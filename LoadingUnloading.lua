--Loading/Unloading handling with direct giants function 
--and not with local CP Triggers/ no more cp.worktool using!!

--for now only support for FieldSupplyAIDriver and FillableFieldworkAIDriver!

--used to check if fillTrigger is allowed and start/stop driver

--scanning for LoadingTriggers and FillTriggers(checkFillTriggers)
function courseplay:isTriggerAvailable(vehicle)
    for key, object in pairs(g_currentMission.activatableObjects) do
		if object:getIsActivatable(vehicle) then
			local callback = {}		
			if object:isa(LoadTrigger) then 
				courseplay:activateTriggerForVehicle(object, vehicle,callback)
				if callback.ok then 
					g_currentMission.activatableObjects[key] = nil
				end
				return
			end
        end
    end
	courseplay:checkFillTriggers(vehicle)
    return
end

--check recusively if fillTriggers are enableable 
function courseplay:checkFillTriggers(object)
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
		self:checkFillTriggers(impl.object)
	end
end

--check for standart object unloading Triggers
function courseplay:isUnloadingTriggerAvailable(object)    
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
		courseplay:isUnloadingTriggerAvailable(impl.object)
	end
end

--loading/unloading text for mode 8
function courseplay:dischargeToObject(superFunc,dischargeNode, emptyLiters, object, targetFillUnitIndex)
	local dischargedLiters = superFunc(self,dischargeNode, emptyLiters, object, targetFillUnitIndex)
	local rootVehicle = self:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) and dischargedLiters~=0 then
		if not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then 
			return dischargedLiters
		end
		local fillType = self:getDischargeFillType(dischargeNode)
		if object and object:isa(Vehicle) then
			local objectRootVehicle = object:getRootVehicle()
			if courseplay:checkAIDriver(objectRootVehicle) then
			--	courseplay.debugFormat(2,"Mode 4 Driver found, dischargedLiters: "..dischargedLiters)
				local fillLevel = object:getFillUnitFillLevel(targetFillUnitIndex)
				local fillCapacity = object:getFillUnitCapacity(targetFillUnitIndex)
				objectRootVehicle.cp.driver:setLoadingText(fillType,fillLevel,fillCapacity)
			end
		end
		local fillLevel = self:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
		local fillCapacity = self:getFillUnitCapacity(dischargeNode.fillUnitIndex)
		rootVehicle.cp.driver:setUnloadingText(fillType,fillLevel,fillCapacity)
	end
	return dischargedLiters
end
Dischargeable.dischargeToObject = Utils.overwrittenFunction(Dischargeable.dischargeToObject,courseplay.dischargeToObject)

--LoadTrigger callback used to open correct cover for loading 
function courseplay:loadTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	--legancy code!!!
	courseplay:SiloTrigger_TriggerCallback(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:checkAIDriver(rootVehicle) then
		continue =true
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) then
			continue = false
		end
		if continue then 
			rootVehicle.cp.driver:countTriggerUp(otherId)
			rootVehicle.cp.driver:setInTriggerRange()
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
				rootVehicle.cp.driver:countTriggerDown(otherId)
				spec = fillableObject.spec_fillUnit
				if spec then
					SpecializationUtil.raiseEvent(fillableObject, "onRemovedFillUnitTrigger",#spec.fillTrigger.triggers)
				end
				courseplay.debugFormat(2,"LoadTrigger onLeave")
			end
		end
	end
end
LoadTrigger.loadTriggerCallback = Utils.appendedFunction(LoadTrigger.loadTriggerCallback,courseplay.loadTriggerCallback)

-- Custom version of trigger:onActivateObject to allow activating for a non-controlled vehicle
function courseplay:activateTriggerForVehicle(trigger, vehicle,callback)
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
function courseplay:getIsActivatable(superFunc,objectToFill)
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
LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,courseplay.getIsActivatable)

--LoadTrigger activate, if fillType is right and fillLevel ok 
function courseplay:onActivateObject(superFunc,vehicle,callback)
	if courseplay:checkAIDriver(vehicle) then 
		if not vehicle.cp.driver:is_a(FillableFieldworkAIDriver) then 
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
									--fixes giants bug for Lemken Solitär with has fillunit that keeps on filling to infinity
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
LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,courseplay.onActivateObject)

--LoadTrigger => start/stop driver and close cover once free from trigger
function courseplay:setIsLoading(superFunc,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
	local rootVehicle = self.validFillableObject:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) then
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) then
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
LoadTrigger.setIsLoading = Utils.overwrittenFunction(LoadTrigger.setIsLoading,courseplay.setIsLoading)

--FillTrigger callback used to set approach speed for Cp driver
function courseplay:fillTriggerCallback(superFunc, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:checkAIDriver(rootVehicle) then
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) then
			return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
		end		
		if onEnter then
			courseplay.debugFormat(2, 'fillTrigger onEnter')
		end
		if onLeave then
			rootVehicle.cp.driver:countTriggerDown(otherActorId)
			courseplay.debugFormat(2, 'fillTrigger onLeave')
		else
			rootVehicle.cp.driver:countTriggerUp(otherActorId)
			rootVehicle.cp.driver:setInTriggerRange()
		end
	end
	return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end
FillTrigger.fillTriggerCallback = Utils.overwrittenFunction(FillTrigger.fillTriggerCallback, courseplay.fillTriggerCallback)

function courseplay:setFillUnitIsFilling(superFunc,isFilling, noEventSend)
	local rootVehicle = self:getRootVehicle()
	if rootVehicle and courseplay:checkAIDriver(rootVehicle) then 
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) then 
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
FillUnit.setFillUnitIsFilling = Utils.overwrittenFunction(FillUnit.setFillUnitIsFilling,courseplay.setFillUnitIsFilling)

--close cover after tipping if not closed already
function courseplay:endTipping(superFunc,noEventSend)
	local rootVehicle = self:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) then
		if rootVehicle.cp.settings.automaticCoverHandling:is(true) and self.spec_cover then
			self:setCoverState(0, true)
		end
		rootVehicle.cp.driver:resetUnloadingState()
	end
	return superFunc(self,noEventSend)
end
Trailer.endTipping = Utils.overwrittenFunction(Trailer.endTipping,courseplay.endTipping)

--check if the vehicle is controlled by courseplay
function courseplay:checkAIDriver(rootVehicle) 
	if rootVehicle and rootVehicle.cp and rootVehicle.cp.driver and rootVehicle:getIsCourseplayDriving() and rootVehicle.cp.driver:isActive() then
		return true
	end
end

--Pipe callback used for augerwagons to open the cover on the fillableObject
function courseplay:unloadingTriggerCallback(superFunc,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local rootVehicle = self:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) then 
		if not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then
			return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
		end
		local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil and object ~= self and object:isa(Vehicle) then
            local objectRootVehicle = object:getRootVehicle()
			if not courseplay:checkAIDriver(objectRootVehicle)then 
				return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
			end
			objectRootVehicle.cp.driver:setInTriggerRange()
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
							objectRootVehicle.cp.driver:setInTriggerRange(true)
						end
					end
				end
			elseif onLeave then
				SpecializationUtil.raiseEvent(object, "onRemovedFillUnitTrigger",0)
				courseplay.debugFormat(2,"unloadingTriggerCallback close Cover")
				objectRootVehicle.cp.driver:resetLoadingState()
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
Pipe.unloadingTriggerCallback = Utils.overwrittenFunction(Pipe.unloadingTriggerCallback,courseplay.unloadingTriggerCallback)

function courseplay:onDischargeStateChanged(superFunc,state)
	local rootVehicle = self:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) then
		if not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then 
			return superFunc(self,state,noEventSend)
		end
		local dischargeNode = self:getCurrentDischargeNode()
		if dischargeNode and dischargeNode.dischargeObject then 
			if dischargeNode.dischargeObject:isa(Vehicle) then 
				local objectRootVehicle = dischargeNode.dischargeObject:getRootVehicle()
				if courseplay:checkAIDriver(objectRootVehicle) then
					if state == Dischargeable.DISCHARGE_STATE_OFF then
						objectRootVehicle.cp.driver:resetLoadingState()
					else
						objectRootVehicle.cp.driver:setLoadingState(dischargeNode.dischargeObject,dischargeNode.dischargeFillUnitIndex,self:getDischargeFillType(dischargeNode))
					end
				end
			end
		end
	end
	return superFunc(self,state,noEventSend)
end
Pipe.onDischargeStateChanged = Utils.overwrittenFunction(Pipe.onDischargeStateChanged,courseplay.onDischargeStateChanged)




