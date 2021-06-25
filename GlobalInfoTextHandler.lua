--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 courseplay dev team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
	The global info texts handler controls all info texts at the left side of the screen relative to the vehicles. 
	It enables quick vehicle swapping by pressing the button which has an info texts by the vehicle.
]]--


---@class GlobalInfoTextHandler
GlobalInfoTextHandler = CpObject()

GlobalInfoTextHandler.attributes = {
    {name = 'level', getXmlFunction = getXMLInt},
    {name = 'text', getXmlFunction = getXMLString},
}

function GlobalInfoTextHandler:init()
	self.playerOnFootMouseEnabled = false;
	self.wasPlayerFrozen = false;
	self.infoTexts = {}
	self.vehicles = {}
end

--- Load the info text xml File.
function GlobalInfoTextHandler:loadFromXml()
	self.xmlFileName = Utils.getFilename('config/InfoTexts.xml', courseplay.path)
    self.xmlFile = self:loadXmlFile(self.xmlFileName)
end

--- Loads the info texts.
---@param fileName string
function GlobalInfoTextHandler:loadXmlFile(fileName)
    courseplay.info('Loading Info texts from %s ...', fileName)
    if fileExists(fileName) then
        local xmlFile = loadXMLFile('infoTexts', fileName);
        local rootElement = 'InfoTexts'
        if xmlFile and hasXMLProperty(xmlFile, rootElement) then
            local i = 0
            while true do
                local infoTextElement = string.format('%s.InfoText(%d)', rootElement, i)
                if hasXMLProperty(xmlFile, infoTextElement) then
                    self:loadInfoText(xmlFile, infoTextElement)
                else
                    break
                end
                i = i + 1
            end
            return xmlFile
        end
    else
        courseplay.info('Info text file %s does not exist.', fileName)
    end
end

--- Load a single info text.
---@param xmlFile number id of the loaded xml file.
---@param infoTextElement string xml key to the info text element.
function GlobalInfoTextHandler:loadInfoText(xmlFile, infoTextElement)
	local infoText = {}
	local name = getXMLString(xmlFile,string.format("%s#name",infoTextElement))
	for _,attribute in pairs(self.attributes) do 
		infoText[attribute.name] = attribute.getXmlFunction(xmlFile,string.format("%s#%s",infoTextElement,attribute.name)) 
	end
	self.infoTexts[name] = infoText
end

--- Setup all the basic global info text information.
--- Needs to be done after the hud is initialized.
function GlobalInfoTextHandler:setup() 
	--- Load info texts
	self:loadFromXml()
	
	--- All visual/button variables
	self.posY = 0.01238; -- = ingameMap posY
	self.posYAboveMap = self.posY + 0.027777777777778 + 0.20833333333333;
	self.fontSize = courseplay.hud:pxToNormal(18, 'y');
	self.lineHeight = self.fontSize * 1.2;
	self.lineMargin = self.lineHeight * 0.2;
	self.buttonHeight = self.lineHeight;
	self.buttonWidth = self.buttonHeight / g_screenAspectRatio;
	self.buttonPosX = 0.015625; -- = ingameMap posX
	self.buttonMargin = self.buttonWidth * 0.4;
	self.backgroundPadding = self.buttonWidth * 0.2;
	self.backgroundImg = 'dataS2/menu/white.png';
	self.backgroundPosX = self.buttonPosX + self.buttonWidth + self.buttonMargin;
	self.backgroundPosY = self.posY;
	self.textPosX = self.backgroundPosX + self.backgroundPadding;
	self.content = {};
	self.vehicleHasText = {};
	self.levelColors = {
		[-2] = courseplay.hud.colors.closeRed;
		[-1] = courseplay.hud.colors.activeRed;
		[0]  = courseplay.hud.colors.hover;
		[1]  = courseplay.hud.colors.activeGreen;
	};

	self.maxNum = 20;
	self.overlays = {};
	self.buttons = {};
	for i=1, self.maxNum do
		local posY = self.backgroundPosY + (i - 1) * self.lineHeight;
		self.overlays[i] = Overlay:new(self.backgroundImg, self.backgroundPosX, posY, 0.1, self.buttonHeight);
		courseplay.button:new(self, 'globalInfoText', 'iconSprite.png', 'goToVehicle', i, self.buttonPosX, posY, self.buttonWidth, self.buttonHeight);
	end;
	self.buttonsClickArea = {
		x1 = self.buttonPosX;
		x2 = self.buttonPosX + self.buttonWidth;
		y1 = self.backgroundPosY,
		y2 = self.backgroundPosY + (self.maxNum * (self.lineHeight + self.lineMargin));
	};
	self.hasContent = false;
