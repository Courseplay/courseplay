--
-- Courseplay
--
-- @authors: Thomas Gärtner / Satissis / Pops64 / Pvajko
-- @version: 5.00 beta
-- @website: http://courseplay.github.io/courseplay/
-- @date:    2016
-- @history: http://courseplay.github.io/courseplay/en/changelog/index.html
--
-- Copyright (C) 2014 Courseplay Dev Team
-- 

-- add steady courseplay identifier to global environment
local globalEnvironment = getfenv (0);
globalEnvironment["g_courseplay"] = globalEnvironment[g_currentModName];

---@class courseplay
courseplay = {};
courseplay.path = g_currentModDirectory;
if courseplay.path:sub(-1) ~= '/' then
	courseplay.path = courseplay.path .. '/';
end;
courseplay.modName = g_currentModName;

--- CoursePlay Input Context name for locking keys and mouse to the hud
courseplay.INPUT_CONTEXT_NAME = "COURSEPLAY_HUD";

-- initiate CpManager
local filePath = courseplay.path .. 'CpManager.lua';
assert(fileExists(filePath), ('COURSEPLAY ERROR: "CpManager.lua" can\'t be found at %q'):format(filePath));
source(filePath);

-- place sub-classes here in order to get an overview of the contents of the courseplay object and allow for sub-class functions
courseplay.utils = {};
courseplay.courses = {};
courseplay.settings = {};
courseplay.hud = {};
courseplay.buttons = {};
courseplay.fields = {};
courseplay.generation = {};
courseplay.lights = {};
courseplay.clock = 0;

local sonOfaBangSonOfaBoom = {
	['56bb4a8d3f72d5a31aee0c317302dde5'] = true; -- Thomas
	['9a9f028043394ff9de1cf6c905b515c1'] = true; -- Satis
	['3e701b6620453edcd4c170543e72788b'] = true; -- Peter
};

CpManager.isDeveloper = sonOfaBangSonOfaBoom[getMD5(g_gameSettings:getValue("nickname"))];

if CpManager.isDeveloper then
	print('Special dev magic for Courseplay developer unlocked. You go, girl!');
else
	--print('No cookies for you! (please wait until we have some limited form of a working version...)');
	--courseplay.houstonWeGotAProblem = true;
	--return;
end;

local function initialize()
	local fileList = {
		'CpObject',
		'base',
		'button',
		'bunkersilo_management',		
		'bypass',
		'combines',
		'combineUnload_management',
		'courseplay_event', 
		'course_management',
		'debug', 
		'distance', 
		'drive', 
		'fields', 
		'fruit', 
		'generateCourse',
		'helpers',
		'hud', 
		'input', 
		'inputCourseNameDialogue', 
		'mode1',
		'mode2',
		'mode3', 
		'mode4', 
		'mode6', 
		'mode8', 
		'mode10',		
		'recording', 
		'reverse',
		'settings',
		'signs', 
		'specialTools', 
		'start_stop', 
		'toolManager',
		'triggers', 
		'turn',
		'traffic',
		'TrafficCollision',
		'vehicles',
		'PurePursuitController',
		'Waypoint',
		'AIDriver',
		'GrainTransportAIDriver',
		'CombineUnloadAIDriver',
		'FieldworkAIDriver',
		'FillableFieldworkAIDriver',
		'UnloadableFieldworkAIDriver',
		'BaleLoaderAIDriver',
		'ShovelModeAIDriver',
	'course-generator/courseGenerator',
    'course-generator/CourseGeneratorScreen',
	'course-generator/CoursePlot',
    'course-generator/cp',
	'course-generator/Genetic',	
    'course-generator/track',
    'course-generator/center',
    'course-generator/headland',
    'course-generator/geo',
    'course-generator/a-star',
    'course-generator/Island',
    'course-generator/pathfinder'
	};

	local numFiles, numFilesLoaded = #(fileList) + 3, 3; -- + 3 as 'register.lua', 'courseplay.lua' and 'CpManager.lua' have already been loaded
	for _,file in ipairs(fileList) do
		local filePath = courseplay.path .. file .. '.lua';

		assert(fileExists(filePath), '\tCOURSEPLAY ERROR: could not load file ' .. filePath);
		source(filePath);
		--print('\t### Courseplay: ' .. filePath .. ' has been loaded');
		numFilesLoaded = numFilesLoaded + 1;
	end;

	print(('### Courseplay: initialized %d/%d files (v%s)'):format(numFilesLoaded, numFiles, courseplay.version));
end;

local function setVersionData()
	local modItem = g_modManager:getModByName(courseplay.modName)
	if modItem and modItem.version then
		courseplay.version = modItem.version;
	end;

	if courseplay.version then
		local versionSplitStr = StringUtil.splitString('.', courseplay.version); -- split as strings
		versionSplitStr[3] = versionSplitStr[3] or '0000';
		courseplay.versionDisplayStr = string.format('v%s.%s\n.%s', versionSplitStr[1], versionSplitStr[2], versionSplitStr[3]); --multiline display string
		courseplay.isDevVersion = tonumber(versionSplitStr[3]) > 0;
		if courseplay.isDevVersion then
			courseplay.versionDisplayStr = courseplay.versionDisplayStr .. '.dev';
		end;
		courseplay.versionFlt = tonumber(string.format('%s.%s%s', versionSplitStr[1], versionSplitStr[2], versionSplitStr[3]));
	else
		courseplay.version = ' [no version specified]';
		courseplay.versionDisplayStr = 'no\nversion';
		courseplay.versionFlt = 0.00000;
		courseplay.isDevVersion = false;
	end;
end;

local function setGlobalData()
	-- CP MODES
	courseplay.MODE_GRAIN_TRANSPORT = 1;
	courseplay.MODE_COMBI = 2;
	courseplay.MODE_OVERLOADER = 3;
	courseplay.MODE_SEED_FERTILIZE = 4;
	courseplay.MODE_TRANSPORT = 5;
	courseplay.MODE_FIELDWORK = 6;
	courseplay.MODE_COMBINE_SELF_UNLOADING = 7; --removed by Tommi
	courseplay.MODE_LIQUIDMANURE_TRANSPORT = 8;
	courseplay.MODE_SHOVEL_FILL_AND_EMPTY = 9;
	courseplay.MODE_BUNKERSILO_COMPACTER = 10;
	courseplay.NUM_MODES = 10;
	------------------------------------------------------------
	courseplay.SHOW_COVERS = true 
	

	-- "start at _ point" options
	courseplay.START_AT_NEAREST_POINT = 1;
	courseplay.START_AT_FIRST_POINT = 2;
	courseplay.START_AT_CURRENT_POINT = 3;
	courseplay.START_AT_NEXT_POINT = 4;

	-- warning lights options
	courseplay.lights.WARNING_LIGHTS_NEVER = 0;
	courseplay.lights.WARNING_LIGHTS_BEACON_ON_STREET = 1;
	courseplay.lights.WARNING_LIGHTS_BEACON_HAZARD_ON_STREET = 2;
	courseplay.lights.WARNING_LIGHTS_BEACON_ALWAYS = 3;

	courseplay.lights.HEADLIGHT_OFF = 0;
	courseplay.lights.HEADLIGHT_STREET = 1;
	courseplay.lights.HEADLIGHT_FULL = 7;
	
	-- 2D/debug lines display options
	courseplay.COURSE_2D_DISPLAY_OFF	 = 0;
	courseplay.COURSE_2D_DISPLAY_2DONLY	 = 1;
	courseplay.COURSE_2D_DISPLAY_DBGONLY = 2;
	courseplay.COURSE_2D_DISPLAY_BOTH	 = 3;

	-- number separators
	local langNumData = {
		br = { '.', ',' },
		cs = { ',', '.' },
		cz = { ' ', ',' },
		de = { "'", ',' },
		en = { ',', '.' },
		es = { '.', ',' },
		fr = { ' ', ',' },
		it = { '.', ',' },
		jp = { ',', '.' },
		pl = { ' ', ',' },
		pt = { '.', ',' },
		ru = { ' ', ',' }
	};
	courseplay.numberSeparator = '\'';
	courseplay.numberDecimalSeparator = '.';
	if g_languageShort and langNumData[g_languageShort] then
		courseplay.numberSeparator        = langNumData[g_languageShort][1];
		courseplay.numberDecimalSeparator = langNumData[g_languageShort][2];
	end;

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
		"HUD4savedCombineName"
		
	};


	--UTF8
	courseplay.allowedCharacters = courseplay:getAllowedCharacters();
	courseplay.utf8normalization = courseplay:getUtf8normalization();

	-- headland turn modes
	courseplay.HEADLAND_CORNER_TYPE_MIN = 1
	courseplay.HEADLAND_CORNER_TYPE_SMOOTH = 1
	courseplay.HEADLAND_CORNER_TYPE_SHARP = 2
	courseplay.HEADLAND_CORNER_TYPE_ROUND = 3
	courseplay.HEADLAND_CORNER_TYPE_MAX = 3

	courseplay.cornerTypeText = {
		'COURSEPLAY_HEADLAND_CORNER_TYPE_SMOOTH',
		'COURSEPLAY_HEADLAND_CORNER_TYPE_SHARP',
		'COURSEPLAY_HEADLAND_CORNER_TYPE_ROUND' }

	-- headland turn maneuver types
	courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_MIN = 1
	courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_STRAIGHT = 1
	courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_CURVE = 2
	courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_MAX = 2

	courseplay.headlandReverseManeuverTypeText = {
		'COURSEPLAY_HEADLAND_REVERSE_MANEUVER_TYPE_STRAIGHT',
		'COURSEPLAY_HEADLAND_REVERSE_MANEUVER_TYPE_CURVE' }

		
	courseplay.multiplayerSyncTable = {
	
	[1]={name='self.cp.automaticCoverHandling',dataFormat='Bool'},
	[2]={name='self.cp.automaticUnloadingOnField',dataFormat='Bool'},
	[3]={name='self.cp.mode',dataFormat='Int'},
	[4]={name='self.cp.turnDiameterAuto',dataFormat='Float'},
	[5]={name='self.cp.canDrive',dataFormat='Bool'},
	[6]={name='self.cp.combineOffsetAutoMode',dataFormat='Bool'},
	[7]={name='self.cp.combineOffset',dataFormat='Float'},
	[8]={name='self.cp.currentCourseName',dataFormat='String'},
	[9]={name='self.cp.driverPriorityUseFillLevel',dataFormat='Bool'},
	[10]={name='self.cp.drivingDirReverse',dataFormat='Bool'},
	[11]={name='self.cp.fieldEdge.customField.isCreated',dataFormat='Bool'},
	[12]={name='self.cp.fieldEdge.customField.fieldNum',dataFormat='Int'},
	[13]={name='self.cp.fieldEdge.customField.selectedFieldNumExists',dataFormat='Bool'},
	[14]={name='self.cp.fieldEdge.selectedField.fieldNum',dataFormat='Int'}, 
	[15]={name='self.cp.globalInfoTextLevel',dataFormat='Int'},
	[16]={name='self.cp.hasBaleLoader',dataFormat='Bool'},
	[17]={name='self.cp.hasStartingCorner',dataFormat='Bool'},
	[18]={name='self.cp.hasStartingDirection',dataFormat='Bool'},
	[19]={name='self.cp.hasValidCourseGenerationData',dataFormat='Bool'},
	[20]={name='self.cp.headland.numLanes',dataFormat='Int'},
	[21]={name='self.cp.headland.turnType',dataFormat='Int'},
    [22]={name='self.cp.hasUnloadingRefillingCourse	',dataFormat='Bool'},
	[23]={name='self.cp.infoText',dataFormat='String'},
	[24]={name='self.cp.returnToFirstPoint',dataFormat='Bool'},
	[25]={name='self.cp.ridgeMarkersAutomatic',dataFormat='Bool'},
	[26]={name='self.cp.shovelStopAndGo',dataFormat='Bool'},
	[27]={name='self.cp.startAtPoint',dataFormat='Int'},
	[28]={name='self.cp.stopAtEnd',dataFormat='Bool'},
	[29]={name='self.cp.isDriving',dataFormat='Bool'},
	[30]={name='self.cp.hud.openWithMouse',dataFormat='Bool'},
	[31]={name='self.cp.realisticDriving',dataFormat='Bool'},
	[32]={name='self.cp.driveOnAtFillLevel',dataFormat='Float'},
	[33]={name='self.cp.followAtFillLevel',dataFormat='Float'},
	[34]={name='self.cp.refillUntilPct',dataFormat='Float'},
	[35]={name='self.cp.tipperOffset',dataFormat='Float'},
	[36]={name='self.cp.tipperHasCover',dataFormat='Bool'},
	[37]={name='self.cp.workWidth',dataFormat='Float'}, 
	[38]={name='self.cp.turnDiameterAutoMode',dataFormat='Bool'},
	[39]={name='self.cp.turnDiameter',dataFormat='Float'},
	[40]={name='self.cp.speeds.useRecordingSpeed',dataFormat='Bool'},
	[41]={name='self.cp.coursePlayerNum',dataFormat='Int'},
	[42]={name='self.cp.laneOffset',dataFormat='Float'},
	[43]={name='self.cp.toolOffsetX',dataFormat='Float'},
	[44]={name='self.cp.toolOffsetZ',dataFormat='Float'},
	[45]={name='self.cp.loadUnloadOffsetX',dataFormat='Float'},
	[46]={name='self.cp.loadUnloadOffsetZ',dataFormat='Float'},
	[47]={name='self.cp.hud.currentPage',dataFormat='Int'},
	[48]={name='self.cp.HUD0noCourseplayer',dataFormat='Bool'},
	[49]={name='self.cp.HUD0wantsCourseplayer',dataFormat='Bool'},
	[50]={name='self.cp.HUD0combineForcedSide',dataFormat='String'},
	[51]={name='self.cp.HUD0isManual',dataFormat='Bool'},
	[52]={name='self.cp.HUD0turnStage',dataFormat='Int'},
	[53]={name='self.cp.HUD0tractorForcedToStop',dataFormat='Bool'},
	[54]={name='self.cp.HUD0tractorName',dataFormat='String'},
	[55]={name='self.cp.HUD0tractor',dataFormat='Bool'},
	[56]={name='self.cp.HUD1wait',dataFormat='Bool'},
	[57]={name='self.cp.HUD1noWaitforFill',dataFormat='Bool'},
	[58]={name='self.cp.HUD4hasActiveCombine',dataFormat='Bool'},
	[59]={name='self.cp.HUD4combineName',dataFormat='String'},
	[60]={name='self.cp.HUD4savedCombine',dataFormat='Bool'},
	[61]={name='self.cp.HUD4savedCombineName',dataFormat='String'},
	[62]={name='self.cp.waypointIndex',dataFormat='Int'},
	[63]={name='self.cp.isRecording',dataFormat='Bool'},
	[64]={name='self.cp.recordingIsPaused',dataFormat='Bool'},
	[65]={name='self.cp.searchCombineAutomatically',dataFormat='Bool'},
	[66]={name='self.cp.searchCombineOnField',dataFormat='Int'},
	[67]={name='self.cp.speeds.turn',dataFormat='Float'},
	[68]={name='self.cp.speeds.field',dataFormat='Float'},
	[69]={name='self.cp.speeds.reverse',dataFormat='Float'},
	[70]={name='self.cp.speeds.street',dataFormat='Float'},
	[71]={name='self.cp.visualWaypointsStartEnd',dataFormat='Bool'},
	[72]={name='self.cp.visualWaypointsAll',dataFormat='Bool'},
	[73]={name='self.cp.visualWaypointsCrossing',dataFormat='Bool'},
	[74]={name='self.cp.warningLightsMode',dataFormat='Int'},
	[75]={name='self.cp.waitTime',dataFormat='Int'},
	[76]={name='self.cp.symmetricLaneChange',dataFormat='Bool'},
	[77]={name='self.cp.startingCorner',dataFormat='Int'},
	[78]={name='self.cp.startingDirection',dataFormat='Int'},
	[79]={name='self.cp.hasShovelStatePositions[2]',dataFormat='Bool'},
	[80]={name='self.cp.hasShovelStatePositions[3]',dataFormat='Bool'},
	[81]={name='self.cp.hasShovelStatePositions[4]',dataFormat='Bool'},
	[82]={name='self.cp.hasShovelStatePositions[5]',dataFormat='Bool'}, 
	[83]={name='self.cp.multiTools',dataFormat='Int'},
	[84]={name='self.cp.convoyActive',dataFormat='Bool'},
	[85]={name='self.cp.alignment.enabled',dataFormat='Bool'},
	[86]={name='self.cp.hasSowingMachine',dataFormat='Bool'},
	[87]={name='self.cp.generationPosition.fieldNum',dataFormat='Int'},
	[87]={name='self.cp.generationPosition.hasSavedPosition',dataFormat='Bool'},
	[88]={name='self.cp.generationPosition.x',dataFormat='Float'},
	[89]={name='self.cp.generationPosition.z',dataFormat='Float'},
	[90]={name='self.cp.fertilizerEnabled',dataFormat='Bool'},
	[91]={name='self.cp.turnOnField',dataFormat='Bool'}
	}	

	--print("\t### Courseplay: setGlobalData() finished");
end;


--------------------------------------------------------------


setVersionData();

initialize();

courseplay.inputBindings.updateInputButtonData();

setGlobalData();


if courseplay.isDevVersion then
	local maxLength = 91;
	local s = {
		('%-' .. maxLength .. 's'):format('You are using a development version of Courseplay, which may and will contain errors, bugs,');
		('%-' .. maxLength .. 's'):format('mistakes and unfinished code. Chances are your computer will explode when using it. Twice.');
		('%-' .. maxLength .. 's'):format('If you have no idea what "beta", "alpha", or "developer" means and entails, remove this');
		('%-' .. maxLength .. 's'):format('version of Courseplay immediately. The Courseplay team will not take any responsibility for');
		('%-' .. maxLength .. 's'):format('crop destroyed, savegames deleted or baby pandas killed.');
	};
	print('    ' .. ('*'):rep((maxLength - 5) * 0.5) .. ' WARNING ' .. ('*'):rep((maxLength - 5) * 0.5) .. '\n    * ' .. table.concat(s, ' *\n    * ') .. ' *\n    ' .. ('*'):rep(maxLength + 4));
end;


--load(), update(), updateTick(), draw() are located in base.lua
--mouseEvent(), keyEvent() are located in input.lua
