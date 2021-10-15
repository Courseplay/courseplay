---@class RunCounterSetting : IntSetting
RunCounterSetting = CpObject(IntSetting)
RunCounterSetting.MAX_RUNS = 20
RunCounterSetting.RUN_COUNTER_DEACTIVATED = -1
---@param name string
---@param label string
---@param toolTip string
---@param value number
---@param alwaysDisabled boolean
function RunCounterSetting:init(name,label,toolTip,vehicle,value,alwaysDisabled)
	IntSetting.init(self,name,label,toolTip,vehicle,-1,self.MAX_RUNS,value or self.RUN_COUNTER_DEACTIVATED)
	self.alwaysDisabled = alwaysDisabled
end

--- Run counter is disabled, so it can be ignored.
function RunCounterSetting:isDisabled()
	return self.value == self.RUN_COUNTER_DEACTIVATED or self:isAlwaysDisabled()
end

--- The run counter for the current mode is disabled.
function RunCounterSetting:isAlwaysDisabled()
	return self.alwaysDisabled
end

function RunCounterSetting:decrement()
	self.value = math.max(0,self.value-1)
end

function RunCounterSetting:increment()
	self.value = math.min(self.MAX_RUNS,self.value+1)
end

function RunCounterSetting:getText()
	return self:isDisabled() and "--------" or string.format("%d/%d",self:get(),self.MAX_RUNS)
end

--- Run counter is not disabled and also greater the 0.
function RunCounterSetting:isValid()
	return self:isDisabled() or self.value > 0
end

--- An item of a silo selected fill type list.
---@class FillTypeListItemSetting : Setting
FillTypeListItemSetting = CpObject(Setting)
FillTypeListItemSetting.MAX_RUNS = 20
FillTypeListItemSetting.RUN_COUNTER_DEACTIVATED = 21
---@param name string
---@param vehicle table
---@param fillType number
---@param counterAlwaysDisabled boolean
function FillTypeListItemSetting:init(name,vehicle,fillType,counterAlwaysDisabled)
	Setting.init(self,name or "",nil,nil,vehicle)
	self.fillType = IntSetting("fillType",nil,nil,vehicle,0,nil,fillType or 0)
	self.minFillLevel = PercentageSettingList("minFillLevel",nil,nil,vehicle,0,0)
	self.maxFillLevel = PercentageSettingList("MaxFillLevel",nil,nil,vehicle,100)
	self.runCounter = RunCounterSetting("runCounter",nil,nil,vehicle,-1,counterAlwaysDisabled)
end

function FillTypeListItemSetting:loadFromXml(xml,parentKey)
	self.fillType:loadFromXml(xml,parentKey)
	self.minFillLevel:loadFromXml(xml,parentKey)
	self.maxFillLevel:loadFromXml(xml,parentKey)
	self.runCounter:loadFromXml(xml,parentKey)
end

function FillTypeListItemSetting:saveToXml(xml,parentKey)
	self.fillType:saveToXml(xml,parentKey)
	self.minFillLevel:saveToXml(xml,parentKey)
	self.maxFillLevel:saveToXml(xml,parentKey)
	self.runCounter:saveToXml(xml,parentKey)
end

function FillTypeListItemSetting:onReadStream(streamId)
	self.fillType:onReadStream(streamId)
	self.minFillLevel:onReadStream(streamId)
	self.maxFillLevel:onReadStream(streamId)
	self.runCounter:onReadStream(streamId)
end

function FillTypeListItemSetting:onWriteStream(streamId)
	self.fillType:onWriteStream(streamId)
	self.minFillLevel:onWriteStream(streamId)
	self.maxFillLevel:onWriteStream(streamId)
	self.runCounter:onWriteStream(streamId)
end

--- Fill type list used to handle loading with the trigger handler.
--- Implemented as linked list.
---@class FillTypeListSetting : LinkedList
FillTypeListSetting = CpObject(LinkedListSetting)
---@param vehicle table
---@param name string
---@param disallowedFillTypes table
---@param maxFillTypes number
---@param runCounterAlwaysDisabled boolean
function FillTypeListSetting:init(vehicle,name,disallowedFillTypes,maxFillTypes,runCounterAlwaysDisabled)
	LinkedListSetting.init(self,name,'COURSEPLAY_ADD_FILLTYPE', 'COURSEPLAY_ADD_FILLTYPE',vehicle)
	self.disallowedFillTypes = disallowedFillTypes
	self.maxFillTypes = maxFillTypes
	self.xmlAttribute = "#size"
	self.xmlKey = name
	self.cleanUpAllowed = false
	self.runCounterAlwaysDisabled = runCounterAlwaysDisabled
	self:registerEvents()