end

--- TODO: Find a better solution then to saves these in the vehicle.
--- Adds a new vehicle.
---@param vehicle table
function GlobalInfoTextHandler:addVehicle(vehicle)
	self.vehicles[vehicle] = {
		currentInfoTexts = {},
		lastInfoTexts = {}
	}
end

--- Removes a vehicle.
---@param vehicle table
function GlobalInfoTextHandler:removeVehicle(vehicle)
	self:resetAllInfoTextsForVehicle(vehicle)
	self.vehicles[vehicle] = nil
end


--- Reset all not used info texts at the end of the vehicle update loop.
---@param vehicle table
function GlobalInfoTextHandler:resetInactiveInfoTextsForVehicle(vehicle)
	for refIdx,_ in pairs(self.infoTexts) do
		if not self.vehicles[vehicle].currentInfoTexts[refIdx] then 
			if self.vehicles[vehicle].lastInfoTexts[refIdx] then 
				self:resetInfoText(vehicle,refIdx)
			end
		end
	end
	self.vehicles[vehicle].lastInfoTexts = self.vehicles[vehicle].currentInfoTexts
	self.vehicles[vehicle].currentInfoTexts = {}
end

--- Completely resets all info texts related to the vehicle.
---@param vehicle table
function GlobalInfoTextHandler:resetAllInfoTextsForVehicle(vehicle)
	for refIdx,_ in pairs(self.infoTexts) do
		if self.vehicles[vehicle].currentInfoTexts[refIdx] 
			or self.vehicles[vehicle].lastInfoTexts[refIdx] then
			self:resetInfoText(vehicle,refIdx)
		end
	end
end

--- Sets a global info text for the given vehicle.
---@param vehicle table
---@param refIdx string index for the info text.
function GlobalInfoTextHandler:setInfoText(vehicle, refIdx)

	local data = self.infoTexts[refIdx]
	if self.vehicles[vehicle].currentInfoTexts[refIdx] == nil or self.vehicles[vehicle].currentInfoTexts[refIdx] ~= data.level then
		if g_server ~= nil then
			InfoTextEvent.sendEvent(vehicle,refIdx,false)
		end	

		local text = nameNum(vehicle) .. " " .. courseplay:loc(data.text);

		self.vehicles[vehicle].currentInfoTexts[refIdx] = data.level;

		if self.content[vehicle.rootNode] == nil then
			self.content[vehicle.rootNode] = {};
		end;
		self.content[vehicle.rootNode][refIdx] = {
			level = data.level,
			text = text,
			backgroundWidth = getTextWidth(self.fontSize, text) + self.backgroundPadding * 2.5,
			vehicle = vehicle
		};
	end;
end

--- Resets a global info text for the given vehicle.
---@param vehicle table
---@param refIdx string index for the info text.
function GlobalInfoTextHandler:resetInfoText(vehicle, refIdx)

	if g_server ~= nil then
		InfoTextEvent.sendEvent(vehicle,refIdx,true)
	end
	if self.content[vehicle.rootNode] and  self.content[vehicle.rootNode][refIdx] then
		self.content[vehicle.rootNode][refIdx] = nil;
	end;
	self.vehicles[vehicle][refIdx] = nil
	if #self.vehicles[vehicle].currentInfoTexts == 0 then
		self.content[vehicle.rootNode] = nil;
	end;
