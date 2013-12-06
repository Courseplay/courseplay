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

function courseplay:setGlobalInfoText(vehicle, text, level, refIdx, forceRemove)
--v3 multiple msgs per vehicle
	--print(string.format('setGlobalInfoText(vehicle, %s, %s, %s, %s)', tostring(text), tostring(level), tostring(refIdx), tostring(forceRemove))); 
	if forceRemove == true then
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


	if courseplay.globalInfoText.content[vehicle.rootNode] == nil then
		courseplay.globalInfoText.content[vehicle.rootNode] = {};
	end;

	level = level or 0;

	vehicle.cp.hasSetGlobalInfoTextThisLoop[refIdx] = true;
	if vehicle.cp.activeGlobalInfoTexts[refIdx] == nil or vehicle.cp.activeGlobalInfoTexts[refIdx] ~= level then
		if vehicle.cp.activeGlobalInfoTexts[refIdx] == nil then
			vehicle.cp.numActiveGlobalInfoTexts = vehicle.cp.numActiveGlobalInfoTexts + 1;
		end;
		--print(string.format('\t%s: setGlobalInfoText [%q] numActiveGlobalInfoTexts=%d, lvl %d, old lvl=%q, text=%q', nameNum(vehicle), refIdx, vehicle.cp.numActiveGlobalInfoTexts, level, tostring(vehicle.cp.activeGlobalInfoTexts[refIdx]), text));
		vehicle.cp.activeGlobalInfoTexts[refIdx] = level;
		courseplay.globalInfoText.content[vehicle.rootNode][refIdx] = {
			level = level,
			text = nameNum(vehicle) .. " " .. text,
			vehicle = vehicle
		};
		courseplay.globalInfoText.content[vehicle.rootNode][refIdx].backgroundWidth = getTextWidth(courseplay.globalInfoText.fontSize, courseplay.globalInfoText.content[vehicle.rootNode][refIdx].text) + courseplay.globalInfoText.backgroundPadding * 2.5;
	end;

--[[ v2 one msg per vehicle
	if forceRemove == true then
		courseplay.globalInfoText.content[vehicle.rootNode] = nil;
		vehicle.cp.curGlobalInfoText = nil;
		print(string.format('%s: remove globalInfoText from global table, curGlobalInfoText=nil', nameNum(vehicle)));
		return;
	end;

	--print(string.format('%s: setGlobalInfoText(): curGlobalInfoText=%q, new text=%q, set hasSetGlobalInfoTextThisLoop to true', nameNum(vehicle), tostring(vehicle.cp.curGlobalInfoText), tostring(text)));
	vehicle.cp.hasSetGlobalInfoTextThisLoop = true;
	if vehicle.cp.curGlobalInfoText == nil or vehicle.cp.curGlobalInfoText ~= text then
		print(string.format('%s: setGlobalInfoText lvl %d, old text=%q, new curGlobalInfoText=%q', nameNum(vehicle), level or 0, tostring(vehicle.cp.curGlobalInfoText), text));
		vehicle.cp.curGlobalInfoText = text;
		courseplay.globalInfoText.content[vehicle.rootNode] = {
			level = level or 0,
			text = nameNum(vehicle) .. " " .. text,
			vehicle = vehicle
		};
	end;
--]]

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
