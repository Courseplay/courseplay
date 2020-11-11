CpGuiPageSettingsFilling = {}
CpGuiPageSettingsFilling.xmlFilename = courseplay.path .. "gui_new/screens/Page_settingsFilling.xml"

local CpGuiPageSettingsFilling_mt = Class(CpGuiPageSettingsFilling)

function CpGuiPageSettingsFilling:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageSettingsFilling_mt
    end;
	local self = setmetatable({}, CpGuiPageSettingsFilling_mt)

	return self
end

function CpGuiPageSettingsFilling:onCreate() 

end

function CpGuiPageSettingsFilling:onOpen() 
      
end

function CpGuiPageSettingsFilling:onClose() 

end