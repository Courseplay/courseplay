--[[
handles "mode9": Fill and empty shovel
--------------------------------------
0)  Course setup:
	a) Start in front of silo
	b) drive forward, set waiting point #1
	c) drive forwards through silo, at end set waiting point #2
	d) drive reverse (back through silo) and turn at end
	e) drive forwards to bunker, set waiting point #3 and unload
	f) drive backwards, turn, drive forwards until before start

1)  drive course until waiting point #1 - set shovel to "filling" rotation
2)  [repeat] if lastFillLevel == currentFillLevel: drive ahead until is filling
2b) if waiting point #2 is reached, area is empty -> stop work
3)  if currentFillLevel == 100: set shovel to "transport" rotation, find closest point that's behind tractor, drive course from there
4)  drive course forwards until waiting point #3 - set shovel to "empty" rotation
5)  drive course with recorded direction (most likely in reverse) until end - continue and repeat to 1)

NOTE: rotation: movingTool.curRot[1] (only x-axis) / translation: movingTool.curTrans[3] (only z-axis)
]]

function courseplay:handle_mode9(vehicle, fillLevelPct, allowedToDrive,lx,lz, dt)
	--state 1: goto BunkerSilo
	--state 2: get ready to load / loading
	--state 3: transport to BGA
	--state 4: get ready to unload
	--state 5: unload
	--state 6: leave BGA
	--state 7: wait for Trailer 10 before EmptyPoint

	if vehicle.cp.totalCapacity == nil or vehicle.cp.totalCapacity == 0 then --NOTE: query here instead of getCanUseAiMode() as tipperCapacity doesn't exist until drive() has been run
		courseplay:setInfoText(vehicle, 'COURSEPLAY_SHOVEL_NOT_FOUND');
		return false;
	end;

	--get moving tools (only once after starting)
	if vehicle.cp.movingToolsPrimary == nil then
		vehicle.cp.movingToolsPrimary, vehicle.cp.movingToolsSecondary = courseplay:getMovingTools(vehicle);
	end;
	local mt, secondary = vehicle.cp.movingToolsPrimary, vehicle.cp.movingToolsSecondary;

	if vehicle.cp.waypointIndex == 1 and vehicle.cp.shovelState ~= 6 then  --backup for missed approach
		courseplay:setShovelState(vehicle, 1, 'backup');
		courseplay:setIsLoaded(vehicle, false);
	end;

	
	-- STATE 1: DRIVE TO BUNKER SILO (1st waiting point)
	if vehicle.cp.shovelState == 1 then
		if vehicle.cp.waypointIndex + 1 > vehicle.cp.shovelFillStartPoint then
			if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[2], dt) then
				courseplay:setShovelState(vehicle, 2);
			end;
			if fillLevelPct >= 98 then
				vehicle.cp.shovel:setFillLevel(vehicle.cp.shovel.cp.capacity * 0.97, vehicle.cp.shovel.cp.fillType);
			end;
			if vehicle.cp.mode9TargetSilo == nil then
				courseplay:debug(('%s: vehicle.cp.mode9TargetSilo = nil call getTargetBunkerSilo'):format(nameNum(vehicle)), 10);
				vehicle.cp.mode9TargetSilo = courseplay:getMode9TargetBunkerSilo(vehicle)
			end
			if vehicle.cp.mode9TargetSilo then
				if vehicle.cp.BunkerSiloMap == nil then
				courseplay:debug(('%s: vehicle.cp.mode9TargetSilo = %s call createMap'):format(nameNum(vehicle),tostring(vehicle.cp.mode9TargetSilo.saveId)), 10);
					vehicle.cp.BunkerSiloMap = courseplay:createBunkerSiloMap(vehicle, vehicle.cp.mode9TargetSilo)
					if vehicle.cp.BunkerSiloMap ~= nil then
						local stopSearching = false
						local mostFillLevelAtLine = 0
						local mostFillLevelIndex = 2
						for lineIndex, line in pairs(vehicle.cp.BunkerSiloMap) do
							if stopSearching then
								break
							end
							mostFillLevelAtLine = 0
							for column, fillUnit in pairs(line) do
								if 	mostFillLevelAtLine < fillUnit.fillLevel then
									mostFillLevelAtLine = fillUnit.fillLevel
									mostFillLevelIndex = column
								end
								if column == #line and mostFillLevelAtLine > 0 then
									fillUnit = line[mostFillLevelIndex]
									if vehicle.cp.mode9SavedLastFillLevel == courseplay:round(fillUnit.fillLevel,1) then
										courseplay:debug(('%s triesTheSameFillUnit fillLevel: %s'):format(nameNum(vehicle),tostring(vehicle.cp.mode9SavedLastFillLevel)),10)
										vehicle.cp.mode9triesTheSameFillUnit = true
									end
									vehicle.cp.actualTarget = {
														line = lineIndex;
														column = mostFillLevelIndex;
																}
									vehicle.cp.mode9SavedLastFillLevel = courseplay:round(fillUnit.fillLevel,1)
									
									stopSearching = true
									break
								end
							end
						end
					end
				else
					
					
				
				end
			end
		end;


	-- STATE 2: PREPARE LOADING
	elseif vehicle.cp.shovelState == 2 then
		if vehicle.cp.mode9TargetSilo and vehicle.cp.BunkerSiloMap and vehicle.cp.actualTarget then
			local targetUnit = vehicle.cp.BunkerSiloMap[vehicle.cp.actualTarget.line][vehicle.cp.actualTarget.column]
			local cx , cz = targetUnit.cx, targetUnit.cz
			local nx,ny,nz = getWorldTranslation(vehicle.cp.shovel.shovelTipReferenceNode)
			local _,_,backUpZ = worldToLocal(vehicle.cp.DirectionNode, cx , targetUnit.y , cz); -- its the savety switch in case I miss the point 
			local distanceToTarget =  courseplay:distance(nx, nz, cx, cz) --distance from shovel to target
			if distanceToTarget < 1 or backUpZ < 2 then
				vehicle.cp.actualTarget.line = math.min(vehicle.cp.actualTarget.line + 1,#vehicle.cp.BunkerSiloMap)
				vehicle.cp.mode9triesTheSameFillUnit = false
			end
			if vehicle.cp.mode9triesTheSameFillUnit and distanceToTarget < 3 then
				local fillType = targetUnit.fillType 
				if vehicle.cp.shovel:getFreeCapacity(fillType) >= targetUnit.fillLevel then
					local takenFromGround = TipUtil.removeFromGroundByArea(targetUnit.sx, targetUnit.sz, targetUnit.wx, targetUnit.wz, targetUnit.hx, targetUnit.hz,fillType )
					if takenFromGround > 0 then
						vehicle.cp.shovel:setUnitFillLevel(1, takenFromGround + vehicle.cp.shovel:getFillLevel(fillType), 0, true)
						courseplay:debug(('%s couldnt get the material %s[%i]-> remove %s fromArea'):format(nameNum(vehicle),FillUtil.fillTypeIndexToDesc[fillType].name,fillType,tostring(takenFromGround)),10)
					end
				else
					courseplay:debug(('%s couldnt get the material %s[%i] but its too much for the shovel-> not remove fromArea'):format(nameNum(vehicle),FillUtil.fillTypeIndexToDesc[fillType].name,fillType),10)
				end
			end
			lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, cx, targetUnit.y, cz);
		end
		if vehicle.cp.shovelStopAndGo then
			if vehicle.cp.shovelLastFillLevel == nil then
				vehicle.cp.shovelLastFillLevel = fillLevelPct;
			elseif vehicle.cp.shovelLastFillLevel ~= nil and fillLevelPct == vehicle.cp.shovelLastFillLevel and fillLevelPct < 100 then
				--allowedToDrive = true;
			elseif vehicle.cp.shovelLastFillLevel ~= nil and vehicle.cp.shovelLastFillLevel ~= fillLevelPct then
				allowedToDrive = false;
			end;
			vehicle.cp.shovelLastFillLevel = fillLevelPct;
		end;
						--vv TODO checkif its a Giants Bug the Shovel never gets 100%
		if fillLevelPct >= 99 or vehicle.cp.isLoaded or vehicle.cp.slippingStage == 2 then
			if not vehicle.cp.isLoaded then
				local _,ty,_ = getWorldTranslation(vehicle.cp.DirectionNode);
				local _,_,sfpZ = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[vehicle.cp.shovelFillStartPoint].cx , ty , vehicle.Waypoints[vehicle.cp.shovelFillStartPoint].cz);
				for i=vehicle.cp.waypointIndex, vehicle.cp.numWaypoints do
					local _,_,z = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[i].cx , ty , vehicle.Waypoints[i].cz);
					if ((vehicle.cp.BunkerSiloMap == nil and z < -3 ) or z < sfpZ) and vehicle.Waypoints[i].rev  then
						--print("z taken:  "..tostring(z));
						courseplay:setWaypointIndex(vehicle, i);
						courseplay:setIsLoaded(vehicle, true);
						break;
					end;
				end;
				if not g_currentMission.missionInfo.stopAndGoBraking then
					vehicle.nextMovingDirection = -1
				end
			else
				if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[3], dt) then
					if vehicle.cp.slippingStage == 2 then
						vehicle.cp.slippingStageBreak = true
						courseplay:setShovelState(vehicle, 3,' aborted by slipping');
					else
						courseplay:setShovelState(vehicle, 3);
					end
				else
					allowedToDrive = false;
				end;
			end;
		end;

	-- STATE 3: TRANSPORT TO BGA
	elseif vehicle.cp.shovelState == 3 then
		local p = vehicle.cp.shovelFillStartPoint
		local _,y,_ = getWorldTranslation(vehicle.cp.DirectionNode);
		local _,_,z = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[p].cx ,y, vehicle.Waypoints[p].cz); 
		if vehicle.cp.BunkerSiloMap ~= nil and vehicle.Waypoints[vehicle.cp.waypointIndex].rev and z < -5 then
			lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, vehicle.Waypoints[p].cx, y, vehicle.Waypoints[p].cz);
		end
		if vehicle.cp.slippingStageBreak and not vehicle.Waypoints[vehicle.cp.waypointIndex].rev then
			vehicle.cp.slippingStageBreak = nil
			if fillLevelPct < 75 then
				courseplay:setIsLoaded(vehicle, false);
				courseplay:setShovelState(vehicle, 1,'try again');
				courseplay:setWaypointIndex(vehicle, vehicle.cp.shovelFillStartPoint - 1);
				vehicle.cp.BunkerSiloMap = nil
			end
		end
		
		if vehicle.cp.previousWaypointIndex + 4 > vehicle.cp.shovelEmptyPoint then
			if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[4], dt) then
				vehicle.cp.shovel.trailerFound = nil;
				vehicle.cp.shovel.objectFound = nil;
				courseplay:setShovelState(vehicle, 7);
			end;
		end;
	-- STATE 7: WAIT FOR TRAILER 10m BEFORE EMPTYING POINT
	elseif vehicle.cp.shovelState == 7 then
		local p = vehicle.cp.shovelEmptyPoint;
		local _,ry,_ = getWorldTranslation(vehicle.cp.DirectionNode);
		local nx, nz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, vehicle.Waypoints[p].cx, ry, vehicle.Waypoints[p].cz);
		local lx,ly,lz = localDirectionToWorld(vehicle.cp.DirectionNode, nx, 0, nz);
		for i=6,12 do
			local x,y,z = localToWorld(vehicle.cp.DirectionNode,0,4,i);
			raycastAll(x, y, z, lx, -1, lz, "findTrailerRaycastCallback", 10, vehicle.cp.shovel);
			if courseplay.debugChannels[10] then
				drawDebugLine(x, y, z, 1, 0, 0, x+lx*10, y-10, z+lz*10, 1, 0, 0);
			end;
		end;

		local ox, _, oz = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[p].cx, ry, vehicle.Waypoints[p].cz);
		local distance = Utils.vector2Length(ox, oz);
		if vehicle.cp.shovel.trailerFound == nil and vehicle.cp.shovel.objectFound == nil and distance < 10 then
			allowedToDrive = false;
		elseif distance < 10 then
			vehicle.cp.shovel.trailerFound = nil;
			vehicle.cp.shovel.objectFound = nil;
			courseplay:setShovelState(vehicle, 4);
		end;

	-- STATE 4: PREPARE UNLOADING
	elseif vehicle.cp.shovelState == 4 then
		local x,y,z = localToWorld(vehicle.cp.shovel.shovelTipReferenceNode,0,0,-1);
		local emptySpeed = vehicle.cp.shovel:getShovelEmptyingSpeed();
		if emptySpeed == 0 then
			raycastAll(x, y, z, 0, -1, 0, "findTrailerRaycastCallback", 10, vehicle.cp.shovel);
		end;

		if vehicle.cp.shovel.trailerFound ~= nil or vehicle.cp.shovel.objectFound ~= nil or emptySpeed > 0 then
			--print("trailer/object found");
			local unloadAllowed = vehicle.cp.shovel.trailerFoundSupported or vehicle.cp.shovel.objectFoundSupported;
			if unloadAllowed then
				if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[5], dt) then
					courseplay:setShovelState(vehicle, 5);
				else
					allowedToDrive = false;
				end;
			else
				allowedToDrive = false;
			end;
		end;

	-- STATE 5: UNLOADING
	elseif vehicle.cp.shovelState == 5 then
		--courseplay:handleSpecialTools(vehicle,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
		courseplay:handleSpecialTools(vehicle,vehicle,true,nil,nil,nil,nil,nil)
		if vehicle.cp.shovel.trailerFound then
			courseplay:setOwnFillLevelsAndCapacities(vehicle.cp.shovel.trailerFound)
		end
		local stopUnloading = vehicle.cp.shovel.trailerFound ~= nil and vehicle.cp.shovel.trailerFound.cp.fillLevel >= vehicle.cp.shovel.trailerFound.cp.capacity;
		if fillLevelPct <= 1 or stopUnloading then
			if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[4], dt) then
				if vehicle.cp.isLoaded then
					for i = vehicle.cp.waypointIndex,vehicle.cp.numWaypoints do
						if vehicle.Waypoints[i].rev then
							courseplay:setIsLoaded(vehicle, false);
							courseplay:setWaypointIndex(vehicle, i);
							break;
						end;
					end;
				end;
				if not vehicle.Waypoints[vehicle.cp.waypointIndex].rev then
					courseplay:setShovelState(vehicle, 6);
				end
			else
				allowedToDrive = false;
			end;
		else
			allowedToDrive = false;
		end;

	-- STATE 6: RETURN FROM BGA TO START POINT
	elseif vehicle.cp.shovelState == 6 then
		courseplay:handleSpecialTools(vehicle,vehicle,false,nil,nil,nil,nil,nil);

		courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[3], dt);
	
		if vehicle.cp.waypointIndex == 1 then
			vehicle.cp.BunkerSiloMap = nil
			vehicle.cp.actualTarget = nil
			courseplay:setShovelState(vehicle, 1);
			
		end;
	end;

	return allowedToDrive , lx,lz;
end;

function courseplay:setShovelState(vehicle, state, extraText)
	if vehicle.cp.shovelState ~= state then
		vehicle.cp.shovelState = state;
		if courseplay.debugChannels[10] then
			if extraText then
				courseplay:debug(('%s: set shovel state to %d (%s)'):format(nameNum(vehicle), state, extraText), 10);
			else
				courseplay:debug(('%s: set shovel state to %d'):format(nameNum(vehicle), state), 10);
			end;
		end;
	end
end;

function courseplay:getCurrentMovingToolsPosition(vehicle, movingTools, secondary , fixIndex) --NOTE: still needed for saveShovelPosition()
	if movingTools == nil then
		print(nameNum(vehicle) .. ': courseplay:getCurrentMovingToolsPosition() return nil');
		return nil;
	end;

	local rotAxis, transAxis = 1, 3; -- 1 = x, 3 = z;
	local curRot, curTrans = {}, {};
	if fixIndex then
		rotAxis = 3
		local mt = movingTools[fixIndex]
			if mt.curRot and mt.curRot[rotAxis] then
				table.insert(curRot, mt.curRot[rotAxis]);
			end;
			if mt.curTrans and mt.curTrans[transAxis] then
				table.insert(curTrans, mt.curTrans[transAxis]);
			end;		
	else
		for i,mt in pairs(movingTools) do
			if mt.curRot and mt.curRot[rotAxis] then
				table.insert(curRot, mt.curRot[rotAxis]);
			end;
			if mt.curTrans and mt.curTrans[transAxis] then
				table.insert(curTrans, mt.curTrans[transAxis]);
			end;
		end;
		if secondary ~= nil then
			for i,mt in pairs(secondary) do
				if mt.curRot and mt.curRot[rotAxis] then
					table.insert(curRot, mt.curRot[rotAxis]);
				end;
				if mt.curTrans and mt.curTrans[transAxis] then
					table.insert(curTrans, mt.curTrans[transAxis]);
				end;
			end;
		end;
	end 
	return curRot, curTrans;
