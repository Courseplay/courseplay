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
		row = hud_row
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

	table.insert(self.buttons, button)
end

function courseplay:render_buttons(self, page)
	for _, button in pairs(self.buttons) do
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
				button.overlay:render();
			end;
		end
	end
end