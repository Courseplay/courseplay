CpGuiPageSettingsVehicle = {}
CpGuiPageSettingsVehicle.xmlFilename = courseplay.path .. "gui_new/screens/Page_settingsVehicle.xml"


local CpGuiPageSettingsVehicle_mt = Class(CpGuiPageSettingsVehicle)

function CpGuiPageSettingsVehicle:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageSettingsVehicle_mt
    end;
	local self = setmetatable({}, CpGuiPageSettingsVehicle_mt)

	return self
end

function CpGuiPageSettingsVehicle:onCreate() 

end

function CpGuiPageSettingsVehicle:onOpen() 
      
end

function CpGuiPageSettingsVehicle:onClose() 

end