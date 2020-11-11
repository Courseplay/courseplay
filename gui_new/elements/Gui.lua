-- 
-- CoursePlay - Gui
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

CpGui = {}
local CpGui_mt = Class(CpGui)

function CpGui:new(name)	
	local self = setmetatable({}, CpGui_mt)
	self.name = name
	self.rootElement = CpGuiElement:new()
	
	return self
end

function CpGui:assignClass(class)
	if self.classGui == nil then
		self.classGui = class
	end
end

function CpGui:setData( ... )
	if self.classGui ~= nil then
		self.classGui:setData(...)
	end
end

function CpGui:loadFromXML()
	if self.classGui.xmlFilename == nil then
		print(string.format("Gui %s haven't xmlFilename", self.name))
		return
	end	
	local xmlFile = loadXMLFile("Temp", self.classGui.xmlFilename)

	if xmlFile == nil or xmlFile == 0 then		
		print(string.format("Gui can't load xml %s", self.classGui.xmlFilename))
		return
	end

	self.classGui.rootElement = self.rootElement
	self:loadFromXMLRec(xmlFile, "GUI", self.rootElement)
	self.classGui:onCreate()
	delete(xmlFile)
end

function CpGui:loadFromXMLRec(xmlFile, key, actGui)
	local i = 0
	while true do
		local k = string.format("%s.GuiElement(%d)", key, i)
		if not hasXMLProperty(xmlFile, k) then
			break
		end
		
		local t = getXMLString(xmlFile, string.format("%s#type", k))		
		local id = getXMLString(xmlFile, string.format("%s#id", k))		
		local templateName = getXMLString(xmlFile, string.format("%s#template", k))			
		local guiElement = nil
		
		if t == "text" then
			guiElement = CpGuiText:new(self.classGui)
		elseif t == "image" then
			guiElement = CpGuiOverlay:new(self.classGui)
		elseif t == "flowLayout" then
			guiElement = CpGuiFlowLayout:new(self.classGui)
		elseif t == "button" then
			guiElement = CpGuiButton:new(self.classGui)
		elseif t == "table" then
			guiElement = CpGuiTable:new(self.classGui)
		elseif t == "input" then
			guiElement = CpGuiInput:new(self.classGui)
		elseif t == "page" then
			guiElement = CpGuiPage:new(self.classGui)
		elseif t == "pageSelector" then
			guiElement = CpGuiPageSelector:new(self.classGui)
		elseif t == "ingameMap" then
			guiElement = CpGuiIngameMap:new(self.classGui)
		elseif t == "tableSort" then
			guiElement = CpGuiTableSort:new(self.classGui)
		elseif t == "guiMover" then
			guiElement = CpGuiMover:new(self.classGui)
		elseif t == "pageLoad" then
			guiElement = CpGuiPage:new(self.classGui, self)
		else
			guiElement = CpGuiElement:new(self.classGui, nil, true)
		end
		guiElement.id = id
		
		guiElement:setParent(actGui)
		guiElement:loadTemplate(templateName, xmlFile, k)
		actGui:addElement(guiElement)
		
		if id ~= nil and id ~= "" then
			self.classGui[id] = guiElement
		end
		
		self:loadFromXMLRec(xmlFile, k, guiElement)
		i = i + 1
	end
end

function CpGui:delete()

end

function CpGui:deleteElements()
	for _,element in pairs(self.rootElement.elements) do
		element:delete()
	end
	self.rootElement.elements = {}
end

function CpGui:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if self.classGui.mouseEvent ~= nil then
		self.classGui:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	end
	self.rootElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
end

function CpGui:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	if self.classGui.keyEvent ~= nil then
		self.classGui:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	end
	self.rootElement:keyEvent(unicode, sym, modifier, isDown, eventUsed)
end

function CpGui:update(dt)
	if self.classGui.update ~= nil then
		self.classGui:update(dt)
	end
	self.rootElement:update(dt)
end

function CpGui:draw()
	self.rootElement:draw()
	if self.classGui.draw ~= nil then
		self.classGui:draw()
	end
end

function CpGui:openGui()
	if self.classGui.onOpen ~= nil then
		self.classGui:onOpen()
	end
	self.rootElement:onOpen()
end

function CpGui:closeGui()
	if self.classGui.onClose ~= nil then
		self.classGui:onClose()
	end
end