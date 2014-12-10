local abs, max, rad, sin = math.abs, math.max, math.rad, math.sin;

function courseplay:goReverse(vehicle,lx,lz)
	local fwd = false;
	local workTool = vehicle.cp.workTools[1];
	if workTool and workTool.cp.isAttacherModule then
		workTool = vehicle.cp.workTools[2];
	end;
	local debugActive = courseplay.debugChannels[13];
	local isNotValid = vehicle.cp.numWorkTools == 0 or workTool == nil or workTool.cp.isPivot == nil or not workTool.cp.frontNode or vehicle.cp.mode == 9;
	if isNotValid then
		-- Start: Fixes issue #525
		local tx, ty, tz = localToWorld(vehicle.cp.DirectionNode, 0, 1, -3);
		local nx, ny, nz = localDirectionToWorld(vehicle.cp.DirectionNode, lx, 0, lz);
		courseplay:doTriggerRaycasts(vehicle, 'tipTrigger', 'rev', false, tx, ty, tz, nx, ny, nz);
		--  End:  Fixes issue #525

		return -lx,-lz,fwd;
	end;

	if vehicle.cp.lastReverseRecordnumber == nil then
		vehicle.cp.lastReverseRecordnumber = vehicle.recordnumber -1;
	end;

	local node = workTool.cp.realTurningNode;
	local isPivot = workTool.cp.isPivot;
	local xTipper,yTipper,zTipper = getWorldTranslation(node);
	if debugActive then drawDebugPoint(xTipper, yTipper+5, zTipper, 1, 0 , 0, 1) end;
	local frontNode = workTool.cp.frontNode;
	local xFrontNode,yFrontNode,zFrontNode = getWorldTranslation(frontNode);
	local tcx,tcy,tcz =0,0,0;
	local index = vehicle.recordnumber + 1;
	if debugActive then
		drawDebugPoint(xFrontNode,yFrontNode+3,zFrontNode, 1, 0 , 0, 1);
		if not vehicle.cp.checkReverseValdityPrinted then
			local checkValdity = false;
			for i=index, vehicle.maxnumber do
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
	for i= index, vehicle.maxnumber do
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
		if vehicle.Waypoints[i-1].wait	then waitingPoint = i-1;	end;
		if vehicle.Waypoints[i].wait 	then waitingPoint = i; 		end;
		-- HANDLE WAITING POINT WAYPOINT CHANGE
		if waitingPoint then
			if workTool.cp.realUnloadOrFillNode then
				local _,y,_ = getWorldTranslation(workTool.cp.realUnloadOrFillNode);
				local _,_,z = worldToLocal(workTool.cp.realUnloadOrFillNode, vehicle.Waypoints[waitingPoint].cx, y, vehicle.Waypoints[waitingPoint].cz);
				if z >= 0 then
					courseplay:setRecordNumber(vehicle, waitingPoint + 1);
					courseplay:debug(string.format("%s: Is at waiting point", nameNum(vehicle)), 13);
					break;
				end;
			else
				if distance <= 2 then
					courseplay:setRecordNumber(vehicle, waitingPoint + 1);
					courseplay:debug(string.format("%s: Is at waiting point", nameNum(vehicle)), 13);
					break;
				end;
			end;

			if distance > 3 then
				local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
				if z < 0 then
					courseplay:setRecordNumber(vehicle, i - 1);
					break;
				end;
			end;

			break;

		-- HANDLE LAST REVERSE WAYPOINT CHANGE
		elseif vehicle.Waypoints[i-1].rev and not vehicle.Waypoints[i].rev then
			if distance <= 2 then
				courseplay:setRecordNumber(vehicle, courseplay:getNextFwdPoint(vehicle));
				courseplay:debug(string.format("%s: Change direction to forward", nameNum(vehicle)), 13);
			end;
			break;

		-- FIND THE RIGHT START REVERSING WAYPOINT
		elseif vehicle.Waypoints[i-1].rev and not vehicle.Waypoints[i-2].rev then
			for recNum = index, vehicle.maxnumber do
				local srX,srZ = vehicle.Waypoints[recNum].cx,vehicle.Waypoints[recNum].cz;
				local _,_,tsrZ = worldToLocal(node,srX,yTipper,srZ);
				if tsrZ < -2 then
					courseplay:setRecordNumber(vehicle, recNum);
					courseplay:debug(string.format("%s: First reverse point -> Change waypoint to behind trailer: %q", nameNum(vehicle), recNum), 13);
					break;
				end;
			end;
			break;

		-- HANDLE REVERSE WAYPOINT CHANGE
		elseif distance > 3 then
			local _,_,z = worldToLocal(node, tcx,yTipper,tcz);
			if z < 0 then
				courseplay:setRecordNumber(vehicle, i - 1);
				break;
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

	--[[if isPivot and ((abs(lxFrontNode) > 0.4 or abs(lxTractor) > 0.5)) then
		fwd = true;
		--lx = -lx
		courseplay:setRecordNumber(vehicle, vehicle.cp.lastReverseRecordnumber);
	end;]]

	if vehicle.cp.currentTipTrigger == nil and vehicle.cp.tipperFillLevel > 0 then
		local nx, ny, nz = localDirectionToWorld(node, lxTipper, 0, lzTipper);
		courseplay:doTriggerRaycasts(vehicle, 'tipTrigger', 'rev', false, xTipper, yTipper + 1, zTipper, nx, ny, nz);
	end;
	courseplay:showDirection(vehicle.cp.DirectionNode,lx,lz);

	return lx,lz,fwd;
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

function courseplay:getReverseProperties(vehicle, workTool)
	courseplay:debug(('getReverseProperties(%q, %q)'):format(nameNum(vehicle), nameNum(workTool)), 13);

	-- Make sure they are reset so they wont conflict when changing worktools
	workTool.cp.frontNode		= nil;
	workTool.cp.isPivot			= nil;

	if workTool == vehicle then
		courseplay:debug('\tworkTool is vehicle (steerable) -> return', 13);
		return;
	end;
	if vehicle.cp.hasSpecializationShovel then
		courseplay:debug('\tvehicle has "Shovel" spec -> return', 13);
		return;
	end;
	if workTool.cp.hasSpecializationShovel then
		courseplay:debug('\tworkTool has "Shovel" spec -> return', 13);
		return;
	end;
	if not courseplay:isReverseAbleWheeledWorkTool(workTool) then
		courseplay:debug('\tworkTool doesn\'t need reverse properties -> return', 13);
		return;
	end;

	--------------------------------------------------

	if not workTool.cp.distances then
		workTool.cp.distances = courseplay:getDistances(workTool);
	end;

	workTool.cp.realTurningNode = courseplay:getRealTurningNode(workTool);

	workTool.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(workTool);

	if workTool.attacherVehicle == vehicle or workTool.attacherVehicle.cp.isAttacherModule then
		workTool.cp.frontNode = courseplay:getRealTrailerFrontNode(workTool);
	else
		workTool.cp.frontNode = courseplay:getRealDollyFrontNode(workTool.attacherVehicle);
		if workTool.cp.frontNode then
			courseplay:debug(string.format('\tworkTool %q has dolly', nameNum(workTool)), 13);
		else
			courseplay:debug(string.format('\tworkTool %q has invalid dolly -> return', nameNum(workTool)), 13);
			return;
		end;
	end;

	workTool.cp.nodeDistance = courseplay:getRealTrailerDistanceToPivot(workTool);
	courseplay:debug("\ttz: "..tostring(workTool.cp.nodeDistance).."  workTool.cp.realTurningNode: "..tostring(workTool.cp.realTurningNode), 13);

	if workTool.cp.realTurningNode == workTool.cp.frontNode then
		workTool.cp.isPivot = false;
	else
		workTool.cp.isPivot = true;
	end;

	if workTool.cp.realTurningNode == workTool.cp.frontNode then
		courseplay:debug('\tworkTool.cp.realTurningNode == workTool.cp.frontNode', 13);
	end;

	courseplay:debug(('\t--> isPivot=%s, frontNode=%s'):format(tostring(workTool.cp.isPivot), tostring(workTool.cp.frontNode)), 13);
end;

function courseplay:isInvertedTrailerNode(workTool, node)
	if courseplay:isMixer(workTool) then
		return false;
	end;
	-- Use node if set else use the workTool.rootNode
	node = node or workTool.rootNode;

	-- Check if the node is in front of the attacher node
	local xTipper,yTipper,zTipper = getWorldTranslation(node);
	local attacherNode = workTool.attacherJoint.node;
	local rxTemp, ryTemp, rzTemp = getRotation(attacherNode);
	setRotation(attacherNode, 0, 0, 0);
	local _,_,direction = worldToLocal(attacherNode, xTipper,yTipper,zTipper);
	setRotation(attacherNode, rxTemp, ryTemp, rzTemp);
	local isInFront = direction >= 0;

	-- Check if it's reversed based on if it's in front of the attacher node or not
	local x,y,z = getWorldTranslation(attacherNode);
	local _,_,tz = worldToLocal(node, x,y,z);
	return isInFront and (tz > 0) or (tz < 0);
end;

local allowedJointType = {};
function courseplay:isReverseAbleWheeledWorkTool(workTool)
	if #allowedJointType == 0 then
		local jointTypeList = {"implement", "trailer", "trailerLow", "semitrailer"};
		for _,jointType in ipairs(jointTypeList) do
			local index = Vehicle.jointTypeNameToInt[jointType];
			if index then
				table.insert(allowedJointType, index, true);
			end;
		end;
	end;

	if allowedJointType[workTool.attacherJoint.jointType] and workTool.wheels and #workTool.wheels > 0 then
		-- Attempt to find the pivot node.
		local node, _ = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
		if node then
			-- Trailers
			if (workTool.attacherJoint.jointType ~= Vehicle.jointTypeNameToInt["implement"])
			-- Implements with pivot and wheels that do not lift the wheels from the ground.
			or (node ~= workTool.rootNode and workTool.attacherJoint.jointType == Vehicle.jointTypeNameToInt["implement"] and not workTool.attacherJoint.topReferenceNode)
			then
				return true;
			end;
		end;
	end;

	return false;
end;

function courseplay:getRealTrailerDistanceToPivot(workTool)
	-- Attempt to find the pivot node.
	local node, backTrack = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
	if node then
		local x,y,z;
		if node == workTool.rootNode then
			x,y,z = getWorldTranslation(workTool.attacherJoint.node);
		else
			x,y,z = getWorldTranslation(node);
		end;
		local _,_,tz = worldToLocal(courseplay:getRealTurningNode(workTool), x,y,z);
		return tz;
	else
		return 3;
	end;
end;

--- courseplay:findJointNodeConnectingToNode(workTool, fromNode, toNode)
--	Returns: (node, backtrack)
--		node will return either:		1. The jointNode that connects to the toNode,
--										2. The toNode if no jointNode is found but the fromNode is inside the same component as the toNode
--										3. nil in case none of the above fails.
--		backTrack will return either:	1. A table of all the jointNodes found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
function courseplay:findJointNodeConnectingToNode(workTool, fromNode, toNode)
	if fromNode == toNode then return toNode; end;

	-- Attempt to find the jointNode by backtracking the compomentJoints.
	for index, component in ipairs(workTool.components) do
		if component.node == fromNode then
			for _, joint in ipairs(workTool.componentJoints) do
				if joint.componentIndices[2] == index then
					if workTool.components[joint.componentIndices[1]].node == toNode then
						return joint.jointNode, {joint.jointNode};
					else
						local node, backTrack = courseplay:findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[1]].node, toNode);
						if backTrack then table.insert(backTrack, 1, joint.jointNode); end;
					    return node, backTrack;
					end;
				end;
			end;
		end;
	end;

	-- Last attempt to find the jointNode by getting parent of parent untill hit or the there is no more parents.
	local node = fromNode;
	while node ~= 0 and node ~= nil do
		if node == toNode then
			return toNode, nil;
		else
			node = getParent(node);
		end;
	end;

	-- If anything else fails, return nil
	return nil, nil;
end;

function courseplay:createNewLinkedNode(object, nodeName, linkToNode)
	if not object.cp.notesToDelete then object.cp.notesToDelete = {}; end;

	local node = createTransformGroup(nodeName);
	link(linkToNode, node);
	table.insert(object.cp.notesToDelete, node);

	return node;
end;

