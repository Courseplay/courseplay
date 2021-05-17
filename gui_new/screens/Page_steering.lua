CpGuiPageSteering = {}
CpGuiPageSteering.xmlFilename = courseplay.path .. "gui_new/screens/Page_steering.xml"

local CpGuiPageSteering_mt = Class(CpGuiPageSteering)

function CpGuiPageSteering:new(parentGui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageSteering_mt
    end;
	local self = setmetatable({}, CpGuiPageSteering_mt)
    self.parentGui = parentGui
	return self
end

function CpGuiPageSteering:setVehicle(vehicle) 
    self.vehicle = vehicle
end

function CpGuiPageSteering:onCreate() 

end

function CpGuiPageSteering:onOpen() 
      
end

function CpGuiPageSteering:onClose() 

end

function CpGuiPageSteering:onClick_1_start(btn, para)
    courseplay:startStop(self.vehicle)
end

function CpGuiPageSteering:onClick_1_copy_left(btn, para) 

end

function CpGuiPageSteering:onClick_1_copy_right(btn, para) 

end

function CpGuiPageSteering:onClick_1_copy(btn, para) 

end

