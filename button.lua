function courseplay:register_button(self, hud_page, img, function_to_call, parameter, x, y, width, height, hud_row, modifiedParameter, showHideVariable)
	local overlay_path = Utils.getFilename("img/" .. img, self.cp_directory);
	local overlay = Overlay:new(img, overlay_path, x, y, width, height);

	button = { 
		page = hud_page, 
		overlay = overlay, 
		function_to_call = function_to_call, 
		parameter = parameter, 
		x = x, 
		x2 = (x + width), 
		y = y, 
		y2 = (y + height), 
		row = hud_row,
		color = courseplay.hud.colors.white,
		canBeClicked = true,
		isActive = false,
		isDisabled = false,
		isHovered = false
	};
	if modifiedParameter then 
		button.modifiedParameter = modifiedParameter;
	end
	
	--NOTE: showHideVariable MUST be in self namespace, since self isn't global (can't be called as _G[self] or _G["self"])
	if showHideVariable then
		if string.find(showHideVariable, "<=") then
			button.compare = "<=";
		elseif string.find(showHideVariable, ">=") then
			button.compare = ">=";
		elseif string.find(showHideVariable, "<") then
			button.compare = "<";
		elseif string.find(showHideVariable, ">") then
			button.compare = ">";
		elseif string.find(showHideVariable, "!=") then
			button.compare = "!=";
		else
			button.compare = "=";
		end;
		
		local split = Utils.splitString(button.compare, showHideVariable);
		button.showWhat = split[1];
		button.showIs = split[2];
		
		if button.compare == "<=" or button.compare == ">=" or button.compare == "<" or button.compare == ">" then
			button.showIs = courseplay:stringToMath(button.showIs);
		end;
	end;

	table.insert(self.cp.buttons, button)
end

function courseplay:render_buttons(self, page)
	for _, button in pairs(self.cp.buttons) do
		if button.page == page or button.page == nil then
			if button.showWhat ~= nil and button.showIs ~= nil then
				local what = Utils.splitString(".", button.showWhat);
				if what[1] == "self" then 
					table.remove(what, 1); 
				end;
				local whatObj;
				for i=1,#what do
					local key = what[i]; 
					if i == 1 then
						whatObj = self[key];
					end;
					if i > 1 then
						whatObj = whatObj[key];
					end;
				end;
				
				if button.compare == "=" then
					button.show = tostring(whatObj) == button.showIs;
				elseif button.compare == "!=" then
					button.show = not tostring(whatObj) == button.showIs;
				elseif button.compare == ">" then
					button.show = whatObj > button.showIs;
				elseif button.compare == "<" then
					button.show = whatObj < button.showIs;
				elseif button.compare == ">=" then
					button.show = whatObj >= button.showIs;
				elseif button.compare == "<=" then
					button.show = whatObj <= button.showIs;
				else 
					button.show = false;
				end;
			end;
			
			if button.show == nil or (button.show ~= nil and button.show) then
				local colors = courseplay.hud.colors;
				local currentColor = courseplay:getButtonColor(button);
				local targetColor = currentColor;

				if not button.isDisabled and not button.isActive and not button.isHovered and button.canBeClicked and not courseplay:colorsMatch(currentColor, colors.white) then
					targetColor = colors.white;
				elseif button.isDisabled and not courseplay:colorsMatch(currentColor, colors.whiteDisabled) then
					targetColor = colors.whiteDisabled;
				elseif button.isActive and not courseplay:colorsMatch(currentColor, colors.activeGreen) then
					targetColor = colors.activeGreen;
				elseif not button.isActive and not button.isDisabled and (button.canBeClicked == nil or (button.canBeClicked ~= nil and button.canBeClicked)) and button.isHovered then
					local hoverColor = colors.hover;
					if button.function_to_call == "close_hud" then
						hoverColor = colors.closeRed;
					end;
					
					if not courseplay:colorsMatch(currentColor, hoverColor) then
						targetColor = hoverColor;
					end;
				end;
				
				-- set colors
				if not courseplay:colorsMatch(currentColor, targetColor) then
					courseplay:setButtonColor(button, targetColor)
				end;
			
				button.overlay:render();
			end;
		end
	end
end;

function courseplay:setButtonColor(button, color)
	if button == nil or button.overlay == nil or color == nil or table.getn(color) ~= 4 then
		return;
	end;
	
	button.color = color;
	setOverlayColor(button.overlay.overlayId, unpack(color));
end;

function courseplay:getButtonColor(button)
	if button == nil or button.overlay == nil or button.color == nil then
		return nil;
	end;

	return button.color;
end;

function courseplay:colorsMatch(color1, color2)
	return Utils.areListsEqual(color1, color2, false);
end;
