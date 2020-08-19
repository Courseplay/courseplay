
TriggerHandler = CpObject()

TriggerHandler.myLoadingStates = {
	IS_LOADING = {},
	NOTHING = {},
	APPROACH_TRIGGER = {},
	APPROACH_AUGER_TRIGGER = {},
	IS_UNLOADING = {},
	DRIVE_NOW = {},
	STOPPED = {}
}
TriggerHandler.APPROACH_AUGER_TRIGGER_SPEED = 3

function TriggerHandler:init(vehicle,siloSelectedFillTypeSetting)
	self.vehicle = vehicle
	self.driver = vehicle.cp.driver
	self.siloSelectedFillTypeSetting=siloSelectedFillTypeSetting
--	self.driveOnAtFillLevel=driveOnAtFillLevelSetting
	self.allwaysSearchFuel = vehicle.cp.settings.allwaysSearchFuel
	self.validFillTypeLoading = false
	self.validFillTypeUnloading = false
	self.validFillTypeUnloadingAugerWagon = false
	self.validFuelLoading = false
	self.states = {}
	self:initStates(TriggerHandler.myLoadingStates)
	self.loadingState = self.states.STOPPED
	self.triggers = {}
	self.isInAugerWagonTrigger = false
	self.fillableObject = nil
end 

function TriggerHandler:initStates(states)
	for key, _ in pairs(states) do
		self.states[key] = {name = tostring(key)}
	end
end

function TriggerHandler:onStart()
	self:changeLoadingState(self.states.NOTHING)
end 

function TriggerHandler:onStop()
	self:changeLoadingState(self.states.STOPPED)
	self:forceStopLoading()
end 

function TriggerHandler:onUpdate()
	if not self:isDriveNowActivated() and not self:isStopped() then
		if self.validFillTypeLoading or self:isAllowedToLoadFuel() then
			self:updateLoadingTriggers()
		end
	end
	if not self:isStopped() then 
		if self.validFillTypeUnloading then 
			self:updateUnloadingTriggers()
		end
	end
end 

function TriggerHandler:onContinue()
	self:forceStopLoading()
	if self:isStopped() then 
		self:changeLoadingState(self.states.NOTHING)
	elseif self:isLoading() or self:isUnloading() then 
		self:changeLoadingState(self.states.NOTHING)
	end
end

function TriggerHandler:writeUpdateStream(streamId)
	streamWriteString(streamId,self.loadingState.name)
end

function TriggerHandler:readUpdateStream(streamId)
	local nameState = streamReadString(streamId)
	self.loadingState = self.states[nameState]
end

function TriggerHandler:onDriveNow()

end

function TriggerHandler:changeLoadingState(newState)
	if newState ~= self.loadingState then 
		self.loadingState = newState
		courseplay.debugFormat(2,"new TriggerHandler state = %s!",self.loadingState.name)
	end
end

function TriggerHandler:updateLoadingTriggers()
	self:activateLoadingTriggerWhenAvailable()
	self:activateFillTriggersWhenAvailable(self.vehicle)
	if self:isLoading() then
		self:disableFillingIfFull()
	end
end 

function TriggerHandler:updateUnloadingTriggers()
	self:activateUnloadingTriggerWhenAvailable(self.vehicle)
end 

function TriggerHandler:disableFillingIfFull()
	if self:isFilledUntilPercantageX() then 
		self:forceStopLoading()
		self:resetLoadingState()
	end
end

function TriggerHandler:isFilledUntilPercantageX()
	if self.fillableObject then
		local fillUnitIndex = self.fillableObject.fillUnitIndex
		local object = self.fillableObject.object
		local maxFillLevelPercentage = self.siloSelectedFillTypeSetting:getMaxFillLevelByFillType(self.fillableObject.fillType)
		return not self:canLoadFillType(object,fillUnitIndex,maxFillLevelPercentage)
	end
end

function TriggerHandler:getSiloSelectedFillTypeData()
	if self.siloSelectedFillTypeSetting then
		local fillTypeData = self.siloSelectedFillTypeSetting:getData()
		local size = self.siloSelectedFillTypeSetting:getSize()
		return fillTypeData,size
	end
end

----

--Driver set to wait while loading
function TriggerHandler:setLoadingState(object,fillUnitIndex,fillType,trigger)
	self:setFillableObject(object,fillUnitIndex,fillType,trigger,true)
	--saftey check for drive now
	if not self:isDriveNowActivated() and not self:isLoading() then
		self:changeLoadingState(self.states.IS_LOADING)
	end
