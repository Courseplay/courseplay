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

-- place sub-classes here in order to get an overview of the contents of the courseplay object and allow for sub-class functions
courseplay.utils = {};
---@class courseplay.courses
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
	['0d8e45a8ed916c1cd40820165b81e12d'] = true; -- Tensuko
	['97c8e6d0d14f4e242c3c37af68cc376c'] = true; -- Dan
	['8f5e9e8fb5a23375afbb3b7abbc6335c'] = true; -- Goof
};

local function initialize()
	local fileList = {
		'CpObject',
		'DevHelper',
		'CpManager',
		'base',
		'button',
		'bunkersilo_management',
		'BunkersiloManager',
		'courseplay_event',
		'course_management',
    	'courseeditor',
    	'clicktoswitch',
		'debug', 
		'distance', 
		'fields',
		'fruit', 
		'helpers',
		'hud', 
		'input', 
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
		'ProximitySensor',
		'vehicles',
		'PurePursuitController',
		'Waypoint',
		'TriggerHandler',
		'AIDriver',
		'CombineUnloadAIDriver',
		'OverloaderAIDriver',
		'CombineUnloadManager',
		'GrainTransportAIDriver',
		'FieldworkAIDriver',
		'FillableFieldworkAIDriver',
		'FieldSupplyAIDriver',
		'PlowAIDriver',
		'UnloadableFieldworkAIDriver',
		'BaleLoaderAIDriver',
		'BalerAIDriver',
		'BaleWrapperAIDriver',
		'CombineAIDriver',
		'LevelCompactAIDriver',
		'ShovelModeAIDriver',
		'TrafficController',
		'TrafficControllerSolver',
		'AITurn',
		'course-generator/geo',
		'course-generator/Pathfinder',
		'course-generator/Island',
		'course-generator/courseGenerator',
		'course-generator/cp',
		'course-generator/Genetic',
		'course-generator/track',
		'course-generator/center',
		'course-generator/headland',
		'course-generator/Vector',
		'course-generator/State3D',
		'course-generator/BinaryHeap',
		'course-generator/Dubins',
		'course-generator/HybridAStar',
		'course-generator/ReedsShepp',
		'course-generator/ReedsSheppSolver',
		'course-generator/PathfinderUtil',
		'gui/CourseGeneratorScreen',
		'gui/CoursePlot',
		'gui/inputCourseNameDialogue',
		'gui/AdvancedSettingsScreen',
		'gui/GlobalSettingsPage',
		'gui/VehicleSettingsPage',
		'Events/StartStopEvent',
		'Events/UnloaderEvents',
		'Events/SiloSelectedFillTypeEvent',
		'Events/StartStopWorkEvent',
		'Events/SettingsListEvent',
		'Events/AssignedCombinesEvents',
		'Events/CourseEvent',
		'Events/InfoTextEvent',
		'Generic/LinkedList'
	};

	local numFiles, numFilesLoaded = #(fileList) + 2, 2; -- + 2 as 'register.lua', 'courseplay.lua' have already been loaded
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
	courseplay.MODE_FIELD_SUPPLY = 8;
	courseplay.MODE_SHOVEL_FILL_AND_EMPTY = 9;
	courseplay.MODE_BUNKERSILO_COMPACTER = 10;
	courseplay.NUM_MODES = 10;
	------------------------------------------------------------
	courseplay.SHOW_COVERS = true
	courseplay.OPEN_COVERS = false
	courseplay.CLOSE_COVERS = true

	courseplay.RIDGEMARKER_NONE = 0
	courseplay.RIDGEMARKER_LEFT = 1
	courseplay.RIDGEMARKER_RIGHT = 2

	-- "start at _ point" options
	StartingPointSetting.START_AT_NEAREST_POINT = 1;
	StartingPointSetting.START_AT_FIRST_POINT = 2;
	StartingPointSetting.START_AT_CURRENT_POINT = 3;
	StartingPointSetting.START_AT_NEXT_POINT = 4;

	-- lights options
	-- this should have a Setting Class like WarningLightsModeSetting
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

	[1]={name='self.cp.mode',dataFormat='Int'},
	[2]={name='self.cp.turnDiameterAuto',dataFormat='Float'},
	[3]={name='self.cp.canDrive',dataFormat='Bool'},
	[4]={name='self.cp.combineOffsetAutoMode',dataFormat='Bool'},
	[5]={name='self.cp.combineOffset',dataFormat='Float'},
	[6]={name='self.cp.currentCourseName',dataFormat='String'},
	[7]={name='self.cp.drivingDirReverse',dataFormat='Bool'},
	[8]={name='self.cp.fieldEdge.customField.isCreated',dataFormat='Bool'},
	[9]={name='self.cp.fieldEdge.customField.fieldNum',dataFormat='Int'},
	[10]={name='self.cp.fieldEdge.customField.selectedFieldNumExists',dataFormat='Bool'},
	[11]={name='self.cp.fieldEdge.selectedField.fieldNum',dataFormat='Int'},
	[12]={name='self.cp.globalInfoTextLevel',dataFormat='Int'},
	[13]={name='self.cp.hasBaleLoader',dataFormat='Bool'},
	[14]={name='self.cp.hasStartingCorner',dataFormat='Bool'},
	[15]={name='self.cp.hasStartingDirection',dataFormat='Bool'},
	[16]={name='self.cp.hasValidCourseGenerationData',dataFormat='Bool'},
	[17]={name='self.cp.headland.numLanes',dataFormat='Int'},
	[18]={name='self.cp.headland.turnType',dataFormat='Int'},
    [19]={name='self.cp.hasUnloadingRefillingCourse	',dataFormat='Bool'},
	[20]={name='self.cp.infoText',dataFormat='String'},
	[21]={name='self.cp.shovelStopAndGo',dataFormat='Bool'},
	[22]={name='self.cp.isDriving',dataFormat='Bool'},
	[23]={name='self.cp.hud.openWithMouse',dataFormat='Bool'},
	[24]={name='self.cp.tipperOffset',dataFormat='Float'},
	[25]={name='self.cp.tipperHasCover',dataFormat='Bool'},
	[26]={name='self.cp.workWidth',dataFormat='Float'},
	[27]={name='self.cp.turnDiameterAutoMode',dataFormat='Bool'},
	[28]={name='self.cp.turnDiameter',dataFormat='Float'},
	[29]={name='self.cp.coursePlayerNum',dataFormat='Int'},
	[30]={name='self.cp.laneOffset',dataFormat='Float'},
	[31]={name='self.cp.toolOffsetX',dataFormat='Float'},
	[32]={name='self.cp.toolOffsetZ',dataFormat='Float'},
	[33]={name='self.cp.loadUnloadOffsetX',dataFormat='Float'},
	[34]={name='self.cp.loadUnloadOffsetZ',dataFormat='Float'},
	[35]={name='self.cp.hud.currentPage',dataFormat='Int'},
	[36]={name='self.cp.waypointIndex',dataFormat='Int'},
	[37]={name='self.cp.isRecording',dataFormat='Bool'},
	[38]={name='self.cp.recordingIsPaused',dataFormat='Bool'},
	[39]={name='self.cp.searchCombineAutomatically',dataFormat='Bool'},
	[40]={name='self.cp.searchCombineOnField',dataFormat='Int'},
	[41]={name='self.cp.speeds.turn',dataFormat='Float'},
	[42]={name='self.cp.speeds.field',dataFormat='Float'},
	[43]={name='self.cp.speeds.reverse',dataFormat='Float'},
	[44]={name='self.cp.speeds.street',dataFormat='Float'},
	[45]={name='self.cp.waitTime',dataFormat='Int'},
	[46]={name='self.cp.hasShovelStatePositions[2]',dataFormat='Bool'},
	[47]={name='self.cp.hasShovelStatePositions[3]',dataFormat='Bool'},
	[48]={name='self.cp.hasShovelStatePositions[4]',dataFormat='Bool'},
	[49]={name='self.cp.hasShovelStatePositions[5]',dataFormat='Bool'},
	[50]={name='self.cp.multiTools',dataFormat='Int'},
	[51]={name='self.cp.convoyActive',dataFormat='Bool'},
	[52]={name='self.cp.alignment.enabled',dataFormat='Bool'},
	[53]={name='self.cp.hasSowingMachine',dataFormat='Bool'},
	[54]={name='self.cp.generationPosition.fieldNum',dataFormat='Int'},
	[55]={name='self.cp.generationPosition.hasSavedPosition',dataFormat='Bool'},
	[56]={name='self.cp.generationPosition.x',dataFormat='Float'},
	[57]={name='self.cp.generationPosition.z',dataFormat='Float'}
	}
	
	-- TODO: see where is the best to instantiate these settings. Maybe we need a container for all these
	courseplay.globalSettings = SettingsContainer("globalSettings")
	courseplay.globalSettings:addSetting(LoadCoursesAtStartupSetting)
	courseplay.globalSettings:addSetting(AutoFieldScanSetting)
	courseplay.globalSettings:addSetting(EarnWagesSetting)
	courseplay.globalSettings:addSetting(WorkerWages)
	courseplay.globalSettings:addSetting(ClickToSwitchSetting)
	courseplay.globalSettings:addSetting(ShowMiniHud)
	courseplay.globalSettings:addSetting(EnableOpenHudWithMouseGlobal)

	courseplay.globalCourseGeneratorSettings = SettingsContainer.createGlobalCourseGeneratorSettings()
	courseplay.globalPathfinderSettings = SettingsContainer.createGlobalPathfinderSettings()

	--print("\t### Courseplay: setGlobalData() finished");
end;


--------------------------------------------------------------

setVersionData();

initialize();

CpManager.isDeveloper = sonOfaBangSonOfaBoom[getMD5(g_gameSettings:getValue("nickname"))];

if CpManager.isDeveloper then
	print('Special dev magic for Courseplay developer unlocked. You go, girl!');
else
	--print('No cookies for you! (please wait until we have some limited form of a working version...)');
	--courseplay.houstonWeGotAProblem = true;
	--return;
end;

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
