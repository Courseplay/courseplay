-- 
-- CoursePlay - Gui - Element
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

CpGuiElement = {}
local CpGuiElement_mt = Class(CpGuiElement)

function CpGuiElement:isElement()

end

function CpGuiElement:new(gui, custom_mt, isOnlyElement)	
	if custom_mt == nil then
		custom_mt = CpGuiElement_mt
	end
	
	local self = setmetatable({}, custom_mt)
	self.name = "empty"
	self.elements = {}
	self.gui = gui
	
	self.isOnlyElement = isOnlyElement or false
	self.position = {0,0} 
	self.drawPosition = {0,0} 
	self.size = {1,1}
	self.margin = {0,0,0,0} --left, top, right, bottom
	self.outputSize = courseplay.guiManager:getOutputSize()
    self.imageSize = {1024, 1024}
	self.visible = true
	self.disabled = false
	self.selected = false
	self.debugEnabled = false
	self.parameter = false
	
	self.newLayer = false	
	
	return self
end

function CpGuiElement:loadTemplate(templateName, xmlFile, key)
	self.anchor = courseplay.guiManager:getTemplateAnchor(templateName)
	self.position = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "position"), self.outputSize, self.position)
	self.size = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "size"), self.outputSize, self.size)
	self.margin = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "margin"), self.outputSize, self.margin)
	self.imageSize = GuiUtils.get2DArray(courseplay.guiManager:getTemplateValue(templateName, "imageSize"), self.imageSize)
	
	self.visible = courseplay.guiManager:getTemplateValueBool(templateName, "visible", self.visible)
	self.disabled = courseplay.guiManager:getTemplateValueBool(templateName, "disabled", self.disabled)
	self.debugEnabled = courseplay.guiManager:getTemplateValueBool(templateName, "debugEnabled", self.debugEnabled)
	self.newLayer = courseplay.guiManager:getTemplateValueBool(templateName, "newLayer", self.newLayer)
		
	if xmlFile ~= nil then
		self.visible = courseplay.guiManager:getTemplateValueBoolXML(xmlFile, "visible", key, self.visible)
		self.disabled = courseplay.guiManager:getTemplateValueBoolXML(xmlFile, "disabled", key, self.disabled)
		
		self.position = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValueXML(xmlFile, "position", key), self.outputSize, self.position)
		self.size = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValueXML(xmlFile, "size", key), self.outputSize, self.size)
		self.margin = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValueXML(xmlFile, "margin", key), self.outputSize, self.margin)
		
		self.anchor = courseplay.guiManager:getTemplateValueXML(xmlFile, "anchor", key, self.anchor)
		self.parameter = courseplay.guiManager:getTemplateValueXML(xmlFile, "parameter", key)
		
		self.callback_onOpen = courseplay.guiManager:getTemplateValueXML(xmlFile, "onOpen", key)
		self.callback_onCreate = courseplay.guiManager:getTemplateValueXML(xmlFile, "onCreate", key)
		self.callback_onDraw = courseplay.guiManager:getTemplateValueXML(xmlFile, "onDraw", key)
	end
	
	if self.isOnlyElement then
		self:loadOnCreate()
	end
end

function CpGuiElement:loadOnCreate()
	if self.callback_onCreate ~= nil then
		self.gui[self.callback_onCreate](self.gui, self, self.parameter)
	end
end

function CpGuiElement:onOpen()
	if self.isOnlyElement and self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	for _,v in ipairs(self.elements) do
		v:onOpen()
	end
end
	
function CpGuiElement:copy(src)	
	self.anchor = src.anchor
	self.position = src.position
	self.size = src.size
	self.margin = src.margin
	self.imageSize = src.imageSize
	
	self.visible = src.visible
	self.disabled = src.disabled
	self.debugEnabled = src.debugEnabled
	
	self.visible = src.visible
	self.disabled = src.disabled
	
	self.callback_onCreate = src.callback_onCreate
	
	--for k,element in pairs(self.elements) do
	--	element:copy(src.elements[k])
	--end
	if self.isOnlyElement then
		self:copyOnCreate()
	end
