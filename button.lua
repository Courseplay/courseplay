function courseplay:register_button(self, hud_page, img, function_to_call, parameter, x, y, width, height, hud_row, modifiedParameter)
	local overlay_path = Utils.getFilename("img/" .. img, self.cp_directory);
	local overlay = Overlay:new(img, overlay_path, x, y, width, height);

	button = { page = hud_page, overlay = overlay, function_to_call = function_to_call, parameter = parameter, x = x, x2 = (x + width), y = y, y2 = (y + height), row = hud_row }
	if modifiedParameter then 
		button.modifiedParameter = modifiedParameter
	end
	
	table.insert(self.buttons, button)
end

function courseplay:render_buttons(self, page)
	for _, button in pairs(self.buttons) do
		if button.page == page or button.page == nil then
			button.overlay:render()
		end
	end
end