end;

function courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, secondaryMovingTools, targetPositions, dt ,fixIndex)
	local targetRotations, targetTranslations = targetPositions.rot, targetPositions.trans;
	local changed = false;
	local numPrimaryMovingTools = #movingTools;
	local rotAxis, transAxis = 1, 3; -- 1 = x, 3 = z;

	for i=1,#targetRotations do
		local mt, mtMainObject;
		if fixIndex then
			rotAxis = 3
			mt = movingTools[fixIndex];
			mtMainObject = vehicle
		else
			if i <= numPrimaryMovingTools then
				mt = movingTools[i];
				mtMainObject = vehicle;
			else
				mt = secondaryMovingTools[i - numPrimaryMovingTools];
				mtMainObject = vehicle.cp.shovel;
			end;
		end
		if mt == nil then
			break
		end
		local curRot = mt.curRot[rotAxis];
		local curTrans = mt.curTrans[transAxis];
		local targetRot = targetRotations[i];
		local targetTrans = targetTranslations[i];
		if courseplay:round(curRot, 4) ~= courseplay:round(targetRot, 4) or courseplay:round(curTrans, 3) ~= courseplay:round(targetTrans, 3) then
			local newRot, newTrans;

			-- ROTATION
			local rotDir = Utils.sign(targetRot - curRot);
			if mt.node and rotDir and rotDir ~= 0 then
				local rotChange = mt.rotSpeed ~= nil and (mt.rotSpeed * dt) or (0.2/dt);
				newRot = curRot + (rotChange * rotDir)
				if (rotDir == 1 and newRot > targetRot) or (rotDir == -1 and newRot < targetRot) then
					newRot = targetRot;
				end;
				if newRot ~= curRot  then
					--courseplay:debug(string.format('%s: movingTool %d: curRot=%.5f, targetRot=%.5f -> newRot=%.5f', nameNum(vehicle), i, curRot, targetRot, newRot), 10);
					mt.curRot[rotAxis] = newRot;
					setRotation(mt.node, unpack(mt.curRot));
					if mt.delayedNode ~= nil then
						mt.delayedUpdates = 2;
						Cylindered.setDelayedNodeRotation(vehicle, mt);
					end
					changed = true;
				end;
			end;

			-- TRANSLATION
			if mt.transSpeed ~= nil then --only change values if transSpeed actually exists
				-- local transSpeed = mt.transSpeed * dt;
				local transDir = Utils.sign(targetTrans - curTrans);
				if mt.node and mt.transMin and mt.transMax and transDir and transDir ~= 0 then
					local transChange = math.min(mt.transSpeed, 0.001) * dt; -- maximum: 1mm/ms (1m/s)
					newTrans = Utils.clamp(curTrans + (transChange * transDir), mt.transMin, mt.transMax);
					if (transDir == 1 and newTrans > targetTrans) or (transDir == -1 and newTrans < targetTrans) then
						newTrans = targetTrans;
					end;
					if newTrans ~= curTrans and newTrans >= mt.transMin and newTrans <= mt.transMax then
						--courseplay:debug(string.format('%s: movingTool %d: curTrans=%.5f, targetTrans=%.5f -> newTrans=%.5f', nameNum(vehicle), i, curTrans, targetTrans, newTrans), 10);
						mt.curTrans[transAxis] = newTrans;
						setTranslation(mt.node, unpack(mt.curTrans));
						if mt.delayedNode ~= nil then
							mt.delayedUpdates = 2;
							Cylindered.setDelayedNodeTranslation(vehicle, mt);
						end
						changed = true;
					end;
				end;
			end;

			-- DIRTY FLAGS (movingTool)
			-- TODO: check if Cylindered.setMovingToolDirty() is better here
			if changed then
				if vehicle.cp.attachedFrontLoader ~= nil then
					Cylindered.setDirty(vehicle.cp.attachedFrontLoader, mt);
				else
					Cylindered.setDirty(mtMainObject, mt);
				end	
				vehicle:raiseDirtyFlags(mtMainObject.cylinderedDirtyFlag);
			end;
		end;
	end;

	-- DIRTY FLAGS (movingParts)
	if changed then
		if vehicle.activeDirtyMovingParts then
			for _, part in pairs(vehicle.activeDirtyMovingParts) do
				Cylindered.setDirty(vehicle, part);
			end;
		end;
		if vehicle.cp.shovel and vehicle.cp.shovel.activeDirtyMovingParts then
			for _, part in pairs(vehicle.cp.shovel.activeDirtyMovingParts) do
				Cylindered.setDirty(vehicle.cp.shovel, part);
			end;
		end;
	end;
	return not changed;
