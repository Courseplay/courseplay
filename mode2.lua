local curFile = 'mode2.lua';
local abs, ceil, max, min = math.abs, math.ceil, math.max, math.min;
local _;

--[[ MODE 2 STATES
 0: default, when not active
 1: wait for work at start point
 2: drive to combine
 3: drive to pipe / unload
 4: drive to the rear of the combine
 5: follow target points
 6: follow tractor
 7: wait for pipe
 9: wait till combine is gone outa my way
81: all trailers are full, tractor turns away from the combine
10: switch side
--]]
--
local STATE_DEFAULT = 0
local STATE_WAIT_AT_START = 1
local STATE_DRIVE_TO_COMBINE = 2
local STATE_DRIVE_TO_PIPE = 3 
local STATE_DRIVE_TO_REAR = 4 
local STATE_FOLLOW_TARGET_WPS = 5 
local STATE_FOLLOW_TRACTOR = 6 
local STATE_WAIT_FOR_PIPE = 7 
local STATE_WAIT_FOR_COMBINE_TO_GET_OUT_OF_WAY = 9 
local STATE_ALL_TRAILERS_FULL = 81 
local STATE_SWITCH_SIDE = 10 

function courseplay:handle_mode2(vehicle, dt)
	local frontTractor;

	-- STATE 0 (default, when not active)
	if vehicle.cp.modeState == STATE_DEFAULT then
		courseplay:setModeState(vehicle, STATE_WAIT_AT_START);
	end


	-- STATE 1 (wait for work at start point)
	if vehicle.cp.modeState == STATE_WAIT_AT_START and vehicle.cp.activeCombine ~= nil then
		courseplay:releaseCombineStop(vehicle,vehicle.cp.activeCombine)
		courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine)
	end

	-- support multiple tippers
	if vehicle.cp.currentTrailerToFill == nil then
		vehicle.cp.currentTrailerToFill = 1
	end

	local currentTipper = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill]

	if currentTipper == nil then
		vehicle.cp.tooIsDirty = true
		return false
	end

	-- STATE 10 (switch side)
	if vehicle.cp.activeCombine ~= nil and (vehicle.cp.modeState == STATE_SWITCH_SIDE or vehicle.cp.activeCombine.turnAP ~= nil and vehicle.cp.activeCombine.turnAP == true) then
		local node = vehicle.cp.activeCombine.cp.DirectionNode or vehicle.cp.activeCombine.rootNode;
		if vehicle.cp.combineOffset > 0 then
			vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(node, 25, 0, 0)
			vehicle.cp.curTarget.rev = false
		else
			vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(node, -25, 0, 0)
			vehicle.cp.curTarget.rev = false
		end
		courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
		courseplay:setMode2NextState(vehicle, STATE_DRIVE_TO_COMBINE);
	end
	
	-- Trailers full?
	if currentTipper.cp.fillLevel >= currentTipper.cp.capacity or vehicle.cp.isLoaded then
		if #(vehicle.cp.workTools) > vehicle.cp.currentTrailerToFill and not vehicle.cp.isLoaded then -- TODO (Jakob): use numWorkTools
			-- got more than one trailer, switch to next
			vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1
		else
			-- one trailer and that's full
			vehicle.cp.currentTrailerToFill = nil
			if vehicle.cp.modeState ~= STATE_FOLLOW_TARGET_WPS then
				if vehicle.cp.modeState == STATE_WAIT_FOR_COMBINE_TO_GET_OUT_OF_WAY then
					vehicle.cp.nextTargets ={}
				end
				local targetIsInFront = false
				local cx,cz = vehicle.Waypoints[2].cx, vehicle.Waypoints[2].cz
				local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 0, cz)
				local x,_,z = worldToLocal(vehicle.cp.DirectionNode or vehicle.rootNode, cx, cy, cz)
				local overTakeDistance = 15
				if z > overTakeDistance then
					targetIsInFront = true
				end
				if (vehicle.cp.activeCombine ~= nil and vehicle.cp.activeCombine.cp.isWoodChipper) or targetIsInFront then
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, overTakeDistance)
					vehicle.cp.curTarget.rev = false
				else
					if vehicle.cp.combineOffset > 0 then
						vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, vehicle.cp.turnDiameter+2, 0, -(vehicle.cp.totalLength+2))
						vehicle.cp.curTarget.rev = false
					else
						vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, -vehicle.cp.turnDiameter-2, 0, -(vehicle.cp.totalLength+2))
						vehicle.cp.curTarget.rev = false
					end
				end
				if vehicle.cp.realisticDriving then
          -- generate course to target around fruit when needed but don't end course in turnDiameter distance
          -- before to avoid circling when transitioning to the next mode
					if courseplay:calculateAstarPathToCoords(vehicle,nil,cx,cz, vehicle.cp.turnDiameter ) then
						courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine)
						courseplay:setCurrentTargetFromList(vehicle, 1);
					end	
				end
				courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
				courseplay:setMode2NextState(vehicle, STATE_ALL_TRAILERS_FULL );
			end			
		end
	end
	-- Have enough payload, can now drive back to the silo
	if vehicle.cp.modeState == STATE_WAIT_AT_START and (vehicle.cp.totalFillLevelPercent >= vehicle.cp.driveOnAtFillLevel or vehicle.cp.isLoaded) then
		vehicle.cp.currentTrailerToFill = nil
		if vehicle.cp.realisticDriving then
			vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, 1)
			local cx,cz = vehicle.Waypoints[2].cx, vehicle.Waypoints[2].cz
      -- generate course to target around fruit when needed but don't end course in turnDiameter distance
      -- before to avoid circling when transitioning to the next mode
			if courseplay:calculateAstarPathToCoords(vehicle,nil,cx,cz, vehicle.cp.turnDiameter ) then
				courseplay:setCurrentTargetFromList(vehicle, 1);
				courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
				courseplay:setMode2NextState(vehicle, STATE_ALL_TRAILERS_FULL );
			else
				courseplay:setWaypointIndex(vehicle, 2);
				courseplay:setIsLoaded(vehicle, true);
			end	
		else
			courseplay:setWaypointIndex(vehicle, 2);
			courseplay:setIsLoaded(vehicle, true);
		end

	end
	
	if vehicle.cp.activeCombine ~= nil then
		if not vehicle.cp.activeCombine.cp.isChopper and courseplay:isSpecialChopper(vehicle.cp.activeCombine)then -- attached wood chipper will not be recognised as chopper before
			vehicle.cp.activeCombine.cp.isChopper = true
		end 
		if vehicle.cp.positionWithCombine == 1 then
			-- is there a trailer to fill, or at least a waypoint to go to?
			if vehicle.cp.currentTrailerToFill or vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS then
				if vehicle.cp.modeState == STATE_FOLLOW_TRACTOR then
					courseplay:setModeState(vehicle, STATE_DRIVE_TO_COMBINE);
				end
				courseplay:unload_combine(vehicle, dt)
			end
		else
			-- follow tractor in front of me
			frontTractor = vehicle.cp.activeCombine.courseplayers[vehicle.cp.positionWithCombine - 1]
			courseplay:debug(string.format('%s: activeCombine ~= nil, my position=%d, frontTractor (positionWithCombine %d) = %q', nameNum(vehicle), vehicle.cp.positionWithCombine, vehicle.cp.positionWithCombine - 1, nameNum(frontTractor)), 4);
			--	courseplay:follow_tractor(vehicle, dt, tractor)
			if vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS and vehicle.cp.mode2nextState == STATE_FOLLOW_TRACTOR then
				if #vehicle.cp.nextTargets == 0 then
					courseplay:setModeState(vehicle, STATE_FOLLOW_TRACTOR);
				end
			else
				courseplay:setModeState(vehicle, STATE_FOLLOW_TRACTOR);
			end
			courseplay:unload_combine(vehicle, dt)
		end
	else -- NO active combine
		-- fake a last combine if we need to
		if vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS and vehicle.cp.nextTargets ~= nil and vehicle.cp.lastActiveCombine == nil and vehicle.cp.mode2nextState and vehicle.cp.mode2nextState == STATE_ALL_TRAILERS_FULL then 
		  -- this can happen when we turn on combi mode with the trailer full before the tractor ever had a combine assigned
		  -- let's see if there's a combine around
			if vehicle.cp.reachableCombines and #vehicle.cp.reachableCombines > 0 then
				-- fake a last combine
				courseplay:debug( "Trailer full, picked a reachable combine to be able to call unload_combine()", 4 )
				vehicle.cp.lastActiveCombine = vehicle.cp.reachableCombines[ 1 ]
			end
		end
		
		if vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS and vehicle.cp.nextTargets ~= nil and vehicle.cp.lastActiveCombine then
			courseplay:unload_combine(vehicle, dt)
		else
			-- STOP!!
			courseplay:checkSaveFuel(vehicle,false)
			
			AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, 0, 0, 28, false, moveForwards, 0, 1)
			courseplay:resetSlippingTimers(vehicle)
			-- We are loaded and have no lastActiveCombine Aviable to us 
			if vehicle.cp.isLoaded and vehicle.cp.lastActiveCombine == nil then
				courseplay:setWaypointIndex(vehicle, 2); 
				-- courseplay:setModeState(vehicle, 99);
				return false
			 end
			-- are there any combines out there that need my help?
			if CpManager.realTime5SecsTimerThrough then
				if vehicle.cp.lastActiveCombine ~= nil then
					local distance = courseplay:distanceToObject(vehicle, vehicle.cp.lastActiveCombine)
					if distance > 20 or vehicle.cp.totalFillLevelPercent == 100 then
						vehicle.cp.lastActiveCombine = nil
						courseplay:debug(string.format("%s (%s): last combine = nil", nameNum(vehicle), tostring(vehicle.id)), 4);
					else
						courseplay:debug(string.format("%s (%s): last combine is just %.0fm away, so wait", nameNum(vehicle), tostring(vehicle.id), distance), 4);
					end
				end
				if vehicle.cp.lastActiveCombine == nil then -- it's important to call this function in the same loop like nilling  vehicle.cp.lastActiveCombine
					courseplay:updateReachableCombines(vehicle)
				end
			end
			--is any of the reachable combines full?
			if vehicle.cp.reachableCombines ~= nil then
				if #vehicle.cp.reachableCombines > 0 then
					-- choose the combine that needs me the most
					if vehicle.cp.bestCombine ~= nil and vehicle.cp.activeCombine == nil then
						courseplay:debug(string.format("%s (%s): request check-in @ %s", nameNum(vehicle), tostring(vehicle.id), tostring(vehicle.cp.combineID)), 4);
						if courseplay:registerAtCombine(vehicle, vehicle.cp.bestCombine) then
							courseplay:setModeState(vehicle, STATE_DRIVE_TO_COMBINE);
						end
					else
						courseplay:setInfoText(vehicle,"COURSEPLAY_WAITING_FOR_FILL_LEVEL")
					end


					local highest_fill_level = 0;
					local num_courseplayers = 0; --TODO: = fewest courseplayers ?
					local distance = 0;

					vehicle.cp.bestCombine = nil;
					vehicle.cp.combineID = 0;
					vehicle.cp.distanceToCombine = math.huge;

					-- chose the combine who needs me the most
					for k, combine in pairs(vehicle.cp.reachableCombines) do
						courseplay:setOwnFillLevelsAndCapacities(combine)
						local fillLevel, capacity = combine.cp.fillLevel, combine.cp.capacity
						if combine.acParameters ~= nil and combine.acParameters.enabled and combine.isHired and fillLevel >= 0.99*capacity and not combine.cp.isDriving then --AC stops at 99% fillLevel so we have to set this as full
							combine.cp.wantsCourseplayer = true
						end
						if (fillLevel >= (capacity * vehicle.cp.followAtFillLevel / 100)) or capacity == 0 or combine.cp.wantsCourseplayer then
							if capacity == 0 then
								if combine.courseplayers == nil then
									vehicle.cp.bestCombine = combine
								else
									local numCombineCourseplayers = #combine.courseplayers;
									if numCombineCourseplayers <= num_courseplayers or vehicle.cp.bestCombine == nil then
										num_courseplayers = numCombineCourseplayers;
										if numCombineCourseplayers > 0 then
											frontTractor = combine.courseplayers[num_courseplayers];
											local canFollowFrontTractor = frontTractor.cp.totalFillLevelPercent and frontTractor.cp.totalFillLevelPercent >= vehicle.cp.followAtFillLevel;
											courseplay:debug(string.format('%s: frontTractor (pos %d)=%q, canFollowFrontTractor=%s', nameNum(vehicle), numCombineCourseplayers, nameNum(frontTractor), tostring(canFollowFrontTractor)), 4);
											if canFollowFrontTractor then
												vehicle.cp.bestCombine = combine
											end
										else
											vehicle.cp.bestCombine = combine
										end
									end;
								end 

							elseif fillLevel >= highest_fill_level and combine.cp.isCheckedIn == nil then
								highest_fill_level = fillLevel
								vehicle.cp.bestCombine = combine
								distance = courseplay:distanceToObject(vehicle, combine);
								vehicle.cp.distanceToCombine = distance
								vehicle.cp.callCombineFillLevel = vehicle.cp.totalFillLevelPercent
								vehicle.cp.combineID = combine.id
							end
						end
					end

					if vehicle.cp.combineID ~= 0 then
						courseplay:debug(string.format("%s (%s): call combine: %s", nameNum(vehicle), tostring(vehicle.id), tostring(vehicle.cp.combineID)), 4);
					end

				else
					courseplay:setInfoText(vehicle, "COURSEPLAY_NO_COMBINE_IN_REACH");
				end
			end
		end
	end

	-- Four wheel drive
	if vehicle.cp.hasDriveControl and vehicle.cp.driveControl.hasFourWD then
		courseplay:setFourWheelDrive(vehicle);
	end;
end

function courseplay:unload_combine(vehicle, dt)
	local curFile = "mode2.lua"
	local allowedToDrive = true
	local combine = vehicle.cp.activeCombine or vehicle.cp.lastActiveCombine;
	local combineDirNode = combine.cp.DirectionNode or combine.rootNode;
	local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode)
	local currentX, currentY, currentZ;
	local combineFillLevel, combineIsTurning = nil, false
	local refSpeed;
	local handleTurn = false
	local isHarvester = false
	local xt, yt, zt;
	local dod;
	local currentTipper = {};
	local speedDebugLine;
	-- Calculate Trailer Offset

	if vehicle.cp.currentTrailerToFill ~= nil then
		currentTipper = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill]
		if  not currentTipper.cp.realUnloadOrFillNode then
			currentTipper.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(currentTipper);
		end;
		xt, yt, zt = worldToLocal(currentTipper.cp.realUnloadOrFillNode, x, y, z)
	else
		--courseplay:debug(nameNum(vehicle) .. ": no cp.currentTrailerToFillSet", 4);
		xt, yt, zt = worldToLocal(vehicle.cp.workTools[1].rootNode, x, y, z)
	end

	-- support for tippers like hw80
	if zt < 0 then
		zt = zt * -1
	end

	local trailerOffset = zt + vehicle.cp.tipperOffset
	local totalLength = vehicle.cp.totalLength+2
	local turnDiameter = vehicle.cp.turnDiameter+2
	
	if vehicle.cp.chopperIsTurning == nil then
		vehicle.cp.chopperIsTurning = false
	end
	
	courseplay:setOwnFillLevelsAndCapacities(combine)
	
	local fillLevel, capacity = combine.cp.fillLevel, combine.cp.capacity;
	if capacity > 0 then
		combineFillLevel = fillLevel * 100 / capacity
	else -- combine is a chopper / has no tank
		combineFillLevel = 99;
	end
  -- TODO: confusing as hell, in the next sections we sometimes use tractor, sometimes combine
	local tractor = combine
	if courseplay:isAttachedCombine(combine) then
    -- this is the tractor pulling a harvester
		tractor = combine.attacherVehicle

		-- Really make sure the combine's attacherVehicle still exists - see issue #443
		if tractor == nil then
			courseplay:removeActiveCombineFromTractor(vehicle);
			return;
		end;
	end;
	local reverser = 1
	if tractor.isReverseDriving then
		reverser = -1
	end
	local combineIsStopped = tractor.lastSpeedReal*3600 < 0.5
	
	-- auto combine
	local AutoCombineIsTurning = false
	local combineIsAutoCombine = false
	local autoCombineExtraMoveBack = 0
	local autoCombineCircleMode = false
	--print(('tractor.acParameters = %s tractor.acParameters.enabled = %s tractor.acTurnStage = %s tractor.isHired = %s'):format(tostring(tractor.acParameters),tostring(tractor.acParameters.enabled),tostring(tractor.acTurnStage),tostring(tractor.isHired)))
	if tractor.acParameters ~= nil and tractor.acParameters.enabled and tractor.isHired and not tractor.cp.isDriving then
		combineIsAutoCombine = true
		autoCombineCircleMode = not tractor.acParameters.upNDown
		if tractor.cp.turnStage == nil then
			tractor.cp.turnStage = 0
		end
		if autoCombineCircleMode and tractor.cp.isChopper then
			tractor.acTurnMode = '7'
		end;
		-- if tractor.acTurnStage ~= 0 then
		if tractor.acTurnStage > 0 then
			tractor.cp.turnStage = 2
			autoCombineExtraMoveBack = vehicle.cp.turnDiameter*2
			AutoCombineIsTurning = true
			courseplay:debug(string.format('%s: acTurnStage=%d -> cp.turnState=2, AutoCombineIsTurning=true', nameNum(tractor), tractor.acTurnStage), 4); --TODO: 140308 AutoTractor
		else
			tractor.cp.turnStage = 0
		end
	end
	
	-- is combine turning ?
	if not vehicle.cp.choppersTurnHasEnded and combine.cp.isChopper and combine.turnStage == 3 and combine.waitingForTrailerToUnload then
		vehicle.cp.choppersTurnHasEnded = true
	elseif combine.turnStage ~= 3 then
		vehicle.cp.choppersTurnHasEnded = false
	end
	local aiTurn = false	
	for index,strategy in pairs(tractor.driveStrategies) do
		if strategy.activeTurnStrategy ~= nil then
			combine.cp.turnStrategyIndex = index
			strategy.activeTurnStrategy.didNotMoveTimer = strategy.activeTurnStrategy.didNotMoveTimeout;
			aiTurn = true
		end
	end	
	
	--local aiTurn = combine.isAIThreshing and combine.turnStage > 0 and not (combine.turnStage == 3 and vehicle.cp.choppersTurnHasEnded)
	if tractor ~= nil and (aiTurn or tractor.cp.turnStage > 0) then
		--courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_IS_TURNING");
		combineIsTurning = true
		-- print(('%s: cp.turnStage=%d -> combineIsTurning=true'):format(nameNum(tractor), tractor.cp.turnStage));
	end

	vehicle.cp.mode2DebugTurning = combineIsTurning
	
	if vehicle.cp.modeState == STATE_DRIVE_TO_COMBINE or vehicle.cp.modeState == STATE_DRIVE_TO_PIPE or vehicle.cp.modeState == STATE_DRIVE_TO_REAR then
		if combine == nil then
			courseplay:setInfoText(vehicle, "combine == nil, this should never happen");
			allowedToDrive = false
		end
	end

	local offset_to_chopper = vehicle.cp.combineOffset
	if combineIsTurning then
		offset_to_chopper = vehicle.cp.combineOffset * 1.6 --1,3
	end
	local x1, y1, z1 = worldToLocal(combineDirNode, x, y, z)
	
	x1,z1 = x1*reverser,z1*reverser;
	
	local distance = Utils.vector2Length(x1, z1)
	local safetyDistance = courseplay:getSafetyDistanceFromCombine( combine )
	
	-- STATE 2 (drive to combine)
	if vehicle.cp.modeState == STATE_DRIVE_TO_COMBINE then
		
		refSpeed = vehicle.cp.speeds.field
		speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		courseplay:setInfoText(vehicle, "COURSEPLAY_DRIVE_BEHIND_COMBINE");

    -- calculate a world position (currentX/Y/Z) and a vector (lx/lz) to a point near the combine (which is sometimes called 'tractor')
    -- here, 'tractor' is the combine, x, y, z is the tractor unloading the combine, z1, y1, z1 is the tractor's local coordinates from 
    -- the combine
		local x1, y1, z1 = worldToLocal(tractor.cp.DirectionNode or tractor.rootNode, x, y, z)
		x1,z1 = x1*reverser,z1*reverser;

    if not combine.cp.isChopper then
      cx_behind, cy_behind, cz_behind = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, vehicle.cp.combineOffset*reverser, 0, -(turnDiameter + safetyDistance)*reverser)
    else
      cx_behind, cy_behind, cz_behind = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, 0, 0, -(turnDiameter + safetyDistance)*reverser)
    end
		
		if z1 > -(turnDiameter + safetyDistance) then 
      -- tractor in front of combine, drive to a position where we can safely transfer to STATE_DRIVE_TO_REAR mode

      -- tractor in front of combine, drive to a position where we can safely transfer to STATE_DRIVE_TO_REAR mode
			-- left side of combine, 30 meters back, 20 to the left
			local cx_left, cy_left, cz_left = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, 20*reverser, 0, -30*reverser)
			-- righ side of combine, 30 meters back, 20 to the right
			local cx_right, cy_right, cz_right = localToWorld(tractor.cp.DirectionNode or tractor.rootNode, -20*reverser, 0, -30*reverser)

			local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(vehicle.cp.DirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)

      -- prefer the one closest to the combine
			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end

		else
			-- tractor behind combine, drive to a position behind the combine
		  currentX, currentY, currentZ = cx_behind, cy_behind, cz_behind
		end

    -- at this point, currentX/Y/Z is a world position near the combine
		
    -- with no path finding, get vector to currentX/currentZ
		local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, currentX, currentY, currentZ)
		lx,lz = lx*reverser,lz*reverser
		
		dod = Utils.vector2Length(lx, lz)
   
		-- PATHFINDING / REALISTIC DRIVING -
    -- if it is enabled and we are not too close to the combine, we abort STATE_DRIVE_TO_COMBINE mode and 
    -- switch to follow course mode to avoid fruit instead of driving directly 
    -- to currentX/currentZ
		if vehicle.cp.realisticDriving and dod > 20 then 
			-- if there's fruit between me and the combine, calculate a path around it to a point 
      -- behind the combine.
			if courseplay:calculateAstarPathToCoords(vehicle, nil, cx_behind, cz_behind ) then
			  -- there's fruit and a path could be calculated, switch to waypoint mode
        courseplay:debug( string.format( "Combine is %.1f meters away, switching to pathfinding, drive to a point %.1f (%.1f safety distance and %.1f turn diameter) behind to combine",
                                       dod, safetyDistance + turnDiameter, safetyDistance, turnDiameter ), 4 )
				courseplay:setCurrentTargetFromList(vehicle, 1);
				courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
				courseplay:setMode2NextState(vehicle, STATE_DRIVE_TO_COMBINE); -- modeState when waypoint is reached
				vehicle.cp.shortestDistToWp = nil;
			end;
		end;
		
	
		-- near point
		if dod < 3 then -- change to vehicle.cp.modeState 4 == drive behind combine or cornChopper
			if combine.cp.isChopper and (not vehicle.cp.chopperIsTurning or combineIsAutoCombine) then -- decide on which side to drive based on ai-combine
				courseplay:sideToDrive(vehicle, combine, 10)
				if vehicle.sideToDrive == "right" then
					vehicle.cp.combineOffset = abs(vehicle.cp.combineOffset) * -1;
				else 
					vehicle.cp.combineOffset = abs(vehicle.cp.combineOffset);
				end
			end
			courseplay:setModeState(vehicle, STATE_DRIVE_TO_REAR);
		end;
		-- END STATE 2

	-- STATE 4 (drive to rear of combine)
	elseif vehicle.cp.modeState == STATE_DRIVE_TO_REAR then
		if combine.cp.offset == nil or vehicle.cp.combineOffset == 0 then
			--print("offset not saved - calculate")
			courseplay:calculateCombineOffset(vehicle, combine);
		elseif not combine.cp.isChopper and not combine.cp.isSugarBeetLoader and vehicle.cp.combineOffsetAutoMode and vehicle.cp.combineOffset ~= combine.cp.offset then
			--print("set saved offset")
			vehicle.cp.combineOffset = combine.cp.offset			
		end
		courseplay:setInfoText(vehicle, "COURSEPLAY_DRIVE_TO_COMBINE"); 
		--courseplay:addToCombinesIgnoreList(vehicle, combine)
		refSpeed = vehicle.cp.speeds.field
		speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		local tX, tY, tZ

		if combine.cp.isSugarBeetLoader then
			local prnToCombineZ = courseplay:calculateVerticalOffset(vehicle, combine);
	
			tX, tY, tZ = localToWorld(combineDirNode, vehicle.cp.combineOffset, 0, prnToCombineZ -5*reverser);
		else			
			tX, tY, tZ = localToWorld(combineDirNode, vehicle.cp.combineOffset, 0, -5*reverser);
		end

		if combine.attachedImplements ~= nil then
			for k, i in pairs(combine.attachedImplements) do
				local implement = i.object;
				if implement.haeckseldolly == true then
					tX, tY, tZ = localToWorld(implement.rootNode, vehicle.cp.combineOffset, 0, trailerOffset)
				end
			end
		end

		currentX, currentZ = tX, tZ

		local lx, ly, lz

		lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, tX, y, tZ)

		if currentX ~= nil and currentZ ~= nil then
			local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, currentX, y, currentZ)
			dod = Utils.vector2Length(lx, lz)
		else
			dod = Utils.vector2Length(lx, lz)
		end


		if dod < 2 then -- dod < 2
			allowedToDrive = false
			courseplay:setModeState(vehicle, STATE_DRIVE_TO_PIPE); -- change to modeState 3 == drive to unload pipe
			vehicle.cp.chopperIsTurning = false
		end

		if dod > 50 then
			courseplay:setModeState(vehicle, STATE_DRIVE_TO_COMBINE);
		end
		-- END STATE 4


	-- STATE 3 (drive to unload pipe)
	elseif vehicle.cp.modeState == STATE_DRIVE_TO_PIPE then
		--courseplay:addToCombinesIgnoreList(vehicle, combine)
		refSpeed = vehicle.cp.speeds.field
		speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		
		if vehicle.cp.nextTargets ~= nil then
			vehicle.cp.nextTargets = {}
		end

		if (not combine.cp.isChopper or combine.haeckseldolly) and (combineFillLevel < 1 or vehicle.cp.forceNewTargets) then --combine empty set waypoints on the field !
			if combine.cp.offset == nil then
				--print("saving offset")
				combine.cp.offset = vehicle.cp.combineOffset;
			end			
			local sideMultiplier = 0;
			if tractor.cp.workWidth == nil or tractor.cp.workWidth == 0 or not tractor.cp.isDriving then
				courseplay:calculateWorkWidth(tractor, true)
			end 
			local workWidth = tractor.cp.workWidth
			local combineOffset = vehicle.cp.combineOffset
			local offset = abs(combineOffset)
			local fruitSide = "404notFound"
			local nodeSet = false
			if workWidth < offset then
				local diff = max (1.5,workWidth/2)
				if  combine.cp.isHarvesterAttachable then
					diff = 5
				end
				fruitSide = courseplay:sideToDrive(vehicle, combine, 0);
				if (fruitSide == "right" and combineOffset > 0) or (fruitSide == "left" and combineOffset < 0) then
					offset = offset-diff
				else
					offset = offset+diff
				end
			end	
			courseplay:debug(string.format("%s: combine.workWidth: %.2f,vehicle.cp.combineOffset: %.2f, calculated offset: %.2f, fruitSide: %s  ",nameNum(vehicle),workWidth,combineOffset,offset,fruitSide),4)	
			if combineOffset > 0 then 
				sideMultiplier = -1;
			else
				sideMultiplier = 1;				
			end
			if combineIsTurning or vehicle.cp.forceNewTargets then
				vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(currentTipper.rootNode, -sideMultiplier*turnDiameter, 0, trailerOffset);
				vehicle.cp.curTarget.rev = false
				courseplay:debug(string.format("%s: combine is empty and turning",nameNum(vehicle)),4)
				if combineIsAutoCombine then

					local index = combine.aiveChain.trace.traceIndex+1
					if index > #combine.aiveChain.trace.trace then
						index = 1
					end
					local tipperX,tipperY,tipperZ = getWorldTranslation(currentTipper.rootNode)
					local dirX,dirZ = combine.aiveChain.trace.trace[index].dx,combine.aiveChain.trace.trace[index].dz

					vehicle.cp.cpTurnBaseNode = createTransformGroup('cpTurnBaseNode');
					link(getRootNode(), vehicle.cp.cpTurnBaseNode);
					setTranslation(vehicle.cp.cpTurnBaseNode, tipperX,tipperY,tipperZ);
					setRotation(vehicle.cp.cpTurnBaseNode, 0, math.atan2(dirX, dirZ), 0)
					nodeSet = true
					courseplay:debug(string.format("%s: combineIsAutoCombine- create vehicle.cp.cpTurnBaseNode (%s; %s)",nameNum(vehicle),tostring(vehicle.cp.cpTurnBaseNode), tostring(getName(vehicle.cp.cpTurnBaseNode))),4)
				end
				-- turn around and drive closer to the next row
				courseplay:debug(string.format("%s: addNewTargetVector: currentTipper: %s, vehicle.cp.cpTurnBaseNode: %s",nameNum(vehicle),tostring(currentTipper),tostring(vehicle.cp.cpTurnBaseNode)),4)				
				-- This was reverted back. sideMultiplier*offset is measured from the tipper starting at the currentTipper or cpTurnBaseNode if not nil.
				-- So this vaule adds enough Y to the target vector to align the tipper with the center of the last lane cleared by the havester.
				-- (-totalLength*4)+trailerOffset Adds vertical length after turning to straigten out the trailer so it isn't bent Pops64 increase this to 4.5 because small offset vaules may cause the tipper to block the next lane of the havester 
				courseplay:addNewTargetVector(vehicle, sideMultiplier*offset*0.5,  (-totalLength*2)+trailerOffset,currentTipper,vehicle.cp.cpTurnBaseNode);
				courseplay:addNewTargetVector(vehicle, sideMultiplier*offset,  (-totalLength*3)+trailerOffset,currentTipper,vehicle.cp.cpTurnBaseNode);
				courseplay:addNewTargetVector(vehicle, sideMultiplier*offset,  (-totalLength*4.5)+trailerOffset,currentTipper,vehicle.cp.cpTurnBaseNode);
				courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
				if vehicle.cp.forceNewTargets then
					vehicle.cp.forceNewTargets = nil
				end
			else
				courseplay:debug(string.format("%s: combine is empty ",nameNum(vehicle)),4)
				if combine.cp.isHarvesterAttachable then
					courseplay:debug(string.format("%s: combine is isHarvesterAttachable move out of the way",nameNum(vehicle)),4)
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(currentTipper.rootNode, 0 , 0, 5);
					vehicle.cp.curTarget.rev = false
					courseplay:addNewTargetVector(vehicle, sideMultiplier*offset*0.8 ,totalLength + trailerOffset,currentTipper);
				else
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(currentTipper.rootNode, sideMultiplier*offset*0.8 , 0, totalLength + trailerOffset);
					vehicle.cp.curTarget.rev = false
				end
				courseplay:addNewTargetVector(vehicle, sideMultiplier*offset ,(totalLength*3)+trailerOffset,currentTipper);
				courseplay:setModeState(vehicle, STATE_WAIT_FOR_COMBINE_TO_GET_OUT_OF_WAY);				
			end

			if nodeSet then
				unlink(vehicle.cp.cpTurnBaseNode);
				delete(vehicle.cp.cpTurnBaseNode);
				vehicle.cp.cpTurnBaseNode = nil 
			end
			if vehicle.cp.nextTargets ~= nil then
				courseplay:debug(string.format("%s: vehicle.cp.nextTargets: %s ",nameNum(vehicle),tostring(#vehicle.cp.nextTargets)),4)
			else
				courseplay:debug(string.format("%s: vehicle.cp.nextTargets: nil ",nameNum(vehicle)),4)
			end
			
			courseplay:setMode2NextState(vehicle, 1);
		end

		--CALCULATE HORIZONTAL OFFSET (side offset)
		if combine.cp.offset == nil and not combine.cp.isChopper then
			courseplay:calculateCombineOffset(vehicle, combine);
		end
		currentX, currentY, currentZ = localToWorld(combineDirNode, vehicle.cp.combineOffset, 0, trailerOffset + 5)
		
		--CALCULATE VERTICAL OFFSET (tipper offset)
		local prnToCombineZ = courseplay:calculateVerticalOffset(vehicle, combine);
		
		--SET TARGET UNLOADING COORDINATES @ COMBINE
		local ttX, ttZ = courseplay:getTargetUnloadingCoords(vehicle, combine, trailerOffset, prnToCombineZ);
		
		local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, ttX, y, ttZ)
		dod = Utils.vector2Length(lx, lz)
		if dod > 40 or vehicle.cp.chopperIsTurning == true then
			courseplay:setModeState(vehicle, STATE_DRIVE_TO_COMBINE);
		end
		-- combine is not moving and trailer is under pipe
		if lz < 5 and combine.cp.fillLevel > 100 then 
			-- print(string.format("lz: %.4f, prnToCombineZ: %.2f, trailerOffset: %.2f",lz,prnToCombineZ,trailerOffset))
		end
		if not combine.cp.isChopper and combineIsStopped and (lz <= 1 or lz < -0.1 * trailerOffset) then
			courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP"); 
			allowedToDrive = false
		elseif combine.cp.isChopper then
			if (combineIsStopped or courseplay:isSpecialChopper(combine)) and dod == -1 and vehicle.cp.chopperIsTurning == false then
				allowedToDrive = false
				courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");				
			end
			if lz < -2 then
				allowedToDrive = false
				courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");
				-- courseplay:setModeState(vehicle, STATE_DRIVE_TO_COMBINE);
			end
		elseif lz < -1.5 then
				allowedToDrive = false
				courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");
		end
		if vehicle.cp.infoText == nil then
			courseplay:setInfoText(vehicle, "COURSEPLAY_DRIVE_NEXT_TO_COMBINE");
		end
		-- refspeed depends on the distance to the combine
		local combine_speed = tractor.lastSpeed*3600
		if combine.cp.isChopper then
			if lz > 20 then
				refSpeed = vehicle.cp.speeds.field
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			elseif lz > 4 and (combine_speed*3600) > 5 then
				refSpeed = max(combine_speed *1.5,vehicle.cp.speeds.crawl)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			elseif lz > 10 then
				refSpeed = vehicle.cp.speeds.turn
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			elseif lz < -1 then
				refSpeed = max(combine_speed/2,vehicle.cp.speeds.crawl)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				refSpeed = max(combine_speed,vehicle.cp.speeds.crawl)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
			
			if (combineIsTurning and lz < 20) or (combineIsStopped and lz < 5) then
				refSpeed = vehicle.cp.speeds.crawl
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
		else
			if lz > 5 then
				refSpeed = vehicle.cp.speeds.field
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			elseif lz < -0.5 then
				refSpeed = max(combine_speed - vehicle.cp.speeds.crawl,vehicle.cp.speeds.crawl)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			elseif lz > 1 or not combine.overloading.isActive then  
				refSpeed = max(combine_speed + vehicle.cp.speeds.crawl,vehicle.cp.speeds.crawl)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				refSpeed = max(combine_speed,vehicle.cp.speeds.crawl)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
			if (combineIsTurning and lz < 20) or (vehicle.timer < vehicle.cp.driveSlowTimer) or (combineIsStopped and lz < 15) then
				refSpeed = vehicle.cp.speeds.crawl
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
				if combineIsTurning then
					vehicle.cp.driveSlowTimer = vehicle.timer + 2000
				end
			end
		
		end

		--courseplay:debug("combine.sentPipeIsUnloading: "..tostring(combine.sentPipeIsUnloading).." refSpeed:  "..tostring(refSpeed*3600).." combine_speed:  "..tostring(combine_speed*3600), 4)
	--END STATE 3
	
	-- STATE 9 (wait till combine is gone)
	elseif vehicle.cp.modeState == STATE_WAIT_FOR_COMBINE_TO_GET_OUT_OF_WAY then
		local lastIndex = #vehicle.cp.nextTargets
		local tx,ty,tz = vehicle.cp.nextTargets[lastIndex].x,vehicle.cp.nextTargets[lastIndex].y,vehicle.cp.nextTargets[lastIndex].z;
		if vehicle.cp.swayPointDistance == nil then
			_,_,vehicle.cp.swayPointDistance = worldToLocal(vehicle.cp.DirectionNode, tx,ty,tz) 
		end
		local x,y,z = getWorldTranslation(combineDirNode)
		local _,_,combineDistance = worldToLocal(vehicle.cp.DirectionNode, x,y,z)
		local backupDistance = worldToLocal(combineDirNode, tx,ty,tz)
		if combineDistance > vehicle.cp.swayPointDistance + 3 or backupDistance < -5 then
			vehicle.cp.swayPointDistance = nil
			courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
		else
			allowedToDrive = false
			courseplay:setInfoText(vehicle, "COURSEPLAY_WAITING_TILL_WAITING_POSITION_IS_FREE");
		end
		if combineIsTurning then
			vehicle.cp.swayPointDistance = nil
			courseplay:setModeState(vehicle, STATE_DRIVE_TO_PIPE);
			vehicle.cp.forceNewTargets = true
			vehicle.cp.nextTargets = {}
		end	
	end;
	---------------------------------------------------------------------
	local stopAICombine = false
	local cx, cy, cz = getWorldTranslation(combineDirNode)
	local sx, sy, sz = getWorldTranslation(vehicle.cp.DirectionNode)
	distance = courseplay:distance(sx, sz, cx, cz)
	if combineIsTurning and not combine.cp.isChopper and vehicle.cp.modeState > STATE_WAIT_AT_START then
		if combine.cp.fillLevel > combine.cp.capacity*0.9 then
			if combineIsAutoCombine and tractor.acIsCPStopped ~= nil then
				 courseplay:debug(nameNum(tractor) .. ': fillLevel > 90%% -> set acIsCPStopped to true', 4); --TODO: 140308 AutoTractor
				tractor.acIsCPStopped = true
			elseif combine.aiIsStarted  then
				stopAICombine = true
			elseif tractor:getIsCourseplayDriving() then
				combine.cp.waitingForTrailerToUnload = true
			end
		elseif distance < 50 then
			--[[for i=1, #combine.acDirectionBeforeTurn.trace do
				local px,pz = combine.acDirectionBeforeTurn.trace[i].px,combine.acDirectionBeforeTurn.trace[i].pz
				local dirX,dirZ = combine.acDirectionBeforeTurn.trace[i].dx,combine.acDirectionBeforeTurn.trace[i].dz
				drawDebugPoint(px+(-dirX*100),cy+10,pz+(-dirZ*100), 1, 1, 1, 1);
				drawDebugLine(px,cy+3,pz, 1, 0, 1, px+(-dirX*100), cy+10,pz+(-dirZ*100), 1, 0, 1);
			end
			local index = combine.acDirectionBeforeTurn.traceIndex+1
			if index > #combine.acDirectionBeforeTurn.trace then
				index = 1
			end
			local px,pz = combine.acDirectionBeforeTurn.trace[index].px,combine.acDirectionBeforeTurn.trace[index].pz
			local dirX,dirZ = combine.acDirectionBeforeTurn.trace[index].dx,combine.acDirectionBeforeTurn.trace[index].dz
			drawDebugPoint(px+(-dirX*100),cy+10,pz+(-dirZ*100), 1, 1, 1, 1);
			drawDebugLine(px,cy+3,pz, 1, 1, 1, px+(-dirX*100), cy+10,pz+(-dirZ*100), 1, 1, 1);]]
			--courseplay:setCustomTimer(vehicle, 'fieldEdgeTimeOut', 15);
			--courseplay:resetCustomTimer(vehicle, 'fieldEdgeTimeOut');
			if not courseplay:timerIsThrough(vehicle, 'fieldEdgeTimeOut') or vehicle.cp.modeState > STATE_DRIVE_TO_COMBINE then
				if AutoCombineIsTurning and tractor.acIsCPStopped ~= nil then
					 courseplay:debug(nameNum(tractor) .. ': distance < 50 -> set acIsCPStopped to true', 4); --TODO: 140308 AutoTractor
					tractor.acIsCPStopped = true
				elseif combine.aiIsStarted then --and not (combineFillLevel == 0 and combine.currentPipeState ~= 2) then
					stopAICombine = true
					--combine.waitForTurnTime = combine.timer + 100
				elseif tractor:getIsCourseplayDriving() then --and not (combineFillLevel == 0 and combine:getOverloadingTrailerInRangePipeState()==0) then
					combine.cp.waitingForTrailerToUnload = true
				end
			elseif vehicle.cp.fieldEdgeTimeOutSet ~= true then
				--print("set timer")
				courseplay:setCustomTimer(vehicle, 'fieldEdgeTimeOut', 20);
				vehicle.cp.fieldEdgeTimeOutSet = true
				--print("set vehicle.cp.fieldEdgeTimeOutSet")
			else
				allowedToDrive = false;
				if combine.cp.waitingForTrailerToUnload then
					--print("reset combine.cp.waitingForTrailerToUnload")
					combine.cp.waitingForTrailerToUnload = false
				elseif tractor.acIsCPStopped then
					tractor.acIsCPStopped = false
				end
			end
		elseif distance < 100 and vehicle.cp.modeState == STATE_DRIVE_TO_COMBINE then
			allowedToDrive = false;
		end		
	elseif vehicle.cp.fieldEdgeTimeOutSet then
		vehicle.cp.fieldEdgeTimeOutSet = false
		--print("reset vehicle.cp.fieldEdgeTimeOutSet")
	end	
	
	if combine.aiIsStarted and stopAICombine and combine.cruiseControl.speed > 0 then
		combine.cp.lastCruiseControlSpeed = combine.cruiseControl.speed
		combine.cruiseControl.speed = 0
	end
	
	if combineIsTurning and distance < 20 then
		if vehicle.cp.modeState == STATE_DRIVE_TO_PIPE or vehicle.cp.modeState == STATE_DRIVE_TO_REAR then
			if combine.cp.isChopper then
				local fruitSide = courseplay:sideToDrive(vehicle, combine, -10,true);
				local maxDiameter = max(totalLength,turnDiameter)
				local extraAlignLength = courseplay:getDirectionNodeToTurnNodeLength(vehicle)*2+6;	
				--another new chopper turn maneuver by Thomas Gärtner  
				if fruitSide == "left" then -- chopper will turn left

					if vehicle.cp.combineOffset > 0 then -- I'm left of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm left", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
						vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnDiameter);
						vehicle.cp.curTarget.rev = false
						courseplay:addNewTargetVector(vehicle, 2*turnDiameter*-1 ,  turnDiameter);
						vehicle.cp.chopperIsTurning = true
	
					else --i'm right of choppper
						if vehicle.cp.isReversePossible  and not autoCombineCircleMode and combine.cp.forcedSide == nil then
							courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm right. Turning the New Way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
							local maxDiameter = max(20,vehicle.cp.turnDiameter)
							local verticalWaypointShift = courseplay:getWaypointShift(vehicle,tractor)
							tractor.cp.verticalWaypointShift = verticalWaypointShift
							vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0,0,3);
							vehicle.cp.curTarget.rev = false
							vehicle.cp.nextTargets  = courseplay:createTurnAwayCourse(vehicle,-1,maxDiameter,tractor.cp.workWidth)
										
							courseplay:addNewTargetVector(vehicle,tractor.cp.workWidth,-(max(maxDiameter +vehicle.cp.totalLength+extraAlignLength,maxDiameter +vehicle.cp.totalLength -verticalWaypointShift)))
							courseplay:addNewTargetVector(vehicle,tractor.cp.workWidth, 2 +verticalWaypointShift,nil,nil,true);
						else
							courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm right. Turning the Old Way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
							vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, turnDiameter*-1, 0, turnDiameter);
							vehicle.cp.chopperIsTurning = true
						end
					end
					
				else -- chopper will turn right
					if vehicle.cp.combineOffset < 0 then -- I'm right of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm right", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
						vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnDiameter);
						vehicle.cp.curTarget.rev = false
						courseplay:addNewTargetVector(vehicle, 2*turnDiameter,     turnDiameter);
						vehicle.cp.chopperIsTurning = true
					else -- I'm left of chopper
						if vehicle.cp.isReversePossible and not autoCombineCircleMode and combine.cp.forcedSide == nil then
							courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm left. Turning the new way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
							local maxDiameter = max(20,vehicle.cp.turnDiameter)
							local verticalWaypointShift = courseplay:getWaypointShift(vehicle,tractor)
							tractor.cp.verticalWaypointShift = verticalWaypointShift
							vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0,0,3);
							vehicle.cp.curTarget.rev = false
							vehicle.cp.nextTargets  = courseplay:createTurnAwayCourse(vehicle,1,maxDiameter,tractor.cp.workWidth)

							courseplay:addNewTargetVector(vehicle,-tractor.cp.workWidth,-(max(maxDiameter +vehicle.cp.totalLength+extraAlignLength,maxDiameter +vehicle.cp.totalLength-verticalWaypointShift)))
							courseplay:addNewTargetVector(vehicle,-tractor.cp.workWidth, 2 +verticalWaypointShift,nil,nil,true);

						else
							courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm left. Turning the old way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
							vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, turnDiameter, 0, turnDiameter);
							vehicle.cp.chopperIsTurning = true
						end
					end
				end

				if vehicle.cp.combineOffsetAutoMode then
					if vehicle.sideToDrive == "right" then
						vehicle.cp.combineOffset = combine.cp.offset * -1;
					elseif vehicle.sideToDrive == "left" then
						vehicle.cp.combineOffset = combine.cp.offset;
					end;
				else
					if vehicle.sideToDrive == "right" then
						vehicle.cp.combineOffset = abs(vehicle.cp.combineOffset) * -1;
					elseif vehicle.sideToDrive == "left" then
						vehicle.cp.combineOffset = abs(vehicle.cp.combineOffset);
					end;
				end;
				courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
				vehicle.cp.shortestDistToWp = nil
				courseplay:setMode2NextState(vehicle, STATE_WAIT_FOR_PIPE);
			end
		-- elseif vehicle.cp.modeState ~= STATE_FOLLOW_TARGET_WPS and vehicle.cp.modeState ~= 99 and not vehicle.cp.realisticDriving then
		elseif vehicle.cp.modeState ~= STATE_FOLLOW_TARGET_WPS and vehicle.cp.modeState ~= STATE_WAIT_FOR_COMBINE_TO_GET_OUT_OF_WAY and not vehicle.cp.realisticDriving then
			-- just wait until combine has turned
			allowedToDrive = false
			courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");
		end
	end


	-- STATE 7
	if vehicle.cp.modeState == STATE_WAIT_FOR_PIPE then
		if not combineIsTurning then
			--courseplay:setModeState(vehicle, STATE_DRIVE_TO_COMBINE);
			courseplay:setModeState(vehicle, STATE_DRIVE_TO_PIPE);
		else
			courseplay:setInfoText(vehicle, "COURSEPLAY_WAITING_FOR_COMBINE_TURNED");
		end
		refSpeed = vehicle.cp.speeds.turn
		speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end
  -- END STATE 7


	--[[ TODO: MODESTATE 99 - WTF?
	-- STATE 99 (turn maneuver)
	if vehicle.cp.modeState == 99 and vehicle.cp.curTarget.x ~= nil and vehicle.cp.curTarget.z ~= nil then
		--courseplay:removeFromCombinesIgnoreList(vehicle, combine)
		courseplay:setInfoText(vehicle, string.format("COURSEPLAY_TURNING_TO_COORDS;%d;%d",vehicle.cp.curTarget.x,vehicle.cp.curTarget.z));
		allowedToDrive = false
		local mx, mz = vehicle.cp.curTarget.x, vehicle.cp.curTarget.z
		local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, mx, y, mz)
		refSpeed = vehicle.cp.speeds.field --vehicle.cp.speeds.turn
		speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		if lz > 0 and abs(lx) < lz * 0.5 then -- lz * 0.5    --2
			if vehicle.cp.mode2nextState == 4 and not combineIsTurning then
				vehicle.cp.curTarget.x = nil
				vehicle.cp.curTarget.z = nil
				courseplay:switchToNextMode2State(vehicle);
				courseplay:setMode2NextState(vehicle, STATE_DEFAULT);
			end

			if vehicle.cp.mode2nextState == 1 or vehicle.cp.mode2nextState == 2 then
				-- is there another waypoint to go to?
				if #(vehicle.cp.nextTargets) > 0 then
					courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
					vehicle.cp.shortestDistToWp = nil
					courseplay:setCurrentTargetFromList(vehicle, 1);
				else
					courseplay:switchToNextMode2State(vehicle);
					courseplay:setMode2NextState(vehicle, STATE_DEFAULT);
				end
			end
		else
			currentX, currentY, currentZ = localToWorld(vehicle.cp.DirectionNode, vehicle.turn_factor, 0, 5)
			allowedToDrive = true
		end
	end
	]]



	-- STATE 5 (follow target points)
	if vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS and vehicle.cp.curTarget.x ~= nil and vehicle.cp.curTarget.z ~= nil then
		courseplay:setInfoText(vehicle, string.format("COURSEPLAY_DRIVE_TO_WAYPOINT;%d;%d",vehicle.cp.curTarget.x,vehicle.cp.curTarget.z));
		currentX = vehicle.cp.curTarget.x
		currentY = vehicle.cp.curTarget.y
		currentZ = vehicle.cp.curTarget.z
		refSpeed = vehicle.cp.speeds.field
		speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		local distance_to_wp = courseplay:distanceToPoint(vehicle, currentX, currentY, currentZ);
		if vehicle.cp.curTarget.rev then
			local nodeX,_,nodeZ =0,0,0
			nodeX,_,nodeZ = getWorldTranslation(vehicle.cp.toolsRealTurningNode or vehicle.cp.DirectionNode)
			distance_to_wp = courseplay:distance(nodeX, nodeZ, currentX, currentZ);
		end		
		
		if #(vehicle.cp.nextTargets) == 0 then
			if distance_to_wp < 10 then
				refSpeed = vehicle.cp.speeds.turn
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))				
			end
		end

		-- avoid circling
		-- if we are closer than distToChange meters to the current waypoint, we switch our target to the next
		local distToChange = 5
		
		if vehicle.cp.mode2nextState == STATE_ALL_TRAILERS_FULL or vehicle.cp.mode2nextState == STATE_DRIVE_TO_COMBINE then
			distToChange = 5 
		elseif vehicle.cp.nextTargets and vehicle.cp.curTarget.turn then
			distToChange = 5
		end

				
		if vehicle.cp.shortestDistToWp == nil or vehicle.cp.shortestDistToWp > distance_to_wp then
			vehicle.cp.shortestDistToWp = distance_to_wp
		end

		if distance_to_wp > vehicle.cp.shortestDistToWp and distance_to_wp < 3 then
			distToChange = distance_to_wp + 1
		end

		-- wait for turning chopper if the field edges are not equal
		if combineIsTurning and tractor.cp.verticalWaypointShift and abs(tractor.cp.verticalWaypointShift) > 2 and vehicle.cp.mode2nextState == "STATE_WAIT_FOR_PIPE" then
			courseplay:setInfoText(vehicle, "COURSEPLAY_WAITING_FOR_COMBINE_TURNED");
			allowedToDrive = false
		end	

		if distance_to_wp < distToChange then
			-- Switching to next waypoint
			vehicle.cp.shortestDistToWp = nil
			if #(vehicle.cp.nextTargets) > 0 then
				-- still have waypoints left
				-- if we are chasing our combine, check if we are close enough now (this can happen when
				-- it has moved since we set our course to it and we are now driving close by) In this case.
				-- abort the course and catch it.
				local continueCourse = true
				if vehicle.cp.mode2nextState == STATE_DRIVE_TO_COMBINE then
					-- how far it is then?
					local combine = vehicle.cp.activeCombine or vehicle.cp.lastActiveCombine;
					if combine then
						local distanceToCombine = courseplay:distanceToObject( vehicle, combine )
						-- magic constants, distance based on turn diameter
						if distanceToCombine < vehicle.cp.turnDiameter + courseplay:getSafetyDistanceFromCombine( combine ) then
						  courseplay:debug( string.format( "Only %.2f meters from the combine on the way, abort course and following the combine", distanceToCombine ), 9 )
						  continueCourse = false
						  vehicle.cp.nextTargets = {}
						  courseplay:switchToNextMode2State(vehicle);
						  courseplay:setMode2NextState(vehicle, STATE_DEFAULT);
						else
						  courseplay:debug( string.format( "Combine is still %.2f meters from me, continuing course", distanceToCombine ), 9 )
						end 
					end
				elseif vehicle.cp.mode2nextState == STATE_ALL_TRAILERS_FULL then 
					local x,z = vehicle.Waypoints[2].cx,vehicle.Waypoints[2].cz
					local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
					local distanceToTarget = courseplay:distanceToPoint(vehicle, x, y, z)
					-- magic constants, distance based on turn diameter
					if distanceToTarget < Utils.getNoNil( vehicle.cp.turnDiameter * 1.5, 20 ) then
					  courseplay:debug( string.format( "Only %.2f meters to Target on the way, abort course", distanceToTarget ), 9 )
					  continueCourse = false
					  vehicle.cp.nextTargets = {}
					  courseplay:switchToNextMode2State(vehicle);
					  courseplay:setMode2NextState(vehicle, STATE_DEFAULT);
					end
				elseif vehicle.cp.mode2nextState == STATE_FOLLOW_TRACTOR then 
					local frontTractor = vehicle.cp.activeCombine.courseplayers[vehicle.cp.positionWithCombine - 1];
					-- distanceToObject may be called with nil here
					if frontTractor then 
						local distanceToTractor = courseplay:distanceToObject( vehicle, frontTractor )
						if distanceToTractor < 50 then
							courseplay:debug( string.format( "Only %.2f meters to tractor on the way, abort course", distanceToTractor ), 9 )
							continueCourse = false
							vehicle.cp.nextTargets = {}
							courseplay:switchToNextMode2State(vehicle);
							courseplay:setMode2NextState(vehicle, STATE_DEFAULT);
						end
					end
				end
				if continueCourse then
				  -- set next target and remome current one from list
				  courseplay:setCurrentTargetFromList(vehicle, 1);
				end
			else
				-- no more waypoints left
				allowedToDrive = false
       			--[[ we are following waypoints mode (for instance because we were in STATE_DRIVE_TO_COMBINE but 
					due the the realistic driving settings, we switched to STATE_FOLLOW_TARGET_WPS).
					now, we are attempting to switch back to drive to combine mode]]
				if vehicle.cp.mode2nextState == STATE_WAIT_FOR_PIPE or vehicle.cp.mode2nextState == STATE_DRIVE_TO_PIPE then
					courseplay:switchToNextMode2State(vehicle);

				elseif vehicle.cp.mode2nextState == STATE_DRIVE_TO_REAR and combineIsTurning then
					courseplay:setInfoText(vehicle, "COURSEPLAY_WAITING_FOR_COMBINE_TURNED");

				elseif vehicle.cp.mode2nextState == STATE_ALL_TRAILERS_FULL then -- tipper turning from combine
					courseplay:releaseCombineStop(vehicle,vehicle.cp.activeCombine)
					courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine)
					courseplay:setIsLoaded(vehicle, true);
					courseplay:setModeState(vehicle, STATE_DEFAULT);
					courseplay:setWaypointIndex(vehicle, 2);

				elseif vehicle.cp.mode2nextState == STATE_WAIT_AT_START then
					-- refSpeed = vehicle.cp.speeds.turn
					courseplay:switchToNextMode2State(vehicle);
					courseplay:setMode2NextState(vehicle, STATE_DEFAULT);

				else
					-- no special processing, just switch to the next mode here
					courseplay:switchToNextMode2State(vehicle);
					courseplay:setMode2NextState(vehicle, STATE_DEFAULT);

				end
			end
		end
	end


	-- STATE 6 (follow tractor)
	local frontTractor;
	if vehicle.cp.activeCombine and vehicle.cp.activeCombine.courseplayers and vehicle.cp.positionWithCombine then
		frontTractor = vehicle.cp.activeCombine.courseplayers[vehicle.cp.positionWithCombine - 1];
	end;
	if vehicle.cp.modeState == STATE_FOLLOW_TRACTOR and frontTractor ~= nil then --Follow Tractor
		courseplay:setInfoText(vehicle, "COURSEPLAY_FOLLOWING_TRACTOR");
		--use the current tractor's sideToDrive as own
		if frontTractor.sideToDrive ~= nil and frontTractor.sideToDrive ~= vehicle.sideToDrive then
			courseplay:debug(string.format("%s: setting current tractor's sideToDrive (%s) as my own", nameNum(vehicle), tostring(frontTractor.sideToDrive)), 4);
			vehicle.sideToDrive = frontTractor.sideToDrive;
		end;

		-- drive behind tractor
		local backDistance = max(10,(turnDiameter + safetyDistance))
		local dx,dz = AIVehicleUtil.getDriveDirection(frontTractor.cp.DirectionNode, x, y, z);
		local x1, y1, z1 = worldToLocal(frontTractor.cp.DirectionNode, x, y, z)
		local distance = Utils.vector2Length(x1, z1)
		local debugText = ""
		local waypointIsBehind = false
		if z1 > -backDistance and dz > 0.6 then
			debugText = "tractor in front of tractor"
			-- left side of tractor
			local cx_left, cy_left, cz_left = localToWorld(frontTractor.cp.DirectionNode, 30, 0, -backDistance-20)
			-- righ side of tractor
			local cx_right, cy_right, cz_right = localToWorld(frontTractor.cp.DirectionNode, -30, 0, -backDistance-20)
			if abs(dx)> 1 then 
				if dx > 0 then
					currentX, currentY, currentZ = cx_left, cy_left, cz_left
				else
					currentX, currentY, currentZ = cx_right, cy_right, cz_right
				end
			else
				if frontTractor.sideToDrive == "right" then
					currentX, currentY, currentZ = cx_right, cy_right, cz_right
				else
					currentX, currentY, currentZ = cx_left, cy_left, cz_left				
				end			
			end
		else
			-- tractor behind tractor
			local sideOffset = 0
			if tractor.cp.workWidth < 4 then
				if vehicle.sideToDrive == 'right' then
					sideOffset = -4
				else
					sideOffset = 4
				end				
			end
			waypointIsBehind = true
			debugText = "tractor behind tractor"
			currentX, currentY, currentZ = localToWorld(frontTractor.cp.DirectionNode, sideOffset, 0, -backDistance * 1.5); -- -backDistance * 1
		end;
		
		if vehicle.cp.realisticDriving and distance > 55 then
			vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, 1)
			local cx,cz = currentX,currentZ
			if courseplay:calculateAstarPathToCoords(vehicle,nil,cx,cz, vehicle.cp.turnDiameter ) then
				courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
				courseplay:setMode2NextState(vehicle, STATE_FOLLOW_TRACTOR);
			end	
		end		
		
		
				
		--show driving direction
		if courseplay.debugChannels[4] then
			renderText(0.2, 0.045, 0.02, string.format("%s,dx= %.2f dz= %.2f",debugText,dx,dz));
			local yy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, currentX, 0, currentZ)
			drawDebugLine(sx, sy+3, sz, 1, 0, 1, currentX, yy+3, currentZ, 1, 0, 1);
		end
		
		local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, currentX, currentY, currentZ)
		dod = Utils.vector2Length(lx, lz)
		
		-- stop if target is out of field
		if dod < 2 or (vehicle.cp.positionWithCombine == 2 and combine.courseplayers[1].cp.modeState ~= STATE_DRIVE_TO_PIPE and dod < 100 ) or (not courseplay:isField(currentX, currentZ, 1, 1)and waypointIsBehind ) then
			courseplay:debug(string.format('\tdod=%s, frontTractor.cp.modeState=%s -> brakeToStop', tostring(dod), tostring(frontTractor.cp.modeState)), 4);
			allowedToDrive = false;
		end
		
		--speeds
		if combine.cp.isSugarBeetLoader or combine.cp.isWoodChipper then
			if distance > 100 then
				refSpeed = vehicle.cp.speeds.street
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				refSpeed = Utils.clamp(frontTractor.lastSpeedReal*3600, vehicle.cp.speeds.turn, vehicle.cp.speeds.field)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
		else
			if dod > 10 then
				refSpeed = vehicle.cp.speeds.field
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			else
				refSpeed = max(frontTractor.lastSpeedReal*3600,vehicle.cp.speeds.crawl)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
		end
		--courseplay:debug(string.format("distance: %d  dod: %d",distance,dod ), 4)
	end
  -- END STATE 6 FOLLOW TRACTOR

	if vehicle.cp.modeState ~= STATE_WAIT_FOR_COMBINE_TO_GET_OUT_OF_WAY  and (currentX == nil or currentZ == nil) then
		if vehicle.cp.infoText == nil then
			courseplay:setInfoText(vehicle, "COURSEPLAY_WAITING_FOR_WAYPOINT");
		end
		allowedToDrive = false;
	end

	if vehicle.cp.forcedToStop then
		courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");
		allowedToDrive = false;
	end

	if vehicle.showWaterWarning then
		allowedToDrive = false
		CpManager:setGlobalInfoText(vehicle, 'WATER');
	end

	-- check traffic and calculate speed
	
	allowedToDrive = courseplay:checkTraffic(vehicle, true, allowedToDrive)
	if vehicle.cp.collidingVehicleId ~= nil then
		refSpeed = courseplay:regulateTrafficSpeed(vehicle,refSpeed,allowedToDrive)
		speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
	end
	
	if g_server ~= nil then
		local lx, lz
		local moveForwards = true
		if currentX ~= nil and currentZ ~= nil then
			lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, currentX, y, currentZ)
		else
			allowedToDrive = false
		end

		courseplay:checkSaveFuel(vehicle,allowedToDrive)
		
		if not allowedToDrive then
			AIVehicleUtil.driveInDirection(vehicle, dt, 30, 0, 0, 28, false, moveForwards, 0, 1)
			vehicle.cp.speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): allowedToDrive false ")
			courseplay:resetSlippingTimers(vehicle)
			return;
		end
		
		if vehicle.cp.TrafficBrake then
			moveForwards = vehicle.movingDirection == -1;
				lx = 0
				lz = 1
		end
		
		if vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS then
			if vehicle.cp.curTarget.rev then
				lx,lz,moveForwards = courseplay:goReverse(vehicle,lx,lz,true)
				refSpeed = min(refSpeed, vehicle.cp.speeds.reverse)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			elseif vehicle.cp.curTarget.turn then
				refSpeed = min(refSpeed, vehicle.cp.speeds.turn)
				speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			end
		end
		
		
		if abs(lx) > 0.5 then
			refSpeed = min(refSpeed, vehicle.cp.speeds.turn)
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		end
				
		if allowedToDrive then
			vehicle.cp.speedDebugLine = speedDebugLine
			courseplay:setSpeed(vehicle, refSpeed)
		end
		

				
		if vehicle.isReverseDriving then
			lz = -lz
		end

		vehicle.cp.TrafficBrake = false
		local combine = vehicle.cp.activeCombine or vehicle.cp.lastActiveCombine
		local distanceToCombine = math.huge 
		if combine ~= nil and combine.cp.isChopper then
			distanceToCombine = courseplay:distanceToObject( vehicle, combine )  	
		end
		if distanceToCombine > 50 and ((vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS and not vehicle.cp.curTarget.turn and not vehicle.cp.curTarget.rev ) or vehicle.cp.modeState == STATE_DRIVE_TO_COMBINE) then   
			local tx, tz
			-- when following waypoints, check obstacles on the course, not dead ahead
			if vehicle.cp.modeState == STATE_FOLLOW_TARGET_WPS then
				if #vehicle.cp.nextTargets > 1 then
				-- look ahead two waypoints if we have that many
				tx, tz = vehicle.cp.nextTargets[ 2 ].x, vehicle.cp.nextTargets[ 2 ].z
				else
				-- otherwise just the next one
				tx, tz = vehicle.cp.curTarget.x, vehicle.cp.curTarget.z 
				end
			end
			lx, lz = courseplay:isTheWayToTargetFree(vehicle, lx, lz, tx, tz )
		end
		
		courseplay:setTrafficCollision(vehicle, lx, lz,true)
		
		if math.abs(vehicle.lastSpeedReal) < 0.0001 and not g_currentMission.missionInfo.stopAndGoBraking then
			if not moveForwards then
				vehicle.nextMovingDirection = -1
			else
				vehicle.nextMovingDirection = 1
			end;
		end;
		
		AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, moveForwards, lx, lz, refSpeed, 1)
				
		--if courseplay.debugChannels[4] and vehicle.cp.nextTargets and vehicle.cp.curTarget.x and vehicle.cp.curTarget.z then
		if (courseplay.debugChannels[4] or courseplay.debugChannels[9]) and vehicle.cp.curTarget.x and vehicle.cp.curTarget.z then
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, vehicle.cp.curTarget.x, 0, vehicle.cp.curTarget.z)
			drawDebugPoint(vehicle.cp.curTarget.x, y +2, vehicle.cp.curTarget.z, 1, 0.65, 0, 1);
			
			for i,tp in pairs(vehicle.cp.nextTargets) do
				local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tp.x, 0, tp.z)
				drawDebugPoint(tp.x, y +2, tp.z, 1, 0.65, 0, 1);
				if i == 1 then
					drawDebugLine(vehicle.cp.curTarget.x, y + 2, vehicle.cp.curTarget.z, 1, 0, 1, tp.x, y + 2, tp.z, 1, 0, 1); 
				else
					local pp = vehicle.cp.nextTargets[i-1];
					drawDebugLine(pp.x, y+2, pp.z, 1, 0, 1, tp.x, y + 2, tp.z, 1, 0, 1); 
				end;
			end;
		end;
	end
