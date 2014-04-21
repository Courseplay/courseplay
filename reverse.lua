local abs, max, rad, sin = math.abs, math.max, math.rad, math.sin;

function courseplay:goReverse(vehicle,lx,lz)
	local fwd = false;
	local inverse = 1;
	local tipper = vehicle.tippers[1];
	if tipper and tipper.cp.isAttacherModule then
		tipper = vehicle.tippers[2];
	end;
	local debugActive = courseplay.debugChannels[13];
	local isNotValid = #vehicle.tippers == 0 or tipper == nil or tipper.cp.inversedNodes == nil or tipper.cp.isPivot == nil or tipper.cp.frontNode == nil or vehicle.cp.mode == 9;
	if isNotValid then
		if (vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 6) and vehicle.cp.tipperFillLevel == 0 then
			vehicle.recordnumber = courseplay:getNextFwdPoint(vehicle);
			return lx,lz,true;
		end;
		return -lx,-lz,fwd;
	end;

	if tipper.cp.inversedNodes then
		inverse = -1;
	end;
	if vehicle.cp.lastReverseRecordnumber == nil then
		vehicle.cp.lastReverseRecordnumber = vehicle.recordnumber -1;
	end;
	local nodeDistance = max(tipper.cp.nodeDistance,6);
	local node = tipper.rootNode;
	local isPivot = tipper.cp.isPivot;
	local xTipper,yTipper,zTipper = getWorldTranslation(node);
	if debugActive then drawDebugPoint(xTipper, yTipper+3, zTipper, 1, 0 , 0, 1) end;
	local frontNode = tipper.cp.frontNode;
	local xFrontNode,yFrontNode,zFrontNode = getWorldTranslation(frontNode);
	local tcx,tcy,tcz =0,0,0;
	local index = vehicle.recordnumber +1;
	if debugActive then
		drawDebugPoint(xFrontNode,yFrontNode+3,zFrontNode, 1, 0 , 0, 1);
		if not vehicle.cp.checkReverseValdityPrinted then
			local checkValdity = false;
			for i=index, vehicle.maxnumber do
				if vehicle.Waypoints[i].rev then
					tcx = vehicle.Waypoints[i].cx;
					tcz = vehicle.Waypoints[i].cz;
					local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
					if z*inverse < 0 then
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
	for i= index, vehicle.maxnumber do
		if vehicle.Waypoints[i].rev then
			tcx = vehicle.Waypoints[i].cx;
			tcz = vehicle.Waypoints[i].cz;
		else
			local dx, dz, _ = courseplay.generation:getPointDirection(vehicle.Waypoints[i-2], vehicle.Waypoints[i-1]);
			tcx = vehicle.Waypoints[i-1].cx + dx * 30;
			tcz = vehicle.Waypoints[i-1].cz + dz * 30;
		end;
		local distance = courseplay:distance(xTipper,zTipper, tcx ,tcz);
		if distance > nodeDistance then
			local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
			if z*inverse < 0 then
				vehicle.recordnumber = i -1;
				break;
			end;
		end;
	end;

	local srX,srZ = vehicle.Waypoints[vehicle.recordnumber].cx,vehicle.Waypoints[vehicle.recordnumber].cz;
	local _,_,tsrZ = worldToLocal(vehicle.cp.DirectionNode,srX,yTipper,srZ);
	if tsrZ > 0 then
		vehicle.cp.checkReverseValdityPrinted = false;
		vehicle.recordnumber = vehicle.recordnumber +1;
	end;

	if debugActive then drawDebugPoint(tcx, yTipper+3, tcz, 1, 1 , 1, 1) end;

	local lxTipper, lzTipper = AIVehicleUtil.getDriveDirection(node, tcx, yTipper, tcz);

	courseplay:showDirection(node,lxTipper, lzTipper);

	local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(frontNode, xTipper,yTipper,zTipper);

	if tipper.cp.inversedNodes then 	-- some tippers have the rootNode backwards, crazy isn't it?
		lxTipper, lzTipper = -lxTipper, -lzTipper;
		lxFrontNode, lzFrontNode = -lxFrontNode, -lzFrontNode;
	end;

	if abs(lxFrontNode) > 0.001 and not tipper.cp.isPivot and tipper.rootNode ~= tipper.cp.frontNode then --backup
		tipper.cp.isPivot = true;
		courseplay:debug(nameNum(vehicle) .. " backup tipper.cp.isPivot set: "..tostring(lxFrontNode),13);
	end;

	local lxTractor, lzTractor = 0,0;

	if isPivot then
		courseplay:showDirection(frontNode,lxFrontNode, lzFrontNode);
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, xFrontNode,yFrontNode,zFrontNode);
		courseplay:showDirection(vehicle.cp.DirectionNode,lxTractor, lzTractor);

		local tractorAngle  = courseplay:getRealWorldRotation(vehicle.cp.DirectionNode);
		local pivotAngle    = courseplay:getRealWorldRotation(frontNode, inverse);
		local tipperAngle   = courseplay:getRealWorldRotation(node, inverse);
		local waypointAngle = Utils.getYRotationFromDirection(xTipper - tcx, zTipper - tcz);

		local rearAngleDiff  = (tipperAngle - waypointAngle) - (pivotAngle - tipperAngle);
		local frontAngleDiff = (pivotAngle - tipperAngle) - (tractorAngle - pivotAngle);

		local angleDiff = (frontAngleDiff - rearAngleDiff) * 2;

		lx, lz = Utils.getDirectionFromYRotation(angleDiff);
	else
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, xTipper,yTipper,zTipper);
		courseplay:showDirection(vehicle.cp.DirectionNode,lxTractor, lzTractor);

		local tractorAngle  = courseplay:getRealWorldRotation(vehicle.cp.DirectionNode);
		local tipperAngle   = courseplay:getRealWorldRotation(node, inverse);
		local waypointAngle = Utils.getYRotationFromDirection(xTipper - tcx, zTipper - tcz);

		local angleDiff     = (tipperAngle - waypointAngle) - (tractorAngle - tipperAngle);

		lx, lz = Utils.getDirectionFromYRotation(angleDiff);
	end;

	if isPivot and ((abs(lxFrontNode) > 0.4 or abs(lxTractor) > 0.5)) then
		fwd = true;
		--lx = -lx
		vehicle.recordnumber = vehicle.cp.lastReverseRecordnumber;
	end;

	local nx, ny, nz = localDirectionToWorld(node, lxTipper, 0, lzTipper);
	courseplay:debug(nameNum(vehicle) .. ": call backward raycast", 1);
	local num = raycastAll(xTipper,yTipper+1,zTipper, nx, ny, nz, "findTipTriggerCallback", 10, vehicle);
	if num > 0 then
		courseplay:debug(string.format("%s: drive(%d): backward raycast end", nameNum(vehicle), debug.getinfo(1).currentline), 1);
	end;
	if courseplay.debugChannels[1] then
		drawDebugLine(xTipper,yTipper+1,zTipper, 1, 1, 0, xTipper+(nx*10), yTipper+(ny*10), zTipper+(nz*10), 1, 1, 0);
	end;
	courseplay:showDirection(vehicle.cp.DirectionNode,lx,lz);
	if (vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 6) and vehicle.cp.tipperFillLevel == 0 then
		vehicle.recordnumber = courseplay:getNextFwdPoint(vehicle);
	end;

	return lx,lz,fwd;
