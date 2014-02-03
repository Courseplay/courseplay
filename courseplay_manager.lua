courseplay_manager = {};
local courseplay_manager_mt = Class(courseplay_manager);

function courseplay_manager:loadMap(name)
	if g_currentMission.cp_courses == nil then
		--courseplay:debug("cp courses was nil and initialized", 8);
		g_currentMission.cp_courses = {};
		g_currentMission.cp_folders = {};
		g_currentMission.cp_sorted = {item={}, info={}};

		if g_server ~= nil and next(g_currentMission.cp_courses) == nil then
			courseplay_manager:load_courses()
			courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		end
	end;

	self.buttons = {};

	--GlobalInfoText
	self.globalInfoTextMaxNum = 20;
	self.globalInfoTextOverlays = {};
	self.buttons.globalInfoText = {};
	local git = courseplay.globalInfoText;
	local buttonHeight = git.fontSize;
	local buttonWidth = buttonHeight * 1080 / 1920;
	local buttonX = git.backgroundX - git.backgroundPadding - buttonWidth;
	for i=1,self.globalInfoTextMaxNum do
		local posY = git.backgroundY + (i - 1) * git.lineHeight;
		self.globalInfoTextOverlays[i] = Overlay:new(string.format("globalInfoTextOverlay%d", i), git.backgroundImg, git.backgroundX, posY, 0.1, git.fontSize);
		self:registerButton('globalInfoText', 'goToVehicle', i, 'pageNav_7.png', buttonX, posY, buttonWidth, buttonHeight);
	end;
	self.buttons.globalInfoTextClickArea = {
		x1 = buttonX;
		x2 = buttonX + buttonWidth;
		y1 = git.backgroundY,
		y2 = git.backgroundY + (self.globalInfoTextMaxNum  * git.lineHeight);
	};

	self:createInitialCourseplayFile();

	self.playerOnFootMouseEnabled = false;
	self.wasPlayerFrozen = false;

	--Field scan info display
	self.fieldScanInfo = {};
	self.fieldScanInfo.fileW = 512/1920;
	self.fieldScanInfo.fileH = 256/1080;
	self.fieldScanInfo.contentW = 426/1920;
	self.fieldScanInfo.contentH = 180/1080;
	self.fieldScanInfo.bgX, self.fieldScanInfo.bgY = 0.5 - self.fieldScanInfo.contentW/2, 0.5 - self.fieldScanInfo.contentH/2;
	local bgPath = Utils.getFilename('img/fieldScanInfoBackground.png', courseplay.path);
	self.fieldScanInfo.bgOverlay = Overlay:new('fieldScanInfoBackground', bgPath, self.fieldScanInfo.bgX, self.fieldScanInfo.bgY, self.fieldScanInfo.fileW, self.fieldScanInfo.fileH);
	local xPadding = 20/1920;
	self.fieldScanInfo.lineX  = self.fieldScanInfo.bgX + xPadding;
	self.fieldScanInfo.line1Y = self.fieldScanInfo.bgY + 67/1080;
	self.fieldScanInfo.line2Y = self.fieldScanInfo.bgY + 40/1080;
	self.fieldScanInfo.loadX  = self.fieldScanInfo.bgX + 340/1920;
	-- self.fieldScanInfo.loadY  = self.fieldScanInfo.line2Y - 0.018/4;
	self.fieldScanInfo.loadY  = self.fieldScanInfo.bgY + 57/1080;

	local loadingPath = Utils.getFilename('img/fieldScanInfoLoading.png', courseplay.path);
	self.fieldScanInfo.loadOverlay = Overlay:new('fieldScanInfoLoad', loadingPath, self.fieldScanInfo.loadX, self.fieldScanInfo.loadY, 32/1920, 32/1080);
	-- self.fieldScanInfo.loadTime = 0;
	self.fieldScanInfo.loadRotStep = 0;
	self.fieldScanInfo.loadRotAdd = math.rad(-360/72); --rotate 5° to the right each step
	self.fieldScanInfo.rotationTime = 1000/72; --in ms

	self.fieldScanInfo.progressBarWidth = self.fieldScanInfo.contentW - 2 * xPadding - 5/1920;
	local progressBarBgPath = Utils.getFilename('img/progressBarBackground.png', courseplay.path);
	self.fieldScanInfo.progressBarBgOverlay = Overlay:new('fieldScanInfoProgressBarBg', progressBarBgPath, self.fieldScanInfo.lineX, self.fieldScanInfo.bgY + 16/1080, self.fieldScanInfo.progressBarWidth, 16/1080);
	local progressBarPath = Utils.getFilename('img/progressBar.png', courseplay.path);
	self.fieldScanInfo.progressBarOverlay = Overlay:new('fieldScanInfoProgressBar', progressBarPath, self.fieldScanInfo.lineX, self.fieldScanInfo.bgY + 16/1080, self.fieldScanInfo.progressBarWidth, 16/1080);
	self.fieldScanInfo.percentColors = {
		{ pct = 0.0, color = { r = 0.882353, g = 0.105882, b = 0 } },
		{ pct = 0.5, color = { r = 1.000000, g = 0.800000, b = 0 } },
		{ pct = 1.0, color = { r = 0.537255, g = 0.952941, b = 0 } }
	};


	if g_server ~= nil then
		courseplay.fields:loadAllCustomFields();
	end;
