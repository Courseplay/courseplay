-- adds courseplayer to global table, so that the system knows all of them
function courseplay:add_working_player(self)
	table.insert(working_course_players, self)
	return table.getn(working_course_players)
end

function courseplay:setGlobalInfoText(self, text, level)
	self.cp.globalInfoText = text;
	self.cp.globalInfoTextLevel = level;
end;

-- renders info_text and global text for courseplaying tractors
function courseplay:renderInfoText(self)
	if self.isEntered then
		if self.cp.infoText ~= nil then
			courseplay:setFontSettings("white", false);
			renderText(courseplay.hud.infoBasePosX + 0.005, courseplay.hud.infoBasePosY + 0.0035, 0.02, self.cp.infoText); --ORIG: +0.002
		end;
	end;
	self.cp.infoText = nil;

	if self.cp.globalInfoText ~= nil then
		local posY = self.working_course_player_num * 0.022;
		local vehicleName = "";
		if self.name ~= nil then
			vehicleName = self.name;
		end;

		courseplay:setFontSettings("shadow", false);
		renderText(0.1015, posY - 0.0015, 0.02, vehicleName .. " " .. self.cp.globalInfoText);

		local level = self.cp.globalInfoTextLevel;
		if level == nil or level == 0 then
			courseplay:setFontSettings("white", false);
		elseif level == 1 then
			courseplay:setFontSettings("activeGreen", false);
		elseif level == -1 then
			courseplay:setFontSettings("activeRed", false);
		elseif level == -2 then
			courseplay:setFontSettings("closeRed", true);
		end;

		renderText(0.100, posY, 0.02, vehicleName .. " " .. self.cp.globalInfoText);
	end;
	self.cp.globalInfoText = nil;
end;

function courseplay:setFontSettings(color, fontBold)
	if color ~= nil and (type(color) == "string" or type(color) == "table") then
		if type(color) == "string" and courseplay.hud.colors[color] ~= nil and table.getn(courseplay.hud.colors[color]) == 4 then
			setTextColor(unpack(courseplay.hud.colors[color]));
		elseif type(color) == "table" and table.getn(color) == 4 then
			setTextColor(unpack(color));
		end;
	else --Backup
		setTextColor(unpack(courseplay.hud.colors.white));
	end;
	
	if fontBold ~= nil and type(fontBold) == "boolean" then
		setTextBold(fontBold);
	else
		setTextBold(false);
	end;
end;
