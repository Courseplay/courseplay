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
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER,vehicle,'FillableFieldworkAIDriver:init()')
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(FillableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_SEED_FERTILIZE
	self.debugChannel = courseplay.DBG_MODE_4
	self.refillState = self.states.TO_BE_REFILLED
	self.lastTotalFillLevel = math.huge
end

function FillableFieldworkAIDriver:setHudContent()
	FieldworkAIDriver.setHudContent(self)
	courseplay.hud:setFillableFieldworkAIDriverContent(self.vehicle)
end

function FillableFieldworkAIDriver:changeToUnloadOrRefill()
	self.refillState = self.states.TO_BE_REFILLED
	self:refreshHUD()
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
	if self:getSiloSelectedFillTypeSetting():isEmpty() then 
		self:setSpeed(0)
		self:setInfoText('NO_SELECTED_FILLTYPE')
		return
	else
		self:clearInfoText('NO_SELECTED_FILLTYPE')
	end
	local isNearWaitPoint, waitPointIx = self.course:hasWaitPointWithinDistance(self.ppc:getRelevantWaypointIx(), 25)
	--this one is used to disable loading at the unloading stations,
	--might be better to disable the triggerID for loading
	self:enableFillTypeLoading(isNearWaitPoint)
	if self.course:isTemporary() then
		-- use the courseplay speed limit until we get to the actual unload corse fields (on alignment/temporary)
		self:setSpeed(self.vehicle.cp.speeds.field)
	elseif  self.refillState == self.states.TO_BE_REFILLED and isNearWaitPoint then
		-- should be reworked and be similar to mode 1 loading at start 
		local distanceToWait = self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, waitPointIx)
		self:setSpeed(MathUtil.clamp(distanceToWait,self.vehicle.cp.speeds.crawl,self:getRecordedSpeed()))
		if distanceToWait < 1 then
			self:fillAtWaitPoint()
		end	
	else
		if self.triggerHandler:isLoading() then 
			self:fillAtWaitPoint()	
		else 
			self:clearInfoText('REACHED_REFILLING_POINT')
		end
		-- just drive normally
		self:setSpeed(self:getRecordedSpeed())
		self:closePipeIfNeeded(isNearWaitPoint)
	end	
end

function FillableFieldworkAIDriver:enableFillTypeLoading(isInWaitPointRange)
	self.triggerHandler:enableFillTypeLoading()
	self.triggerHandler:disableFillTypeUnloading()
end

function FillableFieldworkAIDriver:needsFillTypeLoading()
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE then
		return true
	end
end

function FillableFieldworkAIDriver:closePipeIfNeeded(isInWaitPointRange) 
	--override
end

function FillableFieldworkAIDriver:fillAtWaitPoint()
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	local fillTypeData, fillTypeDataSize= self.triggerHandler:getSiloSelectedFillTypeData()
	if fillTypeData == nil then
		return
	end
	self:setSpeed(0)
	local minFillLevelIsOk = true
	for _,data in ipairs(fillTypeData) do 
		for fillType, info in pairs(fillLevelInfo) do
			if data.fillType == fillType then
				if info.fillLevel/info.capacity*100 < data.minFillLevel then 
					minFillLevelIsOk = false
				end
			end
		end
	end
	if g_updateLoopIndex % 5 == 0 and self:areFillLevelsOk(fillLevelInfo,true) and minFillLevelIsOk then 
		self:continue()
	end
	self:setInfoText('REACHED_REFILLING_POINT')
	
end

--TODO might change this one 
function FillableFieldworkAIDriver:levelDidNotChange(fillLevelPercent)
	--fillLevel changed in last loop-> start timer
	if self.prevFillLevelPct == nil or self.prevFillLevelPct ~= fillLevelPercent then
		self.prevFillLevelPct = fillLevelPercent
		courseplay:setCustomTimer(self.vehicle, "fillLevelChange", 3)
	end
	--if time is up and no fillLevel change happend, return true
	if courseplay:timerIsThrough(self.vehicle, "fillLevelChange",false) then
		if self.prevFillLevelPct == fillLevelPercent then
			return true
		end
		courseplay:resetCustomTimer(self.vehicle, "fillLevelChange",nil)
	end
end

function FillableFieldworkAIDriver:continue()
	AIDriver.continue(self)
	self.refillState = self.states.REFILL_DONE	
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
end

-- is the fill level ok to continue? With fillable tools we need to stop working when we are out
-- of material (seed, fertilizer, etc.)
function FillableFieldworkAIDriver:areFillLevelsOk(fillLevelInfo,isWaitingForRefill)
	local allOk = true
	local hasSeeds, hasNoFertilizer = false, false
	local liquidFertilizerFillLevel,herbicideFillLevel = 0, 0
	if self.vehicle.cp.settings.sowingMachineFertilizerEnabled:is(false) and AIDriverUtil.hasAIImplementWithSpecialization(self.vehicle, FertilizingCultivator) then
		courseplay:setInfoText(self.vehicle, "skipping loading Seeds/Fertilizer and continue with Cultivator !!!")
		return true
	end
	local totalFillLevel = 0
	for fillType, info in pairs(fillLevelInfo) do
		if info.treePlanterSpec then -- is TreePlanter
			--check fillLevel of pallet on top of treePlanter or if their is one pallet
			if not info.treePlanterSpec.mountedSaplingPallet or not info.treePlanterSpec.mountedSaplingPallet:getFillUnitFillLevel(1) then 
				allOk = false
			end
		else
			if self:isValidFillType(fillType) and info.fillLevel == 0 and info.capacity > 0 and not self:helperBuysThisFillType(fillType) then
				allOk = false
				if fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER then hasNoFertilizer = true end
			else
				if fillType == FillType.SEEDS then hasSeeds = true end
			end		
			if fillType == FillType.LIQUIDFERTILIZER then liquidFertilizerFillLevel = info.fillLevel end
			if fillType == FillType.HERBICIDE then  herbicideFillLevel = info.fillLevel end
		end
		totalFillLevel = totalFillLevel + info.fillLevel
	end
	-- special handling for extra frontTanks as they seems to change their fillType random
	-- if we don't have a seeds and either liquidFertilizer or herbicide just continue until both are empty
	if not allOk and not fillLevelInfo[FillType.SEEDS] and(liquidFertilizerFillLevel > 0 or herbicideFillLevel > 0) then 
		self:debugSparse('we probably have an empty front Tank')
		allOk = true
	end
	-- special handling for sowing machines with fertilizer
	if not allOk and self.vehicle.cp.settings.sowingMachineFertilizerEnabled:is(false) and hasNoFertilizer and hasSeeds then
		self:debugSparse('Has no fertilizer but has seeds so keep working.')
		allOk = true
	end
	--check if fillLevel changed, refill on Field
	if isWaitingForRefill then
		allOk = allOk and self.lastTotalFillLevel >= totalFillLevel
	end
	self.lastTotalFillLevel = totalFillLevel
	return allOk
end

--- Do we need to check this fill unit at all?
--- AIR and DEF are currently don't seem to be used in the game and some mods come with empty tank. Most stock
--- vehicles don't seem to consume any air or adblue.
function FillableFieldworkAIDriver:isValidFillType(fillType)
	return fillType ~= FillType.DEF	and fillType ~= FillType.AIR
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
	if g_currentMission.missionInfo.helperBuyFuel and self:isValidFuelType(self.vehicle,fillType) then
		return true
	end
	return false
end

function FillableFieldworkAIDriver:getFillLevelInfoText()
	return 'NEEDS_REFILLING'
end

function FillableFieldworkAIDriver:setLightsMask(vehicle)
	local x,y,z = getWorldTranslation(vehicle.rootNode);
	if not courseplay:isField(x, z) and self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE then
		vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_STREET)
	else
		vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_FULL)
	end
end

function FillableFieldworkAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeFillableFieldWorkDriver
end

function FillableFieldworkAIDriver:notAllowedToLoadNextFillType()
	return true
end

function FillableFieldworkAIDriver:getTurnEndForwardOffset()
	-- TODO: do other implements need this?
	if  SpecializationUtil.hasSpecialization(Sprayer, self.vehicle.specializations)
			and self.vehicle.cp.workWidth > self.vehicle.cp.turnDiameter then
		-- compensate for very wide implements like sprayer booms where the tip of the implement
		-- on the inner side of the turn may be very far forward of the vehicle's root and miss
		-- parts of the inside corner.
		local forwardOffset = - (self.vehicle.cp.workWidth - self.vehicle.cp.turnDiameter) / 2.5
		self:debug('sprayer working width %.1f > turn diameter %.1f, applying forward offset %.1f to turn end',
				self.vehicle.cp.workWidth, self.vehicle.cp.turnDiameter, forwardOffset)
		return forwardOffset
	else
		return 0
	end
end


