courseplay_manager = {};
local courseplay_manager_mt = Class(courseplay_manager);

function courseplay_manager:loadMap(name)
	self.isCourseplayManager = true;

	if not courseplay.globalDataSet then
		courseplay:setGlobalData();
	end;

	if courseplay.isDeveloper then
		addConsoleCommand('cpAddMoney', ('Add %s to your bank account'):format(g_i18n:formatMoney(5000000)), 'devAddMoney', self);
		addConsoleCommand('cpAddFillLevels', 'Add 500\'000 l to all of your silos', 'devAddFillLevels', self);
	end;

	self.firstRun = true;
	-- height for mouse text line in game's help menu
	self.hudHelpMouseLineHeight = g_currentMission.hudHelpTextSize + g_currentMission.hudHelpTextLineSpacing*2;

	self.showFieldScanYesNoDialogue = false;
	self.showWagesYesNoDialogue = false;
	self:createInitialCourseplayFile();

	if g_currentMission.cp_courses == nil then
		--courseplay:debug("cp courses was nil and initialized", 8);
		g_currentMission.cp_courses = {};
		g_currentMission.cp_folders = {};
		g_currentMission.cp_sorted = {item={}, info={}};

		if g_server ~= nil and next(g_currentMission.cp_courses) == nil then
			courseplay_manager:load_courses()
			-- courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		end
	end;

	self.buttons = {};

	-- GLOBAL INFO TEXT
	self.globalInfoTextMaxNum = 20;
	self.globalInfoTextOverlays = {};
	self.buttons.globalInfoText = {};
	local git = courseplay.globalInfoText;
	for i=1,self.globalInfoTextMaxNum do
		local posY = git.backgroundPosY + (i - 1) * git.lineHeight;
		self.globalInfoTextOverlays[i] = Overlay:new(string.format("globalInfoTextOverlay%d", i), git.backgroundImg, git.backgroundPosX, posY, 0.1, git.buttonHeight);
		courseplay.button:new(self, 'globalInfoText', 'iconSprite.png', 'goToVehicle', i, git.buttonPosX, posY, git.buttonWidth, git.buttonHeight);
	end;
	self.buttons.globalInfoTextClickArea = {
		x1 = git.buttonPosX;
		x2 = git.buttonPosX + git.buttonWidth;
		y1 = git.backgroundPosY,
		y2 = git.backgroundPosY + (self.globalInfoTextMaxNum  * (git.lineHeight + git.lineMargin));
	};
	self.globalInfoTextHasContent = false;

	self.playerOnFootMouseEnabled = false;
	self.wasPlayerFrozen = false;

	-- FIELD SCAN INFO DISPLAY
	self.fieldScanInfo = {};
	self.fieldScanInfo.fileW = 512/1080 / g_screenAspectRatio; --512/1920;
	self.fieldScanInfo.fileH = 256/1080;
	self.fieldScanInfo.contentW = 426/1080 / g_screenAspectRatio; --426/1920;
	self.fieldScanInfo.contentH = 180/1080;
	self.fieldScanInfo.bgX, self.fieldScanInfo.bgY = 0.5 - self.fieldScanInfo.contentW/2, 0.5 - self.fieldScanInfo.contentH/2;
	local bgPath = Utils.getFilename('img/fieldScanInfoBackground.png', courseplay.path);
	self.fieldScanInfo.bgOverlay = Overlay:new('fieldScanInfoBackground', bgPath, self.fieldScanInfo.bgX, self.fieldScanInfo.bgY, self.fieldScanInfo.fileW, self.fieldScanInfo.fileH);
	local xPadding = 20/1080 / g_screenAspectRatio; --20/1920;
	self.fieldScanInfo.lineX  = self.fieldScanInfo.bgX + xPadding;
	self.fieldScanInfo.line1Y = self.fieldScanInfo.bgY + 67/1080;
	self.fieldScanInfo.line2Y = self.fieldScanInfo.bgY + 40/1080;
	self.fieldScanInfo.loadX  = self.fieldScanInfo.bgX + 340/1080 / g_screenAspectRatio; --340/1920;
	self.fieldScanInfo.loadY  = self.fieldScanInfo.bgY + 57/1080;

	local loadingPath = Utils.getFilename('img/fieldScanInfoLoading.png', courseplay.path);
	self.fieldScanInfo.loadOverlay = Overlay:new('fieldScanInfoLoad', loadingPath, self.fieldScanInfo.loadX, self.fieldScanInfo.loadY, 32/1080 / g_screenAspectRatio, 32/1080);
	self.fieldScanInfo.loadRotStep = 0;
	self.fieldScanInfo.loadRotAdd = math.rad(-360/72); --rotate 5° to the right each step
	self.fieldScanInfo.rotationTime = 1000/72; --in ms

	self.fieldScanInfo.progressBarWidth = self.fieldScanInfo.contentW - 2 * xPadding - 5/1920;
	local progressBarBgPath = Utils.getFilename('img/progressBarBackground.png', courseplay.path);
	self.fieldScanInfo.progressBarBgOverlay = Overlay:new('fieldScanInfoProgressBarBg', progressBarBgPath, self.fieldScanInfo.lineX, self.fieldScanInfo.bgY + 16/1080, self.fieldScanInfo.progressBarWidth, 16/1080);
	local progressBarPath = Utils.getFilename('img/progressBar.png', courseplay.path);
	self.fieldScanInfo.progressBarOverlay = Overlay:new('fieldScanInfoProgressBar', progressBarPath, self.fieldScanInfo.lineX, self.fieldScanInfo.bgY + 16/1080, self.fieldScanInfo.progressBarWidth, 16/1080);
	self.fieldScanInfo.percentColors = {
		{ pct = 0.0, color = { 225/255,  27/255, 0/255 } },
		{ pct = 0.5, color = { 255/255, 204/255, 0/255 } },
		{ pct = 1.0, color = { 137/255, 243/255, 0/255 } }
	};


	if g_server ~= nil then
		courseplay.fields:loadAllCustomFields();
	end;

	courseplay.totalCoursePlayers = {};
	courseplay.activeCoursePlayers = {};

	courseplay.wageDifficultyMultiplier = Utils.lerp(0.5, 1, (g_currentMission.missionStats.difficulty - 1) / 2);

	g_currentMission.environment:addMinuteChangeListener(courseplay_manager);
	self.realTimeMinuteTimer = 0;
	self.realTime10SecsTimer = 0;
