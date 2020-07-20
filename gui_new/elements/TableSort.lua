-- 
-- CoursePlay - Gui - TableSort
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

CpGuiTableSort = {}
local CpGuiTableSort_mt = Class(CpGuiTableSort, CpGuiElement)

function CpGuiTableSort:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiTableSort_mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "tableSort"
	
	self.sortDirection = 1
	
	return self
end

function CpGuiTableSort:loadTemplate(templateName, xmlFile, key)
	CpGuiTableSort:superClass().loadTemplate(self, templateName, xmlFile, key)
  
    self.buttonElement = CpGuiButton:new(self.gui)
	self.buttonElement:loadTemplate(string.format("%s_button", templateName), xmlFile, key)
    self:addElement(self.buttonElement)
    
    self.overlayElement = CpGuiOverlay:new(self.gui)
    self.overlayElement:loadTemplate(string.format("%s_overlay", templateName), xmlFile, key)
	self:addElement(self.overlayElement)
	
	self.size = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValueXML(xmlFile, "tableSortSize", key), self.outputSize, self.size)
	self.buttonElement.size = self.size
	self.buttonElement.overlayElement.size = self.size
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self)
	end
	self:loadOnCreate()
end

function CpGuiTableSort:copy(src)
	CpGuiTableSort:superClass().copy(self, src)
	
	self:copyOnCreate()
end

function CpGuiTableSort:delete()
	CpGuiTableSort:superClass().delete(self)
end

function CpGuiTableSort:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	CpGuiTableSort:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiTableSort:keyEvent(unicode, sym, modifier, isDown, eventUsed)   
	CpGuiTableSort:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiTableSort:update(dt)
    CpGuiTableSort:superClass().update(self, dt)
end

function CpGuiTableSort:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)	
	
	CpGuiTableSort:superClass().draw(self)
end

function CpGuiTableSort:changeSortDirection()
	self.sortDirection = self.sortDirection * -1
	self:setSortIcon()
end

function CpGuiTableSort:setSortDirection(sortDirection)
	self.sortDirection = sortDirection
	self:setSortIcon()
end

function CpGuiTableSort:setSortIcon()	
	if self.sortDirection == 1 then
		self.overlayElement:setRotation(math.rad(0))
	else
		self.overlayElement:setRotation(math.rad(180))
	end
end

function CpGuiTableSort:sortTable(tableC)
	local needSort = {}
	for k,element in pairs(tableC.items) do
		table.insert(needSort, element.sortName)
	end
	table.sort(needSort, function(a, b) return a:lower() < b:lower() end)

	local newItems = {}

	for _,sortName in pairs(needSort) do
		local toDelete
		for k,oE in pairs(tableC.items) do
			if sortName == oE.sortName then
				table.insert(newItems, oE)
				toDelete = k
				break
			end
		end
		table.remove(tableC.items, toDelete)
	end
	tableC.items = newItems
	
	if self.sortDirection == -1 then
		local i, j = 1, table.getn(tableC.items)
		while i < j do
			tableC.items[i], tableC.items[j] = tableC.items[j], tableC.items[i]
			i = i + 1
			j = j - 1
		end
	end
end