end


function courseplay:calculateCombineOffset(vehicle, combine)
	local curFile = "mode2.lua";
	local offs = vehicle.cp.combineOffset
	local offsPos = abs(vehicle.cp.combineOffset)
	local combineDirNode = combine.cp.DirectionNode or combine.rootNode;
	
	local prnX,prnY,prnZ, prnwX,prnwY,prnwZ, combineToPrnX,combineToPrnY,combineToPrnZ = 0,0,0, 0,0,0, 0,0,0;
	if combine.pipeRaycastNode ~= nil then
		prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combineDirNode, prnwX, prnwY, prnwZ)

		if combine.cp.pipeSide == nil then
			courseplay:getCombinesPipeSide(combine)
		end
	end;

	--special tools, special cases
	local specialOffset = courseplay:getSpecialCombineOffset(combine);
	if vehicle.cp.combineOffsetAutoMode and specialOffset then
		offs = specialOffset;
	
	--Sugarbeet Loaders (e.g. Ropa Euro Maus, Holmer Terra Felis) --TODO (Jakob): theoretically not needed, as it's being dealt with in getSpecialCombineOffset()
	elseif vehicle.cp.combineOffsetAutoMode and combine.cp.isSugarBeetLoader then
		local utwX,utwY,utwZ = getWorldTranslation(combine.unloadingTrigger.node);
		local combineToUtwX,_,combineToUtwZ = worldToLocal(combineDirNode, utwX,utwY,utwZ);
		offs = combineToUtwX;

	--combine // combine_offset is in auto mode, pipe is open
	elseif not combine.cp.isChopper and vehicle.cp.combineOffsetAutoMode and combine.pipeCurrentState == 2 and combine.pipeRaycastNode ~= nil then --pipe is open
		local raycastNodeParent = getParent(combine.pipeRaycastNode);
		if raycastNodeParent == combine.rootNode then -- pipeRaycastNode is direct child of combine.root
			--safety distance so the trailer doesn't crash into the pipe (sidearm)
			local additionalSafetyDistance = 0;
			if combine.cp.isGrimmeTectron415 then
				additionalSafetyDistance = -0.5;
			end;

			offs = prnX + additionalSafetyDistance;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, offs), 4)
		elseif getParent(raycastNodeParent) == combine.rootNode then --pipeRaycastNode is direct child of pipe is direct child of combine.root
			local pipeX, pipeY, pipeZ = getTranslation(raycastNodeParent)
			offs = pipeX - prnZ;
			
			if prnZ == 0 or combine.cp.isGrimmeRootster604 then
				offs = pipeX - prnY;
			end;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipe > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, offs), 4)
		elseif combine.pipeRaycastNode ~= nil then --BACKUP pipeRaycastNode isn't direct child of pipe
			offs = combineToPrnX + 0.5;
			--courseplay:debug(string.format("%s(%i): %s @ %s: combineToPrnX // offs = %f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, offs), 4)
		elseif combine.cp.lmX ~= nil then --user leftMarker
			offs = combine.cp.lmX + 2.5;
		else --if all else fails
			offs = 8;
		end;

	--combine // combine_offset is in manual mode
	elseif not combine.cp.isChopper and not vehicle.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [manual] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);
	
	--combine // combine_offset is in auto mode
	elseif not combine.cp.isChopper and vehicle.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [auto] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);

	--chopper // combine_offset is in auto mode
	elseif combine.cp.isChopper and vehicle.cp.combineOffsetAutoMode then
		if combine.cp.lmX ~= nil then
			offs = max(combine.cp.lmX + 2.5, 7);
		else
			offs = 8;
		end;
		courseplay:sideToDrive(vehicle, combine, 10);
			
		if vehicle.sideToDrive ~= nil then
			if vehicle.sideToDrive == "left" then
				offs = abs(offs);
			elseif vehicle.sideToDrive == "right" then
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
		--courseplay:debug(string.format("%s(%i): %s @ %s: cp.forcedSide=%s => offs=%f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, combine.cp.forcedSide, offs), 4)
	end

	--refresh for display in HUD and other calculations
	vehicle.cp.combineOffset = offs;
end;

function courseplay:calculateVerticalOffset(vehicle, combine)
	local cwX, cwY, cwZ = getWorldTranslation(combine.pipeRaycastNode);
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
		courseplay:debug( string.format( "%s: Switching state: %d -> %d", nameNum( vehicle ), vehicle.cp.modeState, Utils.getNoNil( state, -1 )), 9 )
		vehicle.cp.modeState = state;
	end;
end;

function courseplay:setMode2NextState(vehicle, nextState)
	if nextState == nil then return; end;
  local oldNextState = vehicle.cp.mode2nextState or 0 
  courseplay:debug( string.format( "%s: Setting next state: %d -> %d", nameNum( vehicle ), oldNextState, nextState ), 9 )
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

function courseplay:convertTable(turnTargets)
	local newTable = {}
	for i=1,#turnTargets do
		newTable[i] = {}
		newTable[i].x = turnTargets[i].posX
		newTable[i].z = turnTargets[i].posZ
		newTable[i].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newTable[i].x, 0, newTable[i].z);
		newTable[i].rev = turnTargets[i].turnReverse or false
		newTable[i].turn = true 
	end
	return  newTable
end

function courseplay:createTurnAwayCourse(vehicle,direction,sentDiameter,workwidth)
		--inspired by Satis :-)
		
		local targets = {}
		local center1, center2, startDir, stopDir = {}, {}, {}, {};
		local diameter = sentDiameter
		local radius = diameter/2
		local center1SideOffset = radius*direction
		local center2SideOffset = -(workwidth-radius)*direction
		local sideC = diameter;
		local sideB = abs(center1SideOffset-center2SideOffset);
		
		local centerHeight = math.sqrt(sideC^2 - sideB^2);
				
		--- Get the 2 circle center cordinate
		center1.x,_,center1.z = localToWorld(vehicle.cp.DirectionNode, center1SideOffset, 0, 0);
		center2.x,_,center2.z = localToWorld(vehicle.cp.DirectionNode, center2SideOffset, 0, -centerHeight);

		
		
		--- Generate first turn circle
		startDir.x,_,startDir.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, 0);
		courseplay:generateTurnCircle(vehicle, center1, startDir, center2, radius, direction);

		--- Generate second turn circle
		stopDir.x,_,stopDir.z = localToWorld(vehicle.cp.DirectionNode, -centerHeight*direction, 0, -centerHeight+radius);
		courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, radius, -direction, true);
		
		targets = courseplay:convertTable(vehicle.cp.turnTargets)
		vehicle.cp.turnTargets = {}
		
		return targets