end


--- Renders the info texts buttons.
function GlobalInfoTextHandler:render()
	self.hasContent = false;
	local numLinesRendered = 0;
	local basePosY = self.posY;
	if not (g_currentMission.hud.ingameMap.isVisible and g_currentMission.hud.ingameMap:getIsFullSize()) and next(self.content) ~= nil then
		self.hasContent = true;
		if g_currentMission.hud.ingameMap.isVisible then
			basePosY = self.posYAboveMap;
		end;
	end;
	local line = 0;
	courseplay:setFontSettings('white', false, 'left');
	for _,refIndexes in pairs(self.content) do
		if line >= self.maxNum then
			break;
		end;

		for refIdx,data in pairs(refIndexes) do
			line = line + 1;

			-- background
			local bg = self.overlays[line];
			bg:setColor(unpack(self.levelColors[data.level]));
			local gfxPosY = basePosY + (line - 1) * (self.lineHeight + self.lineMargin);
			bg:setPosition(bg.x, gfxPosY);
			bg:setDimension(data.backgroundWidth, bg.height);
			bg:render();

			-- text
			local textPosY = gfxPosY + (self.lineHeight - self.fontSize) * 1.2; -- should be (lineHeight-fontSize)*0.5, but there seems to be some pixel/sub-pixel rendering error
			renderText(self.textPosX, textPosY, self.fontSize, data.text);
			-- button
			local button = self.buttons[line];
			if button ~= nil then
				button:setPosition(button.overlay.x, gfxPosY)

				local currentColor = button.curColor;
				local targetColor = currentColor;

				button:setCanBeClicked(true);
				button:setDisabled(data.vehicle.isBroken or data.vehicle.isControlled);
				button:setParameter(data.vehicle);
				if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle == data.vehicle then
					targetColor = 'activeGreen';
					button:setCanBeClicked(false);
				elseif button.isDisabled then
					targetColor = 'whiteDisabled';
				elseif button.isClicked then
					targetColor = 'activeRed';
				elseif button.isHovered then
					targetColor = 'hover';
				else
					targetColor = 'white';
				end;

				-- set color
				if currentColor ~= targetColor then
					button:setColor(targetColor);
				end;

				-- NOTE: do not use button:render() here, as we neither need the button.show check, nor the hoveredButton var, nor the color setting. Simply rendering the overlay suffices
				button.overlay:render();
			end;
		end;
	end;
	self.buttonsClickArea.y1 = basePosY;
	self.buttonsClickArea.y2 = basePosY + (line  * (self.lineHeight + self.lineMargin));
end;

--- Resets all buttons.
function GlobalInfoTextHandler:resetButtons()
	for _,button in pairs(self.buttons) do
		button:setClicked(false);
		button:setHovered(false);
	end;
end

--- Delete all button overlays.
function GlobalInfoTextHandler:delete()
	--delete globalInfoText overlays
	for i,button in pairs(self.buttons) do
		button:deleteOverlay();

		if self.overlays[i] then
			local ovl = self.overlays[i];
			if ovl.overlayId ~= nil and ovl.delete ~= nil then
				ovl:delete();
			end;
		end;
	end;
end

