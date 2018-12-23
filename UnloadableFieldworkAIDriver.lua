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

-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
UnloadableFieldworkAIDriver.PIPE_STATE_MOVING = 0
UnloadableFieldworkAIDriver.PIPE_STATE_CLOSED = 1
UnloadableFieldworkAIDriver.PIPE_STATE_OPEN = 2


function UnloadableFieldworkAIDriver:init(vehicle)
	FieldworkAIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_FIELDWORK
end


function UnloadableFieldworkAIDriver:drive(dt)
	FieldworkAIDriver.drive(self, dt)
	self:handlePipe()
end

function UnloadableFieldworkAIDriver:handlePipe()
	if self.vehicle.spec_pipe then
		if self:isFillableTrailerUnderPipe() then
			if self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_MOVING and
				self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_OPEN then
				self:debug('Opening pipe')
				self.vehicle.spec_pipe:setPipeState(self.PIPE_STATE_OPEN)
			end
		else
			if self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_MOVING and
				self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_CLOSED then
				self:debug('Closing pipe')
				self.vehicle.spec_pipe:setPipeState(self.PIPE_STATE_CLOSED)
			end
		end
	end
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

function UnloadableFieldworkAIDriver:isFillableTrailerUnderPipe()
	local canLoad = false
	if self.vehicle.spec_pipe then
		for trailer, value in pairs(self.vehicle.spec_pipe.objectsInTriggers) do
			if value > 0 then
				local fillType = self:getFillType()
				if fillType then
					local fillUnits = trailer:getFillUnits()
					for i=1, #fillUnits do
						local supportedFillTypes = trailer:getFillUnitSupportedFillTypes(i)
						if supportedFillTypes[fillType] and trailer:getFillUnitFreeCapacity(i) > 0 then
							canLoad = true
						end
					end
				end
			end
		end
	end
	return canLoad
end

--- Check fill levels in all tools and stop when one of them isn't
-- ok (empty or full, depending on the derived class)
function UnloadableFieldworkAIDriver:getFillType()
	if not self.vehicle.cp.workTools then return end
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		if workTool.getFillUnits then
			for _, fillUnit in pairs(workTool:getFillUnits()) do
				if self:isValidFillType(fillUnit.fillType) then
					return fillUnit.fillType
				end
			end
		end
	end
	return nil
end

function UnloadableFieldworkAIDriver:isValidFillType(fillType)
	return fillType ~= FillType.DIESEL and fillType ~= FillType.DEF	and fillType ~= FillType.AIR
end
