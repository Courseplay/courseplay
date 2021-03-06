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