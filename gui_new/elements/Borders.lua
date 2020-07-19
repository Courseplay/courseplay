-- 
-- CoursePlay - Gui - Borders
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

CpGuiBorders = {}
CpGuiBorders._mt = Class(CpGuiBorders, CpGuiElement)

function CpGuiBorders:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiBorders._mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "borders"
	
	self.borderLeftSize = 0
	self.borderRightSize = 0
	self.borderTopSize = 0
	self.borderBottomSize = 0
	
	self.borderLeftSize_selected = 0
	self.borderRightSize_selected = 0
	self.borderTopSize_selected = 0
	self.borderBottomSize_selected = 0
	
	self.borderLeftSize_disabled = 0
	self.borderRightSize_disabled = 0
	self.borderTopSize_disabled = 0
	self.borderBottomSize_disabled = 0
	
	self.borderLeftColor = {1,1,1,1}
	self.borderRightColor = {1,1,1,1}
	self.borderTopColor = {1,1,1,1}
	self.borderBottomColor = {1,1,1,1}
	
	self.borderLeftColor_selected = {1,1,1,1}
	self.borderRightColor_selected = {1,1,1,1}
	self.borderTopColor_selected = {1,1,1,1}
	self.borderBottomColor_selected = {1,1,1,1}
	
	self.borderLeftColor_disabled = {1,1,1,1}
	self.borderRightColor_disabled = {1,1,1,1}
	self.borderTopColor_disabled = {1,1,1,1}
	self.borderBottomColor_disabled = {1,1,1,1}
		
	return self
end

function CpGuiBorders:loadTemplate(templateName, xmlFile, key)
	CpGuiBorders:superClass().loadTemplate(self, templateName, xmlFile, key)
	
	if overlayName == nil then
		overlayName = "image"
	end
	
	local imageFilename = g_baseUIFilename	
		
	self.borderLeftSize = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderLeftSize"), self.outputSize, {self.borderLeftSize})[1]
	self.borderRightSize = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderRightSize"), self.outputSize, {self.borderRightSize})[1]
	self.borderTopSize = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderTopSize"), self.outputSize, {self.borderTopSize})[1]
	self.borderBottomSize = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderBottomSize"), self.outputSize, {self.borderBottomSize})[1]
	
	self.borderLeftSize_selected = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderLeftSize_selected"), self.outputSize, {self.borderLeftSize_selected})[1]
	self.borderRightSize_selected = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderRightSize_selected"), self.outputSize, {self.borderRightSize_selected})[1]
	self.borderTopSize_selected = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderTopSize_selected"), self.outputSize, {self.borderTopSize_selected})[1]
	self.borderBottomSize_selected = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderBottomSize_selected"), self.outputSize, {self.borderBottomSize_selected})[1]
	
	self.borderLeftSize_disabled = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderLeftSize_disabled"), self.outputSize, {self.borderLeftSize_disabled})[1]
	self.borderRightSize_disabled = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderRightSize_disabled"), self.outputSize, {self.borderRightSize_disabled})[1]
	self.borderTopSize_disabled = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderTopSize_disabled"), self.outputSize, {self.borderTopSize_disabled})[1]
	self.borderBottomSize_disabled = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "borderBottomSize_disabled"), self.outputSize, {self.borderBottomSize_disabled})[1]
	
	self.borderLeftColor = courseplay.guiManager:getTemplateValueColor(templateName, "borderLeftColor", self.borderLeftColor)	
	self.borderRightColor = courseplay.guiManager:getTemplateValueColor(templateName, "borderRightColor", self.borderRightColor)	
	self.borderTopColor = courseplay.guiManager:getTemplateValueColor(templateName, "borderTopColor", self.borderTopColor)	
	self.borderBottomColor = courseplay.guiManager:getTemplateValueColor(templateName, "borderBottomColor", self.borderBottomColor)	
	
	self.borderLeftColor_selected = courseplay.guiManager:getTemplateValueColor(templateName, "borderLeftColor_selected", self.borderLeftColor_selected)	
	self.borderRightColor_selected = courseplay.guiManager:getTemplateValueColor(templateName, "borderRightColor_selected", self.borderRightColor_selected)	
	self.borderTopColor_selected = courseplay.guiManager:getTemplateValueColor(templateName, "borderTopColor_selected", self.borderTopColor_selected)	
	self.borderBottomColor_selected = courseplay.guiManager:getTemplateValueColor(templateName, "borderBottomColor_selected", self.borderBottomColor_selected)	
	
	self.borderLeftColor_disabled = courseplay.guiManager:getTemplateValueColor(templateName, "borderLeftColor_disabled", self.borderLeftColor_disabled)	
	self.borderRightColor_disabled = courseplay.guiManager:getTemplateValueColor(templateName, "borderRightColor_disabled", self.borderRightColor_disabled)	
	self.borderTopColor_disabled = courseplay.guiManager:getTemplateValueColor(templateName, "borderTopColor_disabled", self.borderTopColor_disabled)	
	self.borderBottomColor_disabled = courseplay.guiManager:getTemplateValueColor(templateName, "borderBottomColor_disabled", self.borderBottomColor_disabled)	
	
	self.uv = GuiUtils.getUVs("10px 1010px 4px 4px", self.imageSize, {0,0,1,1})
	
	self.imageLeft = createImageOverlay(imageFilename)
	self.imageRight = createImageOverlay(imageFilename)
	self.imageTop = createImageOverlay(imageFilename)
	self.imageBottom = createImageOverlay(imageFilename)
	
	self:loadOnCreate()
end

function CpGuiBorders:copy(src)
	CpGuiBorders:superClass().copy(self, src)
	
	self.borderLeftSize = src.borderLeftSize
	self.borderRightSize = src.borderRightSize
	self.borderTopSize = src.borderTopSize
	self.borderBottomSize = src.borderBottomSize
	
	self.borderLeftSize_selected = src.borderLeftSize_selected
	self.borderRightSize_selected = src.borderRightSize_selected
	self.borderTopSize_selected = src.borderTopSize_selected
	self.borderBottomSize_selected = src.borderBottomSize_selected
	
	self.borderLeftSize_disabled = src.borderLeftSize_disabled
	self.borderRightSize_disabled = src.borderRightSize_disabled
	self.borderTopSize_disabled = src.borderTopSize_disabled
	self.borderBottomSize_disabled = src.borderBottomSize_disabled
	
	self.borderLeftColor = src.borderLeftColor
	self.borderRightColor = src.borderRightColor
	self.borderTopColor = src.borderTopColor
	self.borderBottomColor = src.borderBottomColor
	
	self.borderLeftColor_selected = src.borderLeftColor_selected
	self.borderRightColor_selected = src.borderRightColor_selected
	self.borderTopColor_selected = src.borderTopColor_selected
	self.borderBottomColor_selected = src.borderBottomColor_selected
	
	self.borderLeftColor_disabled = src.borderLeftColor_disabled
	self.borderRightColor_disabled = src.borderRightColor_disabled
	self.borderTopColor_disabled = src.borderTopColor_disabled
	self.borderBottomColor_disabled = src.borderBottomColor_disabled
	
	self.uv = src.uv
	self.imageLeft = src.imageLeft
	self.imageRight = src.imageRight
	self.imageTop = src.imageTop
	self.imageBottom = src.imageBottom
	self:copyOnCreate()
end

function CpGuiBorders:setImageFilename(filename)
	self.imageOverlay = createImageOverlay(filename)
end

function CpGuiBorders:delete()
	CpGuiBorders:superClass().delete(self)
	if self.imageOverlay ~= nil then
		delete(self.imageOverlay)
		self.imageOverlay = nil
	end
end

function CpGuiBorders:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	CpGuiBorders:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiBorders:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiBorders:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiBorders:update(dt)
	CpGuiBorders:superClass().update(self, dt)
end

