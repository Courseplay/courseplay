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

function FillableFieldworkAIDriver:init(vehicle)
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(FillableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_SEED_FERTILIZE
end

--- Out of seeds/fertilizer/whatever
function FillableFieldworkAIDriver:changeToFieldworkUnloadOrRefill()
	self:debug('change to fieldwork refilling')
	self:setInfoText('NEEDS_REFILLING')
	FieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
end

--- Drive the refill part of the course
function FillableFieldworkAIDriver:driveUnloadOrRefill()
	self:searchForRefillTriggers()
	if self.alignmentCourse then
		-- use the courseplay speed limit for fields
		self.speed = self.vehicle.cp.speeds.field
	elseif self:getIsInFilltrigger() then
		-- our raycast in searchForRefillTriggers found a fill trigger
		local allowedToDrive = true
		-- lx, lz is not used by refillWorkTools, allowedToDrive is returned, should be refactored, but use it for now as it is
		allowedToDrive, _, _ = courseplay:refillWorkTools(self.vehicle, self.vehicle.cp.refillUntilPct, allowedToDrive, 0, 1)
		if allowedToDrive then
			-- slow down to field speed around fill triggers
			self.speed = math.min(self.vehicle.cp.speeds.turn, self:getRecordedSpeed())
		else
			-- stop for refill when refillWorkTools tells us
			self.speed = 0
		end
	else
		-- just drive normally
		self.speed = self:getRecordedSpeed()
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

function FillableFieldworkAIDriver:searchForRefillTriggers()
	-- look straight ahead for now. The rest of CP looks into the direction of the 'current waypoint'
	-- but we don't have that information (lx/lz) here. See if we can get away with this, should only
	-- be a problem if we have a sharp curve around the trigger
	local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, 0, -0.1, 1)
	-- raycast start point in front of vehicle
	local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1, 3)
	courseplay:doTriggerRaycasts(self.vehicle, 'specialTrigger', 'fwd', true, x, y, z, nx, ny, nz)
end

