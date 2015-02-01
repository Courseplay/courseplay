local curFile = 'CpManager.lua';
CpManager = {};
local CpManager_mt = Class(CpManager);
addModEventListener(CpManager);



function CpManager:loadMap(name)
	self.isCourseplayManager = true;
	self.firstRun = true;

	-- MULTIPLAYER
	CpManager.isMP = g_currentMission.missionDynamicInfo.isMultiplayer;
	courseplay.isClient = not g_server; -- TODO JT: not needed, as every vehicle always has self.isServer and self.isClient

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- XML PATHS
	if g_server ~= nil then
		local savegameDir;
		if g_currentMission.missionInfo.savegameDirectory then
			savegameDir = g_currentMission.missionInfo.savegameDirectory;
		end;
		if not savegameDir and g_careerScreen.currentSavegame and g_careerScreen.currentSavegame.savegameIndex then -- TODO (Jakob): g_careerScreen.currentSavegame not available on DS. MP maybe as well
			savegameDir = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.currentSavegame.savegameIndex);
		end;
		if not savegameDir and g_currentMission.missionInfo.savegameIndex ~= nil then
			savegameDir = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.missionInfo.savegameIndex);
		end;
		self.savegameFolderPath = savegameDir;
		self.cpXmlFilePath = self.savegameFolderPath .. '/courseplay.xml';
		self.cpFieldsXmlFilePath = self.savegameFolderPath .. '/courseplayFields.xml';
	end
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- SETUP DEFAULT GLOBAL DATA
	courseplay.signs:setup();
	courseplay.fields:setup();
	self.showFieldScanYesNoDialogue = false;
	self:setupWages();
	self:setupIngameMap();
	courseplay.courses:setup(); -- NOTE: this call is only to set up batchWriteSize, without loading anything
	self:setup2dCourseData(false); -- NOTE: this call is only to initiate the position and opacity

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- LOAD SETTINGS FROM COURSEPLAY.XML / SAVE DEFAULT SETTINGS IF NOT EXISTING
	if g_server ~= nil then
		self:loadOrSetXmlSettings();
	end
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- SETUP (continued)
	courseplay.hud:setup(); -- NOTE: hud has to be set up after the xml settings have been loaded, as almost all its values are based on basePosX/Y
	self:setUpDebugChannels(); -- NOTE: debugChannels have to be set up after the hud, as they rely on some hud values [positioning]
	self:setupGlobalInfoText(); -- NOTE: globalInfoText has to be set up after the hud, as they rely on some hud values [colors, function]
	courseplay.courses:setup(true); -- NOTE: courses:setup is called a second time, now we actually load the courses and folders from the XML
	self:setup2dCourseData(true); -- NOTE: setup2dCourseData is called a second time, now we actually create the data and overlays

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- COURSEPLAYERS TABLES
	self.totalCoursePlayers = {};
	self.activeCoursePlayers = {};
	self.numActiveCoursePlayers = 0;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- height for mouse text line in game's help menu
	self.hudHelpMouseLineHeight = g_currentMission.hudHelpTextSize + g_currentMission.hudHelpTextLineSpacing*2;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- INPUT
	self.playerOnFootMouseEnabled = false;
	self.wasPlayerFrozen = false;
	local ovl = courseplay.inputBindings.mouse.overlaySecondary;
	if ovl then
		local h = (2.5 * g_currentMission.hudHelpTextSize);
		local w = h / g_screenAspectRatio;
		ovl:setDimension(w, h);
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- FIELDS
	if courseplay.fields.automaticScan then
		self:setupFieldScanInfo();
	end;
	if g_server ~= nil then
		courseplay.fields:loadAllCustomFields();
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- TIMERS
	g_currentMission.environment:addMinuteChangeListener(self);
	self.realTimeMinuteTimer = 0;
	self.realTime10SecsTimer = 0;
	self.realTime5SecsTimer = 0;
	self.realTime5SecsTimerThrough = 0;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- DEV CONSOLE COMMANDS
	if CpManager.isDeveloper then
		addConsoleCommand('cpAddMoney', ('Add %s to your bank account'):format(g_i18n:formatMoney(5000000)), 'devAddMoney', self);
		addConsoleCommand('cpAddFillLevels', 'Add 500\'000 l to all of your silos', 'devAddFillLevels', self);
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- TRIGGERS
	self.confirmedNoneTipTriggers = {};
	self.confirmedNoneTipTriggersCounter = 0;
	self.confirmedNoneSpecialTriggers = {};
	self.confirmedNoneSpecialTriggersCounter = 0;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- TRAFFIC
	self.trafficCollisionIgnoreList = {};

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- MISCELLANEOUS
	self.lightsNeeded = false;
end;

function CpManager:deleteMap()
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- empty courses and folders tables
	g_currentMission.cp_courses = nil;
	g_currentMission.cp_folders = nil;
	g_currentMission.cp_sorted = nil;
	courseplay.courses.batchWriteSize = nil;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- deactivate debug channels
	for channel,_ in pairs(courseplay.debugChannels) do
		courseplay.debugChannels[channel] = false;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete vehicles' button overlays
	for i,vehicle in pairs(g_currentMission.steerables) do
		if vehicle.cp ~= nil and vehicle.hasCourseplaySpec and vehicle.cp.buttons ~= nil then
			courseplay.buttons:deleteButtonOverlays(vehicle);
		end;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	--delete globalInfoText overlays
	for i,button in pairs(self.globalInfoText.buttons) do
		button:deleteOverlay();

		if self.globalInfoText.overlays[i] then
			local ovl = self.globalInfoText.overlays[i];
			if ovl.overlayId ~= nil and ovl.delete ~= nil then
				ovl:delete();
			end;
		end;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete waypoint signs
	for section,signDatas in pairs(courseplay.signs.buffer) do
		for k,signData in pairs(signDatas) do
			courseplay.signs:deleteSign(signData.sign);
		end;
		courseplay.signs.buffer[section] = {};
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete fields data and overlays
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

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete help menu mouse overlay
	if courseplay.inputBindings.mouse.overlaySecondary then
		courseplay.inputBindings.mouse.overlaySecondary:delete();
		courseplay.inputBindings.mouse.overlaySecondary = nil;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete fieldScanInfo overlays
	if self.fieldScanInfo then
		self.fieldScanInfo.bgOverlay:delete();
		self.fieldScanInfo.progressBarOverlay:delete();
		self.fieldScanInfo = nil;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete 2D course overlays
	if self.course2dPolyOverlayId and self.course2dPolyOverlayId ~= 0 then
		delete(self.course2dPolyOverlayId);
	end;
	if self.course2dTractorOverlay then
		self.course2dTractorOverlay:delete();
	end;
	if self.course2dPdaMapOverlay then
		self.course2dPdaMapOverlay:delete();
	end;
end;

function CpManager:update(dt)
	if g_currentMission.paused or (g_gui.currentGui ~= nil and g_gui.currentGuiName ~= 'inputCourseNameDialogue') then
		return;
	end;

	if self.firstRun then
		courseplay:addCpNilTempFillLevelFunction();
		self.firstRun = false;
	end;

	if g_gui.currentGui == nil then
		-- SETUP FIELD INGAME DATA
		if not courseplay.fields.ingameDataSetUp then
			courseplay.fields:setUpFieldsIngameData();
		end;

		-- SCAN ALL FIELD EDGES
		if courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned then
			courseplay.fields:setAllFieldEdges();
		end;

		-- Field scan, wages yes/no dialogue
		if self.showFieldScanYesNoDialogue then
			self:showYesNoDialogue('Courseplay', courseplay:loc('COURSEPLAY_YES_NO_FIELDSCAN'), self.fieldScanDialogueCallback, 'showFieldScanYesNoDialogue');
		elseif self.showWagesYesNoDialogue then
			local txt = courseplay:loc('COURSEPLAY_YES_NO_WAGES'):format(g_i18n:formatMoney(g_i18n:getCurrency(self.wagePerHour * self.wageDifficultyMultiplier), 2));
			self:showYesNoDialogue('Courseplay', txt, self.wagesDialogueCallback, 'showWagesYesNoDialogue');
		end;
	end;


	-- REAL TIME 10 SECS CHANGER
	if self.wagesActive and g_server ~= nil then -- NOTE: if there are more items to be dealt with every 10 secs, remove the "wagesActive" restriction
		if self.realTime10SecsTimer < 10000 then
			self.realTime10SecsTimer = self.realTime10SecsTimer + dt;
		else
			self:realTime10SecsChanged();
			self.realTime10SecsTimer = self.realTime10SecsTimer - 10000;
		end;
	end;

	-- REAL TIME 5 SECS CHANGER
	if self.realTime5SecsTimer < 5000 then
		self.realTime5SecsTimer = self.realTime5SecsTimer + dt;
		self.realTime5SecsTimerThrough = false;
	else
		self.realTime5SecsTimer = self.realTime5SecsTimer - 5000;
		self.realTime5SecsTimerThrough = true;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- HELP MENU
	if g_currentMission.showHelpText and g_gui.currentGui == nil and g_currentMission.controlledVehicle == nil and not g_currentMission.player.currentTool then
		if self.playerOnFootMouseEnabled then
			g_currentMission:addHelpTextFunction(self.drawMouseButtonHelp, self, self.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_HIDE'));
		elseif self.globalInfoText.hasContent then
			g_currentMission:addHelpTextFunction(self.drawMouseButtonHelp, self, self.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_SHOW'));
		end;
	end;
end;

function CpManager:draw()
	if g_currentMission.paused then
		return;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- DISPLAY GLOBALINFOTEXTS
	local git = self.globalInfoText;
	git.hasContent = false;
	local numLinesRendered = 0;
	local basePosY = git.posY;
	if not (g_currentMission.ingameMap.isVisible and g_currentMission.ingameMap:getIsFullSize()) and next(git.content) ~= nil then
		git.hasContent = true;
		if g_currentMission.ingameMap.isVisible then
			basePosY = git.posYAboveMap;
		end;
		numLinesRendered = self:renderGlobalInfoTexts(basePosY);
	end;
	git.buttonsClickArea.y1 = basePosY;
	git.buttonsClickArea.y2 = basePosY + (numLinesRendered  * (git.lineHeight + git.lineMargin));

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- DISPLAY FIELD SCAN MSG
	if courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned then
		self:renderFieldScanInfo();
	end;
end;

function CpManager:mouseEvent(posX, posY, isDown, isUp, mouseKey)
	if g_currentMission.paused then return; end;

	local area = self.globalInfoText.buttonsClickArea;
	if area == nil then
		return;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- LEFT CLICK
	if (isDown or isUp) and mouseKey == courseplay.inputBindings.mouse.primaryButtonId and courseplay:mouseIsInArea(posX, posY, area.x1, area.x2, area.y1, area.y2) then
		if self.globalInfoText.hasContent then
			for i,button in pairs(self.globalInfoText.buttons) do
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

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- RIGHT CLICK
	elseif isUp and mouseKey == courseplay.inputBindings.mouse.secondaryButtonId and g_currentMission.controlledVehicle == nil then
		if self.globalInfoText.hasContent and not self.playerOnFootMouseEnabled and not g_currentMission.player.currentTool then
			self.playerOnFootMouseEnabled = true;
			self.wasPlayerFrozen = g_currentMission.isPlayerFrozen;
			g_currentMission.isPlayerFrozen = true;
		elseif self.playerOnFootMouseEnabled then
			self.playerOnFootMouseEnabled = false;
			if self.globalInfoText.hasContent then --if a button was hovered when deactivating the cursor, deactivate hover state
				for _,button in pairs(self.globalInfoText.buttons) do
					button:setClicked(false);
					button:setHovered(false);
				end;
			end;
			if not self.wasPlayerFrozen then
				g_currentMission.isPlayerFrozen = false;
			end;
		end;
		InputBinding.setShowMouseCursor(self.playerOnFootMouseEnabled);

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- HOVER
	elseif not isDown and not isUp and self.globalInfoText.hasContent then
		for _,button in pairs(self.globalInfoText.buttons) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setHovered(button:getHasMouse(posX, posY));
			end;
		end;
	end;
end;

function CpManager:keyEvent() end;


-- ####################################################################################################


-- Giants - very intelligently - deletes any mod file in the savegame folder when saving. And now we get it back!
function CpManager.backupCpFiles(self)
	if g_server == nil and g_dedicatedServerInfo == nil then return end;
	-- print('backupCpFiles()');

	if not fileExists(CpManager.cpXmlFilePath) then
		-- ERROR: CP FILE DOESN'T EXIST
		return;
	end;

	-- backup CP files before saveSavegame() deletes them
	local savegameIndex = g_currentMission.missionInfo.savegameIndex;
	CpManager.cpTempSaveFolderPath = getUserProfileAppPath() .. 'courseplayBackupSavegame' .. savegameIndex;
	createFolder(CpManager.cpTempSaveFolderPath);
	-- print('    create folder at ' .. CpManager.cpTempSaveFolderPath);
	CpManager.cpFileBackupPath = CpManager.cpTempSaveFolderPath .. '/courseplay.xml';
	copyFile(CpManager.cpXmlFilePath, CpManager.cpFileBackupPath, true);
	-- print(('    copy cp file to backup folder: %q'):format(CpManager.cpFileBackupPath));

	if fileExists(CpManager.cpFieldsXmlFilePath) then
		CpManager.cpFieldsFileBackupPath = CpManager.cpTempSaveFolderPath .. '/courseplayFields.xml';
		copyFile(CpManager.cpFieldsXmlFilePath, CpManager.cpFieldsFileBackupPath, true);
		-- print(('    copy cp fields file to backup folder: %q'):format(CpManager.cpFieldsFileBackupPath));
	end;
end;
g_careerScreen.saveSavegame = Utils.prependedFunction(g_careerScreen.saveSavegame, CpManager.backupCpFiles);

function CpManager.getThatFuckerBack(self)
	if g_server == nil and g_dedicatedServerInfo == nil then return end;
	-- print('getThatFuckerBack()');

	if not CpManager.cpFileBackupPath then return end;

	local savegameIndex = g_currentMission.missionInfo.savegameIndex;
	local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory or CpManager.savegameFolderPath;
	if savegameFolderPath == nil then
		savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), savegameIndex);
	end;

	if fileExists(savegameFolderPath .. '/careerSavegame.xml') then -- savegame isn't corrupted and has been saved correctly
		-- print('    orig savegame folder still exists');

		-- copy backed up files back to our savegame directory
		-- print(('    copy backup cp file to orig savegame folder: %q'):format(CpManager.cpXmlFilePath));
		copyFile(CpManager.cpFileBackupPath, CpManager.cpXmlFilePath, true);
		CpManager.cpFileBackupPath = nil;
		if CpManager.cpFieldsFileBackupPath then
			-- print(('    copy backup cp fields file to orig savegame folder: %q'):format(CpManager.cpFieldsXmlFilePath));
			copyFile(CpManager.cpFieldsFileBackupPath, CpManager.cpFieldsXmlFilePath, true);
			CpManager.cpFieldsFileBackupPath = nil;
		end;

		deleteFolder(CpManager.cpTempSaveFolderPath);
		-- print('    delete backup folder');

	else -- corrupt savegame: display backup info message
		print(('This savegame has been corrupted. The Courseplay file has been backed up to %q'):format(CpManager.cpTempSaveFolderPath));

		local msgTitle = 'Courseplay';
		local msgTxt = ('This savegame has been corrupted.\nYour Courseplay %s been backed up to the "courseplayBackupSavegame%d" directory.\n\nFull path: %q'):format(CpManager.cpFieldsFileBackupPath and 'files have' or 'file has', savegameIndex, CpManager.cpTempSaveFolderPath);
		g_currentMission.inGameMessage:showMessage(msgTitle, msgTxt, 15000, false);
	end;
end;
g_careerScreen.saveSavegame = Utils.appendedFunction(g_careerScreen.saveSavegame, CpManager.getThatFuckerBack);

-- adds courseplayer to global table, so that the system knows all of them
function CpManager:addToTotalCoursePlayers(vehicle)
	local vehicleNum = (table.maxn(self.totalCoursePlayers) or 0) + 1;
	self.totalCoursePlayers[vehicleNum] = vehicle;
	CourseplayEvent.sendEvent(vehicle, "self.cp.coursePlayerNum", vehicleNum);
	return vehicleNum;
end;
function CpManager:addToActiveCoursePlayers(vehicle)
	self.numActiveCoursePlayers = self.numActiveCoursePlayers + 1;
	self.activeCoursePlayers[vehicle.rootNode] = vehicle;
end;
function CpManager:removeFromActiveCoursePlayers(vehicle)
	self.activeCoursePlayers[vehicle.rootNode] = nil;
	self.numActiveCoursePlayers = math.max(self.numActiveCoursePlayers - 1, 0);
end;

function CpManager:devAddMoney()
	if g_server ~= nil then
		g_currentMission:addSharedMoney(5000000, 'other');
		return ('Added %s to your bank account'):format(g_i18n:formatMoney(5000000));
	end;
end;
function CpManager:devAddFillLevels()
	if g_server ~= nil then
		for fillType=1,Fillable.NUM_FILLTYPES do
			g_currentMission:setSiloAmount(fillType, g_currentMission:getSiloAmount(fillType) + 500000);
		end;
		return 'All silo fill levels increased by 500\'000.';
	end;
