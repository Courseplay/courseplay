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

CombineAIDriver.myStates = {
	PULLING_BACK_FOR_UNLOAD = {},
	WAITING_FOR_UNLOAD_AFTER_PULLED_BACK = {},
	RETURNING_FROM_PULL_BACK = {},
	REVERSING_TO_MAKE_A_POCKET = {},
	MAKING_POCKET = {},
	WAITING_FOR_UNLOAD_IN_POCKET = {},
	WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED = {},
	WAITING_FOR_UNLOADER_TO_LEAVE = {},
	RETURNING_FROM_POCKET = {},
	DRIVING_TO_SELF_UNLOAD = {},
	SELF_UNLOADING = {},
	DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED = {},
	SELF_UNLOADING_AFTER_FIELDWORK_ENDED = {},
	RETURNING_FROM_SELF_UNLOAD = {}
}

CombineAIDriver.turnTypes = {
	HEADLAND_NORMAL = {},
	HEADLAND_EASY = {},
	HEADLAND_POCKET = {},
	UP_DOWN_NORMAL = {}
}

function CombineAIDriver:init(vehicle)
	courseplay.debugVehicle(11, vehicle, 'CombineAIDriver:init()')
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
				self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_OPEN)
				self.objectWithPipe:updatePipeNodes(999999, nil)
			end
		end
		local dischargeNode = self.combine:getCurrentDischargeNode()
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
				self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
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

	-- distance to keep to the right when pulling back to make room for the tractor
	self.pullBackSideOffset = self.pipeOffsetX - self.vehicle.cp.workWidth / 2 + 5
	self.pullBackSideOffset = self.pipeOnLeftSide and self.pullBackSideOffset or -self.pullBackSideOffset
	-- should be at pullBackSideOffset to the right at pullBackDistanceStart
	self.pullBackDistanceStart = self.vehicle.cp.turnDiameter --* 0.7
	-- and back up another bit
	self.pullBackDistanceEnd = self.pullBackDistanceStart + 5
	-- when making a pocket, how far to back up before changing to forward
	self.pocketReverseDistance = 25
	-- register ourselves at our boss
	g_combineUnloadManager:addCombineToList(self.vehicle, self)
	self:measureBackDistance()
end

--- Get the combine object, this can be different from the vehicle in case of tools towed or mounted on a tractor
function CombineAIDriver:getCombine()
	return self.combine
end

function CombineAIDriver:postSync()
	--TODO: figure out if we need this or not for multiplayer ??
end

function CombineAIDriver:start(startingPoint)
	self:clearAllUnloaderInformation()
	self:addBackwardProximitySensor()
	UnloadableFieldworkAIDriver.start(self, startingPoint)
	self:fixMaxRotationLimit()
	local total, pipeInFruit = self.fieldworkCourse:setPipeInFruitMap(self.pipeOffsetX, self.vehicle.cp.workWidth)
	self:debug('Pipe in fruit map created, there are %d non-headland waypoints, of which at %d the pipe will be in the fruit',
			total, pipeInFruit)
end

function CombineAIDriver:stop(msgReference)
	self:resetFixMaxRotationLimit()
	AIDriver.stop(self,msgReference)
end

function CombineAIDriver:setHudContent()
	UnloadableFieldworkAIDriver.setHudContent(self)
	courseplay.hud:setCombineAIDriverContent(self.vehicle)
end

function CombineAIDriver:drive(dt)
	-- handle the pipe in any state
	self:handlePipe()
	if self.isChopperWaitingForTrailer then
		-- Give up all reservations while not moving (and do not reserve anything)
		self:resetTrafficControl()
	elseif not self:trafficControlOK() then
		self:debugSparse('would be holding due to traffic')
		--self:hold()
	end
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
		-- reset offset to return to the original up/down row after we unloaded in the pocket
		self.aiDriverOffsetX = 0
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
	if self.vehicle.cp.settings.useRealisticDriving:is(true) then
		self:checkFruit()
		-- TODO: check around turn maneuvers we may not want to pull back before a turn
		if self.vehicle.cp.settings.selfUnload:is(true) and self:startSelfUnload() then
			self:debug('Start self unload')
			self:raiseImplements()
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldworkUnloadOrRefillState = self.states.DRIVING_TO_SELF_UNLOAD
			self.ppc:setShortLookaheadDistance()
			self:disableCollisionDetection()
		elseif self:shouldMakePocket() then
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
		elseif self:shouldPullBack() then
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
	else
		UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
	end
end

