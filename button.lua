-- #################################################################
-- courseplay.button class
---@class button
courseplay.button = {};
cpButton_mt = Class(courseplay.button);

--- Creates a new button
---@param vehicle table
---@param hudPage number page on the hud
---@param img tableOrString image for the button overlay
---@param functionToCall string callback function
---@param parameter number callback parameter
---@param x number x position
---@param y number y position
---@param width number
---@param height number
---@param hudRow number line on the hud
---@param modifiedParameter number adjusted parameter?? 
---@param hoverText string text while hovering
---@param isMouseWheelArea boolean is hovering or scrolling allowed ?
---@param isToggleButton boolean is it a toggle button
---@param toolTip string the same as hoverText ??
---@param onlyCallLocal boolean should the button only work on client side ?
function courseplay.button:new(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip, onlyCallLocal)
	local self = setmetatable({}, cpButton_mt);

	if img then
		if type(img) == 'table' then
			if img[1] == 'iconSprite.png' then
				self.overlay = Overlay:new( courseplay.hud.iconSpritePath, x, y, width, height);
				self.spriteSection = img[2];
			end;
		else
			self.overlay = Overlay:new(Utils.getFilename('img/' .. img, courseplay.path), x, y, width, height);
		end;
	end;

	if hoverText == nil then
		hoverText = false;
	end;
	if isMouseWheelArea == nil then
		isMouseWheelArea = false;
	end;
	if isToggleButton == nil then
		isToggleButton = false;
	end;
	if onlyCallLocal == nil then
		onlyCallLocal = false;
	end;


	if not vehicle.isCourseplayManager then
		self.vehicle = vehicle;
	end;
	self.page = hudPage; 
	self.settingCall = nil
	self.functionToCall = functionToCall;	
	self:setParameter(parameter);
	self.width = width;
	self.height = height;
	self.x_init = x;
	self.x = x;
	self.x2 = (x + width);
	self.y_init = y;
	self.y = y;
	self.y2 = (y + height);
	self.row = hudRow;
	self.hoverText = hoverText;
	self:setColor('white')
	self:setToolTip(toolTip);
	self.isMouseWheelArea = isMouseWheelArea and functionToCall ~= nil;
	self.isToggleButton = isToggleButton;
	self.onlyCallLocal = onlyCallLocal;
	self:setCanBeClicked(not isMouseWheelArea and functionToCall ~= nil);
	self:setShow(true);
	self:setClicked(false);
	self:setActive(false);
	self:setDisabled(false);
	self:setHovered(false);
	if modifiedParameter then 
		self.modifiedParameter = modifiedParameter;
	end
	if isMouseWheelArea then
		self.canScrollUp   = true;
		self.canScrollDown = true;
	end;

	if self.spriteSection then
		self:setSpriteSectionUVs(self.spriteSection);
	else
		self:setSpecialButtonUVs();
	end;

	if vehicle.isCourseplayManager then
		table.insert(vehicle[hudPage].buttons, self);
	else
		table.insert(vehicle.cp.buttons[hudPage], self);
	end;

	return self;
end;

--- Getters
function courseplay.button:getIsDisabled()
	local setting = self:getSetting()
	return self.isDisabled or setting and setting:isDisabled()
end

function courseplay.button:getIsVisible()
	return self.show
end

function courseplay.button:getIsActive()
	local setting = self:getSetting()
	return self.isActive or setting and setting:isActive(self:getCallbackParameter())
end

function courseplay.button:getIsClicked()
	return self.isClicked
end

function courseplay.button:getIsHovered()
	return self.isHovered
end

function courseplay.button:getIsToggleButton()
	return self.isToggleButton
end

function courseplay.button:getCanBeClicked()
	return self.canBeClicked
end

function courseplay.button:getCanScrollDown()
	return self.canScrollDown
end

function courseplay.button:getCanScrollUp()
	return self.canScrollUp
end

function courseplay.button:getToolTip()
	return self.toolTip
end

function courseplay.button:getHoverText()
	return self.hoverText
end

function courseplay.button:getCallbackParameter()
	return self.parameter
end

function courseplay.button:getCallbackFunction()
	return self.functionToCall
end

function courseplay.button:getSetting()
	return self.settingCall
end

function courseplay.button:getOverlay()
	return self.overlay
end

function courseplay.button:getPositions()
	return self.x,self.y,self.x2,self.y2
end

function courseplay.button:getInitPositions()
	return self.x_init,self.y_init,self.x2,self.y2
end

function courseplay.button:getSize()
	return self.width,self.height