end

-- if there's fruit between me and the combine, calculate a path around it and return true.
-- if there's no fruit or no path around it or couldn't calculate path, return false
function courseplay:calculateAstarPathToCoords( vehicle, combine, tx, tz, endBeforeTargetDistance )
	local cx, cz = 0, 0
	local fruitType = 0

  -- if a combine was passed, use it's location
	if combine ~= nil then
		cx, _, cz = getWorldTranslation( combine.rootNode )
	else
		cx, cz = tx, tz
	end
  --
	-- pathfinding is expensive and we don't want it happen in every update cycle
	if not courseplay:timerIsThrough( vehicle, 'pathfinder', true ) then
		return false
	end
	courseplay:setCustomTimer( vehicle, 'pathfinder', 5 )

	local hasFruit, density, fruitType, fruitName = courseplay:hasLineFruit( vehicle.cp.DirectionNode,nil, nil, cx, cz, fixedFruitType )
	if not hasFruit then
		-- no fruit between tractor and combine, can continue in STATE_DRIVE_TO_COMBINE 
		-- and drive directly to the combine.
		return false
	else
		courseplay:debug( string.format( "there is %.1f %s(%d) in my way -> create path around it",density,fruitName,fruitType), 9 )
	end
  
	-- tractor coordinates
	local vx,vy,vz = getWorldTranslation( vehicle.cp.DirectionNode )

	-- where am I ?
	if courseplay.fields == nil then
		courseplay:debug( nameNum(vehicle).."- Pathfinding: no field data available!", 9 )
		courseplay:debug( "to use the full function of pathfinding, you have to activate the automatic field scan or scan this field manually", 9 )
		return false
	end

	local fieldNum = courseplay:onWhichFieldAmI( vehicle ); 
		
	if fieldNum == 0 then														-- No combines are aviable use us again
		local combine = vehicle.cp.activeCombine or vehicle.cp.lastActiveCombine or vehicle;
		fieldNum = courseplay:onWhichFieldAmI( combine );
		if fieldNum == 0 then
			courseplay:debug( "I'm not on field, my combine isn't either", 9 )
			return false
		else
			courseplay:debug( "I'm not on field, my combine is on ".. tostring( fieldNum ), 9 )
			-- pathfinding works only within the field, so we'll have to get to the field first
			local closestPointToVehicleIx = courseplay.generation:getClosestPolyPoint( courseplay.fields.fieldData[ fieldNum ].points, vx, vz )
			-- we'll use this instead of the vehicle location, so tractor will drive directly to this point first 
			vx = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cx
			vz = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cz
		end
	else
		courseplay:debug( "I'm on field " .. tostring( fieldNum ), 9 )
		local _, pointInPoly, _, _ = courseplay.fields:getPolygonData(courseplay.fields.fieldData[fieldNum].points, cx, cz, true, true, true);
		if not pointInPoly then
			local closestPointToVehicleIx = courseplay.generation:getClosestPolyPoint( courseplay.fields.fieldData[ fieldNum ].points, cx, cz )
			cx = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cx
			cz = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cz
		end	
	end

  courseplay:debug( string.format( "Finding path between %.2f, %.2f and %.2f, %.2f", vx, vz, cx, cz ), 9 )
  local path = pathFinder.findPath( { x = vx, z = vz }, { x = cx, z = cz }, 
                                    courseplay.fields.fieldData[fieldNum].points )
   
  if path then
    courseplay:debug( string.format( "Path found with %d waypoints", #path ), 9 )
  else
    courseplay:debug( string.format( "No path found, reverting to dumb mode" ), 9 )
    return false
  end

  -- path only has x,z, add y, most likely for the debug lines only.
  if g_currentMission then
   -- courseplay:debug( tableShow( g_currentMission, "currentMission", 9, ' ', 3 ), 9 )
    for _, point in ipairs( path ) do
      point.y = getTerrainHeightAtWorldPos( g_currentMission.terrainRootNode, point.x, 1, point.z )
    end
  else
    courseplay:debug( string.format( "g_currentMission does not exist, oops. " ))
    return false
  end
  -- make sure path begins far away from the tractor so it won't circle around
  local pointFarEnoughIx = 1
  for _, point in ipairs( path ) do 
		local lx, ly, lz = worldToLocal( vehicle.cp.DirectionNode, point.x, point.y, point.z )
		local d = Utils.vector2Length(lx, lz)
    if d > Utils.getNoNil( vehicle.cp.turnDiameter, 5 ) then break end
    pointFarEnoughIx = pointFarEnoughIx + 1
  end
  for i = 1, pointFarEnoughIx do
    table.remove( path, 1 ) 
  end
  -- make sure path ends far away from the target so it can switch to the next mode
  -- without circling
  local pointFarEnoughIx = #path
  for i = #path, 1, -1 do
    local point = path[ i ]
    local d = Utils.vector2Length( cx - point.x, cz - point.z )
    if d > Utils.getNoNil( endBeforeTargetDistance, 0 ) then break end
    pointFarEnoughIx = pointFarEnoughIx - 1
  end
  for i = #path, pointFarEnoughIx, -1 do
    table.remove( path ) 
  end
  if #path < 2 then
    courseplay:debug( string.format( "Path hasn't got enough waypoints (%d), no fruit avoidance", #path ), 9 )
    return false
  else
    vehicle.cp.nextTargets = path
    return true                                 
  end
end

function courseplay:onWhichFieldAmI(vehicle)
	local fieldNum = 0;
	local postionX,_,postionZ = getWorldTranslation(vehicle.cp.DirectionNode or vehicle.rootNode);
	for index, field in pairs(courseplay.fields.fieldData) do
		if postionX >= field.dimensions.minX and postionX <= field.dimensions.maxX and postionZ >= field.dimensions.minZ and postionZ <= field.dimensions.maxZ then	
			local _, pointInPoly, _, _ = courseplay.fields:getPolygonData(field.points, postionX, postionZ, true, true, true);
			if pointInPoly then
				fieldNum = index
				break
			end
		end	
	end
	return fieldNum
end

function courseplay:getWaypointShift(vehicle,tractor)
	if not tractor:getIsCourseplayDriving() then
		return 0;
	else
		local px,pz = tractor.Waypoints[tractor.cp.waypointIndex].cx, tractor.Waypoints[tractor.cp.waypointIndex].cz
		local py = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 0, pz)
		local _,_,vehicleShift = worldToLocal(tractor.cp.DirectionNode,px,py,pz)

		local nx,nz = tractor.Waypoints[tractor.cp.waypointIndex+1].cx, tractor.Waypoints[tractor.cp.waypointIndex+1].cz
		local ny = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nx, 0, nz)
		local _,_,npShift = worldToLocal(tractor.cp.DirectionNode,nx,ny,nz)
		return npShift-vehicleShift+tractor.sizeLength*.5;
	end
end

function courseplay:getSafetyDistanceFromCombine( combine )
	local safetyDistance = 11;
	if combine.cp.isHarvesterSteerable or combine.cp.isSugarBeetLoader or combine.cp.isWoodChipper or combine.cp.isPoettingerMex5 then
		safetyDistance = 24;
	elseif courseplay:isAttachedCombine(combine) then
		safetyDistance = 11;
	elseif combine.cp.isCombine then
		safetyDistance = 10;
	elseif combine.cp.isChopper then
		safetyDistance = 11;
	end;
  return safetyDistance
end
-- do not remove this comment
-- vim: set noexpandtab:
