-- adds courseplayer to global table, so that the system knows all of them
function courseplay:add_working_player(self)
	table.insert(working_course_players, self)
	return table.getn(working_course_players)
end

function courseplay:setGlobalInfoText(self, text, level)
	self.cp.globalInfoText = text;
	self.cp.globalInfoTextLevel = Utils.getNoNil(level, 0);
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

	local bg = self.cp.globalInfoTextOverlay;
	bg.isRendering = false;
	if self.cp.globalInfoText ~= nil and not g_currentMission.missionPDA.showPDA then
		local posY = self.working_course_player_num * 0.022;
		local msg = Utils.getNoNil(self.name, g_i18n:getText("UNKNOWN")) .. " " .. self.cp.globalInfoText;

		--Background overlay
		local level = self.cp.globalInfoTextLevel;
		local bgColor = nil;
		
		if level ~= nil then
			bgColor = courseplay.globalInfoText.levelColors[tostring(level)];
			bgColor[4] = 0.85;
		end;

		if bgColor ~= nil then
			local currentColor = { bg.r, bg.g, bg.b, bg.a };
			if currentColor == nil or not courseplay:colorsMatch(currentColor, bgColor) then
				bg:setColor(unpack(bgColor))
			end;

			bg:setPosition(bg.x, posY)
			bg:setDimension(getTextWidth(courseplay.globalInfoText.fontSize, msg) + courseplay.globalInfoText.backgroundPadding * 2.5, bg.height)

			bg.isRendering = true; --NOTE: render() happens in courseplay_manager:draw()
		end;
		
		courseplay:setFontSettings("white", false);
		renderText(courseplay.globalInfoText.posX, posY, courseplay.globalInfoText.fontSize, msg);
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
