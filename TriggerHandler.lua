
TriggerHandler = CpObject()

TriggerHandler.myLoadingStates = {
	IS_LOADING = {},
	IS_LOADING_FUEL = {},
	NOTHING = {},
	IS_UNLOADING = {},
	DRIVE_NOW = {},
	STOPPED = {},
	WAITING_FOR_UNLOAD_READY = {}
}
TriggerHandler.APPROACH_AUGER_TRIGGER_SPEED = 3

function TriggerHandler:init(driver,vehicle,siloSelectedFillTypeSetting)
	self.vehicle = vehicle
	self.driver = driver
	self.siloSelectedFillTypeSetting=siloSelectedFillTypeSetting
	self.allwaysSearchFuel = vehicle.cp.settings.allwaysSearchFuel
	self.validFillTypeLoading = false
	self.validFillTypeUnloading = false
	self.validFillTypeUnloadingAugerWagon = false
	self.validFuelLoading = false
	self.loadingState = StateModule(self,"debug", self.vehicle)
	self.loadingState:initStates(TriggerHandler.myLoadingStates)
	self.loadingState.state = self.loadingState.states.STOPPED
	self.triggers = {}
	self.objectsInTrigger= {}
	self.isInAugerWagonTrigger = false
	self.fillableObject = nil
	self.lastLoadedFillTypes = {}
	self.disabledCombiUnloadingTrigger = nil
	self.debugTicks = 100
	self.debugChannel = 2
	self.lastDistanceToTrigger = nil
	self.lastDebugLoadingCallback = nil
	self.bunkerSilo = nil
end 

function TriggerHandler:isDebugActive()
	return courseplay.debugChannels[2]
end

function TriggerHandler:debugSparse(vehicle,...)
	if g_updateLoopIndex % self.debugTicks == 0 then
		courseplay.debugVehicle(self.debugChannel, vehicle, ...)
	end
end

function TriggerHandler:debug(vehicle,...)
	courseplay.debugVehicle(self.debugChannel, vehicle, ...)
end

function TriggerHandler:onStart()
	self:changeLoadingState("NOTHING")
	self.lastDistanceToTrigger = nil
	self.triggers = {}
	self.objectsInTrigger = {}
end 

function TriggerHandler:onStop()
	self:changeLoadingState("STOPPED")
	self:forceStopLoading()
end 

function TriggerHandler:onUpdate(dt)
	if not self:isDriveNowActivated() and not self:isStopped() then
		self:updateLoadingTriggers()
	end
	if not self:isStopped() then 
		if self.validFillTypeUnloading then 
			self:updateUnloadingTriggers()
		end
	end
	--temp hack to reset driveNow 
	local isNearWaitPoint, waitPointIx = (self.driver.ppc:getCurrentWaypointIx()-5)>1 and self.driver.course:hasWaitPointWithinDistance(self.driver.ppc:getCurrentWaypointIx()-5, 10)
	if not self:isInTrigger() and not isNearWaitPoint then 
		if self:isDriveNowActivated() then 
			self:changeLoadingState("NOTHING")
		end
	end
	if self.validFillTypeUnloadingBunkerSilo then 
		self:updateUnloadingBunkerSilo()
	end
end 

--debug info
function TriggerHandler:onDraw()
	if self:isDebugActive() then 
		local y = 0.5
		y = self:renderText(y,"validFillTypeLoading: "..tostring(self.validFillTypeLoading))
		y = self:renderText(y,"validFillTypeUnloading: "..tostring(self.validFillTypeUnloading))
		y = self:renderText(y,"loadingState: "..tostring(self.loadingState:getName()))
		y = self:renderText(y,"isInTrigger: "..tostring(self:isInTrigger()))
		local yTable = {}
		yTable.y = y
		self:debugDischargeNodes(self.vehicle,yTable)
		y=yTable.y
		if self.lastDebugLoadingCallback then 
			self:debugLoadingCallback(self.lastDebugLoadingCallback)
		end
		if self.fillableObject then 
			self:debugFillableObject(self.fillableObject)
		end
	end
end

function TriggerHandler:debugDischargeNodes(object,yTable)
	local spec = object.spec_dischargeable
	if spec then 
		local node = object:getCurrentDischargeNode()
		if node then
			yTable.y = self:renderText(yTable.y,"object: "..nameNum(object))
			yTable.y = self:renderText(yTable.y,"has dischargeObject: "..tostring(node.dischargeObject and true or false))
		end
	end
	for _,impl in pairs(object:getAttachedImplements()) do
		self:debugDischargeNodes(impl.object,yTable)
	end
end
TriggerHandler.debugLoadingCallbackData = {}
TriggerHandler.debugLoadingCallbackData[0] = "MAX_REACHED"
TriggerHandler.debugLoadingCallbackData[1] = "RUN_COUNTER_NOT_REACHED"
TriggerHandler.debugLoadingCallbackData[2] = "SEPARATE_FILLTYPE_NOT_ALLOWED"
TriggerHandler.debugLoadingCallbackData[3] = "MIN_NOT_REACHED"
TriggerHandler.debugLoadingCallbackData[4] = "OK to load"
TriggerHandler.debugLoadingCallbackData[5] = "SKIP_LOADING"
TriggerHandler.debugLoadingCallbackData[6] = "DONE_LOADING"

function TriggerHandler:debugLoadingCallback(loadingCallback)
	local y = 0.5
	local lastCallbackData = nil
	y = self:renderText(y,"debugLoadingCallback:",0.2)
	y = self:renderText(y,string.format("fillUnitIndex: %s",tostring(loadingCallback[1].fillUnitIndex)),0.2)
	for indexCallback,callbackData in ipairs(loadingCallback) do 
		local data = callbackData.data
		local fillType = data.fillType
		lastCallbackData = callbackData
		local text = string.format("index: %s, fillType: %s, callback: %s",indexCallback,tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title),self.debugLoadingCallbackData[callbackData.callback])
		y = self:renderText(y,text,0.2)
	end
	local text = string.format("lastCallback:  fillType: %s, callback: %s",tostring(g_fillTypeManager:getFillTypeByIndex(lastCallbackData.data.fillType).title),self.debugLoadingCallbackData[lastCallbackData.callback])
	y = self:renderText(y,text,0.2)
end

