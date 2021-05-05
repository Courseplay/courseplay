--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

---@class CombineAIDriver : UnloadableFieldworkAIDriver
CombineAIDriver = CpObject(UnloadableFieldworkAIDriver)


-- fill level when we start making a pocket to unload if we are on the outermost headland
CombineAIDriver.pocketFillLevelFullPercentage = 95
CombineAIDriver.safeUnloadDistanceBeforeEndOfRow = 40

CombineAIDriver.myStates = {
	PULLING_BACK_FOR_UNLOAD = {},
	WAITING_FOR_UNLOAD_AFTER_PULLED_BACK = {},
	RETURNING_FROM_PULL_BACK = {},
	REVERSING_TO_MAKE_A_POCKET = {},
	MAKING_POCKET = {},
	WAITING_FOR_UNLOAD_IN_POCKET = {},
	WAITING_FOR_UNLOAD_BEFORE_STARTING_NEXT_ROW = {},
	UNLOADING_BEFORE_STARTING_NEXT_ROW = {},
	WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED = {},
	WAITING_FOR_UNLOADER_TO_LEAVE = {},
	RETURNING_FROM_POCKET = {},
	DRIVING_TO_SELF_UNLOAD = {},
	SELF_UNLOADING = {},
	DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED = {},
	SELF_UNLOADING_AFTER_FIELDWORK_ENDED = {},
	RETURNING_FROM_SELF_UNLOAD = {}
}


-- Developer hack: to check the class of an object one should use the is_a() defined in CpObject.lua.
-- However, when we reload classes on the fly during the development, the is_a() calls in other modules still
-- have the old class definition (for example CombineUnloadManager.lua) of this class and thus, is_a() fails.
-- Therefore, use this instead, this is safe after a reload.
CombineAIDriver.isACombineAIDriver = true

function CombineAIDriver:init(vehicle)
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER, vehicle, 'CombineAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self:initStates(CombineAIDriver.myStates)
	self.fruitLeft, self.fruitRight = 0, 0
	self.litersPerMeter = 0
	self.litersPerSecond = 0
	self.fillLevelAtLastWaypoint = 0
	self.beaconLightsActive = false
	self.lastEmptyTimestamp = 0
	self.pipeOffsetX = 0
	self.unloaders = {}
	self:initUnloadStates()

	if self.vehicle.spec_combine then
		self.combine = self.vehicle.spec_combine
	else
		local combineImplement = AIDriverUtil.getAIImplementWithSpecialization(self.vehicle, Combine)
        local peletizerImplement = FS19_addon_strawHarvest and
				AIDriverUtil.getAIImplementWithSpecialization(self.vehicle, FS19_addon_strawHarvest.StrawHarvestPelletizer) or nil
		if combineImplement then
			self.combine = combineImplement.spec_combine
        elseif peletizerImplement then
            self.combine = peletizerImplement
            self.combine.fillUnitIndex = 1
            self.combine.spec_aiImplement.rightMarker = self.combine.rootNode
            self.combine.spec_aiImplement.leftMarker  = self.combine.rootNode
            self.combine.spec_aiImplement.backMarker  = self.combine.rootNode
		else
			self:error('Vehicle is not a combine and could not find implement with spec_combine')
		end
	end

	self:setUpPipe()
	self:checkMarkers()

	-- distance to keep to the right (>0) or left (<0) when pulling back to make room for the tractor
	self.pullBackRightSideOffset = math.abs(self.pipeOffsetX) - self.vehicle.cp.workWidth / 2 + 5
	self.pullBackRightSideOffset = self.pipeOnLeftSide and self.pullBackRightSideOffset or -self.pullBackRightSideOffset
	-- should be at pullBackRightSideOffset to the right or left at pullBackDistanceStart
	self.pullBackDistanceStart = self.vehicle.cp.turnDiameter --* 0.7
	-- and back up another bit
	self.pullBackDistanceEnd = self.pullBackDistanceStart + 5
	-- when making a pocket, how far to back up before changing to forward
	self.pocketReverseDistance = 25
	-- register ourselves at our boss
	g_combineUnloadManager:addCombineToList(self.vehicle, self)
	self:measureBackDistance()
	self.vehicleIgnoredByFrontProximitySensor = CpTemporaryObject()
	self.waitingForUnloaderAtEndOfRow = CpTemporaryObject()
	-- if this is not nil, we have a pending rendezvous
	---@type CpTemporaryObject
	self.unloadAIDriverToRendezvous = CpTemporaryObject()
end

function CombineAIDriver:setUpPipe()
	if self.vehicle.spec_pipe then
		self.pipe = self.vehicle.spec_pipe
		self.objectWithPipe = self.vehicle
	else
		local implementWithPipe = AIDriverUtil.getAIImplementWithSpecialization(self.vehicle, Pipe)
		if implementWithPipe then
			self.pipe = implementWithPipe.spec_pipe
			self.objectWithPipe = implementWithPipe
		else
			self:info('Could not find implement with pipe')
		end
	end

	if self.pipe then
		-- check the pipe length:
		-- unfold everything, open the pipe, check the side offset, then close pipe, fold everything back (if it was folded)
		local wasFolded, wasClosed
		if self.vehicle.spec_foldable then
			wasFolded = not self.vehicle.spec_foldable:getIsUnfolded()
			if wasFolded then
				Foldable.setAnimTime(self.vehicle.spec_foldable, self.vehicle.spec_foldable.startAnimTime == 1 and 0 or 1, true)
			end
		end
		if self.pipe.currentState == AIDriverUtil.PIPE_STATE_CLOSED then
			wasClosed = true
			if self.pipe.animation.name then
				self.pipe:setAnimationTime(self.pipe.animation.name, 1, true)
			else
				-- as seen in the Giants pipe code
				self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_OPEN, true)
				self.objectWithPipe:updatePipeNodes(999999, nil)
			end
		end
		local dischargeNode = self:getCurrentDischargeNode()
		self:fixDischargeDistance(dischargeNode)
		local dx, _, _ = localToLocal(dischargeNode.node, self.combine.rootNode, 0, 0, 0)
		self.pipeOnLeftSide = dx >= 0
		self:debug('Pipe on left side %s', tostring(self.pipeOnLeftSide))
		-- use self.combine so attached harvesters have the offset relative to the harvester's root node
		-- (and thus, does not depend on the angle between the tractor and the harvester)
		self.pipeOffsetX, _, self.pipeOffsetZ = localToLocal(dischargeNode.node, self.combine.rootNode, 0, 0, 0)
		self:debug('Pipe offset: x = %.1f, z = %.1f', self.pipeOffsetX, self.pipeOffsetZ)
		if wasClosed then
			if self.pipe.animation.name then
				self.pipe:setAnimationTime(self.pipe.animation.name, 0, true)
			else
				self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED, true)
				self.objectWithPipe:updatePipeNodes(999999, nil)
			end
		end
		if self.vehicle.spec_foldable then
			if wasFolded then
				Foldable.setAnimTime(self.vehicle.spec_foldable, self.vehicle.spec_foldable.startAnimTime == 1 and 1 or 0, true)
			end
		end
	else
		-- make sure pipe offset has a value until CombineUnloadManager as cleaned up as it calls getPipeOffset()
		-- periodically even when CP isn't driving, and even for cotton harvesters...
		self.pipeOffsetX, self.pipeOffsetZ = 0, 0
		self.pipeOnLeftSide = true
	end
end

-- This part of an ugly workaround to make the chopper pickups work
function CombineAIDriver:checkMarkers()
	for _, implement in pairs( self:getAllAIImplements(self.vehicle)) do
		local aiLeftMarker, aiRightMarker, aiBackMarker = implement.object:getAIMarkers()
		if not aiLeftMarker or not aiRightMarker or not aiBackMarker then
			self.notAllImplementsHaveAiMarkers = true
			return
		end
	end
end

--- Get the combine object, this can be different from the vehicle in case of tools towed or mounted on a tractor
function CombineAIDriver:getCombine()
	return self.combine
end

function CombineAIDriver:start(startingPoint)
	self:clearAllUnloaderInformation()
	self:addBackwardProximitySensor()
	UnloadableFieldworkAIDriver.start(self, startingPoint)
	-- we work with the traffic conflict detector and the proximity sensors instead
	self:disableCollisionDetection()
	self:fixMaxRotationLimit()
	local total, pipeInFruit = self.fieldworkCourse:setPipeInFruitMap(self.pipeOffsetX, self.vehicle.cp.workWidth)
	local ix = self.fieldworkCourse:getStartingWaypointIx(AIDriverUtil.getDirectionNode(self.vehicle), startingPoint)
	self:shouldStrawSwathBeOn(ix)
	self.fillLevelFullPercentage = self.normalFillLevelFullPercentage
	self:debug('Pipe in fruit map created, there are %d non-headland waypoints, of which at %d the pipe will be in the fruit',
			total, pipeInFruit)
end

function CombineAIDriver:stop(msgReference)
    self:resetFixMaxRotationLimit()
    UnloadableFieldworkAIDriver.stop(self,msgReference)
end

function CombineAIDriver:setHudContent()
	UnloadableFieldworkAIDriver.setHudContent(self)
	courseplay.hud:setCombineAIDriverContent(self.vehicle)
end

function CombineAIDriver:drive(dt)
	-- handle the pipe in any state
	self:handlePipe()
	-- the rest is the same as the parent class
	UnloadableFieldworkAIDriver.drive(self, dt)
end

function CombineAIDriver:onEndCourse()
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
	if self.state == self.states.ON_FIELDWORK_COURSE and
			self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		if self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD then
			self:debug('Self unloading point reached, fill level %.1f.', fillLevel)
			self.fieldworkUnloadOrRefillState = self.states.SELF_UNLOADING
		elseif 	self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED then
			self:debug('Self unloading point reached after fieldwork ended, fill level %.1f.', fillLevel)
			self.fieldworkUnloadOrRefillState = self.states.SELF_UNLOADING_AFTER_FIELDWORK_ENDED
		end
	elseif self.state == self.states.ON_FIELDWORK_COURSE and fillLevel > 0 then
		if self.vehicle.cp.settings.selfUnload:is(true) and self:startSelfUnload() then
			self:debug('Start self unload after fieldwork ended')
			self:raiseImplements()
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldworkUnloadOrRefillState = self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED
			self.ppc:setShortLookaheadDistance()
			self:disableCollisionDetection()
		else
			self:setInfoText(self:getFillLevelInfoText())
			-- let AutoDrive know we are done and can unload
			self:debug('Fieldwork done, fill level is %.1f, now waiting to be unloaded.', fillLevel)
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED
		end
	else
		UnloadableFieldworkAIDriver.onEndCourse(self)
	end
end

function CombineAIDriver:onWaypointPassed(ix)
	if self.state == self.states.ON_FIELDWORK_COURSE and
			(self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD or
			self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED or
			self.fieldworkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD) then
		-- nothing to do while driving to unload and back
		return UnloadableFieldworkAIDriver.onWaypointPassed(self, ix)
	end
	self:checkFruit()
	-- make sure we start making a pocket while we still have some fill capacity left as we'll be
	-- harvesting fruit while making the pocket unless we have self unload turned on
	if self:shouldMakePocket() and self.vehicle.cp.settings.selfUnload:is(false) then
		self.fillLevelFullPercentage = self.pocketFillLevelFullPercentage
	end

	self:shouldStrawSwathBeOn(ix)

	if self.state == self.states.ON_FIELDWORK_COURSE and self.fieldworkState == self.states.WORKING then
		self:checkDistanceUntilFull(ix)
	end

	if self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldworkUnloadOrRefillState == self.states.MAKING_POCKET and
		self.unloadInPocketIx and ix == self.unloadInPocketIx then
		-- we are making a pocket and reached the waypoint where we are going to stop and wait for unload
		self:debug('Waiting for unload in the pocket')
		self:setInfoText(self:getFillLevelInfoText())
		self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_IN_POCKET

	end
	if self.returnedFromPocketIx and self.returnedFromPocketIx == ix then
		-- back to normal look ahead distance for PPC, no tight turns are needed anymore
		self:debug('Reset PPC to normal lookahead distance')
		self.ppc:setNormalLookaheadDistance()
	end
	UnloadableFieldworkAIDriver.onWaypointPassed(self, ix)
end

function CombineAIDriver:isWaitingInPocket()
 	return self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET
end

function CombineAIDriver:changeToFieldworkUnloadOrRefill()
	self:checkFruit()
	-- TODO: check around turn maneuvers we may not want to pull back before a turn
	if self.vehicle.cp.settings.selfUnload:is(true) and self:startSelfUnload() then
		self:debug('Start self unload')
		self:raiseImplements()
		self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
		self.fieldworkUnloadOrRefillState = self.states.DRIVING_TO_SELF_UNLOAD
		self.ppc:setShortLookaheadDistance()
		self:disableCollisionDetection()
	elseif self.vehicle.cp.settings.useRealisticDriving:is(true) and self:shouldMakePocket() then
		-- I'm on the edge of the field or fruit is on both sides, make a pocket on the right side and wait there for the unload
		local pocketCourse, nextIx = self:createPocketCourse()
		if pocketCourse then
			self:debug('No room to the left, making a pocket for unload')
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldworkUnloadOrRefillState = self.states.REVERSING_TO_MAKE_A_POCKET
			-- raise header for reversing
			self:raiseImplements()
			self:startCourse(pocketCourse, 1, self.course, nextIx)
			-- tighter turns
			self.ppc:setShortLookaheadDistance()
		else
			-- revert to normal behavior
			UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
		end
	elseif self.vehicle.cp.settings.useRealisticDriving:is(true) and self:shouldPullBack() then
		-- is our pipe in the fruit? (assuming pipe is on the left side)
		local pullBackCourse = self:createPullBackCourse()
		if pullBackCourse then
			pullBackCourse:print()
			self:debug('Pipe in fruit, pulling back to make room for unloading')
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_STOP
			self.courseAfterPullBack = self.course
			self.ixAfterPullBack = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
			-- tighter turns
			self.ppc:setShortLookaheadDistance()
			self:startCourse(pullBackCourse, 1)
		else
			-- revert to normal behavior
			UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
		end
	else
		-- pipe not in fruit, combine not on outermost headland, just do the normal thing
		UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
	end
end

function CombineAIDriver:driveFieldwork(dt)
	self:checkRendezvous()
	self:checkBlockingUnloader()
	return UnloadableFieldworkAIDriver.driveFieldwork(self, dt)
end

function CombineAIDriver:startWaitingForUnloadBeforeNextRow()
	self:debug('Waiting for unload before starting the next row')
	self.waitingForUnloaderAtEndOfRow:set(true, 30000)
	self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
	self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_BEFORE_STARTING_NEXT_ROW
end

--- Stop for unload/refill while driving the fieldwork course
function CombineAIDriver:driveFieldworkUnloadOrRefill()
	if self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_STOP then
		self:setSpeed(0)
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('Raise implements and start pulling back')
			self:raiseImplements()
			self.fieldworkUnloadOrRefillState = self.states.PULLING_BACK_FOR_UNLOAD
		end
	elseif self.fieldworkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldworkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldworkUnloadOrRefillState == self.states.MAKING_POCKET then
		self:setSpeed(self:getWorkSpeed())
	elseif self.fieldworkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
		self:setSpeed(self.vehicle.cp.speeds.turn)
	elseif self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET or
			self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK or
			self.fieldworkUnloadOrRefillState == self.states.UNLOADING_BEFORE_STARTING_NEXT_ROW then
		if self:unloadFinished() then
			-- reset offset to return to the original up/down row after we unloaded in the pocket
			self.aiDriverOffsetX = 0

			self:clearInfoText(self:getFillLevelInfoText())
			-- wait a bit after the unload finished to give a chance to the unloader to move away
			self.stateBeforeWaitingForUnloaderToLeave = self.fieldworkUnloadOrRefillState
			self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOADER_TO_LEAVE
			self.waitingForUnloaderSince = self.vehicle.timer
			self:debug('Unloading finished, wait for the unloader to leave...')
		else
			self:setSpeed(0)
		end
	elseif self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_BEFORE_STARTING_NEXT_ROW then
		self:setSpeed(0)
		if self:isDischarging() then
			self:cancelRendezvous()
			self.fieldworkUnloadOrRefillState = self.states.UNLOADING_BEFORE_STARTING_NEXT_ROW
			self:debug('Unloading started at end of row')
		end
		if not self.waitingForUnloaderAtEndOfRow:get() then
			local unloaderWhoDidNotShowUp = self.unloadAIDriverToRendezvous:get()
			self:cancelRendezvous()
			if unloaderWhoDidNotShowUp then unloaderWhoDidNotShowUp:onMissedRendezvous(self) end
			self:debug('Waited for unloader at the end of the row but it did not show up, try to continue')
			self:changeToFieldwork()
		end
	elseif self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED then
		local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
		if fillLevel < 0.01 then
			self:clearInfoText(self:getFillLevelInfoText())
			self:debug('Unloading finished after fieldwork ended, end course')
			UnloadableFieldworkAIDriver.onEndCourse(self)
		else
			self:setSpeed(0)
		end
	elseif self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOADER_TO_LEAVE then
		self:setSpeed(0)
		-- TODO: instead of just wait a few seconds we could check if the unloader has actually left
		if self.waitingForUnloaderSince + 5000 < self.vehicle.timer then
			if self.stateBeforeWaitingForUnloaderToLeave == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK then
				local pullBackReturnCourse = self:createPullBackReturnCourse()
				if pullBackReturnCourse then
					self.fieldworkUnloadOrRefillState = self.states.RETURNING_FROM_PULL_BACK
					self:debug('Unloading finished, returning to fieldwork on return course')
					self:startCourse(pullBackReturnCourse, 1, self.courseAfterPullBack, self.ixAfterPullBack)
				else
					self:debug('Unloading finished, returning to fieldwork directly')
					self:startCourse(self.courseAfterPullBack, self.ixAfterPullBack)
					self.ppc:setNormalLookaheadDistance()
					self:changeToFieldwork()
				end
			elseif self.stateBeforeWaitingForUnloaderToLeave == self.states.WAITING_FOR_UNLOAD_IN_POCKET then
				self:debug('Unloading in pocket finished, returning to fieldwork')
				self.fillLevelFullPercentage = self.normalFillLevelFullPercentage
				self:changeToFieldwork()
			elseif self.stateBeforeWaitingForUnloaderToLeave == self.states.UNLOADING_BEFORE_STARTING_NEXT_ROW then
				self:debug('Unloading before next row finished, returning to fieldwork')
				self:changeToFieldwork()
			else
				self:debug('Unloading finished, previous state not known, returning to fieldwork')
				self:changeToFieldwork()
			end
		end
	elseif self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.field)
	elseif self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED then
		self:setSpeed(self.vehicle.cp.speeds.field)
	elseif self.fieldworkUnloadOrRefillState == self.states.SELF_UNLOADING then
		self:setSpeed(0)
		if self:unloadFinished() then
			self:debug('Self unloading finished, returning to fieldwork')
			if self:returnToFieldworkAfterSelfUnloading() then
				self.fieldworkUnloadOrRefillState = self.states.RETURNING_FROM_SELF_UNLOAD
			else
				self:startFieldworkWithPathfinding(self.aiDriverData.continueFieldworkAtWaypoint)
			end
			self.ppc:setNormalLookaheadDistance()
		end
	elseif self.fieldworkUnloadOrRefillState == self.states.SELF_UNLOADING_AFTER_FIELDWORK_ENDED then
		self:setSpeed(0)
		if self:unloadFinished() then
			self:debug('Self unloading finished after fieldwork ended, returning to fieldwork')
			UnloadableFieldworkAIDriver.onEndCourse(self)
		end
	elseif self.fieldworkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.field)
	else
		UnloadableFieldworkAIDriver.driveFieldworkUnloadOrRefill(self)
	end
