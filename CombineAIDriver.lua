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

-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
CombineAIDriver.PIPE_STATE_MOVING = 0
CombineAIDriver.PIPE_STATE_CLOSED = 1
CombineAIDriver.PIPE_STATE_OPEN = 2

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

function CombineAIDriver:init(vehicle)
	courseplay.debugVehicle(11, vehicle, 'CombineAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self:initStates(CombineAIDriver.myStates)
	self.fruitLeft, self.fruitRight = 0, 0
	self.litersPerMeter = 0
	self.fillLevelAtLastWaypoint = 0
	self.beaconLightsActive = false
	self.lastEmptyTimestamp = 0
	self.pipeOffsetX = 0

	if self.vehicle.spec_combine then
		self.combine = self.vehicle.spec_combine
	else
		local combineImplement = FieldworkAIDriver.getImplementWithSpecialization(self.vehicle, Combine)
		if combineImplement then
			self.combine = combineImplement.spec_combine
		else
			self:error('Vehicle is not a combine and could not find implement with spec_combine')
		end
	end

	if self.vehicle.spec_pipe then
		self.pipe = self.vehicle.spec_pipe
		self.objectWithPipe = self.vehicle
	else
		local implementWithPipe = FieldworkAIDriver.getImplementWithSpecialization(self.vehicle, Pipe)
		if implementWithPipe then
			self.pipe = implementWithPipe.spec_pipe
			self.objectWithPipe = implementWithPipe
		else
			self:info('Could not find implement with pipe')
		end
	end

	if self.pipe then
		local dischargeNode = self.combine:getCurrentDischargeNode()
		local dx, _, _ = localToLocal(dischargeNode.node, self.vehicle.rootNode, 0, 0, 0)
		self.pipeOnLeftSide = dx > 0
		self:debug('Pipe on left side %s', tostring(self.pipeOnLeftSide))
		-- check the pipe length:
		-- unfold everything, open the pipe, check the side offset, then close pipe, fold everything back (if it was folded)
		local wasFolded, wasClosed
		if self.vehicle.spec_foldable then
			wasFolded = not self.vehicle.spec_foldable:getIsUnfolded()
			if wasFolded then
				Foldable.setAnimTime(self.vehicle.spec_foldable, 0, true)
			end
		end
		if self.pipe.currentState == CombineAIDriver.PIPE_STATE_CLOSED then
			wasClosed = true
			if self.pipe.animation.name then
				self.pipe:setAnimationTime(self.pipe.animation.name, 1, true)
			else
				-- if there's no animation we have to use this, as seen in the Giants pipe code
				self.objectWithPipe:setPipeState(CombineAIDriver.PIPE_STATE_OPEN)
				self.objectWithPipe:updatePipeNodes(999999, nil)
			end
		end
		self.pipeOffsetX, _, self.pipeOffsetZ = localToLocal(dischargeNode.node, AIDriverUtil.getDirectionNode(self.vehicle), 0, 0, 0)
		self:debug('Pipe offset: x = %.1f, z = %.1f', self.pipeOffsetX, self.pipeOffsetZ)
		if wasClosed then
			if self.pipe.animation.name then
				self.pipe:setAnimationTime(self.pipe.animation.name, 0, true)
			else
				self.objectWithPipe:setPipeState(CombineAIDriver.PIPE_STATE_CLOSED)
				self.objectWithPipe:updatePipeNodes(999999, nil)
			end
		end
		if self.vehicle.spec_foldable then
			if wasFolded then
				Foldable.setAnimTime(self.vehicle.spec_foldable, 1, true)
			end
		end
	else
		self.pipeOnLeftSide = true
	end

	-- distance keep to the right when pulling back to make room for the tractor
	self.pullBackSideOffset = self.pipeOffsetX - self.vehicle.cp.workWidth / 2 + 2
	self.pullBackSideOffset = self.pipeOnLeftSide and self.pullBackSideOffset or -self.pullBackSideOffset
	-- should be at pullBackSideOffset to the right at pullBackDistanceStart
	self.pullBackDistanceStart = self.vehicle.cp.turnDiameter * 0.7
	-- and back up another bit
	self.pullBackDistanceEnd = self.pullBackDistanceStart + 10
	-- when making a pocket, how far to back up before changing to forward
	self.pocketReverseDistance = 25
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
		if self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD then
			self:debug('Self unloading point reached, fill level %.1f.', fillLevel)
			self.fieldWorkUnloadOrRefillState = self.states.SELF_UNLOADING
		elseif 	self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED then
			self:debug('Self unloading point reached after fieldwork ended, fill level %.1f.', fillLevel)
			self.fieldWorkUnloadOrRefillState = self.states.SELF_UNLOADING_AFTER_FIELDWORK_ENDED
		end
	elseif self.state == self.states.ON_FIELDWORK_COURSE and fillLevel > 0 then
		if self.vehicle.cp.settings.selfUnload:is(true) and self:startSelfUnload() then
			self:raiseImplements()
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldWorkUnloadOrRefillState = self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED
			self.ppc:setShortLookaheadDistance()
			self:disableCollisionDetection()
		else
			self:setInfoText(self:getFillLevelInfoText())
			-- let AutoDrive know we are done and can unload
			self:debug('Fieldwork done, fill level is %.1f, now waiting to be unloaded.', fillLevel)
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED
		end
	else
		UnloadableFieldworkAIDriver.onEndCourse(self)
	end
end

function CombineAIDriver:onWaypointPassed(ix)
	if self.state == self.states.ON_FIELDWORK_COURSE and
			(self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD or
			self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED or
			self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD) then
		-- nothing to do while driving to unload and back
		return UnloadableFieldworkAIDriver.onWaypointPassed(self, ix)
	end
	self:checkFruit()
	-- make sure we start making a pocket while we still have some fill capacity left as we'll be
	-- harvesting fruit while making the pocket unless we have self unload turned on
	if self:shouldMakePocket() and self.vehicle.cp.settings.selfUnload:is(false) then
		self.fillLevelFullPercentage = self.pocketFillLevelFullPercentage
	end
	self:checkDistanceUntilFull(ix)
	if self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldWorkUnloadOrRefillState == self.states.MAKING_POCKET and
		self.unloadInPocketIx and ix == self.unloadInPocketIx then
		-- we are making a pocket and reached the waypoint where we are going to stop and wait for unload
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
		self:debug('Waiting for unload in the pocket')
		self:setInfoText(self:getFillLevelInfoText())
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_IN_POCKET
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

function CombineAIDriver:changeToFieldworkUnloadOrRefill()
	if self.vehicle.cp.realisticDriving then
		self:checkFruit()
		-- TODO: check around turn maneuvers we may not want to pull back before a turn
		if self.vehicle.cp.settings.selfUnload:is(true) and self:startSelfUnload() then
			self:raiseImplements()
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldWorkUnloadOrRefillState = self.states.DRIVING_TO_SELF_UNLOAD
			self.ppc:setShortLookaheadDistance()
			self:disableCollisionDetection()
			self:rememberWaypointToContinueFieldwork()
		elseif self:shouldMakePocket() then
			-- I'm on the edge of the field or fruit is on both sides, make a pocket on the right side and wait there for the unload
			local pocketCourse, nextIx = self:createPocketCourse()
			if pocketCourse then
				self:debug('No room to the left, making a pocket for unload')
				self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
				self.fieldWorkUnloadOrRefillState = self.states.REVERSING_TO_MAKE_A_POCKET
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
				self:debug('Pipe in fruit, pulling back to make room for unloading')
				self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
				self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_STOP
				self.courseAfterPullBack = self.course
				self.ixAfterPullBack = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
				-- tighter turns
				self.ppc:setShortLookaheadDistance()
				self:startCourse(pullBackCourse, 1, self.course, self.ixAfterPullBack)
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

--- Stop for unload/refill while driving the fieldwork course
function CombineAIDriver:driveFieldworkUnloadOrRefill()
	if self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_STOP then
		self:setSpeed(0)
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('Raise implements and start pulling back')
			self:raiseImplements()
			self.fieldWorkUnloadOrRefillState = self.states.PULLING_BACK_FOR_UNLOAD
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldWorkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldWorkUnloadOrRefillState == self.states.MAKING_POCKET then
		self:setSpeed(self:getWorkSpeed())
	elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
		self:setSpeed(self.vehicle.cp.speeds.turn)
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET or
			self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK then
		if self:unloadFinished() then
			self:clearInfoText(self:getFillLevelInfoText())
			-- wait a bit after the unload finished to give a chance to the unloader to move away
			self.stateBeforeWaitingForUnloaderToLeave = self.fieldWorkUnloadOrRefillState
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOADER_TO_LEAVE
			self.waitingForUnloaderSince = self.vehicle.timer
			self:debug('Unloading finished, wait for the unloader to leave...')
		else
			self:setSpeed(0)
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED then
		local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
		if fillLevel < 0.01 then
			self:clearInfoText(self:getFillLevelInfoText())
			self:debug('Unloading finished after fieldwork ended, end course')
			UnloadableFieldworkAIDriver.onEndCourse(self)
		else
			self:setSpeed(0)
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOADER_TO_LEAVE then
		self:setSpeed(0)
		-- TODO: instead of just wait a few seconds we could check if the unloader has actually left
		if self.waitingForUnloaderSince + 5000 < self.vehicle.timer then
			if self.stateBeforeWaitingForUnloaderToLeave == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK then
				local pullBackReturnCourse  = self:createPullBackReturnCourse()
				if pullBackReturnCourse then
					self.fieldWorkUnloadOrRefillState = self.states.RETURNING_FROM_PULL_BACK
					self:debug('Unloading finished, returning to fieldwork on return course')
					self:startCourse(pullBackReturnCourse, 1, self.courseAfterPullBack, self.ixAfterPullBack)
				else
					self:debug('Unloading finished, returning to fieldwork directly')
					self.ppc:setNormalLookaheadDistance()
					self:changeToFieldwork()
				end
			elseif self.stateBeforeWaitingForUnloaderToLeave == self.states.WAITING_FOR_UNLOAD_IN_POCKET then
				self:debug('Unloading in pocket finished, returning to fieldwork')
				self.fillLevelFullPercentage = self.normalFillLevelFullPercentage
				self:changeToFieldwork()
			end
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.field)
	elseif self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED then
		self:setSpeed(self.vehicle.cp.speeds.field)
	elseif self.fieldWorkUnloadOrRefillState == self.states.SELF_UNLOADING then
		self:setSpeed(0)
		if self:unloadFinished() then
			self:debug('Self unloading finished, returning to fieldwork')
			if self:returnToFieldworkAfterSelfUnloading() then
				self.fieldWorkUnloadOrRefillState = self.states.RETURNING_FROM_SELF_UNLOAD
			else
				self:startFieldworkWithPathfinding(self.aiDriverData.continueFieldworkAtWaypoint)
			end
			self.ppc:setNormalLookaheadDistance()
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.SELF_UNLOADING_AFTER_FIELDWORK_ENDED then
		self:setSpeed(0)
		if self:unloadFinished() then
			self:debug('Self unloading finished, returning to fieldwork')
			UnloadableFieldworkAIDriver.onEndCourse(self)
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.field)
	else
		UnloadableFieldworkAIDriver.driveFieldworkUnloadOrRefill(self)
	end
end

function CombineAIDriver:onNextCourse(ix)
	if self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		if self.fieldWorkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
			-- pulled back, now wait for unload
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK
			self:debug('Pulled back, now wait for unload')
			self:setInfoText(self:getFillLevelInfoText())
		elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
			self:debug('Pull back finished, returning to fieldwork')
			self:changeToFieldwork()
		elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD then
			self:debug('Back from self unload, returning to fieldwork')
			self:changeToFieldwork()
		elseif self.fieldWorkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
			self:debug('Reversed, now start making a pocket to waypoint %d', self.unloadInPocketIx)
			self:lowerImplements()
			self.fieldWorkUnloadOrRefillState = self.states.MAKING_POCKET
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
	local discharging = self:isDischarging()
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
			self.litersPerMeter = (fillLevel - self.fillLevelAtLastWaypoint) / self.course:getDistanceToNextWaypoint(ix - 1)
			-- smooth a bit
			self.fillLevelAtLastWaypoint = (self.fillLevelAtLastWaypoint + fillLevel) / 2
		else
			-- no history yet, so make sure we don't end up with some unrealistic numbers
			self.litersPerMeter = 0
			self.fillLevelAtLastWaypoint = fillLevel
		end
		self:debug('Fill rate is %.1f liter/meter', self.litersPerMeter)
	end
	local dToNextTurn = self.course:getDistanceToNextTurn(ix) or -1
	local lNextRow = self.course:getNextRowLength(ix) or -1
	if dToNextTurn > 0 and lNextRow > 0 and self.litersPerMeter > 0 then
		local dUntilFull = (self.combine:getFillUnitCapacity(self.combine.fillUnitIndex) - fillLevel) / self.litersPerMeter
		self:debug('dUntilFull: %.1f m, dToNextTurn: %.1f m, lNextRow = %.1f m', dUntilFull, dToNextTurn, lNextRow)
		if dUntilFull > dToNextTurn and dUntilFull < dToNextTurn + lNextRow then
			self:debug('Will be full in the next row' )
		end
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
	local reverseRotation = MathUtil.getYRotationFromDirection(dx, dz)

	local x1, _, z1 = localToWorld(self:getDirectionNode(), -self.pullBackSideOffset, 0, -self.pullBackDistanceStart)
	local x2, _, z2 = localToWorld(self:getDirectionNode(), -self.pullBackSideOffset, 0, -self.pullBackDistanceEnd)
	-- both points must be on the field
	if courseplay:isField(x1, z1) and courseplay:isField(x2, z2) then
		local vx, _, vz = getWorldTranslation(self:getDirectionNode())
		self:debug('%.2f %.2f %d %d', self.returnPoint.rotation, reverseRotation, math.deg(self.returnPoint.rotation), math.deg(reverseRotation))
		local pullBackWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, vx, vz, x1, z1, reverseRotation, true)
		if not pullBackWaypoints then
			self:debug("Can't create alignment course for pull back")
			return nil
		end
		table.insert(pullBackWaypoints, {x = x2, z = z2})
		-- this is the backing up part, so make sure we are reversing here
		for _, p in ipairs(pullBackWaypoints) do
			p.rev = true
		end
		return Course(self.vehicle, pullBackWaypoints, true)
	else
		self:debug("Pull back course would be outside of the field")
		return nil
	end
end

function CombineAIDriver:createPullBackReturnCourse()
	local x1, _, z1 = localToWorld(self:getDirectionNode(), 0, 0, self.pullBackDistanceStart / 2)
	-- don't need to check if points are on the field, we did it when we got here
	local pullBackReturnWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, x1, z1, self.returnPoint.x, self.returnPoint.z, self.returnPoint.rotation, true)
	if not pullBackReturnWaypoints then
		self:debug("Can't create alignment course for pull back return")
		return nil
	end
	return Course(self.vehicle, pullBackReturnWaypoints, true)
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
function CombineAIDriver:holdInTurnManeuver(isApproaching)
	self:debugSparse('held for unload %s, straw active %s, approaching = %s',
		tostring(self.heldForUnloadRefill), tostring(self.combine.strawPSenabled), tostring(isApproaching))
	return self.heldForUnloadRefill or (self.combine.strawPSenabled and not isApproaching)
end

--- Should we return to the first point of the course after we are done?
function CombineAIDriver:shouldReturnToFirstPoint()
	-- Combines stay where they are after finishing work
	-- TODO: call unload driver
	return false
end

-- TODO: either implement these cleanly or remove them from AIDriver
function CombineAIDriver:getHasCourseplayers()
	return self.vehicle.courseplayers and #self.vehicle.courseplayers ~= 0
