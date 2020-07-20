-- 
-- CoursePlay - Gui - Table
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

CpGuiTable = {}
local CpGuiTable_mt = Class(CpGuiTable, CpGuiElement)

CpGuiTable.ORIENTATION_X = 1
CpGuiTable.ORIENTATION_Y = 2

CpGuiTable.TYP_TABLE = 1
CpGuiTable.TYP_LIST = 2

function CpGuiTable:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiTable_mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "table"
	
	self.items = {}
	self.itemTemplate = nil
	self.orientation = CpGuiTable.ORIENTATION_X
	self.type = CpGuiTable.TYP_TABLE
	
	self.itemWidth = 0.1
	self.itemHeight = 0.1
	self.itemMargin = {0,0,0,0}
	
	self.maxItemsX = 5
	self.maxItemsY = 1
	
	self.scrollCount = 0
	self.selectRow = 0
	
	return self
end

function CpGuiTable:loadTemplate(templateName, xmlFile, key, overlayName)
	CpGuiTable:superClass().loadTemplate(self, templateName, xmlFile, key)	
	
	self.itemWidth = unpack(GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "itemWidth"), {self.outputSize[1]}, {self.itemWidth}))
	self.itemHeight = unpack(GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "itemHeight"), {self.outputSize[2]}, {self.itemHeight}))
	self.itemMargin = GuiUtils.getNormalizedValues(courseplay.guiManager:getTemplateValue(templateName, "itemMargin"), self.outputSize, self.itemMargin)
	
	self.maxItemsX = courseplay.guiManager:getTemplateValueNumber(templateName, "maxItemsX", self.maxItemsX)
	self.maxItemsY = courseplay.guiManager:getTemplateValueNumber(templateName, "maxItemsY", self.maxItemsY)

	self.hasSlider = courseplay.guiManager:getTemplateValueBool(templateName, "hasSlider", false)	
	
	local orientation = courseplay.guiManager:getTemplateValue(templateName, "orientation")	

	if orientation == "x" then
		self.orientation = CpGuiTable.ORIENTATION_X
	elseif orientation == "y" then
		self.orientation = CpGuiTable.ORIENTATION_Y
	end
	if self.maxItemsX == 1 then
		self.typ = CpGuiTable.TYP_TABLE
	else
		self.typ = CpGuiTable.TYP_LIST
	end

	if self.hasSlider then
		self.slider = CpGuiSlider:new()
		self.slider:loadTemplate(string.format( "%s_slider",templateName), xmlFile, key)
		self.slider.parent = self
		--self:addElement(self.slider)
		if self.id ~= nil then
			self.gui[string.format("%s_slider",self.id)] = self.slider
		end
		self.slider:setController(self)
	end

	self:loadOnCreate()
end

function CpGuiTable:copy(src)
	CpGuiTable:superClass().copy(self, src)
	
	self.itemWidth = src.itemWidth
	self.itemHeight = src.itemHeight
	self.itemMargin = src.itemMargin
	
	self.maxItemsX = src.maxItemsX
	self.maxItemsY = src.maxItemsY

	self.hasSlider = src.hasSlider
	
	self.orientation = src.orientation
	self:copyOnCreate()
end

function CpGuiTable:delete()
	CpGuiTable:superClass().delete(self)
	
end

function CpGuiTable:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)	
	if not self:getDisabled() then
		eventUsed = CpGuiTable:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
	
		if not eventUsed and courseplay.guiManager:checkClickZoneNormal(posX, posY, self.drawPosition[1], self.drawPosition[2], self.size[1], self.size[2]) then
			if isDown then
				if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
					eventUsed = true
					self:scrollTable(-1)
					if self.hasSlider then
						self.slider:setPosition(self.scrollCount)
					end
				elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
					eventUsed = true
					self:scrollTable(1)
					if self.hasSlider then
						self.slider:setPosition(self.scrollCount)
					end
				end
			end		
		end

		if not eventUsed and self.slider ~= nil then
			self.slider:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
		end
	end
	return eventUsed
