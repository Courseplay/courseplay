-- drives recored course
function courseplay:drive(self, dt)
	if not courseplay:getCanUseAiMode(self) then
		return;
	end;

	local refSpeed = 0
	local cx,cy,cz = 0,0,0
	-- may i drive or should i hold position for some reason?
	local allowedToDrive = true

	-- combine self unloading
	if self.cp.mode == 7 then
		if self.isAIThreshing then
			if (self.grainTankFillLevel * 100 / self.grainTankCapacity) >= self.cp.driveOnAtFillLevel then
				self.maxnumber = table.getn(self.Waypoints)
				cx7, cz7 = self.Waypoints[self.maxnumber].cx, self.Waypoints[self.maxnumber].cz
				local lx7, lz7 = AIVehicleUtil.getDriveDirection(self.rootNode, cx7, cty7, cz7);
				local fx,fy,fz = localToWorld(self.rootNode, 0, 0, -3*self.cp.turnRadius)
				local x7,y7,z7 = localToWorld(self.rootNode, 0, 0, -15)
				self.cp.mode7tx7 = x7
				self.cp.mode7ty7 = y7
				self.cp.mode7tz7 = z7
				if courseplay:is_field(fx, fz) or self.grainTankFillLevel >= self.grainTankCapacity*0.99 then
					self.lastaiThreshingDirectionX = self.aiThreshingDirectionX
					self.lastaiThreshingDirectionZ = self.aiThreshingDirectionZ
					self:stopAIThreshing()
					self.cp.shortestDistToWp = nil
					self.next_targets = {}
					if lx7 < 0 then
						courseplay:debug(nameNum(self) .. ": approach from right", 11);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, -(0.34*3*self.cp.turnRadius) , 0, -3*self.cp.turnRadius);
						courseplay:set_next_target(self, (0.34*2*self.cp.turnRadius) , 0);
						courseplay:set_next_target(self, 0 , 3);
					else
						courseplay:debug(nameNum(self) .. ": approach from left", 11);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, (0.34*3*self.cp.turnRadius) , 0, -3*self.cp.turnRadius);
						courseplay:set_next_target(self, -(0.34*2*self.cp.turnRadius) , 0);
						courseplay:set_next_target(self, 0 ,3);
					end
					self.cp.mode7Unloading = true
					self.cp.mode7GoBackBeforeUnloading = true
					courseplay:start(self)
					self.cp.speeds.sl = 3
					refSpeed = self.cp.speeds.field
				else 
					return
				end
			else
				return
			end
		elseif self.cp.mode7Unloading then
			self.cp.speeds.sl = 3
			refSpeed = self.cp.speeds.field
			if self.cp.mode7GoBackBeforeUnloading then
				local dist = courseplay:distance_to_point(self, self.cp.mode7tx7,self.cp.mode7ty7,self.cp.mode7tz7)
				if  dist  < 1 then
					self.cp.mode7GoBackBeforeUnloading = false
					self.recordnumber = 2
				end
			end
		else
			allowedToDrive = false
			courseplay:setGlobalInfoText(self, 'WORK_END');
		end
		if self.cp.modeState == 5 then
			local targets = table.getn(self.next_targets)
			local aligned  = false
			local ctx7, cty7, ctz7 = getWorldTranslation(self.rootNode);
			self.cp.infoText = string.format(courseplay:loc("CPDriveToWP"), self.target_x, self.target_z)
			cx = self.target_x
			cy = self.target_y
			cz = self.target_z

			if courseplay.debugChannels[11] then 
				drawDebugLine(cx, cty7+3, cz, 1, 0, 0, ctx7, cty7+3, ctz7, 1, 0, 0); 
			end;

			self.cp.speeds.sl = 3
			refSpeed = self.cp.speeds.field
			distance_to_wp = courseplay:distance_to_point(self, cx, y, cz)
			local distToChange = 4
			if self.cp.shortestDistToWp == nil or self.cp.shortestDistToWp > distance_to_wp then
				self.cp.shortestDistToWp = distance_to_wp
			end
			if distance_to_wp > self.cp.shortestDistToWp and distance_to_wp < 6 then
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
					self.cp.speeds.sl = 3
					refSpeed = self.cp.speeds.turn
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
				self.cp.shortestDistToWp = nil
				if targets  > 0 then
					self.target_x = self.next_targets[1].x
					self.target_y = self.next_targets[1].y
					self.target_z = self.next_targets[1].z
					table.remove(self.next_targets, 1)
					self.recordnumber = 2 
				else
					self.cp.modeState = 0
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
	if self.cp.isLoaded == true and self.cp.positionWithCombine ~= nil then
		courseplay:unregister_at_combine(self, self.cp.activeCombine)
	end

	-- switch lights on!
	if not self.isControlled then
		-- we want to hear our courseplayers
		setVisibility(self.aiMotorSound, true)
		if courseplay.lightsNeeded then
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
	if self.cp.mode ~= 7 then 
		cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	elseif self.cp.mode == 7 and self.cp.modeState ~=5 then
		if not self.cp.mode7GoBackBeforeUnloading then
			cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
		else
			cx,cz = self.cp.mode7tx7, self.cp.mode7tz7
		end
	end

	if courseplay.debugChannels[12] and self.cp.isTurning == nil then
		drawDebugPoint(cx, cty+3, cz, 1, 0 , 1, 1);
	end;

	--HORIZONTAL/VERTICAL OFFSET
	local offsetValid = self.cp.totalOffsetX ~= nil and self.cp.toolOffsetZ ~= nil and (self.cp.totalOffsetX ~= 0 or self.cp.toolOffsetZ ~= 0);
	if offsetValid then
		if self.cp.mode == 3 then
			if self.cp.laneOffset ~= 0 then
				courseplay:changeLaneOffset(self, nil, 0);
			end;
			offsetValid = self.recordnumber > 2 and self.recordnumber > self.cp.waitPoints[1] - 6 and self.recordnumber <= self.cp.waitPoints[1] + 3;
		elseif self.cp.mode == 4 or self.cp.mode == 6 then
			offsetValid = self.recordnumber > self.cp.startWork and self.recordnumber < self.cp.stopWork and self.recordnumber > 1; --TODO: recordnumber incl startWork/stopWork?
		elseif self.cp.mode == 7 then
			if self.cp.laneOffset ~= 0 then
				courseplay:changeLaneOffset(self, nil, 0);
			end;
			offsetValid = self.recordnumber > 3 and self.recordnumber > self.cp.waitPoints[1] - 6 and self.recordnumber <= self.cp.waitPoints[1] + 3 and not self.cp.mode7GoBackBeforeUnloading;
		elseif self.cp.mode == 8 then
			if self.cp.laneOffset ~= 0 then
				courseplay:changeLaneOffset(self, nil, 0);
			end;
			offsetValid = self.recordnumber > self.cp.waitPoints[1] - 6 and self.recordnumber <= self.cp.waitPoints[1] + 3;
		else 
			offsetValid = false;
		end;
	end;
	if offsetValid then
		--courseplay:debug(string.format('%s: waypoint before offset: cx=%.2f, cz=%.2f', nameNum(self), cx, cz), 2);
		local vcx, vcz;
		if self.recordnumber == 1 then
			vcx = self.Waypoints[2].cx - cx;
			vcz = self.Waypoints[2].cz - cz;
		else
			if self.Waypoints[self.cp.last_recordnumber].rev then
				vcx = self.Waypoints[self.cp.last_recordnumber].cx - cx;
				vcz = self.Waypoints[self.cp.last_recordnumber].cz - cz;
			else
				vcx = cx - self.Waypoints[self.cp.last_recordnumber].cx;
				vcz = cz - self.Waypoints[self.cp.last_recordnumber].cz;
			end;
		end;

		local vl = Utils.vector2Length(vcx, vcz); -- length of vector
		if vl ~= nil and vl > 0.01 then -- if not too short: normalize and add offsets
			vcx = vcx / vl;
			vcz = vcz / vl;
			cx = cx - vcz * self.cp.totalOffsetX + vcx * self.cp.toolOffsetZ;
			cz = cz + vcx * self.cp.totalOffsetX + vcz * self.cp.toolOffsetZ;
		end;
		--courseplay:debug(string.format('%s: waypoint after offset [%.1fm]: cx=%.2f, cz=%.2f', nameNum(self), self.cp.totalOffsetX, cx, cz), 2);
	end;

	if courseplay.debugChannels[12] and self.cp.isTurning == nil then
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
	if self.cp.mode == 4 or self.cp.mode == 6 then
		if  self.Waypoints[self.recordnumber].turn ~= nil then
			self.cp.isTurning = self.Waypoints[self.recordnumber].turn
		end
		if self.cp.abortWork ~= nil and fill_level == 0 then
			self.cp.isTurning = nil
		end

		--RESET OFFSET TOGGLES
		if not self.cp.isTurning then
			if self.cp.symmetricLaneChange and not self.cp.switchLaneOffset then
				self.cp.switchLaneOffset = true;
				courseplay:debug(string.format("%s: isTurning=false, switchLaneOffset=false -> set switchLaneOffset to true", nameNum(self)), 12);
			end;
			if self.cp.hasPlough and not self.cp.switchToolOffset then
				self.cp.switchToolOffset = true;
				courseplay:debug(string.format("%s: isTurning=false, switchToolOffset=false -> set switchToolOffset to true", nameNum(self)), 12);
			end;
		end;
	end;

	if self.cp.mode == 4 or self.cp.mode == 8 then
		self.implementIsFull = (fill_level ~= nil and fill_level == 100);
	end;
	
	-- in a traffic yam?

	-- coordinates of coli
	--local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
	local tx, ty, tz = localToWorld(self.cp.DirectionNode,0,1,3)
	-- direction of tractor
	local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, 0, lz)
	--RulModiä
	if self.cp.beaconLightsMode == 1 then
		if (self.cp.speeds.sl == 3 and not self.beaconLightsActive) or (self.cp.speeds.sl ~= 3 and self.beaconLightsActive) or (self.cp.mode == 7 and self.isAIThreshing and self.beaconLightsActive)  then
			self:setBeaconLightsVisibility(not self.beaconLightsActive);
		end
	elseif self.cp.beaconLightsMode == 2 then
		if (self.drive and not self.beaconLightsActive) or (not self.drive and self.beaconLightsActive) then
			self:setBeaconLightsVisibility(not self.beaconLightsActive);
		end
	elseif self.cp.beaconLightsMode == 3 then
		if self.beaconLightsActive then
			self:setBeaconLightsVisibility(false);
		end
	end


	-- the tipper that is currently loaded/unloaded
	local activeTipper = nil
	local isBypassing = false
	--### WAITING POINTS - START
	if self.Waypoints[self.cp.last_recordnumber].wait and self.wait then
		if self.waitTimer == nil and self.cp.waitTime > 0 then
			self.waitTimer = self.timer + self.cp.waitTime * 1000
		end
		if self.cp.mode == 3 and self.cp.tipperAttached then
			courseplay:handleMode3(self, fill_level, allowedToDrive, dt);

		elseif self.cp.mode == 4 then
			local drive_on = false
			if self.cp.last_recordnumber == self.cp.startWork and fill_level ~= 0 then
				self.wait = false
			elseif self.cp.last_recordnumber == self.cp.stopWork and self.cp.abortWork ~= nil then
				self.wait = false
			else
				local isInWorkArea = self.recordnumber > self.cp.startWork and self.recordnumber <= self.cp.stopWork;
				if self.cp.tipperAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.tippers ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, fill_level, 100, allowedToDrive, lx, lz, dt);
				end;
				if courseplay:timerIsThrough(self, "fillLevelChange") or self.cp.prevFillLevel == nil then
					if self.cp.prevFillLevel ~= nil and fill_level == self.cp.prevFillLevel and fill_level > self.cp.driveOnAtFillLevel then
						drive_on = true
					end
					self.cp.prevFillLevel = fill_level
					courseplay:setCustomTimer(self, "fillLevelChange", 7);
				end

				if fill_level == 100 or drive_on then
					self.wait = false
				end
				self.cp.infoText = string.format(courseplay:loc("CPloading"), self.cp.tipperFillLevel, self.cp.tipperCapacity)
			end
		elseif self.cp.mode == 6 then
			if self.cp.last_recordnumber == self.cp.startWork then
				self.wait = false
			elseif self.cp.last_recordnumber == self.cp.stopWork and self.cp.abortWork ~= nil then
				self.wait = false
			elseif self.cp.last_recordnumber ~= self.cp.startWork and self.cp.last_recordnumber ~= self.cp.stopWork then 
				courseplay:setGlobalInfoText(self, 'UNLOADING_BALE');
				if fill_level == 0 or drive_on then
					self.wait = false
				end;
			end;
		elseif self.cp.mode == 7 then
			if self.cp.last_recordnumber == self.cp.startWork then
				if self.grainTankFillLevel > 0 then
					self:setPipeState(2)
					courseplay:setGlobalInfoText(self, 'OVERLOADING_POINT');
				else
					self.wait = false
					self.cp.isUnloaded = true
				end
			end
		elseif self.cp.mode == 8 then
			courseplay:setGlobalInfoText(self, 'OVERLOADING_POINT');
			if self.cp.tipperAttached then
				-- drive on if fill_level doesn't change and fill level is < 100-self.cp.followAtFillLevel
				courseplay:handle_mode8(self)
				local drive_on = false
				if courseplay:timerIsThrough(self, "fillLevelChange") or self.cp.prevFillLevel == nil then
					if self.cp.prevFillLevel ~= nil and fill_level == self.cp.prevFillLevel and fill_level < self.cp.followAtFillLevel then
						drive_on = true
					end
					self.cp.prevFillLevel = fill_level
					courseplay:setCustomTimer(self, "fillLevelChange", 7);
				end
				if fill_level == 0 or drive_on then
					self.wait = false
					self.cp.prevFillLevel = nil
					self.cp.isUnloaded = true
				end
			end
		elseif self.cp.mode == 9 then
			self.wait = false;
		else
			courseplay:setGlobalInfoText(self, 'WAIT_POINT');
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
		if (self.cp.mode == 1 or (self.cp.mode == 2 and self.cp.isLoaded)) and self.cp.tipperFillLevel ~= nil and self.cp.tipRefOffset ~= nil and self.cp.tipperAttached then
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
				if self.cp.tipRefOffset ~= 0 then
					if self.cp.currentTipTrigger == nil then
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,self.cp.tipRefOffset,0,0)
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
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,-self.cp.tipRefOffset,0,0)
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
		if (((self.cp.mode == 2 or self.cp.mode == 3) and self.recordnumber < 2) or self.cp.activeCombine) and self.cp.tipperAttached then
			self.cp.inTraffic = false
			courseplay:handle_mode2(self, dt);
			return;
		elseif (self.cp.mode == 2 or self.cp.mode == 3) and self.recordnumber < 3 then
			isBypassing = true
			lx, lz = courseplay:isTheWayToTargetFree(self,lx, lz)
		elseif self.cp.mode == 6 and self.cp.hasBaleLoader and (self.recordnumber == self.cp.stopWork - 4 or (self.cp.abortWork ~= nil and self.recordnumber == self.cp.abortWork ))then
			isBypassing = true
			lx, lz = courseplay:isTheWayToTargetFree(self,lx, lz)			
		elseif self.cp.mode ~= 7 then
			self.cp.modeState = 0
		end;

		if self.cp.mode == 3 and self.cp.tipperAttached and self.recordnumber >= 2 and self.cp.modeState == 0 then
			courseplay:handleMode3(self, fill_level, allowedToDrive, dt);
		end;

		-- Fertilice loading --only for one Implement !
		if self.cp.mode == 4 then
			if self.cp.tipperAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
				local isInWorkArea = self.recordnumber > self.cp.startWork and self.recordnumber <= self.cp.stopWork;
				if self.tippers ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, fill_level, 100, allowedToDrive, lx, lz, dt);
				end
			end;
		end

		if self.cp.mode == 7 then
			if self.recordnumber == self.maxnumber then
				if self.target_x ~= nil then
	 				self.cp.modeState = 5
					self.recordnumber = 2
					courseplay:debug(nameNum(self) .. ": " .. tostring(debug.getinfo(1).currentline) .. ": modeState = 5", 11);
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

		--REFILL LIQUID MANURE TRANSPORT
		if self.cp.mode == 8 then
			raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
			if self.cp.tipperAttached then
				if self.tippers ~= nil then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, fill_level, 100, allowedToDrive, lx, lz, dt);
				end;
			end;
		end;

		--VEHICLE DAMAGE
		if self.damageLevel then
			if self.damageLevel >= 90 and not self.isInRepairTrigger then
				allowedToDrive = courseplay:brakeToStop(self);
				courseplay:setGlobalInfoText(self, 'DAMAGE_MUST');
			elseif self.damageLevel >= 50 and not self.isInRepairTrigger then
				courseplay:setGlobalInfoText(self, 'DAMAGE_SHOULD');
			end;
			if self.damageLevel > 70 then
				raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self);
				if self.cp.fillTrigger ~= nil then
					if courseplay.triggers.all[self.cp.fillTrigger].isDamageModTrigger then
						--print("slow down , its a garage")
						self.cp.isInFilltrigger = true
					end
				end
				if self.isInRepairTrigger then
					self.cp.isInRepairTrigger = true
				end;
			elseif self.damageLevel == 0 then
					self.cp.isInRepairTrigger = false
			end;
			if self.cp.isInRepairTrigger then
				allowedToDrive = false;
				self.cp.fillTrigger = nil;
				courseplay:setGlobalInfoText(self, 'DAMAGE_IS');
			end;
		end;

		--FUEL LEVEL + REFILLING
		if self.fuelCapacity > 0 then
			local currentFuelPercentage = (self.fuelFillLevel / self.fuelCapacity + 0.0001) * 100;
			if currentFuelPercentage < 5 then
				allowedToDrive = false;
				courseplay:setGlobalInfoText(self, 'FUEL_MUST');
			elseif currentFuelPercentage < 20 and not self.isFuelFilling then
				raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				if self.cp.fillTrigger ~= nil then
					local trigger = courseplay.triggers.all[self.cp.fillTrigger]
					if trigger.isGasStationTrigger then
						--print("slow down , its a gasstation")
						self.cp.isInFilltrigger = true
					end
				end
				courseplay:setGlobalInfoText(self, 'FUEL_SHOULD');
				if self.fuelFillTriggers[1] then
					allowedToDrive = courseplay:brakeToStop(self);
					self:setIsFuelFilling(true, self.fuelFillTriggers[1].isEnabled, false);
				end
			elseif self.isFuelFilling and currentFuelPercentage < 99.9 then
				allowedToDrive = courseplay:brakeToStop(self);
				courseplay:setGlobalInfoText(self, 'FUEL_IS');
			end;
			if self.fuelFillTriggers[1] then
				courseplay:debug(nameNum(self) .. ": resetting \"self.cp.fillTrigger\"",1)
				self.cp.fillTrigger = nil
			end
		end;

		--WATER WARNING
		if self.showWaterWarning then
			allowedToDrive = false
			courseplay:setGlobalInfoText(self, 'WATER');
		end

		if self.cp.stopAtEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil) then
			allowedToDrive = false
			courseplay:setGlobalInfoText(self, 'END_POINT');
		end
	end

	-- ai_mode 4 = fertilize
	local workArea = false
	local workSpeed = 0;
	local isFinishingWork = false
	if self.cp.mode == 4 and self.cp.tipperAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed ,isFinishingWork = courseplay:handle_mode4(self, allowedToDrive, workSpeed, fill_level)
	end

	


	-- Mode 6 Fieldwork for balers and foragewagon
	if (self.cp.mode == 6 or self.cp.mode == 4) and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
		if self.cp.mode == 6 then
			allowedToDrive, workArea, workSpeed, activeTipper ,isFinishingWork = courseplay:handle_mode6(self, allowedToDrive, workSpeed, fill_level, lx , lz )
		end
		if not workArea and self.cp.tipperFillLevel ~= nil and ((self.grainTankCapacity == nil and self.cp.tipRefOffset ~= nil) or self.cp.hasMachinetoFill) then
			if self.cp.currentTipTrigger == nil and self.cp.fillTrigger == nil then
				-- is there a tipTrigger within 10 meters?
				courseplay:debug(nameNum(self) .. ": call 1st raycast", 1);
				local num = raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
				if num > 0 then
					courseplay:debug(string.format("%s: drive(%d): 1st raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
				end;
				if courseplay.debugChannels[1] then
					drawDebugLine(tx, ty, tz, 1, 0, 0, tx+(nx*10), ty+(ny*10), tz+(nz*10), 1, 0, 0);
				end;

				if self.cp.tipRefOffset ~= 0 then
					if self.cp.currentTipTrigger == nil then
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,self.cp.tipRefOffset,0,0)
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
						local x1,y1,z1 = localToWorld(self.aiTrafficCollisionTrigger,-self.cp.tipRefOffset,0,0)
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
	if self.cp.mode == 9 then
		allowedToDrive = courseplay:handle_mode9(self, fill_level, allowedToDrive, dt);
	end;
	self.cp.inTraffic = false
	
	local dx,_,dz = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);
	local length = Utils.vector2Length(dx,dz);
	if self.cp.turnStage == 0 then
		self.aiTractorDirectionX = dx/length;
		self.aiTractorDirectionZ = dz/length;
	end

	--Open/close cover
	if self.cp.tipperHasCover and self.cp.automaticCoverHandling and (self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 5 or self.cp.mode == 6) then
		local showCover = false;

		if self.cp.mode ~= 6 then
			local minCoverWaypoint = 3;
			if self.cp.mode == 1 then
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

		courseplay:openCloseCover(self, dt, showCover, self.cp.currentTipTrigger ~= nil);
	end;

	allowedToDrive = courseplay:checkTraffic(self, true, allowedToDrive)
	
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
				courseplay:setGlobalInfoText(self, 'WORK_END');
			else
				self.cp.isLoaded = true;
				self.recordnumber = i + 2
			end
		end
	end



	-- stop or hold position
	if not allowedToDrive then
		self.cp.TrafficBrake = false
		self.cp.isTrafficBraking = false
		if self.isRealistic then
			courseplay:driveInMRDirection(self, 0,1,true,dt,false)
			return
		else
			AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, 0, 1)
			if g_server ~= nil then
				AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, 0.5, 0.5, 28, false, moveForwards, 0, 1)
			end
			return;
		end
		-- unload active tipper if given
	end

	if self.cp.isTurning ~= nil then
		courseplay:turn(self, dt);
		self.cp.TrafficBrake = false
		return
	end


	--SPEED SETTING
	local isAtEnd   = self.recordnumber > self.maxnumber - 3;
	local isAtStart = self.recordnumber < 3;
	if 	((self.cp.mode == 1 or self.cp.mode == 5 or self.cp.mode == 7 or self.cp.mode == 8) and (isAtStart or isAtEnd)) or
		((self.cp.mode == 2 or self.cp.mode == 3) and isAtEnd) or
		(self.cp.mode == 9 and self.recordnumber > self.cp.waitPoints[1] and self.recordnumber <= self.cp.waitPoints[2]) or
		(not workArea and self.wait and ((isAtEnd and self.Waypoints[self.recordnumber].wait) or courseplay:waypointsHaveAttr(self, self.recordnumber, 0, 2, "wait", true, false))) or 
		(isAtEnd and self.Waypoints[self.recordnumber].rev) or
		(workSpeed ~= nil and workSpeed == 0.5) 
	then
		self.cp.speeds.sl = 1;
		refSpeed = self.cp.speeds.turn;
	elseif ((self.cp.mode == 2 or self.cp.mode == 3) and isAtStart) or (workSpeed ~= nil and workSpeed == 1) then
		self.cp.speeds.sl = 2;
		refSpeed = self.cp.speeds.field;
	else
		self.cp.speeds.sl = 3;
		refSpeed = self.cp.speeds.max;
		if self.cp.speeds.useRecordingSpeed and self.Waypoints[self.recordnumber].speed ~= nil then
			refSpeed = Utils.clamp(refSpeed, 3/3600, self.Waypoints[self.recordnumber].speed);
		end;
	end;
	
	if self.cp.collidingVehicleId ~= nil then
		refSpeed = courseplay:regulateTrafficSpeed(self, refSpeed, allowedToDrive);
	end
	
	local real_speed = self.lastSpeedReal;
	local maxRpm = self.motor.maxRpm[self.cp.speeds.sl];

	--bunkerSilo speed by Thomas Gärtner
	if self.cp.currentTipTrigger ~= nil then
		if self.cp.currentTipTrigger.bunkerSilo ~= nil then
			refSpeed = Utils.getNoNil(self.cp.speeds.unload, 3/3600);
		else
			refSpeed = self.cp.speeds.turn
		end
	elseif self.cp.isInFilltrigger then
		if self.lastSpeedReal > self.cp.speeds.turn then
			courseplay:brakeToStop(self)
		else
			refSpeed = self.cp.speeds.turn
		end
		self.cp.isInFilltrigger = false
	else
		if self.runonce ~= nil then
			self.runonce = nil;
		end
	end
	
	--checking ESLimiter version
	if self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] == nil then
		self.cp.infoText = courseplay:loc("CPWrongESLversion")
	end

	-- where to drive?
	if courseplay:isWheelloader(self) then
		local lx2 ,lz2  = AIVehicleUtil.getDriveDirection(self.rootNode, cx, cty, cz); 
		if math.abs(self.steeringLastRotation) < 0.5 then
			lx = lx2
			lz = lz2
		end
	end
   --finishing field work
	if isFinishingWork then
		lx=0
		lz=1
	end
	
	--reverse
	if self.Waypoints[self.recordnumber].rev then
		lx,lz,fwd = courseplay:goReverse(self,lx,lz)
		refSpeed = Utils.getNoNil(self.cp.speeds.unload, 3/3600)
	else
		fwd = true
	end

	if self.cp.TrafficBrake then
		if self.isRealistic then
			AIVehicleUtil.mrDriveInDirection(self, dt, 1, false, true, 0, 1, self.cp.speeds.sl, true, true)
			self.cp.TrafficBrake = false
			self.cp.isTrafficBraking = false
			self.cp.TrafficHasStopped = false
			return
		else
			fwd = false
			lx = 0
			lz = 1
		end
	end  	
	self.cp.TrafficBrake = false
	self.cp.isTrafficBraking = false
	self.cp.TrafficHasStopped = false

	if self.cp.mode7GoBackBeforeUnloading then
		fwd = false
		lz = lz * -1
		lx = lx * -1
	end
	
	-- Speed Control
	if self.cp.maxFieldSpeed ~= 0 then
		refSpeed = math.min(self.cp.maxFieldSpeed, refSpeed);
	end
	
	if self.isRealistic then
		courseplay:setMRSpeed(self, refSpeed, self.cp.speeds.sl, allowedToDrive, workArea);
	else
		courseplay:setSpeed(self, refSpeed, self.cp.speeds.sl)
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
		elseif self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7 then
			distToChange = 5;
		elseif self.cp.mode == 9 then
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
	if self.cp.shortestDistToWp == nil or self.cp.shortestDistToWp > self.dist then
		self.cp.shortestDistToWp = self.dist
	end

	if beforeReverse then
		self.cp.shortestDistToWp = nil
	end

	if self.invertedDrivingDirection then
		lx = -lx
		lz = -lz
	end

	-- if distance grows i must be circling
	if self.dist > self.cp.shortestDistToWp and self.recordnumber > 3 and self.dist < 15 and self.Waypoints[self.recordnumber].rev ~= true then
		distToChange = self.dist + 1
	end

	if self.dist > distToChange or WpUnload or WpLoadEnd or isFinishingWork then
		if g_server ~= nil then
			if self.isRealistic then 
				courseplay:driveInMRDirection(self, lx,lz,fwd, dt,allowedToDrive);
			else
				AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, 0.5, 0.5, 8, true, fwd, lx, lz, self.cp.speeds.sl, 0.5);
			end
			if not isBypassing then
				courseplay:setTrafficCollision(self, lx, lz, workArea)
			end
		end
	else
		-- reset distance to waypoint
		self.cp.shortestDistToWp = nil
		if self.recordnumber < self.maxnumber then -- = New
			if not self.wait then
				self.wait = true
			end
			if self.cp.mode == 7 and self.cp.modeState == 5 then
			else
				self.recordnumber = self.recordnumber + 1
			end
			-- ignore reverse Waypoints for mode 6
			local in_work_area = false
			if self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.recordnumber >= self.cp.startWork and self.recordnumber <= self.cp.stopWork then
				in_work_area = true
			end
			while self.cp.mode == 6 and self.recordnumber < self.maxnumber and in_work_area and self.Waypoints[self.recordnumber].rev do
				self.recordnumber = self.recordnumber + 1
			end
		else -- reset some variables
			if (self.cp.mode == 4 or self.cp.mode == 6) and not self.cp.hasUnloadingRefillingCourse then
			else
				self.recordnumber = 1
			end
			self.cp.isUnloaded = false
			self.cp.stopAtEnd = false
			self.cp.isLoaded = false
			self.cp.isRecording = false
			self.cp.canDrive = true
		end
	end
