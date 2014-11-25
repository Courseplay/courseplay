function courseplay.button:create(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip)
	-- self = courseplay.button

	local overlay;
	if img and img ~= "blank.dds" then
		overlay = Overlay:new(img, Utils.getFilename("img/" .. img, courseplay.path), x, y, width, height);
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

	local button = { 
		page = hudPage, 
		overlay = overlay, 
		overlays = { overlay }, 
		functionToCall = functionToCall, 
		parameter = parameter, 
		x_init = x,
		x = x,
		x2 = (x + width),
		y_init = y,
		y = y,
		y2 = (y + height),
		row = hudRow,
		hoverText = hoverText,
		color = courseplay.hud.colors.white,
		toolTip = toolTip,
		isMouseWheelArea = isMouseWheelArea and functionToCall ~= nil,
		isToggleButton = isToggleButton,
		canBeClicked = not isMouseWheelArea and functionToCall ~= nil,
		show = true,
		isClicked = false,
		isActive = false,
		isDisabled = false,
		isHovered = false,
		isHidden = false
	};
	if modifiedParameter then 
		button.modifiedParameter = modifiedParameter;
	end
	if isMouseWheelArea then
		button.canScrollUp   = true;
		button.canScrollDown = true;
	end;

	self:setSpecialButtonUVs(functionToCall, button);

	table.insert(vehicle.cp.buttons[hudPage], button);
	return #(vehicle.cp.buttons[hudPage]);
end;

function courseplay.button:setSpecialButtonUVs(functionToCall, button)
	if functionToCall == 'toggleDebugChannel' then
		local col = ((button.parameter-1) % courseplay.numDebugChannelButtonsPerLine) + 1;
		local line = math.ceil(button.parameter / courseplay.numDebugChannelButtonsPerLine);

		--space in dds: 16 x, 2 y
		local uvX1,uvX2 = (col-1)/16, col/16;
		local uvY1 = 1 - (line * (courseplay.numDebugChannelButtonsPerLine/courseplay.numAvailableDebugChannels));
		local uvY2 = uvY1 + (courseplay.numDebugChannelButtonsPerLine/courseplay.numAvailableDebugChannels);
		setOverlayUVs(button.overlay.overlayId, uvX1,uvY1, uvX1,uvY2, uvX2,uvY1, uvX2,uvY2);
	end;
end;

function courseplay.button:renderButtons(vehicle, page)
	-- self = courseplay.button

	local hoveredButton;

	for _,button in pairs(vehicle.cp.buttons.global) do
		if self:renderButton(vehicle, button) then
			hoveredButton = button;
		end;
	end;

	for _,button in pairs(vehicle.cp.buttons[page]) do
		if self:renderButton(vehicle, button) then
			hoveredButton = button;
		end;
	end;

	if page == 2 then 
		for _,button in pairs(vehicle.cp.buttons[-2]) do
			if self:renderButton(vehicle, button) then
				hoveredButton = button;
			end;
		end;
	end;

	if vehicle.cp.suc.active then
		if self:renderButton(vehicle, vehicle.cp.suc.fruitNegButton) then
			hoveredButton = vehicle.cp.suc.fruitNegButton;
		end;
		if self:renderButton(vehicle, vehicle.cp.suc.fruitPosButton) then
			hoveredButton = vehicle.cp.suc.fruitPosButton;
		end;
	end;

	-- set currently hovered button
	courseplay.button:setHoveredButton(vehicle, hoveredButton);
end;

function courseplay.button:setHoveredButton(vehicle, button)
	if vehicle.cp.buttonHovered == button then
		return;
	end;
	vehicle.cp.buttonHovered = button;

	-- set toolTip
	if vehicle.cp.buttonHovered ~= nil and vehicle.cp.buttonHovered.toolTip ~= nil then
		courseplay:setToolTip(vehicle, vehicle.cp.buttonHovered.toolTip);
	elseif vehicle.cp.buttonHovered == nil then
		courseplay:setToolTip(vehicle, nil);
	end;
end;

