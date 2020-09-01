local floor = math.floor;

function courseplay.prerequisitesPresent(specializations)
	return true;
end

function courseplay:onLoad(savegame)
	local xmlFile = self.xmlFile;
	self.setCourseplayFunc = courseplay.setCourseplayFunc;
	self.getIsCourseplayDriving = courseplay.getIsCourseplayDriving;
	self.setIsCourseplayDriving = courseplay.setIsCourseplayDriving;
	-- TODO: this is the worst programming practice ever. Defined as courseplay:setCpVar() but then self refers to the
	-- vehicle, this is the ugliest hack I've ever seen.
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
	end
	self.cp.speedDebugLine = "no speed info"

	-- GIANT DLC
	self.cp.haveInversedRidgeMarkerState = nil; --bool

	--turn maneuver
	self.cp.oppositeTurnMode = false;
	self.cp.waitForTurnTime = 0.00   --float
	self.cp.aiTurnNoBackward = false --bool
	self.cp.canBeReversed = nil --bool
	self.cp.backMarkerOffset = nil --float
	self.cp.aiFrontMarker = nil --float
	self.cp.noStopOnEdge = false --bool
	self.cp.noStopOnTurn = false --bool
	self.cp.noWorkArea = false -- bool

	self.cp.combineOffsetAutoMode = true
	self.cp.isDriving = false;
	self.cp.runOnceStartCourse = false;
	self.cp.stopAtEndMode1 = false;
	self.cp.calculatedCourseToCombine = false

	self.cp.waypointIndex = 1;
	self.cp.previousWaypointIndex = 1;
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
	self.cp.unloadPoints = {};
	self.cp.numUnloadPoints = 0;
	self.cp.waitTime = 0;
	self.cp.crossingPoints = {};
	self.cp.numCrossingPoints = 0;


	self.cp.hasHazardLights = self.spec_lights.turnLightState ~= nil and self.setTurnLightState ~= nil;


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
	self.cp.mode = courseplay.MODE_TRANSPORT;
	--courseplay:setNextPrevModeVars(self);
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
	self.cp.canSwitchMode = false;
	self.cp.tipperLoadMode = 0;
	self.cp.easyFillTypeList = {};
	self.cp.siloSelectedEasyFillType = 1;
	self.cp.slippingStage = 0;
	self.cp.isTipping = false;
	self.cp.hasPlow = false;
	self.cp.rotateablePlow = nil;
	self.cp.saveFuel = false;
	self.cp.hasAugerWagon = false;
	self.cp.hasSugarCaneAugerWagon = false
	self.cp.hasSugarCaneTrailer = false
	self.cp.generationPosition = {}
	self.cp.generationPosition.hasSavedPosition = false
	
	self.cp.convoyActive = false
	self.cp.convoy= {
					  distance = 0,
					  number = 0,
					  members = 0,
					  minDistance = 100,
					  maxDistance = 300
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
	self.cp.shovelPositionFromKey = false;
	
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

	self.cp.numCourses = 1;
	self.cp.numWaypoints = 0;
	self.cp.currentCourseName = nil;
	self.cp.currentCourseId = 0;
	self.cp.lastMergedWP = 0;

	self.cp.loadedCourses = {}
	self.cp.course = {} -- as discussed with Peter, this could be the container for all waypoint stuff in one table
	
	-- forced waypoints
	self.cp.curTarget = {};
	self.cp.curTargetMode7 = {};
	self.cp.nextTargets = {};
	self.cp.turnTargets = {};
	self.cp.curTurnIndex = 1;

	-- alignment course data
	self.cp.alignment = { enabled = true }

	-- speed limits
	self.cp.speeds = {
		reverse =  6;
		turn =   10;
		field =  24;
		street = self:getCruiseControlMaxSpeed() or 50;
		crawl = 3;
		discharge = 8;
		bunkerSilo = 20;
		approach = 10;
		
		minReverse = 3;
		minTurn = 3;
		minField = 3;
		minStreet = 3;
		max = self:getCruiseControlMaxSpeed() or 60;
	};

	self.cp.tooIsDirty = false
	self.cp.orgRpm = nil;

	-- data basis for the Course list
	self.cp.reloadCourseItems = true
	self.cp.sorted = {item={}, info={}}	
	self.cp.folder_settings = {}
	courseplay.settings.update_folders(self)

	-- DIRECTION NODE SETUP
	local DirectionNode;
	if self.getAIVehicleDirectionNode ~= nil then -- Check if function exist before trying to use it
		if self.cp.componentNumAsDirectionNode then
			-- If we have specified a component node as the derection node in the special tools section, then use it.
			DirectionNode = self.components[self.cp.componentNumAsDirectionNode].node;
		else
			DirectionNode = self:getAIVehicleDirectionNode();
		end;
	else
		-- TODO: (Claus) Check Wheel Loaders Direction node a bit later.
		--if courseplay:isWheelloader(self)then
		--	if self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin then
		--		local nodeIndex = Utils.getNoNil(self.cp.componentNumAsDirectionNode, 2)
		--		if self.components[nodeIndex] ~= nil then
		--			DirectionNode = self.components[nodeIndex].node;
		--		end
		--	end;
		--end
	end;

	-- If we cant get any valid direction node, then use the rootNode
	if DirectionNode == nil then
		DirectionNode = self.rootNode;
	end

	local directionNodeOffset, isTruck = courseplay:getVehicleDirectionNodeOffset(self, DirectionNode);
	if directionNodeOffset ~= 0 then
		self.cp.oldDirectionNode = DirectionNode;  -- Only used for debugging.
		DirectionNode = courseplay:createNewLinkedNode(self, "realDirectionNode", DirectionNode);
		setTranslation(DirectionNode, 0, 0, directionNodeOffset);
	end;
	self.cp.directionNode = DirectionNode;

	-- REVERSE DRIVING SETUP
	if self.cp.hasSpecializationReverseDriving then
		self.cp.reverseDrivingDirectionNode = courseplay:createNewLinkedNode(self, "realReverseDrivingDirectionNode", self.cp.directionNode);
		setRotation(self.cp.reverseDrivingDirectionNode, 0, math.rad(180), 0);
	end;

	-- TRIGGERS
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	self.findSpecialTriggerCallback = courseplay.findSpecialTriggerCallback;
	self.findFuelTriggerCallback = courseplay.findFuelTriggerCallback;
	self.cp.hasRunRaycastThisLoop = {};
	-- self.findTrafficCollisionCallback = courseplay.findTrafficCollisionCallback;		-- ??? not used anywhere
	self.findBlockingObjectCallbackLeft = courseplay.findBlockingObjectCallbackLeft;
	self.findBlockingObjectCallbackRight = courseplay.findBlockingObjectCallbackRight;
	self.findVehicleHeights = courseplay.findVehicleHeights; 
	
	self.cp.fillTriggers = {}
	
	if self.maxRotation then
		self.cp.steeringAngle = math.deg(self.maxRotation);
	else
		self.cp.steeringAngle = 30;
	end
	courseplay.debugVehicle( 7, self, 'steering angle is %.1f', self.cp.steeringAngle)
	if isTruck then
		self.cp.revSteeringAngle = self.cp.steeringAngle * 0.25;
	end;
	if self.cp.steeringAngleCorrection then
		self.cp.steeringAngle = Utils.getNoNil(self.cp.steeringAngleCorrection, self.cp.steeringAngle);
	elseif self.cp.steeringAngleMultiplier then
		self.cp.steeringAngle = self.cp.steeringAngle * self.cp.steeringAngleMultiplier;
	end;

	-- traffic collision
	self.cpOnTrafficCollisionTrigger = courseplay.cpOnTrafficCollisionTrigger;
	-- self.cp.tempCollis = {}								-- ??? not used anywhere
	self.cpTrafficCollisionIgnoreList = {};
	self.cp.TrafficBrake = false
	self.cp.inTraffic = false

	if self.trafficCollisionIgnoreList == nil then
		self.trafficCollisionIgnoreList = {}
	end
	-- if self.numCollidingVehicles == nil then				-- ??? not used anywhere
		-- self.numCollidingVehicles = {};
	-- end

	self.cp.collidingVehicleId = nil		-- on load game assume no colliding vehicle is detected
	self.cp.numTrafficCollisionTriggers = 4;		-- single point of definition of the number of traffic collision boxes in front of a vehicle
	self.cp.trafficCollisionTriggers = {};
	self.cp.trafficCollisionTriggers[1] = nil;		-- LegacyCollisionTriggers not created
	self.cp.trafficCollisionTriggerToTriggerIndex = {};
	self.cp.collidingObjects = {
		all = {};
	};
	-- self.cp.numCollidingObjects = {							-- ??? not used anywhere
		-- all = 0;
	-- };

	--aiTrafficCollisionTrigger
	self.aiTrafficCollisionTrigger = nil

	local ret_findAiCollisionTrigger = false
	ret_findAiCollisionTrigger = courseplay:findAiCollisionTrigger(self)

	-- create LegacyCollisionTriggers on load game ? -> vehicles not running CP are getting the collision snake

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

	-- combines
	self.cp.reachableCombines = {};
	self.cp.activeCombine = nil;

	self.cp.offset = nil --self = combine [flt]
	self.cp.combineOffset = 0.0
	self.cp.tipperOffset = 0.0

	self.cp.forcedSide = nil
	
	self.cp.allowFollowing = false
	
	self.cp.vehicleTurnRadius = courseplay:getVehicleTurnRadius(self);
	self.cp.turnDiameter = self.cp.vehicleTurnRadius * 2;
	self.cp.turnDiameterAuto = self.cp.vehicleTurnRadius * 2;
	self.cp.turnDiameterAutoMode = true;


	--Offset
	self.cp.laneOffset = 0;
	self.cp.toolOffsetX = 0;
	self.cp.toolOffsetZ = 0;
	self.cp.totalOffsetX = 0;
	self.cp.loadUnloadOffsetX = 0;
	self.cp.loadUnloadOffsetZ = 0;
	self.cp.skipOffsetX = false;

	self.cp.workWidth = 3
	self.cp.headlandHeight = 0;

	self.cp.searchCombineAutomatically = true;
	self.cp.savedCombine = nil
	self.cp.selectedCombineNumber = 0

	--Copy course
	self.cp.hasFoundCopyDriver = false;
	self.cp.copyCourseFromDriver = nil;
	self.cp.selectedDriverNumber = 0;

	--MultiTools
	self.cp.multiTools = 1;
	self.cp.laneNumber = 0;

	--Course generation	
	self.cp.startingCorner = 4;
	self.cp.hasStartingCorner = false;
	self.cp.startingDirection = 0;
	self.cp.rowDirectionDeg = 0
	self.cp.rowDirectionMode = courseGenerator.ROW_DIRECTION_AUTOMATIC
	self.cp.hasStartingDirection = false;
	self.cp.isNewCourseGenSelected = function()
		return self.cp.hasStartingCorner and self.cp.startingCorner > courseGenerator.STARTING_LOCATION_SE_LEGACY
	end
	self.cp.returnToFirstPoint = false;
	self.cp.hasGeneratedCourse = false;
	self.cp.hasValidCourseGenerationData = false;
	-- TODO: add all old course gen settings to a SettingsContainer
	self.cp.oldCourseGeneratorSettings = {
		startingLocation = self.cp.startingCorner,
		manualStartingLocationWorldPos = nil,
		islandBypassMode = Island.BYPASS_MODE_NONE,
		nRowsToSkip = 0,
		centerMode = courseGenerator.CENTER_MODE_UP_DOWN
	}
	self.cp.headland = {
		-- with the old, manual direction selection course generator
		manuDirMaxNumLanes = 6;
		-- with the new, auto direction selection course generator
		autoDirMaxNumLanes = 50;
		maxNumLanes = 20;
		numLanes = 0;
		mode = courseGenerator.HEADLAND_MODE_NORMAL;
		userDirClockwise = true;
		orderBefore = true;
		-- we abuse the numLanes to switch to narrow field mode,
		-- negative headland lanes mean we are in narrow field mode
		-- TODO: this is an ugly hack to make life easy for the UI but needs
		-- to be refactored
		minNumLanes = -1;
		-- another ugly hack: the narrow mode is like the normal headland mode
		-- for most uses (like the turn system). The next two functions are
		-- to be used instead of the numLanes directly to hide the narrow mode
		getNumLanes = function()
			if self.cp.headland.mode == courseGenerator.HEADLAND_MODE_NARROW_FIELD then
				return math.abs( self.cp.headland.numLanes )
			else
				return self.cp.headland.numLanes
			end
		end;
		exists = function()
			return self.cp.headland.getNumLanes() > 0
		end;
		getMinNumLanes = function()
			return self.cp.isNewCourseGenSelected() and self.cp.headland.minNumLanes or 0
		end,
		getMaxNumLanes = function()
			return self.cp.isNewCourseGenSelected() and self.cp.headland.autoDirMaxNumLanes or self.cp.headland.manuDirMaxNumLanes
		end,
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
	if g_currentMission.hud.ingameMap and g_currentMission.hud.ingameMap.mapOverlay and g_currentMission.hud.ingameMap.mapOverlay.filename then
		self.cp.course2dPdaMapOverlay = Overlay:new(g_currentMission.hud.ingameMap.mapOverlay.filename, 0, 0, 1, 1);
		self.cp.course2dPdaMapOverlay:setColor(1, 1, 1, CpManager.course2dPdaMapOpacity);
	end;

	-- HUD
	courseplay.hud:setupVehicleHud(self);

	courseplay:validateCanSwitchMode(self);

	-- TODO: all vehicle specific settings (HUD or advanced settings dialog) should be moved here
	---@type SettingsContainer
	self.cp.settings = SettingsContainer("settings")
	self.cp.settings:addSetting(SearchCombineOnFieldSetting, self)
	self.cp.settings:addSetting(SelectedCombineToUnloadSetting)
	self.cp.settings:addSetting(ReturnToFirstPointSetting, self)
	self.cp.settings:addSetting(UseAITurnsSetting, self)
	self.cp.settings:addSetting(UsePathfindingInTurnsSetting, self)
	self.cp.settings:addSetting(AllowReverseForPathfindingInTurnsSetting, self)
	self.cp.settings:addSetting(ImplementRaiseTimeSetting, self)
	self.cp.settings:addSetting(ImplementLowerTimeSetting, self)
	self.cp.settings:addSetting(AutoDriveModeSetting, self)
	self.cp.settings:addSetting(SelfUnloadSetting, self)
	self.cp.settings:addSetting(StartingPointSetting, self)
	self.cp.settings:addSetting(SymmetricLaneChangeSetting, self)
	self.cp.settings:addSetting(PipeAlwaysUnfoldSetting, self)
	self.cp.settings:addSetting(RidgeMarkersAutomatic, self)
	self.cp.settings:addSetting(StopForUnloadSetting, self)
	self.cp.settings:addSetting(StrawOnHeadland, self)
	self.cp.settings:addSetting(AllowUnloadOnFirstHeadlandSetting, self)
	self.cp.settings:addSetting(SowingMachineFertilizerEnabled, self)
	self.cp.settings:addSetting(EnableOpenHudWithMouseVehicle, self)
	self.cp.settings:addSetting(EnableVisualWaypointsTemporary, self)

	self.cp.settings:addSetting(StopAtEndSetting, self)
	self.cp.settings:addSetting(AutomaticCoverHandlingSetting, self)
	self.cp.settings:addSetting(AutomaticUnloadingOnFieldSetting, self)
	self.cp.settings:addSetting(DriverPriorityUseFillLevelSetting, self)
	self.cp.settings:addSetting(UseRecordingSpeedSetting, self)
	self.cp.settings:addSetting(WarningLightsModeSetting, self)
	self.cp.settings:addSetting(ShowMapHotspotSetting, self)
	self.cp.settings:addSetting(SaveFuelOptionSetting, self)
	self.cp.settings:addSetting(AlwaysSearchFuelSetting, self)
	self.cp.settings:addSetting(RealisticDrivingSetting, self)
	self.cp.settings:addSetting(DriveUnloadNowSetting, self)
	self.cp.settings:addSetting(CombineWantsCourseplayerSetting, self)
	self.cp.settings:addSetting(TurnOnFieldSetting, self)
	self.cp.settings:addSetting(TurnStageSetting, self)
	self.cp.settings:addSetting(GrainTransportDriver_SiloSelectedFillTypeSetting, self)
	self.cp.settings:addSetting(FillableFieldWorkDriver_SiloSelectedFillTypeSetting, self)
	self.cp.settings:addSetting(FieldSupplyDriver_SiloSelectedFillTypeSetting, self)
	self.cp.settings:addSetting(DriveOnAtFillLevelSetting, self)
	self.cp.settings:addSetting(RefillUntilPctSetting, self)
	self.cp.settings:addSetting(FollowAtFillLevelSetting,self)
	self.cp.settings:addSetting(ForcedToStopSetting,self)
	self.cp.settings:addSetting(SeperateFillTypeLoadingSetting,self)
	self.cp.settings:addSetting(ReverseSpeedSetting, self)
	self.cp.settings:addSetting(TurnSpeedSetting, self)
	self.cp.settings:addSetting(FieldSpeedSettting,self)
	self.cp.settings:addSetting(StreetSpeedSetting,self)
	self.cp.settings:addSetting(BunkerSpeedSetting,self)
	self.cp.settings:addSetting(ShowVisualWaypointsSetting,self)
	self.cp.settings:addSetting(ShowVisualWaypointsCrossPointSetting,self)
	---@type SettingsContainer
	self.cp.courseGeneratorSettings = SettingsContainer("courseGeneratorSettings")
	self.cp.courseGeneratorSettings:addSetting(CenterModeSetting, self)
	self.cp.courseGeneratorSettings:addSetting(NumberOfRowsPerLandSetting, self)
	self.cp.courseGeneratorSettings:addSetting(HeadlandOverlapPercent, self)
	
	courseplay.signs:updateWaypointSigns(self);
	
	courseplay:setAIDriver(self, self.cp.mode)
end;

function courseplay:onPostLoad(savegame)
	if savegame ~= nil and savegame.key ~= nil and not savegame.resetVehicles then
		courseplay.loadVehicleCPSettings(self, savegame.xmlFile, savegame.key, savegame.resetVehicles)
	end
end;

function courseplay:onLeaveVehicle()
	if self.cp.mouseCursorActive then
		courseplay:setMouseCursor(self, false);
    courseEditor:reset()
	end

	--hide visual i3D waypoint signs when not in vehicle
	courseplay.signs:setSignsVisibility(self, true);
end

function courseplay:onEnterVehicle()
  courseEditor:reset()
	if self.cp.mouseCursorActive then
		courseplay:setMouseCursor(self, true);
	end;

	if self:getIsCourseplayDriving() and self.steeringEnabled then
		self.steeringEnabled = false;
	end;

	--show visual i3D waypoint signs only when in vehicle
	courseplay.signs:setSignsVisibility(self);
end

function courseplay:onDraw()
  courseEditor:draw(self, self.cp.directionNode)

	courseplay:showAIMarkers(self)
	courseplay:showTemporaryMarkers(self)

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
			if self.cp.settings.useRecordingSpeed:is(true) then
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
	if self.cp.isCombine and courseplay.debugChannels[4] then
		--renderText(0.2,0.165,0.02,string.format("time till full: %s s  ", (self:getFillUnitCapacity(self.spec_combine.fillUnitIndex) - self:getFillUnitFillLevel(self.spec_combine.fillUnitIndex))/self.cp.fillLitersPerSecond))
		--renderText(0.2,0.135,0.02,"self.cp.fillLitersPerSecond: "..tostring(self.cp.fillLitersPerSecond))
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
		cpDebug:drawLine(sx, y, sz, 1, 0, 0, wx, y, wz);
		cpDebug:drawLine(wx, y, wz, 1, 0, 0, hx, y, hz);
		cpDebug:drawLine(fillUnit.hx, y, fillUnit.hz, 1, 0, 0, sx, y, sz);
		--drawDebugLine(fillUnit.cx, y, fillUnit.cz, 1, 0, 1, bx, y, bz, 1, 0, 0); -- Have gradiant color. new draw line cant do that
		cpDebug:drawLine(fillUnit.cx, y, fillUnit.cz, 1, 0, 1, bx, y, bz);
		cpDebug:drawPoint(fillUnit.cx, y, fillUnit.cz, 1, 1 , 1);
		if self.cp.mode == 9 then
			renderText(0.2,0.225,0.02,"unit.fillLevel: "..tostring(fillUnit.fillLevel))
			if self.cp.mode9SavedLastFillLevel ~= nil then
				renderText(0.2,0.195,0.02,"SavedLastFillLevel: "..tostring(self.cp.mode9SavedLastFillLevel))
				renderText(0.2,0.165,0.02,"triesTheSameFillUnit: "..tostring(self.cp.mode9triesTheSameFillUnit))
			end
		elseif self.cp.mode == 10 then

			--renderText(0.2,0.395,0.02,"numStoppedCPs: "..tostring(#self.cp.mode10.stoppedCourseplayers ))
			--renderText(0.2,0.365,0.02,"shieldHeight: "..tostring(self.cp.mode10.shieldHeight))
			--renderText(0.2,0.335,0.02,"lowestAlpha: "..tostring(self.cp.mode10.lowestAlpha))
			--renderText(0.2,0.305,0.02,"speeds.bunkerSilo: "..tostring(self.cp.speeds.bunkerSilo))
			--renderText(0.2,0.275,0.02,"jumpsPerRun: "..tostring(self.cp.mode10.jumpsPerRun))
			--renderText(0.2,0.245,0.02,"bladeOffset: "..tostring(self.cp.mode10.bladeOffset))
			--renderText(0.2,0.215,0.02,"diffY: "..tostring(self.cp.diffY ))
			--renderText(0.2,0.195,0.02,"tractorHeight: "..tostring(self.cp.tractorHeight ))
			--renderText(0.2,0.165,0.02,"shouldBHeight: "..tostring(self.cp.shouldBHeight ))
			--renderText(0.2,0.135,0.02,"targetHeigth: "..tostring(self.cp.mode10.targetHeigth))
			--renderText(0.2,0.105,0.02,"height: "..tostring(self.cp.currentHeigth))
		end
	end
	
	if courseplay.debugChannels[10] and self.cp.tempMOde9PointX ~= nil then
		local x,y,z = getWorldTranslation(self.cp.directionNode)
		cpDebug:drawLine(self.cp.tempMOde9PointX2,self.cp.tempMOde9PointY2+2,self.cp.tempMOde9PointZ2, 1, 0, 0, self.cp.tempMOde9PointX,self.cp.tempMOde9PointY+2,self.cp.tempMOde9PointZ);
		local bunker = self.cp.mode9TargetSilo
		if bunker ~= nil then
			local sx,sz = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local wx,wz = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local hx,hz = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			cpDebug:drawLine(sx,y+2,sz, 0, 0, 1, wx,y+2,wz);
			--drawDebugLine(sx,y+2,sz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
			--drawDebugLine(wx,y+2,wz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
			cpDebug:drawLine(sx,y+2,sz, 0, 0, 1, hx,y+2,hz);
			cpDebug:drawLine(wx,y+2,wz, 0, 0, 1, hx,y+2,hz);
		end
	end
	
	
	--DEBUG SHOW DIRECTIONNODE
	if courseplay.debugChannels[12] then
		-- For debugging when setting the directionNodeZOffset. (Visual points shown for old node)
		if self.cp.oldDirectionNode then
			local ox,oy,oz = getWorldTranslation(self.cp.oldDirectionNode);
			cpDebug:drawPoint(ox, oy+4, oz, 0.9098, 0.6902 , 0.2706);
		end;
		if self.cp.driver then
			self.cp.driver:onDraw()
		end
		local nx,ny,nz = getWorldTranslation(self.cp.directionNode);
		cpDebug:drawPoint(nx, ny+4, nz, 0.6196, 0.3490 , 0);
	end;


	-- HELP BUTTON TEXTS
	--renderText(0.2, 0.5, 0.02, string.format("InputBinding.wrapMousePositionEnabled(%s),g_currentMission.isPlayerFrozen(%s) self:getIsActive(%s) and Enterable.getIsEntered(self)(%s) then"
	--,tostring(InputBinding.wrapMousePositionEnabled),tostring(g_currentMission.isPlayerFrozen),tostring(self:getIsActive()),tostring(Enterable.getIsEntered(self))));
	--print(string.format("if self:getIsActive(%s) and self.isEntered(%s) then",tostring(self:getIsActive()),tostring(Enterable.getIsEntered(self))))
		
										
	if self:getIsActive() and self:getIsEntered() then
		local modifierPressed = courseplay.inputModifierIsPressed;
		--missing hud.openWithMouse ?
		if self.cp.canDrive and not modifierPressed then
			g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_FUNCTIONS'), InputBinding.COURSEPLAY_MODIFIER, nil, GS_PRIO_HIGH);
		end;

		--[[if self.cp.hud.show then
			if self.cp.mouseCursorActive then
				g_currentMission:addHelpTextFunction(CpManager.drawMouseButtonHelp, self, CpManager.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_HIDE'));
			else
				g_currentMission:addHelpTextFunction(CpManager.drawMouseButtonHelp, self, CpManager.hudHelpMouseLineHeight, courseplay:loc('COURSEPLAY_MOUSEARROW_SHOW'));
			end;
		end;]]
		if modifierPressed then
			if not self.cp.hud.show then
				--g_gui.inputManager:setActionEventTextVisibility(courseplay.inputActionEventIds['COURSEPLAY_HUD'], true)
				g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_HUD_OPEN'), InputBinding.COURSEPLAY_HUD, nil, GS_PRIO_HIGH);
			else
				g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_HUD_CLOSE'), InputBinding.COURSEPLAY_HUD, nil, GS_PRIO_HIGH);
			end;
		end;

		if modifierPressed then
			if self.cp.canDrive then
				if isDriving then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_STOP_COURSE'), InputBinding.COURSEPLAY_START_STOP, nil, GS_PRIO_HIGH);
					--g_gui.inputManager:setActionEventTextVisibility(courseplay.inputActionEventIds['COURSEPLAY_START_STOP'], true)
					if self.cp.HUD1wait or (self.cp.driver and self.cp.driver:isWaiting()) then
						g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_CONTINUE'), InputBinding.COURSEPLAY_CANCELWAIT, nil, GS_PRIO_HIGH);
					end;
					if self.cp.HUD1noWaitforFill then
						g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_DRIVE_NOW'), InputBinding.COURSEPLAY_DRIVENOW, nil, GS_PRIO_HIGH);
					end;
				else
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_START_COURSE'), InputBinding.COURSEPLAY_START_STOP, nil, GS_PRIO_HIGH);
					--g_gui.inputManager:setActionEventTextVisibility(courseplay.inputActionEventIds['COURSEPLAY_START_STOP'], true)
					if self.cp.hasShovelStatePositions[2] and InputBinding.COURSEPLAY_SHOVELPOSITION_LOAD ~= nil then
						g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_SHOVELPOSITION_LOAD'). InputBinding.COURSEPLAY_SHOVELPOSITION_LOAD, nil, GS_PRIO_HIGH);
					end;
					if self.cp.hasShovelStatePositions[3] and InputBinding.COURSEPLAY_SHOVELPOSITION_TRANSPORT ~= nil then
						g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_SHOVELPOSITION_TRANSPORT'). InputBinding.COURSEPLAY_SHOVELPOSITION_TRANSPORT, nil, GS_PRIO_HIGH);
					end;
					if self.cp.hasShovelStatePositions[4] and InputBinding.COURSEPLAY_SHOVELPOSITION_PREUNLOAD ~= nil then
						g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_SHOVELPOSITION_PREUNLOAD'). InputBinding.COURSEPLAY_SHOVELPOSITION_PREUNLOAD, nil, GS_PRIO_HIGH);
					end;
					if self.cp.hasShovelStatePositions[5] and InputBinding.COURSEPLAY_SHOVELPOSITION_UNLOAD ~= nil then
						g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_SHOVELPOSITION_UNLOAD'). InputBinding.COURSEPLAY_SHOVELPOSITION_UNLOAD, nil, GS_PRIO_HIGH);
					end;
					--end;
				end;
			else
				if not self.cp.isRecording and not self.cp.recordingIsPaused and self.cp.numWaypoints == 0 then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_RECORDING_START'), InputBinding.COURSEPLAY_START_STOP, nil, GS_PRIO_HIGH);
				elseif self.cp.isRecording and not self.cp.recordingIsPaused and not self.cp.isRecordingTurnManeuver then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_RECORDING_STOP'), InputBinding.COURSEPLAY_START_STOP, nil, GS_PRIO_HIGH);
				end;
			end;

			if self.cp.canSwitchMode then
				if self.cp.nextMode then
					g_currentMission:addHelpButtonText(courseplay:loc('input_COURSEPLAY_NEXTMODE'), InputBinding.COURSEPLAY_NEXTMODE, nil, GS_PRIO_HIGH);
				end;
				if self.cp.prevMode then
					g_currentMission:addHelpButtonText(courseplay:loc('input_COURSEPLAY_PREVMODE'), InputBinding.COURSEPLAY_PREVMODE, nil, GS_PRIO_HIGH);
				end;
			end;
		end;
	end;

	if self:getIsActive() then
		if self.cp.hud.show then
			courseplay.hud:setContent(self);
			courseplay.hud:renderHud(self);
			courseplay.hud:renderHudBottomInfo(self);
			if self.cp.distanceCheck and (isDriving or (not self.cp.canDrive and not self.cp.isRecording and not self.cp.recordingIsPaused)) then -- turn off findFirstWaypoint when driving or no course loaded
				courseplay:toggleFindFirstWaypoint(self);
			end;

			if self.cp.mouseCursorActive then
				g_inputBinding:setShowMouseCursor(self.cp.mouseCursorActive);
			end;
		elseif courseplay.globalSettings.showMiniHud:is(true) then
			courseplay.hud:setContent(self);
			courseplay.hud:renderHudBottomInfo(self);
		end;
		
		if self.cp.distanceCheck and self.cp.numWaypoints > 1 then 
			courseplay:distanceCheck(self);
		elseif self.cp.infoText ~= nil and StringUtil.startsWith(self.cp.infoText, 'COURSEPLAY_DISTANCE') then  
			self.cp.infoText = nil
			self.cp.infoTextNilSent = false
		end;
		
		if self:getIsEntered() and self.cp.toolTip ~= nil then
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


	if vehicle.cp.directionNode and vehicle.cp.backMarkerOffset and vehicle.cp.aiFrontMarker then
		local p1x, p1y, p1z = localToWorld(vehicle.cp.directionNode, left,  1.6, vehicle.cp.backMarkerOffset - offsZ);
		local p2x, p2y, p2z = localToWorld(vehicle.cp.directionNode, right, 1.6, vehicle.cp.backMarkerOffset - offsZ);
		local p3x, p3y, p3z = localToWorld(vehicle.cp.directionNode, right, 1.6, vehicle.cp.aiFrontMarker - offsZ);
		local p4x, p4y, p4z = localToWorld(vehicle.cp.directionNode, left,  1.6, vehicle.cp.aiFrontMarker - offsZ);

		cpDebug:drawPoint(p1x, p1y, p1z, 1, 1, 0);
		cpDebug:drawPoint(p2x, p2y, p2z, 1, 1, 0);
		cpDebug:drawPoint(p3x, p3y, p3z, 1, 1, 0);
		cpDebug:drawPoint(p4x, p4y, p4z, 1, 1, 0);

		cpDebug:drawLine(p1x, p1y, p1z, 1, 0, 0, p2x, p2y, p2z);
		cpDebug:drawLine(p2x, p2y, p2z, 1, 0, 0, p3x, p3y, p3z);
		cpDebug:drawLine(p3x, p3y, p3z, 1, 0, 0, p4x, p4y, p4z);
		cpDebug:drawLine(p4x, p4y, p4z, 1, 0, 0, p1x, p1y, p1z);
	else
		local lX, lY, lZ = localToWorld(vehicle.rootNode, left,  1.6, -6 - offsZ);
		local rX, rY, rZ = localToWorld(vehicle.rootNode, right, 1.6, -6 - offsZ);

		cpDebug:drawPoint(lX, lY, lZ, 1, 1, 0);
		cpDebug:drawPoint(rX, rY, rZ, 1, 1, 0);

		cpDebug:drawLine(lX, lY, lZ, 1, 0, 0, rX, rY, rZ);
	end;
end;

function courseplay:drawWaypointsLines(vehicle)
	if vehicle ~= g_currentMission.controlledVehicle then return; end;

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
		cpDebug:drawPoint(wp.cx, wp.cy + height, wp.cz, r,g,b);

		if i < vehicle.cp.numWaypoints then
			if i + 1 == vehicle.cp.waypointIndex then
				--drawDebugLine(wp.cx, wp.cy + height, wp.cz, 0.9, 0, 0.6, np.cx, np.cy + height, np.cz, 1, 0.4, 0.05);
				cpDebug:drawLine(wp.cx, wp.cy + height, wp.cz, 0.9, 0, 0.6, np.cx, np.cy + height, np.cz);
			else
				cpDebug:drawLine(wp.cx, wp.cy + height, wp.cz, 0, 1, 1, np.cx, np.cy + height, np.cz);
			end;
		end;
	end;
end;

function courseplay:onUpdate(dt)
	
	if g_server == nil and self.isPostSynced == nil then 
		self.cp.driver:postSync()
		self.isPostSynced=true
	end
	
	if not self.cp.remoteIsEntered then
		if self.cp.isEntered ~= Enterable.getIsEntered(self) then
			--CourseplayEvent.sendEvent(self, "self.cp.remoteIsEntered",Enterable.getIsEntered(self))
			self:setCpVar('remoteIsEntered',Enterable.getIsEntered(self))
			--self.cp.remoteIsEntered = Enterable.getIsEntered(self)
		end
		self:setCpVar('isEntered',Enterable.getIsEntered(self))
	end
	
	if not courseplay.isClient then -- and self.cp.infoText ~= nil then --(self.cp.isDriving or self.cp.isRecording or self.cp.recordingIsPaused) then
		if self.cp.infoText == nil and not self.cp.infoTextNilSent then
			CourseplayEvent.sendEvent(self, "self.cp.infoText",nil)
			self.cp.infoTextNilSent = true
		elseif self.cp.infoText ~= nil then
			self.cp.infoText = nil
		end
	end;

	if self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_DBGONLY or self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_BOTH then
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

		local status, err = xpcall(self.cp.driver.update, function(err) printCallstack(); return err end, self.cp.driver, dt)

		for refIdx,_ in pairs(self.cp.activeGlobalInfoTexts) do
			if not self.cp.hasSetGlobalInfoTextThisLoop[refIdx] then
				CpManager:setGlobalInfoText(self, refIdx, true); --force remove
			end;
		end;

		if not status then
			courseplay.infoVehicle(self, 'Exception, stopping Courseplay driver, %s', tostring(err))
			courseplay:stop(self)
			return
		end
	end
	 
	if self.cp.onSaveClick and not self.cp.doNotOnSaveClick then
		if courseplay.vehicleToSaveCourseIn == self then
			inputCourseNameDialogue:onSaveClick()
		end
		self.cp.onSaveClick = false
		self.cp.doNotOnSaveClick = false
	end
	if self.cp.onMpSetCourses then
		courseplay.courses:reloadVehicleCourses(self)
		self.cp.onMpSetCourses = nil
	end

	if self.cp.collidingVehicleId ~= nil and g_currentMission.nodeToObject[self.cp.collidingVehicleId] ~= nil and g_currentMission.nodeToObject[self.cp.collidingVehicleId].isCpPathvehicle then
		courseplay:setPathVehiclesSpeed(self,dt)
	end

	--reset selected field num, when field doesn't exist anymone (contracts)
	if courseplay.fields.fieldData[self.cp.fieldEdge.selectedField.fieldNum] == nil then
		self.cp.fieldEdge.selectedField.fieldNum = 0;
	end	
	
	-- MODE 9: move shovel to positions (manually)
	if (self.cp.mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY or self.cp.shovelPositionFromKey) and self.cp.manualShovelPositionOrder ~= nil and self.cp.movingToolsPrimary then
		if courseplay:checkAndSetMovingToolsPosition(self, self.cp.movingToolsPrimary, self.cp.movingToolsSecondary, self.cp.shovelStatePositions[ self.cp.manualShovelPositionOrder ], dt) or courseplay:timerIsThrough(self, 'manualShovelPositionOrder') then
			courseplay:resetManualShovelPositionOrder(self);
				self:setCpVar('shovelPositionFromKey', false, courseplay.isClient);
		end;
	end;
	-- MODE 3: move pipe to positions (manually)
	if (self.cp.mode == courseplay.MODE_OVERLOADER or self.cp.mode == courseplay.MODE_GRAIN_TRANSPORT) and self.cp.manualPipePositionOrder ~= nil and self.cp.pipeWorkToolIndex then
		local workTool = self.attachedImplements[self.cp.pipeWorkToolIndex].object
		if courseplay:checkAndSetMovingToolsPosition(self, workTool.spec_cylindered.movingTools, nil, self.cp.pipePositions, dt , self.cp.pipeIndex ) or courseplay:timerIsThrough(self, 'manualPipePositionOrder') then
			courseplay:resetManualPipePositionOrder(self);
		end;
	end;	
	--sugarCaneTrailer update tipping function. Moved here so it only runs once. To ensure we start closed or open
	if self.cp.hasSugarCaneTrailer then
		courseplay:updateSugarCaneTrailerTipping(self,dt)
	end
	-- this really should be only done in one place.
	self.cp.curSpeed = self.lastSpeedReal * 3600;
	

end; --END update()

--[[
function courseplay:postUpdate(dt)
end;
]]

function courseplay:onUpdateTick(dt)
	--print("base:courseplay:updateTick(dt)")

	if not self.cp.fieldEdge.selectedField.buttonsCreated and courseplay.fields.numAvailableFields > 0 then
		courseplay:createFieldEdgeButtons(self);
	end;

	--attached or detached implement?
	if self.cp.tooIsDirty then
		self.cpTrafficCollisionIgnoreList = {}			-- clear local colli list, will be updated inside resetTools(self) again
		courseplay:resetTools(self)
	end
	
	if self.cp.isDriving and g_server ~= nil then
		local status, err = xpcall(self.cp.driver.updateTick, function(err) printCallstack(); return err end, self.cp.driver, dt)
		if not status then
			courseplay.infoVehicle(self, 'Exception, stopping Courseplay driver, %s', tostring(err))
			courseplay:stop(self)
			return
		end
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

function courseplay:onDelete()
	if self.cp.driver and self.cp.driver.collisionDetector then
		self.cp.driver.collisionDetector:deleteTriggers()
	end

	local ret_removeLegacyCollisionTriggers = false
	ret_removeLegacyCollisionTriggers = courseplay:removeLegacyCollisionTriggers(self);

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
		if self.cp.ppc then
			self.cp.ppc:delete()
		end
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
	if vehicle:getIsEntered()and vehicle.cp.infoText ~= nil and vehicle.cp.toolTip == nil then
		local text;
		local what = StringUtil.splitString(";", vehicle.cp.infoText);
		
		if what[1] == "COURSEPLAY_LOADING_AMOUNT"
		or what[1] == "COURSEPLAY_UNLOADING_AMOUNT"
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
		elseif what[1] == "COURSEPLAY_WAITING_FOR_FILL_LEVEL" then
			if what[3] then
				text = string.format(courseplay:loc(what[1]), what[2], tonumber(what[3]));
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

function courseplay:setVehicleWaypoints(vehicle, waypoints)
	vehicle.Waypoints = waypoints
	vehicle.cp.numWaypoints = #waypoints
	courseplay.signs:updateWaypointSigns(vehicle, "current");
	if vehicle.cp.numWaypoints > 3 then
		vehicle:setCpVar('canDrive',true,courseplay.isClient);
	end
end;

function courseplay:onReadStream(streamId, connection)
	courseplay:debug("id: "..tostring(self.id).."  base: readStream", 5)
		
	for _,variable in ipairs(courseplay.multiplayerSyncTable)do
		local value = courseplay.streamDebugRead(streamId, variable.dataFormat)
		if variable.dataFormat == 'String' and value == 'nil' then
			value = nil
		end
		courseplay:setVarValueFromString(self, variable.name, value)
	end
	courseplay:debug("id: "..tostring(NetworkUtil.getObjectId(self)).."  base: read courseplay.multiplayerSyncTable end", 5)
-------------------
	-- SettingsContainer:
	self.cp.settings:onReadStream(streamId)
	-- courseGeneratorSettingsContainer:
	self.cp.courseGeneratorSettings:onReadStream(streamId)
-------------------	
	local savedFieldNum = streamDebugReadInt32(streamId)
	if savedFieldNum > 0 then
		self.cp.generationPosition.fieldNum = savedFieldNum
	end
		
	local copyCourseFromDriverId = streamDebugReadInt32(streamId)
	if copyCourseFromDriverId then
		self.cp.copyCourseFromDriver = NetworkUtil.getObject(copyCourseFromDriverId) 
	end
		
	local savedCombineId = streamDebugReadInt32(streamId)
	if savedCombineId then
		self.cp.savedCombine = NetworkUtil.getObject(savedCombineId)
	end

	local activeCombineId = streamDebugReadInt32(streamId)
	if activeCombineId then
		self.cp.activeCombine = NetworkUtil.getObject(activeCombineId)
	end

	local current_trailer_id = streamDebugReadInt32(streamId)
	if current_trailer_id then
		self.cp.currentTrailerToFill = NetworkUtil.getObject(current_trailer_id)
	end

	courseplay.courses:reinitializeCourses()


	-- kurs daten
	local courses = streamDebugReadString(streamId) -- 60.
	if courses ~= nil then
		self.cp.loadedCourses = StringUtil.splitString(",", courses);
		courseplay:reloadCourses(self, true)
	end
	
	self.cp.numCourses = streamDebugReadInt32(streamId)
	
	--print(string.format("%s:read: numCourses: %s loadedCourses: %s",tostring(self.name),tostring(self.cp.numCourses),tostring(#self.cp.loadedCourses)))
	if self.cp.numCourses > #self.cp.loadedCourses then
		self.Waypoints = {}
		local wp_count = streamDebugReadInt32(streamId)
		for w = 1, wp_count do
			table.insert(self.Waypoints, CourseEvent:readWaypoint(streamId))
		end
		self.cp.numWaypoints = #self.Waypoints
		
		if self.cp.numCourses > 1 then
			self.cp.currentCourseName = string.format("%d %s", self.cp.numCourses, courseplay:loc('COURSEPLAY_COMBINED_COURSES'));
		end
	end

	
	local debugChannelsString = streamDebugReadString(streamId)
	for k,v in pairs(StringUtil.splitString(",", debugChannelsString)) do
		courseplay:toggleDebugChannel(self, k, v == 'true');
	end;
	
	--Ingame Map Sync
	if streamDebugReadBool(streamId) then
		--add to activeCoursePlayers
		CpManager:addToActiveCoursePlayers(self)	
		-- add ingameMap icon
		courseplay:createMapHotspot(self);
	end
	
	--Make sure every vehicle has same AIDriver as the Server
	courseplay:setAIDriver(self, self.cp.mode)
	
	courseplay:debug("id: "..tostring(self.id).."  base: readStream end", 5)
end

function courseplay:onWriteStream(streamId, connection)
	courseplay:debug("id: "..tostring(self).."  base: write stream", 5)
		
	for _,variable in ipairs(courseplay.multiplayerSyncTable)do
		courseplay.streamDebugWrite(streamId, variable.dataFormat, courseplay:getVarValueFromString(self,variable.name),variable.name)
	end
	courseplay:debug("id: "..tostring(self).."  base: write courseplay.multiplayerSyncTable end", 5)
-------------------
	-- SettingsContainer:
	self.cp.settings:onWriteStream(streamId)
	-- courseGeneratorSettingsContainer:
	self.cp.courseGeneratorSettings:onWriteStream(streamId)
-------------
	streamDebugWriteInt32(streamId, self.cp.generationPosition.fieldNum)
	
	local copyCourseFromDriverID;
	if self.cp.copyCourseFromDriver ~= nil then
		copyCourseFromDriverID = NetworkUtil.getObjectId(self.cp.copyCourseFromDriver)
	end
	streamDebugWriteInt32(streamId, copyCourseFromDriverID)
	
	
	local savedCombineId;
	if self.cp.savedCombine ~= nil then
		savedCombineId = NetworkUtil.getObjectId(self.cp.savedCombine)
	end
	streamDebugWriteInt32(streamId, savedCombineId)

	local activeCombineId;
	if self.cp.activeCombine ~= nil then
		activeCombineId = NetworkUtil.getObjectId(self.cp.activeCombine)
	end
	streamDebugWriteInt32(streamId, activeCombineId)

	local current_trailer_id;
	if self.cp.currentTrailerToFill ~= nil then
		current_trailer_id = NetworkUtil.getObjectId(self.cp.currentTrailerToFill)
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
		courseplay:debug("id: "..tostring(NetworkUtil.getObjectId(self)).."  sync temp course", 5)
		streamDebugWriteInt32(streamId, #(self.Waypoints))
		for w = 1, #(self.Waypoints) do
			--print("writing point "..tostring(w))
			CourseEvent:writeWaypoint(streamId, self.Waypoints[w])
		end
	end

	local debugChannelsString = table.concat(table.map(courseplay.debugChannels, tostring), ",");
	streamDebugWriteString(streamId, debugChannelsString) 
		
	if self.cp.mapHotspot then
		streamDebugWriteBool(streamId,true)
	else
		streamDebugWriteBool(streamId,false)
	end
	
	
	courseplay:debug("id: "..tostring(NetworkUtil.getObjectId(self)).."  base: write stream end", 5)
end

function courseplay:onReadUpdateStream(streamId, timestamp, connection)
	if g_server == nil and CpManager.isMultiplayer then
		if self.cp.driver ~= nil then 
			self.cp.driver:readUpdateStream(streamId)
		--	streamWriteInt32(streamId,self.cp.waypointIndex)
		--	streamWriteInt32(streamId,self.cp.numWaypoints)
		--	streamWriteBool(streamId,self.cp.isDriving)
			--cp.infoText !!
			--globalInfoText!!
			--distanceCheck
			--canDrive
			--isRecording ??
			--currentCourseName
			--convoy to setting
			--gitAdditionalText
		end 
	end
end

function courseplay:onWriteUpdateStream(streamId, connection, dirtyMask)
	if g_server ~= nil and CpManager.isMultiplayer then
		if self.cp.driver ~= nil then
			self.cp.driver:writeUpdateStream(streamId)
		end
	end
end

function courseplay:loadVehicleCPSettings(xmlFile, key, resetVehicles)
	
	if not resetVehicles and g_server ~= nil then
		-- COURSEPLAY
		local curKey = key .. '.courseplay.basics';
		courseplay:setCpMode(self,  Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#aiMode'), self.cp.mode));
		self.cp.waitTime 		  = Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#waitTime'),		 0);
		local courses 			  = Utils.getNoNil(getXMLString(xmlFile, curKey .. '#courses'),			 '');
		self.cp.loadedCourses = StringUtil.splitString(",", courses);
		courseplay:reloadCourses(self, true);

		--HUD
		curKey = key .. '.courseplay.HUD';
		self.cp.hud.show = Utils.getNoNil(  getXMLBool(xmlFile, curKey .. '#showHud'), false);
		
		-- MODE 2
		curKey = key .. '.courseplay.combi';
		self.cp.tipperOffset 		  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#tipperOffset'),			 0);
		self.cp.combineOffset 		  = Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#combineOffset'),		 0);
		self.cp.combineOffsetAutoMode = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#combineOffsetAutoMode'), true);
		
		curKey = key .. '.courseplay.driving';
		self.cp.turnDiameter		  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#turnDiameter'),			 self.cp.vehicleTurnRadius * 2);
		self.cp.turnDiameterAutoMode  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#turnDiameterAutoMode'),	 true);
		self.cp.alignment.enabled 	  = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#alignment'),	 		 true);
	
	
		-- MODES 4 / 6
		curKey = key .. '.courseplay.fieldWork';
		self.cp.oppositeTurnMode					= Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#oppositeTurnMode'),		false);
		self.cp.workWidth 							= Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#workWidth'),				3);
		self.cp.abortWork							= Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#abortWork'),				0);
		self.cp.manualWorkWidth						= Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#manualWorkWidth'),		0);
		self.cp.lastValidTipDistance				= Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#lastValidTipDistance'),	0);
		self.cp.generationPosition.hasSavedPosition	= Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#hasSavedPosition'),		false);
		self.cp.generationPosition.x				= Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#savedPositionX'),			0);
		self.cp.generationPosition.z				= Utils.getNoNil(getXMLFloat(xmlFile, curKey .. '#savedPositionZ'),			0);
		self.cp.generationPosition.fieldNum 		= Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#savedFieldNum'),			0);
		self.cp.convoyActive						= Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#convoyActive'),			false);
		if self.cp.abortWork == 0 then
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
		
		local offsetData = Utils.getNoNil(getXMLString(xmlFile, curKey .. '#offsetData'), '0;0;0;false;0;0;0'); -- 1=laneOffset, 2=toolOffsetX, 3=toolOffsetZ, 4=symmetricalLaneChange
		offsetData = StringUtil.splitString(';', offsetData);
		courseplay:changeLaneOffset(self, nil, tonumber(offsetData[1]));
		courseplay:changeToolOffsetX(self, nil, tonumber(offsetData[2]), true);
		courseplay:changeToolOffsetZ(self, nil, tonumber(offsetData[3]), true);

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
			shovelRots = StringUtil.splitString(';', shovelRots);
			shovelTrans = StringUtil.splitString(';', shovelTrans);
			if #shovelRots == 4 and #shovelTrans == 4 then
				for state=2, 5 do
					local shovelRotsSplit = table.map(StringUtil.splitString(' ', shovelRots[state-1]), tonumber);
					local shovelTransSplit = table.map(StringUtil.splitString(' ', shovelTrans[state-1]), tonumber);
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
		--courseplay.buttons:setActiveEnabled(self, 'shovel');

	

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
		self.cp.mode10.shieldHeight = Utils.getNoNil( getXMLFloat(xmlFile, curKey .. '#shieldHeight'), 0.3);
		self.cp.mode10.automaticSpeed =  Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#automaticSpeed'), true);
		self.cp.mode10.automaticHeigth = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#automaticHeight'), true);
		self.cp.mode10.bladeOffset = Utils.getNoNil( getXMLFloat(xmlFile, curKey .. '#bladeOffset'), 0);
		self.cp.mode10.drivingThroughtLoading = Utils.getNoNil( getXMLBool(xmlFile, curKey .. '#drivingThroughtLoading'), false);

		self.cp.settings:loadFromXML(xmlFile, key .. '.courseplay')

		courseplay:validateCanSwitchMode(self);
	end;
	return BaseMission.VEHICLE_LOAD_OK;
end


function courseplay:saveToXMLFile(xmlFile, key, usedModNames)
	if not self.hasCourseplaySpec then
		courseplay.infoVehicle(self, 'has no Courseplay installed, not adding Courseplay data to savegame.')
		return
	end

	--cut the key to configure it for our needs 
	local keySplit = StringUtil.splitString(".", key);
	local newKey = keySplit[1]
	for i=2,#keySplit-2 do
		newKey = newKey..'.'..keySplit[i]
	end
	newKey = newKey..'.courseplay'

	
	--CP basics
	setXMLInt(xmlFile, newKey..".basics #aiMode", self.cp.mode)
	if #self.cp.loadedCourses == 0 and self.cp.currentCourseId ~= 0 then
		-- this is the case when a course has been generated and than saved, it is not in loadedCourses (should probably
		-- fix it there), so make sure it is in the savegame
		setXMLString(xmlFile, newKey..".basics #courses", tostring(self.cp.currentCourseId))
	else
		setXMLString(xmlFile, newKey..".basics #courses", tostring(table.concat(self.cp.loadedCourses, ",")))
	end
	setXMLInt(xmlFile, newKey..".basics #waitTime", self.cp.waitTime)

	--HUD
	setXMLBool(xmlFile, newKey..".HUD #showHud", self.cp.hud.show)
	

	
	--combineMode
	setXMLString(xmlFile, newKey..".combi #tipperOffset", string.format("%.1f",self.cp.tipperOffset))
	setXMLString(xmlFile, newKey..".combi #combineOffset", string.format("%.1f",self.cp.combineOffset))
	setXMLString(xmlFile, newKey..".combi #combineOffsetAutoMode", tostring(self.cp.combineOffsetAutoMode))
	
	--driving settings
	setXMLInt(xmlFile, newKey..".driving #turnDiameter", self.cp.turnDiameter)
	setXMLBool(xmlFile, newKey..".driving #turnDiameterAutoMode", self.cp.turnDiameterAutoMode)
	setXMLString(xmlFile, newKey..".driving #alignment", tostring(self.cp.alignment.enabled))
	
	--field work settings
	local offsetData = string.format('%.1f;%.1f;%.1f;%s;%.1f;%.1f;%d', self.cp.laneOffset, self.cp.toolOffsetX, self.cp.toolOffsetZ, 0, self.cp.loadUnloadOffsetX, self.cp.loadUnloadOffsetZ, self.cp.laneNumber);
	setXMLString(xmlFile, newKey..".fieldWork #workWidth", string.format("%.1f",self.cp.workWidth))
	setXMLString(xmlFile, newKey..".fieldWork #offsetData", offsetData)
	setXMLInt(xmlFile, newKey..".fieldWork #abortWork", Utils.getNoNil(self.cp.abortWork, 0))
	setXMLBool(xmlFile, newKey..".fieldWork #oppositeTurnMode", self.cp.oppositeTurnMode)
	setXMLString(xmlFile, newKey..".fieldWork #manualWorkWidth", string.format("%.1f",Utils.getNoNil(self.cp.manualWorkWidth,0)))
	setXMLString(xmlFile, newKey..".fieldWork #lastValidTipDistance", string.format("%.1f",Utils.getNoNil(self.cp.lastValidTipDistance,0)))
	setXMLBool(xmlFile, newKey..".fieldWork #hasSavedPosition", self.cp.generationPosition.hasSavedPosition)
	setXMLString(xmlFile, newKey..".fieldWork #savedPositionX", string.format("%.1f",Utils.getNoNil(self.cp.generationPosition.x,0)))
	setXMLString(xmlFile, newKey..".fieldWork #savedPositionZ", string.format("%.1f",Utils.getNoNil(self.cp.generationPosition.z,0)))
	setXMLString(xmlFile, newKey..".fieldWork #savedFieldNum", string.format("%.1f",Utils.getNoNil(self.cp.generationPosition.fieldNum,0)))
	setXMLBool(xmlFile, newKey..".fieldWork #convoyActive", self.cp.convoyActive)

	--LevlingAndCompactingSettings
	setXMLBool(xmlFile, newKey..".mode10 #leveling", self.cp.mode10.leveling)
	setXMLBool(xmlFile, newKey..".mode10 #CourseplayersOnly", self.cp.mode10.searchCourseplayersOnly)
	setXMLInt(xmlFile, newKey..".mode10 #searchRadius", self.cp.mode10.searchRadius)
	setXMLString(xmlFile, newKey..".mode10 #shieldHeight", string.format("%.1f",self.cp.mode10.shieldHeight))
	setXMLBool(xmlFile, newKey..".mode10 #automaticSpeed", self.cp.mode10.automaticSpeed)
	setXMLBool(xmlFile, newKey..".mode10 #automaticHeight", self.cp.mode10.automaticHeigth)
	setXMLString(xmlFile, newKey..".mode10 #bladeOffset", string.format("%.1f",self.cp.mode10.bladeOffset))
	setXMLBool(xmlFile, newKey..".mode10 #drivingThroughtLoading", self.cp.mode10.drivingThroughtLoading)
	
	--shovelMode positions
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
		if shovelRotsAttrNodes or shovelTransAttrNodes then
			setXMLBool(xmlFile, newKey..".shovel #shovelStopAndGo", self.cp.shovelStopAndGo)
			setXMLString(xmlFile, newKey..".shovel #rot", shovelRotsAttrNodes)
			setXMLString(xmlFile, newKey..".shovel #trans",  shovelTransAttrNodes)
		end;
	end;
		
	--overloaderPipe
	if self.cp.pipeWorkToolIndex ~= nil then
		setXMLString(xmlFile, newKey..".overLoaderPipe #rot", tostring(table.concat(self.cp.pipePositions.rot)))
		setXMLString(xmlFile, newKey..".overLoaderPipe #trans", tostring(table.concat(self.cp.pipePositions.trans)))
		setXMLInt(xmlFile, newKey..".overLoaderPipe #pipeIndex", self.cp.pipeIndex)
		setXMLInt(xmlFile, newKey..".overLoaderPipe #pipeWorkToolIndex", self.cp.pipeWorkToolIndex)
	end

	self.cp.settings:saveToXML(xmlFile, newKey)

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

-- Workaround: onEndWorkAreaProcessing seems to cause Cutter to call stopAIVehicle when
-- driving on an already worked field, or a field where the fruit type is different than the one being processed.
-- This changes that behavior.
function courseplay:getAllowCutterAIFruitRequirements(superFunc)
	return superFunc(self) and not self:getIsCourseplayDriving()
end
Cutter.getAllowCutterAIFruitRequirements = Utils.overwrittenFunction(Cutter.getAllowCutterAIFruitRequirements, courseplay.getAllowCutterAIFruitRequirements)

-- Workaround: onEndWorkAreaProcessing seems to cause Cutter to call stopAIVehicle when
-- driving on an already worked field. This will suppress that call as long as Courseplay is driving
function courseplay:stopAIVehicle(superFunc, reason, noEventSend)
	if superFunc ~= nil and not self:getIsCourseplayDriving() then
		superFunc(self, reason, noEventSend)
	end
end
AIVehicle.stopAIVehicle = Utils.overwrittenFunction(AIVehicle.stopAIVehicle, courseplay.stopAIVehicle)


function courseplay.processSowingMachineArea(tool,originalFunction, superFunc, workArea, dt)
	if tool.fertilizerEnabled ~= nil then
		tool.spec_sprayer.workAreaParameters.sprayFillLevel = tool.fertilizerEnabled and tool.spec_sprayer.workAreaParameters.sprayFillLevel or 0
	end
	return originalFunction(tool, superFunc, workArea, dt)
end
FertilizingSowingMachine.processSowingMachineArea = Utils.overwrittenFunction(FertilizingSowingMachine.processSowingMachineArea, courseplay.processSowingMachineArea)


-- Tour dialog messes up the CP yes no dialogs.
function courseplay:showTourDialog()
	print('Tour dialog is disabled by Courseplay.')
end
TourIcons.showTourDialog = Utils.overwrittenFunction(TourIcons.showTourDialog, courseplay.showTourDialog)

-- TODO: make these part of AIDriver

function courseplay:setWaypointIndex(vehicle, number,isRecording)
	if vehicle.cp.waypointIndex ~= number then
		vehicle.cp.course.hasChangedTheWaypointIndex = true
		if isRecording then
			vehicle.cp.waypointIndex = number
			--courseplay.buttons:setActiveEnabled(vehicle, 'recording');
		else
			vehicle:setCpVar('waypointIndex',number,courseplay.isClient);
		end
		if vehicle.cp.waypointIndex > 1 then
			vehicle.cp.previousWaypointIndex = vehicle.cp.waypointIndex - 1;
		else
			vehicle.cp.previousWaypointIndex = 1;
		end;
	end;
end;

function courseplay:getIsCourseplayDriving()
	return self.cp.isDriving;
end;

function courseplay:setIsCourseplayDriving(active)
	self:setCpVar('isDriving',active,courseplay.isClient)
end;

--This is a copy from the Autodrive code "https://github.com/Stephan-S/FS19_AutoDrive" 
--all credits go to their Dev team
--All the code that has to be run on Server and Client from the "start_stop" file has to get in here
function courseplay:onStartCpAIDriver()
	self.forceIsActive = true
    self.spec_motorized.stopMotorOnLeave = false
    self.spec_enterable.disableCharacterOnLeave = false
    self.spec_aiVehicle.isActive = true
    self.steeringEnabled = false

    if self.currentHelper == nil then
		self.currentHelper = g_helperManager:getRandomHelper()
        if self.setRandomVehicleCharacter ~= nil then
            self:setRandomVehicleCharacter()
            self.cp.vehicleCharacter = self.spec_enterable.vehicleCharacter
        end
        if self.spec_enterable.controllerFarmId ~= 0 then
            self.spec_aiVehicle.startedFarmId = self.spec_enterable.controllerFarmId
        end
	end
	if self.cp.coursePlayerNum == nil then
		self.cp.coursePlayerNum = CpManager:addToTotalCoursePlayers(self)
	end;
	
	--add to activeCoursePlayers
	CpManager:addToActiveCoursePlayers(self)
	
	-- add ingameMap Hotspot
	courseplay:createMapHotspot(self);
	
end

function courseplay:onStopCpAIDriver()
	
    --if self.raiseAIEvent ~= nil then
     --   self:raiseAIEvent("onAIEnd", "onAIImplementEnd")
    --end

    self.spec_aiVehicle.isActive = false
    self.forceIsActive = false
    self.spec_motorized.stopMotorOnLeave = true
    self.spec_enterable.disableCharacterOnLeave = true
    self.currentHelper = nil

    if self.restoreVehicleCharacter ~= nil then
        self:restoreVehicleCharacter()
    end

    if self.steeringEnabled == false then
        self.steeringEnabled = true
    end

    self:requestActionEventUpdate()
	
	--remove from activeCoursePlayers
	CpManager:removeFromActiveCoursePlayers(self);

	-- remove ingame map hotspot
	courseplay:deleteMapHotspot(self);
end

-- do not remove this comment
-- vim: set noexpandtab:
