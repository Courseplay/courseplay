-- #################################################################
-- courseplay.button class

courseplay.button = {};
cpButton_mt = Class(courseplay.button);

function courseplay.button:new(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip)
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

	if not vehicle.isCourseplayManager then
		self.vehicle = vehicle;
	end;
	self.page = hudPage; 
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

	if self.overlay ~= nil then
		if self.show then
			-- set color
			local currentColor = self.curColor;
			local targetColor = currentColor;
			local hoverColor = 'hover';
			if fn == 'openCloseHud' then
				hoverColor = 'closeRed';
			end;

			if fn == 'movePipeToPosition' then
				if vehicle.cp.pipeWorkToolIndex ~= nil and vehicle.cp.manualPipePositionOrder then
					targetColor = 'warningRed';
				elseif vehicle.cp.pipeWorkToolIndex ~= nil then
					targetColor = 'activeGreen';
				end	
			elseif fn == 'moveShovelToPosition' and not self.isDisabled and vehicle.cp.manualShovelPositionOrder and vehicle.cp.manualShovelPositionOrder == prm then  -- forced color
				targetColor = 'warningRed';
			elseif not self.isDisabled and not self.isActive and not self.isHovered and self.canBeClicked and not self.isClicked then
				targetColor = 'white';
			elseif self.isDisabled then
				targetColor = 'whiteDisabled';
			elseif not self.isDisabled and self.canBeClicked and self.isClicked and fn ~= 'openCloseHud' then
				targetColor = 'activeRed';
			elseif self.isHovered and ((not self.isDisabled and self.isToggleButton and self.isActive and self.canBeClicked and not self.isClicked) or (not self.isDisabled and not self.isActive and self.canBeClicked and not self.isClicked)) then
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
			courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_UP: %s(%s)", nameNum(vehicle), tostring(button.functionToCall), tostring(upParameter)), 18);
			vehicle:setCourseplayFunc(button.functionToCall, upParameter, false, button.page);
		elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) and button.canScrollDown then
			courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_DOWN: %s(%s)", nameNum(vehicle), tostring(button.functionToCall), tostring(downParameter)), 18);
			vehicle:setCourseplayFunc(button.functionToCall, downParameter, false, button.page);
		end;
	end;
end

function courseplay.button:handleMouseClick(vehicle)
	vehicle = vehicle or self.vehicle;
	local parameter = self.parameter;
	if courseplay.inputModifierIsPressed and self.modifiedParameter ~= nil then
		courseplay:debug("self.modifiedParameter = " .. tostring(self.modifiedParameter), 18);
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
			vehicle:setCourseplayFunc(self.functionToCall, parameter, false, self.page);
		end
		-- self:setClicked(false);
	end;
end;

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

	if vehicle.cp.suc.active then
		if vehicle.cp.suc.fruitNegButton:render() then
			hoveredButton = vehicle.cp.suc.fruitNegButton;
		end;
		if vehicle.cp.suc.fruitPosButton:render() then
			hoveredButton = vehicle.cp.suc.fruitPosButton;
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

function courseplay.buttons:setActiveEnabled(vehicle, section)
	local anySection = section == nil or section == 'all';

	if anySection or section == 'pageNav' then
		
	end;
