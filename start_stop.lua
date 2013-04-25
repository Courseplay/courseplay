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
	if self.ai_mode ~= 2 and self.ai_mode ~= 3 then
		self.ai_state = 0
	end

	if (self.ai_mode == 4 or self.ai_mode == 6) and self.tipper_attached then
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
	if self.working_course_player_num == nil then
		self.working_course_player_num = courseplay:add_working_player(self)
	end
	self.cp.backMarkerOffset = nil
	self.cp.aiFrontMarker = nil

	courseplay:reset_tools(self)
	-- show arrow
	self.dcheck = true
	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.rootNode);
	-- positoin of next waypoint
	local cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	-- distance
	dist = courseplay:distance(ctx, ctz, cx, cz)

	if self.ai_state == 0 then
		local nearestpoint = dist
		local wpanz = 0
		-- search nearest Waypoint
		for i = 1, self.maxnumber do
			local cx, cz = self.Waypoints[i].cx, self.Waypoints[i].cz
			local wait = self.Waypoints[i].wait
			dist = courseplay:distance(ctx, ctz, cx, cz)
			if dist < nearestpoint then
				nearestpoint = dist
				if self.Waypoints[i].turn ~= nil then
					self.recordnumber = i + 2
				else 
					self.recordnumber = i + 1
				end
			end
			-- specific Workzone
			if self.ai_mode == 4 or self.ai_mode == 6 or self.ai_mode == 7 then
				if wait then
					wpanz = wpanz + 1
				end

				if wpanz == 1 and self.startWork == nil then
					self.startWork = i
				end
				if wpanz > 1 and self.stopWork == nil then
					self.stopWork = i
				end
			end;
			
			--work points for shovel
			if self.ai_mode == 9 then
				if wait then
					wpanz = wpanz + 1;
				end;
				
				if wpanz == 1 and self.cp.shovelFillStartPoint == nil then
					self.cp.shovelFillStartPoint = i;
				end;
				if wpanz == 2 and self.cp.shovelFillEndPoint == nil then
					self.cp.shovelFillEndPoint = i;
				end;
				if wpanz == 3 and self.cp.shovelEmptyPoint == nil then
					self.cp.shovelEmptyPoint = i;
				end;
			end;
		end
		-- mode 6 without start and stop point, set them at start and end, for only-on-field-courses
		if (self.ai_mode == 4 or self.ai_mode == 6) and wpanz == 0 then
			self.startWork = 1
			self.stopWork = self.maxnumber
		end
		if self.recordnumber > self.maxnumber then
			self.recordnumber = 1
		end
	end

	if self.recordnumber > 2 and self.ai_mode ~= 4 and self.ai_mode ~= 6 then
		self.loaded = true
	elseif self.ai_mode == 4 or self.ai_mode == 6 then
		
		self.loaded = false
	end


	self.forceIsActive = true;
	self.stopMotorOnLeave = false;
	self.steeringEnabled = false;
	self.deactivateOnLeave = false
	self.disableCharacterOnLeave = false
	-- ok i am near the waypoint, let's go
	self.checkSpeedLimit = false
	self.runOnceStartCourse = true;
	self.drive = true;

	self.record = false
	self.dcheck = false
	
	
	--validation: can switch ai_mode?
	courseplay:validateCanSwitchMode(self);
end

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


	AITractor.removeCollisionTrigger(self, self);


	-- removing tippers
	if self.tipper_attached then
		for key, tipper in pairs(self.tippers) do
			specialTool = courseplay:handleSpecialTools(tipper,false,false,false)
			if not specialTool then
				if tipper.setIsTurnedOn ~= nil and tipper.isTurnedOn then
					tipper:setIsTurnedOn(false, false);
				end;
				if tipper.isThreshing then
					tipper:setIsThreshing(false, true);
				end
				if self.isThreshing then
					self:setIsThreshing(false, true);
				end
				if courseplay:isFoldable(tipper) and tipper.setFoldDirection ~= nil then
					if self.ai_mode == 6 or courseplay:is_sowingMachine(tipper) then
						tipper:setFoldDirection(1);
					elseif tipper.turnOnFoldDirection ~= nil and tipper.turnOnFoldDirection ~= 0 then
						tipper:setFoldDirection(-tipper.turnOnFoldDirection);
					else
						tipper:setFoldDirection(-1); --> doesn't work for Kotte VTL (liquidManure)
					end;
				end
				if tipper.needsLowering and tipper.aiNeedsLowering and tipper:isLowered() then
					self:setAIImplementsMoveDown(false);
				end;

				-- TODO AITractor.removeToolTrigger(self, tipper)
				if SpecializationUtil.hasSpecialization(Attachable, tipper.specializations) then
					tipper:aiTurnOff()
				end
			end
		end
		
		--open all covers
		if self.cp.tipperHasCover then
			for i=1, table.getn(self.cp.tippersWithCovers) do
				local tIdx = self.cp.tippersWithCovers[i].tipperIndex;
				local coverItems = self.cp.tippersWithCovers[i].coverItems;
				if coverItems ~= nil then
					for _,ci in pairs(coverItems) do
						if getVisibility(ci) then
							setVisibility(ci, false);
						end;
					end;
				end;
			end;
		end;
	end

	-- reseting variables

	self.checkSpeedLimit = true
	self.currentTipTrigger = nil
	self.drive = false
	self.play = true
	self.dcheck = false

	self.motor:setSpeedLevel(0, false);
	self.motor.maxRpmOverride = nil;
	self.startWork = nil
	self.stopWork = nil
	self.StopEnd = false
	self.unloaded = false

	if g_server ~= nil then
		AIVehicleUtil.driveInDirection(self, 0, self.steering_angle, 0, 0, 28, false, moveForwards, 0, 1)
	end
	
	--validation: can switch ai_mode?
	courseplay:validateCanSwitchMode(self);
end