end


function courseplay:setTrafficCollision(self, lx, lz, workArea) --!!!
	--local goForRaycast = self.cp.mode == 1 or (self.cp.mode == 3 and self.recordnumber > 3) or self.cp.mode == 5 or self.cp.mode == 8 or ((self.cp.mode == 4 or self.cp.mode == 6) and self.recordnumber > self.cp.stopWork) or (self.cp.mode == 2 and self.recordnumber > 3)
	--print("lx: "..tostring(lx).."	distance: "..tostring(distance))
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
	if self.cp.trafficCollisionTriggers[1] ~= nil then 
		AIVehicleUtil.setCollisionDirection(self.cp.DirectionNode, self.cp.trafficCollisionTriggers[1], colDirX, colDirZ);
		local recordNumber = self.recordnumber
		if self.cp.collidingVehicleId == nil then
			for i=2,self.cp.numTrafficCollisionTriggers do
				if workArea or recordNumber + i > self.maxnumber or recordNumber < 2 then
					AIVehicleUtil.setCollisionDirection(self.cp.trafficCollisionTriggers[i-1], self.cp.trafficCollisionTriggers[i], 0, -1);
				else
					local nodeX,nodeY,nodeZ = getWorldTranslation(self.cp.trafficCollisionTriggers[i]);
					local nodeDirX,nodeDirY,nodeDirZ,distance = courseplay:get3dDirection(nodeX,nodeY,nodeZ, self.Waypoints[recordNumber+i].cx,nodeY,self.Waypoints[recordNumber+i].cz);
					if distance < 5.5 and recordNumber + i +1 <= self.maxnumber then
							nodeDirX,nodeDirY,nodeDirZ,distance = courseplay:get3dDirection(nodeX,nodeY,nodeZ, self.Waypoints[recordNumber+i+1].cx,nodeY,self.Waypoints[recordNumber+i+1].cz);
					end;
						nodeDirX,nodeDirY,nodeDirZ = worldDirectionToLocal(self.cp.trafficCollisionTriggers[i-1], nodeDirX,nodeDirY,nodeDirZ);
						AIVehicleUtil.setCollisionDirection(self.cp.trafficCollisionTriggers[i-1], self.cp.trafficCollisionTriggers[i], nodeDirX, nodeDirZ);
				end;
			end
		end
	end;
end;


function courseplay:checkTraffic(self, display_warnings, allowedToDrive)
	local ahead = false
	local collisionVehicle = g_currentMission.nodeToVehicle[self.cp.collidingVehicleId]
	--courseplay:debug(tableShow(self, nameNum(self), 4), 4)
	--if self.CPnumCollidingVehicles ~= nil and self.CPnumCollidingVehicles > 0 then
		if collisionVehicle ~= nil and not (self.cp.mode == 9 and collisionVehicle.allowFillFromAir) then
			local vx, vy, vz = getWorldTranslation(self.cp.collidingVehicleId)
			local tx, ty, tz = worldToLocal(self.aiTrafficCollisionTrigger, vx, vy, vz)
			local xvx, xvy, xvz = getWorldTranslation(self.aiTrafficCollisionTrigger)
			local x, y, z = getWorldTranslation(self.cp.DirectionNode)
			local x1, y1, z1 = 0,0,0
			local halfLength = Utils.getNoNil(collisionVehicle.sizeLength,5)/2
			x1,z1 = AIVehicleUtil.getDriveDirection(self.cp.collidingVehicleId, x, y, z);
			if z1 > -0.9 then -- tractor in front of vehicle face2face or beside < 4 o'clock
				ahead = true
			end
			if math.abs(tx) > 5 and collisionVehicle.rootNode ~= nil and not self.cp.collidingObjects.all[self.cp.collidingVehicleId] then
				courseplay:debug(nameNum(self)..": checkTraffic:	deleteCollisionVehicle",3)
				courseplay:deleteCollisionVehicle(self)
				return allowedToDrive
			end
			if collisionVehicle.lastSpeedReal == nil or collisionVehicle.lastSpeedReal*3600 < 5 or ahead then
				--courseplay:debug(nameNum(self)..": checkTraffic:	distance: "..tostring(tz-halfLength),3)
				if tz <= 2 + halfLength then
					allowedToDrive = false;
					self.cp.inTraffic = true
					--courseplay:debug(nameNum(self)..": checkTraffic:	Stop",3)
				elseif self.lastSpeedReal*3600 > 10 then
					--courseplay:debug(nameNum(self)..": checkTraffic:	brake",3)
					allowedToDrive = courseplay:brakeToStop(self)
				else
					--courseplay:debug(nameNum(self)..": checkTraffic:	do nothing - go, but set \"self.cp.isTrafficBraking\"",3)
					self.cp.isTrafficBraking = true
				end
			end
		end
	--end
	
	if display_warnings and self.cp.inTraffic then
		courseplay:setGlobalInfoText(self, 'TRAFFIC');
	end
	return allowedToDrive
end

function courseplay:deleteCollisionVehicle(vehicle)
	if vehicle.cp.collidingVehicleId ~= nil  then
					vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] = nil
					--self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles - 1, 0);
					--if self.CPnumCollidingVehicles == 0 then
					--self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0);
					vehicle.cp.collidingObjects[4][vehicle.cp.collidingVehicleId] = nil
					vehicle.cp.collidingVehicleId = nil
					courseplay:debug(string.format("%s: 	deleteCollisionVehicle: setting \"self.cp.collidingVehicleId\"to nil", nameNum(self)), 3);
	end
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
		if self.lastSpeed*3600 - refSpeed*3600 > 8 and self.cp.isTurning == nil then
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

function courseplay:openCloseCover(self, dt, showCover, isAtTipTrigger)
	for i=1, table.getn(self.cp.tippersWithCovers) do
		local twc = self.cp.tippersWithCovers[i];
		local tIdx, coverType, showCoverWhenTipping, coverItems = twc.tipperIndex, twc.coverType, twc.showCoverWhenTipping, twc.coverItems;
		local tipper = self.tippers[tIdx];

		--SMK-34 et al.
		if coverType == "setPlane" and tipper.plane.bOpen == showCover then
			if showCoverWhenTipping and isAtTipTrigger and not showCover then
				--
			else
				tipper:setPlane(not showCover);
			end;

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

		--Marston / setSheet
		elseif coverType == "setSheet" and tipper.sheet.isActive ~= showCover then
			tipper:setSheet(showCover);

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