end

--- Makes sure the first clean up only accurse,
--- after all implements are attached on load.
function FillTypeListSetting:postInit()
	self.cleanUpAllowed = true
end

function FillTypeListSetting:getFillTypeTitle(ix)
	return g_fillTypeManager:getFillTypeByIndex(ix).title
end

function FillTypeListSetting:loadFromXml(xml, parentKey)
	local size = Utils.getNoNil(getXMLInt(xml, self:getKey(parentKey)),0)
	if size and size>0 then
		for key=1,size do 
			local data = FillTypeListItemSetting("",self.vehicle,0,self.runCounterAlwaysDisabled)
			local elementKey = string.format("%s.element(%d)",parentKey..".elements", key-1)
			data:loadFromXml(xml,elementKey)
			data.name = self:getFillTypeTitle(data.fillType:get())
			self:addLast(data)
			
		end
	end
end

function FillTypeListSetting:saveToXml(xml, parentKey)
	local size = self:getSize()
	setXMLInt(xml, self:getKey(parentKey), Utils.getNoNil(size,0))
	if size > 0 then 
		for key,data in ipairs(self:getData()) do
			local elementKey = string.format("%s.element(%d)", parentKey..".elements", key-1)
			data:saveToXml(xml,elementKey)
		end
	end
end

function FillTypeListSetting:onWriteStream(stream)
	local size = self:getSize() or 0
	self:debugWriteStream(size,"size")
	streamWriteInt32(stream, size)
	if size > 0 then 
		for key,data in ipairs(self:getData()) do		
			data:onWriteStream(stream)
		end
	end
end

function FillTypeListSetting:onReadStream(stream)
	local size = streamReadInt32(stream)
	self:debugReadStream(size,"size")
	if size and size>0 then
		for key=1,size do 
			local data = FillTypeListItemSetting("",self.vehicle,0,self.runCounterAlwaysDisabled)
			data:onReadStream(stream)
			data.name = self:getFillTypeTitle(data.fillType:get())
			self:addLast(data)
		end
	end
end

--- Gets the maximum allowed fill types in the list.
function FillTypeListSetting:getMaxFillTypes()
	return self.maxFillTypes
end

function FillTypeListSetting:isFull()
	if self:getSize() >= self.maxFillTypes then 
		return true
	end
end

--- Adds a new fill type with a popup window from giants.
--- Makes sure only supported fill types by the vehicle combo are allowed
--- and explicit disabled fill types, like FillType.AIR are ignored. 
function FillTypeListSetting:addFilltype()
	if self:isFull() then 
		return
	end
	local supportedFillTypes = {}
	self:getSupportedFillTypes(self.vehicle,supportedFillTypes)
	self:checkSelectedFillTypes(supportedFillTypes)
	if supportedFillTypes then
		g_gui:showSiloDialog({title="Fill type Selection", fillLevels=supportedFillTypes, capacity=100, callback=self.onFillTypeSelection, target=self, hasInfiniteCapacity = true})
	end
end

--- Callback from the popup window to add the selected fill type to the list.
function FillTypeListSetting:onFillTypeSelection(selectedFillType,noEventSend)
	if selectedFillType and selectedFillType ~= FillType.UNKNOWN then 
		local name = self:getFillTypeTitle(selectedFillType)
		local data = FillTypeListItemSetting(name,self.vehicle,selectedFillType,self.runCounterAlwaysDisabled)
		self:addLast(data)
		if not noEventSend then
			self:raiseEvent(self.NEW_ELEMENT_EVENT)
		end
	end
end  

--- Gets all supported fill types, but ignores all consumer fill types,
--- as they get handled separately.
function FillTypeListSetting:getSupportedFillTypes(object,supportedFillTypes)  
	if object and object.spec_fillUnit and object.getFillUnits then
		if supportedFillTypes ~= nil then 
			for fillUnitIndex, fillUnit in pairs(object:getFillUnits()) do
				for fillType,bool in pairs(object:getFillUnitSupportedFillTypes(fillUnitIndex)) do 
					local found = false
					local specMotor = object.spec_motorized
					--disable motor consumer fillTypes as they get loaded seperatly 
					if specMotor then 
						local consumer = specMotor.consumersByFillType[fillType] 
						if consumer then 
							if consumer.fillUnitIndex == fillUnitIndex then 
								found = true
							end							
						end
					end
					--disabled FillTypes(AIR, sometimes DEF or DIESEL)
					if self.disallowedFillTypes then		
						for _,_fillType in pairs(self.disallowedFillTypes) do 
							if fillType == _fillType then
								found = true
							end
						end
					end	
					--all okay and fillType is new add it to spported
					if bool and not found then 
						if supportedFillTypes[fillType] == nil then
							supportedFillTypes[fillType]=100
						end
					end
				end		
			end
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getSupportedFillTypes(impl.object,supportedFillTypes)
	end
end

--- Deletes fill types that are no longer supported by the vehicle combo.
function FillTypeListSetting:cleanUpOldFillTypes(noEventSend)
	local supportedFillTypes = {}
	self:getSupportedFillTypes(self.vehicle,supportedFillTypes)
	self:checkSelectedFillTypes(supportedFillTypes,true, noEventSend)
	if not noEventSend then
		self:raiseEvent(self.CLEAN_EVENT)
	end
end

--- Makes sure on attach/detach of an implement the invalid fill types are removed.
function FillTypeListSetting:validateCurrentValue()
	if self.cleanUpAllowed then
		self:cleanUpOldFillTypes(true)
	end
end

--- Deletes fill types that are no longer supported by the vehicle combo.
function FillTypeListSetting:checkSelectedFillTypes(supportedFillTypes, cleanUp, noEventSend)	
	local totalData = self:getData()
	for index,data in ipairs(totalData) do 
		local fillType = data.fillType:get()
		if supportedFillTypes[fillType] then --already selected fillTypes disable multi select
			supportedFillTypes[fillType]=0
		elseif cleanUp then	--delete not supported fillTypes 
			self:deleteByIndex(index, noEventSend)
			return self:checkSelectedFillTypes(supportedFillTypes, cleanUp, noEventSend)
		end
	end
end 

--- Check if at least one fill type is selected
--- and at least one run counter is valid or disabled.
function FillTypeListSetting:isActive()  
	if self:getSize() == 0 then 
		return false
	end
	
	local data = self:getData()
	local runCounterCheck = false
	for _,data in ipairs(data) do 
		if data.runCounter:isValid() then 
			runCounterCheck=true
		end
	end
	return runCounterCheck
end

--- Gets the hud texts for run counter, min fill level, max fill level of an item.
function FillTypeListSetting:getTexts(index)
	local data = self:getDataByIndex(index)
	
	if data then
		local runCounterText =  data.runCounter:getText()
		local maxFillLevelText = data.maxFillLevel:getText()
		local minFillLevelText = data.minFillLevel:getText()
		return runCounterText,maxFillLevelText,minFillLevelText
	else
		return "","",""
	end
end

--- Gets the fill type title of an item.
function FillTypeListSetting:getText(index)
	local data = self:getDataByIndex(index)
	if data then 
		return self:getFillTypeTitle(data.fillType:get())
	end
	return ""
end

--- Decreases the run counter of the last filled fill types by one.
function FillTypeListSetting:decrementRunCounterByFillType(lastFillTypes)
	local totalData = self:getData()
	for index,data in ipairs(totalData) do 
		for fillType,_ in pairs(lastFillTypes) do
			if data.fillType:get() == fillType then
				if not data.runCounter:isDisabled() then
					local v = data.runCounter:get()
					data.runCounter:decrement()
					if v ~= data.runCounter:get() then 
						self:raiseEvent(self.CHANGE_RUN_COUNTER_EVENT,index*-1)
					end
				end
			end
		end
	end
end

--- Gets the max fill level for a fill type.
function FillTypeListSetting:getMaxFillLevelByFillType(fillType)
	local totalData = self:getData()
	for index,data in ipairs(totalData) do 
		if data.fillType:get() == fillType then
			return data.maxFillLevel:get()		
		end
	end
end

function FillTypeListSetting:moveUpByIndex(index,noEventSend)
	LinkedListSetting.moveUpByIndex(self,index)
	if not noEventSend then
		self:raiseEvent(self.MOVE_UP_EVENT,index)
	end
end

function FillTypeListSetting:moveDownByIndex(index,noEventSend)
	LinkedListSetting.moveDownByIndex(self,index)
	if not noEventSend then
		self:raiseEvent(self.MOVE_DOWN_EVENT,index)
	end
