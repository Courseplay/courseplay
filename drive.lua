local curFile = 'drive.lua';

local abs, max, min, pow, sin , huge = math.abs, math.max, math.min, math.pow, math.sin, math.huge;
local _;
-- drives recored course
function courseplay:drive(self, dt)
	if not courseplay:getCanUseCpMode(self) then
		return;
	end;
	--keeping steering disabled
	if self.steeringEnabled then
		self.steeringEnabled = false;
	end
	-- debug for workAreas
	if courseplay.debugChannels[6] then
		if self.cp.aiFrontMarker and self.cp.backMarkerOffset then
			local tx1, ty1, tz1 = localToWorld(self.cp.DirectionNode,3,1,self.cp.aiFrontMarker)
			local tx2, ty2, tz2 = localToWorld(self.cp.DirectionNode,3,1,self.cp.backMarkerOffset)
			local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, -1, 0, 0)
			local distance = 6
			drawDebugLine(tx1, ty1, tz1, 1, 0, 0, tx1+(nx*distance), ty1+(ny*distance), tz1+(nz*distance), 1, 0, 0)
			drawDebugLine(tx2, ty2, tz2, 1, 0, 0, tx2+(nx*distance), ty2+(ny*distance), tz2+(nz*distance), 1, 0, 0)
		end;
		local workTool = courseplay:getFirstReversingWheeledWorkTool(self) or self.cp.workTools[1];
		if workTool and workTool.workAreas then
			for index, workArea in ipairs(workTool.workAreas) do
				local sx, sy, sz = getWorldTranslation(workArea["start"]);
				drawDebugLine(sx, sy, sz, 1, 0, 0, sx, sy+3, sz, 1, 0, 0);
				local wx, wy, wz = getWorldTranslation(workArea["width"]);
				drawDebugLine(wx, wy, wz, 1, 0, 0, wx, wy+3, wz, 1, 0, 0);
				local hx, hy, hz = getWorldTranslation(workArea["height"]);
				drawDebugLine(hx, hy, hz, 1, 0, 0, hx, hy+3, hz, 1, 0, 0);
			end;
		end;
	end
	
	local forceTrueSpeed = false
	local refSpeed = huge
	local speedDebugLine = "refSpeed"
	self.cp.speedDebugLine = "no speed info"
	self.cp.speedDebugStreet = nil
	local cx,cy,cz = 0,0,0
	-- may I drive or should I hold position for some reason?
	local allowedToDrive = true
	self.cp.curSpeed = self.lastSpeedReal * 3600;

	-- TIPPER FILL LEVELS (get once for all following functions)
	courseplay:updateFillLevelsAndCapacities(self)
	
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


	--[[ unregister at combine, if there is one
	if self.cp.isLoaded == true and self.cp.positionWithCombine ~= nil then
		courseplay:unregisterFromCombine(self, self.cp.activeCombine)
	end]]

	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.cp.DirectionNode);

	if self.cp.waypointIndex > self.cp.numWaypoints then
		courseplay:debug(string.format("drive %d: %s: self.cp.waypointIndex (%s) > self.cp.numWaypoints (%s)", debug.getinfo(1).currentline, nameNum(self), tostring(self.cp.waypointIndex), tostring(self.cp.numWaypoints)), 12); --this should never happen
		courseplay:setWaypointIndex(self, self.cp.numWaypoints);
	end;


	if self.cp.mode ~= 7 or (self.cp.mode == 7 and self.cp.modeState ~= 5) then 
		cx, cz = self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz
	end

	-- HORIZONTAL/VERTICAL OFFSET
	if courseplay:getIsVehicleOffsetValid(self) then
		cx, cz = courseplay:getVehicleOffsettedCoords(self, cx, cz);
		if courseplay.debugChannels[12] and self.cp.isTurning == nil then
			drawDebugPoint(cx, cty+3, cz, 0, 1 , 1, 1);
		end;
	end;

	if courseplay.debugChannels[12] and self.cp.isTurning == nil then
		local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 300, cz);
		drawDebugLine(ctx, cty + 3, ctz, 0, 1, 0, cx, posY + 3, cz, 0, 0, 1)
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
		if self.Waypoints[self.cp.waypointIndex].turnStart then
			self.cp.isTurning = self.Waypoints[self.cp.waypointIndex].turnStart;
		end

		--- If we are turning and abortWork is set, then check if we need to abort the turn
		if self.cp.isTurning and self.cp.abortWork ~= nil then
			local abortTurn = false;
			-- Mode 4 Check
			if self.cp.mode == 4 and self.cp.workTools ~= nil then
				for _,tool in pairs(self.cp.workTools) do
					local hasMoreFillUnits = courseplay:setOwnFillLevelsAndCapacities(tool)
					if hasMoreFillUnits and tool ~= self and
						((tool.sowingMachine ~= nil and self.cp.totalSeederFillLevelPercent == 0) or (tool.sprayer ~= nil and self.cp.totalSprayerFillLevelPercent == 0))
					then
						abortTurn = true;
					end;
				end;
			-- Mode 6 Check
			elseif self.cp.mode == 6 and self.cp.totalFillLevelPercent == 100 then
				abortTurn = true;
			end;

			-- Abort turn if needed.
			if abortTurn then
				self.cp.isTurning = nil;
				if #(self.cp.turnTargets) > 0 then
					courseplay:clearTurnTargets(self);
				end;
			end;
		end

		--RESET OFFSET TOGGLES
		if not self.cp.isTurning then
			if self.cp.symmetricLaneChange and not self.cp.switchLaneOffset then
				self.cp.switchLaneOffset = true;
				courseplay:debug(string.format("%s: isTurning=false, switchLaneOffset=false -> set switchLaneOffset to true", nameNum(self)), 12);
			end;
			if self.cp.hasPlough and self.cp.hasRotateablePlough and not self.cp.switchToolOffset then
				self.cp.switchToolOffset = true;
				courseplay:debug(string.format("%s: isTurning=false, switchToolOffset=false -> set switchToolOffset to true", nameNum(self)), 12);
			end;
		end;
	end;


	-- LIGHTS
	local lightMask = 0
	local combineBeaconOn = self.cp.isCombine and self.cp.totalFillLevelPercent > 80;
	local beaconOn = (self.cp.warningLightsMode == courseplay.WARNING_LIGHTS_BEACON_ALWAYS 
					 or ((self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 3 or self.cp.mode == 5) and self.cp.waypointIndex > 2) 
					 or ((self.cp.mode == 4 or self.cp.mode == 6) and self.cp.waypointIndex > self.cp.stopWork)
					 or (self.cp.mode == 10 and (self.cp.waypointIndex > 1 or #self.cp.mode10.stoppedCourseplayers >0) )
					 or combineBeaconOn) or false;
	if beaconOn then
		lightMask = 1
	else
		lightMask = 7
	end
	
	if self.cp.warningLightsMode == courseplay.WARNING_LIGHTS_NEVER then -- never
		if self.beaconLightsActive then
			self:setBeaconLightsVisibility(false);
		end;
		if self.cp.hasHazardLights and self.turnSignalState ~= Vehicle.TURNSIGNAL_OFF then
			self:setTurnSignalState(Vehicle.TURNSIGNAL_OFF);
		end;
	else -- on street/always
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
	
	-- lights
	if CpManager.lightsNeeded then
		if self.lightsTypesMask ~= lightMask then
			self:setLightsTypesMask(lightMask)
		end
	elseif 	self.lightsTypesMask ~= 0 then
		self:setLightsTypesMask(0)		
	end;
	
	
	

	-- the tipper that is currently loaded/unloaded
	local activeTipper;
	local isBypassing = false
	local isCrawlingToWait = false
	local isWaitingThisLoop = false
	local wayPointIsWait = self.Waypoints[self.cp.previousWaypointIndex].wait
	local wayPointIsUnload = self.Waypoints[self.cp.previousWaypointIndex].unload
	local wayPointIsRevUnload = wayPointIsUnload and self.Waypoints[self.cp.previousWaypointIndex].rev
	local stopForUnload = false
	-- ### WAITING POINTS - START
	if (wayPointIsWait or wayPointIsUnload) and self.cp.wait then
		isWaitingThisLoop = true
		-- set wait time end
		if self.cp.waitTimer == nil and self.cp.waitTime > 0 then
			self.cp.waitTimer = self.timer + self.cp.waitTime * 1000;
		end;
		if 	self.cp.mode <= 2 then
			if wayPointIsUnload then
				stopForUnload = courseplay:handleUnloading(self,wayPointIsRevUnload)
			end
		elseif self.cp.mode == 3 and self.cp.workToolAttached then
			courseplay:handleMode3(self, allowedToDrive, dt);

		elseif self.cp.mode == 4 then
			local drive_on = false
			if self.cp.previousWaypointIndex == self.cp.startWork then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.previousWaypointIndex == self.cp.stopWork and self.cp.abortWork ~= nil then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.waitPoints[3] and self.cp.previousWaypointIndex == self.cp.waitPoints[3] then
				local isInWorkArea = self.cp.waypointIndex > self.cp.startWork and self.cp.waypointIndex <= self.cp.stopWork;
				if self.cp.workToolAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.cp.workTools ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillWorkTools(self, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end;
				if courseplay:timerIsThrough(self, "fillLevelChange") or self.cp.prevFillLevelPct == nil then
					if self.cp.prevFillLevelPct ~= nil and self.cp.totalFillLevelPercent == self.cp.prevFillLevelPct and self.cp.totalFillLevelPercent >= self.cp.refillUntilPct then
						drive_on = true
					end
					self.cp.prevFillLevelPct = self.cp.totalFillLevelPercent
					courseplay:setCustomTimer(self, "fillLevelChange", 7);
				end

				if self.cp.totalFillLevelPercent >= self.cp.refillUntilPct or drive_on then
					courseplay:setVehicleWait(self, false);
				end
				courseplay:setInfoText(self, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(self.cp.totalFillLevel, 100), self.cp.totalCapacity));
			end
		elseif self.cp.mode == 6 then
			if wayPointIsUnload then
				stopForUnload = courseplay:handleUnloading(self,wayPointIsRevUnload)
			elseif self.cp.previousWaypointIndex == self.cp.startWork then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.previousWaypointIndex == self.cp.stopWork and self.cp.abortWork ~= nil then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.previousWaypointIndex ~= self.cp.startWork and self.cp.previousWaypointIndex ~= self.cp.stopWork then 
				if self.cp.hasBaleLoader then
					CpManager:setGlobalInfoText(self, 'UNLOADING_BALE');
				else
					CpManager:setGlobalInfoText(self, 'OVERLOADING_POINT');
				end
				if self.cp.totalFillLevelPercent == 0 or drive_on then
					courseplay:setVehicleWait(self, false);
				end;
			end;
		elseif self.cp.mode == 7 then
			if self.cp.previousWaypointIndex == self.cp.startWork then
				if self.cp.totalFillLevel > 0 then
					if self.pipeCurrentState ~= 2 then
						self:setPipeState(2)
					end
					if self.cp.mode7makeHeaps then
						if self:getCanTipToGround() then
							if not self.dischargeToGround then
								self.cp.speeds.discharge = courseplay:getDischargeSpeed(self)
								self:setDischargeToGround(true)
								courseplay:setVehicleWait(self, false);
							end
						else
							-- TODO show message "not able to discharge"
						end
					else
						CpManager:setGlobalInfoText(self, 'OVERLOADING_POINT');
					end
				else
					courseplay:setVehicleWait(self, false);
					self.cp.isUnloaded = true
				end
			end
			if self.cp.previousWaypointIndex == self.cp.stopWork and self.cp.totalFillLevel == 0 then
				courseplay:setVehicleWait(self, false);
			end 
		elseif self.cp.mode == 8 then
			allowedToDrive, lx, lz = courseplay:handleMode8(self, false, true, allowedToDrive, lx, lz, dt);
		elseif self.cp.mode == 9 then
			courseplay:setVehicleWait(self, false);
		
		elseif self.cp.mode == 10 then
			if #self.cp.mode10.stoppedCourseplayers > 0 then
				for i=1,#self.cp.mode10.stoppedCourseplayers do
					local courseplayer = self.cp.mode10.stoppedCourseplayers[i]
					local tx,tz = self.Waypoints[1].cx,self.Waypoints[1].cz
					local ty = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tx, 1, tz);
					local distance = courseplay:distanceToPoint(courseplayer,tx,ty,tz)
					if distance > self.cp.mode10.searchRadius then
						table.remove(self.cp.mode10.stoppedCourseplayers,i)
						break
					end
				end
			end
			if (self.cp.actualTarget and self.cp.actualTarget.empty) or (self.cp.mode10.deadline and self.cp.mode10.deadline == self.cp.mode10.firstLine) then
				if courseplay:timerIsThrough(self,'BunkerEmpty') then
					courseplay:setCustomTimer(self, "BunkerEmpty", 5);
					courseplay:getActualTarget(self)
					--print("check for FillLevel")
				end
			else
				self.cp.actualTarget = nil
			end
		else
			CpManager:setGlobalInfoText(self, 'WAIT_POINT');
		end;

		-- wait time passed -> continue driving
		if self.cp.waitTimer and self.timer > self.cp.waitTimer then
			self.cp.waitTimer = nil
			courseplay:setVehicleWait(self, false);
		end
		isCrawlingToWait = true
		if wayPointIsWait or wayPointIsRevUnload then
			local _,_,zDist = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.previousWaypointIndex].cx, cty, self.Waypoints[self.cp.previousWaypointIndex].cz);
			if zDist < 1 then -- don't stop immediately when hitting the waitPoints waypointIndex, but rather wait until we're close enough (1m)
				allowedToDrive = false;
			end;
		elseif stopForUnload then
			allowedToDrive = false;
		end;
	-- ### WAITING POINTS - END

	-- ### NON-WAITING POINTS
	else
		-- MODES 1 & 2: unloading in trigger
		if (self.cp.mode == 1 or (self.cp.mode == 2 and self.cp.isLoaded)) and self.cp.totalFillLevel ~= nil and self.cp.tipRefOffset ~= nil and self.cp.workToolAttached then
			if self.cp.currentTipTrigger == nil and self.cp.totalFillLevel > 0 and self.cp.waypointIndex > 2 and self.cp.waypointIndex < self.cp.numWaypoints and not self.Waypoints[self.cp.waypointIndex].rev then
				courseplay:doTriggerRaycasts(self, 'tipTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
			end;

			allowedToDrive = courseplay:handle_mode1(self, allowedToDrive);
		end;
		
		--resetTrailer when empty after unloading in Bunkersilo
		if self.cp.totalFillLevel == 0 then
			for _,tipper in pairs (self.cp.workTools) do
				if tipper.tipState ~= nil and tipper.tipState == Trailer.TIPSTATE_OPEN then
					tipper:toggleTipState();
				end
			end
		end

		-- COMBI MODE / BYPASSING
		if (((self.cp.mode == 2 or self.cp.mode == 3) and self.cp.waypointIndex < 2) or self.cp.activeCombine) and self.cp.workToolAttached then
			self.cp.inTraffic = false
			courseplay:handle_mode2(self, dt);
			return;
		elseif (self.cp.mode == 2 or self.cp.mode == 3) and self.cp.waypointIndex < 3 then
			isBypassing = true
			lx, lz = courseplay:isTheWayToTargetFree(self,lx, lz)
		elseif self.cp.mode == 6 and self.cp.hasBaleLoader and (self.cp.waypointIndex == self.cp.stopWork + 1 or (self.cp.abortWork ~= nil and self.cp.waypointIndex == self.cp.abortWork)) then
			isBypassing = true
			lx, lz = courseplay:isTheWayToTargetFree(self,lx, lz)
		elseif self.cp.mode ~= 7 and self.cp.mode ~= 10 then
			if self.cp.modeState ~= 0 then
				courseplay:setModeState(self, 0);
			end;
		end;

		-- MODE 3: UNLOADING
		if self.cp.mode == 3 and self.cp.workToolAttached and self.cp.waypointIndex >= 2 and self.cp.modeState == 0 then
			courseplay:handleMode3(self, allowedToDrive, dt);

		-- MODE 4: REFILL SPRAYER or SEEDER
		elseif self.cp.mode == 4 then
			if self.cp.workToolAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
				local isInWorkArea = self.cp.waypointIndex > self.cp.startWork and self.cp.waypointIndex <= self.cp.stopWork;
				if self.cp.workTools ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillWorkTools(self, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end
			end;

		-- MODE 8: REFILL LIQUID MANURE TRANSPORT
		elseif self.cp.mode == 8 then
			allowedToDrive, lx, lz = courseplay:handleMode8(self, true, false, allowedToDrive, lx, lz, dt, tx, ty, tz, nx, ny, nz);
		end;

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

		--FUEL LEVEL + REFILLING
		if self.fuelCapacity > 0 then
			local currentFuelPercentage = (self.fuelFillLevel / self.fuelCapacity + 0.0001) * 100;
			local searchForFuel = (self.cp.allwaysSearchFuel and (currentFuelPercentage < 99) and self.cp.waypointIndex > 2 and self.cp.waypointIndex < self.cp.numWaypoints) or (currentFuelPercentage < 20) and not self.isFuelFilling
			if searchForFuel then
				courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
				if self.cp.fillTrigger ~= nil and courseplay.triggers.all[self.cp.fillTrigger].isGasStationTrigger then
					self.cp.isInFilltrigger = true;
				end;
				if self.fuelFillTriggers[1] then
					allowedToDrive = false;
					self:setIsFuelFilling(true, self.fuelFillTriggers[1].isEnabled, false);
				end;			
			end 
			if currentFuelPercentage < 5 then
				allowedToDrive = false;
				CpManager:setGlobalInfoText(self, 'FUEL_MUST');
			elseif currentFuelPercentage < 20 and not self.isFuelFilling then
				CpManager:setGlobalInfoText(self, 'FUEL_SHOULD');
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

		-- STOP AT END OR TRIGGER
		if self.cp.stopAtEnd and (self.cp.waypointIndex == self.cp.numWaypoints or self.cp.currentTipTrigger ~= nil or self.cp.fillTrigger ~= nil) then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'END_POINT');
		end;

		-- STOP AT END MODE 1
		if self.cp.stopAtEndMode1 and self.cp.waypointIndex == self.cp.numWaypoints then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'END_POINT_MODE_1');
		end;
	end;
	-- ### NON-WAITING POINTS END


	--------------------------------------------------


	local workArea = false;
	local workSpeed = 0;
	local isFinishingWork = false;
	-- MODE 4
	if self.cp.mode == 4 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.cp.workToolAttached then
		allowedToDrive, workArea, workSpeed, isFinishingWork, refSpeed = courseplay:handle_mode4(self, allowedToDrive, workSpeed, refSpeed);
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		if not workArea and self.cp.totalFillLevelPercent < self.cp.refillUntilPct then
			courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end;

	-- MODE 6
	elseif self.cp.mode == 6 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
		allowedToDrive, workArea, workSpeed, activeTipper, isFinishingWork,refSpeed = courseplay:handle_mode6(self, allowedToDrive, workSpeed, lx, lz,refSpeed);
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		if not workArea and self.cp.currentTipTrigger == nil and self.cp.totalFillLevel and self.cp.totalFillLevel > 0 and self.capacity == nil and self.cp.tipRefOffset ~= nil and not self.Waypoints[self.cp.waypointIndex].rev then
			courseplay:doTriggerRaycasts(self, 'tipTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end;

	-- MODE 9
	elseif self.cp.mode == 9 then
		allowedToDrive,lx,lz  = courseplay:handle_mode9(self,self.cp.totalFillLevelPercent, allowedToDrive,lx,lz, dt);
	-- MODE 10
	elseif self.cp.mode == 10 then
		local continue = true ;
		continue,allowedToDrive = courseplay:handleMode10(self,allowedToDrive,lx,lz, dt);
		if self.cp.shieldState ~= self.cp.targetShieldState then
			--print(string.format("self.cp.shieldState(%s) ~= self.cp.targetShieldState(%s)",tostring(self.cp.shieldState),tostring(self.cp.targetShieldState)))
			if courseplay:moveShield(self,self.cp.targetShieldState,dt) then
				self.cp.shieldState = self.cp.targetShieldState
			end
		end
		
		if not continue then
			return;
		end;
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-4).."): refSpeed = "..tostring(refSpeed))
	end;
	
	
	self.cp.inTraffic = false;

	-- HANDLE TIPPER COVER
	if self.cp.tipperHasCover and self.cp.automaticCoverHandling and (self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 5 or self.cp.mode == 6) then
		local showCover = false;

		if self.cp.mode ~= 6 then
			local minCoverWaypoint = self.cp.mode == 1 and 4 or 3;
			showCover = self.cp.waypointIndex >= minCoverWaypoint and self.cp.waypointIndex < self.cp.numWaypoints and self.cp.currentTipTrigger == nil and self.cp.trailerFillDistance == nil and not courseplay:waypointsHaveAttr(self, self.cp.waypointIndex, -1, 2, "unload", true, false);
		else
			showCover = not workArea and self.cp.currentTipTrigger == nil;
		end;

		courseplay:openCloseCover(self, dt, showCover, self.cp.currentTipTrigger ~= nil);
	end;

	-- CHECK TRAFFIC
	allowedToDrive = courseplay:checkTraffic(self, true, allowedToDrive)
	
	if self.cp.waitForTurnTime > self.timer or self.cp.isNotAllowedToDrive then
		allowedToDrive = false
	end 

	-- MODE 9 --TODO (Jakob): why is this in drive instead of mode9?
	local WpUnload = false
	if self.cp.shovelEmptyPoint ~= nil and self.cp.waypointIndex >=3  then
		WpUnload = self.cp.waypointIndex == self.cp.shovelEmptyPoint
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
	if self.cp.shovelFillEndPoint ~= nil and self.cp.waypointIndex >=3  then
		WpLoadEnd = self.cp.waypointIndex == self.cp.shovelFillEndPoint
	end
	if WpLoadEnd then
		local i = self.cp.shovelFillEndPoint
		local x,y,z = getWorldTranslation(self.cp.DirectionNode)
		local _,_,ez = worldToLocal(self.cp.DirectionNode, self.Waypoints[i].cx , y , self.Waypoints[i].cz)
		if  ez < 0.2 then
			if self.cp.totalFillLevelPercent == 0 then
				allowedToDrive = false
				CpManager:setGlobalInfoText(self, 'WORK_END');
			else
				courseplay:setIsLoaded(self, true);
				courseplay:setWaypointIndex(self, i + 2);
			end
		end
	end
	-- MODE 9 END

	
	-- allowedToDrive false -> STOP OR HOLD POSITION
	if not allowedToDrive then
		-- reset slipping timers
		courseplay:resetSlippingTimers(self)
		if courseplay.debugChannels[21] then
			renderText(0.5,0.85-(0.03*self.cp.coursePlayerNum),0.02,string.format("%s: self.lastSpeedReal: %.8f km/h ",nameNum(self),self.lastSpeedReal*3600))
		end
		self.cp.TrafficBrake = false;
		self.cp.isTrafficBraking = false;
		
		local moveForwards = true;
		if self.cp.curSpeed > 1 and not self.cp.mode == 9 then
			allowedToDrive = true;
			moveForwards = self.movingDirection == 1;
		elseif self.cp.curSpeed < 0.2 then
			-- ## The infamous "SUCK IT, GIANTS" fix, a.k.a "chain that fucker down, it ain't goin' nowhere!"
			--courseplay:getAndSetFixedWorldPosition(self);
		end;
		AIVehicleUtil.driveInDirection(self, dt, 30, -1, 0, 28, allowedToDrive, moveForwards, 0, 1) 
		self.cp.speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): allowedToDrive false ")
		return;
	end;

	-- reset fixedWorldPosition
	if self.cp.fixedWorldPosition ~= nil then
		courseplay:deleteFixedWorldPosition(self);
	end;


	if self.cp.isTurning then
		courseplay:turn(self, dt);
		self.cp.TrafficBrake = false
		return
	end

	
	--SPEED SETTING
	local isAtEnd   = self.cp.waypointIndex > self.cp.numWaypoints - 3;
	local isAtStart = self.cp.waypointIndex < 3;
	if 	((self.cp.mode == 1 or self.cp.mode == 5 or self.cp.mode == 8) and (isAtStart or isAtEnd)) 
	or	((self.cp.mode == 2 or self.cp.mode == 3) and isAtEnd) 
	or	(self.cp.mode == 9 and self.cp.waypointIndex > self.cp.shovelFillStartPoint and self.cp.waypointIndex <= self.cp.shovelFillEndPoint)
	or	(not workArea and self.cp.wait and ((isAtEnd and self.Waypoints[self.cp.waypointIndex].wait) or courseplay:waypointsHaveAttr(self, self.cp.waypointIndex, 0, 2, "wait", true, false)))
	or 	courseplay:waypointsHaveAttr(self, self.cp.waypointIndex, 0, 2, "unload", true, false)
	or 	(isAtEnd and self.Waypoints[self.cp.waypointIndex].rev)
	or	(not isAtEnd and (self.Waypoints[self.cp.waypointIndex].rev or self.Waypoints[self.cp.waypointIndex + 1].rev or self.Waypoints[self.cp.waypointIndex + 2].rev))
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
		if self.cp.speeds.useRecordingSpeed and self.Waypoints[self.cp.waypointIndex].speed ~= nil and mode7onCourse then
			if self.Waypoints[self.cp.waypointIndex].speed < self.cp.speeds.crawl then
				refSpeed = courseplay:getAverageWpSpeed(self , 4)
				speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				refSpeed = Utils.clamp(refSpeed, self.cp.speeds.crawl, self.Waypoints[self.cp.waypointIndex].speed); --normaly use speed from waypoint, but  maximum street speed
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
			refSpeed = Utils.getNoNil(self.cp.speeds.reverse, self.cp.speeds.crawl);
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
	if self.Waypoints[self.cp.waypointIndex].rev then
		lx,lz,fwd = courseplay:goReverse(self,lx,lz)
		refSpeed = Utils.getNoNil(self.cp.speeds.reverse, self.cp.speeds.crawl)
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	else
		fwd = true
	end

	if self.cp.TrafficBrake then
		fwd = self.movingDirection == -1;
		--lx = 0;
		--lz = 1;
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
	if self.cp.mode7makeHeaps and self.cp.waypointIndex > self.cp.startWork + 1	and self.cp.waypointIndex <= self.cp.stopWork and self.cp.totalFillLevel > 0 then
			refSpeed = self.cp.speeds.discharge
			speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))	
			forceTrueSpeed = true
	end
	
	if abs(lx) > 0.5 then
		refSpeed = min(refSpeed, self.cp.speeds.turn)
		speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end
	
	self.cp.speedDebugLine = speedDebugLine
	
	refSpeed = courseplay:setSpeed(self, refSpeed, forceTrueSpeed)

	-- Four wheel drive
	if self.cp.hasDriveControl and self.cp.driveControl.hasFourWD then
		courseplay:setFourWheelDrive(self, workArea);
	end;


	-- DISTANCE TO CHANGE WAYPOINT
	if self.cp.waypointIndex == 1 or self.cp.waypointIndex == self.cp.numWaypoints - 1 or self.Waypoints[self.cp.waypointIndex].turnStart then
		if self.cp.hasSpecializationArticulatedAxis then
			distToChange = self.cp.mode == 9 and 2 or 1; -- ArticulatedAxis vehicles
		else
			distToChange = 0.5;
		end;
	elseif self.cp.waypointIndex + 1 <= self.cp.numWaypoints then
		local beforeReverse = (self.Waypoints[self.cp.waypointIndex + 1].rev and (self.Waypoints[self.cp.waypointIndex].rev == false))
		local afterReverse = (not self.Waypoints[self.cp.waypointIndex + 1].rev and self.Waypoints[self.cp.previousWaypointIndex].rev)
		if (self.Waypoints[self.cp.waypointIndex].wait or beforeReverse) and self.Waypoints[self.cp.waypointIndex].rev == false then -- or afterReverse or self.cp.waypointIndex == 1
			if self.cp.hasSpecializationArticulatedAxis then
				distToChange = 2; -- ArticulatedAxis vehicles
			else
				distToChange = 1;
			end;
		elseif (self.Waypoints[self.cp.waypointIndex].rev and self.Waypoints[self.cp.waypointIndex].wait) or afterReverse then
			if self.cp.hasSpecializationArticulatedAxis then
				distToChange = 4; -- ArticulatedAxis vehicles
			else
				distToChange = 2;
			end;
		elseif self.Waypoints[self.cp.waypointIndex].rev then
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

		if beforeReverse then
			self.cp.shortestDistToWp = nil
		end
	else
		if self.cp.hasSpecializationArticulatedAxis then
			distToChange = 5; -- ArticulatedAxis vehicles stear better with a longer change distance
		else
			distToChange = 2.85; --orig: 5
		end;
	end
	--distToChange = 2;



	-- record shortest distance to the next waypoint
	if self.cp.shortestDistToWp == nil or self.cp.shortestDistToWp > self.cp.distanceToTarget then
		self.cp.shortestDistToWp = self.cp.distanceToTarget
	end

	if self.invertedDrivingDirection then
		lx = -lx
		lz = -lz
	end

	-- if distance grows i must be circling
	if self.cp.distanceToTarget > self.cp.shortestDistToWp and self.cp.waypointIndex > 3 and self.cp.distanceToTarget < 15 and self.Waypoints[self.cp.waypointIndex].rev ~= true then
		distToChange = self.cp.distanceToTarget + 1
	end

	if self.cp.distanceToTarget > distToChange or WpUnload or WpLoadEnd or isFinishingWork then
		if g_server ~= nil then
			local acceleration = 1;
			if self.cp.speedBrake then
				-- We only need to break sligtly.
				acceleration = (self.movingDirection == 1) == fwd and -0.25 or 0.25; -- Setting accelrator to a negative value will break the tractor.
			end;

			local steeringAngle = self.cp.steeringAngle;
			if self.cp.isFourWheelSteering and self.cp.curSpeed > 20 then
				-- We are a four wheel steered vehicle, so dampen the steeringAngle when driving fast, since we turn double as fast as normal and will cause oscillating.
				steeringAngle = self.cp.steeringAngle * 2;
			end;

			-- Using false to disable the driveToPoint. This could be made into an setting option later on.
			local useDriveToPoint = false --and self.cp.mode == 1 or self.cp.mode == 5 or (self.cp.waypointIndex > 4 and (self.cp.mode == 2 or self.cp.mode == 3));
			if self.Waypoints[self.cp.waypointIndex].rev or not useDriveToPoint then
				if math.abs(self.lastSpeedReal) < 0.0001 and not g_currentMission.missionInfo.stopAndGoBraking then
					if not fwd then
						self.nextMovingDirection = -1
					else
						self.nextMovingDirection = 1
					end;
				end;
				--self,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
				AIVehicleUtil.driveInDirection(self, dt, steeringAngle, acceleration, 0.5, 20, true, fwd, lx, lz, refSpeed, 1);
			else
				local directionNode = self.aiVehicleDirectionNode or self.cp.DirectionNode;
				local tX,_,tZ = worldToLocal(directionNode, cx, cty, cz);
				if courseplay:isWheelloader(self) then
					tZ = tZ * 0.5; -- wheel loaders need to turn more
				end;
				AIVehicleUtil.driveToPoint(self, dt, acceleration, allowedToDrive, fwd, tX, tZ, refSpeed);
			end;
			
			if not isBypassing then
				courseplay:setTrafficCollision(self, lx, lz, workArea)
			end
		end
	elseif not isWaitingThisLoop then
		-- reset distance to waypoint
		self.cp.shortestDistToWp = nil
		if self.cp.waypointIndex < self.cp.numWaypoints then -- = New
			if not self.cp.wait then
				courseplay:setVehicleWait(self, true);
			end
			if self.cp.mode == 7 and self.cp.modeState == 5 then
			else
				courseplay:setWaypointIndex(self, self.cp.waypointIndex + 1);
			end
		else -- last waypoint: reset some variables
			if (self.cp.mode == 4 or self.cp.mode == 6) and not self.cp.hasUnloadingRefillingCourse then
			else
				courseplay:setWaypointIndex(self, 1);
			end
			self.cp.isUnloaded = false
			courseplay:setStopAtEnd(self, false);
			courseplay:setIsLoaded(self, false);
			courseplay:setIsRecording(self, false);
			self:setCpVar('canDrive',true,courseplay.isClient)
		end
	end