end

function CombineAIDriver:onLastWaypoint()
	if self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
			self.fieldworkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
		-- pulled back, now wait for unload
		self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK
		self:debug('Pulled back, now wait for unload')
		self:setInfoText(self:getFillLevelInfoText())
	else
		UnloadableFieldworkAIDriver.onLastWaypoint(self)
	end
end

function CombineAIDriver:onNextCourse(ix)
	if self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		if self.fieldworkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
			self:debug('Pull back finished, returning to fieldwork')
			self:changeToFieldwork()
		elseif self.fieldworkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD then
			self:debug('Back from self unload, returning to fieldwork')
			self:changeToFieldwork()
		elseif self.fieldworkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
			self:debug('Reversed, now start making a pocket to waypoint %d', self.unloadInPocketIx)
			self:lowerImplements()
			self.fieldworkUnloadOrRefillState = self.states.MAKING_POCKET
			self.aiDriverOffsetX = self.pullBackRightSideOffset
		end
	elseif self.fieldworkState == self.states.TURNING then
		self.ppc:setNormalLookaheadDistance()
		-- make sure the next waypoint is in front of us. It can be behind us after a turn with multitools where the
		-- x offset is high (wide tools)
		self.ppc:initialize(self.course:getNextFwdWaypointIxFromVehiclePosition(ix, self:getDirectionNode(), 0))
		UnloadableFieldworkAIDriver.onNextCourse(self)
	else
		UnloadableFieldworkAIDriver.onNextCourse(self)
	end
end

function CombineAIDriver:unloadFinished()
	local discharging = true
	local dischargingNow = false
	if self.pipe then
		dischargingNow = self.pipe:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
	end
	--wait for 10 frames before taking discharging as false
	if not dischargingNow then
		self.notDischargingSinceLoopIndex =
		self.notDischargingSinceLoopIndex and self.notDischargingSinceLoopIndex or g_updateLoopIndex
		if g_updateLoopIndex - self.notDischargingSinceLoopIndex > 10 then
			discharging = false
		end
	else
		self.notDischargingSinceLoopIndex = nil
	end
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)

	-- unload is done when fill levels are ok (not full) and not discharging anymore (either because we
	-- are empty or the trailer is full)
	return (self:allFillLevelsOk() and not discharging) or fillLevel < 0.1
end

function CombineAIDriver:shouldMakePocket()
	if self.fruitLeft > 0.75 and self.fruitRight > 0.75 then
		-- fruit both sides
		return true
	elseif self.pipeOnLeftSide then
		-- on the outermost headland clockwise (field edge)
		return not self.fieldOnLeft
	else
		-- on the outermost headland counterclockwise (field edge)
		return not self.fieldOnRight
	end
end

function CombineAIDriver:shouldPullBack()
	return self:isPipeInFruit()
end

function CombineAIDriver:isPipeOnLeft()
	return self.pipeOnLeftSide
end

function CombineAIDriver:isPipeInFruit()
	-- is our pipe in the fruit?
	if self.pipeOnLeftSide then
		return self.fruitLeft > self.fruitRight
	else
		return self.fruitLeft < self.fruitRight
	end
end

function CombineAIDriver:checkFruit()
	-- getValidityOfTurnDirections() wants to have the vehicle.aiDriveDirection, so get that here.
	local dx,_,dz = localDirectionToWorld(self.vehicle:getAIVehicleDirectionNode(), 0, 0, 1)
	local length = MathUtil.vector2Length(dx,dz)
	dx = dx / length
	dz = dz / length
	self.vehicle.aiDriveDirection = {dx, dz}
	-- getValidityOfTurnDirections works only if all AI Implements have aiMarkers. Since
	-- we make all Cutters AI implements, even the ones which do not have AI markers (such as the
	-- chopper pickups which do not work with the Giants helper) we have to make sure we don't call
	-- getValidityOfTurnDirections for those
	if self.notAllImplementsHaveAiMarkers then
		self.fruitLeft, self.fruitRight = 0, 0
	else
		self.fruitLeft, self.fruitRight = AIVehicleUtil.getValidityOfTurnDirections(self.vehicle)
	end
	local x, _, z = localToWorld(self:getDirectionNode(), self.vehicle.cp.workWidth, 0, 0)
	self.fieldOnLeft = courseplay:isField(x, z, 1, 1)
	x, _, z = localToWorld(self:getDirectionNode(), -self.vehicle.cp.workWidth, 0, 0)
	self.fieldOnRight = courseplay:isField(x, z, 1, 1)
	self:debug('Fruit left: %.2f right %.2f, field on left %s, right %s',
		self.fruitLeft, self.fruitRight, tostring(self.fieldOnLeft), tostring(self.fieldOnRight))
end

function CombineAIDriver:checkDistanceUntilFull(ix)
	-- calculate fill rate so the combine driver knows if it can make the next row without unloading
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
	if ix > 1 then
		if self.fillLevelAtLastWaypoint and self.fillLevelAtLastWaypoint > 0 and self.fillLevelAtLastWaypoint <= fillLevel then
			local litersPerMeter = (fillLevel - self.fillLevelAtLastWaypoint) / self.course:getDistanceToNextWaypoint(ix - 1)
			-- make sure it won't end up being inf
			local litersPerSecond = math.min(1000, (fillLevel - self.fillLevelAtLastWaypoint) /
					((self.vehicle.timer - (self.fillLevelLastCheckedTime or self.vehicle.timer)) / 1000))
			-- smooth everything a bit, also ignore 0
			self.litersPerMeter = litersPerMeter > 0 and (self.litersPerMeter + litersPerMeter) / 2 or self.litersPerMeter
			self.litersPerSecond = litersPerSecond > 0 and (self.litersPerSecond + litersPerSecond) / 2 or self.litersPerSecond
			self.fillLevelAtLastWaypoint = (self.fillLevelAtLastWaypoint + fillLevel) / 2
		else
			-- no history yet, so make sure we don't end up with some unrealistic numbers
			self.waypointIxWhenFull = nil
			self.litersPerMeter = 0
			self.litersPerSecond = 0
			self.fillLevelAtLastWaypoint = fillLevel
		end
		self.fillLevelLastCheckedTime = self.vehicle.timer
		self:debug('Fill rate is %.1f l/m, %.1f l/s', self.litersPerMeter, self.litersPerSecond)
	end
	local litersUntilFull = self.combine:getFillUnitCapacity(self.combine.fillUnitIndex) - fillLevel
	local dUntilFull = litersUntilFull / self.litersPerMeter * 0.9  -- safety margin
	self.secondsUntilFull = self.litersPerSecond > 0 and (litersUntilFull / self.litersPerSecond) or nil
	self.waypointIxWhenFull = self.course:getNextWaypointIxWithinDistance(ix, dUntilFull) or self.course:getNumberOfWaypoints()
	self.distanceToWaypointWhenFull =
		self.course:getDistanceBetweenWaypoints(self.waypointIxWhenFull, self.course:getCurrentWaypointIx())
	self:debug('Will be full at waypoint %d in %d m',
			self.waypointIxWhenFull or -1, self.distanceToWaypointWhenFull)
end

function CombineAIDriver:checkRendezvous()
	if self.fieldworkState == self.states.WORKING then
		if self.unloadAIDriverToRendezvous:get() then
			local d = self.fieldworkCourse:getDistanceBetweenWaypoints(self.fieldworkCourse:getCurrentWaypointIx(),
					self.agreedUnloaderRendezvousWaypointIx)
			if d < 10 then
				self:debugSparse('Slow down around the unloader rendezvous waypoint %d to let the unloader catch up',
						self.agreedUnloaderRendezvousWaypointIx)
				self:setSpeed(self:getWorkSpeed() / 2)
				local dToTurn = self.fieldworkCourse:getDistanceToNextTurn(self.agreedUnloaderRendezvousWaypointIx) or math.huge
				if dToTurn < 20 then
					self:debug('Unloader rendezvous waypoint %d is before a turn, waiting for the unloader here',
							self.agreedUnloaderRendezvousWaypointIx)
					self:startWaitingForUnloadBeforeNextRow()
				end
			elseif self.fieldworkCourse:getCurrentWaypointIx() > self.agreedUnloaderRendezvousWaypointIx then
				self:debug('Unloader missed the rendezvous at %d', self.agreedUnloaderRendezvousWaypointIx)
				local unloaderWhoDidNotShowUp = self.unloadAIDriverToRendezvous:get()
				-- need to call this before onMissedRendezvous as the unloader will call back to set up a new rendezvous
				-- and we don't want to cancel that right away
				self:cancelRendezvous()
				unloaderWhoDidNotShowUp:onMissedRendezvous(self)
			end
			if self:isDischarging() then
				self:debug('Discharging, cancelling unloader rendezvous')
				self:cancelRendezvous()
			end
		end
	end
end

function CombineAIDriver:hasRendezvousWith(unloadAIDriver)
	return self.unloadAIDriverToRendezvous:get() == unloadAIDriver
end

function CombineAIDriver:cancelRendezvous()
	local unloader = self.unloadAIDriverToRendezvous:get()
	self:debug('Rendezvous with %s at waypoint %d cancelled',
			unloader and nameNum(self.unloadAIDriverToRendezvous:get() or 'N/A'),
			self.agreedUnloaderRendezvousWaypointIx or -1)
	self.agreedUnloaderRendezvousWaypointIx = nil
	self.unloadAIDriverToRendezvous:set(nil, 0)
end

--- Before the unloader asks for a rendezvous (which may result in a lengthy pathfinding to figure out
--- the distance), it should check if the combine is willing to rendezvous.
function CombineAIDriver:isWillingToRendezvous()
	if self.state ~= self.states.ON_FIELDWORK_COURSE then
		self:debug('not on fieldwork course, will not rendezvous')
		return nil
	elseif self.vehicle.cp.settings.allowUnloadOnFirstHeadland:is(false) and
			self.fieldworkCourse:isOnHeadland(self.fieldworkCourse:getCurrentWaypointIx(), 1) then
		self:debug('on first headland and unload not allowed on first headland, will not rendezvous')
		return nil
	end
	return true
end

--- When the unloader asks us for a rendezvous, provide him with a waypoint index to meet us.
--- This waypoint should be a good location to unload (pipe not in fruit, not in a turn, etc.)
--- If no such waypoint found, reject the rendezvous.
---@param unloaderEstimatedSecondsEnroute number minimum time the unloader needs to get to the combine
---@param unloadAIDriver CombineUnloadAIDriver the driver requesting the rendezvous
---@return Waypoint, number, number waypoint to meet the unloader, index of waypoint, time we need to reach that waypoint
function CombineAIDriver:getUnloaderRendezvousWaypoint(unloaderEstimatedSecondsEnroute, unloadAIDriver)

	local dToUnloaderRendezvous = unloaderEstimatedSecondsEnroute * self:getWorkSpeed() / 3.6
	-- this is where we'll be when the unloader gets here
	local unloaderRendezvousWaypointIx = self.fieldworkCourse:getNextWaypointIxWithinDistance(
			self.fieldworkCourse:getCurrentWaypointIx(), dToUnloaderRendezvous) or
			self.fieldworkCourse:getNumberOfWaypoints()

	self:debug('Rendezvous request: seconds until full: %d, unloader ETE: %d (around my wp %d, in %d meters), full at waypoint %d, ',
			self.secondsUntilFull or -1, unloaderEstimatedSecondsEnroute, unloaderRendezvousWaypointIx, dToUnloaderRendezvous,
			self.waypointIxWhenFull or -1)

	-- rendezvous at whichever is closer
	unloaderRendezvousWaypointIx = math.min(unloaderRendezvousWaypointIx, self.waypointIxWhenFull or unloaderRendezvousWaypointIx)
	-- now check if this is a good idea
	self.agreedUnloaderRendezvousWaypointIx = self:findBestWaypointToUnload(unloaderRendezvousWaypointIx)
	if self.agreedUnloaderRendezvousWaypointIx then
		self.unloadAIDriverToRendezvous:set(unloadAIDriver, 1000 * (unloaderEstimatedSecondsEnroute + 30))
		self:debug('Rendezvous with unloader at waypoint %d in %d m', self.agreedUnloaderRendezvousWaypointIx, dToUnloaderRendezvous)
		return self.fieldworkCourse:getWaypoint(self.agreedUnloaderRendezvousWaypointIx),
			self.agreedUnloaderRendezvousWaypointIx, unloaderEstimatedSecondsEnroute
	else
		self:cancelRendezvous()
		self:debug('Rendezvous with unloader rejected')
		return nil, 0, 0
	end
end

function CombineAIDriver:canUnloadWhileMovingAtWaypoint(ix)
	if self.fieldworkCourse:isPipeInFruitAt(ix) then
		self:debug('pipe would be in fruit at the planned rendezvous waypoint %d', ix)
		return false
	end
	if self.vehicle.cp.settings.allowUnloadOnFirstHeadland:is(false) and self.fieldworkCourse:isOnHeadland(ix, 1) then
		self:debug('planned rendezvous waypoint %d is on first headland, no unloading of moving combine there', ix)
		return false
	end
	return true
end

-- TODO: put this in onBlocked()?
function CombineAIDriver:checkBlockingUnloader()
	if not self.backwardLookingProximitySensorPack then return end
	local d, blockingVehicle = self.backwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
	if d < 1000 and blockingVehicle and self:isStopped() and self:isReversing() and not self:isWaitingForUnload() then
		self:debugSparse('Can\'t reverse, %s at %.1f m is blocking', blockingVehicle:getName(), d)
		if blockingVehicle.cp.driver and blockingVehicle.cp.driver.onBlockingOtherVehicle then
			blockingVehicle.cp.driver:onBlockingOtherVehicle(self.vehicle)
		end
	end
end

function CombineAIDriver:checkFruitAtNode(node, offsetX, offsetZ)
	local x, _, z = localToWorld(node, offsetX, 0, offsetZ or 0)
	local hasFruit, fruitValue = PathfinderUtil.hasFruit(x, z, 5, 3)
	return hasFruit, fruitValue
end

--- Is pipe in fruit according to the current field harvest state at waypoint?
function CombineAIDriver:isPipeInFruitAtWaypointNow(course, ix)
	if not self.aiDriverData.fruitCheckHelperWpNode then
		self.aiDriverData.fruitCheckHelperWpNode = WaypointNode(nameNum(self.vehicle) .. 'fruitCheckHelperWpNode')
	end
	self.aiDriverData.fruitCheckHelperWpNode:setToWaypoint(course, ix)
	local hasFruit, fruitValue = self:checkFruitAtNode(self.aiDriverData.fruitCheckHelperWpNode.node, self.pipeOffsetX)
	self:debug('at waypoint %d pipe in fruit %s (fruitValue %.1f)', ix, tostring(hasFruit), fruitValue or 0)
	return hasFruit, fruitValue
end

--- Find the best waypoint to unload.
---@param ix number waypoint index we want to start unloading, either because that's about where
--- we'll rendezvous the unloader or we'll be full there.
---@return number best waypoint to unload, ix may be adjusted to make sure it isn't in a turn or
--- the fruit is not in the pipe.
function CombineAIDriver:findBestWaypointToUnload(ix)
	if self.fieldworkCourse:isOnHeadland(ix) then
		return self:findBestWaypointToUnloadOnHeadland(ix)
	else
		return self:findBestWaypointToUnloadOnUpDownRows(ix)
	end
end

function CombineAIDriver:findBestWaypointToUnloadOnHeadland(ix)
	if self.vehicle.cp.settings.allowUnloadOnFirstHeadland:is(false) and
			self.fieldworkCourse:isOnHeadland(ix, 1) then
		self:debug('planned rendezvous waypoint %d is on first headland, no unloading of moving combine there', ix)
		return nil
	end
	if self.fieldworkCourse:isTurnStartAtIx(ix) then
		-- on the headland, use the wp after the turn, the one before may be very far, especially on a
		-- transition from headland to up/down rows.
		return ix + 1
	else
		return ix
	end
end

