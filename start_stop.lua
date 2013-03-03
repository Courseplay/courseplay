-- starts driving the course
function courseplay:start(self)
	self.maxnumber = table.getn(self.Waypoints)
	if self.maxnumber < 1 then
		return
	end
	
	if self.setManualIgnitionMode ~= nil then
	  self:setManualIgnitionMode(2)
	end
	
	
	 --Manual ignition
    if self.ignitionKey ~= nil and self.allowedIgnition ~= nil and self.invokeIgnition ~= nil and not self.isMotorStarted then
        courseplay:debug(string.format("%s: has manualIgnition, isMotorStarted==%s, ignitionKey=%s, allowedIgnition=%s, starting motor [self:invokeIgnition(true)]", self.name, tostring(self.isMotorStarted), tostring(self.ignitionKey), tostring(self.allowedIgnition)),3);
		self.ignitionKey = true;
        self.allowedIgnition = true;
    end;
    --END manual ignition
	

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
				self.recordnumber = i + 1
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
			end
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

	self.orgRpm = {}
	self.orgRpm[1] = self.motor.maxRpm[1]
	self.orgRpm[2] = self.motor.maxRpm[2]
	self.orgRpm[3] = self.motor.maxRpm[3]
	self.record = false
	self.dcheck = false
end

-- stops driving the course
function courseplay:stop(self)
	--self:dismiss()
	self.forceIsActive = false;
	self.stopMotorOnLeave = true;
	self.steeringEnabled = true;
	self.deactivateOnLeave = true
	self.disableCharacterOnLeave = true
	if self.orgRpm then
		self.motor.maxRpm[1] = self.orgRpm[1]
		self.motor.maxRpm[2] = self.orgRpm[2]
		self.motor.maxRpm[3] = self.orgRpm[3]
	end
	self.record = false
	self.record_pause = false
	if self.ai_state > 4 then
		self.ai_state = 1
	end

	AITractor.removeCollisionTrigger(self, self);


	-- removing tippers
	if self.tipper_attached then
		for key, tipper in pairs(self.tippers) do
			-- TODO AITractor.removeToolTrigger(self, tipper)
			if SpecializationUtil.hasSpecialization(Attachable, tipper.specializations) then
				tipper:aiTurnOff()
			end
		end
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
end