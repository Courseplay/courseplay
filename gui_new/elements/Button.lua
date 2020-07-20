-- 
-- CoursePlay - Gui - Button
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

CpGuiButton = {}
local CpGuiButton_mt = Class(CpGuiButton, CpGuiElement)

function CpGuiButton:new(gui, custom_mt)
    if custom_mt == nil then
		custom_mt = CpGuiButton_mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "button"
	
	self.data = {}
	self.isRoundButton = false	
	self.isActivable = false
	self.isActive = false
	self.mouseDown = false
	self.mouseEntered = false
	self.isTableTemplate = false
	self.isMultiSelect = false
	self.checkParent = false
	self.canDeactivable = true

	self.inputAction = nil
	self.clickSound = nil
	
    self.doubleClickInterval = 1000
	self.doubleClickTime = 0
	
	self.sliderPosition = {0,0}
	return self
end

function CpGuiButton:loadTemplate(templateName, xmlFile, key)
	CpGuiButton:superClass().loadTemplate(self, templateName, xmlFile, key)
	
	self.isActivable = courseplay.guiManager:getTemplateValueBool(templateName, "isActivable", self.isActivable)
	self.canDeactivable = courseplay.guiManager:getTemplateValueBool(templateName, "canDeactivable", self.canDeactivable)
	self.isRoundButton = courseplay.guiManager:getTemplateValueBool(templateName, "isRoundButton", self.isRoundButton)		
	self.isMultiSelect = courseplay.guiManager:getTemplateValueBool(templateName, "isMultiSelect", self.isMultiSelect)		
	self.checkParent = courseplay.guiManager:getTemplateValueBool(templateName, "checkParent", self.checkParent)		
	self.clickZone = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "clickZone"), self.outputSize, nil)
		
	self.isTableTemplate = courseplay.guiManager:getTemplateValueBool(templateName, "isTableTemplate", self.isTableTemplate)
	self.hasOverlay = courseplay.guiManager:getTemplateValueBool(templateName, "hasOverlay", false)
	self.hasText = courseplay.guiManager:getTemplateValueBool(templateName, "hasText", false)
	local inputAction = courseplay.guiManager:getTemplateValue(templateName, "inputAction")

	if xmlFile ~= nil then
		self.callback_onClick = courseplay.guiManager:getTemplateValueXML(xmlFile, "onClick", key, nil)
		self.callback_onDoubleClick = courseplay.guiManager:getTemplateValueXML(xmlFile, "onDoubleClick", key, nil)
		self.callback_onEnter = courseplay.guiManager:getTemplateValueXML(xmlFile, "onEnter", key, nil)
		self.callback_onLeave = courseplay.guiManager:getTemplateValueXML(xmlFile, "onLeave", key, nil)

		self.openPage = courseplay.guiManager:getTemplateValueXML(xmlFile, "openPage", key, nil)
		
		self.isTableTemplate = courseplay.guiManager:getTemplateValueBoolXML(xmlFile, "isTableTemplate", key, self.isTableTemplate)

		inputAction = courseplay.guiManager:getTemplateValueXML(xmlFile, "inputAction", key, inputAction)
	end

	if inputAction ~= nil and InputAction[inputAction] ~= nil then
		self.inputAction = InputAction[inputAction]
		self.hasText = true
	end
	
	if self.hasOverlay then
		self.overlayElement = CpGuiOverlay:new(self.gui)
		self.overlayElement:loadTemplate(string.format("%s_overlay", templateName), xmlFile, key)
		self.overlayElement.position = { 0,0 }
		self:addElement(self.overlayElement)
		--if id ~= nil and id ~= "" then
		--	self.gui[id] = self.overlayElement
		--end
	end

	if self.hasText then
		self.textElement = CpGuiText:new(self.gui)
		self.textElement:loadTemplate(string.format("%s_text", templateName), xmlFile, key)
		self.textElement.position = { 0,0 }
		self:addElement(self.textElement)
		--if id ~= nil and id ~= "" then
		--	self.gui[id] = self.textElement
		--end
		
		if self.inputAction ~= nil then
			self.textElement:setText(g_inputDisplayManager:getKeyboardInputActionKey(self.inputAction))
		end
	end
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self)
	end
	self:loadOnCreate()
end

function CpGuiButton:copy(src)
	CpGuiButton:superClass().copy(self, src)
	
	self.isActivable = src.isActivable
	self.isRoundButton = src.isRoundButton
	self.isMultiSelect = src.isMultiSelect
	self.canDeactivable = src.canDeactivable
	self.checkParent = src.checkParent
	self.clickZone = src.clickZone
	
	self.callback_onClick = src.callback_onClick
	self.callback_onDoubleClick = src.callback_onDoubleClick
	self.callback_onEnter = src.callback_onEnter
	self.callback_onLeave = src.callback_onLeave
	self.openPage = src.openPage
	
	--self.isTableTemplate = src.isTableTemplate
	self:copyOnCreate()
end

function CpGuiButton:delete()
	CpGuiButton:superClass().delete(self)
end

function CpGuiButton:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if not self:getDisabled() then
		eventUsed = CpGuiButton:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
			
		local clickZone = {}		
		if self.clickZone == nil then			
			clickZone[1] = self.drawPosition[1]
			clickZone[2] = self.drawPosition[2] + self.size[2]
			clickZone[3] = self.drawPosition[1] + self.size[1]
			clickZone[4] = self.drawPosition[2] + self.size[2]
			clickZone[5] = self.drawPosition[1] + self.size[1]
			clickZone[6] = self.drawPosition[2]
			clickZone[7] = self.drawPosition[1]
			clickZone[8] = self.drawPosition[2]
		else
			if self.isRoundButton then
				clickZone[1] = self.drawPosition[1] + self.clickZone[1] + self.margin[1]
				clickZone[2] = self.drawPosition[2] + self.clickZone[2] + self.margin[4]
				clickZone[3] = self.clickZone[3]
			else
				for i=1, table.getn(self.clickZone), 2 do
					clickZone[i] = self.drawPosition[1] + self.clickZone[i] + self.margin[1]
					clickZone[i+1] = self.drawPosition[2] + self.clickZone[i+1] + self.margin[4]
				end			
			end
		end
		
		if not eventUsed then
			if courseplay.guiManager:checkClickZone(posX, posY, clickZone, self.isRoundButton) then
				if not self.mouseEntered then
					self.mouseEntered = true					
					self.backupPos = {posX, posY}
					self:setSelected(true, self.parent.name == "table")
					if self.callback_onEnter ~= nil then
						self.gui[self.callback_onEnter](self.gui, self, self.parameter)
					end
				end
				
				if isDown and button == Input.MOUSE_BUTTON_LEFT then
					self.mouseDown = true
				end
				
				if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
					self.mouseDown = false
					if self.isActivable then
						if not self.canDeactivable then
							if not self.isActive then
								self:setActive(not self.isActive)
							end
						else
							self:setActive(not self.isActive)
						end
					end
					if self.doubleClickTime <= 0 then
						self.doubleClickTime = self.doubleClickInterval
					else
						if self.callback_onDoubleClick ~= nil then
							self.gui[self.callback_onDoubleClick](self.gui, self, self.parameter)
						end
						self.doubleClickTime = 0
					end
					
					if self.callback_onClick ~= nil and self.gui[self.callback_onClick] ~= nil then
						self.gui[self.callback_onClick](self.gui, self, self.parameter)
					end
					
					if self.openPage ~= nil and self.parent ~= nil and self.parent.parent ~= nil and self.parent.parent.name == "pageSelector" then
						self.parent.parent:openPage(self.openPage)
					end
				end
			else
				if self.mouseEntered then
					self.mouseEntered = false
					if self.isActivable then
						if not self.isActive then
							self:setSelected(false)
						end
					else
						self:setSelected(false)
					end					
					if self.callback_onLeave ~= nil then
						self.gui[self.callback_onLeave](self.gui, self, self.parameter)
					end
				end
			end
			if self.mouseDown and self.parent.name == "slider" then
				if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
					self.mouseDown = false
					self:setSelected(false)
				else
					self:setSelected(true)
					self.parent:moveSlider(self.backupPos[1] - posX, self.backupPos[2] - posY)	
					self.backupPos = {posX, posY}
				end
			end
		end		
	end	
	return eventUsed
end

function CpGuiButton:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiButton:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiButton:update(dt)
	CpGuiButton:superClass().update(self, dt)
	if self.doubleClickTime > 0 then
		self.doubleClickTime = self.doubleClickTime - dt
	end
end

function CpGuiButton:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)			
	
	if self.debugEnabled then
		local xPixel = 1 / g_screenWidth
		local yPixel = 1 / g_screenHeight
		setOverlayColor(GuiElement.debugOverlay, 1, 0,0,1)
				
		if self.isRoundButton then		
			local y = self.clickZone[3] * (g_screenWidth / g_screenHeight)
			renderOverlay(GuiElement.debugOverlay, self.drawPosition[1] + self.clickZone[1] + self.margin[1], self.drawPosition[2] + self.clickZone[2] + self.margin[4], self.clickZone[3],yPixel)
			renderOverlay(GuiElement.debugOverlay, self.drawPosition[1] + self.clickZone[1] + self.margin[1], self.drawPosition[2] + self.clickZone[2] + self.margin[4], xPixel,y)
		else
			local clickZone = {}		
			if self.clickZone == nil then				
				clickZone[1] = self.drawPosition[1]
				clickZone[2] = self.drawPosition[2] + self.size[2]
				clickZone[3] = self.drawPosition[1] + self.size[1]
				clickZone[4] = self.drawPosition[2] + self.size[2]
				clickZone[5] = self.drawPosition[1] + self.size[1]
				clickZone[6] = self.drawPosition[2]
				clickZone[7] = self.drawPosition[1]
				clickZone[8] = self.drawPosition[2]
			else
				for i=1, table.getn(self.clickZone), 2 do
					clickZone[i] = self.drawPosition[1] + self.clickZone[i] + self.margin[1]
					clickZone[i+1] = self.drawPosition[2] + self.clickZone[i+1] + self.margin[4]
				end	
			end	
			
			for i=1, table.getn(clickZone), 2 do
				renderOverlay(GuiElement.debugOverlay, clickZone[i], clickZone[i+1], xPixel*3,yPixel*3)
			end
		end
	end

	self.drawPosition[1] = self.drawPosition[1] + self.sliderPosition[1]
	self.drawPosition[2] = self.drawPosition[2] - self.sliderPosition[2]
	
	CpGuiButton:superClass().draw(self)
end

function CpGuiButton:setActive(state, checkNotParent)
	if state == nil then
		state = false
	end

	if not checkNotParent and not self.isMultiSelect and state and (self.parent.name == "table" or self.checkParent) then
		self.parent:setActive(false, true)
	end
	self.isActive = state
	self:setSelected(state, self.parent.name == "table")
end

function CpGuiButton:getActive()
	return self.isActive
end

function CpGuiButton:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	CpGuiButton:superClass().onOpen(self)
end


function CpGuiButton:setText(...)
	if self.inputAction ~= nil then
		return
	end
	for _,v in ipairs(self.elements) do
		if v.setText ~= nil then
			v:setText(...)
		end
	end
end