end;

function CpManager:setupFieldScanInfo()
	-- FIELD SCAN INFO DISPLAY
	self.fieldScanInfo = {};

	local gfxPath = Utils.getFilename('img/fieldScanInfo.png', courseplay.path);

	self.fieldScanInfo.fileWidth  = 512;
	self.fieldScanInfo.fileHeight = 256;

	local bgUVs = { 41,210, 471,10 };
	local bgW = courseplay.hud:pxToNormal(bgUVs[3] - bgUVs[1], 'x');
	local bgH = courseplay.hud:pxToNormal(bgUVs[2] - bgUVs[4], 'y');
	local bgX = 0.5 - bgW * 0.5;
	local bgY = 0.5 - bgH * 0.5;
	self.fieldScanInfo.bgOverlay = Overlay:new('fieldScanInfoBackground', gfxPath, bgX, bgY, bgW, bgH);
	courseplay.utils:setOverlayUVsPx(self.fieldScanInfo.bgOverlay, bgUVs, self.fieldScanInfo.fileWidth, self.fieldScanInfo.fileHeight);

	self.fieldScanInfo.textPosX  = bgX + courseplay.hud:pxToNormal(10, 'x');
	self.fieldScanInfo.textPosY  = bgY + courseplay.hud:pxToNormal(55, 'y');
	self.fieldScanInfo.titlePosY = bgY + courseplay.hud:pxToNormal(88, 'y');
	self.fieldScanInfo.titleFontSize = courseplay.hud:pxToNormal(22, 'y');
	self.fieldScanInfo.textFontSize  = courseplay.hud:pxToNormal(16, 'y');


	self.fieldScanInfo.progressBarMaxWidthPx = 406;
	self.fieldScanInfo.progressBarMaxWidth = courseplay.hud:pxToNormal(406, 'x');
	local pbH = courseplay.hud:pxToNormal(26, 'y');
	self.fieldScanInfo.progressBarUVs = { 53,246, 459,220 };
	local pbX = bgX + courseplay.hud:pxToNormal(12, 'x');
	local pbY = bgY + courseplay.hud:pxToNormal(12, 'y');
	self.fieldScanInfo.progressBarOverlay = Overlay:new('fieldScanInfoProgressBar', gfxPath, pbX, pbY, self.fieldScanInfo.progressBarMaxWidth, pbH);
	courseplay.utils:setOverlayUVsPx(self.fieldScanInfo.progressBarOverlay, self.fieldScanInfo.progressBarUVs, self.fieldScanInfo.fileWidth, self.fieldScanInfo.fileHeight);

	self.fieldScanInfo.percentColors = {
		  [0] = courseplay.utils:rgbToNormal(225,  27, 0),
		 [50] = courseplay.utils:rgbToNormal(255, 204, 0),
		[100] = courseplay.utils:rgbToNormal(137, 243, 0)
	};
	self.fieldScanInfo.colorMapStep = 50;
end;

function CpManager:renderFieldScanInfo()
	local fsi = self.fieldScanInfo;

	fsi.bgOverlay:render();

	local pct = courseplay.fields.curFieldScanIndex / g_currentMission.fieldDefinitionBase.numberOfFields;

	local r, g, b = courseplay.utils:getColorFromPct(pct * 100, fsi.percentColors, fsi.colorMapStep);
	fsi.progressBarOverlay:setColor(r, g, b, 1);

	fsi.progressBarOverlay.width = fsi.progressBarMaxWidth * pct;
	local widthPx = courseplay:round(fsi.progressBarMaxWidthPx * pct);
	local newUVs = { fsi.progressBarUVs[1], fsi.progressBarUVs[2], fsi.progressBarUVs[1] + widthPx, fsi.progressBarUVs[4] };
	courseplay.utils:setOverlayUVsPx(fsi.progressBarOverlay, newUVs, fsi.fileWidth, fsi.fileHeight);
	fsi.progressBarOverlay:render();

	courseplay:setFontSettings({ 0.8, 0.8, 0.8, 1 }, true, 'left');
	renderText(fsi.textPosX, fsi.titlePosY - 0.001, fsi.titleFontSize, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));
	courseplay:setFontSettings('shadow', true);
	renderText(fsi.textPosX, fsi.titlePosY,         fsi.titleFontSize, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));

	local text = courseplay:loc('COURSEPLAY_SCANNING_FIELD_NMB'):format(courseplay.fields.curFieldScanIndex, g_currentMission.fieldDefinitionBase.numberOfFields);
	courseplay:setFontSettings({ 0.8, 0.8, 0.8, 1 }, false);
	renderText(fsi.textPosX, fsi.textPosY - 0.001, fsi.textFontSize, text);
	courseplay:setFontSettings('shadow', false);
	renderText(fsi.textPosX, fsi.textPosY,         fsi.textFontSize, text);

	-- reset font settings
	courseplay:setFontSettings('white', false, 'left');
end;

function CpManager.drawMouseButtonHelp(self, posY, txt)
	local xLeft = g_currentMission.hudHelpTextPosX1;
	local xRight = g_currentMission.hudHelpTextPosX2;

	local ovl = courseplay.inputBindings.mouse.overlaySecondary;
	if ovl then
		local y = posY - g_currentMission.hudHelpTextSize - g_currentMission.hudHelpTextLineSpacing*3;
		ovl:setPosition(xLeft - ovl.width*0.2, y);
		ovl:render();
		xLeft = xLeft + ovl.width*0.6;
	end;

	posY = posY - g_currentMission.hudHelpTextSize - g_currentMission.hudHelpTextLineSpacing*2;
	setTextAlignment(RenderText.ALIGN_RIGHT);
	renderText(xRight, posY, g_currentMission.hudHelpTextSize, txt);

	setTextAlignment(RenderText.ALIGN_LEFT);
	renderText(xLeft, posY, g_currentMission.hudHelpTextSize, courseplay.inputBindings.mouse.secondaryTextI18n);