function courseplay:getRealTurningNode(workTool)
	if not workTool.cp.turningNode then
		local node = courseplay:createNewLinkedNode(workTool, "realTurningNode", workTool.rootNode);

		local Distance = 0;
		local invert = courseplay:isInvertedTrailerNode(workTool) and -1 or 1;
		local steeringAxleScale = 0;

		-- Get the distance from root node to the whells turning point.
		if workTool.wheels and #workTool.wheels > 0 then
			local _,yTrailer,_ = getWorldTranslation(workTool.rootNode);
			local minDis, maxDis = 0, 0;
			local minDisRot, maxDisRot = 0, 0;
			local haveStraitWheels, haveRotatingWheels = false, false;
			local steeringAxleScaleMin, steeringAxleScaleMax = 0, 0;

			-- Sort wheels in turning wheels and strait wheels and find the min and max distance for each set.
			for i = 1, #workTool.wheels do
				--if workTool.wheels[i].node == workTool.rootNode and workTool.wheels[i].lateralStiffness > 0 then
				if workTool.wheels[i].maxLatStiffness > 0 then
					local x,_,z = getWorldTranslation(workTool.wheels[i].driveNode);
					local _,_,dis = worldToLocal(workTool.rootNode, x, yTrailer, z);
					dis = dis * invert;
					if workTool.steeringAxleUpdateBackwards == false or workTool.wheels[i].steeringAxleScale == 0 then
						if haveStraitWheels then
							if dis < minDis then minDis = dis; end;
							if dis > maxDis then maxDis = dis; end;
						else
							minDis = dis;
							maxDis = dis;
							haveStraitWheels = true;
						end;
					else
						if workTool.wheels[i].steeringAxleScale < 0 and workTool.wheels[i].steeringAxleScale < steeringAxleScaleMin then
							steeringAxleScaleMin = workTool.wheels[i].steeringAxleScale;
						elseif workTool.wheels[i].steeringAxleScale > 0 and workTool.wheels[i].steeringAxleScale > steeringAxleScaleMax then
							steeringAxleScaleMax = workTool.wheels[i].steeringAxleScale;
						end;
						if haveRotatingWheels then
							if dis < minDisRot then minDisRot = dis; end;
							if dis > maxDisRot then maxDisRot = dis; end;
						else
							minDisRot = dis;
							maxDisRot = dis;
							haveRotatingWheels = true;
						end;
					end;
				end;
			end;

			-- Calculate strait wheel median distance
			if haveStraitWheels then
				if minDis == maxDis then
					Distance = minDis;
				else
					Distance = (minDis + maxDis) * 0.5;
				end;

			-- Calculate turning wheel median distance if there are no strait wheels.
			elseif haveRotatingWheels then
				steeringAxleScale = steeringAxleScaleMin + steeringAxleScaleMax;
				if minDisRot == maxDisRot then
					Distance = minDisRot;
				else
					Distance = (minDisRot + maxDisRot) * 0.5;
				end;
			end;
		end;

		if Distance ~= 0 then
			setTranslation(node, 0, 0, Distance);
		end;
		if courseplay:isInvertedTrailerNode(workTool, node) then
			setRotation(node, 0, math.rad(180), 0);
		end;

		if not haveStraitWheels and workTool.steeringAxleUpdateBackwards and steeringAxleScale < 0 then
			local tempNode, _ = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
			if tempNode then
				local x, y, z;
				if tempNode == workTool.rootNode then
					x, y, z = getWorldTranslation(workTool.attacherJoint.node);
				else
					x, y, z = getWorldTranslation(tempNode);
				end;
				local _,_,dis = worldToLocal(node, x, y, z);
				local offset = (dis * math.abs(steeringAxleScale)) + Distance;
				setTranslation(node, 0, 0, offset);
				workTool.cp.steeringAxleUpdateBackwards = true;
			end;
		end;

		workTool.cp.turningNode = node;
	end;

	return workTool.cp.turningNode;
end;

function courseplay:getRealUnloadOrFillNode(workTool)
	if workTool.cp.unloadOrFillNode == nil then
		-- BALELOADERS
		if courseplay:isBaleLoader(workTool) or (courseplay:isSpecialBaleLoader(workTool) and workTool.cp.specialUnloadDistance) then
			-- Create the new node and link it to realTurningNode
			local node = courseplay:createNewLinkedNode(workTool, "UnloadOrFillNode", courseplay:getRealTurningNode(workTool));

			-- make sure we set the node distance position
			local Distance = workTool.cp.specialUnloadDistance or -5;
			setTranslation(node, 0, 0, Distance);

			workTool.cp.unloadOrFillNode = node;

		-- NORMAL FILLABLE TRAILERS WITH ALLOW TO BE FILLED FROM THE AIR
		elseif workTool.cp.hasSpecializationFillable and workTool.allowFillFromAir then
			-- Create the new node and link it to exactFillRootNode
			local node = courseplay:createNewLinkedNode(workTool, "UnloadOrFillNode", workTool.exactFillRootNode);

			-- Make sure ve set the height position to the same as the realTurningNode
			local x, y, z = getWorldTranslation(courseplay:getRealTurningNode(workTool));
			local _,Height,_ = worldToLocal(workTool.exactFillRootNode, x, y, z);
			setTranslation(node, 0, Height, 0);

			if courseplay:isInvertedTrailerNode(workTool, node) then
				setRotation(node, 0, math.rad(180), 0);
			end;

			workTool.cp.unloadOrFillNode = node;

		-- NONE OF THE ABOVE
		else
			workTool.cp.unloadOrFillNode = false;
		end;
	end;

	return workTool.cp.unloadOrFillNode;
end;

function courseplay:getRealTrailerFrontNode(workTool)
	if not workTool.cp.realFrontNode then
		local jointNode, backtrack = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
		if jointNode and backtrack and workTool.attacherJoint.jointType ~= Vehicle.jointTypeNameToInt["implement"] then
			local rootNode;
			for _, joint in ipairs(workTool.componentJoints) do
				if joint.jointNode == jointNode then
					rootNode = workTool.components[joint.componentIndices[2]].node;
					break;
				end;
			end;

			if rootNode then
				local node = courseplay:createNewLinkedNode(workTool, "realFrontNode", rootNode);
				local x, y, z = getWorldTranslation(jointNode);
				local _,_,delta = worldToLocal(rootNode, x, y, z);

				setTranslation(node, 0, 0, delta);

				if courseplay:isInvertedTrailerNode(workTool, node) then
					setRotation(node, 0, math.rad(180), 0);
				end;

				workTool.cp.realFrontNode = node;
			end;
		else
			workTool.cp.realFrontNode = courseplay:getRealTurningNode(workTool);
		end;
	end;

	return workTool.cp.realFrontNode
end;

function courseplay:getRealDollyFrontNode(dolly)
	if dolly.cp.realDollyFrontNode == nil then
		local node, _ = courseplay:findJointNodeConnectingToNode(dolly, dolly.attacherJoint.rootNode, dolly.rootNode);
		if node then
			-- Trailers without pivote
			if (node == dolly.rootNode and dolly.attacherJoint.jointType ~= Vehicle.jointTypeNameToInt["implement"])
			-- Implements with pivot and wheels that do not lift the wheels from the ground.
			or (node ~= dolly.rootNode and dolly.attacherJoint.jointType == Vehicle.jointTypeNameToInt["implement"] and not dolly.attacherJoint.topReferenceNode) then
				dolly.cp.realDollyFrontNode = courseplay:getRealTurningNode(dolly);
			else
				dolly.cp.realDollyFrontNode = false;
			end;
		end;
	end;

	return dolly.cp.realDollyFrontNode
end;

function courseplay:getTotalLengthOnWheels(vehicle)
	courseplay:debug(('%s: getTotalLengthOnWheels()'):format(nameNum(vehicle)), 6);
	local totalLength = 0;
	local directionNodeToFrontWheelOffset;

	if not vehicle.cp.distances then
		vehicle.cp.distances = courseplay:getDistances(vehicle);
	end;

	-- STEERABLES
	if vehicle.cp.hasSpecializationSteerable then
		directionNodeToFrontWheelOffset = vehicle.cp.distances.frontWheelToDirectionNodeOffset;

		local _, y, _ = getWorldTranslation(vehicle.cp.DirectionNode);

		local hasRearAttach = false;
		local jointType = 0;

		for _, implement in ipairs(vehicle.attachedImplements) do
			local xi, _, zi = getWorldTranslation(implement.object.attacherJoint.node);
			local _,_,delta = worldToLocal(vehicle.cp.DirectionNode, xi, y, zi);

			-- Check if it's rear attached
			if delta < 0 then
				hasRearAttach = true;
				local length, _ = courseplay:getTotalLengthOnWheels(implement.object);
				if length > 0 then
					jointType = implement.object.attacherJoint.jointType;
					totalLength = length;
				end;
			end;
		end;

		if hasRearAttach and totalLength > 0 and jointType > 0 then
			local length = vehicle.cp.distances.frontWheelToRearTrailerAttacherJoints[jointType];
			if length then
				totalLength = totalLength + length;
			else
				totalLength = 0;
				directionNodeToFrontWheelOffset = 0;
			end;
			courseplay:debug(('%s: hasRearAttach: totalLength=%.2f'):format(nameNum(vehicle), totalLength), 6);
		else
			totalLength = vehicle.cp.distances.frontWheelToRearWheel;
			courseplay:debug(('%s: Using frontWheelToRearWheel=%.2f'):format(nameNum(vehicle), totalLength), 6);
		end;

		cpPrintLine(6);
		courseplay:debug(('%s: totalLength=%.2f, totalLengthOffset=%.2f'):format(nameNum(vehicle), totalLength, directionNodeToFrontWheelOffset), 6);
		cpPrintLine(6);

	-- IMPLEMENTS OR TRAILERS
	else
	    local _, y, _ = getWorldTranslation(vehicle.attacherJoint.node);

		local hasRearAttach = false;
		local jointType = 0;

		for _, implement in ipairs(vehicle.attachedImplements) do
			local xi, _, zi = getWorldTranslation(implement.object.attacherJoint.node);
			local delta,_,_ = worldToLocal(vehicle.attacherJoint.node, xi, y, zi);

			-- Check if it's rear attached
			if delta > 0 then
				hasRearAttach = true;
				local length, _ = courseplay:getTotalLengthOnWheels(implement.object);
				if length > 0 then
					jointType = implement.object.attacherJoint.jointType;
					totalLength = length;
				end;
			end;
		end;

		if hasRearAttach and totalLength > 0 and jointType > 0 and vehicle.cp.distances.attacherJointToRearTrailerAttacherJoints then
			local length = vehicle.cp.distances.attacherJointToRearTrailerAttacherJoints[jointType];
			if length then
				totalLength = totalLength + length;
			else
				totalLength = 0;
			end;
			courseplay:debug(('%s: hasRearAttach: totalLength=%.2f'):format(nameNum(vehicle), totalLength), 6);
		elseif vehicle.cp.distances.attacherJointToRearWheel then
			totalLength = vehicle.cp.distances.attacherJointToRearWheel;
			courseplay:debug(('%s: Using attacherJointToRearWheel=%.2f'):format(nameNum(vehicle), totalLength), 6);
		else
			totalLength = 0;
			courseplay:debug(('%s: No length found, returning 0'):format(nameNum(vehicle)), 6);
		end;
	end;

	return totalLength, directionNodeToFrontWheelOffset;
end;

