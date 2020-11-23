local curFile = 'start_stop.lua';

-- starts driving the course
function courseplay:start(self)
	if g_server == nil then 
		return
	end
	
	self.cp.TrafficBrake = false
	self.cp.inTraffic = false
	
	if not CpManager.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] then			-- ???
		CpManager.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] = true;
	end;

	-- TODO: move this to TrafficCollision.lua
	if self:getAINeedsTrafficCollisionBox() then
		local collisionRoot = g_i3DManager:loadSharedI3DFile(AIVehicle.TRAFFIC_COLLISION_BOX_FILENAME, self.baseDirectory, false, true, false)
		if collisionRoot ~= nil and collisionRoot ~= 0 then
			local collision = getChildAt(collisionRoot, 0)
			link(getRootNode(), collision)

			self.spec_aiVehicle.aiTrafficCollision = collision

			delete(collisionRoot)
		end
	end

	self.cp.numWayPoints = #self.Waypoints;
	--self:setCpVar('numWaypoints', #self.Waypoints,courseplay.isClient);
	if self.cp.numWaypoints < 1 then
		return
	end
	--setEngineState needed or AIDriver handling this ??
	courseplay:setEngineState(self, true);
	self.cp.saveFuel = false

	courseplay.alreadyPrinted = {}

	self.cpTrafficCollisionIgnoreList = {}
	
	self:setIsCourseplayDriving(false);
	courseplay:setIsRecording(self, false);
	courseplay:setRecordingIsPaused(self, false);
	self.cp.calculatedCourseToCombine = false

	courseplay:resetTools(self)

	if self.cp.waypointIndex < 1 then
		courseplay:setWaypointIndex(self, 1);
	end

	-- show arrow
	self:setCpVar('distanceCheck',true,courseplay.isClient);
	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.cp.directionNode);

	-- TODO: temporary bandaid here for the case when the legacy waypointIndex isn't set correctly
	if self.cp.waypointIndex > #self.Waypoints then
		courseplay.infoVehicle(self, 'Waypoint index %d reset to %d', self.cp.waypointIndex, #self.Waypoints)
		self.cp.waypointIndex = #self.Waypoints
	end
	-- position of next waypoint
	local cx, cz = self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz
	-- distance (in any direction)
	local dist = courseplay:distance(ctx, ctz, cx, cz)

	local setLaneNumber = false;
	local isFrontAttached = false;
	local isReversePossible = true;
	local tailerCount = 0;
	for k,workTool in pairs(self.cp.workTools) do    --TODO temporary solution (better would be Tool:getIsAnimationPlaying(animationName))
		if courseplay:isFolding(workTool) then
			if  self.setLowered ~= nil then
				workTool:setLowered(true)
			elseif self.setFoldState ~= nil then
				self:setFoldState(-1, true)
			end
		end;
		--DrivingLine spec: set lane numbers
		if self.cp.mode == 4 and not setLaneNumber and workTool.cp.hasSpecializationDrivingLine and not workTool.manualDrivingLine then
			setLaneNumber = true;
		end;
		if self.cp.mode == 10 then
			local x,y,z = getWorldTranslation(workTool.rootNode)  
			local _,_,tz = worldToLocal(self.cp.directionNode,x,y,z)
			if tz > 0 then
				isFrontAttached = true
			end
		end
		if workTool.cp.hasSpecializationTrailer then
			tailerCount = tailerCount + 1
			if tailerCount > 1 then
				isReversePossible = false
			end
		end

		-- TODO: this must be moved to the AIDriver somewhere, has nothing to do here...
		if workTool.spec_sprayer ~= nil and self.cp.hasFertilizerSowingMachine then
			workTool.fertilizerEnabled = self.cp.settings.sowingMachineFertilizerEnabled:is(true)
		end	
		
		if workTool.cp.isSugarCaneAugerWagon then
			isReversePossible = false
		end
		
	end;
	self.cp.isReversePossible = isReversePossible
	self.cp.mode10.levelerIsFrontAttached = isFrontAttached
		
	local numWaitPoints = 0
	local numUnloadPoints = 0
	local numCrossingPoints = 0
	self.cp.waitPoints = {};
	self.cp.unloadPoints = {};
	self.cp.workDistance = 0
	self.cp.mediumWpDistance = 0
	self.cp.mode10.alphaList = {}

	-- modes 4/6 without start and stop point, set them at start and end, for only-on-field-courses
	if (self.cp.mode == 4 or self.cp.mode == 6) then
		if numWaitPoints == 0 or self.cp.startWork == nil then
			self.cp.startWork = 1;
		end;
		if numWaitPoints == 0 or self.cp.stopWork == nil then
			self.cp.stopWork = self.cp.numWaypoints;
		end;
	end;
	self.cp.numWaitPoints = numWaitPoints;
	self.cp.numUnloadPoints = numUnloadPoints;
	self.cp.numCrossingPoints = numCrossingPoints;
	courseplay:debug(string.format("%s: numWaitPoints=%d, waitPoints[1]=%s, numCrossingPoints=%d", nameNum(self), self.cp.numWaitPoints, tostring(self.cp.waitPoints[1]), numCrossingPoints), 12);

	-- set waitTime to 0 if necessary
	if not courseplay:getCanHaveWaitTime(self) and self.cp.waitTime > 0 then
		courseplay:changeWaitTime(self, -self.cp.waitTime);
	end;

	if self.cp.waypointIndex > 2 and self.cp.mode ~= 4 and self.cp.mode ~= 6 and self.cp.mode ~= 8 then
		courseplay:setDriveUnloadNow(self, true);
	elseif self.cp.mode == 4 or self.cp.mode == 6 then
		courseplay:setDriveUnloadNow(self, false);
		self.cp.hasUnloadingRefillingCourse = self.cp.numWaypoints > self.cp.stopWork + 7;
		self.cp.hasTransferCourse = self.cp.startWork > 5
		if  self.Waypoints[self.cp.stopWork].cx == self.Waypoints[self.cp.startWork].cx 
		and self.Waypoints[self.cp.stopWork].cz == self.Waypoints[self.cp.startWork].cz then -- TODO: VERY unsafe, there could be LUA float problems (e.g. 7 + 8 = 15.000000001)
			self.cp.finishWork = self.cp.stopWork-5
		else
			self.cp.finishWork = self.cp.stopWork
		end

		-- NOTE: if we want to start the course but catch one of the last 5 points ("returnToStartPoint"), make sure we get wp 2
		if self.cp.settings.startingPoint:is(StartingPointSetting.START_AT_NEAREST_POINT) and self.cp.finishWork ~= self.cp.stopWork and self.cp.waypointIndex > self.cp.finishWork and self.cp.waypointIndex <= self.cp.stopWork then
			courseplay:setWaypointIndex(self, 2);
		end
		courseplay:debug(string.format("%s: numWaypoints=%d, stopWork=%d, finishWork=%d, hasUnloadingRefillingCourse=%s,hasTransferCourse=%s, waypointIndex=%d", nameNum(self), self.cp.numWaypoints, self.cp.stopWork, self.cp.finishWork, tostring(self.cp.hasUnloadingRefillingCourse),tostring(self.cp.hasTransferCourse), self.cp.waypointIndex), 12);
	elseif self.cp.mode == 8 then
		courseplay:setDriveUnloadNow(self, false);
	end

	if self.cp.settings.startingPoint:is(StartingPointSetting.START_AT_FIRST_POINT) then
		if self.cp.mode == 2 or self.cp.mode == 3 then
			-- TODO: really? 3?
			courseplay:setWaypointIndex(self, 3);
			courseplay:setDriveUnloadNow(self, true);
		else
			courseplay:setWaypointIndex(self, 1);
		end
	end;

	courseplay:updateAllTriggers();

	self.cp.aiLightsTypesMaskBackup  = self.spec_lights.aiLightsTypesMask
	self.cp.cruiseControlSpeedBackup = self:getCruiseControlSpeed();

	--check Crab Steering mode and set it to default
	if self.crabSteering and (self.crabSteering.state ~= self.crabSteering.aiSteeringModeIndex or self.cp.useCrabSteeringMode ~= nil) then
		local crabSteeringMode = self.cp.useCrabSteeringMode or self.crabSteering.aiSteeringModeIndex;
		self:setCrabSteering(crabSteeringMode);
	end

	-- ok i am near the waypoint, let's go
	self.cp.savedCheckSpeedLimit = self.checkSpeedLimit;
	self.checkSpeedLimit = false
	self.cp.runOnceStartCourse = true;
	self:setIsCourseplayDriving(true);
	courseplay:setIsRecording(self, false);
	self:setCpVar('distanceCheck',false,courseplay.isClient);

	self.cp.totalLength, self.cp.totalLengthOffset = courseplay:getTotalLengthOnWheels(self);

	courseplay:validateCanSwitchMode(self);

	-- Disable crop destruction if 4Real Module 01 - Crop Destruction mod is installed
	if self.cropDestruction then
		courseplay:disableCropDestruction(self);
	end;

	-- and another ugly hack here as when settings.lua setAIDriver() is called the bale loader does not seem to be
	-- attached and I don't have the motivation do dig through the legacy code to find out why
	if self.cp.mode == courseplay.MODE_FIELDWORK then
		self.cp.driver:delete()
		self.cp.driver = UnloadableFieldworkAIDriver.create(self)
	end
	StartStopEvent:sendStartEvent(self)
	self.cp.driver:start(self.cp.settings.startingPoint)
end;

function courseplay:getCanUseCpMode(vehicle)
	-- check engine running state
	if not courseplay:getIsEngineReady(vehicle) then
		return false;
	end;

	local mode = vehicle.cp.mode;

	if (mode == 7 and not vehicle.cp.isCombine and not vehicle.cp.isChopper and not vehicle.cp.isHarvesterSteerable)
	or ((mode == 1 or mode == 2 or mode == 3 or mode == 4 or mode == 8 or mode == 9) and (vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable))
	or ((mode ~= 5) and (vehicle.cp.isWoodHarvester or vehicle.cp.isWoodForwarder)) then
		courseplay:setInfoText(vehicle, 'COURSEPLAY_MODE_NOT_SUPPORTED_FOR_VEHICLETYPE');
		print('Not Supported Vehicle Type')
		return false;
	end;


	if mode ~= 5 and mode ~= 7 and not vehicle.cp.workToolAttached then
		if mode == 4 or mode == 6 then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TOOL');
		elseif mode == 9 then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_SHOVEL_NOT_FOUND');
		elseif mode == 10 then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_MODE10_NOBLADE');
		else
			courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TRAILER');
		end;
		return false;
	end;
	
	if mode == 10 and vehicle.cp.mode10.levelerIsFrontAttached then
		courseplay:setInfoText(vehicle, 'COURSEPLAY_MODE10_NOFRONTBLADE');
		return false;
	end

	local minWait, maxWait, minUnload, maxUnload;

	if (mode == 1 and vehicle.cp.hasAugerWagon) or mode == 3 or mode == 8 or mode == 10 then
		minWait, maxWait = 1, 1;
		if  vehicle.cp.hasWaterTrailer then
			maxWait = 10
		end
		if vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, string.format("COURSEPLAY_WAITING_POINTS_TOO_FEW;%d",minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
			return false;
		end;
		if mode == 3 then
			maxUnload = 0
			if vehicle.cp.workTools[1] == nil or vehicle.cp.workTools[1].cp == nil or not vehicle.cp.workTools[1].cp.isAugerWagon then
				courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TRAILER');
				return false;
			elseif vehicle.cp.numUnloadPoints > maxUnload then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_MANY;%d',maxUnload));
			return false; 
			end;
		elseif mode == 8 then
			if vehicle.cp.workTools[1] == nil then
				courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TRAILER');
				return false;
			end;
		end;
	elseif mode == 7 then
		-- DELETE ME MODE 7 Crap
		minWait, maxWait = 1, 1;
		if vehicle.cp.numUnloadPoints == 0 and vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, string.format("COURSEPLAY_WAITING_POINTS_TOO_FEW;%d",minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
			return false;
		end;
		minUnload, maxUnload = 2, 2;
		if vehicle.cp.numWaitPoints == 0 and vehicle.cp.numUnloadPoints < minUnload then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_FEW;%d',minUnload));
			return false;
		elseif vehicle.cp.numUnloadPoints > maxUnload then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_MANY;%d',maxUnload));
			return false;
		end;
	elseif mode == 4 or mode == 6 then
		if vehicle.cp.startWork == nil or vehicle.cp.stopWork == nil then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_NO_WORK_AREA');
			return false;
		end;
		if mode == 6 then
			maxUnload = 0;
			if vehicle.cp.hasBaleLoader then
				minWait, maxWait = 2, 3;
				if vehicle.cp.numWaitPoints < minWait then
					courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_FEW;%d',minWait));
					return false;
				elseif vehicle.cp.numWaitPoints > maxWait then
					courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
					return false;
				end;																									--TODO: Remove when tippers are supported with 2 unload points
			elseif (vehicle.cp.isCombine or vehicle.cp.isHarvesterSteerable or vehicle.cp.hasHarvesterAttachable) and not vehicle.cp.hasSpecialChopper then
				maxUnload = 2;
			else
				maxUnload = 1;
			end;
			if vehicle.cp.numUnloadPoints > maxUnload then
				courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_MANY;%d',maxUnload));
				return false;
			end;
		end;

	elseif mode == 9 then
		minWait, maxWait = 3, 3;
		if vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_FEW;%d',minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
			return false;
		elseif vehicle.cp.shovelStatePositions == nil or vehicle.cp.shovelStatePositions[2] == nil or vehicle.cp.shovelStatePositions[3] == nil or vehicle.cp.shovelStatePositions[4] == nil or vehicle.cp.shovelStatePositions[5] == nil then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_SHOVEL_POSITIONS_MISSING');
			return false;
		elseif vehicle.cp.shovelFillStartPoint == nil or vehicle.cp.shovelFillEndPoint == nil or vehicle.cp.shovelEmptyPoint == nil then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_NO_VALID_COURSE');
			return false;
		end;
	end;

	return true;
end;

-- stops driving the course
function courseplay:stop(self)
	if g_server == nil then 
		return
	end
	-- Stop AI Driver
	if self.cp.driver then
		self.cp.driver:dismiss()
	end
	

	-- TODO: move this to TrafficCollision.lua
    if self:getAINeedsTrafficCollisionBox() then
        setTranslation(self.spec_aiVehicle.aiTrafficCollision, 0, -1000, 0)
        self.spec_aiVehicle.aiTrafficCollisionRemoveDelay = 200
    end
	--is this one still used ?? 
	if g_currentMission.missionInfo.automaticMotorStartEnabled and self.cp.saveFuel and not self.spec_motorized.isMotorStarted then
		courseplay:setEngineState(self, true);
		self.cp.saveFuel = false;
	end
	if courseplay:getCustomTimerExists(self,'fuelSaveTimer')  then
		--print("reset existing timer")
		courseplay:resetCustomTimer(self,'fuelSaveTimer',true)
	end

	--stop special tools
	for _, tool in pairs (self.cp.workTools) do
		--  vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload, ridgeMarker,forceSpeedLimit)
		courseplay:handleSpecialTools(self, tool, false,   false,  false,   false, false, nil,nil,0);
		if tool.cp.originalCapacities then
			for index,fillUnit in pairs(tool:getFillUnits()) do
				fillUnit.capacity =  tool.cp.originalCapacities[index]
			end
			tool.cp.originalCapacities = nil
		end
		if tool.fertilizerEnabled ~= nil then
			tool.fertilizerEnabled = nil
		end
	end
	if self.cp.directionNodeToTurnNodeLength ~= nil then
		self.cp.directionNodeToTurnNodeLength = nil
	end

	self.cp.lastInfoText = nil

	--mode10 restore original compactingScales
	if self.cp.mode10.OrigCompactScale ~= nil then
		self.bunkerSiloCompactingScale = self.cp.mode10.OrigCompactScale 
		self.cp.mode10.OrigCompactScale = nil
	end
	
	
	-- Enable crop destruction if 4Real Module 01 - Crop Destruction mod is installed
	if self.cropDestruction then
		courseplay:enableCropDestruction(self);
	end;


	if self.cp.cruiseControlSpeedBackup then
		self.spec_drivable.cruiseControl.speed = self.cp.cruiseControlSpeedBackup; -- NOTE JT: no need to use setter or event function - Drivable's update() checks for changes in the var and calls the event itself
		self.cp.cruiseControlSpeedBackup = nil;
	end; 

	self.spec_lights.aiLightsTypesMask = self.cp.aiLightsTypesMaskBackup
	
	if self.cp.takeOverSteering then
		self.cp.takeOverSteering = false
	end

	courseplay:removeFromVehicleLocalIgnoreList(vehicle, self.cp.activeCombine)
	courseplay:removeFromVehicleLocalIgnoreList(vehicle, self.cp.lastActiveCombine)
	self.cp.BunkerSiloMap = nil
	self.cp.mode9TargetSilo = nil
	self.cp.mode10.lowestAlpha = 99
	
	
	self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
	self.spec_drivable.cruiseControl.minSpeed = 1
	self.cp.settings.forcedToStop:set(false)
	self.cp.waitingForTrailerToUnload = false
	courseplay:setIsRecording(self, false);
	courseplay:setRecordingIsPaused(self, false);
	self.cp.isTurning = nil;
	courseplay:clearTurnTargets(self);
	self.cp.aiTurnNoBackward = false
	self.cp.noStopOnEdge = false
	self.cp.fillTrigger = nil;
	self.cp.factoryScriptTrigger = nil;
	self.cp.tipperLoadMode = 0;
	self.cp.hasMachineToFill = false;
	self.cp.unloadOrder = false
	self.cp.isUnloadingStopped = false
	self.cp.TrafficBrake = false
	self.cp.inTraffic = false
	-- deactivate beacon and hazard lights
	if self.beaconLightsActive then
		self:setBeaconLightsVisibility(false);
	end;
	if self.spec_lights.turnLightState and self.spec_lights.turnLightState ~= Lights.TURNLIGHT_OFF then
		self:setTurnLightState(Lights.TURNLIGHT_OFF);
	end;

	-- resetting variables
	self.checkSpeedLimit = self.cp.savedCheckSpeedLimit;
	courseplay:resetTipTrigger(self);
	self:setIsCourseplayDriving(false);
	self:setCpVar('canDrive',true,courseplay.isClient)
	self:setCpVar('distanceCheck',false,courseplay.isClient);
	if self.cp.checkReverseValdityPrinted then
		self.cp.checkReverseValdityPrinted = false

	end
	self.cp.lastMode8UnloadTriggerId = nil

	self.cp.curSpeed = 0;

	self.spec_motorized.motor.maxRpmOverride = nil;
	self.cp.heapStart = nil
	self.cp.heapStop = nil
	self.cp.startWork = nil
	self.cp.stopWork = nil
	self.cp.hasFinishedWork = nil
	self.cp.turnTimeRecorded = nil;	
	self.cp.hasUnloadingRefillingCourse = false;
	self.cp.hasTransferCourse = false
	self.cp.settings.stopAtEnd:set(false)
	self.cp.stopAtEndMode1 = false;
	self.cp.isTipping = false;
	self.cp.isUnloaded = false;
	self.cp.prevFillLevelPct = nil;
	self.cp.isInRepairTrigger = nil;
	self.cp.curMapWeightStation = nil;
	courseplay:setSlippingStage(self, 0);
	courseplay:resetCustomTimer(self, 'slippingStage1');
	courseplay:resetCustomTimer(self, 'slippingStage2');

	courseplay:resetCustomTimer(self, 'foldBaleLoader', true);

	self.cp.hasBaleLoader = false;
	self.cp.hasPlow = false;
	self.cp.rotateablePlow = nil;
	self.cp.hasSowingMachine = false;
	self.cp.hasSprayer = false;

	if self.cp.manualWorkWidth ~= nil then
		courseplay:changeWorkWidth(self, nil, self.cp.manualWorkWidth, true)
		if self.cp.hud.currentPage == courseplay.hud.PAGE_COURSE_GENERATION then
			courseplay.hud:setReloadPageOrder(self, self.cp.hud.currentPage, true);
		end
	end
	
	self.cp.totalLength, self.cp.totalLengthOffset = 0, 0;
	self.cp.numWorkTools = 0;

	self.cp.movingToolsPrimary, self.cp.movingToolsSecondary = nil, nil;
	self.cp.attachedFrontLoader = nil

	courseplay:deleteFixedWorldPosition(self);

	--remove any local and global info texts
	if g_server ~= nil then
		courseplay:setInfoText(self, nil);

		for refIdx,_ in pairs(CpManager.globalInfoText.msgReference) do
			if self.cp.activeGlobalInfoTexts[refIdx] ~= nil then
				CpManager:setGlobalInfoText(self, refIdx, true);
			end;
		end;
	end
	
	
	--validation: can switch mode?
	courseplay:validateCanSwitchMode(self);
	StartStopEvent:sendStopEvent(self)
	-- reactivate load/add/delete course buttons
	--courseplay.buttons:setActiveEnabled(self, 'page2');
end


function courseplay:findVehicleHeights(transformId, x, y, z, distance)
	local startHeight = math.max(self.sizeLength,5)
	local height = startHeight - distance
	local vehicle = false
	--print(string.format("found %s (%s)",tostring(getName(transformId)),tostring(transformId)))
	-- if self.cp.aiTrafficCollisionTrigger == transformId then
	if self.aiTrafficCollisionTrigger == transformId then	
		if self.cp.HeightsFoundColli < height then
			self.cp.HeightsFoundColli = height
		end
	elseif transformId == self.rootNode then
		vehicle = true
	elseif getParent(transformId) == self.rootNode and self.aiTrafficCollisionTrigger ~= transformId then
		vehicle = true
	elseif self.cpTrafficCollisionIgnoreList[transformId] or self.cpTrafficCollisionIgnoreList[getParent(transformId)] then
		vehicle = true
	end

	if vehicle and self.cp.HeightsFound < height then
		self.cp.HeightsFound = height
	end

	return true
end

function courseplay:safeSetWaypointIndex( vehicle, newIx )
	for i = newIx, newIx do
		-- don't set it too close to a turn start, 
		if vehicle.Waypoints[ i ] ~= nil and vehicle.Waypoints[ i ].turnStart then
			-- set it to after the turn
			newIx = i + 2
			break
		end	
	end

	if vehicle.cp.waypointIndex > vehicle.cp.numWaypoints then
		courseplay:setWaypointIndex(vehicle, 1);
	else
		courseplay:setWaypointIndex( vehicle, newIx );
	end
end

-- do not remove this comment
-- vim: set noexpandtab:
