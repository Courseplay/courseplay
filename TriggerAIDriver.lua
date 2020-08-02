--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko and Schwiti6190

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
Generic AIDriver for loading or unloading, especially at Triggers

]]

---@class TriggerAIDriver : AIDriver
TriggerAIDriver = CpObject(AIDriver)

TriggerAIDriver.myLoadingStates = {
	IS_LOADING = {},
	NOTHING = {},
	APPROACH_TRIGGER = {},
	APPROACH_AUGER_TRIGGER = {},
	IS_UNLOADING = {},
	DRIVE_NOW = {}
}
TriggerAIDriver.APPROACH_AUGER_TRIGGER_SPEED = 3

function TriggerAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'TriggerAIDriver:init()')
	AIDriver.init(self, vehicle)
	self:initStates(TriggerAIDriver.myLoadingStates)
	self.loadingState = self.states.NOTHING
end

function TriggerAIDriver:start(startingPoint)
	self:resetLoadingState()
	AIDriver.start(self,startingPoint)
end

function TriggerAIDriver:stop(msgReference)
	self:resetLoadingState()
	if self:isLoading() or self:isUnloading() then
		self:forceStopLoading()
	end
	self.loadingState = self.states.NOTHING
	AIDriver.stop(self,msgReference)
end

function TriggerAIDriver:setLoadingText(fillType,fillLevel,capacity)
	self.loadingText = {}
	self.loadingText.fillLevel = fillLevel
	self.loadingText.capacity = capacity
end

function TriggerAIDriver:setUnloadingText(fillType,fillLevel,capacity)	
	self.unloadingText = {}
	self.unloadingText.fillLevel = fillLevel
	self.unloadingText.capacity = capacity
end

function TriggerAIDriver:continue()
	if self:isLoading() or self:isUnloading() then
		self:forceStopLoading()
		self.loadingState = self.states.DRIVE_NOW
	end
	AIDriver.continue(self)
end

function TriggerAIDriver:driveCourse(dt)
	if self.loadingState == self.states.APPROACH_TRIGGER then
		self:setSpeed(self.vehicle.cp.speeds.approach)
	elseif self.loadingState == self.states.APPROACH_AUGER_TRIGGER then
		self:setSpeed(self.APPROACH_AUGER_TRIGGER_SPEED)
	end
	if self:isLoading() or self:isUnloading() then
		self:hold()
	end
	AIDriver.driveCourse(self,dt)
end

function TriggerAIDriver:isFilledUntilPercantageX(currentFillType,maxFillLevel)
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

function TriggerAIDriver:checkFilledUnitFillPercantage()
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
function TriggerAIDriver:levelDidNotChange(fillLevelPercent)
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

function TriggerAIDriver:getSiloSelectedFillTypeSetting()
	--override
end

function TriggerAIDriver:getSiloSelectedFillTypeData()
	local siloSelectedFillTypeSetting = self:getSiloSelectedFillTypeSetting()
	if siloSelectedFillTypeSetting then
		local fillTypeData = siloSelectedFillTypeSetting:getData()
		local size = siloSelectedFillTypeSetting:getSize()
		return fillTypeData,size
	end
end

----

--Driver set to wait while loading
function TriggerAIDriver:setLoadingState(object,fillUnitIndex,fillType,trigger)
	if object and fillUnitIndex then 
		self.fillableObject = {}
		self.fillableObject.object = object
		self.fillableObject.fillUnitIndex = fillUnitIndex
		self.fillableObject.fillType = fillType
		self.fillableObject.trigger = trigger
	else
		self.fillableObject = nil
	end
	if not self:ignoreTrigger() and not self:isLoading() then
		self.loadingState=self.states.IS_LOADING
		self:refreshHUD()
	end
end


function TriggerAIDriver:isLoading()
	if self.loadingState == self.states.IS_LOADING then
		return true
	end
end

function TriggerAIDriver:isUnloading()
	if self.loadingState == self.states.IS_UNLOADING then
		return true
	end
end

--Driver set to ignore the current Trigger as "continue" was pressed
function TriggerAIDriver:ignoreTrigger()
	if self.loadingState == self.states.DRIVE_NOW then
		return true
	end
end

--Driver stops loading
function TriggerAIDriver:resetLoadingState()
	if not self:ignoreTrigger() then 
		if not self.activeTriggers then
			self.loadingState=self.states.NOTHING
		else
			self.loadingState=self.states.APPROACH_TRIGGER
		end
	end
	self.augerTriggerSpeed=nil
	self.fillableObject = nil
end

--Driver is in trigger range slow down
function TriggerAIDriver:setInTriggerRange(isAugerTrigger)
	if self.loadingState==self.states.NOTHING then
		self.loadingState=self.states.APPROACH_TRIGGER
	end
	if isAugerTrigger and self.loadingState==self.states.APPROACH_TRIGGER then 
		self.loadingState=self.states.APPROACH_AUGER_TRIGGER
	end