end

function courseplay.button:getRow()
	return self.row
end

function courseplay.button:getPage()
	return self.page
end

function courseplay.button:getColor()
	return self.curColor
end

function courseplay.button:getOnlyCallLocal()
	return self.onlyCallLocal
end



--- Sets button to only be clicked on client.
function courseplay.button:setOnlyCallLocal()
	self.onlyCallLocal = true
	return self;
end;

--- Sets setting to a button.
function courseplay.button:setSetting(setting)
	self.settingCall = setting
	return self;
end;

---Sets/changes the sprite of an button from an sprite sheet.
function courseplay.button:setSpriteSectionUVs(spriteSection)
	if not spriteSection or courseplay.hud.buttonUVsPx[spriteSection] == nil then return; end;

	self.spriteSection = spriteSection;
	HudUtil.setOverlayUVsPx(self:getOverlay(), courseplay.hud.buttonUVsPx[spriteSection], courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
end;

--- Setups Uvs for button.
function courseplay.button:setSpecialButtonUVs()
	local overlay = self:getOverlay()
	if not overlay then return; end;

	local fn = self:getCallbackFunction();
	local prm = self:getCallbackParameter();
	local txtSizeX, txtSizeY = courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y;

	if fn == 'setCpMode' then
		HudUtil.setOverlayUVsPx(overlay, courseplay.hud.modeButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'setHudPage' then
		HudUtil.setOverlayUVsPx(overlay, courseplay.hud.pageButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'generateCourse' then
		HudUtil.setOverlayUVsPx(overlay, courseplay.hud.pageButtonsUVsPx[courseplay.hud.PAGE_COURSE_GENERATION], txtSizeX, txtSizeY);

	elseif fn == 'toggleDebugChannel' then
		self:setSpriteSectionUVs('recordingStop');

	-- CpManager buttons
	elseif fn == 'goToVehicle' then
		HudUtil.setOverlayUVsPx(overlay, courseplay.hud.pageButtonsUVsPx[courseplay.hud.PAGE_DRIVING_SETTINGS], txtSizeX, txtSizeY);
	end;
end;

--- Renders the button.
function courseplay.button:render()
	-- self = courseplay.button
	local overlay = self:getOverlay()
	local vehicle, pg, fn, prm = self.vehicle, self:getPage(), self:getCallbackFunction(), self:getCallbackParameter();
	local hoveredButton = false;

	if overlay ~= nil then
		if self:getIsVisible() then
			-- set color
			local currentColor = self:getColor();
			local targetColor = currentColor;
			local hoverColor = 'hover';
			if fn == 'openCloseHud' then
				hoverColor = 'closeRed';
			end;

			if not self:getIsDisabled() and not self:getIsActive() and not self:getIsHovered() and (self:getCanBeClicked() or self:getCallbackFunction() == nil) and not self:getIsClicked() then
				targetColor = 'white';
			elseif self:getIsDisabled() then
				targetColor = 'whiteDisabled';
			elseif not self:getIsDisabled() and self:getCanBeClicked() and self:getIsClicked() and fn ~= 'openCloseHud' then
				targetColor = 'activeRed';
			elseif self:getIsHovered() and ((not self:getIsDisabled() and self:getIsToggleButton() and self:getIsActive() and self:getCanBeClicked() and not self:getIsClicked()) or (not self:getIsDisabled() and not self:getIsActive() and self:getCanBeClicked() and not self:getIsClicked())) then
				targetColor = hoverColor;
				hoveredButton = true;
				if self:getIsToggleButton() then
					--print(string.format('self %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> hoverColor', fn, g_updateLoopIndex, tostring(self:getIsHovered()), tostring(self:getIsActive()), tostring(self:getIsDisabled()), tostring(self:getCanBeClicked())));
				end;
			elseif self:getIsActive() and (not self:getIsToggleButton() or (self:getIsToggleButton() and not self:getIsHovered())) then
				targetColor = 'activeGreen';
				if self:getIsToggleButton() then
					--print(string.format('button %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> activeGreen', fn, g_updateLoopIndex, tostring(self:getIsHovered()), tostring(self:getIsActive()), tostring(self:getIsDisabled()), tostring(self:getCanBeClicked())));
				end;
			end;

			if currentColor ~= targetColor then
				self:setColor(targetColor);
			end; 

			-- render
			overlay:render();
		end;
	end;	--elseif button.overlay ~= nil

	return hoveredButton;
end;

--- Sets the color of the button.
function courseplay.button:setColor(colorName)
	local curColor = self:getColor()
	local overlay = self:getOverlay()
	if overlay and colorName and (curColor == nil or curColor ~= colorName) and courseplay.hud.colors[colorName] then
		overlay:setColor(unpack(courseplay.hud.colors[colorName]));
		self.curColor = colorName;
	end;
end;

--- Sets/changes the position of the button.
function courseplay.button:setPosition(posX, posY)
	local overlay = self:getOverlay()
	self.x = posX;
	self.x_init = posX;
	self.x2 = posX + self.width;

	self.y = posY;
	self.y_init = posY;
	self.y2 = posY + self.height;

	if overlay then overlay:setPosition(self.x, self.y) end
end;

--- Handles hovering/scrolling by the mouse.
---@param vehicle table
---@param posX number mouse x position
---@param posY number mouse y position
function courseplay.button:handleHoverAction(vehicle, posX, posY)
	local button = self;
	if button.isMouseWheelArea and (button:getCanScrollUp() or button:getCanScrollDown()) then
		--Mouse wheel icon
		vehicle.cp.hud.mouseWheel.render = true;
		vehicle.cp.hud.mouseWheel.icon:setPosition(posX + 3/g_screenWidth, posY - 16/g_screenHeight);

		
		--action
		local parameter = self:getCallbackParameter();
		--print(string.format("if courseplay.inputModifierIsPressed(%s) and button.modifiedParameter(%s) ~= nil then",tostring(courseplay.inputModifierIsPressed),tostring(button.modifiedParameter)))
		if courseplay.inputModifierIsPressed and button.modifiedParameter ~= nil then
			parameter = button.modifiedParameter;
		end;

		local upParameter = parameter;
		local downParameter = upParameter * -1;
		local func = self:getCallbackFunction()
		if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) and button.canScrollUp then
			courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_UP: %s(%s)", nameNum(vehicle), tostring(func), tostring(upParameter)), courseplay.DBG_HUD);
			self:handleInput(vehicle,upParameter)
		elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) and button.canScrollDown then
			courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_DOWN: %s(%s)", nameNum(vehicle), tostring(func), tostring(downParameter)), courseplay.DBG_HUD);
			self:handleInput(vehicle,downParameter)
		end;
	end;
end

--- Handles mouse clicks.
---@param vehicle table
function courseplay.button:handleMouseClick(vehicle)
	vehicle = vehicle or self.vehicle;
	local func,parameter = self:getCallbackFunction(),self:getCallbackParameter();
	if courseplay.inputModifierIsPressed and self.modifiedParameter ~= nil then
		courseplay:debug("self.modifiedParameter = " .. tostring(self.modifiedParameter), courseplay.DBG_HUD);
		parameter = self.modifiedParameter;
	end;

	if self:getIsVisible() and self:getCanBeClicked() and not self:getIsDisabled() then
		--[[if self.functionToCall == "rowButton" and vehicle.cp.hud.content.pages[vehicle.cp.hud.currentPage][self.parameter][1].text == nil then
			return;
		end;]]

		-- self:setClicked(true);
		if func == "showSaveCourseForm" then
			vehicle.cp.imWriting = true
		end
		if func == "goToVehicle" then
			courseplay:executeFunction(vehicle, "goToVehicle", parameter)
		else
			courseplay:debug(string.format("%s: MOUSE_BUTTON_ClICKED: %s(%s)", nameNum(vehicle), tostring(func), tostring(parameter)), courseplay.DBG_HUD);
			self:handleInput(vehicle,parameter)
		end
		-- self:setClicked(false);
	end;
end;

--- Handles button callbacks after mouse button input.
---@param vehicle table
---@param parameter number
function courseplay.button:handleInput(vehicle,parameter)
	local setting,func = self:getSetting(),self:getCallbackFunction()
	if setting then --settingButton
		courseplay:debug(string.format("%s: handleSettingInput: %s:%s(%s)", nameNum(vehicle),tostring(setting:getName()), tostring(func), tostring(parameter)), courseplay.DBG_HUD);
		setting[func](setting, parameter)	
		if vehicle:getIsEntered() then
			g_currentMission.hud.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
		end
		courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
	else
		if func then
			vehicle:setCourseplayFunc(func, parameter, self:getOnlyCallLocal() or false, self:getPage());
		end
	end
end

--- Sets an offset to the button in the hud.
---@param offsetX number x offset
---@param offsetY number y offset
function courseplay.button:setOffset(offsetX, offsetY)
	local overlay = self:getOverlay()
	offsetX = offsetX or 0
	offsetY = offsetY or 0

	self.x = self.x_init + offsetX;
	self.y = self.y_init + offsetY;
	self.x2 = self.x + self.width;
	self.y2 = self.y + self.height;

	if overlay then overlay:setPosition(self.x, self.y) end
end

---@param parameter number
function courseplay.button:setParameter(parameter)
	if self.parameter ~= parameter then
		self.parameter = parameter;
	end;
end;

---@param text string
function courseplay.button:setToolTip(text)
	if self.toolTip ~= text then
		self.toolTip = text;
	end;
end;

---@param active boolean
function courseplay.button:setActive(active)
	if self.isActive ~= active then
		self.isActive = active;
	end;
end;

---@param canBeClicked boolean
function courseplay.button:setCanBeClicked(canBeClicked)
	if self.canBeClicked ~= canBeClicked then
		self.canBeClicked = canBeClicked;
	end;
end;

---@param clicked boolean
function courseplay.button:setClicked(clicked)
	if self.isClicked ~= clicked then
		self.isClicked = clicked;
	end;
end;

---@param disabled boolean
function courseplay.button:setDisabled(disabled)
	if self.isDisabled ~= disabled then
		self.isDisabled = disabled;
	end;
end;

---@param hovered boolean
function courseplay.button:setHovered(hovered)
	if self.isHovered ~= hovered then
		self.isHovered = hovered;
	end;
end;

---@param canScrollUp boolean
function courseplay.button:setCanScrollUp(canScrollUp)
	if self.canScrollUp ~= canScrollUp then
		self.canScrollUp = canScrollUp;
	end;
end;

---@param canScrollDown boolean
function courseplay.button:setCanScrollDown(canScrollDown)
	if self.canScrollDown ~= canScrollDown then
		self.canScrollDown = canScrollDown;
	end;
end;

---@param visible boolean
function courseplay.button:setShow(show)
	if self.show ~= show then
		self.show = show;
	end;
end;

--- Sets an button attribute.
---@param attribute string
---@param value any
function courseplay.button:setAttribute(attribute, value)
	if self[attribute] ~= value then
		self[attribute] = value;
	end;
end;

--- Deletes the overlay.
function courseplay.button:deleteOverlay()
	local overlay = self:getOverlay()
	if overlay ~= nil and overlay.overlayId ~= nil and overlay.delete ~= nil then
		overlay:delete();
	end;
end;

--- Is the button hovered by 
function courseplay.button:getHasMouse(mouseX, mouseY)
	-- return mouseX > self.x and mouseX < self.x2 and mouseY > self.y and mouseY < self.y2;
	return courseplay:mouseIsInArea(mouseX, mouseY, self.x, self.x2, self.y, self.y2);
end;


-- #################################################################
-- courseplay.buttons

--- Renders all buttons.
function courseplay.buttons:renderButtons(vehicle, page)
	-- self = courseplay.buttons

	local hoveredButton;

	for _,button in pairs(vehicle.cp.buttons.global) do
		if button:render() then
			hoveredButton = button;
		end;
	end;

	for _,button in pairs(vehicle.cp.buttons[page]) do
		if button:render() then
			hoveredButton = button;
		end;
	end;

	if page == courseplay.hud.PAGE_MANAGE_COURSES then 
		for _,button in pairs(vehicle.cp.buttons[-courseplay.hud.PAGE_MANAGE_COURSES]) do
			if button:render() then
				hoveredButton = button;
			end;
		end;
	end;
	-- set currently hovered button in vehicle
	self:setHoveredButton(vehicle, hoveredButton);
end;

function courseplay.buttons:setHoveredButton(vehicle, button)
	if vehicle.cp.buttonHovered == button then
		return;
	end;
	vehicle.cp.buttonHovered = button;

	self:onHoveredButtonChanged(vehicle);
end;

function courseplay.buttons:onHoveredButtonChanged(vehicle)
	-- set toolTip in vehicle
	if vehicle.cp.buttonHovered ~= nil and vehicle.cp.buttonHovered.toolTip ~= nil then
		courseplay:setToolTip(vehicle, vehicle.cp.buttonHovered.toolTip);
	elseif vehicle.cp.buttonHovered == nil then
		courseplay:setToolTip(vehicle, nil);
	end;
end;

--- Deletes all button overlays
function courseplay.buttons:deleteButtonOverlays(vehicle)
	for k,buttonSection in pairs(vehicle.cp.buttons) do
		for i,button in pairs(buttonSection) do
			button:deleteOverlay();
		end;
	end;
end;
