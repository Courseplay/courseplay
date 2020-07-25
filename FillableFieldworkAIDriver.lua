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
	courseplay.debugVehicle(11,vehicle,'FillableFieldworkAIDriver:init()')
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(FillableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_SEED_FERTILIZE
	self.refillState = self.states.TO_BE_REFILLED
end
function FillableFieldworkAIDriver:start(startingPoint)
	self:getSiloSelectedFillTypeSetting():cleanUpOldFillTypes()
	FieldworkAIDriver.start(self,startingPoint)
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
	local isNearWaitPoint, waitPointIx = self.course:hasWaitPointWithinDistance(self.ppc:getCurrentWaypointIx(), 5)
	self.waitPointIx = waitPointIx
	local isInWaitPointRange = self.waitPointIx and self.waitPointIx+8 >self.ppc:getCurrentWaypointIx() or isNearWaitPoint 
	if self:is_a(FieldSupplyAIDriver) then
		if not isInWaitPointRange  then
			courseplay:isTriggerAvailable(self.vehicle)
		end
	else
		courseplay:isTriggerAvailable(self.vehicle)
	end
	if self.course:isTemporary() then
		-- use the courseplay speed limit until we get to the actual unload corse fields (on alignment/temporary)
		self:setSpeed(self.vehicle.cp.speeds.field)
	elseif  self.refillState == self.states.TO_BE_REFILLED and isNearWaitPoint then
		local distanceToWait = self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, waitPointIx)
		self:setSpeed(MathUtil.clamp(distanceToWait,self.vehicle.cp.speeds.crawl,self:getRecordedSpeed()))
		if distanceToWait < 1 then
			self:fillAtWaitPoint()
		end	
	else
		if self:isLoading() and not self.activeTriggers then 
			self:fillAtWaitPoint()
		end
		-- just drive normally
		self:setSpeed(self:getRecordedSpeed())
		if self:is_a(FieldSupplyAIDriver) and self.pipe and not isInWaitPointRange then
			self.pipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
		end
	end
	if self:isLoading() then
		self:checkFilledUnitFillPercantage()
		if self.fillableObject and self.fillableObject.object and self.fillableObject.fillUnitIndex then
			local fillLevel = self.fillableObject.object:getFillUnitFillLevel(self.fillableObject.fillUnitIndex)
			local fillCapacity = self.fillableObject.object:getFillUnitCapacity(self.fillableObject.fillUnitIndex)
			courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",math.floor(fillLevel),fillCapacity))
			self.loadingText = nil
		end
		if self.loadingText then 
			courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",math.floor(self.loadingText.fillLevel),self.loadingText.capacity))
		end
	else
		self.loadingText = nil
	end
end

function FillableFieldworkAIDriver:setLoadingText(fillType,fillLevel,capacity)
	self.loadingText = {}
	self.loadingText.fillLevel = fillLevel
	self.loadingText.capacity = capacity
end

function FillableFieldworkAIDriver:setUnloadingText(fillType,fillLevel,capacity)	
	self.unloadingText = {}
	self.unloadingText.fillLevel = fillLevel
	self.unloadingText.capacity = capacity
end

function FillableFieldworkAIDriver:fillAtWaitPoint()
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	local fillTypeData, fillTypeDataSize= self:getSiloSelectedFillTypeData()
	if fillTypeData == nil then
		return
	end
	self:setLoadingState()
	
	local newTotalFillLevel = 0
	for fillType, info in pairs(fillLevelInfo) do
		for _,data in ipairs(fillTypeData) do
			if data.fillType == fillType then
				newTotalFillLevel = newTotalFillLevel+info.fillLevel
			end
		end
	end
	if self:levelDidNotChange(newTotalFillLevel) and self:areFillLevelsOk(fillLevelInfo) then 
		self:continue()
	end
	self:setInfoText('REACHED_REFILLING_POINT')
	
end

function FillableFieldworkAIDriver:continue()
	self.refillState = self.states.REFILL_DONE	
	AIDriver.continue(self)
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
end

