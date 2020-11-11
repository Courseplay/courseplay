CpGuiPageDriversShovel = {}
CpGuiPageDriversShovel.xmlFilename = courseplay.path .. "gui_new/screens/Page_shovel.xml"


local CpGuiPageDriversShovel_mt = Class(CpGuiPageDriversShovel)

function CpGuiPageDriversShovel:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageDriversShovel_mt
    end;
	local self = setmetatable({}, CpGuiPageDriversShovel_mt)

	return self
end

function CpGuiPageDriversShovel:onCreate() 

end

function CpGuiPageDriversShovel:onOpen() 
      
end

function CpGuiPageDriversShovel:onClose() 

end