function CombineAIDriver:driveFieldwork(dt)
	if self.fieldworkState == self.states.WORKING then
		if self.agreedUnloaderRendezvousWaypointIx then
			local d = self.fieldworkCourse:getDistanceBetweenWaypoints(self.fieldworkCourse:getCurrentWaypointIx(),
					self.agreedUnloaderRendezvousWaypointIx)
			if d < 10 then
				self:debugSparse('Slow down around the unloader rendezvous waypoint %d to let the unloader catch up',
					self.agreedUnloaderRendezvousWaypointIx)
				self:setSpeed(self:getWorkSpeed() / 2)
			end
		end
	end
	self:checkBlockingUnloader()
	return UnloadableFieldworkAIDriver.driveFieldwork(self, dt)
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
			self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK then
		if self:unloadFinished() then
			self:clearInfoText(self:getFillLevelInfoText())
			-- wait a bit after the unload finished to give a chance to the unloader to move away
			self.stateBeforeWaitingForUnloaderToLeave = self.fieldworkUnloadOrRefillState
			self.fieldworkUnloadOrRefillState = self.states.WAITING_FOR_UNLOADER_TO_LEAVE
			self.waitingForUnloaderSince = self.vehicle.timer
			self:debug('Unloading finished, wait for the unloader to leave...')
		else
			self:setSpeed(0)
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
			self.aiDriverOffsetX = self.pullBackSideOffset
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
	self.fruitLeft, self.fruitRight = AIVehicleUtil.getValidityOfTurnDirections(self.vehicle)
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
	local dUntilFull = litersUntilFull / self.litersPerMeter
	self.secondsUntilFull = self.litersPerSecond > 0 and (litersUntilFull / self.litersPerSecond) or nil
	self.waypointIxWhenFull = self.course:getNextWaypointIxWithinDistance(ix, dUntilFull) or self.course:getNumberOfWaypoints()
	self.waypointIxWhenFull = self:getSafeUnloaderDestinationWaypoint(self.waypointIxWhenFull)
	self.distanceToWaypointWhenFull =
		self.course:getDistanceBetweenWaypoints(self.waypointIxWhenFull, self.course:getCurrentWaypointIx())
	self:debug('Will be full at waypoint %d in %d m',
			self.waypointIxWhenFull or -1, self.distanceToWaypointWhenFull)
end

---@param unloaderEstimatedSecondsEnroute number minimum time the unloader needs to get to the combine
---@return Waypoint, number, number waypoint to meet the unloader, index of waypoint, time we need to reach that waypoint
function CombineAIDriver:getUnloaderRendezvousWaypoint(unloaderEstimatedSecondsEnroute)

	local dToUnloaderRendezvous = unloaderEstimatedSecondsEnroute * self:getWorkSpeed() / 3.6
	local unloaderRendezvousWaypointIx = self.fieldworkCourse:getNextWaypointIxWithinDistance(self.fieldworkCourse:getCurrentWaypointIx(),
			dToUnloaderRendezvous) or self.fieldworkCourse:getNumberOfWaypoints()

	self:debug('Seconds until full: %d, unloader ETE: %d', self.secondsUntilFull or -1, unloaderEstimatedSecondsEnroute)

	if not self.secondsUntilFull or (self.secondsUntilFull and self.secondsUntilFull > unloaderEstimatedSecondsEnroute) then
		-- unloader will reach us before we are full, or we don't know where we'll be full, guess at which waypoint we will be by then
		unloaderRendezvousWaypointIx = self:getSafeUnloaderDestinationWaypoint(unloaderRendezvousWaypointIx)
		if self:canUnloadWhileMovingAtWaypoint(unloaderRendezvousWaypointIx) then
			self.agreedUnloaderRendezvousWaypointIx = unloaderRendezvousWaypointIx
			self:debug('Rendezvous with unloader at waypoint %d in %d m', unloaderRendezvousWaypointIx, dToUnloaderRendezvous)
			return self.fieldworkCourse:getWaypoint(unloaderRendezvousWaypointIx), unloaderRendezvousWaypointIx, unloaderEstimatedSecondsEnroute
		else
			return nil, 0, 0
		end
	elseif self.waypointIxWhenFull then
		self:debug('We don\'t know when exactly we\'ll be full, but it will be at waypoint %d in %d m, reject rendezvous',
				self.waypointIxWhenFull, self.distanceToWaypointWhenFull)
		if self:canUnloadWhileMovingAtWaypoint(unloaderRendezvousWaypointIx) then
			self.agreedUnloaderRendezvousWaypointIx = self.waypointIxWhenFull
			-- TODO: figure out what to do in this case, it does not seem to make sense to send the unloader to
			-- a distant waypoint
			return nil, 0, 0
			-- return self.fieldworkCourse:getWaypoint(self.waypointIxWhenFull), self.waypointIxWhenFull, self.distanceToWaypointWhenFull / (self:getWorkSpeed() / 3.6)
		else
			return nil, 0, 0
		end
	else
		self:debug('We don\t know when exactly we\'ll be full, reject rendezvous')
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

