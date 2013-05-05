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

	self.cp.globalInfoTextOverlay.isRendering = false;
	if self.cp.globalInfoText ~= nil then
		local posY = self.working_course_player_num * 0.022;
		local vehicleName = "unknown";
		if self.name ~= nil then
			vehicleName = self.name;
		end;
		local msg = vehicleName .. " " .. self.cp.globalInfoText;

		--Background overlay
		local level = self.cp.globalInfoTextLevel;
		local bgColorName = nil;
		
		if level ~= nil then
			if level == 0 then
				bgColorName = nil;
			elseif level == 1 then
				bgColorName = "activeGreen";
			elseif level == -1 then
				bgColorName = "activeRed";
			elseif level == -2 then
				bgColorName = "closeRed";
			end;
		end;

		if bgColorName ~= nil then
			local currentColor = { self.cp.globalInfoTextOverlay.r, self.cp.globalInfoTextOverlay.g, self.cp.globalInfoTextOverlay.b, self.cp.globalInfoTextOverlay.a };
			local bgColor = courseplay.hud.colors[bgColorName];
			bgColor[4] = 0.85;
			if currentColor == nil or not courseplay:colorsMatch(currentColor, bgColor) then
				self.cp.globalInfoTextOverlay:setColor(unpack(bgColor))
			end;

			self.cp.globalInfoTextOverlay:setPosition(self.cp.globalInfoTextOverlay.x, posY)
			self.cp.globalInfoTextOverlay:setDimension(getTextWidth(courseplay.globalInfoText.fontSize, msg) + courseplay.globalInfoText.backgroundPadding * 2.5, self.cp.globalInfoTextOverlay.height)

			self.cp.globalInfoTextOverlay.isRendering = true; --NOTE: render() happens in courseplay_manager:draw()
		end;
		
		courseplay:setFontSettings("white", false);
		renderText(courseplay.globalInfoText.posX, posY, courseplay.globalInfoText.fontSize, msg);
	end;
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
