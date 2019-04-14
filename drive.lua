local curFile = 'drive.lua';

local abs, max, min, pow, sin , huge = math.abs, math.max, math.min, math.pow, math.sin, math.huge;
local _;
local avoidWorkAreaType = {};

-- drives recorded course
function courseplay:drive(self, dt)

	if self.cp.drivingMode:is(DrivingModeSetting.DRIVING_MODE_AIDRIVER) and self.cp.driver then
		self.cp.driver:drive(dt)
		return
	end

--[[ This is FS17 code	-- Reset Character each 2 min to prevent glitching out.
	if courseplay:timerIsThrough(self, "resetCharacter", false) then
		if self.currentHelper == nil then
			self.currentHelper = HelperUtil.getRandomHelper()
		end;
		if self.vehicleCharacter ~= nil then
			self.vehicleCharacter:delete();
			self.vehicleCharacter:loadCharacter(self.currentHelper.xmlFilename, getUserRandomizedMpColor(self.currentHelper.name));
			if self:getIsEntered() then
				self.vehicleCharacter:setCharacterVisibility(false);
			end;
		end;
		--print("Character have been reset!");
		courseplay:setCustomTimer(self, "resetCharacter", 300);
	end;
]]
	if self.cp.saveFuel then
		if self.spec_motorized.isMotorStarted then
			--print("stop Order")
			courseplay:setEngineState(self, false);
		end
	elseif not self.spec_motorized.isMotorStarted then
		courseplay:setEngineState(self, true);
		--("start Order")
	elseif not courseplay:getIsEngineReady(self) then
		AIVehicleUtil.driveInDirection(self, dt, 30, -1, 0, 28, allowedToDrive, moveForwards, 0, 1)
	end;

	if not courseplay:getCanUseCpMode(self) then
		--print('Can Use CP mode is false I dont want to drive')
		return;
	end;

	--keeping steering disabled
	if self.steeringEnabled then
		self.steeringEnabled = false;
	end
	-- debug for workAreas
	if courseplay.debugChannels[6] then
		if self.cp.aiFrontMarker and self.cp.backMarkerOffset then
			local directionNode	= self.isReverseDriving and self.cp.reverseDrivingDirectionNode or self.cp.DirectionNode;
			local tx1, ty1, tz1 = localToWorld(directionNode,3,1,self.cp.aiFrontMarker)
			local tx2, ty2, tz2 = localToWorld(directionNode,3,1,self.cp.backMarkerOffset)
			local nx, ny, nz = localDirectionToWorld(directionNode, -1, 0, 0)
			local distance = 6
			cpDebug:drawLine(tx1, ty1, tz1, 1, 0, 0, tx1+(nx*distance), ty1+(ny*distance), tz1+(nz*distance))
			cpDebug:drawLine(tx2, ty2, tz2, 1, 0, 0, tx2+(nx*distance), ty2+(ny*distance), tz2+(nz*distance))
		end;

		--[[Tommi if #avoidWorkAreaType == 0 then
			avoidWorkAreaType[WorkArea.AREATYPE_RIDGEMARKER] = true;
			avoidWorkAreaType[WorkArea.AREATYPE_MOWERDROP] = true;
			avoidWorkAreaType[WorkArea.AREATYPE_WINDROWERDROP] = true;
			avoidWorkAreaType[WorkArea.AREATYPE_TEDDERDROP] = true;
		end;]]
		for _,workTool in pairs(self.cp.workTools) do
			if workTool.workAreas then
				for k = 1, #workTool.workAreas do
					if not avoidWorkAreaType[workTool.workAreas[k].type] then
						for _, workArea in ipairs(workTool.workAreas) do
							local sx, sy, sz = getWorldTranslation(workArea["start"]);
							cpDebug:drawLine(sx, sy, sz, 1, 0, 0, sx, sy+3, sz);
							local wx, wy, wz = getWorldTranslation(workArea["width"]);
							cpDebug:drawLine(wx, wy, wz, 1, 0, 0, wx, wy+3, wz);
							local hx, hy, hz = getWorldTranslation(workArea["height"]);
							cpDebug:drawLine(hx, hy, hz, 1, 0, 0, hx, hy+3, hz);
						end;
					end;
				end;
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

	--[[ unregister at combine, if there is one
	if self.cp.driveUnloadNow == true and self.cp.positionWithCombine ~= nil then
		courseplay:unregisterFromCombine(self, self.cp.activeCombine)
	end]]


	-- === CURRENT VEHICLE POSITION ===
	-- cty is used throughout this function as the terrain height. 
	local ctx, cty, ctz = getWorldTranslation(self.cp.DirectionNode);
	if self.Waypoints[self.cp.waypointIndex].rev and self.cp.oldDirectionNode then
		ctx, cty, ctz = getWorldTranslation(self.cp.oldDirectionNode);
	end;
	if self.cp.waypointIndex > self.cp.numWaypoints then
		--courseplay:debug(string.format("drive %d: %s: self.cp.waypointIndex (%s) > self.cp.numWaypoints (%s)", debug.getinfo(1).currentline, nameNum(self), tostring(self.cp.waypointIndex), tostring(self.cp.numWaypoints)), 12); --this should never happen
		courseplay:setWaypointIndex(self, self.cp.numWaypoints);
	end;

	-- update the pure pursuit controller state
	self.cp.ppc:update()

	-- === CURRENT WAYPOINT POSITION ===
	-- cx, cz only used to get lx, lz (driving direction) unless we are using driveToPoint (which we don't at the moment)
	if self.cp.mode ~= 7 then
		cx, _, cz = self.cp.ppc:getCurrentWaypointPosition()
	end

	-- FIELDWORK - HORIZONTAL/VERTICAL OFFSET
	if courseplay:getIsVehicleOffsetValid(self) then
		cx, cz = courseplay:getVehicleOffsettedCoords(self, cx, cz);
		if courseplay.debugChannels[12] and self.cp.isTurning == nil then
			cpDebug:drawPoint(cx, cty+3, cz, 0, 1, 1);
		end;
	end;

	-- LOAD/UNLOAD/WAIT - HORIZONTAL/VERTICAL OFFSET
	if courseplay:getIsVehicleOffsetValid(self, true) then
		cx, cz = courseplay:getVehicleOffsettedCoords(self, cx, cz, true);
		if courseplay.debugChannels[12] and self.cp.isTurning == nil then
			cpDebug:drawPoint(cx, cty+3, cz, 0, 1 , 1);
		end;
	end;

	local isTightTurn
	cx, cz, isTightTurn = courseplay.applyTightTurnOffset( self, cx, cz )

	if courseplay.debugChannels[12] and self.cp.isTurning == nil then
		local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 300, cz);
		--drawDebugLine(ctx, cty + 3, ctz, 0, 1, 0, cx, posY + 3, cz, 0, 0, 1)
		cpDebug:drawLine(ctx, cty + 3, ctz, 0, 1, 0, cx, posY + 3, cz);
		if self.drawDebugLine then self.drawDebugLine() end
	end;
	if CpManager.isDeveloper and self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin and courseplay.debugChannels[12] then
		local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 300, cz);
		local desX, _, desZ = localToWorld(self.cp.DirectionNode, 0, 0, 5);
		cpDebug:drawLine(ctx, cty + 3.5, ctz, 0, 0, 1, desX, cty + 3.5, desZ);
	end;

	self.cp.distanceToTarget = courseplay:distance(cx, cz, ctx, ctz);

	-- from this point onward, ctx and ctz is not used. cty used only for terrain height		
	
	local fwd;
	local distToChange;

	-- coordinates of coli
	local tx, ty, tz = localToWorld(self.cp.DirectionNode, 0, 1, 3); --local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
	-- local direction of from DirectionNode to waypoint
	local lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, cx, cty, cz);
	
	-- at this point, we used the current waypoint position and the current vehicle position to calculate 
	-- lx, lz, that is, the direction we want to drive.
	
	-- world direction of from DirectionNode to waypoint
	local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, -0.1, lz);

	if self.cp.mode == 4 or self.cp.mode == 6 then
		if self.Waypoints[self.cp.waypointIndex].turnStart then
			self.cp.isTurning = self.Waypoints[self.cp.waypointIndex].turnStart;
		end

		--- If we are turning and abortWork is set, then check if we need to abort the turn
		if self.cp.isTurning and self.cp.abortWork ~= nil and not courseplay:onAlignmentCourse(self) then
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

	end;


	-- LIGHTS
	local combineBeaconOn = self.cp.isCombine and self.cp.totalFillLevelPercent > 80;
	local onStreet = (((self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 3 or self.cp.mode == 5) and self.cp.waypointIndex > 2 and self.cp.trailerFillDistance == nil)
		or ((self.cp.mode == 4 or self.cp.mode == 6) and self.cp.waypointIndex > self.cp.stopWork)
		or (self.cp.mode == 10 and (self.cp.waypointIndex > 1 or #self.cp.mode10.stoppedCourseplayers >0) )
	) or false;
	if onStreet then
		self.spec_lights.aiLightsTypesMask = courseplay.lights.HEADLIGHT_STREET
	else
		self.spec_lights.aiLightsTypesMask = courseplay.lights.HEADLIGHT_FULL
	end

	if self.cp.warningLightsMode == courseplay.lights.WARNING_LIGHTS_NEVER then -- never
		if self.beaconLightsActive then
			self:setBeaconLightsVisibility(false);
		end;
		if self.cp.hasHazardLights and self.spec_lights.turnLightState ~= Lights.TURNSIGNAL_OFF then
			self:setTurnLightState(Lights.TURNLIGHT_OFF);
		end;
	else -- on street/always
		local beaconOn = onStreet or combineBeaconOn or self.cp.warningLightsMode == courseplay.lights.WARNING_LIGHTS_BEACON_ALWAYS;
		if self.beaconLightsActive ~= beaconOn then
			self:setBeaconLightsVisibility(beaconOn);
		end;
		if self.cp.hasHazardLights then
			local hazardOn = self.cp.warningLightsMode == courseplay.lights.WARNING_LIGHTS_BEACON_HAZARD_ON_STREET and onStreet and not combineBeaconOn;
			if not hazardOn and self.spec_lights.turnLightState ~= Lights.TURNLIGHT_OFF then
				self:setTurnLightState(Lights.TURNLIGHT_OFF);
			elseif hazardOn and self.spec_lights.turnLightState ~= Lights.TURNLIGHT_HAZARD then
				self:setTurnLightState(Lights.TURNLIGHT_HAZARD);
			end;
		end;
	end;

	
	-- the tipper that is currently loaded/unloaded
	local isBypassing = false
	local isCrawlingToWait = false
	local isWaitingThisLoop = false
	local drive_on = false
	local wayPointIsWait = self.Waypoints[self.cp.previousWaypointIndex].wait
	local wayPointIsUnload = self.Waypoints[self.cp.previousWaypointIndex].unload
	local wayPointIsRevUnload = wayPointIsUnload and self.Waypoints[self.cp.previousWaypointIndex].rev
	local stopForUnload = false
	local breakCode = false
	local revUnloadingPoint = 0

	if self.Waypoints[self.cp.previousWaypointIndex].rev and self.cp.numUnloadPoints > 0 then
		for i=1,self.cp.numUnloadPoints do
			local index = self.cp.unloadPoints[i]
			if self.Waypoints[index].rev then
				revUnloadingPoint = index
			end
		end
	end

	if revUnloadingPoint > 0 then
		stopForUnload,breakCode  = courseplay:handleUnloading(self,true,dt,revUnloadingPoint)
		if stopForUnload then
			allowedToDrive = false;
		end
		if breakCode then
			return;
		end
	end
	-- ### WAITING POINTS - START
	if (wayPointIsWait or wayPointIsUnload) and self.cp.wait then
		isWaitingThisLoop = true
		-- set wait time end
		if self.cp.waitTimer == nil and self.cp.waitTime > 0 then
			self.cp.waitTimer = self.timer + self.cp.waitTime * 1000;
		end;
		if self.cp.mode <= 2 then
			if wayPointIsUnload then
				stopForUnload,breakCode  = courseplay:handleUnloading(self,wayPointIsRevUnload,dt)
			elseif self.cp.mode == 1 and wayPointIsWait then
				if self.cp.hasAugerWagon then
					courseplay:handle_mode1(self, allowedToDrive, dt);
				else
					CpManager:setGlobalInfoText(self, 'WAIT_POINT');
				end;
			end;
		elseif self.cp.mode == 3 and self.cp.workToolAttached then
			courseplay:handleMode3(self, allowedToDrive, dt);

		elseif self.cp.mode == 4 then
			if self.cp.previousWaypointIndex == self.cp.startWork then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.previousWaypointIndex == self.cp.stopWork and self.cp.abortWork ~= nil then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.waitPoints[3] and self.cp.previousWaypointIndex == self.cp.waitPoints[3] then
				local isInWorkArea = self.cp.waypointIndex > self.cp.startWork and self.cp.waypointIndex <= self.cp.stopWork;
				if self.cp.workToolAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.cp.workTools ~= nil and not isInWorkArea then
					-- this call never changes lx or lz
					allowedToDrive,lx,lz = courseplay:refillWorkTools(self, self.cp.refillUntilPct, allowedToDrive, lx, lz);
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
				if self.cp.makeHeaps then
					stopForUnload = courseplay:handleHeapUnloading(self);
				else
					stopForUnload,breakCode = courseplay:handleUnloading(self,wayPointIsRevUnload,dt);
				end;
			elseif self.cp.previousWaypointIndex == self.cp.startWork then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.previousWaypointIndex == self.cp.stopWork and self.cp.abortWork ~= nil then
				courseplay:setVehicleWait(self, false);
			elseif self.cp.previousWaypointIndex ~= self.cp.startWork and self.cp.previousWaypointIndex ~= self.cp.stopWork then
				if self.cp.hasBaleLoader then
					CpManager:setGlobalInfoText(self, 'UNLOADING_BALE');
				else
					CpManager:setGlobalInfoText(self, 'OVERLOADING_POINT');

					-- Set Timer if unloading pipe takes time before empty.
					if self.getFirstEnabledFillType and self.pipeParticleSystems and self.cp.totalFillLevelPercent > 0 then
						local filltype = self:getFirstEnabledFillType();
						if filltype ~= FillType.UNKNOWN and self.pipeParticleSystems[filltype] then
							local stopTime = self.pipeParticleSystems[filltype][1].stopTime;
							if stopTime then
								courseplay:setCustomTimer(self, "waitUntilPipeIsEmpty", stopTime);
							end;
						end;
					end;
				end;
				if (self.cp.totalFillLevelPercent == 0 and courseplay:timerIsThrough(self, "waitUntilPipeIsEmpty")) or drive_on then
					courseplay:resetCustomTimer(self, "waitUntilPipeIsEmpty", true);
					courseplay:setVehicleWait(self, false);
				end;
			end;
		elseif self.cp.mode == 8 then
			-- this call does not change lx or lz
			allowedToDrive, lx, lz = courseplay:handleMode8(self, false, true, allowedToDrive, lx, lz, dt);
		elseif self.cp.mode == 10 then
			self.cp.mode10.newApproach = true
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

		if breakCode then
			return
		end

		-- ### WAITING POINTS - END

		-- ### NON-WAITING POINTS
	else
		-- MODES 1 & 2: unloading in trigger
		if (self.cp.mode == 1 or (self.cp.mode == 2 and self.cp.driveUnloadNow)) and self.cp.totalFillLevel ~= nil and self.cp.tipRefOffset ~= nil and self.cp.workToolAttached then
			if not self.cp.hasAugerWagon and self.cp.currentTipTrigger == nil and self.cp.totalFillLevel > 0 and self.cp.waypointIndex > 2 and self.cp.waypointIndex < self.cp.numWaypoints and not self.Waypoints[self.cp.waypointIndex].rev then
				courseplay:doTriggerRaycasts(self, 'tipTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
			end;

			allowedToDrive,breakCode = courseplay:handle_mode1(self, allowedToDrive, dt);
		end;

		if breakCode then
			return
		end

		
		-- COMBI MODE / BYPASSING
		if (((self.cp.mode == 2 or self.cp.mode == 3) and self.cp.waypointIndex < 2) or self.cp.activeCombine) and self.cp.workToolAttached then
			self.cp.inTraffic = false
			courseplay:	handle_mode2(self, dt);
			return;
		elseif (self.cp.mode == 2 or self.cp.mode == 3) and self.cp.waypointIndex < 2 then
			isBypassing = true
			-- this changes the direction by changing lx/lz
			lx, lz = courseplay:isTheWayToTargetFree(self,lx, lz)
		elseif self.cp.mode == 6 and self.cp.hasBaleLoader and (self.cp.waypointIndex == self.cp.stopWork + 1 or (self.cp.abortWork ~= nil and self.cp.waypointIndex == self.cp.abortWork)) and not self.cp.realisticDriving then
			isBypassing = true
			-- this changes the direction by changing lx/lz
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
					-- lx, lz not changed by this call
					allowedToDrive,lx,lz = courseplay:refillWorkTools(self, self.cp.refillUntilPct, allowedToDrive, lx, lz);
				end
			end;

			-- MODE 6-7: HEAP UNLOADING
		elseif self.cp.mode == 6 and self.cp.makeHeaps then
			courseplay:handleHeapUnloading(self);


			-- MODE 8: REFILL LIQUID MANURE TRANSPORT
		elseif self.cp.mode == 8 then
			-- lx, lz not changed by this call
			allowedToDrive, lx, lz = courseplay:handleMode8(self, true, false, allowedToDrive, lx, lz, dt, tx, ty, tz, nx, ny, nz);
		end;

		-- MAP WEIGHT STATION
		--[[if courseplay:canUseWeightStation(self) then
			if self.cp.curMapWeightStation ~= nil or (self.cp.fillTrigger ~= nil and courseplay.triggers.all[self.cp.fillTrigger].isWeightStation) then
				allowedToDrive = courseplay:handleMapWeightStation(self, allowedToDrive);
			elseif courseplay:canScanForWeightStation(self) then
				courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', false, tx, ty, tz, nx, ny, nz);
			end;
		end;]]

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
		-- DO NOT DELETE fuelFillLevel is gone. This variable may be a replacment 
		
		allowedToDrive = courseplay:checkFuel(self,lx,lz,allowedToDrive)
		
		
		-- WATER WARNING
		if self.showWaterWarning then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'WATER');
		end;

		-- STOP AT END OR TRIGGER
		if self.cp.stopAtEnd and (self.cp.ppc:reachedLastWaypoint() or self.cp.currentTipTrigger ~= nil or self.cp.fillTrigger ~= nil) then
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

	-- MODE 3
	-- Support for mode3 handling multiple sugar cane trailers
	if self.cp.isMode3Unloading then
		allowedToDrive = courseplay:handleMode3(self, allowedToDrive, dt);
	end

	local workArea = false;
	local workSpeed = 0;
	local isFinishingWork = false;
	-- MODE 4
	if self.cp.mode == 4 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil and self.cp.workToolAttached then
		
		allowedToDrive, workArea, workSpeed, isFinishingWork, refSpeed = courseplay:handle_mode4(self, allowedToDrive, workSpeed, refSpeed);
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		
		if not workArea and self.cp.totalFillLevelPercent < self.cp.refillUntilPct and not self.cp.fillTrigger then
			courseplay:doTriggerRaycasts(self, 'specialTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end;

		if self.Waypoints[self.cp.waypointIndex].isConnectingTrack then
			courseplay:raiseImplements(self)
		end;

		if self.cp.abortWork then
			-- If we are navigating pathfinding then don't let drive handle driving and use the below function
				if self.cp.isNavigatingPathfinding == true then
					--inTraffic back to false this, clears the inTraffic Message
					self.cp.inTraffic = false
					courseplay:navigatePathToUnloadCourse(self, dt, allowedToDrive) 
					return
			end
		end

	-- MODE 6
	elseif self.cp.mode == 6 and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then

		allowedToDrive, workArea, workSpeed, breakCode, isFinishingWork,refSpeed = courseplay:handle_mode6(self, allowedToDrive, workSpeed, lx, lz,refSpeed,dt);
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	
		
		if not workArea and self.cp.currentTipTrigger == nil and self.cp.totalFillLevel and self.cp.totalFillLevel > 0 and self.capacity == nil and self.cp.tipRefOffset ~= nil and not self.Waypoints[self.cp.waypointIndex].rev then
			courseplay:doTriggerRaycasts(self, 'tipTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end;

		if self.Waypoints[self.cp.waypointIndex].isConnectingTrack then
			courseplay:raiseImplements(self)
		end;

		if breakCode then
			return
		end

		if self.cp.abortWork then
			-- If we are navigating pathfinding then don't let drive handle driving and use the below function
			if self.cp.isNavigatingPathfinding == true then
				--inTraffic back to false this, clears the inTraffic Message
				self.cp.inTraffic = false
				courseplay:navigatePathToUnloadCourse(self, dt, allowedToDrive)
				return
			end;
		end
		
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
			courseplay:checkSaveFuel(self,allowedToDrive)
			return;
		end;
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-4).."): refSpeed = "..tostring(refSpeed))
	end;


	self.cp.inTraffic = false;


	-- HANDLE TIPPER COVER
	if self.cp.tipperHasCover and self.cp.automaticCoverHandling and (self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 4 or self.cp.mode == 5 or self.cp.mode == 6) then
		local showCover = false;

		if self.cp.mode ~= 6 and self.cp.mode ~= 4 then
			local minCoverWaypoint = self.cp.mode == 1 and 4 or 3;
			showCover = self.cp.waypointIndex >= minCoverWaypoint and self.cp.waypointIndex < self.cp.numWaypoints and self.cp.currentTipTrigger == nil and self.cp.trailerFillDistance == nil and not courseplay:waypointsHaveAttr(self, self.cp.waypointIndex, -1, 2, "unload", true, false);
		elseif self.cp.mode == 4 then
			if self.cp.waitPoints[3] and self.cp.previousWaypointIndex == self.cp.waitPoints[3] then
				-- open cover at loading point
				showCover = false;
			else
				showCover = true; --will be handled in courseplay:openCloseCover() to prevent extra loops
			end;
		else
			showCover = not workArea and self.cp.currentTipTrigger == nil;
		end;

		courseplay:openCloseCover(self, showCover);
	elseif self.cp.tipperHasCover then
		courseplay:openCloseCover(self, false);
	end;

	-- CHECK TRAFFIC
	-- Ryan missing gcurrent_mission variable in this function allowedToDrive = courseplay:checkTraffic(self, true, allowedToDrive)

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
				courseplay:setDriveUnloadNow(self, true);
				courseplay:setWaypointIndex(self, i + 2);
			end
		end
	end
	-- MODE 9 END

	courseplay:checkSaveFuel(self,allowedToDrive)

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
		if self.cp.curSpeed > 1 then
			allowedToDrive = true;
			moveForwards = self.movingDirection == 1;
		end;
		--print('broken 779')
		AIVehicleUtil.driveInDirection(self, dt, 30, -1, 0, 28, allowedToDrive, moveForwards, 0, 1)
		--self.cp.speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): allowedToDrive false ")
		return;
	end;

	-- reset fixedWorldPosition
	if self.cp.fixedWorldPosition ~= nil then
		courseplay:deleteFixedWorldPosition(self);
	end;
	local isFieldWorking = ( self.cp.mode == 4 or self.cp.mode == 6 ) and not courseplay:onAlignmentCourse( self )

	if self.cp.isTurning then
		if isFieldWorking then
			if self.cp.turnTimeRecorded then
				self.cp.turnTimeRecorded = nil
				self.cp.recordedTurnTime = nil
			else
				self.cp.recordedTurnTime = (self.cp.recordedTurnTime or 0) + dt
			end
		end
		courseplay:turn(self, dt);
		self.cp.TrafficBrake = false

		return
	elseif isFieldWorking and self.cp.recordedTurnTime and not self.cp.turnTimeRecorded then
		local turnCount = 0
		for i=self.cp.waypointIndex, math.min( #self.Waypoints, self.cp.stopWork ) do
			if self.Waypoints[i].turnStart then
				turnCount = turnCount +1
			end
		end
		self.cp.calculatedTurnTime = turnCount*(self.cp.recordedTurnTime/1000)
		--print(" self.cp.recordedTurnTime: "..tostring(self.cp.recordedTurnTime).." turns: "..tostring(turnCount))
		self.cp.turnTimeRecorded = true
	elseif isFieldWorking and self.cp.waypointIndex < self.cp.stopWork then
		local distance = (self.cp.stopWork-self.cp.waypointIndex) *self.cp.mediumWpDistance -- m
		local speed = math.max (courseplay:round(self.lastSpeedReal*3600)/3.6,0.1)  --m/s
		--local speed = self:getCruiseControlSpeed()/3.6   --m/s
		local turnTime = math.floor(self.cp.calculatedTurnTime or 5)
		if self.cp.course.hasChangedTheWaypointIndex then
			self.cp.course.hasChangedTheWaypointIndex = nil
			self:setCpVar('timeRemaining',distance/speed + turnTime,courseplay.isClient)
		end
	elseif not isFieldWorking then
		self:setCpVar('timeRemaining',nil,courseplay.isClient)
	end



	--SPEED SETTING
	local isAtEnd   = self.cp.waypointIndex > self.cp.numWaypoints - 2;
	local isAtStart = self.cp.waypointIndex < 3;
	if 	((self.cp.mode == 1 or self.cp.mode == 5 or self.cp.mode == 8) and (isAtStart or isAtEnd or self.cp.trailerFillDistance ~= nil))
		or	((self.cp.mode == 2 or self.cp.mode == 3) and isAtEnd)
		or	(not workArea and self.cp.wait and ((isAtEnd and self.Waypoints[self.cp.waypointIndex].wait) or courseplay:waypointsHaveAttr(self, self.cp.waypointIndex, 0, 2, "wait", true, false)))
		or 	courseplay:waypointsHaveAttr(self, self.cp.waypointIndex, 0, 2, "unload", true, false)
		or 	(isAtEnd and self.Waypoints[self.cp.waypointIndex].rev)
		or	(not isAtEnd and (self.Waypoints[self.cp.waypointIndex].rev or self.Waypoints[self.cp.waypointIndex + 1].rev or self.Waypoints[self.cp.waypointIndex + 2].rev))
		or	(workSpeed ~= nil and workSpeed == 0.5) -- baler in mode 6 , slow down
		or 	(self.cp.mode == 3 and self.cp.isMode3Unloading == true)-- Mode 3 SugarCane Trailer
		or isCrawlingToWait
		or isTightTurn
	then
		refSpeed = math.min(self.cp.speeds.turn,refSpeed);              -- we are on the field, go field speed
		--debug nil speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	elseif ((self.cp.mode == 2 or self.cp.mode == 3) and isAtStart)
		or (workSpeed ~= nil and workSpeed == 1)
		or isFinishingWork then
		refSpeed = math.min(self.cp.speeds.field,refSpeed);
		--debug nil speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	else
		local mode7onCourse = true
		self.cp.speedDebugStreet = true
		if self.cp.mode ~= 7 then
			refSpeed = self.cp.speeds.street;
			--debug nil speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		elseif self.cp.modeState == 5 then
			mode7onCourse = false
		end
		if self.cp.speeds.useRecordingSpeed and self.Waypoints[self.cp.waypointIndex].speed ~= nil and mode7onCourse then
			if self.Waypoints[self.cp.waypointIndex].speed < self.cp.speeds.crawl then
				refSpeed = courseplay:getAverageWpSpeed(self , 4)
				--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				refSpeed = MathUtil.clamp(refSpeed, self.cp.speeds.crawl, self.Waypoints[self.cp.waypointIndex].speed); --normaly use speed from waypoint, but  maximum street speed
				--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
		end;
	end;


	if self.cp.collidingVehicleId ~= nil then
		refSpeed = courseplay:regulateTrafficSpeed(self, refSpeed, allowedToDrive);
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end

	if self.cp.currentTipTrigger ~= nil then
		if self.cp.currentTipTrigger.bunkerSilo ~= nil then
			refSpeed = Utils.getNoNil(self.cp.speeds.reverse, self.cp.speeds.crawl);
			if courseplay.debugChannels[14] and g_updateLoopIndex % 100 == 0 then
				courseplay:debug(string.format("%s: refSpeed: %.2f ", nameNum(self),refSpeed), 14);
			end
			
			--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		else
			refSpeed = self.cp.speeds.turn;
			--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		end;
	elseif self.cp.fillTrigger ~= nil then
		refSpeed = self.cp.speeds.turn;
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		self.cp.isInFilltrigger = false;
	end;

	--finishing field work- go straight till tool is ready
	if isFinishingWork then
		lx=0
		lz=1
	end

	--reverse

	if self.Waypoints[self.cp.waypointIndex].rev then
		local isReverseActive
		lx,lz,fwd, isReverseActive = courseplay:goReverse(self,lx,lz)
		-- let the PPC know if goReverse is the driving.
		self.cp.ppc:setReverseActive(isReverseActive)
		refSpeed = Utils.getNoNil(self.cp.speeds.reverse, self.cp.speeds.crawl)
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	else
		-- goReverse is not driving
		self.cp.ppc:setReverseActive(false)
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
				--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				self.cp.reverseBackToPoint = nil;
			end;
		else
			self.cp.isReverseBackToPoint = false;
		end;
	end
	if self.cp.makeHeaps and self.cp.waypointIndex >= self.cp.heapStart - 1	and self.cp.waypointIndex <= self.cp.heapStop and self.cp.totalFillLevel > 0 then
		refSpeed = self.cp.speeds.discharge
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		forceTrueSpeed = true
	end

	if abs(lx) > 0.5 then
		refSpeed = min(refSpeed, self.cp.speeds.turn)
		--speedDebugLine = ("drive("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end

	self.cp.speedDebugLine = speedDebugLine

	refSpeed = courseplay:setSpeed(self, refSpeed, forceTrueSpeed)

	 -- Four wheel drive 
	if self.cp.hasDriveControl and self.cp.driveControl.hasFourWD then 
		courseplay:setFourWheelDrive(self, workArea); 
	end; 
	

	local beforeReverse, afterReverse
	-- DISTANCE TO CHANGE WAYPOINT
	if ( self.cp.waypointIndex == 1 and not self.cp.alignment.justFinished ) or self.cp.waypointIndex == self.cp.numWaypoints - 1 or self.Waypoints[self.cp.waypointIndex].turnStart then
		if self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin then
			distToChange = 1; -- ArticulatedAxis vehicles
		else
			distToChange = 0.5;
		end;
	elseif self.cp.waypointIndex + 1 <= self.cp.numWaypoints then
		beforeReverse = (self.Waypoints[self.cp.waypointIndex + 1].rev and (self.Waypoints[self.cp.waypointIndex].rev == false))
		afterReverse = (not self.Waypoints[self.cp.waypointIndex + 1].rev and self.Waypoints[self.cp.previousWaypointIndex].rev)
		if (self.Waypoints[self.cp.waypointIndex].wait or beforeReverse) and self.Waypoints[self.cp.waypointIndex].rev == false then -- or afterReverse or self.cp.waypointIndex == 1
			if self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin then
				distToChange = 2; -- ArticulatedAxis vehicles
			else
				distToChange = 1;
			end;
		elseif (self.Waypoints[self.cp.waypointIndex].rev and self.Waypoints[self.cp.waypointIndex].wait) or afterReverse then
			if self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin then
				distToChange = 4; -- ArticulatedAxis vehicles
			else
				distToChange = 2;
			end;
		elseif self.Waypoints[self.cp.waypointIndex].rev then
			if self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin then
				distToChange = 4; -- ArticulatedAxis vehicles
			else
				distToChange = 2; --orig:1
			end;
		elseif self.cp.mode == 4 or self.cp.mode == 6 then
			distToChange = 5
		else
			if self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin then
				distToChange = 5; -- ArticulatedAxis vehicles
			else
				distToChange = 2.85; --orig: 5
			end;
		end;

		if beforeReverse then
			self.cp.shortestDistToWp = nil
		end
	else
		if self.spec_articulatedAxis and self.spec_articulatedAxis.rotMin then
			distToChange = 5; -- ArticulatedAxis vehicles stear better with a longer change distance
		else
			distToChange = 2.85; --orig: 5
		end;
	end
	--distToChange = 2;



	-- record shortest distance to the next waypoint
	if self.cp.shortestDistToWp == nil or self.cp.shortestDistToWp > self.cp.distanceToTarget then
		local shortestDistToWp = Utils.getNoNil( self.cp.shortestDistToWp, -1 )
		self.cp.shortestDistToWp = self.cp.distanceToTarget
		-- courseplay:debug( string.format( "shortestDistToWp %.3f, distanceToTarget %.3f", shortestDistToWp, self.cp.distanceToTarget ), 12 )
	end

	if self.isReverseDriving and not isFinishingWork then
		lz = -lz
	end

	-- if distance grows i must be circling. Allow for half a meter to tolerate slight calculation errors, especially at
	-- tight turns where we constantly recalculate the target
	if self.cp.distanceToTarget > ( self.cp.shortestDistToWp + 0.5 ) and self.cp.waypointIndex > 3 and self.cp.distanceToTarget < 15 and self.Waypoints[self.cp.waypointIndex].rev ~= true then
		distToChange = self.cp.distanceToTarget + 1
		--courseplay.debugVehicle( 12, self, "circling? wp=%d distToChange %.1f, shortestDistToWp %.3f, distanceToTarget %.3f",
		--	self.cp.waypointIndex, distToChange, self.cp.shortestDistToWp, self.cp.distanceToTarget )
	end

	if not self.cp.ppc:shouldChangeWaypoint(distToChange) or WpUnload or WpLoadEnd or isFinishingWork then
		if g_server ~= nil then
			local acceleration = 1;
			if self.cp.speedBrake then
				-- We only need to brake slightly.
				local mrAccelrator = .25
				if self.cp.useProgessiveBraking then
					mrAccelrator = self.cp.mrAccelrator -- We need to actually break the tractor even more when using MR due to no engine break
				end
				acceleration = (self.movingDirection == 1) == fwd and -mrAccelrator or mrAccelrator; -- Setting accelrator to a negative value will break the tractor.
			end;

			local steeringAngle = self.cp.steeringAngle;
			if self.cp.isFourWheelSteering and self.cp.curSpeed > 20 then
				-- We are a four wheel steered vehicle, so dampen the steeringAngle when driving fast, since we turn double as fast as normal and will cause oscillating.
				steeringAngle = self.cp.steeringAngle * 2;
			end;

			-- Using false to disable the driveToPoint. This could be made into an setting option later on.
			local useDriveToPoint = false --and self.cp.mode == 1 or self.cp.mode == 5 or (self.cp.waypointIndex > 4 and (self.cp.mode == 2 or self.cp.mode == 3));
			local disableLongCollisionCheck = workArea;
			if self.Waypoints[self.cp.waypointIndex].rev or not useDriveToPoint then
				if self.Waypoints[self.cp.waypointIndex].rev then
					if self.cp.revSteeringAngle then
						steeringAngle = self.cp.revSteeringAngle;
					end;
					disableLongCollisionCheck = true;
				end;
				if math.abs(self.lastSpeedReal) < 0.0001 and not g_currentMission.missionInfo.stopAndGoBraking then
					if not fwd then
						self.nextMovingDirection = -1
					else
						self.nextMovingDirection = 1
					end;
				end;
	
				--self,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
				--AIVehicleUtil.driveInDirection=function(...) log(...) end
				--print(string.format('self = %s dt = %d acceleration = %.1f self.cp.steeringAngle = %s moveForwards =%s lx = %.2f lz = %.2f refSpeed = %.2f',tostring(self),dt,acceleration,tostring(self.cp.steeringAngle),tostring(fwd),lx,lz,refSpeed))
				AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, acceleration, 0.5, 20, true, fwd, lx, lz, refSpeed, 1);
			else 
				local directionNode = self.aiVehicleDirectionNode or self.cp.DirectionNode;
				local tX,_,tZ = worldToLocal(directionNode, cx, cty, cz);
				if courseplay:isWheelloader(self) then
					tZ = tZ * 0.5; -- wheel loaders need to turn more
				end;
				print('broken 1077')
				print(string.format(' acceleration = %.1f fwd =%s lx = %.2f lz = %.2f refSpeed = %.2f',acceleration,tostring(fwd),tX,tZ,refSpeed))
				-- This works but does not steer correctly
				AIVehicleUtil.driveToPoint(self, dt, acceleration, allowedToDrive, fwd, tX, tZ, refSpeed, false);
			end;

			if not isBypassing then
				courseplay:setTrafficCollision(self, lx, lz, disableLongCollisionCheck);
			end
		end
	elseif not isWaitingThisLoop then
		-- reset distance to waypoint
		self.cp.shortestDistToWp = nil
		if not self.cp.ppc:reachedLastWaypoint() then -- = New
			if not self.cp.wait then
				courseplay:setVehicleWait(self, true);
			end
			-- Allows alignment course to be used to transition to up/down until some better fix for the transition can come about
			if self.Waypoints[self.cp.waypointIndex].isConnectingTrack and (self.cp.mode == 4 or self.cp.mode == 6) then
				local transitionWP = 0
				-- Local for a turn start to ensure we don't override a turn transition, we only want a transition that as no help
				-- Look 15 waypoints ahead, this may need adjustment if connecting track goes through a corner in headland this upsets this number
				for i=1,15 do
					if self.Waypoints[self.cp.waypointIndex + i] then
						if self.Waypoints[self.cp.waypointIndex + i].turnStart and self.Waypoints[self.cp.waypointIndex + i].lane then -- turn found break
							transitionWP = 0
							courseplay.debugVehicle( 12, self, "Turn Start Found No Align Course Needed")
							break
						elseif not self.Waypoints[self.cp.waypointIndex + i].lane then --No turn found and we are coming up on up/down transition set trastionWP
							transitionWP = i
							courseplay.debugVehicle( 12, self, "No Turn Start Found Align Course Needed in %d", transitionWP)
							break
						end
					else
						-- No need to look for wapoints ahead when beyond maxnumber of waypoints
						break
					end
				end
				if not courseplay:onAlignmentCourse(self) and transitionWP > 0 then
					courseplay:setWaypointIndex(self, self.cp.waypointIndex + transitionWP)
					self.cp.ppc:initialize()
					courseplay.debugVehicle( 12, self, "Setting Waypoint index to %d. Starting Alignement Course", self.cp.waypointIndex)
					courseplay:startAlignmentCourse( self, self.Waypoints[self.cp.waypointIndex], true )
					return
				end
			end
			-- SWITCH TO THE NEXT WAYPOINT
			self.cp.ppc:switchToNextWaypoint()
			courseplay.calculateTightTurnOffset( self )
			local rev = ""
			if beforeReverse then 
				rev = "beforeReverse"
			end
			if afterReverse then
				rev = rev .. " afterReverse"
			end
			courseplay:debug( string.format( "%s: Switch to next wp: %d, distToChange %.1f, %s", nameNum( self ), self.cp.waypointIndex, distToChange, rev ), 12 )

		else -- last waypoint: reset some variable
			if (self.cp.mode == 4 or self.cp.mode == 6) and not self.cp.hasUnloadingRefillingCourse then
				-- in a typical CP fashion we leave it to the reader to find out why there's a special
				-- handling for modes 4 and 6 :(
			else
				courseplay:setWaypointIndex(self, 1);
				self.cp.ppc:initialize()
			end
			self.cp.isUnloaded = false
			courseplay:setStopAtEnd(self, false);
			courseplay:setDriveUnloadNow(self, false);
			courseplay:setIsRecording(self, false);
			self:setCpVar('canDrive',true,courseplay.isClient)
		end
	end
end
-- END drive();

function getTarget(vehicle)
	-- current vehicle position
	local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
	-- current target
	local ctx, cty, ctz = vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vy, vehicle.Waypoints[vehicle.cp.waypointIndex].cz
	cty = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, ctx, cty, ctz)
	-- another waypoint, preferably the next, to determine the minimum distance of the vehicle from the course
	--local otherIx = vehicle.cp.waypointIndex < #vehicle.Waypoints and vehicle.cp.waypointIndex + 1 or vehicle.cp.waypointIndex - 1
	local otherIx = vehicle.cp.waypointIndex > 1 and vehicle.cp.waypointIndex - 1 or vehicle.cp.waypointIndex - 1
	if not otherIx then return lz end
	local ox, oy, oz = vehicle.Waypoints[otherIx].cx, 0, vehicle.Waypoints[otherIx].cz
	oy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, ox, oy, oz)
	-- closest distance to the current waypoint vector (google point's distance from line)
	local dx, dy = ox - ctx, oy - cty
	local minD = math.abs(dy * vx - dx * vy + ox * cty - oy * ctx) / math.sqrt(dy * dy + dx * dx)

	local currentWpNode = courseplay.createNode( 'currentWpNode', ctx, ctz, math.rad( vehicle.Waypoints[ vehicle.cp.waypointIndex ].angle ))

	local newX, _, newZ = localToWorld( currentWpNode, vehicle.cp.tightTurnOffset, 0, 0 )
	courseplay.destroyNode( currentWpNode )


end

function courseplay:setTrafficCollision(vehicle, lx, lz, disableLongCheck)
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
				if disableLongCheck or recordNumber + i >= vehicle.cp.numWaypoints or recordNumber < 2 then
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

function courseplay:setSpeed(vehicle, refSpeed,forceTrueSpeed)
	local newSpeed = math.max(refSpeed,3)
	--[[This is no longer neccessary handled by Giants if vehicle.cruiseControl.state == Drivable.CRUISECONTROL_STATE_OFF then
		vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
	end ]]
	local deltaMinus = vehicle.cp.curSpeed - refSpeed;
	if not forceTrueSpeed then
		if newSpeed < vehicle:getCruiseControlSpeed() then
			newSpeed = math.max(newSpeed, vehicle.cp.curSpeed - math.max(0.1, math.min(deltaMinus * 0.5, 3)));
		end;
	end
	-- TODO: is this really necessary
	vehicle:setCruiseControlMaxSpeed(newSpeed)

	courseplay:handleSlipping(vehicle, refSpeed);

	if vehicle.cp.useProgessiveBraking then
		courseplay:mrProgressiveBreaking(vehicle, refSpeed)
		if vehicle.cp.mrAccelrator then
			vehicle.cp.speedBrake = true;
		else
			vehicle.cp.speedBrake = false;
		end
	else
		local tolerance = 2.5;

		if vehicle.cp.currentTipTrigger and vehicle.cp.currentTipTrigger.bunkerSilo then
			tolerance = 1;
		end;
		if deltaMinus > tolerance then
			vehicle.cp.speedBrake = true;
		else
			vehicle.cp.speedBrake = false;
		end;
	end;

	return newSpeed;
end

function courseplay:mrProgressiveBreaking(vehicle, refSpeed)
	local deltaMinus = vehicle.cp.curSpeed - refSpeed;
	if vehicle.cp.currentTipTrigger and vehicle.cp.currentTipTrigger.bunkerSilo then
		deltaMinus = deltaMinus + .5
	elseif  deltaMinus > 7.5 then
		vehicle.cp.mrAccelrator = 1
	elseif  deltaMinus > 5 then
		vehicle.cp.mrAccelrator = .75
	elseif  deltaMinus > 2.5 then
		vehicle.cp.mrAccelrator = 0.5
	elseif  deltaMinus > 1.5 then
		vehicle.cp.mrAccelrator = 0.25
	else 
		vehicle.cp.mrAccelrator = nil
	end
end

function courseplay:getSpeedWithLimiter(vehicle, refSpeed)
	local speedLimit, speedLimitActivated = vehicle:getSpeedLimit(true);
	refSpeed = min(refSpeed, speedLimit);

	return refSpeed, speedLimitActivated;
end

function courseplay:openCloseCover(vehicle, showCover, fillTrigger)
	if not vehicle.cp.automaticCoverHandling then
		return
	end
	
	for i,twc in pairs(vehicle.cp.tippersWithCovers) do
		local tIdx, coverType, showCoverWhenTipping, coverItems = twc.tipperIndex, twc.coverType, twc.showCoverWhenTipping, twc.coverItems;
		local tipper = vehicle.cp.workTools[tIdx];
		local numCovers = #tipper.spec_cover.covers
		-- default Giants trailers
		if coverType == 'defaultGiants' then
			--open cover
			if not showCover then
				--we have more covers, open the one related to the fillUnit
				if numCovers > 1 and (courseplay:isSprayer(tipper) or courseplay:isSowingMachine(tipper)) and fillTrigger then
					local fillUnits = tipper:getFillUnits()
					for i=1,#fillUnits do	
						if courseplay:fillTypesMatch(vehicle, fillTrigger, tipper, i) then
							local cover = tipper:getCoverByFillUnitIndex(i)
							if tipper.spec_cover.state ~= cover.index then
								tipper:setCoverState(cover.index ,true);
							end
						end
					end
				else
					--we have just one, easy going
					local newState = 1    
					if tipper.spec_cover.state ~= newState and tipper:getIsNextCoverStateAllowed(newState) then
						tipper:setCoverState(newState,true);
					end
				end
			else --showCover	
				local newState = 0         
				if tipper.spec_cover.state ~= newState then
					if tipper:getIsNextCoverStateAllowed(newState) then
						tipper:setCoverState(newState,true);
					else
						for i=tipper.spec_cover.state,numCovers do
							if tipper:getIsNextCoverStateAllowed(i+1)then
								tipper:setCoverState(i+1,true);
							end
							if tipper:getIsNextCoverStateAllowed(newState) then
								tipper:setCoverState(newState,true);
								break
							end
						end
					end;
				end
			end
			
			

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



function courseplay:getIsVehicleOffsetValid(vehicle, isLoadUnloadWait)
	local valid = (vehicle.cp.totalOffsetX ~= nil and vehicle.cp.toolOffsetZ ~= nil and (vehicle.cp.totalOffsetX ~= 0 or vehicle.cp.toolOffsetZ ~= 0))
		or (isLoadUnloadWait == true and vehicle.cp.loadUnloadOffsetX ~= nil and vehicle.cp.loadUnloadOffsetZ ~= nil and (vehicle.cp.loadUnloadOffsetX ~= 0 or vehicle.cp.loadUnloadOffsetZ ~= 0));
	if not valid then
		return false;
	end;
	vehicle.cp.skipOffsetX = false;

	if not isLoadUnloadWait then
		if vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK then
			return vehicle.cp.waypointIndex >= vehicle.cp.startWork and vehicle.cp.waypointIndex <= vehicle.cp.stopWork;
		end;
	else
		if vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT then
			-- We are around the start area and dont have an overloader attached.
			if not vehicle.cp.hasAugerWagon and (vehicle.cp.waypointIndex > #vehicle.Waypoints - 6 or vehicle.cp.waypointIndex <= 4) then
				return true;
			end;
			-- Check if we are near an wait point
			if courseplay:isInWaitArea(vehicle, 6, 3) then
				if not vehicle.cp.hasAugerWagon then
					vehicle.cp.skipOffsetX = true;
				end;
				return true;
			end;
			-- Check if we are near an unload point
			if courseplay:isInUnloadArea(vehicle, 6, 3) then
				return true;
			end;
		elseif vehicle.cp.mode == courseplay.MODE_OVERLOADER then
			return courseplay:isInWaitArea(vehicle, 6, 3, 2, 1);
		elseif vehicle.cp.mode == courseplay.MODE_FIELDWORK then
			return (vehicle.cp.makeHeaps and courseplay:isInUnloadArea(vehicle, 6, 3, 3, 1, 2)) or courseplay:isInUnloadArea(vehicle, 6, 3, 3);
		elseif vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT then
			return courseplay:isInWaitArea(vehicle, 6, 3, nil, 1) or courseplay:isInUnloadArea(vehicle, 6, 3, nil, 1);
		end;
	end;

	return false;
end;

function courseplay:getVehicleOffsettedCoords(vehicle, x, z, isLoadUnloadWait)
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
		if not isLoadUnloadWait then
			x = x - dz * vehicle.cp.totalOffsetX + dx * vehicle.cp.toolOffsetZ;
			z = z + dx * vehicle.cp.totalOffsetX + dz * vehicle.cp.toolOffsetZ;
		else
			if not vehicle.cp.skipOffsetX then
				x = x - dz * vehicle.cp.loadUnloadOffsetX + dx * vehicle.cp.loadUnloadOffsetZ;
			end;
			z = z + dx * vehicle.cp.loadUnloadOffsetX + dz * vehicle.cp.loadUnloadOffsetZ;
		end;
	end;
	--courseplay:debug(string.format('%s: waypoint after offset [%.1fm]: cx=%.2f, cz=%.2f', nameNum(vehicle), vehicle.cp.totalOffsetX, cx, cz), 2);

	return x, z;
end;

--- If we are towing an implement, move to a bigger radius in tight turns
-- making sure that the towed implement's trajectory remains closer to the
-- course.
function courseplay.calculateTightTurnOffset( vehicle )
	if vehicle.cp.mode ~= courseplay.MODE_SEED_FERTILIZE and vehicle.cp.mode ~= courseplay.MODE_FIELDWORK then
		vehicle.cp.tightTurnOffset = 0
		return
	end
	-- first of all, does the current waypoint have radius data?
	local r = vehicle.Waypoints[ vehicle.cp.waypointIndex ].radius
	if not r then
		vehicle.cp.tightTurnOffset = 0
		return
	end
	-- is there a wheeled implement behind the tractor and is it on a pivot?
	local workTool = courseplay:getFirstReversingWheeledWorkTool( vehicle )
	if not workTool or not workTool.cp.realTurningNode then
		vehicle.cp.tightTurnOffset = 0
		return
	end
	-- get the distance between the tractor and the towed implement's turn node
	-- (not quite accurate when the angle between the tractor and the tool is high)
	local tractorX, _, tractorZ = getWorldTranslation( vehicle.cp.DirectionNode )
	local toolX, _, toolZ = getWorldTranslation( workTool.cp.realTurningNode )
	local towBarLength = courseplay:distance( tractorX, tractorZ, toolX, toolZ )

	-- Is this really a tight turn? It is when the tow bar is longer than radius / 3, otherwise
	-- we ignore it.
	if towBarLength < r / 3 then
		vehicle.cp.tightTurnOffset = 0
		return
	end

	-- Ok, looks like a tight turn, so we need to move a bit left or right of the course
	-- to keep the tool on the course.
	local rTractor = math.sqrt( r * r + towBarLength * towBarLength ) -- the radius the tractor should be on
	local offset = rTractor - r

	-- figure out left or right now?
	local nextAngle = vehicle.Waypoints[ math.min( vehicle.cp.waypointIndex + 1, #vehicle.Waypoints )].angle
	local currentAngle = vehicle.Waypoints[ vehicle.cp.waypointIndex ].angle
	if not nextAngle or not currentAngle then
		vehicle.cp.tightTurnOffset = 0
		return
	end

	if getDeltaAngle( math.rad( nextAngle ), math.rad( currentAngle )) < 0 then offset = -offset end

	-- smooth the offset a bit to avoid sudden changes
	local smoothOffset = ( offset + 2 * Utils.getNoNil( vehicle.cp.tightTurnOffset, 0 )) / 3
	vehicle.cp.tightTurnOffset = smoothOffset

	courseplay.debugVehicle( 12, vehicle, 'Tight turn, r = %.1f, tow bar = %.1f m, currentAngle = %.0f, nextAngle = %.0f, offset = %.1f, smoothOffset = %.1f',
		r, towBarLength, currentAngle, nextAngle, offset, smoothOffset )
end

--- Apply the offset for tight turns calculated earlier to the target
-- coordinates. Return true if any offset applied.
function courseplay.applyTightTurnOffset( vehicle, x, z )
	if not vehicle.cp.tightTurnOffset or math.abs( vehicle.cp.tightTurnOffset ) < 0.1 then
		return x, z, false
	end
	local currentWpNode = courseplay.createNode( 'currentWpNode', x, z, math.rad( vehicle.Waypoints[ vehicle.cp.waypointIndex ].angle ))
	local newX, _, newZ = localToWorld( currentWpNode, vehicle.cp.tightTurnOffset, 0, 0 )
	courseplay.destroyNode( currentWpNode )
	return newX, newZ, true
end

function courseplay:isInWaitArea(vehicle, wpBefore, wpAfter, fromWP, waitIndex, toWaitIndex)
	local fromWP = Utils.getNoNil(fromWP, 0);

	if vehicle.cp.numWaitPoints > 0 and vehicle.cp.waypointIndex > fromWP then
		local wpBefore = Utils.getNoNil(wpBefore, 1);
		local wpAfter = Utils.getNoNil(wpAfter, 0);
		if waitIndex and vehicle.cp.waitPoints[waitIndex] then
			local toWaitIndex = Utils.getNoNil(toWaitIndex, waitIndex);
			return vehicle.cp.waypointIndex > vehicle.cp.waitPoints[waitIndex] - wpBefore and vehicle.cp.waypointIndex <= vehicle.cp.waitPoints[toWaitIndex] + wpAfter;
		else
			for _, waitWayPointNum in ipairs(vehicle.cp.waitPoints) do
				if vehicle.cp.waypointIndex > waitWayPointNum - wpBefore and vehicle.cp.waypointIndex <= waitWayPointNum + wpAfter then
					return true;
				end;
			end;
		end;
	end;

	return false;
end;

function courseplay:isInUnloadArea(vehicle, wpBefore, wpAfter, fromWP, unloadIndex, toUnloadIndex)
	local fromWP = Utils.getNoNil(fromWP, 0);

	if vehicle.cp.numUnloadPoints > 0 and vehicle.cp.waypointIndex > fromWP then
		local wpBefore = Utils.getNoNil(wpBefore, 1);
		local wpAfter = Utils.getNoNil(wpAfter, 0);
		if unloadIndex and vehicle.cp.unloadPoints[unloadIndex] then
			local toUnloadIndex = Utils.getNoNil(toUnloadIndex, unloadIndex);
			return vehicle.cp.waypointIndex > vehicle.cp.unloadPoints[unloadIndex] - wpBefore and vehicle.cp.waypointIndex <= vehicle.cp.unloadPoints[toUnloadIndex] + wpAfter;
		else
			for _, unloadWayPointNum in ipairs(vehicle.cp.unloadPoints) do
				if vehicle.cp.waypointIndex > unloadWayPointNum - wpBefore and vehicle.cp.waypointIndex <= unloadWayPointNum + wpAfter then
					return true;
				end;
			end;
		end;
	end;

	return false;
end;

--[[function courseplay:handleMapWeightStation(vehicle, allowedToDrive)
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
		name = tostring(getName(station.triggerId));
		x, y, z = getWorldTranslation(station.triggerId);
		local distToStation = courseplay:distanceToPoint(vehicle, x, y, z);

		-- too far away from station -> abort
		if distToStation > 60 then
			vehicle.cp.fillTrigger = nil;
			courseplay:debug(('%s: station=%s, distToStation=%.1f -> set fillTrigger to nil, return allowedToDrive'):format(nameNum(vehicle), name, distToStation), 20);
			return allowedToDrive;
		end;


		local iAmInTrigger = false;
		for triggerVehicle, num in pairs(station.triggerVehicles) do
			-- VEHICLE (or some part of it) IN TRIGGER
			if vehicle.cpTrafficCollisionIgnoreList[triggerVehicle.rootNode] then
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
			--local displayX, displayY, displayZ = getWorldTranslation(vehicle.cp.curMapWeightStation.digits[1]);
			local displayX, displayY, displayZ = getWorldTranslation(vehicle.cp.curMapWeightStation.displayNumbers);
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

	-- Set isInFilltrigger to true, so we slow down on the trigger.
	vehicle.cp.isInFilltrigger = true; --vehicle.cp.curMapWeightStation ~= nil;

	if vehicle.cp.curMapWeightStation ~= nil then
		name = tostring(getName(vehicle.cp.curMapWeightStation.triggerId));
		vehicle.cp.fillTrigger = nil; -- really make sure fillTrigger is nil
		x, y, z = getWorldTranslation(vehicle.cp.curMapWeightStation.triggerId);
		vehToCenterX, _, vehToCenterZ = worldToLocal(vehicle.cp.DirectionNode, x, y, z);

		-- make sure to abort in case we somehow missed the stopping point
		if vehToCenterZ <= -45 or MathUtil.vector2Length(vehToCenterX, vehToCenterZ) > 45 then
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

		local isStopping = false;
		if vehicle.cp.curSpeed > 0.1 then
			courseplay:setCustomTimer(vehicle, "WeightStationWaitTime", 5);
			isStopping = true;
		end;

		-- tractor + trailer on scale -> stop
		if vehToCenterZ and vehToCenterZ <= stopAt + brakeDistance then
			local origAllowedToDrive = allowedToDrive;
			allowedToDrive = false;

			-- vehicle in trigger, still moving
			if isStopping then
				courseplay:debug(('%s: station=%s, vehToCenterZ=%.1f, vehicle at center -> stop'):format(nameNum(vehicle), name, vehToCenterZ), 20);

				-- vehicle in trigger, not moving, being weighed
			elseif not courseplay:timerIsThrough(vehicle, "WeightStationWaitTime", false) then
				CpManager:setGlobalInfoText(vehicle, 'WEIGHING_VEHICLE');
				courseplay:debug(('%s: station=%s, vehicle is being weighed'):format(nameNum(vehicle), name), 20);

				-- weighing finished -> continue
			else
				allowedToDrive = origAllowedToDrive;
				vehicle.cp.curMapWeightStation = nil;
				courseplay:resetCustomTimer(vehicle, "WeightStationWaitTime", true)
				courseplay:debug(('%s: station=%s, vehToCenterZ=%.1f, [WEIGHING DONE] -> set curMapWeightStation to nil, allowedToDrive=%s'):format(nameNum(vehicle), name, vehToCenterZ, tostring(allowedToDrive)), 20);
			end;

			return allowedToDrive;
		end;
	end;

	courseplay:debug(('%s: handleMapWeightStation() **END** -> station=%s, isInFrontOfStation=%s, isInStation=%s, vehToCenterZ=%s'):format(nameNum(vehicle), tostring(name), tostring(isInFrontOfStation), tostring(vehicle.cp.curMapWeightStation ~= nil), tostring(vehToCenterZ)), 20);

	return allowedToDrive;
end;]]

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
  local awdOn = workArea or vehicle.cp.isBGATipping or vehicle.cp.slippingStage ~= 0 or vehicle.cp.mode == 9 or vehicle.cp.mode == 10 or (vehicle.cp.mode == 2 and (vehicle.cp.modeState > 1 or vehicle.cp.waypointIndex < 3)); 
  local awdOff = not vehicle.cp.driveControl.alwaysUseFourWD and not workArea and not vehicle.cp.isBGATipping and vehicle.cp.slippingStage == 0 and vehicle.cp.mode ~= 9 and not (vehicle.cp.mode == 2 and vehicle.cp.modeState > 1); 
  if (awdOn or vehicle.cp.driveControl.mode > 0) and not vehicle.driveControl.fourWDandDifferentials.fourWheel then 
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
  local Front = targetLockStatus or (awdOn and (vehicle.cp.driveControl.mode == 2 or vehicle.cp.driveControl.mode == 4)); 
  local Rear = targetLockStatus or (awdOn and (vehicle.cp.driveControl.mode == 3 or vehicle.cp.driveControl.mode == 4)); 
 
  if vehicle.driveControl.fourWDandDifferentials.diffLockFront ~= Front then 
    courseplay:debug(('%s: set diffLockFront to %s'):format(nameNum(vehicle), tostring(targetLockStatus)), 14); 
    vehicle.driveControl.fourWDandDifferentials.diffLockFront = Front; 
    changed = true; 
  end; 
  if vehicle.driveControl.fourWDandDifferentials.diffLockBack ~= Rear then 
    courseplay:debug(('%s: set diffLockBack to %s'):format(nameNum(vehicle), tostring(targetLockStatus)), 14); 
    vehicle.driveControl.fourWDandDifferentials.diffLockBack = Rear; 
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

function courseplay:setWaypointIndex(vehicle, number,isRecording)
	if vehicle.cp.waypointIndex ~= number then
		vehicle.cp.course.hasChangedTheWaypointIndex = true
		if isRecording then
			vehicle.cp.waypointIndex = number
			courseplay.buttons:setActiveEnabled(vehicle, 'recording');
		else
			vehicle:setCpVar('waypointIndex',number,courseplay.isClient);
		end
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
	if vehicle.cp.totalSprayerFillLevel ~= nil and vehicle.cp.sprayerCapacity ~= nil then
		vehicle.cp.totalSprayerFillLevelPercent = (vehicle.cp.totalSprayerFillLevel*100)/vehicle.cp.totalSprayerCapacity
	end
	if vehicle.cp.fillLevel ~= nil and vehicle.cp.capacity ~= nil then
		vehicle.cp.totalFillLevelPercent = (vehicle.cp.fillLevel*100)/vehicle.cp.capacity;
	end
	--print(string.format("vehicle itself(%s): vehicle.cp.totalFillLevel:(%s)",tostring(vehicle:getName()),tostring(vehicle.cp.totalFillLevel)))
	--print(string.format("vehicle itself(%s): vehicle.cp.totalCapacity:(%s)",tostring(vehicle:getName()),tostring(vehicle.cp.totalCapacity)))
	if vehicle.cp.workTools ~= nil then
		for _,tool in pairs(vehicle.cp.workTools) do
			local hasMoreFillUnits = courseplay:setOwnFillLevelsAndCapacities(tool,vehicle.cp.mode)
			if hasMoreFillUnits and tool ~= vehicle then
				vehicle.cp.totalFillLevel = (vehicle.cp.totalFillLevel or 0) + tool.cp.fillLevel
				vehicle.cp.totalCapacity = (vehicle.cp.totalCapacity or 0 ) + tool.cp.capacity
				vehicle.cp.totalFillLevelPercent = (vehicle.cp.totalFillLevel*100)/vehicle.cp.totalCapacity;
				--print(string.format("%s: adding %s to vehicle.cp.totalFillLevel = %s",tostring(tool:getName()),tostring(tool.cp.fillLevel), tostring(vehicle.cp.totalFillLevel)))
				--print(string.format("%s: adding %s to vehicle.cp.totalCapacity = %s",tostring(tool:getName()),tostring(tool.cp.capacity), tostring(vehicle.cp.totalCapacity)))
				if tool.spec_sowingMachine ~= nil or tool.cp.isTreePlanter then
					vehicle.cp.totalSeederFillLevel = (vehicle.cp.totalSeederFillLevel or 0) + tool.cp.seederFillLevel
					vehicle.cp.totalSeederCapacity = (vehicle.cp.totalSeederCapacity or 0) + tool.cp.seederCapacity
					vehicle.cp.totalSeederFillLevelPercent = (vehicle.cp.totalSeederFillLevel*100)/vehicle.cp.totalSeederCapacity
					--print(string.format("%s:  vehicle.cp.totalSeederFillLevel:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSeederFillLevel)))
					--print(string.format("%s:  vehicle.cp.totalSeederCapacity:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSeederCapacity)))
				end
				if tool.spec_sprayer ~= nil then
					vehicle.cp.totalSprayerFillLevel = (vehicle.cp.totalSprayerFillLevel or 0) + tool.cp.sprayerFillLevel
					vehicle.cp.totalSprayerCapacity = (vehicle.cp.totalSprayerCapacity or 0) + tool.cp.sprayerCapacity
					vehicle.cp.totalSprayerFillLevelPercent = (vehicle.cp.totalSprayerFillLevel*100)/vehicle.cp.totalSprayerCapacity
					--print(string.format("%s:  vehicle.cp.totalSprayerFillLevel:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSprayerFillLevel)))
					--print(string.format("%s:  vehicle.cp.totalSprayerCapacity:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSprayerCapacity)))
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
	if workTool.getFillUnits == nil then
		return false
	end
	local fillUnits = workTool:getFillUnits()
	for index,fillUnit in pairs(fillUnits) do
		if mode == 10 and workTool.cp.hasSpecializationLeveler then
			if not workTool.cp.originalCapacities then
				workTool.cp.originalCapacities = {}
				workTool.cp.originalCapacities[index]= fillUnit.capacity
				fillUnit.capacity = fillUnit.capacity *3
			end
		end
		-- TODO: why not fillUnit.fillType == FillType.DIESEL? answer: because you may have diesel in your trailer
		if workTool.getConsumerFillUnitIndex and (index == workTool:getConsumerFillUnitIndex(FillType.DIESEL) 
		or index == workTool:getConsumerFillUnitIndex(FillType.DEF)
		or index == workTool:getConsumerFillUnitIndex(FillType.AIR))
		or fillUnit.capacity > 999999 then
		else
			
			fillLevel = fillLevel + fillUnit.fillLevel
			capacity = capacity + fillUnit.capacity
			if fillLevel ~= nil and capacity ~= nil then
				fillLevelPercent = (fillLevel*100)/capacity;
			else
				fillLevelPercent = nil
			end
			fillType = fillUnit.lastValidFillType
			if workTool.cp.isTreePlanter  then
				local hired = true
				if workTool.mountedSaplingPallet == nil then
					workTool.cp.seederFillLevel = 0
					hired = false;
				else
					workTool.cp.seederFillLevel = fillUnit.fillLevel
				end;
				if workTool.attacherVehicle ~= nil and workTool.attacherVehicle.isHired ~= hired and workTool.attacherVehicle.cp.isDriving then
					workTool.attacherVehicle.isHired = hired;
				end
				workTool.cp.seederCapacity = fillUnit.capacity
				workTool.cp.seederFillLevelPercent = (fillUnit.fillLevel*100)/fillUnit.capacity;
			end
			if workTool.spec_sowingMachine ~= nil and index == workTool.spec_sowingMachine.fillUnitIndex then
				workTool.cp.seederFillLevel = fillUnit.fillLevel
				--print(string.format("%s: adding %s to workTool.cp.seederFillLevel",tostring(workTool:getName()),tostring(fillUnit.fillLevel)))
				workTool.cp.seederCapacity = fillUnit.capacity
				--print(string.format("%s: adding %s to workTool.cp.seederCapacity",tostring(workTool:getName()),tostring(fillUnit.capacity)))
				if g_currentMission.missionInfo.helperBuySeeds then
					workTool.cp.seederFillLevel = 100
					workTool.cp.seederCapacity = 100
				end
				workTool.cp.seederFillLevelPercent = (fillUnit.fillLevel*100)/fillUnit.capacity;
			end
			if workTool.spec_sprayer ~= nil and index == workTool.spec_sprayer.fillUnitIndex then
				workTool.cp.sprayerFillLevel = fillUnit.fillLevel
				--print(string.format("%s: adding %s to workTool.cp.sprayerFillLevel",tostring(workTool:getName()),tostring(fillUnit.fillLevel)))
				workTool.cp.sprayerCapacity = fillUnit.capacity
				--print(string.format("%s: adding %s to workTool.cp.sprayerCapacity",tostring(workTool:getName()),tostring(fillUnit.capacity)))

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
	end

	workTool.cp.fillLevel = fillLevel
	workTool.cp.capacity = capacity
	workTool.cp.fillLevelPercent = fillLevelPercent
	workTool.cp.fillType = fillType
	--print(string.format("%s: adding %s to workTool.cp.fillLevel",tostring(workTool:getName()),tostring(workTool.cp.fillLevel)))
	--print(string.format("%s: adding %s to workTool.cp.capacity",tostring(workTool:getName()),tostring(workTool.cp.capacity)))
	return true
end

function courseplay:setCollisionDirection(node, col, colDirX, colDirZ)
	local parent = getParent(col)
	local colDirY = 0
	if parent ~= node then
		colDirX, colDirY, colDirZ = worldDirectionToLocal(parent, localDirectionToWorld(node, colDirX, 0, colDirZ))
	end
	if not ( math.abs( colDirX ) < 0.001 and math.abs( colDirZ ) < 0.001 ) then
		setDirection(col, colDirX, colDirY, colDirZ, 0, 1, 0);
	end;
end;

function courseplay:navigatePathToUnloadCourse(vehicle, dt, allowedToDrive)
	-- This function allows CP to naviagte to the start of the UnloadingCourse without leaving the field if pathfinding option is enabled
	local min = math.min
	local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode)
	local currentX, currentY, currentZ;
	local refSpeed;
	local handleTurn = false
	local xt, yt, zt;
	local dod;
	local speedDebugLine;
	local moveForwards = true
	--print(string.format('vehicle.cp.nextTargets %s vehicle.cp.curTarget.x = %s, vehicle.cp.curTarget.z =%s', tostring(vehicle.cp.nextTargets), tostring(vehicle.cp.curTarget.x), tostring(vehicle.cp.curTarget.z)))
	if vehicle.cp.curTarget.x ~= nil and vehicle.cp.curTarget.z ~= nil then
		courseplay:setInfoText(vehicle, string.format("COURSEPLAY_DRIVE_TO_WAYPOINT;%d;%d",vehicle.cp.curTarget.x,vehicle.cp.curTarget.z));
		currentX = vehicle.cp.curTarget.x
		currentY = vehicle.cp.curTarget.y
		currentZ = vehicle.cp.curTarget.z
		refSpeed = vehicle.cp.speeds.field
		--speedDebugLine = ("navigatePathToUnloadCourse("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		local distance_to_wp = courseplay:distanceToPoint(vehicle, currentX, currentY, currentZ);	

		-- avoid circling
		-- if we are closer than distToChange meters to the current waypoint, we switch our target to the next
		-- set to 5 cause this is what it was set to in Mode2. AKA I have no clue it worked for mode2 so if it aint broke I am not fixing it
		local distToChange = 5
				
		if vehicle.cp.shortestDistToWp == nil or vehicle.cp.shortestDistToWp > distance_to_wp then
			vehicle.cp.shortestDistToWp = distance_to_wp
		end

		if distance_to_wp > vehicle.cp.shortestDistToWp and distance_to_wp < 3 then
			distToChange = distance_to_wp + 1
		end
		--print(string.format('distance_to_wp = %s distToChange = %s ',tostring(distance_to_wp),tostring(distToChange)))
		if distance_to_wp < distToChange then
			-- Switching to next waypoint
			vehicle.cp.shortestDistToWp = nil
			if #(vehicle.cp.nextTargets) > 0 then
				-- still have waypoints left
				local continueCourse = true
				--Reset all variables in case generate path gives a course to close to the target and we have more targets left							
				local wx, wz = vehicle.Waypoints[vehicle.cp.waypointIndex].cx,vehicle.Waypoints[vehicle.cp.waypointIndex].cz
				local wy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, 0, wz)
				local distanceToTarget = courseplay:distanceToPoint(vehicle, wx, wy, wz)
				-- magic constants, based on WAG
				if distanceToTarget < vehicle.cp.turnDiameter*2 then
					courseplay.debugVehicle( 9, vehicle, "Only %.2f meters from end of pathfinding, abort course and countiune with the course", distanceToTarget )
					continueCourse = false
					vehicle.cp.nextTargets = {}
					vehicle.cp.isNavigatingPathfinding = false
					courseplay:startAlignmentCourse( vehicle, vehicle.Waypoints[vehicle.cp.waypointIndex], true)
				else
					courseplay.debugVehicle( 9, vehicle, "Abort Work is still %.2f meters from me, continuing pathfinding", distanceToTarget )
				end 
		
				if continueCourse then
					-- set next target and remome current one from list
					courseplay:setCurrentTargetFromList(vehicle, 1);
				end
			else
				-- no more waypoints left
				allowedToDrive = false
				--Reset All used variables and fire the alligment course incase we are not at the correct angle							
				courseplay.debugVehicle( 9, vehicle, "No more waypoints left abort course, resuming work" )
				continueCourse = false
				vehicle.cp.nextTargets = {}
				vehicle.cp.isNavigatingPathfinding = false
				courseplay:startAlignmentCourse( vehicle, vehicle.Waypoints[vehicle.cp.waypointIndex], true)
			end
		end
	end

	if vehicle.showWaterWarning then
		allowedToDrive = false
		CpManager:setGlobalInfoText(vehicle, 'WATER');
	end
	
		-- check traffic and calculate speed
		
	allowedToDrive = courseplay:checkTraffic(vehicle, true, allowedToDrive)
	if vehicle.cp.collidingVehicleId ~= nil then
		refSpeed = courseplay:regulateTrafficSpeed(vehicle,refSpeed,allowedToDrive)
		--speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end

	if g_server ~= nil then
		local lx, lz
		local moveForwards = true
		if currentX ~= nil and currentZ ~= nil then
			print('broken 2030')
			lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, currentX, y, currentZ)
		else
			allowedToDrive = false
		end
			
		if not allowedToDrive then
			print('broken 2037')
			AIVehicleUtil.driveInDirection(vehicle, dt, 30, 0, 0, 28, false, true, 0, 1)
			--vehicle.cp.speedDebugLine = ("navigatePathToUnloadCourse("..tostring(debug.getinfo(1).currentline-1).."): allowedToDrive false ")
			courseplay:resetSlippingTimers(vehicle)
			return;
		end
			
		if vehicle.cp.TrafficBrake then
			moveForwards = vehicle.movingDirection == -1;
			lx = 0
			lz = 1
		end

		if abs(lx) > 0.5 then
			refSpeed = min(refSpeed, vehicle.cp.speeds.turn)
			--speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		end
					
		if allowedToDrive then
			vehicle.cp.speedDebugLine = speedDebugLine
			courseplay:setSpeed(vehicle, refSpeed)
		end
	
		vehicle.cp.TrafficBrake = false

		local tx, tz
		-- when following waypoints, check obstacles on the course, not dead ahead
		if #vehicle.cp.nextTargets > 1 then
		-- look ahead two waypoints if we have that many
			tx, tz = vehicle.cp.nextTargets[ 2 ].x, vehicle.cp.nextTargets[ 2 ].z
		else
		-- otherwise just the next one
			tx, tz = vehicle.cp.curTarget.x, vehicle.cp.curTarget.z 
		end

		dod = MathUtil.vector2Length(lx, lz)
		lx, lz = courseplay:isTheWayToTargetFree(vehicle, lx, lz, tx, tz,dod )
	
		courseplay:setTrafficCollision(vehicle, lx, lz,true)

		if math.abs(vehicle.lastSpeedReal) < 0.0001 and not g_currentMission.missionInfo.stopAndGoBraking then
			if not moveForwards then
				vehicle.nextMovingDirection = -1
			else
				vehicle.nextMovingDirection = 1
			end;
		end;
	
		-- MR needs braking assitance
		local accelrator = 1
		if vehicle.cp.useProgessiveBraking then
			courseplay:mrProgressiveBreaking(vehicle, refSpeed)
			if vehicle.cp.mrAccelrator then
				accelrator = -vehicle.cp.mrAccelrator -- The progressive breaking function returns a postive number which accelerates the tractor 
			end
		end

		--print(string.format('accelrator = %.1f allowedToDrive = %s moveForwards =%s lx = %.2f lz = %.2f refSpeed = $.2f',accelrator,tostring(allowedToDrive),tostring(moveForwards),lx,lz,refSpeed))
		print('broken 2095')
		AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, accelrator, 0.5, 10, allowedToDrive, moveForwards, lx, lz, refSpeed, 1)

		if courseplay.debugChannels[9] and vehicle.cp.curTarget.x and vehicle.cp.curTarget.z then
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, vehicle.cp.curTarget.x, 0, vehicle.cp.curTarget.z)
			cpDebug:drawPoint(vehicle.cp.curTarget.x, y +2, vehicle.cp.curTarget.z, 1, 0.65, 0);

			for i,tp in pairs(vehicle.cp.nextTargets) do
				local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tp.x, 0, tp.z)
				cpDebug:drawPoint(tp.x, y +2, tp.z, 1, 0.65, 0);
				if i == 1 then
					cpDebug:drawLine(vehicle.cp.curTarget.x, y + 2, vehicle.cp.curTarget.z, 1, 0, 1, tp.x, y + 2, tp.z);
				else
					local pp = vehicle.cp.nextTargets[i-1];
					cpDebug:drawLine(pp.x, y+2, pp.z, 1, 0, 1, tp.x, y + 2, tp.z);
				end;
			end;
		end;
	end
end;

function courseplay:checkFuel(vehicle, lx, lz,allowedToDrive)
	if vehicle.getConsumerFillUnitIndex ~= nil then
		local isFilling = false
		local dieselIndex = vehicle:getConsumerFillUnitIndex(FillType.DIESEL)
		local currentFuelPercentage = vehicle:getFillUnitFillLevelPercentage(dieselIndex) * 100;
		local searchForFuel = not vehicle.isFuelFilling and (vehicle.cp.allwaysSearchFuel and currentFuelPercentage < 99 or currentFuelPercentage < 20); 
		if searchForFuel and not vehicle.cp.fuelFillTrigger then
			local nx, ny, nz = localDirectionToWorld(vehicle.cp.DirectionNode, lx, 0, lz);
			local tx, ty, tz = getWorldTranslation(vehicle.cp.DirectionNode)
			courseplay:doTriggerRaycasts(vehicle, 'fuelTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end
		
		if vehicle.cp.fuelFillTrigger then
			local trigger = courseplay.triggers.fillTriggers[vehicle.cp.fuelFillTrigger]
			if trigger ~= nil and courseplay:fillTypesMatch(vehicle, trigger, vehicle, dieselIndex) then
				allowedToDrive,isFilling = courseplay:fillOnTrigger(vehicle,vehicle,vehicle.cp.fuelFillTrigger)
			else
				vehicle.cp.fuelFillTrigger = nil
			end			
		end
		if currentFuelPercentage < 5 then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(vehicle, 'FUEL_MUST');
		elseif currentFuelPercentage < 20 and not vehicle.isFuelFilling then
			CpManager:setGlobalInfoText(vehicle, 'FUEL_SHOULD');
		elseif isFilling and currentFuelPercentage < 99.99 then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(vehicle, 'FUEL_IS');
		end;
	end
	return allowedToDrive;
end

-- do not delete this line
-- vim: set noexpandtab:
