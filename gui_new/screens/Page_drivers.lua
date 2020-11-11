CpGuiPageDrivers = {}
CpGuiPageDrivers.xmlFilename = courseplay.path .. "gui_new/screens/Page_drivers.xml"


local CpGuiPageDrivers_mt = Class(CpGuiPageDrivers)

function CpGuiPageDrivers:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageDrivers_mt
    end;
	local self = setmetatable({}, CpGuiPageDrivers_mt)

	return self
end

function CpGuiPageDrivers:onCreate() 

end

function CpGuiPageDrivers:onOpen() 
      
end

function CpGuiPageDrivers:onClose() 

end