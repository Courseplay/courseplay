-- 
-- CoursePlay - Gui - Slider
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

CpGuiSlider = {}
local CpGuiSlider_mt = Class(CpGuiSlider, CpGuiElement)

function CpGuiSlider:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiSlider_mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "slider"

	self.minHeight = GuiUtils.getNormalizedValues("20px", self.outputSize)	
	return self
end

function CpGuiSlider:loadTemplate(templateName, xmlFile, key, overlayName)
	CpGuiSlider:superClass().loadTemplate(self, templateName, xmlFile, key)	
	
	self.buttonElement = CpGuiButton:new(self.gui)
	self.buttonElement:loadTemplate(templateName, xmlFile, key)

	self:addElement(self.buttonElement)
	
	self:loadOnCreate()
end

function CpGuiSlider:copy(src)
	CpGuiSlider:superClass().copy(self, src)
	self:copyOnCreate()
end

function CpGuiSlider:delete()
	CpGuiSlider:superClass().delete(self)	
end

function CpGuiSlider:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)	
	if not self:getDisabled() then
		eventUsed = CpGuiSlider:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
	end
	return eventUsed
end

function CpGuiSlider:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiSlider:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiSlider:update(dt)
	CpGuiSlider:superClass().update(self, dt)
end

function CpGuiSlider:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)
	CpGuiSlider:superClass().draw(self,index)
end

function CpGuiSlider:setController(table)
	self.controller = table
	self:updateItems()
end

function CpGuiSlider:setPosition(pos)	
	if self.stepsize ~= nil then
		self.buttonElement.sliderPosition[2] = self.stepsize * pos
	end
end

function CpGuiSlider:moveSlider(x, y)
	self.buttonElement.sliderPosition[2] = math.min(math.max(self.buttonElement.sliderPosition[2] + y, 0), self.size[2] - self.buttonElement.size[2])	
	self.controller:setPosition(math.floor(self.buttonElement.sliderPosition[2] / self.stepsize))
end

function CpGuiSlider:updateItems()
	if self.controller ~= nil then
		if #self.controller.items <= self.controller.maxItemsX * self.controller.maxItemsY then
			self:setVisible(false)
		else
			self:setVisible(true)
			--self.stepsize = self.size[2] / ( 1 + (#self.controller.items - (self.controller.maxItemsX * self.controller.maxItemsY))) --set correct direction!
			if self.controller.maxItemsX > 1 then
				self.stepsize = self.size[2] / math.ceil( 1 + (math.ceil(#self.controller.items / self.controller.maxItemsX) / (self.controller.maxItemsY)))
			else
				self.stepsize = self.size[2] / ( 1 + (#self.controller.items - self.controller.maxItemsY))
			end 
			local size = math.max(self.stepsize, self.minHeight[1])
			self.buttonElement.size[2] = size
			if self.buttonElement.overlayElement ~= nil then
				self.buttonElement.overlayElement.size[2] = size
			end
		end
	end
end