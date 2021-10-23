local curFile = 'CpManager.lua';
CpManager = {};
local CpManager_mt = Class(CpManager);
addModEventListener(CpManager);

local modDirectory = g_currentModDirectory

--- Setups dev settings.
local function loadDevSetup()
	local filePath = Utils.getFilename('config/DevSetup.xml', courseplay.path)
	local xmlFile = loadXMLFile('devSetup', filePath)
	local baseKey = "DevSetup"
	CpManager.preDebugSetup = {
		nameToChannel = {},
		idToChannel = {}
	}
	CpManager.isDeveloper = false
	if xmlFile then 
		CpManager.isDeveloper = Utils.getNoNil(getXMLBool(xmlFile,baseKey.."#isDev"),false)
		if CpManager.isDeveloper then 
			print('Special dev magic for Courseplay developer unlocked. You go, girl!');
		end

		--- Checks if any debug channel should be active immediately.
		baseKey = string.format("%s.%s",baseKey,"DebugChannels") 
		if hasXMLProperty(xmlFile, baseKey) then 
			CpManager.preDebugSetup = {
				nameToChannel = {},
				idToChannel = {}
			}
			local i = 0
			while true do 
				local key = string.format("%s.%s(%d)",baseKey,"DebugChannel",i)
				if not hasXMLProperty(xmlFile, key) then
					break
				end
				local id = getXMLInt(xmlFile, key.."#id")
				local name = getXMLString(xmlFile, key.."#name")
				local active = getXMLBool(xmlFile, key)
				if id then 
					CpManager.preDebugSetup.idToChannel[id] = active
				end
				if name then 
					CpManager.preDebugSetup.nameToChannel[name] = active
				end
				i = i + 1
				if active then
					print(string.format("Debug channel id: %s, name: %s is activated for dev.",tostring(id),tostring(name)))
				end
			end
		end
		delete(xmlFile)
	end
end
loadDevSetup()

