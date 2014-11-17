local curFile = 'drive.lua';

local abs, max, min, pow, sin = math.abs, math.max, math.min, math.pow, math.sin;

-- drives recored course
function courseplay:drive(self, dt)
	if not courseplay:getCanUseAiMode(self) then
		return;
	end;
	
	local refSpeed = 0
	local cx,cy,cz = 0,0,0
	-- may i drive or should i hold position for some reason?
	local allowedToDrive = true

	-- TIPPER FILL LEVELS (get once for all following functions)
	self.cp.tipperFillLevel, self.cp.tipperCapacity = self:getAttachedTrailersFillLevelAndCapacity();
	if self.cp.tipperFillLevel == nil then self.cp.tipperFillLevel = 0; end;
	if self.cp.tipperCapacity == nil or self.cp.tipperCapacity == 0 then self.cp.tipperCapacity = 0.00001; end;
	self.cp.tipperFillLevelPct = self.cp.tipperFillLevel * 100 / self.cp.tipperCapacity;


	-- RESET TRIGGER RAYCASTS
	self.cp.hasRunRaycastThisLoop['tipTrigger'] = false;
	self.cp.hasRunRaycastThisLoop['specialTrigger'] = false;


	-- combine self unloading
	if self.cp.mode == 7 then
		local continue;
		continue, cx, cy, cz, refSpeed, allowedToDrive = courseplay:handleMode7(self, cx, cy, cz, refSpeed, allowedToDrive);
		if not continue then
			return;
		end;
	end;


	-- unregister at combine, if there is one
	if self.cp.isLoaded == true and self.cp.positionWithCombine ~= nil then
		courseplay:unregisterFromCombine(self, self.cp.activeCombine)
	end

	-- Turn on sound / control lights
	if not self.isControlled then
		--setVisibility(self.aiMotorSound, true); --TODO (Jakob): still needed in FS13 and FS15(Tom)?
		self:setLightsVisibility(courseplay.lightsNeeded);
	end;

	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.rootNode);

	if self.recordnumber > self.maxnumber then
		courseplay:debug(string.format("drive %d: %s: self.recordnumber (%s) > self.maxnumber (%s)", debug.getinfo(1).currentline, nameNum(self), tostring(self.recordnumber), tostring(self.maxnumber)), 12); --this should never happen
		courseplay:setRecordNumber(self, self.maxnumber);
	end;
	if self.recordnumber > 1 then
		self.cp.lastRecordnumber = self.recordnumber - 1;
	else
		self.cp.lastRecordnumber = 1;
	end;


	if self.cp.mode ~= 7 or (self.cp.mode == 7 and self.cp.modeState ~= 5) then 
		cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	end

	if courseplay.debugChannels[12] and self.cp.isTurning == nil then
		drawDebugPoint(cx, cty+3, cz, 1, 0 , 1, 1);
	end;

	-- HORIZONTAL/VERTICAL OFFSET
	if courseplay:getIsVehicleOffsetValid(self) then
		cx, cz = courseplay:getVehicleOffsettedCoords(self, cx, cz);
		if courseplay.debugChannels[12] and self.cp.isTurning == nil then
			drawDebugPoint(cx, cty+3, cz, 0, 1 , 1, 1);
		end;
	end;

	self.cp.distanceToTarget = courseplay:distance(cx, cz, ctx, ctz);
	-- courseplay:debug(('ctx=%.2f, ctz=%.2f, cx=%.2f, cz=%.2f, distanceToTarget=%.2f'):format(ctx, ctz, cx, cz, self.cp.distanceToTarget), 2);
	local fwd;
	local distToChange;

	-- coordinates of coli
	local tx, ty, tz = localToWorld(self.cp.DirectionNode, 0, 1, 3); --local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
	-- local direction of from DirectionNode to waypoint
	local lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, cx, cty, cz);
	-- world direction of from DirectionNode to waypoint
	local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, 0, lz);


	if self.cp.mode == 4 or self.cp.mode == 6 then
		if self.Waypoints[self.recordnumber].turn ~= nil then
			self.cp.isTurning = self.Waypoints[self.recordnumber].turn
		end
		if self.cp.abortWork ~= nil and self.cp.tipperFillLevelPct == 0 then
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


	-- BEACON LIGHTS
	if self.cp.beaconLightsMode == 1 then --on streets only
		local combineNeedsBeacon = self.cp.isCombine and (self.fillLevel / self.capacity) > 0.8;
		if (self.cp.speeds.sl == 3 and not self.beaconLightsActive)
		or (self.cp.speeds.sl ~= 3 and self.beaconLightsActive and not combineNeedsBeacon)
		or (self.cp.mode == 6 and combineNeedsBeacon and not self.beaconLightsActive)
		or (self.cp.mode == 7 and self.isAIThreshing == self.beaconLightsActive) then
			self:setBeaconLightsVisibility(not self.beaconLightsActive);
		end;

	elseif self.cp.beaconLightsMode == 2 then --always
		if not self.beaconLightsActive then
			self:setBeaconLightsVisibility(true);
		end;

	elseif self.cp.beaconLightsMode == 3 then --never
		if self.beaconLightsActive then
			self:setBeaconLightsVisibility(false);
		end;
	end;


	-- the tipper that is currently loaded/unloaded
	local activeTipper;
	local isBypassing = false


	-- ### WAITING POINTS - START
	if self.Waypoints[self.cp.lastRecordnumber].wait and self.wait then
		-- set wait time end
		if self.cp.waitTimer == nil and self.cp.waitTime > 0 then
			self.cp.waitTimer = self.timer + self.cp.waitTime * 1000;
		end;

		if self.cp.mode == 3 and self.cp.tipperAttached then
			courseplay:handleMode3(self, self.cp.tipperFillLevelPct, allowedToDrive, dt);

		elseif self.cp.mode == 4 then
			local drive_on = false
			if self.cp.lastRecordnumber == self.cp.startWork and self.cp.tipperFillLevelPct ~= 0 then
				self.wait = false
			elseif self.cp.lastRecordnumber == self.cp.stopWork and self.cp.abortWork ~= nil then
				self.wait = false
			elseif self.cp.waitPoints[3] and self.cp.lastRecordnumber == self.cp.waitPoints[3] then
				local isInWorkArea = self.recordnumber > self.cp.startWork and self.recordnumber <= self.cp.stopWork;
				if self.cp.tipperAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.tippers ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, self.cp.tipperFillLevelPct, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end;
				if courseplay:timerIsThrough(self, "fillLevelChange") or self.cp.prevFillLevelPct == nil then
					if self.cp.prevFillLevelPct ~= nil and self.cp.tipperFillLevelPct == self.cp.prevFillLevelPct and self.cp.tipperFillLevelPct >= self.cp.refillUntilPct then
						drive_on = true
					end
					self.cp.prevFillLevelPct = self.cp.tipperFillLevelPct
					courseplay:setCustomTimer(self, "fillLevelChange", 7);
				end

				if self.cp.tipperFillLevelPct >= self.cp.refillUntilPct or drive_on then
					self.wait = false
				end
				self.cp.infoText = string.format(courseplay:loc("COURSEPLAY_LOADING_AMOUNT"), self.cp.tipperFillLevel, self.cp.tipperCapacity)
			end
		elseif self.cp.mode == 6 then
			if self.cp.lastRecordnumber == self.cp.startWork then
				self.wait = false
			elseif self.cp.lastRecordnumber == self.cp.stopWork and self.cp.abortWork ~= nil then
				self.wait = false
			elseif self.cp.lastRecordnumber ~= self.cp.startWork and self.cp.lastRecordnumber ~= self.cp.stopWork then 
				courseplay:setGlobalInfoText(self, 'UNLOADING_BALE');
				if self.cp.tipperFillLevelPct == 0 or drive_on then
					self.wait = false
				end;
			end;
		elseif self.cp.mode == 7 then
			if self.cp.lastRecordnumber == self.cp.startWork then
				if self.fillLevel > 0 then
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
				-- drive on if tipperFillLevelPct doesn't change and fill level is < 100-self.cp.followAtFillLevel
				courseplay:handle_mode8(self)
				local drive_on = false
				if courseplay:timerIsThrough(self, "fillLevelChange") or self.cp.prevFillLevelPct == nil then
					if self.cp.prevFillLevelPct ~= nil and self.cp.tipperFillLevelPct == self.cp.prevFillLevelPct and self.cp.tipperFillLevelPct < self.cp.followAtFillLevel then
						drive_on = true
					end
					self.cp.prevFillLevelPct = self.cp.tipperFillLevelPct
					courseplay:setCustomTimer(self, "fillLevelChange", 7);
				end
				if self.cp.tipperFillLevelPct == 0 or drive_on then
					self.wait = false
					self.cp.prevFillLevelPct = nil
					self.cp.isUnloaded = true
				end
			end
		elseif self.cp.mode == 9 then
			self.wait = false;
		else
			courseplay:setGlobalInfoText(self, 'WAIT_POINT');
		end

		-- wait time passed -> continue driving
		if self.cp.waitTimer and self.timer > self.cp.waitTimer then
			self.cp.waitTimer = nil
			self.wait = false
		end
		allowedToDrive = false
	-- ### WAITING POINTS - END

	-- ### NON-WAITING POINTS
	else
		-- MODES 1 & 2: unloading in trigger
		if (self.cp.mode == 1 or (self.cp.mode == 2 and self.cp.isLoaded)) and self.cp.tipperFillLevel ~= nil and self.cp.tipRefOffset ~= nil and self.cp.tipperAttached then
			if self.cp.currentTipTrigger == nil and self.cp.tipperFillLevel > 0 and self.recordnumber > 2 and self.recordnumber < self.maxnumber and not self.Waypoints[self.recordnumber].rev then
				courseplay:doTriggerRaycasts(self, 'tipTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
			end;

			allowedToDrive = courseplay:handle_mode1(self, allowedToDrive);
		end;

		-- COMBI MODE / BYPASSING
		if (((self.cp.mode == 2 or self.cp.mode == 3) and self.recordnumber < 2) or self.cp.activeCombine) and self.cp.tipperAttached then
			self.cp.inTraffic = false
			courseplay:handle_mode2(self, dt);
			return;
		elseif (self.cp.mode == 2 or self.cp.mode == 3) and self.recordnumber < 3 then
			--isBypassing = true
			--lx, lz = courseplay:isTheWayToTargetFree(self,lx, lz)
		elseif self.cp.mode == 6 and self.cp.hasBaleLoader and (self.recordnumber == self.cp.stopWork - 4 or (self.cp.abortWork ~= nil and self.recordnumber == self.cp.abortWork)) then
			--isBypassing = true
			--lx, lz = courseplay:isTheWayToTargetFree(self,lx, lz)
		elseif self.cp.mode ~= 7 then
			if self.cp.modeState ~= 0 then
				courseplay:setModeState(self, 0);
			end;
		end;

		-- MODE 3: UNLOADING
		if self.cp.mode == 3 and self.cp.tipperAttached and self.recordnumber >= 2 and self.cp.modeState == 0 then
			courseplay:handleMode3(self, self.cp.tipperFillLevelPct, allowedToDrive, dt);
		end;

		-- MODE 4: REFILL SPRAYER or SEEDER
		if self.cp.mode == 4 then
			if self.cp.tipperAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
				local isInWorkArea = self.recordnumber > self.cp.startWork and self.recordnumber <= self.cp.stopWork;
				if self.tippers ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, self.cp.tipperFillLevelPct, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end
			end;
		end

		-- MAP WEIGHT STATION
		if courseplay:canUseWeightStation(self) then
			if self.cp.curMapWeightStation ~= nil or (self.cp.fillTrigger ~= nil and courseplay.triggers.all[self.cp.fillTrigger].isWeightStation) then
				allowedToDrive = courseplay:handleMapWeightStation(self, allowedToDrive);
			elseif courseplay:canScanForWeightStation(self) then
				courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
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
				courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
				if self.cp.fillTrigger ~= nil then
					if courseplay.triggers.all[self.cp.fillTrigger].isDamageModTrigger then
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

		-- MODE 8: REFILL LIQUID MANURE TRANSPORT
		if self.cp.mode == 8 then
			courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
			if self.cp.tipperAttached then
				if self.tippers ~= nil then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, self.cp.tipperFillLevelPct, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end;
			end;
		end;

		--FUEL LEVEL + REFILLING
		if self.fuelCapacity > 0 then
			local currentFuelPercentage = (self.fuelFillLevel / self.fuelCapacity + 0.0001) * 100;
			if currentFuelPercentage < 5 then
				allowedToDrive = false;
				courseplay:setGlobalInfoText(self, 'FUEL_MUST');
			elseif currentFuelPercentage < 20 and not self.isFuelFilling then
				courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
				if self.cp.fillTrigger ~= nil and courseplay.triggers.all[self.cp.fillTrigger].isGasStationTrigger then
					self.cp.isInFilltrigger = true;
				end;
				courseplay:setGlobalInfoText(self, 'FUEL_SHOULD');
				if self.fuelFillTriggers[1] then
					allowedToDrive = courseplay:brakeToStop(self);
					self:setIsFuelFilling(true, self.fuelFillTriggers[1].isEnabled, false);
				end;
			elseif self.isFuelFilling and currentFuelPercentage < 99.9 then
				allowedToDrive = courseplay:brakeToStop(self);
				courseplay:setGlobalInfoText(self, 'FUEL_IS');
			end;
			if self.fuelFillTriggers[1] and self.cp.fillTrigger and courseplay.triggers.all[self.cp.fillTrigger].isGasStationTrigger then
				courseplay:debug(nameNum(self) .. ': self.fuelFillTriggers[1] ~= nil -> resetting "self.cp.fillTrigger"', 1);
				self.cp.fillTrigger = nil;
			end;
		end;

		-- WATER WARNING
		if self.showWaterWarning then
			allowedToDrive = false;
			courseplay:setGlobalInfoText(self, 'WATER');
		end;

		-- STOP AND END OR TRIGGER
		if self.cp.stopAtEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil) then
			allowedToDrive = false;
			courseplay:setGlobalInfoText(self, 'END_POINT');
		end;
	end;
	-- ### NON-WAITING POINTS END


	--------------------------------------------------


	local workArea = false;
	local workSpeed = 0;
	local isFinishingWork = false;
	-- MODE 4
	if self.cp.mode == 4 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.cp.tipperAttached then
		allowedToDrive, workArea, workSpeed, isFinishingWork = courseplay:handle_mode4(self, allowedToDrive, workSpeed, self.cp.tipperFillLevelPct);
		if not workArea and self.cp.tipperFillLevelPct < self.cp.refillUntilPct then
			courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end;

	-- MODE 6
	elseif self.cp.mode == 6 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed, activeTipper, isFinishingWork = courseplay:handle_mode6(self, allowedToDrive, workSpeed, self.cp.tipperFillLevelPct, lx, lz);

		if not workArea and self.cp.currentTipTrigger == nil and self.cp.tipperFillLevel and self.cp.tipperFillLevel > 0 and self.capacity == nil and self.cp.tipRefOffset ~= nil and not self.Waypoints[self.recordnumber].rev then
			courseplay:doTriggerRaycasts(self, 'tipTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end;

	-- MODE 9
	elseif self.cp.mode == 9 then
		allowedToDrive = courseplay:handle_mode9(self, self.cp.tipperFillLevelPct, allowedToDrive, dt);
	end;
	self.cp.inTraffic = false;

	-- AI TRACTOR DIRECTION
	local dx,_,dz = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);
	local length = Utils.vector2Length(dx,dz);
	if self.cp.turnStage == 0 then
		self.aiTractorDirectionX = dx/length;
		self.aiTractorDirectionZ = dz/length;
	end

	-- HANDLE TIPPER COVER
	if self.cp.tipperHasCover and self.cp.automaticCoverHandling and (self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 5 or self.cp.mode == 6) then
		local showCover = false;

		if self.cp.mode ~= 6 then
			local minCoverWaypoint = self.cp.mode == 1 and 4 or 3;
			showCover = self.recordnumber >= minCoverWaypoint and self.recordnumber < self.maxnumber and self.cp.currentTipTrigger == nil;
		else
			showCover = not workArea and self.cp.currentTipTrigger == nil;
		end;

		courseplay:openCloseCover(self, dt, showCover, self.cp.currentTipTrigger ~= nil);
	end;

	-- CHECK TRAFFIC
	allowedToDrive = courseplay:checkTraffic(self, true, allowedToDrive)
	
	if self.cp.waitForTurnTime > self.timer then
		allowedToDrive = courseplay:brakeToStop(self)
	end 

	-- MODE 9 --TODO (Jakob): why is this in drive instead of mode9?
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
			if self.cp.tipperFillLevelPct == 0 then
				allowedToDrive = false
				courseplay:setGlobalInfoText(self, 'WORK_END');
			else
				courseplay:setIsLoaded(self, true);
				courseplay:setRecordNumber(self, i + 2);
			end
		end
	end
	-- MODE 9 END



	-- allowedToDrive false -> STOP OR HOLD POSITION
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
	if 	((self.cp.mode == 1 or self.cp.mode == 5 or self.cp.mode == 8) and (isAtStart or isAtEnd)) or
		((self.cp.mode == 2 or self.cp.mode == 3) and isAtEnd) or
		(self.cp.mode == 9 and self.recordnumber > self.cp.shovelFillStartPoint and self.recordnumber <= self.cp.shovelFillEndPoint) or
		(not workArea and self.wait and ((isAtEnd and self.Waypoints[self.recordnumber].wait) or courseplay:waypointsHaveAttr(self, self.recordnumber, 0, 2, "wait", true, false))) or 
		(isAtEnd and self.Waypoints[self.recordnumber].rev) or
		(not isAtEnd and (self.Waypoints[self.recordnumber].rev or self.Waypoints[self.recordnumber + 1].rev or self.Waypoints[self.recordnumber + 2].rev)) or
		(workSpeed ~= nil and workSpeed == 0.5) 
	then
		--self.cp.speeds.sl = 1;
		refSpeed = self.cp.speeds.turn;
	elseif ((self.cp.mode == 2 or self.cp.mode == 3) and isAtStart) or (workSpeed ~= nil and workSpeed == 1) then
		--self.cp.speeds.sl = 2;
		refSpeed = self.cp.speeds.field;
	else
		if self.cp.mode ~= 7 then
		--self.cp.speeds.sl = 3;
			refSpeed = self.cp.speeds.street;
		end
		if self.cp.speeds.useRecordingSpeed and self.Waypoints[self.recordnumber].speed ~= nil then
			refSpeed = Utils.clamp(refSpeed, 3/3600, self.Waypoints[self.recordnumber].speed);
		end;
	end;
	
	if self.cp.collidingVehicleId ~= nil then
		refSpeed = courseplay:regulateTrafficSpeed(self, refSpeed, allowedToDrive);
	end
	
	if self.cp.currentTipTrigger ~= nil then
		if self.cp.currentTipTrigger.bunkerSilo ~= nil then
			refSpeed = Utils.getNoNil(self.cp.speeds.unload, 3/3600);
		else
			refSpeed = self.cp.speeds.turn;
		end;
		self.cp.speeds.sl = 1;
	elseif self.cp.isInFilltrigger then
		refSpeed = self.cp.speeds.turn;
		if self.lastSpeedReal > self.cp.speeds.turn then
			courseplay:brakeToStop(self);
		end;
		self.cp.speeds.sl = 1;
		self.cp.isInFilltrigger = false;
	end;

	--finishing field work- go straight till tool is ready
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
	elseif self.cp.isReverseBackToPoint then
		if self.cp.reverseBackToPoint then
			local _, _, zDis = worldToLocal(self.rootNode, self.cp.reverseBackToPoint.x, self.cp.reverseBackToPoint.y, self.cp.reverseBackToPoint.z);
			if zDis < 0 then
				fwd = false;
				lx = 0;
				lz = 1;
			else
				self.cp.reverseBackToPoint = nil;
			end;
		else
			self.cp.isReverseBackToPoint = false;
		end;
	end
	
	-- Speed Control
	if self.cp.maxFieldSpeed ~= 0 then
		refSpeed = min(self.cp.maxFieldSpeed, refSpeed);
	end
	
	if self.isRealistic then
		courseplay:setMRSpeed(self, refSpeed, self.cp.speeds.sl, allowedToDrive, workArea);
	else
		
		courseplay:setSpeed(self, refSpeed, self.cp.speeds.sl)
	end

	-- DISTANCE TO CHANGE WAYPOINT
	if self.recordnumber == 1 or self.recordnumber == self.maxnumber - 1 or self.Waypoints[self.recordnumber].turn then
		if self.cp.hasSpecializationArticulatedAxis then
			distToChange = self.cp.mode == 9 and 2 or 1; -- ArticulatedAxis vehicles
		else
			distToChange = 0.5;
		end;
	elseif self.recordnumber + 1 <= self.maxnumber then
		local beforeReverse = (self.Waypoints[self.recordnumber + 1].rev and (self.Waypoints[self.recordnumber].rev == false))
		local afterReverse = (not self.Waypoints[self.recordnumber + 1].rev and self.Waypoints[self.cp.lastRecordnumber].rev)
		if (self.Waypoints[self.recordnumber].wait or beforeReverse) and self.Waypoints[self.recordnumber].rev == false then -- or afterReverse or self.recordnumber == 1
			if self.cp.hasSpecializationArticulatedAxis then
				distToChange = 2; -- ArticulatedAxis vehicles
			else
				distToChange = 1;
			end;
		elseif (self.Waypoints[self.recordnumber].rev and self.Waypoints[self.recordnumber].wait) or afterReverse then
			if self.cp.hasSpecializationArticulatedAxis then
				distToChange = 4; -- ArticulatedAxis vehicles
			else
				distToChange = 2;
			end;
		elseif self.Waypoints[self.recordnumber].rev then
			if self.cp.hasSpecializationArticulatedAxis then
				distToChange = 4; -- ArticulatedAxis vehicles
			else
				distToChange = 2; --orig:1
			end;
		elseif self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7 then
			distToChange = 5;
		elseif self.cp.mode == 9 then
			distToChange = 4;
		else
			if self.cp.hasSpecializationArticulatedAxis then
				distToChange = 5; -- ArticulatedAxis vehicles
			else
				distToChange = 2.85; --orig: 5
			end;
		end;
	else
		if self.cp.hasSpecializationArticulatedAxis then
			distToChange = 5; -- ArticulatedAxis vehicles stear better with a longer change distance
		else
			distToChange = 2.85; --orig: 5
		end;
	end



	-- record shortest distance to the next waypoint
	if self.cp.shortestDistToWp == nil or self.cp.shortestDistToWp > self.cp.distanceToTarget then
		self.cp.shortestDistToWp = self.cp.distanceToTarget
	end

	if beforeReverse then
		self.cp.shortestDistToWp = nil
	end

	if self.invertedDrivingDirection then
		lx = -lx
		lz = -lz
	end

	-- if distance grows i must be circling
	if self.cp.distanceToTarget > self.cp.shortestDistToWp and self.recordnumber > 3 and self.cp.distanceToTarget < 15 and self.Waypoints[self.recordnumber].rev ~= true then
		distToChange = self.cp.distanceToTarget + 1
	end

	-- Better stearing on MR Articulated Axis vehicles on MR Engine v1.3.19 and below. By Claus G. Pedersen
	if self.isRealistic and self.cp.hasSpecializationArticulatedAxis and (not courseplay.moreRealisticVersion or courseplay.moreRealisticVersion < 1.0320) then
		-- Get the rotation direction from the vehicle to the drive direction note
		local x,_,z = localDirectionToWorld(self.cp.DirectionNode, lx, 0, lz);
		local dirRot = Utils.getYRotationFromDirection(x, z);

		-- If we are a Wheelloader and we are reversing, the curent Rotation needs to be inverted to work.
		local curRot = self.articulatedAxis.curRot;
		if not fwd and courseplay:isWheelloader(self) then
			curRot = curRot * -1;
		end;

		-- Here is the magic calculation to find the real lx and lz values based on the vehicle curRot
		local steerAngle = (dirRot - courseplay:getRealWorldRotation(self.cp.DirectionNode)) - curRot;
		lx, lz = Utils.getDirectionFromYRotation(steerAngle);

	end;

	if self.cp.distanceToTarget > distToChange or WpUnload or WpLoadEnd or isFinishingWork then
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
				courseplay:setRecordNumber(self, self.recordnumber + 1);
			end
		else -- last waypoint: reset some variables
			if (self.cp.mode == 4 or self.cp.mode == 6) and not self.cp.hasUnloadingRefillingCourse then
			else
				courseplay:setRecordNumber(self, 1);
			end
			self.cp.isUnloaded = false
			self.cp.stopAtEnd = false
			courseplay:setIsLoaded(self, false);
			self.cp.isRecording = false
			self.cp.canDrive = true
		end
	end
	
