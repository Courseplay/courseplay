-- drives recored course
function courseplay:drive(self, dt)
	local refSpeed = 0
	local cx,cy,cz = 0,0,0

	-- combine self unloading
	if self.ai_mode == 7 then
		if self.isAIThreshing then
			if (self.grainTankFillLevel * 100 / self.grainTankCapacity) >= self.required_fill_level_for_drive_on then
				self.maxnumber = table.getn(self.Waypoints)
				cx7, cz7 = self.Waypoints[self.maxnumber].cx, self.Waypoints[self.maxnumber].cz
				local lx7, lz7 = AIVehicleUtil.getDriveDirection(self.rootNode, cx7, cty7, cz7);
				local fx,fy,fz = localToWorld(self.rootNode, 0, 0, -3*self.turn_radius)
				if courseplay:is_field(fx, fz) or self.grainTankFillLevel >= self.grainTankCapacity*0.99 then
					self.lastaiThreshingDirectionX = self.aiThreshingDirectionX
					self.lastaiThreshingDirectionZ = self.aiThreshingDirectionZ
					self:stopAIThreshing()
					self.shortest_dist = nil
					self.next_targets = {}
					if lx7 < 0 then
						courseplay:debug("approach from right",1)
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, -(0.34*3*self.turn_radius) , 0, -3*self.turn_radius);
						courseplay:set_next_target(self, (0.34*2*self.turn_radius) , 0);
						courseplay:set_next_target(self, 0 , 3);
					else
						courseplay:debug("approach from left",1)
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, (0.34*3*self.turn_radius) , 0, -3*self.turn_radius);
						courseplay:set_next_target(self, -(0.34*2*self.turn_radius) , 0);
						courseplay:set_next_target(self, 0 ,3);
					end
					courseplay:start(self)
					self.sl = 3
					refSpeed = self.field_speed
					self.recordnumber = 2
				else 
					return
				end
			else
				return
			end
		else
			self.sl = 3
			refSpeed = self.field_speed
		end
		if self.ai_state == 5 then
			local targets = table.getn(self.next_targets)
			local aligned  = false
			local ctx7, cty7, ctz7 = getWorldTranslation(self.rootNode);
			self.info_text = string.format(courseplay:get_locale(self, "CPDriveToWP"), self.target_x, self.target_z)
			cx = self.target_x
			cy = self.target_y
			cz = self.target_z
			if CPDebugLevel > 0 then drawDebugLine(cx, cty7+3, cz, 1, 0, 0, ctx7, cty7+3, ctz7, 1, 0, 0); end
			self.sl = 3
			refSpeed = self.field_speed
			distance_to_wp = courseplay:distance_to_point(self, cx, y, cz)
			local distToChange = 4
			if self.shortest_dist == nil or self.shortest_dist > distance_to_wp then
				self.shortest_dist = distance_to_wp
			end
			if distance_to_wp > self.shortest_dist and distance_to_wp < 6 then
				distToChange = distance_to_wp + 1
			end
			if targets == 2 then 
				self.target_x7 = self.next_targets[2].x
				self.target_y7 = self.next_targets[2].y
				self.target_z7 = self.next_targets[2].z
			elseif targets == 1 then
				if math.abs(self.lastaiThreshingDirectionZ) > 0.1 then
					if math.abs(self.target_x7-ctx7)< 3 then
						aligned = true
						courseplay:debug("aligned",1)
					end
				else
					if math.abs(self.target_z7-ctz7)< 3 then
						aligned = true
						courseplay:debug("aligned",1)
					end
				end
			elseif targets  == 0 then
				if distance_to_wp < 25 then
					self.sl = 3
					refSpeed = self.turn_speed
				end
				if distance_to_wp < 15 then
					self:setIsThreshing(true, true)
				end
				if math.abs(self.lastaiThreshingDirectionX) > 0.1 then
					if math.abs(self.target_x7-ctx7)< 5 then
						aligned = true
						courseplay:debug("aligned",1)
					end
				else
					if math.abs(self.target_z7-ctz7)< 5 then
						aligned = true
						courseplay:debug("aligned",1)
					end
				end
			end
			if distance_to_wp < distToChange or aligned then
				self.shortest_dist = nil
				if targets  > 0 then
					self.target_x = self.next_targets[1].x
					self.target_y = self.next_targets[1].y
					self.target_z = self.next_targets[1].z
					table.remove(self.next_targets, 1)
					self.recordnumber = 2 
				else
					self.ai_state = 0
					if self.lastaiThreshingDirectionX ~= nil then
						self.aiThreshingDirectionX = self.lastaiThreshingDirectionX
						self.aiThreshingDirectionZ = self.lastaiThreshingDirectionZ
						courseplay:debug("restored self.aiThreshingDirection",1)
					end	
					self:startAIThreshing(true)
					courseplay:debug("start AITreshing",1)
					courseplay:debug("fault: "..tostring(math.ceil(math.abs(ctx7-self.target_x7)*100)).." cm X  "..tostring(math.ceil(math.abs(ctz7-self.target_z7)*100)).." cm Z",1)
				end
			end
		end

	end
	-- unregister at combine, if there is one
	if self.loaded == true and courseplay_position ~= nil then
		courseplay:unregister_at_combine(self, self.active_combine)
	end

	-- switch lights on!
	if not self.isControlled then
		-- we want to hear our courseplayers
		setVisibility(self.aiMotorSound, true)
		if g_currentMission.environment.needsLights then
			self:setLightsVisibility(true);
		else
			self:setLightsVisibility(false);
		end;
	end;
	-- actual position
	local ctx, cty, ctz = getWorldTranslation(self.rootNode);
	-- coordinates of next waypoint
	--if self.recordnumber > self.maxnumber then
	-- this should never happen
	--   self.recordnumber = self.maxnumber
	-- end
	local last_recordnumber = nil
	if self.recordnumber > 1 then
		last_recordnumber = self.recordnumber - 1
	else
		last_recordnumber = 1
	end
	if self.recordnumber > self.maxnumber then
		courseplay:debug(string.format("drive %i: %s: self.recordnumber (%s) > self.maxnumber (%s)", debug.getinfo(1).currentline, self.name, tostring(self.recordnumber), tostring(self.maxnumber)), 3); --this should never happen
		self.recordnumber = self.maxnumber
	end
	if self.ai_mode ~= 7 then 
		cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	elseif self.ai_mode == 7 and self.ai_state ~=5 then
		cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	end
	
	if CPDebugLevel > 0 then  drawDebugPoint(cx, cty+3, cz, 1, 0 , 1, 1) end
	-- offset - endlich lohnt sich der mathe-lk von vor 1000 Jahren ;)
	if (self.ai_mode == 4 or self.ai_mode == 6 ) and self.startWork ~= nil and self.stopWork ~=nil and self.WpOffsetX ~= nil and self.WpOffsetZ ~= nil then
		if self.recordnumber > self.startWork and self.recordnumber < self.stopWork and self.recordnumber > 1  and (self.WpOffsetX ~= 0 or self.WpOffsetZ ~= 0) then
			--courseplay:addsign(self, cx, 10, cz)
			--courseplay:debug(string.format("old WP: %d x %d ", cx, cz ), 2)

			-- direction vector
			local vcx, vcz
			if self.recordnumber == 1 then
				vcx = self.Waypoints[2].cx - cx
				vcz = self.Waypoints[2].cz - cz
			else
				if self.Waypoints[last_recordnumber].rev then
					vcx = self.Waypoints[last_recordnumber].cx - cx
					vcz = self.Waypoints[last_recordnumber].cz - cz
				else
					vcx = cx - self.Waypoints[last_recordnumber].cx
					vcz = cz - self.Waypoints[last_recordnumber].cz
				end
			end
			-- length of vector
			local vl = Utils.vector2Length(vcx, vcz)
			-- if not too short: normalize and add offsets
			if vl ~= nil and vl > 0.01 then
				vcx = vcx / vl
				vcz = vcz / vl
				cx = cx - vcz * self.WpOffsetX + vcx * self.WpOffsetZ
				cz = cz + vcx * self.WpOffsetX + vcz * self.WpOffsetZ
			end
		end
		--courseplay:debug(string.format("new WP: %d x %d (angle) %d ", cx, cz, angle ), 2)
		--courseplay:addsign(self, cx, 10, cz)
	end

	if CPDebugLevel > 0 then  drawDebugPoint(cx, cty+3, cz, 0, 1 , 1, 1) end

	self.dist = courseplay:distance(cx, cz, ctx, ctz)
	--courseplay:debug(string.format("Tx: %f2 Tz: %f2 WPcx: %f2 WPcz: %f2 dist: %f2 ", ctx, ctz, cx, cz, self.dist ), 2)
	local fwd = nil
	local distToChange = nil
	local lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, cx, cty, cz);
	
	-- what about our tippers?
	self.cp.tipperFillLevel, self.cp.tipperCapacity = self:getAttachedTrailersFillLevelAndCapacity()
	local fill_level = nil
	if self.cp.tipperFillLevel ~= nil then
		fill_level = self.cp.tipperFillLevel * 100 / self.cp.tipperCapacity
	end
	if self.ai_mode == 4 or self.ai_mode == 6 then
		if  self.Waypoints[self.recordnumber].turn ~= nil then
			self.cp.isTurning = self.Waypoints[self.recordnumber].turn
		end	
	end

	if self.ai_mode == 4 or self.ai_mode == 8 then
		self.implementIsFull = (fill_level ~= nil and fill_level == 100);
	end;
	
	-- may i drive or should i hold position for some reason?
	local allowedToDrive = true
	-- in a traffic yam?

	self.max_speed_level = nil

	-- coordinates of coli
	local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
	-- direction of tractor
	local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1)
	
	--RulModiä
	if self.RulMode == 1 then
		if (self.sl == 3 and not self.beaconLightsActive) or (self.sl ~= 3 and self.beaconLightsActive) or (self.ai_mode == 7 and self.isAIThreshing and self.beaconLightsActive)  then
			self:setBeaconLightsVisibility(not self.beaconLightsActive);
		end
	elseif self.RulMode == 2 then
		if (self.drive and not self.beaconLightsActive) or (not self.drive and self.beaconLightsActive) then
			self:setBeaconLightsVisibility(not self.beaconLightsActive);
		end
	elseif self.RulMode == 3 then
		if self.beaconLightsActive then
			self:setBeaconLightsVisibility(false);
		end
	end


	-- the tipper that is currently loaded/unloaded
	local active_tipper = nil

	if self.Waypoints[last_recordnumber].wait and self.wait then
		if self.waitTimer == nil and self.waitTime > 0 then
			self.waitTimer = self.timer + self.waitTime * 1000
		end
		if self.ai_mode == 3 then
			self.global_info_text = courseplay:get_locale(self, "CPReachedOverloadPoint") --'hat Überladepunkt erreicht.'
			if self.tipper_attached then
				-- drive on if fill_level doesn't change and fill level is < 100-self.required_fill_level_for_follow
				local drive_on = false
				if self.timeout < self.timer or self.last_fill_level == nil then
					if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level < 100 - self.required_fill_level_for_follow then
						drive_on = true
					end
					self.last_fill_level = fill_level
					courseplay:set_timeout(self, 7000)
				end

				if fill_level == 0 or drive_on then
					self.wait = false
					self.last_fill_level = nil
					self.unloaded = true
				end
			end
		elseif self.ai_mode == 4 then
			if last_recordnumber == self.startWork and fill_level ~= 0 then
				self.wait = false
			elseif last_recordnumber == self.stopWork and self.abortWork ~= nil then
				self.wait = false
			elseif last_recordnumber == self.stopWork and self.abortWork == nil then
				self.global_info_text = courseplay:get_locale(self, "CPWorkEnd") --'hat Arbeit beendet.'
			else
				if fill_level == 100 or drive_on then
					self.wait = false
				end
				self.info_text = string.format(courseplay:get_locale(self, "CPloading"), self.cp.tipperFillLevel, self.cp.tipperCapacity)
			end
		elseif self.ai_mode == 6 then
			if last_recordnumber == self.startWork then
				self.wait = false
			elseif last_recordnumber == self.stopWork and self.abortWork ~= nil then
				self.wait = false
			elseif last_recordnumber == self.stopWork and self.abortWork == nil then
				self.global_info_text = courseplay:get_locale(self, "CPWorkEnd") --'hat Arbeit beendet.'
			elseif last_recordnumber ~= self.startWork and last_recordnumber ~= self.stopWork then 
				self.global_info_text = courseplay:get_locale(self, "CPUnloadBale") -- "Ballen werden entladen"
				if fill_level == 0 or drive_on then
					self.wait = false
				end;
			end;
		elseif self.ai_mode == 7 then
			if last_recordnumber == self.startWork then
				if self.grainTankFillLevel > 0 then
					self:setPipeState(2)
					self.global_info_text = courseplay:get_locale(self, "CPReachedOverloadPoint") --'hat Überladepunkt erreicht.'
				else
					self.wait = false
					self.unloaded = true
				end
			end
		elseif self.ai_mode == 8 then
			self.global_info_text = courseplay:get_locale(self, "CPReachedOverloadPoint") --'hat Überladepunkt erreicht.'
			if self.tipper_attached then
				-- drive on if fill_level doesn't change and fill level is < 100-self.required_fill_level_for_follow
				courseplay:handle_mode8(self)
				local drive_on = false
				if self.timeout < self.timer or self.last_fill_level == nil then
					if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level < 100 - self.required_fill_level_for_follow then
						drive_on = true
					end
					self.last_fill_level = fill_level
					courseplay:set_timeout(self, 7000)
				end
				if fill_level == 0 or drive_on then
					self.wait = false
					self.last_fill_level = nil
					self.unloaded = true
				end
			end
		elseif self.ai_mode == 9 then
			self.wait = false;
		else
			self.global_info_text = courseplay:get_locale(self, "CPReachedWaitPoint")
		end
		-- wait untli a specific time
		if self.waitTimer and self.timer > self.waitTimer then
			self.waitTimer = nil
			self.wait = false
		end
		allowedToDrive = false
	else -- ende wartepunkt
		-- abfahrer-mode
		if (self.ai_mode == 1 and self.tipper_attached and self.cp.tipperFillLevel ~= nil and self.tipRefOffset ~= nil) or (self.loaded and self.ai_mode == 2 and self.tipRefOffset ~= nil) then
			-- is there a tipTrigger within 10 meters?
			raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
			if self.tipRefOffset ~= 0 then
				if self.currentTipTrigger == nil then
					raycastAll(tx+self.tipRefOffset, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				end
				if self.currentTipTrigger == nil then
					raycastAll(tx-self.tipRefOffset, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				end
			end
			-- handle mode
			allowedToDrive  = courseplay:handle_mode1(self)
		end
		-- combi-mode
		if (((self.ai_mode == 2 or self.ai_mode == 3) and self.recordnumber < 2) or self.active_combine) and self.tipper_attached then
			return courseplay:handle_mode2(self, dt)
		elseif self.ai_mode ~= 7 then
			self.ai_state = 0
		end
		-- Fertilice loading --only for one Implement !
		if self.ai_mode == 4 then
			if self.tipper_attached and self.startWork ~= nil and self.stopWork ~= nil then
				if self.tippers ~= nil then
					allowedToDrive = courseplay:refillSprayer(self, fill_level, 100, allowedToDrive);
				end
			end
		elseif self.ai_mode == 4 and (self.startWork == nil or self.stopWork == nil) then
			allowedToDrive = false
			self.info_text = courseplay.locales.CPNoWorkArea
		end

		if self.ai_mode ~= 5 and self.ai_mode ~= 6 and self.ai_mode ~= 7 and not self.tipper_attached then
			self.info_text = courseplay.locales.CPWrongTrailer
			allowedToDrive = false
		end

		if self.ai_mode == 7 then
			if self.recordnumber == self.maxnumber then
				if self.target_x ~= nil then
	 				self.ai_state = 5
					self.recordnumber = 2				
					courseplay:debug("347:  ai_state = 5",1)
				else
					allowedToDrive = false
					--TODO local text no aithreshing
				end
			end
			local pipeState = self:getCombineTrailerInRangePipeState();
			if pipeState > 0 then
				self:setPipeState(pipeState);
			else
				self:setPipeState(1);
			end;
		end;

		if self.ai_mode == 8 then
			if self.tipper_attached then
				if self.tippers ~= nil then
					allowedToDrive = courseplay:refillSprayer(self, fill_level, Utils.getNoNil(self.required_fill_level_for_drive_on, 100), allowedToDrive);
				end;
			end;
		end;

		if self.fuelCapacity > 0 then
			local currentFuelPercentage = (self.fuelFillLevel / self.fuelCapacity + 0.0001) * 100;
			if currentFuelPercentage < 5 then
				allowedToDrive = false;
				self.global_info_text = courseplay.locales.CPNoFuelStop;
			elseif currentFuelPercentage < 20 and not self.isFuelFilling then
				self.global_info_text = courseplay.locales.CPFuelWarning;
				if self.fuelFillTriggers[1] then
					allowedToDrive = false;
					self:setIsFuelFilling(true, self.fuelFillTriggers[1].isEnabled, false);
				end
			elseif self.isFuelFilling and currentFuelPercentage < 99.9 then
				allowedToDrive = false;
				self.global_info_text = courseplay.locales.CPRefueling;
			end;
		end;

		if self.showWaterWarning then
			allowedToDrive = false
			self.global_info_text = courseplay.locales.CPWaterDrive
		end

		if self.StopEnd and (self.recordnumber == self.maxnumber or self.currentTipTrigger ~= nil) then
			allowedToDrive = false
			self.global_info_text = courseplay.locales.CPReachedEndPoint
		end
	end

	-- ai_mode 4 = fertilize
	local workArea = false
	local workSpeed = 0;

	if self.ai_mode == 4 and self.tipper_attached and self.startWork ~= nil and self.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed = courseplay:handle_mode4(self, allowedToDrive, workArea, workSpeed, fill_level, last_recordnumber)
	end

	


	-- Mode 6 Fieldwork for balers and foragewagon
	if self.ai_mode == 6 and self.startWork ~= nil and self.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed, active_tipper = courseplay:handle_mode6(self, allowedToDrive, workArea, workSpeed, fill_level, last_recordnumber, lx , lz )
		if not workArea and self.grainTankCapacity == nil and self.tipRefOffset ~= nil then
			-- is there a tipTrigger within 10 meters?
			raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
			if self.tipRefOffset ~= 0 then
				if self.currentTipTrigger == nil then
					raycastAll(tx+self.tipRefOffset, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				end
				if self.currentTipTrigger == nil then
					raycastAll(tx-self.tipRefOffset, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				end
			end
		end;
	end
	if self.ai_mode == 9 then
		allowedToDrive = courseplay:handle_mode9(self, last_recordnumber, fill_level, allowedToDrive, dt);
	end;

	
	local dx,_,dz = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);
	local length = Utils.vector2Length(dx,dz);
	if self.cp.turnStage == 0 then
		self.aiTractorDirectionX = dx/length;
		self.aiTractorDirectionZ = dz/length;
	end

	--Open/close cover
	courseplay:openCloseCover(self);

	allowedToDrive = courseplay:check_traffic(self, true, allowedToDrive)
	
	if self.cp.waitForTurnTime > self.timer then
		allowedToDrive = false
	end 

	-- stop or hold position
	if not allowedToDrive then
		--self.motor:setSpeedLevel(0, false);
		AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, nil, nil)
		if g_server ~= nil then
			AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0.5, 0.5, 28, false, moveForwards, 0, 1)
		end

		-- unload active tipper if given
		return;
	end
	if self.cp.isTurning ~= nil then
		courseplay:turn(self, dt);
		return
	end


	-- which speed?
	local slowEnd = self.ai_mode == 2 and self.recordnumber > self.maxnumber - 3;
	local slowStart_lvl2 = (self.ai_mode == 2 or self.ai_mode == 3) and self.recordnumber < 3;
	local slowStartEnd = self.ai_mode ~= 2 and self.ai_mode ~= 3 and self.ai_mode ~= 4 and self.ai_mode ~= 6 and self.ai_mode ~= 9 and (self.recordnumber > self.maxnumber - 3 or self.recordnumber < 3)
	local slowDownWP = false
	local slowDownRev = false
	local real_speed = self.lastSpeedReal
	local maxRpm = self.motor.maxRpm[self.sl]

	if self.recordnumber < (self.maxnumber - 3) then
		slowDownWP = (self.Waypoints[self.recordnumber + 2].wait or self.Waypoints[self.recordnumber + 1].wait or self.Waypoints[self.recordnumber].wait) --if mode4 or 6: last 3 points before stop or before start
		slowDownRev = (self.Waypoints[self.recordnumber + 2].rev or self.Waypoints[self.recordnumber + 1].rev or self.Waypoints[self.recordnumber].rev)
	else
		slowDownWP = self.Waypoints[self.recordnumber].wait;
		slowDownRev = self.Waypoints[self.recordnumber].rev;
	end

	if self.ai_mode ~= 7 then
		if (workSpeed ~= nil and workSpeed == 0.5) or ((slowDownWP and not workArea) or slowDownRev or self.max_speed_level == 1 or slowStartEnd or slowEnd) then
			self.sl = 1
			refSpeed = self.turn_speed
		elseif (workSpeed ~= nil and workSpeed == 1) or slowStart_lvl2 then
			self.sl = 2
			refSpeed = self.field_speed
		else
			self.sl = 3
			refSpeed = self.max_speed
		end
	elseif slowDownWP then
		self.sl = 1
		refSpeed = self.turn_speed
	end
	if self.ai_mode == 9 then
		slowDownWP = false
	end
	
	if self.Waypoints[self.recordnumber].speed ~= nil and self.use_speed and self.recordnumber > 3 then
		refSpeed = math.max(self.Waypoints[self.recordnumber].speed,3/3600)
	end

	if slowDownRev and refSpeed > self.turn_speed then
		refSpeed = self.turn_speed
	end


	self.cpTrafficBrake = false
	if self.traffic_vehicle_in_front ~= nil then
		local vehicle_in_front = g_currentMission.nodeToVehicle[self.traffic_vehicle_in_front];
		local vehicleBehind = false
		if vehicle_in_front == nil then
			self.traffic_vehicle_in_front = nil
			self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles-1, 0);
			return
		end
		local x, y, z = getWorldTranslation(self.traffic_vehicle_in_front)
		local x1, y1, z1 = worldToLocal(self.rootNode, x, y, z)
		if z1 < 0 or math.abs(x1) > 4 then -- vehicle behind tractor
			vehicleBehind = true
		end
		if vehicle_in_front.rootNode == nil or vehicle_in_front.lastSpeedReal == nil or (vehicle_in_front.rootNode ~= nil and courseplay:distance_to_object(self, vehicle_in_front) > 40) or vehicleBehind then
			self.traffic_vehicle_in_front = nil
		else
			if allowedToDrive then 
				if (self.lastSpeed*3600) - (vehicle_in_front.lastSpeedReal*3600) > 15 then
					self.cpTrafficBrake = true
				else
					refSpeed = math.min(vehicle_in_front.lastSpeedReal,refSpeed)
				end
			end
		end
	end

	--bunkerSilo speed by Thomas Gärtner
	if self.currentTipTrigger ~= nil then
		if self.currentTipTrigger.bunkerSilo ~= nil then
			if self.unload_speed ~= nil then
				refSpeed = self.unload_speed;
			else
				refSpeed = 6 / 3600;
			end;
		else
			refSpeed = 9 / 3600;
		end
	else
		if self.runonce ~= nil then
			self.runonce = nil;
		end
	end


	-- Speed Control
	
	courseplay:setSpeed(self, refSpeed, self.sl)
		
	if self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] == nil then
		self.info_text = courseplay:get_locale(self, "CPWrongESLversion")
	end

	-- where to drive?
	if self.Waypoints[self.recordnumber].rev then
		lz = lz * -1
		lx = lx * -1
		fwd = false
	else
		fwd = true
	end

	if self.cpTrafficBrake then
		fwd = false
	end  	

	-- go, go, go!
	if self.recordnumber == 1 or self.recordnumber == self.maxnumber - 1 or self.Waypoints[self.recordnumber].turn then
		distToChange = 0.5
	elseif self.recordnumber + 1 <= self.maxnumber then
		local beforeReverse = (self.Waypoints[self.recordnumber + 1].rev and (self.Waypoints[self.recordnumber].rev == false))
		local afterReverse = (not self.Waypoints[self.recordnumber + 1].rev and self.Waypoints[last_recordnumber].rev)
		if (self.Waypoints[self.recordnumber].wait or beforeReverse) and self.Waypoints[self.recordnumber].rev == false then -- or afterReverse or self.recordnumber == 1
			distToChange = 1
		elseif (self.Waypoints[self.recordnumber].rev and self.Waypoints[self.recordnumber].wait) or afterReverse then
			distToChange = 2
		elseif self.Waypoints[self.recordnumber].rev then
			distToChange = 2;  --1
		elseif self.ai_mode == 4 or self.ai_mode == 6 or self.ai_mode == 7 then
			distToChange = 5;
		elseif self.ai_mode == 9 then
			distToChange = 4;
		else
			distToChange = 2.85; --orig: 5
		end;
	else
		distToChange = 2.85; --orig: 5
	end

	-- record shortest distance to the next waypoint
	if self.shortest_dist == nil or self.shortest_dist > self.dist then
		self.shortest_dist = self.dist
	end

	if beforeReverse then
		self.shortest_dist = nil
	end

	-- if distance grows i must be circling
	if self.dist > self.shortest_dist and self.recordnumber > 3 and self.dist < 15 and self.Waypoints[self.recordnumber].rev ~= true then
		distToChange = self.dist + 1
	end

	if self.dist > distToChange then
		if g_server ~= nil then
			AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0.5, 0.5, 8, true, fwd, lx, lz, self.sl, 0.5);
			courseplay:set_traffc_collision(self, lx, lz)
		end
	else
		-- reset distance to waypoint
		self.shortest_dist = nil
		if self.recordnumber < self.maxnumber then -- = New
			if not self.wait then
				self.wait = true
			end
			if self.ai_mode == 7 and self.ai_state == 5 then
			else
				self.recordnumber = self.recordnumber + 1
			end
			-- ignore reverse Waypoints for mode 6
			local in_work_area = false
			if self.startWork ~= nil and self.stopWork ~= nil and self.recordnumber >= self.startWork and self.recordnumber <= self.stopWork then
				in_work_area = true
			end
			while self.ai_mode == 6 and self.recordnumber < self.maxnumber and in_work_area and self.Waypoints[self.recordnumber].rev do
				self.recordnumber = self.recordnumber + 1
			end
		else -- reset some variables
			self.recordnumber = 1
			self.unloaded = false
			self.StopEnd = false
			self.loaded = false
			self.record = false
			self.play = true
		end
	end
end


function courseplay:set_traffc_collision(self, lx, lz)
	local maxlx = 0.5; --math.sin(maxAngle); --sin30°  old was : 0.7071067 sin 45°
	local colDirX = lx;
	local colDirZ = lz;
	if colDirX > maxlx then
		colDirX = maxlx;
	elseif colDirX < -maxlx then
		colDirX = -maxlx;
	end;
	if colDirZ < -0.4 then
		colDirZ = 0.4;
	end;
	--courseplay:debug(string.format("colDirX: %f colDirZ %f ",colDirX,colDirZ ), 2)

	if CPDebugLevel > 0 then	
		local x,y,z = getWorldTranslation(self.aiTrafficCollisionTrigger)
		local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger, colDirX*5, 0, colDirZ*5 )
		local x2,y2,z2 = localToWorld(self.aiTrafficCollisionTrigger, (colDirX*5)+ 1.5 , 0, colDirZ*5 )
		local x3,y3,z3 = localToWorld(self.aiTrafficCollisionTrigger, (colDirX*5)-1.5 , 0, colDirZ*5 )
		drawDebugPoint(x2, y, z2, 1, 1, 0, 1);
		drawDebugPoint(x3, y, z3, 1, 1, 0, 1);
		drawDebugLine(x, y, z, 1, 0, 0, x1, y, z1, 1, 0, 0);
	end;

	if self.aiTrafficCollisionTrigger ~= nil and g_server ~= nil then
		AIVehicleUtil.setCollisionDirection(self.cp.DirectionNode, self.aiTrafficCollisionTrigger, colDirX, colDirZ);
	end
