--
-- Courseplay
--
-- @authors: Thomas Gärtner / Satissis
-- @version: 5.00 beta
-- @website: http://courseplay.github.io/courseplay/
-- @date:    2016
-- @history: http://courseplay.github.io/courseplay/en/changelog/index.html
--
-- Copyright (C) 2014 Courseplay Dev Team
-- 

courseplay = {};
courseplay.path = g_currentModDirectory;
if courseplay.path:sub(-1) ~= '/' then
	courseplay.path = courseplay.path .. '/';
end;
courseplay.modName = g_currentModName;

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
courseplay.clock = 0;

local sonOfaBangSonOfaBoom = {
	['56bb4a8d3f72d5a31aee0c317302dde5'] = true; -- Thomas
	['9a9f028043394ff9de1cf6c905b515c1'] = true; -- Satis
	['c8029c5126f522ec8839ec30fcabc22e'] = true; -- sKyDaNcEr
	['06475174d922e7dcbb3ed34c0236dbdf'] = true; -- Justin
	['b74ad095badc54d4334039f2f73f240e'] = true; -- Pops64
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
		'base',
		'button', 
		'bypass',
		'combines', 
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
		'mode7', 
		'mode8', 
		'mode9',
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
		'vehicles',
    'course-generator/courseGenerator',
    'course-generator/cp',
    'course-generator/track',
    'course-generator/center',
    'course-generator/headland',
    'course-generator/geo',
    'course-generator/bspline',
    'course-generator/file',
    'course-generator/a-star',
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
	local modItem = ModsUtil.findModItemByModName(courseplay.modName);
	if modItem and modItem.version then
		courseplay.version = modItem.version;
	end;

	if courseplay.version then
		local versionSplitStr = Utils.splitString('.', courseplay.version); -- split as strings
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
	courseplay.MODE_COMBINE_SELF_UNLOADING = 7;
	courseplay.MODE_LIQUIDMANURE_TRANSPORT = 8;
	courseplay.MODE_SHOVEL_FILL_AND_EMPTY = 9;
	courseplay.MODE_BUNKERSILO_COMPACTER = 10;
	courseplay.NUM_MODES = 10;
	------------------------------------------------------------


	-- "start at _ point" options
	courseplay.START_AT_NEAREST_POINT = 1;
	courseplay.START_AT_FIRST_POINT = 2;
	courseplay.START_AT_CURRENT_POINT = 3;

	-- warning lights options
	courseplay.WARNING_LIGHTS_NEVER = 0;
	courseplay.WARNING_LIGHTS_BEACON_ON_STREET = 1;
	courseplay.WARNING_LIGHTS_BEACON_HAZARD_ON_STREET = 2;
	courseplay.WARNING_LIGHTS_BEACON_ALWAYS = 3;

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
	--[[
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
		
	};]]


	--UTF8
	courseplay.allowedCharacters = courseplay:getAllowedCharacters();
	courseplay.utf8normalization = courseplay:getUtf8normalization();


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