end;

function courseplay_manager:createInitialCourseplayFile()
	local dir = g_currentMission.missionInfo.savegameDirectory;
	if dir then
		local filePath = dir .. '/courseplay.xml';
		-- print(string.format('createInitialCourseplayFile(): filePath=%q', filePath));
		local file;
		if not fileExists(filePath) then
			file = createXMLFile('courseplayFile', filePath, 'XML');
			-- print(string.format('\tcreateXmlFile("courseplayFile", [path], XML), file=%s', tostring(file)));
		else
			file = loadXMLFile('courseplayFile', filePath);
			-- print(string.format('\tloadXMLFile("courseplayFile", [path]), file=%s', tostring(file)));
		end;

		-- NOTE: usually "hasXMLProperty" would be used in this case. This presented some weird shitty problem though, in that the first of each set (posX, posX and debugScannedFields) were created, but not the second ones. So, getXML... is the better choice in this case.
		if not getXMLFloat(file, 'XML.courseplayHud#posX') then
			setXMLString(file, 'XML.courseplayHud#posX', ('%.3f'):format(courseplay.hud.infoBasePosX));
		end;
		if not getXMLFloat(file, 'XML.courseplayHud#posY') then
			setXMLString(file, 'XML.courseplayHud#posY', ('%.3f'):format(courseplay.hud.infoBasePosY));
		end;

		if not getXMLFloat(file, 'XML.courseplayGlobalInfoText#posX') then
			setXMLString(file, 'XML.courseplayGlobalInfoText#posX', ('%.3f'):format(courseplay.globalInfoText.posX));
		end;
		if not getXMLFloat(file, 'XML.courseplayGlobalInfoText#posY') then
			setXMLString(file, 'XML.courseplayGlobalInfoText#posY', ('%.3f'):format(courseplay.globalInfoText.posY));
		end;

		if getXMLBool(file, 'XML.courseplayFields#automaticScan') == nil then
			setXMLString(file, 'XML.courseplayFields#automaticScan', tostring(courseplay.fields.automaticScan));
		end;
		if getXMLBool(file, 'XML.courseplayFields#onlyScanOwnedFields') == nil then
			setXMLString(file, 'XML.courseplayFields#onlyScanOwnedFields', tostring(courseplay.fields.onlyScanOwnedFields));
		end;
		if getXMLBool(file, 'XML.courseplayFields#debugScannedFields') == nil then
			setXMLString(file, 'XML.courseplayFields#debugScannedFields', tostring(courseplay.fields.debugScannedFields));
		end;
		if getXMLBool(file, 'XML.courseplayFields#debugCustomLoadedFields') == nil then
			setXMLString(file, 'XML.courseplayFields#debugCustomLoadedFields', tostring(courseplay.fields.debugCustomLoadedFields));
		end;
		if not getXMLInt(file, 'XML.courseplayFields#scanStep') then
			setXMLInt(file, 'XML.courseplayFields#scanStep', courseplay.fields.scanStep);
		end;

		saveXMLFile(file);
		delete(file);
	end;
end;

function courseplay_manager:registerButton(section, fn, prm, img, x, y, w, h)
	local overlay = Overlay:new(img, Utils.getFilename("img/" .. img, courseplay.path), x, y, w, h);
	local button = { 
		section = section, 
		overlay = overlay, 
		overlays = { overlay }, 
		function_to_call = fn, 
		parameter = prm, 
		x_init = x,
		x = x,
		x2 = (x + w),
		y_init = y,
		y = y,
		y2 = (y + h),
		color = courseplay.hud.colors.white,
		canBeClicked = fn ~= nil,
		show = true,
		isClicked = false,
		isActive = false,
		isDisabled = false,
		isHovered = false,
		isHidden = false
	};
	--print(string.format("courseplay_manager:registerButton(%q, %q, %s, %q, %.3f, %.3f, %.3f, %.3f)", section, fn, prm, img, x, y, w, h));
	table.insert(courseplay_manager.buttons[tostring(section)], button);
	--return #(courseplay_manager.buttons[tostring(section)]);
end;