function courseplay:getDistances(object)
	cpPrintLine(6);
	local distances = {};

	-- STEERABLES
	if object.cp.DirectionNode then
		-- Finde the front and rear distance from the direction node
		local front, rear = 0, 0;
		local haveRunnedOnce = false
		for _, wheel in ipairs(object.wheels) do
			local wdnrxTemp, wdnryTemp, wdnrzTemp = getRotation(wheel.driveNode);
			setRotation(wheel.driveNode, 0, 0, 0);
			local wreprxTemp, wrepryTemp, wreprzTemp = getRotation(wheel.repr);
			setRotation(wheel.repr, 0, 0, 0);
			local xw, yw, zw = getWorldTranslation(wheel.driveNode);
			local _,_,dis = worldToLocal(object.cp.DirectionNode, xw, yw, zw);
			setRotation(wheel.repr, wreprxTemp, wrepryTemp, wreprzTemp);
			setRotation(wheel.driveNode, wdnrxTemp, wdnryTemp, wdnrzTemp);
			if haveRunnedOnce then
				if dis < rear then rear = dis; end;
				if dis > front then front = dis; end;
			else
				rear = dis;
				front = dis;
				haveRunnedOnce = true;
			end;
		end;
		-- Set the wheel offset anddistance
		distances.frontWheelToDirectionNodeOffset = front * -1;
		distances.frontWheelToRearWheel = math.abs(front - rear);
		courseplay:debug(('%s: frontWheelToDirectionNodeOffset=%.2f, frontWheelToRearWheel=%.2f'):format(nameNum(object), distances.frontWheelToDirectionNodeOffset, distances.frontWheelToRearWheel), 6);

		-- Finde the attacherJoints distance from the direction node
		for _, attacherJoint in ipairs(object.attacherJoints) do
			local xj, yj, zj = getWorldTranslation(attacherJoint.jointTransform);
			local _,_,dis = worldToLocal(object.cp.DirectionNode, xj, yj, zj);
			if dis < front then
				if not distances.frontWheelToRearTrailerAttacherJoints then
					distances.frontWheelToRearTrailerAttacherJoints = {};
				end;
				distances.frontWheelToRearTrailerAttacherJoints[attacherJoint.jointType] = math.abs(front - dis);
				courseplay:debug(('%s: frontWheelToRearTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.frontWheelToRearTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;
		end

	-- IMPLEMENTS OR TRAILERS
	else
		local node = object.attacherJoint.node;
		if object.attacherJoint.rootNode ~= object.rootNode then
			local tempNode, backTrack = courseplay:findJointNodeConnectingToNode(object, object.attacherJoint.rootNode, object.rootNode);
			if tempNode and backTrack then
				node = tempNode;
				local tnx, tny, tnz = getWorldTranslation(tempNode);
				local xdis,ydis,dis = worldToLocal(object.attacherJoint.node, tnx, tny, tnz);
				local nodeLength = 0;
				for i = 1, #backTrack do
					local btx, bty, btz = getWorldTranslation(backTrack[i]);
					if i == 1 then
						tempNode = object.attacherJoint.node;
					else
						tempNode = backTrack[i-1];
					end;

					-- Save the rotations of the tempNode
					local tnrxTemp, tnryTemp, tnrzTemp = getRotation(tempNode);
					-- Reset all the rotation to 0 for tempNode, to be sure we get valid data.
					setRotation(tempNode, 0, 0, 0);
					-- Get the distance from tempNode to the current backTrack node
					local _,_,dis = worldToLocal(tempNode, btx, bty, btz);
					-- Restore the tempNode rotations.
					setRotation(tempNode, tnrxTemp, tnryTemp, tnrzTemp);
					courseplay:debug(('%s: backTrack[%d](node: %s) Length = %.2f'):format(nameNum(object), i, tostring(backTrack[i]), math.abs(dis)), 6);
					nodeLength = nodeLength + math.abs(dis);
				end;

				distances.attacherJointToPivot = nodeLength
				courseplay:debug(('%s: attacherJointToPivot=%.2f'):format(nameNum(object), distances.attacherJointToPivot), 6);
			end;
		end;

		-- backup node rotation and set the rotation to 0
		local nodeXTemp, nodeYTemp, nodeZTemp = getRotation(node);
		setRotation(node, 0, 0, 0);

		-- Find the distance from attacherJoint to rear wheel
		if object.wheels and #object.wheels > 0 then
			local length = 0;
			for _, wheel in ipairs(object.wheels) do
				local nx, ny, nz = getWorldTranslation(wheel.driveNode);
				local _,_,dis = worldToLocal(node, nx, ny, nz);

				if math.abs(dis) > length then
					length = math.abs(dis);
				end;
			end;

			if distances.attacherJointToPivot then
				distances.pivotToRearWheel = length;
				distances.attacherJointToRearWheel = distances.attacherJointToPivot + length;
			else
				distances.attacherJointToRearWheel = length;
			end;

			courseplay:debug(('%s: attacherJointToRearWheel=%.2f'):format(nameNum(object), distances.attacherJointToRearWheel), 6);
		end;

		-- Finde the attacherJoints distance from the direction node
		for _, attacherJoint in ipairs(object.attacherJoints) do
			local nx, ny, nz = getWorldTranslation(attacherJoint.jointTransform);
			local _,_,dis = worldToLocal(node, nx, ny, nz);
			dis = dis * -1;

			if dis > 0 then
				if not distances.attacherJointToRearTrailerAttacherJoints then
					distances.attacherJointToRearTrailerAttacherJoints = {};
				end;

				if distances.attacherJointToPivot then
					if not distances.pivotToRearTrailerAttacherJoints then
						distances.pivotToRearTrailerAttacherJoints = {};
					end;
					distances.pivotToRearTrailerAttacherJoints[attacherJoint.jointType] = math.abs(dis);
					distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType] = distances.attacherJointToPivot + math.abs(dis);
				else
					distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType] = math.abs(dis);
				end;

				courseplay:debug(('%s: attacherJointToRearTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;
		end;

		-- restore node rotation from backup.
		setRotation(node, nodeXTemp, nodeYTemp, nodeZTemp);
	end;

	return distances;
end;

