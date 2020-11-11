CpGuiPageSettingsField = {}
CpGuiPageSettingsField.xmlFilename = courseplay.path .. "gui_new/screens/Page_settingsField.xml"


local CpGuiPageSettingsField_mt = Class(CpGuiPageSettingsField)

function CpGuiPageSettingsField:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageSettingsField_mt
    end;
	local self = setmetatable({}, CpGuiPageSettingsField_mt)

	return self
end

function CpGuiPageSettingsField:onCreate() 

end

function CpGuiPageSettingsField:onOpen() 
      
end

function CpGuiPageSettingsField:onClose() 

end