function courseplay_manager:deleteMap()
	--courses & folders
	g_currentMission.cp_courses = nil
	g_currentMission.cp_folders = nil
	g_currentMission.cp_sorted = nil

	--buttons
	for i,vehicle in pairs(g_currentMission.steerables) do
		if vehicle.cp ~= nil then
			if vehicle.cp.globalInfoTextOverlay ~= nil then
				vehicle.cp.globalInfoTextOverlay:delete();
			end;
			if vehicle.cp.buttons ~= nil then
				courseplay.button.deleteButtonOverlays(vehicle);
			end;
		end;
	end;

	--global info text
	for i,button in pairs(self.buttons.globalInfoText) do
		if button.overlays ~= nil then
			for j,overlay in pairs(button.overlays) do
				if overlay.overlayId ~= nil and overlay.delete ~= nil then
					overlay:delete();
				end;
			end;
		end;
		if self.globalInfoTextOverlays[i] then
			local gitOverlay = self.globalInfoTextOverlays[i];
			if gitOverlay.overlayId ~= nil and gitOverlay.delete ~= nil then
				gitOverlay:delete();
			end;
		end;
	end;

	--signs
	for section,signDatas in pairs(courseplay.signs.buffer) do
		for k,signData in pairs(signDatas) do
			courseplay.utils.signs.deleteSign(signData.sign);
		end;
		courseplay.signs.buffer[section] = {};
	end;

	--fields
	courseplay.fields.fieldData = {};
	courseplay.fields.curFieldScanIndex = 0;
	courseplay.fields.allFieldsScanned = false;
	courseplay.fields.ingameDataSetUp = false;
end

function courseplay_manager:draw()
	if g_currentMission.paused then
		return;
	end;

	courseplay.globalInfoText.hasContent = false;
	line = 0;
	if (not courseplay.globalInfoText.hideWhenPdaActive or (courseplay.globalInfoText.hideWhenPdaActive and not g_currentMission.missionPDA.showPDA)) and table.maxn(courseplay.globalInfoText.content) > 0 then
		courseplay.globalInfoText.hasContent = true;
		for _,refIndexes in pairs(courseplay.globalInfoText.content) do
			if line >= self.globalInfoTextMaxNum then
				break;
			end;

			for refIdx,data in pairs(refIndexes) do
				line = line + 1;

				local bg = self.globalInfoTextOverlays[line];
				bg:setColor(unpack(courseplay.globalInfoText.levelColors[data.level]));
				local posY = courseplay.globalInfoText.posY + ((line - 1) * courseplay.globalInfoText.lineHeight);
				bg:setPosition(bg.x, posY);
				bg:setDimension(data.backgroundWidth, bg.height);

				local button = self.buttons.globalInfoText[line];
				if button ~= nil then
					button.canBeClicked = true;
					button.isDisabled = data.vehicle.isBroken or data.vehicle.isControlled;
					button.parameter = data.vehicle;
					if g_currentMission.controlledVehicle == data.vehicle then
						courseplay:setButtonColor(button, courseplay.hud.colors.activeGreen);
						button.canBeClicked = false;
					elseif button.isDisabled then
						courseplay:setButtonColor(button, courseplay.hud.colors.whiteDisabled);
					elseif button.isHovered then
						courseplay:setButtonColor(button, courseplay.hud.colors.hover);
					elseif button.isClicked then
						courseplay:setButtonColor(button, courseplay.hud.colors.activeRed);
					else
						courseplay:setButtonColor(button, button.color);
					end;
					button.overlay:render();
				end;


				bg:render();
				courseplay:setFontSettings("white", false);
				renderText(courseplay.globalInfoText.posX, posY, courseplay.globalInfoText.fontSize, data.text);
			end;
		end;
	end;
	self.buttons.globalInfoTextClickArea.y2 = courseplay.globalInfoText.backgroundY + (line  * courseplay.globalInfoText.lineHeight);

	courseplay.lightsNeeded = g_currentMission.environment.needsLights or (g_currentMission.environment.lastRainScale > 0.1 and g_currentMission.environment.timeSinceLastRain < 30);

	-- DISPLAY FIELD SCAN MSG
	if courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned then
		local fsi = self.fieldScanInfo;

		fsi.progressBarBgOverlay:render();
		local pct = courseplay.fields.curFieldScanIndex / g_currentMission.fieldDefinitionBase.numberOfFields;
		local color = self:getColorFromPct(pct, fsi.percentColors);
		fsi.progressBarOverlay:setColor(color.r, color.g, color.b, 1);
		fsi.progressBarOverlay.width = fsi.progressBarWidth * pct;
  		setOverlayUVs(fsi.progressBarOverlay.overlayId, 0,0, 0,1, pct,0, pct,1);
		fsi.progressBarOverlay:render();

		fsi.bgOverlay:render();

		courseplay:setFontSettings({ 0.8, 0.8, 0.8, 1 }, true, 'left');
		renderText(fsi.lineX, fsi.line1Y - 0.001, 0.021, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));
		courseplay:setFontSettings('shadow', true, 'left');
		renderText(fsi.lineX, fsi.line1Y,         0.021, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));

		local str2 = courseplay:loc('COURSEPLAY_SCANNING_FIELD_NMB'):format(courseplay.fields.curFieldScanIndex, g_currentMission.fieldDefinitionBase.numberOfFields);
		courseplay:setFontSettings({ 0.8, 0.8, 0.8, 1 }, false, 'left');
		renderText(fsi.lineX, fsi.line2Y - 0.001, 0.018, str2);
		courseplay:setFontSettings('shadow', false, 'left');
		renderText(fsi.lineX, fsi.line2Y,         0.018, str2);

		local rotationStep = math.floor(g_currentMission.time / self.fieldScanInfo.rotationTime);
		if rotationStep > fsi.loadRotStep then
			fsi.loadOverlay:setRotation(rotationStep * fsi.loadRotAdd, fsi.loadOverlay.width/2, fsi.loadOverlay.height/2);
			fsi.loadRotStep = rotationStep;
		end;
		fsi.loadOverlay:render();

		--reset font settings
		courseplay:setFontSettings('white', true, 'left');
	end;
