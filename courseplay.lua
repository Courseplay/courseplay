--[[
Courseplay
Specialization for Courseplay

@author  	Jakob Tischler / Thomas Gärtner / horoman
@website:	http://courseplay.github.io/courseplay/
@version:	v4.00 beta
@changelog:	http://courseplay.github.io/courseplay/en/changelog/index.html
]]

courseplay = {
	path = g_currentModDirectory;
	modName = g_currentModName;
	
	-- place sub-classes here in order to get an overview of the contents of the courseplay object and allow for sub-class functions
	utils = {
		signs = {};
	};
	courses = {};
	settings = {};
	hud = {};
	button = {};
	fields = {};
	generation = {};
	pathfinding = {};
};

if courseplay.path ~= nil then
	if not Utils.endsWith(courseplay.path, "/") then
		courseplay.path = courseplay.path .. "/";
	end;
end;

courseplay.sonOfaBangSonOfaBoom = {
	['44d143f3e847254a55835a8298ba4e21'] = true;
	['6fbb6a98a4054b1d603bd8c591d572af'] = true;
	['87a96c3bb39fa285d7ed2fb5beaffc16'] = true;
	['d4043d2f9265e18c794be4159faaef5c'] = true;
};
courseplay.isDeveloper = courseplay.sonOfaBangSonOfaBoom[getMD5(g_settingsNickname)];
if courseplay.isDeveloper then
	print('Special dev magic for Courseplay developer unlocked. You go, girl!');
else
	--print('No cookies for you! (please wait until we have some limited form of a working version...)');
	--courseplay.houstonWeGotAProblem = true;
	--return;
end;

-- working tractors saved in this
courseplay.totalCoursePlayers = {};
courseplay.activeCoursePlayers = {};
courseplay.numActiveCoursePlayers = 0;

function courseplay:setVersionData()
	local modItem = ModsUtil.findModItemByModName(courseplay.modName);
	if modItem and modItem.version then
		courseplay.version = modItem.version;
	end;

	if courseplay.version then
		courseplay.versionSplitStr = Utils.splitString('.', courseplay.version); -- split as strings
		courseplay.versionSplitStr[3] = courseplay.versionSplitStr[3] or '0000';
		--[[
		courseplay.versionSplitFlt = { --split as floats
			[1] = tonumber(courseplay.versionSplitStr[1]);
			[2] = tonumber(courseplay.versionSplitStr[2]);
			[3] = tonumber(courseplay.versionSplitStr[3]);
		};
		]]
		courseplay.versionSplitFlt = table.map(courseplay.versionSplitStr, tonumber);
		courseplay.versionDisplayStr = string.format('v%s.%s\n.%s', courseplay.versionSplitStr[1], courseplay.versionSplitStr[2], courseplay.versionSplitStr[3]); --multiline display string
		courseplay.isDevVersion = courseplay.versionSplitFlt[3] > 0;
		if courseplay.isDevVersion then
			courseplay.versionDisplayStr = courseplay.versionDisplayStr .. '.dev';
		end;
		courseplay.versionFlt = tonumber(string.format('%s.%s%s', courseplay.versionSplitStr[1], courseplay.versionSplitStr[2], courseplay.versionSplitStr[3]));
	else
		courseplay.version = ' [no version specified]';
		courseplay.versionSplitStr = { '0', '00', '0000' };
		courseplay.versionSplitFlt = { 0, 0, 0 };
		courseplay.versionDisplayStr = 'no\nversion';
		courseplay.versionFlt = 0.00000;
		courseplay.isDevVersion = false;
	end;
	courseplay.versionDisplay = courseplay.versionSplitFlt;
end;

