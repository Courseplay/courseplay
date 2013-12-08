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

function courseplay:setGlobalInfoText(vehicle, refIdx, forceRemove)
--v3 multiple msgs per vehicle
	--print(string.format('setGlobalInfoText(vehicle, %s, %s)', tostring(refIdx), tostring(forceRemove))); 
	if forceRemove == true then
		if g_server ~= nil then
			CourseplayEvent.sendEvent(vehicle, "setMPGlobalInfoText", refIdx, false, forceRemove)
		end	
		if courseplay.globalInfoText.content[vehicle.rootNode][refIdx] then
			courseplay.globalInfoText.content[vehicle.rootNode][refIdx] = nil;
		end;
		vehicle.cp.activeGlobalInfoTexts[refIdx] = nil;
		vehicle.cp.numActiveGlobalInfoTexts = vehicle.cp.numActiveGlobalInfoTexts - 1;
		--print(string.format('\t%s: remove globalInfoText[%s] from global table, numActiveGlobalInfoTexts=%d', nameNum(vehicle), refIdx, vehicle.cp.numActiveGlobalInfoTexts));
		if vehicle.cp.numActiveGlobalInfoTexts == 0 then
			courseplay.globalInfoText.content[vehicle.rootNode] = nil;
			--print(string.format('\t\tset globalInfoText.content[rootNode] to nil'));
		end;
		return;
	end;

	vehicle.cp.hasSetGlobalInfoTextThisLoop[refIdx] = true;
	local data = courseplay.globalInfoText.msgReference[refIdx];
	--print(string.format('refIdx=%q, level=%s, text=%q, textLoc=%q', tostring(refIdx), tostring(data.level), tostring(data.text), tostring(courseplay:loc(data.text))));
	if vehicle.cp.activeGlobalInfoTexts[refIdx] == nil or vehicle.cp.activeGlobalInfoTexts[refIdx] ~= data.level then
		if g_server ~= nil then
			CourseplayEvent.sendEvent(vehicle, "setMPGlobalInfoText", refIdx, false, forceRemove)
		end	
		if vehicle.cp.activeGlobalInfoTexts[refIdx] == nil then
			vehicle.cp.numActiveGlobalInfoTexts = vehicle.cp.numActiveGlobalInfoTexts + 1;
		end;
		local text = nameNum(vehicle) .. " " .. courseplay:loc(data.text);
		--print(string.format('\t%s: setGlobalInfoText [%q] numActiveGlobalInfoTexts=%d, lvl %d,  text=%q', nameNum(vehicle), refIdx, vehicle.cp.numActiveGlobalInfoTexts, data.level, tostring(text)));
		vehicle.cp.activeGlobalInfoTexts[refIdx] = data.level;

		if courseplay.globalInfoText.content[vehicle.rootNode] == nil then
			courseplay.globalInfoText.content[vehicle.rootNode] = {};
		end;
		courseplay.globalInfoText.content[vehicle.rootNode][refIdx] = {
			level = data.level,
			text = text,
			backgroundWidth = getTextWidth(courseplay.globalInfoText.fontSize, text) + courseplay.globalInfoText.backgroundPadding * 2.5,
			vehicle = vehicle
		};
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
