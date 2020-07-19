-- 
-- CoursePlay - Gui - FlowLayout
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

CpGuiFlowLayout = {}

CpGuiFlowLayout.ORIENTATION_X = 1
CpGuiFlowLayout.ORIENTATION_Y = 2

CpGuiFlowLayout.ALIGNMENT_LEFT = 1
CpGuiFlowLayout.ALIGNMENT_MIDDLE = 2
CpGuiFlowLayout.ALIGNMENT_RIGHT = 3
CpGuiFlowLayout.ALIGNMENT_TOP = 4
CpGuiFlowLayout.ALIGNMENT_CENTER = 5
CpGuiFlowLayout.ALIGNMENT_BOTTOM = 6

CpGuiFlowLayout._mt = Class(CpGuiFlowLayout, CpGuiElement)

function CpGuiFlowLayout:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiFlowLayout._mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "flowLayout"
	
	self.orientation = CpGuiFlowLayout.ORIENTATION_X
	self.alignment = CpGuiFlowLayout.ALIGNMENT_LEFT
	
	return self
end

function CpGuiFlowLayout:loadTemplate(templateName, xmlFile, key)
	CpGuiFlowLayout:superClass().loadTemplate(self, templateName, xmlFile, key)
	
	local orientation = courseplay.guiManager:getTemplateValue(templateName, "orientation")
	local alignment = courseplay.guiManager:getTemplateValue(templateName, "alignment")
	
	if orientation == "x" then
		self.orientation = CpGuiFlowLayout.ORIENTATION_X
	elseif orientation == "y" then
		self.orientation = CpGuiFlowLayout.ORIENTATION_Y
	end
	
	if alignment == "left" then
		self.alignment = CpGuiFlowLayout.ALIGNMENT_LEFT
	elseif alignment == "middle" then
		self.alignment = CpGuiFlowLayout.ALIGNMENT_MIDDLE
	elseif alignment == "right" then
		self.alignment = CpGuiFlowLayout.ALIGNMENT_RIGHT
	elseif alignment == "top" then
		self.alignment = CpGuiFlowLayout.ALIGNMENT_TOP
	elseif alignment == "center" then
		self.alignment = CpGuiFlowLayout.ALIGNMENT_CENTER
	elseif alignment == "bottom" then
		self.alignment = CpGuiFlowLayout.ALIGNMENT_BOTTOM
	end	
	self:loadOnCreate()
end

function CpGuiFlowLayout:copy(src)
	CpGuiFlowLayout:superClass().copy(self, src)
	
	self.orientation = src.orientation
	self.alignment = src.alignment
	self:copyOnCreate()
end

function CpGuiFlowLayout:delete()
	CpGuiFlowLayout:superClass().delete(self)
end

function CpGuiFlowLayout:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	CpGuiFlowLayout:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiFlowLayout:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiFlowLayout:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiFlowLayout:update(dt)
	CpGuiFlowLayout:superClass().update(self, dt)
end

function CpGuiFlowLayout:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)
	CpGuiFlowLayout:superClass().draw(self)
end

function CpGuiFlowLayout:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	CpGuiFlowLayout:superClass().onOpen(self)
end

function CpGuiFlowLayout:setActive(state, e)
	for _,element in pairs(self.elements) do
		if e ~= element then
			element:setActive(state)
		end
	end
end