function courseplay:initialize()
	local fileList = {
		'astar', 
		'base',
		'button', 
		'bypass',
		'combines', 
		'courseplay_event', 
		'courseplay_manager', 
		'course_management',
		'debug', 
		'distance', 
		'drive', 
		'fields', 
		'fruit', 
		'generateCourse', 
		'global', 
		'helpers', 
		'hud', 
		'input', 
		'inputCourseNameDialogue', 
		'mode1', 
		'mode2', 
		'mode3', 
		'mode4', 
		'mode6', 
		'mode7', 
		'mode8', 
		'mode9', 
		'pathfinding',
		'pathfinding_helpers',
		'pathfinding_PathFinderOnGrids',
		'recording', 
		'reverse',
		'settings', 
		'signs', 
		'specialTools', 
		'start_stop', 
		'tippers', 
		'triggers', 
		'turn'
	};

	local numFiles, numFilesLoaded = #(fileList), 0;
	for _,file in ipairs(fileList) do
		local filePath = courseplay.path .. file .. '.lua';

		if fileExists(filePath) then
			source(filePath);
			--print('\t### Courseplay: ' .. filePath .. ' has been loaded');
			numFilesLoaded = numFilesLoaded + 1;

			if file == 'inputCourseNameDialogue' then
				g_inputCourseNameDialogue = inputCourseNameDialogue:new();
				g_gui:loadGui(courseplay.path .. 'inputCourseNameDialogue.xml', 'inputCourseNameDialogue', g_inputCourseNameDialogue);
			end;
		else
			print('\tError: Courseplay could not load file ' .. filePath);
		end;
	end;

	courseplay:setVersionData();

	courseplay:setInputBindings();

	courseplay:setGlobalData();

	print(('### Courseplay: initialized %d/%d files (v%s)'):format(numFilesLoaded, numFiles, courseplay.version));

	if courseplay.isDevVersion then
		local devWarning = '';
		devWarning = devWarning .. '\t' .. ('*'):rep(47) .. ' WARNING ' .. ('*'):rep(47) .. '\n';
		devWarning = devWarning .. '\t* You are using a development version of Courseplay, which may and will contain errors, bugs,         *\n';
		devWarning = devWarning .. '\t* mistakes and unfinished code. Chances are your computer will explode when using it. Twice.          *\n';
		devWarning = devWarning .. '\t* If you have no idea what "beta", "alpha", or "developer" means and entails, remove this version     *\n';
		devWarning = devWarning .. '\t* of Courseplay immediately. The Courseplay team will not take any responsibility for crop destroyed, *\n';
		devWarning = devWarning .. '\t* savegames deleted or baby pandas killed.                                                            *\n';
		devWarning = devWarning .. '\t' .. ('*'):rep(103);
		print(devWarning);
	end;
end;

function courseplay:setGlobalData()
	if courseplay.globalDataSet then
		return;
	end;

	courseplay.cpFolderPath = getUserProfileAppPath() .. 'courseplay/';
	courseplay.cpSavegameFolderPath = courseplay.cpFolderPath .. 'savegame' .. g_careerScreen.selectedIndex .. '/';
	courseplay.cpXmlFilePath = courseplay.cpSavegameFolderPath .. 'courseplay.xml';
	courseplay.cpFieldsXmlFilePath = courseplay.cpSavegameFolderPath .. 'courseplayFields.xml';
	createFolder(courseplay.cpFolderPath);
	createFolder(courseplay.cpSavegameFolderPath);

	local customPosX, customPosY;
	local fieldsAutomaticScan, fieldsDebugScan, fieldsDebugCustomLoad, fieldsCustomScanStep, fieldsOnlyScanOwnedFields = true, false, false, nil, true;
	local wagesActive, wagesAmount = false, 1125;

	if courseplay.cpXmlFilePath and fileExists(courseplay.cpXmlFilePath) then
		local cpFile = loadXMLFile('cpFile', courseplay.cpXmlFilePath);
		local hudKey = 'XML.courseplayHud';
		if hasXMLProperty(cpFile, hudKey) then
			customPosX = getXMLFloat(cpFile, hudKey .. '#posX');
			customPosY = getXMLFloat(cpFile, hudKey .. '#posY');
		end;

		local fieldsKey = 'XML.courseplayFields';
		if hasXMLProperty(cpFile, fieldsKey) then
			fieldsAutomaticScan   = Utils.getNoNil(getXMLBool(cpFile, fieldsKey .. '#automaticScan'), true);
			fieldsOnlyScanOwnedFields = Utils.getNoNil(getXMLBool(cpFile, fieldsKey .. '#onlyScanOwnedFields'), true);
			fieldsDebugScan       = Utils.getNoNil(getXMLBool(cpFile, fieldsKey .. '#debugScannedFields'), false);
			fieldsDebugCustomLoad = Utils.getNoNil(getXMLBool(cpFile, fieldsKey .. '#debugCustomLoadedFields'), false);
			fieldsCustomScanStep = getXMLInt(cpFile, fieldsKey .. '#scanStep');
		end;

		local wagesKey = 'XML.courseplayWages';
		if hasXMLProperty(cpFile, wagesKey) then
			wagesActive = Utils.getNoNil(getXMLBool(cpFile, wagesKey .. '#active'), wagesActive);
			wagesAmount = Utils.getNoNil(getXMLInt(cpFile, wagesKey .. '#wagePerHour'), wagesAmount);
		end;

		delete(cpFile);
	end;

	courseplay.numAiModes = 9;
	local ch = courseplay.hud
	ch.infoBasePosX = Utils.getNoNil(customPosX, 0.433);
	ch.infoBasePosY = Utils.getNoNil(customPosY, 0.002);
	ch.infoBaseWidth = 0.512;
	ch.infoBaseHeight = 0.512;
	ch.offset = 16/1920;  --0.006 (button width)
	ch.colors = {
		white =         { 255/255, 255/255, 255/255, 1.00 };
		whiteInactive = { 255/255, 255/255, 255/255, 0.75 };
		whiteDisabled = { 255/255, 255/255, 255/255, 0.15 };
		hover =         {  32/255, 168/255, 219/255, 1.00 };
		activeGreen =   { 110/255, 235/255,  56/255, 1.00 };
		activeRed =     { 206/255,  83/255,  77/255, 1.00 };
		closeRed =      { 180/255,   0/255,   0/255, 1.00 };
		warningRed =    { 240/255,  25/255,  25/255, 1.00 };
		shadow =        {  35/255,  35/255,  35/255, 1.00 };
	};

	ch.pagesPerMode = {
		--Pg 0		  Pg 1		  Pg 2		  Pg 3		   Pg 4			Pg 5		Pg 6		Pg 7		Pg 8		 Pg 9
		{ [0] = true, [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false }; --Mode 1
		{ [0] = true, [1] = true, [2] = true, [3] = true,  [4] = true,  [5] = true, [6] = true, [7] = true, [8] = false, [9] = false }; --Mode 2
		{ [0] = true, [1] = true, [2] = true, [3] = true,  [4] = true,  [5] = true, [6] = true, [7] = true, [8] = false, [9] = false }; --Mode 3
		{ [0] = true, [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = true,  [9] = false }; --Mode 4
		{ [0] = true, [1] = true, [2] = true, [3] = false, [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false }; --Mode 5
		{ [0] = true, [1] = true, [2] = true, [3] = false, [4] = false, [5] = true, [6] = true, [7] = true, [8] = true,  [9] = false }; --Mode 6
		{ [0] = true, [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false }; --Mode 7
		{ [0] = true, [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false }; --Mode 8
		{ [0] = true, [1] = true, [2] = true, [3] = false, [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = true  }; --Mode 9
	};
	ch.visibleArea = {
		x1 = courseplay.hud.infoBasePosX;
		x2 = courseplay.hud.infoBasePosX + 0.320;
		y1 = courseplay.hud.infoBasePosY;
		y2 = --[[0.30463;]] --[[0.002 + 0.271 + 32/1080 + 0.002;]] courseplay.hud.infoBasePosY + 0.271 + 32/1080 + 0.002;
	};
	ch.visibleArea.y2InclSuc = ch.visibleArea.y2 + 0.15;
	ch.visibleArea.width = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1;
	ch.infoBaseCenter = (courseplay.hud.visibleArea.x1 + courseplay.hud.visibleArea.x2)/2;

	--print(string.format("\t\tposX=%f,posY=%f, visX1=%f,visX2=%f, visY1=%f,visY2=%f, visCenter=%f", courseplay.hud.infoBasePosX, courseplay.hud.infoBasePosY, courseplay.hud.visibleArea.x1, courseplay.hud.visibleArea.x2, courseplay.hud.visibleArea.y1, courseplay.hud.visibleArea.y2, courseplay.hud.infoBaseCenter));

	-- lines and text
	ch.linesPosY = {};
	ch.linesBottomPosY = {};
	ch.linesButtonPosY = {};
	ch.numPages = 9;
	ch.numLines = 6;
	ch.lineHeight = 0.0213;
	for l=1,courseplay.hud.numLines do
		if l == 1 then
			courseplay.hud.linesPosY[l] = courseplay.hud.infoBasePosY + 0.215;
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.infoBasePosY + 0.08;
		else
			courseplay.hud.linesPosY[l] = courseplay.hud.linesPosY[1] - ((l-1) * courseplay.hud.lineHeight);
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.linesBottomPosY[1] - ((l-1) * courseplay.hud.lineHeight);
		end;
		courseplay.hud.linesButtonPosY[l] = courseplay.hud.linesPosY[l] - 0.003;
	end;
	ch.fontSizes = {
		seedUsageCalculator = 0.015;
		hudTitle = 0.021;
		contentTitle = 0.016;
		contentValue = 0.014; 
		bottomInfo = 0.015;
		version = 0.01;
		infoText = 0.015;
		fieldScanTitle = 0.021;
		fieldScanData = 0.018;
	};

	courseplay.hud.col2posX = {
		[0] = courseplay.hud.infoBasePosX + 0.122,
		[1] = courseplay.hud.infoBasePosX + 0.142,
		[2] = courseplay.hud.infoBasePosX + 0.122,
		[3] = courseplay.hud.infoBasePosX + 0.122,
		[4] = courseplay.hud.infoBasePosX + 0.122,
		[5] = courseplay.hud.infoBasePosX + 0.122,
		[6] = courseplay.hud.infoBasePosX + 0.182,
		[7] = courseplay.hud.infoBasePosX + 0.192,
		[8] = courseplay.hud.infoBasePosX + 0.142,
		[9] = courseplay.hud.infoBasePosX + 0.230,
	};
	courseplay.hud.col2posXforce = {
		[0] = {
			[4] = courseplay.hud.infoBasePosX + 0.212;
			[5] = courseplay.hud.infoBasePosX + 0.212;
		};
		[1] = {
			[4] = courseplay.hud.infoBasePosX + 0.182;
			[5] = courseplay.hud.infoBasePosX + 0.182;
			[6] = courseplay.hud.infoBasePosX + 0.182;
		};
		[7] = {
			[5] = courseplay.hud.infoBasePosX + 0.105;
			[6] = courseplay.hud.infoBasePosX + 0.105;
		};
		[8] = {
			[6] = courseplay.hud.infoBasePosX + 0.265;
		};
	};
	courseplay.hud.buttonPosX = {
		[1] = courseplay.hud.infoBasePosX + 0.285;
		[2] = courseplay.hud.infoBasePosX + 0.300;
	};

	ch.clickSound = createSample("clickSound");
	loadSample(courseplay.hud.clickSound, Utils.getFilename("sounds/cpClickSound.wav", courseplay.path), false);

	courseplay.lightsNeeded = false;

	local langNumData = {
		br = { '.', ',' },
		cz = { ' ', ',' },
		de = { '.', ',' },
		en = { ',', '.' },
		es = { '.', ',' },
		fr = { ' ', ',' },
		it = { '.', ',' },
		jp = { ',', '.' },
		pl = { ' ', ',' },
		ru = { ' ', ',' }
	};
	courseplay.numberSeparator = '\'';
	courseplay.numberDecimalSeparator = '.';
	if g_languageShort and langNumData[g_languageShort] then
		courseplay.numberSeparator        = langNumData[g_languageShort][1];
		courseplay.numberDecimalSeparator = langNumData[g_languageShort][2];
	end;

	--GLOBALINFOTEXT
	courseplay.globalInfoText = {};
	courseplay.globalInfoText.posY = 0.01238; -- = ingameMap posY
	courseplay.globalInfoText.posYAboveMap = courseplay.globalInfoText.posY + 0.027777777777778 + 0.20833333333333;

	courseplay.globalInfoText.fontSize = 0.016;
	courseplay.globalInfoText.lineHeight = courseplay.globalInfoText.fontSize * 1.2;
	courseplay.globalInfoText.lineMargin = courseplay.globalInfoText.lineHeight * 0.2;
	courseplay.globalInfoText.buttonHeight = courseplay.globalInfoText.lineHeight;
	courseplay.globalInfoText.buttonWidth = courseplay.globalInfoText.buttonHeight / g_screenAspectRatio;
	courseplay.globalInfoText.buttonPosX = 0.015625; -- = ingameMap posX
	courseplay.globalInfoText.buttonMargin = courseplay.globalInfoText.buttonWidth * 0.4;
	courseplay.globalInfoText.backgroundPadding = courseplay.globalInfoText.buttonWidth * 0.2;
	courseplay.globalInfoText.backgroundImg = 'dataS2/menu/white.png';
	courseplay.globalInfoText.backgroundPosX = courseplay.globalInfoText.buttonPosX + courseplay.globalInfoText.buttonWidth + courseplay.globalInfoText.buttonMargin;
	courseplay.globalInfoText.backgroundPosY = courseplay.globalInfoText.posY;
	courseplay.globalInfoText.textPosX = courseplay.globalInfoText.backgroundPosX + courseplay.globalInfoText.backgroundPadding;
	courseplay.globalInfoText.content = {};
	courseplay.globalInfoText.hasContent = false;
	courseplay.globalInfoText.vehicleHasText = {};
	courseplay.globalInfoText.levelColors = {
		[-2] = courseplay.utils.table.copy(courseplay.hud.colors.closeRed);
		[-1] = courseplay.utils.table.copy(courseplay.hud.colors.activeRed);
		[0]  = courseplay.utils.table.copy(courseplay.hud.colors.hover);
		[1]  = courseplay.utils.table.copy(courseplay.hud.colors.activeGreen);
	};
	--[[
	for i=-2,1 do
		courseplay.globalInfoText.levelColors[i][4] = 0.85;
	end;
	]]
	courseplay.globalInfoText.msgReference = {
		BALER_NETS					= { level = -2, text = 'COURSEPLAY_BALER_NEEDS_NETS' };
		BGA_IS_FULL					= { level = -1, text = 'COURSEPLAY_BGA_IS_FULL'};
		DAMAGE_IS					= { level =  0, text = 'COURSEPLAY_DAMAGE_IS_BEING_REPAIRED' };
		DAMAGE_MUST					= { level = -2, text = 'COURSEPLAY_DAMAGE_MUST_BE_REPAIRED' };
		DAMAGE_SHOULD				= { level = -1, text = 'COURSEPLAY_DAMAGE_SHOULD_BE_REPAIRED' };
		END_POINT					= { level =  0, text = 'COURSEPLAY_REACHED_END_POINT' };
		FARM_SILO_DONT_HAVE_FILTYPE	= { level = -2, text = 'COURSEPLAY_FARM_SILO_DONT_HAVE_FILTYPE'};
		FARM_SILO_IS_EMPTY			= { level =  0, text = 'COURSEPLAY_FARM_SILO_IS_EMPTY'};
		FUEL_IS						= { level =  0, text = 'COURSEPLAY_IS_BEING_REFUELED' };
		FUEL_MUST					= { level = -2, text = 'COURSEPLAY_MUST_BE_REFUELED' };
		FUEL_SHOULD					= { level = -1, text = 'COURSEPLAY_SHOULD_BE_REFUELED' };
		HOSE_MISSING				= { level = -2, text = 'COURSEPLAY_HOSEMISSING' };
		NEEDS_REFILLING				= { level = -1, text = 'COURSEPLAY_NEEDS_REFILLING' };
		NEEDS_UNLOADING				= { level = -1, text = 'COURSEPLAY_NEEDS_UNLOADING' };
		OVERLOADING_POINT			= { level =  0, text = 'COURSEPLAY_REACHED_OVERLOADING_POINT' };
		PICKUP_JAMMED				= { level = -2, text = 'COURSEPLAY_PICKUP_JAMMED' };
		SLIPPING_0					= { level = -1, text = 'COURSEPLAY_SLIPPING_WARNING_0' };
		SLIPPING_1					= { level = -1, text = 'COURSEPLAY_SLIPPING_WARNING_1' };
		SLIPPING_2					= { level = -2, text = 'COURSEPLAY_SLIPPING_WARNING_2' };
		TRAFFIC						= { level = -1, text = 'COURSEPLAY_IS_IN_TRAFFIC' };
		UNLOADING_BALE				= { level =  0, text = 'COURSEPLAY_UNLOADING_BALES' };
		WAIT_POINT					= { level =  0, text = 'COURSEPLAY_REACHED_WAITING_POINT' };
		WATER						= { level = -2, text = 'COURSEPLAY_WATER_WARNING' };
		WEATHER						= { level =  0, text = 'COURSEPLAY_WEATHER_WARNING' };
		WORK_END					= { level =  1, text = 'COURSEPLAY_WORK_END' };
	};


	--TRIGGERS
	courseplay.confirmedNoneTipTriggers = {};
	courseplay.confirmedNoneTipTriggersCounter = 0;
	courseplay.confirmedNoneSpecialTriggers = {};
	courseplay.confirmedNoneSpecialTriggersCounter = 0;

	--TRAFFIC
	courseplay.trafficCollisionIgnoreList = {};

	--MULTIPLAYER
	courseplay.checkValues = {
		"infoText",
		"HUD0noCourseplayer",
		"HUD0wantsCourseplayer",
		"HUD0tractorName",
		"HUD0tractorForcedToStop",
		"HUD0tractor",
		"HUD0combineForcedSide",
		"HUD0isManual",
		"HUD0turnStage",
		"HUD1notDrive",
		"HUD1wait",
		"HUD1noWaitforFill",
		"HUD4combineName",
		"HUD4hasActiveCombine",
		"HUD4savedCombine",
		"HUD4savedCombineName",
		"HUDrecordnumber"
	};

	--SIGNS
	local signData = {
		normal = { 10000, "current",  4.5 }, -- orig height=5
		start =  {   500, "current",  4.5 }, -- orig height=3
		stop =   {   500, "current",  4.5 }, -- orig height=3
		wait =   {  1000, "current",  4.5 }, -- orig height=3
		cross =  {  2000, "crossing", 4.0 }
	};
	local globalRootNode = getRootNode();
	courseplay.signs = {
		buffer = {};
		bufferMax = {};
		sections = {};
		heightPos = {};
		protoTypes = {};
	};
	for signType,data in pairs(signData) do
		courseplay.signs.buffer[signType] =    {};
		courseplay.signs.bufferMax[signType] = data[1];
		courseplay.signs.sections[signType] =  data[2];
		courseplay.signs.heightPos[signType] = data[3];

		local i3dNode = Utils.loadSharedI3DFile("img/signs/" .. signType .. ".i3d", courseplay.path);
		local itemNode = getChildAt(i3dNode, 0);
		link(globalRootNode, itemNode);
		setRigidBodyType(itemNode, "NoRigidBody");
		setTranslation(itemNode, 0, 0, 0);
		setVisibility(itemNode, false);
		delete(i3dNode);
		courseplay.signs.protoTypes[signType] = itemNode;
	end;

	--FIELDS
	courseplay.fields.fieldData = {};
	courseplay.fields.numAvailableFields = 0;
	courseplay.fields.fieldChannels = {};
	courseplay.fields.lastChannel = 0;
	courseplay.fields.curFieldScanIndex = 0;
	courseplay.fields.allFieldsScanned = false;
	courseplay.fields.ingameDataSetUp = false;
	courseplay.fields.customFieldMaxNum = 150;
	courseplay.fields.automaticScan = fieldsAutomaticScan;
	courseplay.fields.onlyScanOwnedFields = fieldsOnlyScanOwnedFields;
	courseplay.fields.debugScannedFields = fieldsDebugScan;
	courseplay.fields.debugCustomLoadedFields = fieldsDebugCustomLoad;
	courseplay.fields.scanStep = Utils.getNoNil(fieldsCustomScanStep, courseplay.fields.defaultScanStep);
	courseplay.fields.seedUsageCalculator = {};
	courseplay.fields.seedUsageCalculator.fieldsWithoutSeedData = {};

	--PATHFINDING
	courseplay.pathfinding = {};

	--UTF8
	courseplay.allowedCharacters = courseplay:getAllowedCharacters();
	courseplay.utf8normalization = courseplay:getUtf8normalization();

	-- WORKER WAGES
	courseplay.wagesActive = wagesActive;
	courseplay.wagePerHour = wagesAmount;
	courseplay.wagePerMin  = wagesAmount / 60;

	--print("\t### Courseplay: setGlobalData() finished");

	courseplay.globalDataSet = true;
end;

courseplay:initialize();

--load(), update(), updateTick(), draw() are located in base.lua
--mouseEvent(), keyEvent() are located in input.lua
