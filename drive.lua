local curFile = 'drive.lua';

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
		courseplay:unregister_at_combine(self, self.cp.activeCombine)
	end

	-- Turn on sound / control lights
	if not self.isControlled then
		setVisibility(self.aiMotorSound, true); --TODO (Jakob): still needed in FS13?
		self:setLightsVisibility(courseplay.lightsNeeded);
	end;

	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.rootNode);

	if self.recordnumber > self.maxnumber then
		courseplay:debug(string.format("drive %d: %s: self.recordnumber (%s) > self.maxnumber (%s)", debug.getinfo(1).currentline, nameNum(self), tostring(self.recordnumber), tostring(self.maxnumber)), 12); --this should never happen
		self.recordnumber = self.maxnumber;
	end;
	if self.recordnumber > 1 then
		self.cp.lastRecordnumber = self.recordnumber - 1;
	else
		self.cp.lastRecordnumber = 1;
	end;


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
	if courseplay:getIsVehicleOffsetValid(self) then
		cx, cz = courseplay:getVehicleOffsettedCoords(self, cx, cz);
	end;

	if courseplay.debugChannels[12] and self.cp.isTurning == nil then
		drawDebugPoint(cx, cty+3, cz, 0, 1 , 1, 1);
	end;

	self.cp.distanceToTarget = courseplay:distance(cx, cz, ctx, ctz);
	--courseplay:debug(string.format("Tx: %f2 Tz: %f2 WPcx: %f2 WPcz: %f2 dist: %f2 ", ctx, ctz, cx, cz, self.cp.distanceToTarget ), 2)
	local fwd = nil
	local distToChange = nil
	local lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, cx, cty, cz);

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

	if self.cp.mode == 4 or self.cp.mode == 8 then
		self.implementIsFull = (self.cp.tipperFillLevelPct ~= nil and self.cp.tipperFillLevelPct == 100);
	end;
	
	-- in a traffic yam?

	-- coordinates of coli
	--local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
	local tx, ty, tz = localToWorld(self.cp.DirectionNode,0,1,3)
	-- direction of tractor
	local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, 0, lz)

	-- RulModiä
	if self.cp.beaconLightsMode == 1 then --on streets only
		local combineNeedsBeacon = self.cp.isCombine and (self.grainTankFillLevel / self.grainTankCapacity) > 0.8;
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
	local activeTipper = nil
	local isBypassing = false


	--### WAITING POINTS - START
	if self.Waypoints[self.cp.lastRecordnumber].wait and self.wait then
		if self.cp.waitTimer == nil and self.cp.waitTime > 0 then
			self.cp.waitTimer = self.timer + self.cp.waitTime * 1000
		end
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
		-- wait for a specific amount of time
		if self.cp.waitTimer and self.timer > self.cp.waitTimer then
			self.cp.waitTimer = nil
			self.wait = false
		end
		allowedToDrive = false
	--### WAITING POINTS - END

	else
		-- MODES 1 & 2: unloading in trigger
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
			courseplay:handleMode3(self, self.cp.tipperFillLevelPct, allowedToDrive, dt);
		end;

		-- Fertilice loading --only for one Implement !
		if self.cp.mode == 4 then
			if self.cp.tipperAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
				local isInWorkArea = self.recordnumber > self.cp.startWork and self.recordnumber <= self.cp.stopWork;
				if self.tippers ~= nil and not isInWorkArea then
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, self.cp.tipperFillLevelPct, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
				end
			end;
		end

		if self.cp.mode == 7 then
			if self.recordnumber == self.maxnumber then
				if self.cp.curTarget.x ~= nil then
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
					allowedToDrive,lx,lz = courseplay:refillSprayer(self, self.cp.tipperFillLevelPct, self.cp.refillUntilPct, allowedToDrive, lx, lz, dt);
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

	-- Modes 4 & 6
	local workArea = false
	local workSpeed = 0;
	local isFinishingWork = false
	if (self.cp.mode == 4 or self.cp.mode == 6) and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
		if self.cp.mode == 4 and self.cp.tipperAttached and self.cp.startWork ~= nil and self.cp.stopWork ~= nil then
			allowedToDrive, workArea, workSpeed ,isFinishingWork = courseplay:handle_mode4(self, allowedToDrive, workSpeed, self.cp.tipperFillLevelPct)
		elseif self.cp.mode == 6 then
			allowedToDrive, workArea, workSpeed, activeTipper, isFinishingWork = courseplay:handle_mode6(self, allowedToDrive, workSpeed, self.cp.tipperFillLevelPct, lx , lz )
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
		allowedToDrive = courseplay:handle_mode9(self, self.cp.tipperFillLevelPct, allowedToDrive, dt);
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
				self.cp.isLoaded = true;
				self.recordnumber = i + 2
			end
		end
	end
	-- MODE 9 END



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
		self.cp.infoText = courseplay:loc("COURSEPLAY_ESL_NOT_SUPPORTED")
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

	-- Change the distance to the correct one on the Kirovets K700A.
	if self.cp.isKasi ~= nil then
		if fwd then
			self.cp.distanceToTarget = self.cp.distanceToTarget - self.cp.isKasi;
		else
			self.cp.distanceToTarget = self.cp.distanceToTarget + self.cp.isKasi;
		end;
		-- TODO: (Claus) Remove old Kasi stuff.
		--distToChange = distToChange * self.cp.isKasi
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
		local stearAngle = (dirRot - courseplay:getRealWorldRotation(self.cp.DirectionNode)) - curRot;
		lx, lz = Utils.getDirectionFromYRotation(stearAngle);

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


function courseplay:setTrafficCollision(vehicle, lx, lz, workArea) --!!!
	--local goForRaycast = vehicle.cp.mode == 1 or (vehicle.cp.mode == 3 and vehicle.recordnumber > 3) or vehicle.cp.mode == 5 or vehicle.cp.mode == 8 or ((vehicle.cp.mode == 4 or vehicle.cp.mode == 6) and vehicle.recordnumber > vehicle.cp.stopWork) or (vehicle.cp.mode == 2 and vehicle.recordnumber > 3)
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


function courseplay:checkTraffic(vehicle, display_warnings, allowedToDrive)
	local ahead = false
	local collisionVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId]
	--courseplay:debug(tableShow(vehicle, nameNum(vehicle), 4), 4)
	--if vehicle.CPnumCollidingVehicles ~= nil and vehicle.CPnumCollidingVehicles > 0 then
		if collisionVehicle ~= nil and not (vehicle.cp.mode == 9 and (collisionVehicle.allowFillFromAir or (collisionVehicle.cp and collisionVehicle.cp.mode9TrafficIgnoreVehicle))) then
			local vx, vy, vz = getWorldTranslation(vehicle.cp.collidingVehicleId)
			local tx, ty, tz = worldToLocal(vehicle.aiTrafficCollisionTrigger, vx, vy, vz)
			local xvx, xvy, xvz = getWorldTranslation(vehicle.aiTrafficCollisionTrigger)
			local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode)
			local x1, y1, z1 = 0,0,0
			local halfLength = Utils.getNoNil(collisionVehicle.sizeLength,5)/2
			x1,z1 = AIVehicleUtil.getDriveDirection(vehicle.cp.collidingVehicleId, x, y, z);
			if z1 > -0.9 then -- tractor in front of vehicle face2face or beside < 4 o'clock
				ahead = true
			end
			if math.abs(tx) > 5 and collisionVehicle.rootNode ~= nil and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then
				courseplay:debug(nameNum(vehicle)..": checkTraffic:	deleteCollisionVehicle",3)
				courseplay:deleteCollisionVehicle(vehicle)
				return allowedToDrive
			end
			if collisionVehicle.lastSpeedReal == nil or collisionVehicle.lastSpeedReal*3600 < 5 or ahead then
				--courseplay:debug(nameNum(vehicle)..": checkTraffic:	distance: "..tostring(tz-halfLength),3)
				if tz <= 2 + halfLength then
					allowedToDrive = false;
					vehicle.cp.inTraffic = true
					--courseplay:debug(nameNum(vehicle)..": checkTraffic:	Stop",3)
				elseif vehicle.lastSpeedReal*3600 > 10 then
					--courseplay:debug(nameNum(vehicle)..": checkTraffic:	brake",3)
					allowedToDrive = courseplay:brakeToStop(vehicle)
				else
					--courseplay:debug(nameNum(vehicle)..": checkTraffic:	do nothing - go, but set \"vehicle.cp.isTrafficBraking\"",3)
					vehicle.cp.isTrafficBraking = true
				end
			end
		end
	--end
	
	if display_warnings and vehicle.cp.inTraffic then
		courseplay:setGlobalInfoText(vehicle, 'TRAFFIC');
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