end


function courseplay:setTrafficCollision(vehicle, lx, lz, workArea) --!!!
	--local goForRaycast = vehicle.cp.mode == 1 or (vehicle.cp.mode == 3 and vehicle.recordnumber > 3) or vehicle.cp.mode == 5 or vehicle.cp.mode == 8 or ((vehicle.cp.mode == 4 or vehicle.cp.mode == 6) and vehicle.recordnumber > vehicle.cp.stopWork) or (vehicle.cp.mode == 2 and vehicle.recordnumber > 3)
	--print("lx: "..tostring(lx).."	distance: "..tostring(distance))
	local maxlx = 0.5; --sin(maxAngle); --sin30°  old was : 0.7071067 sin 45°
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
	if vehicle.cp.trafficCollisionTriggers[1] ~= nil then 
		AIVehicleUtil.setCollisionDirection(vehicle.cp.DirectionNode, vehicle.cp.trafficCollisionTriggers[1], colDirX, colDirZ);
		local recordNumber = vehicle.recordnumber
		if vehicle.cp.collidingVehicleId == nil then
			for i=2,vehicle.cp.numTrafficCollisionTriggers do
				if workArea or recordNumber + i > vehicle.maxnumber or recordNumber < 2 then
					AIVehicleUtil.setCollisionDirection(vehicle.cp.trafficCollisionTriggers[i-1], vehicle.cp.trafficCollisionTriggers[i], 0, -1);
				else
					local nodeX,nodeY,nodeZ = getWorldTranslation(vehicle.cp.trafficCollisionTriggers[i]);
					local nodeDirX,nodeDirY,nodeDirZ,distance = courseplay:getWorldDirection(nodeX,nodeY,nodeZ, vehicle.Waypoints[recordNumber+i].cx,nodeY,vehicle.Waypoints[recordNumber+i].cz);
					if distance < 5.5 and recordNumber + i +1 <= vehicle.maxnumber then
							nodeDirX,nodeDirY,nodeDirZ,distance = courseplay:getWorldDirection(nodeX,nodeY,nodeZ, vehicle.Waypoints[recordNumber+i+1].cx,nodeY,vehicle.Waypoints[recordNumber+i+1].cz);
					end;
						nodeDirX,nodeDirY,nodeDirZ = worldDirectionToLocal(vehicle.cp.trafficCollisionTriggers[i-1], nodeDirX,nodeDirY,nodeDirZ);
						AIVehicleUtil.setCollisionDirection(vehicle.cp.trafficCollisionTriggers[i-1], vehicle.cp.trafficCollisionTriggers[i], nodeDirX, nodeDirZ);
				end;
			end
		end
	end;