end

--Driver set to wait while unloading
function TriggerAIDriver:setUnloadingState(object)
	if object then 
		self.fillableObject = {} 
		self.fillableObject.object = object --used to enable self:forceStopLoading()
	else
		self.fillableObject = nil
	end
	if not self:ignoreTrigger() then
		self.loadingState=self.states.IS_UNLOADING
		self:refreshHUD()
	end
end

--Driver stops unloading 
function TriggerAIDriver:resetUnloadingState()
	if not self:ignoreTrigger() then
		self.loadingState=self.states.NOTHING
	end
	self.fillableObject = nil
end

--countTriggerUp/countTriggerDown used to check current Triggers
function TriggerAIDriver:countTriggerUp(object)
	if self.activeTriggers ==nil then
		self.activeTriggers = {}
		self.loadingState = self.states.APPROACH_TRIGGER
	end
	if object then
		self.activeTriggers[object] = true
	end
end

function TriggerAIDriver:countTriggerDown(object)
	if object and self.activeTriggers then
		self.activeTriggers[object] = false
	end
	if self.activeTriggers == nil then 
		return
	end
	for object,bool in pairs(self.activeTriggers) do 
		if bool then 
			return
		end
	end
	self.activeTriggers =nil
	self.loadingState = self.states.NOTHING
end

--force stop loading/ unloading if "continue" or stop is pressed
function TriggerAIDriver:forceStopLoading()
	if self.fillableObject then 
		if self.fillableObject.trigger then 
			if self.fillableObject.trigger:isa(Vehicle) then --disable filling at Augerwagons
				--TODO!!
			else --disable filling at LoadingTriggers
				self.fillableObject.trigger:setIsLoading(false)
			end
		else 
			if self:isLoading() then -- disable filling at fillTriggers
				self.fillableObject.object:setFillUnitIsFilling(false)
			else -- disable unloading
				self.fillableObject.object:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
			end
		end
	end
end

--- Check if need to refill/unload anything
function TriggerAIDriver:allFillLevelsOk()
	if not self.vehicle.cp.workTools then return false end
	-- what here comes is basically what Giants' getFillLevelInformation() does but this returns the real fillType,
	-- not the fillTypeToDisplay as this latter is different for each type of seed
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	return self:areFillLevelsOk(fillLevelInfo)
end

function TriggerAIDriver:getAllFillLevels(object, fillLevelInfo)
	-- get own fill levels
	if object.getFillUnits then
		for _, fillUnit in pairs(object:getFillUnits()) do
			local fillType = self:getFillTypeFromFillUnit(fillUnit)
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
			self:debugSparse('%s: Fill levels: %s: %.1f/%.1f', object:getName(), fillTypeName, fillUnit.fillLevel, fillUnit.capacity)
			if not fillLevelInfo[fillType] then fillLevelInfo[fillType] = {fillLevel=0, capacity=0} end
			fillLevelInfo[fillType].fillLevel = fillLevelInfo[fillType].fillLevel + fillUnit.fillLevel
			fillLevelInfo[fillType].capacity = fillLevelInfo[fillType].capacity + fillUnit.capacity
		end
	end
 	-- collect fill levels from all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getAllFillLevels(impl.object, fillLevelInfo)
	end
end

function TriggerAIDriver:getFillTypeFromFillUnit(fillUnit)
	local fillType = fillUnit.lastValidFillType or fillUnit.fillType
	-- TODO: do we need to check more supported fill types? This will probably cover 99.9% of the cases
	if fillType == FillType.UNKNOWN then
		-- just get the first valid supported fill type
		for ft, valid in pairs(fillUnit.supportedFillTypes) do
			if valid then return ft end
		end
	else
		return fillType
	end
end

function TriggerAIDriver:areFillLevelsOk(fillLevelInfo)
	return true
end

--Trigger stuff


--scanning for LoadingTriggers and FillTriggers(checkFillTriggers)
function TriggerAIDriver:activateLoadingTriggerWhenAvailable()
    local vehicle = self.vehicle
	for key, object in pairs(g_currentMission.activatableObjects) do
		if object:getIsActivatable(vehicle) then
			local callback = {}		
			if object:isa(LoadTrigger) then 
				self:activateTriggerForVehicle(object, vehicle,callback)
				if callback.ok then 
					g_currentMission.activatableObjects[key] = nil
				end
				return
			end
        end
    end
    return
end