end

function TriggerHandler:setFillableObject(object,fillUnitIndex,fillType,trigger,isLoading)
	if object then
		self.fillableObject = {}
		self.fillableObject.object = object
		self.fillableObject.fillUnitIndex = fillUnitIndex
		self.fillableObject.fillType = fillType
		self.fillableObject.trigger = trigger
		self.fillableObject.isLoading = isLoading
	end
	self.driver:refreshHUD()
end

function TriggerHandler:resetFillableObject()
	self.fillableObject=nil
end

function TriggerHandler:isLoading()
	return self.loadingState == self.states.IS_LOADING
end

function TriggerHandler:isUnloading()
	return self.loadingState == self.states.IS_UNLOADING
end

--Driver stops loading
function TriggerHandler:resetLoadingState()
	if not self:isDriveNowActivated() then
		self:changeLoadingState(self.states.APPROACH_TRIGGER)
	end
	self.augerTriggerSpeed=nil
	self:resetFillableObject()
end

--Driver set to wait while unloading
function TriggerHandler:setUnloadingState(object,fillUnitIndex,fillType)
	self:setFillableObject(object,fillUnitIndex,fillType)
	if not self:isDriveNowActivated() then
		self:changeLoadingState(self.states.IS_UNLOADING)
	end
	self.driver:refreshHUD()
end

--Driver stops unloading 
function TriggerHandler:resetUnloadingState()
	if not self:isDriveNowActivated() then
		self:changeLoadingState(self.states.NOTHING)
	end
	self:resetFillableObject()
end

function TriggerHandler:enableTriggerSpeed(lastTriggerID,object,isInAugerWagonTrigger)
	self.isInAugerWagonTrigger = isInAugerWagonTrigger
	if (not self:isDriveNowActivated() or lastTriggerID ~= self.lastTriggerID )and not self:isLoading() and not self:isUnloading() then 
		self:changeLoadingState(self.isInAugerWagonTrigger and self.states.APPROACH_AUGER_TRIGGER or self.states.APPROACH_TRIGGER)
	end
	if self.loadingState == self.states.APPROACH_TRIGGER and isInAugerWagonTrigger then 
		self.loadingState = self.states.APPROACH_AUGER_TRIGGER
	end
	self.lastTriggerID = lastTriggerID
	if lastTriggerID < 0 then 
		self.lastUnloadingTriggerID = lastTriggerID*(-1)
	end
	self.triggers[object]=true
end

function TriggerHandler:setDriveNow()
	self:forceStopLoading()
	self:changeLoadingState(self.states.DRIVE_NOW)
end

function TriggerHandler:disableTriggerSpeed(object)
	self.triggers[object]=nil
	if not self:isDriveNowActivated() and not self:isLoading() and not self:isUnloading() and next(self.triggers) == nil then 
		self:changeLoadingState(self.states.NOTHING)
	end
	if not self:isLoading() and not self:isUnloading() then 
		self:resetFillableObject()
	end
	self.isInAugerWagonTrigger = nil
end

function TriggerHandler:isInTrigger()
	local bool = next(self.triggers) ~=nil
	return bool, self.isInAugerWagonTrigger
end

function TriggerHandler:isDriveNowActivated()
	return self.loadingState == self.states.DRIVE_NOW
end

function TriggerHandler:isStopped()
	return self.loadingState == self.states.STOPPED
end

--force stop loading/ unloading if "continue" or stop is pressed
function TriggerHandler:forceStopLoading()
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
			elseif self.fillableObject.setDischargeState then -- disable unloading
				self.fillableObject.object:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
			end
		end
	end
end

function TriggerHandler:needsFuel()
	local dieselIndex = self.vehicle:getConsumerFillUnitIndex(FillType.DIESEL)
	local currentFuelPercentage = self.vehicle:getFillUnitFillLevelPercentage(dieselIndex) * 100
	local searchForFuel = self.allwaysSearchFuel:is(true) and currentFuelPercentage <99 or currentFuelPercentage < 20
	if searchForFuel then 
		return true
	end
end

--Trigger stuff