end

function CombineAIDriver:getFirstCourseplayer()
	return self.vehicle.courseplayers and self.vehicle.courseplayers[1]
end

--- Interface for AutoDrive
---@return boolean true when the combine is waiting to be unloaded
function CombineAIDriver:isWaitingForUnload()
	return self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		(self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL or
			self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET or
			self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK or
			self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED)
end

--- Interface for AutoDrive
---@return boolean true when the combine is waiting to be unloaded after it ended the course
function CombineAIDriver:isWaitingForUnloadAfterCourseEnded()
	return self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED
end


function CombineAIDriver:createTurnCourse()
	return CombineCourseTurn(self.vehicle, self, self.turnContext, self.fieldworkCourse)
end

function CombineAIDriver:startTurn(ix)
	self:debug('Starting a combine turn.')

	self:setMarkers()
	self.turnContext = TurnContext(self.course, ix, self.aiDriverData, self.vehicle.cp.workWidth, self.frontMarkerDistance,
			self:getTurnEndSideOffset())

	-- Combines drive special headland corner maneuvers, except potato and sugarbeet harvesters
	if self.turnContext:isHeadlandCorner() then
		if self:isPotatoOrSugarBeetHarvester() then
			self:debug('Headland turn but this harvester uses normal turn maneuvers.')
			UnloadableFieldworkAIDriver.startTurn(self, ix)
		elseif self.course:isOnOutermostHeadland(ix) and self.vehicle.cp.turnOnField then
			self:debug('Creating a pocket in the corner so the combine stays on the field during the turn')
			local cornerCourse, nextIx = self:createOuterHeadlandCornerCourse(self.turnContext)
			if cornerCourse then
				self:debug('Starting a corner with a course with %d waypoints, will continue fieldwork at waypoint %d',
						cornerCourse:getNumberOfWaypoints(), nextIx)
				self.fieldworkState = self.states.TURNING
				self:startCourse(cornerCourse, 1, self.course, nextIx)
				-- tighter turns
				self.ppc:setShortLookaheadDistance()
			else
				self:debug('Could not create a corner course, falling back to default headland turn')
				UnloadableFieldworkAIDriver.startTurn(self, ix)
			end
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
	if self:isFillableTrailerUnderPipe() or self:isAutoDriveWaitingForPipe() then
		self:openPipe()
	else
		self:closePipe()
	end