end;

function CpManager:severCombineTractorConnection(vehicle, callDelete)
	if vehicle.cp then
		-- VEHICLE IS COMBINE
		if vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or courseplay:isSpecialChopper(vehicle) then
			courseplay:debug(('BaseMission:removeVehicle() -> severCombineTractorConnection(%q, %s) [VEHICLE IS COMBINE]'):format(nameNum(vehicle), tostring(callDelete)), 4);
			local combine = vehicle;
			-- remove this combine as savedCombine from all tractors
			for i,tractor in pairs(g_currentMission.steerables) do
				if tractor.hasCourseplaySpec and tractor.cp.savedCombine and tractor.cp.savedCombine == combine then
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
BaseMission.removeVehicle = Utils.prependedFunction(BaseMission.removeVehicle, CpManager.severCombineTractorConnection);

local nightStart, dayStart = 19 * 3600000, 7.5 * 3600000; -- from 7pm until 7:30am
function CpManager:minuteChanged()
	-- WEATHER
	local env = g_currentMission.environment;
	self.lightsNeeded = env.needsLights or (env.dayTime >= nightStart or env.dayTime <= dayStart) or env.currentRain ~= nil or env.curRain ~= nil or (env.lastRainScale > 0.1 and env.timeSinceLastRain < 30);
end;

function CpManager:realTime10SecsChanged()
	-- WAGES
	if self.wagesActive and g_server ~= nil then
		local totalWages = 0;
		for vehicleNum, vehicle in pairs(self.activeCoursePlayers) do
			if vehicle:getIsCourseplayDriving() and not vehicle.isHired then
				totalWages = totalWages + self.wagePer10Secs;
			end;
		end;
		if totalWages > 0 then
			g_currentMission:addSharedMoney(-totalWages * self.wageDifficultyMultiplier, 'wagePayment');
		end;
	end;
end;

function CpManager:showYesNoDialogue(title, text, callbackFn, showBoolVar)
	local yesNoDialogue = g_gui:showGui('YesNoDialog');
	yesNoDialogue.target.titleElement:setText(title);
	yesNoDialogue.target:setText(text);
	yesNoDialogue.target:setCallbacks(callbackFn, self);
	self[showBoolVar] = false;
end;


-- ####################################################################################################
-- FIELD SCAN Y/N DIALOGUE
function CpManager:fieldScanDialogueCallback(setActive)
	courseplay.fields.automaticScan = setActive;
	local file = loadXMLFile('courseplayFile', self.cpXmlFilePath);
	if file and file ~= 0 then
		setXMLBool(file, 'XML.courseplayFields#automaticScan', setActive);
		saveXMLFile(file);
		delete(file);
	end;
	g_gui:showGui('');
end;


-- ####################################################################################################
-- WAGES
function CpManager:setupWages()
	self.wageDifficultyMultiplier = Utils.lerp(0.5, 1, (g_currentMission.missionStats.difficulty - 1) / 2);
	self.wagesActive = true;
	self.wagePerHour = 1500;
	self.wagePer10Secs  = self.wagePerHour / 360;
	self.showWagesYesNoDialogue = false;
end;

function CpManager:wagesDialogueCallback(setActive)
	self.wagesActive = setActive;
	local file = loadXMLFile('courseplayFile', self.cpXmlFilePath);
	if file and file ~= 0 then
		setXMLBool(file, 'XML.courseplayWages#active', setActive);
		saveXMLFile(file);
		delete(file);
	end;
	g_gui:showGui('');
end;


-- ####################################################################################################
-- INGAME MAP
function CpManager:setupIngameMap()
	self.ingameMapIconActive		 = true;
	self.ingameMapIconShowName		 = true;
	self.ingameMapIconShowCourse	 = true;
	self.ingameMapIconShowText		 = self.ingameMapIconShowName or self.ingameMapIconShowCourse;
	self.ingameMapIconShowTextLoaded = self.ingameMapIconShowText;
end;


-- ####################################################################################################
-- GLOBALINFOTEXT
function CpManager:setupGlobalInfoText()
	print('## Courseplay: setting up globalInfoText');

	self.globalInfoText = {};

	self.globalInfoText.posY = 0.01238; -- = ingameMap posY
	self.globalInfoText.posYAboveMap = self.globalInfoText.posY + 0.027777777777778 + 0.20833333333333;
	self.globalInfoText.fontSize = courseplay.hud:pxToNormal(18, 'y');
	self.globalInfoText.lineHeight = self.globalInfoText.fontSize * 1.2;
	self.globalInfoText.lineMargin = self.globalInfoText.lineHeight * 0.2;
	self.globalInfoText.buttonHeight = self.globalInfoText.lineHeight;
	self.globalInfoText.buttonWidth = self.globalInfoText.buttonHeight / g_screenAspectRatio;
	self.globalInfoText.buttonPosX = 0.015625; -- = ingameMap posX
	self.globalInfoText.buttonMargin = self.globalInfoText.buttonWidth * 0.4;
	self.globalInfoText.backgroundPadding = self.globalInfoText.buttonWidth * 0.2;
	self.globalInfoText.backgroundImg = 'dataS2/menu/white.png';
	self.globalInfoText.backgroundPosX = self.globalInfoText.buttonPosX + self.globalInfoText.buttonWidth + self.globalInfoText.buttonMargin;
	self.globalInfoText.backgroundPosY = self.globalInfoText.posY;
	self.globalInfoText.textPosX = self.globalInfoText.backgroundPosX + self.globalInfoText.backgroundPadding;
	self.globalInfoText.content = {};
	self.globalInfoText.vehicleHasText = {};
	self.globalInfoText.levelColors = {
		[-2] = courseplay.hud.colors.closeRed;
		[-1] = courseplay.hud.colors.activeRed;
		[0]  = courseplay.hud.colors.hover;
		[1]  = courseplay.hud.colors.activeGreen;
	};

	self.globalInfoText.maxNum = 20;
	self.globalInfoText.overlays = {};
	self.globalInfoText.buttons = {};
	for i=1, self.globalInfoText.maxNum do
		local posY = self.globalInfoText.backgroundPosY + (i - 1) * self.globalInfoText.lineHeight;
		self.globalInfoText.overlays[i] = Overlay:new('globalInfoTextOverlay' .. i, self.globalInfoText.backgroundImg, self.globalInfoText.backgroundPosX, posY, 0.1, self.globalInfoText.buttonHeight);
		courseplay.button:new(self, 'globalInfoText', 'iconSprite.png', 'goToVehicle', i, self.globalInfoText.buttonPosX, posY, self.globalInfoText.buttonWidth, self.globalInfoText.buttonHeight);
	end;
	self.globalInfoText.buttonsClickArea = {
		x1 = self.globalInfoText.buttonPosX;
		x2 = self.globalInfoText.buttonPosX + self.globalInfoText.buttonWidth;
		y1 = self.globalInfoText.backgroundPosY,
		y2 = self.globalInfoText.backgroundPosY + (self.globalInfoText.maxNum * (self.globalInfoText.lineHeight + self.globalInfoText.lineMargin));
	};
	self.globalInfoText.hasContent = false;


	self.globalInfoText.msgReference = {
		BALER_NETS					= { level = -2, text = 'COURSEPLAY_BALER_NEEDS_NETS' };
		BGA_IS_FULL					= { level = -1, text = 'COURSEPLAY_BGA_IS_FULL'};
		DAMAGE_IS					= { level =  0, text = 'COURSEPLAY_DAMAGE_IS_BEING_REPAIRED' };
		DAMAGE_MUST					= { level = -2, text = 'COURSEPLAY_DAMAGE_MUST_BE_REPAIRED' };
		DAMAGE_SHOULD				= { level = -1, text = 'COURSEPLAY_DAMAGE_SHOULD_BE_REPAIRED' };
		END_POINT					= { level =  0, text = 'COURSEPLAY_REACHED_END_POINT' };
		FARM_SILO_NO_FILLTYPE		= { level = -2, text = 'COURSEPLAY_FARM_SILO_NO_FILLTYPE'};
		FARM_SILO_IS_EMPTY			= { level =  0, text = 'COURSEPLAY_FARM_SILO_IS_EMPTY'};
		FUEL_IS						= { level =  0, text = 'COURSEPLAY_IS_BEING_REFUELED' };
		FUEL_MUST					= { level = -2, text = 'COURSEPLAY_MUST_BE_REFUELED' };
		FUEL_SHOULD					= { level = -1, text = 'COURSEPLAY_SHOULD_BE_REFUELED' };
		HOSE_MISSING				= { level = -2, text = 'COURSEPLAY_HOSEMISSING' };
		NEEDS_REFILLING				= { level = -1, text = 'COURSEPLAY_NEEDS_REFILLING' };
		NEEDS_UNLOADING				= { level = -1, text = 'COURSEPLAY_NEEDS_UNLOADING' };
		OVERLOADING_POINT			= { level =  0, text = 'COURSEPLAY_REACHED_OVERLOADING_POINT' };
		PICKUP_JAMMED				= { level = -2, text = 'COURSEPLAY_PICKUP_JAMMED' };
		SLIPPING_1					= { level = -1, text = 'COURSEPLAY_SLIPPING_WARNING' };
		SLIPPING_2					= { level = -2, text = 'COURSEPLAY_SLIPPING_WARNING' };
		TRAFFIC						= { level = -1, text = 'COURSEPLAY_IS_IN_TRAFFIC' };
		UNLOADING_BALE				= { level =  0, text = 'COURSEPLAY_UNLOADING_BALES' };
		WAIT_POINT					= { level =  0, text = 'COURSEPLAY_REACHED_WAITING_POINT' };
		WATER						= { level = -2, text = 'COURSEPLAY_WATER_WARNING' };
		WEATHER						= { level =  0, text = 'COURSEPLAY_WEATHER_WARNING' };
		WORK_END					= { level =  1, text = 'COURSEPLAY_WORK_END' };
	};
end;

function CpManager:setGlobalInfoText(vehicle, refIdx, forceRemove)
	local git = self.globalInfoText;

	--print(string.format('setGlobalInfoText(vehicle, %s, %s)', tostring(refIdx), tostring(forceRemove))); 
	if forceRemove == true then
		if g_server ~= nil then
			CourseplayEvent.sendEvent(vehicle, "setMPGlobalInfoText", refIdx, false, forceRemove)
		end
		if git.content[vehicle.rootNode][refIdx] then
			git.content[vehicle.rootNode][refIdx] = nil;
		end;
		vehicle.cp.activeGlobalInfoTexts[refIdx] = nil;
		vehicle.cp.numActiveGlobalInfoTexts = vehicle.cp.numActiveGlobalInfoTexts - 1;
		--print(string.format('\t%s: remove globalInfoText[%s] from global table, numActiveGlobalInfoTexts=%d', nameNum(vehicle), refIdx, vehicle.cp.numActiveGlobalInfoTexts));
		if vehicle.cp.numActiveGlobalInfoTexts == 0 then
			git.content[vehicle.rootNode] = nil;
			--print(string.format('\t\tset globalInfoText.content[rootNode] to nil'));
		end;
		return;
	end;

	vehicle.cp.hasSetGlobalInfoTextThisLoop[refIdx] = true;
	local data = git.msgReference[refIdx];
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

		if git.content[vehicle.rootNode] == nil then
			git.content[vehicle.rootNode] = {};
		end;
		git.content[vehicle.rootNode][refIdx] = {
			level = data.level,
			text = text,
			backgroundWidth = getTextWidth(git.fontSize, text) + git.backgroundPadding * 2.5,
			vehicle = vehicle
		};
	end;