--check recusively if fillTriggers are enableable 
function TriggerAIDriver:activateFillTriggersWhenAvailable(object)
	if object.spec_fillUnit then
		local spec = object.spec_fillUnit
		local coverSpec = object.spec_cover	
		if spec.fillTrigger and #spec.fillTrigger.triggers>0 then
			local rootVehicle = object:getRootVehicle()
			if not rootVehicle.cp.driver:ignoreTrigger() and not spec.fillTrigger.isFilling then	
				if coverSpec and coverSpec.isDirty then 
					courseplay.debugFormat(2,"cover is still opening wait!")
				else
					object:setFillUnitIsFilling(true)
				end
				rootVehicle.cp.driver:setLoadingState()
			end
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:activateFillTriggersWhenAvailable(impl.object)
	end
end

--check for standart object unloading Triggers
function TriggerAIDriver:activateUnloadingTriggerWhenAvailable(object)    
	local spec = object.spec_dischargeable
	local rootVehicle = object:getRootVehicle()
	if rootVehicle and spec then 
		if spec:getCanToggleDischargeToObject() then 
			local currentDischargeNode = spec.currentDischargeNode
			if currentDischargeNode then
				if currentDischargeNode.dischargeObject then 
					rootVehicle.cp.driver:countTriggerUp(object)
					rootVehicle.cp.driver:setInTriggerRange()
					if not rootVehicle.cp.driver:isUnloading() then
						courseplay:setInfoText(rootVehicle,"COURSEPLAY_TIPTRIGGER_REACHED")
					end
				else
					rootVehicle.cp.driver:countTriggerDown(object)
				end
				if currentDischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_NO_FREE_CAPACITY then 
					CpManager:setGlobalInfoText(rootVehicle, 'FARM_SILO_IS_FULL');
					rootVehicle.cp.driver:setUnloadingState()
				elseif currentDischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_FILLTYPE_NOT_SUPPORTED then
				--	CpManager:setGlobalInfoText(rootVehicle, 'WRONG_FILLTYPE_FOR_TRIGGER');
				end
				if spec.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
					if not spec:getCanDischargeToObject(currentDischargeNode) then
						for i=1,#spec.dischargeNodes do
							if spec:getCanDischargeToObject(spec.dischargeNodes[i])then
								spec:setCurrentDischargeNodeIndex(spec.dischargeNodes[i]);
								currentDischargeNode = spec:getCurrentDischargeNode()
								break
							end
						end
					end
					if spec:getCanDischargeToObject(currentDischargeNode) and not rootVehicle.cp.driver:isNearFillPoint() then
						if not object:getFillUnitFillType(currentDischargeNode.fillUnitIndex) or rootVehicle.cp.driver:ignoreTrigger() then 
							return
						end
						spec:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)				
						rootVehicle.cp.driver:setUnloadingState(object)
					end
				end
			end
		else
			rootVehicle.cp.driver:countTriggerDown(object)
		end
	end
	for _,impl in pairs(object:getAttachedImplements()) do
		TriggerAIDriver:activateUnloadingTriggerWhenAvailable(impl.object)
	end
end

-- Custom version of trigger:onActivateObject to allow activating for a non-controlled vehicle
function TriggerAIDriver:activateTriggerForVehicle(trigger, vehicle,callback)
	--Cache giant values to restore later
	local defaultGetFarmIdFunction = g_currentMission.getFarmId;
	local oldControlledVehicle = g_currentMission.controlledVehicle;

	--Override farm id to match the calling vehicle (fixes issue when obtaining fill levels)
	local overriddenFarmIdFunc = function()
		local ownerFarmId = vehicle:getOwnerFarmId()
		courseplay.debugVehicle(19, vehicle, 'Overriding farm id during trigger activation to %d', ownerFarmId);
		return ownerFarmId;
	end
	g_currentMission.getFarmId = overriddenFarmIdFunc;

	--Override controlled vehicle if I'm not in it
	if g_currentMission.controlledVehicle ~= vehicle then
		g_currentMission.controlledVehicle = vehicle;
	end

	--Call giant method with new params set
	--trigger:onActivateObject(vehicle,callback);
	trigger:onActivateObject(vehicle,callback)
	--Restore previous values
	g_currentMission.getFarmId = defaultGetFarmIdFunction;
	g_currentMission.controlledVehicle = oldControlledVehicle;
end


-- LoadTrigger doesn't allow filling non controlled tools
function TriggerAIDriver:getIsActivatable(superFunc,objectToFill)
	--when the trigger is filling, it uses this function without objectToFill
	if objectToFill ~= nil then
		local vehicle = objectToFill:getRootVehicle()
		if objectToFill:getIsCourseplayDriving() or (vehicle~= nil and vehicle:getIsCourseplayDriving()) then
			--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
			if g_currentMission.controlledVehicle ~= vehicle then
				local oldControlledVehicle = g_currentMission.controlledVehicle;
				g_currentMission.controlledVehicle = vehicle or objectToFill;
				local result = superFunc(self,objectToFill);
				g_currentMission.controlledVehicle = oldControlledVehicle;
				return result;
			end
		end
	end
	return superFunc(self,objectToFill);