end


--- Support for AutoDrive mod: they'll only find us if we open the pipe
function CombineAIDriver:isAutoDriveWaitingForPipe()
	return self.vehicle.spec_autodrive and self.vehicle.spec_autodrive.combineIsCallingDriver and self.vehicle.spec_autodrive:combineIsCallingDriver(self.vehicle)
end

function CombineAIDriver:handleChopperPipe()
	if self.state == self.states.ON_FIELDWORK_COURSE then
		-- chopper always opens the pipe
		self:openPipe()
		-- and stops if there's no trailer in sight
		local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
		--self:debug('filltype = %s, fillLevel = %.1f', self:getFillType(), fillLevel)
		-- not using isFillableTrailerUnderPipe() as the chopper sometimes has FillType.UNKNOWN
		if self:getIsChopperWaitingForTrailer(fillLevel) then
			self:debugSparse('Chopper waiting for trailer, fill level %f', fillLevel)
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
	if self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_MOVING and
		self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_OPEN then
		self:debug('Opening pipe')
		self.objectWithPipe:setPipeState(self.PIPE_STATE_OPEN)
	end
end

function CombineAIDriver:closePipe()
	if not self:needToOpenPipe() then return end
	if self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_MOVING and
		self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_CLOSED then
		self:debug('Closing pipe')
		self.objectWithPipe:setPipeState(self.PIPE_STATE_CLOSED)
	end
end

function CombineAIDriver:shouldStopForUnloading(pc)
	local stop = false
	if self.vehicle.cp.stopWhenUnloading and self.pipe then
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
	if self.pipe then
		return self.pipe:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
	else
		return false
	end
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
				self.vehicle, self.fieldworkCourse:getWaypoint(self.waypointIxAfterPathfinding), 0,true, nil)
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
		if self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_SELF_UNLOAD then
			self:startFieldworkWithPathfinding(self.aiDriverData.continueFieldworkAtWaypoint)
		elseif self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD then
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
		elseif self.fieldWorkUnloadOrRefillState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED then
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_FIELDWORK_ENDED
		end
		return false
	end
end
