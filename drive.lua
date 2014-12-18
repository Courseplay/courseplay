local curFile = 'drive.lua';

local abs, max, min, pow, sin , huge = math.abs, math.max, math.min, math.pow, math.sin, math.huge;

-- drives recored course
function courseplay:drive(self, dt)
	if not courseplay:getCanUseCpMode(self) then
		return;
	end;

	-- debug for workAreas
	if courseplay.debugChannels[6] then
		local tx1, ty1, tz1 = localToWorld(self.cp.DirectionNode,3,1,self.cp.aiFrontMarker)
		local tx2, ty2, tz2 = localToWorld(self.cp.DirectionNode,3,1,self.cp.backMarkerOffset)
		local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, -1, 0, 0)
		local distance = 6
		drawDebugLine(tx1, ty1, tz1, 1, 0, 0, tx1+(nx*distance), ty1+(ny*distance), tz1+(nz*distance), 1, 0, 0) 
		drawDebugLine(tx2, ty2, tz2, 1, 0, 0, tx2+(nx*distance), ty2+(ny*distance), tz2+(nz*distance), 1, 0, 0) 
	end 
	
	local refSpeed = huge
	local speedDebugLine = "refSpeed"
	self.cp.speedDebugLine = nil
	self.cp.speedDebugStreet = nil
	local cx,cy,cz = 0,0,0
	-- may I drive or should I hold position for some reason?
	local allowedToDrive = true
	self.cp.curSpeed = self.lastSpeedReal * 3600;

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
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-4).."): refSpeed = "..tostring(refSpeed))
	end;


	-- unregister at combine, if there is one
	if self.cp.isLoaded == true and self.cp.positionWithCombine ~= nil then
		courseplay:unregisterFromCombine(self, self.cp.activeCombine)
	end

	-- Turn on sound / control lights
	if not self.isControlled then
		self:setLightsVisibility(CpManager.lightsNeeded);
	end;

	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.cp.DirectionNode);

	if self.recordnumber > self.maxnumber then
		courseplay:debug(string.format("drive %d: %s: self.recordnumber (%s) > self.maxnumber (%s)", debug.getinfo(1).currentline, nameNum(self), tostring(self.recordnumber), tostring(self.maxnumber)), 12); --this should never happen
		courseplay:setRecordNumber(self, self.maxnumber);
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


	-- WARNING LIGHTS
	if self.cp.warningLightsMode == courseplay.WARNING_LIGHTS_NEVER then -- never
		if self.beaconLightsActive then
			self:setBeaconLightsVisibility(false);
		end;
		if self.cp.hasHazardLights and self.turnSignalState ~= Vehicle.TURNSIGNAL_OFF then
			self:setTurnSignalState(Vehicle.TURNSIGNAL_OFF);
		end;
	else -- on street/always
		local combineBeaconOn = self.cp.isCombine and (self.fillLevel / self.capacity) > 0.8;
		local beaconOn = self.cp.warningLightsMode == courseplay.WARNING_LIGHTS_BEACON_ALWAYS 
						 or ((self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 3 or self.cp.mode == 5) and self.recordnumber > 2) 
						 or ((self.cp.mode == 4 or self.cp.mode == 6) and self.recordnumber > self.cp.stopWork)
						 or combineBeacon;
		if self.beaconLightsActive ~= beaconOn then
			self:setBeaconLightsVisibility(beaconOn);
		end;
		if self.cp.hasHazardLights then
			local hazardOn = self.cp.warningLightsMode == courseplay.WARNING_LIGHTS_BEACON_HAZARD_ON_STREET and beaconOn and not combineBeaconOn;
			if not hazardOn and self.turnSignalState ~= Vehicle.TURNSIGNAL_OFF then
				self:setTurnSignalState(Vehicle.TURNSIGNAL_OFF);
			elseif hazardOn and self.turnSignalState ~= Vehicle.TURNSIGNAL_HAZARD then
				self:setTurnSignalState(Vehicle.TURNSIGNAL_HAZARD);
			end;
		end;
	end;


	-- the tipper that is currently loaded/unloaded
	local activeTipper;
	local isBypassing = false
	local isCrawlingToWait = false

	-- ### WAITING POINTS - START
	if self.Waypoints[self.cp.lastRecordnumber].wait and self.cp.wait then
		-- set wait time end
		if self.cp.waitTimer == nil and self.cp.waitTime > 0 then
			self.cp.waitTimer = self.timer + self.cp.waitTime * 1000;
		end;

		if self.cp.mode == 3 and self.cp.workToolAttached then
			courseplay:handleMode3(self, self.cp.tipperFillLevelPct, allowedToDrive, dt);

		elseif self.cp.mode == 4 then
			local drive_on = false
			if self.cp.lastRecordnumber == self.cp.startWork then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.lastRecordnumber == self.cp.stopWork and self.cp.abortWork ~= nil then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.waitPoints[3] and self.cp.lastRecordnumber == self.cp.waitPoints[3] then
				local isInWorkArea = self.recordnumber > self.cp.startWork and self.recordnumber <= self.cp.stopWork;
				if self.cp.workToolAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.cp.workTools ~= nil and not isInWorkArea then
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
					courseplay:setVehicleWait(self, false);
				end
				courseplay:setInfoText(self, string.format(courseplay:loc("COURSEPLAY_LOADING_AMOUNT"), self.cp.tipperFillLevel, self.cp.tipperCapacity));
			end
		elseif self.cp.mode == 6 then
			if self.cp.lastRecordnumber == self.cp.startWork then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.lastRecordnumber == self.cp.stopWork and self.cp.abortWork ~= nil then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.lastRecordnumber ~= self.cp.startWork and self.cp.lastRecordnumber ~= self.cp.stopWork then 
				CpManager:setGlobalInfoText(self, 'UNLOADING_BALE');
				if self.cp.tipperFillLevelPct == 0 or drive_on then
					courseplay:setVehicleWait(self, false);
				end;
			end;
		elseif self.cp.mode == 7 then
			if self.cp.lastRecordnumber == self.cp.startWork then
				if self.fillLevel > 0 then
					self:setPipeState(2)
					CpManager:setGlobalInfoText(self, 'OVERLOADING_POINT');
				else
					courseplay:setVehicleWait(self, false);
					self.cp.isUnloaded = true
				end
			end
		elseif self.cp.mode == 8 then
			CpManager:setGlobalInfoText(self, 'OVERLOADING_POINT');
			if self.cp.workToolAttached then
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
					courseplay:setVehicleWait(self, false);
					self.cp.prevFillLevelPct = nil
					self.cp.isUnloaded = true
				end
			end
		elseif self.cp.mode == 9 then
			courseplay:setVehicleWait(self, false);
		else
			CpManager:setGlobalInfoText(self, 'WAIT_POINT');
		end;

		-- wait time passed -> continue driving
		if self.cp.waitTimer and self.timer > self.cp.waitTimer then
			self.cp.waitTimer = nil
			courseplay:setVehicleWait(self, false);
		end
		isCrawlingToWait = true
		local _,_,zDist = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.lastRecordnumber].cx, cty, self.Waypoints[self.cp.lastRecordnumber].cz);
		if zDist < 1 then -- don't stop immediately when hitting the waitPoints recordnumber, but rather wait until we're close enough (1m)
			allowedToDrive = false;
		end;
	-- ### WAITING POINTS - END

	-- ### NON-WAITING POINTS
	else
		-- MODES 1 & 2: unloading in trigger
		if (self.cp.mode == 1 or (self.cp.mode == 2 and self.cp.isLoaded)) and self.cp.tipperFillLevel ~= nil and self.cp.tipRefOffset ~= nil and self.cp.workToolAttached then
			if self.cp.currentTipTrigger == nil and self.cp.tipperFillLevel > 0 and self.recordnumber > 2 and self.recordnumber < self.maxnumber and not self.Waypoints[self.recordnumber].rev then
				courseplay:doTriggerRaycasts(self, 'tipTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
			end;

			allowedToDrive = courseplay:handle_mode1(self, allowedToDrive);
		end;

		-- COMBI MODE / BYPASSING
		if (((self.cp.mode == 2 or self.cp.mode == 3) and self.recordnumber < 2) or self.cp.activeCombine) and self.cp.workToolAttached then
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
		if self.cp.mode == 3 and self.cp.workToolAttached and self.recordnumber >= 2 and self.cp.modeState == 0 then
			courseplay:handleMode3(self, self.cp.tipperFillLevelPct, allowedToDrive, dt);
		end;

		-- MODE 4: REFILL SPRAYER or SEEDER
		if self.cp.mode == 4 then
			if self.cp.workToolAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
				local isInWorkArea = self.recordnumber > self.cp.startWork and self.recordnumber <= self.cp.stopWork;
				if self.cp.workTools ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, self.cp.tipperFillLevelPct, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end
			end;
		end

		--[[ MAP WEIGHT STATION
		if courseplay:canUseWeightStation(self) then
			if self.cp.curMapWeightStation ~= nil or (self.cp.fillTrigger ~= nil and courseplay.triggers.all[self.cp.fillTrigger].isWeightStation) then
				allowedToDrive = courseplay:handleMapWeightStation(self, allowedToDrive);
			elseif courseplay:canScanForWeightStation(self) then
				courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
			end;
		end;
		]]

		--VEHICLE DAMAGE
		if self.damageLevel then
			if self.damageLevel >= 90 and not self.isInRepairTrigger then
				allowedToDrive = false;
				CpManager:setGlobalInfoText(self, 'DAMAGE_MUST');
			elseif self.damageLevel >= 50 and not self.isInRepairTrigger then
				CpManager:setGlobalInfoText(self, 'DAMAGE_SHOULD');
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
				CpManager:setGlobalInfoText(self, 'DAMAGE_IS');
			end;
		end;

		-- MODE 8: REFILL LIQUID MANURE TRANSPORT
		if self.cp.mode == 8 then
			courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
			if self.cp.workToolAttached then
				if self.cp.workTools ~= nil then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, self.cp.tipperFillLevelPct, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end;
			end;
		end;

		--FUEL LEVEL + REFILLING
		if self.fuelCapacity > 0 then
			local currentFuelPercentage = (self.fuelFillLevel / self.fuelCapacity + 0.0001) * 100;
			if currentFuelPercentage < 5 then
				allowedToDrive = false;
				CpManager:setGlobalInfoText(self, 'FUEL_MUST');
			elseif currentFuelPercentage < 20 and not self.isFuelFilling then
				courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
				if self.cp.fillTrigger ~= nil and courseplay.triggers.all[self.cp.fillTrigger].isGasStationTrigger then
					self.cp.isInFilltrigger = true;
				end;
				CpManager:setGlobalInfoText(self, 'FUEL_SHOULD');
				if self.fuelFillTriggers[1] then
					allowedToDrive = false;
					self:setIsFuelFilling(true, self.fuelFillTriggers[1].isEnabled, false);
				end;
			elseif self.isFuelFilling and currentFuelPercentage < 99.9 then
				allowedToDrive = false;
				CpManager:setGlobalInfoText(self, 'FUEL_IS');
			end;
			if self.fuelFillTriggers[1] and self.cp.fillTrigger and courseplay.triggers.all[self.cp.fillTrigger].isGasStationTrigger then
				courseplay:debug(nameNum(self) .. ': self.fuelFillTriggers[1] ~= nil -> resetting "self.cp.fillTrigger"', 1);
				self.cp.fillTrigger = nil;
			end;
		end;

		-- WATER WARNING
		if self.showWaterWarning then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'WATER');
		end;

		-- STOP AND END OR TRIGGER
		if self.cp.stopAtEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil or self.cp.fillTrigger ~= nil) then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'END_POINT');
		end;
	end;
	-- ### NON-WAITING POINTS END


	--------------------------------------------------


	local workArea = false;
	local workSpeed = 0;
	local isFinishingWork = false;
	-- MODE 4
	if self.cp.mode == 4 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.cp.workToolAttached then
		allowedToDrive, workArea, workSpeed, isFinishingWork, refSpeed = courseplay:handle_mode4(self, allowedToDrive, workSpeed, self.cp.tipperFillLevelPct, refSpeed);
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		if not workArea and self.cp.tipperFillLevelPct < self.cp.refillUntilPct then
			courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end;

	-- MODE 6
	elseif self.cp.mode == 6 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed, activeTipper, isFinishingWork,refSpeed = courseplay:handle_mode6(self, allowedToDrive, workSpeed, self.cp.tipperFillLevelPct, lx, lz,refSpeed);
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
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
			showCover = self.recordnumber >= minCoverWaypoint and self.recordnumber < self.maxnumber and self.cp.currentTipTrigger == nil and self.cp.trailerFillDistance == nil;
		else
			showCover = not workArea and self.cp.currentTipTrigger == nil;
		end;

		courseplay:openCloseCover(self, dt, showCover, self.cp.currentTipTrigger ~= nil);
	end;

	-- CHECK TRAFFIC
	allowedToDrive = courseplay:checkTraffic(self, true, allowedToDrive)
	
	if self.cp.waitForTurnTime > self.timer then
		allowedToDrive = false
	end 

	-- MODE 9 --TODO (Jakob): why is this in drive instead of mode9?
	local WpUnload = false
	if self.cp.shovelEmptyPoint ~= nil and self.recordnumber >=3  then
		WpUnload = self.recordnumber == self.cp.shovelEmptyPoint
	end
	
	if WpUnload then
		local i = self.cp.shovelEmptyPoint
		local x,y,z = getWorldTranslation(self.cp.DirectionNode)
		local _,_,ez = worldToLocal(self.cp.DirectionNode, self.Waypoints[i].cx , y , self.Waypoints[i].cz)
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
		local x,y,z = getWorldTranslation(self.cp.DirectionNode)
		local _,_,ez = worldToLocal(self.cp.DirectionNode, self.Waypoints[i].cx , y , self.Waypoints[i].cz)
		if  ez < 0.2 then
			if self.cp.tipperFillLevelPct == 0 then
				allowedToDrive = false
				CpManager:setGlobalInfoText(self, 'WORK_END');
			else
				courseplay:setIsLoaded(self, true);
				courseplay:setRecordNumber(self, i + 2);
			end
		end
	end
	-- MODE 9 END

	
	-- allowedToDrive false -> STOP OR HOLD POSITION
	if not allowedToDrive then
		self.cp.TrafficBrake = false;
		self.cp.isTrafficBraking = false;

		local moveForwards = true;
		if self.cp.curSpeed > 1 then
			allowedToDrive = true;
			moveForwards = self.movingDirection == 1;
		end;
		AIVehicleUtil.driveInDirection(self, dt, 30, -1, 0, 28, allowedToDrive, moveForwards, 0, 1)
		self.cp.speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): allowedToDrive false ")
		return;
	end


	if self.cp.isTurning ~= nil then
		courseplay:turn(self, dt);
		self.cp.TrafficBrake = false
		return
	end
	self.cp.checkMarkers = false
	
	--SPEED SETTING
	local isAtEnd   = self.recordnumber > self.maxnumber - 3;
	local isAtStart = self.recordnumber < 3;
	if 	((self.cp.mode == 1 or self.cp.mode == 5 or self.cp.mode == 8) and (isAtStart or isAtEnd)) 
	or	((self.cp.mode == 2 or self.cp.mode == 3) and isAtEnd) 
	or	(self.cp.mode == 9 and self.recordnumber > self.cp.shovelFillStartPoint and self.recordnumber <= self.cp.shovelFillEndPoint)
	or	(not workArea and self.cp.wait and ((isAtEnd and self.Waypoints[self.recordnumber].wait) or courseplay:waypointsHaveAttr(self, self.recordnumber, 0, 2, "wait", true, false)))
	or 	(isAtEnd and self.Waypoints[self.recordnumber].rev)
	or	(not isAtEnd and (self.Waypoints[self.recordnumber].rev or self.Waypoints[self.recordnumber + 1].rev or self.Waypoints[self.recordnumber + 2].rev))
	or	(workSpeed ~= nil and workSpeed == 0.5) -- baler in mode 6 , slow down
	or isCrawlingToWait		
	then
		refSpeed = math.min(self.cp.speeds.turn,refSpeed);              -- we are on the field, go field speed
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	elseif ((self.cp.mode == 2 or self.cp.mode == 3) and isAtStart) or (workSpeed ~= nil and workSpeed == 1) then
		refSpeed = math.min(self.cp.speeds.field,refSpeed); 
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	else
		local mode7onCourse = true
		self.cp.speedDebugStreet = true
		if self.cp.mode ~= 7 then
			refSpeed = self.cp.speeds.street;
			speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		elseif self.cp.modeState == 5 then
			mode7onCourse = false
		end
		if self.cp.speeds.useRecordingSpeed and self.Waypoints[self.recordnumber].speed ~= nil and mode7onCourse then
			if self.Waypoints[self.recordnumber].speed < self.cp.speeds.crawl then
				refSpeed = courseplay:getAverageWpSpeed(self , 4)
				speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				refSpeed = Utils.clamp(refSpeed, self.cp.speeds.crawl, self.Waypoints[self.recordnumber].speed); --normaly use speed from waypoint, but  maximum street speed
				speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
		end;		
	end;
	
	
	if self.cp.collidingVehicleId ~= nil then
		refSpeed = courseplay:regulateTrafficSpeed(self, refSpeed, allowedToDrive);
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end
	
	if self.cp.currentTipTrigger ~= nil then
		if self.cp.currentTipTrigger.bunkerSilo ~= nil then
			refSpeed = Utils.getNoNil(self.cp.speeds.unload, self.cp.speeds.crawl);
			speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		else
			refSpeed = self.cp.speeds.turn;
			speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		end;
	elseif self.cp.isInFilltrigger then
		refSpeed = self.cp.speeds.turn;
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
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
		refSpeed = Utils.getNoNil(self.cp.speeds.unload, self.cp.speeds.crawl)
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	else
		fwd = true
	end

	if self.cp.TrafficBrake then
		fwd = self.movingDirection == -1;
		lx = 0;
		lz = 1;
	end  	
	self.cp.TrafficBrake = false
	self.cp.isTrafficBraking = false

	if self.cp.mode7GoBackBeforeUnloading then
		fwd = false;
		lz = lz * -1;
		lx = lx * -1;
	elseif self.cp.isReverseBackToPoint then
		if self.cp.reverseBackToPoint then
			local _, _, zDis = worldToLocal(self.cp.DirectionNode, self.cp.reverseBackToPoint.x, self.cp.reverseBackToPoint.y, self.cp.reverseBackToPoint.z);
			if zDis < 0 then
				fwd = false;
				lx = 0
				lz = 1				
				refSpeed = self.cp.speeds.crawl
				speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				self.cp.reverseBackToPoint = nil;
			end;
		else
			self.cp.isReverseBackToPoint = false;
		end;
	end
	if abs(lx) > 0.5 then
		refSpeed = min(refSpeed, self.cp.speeds.turn)
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end
	
	self.cp.speedDebugLine = speedDebugLine
	
	courseplay:setSpeed(self, refSpeed)

	-- Four wheel drive
	if self.cp.hasDriveControl and self.cp.driveControl.hasFourWD then
		courseplay:setFourWheelDrive(self, workArea);
	end;


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

	if self.cp.distanceToTarget > distToChange or WpUnload or WpLoadEnd or isFinishingWork then
		if g_server ~= nil then
			local acceleration = 1;
			if self.cp.speedBrake then
				-- We only need to break sligtly.
				acceleration = (self.movingDirection == 1) == fwd and -0.25 or 0.25; -- Setting accelrator to a negative value will break the tractor.
			end;

			--self,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
			--AIVehicleUtil.driveInDirection(dt,25,acceleration,0.5,20,true,true,-0.028702223698223,0.99958800630799,22,1,nil)
			AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, acceleration, 0.5, 20, true, fwd, lx, lz, refSpeed, 1);
			if not isBypassing then
				courseplay:setTrafficCollision(self, lx, lz, workArea)
			end
		end
	else
		-- reset distance to waypoint
		self.cp.shortestDistToWp = nil
		if self.recordnumber < self.maxnumber then -- = New
			if not self.cp.wait then
				courseplay:setVehicleWait(self, true);
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
			courseplay:setStopAtEnd(self, false);
			courseplay:setIsLoaded(self, false);
			courseplay:setIsRecording(self, false);
			self.cp.canDrive = true
		end
	end
end
-- END drive();


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
		local _,transY,_ = getTranslation(vehicle.cp.collidingVehicleId);
		if transY < 0 or abs(tx) > 5 and collisionVehicle.rootNode ~= nil and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then
			courseplay:debug(('%s: checkTraffic:\tcall deleteCollisionVehicle(), transY= %s'):format(nameNum(vehicle),tostring(transY)), 3);
			courseplay:deleteCollisionVehicle(vehicle);
			return allowedToDrive;
		end;

		if collisionVehicle.lastSpeedReal == nil or collisionVehicle.lastSpeedReal*3600 < 5 or ahead then
			-- courseplay:debug(('%s: checkTraffic:\tcall distance=%.2f'):format(nameNum(vehicle), tz-halfLength), 3);
			if tz <= halfLength + 2 then --TODO: abs(tz) ?
				allowedToDrive = false;
				vehicle.cp.inTraffic = true;
				courseplay:debug(('%s: checkTraffic:\tstop'):format(nameNum(vehicle)), 3);
			elseif vehicle.cp.curSpeed > 10 then
				-- courseplay:debug(('%s: checkTraffic:\tbrake'):format(nameNum(vehicle)), 3);
				allowedToDrive = false;
			else
				-- courseplay:debug(('%s: checkTraffic:\tdo nothing - go, but set "vehicle.cp.isTrafficBraking"'):format(nameNum(vehicle)), 3);
				vehicle.cp.isTrafficBraking = true;
			end;
		end;
	end;

	if displayWarnings and vehicle.cp.inTraffic then
		CpManager:setGlobalInfoText(vehicle, 'TRAFFIC');
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

function courseplay:setSpeed(vehicle, refSpeed)
	local newSpeed = math.max(refSpeed,3)	
	if vehicle.cruiseControl.state == Drivable.CRUISECONTROL_STATE_OFF then
		vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
	end 
	vehicle:setCruiseControlMaxSpeed(newSpeed) 

	courseplay:handleSlipping(vehicle, refSpeed);

	local deltaMinus = vehicle.cp.curSpeed - refSpeed;
	local tolerance = 2.5;

	if vehicle.cp.currentTipTrigger and vehicle.cp.currentTipTrigger.bunkerSilo then
		tolerance = 1;
	end;
	if deltaMinus > tolerance then
		vehicle.cp.speedBrake = true;
	else
		vehicle.cp.speedBrake = false;
	end;
end
	
function courseplay:openCloseCover(vehicle, dt, showCover, isAtTipTrigger)
	for i,twc in pairs(vehicle.cp.tippersWithCovers) do
		local tIdx, coverType, showCoverWhenTipping, coverItems = twc.tipperIndex, twc.coverType, twc.showCoverWhenTipping, twc.coverItems;
		local tipper = vehicle.cp.workTools[tIdx];

		-- default Giants trailers
		if coverType == 'defaultGiants' then
			if tipper.isCoverOpen == showCover then
				tipper:setCoverState(not showCover);
			end;


		-- Example: for mods trailer that don't use the default cover specialization
		else--if coverType == 'CoverVehicle' then
			--for _,ci in pairs(coverItems) do
			--	if getVisibility(ci) ~= showCover then
			--		setVisibility(ci, showCover);
			--	end;
			--end;
			--if showCoverWhenTipping and isAtTipTrigger and not showCover then
				--
			--else
			--	tipper:setPlane(not showCover);
			--end;
		end;
	end; --END for i,tipperWithCover in vehicle.cp.tippersWithCovers
end;

function courseplay:refillSprayer(vehicle, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt)
	for i=1, vehicle.cp.numWorkTools do
		local activeTool = vehicle.cp.workTools[i];
		local isSpecialSprayer = false
		local fillTrigger;
		isSpecialSprayer, allowedToDrive, lx, lz = courseplay:handleSpecialSprayer(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, 'pull');
		if isSpecialSprayer then
			return allowedToDrive,lx,lz
		end;

		-- SPRAYER
		if courseplay:isSprayer(activeTool) or activeTool.cp.isLiquidManureOverloader then
			-- print(('\tworkTool %d (%q)'):format(i, nameNum(activeTool)));
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger )and courseplay:fillTypesMatch(trigger, activeTool) then 
					--print('\t\tslow down, it\'s a sprayerFillTrigger');
					vehicle.cp.isInFilltrigger = true
				end
			end;

			local activeToolFillLevel;
			if activeTool.fillLevel ~= nil and activeTool.capacity ~= nil then
				activeToolFillLevel = (activeTool.fillLevel / activeTool.capacity) * 100;
			end;
			--vehicle.cp.lastMode8UnloadTriggerId
			if fillTrigger == nil then
				if activeTool.fillTriggers[1] ~= nil and (activeTool.fillTriggers[1].isSprayerFillTrigger or activeTool.fillTriggers[1].isLiquidManureFillTrigger) then
					fillTrigger = activeTool.fillTriggers[1];
					vehicle.cp.fillTrigger = nil; --TODO (Jakob): if i == vehicle.cp.numWorkTools then vehicle.cp.fillTrigger = nil; end; (prevent nilling if there are other tools left to be filled)
				end;
			end;

			local fillTypesMatch = courseplay:fillTypesMatch(fillTrigger, activeTool);
			local canRefill = (activeToolFillLevel ~= nil and activeToolFillLevel < driveOn) and fillTypesMatch;
			
			if vehicle.cp.mode == 8 then
				canRefill = canRefill and not courseplay:waypointsHaveAttr(vehicle, vehicle.recordnumber, -2, 2, 'wait', true, false);
				if (activeTool.isSpreaderInRange ~= nil and activeTool.isSpreaderInRange.manureTriggerc ~= nil) 
				--normal fill triggers
				or (fillTrigger ~= nil and fillTrigger.triggerId ~= nil and vehicle.cp.lastMode8UnloadTriggerId ~= nil and fillTrigger.triggerId == vehicle.cp.lastMode8UnloadTriggerId)
				-- manureLager fill trigger
				or (fillTrigger ~= nil and fillTrigger.manureTrigger ~= nil and vehicle.cp.lastMode8UnloadTriggerId ~= nil and fillTrigger.manureTrigger == vehicle.cp.lastMode8UnloadTriggerId)
				then
					canRefill = false;
				end;
			end;
			
			if canRefill then
				allowedToDrive = false;
				--courseplay:handleSpecialTools(vehicle,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
				courseplay:handleSpecialTools(vehicle,activeTool,nil,nil,nil,allowedToDrive,false,false)
				local sprayer = activeTool.fillTriggers[1];
				if not activeTool.isFilling then
					activeTool:setIsFilling(true);
				end;
				--[[
				if sprayer.trailerInTrigger == activeTool then --Feldrand-Container Guellebomber
					sprayer.fill = true;
				end;]]

				courseplay:setInfoText(vehicle, courseplay:loc("COURSEPLAY_LOADING_AMOUNT"):format(activeTool.fillLevel, activeTool.capacity));
			elseif vehicle.cp.isLoaded then
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
				courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_LOADING_AMOUNT'):format(activeTool.fillLevel, activeTool.capacity));
			elseif activeTool.fillTriggers[1] ~= nil then
				if activeTool.isFilling then
					activeTool:setIsFilling(false);
				end;
				vehicle.cp.fillTrigger = nil
			end;
		end;
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
		local x1, y1, z1 = worldToLocal(vehicle.cp.DirectionNode, x, y, z)
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
				if vehicle.cp.curSpeed - (collisionVehicle.lastSpeedReal*3600) > 15 or z1 < 3 then
					vehicle.cp.TrafficBrake = true
				else
					return min(collisionVehicle.lastSpeedReal*3600,refSpeed)
				end
			end
		end
	end
	return refSpeed
end

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
					allowedToDrive = false;
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
		local brakeDistance = pow(vehicle.cp.speeds.turn * 0.1, 2);
		-- local brakeDistance = pow(vehicle.cp.curSpeed * 0.1, 2);
		-- local brakeDistance = 1;

		-- tractor + trailer on scale -> stop
		if vehToCenterZ and vehToCenterZ <= stopAt + brakeDistance then
			local origAllowedToDrive = allowedToDrive;
			allowedToDrive = false;

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

function courseplay:setReverseBackDistance(vehicle, metersBack)
	if not vehicle or not metersBack then return; end;

	if not vehicle.cp.reverseBackToPoint then
		local x, y, z = localToWorld(vehicle.cp.DirectionNode, 0, 0, -metersBack);
		vehicle.cp.reverseBackToPoint = {};
		vehicle.cp.reverseBackToPoint.x = x;
		vehicle.cp.reverseBackToPoint.y = y;
		vehicle.cp.reverseBackToPoint.z = z;

		vehicle.cp.isReverseBackToPoint = true;

		courseplay:debug(string.format("%s: Reverse back %d meters", nameNum(vehicle), metersBack), 13);
	end;
end;

function courseplay:getAverageWpSpeed(vehicle, numWaypoints)
	numWaypoints = max(numWaypoints,3)
	local refSpeed = 0
	local divider = numWaypoints
	for i= (vehicle.recordnumber-1), (vehicle.recordnumber + numWaypoints-1) do
		local index = i
		if index > vehicle.maxnumber then
			index = index - vehicle.maxnumber
		elseif index < 1 then
			index = vehicle.maxnumber - index
		end
		if vehicle.Waypoints[index].speed ~= nil then
			refSpeed = refSpeed + vehicle.Waypoints[index].speed
		else
			divider = divider -1
		end
	end
	
	return refSpeed/divider
end;

function courseplay:setFourWheelDrive(vehicle, workArea)
	local changed = false;

	-- set 4WD
	local awdOn = vehicle.cp.driveControl.alwaysUseFourWD or workArea or vehicle.cp.isBGATipping or vehicle.cp.slippingStage ~= 0 or vehicle.cp.mode == 9 or (vehicle.cp.mode == 2 and vehicle.cp.modeState > 1);
	local awdOff = not vehicle.cp.driveControl.alwaysUseFourWD and not workArea and not vehicle.cp.isBGATipping and vehicle.cp.slippingStage == 0 and vehicle.cp.mode ~= 9 and not (vehicle.cp.mode == 2 and vehicle.cp.modeState > 1);
	if awdOn and not vehicle.driveControl.fourWDandDifferentials.fourWheel then
		courseplay:debug(('%s: set fourWheel to true'):format(nameNum(vehicle)), 14);
		vehicle.driveControl.fourWDandDifferentials.fourWheel = true;
		changed = true;
	elseif awdOff and vehicle.driveControl.fourWDandDifferentials.fourWheel then
		courseplay:debug(('%s: set fourWheel to false'):format(nameNum(vehicle)), 14);
		vehicle.driveControl.fourWDandDifferentials.fourWheel = false;
		changed = true;
	end;

	-- set differential lock
	local targetLockStatus = vehicle.cp.slippingStage > 1;
	if vehicle.driveControl.fourWDandDifferentials.diffLockFront ~= targetLockStatus then
		courseplay:debug(('%s: set diffLockFront to %s'):format(nameNum(vehicle), tostring(targetLockStatus)), 14);
		vehicle.driveControl.fourWDandDifferentials.diffLockFront = targetLockStatus;
		changed = true;
	end;
	if vehicle.driveControl.fourWDandDifferentials.diffLockBack ~= targetLockStatus then
		courseplay:debug(('%s: set diffLockBack to %s'):format(nameNum(vehicle), tostring(targetLockStatus)), 14);
		vehicle.driveControl.fourWDandDifferentials.diffLockBack = targetLockStatus;
		changed = true;
	end;

	if changed and driveControlInputEvent ~= nil then
		driveControlInputEvent.sendEvent(vehicle);
	end;
end;

function courseplay:handleSlipping(vehicle, refSpeed)
	if vehicle.cp.inTraffic or vehicle.Waypoints[vehicle.recordnumber].wait then return end;

	if vehicle.cp.slippingStage == 1 then
		CpManager:setGlobalInfoText(vehicle, 'SLIPPING_1');
	elseif vehicle.cp.slippingStage == 2 then
		CpManager:setGlobalInfoText(vehicle, 'SLIPPING_2');
	end;

	-- 0) no slipping (slippingStage 0)
	-- 1) 3 seconds < 0.5 kph -> slippingStage 1: activate 4WD
	-- 2) another 3 seconds < 1 kph -> slippingStage 2: activate differential locks
	-- 3) if speed > 20% refSpeed -> slippingStage 1: deactivate differential locks
	-- 4) if speed > 35% refSpeed -> slippingStage 0: deactivate 4WD

	if vehicle.cp.curSpeed < 0.5 then
		-- set stage 1
		if vehicle.cp.slippingStage == 0 then
			if vehicle.cp.timers.slippingStage1 == nil or vehicle.cp.timers.slippingStage1 == 0 then
				courseplay:setCustomTimer(vehicle, 'slippingStage1', 3);
				courseplay:debug(('%s: setCustomTimer(..., "slippingStage1", 3)'):format(nameNum(vehicle)), 14);
			elseif courseplay:timerIsThrough(vehicle, 'slippingStage1') then
				courseplay:debug(('%s: timerIsThrough(..., "slippingStage1") -> setSlippingStage 1, reset timer'):format(nameNum(vehicle)), 14);
				courseplay:setSlippingStage(vehicle, 1);
				courseplay:resetCustomTimer(vehicle, 'slippingStage1');
			end;

		-- set stage 2
		elseif vehicle.cp.slippingStage == 1 then
			if vehicle.cp.timers.slippingStage2 == nil or vehicle.cp.timers.slippingStage2 == 0 then
				courseplay:setCustomTimer(vehicle, 'slippingStage2', 3);
				courseplay:debug(('%s: setCustomTimer(..., "slippingStage2", 3)'):format(nameNum(vehicle)), 14);
			elseif courseplay:timerIsThrough(vehicle, 'slippingStage2') then
				courseplay:debug(('%s: timerIsThrough(..., "slippingStage2") -> setSlippingStage 2, reset timer'):format(nameNum(vehicle)), 14);
				courseplay:setSlippingStage(vehicle, 2);
				courseplay:resetCustomTimer(vehicle, 'slippingStage2');
			end;
		end;

	-- resets when speeds are met
	elseif vehicle.cp.curSpeed >= refSpeed * 0.2 then
		if vehicle.cp.curSpeed >= refSpeed * 0.35 then
			if vehicle.cp.timers.slippingStage1 ~= 0 then
				courseplay:debug(('%s: curStage=%d, refSpeed=%.2f, curSpeed=%.2f -> resetCustomTimer(..., "slippingStage1")'):format(nameNum(vehicle), vehicle.cp.slippingStage, refSpeed, vehicle.cp.curSpeed), 14);
				courseplay:resetCustomTimer(vehicle, 'slippingStage1');
			end;
			if vehicle.cp.slippingStage > 0 then
				courseplay:debug(('%s: curStage=%d, refSpeed=%.2f, curSpeed=%.2f -> setSlippingStage 0'):format(nameNum(vehicle), vehicle.cp.slippingStage, refSpeed, vehicle.cp.curSpeed), 14);
				courseplay:setSlippingStage(vehicle, 0);
			end;
		end;

		if vehicle.cp.timers.slippingStage2 ~= 0 then
			courseplay:debug(('%s: curStage=%d, refSpeed=%.2f, curSpeed=%.2f -> resetCustomTimer(..., "slippingStage2")'):format(nameNum(vehicle), vehicle.cp.slippingStage, refSpeed, vehicle.cp.curSpeed), 14);
			courseplay:resetCustomTimer(vehicle, 'slippingStage2');
		end;
		if vehicle.cp.slippingStage > 1 then
			courseplay:debug(('%s: curStage=%d, refSpeed=%.2f, curSpeed=%.2f -> setSlippingStage 1'):format(nameNum(vehicle), vehicle.cp.slippingStage, refSpeed, vehicle.cp.curSpeed), 14);
			courseplay:setSlippingStage(vehicle, 1);
		end;
	end;
end;


-----------------------------------------------------------------------------------------

function courseplay:setRecordNumber(vehicle, number)
	if vehicle.recordnumber ~= number then
		local oldValue = vehicle.recordnumber;
		vehicle.recordnumber = number;
		courseplay:onRecordNumberChanged(vehicle, oldValue);
	end;
end;

function courseplay:onRecordNumberChanged(vehicle, oldValue)
	if vehicle.recordnumber > 1 then
		vehicle.cp.lastRecordnumber = vehicle.recordnumber - 1;
	else
		vehicle.cp.lastRecordnumber = 1;
	end;
	vehicle.cp.HUDrecordnumber = vehicle.recordnumber;
	-- print(('%s: onRecordNumberChanged(): new=%d, old=%s'):format(nameNum(vehicle), vehicle.recordnumber, tostring(oldValue)));
end;

function courseplay:getIsCourseplayDriving()
	return self.cp.isDriving;
end;

function courseplay:setIsCourseplayDriving(active)
	if self.cp.isDriving ~= active then
		self.cp.isDriving = active;
		-- courseplay:onIsDrivingChanged(self);
	end;
end;

function courseplay:onIsDrivingChanged(vehicle)
end;