function courseplay:refillSprayer(self, fill_level, driveOn, allowedToDrive, lx, lz, dt)
	for i = 1, table.getn(self.tippers) do
		local activeTool = self.tippers[i];
		local isSpecialSprayer = false
		local fillTrigger = nil;
		isSpecialSprayer, allowedToDrive, lx, lz = courseplay:handleSpecialSprayer(self,activeTool, fill_level, driveOn, allowedToDrive, lx, lz, dt, "pull");
		if isSpecialSprayer then
			return allowedToDrive,lx,lz
		end
		
		if courseplay:isSprayer(activeTool) or activeTool.cp.hasUrfSpec then --sprayer
			if self.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[self.cp.fillTrigger];
				if courseplay:fillTypesMatch(trigger, activeTool) then 
					--print(nameNum(activeTool) .. ": slow down, it's a sprayerFillTrigger")
					self.cp.isInFilltrigger = true
				end
			end
			local activeToolFillLevel = nil;
			if activeTool.fillLevel ~= nil and activeTool.capacity ~= nil then
				activeToolFillLevel = (activeTool.fillLevel / activeTool.capacity) * 100;
			end;
			if activeTool.cp.hasUrfSpec then
				activeToolFillLevel = (activeTool.sprayFillLevel / activeTool.sprayCapacity) * 100;
			end

			if fillTrigger == nil then
				if activeTool.sprayerFillTriggers ~= nil and table.getn(activeTool.sprayerFillTriggers) > 0 then
					fillTrigger = activeTool.sprayerFillTriggers[1];
					self.cp.fillTrigger = nil
				end;
			end;

			local fillTypesMatch = courseplay:fillTypesMatch(fillTrigger, activeTool);

			local canRefill = (activeToolFillLevel ~= nil and activeToolFillLevel < driveOn) and fillTypesMatch;
			--ManureLager: activeTool.ReFillTrigger has to be nil so it doesn't refill
			if self.cp.mode == 8 then
				canRefill = canRefill and activeTool.ReFillTrigger == nil and not courseplay:waypointsHaveAttr(self, self.recordnumber, -2, 2, "wait", true, false);

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

				self.cp.infoText = string.format(courseplay:loc("CPloading"), self.cp.tipperFillLevel, self.cp.tipperCapacity);
			elseif self.cp.isLoaded or not self.cp.stopForLoading then
				activeTool:setIsSprayerFilling(false, false);
				courseplay:handleSpecialTools(self,activeTool,nil,nil,nil,allowedToDrive,false,false)
				self.cp.fillTrigger = nil
			end;
		end
		if courseplay:is_sowingMachine(activeTool) then --sowing machine
			if self.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[self.cp.fillTrigger]
				if trigger.isSowingMachineFillTrigger then
					--print("slow down , its a SowingMachineFillTrigger")
					self.cp.isInFilltrigger = true
				end
			end
			if fill_level < driveOn and activeTool.sowingMachineFillTriggers[1] ~= nil then
				activeTool:setIsSowingMachineFilling(true, activeTool.sowingMachineFillTriggers[1].isEnabled, false);
				allowedToDrive = false;
				self.cp.infoText = string.format(courseplay:loc("CPloading"), activeTool.fillLevel, activeTool.capacity);
			elseif activeTool.sowingMachineFillTriggers[1] ~= nil then
				self.cp.fillTrigger = nil
			end;
		end;
		if self.cp.stopForLoading then
			courseplay:handleSpecialTools(self,activeTool,nil,nil,nil,allowedToDrive,true,false)
			allowedToDrive = false
		end
	end;
	
	return allowedToDrive,lx,lz