--[[
	if vehicle.cp.hud.currentPage == 1 and (anySection or section == 'quickModes' or section == 'recording' or section == 'customFieldShow' or section == 'findFirstWaypoint') then
		local isMode2_3_4_6 = vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK or vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_OVERLOADER;
		local isMode4or6 = vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK
		for _,button in pairs(vehicle.cp.buttons[1]) do
			local fn, prm = button.functionToCall, button.parameter;
			if fn == 'setCpMode' and (anySection or section == 'quickModes') then
				button:setActive(vehicle.cp.mode == prm);
				local disabled = not courseplay:getCanVehicleUseMode(vehicle, prm);
				button:setDisabled(disabled);
				button:setCanBeClicked(not button.isDisabled and not button.isActive);
			end;

			if fn == 'toggleCustomFieldEdgePathShow' and (anySection or section == 'customFieldShow') then
				button:setActive(vehicle.cp.fieldEdge.customField.show);
			end;

			if fn == 'toggleFindFirstWaypoint' and (anySection or section == 'findFirstWaypoint') then
				button:setActive(vehicle.cp.distanceCheck);
			end;

			if button.row == 7 and button.functionToCall == 'rowButton' then
				button:setDisabled(not isMode2_3_4_6);
				button:setShow(isMode2_3_4_6);
				button:setActive(vehicle.cp.turnOnField);
				button:setCanBeClicked(not button.isDisabled);
			elseif button.row == 8 and button.functionToCall == 'rowButton' then
				button:setDisabled(not isMode4or6);
				button:setShow(isMode4or6);
				button:setActive(vehicle.cp.turnOnField);
				button:setCanBeClicked(not button.isDisabled);
			end;

			if anySection or section == 'recording' then
				if fn == 'stop_record' then
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'setRecordingPause' then
					button:setActive(vehicle.cp.recordingIsPaused);
					button:setDisabled(vehicle.cp.waypointIndex < 4 or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'delete_waypoint' then
					button:setDisabled(not vehicle.cp.recordingIsPaused or vehicle.cp.waypointIndex <= 4);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'set_waitpoint' or fn == 'set_crossing' then
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'setRecordingTurnManeuver' then --isToggleButton
					button:setActive(vehicle.cp.isRecordingTurnManeuver);
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.drivingDirReverse);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'change_DriveDirection' then --isToggleButton
					button:setActive(vehicle.cp.drivingDirReverse);
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'addSplitRecordingPoints' then
					button:setDisabled(not vehicle.cp.recordingIsPaused);
					button:setCanBeClicked(not button.isDisabled);
				end;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 2 and (anySection or section == 'page2') then
		local enable, show = true, true;
		local numVisibleCourses = #(vehicle.cp.hud.courses);
		local nofolders = nil == next(g_currentMission.cp_folders);
		local indent = courseplay.hud.indent;
		local row, fn;
		for _, button in pairs(vehicle.cp.buttons[-2]) do
			row = button.row;
			fn = button.functionToCall;
			enable = true;
			show = true;

			if row > numVisibleCourses then
				show = false;
			else
				if fn == 'expandFolder' then
					if vehicle.cp.hud.courses[row].type == 'course' then
						show = false;
					else
						-- position the expandFolder buttons
						button:setOffset(vehicle.cp.hud.courses[row].level * indent, 0)
						
						if vehicle.cp.hud.courses[row].id == 0 then
							show = false; --hide for level 0 'folder'
						else
							-- check if plus or minus should show up
							if vehicle.cp.folder_settings[vehicle.cp.hud.courses[row].id].showChildren then
								button:setSpriteSectionUVs('navMinus');
							else
								button:setSpriteSectionUVs('navPlus');
							end;
							if g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild == 0 then
								enable = false; -- button has no children
							end;
						end;
					end;
				else
					if vehicle.cp.hud.courses[row].type == 'folder' and (fn == 'loadSortedCourse' or fn == 'addSortedCourse') then
						show = false;
					elseif vehicle.cp.hud.choose_parent ~= true then
						if fn == 'deleteSortedItem' and vehicle.cp.hud.courses[row].type == 'folder' and g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild ~= 0 then
							enable = false;
						elseif fn == 'linkParent' then
							button:setSpriteSectionUVs('folderParentFrom');
							if nofolders then
								enable = false;
							end;
						elseif vehicle.cp.hud.courses[row].type == 'course' and (fn == 'loadSortedCourse' or fn == 'addSortedCourse' or fn == 'deleteSortedItem') and vehicle.cp.isDriving then
							enable = false;
						end;
					else
						if fn ~= 'linkParent' then
							enable = false;
						else
							button:setSpriteSectionUVs('folderParentTo');
						end;
					end;
				end;
			end;

			button:setDisabled(not enable or not show);
			button:setShow(show);
		end; -- for buttons
		courseplay.settings.validateCourseListArrows(vehicle);

	elseif vehicle.cp.hud.currentPage == 3 and anySection then
	
		for _,button in pairs(vehicle.cp.buttons[3]) do
			if button.functionToCall == 'changeLastValidTipDistance' then
				local activate = vehicle.cp.lastValidTipDistance ~= nil
				button:setDisabled(not activate);
				button:setCanBeClicked(activate);
				button:setShow(activate);
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 6 then
		if anySection or section == 'debug' then
			for _,button in pairs(vehicle.cp.buttons[6]) do
				if button.functionToCall == 'toggleDebugChannel' then
					button:setDisabled(button.parameter > courseplay.numDebugChannels);
					button:setActive(courseplay.debugChannels[button.parameter] == true);
					button:setCanBeClicked(not button.isDisabled);
				end;
			end;
		end;

		if anySection or section == 'visualWaypoints' then
			vehicle.cp.visualWaypointsStartEndButton1:setActive(vehicle.cp.visualWaypointsStartEnd);
			vehicle.cp.visualWaypointsStartEndButton1:setCanBeClicked(true);

			vehicle.cp.visualWaypointsStartEndButton2:setActive(vehicle.cp.visualWaypointsStartEnd);
			vehicle.cp.visualWaypointsStartEndButton2:setCanBeClicked(true);

			vehicle.cp.visualWaypointsAllEndButton:setActive(vehicle.cp.visualWaypointsAll);
			vehicle.cp.visualWaypointsAllEndButton:setCanBeClicked(true);

			vehicle.cp.visualWaypointsCrossingButton:setActive(vehicle.cp.visualWaypointsCrossing);
			vehicle.cp.visualWaypointsCrossingButton:setCanBeClicked(true);
		end;

	elseif vehicle.cp.hud.currentPage == 8 and (anySection or section == 'generateCourse' or section == 'selectedFieldShow' or section == 'suc') then
		vehicle.cp.hud.generateCourseButton:setDisabled(not vehicle.cp.hasValidCourseGenerationData);
		if vehicle.cp.hud.showSelectedFieldEdgePathButton then
			vehicle.cp.hud.showSelectedFieldEdgePathButton:setActive(vehicle.cp.fieldEdge.selectedField.show);
		end;
		if vehicle.cp.suc.toggleHudButton then
			vehicle.cp.suc.toggleHudButton:setActive(vehicle.cp.suc.active);
		end;

	elseif vehicle.cp.hud.currentPage == 9 and (anySection or section == 'shovel') then
		for _,button in pairs(vehicle.cp.buttons[9]) do
			if button.functionToCall == 'saveShovelPosition' then --isToggleButton
				button:setActive(vehicle.cp.shovelStatePositions[button.parameter] ~= nil);
				button:setCanBeClicked(true);
			elseif button.functionToCall == 'moveShovelToPosition' then
				button:setDisabled(not vehicle.cp.hasShovelStatePositions[button.parameter]);
			end;
		end;
	end;	
	]]
end;