end;

-- Giants - very intelligently - deletes any mod file in the savegame folder when saving. And now we get it back!
local function backupCpFiles(self)
	if g_server == nil and g_dedicatedServerInfo == nil then return end;

	if not fileExists(courseplay.cpXmlFilePath) then
		-- ERROR: CP FILE DOESN'T EXIST
		return;
	end;

	-- backup CP files before saveSavegame() deletes them
	local savegameIndex = g_currentMission.missionInfo.savegameIndex;
	courseplay_manager.cpTempSaveFolderPath = getUserProfileAppPath() .. 'courseplayBackupSavegame' .. savegameIndex;
	createFolder(courseplay_manager.cpTempSaveFolderPath);
	-- print('create folder at ' .. courseplay_manager.cpTempSaveFolderPath);
	courseplay_manager.cpFileBackupPath = courseplay_manager.cpTempSaveFolderPath .. '/courseplay.xml';
	copyFile(courseplay.cpXmlFilePath, courseplay_manager.cpFileBackupPath, true);
	-- print('copy cp file to backup folder: ' .. courseplay_manager.cpFileBackupPath);

	if fileExists(courseplay.cpFieldsXmlFilePath) then
		courseplay_manager.cpFieldsFileBackupPath = courseplay_manager.cpTempSaveFolderPath .. '/courseplayFields.xml';
		copyFile(courseplay.cpFieldsXmlFilePath, courseplay_manager.cpFieldsFileBackupPath, true);
		-- print('copy cp fields file to backup folder: ' .. courseplay_manager.cpFieldsFileBackupPath);
	end;
end;
g_careerScreen.saveSavegame = Utils.prependedFunction(g_careerScreen.saveSavegame, backupCpFiles);

local function getThatFuckerBack(self)
	if g_server == nil and g_dedicatedServerInfo == nil then return end;

	if not courseplay_manager.cpFileBackupPath then return end;

	local savegameIndex = g_currentMission.missionInfo.savegameIndex;
	local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory or courseplay.savegameFolderPath;
	if savegameFolderPath == nil then
		savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), savegameIndex);
	end;

	if fileExists(savegameFolderPath .. '/careerSavegame.xml') then -- savegame isn't corrupted and has been saved correctly
		-- print('orig savegame folder still exists');

		-- copy backed up files back to our savegame directory
		-- print('copy backup cp file to orig savegame folder');
		copyFile(courseplay_manager.cpFileBackupPath, courseplay.cpXmlFilePath, true);
		courseplay_manager.cpFileBackupPath = nil;
		if courseplay_manager.cpFieldsFileBackupPath then
			-- print('copy backup cp fields file to orig savegame folder');
			copyFile(courseplay_manager.cpFieldsFileBackupPath, courseplay.cpFieldsXmlFilePath, true);
			courseplay_manager.cpFieldsFileBackupPath = nil;
		end;

		deleteFolder(courseplay_manager.cpTempSaveFolderPath);
		-- print('delete backup folder');

	else -- corrupt savegame: display backup info message
		print(('This savegame has been corrupted. The Courseplay file has been backed up to %q'):format(courseplay_manager.cpTempSaveFolderPath));

		local msgTitle = 'Courseplay';
		local msgTxt = 'This savegame has been corrupted.';
		if courseplay_manager.cpFieldsFileBackupPath then
			msgTxt = msgTxt .. ('\nYour Courseplay files have been backed up to the %q directory.'):format('courseplayBackupSavegame' .. savegameIndex);
		else
			msgTxt = msgTxt .. ('\nYour Courseplay file has been backed up to the %q directory.'):format('courseplayBackupSavegame' .. savegameIndex);
		end;
		msgTxt = msgTxt .. ('\n\nFull path: %q'):format(courseplay_manager.cpTempSaveFolderPath);
		g_currentMission.inGameMessage:showMessage(msgTitle, msgTxt, 15000, false);
	end;
end;
g_careerScreen.saveSavegame = Utils.appendedFunction(g_careerScreen.saveSavegame, getThatFuckerBack);

function courseplay_manager:createInitialCourseplayFile()
	if courseplay.cpXmlFilePath then
		createFolder(courseplay.savegameFolderPath);
		local file;
		local created, changed = false, false;
		if not fileExists(courseplay.cpXmlFilePath) then
			file = createXMLFile('courseplayFile', courseplay.cpXmlFilePath, 'XML');
			created = true;
			self.showFieldScanYesNoDialogue = true;
			self.showWagesYesNoDialogue = true;
			-- print(string.format('\tcreateXmlFile("courseplayFile", [path], XML), file=%s', tostring(file)));
		else
			file = loadXMLFile('courseplayFile', courseplay.cpXmlFilePath);
			-- print(string.format('\tloadXMLFile("courseplayFile", [path]), file=%s', tostring(file)));
		end;

		local data = {
			{ tag = 'courseplayHud', attr = 'posX', value = ('%.3f'):format(courseplay.hud.infoBasePosX), get = 'Float', set = 'String' };
			{ tag = 'courseplayHud', attr = 'posY', value = ('%.3f'):format(courseplay.hud.infoBasePosY), get = 'Float', set = 'String' };

			{ tag = 'courseplayFields', attr = 'automaticScan', value = tostring(courseplay.fields.automaticScan), get = 'Bool', set = 'String' };
			{ tag = 'courseplayFields', attr = 'onlyScanOwnedFields', value = tostring(courseplay.fields.onlyScanOwnedFields), get = 'Bool', set = 'String' };
			{ tag = 'courseplayFields', attr = 'debugScannedFields', value = tostring(courseplay.fields.debugScannedFields), get = 'Bool', set = 'String' };
			{ tag = 'courseplayFields', attr = 'debugCustomLoadedFields', value = tostring(courseplay.fields.debugCustomLoadedFields), get = 'Bool', set = 'String' };
			{ tag = 'courseplayFields', attr = 'scanStep', value = courseplay.fields.scanStep, get = 'Int', set = 'Int' };

			{ tag = 'courseplayWages', attr = 'active', value = tostring(courseplay.wagesActive), get = 'Bool', set = 'String' };
			{ tag = 'courseplayWages', attr = 'wagePerHour', value = courseplay.wagePerHour, get = 'Int', set = 'Int' };

			{ tag = 'courseplayIngameMap', attr = 'active',		value = tostring(courseplay.ingameMapIconActive),	  get = 'Bool', set = 'String' };
			{ tag = 'courseplayIngameMap', attr = 'showName',	value = tostring(courseplay.ingameMapIconShowName),	  get = 'Bool', set = 'String' };
			{ tag = 'courseplayIngameMap', attr = 'showCourse',	value = tostring(courseplay.ingameMapIconShowCourse), get = 'Bool', set = 'String' };
		};

		for _,d in ipairs(data) do
			local node = ('XML.%s#%s'):format(d.tag, d.attr);
			if created or courseplay.prmGetXMLFn[d.get](file, node) == nil then
				courseplay.prmSetXMLFn[d.set](file, node, d.value);
				changed = true;
			end;
		end;

		if changed then
			saveXMLFile(file);
		end;
		delete(file);
	end;
end;

function courseplay_manager:deleteMap()
	--courses & folders
	g_currentMission.cp_courses = nil
	g_currentMission.cp_folders = nil
	g_currentMission.cp_sorted = nil

	-- debug channels
	for channel,_ in pairs(courseplay.debugChannels) do
		courseplay.debugChannels[channel] = false;
	end;

	--buttons
	for i,vehicle in pairs(g_currentMission.steerables) do
		if vehicle.cp ~= nil and vehicle.cp.hasCourseplaySpec then
			if vehicle.cp.globalInfoTextOverlay ~= nil then
				vehicle.cp.globalInfoTextOverlay:delete();
			end;
			if vehicle.cp.buttons ~= nil then
				courseplay.buttons:deleteButtonOverlays(vehicle);
			end;
		end;
	end;

	--global info text
	for i,button in pairs(self.buttons.globalInfoText) do
		button:deleteOverlay();

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
			courseplay.utils.signs:deleteSign(signData.sign);
		end;
		courseplay.signs.buffer[section] = {};
	end;

	--fields
	courseplay.fields.fieldData = {};
	courseplay.fields.curFieldScanIndex = 0;
	courseplay.fields.allFieldsScanned = false;
	courseplay.fields.ingameDataSetUp = false;
	for i,fruitData in pairs(courseplay.fields.seedUsageCalculator.fruitTypes) do
		if fruitData.overlay then
			fruitData.overlay:delete();
		end;
	end;
	courseplay.fields.seedUsageCalculator = {};
	courseplay.fields.seedUsageCalculator.fieldsWithoutSeedData = {};

	if courseplay.inputBindings.mouse.overlaySecondary then
		courseplay.inputBindings.mouse.overlaySecondary:delete();
		courseplay.inputBindings.mouse.overlaySecondary = nil;
	end;


	-- load/set global again on new map
	courseplay.globalDataSet = false;
end;

function courseplay_manager:draw()
	if g_currentMission.paused then
		return;
	end;

	self.globalInfoTextHasContent = false;
	local git = courseplay.globalInfoText;
	local line = 0;
	local basePosY = courseplay.globalInfoText.backgroundPosY;
	local ingameMap = g_currentMission.ingameMap;
	if not (ingameMap.isVisible and ingameMap:getIsFullSize()) and next(courseplay.globalInfoText.content) ~= nil then
		self.globalInfoTextHasContent = true;
		basePosY = ingameMap.isVisible and git.posYAboveMap or git.posY;
		for _,refIndexes in pairs(git.content) do
			if line >= self.globalInfoTextMaxNum then
				break;
			end;

			for refIdx,data in pairs(refIndexes) do
				line = line + 1;

				-- background
				local bg = self.globalInfoTextOverlays[line];
				bg:setColor(unpack(git.levelColors[data.level]));
				local gfxPosY = basePosY + (line - 1) * (git.lineHeight + git.lineMargin);
				bg:setPosition(bg.x, gfxPosY);
				bg:setDimension(data.backgroundWidth, bg.height);
				bg:render();

				-- text
				courseplay:setFontSettings('white', false);
				local textPosY = gfxPosY + (git.lineHeight - git.fontSize) * 1.2; -- should be (lineHeight-fontSize)*0.5, but there seems to be some pixel/sub-pixel rendering error
				renderText(git.textPosX, textPosY, git.fontSize, data.text);

				-- button
				local button = self.buttons.globalInfoText[line];
				if button ~= nil then
					button:setPosition(button.overlay.x, gfxPosY)

					local currentColor = button.curColor;
					local targetColor = currentColor;

					button:setCanBeClicked(true);
					button:setDisabled(data.vehicle.isBroken or data.vehicle.isControlled);
					button:setParameter(data.vehicle);
					if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle == data.vehicle then
						targetColor = 'activeGreen';
						button:setCanBeClicked(false);
					elseif button.isDisabled then
						targetColor = 'whiteDisabled';
					elseif button.isClicked then
						targetColor = 'activeRed';
					elseif button.isHovered then
						targetColor = 'hover';
					else
						targetColor = 'white';
					end;

					-- set color
					if currentColor ~= targetColor then
						button:setColor(targetColor);
					end;

					-- NOTE: do not use button:render() here, as we neither need the button.show check, nor the hoveredButton var, nor the color setting. Simply rendering the overlay suffices
					button.overlay:render();
				end;
			end;
		end;
	end;
	self.buttons.globalInfoTextClickArea.y2 = basePosY + (line  * (git.lineHeight + git.lineMargin));

	-- DISPLAY FIELD SCAN MSG
	if courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned then
		local fsi = self.fieldScanInfo;

		fsi.progressBarBgOverlay:render();
		local pct = courseplay.fields.curFieldScanIndex / g_currentMission.fieldDefinitionBase.numberOfFields;
		local r, g, b = self:getColorFromPct(pct, fsi.percentColors);
		fsi.progressBarOverlay:setColor(r, g, b, 1);
		fsi.progressBarOverlay.width = fsi.progressBarWidth * pct;
  		setOverlayUVs(fsi.progressBarOverlay.overlayId, 0,0, 0,1, pct,0, pct,1);
		fsi.progressBarOverlay:render();

		fsi.bgOverlay:render();

		courseplay:setFontSettings({ 0.8, 0.8, 0.8, 1 }, true, 'left');
		renderText(fsi.lineX, fsi.line1Y - 0.001, courseplay.hud.fontSizes.fieldScanTitle, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));
		courseplay:setFontSettings('shadow', true, 'left');
		renderText(fsi.lineX, fsi.line1Y,         courseplay.hud.fontSizes.fieldScanTitle, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));

		local str2 = courseplay:loc('COURSEPLAY_SCANNING_FIELD_NMB'):format(courseplay.fields.curFieldScanIndex, g_currentMission.fieldDefinitionBase.numberOfFields);
		courseplay:setFontSettings({ 0.8, 0.8, 0.8, 1 }, false, 'left');
		renderText(fsi.lineX, fsi.line2Y - 0.001, courseplay.hud.fontSizes.fieldScanData, str2);
		courseplay:setFontSettings('shadow', false, 'left');
		renderText(fsi.lineX, fsi.line2Y,         courseplay.hud.fontSizes.fieldScanData, str2);

		local rotationStep = math.floor(g_currentMission.time / self.fieldScanInfo.rotationTime);
		if rotationStep > fsi.loadRotStep then
			fsi.loadOverlay:setRotation(rotationStep * fsi.loadRotAdd, fsi.loadOverlay.width/2, fsi.loadOverlay.height/2);
			fsi.loadRotStep = rotationStep;
		end;
		fsi.loadOverlay:render();

		--reset font settings
		courseplay:setFontSettings('white', true, 'left');
	end;

	-- HELP MENU
	if g_currentMission.controlledVehicle == nil and not g_currentMission.player.currentTool then
		if self.playerOnFootMouseEnabled then
			g_currentMission:addHelpTextFunction(courseplay.drawMouseButtonHelp, courseplay, self.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_HIDE'));
		elseif self.globalInfoTextHasContent then
			g_currentMission:addHelpTextFunction(courseplay.drawMouseButtonHelp, courseplay, self.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_SHOW'));
		end;
	end;
end;

function courseplay_manager:getColorFromPct(pct, colorMap)
	local step = colorMap[2].pct - colorMap[1].pct;

	if pct == 0 then
		return unpack(colorMap[1].color);
	end;

	for i=2, #colorMap do
		local data = colorMap[i];
		if pct == data.pct then
			return unpack(data.color);
		end;

		if pct < data.pct then
			local lower = colorMap[i - 1];
			local upper = colorMap[i];
			local pctAlpha = (pct - lower.pct) / step;
			return Utils.vector3ArrayLerp(lower.color, upper.color, pctAlpha);
		end;
	end;
end;


function courseplay_manager:mouseEvent(posX, posY, isDown, isUp, mouseKey)
	if g_currentMission.paused then return; end;

	local area = courseplay_manager.buttons.globalInfoTextClickArea;
	if area == nil then
		return;
	end;

	--LEFT CLICK
	if (isDown or isUp) and mouseKey == courseplay.inputBindings.mouse.primaryButtonId and courseplay:mouseIsInArea(posX, posY, area.x1, area.x2, area.y1, area.y2) then
		if self.globalInfoTextHasContent then
			for i,button in pairs(self.buttons.globalInfoText) do
				if button.show and button:getHasMouse(posX, posY) then
					button:setClicked(isDown);
					if isUp then
						local sourceVehicle = g_currentMission.controlledVehicle or button.parameter;
						button:handleMouseClick(sourceVehicle);
					end;
					break;
				end;
			end;
		end;

	--RIGHT CLICK
	elseif isUp and mouseKey == courseplay.inputBindings.mouse.secondaryButtonId and g_currentMission.controlledVehicle == nil then
		if self.globalInfoTextHasContent and not self.playerOnFootMouseEnabled and not g_currentMission.player.currentTool then
			self.playerOnFootMouseEnabled = true;
			self.wasPlayerFrozen = g_currentMission.isPlayerFrozen;
			g_currentMission.isPlayerFrozen = true;
		elseif self.playerOnFootMouseEnabled then
			self.playerOnFootMouseEnabled = false;
			if self.globalInfoTextHasContent then --if a button was hovered when deactivating the cursor, deactivate hover state
				for _,button in pairs(self.buttons.globalInfoText) do
					button:setClicked(false);
					button:setHovered(false);
				end;
			end;
			if not self.wasPlayerFrozen then
				g_currentMission.isPlayerFrozen = false;
			end;
		end;
		--print(string.format("right mouse click: playerOnFootMouseEnabled=%s, wasPlayerFrozen=%s, isPlayerFrozen=%s", tostring(self.playerOnFootMouseEnabled), tostring(self.wasPlayerFrozen), tostring(g_currentMission.isPlayerFrozen)));
		InputBinding.setShowMouseCursor(self.playerOnFootMouseEnabled);

	--HOVER
	elseif not isDown and not isUp and self.globalInfoTextHasContent then
		for _,button in pairs(self.buttons.globalInfoText) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setHovered(button:getHasMouse(posX, posY));
			end;
		end;
	end;
end;

function courseplay_manager:fieldScanDialogueCallback(setActive)
	courseplay.fields.automaticScan = setActive;
	local file = loadXMLFile('courseplayFile', courseplay.cpXmlFilePath);
	if file and file ~= 0 then
		setXMLBool(file, 'XML.courseplayFields#automaticScan', setActive);
		saveXMLFile(file);
		delete(file);
	end;
	g_gui:showGui('');
end;

function courseplay_manager:wagesDialogueCallback(setActive)
	courseplay.wagesActive = setActive;
	local file = loadXMLFile('courseplayFile', courseplay.cpXmlFilePath);
	if file and file ~= 0 then
		setXMLBool(file, 'XML.courseplayWages#active', setActive);
		saveXMLFile(file);
		delete(file);
	end;
	g_gui:showGui('');
end;

function courseplay_manager:update(dt)
	if g_gui.currentGui ~= nil and g_gui.currentGuiName ~= 'inputCourseNameDialogue' then
		return;
	end;

	if self.firstRun then
		courseplay:addCpNilTempFillLevelFunction();

		self.firstRun = false;
	end;

	-- Field scan, wages yes/no dialogue -START-
	if not g_currentMission.paused and g_gui.currentGui == nil then
		if self.showFieldScanYesNoDialogue then
			local yesNoDialogue = g_gui:showGui('YesNoDialog');
			yesNoDialogue.target.titleElement:setText('Courseplay');
			yesNoDialogue.target:setText(courseplay:loc('COURSEPLAY_YES_NO_FIELDSCAN'));
			yesNoDialogue.target:setCallbacks(self.fieldScanDialogueCallback, self);
			self.showFieldScanYesNoDialogue = false;
		elseif self.showWagesYesNoDialogue then
			local yesNoDialogue = g_gui:showGui('YesNoDialog');
			yesNoDialogue.target.titleElement:setText('Courseplay');
			local txt = courseplay:loc('COURSEPLAY_YES_NO_WAGES'):format(g_i18n:formatMoney(g_i18n:getCurrency(courseplay.wagePerHour * courseplay.wageDifficultyMultiplier), 2));
			yesNoDialogue.target:setText(txt);
			yesNoDialogue.target:setCallbacks(self.wagesDialogueCallback, self);
			self.showWagesYesNoDialogue = false;
		end;
	end;
	-- Field scan, wages yes/n dialogue - END -

	--SETUP FIELD INGAME DATA
	if not courseplay.fields.ingameDataSetUp then
		courseplay.fields:setUpFieldsIngameData();
	end;

	--SCAN ALL FIELD EDGES
	if courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned then
		courseplay.fields:setAllFieldEdges();
	end;

	-- REAL TIME MINUTE CHANGER
	if not g_currentMission.paused and courseplay.wagesActive and g_server ~= nil then -- TODO: if there are more items to be dealt with every 10 secs, remove the "wagesActive" restriction
		if self.realTime10SecsTimer < 10000 then
			self.realTime10SecsTimer = self.realTime10SecsTimer + dt;
		else
			self:realTime10SecsChanged();
			self.realTime10SecsTimer = self.realTime10SecsTimer - 10000;
		end;
	end;
end;

function courseplay_manager:keyEvent() end;

function courseplay_manager:load_courses()
	--print("courseplay_manager:load_courses()");
	courseplay:debug('loading courses by courseplay manager', 8);

	local finish_all = false;
	if courseplay.cpXmlFilePath then
		local filePath = courseplay.cpXmlFilePath;

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
						
						--is it a old savegame with old speeds ?
						if math.ceil(speed) ~= speed then
							speed = math.ceil(speed*3600)							
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
			-- print(('\t"courseplay.xml" missing at %q'):format(tostring(courseplay.cpXmlFilePath);
		end; --END if fileExists
		
		courseplay:debug(tableShow(g_currentMission.cp_sorted.item, "cp_sorted.item", 8), 8);

		return g_currentMission.cp_courses;
	else
		print(('Error: [Courseplay] current savegame could not be found at %q.'):format(courseplay.cpXmlFilePath));
	end; --END if savegame ~= nil

	return nil;
end


--remove courseplayers from combine / combine from tractor before it is reset and/or sold
function courseplay_manager:severCombineTractorConnection(vehicle, callDelete)
	if vehicle.cp then
		-- VEHICLE IS COMBINE
		if vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or courseplay:isSpecialChopper(vehicle) then
			courseplay:debug(('BaseMission:removeVehicle() -> severCombineTractorConnection(%q, %s) [VEHICLE IS COMBINE]'):format(nameNum(vehicle), tostring(callDelete)), 4);
			local combine = vehicle;
			-- remove this combine as savedCombine from all tractors
			for i,tractor in pairs(g_currentMission.steerables) do
				if tractor.cp and tractor.cp.savedCombine and tractor.cp.savedCombine == combine and tractor.cp.hasCourseplaySpec  then
					courseplay:debug(('\ttractor %q: savedCombine=%q --> removeSavedCombineFromTractor()'):format(nameNum(tractor), nameNum(combine)), 4);
					courseplay:removeSavedCombineFromTractor(tractor);
				end;
			end;

			-- unregister all tractors from this combine (activeCombine)
			if combine.courseplayers ~= nil then
				courseplay:debug(('\t.courseplayers ~= nil (%d courseplayers)'):format(#combine.courseplayers), 4);
				if #combine.courseplayers > 0 then
					for i,tractor in pairs(combine.courseplayers) do
						courseplay:debug(('\t\t%q: removeActiveCombineFromTractor(), removeSavedCombineFromTractor()'):format(nameNum(tractor)), 4);
						courseplay:removeActiveCombineFromTractor(tractor);
						courseplay:removeSavedCombineFromTractor(tractor); --TODO (Jakob): unnecessary, as done above in steerables table already?
						tractor.cp.reachableCombines = nil;
					end;
					courseplay:debug(('\t-> now has %d courseplayers'):format(#combine.courseplayers), 4);
				end;
			end;

		-- VEHICLE IS TRACTOR
		elseif vehicle.cp.activeCombine ~= nil or vehicle.cp.lastActiveCombine ~= nil or vehicle.cp.savedCombine ~= nil then
			courseplay:debug(('BaseMission:removeVehicle() -> severCombineTractorConnection(%q, %s) [VEHICLE IS TRACTOR]'):format(nameNum(vehicle), tostring(callDelete)), 4);
			courseplay:debug(('\tactiveCombine=%q, lastActiveCombine=%q, savedCombine=%q -> removeActiveCombineFromTractor(), removeSavedCombineFromTractor()'):format(nameNum(vehicle.cp.activeCombine), nameNum(vehicle.cp.lastActiveCombine), nameNum(vehicle.cp.savedCombine)), 4);
			courseplay:removeActiveCombineFromTractor(vehicle);
			courseplay:removeSavedCombineFromTractor(vehicle);
			courseplay:debug(('\t-> activeCombine=%q, lastActiveCombine=%q, savedCombine=%q'):format(nameNum(vehicle.cp.activeCombine), nameNum(vehicle.cp.lastActiveCombine), nameNum(vehicle.cp.savedCombine)), 4);
		end;
	end;
end;
BaseMission.removeVehicle = Utils.prependedFunction(BaseMission.removeVehicle, courseplay_manager.severCombineTractorConnection);

function courseplay_manager:devAddMoney()
	if g_server ~= nil then
		g_currentMission:addSharedMoney(5000000, 'other');
		return ('Added %s to your bank account'):format(g_i18n:formatMoney(5000000));
	end;
end;
function courseplay_manager:devAddFillLevels()
	if g_server ~= nil then
		for fillType=1,Fillable.NUM_FILLTYPES do
			g_currentMission:setSiloAmount(fillType, g_currentMission:getSiloAmount(fillType) + 500000);
		end;
		return 'All silo fill levels increased by 500\'000.';
	end;
end;

local nightStart, dayStart = 19 * 3600000, 7.5 * 3600000; -- from 7pm until 7:30am
function courseplay_manager:minuteChanged()
	-- WEATHER
	local env = g_currentMission.environment;
	courseplay.lightsNeeded = env.needsLights or (env.dayTime >= nightStart or env.dayTime <= dayStart) or env.currentRain ~= nil or env.curRain ~= nil or (env.lastRainScale > 0.1 and env.timeSinceLastRain < 30);
end;

function courseplay_manager:realTime10SecsChanged()
	-- WAGES
	if courseplay.wagesActive and g_server ~= nil then
		local totalWages = 0;
		for vehicleNum, vehicle in pairs(courseplay.activeCoursePlayers) do
			if vehicle:getIsCourseplayDriving() and not vehicle.isHired then
				totalWages = totalWages + courseplay.wagePerMin;
			end;
		end;
		if totalWages > 0 then
			-- TODO (Jakob): does addSharedMoney already include the currency factor, or do we have to calculate it before passing it?
			g_currentMission:addSharedMoney(-totalWages * courseplay.wageDifficultyMultiplier / 6, 'wagePayment'); -- divide by 6 to get wage per 10 secs
		end;
	end;
end;

addModEventListener(courseplay_manager);



stream_debug_counter = 0


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
				local speed = streamDebugReadInt32(streamId)

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