end;

function CpManager:renderGlobalInfoTexts(basePosY)
	local git = self.globalInfoText;
	local line = 0;
	courseplay:setFontSettings('white', false, 'left');
	for _,refIndexes in pairs(git.content) do
		if line >= self.globalInfoText.maxNum then
			break;
		end;

		for refIdx,data in pairs(refIndexes) do
			line = line + 1;

			-- background
			local bg = git.overlays[line];
			bg:setColor(unpack(git.levelColors[data.level]));
			local gfxPosY = basePosY + (line - 1) * (git.lineHeight + git.lineMargin);
			bg:setPosition(bg.x, gfxPosY);
			bg:setDimension(data.backgroundWidth, bg.height);
			bg:render();

			-- text
			local textPosY = gfxPosY + (git.lineHeight - git.fontSize) * 1.2; -- should be (lineHeight-fontSize)*0.5, but there seems to be some pixel/sub-pixel rendering error
			renderText(git.textPosX, textPosY, git.fontSize, data.text);

			-- button
			local button = self.globalInfoText.buttons[line];
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

	return line;
end;

-- ####################################################################################################
-- 2D COURSE DRAW SETUP
function CpManager:setup2dCourseData(createOverlays)
	if not createOverlays then
		self.course2dPlotPosX = 0.65;
		self.course2dPlotPosY = 0.35;
		self.course2dPdaMapOpacity = 0.7;

		self.course2dColorTable = {
			  [0] = courseplay.utils:rgbToNormal( 24, 225, 0),
			 [50] = courseplay.utils:rgbToNormal(255, 230, 0),
			[100] = courseplay.utils:rgbToNormal(210,   5, 0)
		};
		self.course2dColorPctStep = 50;

		self.course2dPlotField = { x = self.course2dPlotPosX, y = self.course2dPlotPosY, width = 0.3, height = 0.3 * g_screenAspectRatio }; -- definition of plot field for 2D

		return;
	end;

	self.course2dPolyOverlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds');

	local w, h = courseplay.hud:getPxToNormalConstant(14, 10);
	self.course2dTractorOverlay = Overlay:new('cpTractorIndicator', courseplay.hud.iconSpritePath, 0.5, 0.5, w, h);
	courseplay.utils:setOverlayUVsPx(self.course2dTractorOverlay, courseplay.hud.buttonUVsPx.recordingPlay, courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
	self.course2dTractorOverlay:setColor(0,0.8,1,1);

end;

-- ####################################################################################################
-- LOAD SETTINGS FROM courseplay.xml / SET DEFAULT SETTINGS IF NOT EXISTING
function CpManager:loadOrSetXmlSettings()
	if self.savegameFolderPath and self.cpXmlFilePath then
		createFolder(self.savegameFolderPath);
		local cpFile;
		if fileExists(self.cpXmlFilePath) then
			cpFile = loadXMLFile('cpFile', self.cpXmlFilePath);
		else
			self:createXmlSettings();
			return;
		end;

		print('## Courseplay: loading settings from "courseplay.xml"');

		-- hud position
		local key = 'XML.courseplayHud';
		local posX, posY = getXMLFloat(cpFile, key .. '#posX'), getXMLFloat(cpFile, key .. '#posY');
		if posX then
			courseplay.hud.basePosX = courseplay.hud:getFullPx(posX, 'x');
		else
			setXMLFloat(cpFile, key .. '#posX', courseplay.hud.basePosX);
		end;
		if posY then
			courseplay.hud.basePosY = courseplay.hud:getFullPx(posY, 'y');
		else
			setXMLFloat(cpFile, key .. '#posY', courseplay.hud.basePosY);
		end;


		-- fields settings
		key = 'XML.courseplayFields';
		local fieldsAutomaticScan		= getXMLBool(cpFile, key .. '#automaticScan');
		local fieldsOnlyScanOwnedFields	= getXMLBool(cpFile, key .. '#onlyScanOwnedFields');
		local fieldsDebugScan			= getXMLBool(cpFile, key .. '#debugScannedFields');
		local fieldsDebugCustomLoad		= getXMLBool(cpFile, key .. '#debugCustomLoadedFields');
		local fieldsCustomScanStep		=  getXMLInt(cpFile, key .. '#scanStep');
		if fieldsAutomaticScan ~= nil then
			courseplay.fields.automaticScan = fieldsAutomaticScan;
		else
			setXMLBool(cpFile, key .. '#automaticScan', courseplay.fields.automaticScan);
			self.showFieldScanYesNoDialogue = true;
		end;
		if fieldsOnlyScanOwnedFields ~= nil then
			courseplay.fields.onlyScanOwnedFields = fieldsOnlyScanOwnedFields;
		else
			setXMLBool(cpFile, key .. '#onlyScanOwnedFields', courseplay.fields.onlyScanOwnedFields);
		end;
		if fieldsDebugScan ~= nil then
			courseplay.fields.debugScannedFields = fieldsDebugScan;
		else
			setXMLBool(cpFile, key .. '#debugScannedFields', courseplay.fields.debugScannedFields);
		end;
		if fieldsDebugCustomLoad ~= nil then
			courseplay.fields.debugCustomLoadedFields = fieldsDebugCustomLoad;
		else
			setXMLBool(cpFile, key .. '#debugCustomLoadedFields', courseplay.fields.debugCustomLoadedFields);
		end;
		if fieldsCustomScanStep ~= nil then
			courseplay.fields.scanStep = fieldsCustomScanStep;
		else
			setXMLInt(cpFile, key .. '#scanStep', courseplay.fields.scanStep);
		end;


		-- wages
		key = 'XML.courseplayWages';
		local wagesActive, wagePerHour = getXMLBool(cpFile, key .. '#active'), getXMLInt(cpFile, key .. '#wagePerHour');
		if wagesActive ~= nil then
			self.wagesActive = wagesActive;
		else
			setXMLBool(cpFile, key .. '#active', self.wagesActive);
			self.showWagesYesNoDialogue = true;
		end;
		if wagePerHour ~= nil then
			self.wagePerHour = wagePerHour;
		else
			setXMLInt(cpFile, key .. '#wagePerHour', self.wagePerHour);
			self.showWagesYesNoDialogue = true;
		end;
		self.wagePer10Secs = self.wagePerHour / 360;


		-- ingame map
		key = 'XML.courseplayIngameMap';
		local active, showName, showCourse = getXMLBool(cpFile, key .. '#active'), getXMLBool(cpFile, key .. '#showName'), getXMLBool(cpFile, key .. '#showCourse');
		if active ~= nil then
			self.ingameMapIconActive = active;
		else
			setXMLBool(cpFile, key .. '#active', self.ingameMapIconActive);
		end;
		if showName ~= nil then
			self.ingameMapIconShowName = showName;
		else
			setXMLBool(cpFile, key .. '#showName', self.ingameMapIconShowName);
		end;
		if showCourse ~= nil then
			self.ingameMapIconShowCourse = showCourse;
		else
			setXMLBool(cpFile, key .. '#showCourse', self.ingameMapIconShowCourse);
		end;
		self.ingameMapIconShowText = self.ingameMapIconShowName or self.ingameMapIconShowCourse;


		-- batch write size (used in deleteSaveAll())
		key = 'XML.courseManagement';
		local batchWriteSize = getXMLInt(cpFile, key .. '#batchWriteSize');
		if batchWriteSize ~= nil then
			courseplay.courses.batchWriteSize = batchWriteSize;
		else
			setXMLInt(cpFile, key .. '#batchWriteSize', courseplay.courses.batchWriteSize);
		end;


		-- 2D course
		key = 'XML.course2D';
		local posX, posY, opacity = getXMLFloat(cpFile, key .. '#posX'), getXMLFloat(cpFile, key .. '#posY'), getXMLFloat(cpFile, key .. '#opacity');
		if posX ~= nil then
			self.course2dPlotPosX = posX;
			self.course2dPlotField.x = self.course2dPlotPosX;
		else
			setXMLFloat(cpFile, key .. '#posX', self.course2dPlotPosX);
		end;
		if posY ~= nil then
			self.course2dPlotPosY = posY;
			self.course2dPlotField.y = self.course2dPlotPosY;
		else
			setXMLFloat(cpFile, key .. '#posY', self.course2dPlotPosY);
		end;
		if opacity ~= nil then
			self.course2dPdaMapOpacity = opacity;
		else
			setXMLFloat(cpFile, key .. '#opacity', self.course2dPdaMapOpacity);
		end;

		--------------------------------------------------
		saveXMLFile(cpFile);
		delete(cpFile);
	end;
end;

-- CREATE courseplay.xml AND SET DEFAULT SETTINGS
function CpManager:createXmlSettings()
	print('## Courseplay: creating "courseplay.xml" with default settings');

	local cpFile = createXMLFile('cpFile', self.cpXmlFilePath, 'XML');

	-- hud position
	local key = 'XML.courseplayHud';
	setXMLFloat(cpFile, key .. '#posX', courseplay.hud.basePosX);
	setXMLFloat(cpFile, key .. '#posY', courseplay.hud.basePosY);

	-- fields settings
	self.showFieldScanYesNoDialogue = true;
	key = 'XML.courseplayFields';
	setXMLBool(cpFile, key .. '#automaticScan',			  courseplay.fields.automaticScan);
	setXMLBool(cpFile, key .. '#onlyScanOwnedFields',	  courseplay.fields.onlyScanOwnedFields);
	setXMLBool(cpFile, key .. '#debugScannedFields',	  courseplay.fields.debugScannedFields);
	setXMLBool(cpFile, key .. '#debugCustomLoadedFields', courseplay.fields.debugCustomLoadedFields);
	 setXMLInt(cpFile, key .. '#scanStep',				  courseplay.fields.scanStep);

	-- wages
	self.showWagesYesNoDialogue = true;
	key = 'XML.courseplayWages';
	setXMLBool(cpFile, key .. '#active',	  self.wagesActive);
	 setXMLInt(cpFile, key .. '#wagePerHour', self.wagePerHour);

	-- ingame map
	key = 'XML.courseplayIngameMap';
	setXMLBool(cpFile, key .. '#active',	 self.ingameMapIconActive);
	setXMLBool(cpFile, key .. '#showName',	 self.ingameMapIconShowName);
	setXMLBool(cpFile, key .. '#showCourse', self.ingameMapIconShowCourse);

	-- batch write size (used in deleteSaveAll())
	key = 'XML.courseManagement';
	setXMLInt(cpFile, key .. '#batchWriteSize', courseplay.courses.batchWriteSize);

	-- 2D course
	key = 'XML.course2D';
	setXMLFloat(cpFile, key .. '#posX', self.course2dPlotPosX);
	setXMLFloat(cpFile, key .. '#posY', self.course2dPlotPosY);
	setXMLFloat(cpFile, key .. '#opacity', self.course2dPdaMapOpacity);

	--------------------------------------------------
	saveXMLFile(cpFile);
	delete(cpFile);
end;
