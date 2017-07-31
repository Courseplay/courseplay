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
		-- Settings and custom fields path and files
		self.savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.selectedIndex); -- This should work for both SP, MP and Dedicated Servers
		self.cpSettingsXmlFilePath = self.savegameFolderPath .. '/courseplaySettings.xml';
		self.cpCustomFieldsXmlFilePath = self.savegameFolderPath .. '/courseplayCustomFields.xml';
		self.cpOldCustomFieldsXmlFilePath = self.savegameFolderPath .. '/courseplayFields.xml';

		self.cpXmlFilePath = self.savegameFolderPath .. '/courseplay.xml';
		self.oldCPFileExists = fileExists(self.cpXmlFilePath);

		-- Course save path
		self.cpCoursesFolderPath = ("%s%s/%s"):format(getUserProfileAppPath(),"CoursePlay_Courses", g_careerScreen.savegames[g_careerScreen.selectedIndex].mapId);
		self.cpCourseManagerXmlFilePath = self.cpCoursesFolderPath .. "/courseManager.xml";
		self.cpCourseStorageXmlFileTemplate = "courseStorage%04d.xml";

		-- we need to create CoursePlay_Courses folder before we can create any new folders inside it.
		createFolder(("%sCoursePlay_Courses"):format(getUserProfileAppPath()));
		createFolder(self.cpCoursesFolderPath);

		-- Add / at end of path, so we dont save that in the courseManager.xml (Needs to be done after folder creation!)
		self.cpCoursesFolderPath = self.cpCoursesFolderPath .. "/";
	end
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- SETUP DEFAULT GLOBAL DATA
	courseplay.signs:setup();
	courseplay.fields:setup();
	self.showFieldScanYesNoDialogue = false;
	self:setupWages();
	self:setupIngameMap();
	self:setup2dCourseData(false); -- NOTE: this call is only to initiate the position and opacity

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- LOAD SETTINGS FROM COURSEPLAYSETTINGS.XML / SAVE DEFAULT SETTINGS IF NOT EXISTING
	if g_server ~= nil then
		self:loadXmlSettings();
	end
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- SETUP (continued)
	courseplay.hud:setup(); -- NOTE: hud has to be set up after the xml settings have been loaded, as almost all its values are based on basePosX/Y
	self:setUpDebugChannels(); -- NOTE: debugChannels have to be set up after the hud, as they rely on some hud values [positioning]
	self:setupGlobalInfoText(); -- NOTE: globalInfoText has to be set up after the hud, as they rely on some hud values [colors, function]
	courseplay.courses:setup(); -- NOTE: load the courses and folders from the XML
	self:setup2dCourseData(true); -- NOTE: setup2dCourseData is called a second time, now we actually create the data and overlays
	courseplay:register(true)-- NOTE: running here again to check whether there were mods loaded after courseplay
	
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- COURSEPLAYERS TABLES
	self.totalCoursePlayers = {};
	self.activeCoursePlayers = {};
	self.numActiveCoursePlayers = 0;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- height for mouse text line in game's help menu
	self.hudHelpMouseLineHeight = g_currentMission.helpBoxTextSize + g_currentMission.helpBoxTextLineSpacing*2;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- INPUT
	self.playerOnFootMouseEnabled = false;
	self.wasPlayerFrozen = false;
	local ovl = courseplay.inputBindings.mouse.overlaySecondary;
	if ovl then
		local h = (2.5 * g_currentMission.helpBoxTextSize);
		local w = h / g_screenAspectRatio;
		ovl:setDimension(w, h);
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- FIELDS
	if courseplay.fields.automaticScan then
		self:setupFieldScanInfo();
	end;
	if g_server ~= nil then
		courseplay.fields:loadCustomFields(fileExists(self.cpOldCustomFieldsXmlFilePath) and not fileExists(self.cpCustomFieldsXmlFilePath));
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- TIMERS
	g_currentMission.environment:addMinuteChangeListener(self);
	self.realTimeMinuteTimer = 0;
	self.realTime10SecsTimer = 0;
	self.realTime5SecsTimer = 0;
	self.realTime5SecsTimerThrough = 0;
	self.startFieldScanAfter = 1500; -- Start field scanning after specified milliseconds

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- DEV CONSOLE COMMANDS
	if CpManager.isDeveloper then
		addConsoleCommand('cpAddMoney', ('Add %s to your bank account'):format(g_i18n:formatMoney(5000000)), 'devAddMoney', self);
		addConsoleCommand('cpAddFillLevels', 'Add 500\'000 l to all of your silos', 'devAddFillLevels', self);
	end;
	addConsoleCommand('cpStopAll', 'Stop all Courseplayers', 'devStopAll', self);
  addConsoleCommand( 'cpSaveAllFields', 'Save all fields', 'devSaveAllFields', self )
	
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
  -- UPDATE CLOCK
  courseplay.clock = courseplay.clock + dt

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
		if self.startFieldScanAfter > 0 then
			self.startFieldScanAfter = self.startFieldScanAfter - dt;
		end;
		if g_currentMission.fieldDefinitionBase and courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned and self.startFieldScanAfter <= 0 then
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
	if g_currentMission.fieldDefinitionBase and courseplay.fields.automaticScan and not courseplay.fields.allFieldsScanned and self.startFieldScanAfter <= 0 then
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
function CpManager.saveXmlSettings(self)
	if g_server == nil and g_dedicatedServerInfo == nil then return end;
	-- Create folder in case there is none
	createFolder(CpManager.savegameFolderPath);

	-- createXMLFile will clear settings file if it exists
	local cpSettingsXml = createXMLFile("cpSettingsXml", CpManager.cpSettingsXmlFilePath, "CPSettings");

	if cpSettingsXml and cpSettingsXml ~= 0 then
		local key = '';
		-- Save Hud Possition
		key = 'CPSettings.courseplayHud';
		setXMLFloat(cpSettingsXml, key .. '#posX',		courseplay.hud.basePosX);
		setXMLFloat(cpSettingsXml, key .. '#posY',		courseplay.hud.basePosY);
		setXMLFloat(cpSettingsXml, key .. '#hudScale',	courseplay.hud.sizeRatio);
		setXMLFloat(cpSettingsXml, key .. '#uiScale',	courseplay.hud.uiScale);
		local string = "\n\tNOTE 1: Do not change the uiScale Manually.\n\tNOTE 2: If you change the hudScale and you haven't changed the posX and posY manually,\n\t\t\tthen you need to delete the posX and posY section to center the hud again.\n\t";
		setXMLString(cpSettingsXml, key, string);

		-- Save Fields Settings
		key = 'CPSettings.courseplayFields';
		setXMLBool(cpSettingsXml, key .. '#automaticScan',				courseplay.fields.automaticScan);
		setXMLBool(cpSettingsXml, key .. '#onlyScanOwnedFields',		courseplay.fields.onlyScanOwnedFields);
		setXMLBool(cpSettingsXml, key .. '#debugScannedFields',			courseplay.fields.debugScannedFields);
		setXMLBool(cpSettingsXml, key .. '#debugCustomLoadedFields',	courseplay.fields.debugCustomLoadedFields);
		setXMLInt (cpSettingsXml, key .. '#scanStep',					courseplay.fields.scanStep);

		-- Save Wages Settings
		key = 'CPSettings.courseplayWages';
		setXMLBool(cpSettingsXml, key .. '#active', 		CpManager.wagesActive);
		setXMLInt (cpSettingsXml, key .. '#wagePerHour',	CpManager.wagePerHour);

		-- Save Ingame Map Settings
		key = 'CPSettings.courseplayIngameMap';
		setXMLBool(cpSettingsXml, key .. '#active', 		CpManager.ingameMapIconActive);
		setXMLBool(cpSettingsXml, key .. '#showName', 		CpManager.ingameMapIconShowName);
		setXMLBool(cpSettingsXml, key .. '#showCourse',		CpManager.ingameMapIconShowCourse);

		-- Save 2D Course Settings
		key = 'CPSettings.course2D';
		setXMLFloat(cpSettingsXml, key .. '#posX', 		CpManager.course2dPlotPosX);
		setXMLFloat(cpSettingsXml, key .. '#posY', 		CpManager.course2dPlotPosY);
		setXMLFloat(cpSettingsXml, key .. '#opacity',	CpManager.course2dPdaMapOpacity);

		saveXMLFile(cpSettingsXml);
		delete(cpSettingsXml);
	else
		print(("COURSEPLAY ERROR: unable to load or create file -> %s"):format(CpManager.cpSettingsXmlFilePath));
	end;