end;

function courseplay_manager:getColorFromPct(pct, colorMap)
	local step = colorMap[2].pct - colorMap[1].pct;

	for i=1, #colorMap do
		local data = colorMap[i];
		if pct == data.pct then
			return data.color;
		end;

		--print(string.format('\tstep %d, step base pct=%.1f', i, colorMap[i].pct));
		if pct <= data.pct then
			local lower = colorMap[i - 1];
			local upper = colorMap[i];
			--print(string.format('\t\tpct <= map pct -> lower=colorMap[%d], upper=colorMap[%d]', i-1, i));

			local rd, gd, bd = upper.color.r - lower.color.r, upper.color.g - lower.color.g, upper.color.b - lower.color.b;
			local relativePct = (pct - lower.pct) / step;
			--print(string.format('\t\trd=%.1f, gd=%.1f, bg=%.1f, relativePct=%.2f', rd, gd, bd, relativePct))
			local color = {
				r = lower.color.r + relativePct * rd,
				g = lower.color.g + relativePct * gd,
				b = lower.color.b + relativePct * bd
			};
			--print(string.format('\t\tr = lower r + relativePct * rd = %.2f + %.2f * %.2f = %.2f', lower.color.r, relativePct, rd, color.r));
			--print(string.format('\t\tg = lower g + relativePct * gd = %.2f + %.2f * %.2f = %.2f', lower.color.g, relativePct, gd, color.g));
			--print(string.format('\t\tb = lower b + relativePct * bd = %.2f + %.2f * %.2f = %.2f', lower.color.b, relativePct, bd, color.b));
			return color;
		end;
	end;
end;


function courseplay_manager:mouseEvent(posX, posY, isDown, isUp, button)
	if g_currentMission.paused then
		return;
	end;

	local area = courseplay_manager.buttons.globalInfoTextClickArea;
	if area == nil then
		return;
	end;
	local mouseKey = button;
	local mouseIsInClickArea = posX > area.x1 and posX < area.x2 and posY > area.y1 and posY < area.y2;

	--LEFT CLICK
	if isDown and mouseKey == Input[courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION.keyName] and mouseIsInClickArea then
		if courseplay.globalInfoText.hasContent then
			for i,button in pairs(self.buttons.globalInfoText) do
				if button.show and courseplay:mouseIsInButtonArea(posX, posY, button) then
					local sourceVehicle = g_currentMission.controlledVehicle or button.parameter;
					--print(string.format("handleMouseClickForButton(%q, button)", nameNum(sourceVehicle)));
					courseplay:handleMouseClickForButton(sourceVehicle, button);
					break;
				end;
			end;
		end;

	--RIGHT CLICK
	elseif isDown and mouseKey == Input[courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.keyName] and g_currentMission.controlledVehicle == nil then
		if courseplay.globalInfoText.hasContent and not self.playerOnFootMouseEnabled then
			self.playerOnFootMouseEnabled = true;
			self.wasPlayerFrozen = g_currentMission.isPlayerFrozen;
			g_currentMission.isPlayerFrozen = true;
		elseif self.playerOnFootMouseEnabled then
			self.playerOnFootMouseEnabled = false;
			if courseplay.globalInfoText.hasContent then --if a button was hovered when deactivating the cursor, deactivate hover state
				for _,button in pairs(self.buttons.globalInfoText) do
					button.isClicked = false;
					button.isHovered = false;
				end;
			end;
			if not self.wasPlayerFrozen then
				g_currentMission.isPlayerFrozen = false;
			end;
		end;
		--print(string.format("right mouse click: playerOnFootMouseEnabled=%s, wasPlayerFrozen=%s, isPlayerFrozen=%s", tostring(self.playerOnFootMouseEnabled), tostring(self.wasPlayerFrozen), tostring(g_currentMission.isPlayerFrozen)));
		InputBinding.setShowMouseCursor(self.playerOnFootMouseEnabled);

	--HOVER
	elseif not isDown and courseplay.globalInfoText.hasContent --[[and posX > area.x1 * 0.9 and posX < area.x2 * 1.1 and posY > area.y1 * 0.9 and posY < area.y2 * 1.1]] then
		for _,button in pairs(self.buttons.globalInfoText) do
			button.isClicked = false;
			if button.show and not button.isHidden then
				button.isHovered = false;
				if courseplay:mouseIsInButtonArea(posX, posY, button) then
					button.isClicked = false;
					button.isHovered = true;
				end;
			end;
		end;
	end;
