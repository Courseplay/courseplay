-- 
-- CoursePlay 
-- 
-- @Interface: 1.6.0.0 b9166
-- @Author: LS-Modcompany / kevink98
-- @Date: 18.07.2020
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

GuiManager = {}
GuiManager._mt = Class(GuiManager)

GuiManager.devVersion = false -- if true, the gui will reload every defined time

GuiManager.guiClass = {}

function GuiManager:new(customMt)
	local self = {}
	setmetatable(self, customMt or GuiManager._mt)

	self.devVersionTimeReload = 1000 -- time for reload
	self.devVersionTemplateFiles = {}

	self.guis = {}
	self.smallGuis = {}
	self.toInit_actionEvents = {}
	self.activeGuiDialogs = {}
	self.registeredActionEvents = {} -- TODO: Need this variable?
	self.guiStates = {}

	self.template = {}
	self.template.colors = {}
	self.template.uvs = {}
	self.template.templates = {}
	self.template.uiElements = {}

	Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, self.init)
	--BaseMission.draw = Utils.appendedFunction(BaseMission.draw, self.drawB)

	return self
end

function GuiManager:load()
	self:loadGuiTemplates(courseplay.path .. "gui_new/guiTemplates.xml")

	self.fakeGui = GuiManager.fakeGui:new()
	g_gui:loadGui(courseplay.path .. self.fakeGui.guiInformations.guiXml, "cp_fakeGui", self.fakeGui)
	
	self:registerUiElements("g_cpIcons", courseplay.path .. "img/iconSprite.dds")
	
	self.mainCpGui = self:registerGui("cp_main", InputAction.COURSEPLAY_MOUSEACTION_SECONDARY, GuiManager.guiClass.main, false, false, true).classGui
	--self:registerInput("cp_main", InputAction.COURSEPLAY_HUD_OPEN, true) 
end

function GuiManager:init()
	--for _,inAc in pairs(courseplay.guiManager.toInit_actionEvents) do
	--	if (inAc.inVehicle and g_currentMission.controlledVehicle ~= nil) or not inAc.inVehicle then
	--		g_gui.inputManager:registerActionEvent(inAc.inputAction, courseplay.guiManager, inAc.func, false, true, false, true)
	--	end
	--end
	--FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, courseplay.guiManager.registerActionEventsVehicle)
end

function GuiManager:registerActionEventsVehicle()
	--print("registerActionEventsVehicle")
	--if self.toInit_actionEvents ~= nil then
		--print("registerActionEventsVehicle2")
		--for _,inAc in pairs(self.toInit_actionEvents) do
			--print("registerActionEventsVehicle3")
			--print(string.format("%s %s %s", inAc.inVehicle, g_currentMission.controlledVehicle ~= nil, (inAc.inVehicle and g_currentMission.controlledVehicle ~= nil) or not inAc.inVehicle))
			--if (inAc.inVehicle and g_currentMission.controlledVehicle ~= nil) or not inAc.inVehicle then
				--g_gui.inputManager:registerActionEvent(inAc.inputAction, self, inAc.func, false, true, false, true)
			--end
		--end
	--end
end

--function GuiManager:loadMap()	
	--Gui.mouseEvent = self_stored_gui_mouseEvent --TODO: Need it for cp? I think it was for the farmstart
	--Gui.keyEvent = self_stored_gui_keyEvent --TODO: Need it for cp? I think it was for the farmstart
--end

function GuiManager:update(dt)
	if GuiManager.devVersion then
		if self.devVersionTimeCurrent == nil or self.devVersionTimeCurrent <= 0 then
			for _, fileName in pairs(self.devVersionTemplateFiles) do				
				self:loadGuiTemplates(fileName)
			end
			for name,gui in pairs(self.guis) do		
				gui.gui:deleteElements()
				gui.gui:loadFromXML()
			end
			if self.activeGui ~= nil then
				self.guis[self.activeGui].gui:openGui()
			else
				for name, open in pairs(self.smallGuis) do
					if open then
						self.guis[name].gui:openGui()
					end
				end 
			end
			if self.activeGuiDialog ~= nil then
				self.guis[self.activeGuiDialog].gui:openGui()
			end
			self.devVersionTimeCurrent = self.devVersionTimeReload
		else
			self.devVersionTimeCurrent = self.devVersionTimeCurrent - dt
		end		
	end
	
	if self.activeGui == nil then
		for name, open in pairs(self.smallGuis) do
			if open then
				self.guis[name].gui:update(dt)
			end
		end
	else
		if g_gui:getIsDialogVisible() then
			self:closeGui(self.activeGui)
		else
			self.guis[self.activeGui].gui:update(dt)
		end
	end
	for _, name in pairs(self.activeGuiDialogs) do
		self.guis[name].gui:update(dt)
	end
end

function GuiManager:mouseEvent(posX, posY, isDown, isUp, button) 
	if self.activeGuiDialog ~= nil then
		self.guis[self.activeGuiDialog].gui:mouseEvent(posX, posY, isDown, isUp, button)
	elseif self.activeGui ~= nil then
		self.guis[self.activeGui].gui:mouseEvent(posX, posY, isDown, isUp, button)
	else		
		for name, open in pairs(self.smallGuis) do
			if open then
				self.guis[name].gui:mouseEvent(posX, posY, isDown, isUp, button)
			end
		end
	end
end

function GuiManager:keyEvent(unicode, sym, modifier, isDown) 
	if self.activeGuiDialog ~= nil then
		self.guis[self.activeGuiDialog].gui:keyEvent(unicode, sym, modifier, isDown)
	-- TODO: Need this really?
	--elseif self.activeGui == nil then
	--	for name, open in pairs(self.smallGuis) do
	--		if open then
	--			self.guis[name].gui:keyEvent(unicode, sym, modifier, isDown)
	--		end
	--	end
	elseif self.activeGui ~= nil then
		self.guis[self.activeGui].gui:keyEvent(unicode, sym, modifier, isDown)
	else		
		for name, open in pairs(self.smallGuis) do
			if open then
				self.guis[name].gui:keyEvent(unicode, sym, modifier, isDown)
			end
		end
	end
end

function GuiManager:draw()
	if self.activeGui == nil then
		if not g_gui:getIsGuiVisible() or g_currentMission == nil then
			for name, open in pairs(self.smallGuis) do
				if open then
					self.guis[name].gui:draw()
				end
			end
		end
	else
		self.guis[self.activeGui].gui:draw()
	end
	for _, name in pairs(self.activeGuiDialogs) do
		self.guis[name].gui:draw()
	end
end

function GuiManager:delete() 
	
end

function GuiManager:loadGui(class, name, isFullGui, canExit)
	if self.guis[name] ~= nil then
		print(string.format("Gui %s already exist.", name))
		return
	else 
		self.guis[name] = {}
	end

	self.guis[name].isFullGui = Utils.getNoNil(isFullGui, true)
	self.guis[name].canExit = Utils.getNoNil(canExit, true)

	local classGui = class:new()
	local newGui = GC_Gui:new(name)
	newGui:assignClass(classGui)
	self.guis[name].gui = newGui
	newGui:loadFromXML()
	return newGui
end

function GuiManager:registerGui(name, inputAction, class, isFullGui, canExit, inVehicle)
	if self.guis[name] ~= nil then
		print(string.format("Gui %s already exist.", name))
		return
	else 
		self.guis[name] = {}
	end
	
	local classGui = class:new()
	local newGui = CpGui:new(name)
	newGui:assignClass(classGui)
	self.guis[name].gui = newGui
	self.guis[name].isFullGui = Utils.getNoNil(isFullGui, true)
	self.guis[name].canExit = canExit
		
	if not self.guis[name].isFullGui then
		self.smallGuis[name] = false		
	end
	
	if inputAction ~= nil then
		local func = function() self:openGui(name) end	
		table.insert(self.toInit_actionEvents, {inputAction=inputAction, func=func, inVehicle=inVehicle})
	end
	
	newGui:loadFromXML()
	
	return newGui
end