function CpManager:loadMap(name)
	--print("CpManager:loadMap(name)")
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

		-- Course save path
		self.cpCoursesFolderPath = ("%s%s/%s"):format(getUserProfileAppPath(),"CoursePlay_Courses", g_currentMission.missionInfo.mapId);
		self.cpCourseManagerXmlFilePath = self.cpCoursesFolderPath .. "/courseManager.xml";
		self.cpCourseStorageXmlFileTemplate = "courseStorage%04d.xml";
		self.cpDebugPrintXmlFolderPath = string.format("%s%s",getUserProfileAppPath(),"courseplayDebugPrint")
		self.cpDebugPrintXmlFilePathDefault = string.format("%s/%s",self.cpDebugPrintXmlFolderPath,"courseplayDebugPrint.xml")
		createFolder(self.cpDebugPrintXmlFolderPath)

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
	self:setup2dCourseData(false); -- NOTE: this call is only to initiate the position and opacity

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- LOAD SETTINGS FROM COURSEPLAYSETTINGS.XML / SAVE DEFAULT SETTINGS IF NOT EXISTING
	if g_server ~= nil then
		self:loadXmlSettings();
		g_vehicleConfigurations:loadFromXml()
	end
	---Load action event configurations. Every client/server has to load them.
	g_ActionEventsLoader:loadFromXml()
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- SETUP (continued)
	courseplay.hud:setup(); -- NOTE: hud has to be set up after the xml settings have been loaded, as almost all its values are based on basePosX/Y
	g_globalInfoTextHandler:setup() -- NOTE: globalInfoText has to be set up after the hud, as they rely on some hud values [colors, function]
	courseplay.courses:setup(); -- NOTE: load the courses and folders from the XML
	self:setup2dCourseData(true); -- NOTE: setup2dCourseData is called a second time, now we actually create the data and overlays
	courseplay:register(true)-- NOTE: running here again to check whether there were mods loaded after courseplay
	
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- COURSEPLAYERS TABLES
	self.totalCoursePlayers = {};
	self.activeCoursePlayers = {};
	self.numActiveCoursePlayers = 0;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- height for mouse text line in game's help menu DISABLED HUD issue
	--self.hudHelpMouseLineHeight = g_currentMission.helpBoxTextSize + g_currentMission.helpBoxTextLineSpacing*2;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- INPUT
	local ovl = courseplay.inputBindings.mouse.overlaySecondary;
	if ovl then
		local h = (2.5 * g_currentMission.helpBoxTextSize);
		local w = h / g_screenAspectRatio;
		ovl:setDimension(w, h);
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- FIELDS
	if courseplay.globalSettings.autoFieldScan:is(true) then
		self:setupFieldScanInfo();
	end;
	if g_server ~= nil then
		courseplay.fields:loadCustomFields();
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- TIMERS
	g_currentMission.environment:addMinuteChangeListener(self);
	self.realTimeMinuteTimer = 0;
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
	addConsoleCommand( 'print', 'Print a variable', 'printVariable', self )
	addConsoleCommand( 'printGlobalCpVariable', 'Print a global cp variable', 'printGlobalCpVariable', self )
	addConsoleCommand( 'printVehicleVariable', 'Print g_currentMission.controlledVehicle.variable', 'printVehicleVariable', self )
	addConsoleCommand( 'printDriverVariable', 'Print g_currentMission.controlledVehicle.cp.driver.variable', 'printDriverVariable', self )
	addConsoleCommand( 'printSettingVariable', 'Print g_currentMission.controlledVehicle.cp.settings.variable', 'printSettingVariable', self )
	addConsoleCommand( 'printCourseGeneratorSettingVariable', 'Print g_currentMission.controlledVehicle.cp.courseGeneratorSettings.variable', 'printCourseGeneratorSettingVariable', self )
	addConsoleCommand( 'printGlobalSettingVariable', 'Print g_currentMission.controlledVehicle.cp.globalSettings.variable', 'printGlobalSettingVariable', self )
	addConsoleCommand( 'cpTraceOn', 'Turn on function call argument tracing', 'traceOn', self )
	addConsoleCommand( 'cpTraceOnForAll', 'Turn on call argument tracing for all functions of the given table (lots of output)', 'traceOnForAll', self )
	addConsoleCommand( 'cpLoadFile', 'Load a lua file', 'loadFile', self )
	addConsoleCommand( 'cpLoadAIDriver', 'Load a lua file and re-instantiate the current AIDriver', 'loadAIDriver', self )

	addConsoleCommand( 'cpRestoreVehiclePositions', 'Restore all saved vehicle positions', 'restoreVehiclePositions', self )
	addConsoleCommand( 'cpSaveVehiclePositions', 'Save position of all vehicles', 'saveVehiclePositions', self )

	addConsoleCommand( 'cpRestartSaveGame', 'Load and start a savegame', 'restartSaveGame', self )
	addConsoleCommand( 'cpSetLookaheadDistance', 'Set look ahead distance for the pure pursuit controller', 'setLookaheadDistance', self )
	addConsoleCommand( 'cpCallVehicleFunction', 'Call a function on the current vehicle and print the results', 'callVehicleFunction', self )
	addConsoleCommand( 'cpSetPathfindingDebug', 'Set pathfinding visual debug level (0-2)', 'setPathfindingDebug', self )
	addConsoleCommand( 'cpToggleDevhelperDebug', 'Toggle development helper visual debug info', 'toggleDevhelperDebug', self )
	addConsoleCommand( 'cpShowCombineUnloadManagerStatus', 'Show combine unload manager status', 'showCombineUnloadManagerStatus', self )
	addConsoleCommand( 'cpReadVehicleConfigurations', 'Read custom vehicle configurations', 'loadFromXml', g_vehicleConfigurations)
	
	addConsoleCommand( 'cpCreateVehicleDebugSparseHook', 'Create a debug Sparse Hook', 'createVehicleVariableDebugSparseHook', self)
	addConsoleCommand( 'cpUpgradeAllCourses', 'Upgrade all courses to the new (faster) format', 'upgradeAllCourses', courseplay.courses)


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
	self.validModeSetupHandler = ValidModeSetupHandler()
end;

