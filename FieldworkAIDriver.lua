--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

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

--[[
Fieldwork AI Driver

Can follow a fieldworking course, perform turn maneuvers, turn on/off and raise/lower implements,
add adjustment course if needed.
]]

FieldworkAIDriver = CpObject(AIDriver)

--- Constructor
function FieldworkAIDriver:init(vehicle)
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_SEED_FERTILIZE
end

function FieldworkAIDriver:start(ix)
	AIDriver.start(self, ix)
	self.vehicle.cp.stopAtEnd = true
	if not self.alignmentCourse then
		-- if there's no alignment course, start work immediately
		-- TODO: should probably better start it when the initialized waypoint (ix) is reached
		-- as we may start the vehicle outside of the field?
		self:startWork()
	end
end

function FieldworkAIDriver:drive(dt)
	AIDriver.drive(self, dt)
	self:checkCapacities()
end

function FieldworkAIDriver:stop(msgReference)
	self:stopWork()
	AIDriver.stop(self, msgReference)
end

function FieldworkAIDriver:onEndAlignmentCourse()
	self:startWork()
end

function FieldworkAIDriver:onEndCourse()
	self:stop('END_POINT')
end

function FieldworkAIDriver:getSpeed()
	if self.alignmentCourse then
		return self.vehicle.cp.speeds.field
	else
		local speedLimit = self.vehicle:getSpeedLimit() or math.huge
		return math.min(self.vehicle.cp.speeds.field, speedLimit)
	end
end

--- Start the actual work. Lower and turn on implements
function FieldworkAIDriver:startWork()
	self:debug('Starting work: turn on and lower implements.')
	courseplay:lowerImplements(self.vehicle)
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
end

--- Stop working. Raise and stop implements
function FieldworkAIDriver:stopWork()
	self:debug('Ending work: turn off and raise implements.')
	courseplay:raiseImplements(self.vehicle)
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
end

function FieldworkAIDriver:checkCapacities()
	-- really no need to do this on every update()
	if g_updateLoopIndex % 100 ~= 0 then return end
	if not self.vehicle.cp.workTools then return end
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		if workTool.getFillUnits then
			for index, fillUnit in pairs(workTool:getFillUnits()) do
				local pc = 100 * workTool:getFillUnitFillLevelPercentage(index)
				local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnit.fillType)
				self:debug('Fill levels: %s: %d', fillTypeName, pc )
			end
		end
	end
end