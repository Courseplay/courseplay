CpGuiPageSteering = {}
CpGuiPageSteering.xmlFilename = courseplay.path .. "gui_new/screens/Page_steering.xml"

local CpGuiPageSteering_mt = Class(CpGuiPageSteering)

function CpGuiPageSteering:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageSteering_mt
    end;
	local self = setmetatable({}, CpGuiPageSteering_mt)

	return self
end

function CpGuiPageSteering:onCreate() 

end

function CpGuiPageSteering:onOpen() 
      
end

function CpGuiPageSteering:onClose() 

end