end


function courseplay:check_traffic(self, display_warnings, allowedToDrive)
	local in_traffic = false;
	local ahead = false
	local vehicle_in_front = g_currentMission.nodeToVehicle[self.traffic_vehicle_in_front]
	local x, y, z = getWorldTranslation(self.cp.DirectionNode)
	local x1, y1, z1 = 0,0,0
	
	--courseplay:debug(table.show(self), 4)
	if self.CPnumCollidingVehicles ~= nil and self.CPnumCollidingVehicles > 0 then
		if vehicle_in_front ~= nil then
			x1, y1, z1 = worldToLocal(self.traffic_vehicle_in_front, x, y, z)
			if z1 > 0 then -- tractor in front of vehicle face2face 
				ahead = true
			end
			if vehicle_in_front.lastSpeedReal == nil or vehicle_in_front.lastSpeedReal*3600 < 5 or ahead then
				--courseplay:debug("colliding", 2)
				allowedToDrive = false;
				in_traffic = true
			end
		end
	end

	if display_warnings and in_traffic then
		self.global_info_text = courseplay:get_locale(self, "CPInTraffic") --' steckt im Verkehr fest'
	end

	return allowedToDrive
end

function courseplay:setSpeed(self, refSpeed, sl)
	if self.lastSpeedSave ~= self.lastSpeedReal*3600 then		
		if refSpeed*3600 == 1 then
			refSpeed = 1.6 / 3600
		end
		local trueRpm = self.motor.lastMotorRpm*100/self.cp.orgRpm[3]
		local targetRpm = self.motor.maxRpm[sl]*100/self.cp.orgRpm[3]	
		local newLimit = 0
		local oldLimit = 0 
		if self.ESLimiter ~= nil then 
			oldLimit =  self.ESLimiter.percentage[sl+1]
		else
			oldLimit = targetRpm
		end

		if refSpeed*3600 - self.lastSpeed*3600 > 15 then
			if sl == 2 then
				newLimit = 75
			else
				newLimit = 100
			end
		elseif refSpeed*3600 - self.lastSpeed*3600 > 4 then
			newLimit = oldLimit + 1
		elseif refSpeed*3600 - self.lastSpeed*3600 > 0.5 then
			newLimit = oldLimit + 0.1
		elseif refSpeed*3600 - self.lastSpeed*3600 > 0 then	
			newLimit = oldLimit
		end
		if oldLimit - trueRpm > 10 then
			if refSpeed*3600 - self.lastSpeed*3600 < 1 then
				newLimit = trueRpm
			
			end
		end
		if self.lastSpeed*3600 - refSpeed*3600 > 8 then
			if sl == 1 then
				newLimit = 20
			else			
				newLimit = oldLimit - 3
			end
		elseif self.lastSpeed*3600 - refSpeed*3600 > 3 then
			newLimit = oldLimit -1
		elseif self.lastSpeed*3600 - refSpeed*3600 > 1 then
			newLimit = oldLimit -0.75
		elseif self.lastSpeed*3600 - refSpeed*3600 > 0.5 then
			newLimit = oldLimit -0.25
		elseif self.lastSpeed*3600 - refSpeed*3600 > 0 then
			newLimit = oldLimit
		end
		
		if newLimit > 100 then
			newLimit = 100
		elseif newLimit < 0 then
			newLimit = 0
		end

		if self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] ~= nil then
			self:setNewLimit(sl+1, newLimit , false, true)
		elseif self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] == nil then
			--ESlimiter < V3
		else
			local maxRpm = newLimit * self.cp.orgRpm[3]/100
			
			-- don't drive faster/slower than you can!
			if maxRpm > self.cp.orgRpm[3] then
				maxRpm = self.cp.orgRpm[3]
			elseif maxRpm < self.motor.minRpm then
				maxRpm = self.motor.minRpm
			end
			self.motor.maxRpm[sl]= maxRpm
		end



		self.lastSpeedSave = self.lastSpeedReal*3600
	end
