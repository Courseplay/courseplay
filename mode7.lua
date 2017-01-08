local abs, ceil = math.abs, math.ceil;

function courseplay:handleMode7(vehicle, cx, cy, cz, refSpeed, allowedToDrive)
	-- backup protection
	if vehicle.attachedCutters == nil then
		--TODO local text "wrong worktool for this mode"
		return false
	end
	
	local pipeState = courseplay:getTrailerInPipeRangeState(vehicle);
	if not vehicle.cp.mode7makeHeaps then
		if pipeState > 0 then
			vehicle:setPipeState(pipeState);
		elseif not vehicle.aiIsStarted then
			vehicle:setPipeState(1);
		end;
	end
	if (vehicle.cp.waypointIndex == vehicle.cp.numWaypoints and vehicle.cp.modeState ~= 5) or (vehicle.cp.mode7GoBackBeforeUnloading and vehicle.cp.modeState ~= 5) then 
		if vehicle.cp.curTarget.x ~= nil then
			courseplay:setModeState(vehicle, 5);
			courseplay:debug(nameNum(vehicle) .. ": " .. tostring(debug.getinfo(1).currentline) .. ": modeState = 5", 11);
		else
			allowedToDrive = false;
			--TODO local text "no aithreshing"
		end
	end
	-- AutoCombine
	local isAutoCombine = false;
	if vehicle.acParameters ~= nil and vehicle.acParameters.enabled then
		isAutoCombine = true;
	end
	-- wait untill fillLevel is reached	
	if vehicle.aiIsStarted then
		if vehicle.cp.totalFillLevelPercent >= vehicle.cp.driveOnAtFillLevel then
			local cx7, cz7 = vehicle.Waypoints[vehicle.cp.numWaypoints].cx, vehicle.Waypoints[vehicle.cp.numWaypoints].cz;
			local cty7 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx7,1, cz7)
			local lx7, lz7 = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, cx7, cty7, cz7);
			local x7,y7,z7 = localToWorld(vehicle.cp.DirectionNode, 0, 0, -30);
			local x7d,y7d,z7d = localToWorld(vehicle.cp.DirectionNode, 0, 0, -15);
			vehicle.cp.mode7t = {};
			vehicle.cp.mode7t.x = x7;
			vehicle.cp.mode7t.y = y7;
			vehicle.cp.mode7t.z = z7;
			vehicle.cp.mode7d = {};
			vehicle.cp.mode7d.x = x7d;
			vehicle.cp.mode7d.y = y7d;
			vehicle.cp.mode7d.z = z7d;
			local fx,fy,fz = 0,0,0;
			local isField = true;
			for i = 0.5, 3 do
				fx,fy,fz = localToWorld(vehicle.cp.DirectionNode, 0, 0, -i*vehicle.cp.turnDiameter);
				if not courseplay:isField(fx, fz) then
					isField = false;
					break;
				end					
			end
			if isField or vehicle.cp.totalFillLevelPercent > 99 then
				local dx, _, dz = localDirectionToWorld(vehicle.cp.DirectionNode, 0, 0, 1)
				local length = Utils.vector2Length(dx, dz)
                vehicle.lastaiThreshingDirectionX = dx / length;
				vehicle.lastaiThreshingDirectionZ = dz / length;
				vehicle:stopAIVehicle();
				if vehicle.cp.hasDriveControl and vehicle.cp.driveControl.hasManualMotorStart then
					vehicle.driveControl.manMotorStart.wasHired = false
				end				
				vehicle.cp.shortestDistToWp = nil;
				vehicle.cp.nextTargets = {};
				local sideOffset = math.max(0.34*3*vehicle.cp.turnDiameter,vehicle.cp.workWidth);
				courseplay:debug(nameNum(vehicle) .. ": sideOffset = "..tostring(sideOffset), 11);
				if lx7 < 0 then
					courseplay:debug(nameNum(vehicle) .. ": approach from right", 11);
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, -sideOffset , 0, -3*vehicle.cp.turnDiameter);
					courseplay:addNewTargetVector(vehicle, sideOffset , 0);
					courseplay:addNewTargetVector(vehicle, 0 , 3.5);
				else
					courseplay:debug(nameNum(vehicle) .. ": approach from left", 11);
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, sideOffset , 0, -3*vehicle.cp.turnDiameter);
					courseplay:addNewTargetVector(vehicle, -sideOffset , 0);
					courseplay:addNewTargetVector(vehicle, 0 ,3.5);
				end
				vehicle.cp.mode7Unloading = true;
				vehicle.cp.mode7GoBackBeforeUnloading = true;
				vehicle.cp.mode7SpeedBackup = vehicle.cruiseControl.maxSpeed
				courseplay:start(vehicle);
				courseplay:setWaypointIndex(vehicle, 1);
			else
				if courseplay.debugChannels[11] then
					local dbgctx7, dbgcty7, dbgctz7 = getWorldTranslation(vehicle.cp.DirectionNode);
					local dbgcx, _, dbgcz = localToWorld(vehicle.cp.DirectionNode, 0 , 0, -3*vehicle.cp.turnDiameter);
					drawDebugLine(dbgctx7, dbgcty7+3, dbgctz7, 1, 1, 1, dbgcx, dbgcty7+3, dbgcz, 1, 1, 1);
				end					
				return false;
			end
		else
			return false;
		end
	-- go back for 15m
	elseif vehicle.cp.mode7Unloading then
		refSpeed = vehicle.cp.speeds.field;
		if vehicle.cp.mode7GoBackBeforeUnloading then
			refSpeed = vehicle.cp.speeds.turn;
			local dist = courseplay:distanceToPoint(vehicle, vehicle.cp.mode7d.x,vehicle.cp.mode7d.y,vehicle.cp.mode7d.z);
			if dist < 1 then
				vehicle.cp.mode7GoBackBeforeUnloading = false;
				courseplay:setWaypointIndex(vehicle, 2);
				courseplay:setModeState(vehicle, 0);
				courseplay:debug(nameNum(vehicle) .. ": " .. tostring(debug.getinfo(1).currentline) .. ": modeState = 0", 11);
			end
		end
	--finished work
	else
		allowedToDrive = false
		CpManager:setGlobalInfoText(vehicle, 'WORK_END');
	end
	--go to course
	local continue = true
	if vehicle.cp.modeState == 0 then
		if vehicle.cp.waypointIndex ==2 then
			refSpeed = vehicle.cp.speeds.field;
		else
			refSpeed = vehicle.cp.speeds.street;
		end
	--follow waypoints
	elseif vehicle.cp.modeState == 5 then
		local targets = #(vehicle.cp.nextTargets);
		local aligned = false;
		local ctx7, cty7, ctz7 = getWorldTranslation(vehicle.cp.DirectionNode);
		if vehicle.cp.mode7GoBackBeforeUnloading then
			cx = vehicle.cp.mode7t.x;
			cy = vehicle.cp.mode7t.y;
			cz = vehicle.cp.mode7t.z;
		else
			cx = vehicle.cp.curTarget.x;
			cy = vehicle.cp.curTarget.y;
			cz = vehicle.cp.curTarget.z;
		end
		courseplay:setInfoText(vehicle, string.format("COURSEPLAY_DRIVE_TO_WAYPOINT;%d;%d",cx,cz));
		if courseplay.debugChannels[11] then
			drawDebugPoint(cx, cy+3, cz, 0, 1 , 1, 1);
			drawDebugLine(cx, cty7+3, cz, 1, 0, 0, ctx7, cty7+3, ctz7, 1, 0, 0); 
		end;
		if not vehicle.cp.mode7GoBackBeforeUnloading then
			refSpeed = vehicle.cp.speeds.field;
			local distance_to_wp = courseplay:distanceToPoint(vehicle, cx, cy, cz);
			local distToChange = 4;
			if vehicle.cp.shortestDistToWp == nil or vehicle.cp.shortestDistToWp > distance_to_wp then
				vehicle.cp.shortestDistToWp = distance_to_wp;
			end
			if distance_to_wp > vehicle.cp.shortestDistToWp and distance_to_wp < 6 then
				distToChange = distance_to_wp + 1;
			end
			if targets == 2 then 
				vehicle.cp.curTargetMode7 = vehicle.cp.nextTargets[2];
				if distance_to_wp < 25 then
					refSpeed = vehicle.cp.speeds.turn;
				end
			elseif targets == 1 then
				if isAutoCombine then
					aligned = true;
					courseplay:debug(nameNum(vehicle) .. ": AC aligned", 11);
				end
				if abs(vehicle.lastaiThreshingDirectionZ) > 0.1 then
					if abs(vehicle.cp.curTargetMode7.x-ctx7)< 3 then
						aligned = true;
						courseplay:debug(nameNum(vehicle) .. ": aligned", 11);
					end
				else
					if abs(vehicle.cp.curTargetMode7.z-ctz7)< 3 then
						aligned = true;
						courseplay:debug(nameNum(vehicle) .. ": aligned", 11);
					end
				end
				
				refSpeed = vehicle.cp.speeds.turn;
				
			elseif targets == 0 then
				refSpeed = vehicle.cp.speeds.turn;
				if distance_to_wp < 10 and not isAutoCombine then
					vehicle:setIsTurnedOn(true);
				end
			end
			if distance_to_wp < distToChange or aligned then
				vehicle.cp.shortestDistToWp = nil;
				if targets > 0 then
					courseplay:setCurrentTargetFromList(vehicle, 1);
					courseplay:debug(nameNum(vehicle) .. ": set next Target from List", 11);
				else
					courseplay:setModeState(vehicle, 0);
					courseplay:debug(nameNum(vehicle) .. ": " .. tostring(debug.getinfo(1).currentline) .. ": modeState = 0", 11);
					if vehicle.lastaiThreshingDirectionX ~= nil then
						vehicle.aiThreshingDirectionX = vehicle.lastaiThreshingDirectionX;
						vehicle.aiThreshingDirectionZ = vehicle.lastaiThreshingDirectionZ;
						courseplay:debug(nameNum(vehicle) .. ": restored vehicle.aiThreshingDirection", 11);
					end
					vehicle:startAIVehicle();
					vehicle:setCruiseControlMaxSpeed(vehicle.cp.mode7SpeedBackup)
					continue = false
					vehicle.cp.mode7Unloading = false;
					courseplay:debug(nameNum(vehicle) .. ": start AITreshing", 11);
					courseplay:debug(nameNum(vehicle) .. ": fault: "..tostring(ceil(abs(ctx7-vehicle.cp.curTargetMode7.x)*100)).." cm X  "..tostring(ceil(abs(ctz7-vehicle.cp.curTargetMode7.z)*100)).." cm Z", 11);
				end
			end
		end
	end

	return continue, cx, cy, cz, refSpeed, allowedToDrive;
