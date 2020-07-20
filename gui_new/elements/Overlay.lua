-- 
-- CoursePlay - Gui - Overlay
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

CpGuiOverlay = {}
local CpGuiOverlay_mt = Class(CpGuiOverlay, CpGuiElement)

function CpGuiOverlay:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiOverlay_mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "overlay"
	
	self.imageColor = {1,1,1,1}
	self.imageColor_disabled = {1,1,1,1}
	self.imageColor_selected = {1,1,1,1}
	self.imageColor_disabledSelected = {1,1,1,1}
	
	self.uvs = {0, 0, 0, 1, 1, 0, 1, 1}
	self.uvs_selected = {0, 0, 0, 1, 1, 0, 1, 1}
	self.uvs_disabled = {0, 0, 0, 1, 1, 0, 1, 1}
	self.uvs_disabledSelected = {0, 0, 0, 1, 1, 0, 1, 1}
	
	self.borderLeftSize = 0
	self.borderRightSize = 0
	self.borderTopSize = 0
	self.borderBottomSize = 0
	
	self.borderLeftColor = 0
	self.borderRightColor = 0
	self.borderTopColor = 0
	self.borderBottomColor = 0

	self.scaleX = 1
	self.scaleY = 1
	
	self.rotation = 0
	
	return self
end

function CpGuiOverlay:loadTemplate(templateName, xmlFile, key, overlayName)
	CpGuiOverlay:superClass().loadTemplate(self, templateName, xmlFile, key)
	
	if overlayName == nil then
		overlayName = "image"
	end
	
	self.imageFilename = courseplay.guiManager:getTemplateValue(templateName, overlayName .. "Filename")		
		
	self.uvs = courseplay.guiManager:getTemplateValueUVs(templateName, overlayName .. "UVs", self.imageSize, self.uvs)
	self.uvs_selected = courseplay.guiManager:getTemplateValueUVs(templateName, overlayName .. "UVs_selected", self.imageSize, self.uvs_selected)
	self.uvs_disabled = courseplay.guiManager:getTemplateValueUVs(templateName, overlayName .. "UVs_disabled", self.imageSize, self.uvs_disabled)	
	self.uvs_disabledSelected = courseplay.guiManager:getTemplateValueUVs(templateName, overlayName .. "UVs_disabledSelected", self.imageSize, self.uvs_disabledSelected)	
	
	self.imageColor = courseplay.guiManager:getTemplateValueColor(templateName, overlayName .. "Color", self.imageColor)
	self.imageColor_disabled = courseplay.guiManager:getTemplateValueColor(templateName, overlayName .. "Color_disabled", self.imageColor_disabled)
	self.imageColor_selected = courseplay.guiManager:getTemplateValueColor(templateName, overlayName .. "Color_selected", self.imageColor_selected)	
	self.imageColor_disabledSelected = courseplay.guiManager:getTemplateValueColor(templateName, overlayName .. "Color_disabledSelected", self.imageColor_disabledSelected)	
	
	self.isCamera = courseplay.guiManager:getTemplateValueBool(templateName, "isCamera", false)	
	self.hasBorders = courseplay.guiManager:getTemplateValueBool(templateName, "hasBorders", false)	
	if self.hasBorders then
		self.borders = CpGuiBorders:new(self.gui)
		self.borders:loadTemplate(templateName, xmlFile, key)
		self:addElement(self.borders)
	end
	
	self.rotation = courseplay.guiManager:getTemplateValueNumber(templateName, "rotation", self.rotation)
	
	local uiElement = courseplay.guiManager:getUiElement(self.imageFilename)
	if self.imageFilename == "g_baseUIFilename" then
		self.imageFilename = g_baseUIFilename
	elseif self.imageFilename == "g_baseHUDFilename" then
		self.imageFilename = g_baseHUDFilename
	elseif self.imageFilename == "pda" then
		self.imageFilename = g_currentMission.mapImageFilename
	elseif uiElement ~= nil then
        self.imageFilename = uiElement
	end
	
	self.imageOverlay = createImageOverlay(self.imageFilename)
	self:loadOnCreate()
end