end

function CpGuiElement:copyOnCreate()
	if self.callback_onCreate ~= nil then
		self.gui[self.callback_onCreate](self.gui, self, self.parameter)
	end
end

function CpGuiElement:setParent(parent)
	self.parent = parent
	if self.isOnlyElement then
		self:copy(parent)
		self.position = {0,0} 
		self.margin = {0,0,0,0}
	end
end

function CpGuiElement:delete()
	for _,v in ipairs(self.elements) do
		v:delete()
	end
end

function CpGuiElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	for _,v in ipairs(self.elements) do
		if v:getVisible() then
			v:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
		end
	end
end

function CpGuiElement:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	for _,v in ipairs(self.elements) do
		if v:getVisible() then
			v:keyEvent(unicode, sym, modifier, isDown, eventUsed)
		end
	end
end

function CpGuiElement:update(dt)
	for _,v in ipairs(self.elements) do
		if v:getVisible() then
			v:update(dt)
		end
	end
end

function CpGuiElement:draw(index, gui)
	if self.isOnlyElement then
		self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index, gui)
	end
	if self.newLayer then
		new2DLayer()
	end
	
	if self.debugEnabled then
		local xPixel = 1 / g_screenWidth
		local yPixel = 1 / g_screenHeight
		setOverlayColor(GuiElement.debugOverlay, 1, 0,0,1)
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]-xPixel, self.drawPosition[2]-yPixel, self.size[1]+2*xPixel, yPixel)
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]-xPixel, self.drawPosition[2]+self.size[2], self.size[1]+2*xPixel, yPixel)
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]-xPixel, self.drawPosition[2], xPixel, self.size[2])
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]+self.size[1], self.drawPosition[2], xPixel, self.size[2])
	end

	if self.callback_onDraw ~= nil then
		self.gui[self.callback_onDraw](self.gui, self, self.parameter)
	end

	for k,v in ipairs(self.elements) do
		if v:getVisible() then
			v:draw(k)
		end
	end
end

function CpGuiElement:addElement(element)
	if element.parent ~= nil then
		element.parent:removeElement(element)
	end
	table.insert(self.elements, element)
	element.parent = self
end

function CpGuiElement:removeElement(element)
	for k,e in pairs(self.elements) do
		if e == element then
			table.remove(self.elements, k)
			element.parent = nil
			break
		end
	end
end

function CpGuiElement:removeElements()
	for k,e in pairs(self.elements) do
		e.parent = nil
	end
	self.elements = {}
end

function CpGuiElement:setDisabled(state)
	if state == nil then
		state = false
	end
	self.disabled = state
	for _,element in pairs(self.elements) do
		element:setDisabled(state)
	end
end

function CpGuiElement:getDisabled()
	return self.disabled
end

function CpGuiElement:setVisible(state)
	if state == nil then
		state = false
	end
	self.visible = state
	for _,element in pairs(self.elements) do
		element:setVisible(state)
	end
end

function CpGuiElement:getVisible()
	return self.visible
end

function CpGuiElement:setSelected(state, noCheckButton)
	if state == nil then
		state = false
	end
	self.selected = state
	for _,element in pairs(self.elements) do
		if noCheckButton then
			if element.name ~= "button" then
				element:setSelected(state)
			end
		else
			element:setSelected(state)
		end
	end
end

function CpGuiElement:getIsSelected()
	return self.selected
end

function CpGuiElement:getAnchor()
	return self.anchor
end

function CpGuiElement:setPosition(str)
	self.position = GuiUtils.getNormalizedValues(str, self.outputSize, self.position)
end

function CpGuiElement:getXleft()
	return self.position[1] + self.margin[1]
end

function CpGuiElement:getXright()
	return self.position[1] + self.margin[1] + self.size[1]
end

function CpGuiElement:getYbottom()
	return self.position[2] + self.margin[2]
end

function CpGuiElement:getYtop()
	return self.position[2] + self.margin[2] + self.size[2]
end

function CpGuiElement:setSortName(sortName)
	self.sortName = sortName
end