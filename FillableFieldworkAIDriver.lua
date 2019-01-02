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
	REFILL = {},
	WAITING_FOR_FILL = {}
}

function FillableFieldworkAIDriver:init(vehicle)
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(FillableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_SEED_FERTILIZE
end

--- Doing the fieldwork (headlands or up/down rows, including the turns)
function FillableFieldworkAIDriver:driveFieldwork()
	if self.fieldworkState == self.states.WAITING_FOR_LOWER then
		if self:areAllWorkToolsReady() then
			self:debug('all tools ready, start working')
			self.fieldworkState = self.states.WORKING
			self.speed = self:getFieldSpeed()
		else
			self.speed = 0
		end
	elseif self.fieldworkState == self.states.WORKING then
		if not self:allFillLevelsOk() then
			if self.unloadRefillCourse then
				---@see courseplay#setAbortWorkWaypoint if that logic needs to be implemented
				-- TODO: also, this should be persisted through stop/start cycles (maybe on the vehicle?)
				self.fieldworkAbortedAtWaypoint = self.ppc:getCurrentWaypointIx()
				self.vehicle.cp.fieldworkAbortedAtWaypoint = self.fieldworkAbortedAtWaypoint
				self:debug('at least one tool is empty.')
				self:changeToUnloadOrRefill()
				self:startCourseWithAlignment(self.unloadRefillCourse, 1 )
			else
				self:changeToFieldworkRefill()
			end
		end
	elseif self.fieldworkState == self.states.REFILL then
		self:driveFieldworkRefill()
	elseif self.fieldworkState == self.states.ALIGNMENT then
		self.speed = self:getFieldSpeed()
	end
end

--- Out of seeds/fertilizer/whatever
function FillableFieldworkAIDriver:changeToFieldworkRefill()
	self:debug('change to fieldwork refilling')
	self:setInfoText('NEEDS_REFILLING')
	self.fieldworkState = self.states.REFILL
	self.fieldWorkRefillState = self.states.WAITING_FOR_RAISE
end

function FillableFieldworkAIDriver:driveFieldworkRefill()
	-- don't move while empty
	self.speed = 0
	if self.fieldWorkRefillState == self.states.WAITING_FOR_RAISE then
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('implements raised, stop')
			self:stopWork()
			self.fieldWorkRefillState = self.states.WAITING_FOR_REFILL
		end
	elseif self.fieldWorkRefillState == self.states.WAITING_FOR_REFILL then
		if self:allFillLevelsOk() then
			self:debug('refilled, continue working')
			-- not full anymore, maybe because Refilling to a trailer, go back to work
			self:clearInfoText()
			self:changeToFieldwork()
		end
	end
end

-- is the fill level ok to continue? With fillable tools we need to stop working when we are out
-- of material (seed, fertilizer, etc.)
function FillableFieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	local pc = 100 * workTool:getFillUnitFillLevelPercentage(index)
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnit.fillType)
	self:debugSparse('Fill levels: %s: %d', fillTypeName, pc )
	if pc < 1 then
		return false
	end
	return true
end