--scanning for LoadingTriggers and FillTriggers(checkFillTriggers)
function TriggerHandler:activateLoadingTriggerWhenAvailable()
	for key, object in pairs(g_currentMission.activatableObjects) do
		if object:getIsActivatable(self.vehicle) then
			if object:isa(LoadTrigger) and (object ~= NetworkUtil.getObject(self.lastUnloadingTriggerID) or self:isNearFillPoint()) then 
				self:activateTriggerForVehicle(object, self.vehicle)
				return
			end
        end
    end
    return
end

--check recusively if fillTriggers are enableable 
function TriggerHandler:activateFillTriggersWhenAvailable(object)
	if object.spec_fillUnit then
		local spec = object.spec_fillUnit
		local coverSpec = object.spec_cover	
		if spec.fillTrigger and #spec.fillTrigger.triggers>0 then
			if not spec.fillTrigger.isFilling then	
				if coverSpec and coverSpec.isDirty then 
					courseplay.debugFormat(2,"cover is still opening wait!")
					self:setLoadingState()
				else
					object:setFillUnitIsFilling(true)
				end
			end
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:activateFillTriggersWhenAvailable(impl.object)
	end
end

--check for standart object unloading Triggers
function TriggerHandler:activateUnloadingTriggerWhenAvailable(object)    
	local spec = object.spec_dischargeable
	local rootVehicle = object:getRootVehicle()
	if rootVehicle and spec then 
		if spec:getCanToggleDischargeToObject() then 
			local currentDischargeNode = spec.currentDischargeNode
			if currentDischargeNode then
				if currentDischargeNode.dischargeObject then 
					if not self:isUnloading() then
						courseplay:setInfoText(rootVehicle,"COURSEPLAY_TIPTRIGGER_REACHED")
					end
					self:enableTriggerSpeed(-NetworkUtil.getObjectId(object),object)
				else
					self:disableTriggerSpeed(object)
				end
				if currentDischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_NO_FREE_CAPACITY then 
					CpManager:setGlobalInfoText(rootVehicle, 'FARM_SILO_IS_FULL');
					self:setUnloadingState()
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
					if spec:getCanDischargeToObject(currentDischargeNode) then
						if not object:getFillUnitFillType(currentDischargeNode.fillUnitIndex) or self:isDriveNowActivated() then 
							return
						end
						if spec.setDischargeState then
							spec:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)				
							self:setUnloadingState(object,currentDischargeNode.fillUnitIndex,spec:getDischargeFillType(currentDischargeNode))
						end
					end
				end
			else
				self:disableTriggerSpeed(object)
			end
		else
			self:disableTriggerSpeed(object)
		end
	end
	for _,impl in pairs(object:getAttachedImplements()) do
		self:activateUnloadingTriggerWhenAvailable(impl.object)
	end
end



function TriggerHandler:enableFillTypeLoading()
	self.validFillTypeLoading = true
end 

function TriggerHandler:enableFillTypeUnloading()
	self.validFillTypeUnloading = true
end

function TriggerHandler:enableFillTypeUnloadingAugerWagon()
	self.validFillTypeUnloadingAugerWagon = true
end

function TriggerHandler:enableFuelLoading()
	self.validFuelLoading = true
end

function TriggerHandler:disableFillTypeLoading()
	self.validFillTypeLoading = false
end 

function TriggerHandler:disableFillTypeUnloading()
	self.validFillTypeUnloading = false
	self.validFillTypeUnloadingAugerWagon = false
end

function TriggerHandler:disableFuelLoading()
	self.validFuelLoading = false
end

function TriggerHandler:isAllowedToLoadFillType()
	if self.validFillTypeLoading and self.siloSelectedFillTypeSetting then
		return true
	end
end 

function TriggerHandler:isAllowedToLoadFuel()
	if self.validFuelLoading and self:needsFuel() then
		return true
	end
end 

function TriggerHandler:canLoadFillType(object,fillUnitIndex,maxFillLevelPercentage)  
	local objectFillLevelPercentage = object:getFillUnitFillLevelPercentage(fillUnitIndex)
	courseplay:debugFormat(2,"fillPercentage: %s > maxFillLevel: %s",tostring(objectFillLevelPercentage),tostring(maxFillLevelPercentage))
	return objectFillLevelPercentage*100 < (maxFillLevelPercentage or 99)
end

function TriggerHandler:isMinFillLevelReached(object,fillUnitIndex,triggerFillLevel,minFillLevelPercentage)
	local objectFillCapacity = object:getFillUnitCapacity(fillUnitIndex)
	local minNeededFillLevel = minFillLevelPercentage and minFillLevelPercentage*0.01*objectFillCapacity or 0.1
	return triggerFillLevel and triggerFillLevel > minNeededFillLevel or triggerFillLevel == nil
