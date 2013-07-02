-- drives recored course
function courseplay:drive(self, dt)
	if g_server == nil then
		return
	end

	local refSpeed = 0
	local cx,cy,cz = 0,0,0
	-- may i drive or should i hold position for some reason?
	local allowedToDrive = true
	-- combine self unloading
	if self.ai_mode == 7 then
		if self.isAIThreshing then
			if (self.grainTankFillLevel * 100 / self.grainTankCapacity) >= self.required_fill_level_for_drive_on then
				self.maxnumber = table.getn(self.Waypoints)
				cx7, cz7 = self.Waypoints[self.maxnumber].cx, self.Waypoints[self.maxnumber].cz
				local lx7, lz7 = AIVehicleUtil.getDriveDirection(self.rootNode, cx7, cty7, cz7);
				local fx,fy,fz = localToWorld(self.rootNode, 0, 0, -3*self.turn_radius)
				local x7,y7,z7 = localToWorld(self.rootNode, 0, 0, -15)
				self.cp.mode7tx7 = x7
				self.cp.mode7ty7 = y7
				self.cp.mode7tz7 = z7
				if courseplay:is_field(fx, fz) or self.grainTankFillLevel >= self.grainTankCapacity*0.99 then
					self.lastaiThreshingDirectionX = self.aiThreshingDirectionX
					self.lastaiThreshingDirectionZ = self.aiThreshingDirectionZ
					self:stopAIThreshing()
					self.shortest_dist = nil
					self.next_targets = {}
					if lx7 < 0 then
						courseplay:debug(nameNum(self) .. ": approach from right", 11);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, -(0.34*3*self.turn_radius) , 0, -3*self.turn_radius);
						courseplay:set_next_target(self, (0.34*2*self.turn_radius) , 0);
						courseplay:set_next_target(self, 0 , 3);
					else
						courseplay:debug(nameNum(self) .. ": approach from left", 11);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, (0.34*3*self.turn_radius) , 0, -3*self.turn_radius);
						courseplay:set_next_target(self, -(0.34*2*self.turn_radius) , 0);
						courseplay:set_next_target(self, 0 ,3);
					end
					self.cp.mode7Unloading = true
					self.cp.mode7GoBackBeforeUnloading = true
					courseplay:start(self)
					self.sl = 3
					refSpeed = self.field_speed
				else 
					return
				end
			else
				return
			end
		elseif self.cp.mode7Unloading then
			self.sl = 3
			refSpeed = self.field_speed
			if self.cp.mode7GoBackBeforeUnloading then
				local dist = courseplay:distance_to_point(self, self.cp.mode7tx7,self.cp.mode7ty7,self.cp.mode7tz7)
				if  dist  < 1 then
					self.cp.mode7GoBackBeforeUnloading = false
					self.recordnumber = 2
				end
			end
		else
			allowedToDrive = false
			courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPWorkEnd"), 1);
		end
		if self.ai_state == 5 then
			local targets = table.getn(self.next_targets)
			local aligned  = false
			local ctx7, cty7, ctz7 = getWorldTranslation(self.rootNode);
			self.cp.infoText = string.format(courseplay:get_locale(self, "CPDriveToWP"), self.target_x, self.target_z)
			cx = self.target_x
			cy = self.target_y
			cz = self.target_z

			if courseplay.debugChannels[11] then 
				drawDebugLine(cx, cty7+3, cz, 1, 0, 0, ctx7, cty7+3, ctz7, 1, 0, 0); 
			end;

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
						courseplay:debug(nameNum(self) .. ": aligned", 11);
					end
				else
					if math.abs(self.target_z7-ctz7)< 3 then
						aligned = true
						courseplay:debug(nameNum(self) .. ": aligned", 11);
					end
				end
			elseif targets  == 0 then
				if distance_to_wp < 25 then
					self.sl = 3
					refSpeed = self.turn_speed
				end
				if distance_to_wp < 15 then
					self:setIsThreshing(true)
				end
				if math.abs(self.lastaiThreshingDirectionX) > 0.1 then
					if math.abs(self.target_x7-ctx7)< 5 then
						aligned = true
						courseplay:debug(nameNum(self) .. ": aligned", 11);
					end
				else
					if math.abs(self.target_z7-ctz7)< 5 then
						aligned = true
						courseplay:debug(nameNum(self) .. ": aligned", 11);
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
						courseplay:debug(nameNum(self) .. ": restored self.aiThreshingDirection", 11);
					end	
					self:startAIThreshing(true)
					self.cp.mode7Unloading = false
					courseplay:debug(nameNum(self) .. ": start AITreshing", 11);
					courseplay:debug(nameNum(self) .. ": fault: "..tostring(math.ceil(math.abs(ctx7-self.target_x7)*100)).." cm X  "..tostring(math.ceil(math.abs(ctz7-self.target_z7)*100)).." cm Z", 11);
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
		if g_currentMission.environment.needsLights or (g_currentMission.environment.lastRainScale > 0.1 and g_currentMission.environment.timeSinceLastRain < 30) then
			self:setLightsVisibility(true);
		else
			self:setLightsVisibility(false);
		end;
	end;

	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.rootNode);
	-- coordinates of next waypoint
	--if self.recordnumber > self.maxnumber then
	-- this should never happen
	--   self.recordnumber = self.maxnumber
	-- end
	
	if self.recordnumber > 1 then
		self.cp.last_recordnumber = self.recordnumber - 1
	else
		self.cp.last_recordnumber = 1
	end
	if self.recordnumber > self.maxnumber then
		courseplay:debug(string.format("drive %i: %s: self.recordnumber (%s) > self.maxnumber (%s)", debug.getinfo(1).currentline, self.name, tostring(self.recordnumber), tostring(self.maxnumber)), 12); --this should never happen
		self.recordnumber = self.maxnumber
	end
	if self.ai_mode ~= 7 then 
		cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	elseif self.ai_mode == 7 and self.ai_state ~=5 then
		if not self.cp.mode7GoBackBeforeUnloading then
			cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
		else
			cx,cz = self.cp.mode7tx7, self.cp.mode7tz7
		end
	end

	if courseplay.debugChannels[12] then
		drawDebugPoint(cx, cty+3, cz, 1, 0 , 1, 1);
	end;

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
				if self.Waypoints[self.cp.last_recordnumber].rev then
					vcx = self.Waypoints[self.cp.last_recordnumber].cx - cx
					vcz = self.Waypoints[self.cp.last_recordnumber].cz - cz
				else
					vcx = cx - self.Waypoints[self.cp.last_recordnumber].cx
					vcz = cz - self.Waypoints[self.cp.last_recordnumber].cz
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

	if courseplay.debugChannels[12] then
		drawDebugPoint(cx, cty+3, cz, 0, 1 , 1, 1);
	end;

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
		if self.abortWork ~= nil and fill_level == 0 then
			self.cp.isTurning = nil
		end
	end

	if self.ai_mode == 4 or self.ai_mode == 8 then
		self.implementIsFull = (fill_level ~= nil and fill_level == 100);
	end;
	
	-- in a traffic yam?

	self.max_speed_level = nil

	-- coordinates of coli
	local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
	-- direction of tractor
	local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, 0, lz)
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

	--### WAITING POINTS - START
	if self.Waypoints[self.cp.last_recordnumber].wait and self.wait then
		if self.waitTimer == nil and self.waitTime > 0 then
			self.waitTimer = self.timer + self.waitTime * 1000
		end
		if self.ai_mode == 3 then
			courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPReachedOverloadPoint"));
			if self.tipper_attached then
				-- drive on if fill_level doesn't change and fill level is < self.required_fill_level_for_follow
				local drive_on = false
				if self.timeout < self.timer or self.last_fill_level == nil then
					if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level < self.required_fill_level_for_follow then
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
			local drive_on = false
			if self.cp.last_recordnumber == self.startWork and fill_level ~= 0 then
				self.wait = false
			elseif self.cp.last_recordnumber == self.stopWork and self.abortWork ~= nil then
				self.wait = false
			elseif self.cp.last_recordnumber == self.stopWork and self.abortWork == nil then
				courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPWorkEnd"), 1);
			else
				if self.timeout < self.timer or self.last_fill_level == nil then
					if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level > self.required_fill_level_for_drive_on then
						drive_on = true
					end
					self.last_fill_level = fill_level
					courseplay:set_timeout(self, 7000)
				end

				if fill_level == 100 or drive_on then
					self.wait = false
				end
				self.cp.infoText = string.format(courseplay:get_locale(self, "CPloading"), self.cp.tipperFillLevel, self.cp.tipperCapacity)
			end
		elseif self.ai_mode == 6 then
			if self.cp.last_recordnumber == self.startWork then
				self.wait = false
			elseif self.cp.last_recordnumber == self.stopWork and self.abortWork ~= nil then
				self.wait = false
			elseif self.cp.last_recordnumber == self.stopWork and self.abortWork == nil then
				courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPWorkEnd"), 1);
			elseif self.cp.last_recordnumber ~= self.startWork and self.cp.last_recordnumber ~= self.stopWork then 
				courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPUnloadBale"));
				if fill_level == 0 or drive_on then
					self.wait = false
				end;
			end;
		elseif self.ai_mode == 7 then
			if self.cp.last_recordnumber == self.startWork then
				if self.grainTankFillLevel > 0 then
					self:setPipeState(2)
					courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPReachedOverloadPoint"));
				else
					self.wait = false
					self.unloaded = true
				end
			end
		elseif self.ai_mode == 8 then
			courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPReachedOverloadPoint"));
			if self.tipper_attached then
				-- drive on if fill_level doesn't change and fill level is < 100-self.required_fill_level_for_follow
				courseplay:handle_mode8(self)
				local drive_on = false
				if self.timeout < self.timer or self.last_fill_level == nil then
					if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level < self.required_fill_level_for_follow then
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
			courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPReachedWaitPoint"));
		end
		-- wait untli a specific time
		if self.waitTimer and self.timer > self.waitTimer then
			self.waitTimer = nil
			self.wait = false
		end
		allowedToDrive = false
	--### WAITING POINTS - END

	else -- ende wartepunkt
		-- abfahrer-mode
		if (self.ai_mode == 1 or (self.ai_mode == 2 and self.loaded)) and self.cp.tipperFillLevel ~= nil and self.tipRefOffset ~= nil and self.tipper_attached then
			if self.cp.currentTipTrigger == nil and self.cp.tipperFillLevel > 0 then
				-- is there a tipTrigger within 10 meters?
				courseplay:debug(nameNum(self) .. ": call 1st raycast", 1);
				local num = raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				if num > 0 then 
					courseplay:debug(string.format("%s: drive(%d): 1st raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
				end;
				if courseplay.debugChannels[1] then
					drawDebugLine(tx, ty, tz, 1, 0, 0, tx+(nx*10), ty+(ny*10), tz+(nz*10), 1, 0, 0);
				end;
				if self.tipRefOffset ~= 0 then
					if self.cp.currentTipTrigger == nil then
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,self.tipRefOffset,0,0)
						courseplay:debug(nameNum(self) .. ": call 2nd raycast", 1);
						num = raycastAll(x1,y1,z1, nx, ny, nz, "findTipTriggerCallback", 10, self)
						if num > 0 then 
							courseplay:debug(string.format("%s: drive(%d): 2nd raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
						end;
						if courseplay.debugChannels[1] then
							drawDebugLine(x1,y1,z1, 1, 0, 0, x1+(nx*10), y1+(ny*10), z1+(nz*10), 1, 0, 0);
						end;
					end
					if self.cp.currentTipTrigger == nil then
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,-self.tipRefOffset,0,0)
						courseplay:debug(nameNum(self) .. ": call 3rd raycast", 1);
						num = raycastAll(x1,y1,z1, nx, ny, nz, "findTipTriggerCallback", 10, self)
						if num > 0 then 
							courseplay:debug(string.format("%s: drive(%d): 3rd raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
						end;
						if courseplay.debugChannels[1] then
							drawDebugLine(x1,y1,z1, 1, 0, 0, x1+(nx*10), y1+(ny*10), z1+(nz*10), 1, 0, 0); 
						end;
					end
				end
			end;

			-- handle mode
			allowedToDrive = courseplay:handle_mode1(self);
		end;

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
			self.cp.infoText = courseplay.locales.CPNoWorkArea
		end

		if self.ai_mode ~= 5 and self.ai_mode ~= 6 and self.ai_mode ~= 7 and not self.tipper_attached then
			self.cp.infoText = courseplay.locales.CPWrongTrailer
			allowedToDrive = false
		end

		if self.ai_mode == 7 then
			if self.recordnumber == self.maxnumber then
				if self.target_x ~= nil then
	 				self.ai_state = 5
					self.recordnumber = 2
					courseplay:debug(nameNum(self) .. ": " .. tostring(debug.getinfo(1).currentline) .. ": ai_state = 5", 11);
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
					allowedToDrive = courseplay:refillSprayer(self, fill_level, 100, allowedToDrive);
				end;
			end;
		end;

		if self.fuelCapacity > 0 then
			local currentFuelPercentage = (self.fuelFillLevel / self.fuelCapacity + 0.0001) * 100;
			if currentFuelPercentage < 5 then
				allowedToDrive = false;
				courseplay:setGlobalInfoText(self, courseplay:get_locale(self, courseplay.locales.CPNoFuelStop), -2);
			elseif currentFuelPercentage < 20 and not self.isFuelFilling then
				courseplay:setGlobalInfoText(self, courseplay:get_locale(self, courseplay.locales.CPFuelWarning), -1);
				if self.fuelFillTriggers[1] then
					allowedToDrive = courseplay:brakeToStop(self);
					self:setIsFuelFilling(true, self.fuelFillTriggers[1].isEnabled, false);
				end
			elseif self.isFuelFilling and currentFuelPercentage < 99.9 then
				allowedToDrive = courseplay:brakeToStop(self);
				courseplay:setGlobalInfoText(self, courseplay:get_locale(self, courseplay.locales.CPRefueling));
			end;
		end;

		if self.showWaterWarning then
			allowedToDrive = false
			courseplay:setGlobalInfoText(self, courseplay:get_locale(self, courseplay.locales.CPWaterDrive), -2);
		end

		if self.StopEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil) then
			allowedToDrive = false
			courseplay:setGlobalInfoText(self, courseplay:get_locale(self, courseplay.locales.CPReachedEndPoint));
		end
	end

	-- ai_mode 4 = fertilize
	local workArea = false
	local workSpeed = 0;

	if self.ai_mode == 4 and self.tipper_attached and self.startWork ~= nil and self.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed = courseplay:handle_mode4(self, allowedToDrive, workArea, workSpeed, fill_level)
	end

	


	-- Mode 6 Fieldwork for balers and foragewagon
	if self.ai_mode == 6 and self.startWork ~= nil and self.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed, active_tipper = courseplay:handle_mode6(self, allowedToDrive, workArea, workSpeed, fill_level, lx , lz )
		if not workArea and self.grainTankCapacity == nil and self.tipRefOffset ~= nil then
			if self.cp.currentTipTrigger == nil and self.cp.tipperFillLevel > 0 then
				-- is there a tipTrigger within 10 meters?
				courseplay:debug(nameNum(self) .. ": call 1st raycast", 1);
				local num = raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				if num > 0 then
					courseplay:debug(string.format("%s: drive(%d): 1st raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
				end;
				if courseplay.debugChannels[1] then
					drawDebugLine(tx, ty, tz, 1, 0, 0, tx+(nx*10), ty+(ny*10), tz+(nz*10), 1, 0, 0);
				end;

				if self.tipRefOffset ~= 0 then
					if self.cp.currentTipTrigger == nil then
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,self.tipRefOffset,0,0)
						courseplay:debug(nameNum(self) .. ": call 2nd raycast", 1);
						num = raycastAll(x1,y1,z1, nx, ny, nz, "findTipTriggerCallback", 10, self)
						if num > 0 then
							courseplay:debug(string.format("%s: drive(%d): 2nd raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
						end;
						if courseplay.debugChannels[1] then
							drawDebugLine(x1,y1,z1, 1, 0, 0, x1+(nx*10), y1+(ny*10), z1+(nz*10), 1, 0, 0);
						end;
					end
					if self.cp.currentTipTrigger == nil then
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,-self.tipRefOffset,0,0)
						courseplay:debug(nameNum(self) .. ": call 3rd raycast", 1);
						num = raycastAll(x1,y1,z1, nx, ny, nz, "findTipTriggerCallback", 10, self)
						if num > 0 then
							courseplay:debug(string.format("%s: drive(%d): 3rd raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
						end;
						if courseplay.debugChannels[1] then
							drawDebugLine(x1,y1,z1, 1, 0, 0, x1+(nx*10), y1+(ny*10), z1+(nz*10), 1, 0, 0);
						end;
					end
				end
			end;
		end;
	end
	if self.ai_mode == 9 then
		allowedToDrive = courseplay:handle_mode9(self, fill_level, allowedToDrive, dt);
	end;

	
	local dx,_,dz = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);
	local length = Utils.vector2Length(dx,dz);
	if self.cp.turnStage == 0 then
		self.aiTractorDirectionX = dx/length;
		self.aiTractorDirectionZ = dz/length;
	end

	--Open/close cover
	if self.cp.tipperHasCover and self.ai_mode == 1 or self.ai_mode == 2 or self.ai_mode == 5 or self.ai_mode == 6 then
		local showCover = false;

		if self.ai_mode ~= 6 then
			local minCoverWaypoint = 3;
			if self.ai_mode == 1 then
				minCoverWaypoint = 4;
			end;

			if self.recordnumber >= minCoverWaypoint and self.recordnumber < self.maxnumber and self.cp.currentTipTrigger == nil then
				showCover = true;
			elseif (self.recordnumber == nil or (self.recordnumber ~= nil and (self.recordnumber == 1 or self.recordnumber == self.maxnumber))) or self.cp.currentTipTrigger ~= nil then
				showCover = false;
			end;
		else
			showCover = not workArea and self.cp.currentTipTrigger == nil;
		end;

		courseplay:openCloseCover(self, dt, showCover);
	end;

	allowedToDrive = courseplay:check_traffic(self, true, allowedToDrive)
	
	if self.cp.waitForTurnTime > self.timer then
		allowedToDrive = courseplay:brakeToStop(self)
	end 

	local WpUnload = false
	if self.cp.shovelEmptyPoint ~= nil and self.recordnumber >=3  then
		WpUnload = self.recordnumber == self.cp.shovelEmptyPoint
	end
	
	if WpUnload then
		local i = self.cp.shovelEmptyPoint
		local x,y,z = getWorldTranslation(self.rootNode)
		local _,_,ez = worldToLocal(self.rootNode, self.Waypoints[i].cx , y , self.Waypoints[i].cz)
		if  ez < 0 then
			allowedToDrive = false
		end
	end
	
	local WpLoadEnd = false
	if self.cp.shovelFillEndPoint ~= nil and self.recordnumber >=3  then
		WpLoadEnd = self.recordnumber == self.cp.shovelFillEndPoint
	end
	if WpLoadEnd then
		local i = self.cp.shovelFillEndPoint
		local x,y,z = getWorldTranslation(self.rootNode)
		local _,_,ez = worldToLocal(self.rootNode, self.Waypoints[i].cx , y , self.Waypoints[i].cz)
		if  ez < 0.2 then
			if fill_level == 0 then
				allowedToDrive = false
				courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPWorkEnd"), 1);
			else
				self.loaded = true;
				self.recordnumber = i + 2
			end
		end
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

	if self.cpTrafficBrake and self.lastSpeedReal < 1/3600 then
		self.cpTrafficBrake = false
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
	
	if self.Waypoints[self.recordnumber].speed ~= nil and self.use_speed and self.recordnumber > 3 then
		refSpeed = math.max(self.Waypoints[self.recordnumber].speed, 3/3600)
	end

	if slowDownRev and refSpeed > self.turn_speed then
		refSpeed = self.turn_speed
	end

	refSpeed = courseplay:regulateTrafficSpeed(self,refSpeed,allowedToDrive)

	--bunkerSilo speed by Thomas Gärtner
	if self.cp.currentTipTrigger ~= nil then
		if self.cp.currentTipTrigger.bunkerSilo ~= nil then
			refSpeed = Utils.getNoNil(self.unload_speed, 3/3600);
		else
			refSpeed = 9 / 3600;
		end
	else
		if self.runonce ~= nil then
			self.runonce = nil;
		end
	end


	-- Speed Control
	if self.cp.maxFieldSpeed ~= 0 then
		refSpeed = self.cp.maxFieldSpeed
	end

	courseplay:setSpeed(self, refSpeed, self.sl)

	if self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] == nil then
		self.cp.infoText = courseplay:get_locale(self, "CPWrongESLversion")
	end

	-- where to drive?
	if courseplay:isWheelloader(self) then
		local lx2 ,lz2  = AIVehicleUtil.getDriveDirection(self.rootNode, cx, cty, cz); 
		if math.abs(self.steeringLastRotation) < 0.5 then
			lx = lx2
			lz = lz2
		end
	end



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

	if self.cp.mode7GoBackBeforeUnloading then
		fwd = false
		lz = lz * -1
		lx = lx * -1
	end

	-- go, go, go!
	if self.recordnumber == 1 or self.recordnumber == self.maxnumber - 1 or self.Waypoints[self.recordnumber].turn then
		distToChange = 0.5
	elseif self.recordnumber + 1 <= self.maxnumber then
		local beforeReverse = (self.Waypoints[self.recordnumber + 1].rev and (self.Waypoints[self.recordnumber].rev == false))
		local afterReverse = (not self.Waypoints[self.recordnumber + 1].rev and self.Waypoints[self.cp.last_recordnumber].rev)
		if (self.Waypoints[self.recordnumber].wait or beforeReverse) and self.Waypoints[self.recordnumber].rev == false then -- or afterReverse or self.recordnumber == 1
			distToChange = 1
		elseif (self.Waypoints[self.recordnumber].rev and self.Waypoints[self.recordnumber].wait) or afterReverse then
			distToChange = 2
		elseif self.Waypoints[self.recordnumber].rev then
			distToChange = 2; --1
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
	
	if self.cp.isKasi ~= nil then 
		distToChange = distToChange * self.cp.isKasi
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

	if self.dist > distToChange or WpUnload or WpLoadEnd then
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
	--courseplay:debug(string.format("colDirX: %f colDirZ %f ",colDirX,colDirZ ), 3)

	if courseplay.debugChannels[3] then
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
	
	--courseplay:debug(tableShow(self, nameNum(self), 4), 4)
	if self.CPnumCollidingVehicles ~= nil and self.CPnumCollidingVehicles > 0 then
		if vehicle_in_front ~= nil and not (self.ai_mode == 9 and vehicle_in_front.allowFillFromAir) then
			x1,z1 = AIVehicleUtil.getDriveDirection(self.traffic_vehicle_in_front, x, y, z);
			if z1 > -0.9 then -- tractor in front of vehicle face2face or beside < 4 o'clock
				ahead = true
			end
			if vehicle_in_front.lastSpeedReal == nil or vehicle_in_front.lastSpeedReal*3600 < 5 or ahead then
				--courseplay:debug(nameNum(self) .. ": colliding", 4)
				allowedToDrive = false;
				in_traffic = true
			end
		end
	end
	
	if display_warnings and in_traffic then
		courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPInTraffic"), -1);
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

function courseplay:openCloseCover(self, dt, showCover)
	for i=1, table.getn(self.cp.tippersWithCovers) do
		local twc = self.cp.tippersWithCovers[i];
		local tIdx, coverType, coverItems = twc.tipperIndex, twc.coverType, twc.coverItems;
		local tipper = self.tippers[tIdx];

		--SMK-34 et al.
		if coverType == "setPlane" and tipper.plane.bOpen == showCover then
			tipper:setPlane(not showCover);

		--Hobein 18t et al.
		elseif coverType == "setCoverState" and tipper.cover.state ~= showCover then
			tipper:setCoverState(showCover);

		--TUW et al.
		elseif coverType == "planeOpen" then
			if showCover and tipper.planeOpen then 
				tipper:setAnimationTime(3, tipper.animationParts[3].offSet, false);
			elseif not showCover and not tipper.planeOpen then
				tipper:setAnimationTime(3, tipper.animationParts[3].animDuration, false);
			end;

		--default Giants trailers
		elseif coverType == "defaultGiants" then
			for _,ci in pairs(coverItems) do
				if getVisibility(ci) ~= showCover then
					setVisibility(ci, showCover);
				end;
			end;
		end;
	end; --END for i in self.cp.tippersWithCovers
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
				canRefill = canRefill and activeTool.ReFillTrigger == nil and not self.Waypoints[self.recordnumber].wait and not self.Waypoints[self.recordnumber-1].wait and not self.Waypoints[self.recordnumber-2].wait;

				if activeTool.isSpreaderInRange ~= nil and activeTool.isSpreaderInRange.manureTriggerc ~= nil then
					canRefill = false;
				end;

				--TODO: what to do when transfering from one ManureLager to another?
			end;
			
			if canRefill then
				allowedToDrive = false;
				--courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
				courseplay:handleSpecialTools(self,activeTool,nil,nil,nil,allowedToDrive,false,false)
				local sprayer = activeTool.sprayerFillTriggers[1];
				activeTool:setIsSprayerFilling(true, false);
				
				if sprayer.trailerInTrigger == activeTool then --Feldrand-Container Guellebomber
					sprayer.fill = true;
				end;

				self.cp.infoText = string.format(courseplay:get_locale(self, "CPloading"), self.cp.tipperFillLevel, self.cp.tipperCapacity);
			elseif self.loaded or not self.cp.stopForLoading then
				activeTool:setIsSprayerFilling(false, false);
				courseplay:handleSpecialTools(self,activeTool,nil,nil,nil,allowedToDrive,false,false)
			end;
		elseif courseplay:is_sowingMachine(activeTool) then --sowing machine
			if fill_level < driveOn and activeTool.sowingMachineFillTriggers[1] ~= nil then
				activeTool:setIsSowingMachineFilling(true, activeTool.sowingMachineFillTriggers[1].isEnabled, false);
				allowedToDrive = false;
				self.cp.infoText = string.format(courseplay:get_locale(self, "CPloading"), activeTool.fillLevel, activeTool.capacity);
			end;
		end;
		if self.cp.stopForLoading then
			courseplay:handleSpecialTools(self,activeTool,nil,nil,nil,allowedToDrive,true,false)
			allowedToDrive = false
		end
	end;
	
	return allowedToDrive;
end;

function courseplay:regulateTrafficSpeed(self,refSpeed,allowedToDrive)
	if not allowedToDrive then
		self.cpTrafficBrake = false
	end
	if self.traffic_vehicle_in_front ~= nil then
		local vehicle_in_front = g_currentMission.nodeToVehicle[self.traffic_vehicle_in_front];
		local vehicleBehind = false
		if vehicle_in_front == nil then
			self.traffic_vehicle_in_front = nil
			self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles-1, 0);
			return refSpeed
		end
		local x, y, z = getWorldTranslation(self.traffic_vehicle_in_front)
		local x1, y1, z1 = worldToLocal(self.rootNode, x, y, z)
		if z1 < 0 or math.abs(x1) > 4 then -- vehicle behind tractor
			vehicleBehind = true
		end
		if vehicle_in_front.rootNode == nil or vehicle_in_front.lastSpeedReal == nil or (vehicle_in_front.rootNode ~= nil and courseplay:distance_to_object(self, vehicle_in_front) > 40) or vehicleBehind then
			self.traffic_vehicle_in_front = nil
		else
			if allowedToDrive and not (self.ai_mode == 9 and vehicle_in_front.allowFillFromAir) then
				if (self.lastSpeed*3600) - (vehicle_in_front.lastSpeedReal*3600) > 15 or z1 < 3 then
					self.cpTrafficBrake = true
				else
					self.cpTrafficBrake = false
					return math.min(vehicle_in_front.lastSpeedReal,refSpeed)
				end
			end
		end
	end
	return refSpeed
end

function courseplay:brakeToStop(self)
	if self.lastSpeedReal > 1/3600 then
		self.cpTrafficBrake = true
		return true
	else
		self.cpTrafficBrake = false
		return false
	end
end
