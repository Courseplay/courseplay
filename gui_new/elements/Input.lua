-- 
-- CoursePlay - Gui - Input
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

CpGuiInput = {}
CpGuiInput._mt = Class(CpGuiInput, CpGuiElement)

function CpGuiInput:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiInput._mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "input"	
	
	return self
end

function CpGuiInput:loadTemplate(templateName, xmlFile, key)
	CpGuiInput:superClass().loadTemplate(self, templateName, xmlFile, key)
	
	self.buttonElement = CpGuiButton:new(self.gui)
	self.buttonElement:loadTemplate(templateName, xmlFile, key)

	self:addElement(self.buttonElement)
		        
    self.textElement = CpGuiText:new(self.gui)
    self.textElement:loadTemplate(string.format("%s_text", templateName), xmlFile, key)
    self:addElement(self.textElement)
        	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self)
	end
	self:loadOnCreate()
end

function CpGuiInput:copy(src)
	CpGuiInput:superClass().copy(self, src)	

	self:copyOnCreate()
end

function CpGuiInput:delete()
	CpGuiInput:superClass().delete(self)
end

function CpGuiInput:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	CpGuiInput:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiInput:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if self.buttonElement:getActive() and isDown then
		local currentText = self.textElement.text
        if sym == Input.KEY_backspace then
			currentText = currentText:sub(0, currentText:len() - 1)
        else
            currentText = currentText .. unicodeToUtf8(unicode)
        end
        self.textElement:setText(currentText)
    end
	CpGuiInput:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiInput:update(dt)
    CpGuiInput:superClass().update(self, dt)
end

function CpGuiInput:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)	
	
	CpGuiInput:superClass().draw(self)
end