end

function CpGuiTable:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiTable:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
	if self.slider ~= nil then
		self.slider:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	end
end

function CpGuiTable:update(dt)
	CpGuiTable:superClass().update(self, dt)
	if self.slider ~= nil then
		self.slider:update(dt)
	end
end

function CpGuiTable:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)
	if self.slider ~= nil then
		self.slider:draw(index)
	end
	CpGuiTable:superClass().draw(self,index)
end

function CpGuiTable:setTableTemplate(element)
	self.itemTemplate = element
	self:removeElement(element)
end

function CpGuiTable:addElement(element)
	if not element.isTableTemplate then
		if element.parent ~= nil then
			element.parent:removeElement(element)
		end
		element:setParent(self)
		table.insert(self.items, element)
		self:updateVisibleItems()
	end
end

function CpGuiTable:removeElements()
	for _,element in pairs(self.elements) do
		element.parent = nil
		element:delete()
	end
	self.items = {}
	self.elements = {}
end

function CpGuiTable:updateVisibleItems()	
	self.elements = {}
	
	local start
	if self.orientation == CpGuiTable.ORIENTATION_X then
		start = self.scrollCount * self.maxItemsY + 1
	elseif self.orientation == CpGuiTable.ORIENTATION_Y then
		start = self.scrollCount * self.maxItemsX + 1
	end
	local maxNum = self.maxItemsX * self.maxItemsY
	
	for k,element in pairs(self.items) do
		if k >= start and k < start + maxNum then
			table.insert(self.elements, element)
		end
		if k >= maxNum + start then
			break
		end
	end
	if self.hasSlider then
		self.slider:updateItems()
	end
end

function CpGuiTable:setPosition(pos)
	if self.scrollCount ~= pos then
		self.scrollCount = pos
		self:scrollItems()
	end
end

function CpGuiTable:scrollTable(num)
	if num == nil then
		self.scrollCount = 0
	else
		self.scrollCount = self.scrollCount + num			
	end
	self:scrollItems()
	self:updateVisibleItems()
end

function CpGuiTable:scrollItems()
	local m,s,e
	if self.orientation == CpGuiTable.ORIENTATION_X then
		m = self.maxItemsY
	elseif self.orientation == CpGuiTable.ORIENTATION_Y then
		m = self.maxItemsX
	end			
	self:updateVisibleItems() --#Pfusch am Mod
	if self.maxItemsY*self.maxItemsX - table.getn(self.elements) >= m then
		self.scrollCount = self.scrollCount - 1
	end
	
	if self.scrollCount < 0 then
		self.scrollCount = 0
	end
end

function CpGuiTable:setActive(state, e)
	for _,element in pairs(self.items) do
		if e ~= element then
			element:setActive(state)
		end
	end
end

function CpGuiTable:setSelected(state, e)	
	if state == nil then
		state = false
	end
	for _,element in pairs(self.items) do
		if e ~= element then
			element:setSelected(state, true)
		end
	end
end

function CpGuiTable:createItem()
	if self.itemTemplate ~= nil then
		local item = CpGuiButton:new(self.gui)
		self:addElement(item)
		item:copy(self.itemTemplate)
		for _,element in pairs(self.itemTemplate.elements) do		
			self:createItemRec(self, element, item)
		end
		
		return item
	end
	return nil
end

function CpGuiTable:createItemRec(t, element, parent)
	local item = element:new(t.gui)
	parent:addElement(item)
	item:copy(element)
	for _,e in pairs(element.elements) do		
		t:createItemRec(t, e, item)
	end
end

function CpGuiTable:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	CpGuiTable:superClass().onOpen(self)
end

function CpGuiTable:selectFirstItem()
	self:scrollTable()
	for k,element in pairs(self.items) do
			element:setActive(true)
			if element.callback_onClick ~= nil then
				element.gui[element.callback_onClick](element.gui, element, element.parameter)
			end
		break
	end
end