function CpManager:deleteMap()
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- empty courses and folders tables
	g_currentMission.cp_courses = nil;
	g_currentMission.cp_folders = nil;
	g_currentMission.cp_sorted = nil;
	courseplay.courses.batchWriteSize = nil;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	if courseplay.debugChannels then
		-- deactivate debug channels
		for channel,_ in pairs(courseplay.debugChannels) do
			courseplay.debugChannels[channel] = false;
		end;
	end
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete vehicles' button overlays
	for i,vehicle in pairs(g_currentMission.vehicles) do
		if vehicle.cp ~= nil and vehicle.hasCourseplaySpec and vehicle.cp.buttons ~= nil then
			courseplay.buttons:deleteButtonOverlays(vehicle);
		end;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	g_globalInfoTextHandler:delete()
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete waypoint signs and protoTypes
	for section,signDatas in pairs(courseplay.signs.buffer) do
		for k,signData in pairs(signDatas) do
			courseplay.signs:deleteSign(signData.sign);
		end;
		courseplay.signs.buffer[section] = {};
	end;

	for _,itemNode in pairs(courseplay.signs.protoTypes) do
		courseplay.signs:deleteSign(itemNode);
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- delete fields data and overlays
	---@class courseplay.fields.fieldData
	courseplay.fields.fieldData = {};
	courseplay.fields.curFieldScanIndex = 0;
	courseplay.fields.allFieldsScanned = false;
	courseplay.fields.ingameDataSetUp = false;

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
  --print("CpManager:update(dt)")
  -- UPDATE CLOCK
  courseplay.clock = courseplay.clock + dt

	if g_currentMission.paused or (g_gui.currentGui ~= nil and g_gui.currentGuiName ~= 'inputCourseNameDialogue') then
		return;
	end;

	if self.firstRun then
		courseplay:addCpNilTempFillLevelFunction();
		self.firstRun = false;
		courseplay.fields.fieldDefinitionBase = g_fieldManager:getFields()
		--print(tableShow(courseplay.fields.fieldDefinitionBase,"courseplay.fields.fieldDefinitionBase",nil,nil,4))
		
	end;

	if courseplay.fieldMod == nil then
		courseplay:initailzeFieldMod()
	end

	if g_gui.currentGui == nil then
		-- SETUP FIELD INGAME DATA
		if not courseplay.fields.ingameDataSetUp then
			courseplay.fields:setUpFieldsIngameData();
		end;

		-- SCAN ALL FIELD EDGES
		if self.startFieldScanAfter > 0 then
			self.startFieldScanAfter = self.startFieldScanAfter - dt;
		end;
		
		if courseplay.fieldMod == nil then 
			courseplay:initailzeFieldMod()
		end	
		
		if courseplay.fields.fieldDefinitionBase and courseplay.globalSettings.autoFieldScan:is(true) and not courseplay.fields.allFieldsScanned and self.startFieldScanAfter <= 0 then
			courseplay.fields:setAllFieldEdges();
		end;

		-- Field scan yes/no dialogue
		if self.showFieldScanYesNoDialogue then
			self:showYesNoDialogue('Courseplay', courseplay:loc('COURSEPLAY_YES_NO_FIELDSCAN'), self.fieldScanDialogueCallback);
		end;
	end;
	TrafficConflictDetector.drawAllDebugInfo()
	g_combineUnloadManager:onUpdate(dt)

	-- REAL TIME 5 SECS CHANGER
	if self.realTime5SecsTimer < 5000 then
		self.realTime5SecsTimer = self.realTime5SecsTimer + dt;
		self.realTime5SecsTimerThrough = false;
	else
		self.realTime5SecsTimer = self.realTime5SecsTimer - 5000;
		self.realTime5SecsTimerThrough = true;
	end;

	if not courseplay.fields.modifier then
		courseplay.fields.modifier = DensityMapModifier:new(g_currentMission.terrainDetailId, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels) -- terrain type modifier
		courseplay.fields.filter = DensityMapFilter:new(courseplay.fields.modifier) -- filter on terrain type
		courseplay.fields.filter:setValueCompareParams("greater", 0) -- more than 0, so it is a field
	end
	g_devHelper:update()
	self:printVariableDebugSparseHook()
