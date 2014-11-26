-- #################################################################
-- courseplay.button class

courseplay.button = {};
cpButton_mt = Class(courseplay.button);

function courseplay.button:new(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip)
	local self = setmetatable({}, cpButton_mt);

	local overlay, spriteSection;
	if img then
		if type(img) == 'table' then
			if img[1] == 'iconSprite.png' then
				overlay = Overlay:new(img, courseplay.hud.iconSpritePath, x, y, width, height);
				spriteSection = img[2];
			end;
		elseif img ~= 'blank.dds' and img ~= 'blank.png' then
			overlay = Overlay:new(img, Utils.getFilename('img/' .. img, courseplay.path), x, y, width, height);
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

	self.vehicle = vehicle;
	self.page = hudPage; 
	self.overlay = overlay; 
	self.functionToCall = functionToCall; 
	self.parameter = parameter; 
	self.x_init = x;
	self.x = x;
	self.x2 = (x + width);
	self.y_init = y;
	self.y = y;
	self.y2 = (y + height);
	self.row = hudRow;
	self.hoverText = hoverText;
	self.color = courseplay.hud.colors.white;
	self.toolTip = toolTip;
	self.isMouseWheelArea = isMouseWheelArea and functionToCall ~= nil;
	self.isToggleButton = isToggleButton;
	self.canBeClicked = not isMouseWheelArea and functionToCall ~= nil;
	self.show = true;
	self.isClicked = false;
	self.isActive = false;
	self.isDisabled = false;
	self.isHovered = false;
	self.isHidden = false;
	if modifiedParameter then 
		self.modifiedParameter = modifiedParameter;
	end
	if isMouseWheelArea then
		self.canScrollUp   = true;
		self.canScrollDown = true;
	end;

	if spriteSection then
		self:setSpriteSectionUVs(spriteSection);
	else
		self:setSpecialButtonUVs();
	end;

	table.insert(vehicle.cp.buttons[hudPage], self);
	return self;
end;

function courseplay.button:setSpriteSectionUVs(spriteSection)
	if not spriteSection or courseplay.hud.buttonUVsPx[spriteSection] == nil then return; end;

	local ovl = self.overlay;
	local txtSizeX, txtSizeY = courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y;
	local UVs = courseplay.hud.buttonUVsPx[spriteSection];
	courseplay.utils:setOverlayUVsPx(ovl, UVs[1], UVs[2], UVs[3], UVs[4], txtSizeX, txtSizeY);
end;

function courseplay.button:setSpecialButtonUVs()
	local fn = self.functionToCall;
	local prm = self.parameter;
	local ovl = self.overlay;
	local txtSizeX, txtSizeY = courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y;

	if fn == 'toggleDebugChannel' then
		local col = ((prm - 1) % courseplay.numDebugChannelButtonsPerLine) + 1;
		local line = math.ceil(prm / courseplay.numDebugChannelButtonsPerLine);
		courseplay.utils:setOverlayUVsSymmetric(self.overlay, col, line, 16, 2); -- space in dds: 16 x, 2 y

	elseif fn == 'setCpMode' then
		local UVs = courseplay.hud.modeButtonsUVsPx[prm];
		courseplay.utils:setOverlayUVsPx(ovl, UVs[1], UVs[2], UVs[3], UVs[4], txtSizeX, txtSizeY);

	elseif fn == 'setHudPage' then
		local UVs = courseplay.hud.pageButtonsUVsPx[prm];
		courseplay.utils:setOverlayUVsPx(ovl, UVs[1], UVs[2], UVs[3], UVs[4], txtSizeX, txtSizeY);

	elseif fn == 'generateCourse' then
		local UVs = courseplay.hud.pageButtonsUVsPx[8];
		courseplay.utils:setOverlayUVsPx(ovl, UVs[1], UVs[2], UVs[3], UVs[4], txtSizeX, txtSizeY);
	end;
end;