end

function TriggerHandler:isRunCounterValid(runCounter) 
	return runCounter and runCounter>0 or runCounter == nil
end


-- Custom version of trigger:onActivateObject to allow activating for a non-controlled vehicle
function TriggerHandler:activateTriggerForVehicle(trigger, vehicle)
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
	trigger:onActivateObject(vehicle)
	--Restore previous values
	g_currentMission.getFarmId = defaultGetFarmIdFunction;
	g_currentMission.controlledVehicle = oldControlledVehicle;
end

-- LoadTrigger doesn't allow filling non controlled tools
function TriggerHandler:getIsActivatable(superFunc,objectToFill)
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
LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,TriggerHandler.getIsActivatable)

--LoadTrigger activate, if fillType is right and fillLevel ok 
function TriggerHandler:onActivateObject(superFunc,vehicle)
	if courseplay:isAIDriverActive(vehicle) then 
		local triggerHandler = vehicle.cp.driver.triggerHandler
		if not triggerHandler:isAllowedToLoadFuel() and not triggerHandler:isAllowedToLoadFillType() then 
			return superFunc(self)
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
			--fixes giants bug for Lemken Solitaer with has fillunit that keeps on filling to infinity
			if fillableObject:getFillUnitCapacity(fillUnitIndex) <=0 then 
				triggerHandler:resetLoadingState()
				return
			end
			local firstFillType = nil
			local validFillTypIndexes = {}
			local emptyOnes = 0
			local lastCounter
			local fillTypeData,fillTypeDataSize = triggerHandler:getSiloSelectedFillTypeData()
			if triggerHandler:isAllowedToLoadFillType() then
				for _,data in ipairs(fillTypeData) do
					for fillTypeIndex, fillLevel in pairs(fillLevels) do
						if self.fillTypes == nil or self.fillTypes[fillTypeIndex] then
							if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) and fillTypeIndex == data.fillType then
								if triggerHandler:canLoadFillType(fillableObject,fillUnitIndex,data.maxFillLevel) then 
									if triggerHandler:isMinFillLevelReached(fillableObject,fillUnitIndex,fillLevel,data.minFillLevel) then 
										if triggerHandler:isRunCounterValid(data.runCounter) then 
											--waiting for cover to be open
											if fillableObject.spec_cover and fillableObject.spec_cover.isDirty then 
												triggerHandler:setLoadingState(fillableObject,fillUnitIndex,fillTypeIndex,self)
												courseplay.debugFormat(2, 'Cover is still opening!')
												return
											end
											--all okay start loading
											self:onFillTypeSelection(fillTypeIndex)
											g_currentMission.activatableObjects[self] = nil
											return
										else
											--runCounter is zero
											courseplay.debugFormat(2, 'runCounter = 0!')
										end
									else	
										--not enough in silo
										courseplay.debugFormat(2, 'FillType is empty or minFillLevel not reached!')
										emptyOnes = emptyOnes +1
									end
								else
									--full
									courseplay.debugFormat(2, 'FillLevel reached!')
									g_currentMission.activatableObjects[self] = nil
									triggerHandler:resetLoadingState()
									return
								end
							end
						end
					end
					lastCounter=data.runCounter
				end
			end
			if triggerHandler:isAllowedToLoadFuel() and fillableObject == vehicle then 
				for fillTypeIndex, fillLevel in pairs(fillLevels) do
					if fillTypeIndex == FillType.DIESEL  then 
						if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) then
							if triggerHandler:canLoadFillType(fillableObject,fillUnitIndex) then 
								if triggerHandler:isMinFillLevelReached(fillableObject,fillUnitIndex,fillLevel) then 
									self:onFillTypeSelection(fillTypeIndex)
									g_currentMission.activatableObjects[self] = nil
								else
									triggerHandler:setLoadingState()
									CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY')
									courseplay.debugFormat(2, 'No Diesel at this trigger.')
								end
							else
								courseplay.debugFormat(2, 'max FillLevel Reached')
							end
						end
					end
				end
			end
			--if all selected fillTypes are empty in the trigger and no fillLevel reached => wait for more
			if emptyOnes == fillTypeDataSize and emptyOnes>0 then 
				triggerHandler:setLoadingState()
				CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
				courseplay.debugFormat(2, 'Silo empty, emptyOnes: '..emptyOnes)
				return
			elseif lastCounter == 0 then 
				triggerHandler:setLoadingState()
				CpManager:setGlobalInfoText(vehicle, 'RUNCOUNTER_ERROR_FOR_TRIGGER');
				courseplay.debugFormat(2, 'last runCounter=0 ')
				return
			end
		end
	else 
		return superFunc(self,vehicle)
	end