end;

function courseplay:showDirection(node,lx,lz)
	if courseplay.debugChannels[13] then
		local x,y,z = getWorldTranslation(node);
		local ctx,_,ctz = localToWorld(node,lx*5,y,lz*5);
		drawDebugLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz, 1, 0, 0);
	end
end

-- Find the first forward waypoint ahead of the vehicle
function courseplay:getNextFwdPoint(vehicle)
	local maxVarianceX = sin(rad(30));
	local firstFwd, firstFwdOver3;
	courseplay:debug(('%s: getNextFwdPoint()'):format(nameNum(vehicle)), 13);
	for i = vehicle.recordnumber, vehicle.maxnumber do
		if not vehicle.Waypoints[i].rev then
			local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode);
			local wdx, _, wdz, dist = courseplay:getWorldDirection(x, 0, z, vehicle.Waypoints[i].cx, 0, vehicle.Waypoints[i].cz);
			local dx,_,dz = worldDirectionToLocal(vehicle.cp.DirectionNode, wdx, 0, wdz);
			if not firstFwd then
				firstFwd = i;
				courseplay:debug(('\tset firstFwd as %d'):format(i), 13);
			end;
			if not firstFwdOver3 and dz and dist and dz * dist >= 3 then
				firstFwdOver3 = i;
				courseplay:debug(('\tset firstFwdOver3 as %d'):format(i), 13);
			end;
			courseplay:debug(('\tpoint %d, dx=%.4f, dz=%.4f, dist=%.2f, maxVarianceX=%.4f'):format(i, dx, dz, dist, maxVarianceX), 13);
			if dz > 0 and abs(dx) <= maxVarianceX then -- forward and x angle <= 30°
				courseplay:debug('\t-> return as recordnumber', 13);
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

	courseplay:debug('\treturn 1', 13);
	return 1;
end;