end

function FillTypeListSetting:deleteByIndex(index, noEventSend)
	LinkedListSetting.deleteByIndex(self,index)
	if not noEventSend then
		self:raiseEvent(self.DELETE_ELEMENT_EVENT,index)
	end
end

--- Registers all events.
function FillTypeListSetting:registerEvents()
	self.NEW_ELEMENT_EVENT = self:registerIntEvent(self.onFillTypeSelection)
	self.DELETE_ELEMENT_EVENT = self:registerIntEvent(self.deleteByIndex)
	self.MOVE_UP_EVENT = self:registerIntEvent(self.moveUpByIndex)
	self.MOVE_DOWN_EVENT = self:registerIntEvent(self.moveDownByIndex)
	self.CLEAN_EVENT = self:registerFunctionEvent(self.cleanUpOldFillTypes)

	self.CHANGE_MIN_FILL_LEVEL_EVENT = self:registerFunctionEvent(self.changeMinFillLevel)
	self.CHANGE_MAX_FILL_LEVEL_EVENT = self:registerFunctionEvent(self.changeMaxFillLevel)
	self.CHANGE_RUN_COUNTER_EVENT = self:registerFunctionEvent(self.changeRunCounter)
end

function FillTypeListSetting:changeMinFillLevel(index,noEventSend)
	local data = self:getDataByIndex(math.abs(index))
	local x = index/math.abs(index)
	data.minFillLevel:changeByX(x)
	if noEventSend == nil or false then
		self:raiseEvent(self.CHANGE_MIN_FILL_LEVEL_EVENT,index)
	end
end

function FillTypeListSetting:changeMaxFillLevel(index,noEventSend)
	local data = self:getDataByIndex(math.abs(index))
	local x = index/math.abs(index)
	data.maxFillLevel:changeByX(x)
	if noEventSend == nil or false then
		self:raiseEvent(self.CHANGE_MAX_FILL_LEVEL_EVENT,index)
	end
end

function FillTypeListSetting:changeRunCounter(index,noEventSend)
	local data = self:getDataByIndex(math.abs(index))
	if not data.runCounter:isAlwaysDisabled() then
		local x = index/math.abs(index)
		data.runCounter:changeByX(x)
		if noEventSend == nil or false then
			self:raiseEvent(self.CHANGE_RUN_COUNTER_EVENT,index)
		end
	end
end


---@class FillTypeListsSettingsContainer : SettingsContainer
FillTypeListsSettingsContainer = CpObject(SettingsContainer)
--- All the custom functions for the different modi are implemented here.
FillTypeListsSettingsContainer.SETTINGS = {
	["grainTransportAIDriver"] = {
		{FillType.AIR}, --- disallowed fill types
		5 --- max fill types
	},
	["fillableFieldWorkAIDriver"] = {
		{FillType.DIESEL, FillType.DEF,FillType.AIR}, --- disallowed fill types
		2, --- max fill types
		true --- run counter always active
	},
	["fieldSupplyAIDriver"] = {
		{FillType.DEF,FillType.AIR}, --- disallowed fill types
		2, --- max fill types
		true --- run counter always active
	},
	["shovelModeAIDriver"] = {
		{FillType.DIESEL, FillType.DEF,FillType.AIR}, --- disallowed fill types
		1, --- max fill types
	},
	["mixerWagonAIDriver"] = {
		{FillType.DIESEL, FillType.DEF,FillType.AIR}, --- disallowed fill types
		7, --- max fill types
	},
}

function FillTypeListsSettingsContainer:init()
	SettingsContainer.init(self, 'fillTypeList')
end

function FillTypeListsSettingsContainer:postInit()
	for _, setting in pairs(self) do
		if self:validateSetting(setting) then 
			setting:postInit()
		end
	end
end

function FillTypeListsSettingsContainer:saveToXML(xml, parentKey)
	SettingsContainer.saveToXML(self, xml, parentKey .. '.' .. self.name)
end

function FillTypeListsSettingsContainer:loadFromXML(xml, parentKey)
	SettingsContainer.loadFromXML(self, xml, parentKey .. '.' .. self.name)
end

function FillTypeListsSettingsContainer.create(vehicle)
	local container = FillTypeListsSettingsContainer()
	for name,data in pairs(FillTypeListsSettingsContainer.SETTINGS) do 
		container:addSetting(FillTypeListSetting,vehicle,name,unpack(data))
	end
	return container
end