function TriggerHandler:debugFillableObject(fillableObject)
	local y = 0.5
	local lastCallbackData = nil
	y = self:renderText(y,"debugDillableObject:",0.4)
	y = self:renderText(y,string.format("object: %s",nameNum(fillableObject.object)),0.4)
	y = self:renderText(y,string.format("fillUnitIndex: %s",tostring(fillableObject.fillUnitIndex)),0.4)
	y = self:renderText(y,string.format("fillType: %s",tostring(fillableObject.fillType)),0.4)
	y = self:renderText(y,string.format("trigger: %s",tostring(fillableObject.trigger)),0.4)
	y = self:renderText(y,string.format("isLoading: %s",tostring(fillableObject.isLoading)),0.4)
	y = self:renderText(y,text,0.4)
end

function TriggerHandler:renderText(y,text,xOffset)
	renderText(xOffset and 0.3+xOffset or 0.3,y,0.02,tostring(text))
	return y-0.02
end

function TriggerHandler:onUpdateTick(dt)

end

function TriggerHandler:onContinue()
	self:forceStopLoading()
	if self:isStopped() then 
		self:changeLoadingState("NOTHING")
	elseif self:isLoading() or self:isUnloading() then 
		self:changeLoadingState("NOTHING")
	end
end

function TriggerHandler:writeUpdateStream(streamId)
	self.loadingState:onWriteUpdateStream(streamId)
end

function TriggerHandler:readUpdateStream(streamId)
	self.loadingState:onReadUpdateStream(streamId)
end

function TriggerHandler:onWriteStream(streamId)
	self.loadingState:onWriteStream(streamId)
end

function TriggerHandler:onReadStream(streamId)
	self.loadingState:onReadStream(streamId)
end

function TriggerHandler:onDriveNow()
	self:setDriveNow()
end

function TriggerHandler:changeLoadingState(newState)
	self.loadingState:changeState(newState)
end

function TriggerHandler:updateLoadingTriggers()
	if self.validFillTypeLoading or self:needsFuel() then
		self:activateLoadingTriggerWhenAvailable()
	end
	if self:isLoading() or self:isLoadingFuel() then
		self:disableFillingIfFull()
	end
end 

function TriggerHandler:updateUnloadingTriggers()
	if self:isUnloading() then 
		self:disableUnloadingIfEmpty()
	end
end 

function TriggerHandler:updateUnloadingBunkerSilo()
--	if self.bunkerSilo ~= nil then
--		self.bunkerSilo = BunkerSiloManagerUtil.getTargetBunkerSiloByPointOnCourse(self.driver.course,self.driver.ppc:getCurrentWaypointIx()+3)
--	else 
--		self.bunkerSilo = BunkerSiloManagerUtil.getTargetBunkerSiloByPointOnCourse(self.driver.course,self.driver.ppc:getCurrentWaypointIx()-3)
--	end
	if self:isWaitingForUnloadReady() then 
		self.driver:setInfoText('WAITING_FOR_LEVELCOMPACTAIDRIVER')
		self.driver:setSpeed(0)
	else 
		self.driver:clearInfoText('WAITING_FOR_LEVELCOMPACTAIDRIVER')
	end
end

function TriggerHandler:disableFillingIfFull()
	if self:isFilledUntilPercantageX() then 
		self:forceStopLoading()
		self:resetLoadingState()
	end
end

--saftey check as driver sometimes dosen't restart automaticlly
function TriggerHandler:disableUnloadingIfEmpty()
	if self.fillableObject then		
		local fillUnitIndex = self.fillableObject.fillUnitIndex
		local object = self.fillableObject.object
		if object:getFillUnitFillLevelPercentage(fillUnitIndex)*100 < 0.5 and object.spec_waterTrailer then 
			self:resetUnloadingState()
		end
	end
end

function TriggerHandler:isFilledUntilPercantageX()
	if self.fillableObject then
		local fillUnitIndex = self.fillableObject.fillUnitIndex
		local object = self.fillableObject.object
		local fillType = self.fillableObject.fillType
		local maxFillLevelPercentage = not self:isLoadingFuel() and self.siloSelectedFillTypeSetting:getMaxFillLevelByFillType(self.fillableObject.fillType) or 99
		return not self:maxFillLevelNotReached(object,fillUnitIndex,maxFillLevelPercentage,fillType)
	end
end

function TriggerHandler:getSiloSelectedFillTypeData()
	if self.siloSelectedFillTypeSetting then
		local fillTypeData = self.siloSelectedFillTypeSetting:getData()
		local size = self.siloSelectedFillTypeSetting:getSize()
		return fillTypeData,size
	end
end


function TriggerHandler:getTriggerDischargeNode(trigger)
	return trigger.dischargeInfo and trigger.dischargeInfo.nodes and (trigger.dischargeInfo.nodes.node or trigger.dischargeInfo.nodes[1].node) -- or trigger.triggerNode
end

--used to move the trailer more to the middle, but not really reliable,
--as we can't do a proper full stop or calculate the need distance to stop
function TriggerHandler:isNearDischargeNode(object,fillUnitIndex,trigger)
	if object and fillUnitIndex and trigger then
		local node = object:getFillUnitExactFillRootNode(fillUnitIndex)
		local triggerNode = self:getTriggerDischargeNode(trigger)
		if node and triggerNode then 
			local distance = calcDistanceFrom(triggerNode, node)
			if self.lastDistanceToTrigger and distance > self.lastDistanceToTrigger then 
				self:debugSparse(object,"dischargeNode and TriggerNode distance okay !")
				return true
			else 
				self.driver:setSpeed(math.min(1,distance))
				self:debugSparse(object,"dischargeNode and TriggerNode distance not okay, continue..!")
				self.lastDistanceToTrigger = distance
			end
		elseif node == nil then 
			self:debugSparse(object,"dischargeNodeX not found!")
			return true
		else 
			self:debugSparse(object,"TriggerNodeX not found!")
			return true
		end
	else 
		self:debugSparse(object,"dischargeNode or TriggerNode not found!")
	end
end


----

--Driver set to wait while loading
function TriggerHandler:setLoadingState(object,fillUnitIndex,fillType,trigger)
	if self:isLoadingFuel() then 
		self:setFuelLoadingState(object,fillUnitIndex,fillType,trigger)
		return
	end
	self:setFillableObject(object,fillUnitIndex,fillType,trigger,true)
	--saftey check for drive now
	if not self:isDriveNowActivated() and not self:isLoading() then
		self:changeLoadingState("IS_LOADING")
	end
end

--Driver set to wait while loading
function TriggerHandler:setFuelLoadingState(object,fillUnitIndex,fillType,trigger)
	self:setFillableObject(object,fillUnitIndex,fillType,trigger,true)
	--saftey check for drive now
	if not self:isLoadingFuel() then
		self:changeLoadingState("IS_LOADING_FUEL")
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

