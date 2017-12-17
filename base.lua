local floor = math.floor;

function courseplay.prerequisitesPresent(specializations)
	return true;
end

--[[
function courseplay:preLoad(xmlFile)
end;
]]

function courseplay:load(savegame)
	local xmlFile = self.xmlFile;
	self.setCourseplayFunc = courseplay.setCourseplayFunc;
	self.getIsCourseplayDriving = courseplay.getIsCourseplayDriving;
	self.setIsCourseplayDriving = courseplay.setIsCourseplayDriving;
	self.setCpVar = courseplay.setCpVar;
	
	--SEARCH AND SET self.name IF NOT EXISTING
	if self.name == nil then
		self.name = courseplay:getObjectName(self, xmlFile);
	end;

	if self.cp == nil then self.cp = {}; end;
	self.hasCourseplaySpec = true;

	self.cp.varMemory = {};

	-- XML FILE NAME VARIABLE
	if self.cp.xmlFileName == nil then
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;

	courseplay:setNameVariable(self);
	self.cp.isCombine = courseplay:isCombine(self);
	self.cp.isChopper = courseplay:isChopper(self);
	self.cp.isHarvesterSteerable = courseplay:isHarvesterSteerable(self);
	self.cp.isSugarBeetLoader = courseplay:isSpecialCombine(self, "sugarBeetLoader");
	self.cp.hasHarvesterAttachable = false;
	self.cp.hasSpecialChopper = false;
	if self.cp.isCombine or self.cp.isHarvesterSteerable then
		self.cp.mode7Unloading = false
		self.cp.driverPriorityUseFillLevel = false;
	end
	self.cp.speedDebugLine = "no speed info"
	self.cp.stopWhenUnloading = false;

	-- GIANT DLC
	self.cp.haveInversedRidgeMarkerState = nil; --bool

	-- --More Realistlitic Mod. Temp fix until we can fix the breaking problem. 
	self.cp.changedMRMod = false;

	--turn maneuver
	self.cp.turnOnField = true;
	self.cp.oppositeTurnMode = false;
	self.cp.waitForTurnTime = 0.00   --float
	self.cp.lowerToolThisTurnLoop = true;
	self.cp.turnStage = 0 --int
	self.cp.aiTurnNoBackward = false --bool
	self.cp.canBeReversed = nil --bool
	self.cp.backMarkerOffset = nil --float
	self.cp.aiFrontMarker = nil --float
	self.cp.turnTimer = 8000 --int
	self.cp.noStopOnEdge = false --bool
	self.cp.noStopOnTurn = false --bool
	self.cp.noWorkArea = false -- bool

	self.cp.combineOffsetAutoMode = true
	self.cp.isDriving = false;
	self.cp.runOnceStartCourse = false;
	self.cp.stopAtEnd = false;
	self.cp.stopAtEndMode1 = false;
	self.cp.calculatedCourseToCombine = false

	self.cp.waypointIndex = 1;
	self.cp.previousWaypointIndex = 1;
	self.cp.recordingTimer = 1
	self.timer = 0.00
	self.cp.timers = {}; 
	self.cp.driveSlowTimer = 0;
	self.cp.positionWithCombine = nil;

	--Mode 1 Run Loop
 	self.cp.runNumber = 11; -- Number of times to run Mode 1. Set to 11 for unlimited runs by default.
 	self.cp.runCounter = 0; -- Current Number of runs
	self.cp.runReset = false; -- Resets run loop at stop.
	self.cp.runCounterBool = false; 

	-- RECORDING
	self.cp.isRecording = false;
	self.cp.recordingIsPaused = false;
	self.cp.isRecordingTurnManeuver = false;
	self.cp.drivingDirReverse = false;

	self.cp.waitPoints = {};
	self.cp.numWaitPoints = 0;
	self.cp.unloadPoints = {};
	self.cp.numUnloadPoints = 0;
	self.cp.waitTime = 0;
	self.cp.crossingPoints = {};
	self.cp.numCrossingPoints = 0;

	self.cp.visualWaypointsStartEnd = true;
	self.cp.visualWaypointsAll = false;
	self.cp.visualWaypointsCrossing = false;
	self.cp.warningLightsMode = 1;
	self.cp.hasHazardLights = self.turnLightState ~= nil and self.setTurnLightState ~= nil;


	-- saves the shortest distance to the next waypoint (for recocnizing circling)
	self.cp.shortestDistToWp = nil

	self.Waypoints = {}
	self.cp.isEntered = false
	self.cp.remoteIsEntered = false
	self.cp.canDrive = false --can drive course (has >4 waypoints, is not recording)
	self.cp.coursePlayerNum = nil;

	self.cp.infoText = nil; -- info text in tractor
	self.cp.toolTip = nil;

	-- global info text - also displayed when not in vehicle
	self.cp.hasSetGlobalInfoTextThisLoop = {};
	self.cp.activeGlobalInfoTexts = {};
	self.cp.numActiveGlobalInfoTexts = 0;

	

	-- CP mode
	self.cp.mode = 5;
	courseplay:setNextPrevModeVars(self);
	self.cp.modeState = 0
	self.cp.mode2nextState = nil;
	self.cp.heapStart = nil
	self.cp.heapStop = nil
	self.cp.makeHeaps = false
	-- for modes 4 and 6, this the index of the waypoint where the work begins
	self.cp.startWork = nil
	-- for modes 4 and 6, this the index of the waypoint where the work ends
	self.cp.stopWork = nil
	self.cp.abortWork = nil
	self.cp.abortWorkExtraMoveBack = 0;
	self.cp.hasUnloadingRefillingCourse = false;
	self.cp.hasTransferCourse = false
	self.cp.wait = true;
	self.cp.waitTimer = nil;
	self.cp.realisticDriving = true;
	self.cp.ploughFieldEdge = false;
	self.cp.canSwitchMode = false;
	self.cp.tipperLoadMode = 0;
	self.cp.easyFillTypeList = {};
	self.cp.siloSelectedFillType = FillUtil.FILLTYPE_UNKNOWN;
	self.cp.siloSelectedEasyFillType = 1;
	self.cp.slippingStage = 0;
	self.cp.isTipping = false;
	self.cp.hasPlough = false;
	self.cp.hasRotateablePlough = false;
	self.cp.isNotAllowedToDrive = false;
	self.cp.allwaysSearchFuel = false;
	self.cp.saveFuel = false;
	self.cp.saveFuelOptionActive = true;
	self.cp.hasAugerWagon = false;
	self.cp.hasSugarCaneAugerWagon = false
	self.cp.hasSugarCaneTrailer = false
	self.cp.generationPosition = {}
	self.cp.generationPosition.hasSavedPosition = false
	
	self.cp.startAtPoint = courseplay.START_AT_NEXT_POINT;
	self.cp.fertilizerOption = true
	self.cp.convoyActive = false
	self.cp.convoy= {
					  distance = 0,
					  number = 0,
					  members = 0,
					  }
	
	
	

	-- ai mode 9: shovel
	self.cp.shovelEmptyPoint = nil;
	self.cp.shovelFillStartPoint = nil;
	self.cp.shovelFillEndPoint = nil;
	self.cp.shovelState = 1;
	self.cp.shovel = {};
	self.cp.shovelStopAndGo = true;
	self.cp.shovelLastFillLevel = nil;
	self.cp.shovelStatePositions = {};
	self.cp.hasShovelStatePositions = {};
	self.cp.manualShovelPositionOrder = nil;
	for i=2,5 do
		self.cp.hasShovelStatePositions[i] = false;
	end;
	
	--ai mode 10 : bunkersilo
	self.cp.mode10 = {}
	self.cp.mode10.stoppedCourseplayers = {}
	self.cp.mode10.alphaList = {}		
	self.cp.mode10.leveling = true
	self.cp.mode10.automaticHeigth = true
	self.cp.mode10.searchRadius = 50
	self.cp.mode10.searchCourseplayersOnly = false
	self.cp.mode10.shieldHeight = 0.3
	self.cp.mode10.levelerIsFrontAttached = false
 	self.cp.mode10.jumpsPerRun = 0
	self.cp.mode10.automaticSpeed = true
	self.cp.mode10.lowestAlpha = 99
	self.cp.mode10.lastTargetLine = 99
	self.cp.mode10.deadline = nil
	self.cp.mode10.firstLine = 0
	self.cp.mode10.bladeOffset = 0
	self.cp.mode10.drivingThroughtLoading = false
	
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
	self.cp.turnTargets = {};
	self.cp.curTurnIndex = 1;

	-- alignment course data
	-- alignment course enabled for developers by default
	self.cp.alignment = { enabled = CpManager.isDeveloper }

	-- speed limits
	self.cp.speeds = {
		useRecordingSpeed = true;
		reverse =  6;
		turn =   10;
		field =  24;
		street = self.cruiseControl.maxSpeed or 50;
		crawl = 3;
		discharge = 8;
		bunkerSilo = 20;
		
		minReverse = 3;
		minTurn = 3;
		minField = 3;
		minStreet = 3;
		max = self.cruiseControl.maxSpeed or 60;
	};

	self.cp.tooIsDirty = false
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

	-- DIRECTION NODE SETUP
	local DirectionNode;
	if self.aiVehicleDirectionNode ~= nil then
		if self.cp.componentNumAsDirectionNode then
			DirectionNode = self.components[self.cp.componentNumAsDirectionNode].node;
		else
			DirectionNode = self.aiVehicleDirectionNode;
		end;
	else
		if courseplay:isWheelloader(self)then
			if self.cp.hasSpecializationArticulatedAxis then
				local nodeIndex = Utils.getNoNil(self.cp.componentNumAsDirectionNode, 2)
				if self.components[nodeIndex] ~= nil then
					DirectionNode = self.components[nodeIndex].node;
				end
			end;
		end
		if DirectionNode == nil then
			DirectionNode = self.rootNode;
		end
	end;

	local directionNodeOffset, isTruck = courseplay:getVehicleDirectionNodeOffset(self, DirectionNode);
	if directionNodeOffset ~= 0 then
		self.cp.oldDirectionNode = DirectionNode;  -- Only used for debugging.
		DirectionNode = courseplay:createNewLinkedNode(self, "realDirectionNode", DirectionNode);
		setTranslation(DirectionNode, 0, 0, directionNodeOffset);
	end;
	self.cp.DirectionNode = DirectionNode;

	-- REVERSE DRIVING SETUP
	if self.cp.hasSpecializationReverseDriving then
		self.cp.reverseDrivingDirectionNode = courseplay:createNewLinkedNode(self, "realReverseDrivingDirectionNode", self.cp.DirectionNode);
		setRotation(self.cp.reverseDrivingDirectionNode, 0, math.rad(180), 0);
	end;

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
	if self.maxRotation then
		self.cp.steeringAngle = math.deg(self.maxRotation);
	else
		self.cp.steeringAngle = 30;
	end
	if isTruck then
		self.cp.revSteeringAngle = self.cp.steeringAngle * 0.25;
	end;
	if self.cp.steeringAngleCorrection then
		self.cp.steeringAngle = Utils.getNoNil(self.cp.steeringAngleCorrection, self.cp.steeringAngle);
	elseif self.cp.steeringAngleMultiplier then
		self.cp.steeringAngle = self.cp.steeringAngle * self.cp.steeringAngleMultiplier;
	end;
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
	courseplay:setOwnFillLevelsAndCapacities(self)

	-- workTools
	self.cp.workTools = {};
	self.cp.numWorkTools = 0;
	self.cp.workToolAttached = false;
	self.cp.currentTrailerToFill = nil;
	self.cp.trailerFillDistance = nil;
	self.cp.prevTrailerDistance = 100.00;
	self.cp.isUnloaded = false;
	self.cp.isLoaded = false;
	self.cp.totalFillLevel = nil;
	self.cp.totalCapacity = nil;
	self.cp.totalFillLevelPercent = 0;
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

	self.cp.vehicleTurnRadius = courseplay:getVehicleTurnRadius(self);
	self.cp.turnDiameter = self.cp.vehicleTurnRadius * 2;
	self.cp.turnDiameterAuto = self.cp.vehicleTurnRadius * 2;
	self.cp.turnDiameterAutoMode = true;

	--Offset
	self.cp.laneOffset = 0;
	self.cp.toolOffsetX = 0;
	self.cp.toolOffsetZ = 0;
	self.cp.totalOffsetX = 0;
	self.cp.symmetricLaneChange = false;
	self.cp.switchLaneOffset = false;
	self.cp.switchToolOffset = false;
	self.cp.loadUnloadOffsetX = 0;
	self.cp.loadUnloadOffsetZ = 0;
	self.cp.skipOffsetX = false;

	self.cp.workWidth = 3
	self.cp.headlandHeight = 0;

	self.cp.searchCombineAutomatically = true;
	self.cp.savedCombine = nil
	self.cp.selectedCombineNumber = 0
	self.cp.searchCombineOnField = 0;

	--Copy course
	self.cp.hasFoundCopyDriver = false;
	self.cp.copyCourseFromDriver = nil;
	self.cp.selectedDriverNumber = 0;

	--MultiTools
	self.cp.multiTools = 1;
	self.cp.laneNumber = 0;

	--Course generation	
	self.cp.startingCorner = 0;
	self.cp.hasStartingCorner = false;
	self.cp.startingDirection = 0;
	self.cp.hasStartingDirection = false;
	self.cp.returnToFirstPoint = false;
	self.cp.hasGeneratedCourse = false;
	self.cp.hasValidCourseGenerationData = false;
	self.cp.ridgeMarkersAutomatic = true;
	self.cp.bypassIslands = false;
	self.cp.headland = {
		maxNumLanes = 6;
		-- with the old, manual direction selection course generator
		manuDirMaxNumLanes = 6;
		-- with the new, auto direction selection course generator
		autoDirMaxNumLanes = 20;
		numLanes = 0;
		userDirClockwise = true;
		orderBefore = true;

		turnType = courseplay.HEADLAND_CORNER_TYPE_SMOOTH;
		reverseManeuverType = courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_STRAIGHT;
		
		tg = createTransformGroup('cpPointOrig_' .. tostring(self.rootNode));

		rectWidthRatio = 1.25;
		noGoWidthRatio = 0.975;
		minPointDistance = 0.5;
		maxPointDistance = 7.25;
	};
	link(getRootNode(), self.cp.headland.tg);
	if CpManager.isDeveloper then
		self.cp.headland.manuDirMaxNumLanes = 30;
		self.cp.headland.autoDirMaxNumLanes = 50;
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

	-- 2D course
	self.cp.drawCourseMode = courseplay.COURSE_2D_DISPLAY_OFF;
	-- 2D pda map background -- TODO: MP?
    if g_currentMission.ingameMap and g_currentMission.ingameMap.mapOverlay and g_currentMission.ingameMap.mapOverlay.filename then
		self.cp.course2dPdaMapOverlay = Overlay:new('cpPdaMap', g_currentMission.ingameMap.mapOverlay.filename, 0, 0, 1, 1);
		self.cp.course2dPdaMapOverlay:setColor(1, 1, 1, CpManager.course2dPdaMapOpacity);
	end;

	-- HUD
	courseplay.hud:setupVehicleHud(self);

	courseplay:validateCanSwitchMode(self);
	courseplay.buttons:setActiveEnabled(self, 'all');
