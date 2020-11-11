CpGuiPageDriversSiloCompaction = {}
CpGuiPageDriversSiloCompaction.xmlFilename = courseplay.path .. "gui_new/screens/Page_siloCompaction.xml"


local CpGuiPageDriversSiloCompaction_mt = Class(CpGuiPageDriversSiloCompaction)

function CpGuiPageDriversSiloCompaction:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageDriversSiloCompaction_mt
    end;
	local self = setmetatable({}, CpGuiPageDriversSiloCompaction_mt)

	return self
end

function CpGuiPageDriversSiloCompaction:onCreate() 

end

function CpGuiPageDriversSiloCompaction:onOpen() 
      
end

function CpGuiPageDriversSiloCompaction:onClose() 

end