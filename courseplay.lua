--
-- Courseplay
-- Specialization for Courseplay
--
-- @author  	Lautschreier / Hummel / Wolverin0815 / Bastian82 / skydancer / Jakob Tischler / Thomas Gärtner
-- @version:	v3.41

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
	courseplay.numAiModes = 9;
	courseplay.hud = {
		infoBasePosX = 0.433;
		infoBasePosY = 0.002;
		infoBaseWidth = 0.512; --try: 512/1920
		infoBaseHeight = 0.512; --try: 512/1080
		infoBaseCenter = 0.433 + 0.16;
		visibleArea = {
			x1 = 0.433;
			x2 = 0.753;
			y1 = 0.002;
			y2 = 0.30463; --0.002 + 0.271 + 32/1080 + 0.002;
		};
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

	courseplay.numDebugChannels = 12;
	courseplay.debugChannels = {};
	for channel=1, courseplay.numDebugChannels do
		courseplay.debugChannels[channel] = false;
	end;
	--[[
	Debug channels legend:
	1  	Raycast (drive + triggers) / TipTriggers
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
	}

	--print("\t### Courseplay: setGlobalData() finished");
end;

courseplay:initialize();