end;


function courseplay:checkTraffic(vehicle, displayWarnings, allowedToDrive)
	local ahead = false
	local collisionVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId]
	if collisionVehicle ~= nil and not (vehicle.cp.mode == 9 and (collisionVehicle.allowFillFromAir or (collisionVehicle.cp and collisionVehicle.cp.mode9TrafficIgnoreVehicle))) then
		local vx, vy, vz = getWorldTranslation(vehicle.cp.collidingVehicleId);
		local tx, ty, tz = worldToLocal(vehicle.aiTrafficCollisionTrigger, vx, vy, vz);
		local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode);
		local halfLength =  (collisionVehicle.sizeLength or 5) * 0.5;
		local x1,z1 = AIVehicleUtil.getDriveDirection(vehicle.cp.collidingVehicleId, x, y, z);
		if z1 > -0.9 then -- tractor in front of vehicle face2face or beside < 4 o'clock
			ahead = true
		end;

		if abs(tx) > 5 and collisionVehicle.rootNode ~= nil and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then
			courseplay:debug(('%s: checkTraffic:\tcall deleteCollisionVehicle()'):format(nameNum(vehicle)), 3);
			courseplay:deleteCollisionVehicle(vehicle);
			return allowedToDrive;
		end;

		if collisionVehicle.lastSpeedReal == nil or collisionVehicle.lastSpeedReal*3600 < 5 or ahead then
			-- courseplay:debug(('%s: checkTraffic:\tcall distance=%.2f'):format(nameNum(vehicle), tz-halfLength), 3);
			if tz <= halfLength + 2 then --TODO: abs(tz) ?
				allowedToDrive = false;
				vehicle.cp.inTraffic = true;
				courseplay:debug(('%s: checkTraffic:\tstop'):format(nameNum(vehicle)), 3);
			elseif vehicle.lastSpeedReal*3600 > 10 then
				-- courseplay:debug(('%s: checkTraffic:\tbrake'):format(nameNum(vehicle)), 3);
				allowedToDrive = courseplay:brakeToStop(vehicle);
			else
				-- courseplay:debug(('%s: checkTraffic:\tdo nothing - go, but set "vehicle.cp.isTrafficBraking"'):format(nameNum(vehicle)), 3);
				vehicle.cp.isTrafficBraking = true;
			end;
		end;
	end;

	if displayWarnings and vehicle.cp.inTraffic then
		courseplay:setGlobalInfoText(vehicle, 'TRAFFIC');
	end;
	return allowedToDrive;
