--
-- Courseplay
-- Specialization for Courseplay
--
-- @author  	Lautschreier / Hummel / Wolverin0815 / Bastian82 / skydancer / Jakob Tischler / Thomas Gärtner
-- @website:	http://courseplay.github.io/courseplay/
-- @version:	v3.41
-- @changelog:	http://courseplay.github.io/courseplay/en/changelog/index.html

courseplay = {
	path = g_currentModDirectory;
};
if courseplay.path ~= nil then
	if not Utils.endsWith(courseplay.path, "/") then
		courseplay.path = courseplay.path .. "/";
	end;
end;

local modDescPath = courseplay.path .. "modDesc.xml";
if fileExists(modDescPath) then
	courseplay.modDescFile = loadXMLFile("cp_modDesc", modDescPath);

	courseplay.version = Utils.getNoNil(getXMLString(courseplay.modDescFile, "modDesc.version"), " [no version specified]");
	if courseplay.version ~= " [no version specified]" then
		courseplay.versionDisplay = Utils.splitString(".", courseplay.version);
	end;
end;

-- working tractors saved in this
working_course_players = {};

function courseplay:initialize()
	local fileList = {
		"astar", 
		"base",
		"button", 
		"combines", 
		"courseplay_event", 
		"courseplay_manager", 
		"course_management",
		"debug", 
		"distance", 
		"drive", 
		"fruit", 
		"generateCourse", 
		"global", 
		"helpers", 
		"hud", 
		"input", 
		"inputCourseNameDialogue", 
		"mode1", 
		"mode2", 
		"mode4", 
		"mode6", 
		"mode8", 
		"mode9", 
		"recording", 
		"settings", 
		"signs", 
		"specialTools", 
		"start_stop", 
		"tippers", 
		"triggers", 
		"turn"
	};

	local numFiles, numFilesLoaded = table.getn(fileList), 0;
	for _,file in ipairs(fileList) do
		local filePath = courseplay.path .. file .. ".lua";

		if fileExists(filePath) then
			source(filePath);
			--print("\t### Courseplay: " .. filePath .. " has been loaded");
			numFilesLoaded = numFilesLoaded + 1;

			if file == "inputCourseNameDialogue" then
				g_inputCourseNameDialogue = inputCourseNameDialogue:new();
				g_gui:loadGui(courseplay.path .. "inputCourseNameDialogue.xml", "inputCourseNameDialogue", g_inputCourseNameDialogue);
			end;
		else
			print("\tError: Courseplay could not load file " .. filePath);
		end;
	end;

	courseplay:setGlobalData();

	print(string.format("\t### Courseplay: initialized %d/%d files (v%s)", numFilesLoaded, numFiles, courseplay.version));
end;