--- Check if ix is a safe destination for an unloader, return an adjusted ix if not
---@param ix number waypoint index to check
---@return number waypoint index adjusted if needed
function CombineAIDriver:getSafeUnloaderDestinationWaypoint(ix)
	local newWpIx = ix
	if self.fieldworkCourse:isTurnStartAtIx(ix) then
		if self.fieldworkCourse:isOnHeadland(ix) then
			-- on the headland, use the wp after the turn, the one before may be very far, especially on a
			-- transition from headland to up/down rows.
			newWpIx = ix + 1
		else
			-- turn start waypoints usually aren't safe as they point to the turn end direction in 180 turns
			-- so use the one before
			newWpIx = ix - 1
		end
	else

	end
	-- if we ended up on a turn start WP and the row is long enough, move it a bit forward so the unloader does
	-- not drive much off the field to align with it
	if self.fieldworkCourse:isTurnStartAtIx(newWpIx) and self.fieldworkCourse:getDistanceToNextTurn(newWpIx) > 20 then
		-- TODO: get the guess factor out of this (2 wp distance < 20 m)
		newWpIx = newWpIx + 2
	end

	return newWpIx
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
---@param waypointIxWhenFull number estimated waypoint index when full based on current fruit flow and distance
---@return number best waypoint to unload. What is a good point to unload:
function CombineAIDriver:findBestWaypointToUnload(waypointIxWhenFull)
	if self.course:isOnHeadland(waypointIxWhenFull) then
		return self:findBestWaypointToUnloadOnHeadland(waypointIxWhenFull)
	else
		return self:findBestWaypointToUnloadOnUpDownRows(waypointIxWhenFull)
	end
end

function CombineAIDriver:findBestWaypointToUnloadOnHeadland(waypointIxWhenFull)
	return waypointIxWhenFull
end

function CombineAIDriver:findBestWaypointToUnloadOnUpDownRows(waypointIxWhenFull)
	local dToNextTurn = self.course:getDistanceToNextTurn(waypointIxWhenFull) or 0
	local lRow, ixAtTurnEnd = self.course:getRowLength(waypointIxWhenFull)
	local pipeInFruit, _ = self:isPipeInFruitAtWaypoint(self.course, waypointIxWhenFull)
	self:debug('Estimated waypoint when full: %d on up/down row, pipe in fruit %s, dToNextTurn: %d m, lRow = %d m',
				waypointIxWhenFull, tostring(pipeInFruit), dToNextTurn, lRow or 0)
	if pipeInFruit then
		self:debug('Pipe would be in fruit where we will be full. Check previous row')
		if ixAtTurnEnd and ixAtTurnEnd > self.course:getCurrentWaypointIx() then
			pipeInFruit, _ = self:isPipeInFruitAtWaypoint(self.course, ixAtTurnEnd - 1)
			if not pipeInFruit then
				local lPreviousRow = self.course:getRowLength(ixAtTurnEnd - 1)
				self:debug('pipe not in fruit in the previous row (%d m, ending at wp %d), so unload there if long enough',
						lPreviousRow, ixAtTurnEnd - 1)
				return ixAtTurnEnd - 3
			end
		end
	else
		self:debug('pipe is not in fruit where we are full. If it is towards the end of the row, bring it up a bit')
		-- so we'll have some distance for unloading
		if ixAtTurnEnd and dToNextTurn < lRow / 2 then
			return ixAtTurnEnd + 1
		end
	end
	-- no better idea, just use the original estimated
	return waypointIxWhenFull
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

	local x1, _, z1 = localToWorld(self:getDirectionNode(), -self.pullBackSideOffset, 0, -self.pullBackDistanceStart)
	local x2, _, z2 = localToWorld(self:getDirectionNode(), -self.pullBackSideOffset, 0, -self.pullBackDistanceEnd)
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
				-self.pullBackSideOffset, 0, -self.pullBackDistanceEnd, -2, true)
	else
		self:debug("Pull back course would be outside of the field")
		return nil
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
	self.turnContext = TurnContext(self.course, ix, self.aiDriverData, self.vehicle.cp.workWidth, self.frontMarkerDistance,
			self:getTurnEndSideOffset(), self:getTurnEndForwardOffset())

	-- Combines drive special headland corner maneuvers, except potato and sugarbeet harvesters
	if self.turnContext:isHeadlandCorner() then
		if self:isPotatoOrSugarBeetHarvester() then
			self:debug('Headland turn but this harvester uses normal turn maneuvers.')
			self.turnType = self.turnTypes.HEADLAND_NORMAL
			UnloadableFieldworkAIDriver.startTurn(self, ix)
		elseif self.course:isOnOutermostHeadland(ix) and self.vehicle.cp.settings.turnOnField:is(true) then
			self:debug('Creating a pocket in the corner so the combine stays on the field during the turn')
			self.aiTurn = CombinePocketHeadlandTurn(self.vehicle, self, self.turnContext, self.fieldworkCourse)
			self.turnType = self.turnTypes.HEADLAND_POCKET
			self.fieldworkState = self.states.TURNING
			self.ppc:setShortLookaheadDistance()
		else
			self:debug('Use combine headland turn.')
			self.aiTurn = CombineHeadlandTurn(self.vehicle, self, self.turnContext)
			self.turnType = self.turnTypes.HEADLAND_EASY
			self.fieldworkState = self.states.TURNING
		end
	else
		self:debug('Non headland turn.')
		self.turnType = self.turnTypes.UP_DOWN_NORMAL
		UnloadableFieldworkAIDriver.startTurn(self, ix)
	end

	self:sendTurnStartEventToUnloaders(ix, self.turnType)

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