function courseplay:setSpeed(vehicle, refSpeed, sl)
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

		--SMK-34 et al.
		if coverType == 'setPlane' and tipper.plane.bOpen == showCover then
			if showCoverWhenTipping and isAtTipTrigger and not showCover then
				--
			else
				tipper:setPlane(not showCover);
			end;

		--Hobein 18t et al.
		elseif coverType == 'setCoverState' and tipper.cover.state ~= showCover then
			tipper:setCoverState(showCover);

		--TUW et al.
		elseif coverType == 'planeOpen' then
			if showCover and tipper.planeOpen then 
				tipper:setAnimationTime(3, tipper.animationParts[3].offSet, false);
			elseif not showCover and not tipper.planeOpen then
				tipper:setAnimationTime(3, tipper.animationParts[3].animDuration, false);
			end;

		--Marston / setSheet
		elseif coverType == 'setSheet' and tipper.sheet.isActive ~= showCover then
			tipper:setSheet(showCover);

		--default Giants trailers
		elseif coverType == 'defaultGiants' then
			for _,ci in pairs(coverItems) do
				if getVisibility(ci) ~= showCover then
					setVisibility(ci, showCover);
				end;
			end;
		end;
	end; --END for i,tipperWithCover in vehicle.cp.tippersWithCovers
end;

function courseplay:refillSprayer(self, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt)
	for i,activeTool in pairs(self.tippers) do
		local isSpecialSprayer = false
		local fillTrigger = nil;
		isSpecialSprayer, allowedToDrive, lx, lz = courseplay:handleSpecialSprayer(self, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, 'pull');
		if isSpecialSprayer then
			return allowedToDrive,lx,lz
		end;

		if courseplay:isSprayer(activeTool) or activeTool.cp.hasUrfSpec then --sprayer
			if self.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[self.cp.fillTrigger];
				if courseplay:fillTypesMatch(trigger, activeTool) then 
					--print(nameNum(activeTool) .. ': slow down, it's a sprayerFillTrigger')
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
				if activeTool.sprayerFillTriggers ~= nil and #activeTool.sprayerFillTriggers > 0 then
					fillTrigger = activeTool.sprayerFillTriggers[1];
					self.cp.fillTrigger = nil
				end;
			end;

			local fillTypesMatch = courseplay:fillTypesMatch(fillTrigger, activeTool);

			local canRefill = (activeToolFillLevel ~= nil and activeToolFillLevel < driveOn) and fillTypesMatch;
			--ManureLager: activeTool.ReFillTrigger has to be nil so it doesn't refill
			if self.cp.mode == 8 then
				canRefill = canRefill and activeTool.ReFillTrigger == nil and not courseplay:waypointsHaveAttr(self, self.recordnumber, -2, 2, 'wait', true, false);

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
				if not activeTool.isSprayerFilling then
					activeTool:setIsSprayerFilling(true);
				end;
				
				if sprayer.trailerInTrigger == activeTool then --Feldrand-Container Guellebomber
					sprayer.fill = true;
				end;

				self.cp.infoText = courseplay:loc("COURSEPLAY_LOADING_AMOUNT"):format(activeTool.fillLevel, activeTool.capacity);
			elseif self.cp.isLoaded or not self.cp.stopForLoading then
				if activeTool.isSprayerFilling then
					activeTool:setIsSprayerFilling(false);
				end;
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
			if fillLevelPct < driveOn and activeTool.sowingMachineFillTriggers[1] ~= nil then
				if not activeTool.isSowingMachineFilling then
					activeTool:setIsSowingMachineFilling(true);
				end;
				allowedToDrive = false;
				self.cp.infoText = courseplay:loc('COURSEPLAY_LOADING_AMOUNT'):format(activeTool.fillLevel, activeTool.capacity);
			elseif activeTool.sowingMachineFillTriggers[1] ~= nil then
				if activeTool.isSowingMachineFilling then
					activeTool:setIsSowingMachineFilling(false);
				end;
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
			vehicle.CPnumCollidingVehicles = math.max(vehicle.CPnumCollidingVehicles-1, 0);
			return refSpeed
		else
			local name = getName(vehicle.cp.collidingVehicleId)
			courseplay:debug(nameNum(vehicle)..": regulateTrafficSpeed:	 "..tostring(name),3)
		end
		local x, y, z = getWorldTranslation(vehicle.cp.collidingVehicleId)
		local x1, y1, z1 = worldToLocal(vehicle.rootNode, x, y, z)
		if z1 < 0 or math.abs(x1) > 5 and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then -- vehicle behind tractor
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
					return math.min(collisionVehicle.lastSpeedReal,refSpeed)
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
	if math.abs(lx) > 0.25 and vehicle.lastSpeedReal*3600 > 25 then
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

	if deltaMinus > 5 then
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