end;

function courseplay_manager:update(dt)
	--courseplay:debug(table.getn(g_currentMission.courseplay_courses), 8);

	if g_currentMission.controlledVehicle == nil then
		if self.playerOnFootMouseEnabled then
			g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:loc("COURSEPLAY_MOUSEARROW_HIDE"));
		elseif courseplay.globalInfoText.hasContent then
			g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:loc("COURSEPLAY_MOUSEARROW_SHOW"));
		end;
	end;

	--SETUP FIELD INGAME DATA
	if not courseplay.fields.ingameDataSetUp then
		courseplay.fields:setUpFieldsIngameData();
	end;

	--SCAN ALL FIELD EDGES
	if courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned then
		courseplay.fields:setAllFieldEdges();
	end;
end;

function courseplay_manager:updateTick(dt)
end;

function courseplay_manager:keyEvent()
end

function courseplay_manager:load_courses()
	--print("courseplay_manager:load_courses()");
	courseplay:debug('loading courses by courseplay manager', 8);

	local finish_all = false;
	local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
	if savegame ~= nil then
		local filePath = savegame.savegameDirectory .. "/courseplay.xml";

		if fileExists(filePath) then
			local cpFile = loadXMLFile("courseFile", filePath);
			g_currentMission.cp_courses = nil -- make sure it's empty (especially in case of a reload)
			g_currentMission.cp_courses = {}
			local courses_by_id = g_currentMission.cp_courses
			local courses_without_id = {}
			local i = 0
			
			local tempCourse
			repeat

				--current course
				local currentCourse = string.format("XML.courses.course(%d)", i)
				if not hasXMLProperty(cpFile, currentCourse) then
					finish_all = true;
					break;
				end;

				--course name
				local courseName = getXMLString(cpFile, currentCourse .. "#name");
				if courseName == nil then
					courseName = string.format('NO_NAME%d',i)
				end;
				local courseNameClean = courseplay:normalizeUTF8(courseName);

				--course ID
				local id = getXMLInt(cpFile, currentCourse .. "#id")
				if id == nil then
					id = 0;
				end;
				
				--course parent
				local parent = getXMLInt(cpFile, currentCourse .. "#parent")
				if parent == nil then
					parent = 0
				end

				--course waypoints
				tempCourse = {};
				local wpNum = 1;
				local key = currentCourse .. ".waypoint" .. wpNum;
				local finish_wp = not hasXMLProperty(cpFile, key);
				
				while not finish_wp do
					local x, z = Utils.getVectorFromString(getXMLString(cpFile, key .. "#pos"));
					if x ~= nil then
						if z == nil then
							finish_wp = true;
							break;
						end;
						local dangle =   Utils.getVectorFromString(getXMLString(cpFile, key .. "#angle"));
						local wait =     Utils.getVectorFromString(getXMLString(cpFile, key .. "#wait"));
						local speed =    Utils.getVectorFromString(getXMLString(cpFile, key .. "#speed"));
						local rev =      Utils.getVectorFromString(getXMLString(cpFile, key .. "#rev"));
						local crossing = Utils.getVectorFromString(getXMLString(cpFile, key .. "#crossing"));

						--course generation
						local generated =   Utils.getNoNil(getXMLBool(cpFile, key .. "#generated"), false);
						local dir =         getXMLString(cpFile, key .. "#dir");
						local turn =        Utils.getNoNil(getXMLString(cpFile, key .. "#turn"), "false");
						local turnStart =   Utils.getNoNil(getXMLInt(cpFile, key .. "#turnstart"), 0);
						local turnEnd =     Utils.getNoNil(getXMLInt(cpFile, key .. "#turnend"), 0);
						local ridgeMarker = Utils.getNoNil(getXMLInt(cpFile, key .. "#ridgemarker"), 0);

						crossing = crossing == 1 or wpNum == 1;
						wait = wait == 1;
						rev = rev == 1;

						if speed == 0 then
							speed = nil
						end

						--generated not needed, since true or false are loaded from file
						if turn == "false" then
							turn = nil;
						end;
						turnStart = turnStart == 1;
						turnEnd = turnEnd == 1;
						--ridgeMarker not needed, since 0, 1 or 2 is loaded from file

						tempCourse[wpNum] = { 
							cx = x, 
							cz = z, 
							angle = dangle, 
							rev = rev, 
							wait = wait, 
							crossing = crossing, 
							speed = speed,
							generated = generated,
							laneDir = dir,
							turn = turn,
							turnStart = turnStart,
							turnEnd = turnEnd,
							ridgeMarker = ridgeMarker
						};
						
						-- prepare next waypoint
						wpNum = wpNum + 1;
						key = currentCourse .. ".waypoint" .. wpNum;
						finish_wp = not hasXMLProperty(cpFile, key);
					else
						finish_wp = true;
						break;
					end;
				end -- while finish_wp == false;
				
				local course = { id = id, uid = 'c' .. id , type = 'course', name = courseName, nameClean = courseNameClean, waypoints = tempCourse, parent = parent }
				if id ~= 0 then
					courses_by_id[id] = course
				else
					table.insert(courses_without_id, course)
				end
				
				tempCourse = nil;
				i = i + 1;
				
			until finish_all == true;
			
			local j = 0
			local currentFolder, FolderName, id, parent, folder
			finish_all = false
			g_currentMission.cp_folders = nil
			g_currentMission.cp_folders = {}
			local folders_by_id = g_currentMission.cp_folders
			local folders_without_id = {}
			repeat
				-- current folder
				currentFolder = string.format("XML.folders.folder(%d)", j)
				if not hasXMLProperty(cpFile, currentFolder) then
					finish_all = true;
					break;
				end;
				
				-- folder name
				FolderName = getXMLString(cpFile, currentFolder .. "#name")
				if FolderName == nil then
					FolderName = string.format('NO_NAME%d',j)
				end
				local folderNameClean = courseplay:normalizeUTF8(FolderName);
				
				-- folder id
				id = getXMLInt(cpFile, currentFolder .. "#id")
				if id == nil then
					id = 0
				end
				
				-- folder parent
				parent = getXMLInt(cpFile, currentFolder .. "#parent")
				if parent == nil then
					parent = 0
				end
				
				-- "save" current folder
				folder = { id = id, uid = 'f' .. id ,type = 'folder', name = FolderName, nameClean = folderNameClean, parent = parent }
				if id ~= 0 then
					folders_by_id[id] = folder
				else
					table.insert(folders_without_id, folder)
				end
				j = j + 1
			until finish_all == true
			
			local save = false
			if #courses_without_id > 0 then
				-- give a new ID and save
				local maxID = courseplay.courses.getMaxCourseID()
				for i = 1, #courses_without_id do
					maxID = maxID + 1
					courses_without_id[i].id = maxID
					courses_without_id[i].uid = 'c' .. maxID
					courses_by_id[maxID] = courses_without_id[i]
				end
				save = true
			end
			if #folders_without_id > 0 then
				-- give a new ID and save
				local maxID = courseplay.courses.getMaxFolderID()
				for i = #folders_without_id, 1, -1 do
					maxID = maxID + 1
					folders_without_id[i].id = maxID
					folders_without_id[i].uid = 'f' .. maxID
					folders_by_id[maxID] = table.remove(folders_without_id)
				end
				save = true
			end		
			if save then
				-- this will overwrite the courseplay file and therefore delete the courses without ids and add them again with ids as they are now stored in g_currentMission with an id
				courseplay.courses.save_all()
			end
			
			g_currentMission.cp_sorted = courseplay.courses.sort(courses_by_id, folders_by_id, 0, 0)
						
			delete(cpFile);
		else
			--print("\t \"courseplay.xml\" missing from \"savegame" .. g_careerScreen.selectedIndex .. "\" folder");
		end; --END if fileExists
		
		courseplay:debug(tableShow(g_currentMission.cp_sorted.item, "cp_sorted.item", 8), 8);

		return g_currentMission.cp_courses;
	else
		print("Error: [Courseplay] current savegame could not be found.");
	end; --END if savegame ~= nil

	return nil;
