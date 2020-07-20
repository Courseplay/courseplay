-- 
-- CoursePlay - Gui - Mover
-- 
-- @Interface: 1.6.0.0 b9166
-- @Author: LS-Modcompany / kevink98
-- @Date: 20.07.2020
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

CpGuiMover = {}
local CpGuiMover_mt = Class(CpGuiMover, CpGuiElement)

function CpGuiMover:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiMover_mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "mover"
	
	self.mouseDown = false
	self.mouseEntered = false
    
    
	return self
end

function CpGuiMover:loadTemplate(templateName, xmlFile, key)
	CpGuiMover:superClass().loadTemplate(self, templateName, xmlFile, key)
	
    
    
	self:loadOnCreate()
end

function CpGuiMover:copy(src)
	CpGuiMover:superClass().copy(self, src)
	
    
    
	self:copyOnCreate()
end

function CpGuiMover:delete()
	CpGuiMover:superClass().delete(self)
end

function CpGuiMover:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    eventUsed = CpGuiMover:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
    
    if not eventUsed then
		local clickZone = {}		
        clickZone[1] = self.drawPosition[1]
        clickZone[2] = self.drawPosition[2] + self.size[2]
        clickZone[3] = self.drawPosition[1] + self.size[1]
        clickZone[4] = self.drawPosition[2] + self.size[2]
        clickZone[5] = self.drawPosition[1] + self.size[1]
        clickZone[6] = self.drawPosition[2]
        clickZone[7] = self.drawPosition[1]
        clickZone[8] = self.drawPosition[2]
			
        if courseplay.guiManager:checkClickZone(posX, posY, clickZone, self.isRoundButton) then
            if not self.mouseEntered then
                self.mouseEntered = true		
                eventUsed = true
                self.lastPos = {posX, posY}
            end
            
            if isDown and button == Input.MOUSE_BUTTON_LEFT then
                self.mouseDown = true
                eventUsed = true
            end
            
            if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
                self.mouseDown = false
                self.mouseEntered = false
            end
        end

        if self.mouseEntered and self.mouseDown then
            self.gui.rootElement.elements[1].position[1] = self.gui.rootElement.elements[1].position[1] - (self.lastPos[1] - posX)
            self.gui.rootElement.elements[1].position[2] = self.gui.rootElement.elements[1].position[2] - (self.lastPos[2] - posY)
            eventUsed = true
        end

        self.lastPos = {posX, posY}
    end
	return eventUsed
end

function CpGuiMover:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiMover:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiMover:update(dt)
	CpGuiMover:superClass().update(self, dt)
end

function CpGuiMover:draw(index)			
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)	
	CpGuiMover:superClass().draw(self,index)
end

function CpGuiMover:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	CpGuiMover:superClass().onOpen(self)
end