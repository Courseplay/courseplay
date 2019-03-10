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

CombineAIDriver.myStates = {
	PULLING_BACK_FOR_UNLOAD = {},
	WAITING_FOR_UNLOAD_AFTER_PULLED_BACK = {},
	RETURNING_FROM_PULL_BACK = {}
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
	self.pullBackSideOffset = math.min(self.vehicle.cp.workWidth * 1.2, 6)
	-- should be at pullBackSideOffset to the right at pullBackDistanceStart
	self.pullBackDistanceStart = self.vehicle.cp.turnDiameter * 0.7
	-- and back up another bit
	self.pullBackDistanceEnd = self.pullBackDistanceStart + 10
end

function CombineAIDriver:onWaypointPassed(ix)
	self:checkDistanceUntilFull(ix)
	UnloadableFieldworkAIDriver.onWaypointPassed(self, ix)
end

function CombineAIDriver:changeToFieldworkUnloadOrRefill()
	-- is our pipe in the fruit? (assuming pipe is on the left side)
	self:checkFruit()
	-- TODO: check around turn maneuvers we may not want to pull back before a turn
	if self.fruitLeft > self.fruitRight then
		local pullBackCourse = self:createPullBackCourse()
		if pullBackCourse then
			self:debug('Pipe in fruit, pulling back to make room for unloading')
			self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_RAISE
			self.courseAfterPullBack = self.course
			self.ixAfterPullBack = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
			self:debug('ix %d', self.ixAfterPullBack)
			self:startCourse(pullBackCourse, 1, self.course, self.ixAfterPullBack)
		else
			-- revert to normal behavior
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
	elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
		self:setSpeed(self.vehicle.cp.speeds.turn)
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
	-- unload is done when fill levels are ok (not full) and not discharging anymore (either because we
	-- are empty or the trailer is full)
	return self:allFillLevelsOk() and not discharging
end

function CombineAIDriver:checkFruit()
	-- getValidityOfTurnDirections() wants to have the vehicle.aiDriveDirection, so get that here.
	local dx,_,dz = localDirectionToWorld(self.vehicle:getAIVehicleDirectionNode(), 0, 0, 1)
	local length = MathUtil.vector2Length(dx,dz)
	dx = dx / length
	dz = dz / length
	self.vehicle.aiDriveDirection = {dx, dz}
	self.fruitLeft, self.fruitRight = AIVehicleUtil.getValidityOfTurnDirections(self.vehicle)
	self:debug('Fruit left: %.2f right %.2f', self.fruitLeft, self.fruitRight)
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