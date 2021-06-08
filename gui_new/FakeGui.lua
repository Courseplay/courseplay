-- 
-- CoursePlay 
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

FakeGui = {}
FakeGui.guiInformations = {}
FakeGui.guiInformations.guiXml = "gui_new/FakeGui.xml"

FakeGui._mt = Class(FakeGui, ScreenElement)

function FakeGui:new(target, custom_mt)
    return ScreenElement:new(target, FakeGui._mt)
end
function FakeGui:onCreate() 
	self.exit = true
end

function FakeGui:update(dt)
	FakeGui:superClass().update(self, dt)
end
function FakeGui:onOpen()
    FakeGui:superClass().onOpen(self)	
end
function FakeGui:onClose(element)
    FakeGui:superClass().onClose(self)
end
function FakeGui:onClickBack()
	if self.exit then
		courseplay.guiManager:closeActiveGui()
		g_gui:showGui("")
	end
end
function FakeGui:setExit(val)
	self.exit = val
end