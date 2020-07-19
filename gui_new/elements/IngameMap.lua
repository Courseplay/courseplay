-- 
-- CoursePlay - Gui - IngameMap
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

CpGuiIngameMap = {}
CpGuiIngameMap._mt = Class(CpGuiIngameMap, CpGuiElement)

function CpGuiIngameMap:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiIngameMap._mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "ingameMap"
	
	self.zoomFactor = 8
	self.lastPxPosX = 0
	self.lastPxPosY = 0
	self.lastPxPosY = 0

	self.bitmaps = {}
	self.pdaMarkerCount = -1
	self.pdaMarkers = {}

	self.pdaWith = 2048
	if fileExists(g_currentMission.missionInfo.baseDirectory.."modDesc.xml") then
		local path = g_currentMission.missionInfo.baseDirectory .. g_currentMission.missionInfo.mapXMLFilename
		if fileExists(path) then
			local xml = loadXMLFile("map",path,"map")
			self.pdaWith = getXMLInt(xml, "map#width")
			delete(xml)
		end
	end

	self.lastSize = self.zoomFactor * 128
	self.sizeFactor = self.pdaWith / 2048
	
	return self
end

function CpGuiIngameMap:loadTemplate(templateName, xmlFile, key)
	CpGuiIngameMap:superClass().loadTemplate(self, templateName, xmlFile, key)
    
    self.overlayElement = CpGuiOverlay:new(self.gui)
    self.overlayElement:loadTemplate(string.format("%s_overlay", templateName), xmlFile, key)
    self.overlayElement:setImageFilename(g_currentMission.mapImageFilename)
    self:addElement(self.overlayElement)
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self)
	end
	self:loadOnCreate()
end

function CpGuiIngameMap:copy(src)
	CpGuiIngameMap:superClass().copy(self, src)	

	self:copyOnCreate()
end

function CpGuiIngameMap:delete()
	CpGuiIngameMap:superClass().delete(self)
end

function CpGuiIngameMap:onOpen()
	
end

function CpGuiIngameMap:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if not self:getDisabled() then
		eventUsed = CpGuiIngameMap:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
				
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

					if self.callback_onEnter ~= nil then
						self.gui[self.callback_onEnter](self.gui, self, self.parameter)
					end
				end
				
				if isDown and button == Input.MOUSE_BUTTON_WHEEL_UP then
                    self:zoom(-1, posX, posY)
                    eventUsed = true
                end
                if isDown and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
                    self:zoom(1, posX, posY)
                    eventUsed = true
				end
				
                if isDown and button == Input.MOUSE_BUTTON_LEFT then
                    eventUsed = true
                    if not self.mouseDown then
                        self.mouseDown = true
                        self.lastMousePosX = posX
                        self.lastMousePosY = posY
                    end
                end
                if isUp and button == Input.MOUSE_BUTTON_LEFT then
                    self.mouseDown = false
                end

                if self.mouseDown then
					self:move(posX, posY)					
                    self.lastMousePosX = posX
                    self.lastMousePosY = posY
				end
			else
				if self.mouseEntered then
					self.mouseDown = false
					self.mouseEntered = false					
					if self.callback_onLeave ~= nil then
						self.gui[self.callback_onLeave](self.gui, self, self.parameter)
					end
				end
			end
		end
	end
	return eventUsed
end

function CpGuiIngameMap:keyEvent(unicode, sym, modifier, isDown, eventUsed)   
	CpGuiIngameMap:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiIngameMap:update(dt)
    CpGuiIngameMap:superClass().update(self, dt)
end

function CpGuiIngameMap:zoom(value, posX, posY)
	local oldZoom = self.zoomFactor
	self.zoomFactor = self.zoomFactor + value

	if self.zoomFactor < 1 or self.zoomFactor > 8 then
		self.zoomFactor = oldZoom
	end

	if self.zoomFactor == oldZoom then 
		return
	end	

	local factorX = (posX - self.drawPosition[1]) / self.size[1]
	local factorY = 1 - (posY - self.drawPosition[2]) / self.size[2]

	self.lastPxPosX = math.ceil(self.lastPxPosX + 128 * factorX * value * -1)
	self.lastPxPosY = math.ceil(self.lastPxPosY + 128 * factorY * value * -1)

	self.lastSize = self.zoomFactor * 128

	self.lastPxPosX = self:checkEdges(self.lastPxPosX)
	self.lastPxPosY = self:checkEdges(self.lastPxPosY)
	
	self.overlayElement:setUV(string.format("%spx %spx %spx %spx", self.lastPxPosX, self.lastPxPosY, self.lastSize, self.lastSize))
	self:checkPdaMarkers()
end

function CpGuiIngameMap:checkEdges(lastPos)
	if lastPos < 0 then
		return 0
	elseif lastPos + self.lastSize > 1024 then
		return lastPos - ((lastPos + self.lastSize) - 1024)
	end
	return lastPos
end

function CpGuiIngameMap:move(posX, posY)
	self.lastPxPosX = self.lastPxPosX + ((self.lastMousePosX - posX) / self.size[1] * self.lastSize)
	self.lastPxPosY = self.lastPxPosY + ((posY - self.lastMousePosY) / self.size[2] * self.lastSize)

	self.lastPxPosX = self:checkEdges(self.lastPxPosX)
	self.lastPxPosY = self:checkEdges(self.lastPxPosY)

	self.overlayElement:setUV(string.format("%spx %spx %spx %spx", self.lastPxPosX, self.lastPxPosY, self.lastSize, self.lastSize))
	self:checkPdaMarkers()
end

function CpGuiIngameMap:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)	
	
	CpGuiIngameMap:superClass().draw(self)
end

function CpGuiIngameMap:addPdaMarker(element)
	self.pdaMarkerCount = self.pdaMarkerCount + 1
	table.insert(self.pdaMarkers, {id = self.pdaMarkerCount, element = element, posX = 0, posY = 0, worldPosX = 0, worldPosY = 0, size = element.size})
	return self.pdaMarkerCount
end

function CpGuiIngameMap:setPdaMarkerPosition(id, x, y)
	for _,marker in pairs(self.pdaMarkers) do
		if marker.id == id then
			marker.worldPosX = x / self.sizeFactor
			marker.worldPosY = y / self.sizeFactor
		end
	end
	self:checkPdaMarkers()
end

function CpGuiIngameMap:checkPdaMarkers()	
	for _,marker in pairs(self.pdaMarkers) do
		local sizeH = marker.size[1] / 2
		
		local pdaPosX = (marker.worldPosX + self.pdaWith / 2 / self.sizeFactor) / 2
		local pdaPosY = (marker.worldPosY + self.pdaWith / 2 / self.sizeFactor) / 2
		
		if self.lastPxPosX < pdaPosX and pdaPosX < (self.lastPxPosX + self.lastSize) and self.lastPxPosY < pdaPosY and pdaPosY < (self.lastPxPosY + self.lastSize)  then

			local posX = (880 / self.lastSize * (pdaPosX - self.lastPxPosX)) - 440
			local posY = 440 - (880 / self.lastSize * (pdaPosY - self.lastPxPosY))

			marker.element.position = GuiUtils.getNormalizedValues(string.format("%spx %spx", posX, posY), marker.element.outputSize, marker.element.position)
			marker.element:setVisible(true)
		else
			marker.element:setVisible(false)
		end
	end
end