end

function courseplay:deleteCollisionVehicle(vehicle)
	if vehicle.cp.collidingVehicleId ~= nil  then
		vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] = nil
		--vehicle.CPnumCollidingVehicles = max(vehicle.CPnumCollidingVehicles - 1, 0);
		--if vehicle.CPnumCollidingVehicles == 0 then
		--vehicle.numCollidingVehicles[triggerId] = max(vehicle.numCollidingVehicles[triggerId]-1, 0);
		vehicle.cp.collidingObjects[4][vehicle.cp.collidingVehicleId] = nil
		vehicle.cp.collidingVehicleId = nil
		courseplay:debug(string.format('%s: 	deleteCollisionVehicle: setting "collidingVehicleId" to nil', nameNum(vehicle)), 3);
	end
end

function courseplay:setSpeed(vehicle, refSpeed, sl)
	local newSpeed = math.max(refSpeed*3600,3)	
	if vehicle.cruiseControl.state == 0 then
		vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
	end 
	vehicle.cruiseControl.minSpeed = newSpeed   --TODO(Tom) thats rape, make it nice and clear when you know how
end
	
function dummy()
	
	if vehicle.lastSpeedSave ~= vehicle.lastSpeedReal*3600 then
		local refSpeedKph = refSpeed * 3600;
		local lastSpeedKph = vehicle.lastSpeed * 3600;

		if refSpeedKph == 1 then
			refSpeed = 1.6 / 3600;
			refSpeedKph = 1.6;
		end
		local trueRpm = vehicle.motor.lastMotorRpm*100/vehicle.cp.orgRpm[3];
		local targetRpm = vehicle.motor.maxRpm[sl]*100/vehicle.cp.orgRpm[3];
		local newLimit = 0;
		local oldLimit = 0 ;
		if vehicle.ESLimiter ~= nil then 
			oldLimit =  vehicle.ESLimiter.percentage[sl+1];
		else
			oldLimit = targetRpm;
		end;

		local speedDelta = refSpeedKph - lastSpeedKph; -- accelerate
		if speedDelta > 15 then
			if sl == 2 then
				newLimit = 75;
			else
				newLimit = 100;
			end;
		elseif speedDelta > 4 then
			newLimit = oldLimit + 1;
		elseif speedDelta > 0.5 then
			newLimit = oldLimit + 0.1;
		elseif speedDelta > 0 then
			newLimit = oldLimit;
		end;
		if oldLimit - trueRpm > 10 then
			if speedDelta < 1 then
				newLimit = trueRpm;
			end;
		end;

		speedDelta = lastSpeedKph - refSpeedKph; --decelerate
		if speedDelta > 8 and vehicle.cp.isTurning == nil then
			if sl == 1 then
				newLimit = 20;
			else
				newLimit = oldLimit - 3;
			end;
		elseif speedDelta > 3 then
			newLimit = oldLimit - 1;
		elseif speedDelta > 1 then
			newLimit = oldLimit - 0.75;
		elseif speedDelta > 0.5 then
			newLimit = oldLimit - 0.25;
		elseif speedDelta > 0 then
			newLimit = oldLimit;
		end;

		newLimit = Utils.clamp(newLimit, 0, 100);

		if vehicle.ESLimiter ~= nil and vehicle.ESLimiter.maxRPM[5] ~= nil then
			vehicle:setNewLimit(sl + 1, newLimit, false, true);
		elseif vehicle.ESLimiter ~= nil and vehicle.ESLimiter.maxRPM[5] == nil then
			--ESlimiter < V3
		else
			vehicle.motor.maxRpm[sl] = Utils.clamp(newLimit * vehicle.cp.orgRpm[3]/100, vehicle.motor.minRpm, vehicle.cp.orgRpm[3]);
		end;

		vehicle.lastSpeedSave = vehicle.lastSpeedReal*3600;
	end;

	-- slipping notification
	if vehicle.lastSpeedSave < 0.5 and not vehicle.cp.inTraffic and not vehicle.Waypoints[vehicle.recordnumber].wait then
		if vehicle.cp.timers.slippingWheels == nil or vehicle.cp.timers.slippingWheels == 0 then
			courseplay:setCustomTimer(vehicle, 'slippingWheels', 5);
		elseif courseplay:timerIsThrough(vehicle, 'slippingWheels') then
			courseplay:setGlobalInfoText(vehicle, 'SLIPPING_0');
		end;

	-- reset timer
	elseif vehicle.cp.timers.slippingWheels ~= 0 then
		vehicle.cp.timers.slippingWheels = 0;
	end;