end;

function courseplay:getMovingTools(vehicle)
	local primaryMovingTools, secondaryMovingTools;
	local frontLoader, shovel ,pipe = 0, 0;
	for i=1, #(vehicle.attachedImplements) do
		if vehicle.attachedImplements[i].object.cp.hasSpecializationShovel then
			shovel = i;
		elseif courseplay:isFrontloader(vehicle.attachedImplements[i].object) then
			frontLoader = i;
		else
			pipe = i;
		end;
	end;

	courseplay:debug(('%s: getMovingTools(): frontLoader index=%d, shovel index=%d'):format(nameNum(vehicle), frontLoader, shovel), 10);

	if shovel ~= 0 then
		primaryMovingTools = vehicle.movingTools;
		secondaryMovingTools = vehicle.attachedImplements[shovel].object.movingTools;
		vehicle.cp.shovel = vehicle.attachedImplements[shovel].object;

		courseplay:debug(('    [1] primaryMt=%s, secondaryMt=%s, shovel=%s'):format(nameNum(vehicle), nameNum(vehicle.attachedImplements[shovel].object), nameNum(vehicle.cp.shovel)), 10);
	elseif frontLoader ~= 0 then
		local object = vehicle.attachedImplements[frontLoader].object;
		vehicle.cp.attachedFrontLoader = object
		primaryMovingTools = object.movingTools;
		if object.attachedImplements[1] ~= nil then
			secondaryMovingTools = object.attachedImplements[1].object.movingTools;
			vehicle.cp.shovel = object.attachedImplements[1].object;
			courseplay:debug(('    [2] attachedFrontLoader=%s, primaryMt=%s, secondaryMt=%s, shovel=%s'):format(nameNum(object), nameNum(object), nameNum(object.attachedImplements[1].object), nameNum(vehicle.cp.shovel)), 10);
		end;
		
	elseif pipe ~= 0 then
		primaryMovingTools = vehicle.attachedImplements[i].object.movingTools;
	else
		primaryMovingTools = vehicle.movingTools;
		vehicle.cp.shovel = vehicle;

		courseplay:debug(('    [3] primaryMt=%s, shovel=%s'):format(nameNum(vehicle), nameNum(vehicle.cp.shovel)), 10);
	end;

	return primaryMovingTools, secondaryMovingTools;