end


--remove courseplayers from combine before it is reset and/or sold
function courseplay_manager:removeCourseplayersFromCombine(vehicle, callDelete)
	if vehicle.cp and vehicle.cameras then --Note: .cameras is used as a quick way to check if a vehicle is a steerable
		courseplay:debug(string.format('BaseMission:removeVehicle() -> courseplay_manager:removeCourseplayersFromCombine(%q, %s)', nameNum(vehicle), tostring(callDelete)), 4);
		for k,steerable in pairs(g_currentMission.steerables) do
			if steerable.cp and steerable.cp.savedCombine and steerable.cp.savedCombine == vehicle then
				courseplay:debug(string.format('\tsteerable %q: savedCombine is %q --> set savedCombine to nil, set selectedCombineNumber to 0, set HUD4savedCombine to false, set HUD4savedCombineName to "", reload hud page 4', nameNum(steerable), nameNum(vehicle)), 4);
				steerable.cp.savedCombine = nil;
				steerable.cp.selectedCombineNumber = 0;
				steerable.cp.HUD4savedCombine = false;
				steerable.cp.HUD4savedCombineName = '';
				courseplay.hud:setReloadPageOrder(steerable, 4, true);
			end;
		end;
	end;

	if vehicle.courseplayers ~= nil then
		local combine = vehicle;
		local numCourseplayers = #(combine.courseplayers);
		courseplay:debug(string.format('\t.courseplayers ~= nil (%d vehicles)', numCourseplayers), 4);

		if numCourseplayers > 0 then
			courseplay:debug(string.format('%s: has %d courseplayers -> unregistering all', nameNum(combine), numCourseplayers), 4);
			for i,tractor in pairs(combine.courseplayers) do
				courseplay:unregister_at_combine(tractor, combine);
				
				if tractor.cp.savedCombine ~= nil and tractor.cp.savedCombine == combine then
					tractor.cp.savedCombine = nil;
				end;
				tractor.cp.reachableCombines = nil;

				courseplay.hud:setReloadPageOrder(tractor, 4, true);
			end;
			courseplay:debug(string.format('%s: has %d courseplayers', nameNum(combine), numCourseplayers), 4);
		end;
	end;