end;

function courseplay:openCloseCover(vehicle, dt, showCover, isAtTipTrigger)
	for i,twc in pairs(vehicle.cp.tippersWithCovers) do
		local tIdx, coverType, showCoverWhenTipping, coverItems = twc.tipperIndex, twc.coverType, twc.showCoverWhenTipping, twc.coverItems;
		local tipper = vehicle.tippers[tIdx];

		-- SMK-34 et al.
		if coverType == 'setPlane' and tipper.plane.bOpen == showCover then
			if showCoverWhenTipping and isAtTipTrigger and not showCover then
				--
			else
				tipper:setPlane(not showCover);
			end;

		-- Hobein 18t et al.
		elseif coverType == 'setCoverState' and tipper.cover.state ~= showCover then
			tipper:setCoverState(showCover);

		-- TUW et al.
		elseif coverType == 'planeOpen' then
			if showCover and tipper.planeOpen then
				tipper:setAnimationTime(3, tipper.animationParts[3].offSet, false);
			elseif not showCover and not tipper.planeOpen then
				tipper:setAnimationTime(3, tipper.animationParts[3].animDuration, false);
			end;

		-- Marston / setSheet
		elseif coverType == 'setSheet' and tipper.sheet.isActive ~= showCover then
			tipper:setSheet(showCover);

		-- default Giants trailers
		elseif coverType == 'defaultGiants' then
			for _,ci in pairs(coverItems) do
				if getVisibility(ci) ~= showCover then
					setVisibility(ci, showCover);
				end;
			end;

		-- setCoverState (Giants Marshall DLC)
		elseif coverType == 'setCoverStateGiants' and tipper.isCoverOpen == showCover then
			tipper:setCoverState(not showCover);
		end;
	end; --END for i,tipperWithCover in vehicle.cp.tippersWithCovers