end;

function courseplay:createBunkerSiloMap(vehicle, Silo,width, height)
	local sx,sz = Silo.bunkerSiloArea.sx,Silo.bunkerSiloArea.sz;
	local wx,wz = Silo.bunkerSiloArea.wx,Silo.bunkerSiloArea.wz;
	local hx,hz = Silo.bunkerSiloArea.hx,Silo.bunkerSiloArea.hz;
	local sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 1, sz);
	local bunkerWidth = courseplay:distance(sx,sz, wx, wz)
	local bunkerLength = courseplay:distance(sx,sz, hx, hz)
	local startDistance = courseplay:distanceToPoint(vehicle, sx, sy, sz)
	local endDistance = courseplay:distanceToPoint(vehicle, hx, sy, hz)
	local widthDirX,widthDirY,widthDirZ,widthDistance = courseplay:getWorldDirection(sx,sy,sz, wx,sy,wz);
	local heightDirX,heightDirY,heightDirZ,heightDistance = courseplay:getWorldDirection(sx,sy,sz, hx,sy,hz);

	local widthCount = math.ceil(bunkerWidth/vehicle.cp.workWidth)
	if vehicle.cp.mode10.leveling and courseplay:isEven(widthCount) then
		widthCount = widthCount+1
	end
	
	local heightCount = math.ceil(bunkerLength/vehicle.cp.workWidth)
	local unitWidth = bunkerWidth/widthCount
	local unitHeigth = bunkerLength/heightCount
	local heightLengthX = (Silo.bunkerSiloArea.hx-Silo.bunkerSiloArea.sx)/heightCount
	local heightLengthZ = (Silo.bunkerSiloArea.hz-Silo.bunkerSiloArea.sz)/heightCount
	local widthLengthX = (Silo.bunkerSiloArea.wx-Silo.bunkerSiloArea.sx)/widthCount
	local widthLengthZ = (Silo.bunkerSiloArea.wz-Silo.bunkerSiloArea.sz)/widthCount
	local getOffTheWall = 0.5;
	
	local lastValidfillType = 0
	local map = {}
	for heightIndex = 1,heightCount do
		map[heightIndex]={}
		for widthIndex = 1,widthCount do
			local newWx = sx + widthLengthX
			local newWz = sz + widthLengthZ
			local newHx = sx + heightLengthX
			local newHz = sz + heightLengthZ
			
			local wY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newWx, 1, newWz); 
			local hY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newHx, 1, newHz);
			local fillType = TipUtil.getFillTypeAtLine(newWx, wY, newWz, newHx, hY, newHz, 5)
			if lastValidfillType ~= fillType and fillType ~= 0 then
				lastValidfillType = fillType
			end
			local newFillLevel = TipUtil.getFillLevelAtArea(fillType, sx, sz, newWx, newWz, newHx, newHz )
			local bx = sx + (widthLengthX/2) + (heightLengthX/2)  
			local bz = sz + (widthLengthZ/2) + (heightLengthZ/2)
			local offset = 0
			if widthIndex == 1 then
				offset = getOffTheWall+ (vehicle.cp.workWidth/2)
			elseif widthIndex == widthCount then
				offset = unitWidth- (getOffTheWall+ (vehicle.cp.workWidth/2))
			else
				offset = unitWidth/2
			end
			local cx,cz = sx +(widthDirX*offset)+(heightLengthX/2),sz +(widthDirZ*offset)+ (heightLengthZ/2)
			local unitArea = unitWidth*unitHeigth
			
			map[heightIndex][widthIndex] ={
										sx = sx;
										sz = sz;
										y = wY;
										wx = newWx;
										wz = newWz;
										hx = newHx;
										hz = newHz;
										cx = cx;
										cz = cz;
										bx = bx;
										bz = bz;
										area = unitArea;
										fillLevel = newFillLevel;
										fillType = fillType;
										bunkerLength = bunkerLength;
										bunkerWidth = bunkerWidth;
											}
											
			sx = map[heightIndex][widthIndex].wx
			sz = map[heightIndex][widthIndex].wz
		end
		sx = map[heightIndex][1].hx
		sz = map[heightIndex][1].hz
	end
	if lastValidfillType > 0 then
		courseplay:debug(('%s: Bunkersilo filled with %s(%i) will be devided in %d lines and %d columns'):format(nameNum(vehicle),FillUtil.fillTypeIndexToDesc[lastValidfillType].name ,lastValidfillType, heightCount, widthCount), 10);   
	else
		courseplay:debug(('%s: empty Bunkersilo will be devided in %d lines and %d columns'):format(nameNum(vehicle), heightCount, widthCount), 10);   
	end
	--invert table
	if endDistance < startDistance then
		courseplay:debug(('%s: Bunkersilo will be approached from the back -> turn map'):format(nameNum(vehicle)), 10);
		local newMap = {}	
		local lineCounter = #map 
		for lineIndex=1,lineCounter do 
			local newLineIndex = lineCounter+1-lineIndex;
			--print(string.format("put line%s into line%s",tostring(lineIndex),tostring(newLineIndex)))
			newMap[newLineIndex]={}
			local columnCount = #map[lineIndex]
			for columnIndex =1, columnCount do
				--print(string.format("  put column%s into column%s",tostring(columnIndex),tostring(columnCount+1-columnIndex)))
				newMap[newLineIndex][columnCount+1-columnIndex] = map[lineIndex][columnIndex]
			end
		end	
		map = newMap
	end
	return map
end

function courseplay:getMode9TargetBunkerSilo(vehicle,forcedPoint)
	local pointIndex = 0
	if forcedPoint then
		 pointIndex = forcedPoint;
	else
		pointIndex = vehicle.cp.shovelFillStartPoint+1
	end
	local x,z = vehicle.Waypoints[pointIndex].cx,vehicle.Waypoints[pointIndex].cz			
	local tx,tz = x,z + 0.50
	if g_currentMission.bunkerSilos ~= nil then
		for _, bunker in pairs(g_currentMission.bunkerSilos) do
			local x1,z1 = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local x2,z2 = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local x3,z3 = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			if Utils.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z) then
				return bunker
			end
		end
	else
		return false
	end
	return false
end