end;

function courseplay:openCloseCover(self)
	--courseplay:debug("self.cp.tipperHasCover = " .. tostring(self.cp.tipperHasCover), 3);
	if self.cp.tipperHasCover then
		for i=1, table.getn(self.cp.tippersWithCovers) do
			local tIdx = self.cp.tippersWithCovers[i].tipperIndex;
			local tipper = self.tippers[tIdx];
			local coverItems = self.cp.tippersWithCovers[i].coverItems;
			
			--INFO: setPlane(true) = open / setPlane(false) = closed
			if self.ai_mode == 1 or self.ai_mode == 2 or self.ai_mode == 5 then
				local minCoverWaypoint = 3;
				if self.ai_mode == 2 then
					minCoverWaypoint = 2;
				end;
				
				--close
				if self.recordnumber >= minCoverWaypoint and self.recordnumber < self.maxnumber and self.currentTipTrigger == nil then
					if tipper.plane ~= nil and tipper.plane.bOpen ~= nil and tipper.plane.bOpen then
						tipper:setPlane(false);
					elseif tipper.planeOpen ~= nil and tipper.planeOpen then
						tipper:setAnimationTime(3, tipper.animationParts[3].offSet, false);
					elseif coverItems ~= nil then
						for _,ci in pairs(coverItems) do
							if not getVisibility(ci) then
								setVisibility(ci, true);
							end;
						end;
					end;

				--open
				elseif ((self.recordnumber == nil or (self.recordnumber ~= nil and (self.recordnumber == 1 or self.recordnumber == self.maxnumber))) or self.currentTipTrigger ~= nil) then
					if tipper.plane ~= nil and tipper.plane.bOpen ~= nil and not tipper.plane.bOpen then
						tipper:setPlane(true);
					elseif tipper.planeOpen ~= nil and not tipper.planeOpen then
						tipper:setAnimationTime(3, tipper.animationParts[3].animDuration, false);
					elseif coverItems ~= nil then
						for _,ci in pairs(coverItems) do
							if getVisibility(ci) then
								setVisibility(ci, false);
							end;
						end;
					end;
				end;
			elseif self.ai_mode == 6 then
				if not workArea and self.currentTipTrigger == nil then
					if tipper.plane ~= nil and tipper.plane.bOpen ~= nil and tipper.plane.bOpen then
						tipper:setPlane(false);
					end;
					if coverItems ~= nil then
						for _,ci in pairs(coverItems) do
							if not getVisibility(ci) then
								setVisibility(ci, true);
							end;
						end;
					end;
				elseif (workArea or self.currentTipTriger ~= nil) then
					if tipper.plane ~= nil and tipper.plane.bOpen ~= nil and not tipper.plane.bOpen then
						tipper:setPlane(true);
					end;
					if coverItems ~= nil then
						for _,ci in pairs(coverItems) do
							if getVisibility(ci) then
								setVisibility(ci, false);
							end;
						end;
					end;
				end;
			end;
		end; --END for i in self.cp.tippersWithCovers
	end;