end;

function courseplay:refillSprayer(vehicle, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt)
	-- for i,activeTool in pairs(vehicle.tippers) do --TODO (Jakob): delete
	for i=1, vehicle.cp.numWorkTools do
		local activeTool = vehicle.tippers[i];
		local isSpecialSprayer = false
		local fillTrigger;
		isSpecialSprayer, allowedToDrive, lx, lz = courseplay:handleSpecialSprayer(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, 'pull');
		if isSpecialSprayer then
			return allowedToDrive,lx,lz
		end;

		-- SPRAYER
		if courseplay:isSprayer(activeTool) then
			-- print(('\tworkTool %d (%q)'):format(i, nameNum(activeTool)));
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if trigger.isSprayerFillTrigger and courseplay:fillTypesMatch(trigger, activeTool) then 
					--print('\t\tslow down, it\'s a sprayerFillTrigger');
					vehicle.cp.isInFilltrigger = true
				end
			end;

			local activeToolFillLevel;
			if activeTool.fillLevel ~= nil and activeTool.capacity ~= nil then
				activeToolFillLevel = (activeTool.fillLevel / activeTool.capacity) * 100;
			end;

			if fillTrigger == nil then
				if activeTool.fillTriggers[1] ~= nil and activeTool.fillTriggers[1].isSprayerFillTrigger then
					-- print('\t\tset local fillTrigger to activeTool.sprayerFillTriggers[1], nil cp.fillTrigger');
					fillTrigger = activeTool.fillTriggers[1];
					vehicle.cp.fillTrigger = nil; --TODO (Jakob): if i == vehicle.cp.numWorkTools then vehicle.cp.fillTrigger = nil; end; (prevent nilling if there are other tools left to be filled)
				end;
			end;

			local fillTypesMatch = courseplay:fillTypesMatch(fillTrigger, activeTool);

			local canRefill = (activeToolFillLevel ~= nil and activeToolFillLevel < driveOn) and fillTypesMatch;
			--ManureLager: activeTool.ReFillTrigger has to be nil so it doesn't refill
			if vehicle.cp.mode == 8 then
				canRefill = canRefill and activeTool.ReFillTrigger == nil and not courseplay:waypointsHaveAttr(vehicle, vehicle.recordnumber, -2, 2, 'wait', true, false);

				if activeTool.isSpreaderInRange ~= nil and activeTool.isSpreaderInRange.manureTriggerc ~= nil then
					canRefill = false;
				end;

				--TODO: what to do when transfering from one ManureLager to another?
			end;

			if canRefill then
				allowedToDrive = false;
				--courseplay:handleSpecialTools(vehicle,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
				courseplay:handleSpecialTools(vehicle,activeTool,nil,nil,nil,allowedToDrive,false,false)
				local sprayer = activeTool.fillTriggers[1];
				if not activeTool.isFilling then
					activeTool:setIsFilling(true);
				end;
				
				if sprayer.trailerInTrigger == activeTool then --Feldrand-Container Guellebomber
					sprayer.fill = true;
				end;

				vehicle.cp.infoText = courseplay:loc("COURSEPLAY_LOADING_AMOUNT"):format(activeTool.fillLevel, activeTool.capacity);
			elseif vehicle.cp.isLoaded or not vehicle.cp.stopForLoading then
				if activeTool.isFilling then
					activeTool:setIsFilling(false);
				end;
				courseplay:handleSpecialTools(vehicle,activeTool,nil,nil,nil,allowedToDrive,false,false)
				vehicle.cp.fillTrigger = nil
			end;
		end;

		-- SOWING MACHINE
		if courseplay:isSowingMachine(activeTool) then
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger]
				if trigger.isSowingMachineFillTrigger then
					--print("slow down , its a SowingMachineFillTrigger")
					vehicle.cp.isInFilltrigger = true
				end
			end
			if fillLevelPct < driveOn and activeTool.fillTriggers[1] ~= nil and activeTool.fillTriggers[1].isSowingMachineFillTrigger then
				--print(tableShow(activeTool.fillTriggers,"activeTool.fillTriggers"))
				if not activeTool.isFilling then
					activeTool:setIsFilling(true);
				end;
				allowedToDrive = false;
				vehicle.cp.infoText = courseplay:loc('COURSEPLAY_LOADING_AMOUNT'):format(activeTool.fillLevel, activeTool.capacity);
			elseif activeTool.fillTriggers[1] ~= nil then
				if activeTool.isFilling then
					activeTool:setIsFilling(false);
				end;
				vehicle.cp.fillTrigger = nil
			end;
		end;
		if vehicle.cp.stopForLoading then
			courseplay:handleSpecialTools(vehicle,activeTool,nil,nil,nil,allowedToDrive,true,false)
			allowedToDrive = false
		end
	end;

	return allowedToDrive,lx,lz
end;

function courseplay:regulateTrafficSpeed(vehicle,refSpeed,allowedToDrive)
	if vehicle.cp.isTrafficBraking then
		return refSpeed
	end
	if vehicle.cp.collidingVehicleId ~= nil then
		local collisionVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId];
		local vehicleBehind = false
		if collisionVehicle == nil then
			courseplay:debug(nameNum(vehicle)..": regulateTrafficSpeed(1216):	setting vehicle.cp.collidingVehicleId nil",3)
			vehicle.cp.collidingVehicleId = nil
			vehicle.CPnumCollidingVehicles = max(vehicle.CPnumCollidingVehicles-1, 0);
			return refSpeed
		else
			local name = getName(vehicle.cp.collidingVehicleId)
			courseplay:debug(nameNum(vehicle)..": regulateTrafficSpeed:	 "..tostring(name),3)
		end
		local x, y, z = getWorldTranslation(vehicle.cp.collidingVehicleId)
		local x1, y1, z1 = worldToLocal(vehicle.rootNode, x, y, z)
		if z1 < 0 or abs(x1) > 5 and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then -- vehicle behind tractor
			vehicleBehind = true
		end
		local distance = 0
		if collisionVehicle.rootNode ~= nil then
			distance = courseplay:distanceToObject(vehicle, collisionVehicle)
		end
		if collisionVehicle.rootNode == nil or collisionVehicle.lastSpeedReal == nil or (distance > 40) or vehicleBehind then
			courseplay:debug(string.format("%s: v.rootNode= %s,v.lastSpeedReal= %s, distance: %f, vehicleBehind= %s",nameNum(vehicle),tostring(collisionVehicle.rootNode),tostring(collisionVehicle.lastSpeedReal),distance,tostring(vehicleBehind)),3)
			courseplay:deleteCollisionVehicle(vehicle)
			--courseplay:debug(nameNum(vehicle)..": regulateTrafficSpeed(1230):	setting vehicle.cp.collidingVehicleId nil",3)
		
		else
			if allowedToDrive and not (vehicle.cp.mode == 9 and collisionVehicle.allowFillFromAir) then
				if (vehicle.lastSpeed*3600) - (collisionVehicle.lastSpeedReal*3600) > 15 or z1 < 3 then
					vehicle.cp.TrafficBrake = true
				else
					return min(collisionVehicle.lastSpeedReal,refSpeed)
				end
			end
		end
	end
	return refSpeed
end

function courseplay:brakeToStop(vehicle)
	if vehicle.isRealistic then
		return false
	end
	if vehicle.lastSpeedReal > 1/3600 and not vehicle.cp.TrafficHasStopped then
		vehicle.cp.TrafficBrake = true
		vehicle.cp.isTrafficBraking = true
		return true
	else
		vehicle.cp.TrafficHasStopped = true
		return false
	end
end


function courseplay:driveInMRDirection(vehicle, lx,lz,fwd,dt,allowedToDrive)
	if not vehicle.realForceAiDriven then
		vehicle.realForceAiDriven = true
	end
	if vehicle.cp.speedBrake then 
		--print("speed brake")
		allowedToDrive = false
	end	

	--when I'm 2Fast in a curve then brake
	if abs(lx) > 0.25 and vehicle.lastSpeedReal*3600 > 25 then
		allowedToDrive = false
		--print("emergency brake")
	end
	if not fwd then
		lx = -lx
		lz = -lz
	end
	--AIVehicleUtil.mrDriveInDirection(vehicle, dt, acceleration, allowedToDrive, moveForwards, lx, lz, speedLevel, useReduceSpeed, noDefaultHiredWorker)
	AIVehicleUtil.mrDriveInDirection(vehicle, dt, 1, allowedToDrive, fwd, lx, lz, vehicle.cp.speeds.sl, true, true)
end


function courseplay:setMRSpeed(vehicle, refSpeed, sl, allowedToDrive, workArea)
	local currentSpeed = vehicle.lastSpeedReal
	local deltaMinus = currentSpeed*3600 - refSpeed*3600
	local deltaPlus = refSpeed*3600 - currentSpeed*3600

	local tolerance = 5;
	if vehicle.cp.currentTipTrigger and vehicle.cp.currentTipTrigger.bunkerSilo then
		tolerance = 1;
	end;
	if deltaMinus > tolerance then
		vehicle.cp.speedBrake = true
	else 
		vehicle.cp.speedBrake = false
	end
	
	vehicle.motor.speedLevel = sl
	vehicle.motor.realSpeedLevelsAI[vehicle.motor.speedLevel] = refSpeed*3600

	-- slipping notification
	if vehicle.realDisplaySlipPercent > 90 then
		courseplay:setGlobalInfoText(vehicle, 'SLIPPING_2');
	elseif vehicle.realDisplaySlipPercent > 75 then
		courseplay:setGlobalInfoText(vehicle, 'SLIPPING_1');
	end;

	-- setting AWD if necessary
	if (workArea or vehicle.realDisplaySlipPercent > 25 or vehicle.cp.BGASelectedSection) and vehicle.realAWDModeOn == false then
		vehicle:realSetAwdActive(true);
	elseif not workArea and vehicle.realDisplaySlipPercent < 1 and not vehicle.cp.BGASelectedSection and vehicle.realAWDModeOn == true then
		vehicle:realSetAwdActive(false);
	end
end;

function courseplay:getIsVehicleOffsetValid(vehicle)
	local valid = vehicle.cp.totalOffsetX ~= nil and vehicle.cp.toolOffsetZ ~= nil and (vehicle.cp.totalOffsetX ~= 0 or vehicle.cp.toolOffsetZ ~= 0);
	if not valid then
		return false;
	end;

	if vehicle.cp.mode == 3 then
		if vehicle.cp.laneOffset ~= 0 then
			courseplay:changeLaneOffset(vehicle, nil, 0);
		end;
		return vehicle.recordnumber > 2 and vehicle.recordnumber > vehicle.cp.waitPoints[1] - 6 and vehicle.recordnumber <= vehicle.cp.waitPoints[1] + 3;
	elseif vehicle.cp.mode == 4 or vehicle.cp.mode == 6 then
		return vehicle.recordnumber >= vehicle.cp.startWork and vehicle.recordnumber <= vehicle.cp.stopWork;
	elseif vehicle.cp.mode == 7 then
		if vehicle.cp.laneOffset ~= 0 then
			courseplay:changeLaneOffset(vehicle, nil, 0);
		end;
		return vehicle.recordnumber > 3 and vehicle.recordnumber > vehicle.cp.waitPoints[1] - 6 and vehicle.recordnumber <= vehicle.cp.waitPoints[1] + 3 and not vehicle.cp.mode7GoBackBeforeUnloading;
	elseif vehicle.cp.mode == 8 then
		if vehicle.cp.laneOffset ~= 0 then
			courseplay:changeLaneOffset(vehicle, nil, 0);
		end;
		return vehicle.recordnumber > vehicle.cp.waitPoints[1] - 6 and vehicle.recordnumber <= vehicle.cp.waitPoints[1] + 3;
	end; 

	return false;
end;

function courseplay:getVehicleOffsettedCoords(vehicle, x, z)
	--courseplay:debug(string.format('%s: waypoint before offset: cx=%.2f, cz=%.2f', nameNum(vehicle), cx, cz), 2);
	local fromX, fromZ, toX, toZ;
	if vehicle.recordnumber == 1 then
		fromX = x;
		fromZ = z;
		toX = vehicle.Waypoints[2].cx;
		toZ = vehicle.Waypoints[2].cz;
	elseif vehicle.Waypoints[vehicle.cp.lastRecordnumber].rev then
		fromX = x;
		fromZ = z;
		toX = vehicle.Waypoints[vehicle.cp.lastRecordnumber].cx;
		toZ = vehicle.Waypoints[vehicle.cp.lastRecordnumber].cz;
	else
		fromX = vehicle.Waypoints[vehicle.cp.lastRecordnumber].cx;
		fromZ = vehicle.Waypoints[vehicle.cp.lastRecordnumber].cz;
		toX = x;
		toZ = z;
	end;

	local dx,_,dz,dist = courseplay:getWorldDirection(fromX, 0, fromZ, toX, 0, toZ)
	if dist and dist > 0.01 then
		x = x - dz * vehicle.cp.totalOffsetX + dx * vehicle.cp.toolOffsetZ;
		z = z + dx * vehicle.cp.totalOffsetX + dz * vehicle.cp.toolOffsetZ;
	end;
	--courseplay:debug(string.format('%s: waypoint after offset [%.1fm]: cx=%.2f, cz=%.2f', nameNum(vehicle), vehicle.cp.totalOffsetX, cx, cz), 2);

	return x, z;
end;