end;

function courseplay:postLoad(savegame)
    if savegame ~= nil and savegame.key ~= nil and not savegame.resetVehicles then
		courseplay.loadVehicleCPSettings(self, savegame.xmlFile, savegame.key, savegame.resetVehicles)
    end

	-- Drive Control (upsidedown)
	if self.driveControl ~= nil and g_currentMission.driveControl ~= nil then
		self.cp.hasDriveControl = true;
		self.cp.driveControl = {
			hasFourWD = g_currentMission.driveControl.useModules.fourWDandDifferentials and not self.driveControl.fourWDandDifferentials.isSurpressed;
			hasHandbrake = g_currentMission.driveControl.useModules.handBrake;
			hasManualMotorStart = g_currentMission.driveControl.useModules.manMotorStart;
			hasMotorKeepTurnedOn = g_currentMission.driveControl.useModules.manMotorKeepTurnedOn;
			hasShuttleMode = g_currentMission.driveControl.useModules.shuttle;
			--alwaysUseFourWD = false;
			mode = 0;
			OFF = 0;
			AWD = 1;
			AWD_FRONT_DIFF = 2;
			AWD_REAR_DIFF = 3;
			AWD_BOTH_DIFF = 4;
		};

		-- add "always use 4WD" button. This was moved into hud and shown based off conditions in button
		-- if self.cp.driveControl.hasFourWD then
		-- 	--courseplay.button:new(self, 5, nil, 'toggleAlwaysUseFourWD', nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[7], courseplay.hud.contentMaxWidth, 0.015, 7, nil, true);
		-- end
	end;
