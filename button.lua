function courseplay:register_button(self, hudPage, img, function_to_call, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea)
	local overlay = nil;
	if img and img ~= "blank.dds" then
		overlay = Overlay:new(img, Utils.getFilename("img/" .. img, courseplay.path), x, y, width, height);
	end;

	if isMouseWheelArea == nil then
		isMouseWheelArea = false;
	end;
	if hoverText == nil then
		hoverText = false;
	end;

	local button = { 
		page = hudPage, 
		overlay = overlay, 
		overlays = { overlay }, 
		function_to_call = function_to_call, 
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
		isMouseWheelArea = isMouseWheelArea and function_to_call ~= nil,
		canBeClicked = not isMouseWheelArea and function_to_call ~= nil,
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
	if function_to_call == "toggleDebugChannel" then
		local col = ((button.parameter-1) % courseplay.numDebugChannelButtonsPerLine) + 1;
		local line = math.ceil(button.parameter / courseplay.numDebugChannelButtonsPerLine);

		--space in dds: 16 x, 2 y
		local uvX1,uvX2 = (col-1)/16, col/16;
		local uvY1 = 1 - (line * (courseplay.numDebugChannelButtonsPerLine/courseplay.numAvailableDebugChannels));
		local uvY2 = uvY1 + (courseplay.numDebugChannelButtonsPerLine/courseplay.numAvailableDebugChannels);
		setOverlayUVs(button.overlay.overlayId, uvX1,uvY1, uvX1,uvY2, uvX2,uvY1, uvX2,uvY2);
	end;

	table.insert(self.cp.buttons[tostring(hudPage)], button);
	return #(self.cp.buttons[tostring(hudPage)]);
end

function courseplay:renderButtons(self, page)
	for _,button in pairs(self.cp.buttons.global) do
		courseplay:renderButton(self, button);
	end;

	for _,button in pairs(self.cp.buttons[tostring(page)]) do
		courseplay:renderButton(self, button);
	end;

	if page == 2 then 
		for _,button in pairs(self.cp.buttons["-2"]) do
			courseplay:renderButton(self, button);
		end;
	end;
end;

function courseplay:renderButton(self, button)
	local pg, fn, prm = button.page, button.function_to_call, button.parameter;

	--mouseWheelAreas conditionals
	if button.isMouseWheelArea then
		if pg == 1 then
			if fn == "setCustomFieldEdgePathNumber" then
				button.canScrollUp =   self.cp.fieldEdge.customField.isCreated and self.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				button.canScrollDown = self.cp.fieldEdge.customField.isCreated and self.cp.fieldEdge.customField.fieldNum > 0;
			end;

		elseif pg == 2 then
			if fn == "shiftHudCourses" then
				button.canScrollUp =   self.cp.hud.courseListPrev == true;
				button.canScrollDown = self.cp.hud.courseListNext == true;
			end;

		elseif pg == 3 then
			if fn == "changeTurnRadius" then
				button.canScrollUp =   true;
				button.canScrollDown = self.cp.turnRadius > 0;
			elseif fn == "change_required_fill_level" then
				button.canScrollUp =   self.cp.followAtFillLevel < 100;
				button.canScrollDown = self.cp.followAtFillLevel > 0;
			elseif fn == "change_required_fill_level_for_drive_on" then
				button.canScrollUp =   self.cp.driveOnAtFillLevel < 100;
				button.canScrollDown = self.cp.driveOnAtFillLevel > 0;
			end;

		elseif pg == 5 then
			if fn == "change_turn_speed" then
				button.canScrollUp =   self.cp.speeds.turn < 60/3600;
				button.canScrollDown = self.cp.speeds.turn >  5/3600;
			elseif fn == "change_field_speed" then
				button.canScrollUp =   self.cp.speeds.field < 60/3600;
				button.canScrollDown = self.cp.speeds.field >  5/3600;
			elseif fn == "change_max_speed" then
				button.canScrollUp =   self.cp.speeds.useRecordingSpeed == false and self.cp.speeds.max < 60/3600;
				button.canScrollDown = self.cp.speeds.useRecordingSpeed == false and self.cp.speeds.max >  5/3600;
			elseif fn == "change_unload_speed" then
				button.canScrollUp =   self.cp.speeds.unload < 60/3600;
				button.canScrollDown = self.cp.speeds.unload >  3/3600;
			end;

		elseif pg == 6 then
			if fn == "changeWaitTime" then
				button.canScrollUp = not (self.cp.mode == 3 or self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7);
				button.canScrollDown = button.canScrollUp and self.cp.waitTime > 0;
			end;

		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				button.canScrollUp = self.cp.mode == 4 or self.cp.mode == 6;
				button.canScrollDown = button.canScrollUp;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				button.canScrollUp = self.cp.mode == 3 or self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7;
				button.canScrollDown = button.canScrollUp;
			end;

		elseif pg == 8 then
			if fn == "setFieldEdgePath" then
				button.canScrollUp   = courseplay.fields.numAvailableFields > 0 and self.cp.fieldEdge.selectedField.fieldNum > 0;
				button.canScrollDown = courseplay.fields.numAvailableFields > 0 and self.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
			elseif fn == "changeWorkWidth" then
				button.canScrollUp =   true;
				button.canScrollDown = self.cp.workWidth > 0.1;
			end;
		end;

	elseif button.overlay ~= nil then
		button.show = true;

		--CONDITIONAL DISPLAY
		--Global
		if pg == "global" then
			if fn == "showSaveCourseForm" and prm == "course" then
				button.show = self.cp.canDrive and not self.record and not self.record_pause and self.Waypoints ~= nil and #(self.Waypoints) ~= 0;
			end;

		--Page 1
		elseif pg == 1 then
			if fn == "setAiMode" then
				button.show = self.cp.canSwitchMode;
			elseif fn == "clearCustomFieldEdge" or fn == "toggleCustomFieldEdgePathShow" then
				button.show = not self.cp.canDrive and self.cp.fieldEdge.customField.isCreated;
			elseif fn == "setCustomFieldEdgePathNumber" then
				if prm < 0 then
					button.show = not self.cp.canDrive and self.cp.fieldEdge.customField.isCreated and self.cp.fieldEdge.customField.fieldNum > 0;
				elseif prm > 0 then
					button.show = not self.cp.canDrive and self.cp.fieldEdge.customField.isCreated and self.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				end;
			end;

		--Page 2
		elseif pg == 2 then
			if fn == "reloadCoursesFromXML" then
				button.show = g_server ~= nil;
			elseif fn == "showSaveCourseForm" and prm == "filter" then
				button.show = not self.cp.hud.choose_parent;
			elseif fn == "shiftHudCourses" then
				if prm < 0 then
					button.show = self.cp.hud.courseListPrev;
				elseif prm > 0 then
					button.show = self.cp.hud.courseListNext;
				end;
			end;
		elseif pg == -2 then
			button.show = self.cp.hud.content.pages[2][prm][1].text ~= nil;

		--Page 3
		elseif pg == 3 then
			if fn == "changeTurnRadius" and prm < 0 then
				button.show = self.cp.turnRadius > 0;
			elseif fn == "change_required_fill_level" then
				if prm < 0 then
					button.show = self.cp.followAtFillLevel > 0;
				elseif prm > 0 then
					button.show = self.cp.followAtFillLevel < 100;
				end;
			elseif fn == "change_required_fill_level_for_drive_on" then 
				if prm < 0 then
					button.show = self.cp.driveOnAtFillLevel > 0;
				elseif prm > 0 then
					button.show = self.cp.driveOnAtFillLevel < 100;
				end;
			end;

		--Page 4
		elseif pg == 4 then
			if fn == "switch_combine" and prm < 0 then
				button.show = self.selected_combine_number > 0;
			end;

		--Page 5
		elseif pg == 5 then
			if fn == "change_turn_speed" then
				if prm < 0 then
					button.show = self.cp.speeds.turn >  5/3600;
				elseif prm > 0 then
					button.show = self.cp.speeds.turn < 60/3600;
				end;
			elseif fn == "change_field_speed" then
				if prm < 0 then
					button.show = self.cp.speeds.field >  5/3600;
				elseif prm > 0 then
					button.show = self.cp.speeds.field < 60/3600;
				end;
			elseif fn == "change_max_speed" then
				if prm < 0 then
					button.show = not self.cp.speeds.useRecordingSpeed and self.cp.speeds.max >  5/3600;
				elseif prm > 0 then
					button.show = not self.cp.speeds.useRecordingSpeed and self.cp.speeds.max < 60/3600;
				end;
			elseif fn == "change_unload_speed" then
				if prm < 0 then
					button.show = self.cp.speeds.unload >  3/3600;
				elseif prm > 0 then
					button.show = self.cp.speeds.unload < 60/3600;
				end;
			end;

		--Page 6
		elseif pg == 6 then
			if fn == "changeWaitTime" then
				button.show = not (self.cp.mode == 3 or self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7);
				if prm < 0 and button.show then
					button.show = self.cp.waitTime > 0;
				end;
			elseif fn == "toggleDebugChannel" then
				button.show = prm >= courseplay.debugChannelSectionStart and prm <= courseplay.debugChannelSectionEnd;
			elseif fn == "changeDebugChannelSection" then
				if prm < 0 then
					button.show = courseplay.debugChannelSection > 1;
				elseif prm > 0 then
					button.show = courseplay.debugChannelSection < math.ceil(courseplay.numAvailableDebugChannels / courseplay.numDebugChannelButtonsPerLine);
				end;
			end;

		--Page 7
		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				button.show = self.cp.mode == 4 or self.cp.mode == 6;
			elseif fn == "toggleSymmetricLaneChange" then
				button.show = self.cp.mode == 4 or self.cp.mode == 6 and self.cp.laneOffset ~= 0;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				button.show = self.cp.mode == 3 or self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7;
			elseif fn == "switchDriverCopy" and prm < 0 then
				button.show = self.cp.selectedDriverNumber > 0;
			elseif fn == "copyCourse" then
				button.show = self.cp.hasFoundCopyDriver;
			end;

		--Page 8
		elseif pg == 8 then
			if fn == "toggleSelectedFieldEdgePathShow" then
				button.show = courseplay.fields.numAvailableFields > 0 and self.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "setFieldEdgePath" then
				button.show = courseplay.fields.numAvailableFields > 0;
				if button.show then
					if prm < 0 then
						button.show = self.cp.fieldEdge.selectedField.fieldNum > 0;
					elseif prm > 0 then
						button.show = self.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
					end;
				end;
			elseif fn == "changeWorkWidth" and prm < 0 then
				button.show = self.cp.workWidth > 0.1;
			elseif fn == "switchStartingDirection" then
				button.show = self.cp.hasStartingCorner;
			elseif fn == "setHeadlandLanes" then
				if prm < 0 then
					button.show = self.cp.headland.numLanes > -1;
				elseif prm > 0 then
					button.show = self.cp.headland.numLanes <  1;
				end;
			elseif fn == "generateCourse" then
				button.show = self.cp.hasValidCourseGenerationData;
			end;
		end;

		
		if button.show and not button.isHidden then
			local colors = courseplay.hud.colors;
			local currentColor = courseplay:getButtonColor(button);
			local targetColor = currentColor;
			local hoverColor = colors.hover;
			if fn == "openCloseHud" then
				hoverColor = colors.closeRed;
			end;

			if not button.isDisabled and not button.isActive and not button.isHovered and button.canBeClicked and not button.isClicked and not courseplay:colorsMatch(currentColor, colors.white) then
				targetColor = colors.white;
			elseif button.isDisabled and not courseplay:colorsMatch(currentColor, colors.whiteDisabled) then
				targetColor = colors.whiteDisabled;
			elseif not button.isDisabled and button.canBeClicked and button.isClicked and not fn == "openCloseHud" then
				targetColor = colors.activeRed;
			elseif button.isHovered and ((button.page == 9 and button.isActive and button.canBeClicked and not button.isClicked) or (not button.isDisabled and not button.isActive and button.canBeClicked and not button.isClicked)) and not courseplay:colorsMatch(currentColor, hoverColor) then
				targetColor = hoverColor;
			elseif button.isActive and (button.page ~= 9 or (button.page == 9 and not button.isHovered)) and not courseplay:colorsMatch(currentColor, colors.activeGreen) then
				targetColor = colors.activeGreen;
			end;

			-- set colors
			if not courseplay:colorsMatch(currentColor, targetColor) then
				courseplay:setButtonColor(button, targetColor)
			end;

			button.overlay:render();
		end;
	end;	--elseif button.overlay ~= nil
end;


function courseplay:setButtonColor(button, color)
	if button == nil or button.overlay == nil or color == nil or table.getn(color) ~= 4 then
		return;
	end;
	button.overlay:setColor(unpack(color));
end;

function courseplay:getButtonColor(button)
	if button == nil or button.overlay == nil or button.overlay.r == nil or button.overlay.g == nil or button.overlay.b == nil or button.overlay.a == nil then
		return nil;
	end;
	local r,g,b,a = button.overlay.r, button.overlay.g, button.overlay.b, button.overlay.a;
	if r == nil or g == nil or b == nil or a == nil then
		return nil;
	end;
	return { r,g,b,a };
end;

function courseplay:colorsMatch(color1, color2)
	if color1 == nil or color2 == nil then
		return nil;
	end;
	return Utils.areListsEqual(color1, color2, false);
end;

function courseplay.button.setOffset(button, x_off, y_off)
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

function courseplay.button.addOverlay(button, index, img)
	local width = button.x2 - button.x
	local height = button.y2 - button.y
	button.overlays[index] = Overlay:new(img, Utils.getFilename("img/" .. img, courseplay.path), button.x, button.y, width, height);
end

function courseplay.button.setOverlay(button, index)
	button.overlay = button.overlays[index]
	-- the offset of the button might have changed...
	button.overlay.x = button.x
	button.overlay.y = button.y
end

function courseplay.button.deleteButtonOverlays(vehicle)
	for k,buttonSection in pairs(vehicle.cp.buttons) do
		for i,button in pairs(buttonSection) do
			if button.overlays ~= nil then
				for j,overlay in pairs(button.overlays) do
					if overlay.overlayId ~= nil and overlay.delete ~= nil then
						overlay:delete();
					end;
				end;
			end;
			--NOTE: deleting single overlays not necessary since all overlay in button.overlays have already been deleted.
		end;
	end;
end;