function courseplay:handleMapWeightStation(vehicle, allowedToDrive)
	local station, name, x, y, z, vehToCenterX, vehToCenterZ;
	local isInFrontOfStation = vehicle.cp.fillTrigger ~= nil;

	if isInFrontOfStation and vehicle.cp.curMapWeightStation == nil then
		station = courseplay.triggers.all[vehicle.cp.fillTrigger];

		-- station couldn't be found -> abort
		if station == nil then
			courseplay:debug(('%s: station == nil -> set fillTrigger to nil, return allowedToDrive'):format(nameNum(vehicle)), 20);
			vehicle.cp.fillTrigger = nil;
			return allowedToDrive;
		end;

		name = tostring(station.name);
		x, y, z = getWorldTranslation(station.id);
		local distToStation = courseplay:distanceToPoint(vehicle, x, y, z);

		-- too far away from station -> abort
		if distToStation > 60 then
			vehicle.cp.fillTrigger = nil;
			courseplay:debug(('%s: station=%s, distToStation=%.1f -> set fillTrigger to nil, return allowedToDrive'):format(nameNum(vehicle), name, distToStation), 20);
			return allowedToDrive;
		end;


		if #station.vehiclesInTrigger > 0 then
			local iAmInTrigger = false;
			for i,id in pairs(station.vehiclesInTrigger) do
				local vehInTrigger = g_currentMission.nodeToVehicle[id];
				-- VEHICLE (or some part of it) IN TRIGGER
				if vehicle.cpTrafficCollisionIgnoreList[id] then
					courseplay:debug(('%s: station=%s, part of me is in trigger -> set iAmInTrigger to true'):format(nameNum(vehicle), name), 20);
					iAmInTrigger = true;

				-- OTHER VEHICLE IN TRIGGER
				else
					allowedToDrive = courseplay:brakeToStop(vehicle);
					courseplay:debug(('%s: station=%s, other vehicle in trigger -> stop'):format(nameNum(vehicle), name), 20);
					return allowedToDrive;
				end;
			end;

			if iAmInTrigger then -- ... and no other vehicle is in trigger
				vehicle.cp.fillTrigger = nil;
				isInFrontOfStation = false;
				vehicle.cp.curMapWeightStation = station;

				-- CHECK IF WE'RE DRIVING IN THE CORRECT DIRECTION
				_, _, vehToCenterZ = worldToLocal(vehicle.cp.DirectionNode, x, y, z);
				local displayX, displayY, displayZ = getWorldTranslation(vehicle.cp.curMapWeightStation.digits[1]);
				local _, _, vehToDisZ = worldToLocal(vehicle.cp.DirectionNode, displayX, displayY, displayZ);
				if vehToDisZ < vehToCenterZ then -- display is closer than weightStation center
					vehicle.cp.curMapWeightStation = nil;
					courseplay:debug(('%s: station=%s, vehToCenterZ=%.1f, vehToDisZ=%.1f [display closer than center] -> wrong direction: set curMapWeightStation to nil, return allowedToDrive=%s'):format(nameNum(vehicle), name, vehToCenterZ, vehToDisZ, tostring(allowedToDrive)), 20);
					return allowedToDrive;
				else
					courseplay:debug(('%s: station=%s, vehToCenterZ=%.1f, vehToDisZ=%.1f [center closer than display] -> correct direction'):format(nameNum(vehicle), name, vehToCenterZ, vehToDisZ), 20);
				end;
			end;
		end;
	end;

	vehicle.cp.isInFilltrigger = true; --vehicle.cp.curMapWeightStation ~= nil;

	if vehicle.cp.curMapWeightStation ~= nil then
		name = tostring(vehicle.cp.curMapWeightStation.name);
		vehicle.cp.fillTrigger = nil; -- really make sure fillTrigger is nil
		if vehicle.cp.curMapWeightStation.senke and vehicle.cp.curMapWeightStation.senke.index then
			x, y, z = getWorldTranslation(vehicle.cp.curMapWeightStation.senke.index);
		else
			x, y, z = getWorldTranslation(vehicle.cp.curMapWeightStation.id);
		end;
		vehToCenterX, _, vehToCenterZ = worldToLocal(vehicle.cp.DirectionNode, x, y, z);

		-- make sure to abort in case we somehow missed the stopping point
		if vehToCenterZ <= -45 or Utils.vector2Length(vehToCenterX, vehToCenterZ) > 45 then
			vehicle.cp.curMapWeightStation = nil;
			courseplay:debug(('%s: station=%s, vehToCenterZ=%.1f -> set curMapWeightStation to nil, allowedToDrive=%s'):format(nameNum(vehicle), name, vehToCenterZ, tostring(allowedToDrive)), 20);
			return allowedToDrive;
		end;

		-- get stop point/distance
		local stopAt = -8.5;
		if vehicle.cp.totalLength and vehicle.cp.totalLength > 0 and vehicle.cp.totalLengthOffset then
			stopAt = (vehicle.cp.totalLength * 0.5 + vehicle.cp.totalLengthOffset) * -1;
		end;
		local brakeDistance = pow(vehicle.cp.speeds.turn * 3600 * 0.1, 2);
		-- local brakeDistance = pow(vehicle.lastSpeedReal * 3600 * 0.1, 2);
		-- local brakeDistance = 1;

		-- tractor + trailer on scale -> stop
		if vehToCenterZ and vehToCenterZ <= stopAt + brakeDistance then
			local origAllowedToDrive = allowedToDrive;
			allowedToDrive = courseplay:brakeToStop(vehicle);

			-- vehicle in trigger, still moving
			if vehicle.cp.curMapWeightStation.timerSet == 1 then
				courseplay:debug(('%s: station=%s, vehToCenterZ=%.1f, vehicle at center -> stop, timerSet=1'):format(nameNum(vehicle), name, vehToCenterZ), 20);

			-- vehicle in trigger, not moving, being weighed
			elseif vehicle.cp.curMapWeightStation.timerSet == 2 or vehicle.cp.curMapWeightStation.timerSet == 4 then
				courseplay:debug(('%s: station=%s, vehicle is being weighed, timerSet=%d'):format(nameNum(vehicle), name, vehicle.cp.curMapWeightStation.timerSet), 20);

			-- weighing finished -> continue
			elseif vehicle.cp.curMapWeightStation.timerSet == 3 then
				allowedToDrive = origAllowedToDrive;
				vehicle.cp.curMapWeightStation = nil;
				courseplay:debug(('%s: station=%s, vehToCenterZ=%.1f, timerSet=3 [WEIGHING DONE] -> set curMapWeightStation to nil, allowedToDrive=%s'):format(nameNum(vehicle), name, vehToCenterZ, tostring(allowedToDrive)), 20);
			else
				courseplay:debug(('%s: station=%s, timerSet=%d'):format(nameNum(vehicle), name, vehicle.cp.curMapWeightStation.timerSet), 20);
			end;

			return allowedToDrive;
		end;
	end;

	courseplay:debug(('%s: handleMapWeightStation() **END** -> station=%s, isInFrontOfStation=%s, isInStation=%s, vehToCenterZ=%s'):format(nameNum(vehicle), tostring(name), tostring(isInFrontOfStation), tostring(vehicle.cp.curMapWeightStation ~= nil), tostring(vehToCenterZ)), 20);

	return allowedToDrive;
end;

function courseplay:setRecordNumber(vehicle, number)
	if vehicle.recordnumber ~= number then
		-- courseplay:onRecordNumberChanged(vehicle);
	end;
	vehicle.recordnumber = number;
end;

function courseplay:onRecordNumberChanged(vehicle)
end;

function courseplay:setReverseBackDistance(vehicle, metersBack)
	if not vehicle or not metersBack then return; end;

	if not vehicle.cp.reverseBackToPoint then
		local x, y, z = localToWorld(vehicle.rootNode, 0, 0, -metersBack);
		vehicle.cp.reverseBackToPoint = {};
		vehicle.cp.reverseBackToPoint.x = x;
		vehicle.cp.reverseBackToPoint.y = y;
		vehicle.cp.reverseBackToPoint.z = z;

		vehicle.cp.isReverseBackToPoint = true;

		courseplay:debug(string.format("%s: Reverse back %d meters", nameNum(vehicle), metersBack), 13);
	end;
end;