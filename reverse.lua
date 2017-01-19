local abs, max, rad, sin = math.abs, math.max, math.rad, math.sin;

function courseplay:goReverse(vehicle,lx,lz)
	local fwd = false;
	local workTool = courseplay:getFirstReversingWheeledWorkTool(vehicle) or vehicle.cp.workTools[1];
	local newTarget;
	if vehicle.cp.turnTargets and vehicle.cp.curTurnIndex then
		newTarget = vehicle.cp.turnTargets[vehicle.cp.curTurnIndex];
	end;

	if workTool then
		-- Attacher modules and HookLift modules that needs the hookLiftTrailer
		if courseplay:isHookLift(workTool) or courseplay:isAttacherModule(workTool) then
			workTool = workTool.attacherVehicle;

			if workTool == vehicle then
			workTool = vehicle.cp.workTools[2];
				if courseplay:isAttacherModule(workTool) then
					workTool = workTool.attacherVehicle;
				end;
			end;
		end;
	end;
	local debugActive = courseplay.debugChannels[13];
	local isNotValid = vehicle.cp.numWorkTools == 0 or workTool == nil or workTool.cp.isPivot == nil or not workTool.cp.frontNode or vehicle.cp.mode == 9;
	if isNotValid then
		if newTarget then
			-- If we have the revPosX, revPosZ set, use those
			if newTarget.revPosX and newTarget.revPosZ then
				local _, vehicleY, _ = getWorldTranslation(vehicle.cp.DirectionNode);
				lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, newTarget.revPosX, vehicleY, newTarget.revPosZ);
			end;
		elseif not vehicle.cp.mode == 9 then
			-- Start: Fixes issue #525
			local tx, ty, tz = localToWorld(vehicle.cp.DirectionNode, 0, 1, -3);
			local nx, ny, nz = localDirectionToWorld(vehicle.cp.DirectionNode, lx, 0, lz);
			courseplay:doTriggerRaycasts(vehicle, 'tipTrigger', 'rev', false, tx, ty, tz, nx, ny, nz);
			--  End:  Fixes issue #525
		end
		return -lx,-lz,fwd;
	end;

	local node = workTool.cp.realTurningNode;
	local isPivot = workTool.cp.isPivot;
	local xTipper,yTipper,zTipper = getWorldTranslation(node);
	if debugActive then drawDebugPoint(xTipper, yTipper+5, zTipper, 1, 0 , 0, 1) end;
	local frontNode = workTool.cp.frontNode;
	local xFrontNode,yFrontNode,zFrontNode = getWorldTranslation(frontNode);
	local tcx,tcy,tcz =0,0,0;
	local index = vehicle.cp.waypointIndex + 1;
	if debugActive and not newTarget then
		drawDebugPoint(xFrontNode,yFrontNode+3,zFrontNode, 1, 0 , 0, 1);
		if not vehicle.cp.checkReverseValdityPrinted then
			local checkValdity = false;
			for i=index, vehicle.cp.numWaypoints do
				if vehicle.Waypoints[i].rev then
					tcx = vehicle.Waypoints[i].cx;
					tcz = vehicle.Waypoints[i].cz;
					local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
					if z < 0 then
						checkValdity = true;
						break;
					end;
				else
					break;
				end;
			end;
			if not checkValdity then
				print(nameNum(vehicle) ..": reverse course is not valid");
			end;
			vehicle.cp.checkReverseValdityPrinted = true;
		end;
	end;

	if newTarget then
		if newTarget.revPosX and newTarget.revPosZ then
			tcx = newTarget.revPosX;
			tcz = newTarget.revPosZ;
		else
			tcx = newTarget.posX;
			tcz = newTarget.posZ;
		end;
	else
		for i= index, vehicle.cp.numWaypoints do
			if vehicle.Waypoints[i].rev and not vehicle.Waypoints[i-1].wait then
				tcx = vehicle.Waypoints[i].cx;
				tcz = vehicle.Waypoints[i].cz;
			else
				local dx, dz, _ = courseplay.generation:getPointDirection(vehicle.Waypoints[i-2], vehicle.Waypoints[i-1]);
				tcx = vehicle.Waypoints[i-1].cx + dx * (vehicle.Waypoints[i-1].wait and 15 or 30);
				tcz = vehicle.Waypoints[i-1].cz + dz * (vehicle.Waypoints[i-1].wait and 15 or 30);
			end;
			local distance = courseplay:distance(xTipper,zTipper, vehicle.Waypoints[i-1].cx ,vehicle.Waypoints[i-1].cz);

			local waitingPoint;
			local unloadPoint;
			if vehicle.Waypoints[i-1].wait then 
				waitingPoint = i-1;	
			end;
			if vehicle.Waypoints[i].wait then
				waitingPoint = i;
			end;
			if vehicle.Waypoints[i-1].unload then 
				unloadPoint = i-1;	
			end;
			if vehicle.Waypoints[i].unload then
				unloadPoint = i;
			end;
			
			
			
			-- HANDLE WAITING POINT WAYPOINT CHANGE
			if waitingPoint then
				if workTool.cp.realUnloadOrFillNode then
					local _,y,_ = getWorldTranslation(workTool.cp.realUnloadOrFillNode);
					local _,_,z = worldToLocal(workTool.cp.realUnloadOrFillNode, vehicle.Waypoints[waitingPoint].cx, y, vehicle.Waypoints[waitingPoint].cz);
					if z >= 0 then
						courseplay:setWaypointIndex(vehicle, waitingPoint + 1);
						courseplay:debug(string.format("%s: Is at waiting point", nameNum(vehicle)), 13);
						break;
					end;
				else
					if distance <= 2 then
						courseplay:setWaypointIndex(vehicle, waitingPoint + 1);
						courseplay:debug(string.format("%s: Is at waiting point", nameNum(vehicle)), 13);
						break;
					end;
				end;

				if distance > 3 then
					local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
					if z < 0 then
						courseplay:setWaypointIndex(vehicle, i - 1);
						break;
					end;
				end;

				break;
			elseif unloadPoint then
				if workTool.cp.rearTipRefPoint then
					local tipRefPoint = workTool.tipReferencePoints[workTool.cp.rearTipRefPoint].node
					local x,y,z = getWorldTranslation(tipRefPoint);
					local tipDistanceToPoint = courseplay:distance(x,z,vehicle.Waypoints[unloadPoint].cx,vehicle.Waypoints[unloadPoint].cz)
					courseplay:debug(string.format("%s:workTool.cp.rearTipRefPoint: tipDistanceToPoint: %s", nameNum(vehicle),tostring(tipDistanceToPoint)), 13);
					if tipDistanceToPoint  < 0.5 then
						courseplay:setWaypointIndex(vehicle, unloadPoint + 1);
						courseplay:debug(string.format("%s: Is at unload point", nameNum(vehicle)), 13);
						break;
					end;		
				end
				if distance > 3 then
					local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
					if z < 0 then
						courseplay:setWaypointIndex(vehicle, i - 1);
						break;
					end;
				end;
				break
			-- HANDLE LAST REVERSE WAYPOINT CHANGE
			elseif vehicle.Waypoints[i-1].rev and not vehicle.Waypoints[i].rev then
				if distance <= 2 then
					courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
					courseplay:debug(string.format("%s: Change direction to forward", nameNum(vehicle)), 13);
				end;
				break;

			-- FIND THE RIGHT START REVERSING WAYPOINT
			elseif vehicle.Waypoints[i-1].rev and not vehicle.Waypoints[i-2].rev then
				for recNum = index, vehicle.cp.numWaypoints do
					local srX,srZ = vehicle.Waypoints[recNum].cx,vehicle.Waypoints[recNum].cz;
					local _,_,tsrZ = worldToLocal(node,srX,yTipper,srZ);
					if tsrZ < -2 then
						courseplay:setWaypointIndex(vehicle, recNum);
						courseplay:debug(string.format("%s: First reverse point -> Change waypoint to behind trailer: %q", nameNum(vehicle), recNum), 13);
						break;
					end;
				end;
				break;

			-- HANDLE REVERSE WAYPOINT CHANGE
			elseif distance > 3 then
				local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
				if z < 0 then
					courseplay:setWaypointIndex(vehicle, i - 1);
					break;
				end;
			end;
		end;
	end;

	if debugActive then
		drawDebugPoint(tcx, yTipper+3, tcz, 1, 1 , 1, 1)
		if workTool.cp.realUnloadOrFillNode then
			local xUOFNode,yUOFNode,zUOFNode = getWorldTranslation(workTool.cp.realUnloadOrFillNode);
			drawDebugPoint(xUOFNode,yUOFNode+5,zUOFNode, 0, 1 , 0.5, 1);
		end;
	end;

	local lxTipper, lzTipper = AIVehicleUtil.getDriveDirection(node, tcx, yTipper, tcz);

	courseplay:showDirection(node,lxTipper, lzTipper);

	local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(frontNode, xTipper,yTipper,zTipper);

	local lxTractor, lzTractor = 0,0;

	local maxTractorAngle = rad(60);

	if isPivot then
		courseplay:showDirection(frontNode,lxFrontNode, lzFrontNode);
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, xFrontNode,yFrontNode,zFrontNode);
		courseplay:showDirection(vehicle.cp.DirectionNode,lxTractor, lzTractor);

		local rotDelta = (workTool.cp.nodeDistance * (0.5 - (0.023 * workTool.cp.nodeDistance - 0.073)));
		local trailerToWaypointAngle = courseplay:getLocalYRotationToPoint(node, tcx, yTipper, tcz, -1) * rotDelta;
		trailerToWaypointAngle = Utils.clamp(trailerToWaypointAngle, -rad(90), rad(90));

		local dollyToTrailerAngle = courseplay:getLocalYRotationToPoint(frontNode, xTipper, yTipper, zTipper, -1);

		local tractorToDollyAngle = courseplay:getLocalYRotationToPoint(vehicle.cp.DirectionNode, xFrontNode, yFrontNode, zFrontNode, -1);

		local rearAngleDiff	= (dollyToTrailerAngle - trailerToWaypointAngle);
		rearAngleDiff = Utils.clamp(rearAngleDiff, -rad(45), rad(45));

		local frontAngleDiff = (tractorToDollyAngle - dollyToTrailerAngle);
		frontAngleDiff = Utils.clamp(frontAngleDiff, -rad(45), rad(45));

		local angleDiff = (frontAngleDiff - rearAngleDiff) * (1.5 - (workTool.cp.nodeDistance * 0.4 - 0.9) + rotDelta);
		angleDiff = Utils.clamp(angleDiff, -rad(45), rad(45));

		lx, lz = Utils.getDirectionFromYRotation(angleDiff);
	else
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, xTipper,yTipper,zTipper);
		courseplay:showDirection(vehicle.cp.DirectionNode,lxTractor, lzTractor);

		local rotDelta = workTool.cp.nodeDistance * 0.3;
		local trailerToWaypointAngle = courseplay:getLocalYRotationToPoint(node, tcx, yTipper, tcz, -1) * rotDelta;
		trailerToWaypointAngle = Utils.clamp(trailerToWaypointAngle, -math.rad(90), math.rad(90));
		local tractorToTrailerAngle = courseplay:getLocalYRotationToPoint(vehicle.cp.DirectionNode, xTipper, yTipper, zTipper, -1);

		local angleDiff = (tractorToTrailerAngle - trailerToWaypointAngle) * (1 + rotDelta);

		-- If we only have stearing axle on the worktool and they turn when reversing, we need to stear allot more to counter this.
		if workTool.cp.steeringAxleUpdateBackwards then
			angleDiff = angleDiff * 4;
		end;

		angleDiff = Utils.clamp(angleDiff, -maxTractorAngle, maxTractorAngle);

		lx, lz = Utils.getDirectionFromYRotation(angleDiff);
	end;

	if (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_FIELDWORK) and vehicle.cp.currentTipTrigger == nil and (vehicle.cp.totalFillLevel ~= nil and vehicle.cp.totalFillLevel > 0) then
		local nx, ny, nz = localDirectionToWorld(node, lxTipper, 0, lzTipper);
		courseplay:doTriggerRaycasts(vehicle, 'tipTrigger', 'rev', false, xTipper, yTipper + 1, zTipper, nx, ny, nz);
	end;
	courseplay:showDirection(vehicle.cp.DirectionNode,lx,lz);

	return lx,lz,fwd;