function GuiManager:registerInput(name, inputAction, inVehicle)
	local func = function() self:openGui(name) end	
	table.insert(self.toInit_actionEvents, {inputAction=inputAction, func=func, inVehicle=inVehicle})
end

function GuiManager:setCanExit(name, canExit)
	if self.guis[name] ~= nil then
		self.guis[name].canExit = canExit
	end
end

function GuiManager:unregisterGui()
	if self.guis[name] ~= nil then
		self.guis[name].gui:delete()
		self.guis[name] = nil
	end
end

function GuiManager:openGui(name, asDialog)
	if not asDialog then
		self:closeActiveGui()
	end
	
	if self.guis[name] == nil then
		print(string.format("Gui %s not exist.", name))
		return
	end
	if self.guis[name].isFullGui then
		g_gui:showGui("cp_fakeGui")
		self.fakeGui:setExit(self.guis[name].canExit)
		
		if not asDialog then
			for nameG,_ in pairs(self.smallGuis) do
				self.guis[nameG].gui:closeGui()
			end
			
			self.activeGui = name
		end
	else
		self.smallGuis[name] = true
	end
	self.guis[name].gui:openGui()

	self.guiStates[name] = true
end

function GuiManager:getGuiForOpen(name, asDialog)
	if self.guis[name] == nil then
		print(string.format("Gui %s not exist.", name))
		return
	end
	if self.guis[name].isFullGui then
		g_gui:showGui("cp_fakeGui")
		self.fakeGui:setExit(self.guis[name].canExit)
		
		if asDialog then
			table.insert(self.activeGuiDialogs, name)
			self.activeGuiDialog = name
		else
			for nameG,_ in pairs(self.smallGuis) do
				self.guis[nameG].gui:closeGui()
			end
			
			self.activeGui = name
		end
	else
		self.smallGuis[name] = true
	end
	return self.guis[name].gui
end

function GuiManager:getGui(name)
	return self.guis[name].gui
end

function GuiManager:openGuiWithData(guiName, asDialog, ...)
	local gui = self:getGuiForOpen(guiName, asDialog)
	gui.classGui:setData(...)
	gui:openGui()
	return gui
end

function GuiManager:updateGuiData(guiName, ...)
	if self.activeGui == guiName then
		self.guis[guiName].gui.classGui:updateData(...)
	end
end

function GuiManager:closeGui(name)
	if self.guis[name].isFullGui then
		for nameG,open in pairs(self.smallGuis) do
			if open then
				self.guis[nameG].gui:openGui()
			end
		end
		self.activeGui = nil
		self.fakeGui:setExit(true)
		self.guis[name].gui:closeGui()
		g_gui:showGui("")
	else
		self.smallGuis[name] = false
	end	
end

function GuiManager:closeActiveGui(guiName, ...)
	if self.activeGui ~= nil then
		self:closeGui(self.activeGui)
	end
	if guiName ~= nil then
		self:openGuiWithData(guiName, ...)
	end
end

function GuiManager:getGuiIsOpen(guiName)
	return self.activeGui ~= nil and self.activeGui == guiName
end