end
LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,TriggerHandler.onActivateObject)

--LoadTrigger => start/stop driver and close cover once free from trigger
function TriggerHandler:setIsLoading(superFunc,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
	local rootVehicle = self.validFillableObject:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		if not triggerHandler.validFillTypeLoading and not triggerHandler.validFuelLoading then
			return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
		end
		if isLoading then 
			triggerHandler:setLoadingState(self.validFillableObject,fillUnitIndex, fillType,self)
			courseplay.debugFormat(2, 'LoadTrigger setLoading, FillType: '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
		else 
			triggerHandler:resetLoadingState()
			courseplay.debugFormat(2, 'LoadTrigger resetLoading and close Cover')
			SpecializationUtil.raiseEvent(self.validFillableObject, "onRemovedFillUnitTrigger",#self.validFillableObject.spec_fillUnit.fillTrigger.triggers)
			g_currentMission:addActivatableObject(self)
		end
	end
	return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
end
LoadTrigger.setIsLoading = Utils.overwrittenFunction(LoadTrigger.setIsLoading,TriggerHandler.setIsLoading)

--close cover after tipping for trailer if not closed already
function TriggerHandler:endTipping(superFunc,noEventSend)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then
		if rootVehicle.cp.settings.automaticCoverHandling:is(true) and self.spec_cover then
			self:setCoverState(0, true)
		end
		rootVehicle.cp.driver.triggerHandler:resetUnloadingState()
	end
	return superFunc(self,noEventSend)
end
Trailer.endTipping = Utils.overwrittenFunction(Trailer.endTipping,TriggerHandler.endTipping)

function TriggerHandler:setFillUnitIsFilling(superFunc,isFilling, noEventSend)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then 
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		if not triggerHandler:isAllowedToLoadFuel() and not triggerHandler:isAllowedToLoadFillType() then
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
			spec.fillTrigger.isFilling = isFilling
			if isFilling then
				spec.fillTrigger.currentTrigger = nil
				-- find the first trigger which is activable
				local fillTypeData,fillTypeDataSize = triggerHandler:getSiloSelectedFillTypeData()
				if triggerHandler:isAllowedToLoadFillType() then
					for _,data in ipairs(fillTypeData) do
						for _, trigger in ipairs(spec.fillTrigger.triggers) do
							if trigger:getIsActivatable(self) and (trigger ~= NetworkUtil.getObject(self.lastUnloadingTriggerID) or self:isNearFillPoint()) then
								local fillType = trigger:getCurrentFillType()
								local fillUnitIndex = nil
								if fillType and fillType == data.fillType then
									fillUnitIndex = self:getFirstValidFillUnitToFill(fillType)
								end
								if fillUnitIndex then
									if triggerHandler:canLoadFillType(self,fillUnitIndex,data.maxFillLevel) then 
							--			if triggerHandler:isMinFillLevelReached(object,fillUnitIndex,triggerFillLevel) then 
											if triggerHandler:isRunCounterValid(data.runCounter) then 
												triggerHandler:setLoadingState(self,fillUnitIndex,fillType)
												spec.fillTrigger.currentTrigger = trigger
												courseplay.debugFormat(2,"FillUnit setLoading, FillType: "..g_fillTypeManager:getFillTypeByIndex(fillType).title)
												break
											else
												courseplay.debugFormat(2, 'runCounter == 0!')
											end
						--				else
											--minFillLevel not reached
						--				end
									else
										courseplay.debugFormat(2, 'fillLevel reached')
									end
								else
									courseplay.debugFormat(2, 'fillUnitIndex not found')
								end
							end
						end
					end
				end
				if spec.fillTrigger.currentTrigger == nil and triggerHandler:isAllowedToLoadFuel() and self == rootVehicle then 
					for _, trigger in ipairs(spec.fillTrigger.triggers) do
						if trigger:getIsActivatable(self) then
							local dieselFillTypeFound = trigger:getCurrentFillType() == FillType.DIESEL
							local fillUnitIndex = nil
							if dieselFillTypeFound then 
								fillUnitIndex = self:getFirstValidFillUnitToFill(FillType.DIESEL)
							end
							if fillUnitIndex and triggerHandler:canLoadFillType(self,fillUnitIndex) then 
								spec.fillTrigger.currentTrigger = trigger
								triggerHandler:setLoadingState(self,fillUnitIndex,fillType)
								courseplay.debugFormat(2,"FillUnit setLoading, FillType: "..g_fillTypeManager:getFillTypeByIndex(fillType).title)
							end								
						end
					end
				end
			end
			if self.isClient then
				self:setFillSoundIsPlaying(isFilling)
				if spec.fillTrigger.currentTrigger ~= nil then
					spec.fillTrigger.currentTrigger:setFillSoundIsPlaying(isFilling)
				end
			end
			SpecializationUtil.raiseEvent(self, "onFillUnitIsFillingStateChanged", isFilling)
			if not isFilling then
				triggerHandler:resetLoadingState()
				courseplay.debugFormat(2,"FillUnit resetLoading")
				self:updateFillUnitTriggers()
			end
		end
	else
		return superFunc(self,isFilling, noEventSend)
	end
end
FillUnit.setFillUnitIsFilling = Utils.overwrittenFunction(FillUnit.setFillUnitIsFilling,TriggerHandler.setFillUnitIsFilling)


--LoadTrigger callback used to open correct cover for loading 
function TriggerHandler:loadTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	--legancy code!!!
	courseplay:SiloTrigger_TriggerCallback(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject and fillableObject:isa(Vehicle) then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:isAIDriverActive(rootVehicle) then
	--	if rootVehicle.cp.driver.triggerHandler.validFillTypeLoading then
			TriggerHandler:handleLoadTriggerCallback(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId,rootVehicle,fillableObject)
	--	end
	end
end
LoadTrigger.loadTriggerCallback = Utils.appendedFunction(LoadTrigger.loadTriggerCallback,TriggerHandler.loadTriggerCallback)

function TriggerHandler:handleLoadTriggerCallback(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId,rootVehicle,fillableObject)
	local triggerHandler = rootVehicle.cp.driver.triggerHandler
	if onEnter then 
		courseplay.debugFormat(2, 'LoadTrigger onEnter')
		if fillableObject.getFillUnitIndexFromNode ~= nil then
			local fillLevels, capacity
			if self.source.getAllFillLevels then
				fillLevels, capacity = self.source:getAllFillLevels(g_currentMission:getFarmId())
			elseif self.source.getAllProvidedFillLevels then
				fillLevels, capacity = self.source:getAllProvidedFillLevels(g_currentMission:getFarmId(), self.managerId)
			end
			if fillLevels then
				local foundFillUnitIndex = fillableObject:getFillUnitIndexFromNode(otherId)
				for fillTypeIndex, fillLevel in pairs(fillLevels) do
					if fillableObject:getFillUnitSupportsFillType(foundFillUnitIndex, fillTypeIndex) then
						if fillableObject:getFillUnitAllowsFillType(foundFillUnitIndex, fillTypeIndex) and fillableObject.spec_cover then
							SpecializationUtil.raiseEvent(fillableObject, "onAddedFillUnitTrigger",fillTypeIndex,foundFillUnitIndex,1)
							courseplay.debugFormat(2, 'open Cover for loading')
						end
					end
				end
			end
		end
	end
	if onLeave then 
		triggerHandler:disableTriggerSpeed(otherId)
		spec = fillableObject.spec_fillUnit
		if spec then
			SpecializationUtil.raiseEvent(fillableObject, "onRemovedFillUnitTrigger",#spec.fillTrigger.triggers)
		end
		courseplay.debugFormat(2,"LoadTrigger onLeave")
	else
		triggerHandler:enableTriggerSpeed(triggerId,otherId)
	end
end

--FillTrigger callback used to set approach speed for Cp driver
function TriggerHandler:fillTriggerCallback(superFunc, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject and fillableObject:isa(Vehicle) then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:isAIDriverActive(rootVehicle) then
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		if not triggerHandler.validFillTypeLoading then
			return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
		end		
		if onEnter then
			courseplay.debugFormat(2, 'fillTrigger onEnter')
		end
		if onLeave then
			triggerHandler:disableTriggerSpeed(otherActorId)
			courseplay.debugFormat(2, 'fillTrigger onLeave')
		else
			triggerHandler:enableTriggerSpeed(triggerId,otherActorId)
		end
	end
	return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end
FillTrigger.fillTriggerCallback = Utils.overwrittenFunction(FillTrigger.fillTriggerCallback, TriggerHandler.fillTriggerCallback)

--check if the vehicle is controlled by courseplay
function courseplay:isAIDriverActive(rootVehicle) 
	if rootVehicle and rootVehicle.cp and rootVehicle.cp.driver and rootVehicle:getIsCourseplayDriving() and rootVehicle.cp.driver:isActive() and not rootVehicle.cp.driver:isAutoDriveDriving() then
		return true
	end
end

--Augerwagons handling
--Pipe callback used for augerwagons to open the cover on the fillableObject
function TriggerHandler:unloadingTriggerCallback(superFunc,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) and rootVehicle.cp.driver.triggerHandler.validFillTypeUnloadingAugerWagon then 
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil and object ~= self and object:isa(Vehicle) then
            local objectRootVehicle = object:getRootVehicle()
			if not courseplay:isAIDriverActive(objectRootVehicle) then 
				return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
			end
			local objectTriggerHandler = objectRootVehicle.cp.driver.triggerHandler
			objectTriggerHandler:enableTriggerSpeed(NetworkUtil.getObjectId(self),object)
			if object.getFillUnitIndexFromNode ~= nil and not onLeave then
                local fillUnitIndex = object:getFillUnitIndexFromNode(otherId)
                if fillUnitIndex ~= nil then
                    local dischargeNode = self:getDischargeNodeByIndex(self:getPipeDischargeNodeIndex())
                    if dischargeNode ~= nil then
                        local fillType = self:getFillUnitFillType(dischargeNode.fillUnitIndex)
						local validFillUnitIndex = object:getFirstValidFillUnitToFill(fillType)
                        if fillType and validFillUnitIndex then 
							courseplay.debugFormat(2,"unloadingTriggerCallback open Cover for "..g_fillTypeManager:getFillTypeByIndex(fillType).title)
							SpecializationUtil.raiseEvent(object, "onAddedFillUnitTrigger",fillType,validFillUnitIndex,1)
							objectTriggerHandler:enableTriggerSpeed(NetworkUtil.getObjectId(self),object,true)
						end
					end
				end
			elseif onLeave then
				SpecializationUtil.raiseEvent(object, "onRemovedFillUnitTrigger",0)
				courseplay.debugFormat(2,"unloadingTriggerCallback close Cover")
				objectTriggerHandler:resetLoadingState()
				objectTriggerHandler:disableTriggerSpeed(object)
			end
		end
		if onLeave then
			courseplay.debugFormat(2,"unloadingTriggerCallback onLeave")
		end
		if onEnter then 
			courseplay.debugFormat(2,"unloadingTriggerCallback onEnter")
		end
	end
	return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
end
Pipe.unloadingTriggerCallback = Utils.overwrittenFunction(Pipe.unloadingTriggerCallback,TriggerHandler.unloadingTriggerCallback)

--stoping mode 4 driver for augerwagons
function TriggerHandler:onDischargeStateChanged(superFunc,state)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		local dischargeNode = self:getCurrentDischargeNode()
		if dischargeNode and dischargeNode.dischargeObject and triggerHandler.validFillTypeUnloadingAugerWagon then 
			if dischargeNode.dischargeObject:isa(Vehicle) then 
				local objectRootVehicle = dischargeNode.dischargeObject:getRootVehicle()
				if courseplay:isAIDriverActive(objectRootVehicle) then
					local objectTriggerHandler = objectRootVehicle.cp.driver.triggerHandler
					if state == Dischargeable.DISCHARGE_STATE_OFF then
						objectTriggerHandler:resetLoadingState()
						triggerHandler:resetFillableObject()
					else
						objectTriggerHandler:setLoadingState(dischargeNode.dischargeObject,dischargeNode.dischargeFillUnitIndex,self:getDischargeFillType(dischargeNode))
						triggerHandler:setFillableObject(self,dischargeNode.fillUnitIndex,self.spec_dischargeable:getDischargeFillType(dischargeNode))
					end
				end
			end
		end
	end
	return superFunc(self,state)
end
Pipe.onDischargeStateChanged = Utils.overwrittenFunction(Pipe.onDischargeStateChanged,TriggerHandler.onDischargeStateChanged)
