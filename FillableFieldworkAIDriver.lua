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
	TO_BE_REFILLED = {},
	REFILL_DONE = {}
}
function FillableFieldworkAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(FillableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_SEED_FERTILIZE
	self.refillState = self.states.TO_BE_REFILLED
end

function FillableFieldworkAIDriver:changeToUnloadOrRefill()
	self.refillState = self.states.TO_BE_REFILLED
	FieldworkAIDriver.changeToUnloadOrRefill(self)
end
--- Out of seeds/fertilizer/whatever
function FillableFieldworkAIDriver:changeToFieldworkUnloadOrRefill()
	self:debug('change to fieldwork refilling')
	self:setInfoText(self:getFillLevelInfoText())
	FieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
end

--- Drive the refill part of the course
function FillableFieldworkAIDriver:driveUnloadOrRefill()
	local isNearWaitPoint, waitPointIx = self.course:hasWaitPointWithinDistance(self.ppc:getCurrentWaypointIx(), 5)

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
			self:debugSparse('refillWorkTools() tells us to stop')
			self:setSpeed( 0)
		end
	elseif  self.refillState == self.states.TO_BE_REFILLED and isNearWaitPoint then
		local allowedToDrive = true;
		local distanceToWait = self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, waitPointIx)
		self:setSpeed(MathUtil.clamp(distanceToWait,self.vehicle.cp.speeds.crawl,self:getRecordedSpeed()))
		if distanceToWait < 1 then
			allowedToDrive = self:fillAtWaitPoint()
		end	
		if not allowedToDrive then
			self:setSpeed( 0)
		end
	else
		-- just drive normally
		self:setSpeed(self:getRecordedSpeed())
	end
	return false
end

function FillableFieldworkAIDriver:fillAtWaitPoint()
	local vehicle = self.vehicle
	local allowedToDrive = false
	courseplay:setInfoText(vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",courseplay.utils:roundToLowerInterval(vehicle.cp.totalFillLevel, 100),vehicle.cp.totalCapacity));
	self:setInfoText('WAIT_POINT')
	
	--fillLevel changed in last loop-> start timer
	if self.prevFillLevelPct == nil or self.prevFillLevelPct ~= vehicle.cp.totalFillLevelPercent then
		self.prevFillLevelPct = vehicle.cp.totalFillLevelPercent
		courseplay:setCustomTimer(vehicle, "fillLevelChange", 7);
	end
	
	--if time is up and no fillLevel change happend, check whether we may drive on or not
	if courseplay:timerIsThrough(vehicle, "fillLevelChange",false) then
		if vehicle.cp.totalFillLevelPercent >= vehicle.cp.refillUntilPct then
			self:continue()
			courseplay:resetCustomTimer(vehicle, "fillLevelChange",true);
			self.prevFillLevelPct = nil
		end
	end
	return allowedToDrive
end

function FillableFieldworkAIDriver:continue()
	self:debug('Continuing...')
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
	self.refillState = self.states.REFILL_DONE	
	self:clearAllInfoTexts()
end

-- is the fill level ok to continue? With fillable tools we need to stop working when we are out
-- of material (seed, fertilizer, etc.)
function FillableFieldworkAIDriver:areFillLevelsOk(fillLevelInfo)
	local allOk = true
	local hasSeeds, hasNoFertilizer = false, false

	for fillType, info in pairs(fillLevelInfo) do
		if info.fillLevel == 0 and info.capacity > 0 and not self:helperBuysThisFillType(fillType) then
			allOk = false
			if fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER then hasNoFertilizer = true end
		else
			if fillType == FillType.SEEDS then hasSeeds = true end
		end
	end
	if not allOk and not self.vehicle.cp.fertilizerEnabled and hasNoFertilizer and hasSeeds then
		self:debugSparse('Has no fertilizer but has seeds so keep working.')
		allOk = true
	end
	return allOk
end

--- Does the helper buy this fill unit (according to the game settings)? If yes, we don't have to stop or refill when empty.
function FillableFieldworkAIDriver:helperBuysThisFillType(fillType)
	if g_currentMission.missionInfo.helperBuySeeds and fillType == FillType.SEEDS then
		return true
	end
	if g_currentMission.missionInfo.helperBuyFertilizer and
		(fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER) then
		return true
	end
	-- Check for source as in Sprayer:getExternalFill()
	-- Source 1 - helper refill off, 2 - helper buys, > 2 - farm sources (manure heap, etc.)
	if fillType == FillType.MANURE then
		if  g_currentMission.missionInfo.helperManureSource == 2 then
			-- helper buys
			return true
		elseif g_currentMission.missionInfo.helperManureSource > 2 then
		else
			-- maure heaps
			local info = g_currentMission.manureHeaps[g_currentMission.missionInfo.helperManureSource - 2]
			if info ~= nil then -- Can be nil if pen was removed
				if info.manureHeap:getManureLevel() > 0 then
					return true
				end
			end
			return false
		end
	elseif fillType == FillType.LIQUIDMANURE or fillType == FillType.DIGESTATE then
		if g_currentMission.missionInfo.helperSlurrySource == 2 then
			-- helper buys
			return true
		elseif g_currentMission.missionInfo.helperSlurrySource > 2 then
			--
			local info = g_currentMission.liquidManureTriggers[g_currentMission.missionInfo.helperSlurrySource - 2]
			if info ~= nil then -- Can be nil if pen was removed
				if info.silo:getFillLevel(FillType.LIQUIDMANURE) > 0 then
					return true
				end
			end
			return true
		end
	end
	if g_currentMission.missionInfo.helperBuyFuel and
		(fillType == FillType.DIESEL or fillType == FillType.FUEL) then
		return true
	end
	return false
end

function FillableFieldworkAIDriver:searchForRefillTriggers()
	-- look straight ahead for now. The rest of CP looks into the direction of the 'current waypoint'
	-- but we don't have that information (lx/lz) here. See if we can get away with this, should only
	-- be a problem if we have a sharp curve around the trigger
	if not self.ppc:isReversing() then
		local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1, 3)
		local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, 0, -0.1, 1)
		-- raycast start point in front of vehicle
		courseplay:doTriggerRaycasts(self.vehicle, 'specialTrigger', 'fwd', true, x, y, z, nx, ny, nz)
		
		--create a hammerhead racast to get small triggerStartId
		local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, -1.5, 1, 10)
		local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, 1, 0, 0)
		courseplay:doTriggerRaycasts(self.vehicle, 'specialTrigger', 'fwd', false, x, y, z, nx, ny, nz,3)
		
	else
		for _,workTool in pairs(self.vehicle.cp.workTools) do
			local node = workTool.cp.realTurningNode or workTool.rootNode ;
			local x, y, z = localToWorld(node, 0, 2, 3)
			local nx, ny, nz = localDirectionToWorld(node, 0, -0.1, -1)
			-- raycast start point behind the workTool
			courseplay:doTriggerRaycasts(self.vehicle, 'specialTrigger', 'rev', false, x, y, z, nx, ny, nz)
			
			--create a hammerhead racast to get small triggerStartId
			local x, y, z = localToWorld(node, -1.5, 1, -10)
			local nx, ny, nz = localDirectionToWorld(node, 1, 0, 0)
			courseplay:doTriggerRaycasts(self.vehicle, 'specialTrigger', 'rev', false, x, y, z, nx, ny, nz,3)
		end
	end
end

function FillableFieldworkAIDriver:getFillLevelInfoText()
	return 'NEEDS_REFILLING'
end