-- is the fill level ok to continue? With fillable tools we need to stop working when we are out
-- of material (seed, fertilizer, etc.)
function FillableFieldworkAIDriver:areFillLevelsOk(fillLevelInfo)
	local allOk = true
	local hasSeeds, hasNoFertilizer = false, false
	if self:getSiloSelectedFillTypeSetting():isEmpty() and AIDriverUtil.hasAIImplementWithSpecialization(self.vehicle, Cultivator) then
		courseplay:setInfoText(self.vehicle, "skipping loading Seeds/Fertilizer and continue with Cultivator !!!")
		return true
	end
	
	for fillType, info in pairs(fillLevelInfo) do
		if self:isValidFillType(fillType) and info.fillLevel == 0 and info.capacity > 0 and not self:helperBuysThisFillType(fillType) then
			allOk = false
			if fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER then hasNoFertilizer = true end
		else
			if fillType == FillType.SEEDS then hasSeeds = true end
		end		
	end
	-- special handling for sowing machines with fertilizer
	if not allOk and self.vehicle.cp.settings.sowingMachineFertilizerEnabled:is(false) and hasNoFertilizer and hasSeeds then
		self:debugSparse('Has no fertilizer but has seeds so keep working.')
		allOk = true
	end
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
	if g_currentMission.missionInfo.helperBuyFuel and
		(fillType == FillType.DIESEL or fillType == FillType.FUEL) then
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

function FillableFieldworkAIDriver:setLoadingState(object,fillUnitIndex,fillType,trigger)
	if object and fillUnitIndex then 
		self.fillableObject = {}
		self.fillableObject.object = object
		self.fillableObject.fillUnitIndex = fillUnitIndex
		self.fillableObject.fillType = fillType
		self.fillableObject.trigger = trigger
	else
		self.fillableObject = nil
	end
	AIDriver.setLoadingState(self)
end

function FillableFieldworkAIDriver:isFilledUntilPercantageX(currentFillType,maxFillLevel)
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	for fillType, info in pairs(fillLevelInfo) do
		if fillType == currentFillType then 
			local fillLevelPercentage = info.fillLevel/info.capacity*100
			if fillLevelPercentage >= maxFillLevel then
				return true
			end
		end
	end
end

function FillableFieldworkAIDriver:checkFilledUnitFillPercantage()
	local fillTypeData, fillTypeDataSize= self:getSiloSelectedFillTypeData()
	if fillTypeData == nil then
		return
	end
	local fillLevelInfo = {}
	local okFillTypes = 0
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	for fillType, info in pairs(fillLevelInfo) do	
		if fillTypeData then 
			for _,data in ipairs(fillTypeData) do
				if data.fillType == fillType then
					local fillLevelPercentage = info.fillLevel/info.capacity*100
					if data.maxFillLevel and fillLevelPercentage >= data.maxFillLevel then 
						if self.fillableObject and self.fillableObject.fillType == fillType then
							self:forceStopLoading()
						end
						okFillTypes=okFillTypes+1
					end
				end
			end
		end
	end
	if okFillTypes == #fillTypeData then 
		return true
	end
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

function FillableFieldworkAIDriver:getSiloSelectedFillTypeSetting()
	if self.vehicle.cp.driver:is_a(FillableFieldworkAIDriver) then
		siloSelectedFillTypeSetting = self.vehicle.cp.settings.siloSelectedFillTypeFillableFieldWorkDriver
	end
	if self.vehicle.cp.driver:is_a(FieldSupplyAIDriver) then
		siloSelectedFillTypeSetting = self.vehicle.cp.settings.siloSelectedFillTypeFieldSupplyDriver
	end
	return siloSelectedFillTypeSetting
end

function FillableFieldworkAIDriver:getSiloSelectedFillTypeData()
	local siloSelectedFillTypeSetting = self:getSiloSelectedFillTypeSetting()
	if siloSelectedFillTypeSetting then
		local fillTypeData = siloSelectedFillTypeSetting:getData()
		local size = siloSelectedFillTypeSetting:getSize()
		return fillTypeData,size
	end
end
