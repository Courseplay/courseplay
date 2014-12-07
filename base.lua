function courseplay.prerequisitesPresent(specializations)
	return true;
end

function courseplay:load(xmlFile)
	self.setCourseplayFunc = courseplay.setCourseplayFunc;
	self.getIsCourseplayDriving = courseplay.getIsCourseplayDriving;
	self.setIsCourseplayDriving = courseplay.setIsCourseplayDriving;


	--SEARCH AND SET self.name IF NOT EXISTING
	if self.name == nil then
		self.name = courseplay:getObjectName(self, xmlFile);
	end;

	if self.cp == nil then self.cp = {}; end;
	self.cp.hasCourseplaySpec = true;

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

	self.cp.combineOffsetAutoMode = true
	self.cp.isDriving = false;
	self.cp.runOnceStartCourse = false;
	self.cp.stopAtEnd = false;
	self.cp.calculatedCourseToCombine = false

	self.recordnumber = 1;
	self.cp.lastRecordnumber = 1;
	self.cp.recordingTimer = 1
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
	-- saves the shortest distance to the next waypoint (for recocnizing circling)
	self.cp.shortestDistToWp = nil

	self.Waypoints = {}

	self.cp.canDrive = false --can drive course (has >4 waypoints, is not recording)
	self.cp.coursePlayerNum = nil;

	self.cp.infoText = nil; -- info text in tractor
	self.cp.toolTip = nil;

	-- global info text - also displayed when not in vehicle
	self.cp.hasSetGlobalInfoTextThisLoop = {};
	self.cp.activeGlobalInfoTexts = {};
	self.cp.numActiveGlobalInfoTexts = 0;



	-- CP mode
	self.cp.mode = 1;
	if self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isWoodHarvester or self.cp.isWoodForwarder then
		self.cp.mode = 5;
	end;
	self.cp.modeState = 0
	self.cp.mode2nextState = nil;
	self.cp.startWork = nil
	self.cp.stopWork = nil
	self.cp.abortWork = nil
	self.cp.hasUnloadingRefillingCourse = false;
	self.cp.wait = true;
	self.cp.waitTimer = nil;
	self.cp.realisticDriving = true;
	self.cp.canSwitchMode = false;
	self.cp.multiSiloSelectedFillType = Fillable.FILLTYPE_UNKNOWN;
	self.cp.slippingStage = 0;

	self.cp.startAtPoint = courseplay.START_AT_NEAREST_POINT;


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
	courseplay.signs:updateWaypointSigns(self);

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
		CpManager.trafficCollisionIgnoreList[self.aiTrafficCollisionTrigger] = true; --add AI traffic collision trigger to global ignore list
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
			CpManager.trafficCollisionIgnoreList[newTrigger] = true; --add all traffic collision triggers to global ignore list
			self.cp.collidingObjects[i] = {};
			self.cp.numCollidingObjects[i] = 0;
		end;
	end;

	if not CpManager.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] then
		CpManager.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] = true;
	end;


	courseplay:askForSpecialSettings(self,self)


	-- workTools
	self.cp.workTools = {};
	self.cp.numWorkTools = 0;
	self.cp.workToolAttached = false;
	self.cp.currentTrailerToFill = nil;
	self.cp.trailerFillDistance = nil;
	self.cp.isUnloaded = false;
	self.cp.isLoaded = false;
	self.cp.tipperFillLevel = nil;
	self.cp.tipperCapacity = nil;
	self.cp.tipperFillLevelPct = 0;
	self.cp.prevFillLevelPct = nil;
	self.cp.tipRefOffset = 0;
	self.cp.isReverseBGATipping = nil; -- Used for reverse BGA tipping
	self.cp.isBGATipping = false; -- Used for BGA tipping
	self.cp.BGASectionInverted = false; -- Used for BGA tipping
	self.cp.inversedRearTipNode = nil; -- Used for BGA tipping
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
	if CpManager.isDeveloper then
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

	-- WOOD CUTTING: increase max cut length
	if CpManager.isDeveloper then
		self.cutLengthMax = 15;
		self.cutLengthStep = 1;
	end;


	self.cp.mouseCursorActive = false;


	local w16px, h16px = 16/1920, 16/1080;
	local w24px, h24px = 24/1920, 24/1080;
	local w32px, h32px = 32/1920, 32/1080;

	-- HUD
	self.cp.hud = {
		background = Overlay:new('courseplayHud', Utils.getFilename('img/hud_bg.png', courseplay.path), courseplay.hud.infoBasePosX - 16/1920, courseplay.hud.infoBasePosY - 7/1080, courseplay.hud.infoBaseWidth, courseplay.hud.infoBaseHeight);
		backgroundSuc = Overlay:new('courseplayHudSuc', Utils.getFilename('img/hud_suc_bg.png', courseplay.path), courseplay.hud.infoBasePosX - 16/1920, courseplay.hud.infoBasePosY - 7/1080, courseplay.hud.infoBaseWidth, courseplay.hud.infoBaseHeight);
		currentPage = 1;
		show = false;
		openWithMouse = true;
		content = {
			global = {};
			pages = {};
		};
		mouseWheel = {
			icon = Overlay:new('cpMouseWheelIcon', 'dataS2/menu/controllerSymbols/mouse/mouseMMB.png', 0, 0, 32/g_screenWidth, 32/g_screenHeight); -- FS15
			render = false;
		};
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
		posY = self.cp.suc.lines.title.posY - self.cp.suc.lineHeight * 1.5;
		text = '';
	};
	self.cp.suc.lines.fruit = {
		fontSize = self.cp.suc.fontSize;
		posY = self.cp.suc.lines.field.posY - self.cp.suc.lineHeight;
		text = '';
	};
	self.cp.suc.lines.result = {
		fontSize = self.cp.suc.fontSize * 1.05;
		posY = self.cp.suc.lines.fruit.posY - self.cp.suc.lineHeight * 4/3;
		text = '';
	};
	local xL = self.cp.suc.x1 + 3/1080 / g_screenAspectRatio;
	local xR = self.cp.suc.x1 + self.cp.suc.buttonFileWidth;
	local w,h = self.cp.suc.buttonFileWidth, self.cp.suc.buttonFileHeight;
	self.cp.suc.fruitNegButton = courseplay.button:new(self, 'suc', { 'iconSprite.png', 'navLeft' },  'sucChangeFruit', -1, xL, self.cp.suc.lines.fruit.posY - 3/1080, w, h);
	self.cp.suc.fruitPosButton = courseplay.button:new(self, 'suc', { 'iconSprite.png', 'navRight' }, 'sucChangeFruit',  1, xR, self.cp.suc.lines.fruit.posY - 3/1080, w, h);
	self.cp.suc.selectedFruitIdx = 1;
	self.cp.suc.selectedFruit = nil;


	-- main hud content
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
	self.cp.HUDrecordnumber = 1; 
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
		x = courseplay.hud.col1posX,
		w = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1 - (2 * 0.005),
		h = courseplay.hud.lineHeight
	};

	local listArrowX = courseplay.hud.visibleArea.x2 - (2 * 0.005) - w24px;
	local topIconsY = courseplay.hud.infoBasePosY + 0.2395;
	local topIconsX = {};
	topIconsX[3] = listArrowX - w16px - w24px;
	topIconsX[2] = topIconsX[3] - w16px - w24px;
	topIconsX[1] = topIconsX[2] - w16px - w24px;

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
		local toolTip = courseplay.hud.hudTitles[p];
		if p == 2 then
			toolTip = courseplay.hud.hudTitles[p][1];
		end;
		courseplay.button:new(self, 'global', 'iconSprite.png', 'setHudPage', p, posX, pageNav.posY, pageNav.buttonW, pageNav.buttonH, nil, nil, nil, false, false, toolTip);
	end;

	courseplay.button:new(self, 'global', { 'iconSprite.png', 'close' }, 'openCloseHud', false, courseplay.hud.buttonPosX[2], courseplay.hud.infoBasePosY + 0.255, w24px, h24px);

	courseplay.button:new(self, 'global', { 'iconSprite.png', 'save' }, 'showSaveCourseForm', 'course', topIconsX[2], topIconsY, w24px, h24px);

	if CpManager.isDeveloper then
		self.cp.toggleDrawWaypointsLinesButton = courseplay.button:new(self, 'global', { 'iconSprite.png', 'eye' }, 'toggleDrawWaypointsLines', nil, courseplay.hud.col1posX, topIconsY, w24px, h24px, nil, nil, false, false, true);
	end;


	-- ##################################################
	-- Page 0: Combine controls
	for i=1, courseplay.hud.numLines do
		courseplay.button:new(self, 0, nil, "rowButton", i, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[i], courseplay.hud.visibleArea.width, 0.015, i, nil, true);
	end;


	-- ##################################################
	-- Page 1
	-- setCpMode buttons
	local modeBtn = {
		w = w32px;
		h = h32px;
		numColumns = 3;
		marginX = w32px / 32;
		marginY = h32px / 32;
		maxX = listArrowX + w24px;
	};
	modeBtn.maxY = courseplay.hud.linesPosY[1] + courseplay.hud.lineHeight * 0.75 + modeBtn.marginY;
	modeBtn.minX = modeBtn.maxX - (modeBtn.numColumns * modeBtn.w) - ((modeBtn.numColumns - 1) * modeBtn.marginX);
	for i=1, courseplay.numAiModes do
		local line = math.ceil(i/modeBtn.numColumns); -- 1, 2, 3
		local col = (i - 1) % modeBtn.numColumns; -- 0, 1, 2

		local posX = modeBtn.minX + ((modeBtn.w + modeBtn.marginX) * col);
		local posY = modeBtn.maxY - ((modeBtn.h + modeBtn.marginY) * line);

		local toolTip = courseplay:loc(('COURSEPLAY_MODE_%d'):format(i));

		courseplay.button:new(self, 1, 'iconSprite.png', 'setCpMode', i, posX, posY, modeBtn.w, modeBtn.h, nil, nil, false, false, false, toolTip);
	end;

	--recording
	local recordingData = {
		[1] = { 'recordingStop', 'stop_record', nil, 'COURSEPLAY_RECORDING_STOP' },
		[2] = { 'recordingPause', 'setRecordingPause', true, 'COURSEPLAY_RECORDING_PAUSE' },
		[3] = { 'recordingDelete', 'delete_waypoint', nil, 'COURSEPLAY_RECORDING_DELETE' },
		[4] = { 'recordingWait', 'set_waitpoint', nil, 'COURSEPLAY_RECORDING_SET_WAIT' },
		[5] = { 'recordingCross', 'set_crossing', nil, 'COURSEPLAY_RECORDING_SET_CROSS' },
		[6] = { 'recordingTurn', 'setRecordingTurnManeuver', true, 'COURSEPLAY_RECORDING_TURN_START' },
		[7] = { 'recordingReverse', 'change_DriveDirection', true, 'COURSEPLAY_RECORDING_REVERSE_START' }
	};
	local w,h = w32px,h32px;
	local padding = w/4;
	local totalWidth = (#recordingData - 1) * (w + padding) + w;
	local initX = courseplay.hud.infoBaseCenter - totalWidth/2;
	
	for i,data in pairs(recordingData) do
		local posX = initX + ((w + padding) * (i-1));
		local fn = data[2];
		local isToggleButton = data[3];
		local toolTip = courseplay:loc(data[4]);
		local button = courseplay.button:new(self, 1, { 'iconSprite.png', data[1] }, fn, nil, posX, courseplay.hud.linesButtonPosY[2], w, h, nil, nil, false, false, isToggleButton, toolTip);
		if isToggleButton then
			if fn == 'setRecordingPause' then
				self.cp.hud.recordingPauseButton = button;
			elseif fn == 'setRecordingTurnManeuver' then
				self.cp.hud.recordingTurnManeuverButton = button;
			elseif fn == 'change_DriveDirection' then
				self.cp.hud.recordingDriveDirectionButton = button;
			end;
		end;
	end;

	--row buttons
	for i=1, courseplay.hud.numLines do
		courseplay.button:new(self, 1, nil, 'rowButton', i, courseplay.hud.col1posX, courseplay.hud.linesPosY[i], modeBtn.minX - courseplay.hud.col1posX, 0.015, i, nil, true);
	end;

	--Custom field edge path
	courseplay.button:new(self, 1, { 'iconSprite.png', 'cancel' }, 'clearCustomFieldEdge', nil, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);
	courseplay.button:new(self, 1, { 'iconSprite.png', 'eye' }, 'toggleCustomFieldEdgePathShow', nil, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);

	courseplay.button:new(self, 1, { 'iconSprite.png', 'navMinus' }, 'setCustomFieldEdgePathNumber', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -5, false);
	courseplay.button:new(self, 1, { 'iconSprite.png', 'navPlus' },  'setCustomFieldEdgePathNumber',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  5, false);
	courseplay.button:new(self, 1, nil, 'setCustomFieldEdgePathNumber', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	-- Find first waypoint
	courseplay.button:new(self, 1, { 'iconSprite.png', 'search' }, 'toggleFindFirstWaypoint', nil, topIconsX[1], topIconsY, w24px, h24px, nil, nil, false, false, true);


	-- ##################################################
	-- Page 2: Course management
	--course navigation
	courseplay.button:new(self, 2, { 'iconSprite.png', 'navUp' },   'shiftHudCourses', -courseplay.hud.numLines, listArrowX, courseplay.hud.linesPosY[1] - 0.003,                       w24px, h24px, nil, -courseplay.hud.numLines*2);
	courseplay.button:new(self, 2, { 'iconSprite.png', 'navDown' }, 'shiftHudCourses',  courseplay.hud.numLines, listArrowX, courseplay.hud.linesPosY[courseplay.hud.numLines] - 0.003, w24px, h24px, nil,  courseplay.hud.numLines*2);

	local courseListMouseWheelArea = {
		x = mouseWheelArea.x,
		y = courseplay.hud.linesPosY[courseplay.hud.numLines],
		width = mouseWheelArea.w,
		height = courseplay.hud.linesPosY[1] + courseplay.hud.lineHeight - courseplay.hud.linesPosY[courseplay.hud.numLines]
	};
	courseplay.button:new(self, 2, nil, 'shiftHudCourses',  -1, courseListMouseWheelArea.x, courseListMouseWheelArea.y, courseListMouseWheelArea.width, courseListMouseWheelArea.height, nil, -courseplay.hud.numLines, nil, true);

	-- course actions
	local pad = w16px*10/16;
	local buttonX = {};
	buttonX[0] = courseplay.hud.col1posX;
	buttonX[4] = listArrowX - (2 * pad) - w16px;
	buttonX[3] = buttonX[4] - pad - w16px;
	buttonX[2] = buttonX[3] - pad - w16px;
	buttonX[1] = buttonX[2] - pad - w16px;
	local hoverAreaWidth = buttonX[3] + w16px - buttonX[1];
	if g_server ~= nil then
		hoverAreaWidth = buttonX[4] + w16px - buttonX[1];
	end;
	 -- TODO (Jakob): toolTips i18n
	for i=1, courseplay.hud.numLines do
		courseplay.button:new(self, -2, { 'iconSprite.png', 'navPlus' }, 'expandFolder', i, buttonX[0], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		courseplay.button:new(self, -2, { 'iconSprite.png', 'courseLoadAppend' }, 'loadSortedCourse', i, buttonX[1], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false, false, false, 'Load course/merge into loaded course');
		courseplay.button:new(self, -2, { 'iconSprite.png', 'courseAdd' }, 'addSortedCourse', i, buttonX[2], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false, false, false, 'Append course at the end');
		courseplay.button:new(self, -2, { 'iconSprite.png', 'folderParentFrom' }, 'linkParent', i, buttonX[3], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false, false, false, 'Move to folder');
		if g_server ~= nil then
			courseplay.button:new(self, -2, { 'iconSprite.png', 'delete' }, 'deleteSortedItem', i, buttonX[4], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false, false, false, 'Delete course/folder');
		end;
		courseplay.button:new(self, -2, nil, nil, nil, buttonX[1], courseplay.hud.linesButtonPosY[i], hoverAreaWidth, mouseWheelArea.h, i, nil, true, false);
	end
	self.cp.hud.filterButton = courseplay.button:new(self, 2, { 'iconSprite.png', 'search' }, 'showSaveCourseForm', 'filter', topIconsX[1], topIconsY, w24px, h24px, nil, nil, false, false, false, 'Search for courses and folders');
	courseplay.button:new(self, 2, { 'iconSprite.png', 'folderNew' }, 'showSaveCourseForm', 'folder', topIconsX[3], topIconsY, w24px, h24px, nil, nil, false, false, false, 'Create new folder');


	-- ##################################################
	-- Page 3
	courseplay.button:new(self, 3, { 'iconSprite.png', 'navMinus' }, 'changeCombineOffset', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -0.5, false);
	courseplay.button:new(self, 3, { 'iconSprite.png', 'navPlus' },  'changeCombineOffset',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  0.5, false);
	courseplay.button:new(self, 3, nil, 'changeCombineOffset', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);

	courseplay.button:new(self, 3, { 'iconSprite.png', 'navMinus' }, 'changeTipperOffset', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -0.5, false);
	courseplay.button:new(self, 3, { 'iconSprite.png', 'navPlus' },  'changeTipperOffset',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  0.5, false);
	courseplay.button:new(self, 3, nil, 'changeTipperOffset', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);

	courseplay.button:new(self, 3, { 'iconSprite.png', 'navMinus' }, 'changeTurnRadius', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, -5, false);
	courseplay.button:new(self, 3, { 'iconSprite.png', 'navPlus' },  'changeTurnRadius',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  5, false);
	courseplay.button:new(self, 3, nil, 'changeTurnRadius', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

	courseplay.button:new(self, 3, { 'iconSprite.png', 'navMinus' }, 'changeFollowAtFillLevel', -5, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -10, false);
	courseplay.button:new(self, 3, { 'iconSprite.png', 'navPlus' },  'changeFollowAtFillLevel',  5, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  10, false);
	courseplay.button:new(self, 3, nil, 'changeFollowAtFillLevel', 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 10, true, true);

	courseplay.button:new(self, 3, { 'iconSprite.png', 'navMinus' }, 'changeDriveOnAtFillLevel', -5, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, -10, false);
	courseplay.button:new(self, 3, { 'iconSprite.png', 'navPlus' },  'changeDriveOnAtFillLevel',  5, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5,  10, false);
	courseplay.button:new(self, 3, nil, 'changeDriveOnAtFillLevel', 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 10, true, true);

	courseplay.button:new(self, 3, { 'iconSprite.png', 'navMinus' }, 'changeRefillUntilPct', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, -5, false);
	courseplay.button:new(self, 3, { 'iconSprite.png', 'navPlus' },  'changeRefillUntilPct',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6,  5, false);
	courseplay.button:new(self, 3, nil, 'changeRefillUntilPct', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, 5, true, true);


	-- ##################################################
	-- Page 4: Combine management
	courseplay.button:new(self, 4, nil, 'toggleSearchCombineMode', nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[1], courseplay.hud.visibleArea.width, 0.015, 1, nil, true);

	courseplay.button:new(self, 4, { 'iconSprite.png', 'navUp' },   'selectAssignedCombine', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, nil, false);
	courseplay.button:new(self, 4, { 'iconSprite.png', 'navDown' }, 'selectAssignedCombine',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, nil, false);

	--[[
	courseplay.button:new(self, 4, { 'iconSprite.png', 'navUp' },   'setSearchCombineOnField', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);
	courseplay.button:new(self, 4, { 'iconSprite.png', 'navDown' }, 'setSearchCombineOnField',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, nil, false);
	courseplay.button:new(self, 4, nil, 'setSearchCombineOnField', -1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, -5, true, true);
	]]

	courseplay.button:new(self, 4, nil, 'removeActiveCombineFromTractor', nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);


	-- ##################################################
	-- Page 5: Speeds
	courseplay.button:new(self, 5, { 'iconSprite.png', 'navMinus' }, 'changeTurnSpeed',   -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -5, false);
	courseplay.button:new(self, 5, { 'iconSprite.png', 'navPlus' },  'changeTurnSpeed',    1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  5, false);
	courseplay.button:new(self, 5, nil, 'changeTurnSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 5, true, true);

	courseplay.button:new(self, 5, { 'iconSprite.png', 'navMinus' }, 'changeFieldSpeed',  -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -5, false);
	courseplay.button:new(self, 5, { 'iconSprite.png', 'navPlus' },  'changeFieldSpeed',   1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  5, false);
	courseplay.button:new(self, 5, nil, 'changeFieldSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 5, true, true);

	courseplay.button:new(self, 5, { 'iconSprite.png', 'navMinus' }, 'changeMaxSpeed',    -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, -5, false);
	courseplay.button:new(self, 5, { 'iconSprite.png', 'navPlus' },  'changeMaxSpeed',     1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  5, false);
	courseplay.button:new(self, 5, nil, 'changeMaxSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

	courseplay.button:new(self, 5, { 'iconSprite.png', 'navMinus' }, 'changeUnloadSpeed', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -5, false);
	courseplay.button:new(self, 5, { 'iconSprite.png', 'navPlus' },  'changeUnloadSpeed',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  5, false);
	courseplay.button:new(self, 5, nil, 'changeUnloadSpeed', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	courseplay.button:new(self, 5, nil, 'toggleUseRecordingSpeed',1, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);


	-- ##################################################
	-- Page 6: General settings
	courseplay.button:new(self, 6, nil, 'toggleRealisticDriving', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[1], courseplay.hud.visibleArea.width, 0.015, 1, nil, true);
	courseplay.button:new(self, 6, nil, 'toggleOpenHudWithMouse', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], courseplay.hud.visibleArea.width, 0.015, 2, nil, true);
	courseplay.button:new(self, 6, nil, 'changeVisualWaypointsMode', 1, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[3], courseplay.hud.visibleArea.width, 0.015, 3, nil, true);
	courseplay.button:new(self, 6, nil, 'changeBeaconLightsMode', 1, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[4], courseplay.hud.visibleArea.width, 0.015, 4, nil, true);

	courseplay.button:new(self, 6, { 'iconSprite.png', 'navMinus' }, 'changeWaitTime', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, -5, false);
	courseplay.button:new(self, 6, { 'iconSprite.png', 'navPlus' },  'changeWaitTime',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5,  5, false);
	courseplay.button:new(self, 6, nil, 'changeWaitTime', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 5, true, true);

	if courseplay.ingameMapIconActive and courseplay.ingameMapIconShowTextLoaded then
		courseplay.button:new(self, 6, nil, 'toggleIngameMapIconShowText', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[6], courseplay.hud.visibleArea.width, 0.015, 7, nil, true);
	end;

	self.cp.hud.debugChannelButtons = {};
	for dbg=1, courseplay.numDebugChannelButtonsPerLine do
		local data = courseplay.debugButtonPosData[dbg];
		local toolTip = courseplay.debugChannelsDesc[dbg];
		self.cp.hud.debugChannelButtons[dbg] = courseplay.button:new(self, 6, 'iconSprite.png', 'toggleDebugChannel', dbg, data.posX, data.posY, data.width, data.height, nil, nil, nil, false, false, toolTip);
	end;
	courseplay.button:new(self, 6, { 'iconSprite.png', 'navUp' },   'changeDebugChannelSection', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[8], w16px, h16px, 8, -1, true, false);
	courseplay.button:new(self, 6, { 'iconSprite.png', 'navDown' }, 'changeDebugChannelSection',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[8], w16px, h16px, 8,  1, true, false);
	courseplay.button:new(self, 6, nil, 'changeDebugChannelSection', -1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[8], mouseWheelArea.w, mouseWheelArea.h, 8, -1, true, true);


	-- ##################################################
	-- Page 7: Driving settings
	courseplay.button:new(self, 7, { 'iconSprite.png', 'navLeft' },  'changeLaneOffset', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -0.5, false);
	courseplay.button:new(self, 7, { 'iconSprite.png', 'navRight' }, 'changeLaneOffset',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  0.5, false);
	courseplay.button:new(self, 7, nil, 'changeLaneOffset', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);

	courseplay.button:new(self, 7, nil, 'toggleSymmetricLaneChange', nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], courseplay.hud.visibleArea.width, 0.015, 2, nil, true);

	courseplay.button:new(self, 7, { 'iconSprite.png', 'navLeft' },  'changeToolOffsetX', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  -0.5, false);
	courseplay.button:new(self, 7, { 'iconSprite.png', 'navRight' }, 'changeToolOffsetX',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,   0.5, false);
	courseplay.button:new(self, 7, nil, 'changeToolOffsetX', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 0.5, true, true);

	courseplay.button:new(self, 7, { 'iconSprite.png', 'navDown' }, 'changeToolOffsetZ', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  -0.5, false);
	courseplay.button:new(self, 7, { 'iconSprite.png', 'navUp' },   'changeToolOffsetZ',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,   0.5, false);
	courseplay.button:new(self, 7, nil, 'changeToolOffsetZ', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 0.5, true, true);


	courseplay.button:new(self, 7, { 'iconSprite.png', 'navUp' },   'switchDriverCopy', -1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay.button:new(self, 7, { 'iconSprite.png', 'navDown' }, 'switchDriverCopy',  1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay.button:new(self, 7, nil, nil, nil, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[5], 0.015 + w16px, mouseWheelArea.h, 5, nil, true, false);
	courseplay.button:new(self, 7, { 'iconSprite.png', 'copy' }, 'copyCourse', nil, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[6], w16px, h16px);


	-- ##################################################
	-- Page 8: Course generation
	-- Note: line 1 (field edges) will be applied in first updateTick() runthrough

	-- line 2 (workWidth)
	courseplay.button:new(self, 8, { 'iconSprite.png', 'calculator' }, 'calculateWorkWidth', nil, courseplay.hud.buttonPosX[0], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, nil, false);
	courseplay.button:new(self, 8, { 'iconSprite.png', 'navMinus' }, 'changeWorkWidth', -0.1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -0.5, false);
	courseplay.button:new(self, 8, { 'iconSprite.png', 'navPlus' },  'changeWorkWidth',  0.1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  0.5, false);
	courseplay.button:new(self, 8, nil, 'changeWorkWidth', 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);

	-- line 3 (starting corner)
	courseplay.button:new(self, 8, nil, 'switchStartingCorner',     nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[3], courseplay.hud.visibleArea.width, 0.015, 3, nil, true);

	-- line 4 (starting direction)
	courseplay.button:new(self, 8, nil, 'changeStartingDirection',  nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[4], courseplay.hud.visibleArea.width, 0.015, 4, nil, true);

	-- line 5 (return to first point)
	courseplay.button:new(self, 8, nil, 'toggleReturnToFirstPoint', nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);

	-- line 6 (headland)
	-- 6.1 direction
	self.cp.headland.directionButton = courseplay.button:new(self, 8, { 'iconSprite.png', 'headlandDirCW' }, 'toggleHeadlandDirection', nil, courseplay.hud.infoBasePosX + 0.246 - w32px, courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, nil, false, nil, nil, 'Headland counter-/clockwise'); -- TODO (Jakob): i18n

	-- 6.2 order
	self.cp.headland.orderButton = courseplay.button:new(self, 8, { 'iconSprite.png', 'headlandOrdBef' }, 'toggleHeadlandOrder', nil, courseplay.hud.infoBasePosX + 0.240, courseplay.hud.linesButtonPosY[6], w32px, h16px, 6, nil, false, nil, nil, 'Headland before/after field course'); -- TODO (Jakob): i18n

	-- 6.3: numLanes
	courseplay.button:new(self, 8, { 'iconSprite.png', 'navUp' },   'changeHeadlandNumLanes',   1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, nil, false);
	courseplay.button:new(self, 8, { 'iconSprite.png', 'navDown' }, 'changeHeadlandNumLanes',  -1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[6], w16px, h16px, 6, nil, false);

	-- generation action button
	local toolTip = 'Generate field course'; -- TODO: i18n
	self.cp.hud.generateCourseButton = courseplay.button:new(self, 8, { 'iconSprite.png', 'generateCourse' }, 'generateCourse', nil, topIconsX[3], topIconsY, w24px, h24px, nil, nil, false, false, false, toolTip);


	-- ##################################################
	-- Page 9: Shovel settings
	local wTemp = 22/1920;
	local hTemp = 22/1080;
	courseplay.button:new(self, 9, { 'iconSprite.png', 'shovelLoading' },   'saveShovelPosition', 2, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[1] - 0.003, wTemp, hTemp, 1, nil, true, false, true);
	courseplay.button:new(self, 9, { 'iconSprite.png', 'shovelTransport' }, 'saveShovelPosition', 3, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[2] - 0.003, wTemp, hTemp, 2, nil, true, false, true);
	courseplay.button:new(self, 9, { 'iconSprite.png', 'shovelPreUnload' }, 'saveShovelPosition', 4, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[3] - 0.003, wTemp, hTemp, 3, nil, true, false, true);
	courseplay.button:new(self, 9, { 'iconSprite.png', 'shovelUnloading' }, 'saveShovelPosition', 5, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[4] - 0.003, wTemp, hTemp, 4, nil, true, false, true);

	courseplay.button:new(self, 9, nil, 'toggleShovelStopAndGo', nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);
	--END Page 9


	-- ##################################################
	-- Status icons
	local bi = courseplay.hud.bottomInfo;
	local w = bi.iconWidth;
	local h = bi.iconHeight;
	local sizeX,sizeY = courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y;
	-- current mode icon
	self.cp.hud.currentModeIcon = Overlay:new('cpCurrentModeIcon', courseplay.hud.iconSpritePath, bi.modeIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(self.cp.hud.currentModeIcon, bi.modeUVsPx[self.cp.mode], sizeX, sizeY);

	-- waypoint icon
	self.cp.hud.currentWaypointIcon = Overlay:new('cpCurrentWaypointIcon', courseplay.hud.iconSpritePath, bi.waypointIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(self.cp.hud.currentWaypointIcon, { 4, 180, 36, 148 }, sizeX, sizeY);

	-- waitPoints icon
	self.cp.hud.waitPointsIcon = Overlay:new('cpWaitPointsIcon', courseplay.hud.iconSpritePath, bi.waitPointsIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(self.cp.hud.waitPointsIcon, courseplay.hud.buttonUVsPx['recordingWait'], sizeX, sizeY);

	-- crossingPoints icon
	self.cp.hud.crossingPointsIcon = Overlay:new('cpCrossingPointsIcon', courseplay.hud.iconSpritePath, bi.crossingPointsIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(self.cp.hud.crossingPointsIcon, courseplay.hud.buttonUVsPx['recordingCross'], sizeX, sizeY);

	-- toolTip icon
	self.cp.hud.toolTipIcon = Overlay:new('cpToolTipIcon', courseplay.hud.iconSpritePath, courseplay.hud.col1posX, courseplay.hud.infoBasePosY + 0.0055, w, h);
	courseplay.utils:setOverlayUVsPx(self.cp.hud.toolTipIcon, { 112, 180, 144, 148 }, sizeX, sizeY);



	courseplay:validateCanSwitchMode(self);
	courseplay:buttonsActiveEnabled(self, 'all');
end;

function courseplay:postLoad(xmlFile)
	-- Drive Control (upsidedown)
	if self.driveControl ~= nil and g_currentMission.driveControl ~= nil then
		self.cp.hasDriveControl = true;
		self.cp.driveControl = {
			hasFourWD = g_currentMission.driveControl.useModules.fourWDandDifferentials and not self.driveControl.fourWDandDifferentials.isSurpressed;
			hasHandbrake = g_currentMission.driveControl.useModules.handBrake;
			hasManualMotorStart = g_currentMission.driveControl.useModules.manMotorStart;
			hasMotorKeepTurnedOn = g_currentMission.driveControl.useModules.manMotorKeepTurnedOn;
			hasShuttleMode = g_currentMission.driveControl.useModules.shuttle;
		};
	end;
end;

function courseplay:onLeave()
	if self.cp.mouseCursorActive then
		courseplay:setMouseCursor(self, false);
	end

	--hide visual i3D waypoint signs when not in vehicle
	courseplay.signs:setSignsVisibility(self, false);
end

function courseplay:onEnter()
	if self.cp.mouseCursorActive then
		courseplay:setMouseCursor(self, true);
	end;

	if self:getIsCourseplayDriving() and self.steeringEnabled then
		self.steeringEnabled = false;
	end;

	--show visual i3D waypoint signs only when in vehicle
	courseplay.signs:setSignsVisibility(self);
end

function courseplay:draw()
	local isDriving = self:getIsCourseplayDriving();

	--WORKWIDTH DISPLAY
	if self.cp.mode ~= 7 and self.cp.timers.showWorkWidth and self.cp.timers.showWorkWidth > 0 then
		if courseplay:timerIsThrough(self, 'showWorkWidth') then -- stop showing, reset timer
			courseplay:resetCustomTimer(self, 'showWorkWidth');
		else -- timer running, show
			courseplay:showWorkWidth(self);
		end;
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


	-- HELP BUTTON TEXTS
	if self:getIsActive() and self.isEntered then
		local modifierPressed = InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER);

		if (self.cp.canDrive or not self.cp.hud.openWithMouse) and not modifierPressed then
			g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_FUNCTIONS'), InputBinding.COURSEPLAY_MODIFIER);
		end;

		if self.cp.hud.show then
			if self.cp.mouseCursorActive then
				g_currentMission:addHelpTextFunction(CpManager.drawMouseButtonHelp, self, CpManager.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_HIDE'));
			else
				g_currentMission:addHelpTextFunction(CpManager.drawMouseButtonHelp, self, CpManager.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_SHOW'));
			end;
		end;

		if self.cp.hud.openWithMouse then
			if not self.cp.hud.show then
				g_currentMission:addHelpTextFunction(CpManager.drawMouseButtonHelp, self, CpManager.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_HUD_OPEN'));
			end;
		else
			if modifierPressed then
				if not self.cp.hud.show then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_HUD_OPEN'), InputBinding.COURSEPLAY_HUD);
				else
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_HUD_CLOSE'), InputBinding.COURSEPLAY_HUD);
				end;
			end;
		end;

		if self.cp.canDrive and modifierPressed then
			if isDriving then
				g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_STOP_COURSE'), InputBinding.COURSEPLAY_START_STOP);
				if self.cp.HUD1wait then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_CONTINUE'), InputBinding.COURSEPLAY_CANCELWAIT);
				end;
				if self.cp.HUD1noWaitforFill then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_DRIVE_NOW'), InputBinding.COURSEPLAY_DRIVENOW);
				end;
			else
				g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_START_COURSE'), InputBinding.COURSEPLAY_START_STOP);
			end;
		end;
	end;

	--RENDER
	courseplay:renderInfoText(self);

	if self:getIsActive() then
		if self.cp.hud.show then
			courseplay.hud:setContent(self);
			courseplay.hud:renderHud(self);
			if self.cp.distanceCheck and (isDriving or (not self.cp.canDrive and not self.cp.isRecording and not self.cp.recordingIsPaused)) then -- turn off findFirstWaypoint when driving or no course loaded
				courseplay:toggleFindFirstWaypoint(self);
			end;

			if self.cp.mouseCursorActive then
				InputBinding.setShowMouseCursor(self.cp.mouseCursorActive);
			end;
		end;
		if self.cp.distanceCheck and #(self.Waypoints) > 1 then
			courseplay:distanceCheck(self);
		end;
		if self.isEntered and self.cp.toolTip ~= nil then
			courseplay:renderToolTip(self);
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
	if not CpManager.isDeveloper or not vehicle.isControlled then return; end;

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

function courseplay:update(dt)
	-- KEYBOARD EVENTS
	if self:getIsActive() and self.isEntered and InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
		if self.cp.canDrive then
			if self.cp.isDriving then
				if InputBinding.hasEvent(InputBinding.COURSEPLAY_START_STOP) then
					self:setCourseplayFunc("stop", nil, false, 1);
				elseif self.cp.HUD1wait and InputBinding.hasEvent(InputBinding.COURSEPLAY_CANCELWAIT) then
					self:setCourseplayFunc('cancelWait', true, false, 1);
				elseif self.cp.HUD1noWaitforFill and InputBinding.hasEvent(InputBinding.COURSEPLAY_DRIVENOW) then
					self:setCourseplayFunc("setIsLoaded", true, false, 1);
				end;
			else
				if InputBinding.hasEvent(InputBinding.COURSEPLAY_START_STOP) then
					self:setCourseplayFunc("start", nil, false, 1);
				end;
			end;
		end;

		if not self.cp.openHudWithMouse and InputBinding.hasEvent(InputBinding.COURSEPLAY_HUD) then
			self:setCourseplayFunc('openCloseHud', not self.cp.hud.show);
		end;
	end; -- self:getIsActive() and self.isEntered and modifierPressed


	if g_server ~= nil and (self.cp.isDriving or self.cp.isRecording or self.cp.recordingIsPaused) then
		courseplay:setInfoText(self, nil);
	end;

	if self.cp.drawWaypointsLines then
		courseplay:drawWaypointsLines(self);
	end;

	-- we are in record mode
	if self.cp.isRecording then
		courseplay:record(self);
	end;

	-- we are in drive mode and single player /MP server
	if self.cp.isDriving and g_server ~= nil then
		for refIdx,_ in pairs(CpManager.globalInfoText.msgReference) do
			self.cp.hasSetGlobalInfoTextThisLoop[refIdx] = false;
		end;

		courseplay:drive(self, dt);

		for refIdx,_ in pairs(self.cp.activeGlobalInfoTexts) do
			if not self.cp.hasSetGlobalInfoTextThisLoop[refIdx] then
				CpManager:setGlobalInfoText(self, refIdx, true); --force remove
			end;
		end;
	end
	 
	if self.cp.onSaveClick and not self.cp.doNotOnSaveClick then
		inputCourseNameDialogue:onSaveClick()
		self.cp.onSaveClick = false
		self.cp.doNotOnSaveClick = false
	end
	if self.cp.onMpSetCourses then
		courseplay.courses:reloadVehicleCourses(self)
		self.cp.onMpSetCourses = nil
	end

	if g_server ~= nil then
		if self.cp.isDriving then
			local showDriveOnButton = false;
			if self.cp.mode == 6 then
				if self.cp.wait and (self.recordnumber == self.cp.stopWork or self.cp.lastRecordnumber == self.cp.stopWork) and self.cp.abortWork == nil and not self.cp.isLoaded and not isFinishingWork and self.cp.hasUnloadingRefillingCourse then
					showDriveOnButton = true;
				end;
			else
				if (self.cp.wait and (self.Waypoints[self.recordnumber].wait or self.Waypoints[self.cp.lastRecordnumber].wait)) or (self.cp.stopAtEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil)) then
					showDriveOnButton = true;
				end;
			end;
			self:setCpVar('HUD1wait', showDriveOnButton);

			self:setCpVar('HUD1noWaitforFill', not self.cp.isLoaded and self.cp.mode ~= 5);
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
			if self.cp.attachedCombineIdx ~= nil and self.cp.workTools ~= nil and self.cp.workTools[self.cp.attachedCombineIdx] ~= nil then
				combine = self.cp.workTools[self.cp.attachedCombineIdx];
			end;
			if combine.courseplayers == nil then
				self:setCpVar('HUD0noCourseplayer', true);
				combine.courseplayers = {};
			else
				self:setCpVar('HUD0noCourseplayer', #combine.courseplayers == 0);
			end
			self:setCpVar('HUD0wantsCourseplayer', combine.cp.wantsCourseplayer);
			self:setCpVar('HUD0combineForcedSide', combine.cp.forcedSide);
			self:setCpVar('HUD0isManual', not self.cp.isDriving and not combine.isAIThreshing);
			self:setCpVar('HUD0turnStage', self.cp.turnStage);
			local tractor = combine.courseplayers[1]
			if tractor ~= nil then
				self:setCpVar('HUD0tractorForcedToStop', tractor.cp.forcedToStop);
				self:setCpVar('HUD0tractorName', tostring(tractor.name));
				self:setCpVar('HUD0tractor', true);
			else
				self:setCpVar('HUD0tractorForcedToStop', nil);
				self:setCpVar('HUD0tractorName', nil);
				self:setCpVar('HUD0tractor', false);
			end;

		elseif self.cp.hud.currentPage == 1 then
			if self:getIsActive() and not self.cp.canDrive and self.cp.fieldEdge.customField.show and self.cp.fieldEdge.customField.points ~= nil then
				courseplay:showFieldEdgePath(self, "customField");
			end;


		elseif self.cp.hud.currentPage == 4 then
			self:setCpVar('HUD4hasActiveCombine', self.cp.activeCombine ~= nil);
			if self.cp.HUD4hasActiveCombine == true then
				self:setCpVar('HUD4combineName', self.cp.activeCombine.name);
			end
			self:setCpVar('HUD4savedCombine', self.cp.savedCombine ~= nil and self.cp.savedCombine.rootNode ~= nil);
			if self.cp.savedCombine ~= nil then
				self:setCpVar('HUD4savedCombineName', self.cp.savedCombine.name);
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

	self.timer = self.timer + dt;
end

function courseplay:preDelete()
	if self.cp ~= nil and self.cp.numActiveGlobalInfoTexts ~= 0 then
		for refIdx,_ in pairs(CpManager.globalInfoText.msgReference) do
			if self.cp.activeGlobalInfoTexts[refIdx] ~= nil then
				CpManager:setGlobalInfoText(self, refIdx, true);
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
			courseplay.buttons:deleteButtonOverlays(self);
		end;
		if self.cp.signs ~= nil then
			for _,section in pairs(self.cp.signs) do
				for k,signData in pairs(section) do
					courseplay.signs:deleteSign(signData.sign);
				end;
			end;
			self.cp.signs = nil;
		end;
	end;
end;

function courseplay:setInfoText(vehicle, text, seconds)
	if vehicle.cp.infoText ~= text then
		vehicle.cp.infoText = text;
		if seconds then
			courseplay:setCustomTimer(vehicle, 'infoText', seconds);
		end;
	end;
end;

function courseplay:renderInfoText(vehicle)
	if vehicle.isEntered and vehicle.cp.infoText ~= nil and vehicle.cp.toolTip == nil then
		courseplay:setFontSettings('white', false, 'left');
		renderText(courseplay.hud.col1posX, courseplay.hud.infoBasePosY + 0.012, courseplay.hud.fontSizes.infoText, vehicle.cp.infoText);
	end;
end;

function courseplay:setToolTip(vehicle, text)
	if vehicle.cp.toolTip ~= text then
		vehicle.cp.toolTip = text;
	end;
end;

function courseplay:renderToolTip(vehicle)
	courseplay:setFontSettings('white', false, 'left');
	renderText(courseplay.hud.col1posX + vehicle.cp.hud.toolTipIcon.width * 1.25, courseplay.hud.infoBasePosY + 0.012, courseplay.hud.fontSizes.infoText, vehicle.cp.toolTip);
	vehicle.cp.hud.toolTipIcon:render();
end;


function courseplay:readStream(streamId, connection)
	courseplay:debug("id: "..tostring(self.id).."  base: readStream", 5)
	
	self.cp.automaticCoverHandling = streamDebugReadBool(streamId);
	self.cp.automaticUnloadingOnField = streamDebugReadBool(streamId);
	courseplay:setCpMode(self, streamDebugReadInt32(streamId));
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
    self.cp.hasUnloadingRefillingCourse	 = streamDebugReadBool(streamId);
	courseplay:setInfoText(self, streamDebugReadString(streamId));
	self.cp.returnToFirstPoint = streamDebugReadBool(streamId);
	self.cp.ridgeMarkersAutomatic = streamDebugReadBool(streamId);
	self.cp.shovelStopAndGo = streamDebugReadBool(streamId);
	self.cp.startAtPoint = streamDebugReadInt32(streamId);
	courseplay:setStopAtEnd(self, streamDebugReadBool(streamId));
	self:setIsCourseplayDriving(streamDebugReadBool(streamId));
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
	courseplay:setHudPage(self, streamDebugReadInt32(streamId));
	self:setCpVar('HUDrecordnumber', streamDebugReadInt32(streamId));
	self:setCpVar('HUD0noCourseplayer', streamDebugReadBool(streamId));
	self:setCpVar('HUD0wantsCourseplayer', streamDebugReadBool(streamId));
	self:setCpVar('HUD0combineForcedSide', streamDebugReadString(streamId));
	self:setCpVar('HUD0isManual', streamDebugReadBool(streamId));
	self:setCpVar('HUD0turnStage', streamDebugReadInt32(streamId));
	self:setCpVar('HUD0tractorForcedToStop', streamDebugReadBool(streamId));
	self:setCpVar('HUD0tractorName', streamDebugReadString(streamId));
	self:setCpVar('HUD0tractor', streamDebugReadBool(streamId));
	self:setCpVar('HUD1wait', streamDebugReadBool(streamId));
	self:setCpVar('HUD1noWaitforFill', streamDebugReadBool(streamId));
	self:setCpVar('HUD4hasActiveCombine', streamDebugReadBool(streamId));
	self:setCpVar('HUD4combineName', streamDebugReadString(streamId));
	self:setCpVar('HUD4savedCombine', streamDebugReadBool(streamId));
	self:setCpVar('HUD4savedCombineName', streamDebugReadString(streamId));
	courseplay:setRecordNumber(self, streamDebugReadInt32(streamId));
	courseplay:setIsRecording(self, streamDebugReadBool(streamId));
	courseplay:setRecordingIsPaused(self, streamDebugReadBool(streamId));
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

	courseplay.courses:reinitializeCourses()


	-- kurs daten
	local courses = streamDebugReadString(streamId) -- 60.
	if courses ~= nil then
		self.cp.loadedCourses = Utils.splitString(",", courses);
		courseplay:reloadCourses(self, true)
	end

	local debugChannelsString = streamDebugReadString(streamId)
	for k,v in pairs(Utils.splitString(",", debugChannelsString)) do
		courseplay:toggleDebugChannel(self, k, v == 'true');
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
	streamDebugWriteBool(streamId, self.cp.hasUnloadingRefillingCourse)
	streamDebugWriteString(streamId, self.cp.infoText);
	streamDebugWriteBool(streamId, self.cp.returnToFirstPoint);
	streamDebugWriteBool(streamId, self.cp.ridgeMarkersAutomatic);
	streamDebugWriteBool(streamId, self.cp.shovelStopAndGo);
	streamDebugWriteInt32(streamId, self.cp.startAtPoint);
	streamDebugWriteBool(streamId, self.cp.stopAtEnd)
	streamDebugWriteBool(streamId, self:getIsCourseplayDriving());
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
		courseplay:setCpMode(self,  Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#aiMode'),			 1));
		self.cp.hud.openWithMouse = Utils.getNoNil(  getXMLBool(xmlFile, curKey .. '#openHudWithMouse'), true);
		self.cp.beaconLightsMode  = Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#beacon'),			 1);
		self.cp.waitTime 		  = Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#waitTime'),		 0);
		local courses 			  = Utils.getNoNil(getXMLString(xmlFile, curKey .. '#courses'),			 '');
		self.cp.loadedCourses = Utils.splitString(",", courses);
		courseplay:reloadCourses(self, true);
		local visualWaypointsMode = Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#visualWaypoints'),	 1);
		courseplay:changeVisualWaypointsMode(self, 0, visualWaypointsMode);
		self.cp.multiSiloSelectedFillType = Fillable.fillTypeNameToInt[Utils.getNoNil(getXMLString(xmlFile, curKey .. '#multiSiloSelectedFillType'), 'unknown')];
		if self.cp.multiSiloSelectedFillType == nil then self.cp.multiSiloSelectedFillType = Fillable.FILLTYPE_UNKNOWN; end;

		-- SPEEDS
		curKey = key .. '.courseplay.speeds';
		self.cp.speeds.useRecordingSpeed = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#useRecordingSpeed'), true);
		self.cp.speeds.unload 			 = Utils.getNoNil( getXMLInt(xmlFile, curKey .. '#unload'), 6);
		self.cp.speeds.turn 			 = Utils.getNoNil( getXMLInt(xmlFile, curKey .. '#turn'),  10);
		self.cp.speeds.field 			 = Utils.getNoNil( getXMLInt(xmlFile, curKey .. '#field'), 24);
		self.cp.speeds.street 			 = Utils.getNoNil( getXMLInt(xmlFile, curKey .. '#max'),   50);

		-- MODE 2
		curKey = key .. '.courseplay.combi';
		self.cp.tipperOffset 		  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#tipperOffset'),			 0);
		self.cp.combineOffset 		  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#combineOffset'),		 0);
		self.cp.combineOffsetAutoMode = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#combineOffsetAutoMode'), true);
		self.cp.followAtFillLevel 	  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#fillFollow'),			 50);
		self.cp.driveOnAtFillLevel 	  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#fillDriveOn'),			 90);
		self.cp.turnRadius 			  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#turnRadius'),			 10);
		self.cp.realisticDriving 	  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#realisticDriving'),		 true);

		-- MODES 4 / 6
		curKey = key .. '.courseplay.fieldWork';
		self.cp.workWidth 			  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#workWidth'),			 3);
		self.cp.ridgeMarkersAutomatic = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#ridgeMarkersAutomatic'), true);
		self.cp.abortWork 			  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#abortWork'),			 0);
		if self.cp.abortWork 		  == 0 then
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
	local speeds = string.format('<speeds useRecordingSpeed=%q unload="%d" turn="%d" field="%d" max="%d" />', tostring(self.cp.speeds.useRecordingSpeed), self.cp.speeds.unload, self.cp.speeds.turn, self.cp.speeds.field, self.cp.speeds.street);
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