function courseplay.button:render()
	-- self = courseplay.button

	local vehicle, pg, fn, prm = self.vehicle, self.page, self.functionToCall, self.parameter;
	local hoveredButton = false;

	--mouseWheelAreas conditionals
	if self.isMouseWheelArea then
		if pg == 1 then
			if fn == "setCustomFieldEdgePathNumber" then
				self.canScrollUp =   vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				self.canScrollDown = vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
			end;

		elseif pg == 2 then
			if fn == "shiftHudCourses" then
				self.canScrollUp =   vehicle.cp.hud.courseListPrev == true;
				self.canScrollDown = vehicle.cp.hud.courseListNext == true;
			end;

		elseif pg == 3 then
			if fn == "changeTurnRadius" then
				self.canScrollUp =   true;
				self.canScrollDown = vehicle.cp.turnRadius > 0;
			elseif fn == "changeFollowAtFillLevel" then
				self.canScrollUp =   vehicle.cp.followAtFillLevel < 100;
				self.canScrollDown = vehicle.cp.followAtFillLevel > 0;
			elseif fn == "changeDriveOnAtFillLevel" then
				self.canScrollUp =   vehicle.cp.driveOnAtFillLevel < 100;
				self.canScrollDown = vehicle.cp.driveOnAtFillLevel > 0;
			elseif fn == 'changeRefillUntilPct' then
				self.canScrollUp =   (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct < 100;
				self.canScrollDown = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct > 1;
			end;

		elseif pg == 4 then
			if fn == 'setSearchCombineOnField' then
				self.canScrollUp = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField > 0;
				self.canScrollDown = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
			end;

		elseif pg == 5 then
			if fn == 'changeTurnSpeed' then
				self.canScrollUp =   vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
				self.canScrollDown = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
			elseif fn == 'changeFieldSpeed' then
				self.canScrollUp =   vehicle.cp.speeds.field < vehicle.cp.speeds.max;
				self.canScrollDown = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
			elseif fn == 'changeMaxSpeed' then
				self.canScrollUp =   vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
				self.canScrollDown = vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
			elseif fn == 'changeUnloadSpeed' then
				self.canScrollUp =   vehicle.cp.speeds.unload < vehicle.cp.speeds.max;
				self.canScrollDown = vehicle.cp.speeds.unload > vehicle.cp.speeds.minUnload;
			end;

		elseif pg == 6 then
			if fn == "changeWaitTime" then
				self.canScrollUp = courseplay:getCanHaveWaitTime(vehicle);
				self.canScrollDown = self.canScrollUp and vehicle.cp.waitTime > 0;
			elseif fn == 'changeDebugChannelSection' then
				self.canScrollUp = courseplay.debugChannelSection > 1;
				self.canScrollDown = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
			end;

		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				self.canScrollUp = vehicle.cp.mode == 4 or vehicle.cp.mode == 6;
				self.canScrollDown = self.canScrollUp;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				self.canScrollUp = vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7 or vehicle.cp.mode == 8;
				self.canScrollDown = self.canScrollUp;
			end;

		elseif pg == 8 then
			if fn == "setFieldEdgePath" then
				self.canScrollUp = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
				self.canScrollDown   = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "changeWorkWidth" then
				self.canScrollUp =   true;
				self.canScrollDown = vehicle.cp.workWidth > 0.1;
			end;
		end;

	elseif self.overlay ~= nil then
		self.show = true;

		--CONDITIONAL DISPLAY
		--Global
		if pg == "global" then
			if fn == "showSaveCourseForm" and prm == "course" then
				self.show = vehicle.cp.canDrive and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and vehicle.Waypoints ~= nil and #(vehicle.Waypoints) ~= 0;
			end;

		--Page 1
		elseif pg == 1 then
			if fn == "setCpMode" then
				self.show = vehicle.cp.canSwitchMode and not vehicle.cp.distanceCheck;
			elseif fn == "clearCustomFieldEdge" or fn == "toggleCustomFieldEdgePathShow" then
				self.show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated;
			elseif fn == "setCustomFieldEdgePathNumber" then
				if prm < 0 then
					self.show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
				elseif prm > 0 then
					self.show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				end;
			elseif fn == 'toggleFindFirstWaypoint' then
				self.show = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused;
			elseif fn == 'stop_record' or fn == 'setRecordingPause' or fn == 'delete_waypoint' or fn == 'set_waitpoint' or fn == 'set_crossing' or fn == 'setRecordingTurnManeuver' or fn == 'change_DriveDirection' then
				self.show = vehicle.cp.isRecording or vehicle.cp.recordingIsPaused;
			end;

		--Page 2
		elseif pg == 2 then
			if fn == "reloadCoursesFromXML" then
				self.show = g_server ~= nil;
			elseif fn == "showSaveCourseForm" and prm == "filter" then
				self.show = not vehicle.cp.hud.choose_parent;
			elseif fn == "shiftHudCourses" then
				if prm < 0 then
					self.show = vehicle.cp.hud.courseListPrev;
				elseif prm > 0 then
					self.show = vehicle.cp.hud.courseListNext;
				end;
			end;
		elseif pg == -2 then
			self.show = vehicle.cp.hud.content.pages[2][prm][1].text ~= nil;

		--Page 3
		elseif pg == 3 then
			if fn == "changeTurnRadius" and prm < 0 then
				self.show = vehicle.cp.turnRadius > 0;
			elseif fn == "changeFollowAtFillLevel" then
				if prm < 0 then
					self.show = vehicle.cp.followAtFillLevel > 0;
				elseif prm > 0 then
					self.show = vehicle.cp.followAtFillLevel < 100;
				end;
			elseif fn == "changeDriveOnAtFillLevel" then 
				if prm < 0 then
					self.show = vehicle.cp.driveOnAtFillLevel > 0;
				elseif prm > 0 then
					self.show = vehicle.cp.driveOnAtFillLevel < 100;
				end;
			elseif fn == 'changeRefillUntilPct' then 
				if prm < 0 then
					self.show = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct > 1;
				elseif prm > 0 then
					self.show = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct < 100;
				end;
			end;

		--Page 4
		elseif pg == 4 then
			if fn == 'selectAssignedCombine' then
				self.show = not vehicle.cp.searchCombineAutomatically;
				if self.show and prm < 0 then
					self.show = vehicle.cp.selectedCombineNumber > 0;
				end;
			elseif fn == 'setSearchCombineOnField' then
				self.show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically;
				if self.show then
					if prm < 0 then
						self.show = vehicle.cp.searchCombineOnField > 0;
					else
						self.show = vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
					end;
				end;
			elseif fn == 'removeActiveCombineFromTractor' then
				self.show = vehicle.cp.activeCombine ~= nil;
			end;

		--Page 5
		elseif pg == 5 then
			if fn == 'changeTurnSpeed' then
				if prm < 0 then
					self.show = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
				elseif prm > 0 then
					self.show = vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeFieldSpeed' then
				if prm < 0 then
					self.show = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
				elseif prm > 0 then
					self.show = vehicle.cp.speeds.field < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeMaxSpeed' then
				if prm < 0 then
					self.show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
				elseif prm > 0 then
					self.show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeUnloadSpeed' then
				if prm < 0 then
					self.show = vehicle.cp.speeds.unload > vehicle.cp.speeds.minUnload;
				elseif prm > 0 then
					self.show = vehicle.cp.speeds.unload < vehicle.cp.speeds.max;
				end;
			end;

		--Page 6
		elseif pg == 6 then
			if fn == "changeWaitTime" then
				self.show = courseplay:getCanHaveWaitTime(vehicle);
				if self.show and prm < 0 then
					self.show = vehicle.cp.waitTime > 0;
				end;
			elseif fn == "toggleDebugChannel" then
				self.show = prm >= courseplay.debugChannelSectionStart and prm <= courseplay.debugChannelSectionEnd;
			elseif fn == "changeDebugChannelSection" then
				if prm < 0 then
					self.show = courseplay.debugChannelSection > 1;
				elseif prm > 0 then
					self.show = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
				end;
			end;

		--Page 7
		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				self.show = vehicle.cp.mode == 4 or vehicle.cp.mode == 6;
			elseif fn == "toggleSymmetricLaneChange" then
				self.show = vehicle.cp.mode == 4 or vehicle.cp.mode == 6 and vehicle.cp.laneOffset ~= 0;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				self.show = vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7;
			elseif fn == "switchDriverCopy" and prm < 0 then
				self.show = vehicle.cp.selectedDriverNumber > 0;
			elseif fn == "copyCourse" then
				self.show = vehicle.cp.hasFoundCopyDriver;
			end;

		--Page 8
		elseif pg == 8 then
			if fn == 'toggleSucHud' then
				self.show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "toggleSelectedFieldEdgePathShow" then
				self.show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "setFieldEdgePath" then
				self.show = courseplay.fields.numAvailableFields > 0;
				if self.show then
					if prm < 0 then
						self.show = vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
					elseif prm > 0 then
						self.show = vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
					end;
				end;
			elseif fn == "changeWorkWidth" and prm < 0 then
				self.show = vehicle.cp.workWidth > 0.1;
			elseif fn == "switchStartingDirection" then
				self.show = vehicle.cp.hasStartingCorner;
			elseif fn == 'setHeadlandDir' or fn == 'setHeadlandOrder' then
				self.show = vehicle.cp.headland.numLanes > 0;
			elseif fn == 'setHeadlandNumLanes' then
				if prm < 0 then
					self.show = vehicle.cp.headland.numLanes > 0;
				elseif prm > 0 then
					self.show = vehicle.cp.headland.numLanes < vehicle.cp.headland.maxNumLanes;
				end;
			elseif fn == "generateCourse" then
				self.show = vehicle.cp.hasValidCourseGenerationData;
			end;
		end;

		
		if self.show and not self.isHidden then
			-- set color
			local currentColor = self.overlay.curColor;
			local targetColor = currentColor;
			local hoverColor = 'hover';
			if fn == 'openCloseHud' then
				hoverColor = 'closeRed';
			end;

			if not self.isDisabled and not self.isActive and not self.isHovered and self.canBeClicked and not self.isClicked then
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
	if self.overlay and colorName and self.overlay.curColor ~= colorName and courseplay.hud.colors[colorName] and #courseplay.hud.colors[colorName] == 4 then
		self.overlay:setColor(unpack(courseplay.hud.colors[colorName]));
		self.overlay.curColor = colorName;
	end;
end;

function courseplay.button:setOffset(x_off, y_off)
	x_off = x_off or 0
	y_off = y_off or 0
	
	local width = self.x2 - self.x
	local height = self.y2 - self.y
	self.x = self.x_init + x_off
	self.y = self.y_init + y_off
	self.x2 = self.x + width
	self.y2 = self.y + height
	self.overlay.x = self.x_init + x_off
	self.overlay.y = self.y_init + y_off
end

function courseplay.button:setToolTip(text)
	if self.toolTip ~= text then
		self.toolTip = text;
	end;
end;

function courseplay.button:delete()
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

	if page == 2 then 
		for _,button in pairs(vehicle.cp.buttons[-2]) do
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
			button:delete();
		end;
	end;
end;
