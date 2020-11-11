CpGuiPageDriversSearch = {}
CpGuiPageDriversSearch.xmlFilename = courseplay.path .. "gui_new/screens/Page_driversSearch.xml"


local CpGuiPageDriversSearch_mt = Class(CpGuiPageDriversSearch)

function CpGuiPageDriversSearch:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageDriversSearch_mt
    end;
	local self = setmetatable({}, CpGuiPageDriversSearch_mt)

	return self
end

function CpGuiPageDriversSearch:onCreate() 

end

function CpGuiPageDriversSearch:onOpen() 
      
end

function CpGuiPageDriversSearch:onClose() 

end