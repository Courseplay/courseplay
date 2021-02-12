-- #################################################################
-- courseplay.button class

courseplay.button = {};
cpButton_mt = Class(courseplay.button);

function courseplay.button:new(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow,
							   modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip, onlyCallLocal)
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

function courseplay.button:setOnlyCallLocal()
	self.onlyCallLocal = true
	return self;
end;

function courseplay.button:setSetting(setting)
	self.settingCall = setting
	return self;
end;

function courseplay.button:setSpriteSectionUVs(spriteSection)
	if not spriteSection or courseplay.hud.buttonUVsPx[spriteSection] == nil then return; end;

	self.spriteSection = spriteSection;
	courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.buttonUVsPx[spriteSection], courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
end;

function courseplay.button:setSpecialButtonUVs()
	if not self.overlay then return; end;

	local fn = self.functionToCall;
	local prm = self.parameter;
	local txtSizeX, txtSizeY = courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y;

	if fn == 'setCpMode' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.modeButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'setHudPage' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'generateCourse' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[courseplay.hud.PAGE_COURSE_GENERATION], txtSizeX, txtSizeY);

	elseif fn == 'toggleDebugChannel' then
		self:setSpriteSectionUVs('recordingStop');

	-- CpManager buttons
	elseif fn == 'goToVehicle' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[courseplay.hud.PAGE_DRIVING_SETTINGS], txtSizeX, txtSizeY);
	end;
end;

function courseplay.button:render()
	-- self = courseplay.button

	local vehicle, pg, fn, prm = self.vehicle, self.page, self.functionToCall, self.parameter;
	local hoveredButton = false;
	local isDisabled = self.settingCall and self.settingCall:isDisabled(self.parameter) or false
	local isVisible = self.settingCall and self.settingCall:isVisible(self.parameter) or true


	if self.overlay ~= nil then
		if self.show and isVisible then
			-- set color
			local currentColor = self.curColor;
			local targetColor = currentColor;
			local hoverColor = 'hover';
			if fn == 'openCloseHud' then
				hoverColor = 'closeRed';
			end;
			isDisabled = self.isDisabled or isDisabled

			if not isDisabled and not self.isActive and not self.isHovered and (self.canBeClicked or self.functionToCall == nil) and not self.isClicked then
				targetColor = 'white';
			elseif isDisabled then
				targetColor = 'whiteDisabled';
			elseif not isDisabled and self.canBeClicked and self.isClicked and fn ~= 'openCloseHud' then
				targetColor = 'activeRed';
			elseif self.isHovered and ((not isDisabled and self.isToggleButton and self.isActive and self.canBeClicked and not self.isClicked) or (not isDisabled and not self.isActive and self.canBeClicked and not self.isClicked)) then
				targetColor = hoverColor;
				hoveredButton = true;
				if self.isToggleButton then
					--print(string.format('self %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> hoverColor', fn, g_updateLoopIndex, tostring(self.isHovered), tostring(self.isActive), tostring(self.isDisabled), tostring(self.canBeClicked)));
				end;
			elseif self.isActive and (not self.isToggleButton or (self.isToggleButton and not self.isHovered)) then
				targetColor = 'activeGreen';
				if self.isToggleButton then
					--print(string.format('button %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> activeGreen', fn, g_updateLoopIndex, tostring(self.isHovered), tostring(self.isActive), tostring(self.isDisabled), tostring(self.canBeClicked)));
				end;
			end;

			if currentColor ~= targetColor then
				self:setColor(targetColor);
			end; 

			-- render
			self.overlay:render();
		end;
	end;	--elseif button.overlay ~= nil

	return hoveredButton;
end;

function courseplay.button:setColor(colorName)
	if self.overlay and colorName and (self.curColor == nil or self.curColor ~= colorName) and courseplay.hud.colors[colorName] then
		self.overlay:setColor(unpack(courseplay.hud.colors[colorName]));
		self.curColor = colorName;
	end;
end;

function courseplay.button:setPosition(posX, posY)
	self.x = posX;
	self.x_init = posX;
	self.x2 = posX + self.width;

	self.y = posY;
	self.y_init = posY;
	self.y2 = posY + self.height;

	if not self.overlay then return; end;
	self.overlay:setPosition(self.x, self.y);
end;


function courseplay.button:handleHoverAction(vehicle, posX, posY)
	local button = self;
	if button.isMouseWheelArea and (button.canScrollUp or button.canScrollDown) then
		--Mouse wheel icon
		vehicle.cp.hud.mouseWheel.render = true;
		vehicle.cp.hud.mouseWheel.icon:setPosition(posX + 3/g_screenWidth, posY - 16/g_screenHeight);

		
		--action
		local parameter = button.parameter;
		--print(string.format("if courseplay.inputModifierIsPressed(%s) and button.modifiedParameter(%s) ~= nil then",tostring(courseplay.inputModifierIsPressed),tostring(button.modifiedParameter)))
		if courseplay.inputModifierIsPressed and button.modifiedParameter ~= nil then
			parameter = button.modifiedParameter;
		end;

		local upParameter = parameter;
		local downParameter = upParameter * -1;
		if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) and button.canScrollUp then
			courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_UP: %s(%s)", nameNum(vehicle), tostring(button.functionToCall), tostring(upParameter)), courseplay.DBG_HUD);
			self:handleInput(vehicle,upParameter)
		elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) and button.canScrollDown then
			courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_DOWN: %s(%s)", nameNum(vehicle), tostring(button.functionToCall), tostring(downParameter)), courseplay.DBG_HUD);
			self:handleInput(vehicle,downParameter)
		end;
	end;
