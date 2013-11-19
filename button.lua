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
		if pg == 2 then
			if fn == "shiftHudCourses" then
				button.canScrollUp =   self.cp.hud.courseListPrev == true;
				button.canScrollDown = self.cp.hud.courseListNext == true;
			end;

		elseif pg == 3 then
			if fn == "change_turn_radius" then
				button.canScrollUp =   true;
				button.canScrollDown = self.turn_radius > 0;
			elseif fn == "change_required_fill_level" then
				button.canScrollUp =   self.required_fill_level_for_follow < 100;
				button.canScrollDown = self.required_fill_level_for_follow > 0;
			elseif fn == "change_required_fill_level_for_drive_on" then
				button.canScrollUp =   self.required_fill_level_for_drive_on < 100;
				button.canScrollDown = self.required_fill_level_for_drive_on > 0;
			end;

		elseif pg == 5 then
			if fn == "change_turn_speed" then
				button.canScrollUp =   self.turn_speed < 60/3600;
				button.canScrollDown = self.turn_speed >  5/3600;
			elseif fn == "change_field_speed" then
				button.canScrollUp =   self.field_speed < 60/3600;
				button.canScrollDown = self.field_speed >  5/3600;
			elseif fn == "change_max_speed" then
				button.canScrollUp =   self.use_speed == false and self.max_speed < 60/3600;
				button.canScrollDown = self.use_speed == false and self.max_speed >  5/3600;
			elseif fn == "change_unload_speed" then
				button.canScrollUp =   self.unload_speed < 60/3600;
				button.canScrollDown = self.unload_speed >  3/3600;
			end;

		elseif pg == 7 then
			if fn == "change_wait_time" then
				button.canScrollUp =   true;
				button.canScrollDown = self.waitTime > 0;
			elseif fn == "changeWpOffsetX" or fn == "changeWpOffsetZ" then
				button.canScrollUp = self.ai_mode == 3 or self.ai_mode == 4 or self.ai_mode == 6 or self.ai_mode == 7;
				button.canScrollDown = button.canScrollUp;
			end;

		elseif pg == 8 then
			if fn == "changeWorkWidth" then
				button.canScrollUp =   true;
				button.canScrollDown = self.toolWorkWidht > 0.1;
			end;
		end;

	elseif button.overlay ~= nil then
		button.show = true;

		--CONDITIONAL DISPLAY
		--Global
		if pg == "global" then
			if fn == "showSaveCourseForm" and prm == "course" then
				button.show = self.play and not self.record and not self.record_pause and self.Waypoints ~= nil and table.getn(self.Waypoints) ~= 0;
			end;

		--Page 1
		elseif pg == 1 then
			if fn == "setAiMode" then
				button.show = self.cp.canSwitchMode;
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
			if fn == "change_turn_radius" and prm < 0 then
				button.show = self.turn_radius > 0;
			elseif fn == "change_required_fill_level" then
				if prm < 0 then
					button.show = self.required_fill_level_for_follow > 0;
				elseif prm > 0 then
					button.show = self.required_fill_level_for_follow < 100;
				end;
			elseif fn == "change_required_fill_level_for_drive_on" then 
				if prm < 0 then
					button.show = self.required_fill_level_for_drive_on > 0;
				elseif prm > 0 then
					button.show = self.required_fill_level_for_drive_on < 100;
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
					button.show = self.turn_speed >  5/3600;
				elseif prm > 0 then
					button.show = self.turn_speed < 60/3600;
				end;
			elseif fn == "change_field_speed" then
				if prm < 0 then
					button.show = self.field_speed >  5/3600;
				elseif prm > 0 then
					button.show = self.field_speed < 60/3600;
				end;
			elseif fn == "change_max_speed" then
				if prm < 0 then
					button.show = not self.use_speed and self.max_speed >  5/3600;
				elseif prm > 0 then
					button.show = not self.use_speed and self.max_speed < 60/3600;
				end;
			elseif fn == "change_unload_speed" then
				if prm < 0 then
					button.show = self.unload_speed >  3/3600;
				elseif prm > 0 then
					button.show = self.unload_speed < 60/3600;
				end;
			end;

		--Page 6
		elseif pg == 6 then
			if fn == "setFieldEdgePath" and self.cp.selectedFieldEdgePathNumber ~= nil then
				if prm < 0 then
					button.show = self.cp.selectedFieldEdgePathNumber > 0;
				elseif prm > 0 then
					button.show = self.cp.selectedFieldEdgePathNumber < courseplay.fields.highestFieldNumber;
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
			if fn == "change_wait_time" and prm < 0 then
				button.show = self.waitTime > 0;
			elseif fn == "changeWpOffsetX" or fn == "changeWpOffsetZ" then
				button.show = self.ai_mode == 3 or self.ai_mode == 4 or self.ai_mode == 6 or self.ai_mode == 7;
			elseif fn == "toggleSymmetricLaneChange" then
				button.show = self.ai_mode == 4 or self.ai_mode == 6 and self.WpOffsetX ~= 0;
			elseif fn == "switchDriverCopy" and prm < 0 then
				button.show = self.cp.selectedDriverNumber > 0;
			elseif fn == "copyCourse" then
				button.show = self.cp.hasFoundCopyDriver;
			end;

		--Page 8
		elseif pg == 8 then
			if fn == "changeWorkWidth" and prm < 0 then
				button.show = self.toolWorkWidht > 0.1;
			elseif fn == "switchStartingDirection" then
				button.show = self.cp.hasStartingCorner;
			elseif fn == "setHeadlandLanes" and prm < 0 then
				button.show = self.cp.headland.numLanes > -1;
			elseif fn == "setHeadlandLanes" and prm > 0 then
				button.show = self.cp.headland.numLanes <  1;
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
			if button.overlay ~= nil and button.overlay.overlayId ~= nil then
				button.overlay:delete();
			end;
			if button.overlays ~= nil then
				for j,overlay in pairs(button.overlays) do
					if overlay.overlayId ~= nil then
						overlay:delete();
					end;
				end;
			end;
		end;
	end;
end;