end;
BaseMission.removeVehicle = Utils.prependedFunction(BaseMission.removeVehicle, courseplay_manager.removeCourseplayersFromCombine);




stream_debug_counter = 0

addModEventListener(courseplay_manager);

--
-- based on PlayerJoinFix
--
-- SFM-Modding
-- @author:  Manuel Leithner
-- @date:    01/08/11
-- @version: v1.1
-- @history: v1.0 - initial implementation
--           v1.1 - adaption to courseplay
--

local modName = g_currentModName;
local Server_sendObjects_old = Server.sendObjects;

function Server:sendObjects(connection, x, y, z, viewDistanceCoeff)
	connection:sendEvent(CourseplayJoinFixEvent:new());

	Server_sendObjects_old(self, connection, x, y, z, viewDistanceCoeff);
end


CourseplayJoinFixEvent = {};
CourseplayJoinFixEvent_mt = Class(CourseplayJoinFixEvent, Event);

InitEventClass(CourseplayJoinFixEvent, "CourseplayJoinFixEvent");

function CourseplayJoinFixEvent:emptyNew()
	local self = Event:new(CourseplayJoinFixEvent_mt);
	self.className = modName .. ".CourseplayJoinFixEvent";
	return self;
end

function CourseplayJoinFixEvent:new()
	local self = CourseplayJoinFixEvent:emptyNew()
	return self;
end

