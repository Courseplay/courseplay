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
Fieldwork AI Driver for harvesting vehicles which need to unload material to continue

Also known as mode 6.

]]

UnloadableFieldworkAIDriver = CpObject(FieldworkAIDriver)
-- at which fill level we need to unload
UnloadableFieldworkAIDriver.fillLevelFullPercentage = 99.99

function UnloadableFieldworkAIDriver:init(vehicle)
	FieldworkAIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_FIELDWORK
end

-- is the fill level ok to continue? With unloadable tools we need to stop working when the tool is full
-- with fruit
function UnloadableFieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	local pc = 100 * workTool:getFillUnitFillLevelPercentage(index)
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnit.fillType)
	self:debug('Fill levels: %s: %d', fillTypeName, pc )
	if pc > self.fillLevelFullPercentage then
		return false, 'NEEDS_UNLOADING'
	end
	return true, nil
end