--- We calculated a waypoint to meet the unloader (either because it asked for it or we think we'll need
--- to unload. Now make sure that this location is not around a turn or the pipe isn't in the fruit by
--- trying to move it up or down a bit. If that's not possible, just leave it and see what happens :)
function CombineAIDriver:findBestWaypointToUnloadOnUpDownRows(ix)
	local dToNextTurn = self.fieldworkCourse:getDistanceToNextTurn(ix) or math.huge
	local lRow, ixAtRowStart = self.fieldworkCourse:getRowLength(ix)
	local pipeInFruit = self.fieldworkCourse:isPipeInFruitAt(ix)
	local currentIx = self.fieldworkCourse:getCurrentWaypointIx()
	local newWpIx = ix
	self:debug('Looking for a waypoint to unload around %d on up/down row, pipe in fruit %s, dToNextTurn: %d m, lRow = %d m',
				ix, tostring(pipeInFruit), dToNextTurn, lRow or 0)
	if pipeInFruit then
		if ixAtRowStart then
			if ixAtRowStart > currentIx then
				-- have not started the previous row yet
				self:debug('Pipe would be in fruit at waypoint %d. Check previous row', ix)
				pipeInFruit, _ = self.fieldworkCourse:isPipeInFruitAt(ixAtRowStart - 2) -- wp before the turn start
				if not pipeInFruit then
					local lPreviousRow, ixAtPreviousRowStart = self.fieldworkCourse:getRowLength(ixAtRowStart - 1)
					self:debug('pipe not in fruit in the previous row (%d m, ending at wp %d), rendezvous at %d',
							lPreviousRow, ixAtRowStart - 1, newWpIx)
					newWpIx = math.max(ixAtRowStart - 3, ixAtPreviousRowStart, currentIx)
				else
					self:debug('Pipe in fruit in previous row too, rejecting rendezvous')
					newWpIx = nil
				end
			else
				-- previous row already started. Could check next row but that means the rendezvous would be after
				-- the combine turns, and we'd be in the way during the turn, so rather not worry about the next row
				-- until the combine gets there.
				self:debug('Pipe would be in fruit at waypoint %d. Previous row is already started, no rendezvous', ix)
				newWpIx = nil
			end
		else
			self:debug('Could not determine row length, rejecting rendezvous')
			newWpIx = nil
		end
	else
		self:debug('pipe is not in fruit at %d. If it is towards the end of the row, bring it up a bit', ix)
		-- so we'll have some distance for unloading
		if ixAtRowStart and dToNextTurn < CombineAIDriver.safeUnloadDistanceBeforeEndOfRow then
			local safeIx = self.fieldworkCourse:getPreviousWaypointIxWithinDistance(ix,
					CombineAIDriver.safeUnloadDistanceBeforeEndOfRow)
			newWpIx = math.max(ixAtRowStart + 1, safeIx or -1, ix - 4)
		end
	end
	-- no better idea, just use the original estimated, making sure we avoid turn start waypoints
	if newWpIx and self.fieldworkCourse:isTurnStartAtIx(newWpIx) then
		self:debug('Calculated rendezvous waypoint is at turn start, moving it up')
		-- make sure it is not on the turn start waypoint
		return math.max(newWpIx - 1, currentIx)
	else
		return newWpIx
	end
end

function CombineAIDriver:updateLightsOnField()
	-- handle beacon lights to call unload driver
	-- copy/paste from AIDriveStrategyCombine
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
	local capacity = self.vehicle:getFillUnitCapacity(self.combine.fillUnitIndex)
	if fillLevel > (0.8 * capacity) then
		if not self.beaconLightsActive then
			self.vehicle:setAIMapHotspotBlinking(true)
			self.vehicle:setBeaconLightsVisibility(true)
			self.beaconLightsActive = true
		end
	else
		if self.beaconLightsActive then
			self.vehicle:setAIMapHotspotBlinking(false)
			self.vehicle:setBeaconLightsVisibility(false)
			self.beaconLightsActive = false
		end
	end
end

--- Create a temporary course to pull back to the right when the pipe is in the fruit so the tractor does not have
-- to drive in the fruit to get under the pipe
function CombineAIDriver:createPullBackCourse()
	-- all we need is a waypoint on our right side towards the back
	self.returnPoint = {}
	self.returnPoint.x, _, self.returnPoint.z = getWorldTranslation(self.vehicle.rootNode)

	local dx,_,dz = localDirectionToWorld(self:getDirectionNode(), 0, 0, 1)
	self.returnPoint.rotation = MathUtil.getYRotationFromDirection(dx, dz)
	dx,_,dz = localDirectionToWorld(self:getDirectionNode(), 0, 0, -1)

	local x1, _, z1 = localToWorld(self:getDirectionNode(), -self.pullBackRightSideOffset, 0, -self.pullBackDistanceStart)
	local x2, _, z2 = localToWorld(self:getDirectionNode(), -self.pullBackRightSideOffset, 0, -self.pullBackDistanceEnd)
	-- both points must be on the field
	if courseplay:isField(x1, z1) and courseplay:isField(x2, z2) then

		local referenceNode, debugText = AIDriverUtil.getReverserNode(self.vehicle)
		if referenceNode then
			self:debug('Using %s to start pull back course', debugText)
		else
			referenceNode = AIDriverUtil.getDirectionNode(self.vehicle)
			self:debug('Using the direction node to start pull back course')
		end
		-- don't make this too complicated, just create a straight line on the left/right side (depending on
		-- where the pipe is and rely on the PPC, no need for generating fancy curves
		return Course.createFromNode(self.vehicle, referenceNode,
				-self.pullBackRightSideOffset, 0, -self.pullBackDistanceEnd, -2, true)
	else
		self:debug("Pull back course would be outside of the field")
		return nil
	end
end

--- Get the area the unloader should avoid when approaching the combine.
--- Main (and for now, only) use case is to prevent the unloader to cross in front of the combine after the
--- combine pulled back full with pipe in the fruit, making room for the unloader on its left side.
--- @return table, number, number, number, number node, xOffset, zOffset, width, length : the area to avoid is
--- a length x width m rectangle, the rectangle's bottom right corner (when looking from node) is at xOffset/zOffset
--- from node.
function CombineAIDriver:getAreaToAvoid()
	if self:isWaitingForUnloadAfterPulledBack() then
		local xOffset = 0
		local zOffset = 0
		local length = self.pullBackDistanceEnd
		local width = self.pullBackRightSideOffset
		return PathfinderUtil.Area(AIDriverUtil.getDirectionNode(self.vehicle), xOffset, zOffset, width, length)
	end
end

function CombineAIDriver:createPullBackReturnCourse()
	-- nothing fancy here either, just move forward a few meters before returning to the fieldwork course
	local referenceNode = AIDriverUtil.getDirectionNode(self.vehicle)
	return Course.createFromNode(self.vehicle, referenceNode, 0, 0, 6, 2, false)
end

--- Create a temporary course to make a pocket in the fruit on the right (or left), so we can move into that pocket and
--- wait for the unload there. This way the unload tractor does not have to leave the field.
--- We create a temporary course to reverse back far enough. After that, we return to the main course but
--- set an offset to the right (or left)
function CombineAIDriver:createPocketCourse()
	local startIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
	-- find the waypoint we want to back up to
	local backIx = self.course:getPreviousWaypointIxWithinDistance(startIx, self.pocketReverseDistance)
	if not backIx then return nil end
	-- this is where we'll stop in the pocket for unload
	self.unloadInPocketIx = startIx - 2
	-- this where we are back on track after returning from the pocket
	self.returnedFromPocketIx = self.ppc:getCurrentWaypointIx()
	self:debug('Backing up %.1f meters from waypoint %d to %d to make a pocket', self.pocketReverseDistance, startIx, backIx)
	if startIx - backIx > 2 then
		local pocketReverseWaypoints = {}
		for i = startIx, backIx, -1 do
			if self.course:isTurnStartAtIx(i) then
				self:debug('There is a turn behind me at waypoint %d, no pocket', i)
				return nil
			end
			local x, _, z = self.course:getWaypointPosition(i)
			table.insert(pocketReverseWaypoints, {x = x, z = z, rev = true})
		end
		return Course(self.vehicle, pocketReverseWaypoints, true), backIx + 1
	else
		self:debug('Not enough waypoints behind me, no pocket')
		return nil
	end
end

--- Disable auto stop for choppers as when we stop the engine they'll also raise implements and the way we restart them
--- won't lower the header. So for now, just don't let them to stop the engine
function CombineAIDriver:isEngineAutoStopEnabled()
	return not self:isChopper() and AIDriver.isEngineAutoStopEnabled(self)
end

--- Compatibility function for turn.lua to check if the vehicle should stop during a turn (for example while it
--- is held for unloading or waiting for the straw swath to stop
--- Turn.lua calls this in every cycle during the turn and will stop the vehicle if this returns true.
---@param isApproaching boolean if true we are still in the turn approach phase (still working on the field,
---not yet reached the turn start
---@param isHeadlandCorner boolean is this a headland turn?
function CombineAIDriver:holdInTurnManeuver(isApproaching, isHeadlandCorner)
	local discharging = self:isDischarging() and not self:isChopper()
	local waitForStraw = self.combine.strawPSenabled and not isApproaching and not isHeadlandCorner
	self:debugSparse('discharging %s, held for unload %s, straw active %s, approaching = %s',
		tostring(discharging), tostring(self.heldForUnloadRefill), tostring(self.combine.strawPSenabled), tostring(isApproaching))
	return discharging or self.heldForUnloadRefill or waitForStraw
end

--- Should we return to the first point of the course after we are done?
function CombineAIDriver:shouldReturnToFirstPoint()
	-- Combines stay where they are after finishing work
	-- TODO: call unload driver
	return false
end

--- Interface for Mode 2 and AutoDrive
---@return boolean true when the combine is waiting to be unloaded
function CombineAIDriver:isWaitingForUnload()
	return self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		(self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL or
			self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET or
			self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK or
			self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED)
end

--- Interface for AutoDrive
---@return boolean true when the combine is waiting to be unloaded after it ended the course
function CombineAIDriver:isWaitingForUnloadAfterCourseEnded()
	return self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED
end

--- Interface for Mode 2
---@return boolean true when the combine is waiting to after it pulled back.
function CombineAIDriver:isWaitingForUnloadAfterPulledBack()
	return self.state == self.states.ON_FIELDWORK_COURSE and
			self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
			self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK
end

function CombineAIDriver:createTurnCourse()
	return CombineCourseTurn(self.vehicle, self, self.turnContext, self.fieldworkCourse)
end

--- Will we be driving forward only (not reversing) during a turn
function CombineAIDriver:isTurnForwardOnly()
	return self:isTurning() and self.aiTurn and self.aiTurn:isForwardOnly()
end

function CombineAIDriver:getTurnCourse()
	return self.aiTurn and self.aiTurn:getCourse()
end

function CombineAIDriver:startTurn(ix)
	self:debug('Starting a combine turn.')

	self:setMarkers()
	self.turnContext = TurnContext(self.course, ix, self.aiDriverData, self.vehicle.cp.workWidth,
			self.frontMarkerDistance, self.backMarkerDistance,
			self:getTurnEndSideOffset(), self:getTurnEndForwardOffset())

	-- Combines drive special headland corner maneuvers, except potato and sugarbeet harvesters
	if self.turnContext:isHeadlandCorner() then
		if self:isPotatoOrSugarBeetHarvester() then
			self:debug('Headland turn but this harvester uses normal turn maneuvers.')
			UnloadableFieldworkAIDriver.startTurn(self, ix)
		elseif self.course:isOnConnectingTrack(ix) then
			self:debug('Headland turn but this a connecting track, use normal turn maneuvers.')
			UnloadableFieldworkAIDriver.startTurn(self, ix)
		elseif self.course:isOnOutermostHeadland(ix) and self.vehicle.cp.settings.turnOnField:is(true) then
			self:debug('Creating a pocket in the corner so the combine stays on the field during the turn')
			self.aiTurn = CombinePocketHeadlandTurn(self.vehicle, self, self.turnContext, self.fieldworkCourse)
			self.fieldworkState = self.states.TURNING
			self.ppc:setShortLookaheadDistance()
		else
			self:debug('Use combine headland turn.')
			self.aiTurn = CombineHeadlandTurn(self.vehicle, self, self.turnContext)
			self.fieldworkState = self.states.TURNING
		end
	else
		self:debug('Non headland turn.')
		UnloadableFieldworkAIDriver.startTurn(self, ix)
	end
end

function CombineAIDriver:isTurning()
	return self.state == self.states.ON_FIELDWORK_COURSE and self.fieldworkState == self.states.TURNING
end

-- Turning except in the ending turn phase which isn't really a turn, it is rather 'starting row'
function CombineAIDriver:isTurningButNotEndingTurn()
	return self:isTurning() and self.aiTurn and not self.aiTurn:isEndingTurn()
end

function CombineAIDriver:isFinishingRow()
	return self:isTurning() and self.aiTurn and self.aiTurn:isFinishingRow()
end

function CombineAIDriver:getTurnStartWpIx()
	return self.turnContext and self.turnContext.turnStartWpIx or nil
end

function CombineAIDriver:isTurningOnHeadland()
	return self.fieldworkState == self.states.TURNING and self.turnContext and self.turnContext:isHeadlandCorner()
end

function CombineAIDriver:isTurningLeft()
	return self.fieldworkState == self.states.TURNING and self.turnContext and self.turnContext:isLeftTurn()
end

function CombineAIDriver:getFieldworkCourse()
	return self.fieldworkCourse
end

function CombineAIDriver:getWorkWidth()
	return self.vehicle.cp.workWidth
end

function CombineAIDriver:isChopper()
	return self.combine:getFillUnitCapacity(self.combine.fillUnitIndex) > 10000000
end

function CombineAIDriver:handlePipe()
	if self.pipe then
		if self:isChopper() then
			self:handleChopperPipe()
		else
			self:handleCombinePipe()
		end
	end
end

function CombineAIDriver:handleCombinePipe()
    
  if self:isFillableTrailerUnderPipe() or self:isAutoDriveWaitingForPipe() or (self:isWaitingForUnload() and self.vehicle.cp.settings.pipeAlwaysUnfold:is(true)) then
		self:openPipe()
	else
		--wait until the objects under the pipe are gone
		if self.pipe.numObjectsInTriggers <=0 then
			self:closePipe()
		end
	end
end

function CombineAIDriver:getFillLevelPercentage()
	return 100 * self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex) / self.vehicle:getFillUnitCapacity(self.combine.fillUnitIndex)
end

--- Support for AutoDrive mod: they'll only find us if we open the pipe
function CombineAIDriver:isAutoDriveWaitingForPipe()
	return self.vehicle.spec_autodrive and self.vehicle.spec_autodrive.combineIsCallingDriver and self.vehicle.spec_autodrive:combineIsCallingDriver(self.vehicle)
end

function CombineAIDriver:handleChopperPipe()
	self.isChopperWaitingForTrailer = false
	if self.state == self.states.ON_FIELDWORK_COURSE then
		-- chopper always opens the pipe
		self:openPipe()
		-- and stops if there's no trailer in sight
		local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
		--self:debug('filltype = %s, fillLevel = %.1f', self:getFillType(), fillLevel)
		-- not using isFillableTrailerUnderPipe() as the chopper sometimes has FillType.UNKNOWN
		if self:getIsChopperWaitingForTrailer(fillLevel) then
			self:debugSparse('Chopper waiting for trailer, fill level %f', fillLevel)
			self.isChopperWaitingForTrailer = true
			self:setSpeed(0)
		end
	else
		self:closePipe()
	end
end

function CombineAIDriver:getIsChopperWaitingForTrailer()
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
	if fillLevel > 0.01 and self:getFillType() ~= FillType.UNKNOWN and not (self:isFillableTrailerUnderPipe() and self:canDischarge()) then
		-- the above condition (by the time of writing this comment we can't remember which exact one) temporarily
		-- can return an incorrect value so try to ignore these glitches
		self.cantDischargeCount = self.cantDischargeCount and self.cantDischargeCount + 1 or 0
		if self.cantDischargeCount > 10 then
			return true
		end
	else
		self.cantDischargeCount = 0
	end
	return false
end

function CombineAIDriver:needToOpenPipe()
	-- potato harvesters for instance don't need to open the pipe.
	return self.pipe.numStates > 1
end

function CombineAIDriver:openPipe()
	if not self:needToOpenPipe() then return end
	if self.pipe.currentState ~= AIDriverUtil.PIPE_STATE_MOVING and
		self.pipe.currentState ~= AIDriverUtil.PIPE_STATE_OPEN then
		self:debug('Opening pipe')
		self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_OPEN)
	end
end

function CombineAIDriver:closePipe()
	if not self:needToOpenPipe() then return end
	if self.pipe.currentState ~= AIDriverUtil.PIPE_STATE_MOVING and
		self.pipe.currentState ~= AIDriverUtil.PIPE_STATE_CLOSED then
		self:debug('Closing pipe')
		self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
	end
end

function CombineAIDriver:isPipeMoving()
	if not self:needToOpenPipe() then return end
	return self.pipe.currentState == AIDriverUtil.PIPE_STATE_MOVING
end

function CombineAIDriver:shouldStopForUnloading(pc)
	local stop = false
	if self.vehicle.cp.settings.stopForUnload:is(true) and self.pipe then
		if self:isDischarging() and g_updateLoopIndex > self.lastEmptyTimestamp + 600 then
			-- stop only if the pipe is discharging AND we have been emptied a while ago.
			-- this makes sure the combine will start driving after it is emptied but the trailer
			-- is still under the pipe
			stop = true
		end
	end
	if pc and pc < 0.1 then
		-- remember the time we were completely unloaded.
		self.lastEmptyTimestamp = g_updateLoopIndex
	end
	return stop
end

function CombineAIDriver:isFillableTrailerUnderPipe()
	if self.pipe then
		for trailer, value in pairs(self.pipe.objectsInTriggers) do
			if value > 0 then
				if self:canLoadTrailer(trailer) then
					return true
				end
			end
		end
	end
	return false
end

function CombineAIDriver:canLoadTrailer(trailer)
	local fillType = self:getFillType()
	if fillType then
		local fillUnits = trailer:getFillUnits()
		for i = 1, #fillUnits do
			local supportedFillTypes = trailer:getFillUnitSupportedFillTypes(i)
			local freeCapacity =  trailer:getFillUnitFreeCapacity(i)
			if supportedFillTypes[fillType] and freeCapacity > 0 then
				return true, freeCapacity, i
			end
		end
	end
	return false, 0
end

function CombineAIDriver:getFillType()
	local dischargeNode = self.objectWithPipe:getDischargeNodeByIndex(self.objectWithPipe:getPipeDischargeNodeIndex())
	if dischargeNode then
		return self.objectWithPipe:getFillUnitFillType(dischargeNode.fillUnitIndex)
	end
	return nil
end

function CombineAIDriver:getCurrentDischargeNode()
	if self.combine and self.combine.getCurrentDischargeNode then
		return self.combine:getCurrentDischargeNode()
	end
end

-- even if there is a trailer in range, we should not start moving until the pipe is turned towards the
-- trailer and can start discharging. This returning true does not mean there's a trailer under the pipe,
-- this seems more like for choppers to check if there's a potential target around
function CombineAIDriver:canDischarge()
	-- TODO: self.vehicle should be the combine, which may not be the vehicle in case of towed harvesters
	local dischargeNode = self:getCurrentDischargeNode()
	if dischargeNode then
		local targetObject, _ = self.combine:getDischargeTargetObject(dischargeNode)
		return targetObject
	end
	return false
end

function CombineAIDriver:isDischarging()
	local currentDischargeNode = self:getCurrentDischargeNode()
	if currentDischargeNode then
		return currentDischargeNode.isEffectActive
	end
	return false
end

function CombineAIDriver:isPotatoOrSugarBeetHarvester()
	for i, fillUnit in ipairs(self.vehicle:getFillUnits()) do
		if self.vehicle:getFillUnitSupportsFillType(i, FillType.POTATO) or
			self.vehicle:getFillUnitSupportsFillType(i, FillType.SUGARBEET) then
			self:debug('This is a potato or sugar beet harvester.')
			return true
		end
	end
	return false
end

--- Find a trailer we can use for self unloading
function CombineAIDriver:findBestTrailer()
	local bestTrailer, bestFillUnitIndex
	local minDistance = math.huge
	local maxCapacity = 0
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if SpecializationUtil.hasSpecialization(Trailer, vehicle.specializations) then
			local rootVehicle = vehicle:getRootVehicle()
			local attacherVehicle
			if SpecializationUtil.hasSpecialization(Attachable, vehicle.specializations) then
				attacherVehicle = vehicle.spec_attachable:getAttacherVehicle()
			end
			local fieldNum = PathfinderUtil.getFieldNumUnderVehicle(vehicle)
			local myFieldNum = PathfinderUtil.getFieldNumUnderVehicle(self.vehicle)
			local x, _, z = getWorldTranslation(vehicle.rootNode)
			local closestDistance = courseplay.fields:getClosestDistanceToFieldEdge(myFieldNum, x, z)
			local lastSpeed = rootVehicle:getLastSpeed()
			self:debug('%s is a trailer on field %d, closest distance to %d is %.1f, attached to %s, root vehicle is %s, last speed %.1f', vehicle:getName(),
					fieldNum, myFieldNum, closestDistance, attacherVehicle and attacherVehicle:getName() or 'none', rootVehicle:getName(), lastSpeed)
			-- consider only trailer on my field or close to my field
			if rootVehicle ~= self.vehicle and fieldNum == myFieldNum or myFieldNum == 0 or
					closestDistance < 20 and lastSpeed < 0.1 then
				local d = courseplay:distanceToObject(self.vehicle, vehicle)
				local canLoad, freeCapacity, fillUnitIndex = self:canLoadTrailer(vehicle)
				if d < minDistance and canLoad then
					bestTrailer = vehicle
					bestFillUnitIndex = fillUnitIndex
					minDistance = d
					maxCapacity = freeCapacity
				end
			end
		end
	end
	local fillRootNode
	if bestTrailer then
		fillRootNode = bestTrailer:getFillUnitExactFillRootNode(bestFillUnitIndex)
		self:debug('Best trailer is %s at %.1f meters, free capacity %d, root node %s', bestTrailer:getName(), minDistance, maxCapacity, tostring(fillRootNode))
		local bestFillNode = self:findBestFillNode(fillRootNode, self.pipeOffsetX)
		return bestTrailer, bestFillNode
	else
		self:info('Found no trailer to unload to.')
		return nil
	end
end

function CombineAIDriver:findBestFillNode(fillRootNode, offset)
	local dx, dy, dz = localToLocal(fillRootNode, AIDriverUtil.getDirectionNode(self.vehicle), offset, 0, 0)
	local dLeft = MathUtil.vector3Length(dx, dy, dz)
	dx, dy, dz = localToLocal(fillRootNode, AIDriverUtil.getDirectionNode(self.vehicle), -offset, 0, 0)
	local dRight = MathUtil.vector3Length(dx, dy, dz)
	self:debug('Trailer left side distance %d, right side %d', dLeft, dRight)
	if dLeft <= dRight then
		-- left side of the trailer is closer, so turn the fillRootNode around as the combine must approach the
		-- trailer from the front of the trailer
		-- (as always, we always persist nodes in aiDriverData so they survive the AIDriver object and won't leak)
		if not self.aiDriverData.bestFillNode then
			self.aiDriverData.bestFillNode = courseplay.createNode('bestFillNode', 0, 0, math.pi, fillRootNode)
		else
			unlink(self.aiDriverData.bestFillNode)
			link(fillRootNode, self.aiDriverData.bestFillNode)
			setRotation(self.aiDriverData.bestFillNode, 0, math.pi, 0)
		end
		return self.aiDriverData.bestFillNode
	else
		-- right side closer, combine approaches the trailer from the rear, driving the same direction as the getFillUnitExactFillRootNode
		return fillRootNode
	end
end

--- Find a path to the best trailer to unload
function CombineAIDriver:startSelfUnload()
	local bestTrailer, fillRootNode = self:findBestTrailer()
	if not bestTrailer then return false end

	if not self.pathfinder or not self.pathfinder:isActive() then
		self:rememberWaypointToContinueFieldwork()
		self.pathfindingStartedAt = self.vehicle.timer
		self.courseAfterPathfinding = nil
		self.waypointIxAfterPathfinding = nil
		local targetNode = fillRootNode or bestTrailer.rootNode
		local offsetX = -self.pipeOffsetX - 0.2
		local alignLength = 3
		-- arrive near the trailer alignLength meters behind the target, from there, continue straight a bit
		local offsetZ = -self.pipeOffsetZ - alignLength
		-- little straight section parallel to the trailer to align better
		self.selfUnloadAlignCourse = Course.createFromNode(self.vehicle, targetNode,
				offsetX, offsetZ + 1, offsetZ + 1 + alignLength, 1, false)

	local fieldNum = PathfinderUtil.getFieldNumUnderVehicle(self.vehicle)
		local done, path
		-- require full accuracy from pathfinder as we must exactly line up with the trailer
		self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(
				self.vehicle, targetNode, offsetX, offsetZ,
				self:getAllowReversePathfinding(),
				fieldNum, {}, nil, nil, nil, true)
		if done then
			return self:onPathfindingDone(path)
		else
			self:setPathfindingDoneCallback(self, self.onPathfindingDone)
		end
	else
		self:debug('Pathfinder already active')
	end
	return true
end

--- Back to fieldwork after self unloading
function CombineAIDriver:returnToFieldworkAfterSelfUnloading()
	if not self.pathfinder or not self.pathfinder:isActive() then
		self.pathfindingStartedAt = self.vehicle.timer
		self.courseAfterPathfinding = self.fieldworkCourse
		self.waypointIxAfterPathfinding = self.aiDriverData.continueFieldworkAtWaypoint
		self.selfUnloadAlignCourse = nil
		local done, path
		self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
				self.vehicle, self.fieldworkCourse:getWaypoint(self.waypointIxAfterPathfinding), 0,0,
				self:getAllowReversePathfinding(), nil)
		if done then
			return self:onPathfindingDone(path)
		else
			self:setPathfindingDoneCallback(self, self.onPathfindingDone)
		end
	else
		self:debug('Pathfinder already active')
	end
	return true
end

-- TODO: split this into two, depending on the call location, like in mode 2
function CombineAIDriver:onPathfindingDone(path)
	if path and #path > 2 then
		self:debug('(CombineAIDriver) Pathfinding finished with %d waypoints (%d ms)', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0))
		local selfUnloadCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		if self.selfUnloadAlignCourse then
			selfUnloadCourse:append(self.selfUnloadAlignCourse)
			self.selfUnloadAlignCourse = nil
		end
		self:startCourse(selfUnloadCourse, 1, self.courseAfterPathfinding, self.waypointIxAfterPathfinding)
		return true
	else
		self:debug('No path found in %d ms, no self unloading', self.vehicle.timer - (self.pathfindingStartedAt or 0))
		if self.fieldworkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD then
			self:startFieldworkWithPathfinding(self.aiDriverData.continueFieldworkAtWaypoint)
		elseif self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD then
			self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
		elseif self.fieldworkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED then
			self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED
		end
		return false
	end
end

--- Some of our turns need a short look ahead distance, make sure we restore the normal after the turn
function CombineAIDriver:resumeFieldworkAfterTurn(ix)
	self.ppc:setNormalLookaheadDistance()
	UnloadableFieldworkAIDriver.resumeFieldworkAfterTurn(self, ix)
end

--- Let unloaders register for events. This is different from the CombineUnloadManager registration, these
--- events are for the low level coordination between the combine and its unloader(s). CombineUnloadManager
--- takes care about coordinating the work between multiple combines.
function CombineAIDriver:clearAllUnloaderInformation()
	self:cancelRendezvous()
	-- the unloaders table hold all registered unloaders, key and value are both the unloader AIDriver
	self.unloaders = {}
end

--- Register a combine unload AI driver for notification about combine events
--- Unloaders can renew their registration as often as they want to make sure they remain registered.
---@param driver CombineUnloadAIDriver
function CombineAIDriver:registerUnloader(driver,noEventSend)
	self.unloaders[driver] = driver
	if not noEventSend then 
		UnloaderEvents:sendRegisterUnloaderEvent(driver,self)
	end
end

--- Deregister a combine unload AI driver from notificiations
---@param driver CombineUnloadAIDriver
function CombineAIDriver:deregisterUnloader(driver,noEventSend)
	self.unloaders[driver] = nil
	if not noEventSend then 
		UnloaderEvents:sendDeregisterUnloaderEvent(driver,self)
	end
end

--- Make life easier for unloaders, increase chopper discharge distance
function CombineAIDriver:fixDischargeDistance(dischargeNode)
	if self:isChopper() and dischargeNode and dischargeNode.maxDistance then
		local safeDischargeNodeMaxDistance = 40
		if dischargeNode.maxDistance < safeDischargeNodeMaxDistance then
			self:debug('Chopper maximum throw distance is %.1f, increasing to %.1f', dischargeNode.maxDistance, safeDischargeNodeMaxDistance)
			dischargeNode.maxDistance = safeDischargeNodeMaxDistance
		end
	end
end

--- Make life easier for unloaders, increases reach of the pipe
function CombineAIDriver:fixMaxRotationLimit()
	if self.pipe then
		local lastPipeNode = self.pipe.nodes and self.pipe.nodes[#self.pipe.nodes]
		if self:isChopper() and lastPipeNode and lastPipeNode.maxRotationLimits then
			self.oldLastPipeNodeMaxRotationLimit = lastPipeNode.maxRotationLimits
			self:debug('Chopper fix maxRotationLimits, old Values: x=%s, y= %s, z =%s', tostring(lastPipeNode.maxRotationLimits[1]), tostring(lastPipeNode.maxRotationLimits[2]), tostring(lastPipeNode.maxRotationLimits[3]))
			lastPipeNode.maxRotationLimits = nil
		end
	end
end

function CombineAIDriver:resetFixMaxRotationLimit()
	if self.pipe then
		local lastPipeNode = self.pipe.nodes and self.pipe.nodes[#self.pipe.nodes]
		if lastPipeNode and self.oldLastPipeNodeMaxRotationLimit then
			lastPipeNode.maxRotationLimits = self.oldLastPipeNodeMaxRotationLimit
			self:debug('Chopper: reset maxRotationLimits is x=%s, y= %s, z =%s', tostring(lastPipeNode.maxRotationLimits[1]), tostring(lastPipeNode.maxRotationLimits[3]), tostring(lastPipeNode.maxRotationLimits[3]))
			self.oldLastPipeNodeMaxRotationLimit = nil
		end
	end
end

--- Offset of the pipe from the combine implement's root node
---@param additionalOffsetX number add this to the offsetX if you don't want to be directly under the pipe. If
--- greater than 0 -> to the left, less than zero -> to the right
---@param additionalOffsetZ number forward (>0)/backward (<0) offset from the pipe
function CombineAIDriver:getPipeOffset(additionalOffsetX, additionalOffsetZ)
	return self.pipeOffsetX + (additionalOffsetX or 0), self.pipeOffsetZ + (additionalOffsetZ or 0)
end

--- Pipe side offset relative to course. This is to help the unloader
--- to find the pipe when we are waiting in a pocket
function CombineAIDriver:getPipeOffsetFromCourse()
	return self.pipeOffsetX, self.pipeOffsetZ
end

function CombineAIDriver:initUnloadStates()
	self.safeUnloadFieldworkStates = {
		self.states.WORKING,
		self.states.WAITING_FOR_LOWER,
		self.states.WAITING_FOR_LOWER_DELAYED,
		self.states.WAITING_FOR_STOP,
	}

	self.safeFieldworkUnloadOrRefillStates = {
		self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED,
		self.states.WAITING_FOR_UNLOAD_OR_REFILL,
		self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK,
		self.states.WAITING_FOR_UNLOAD_IN_POCKET,
		self.states.WAITING_FOR_UNLOAD_BEFORE_STARTING_NEXT_ROW
	}

	self.willWaitForUnloadToFinishFieldworkStates = {
		self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK,
		self.states.WAITING_FOR_UNLOAD_IN_POCKET,
		self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED,
		self.states.WAITING_FOR_UNLOAD_BEFORE_STARTING_NEXT_ROW
	}
end

function CombineAIDriver:isStateOneOf(myState, states)
	for _, state in ipairs(states) do
		if myState == state then
			return true
		end
	end
	return false
end

function CombineAIDriver:isFieldworkStateOneOf(states)
	if self.state ~= self.states.ON_FIELDWORK_COURSE then
		return false
	end
	return self:isStateOneOf(self.fieldworkState, states)
end

function CombineAIDriver:isFieldworkUnloadOrRefillStateOneOf(states)
	return self:isStateOneOf(self.fieldworkUnloadOrRefillState, states)
end

-- TODO: this whole logic is more relevant to the unloader maybe move it there?
function CombineAIDriver:getClosestFieldworkWaypointIx()
	if self:isTurning() then
		if self.turnContext then
			-- send turn start wp, unloader will decide if it needs to move it to the turn end or not
			return self.turnContext.turnStartWpIx
		else
			-- if for whatever reason we don't have a turn context, current waypoint is ok
			return self.fieldworkCourse:getCurrentWaypointIx()
		end
	elseif self.course:isTemporary() then
		return self.fieldworkCourse:getLastPassedWaypointIx()
	else
		-- if currently on the fieldwork course, this is the best estimate
		return self:getRelevantWaypointIx()
	end
end

--- Maneuvering means turning or working on a pocket or pulling back due to the pipe in fruit
--- We don't want to get too close to a maneuvering combine until it is done
function CombineAIDriver:isManeuvering()
	return self:isTurning() or
			(
					self.state == self.states.ON_FIELDWORK_COURSE and
							self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
							not self:isFieldworkUnloadOrRefillStateOneOf(self.safeFieldworkUnloadOrRefillStates)
			)
end

function CombineAIDriver:isOnHeadland(n)
	return self.state == self.states.ON_FIELDWORK_COURSE and
			self.fieldworkCourse:isOnHeadland(self.fieldworkCourse:getCurrentWaypointIx(), n)
end

--- Are we ready for an unloader?
--- @param noUnloadWithPipeInFruit boolean pipe must not be in fruit for unload
function CombineAIDriver:isReadyToUnload(noUnloadWithPipeInFruit)
	-- no unloading when not in a safe state (like turning)
	-- in these states we are always ready
	if self:willWaitForUnloadToFinish() then return true end

	-- but, if we are full and waiting for unload, we have no choice, we must be ready ...
	if self.state == self.states.ON_FIELDWORK_COURSE and
			self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
			self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL then
		return true
	end

	-- pipe is in the fruit.
	if noUnloadWithPipeInFruit and self:isPipeInFruit() then
		self:debugSparse('isReadyToUnload(): pipe in fruit')
		return false
	end

	if not self.fieldworkCourse then
		self:debugSparse('isReadyToUnload(): has no fieldwork course')
		return false
	end

    -- around a turn, for example already working on the next row but not done with the turn yet

	if self.fieldworkCourse:isCloseToNextTurn(10) then
		self:debugSparse('isReadyToUnload(): too close to turn')
		return false
	end
	-- safe default, better than block unloading
	self:debugSparse('isReadyToUnload(): defaulting to ready to unload')
	return true
end

--- Will not move until unload is done? Unloaders like to know this.
function CombineAIDriver:willWaitForUnloadToFinish()
	return self.state == self.states.ON_FIELDWORK_COURSE and
			self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
			((self.vehicle.cp.settings.stopForUnload:is(true) and self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL) or
					self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET or
					self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK or
					self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED)
end

function CombineAIDriver:shouldStrawSwathBeOn(ix)
	local strawMode = self.vehicle.cp.settings.strawSwath:get()
	local headland = self.course:isOnHeadland(ix)
	if self.combine.isSwathActive then 
		if strawMode == StrawSwathSetting.OFF or headland and strawMode==StrawSwathSetting.ONLY_CENTER then 
			self:setStrawSwath(false)
		end
	else
		if strawMode > StrawSwathSetting.OFF then 
			if headland and strawMode==StrawSwathSetting.ONLY_CENTER then 
				return
			end
			self:setStrawSwath(true)
		end
	end	
end

CombineAIDriver.maxBackDistance = 10

function CombineAIDriver:getMeasuredBackDistance()
	return self.measuredBackDistance
end

--- Determine how far the back of the combine is from the direction node
-- TODO: attached/towed harvesters
function CombineAIDriver:measureBackDistance()
	self.measuredBackDistance = 0
	-- raycast from a point behind the vehicle forward towards the direction node
	local nx, ny, nz = localDirectionToWorld(self.vehicle.rootNode, 0, 0, 1)
	local x, y, z = localToWorld(self.vehicle.rootNode, 0, 1.5, - self.maxBackDistance)
	raycastAll(x, y, z, nx, ny, nz, 'raycastBackCallback', self.maxBackDistance, self)
end

-- I believe this tries to figure out how far the back of a combine is from its direction node.
function CombineAIDriver:raycastBackCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and object == self.vehicle then
			local d = self.maxBackDistance - distance
			if d > self.measuredBackDistance then
				self.measuredBackDistance = d
				self:debug('Measured back distance is %.1f m', self.measuredBackDistance)
			end
		else
			return true
		end
	end
end

function CombineAIDriver:setStrawSwath(enable)
	local strawSwathCanBeEnabled = false
	local fruitType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(self.vehicle:getFillUnitFillType(self.combine.fillUnitIndex))
	if fruitType ~= nil and fruitType ~= FruitType.UNKNOWN then
		local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitType)
		if fruitDesc.hasWindrow then
			strawSwathCanBeEnabled = true
		end
		self.vehicle:setIsSwathActive(enable and strawSwathCanBeEnabled)
	end
end

function CombineAIDriver:onDraw()

	if not courseplay.debugChannels[courseplay.DBG_IMPLEMENTS] then return end

	local dischargeNode = self:getCurrentDischargeNode()
	if dischargeNode then
		DebugUtil.drawDebugNode(dischargeNode.node, 'discharge')
	end

	if self.aiDriverData.backMarkerNode then
		DebugUtil.drawDebugNode(self.aiDriverData.backMarkerNode, 'back marker')
	end

	local areaToAvoid = self:getAreaToAvoid()
	if areaToAvoid then
		local x, y, z = localToWorld(areaToAvoid.node, areaToAvoid.xOffset, 0, areaToAvoid.zOffset)
		cpDebug:drawLine(x, y + 1.2, z, 10, 10, 10, x, y + 1.2, z + areaToAvoid.length)
		cpDebug:drawLine(x + areaToAvoid.width, y + 1.2, z, 10, 10, 10, x + areaToAvoid.width, y + 1.2, z + areaToAvoid.length)
	end

	UnloadableFieldworkAIDriver.onDraw(self)
end

-- For combines, we use the collision trigger of the header to cover the whole vehicle width
function CombineAIDriver:createTrafficConflictDetector()
	-- (not everything running as combine has a cutter, for instance the Krone Premos)
	if self.combine.attachedCutters then
		for cutter, _ in pairs(self.combine.attachedCutters) do
			-- attachedCutters is indexed by the cutter, not an integer
			self.trafficConflictDetector = TrafficConflictDetector(self.vehicle, self.course, cutter)
			-- for now, combines ignore traffic conflicts (but still provide the detector boxes for other vehicles)
			self.trafficConflictDetector:disableSpeedControl()
			return
		end
	end
	self.trafficConflictDetector = TrafficConflictDetector(self.vehicle, self.course)
	-- for now, combines ignore traffic conflicts (but still provide the detector boxes for other vehicles)
	self.trafficConflictDetector:disableSpeedControl()
end

-- and our forward proximity sensor covers the entire working width
function CombineAIDriver:addForwardProximitySensor()
	self:setFrontMarkerNode(self.vehicle)
	self.forwardLookingProximitySensorPack = WideForwardLookingProximitySensorPack(
			self.vehicle, self.ppc, self:getFrontMarkerNode(self.vehicle), self.proximitySensorRange, 1, self.vehicle.cp.workWidth)
end

--- Check the vehicle in the proximity sensor's range. If it is player driven, don't slow them down when hitting this
--- vehicle.
--- Note that we don't really know if the player is to unload the combine, this will disable all proximity check for
--- player driven vehicles.
function CombineAIDriver:isProximitySlowDownEnabled(vehicle)
	-- if not on fieldwork, always enable slowing down
	if self.state ~= self.states.ON_FIELDWORK_COURSE then return true end

	-- CP drives other vehicle, it'll take care of everything, including enable/disable
	-- the proximity sensor when unloading
	if vehicle.cp.driver and vehicle.cp.driver.isActive and vehicle.cp.driver:isActive() then return true end

	-- vehicle:getIsControlled() is needed as this one gets synchronized 
	if vehicle and vehicle.getIsEntered and (vehicle:getIsEntered() or vehicle:getIsControlled()) then
		self:debugSparse('human player in nearby %s not driven by CP so do not slow down for it', nameNum(vehicle))
		-- trust the player to avoid collisions
		return false
	else
		return true
	end
end