end;

function courseplay:regulateTrafficSpeed(self,refSpeed,allowedToDrive)
	if self.cp.isTrafficBraking then
		return refSpeed
	end
	if self.cp.collidingVehicleId ~= nil then
		local collisionVehicle = g_currentMission.nodeToVehicle[self.cp.collidingVehicleId];
		local vehicleBehind = false
		if collisionVehicle == nil then
			courseplay:debug(nameNum(self)..": regulateTrafficSpeed(1216):	setting self.cp.collidingVehicleId nil",3)
			self.cp.collidingVehicleId = nil
			self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles-1, 0);
			return refSpeed
		else
			local name = getName(self.cp.collidingVehicleId)
			courseplay:debug(nameNum(self)..": regulateTrafficSpeed:	 "..tostring(name),3)
		end
		local x, y, z = getWorldTranslation(self.cp.collidingVehicleId)
		local x1, y1, z1 = worldToLocal(self.rootNode, x, y, z)
		if z1 < 0 or math.abs(x1) > 5 and not self.cp.collidingObjects.all[self.cp.collidingVehicleId] then -- vehicle behind tractor
			vehicleBehind = true
		end
		local distance = 0
		if collisionVehicle.rootNode ~= nil then
			distance = courseplay:distance_to_object(self, collisionVehicle)
		end
		if collisionVehicle.rootNode == nil or collisionVehicle.lastSpeedReal == nil or (distance > 40) or vehicleBehind then
			courseplay:debug(string.format("%s: v.rootNode= %s,v.lastSpeedReal= %s, distance: %f, vehicleBehind= %s",nameNum(self),tostring(collisionVehicle.rootNode),tostring(collisionVehicle.lastSpeedReal),distance,tostring(vehicleBehind)),3)
			courseplay:deleteCollisionVehicle(self)
			--courseplay:debug(nameNum(self)..": regulateTrafficSpeed(1230):	setting self.cp.collidingVehicleId nil",3)
		
		else
			if allowedToDrive and not (self.cp.mode == 9 and collisionVehicle.allowFillFromAir) then
				if (self.lastSpeed*3600) - (collisionVehicle.lastSpeedReal*3600) > 15 or z1 < 3 then
					self.cp.TrafficBrake = true
				else
					return math.min(collisionVehicle.lastSpeedReal,refSpeed)
				end
			end
		end
	end
	return refSpeed
end

function courseplay:brakeToStop(self)
	if self.isRealistic then
		return false
	end
	if self.lastSpeedReal > 1/3600 and not self.cp.TrafficHasStopped then
		self.cp.TrafficBrake = true
		self.cp.isTrafficBraking = true
		return true
	else
		self.cp.TrafficHasStopped = true
		return false
	end
end


function courseplay:driveInMRDirection(self, lx,lz,fwd,dt,allowedToDrive)
	if not self.realForceAiDriven then
		self.realForceAiDriven = true
	end
	if self.cp.speedBrake then 
		--print("speed brake")
		allowedToDrive = false
	end	

	--when I'm 2Fast in a curve then brake
	if math.abs(lx) > 0.25 and self.lastSpeedReal*3600 > 25 then
		allowedToDrive = false
		--print("emergency brake")
	end
	if not fwd then
		lx = -lx
		lz = -lz
	end
	--AIVehicleUtil.mrDriveInDirection(self, dt, acceleration, allowedToDrive, moveForwards, lx, lz, speedLevel, useReduceSpeed, noDefaultHiredWorker)
	AIVehicleUtil.mrDriveInDirection(self, dt, 1, allowedToDrive, fwd, lx, lz, self.cp.speeds.sl, true, true)
			
end


function courseplay:setMRSpeed(self, refSpeed, sl, allowedToDrive, workArea)
	local currentSpeed = self.lastSpeedReal
	local deltaMinus = currentSpeed*3600 - refSpeed*3600
	local deltaPlus = refSpeed*3600 - currentSpeed*3600

	if deltaMinus > 5 then
		self.cp.speedBrake = true
	else 
		self.cp.speedBrake = false
	end
	
	self.motor.speedLevel = sl
	self.motor.realSpeedLevelsAI[self.motor.speedLevel] = refSpeed*3600
	
	-- setting AWD if necessary
	if (workArea or self.realDisplaySlipPercent > 25) and self.realAWDModeOn == false then 
		self:realSetAwdActive(true);
	elseif not workArea and self.realDisplaySlipPercent < 1 and self.realAWDModeOn == true then 
		self:realSetAwdActive(false);
	end
end;
