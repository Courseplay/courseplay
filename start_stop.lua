local curFile = 'start_stop.lua';

-- starts driving the course
function courseplay:start(self)
	self.maxnumber = #(self.Waypoints)
	if self.maxnumber < 1 then
		return
	end

	courseplay:setEngineState(self, true);

	if self.cp.orgRpm == nil then
		self.cp.orgRpm = {}
		self.cp.orgRpm[1] = self.motor.maxRpm[1]
		self.cp.orgRpm[2] = self.motor.maxRpm[2]
		self.cp.orgRpm[3] = self.motor.maxRpm[3]
	end
	if self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] ~= nil then
		self.cp.ESL = {}
		self.cp.ESL[1] = self.ESLimiter.percentage[2]
		self.cp.ESL[2] = self.ESLimiter.percentage[3]
		self.cp.ESL[3] = self.ESLimiter.percentage[4]
	end;
	if self.isRealistic then
		self.cp.mrOrigSpeed = {
			[1] = self.motor.realSpeedLevelsAI[1],
			[2] = self.motor.realSpeedLevelsAI[2],
			[3] = self.motor.realSpeedLevelsAI[3]
		};
	end;

	self.CPnumCollidingVehicles = 0;
	self.cp.collidingVehicleId = nil
	courseplay:debug(string.format("%s: Start/Stop: deleting \"self.cp.collidingVehicleId\"", nameNum(self)), 3);
	--self.numToolsCollidingVehicles = {};
	self.drive = false
	self.cp.isRecording = false
	self.cp.recordingIsPaused = false
	self.cp.calculatedCourseToCombine = false

	AITractor.addCollisionTrigger(self, self);
		
	if self.attachedCutters ~= nil then
		for cutter, implement in pairs(self.attachedCutters) do
			--remove cutter atTrafficCollisionTrigger in case of having changed or removed it while not in CP
			if self.cp.trafficCollisionTriggers[0] ~= nil then
				removeTrigger(self.cp.trafficCollisionTriggers[0])
				self.cp.trafficCollisionTriggerToTriggerIndex[self.cp.trafficCollisionTriggers[0]] = nil
			end	
			--set cutter aiTrafficCollisionTrigger to cp.aiTrafficCollisionTrigger's list
			if cutter.aiTrafficCollisionTrigger ~= nil then
				if cutter.cpTrafficCollisionTrigger == nil then
					cutter.cpTrafficCollisionTrigger = clone(cutter.aiTrafficCollisionTrigger, true);
					self.cp.trafficCollisionTriggers[0] = cutter.cpTrafficCollisionTrigger
				else
					self.cp.trafficCollisionTriggers[0] = cutter.cpTrafficCollisionTrigger
				end
				addTrigger(self.cp.trafficCollisionTriggers[0], 'cpOnTrafficCollisionTrigger', self);
				self.cp.trafficCollisionTriggerToTriggerIndex[self.cp.trafficCollisionTriggers[0]] = 0
				self.cp.collidingObjects[0] = {};
				courseplay:debug(string.format("%s: Start/Stop: cutter.aiTrafficCollisionTrigger present -> adding %s to self.cp.trafficCollisionTriggers[0]",nameNum(self),tostring(self.cp.trafficCollisionTriggers[0])),3)
				--self.cp.numCollidingObjects[0] = 0;
			else
				courseplay:debug(string.format('## Courseplay: %s: aiTrafficCollisionTrigger in cutter missing. Traffic collision prevention will not work!', nameNum(self)),3);
			end
		end
	end	
	

	self.orig_maxnumber = self.maxnumber
	-- set default modeState if not in mode 2 or 3
	if self.cp.mode ~= 2 and self.cp.mode ~= 3 then
		self.cp.modeState = 0
	end

	if self.recordnumber < 1 then
		self.recordnumber = 1
	end

	-- add do working players if not already added
	if self.cp.coursePlayerNum == nil then
		self.cp.coursePlayerNum = courseplay:addToTotalCoursePlayers(self)
	end;
	--add to activeCoursePlayers
	courseplay:addToActiveCoursePlayers(self);

	self.cp.backMarkerOffset = nil
	self.cp.aiFrontMarker = nil

	courseplay:reset_tools(self)
	-- show arrow
	self.cp.distanceCheck = true
	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.rootNode);
	-- position of next waypoint
	local cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	-- distance
	local dist = courseplay:distance(ctx, ctz, cx, cz)
	

	local setLaneNumber = false;
	for k,workTool in pairs(self.tippers) do    --TODO temporary solution (better would be Tool:getIsAnimationPlaying(animationName))
		if courseplay:isFolding(workTool) then
			if  self.setAIImplementsMoveDown ~= nil then
				self:setAIImplementsMoveDown(true)
			elseif self.setFoldState ~= nil then
				self:setFoldState(-1, true)
			end
		end;

		--DrivingLine spec: set lane numbers
		if self.cp.mode == 4 and not setLaneNumber and workTool.cp.hasSpecializationDrivingLine and not workTool.manualDrivingLine then
			setLaneNumber = true;
		end;
	end;


	local numWaitPoints = 0
	local numCrossingPoints = 0
	self.cp.waitPoints = {};
	self.cp.shovelFillStartPoint = nil
	self.cp.shovelFillEndPoint = nil
	self.cp.shovelEmptyPoint = nil
	local nearestpoint = dist
	local recordNumber = 0
	local curLaneNumber = 1;
	-- print(('%s [%s(%d)]: start(), modeState=%d, mode2nextState=%s'):format(nameNum(self), curFile, debug.getinfo(1).currentline, self.cp.modeState, tostring(self.cp.mode2nextState))); -- DEBUG140301
	for i,wp in pairs(self.Waypoints) do
		local cx, cz = wp.cx, wp.cz
		if self.cp.modeState == 0 or self.cp.modeState == 99 then
			dist = courseplay:distance(ctx, ctz, cx, cz)
			if dist <= nearestpoint then
				nearestpoint = dist
				recordNumber = i
			end;
		end;

		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
			self.cp.waitPoints[numWaitPoints] = i;
		end;
		if wp.crossing then
			numCrossingPoints = numCrossingPoints + 1;
			self.cp.crossingPoints[numCrossingPoints] = i;
		end;

		-- specific Workzone
		if self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7 then
			if numWaitPoints == 1 and (self.cp.startWork == nil or self.cp.startWork == 0) then
				self.cp.startWork = i
			end
			if numWaitPoints > 1 and (self.cp.stopWork == nil or self.cp.stopWork == 0) then
				self.cp.stopWork = i
			end

		--unloading point for transporter
		elseif self.cp.mode == 8 then
			--

		--work points for shovel
		elseif self.cp.mode == 9 then
			if numWaitPoints == 1 and self.cp.shovelFillStartPoint == nil then
				self.cp.shovelFillStartPoint = i;
			end;
			if numWaitPoints == 2 and self.cp.shovelFillEndPoint == nil then
				self.cp.shovelFillEndPoint = i;
			end;
			if numWaitPoints == 3 and self.cp.shovelEmptyPoint == nil then
				self.cp.shovelEmptyPoint = i;
			end;
		end;

		-- laneNumber (for seeders)
		if setLaneNumber and wp.generated ~= nil and wp.generated == true then
			if wp.turnEnd ~= nil and wp.turnEnd == true then
				curLaneNumber = curLaneNumber + 1;
				courseplay:debug(string.format('%s: waypoint %d: turnEnd=true -> new curLaneNumber=%d', nameNum(self), i, curLaneNumber), 12);
			end;
			wp.laneNum = curLaneNumber;
		end;
	end;


	-- modes 4/6 without start and stop point, set them at start and end, for only-on-field-courses
	if (self.cp.mode == 4 or self.cp.mode == 6) then
		if numWaitPoints == 0 or self.cp.startWork == nil then
			self.cp.startWork = 1;
		end;
		if numWaitPoints == 0 or self.cp.stopWork == nil then
			self.cp.stopWork = self.maxnumber;
		end;
	end;
	self.cp.numWaitPoints = numWaitPoints;
	self.cp.numCrossingPoints = numCrossingPoints;
	courseplay:debug(string.format("%s: numWaitPoints=%d, waitPoints[1]=%s, numCrossingPoints=%d", nameNum(self), self.cp.numWaitPoints, tostring(self.cp.waitPoints[1]), numCrossingPoints), 12);

	-- Sprayer: set waitTime to 0
	if self.cp.mode == 4 or self.cp.mode == 8 and self.cp.waitTime > 0 then
		courseplay:changeWaitTime(self, -self.cp.waitTime);
	end;


	-- print(('%s [%s(%d)]: start(), modeState=%d, mode2nextState=%s, recordNumber=%d'):format(nameNum(self), curFile, debug.getinfo(1).currentline, self.cp.modeState, tostring(self.cp.mode2nextState), recordNumber)); -- DEBUG140301
	if self.cp.modeState == 0 or self.cp.modeState == 99 then
		local changed = false
		for i=recordNumber,recordNumber+3 do
			if self.Waypoints[i]~= nil and self.Waypoints[i].turn ~= nil then
				self.recordnumber = i + 2
				-- print(('\t(%d) self.recordnumber=%d'):format(debug.getinfo(1).currentline, self.recordnumber)); -- DEBUG140301
				changed = true
				break
			end	
		end
		if changed == false then
			self.recordnumber = recordNumber
			-- print(('\t(%d) self.recordnumber=%d'):format(debug.getinfo(1).currentline, self.recordnumber)); -- DEBUG140301
		end

		if self.recordnumber > self.maxnumber then
			self.recordnumber = 1
		end
	end --END if modeState == 0

	if self.recordnumber > 2 and self.cp.mode ~= 4 and self.cp.mode ~= 6 then
		self.cp.isLoaded = true
		-- print(('%s [%s(%d)]: start(), recordnumber=%d -> set isLoaded to true'):format(nameNum(self), curFile, debug.getinfo(1).currentline, self.recordnumber)); -- DEBUG140301
	elseif self.cp.mode == 4 or self.cp.mode == 6 then
		self.cp.isLoaded = false;
		self.cp.hasUnloadingRefillingCourse = self.maxnumber > self.cp.stopWork + 7;
		if  self.Waypoints[self.cp.stopWork].cx == self.Waypoints[self.cp.startWork].cx 
		and self.Waypoints[self.cp.stopWork].cz == self.Waypoints[self.cp.startWork].cz then
			self.cp.finishWork = self.cp.stopWork-5
		else
			self.cp.finishWork = self.cp.stopWork
		end

		if self.cp.finishWork ~= self.cp.stopWork and self.recordnumber > self.cp.finishWork and self.recordnumber <= self.cp.stopWork then
			self.recordnumber = 2
		end
		courseplay:debug(string.format("%s: maxnumber=%d, stopWork=%d, finishWork=%d, hasUnloadingRefillingCourse=%s, recordnumber=%d", nameNum(self), self.maxnumber, self.cp.stopWork, self.cp.finishWork, tostring(self.cp.hasUnloadingRefillingCourse), self.recordnumber), 12);
	end

	if self.cp.mode == 9 or self.cp.startAtFirstPoint then
		self.recordnumber = 1;
		self.cp.shovelState = 1;
	end;

	courseplay:updateAllTriggers();

	self.forceIsActive = true;
	self.stopMotorOnLeave = false;
	self.steeringEnabled = false;
	self.deactivateOnLeave = false
	self.disableCharacterOnLeave = false
	-- ok i am near the waypoint, let's go
	self.checkSpeedLimit = false
	self.cp.runOnceStartCourse = true;
	self.drive = true;
	self.cp.maxFieldSpeed = 0
	self.cp.isRecording = false
	self.cp.distanceCheck = false;

	
	if self.isRealistic then
		self.cpSavedRealAWDModeOn = self.realAWDModeOn
	end

	--EifokLiquidManure
	self.cp.EifokLiquidManure.searchMapHoseRefStation.pull = true;
	self.cp.EifokLiquidManure.searchMapHoseRefStation.push = true;

	courseplay:validateCanSwitchMode(self);
end;

function courseplay:getCanUseAiMode(vehicle)
	if not vehicle.isMotorStarted or (vehicle.motorStartTime and vehicle.motorStartTime > vehicle.time) then
		return false;
	end;

	local mode = vehicle.cp.mode;

	if mode ~= 5 and mode ~= 6 and mode ~= 7 and not vehicle.cp.tipperAttached then
		vehicle.cp.infoText = courseplay:loc('COURSEPLAY_WRONG_TRAILER');
		return false;
	end;

	if mode == 3 or mode == 7 or mode == 8 then
		if vehicle.cp.numWaitPoints < 1 then
			vehicle.cp.infoText = string.format(courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_FEW'), 1);
			return false;
		elseif vehicle.cp.numWaitPoints > 1 then
			vehicle.cp.infoText = string.format(courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_MANY'), 1);
			return false;
		end;
		if mode == 3 then
			if vehicle.tippers[1] == nil or vehicle.tippers[1].cp == nil or not vehicle.tippers[1].cp.isAugerWagon then
				vehicle.cp.infoText = courseplay:loc('COURSEPLAY_WRONG_TRAILER');
				return false;
			end;
		elseif mode == 7 then
			if vehicle.isAutoCombineActivated ~= nil and vehicle.isAutoCombineActivated then
				vehicle.cp.infoText = courseplay:loc('COURSEPLAY_NO_AUTOCOMBINE_MODE_7');
				return false;
			end;
		end;

	elseif mode == 4 or mode == 6 then
		if vehicle.cp.startWork == nil or vehicle.cp.stopWork == nil then
			vehicle.cp.infoText = courseplay:loc('COURSEPLAY_NO_WORK_AREA');
			return false;
		end;
		if mode == 6 then
			if vehicle.cp.hasBaleLoader then
				if vehicle.cp.numWaitPoints < 2 then
					vehicle.cp.infoText = string.format(courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_FEW'), 2);
					return false;
				elseif vehicle.cp.numWaitPoints > 3 then
					vehicle.cp.infoText = string.format(courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_MANY'), 3);
					return false;
				end;
			end;
		end;

	elseif mode == 9 then
		if vehicle.cp.numWaitPoints < 3 then
			vehicle.cp.infoText = string.format(courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_FEW'), 3);
			return false;
		elseif vehicle.cp.numWaitPoints > 3 then
			vehicle.cp.infoText = string.format(courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_MANY'), 3);
			return false;
		elseif vehicle.cp.shovelStatePositions == nil or vehicle.cp.shovelStatePositions[2] == nil or vehicle.cp.shovelStatePositions[3] == nil or vehicle.cp.shovelStatePositions[4] == nil or vehicle.cp.shovelStatePositions[5] == nil then
			vehicle.cp.infoText = courseplay:loc('COURSEPLAY_SHOVEL_POSITIONS_MISSING');
			return false;
		elseif vehicle.cp.shovelFillStartPoint == nil or vehicle.cp.shovelFillEndPoint == nil or vehicle.cp.shovelEmptyPoint == nil then
			vehicle.cp.infoText = courseplay:loc('COURSEPLAY_NO_VALID_COURSE');
			return false;
		end;
	end;

	return true;
end;

-- stops driving the course
function courseplay:stop(self)
	--self:dismiss()
	self.forceIsActive = false;
	self.stopMotorOnLeave = true;
	self.steeringEnabled = true;
	self.deactivateOnLeave = true
	self.disableCharacterOnLeave = true
	if self.cp.orgRpm then
		self.motor.maxRpm[1] = self.cp.orgRpm[1]
		self.motor.maxRpm[2] = self.cp.orgRpm[2]
		self.motor.maxRpm[3] = self.cp.orgRpm[3]
	end
	if self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] ~= nil then
		self.ESLimiter.percentage[2] =	self.cp.ESL[1]
		self.ESLimiter.percentage[3] =	self.cp.ESL[2]
		self.ESLimiter.percentage[4] =	self.cp.ESL[3]  
	end;
	if self.isRealistic and self.cp.mrOrigSpeed ~= nil then
		self.motor.realSpeedLevelsAI[1] = self.cp.mrOrigSpeed[1];
		self.motor.realSpeedLevelsAI[2] = self.cp.mrOrigSpeed[2];
		self.motor.realSpeedLevelsAI[3] = self.cp.mrOrigSpeed[3];
	end;
	self.cp.forcedToStop = false
	self.cp.isRecording = false
	self.cp.recordingIsPaused = false
	if self.cp.modeState > 4 then
		self.cp.modeState = 1
	end
	self.cp.turnStage = 0
	self.cp.isTurning = nil
	self.aiTractorTargetX = nil
	self.aiTractorTargetZ = nil
	self.aiTractorTargetBeforeTurnX = nil
	self.aiTractorTargetBeforeTurnZ = nil
	self.cp.backMarkerOffset = nil
	self.cp.aiFrontMarker = nil
	self.cp.aiTurnNoBackward = false
	self.cp.noStopOnEdge = false
	if self.isRealistic then
		self.motor.speedLevel = 0 
		self:realSetAwdActive(self.cpSavedRealAWDModeOn)
		if self.realForceAiDriven then
			self.realForceAiDriven = false
		end
	end
	self.cp.fillTrigger = nil
	self.cp.unloadOrder = false
	AITractor.removeCollisionTrigger(self, self);
	self.cpTrafficCollisionIgnoreList = {}
	self.cp.foundColli = {}
	self.cp.inTraffic = false
	self.cp.bypassWaypointsSet = false
	--deactivate beacon lights
	if self.beaconLightsActive then
		self:setBeaconLightsVisibility(false);
	end;

	--open all covers
	if self.cp.tipperAttached and self.cp.tipperHasCover and self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 5 or self.cp.mode == 6 then
		courseplay:openCloseCover(self, nil, false);
	end;

	-- resetting variables
	courseplay:setMinHudPage(self, nil);
	self.cp.attachedCombineIdx = nil;
	self.cp.tempCollis = {}
	self.checkSpeedLimit = true
	self.cp.currentTipTrigger = nil
	self.drive = false
	self.cp.canDrive = true
	self.cp.distanceCheck = false
	self.cp.mode7GoBackBeforeUnloading = false
	if self.cp.checkReverseValdityPrinted then
		self.cp.checkReverseValdityPrinted = false
	end
	
	self.motor:setSpeedLevel(0, false);
	self.motor.maxRpmOverride = nil;
	self.cp.startWork = nil
	self.cp.stopWork = nil
	self.cp.hasUnloadingRefillingCourse = false;
	self.cp.stopAtEnd = false
	self.cp.isUnloaded = false;
	self.cp.prevFillLevelPct = nil;
	self.cp.isInRepairTrigger = nil;

	self.cp.hasBaleLoader = false;
	self.cp.hasSowingMachine = false;
	self.cp.hasPlough = false;
	if self.cp.tempToolOffsetX ~= nil then
		courseplay:changeToolOffsetX(self, nil, self.cp.tempToolOffsetX, true);
		self.cp.tempToolOffsetX = nil
	end;

	self.cp.timers.slippingWheels = 0;

	self.cp.movingToolsPrimary, self.cp.movingToolsSecondary = nil, nil;

	--remove any global info texts
	if g_server ~= nil then
		self.cp.infoText = nil;

		for refIdx,_ in pairs(courseplay.globalInfoText.msgReference) do
			if self.cp.activeGlobalInfoTexts[refIdx] ~= nil then
				courseplay:setGlobalInfoText(self, refIdx, true);
			end;
		end;
	end

	--reset EifokLiquidManure
	courseplay.thirdParty.EifokLiquidManure:resetData(self);

	--remove from activeCoursePlayers
	courseplay:removeFromActiveCoursePlayers(self);

	--validation: can switch ai_mode?
	courseplay:validateCanSwitchMode(self);
end