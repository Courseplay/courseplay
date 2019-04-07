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
	RETURNING_FROM_POCKET = {}
}

function CombineAIDriver:init(vehicle)
	courseplay.debugVehicle(11, vehicle, 'CombineAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self:initStates(CombineAIDriver.myStates)
	self.fruitLeft, self.fruitRight = 0, 0
	self.litersPerMeter = 0
	self.fillLevelAtLastWaypoint = 0
	self.beaconLightsActive = false
	-- distance keep to the right when pulling back to make room for the tractor
	self.pullBackSideOffset = math.min(self.vehicle.cp.workWidth, 6)
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

function CombineAIDriver:onWaypointPassed(ix)
	if self.turnIsDriving then
		self:debug('onWaypointPassed %d, ignored as turn is driving now', ix)
		return
	end
	self:checkFruit()
	-- make sure we start making a pocket while we still have some fill capacity left as we'll be
	-- harvesting fruit while making the pocket
	if not self.fieldOnLeft then
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
		if not self.fieldOnLeft then
			-- I'm on the edge of the field, make a pocket on the right side and wait there for the unload
			local pocketCourse, nextIx = self:createPocketCourse()
			if pocketCourse then
				self:debug('No room to the left, making a pocket for unload')
				self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
				self.fieldWorkUnloadOrRefillState = self.states.REVERSING_TO_MAKE_A_POCKET
				self:startCourse(pocketCourse, 1, self.course, nextIx)
				-- tighter turns
				self.ppc:setShortLookaheadDistance()
			else
				-- revert to normal behavior
				UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
			end
		elseif self.fruitLeft > self.fruitRight then
			-- is our pipe in the fruit? (assuming pipe is on the left side)
			local pullBackCourse = self:createPullBackCourse()
			if pullBackCourse then
				self:debug('Pipe in fruit, pulling back to make room for unloading')
				self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
				self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_RAISE
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
	if self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_RAISE then
		self:setSpeed(0)
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('implements raised, start pulling back')
			self:stopWork()
			self.fieldWorkUnloadOrRefillState = self.states.PULLING_BACK_FOR_UNLOAD
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldWorkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldWorkUnloadOrRefillState == self.states.MAKING_POCKET then
		self:setSpeed(self:getFieldSpeed())
	elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
		self:setSpeed(self.vehicle.cp.speeds.turn)
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET then
		if self:unloadFinished() then
			self:clearInfoText(self:getFillLevelInfoText())
			self:debug('Unloading in pocket finished, returning to fieldwork')
			self.fillLevelFullPercentage = self.normalFillLevelFullPercentage
			self:changeToFieldwork()
		else
			self:setSpeed(0)
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK then
		-- don't move when pulled back until unloading is finished
		if self:unloadFinished() then
			self:clearInfoText(self:getFillLevelInfoText())
			local pullBackReturnCourse = self:createPullBackReturnCourse()
			if pullBackReturnCourse then
				self.fieldWorkUnloadOrRefillState = self.states.RETURNING_FROM_PULL_BACK
				self:debug('Unloading finished, returning to fieldwork on return course')
				self:startCourse(pullBackReturnCourse, 1, self.courseAfterPullBack, self.ixAfterPullBack)
			else
				self:debug('Unloading finished, returning to fieldwork directly')
				self.ppc:setNormalLookaheadDistance()
				self:changeToFieldwork()
			end
		else
			self:setSpeed(0)
		end
	else
		UnloadableFieldworkAIDriver.driveFieldworkUnloadOrRefill(self)
	end
end

function CombineAIDriver:onNextCourse()
	if self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		if self.fieldWorkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
			-- pulled back, now wait for unload
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK
			self:debug('Pulled back, now wait for unload')
			self:setInfoText(self:getFillLevelInfoText())
		elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
			self:debug('Pull back finished, returning to fieldwork')
			self:changeToFieldwork()
		elseif self.fieldWorkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
			self:debug('Reversed, now start making a pocket to waypoint %d', self.unloadInPocketIx)
			self.fieldWorkUnloadOrRefillState = self.states.MAKING_POCKET
			self.aiDriverOffsetX = self.pullBackSideOffset
		end
	else
		UnloadableFieldworkAIDriver.onNextCourse(self)
	end
end

function CombineAIDriver:unloadFinished()
	local discharging = false
	if self.vehicle.spec_pipe then
		discharging = self.vehicle.spec_pipe:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
	end
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.vehicle.spec_combine.fillUnitIndex)

	-- unload is done when fill levels are ok (not full) and not discharging anymore (either because we
	-- are empty or the trailer is full)
	return (self:allFillLevelsOk() and not discharging) or fillLevel < 0.1
end

function CombineAIDriver:checkFruit()
	-- getValidityOfTurnDirections() wants to have the vehicle.aiDriveDirection, so get that here.
	local dx,_,dz = localDirectionToWorld(self.vehicle:getAIVehicleDirectionNode(), 0, 0, 1)
	local length = MathUtil.vector2Length(dx,dz)
	dx = dx / length
	dz = dz / length
	self.vehicle.aiDriveDirection = {dx, dz}
	self.fruitLeft, self.fruitRight = AIVehicleUtil.getValidityOfTurnDirections(self.vehicle)
	-- Is there field on my left side?
	local x, _, z = localToWorld(self.vehicle.cp.DirectionNode, self.vehicle.cp.workWidth, 0, 0)
	self.fieldOnLeft = courseplay:isField(x, z, 1, 1)
	self:debug('Fruit left: %.2f right %.2f, field on left %s', self.fruitLeft, self.fruitRight, tostring(self.fieldOnLeft))
end

function CombineAIDriver:checkDistanceUntilFull(ix)
	-- calculate fill rate so the combine driver knows if it can make the next row without unloading
	local spec = self.vehicle.spec_combine
	local fillLevel = self.vehicle:getFillUnitFillLevel(spec.fillUnitIndex)
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
		local dUntilFull = (self.vehicle:getFillUnitCapacity(spec.fillUnitIndex) - fillLevel) / self.litersPerMeter
		self:debug('dUntilFull: %.1f m, dToNextTurn: %.1f m, lNextRow = %.1f m', dUntilFull, dToNextTurn, lNextRow)
		if dUntilFull > dToNextTurn and dUntilFull < dToNextTurn + lNextRow then
			self:debug('Will be full in the next row' )
		end
	end
end

function CombineAIDriver:updateLightsOnField()
	-- handle beacon lights to call unload driver
	-- copy/paste from AIDriveStrategyCombine
	local spec = self.vehicle.spec_combine
	local fillLevel = self.vehicle:getFillUnitFillLevel(spec.fillUnitIndex)
	local capacity = self.vehicle:getFillUnitCapacity(spec.fillUnitIndex)
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

	local dx,_,dz = localDirectionToWorld(self.vehicle.rootNode, 0, 0, 1)
	self.returnPoint.rotation = MathUtil.getYRotationFromDirection(dx, dz)
	dx,_,dz = localDirectionToWorld(self.vehicle.rootNode, 0, 0, -1)
	local reverseRotation = MathUtil.getYRotationFromDirection(dx, dz)

	local x1, _, z1 = localToWorld(self.vehicle.rootNode, -self.pullBackSideOffset, 0, -self.pullBackDistanceStart)
	local x2, _, z2 = localToWorld(self.vehicle.rootNode, -self.pullBackSideOffset, 0, -self.pullBackDistanceEnd)
	-- both points must be on the field
	if courseplay:isField(x1, z1) and courseplay:isField(x2, z2) then
		local vx, _, vz = getWorldTranslation(self.vehicle.cp.DirectionNode or self.vehicle.rootNode)
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
	local x1, _, z1 = localToWorld(self.vehicle.cp.DirectionNode, 0, 0, self.pullBackDistanceStart / 2)
	-- don't need to check if points are on the field, we did it when we got here
	local pullBackReturnWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, x1, z1, self.returnPoint.x, self.returnPoint.z, self.returnPoint.rotation, true)
	if not pullBackReturnWaypoints then
		self:debug("Can't create alignment course for pull back return")
		return nil
	end
	return Course(self.vehicle, pullBackReturnWaypoints, true)
end

--- Create a temporary course to make a pocket in the fruit on the right, so we can move into that pocket and
--- wait for the unload there. This way the unload tractor does not have to leave the field.
--- We create a temporary course to reverse back far enough. After that, we return to the main course but
--- set an offset to the right
function CombineAIDriver:createPocketCourse()
	local startIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
	-- find the waypoint we want to back up to
	local backIx = self.course:getPreviousWaypointIxWithinDistance(startIx, self.pocketReverseDistance)
	-- this is where we'll stop in the pocket for unload
	self.unloadInPocketIx = startIx - 2
	-- this where we are back on track after returning from the pocket
	self.returnedFromPocketIx = self.ppc:getCurrentWaypointIx()
	self:debug('Backing up %.1f meters from waypoint %d to %d to make a pocket', self.pocketReverseDistance, startIx, backIx)
	if startIx - backIx > 2 then
		local pocketReverseWaypoints = {}
		for i = startIx, backIx, -1 do
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
	return not self:isChopper() and self.vehicle.cp.saveFuelOptionActive
end

--- Compatibility function for turn.lua to check if the vehicle should stop during a turn (for example while it
--- is held for unloading or waiting for the straw swath to stop
--- Turn.lua calls this in every cycle during the turn and will stop the vehicle if this returns true.
---@param isApproaching boolean if true we are still in the turn approach phase (still working on the field,
---not yet reached the turn start
function CombineAIDriver:holdInTurnManeuver(isApproaching)
	self:debugSparse('held for unload %s, straw active %s, approaching = %s',
		tostring(self.heldForUnloadRefill), tostring(self.vehicle.spec_combine.strawPSenabled), tostring(isApproaching))
	return self.heldForUnloadRefill or (self.vehicle.spec_combine.strawPSenabled and not isApproaching)
end

function CombineAIDriver:getHasCourseplayers()
	return self.vehicle.courseplayers and #self.vehicle.courseplayers ~= 0
end

function CombineAIDriver:getFirstCourseplayer()
	return self.vehicle.courseplayers and self.vehicle.courseplayers[1]
end