function courseplay.button:renderButton(vehicle, button)
	-- self = courseplay.button

	local pg, fn, prm = button.page, button.functionToCall, button.parameter;
	local hoveredButton = false;

	--mouseWheelAreas conditionals
	if button.isMouseWheelArea then
		if pg == 1 then
			if fn == "setCustomFieldEdgePathNumber" then
				button.canScrollUp =   vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				button.canScrollDown = vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
			end;

		elseif pg == 2 then
			if fn == "shiftHudCourses" then
				button.canScrollUp =   vehicle.cp.hud.courseListPrev == true;
				button.canScrollDown = vehicle.cp.hud.courseListNext == true;
			end;

		elseif pg == 3 then
			if fn == "changeTurnRadius" then
				button.canScrollUp =   true;
				button.canScrollDown = vehicle.cp.turnRadius > 0;
			elseif fn == "changeFollowAtFillLevel" then
				button.canScrollUp =   vehicle.cp.followAtFillLevel < 100;
				button.canScrollDown = vehicle.cp.followAtFillLevel > 0;
			elseif fn == "changeDriveOnAtFillLevel" then
				button.canScrollUp =   vehicle.cp.driveOnAtFillLevel < 100;
				button.canScrollDown = vehicle.cp.driveOnAtFillLevel > 0;
			elseif fn == 'changeRefillUntilPct' then
				button.canScrollUp =   (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct < 100;
				button.canScrollDown = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct > 1;
			end;

		elseif pg == 4 then
			if fn == 'setSearchCombineOnField' then
				button.canScrollUp = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField > 0;
				button.canScrollDown = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
			end;

		elseif pg == 5 then
			if fn == 'changeTurnSpeed' then
				button.canScrollUp =   vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
				button.canScrollDown = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
			elseif fn == 'changeFieldSpeed' then
				button.canScrollUp =   vehicle.cp.speeds.field < vehicle.cp.speeds.max;
				button.canScrollDown = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
			elseif fn == 'changeMaxSpeed' then
				button.canScrollUp =   vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
				button.canScrollDown = vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
			elseif fn == 'changeUnloadSpeed' then
				button.canScrollUp =   vehicle.cp.speeds.unload < vehicle.cp.speeds.max;
				button.canScrollDown = vehicle.cp.speeds.unload > vehicle.cp.speeds.minUnload;
			end;

		elseif pg == 6 then
			if fn == "changeWaitTime" then
				button.canScrollUp = courseplay:getCanHaveWaitTime(vehicle);
				button.canScrollDown = button.canScrollUp and vehicle.cp.waitTime > 0;
			elseif fn == 'changeDebugChannelSection' then
				button.canScrollUp = courseplay.debugChannelSection > 1;
				button.canScrollDown = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
			end;

		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				button.canScrollUp = vehicle.cp.mode == 4 or vehicle.cp.mode == 6;
				button.canScrollDown = button.canScrollUp;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				button.canScrollUp = vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7 or vehicle.cp.mode == 8;
				button.canScrollDown = button.canScrollUp;
			end;

		elseif pg == 8 then
			if fn == "setFieldEdgePath" then
				button.canScrollUp = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
				button.canScrollDown   = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "changeWorkWidth" then
				button.canScrollUp =   true;
				button.canScrollDown = vehicle.cp.workWidth > 0.1;
			end;
		end;

	elseif button.overlay ~= nil then
		button.show = true;

		--CONDITIONAL DISPLAY
		--Global
		if pg == "global" then
			if fn == "showSaveCourseForm" and prm == "course" then
				button.show = vehicle.cp.canDrive and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and vehicle.Waypoints ~= nil and #(vehicle.Waypoints) ~= 0;
			end;

		--Page 1
		elseif pg == 1 then
			if fn == "setCpMode" then
				button.show = vehicle.cp.canSwitchMode and not vehicle.cp.distanceCheck;
			elseif fn == "clearCustomFieldEdge" or fn == "toggleCustomFieldEdgePathShow" then
				button.show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated;
			elseif fn == "setCustomFieldEdgePathNumber" then
				if prm < 0 then
					button.show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
				elseif prm > 0 then
					button.show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				end;
			elseif fn == 'toggleFindFirstWaypoint' then
				button.show = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused;
			elseif fn == 'stop_record' or fn == 'setRecordingPause' or fn == 'delete_waypoint' or fn == 'set_waitpoint' or fn == 'set_crossing' or fn == 'setRecordingTurnManeuver' or fn == 'change_DriveDirection' then
				button.show = vehicle.cp.isRecording or vehicle.cp.recordingIsPaused;
			end;

		--Page 2
		elseif pg == 2 then
			if fn == "reloadCoursesFromXML" then
				button.show = g_server ~= nil;
			elseif fn == "showSaveCourseForm" and prm == "filter" then
				button.show = not vehicle.cp.hud.choose_parent;
			elseif fn == "shiftHudCourses" then
				if prm < 0 then
					button.show = vehicle.cp.hud.courseListPrev;
				elseif prm > 0 then
					button.show = vehicle.cp.hud.courseListNext;
				end;
			end;
		elseif pg == -2 then
			button.show = vehicle.cp.hud.content.pages[2][prm][1].text ~= nil;

		--Page 3
		elseif pg == 3 then
			if fn == "changeTurnRadius" and prm < 0 then
				button.show = vehicle.cp.turnRadius > 0;
			elseif fn == "changeFollowAtFillLevel" then
				if prm < 0 then
					button.show = vehicle.cp.followAtFillLevel > 0;
				elseif prm > 0 then
					button.show = vehicle.cp.followAtFillLevel < 100;
				end;
			elseif fn == "changeDriveOnAtFillLevel" then 
				if prm < 0 then
					button.show = vehicle.cp.driveOnAtFillLevel > 0;
				elseif prm > 0 then
					button.show = vehicle.cp.driveOnAtFillLevel < 100;
				end;
			elseif fn == 'changeRefillUntilPct' then 
				if prm < 0 then
					button.show = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct > 1;
				elseif prm > 0 then
					button.show = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct < 100;
				end;
			end;

		--Page 4
		elseif pg == 4 then
			if fn == 'selectAssignedCombine' then
				button.show = not vehicle.cp.searchCombineAutomatically;
				if button.show and prm < 0 then
					button.show = vehicle.cp.selectedCombineNumber > 0;
				end;
			elseif fn == 'setSearchCombineOnField' then
				button.show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically;
				if button.show then
					if prm < 0 then
						button.show = vehicle.cp.searchCombineOnField > 0;
					else
						button.show = vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
					end;
				end;
			elseif fn == 'removeActiveCombineFromTractor' then
				button.show = vehicle.cp.activeCombine ~= nil;
			end;

		--Page 5
		elseif pg == 5 then
			if fn == 'changeTurnSpeed' then
				if prm < 0 then
					button.show = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
				elseif prm > 0 then
					button.show = vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeFieldSpeed' then
				if prm < 0 then
					button.show = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
				elseif prm > 0 then
					button.show = vehicle.cp.speeds.field < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeMaxSpeed' then
				if prm < 0 then
					button.show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
				elseif prm > 0 then
					button.show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeUnloadSpeed' then
				if prm < 0 then
					button.show = vehicle.cp.speeds.unload > vehicle.cp.speeds.minUnload;
				elseif prm > 0 then
					button.show = vehicle.cp.speeds.unload < vehicle.cp.speeds.max;
				end;
			end;

		--Page 6
		elseif pg == 6 then
			if fn == "changeWaitTime" then
				button.show = courseplay:getCanHaveWaitTime(vehicle);
				if button.show and prm < 0 then
					button.show = vehicle.cp.waitTime > 0;
				end;
			elseif fn == "toggleDebugChannel" then
				button.show = prm >= courseplay.debugChannelSectionStart and prm <= courseplay.debugChannelSectionEnd;
			elseif fn == "changeDebugChannelSection" then
				if prm < 0 then
					button.show = courseplay.debugChannelSection > 1;
				elseif prm > 0 then
					button.show = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
				end;
			end;

		--Page 7
		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				button.show = vehicle.cp.mode == 4 or vehicle.cp.mode == 6;
			elseif fn == "toggleSymmetricLaneChange" then
				button.show = vehicle.cp.mode == 4 or vehicle.cp.mode == 6 and vehicle.cp.laneOffset ~= 0;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				button.show = vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7;
			elseif fn == "switchDriverCopy" and prm < 0 then
				button.show = vehicle.cp.selectedDriverNumber > 0;
			elseif fn == "copyCourse" then
				button.show = vehicle.cp.hasFoundCopyDriver;
			end;

		--Page 8
		elseif pg == 8 then
			if fn == 'toggleSucHud' then
				button.show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "toggleSelectedFieldEdgePathShow" then
				button.show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "setFieldEdgePath" then
				button.show = courseplay.fields.numAvailableFields > 0;
				if button.show then
					if prm < 0 then
						button.show = vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
					elseif prm > 0 then
						button.show = vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
					end;
				end;
			elseif fn == "changeWorkWidth" and prm < 0 then
				button.show = vehicle.cp.workWidth > 0.1;
			elseif fn == "switchStartingDirection" then
				button.show = vehicle.cp.hasStartingCorner;
			elseif fn == 'setHeadlandDir' or fn == 'setHeadlandOrder' then
				button.show = vehicle.cp.headland.numLanes > 0;
			elseif fn == 'setHeadlandNumLanes' then
				if prm < 0 then
					button.show = vehicle.cp.headland.numLanes > 0;
				elseif prm > 0 then
					button.show = vehicle.cp.headland.numLanes < vehicle.cp.headland.maxNumLanes;
				end;
			elseif fn == "generateCourse" then
				button.show = vehicle.cp.hasValidCourseGenerationData;
			end;
		end;

		
		if button.show and not button.isHidden then
			-- set color
			local currentColor = button.overlay.curColor;
			local targetColor = currentColor;
			local hoverColor = 'hover';
			if fn == 'openCloseHud' then
				hoverColor = 'closeRed';
			end;

			if not button.isDisabled and not button.isActive and not button.isHovered and button.canBeClicked and not button.isClicked then
				targetColor = 'white';
			elseif button.isDisabled then
				targetColor = 'whiteDisabled';
			elseif not button.isDisabled and button.canBeClicked and button.isClicked and fn ~= 'openCloseHud' then
				targetColor = 'activeRed';
			elseif button.isHovered and ((not button.isDisabled and button.isToggleButton and button.isActive and button.canBeClicked and not button.isClicked) or (not button.isDisabled and not button.isActive and button.canBeClicked and not button.isClicked)) then
				targetColor = hoverColor;
				hoveredButton = true;
				if button.isToggleButton then
					--print(string.format('button %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> hoverColor', fn, g_updateLoopIndex, tostring(button.isHovered), tostring(button.isActive), tostring(button.isDisabled), tostring(button.canBeClicked)));
				end;
			elseif button.isActive and (not button.isToggleButton or (button.isToggleButton and not button.isHovered)) then
				targetColor = 'activeGreen';
				if button.isToggleButton then
					--print(string.format('button %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> activeGreen', fn, g_updateLoopIndex, tostring(button.isHovered), tostring(button.isActive), tostring(button.isDisabled), tostring(button.canBeClicked)));
				end;
			end;

			if currentColor ~= targetColor then
				self:setButtonColor(button, targetColor);
			end;

			-- render
			button.overlay:render();
		end;
	end;	--elseif button.overlay ~= nil

	return hoveredButton;
end;


function courseplay.button:setButtonColor(button, colorName)
	if button and button.overlay and colorName and courseplay.hud.colors[colorName] and #courseplay.hud.colors[colorName] == 4 then
		button.overlay:setColor(unpack(courseplay.hud.colors[colorName]));
		button.overlay.curColor = colorName;
	end;
end;

function courseplay.button:setOffset(button, x_off, y_off)
	x_off = x_off or 0
	y_off = y_off or 0
	
	local width = button.x2 - button.x
	local height = button.y2 - button.y
	button.x = button.x_init + x_off
	button.y = button.y_init + y_off
	button.x2 = button.x + width
	button.y2 = button.y + height
	button.overlay.x = button.x_init + x_off
	button.overlay.y = button.y_init + y_off
end

function courseplay.button:addOverlay(button, index, img)
	local width = button.x2 - button.x
	local height = button.y2 - button.y
	button.overlays[index] = Overlay:new(img, Utils.getFilename("img/" .. img, courseplay.path), button.x, button.y, width, height);
end

function courseplay.button:setOverlay(button, index)
	button.overlay = button.overlays[index]
	-- the offset of the button might have changed...
	button.overlay.x = button.x
	button.overlay.y = button.y
end

function courseplay.button:deleteButtonOverlays(vehicle)
	for k,buttonSection in pairs(vehicle.cp.buttons) do
		for i,button in pairs(buttonSection) do
			if button.overlays ~= nil then
				for j,overlay in pairs(button.overlays) do
					if overlay.overlayId ~= nil and overlay.delete ~= nil then
						overlay:delete();
					end;
				end;
			end;
			--NOTE: deleting single overlays not necessary since all overlays in button.overlays have already been deleted.
		end;
	end;
end;
