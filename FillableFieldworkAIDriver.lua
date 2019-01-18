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
	if self.temporaryCourse then
		-- use the courseplay speed limit for fields
		self:setSpeed(self.vehicle.cp.speeds.field)
	elseif self:getIsInFilltrigger() then
		-- our raycast in searchForRefillTriggers found a fill trigger
		local allowedToDrive = true
		-- lx, lz is not used by refillWorkTools, allowedToDrive is returned, should be refactored, but use it for now as it is
		allowedToDrive, _, _ = courseplay:refillWorkTools(self.vehicle, self.vehicle.cp.refillUntilPct, allowedToDrive, 0, 1)
		if allowedToDrive then
			-- slow down to field speed around fill triggers
			self:setSpeed(math.min(self.vehicle.cp.speeds.turn, self:getRecordedSpeed()))
		else
			-- stop for refill when refillWorkTools tells us
			self:setSpeed( 0)
		end
	else
		-- just drive normally
		self:setSpeed(self:getRecordedSpeed())
	end
	return false
end


-- is the fill level ok to continue? With fillable tools we need to stop working when we are out
-- of material (seed, fertilizer, etc.)
function FillableFieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	if self:helperBuysThisFillUnit(fillUnit) then return true end
	local pc = 100 * workTool:getFillUnitFillLevelPercentage(index)
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnit.lastValidFillType or fillUnit.fillType)
	if pc == 0 then
		self:debugSparse('Empty: %s: %d', fillTypeName, pc )
		return false
	end
	self:debugSparse('Fill levels: %s: %d', fillTypeName, pc )
	return true
end

--- Does the helper buy this fill unit (according to the game settings)? If yes, we don't have to stop or refill when empty.
function FillableFieldworkAIDriver:helperBuysThisFillUnit(fillUnit)
	for fillType, _ in pairs(fillUnit.supportedFillTypes) do
		if g_currentMission.missionInfo.helperBuySeeds and fillType == FillType.SEEDS then
			return true
		end
		if g_currentMission.missionInfo.helperBuyFertilizer and
			(fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER) then
			return true
		end
		if g_currentMission.missionInfo.helperManureSource == 2 and fillType == FillType.MANURE then
			return true
		end
		if g_currentMission.missionInfo.helperSlurrySource == 2 and fillType == FillType.LIQUIDMANURE then
			return true
		end
		if g_currentMission.missionInfo.helperBuyFuel and
			(fillType == FillType.DIESEL or fillType == FillType.FUEL) then
			return true
		end
	end
	return false
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

