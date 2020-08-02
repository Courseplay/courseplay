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
	--this one is used to disable loading at the unloading stations,
	--might be better to disable the triggerID for loading
	local isInWaitPointRange = self.waitPointIx and self.waitPointIx+8 >self.ppc:getCurrentWaypointIx() or isNearWaitPoint 
	self:activateTriggersIfPossible(isInWaitPointRange)
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
		self:closePipeIfNeeded(isInWaitPointRange)
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

function FillableFieldworkAIDriver:activateTriggersIfPossible(isInWaitPointRange)
	self:activateFillTriggersWhenAvailable(self.vehicle)
	self:activateLoadingTriggerWhenAvailable()
end

function FillableFieldworkAIDriver:closePipeIfNeeded(isInWaitPointRange) 
	--override
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
	TriggerAIDriver.continue(self)
	self.refillState = self.states.REFILL_DONE	
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
	self.loadingState = self.states.NOTHING
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

function FillableFieldworkAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeFillableFieldWorkDriver
end


function FillableFieldworkAIDriver:isLoadingTriggerCallbackEnabled()
	return true
end

function FillableFieldworkAIDriver:setFillUnitIsFilling(superFunc,isFilling, noEventSend)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then 
		if not rootVehicle.cp.driver:isLoadingTriggerCallbackEnabled() then 
			return superFunc(self,isFilling, noEventSend)
		end
		local fillTypeData, fillTypeDataSize= rootVehicle.cp.driver:getSiloSelectedFillTypeData()
		if fillTypeData == nil then
			return superFunc(self,isFilling, noEventSend)
		end
		local spec = self.spec_fillUnit
		if isFilling ~= spec.fillTrigger.isFilling then
			if noEventSend == nil or noEventSend == false then
				if g_server ~= nil then
					g_server:broadcastEvent(SetFillUnitIsFillingEvent:new(self, isFilling), nil, nil, self)
				else
					g_client:getServerConnection():sendEvent(SetFillUnitIsFillingEvent:new(self, isFilling))
				end
			end
			if isFilling then
				-- find the first trigger which is activable
				spec.fillTrigger.currentTrigger = nil
				for _, trigger in ipairs(spec.fillTrigger.triggers) do
					for _,data in ipairs(fillTypeData) do
						if trigger:getIsActivatable(self) then
							local fillType = trigger:getCurrentFillType()
							local fillUnitIndex = nil
							if fillType and fillType == data.fillType then
								fillUnitIndex = self:getFirstValidFillUnitToFill(fillType)
							end
							if not rootVehicle.cp.driver:isFilledUntilPercantageX(fillType,data.maxFillLevel) then 
								if fillUnitIndex then
									rootVehicle = self:getRootVehicle()
									rootVehicle.cp.driver:setLoadingState(self,fillUnitIndex,fillType)
									spec.fillTrigger.currentTrigger = trigger
									courseplay.debugFormat(2,"FillUnit setLoading, FillType: "..g_fillTypeManager:getFillTypeByIndex(fillType).title)
									break
								end
							end
						end
					end
				end
			end
			spec.fillTrigger.isFilling = isFilling
			if self.isClient then
				self:setFillSoundIsPlaying(isFilling)
				if spec.fillTrigger.currentTrigger ~= nil then
					spec.fillTrigger.currentTrigger:setFillSoundIsPlaying(isFilling)
				end
			end
			SpecializationUtil.raiseEvent(self, "onFillUnitIsFillingStateChanged", isFilling)
			if not isFilling then
				self:updateFillUnitTriggers()
				rootVehicle.cp.driver:resetLoadingState()
				courseplay.debugFormat(2,"FillUnit resetLoading")
			end
		end
		return
	end
	return superFunc(self,isFilling, noEventSend)
end
FillUnit.setFillUnitIsFilling = Utils.overwrittenFunction(FillUnit.setFillUnitIsFilling,FillableFieldworkAIDriver.setFillUnitIsFilling)

