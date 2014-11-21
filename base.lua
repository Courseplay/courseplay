function courseplay.prerequisitesPresent(specializations)
	return true;
end

function courseplay:load(xmlFile)
	self.setCourseplayFunc = courseplay.setCourseplayFunc;

	--SEARCH AND SET self.name IF NOT EXISTING
	if self.name == nil then
		self.name = courseplay:getObjectName(self, xmlFile);
	end;

	if self.cp == nil then self.cp = {}; end;

	self.cp.varMemory = {};

	courseplay:setNameVariable(self);
	self.cp.isCombine = courseplay:isCombine(self);
	self.cp.isChopper = courseplay:isChopper(self);
	self.cp.isHarvesterSteerable = courseplay:isHarvesterSteerable(self);
	self.cp.isSugarBeetLoader = courseplay:isSpecialCombine(self, "sugarBeetLoader");
	if self.cp.isCombine then
		self.cp.mode7Unloading = false
		self.cp.driverPriorityUseFillLevel = false;
	end
	if self.isRealistic then
		self.cp.trailerPushSpeed = 0
	end
	self.cp.stopWhenUnloading = false;

	-- GIANT DLC
	self.cp.haveInversedRidgeMarkerState = nil; --bool

	--turn maneuver
	self.cp.waitForTurnTime = 0.00   --float
	self.cp.turnStage = 0 --int
	self.cp.aiTurnNoBackward = false --bool
	self.cp.backMarkerOffset = nil --float
	self.cp.aiFrontMarker = nil --float
	self.cp.turnTimer = 8000 --int
	self.cp.noStopOnEdge = false --bool
	self.cp.noStopOnTurn = false --bool

	self.toggledTipState = 0;

	self.cp.combineOffsetAutoMode = true
	self.drive = false
	self.cp.runOnceStartCourse = false;
	self.cp.stopAtEnd = false
	self.cp.calculatedCourseToCombine = false

	courseplay:setRecordNumber(self, 1);
	self.cp.lastRecordnumber = 1;
	self.cp.recordingTimer = 1
	self.cp.timeOut = 1
	self.timer = 0.00
	self.cp.timers = {}; 
	self.cp.driveSlowTimer = 0;
	self.cp.positionWithCombine = nil;

	-- RECORDING
	self.cp.isRecording = false;
	self.cp.recordingIsPaused = false;
	self.cp.isRecordingTurnManeuver = false;
	self.cp.drivingDirReverse = false;

	self.cp.waitPoints = {};
	self.cp.numWaitPoints = 0;
	self.cp.waitTime = 0;
	self.cp.crossingPoints = {};
	self.cp.numCrossingPoints = 0;

	self.cp.visualWaypointsMode = 1
	self.cp.beaconLightsMode = 1
	self.cp.workWidthChanged = 0
	-- saves the shortest distance to the next waypoint (for recocnizing circling)
	self.cp.shortestDistToWp = nil

	self.Waypoints = {}

	self.cp.canDrive = false --can drive course (has >4 waypoints, is not recording)
	self.cp.coursePlayerNum = nil;

	self.cp.infoText = nil -- info text on tractor

	-- global info text - also displayed when not in vehicle
	self.cp.hasSetGlobalInfoTextThisLoop = {};
	self.cp.activeGlobalInfoTexts = {};
	self.cp.numActiveGlobalInfoTexts = 0;


	-- ai mode: 1 abfahrer, 2 kombiniert
	self.cp.mode = 1
	self.cp.modeState = 0
	self.cp.mode2nextState = nil;
	self.cp.startWork = nil
	self.cp.stopWork = nil
	self.cp.abortWork = nil
	self.cp.hasUnloadingRefillingCourse = false;
	self.wait = true --TODO (Jakob): put in cp table
	self.cp.waitTimer = nil;
	self.cp.realisticDriving = true;
	self.cp.canSwitchMode = false;
	self.cp.startAtFirstPoint = false;
	self.cp.multiSiloSelectedFillType = Fillable.FILLTYPE_UNKNOWN;
	self.cp.stopForLoading = false;

	self.cp.attachedCombineIdx = nil;

	-- ai mode 9: shovel
	self.cp.shovelEmptyPoint = nil;
	self.cp.shovelFillStartPoint = nil;
	self.cp.shovelFillEndPoint = nil;
	self.cp.shovelState = 1;
	self.cp.shovel = {};
	self.cp.shovelStopAndGo = false;
	self.cp.shovelLastFillLevel = nil;
	self.cp.shovelStatePositions = {};
	self.cp.hasShovelStatePositions = {
		[2] = false;
		[3] = false;
		[4] = false;
		[5] = false;
	};

	--direction arrow the last waypoint (during paused recording)
	self.cp.directionArrowOverlay = Overlay:new('cpDistArrow_' .. tostring(self.rootNode), Utils.getFilename('img/arrow.png', courseplay.path), courseplay.hud.infoBaseCenter + 0.05, courseplay.hud.infoBasePosY + 0.11, 128/1920, 128/1080);

	-- Visual i3D waypoint signs
	self.cp.signs = {
		crossing = {};
		current = {};
	};
	courseplay.utils.signs:updateWaypointSigns(self);

	self.cp.numCourses = 1;
	self.cp.numWaypoints = 0;
	self.cp.currentCourseName = nil;
	self.cp.currentCourseId = 0;
	self.cp.lastMergedWP = 0;

	self.cp.loadedCourses = {}

	-- forced waypoints
	self.cp.curTarget = {};
	self.cp.curTargetMode7 = {};
	self.cp.nextTargets = {};

	-- speed limits
	self.cp.speeds = {
		useRecordingSpeed = true;
		unload =  6;
		turn =   10;
		field =  24;
		street = 50;
		crawl = 3;
		
		minUnload = 3;
		minTurn = 3;
		minField = 3;
		minStreet = 3;
		max = self.cruiseControl.maxSpeed or 60;
	};

	self.cp.toolsDirty = false

	self.cp.orgRpm = nil;

	-- data basis for the Course list
	self.cp.reloadCourseItems = true
	self.cp.sorted = {item={}, info={}}	
	self.cp.folder_settings = {}
	courseplay.settings.update_folders(self)

	--aiTrafficCollisionTrigger
	if self.aiTrafficCollisionTrigger == nil then
		local index = getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index");
		if index then
			local triggerObject = Utils.indexToObject(self.components, index);
			if triggerObject then
				self.aiTrafficCollisionTrigger = triggerObject;
			end;
		end;
	else
		courseplay.trafficCollisionIgnoreList[self.aiTrafficCollisionTrigger] = true; --add AI traffic collision trigger to global ignore list
	end;
	if self.aiTrafficCollisionTrigger == nil and getNumOfChildren(self.rootNode) > 0 then
		if getChild(self.rootNode, "trafficCollisionTrigger") ~= 0 then
			self.aiTrafficCollisionTrigger = getChild(self.rootNode, "trafficCollisionTrigger");
		else
			for i=0,getNumOfChildren(self.rootNode)-1 do
				local child = getChildAt(self.rootNode, i);
				if getChild(child, "trafficCollisionTrigger") ~= 0 then
					self.aiTrafficCollisionTrigger = getChild(child, "trafficCollisionTrigger");
					break;
				end;
			end;
		end;
	end;
	if self.aiTrafficCollisionTrigger == nil then
		print(string.format('## Courseplay: %s: aiTrafficCollisionTrigger missing. Traffic collision prevention will not work!', nameNum(self)));
	end;

	--Direction 
	local DirectionNode;
	if self.aiTractorDirectionNode ~= nil then
		DirectionNode = self.aiTractorDirectionNode;
	elseif self.aiTreshingDirectionNode ~= nil then
		DirectionNode = self.aiTreshingDirectionNode;
	else
		if courseplay:isWheelloader(self)then
			-- DirectionNode = getParent(self.shovelTipReferenceNode)
			DirectionNode = self.components[2].node;
			if self.wheels[1].rotMax ~= 0 then
				DirectionNode = self.rootNode;
			end
			--[[if DirectionNode == nil then
				for i=1, table.getn(self.attacherJoints) do
					if self.rootNode ~= getParent(self.attacherJoints[i].jointTransform) then
						DirectionNode = getParent(self.attacherJoints[i].jointTransform)
						break
					end
				end
			end]]
		end
		if DirectionNode == nil then
			DirectionNode = self.rootNode;
		end
	end;
	if self.cp.directionNodeZOffset and self.cp.directionNodeZOffset ~= 0 then
		self.cp.oldDirectionNode = DirectionNode;  -- Only used for debugging.
		DirectionNode = courseplay:createNewLinkedNode(self, "realDirectionNode", DirectionNode);
		setTranslation(DirectionNode, 0, 0, self.cp.directionNodeZOffset);
	end;

	self.cp.DirectionNode = DirectionNode;

	-- TRIGGERS
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	self.findSpecialTriggerCallback = courseplay.findSpecialTriggerCallback;
	self.cp.hasRunRaycastThisLoop = {};
	self.findTrafficCollisionCallback = courseplay.findTrafficCollisionCallback;
	self.findBlockingObjectCallbackLeft = courseplay.findBlockingObjectCallbackLeft;
	self.findBlockingObjectCallbackRight = courseplay.findBlockingObjectCallbackRight;
	self.findVehicleHeights = courseplay.findVehicleHeights; 
	
	-- traffic collision
	self.cpOnTrafficCollisionTrigger = courseplay.cpOnTrafficCollisionTrigger;

	self.cp.steeringAngle = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.wheels.wheel(1)" .. "#rotMax"), 30)
	self.cp.tempCollis = {}
	self.CPnumCollidingVehicles = 0;
	self.cpTrafficCollisionIgnoreList = {};
	self.cp.TrafficBrake = false
	self.cp.inTraffic = false

	if self.trafficCollisionIgnoreList == nil then
		self.trafficCollisionIgnoreList = {}
	end
	 if self.numCollidingVehicles == nil then
		self.numCollidingVehicles = {};
	end

	self.cp.numTrafficCollisionTriggers = 0;
	self.cp.trafficCollisionTriggers = {};
	self.cp.trafficCollisionTriggerToTriggerIndex = {};
	self.cp.collidingObjects = {
		all = {};
	};
	self.cp.numCollidingObjects = {
		all = 0;
	};
	if self.aiTrafficCollisionTrigger ~= nil then
		self.cp.numTrafficCollisionTriggers = 4;
		for i=1,self.cp.numTrafficCollisionTriggers do
			local newTrigger = clone(self.aiTrafficCollisionTrigger, true);
			self.cp.trafficCollisionTriggers[i] = newTrigger
			if i > 1 then
				unlink(newTrigger);
				link(self.cp.trafficCollisionTriggers[i-1], newTrigger);
				setTranslation(newTrigger, 0,0,5);
			end;
			addTrigger(newTrigger, 'cpOnTrafficCollisionTrigger', self);
			self.cp.trafficCollisionTriggerToTriggerIndex[newTrigger] = i;
			courseplay.trafficCollisionIgnoreList[newTrigger] = true; --add all traffic collision triggers to global ignore list
			self.cp.collidingObjects[i] = {};
			self.cp.numCollidingObjects[i] = 0;
		end;
	end;

	if not courseplay.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] then
		courseplay.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] = true;
	end;


	courseplay:askForSpecialSettings(self,self)


	-- tippers
	self.tippers = {}; --TODO (Jakob): put in cp table
	self.cp.numWorkTools = 0;
	self.cp.tipperAttached = false;
	self.cp.currentTrailerToFill = nil;
	self.cp.trailerFillDistance = nil;
	self.cp.isUnloaded = false;
	self.cp.isLoaded = false;
	self.cp.unloadingTipper = nil;
	self.cp.tipperFillLevel = nil;
	self.cp.tipperCapacity = nil;
	self.cp.tipperFillLevelPct = 0;
	self.cp.prevFillLevelPct = nil;
	self.cp.tipRefOffset = 0;
	self.cp.isReverseBGATipping = nil; -- Used for reverse BGA tipping
	self.cp.BGASelectedSection = nil; -- Used for reverse BGA tipping
	self.cp.BGASectionInverted = false; -- Used for reverse BGA tipping
	self.cp.rearTipRefPoint = nil; -- Used for reverse BGA tipping
	self.cp.inversedRearTipNode = nil; -- Used for reverse BGA tipping
	self.cp.tipperHasCover = false;
	self.cp.tippersWithCovers = {};
	self.cp.automaticCoverHandling = true;

	-- combines
	self.cp.reachableCombines = {};
	self.cp.activeCombine = nil;

	self.cp.offset = nil --self = combine [flt]
	self.cp.combineOffset = 0.0
	self.cp.tipperOffset = 0.0

	self.cp.forcedSide = nil
	self.cp.forcedToStop = false

	self.cp.allowFollowing = false
	self.cp.followAtFillLevel = 50
	self.cp.driveOnAtFillLevel = 90
	self.cp.refillUntilPct = 100;

	--self.turn_factor = nil --TODO: is never set, but used in mode2:816 in localToWorld function
	self.cp.turnRadius = 10;
	self.cp.turnRadiusAuto = 10;
	self.cp.turnRadiusAutoMode = true;

	--Offset
	self.cp.laneOffset = 0;
	self.cp.toolOffsetX = 0;
	self.cp.toolOffsetZ = 0;
	self.cp.totalOffsetX = 0;
	self.cp.symmetricLaneChange = false;
	self.cp.switchLaneOffset = false;
	self.cp.switchToolOffset = false;

	self.cp.workWidth = 3

	self.cp.searchCombineAutomatically = true;
	self.cp.savedCombine = nil
	self.cp.selectedCombineNumber = 0
	self.cp.searchCombineOnField = 0;

	--Copy course
	self.cp.hasFoundCopyDriver = false;
	self.cp.copyCourseFromDriver = nil;
	self.cp.selectedDriverNumber = 0;

	--Course generation
	self.cp.startingCorner = 0;
	self.cp.hasStartingCorner = false;
	self.cp.startingDirection = 0;
	self.cp.hasStartingDirection = false;
	self.cp.returnToFirstPoint = false;
	self.cp.hasGeneratedCourse = false;
	self.cp.hasValidCourseGenerationData = false;
	self.cp.ridgeMarkersAutomatic = true;
	self.cp.headland = {
		maxNumLanes = 6;
		numLanes = 0;
		userDirClockwise = true;
		orderBefore = true;

		tg = createTransformGroup('cpPointOrig_' .. tostring(self.rootNode));

		rectWidthRatio = 1.25;
		noGoWidthRatio = 0.975;
		minPointDistance = 0.5;
		maxPointDistance = 7.25;
	};
	link(getRootNode(), self.cp.headland.tg);
	if courseplay.isDeveloper then
		self.cp.headland.maxNumLanes = 50;
	end;

	self.cp.fieldEdge = {
		selectedField = {
			fieldNum = 0;
			numPoints = 0;
			buttonsCreated = false;
		};
		customField = {
			points = nil;
			numPoints = 0;
			isCreated = false;
			show = false;
			fieldNum = 0;
			selectedFieldNumExists = false;
		};
	};

	self.cp.mouseCursorActive = false;


	local w16px, h16px = 16/1920, 16/1080;
	local w24px, h24px = 24/1920, 24/1080;
	local w32px, h32px = 32/1920, 32/1080;

	-- HUD
	self.cp.hud = {
		background = Overlay:new('courseplayHud', Utils.getFilename('img/hud_bg.png', courseplay.path), courseplay.hud.infoBasePosX - 10/1920, courseplay.hud.infoBasePosY - 10/1920, courseplay.hud.infoBaseWidth, courseplay.hud.infoBaseHeight);
		backgroundSuc = Overlay:new('courseplayHudSuc', Utils.getFilename('img/hud_suc_bg.png', courseplay.path), courseplay.hud.infoBasePosX - 10/1920, courseplay.hud.infoBasePosY - 10/1920, courseplay.hud.infoBaseWidth, courseplay.hud.infoBaseHeight);
		currentPage = 1;
		show = false;
		openWithMouse = true;
		content = {
			global = {};
			pages = {};
		};
		mouseWheel = {
			-- icon = Overlay:new('cpMouseWheelIcon', 'dataS2/menu/mouseControlsHelp/mouseMMB.png', 0, 0, 32/g_screenWidth, 32/g_screenHeight); -- FS13
			icon = Overlay:new('cpMouseWheelIcon', 'dataS2/menu/controllerSymbols/mouse/mouseMMB.png', 0, 0, 32/g_screenWidth, 32/g_screenHeight); -- FS15
			render = false;
		};

		--3rd party huds backup
		ESLimiterOrigPosY = nil; --[table]
		ThreshingCounterOrigPosY = nil; --[table]
		OdometerOrigPosY = nil; --[table]
		AllradOrigPosY = nil; --[table]
		MaxRpmOrigPosY = nil; --[table]
	};

	-- clickable buttons
	self.cp.buttons = {};
	self.cp.buttons.global = {};
	self.cp.buttons.suc = {};
	self.cp.buttons[-2] = {};
	for page=0, courseplay.hud.numPages do
		self.cp.buttons[page] = {};
	end;

	-- SeedUsageCalculator
	self.cp.suc = {
		active = false;
		fontSize = courseplay.hud.fontSizes.seedUsageCalculator;
		x1 = self.cp.hud.background.x + 93/1920;
		x2 = self.cp.hud.background.x + 93/1920 + 449/1920;
		y1 = self.cp.hud.background.y + 335/1080;
		y2 = self.cp.hud.background.y + 335/1080 + 115/1080;
	};
	self.cp.suc.lineHeight = self.cp.suc.fontSize; -- * 1.25;
	-- if not courseplay.moreRealisticInstalled then
		-- self.cp.suc.y2 = self.cp.suc.y2 - self.cp.suc.lineHeight;
	-- end;
	self.cp.suc.width  = self.cp.suc.x2 - self.cp.suc.x1;
	self.cp.suc.height = self.cp.suc.y2 - self.cp.suc.y1;
	self.cp.suc.buttonFileHeight = self.cp.suc.fontSize;
	self.cp.suc.buttonFileWidth  = self.cp.suc.buttonFileHeight / g_screenAspectRatio;
	self.cp.suc.hPad = self.cp.suc.buttonFileWidth * 2.25;
	self.cp.suc.vPad = 0.007;
	self.cp.suc.textMinX = self.cp.suc.x1 + self.cp.suc.hPad;
	self.cp.suc.textMaxX = self.cp.suc.x2 - self.cp.suc.hPad;
	self.cp.suc.textMaxWidth = self.cp.suc.textMaxX - self.cp.suc.textMinX;

	self.cp.suc.lines = {};
	self.cp.suc.lines.title = {
		fontSize = self.cp.suc.fontSize * 1.1;
		text = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR');
	};
	self.cp.suc.lines.title.posY = self.cp.suc.y2 - self.cp.suc.vPad - self.cp.suc.lines.title.fontSize;
	self.cp.suc.lines.field = {
		fontSize = self.cp.suc.fontSize;
		posY = self.cp.suc.lines.title.posY - self.cp.suc.lineHeight * 1.15;
		text = '';
	};
	self.cp.suc.lines.fruit = {
		fontSize = self.cp.suc.fontSize;
		posY = self.cp.suc.lines.field.posY - self.cp.suc.lineHeight;
		text = '';
	};
	self.cp.suc.lines.resultDefault = {
		fontSize = self.cp.suc.fontSize * 1.05;
		posY = self.cp.suc.lines.fruit.posY - self.cp.suc.lineHeight * 4/3;
		text = '';
	};
	self.cp.suc.lines.resultMoreRealistic = {
		fontSize = self.cp.suc.fontSize * 1.05;
		posY = self.cp.suc.lines.resultDefault.posY - self.cp.suc.lineHeight * 1.05;
		text = '';
	};
	local xL = self.cp.suc.x1 + 3/1080 / g_screenAspectRatio;
	local xR = self.cp.suc.x1 + self.cp.suc.buttonFileWidth;
	local w,h = self.cp.suc.buttonFileWidth, self.cp.suc.buttonFileHeight;
	local fruitNegButtonIdx = courseplay.button:create(self, 'suc', 'navigate_left.png',  'sucChangeFruit', -1, xL, self.cp.suc.lines.fruit.posY, w, h);
	local fruitPosButtonIdx = courseplay.button:create(self, 'suc', 'navigate_right.png', 'sucChangeFruit',  1, xR, self.cp.suc.lines.fruit.posY, w, h);
	self.cp.suc.fruitNegButton = self.cp.buttons.suc[fruitNegButtonIdx];
	self.cp.suc.fruitPosButton = self.cp.buttons.suc[fruitPosButtonIdx];
	-- self.cp.suc.selectedFieldIdx = 1;
	-- self.cp.suc.selectedField = nil; --0;
	self.cp.suc.selectedFruitIdx = 1;
	self.cp.suc.selectedFruit = nil;


	self.cp.hud.reloadPage = {};
	courseplay.hud:setReloadPageOrder(self, -1, true); --reload all

	for page=0,courseplay.hud.numPages do
		self.cp.hud.content.pages[page] = {};
		for line=1,courseplay.hud.numLines do
			self.cp.hud.content.pages[page][line] = {
				{ text = nil, isClicked = false, isHovered = false, indention = 0 },
				{ text = nil, posX = courseplay.hud.col2posX[page] }
			};
			if courseplay.hud.col2posXforce[page] ~= nil and courseplay.hud.col2posXforce[page][line] ~= nil then
				self.cp.hud.content.pages[page][line][2].posX = courseplay.hud.col2posXforce[page][line];
			end;
		end;
	end;
	
	-- course list
	self.cp.hud.filterEnabled = true;
	self.cp.hud.filter = "";
	self.cp.hud.choose_parent = false
	self.cp.hud.showFoldersOnly = false
	self.cp.hud.showZeroLevelFolder = false
	self.cp.hud.courses = {}
	self.cp.hud.courseListPrev = false;
	self.cp.hud.courseListNext = false; -- will be updated after loading courses into the hud

	--Camera backups: allowTranslation
	self.cp.camerasBackup = {};
	for camIndex, camera in pairs(self.cameras) do
		if camera.allowTranslation then
			self.cp.camerasBackup[camIndex] = camera.allowTranslation;
		end;
	end;

	--default hud conditional variables
	self.cp.HUDrecordnumber = 0 
	self.cp.HUD0noCourseplayer = false;
	self.cp.HUD0wantsCourseplayer = false;
	self.cp.HUD0tractorName = "";
	self.cp.HUD0tractorForcedToStop = false;
	self.cp.HUD0tractor = false;
	self.cp.HUD0combineForcedSide = nil;
	self.cp.HUD0isManual = false;
	self.cp.HUD0turnStage = 0;
	self.cp.HUD1notDrive = false;
	self.cp.HUD1wait = false;
	self.cp.HUD1noWaitforFill = false;
	self.cp.HUD4combineName = "";
	self.cp.HUD4hasActiveCombine = false;
	self.cp.HUD4savedCombine = nil;
	self.cp.HUD4savedCombineName = "";

	courseplay:setMinHudPage(self, nil);

	--Hud titles
	if courseplay.hud.hudTitles == nil then
		courseplay.hud.hudTitles = {
			[0] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBINE_CONTROLS"), -- combine controls
			[1] = courseplay:loc("COURSEPLAY_PAGE_TITLE_CP_CONTROL"), -- courseplay control
			[2] = { courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COURSES"), courseplay:loc("COURSEPLAY_PAGE_TITLE_CHOOSE_FOLDER"), courseplay:loc("COURSEPLAY_COURSES_FILTER_TITLE") }, -- courses & filter
			[3] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBI_MODE"), -- combi mode settings
			[4] = courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COMBINES"), -- manage combines
			[5] = courseplay:loc("COURSEPLAY_PAGE_TITLE_SPEEDS"), -- speeds
			[6] = courseplay:loc("COURSEPLAY_PAGE_TITLE_GENERAL_SETTINGS"), -- general settings
			[7] = courseplay:loc("COURSEPLAY_PAGE_TITLE_DRIVING_SETTINGS"), -- Driving settings
			[8] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COURSE_GENERATION"), -- course generation
			[9] = courseplay:loc("COURSEPLAY_SHOVEL_POSITIONS") -- shovel
		};
	end;


	-- ## BUTTONS FOR HUD ##
	local mouseWheelArea = {
		x = courseplay.hud.infoBasePosX + 0.005,
		w = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1 - (2 * 0.005),
		h = courseplay.hud.lineHeight
	};

	local listArrowX = courseplay.hud.visibleArea.x2 - (2 * 0.005) - w24px;

	-- Page nav
	local pageNav = {
		buttonW = w32px;
		buttonH = h32px;
		paddingRight = 0.005;
		posY = courseplay.hud.infoBasePosY + 0.271;
	};
	pageNav.totalWidth = ((courseplay.hud.numPages + 1) * pageNav.buttonW) + (courseplay.hud.numPages * pageNav.paddingRight); --numPages=9, real numPages=10
	pageNav.baseX = courseplay.hud.infoBaseCenter - pageNav.totalWidth/2;
	for p=0, courseplay.hud.numPages do
		local posX = pageNav.baseX + (p * (pageNav.buttonW + pageNav.paddingRight));
		courseplay.button:create(self, 'global', string.format('pageNav_%d.dds', p), 'setHudPage', p, posX, pageNav.posY, pageNav.buttonW, pageNav.buttonH);
	end;

	courseplay.button:create(self, 'global', 'navigate_left.png', 'switchHudPage', -1, courseplay.hud.infoBasePosX + 0.035, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px); --ORIG: +0.242
	courseplay.button:create(self, 'global', 'navigate_right.png', 'switchHudPage', 1, courseplay.hud.buttonPosX[1], courseplay.hud.infoBasePosY + 0.2395, w24px, h24px);

	courseplay.button:create(self, 'global', 'close.png', 'openCloseHud', false, courseplay.hud.buttonPosX[2], courseplay.hud.infoBasePosY + 0.255, w24px, h24px);

	courseplay.button:create(self, 'global', 'disk.png', 'showSaveCourseForm', 'course', listArrowX - 15/1920 - w24px, courseplay.hud.infoBasePosY + 0.056, w24px, h24px);

	if courseplay.isDeveloper then
		courseplay.button:create(self, 'global', 'eye.png', 'setDrawWaypointsLines', nil, courseplay.hud.infoBasePosX + 0.01, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px);
	end;


	-- ##################################################
	-- Page 0: Combine controls
	for i=1, courseplay.hud.numLines do
		courseplay.button:create(self, 0, "blank.png", "rowButton", i, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[i], courseplay.hud.visibleArea.width, 0.015, i, nil, true);
	end;


	-- ##################################################
	-- Page 1
	-- mode quickSwitch
	local aiModeQuickSwitch = {
		w = w32px;
		h = h32px;
		numColumns = 3;
		maxX = courseplay.hud.visibleArea.x2 - 0.01;
	};
	aiModeQuickSwitch.minX = aiModeQuickSwitch.maxX - (aiModeQuickSwitch.numColumns * aiModeQuickSwitch.w);
	for i=1, courseplay.numAiModes do
		local icon = string.format('quickSwitch_mode%d.png', i);

		local l = math.ceil(i/aiModeQuickSwitch.numColumns);
		local col = i;
		while col > aiModeQuickSwitch.numColumns do
			col = col - aiModeQuickSwitch.numColumns;
		end;

		local posX = aiModeQuickSwitch.minX + (aiModeQuickSwitch.w * (col-1));
		local posY = courseplay.hud.linesPosY[1] + courseplay.hud.lineHeight --[[(20/1080)]] - (aiModeQuickSwitch.h * l);

		courseplay.button:create(self, 1, icon, 'setCpMode', i, posX, posY, aiModeQuickSwitch.w, aiModeQuickSwitch.h);
	end;

	--recording
	local recordingData = {
		[1] = { 'recording_stop', 'stop_record' },
		[2] = { 'recording_pause', 'setRecordingPause', true },
		[3] = { 'recording_deleteWaypoint', 'delete_waypoint' },
		[4] = { 'recording_setWait', 'set_waitpoint' },
		[5] = { 'recording_setCrossing', 'set_crossing' },
		[6] = { 'recording_turn', 'setRecordingTurnManeuver', true },
		[7] = { 'recording_reverse', 'change_DriveDirection', true }
	};
	local w,h = w32px,h32px;
	local padding = w/4;
	local totalWidth = (#recordingData - 1) * (w + padding) + w;
	local initX = courseplay.hud.infoBaseCenter - totalWidth/2;
	
	for i,data in pairs(recordingData) do
		local posX = initX + ((w + padding) * (i-1));
		local isToggleButton = data[3] or false;
		courseplay.button:create(self, 1, data[1] .. '.png', data[2], nil, posX, courseplay.hud.linesButtonPosY[2], w, h, nil, nil, false, false, isToggleButton);
	end;

	--row buttons
	for i=1, courseplay.hud.numLines do
		courseplay.button:create(self, 1, 'blank.png', 'rowButton', i, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[i], aiModeQuickSwitch.minX - courseplay.hud.infoBasePosX - 0.005, 0.015, i, nil, true);
	end;

	--Custom field edge path
	courseplay.button:create(self, 1, 'cancel.png', 'clearCustomFieldEdge', nil, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);
	courseplay.button:create(self, 1, 'eye.png', 'toggleCustomFieldEdgePathShow', nil, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);

	courseplay.button:create(self, 1, 'navigate_minus.png', 'setCustomFieldEdgePathNumber', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -5, false);
	courseplay.button:create(self, 1, 'navigate_plus.png',  'setCustomFieldEdgePathNumber',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  5, false);
	courseplay.button:create(self, 1, nil, 'setCustomFieldEdgePathNumber', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	-- Find first waypoint
	courseplay.button:create(self, 1, 'searchGlass.png', 'toggleFindFirstWaypoint', nil, listArrowX - (4*w16px*10/16) - (3*w16px), courseplay.hud.infoBasePosY + 0.2395, w24px, h24px, nil, nil, false, false, true);


	-- ##################################################
	-- Page 2: Course management
	--course navigation
	courseplay.button:create(self, 2, 'navigate_up.png',   'shiftHudCourses', -courseplay.hud.numLines, listArrowX, courseplay.hud.linesPosY[1] - 0.003,                       w24px, h24px, nil, -courseplay.hud.numLines*2);
	courseplay.button:create(self, 2, 'navigate_down.png', 'shiftHudCourses',  courseplay.hud.numLines, listArrowX, courseplay.hud.linesPosY[courseplay.hud.numLines] - 0.003, w24px, h24px, nil,  courseplay.hud.numLines*2);

	local courseListMouseWheelArea = {
		x = mouseWheelArea.x,
		y = courseplay.hud.linesPosY[courseplay.hud.numLines],
		width = mouseWheelArea.w,
		height = courseplay.hud.linesPosY[1] + courseplay.hud.lineHeight - courseplay.hud.linesPosY[courseplay.hud.numLines]
	};
	courseplay.button:create(self, 2, nil, 'shiftHudCourses',  -1, courseListMouseWheelArea.x, courseListMouseWheelArea.y, courseListMouseWheelArea.width, courseListMouseWheelArea.height, nil, -courseplay.hud.numLines, nil, true);

	--reload courses
	if g_server ~= nil then
		--courseplay.button:create(self, 2, 'refresh.png', 'reloadCoursesFromXML', nil, courseplay.hud.infoBasePosX + 0.258, courseplay.hud.infoBasePosY + 0.24, w16px, h16px);
	end;

	--course actions
	local pad = w16px*10/16 --old padding = 0.009667 ~ 18.5px
	local buttonX = {};
	buttonX[0] = courseplay.hud.infoBasePosX + 0.005;
	buttonX[4] = listArrowX - (2 * pad) - w16px;
	buttonX[3] = buttonX[4] - pad - w16px;
	buttonX[2] = buttonX[3] - pad - w16px;
	buttonX[1] = buttonX[2] - pad - w16px;
	local hoverAreaWidth = buttonX[3] + w16px - buttonX[1];
	if g_server ~= nil then
		hoverAreaWidth = buttonX[4] + w16px - buttonX[1];
	end;
	for i=1, courseplay.hud.numLines do
		local expandButtonIndex = courseplay.button:create(self, -2, 'folder_expand.png', 'expandFolder', i, buttonX[0], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		courseplay.button:addOverlay(self.cp.buttons[-2][expandButtonIndex], 2, 'folder_reduce.png');
		courseplay.button:create(self, -2, 'courseLoadAppend.png', 'load_sorted_course', i, buttonX[1], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		courseplay.button:create(self, -2, 'courseAdd.png', 'add_sorted_course', i, buttonX[2], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		local linkParentButtonIndex = courseplay.button:create(self, -2, 'folder_parent_from.png', 'link_parent', i, buttonX[3], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		courseplay.button:addOverlay(self.cp.buttons[-2][linkParentButtonIndex], 2, 'folder_parent_to.png');
		if g_server ~= nil then
			courseplay.button:create(self, -2, 'delete.png', 'delete_sorted_item', i, buttonX[4], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		end;
		courseplay.button:create(self, -2, nil, nil, nil, buttonX[1], courseplay.hud.linesButtonPosY[i], hoverAreaWidth, mouseWheelArea.h, i, nil, true, false);
	end
	self.cp.hud.filterButtonIndex = courseplay.button:create(self, 2, 'searchGlass.png', 'showSaveCourseForm', 'filter', buttonX[2], courseplay.hud.infoBasePosY + 0.2395, w24px, h24px);
	courseplay.button:addOverlay(self.cp.buttons[2][self.cp.hud.filterButtonIndex], 2, 'cancel.png');
	courseplay.button:create(self, 2, 'folder_new.png', 'showSaveCourseForm', 'folder', listArrowX, courseplay.hud.infoBasePosY + 0.056, w24px, h24px);


	-- ##################################################
	-- Page 3
	courseplay.button:create(self, 3, 'navigate_minus.png', 'changeCombineOffset', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -0.5, false);
	courseplay.button:create(self, 3, 'navigate_plus.png',  'changeCombineOffset',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  0.5, false);
	courseplay.button:create(self, 3, nil, 'changeCombineOffset', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);

	courseplay.button:create(self, 3, 'navigate_minus.png', 'changeTipperOffset', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -0.5, false);
	courseplay.button:create(self, 3, 'navigate_plus.png',  'changeTipperOffset',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  0.5, false);
	courseplay.button:create(self, 3, nil, 'changeTipperOffset', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);

	courseplay.button:create(self, 3, 'navigate_minus.png', 'changeTurnRadius', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, -5, false);
	courseplay.button:create(self, 3, 'navigate_plus.png',  'changeTurnRadius',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  5, false);
	courseplay.button:create(self, 3, nil, 'changeTurnRadius', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

	courseplay.button:create(self, 3, 'navigate_minus.png', 'changeFollowAtFillLevel', -5, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -10, false);
	courseplay.button:create(self, 3, 'navigate_plus.png',  'changeFollowAtFillLevel',  5, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  10, false);
	courseplay.button:create(self, 3, nil, 'changeFollowAtFillLevel', 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 10, true, true);

	courseplay.button:create(self, 3, 'navigate_minus.png', 'changeDriveOnAtFillLevel', -5, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, -10, false);
	courseplay.button:create(self, 3, 'navigate_plus.png',  'changeDriveOnAtFillLevel',  5, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5,  10, false);
	courseplay.button:create(self, 3, nil, 'changeDriveOnAtFillLevel', 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 10, true, true);

	courseplay.button:create(self, 3, 'navigate_minus.png', 'changeRefillUntilPct', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, -5, false);
	courseplay.button:create(self, 3, 'navigate_plus.png',  'changeRefillUntilPct',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6,  5, false);
	courseplay.button:create(self, 3, nil, 'changeRefillUntilPct', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, 5, true, true);


	-- ##################################################
	-- Page 4: Combine management
	courseplay.button:create(self, 4, 'blank.png', 'switchSearchCombineMode', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[1], courseplay.hud.visibleArea.width, 0.015, 1, nil, true);

	courseplay.button:create(self, 4, 'navigate_up.png',   'selectAssignedCombine', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, nil, false);
	courseplay.button:create(self, 4, 'navigate_down.png', 'selectAssignedCombine',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, nil, false);

	courseplay.button:create(self, 4, 'navigate_up.png',   'setSearchCombineOnField', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);
	courseplay.button:create(self, 4, 'navigate_down.png', 'setSearchCombineOnField',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);
	courseplay.button:create(self, 4, nil, 'setSearchCombineOnField', -1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, -5, true, true);

	courseplay.button:create(self, 4, 'blank.png', 'removeActiveCombineFromTractor', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);


	-- ##################################################
	-- Page 5: Speeds
	courseplay.button:create(self, 5, 'navigate_minus.png', 'changeTurnSpeed',   -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -5, false);
	courseplay.button:create(self, 5, 'navigate_plus.png',  'changeTurnSpeed',    1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  5, false);
	courseplay.button:create(self, 5, nil, 'changeTurnSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 5, true, true);

	courseplay.button:create(self, 5, 'navigate_minus.png', 'changeFieldSpeed',  -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -5, false);
	courseplay.button:create(self, 5, 'navigate_plus.png',  'changeFieldSpeed',   1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  5, false);
	courseplay.button:create(self, 5, nil, 'changeFieldSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 5, true, true);

	courseplay.button:create(self, 5, 'navigate_minus.png', 'changeMaxSpeed',    -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, -5, false);
	courseplay.button:create(self, 5, 'navigate_plus.png',  'changeMaxSpeed',     1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  5, false);
	courseplay.button:create(self, 5, nil, 'changeMaxSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

	courseplay.button:create(self, 5, 'navigate_minus.png', 'changeUnloadSpeed', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -5, false);
	courseplay.button:create(self, 5, 'navigate_plus.png',  'changeUnloadSpeed',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  5, false);
	courseplay.button:create(self, 5, nil, 'changeUnloadSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	courseplay.button:create(self, 5, 'blank.png', 'changeUseRecordingSpeed',1, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);


	-- ##################################################
	-- Page 6: General settings
	courseplay.button:create(self, 6, 'blank.png', 'toggleRealisticDriving', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[1], courseplay.hud.visibleArea.width, 0.015, 1, nil, true);
	courseplay.button:create(self, 6, 'blank.png', 'toggleOpenHudWithMouse', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], courseplay.hud.visibleArea.width, 0.015, 2, nil, true);
	courseplay.button:create(self, 6, 'blank.png', 'changeVisualWaypointsMode', 1, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[3], courseplay.hud.visibleArea.width, 0.015, 3, nil, true);
	courseplay.button:create(self, 6, 'blank.png', 'changeBeaconLightsMode', 1, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[4], courseplay.hud.visibleArea.width, 0.015, 4, nil, true);

	courseplay.button:create(self, 6, 'navigate_minus.png', 'changeWaitTime', -5, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, -10, false);
	courseplay.button:create(self, 6, 'navigate_plus.png',  'changeWaitTime',  5, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5,  10, false);
	courseplay.button:create(self, 6, nil, 'changeWaitTime', 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 10, true, true);

	local dbgW, dbgH = 22/1920, 22/1080;
	local dbgPosY = courseplay.hud.linesPosY[6] - 0.004;
	local dbgMaxX = courseplay.hud.buttonPosX[1] - 0.01;
	for dbg=1, courseplay.numAvailableDebugChannels do
		local col = ((dbg-1) % courseplay.numDebugChannelButtonsPerLine) + 1;
		local dbgPosX = dbgMaxX - (courseplay.numDebugChannelButtonsPerLine * dbgW) + ((col-1) * dbgW);
		courseplay.button:create(self, 6, 'debugChannelButtons.png', 'toggleDebugChannel', dbg, dbgPosX, dbgPosY, dbgW, dbgH);
	end;
	courseplay.button:create(self, 6, 'navigate_up.png',   'changeDebugChannelSection', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, -1, true, false);
	courseplay.button:create(self, 6, 'navigate_down.png', 'changeDebugChannelSection',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6,  1, true, false);
	courseplay.button:create(self, 6, nil, 'changeDebugChannelSection', -1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, -1, true, true);


	-- ##################################################
	-- Page 7: Driving settings
	courseplay.button:create(self, 7, 'navigate_left.png',  'changeLaneOffset', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -0.5, false);
	courseplay.button:create(self, 7, 'navigate_right.png', 'changeLaneOffset',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  0.5, false);
	courseplay.button:create(self, 7, nil, 'changeLaneOffset', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);

	courseplay.button:create(self, 7, 'blank.png', 'toggleSymmetricLaneChange', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], courseplay.hud.visibleArea.width, 0.015, 2, nil, true);

	courseplay.button:create(self, 7, 'navigate_left.png',  'changeToolOffsetX', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  -0.5, false);
	courseplay.button:create(self, 7, 'navigate_right.png', 'changeToolOffsetX',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,   0.5, false);
	courseplay.button:create(self, 7, nil, 'changeToolOffsetX', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 0.5, true, true);

	courseplay.button:create(self, 7, 'navigate_down.png', 'changeToolOffsetZ', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  -0.5, false);
	courseplay.button:create(self, 7, 'navigate_up.png',   'changeToolOffsetZ',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,   0.5, false);
	courseplay.button:create(self, 7, nil, 'changeToolOffsetZ', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 0.5, true, true);


	courseplay.button:create(self, 7, 'navigate_up.png',   'switchDriverCopy', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay.button:create(self, 7, 'navigate_down.png', 'switchDriverCopy',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay.button:create(self, 7, nil, nil, nil, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], 0.015 + w16px, mouseWheelArea.h, 5, nil, true, false);
	courseplay.button:create(self, 7, 'copy.png',          'copyCourse',      nil, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[6], w16px, h16px);


	-- ##################################################
	-- Page 8: Course generation
	-- Note: line 1 (field edges) will be applied in first updateTick() runthrough

	-- line 2 (workWidth)
	courseplay.button:create(self, 8, 'calculator.png', 'calculateWorkWidth',   nil, courseplay.hud.infoBasePosX + 0.270, courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  nil, false);
	courseplay.button:create(self, 8, 'navigate_minus.png', 'changeWorkWidth', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -0.5, false);
	courseplay.button:create(self, 8, 'navigate_plus.png',  'changeWorkWidth',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  0.5, false);
	courseplay.button:create(self, 8, nil, 'changeWorkWidth', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);

	-- line 3 (starting corner)
	courseplay.button:create(self, 8, 'blank.png', 'switchStartingCorner',     nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[3], courseplay.hud.visibleArea.width, 0.015, 3, nil, true);

	-- line 4 (starting direction)
	courseplay.button:create(self, 8, 'blank.png', 'switchStartingDirection',  nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[4], courseplay.hud.visibleArea.width, 0.015, 4, nil, true);

	-- line 5 (return to first point)
	courseplay.button:create(self, 8, 'blank.png', 'switchReturnToFirstPoint', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);

	-- line 6 (headland)
	-- 6.1 direction
	local headlandDirButtonIdx = courseplay.button:create(self, 8, 'headlandDirCW.png', 'setHeadlandDir', nil, courseplay.hud.infoBasePosX + 0.246 - w32px, courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, nil, false);
	self.cp.headland.directionButton = self.cp.buttons[8][headlandDirButtonIdx];
	courseplay.button:addOverlay(self.cp.headland.directionButton, 2, 'headlandDirCCW.png');

	-- 6.2 order --width = 2 x 0.015
	local headlandOrderButtonIdx = courseplay.button:create(self, 8, 'headlandOrderBefore.png', 'setHeadlandOrder', nil, courseplay.hud.infoBasePosX + 0.240, courseplay.hud.linesButtonPosY[6], w32px, h16px, 6, nil, false);
	self.cp.headland.orderButton = self.cp.buttons[8][headlandOrderButtonIdx];
	courseplay.button:addOverlay(self.cp.headland.orderButton, 2, 'headlandOrderAfter.png');

	-- 6.3: numLanes
	courseplay.button:create(self, 8, 'navigate_up.png',   'setHeadlandNumLanes',   1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, nil, false);
	courseplay.button:create(self, 8, 'navigate_down.png', 'setHeadlandNumLanes',  -1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, nil, false);

	-- generation action button
	courseplay.button:create(self, 8, 'pageNav_8.png', 'generateCourse', nil, listArrowX - 15/1920 - w24px - 15/1920 - w24px, courseplay.hud.infoBasePosY + 0.056, w24px, h24px, nil, nil, false);


	-- ##################################################
	-- Page 9: Shovel settings
	local wTemp = 22/1920;
	local hTemp = 22/1080;
	courseplay.button:create(self, 9, 'shovelLoading.png',      'saveShovelPosition', 2, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[1] - 0.003, wTemp, hTemp, 1, 2, true, false, true);
	courseplay.button:create(self, 9, 'shovelTransport.png',    'saveShovelPosition', 3, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[2] - 0.003, wTemp, hTemp, 2, 3, true, false, true);
	courseplay.button:create(self, 9, 'shovelPreUnloading.png', 'saveShovelPosition', 4, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[3] - 0.003, wTemp, hTemp, 3, 4, true, false, true);
	courseplay.button:create(self, 9, 'shovelUnloading.png',    'saveShovelPosition', 5, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[4] - 0.003, wTemp, hTemp, 4, 5, true, false, true);

	courseplay.button:create(self, 9, 'blank.png', 'setShovelStopAndGo', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);
	--END Page 9


	courseplay:validateCanSwitchMode(self);
	courseplay:buttonsActiveEnabled(self, 'all');
end

function courseplay:onLeave()
	if self.cp.mouseCursorActive then
		courseplay:setMouseCursor(self, false);
	end

	--hide visual i3D waypoint signs only when in vehicle
	courseplay.utils.signs:setSignsVisibility(self, false);
end

function courseplay:onEnter()
	if self.cp.mouseCursorActive then
		courseplay:setMouseCursor(self, true);
	end

	if self.drive and self.steeringEnabled then
	  self.steeringEnabled = false
	end

	--show visual i3D waypoint signs only when in vehicle
	courseplay.utils.signs:setSignsVisibility(self);
end

function courseplay:draw()
	--WORKWIDTH DISPLAY
	if self.cp.workWidthChanged > self.timer and self.cp.mode ~= 7 then
		courseplay:showWorkWidth(self);
	end;

	--DEBUG SHOW DIRECTIONNODE
	if courseplay.debugChannels[12] then
		-- For debugging when setting the directionNodeZOffset. (Visual points shown for old node)
		-- In specialTools.lua -> courseplay:setNameVariable(workTool), add the value "workTool.cp.showDirectionNode = true;" to the specific vehicle, while testing.
		if self.cp.oldDirectionNode and self.cp.showDirectionNode then
			local ox,oy,oz = getWorldTranslation(self.cp.oldDirectionNode);
			drawDebugPoint(ox, oy+4, oz, 0.9098, 0.6902 , 0.2706, 1);
		end;

		local nx,ny,nz = getWorldTranslation(self.cp.DirectionNode);
		drawDebugPoint(nx, ny+4, nz, 0.6196, 0.3490 , 0, 1);
	end;


	--KEYBOARD ACTIONS and HELP BUTTON TEXTS
	--Note: located in draw() instead of update() so they're not displayed/executed for *all* vehicles but rather only for *self*
	if self:getIsActive() and self.isEntered then
		local kb = courseplay.inputBindings.keyboard;
		local mouse = courseplay.inputBindings.mouse;

		if (self.cp.canDrive or not self.cp.hud.openWithMouse) and not InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
			g_currentMission:addHelpButtonText(courseplay:loc("COURSEPLAY_FUNCTIONS"), InputBinding.COURSEPLAY_MODIFIER);
		end;

		if self.cp.hud.show then
			if self.cp.mouseCursorActive then
				g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:loc("COURSEPLAY_MOUSEARROW_HIDE"));
			else
				g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:loc("COURSEPLAY_MOUSEARROW_SHOW"));
			end;
		end;

		if self.cp.hud.openWithMouse then
			if not self.cp.hud.show then
				g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:loc("COURSEPLAY_HUD_OPEN"));
			end;
		else
			if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
				if not self.cp.hud.show then
					g_currentMission:addHelpButtonText(courseplay:loc("COURSEPLAY_HUD_OPEN"), InputBinding.COURSEPLAY_HUD);
				else
					g_currentMission:addHelpButtonText(courseplay:loc("COURSEPLAY_HUD_CLOSE"), InputBinding.COURSEPLAY_HUD);
				end;
			end;

			if InputBinding.hasEvent(InputBinding.COURSEPLAY_HUD_COMBINED) then
				--courseplay:openCloseHud(self, not self.cp.hud.show);
				self:setCourseplayFunc("openCloseHud", not self.cp.hud.show);
			end;
		end;

		if self.cp.canDrive then
			if self.drive then
				if InputBinding.hasEvent(InputBinding.COURSEPLAY_START_STOP_COMBINED) then
					self:setCourseplayFunc("stop", nil, false, 1);
				elseif self.cp.HUD1wait and InputBinding.hasEvent(InputBinding.COURSEPLAY_CANCELWAIT_COMBINED) then
					self:setCourseplayFunc('cancelWait', true, false, 1);
				elseif self.cp.HUD1noWaitforFill and InputBinding.hasEvent(InputBinding.COURSEPLAY_DRIVENOW_COMBINED) then
					self:setCourseplayFunc("setIsLoaded", true, false, 1);
				end;

				if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
					g_currentMission:addHelpButtonText(courseplay:loc("COURSEPLAY_STOP_COURSE"), InputBinding.COURSEPLAY_START_STOP);
					if self.cp.HUD1wait then
						g_currentMission:addHelpButtonText(courseplay:loc("COURSEPLAY_CONTINUE"), InputBinding.COURSEPLAY_CANCELWAIT);
					end;
					if self.cp.HUD1noWaitforFill then
						g_currentMission:addHelpButtonText(courseplay:loc("COURSEPLAY_DRIVE_NOW"), InputBinding.COURSEPLAY_DRIVENOW);
					end;
				end;
			else
				if InputBinding.hasEvent(InputBinding.COURSEPLAY_START_STOP_COMBINED) then
					self:setCourseplayFunc("start", nil, false, 1);
				end;

				if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
					g_currentMission:addHelpButtonText(courseplay:loc("COURSEPLAY_START_COURSE"), InputBinding.COURSEPLAY_START_STOP);
				end;
			end;
		end;
	end; -- self:getIsActive() and self.isEntered

	--RENDER
	courseplay:renderInfoText(self);
	
	if self:getIsActive() then
		if self.cp.hud.show then
			courseplay:setHudContent(self);
			courseplay:renderHud(self);
			if self.cp.distanceCheck and (self.drive or (not self.cp.canDrive and not self.cp.isRecording and not self.cp.recordingIsPaused)) then -- turn off findFirstWaypoint when driving or no course loaded
				courseplay:toggleFindFirstWaypoint(self);
			end;

			if self.cp.mouseCursorActive then
				InputBinding.setShowMouseCursor(self.cp.mouseCursorActive);
			end;
		end;
		if self.cp.distanceCheck and #(self.Waypoints) > 1 then
			courseplay:distanceCheck(self);
		end;
	end;
end; --END draw()

function courseplay:showWorkWidth(vehicle)
	local left =  vehicle.cp.workWidthDisplayPoints.left;
	local right = vehicle.cp.workWidthDisplayPoints.right;
	drawDebugPoint(left.x, left.y, left.z, 1, 1, 0, 1);
	drawDebugPoint(right.x, right.y, right.z, 1, 1, 0, 1);
	drawDebugLine(left.x, left.y, left.z, 1, 0, 0, right.x, right.y, right.z, 1, 0, 0);
end;

function courseplay:drawWaypointsLines(vehicle)
	if not courseplay.isDeveloper or not vehicle.isControlled then return; end;

	local height = 2.5;
	for i,wp in pairs(vehicle.Waypoints) do
		if wp.cy == nil or wp.cy == 0 then
			wp.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.cx, 1, wp.cz);
		end;
		local np = vehicle.Waypoints[i+1];
		if np and (np.cy == nil or np.cy == 0) then
			np.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, np.cx, 1, np.cz);
		end;

		if i == 1 then
			drawDebugPoint(wp.cx, wp.cy + height, wp.cz, 0, 1, 0, 1);
		elseif i == vehicle.maxnumber then
			drawDebugPoint(wp.cx, wp.cy + height, wp.cz, 1, 0, 0, 1);
		else
			drawDebugPoint(wp.cx, wp.cy + height, wp.cz, 1, 1, 0, 1);
		end;

		if i < vehicle.maxnumber then
			drawDebugLine(wp.cx, wp.cy + height, wp.cz, 0, 1, 1, np.cx, np.cy + height, np.cz, 0, 1, 1);
		end;
	end;
end;

-- is being called every loop
function courseplay:update(dt)
	if g_server ~= nil and (self.drive or self.cp.isRecording or self.cp.recordingIsPaused) then
		self.cp.infoText = nil;
	end;

	if self.cp.drawWaypointsLines then
		courseplay:drawWaypointsLines(self);
	end;

	-- we are in record mode
	if self.cp.isRecording then
		courseplay:record(self);
	end;

	-- we are in drive mode and single player /MP server
	if self.drive and g_server ~= nil then
		for refIdx,_ in pairs(courseplay.globalInfoText.msgReference) do
			self.cp.hasSetGlobalInfoTextThisLoop[refIdx] = false;
		end;

		courseplay:drive(self, dt);

		for refIdx,_ in pairs(self.cp.activeGlobalInfoTexts) do
			if not self.cp.hasSetGlobalInfoTextThisLoop[refIdx] then
				courseplay:setGlobalInfoText(self, refIdx, true); --force remove
			end;
		end;
	end
	 
	if self.cp.onSaveClick and not self.cp.doNotOnSaveClick then
		inputCourseNameDialogue:onSaveClick()
		self.cp.onSaveClick = false
		self.cp.doNotOnSaveClick = false
	end
	if self.cp.onMpSetCourses then
		courseplay.courses.reload(self)
		self.cp.onMpSetCourses = nil
	end

	if g_server ~= nil then
		self.cp.HUDrecordnumber = self.recordnumber
		if self.drive then
			self.cp.HUD1wait = (self.Waypoints[self.cp.lastRecordnumber] ~= nil and self.Waypoints[self.cp.lastRecordnumber].wait and self.wait) or (self.cp.stopAtEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil));
			self.cp.HUD1noWaitforFill = not self.cp.isLoaded and self.cp.mode ~= 5;
			--[[ TODO (Jakob):
				* rename to "HUD1waitForFill"
				* should only be applicable in following situations:
					** mode 1: waypoint 1 (being filled)
					** mode 2: waiting for fill/unloading combine
					** mode 3: unloading at wait point 3
					** mode 4: refilling in trigger/at wait point 3
					** mode 6: on field
					** mode 7: ai threshing / unloading at wait point
			]]
		end;

		if self.cp.hud.currentPage == 0 then
			local combine = self;
			if self.cp.attachedCombineIdx ~= nil and self.tippers ~= nil and self.tippers[self.cp.attachedCombineIdx] ~= nil then
				combine = self.tippers[self.cp.attachedCombineIdx];
			end;
			if combine.courseplayers == nil then
				self.cp.HUD0noCourseplayer = true
				combine.courseplayers = {};
			else
				self.cp.HUD0noCourseplayer = table.getn(combine.courseplayers) == 0
			end
			self.cp.HUD0wantsCourseplayer = combine.cp.wantsCourseplayer
			self.cp.HUD0combineForcedSide = combine.cp.forcedSide
			self.cp.HUD0isManual = not self.drive and not combine.isAIThreshing 
			self.cp.HUD0turnStage = self.cp.turnStage
			local tractor = combine.courseplayers[1]
			if tractor ~= nil then
				self.cp.HUD0tractorForcedToStop = tractor.cp.forcedToStop
				self.cp.HUD0tractorName = tostring(tractor.name)
				self.cp.HUD0tractor = true
			else
				self.cp.HUD0tractorForcedToStop = nil
				self.cp.HUD0tractorName = nil
				self.cp.HUD0tractor = false
			end;

		elseif self.cp.hud.currentPage == 1 then
			if self:getIsActive() and not self.cp.canDrive and self.cp.fieldEdge.customField.show and self.cp.fieldEdge.customField.points ~= nil then
				courseplay:showFieldEdgePath(self, "customField");
			end;


		elseif self.cp.hud.currentPage == 4 then
			self.cp.HUD4hasActiveCombine = self.cp.activeCombine ~= nil
			if self.cp.HUD4hasActiveCombine == true then
				self.cp.HUD4combineName = self.cp.activeCombine.name
			end
			self.cp.HUD4savedCombine = self.cp.savedCombine ~= nil and self.cp.savedCombine.rootNode ~= nil
			if self.cp.savedCombine ~= nil then
				-- self.cp.HUD4savedCombineName = self.cp.savedCombine.name
			end

		elseif self.cp.hud.currentPage == 8 then
			if self:getIsActive() and self.cp.fieldEdge.selectedField.show and self.cp.fieldEdge.selectedField.fieldNum > 0 then
				courseplay:showFieldEdgePath(self, "selectedField");
			end;
		end;
	end;

	if g_server ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer then 
		for k,v in pairs(courseplay.checkValues) do
			self.cp[v .. "Memory"] = courseplay:checkForChangeAndBroadcast(self, "self.cp." .. v , self.cp[v], self.cp[v .. "Memory"]);
		end;
	end;
end; --END update()

function courseplay:updateTick(dt)
	if not self.cp.fieldEdge.selectedField.buttonsCreated and courseplay.fields.numAvailableFields > 0 then
		courseplay:createFieldEdgeButtons(self);
	end;

	--attached or detached implement?
	if self.cp.toolsDirty then
		courseplay:reset_tools(self)
	end

	self.timer = self.timer + dt
	--courseplay:debug(string.format("timer: %f", self.timer ), 2)
end

function courseplay:preDelete()
	if self.cp ~= nil and self.cp.numActiveGlobalInfoTexts ~= 0 then
		for refIdx,_ in pairs(courseplay.globalInfoText.msgReference) do
			if self.cp.activeGlobalInfoTexts[refIdx] ~= nil then
				courseplay:setGlobalInfoText(self, refIdx, true);
				-- print(('%s: preDelete(): self.cp.activeGlobalInfoTexts[%s]=%s'):format(nameNum(self), tostring(refIdx), tostring(self.cp.activeGlobalInfoTexts[refIdx])));
			end;
			self.cp.hasSetGlobalInfoTextThisLoop[refIdx] = false;
		end;
	end;
end;

function courseplay:delete()
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end;
	for i,trigger in pairs(self.cp.trafficCollisionTriggers) do
		removeTrigger(trigger);
	end;

	if self.cp ~= nil then
		if self.cp.headland and self.cp.headland.tg then
			unlink(self.cp.headland.tg);
			delete(self.cp.headland.tg);
			self.cp.headland.tg = nil;
		end;

		if self.cp.hud.background ~= nil then
			self.cp.hud.background:delete();
		end;
		if self.cp.hud.backgroundSuc ~= nil then
			self.cp.hud.backgroundSuc:delete();
		end;
		if self.cp.directionArrowOverlay ~= nil then
			self.cp.directionArrowOverlay:delete();
		end;
		if self.cp.buttons ~= nil then
			courseplay.button:deleteButtonOverlays(self);
		end;
		if self.cp.globalInfoTextOverlay ~= nil then
			self.cp.globalInfoTextOverlay:delete();
		end;
		if self.cp.signs ~= nil then
			for _,section in pairs(self.cp.signs) do
				for k,signData in pairs(section) do
					courseplay.utils.signs:deleteSign(signData.sign);
				end;
			end;
			self.cp.signs = nil;
		end;
	end;
end;

function courseplay:set_timeout(vehicle, interval)
	vehicle.cp.timeOut = vehicle.timer + interval;
end;


function courseplay:readStream(streamId, connection)
	courseplay:debug("id: "..tostring(self.id).."  base: readStream", 5)
	
	self.cp.automaticCoverHandling = streamDebugReadBool(streamId);
	self.cp.automaticUnloadingOnField = streamDebugReadBool(streamId);
	self.cp.mode = streamDebugReadInt32(streamId)
	self.cp.turnRadiusAuto = streamDebugReadFloat32(streamId)
	self.cp.canDrive = streamDebugReadBool(streamId);
	self.cp.combineOffsetAutoMode = streamDebugReadBool(streamId);
	self.cp.combineOffset = streamDebugReadFloat32(streamId)
	self.cp.currentCourseName = streamDebugReadString(streamId);
	self.cp.driverPriorityUseFillLevel = streamDebugReadBool(streamId);
	self.cp.drivingDirReverse = streamDebugReadBool(streamId);
	self.cp.fieldEdge.customField.isCreated = streamDebugReadBool(streamId);
	self.cp.fieldEdge.customField.fieldNum = streamDebugReadInt32(streamId)
	self.cp.fieldEdge.customField.selectedFieldNumExists = streamDebugReadBool(streamId)
	self.cp.fieldEdge.selectedField.fieldNum = streamDebugReadInt32(streamId) 
	self.cp.globalInfoTextLevel = streamDebugReadInt32(streamId)
	self.cp.hasBaleLoader = streamDebugReadBool(streamId);
	self.cp.hasStartingCorner = streamDebugReadBool(streamId);
	self.cp.hasStartingDirection = streamDebugReadBool(streamId);
	self.cp.hasValidCourseGenerationData = streamDebugReadBool(streamId);
	self.cp.headland.numLanes = streamDebugReadInt32(streamId)
	self.cp.hud.currentPage = streamDebugReadInt32(streamId)
    self.cp.hasUnloadingRefillingCourse	 = streamDebugReadBool(streamId);
	self.cp.infoText = streamDebugReadString(streamId);
	self.cp.returnToFirstPoint = streamDebugReadBool(streamId);
	self.cp.ridgeMarkersAutomatic = streamDebugReadBool(streamId);
	self.cp.shovelStopAndGo = streamDebugReadBool(streamId);
	self.cp.startAtFirstPoint = streamDebugReadBool(streamId);
	self.cp.stopAtEnd = streamDebugReadBool(streamId);
	self.drive = streamDebugReadBool(streamId)
	self.cp.hud.openWithMouse = streamDebugReadBool(streamId)
	self.cp.realisticDriving = streamDebugReadBool(streamId);
	self.cp.driveOnAtFillLevel = streamDebugReadFloat32(streamId)
	self.cp.followAtFillLevel = streamDebugReadFloat32(streamId)
	self.cp.refillUntilPct = streamDebugReadFloat32(streamId)
	self.cp.tipperOffset = streamDebugReadFloat32(streamId)
	self.cp.tipperHasCover = streamDebugReadBool(streamId);
	self.cp.workWidth = streamDebugReadFloat32(streamId) 
	self.cp.turnRadiusAutoMode = streamDebugReadBool(streamId);
	self.cp.turnRadius = streamDebugReadFloat32(streamId)
	self.cp.speeds.useRecordingSpeed = streamDebugReadBool(streamId) 
	self.cp.coursePlayerNum = streamReadFloat32(streamId)
	self.cp.laneOffset = streamDebugReadFloat32(streamId)
	self.cp.toolOffsetX = streamDebugReadFloat32(streamId)
	self.cp.toolOffsetZ = streamDebugReadFloat32(streamId)
	self.cp.hud.currentPage = streamDebugReadInt32(streamId)
	self.cp.HUDrecordnumber = streamDebugReadInt32(streamId)
	self.cp.HUD0noCourseplayer = streamDebugReadBool(streamId)
	self.cp.HUD0wantsCourseplayer = streamDebugReadBool(streamId)
	self.cp.HUD0combineForcedSide = streamDebugReadString(streamId);
	self.cp.HUD0isManual = streamDebugReadBool(streamId)
	self.cp.HUD0turnStage = streamDebugReadInt32(streamId)
	self.cp.HUD0tractorForcedToStop = streamDebugReadBool(streamId)
	self.cp.HUD0tractorName = streamDebugReadString(streamId);
	self.cp.HUD0tractor = streamDebugReadBool(streamId)
	self.cp.HUD1wait = streamDebugReadBool(streamId)
	self.cp.HUD1noWaitforFill = streamDebugReadBool(streamId)
	self.cp.HUD4hasActiveCombine = streamDebugReadBool(streamId)
	self.cp.HUD4combineName = streamDebugReadString(streamId);
	self.cp.HUD4savedCombine = streamDebugReadBool(streamId)
	self.cp.HUD4savedCombineName = streamDebugReadString(streamId);
	courseplay:setRecordNumber(self, streamDebugReadInt32(streamId));
	self.cp.isRecording = streamDebugReadBool(streamId)
	self.cp.recordingIsPaused = streamDebugReadBool(streamId)
	self.cp.searchCombineAutomatically = streamDebugReadBool(streamId)
	self.cp.searchCombineOnField = streamDebugReadInt32(streamId)
	self.cp.speeds.turn = streamDebugReadFloat32(streamId)
	self.cp.speeds.field = streamDebugReadFloat32(streamId)
	self.cp.speeds.unload = streamDebugReadFloat32(streamId)
	self.cp.speeds.street = streamDebugReadFloat32(streamId)
	self.cp.visualWaypointsMode = streamDebugReadInt32(streamId)
	self.cp.beaconLightsMode = streamDebugReadInt32(streamId)
	self.cp.waitTime = streamDebugReadInt32(streamId)
	self.cp.symmetricLaneChange = streamDebugReadBool(streamId)
	self.cp.startingCorner = streamDebugReadInt32(streamId)
	self.cp.startingDirection = streamDebugReadInt32(streamId)
	self.cp.hasShovelStatePositions[2] = streamDebugReadBool(streamId)
	self.cp.hasShovelStatePositions[3] = streamDebugReadBool(streamId)
	self.cp.hasShovelStatePositions[4] = streamDebugReadBool(streamId)
	self.cp.hasShovelStatePositions[5] = streamDebugReadBool(streamId) 
	
	local copyCourseFromDriverId = streamDebugReadInt32(streamId)
	if copyCourseFromDriverId then
		self.cp.copyCourseFromDriver = networkGetObject(copyCourseFromDriverId) 
	end
		
	local savedCombineId = streamDebugReadInt32(streamId)
	if savedCombineId then
		self.cp.savedCombine = networkGetObject(savedCombineId)
	end

	local activeCombineId = streamDebugReadInt32(streamId)
	if activeCombineId then
		self.cp.activeCombine = networkGetObject(activeCombineId)
	end

	local current_trailer_id = streamDebugReadInt32(streamId)
	if current_trailer_id then
		self.cp.currentTrailerToFill = networkGetObject(current_trailer_id)
	end

	local unloading_tipper_id = streamDebugReadInt32(streamId)
	if unloading_tipper_id then
		self.cp.unloadingTipper = networkGetObject(unloading_tipper_id)
	end

	courseplay:reinit_courses(self)


	-- kurs daten
	local courses = streamDebugReadString(streamId) -- 60.
	if courses ~= nil then
		self.cp.loadedCourses = Utils.splitString(",", courses);
		courseplay:reload_courses(self, true)
	end

	local debugChannelsString = streamDebugReadString(streamId)
	for k,v in pairs(Utils.splitString(",", debugChannelsString)) do
		courseplay.debugChannels[k] = v == "true";
	end;
	courseplay:debug("id: "..tostring(self.id).."  base: readStream end", 5)
end

function courseplay:writeStream(streamId, connection)
	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write stream", 5)
	streamDebugWriteBool(streamId, self.cp.automaticCoverHandling)
	streamDebugWriteBool(streamId, self.cp.automaticUnloadingOnField)
	streamDebugWriteInt32(streamId,self.cp.mode)
	streamDebugWriteFloat32(streamId,self.cp.turnRadiusAuto)
	streamDebugWriteBool(streamId, self.cp.canDrive)
	streamDebugWriteBool(streamId, self.cp.combineOffsetAutoMode);
	streamDebugWriteFloat32(streamId,self.cp.combineOffset)
	streamDebugWriteString(streamId, self.cp.currentCourseName);
	streamDebugWriteBool(streamId, self.cp.driverPriorityUseFillLevel);
	streamDebugWriteBool(streamId, self.cp.drivingDirReverse)
	streamDebugWriteBool(streamId, self.cp.fieldEdge.customField.isCreated)
	streamDebugWriteInt32(streamId,self.cp.fieldEdge.customField.fieldNum)
	streamDebugWriteBool(streamId, self.cp.fieldEdge.customField.selectedFieldNumExists)
	streamDebugWriteInt32(streamId, self.cp.fieldEdge.selectedField.fieldNum)
	streamDebugWriteInt32(streamId, self.cp.globalInfoTextLevel);
	streamDebugWriteBool(streamId, self.cp.hasBaleLoader)
	streamDebugWriteBool(streamId, self.cp.hasStartingCorner);
	streamDebugWriteBool(streamId, self.cp.hasStartingDirection);
	streamDebugWriteBool(streamId, self.cp.hasValidCourseGenerationData);
	streamDebugWriteInt32(streamId,self.cp.headland.numLanes);
	streamDebugWriteInt32(streamId,self.cp.hud.currentPage);
	streamDebugWriteBool(streamId, self.cp.hasUnloadingRefillingCourse)
	streamDebugWriteString(streamId, self.cp.infoText);
	streamDebugWriteBool(streamId, self.cp.returnToFirstPoint);
	streamDebugWriteBool(streamId, self.cp.ridgeMarkersAutomatic);
	streamDebugWriteBool(streamId, self.cp.shovelStopAndGo);
	streamDebugWriteBool(streamId, self.cp.startAtFirstPoint)
	streamDebugWriteBool(streamId, self.cp.stopAtEnd)
	streamDebugWriteBool(streamId,self.drive)
	streamDebugWriteBool(streamId,self.cp.hud.openWithMouse)
	streamDebugWriteBool(streamId, self.cp.realisticDriving);
	streamDebugWriteFloat32(streamId,self.cp.driveOnAtFillLevel)
	streamDebugWriteFloat32(streamId,self.cp.followAtFillLevel)
	streamDebugWriteFloat32(streamId,self.cp.refillUntilPct)
	streamDebugWriteFloat32(streamId,self.cp.tipperOffset)
	streamDebugWriteBool(streamId, self.cp.tipperHasCover)
	streamDebugWriteFloat32(streamId,self.cp.workWidth);
	streamDebugWriteBool(streamId,self.cp.turnRadiusAutoMode)
	streamDebugWriteFloat32(streamId,self.cp.turnRadius)
	streamDebugWriteBool(streamId,self.cp.speeds.useRecordingSpeed)
	streamDebugWriteFloat32(streamId,self.cp.coursePlayerNum);
	streamDebugWriteFloat32(streamId,self.cp.laneOffset)
	streamDebugWriteFloat32(streamId,self.cp.toolOffsetX)
	streamDebugWriteFloat32(streamId,self.cp.toolOffsetZ)
	streamDebugWriteInt32(streamId,self.cp.hud.currentPage)
	streamDebugWriteInt32(streamId,self.cp.HUDrecordnumber)
	streamDebugWriteBool(streamId,self.cp.HUD0noCourseplayer)
	streamDebugWriteBool(streamId,self.cp.HUD0wantsCourseplayer)
	streamDebugWriteString(streamId,self.cp.HUD0combineForcedSide)
	streamDebugWriteBool(streamId,self.cp.HUD0isManual)
	streamDebugWriteInt32(streamId,self.cp.HUD0turnStage)
	streamDebugWriteBool(streamId,self.cp.HUD0tractorForcedToStop)
	streamDebugWriteString(streamId,self.cp.HUD0tractorName)
	streamDebugWriteBool(streamId,self.cp.HUD0tractor)
	streamDebugWriteBool(streamId,self.cp.HUD1wait)
	streamDebugWriteBool(streamId,self.cp.HUD1noWaitforFill)
	streamDebugWriteBool(streamId,self.cp.HUD4hasActiveCombine)
	streamDebugWriteString(streamId,self.cp.HUD4combineName)
	streamDebugWriteBool(streamId,self.cp.HUD4savedCombine)
	streamDebugWriteString(streamId,self.cp.HUD4savedCombineName)
	streamDebugWriteInt32(streamId,self.recordnumber)
	streamDebugWriteBool(streamId,self.cp.isRecording)
	streamDebugWriteBool(streamId,self.cp.recordingIsPaused)
	streamDebugWriteBool(streamId,self.cp.searchCombineAutomatically)
	streamDebugWriteInt32(streamId,self.cp.searchCombineOnField)
	streamDebugWriteFloat32(streamId,self.cp.speeds.turn)
	streamDebugWriteFloat32(streamId,self.cp.speeds.field)
	streamDebugWriteFloat32(streamId,self.cp.speeds.unload)
	streamDebugWriteFloat32(streamId,self.cp.speeds.street)
	streamDebugWriteInt32(streamId,self.cp.visualWaypointsMode)
	streamDebugWriteInt32(streamId,self.cp.beaconLightsMode)
	streamDebugWriteInt32(streamId,self.cp.waitTime)
	streamDebugWriteBool(streamId,self.cp.symmetricLaneChange)
	streamDebugWriteInt32(streamId,self.cp.startingCorner)
	streamDebugWriteInt32(streamId,self.cp.startingDirection)
	streamDebugWriteBool(streamId,self.cp.hasShovelStatePositions[2])
	streamDebugWriteBool(streamId,self.cp.hasShovelStatePositions[3])
	streamDebugWriteBool(streamId,self.cp.hasShovelStatePositions[4])
	streamDebugWriteBool(streamId,self.cp.hasShovelStatePositions[5])
	
	local copyCourseFromDriverID;
	if self.cp.copyCourseFromDriver ~= nil then
		copyCourseFromDriverID = networkGetObject(self.cp.copyCourseFromDriver)
	end
	streamDebugWriteInt32(streamId, copyCourseFromDriverID)
	
	
	local savedCombineId;
	if self.cp.savedCombine ~= nil then
		savedCombineId = networkGetObject(self.cp.savedCombine)
	end
	streamDebugWriteInt32(streamId, savedCombineId)

	local activeCombineId;
	if self.cp.activeCombine ~= nil then
		activeCombineId = networkGetObject(self.cp.activeCombine)
	end
	streamDebugWriteInt32(streamId, activeCombineId)

	local current_trailer_id;
	if self.cp.currentTrailerToFill ~= nil then
		current_trailer_id = networkGetObject(self.cp.currentTrailerToFill)
	end
	streamDebugWriteInt32(streamId, current_trailer_id)

	local unloading_tipper_id;
	if self.cp.unloadingTipper ~= nil then
		unloading_tipper_id = networkGetObject(self.cp.unloadingTipper)
	end
	streamDebugWriteInt32(streamId, unloading_tipper_id)

	local loadedCourses;
	if #self.cp.loadedCourses then
		loadedCourses = table.concat(self.cp.loadedCourses, ",")
	end
	streamDebugWriteString(streamId, loadedCourses) -- 60.

	local debugChannelsString = table.concat(table.map(courseplay.debugChannels, tostring), ",");
	streamDebugWriteString(streamId, debugChannelsString) 

	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write stream end", 5)
end


function courseplay:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles and g_server ~= nil then
		-- COURSEPLAY
		local curKey = key .. '.courseplay';
		courseplay:setCpMode(self, Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#aiMode'), 1));
		self.cp.hud.openWithMouse = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#openHudWithMouse'), true);
		self.cp.beaconLightsMode = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#beacon'), 1);
		self.cp.waitTime = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#waitTime'), 0);
		local courses = Utils.getNoNil(getXMLString(xmlFile, curKey .. '#courses'), '');
		self.cp.loadedCourses = Utils.splitString(",", courses);
		courseplay:reload_courses(self, true);
		local visualWaypointsMode = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#visualWaypoints'), 1);
		courseplay:changeVisualWaypointsMode(self, 0, visualWaypointsMode);
		self.cp.multiSiloSelectedFillType = Fillable.fillTypeNameToInt[Utils.getNoNil(getXMLString(xmlFile, curKey .. '#multiSiloSelectedFillType'), 'unknown')];
		if self.cp.multiSiloSelectedFillType == nil then self.cp.multiSiloSelectedFillType = Fillable.FILLTYPE_UNKNOWN; end;

		-- SPEEDS
		curKey = key .. '.courseplay.speeds';
		self.cp.speeds.useRecordingSpeed = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#useRecordingSpeed'), true);
		self.cp.speeds.unload = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#unload'), 6);
		self.cp.speeds.turn = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#turn'), 10);
		self.cp.speeds.field = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#field'), 24);
		self.cp.speeds.street = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#max'), 50);

		-- MODE 2
		curKey = key .. '.courseplay.combi';
		self.cp.tipperOffset = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#tipperOffset'), 0);
		self.cp.combineOffset = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#combineOffset'), 0);
		self.cp.combineOffsetAutoMode = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#combineOffsetAutoMode'), true);
		self.cp.followAtFillLevel = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#fillFollow'), 50);
		self.cp.driveOnAtFillLevel = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#fillDriveOn'), 90);
		self.cp.turnRadius = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#turnRadius'), 10);
		self.cp.realisticDriving = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#realisticDriving'), true);

		-- MODES 4 / 6
		curKey = key .. '.courseplay.fieldWork';
		self.cp.workWidth = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#workWidth'), 3);
		self.cp.ridgeMarkersAutomatic = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#ridgeMarkersAutomatic'), true);
		self.cp.abortWork = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#abortWork'), 0);
		if self.cp.abortWork == 0 then
			self.cp.abortWork = nil;
		end;
		self.cp.refillUntilPct = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#refillUntilPct'), 100);
		local offsetData = Utils.getNoNil(getXMLString(xmlFile, curKey .. '#offsetData'), '0;0;0;false'); -- 1=laneOffset, 2=toolOffsetX, 3=toolOffsetZ, 4=symmetricalLaneChange
		offsetData = Utils.splitString(';', offsetData);
		courseplay:changeLaneOffset(self, nil, tonumber(offsetData[1]));
		courseplay:changeToolOffsetX(self, nil, tonumber(offsetData[2]), true);
		courseplay:changeToolOffsetZ(self, nil, tonumber(offsetData[3]));
		courseplay:toggleSymmetricLaneChange(self, offsetData[4] == 'true');

		-- SHOVEL POSITIONS
		curKey = key .. '.courseplay.shovel';
		local shovelRots = getXMLString(xmlFile, curKey .. '#rot');
		local shovelTrans = getXMLString(xmlFile, curKey .. '#trans');
		courseplay:debug(tableShow(self.cp.shovelStatePositions, nameNum(self) .. ' shovelStatePositions (before loading)', 10), 10);
		if shovelRots and shovelTrans then
			self.cp.shovelStatePositions = {};
			shovelRots = Utils.splitString(';', shovelRots);
			shovelTrans = Utils.splitString(';', shovelTrans);
			if #shovelRots == 4 and #shovelTrans == 4 then
				for state=2, 5 do
					local shovelRotsSplit = table.map(Utils.splitString(' ', shovelRots[state-1]), tonumber);
					local shovelTransSplit = table.map(Utils.splitString(' ', shovelTrans[state-1]), tonumber);
					if shovelRotsSplit and shovelTransSplit then
						self.cp.shovelStatePositions[state] = {
							rot = shovelRotsSplit,
							trans = shovelTransSplit
						};
					end;
					self.cp.hasShovelStatePositions[state] = self.cp.shovelStatePositions[state] ~= nil and self.cp.shovelStatePositions[state].rot ~= nil and self.cp.shovelStatePositions[state].trans ~= nil; --TODO (Jakob): divide into rot and trans as well?
				end;
			end;
		end;
		courseplay:debug(tableShow(self.cp.shovelStatePositions, nameNum(self) .. ' shovelStatePositions (after loading)', 10), 10);
		courseplay:buttonsActiveEnabled(self, 'shovel');

		-- COMBINE
		if self.cp.isCombine then
			curKey = key .. '.courseplay.combine';
			self.cp.driverPriorityUseFillLevel = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#driverPriorityUseFillLevel'), false);
			self.cp.stopWhenUnloading = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#stopWhenUnloading'), false);
		end;


		courseplay:validateCanSwitchMode(self);
	end;
	return BaseMission.VEHICLE_LOAD_OK;
end


function courseplay:getSaveAttributesAndNodes(nodeIdent)
	local attributes = '';

	--Shovel positions (<shovel rot="1;2;3;4" trans="1;2;3;4" />)
	local shovelRotsAttrNodes, shovelTransAttrNodes;
	local shovelRotsTmp, shovelTransTmp = {}, {};
	if self.cp.shovelStatePositions and self.cp.shovelStatePositions[2] and self.cp.shovelStatePositions[3] and self.cp.shovelStatePositions[4] and self.cp.shovelStatePositions[5] then
		if self.cp.shovelStatePositions[2].rot and self.cp.shovelStatePositions[3].rot and self.cp.shovelStatePositions[4].rot and self.cp.shovelStatePositions[5].rot then
			local shovelStateRotSaveTable = {};
			for a=1,4 do
				shovelStateRotSaveTable[a] = {};
				local rotTable = self.cp.shovelStatePositions[a+1].rot;
				for i=1,#rotTable do
					shovelStateRotSaveTable[a][i] = courseplay:round(rotTable[i], 4);
				end;
				table.insert(shovelRotsTmp, tostring(table.concat(shovelStateRotSaveTable[a], ' ')));
			end;
			if #shovelRotsTmp > 0 then
				shovelRotsAttrNodes = tostring(table.concat(shovelRotsTmp, ';'));
				courseplay:debug(nameNum(self) .. ": shovelRotsAttrNodes=" .. shovelRotsAttrNodes, 10);
			end;
		end;
		if self.cp.shovelStatePositions[2].trans and self.cp.shovelStatePositions[3].trans and self.cp.shovelStatePositions[4].trans and self.cp.shovelStatePositions[5].trans then
			local shovelStateTransSaveTable = {};
			for a=1,4 do
				shovelStateTransSaveTable[a] = {};
				local transTable = self.cp.shovelStatePositions[a+1].trans;
				for i=1,#transTable do
					shovelStateTransSaveTable[a][i] = courseplay:round(transTable[i], 4);
				end;
				table.insert(shovelTransTmp, tostring(table.concat(shovelStateTransSaveTable[a], ' ')));
			end;
			if #shovelTransTmp > 0 then
				shovelTransAttrNodes = tostring(table.concat(shovelTransTmp, ';'));
				courseplay:debug(nameNum(self) .. ": shovelTransAttrNodes=" .. shovelTransAttrNodes, 10);
			end;
		end;
	end;

	--Offset data
	local offsetData = string.format('%.1f;%.1f;%.1f;%s', self.cp.laneOffset, self.cp.toolOffsetX, self.cp.toolOffsetZ, tostring(self.cp.symmetricLaneChange));


	--NODES
	local cpOpen = string.format('<courseplay aiMode=%q courses=%q openHudWithMouse=%q beacon=%q visualWaypoints=%q waitTime=%q multiSiloSelectedFillType=%q>', tostring(self.cp.mode), tostring(table.concat(self.cp.loadedCourses, ",")), tostring(self.cp.hud.openWithMouse), tostring(self.cp.beaconLightsMode), tostring(self.cp.visualWaypointsMode), tostring(self.cp.waitTime), Fillable.fillTypeIntToName[self.cp.multiSiloSelectedFillType]);
	local speeds = string.format('<speeds useRecordingSpeed=%q unload="%.5f" turn="%.5f" field="%.5f" max="%.5f" />', tostring(self.cp.speeds.useRecordingSpeed), self.cp.speeds.unload, self.cp.speeds.turn, self.cp.speeds.field, self.cp.speeds.street);
	local combi = string.format('<combi tipperOffset="%.1f" combineOffset="%.1f" combineOffsetAutoMode=%q fillFollow="%d" fillDriveOn="%d" turnRadius="%d" realisticDriving=%q />', self.cp.tipperOffset, self.cp.combineOffset, tostring(self.cp.combineOffsetAutoMode), self.cp.followAtFillLevel, self.cp.driveOnAtFillLevel, self.cp.turnRadius, tostring(self.cp.realisticDriving));
	local fieldWork = string.format('<fieldWork workWidth="%.1f" ridgeMarkersAutomatic=%q offsetData=%q abortWork="%d" refillUntilPct="%d" />', self.cp.workWidth, tostring(self.cp.ridgeMarkersAutomatic), offsetData, Utils.getNoNil(self.cp.abortWork, 0), self.cp.refillUntilPct);
	local shovels, combine = '', '';
	if shovelRotsAttrNodes or shovelTransAttrNodes then
		shovels = string.format('<shovel rot=%q trans=%q />', shovelRotsAttrNodes, shovelTransAttrNodes);
	end;
	if self.cp.isCombine then
		combine = string.format('<combine driverPriorityUseFillLevel=%q stopWhenUnloading=%q />', tostring(self.cp.driverPriorityUseFillLevel), tostring(self.cp.stopWhenUnloading));
	end;
	local cpClose = '</courseplay>';

	local indent = '   ';
	local nodes = nodeIdent .. cpOpen .. '\n';
	nodes = nodes .. nodeIdent .. indent .. speeds .. '\n';
	nodes = nodes .. nodeIdent .. indent .. combi .. '\n';
	nodes = nodes .. nodeIdent .. indent .. fieldWork .. '\n';
	if shovelRotsAttrNodes or shovelTransAttrNodes then
		nodes = nodes .. nodeIdent .. indent .. shovels .. '\n';
	end;
	if self.cp.isCombine then
		nodes = nodes .. nodeIdent .. indent .. combine .. '\n';
	end;
	nodes = nodes .. nodeIdent .. cpClose;

	courseplay:debug(nameNum(self) .. ": getSaveAttributesAndNodes(): nodes\n" .. nodes, 10)

	return attributes, nodes;
end