---@param turnType table one of CombineAIDriver.turnTypes
function CombineAIDriver:isHeadlandTurn(turnType)
	return turnType ~= CombineAIDriver.turnTypes.UP_DOWN_NORMAL
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


--- Create a pocket in the next row at the corner to stay on the field during the turn maneuver.
---@param turnContext TurnContext
function CombineAIDriver:createOuterHeadlandCornerCourse(turnContext)
	local cornerWaypoints = {}
	local turnRadius = self.vehicle.cp.turnDiameter / 2
	-- this is how far we have to cut into the next headland (the position where the header will be after the turn)
	local offset = math.min(turnRadius + self.frontMarkerDistance,  self.vehicle.cp.workWidth)
	local corner = turnContext:createCorner(self.vehicle, turnRadius)
	local d = -self.vehicle.cp.workWidth / 2 + self.frontMarkerDistance
	local wp = corner:getPointAtDistanceFromCornerStart(d + 2)
	wp.speed = self.vehicle.cp.speeds.turn * 0.75
	table.insert(cornerWaypoints, wp)
	-- drive forward up to the field edge
	wp = corner:getPointAtDistanceFromCornerStart(d)
	wp.speed = self.vehicle.cp.speeds.turn * 0.75
	table.insert(cornerWaypoints, wp)
	-- drive back to prepare for making a pocket
	-- reverse back to set up for the headland after the corner
	local reverseDistance = 2 * offset
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance / 2)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	-- now make a pocket in the inner headland to make room to turn
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance * 0.75, -offset * 0.75)
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance * 0.5, -offset * 0.9)
	if not courseplay:isField(wp.x, wp.z) then
		self:debug('No field where the pocket would be, this seems to be a 270 corner')
		corner:delete()
		return nil
	end
	table.insert(cornerWaypoints, wp)
	-- drive forward to the field edge on the inner headland
	wp = corner:getPointAtDistanceFromCornerStart(d, -offset)
	wp.speed = self.vehicle.cp.speeds.turn * 0.75
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance / 2)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerEnd(turnRadius / 3, turnRadius / 4)
	wp.speed = self.vehicle.cp.speeds.turn * 0.5
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerEnd(turnRadius, turnRadius / 4)
	wp.speed = self.vehicle.cp.speeds.turn * 0.5
	table.insert(cornerWaypoints, wp)
	corner:delete()
	return Course(self.vehicle, cornerWaypoints, true), turnContext.turnEndWpIx
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

-- even if there is a trailer in range, we should not start moving until the pipe is turned towards the
-- trailer and can start discharging. This returning true does not mean there's a trailer under the pipe,
-- this seems more like for choppers to check if there's a potential target around
function CombineAIDriver:canDischarge()
	-- TODO: self.vehicle should be the combine, which may not be the vehicle in case of towed harvesters
	local dischargeNode = self.combine:getCurrentDischargeNode()
	local targetObject, _ = self.combine:getDischargeTargetObject(dischargeNode)
	return targetObject
end

