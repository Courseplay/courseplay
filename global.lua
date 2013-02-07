-- adds courseplayer to global table, so that the system knows all of them
function courseplay:add_working_player(self)
	table.insert(working_course_players, self)
	return table.getn(working_course_players)
end

-- renders info_text and global text for courseplaying tractors
function courseplay:infotext(self)
	if self.isEntered then
		if self.info_text ~= nil then
			renderText(courseplay.hud.infoBasePosX + 0.005, courseplay.hud.infoBasePosY + 0.0035, 0.02, self.info_text); --ORIG: +0.002
		end
	end

	if self.global_info_text ~= nil then
		local yspace = self.working_course_player_num * 0.022
		local show_name = ""
		if self.name ~= nil then
			show_name = self.name
		end
		renderText(0.1, yspace, 0.02, show_name .. " " .. self.global_info_text);
	end
	self.info_text = nil
	self.global_info_text = nil
end