end
LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,TriggerAIDriver.getIsActivatable)

--LoadTrigger activate, if fillType is right and fillLevel ok 
function TriggerAIDriver:onActivateObject(superFunc,vehicle,callback)
	if courseplay:isAIDriverActive(vehicle) then 
		if not vehicle.cp.driver:isLoadingTriggerCallbackEnabled() then
			return superFunc(self)
		end
		local fillTypeData, fillTypeDataSize= vehicle.cp.driver:getSiloSelectedFillTypeData()
		if fillTypeData == nil then
			return superFunc(self)
		end
		--if continue button was pressed ignore trigger
		if vehicle.cp.driver:ignoreTrigger() then 
			return
		end
		if not self.isLoading then
			local fillLevels, capacity
			--normal fillLevels of silo
			if self.source.getAllFillLevels then 
				fillLevels, capacity = self.source:getAllFillLevels(g_currentMission:getFarmId())
			--g_company fillLevels of silo
			elseif self.source.getAllProvidedFillLevels then --g_company fillLevels
				--self.managerId should be self.extraParameter!!!
				fillLevels, capacity = self.source:getAllProvidedFillLevels(g_currentMission:getFarmId(), self.managerId)
			else
				return superFunc(self)
			end
			local fillableObject = self.validFillableObject
			local fillUnitIndex = self.validFillableFillUnitIndex
			local firstFillType = nil
			local validFillTypIndexes = {}
			local emptyOnes = 0
			for fillTypeIndex, fillLevel in pairs(fillLevels) do
				if self.fillTypes == nil or self.fillTypes[fillTypeIndex] then
					if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) then
						for _,data in ipairs(fillTypeData) do
							--check silo fillLevel
							if fillLevel > 0 and  fillTypeIndex == data.fillType then
								--check if specific fillType is reached
								if not vehicle.cp.driver:isFilledUntilPercantageX(fillTypeIndex,data.maxFillLevel) then 
									--cover is open, wait till it's open to start load
									if fillableObject.spec_cover and fillableObject.spec_cover.isDirty then 
										vehicle.cp.driver:setLoadingState(fillableObject,fillUnitIndex,fillTypeIndex,self)
										courseplay.debugFormat(2, 'Cover is still opening!')
										return
									end
									--fixes giants bug for Lemken SolitĂ¤r with has fillunit that keeps on filling to infinity
									if fillableObject:getFillUnitCapacity(fillUnitIndex) <=0 then 
										vehicle.cp.driver:resetLoadingState()
										return
									else
									--start loading everthing is ok
										self:onFillTypeSelection(fillTypeIndex)
										callback.ok = true
										return								
									end
								else
									courseplay.debugFormat(2, 'FillLevel reached!')
									callback.ok = true
								end
							else 
								emptyOnes = emptyOnes+1
							end
						end
					end
				end
			end
			--if all selected fillTypes are empty in the trigger and no fillLevel reached => wait for more
			if emptyOnes == fillTypeDataSize and not callback.ok then 
				vehicle.cp.driver:setLoadingState()
				CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
				return
			end
		end
	else 
		return superFunc(self)
	end
end
LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,TriggerAIDriver.onActivateObject)

--LoadTrigger => start/stop driver and close cover once free from trigger
function TriggerAIDriver:setIsLoading(superFunc,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
	local rootVehicle = self.validFillableObject:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then
		if not rootVehicle.cp.driver:isLoadingTriggerCallbackEnabled() then
			return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
		end
		if isLoading then 
			rootVehicle.cp.driver:setLoadingState(self.validFillableObject,fillUnitIndex, fillType,self)
			courseplay.debugFormat(2, 'LoadTrigger setLoading, FillType: '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
		else 
			rootVehicle.cp.driver:resetLoadingState()
			courseplay.debugFormat(2, 'LoadTrigger resetLoading and close Cover')
			SpecializationUtil.raiseEvent(self.validFillableObject, "onRemovedFillUnitTrigger",#self.validFillableObject.spec_fillUnit.fillTrigger.triggers)
			g_currentMission:addActivatableObject(self)
		end
	end
	return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
end
LoadTrigger.setIsLoading = Utils.overwrittenFunction(LoadTrigger.setIsLoading,TriggerAIDriver.setIsLoading)

--close cover after tipping for trailer if not closed already
function TriggerAIDriver:endTipping(superFunc,noEventSend)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then
		if rootVehicle.cp.settings.automaticCoverHandling:is(true) and self.spec_cover then
			self:setCoverState(0, true)
		end
		rootVehicle.cp.driver:resetUnloadingState()
	end
	return superFunc(self,noEventSend)
end
Trailer.endTipping = Utils.overwrittenFunction(Trailer.endTipping,TriggerAIDriver.endTipping)