function CombineAIDriver:isDischarging()
	if self.combine then
		local currentDischargeNode = self.combine:getCurrentDischargeNode()
		return currentDischargeNode and currentDischargeNode.isEffectActive
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
			local fieldNum = courseplay.fields:onWhichFieldAmI(vehicle)
			local myFieldNum = courseplay.fields:onWhichFieldAmI(self.vehicle)
			local x, _, z = getWorldTranslation(vehicle.rootNode)
			local closestDistance = courseplay.fields:getClosestDistanceToFieldEdge(myFieldNum, x, z)
			local lastSpeed = rootVehicle:getLastSpeed()
			self:debug('%s is a trailer on field %d, closest distance to %d is %.1f, attached to %s, root vehicle is %s, last speed %.1f', vehicle:getName(),
					fieldNum, myFieldNum, closestDistance, attacherVehicle and attacherVehicle:getName() or 'none', rootVehicle:getName(), lastSpeed)
			-- consider only trailer on my field or close to my field
			if fieldNum == myFieldNum or myFieldNum == 0 or closestDistance < 20 and lastSpeed < 0.1 then
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
		local fieldNum = courseplay.fields:onWhichFieldAmI(self.vehicle)
		local done, path
		self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(
				self.vehicle, fillRootNode or bestTrailer.rootNode, -self.pipeOffsetX - 0.2, -self.pipeOffsetZ, true, fieldNum)
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
		local done, path
		self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
				self.vehicle, self.fieldworkCourse:getWaypoint(self.waypointIxAfterPathfinding), 0,0,true, nil)
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

function CombineAIDriver:onPathfindingDone(path)
	if path and #path > 2 then
		self:debug('(CombineAIDriver) Pathfinding finished with %d waypoints (%d ms)', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0))
		local selfUnloadCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
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
	self.agreedUnloaderRendezvousWaypointIx = nil
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

function CombineAIDriver:sendTurnStartEventToUnloaders(ix, turnType)
	for _, unloader in pairs(self.unloaders) do
		if unloader then unloader:onCombineTurnStart(ix, turnType) end
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
	local LastPipeNode = self.pipe.nodes and self.pipe.nodes[#self.pipe.nodes]
	if self:isChopper() and LastPipeNode and LastPipeNode.maxRotationLimits then
		self.oldLastPipeNodeMaxRotationLimit = LastPipeNode.maxRotationLimits
        self:debug('Chopper fix maxRotationLimits, old Values: x=%s, y= %s, z =%s', tostring(LastPipeNode.maxRotationLimits[1]), tostring(LastPipeNode.maxRotationLimits[2]), tostring(LastPipeNode.maxRotationLimits[3]))
        LastPipeNode.maxRotationLimits = nil   
    end
end

function CombineAIDriver:resetFixMaxRotationLimit()
	local LastPipeNode = self.pipe.nodes and self.pipe.nodes[#self.pipe.nodes]
	if LastPipeNode and self.oldLastPipeNodeMaxRotationLimit then 
		LastPipeNode.maxRotationLimits = self.oldLastPipeNodeMaxRotationLimit
		self:debug('Chopper: reset maxRotationLimits is x=%s, y= %s, z =%s', tostring(LastPipeNode.maxRotationLimits[1]), tostring(LastPipeNode.maxRotationLimits[3]), tostring(LastPipeNode.maxRotationLimits[3]))
		self.oldLastPipeNodeMaxRotationLimit = nil
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
		self.states.WAITING_FOR_UNLOAD_IN_POCKET
	}

	self.willWaitForUnloadToFinishFieldworkStates = {
		self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK,
		self.states.WAITING_FOR_UNLOAD_IN_POCKET,
		self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED,
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
	local strawSwath = self.combine.isSwathActive 
	local headlandStraw = self.vehicle.cp.settings.strawOnHeadland:is(true)
	local headland = self.course:isOnHeadland(ix)

	-- Do not check headland or set swath if combine is set to no swath
	if strawSwath then
		if not headland or (headland and headlandStraw) then
			strawSwath = true
		else
			strawSwath = false
		end

		self:setStrawSwath(strawSwath)
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
	local nx, ny, nz = localDirectionToWorld(self:getDirectionNode(), 0, 0, 1)
	local x, y, z = localToWorld(self:getDirectionNode(), 0, 1.5, - self.maxBackDistance)
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

	if not courseplay.debugChannels[6] then return end

	local dischargeNode = self.combine:getCurrentDischargeNode()
	if dischargeNode then
		DebugUtil.drawDebugNode(dischargeNode.node, 'discharge')
	end

	UnloadableFieldworkAIDriver.onDraw(self)
end
