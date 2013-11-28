-- adds courseplayer to global table, so that the system knows all of them
function courseplay:addToTotalCoursePlayers(self)
	local vehicleNum = (table.maxn(courseplay.totalCoursePlayers) or 0) + 1;
	courseplay.totalCoursePlayers[vehicleNum] = self;
	CourseplayEvent.sendEvent(self, "self.cp.coursePlayerNum", vehicleNum)
	return vehicleNum;
end;

function courseplay:addToActiveCoursePlayers(vehicle)
	courseplay.numActiveCoursePlayers = courseplay.numActiveCoursePlayers + 1;
	courseplay.activeCoursePlayers[vehicle.rootNode] = vehicle;
end;
function courseplay:removeFromActiveCoursePlayers(vehicle)
	courseplay.activeCoursePlayers[vehicle.rootNode] = nil;
	courseplay.numActiveCoursePlayers = math.max(courseplay.numActiveCoursePlayers - 1, 0);
end;

function courseplay:setGlobalInfoText(vehicle, text, level)
	if not courseplay.globalInfoText.vehicleHasText[vehicle.cp.coursePlayerNum] then
		vehicle.cp.currentGlobalInfoTextLevel = level or 0;
		table.insert(courseplay.globalInfoText.content, {
			level = vehicle.cp.currentGlobalInfoTextLevel,
			text = nameNum(vehicle) .. " " .. text,
			vehicle = vehicle
		});
		courseplay.globalInfoText.vehicleHasText[vehicle.cp.coursePlayerNum] = true;
	end;
end;

function courseplay:renderInfoText(vehicle)
	if vehicle.isEntered and vehicle.cp.infoText ~= nil then
		courseplay:setFontSettings("white", false, "left");
		renderText(courseplay.hud.infoBasePosX + 0.005, courseplay.hud.infoBasePosY + 0.0035, 0.02, vehicle.cp.infoText); --ORIG: +0.002
	end;
end;

function courseplay:setFontSettings(color, fontBold, align)
	if color ~= nil and (type(color) == "string" or type(color) == "table") then
		if type(color) == "string" and courseplay.hud.colors[color] ~= nil and #(courseplay.hud.colors[color]) == 4 then
			setTextColor(unpack(courseplay.hud.colors[color]));
		elseif type(color) == "table" and #(color) == 4 then
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