function courseplay:setGlobalData()
	local customPosX, customPosY = nil, nil;
	local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
	if savegame ~= nil then
		local cpFilePath = savegame.savegameDirectory .. "/courseplay.xml";
		if fileExists(cpFilePath) then
			local cpFile = loadXMLFile("cpFile", cpFilePath);
			local hudKey = "XML.courseplayHud"
			if hasXMLProperty(cpFile, hudKey) then
				customPosX = getXMLFloat(cpFile, hudKey .. "#posX");
				customPosY = getXMLFloat(cpFile, hudKey .. "#posY");
			end;
			delete(cpFile);
		end;
	end;

	courseplay.numAiModes = 9;
	courseplay.hud = {
		infoBasePosX = Utils.getNoNil(customPosX, 0.433);
		infoBasePosY = Utils.getNoNil(customPosY, 0.002);
		infoBaseWidth = 0.512; --try: 512/1920
		infoBaseHeight = 0.512; --try: 512/1080
		linesPosY = {};
		linesBottomPosY = {};
		linesButtonPosY = {};
		numPages = 9,
		numLines = 6;
		lineHeight = 0.021;
		colors = {
			white =         {       1,       1,       1, 1    };
			whiteInactive = {       1,       1,       1, 0.75 };
			whiteDisabled = {       1,       1,       1, 0.15 };
			hover =         {  32/255, 168/255, 219/255, 1    };
			activeGreen =   { 110/255, 235/255,  56/255, 1    };
			activeRed =     { 206/255,  83/255,  77/255, 1    };
			closeRed =      { 180/255,       0,       0, 1    };
			warningRed =    { 240/255,  25/255,  25/255, 1    };
			shadow =        {  35/255,  35/255,  35/255, 1    };
		};
		clickSound = createSample("clickSound");
		pagesPerMode = {
			--Pg 0  Pg 1  Pg 2  Pg 3   Pg 4   Pg 5  Pg 6  Pg 7  Pg 8   Pg 9
			{ true, true, true, true,  false, true, true, true, false, false }; --Mode 1
			{ true, true, true, true,  true,  true, true, true, false, false }; --Mode 2
			{ true, true, true, true,  true,  true, true, true, false, false }; --Mode 3
			{ true, true, true, true,  false, true, true, true, true,  false }; --Mode 4
			{ true, true, true, false, false, true, true, true, false, false }; --Mode 5
			{ true, true, true, false, false, true, true, true, true,  false }; --Mode 6
			{ true, true, true, true,  false, true, true, true, false, false }; --Mode 7
			{ true, true, true, true,  false, true, true, true, false, false }; --Mode 8
			{ true, true, true, false, false, true, true, true, false, true  }; --Mode 9
		};
	};
	courseplay.hud.visibleArea = {
		x1 = courseplay.hud.infoBasePosX;
		x2 = courseplay.hud.infoBasePosX + 0.320;
		y1 = courseplay.hud.infoBasePosY;
		y2 = --[[0.30463;]] --[[0.002 + 0.271 + 32/1080 + 0.002;]] courseplay.hud.infoBasePosY + 0.271 + 32/1080 + 0.002;
	};
	courseplay.hud.visibleArea.width = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1;
	courseplay.hud.infoBaseCenter = (courseplay.hud.visibleArea.x1 + courseplay.hud.visibleArea.x2)/2;

	--print(string.format("\t\tposX=%f,posY=%f, visX1=%f,visX2=%f, visY1=%f,visY2=%f, visCenter=%f", courseplay.hud.infoBasePosX, courseplay.hud.infoBasePosY, courseplay.hud.visibleArea.x1, courseplay.hud.visibleArea.x2, courseplay.hud.visibleArea.y1, courseplay.hud.visibleArea.y2, courseplay.hud.infoBaseCenter));

	for l=1,courseplay.hud.numLines do
		if l == 1 then
			courseplay.hud.linesPosY[l] = courseplay.hud.infoBasePosY + 0.210;
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.infoBasePosY + 0.077;
		else
			courseplay.hud.linesPosY[l] = courseplay.hud.linesPosY[1] - ((l-1) * courseplay.hud.lineHeight);
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.linesBottomPosY[1] - ((l-1) * courseplay.hud.lineHeight);
		end;
		courseplay.hud.linesButtonPosY[l] = courseplay.hud.linesPosY[l] + 0.0020; --0.0045
	end;

	courseplay.hud.col2posX = {
		courseplay.hud.infoBasePosX + 0.122,
		courseplay.hud.infoBasePosX + 0.142,
		courseplay.hud.infoBasePosX + 0.122,
		courseplay.hud.infoBasePosX + 0.122,
		courseplay.hud.infoBasePosX + 0.122,
		courseplay.hud.infoBasePosX + 0.122,
		courseplay.hud.infoBasePosX + 0.182,
		courseplay.hud.infoBasePosX + 0.122,
		courseplay.hud.infoBasePosX + 0.182,
		courseplay.hud.infoBasePosX + 0.230,
	};

	courseplay.globalInfoText = {
		fontSize = 0.02,
		posX = 0.035,
		backgroundImg = "dataS2/menu/white.png",
		backgroundPadding = 0.005,
		backgroundX = 0.035 - 0.005,
		levelColors = {}
	};
	courseplay.globalInfoText.levelColors["0"]  = courseplay.hud.colors.hover;
	courseplay.globalInfoText.levelColors["1"]  = courseplay.hud.colors.activeGreen;
	courseplay.globalInfoText.levelColors["-1"] = courseplay.hud.colors.activeRed;
	courseplay.globalInfoText.levelColors["-2"] = courseplay.hud.colors.closeRed;

	loadSample(courseplay.hud.clickSound, Utils.getFilename("sounds/cpClickSound.wav", courseplay.path), false);

	courseplay.confirmedNoneTriggers = {};
	courseplay.confirmedNoneTriggersCounter = 0;

	courseplay.numAvailableDebugChannels = 16;
	courseplay.numDebugChannels = 12;
	courseplay.debugChannels = {};
	for channel=1, courseplay.numAvailableDebugChannels do
		courseplay.debugChannels[channel] = false;
	end;
	--[[
	Debug channels legend:
	 1	Raycast (drive + triggers) / TipTriggers
	 2	unload_tippers
	 3	traffic collision
	 4	Combines/mode2, register and unload combines
	 5	Multiplayer
	 6	implements (update_tools etc)
	 7	course generation
	 8	course management
	 9	path finding
	10	mode9
	11	mode7
	12	all other debugs (uncategorized)
	13	[empty]
	14	[empty]
	15	[empty]
	16	[empty]
	--]]

	courseplay.checkValues = {
		"infoText",
		"globalInfoText",
		"globalInfoTextLevel",
		"HUD0noCourseplayer",
		"HUD0wantsCourseplayer",
		"HUD0tractorName",
		"HUD0tractorForcedToStop",
		"HUD0tractor",
		"HUD0combineForcedSide",
		"HUD0isManual",
		"HUD0turnStage",
		"HUD1notDrive",
		"HUD1goOn",
		"HUD1noWaitforFill",
		"HUD4combineName",
		"HUD4hasActiveCombine",
		"HUD4savedCombine",
		"HUD4savedCombineName"
	};

	--print("\t### Courseplay: setGlobalData() finished");
end;

courseplay:initialize();

--load(), update(), updateTick(), draw() are located in base.lua
--mouseEvent(), keyEvent() are located in input.lua