end
-- END drive();


function courseplay:setTrafficCollision(vehicle, lx, lz, workArea)
	--local goForRaycast = vehicle.cp.mode == 1 or (vehicle.cp.mode == 3 and vehicle.cp.waypointIndex > 3) or vehicle.cp.mode == 5 or vehicle.cp.mode == 8 or ((vehicle.cp.mode == 4 or vehicle.cp.mode == 6) and vehicle.cp.waypointIndex > vehicle.cp.stopWork) or (vehicle.cp.mode == 2 and vehicle.cp.waypointIndex > 3)
	--print("lx: "..tostring(lx).."	distance: "..tostring(distance))
	--local maxlx = 0.5; --sin(maxAngle); --sin30°  old was : 0.7071067 sin 45°
	local colDirX = lx;
	local colDirZ = lz;
	--[[if colDirX > maxlx then
		colDirX = maxlx;
	elseif colDirX < -maxlx then
		colDirX = -maxlx;
	end;
	if colDirZ < -0.4 then
		colDirZ = 0.4;
	end;]]
	--courseplay:debug(string.format("colDirX: %f colDirZ %f ",colDirX,colDirZ ), 3)
	if vehicle.cp.trafficCollisionTriggers[1] ~= nil then 
		courseplay:setCollisionDirection(vehicle.cp.DirectionNode, vehicle.cp.trafficCollisionTriggers[1], colDirX, colDirZ);
		local recordNumber = vehicle.cp.waypointIndex
		if vehicle.cp.collidingVehicleId == nil then
			for i=2,vehicle.cp.numTrafficCollisionTriggers do
				if workArea or recordNumber + i >= vehicle.cp.numWaypoints or recordNumber < 2 then
					courseplay:setCollisionDirection(vehicle.cp.trafficCollisionTriggers[i-1], vehicle.cp.trafficCollisionTriggers[i], 0, -1);
				else
					
					local nodeX,nodeY,nodeZ = getWorldTranslation(vehicle.cp.trafficCollisionTriggers[i]);
					local nodeDirX,nodeDirY,nodeDirZ,distance = courseplay:getWorldDirection(nodeX,nodeY,nodeZ, vehicle.Waypoints[recordNumber].cx,nodeY,vehicle.Waypoints[recordNumber].cz);
					local _,_,Z = worldToLocal(vehicle.cp.trafficCollisionTriggers[i], vehicle.Waypoints[recordNumber].cx,nodeY,vehicle.Waypoints[recordNumber].cz);
					local index = 1
					local oldValue = Z
					while Z < 5.5 do
						recordNumber = recordNumber+index
						if recordNumber > vehicle.cp.numWaypoints then -- just a backup
							break
						end
						nodeDirX,nodeDirY,nodeDirZ,distance = courseplay:getWorldDirection(nodeX,nodeY,nodeZ, vehicle.Waypoints[recordNumber].cx,nodeY,vehicle.Waypoints[recordNumber].cz);
						_,_,Z = worldToLocal(vehicle.cp.trafficCollisionTriggers[i], vehicle.Waypoints[recordNumber].cx,nodeY,vehicle.Waypoints[recordNumber].cz);
						if oldValue > Z then
							courseplay:setCollisionDirection(vehicle.cp.trafficCollisionTriggers[1], vehicle.cp.trafficCollisionTriggers[i], 0, 1);
							break
						end
						index = index +1
						oldValue = Z
					end					
					nodeDirX,nodeDirY,nodeDirZ = worldDirectionToLocal(vehicle.cp.trafficCollisionTriggers[i-1], nodeDirX,nodeDirY,nodeDirZ);
					--print("colli"..i..": setDirection z= "..tostring(nodeDirZ).." waypoint: "..tostring(recordNumber))
					courseplay:setCollisionDirection(vehicle.cp.trafficCollisionTriggers[i-1], vehicle.cp.trafficCollisionTriggers[i], nodeDirX, nodeDirZ);
				end;
			end
		end
	end;