end

function courseplay.button:handleMouseClick(vehicle)
	vehicle = vehicle or self.vehicle;
	local parameter = self.parameter;
	if courseplay.inputModifierIsPressed and self.modifiedParameter ~= nil then
		courseplay:debug("self.modifiedParameter = " .. tostring(self.modifiedParameter), courseplay.DBG_HUD);
		parameter = self.modifiedParameter;
	end;

	if self.show and not self.isHidden and self.canBeClicked and not self.isDisabled then
		--[[if self.functionToCall == "rowButton" and vehicle.cp.hud.content.pages[vehicle.cp.hud.currentPage][self.parameter][1].text == nil then
			return;
		end;]]

		-- self:setClicked(true);
		if self.functionToCall == "showSaveCourseForm" then
			vehicle.cp.imWriting = true
		end
		if self.functionToCall == "goToVehicle" then
			courseplay:executeFunction(vehicle, "goToVehicle", parameter)
		else
			courseplay:debug(string.format("%s: MOUSE_BUTTON_ClICKED: %s(%s)", nameNum(vehicle), tostring(self.functionToCall), tostring(parameter)), courseplay.DBG_HUD);
			self:handleInput(vehicle,parameter)
		end
		-- self:setClicked(false);
	end;
end;

function courseplay.button:handleInput(vehicle,parameter)
	if self.settingCall then --settingButton
		local isDisabled = self.settingCall:isDisabled(parameter)
		if not isDisabled then 
			courseplay:debug(string.format("%s: handleSettingInput: %s:%s(%s)", nameNum(vehicle),tostring(self.settingCall.name), tostring(self.functionToCall), tostring(parameter)), 18);
			self.settingCall[self.functionToCall](self.settingCall, parameter)	
			if vehicle:getIsEntered() then
				g_currentMission.hud.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
			end
			courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
		end
	else
		if self.functionToCall then
			vehicle:setCourseplayFunc(self.functionToCall, parameter, self.onlyCallLocal or false, self.page);
		end
	end
end

function courseplay.button:setOffset(offsetX, offsetY)
	offsetX = offsetX or 0
	offsetY = offsetY or 0

	self.x = self.x_init + offsetX;
	self.y = self.y_init + offsetY;
	self.x2 = self.x + self.width;
	self.y2 = self.y + self.height;

	if not self.overlay then return; end;
	self.overlay:setPosition(self.x, self.y);
end

function courseplay.button:setParameter(parameter)
	if self.parameter ~= parameter then
		self.parameter = parameter;
	end;
end;

function courseplay.button:setToolTip(text)
	if self.toolTip ~= text then
		self.toolTip = text;
	end;
end;

function courseplay.button:setActive(active)
	if self.isActive ~= active then
		self.isActive = active;
	end;
end;

function courseplay.button:setCanBeClicked(canBeClicked)
	if self.canBeClicked ~= canBeClicked then
		self.canBeClicked = canBeClicked;
	end;
end;

function courseplay.button:setClicked(clicked)
	if self.isClicked ~= clicked then
		self.isClicked = clicked;
	end;
end;

function courseplay.button:setDisabled(disabled)
	if self.isDisabled ~= disabled then
		self.isDisabled = disabled;
	end;
end;

function courseplay.button:setHovered(hovered)
	if self.isHovered ~= hovered then
		self.isHovered = hovered;
	end;
end;

function courseplay.button:setCanScrollUp(canScrollUp)
	if self.canScrollUp ~= canScrollUp then
		self.canScrollUp = canScrollUp;
	end;
end;

function courseplay.button:setCanScrollDown(canScrollDown)
	if self.canScrollDown ~= canScrollDown then
		self.canScrollDown = canScrollDown;
	end;
end;

function courseplay.button:setShow(show)
	if self.show ~= show then
		self.show = show;
	end;
end;

function courseplay.button:setAttribute(attribute, value)
	if self[attribute] ~= value then
		self[attribute] = value;
	end;
end;

function courseplay.button:deleteOverlay()
	if self.overlay ~= nil and self.overlay.overlayId ~= nil and self.overlay.delete ~= nil then
		self.overlay:delete();
	end;
end;

function courseplay.button:getHasMouse(mouseX, mouseY)
	-- return mouseX > self.x and mouseX < self.x2 and mouseY > self.y and mouseY < self.y2;
	return courseplay:mouseIsInArea(mouseX, mouseY, self.x, self.x2, self.y, self.y2);
end;

function courseplay.button:getIsDisabled()
	return self.isDisabled
end


-- #################################################################
-- courseplay.buttons

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

function courseplay.buttons:deleteButtonOverlays(vehicle)
	for k,buttonSection in pairs(vehicle.cp.buttons) do
		for i,button in pairs(buttonSection) do
			button:deleteOverlay();
		end;
	end;
end;