end;

function courseplay:refillSprayer(self, fill_level, driveOn, allowedToDrive)
	for i = 1, table.getn(self.tippers) do
		local activeTool = self.tippers[i];
		
		if courseplay:isSprayer(activeTool) then --sprayer
			local activeToolFillLevel = nil;
			if activeTool.fillLevel ~= nil and activeTool.capacity ~= nil then
				activeToolFillLevel = (activeTool.fillLevel / activeTool.capacity) * 100;
			end;
			local canRefill = (activeToolFillLevel ~= nil and activeToolFillLevel < driveOn) and (activeTool.sprayerFillTriggers ~= nil and table.getn(activeTool.sprayerFillTriggers) > 0);

			--ManureLager: activeTool.ReFillTrigger has to be nil so it doesn't refill
			if self.ai_mode == 8 then
				canRefill = canRefill and activeTool.ReFillTrigger == nil;
				--TODO: what to do when transfering from one ManureLager to another?
			end;
			local isFuchsFass = activeTool.isFuchsFass and activeTool.setdeckelAnimationisPlaying ~= nil; --Fuchs Guellefass
			
		
			if canRefill then
				allowedToDrive = false;
				
				if isFuchsFass then
					activeTool:setdeckelAnimationisPlaying(true);
				end;
				
				self.info_text = string.format(courseplay:get_locale(self, "CPloading"), self.cp.tipperFillLevel, self.cp.tipperCapacity);
				local sprayer = activeTool.sprayerFillTriggers[1];
				activeTool:setIsSprayerFilling(true, false);
				
				if sprayer.trailerInTrigger == activeTool then --Feldrand-Container Guellebomber
					sprayer.fill = true;
				end;
			else
				activeTool:setIsSprayerFilling(false, false);

				if isFuchsFass then
					activeTool:setdeckelAnimationisPlaying(false);
				end;
			end;
		elseif courseplay:is_sowingMachine(activeTool) then --sowing machine
			if fill_level < driveOn and activeTool.sowingMachineFillTriggers[1] ~= nil then
				activeTool:setIsSowingMachineFilling(true, activeTool.sowingMachineFillTriggers[1].isEnabled, false);
				allowedToDrive = false;
			end;
			
			--[[TODO: needed?
			if activeTool.fillLevel == activeTool.capacity then
				allowedToDrive = true;
			end;
			--]]
		end;
	end;
	
	return allowedToDrive;
end;