end;


function courseplay:checkTraffic(vehicle, displayWarnings, allowedToDrive)
	local ahead = false
	local inQueue = false
	local collisionVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId]
	if collisionVehicle ~= nil and not (vehicle.cp.mode == 9 and (collisionVehicle.allowFillFromAir or (collisionVehicle.cp and collisionVehicle.cp.mode9TrafficIgnoreVehicle))) then
		local vx, vy, vz = getWorldTranslation(vehicle.cp.collidingVehicleId);
		local tx, _, tz = worldToLocal(vehicle.cp.trafficCollisionTriggers[1], vx, vy, vz);
		local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode);
		local halfLength =  (collisionVehicle.sizeLength or 5) * 0.5;
		local x1,z1 = AIVehicleUtil.getDriveDirection(vehicle.cp.collidingVehicleId, x, y, z);
		if z1 > -0.9 then -- tractor in front of vehicle face2face or beside < 4 o'clock
			ahead = true
		end;
		local _,transY,_ = getTranslation(vehicle.cp.collidingVehicleId);
		if (transY < 0 and collisionVehicle.rootNode == nil) or abs(tx) > 5 and collisionVehicle.rootNode ~= nil and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then
			courseplay:debug(('%s: checkTraffic:\tcall deleteCollisionVehicle(), transY: %s, tx: %s, vehicle.cp.collidingObjects.all[Id]: %s'):format(nameNum(vehicle),tostring(transY),tostring(tx),tostring(vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId])), 3);
			courseplay:deleteCollisionVehicle(vehicle);
			return allowedToDrive;
		end;

		if collisionVehicle.lastSpeedReal == nil or collisionVehicle.lastSpeedReal*3600 < 5 or ahead then
			-- courseplay:debug(('%s: checkTraffic:\tcall distance=%.2f'):format(nameNum(vehicle), tz-halfLength), 3);
			if tz <= halfLength + 4 then --TODO: abs(tz) ?
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
		local attacher
		if collisionVehicle.getRootAttacherVehicle then
			attacher = collisionVehicle:getRootAttacherVehicle()
			inQueue = vehicle.cp.mode == 1 and vehicle.cp.waypointIndex == 1 and attacher.cp ~= nil and attacher.cp.isDriving and attacher.cp.mode == 1 and attacher.cp.waypointIndex == 2 
		end		
	end;

	if displayWarnings and vehicle.cp.inTraffic and not inQueue then
		CpManager:setGlobalInfoText(vehicle, 'TRAFFIC');
	end;
	return allowedToDrive;
end

function courseplay:setSpeed(vehicle, refSpeed,forceTrueSpeed)
	local newSpeed = math.max(refSpeed,3)	
	if vehicle.cruiseControl.state == Drivable.CRUISECONTROL_STATE_OFF then
		vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
	end
	local deltaMinus = vehicle.cp.curSpeed - refSpeed;
	if not forceTrueSpeed then
		if newSpeed < vehicle.cruiseControl.speed then
			newSpeed = math.max(newSpeed, vehicle.cp.curSpeed - math.max(0.1, math.min(deltaMinus * 0.5, 3)));
		end;
	end
	
	vehicle:setCruiseControlMaxSpeed(newSpeed) 

	courseplay:handleSlipping(vehicle, refSpeed);

	local tolerance = 2.5;

	if vehicle.cp.currentTipTrigger and vehicle.cp.currentTipTrigger.bunkerSilo then
		tolerance = 1;
	end;
	if deltaMinus > tolerance then
		vehicle.cp.speedBrake = true;
	else
		vehicle.cp.speedBrake = false;
	end;

	return newSpeed;
end
	
function courseplay:getSpeedWithLimiter(vehicle, refSpeed)
	local speedLimit, speedLimitActivated = vehicle:getSpeedLimit(true);
	refSpeed = min(refSpeed, speedLimit);

	return refSpeed, speedLimitActivated;
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

function courseplay:regulateTrafficSpeed(vehicle,refSpeed,allowedToDrive)
	if vehicle.cp.isTrafficBraking then
		return refSpeed
	end
	if vehicle.cp.collidingVehicleId ~= nil then
		local collisionVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId];
		local vehicleBehind = false
		if collisionVehicle == nil then
			courseplay:debug(nameNum(vehicle)..": regulateTrafficSpeed(1216):	setting vehicle.cp.collidingVehicleId nil",3)
			courseplay:deleteCollisionVehicle(vehicle)
			
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
			if allowedToDrive and not (vehicle.cp.mode == 9 and (collisionVehicle.allowFillFromAir or collisionVehicle.cp.mode9TrafficIgnoreVehicle)) then
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
		return vehicle.cp.waypointIndex > 2 and vehicle.cp.waypointIndex > vehicle.cp.waitPoints[1] - 6 and vehicle.cp.waypointIndex <= vehicle.cp.waitPoints[1] + 3;
	elseif vehicle.cp.mode == 4 or vehicle.cp.mode == 6 then
		return vehicle.cp.waypointIndex >= vehicle.cp.startWork and vehicle.cp.waypointIndex <= vehicle.cp.stopWork;
	elseif vehicle.cp.mode == 7 then
		if vehicle.cp.laneOffset ~= 0 then
			courseplay:changeLaneOffset(vehicle, nil, 0);
		end;
		return vehicle.cp.waypointIndex > 3 and vehicle.cp.waypointIndex > vehicle.cp.waitPoints[1] - 6 and vehicle.cp.waypointIndex <= vehicle.cp.waitPoints[1] + 3 and not vehicle.cp.mode7GoBackBeforeUnloading;
	elseif vehicle.cp.mode == 8 then
		if vehicle.cp.laneOffset ~= 0 then
			courseplay:changeLaneOffset(vehicle, nil, 0);
		end;
		return vehicle.cp.waypointIndex > vehicle.cp.waitPoints[1] - 6 and vehicle.cp.waypointIndex <= vehicle.cp.waitPoints[1] + 3;
	end; 

	return false;
end;

function courseplay:getVehicleOffsettedCoords(vehicle, x, z)
	--courseplay:debug(string.format('%s: waypoint before offset: cx=%.2f, cz=%.2f', nameNum(vehicle), cx, cz), 2);
	local fromX, fromZ, toX, toZ;
	if vehicle.cp.waypointIndex == 1 then
		fromX = x;
		fromZ = z;
		toX = vehicle.Waypoints[2].cx;
		toZ = vehicle.Waypoints[2].cz;
	elseif vehicle.Waypoints[vehicle.cp.previousWaypointIndex].rev then
		fromX = x;
		fromZ = z;
		toX = vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cx;
		toZ = vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cz;
	else
		fromX = vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cx;
		fromZ = vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cz;
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
	for i= (vehicle.cp.waypointIndex-1), (vehicle.cp.waypointIndex + numWaypoints-1) do
		local index = i
		if index > vehicle.cp.numWaypoints then
			index = index - vehicle.cp.numWaypoints
		elseif index < 1 then
			index = vehicle.cp.numWaypoints - index
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
	local awdOn = vehicle.cp.driveControl.alwaysUseFourWD or workArea or vehicle.cp.isBGATipping or vehicle.cp.slippingStage ~= 0 or vehicle.cp.mode == 9 or vehicle.cp.mode == 10 or (vehicle.cp.mode == 2 and vehicle.cp.modeState > 1);
	local awdOff = not vehicle.cp.driveControl.alwaysUseFourWD and not workArea and not vehicle.cp.isBGATipping and vehicle.cp.slippingStage == 0 and vehicle.cp.mode ~= 9 and not (vehicle.cp.mode == 2 and vehicle.cp.modeState > 1);
	if awdOn and not vehicle.driveControl.fourWDandDifferentials.fourWheel then
		courseplay:debug(('%s: set fourWheel to true'):format(nameNum(vehicle)), 14);
		vehicle.driveControl.fourWDandDifferentials.fourWheel = true;
		courseplay:setCustomTimer(vehicle, '4WDminTime', 5);
		changed = true;
	elseif awdOff and vehicle.driveControl.fourWDandDifferentials.fourWheel and courseplay:timerIsThrough(vehicle, '4WDminTime') then
		courseplay:debug(('%s: set fourWheel to false'):format(nameNum(vehicle)), 14);
		vehicle.driveControl.fourWDandDifferentials.fourWheel = false;
		changed = true;
	end;

	-- set differential lock
	local targetLockStatus = vehicle.cp.slippingStage > 1 or (vehicle.cp.mode == 10 and vehicle.cp.waypointIndex == 1);
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
	if vehicle.cp.inTraffic or vehicle.Waypoints[vehicle.cp.waypointIndex].wait then return end;

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

function courseplay:resetSlippingTimers(vehicle)
	courseplay:resetCustomTimer(vehicle, 'slippingStage1');
	courseplay:resetCustomTimer(vehicle, 'slippingStage2');
end

-----------------------------------------------------------------------------------------

function courseplay:setWaypointIndex(vehicle, number)
	if vehicle.cp.waypointIndex ~= number then
		vehicle:setCpVar('waypointIndex',number,courseplay.isClient);
		if vehicle.cp.waypointIndex > 1 then
			vehicle.cp.previousWaypointIndex = vehicle.cp.waypointIndex - 1;
		else
			vehicle.cp.previousWaypointIndex = 1;
		end;
	end;
end;

function courseplay:getIsCourseplayDriving()
	return self.cp.isDriving;
end;

function courseplay:setIsCourseplayDriving(active)
	self:setCpVar('isDriving',active,courseplay.isClient)
end;

function courseplay:updateFillLevelsAndCapacities(vehicle)
	courseplay:setOwnFillLevelsAndCapacities(vehicle,vehicle.cp.mode)
	vehicle.cp.totalFillLevel = vehicle.cp.fillLevel;
	vehicle.cp.totalCapacity = vehicle.cp.capacity;
	vehicle.cp.totalSeederFillLevel = vehicle.cp.seederFillLevel
	vehicle.cp.totalSeederCapacity = vehicle.cp.seederCapacity
	vehicle.cp.totalSprayerFillLevel = vehicle.cp.sprayerFillLevel
	vehicle.cp.totalSprayerCapacity = vehicle.cp.sprayerCapacity
	
	if vehicle.cp.fillLevel ~= nil and vehicle.cp.capacity ~= nil then
		vehicle.cp.totalFillLevelPercent = (vehicle.cp.fillLevel*100)/vehicle.cp.capacity;
	end
	--print(string.format("vehicle itself(%s): vehicle.cp.totalFillLevel:(%s)",tostring(vehicle.name),tostring(vehicle.cp.totalFillLevel)))
	--print(string.format("vehicle itself(%s): vehicle.cp.totalCapacity:(%s)",tostring(vehicle.name),tostring(vehicle.cp.totalCapacity)))
	if vehicle.cp.workTools ~= nil then
		for _,tool in pairs(vehicle.cp.workTools) do
			local hasMoreFillUnits = courseplay:setOwnFillLevelsAndCapacities(tool)
			if hasMoreFillUnits and tool ~= vehicle then
				vehicle.cp.totalFillLevel = (vehicle.cp.totalFillLevel or 0) + tool.cp.fillLevel
				vehicle.cp.totalCapacity = (vehicle.cp.totalCapacity or 0 ) + tool.cp.capacity
				vehicle.cp.totalFillLevelPercent = (vehicle.cp.totalFillLevel*100)/vehicle.cp.totalCapacity;
				--print(string.format("%s: adding %s to vehicle.cp.totalFillLevel = %s",tostring(tool.name),tostring(tool.cp.fillLevel), tostring(vehicle.cp.totalFillLevel)))
				--print(string.format("%s: adding %s to vehicle.cp.totalCapacity = %s",tostring(tool.name),tostring(tool.cp.capacity), tostring(vehicle.cp.totalCapacity)))
				if tool.sowingMachine ~= nil then
					vehicle.cp.totalSeederFillLevel = (vehicle.cp.totalSeederFillLevel or 0) + tool.cp.seederFillLevel
					vehicle.cp.totalSeederCapacity = (vehicle.cp.totalSeederCapacity or 0) + tool.cp.seederCapacity
					vehicle.cp.totalSeederFillLevelPercent = (vehicle.cp.totalSeederFillLevel*100)/vehicle.cp.totalSeederCapacity
					--print(string.format("%s:  vehicle.cp.totalSeederFillLevel:%s",tostring(vehicle.name),tostring(vehicle.cp.totalSeederFillLevel)))
					--print(string.format("%s:  vehicle.cp.totalSeederCapacity:%s",tostring(vehicle.name),tostring(vehicle.cp.totalSeederCapacity)))
				end
				if tool.sprayer ~= nil then
					vehicle.cp.totalSprayerFillLevel = (vehicle.cp.totalSprayerFillLevel or 0) + tool.cp.sprayerFillLevel
					vehicle.cp.totalSprayerCapacity = (vehicle.cp.totalSprayerCapacity or 0) + tool.cp.sprayerCapacity
					vehicle.cp.totalSprayerFillLevelPercent = (vehicle.cp.totalSprayerFillLevel*100)/vehicle.cp.totalSprayerCapacity
					--print(string.format("%s:  vehicle.cp.totalSprayerFillLevel:%s",tostring(vehicle.name),tostring(vehicle.cp.totalSprayerFillLevel)))
					--print(string.format("%s:  vehicle.cp.totalSprayerCapacity:%s",tostring(vehicle.name),tostring(vehicle.cp.totalSprayerCapacity)))
				end
			end	
		end
	end
	--print(string.format("End of function: vehicle.cp.totalFillLevel:(%s)",tostring(vehicle.cp.totalFillLevel)))
end

function courseplay:setOwnFillLevelsAndCapacities(workTool,mode)
   local fillLevel,capacity = 0,0
	local fillLevelPercent = 0;
	local fillType = 0;
	if workTool.fillUnits == nil then
		return false
	end
	for index,fillUnit in pairs(workTool.fillUnits) do
		fillLevel = fillLevel + fillUnit.fillLevel
		capacity = capacity + fillUnit.capacity
		if fillLevel ~= nil and capacity ~= nil then
			fillLevelPercent = (fillLevel*100)/capacity;
		else
			fillLevelPercent = nil
		end
		fillType = fillUnit.lastValidFillType
		
		if workTool.sowingMachine ~= nil and index == workTool.sowingMachine.fillUnitIndex then
			workTool.cp.seederFillLevel = fillUnit.fillLevel
			--print(string.format("%s: adding %s to workTool.cp.seederFillLevel",tostring(workTool.name),tostring(fillUnit.fillLevel)))
			workTool.cp.seederCapacity = fillUnit.capacity
			--print(string.format("%s: adding %s to workTool.cp.seederCapacity",tostring(workTool.name),tostring(fillUnit.capacity)))
			if g_currentMission.missionInfo.helperBuySeeds then
				workTool.cp.seederFillLevel = 100
				workTool.cp.seederCapacity = 100
			end
			workTool.cp.seederFillLevelPercent = (fillUnit.fillLevel*100)/fillUnit.capacity;
		end
		if workTool.sprayer ~= nil and index == workTool.sprayer.fillUnitIndex then
			workTool.cp.sprayerFillLevel = fillUnit.fillLevel
			--print(string.format("%s: adding %s to workTool.cp.sprayerFillLevel",tostring(workTool.name),tostring(fillUnit.fillLevel)))
			workTool.cp.sprayerCapacity = fillUnit.capacity
			--print(string.format("%s: adding %s to workTool.cp.sprayerCapacity",tostring(workTool.name),tostring(fillUnit.capacity)))
			
			if courseplay:isSprayer(workTool) then 
				if (workTool.cp.isLiquidManureSprayer and g_currentMission.missionInfo.helperSlurrySource == 2)
					or (workTool.cp.isManureSprayer and g_currentMission.missionInfo.helperManureSource == 2)
					or (g_currentMission.missionInfo.helperBuyFertilizer and not workTool.cp.isLiquidManureSprayer and not workTool.cp.isManureSprayer) 
					then
						workTool.cp.sprayerFillLevel = 100
						workTool.cp.sprayerCapacity = 100
				end
			end
			workTool.cp.sprayerFillLevelPercent = (fillUnit.fillLevel*100)/fillUnit.capacity;
		end
	end 

	workTool.cp.fillLevel = fillLevel
	workTool.cp.capacity = capacity
	workTool.cp.fillLevelPercent = fillLevelPercent
	workTool.cp.fillType = fillType
	--print(string.format("%s: adding %s to workTool.cp.fillLevel",tostring(workTool.name),tostring(workTool.cp.fillLevel)))
	--print(string.format("%s: adding %s to workTool.cp.capacity",tostring(workTool.name),tostring(workTool.cp.capacity)))
	return true
end

function courseplay:setCollisionDirection(node, col, colDirX, colDirZ)
  local parent = getParent(col)
  local colDirY = 0
  if parent ~= node then
    colDirX, colDirY, colDirZ = worldDirectionToLocal(parent, localDirectionToWorld(node, colDirX, 0, colDirZ))
  end
  setDirection(col, colDirX, colDirY, colDirZ, 0, 1, 0)
end
