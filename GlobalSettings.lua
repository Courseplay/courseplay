-- all the Global Settings

--- Load courses at startup?
---@class LoadCoursesAtStartupSetting : BooleanSetting
LoadCoursesAtStartupSetting = CpObject(BooleanSetting)
function LoadCoursesAtStartupSetting:init()
	BooleanSetting.init(self, 'loadCoursesAtStartup', 'COURSEPLAY_LOAD_COURSES_AT_STARTUP',
		'COURSEPLAY_LOAD_COURSES_AT_STARTUP_TOOLTIP', nil)
end

---@class AutoFieldScanSetting : BooleanSetting
AutoFieldScanSetting = CpObject(BooleanSetting)
function AutoFieldScanSetting:init()
	BooleanSetting.init(self, 'autoFieldScan', 'COURSEPLAY_AUTO_FIELD_SCAN',
		'COURSEPLAY_YES_NO_FIELDSCAN', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---@class ClickToSwitchSetting : BooleanSetting
ClickToSwitchSetting = CpObject(BooleanSetting)
function ClickToSwitchSetting:init()
	BooleanSetting.init(self, 'clickToSwitch', 'COURSEPLAY_CLICK_TO_SWITCH',
				'COURSEPLAY_YES_NO_CLICK_TO_SWITCH', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---@class WorkerWagesSetting : SettingList
WorkerWagesSetting = CpObject(SettingList)
function WorkerWagesSetting:init()
	SettingList.init(self, 'workerWages', 'COURSEPLAY_WORKER_WAGES', 'COURSEPLAY_WORKER_WAGES_TOOLTIP', nil,
			{0,  50, 100, 250, 500, 1000},
			{'0%', '50%', '100%', '250%', '500%', '1000%'}
		)
	self:set(0)
end

---@class EnableOpenHudWithMouseGlobalSetting : BooleanSetting
EnableOpenHudWithMouseGlobalSetting = CpObject(BooleanSetting)
function EnableOpenHudWithMouseGlobalSetting:init()
	BooleanSetting.init(self, 'enableOpenHudWithMouseGlobal', 'COURSEPLAY_ENABLE_OPEN_HUD_WITH_MOUSE_GLOBAL',
				'COURSEPLAY_YES_NO_ENABLE_OPEN_HUD_WITH_MOUSE_GLOBAL', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---@class EnableOpenHudWithMouseVehicleSetting : BooleanSetting
EnableOpenHudWithMouseVehicleSetting = CpObject(BooleanSetting)
function EnableOpenHudWithMouseVehicleSetting:init()
	BooleanSetting.init(self, 'enableOpenHudWithMouseVehicle', 'COURSEPLAY_ENABLE_OPEN_HUD_WITH_MOUSE_VEHICLE',
				'COURSEPLAY_YES_NO_ENABLE_OPEN_HUD_WITH_MOUSE_VEHICLE', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---@class ShowMiniHudSetting  : BooleanSetting
ShowMiniHudSetting  = CpObject(BooleanSetting)
function ShowMiniHudSetting:init()
	BooleanSetting.init(self, 'showMiniHud', 'COURSEPLAY_SHOW_MINI_HUD',
				'COURSEPLAY_YES_NO_SHOW_MINI_HUD', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(false)
end

---@class ShowActionEventTextsSetting  : BooleanSetting
ShowActionEventTextsSetting  = CpObject(BooleanSetting)
function ShowActionEventTextsSetting:init()
	BooleanSetting.init(self, 'showActionEventsTexts', 'COURSEPLAY_SHOW_ACTION_EVENTS_TEXTS',
				'COURSEPLAY_SHOW_ACTION_EVENTS_TEXTS_TOOLTIP', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---On setting change, make sure the current entered vehicle gets updated.
function ShowActionEventTextsSetting:onChange()
	if g_currentMission then
		local vehicle = g_currentMission.controlledVehicle
		if vehicle ~= nil then 
			ActionEventsLoader.updateAllActionEvents(vehicle)
		end
	end
end


---@class AutoRepairSetting : SettingList
AutoRepairSetting = CpObject(SettingList)
AutoRepairSetting.OFF = 0
function AutoRepairSetting:init()
	SettingList.init(self, 'autoRepair', 'COURSEPLAY_AUTOREPAIR', 'COURSEPLAY_AUTOREPAIR_TOOLTIP', nil,
			{AutoRepairSetting.OFF,  25, 70, 99},
			{'COURSEPLAY_AUTOREPAIR_OFF', '< 25%', '< 70%', 'COURSEPLAY_AUTOREPAIR_ALWAYS'}
		)
	self:set(0)
end

function AutoRepairSetting:isAutoRepairActive()
	return self:get() ~= AutoRepairSetting.OFF
end

function AutoRepairSetting:onUpdateTick(dt, isActive, isActiveForInput, isSelected)
	local rootVehicle = self:getRootVehicle()
	local isOwned = rootVehicle.propertyState ~= Vehicle.PROPERTY_STATE_MISSION
	if courseplay:isAIDriverActive(rootVehicle) and isOwned then 
		if courseplay.globalSettings.autoRepair:isAutoRepairActive() then 
			local repairStatus = (1 - self:getWearTotalAmount())*100
			if repairStatus < courseplay.globalSettings.autoRepair:get() then 
				self:repairVehicle()
			end		
		end
	end
end
Wearable.onUpdateTick = Utils.appendedFunction(Wearable.onUpdateTick, AutoRepairSetting.onUpdateTick)


---@class ShowMapHotspotSetting : SettingList
ShowMapHotspotSetting = CpObject(SettingList)
ShowMapHotspotSetting.DEACTIVATED = 0
ShowMapHotspotSetting.NAME_ONLY = 1
ShowMapHotspotSetting.NAME_AND_COURSE = 2

function ShowMapHotspotSetting:init()
	SettingList.init(self, 'showMapHotspot', 'COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT', 'COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT', nil,
		{ 
			ShowMapHotspotSetting.DEACTIVATED,
			ShowMapHotspotSetting.NAME_ONLY,
			ShowMapHotspotSetting.NAME_AND_COURSE
		},
		{ 	
			'COURSEPLAY_DEACTIVATED',
			'COURSEPLAY_NAME_ONLY',
			'COURSEPLAY_NAME_AND_COURSE'
		}
		)
	self:set(ShowMapHotspotSetting.NAME_ONLY)
end

---If the setting changes force update all mapHotSpot texts
function ShowMapHotspotSetting:onChange()
	self:updateHotSpotTexts()
end

function ShowMapHotspotSetting:updateHotSpotTexts()
	if CpManager.activeCoursePlayers then
		for _,vehicle in pairs(CpManager.activeCoursePlayers) do
			if vehicle.spec_aiVehicle.mapAIHotspot then
				vehicle.spec_aiVehicle.mapAIHotspot:setText(self:getMapHotspotText(vehicle))
			end
		end
	end
end

function ShowMapHotspotSetting:getMapHotspotText(vehicle)
	local text = ''
	if self:is(ShowMapHotspotSetting.NAME_ONLY) then 
		text = string.format("%s%s\n",text,nameNum(vehicle, true))
	elseif self:is(ShowMapHotspotSetting.NAME_AND_COURSE) then
		text = string.format("%s%s\n%s",text,nameNum(vehicle, true),vehicle.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE'))
	end
	return text
end


--- This Setting handles all debug channels. 
--- For each debug channel is a code short cut created, 
--- for example: DebugChannelsSetting.DBG_MODE_3.
--- This is defined in the debug config xml file.
--- For backwards compatibility are all 
--- courseplay.debugChannels[ix] or courseplay["DBG_MODE_3"] calls still valid.
---@class DebugChannelsSetting : Setting 
DebugChannelsSetting = CpObject(Setting)
function DebugChannelsSetting:init()
	Setting.init(self,"debugChannels")
	self.xmlFilePath = Utils.getFilename('config/DebugChannels.xml', courseplay.path)
	self:load(self.xmlFilePath)
	self.DEFAULT_EVENT = self:registerIntEvent(self.setFromNetwork)
end

function DebugChannelsSetting:load(xmlFilePath)
	local xmlFile = loadXMLFile('debugChannels', xmlFilePath)
	local baseKey = "DebugChannels"
	self.channels = {}
	self.numChannels = 0
	self.toolTips = {}
	if xmlFile and hasXMLProperty(xmlFile, baseKey) then 
		print("Loading debug channel setup!")
		local i = 0
		while true do
			local key = string.format("%s.%s(%d)",baseKey,"DebugChannel",i)
			if not hasXMLProperty(xmlFile, key) then
				break
			end
			local text = getXMLString(xmlFile, key.."#text")
			local name = getXMLString(xmlFile, key.."#name")
			local active = getXMLBool(xmlFile, key.."#active")
			i = i + 1
			self[name] = i
			courseplay[name] = i --- Old code 
			self.toolTips[i] = text

			--- Evaluate pre debug setups from the DevSetup xml file.
			--- Also make sure active ~= nil.
			active = Utils.getNoNil(active or 
									CpManager.preDebugSetup.nameToChannel[name] or 
									CpManager.preDebugSetup.idToChannel[i]
									,false)

			self.channels[i] = active
			if active then 
				print(string.format("Debug channel id: %s, name: %s is activated.",tostring(i),tostring(name)))
			end
		end
		self.numChannels = i
		delete(xmlFile)
	else 
		print("Couldn't load debug channel setup!")
	end
	courseplay.debugChannels = self.channels --- Old code 
end

function DebugChannelsSetting:onWriteStream(streamID)
	streamWriteUInt8(streamID,self.numChannels)
	for ix,value in ipairs(self.channels) do 
		streamWriteBool(streamID,value)
	end
end

function DebugChannelsSetting:onReadStream(streamID)
	self.numChannels = streamReadUInt8(streamID)
	for i= 1, self.numChannels do 
		self.channels[i] = streamReadBool(streamID)
	end
end

function DebugChannelsSetting:toggleChannel(ix,noEventSend)
	self:set(ix,not self.channels[ix],noEventSend)
end

function DebugChannelsSetting:set(ix,value,noEventSend)
	self.channels[ix] = value
	if noEventSend == nil or noEventSend == false then 
		self:sendEvent(ix)
	end
	self:onChange()
end

function DebugChannelsSetting:get() 
	return self.channels
end

function DebugChannelsSetting:getNumberOfChannels()
	return self.numChannels
end
	
function DebugChannelsSetting:getToolTips()
	return self.toolTips
end

function DebugChannelsSetting:sendEvent(ix)
	self:raiseEvent(self.DEFAULT_EVENT,ix)
end

function DebugChannelsSetting:setFromNetwork(ix)
	self:toggleChannel(ix,true)
end

function DebugChannelsSetting:isActive(ix)
	return self.channels[ix]
end

function SettingsContainer.createGlobalSettings()
	local container = SettingsContainer("globalSettings")
	container:addSetting(DebugChannelsSetting)
	container:addSetting(LoadCoursesAtStartupSetting)
	container:addSetting(AutoFieldScanSetting)
	container:addSetting(WorkerWagesSetting)
	container:addSetting(ClickToSwitchSetting)
	container:addSetting(ShowMiniHudSetting)
	container:addSetting(EnableOpenHudWithMouseGlobalSetting)
	container:addSetting(AutoRepairSetting)
	container:addSetting(ShowMapHotspotSetting)
	container:addSetting(ShowActionEventTextsSetting)
	return container
end
