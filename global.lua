-- adds courseplayer to global table, so that the system knows all of them
function courseplay:add_working_player(self)
	table.insert(working_course_players, self)
	local numPlayers = table.getn(working_course_players)
	CourseplayEvent.sendEvent(self, "self.working_course_player_num", numPlayers)
	return numPlayers
end

function courseplay:setGlobalInfoText(vehicle, text, level)
	courseplay.globalInfoText.content[vehicle.working_course_player_num] = {
		level = level or 0,
		text = nameNum(vehicle, true) .. " " .. text,
		vehicle = vehicle
	};
end;

function courseplay:renderInfoText(vehicle)
	if vehicle.isEntered and vehicle.cp.infoText ~= nil then
		courseplay:setFontSettings("white", false);
		renderText(courseplay.hud.infoBasePosX + 0.005, courseplay.hud.infoBasePosY + 0.0035, 0.02, vehicle.cp.infoText); --ORIG: +0.002
	end;
end;

function courseplay:setFontSettings(color, fontBold, align)
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

	if align ~= nil and (align == "left" or align == "center" or align == "right") then
		setTextAlignment(RenderText["ALIGN_" .. string.upper(align)]);
	end;
end;
