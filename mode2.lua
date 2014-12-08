local curFile = 'mode2.lua';
local abs, ceil, max, min = math.abs, math.ceil, math.max, math.min;

--[[ MODE 2 STATES
 0: default, when not active
 1: wait for work at start point
 2: drive to combine
 3: drive to pipe / unload
 4: drive to the rear of the combine
 5: follow target points
 6: follow tractor
 7: wait for pipe
 8: all trailers are full
81: all trailers are full, tractor turns away from the combine
99: turn maneuver
10: switch side
--]]

function courseplay:handle_mode2(self, dt)
	local frontTractor;
	--[[
	if self.cp.tipperFillLevelPct >= self.cp.followAtFillLevel then --TODO: shouldn't this be the "tractor that following me"'s followAtFillLevel ?
		self.cp.allowFollowing = true
	else
		self.cp.allowFollowing = false
	end
	]]

	-- STATE 0 (default, when not active)
	if self.cp.modeState == 0 then
		courseplay:setModeState(self, 1);
	end


	-- STATE 1 (wait for work at start point)
	if self.cp.modeState == 1 and self.cp.activeCombine ~= nil then
		courseplay:unregisterFromCombine(self, self.cp.activeCombine)
	end

	-- STATE 8 (all trailers are full)
	if self.cp.modeState == 8 then
		courseplay:setRecordNumber(self, 2);
		courseplay:unregisterFromCombine(self, self.cp.activeCombine)
		courseplay:setModeState(self, 0);
		courseplay:setIsLoaded(self, true);
		return false
	end

	-- support multiple tippers
	if self.cp.currentTrailerToFill == nil then
		self.cp.currentTrailerToFill = 1
	end

	local current_tipper = self.cp.workTools[self.cp.currentTrailerToFill]

	if current_tipper == nil then
		self.cp.toolsDirty = true
		return false
	end


	-- STATE 10 (switch side)
	if self.cp.activeCombine ~= nil and (self.cp.modeState == 10 or self.cp.activeCombine.turnAP ~= nil and self.cp.activeCombine.turnAP == true) then
		local node = self.cp.activeCombine.cp.DirectionNode or self.cp.activeCombine.rootNode;
		if self.cp.combineOffset > 0 then
			self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(node, 25, 0, 0)
		else
			self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(node, -25, 0, 0)
		end
		courseplay:setModeState(self, 5);
		courseplay:setMode2NextState(self, 2);
	end

	if (current_tipper.fillLevel == current_tipper.capacity) or self.cp.isLoaded or (self.cp.tipperFillLevelPct >= self.cp.driveOnAtFillLevel and self.cp.modeState == 1) then
		if #(self.cp.workTools) > self.cp.currentTrailerToFill then -- TODO (Jakob): use numWorkTools
			self.cp.currentTrailerToFill = self.cp.currentTrailerToFill + 1
		else
			self.cp.currentTrailerToFill = nil
			--courseplay:unregisterFromCombine(self, self.cp.activeCombine)  
			if self.cp.modeState ~= 5 then
				local cx2, cz2 = self.Waypoints[1].cx, self.Waypoints[1].cz
				local lx2, lz2 = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, cx2, cty2, cz2);
				if lz2 > 0 or (self.cp.activeCombine ~= nil and self.cp.activeCombine.cp.isChopper) then
					if self.cp.combineOffset > 0 then
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, self.cp.turnRadius, 0, self.cp.turnRadius)
					else
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, -self.cp.turnRadius, 0, self.cp.turnRadius)
					end
				elseif self.cp.activeCombine ~= nil and not self.cp.activeCombine.cp.isChopper then
					if self.cp.combineOffset > 0 then
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, 3, 0, -self.cp.turnRadius)
					else
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, -3, 0, -self.cp.turnRadius)
					end
				end
				courseplay:setModeState(self, 5);
				courseplay:setMode2NextState(self, 81);
			end
		end
	end


	if self.cp.activeCombine ~= nil then
		if self.cp.positionWithCombine == 1 then
			-- is there a trailer to fill, or at least a waypoint to go to?
			if self.cp.currentTrailerToFill or self.cp.modeState == 5 then
				if self.cp.modeState == 6 then
					-- drive behind combine: courseplay:setModeState(self, 2);
					-- drive next to combine:
					courseplay:setModeState(self, 3);
				end
				courseplay:unload_combine(self, dt)
			end
		else
			-- follow tractor in front of me
			frontTractor = self.cp.activeCombine.courseplayers[self.cp.positionWithCombine - 1]
			courseplay:debug(string.format('%s: activeCombine ~= nil, my position=%d, frontTractor (positionWithCombine %d) = %q', nameNum(self), self.cp.positionWithCombine, self.cp.positionWithCombine - 1, nameNum(frontTractor)), 4);
			--	courseplay:follow_tractor(self, dt, tractor)
			courseplay:setModeState(self, 6);
			courseplay:unload_combine(self, dt)
		end
	else -- NO active combine
		-- STOP!!
		AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, 0, 0, 28, false, moveForwards, 0, 1)
		

		if self.cp.isLoaded then
			courseplay:setRecordNumber(self, 2);
			courseplay:setModeState(self, 99);
			return false
		end

		-- are there any combines out there that need my help?
		if courseplay:timerIsThrough(self, 'searchForCombines') then
			if self.cp.lastActiveCombine ~= nil then
				local distance = courseplay:distanceToObject(self, self.cp.lastActiveCombine)
				if distance > 20 then
					self.cp.lastActiveCombine = nil
				else
					courseplay:debug(string.format("%s (%s): last combine is just %.0f away, so wait", nameNum(self), tostring(self.id), distance), 4);
				end
			else 
				courseplay:updateReachableCombines(self)
			end
			courseplay:setCustomTimer(self, 'searchForCombines', 5);
		end

		--is any of the reachable combines full?
		if self.cp.reachableCombines ~= nil then
			if #self.cp.reachableCombines > 0 then
				-- choose the combine that needs me the most
				if self.cp.bestCombine ~= nil and self.cp.activeCombine == nil then
					courseplay:debug(string.format("%s (%s): request check-in @ %s", nameNum(self), tostring(self.id), tostring(self.cp.combineID)), 4);
					if courseplay:registerAtCombine(self, self.cp.bestCombine) then
						courseplay:setModeState(self, 2);
					end
				else
					courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_WAITING_FOR_FILL_LEVEL"));
				end


				local highest_fill_level = 0;
				local num_courseplayers = 0; --TODO: = fewest courseplayers ?
				local distance = 0;

				self.cp.bestCombine = nil;
				self.cp.combineID = 0;
				self.cp.distanceToCombine = 99999999999;

				-- chose the combine who needs me the most
				for k, combine in pairs(self.cp.reachableCombines) do
					if (combine.fillLevel >= (combine.capacity * self.cp.followAtFillLevel / 100)) or combine.capacity == 0 or combine.cp.wantsCourseplayer then
						if combine.capacity == 0 then
							if combine.courseplayers == nil then
								self.cp.bestCombine = combine
							else
								local numCombineCourseplayers = #combine.courseplayers;
								if numCombineCourseplayers <= num_courseplayers or self.cp.bestCombine == nil then
									num_courseplayers = numCombineCourseplayers;
									if numCombineCourseplayers > 0 then
										frontTractor = combine.courseplayers[num_courseplayers];
										local canFollowFrontTractor = frontTractor.cp.tipperFillLevelPct and frontTractor.cp.tipperFillLevelPct >= self.cp.followAtFillLevel;
										courseplay:debug(string.format('%s: frontTractor (pos %d)=%q, canFollowFrontTractor=%s', nameNum(self), numCombineCourseplayers, nameNum(frontTractor), tostring(canFollowFrontTractor)), 4);
										if canFollowFrontTractor then
											self.cp.bestCombine = combine
										end
									else
										self.cp.bestCombine = combine
									end
								end;
							end 

						elseif combine.fillLevel >= highest_fill_level and combine.cp.isCheckedIn == nil then
							highest_fill_level = combine.fillLevel
							self.cp.bestCombine = combine
							distance = courseplay:distanceToObject(self, combine);
							self.cp.distanceToCombine = distance
							self.cp.callCombineFillLevel = self.cp.tipperFillLevelPct
							self.cp.combineID = combine.id
						end
					end
				end

				if self.cp.combineID ~= 0 then
					courseplay:debug(string.format("%s (%s): call combine: %s", nameNum(self), tostring(self.id), tostring(self.cp.combineID)), 4);
				end

			else
				courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_NO_COMBINE_IN_REACH"));
			end
		end
	end

	-- Four wheel drive
	if self.cp.hasDriveControl and self.cp.driveControl.hasFourWD then
		courseplay:setFourWheelDrive(self);
	end;
