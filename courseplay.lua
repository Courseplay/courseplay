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
---@class courseplay.fields
courseplay.fields = {};
courseplay.generation = {};
courseplay.lights = {};
courseplay.clock = 0;

local function initialize()
	local fileList = {
		'CpObject',
		'DevHelper',
		'CpManager',
		'base',
		'button',
		'BunkersiloManager',
		'courseplay_event',
		'course_management',
    	'courseeditor',
    	'CourseEditorEvent',
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
		'GlobalSettings',
		'ValidModeSetupHandler',
		'signs', 
		'specialTools', 
		'start_stop', 
		'toolManager',
		'triggers', 
		'turn',
		'TrafficCollision',
		'ProximitySensor',
		'vehicles',
		'AIDriverUtil',
		'PurePursuitController',
		'Waypoint',
		'StateModule',
		'TriggerHandler',
		'TriggerSensor',
		'BaleToCollect',
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
		'BaleCollectorAIDriver',
		'BalerAIDriver',
		'BaleWrapperAIDriver',
		'CombineAIDriver',
		'BunkerSiloAIDriver',
		'CompactingAIDriver',
		'ShieldAIDriver',
		'ShovelAIDriver',
		'TriggerShovelAIDriver',
		'BunkerSiloLoaderAIDriver',
		'MixerWagonAIDriver',
		'Conflict',
		'AITurn',
		'VehicleConfigurations',
		'ActionEventsLoader',
		'GlobalInfoTextHandler',
		'course-generator/geo',
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
		'course-generator/CourseGeneratorSettings',
		'gui/CpGuiUtil',
		'gui/CourseGeneratorScreen',
		'gui/CoursePlot',
		'gui/inputCourseNameDialogue',
		'gui/AdvancedSettingsScreen',
		'gui/GlobalSettingsPage',
		'gui/VehicleSettingsPage',
		'Events/SettingEvent',
		'Events/StartStopEvent',
		'Events/UnloaderEvents',
		'Events/SiloSelectedFillTypeEvent',
		'Events/StartStopWorkEvent',
		'Events/AssignedCombinesEvents',
		'Events/CourseEvent',
		'Events/InfoTextEvent',
		'Events/CommandEvents',
		'Events/CustomFieldEvent',
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
		courseplay.version = modItem.version
		courseplay.versionDisplayStr = string.format("v%s",courseplay.version)
	else
		courseplay.version = ' [no version specified]'
		courseplay.versionDisplayStr = 'no\nversion'
	end
end

local function setGlobalData()
	courseplay.MODE_GRAIN_TRANSPORT = 1;
	courseplay.MODE_COMBI = 2;
	courseplay.MODE_OVERLOADER = 3;
	courseplay.MODE_SEED_FERTILIZE = 4;
	courseplay.MODE_TRANSPORT = 5;
	courseplay.MODE_FIELDWORK = 6;
	courseplay.MODE_BALE_COLLECTOR = 7;
	courseplay.MODE_FIELD_SUPPLY = 8;
	courseplay.MODE_SHOVEL_FILL_AND_EMPTY = 9;
	courseplay.MODE_BUNKERSILO_COMPACTER = 10;
	courseplay.NUM_MODES = 10;
	courseplay.MODE_DEFAULT = courseplay.MODE_TRANSPORT
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

	courseplay.multiplayerSyncTable = {

	[1]={name='self.cp.canDrive',dataFormat='Bool'},
	[2]={name='self.cp.drivingDirReverse',dataFormat='Bool'},
	[3]={name='self.cp.isDriving',dataFormat='Bool'},
	[4]={name='self.cp.hud.openWithMouse',dataFormat='Bool'},
	[5]={name='self.cp.coursePlayerNum',dataFormat='Int'}, --??
	[6]={name='self.cp.hud.currentPage',dataFormat='Int'},
	[7]={name='self.cp.waypointIndex',dataFormat='Int'},
	[8]={name='self.cp.isRecording',dataFormat='Bool'},
	[9]={name='self.cp.recordingIsPaused',dataFormat='Bool'},
	}
	---@type SettingsContainer
	courseplay.globalSettings = SettingsContainer.createGlobalSettings()
	---@type SettingsContainer
	courseplay.globalCourseGeneratorSettings = SettingsContainer.createGlobalCourseGeneratorSettings()
	---@type SettingsContainer
	courseplay.globalPathfinderSettings = SettingsContainer.createGlobalPathfinderSettings()
end;


--------------------------------------------------------------

setVersionData();

initialize();


courseplay.inputBindings.updateInputButtonData();

setGlobalData();


local function displayDevWaring()
	local maxLength = 91;
	local s = {
		('%-' .. maxLength .. 's'):format('You are using a development version of Courseplay, which may and will contain errors, bugs,');
		('%-' .. maxLength .. 's'):format('mistakes and unfinished code. Chances are your computer will explode when using it. Twice.');
		('%-' .. maxLength .. 's'):format('If you have no idea what "beta", "alpha", or "developer" means and entails, remove this');
		('%-' .. maxLength .. 's'):format('version of Courseplay immediately. The Courseplay team will not take any responsibility for');
		('%-' .. maxLength .. 's'):format('crop destroyed, savegames deleted or baby pandas killed.');
	};
	print('    ' .. ('*'):rep((maxLength - 5) * 0.5) .. ' WARNING ' .. ('*'):rep((maxLength - 5) * 0.5) .. '\n    * ' .. table.concat(s, ' *\n    * ') .. ' *\n    ' .. ('*'):rep(maxLength + 4));
end

displayDevWaring()


--load(), update(), updateTick(), draw() are located in base.lua
--mouseEvent(), keyEvent() are located in input.lua
