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

function courseplay:handle_mode9(vehicle, fillLevelPct, allowedToDrive, dt)
	--state 1: goto BunkerSilo
	--state 2: get ready to load / loading
	--state 3: transport to BGA
	--state 4: get ready to unload
	--state 5: unload
	--state 6: leave BGA
	--state 7: wait for Trailer 10 before EmptyPoint

	if vehicle.cp.tipperCapacity == nil or vehicle.cp.tipperCapacity == 0 then --NOTE: query here instead of getCanUseAiMode() as tipperCapacity doesn't exist until drive() has been run
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
			if fillLevelPct == 100 then
				vehicle.cp.shovel:setFillLevel(vehicle.cp.shovel.capacity * 0.99, vehicle.cp.shovel.currentFillType);
			end;
		end;


	-- STATE 2: PREPARE LOADING
	elseif vehicle.cp.shovelState == 2 then

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

		if fillLevelPct == 100 or vehicle.cp.isLoaded then
			if not vehicle.cp.isLoaded then
				for i=vehicle.cp.waypointIndex, vehicle.cp.numWaypoints do
					local _,ty,_ = getWorldTranslation(vehicle.cp.DirectionNode);
					local _,_,z = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[i].cx , ty , vehicle.Waypoints[i].cz);
					if z < -3 and vehicle.Waypoints[i].rev  then
						--print("z taken:  "..tostring(z));
						courseplay:setWaypointIndex(vehicle, i + 1);
						courseplay:setIsLoaded(vehicle, true);
						break;
					end;
				end;
			else
				if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[3], dt) then
					courseplay:setShovelState(vehicle, 3);
				else
					allowedToDrive = false;
				end;
			end;
		end;

	-- STATE 3: TRANSPORT TO BGA
	elseif vehicle.cp.shovelState == 3 then
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
		local stopUnloading = vehicle.cp.shovel.trailerFound ~= nil and vehicle.cp.shovel.trailerFound.fillLevel >= vehicle.cp.shovel.trailerFound.capacity;
		if fillLevelPct <= 1 or stopUnloading then
			if vehicle.cp.isLoaded then
				for i = vehicle.cp.waypointIndex,vehicle.cp.numWaypoints do
					if vehicle.Waypoints[i].rev then
						courseplay:setIsLoaded(vehicle, false);
						courseplay:setWaypointIndex(vehicle, i);
						break;
					end;
				end;
			end;

			if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[4], dt) then
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
			courseplay:setShovelState(vehicle, 1);
		end;
	end;

	return allowedToDrive;
end;

function courseplay:setShovelState(vehicle, state, extraText)
	vehicle.cp.shovelState = state;
	if courseplay.debugChannels[10] then
		if extraText then
			courseplay:debug(('%s: set shovel state to %d (%s)'):format(nameNum(vehicle), state, extraText), 10);
		else
			courseplay:debug(('%s: set shovel state to %d'):format(nameNum(vehicle), state), 10);
		end;
	end;
end;

function courseplay:getCurrentMovingToolsPosition(vehicle, movingTools, secondary) --NOTE: still needed for saveShovelPosition()
	if movingTools == nil then
		print(nameNum(vehicle) .. ': courseplay:getCurrentMovingToolsPosition() return nil');
		return nil;
	end;

	local rotAxis, transAxis = 1, 3; -- 1 = x, 3 = z;
	local curRot, curTrans = {}, {};
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

	return curRot, curTrans;
end;

function courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, secondaryMovingTools, targetPositions, dt)
	local targetRotations, targetTranslations = targetPositions.rot, targetPositions.trans;
	local changed = false;
	local numPrimaryMovingTools = #movingTools;
	local rotAxis, transAxis = 1, 3; -- 1 = x, 3 = z;

	for i=1,#targetRotations do
		local mt, mtMainObject;
		if i <= numPrimaryMovingTools then
			mt = movingTools[i];
			mtMainObject = vehicle;
		else
			mt = secondaryMovingTools[i - numPrimaryMovingTools];
			mtMainObject = vehicle.cp.shovel;
		end;

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
					courseplay:debug(string.format('%s: movingTool %d: curRot=%.5f, targetRot=%.5f -> newRot=%.5f', nameNum(vehicle), i, curRot, targetRot, newRot), 10);
					mt.curRot[rotAxis] = newRot;
					setRotation(mt.node, unpack(mt.curRot));
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
						courseplay:debug(string.format('%s: movingTool %d: curTrans=%.5f, targetTrans=%.5f -> newTrans=%.5f', nameNum(vehicle), i, curTrans, targetTrans, newTrans), 10);
						mt.curTrans[transAxis] = newTrans;
						setTranslation(mt.node, unpack(mt.curTrans));
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
	local frontLoader, shovel = 0, 0;
	for i=1, #(vehicle.attachedImplements) do
		if vehicle.attachedImplements[i].object.cp.hasSpecializationShovel then
			shovel = i;
		elseif courseplay:isFrontloader(vehicle.attachedImplements[i].object) then
			frontLoader = i;
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
		end;

		courseplay:debug(('    [2] attachedFrontLoader=%s, primaryMt=%s, secondaryMt=%s, shovel=%s'):format(nameNum(object), nameNum(object), nameNum(object.attachedImplements[1].object), nameNum(vehicle.cp.shovel)), 10);
	else
		primaryMovingTools = vehicle.movingTools;
		vehicle.cp.shovel = vehicle;

		courseplay:debug(('    [3] primaryMt=%s, shovel=%s'):format(nameNum(vehicle), nameNum(vehicle.cp.shovel)), 10);
	end;

	return primaryMovingTools, secondaryMovingTools;
end;
