-- 
-- CoursePlay - Gui - Page
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

CpGuiPage = {}
local CpGuiPage_mt = Class(CpGuiPage, CpGuiElement)

function CpGuiPage:new(gui, custom_mt)	
	if custom_mt == nil then
        custom_mt = CpGuiPage_mt
    end
	local self = CpGuiElement:new(gui, custom_mt)
    
	return self
end

function CpGuiPage:loadTemplate(templateName, xmlFile, key)
	CpGuiPage:superClass().loadTemplate(self, templateName, xmlFile, key)
    
	if xmlFile ~= nil then
		self.pageName = courseplay.guiManager:getTemplateValueXML(xmlFile, "pageName", key, nil)
		self.pageHeader = courseplay.guiManager:getTemplateValueXML(xmlFile, "pageHeader", key, nil)
	end
	
	if self.pageName == nil then
		print("No pagename defined.")
	end

	self:loadOnCreate()
end

function CpGuiPage:copy(src)
	CpGuiPage:superClass().copy(self, src)

	self:copyOnCreate()
end

function CpGuiPage:delete()
	CpGuiPage:superClass().delete(self)
end

function CpGuiPage:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	return CpGuiPage:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiPage:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiPage:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiPage:update(dt)
	CpGuiPage:superClass().update(self, dt)
end

function CpGuiPage:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)	
		
	CpGuiPage:superClass().draw(self)
end