--- Mouse event to interact with the info text buttons.
---@param posX number mouse x position
---@param posY number mouse y position
---@param isDown boolean the mouse button down ?
---@param isUp boolean the mouse button up ?
---@param mouseKey number mouse button was pressed ?
function GlobalInfoTextHandler:mouseEvent(posX, posY, isDown, isUp, mouseKey)
	local area = self.buttonsClickArea;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- LEFT CLICK to click the button shown in globalInfoText
	if (isDown or isUp) and mouseKey == courseplay.inputBindings.mouse.primaryButtonId and courseplay:mouseIsInArea(posX, posY, area.x1, area.x2, area.y1, area.y2) then
		self:onPrimaryMouseClick(posX, posY, isDown, isUp, mouseKey)
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- RIGHT CLICK  to activate the mouse cursor when I'm not in a vehicle and a globalInfoText is shown
	elseif isUp and mouseKey == courseplay.inputBindings.mouse.secondaryButtonId and g_currentMission.controlledVehicle == nil then
		self:onSecondaryMouseClick(posX, posY, isDown, isUp, mouseKey)
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- HOVER
	elseif not isDown and not isUp and self.hasContent then
		for _,button in pairs(self.buttons) do
			button:setClicked(false)
			if button.show and not button.isHidden then
				button:setHovered(button:getHasMouse(posX, posY))
			end
		end
	end
end

---Secondary mouse button pressed
---@param posX number mouse x position
---@param posY number mouse y position
---@param isDown boolean the mouse button down ?
---@param isUp boolean the mouse button up ?
---@param mouseKey number mouse button was pressed ?
function GlobalInfoTextHandler:onSecondaryMouseClick(posX, posY, isDown, isUp, mouseKey)
	if self.hasContent and not self.playerOnFootMouseEnabled and not g_currentMission.player.currentTool then
		self.playerOnFootMouseEnabled = true
		self.wasPlayerFrozen = g_currentMission.isPlayerFrozen
		g_currentMission.isPlayerFrozen = true
	elseif self.playerOnFootMouseEnabled then
		self.playerOnFootMouseEnabled = false
		if self.hasContent then --if a button was hovered when deactivating the cursor, deactivate hover state
			self:resetButtons()
		end;
		if not self.wasPlayerFrozen then
			g_currentMission.isPlayerFrozen = false
		end;
	end;
	g_inputBinding:setShowMouseCursor(self.playerOnFootMouseEnabled)
end

---Primary mouse button pressed
---@param posX number mouse x position
---@param posY number mouse y position
---@param isDown boolean the mouse button down ?
---@param isUp boolean the mouse button up ?
---@param mouseKey number mouse button was pressed ?
function GlobalInfoTextHandler:onPrimaryMouseClick(posX, posY, isDown, isUp, mouseKey)
	if self.hasContent then
		for i,button in pairs(self.buttons) do
			if button.show and button:getHasMouse(posX, posY) then
				button:setClicked(isDown)
				if isUp then
					local sourceVehicle = g_currentMission.controlledVehicle or button.parameter
					button:handleMouseClick(sourceVehicle)
				end
				break
			end
		end
	end
end

---Is the second mouse button allowed, when the player isn't in a vehicle ?
---@return boolean allowed?
function GlobalInfoTextHandler:isSecondaryMouseClickAllowed()
	return self.playerOnFootMouseEnabled or self.hasContent and not self.playerOnFootMouseEnabled and not g_currentMission.player.currentTool
end

---Is the first mouse button allowed, when the player isn't in a vehicle ?
---@return boolean allowed?
function GlobalInfoTextHandler:isPrimaryMouseClickAllowed()
	return self.hasContent and self.playerOnFootMouseEnabled
end

--- Gets all info texts
function GlobalInfoTextHandler:getInfoTexts()
	return self.infoTexts
end

--- Switch to a vehicle, which info text button was pressed.
function GlobalInfoTextHandler:goToVehicle(vehicle)
	g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(vehicle, g_currentMission.missionInfo.playerStyle, g_currentMission.player.farmId));
	g_currentMission.isPlayerFrozen = false;
	self.playerOnFootMouseEnabled = false;
	g_inputBinding:setShowMouseCursor(vehicle.cp.mouseCursorActive);
end


g_globalInfoTextHandler = GlobalInfoTextHandler()