function CpGuiOverlay:copy(src)
	CpGuiOverlay:superClass().copy(self, src)
	
	self:setImageFilename(src.imageFilename)
	self.uvs = src.uvs
	self.uvs_selected = src.uvs_selected
	self.uvs_disabled = src.uvs_disabled
	self.uvs_disabledSelected = src.uvs_disabledSelected
	
	self.imageColor = src.imageColor
	self.imageColor_disabled = src.imageColor_disabled
	self.imageColor_selected = src.imageColor_selected
	self.imageColor_disabledSelected = src.imageColor_disabledSelected
	
	self.rotation = src.rotation
	self.hasBorders = src.hasBorders
	
	if self.hasBorders then
		self.borders = CpGuiBorders:new(self.gui)
		self.borders:copy(src.borders)
		self:addElement(self.borders)
	end
	
	--self.imageOverlay = createImageOverlay(self.imageFilename)
	self:copyOnCreate()
end

function CpGuiOverlay:setImageFilename(filename)
	local uiElement = courseplay.guiManager:getUiElement(filename)
	if uiElement ~= nil then
		filename = uiElement
	end
	self.imageFilename = filename
	self.imageOverlay = createImageOverlay(self.imageFilename)
end

function CpGuiOverlay:setImageOverlay(overlay)
	self.imageOverlay = overlay
end

function CpGuiOverlay:delete()
	CpGuiOverlay:superClass().delete(self)
	if self.imageOverlay ~= nil and self.imageOverlay ~= 0 then
		delete(self.imageOverlay)
		self.imageOverlay = nil
	end
end

function CpGuiOverlay:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	CpGuiOverlay:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiOverlay:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiOverlay:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiOverlay:update(dt)
	CpGuiOverlay:superClass().update(self, dt)
end

function CpGuiOverlay:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)
	
	--if self:getVisible() then
		if self.isCamera then
			setOverlayRotation(self.imageOverlay, self.rotation, self.size[1] * 0.5, self.size[2] * 0.5)
			renderOverlay(self.imageOverlay, self.drawPosition[1], self.drawPosition[2], self.size[1], self.size[2])
		else
			setOverlayRotation(self.imageOverlay, self.rotation, self.size[1] * 0.5, self.size[2] * 0.5)
			setOverlayUVs(self.imageOverlay, unpack(self:getUVs()))
			setOverlayColor(self.imageOverlay, unpack(self:getImageColor()))
			
			local sizeX = math.max(self.size[1], 1 / g_screenWidth)
			local sizeY = math.max(self.size[2], 1 / g_screenHeight)			
			renderOverlay(self.imageOverlay, self.drawPosition[1], self.drawPosition[2], sizeX * self.scaleX, sizeY * self.scaleY)
		end
	--end

	CpGuiOverlay:superClass().draw(self)
end

function CpGuiOverlay:setScale(x,y)
	self.scaleX = x
	self.scaleY = Utils.getNoNil(y,self.scaleY)
end

function CpGuiOverlay:setUV(str)
	self.uvs = GuiUtils.getUVs(str, self.imageSize, nil)
end

function CpGuiOverlay:getUVs()
    if self:getDisabled() and self:getIsSelected() then
        return self.uvs_disabledSelected
	elseif self:getDisabled() then
        return self.uvs_disabled
    elseif self:getIsSelected() then
        return self.uvs_selected
    else
        return self.uvs
    end
end

function CpGuiOverlay:getImageColor()
    if self:getDisabled() and self:getIsSelected() then
        return self.imageColor_disabledSelected
	elseif self:getDisabled() then
        return self.imageColor_disabled
    elseif self:getIsSelected() then
        return self.imageColor_selected
    else
        return self.imageColor
    end
end

function CpGuiOverlay:setRotation(rotation)
	self.rotation = rotation
end

function CpGuiOverlay:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	CpGuiOverlay:superClass().onOpen(self)
end

function CpGuiOverlay:setImageUv(uv, all)
	if courseplay.guiManager.template.uvs[uv] ~= nil then
		self.uvs = GuiUtils.getUVs(courseplay.guiManager.template.uvs[uv], self.imageSize, self.default)
		if all then
			self.uvs_selected = self.uvs
			self.uvs_disabled = self.uvs
		end
	end
end