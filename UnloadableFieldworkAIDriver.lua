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

---@class UnloadableFieldworkAIDriver : FieldworkAIDriver
UnloadableFieldworkAIDriver = CpObject(FieldworkAIDriver)
-- at which fill level we need to unload. We want to have a little buffer there
-- as we won't raise our implements until we stopped and during that time we keep
-- harvesting
UnloadableFieldworkAIDriver.fillLevelFullPercentage = 99.5

-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
UnloadableFieldworkAIDriver.PIPE_STATE_MOVING = 0
UnloadableFieldworkAIDriver.PIPE_STATE_CLOSED = 1
UnloadableFieldworkAIDriver.PIPE_STATE_OPEN = 2


UnloadableFieldworkAIDriver.myStates = {
	UNLOAD = {},
	WAITING_FOR_UNLOAD = {}
}

function UnloadableFieldworkAIDriver:init(vehicle)
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(UnloadableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_FIELDWORK
end

function UnloadableFieldworkAIDriver:drive(dt)
	-- handle the pipe in any state
	self:handlePipe()
	-- the rest is the same as the parent class
	FieldworkAIDriver.drive(self, dt)
end

--- Doing the fieldwork (headlands or up/down rows, including the turns)
function UnloadableFieldworkAIDriver:driveFieldwork()
	if self.fieldWorkState == self.states.WAITING_FOR_LOWER then
		if self:areAllWorkToolsReady() then
			self:debug('all tools ready, start working')
			self.fieldWorkState = self.states.WORKING
			self.speed = self:getFieldSpeed()
		else
			self.speed = 0
		end
	elseif self.fieldWorkState == self.states.WORKING then
		if not self:allFillLevelsOk() then
			self:changeToFieldworkUnload()
		end
	elseif self.fieldWorkState == self.states.UNLOAD then
		self:driveFieldworkUnload()
	elseif self.fieldWorkState == self.states.ALIGNMENT then
		self.speed = self:getFieldSpeed()
	end
end

--- Grain tank full during fieldwork
function UnloadableFieldworkAIDriver:changeToFieldworkUnload()
	self:debug('change to fieldwork unload')
	self:setInfoText('NEEDS_UNLOADING')
	self.fieldWorkState = self.states.UNLOAD
	self.fieldWorkUnloadState = self.states.WAITING_FOR_RAISE
end

function UnloadableFieldworkAIDriver:driveFieldworkUnload()
	-- don't move while full
	self.speed = 0
	if self.fieldWorkUnloadState == self.states.WAITING_FOR_RAISE then
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('vehicle stopped, raise implements')
			self:stopWork()
			self.fieldWorkUnloadState = self.states.WAITING_FOR_UNLOAD
		end
	elseif self.fieldWorkUnloadState == self.states.WAITING_FOR_UNLOAD then
		if self:allFillLevelsOk() then
			self:debug('not full anymore, continue working')
			-- not full anymore, maybe because unloading to a trailer, go back to work
			self:clearInfoText()
			self:changeToFieldwork()
		end
	end
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
	self:debugSparse('Fill levels: %s: %.1f', fillTypeName, pc )

	if self:isValidFillType(fillUnit.fillType) and pc > self.fillLevelFullPercentage then
		return false
	end
	return true
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




