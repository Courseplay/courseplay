-- 
-- CoursePlay - Gui - Main
-- 
-- @Interface: 1.6.0.0 b9166
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.07.2020
-- @Version: 1.0.0.0
-- 
-- @Changelog:
--		
-- 	v1.0.0.0 (kevink98):
-- 		- initial fs19
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
--

CpGuiMain = {}
CpGuiMain.xmlFilename = courseplay.path .. "gui_new/screens/Main.xml"

CpGuiMain._mt = Class(CpGuiMain)

function CpGuiMain:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiMain._mt
    end
    local self = setmetatable({}, CpGuiMain_mt)
	
	return self
end

function CpGuiMain:onCreate() 
    
    
end

function CpGuiMain:onOpen() 

end

function CpGuiMain:onClose() 
    
end


function CpGuiMain:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    
end

function CpGuiMain:keyEvent(unicode, sym, modifier, isDown, eventUsed)
   
end

function CpGuiMain:update(dt)
	
end

function CpGuiMain:draw()
	
end

function CpGuiMain:setData(site)
    
end