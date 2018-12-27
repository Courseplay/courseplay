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
Fieldwork AI Driver for seeding, spraying, etc. where the tool needs to be filled
with some material

Also known as mode 4

]]

---@class FillableFieldworkAIDriver : FieldworkAIDriver
FillableFieldworkAIDriver = CpObject(FieldworkAIDriver)


FillableFieldworkAIDriver.myStates = {
	WAITING_FOR_FILL = {}
}

function FillableFieldworkAIDriver:init(vehicle)
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(FillableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_SEED_FERTILIZE
end

function FillableFieldworkAIDriver:drive(dt)
	FillableFieldworkAIDriver:checkRefillStatus()
	FieldworkAIDriver.drive(self, dt)
end


-- is the fill level ok to continue? With fillable tools we need to stop working when we are out
-- of material (seed, fertilizer, etc.)
function FillableFieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	local pc = 100 * workTool:getFillUnitFillLevelPercentage(index)
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnit.fillType)
	self:debug('Fill levels: %s: %d', fillTypeName, pc )
	if pc < 1 then
		return false
	end
	return true
end

--- Check if need to refill anything
function FillableFieldworkAIDriver:checkRefillStatus()
	if not self.vehicle.cp.workTools then return end
	if g_updateLoopIndex % 100 ~= 0 then return end
	local nothingToRefill = true
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		nothingToRefill = self:checkFillLevels(workTool) and nothingToRefill
	end
	if not nothingToRefill then
		self:stopWork()
		self:hold('NEEDS_REFILLING')
	end
end