end;
g_careerScreen.saveSavegame = Utils.appendedFunction(g_careerScreen.saveSavegame, CpManager.saveXmlSettings);

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
		for fillType=1,FillUtil.NUM_FILLTYPES do
			g_currentMission:setSiloAmount(fillType, g_currentMission:getSiloAmount(fillType) + 500000);
		end;
		return 'All silo fill levels increased by 500\'000.';
	end;
end;
function CpManager:devStopAll()
	if g_server ~= nil then
		for _,vehicle in pairs (self.activeCoursePlayers) do
			courseplay:stop(vehicle);
		end
		
		return ('stopped all Courseplayers');
	end;
end;

function CpManager:devSaveAllFields()
  courseplay.fields.saveAllFields()
  return( 'All fields saved' )
end

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

	courseplay:setFontSettings('white', false, 'left');
	renderText(fsi.textPosX, fsi.titlePosY,         fsi.titleFontSize, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));

	local text = courseplay:loc('COURSEPLAY_SCANNING_FIELD_NMB'):format(courseplay.fields.curFieldScanIndex, g_currentMission.fieldDefinitionBase.numberOfFields);
	courseplay:setFontSettings('white', false, 'left');
	renderText(fsi.textPosX, fsi.textPosY,         fsi.textFontSize, text);

	-- reset font settings
	courseplay:setFontSettings('white', false, 'left');
end;

function CpManager.drawMouseButtonHelp(self, posY, txt)
	local xLeft = g_currentMission.helpBoxTextPos1X;
	local xRight = g_currentMission.helpBoxTextPos2X;

	local ovl = courseplay.inputBindings.mouse.overlaySecondary;
	if ovl then
		local y = posY - g_currentMission.helpBoxTextSize - g_currentMission.helpBoxTextLineSpacing*3;
		ovl:setPosition(xLeft - ovl.width*0.2, y);
		ovl:render();
		xLeft = xLeft + ovl.width*0.6;
	end;

	posY = posY - g_currentMission.helpBoxTextSize - g_currentMission.helpBoxTextLineSpacing*2;
	setTextAlignment(RenderText.ALIGN_RIGHT);
	renderText(xRight, posY, g_currentMission.helpBoxTextSize, txt);

	setTextAlignment(RenderText.ALIGN_LEFT);
	renderText(xLeft, posY, g_currentMission.helpBoxTextSize, courseplay.inputBindings.mouse.secondaryTextI18n);
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
			if vehicle:getIsCourseplayDriving() and not vehicle.aiIsStarted then
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
    yesNoDialogue.target:setTitle(title);
	yesNoDialogue.target:setText(text);
 	yesNoDialogue.target:setCallback(callbackFn, self);
	self[showBoolVar] = false;
end;


-- ####################################################################################################
-- FIELD SCAN Y/N DIALOGUE
function CpManager:fieldScanDialogueCallback(setActive)
	courseplay.fields.automaticScan = setActive;

	g_gui:showGui('');
end;


-- ####################################################################################################
-- WAGES
function CpManager:setupWages()
	self.wageDifficultyMultiplier = Utils.lerp(0.5, 1, (g_currentMission.missionInfo.difficulty - 1) / 2);
	self.wagesActive = true;
	self.wagePerHour = 1500;
	self.wagePer10Secs  = self.wagePerHour / 360;
	self.showWagesYesNoDialogue = false;
end;

function CpManager:wagesDialogueCallback(setActive)
	self.wagesActive = setActive;

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
		END_POINT_MODE_1			= { level =  0, text = 'COURSEPLAY_REACHED_END_POINT_MODE_1' };
		END_POINT_MODE_8			= { level =  0, text = 'COURSEPLAY_REACHED_END_POINT_MODE_8' };
		FARM_SILO_NO_FILLTYPE		= { level = -2, text = 'COURSEPLAY_FARM_SILO_NO_FILLTYPE'};
		FARM_SILO_IS_EMPTY			= { level =  0, text = 'COURSEPLAY_FARM_SILO_IS_EMPTY'};
		FARM_SILO_IS_FULL			= { level =  0, text = 'COURSEPLAY_FARM_SILO_IS_FULL'};
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
		WEIGHING_VEHICLE			= { level =  0, text = 'COURSEPLAY_IS_BEING_WEIGHED' };
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

		local height = courseplay.hud:getFullPx(0.3 * 1920 / 1080, 'y');
		local width = height / g_screenAspectRatio;
		self.course2dPlotField = { x = self.course2dPlotPosX, y = self.course2dPlotPosY, width = width, height = height }; -- definition of plot field for 2D
		-- print(('course2dPlotField: x=%f (%.1f px), y=%f (%.1f px), width=%.1f (%.1f px), height=%.2f (%.1f px)'):format(self.course2dPlotPosX, self.course2dPlotPosX * g_screenWidth, self.course2dPlotPosY, self.course2dPlotPosY * g_screenHeight, width, width * g_screenWidth, height, height * g_screenHeight));
		return;
	end;

	self.course2dPolyOverlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds');

	local w, h = courseplay.hud:getPxToNormalConstant(14, 10);
	self.course2dTractorOverlay = Overlay:new('cpTractorIndicator', courseplay.hud.iconSpritePath, 0.5, 0.5, w, h);
	courseplay.utils:setOverlayUVsPx(self.course2dTractorOverlay, courseplay.hud.buttonUVsPx.recordingPlay, courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
	self.course2dTractorOverlay:setColor(0,0.8,1,1);
end;

-- ####################################################################################################
-- LOAD SETTINGS FROM COURSEPLAYSETTINGS.XML / SET DEFAULT SETTINGS IF NOT EXISTING
function CpManager:loadXmlSettings()
	createFolder(self.savegameFolderPath);
	local cpSettingsXml;
	if fileExists(self.cpSettingsXmlFilePath) then
		cpSettingsXml = loadXMLFile('cpSettingsXml', self.cpSettingsXmlFilePath);
	else
		print('## Courseplay: loading default settings');
		if not self.oldCPFileExists then
			self.showFieldScanYesNoDialogue = true;
			self.showWagesYesNoDialogue = true;
		end;
		return;
	end;

	if cpSettingsXml and cpSettingsXml ~= 0 then
		print('## Courseplay: loading settings from "courseplaySettings.xml"');

		-- hud position
		local key = 'CPSettings.courseplayHud';

		local sizeRatio, uiScale = getXMLFloat(cpSettingsXml, key .. '#hudScale'), getXMLFloat(cpSettingsXml, key .. '#uiScale');
		if sizeRatio and sizeRatio ~= courseplay.hud.sizeRatio then
			courseplay.hud.sizeRatio = sizeRatio;

			-- Reposition hud based on size.
			courseplay.hud.basePosX = 0.5 - courseplay.hud:pxToNormal(630 / 2, 'x'); -- Center Screen - half hud width
			courseplay.hud.basePosY = courseplay.hud:pxToNormal(32, 'y');
		end;

		local newUiScale = courseplay.hud.uiScale;
		local posX, posY = getXMLFloat(cpSettingsXml, key .. '#posX'), getXMLFloat(cpSettingsXml, key .. '#posY');
		if uiScale and posX then
			posX = courseplay.hud:getFullPx(posX, 'x');
		end;
		if uiScale and posY then
			posY = courseplay.hud:getFullPx(posY, 'y');
		end;

	    -- Check if the UI Scale have been changed since last time and reset center position if needed.
		if uiScale and uiScale ~= newUiScale then
			print("## CoursePlay: UI Scale have changed. Recalculating hud positions.");
			-- Set the uiScale to the loaded one so we can get the original posX
			courseplay.hud.uiScale = uiScale;
			-- Get the original posX
			local oldPosX = 0.5 - courseplay.hud:pxToNormal(630 / 2, 'x');
			local oldPosY = courseplay.hud:pxToNormal(32, 'y');
			-- Reset the uiScale back to the new one.
			courseplay.hud.uiScale = newUiScale;

			-- if the position is the same, then we need to update it to the new center position.
			-- NOTE: If they are not the same, then the posX might have been changed by the user for there own position, and then we dont change it back to the center position.
			if not posX or (posX and oldPosX == posX) then
				courseplay.hud.basePosX = 0.5 - courseplay.hud:pxToNormal(630 / 2, 'x'); -- Center Screen - half hud width
			end;
			if not posY or (posY and oldPosY == posY) then
				courseplay.hud.basePosY = courseplay.hud:pxToNormal(32, 'y');
			end;

		-- Get the saved position if UI Scale are the same.
		else
			if uiScale and posX then
				courseplay.hud.basePosX = posX;
			end;
			if uiScale and posY then
				courseplay.hud.basePosY = posY;
			end;
		end;

		-- fields settings
		key = 'CPSettings.courseplayFields';
		local fieldsAutomaticScan = getXMLBool(cpSettingsXml, key .. '#automaticScan');
		if fieldsAutomaticScan ~= nil then
			courseplay.fields.automaticScan = fieldsAutomaticScan;
		elseif not self.oldCPFileExists then
			self.showFieldScanYesNoDialogue = true;
		end;
		courseplay.fields.onlyScanOwnedFields	  = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#onlyScanOwnedFields'),	 courseplay.fields.onlyScanOwnedFields);
		courseplay.fields.debugScannedFields 	  = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#debugScannedFields'),		 courseplay.fields.debugScannedFields);
		courseplay.fields.debugCustomLoadedFields = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#debugCustomLoadedFields'), courseplay.fields.debugCustomLoadedFields);
		courseplay.fields.scanStep				  = Utils.getNoNil( getXMLInt(cpSettingsXml, key .. '#scanStep'),				 courseplay.fields.scanStep);

		-- wages
		key = 'CPSettings.courseplayWages';
		local wagesActive, wagePerHour = getXMLBool(cpSettingsXml, key .. '#active'), getXMLInt(cpSettingsXml, key .. '#wagePerHour');
		if wagesActive ~= nil then
			self.wagesActive = wagesActive;
		elseif not self.oldCPFileExists then
			self.showWagesYesNoDialogue = true;
		end;
		if wagePerHour ~= nil then
			self.wagePerHour = wagePerHour;
		elseif not self.oldCPFileExists then
			self.showWagesYesNoDialogue = true;
		end;
		self.wagePer10Secs = self.wagePerHour / 360;

		-- ingame map
		key = 'CPSettings.courseplayIngameMap';
		self.ingameMapIconActive	 = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#active'),		self.ingameMapIconActive);
		self.ingameMapIconShowName	 = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#showName'),	self.ingameMapIconShowName);
		self.ingameMapIconShowCourse = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#showCourse'),	self.ingameMapIconShowCourse);
		self.ingameMapIconShowText = true --self.ingameMapIconShowName or self.ingameMapIconShowCourse;

		-- 2D course
		key = 'CPSettings.course2D';
		self.course2dPlotPosX		= Utils.getNoNil(getXMLFloat(cpSettingsXml, key .. '#posX'),	 self.course2dPlotPosX);
		self.course2dPlotPosY		= Utils.getNoNil(getXMLFloat(cpSettingsXml, key .. '#posY'),	 self.course2dPlotPosY);
		self.course2dPdaMapOpacity	= Utils.getNoNil(getXMLFloat(cpSettingsXml, key .. '#opacity'), self.course2dPdaMapOpacity);

		self.course2dPlotField.x = self.course2dPlotPosX;
		self.course2dPlotField.y = self.course2dPlotPosY;

		--------------------------------------------------
		delete(cpSettingsXml);
	end;
end;

function CpManager:importOldCPFiles(save, courses_by_id, folders_by_id)
	local cpFile = loadXMLFile("cpFile", self.cpXmlFilePath);

	if not fileExists(self.cpXmlFilePath) and false then
		-------------------------------------------------------------------------
		-- Import Settings from old file
		-------------------------------------------------------------------------
		print('## Courseplay: Importing old settings from "courseplay.xml"');

		-- hud position
		local key = 'XML.courseplayHud';
		local posX, posY = getXMLFloat(cpFile, key .. '#posX'), getXMLFloat(cpFile, key .. '#posY');
		if posX then
			courseplay.hud.basePosX = courseplay.hud:getFullPx(posX, 'x');
		end;
		if posY then
			courseplay.hud.basePosY = courseplay.hud:getFullPx(posY, 'y');
		end;

		-- fields settings
		key = 'XML.courseplayFields';
		local fieldsAutomaticScan = getXMLBool(cpFile, key .. '#automaticScan');
		if fieldsAutomaticScan ~= nil then
			courseplay.fields.automaticScan = fieldsAutomaticScan;
		end;
		courseplay.fields.onlyScanOwnedFields	  = Utils.getNoNil(getXMLBool(cpFile, key .. '#onlyScanOwnedFields'),	 courseplay.fields.onlyScanOwnedFields);
		courseplay.fields.debugScannedFields 	  = Utils.getNoNil(getXMLBool(cpFile, key .. '#debugScannedFields'),		 courseplay.fields.debugScannedFields);
		courseplay.fields.debugCustomLoadedFields = Utils.getNoNil(getXMLBool(cpFile, key .. '#debugCustomLoadedFields'), courseplay.fields.debugCustomLoadedFields);
		courseplay.fields.scanStep				  = Utils.getNoNil( getXMLInt(cpFile, key .. '#scanStep'),				 courseplay.fields.scanStep);

		-- wages
		key = 'XML.courseplayWages';
		local wagesActive, wagePerHour = getXMLBool(cpFile, key .. '#active'), getXMLInt(cpFile, key .. '#wagePerHour');
		if wagesActive ~= nil then
			self.wagesActive = wagesActive;
		end;
		if wagePerHour ~= nil then
			self.wagePerHour = wagePerHour;
		end;
		self.wagePer10Secs = self.wagePerHour / 360;

		-- ingame map
		key = 'XML.courseplayIngameMap';
		self.ingameMapIconActive	 = Utils.getNoNil(getXMLBool(cpFile, key .. '#active'),		self.ingameMapIconActive);
		self.ingameMapIconShowName	 = Utils.getNoNil(getXMLBool(cpFile, key .. '#showName'),	self.ingameMapIconShowName);
		self.ingameMapIconShowCourse = Utils.getNoNil(getXMLBool(cpFile, key .. '#showCourse'),	self.ingameMapIconShowCourse);
		self.ingameMapIconShowText =  true --self.ingameMapIconShowName or self.ingameMapIconShowCourse;

		-- 2D course
		key = 'XML.course2D';
		self.course2dPlotPosX		= Utils.getNoNil(getXMLFloat(cpFile, key .. '#posX'),	 self.course2dPlotPosX);
		self.course2dPlotPosY		= Utils.getNoNil(getXMLFloat(cpFile, key .. '#posY'),	 self.course2dPlotPosY);
		self.course2dPdaMapOpacity	= Utils.getNoNil(getXMLFloat(cpFile, key .. '#opacity'), self.course2dPdaMapOpacity);

		self.course2dPlotField.x = self.course2dPlotPosX;
		self.course2dPlotField.y = self.course2dPlotPosY;

		-- Save Imported settings.
		self:saveXmlSettings();
	end;

	-------------------------------------------------------------------------
	-- Import Folders and Courses from old file
	-------------------------------------------------------------------------

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- DO CHECKS AND SETUP BEFORE IMPORTING
	local startFromFolderID, startFromCourseID = Utils.getNoNil(courseplay.courses:getMaxFolderID(), 0) + 1, Utils.getNoNil(courseplay.courses:getMaxCourseID(), 0) + 1;
	if hasXMLProperty(cpFile, "XML.folders.folder(0)") or hasXMLProperty(cpFile, "XML.courses.course(0)") then
		local FolderName = string.format('Import from savegame%d',g_careerScreen.selectedIndex);
		local folderNameClean = courseplay:normalizeUTF8(FolderName);
		local folder = { id = startFromFolderID, uid = 'f' .. startFromFolderID, type = 'folder', name = FolderName, nameClean = folderNameClean, parent = 0 }
		folders_by_id[startFromFolderID] = folder;

		save = true;
	end;


	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- LOAD FOLDERS
	if hasXMLProperty(cpFile, "XML.folders.folder(0)") then
		-- g_careerScreen.selectedIndex
		print('## Courseplay: Importing old folders from "courseplay.xml"');
		local j = 0;
		local currentFolder, FolderName, id, parent, folder;
		local finish_all = false;
		local folders_without_id = {};
		repeat
			-- current folder
			currentFolder = string.format("XML.folders.folder(%d)", j)
			if not hasXMLProperty(cpFile, currentFolder) then
				finish_all = true;
				break;
			end;

			-- folder id
			id = getXMLInt(cpFile, currentFolder .. "#id");
			if id then
				id = id + startFromFolderID;
				-- folder name
				FolderName = getXMLString(cpFile, currentFolder .. "#name");
				if FolderName == nil then
					FolderName = string.format('NO_NAME%d',j);
				end
				local folderNameClean = courseplay:normalizeUTF8(FolderName);

				-- folder parent
				parent = getXMLInt(cpFile, currentFolder .. "#parent");
				if parent == nil then
					parent = 0;
				end;
				parent = parent + startFromFolderID;

				-- "save" current folder
				folder = { id = id, uid = 'f' .. id, type = 'folder', name = FolderName, nameClean = folderNameClean, parent = parent };
				if id ~= 0 then
					folders_by_id[id] = folder;
				else
					table.insert(folders_without_id, folder);
				end;
				j = j + 1;
			end;
		until finish_all == true

		if #folders_without_id > 0 then
			-- give a new ID and save
			local maxID = self:getMaxFolderID()
			for i = #folders_without_id, 1, -1 do
				maxID = maxID + 1
				folders_without_id[i].id = maxID
				folders_without_id[i].uid = 'f' .. maxID
				folders_by_id[maxID] = table.remove(folders_without_id)
			end
			save = true;
		end
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- LOAD COURSES
	if hasXMLProperty(cpFile, "XML.courses.course(0)") then
		print('## Courseplay: Importing old courses from "courseplay.xml"');

		local courses_without_id = {}

		local waypoints;
		local i = 0;
		while true do
			-- current course
			local courseKey = ('XML.courses.course(%d)'):format(i);
			if not hasXMLProperty(cpFile, courseKey) then
				break;
			end;

			-- course ID
			local id = getXMLInt(cpFile, courseKey .. '#id');
			if id then
				id = id + startFromCourseID;
				-- course name
				local courseName = getXMLString(cpFile, courseKey .. '#name');
				if courseName == nil then
					courseName = ('NO_NAME%d'):format(i);
				end;
				local courseNameClean = courseplay:normalizeUTF8(courseName);

				-- course parent
				local parent = getXMLInt(cpFile, courseKey .. '#parent') or 0;
				parent = parent + startFromFolderID;

				-- course workWidth
				local workWidth = getXMLFloat(cpFile, courseKey .. "#workWidth");

				-- course numHeadlandLanes
				local numHeadlandLanes = getXMLInt(cpFile, courseKey .. "#numHeadlandLanes");

				-- course headlandDirectionCW
				local headlandDirectionCW = getXMLBool(cpFile, courseKey .. "#headlandDirectionCW");

				--course waypoints
				waypoints = {};

				local wpNum = 1;
				while true do
					local key = courseKey .. '.waypoint' .. wpNum;

					if not hasXMLProperty(cpFile, key .. '#pos') then
						break;
					end;
					local x, z = Utils.getVectorFromString(getXMLString(cpFile, key .. '#pos'));
					if x == nil or z == nil then
						break;
					end;

					local angle 	  =  getXMLFloat(cpFile, key .. '#angle') or 0;
					local speed 	  = getXMLString(cpFile, key .. '#speed') or '0'; -- use string so we can get both ints and proper floats without LUA's rounding errors
					speed = tonumber(speed);
					if math.ceil(speed) ~= speed then -- is it an old savegame with old speeds ?
						speed = math.ceil(speed * 3600);
					end;

					-- NOTE: only pos, angle and speed can't be nil. All others can and should be nil if not "active", so that they're not saved to the xml
					local wait 		  =    getXMLInt(cpFile, key .. '#wait');
					local rev 		  =    getXMLInt(cpFile, key .. '#rev');
					local crossing 	  =    getXMLInt(cpFile, key .. '#crossing');

					local generated   =   getXMLBool(cpFile, key .. '#generated');
					local lane		  =    getXMLInt(cpFile, key .. '#lane');
					local turnStart	  =    getXMLInt(cpFile, key .. '#turnstart');
					local turnEnd 	  =    getXMLInt(cpFile, key .. '#turnend');
					local ridgeMarker =    getXMLInt(cpFile, key .. '#ridgemarker') or 0;

					crossing = crossing == 1 or wpNum == 1;
					wait = wait == 1;
					rev = rev == 1;

					turnStart = turnStart == 1;
					turnEnd = turnEnd == 1;

					waypoints[wpNum] = {
						cx = x,
						cz = z,
						angle = angle,
						speed = speed,

						rev = rev,
						wait = wait,
						crossing = crossing,
						generated = generated,
						turnStart = turnStart,
						turnEnd = turnEnd,
						ridgeMarker = ridgeMarker
					};

					wpNum = wpNum + 1;
				end; -- END while true (waypoints)

				local course = {
					id = id,
					uid = 'c' .. id ,
					type = 'course',
					name = courseName,
					nameClean = courseNameClean,
					waypoints = waypoints,
					parent = parent,
					workWidth = workWidth,
					numHeadlandLanes = numHeadlandLanes,
					headlandDirectionCW = headlandDirectionCW
				};
				if id ~= 0 then
					courses_by_id[id] = course;
				else
					table.insert(courses_without_id, course);
				end;

				waypoints = nil;
			end;
			i = i + 1;
		end; -- END while true (courses)

		if #courses_without_id > 0 then
			-- give a new ID and save
			local maxID = self:getMaxCourseID()
			for i = 1, #courses_without_id do
				maxID = maxID + 1
				courses_without_id[i].id = maxID
				courses_without_id[i].uid = 'c' .. maxID
				courses_by_id[maxID] = courses_without_id[i]
			end
			save = true;
		end;
	end;

	delete(cpFile);

	-------------------------------------------------------------------------
	-- Delete content of old file
	-------------------------------------------------------------------------
	local cpOldFile = createXMLFile("cpOldFile", self.cpXmlFilePath, 'XML');
	saveXMLFile(cpOldFile);
	delete(cpOldFile);


	return save, courses_by_id, folders_by_id;
end;