end;

function courseplay:getFirstReversingWheeledWorkTool(vehicle)
	-- Checl all attached implements if we are an wheeled workTool behind the tractor
	for _, imp in ipairs(vehicle.attachedImplements) do
		-- Check if the implement is behind
		if courseplay:isRearAttached(vehicle, imp.jointDescIndex) then
			if courseplay:isWheeledWorkTool(imp.object) then
				-- If the implement is a wheeled workTool, then return the object
				return imp.object;
			else
				-- If the implement is not a wheeled workTool, then check if that implement have an attached wheeled workTool and return that.
				return courseplay:getFirstReversingWheeledWorkTool(imp.object);
			end;
		end;
	end;

	-- If we didnt find any workTool, return nil
	return nil;
end;

function courseplay:getLocalYRotationToPoint(node, x, y, z, direction)
	direction = direction or 1;
	local dx, _, dz = worldToLocal(node, x, y, z);
	dx = dx * direction;
	dz = dz * direction;
	return Utils.getYRotationFromDirection(dx, dz);
end;

function courseplay:showDirection(node,lx,lz)
	if courseplay.debugChannels[13] then
		local x,y,z = getWorldTranslation(node);
		local ctx,_,ctz = localToWorld(node,lx*5,y,lz*5);
		drawDebugLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz, 1, 0, 0);
	end