function CpGuiBorders:draw(index)		
	local sizeLeft = self:getBorderLeftSize()
	local sizeRight = self:getBorderRightSize()
	local sizeTop = self:getBorderTopSize()
	local sizeBottom = self:getBorderBottomSize()

	if sizeLeft > 0 then
		local  x = self.parent.drawPosition[1]
		local  y = self.parent.drawPosition[2]
		setOverlayUVs(self.imageLeft, unpack(self.uv))
		setOverlayColor(self.imageLeft, unpack(self:getBorderLeftColor()))		
		local sizeX = math.max(sizeLeft, 1 / g_screenWidth)
		local sizeY = math.max(self.parent.size[2], 1 / g_screenHeight)
		renderOverlay(self.imageLeft, x,y,sizeX, sizeY)
	end
	if sizeRight > 0 then
		local  x = self.parent.drawPosition[1] + self.parent.size[1] - self:getBorderRightSize()
		local  y = self.parent.drawPosition[2]
		setOverlayUVs(self.imageRight, unpack(self.uv))
		setOverlayColor(self.imageRight, unpack(self:getBorderRightColor()))
		local sizeX = math.max(sizeRight, 1 / g_screenWidth)
		local sizeY = math.max(self.parent.size[2], 1 / g_screenHeight)
		renderOverlay(self.imageRight, x,y,sizeX, sizeY)
	end
	if sizeTop > 0 then
		local  x = self.parent.drawPosition[1]
		local  y = self.parent.drawPosition[2] + self.parent.size[2] - self:getBorderTopSize()
		setOverlayUVs(self.imageTop, unpack(self.uv))
		setOverlayColor(self.imageTop, unpack(self:getBorderTopColor()))
		local sizeX = math.max(self.parent.size[1], 1 / g_screenWidth)
		local sizeY = math.max(sizeTop, 1 / g_screenHeight)
		renderOverlay(self.imageTop, x,y,sizeX, sizeY)
	end
	if sizeBottom > 0 then
		local  x = self.parent.drawPosition[1]
		local  y = self.parent.drawPosition[2]
		setOverlayUVs(self.imageBottom, unpack(self.uv))
		setOverlayColor(self.imageBottom, unpack(self:getBorderBottomColor()))		
		local sizeX = math.max(self.parent.size[1], 1 / g_screenWidth)
		local sizeY = math.max(sizeBottom, 1 / g_screenHeight)
		renderOverlay(self.imageBottom, x,y,sizeX, sizeY)
	end
	CpGuiBorders:superClass().draw(self,index)
end

function CpGuiBorders:getBorderLeftColor()
    if self:getDisabled() then
        return self.borderLeftColor_disabled
    elseif self:getIsSelected() then
        return self.borderLeftColor_selected
    else
        return self.borderLeftColor
    end
end

function CpGuiBorders:getBorderRightColor()
    if self:getDisabled() then
        return self.borderRightColor_disabled
    elseif self:getIsSelected() then
        return self.borderRightColor_selected
    else
        return self.borderRightColor
    end
end

function CpGuiBorders:getBorderTopColor()
    if self:getDisabled() then
        return self.borderTopColor_disabled
    elseif self:getIsSelected() then
        return self.borderTopColor_selected
    else
        return self.borderTopColor
    end
end

function CpGuiBorders:getBorderBottomColor()
    if self:getDisabled() then
        return self.borderBottomColor_disabled
    elseif self:getIsSelected() then
        return self.borderBottomColor_selected
    else
        return self.borderBottomColor
    end
end

function CpGuiBorders:getBorderLeftSize()
    if self:getDisabled() then
        return self.borderLeftSize_disabled
    elseif self:getIsSelected() then
        return self.borderLeftSize_selected
    else
        return self.borderLeftSize
    end
end

function CpGuiBorders:getBorderRightSize()
    if self:getDisabled() then
        return self.borderRightSize_disabled
    elseif self:getIsSelected() then
        return self.borderRightSize_selected
    else
        return self.borderRightSize
    end
end

function CpGuiBorders:getBorderTopSize()
    if self:getDisabled() then
        return self.borderTopSize_disabled
    elseif self:getIsSelected() then
        return self.borderTopSize_selected
    else
        return self.borderTopSize
    end
end

function CpGuiBorders:getBorderBottomSize()
    if self:getDisabled() then
        return self.borderBottomSize_disabled
    elseif self:getIsSelected() then
        return self.borderBottomSize_selected
    else
        return self.borderBottomSize
    end
end

function CpGuiBorders:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	CpGuiBorders:superClass().onOpen(self)
end