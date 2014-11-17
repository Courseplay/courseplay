local abs, ceil = math.abs, math.ceil;

function courseplay:handleMode7(vehicle, cx, cy, cz, refSpeed, allowedToDrive)
	-- backup protection
	if vehicle.attachedCutters == nil then
		--TODO local text "wrong worktool for this mode"
		return false
	end
	
	local pipeState = vehicle:getOverloadingTrailerInRangePipeState();
	if pipeState > 0 then
		vehicle:setPipeState(pipeState);
	else
		vehicle:setPipeState(1);
	end;
	
	if (vehicle.recordnumber == vehicle.maxnumber and vehicle.cp.modeState ~= 5) or (vehicle.cp.mode7GoBackBeforeUnloading and vehicle.cp.modeState ~= 5) then 
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
	if vehicle.isAIThreshing then
		if (vehicle.fillLevel * 100 / vehicle.capacity) >= vehicle.cp.driveOnAtFillLevel then
			local cx7, cz7 = vehicle.Waypoints[vehicle.maxnumber].cx, vehicle.Waypoints[vehicle.maxnumber].cz;
			local lx7, lz7 = AIVehicleUtil.getDriveDirection(vehicle.rootNode, cx7, cty7, cz7);
			local x7,y7,z7 = localToWorld(vehicle.rootNode, 0, 0, -15);
			vehicle.cp.mode7t = {};
			vehicle.cp.mode7t.x = x7;
			vehicle.cp.mode7t.y = y7;
			vehicle.cp.mode7t.z = z7;
			local fx,fy,fz = 0,0,0;
			local isField = true;
			for i = 0.5, 3 do
				fx,fy,fz = localToWorld(vehicle.rootNode, 0, 0, -i*vehicle.cp.turnRadius);
				if not courseplay:isField(fx, fz) then
					isField = false;
					break;
				end					
			end
			if isField or vehicle.fillLevel >= vehicle.capacity*0.99 then
				vehicle.lastaiThreshingDirectionX = vehicle.aiThreshingDirectionX;
				vehicle.lastaiThreshingDirectionZ = vehicle.aiThreshingDirectionZ;
				vehicle:stopAIThreshing();
				vehicle.cp.shortestDistToWp = nil;
				vehicle.cp.nextTargets = {};
				local sideOffset = math.max(0.34*3*vehicle.cp.turnRadius,vehicle.cp.workWidth);
				courseplay:debug(nameNum(vehicle) .. ": sideOffset = "..tostring(sideOffset), 11);
				if lx7 < 0 then
					courseplay:debug(nameNum(vehicle) .. ": approach from right", 11);
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.rootNode, -sideOffset , 0, -3*vehicle.cp.turnRadius);
					courseplay:addNewTargetVector(vehicle, sideOffset , 0);
					courseplay:addNewTargetVector(vehicle, 0 , 3.5);
				else
					courseplay:debug(nameNum(vehicle) .. ": approach from left", 11);
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.rootNode, sideOffset , 0, -3*vehicle.cp.turnRadius);
					courseplay:addNewTargetVector(vehicle, -sideOffset , 0);
					courseplay:addNewTargetVector(vehicle, 0 ,3.5);
				end
				vehicle.cp.mode7Unloading = true;
				vehicle.cp.mode7GoBackBeforeUnloading = true;
				courseplay:start(vehicle);
			else
				if courseplay.debugChannels[11] then
					local dbgctx7, dbgcty7, dbgctz7 = getWorldTranslation(vehicle.rootNode);
					local dbgcx, _, dbgcz = localToWorld(vehicle.rootNode, 0 , 0, -3*vehicle.cp.turnRadius);
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
			local dist = courseplay:distanceToPoint(vehicle, vehicle.cp.mode7t.x,vehicle.cp.mode7t.y,vehicle.cp.mode7t.z);
			if dist < 1 then
				vehicle.cp.mode7GoBackBeforeUnloading = false;
				courseplay:setRecordNumber(vehicle, 2);
				courseplay:setModeState(vehicle, 0);
				courseplay:debug(nameNum(vehicle) .. ": " .. tostring(debug.getinfo(1).currentline) .. ": modeState = 0", 11);
			end
		end
	--finished work
	else
		allowedToDrive = false
		courseplay:setGlobalInfoText(vehicle, 'WORK_END');
	end
	--go to course
	if vehicle.cp.modeState == 0 then
		if vehicle.recordnumber ==2 then
			refSpeed = vehicle.cp.speeds.field;
		else
			refSpeed = vehicle.cp.speeds.street;
		end
	--follow waypoints
	elseif vehicle.cp.modeState == 5 then
		local targets = #(vehicle.cp.nextTargets);
		local aligned = false;
		local ctx7, cty7, ctz7 = getWorldTranslation(vehicle.rootNode);
		vehicle.cp.infoText = string.format(courseplay:loc("COURSEPLAY_DRIVE_TO_WAYPOINT"), vehicle.cp.curTarget.x, vehicle.cp.curTarget.z);
		if vehicle.cp.mode7GoBackBeforeUnloading then
			cx = vehicle.cp.mode7t.x;
			cy = vehicle.cp.mode7t.y;
			cz = vehicle.cp.mode7t.z;
		else
			cx = vehicle.cp.curTarget.x;
			cy = vehicle.cp.curTarget.y;
			cz = vehicle.cp.curTarget.z;
		end
		if courseplay.debugChannels[11] then
			drawDebugPoint(cx, cy+3, cz, 0, 1 , 1, 1);
			drawDebugLine(cx, cty7+3, cz, 1, 0, 0, ctx7, cty7+3, ctz7, 1, 0, 0); 
		end;
		if not vehicle.cp.mode7GoBackBeforeUnloading then
			vehicle.cp.speeds.sl = 3;
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
				if distance_to_wp < 15 and not isAutoCombine then
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
					vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);	-- TODO (Tom) tricky temporary solution
					vehicle.cruiseControl.minSpeed = 1;	-- TODO (Tom) tricky temporary solution			 	
					vehicle:startAIThreshing(true);
					vehicle.cp.mode7Unloading = false;
					courseplay:debug(nameNum(vehicle) .. ": start AITreshing", 11);
					courseplay:debug(nameNum(vehicle) .. ": fault: "..tostring(ceil(abs(ctx7-vehicle.cp.curTargetMode7.x)*100)).." cm ", 11);
				end
			end
		end
	end

	return true, cx, cy, cz, refSpeed, allowedToDrive;
end;