function CourseplayJoinFixEvent:writeStream(streamId, connection)


	if not connection:getIsServer() then
		--courseplay:debug("manager transfering courses", 8);
		--transfer courses
		local course_count = 0
		for _,_ in pairs(g_currentMission.cp_courses) do
			course_count = course_count + 1
		end
		streamDebugWriteInt32(streamId, course_count)
		print(string.format("\t### CourseplayMultiplayer: writing %d courses ", course_count ))
		for id, course in pairs(g_currentMission.cp_courses) do
			streamDebugWriteString(streamId, course.name)
			streamDebugWriteString(streamId, course.uid)
			streamDebugWriteString(streamId, course.type)
			streamDebugWriteInt32(streamId, course.id)
			streamDebugWriteInt32(streamId, course.parent)
			streamDebugWriteInt32(streamId, #(course.waypoints))
			for w = 1, #(course.waypoints) do
				streamDebugWriteFloat32(streamId, course.waypoints[w].cx)
				streamDebugWriteFloat32(streamId, course.waypoints[w].cz)
				streamDebugWriteFloat32(streamId, course.waypoints[w].angle)
				streamDebugWriteBool(streamId, course.waypoints[w].wait)
				streamDebugWriteBool(streamId, course.waypoints[w].rev)
				streamDebugWriteBool(streamId, course.waypoints[w].crossing)
				streamDebugWriteInt32(streamId, course.waypoints[w].speed)

				streamDebugWriteBool(streamId, course.waypoints[w].generated)
				streamDebugWriteString(streamId, (course.waypoints[w].laneDir or ""))
				streamDebugWriteString(streamId, course.waypoints[w].turn)
				streamDebugWriteBool(streamId, course.waypoints[w].turnStart)
				streamDebugWriteBool(streamId, course.waypoints[w].turnEnd)
				streamDebugWriteInt32(streamId, course.waypoints[w].ridgeMarker)
			end
		end
				
		local folderCount = 0
		for _,_ in pairs(g_currentMission.cp_folders) do
			folderCount = folderCount + 1
		end
		streamDebugWriteInt32(streamId, folderCount)
		print(string.format("\t### CourseplayMultiplayer: writing %d folders ", folderCount ))
		for id, folder in pairs(g_currentMission.cp_folders) do
			streamDebugWriteString(streamId, folder.name)
			streamDebugWriteString(streamId, folder.uid)
			streamDebugWriteString(streamId, folder.type)
			streamDebugWriteInt32(streamId, folder.id)
			streamDebugWriteInt32(streamId, folder.parent)
		end
				
		local fieldsCount = 0
		for _, field in pairs(courseplay.fields.fieldData) do
			if field.isCustom then
				fieldsCount = fieldsCount+1
			end
		end
		streamDebugWriteInt32(streamId, fieldsCount)
		print(string.format("\t### CourseplayMultiplayer: writing %d custom fields ", fieldsCount))
		for id, course in pairs(courseplay.fields.fieldData) do
			if course.isCustom then
				streamDebugWriteString(streamId, course.name)
				streamDebugWriteInt32(streamId, course.numPoints)
				streamDebugWriteBool(streamId, course.isCustom)
				streamDebugWriteInt32(streamId, course.fieldNum)
				streamDebugWriteInt32(streamId, #(course.points))
				for p = 1, #(course.points) do
					streamDebugWriteFloat32(streamId, course.points[p].cx)
					streamDebugWriteFloat32(streamId, course.points[p].cy)
					streamDebugWriteFloat32(streamId, course.points[p].cz)
				end
			end
		end
	end;
end

function CourseplayJoinFixEvent:readStream(streamId, connection)
	if connection:getIsServer() then
		local course_count = streamDebugReadInt32(streamId)
		print(string.format("\t### CourseplayMultiplayer: reading %d couses ", course_count ))
		g_currentMission.cp_courses = {}
		for i = 1, course_count do
			--courseplay:debug("got course", 8);
			local course_name = streamDebugReadString(streamId)
			local courseUid = streamDebugReadString(streamId)
			local courseType = streamDebugReadString(streamId)
			local course_id = streamDebugReadInt32(streamId)
			local courseParent = streamDebugReadInt32(streamId)
			local wp_count = streamDebugReadInt32(streamId)
			local waypoints = {}
			for w = 1, wp_count do
				--courseplay:debug("got waypoint", 8);
				local cx = streamDebugReadFloat32(streamId)
				local cz = streamDebugReadFloat32(streamId)
				local angle = streamDebugReadFloat32(streamId)
				local wait = streamDebugReadBool(streamId)
				local rev = streamDebugReadBool(streamId)
				local crossing = streamDebugReadBool(streamId)
				local speeed = streamDebugReadInt32(streamId)

				local generated = streamDebugReadBool(streamId)
				local dir = streamDebugReadString(streamId)
				local turn = streamDebugReadString(streamId)
				local turnStart = streamDebugReadBool(streamId)
				local turnEnd = streamDebugReadBool(streamId)
				local ridgeMarker = streamDebugReadInt32(streamId)
				
				local wp = {
					cx = cx, 
					cz = cz, 
					angle = angle, 
					wait = wait, 
					rev = rev, 
					crossing = crossing, 
					speed = speed,
					generated = generated,
					laneDir = dir,
					turn = turn,
					turnStart = turnStart,
					turnEnd = turnEnd,
					ridgeMarker = ridgeMarker 
				};
				table.insert(waypoints, wp)
			end
			local course = { id = course_id, uid = courseUid, type = courseType, name = course_name, nameClean = courseplay:normalizeUTF8(course_name), waypoints = waypoints, parent = courseParent }
			g_currentMission.cp_courses[course_id] = course
			g_currentMission.cp_sorted = courseplay.courses.sort()
		end
		
		local folderCount = streamDebugReadInt32(streamId)
		print(string.format("\t### CourseplayMultiplayer: reading %d folders ", folderCount ))
		g_currentMission.cp_folders = {}
		for i = 1, folderCount do
			local folderName = streamDebugReadString(streamId)
			local folderUid = streamDebugReadString(streamId)
			local folderType = streamDebugReadString(streamId)
			local folderId = streamDebugReadInt32(streamId)
			local folderParent = streamDebugReadInt32(streamId)
			local folder = { id = folderId, uid = folderUid, type = folderType, name = folderName, nameClean = courseplay:normalizeUTF8(folderName), parent = folderParent }
			g_currentMission.cp_folders[folderId] = folder
			g_currentMission.cp_sorted = courseplay.courses.sort(g_currentMission.cp_courses, g_currentMission.cp_folders, 0, 0)
		end
		
		local fieldsCount = streamDebugReadInt32(streamId)		
		print(string.format("\t### CourseplayMultiplayer: reading %d custom fields ", fieldsCount))
		courseplay.fields.fieldData = {}
		for i = 1, fieldsCount do
			local name = streamDebugReadString(streamId)
			local numPoints = streamDebugReadInt32(streamId)
			local isCustom = streamDebugReadBool(streamId)
			local fieldNum = streamDebugReadInt32(streamId)
			local ammountPoints = streamDebugReadInt32(streamId)
			local waypoints = {}
			for w = 1, ammountPoints do 
				local cx = streamDebugReadFloat32(streamId)
				local cy = streamDebugReadFloat32(streamId)
				local cz = streamDebugReadFloat32(streamId)
				local wp = { cx = cx, cy = cy, cz = cz}
				table.insert(waypoints, wp)
			end
			local field = { name = name, numPoints = numPoints, isCustom = isCustom, fieldNum = fieldNum, points = waypoints}
			courseplay.fields.fieldData[fieldNum] = field
		end
		print("\t### CourseplayMultiplayer: courses/folders reading end")
	end;
end

function CourseplayJoinFixEvent:run(connection)
	--courseplay:debug("CourseplayJoinFixEvent Run function should never be called", 8);
end;