function GuiManager:closeActiveDialog()
	if self.activeGuiDialog ~= nil then
		self.guis[self.activeGuiDialog].gui:closeGui()
		table.remove(self.activeGuiDialogs, #self.activeGuiDialogs)
		self.activeGuiDialog = nil	
		for _,dialogName in pairs(self.activeGuiDialogs) do
			self.activeGuiDialog = dialogName
		end
	end
end

function GuiManager:getGuiFromName(name)
	return self.guis[name].gui
end

function GuiManager:loadGuiTemplates(xmlFilename, noWarning)
    local showWarnings = not GuiManager.devVersion
	
	local xmlFile = loadXMLFile("Temp", xmlFilename)

	if xmlFile == nil or xmlFile == 0 then		
		print(string.format("Gui can't load templates %s", xmlFilename))			
		return
	end
	
	self.devVersionTemplateFiles[xmlFilename] = xmlFilename
	
	local i = 0
	while true do
		local key = string.format("guiTemplates.colors.color(%d)", i)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local name = getXMLString(xmlFile, string.format("%s#name", key))
		local value = getXMLString(xmlFile, string.format("%s#value", key))
		
		if name == nil or name == "" then			
			print(string.format("Gui template haven't name at %s", key))
			break
		end
		if self.template.colors[name] ~= nil and showWarnings then	
			print(string.format("Gui template colour %s already exist", name))
			break
		end
		
		if value == nil or value == "" then			
			print(string.format("Gui template haven't value at %s", key))
			break
		end
		
		local r,g,b,a = unpack(StringUtil.splitString(" ", value))
		if r == nil or g == nil or b == nil or a == nil then	
			print(string.format("Gui template haven't correct color at %s", key))	
			break
		end
		
		self.template.colors[name] = {tonumber(r), tonumber(g), tonumber(b), tonumber(a)}
		i = i + 1
	end
	
	if hasXMLProperty(xmlFile, "guiTemplates.uvs") then
		i = 0
		while true do
			local key = string.format("guiTemplates.uvs.uv(%d)", i)
			if not hasXMLProperty(xmlFile, key) then
				break
			end
			local name = getXMLString(xmlFile, string.format("%s#name", key))
			local value = getXMLString(xmlFile, string.format("%s#value", key))
			
			if name == nil or name == "" then			
				print(string.format("Gui template haven't name at %s", key))
				break
			end
			if self.template.uvs[name] ~= nil and showWarnings then	
				print(string.format("Gui template uv %s already exist", name))
				break
			end
			
			if value == nil or value == "" then			
				print(string.format("Gui template haven't value at %s", key))
				break
			end
			
			self.template.uvs[name] = value
		i = i + 1
		end
	end
	
	i = 0
	while true do
		local key = string.format("guiTemplates.templates.template(%d)", i)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local name = getXMLString(xmlFile, string.format("%s#name", key))
		local anchor = getXMLString(xmlFile, string.format("%s#anchor", key))
		local extends = getXMLString(xmlFile, string.format("%s#extends", key))
		
		if name == nil or name == "" then			
			print(string.format("Gui template haven't name at %s", key))
			break
		end
		if self.template.templates[name] ~= nil and showWarnings then
			print(string.format("Gui template template %s already exist", name))	
			break
		end
		
		if anchor == nil or anchor == "" then			
			anchor = "middleCenter"
		end
		
		self.template.templates[name] = {}
		self.template.templates[name].anchor = anchor
		self.template.templates[name].values = {}
		self.template.templates[name].extends = {}		
		
		if extends ~= nil and extends ~= "" then
			self.template.templates[name].extends = StringUtil.splitString(" ", extends)
		end
		
		local j = 0
		while true do
			local key = string.format("guiTemplates.templates.template(%d).value(%d)", i, j)
			if not hasXMLProperty(xmlFile, key) then
				break
			end
			
			local nameV = getXMLString(xmlFile, string.format("%s#name", key))
			local valueV = getXMLString(xmlFile, string.format("%s#value", key))
			
			if nameV ~= nil and nameV ~= "" and valueV ~= nil and valueV ~= "" then
				if self.template.templates[name].values[nameV] ~= nil and showWarnings then	
					print(string.format("Gui template template %s already exist", nameV))
					break
				end
				self.template.templates[name].values[nameV] = valueV
			else
				print(string.format("Gui template template error at %s", key))
			end				
			j = j + 1
		end
		i = i + 1
	end
end

function GuiManager:registerUiElements(name, path)
	self.template.uiElements[name] = path
end

function GuiManager:getUiElement(name)
	return self.template.uiElements[name]
end

function GuiManager:getTemplateValueParents(templateName, valueName)
	if self.template.templates[templateName] ~= nil then
		local val
		for _,extend in pairs(self.template.templates[templateName].extends) do
			local rVal = self:getTemplateValue(extend, valueName, nil, true)
			if rVal ~= nil then
				val = rVal
				break
			end
		end
		if val ~= nil then
			return val
		end
		for _,extend in pairs(self.template.templates[templateName].extends) do
			local rVal = self:getTemplateValueParents(extend, valueName, nil)
			if rVal ~= nil then
				val = rVal
				break
			end
		end
		return val
	end
	return nil
end

function GuiManager:getTemplateValue(templateName, valueName, default, ignoreExtends)
	if self.template.templates[templateName] ~= nil then
		if self.template.templates[templateName].values[valueName] ~= nil then
			return self.template.templates[templateName].values[valueName]
		elseif not ignoreExtends then
			local parentV = self:getTemplateValueParents(templateName, valueName)
			if parentV ~= nil then
				return parentV
			else
				return default
			end
		else
			return default
		end
	else
		return default
	end
end

function GuiManager:getTemplateValueBool(templateName, valueName, default)
	local val = self:getTemplateValue(templateName, valueName)
	if val ~= nil then
		return val:lower() == "true"
	end
	return default
end

function GuiManager:getTemplateValueNumber(templateName, valueName, default)
	local val = self:getTemplateValue(templateName, valueName, default)
	if val ~= nil and val ~= "nil" then
		return tonumber(val)
	end
	return default
end

function GuiManager:getTemplateValueColor(templateName, valueName, default)
	local var = self:getTemplateValue(templateName, valueName)
	
	if self.template.colors[var] ~= nil then
		return self.template.colors[var]
	else
		return GuiUtils.getColorArray(var, default)
	end
end

function GuiManager:getTemplateValueUVs(templateName, valueName, imageSize, default)
	local var = self:getTemplateValue(templateName, valueName)
	
	if self.template.uvs[var] ~= nil then
		return GuiUtils.getUVs(self.template.uvs[var], imageSize, default)
	else
		return GuiUtils.getUVs(var, imageSize, default)
	 end
end

function GuiManager:getTemplateValueXML(xmlFile, name, key, default)
	local val = getXMLString(xmlFile, string.format("%s#%s", key, name))	
	if val ~= nil then
		return val
	end
	return default
end

function GuiManager:getTemplateValueNumberXML(xmlFile, name, key, default)
	local val = getXMLString(xmlFile, string.format("%s#%s", key, name))	
	if val ~= nil then
		return tonumber(val)
	end
	return default
end

function GuiManager:getTemplateValueBoolXML(xmlFile, name, key, default)
	local val = getXMLString(xmlFile, string.format("%s#%s", key, name))	
	if val ~= nil then
		return val:lower() == "true"
	end
	return default
end

function GuiManager:getTemplateAnchor(templateName)
	if self.template.templates[templateName] ~= nil then
		return self.template.templates[templateName].anchor
	else
		return "middleCenter"
	end
end

function GuiManager:calcDrawPos(element, index)
	local x,y	
	local anchor = element:getAnchor():lower()
	local isLeft = anchor:find("left")
	local isMiddle = anchor:find("middle")
	local isRight = anchor:find("right")
	local isTop = anchor:find("top")
	local isCenter = anchor:find("center")
	local isBottom = anchor:find("bottom")
	
	if element.parent.name == "flowLayout" then
		if element.parent.orientation == CpGuiFlowLayout.ORIENTATION_X then			
			if element.parent.alignment == CpGuiFlowLayout.ALIGNMENT_LEFT then
				x = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						if i == index then
							break
						else
							x = x + elementF.size[1] + elementF.margin[1] + elementF.margin[3] + elementF.position[1]
						end
					end
				end
				
				x = x + element.parent.drawPosition[1] + element.margin[1] + element.position[1]					
			elseif element.parent.alignment == CpGuiFlowLayout.ALIGNMENT_MIDDLE then			
				local fullSize = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						fullSize = fullSize + elementF.size[1] + elementF.margin[1] + elementF.margin[3] + elementF.position[1]
					end
				end	
				local leftToStart = (element.parent.size[1] - fullSize) / 2
				
				x = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						if i == index then
							break
						else
							x = x + elementF.size[1] + elementF.margin[1] + elementF.margin[3]
						end
					end
				end

				x = x + leftToStart + element.parent.drawPosition[1] + element.margin[1] + element.position[1]			
			elseif element.parent.alignment == CpGuiFlowLayout.ALIGNMENT_RIGHT then			
				x = 0
				local search = true
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						if search then
							if i == index then
								search = false
							end
						else
							x = x + elementF.size[1] + elementF.margin[1] + elementF.margin[3] + elementF.position[1]
						end
					end
				end
				
				x = element.parent.drawPosition[1] + element.parent.size[1] - element.margin[3] - element.size[1] + element.position[1] - x	
			end
			
			if isTop then
				y = element.parent.drawPosition[2] + element.parent.size[2] - element.margin[2] - element.size[2] + element.position[2]
			elseif isCenter then
				y = element.parent.drawPosition[2] + (element.parent.size[2] * 0.5) + element.position[2] - (element.size[2] * 0.5)
			elseif isBottom then
				y = element.parent.drawPosition[2] + element.margin[4] + element.position[2]
			end
		elseif element.parent.orientation == CpGuiFlowLayout.ORIENTATION_Y then		
			if element.parent.alignment == CpGuiFlowLayout.ALIGNMENT_TOP then
				y = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						if i == index then
							break
						else
							if elementF.name == "text" then							
								y = y + elementF:getTextHeight() + elementF.margin[2] + elementF.margin[4] + elementF.position[1]
							else
								y = y + elementF.size[2] + elementF.margin[2] + elementF.margin[4] + elementF.position[1]
							end
						end
					end
				end
				
				y = element.parent.drawPosition[2] + element.parent.size[2] - y - element.size[2] - element.margin[2] + element.position[2]	
			elseif element.parent.alignment == CpGuiFlowLayout.ALIGNMENT_CENTER then
				local fullSize = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						fullSize = fullSize + elementF.size[2] + elementF.margin[2] + elementF.margin[4]
					end
				end	
				local topToStart = (element.parent.size[2] - fullSize) / 2
				
				y = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						if i == index then
							break
						else
							if elementF.name == "text" then							
								y = y + elementF:getTextHeight() + elementF.margin[2] + elementF.margin[4] + elementF.position[1]
							else
								y = y + elementF.size[2] + elementF.margin[2] + elementF.margin[4] + elementF.position[1]
							end
						end
					end
				end
				
				y = element.parent.drawPosition[2] + element.parent.size[2] - topToStart - y - element.size[2] - element.margin[2] + element.position[2]			
			elseif element.parent.alignment == CpGuiFlowLayout.ALIGNMENT_BOTTOM then
				local fullSize = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						fullSize = fullSize + elementF.size[2] + elementF.margin[2] + elementF.margin[4]
					end
				end	
				local topToStart = element.parent.size[2] - fullSize
				
				y = 0
				for i, elementF in pairs(element.parent.elements) do
					if elementF:getVisible() then
						if i == index then
							break
						else
							if elementF.name == "text" then							
								y = y + elementF:getTextHeight() + elementF.margin[2] + elementF.margin[4] + elementF.position[1]
							else
								y = y + elementF.size[2] + elementF.margin[2] + elementF.margin[4] + elementF.position[1]
							end
						end
					end
				end
				
				y = element.parent.drawPosition[2] + element.parent.size[2] - topToStart - y - element.size[2] - element.margin[2] + element.position[2]		
			end
		
			if isLeft then
				x = element.parent.drawPosition[1] + element.margin[1] + element.position[1]
			elseif isMiddle then
				x = element.parent.drawPosition[1] + (element.parent.size[1] * 0.5) + element.position[1]  - (element.size[1] * 0.5)
			elseif isRight then
				x = element.parent.drawPosition[1] + element.parent.size[1] - element.margin[3] - element.size[1] + element.position[1]
			end
		end
	elseif element.parent.name == "table" and element.name ~= "slider" then
		if element.parent.orientation == CpGuiTable.ORIENTATION_X then				
			local xRow = math.floor((index - 1) / element.parent.maxItemsY)
			local yRow = (index - 1) % element.parent.maxItemsY
			
			x = element.parent.drawPosition[1] + xRow * (element.margin[1] + element.size[1] + element.margin[3]) + element.margin[1]
			y = element.parent.drawPosition[2] + element.parent.size[2] - (yRow) * (element.margin[2] + element.size[2] + element.margin[4]) - element.margin[2] - element.size[2]
		elseif element.parent.orientation == CpGuiTable.ORIENTATION_Y then	
			
			local yRow = math.floor((index - 1) / element.parent.maxItemsX)
			local xRow = (index - 1) % element.parent.maxItemsX
			
			x = element.parent.drawPosition[1] + xRow * (element.margin[1] + element.size[1] + element.margin[3]) + element.margin[1]
			y = element.parent.drawPosition[2] + element.parent.size[2] - (yRow) * (element.margin[2] + element.size[2] + element.margin[4]) - element.margin[2] - element.size[2]
			
			
		end
	else
		if isLeft then
			x = element.parent.drawPosition[1] + element.margin[1] + element.position[1]
		elseif isMiddle then
			x = element.parent.drawPosition[1] + (element.parent.size[1] * 0.5) + element.position[1]  - (element.size[1] * 0.5) + element.margin[1]
		elseif isRight then
			x = element.parent.drawPosition[1] + element.parent.size[1] - element.margin[3] - element.size[1] + element.position[1]
		end
		
		if isTop then
			y = element.parent.drawPosition[2] + element.parent.size[2] - element.margin[2] - element.size[2] + element.position[2]
		elseif isCenter then
			y = element.parent.drawPosition[2] + (element.parent.size[2] * 0.5) + element.position[2] - (element.size[2] * 0.5) + element.margin[2]
		elseif isBottom then
			y = element.parent.drawPosition[2] + element.margin[4] + element.position[2]
		end
	end	
	
	if x == nil or y == nil then
		x = 0
		y = 0
	end

	return x,y
end

function GuiManager:getOutputSize()	
	local factor =  1920 / g_screenWidth
	if g_screenWidth / 2 > g_screenHeight then
		factor =  1080 / g_screenHeight
	end
	return {g_screenWidth * factor, g_screenHeight * factor}
end

-- http://alienryderflex.com/polygon/
function GuiManager:checkClickZone(x,y, clickZone, isRound)		
	if isRound then	
		local dx = math.abs(clickZone[1] - x)
		local dy = math.abs(clickZone[2] - y)	
		return math.sqrt(dx*dx + dy*dy) <= clickZone[3]		
	else	
		local polyX = {}
		local polyY = {}
		
		local num = table.getn(clickZone)
		
		for i=1, num do
			if i % 2 == 0 then
				table.insert(polyY, clickZone[i])
			else
				table.insert(polyX, clickZone[i])
			end
		end
		
		num = num / 2
		
		local j = num
		local insert = false
		
		for i=1, num do
			if polyY[i]< y and polyY[j]>=y or polyY[j]< y and polyY[i]>=y then
				if polyX[i] + (y-polyY[i]) / (polyY[j]-polyY[i])*(polyX[j]-polyX[i]) < x then
					insert = not insert
				end
			end
			j=i
		end		
		return insert
	end
end

function GuiManager:checkClickZoneNormal(x,y, drawX, drawY, sX, sY)
	return x > drawX and y > drawY and x < drawX + sX and y < drawY + sY
end

function GuiManager:handleInputMainGui(rightClick)
	-- TODO: Add Key setting

	if not self.smallGuis["cp_main"] then
		courseplay.guiManager:openGui("cp_main", true)
	end

	--if rightClick then

	--end
end

function GuiManager:onEnterVehicle()
	if self.guiStates["cp_main"] then
		courseplay.guiManager:openGui("cp_main", true)
	end

end

function GuiManager:onLeaveVehicle()
	if self.smallGuis["cp_main"] then
		courseplay.guiManager:closeGui("cp_main")
	end

end

function GuiManager:onCloseCpMainGui()
	courseplay.guiManager:closeGui("cp_main")
	self.guiStates["cp_main"] = false
end