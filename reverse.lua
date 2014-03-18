function courseplay:goReverse(vehicle,lx,lz)
	local fwd = false;
	local inverse = 1;
	local tipper = vehicle.tippers[1];
	local debugActive = courseplay.debugChannels[13];
	local isNotValid = table.getn(vehicle.tippers) == 0 or tipper.cp.inversedNodes == nil or tipper.cp.isPivot == nil or tipper.cp.frontNode == nil or vehicle.cp.mode == 9;
	if isNotValid then
		return -lx,-lz,fwd;
	end;

	if tipper.cp.inversedNodes then
		inverse = -1;
	end;
	if vehicle.cp.lastReverseRecordnumber == nil then
		vehicle.cp.lastReverseRecordnumber = vehicle.recordnumber -1;
	end;
	local nodeDistance = math.max(tipper.cp.nodeDistance,6);
	local node = tipper.rootNode;
	local isPivot = tipper.cp.isPivot;
	local xTipper,yTipper,zTipper = getWorldTranslation(node);
	if debugActive then drawDebugPoint(xTipper, yTipper+3, zTipper, 1, 0 , 0, 1) end;
	local xTractor,yTractor,zTractor = getWorldTranslation(vehicle.rootNode);
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
	local _,_,tsrZ = worldToLocal(vehicle.rootNode,srX,yTipper,srZ);
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

	if math.abs(lxFrontNode) > 0.001 and not tipper.cp.isPivot and tipper.rootNode ~= tipper.cp.frontNode then --backup
		tipper.cp.isPivot = true;
		courseplay:debug(nameNum(vehicle) .. " backup tipper.cp.isPivot set: "..tostring(lxFrontNode),13);
	end;

	local lxTractor, lzTractor = 0,0;
	-- TODO: (Claus) Old stearing code do we keep or delete?
	--[[local limitTractor = 0.068
	local limitFront = 0.065
	local limitTipper = 0.03 ]]
	-- End Old Code

	if isPivot then
		courseplay:showDirection(frontNode,lxFrontNode, lzFrontNode);
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(vehicle.rootNode, xFrontNode,yFrontNode,zFrontNode);
		courseplay:showDirection(vehicle.rootNode,lxTractor, lzTractor);

		-- TODO: (Claus) Old stearing code do we keep or delete?
		--[[ lz = (-lzTractor) - (-lzFrontNode)
		lx = (-lxTractor) - (-lxFrontNode)

		if ((lxTipper > limitTipper and lxFrontNode < lxTipper) or (lxTipper < -limitTipper and lxFrontNode > lxTipper)) and math.abs(lxFrontNode) < limitFront and math.abs(lxTractor) < limitTractor then
			lz = (-lzFrontNode) - (-lzTipper)
			lx = (-lxFrontNode) - (-lxTipper)

			lz = (-lzTractor) - lz
			lx = (-lxTractor) - lx
			courseplay.Revprinted = false
			if (lxTipper > 0 and lxFrontNode > 0 and lxTractor > 0) or (lxTipper < 0 and lxFrontNode < 0 and lxTractor < 0) then
				lz = -lz
				lx = -lx
			end
		else
			if not courseplay.Revprinted then
				if math.abs(lxFrontNode) > limitFront then
					courseplay:debug(nameNum(vehicle) .. " out with front: "..tostring(lxFrontNode),13)
				end
				if math.abs(lxTractor) > limitTractor then
					courseplay:debug(nameNum(vehicle) .. " out with tractor: "..tostring(lxTractor),13)
				end
				if math.abs(lxTipper) < limitTipper then
					courseplay:debug(nameNum(vehicle) .. " out with tipper: "..tostring(lxTipper),13)
				end
				courseplay.Revprinted = true
			end
		end]]
		-- End Old Code

		local tractorAngle  = courseplay:getRealWorldRotation(vehicle.rootNode);
		local pivotAngle    = courseplay:getRealWorldRotation(frontNode, inverse);
		local tipperAngle   = courseplay:getRealWorldRotation(node, inverse);
		local waypointAngle = Utils.getYRotationFromDirection(zTipper - tcz, xTipper - tcx);

		local rearAngleDiff  = (pivotAngle - tipperAngle) - (tipperAngle - waypointAngle);
		local frontAngleDiff = (tractorAngle - pivotAngle) - (pivotAngle - tipperAngle);

		local angleDiff = (frontAngleDiff - rearAngleDiff) * 2;

		lx, lz = Utils.getDirectionFromYRotation(angleDiff);
	else
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(vehicle.rootNode, xTipper,yTipper,zTipper);
		courseplay:showDirection(vehicle.rootNode,lxTractor, lzTractor);

		-- TODO: (Claus) Old stearing code do we keep or delete?
		--[[lz = (-lzTractor) - (-lzTipper)
		lx = (-lxTractor) - (-lxTipper)

		if math.abs(lx) < 0.05 then
			lx = 0
			lz = 1
		end ]]
		-- End of old stearing code.

		--print("lx: "..tostring(lx).."	lxTractor: "..tostring(lxTractor).."	lxTipper: "..tostring(lxTipper))

		local tractorAngle  = courseplay:getRealWorldRotation(vehicle.rootNode);
		local tipperAngle   = courseplay:getRealWorldRotation(node, inverse);
		local waypointAngle = Utils.getYRotationFromDirection(zTipper - tcz, xTipper - tcx);

		local angleDiff     = (tractorAngle - tipperAngle) - (tipperAngle - waypointAngle);

		lx, lz = Utils.getDirectionFromYRotation(angleDiff);
	end;

	if isPivot and ((math.abs(lxFrontNode) > 0.4 or math.abs(lxTractor) > 0.5)) then
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
	courseplay:showDirection(vehicle.rootNode,lx,lz);
	if (vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 6) and vehicle.cp.tipperFillLevel == 0 then
		courseplay:changeToFirstForwardWPAhead(vehicle);
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

function courseplay:getRealWorldRotation(node, direction)
	if not direction then direction = 1 end;
	local x,_,z = localDirectionToWorld(node, 0, 0, direction);
	local length = Utils.vector2Length(x,z);
	local rot = 0;
	if length > 0 then
		rot = Utils.getYRotationFromDirection(z/length, x/length);
	end;

	return rot;
end;

-- Find the first forward waypoint ahead of the vehicle
function courseplay:changeToFirstForwardWPAhead(vehicle)
	for i = vehicle.recordnumber, vehicle.maxnumber do
		if not vehicle.Waypoints[i].rev then
			local _,_,lz = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[i].cx, yTractor, vehicle.Waypoints[i].cz);
			if lz > 3 then
				vehicle.recordnumber = i;
				break;
			end;
		end;
	end;
end;