end;

function courseplay:onLeave()
	if self.cp.mouseCursorActive then
		courseplay:setMouseCursor(self, false);
	end

	--hide visual i3D waypoint signs when not in vehicle
	courseplay.signs:setSignsVisibility(self, true);
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
	--DEBUG Speed Setting
	if courseplay.debugChannels[21] then
		renderText(0.2, 0.105, 0.02, string.format("mode%d waypointIndex: %d",self.cp.mode,self.cp.waypointIndex));
		renderText(0.2, 0.075, 0.02, self.cp.speedDebugLine);
		if self.cp.speedDebugStreet then
			local mode = "max"
			local speed = self.cp.speeds.street
			if self.cp.speeds.useRecordingSpeed then
				mode = "wpt"
				if self.Waypoints and self.Waypoints[self.cp.waypointIndex] and self.Waypoints[self.cp.waypointIndex].speed then
					speed = self.Waypoints[self.cp.waypointIndex].speed
				else
					speed = "no speed"
				end
			end			
			renderText(0.2, 0.045, 0.02, string.format("mode[%s] speed: %s",mode,tostring(speed)));
		end	
		if (self.cp.mode == 2 or self.cp.mode ==3) and self.cp.activeCombine ~= nil then
			local combine = self.cp.activeCombine	
			renderText(0.2,0.165,0.02,string.format("combine.lastSpeedReal: %.6f ",combine.lastSpeedReal*3600))
			renderText(0.2,0.135,0.02,"combineIsTurning: "..tostring(self.cp.mode2DebugTurning ))
		end	
	end
	if courseplay.debugChannels[10] and self.cp.BunkerSiloMap ~= nil and self.cp.actualTarget ~= nil then

		local fillUnit = self.cp.BunkerSiloMap[self.cp.actualTarget.line][self.cp.actualTarget.column]
		--print(string.format("fillUnit %s; self.cp.actualTarget.line %s; self.cp.actualTarget.column %s",tostring(fillUnit),tostring(self.cp.actualTarget.line),tostring(self.cp.actualTarget.column)))
		local sx,sz = fillUnit.sx,fillUnit.sz
		local wx,wz = fillUnit.wx,fillUnit.wz
		local bx,bz = fillUnit.bx,fillUnit.bz
		local hx,hz = fillUnit.hx +(fillUnit.wx-fillUnit.sx) ,fillUnit.hz +(fillUnit.wz-fillUnit.sz)
		local y = 0
		local height = fillUnit.height or 0.5;
		if self.cp.mode10.leveling then
			if self.cp.mode10.automaticHeigth then
				y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 1, sz)+ height;
			else
				y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 1, sz) + self.cp.mode10.shieldHeight + self.cp.tractorHeight ;
			end
		else
			y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 1, sz) + 0.5;
		end
		drawDebugLine(sx, y, sz, 1, 0, 0, wx, y, wz, 1, 0, 0);
		drawDebugLine(wx, y, wz, 1, 0, 0, hx, y, hz, 1, 0, 0);
		drawDebugLine(fillUnit.hx, y, fillUnit.hz, 1, 0, 0, sx, y, sz, 1, 0, 0);
		drawDebugLine(fillUnit.cx, y, fillUnit.cz, 1, 0, 1, bx, y, bz, 1, 0, 0);
		drawDebugPoint(fillUnit.cx, y, fillUnit.cz, 1, 1 , 1, 1);
		if self.cp.mode == 9 then
			renderText(0.2,0.225,0.02,"unit.fillLevel: "..tostring(fillUnit.fillLevel))
			if self.cp.mode9SavedLastFillLevel ~= nil then
				renderText(0.2,0.195,0.02,"SavedLastFillLevel: "..tostring(self.cp.mode9SavedLastFillLevel))
				renderText(0.2,0.165,0.02,"triesTheSameFillUnit: "..tostring(self.cp.mode9triesTheSameFillUnit))
			end
		elseif self.cp.mode == 10 then

			renderText(0.2,0.395,0.02,"numStoppedCPs: "..tostring(#self.cp.mode10.stoppedCourseplayers ))
			renderText(0.2,0.365,0.02,"shieldHeight: "..tostring(self.cp.mode10.shieldHeight))
			renderText(0.2,0.335,0.02,"lowestAlpha: "..tostring(self.cp.mode10.lowestAlpha))
			renderText(0.2,0.305,0.02,"speeds.bunkerSilo: "..tostring(self.cp.speeds.bunkerSilo))
			renderText(0.2,0.275,0.02,"jumpsPerRun: "..tostring(self.cp.mode10.jumpsPerRun))
			renderText(0.2,0.245,0.02,"bladeOffset: "..tostring(self.cp.mode10.bladeOffset))
			renderText(0.2,0.215,0.02,"diffY: "..tostring(self.cp.diffY ))
			renderText(0.2,0.195,0.02,"tractorHeight: "..tostring(self.cp.tractorHeight ))
			renderText(0.2,0.165,0.02,"shouldBHeight: "..tostring(self.cp.shouldBHeight ))
			renderText(0.2,0.135,0.02,"targetHeigth: "..tostring(self.cp.mode10.targetHeigth))
			renderText(0.2,0.105,0.02,"height: "..tostring(self.cp.currentHeigth))
		end
	end
	
	if courseplay.debugChannels[10] and self.cp.tempMOde9PointX ~= nil then
		local x,y,z = getWorldTranslation(self.cp.DirectionNode)
		drawDebugLine(self.cp.tempMOde9PointX2,self.cp.tempMOde9PointY2+2,self.cp.tempMOde9PointZ2, 1, 0, 0, self.cp.tempMOde9PointX,self.cp.tempMOde9PointY+2,self.cp.tempMOde9PointZ, 1, 0, 0);
		local bunker = self.cp.mode9TargetSilo
		if bunker ~= nil then
			local sx,sz = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local wx,wz = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local hx,hz = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			drawDebugLine(sx,y+2,sz, 0, 0, 1, wx,y+2,wz, 0, 0, 1);
			drawDebugLine(sx,y+2,sz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
			drawDebugLine(wx,y+2,wz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
		end
	end
	
	
	--DEBUG SHOW DIRECTIONNODE
	if courseplay.debugChannels[12] then
		-- For debugging when setting the directionNodeZOffset. (Visual points shown for old node)
		if self.cp.oldDirectionNode then
			local ox,oy,oz = getWorldTranslation(self.cp.oldDirectionNode);
			drawDebugPoint(ox, oy+4, oz, 0.9098, 0.6902 , 0.2706, 1);
		end;

		local nx,ny,nz = getWorldTranslation(self.cp.DirectionNode);
		drawDebugPoint(nx, ny+4, nz, 0.6196, 0.3490 , 0, 1);
	end;


	-- HELP BUTTON TEXTS
	if self:getIsActive() and self.isEntered and g_currentMission.showHelpText then
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

		if modifierPressed then
			if self.cp.canDrive then
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
			else
				if not self.cp.isRecording and not self.cp.recordingIsPaused and self.cp.numWaypoints == 0 then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_RECORDING_START'), InputBinding.COURSEPLAY_START_STOP);
				elseif self.cp.isRecording and not self.cp.recordingIsPaused and not self.cp.isRecordingTurnManeuver then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_RECORDING_STOP'), InputBinding.COURSEPLAY_START_STOP);
				end;
			end;

			if self.cp.canSwitchMode then
				if self.cp.nextMode then
					g_currentMission:addHelpButtonText(courseplay:loc('input_COURSEPLAY_NEXTMODE'), InputBinding.COURSEPLAY_NEXTMODE);
				end;
				if self.cp.prevMode then
					g_currentMission:addHelpButtonText(courseplay:loc('input_COURSEPLAY_PREVMODE'), InputBinding.COURSEPLAY_PREVMODE);
				end;
			end;
		end;
	end;

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
		if self.cp.distanceCheck and self.cp.numWaypoints > 1 then 
			courseplay:distanceCheck(self);
		elseif self.cp.infoText ~= nil and Utils.startsWith(self.cp.infoText, 'COURSEPLAY_DISTANCE') then  
			self.cp.infoText = nil
			self.cp.infoTextNilSent = false
		end;
		
		if self.isEntered and self.cp.toolTip ~= nil then
			courseplay:renderToolTip(self);
		end;
	end;


	--RENDER
	courseplay:renderInfoText(self);

	if self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_2DONLY or self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_BOTH then
		courseplay:drawCourse2D(self, false);
	end;
end; --END draw()

function courseplay:showWorkWidth(vehicle)
	local offsX, offsZ = vehicle.cp.toolOffsetX or 0, vehicle.cp.toolOffsetZ or 0;

	local left =  (vehicle.cp.workWidth *  0.5) + offsX;
	local right = (vehicle.cp.workWidth * -0.5) + offsX;


	if vehicle.cp.DirectionNode and vehicle.cp.backMarkerOffset and vehicle.cp.aiFrontMarker then
		local p1x, p1y, p1z = localToWorld(vehicle.cp.DirectionNode, left,  1.6, vehicle.cp.backMarkerOffset - offsZ);
		local p2x, p2y, p2z = localToWorld(vehicle.cp.DirectionNode, right, 1.6, vehicle.cp.backMarkerOffset - offsZ);
		local p3x, p3y, p3z = localToWorld(vehicle.cp.DirectionNode, right, 1.6, vehicle.cp.aiFrontMarker - offsZ);
		local p4x, p4y, p4z = localToWorld(vehicle.cp.DirectionNode, left,  1.6, vehicle.cp.aiFrontMarker - offsZ);

		drawDebugPoint(p1x, p1y, p1z, 1, 1, 0, 1);
		drawDebugPoint(p2x, p2y, p2z, 1, 1, 0, 1);
		drawDebugPoint(p3x, p3y, p3z, 1, 1, 0, 1);
		drawDebugPoint(p4x, p4y, p4z, 1, 1, 0, 1);

		drawDebugLine(p1x, p1y, p1z, 1, 0, 0, p2x, p2y, p2z, 1, 0, 0);
		drawDebugLine(p2x, p2y, p2z, 1, 0, 0, p3x, p3y, p3z, 1, 0, 0);
		drawDebugLine(p3x, p3y, p3z, 1, 0, 0, p4x, p4y, p4z, 1, 0, 0);
		drawDebugLine(p4x, p4y, p4z, 1, 0, 0, p1x, p1y, p1z, 1, 0, 0);
	else
		local lX, lY, lZ = localToWorld(vehicle.rootNode, left,  1.6, -6 - offsZ);
		local rX, rY, rZ = localToWorld(vehicle.rootNode, right, 1.6, -6 - offsZ);

		drawDebugPoint(lX, lY, lZ, 1, 1, 0, 1);
		drawDebugPoint(rX, rY, rZ, 1, 1, 0, 1);

		drawDebugLine(lX, lY, lZ, 1, 0, 0, rX, rY, rZ, 1, 0, 0);
	end;
end;

function courseplay:drawWaypointsLines(vehicle)
	if not CpManager.isDeveloper or not vehicle.isControlled or vehicle ~= g_currentMission.controlledVehicle then return; end;

	local height = 2.5;
	local r,g,b,a;
	for i,wp in pairs(vehicle.Waypoints) do
		if wp.cy == nil or wp.cy == 0 then
			wp.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.cx, 1, wp.cz);
		end;
		local np = vehicle.Waypoints[i+1];
		if np and (np.cy == nil or np.cy == 0) then
			np.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, np.cx, 1, np.cz);
		end;

		if i == 1 or wp.turnStart then
			r,g,b,a = 0, 1, 0, 1;
		elseif i == vehicle.cp.numWaypoints or wp.turnEnd then
			r,g,b,a = 1, 0, 0, 1;
		elseif i == vehicle.cp.waypointIndex then
			r,g,b,a = 0.9, 0, 0.6, 1;
		else
			r,g,b,a = 1, 1, 0, 1;
		end;
		drawDebugPoint(wp.cx, wp.cy + height, wp.cz, r,g,b,a);

		if i < vehicle.cp.numWaypoints then
			if i + 1 == vehicle.cp.waypointIndex then
				drawDebugLine(wp.cx, wp.cy + height, wp.cz, 0.9, 0, 0.6, np.cx, np.cy + height, np.cz, 1, 0.4, 0.05);
			else
				drawDebugLine(wp.cx, wp.cy + height, wp.cz, 0, 1, 1, np.cx, np.cy + height, np.cz, 0, 1, 1);
			end;
		end;
	end;
end;

function courseplay:update(dt)
	-- KEYBOARD EVENTS
	if self:getIsActive() and self.isEntered and InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
		if InputBinding.hasEvent(InputBinding.COURSEPLAY_START_STOP) then
			if self.cp.canDrive then
				if self.cp.isDriving then
					self:setCourseplayFunc('stop', nil, false, 1);
				else
					self:setCourseplayFunc('start', nil, false, 1);
				end;
			else
				if not self.cp.isRecording and not self.cp.recordingIsPaused and self.cp.numWaypoints == 0 then
					self:setCourseplayFunc('start_record', nil, false, 1);
				elseif self.cp.isRecording and not self.cp.recordingIsPaused and not self.cp.isRecordingTurnManeuver then
					self:setCourseplayFunc('stop_record', nil, false, 1);
				end;
			end;
		elseif InputBinding.hasEvent(InputBinding.COURSEPLAY_CANCELWAIT) and self.cp.HUD1wait and self.cp.canDrive and self.cp.isDriving then
			self:setCourseplayFunc('cancelWait', true, false, 1);
		elseif InputBinding.hasEvent(InputBinding.COURSEPLAY_DRIVENOW) and self.cp.HUD1noWaitforFill and self.cp.canDrive and self.cp.isDriving then
			self:setCourseplayFunc('setIsLoaded', true, false, 1);
		elseif InputBinding.hasEvent(InputBinding.COURSEPLAY_STOP_AT_END) and self.cp.canDrive and self.cp.isDriving then
			self:setCourseplayFunc('setStopAtEnd', not self.cp.stopAtEnd, false, 1);
		elseif self.cp.canSwitchMode and self.cp.nextMode and InputBinding.hasEvent(InputBinding.COURSEPLAY_NEXTMODE) then
			self:setCourseplayFunc('setCpMode', self.cp.nextMode, false, 1);
		elseif self.cp.canSwitchMode and self.cp.prevMode and InputBinding.hasEvent(InputBinding.COURSEPLAY_PREVMODE) then
			self:setCourseplayFunc('setCpMode', self.cp.prevMode, false, 1);
		end;

		if not self.cp.openHudWithMouse and InputBinding.hasEvent(InputBinding.COURSEPLAY_HUD) then
			self:setCourseplayFunc('openCloseHud', not self.cp.hud.show, true);
		end;
	end; -- self:getIsActive() and self.isEntered and modifierPressed
	
	if not self.cp.remoteIsEntered then
		if self.cp.isEntered ~= self.isEntered then
			CourseplayEvent.sendEvent(self, "self.cp.remoteIsEntered",self.isEntered)
		end
		self:setCpVar('isEntered',self.isEntered)
	end
	
	if not courseplay.isClient then -- and self.cp.infoText ~= nil then --(self.cp.isDriving or self.cp.isRecording or self.cp.recordingIsPaused) then
		if self.cp.infoText == nil and not self.cp.infoTextNilSent then
			CourseplayEvent.sendEvent(self, "self.cp.infoText",nil)
			self.cp.infoTextNilSent = true
		elseif self.cp.infoText ~= nil then
			self.cp.infoText = nil
		end
	end;

	if CpManager.isDeveloper and (self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_DBGONLY or self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_BOTH) then
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
		
		self.cp.isNotAllowedToDrive = false
		
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

	if not courseplay.isClient then
		if self.cp.isDriving then
			local showDriveOnButton = false;
			if self.cp.mode == courseplay.MODE_FIELDWORK then
				if self.cp.wait and (self.cp.waypointIndex == self.cp.stopWork or self.cp.previousWaypointIndex == self.cp.stopWork) and self.cp.abortWork == nil and not self.cp.isLoaded and not isFinishingWork and self.cp.hasUnloadingRefillingCourse then
					showDriveOnButton = true;
				end;
			else
				if (self.cp.wait and (self.Waypoints[self.cp.waypointIndex].wait or self.Waypoints[self.cp.previousWaypointIndex].wait)) or (self.cp.stopAtEnd and (self.cp.waypointIndex == self.cp.numWaypoints or self.cp.currentTipTrigger ~= nil)) or (self.cp.runReset and self.cp.runCounter ~= 0) then
					showDriveOnButton = true;
				end;
			end;
			self:setCpVar('HUD1wait', showDriveOnButton,courseplay.isClient);

			self:setCpVar('HUD1noWaitforFill', not self.cp.isLoaded and self.cp.mode ~= 5,courseplay.isClient);
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
			if self.cp.attachedCombine then
				combine = self.cp.attachedCombine;
			end;
			if combine.courseplayers == nil then
				self:setCpVar('HUD0noCourseplayer', true,courseplay.isClient);
				combine.courseplayers = {};
			else
				self:setCpVar('HUD0noCourseplayer', #combine.courseplayers == 0,courseplay.isClient);
			end
			self:setCpVar('HUD0wantsCourseplayer', combine.cp.wantsCourseplayer,courseplay.isClient);
			self:setCpVar('HUD0combineForcedSide', combine.cp.forcedSide,courseplay.isClient);
			self:setCpVar('HUD0isManual', not self.cp.isDriving and not combine.aiIsStarted,courseplay.isClient);
			self:setCpVar('HUD0turnStage', self.cp.turnStage,courseplay.isClient);
			local tractor = combine.courseplayers[1]
			if tractor ~= nil then
				self:setCpVar('HUD0tractorForcedToStop', tractor.cp.forcedToStop,courseplay.isClient);
				self:setCpVar('HUD0tractorName', tostring(tractor.name),courseplay.isClient);
				self:setCpVar('HUD0tractor', true,courseplay.isClient);
			else
				self:setCpVar('HUD0tractorForcedToStop', nil,courseplay.isClient);
				self:setCpVar('HUD0tractorName', nil,courseplay.isClient);
				self:setCpVar('HUD0tractor', false,courseplay.isClient);
			end;

		elseif self.cp.hud.currentPage == 1 then
			if self:getIsActive() and not self.cp.canDrive and self.cp.fieldEdge.customField.show and self.cp.fieldEdge.customField.points ~= nil then
				courseplay:showFieldEdgePath(self, "customField");
			end;


		elseif self.cp.hud.currentPage == 4 then
			self:setCpVar('HUD4hasActiveCombine', self.cp.activeCombine ~= nil,courseplay.isClient);
			if self.cp.HUD4hasActiveCombine == true then
				self:setCpVar('HUD4combineName', self.cp.activeCombine.name,courseplay.isClient);
			end
			self:setCpVar('HUD4savedCombine', self.cp.savedCombine ~= nil and self.cp.savedCombine.rootNode ~= nil,courseplay.isClient);
			if self.cp.savedCombine ~= nil then
				self:setCpVar('HUD4savedCombineName', self.cp.savedCombine.name,courseplay.isClient);
			end

		elseif self.cp.hud.currentPage == 8 then
			if self:getIsActive() and self.cp.fieldEdge.selectedField.show and self.cp.fieldEdge.selectedField.fieldNum > 0 and self == g_currentMission.controlledVehicle then
				courseplay:showFieldEdgePath(self, "selectedField");
			end;
		end;
	end;
	
	--Not sure if this needs to be reenabled? During my test this produced a nil error
	--[[if g_server ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer then 
		for k,v in pairs(courseplay.checkValues) do
			self.cp[v .. "Memory"] = courseplay:checkForChangeAndBroadcast(self, "self.cp." .. v , self.cp[v], self.cp[v .. "Memory"]);
		end;
	end;]]
	
	
	if self.cp.collidingVehicleId ~= nil and g_currentMission.nodeToVehicle[self.cp.collidingVehicleId] ~= nil and g_currentMission.nodeToVehicle[self.cp.collidingVehicleId].isCpPathvehicle then
		courseplay:setPathVehiclesSpeed(self,dt)
	end

	-- MODE 9: move shovel to positions (manually)
	if self.cp.mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY and self.cp.manualShovelPositionOrder ~= nil and self.cp.movingToolsPrimary then
		if courseplay:checkAndSetMovingToolsPosition(self, self.cp.movingToolsPrimary, self.cp.movingToolsSecondary, self.cp.shovelStatePositions[ self.cp.manualShovelPositionOrder ], dt) or courseplay:timerIsThrough(self, 'manualShovelPositionOrder') then
			courseplay:resetManualShovelPositionOrder(self);
		end;
	end;
	-- MODE 3: move pipe to positions (manually)
	if (self.cp.mode == courseplay.MODE_OVERLOADER or self.cp.mode == courseplay.MODE_GRAIN_TRANSPORT) and self.cp.manualPipePositionOrder ~= nil and self.cp.pipeWorkToolIndex then
		local workTool = self.attachedImplements[self.cp.pipeWorkToolIndex].object
		if courseplay:checkAndSetMovingToolsPosition(self, workTool.movingTools, nil, self.cp.pipePositions, dt , self.cp.pipeIndex ) or courseplay:timerIsThrough(self, 'manualPipePositionOrder') then
			courseplay:resetManualPipePositionOrder(self);
		end;
	end;
	
	--sugarCaneTrailer update tipping function
	if self.cp.hasSugarCaneTrailer then
		courseplay:updateSugarCaneTrailerTipping(self,dt)
	end
	
end; --END update()

--[[
function courseplay:postUpdate(dt)
end;
]]

function courseplay:updateTick(dt)
	if not self.cp.fieldEdge.selectedField.buttonsCreated and courseplay.fields.numAvailableFields > 0 then
		courseplay:createFieldEdgeButtons(self);
	end;

	--attached or detached implement?
	if self.cp.tooIsDirty then
		self.cpTrafficCollisionIgnoreList = {}
		courseplay:resetTools(self)
	end

	self.timer = self.timer + dt;
end

--[[
function courseplay:postUpdateTick(dt)
end;
]]

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

		if self.cp.hud.bg ~= nil then
			self.cp.hud.bg:delete();
		end;
		if self.cp.hud.bgWithModeButtons ~= nil then
			self.cp.hud.bgWithModeButtons:delete();
		end;
		if self.cp.hud.suc ~= nil then
			self.cp.hud.suc:delete();
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
		if self.cp.course2dPdaMapOverlay then
			self.cp.course2dPdaMapOverlay:delete();
		end;
	end;
end;

function courseplay:setInfoText(vehicle, text)
	if not vehicle.cp.isEntered then
		return
	end
	if vehicle.cp.infoText ~= text and  text ~= nil and vehicle.cp.lastInfoText ~= text then
		vehicle:setCpVar('infoText',text,courseplay.isClient)
		vehicle.cp.lastInfoText = text
		vehicle.cp.infoTextNilSent = false
	elseif vehicle.cp.infoText ~= text and  text ~= nil and vehicle.cp.lastInfoText == text then
		vehicle:setCpVar('infoText',text,true)
		vehicle.cp.infoTextNilSent = false
	end;
end;

function courseplay:renderInfoText(vehicle)
	if vehicle.isEntered and vehicle.cp.infoText ~= nil and vehicle.cp.toolTip == nil then
		local text;
		local what = Utils.splitString(";", vehicle.cp.infoText);
		
		if what[1] == "COURSEPLAY_LOADING_AMOUNT"
		or what[1] == "COURSEPLAY_TURNING_TO_COORDS"
		or what[1] == "COURSEPLAY_DRIVE_TO_WAYPOINT" then
			if what[3] then	 
				text = string.format(courseplay:loc(what[1]), tonumber(what[2]), tonumber(what[3]));
			end		
		elseif what[1] == "COURSEPLAY_STARTING_UP_TOOL" 
		or what[1] == "COURSEPLAY_WAITING_POINTS_TOO_FEW"
		or what[1] == "COURSEPLAY_WAITING_POINTS_TOO_MANY"
		or what[1] == "COURSEPLAY_UNLOADING_POINTS_TOO_FEW"
		or what[1] == "COURSEPLAY_UNLOADING_POINTS_TOO_MANY" then
			if what[2] then
				text = string.format(courseplay:loc(what[1]), what[2]);
			end
		elseif what[1] == "COURSEPLAY_DISTANCE" then  
			if what[2] then
				local dist = tonumber(what[2]);
				if dist >= 1000 then
					text = ('%s: %.1f%s'):format(courseplay:loc('COURSEPLAY_DISTANCE'), dist * 0.001, courseplay:getMeasuringUnit());
				else
					text = ('%s: %d%s'):format(courseplay:loc('COURSEPLAY_DISTANCE'), dist, courseplay:loc('COURSEPLAY_UNIT_METER'));
				end;
			end
		else
			text = courseplay:loc(vehicle.cp.infoText)
		end;

		if text then
			courseplay:setFontSettings('white', false, 'left');
			renderText(courseplay.hud.infoTextPosX, courseplay.hud.infoTextPosY, courseplay.hud.fontSizes.infoText, text);
		end;
	end;
end;

function courseplay:setToolTip(vehicle, text)
	if vehicle.cp.toolTip ~= text then
		vehicle.cp.toolTip = text;
	end;
end;

function courseplay:renderToolTip(vehicle)
	courseplay:setFontSettings('white', false, 'left');
	renderText(courseplay.hud.toolTipTextPosX, courseplay.hud.toolTipTextPosY, courseplay.hud.fontSizes.infoText, vehicle.cp.toolTip);
	vehicle.cp.hud.toolTipIcon:render();
end;


function courseplay:readStream(streamId, connection)
	courseplay:debug("id: "..tostring(self.id).."  base: readStream", 5)
		
	for _,variable in ipairs(courseplay.multiplayerSyncTable)do
		local value = courseplay.streamDebugRead(streamId, variable.dataFormat)
		if variable.dataFormat == 'String' and value == 'nil' then
			value = nil
		end
		courseplay:setVarValueFromString(self, variable.name, value)
	end
	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: read courseplay.multiplayerSyncTable end", 5)
	
	local savedFieldNum = streamDebugReadInt32(streamId)
	if savedFieldNum > 0 then
		self.cp.generationPosition.fieldNum = savedFieldNum
	end
		
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
	
	self.cp.numCourses = streamDebugReadInt32(streamId)
	
	--print(string.format("%s:read: numCourses: %s loadedCourses: %s",tostring(self.name),tostring(self.cp.numCourses),tostring(#self.cp.loadedCourses)))
	if self.cp.numCourses > #self.cp.loadedCourses then
		self.Waypoints = {}
		local wp_count = streamDebugReadInt32(streamId)
		for w = 1, wp_count do
			--courseplay:debug("got waypoint", 8);
			--print("reading "..tostring(w))
			local cx = streamDebugReadFloat32(streamId)
			local cz = streamDebugReadFloat32(streamId)
			local angle = streamDebugReadFloat32(streamId)
			local wait = streamDebugReadBool(streamId)
			local rev = streamDebugReadBool(streamId)
			local crossing = streamDebugReadBool(streamId)
			local speed = streamDebugReadInt32(streamId)

			local generated = streamDebugReadBool(streamId)
			--local dir = streamDebugReadString(streamId)
			local turnStart = streamDebugReadBool(streamId)
			local turnEnd = streamDebugReadBool(streamId)
			local ridgeMarker = streamDebugReadInt32(streamId)
			
			local wp = {
				cx = cx, 
				cz = cz, 
				angle = angle, 
				wait = wait, 
				rev = rev, 
				crossing = crossing, 
				speed = speed,
				generated = generated,
				turnStart = turnStart,
				turnEnd = turnEnd,
				ridgeMarker = ridgeMarker 
			};
			table.insert(self.Waypoints, wp)
		end
		self.cp.numWaypoints = #self.Waypoints
		
		if self.cp.numCourses > 1 then
			self.cp.currentCourseName = string.format("%d %s", self.cp.numCourses, courseplay:loc('COURSEPLAY_COMBINED_COURSES'));
		end
	end

	
	local debugChannelsString = streamDebugReadString(streamId)
	for k,v in pairs(Utils.splitString(",", debugChannelsString)) do
		courseplay:toggleDebugChannel(self, k, v == 'true');
	end;
	courseplay:debug("id: "..tostring(self.id).."  base: readStream end", 5)
end

function courseplay:writeStream(streamId, connection)
	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write stream", 5)
		
	for _,variable in ipairs(courseplay.multiplayerSyncTable)do
		courseplay.streamDebugWrite(streamId, variable.dataFormat, courseplay:getVarValueFromString(self,variable.name),variable.name)
	end
	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write courseplay.multiplayerSyncTable end", 5)

	streamDebugWriteInt32(streamId, self.cp.generationPosition.fieldNum)
	
	local copyCourseFromDriverID;
	if self.cp.copyCourseFromDriver ~= nil then
		copyCourseFromDriverID = networkGetObjectId(self.cp.copyCourseFromDriver)
	end
	streamDebugWriteInt32(streamId, copyCourseFromDriverID)
	
	
	local savedCombineId;
	if self.cp.savedCombine ~= nil then
		savedCombineId = networkGetObjectId(self.cp.savedCombine)
	end
	streamDebugWriteInt32(streamId, savedCombineId)

	local activeCombineId;
	if self.cp.activeCombine ~= nil then
		activeCombineId = networkGetObjectId(self.cp.activeCombine)
	end
	streamDebugWriteInt32(streamId, activeCombineId)

	local current_trailer_id;
	if self.cp.currentTrailerToFill ~= nil then
		current_trailer_id = networkGetObjectId(self.cp.currentTrailerToFill)
	end
	streamDebugWriteInt32(streamId, current_trailer_id)

	local loadedCourses;
	if #self.cp.loadedCourses then
		loadedCourses = table.concat(self.cp.loadedCourses, ",")
	end
	streamDebugWriteString(streamId, loadedCourses) -- 60.
	streamDebugWriteInt32(streamId, self.cp.numCourses)
	
	--print(string.format("%s:write: numCourses: %s loadedCourses: %s",tostring(self.name),tostring(self.cp.numCourses),tostring(#self.cp.loadedCourses)))
	if self.cp.numCourses > #self.cp.loadedCourses then
		courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  sync temp course", 5)
		streamDebugWriteInt32(streamId, #(self.Waypoints))
		for w = 1, #(self.Waypoints) do
			--print("writing point "..tostring(w))
			streamDebugWriteFloat32(streamId, self.Waypoints[w].cx)
			streamDebugWriteFloat32(streamId, self.Waypoints[w].cz)
			streamDebugWriteFloat32(streamId, self.Waypoints[w].angle)
			streamDebugWriteBool(streamId, self.Waypoints[w].wait)
			streamDebugWriteBool(streamId, self.Waypoints[w].rev)
			streamDebugWriteBool(streamId, self.Waypoints[w].crossing)
			streamDebugWriteInt32(streamId, self.Waypoints[w].speed)
			streamDebugWriteBool(streamId, self.Waypoints[w].generated)
			streamDebugWriteBool(streamId, self.Waypoints[w].turnStart)
			streamDebugWriteBool(streamId, self.Waypoints[w].turnEnd)
			streamDebugWriteInt32(streamId, self.Waypoints[w].ridgeMarker)
		end	
	end

	local debugChannelsString = table.concat(table.map(courseplay.debugChannels, tostring), ",");
	streamDebugWriteString(streamId, debugChannelsString) 
	
	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write stream end", 5)
end


function courseplay:loadVehicleCPSettings(xmlFile, key, resetVehicles)
	if not resetVehicles and g_server ~= nil then
		-- COURSEPLAY
		local curKey = key .. '.courseplay';
		courseplay:setCpMode(self,  Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#aiMode'),			 self.cp.mode));
		self.cp.hud.openWithMouse = Utils.getNoNil(  getXMLBool(xmlFile, curKey .. '#openHudWithMouse'), true);
		self.cp.warningLightsMode  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#lights'),			 1);
		self.cp.waitTime 		  = Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#waitTime'),		 0);
 		self.cp.runCounter  	= Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#runCounter'),	 		 0);
 		self.cp.runNumber		 = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#runNumber'),			 11);
 		self.cp.runCounterBool	= Utils.getNoNil(  getXMLBool(xmlFile, curKey .. '#runCounterBool'),		 false);
 		self.cp.saveFuelOptionActive = Utils.getNoNil(  getXMLBool(xmlFile, curKey .. '#saveFuelOption'),			 true);
	
		local courses 			  = Utils.getNoNil(getXMLString(xmlFile, curKey .. '#courses'),			 '');
		self.cp.loadedCourses = Utils.splitString(",", courses);
		courseplay:reloadCourses(self, true);

		local visualWaypointsStartEnd = getXMLBool(xmlFile, curKey .. '#visualWaypointsStartEnd');
		local visualWaypointsAll = getXMLBool(xmlFile, curKey .. '#visualWaypointsAll');
		local visualWaypointsCrossing = getXMLBool(xmlFile, curKey .. '#visualWaypointsCrossing');
		if visualWaypointsStartEnd ~= nil then
			courseplay:toggleShowVisualWaypointsStartEnd(self, visualWaypointsStartEnd, false);
		end;
		if visualWaypointsAll ~= nil then
			courseplay:toggleShowVisualWaypointsAll(self, visualWaypointsAll, false);
		end;
		if visualWaypointsCrossing ~= nil then
			courseplay:toggleShowVisualWaypointsCrossing(self, visualWaypointsCrossing, false);
		end;
		courseplay.buttons:setActiveEnabled(self, 'visualWaypoints');
		courseplay.signs:setSignsVisibility(self);

		self.cp.siloSelectedFillType = FillUtil.fillTypeNameToInt[Utils.getNoNil(getXMLString(xmlFile, curKey .. '#siloSelectedFillType'), 'unknown')];
		if self.cp.siloSelectedFillType == nil then self.cp.siloSelectedFillType = FillUtil.FILLTYPE_UNKNOWN; end;

		-- SPEEDS
		curKey = key .. '.courseplay.speeds';
		self.cp.speeds.useRecordingSpeed = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#useRecordingSpeed'), true);
		-- use string so we can get both ints and proper floats without LUA's rounding errors
		-- if float speeds (old speed system) are loaded, the default speeds are used instead
		local reverse = floor(tonumber(getXMLString(xmlFile, curKey .. '#reverse') or '0'));
		local turn    = floor(tonumber(getXMLString(xmlFile, curKey .. '#turn')	   or '0'));
		local field   = floor(tonumber(getXMLString(xmlFile, curKey .. '#field')   or '0'));
		local street  = floor(tonumber(getXMLString(xmlFile, curKey .. '#max')	   or '0'));
		if reverse ~= 0	then self.cp.speeds.reverse	= reverse; end;
		if turn ~= 0	then self.cp.speeds.turn	= turn;   end;
		if field ~= 0	then self.cp.speeds.field	= field;  end;
		if street ~= 0	then self.cp.speeds.street	= street; end;

		-- MODE 2
		curKey = key .. '.courseplay.combi';
		self.cp.tipperOffset 		  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#tipperOffset'),			 0);
		self.cp.combineOffset 		  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#combineOffset'),		 0);
		self.cp.combineOffsetAutoMode = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#combineOffsetAutoMode'), true);
		self.cp.followAtFillLevel 	  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#fillFollow'),			 50);
		self.cp.driveOnAtFillLevel 	  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#fillDriveOn'),			 90);
		self.cp.turnDiameter		  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#turnDiameter'),			 self.cp.vehicleTurnRadius * 2);
		self.cp.realisticDriving 	  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#realisticDriving'),		 true);
		self.cp.allwaysSearchFuel 	  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#allwaysSearchFuel'),	 false);
		
		-- MODES 4 / 6
		curKey = key .. '.courseplay.fieldWork';
		self.cp.turnOnField  		  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#turnOnField'), 			 true);
		self.cp.oppositeTurnMode  	  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#oppositeTurnMode'), 		 false);
		self.cp.workWidth 			  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#workWidth'),			 3);
		self.cp.ridgeMarkersAutomatic = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#ridgeMarkersAutomatic'), true);
		self.cp.abortWork 			  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#abortWork'),			 0);
		self.cp.manualWorkWidth		  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#manualWorkWidth'),	     0);
		self.cp.ploughFieldEdge 	  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#ploughFieldEdge'),		 false);
		self.cp.lastValidTipDistance  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#lastValidTipDistance'),	     0);
		self.cp.generationPosition.hasSavedPosition = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#hasSavedPosition'),		 false);
		self.cp.generationPosition.x = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#savedPositionX'),	     0);
		self.cp.generationPosition.z = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#savedPositionZ'),	     0);
		self.cp.generationPosition.fieldNum = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#savedFieldNum'),			 0);
		self.cp.fertilizerOption	  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#fertilizerOption'),		 true);
		self.cp.convoyActive		 =	Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#convoyActive'),		 false);
		if self.cp.abortWork 		  == 0 then
			self.cp.abortWork = nil;
		end;
		if self.cp.manualWorkWidth ~= 0 then
			self.cp.workWidth = self.cp.manualWorkWidth
		else
			self.cp.manualWorkWidth = nil
		end;	
		if self.cp.lastValidTipDistance == 0 then
			self.cp.lastValidTipDistance = nil;
		end;
		
		self.cp.refillUntilPct = Utils.getNoNil(getXMLInt(xmlFile, curKey .. '#refillUntilPct'), 100);
		local offsetData = Utils.getNoNil(getXMLString(xmlFile, curKey .. '#offsetData'), '0;0;0;false;0;0;0'); -- 1=laneOffset, 2=toolOffsetX, 3=toolOffsetZ, 4=symmetricalLaneChange
		offsetData = Utils.splitString(';', offsetData);
		courseplay:changeLaneOffset(self, nil, tonumber(offsetData[1]));
		courseplay:changeToolOffsetX(self, nil, tonumber(offsetData[2]), true);
		courseplay:changeToolOffsetZ(self, nil, tonumber(offsetData[3]), true);
		courseplay:toggleSymmetricLaneChange(self, offsetData[4] == 'true');
		if not offsetData[5] then offsetData[5] = 0; end;
		courseplay:changeLoadUnloadOffsetX(self, nil, tonumber(offsetData[5]));
		if not offsetData[6] then offsetData[6] = 0; end;
		courseplay:changeLoadUnloadOffsetZ(self, nil, tonumber(offsetData[6]));
		if offsetData[7] ~= nil then self.cp.laneNumber = tonumber(offsetData[7]) end;

		-- SHOVEL POSITIONS
		curKey = key .. '.courseplay.shovel';
		local shovelRots = getXMLString(xmlFile, curKey .. '#rot');
		local shovelTrans = getXMLString(xmlFile, curKey .. '#trans');
		self.cp.shovelStopAndGo = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#shovelStopAndGo'), true);
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
					self.cp.hasShovelStatePositions[state] = self.cp.shovelStatePositions[state] ~= nil and self.cp.shovelStatePositions[state].rot ~= nil and self.cp.shovelStatePositions[state].trans ~= nil;
				end;
			end;
		end;
		courseplay:debug(tableShow(self.cp.shovelStatePositions, nameNum(self) .. ' shovelStatePositions (after loading)', 10), 10);
		courseplay.buttons:setActiveEnabled(self, 'shovel');

		-- COMBINE
		if self.cp.isCombine then
			curKey = key .. '.courseplay.combine';
			self.cp.driverPriorityUseFillLevel = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#driverPriorityUseFillLevel'), false);
			self.cp.stopWhenUnloading = Utils.getNoNil(getXMLBool(xmlFile, curKey .. '#stopWhenUnloading'), false);
		end;

		--overLoaderPipe
		curKey = key .. '.courseplay.overLoaderPipe';
		local rot =  getXMLFloat(xmlFile, curKey .. '#rot')
		local trans = getXMLFloat(xmlFile, curKey .. '#trans')
		local pipeIndex =  getXMLInt(xmlFile, curKey .. '#pipeIndex')
		local pipeWorkToolIndex = getXMLInt(xmlFile, curKey .. '#pipeWorkToolIndex')
		
		if rot and trans and pipeIndex and pipeWorkToolIndex then
			self.cp.pipePositions = {}
			self.cp.pipePositions.rot = {}
			self.cp.pipePositions.trans={}
			table.insert(self.cp.pipePositions.rot,rot)
			table.insert(self.cp.pipePositions.trans,trans)

			self.cp.pipeIndex =  pipeIndex
			self.cp.pipeWorkToolIndex = pipeWorkToolIndex
		end
	
		--mode10
		curKey = key .. '.courseplay.mode10';
		self.cp.mode10.leveling =  Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#leveling'), true);
		self.cp.mode10.searchCourseplayersOnly = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#CourseplayersOnly'), true);
		self.cp.mode10.searchRadius = Utils.getNoNil( getXMLInt(xmlFile, curKey .. '#searchRadius'), 50);
		self.cp.speeds.bunkerSilo = Utils.getNoNil( getXMLInt(xmlFile, curKey .. '#maxSiloSpeed'), 20);
		self.cp.mode10.shieldHeight = Utils.getNoNil( getXMLFloat(xmlFile, curKey .. '#shieldHeight'), 0.3);
		self.cp.mode10.automaticSpeed =  Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#automaticSpeed'), true);
		self.cp.mode10.automaticHeigth = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#automaticHeight'), true);
		self.cp.mode10.bladeOffset = Utils.getNoNil( getXMLFloat(xmlFile, curKey .. '#bladeOffset'), 0);
		self.cp.mode10.drivingThroughtLoading = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#drivingThroughtLoading'), false);
		
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
	--overloader pipe position

	local overLoaderPipe = '';
	
	if self.cp.pipeWorkToolIndex ~= nil then
		overLoaderPipe = string.format('<overLoaderPipe rot=%q trans=%q pipeIndex ="%i" pipeWorkToolIndex="%i" />',tostring(table.concat(self.cp.pipePositions.rot)),tostring(table.concat(self.cp.pipePositions.trans)),self.cp.pipeIndex,self.cp.pipeWorkToolIndex)
	end

	
	--Offset data
	local offsetData = string.format('%.1f;%.1f;%.1f;%s;%.1f;%.1f;%d', self.cp.laneOffset, self.cp.toolOffsetX, self.cp.toolOffsetZ, tostring(self.cp.symmetricLaneChange), self.cp.loadUnloadOffsetX, self.cp.loadUnloadOffsetZ, self.cp.laneNumber);

	local runCounter = self.cp.runCounter
	if self.cp.runReset == true then
		runCounter = 0;
	end;

	--NODES
	local cpOpen = string.format('<courseplay aiMode=%q courses=%q openHudWithMouse=%q lights=%q visualWaypointsStartEnd=%q visualWaypointsAll=%q visualWaypointsCrossing=%q waitTime=%q siloSelectedFillType=%q runNumber="%d" runCounter="%d" runCounterBool=%q saveFuelOption=%q >', tostring(self.cp.mode), tostring(table.concat(self.cp.loadedCourses, ",")), tostring(self.cp.hud.openWithMouse), tostring(self.cp.warningLightsMode), tostring(self.cp.visualWaypointsStartEnd), tostring(self.cp.visualWaypointsAll), tostring(self.cp.visualWaypointsCrossing), tostring(self.cp.waitTime), FillUtil.fillTypeIntToName[self.cp.siloSelectedFillType], self.cp.runNumber, runCounter, tostring(self.cp.runCounterBool), tostring(self.cp.saveFuelOptionActive));
	--local cpOpen = string.format('<courseplay aiMode=%q courses=%q openHudWithMouse=%q lights=%q visualWaypointsStartEnd=%q visualWaypointsAll=%q visualWaypointsCrossing=%q waitTime=%q >', tostring(self.cp.mode), tostring(table.concat(self.cp.loadedCourses, ",")), tostring(self.cp.hud.openWithMouse), tostring(self.cp.warningLightsMode), tostring(self.cp.visualWaypointsStartEnd), tostring(self.cp.visualWaypointsAll), tostring(self.cp.visualWaypointsCrossing), tostring(self.cp.waitTime));
	local speeds = string.format('<speeds useRecordingSpeed=%q reverse="%d" turn="%d" field="%d" max="%d" />', tostring(self.cp.speeds.useRecordingSpeed), self.cp.speeds.reverse, self.cp.speeds.turn, self.cp.speeds.field, self.cp.speeds.street);
	local combi = string.format('<combi tipperOffset="%.1f" combineOffset="%.1f" combineOffsetAutoMode=%q fillFollow="%d" fillDriveOn="%d" turnDiameter="%d" realisticDriving=%q allwaysSearchFuel=%q />', self.cp.tipperOffset, self.cp.combineOffset, tostring(self.cp.combineOffsetAutoMode), self.cp.followAtFillLevel, self.cp.driveOnAtFillLevel, self.cp.turnDiameter, tostring(self.cp.realisticDriving),tostring(self.cp.allwaysSearchFuel));
	local fieldWork = string.format('<fieldWork workWidth="%.1f" ridgeMarkersAutomatic=%q offsetData=%q abortWork="%d" refillUntilPct="%d" turnOnField=%q oppositeTurnMode=%q manualWorkWidth="%.1f" ploughFieldEdge=%q lastValidTipDistance="%.1f" hasSavedPosition=%q savedPositionX="%f" savedPositionZ="%f" savedFieldNum="%d" fertilizerOption=%q convoyActive=%q /> ', self.cp.workWidth, tostring(self.cp.ridgeMarkersAutomatic), offsetData, Utils.getNoNil(self.cp.abortWork, 0), self.cp.refillUntilPct, tostring(self.cp.turnOnField), tostring(self.cp.oppositeTurnMode),Utils.getNoNil(self.cp.manualWorkWidth,0),tostring(self.cp.ploughFieldEdge),Utils.getNoNil(self.cp.lastValidTipDistance,0),tostring(self.cp.generationPosition.hasSavedPosition),Utils.getNoNil(self.cp.generationPosition.x,0),Utils.getNoNil(self.cp.generationPosition.z,0),Utils.getNoNil(self.cp.generationPosition.fieldNum,0), tostring(self.cp.fertilizerOption),tostring(self.cp.convoyActive));
	local mode10 = string.format('<mode10 leveling=%q  CourseplayersOnly=%q searchRadius="%i" maxSiloSpeed="%i" shieldHeight="%.1f" automaticSpeed=%q  automaticHeight=%q bladeOffset="%.1f" drivingThroughtLoading=%q />', tostring(self.cp.mode10.leveling), tostring(self.cp.mode10.searchCourseplayersOnly), self.cp.mode10.searchRadius, self.cp.speeds.bunkerSilo, self.cp.mode10.shieldHeight, tostring(self.cp.mode10.automaticSpeed),tostring(self.cp.mode10.automaticHeigth), self.cp.mode10.bladeOffset, tostring(self.cp.mode10.drivingThroughtLoading));
	local shovels, combine = '', '';
	if shovelRotsAttrNodes or shovelTransAttrNodes then
		shovels = string.format('<shovel rot=%q trans=%q shovelStopAndGo=%q />', shovelRotsAttrNodes, shovelTransAttrNodes,tostring(self.cp.shovelStopAndGo));
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
	nodes = nodes .. nodeIdent .. indent .. mode10 .. '\n';
	if shovelRotsAttrNodes or shovelTransAttrNodes then
		nodes = nodes .. nodeIdent .. indent .. shovels .. '\n';
	end;
	if self.cp.isCombine then
		nodes = nodes .. nodeIdent .. indent .. combine .. '\n';
	end;
	if self.cp.pipeWorkToolIndex ~= nil then
		nodes = nodes .. nodeIdent .. indent .. overLoaderPipe .. '\n';
	end
	nodes = nodes .. nodeIdent .. cpClose;

	courseplay:debug(nameNum(self) .. ": getSaveAttributesAndNodes(): nodes\n" .. nodes, 10)

	return attributes, nodes;
end


-- This is to prevent the selfPropelledPotatoHarvester from turning off while turning
function courseplay.setIsTurnedOn(self, originalFunction, isTurnedOn, noEventSend)
	if self.typeName and self.typeName == "selfPropelledPotatoHarvester" then
		if self.getIsCourseplayDriving and self:getIsCourseplayDriving() and self.cp.isTurning and not isTurnedOn then
			isTurnedOn = true;
		end;
	end;

	originalFunction(self, isTurnedOn, noEventSend);
end;
TurnOnVehicle.setIsTurnedOn = Utils.overwrittenFunction(TurnOnVehicle.setIsTurnedOn, courseplay.setIsTurnedOn);
-- do not remove this comment
-- vim: set noexpandtab:
