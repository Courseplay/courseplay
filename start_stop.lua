-- starts driving the course
function courseplay:start(self)
	self.maxnumber = table.getn(self.Waypoints)
	if self.maxnumber < 1 then
		return
	end
	
	--Manual ignition v3.01/3.04 (self-installing)
	if self.setManualIgnitionMode ~= nil and self.ignitionMode ~= nil and self.ignitionMode ~= 2 then
		self:setManualIgnitionMode(2);
		
	--Manual ignition v3.x (in steerable as lua)
	elseif self.ignitionKey ~= nil and self.allowedIgnition ~= nil and not self.isMotorStarted then
		self.ignitionKey = true;
        self.allowedIgnition = true;
    end;
    --END manual ignition
	
	if not self.isMotorStarted then
		self:startMotor(true);
	end
	
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
	end

	self.CPnumCollidingVehicles = 0;
	self.traffic_vehicle_in_front = nil
	--self.numToolsCollidingVehicles = {};
	self.drive = false
	self.record = false
	self.record_pause = false
	self.calculated_course = false

	AITractor.addCollisionTrigger(self, self);

	self.orig_maxnumber = self.maxnumber
	-- set default ai_state if not in mode 2 or 3
	if self.cp.aiMode ~= 2 and self.cp.aiMode ~= 3 then
		self.ai_state = 0
	end

	--TODO: section needed?
	if (self.cp.aiMode == 4 or self.cp.aiMode == 6) and self.tipper_attached then
		local start_anim_time = self.tippers[1].startAnimTime
		if start_anim_time == 1 then
			self.fold_move_direction = 1
		else
			self.fold_move_direction = -1
		end
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
	self.dcheck = true
	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.rootNode);
	-- position of next waypoint
	local cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	-- distance
	local dist = courseplay:distance(ctx, ctz, cx, cz)
	

	for k,workTool in pairs(self.tippers) do    --TODO temporary solution (better would be Tool:getIsAnimationPlaying(animationName))
		if courseplay:isFolding(workTool) then
			if  self.setAIImplementsMoveDown ~= nil then
				self:setAIImplementsMoveDown(true)
			elseif self.setFoldState ~= nil then
				self:setFoldState(-1, true)
			end
		end
	end

	local numWaitPoints = 0
	self.cp.waitPoints = {};
	self.cp.shovelFillStartPoint = nil
	self.cp.shovelFillEndPoint = nil
	self.cp.shovelEmptyPoint = nil
	local nearestpoint = dist
	local recordNumber = 0
	for i,wp in pairs(self.Waypoints) do
		local cx, cz = wp.cx, wp.cz
		if self.ai_state == 0 or self.ai_state == 1 then
			dist = courseplay:distance(ctx, ctz, cx, cz)
			if dist <= nearestpoint then
				nearestpoint = dist
				recordNumber = i
			end;
		end;

		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
			self.cp.waitPoints[numWaitPoints] = i;
		end

		-- specific Workzone
		if self.cp.aiMode == 4 or self.cp.aiMode == 6 or self.cp.aiMode == 7 then
			if numWaitPoints == 1 and (self.cp.startWork == nil or self.cp.startWork == 0) then
				self.cp.startWork = i
			end
			if numWaitPoints > 1 and (self.cp.stopWork == nil or self.cp.stopWork == 0) then
				self.cp.stopWork = i
			end

		--unloading point for transporter
		elseif self.cp.aiMode == 8 then
			--

		--work points for shovel
		elseif self.cp.aiMode == 9 then
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
	end;
	-- mode 6 without start and stop point, set them at start and end, for only-on-field-courses
	if (self.cp.aiMode == 4 or self.cp.aiMode == 6) then
		if numWaitPoints == 0 or self.cp.startWork == nil then
			self.cp.startWork = 1;
		end;
		if numWaitPoints == 0 or self.cp.stopWork == nil then
			self.cp.stopWork = self.maxnumber;
		end;
	end;
	self.cp.numWaitPoints = numWaitPoints;
	courseplay:debug(string.format("%s: numWaitPoints=%d, waitPoints[1]=%s", nameNum(self), self.cp.numWaitPoints, tostring(self.cp.waitPoints[1])), 12);


	if self.ai_state == 0 or self.ai_state == 1 then
		local changed = false
		for i=recordNumber,recordNumber+3 do
			if self.Waypoints[i]~= nil and self.Waypoints[i].turn ~= nil then
				self.recordnumber = i + 2
				changed = true
				break
			end	
		end
		if changed == false then
			self.recordnumber = recordNumber
		end

		if self.recordnumber > self.maxnumber then
			self.recordnumber = 1
		end
	end --END if ai_state == 0

	if self.recordnumber > 2 and self.cp.aiMode ~= 4 and self.cp.aiMode ~= 6 then
		self.loaded = true
	elseif self.cp.aiMode == 4 or self.cp.aiMode == 6 then
		self.loaded = false;
		self.cp.hasUnloadingRefillingCourse = self.maxnumber > self.cp.stopWork + 7;
		courseplay:debug(string.format("%s: maxnumber=%d, stopWork=%d, hasUnloadingRefillingCourse=%s", nameNum(self), self.maxnumber, self.cp.stopWork, tostring(self.cp.hasUnloadingRefillingCourse)), 12);
	end

	if self.cp.aiMode == 9 or self.cp.startAtFirstPoint then
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
	self.runOnceStartCourse = true;
	self.drive = true;
	self.cp.maxFieldSpeed = 0
	self.record = false
	self.dcheck = false
	
	if self.isRealistic then
		self.cpSavedRealAWDModeOn = self.realAWDModeOn
		
	end

	--EifokLiquidManure
	self.cp.EifokLiquidManure.searchMapHoseRefStation.pull = true;
	self.cp.EifokLiquidManure.searchMapHoseRefStation.push = true;

	courseplay:validateCanSwitchMode(self);
end;

function courseplay:getCanUseAiMode(vehicle)
	local mode = vehicle.cp.aiMode;

	if mode ~= 5 and mode ~= 6 and mode ~= 7 and not vehicle.tipper_attached then
		vehicle.cp.infoText = courseplay.locales.CPWrongTrailer;
		return false;
	end;

	if mode == 3 or mode == 7 or mode == 8 then
		if vehicle.cp.numWaitPoints < 1 then
			vehicle.cp.infoText = string.format(courseplay.locales.CPTooFewWaitingPoints, 1);
			return false;
		elseif vehicle.cp.numWaitPoints > 1 then
			vehicle.cp.infoText = string.format(courseplay.locales.CPTooManyWaitingPoints, 1);
			return false;
		end;
		if mode == 3 then
			if vehicle.tippers[1] == nil or vehicle.tippers[1].cp == nil or not vehicle.tippers[1].cp.isAugerWagon then
				vehicle.cp.infoText = courseplay.locales.CPWrongTrailer;
				return false;
			end;
		elseif mode == 7 then
			if vehicle.isAutoCombineActivated ~= nil and vehicle.isAutoCombineActivated then
				vehicle.cp.infoText = courseplay.locales.COURSEPLAY_NO_AUTOCOMBINE_MODE_7;
				return false;
			end;
		end;

	elseif mode == 4 or mode == 6 then
		if vehicle.cp.startWork == nil or vehicle.cp.stopWork == nil then
			vehicle.cp.infoText = courseplay.locales.CPNoWorkArea;
			return false;
		end;

	elseif mode == 9 then
		if vehicle.cp.numWaitPoints < 3 then
			vehicle.cp.infoText = string.format(courseplay.locales.CPTooFewWaitingPoints, 3);
			return false;
		elseif vehicle.cp.numWaitPoints > 3 then
			vehicle.cp.infoText = string.format(courseplay.locales.CPTooManyWaitingPoints, 3);
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
	end
	self.forced_to_stop = false
	self.record = false
	self.record_pause = false
	if self.ai_state > 4 then
		self.ai_state = 1
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
	if self.tipper_attached and self.cp.tipperHasCover and self.cp.aiMode == 1 or self.cp.aiMode == 2 or self.cp.aiMode == 5 or self.cp.aiMode == 6 then
		courseplay:openCloseCover(self, nil, false);
	end;

	-- resetting variables
	courseplay:setMinHudPage(self, nil);
	self.cp.attachedCombineIdx = nil;
	self.cp.tempCollis = {}
	self.checkSpeedLimit = true
	self.cp.currentTipTrigger = nil
	self.drive = false
	self.play = true
	self.dcheck = false
	self.cp.numWaitPoints = 0;
	self.cp.waitPoints = {};
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
	self.unloaded = false
	
	self.cp.hasBaleLoader = false;
	self.cp.hasSowingMachine = false;
	self.cp.hasPlough = false;
	if self.cp.tempToolOffsetX ~= nil then
		self.cp.toolOffsetX = self.cp.tempToolOffsetX 
		self.cp.tempToolOffsetX = nil
	end

	--reset EifokLiquidManure
	courseplay.thirdParty.EifokLiquidManure.resetData(self);

	--remove from activeCoursePlayers
	courseplay:removeFromActiveCoursePlayers(self);

	--validation: can switch ai_mode?
	courseplay:validateCanSwitchMode(self);
end