end

function courseplay:unload_combine(self, dt)
	local curFile = "mode2.lua"
	local allowedToDrive = true
	local combine = self.cp.activeCombine
	local x, y, z = getWorldTranslation(self.cp.DirectionNode)
	local currentX, currentY, currentZ;

	local combine_fill_level, combine_turning = nil, false
	local refSpeed;
	local handleTurn = false
	local isHarvester = false
	local xt, yt, zt;
	local dod;

	-- Calculate Trailer Offset

	if self.cp.currentTrailerToFill ~= nil then
		xt, yt, zt = worldToLocal(self.cp.workTools[self.cp.currentTrailerToFill].fillRootNode, x, y, z)
	else
		--courseplay:debug(nameNum(self) .. ": no cp.currentTrailerToFillSet", 4);
		xt, yt, zt = worldToLocal(self.cp.workTools[1].rootNode, x, y, z)
	end

	-- support for tippers like hw80
	if zt < 0 then
		zt = zt * -1
	end

	local trailer_offset = zt + self.cp.tipperOffset


	if self.cp.chopperIsTurning == nil then
		self.cp.chopperIsTurning = false
	end

	if combine.capacity > 0 then
		combine_fill_level = combine.fillLevel * 100 / combine.capacity
	else -- combine is a chopper / has no tank
		combine_fill_level = 51;
	end
	local tractor = combine
	if courseplay:isAttachedCombine(combine) then
		tractor = combine.attacherVehicle

		-- Really make sure the combine's attacherVehicle still exists - see issue #443
		if tractor == nil then
			courseplay:removeActiveCombineFromTractor(self);
			return;
		end;
	end;

	local combineIsHelperTurning = false
	if tractor.turnStage ~= nil and tractor.turnStage ~= 0 then
		combineIsHelperTurning = true
	end

	-- auto combine
	if self.cp.turnCounter == nil then
			self.cp.turnCounter = 0
	end
	
	local AutoCombineIsTurning = false
	local combineIsAutoCombine = false
	local autoCombineExtraMoveBack = 0
	if tractor.acParameters ~= nil and tractor.acParameters.enabled and tractor.isHired  then
		combineIsAutoCombine = true
		if tractor.cp.turnStage == nil then
			tractor.cp.turnStage = 0
		end
		-- if tractor.acTurnStage ~= 0 then 
		if tractor.acTurnStage > 0 and not (tractor.acTurnStage >= 20 and tractor.acTurnStage <= 22) then
			tractor.cp.turnStage = 2
			autoCombineExtraMoveBack = self.cp.turnRadius*1.5
			AutoCombineIsTurning = true
			-- print(('%s: acTurnStage=%d -> cp.turnState=2, AutoCombineIsTurning=true'):format(nameNum(tractor), tractor.acTurnStage)); --TODO: 140308 AutoTractor
		else
			tractor.cp.turnStage = 0
		end
	end
	
	-- is combine turning ?
	
	local aiTurn = combine.isAIThreshing and (combine.turnStage == 1 or combine.turnStage == 2 or combine.turnStage == 4 or combine.turnStage == 5)
	if tractor ~= nil and (aiTurn or (tractor.cp.turnStage > 0)) then
		courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_COMBINE_IS_TURNING")); -- "Drescher wendet. "
		combine_turning = true
		-- print(('%s: cp.turnStage=%d -> combine_turning=true'):format(nameNum(tractor), tractor.cp.turnStage));
	end
	if self.cp.modeState == 2 or self.cp.modeState == 3 or self.cp.modeState == 4 then
		if combine == nil then
			courseplay:setInfoText(self, "combine == nil, this should never happen");
			allowedToDrive = false
		end
	end

	local offset_to_chopper = self.cp.combineOffset
	if combineIsHelperTurning or tractor.cp.turnStage ~= 0 then
		offset_to_chopper = self.cp.combineOffset * 1.6 --1,3
	end


	local x1, y1, z1 = worldToLocal(combine.cp.DirectionNode or combine.rootNode, x, y, z)
	local distance = Utils.vector2Length(x1, z1)

	local safetyDistance = 11;
	if courseplay:isAttachedCombine(combine) then
		safetyDistance = 11;
	elseif combine.cp.isHarvesterSteerable or combine.cp.isSugarBeetLoader then
		safetyDistance = 24;
	elseif combine.cp.isCombine then
		safetyDistance = 10;
	elseif combine.cp.isChopper then
		safetyDistance = 11;
	end;

	-- STATE 2 (drive to combine)
	if self.cp.modeState == 2 then
		refSpeed = self.cp.speeds.field
		--courseplay:removeFromCombinesIgnoreList(self, combine)
		courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_DRIVE_BEHIND_COMBINE"));

		local x1, y1, z1 = worldToLocal(tractor.cp.DirectionNode or tractor.rootNode, x, y, z)

		if z1 > -(self.cp.turnRadius + safetyDistance) then -- tractor in front of combine     
			-- left side of combine
			local cx_left, cy_left, cz_left = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, 20, 0, -30)
			-- righ side of combine
			local cx_right, cy_right, cz_right = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, -20, 0, -30)
			local lx, ly, lz = worldToLocal(self.cp.DirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(self.cp.DirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)

			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end

		else
			-- tractor behind combine
			if not combine.cp.isChopper then
				currentX, currentY, currentZ = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, self.cp.combineOffset, 0, -(self.cp.turnRadius + safetyDistance)) --!!!
			else
				currentX, currentY, currentZ = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, 0, 0, -(self.cp.turnRadius + safetyDistance))
			end
		end

		--[[
		-- PATHFINDING / REALISTIC DRIVING (ASTAR)
		if self.cp.realisticDriving and not self.cp.calculatedCourseToCombine then
			-- if courseplay:calculate_course_to(self, currentX, currentZ) then
			if courseplay:calculateAstarPathToCoords(self, currentX, currentZ) then
				courseplay:setModeState(self, 5);
				self.cp.shortestDistToWp = nil;
				courseplay:setMode2NextState(self, 2); -- modeState when waypoint is reached
			end;
		end;
		--]]



		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, currentX, currentY, currentZ)
		dod = Utils.vector2Length(lx, lz)
		-- near point
		if dod < 3 then -- change to self.cp.modeState 4 == drive behind combine or cornChopper
			if combine.cp.isChopper and (not self.cp.chopperIsTurning or combineIsAutoCombine) then -- decide on which side to drive based on ai-combine
				courseplay:sideToDrive(self, combine, 10);
				if self.sideToDrive == "right" then
					self.cp.combineOffset = abs(self.cp.combineOffset) * -1;
				else 
					self.cp.combineOffset = abs(self.cp.combineOffset);
				end
			end
			courseplay:setModeState(self, 4);
		end;
		-- END STATE 2


	-- STATE 4 (drive to rear of combine)
	elseif self.cp.modeState == 4 then
		if combine.cp.offset == nil or self.cp.combineOffset == 0 then
			--print("offset not saved - calculate")
			courseplay:calculateCombineOffset(self, combine);
		elseif not combine.cp.isChopper and not combine.cp.isSugarBeetLoader and self.cp.combineOffsetAutoMode and self.cp.combineOffset ~= combine.cp.offset then
			--print("set saved offset")
			self.cp.combineOffset = combine.cp.offset			
		end
		courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_DRIVE_TO_COMBINE")); -- "Fahre zum Drescher"
		--courseplay:addToCombinesIgnoreList(self, combine)
		refSpeed = self.cp.speeds.field

		local tX, tY, tZ = nil, nil, nil

		if combine.cp.isSugarBeetLoader then
			local prnToCombineZ = courseplay:calculateVerticalOffset(self, combine);
	
			tX, tY, tZ = localToWorld(combine.cp.DirectionNode or combine.rootNode, self.cp.combineOffset, 0, prnToCombineZ -5);
		else			
			tX, tY, tZ = localToWorld(combine.cp.DirectionNode or combine.rootNode, self.cp.combineOffset, 0, -5);
		end

		if combine.attachedImplements ~= nil then
			for k, i in pairs(combine.attachedImplements) do
				local implement = i.object;
				if implement.haeckseldolly == true then
					tX, tY, tZ = localToWorld(implement.rootNode, self.cp.combineOffset, 0, trailer_offset)
				end
			end
		end

		currentX, currentZ = tX, tZ

		local lx, ly, lz = nil, nil, nil

		lx, ly, lz = worldToLocal(self.cp.DirectionNode, tX, y, tZ)

		if currentX ~= nil and currentZ ~= nil then
			local lx, ly, lz = worldToLocal(self.cp.DirectionNode, currentX, y, currentZ)
			dod = Utils.vector2Length(lx, lz)
		else
			dod = Utils.vector2Length(lx, lz)
		end


		if dod < 2 then -- dod < 2
			allowedToDrive = false
			courseplay:setModeState(self, 3); -- change to modeState 3 == drive to unload pipe
			self.cp.chopperIsTurning = false
		end

		if dod > 50 then
			courseplay:setModeState(self, 2);
		end
		-- END STATE 4


	-- STATE 3 (drive to unload pipe)
	elseif self.cp.modeState == 3 then

		courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_DRIVE_NEXT_TO_COMBINE"));
		--courseplay:addToCombinesIgnoreList(self, combine)
		refSpeed = self.cp.speeds.field

		if self.cp.nextTargets ~= nil then
			self.cp.nextTargets = {}
		end

		if combine_fill_level == 0 then --combine empty set waypoints on the field !!!
			if combine.cp.offset == nil then
				--print("saving offset")
				combine.cp.offset = self.cp.combineOffset;
			end			
			local fruitSide = courseplay:sideToDrive(self, combine, -10)
			if fruitSide == "none" then
				fruitSide = courseplay:sideToDrive(self, combine, -50)
			end
			local offset = abs(self.cp.combineOffset)
			local DirTx,_,DirTz = worldToLocal(self.cp.DirectionNode,self.Waypoints[self.maxnumber].cx,0, self.Waypoints[self.maxnumber].cz)
			if self.cp.combineOffset > 0 then  --I'm left
				if fruitSide == "right" or fruitSide == "none" then 
					courseplay:debug(nameNum(self) .. ": I'm left, fruit is right", 4)
					local fx,fy,fz = localToWorld(self.cp.DirectionNode, 0, 0, 8)
					local sx,sy,sz = localToWorld(self.cp.DirectionNode, 0 , 0, -self.cp.turnRadius-trailer_offset-autoCombineExtraMoveBack)
					if courseplay:isField(fx, fz) and not combineIsAutoCombine then
						courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, 0 , 0, 5);
						courseplay:setModeState(self, 5);
					elseif courseplay:isField(sx, sz) then
						courseplay:debug(nameNum(self) .. ": 2nd target is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, 2 , 0, -self.cp.turnRadius);
						courseplay:addNewTargetVector(self, 0 ,  -self.cp.turnRadius-trailer_offset-autoCombineExtraMoveBack);
						courseplay:setModeState(self, 5);
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.cp.DirectionNode, 2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTargetVector(self, DirTx, DirTz);
						courseplay:setModeState(self, 5);
					end					
				else
					courseplay:debug(nameNum(self) .. ": I'm left, fruit is left", 4)
					local fx,fy,fz = localToWorld(self.cp.DirectionNode, 3*offset*-1, 0, -self.cp.turnRadius-trailer_offset)
					local tx,ty,tz = localToWorld(self.cp.DirectionNode, 3*offset*-1, 0, -(2*self.cp.turnRadius)-trailer_offset)
					if courseplay:isField(fx, fz) then
						courseplay:debug(nameNum(self) .. ": deepest waypoint is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, 2, 0, -self.cp.turnRadius-trailer_offset);
						courseplay:addNewTargetVector(self, 3*offset*-1 ,  -self.cp.turnRadius-trailer_offset);
						fx,fy,fz = localToWorld(self.cp.DirectionNode, 3*offset*-1, 0, 0)
						local sx,sy,sz = localToWorld(self.cp.DirectionNode, 3*offset*-1, 0, -(2*self.cp.turnRadius)-trailer_offset)
						if courseplay:isField(fx, fz) then
							courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
							courseplay:addNewTargetVector(self, 3*offset*-1,0);
						elseif courseplay:isField(sx, sz) then
							courseplay:debug(nameNum(self) .. ": 2nd target is on field",4)
							courseplay:addNewTargetVector(self, 3*offset*-1 ,  -(2*self.cp.turnRadius)-trailer_offset);
						else
							courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
							self.cp.curTarget.x, self.cp.curTarget.z  = self.Waypoints[self.maxnumber].cx, self.Waypoints[self.maxnumber].cz
						end
						courseplay:setModeState(self, 5);
					elseif courseplay:isField(tx, tz) then
						courseplay:debug(nameNum(self) .. ": deepest waypoint is not on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, self.cp.turnRadius, 0, 0);
						courseplay:addNewTargetVector(self, 0 ,  -(2*trailer_offset));
						courseplay:addNewTargetVector(self, 3*offset*-1 ,  -(2*trailer_offset));
						courseplay:addNewTargetVector(self, 3*offset*-1 , self.cp.turnRadius);
						courseplay:setModeState(self, 5);
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.cp.DirectionNode, 2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTargetVector(self, DirTx, DirTz);
						courseplay:setModeState(self, 5);
					end
				end
			else
				if fruitSide == "right" or fruitSide == "none" then 
					courseplay:debug(nameNum(self) .. ": I'm right, fruit is right", 4)
					local fx,fy,fz = localToWorld(self.cp.DirectionNode, 3*offset, 0, -self.cp.turnRadius-trailer_offset)
					local sx,sy,sz = localToWorld(self.cp.DirectionNode, 3*offset,0,  -(2*trailer_offset))
					if courseplay:isField(fx, fz) then
						courseplay:debug(nameNum(self) .. ": deepest waypoint is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, -4, 0, -self.cp.turnRadius-trailer_offset);
						courseplay:addNewTargetVector(self, 3*offset ,  -self.cp.turnRadius-trailer_offset);
						fx,fy,fz = localToWorld(self.cp.DirectionNode, 3*offset, 0, 0)
						sx,sy,sz = localToWorld(self.cp.DirectionNode, 3*offset, 0, -(2*self.cp.turnRadius)-trailer_offset)
						if courseplay:isField(fx, fz) then
							courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
							courseplay:addNewTargetVector(self, 3*offset,0);

						elseif courseplay:isField(sx, sz) then
							courseplay:debug(nameNum(self) .. ": 2nd target is on field", 4)
							courseplay:addNewTargetVector(self, 3*offset,  -(2*self.cp.turnRadius)-trailer_offset);
						else
							courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
							self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.cp.DirectionNode, -2 , 0, -self.cp.turnRadius-trailer_offset)
							courseplay:addNewTargetVector(self, DirTx, DirTz);
						end
						courseplay:setModeState(self, 5);

					elseif courseplay:isField(sx, sz) then
						courseplay:debug(nameNum(self) .. ": deepest waypoint is not on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, -self.cp.turnRadius, 0, 0);
						courseplay:addNewTargetVector(self, 0 ,  -(2*trailer_offset));
						courseplay:addNewTargetVector(self, 3*offset,  -(2*trailer_offset));
						courseplay:addNewTargetVector(self, 3*offset, self.cp.turnRadius);
						courseplay:setModeState(self, 5);
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.cp.DirectionNode, -2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTargetVector(self, DirTx, DirTz);
						courseplay:setModeState(self, 5);
					end
				else
					courseplay:debug(nameNum(self) .. ": I'm right, fruit is left", 4)
					local fx,fy,fz = localToWorld(self.cp.DirectionNode, 0, 0, 3)
					local sx,sy,sz = localToWorld(self.cp.DirectionNode, 0,0, -self.cp.turnRadius-trailer_offset)
					if courseplay:isField(fx, fz) then
						courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
						courseplay:setModeState(self, 1);

					elseif courseplay:isField(sx, sz) then
						courseplay:debug(nameNum(self) .. ": 2nd target is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, -2 , 0, -self.cp.turnRadius);
						courseplay:addNewTargetVector(self, 0, -self.cp.turnRadius-trailer_offset);
						courseplay:setModeState(self, 5);
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.cp.DirectionNode, -2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTargetVector(self, DirTx, DirTz);
						courseplay:setModeState(self, 5);
					end

				end

			end


			if self.cp.tipperFillLevelPct >= self.cp.driveOnAtFillLevel then
				courseplay:setIsLoaded(self, true);
			else
				courseplay:setMode2NextState(self, 1);
			end
		end

		--CALCULATE HORIZONTAL OFFSET (side offset)
		if combine.cp.offset == nil and not combine.cp.isChopper then
			courseplay:calculateCombineOffset(self, combine);
		end
		currentX, currentY, currentZ = localToWorld(combine.cp.DirectionNode or combine.rootNode, self.cp.combineOffset, 0, trailer_offset + 5)
		
		--CALCULATE VERTICAL OFFSET (tipper offset)
		local prnToCombineZ = courseplay:calculateVerticalOffset(self, combine);
		
		--SET TARGET UNLOADING COORDINATES @ COMBINE
		local ttX, ttZ = courseplay:getTargetUnloadingCoords(self, combine, trailer_offset, prnToCombineZ);
		
		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, ttX, y, ttZ)
		dod = Utils.vector2Length(lx, lz)
		if dod > 40 or self.cp.chopperIsTurning == true then
			courseplay:setModeState(self, 2);
		end
		-- combine is not moving and trailer is under pipe
		if not combine.cp.isChopper and tractor.movingDirection == 0 and (lz <= 1 or lz < -0.1 * trailer_offset) then
			courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_COMBINE_WANTS_ME_TO_STOP")); -- "Drescher sagt ich soll anhalten."
			allowedToDrive = false
		elseif combine.cp.isChopper then
			if combine.movingDirection == 0 and dod == -1 and self.cp.chopperIsTurning == false then
				allowedToDrive = false
				courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_COMBINE_WANTS_ME_TO_STOP")); -- "Drescher sagt ich soll anhalten."
			end
			if lz < -2 then
				allowedToDrive = false
				courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_COMBINE_WANTS_ME_TO_STOP"));
				-- courseplay:setModeState(self, 2);
			end
		elseif lz < -1.5 then
				allowedToDrive = false
				courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_COMBINE_WANTS_ME_TO_STOP"));
		end

		-- refspeed depends on the distance to the combine
		local combine_speed = tractor.lastSpeed*3600
		if combine.cp.isChopper then
			if lz > 20 then
				refSpeed = self.cp.speeds.field
			elseif lz > 4 and (combine_speed*3600) > 5 then
				refSpeed = max(combine_speed *1.5,self.cp.speeds.crawl)
			elseif lz > 10 then
				refSpeed = self.cp.speeds.turn
			elseif lz < -1 then
				refSpeed = max(combine_speed/2,self.cp.speeds.crawl)
			else
				refSpeed = max(combine_speed,self.cp.speeds.crawl)
			end
			
			if ((combineIsHelperTurning or tractor.cp.turnStage ~= 0) and lz < 20) or (combine.movingDirection == 0 and lz < 5) then
				refSpeed = self.cp.speeds.crawl
			end
		else
			if lz > 5 then
				refSpeed = self.cp.speeds.field
			elseif lz < -0.5 then
				refSpeed = max(combine_speed - self.cp.speeds.crawl,self.cp.speeds.crawl)
			elseif lz > 1 or combine.sentPipeIsUnloading ~= true  then  
				refSpeed = max(combine_speed + self.cp.speeds.crawl,self.cp.speeds.crawl)
			else
				refSpeed = max(combine_speed,self.cp.speeds.crawl)
			end
			if ((combineIsHelperTurning or tractor.cp.turnStage ~= 0) and lz < 20) or (self.timer < self.cp.driveSlowTimer) or (combine.movingDirection == 0 and lz < 15) then
				refSpeed = self.cp.speeds.crawl
				if combineIsHelperTurning or tractor.cp.turnStage ~= 0 then
					self.cp.driveSlowTimer = self.timer + 2000
				end
			end
		
		end

		--courseplay:debug("combine.sentPipeIsUnloading: "..tostring(combine.sentPipeIsUnloading).." refSpeed:  "..tostring(refSpeed*3600).." combine_speed:  "..tostring(combine_speed*3600), 4)
	end;
	--END STATE 3

	---------------------------------------------------------------------

	local cx, cy, cz = getWorldTranslation(combine.cp.DirectionNode or combine.rootNode)
	local sx, sy, sz = getWorldTranslation(self.cp.DirectionNode)
	distance = courseplay:distance(sx, sz, cx, cz)
	if combine_turning and not combine.cp.isChopper then
		if combine.fillLevel > combine.capacity*0.9 then
			if combineIsAutoCombine and tractor.acIsCPStopped ~= nil then
				-- print(nameNum(tractor) .. ': fillLevel > 90%% -> set acIsCPStopped to true'); --TODO: 140308 AutoTractor
				tractor.acIsCPStopped = true
			elseif combine.isAIThreshing then 
				--allowedToDrive = false
				combine.waitForTurnTime = combine.timer + 100
			elseif tractor:getIsCourseplayDriving() then
				combine.cp.waitingForTrailerToUnload = true
			end
		elseif distance < 50 then
			if AutoCombineIsTurning and tractor.acIsCPStopped ~= nil then
				-- print(nameNum(tractor) .. ': distance < 50 -> set acIsCPStopped to true'); --TODO: 140308 AutoTractor
				tractor.acIsCPStopped = true
			elseif combine.isAIThreshing and not (combine_fill_level == 0 and combine.currentPipeState ~= 2) then
				--allowedToDrive = false
				combine.waitForTurnTime = combine.timer + 100
			elseif tractor:getIsCourseplayDriving() and not (combine_fill_level == 0 and combine:getOverloadingTrailerInRangePipeState()==0) then
				combine.cp.waitingForTrailerToUnload = true
			end
		elseif distance < 100 and self.cp.modeState == 2 then
			allowedToDrive = courseplay:brakeToStop(self)
		end 
	end
	if combine_turning and distance < 20 then
		if self.cp.modeState == 3 or self.cp.modeState == 4 then
			if combine.cp.isChopper then
				local fruitSide = courseplay:sideToDrive(self, combine, -10,true);
				
				--new chopper turn maneuver by Thomas Gärtner  
				if fruitSide == "left" then -- chopper will turn left

					if self.cp.combineOffset > 0 then -- I'm left of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm left", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, 0, 0, self.cp.turnRadius);
						courseplay:addNewTargetVector(self, 2*self.cp.turnRadius*-1 ,  self.cp.turnRadius);
						self.cp.chopperIsTurning = true
	
					else --i'm right of choppper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm right", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, self.cp.turnRadius*-1, 0, self.cp.turnRadius);
						self.cp.chopperIsTurning = true
					end
					
				else -- chopper will turn right
					if self.cp.combineOffset < 0 then -- I'm right of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm right", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, 0, 0, self.cp.turnRadius);
						courseplay:addNewTargetVector(self, 2*self.cp.turnRadius,     self.cp.turnRadius);
						self.cp.chopperIsTurning = true
					else -- I'm left of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm left", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.DirectionNode, self.cp.turnRadius, 0, self.cp.turnRadius);
						self.cp.chopperIsTurning = true
					end
				end

				if self.cp.combineOffsetAutoMode then
					if self.sideToDrive == "right" then
						self.cp.combineOffset = combine.cp.offset * -1;
					elseif self.sideToDrive == "left" then
						self.cp.combineOffset = combine.cp.offset;
					end;
				else
					if self.sideToDrive == "right" then
						self.cp.combineOffset = abs(self.cp.combineOffset) * -1;
					elseif self.sideToDrive == "left" then
						self.cp.combineOffset = abs(self.cp.combineOffset);
					end;
				end;
				courseplay:setModeState(self, 5);
				self.cp.shortestDistToWp = nil
				courseplay:setMode2NextState(self, 7);
			end
		-- elseif self.cp.modeState ~= 5 and self.cp.modeState ~= 99 and not self.cp.realisticDriving then
		elseif self.cp.modeState ~= 5 and self.cp.modeState ~= 9 and not self.cp.realisticDriving then
			-- just wait until combine has turned
			allowedToDrive = false
			courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_COMBINE_WANTS_ME_TO_STOP"));
		end
	end


	-- STATE 7
	if self.cp.modeState == 7 then
		if combine.movingDirection == 0 then
			courseplay:setModeState(self, 3);
		else
			courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_WAITING_FOR_COMBINE_TURNED"));
		end
		refSpeed = self.cp.speeds.turn
	end


	-- [[ TODO: MODESTATE 99 - WTF?
	-- STATE 99 (turn maneuver)
	if self.cp.modeState == 99 and self.cp.curTarget.x ~= nil and self.cp.curTarget.z ~= nil then
		--courseplay:removeFromCombinesIgnoreList(self, combine)
		courseplay:setInfoText(self, string.format(courseplay:loc("COURSEPLAY_TURNING_TO_COORDS"), self.cp.curTarget.x, self.cp.curTarget.z));
		allowedToDrive = false
		local mx, mz = self.cp.curTarget.x, self.cp.curTarget.z
		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, mx, y, mz)
		refSpeed = self.cp.speeds.field --self.cp.speeds.turn

		if lz > 0 and abs(lx) < lz * 0.5 then -- lz * 0.5    --2
			if self.cp.mode2nextState == 4 and not combine_turning then
				self.cp.curTarget.x = nil
				self.cp.curTarget.z = nil
				courseplay:switchToNextMode2State(self);
				courseplay:setMode2NextState(self, 0);
			end

			if self.cp.mode2nextState == 1 or self.cp.mode2nextState == 2 then
				-- is there another waypoint to go to?
				if #(self.cp.nextTargets) > 0 then
					courseplay:setModeState(self, 5);
					self.cp.shortestDistToWp = nil
					courseplay:setCurrentTargetFromList(self, 1);
				else
					courseplay:switchToNextMode2State(self);
					courseplay:setMode2NextState(self, 0);
				end
			end
		else
			currentX, currentY, currentZ = localToWorld(self.cp.DirectionNode, self.turn_factor, 0, 5)
			allowedToDrive = true
		end
	end
	--]]



	-- STATE 5 (follow target points)
	if self.cp.modeState == 5 and self.cp.curTarget.x ~= nil and self.cp.curTarget.z ~= nil then
		if combine ~= nil then
			--courseplay:removeFromCombinesIgnoreList(self, combine)
		end
		courseplay:setInfoText(self, string.format(courseplay:loc("COURSEPLAY_DRIVE_TO_WAYPOINT"), self.cp.curTarget.x, self.cp.curTarget.z));
		currentX = self.cp.curTarget.x
		currentY = self.cp.curTarget.y
		currentZ = self.cp.curTarget.z
		refSpeed = self.cp.speeds.field

		local distance_to_wp = courseplay:distanceToPoint(self, currentX, y, currentZ);

		if #(self.cp.nextTargets) == 0 then
			if distance_to_wp < 10 then
				refSpeed = self.cp.speeds.turn 
			end
		end

		-- avoid circling
		local distToChange = 1
		if self.cp.shortestDistToWp == nil or self.cp.shortestDistToWp > distance_to_wp then
			self.cp.shortestDistToWp = distance_to_wp
		end

		if distance_to_wp > self.cp.shortestDistToWp and distance_to_wp < 3 then
			distToChange = distance_to_wp + 1
		end

		if distance_to_wp < distToChange then
			if self.cp.mode2nextState == 81 then
				if self.cp.activeCombine ~= nil then
					courseplay:unregisterFromCombine(self, self.cp.activeCombine)
				end
			end

			self.cp.shortestDistToWp = nil
			if #(self.cp.nextTargets) > 0 then
				-- courseplay:setModeState(self, 5);
				courseplay:setCurrentTargetFromList(self, 1);
			else
				allowedToDrive = false
				if self.cp.mode2nextState ~= 2 then
					self.cp.calculatedCourseToCombine = false
				end
				if self.cp.mode2nextState == 7 then
					courseplay:switchToNextMode2State(self);
					--self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(combine.cp.DirectionNode or combine.rootNode, self.chopper_offset*0.7, 0, -9) -- -2          --??? *0,5 -10

				elseif self.cp.mode2nextState == 4 and combine_turning then
					courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_WAITING_FOR_COMBINE_TURNED"));
				elseif self.cp.mode2nextState == 81 then -- tipper turning from combine

					-- print(('%s [%s(%d)]: no nextTargets, mode2nextState=81 -> set recordnumber to 2, modeState to 99, isLoaded to true, return false'):format(nameNum(self), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
					courseplay:setRecordNumber(self, 2);
					courseplay:unregisterFromCombine(self, self.cp.activeCombine)
					courseplay:setModeState(self, 99);
					courseplay:setIsLoaded(self, true);

				elseif self.cp.mode2nextState == 1 then
					-- refSpeed = self.cp.speeds.turn
					courseplay:switchToNextMode2State(self);
					courseplay:setMode2NextState(self, 0);

				else
					courseplay:switchToNextMode2State(self);
					courseplay:setMode2NextState(self, 0);
				end
			end
		end
	end


	-- STATE 6 (follow tractor)
	local frontTractor;
	if self.cp.activeCombine and self.cp.activeCombine.courseplayers and self.cp.positionWithCombine then
		frontTractor = self.cp.activeCombine.courseplayers[self.cp.positionWithCombine - 1];
	end;
	if self.cp.modeState == 6 and frontTractor ~= nil then --Follow Tractor
		courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_FOLLOWING_TRACTOR"));
		--use the current tractor's sideToDrive as own
		if frontTractor.sideToDrive ~= nil and frontTractor.sideToDrive ~= self.sideToDrive then
			courseplay:debug(string.format("%s: setting current tractor's sideToDrive (%s) as my own", nameNum(self), tostring(frontTractor.sideToDrive)), 4);
			self.sideToDrive = frontTractor.sideToDrive;
		end;

		-- drive behind tractor
		local backDistance = max(10,(self.cp.turnRadius + safetyDistance))
		local dx,dz = AIVehicleUtil.getDriveDirection(frontTractor.cp.DirectionNode, x, y, z);
		local x1, y1, z1 = worldToLocal(frontTractor.cp.DirectionNode, x, y, z)
		local distance = Utils.vector2Length(x1, z1)
		if z1 > -backDistance and dz > -0.9 then
			-- tractor in front of tractor
			-- left side of tractor
			local cx_left, cy_left, cz_left = localToWorld(frontTractor.cp.DirectionNode, 30, 0, -backDistance-20)
			-- righ side of tractor
			local cx_right, cy_right, cz_right = localToWorld(frontTractor.cp.DirectionNode, -30, 0, -backDistance-20)
			local lx, ly, lz = worldToLocal(self.cp.DirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(self.cp.DirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)
			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end
		else
			-- tractor behind tractor
			currentX, currentY, currentZ = localToWorld(frontTractor.cp.DirectionNode, 0, 0, -backDistance * 1.5); -- -backDistance * 1
		end;



		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, currentX, currentY, currentZ)
		dod = Utils.vector2Length(lx, lz)
		-- if dod < 2 or (self.cp.positionWithCombine == 2 and frontTractor.cp.modeState ~= 3 and dod < 100) then
		if dod < 2 or (self.cp.positionWithCombine == 2 and combine.courseplayers[1].cp.modeState ~= 3 and dod < 100) then
			courseplay:debug(string.format('\tdod=%s, frontTractor.cp.modeState=%s -> brakeToStop', tostring(dod), tostring(frontTractor.cp.modeState)), 4);
			allowedToDrive = courseplay:brakeToStop(self)
		end
		if combine.cp.isSugarBeetLoader then
			if distance > 50 then
				refSpeed = self.cp.speeds.street
			else
				refSpeed = Utils.clamp(frontTractor.lastSpeedReal*3600, self.cp.speeds.turn, self.cp.speeds.field)
			end
		else
			if distance > 50 then
				refSpeed = self.cp.speeds.street
			else
				refSpeed = max(frontTractor.lastSpeedReal*3600,self.cp.speeds.crawl)
			end
		end
		--courseplay:debug(string.format("distance: %d  dod: %d",distance,dod ), 4)
	end

	if currentX == nil or currentZ == nil then
		courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_WAITING_FOR_WAYPOINT")); -- "Warte bis ich neuen Wegpunkt habe"
		allowedToDrive = courseplay:brakeToStop(self)
	end

	if self.cp.forcedToStop then
		courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_COMBINE_WANTS_ME_TO_STOP")); -- "Drescher sagt ich soll anhalten."
		allowedToDrive = courseplay:brakeToStop(self)
	end

	if self.showWaterWarning then
		allowedToDrive = false
		CpManager:setGlobalInfoText(self, 'WATER');
	end

	-- check traffic and calculate speed
	
	allowedToDrive = courseplay:checkTraffic(self, true, allowedToDrive)
	refSpeed = courseplay:regulateTrafficSpeed(self,refSpeed,allowedToDrive)

	
	if g_server ~= nil then
		local lx, lz = nil, nil
		local moveForwards = true
		if currentX ~= nil and currentZ ~= nil then
			lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, currentX, y, currentZ)
		else
			allowedToDrive = false
		end

		if not allowedToDrive then
			AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, 0, 1)
			return;
		end
		
		if self.cp.TrafficBrake then
			moveForwards = false
				lx = 0
				lz = 1
		end
		
		if abs(lx) > 0.5 then
			refSpeed = min(refSpeed, self.cp.speeds.turn)
		end
				
		if allowedToDrive then
			courseplay:setSpeed(self, refSpeed)
		end
		
		self.cp.TrafficBrake = false
		--[[if self.cp.modeState == 5 or self.cp.modeState == 2 then    FS15
			lx, lz = courseplay:isTheWayToTargetFree(self, lx, lz)
		end]]
		courseplay:setTrafficCollision(self, lx, lz,true)
		
		AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, moveForwards, lx, lz, refSpeed, 1)
		

		if courseplay.debugChannels[4] and self.cp.nextTargets and self.cp.curTarget.x and self.cp.curTarget.z then
			drawDebugPoint(self.cp.curTarget.x, self.cp.curTarget.y or 0, self.cp.curTarget.z, 1, 0.65, 0, 1);
			
			for i,tp in pairs(self.cp.nextTargets) do
				drawDebugPoint(tp.x, tp.y or 0, tp.z, 1, 0.65, 0, 1);
				if i == 1 then
					drawDebugLine(self.cp.curTarget.x, self.cp.curTarget.y or 0, self.cp.curTarget.z, 1, 0, 1, tp.x, tp.y or 0, tp.z, 1, 0, 1); 
				else
					local pp = self.cp.nextTargets[i-1];
					drawDebugLine(pp.x, pp.y or 0, pp.z, 1, 0, 1, tp.x, tp.y or 0, tp.z, 1, 0, 1); 
				end;
			end;
		end;
	end
end

-- GET ASTAR PATH TO COMBINE
function courseplay:calculateAstarPathToCoords(vehicle, targetX, targetZ)
	courseplay:debug(('%s: calculateAstarPathToCoords(..., targetX=%.2f, targetZ=%.2f)'):format(nameNum(vehicle), targetX, targetZ), 4);
	local tileSize = 5; -- meters
	vehicle.cp.calculatedCourseToCombine = true;
	
	-- check if there is fruit between me and the target, if not then return false in order to avoid the calculating
	local node = vehicle.cp.DirectionNode;
	local x, y, z = getWorldTranslation(node);
	-- local x, y, z = localToWorld(node, 0, 0, tileSize); --make sure first target is in front of us

	local lineIsField = courseplay:isLineField(node, nil, nil, targetX, targetZ);
	-- local hasFruit, density, fruitType, fruitName = courseplay:hasLineFruit(nil, x, z, targetX, targetZ);
	local hasFruit, density, fruitType, fruitName = courseplay:hasLineFruit(node, nil, nil, targetX, targetZ);
	if lineIsField and not hasFruit then
		courseplay:debug('\tno fruit between tractor and target -> return false', 4);
		return false;
	end;
	courseplay:debug(string.format('\tfruit density between tractor and target = %s -> continue calculation', tostring(density)), 4);

	-- check fruit: tipper
	if vehicle.cp.workToolAttached then
		for i,tipper in pairs(vehicle.cp.workTools) do
			if tipper.getCurrentFruitType and tipper.fillLevel > 0 then
				local tipperFruitType = tipper:getCurrentFruitType();
				courseplay:debug(string.format('%s: workTools[%d]: fillType=%d (%s), getCurrentFruitType()=%s (%s)', nameNum(vehicle), i, tipper.currentFillType, tostring(Fillable.fillTypeIntToName[tipper.currentFillType]), tostring(tipperFruitType), tostring(FruitUtil.fruitIndexToDesc[tipperFruitType].name)), 4);
				if tipperFruitType and tipperFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
					fruitType = tipperFruitType;
					courseplay:debug(string.format('\tset pathFinding fruitType as workTools[%d]\'s fruitType', i), 4);
					break;
				end;
			end;
		end;
	end;
	if fruitType == nil and fieldFruitType ~= nil then
		fruitType = fieldFruitType;
		courseplay:debug(string.format('%s: tipper fruitType=nil, fieldFruitType=%d (%s) -> set astar fruitType as fieldFruitType', nameNum(vehicle), fieldFruitType, FruitUtil.fruitIndexToDesc[fieldFruitType].name), 4);
	elseif fruitType == nil and fieldFruitType == nil then
		courseplay:debug(string.format('%s: tipper fruitType=nil, fieldFruitType = nil -> return false', nameNum(vehicle)), 4);
		return false;
	end;


	local targetPoints = courseplay:calcMoves(z, x, targetZ, targetX, fruitType);
	if targetPoints ~= nil then
		vehicle.cp.nextTargets = {};
		local numPoints = #targetPoints;
		local firstPoint = ceil(vehicle.cp.turnRadius / 5);
		courseplay:debug(string.format('numPoints=%d, first point = ceil(turnRadius [%.1f] / 5) = %d', numPoints, vehicle.cp.turnRadius, firstPoint), 4);
		if numPoints < firstPoint then
			return false;
		end;
		-- for i, cp in pairs(targetPoints) do
		for i=firstPoint, numPoints do
			local cp = targetPoints[i];
			local insert = true;

			--[[clean path (only keep corner points)
			if i > firstPoint and i < numPoints then
				local pp = targetPoints[i-1];
				local np = targetPoints[i+1];
				if cp.y == pp.y and cp.y == np.y then
					courseplay:debug(string.format('\t%d: [x] cp.y==pp.y==np.y = %d, [z] cp.x = %d -> insert=false', i, cp.y, cp.x), 4);
					insert = false;
				elseif cp.x == pp.x and cp.x == np.x then
					courseplay:debug(string.format('\t%d: [x] cp.y = %d, [z] cp.x==pp.x==np.x = %d -> insert=false', i, cp.y, cp.x), 4);
					insert = false;
				end;
			end;
			--]]

			if insert then
				courseplay:debug(string.format('%d: [x] cp.y = %d, [z] cp.x = %d, insert=true', i, cp.y, cp.x), 4);
				table.insert(vehicle.cp.nextTargets, { x = cp.y, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cp.y, 1, cp.x) + 3, z = cp.x });
			end;
		end;
		courseplay:setCurrentTargetFromList(vehicle, 1);
		courseplay:setModeState(vehicle, 5);
		return true;
	end;

	return false;
end;

function courseplay:calculateCombineOffset(self, combine)
	local curFile = "mode2.lua";
	local offs = self.cp.combineOffset
	local offsPos = abs(self.cp.combineOffset)
	
	local prnX,prnY,prnZ, prnwX,prnwY,prnwZ, combineToPrnX,combineToPrnY,combineToPrnZ = 0,0,0, 0,0,0, 0,0,0;
	if combine.pipeRaycastNode ~= nil then
		prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.cp.DirectionNode or combine.rootNode, prnwX, prnwY, prnwZ)

		if combineToPrnX >= 0 then
			combine.cp.pipeSide = 1; --left
		else
			combine.cp.pipeSide = -1; --right
		end;
	end;

	--special tools, special cases
	local specialOffset = courseplay:getSpecialCombineOffset(combine);
	if self.cp.combineOffsetAutoMode and specialOffset then
		offs = specialOffset;
	
	--Sugarbeet Loaders (e.g. Ropa Euro Maus, Holmer Terra Felis) --TODO (Jakob): theoretically not needed, as it's being dealt with in getSpecialCombineOffset()
	elseif self.cp.combineOffsetAutoMode and combine.cp.isSugarBeetLoader then
		local utwX,utwY,utwZ = getWorldTranslation(combine.unloadingTrigger.node);
		local combineToUtwX,_,combineToUtwZ = worldToLocal(combine.cp.DirectionNode or combine.rootNode, utwX,utwY,utwZ);
		offs = combineToUtwX;

	--combine // combine_offset is in auto mode, pipe is open
	elseif not combine.cp.isChopper and self.cp.combineOffsetAutoMode and combine.currentPipeState == 2 and combine.pipeRaycastNode ~= nil then --pipe is open
		local raycastNodeParent = getParent(combine.pipeRaycastNode);
		if raycastNodeParent == combine.rootNode then -- pipeRaycastNode is direct child of combine.root
			--safety distance so the trailer doesn't crash into the pipe (sidearm)
			local additionalSafetyDistance = 0;
			if combine.cp.isGrimmeMaxtron620 then
				additionalSafetyDistance = 0.9;
			elseif combine.cp.isGrimmeTectron415 then
				additionalSafetyDistance = -0.5;
			end;

			offs = prnX + additionalSafetyDistance;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, offs), 4)
		elseif getParent(raycastNodeParent) == combine.rootNode then --pipeRaycastNode is direct child of pipe is direct child of combine.root
			local pipeX, pipeY, pipeZ = getTranslation(raycastNodeParent)
			offs = pipeX - prnZ;
			
			if prnZ == 0 or combine.cp.isGrimmeRootster604 then
				offs = pipeX - prnY;
			end;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipe > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, offs), 4)
		elseif combine.pipeRaycastNode ~= nil then --BACKUP pipeRaycastNode isn't direct child of pipe
			offs = combineToPrnX + 0.5;
			--courseplay:debug(string.format("%s(%i): %s @ %s: combineToPrnX // offs = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, offs), 4)
		elseif combine.cp.lmX ~= nil then --user leftMarker
			offs = combine.cp.lmX + 2.5;
		else --if all else fails
			offs = 8;
		end;

	--combine // combine_offset is in manual mode
	elseif not combine.cp.isChopper and not self.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [manual] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, self.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);
	
	--combine // combine_offset is in auto mode
	elseif not combine.cp.isChopper and self.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [auto] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, self.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);

	--chopper // combine_offset is in auto mode
	elseif combine.cp.isChopper and self.cp.combineOffsetAutoMode then
		if combine.cp.lmX ~= nil then
			offs = max(combine.cp.lmX + 2.5, 7);
		else
			offs = 8;
		end;
		courseplay:sideToDrive(self, combine, 10);
			
		if self.sideToDrive ~= nil then
			if self.sideToDrive == "left" then
				offs = abs(offs);
			elseif self.sideToDrive == "right" then
				offs = abs(offs) * -1;
			end;
		end;
	end;
	
	--cornChopper forced side offset
	if combine.cp.isChopper and combine.cp.forcedSide ~= nil then
		if combine.cp.forcedSide == "left" then
			offs = abs(offs);
		elseif combine.cp.forcedSide == "right" then
			offs = abs(offs) * -1;
		end
		--courseplay:debug(string.format("%s(%i): %s @ %s: cp.forcedSide=%s => offs=%f", curFile, debug.getinfo(1).currentline, self.name, combine.name, combine.cp.forcedSide, offs), 4)
	end

	--refresh for display in HUD and other calculations
	self.cp.combineOffset = offs;
end;

function courseplay:calculateVerticalOffset(self, combine)
	local cwX,cwY,cwZ;
	if combine.cp.isSugarBeetLoader then
		cwX, cwY, cwZ = getWorldTranslation(combine.unloadingTrigger.node);
	else
		cwX, cwY, cwZ = getWorldTranslation(combine.pipeRaycastNode);
	end;
	
	local _, _, prnToCombineZ = worldToLocal(combine.cp.DirectionNode or combine.rootNode, cwX, cwY, cwZ);
	
	return prnToCombineZ;
end;

function courseplay:getTargetUnloadingCoords(vehicle, combine, trailerOffset, prnToCombineZ)
	local sourceRootNode = combine.cp.DirectionNode or combine.rootNode;

	if combine.cp.isChopper then
		prnToCombineZ = 0;

		-- check for chopper dolly trailer ('Häcksel-Dolly')
		if combine.attachedImplements ~= nil and combine.haeckseldolly then
			for k, i in pairs(combine.attachedImplements) do
				local implement = i.object;
				if implement.haeckseldolly == true then
					sourceRootNode = implement.rootNode;
				end;
			end;
		end;
	end;

	local ttX, _, ttZ = localToWorld(sourceRootNode, vehicle.cp.combineOffset, 0, trailerOffset + prnToCombineZ);

	return ttX, ttZ;
end;

-- MODE STATE FUNCTIONS
function courseplay:setModeState(vehicle, state, debugLevel)
	debugLevel = debugLevel or 2;
	if vehicle.cp.modeState ~= state then
		-- courseplay:onModeStateChange(vehicle, vehicle.cp.modeState, state);
		-- print(('%s: modeState=%d -> set modeState to %d\n\t%s'):format(nameNum(vehicle), vehicle.cp.modeState, state, courseplay.utils:getFnCallPath(debugLevel))); -- DEBUG140301
		
		vehicle.cp.modeState = state;
	end;
end;

function courseplay:setMode2NextState(vehicle, nextState)
	if nextState == nil then return; end;

	if vehicle.cp.mode2nextState ~= nextState then
		vehicle.cp.mode2nextState = nextState;
	end;
end;

function courseplay:switchToNextMode2State(vehicle)
	if vehicle.cp.mode2nextState == nil then return; end;

	courseplay:setModeState(vehicle, vehicle.cp.mode2nextState, 3);
end;

function courseplay:onModeStateChange(vehicle, oldState, newState)
end;