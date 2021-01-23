local abs, max, rad, sin = math.abs, math.max, math.rad, math.sin;

function courseplay:goReverse(vehicle,lx,lz,mode2)
	-- TODO get rid of cx and cz and the global Waypoints array. I know this is horrible but I don't want to
	-- maintain a cx/cz in the Course object
	local getX = function(waypoints, ix)
		return waypoints[ix].cx or waypoints[ix].x
	end

	local getZ = function(waypoints, ix)
		return waypoints[ix].cz or waypoints[ix].z
	end

	local waypoints, index
	-- when the AI Driver is driving we want to use the course set up by the driver and not the legacy
	-- global variable
	-- TODO: fix missing encapsulation
	index = math.min(vehicle.cp.driver.ppc:getCurrentWaypointIx() + 1, vehicle.cp.driver.ppc.course:getNumberOfWaypoints())
	waypoints = vehicle.cp.driver:getCurrentCourse().waypoints

	local fwd = false;
	local workTool = courseplay:getFirstReversingWheeledWorkTool(vehicle) or vehicle.cp.workTools[1];
	local newTarget;
	local attacherVehicle;
	if vehicle.cp.turnTargets and vehicle.cp.curTurnIndex then
		newTarget = vehicle.cp.turnTargets[vehicle.cp.curTurnIndex];
	end;

	if workTool then
		attacherVehicle = workTool.getAttacherVehicle and workTool:getAttacherVehicle() or vehicle;
		-- Attacher modules and HookLift modules that needs the hookLiftTrailer
		if courseplay:isHookLift(workTool) or courseplay:isAttacherModule(workTool) then
			workTool = attacherVehicle;

			if workTool == vehicle and vehicle.cp.workTools[2] ~= nil then
				workTool = vehicle.cp.workTools[2];
				if courseplay:isAttacherModule(workTool) then
					workTool = attacherVehicle;
				end;
			end;
		end;
	end;
	local debugActive = courseplay.debugChannels[13];
	local isNotValid = vehicle.cp.numWorkTools == 0 or workTool == nil or workTool.cp.isPivot == nil or not workTool.cp.frontNode or vehicle.cp.mode == 9;
	if isNotValid then
		-- Simple reversing, no trailer to back up, so set the direction and get out of here, no need for
		-- all the sophisticated reversing	
		if newTarget then
			-- If we have the revPosX, revPosZ set, use those
			if newTarget.revPosX and newTarget.revPosZ then
				local _, vehicleY, _ = getWorldTranslation(vehicle.cp.directionNode);
				lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.directionNode, newTarget.revPosX, vehicleY, newTarget.revPosZ);
			end;
		elseif vehicle.cp.mode ~= 9 then
			-- Start: Fixes issue #525
			local tx, ty, tz = localToWorld(vehicle.cp.directionNode, 0, 1, -3);
			local nx, ny, nz = localDirectionToWorld(vehicle.cp.directionNode, lx, -0,1, lz);
			courseplay:doTriggerRaycasts(vehicle, 'tipTrigger', 'rev', false, tx, ty, tz, nx, ny, nz);
			--  End:  Fixes issue #525
		end
		-- false means that this is a trivial reverse and can be handled by drive
		return -lx,-lz,fwd, false;
	end;
	local node = workTool.cp.realTurningNode;
	if mode2 then
		vehicle.cp.toolsRealTurningNode = node;
	end
	local xTipper,yTipper,zTipper = getWorldTranslation(node);
	if debugActive then cpDebug:drawPoint(xTipper, yTipper+5, zTipper, 1, 0 , 0) end;
	local frontNode = workTool.cp.frontNode;
	local xFrontNode,yFrontNode,zFrontNode = getWorldTranslation(frontNode);
	local tcx,tcy,tcz =0,0,0;
	if debugActive and not newTarget then
		cpDebug:drawPoint(xFrontNode,yFrontNode+3,zFrontNode, 1, 0 , 0);
		if not vehicle.cp.checkReverseValdityPrinted then
			local checkValidity = false;
			for i=index, #waypoints do
				if waypoints[i].rev then
					tcx = getX(waypoints, i);
					tcz = getZ(waypoints, i);
					local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
					if z < 0 then
						checkValidity = true;
						break;
					end;
				else
					break;
				end;
			end;
			if not checkValidity then
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
	elseif not mode2 then
		for i= index, #waypoints do
			if waypoints[i].rev and not waypoints[i-1].wait then
				tcx = getX(waypoints, i);
				tcz = getZ(waypoints, i);
			else
				local dx, dz, _ = courseplay:getPointDirection(waypoints[i-2], waypoints[i-1]);
				tcx = getX(waypoints, i-1) + dx * (waypoints[i-1].wait and 15 or 30);
				tcz = getZ(waypoints, i-1) + dz * (waypoints[i-1].wait and 15 or 30);
			end;
			local distance = courseplay:distance(xTipper,zTipper, getX(waypoints, i-1) ,getZ(waypoints, i-1));

			local waitingPoint;
			local unloadPoint;
			if waypoints[i-1].wait then 
				waitingPoint = i-1;	
			end;
			if waypoints[i].wait then
				waitingPoint = i;
			end;
			if waypoints[i-1].unload then 
				unloadPoint = i-1;	
			end;
			if waypoints[i].unload then
				unloadPoint = i;
			end;
			
			
			
			-- HANDLE WAITING POINT WAYPOINT CHANGE
			if waitingPoint then
				if workTool.cp.realUnloadOrFillNode then
					local _,y,_ = getWorldTranslation(workTool.cp.realUnloadOrFillNode);
					local _,_,z = worldToLocal(workTool.cp.realUnloadOrFillNode, getX(waypoints, waitingPoint), y, getZ(waypoints, waitingPoint));
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
					local tipDistanceToPoint = courseplay:distance(x,z,getX(waypoints, unloadPoint),getZ(waypoints, unloadPoint))
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
			-- SWITCH TO FORWARD
			elseif waypoints[i-1].rev and not waypoints[i].rev then
				if distance <= 2 then
					courseplay:debug(string.format("%s: Change direction to forward", nameNum(vehicle)), 13);
				end;
				break;

			-- FIND THE RIGHT START REVERSING WAYPOINT
			elseif waypoints[i-1].rev and not waypoints[i-2].rev then
				for recNum = index, vehicle.cp.numWaypoints do
					local srX,srZ = getX(waypoints, recNum),getZ(waypoints, recNum);
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
	elseif mode2 then
		tcx,tcz = vehicle.cp.curTarget.x, vehicle.cp.curTarget.z;
	end;

	if debugActive then
		cpDebug:drawPoint(tcx, yTipper+3, tcz, 1, 1 , 1)
		if workTool.cp.realUnloadOrFillNode then
			local xUOFNode,yUOFNode,zUOFNode = getWorldTranslation(workTool.cp.realUnloadOrFillNode);
			cpDebug:drawPoint(xUOFNode,yUOFNode+5,zUOFNode, 0, 1 , 0.5);
		end;
	end;

	local lxTipper, lzTipper = AIVehicleUtil.getDriveDirection(node, tcx, yTipper, tcz);

	courseplay:showDirection(node,lxTipper, lzTipper, 1, 0, 0);

	local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(frontNode, xTipper,yTipper,zTipper);

	local lxTractor, lzTractor = 0,0;

	local maxTractorAngle = rad(60);

	-- for articulated vehicles use the articulated axis' rotation node as it is a better indicator or the
	-- vehicle's orientation than the direction node which often turns/moves with an articulated vehicle part
	-- TODO: consolidate this with AITurn:getTurnNode()
	local turnNode
	local useArticulatedAxisRotationNode = SpecializationUtil.hasSpecialization(ArticulatedAxis, vehicle.specializations) and vehicle.spec_articulatedAxis.rotationNode
	if useArticulatedAxisRotationNode then
		turnNode = vehicle.spec_articulatedAxis.rotationNode
	else
		turnNode = vehicle.cp.directionNode
	end

	if workTool.cp.isPivot then
		courseplay:showDirection(frontNode,lxFrontNode, lzFrontNode, 0, 1, 0);

		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(turnNode, xFrontNode,yFrontNode,zFrontNode);
		courseplay:showDirection(turnNode,lxTractor, lzTractor, 0, 0.7, 0);

		local rotDelta = (workTool.cp.nodeDistance * (0.5 - (0.023 * workTool.cp.nodeDistance - 0.073)));
		local trailerToWaypointAngle = courseplay:getLocalYRotationToPoint(node, tcx, yTipper, tcz, -1) * rotDelta;
		trailerToWaypointAngle = MathUtil.clamp(trailerToWaypointAngle, -rad(90), rad(90));

		local dollyToTrailerAngle = courseplay:getLocalYRotationToPoint(frontNode, xTipper, yTipper, zTipper, -1);

		local tractorToDollyAngle = courseplay:getLocalYRotationToPoint(turnNode, xFrontNode, yFrontNode, zFrontNode, -1);

		local rearAngleDiff	= (dollyToTrailerAngle - trailerToWaypointAngle);
		rearAngleDiff = MathUtil.clamp(rearAngleDiff, -rad(45), rad(45));

		local frontAngleDiff = (tractorToDollyAngle - dollyToTrailerAngle);
		frontAngleDiff = MathUtil.clamp(frontAngleDiff, -rad(45), rad(45));

		local angleDiff = (frontAngleDiff - rearAngleDiff) * (1.5 - (workTool.cp.nodeDistance * 0.4 - 0.9) + rotDelta);
		angleDiff = MathUtil.clamp(angleDiff, -rad(45), rad(45));

		lx, lz = MathUtil.getDirectionFromYRotation(angleDiff);
	else
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(turnNode, xTipper,yTipper,zTipper);
		courseplay:showDirection(turnNode,lxTractor, lzTractor, 1, 1, 0);

		local rotDelta = workTool.cp.nodeDistance * 0.3;
		local trailerToWaypointAngle = courseplay:getLocalYRotationToPoint(node, tcx, yTipper, tcz, -1) * rotDelta;
		trailerToWaypointAngle = MathUtil.clamp(trailerToWaypointAngle, -math.rad(90), math.rad(90));
		local tractorToTrailerAngle = courseplay:getLocalYRotationToPoint(turnNode, xTipper, yTipper, zTipper, -1);

		local angleDiff = (tractorToTrailerAngle - trailerToWaypointAngle) * (1 + rotDelta);

		-- If we only have steering axle on the worktool and they turn when reversing, we need to steer a lot more to counter this.
		if workTool.cp.steeringAxleUpdateBackwards then
			angleDiff = angleDiff * 4;
		end;

		angleDiff = MathUtil.clamp(angleDiff, -maxTractorAngle, maxTractorAngle);

		lx, lz = MathUtil.getDirectionFromYRotation(angleDiff);
	end;

	if (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_FIELDWORK) and vehicle.cp.currentTipTrigger == nil and (vehicle.cp.totalFillLevel ~= nil and vehicle.cp.totalFillLevel > 0) then
		local nx, ny, nz = localDirectionToWorld(node, lxTipper, -0.1, lzTipper);
		courseplay:doTriggerRaycasts(vehicle, 'tipTrigger', 'rev', false, xTipper, yTipper + 1, zTipper, nx, ny, nz);
	end;
	courseplay:showDirection(turnNode,lx,lz, 0.7, 0, 1);
	-- do a little bit of damping if using the articulated axis as lx tends to oscillate around 0 which results in the
	-- speed adjustment kicking in and slowing down the vehicle.
	if useArticulatedAxisRotationNode and math.abs(lx) < 0.04 then lx = 0 end
	-- true means this code is taking care of the reversing as this is not a trivial case
	-- for instance because of a trailer
	return lx,lz,fwd, true;
end;

function courseplay:getFirstReversingWheeledWorkTool(vehicle)
	-- since some weird things like Seed Bigbag are also vehicles, check this first
	if not vehicle.getAttachedImplements then return nil end
	-- Check all attached implements if we are an wheeled workTool behind the tractor
	for _, imp in ipairs(vehicle:getAttachedImplements()) do
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
	return MathUtil.getYRotationFromDirection(dx, dz);
end;

function courseplay:showDirection(node,lx,lz, r, g, b)
	if courseplay.debugChannels[13] then
		local x,y,z = getWorldTranslation(node);
		local ctx,_,ctz = localToWorld(node,lx*5,y,lz*5);
		cpDebug:drawLine(x, y+5, z, r or 1, g or 0, b or 0, ctx, y+5, ctz);
	end
end

-- Find the first forward waypoint ahead of the vehicle
function courseplay:getNextFwdPoint(vehicle, isTurning)
	local directionNode	= AIDriverUtil.getDirectionNode(vehicle)
	if isTurning then
		courseplay:debug(('%s: getNextFwdPoint()'):format(nameNum(vehicle)), 14);
    -- scan only the next few waypoints, we don't want to end up way further in the course, missing 
    -- many waypoints. The proper solution here would be to take the workarea into account as the tractor may 
    -- be well ahead of the turnEnd point in case of long implements. Instead we just assume 10 waypoints is
    -- long enough.
		for i = vehicle.cp.waypointIndex, math.min( vehicle.cp.waypointIndex + 10, vehicle.cp.numWaypoints ) do
			if vehicle.cp.abortWork and vehicle.cp.abortWork == i then
				vehicle.cp.abortWork = nil;
			end;
			local waypointToCheck = vehicle.Waypoints[i]
			if not waypointToCheck.rev and not waypointToCheck.turnEnd then
				local wpX, wpZ = waypointToCheck.cx, waypointToCheck.cz;
				local _, _, disZ = worldToLocal(directionNode, wpX, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wpX, 300, wpZ), wpZ);
				local vX, _, vZ = localToWorld( directionNode, 0, 0, 0 )
				courseplay:debug(('%s: getNextFwdPoint(), vX = %.1f, vZ = %.1f, i = %d, wpX = %.1f, wpZ = %.1f, disZ = %.1f '):format(nameNum(vehicle), vX, vZ, i, wpX, wpZ, disZ ), 14);
				if disZ > 5 then
					courseplay:debug(('--> return (%d) as waypointIndex'):format(i), 14);
					return i;
				end;
			end;
		end;
		local ix = math.min(vehicle.cp.waypointIndex + 1, vehicle.cp.numWaypoints)
		courseplay:debug(('\tno waypoint found in front of us, returning next waypoint (%d)'):format(ix), 14);
		return ix
	else
		local maxVarianceX = sin(rad(30));
		local firstFwd, firstFwdOver3;
		courseplay:debug(('%s: getNextFwdPoint()'):format(nameNum(vehicle)), 13);
		for i = vehicle.cp.waypointIndex, vehicle.cp.numWaypoints do
			if not vehicle.Waypoints[i].rev then
				local x, y, z = getWorldTranslation(directionNode);
				local wdx, _, wdz, dist = courseplay:getWorldDirection(x, 0, z, vehicle.Waypoints[i].cx, 0, vehicle.Waypoints[i].cz);
				local dx,_,dz = worldDirectionToLocal(directionNode, wdx, 0, wdz);
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

	local attacherVehicle = workTool:getAttacherVehicle();

	if not workTool.cp.distances then
		workTool.cp.distances = courseplay:getDistances(workTool);
	end;

	workTool.cp.realTurningNode = courseplay:getRealTurningNode(workTool);

	workTool.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(workTool);

	if attacherVehicle == vehicle or attacherVehicle.cp.isAttacherModule then
		workTool.cp.frontNode = courseplay:getRealTrailerFrontNode(workTool);
	else
		workTool.cp.frontNode = courseplay:getRealDollyFrontNode(attacherVehicle);
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