end;

function courseplay:getDischargeSpeed(vehicle)
	courseplay:debug(nameNum(vehicle) .. ":getDischargeSpeed()", 11);
	local refSpeed = 0
	local sx,sz = vehicle.Waypoints[vehicle.cp.startWork].cx, vehicle.Waypoints[vehicle.cp.startWork].cz; 
	local ex,ez = vehicle.Waypoints[vehicle.cp.stopWork].cx, vehicle.Waypoints[vehicle.cp.stopWork].cz;
	local length = courseplay:distance(sx,sz, ex,ez) -5  --just to be sure, that we will get all in...
	local fillDelta = vehicle.cp.totalFillLevel / vehicle.cp.totalCapacity;
	courseplay:debug(nameNum(vehicle) .. ":  TipRange length: "..tostring(length), 11);
	local completeTipDuration = (vehicle.cp.totalFillLevel/vehicle.overloading.capacity)+ (vehicle.overloading.delay.time/1000) 
	courseplay:debug(nameNum(vehicle) .. ":  complete tip duration: "..tostring(completeTipDuration), 11);
	local meterPrSeconds = length / completeTipDuration;
	refSpeed =  meterPrSeconds * 3.6 
	courseplay:debug(nameNum(vehicle) .. ":  refSpeed: "..tostring(refSpeed), 11);
	return refSpeed
end