function TriggerHandler:setWaitingForUnloadReady()
	if not self:isWaitingForUnloadReady() and self.validFillTypeUnloadingBunkerSilo then
		self:changeLoadingState("WAITING_FOR_UNLOAD_READY")
	end
end

function TriggerHandler:resetWaitingForUnloadReady()
	if self:isWaitingForUnloadReady() then
		self:changeLoadingState("NOTHING")
	end
end

function TriggerHandler:resetFillableObject()
	self.fillableObject=nil
end

function TriggerHandler:isLoading()
	return self.loadingState:is("IS_LOADING") or self:isLoadingFuel()
end

function TriggerHandler:isLoadingFuel()
	return self.loadingState:is("IS_LOADING_FUEL")
end

function TriggerHandler:isUnloading()
	return self.loadingState:is("IS_UNLOADING")
end

function TriggerHandler:isWaitingForUnloadReady()
	return self.loadingState:is("WAITING_FOR_UNLOAD_READY")
end

--Driver stops loading
function TriggerHandler:resetLoadingState()
	if not self:isDriveNowActivated() then
		self:changeLoadingState("NOTHING")
	end
	self.augerTriggerSpeed=nil
	self:resetFillableObject()
end

--Driver set to wait while unloading
function TriggerHandler:setUnloadingState(object,fillUnitIndex,fillType)
	self:setFillableObject(object,fillUnitIndex,fillType)
	if not self:isDriveNowActivated() then
		self:changeLoadingState("IS_UNLOADING")
	end
	self.driver:refreshHUD()
end

--Driver stops unloading 
function TriggerHandler:resetUnloadingState()
	if not self:isDriveNowActivated() then
		self:changeLoadingState("NOTHING")
	end
	self:resetFillableObject()
end

function TriggerHandler:setDriveNow()
	if self:isLoading() or self:isUnloading() then 
		self:forceStopLoading()
		self:changeLoadingState("DRIVE_NOW")
	end
	if self:isUnloading() then 
		courseplay:resetTipTrigger(self.vehicle, true);
	end
end

--AIDriver uses this function to check if we are in trigger or not!
function TriggerHandler:isInTrigger()
	local oldCpTrigger = self.vehicle.cp.currentTipTrigger
	if oldCpTrigger and oldCpTrigger.bunkerSilo ~= nil then
		return false
	end
	local bool = self.validFillTypeLoading and (self.driver:getIsInFilltrigger() or next(self.triggers) ~=nil) or self.validFillTypeUnloading and  self.driver:hasTipTrigger()
--	local bool = next(self.triggers) ~=nil or next(self.objectsInTrigger) ~=nil
	return bool, self.isInAugerWagonTrigger
end

function TriggerHandler:isDriveNowActivated()
	return self.loadingState:is("DRIVE_NOW")
end

function TriggerHandler:isStopped()
	return self.loadingState:is("STOPPED")
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
			if self.fillableObject.isLoading then -- disable filling at fillTriggers
				self:debug(object,"forceStop setFillUnitIsFilling")
				self.fillableObject.object:setFillUnitIsFilling(false)
			elseif self.fillableObject.object.setDischargeState then -- disable unloading
				self.fillableObject.object:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
			end
		end
	end
end

function TriggerHandler:needsFuel()
	local currentFuelPercentage = self.driver:getFuelLevelPercentage()
	local searchForFuel = self.allwaysSearchFuel:is(true) and currentFuelPercentage <99 or currentFuelPercentage < 20
	if searchForFuel then 
		return true
	end
end

--scanning for LoadingTriggers and FillTriggers(checkFillTriggers)
function TriggerHandler:activateLoadingTriggerWhenAvailable()
	for key, object in pairs(g_currentMission.activatableObjects) do		
		if self:objectInTrigger(object,self.vehicle) and object:getIsActivatable(self.vehicle) then
			if object:isa(LoadTrigger) and (object ~= NetworkUtil.getObject(self.lastUnloadingTriggerID) or self:isNearFillPoint()) then 
				self:activateTriggerForVehicle(object, self.vehicle)
				return
			end
        end
    end
    return
end

function TriggerHandler:objectInTrigger(trigger,object)
	if not trigger.courseplayersInTrigger then 
		return
	end
	if trigger.courseplayersInTrigger[object] then 
		return true
	end
	
	for _,impl in pairs(object:getAttachedImplements()) do
		if self:objectInTrigger(trigger,impl.object) then 
			return true
		end
	end
end

function TriggerHandler:enableFillTypeLoading()
	self.validFillTypeLoading = true
end 

function TriggerHandler:enableFillTypeUnloading()
	self.validFillTypeUnloading = true
end

function TriggerHandler:enableFillTypeUnloadingBunkerSilo()
	self.validFillTypeUnloadingBunkerSilo = true
end

function TriggerHandler:enableFillTypeUnloadingAugerWagon()
	self.validFillTypeUnloadingAugerWagon = true
end

function TriggerHandler:enableFuelLoading()
	self.validFuelLoading = true
end

function TriggerHandler:disableFillTypeLoading()
	self.validFillTypeLoading = false
	if self.siloSelectedFillTypeSetting:isRunCounterActive() then 
		self.siloSelectedFillTypeSetting:decrementRunCounterByFillType(self.lastLoadedFillTypes)
		self.driver:refreshHUD()
	end	
	self.lastLoadedFillTypes = {}
end 

function TriggerHandler:disableFillTypeUnloading()
	self.validFillTypeUnloading = false
	self.validFillTypeUnloadingAugerWagon = false
	self.validFillTypeUnloadingBunkerSilo = false
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

function TriggerHandler:isAllowedToUnloadAtBunkerSilo()
	return self.validFillTypeUnloadingBunkerSilo 
end