end;


function CpManager:UpdateTick(dt)
	print("CpManager:updateTick(dt)")
end




function CpManager:draw()
	if g_currentMission.paused then
		return;
	end;

	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- DISPLAY GLOBALINFOTEXTS
	g_globalInfoTextHandler:render()
	
	-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	-- DISPLAY FIELD SCAN MSG
	if courseplay.fields.fieldDefinitionBase and courseplay.globalSettings.autoFieldScan:is(true) and not courseplay.fields.allFieldsScanned and self.startFieldScanAfter <= 0 then
		self:renderFieldScanInfo();
	end;

	g_devHelper:draw()
end;

function CpManager:mouseEvent(posX, posY, isDown, isUp, mouseKey)
	-- if the game is paused or a gui is open (e.g. Shop or Landscaping) then ignore the input
	if g_currentMission.paused or g_gui.currentGui~= nil then return; end;

	--print(string.format('CpManager:mouseEvent(posX(%s), posY(%s), isDown(%s), isUp(%s), mouseKey(%s))',
	--tostring(posX),tostring(posY),tostring(isDown),tostring(isUp),tostring(mouseKey) ))
	
	courseplay:onMouseEvent(posX, posY, isDown, isUp, mouseKey)

	g_globalInfoTextHandler:mouseEvent(posX, posY, isDown, isUp, mouseKey)

	g_devHelper:mouseEvent(posX, posY, isDown, isUp, mouseKey)
end;

function CpManager:keyEvent(unicode, sym, modifier, isDown) 
	courseplay:onKeyEvent(unicode, sym, modifier, isDown)
	g_devHelper:keyEvent(unicode, sym, modifier, isDown)
end;

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
		setXMLBool(cpSettingsXml, key .. '#onlyScanOwnedFields',		courseplay.fields.onlyScanOwnedFields);
		setXMLBool(cpSettingsXml, key .. '#debugScannedFields',			courseplay.fields.debugScannedFields);
		setXMLBool(cpSettingsXml, key .. '#debugCustomLoadedFields',	courseplay.fields.debugCustomLoadedFields);
		setXMLInt (cpSettingsXml, key .. '#scanStep',					courseplay.fields.scanStep);

	

		-- Save 2D Course Settings
		key = 'CPSettings.course2D';
		setXMLFloat(cpSettingsXml, key .. '#posX', 		CpManager.course2dPlotPosX);
		setXMLFloat(cpSettingsXml, key .. '#posY', 		CpManager.course2dPlotPosY);
		setXMLFloat(cpSettingsXml, key .. '#opacity',	CpManager.course2dPdaMapOpacity);

		courseplay.globalSettings:saveToXML(cpSettingsXml, 'CPSettings')
		courseplay.globalCourseGeneratorSettings:saveToXML(cpSettingsXml, 'CPSettings.courseGenerator')

		saveXMLFile(cpSettingsXml);
		delete(cpSettingsXml);

	else
		print(("COURSEPLAY ERROR: unable to load or create file -> %s"):format(CpManager.cpSettingsXmlFilePath));
	end;
end;
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, CpManager.saveXmlSettings);

-- adds courseplayer to global table, so that the system knows all of them
function CpManager:addToTotalCoursePlayers(vehicle)
	local vehicleNum = (table.maxn(self.totalCoursePlayers) or 0) + 1;
	self.totalCoursePlayers[vehicleNum] = vehicle;
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
		g_currentMission:addMoney(5000000,1, MoneyType.OTHER,true);
	else 
		CommandEvents.sendEvent("devAddMoney")
	end
	return ('Added %s to your bank account'):format(g_i18n:formatMoney(5000000));
end;

function CpManager:devAddFillLevels()
	--[[ Ryan TODO FillUtil.NUM_FILLTYPES doesn't have exist in g_fillTypeManager. Also the set and get functions might not exist there any more 
	if g_server ~= nil then
		for fillType=1,FillUtil.NUM_FILLTYPES do
			g_currentMission:setSiloAmount(fillType, g_currentMission:getSiloAmount(fillType) + 500000);
		end;
		return 'All silo fill levels increased by 500\'000.';
	end; ]]
end;
function CpManager:devStopAll()
	if g_server ~= nil then
		for _,vehicle in pairs (self.activeCoursePlayers) do
			courseplay.onStopCpAIDriver(vehicle,AIVehicle.STOP_REASON_UNKOWN)
		end
	else
		CommandEvents.sendEvent("devStopAll")
	end
	return ('stopped all Courseplayers');
end;

function CpManager:devSaveAllFields()
	if g_server then
		courseplay.fields.saveAllFields()
	else 
		CommandEvents.sendEvent("devSaveAllFields")
	end
	return( 'All fields saved' )
end

---Prints a variable to the console or a xmlFile.
---@param string variableName name of the variable, can be multiple levels
---@param int depth maximum depth, 1 by default
---@param int printToXML: should the variable be printed to an xml file ? (optional)
---@param int printToSeparateXmlFiles: should the variable be printed to an xml file named after the variable ? (optional)
function CpManager:printVariable(variableName, maxDepth,printToXML, printToSeparateXmlFiles)
	if printToXML and tonumber(printToXML) and tonumber(printToXML)>0 then
		HelperUtil.printVariableToXML(variableName, maxDepth,printToSeparateXmlFiles)
		return
	end
	print(string.format('%s - %s', tostring(variableName), tostring(maxDepth)))
	local depth = maxDepth and math.max(1, tonumber(maxDepth)) or 1
	local value = self:getVariable(variableName)
	local valueType = type(value)
	if value then
		print(string.format('Printing %s (%s), depth %d', variableName, valueType, depth))
		if valueType == 'table' then
			DebugUtil.printTableRecursively(value, '  ', 1, depth)
			local mt = getmetatable(value)
			if mt and type(mt) == 'table' then
				print('-- metatable -->')
				DebugUtil.printTableRecursively(mt, '  ', 1, depth)
			end
		else
			print(variableName .. ': ' .. tostring(value))
		end
	else
		return(variableName .. ' is nil')
	end
	return('Printed variable ' .. variableName)
end



