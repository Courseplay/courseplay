CpGuiPageDriversSpeed = {}
CpGuiPageDriversSpeed.xmlFilename = courseplay.path .. "gui_new/screens/Page_speed.xml"


local CpGuiPageDriversSpeed_mt = Class(CpGuiPageDriversSpeed)

function CpGuiPageDriversSpeed:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageDriversSpeed_mt
    end;
	local self = setmetatable({}, CpGuiPageDriversSpeed_mt)

	return self
end

function CpGuiPageDriversSpeed:onCreate() 

end

function CpGuiPageDriversSpeed:onOpen() 
      
end

function CpGuiPageDriversSpeed:onClose() 

end