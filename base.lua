local floor = math.floor;

function courseplay.prerequisitesPresent(specializations)
	return true;
end

--[[
function courseplay:preLoad(xmlFile)
end;
]]

function courseplay:load(xmlFile)
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
	if self.cp.isCombine then
		self.cp.mode7Unloading = false
		self.cp.driverPriorityUseFillLevel = false;
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
	self.cp.waitTime = 0;
	self.cp.crossingPoints = {};
	self.cp.numCrossingPoints = 0;

	self.cp.visualWaypointsMode = 1
	self.cp.warningLightsMode = 1;
	self.cp.hasHazardLights = self.turnSignalState ~= nil and self.setTurnSignalState ~= nil;


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


	-- ai mode 9: shovel
	self.cp.shovelEmptyPoint = nil;
	self.cp.shovelFillStartPoint = nil;
	self.cp.shovelFillEndPoint = nil;
	self.cp.shovelState = 1;
	self.cp.shovel = {};
	self.cp.shovelStopAndGo = false;
	self.cp.shovelLastFillLevel = nil;
	self.cp.shovelStatePositions = {};
	self.cp.hasShovelStatePositions = {};
	self.cp.manualShovelPositionOrder = nil;
	for i=2,5 do
		self.cp.hasShovelStatePositions[i] = false;
	end;

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
		reverse =  6;
		turn =   10;
		field =  24;
		street = 50;
		crawl = 3;
		
		minReverse = 3;
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
	courseplay:setAckermannSteeringInfo(self, xmlFile);
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

	-- HUD
	courseplay.hud:setupVehicleHud(self);

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
			alwaysUseFourWD = false;
		};

		-- add "always use 4WD" button
		if self.cp.driveControl.hasFourWD then
			courseplay.button:new(self, 7, nil, 'toggleAlwaysUseFourWD', nil, courseplay.hud.col1posX, courseplay.hud.linesPosY[5], courseplay.hud.contentMaxWidth, 0.015, 5, nil, true);
		end;
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
	--DEBUG Speed Setting
	if courseplay.debugChannels[21] then
		renderText(0.2, 0.105, 0.02, string.format("mode%d rn: %d",self.cp.mode,self.cp.waypointIndex));
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
			renderText(0.2,0.255,0.02,string.format("combine.lastSpeedReal: %.6f ",combine.lastSpeedReal*3600))
			renderText(0.2,0.225,0.02,"combine.turnStage: "..combine.turnStage)
			renderText(0.2,0.195,0.02,"combine.cp.turnStage: "..combine.cp.turnStage)
			renderText(0.2,0.165,0.02,"combine.acTurnStage: "..combine.acTurnStage)
			renderText(0.2,0.135,0.02,"combineIsTurning: "..tostring(self.cp.mode2DebugTurning ))
		end	
	end
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
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_NEXTMODE'), InputBinding.COURSEPLAY_NEXTMODE);
				end;
				if self.cp.prevMode then
					g_currentMission:addHelpButtonText(courseplay:loc('COURSEPLAY_PREVMODE'), InputBinding.COURSEPLAY_PREVMODE);
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
		end;
		if self.isEntered and self.cp.toolTip ~= nil then
			courseplay:renderToolTip(self);
		end;
	end;
	
	--RENDER
	courseplay:renderInfoText(self);
	
end; --END draw()

function courseplay:showWorkWidth(vehicle)

	local left =  (vehicle.cp.workWidth *  0.5) + (vehicle.cp.toolOffsetX or 0);
	local right = (vehicle.cp.workWidth * -0.5) + (vehicle.cp.toolOffsetX or 0);

	if vehicle.cp.DirectionNode and vehicle.cp.backMarkerOffset and vehicle.cp.aiFrontMarker then
		local p1x, p1y, p1z = localToWorld(vehicle.cp.DirectionNode, left,  1.6, vehicle.cp.backMarkerOffset);
		local p2x, p2y, p2z = localToWorld(vehicle.cp.DirectionNode, right, 1.6, vehicle.cp.backMarkerOffset);
		local p3x, p3y, p3z = localToWorld(vehicle.cp.DirectionNode, right, 1.6, vehicle.cp.aiFrontMarker);
		local p4x, p4y, p4z = localToWorld(vehicle.cp.DirectionNode, left,  1.6, vehicle.cp.aiFrontMarker);

		drawDebugPoint(p1x, p1y, p1z, 1, 1, 0, 1);
		drawDebugPoint(p2x, p2y, p2z, 1, 1, 0, 1);
		drawDebugPoint(p3x, p3y, p3z, 1, 1, 0, 1);
		drawDebugPoint(p4x, p4y, p4z, 1, 1, 0, 1);

		drawDebugLine(p1x, p1y, p1z, 1, 0, 0, p2x, p2y, p2z, 1, 0, 0);
		drawDebugLine(p2x, p2y, p2z, 1, 0, 0, p3x, p3y, p3z, 1, 0, 0);
		drawDebugLine(p3x, p3y, p3z, 1, 0, 0, p4x, p4y, p4z, 1, 0, 0);
		drawDebugLine(p4x, p4y, p4z, 1, 0, 0, p1x, p1y, p1z, 1, 0, 0);
	else
		local lX, lY, lZ = localToWorld(vehicle.rootNode, left,  1.6, -6);
		local rX, rY, rZ = localToWorld(vehicle.rootNode, right, 1.6, -6);

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

	if not courseplay.isClient then
		if self.cp.isDriving then
			local showDriveOnButton = false;
			if self.cp.mode == courseplay.MODE_FIELDWORK then
				if self.cp.wait and (self.cp.waypointIndex == self.cp.stopWork or self.cp.previousWaypointIndex == self.cp.stopWork) and self.cp.abortWork == nil and not self.cp.isLoaded and not isFinishingWork and self.cp.hasUnloadingRefillingCourse then
					showDriveOnButton = true;
				end;
			else
				if (self.cp.wait and (self.Waypoints[self.cp.waypointIndex].wait or self.Waypoints[self.cp.previousWaypointIndex].wait)) or (self.cp.stopAtEnd and (self.cp.waypointIndex == self.cp.numWaypoints or self.cp.currentTipTrigger ~= nil)) then
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
			self:setCpVar('HUD0isManual', not self.cp.isDriving and not combine.isAIThreshing,courseplay.isClient);
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
	if self.cp.toolsDirty then
		self.cpTrafficCollisionIgnoreList = {}
		courseplay:reset_tools(self)
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
		or what[1] == "COURSEPLAY_WAITING_POINTS_TOO_MANY" then
			if what[2] then
				text = string.format(courseplay:loc(what[1]), what[2]);
			end
		elseif what[1] == "COURSEPLAY_DISTANCE" then  
			if what[2] then
				local dist = tonumber(what[2]);
				if dist >= 1000 then
					text = ('%s: %.1f%s'):format(courseplay:loc('COURSEPLAY_DISTANCE'), dist * 0.001, g_i18n:getMeasuringUnit());
				else
					text = ('%s: %d%s'):format(courseplay:loc('COURSEPLAY_DISTANCE'), dist, g_i18n:getText('unit_meter'));
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
	--print(tostring(self.name).."  base: readStream")
	self.cp.automaticCoverHandling = streamDebugReadBool(streamId);
	self.cp.automaticUnloadingOnField = streamDebugReadBool(streamId);
	courseplay:setCpMode(self, streamDebugReadInt32(streamId));
	self.cp.turnDiameterAuto = streamDebugReadFloat32(streamId)
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
	self.cp.turnDiameterAutoMode = streamDebugReadBool(streamId);
	self.cp.turnDiameter = streamDebugReadFloat32(streamId)
	self.cp.speeds.useRecordingSpeed = streamDebugReadBool(streamId) 
	self.cp.coursePlayerNum = streamReadFloat32(streamId)
	self.cp.laneOffset = streamDebugReadFloat32(streamId)
	self.cp.toolOffsetX = streamDebugReadFloat32(streamId)
	self.cp.toolOffsetZ = streamDebugReadFloat32(streamId)
	courseplay:setHudPage(self, streamDebugReadInt32(streamId));
	self.cp.HUD0noCourseplayer = streamDebugReadBool(streamId);
	self.cp.HUD0wantsCourseplayer = streamDebugReadBool(streamId);
	self.cp.HUD0combineForcedSide = streamDebugReadString(streamId);
	self.cp.HUD0isManual = streamDebugReadBool(streamId);
	self.cp.HUD0turnStage = streamDebugReadInt32(streamId);
	self.cp.HUD0tractorForcedToStop = streamDebugReadBool(streamId);
	self.cp.HUD0tractorName = streamDebugReadString(streamId);
	self.cp.HUD0tractor = streamDebugReadBool(streamId);
	self.cp.HUD1wait = streamDebugReadBool(streamId);
	self.cp.HUD1noWaitforFill = streamDebugReadBool(streamId);
	self.cp.HUD4hasActiveCombine = streamDebugReadBool(streamId);
	self.cp.HUD4combineName = streamDebugReadString(streamId);
	self.cp.HUD4savedCombine = streamDebugReadBool(streamId);
	self.cp.HUD4savedCombineName = streamDebugReadString(streamId);
	self.cp.waypointIndex = streamDebugReadInt32(streamId);
	self.cp.isRecording = streamDebugReadBool(streamId);
	self.cp.recordingIsPaused = streamDebugReadBool(streamId);
	self.cp.searchCombineAutomatically = streamDebugReadBool(streamId)
	self.cp.searchCombineOnField = streamDebugReadInt32(streamId)
	self.cp.speeds.turn = streamDebugReadFloat32(streamId)
	self.cp.speeds.field = streamDebugReadFloat32(streamId)
	self.cp.speeds.reverse = streamDebugReadFloat32(streamId)
	self.cp.speeds.street = streamDebugReadFloat32(streamId)
	self.cp.visualWaypointsMode = streamDebugReadInt32(streamId)
	self.cp.warningLightsMode = streamDebugReadInt32(streamId)
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
	--print(tostring(self.name).."  base: write stream")
	streamDebugWriteBool(streamId, self.cp.automaticCoverHandling)
	streamDebugWriteBool(streamId, self.cp.automaticUnloadingOnField)
	streamDebugWriteInt32(streamId,self.cp.mode)
	streamDebugWriteFloat32(streamId,self.cp.turnDiameterAuto)
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
	streamDebugWriteBool(streamId,self.cp.turnDiameterAutoMode)
	streamDebugWriteFloat32(streamId,self.cp.turnDiameter)
	streamDebugWriteBool(streamId,self.cp.speeds.useRecordingSpeed)
	streamDebugWriteFloat32(streamId,self.cp.coursePlayerNum);
	streamDebugWriteFloat32(streamId,self.cp.laneOffset)
	streamDebugWriteFloat32(streamId,self.cp.toolOffsetX)
	streamDebugWriteFloat32(streamId,self.cp.toolOffsetZ)
	streamDebugWriteInt32(streamId,self.cp.hud.currentPage)
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
	streamDebugWriteInt32(streamId,self.cp.waypointIndex)
	streamDebugWriteBool(streamId,self.cp.isRecording)
	streamDebugWriteBool(streamId,self.cp.recordingIsPaused)
	streamDebugWriteBool(streamId,self.cp.searchCombineAutomatically)
	streamDebugWriteInt32(streamId,self.cp.searchCombineOnField)
	streamDebugWriteFloat32(streamId,self.cp.speeds.turn)
	streamDebugWriteFloat32(streamId,self.cp.speeds.field)
	streamDebugWriteFloat32(streamId,self.cp.speeds.reverse)
	streamDebugWriteFloat32(streamId,self.cp.speeds.street)
	streamDebugWriteInt32(streamId,self.cp.visualWaypointsMode)
	streamDebugWriteInt32(streamId,self.cp.warningLightsMode)
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

	local debugChannelsString = table.concat(table.map(courseplay.debugChannels, tostring), ",");
	streamDebugWriteString(streamId, debugChannelsString) 
	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write stream end", 5)
end


function courseplay:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles and g_server ~= nil then
		-- COURSEPLAY
		local curKey = key .. '.courseplay';
		courseplay:setCpMode(self,  Utils.getNoNil(   getXMLInt(xmlFile, curKey .. '#aiMode'),			 self.cp.mode));
		self.cp.hud.openWithMouse = Utils.getNoNil(  getXMLBool(xmlFile, curKey .. '#openHudWithMouse'), true);
		self.cp.warningLightsMode  = Utils.getNoNil(  getXMLInt(xmlFile, curKey .. '#lights'),			 1);
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
	local cpOpen = string.format('<courseplay aiMode=%q courses=%q openHudWithMouse=%q lights=%q visualWaypoints=%q waitTime=%q multiSiloSelectedFillType=%q>', tostring(self.cp.mode), tostring(table.concat(self.cp.loadedCourses, ",")), tostring(self.cp.hud.openWithMouse), tostring(self.cp.warningLightsMode), tostring(self.cp.visualWaypointsMode), tostring(self.cp.waitTime), Fillable.fillTypeIntToName[self.cp.multiSiloSelectedFillType]);
	local speeds = string.format('<speeds useRecordingSpeed=%q reverse="%d" turn="%d" field="%d" max="%d" />', tostring(self.cp.speeds.useRecordingSpeed), self.cp.speeds.reverse, self.cp.speeds.turn, self.cp.speeds.field, self.cp.speeds.street);
	local combi = string.format('<combi tipperOffset="%.1f" combineOffset="%.1f" combineOffsetAutoMode=%q fillFollow="%d" fillDriveOn="%d" turnDiameter="%d" realisticDriving=%q />', self.cp.tipperOffset, self.cp.combineOffset, tostring(self.cp.combineOffsetAutoMode), self.cp.followAtFillLevel, self.cp.driveOnAtFillLevel, self.cp.turnDiameter, tostring(self.cp.realisticDriving));
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