--Loading Trigger callback check 
--1: maxFillLevel reached 
--2: runCounter valid or can be ignored
--3: load seperarteFillType activated or ignored
--4: minFillLevel reached or allowed to drive if trigger empty
TriggerHandler.CALLBACK = {}
TriggerHandler.CALLBACK.MAX_REACHED = 0
TriggerHandler.CALLBACK.RUN_COUNTER_NOT_REACHED = 1
TriggerHandler.CALLBACK.SEPARATE_FILLTYPE_NOT_ALLOWED = 2
TriggerHandler.CALLBACK.MIN_NOT_REACHED = 3
TriggerHandler.CALLBACK.OK = 4
TriggerHandler.CALLBACK.SKIP_LOADING = 5
--TriggerHandler.CALLBACK.TRIGGER_FILLEVEL_EMPTY = 5
TriggerHandler.CALLBACK.DONE_LOADING = 6
function TriggerHandler:triggerCanStartLoading(trigger,object,fillUnitIndex,triggerFillLevel,data, dataLength)
	--is fillLevel < maxFillLevel
	local callback = nil
	local fillType = data.fillType
	if self:maxFillLevelNotReached(object,fillUnitIndex,data.maxFillLevel,fillType) then 
		--if runCounter activated and runCounter > 0
		if self:isRunCounterValid(data.runCounter,data.fillType) then 	
			-- is separateFillTypeLoading not activated or separateFillType not loaded yet
			if self:isAllowedToLoadSeparateFillType(object,dataLength,fillType) or object:getFillUnitFillLevel(fillUnitIndex) > 1 then
				local separateFillTypeLoading = self.driver:getSeparateFillTypeLoadingSetting()
				if separateFillTypeLoading and not separateFillTypeLoading:hasDiffFillTypes() then
					if self.lastLoadedFillTypes[1] and fillType~= self.lastLoadedFillTypes[1] then 
						callback = self.CALLBACK.SKIP_LOADING
						return callback
					end
				end
				-- is minFillLevelPercentage in trigger or infinity fillLevel trigger or autoStart at trigger
				if triggerFillLevel and triggerFillLevel> 0 or trigger.hasInfiniteCapacity or triggerFillLevel == nil then -- or trigger.autoStart then 
					if data.minFillLevel == 0 or self:isMinFillLevelReachedToLoad(object,fillUnitIndex,triggerFillLevel,data.minFillLevel,fillType)  then
						callback = self.CALLBACK.OK
						if trigger.hasInfiniteCapacity then
							self:debugSparse(object,"trigger hasInfiniteCapacity")
						end			
					else --minFillLevel not reached!!
						callback = self.CALLBACK.SKIP_LOADING
						self:debugSparse(object,"skip loading trigger<min, %s",tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title))
					end
				else --triggerFillLevel is empty!!
					local fillLevelPercentage = object:getFillUnitFillLevelPercentage(fillUnitIndex)*100
					if fillLevelPercentage >= data.minFillLevel and fillLevelPercentage>0 then 
						if fillType == object:getFillUnitFillType(fillUnitIndex) then
							callback = self.CALLBACK.DONE_LOADING
							self:debugSparse(object,"skip loading triggerEmpty min reached, %s",tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title))
						else 
							callback = self.CALLBACK.SKIP_LOADING
						end
					elseif fillLevelPercentage>0 then
						callback = self.CALLBACK.MIN_NOT_REACHED
						self:debugSparse(object,"skip loading triggerEmpty waiting for more, %s",tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title))
					else 
						callback = self.CALLBACK.SKIP_LOADING
						self:debugSparse(object,"skip loading triggerEmpty, skip to next fillType, %s",tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title))
					end
				end
			else
				callback = self.CALLBACK.SEPARATE_FILLTYPE_NOT_ALLOWED
			end
		else
			callback = self.CALLBACK.RUN_COUNTER_NOT_REACHED
			self:debugSparse(object,"skip loading, runcounter = 0, %s",tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title))
		end
	else
		callback = self.CALLBACK.MAX_REACHED
	end
	return callback
end

--check max Level
function TriggerHandler:maxFillLevelNotReached(object,fillUnitIndex,maxFillLevelPercentage,fillType)  
	local objectFillLevelPercentage = object:getFillUnitFillLevelPercentage(fillUnitIndex)*100	
	self:debugSparse(object,"maxFillLevel:, fillPercentage: %s > maxFillLevel: %s, fillType: %s",tostring(objectFillLevelPercentage),tostring(maxFillLevelPercentage),tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title))
	return objectFillLevelPercentage < (maxFillLevelPercentage or 99)
end

--check min Level and Trigger Level
function TriggerHandler:isMinFillLevelReachedToLoad(object,fillUnitIndex,triggerFillLevel,minFillLevelPercentage,fillType)
	local objectFillCapacity = object:getFillUnitCapacity(fillUnitIndex)
	local objectFillLevel = object:getFillUnitFillLevel(fillUnitIndex)
	local minNeededFillLevel = minFillLevelPercentage and minFillLevelPercentage*0.01*objectFillCapacity - objectFillLevel or 0.1
	self:debugSparse(object,"min FillLevel:, triggerFillLevel: %s, objectFillCapacity: %s, minNeededFillLevel: %s, fillType: %s",tostring(triggerFillLevel),tostring(objectFillCapacity),tostring(minNeededFillLevel),tostring(g_fillTypeManager:getFillTypeByIndex(fillType).title))
	return triggerFillLevel and triggerFillLevel > minNeededFillLevel 
end

--check runcounter
function TriggerHandler:isRunCounterValid(runCounter,fillType) 
	return runCounter and runCounter>0 or runCounter == nil
end

--check separateFillTypes
function TriggerHandler:isAllowedToLoadSeparateFillType(object,dataLength,fillTypeIndex)
	local separateFillTypeLoading = self.driver:getSeparateFillTypeLoadingSetting()
	if separateFillTypeLoading and separateFillTypeLoading:hasDiffFillTypes() and dataLength > 1 then
		for _,fillType in pairs(self.lastLoadedFillTypes) do 
			if fillType == fillTypeIndex and #self.lastLoadedFillTypes < separateFillTypeLoading:get() then
				self:debugSparse(object,"fillType: "..fillTypeIndex.." already loaded")
				return false
			end
		end
	end
	self:debugSparse(object,"isAllowedToLoadSeparateFillType true")
	return true
end

--TODO: probably broken
function TriggerHandler:disableUnloadingTriggerUnderFillTrigger(object)
	local spec = object.spec_dischargeable
	if spec and spec.currentDischargeNode and spec.currentDischargeNode.dischargeObject then 
		if self.disabledCombiUnloadingTrigger == nil then 
			self.disabledCombiUnloadingTrigger  = spec.currentDischargeNode.dischargeObject
		end
		self:debugSparse("Unloading Trigger of LoadingTrigger disabled no!")
	end
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
	trigger:onActivateObject(vehicle)
	--Restore previous values
	g_currentMission.getFarmId = defaultGetFarmIdFunction;
	g_currentMission.controlledVehicle = oldControlledVehicle;
end

-- LoadTrigger doesn't allow filling non controlled tools
function TriggerHandler:getIsActivatable(superFunc,objectToFill)
	--when the trigger is filling, it uses this function without objectToFill
	if objectToFill then
		local oldVehicle = {}
		local oldVehicle = g_currentMission.controlledVehicle
		local vehicle = objectToFill:getRootVehicle()
		g_currentMission.controlledVehicle = vehicle or objectToFill
		local bool = superFunc(self,objectToFill)
		g_currentMission.controlledVehicle = oldVehicle
		return bool
	else 
		return superFunc(self,objectToFill)
	end
end
LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,TriggerHandler.getIsActivatable)


--LoadTrigger activate, if fillType is right and fillLevel ok 
function TriggerHandler:onActivateObject(superFunc,vehicle)
	--self = LoadTrigger!
	if courseplay:isAIDriverActive(vehicle) then 
		local triggerHandler = vehicle.cp.driver.triggerHandler
		if not triggerHandler:isAllowedToLoadFuel() and not triggerHandler:isAllowedToLoadFillType() then 
			return superFunc(self)
		end
		
		if not self.isLoading then
			local isG_companyTrigger = false
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
			local node = fillableObject:getFillUnitExactFillRootNode(fillUnitIndex)
	--		DebugUtil.drawDebugNode(node, "ExactFillRootNode", false)
			--checks if we are in the fillPlane, bugged with mode 4 as driver dosen't stop fast enough..
			if not triggerHandler:isNearDischargeNode(fillableObject,fillUnitIndex,self) then 
				triggerHandler:resetLoadingState()
				return 
			elseif not triggerHandler:isDriveNowActivated() then
				vehicle:brake(1)
			end
			if fillableObject.spec_cover and fillableObject.spec_cover.isDirty then 
				triggerHandler:setLoadingState()
				triggerHandler:debugSparse(fillableObject, 'Cover is still opening!')
				return
			end			
			local fillTypeData,fillTypeDataSize = triggerHandler:getSiloSelectedFillTypeData()
			local loadingCallback = {}
			local indexCallback = 1
			if triggerHandler:isAllowedToLoadFillType() then
				for _,data in ipairs(fillTypeData) do
					for fillTypeIndex, fillLevel in pairs(fillLevels) do
						if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) and fillTypeIndex == data.fillType and data.fillType ~= nil then
							local callback = triggerHandler:triggerCanStartLoading(self,fillableObject,fillUnitIndex,fillLevel,data,fillTypeDataSize)
							loadingCallback[indexCallback] = {}
							loadingCallback[indexCallback].callback = callback
							loadingCallback[indexCallback].data = data
							loadingCallback[indexCallback].fillLevelTrigger = fillLevel
							loadingCallback[indexCallback].fillUnitIndex = fillUnitIndex
							indexCallback = indexCallback +1
						end
					end
				end
			end
			--seperarte for only loading Fuel in to motors!
			if triggerHandler:isAllowedToLoadFuel() and fillableObject == vehicle then 
				for fillTypeIndex, fillLevel in pairs(fillLevels) do
					if vehicle.cp.driver:isValidFuelType(fillableObject,fillTypeIndex) then 
						if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) then
							if triggerHandler:maxFillLevelNotReached(fillableObject,fillUnitIndex,99,fillTypeIndex) then 
								if fillLevel>0 then 
									triggerHandler:setFuelLoadingState()
									self:onFillTypeSelection(fillTypeIndex)
									g_currentMission.activatableObjects[self] = nil
									return
								else
									triggerHandler:setFuelLoadingState()
									CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY')
									courseplay.debugFormat(2, 'No Diesel at this trigger.')
								end
							else
								courseplay.debugFormat(2, 'max FillLevel Reached')
								triggerHandler:resetLoadingState()
							end
						end
					end
				end
			end
			if loadingCallback and #loadingCallback > 0 then
				triggerHandler:handleLoadingCallback(self,fillableObject,fillUnitIndex,loadingCallback)
			end
		end
	else 
		return superFunc(self)
	end
end
LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,TriggerHandler.onActivateObject)

function TriggerHandler:handleLoadingCallback(trigger,object,fillUnitIndex,loadingCallback)
	local lastCallbackData = nil
	self.lastDebugLoadingCallback = loadingCallback
	for indexCallback,callbackData in ipairs(loadingCallback) do 
		local data = callbackData.data
		local fillType = data.fillType
		lastCallbackData = callbackData
		--all okay start loading
		if callbackData.callback == TriggerHandler.CALLBACK.OK then 
			table.insert(self.lastLoadedFillTypes, fillType)
			if trigger and trigger.onFillTypeSelection then 
				trigger:onFillTypeSelection(fillType)
				g_currentMission.activatableObjects[trigger] = nil
			else 
				object:setFillUnitIsFilling(true,nil,callbackData.currentTrigger)
				self:setLoadingState(object,callbackData.fillUnitIndex,fillType)
			end
			self:debugSparse(object, 'LoadingTrigger: start Loading, fillType: '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
			return 
		--max FillLevel reached
		elseif callbackData.callback == TriggerHandler.CALLBACK.MAX_REACHED then 
			if trigger and trigger.onFillTypeSelection then 
				g_currentMission.activatableObjects[trigger] = nil
			end
			self:resetLoadingState()
			self:debugSparse(object, 'LoadingTrigger: max Reached, fillType: '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
			return 
		-- min FillLevel not reached to start filling
		elseif callbackData.callback == TriggerHandler.CALLBACK.MIN_NOT_REACHED then
			self:setLoadingState()
			CpManager:setGlobalInfoText(self.vehicle, 'FARM_SILO_IS_EMPTY');
			self:debugSparse(object, 'LoadingTrigger: minLevel not reached, fillType: '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
			return 
		--min is reached so continue..
		elseif callbackData.callback == TriggerHandler.CALLBACK.DONE_LOADING then
			lastCallbackData = nil
			if trigger and trigger.onFillTypeSelection then 
				g_currentMission.activatableObjects[trigger] = nil
			end
			self:resetLoadingState()		
			self:debugSparse(object, 'LoadingTrigger: continue!! : '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
			return
		end
	end
	--runCounter = 0
	if lastCallbackData and lastCallbackData.callback ==  TriggerHandler.CALLBACK.RUN_COUNTER_NOT_REACHED then 
		self:setLoadingState()
		CpManager:setGlobalInfoText(self.vehicle, 'RUNCOUNTER_ERROR_FOR_TRIGGER');
		self:debugSparse(object, 'last runCounter=0, fillType: '..g_fillTypeManager:getFillTypeByIndex(lastCallbackData.data.fillType).title)
		return
	end
	if lastCallbackData and (lastCallbackData.callback == TriggerHandler.CALLBACK.SKIP_LOADING or lastCallbackData.callback == TriggerHandler.CALLBACK.SEPARATE_FILLTYPE_NOT_ALLOWED) then
		--not enough fillTypes loaded!!
		self:setLoadingState()
		CpManager:setGlobalInfoText(self.vehicle, 'FARM_SILO_IS_EMPTY');
		self:debugSparse(object, 'last FillType  minLevel not reached, fillType: '..g_fillTypeManager:getFillTypeByIndex(lastCallbackData.data.fillType).title)
		return
	end
end


--LoadTrigger => start/stop driver and close cover once free from trigger
function TriggerHandler:setIsLoading(superFunc,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
	if self.validFillableObject then 
		local rootVehicle = self.validFillableObject:getRootVehicle()
		if courseplay:isAIDriverActive(rootVehicle) then
			local triggerHandler = rootVehicle.cp.driver.triggerHandler
			if not triggerHandler.validFillTypeLoading and not triggerHandler.validFuelLoading then
				return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
			end
			if isLoading then 
				triggerHandler:setLoadingState(self.validFillableObject,fillUnitIndex, fillType,self)
				triggerHandler:debug(self.validFillableObject, 'LoadTrigger setLoading, FillType: '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
			else 
				triggerHandler:disableUnloadingTriggerUnderFillTrigger(self.validFillableObject)
				triggerHandler:resetLoadingState()
				triggerHandler:debug(self.validFillableObject, 'LoadTrigger resetLoading and close Cover')
				SpecializationUtil.raiseEvent(self.validFillableObject, "onRemovedFillUnitTrigger",#self.validFillableObject.spec_fillUnit.fillTrigger.triggers)
				g_currentMission:addActivatableObject(self)
			end
		end
	end
	return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
end
LoadTrigger.setIsLoading = Utils.overwrittenFunction(LoadTrigger.setIsLoading,TriggerHandler.setIsLoading)

--close cover after tipping for trailer if not closed already
function TriggerHandler:endTipping(superFunc,noEventSend)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then
		rootVehicle.cp.driver.triggerHandler:debug(self,"finished unloading, endTipping !! ")
		if rootVehicle.cp.settings.automaticCoverHandling:is(true) and self.spec_cover then
			self:setCoverState(0, true)
		end
		rootVehicle.cp.driver.triggerHandler:resetUnloadingState()
	end
	return superFunc(self,noEventSend)
end
Trailer.endTipping = Utils.overwrittenFunction(Trailer.endTipping,TriggerHandler.endTipping)

--pass trigger from updateFillUnitTriggers to spec
function TriggerHandler:setFillUnitIsFilling(superFunc,isFilling, noEventSend,trigger)
	local spec = self.spec_fillUnit
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then 
		if isFilling ~= spec.fillTrigger.isFilling then
			if noEventSend == nil or noEventSend == false then
				if g_server ~= nil then
					g_server:broadcastEvent(SetFillUnitIsFillingEvent:new(self, isFilling), nil, nil, self)
				else
					g_client:getServerConnection():sendEvent(SetFillUnitIsFillingEvent:new(self, isFilling))
				end
			end
			spec.fillTrigger.isFilling = isFilling
			if trigger then
				spec.fillTrigger.currentTrigger = trigger
			end
			if self.isClient then
				self:setFillSoundIsPlaying(isFilling)
				if spec.fillTrigger.currentTrigger ~= nil then
					spec.fillTrigger.currentTrigger:setFillSoundIsPlaying(isFilling)
				end
			end
			if not trigger then 
				spec.fillTrigger.currentTrigger = nil
			end
			SpecializationUtil.raiseEvent(self, "onFillUnitIsFillingStateChanged", isFilling)
		end
	else
		return superFunc(self,isFilling, noEventSend)
	end
end
FillUnit.setFillUnitIsFilling = Utils.overwrittenFunction(FillUnit.setFillUnitIsFilling,TriggerHandler.setFillUnitIsFilling)

--LoadTrigger callback used to open correct cover for loading 
function TriggerHandler:loadTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local rootVehicle
	local fillableObject = g_currentMission:getNodeObject(otherId)
	if fillableObject and fillableObject:isa(Vehicle) then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	
	if not self.courseplayersInTrigger then 
		self.courseplayersInTrigger = {}
	end
	if rootVehicle then 
		if onLeave then 
			if self.courseplayersInTrigger[rootVehicle] then
				self.courseplayersInTrigger[rootVehicle][fillableObject] = nil
				if next(self.courseplayersInTrigger[rootVehicle]) == nil then
					self.courseplayersInTrigger[rootVehicle] = nil
				end
			end
		else 
			if self.courseplayersInTrigger[rootVehicle] == nil then
				self.courseplayersInTrigger[rootVehicle]= {}
			end
			self.courseplayersInTrigger[rootVehicle][fillableObject] = true
		end
	end		
	--legancy code!!! (not sure if still needed??) 
	courseplay:SiloTrigger_TriggerCallback(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	
	if courseplay:isAIDriverActive(rootVehicle) then
		TriggerHandler.handleLoadTriggerCallback(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId,rootVehicle,fillableObject)
	end
end
LoadTrigger.loadTriggerCallback = Utils.appendedFunction(LoadTrigger.loadTriggerCallback,TriggerHandler.loadTriggerCallback)

function TriggerHandler.handleLoadTriggerCallback(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId,rootVehicle,fillableObject)
	local triggerHandler = rootVehicle.cp.driver.triggerHandler
	if not onLeave and triggerHandler.triggers[self] == nil then 
		triggerHandler.triggers[self] = true
	elseif onLeave and (self.courseplayersInTrigger[rootVehicle] == nil or next(self.courseplayersInTrigger[rootVehicle]) == nil) then 
		triggerHandler.triggers[self] = nil
	end
	if onEnter then 
		courseplay.debugVehicle(2,fillableObject, 'LoadTrigger onEnter')
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
							triggerHandler:debugSparse(fillableObject,"LoadTrigger: open Cover for loading")
						end
					end
				end
			end
		end
	end
	if onLeave then 
		spec = fillableObject.spec_fillUnit
		if spec then
			SpecializationUtil.raiseEvent(fillableObject, "onRemovedFillUnitTrigger",#spec.fillTrigger.triggers)
		end
		courseplay.debugVehicle(2,fillableObject, 'LoadTrigger: onLeave, disableTriggerSpeed')
	else
		courseplay.debugVehicle(2,fillableObject, 'LoadTrigger: enableTriggerSpeed')
	end
	courseplay.debugVehicle(2,fillableObject, "validFillableObject: "..tostring(self.validFillableObject))
end

--FillTrigger callback used to set approach speed for Cp driver
function TriggerHandler:fillTriggerCallback(superFunc, triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)

	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject and fillableObject:isa(Vehicle) then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if not self.courseplayersInTrigger then 
		self.courseplayersInTrigger = {}
	end
	if onEnter and rootVehicle then
		if self.courseplayersInTrigger[rootVehicle] == nil then
			self.courseplayersInTrigger[rootVehicle]= {}
		end
		self.courseplayersInTrigger[rootVehicle][fillableObject] = true
	elseif onLeave and rootVehicle then 
		if self.courseplayersInTrigger[rootVehicle] then
			self.courseplayersInTrigger[rootVehicle][fillableObject] = nil
			if next(self.courseplayersInTrigger[rootVehicle]) == nil then
				self.courseplayersInTrigger[rootVehicle] = nil
			end
		end
	end
	if courseplay:isAIDriverActive(rootVehicle) then
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		if not triggerHandler.validFillTypeLoading then
			return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
		end
		if not onLeave and triggerHandler.triggers[self] == nil then 
			triggerHandler.triggers[self] = true
		elseif onLeave and (self.courseplayersInTrigger[rootVehicle] == nil or next(self.courseplayersInTrigger[rootVehicle]) == nil)  then 
			triggerHandler.triggers[self] = nil
		end
		if onEnter then
			courseplay.debugVehicle(2,fillableObject, 'fillTrigger onEnter')
		end
		if onLeave then
			courseplay.debugVehicle(2,fillableObject, 'fillTrigger onLeave')
		end
	end
	return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
end
FillTrigger.fillTriggerCallback = Utils.overwrittenFunction(FillTrigger.fillTriggerCallback, TriggerHandler.fillTriggerCallback)

--check if the vehicle is controlled by courseplay
function courseplay:isAIDriverActive(rootVehicle) 
	if rootVehicle and rootVehicle.cp and rootVehicle.cp.driver and rootVehicle:getIsCourseplayDriving() and rootVehicle.cp.driver:isActive() then
		if rootVehicle.spec_autodrive and rootVehicle.spec_autodrive.stateModule and rootVehicle.spec_autodrive.stateModule:isActive() then 
			return
		end
		return true
	end
end

--Augerwagons handling
--Pipe callback used for augerwagons to open the cover on the fillableObject
function TriggerHandler:unloadingTriggerCallback(superFunc,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if not self.objectsInTrigger then 
		self.objectsInTrigger = {}
	end
	if onEnter then
		self.objectsInTrigger[otherId] = true
	elseif onLeave then 
		self.objectsInTrigger[otherId] = nil
	end	
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) and not rootVehicle.cp.driver.triggerHandler.validFillTypeUnloadingAugerWagon then 
		return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	end
	local object = g_currentMission:getNodeObject(otherId)
	if object ~= nil and object ~= self and object:isa(Vehicle) then
		local objectRootVehicle = object:getRootVehicle()
		if not courseplay:isAIDriverActive(objectRootVehicle) then 
			return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
		end
		local objectTriggerHandler = objectRootVehicle.cp.driver.triggerHandler
		if not objectTriggerHandler.validFillTypeLoading then
			return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
		end
		if not onLeave and objectTriggerHandler.triggers[self] == nil then 
			objectTriggerHandler.triggers[self] = true
		elseif onLeave and next(self.objectsInTrigger) == nil then 
			objectTriggerHandler.triggers[self] = nil
		end
		if object.getFillUnitIndexFromNode ~= nil and not onLeave then
			local fillUnitIndex = object:getFillUnitIndexFromNode(otherId)
            if fillUnitIndex ~= nil then
				local dischargeNode = self:getDischargeNodeByIndex(self:getPipeDischargeNodeIndex())
                if dischargeNode ~= nil then
					local fillType = self:getFillUnitFillType(dischargeNode.fillUnitIndex)
					local validFillUnitIndex = object:getFirstValidFillUnitToFill(fillType)
                    if fillType and validFillUnitIndex then 
						courseplay.debugVehicle(2,object,"unloadingTriggerCallback open Cover for "..g_fillTypeManager:getFillTypeByIndex(fillType).title)
						SpecializationUtil.raiseEvent(object, "onAddedFillUnitTrigger",fillType,validFillUnitIndex,1)
						objectTriggerHandler.isInAugerWagonTrigger = true
					end
				end
			end
		elseif onLeave then
			SpecializationUtil.raiseEvent(object, "onRemovedFillUnitTrigger",0)
			courseplay.debugVehicle(2,object,"unloadingTriggerCallback close Cover")
			objectTriggerHandler:resetLoadingState()
			objectTriggerHandler.isInAugerWagonTrigger = false
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

--quite funky as setDischargeState dosen't get called every time it stops to discharge
function TriggerHandler:setDischargeState(superFunc,state, noEventSend)
	local rootVehicle = self:getRootVehicle()
	local spec = self.spec_dischargeable
	if courseplay:isAIDriverActive(rootVehicle) then
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		if state ~= spec.currentDischargeState then 
			if state == Dischargeable.DISCHARGE_STATE_OFF then
				if not self.spec_trailer  then
					triggerHandler:resetUnloadingState()
				end
			end			
		end
	end
	return superFunc(self,state,noEventSend)
end
Dischargeable.setDischargeState = Utils.overwrittenFunction(Dischargeable.setDischargeState,TriggerHandler.setDischargeState)

--check all the different fillUnits for example Wilson trailers
function TriggerHandler:updateRaycast(superFunc,currentDischargeNode)
	local rootVehicle = self:getRootVehicle()
	local spec = self.spec_dischargeable
	if courseplay:isAIDriverActive(rootVehicle) and spec and spec.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
		if #spec.fillUnitDischargeNodeMapping>1 then
			for fillUnitIndex,dischargeNode in pairs(spec.fillUnitDischargeNodeMapping) do 
				superFunc(self,dischargeNode)
				if self:getCanDischargeToObject(dischargeNode) then 
					for dischargeNodeIndex,curDischargeNode in pairs(spec.dischargeNodes) do 
						if curDischargeNode == dischargeNode then 
							local trailerSpec = self.spec_trailer
							if trailerSpec and self:getCanTogglePreferdTipSide() then
								for tipSideIndex,tipside in pairs(trailerSpec.tipSides) do 
									if tipside.dischargeNodeIndex == dischargeNodeIndex then 
										self:setPreferedTipSide(tipSideIndex)
										return
									end
								end											
							end
						end
					end
				end
			end
		else 
			superFunc(self,currentDischargeNode)
		end
	else 
		return superFunc(self,currentDischargeNode)
	end
end
Dischargeable.updateRaycast = Utils.overwrittenFunction(Dischargeable.updateRaycast, TriggerHandler.updateRaycast)

--check if we can unload and then wait and also set triggerSpeed for unloadingTriggers for now until raycast is fixed
function TriggerHandler:onUpdateDischargeable(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local rootVehicle = self:getRootVehicle()
	local spec = self.spec_dischargeable
	if courseplay:isAIDriverActive(rootVehicle) and spec and spec.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		local currentDischargeNode = spec.currentDischargeNode
		if triggerHandler:isStopped() or not triggerHandler.validFillTypeUnloading or not currentDischargeNode then 
			return
		end
		if spec:getCanDischargeToObject(currentDischargeNode) and not triggerHandler:isDriveNowActivated() then 
			triggerHandler:setUnloadingState(self,currentDischargeNode.fillUnitIndex,spec:getDischargeFillType(currentDischargeNode))
			triggerHandler:debugSparse(self,"getCanDischargeToObject")
			spec:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)				
		end
		if currentDischargeNode.dischargeFailedReason and currentDischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_NO_FREE_CAPACITY then 
			CpManager:setGlobalInfoText(rootVehicle, 'FARM_SILO_IS_FULL') -- not working for now, might have to double check
		end
		if currentDischargeNode.dischargeObject then
			if triggerHandler.objectsInTrigger[self] == nil then
				triggerHandler.objectsInTrigger[self] = true
			end
		else
			triggerHandler.objectsInTrigger[self] = nil
		end
		if spec.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF and rootVehicle.cp.driver:hasTipTrigger() then 
			courseplay:setInfoText(rootVehicle,"COURSEPLAY_TIPTRIGGER_REACHED")
			triggerHandler:debugSparse(self,"COURSEPLAY_TIPTRIGGER_REACHED")
		end
	end
end
Dischargeable.onUpdate = Utils.appendedFunction(Dischargeable.onUpdate, TriggerHandler.onUpdateDischargeable)

--check if we have any fillTrigger nearby and handle them
function TriggerHandler:onUpdateTickFillUnit(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local rootVehicle = self:getRootVehicle()
	local spec = self.spec_fillUnit
	if courseplay:isAIDriverActive(rootVehicle) and not spec.fillTrigger.isFilling then
		local triggerHandler = rootVehicle.cp.driver.triggerHandler
		if #spec.fillTrigger.triggers == 0 then 
			return
		end
		if triggerHandler:isAllowedToLoadFuel() then 
			for _, trigger in ipairs(spec.fillTrigger.triggers) do
				if trigger:getIsActivatable(self) then
					local fillType = trigger:getCurrentFillType()
					local fillUnitIndex = self:getFirstValidFillUnitToFill(fillType)
					if rootVehicle.cp.driver:isValidFuelType(self,fillType) then 
						self:setFillUnitIsFilling(true,nil,trigger)
						triggerHandler:setFuelLoadingState(self,fillUnitIndex,fillType)
						return
					end
				end
			end
		end
		if not triggerHandler.validFillTypeLoading then
			return
		end
		if self.spec_cover and self.spec_cover.isDirty then 
			triggerHandler:setLoadingState()
			return
		end
		local fillTypeData,fillTypeDataSize = triggerHandler:getSiloSelectedFillTypeData()
		local loadingCallback = {}
		local indexCallback = 1
		for _,data in ipairs(fillTypeData) do
			for _, trigger in ipairs(spec.fillTrigger.triggers) do
				if trigger:getIsActivatable(self) then
					local fillType = trigger:getCurrentFillType()
					local fillUnitIndex = self:getFirstValidFillUnitToFill(fillType)
					if fillType == data.fillType and fillUnitIndex then 
						local callback = triggerHandler:triggerCanStartLoading(trigger,self,fillUnitIndex,10000,data,fillTypeDataSize)
						loadingCallback[indexCallback] = {}
						loadingCallback[indexCallback].callback = callback
						loadingCallback[indexCallback].data = data
						loadingCallback[indexCallback].fillUnitIndex = fillUnitIndex
						loadingCallback[indexCallback].currentTrigger = trigger
						indexCallback = indexCallback +1				
					end
				end
			end
		end
		triggerHandler:handleLoadingCallback(nil,self,fillUnitIndex,loadingCallback)
	end
end
FillUnit.onUpdateTick = Utils.appendedFunction(FillUnit.onUpdateTick, TriggerHandler.onUpdateTickFillUnit)

--Global company....

function TriggerHandler:onActivateObjectGlobalCompany(superFunc,vehicle)
	local rootVehicle = vehicle
	if self.validFillableObject and (not vehicle or not vehicle:isa(Vehicle)) then 
		rootVehicle = self.validFillableObject:getRootVehicle()
	end
	TriggerHandler.onActivateObject(self,superFunc,rootVehicle)
end

function TriggerHandler:onLoad_GC_LoadingTriggerFix(superFunc,nodeId, source, xmlFile, xmlKey, forcedFillTypes, infiniteCapacity, blockUICapacity, baseDirectory)
	local isOk = superFunc(self,nodeId, source, xmlFile, xmlKey, forcedFillTypes, infiniteCapacity, blockUICapacity, baseDirectory)
	if self.dischargeInfo == nil or self.dischargeInfo.nodes == nil or self.dischargeInfo.nodes[1] == nil or self.dischargeInfo.nodes[1].node == nil then
		local dischargeNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".dischargeInfo#dischargeNode"), source.i3dMappings)
		if dischargeNode ~= nil then
			self.dischargeInfo = {}
			self.dischargeInfo.name = "fillVolumeDischargeInfo"
			local width = g_company.xmlUtils.getXMLValue(getXMLFloat, xmlFile, xmlKey .. ".dischargeInfo#width", 0.5)
			local length = g_company.xmlUtils.getXMLValue(getXMLFloat, xmlFile, xmlKey .. ".dischargeInfo#length", 0.5)
			self.dischargeInfo.nodes = {}
			table.insert(self.dischargeInfo.nodes, {node=dischargeNode, width=width, length=length, priority=1})
		end
	end
	return isOk
end
