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