end

-- Find the first forward waypoint ahead of the vehicle
function courseplay:getNextFwdPoint(vehicle, isTurning)
	if isTurning then
		courseplay:debug(('%s: getNextFwdPoint()'):format(nameNum(vehicle)), 14);
		for i = vehicle.cp.waypointIndex, vehicle.cp.numWaypoints do
			if vehicle.cp.abortWork and vehicle.cp.abortWork == i then
				vehicle.cp.abortWork = nil;
			end;
			if not vehicle.Waypoints[i].rev then
				local wpX, wpZ = vehicle.Waypoints[i].cx, vehicle.Waypoints[i].cz;
				local _, _, disZ = worldToLocal(vehicle.cp.DirectionNode, wpX, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wpX, 300, wpZ), wpZ);

				if disZ > 3 then
					courseplay:debug(('--> return (%d) as waypointIndex'):format(i), 14);
					return i;
				end;
			end;
		end;
	else
		local maxVarianceX = sin(rad(30));
		local firstFwd, firstFwdOver3;
		courseplay:debug(('%s: getNextFwdPoint()'):format(nameNum(vehicle)), 13);
		for i = vehicle.cp.waypointIndex, vehicle.cp.numWaypoints do
			if not vehicle.Waypoints[i].rev then
				local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode);
				local wdx, _, wdz, dist = courseplay:getWorldDirection(x, 0, z, vehicle.Waypoints[i].cx, 0, vehicle.Waypoints[i].cz);
				local dx,_,dz = worldDirectionToLocal(vehicle.cp.DirectionNode, wdx, 0, wdz);
				if not firstFwd then
					firstFwd = i;
					courseplay:debug(('--> set firstFwd as %d'):format(i), 13);
				end;
				if not firstFwdOver3 and dz and dist and dz * dist >= 3 then
					firstFwdOver3 = i;
					courseplay:debug(('--> set firstFwdOver3 as %d'):format(i), 13);
				end;
				courseplay:debug(('--> point %d, dx=%.4f, dz=%.4f, dist=%.2f, maxVarianceX=%.4f'):format(i, dx, dz, dist, maxVarianceX), 13);
				if dz > 0 and abs(dx) <= maxVarianceX then -- forward and x angle <= 30°
					courseplay:debug('----> return as waypointIndex', 13);
					return i;
				end;
			end;
		end;

		if firstFwdOver3 then
			courseplay:debug(('\treturn firstFwdOver3 (%d)'):format(firstFwdOver3), 13);
			return firstFwdOver3;
		elseif firstFwd then
			courseplay:debug(('\treturn firstFwd (%d)'):format(firstFwd), 13);
			return firstFwd;
		end;
	end;

	courseplay:debug('\treturn 1', 13);
	return 1;