--- Print the variable in the selected vehicle's namespace
-- You can omit the dot for data members but if you want to call a function, you must start the variable name with a colon
function CpManager:printVehicleVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	self:printVariableInternal( 'g_currentMission.controlledVehicle', variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end

function CpManager:printDriverVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	self:printVariableInternal( 'g_currentMission.controlledVehicle.cp.driver', variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end

function CpManager:printSettingVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	self:printVariableInternal( 'g_currentMission.controlledVehicle.cp.settings', variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end

function CpManager:printCourseGeneratorSettingVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	self:printVariableInternal( 'g_currentMission.controlledVehicle.cp.courseGeneratorSettings', variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end

function CpManager:printGlobalSettingVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	self:printVariableInternal( 'courseplay.courseplay.globalSettings', variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end

function CpManager:printGlobalCpVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	self:printVariableInternal( 'courseplay', variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end


function CpManager:printVariableInternal(prefix, variableName, maxDepth,printToXML,printToSeparateXmlFiles)
	if not StringUtil.startsWith(variableName, ':') and not StringUtil.startsWith(variableName, '.') then
		-- allow to omit the . at the beginning of the variable name.
		prefix = prefix .. '.'
	end
	self:printVariable(prefix .. variableName, maxDepth,printToXML,printToSeparateXmlFiles)
end


--- Install a wrapper around a function. The wrapper will print the function name
-- and the arguments every time the function is called and then call the function
function CpManager.installTraceFunction(name)
	return function(self, superFunc, ...)
		print(name ..  ' called with: ')
		for n= 1, select('#',...) do
			local v = select(n,...)
			if type(v) == 'table' then
				print(string.format(' arg %d: ', n))
				DebugUtil.printTableRecursively(v, '  ', 1, 1)
			else
				print(string.format(' arg %d: %s', n, tostring(v)))
			end
		end
		return superFunc(self, ...)
	end
end

--- Enable trace for a function. This is to reverse engineer the signature of undocumented functions
-- by tracing the arguments at every call. The original function is still executed.
function CpManager:traceOn(functionName)
	-- split the name into the function and table containing it
	local _, _, tabName, funcName = string.find(functionName, '(.*)%.(%w+)$')
	-- can't use func directly as we need to rewrite the reference to the function in the containing table
	local tab = self:getVariable(tabName)
	if tab and type(tab[funcName]) == 'function' then
		tab[funcName] = Utils.overwrittenFunction(tab[funcName], CpManager.installTraceFunction(functionName))
	else
		return(functionName .. ' is not a function.')
	end
	return('argument tracing is on for ' .. functionName)
end

--- Enable trace for all functions of the table
-- by tracing the arguments at every call. The original function is still executed.
function CpManager:traceOnForAll(tableName)
	local t = self:getVariable(tableName)
	if not t then
		return 'Could not read ' .. tableName
	else
		self:traceOnForTable(t, tableName)
		local mt = getmetatable(t)
		if mt then
			self:traceOnForTable(mt, tableName .. ' metatable')
			if mt.__index then
				self:traceOnForTable(mt, tableName .. ' metatable.__index')
			end
		end
	end
	return('argument tracing is on for all functions of ' .. tableName)
end

function CpManager:traceOnForTable(t, tableName)
	for key, value in pairs(t) do
		if type(value) == 'function' then
			t[key] = Utils.overwrittenFunction(value, CpManager.installTraceFunction(tableName .. '.' .. key))
			print('argument tracing is on for ' .. tableName .. '.' .. key)
		end
	end
end

---Creates a debug loop of n-iterations and a delay of m-ticks
---@param string variable name/path to print  
---@param function function to print the variable name
---@param int optional number of total iterations, default is 5
---@param int optional delay of update ticks in between, default is 100
function CpManager:createVariableDebugSparseHook(variableName,printVariableFunc,numIterations,delayBetweenIterations)
	if self.debugSparseHookVariable == nil then
		self.debugSparseHookVariable = {
			variableName = variableName,
			printVariableFunc = printVariableFunc,
			numIterations = numIterations or 5,
			delayBetweenIterations = delayBetweenIterations or 100
		}
	end
end

---Creates a debug loop of n-iterations and a delay of m-ticks for vehicle variables
---@param string variable name/path to print  
---@param int optional number of total iterations, default is 5
---@param int optional delay of update ticks in between, default is 100
function CpManager:createVehicleVariableDebugSparseHook(variableName,numIterations,delayBetweenIterations)
	if g_currentMission.controlledVehicle then
		self:createVariableDebugSparseHook(variableName,self.printVehicleVariable,numIterations,delayBetweenIterations)
	else 
		courseplay.info("controlledVehicle not found!")
	end
end

---Prints the debug sparse hook variable 
function CpManager:printVariableDebugSparseHook()
	if self.debugSparseHookVariable then 
		local delayBetweenIterations = self.debugSparseHookVariable.delayBetweenIterations
		if g_updateLoopIndex % delayBetweenIterations == 0 then
			local variableName = self.debugSparseHookVariable.variableName
			local numIterations = self.debugSparseHookVariable.numIterations
			local printVariableFunc = self.debugSparseHookVariable.printVariableFunc
			printVariableFunc(self,variableName,1)
			numIterations = numIterations - 1
			if numIterations < 1 then 
				self.debugSparseHookVariable = nil
			end
		end
	end
end

--- get a reference pointing to the global variable 'variableName'
-- can handle multiple levels (but not arrays, yet) like foo.bar
function CpManager:getVariable(variableName)
	local f = getfenv(0).loadstring('return ' .. variableName)
	return f and f() or nil
end

function CpManager:loadFile(fileName)
	fileName = fileName or 'reload.xml'
	local path = courseplay.path .. fileName
	if fileExists(path) then
		g_xmlFile = loadXMLFile('loadFile', path)
	end
	if not g_xmlFile then
		return 'Could not load ' .. path
	else
		local code = getXMLString(g_xmlFile, 'code')
		local f = getfenv(0).loadstring('setfenv(1, courseplay); ' .. code)
		if f then
			f()
			return 'OK: ' .. path .. ' loaded.'
		else
			return 'ERROR: ' .. path .. ' could not be compiled.'
		end
	end
end

function CpManager:loadAIDriver()
	local result = self:loadFile()
	if g_currentMission.controlledVehicle then
		-- re-instantiate the AIDriver after loaded
		g_currentMission.controlledVehicle.cp.settings.driverMode:setAIDriver()
		g_combineUnloadManager:addNewCombines()
	end
	return result
end

function CpManager:saveVehiclePositions()
	if g_server then 
		DevHelper.saveAllVehiclePositions()
	else 
		CommandEvents.sendEvent("saveVehiclePositions")
	end
end

function CpManager:restoreVehiclePositions()
	if g_server then 
		DevHelper.restoreAllVehiclePositions()
	else
		CommandEvents.sendEvent("restoreVehiclePositions")
	end
end

function CpManager:restartSaveGame(saveGameNumber)
	if g_server then
		restartApplication(" -autoStartSavegameId " .. saveGameNumber)
	end
end

function CpManager:showCombineUnloadManagerStatus()
	g_combineUnloadManager:printStatus()
end

function CpManager:setLookaheadDistance(d)
	if g_server then
		local vehicle = g_currentMission.controlledVehicle
		if vehicle and vehicle.cp and vehicle.cp.ppc then
			vehicle.cp.ppc:setLookaheadDistance(d)
			print('Look ahead distance for ' .. vehicle.name .. ' changed to ' .. tostring(d))
		else
			print('No vehicle or has no PPC.')	
		end
	else 
		CommandEvents.sendEvent("setLookaheadDistance",d)
		print('trying to change LookaheadDistance.')
	end
end

-- call vehicle:funcName(...) for the current vehicle and print the result
function CpManager:callVehicleFunction(funcName, ...)
	if g_currentMission.controlledVehicle then
		local f = loadstring('return g_currentMission.controlledVehicle.' .. funcName)
		if f then
			local result = f()(g_currentMission.controlledVehicle, ...)
			print('vehicle:' .. funcName .. ' returned:')
			DebugUtil.printTableRecursively(result, '  ', 1, 1)
			return
		end		 
	end
	return 'Error when calling vehicle:' .. funcName
end

function CpManager:setPathfindingDebug(d)
	PathfinderUtil.setVisualDebug(tonumber(d))
end

function CpManager:toggleDevhelperDebug()
	g_devHelper:toggleVisualDebug()
end


function CpManager:setupFieldScanInfo()
	--print("CpManager:setupFieldScanInfo()")
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
	self.fieldScanInfo.bgOverlay = Overlay:new(gfxPath, bgX, bgY, bgW, bgH);
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
	self.fieldScanInfo.progressBarOverlay = Overlay:new(gfxPath, pbX, pbY, self.fieldScanInfo.progressBarMaxWidth, pbH);
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

	local pct = courseplay.fields.curFieldScanIndex / #courseplay.fields.fieldDefinitionBase;

	local r, g, b = courseplay.utils:getColorFromPct(pct * 100, fsi.percentColors, fsi.colorMapStep);
	fsi.progressBarOverlay:setColor(r, g, b, 1);

	fsi.progressBarOverlay.width = fsi.progressBarMaxWidth * pct;
	local widthPx = courseplay:round(fsi.progressBarMaxWidthPx * pct);
	local newUVs = { fsi.progressBarUVs[1], fsi.progressBarUVs[2], fsi.progressBarUVs[1] + widthPx, fsi.progressBarUVs[4] };
	courseplay.utils:setOverlayUVsPx(fsi.progressBarOverlay, newUVs, fsi.fileWidth, fsi.fileHeight);
	fsi.progressBarOverlay:render();

	courseplay:setFontSettings('white', false, 'left');
	renderText(fsi.textPosX, fsi.titlePosY,         fsi.titleFontSize, courseplay:loc('COURSEPLAY_FIELD_SCAN_IN_PROGRESS'));

	local text = courseplay:loc('COURSEPLAY_SCANNING_FIELD_NMB'):format(courseplay.fields.curFieldScanIndex, #courseplay.fields.fieldDefinitionBase);
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
		local y = posY - g_currentMission.helpBoxTextSize - g_currentMission.helpBoxTextLineSpacing*2;
		ovl:setPosition(xLeft - ovl.width*0.2, y);
		ovl:render();
		xLeft = xLeft + ovl.width*0.6;
	end;

	posY = posY - g_currentMission.helpBoxTextSize - g_currentMission.helpBoxTextLineSpacing;
	setTextAlignment(RenderText.ALIGN_RIGHT);
	setTextColor(g_currentMission.helpBoxTextColor[1], g_currentMission.helpBoxTextColor[2], g_currentMission.helpBoxTextColor[3], g_currentMission.helpBoxTextColor[4]);
	renderText(xRight, posY, g_currentMission.helpBoxTextSize, txt);

	setTextAlignment(RenderText.ALIGN_LEFT);
	renderText(xLeft, posY, g_currentMission.helpBoxTextSize, courseplay.inputBindings.mouse.secondaryTextI18n);
end;

function CpManager:minuteChanged()
end;

--FieldScan startup dialog and github info
function CpManager:showYesNoDialogue(title, text, callbackFn)
	-- don't show anything if the tutorial dialog is open (it takes a while until isOpen, shows true after startup, hence the clock)
	if courseplay.clock < 2000 or (g_gui.guis.YesNoDialog.target and g_gui.guis.YesNoDialog.target.isOpen) then
		return
	end
	local text =string.format("%s\n\n%s",courseplay:loc('COURSEPLAY_SUPPORT_INFO'),courseplay:loc('COURSEPLAY_YES_NO_FIELDSCAN'))
	g_gui:showYesNoDialog({text=text, title=title, callback=callbackFn, target=self})
end;


-- ####################################################################################################
-- FIELD SCAN Y/N DIALOGUE
function CpManager:fieldScanDialogueCallback(setActive)
	--print(string.format("CpManager:fieldScanDialogueCallback(setActive(%s))",tostring(setActive)))
	courseplay.globalSettings.autoFieldScan:set(setActive)
	self.showFieldScanYesNoDialogue = false
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
	self.course2dTractorOverlay = Overlay:new( courseplay.hud.iconSpritePath, 0.5, 0.5, w, h);
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
		self.showFieldScanYesNoDialogue = true;
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
		courseplay.fields.onlyScanOwnedFields	  = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#onlyScanOwnedFields'),	 courseplay.fields.onlyScanOwnedFields);
		courseplay.fields.debugScannedFields 	  = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#debugScannedFields'),		 courseplay.fields.debugScannedFields);
		courseplay.fields.debugCustomLoadedFields = Utils.getNoNil(getXMLBool(cpSettingsXml, key .. '#debugCustomLoadedFields'), courseplay.fields.debugCustomLoadedFields);
		courseplay.fields.scanStep				  = Utils.getNoNil( getXMLInt(cpSettingsXml, key .. '#scanStep'),				 courseplay.fields.scanStep);

		-- 2D course
		key = 'CPSettings.course2D';
		self.course2dPlotPosX		= Utils.getNoNil(getXMLFloat(cpSettingsXml, key .. '#posX'),	 self.course2dPlotPosX);
		self.course2dPlotPosY		= Utils.getNoNil(getXMLFloat(cpSettingsXml, key .. '#posY'),	 self.course2dPlotPosY);
		self.course2dPdaMapOpacity	= Utils.getNoNil(getXMLFloat(cpSettingsXml, key .. '#opacity'), self.course2dPdaMapOpacity);

		self.course2dPlotField.x = self.course2dPlotPosX;
		self.course2dPlotField.y = self.course2dPlotPosY;

		courseplay.globalSettings:loadFromXML(cpSettingsXml, 'CPSettings')
		courseplay.globalCourseGeneratorSettings:loadFromXML(cpSettingsXml, 'CPSettings.courseGenerator')

		--------------------------------------------------
		delete(cpSettingsXml);
	end;
end;