end;

function courseplay:getReverseProperties(vehicle, workTool)
	courseplay:debug(('getReverseProperties(%q, %q)'):format(nameNum(vehicle), nameNum(workTool)), 13);

	-- Make sure they are reset so they wont conflict when changing worktools
	workTool.cp.frontNode		= nil;
	workTool.cp.isPivot			= nil;

	if workTool == vehicle then
		courseplay:debug('--> workTool is vehicle (steerable) -> return', 13);
		return;
	end;
	if vehicle.cp.hasSpecializationShovel then
		courseplay:debug('--> vehicle has "Shovel" spec -> return', 13);
		return;
	end;
	if workTool.cp.hasSpecializationShovel then
		courseplay:debug('--> workTool has "Shovel" spec -> return', 13);
		return;
	end;
	if not courseplay:isWheeledWorkTool(workTool) or courseplay:isHookLift(workTool) or courseplay:isAttacherModule(workTool) then
		courseplay:debug('--> workTool doesn\'t need reverse properties -> return', 13);
		return;
	end;

	--------------------------------------------------

	if not workTool.cp.distances then
		workTool.cp.distances = courseplay:getDistances(workTool);
	end;

	workTool.cp.realTurningNode = courseplay:getRealTurningNode(workTool);

	workTool.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(workTool);

	if workTool.attacherVehicle == vehicle or vehicle.cp.isHookLiftTrailer or workTool.attacherVehicle.cp.isAttacherModule then
		workTool.cp.frontNode = courseplay:getRealTrailerFrontNode(workTool);
	else
		workTool.cp.frontNode = courseplay:getRealDollyFrontNode(workTool.attacherVehicle);
		if workTool.cp.frontNode then
			courseplay:debug(string.format('--> workTool %q has dolly', nameNum(workTool)), 13);
		else
			courseplay:debug(string.format('--> workTool %q has invalid dolly -> return', nameNum(workTool)), 13);
			return;
		end;
	end;

	workTool.cp.nodeDistance = courseplay:getRealTrailerDistanceToPivot(workTool);
	courseplay:debug("--> tz: "..tostring(workTool.cp.nodeDistance).."  workTool.cp.realTurningNode: "..tostring(workTool.cp.realTurningNode), 13);

	if workTool.cp.realTurningNode == workTool.cp.frontNode then
		courseplay:debug('--> workTool.cp.realTurningNode == workTool.cp.frontNode', 13);
		workTool.cp.isPivot = false;
	else
		workTool.cp.isPivot = true;
	end;

	courseplay:debug(('--> isPivot=%s, frontNode=%s'):format(tostring(workTool.cp.isPivot), tostring(workTool.cp.frontNode)), 13);
end;
