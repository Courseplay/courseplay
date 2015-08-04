local abs, max, rad, deg, cos, sin = math.abs, math.max, math.rad, math.deg, math.cos, math.sin;
-- ##### VEHICLE TOOLS ##### --

function courseplay:calculateTurnRadius(type, wheelBase, rotMax, CPRatio)
	local turnRadius = 0;
	CPRatio = CPRatio or 0;

	-- ArticulatedAxis Steering
	if (type == "ASW" or type == "Tool") and CPRatio > 0 and CPRatio < 1  then
		if CPRatio <= 0.5 then
			turnRadius = wheelBase * (1-CPRatio) / sin(rotMax) * (CPRatio * cos(rotMax) + 1 - CPRatio);
		else
			turnRadius = wheelBase * CPRatio / sin(rotMax) * (CPRatio + (1 - CPRatio) * cos(rotMax));
		end;

		-- 4 Wheel Steering
	elseif type == "4WS" then
		turnRadius = wheelBase / (2 * sin(rotMax)) * cos(rotMax);

		-- 2 Wheel Steering
	elseif (type == "2WS" or type == "Tool") then
		turnRadius = wheelBase / sin(rotMax) * cos(rotMax);
	end;

	return turnRadius;
end;

function courseplay:createNewLinkedNode(object, nodeName, linkToNode)
	if not object.cp.notesToDelete then object.cp.notesToDelete = {}; end;

	local node = createTransformGroup(nodeName);
	link(linkToNode, node);
	table.insert(object.cp.notesToDelete, 1, node);

	return node;
end;

function courseplay:deleteCollisionVehicle(vehicle)
	if vehicle.cp.collidingVehicleId ~= nil  then
		local Id = vehicle.cp.collidingVehicleId
		if g_currentMission.nodeToVehicle[Id] and g_currentMission.nodeToVehicle[Id].isCpPathvehicle  then
			g_currentMission.nodeToVehicle[Id] = nil
		end
		vehicle.cp.collidingObjects.all[Id] = nil
		--vehicle.CPnumCollidingVehicles = max(vehicle.CPnumCollidingVehicles - 1, 0);
		--if vehicle.CPnumCollidingVehicles == 0 then
		--vehicle.numCollidingVehicles[triggerId] = max(vehicle.numCollidingVehicles[triggerId]-1, 0);
		vehicle.cp.collidingObjects[4][Id] = nil
		vehicle.cp.collidingVehicleId = nil
		courseplay:debug(string.format('%s: 	deleteCollisionVehicle: setting "collidingVehicleId" to nil', nameNum(vehicle)), 3);
	end
end

--- courseplay:findJointNodeConnectingToNode(workTool, fromNode, toNode)
--	Returns: (node, backtrack, rotLimits)
--		node will return either:		1. The jointNode that connects to the toNode,
--										2. The toNode if no jointNode is found but the fromNode is inside the same component as the toNode
--										3. nil in case none of the above fails.
--		backTrack will return either:	1. A table of all the jointNodes found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
--		rotLimits will return either:	1. A table of all the rotLimits of the componentJoint, found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
function courseplay:findJointNodeConnectingToNode(workTool, fromNode, toNode)
	if fromNode == toNode then return toNode; end;

	-- Attempt to find the jointNode by backtracking the compomentJoints.
	for index, component in ipairs(workTool.components) do
		if courseplay:isPartOfNode(fromNode, component.node) then
			for _, joint in ipairs(workTool.componentJoints) do
				if joint.componentIndices[2] == index then
					if workTool.components[joint.componentIndices[1]].node == toNode then
						--          node            backtrack         rotLimits
						return joint.jointNode, {joint.jointNode}, {joint.rotLimit};
					else
						local node, backTrack, rotLimits = courseplay:findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[1]].node, toNode);
						if backTrack then table.insert(backTrack, 1, joint.jointNode); end;
						if rotLimits then table.insert(rotLimits, 1, joint.rotLimit); end;
						return node, backTrack, rotLimits;
					end;
				end;
			end;
		end;
	end;

	-- Last attempt to find the jointNode by getting parent of parent untill hit or the there is no more parents.
	if courseplay:isPartOfNode(fromNode, toNode) then
		return toNode, nil;
	end;

	-- If anything else fails, return nil
	return nil, nil;
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
		distances.frontWheelToRearWheel = abs(front - rear);
		courseplay:debug(('%s: frontWheelToDirectionNodeOffset=%.2f, frontWheelToRearWheel=%.2f'):format(nameNum(object), distances.frontWheelToDirectionNodeOffset, distances.frontWheelToRearWheel), 6);

		-- Finde the attacherJoints distance from the direction node
		for _, attacherJoint in ipairs(object.attacherJoints) do
			local xj, yj, zj = getWorldTranslation(attacherJoint.jointTransform);
			local _,_,dis = worldToLocal(object.cp.DirectionNode, xj, yj, zj);
			if dis < front then
				if not distances.frontWheelToRearTrailerAttacherJoints then
					distances.frontWheelToRearTrailerAttacherJoints = {};
				end;
				distances.frontWheelToRearTrailerAttacherJoints[attacherJoint.jointType] = abs(front - dis);
				courseplay:debug(('%s: frontWheelToRearTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.frontWheelToRearTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;
		end

		-- Finde the attacherJoints distance from the turning node
		local turningNode = courseplay:getRealTurningNode(object);
		for _, attacherJoint in ipairs(object.attacherJoints) do
			local xj, yj, zj = getWorldTranslation(attacherJoint.jointTransform);
			local _, _, deltaZ = worldToLocal(object.cp.DirectionNode, xj, yj, zj);

			-- If we are behind the front wheel, then it should be an attacherJoing on the rear
			if deltaZ < front then
				local _,_,dis = worldToLocal(turningNode, xj, yj, zj);
				dis = dis * -1;
				if not distances.turningNodeToRearTrailerAttacherJoints then
					distances.turningNodeToRearTrailerAttacherJoints = {};
				end;
				distances.turningNodeToRearTrailerAttacherJoints[attacherJoint.jointType] = dis;
				courseplay:debug(('%s: turningNodeToRearTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.turningNodeToRearTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;
		end

	-- IMPLEMENTS OR TRAILERS
	else
		local node = object.attacherJoint.node;
		local isHookLift = courseplay:isHookLift(object);
		if object.attacherJoint.rootNode ~= object.rootNode and not isHookLift then
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
					courseplay:debug(('%s: backTrack[%d](node: %s) Length = %.2f'):format(nameNum(object), i, tostring(backTrack[i]), abs(dis)), 6);
					nodeLength = nodeLength + abs(dis);
				end;

				distances.attacherJointToPivot = nodeLength
				courseplay:debug(('%s: attacherJointToPivot=%.2f'):format(nameNum(object), distances.attacherJointToPivot), 6);
			end;
		end;

		-- backup node rotation and set the rotation to 0
		local nodeXTemp, nodeYTemp, nodeZTemp = getRotation(node);
		setRotation(node, 0, 0, 0);

		-- Find the distance from attacherJoint to rear wheel
		if object.wheels and #object.wheels > 0 and not isHookLift then
			local length = 0;
			for _, wheel in ipairs(object.wheels) do
				local nx, ny, nz = getWorldTranslation(wheel.driveNode);
				local _,_,dis = worldToLocal(node, nx, ny, nz);

				if abs(dis) > length then
					length = abs(dis);
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
					distances.pivotToRearTrailerAttacherJoints[attacherJoint.jointType] = abs(dis);
					distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType] = distances.attacherJointToPivot + abs(dis);
				else
					distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType] = abs(dis);
				end;

				courseplay:debug(('%s: attacherJointToRearTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;
		end;

		if distances.attacherJointToRearWheel then
			local turningNode = courseplay:getRealTurningNode(object);
			-- Finde the attacherJoints distance from the turning node
			for _, attacherJoint in ipairs(object.attacherJoints) do
				local nx, ny, nz = getWorldTranslation(attacherJoint.jointTransform);
				local _,_,dis = worldToLocal(turningNode, nx, ny, nz);
				dis = dis * -1;

				if not distances.turningNodeToTrailerAttacherJoints then
					distances.turningNodeToTrailerAttacherJoints = {};
				end;

				distances.turningNodeToTrailerAttacherJoints[attacherJoint.jointType] = dis;

				courseplay:debug(('%s: turningNodeToTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.turningNodeToTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;

			-- Finde the attacherJoint/Pivot distance to the turning node
			local nx, ny, nz = getWorldTranslation(node);
			local _,_,dis = worldToLocal(turningNode, nx, ny, nz);
			distances.pivotToTurningNode = dis;
			courseplay:debug(('%s: pivotToTurningNode=%.2f'):format(nameNum(object), distances.pivotToTurningNode), 6);

		end;

		-- restore node rotation from backup.
		setRotation(node, nodeXTemp, nodeYTemp, nodeZTemp);
	end;

	return distances;
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

				if courseplay:isInvertedToolNode(workTool, node) then
					setRotation(node, 0, rad(180), 0);
				end;

				workTool.cp.realFrontNode = node;
			end;
		else
			workTool.cp.realFrontNode = courseplay:getRealTurningNode(workTool);
		end;
	end;

	return workTool.cp.realFrontNode
end;

function courseplay:getRealTurningNode(object)
	if not object.cp.turningNode then
		local node = courseplay:createNewLinkedNode(object, "realTurningNode", object.rootNode);

		local _, y, _ = getWorldTranslation(object.rootNode);
		local minDis, maxDis = 0, 0;
		local minDisRot, maxDisRot = 0, 0;
		local haveStraitWheels, haveTurningWheels = false, false;
		local Distance = 0;

		-- STEERABLES
		if object.cp.DirectionNode then
			local ASInfo = object.cp.ackermannSteering;
			-- Giants have provided us with some info to use, so use them.
			if ASInfo and (ASInfo.rotCenterZ or ASInfo.rotCenterWheels) and not object.articulatedAxis then
				-- The offset is already set for us to use.
				if ASInfo.rotCenterZ then
					setTranslation(node, 0, 0, ASInfo.rotCenterZ);

					-- Check if it's actually an four wheel steering
					if not object.crawlers or #object.crawlers == 0 then
						for index, wheel in ipairs(object.wheels) do
							-- Strait wheels
							if wheel.rotMax == 0 and wheel.maxLatStiffness > 0 then
								haveStraitWheels = true;

							-- Turning wheels
							else
								haveTurningWheels = true;
							end;
						end;

						if not haveStraitWheels and haveTurningWheels then
							object.cp.isFourWheelSteering = true;
						end;
					end;

				-- We know which wheels that is the center.
				else
					for i, index in pairs(ASInfo.rotCenterWheels) do
						local x,_,z = getWorldTranslation(object.wheels[index].driveNode);
						local _,_,dis = worldToLocal(object.rootNode, x, y, z);
						if i > 1 then
							if dis < minDis then minDis = dis; end;
							if dis > maxDis then maxDis = dis; end;
						else
							minDis = dis;
							maxDis = dis;
						end;
					end;

					if minDis == maxDis then
						Distance = minDis;
					else
						Distance = (minDis + maxDis) * 0.5;
					end;

					if Distance ~= 0 then
						setTranslation(node, 0, 0, Distance);
					end;
				end;
			else
				-- Find the pivot point on articulated vehicle
				if object.articulatedAxis then
					local jointNode = object.articulatedAxis.componentJoint.jointNode;
					local x,_,z = getWorldTranslation(jointNode);
					local _,_,Distance = worldToLocal(object.rootNode, x, y, z);

				-- Get the distance from root node to the wheels turning point.
				else
					local rotMax = 0;

					-- Sort wheels in turning wheels and strait wheels and find the min and max distance for each set.
					for index, wheel in ipairs(object.wheels) do
						local x,_,z = getWorldTranslation(wheel.repr);
						local _,_,dis = worldToLocal(object.rootNode, x, y, z);

						-- Strait wheels
						if wheel.rotMax == 0 and wheel.maxLatStiffness > 0 then
							if haveStraitWheels then
								if dis < minDis then minDis = dis; end;
								if dis > maxDis then maxDis = dis; end;
							else
								minDis = dis;
								maxDis = dis;
								haveStraitWheels = true;
							end;

						-- Turning wheels
						else
							if abs(wheel.rotMax) > rotMax then
								rotMax = abs(wheel.rotMax)
							end;
							if haveTurningWheels then
								if dis < minDisRot then minDisRot = dis; end;
								if dis > maxDisRot then maxDisRot = dis; end;
							else
								minDisRot = dis;
								maxDisRot = dis;
								haveTurningWheels = true;
							end;
						end;
					end;

					-- 2WS: Calculate strait wheel median distance
					if haveStraitWheels then
						if minDis == maxDis then
							Distance = minDis;
						else
							Distance = (minDis + maxDis) * 0.5;
						end;

					-- 4WS: Calculate turning wheel median distance if there are no strait wheels.
					elseif haveTurningWheels then
						object.cp.isFourWheelSteering = true;
						object.cp.fourWheelSteerMaxRot = rotMax;
						if minDisRot == maxDisRot then
							Distance = minDisRot;
						else
							Distance = (minDisRot + maxDisRot) * 0.5;
						end;
					end;

					if Distance ~= 0 then
						setTranslation(node, 0, 0, Distance);
					end;
				end;
			end;

		-- IMPLEMENTS OR TRAILERS
		else
			local invert = courseplay:isInvertedToolNode(object) and -1 or 1;
			local steeringAxleScale = 0;

			-- Get the distance from root node to the wheels turning point.
			if object.wheels and #object.wheels > 0 then
				local steeringAxleScaleMin, steeringAxleScaleMax = 0, 0;

				-- Sort wheels in turning wheels and strait wheels and find the min and max distance for each set.
				for i = 1, #object.wheels do
					if courseplay:isPartOfNode(object.wheels[i].node, object.rootNode) and object.wheels[i].maxLatStiffness > 0 then
						local x,_,z = getWorldTranslation(object.wheels[i].driveNode);
						local _,_,dis = worldToLocal(object.rootNode, x, y, z);
						dis = dis * invert;
						if object.steeringAxleUpdateBackwards == false or object.wheels[i].steeringAxleScale == 0 then
							if haveStraitWheels then
								if dis < minDis then minDis = dis; end;
								if dis > maxDis then maxDis = dis; end;
							else
								minDis = dis;
								maxDis = dis;
								haveStraitWheels = true;
							end;
						else
							if object.wheels[i].steeringAxleScale < 0 and object.wheels[i].steeringAxleScale < steeringAxleScaleMin then
								steeringAxleScaleMin = object.wheels[i].steeringAxleScale;
							elseif object.wheels[i].steeringAxleScale > 0 and object.wheels[i].steeringAxleScale > steeringAxleScaleMax then
								steeringAxleScaleMax = object.wheels[i].steeringAxleScale;
							end;
							if haveTurningWheels then
								if dis < minDisRot then minDisRot = dis; end;
								if dis > maxDisRot then maxDisRot = dis; end;
							else
								minDisRot = dis;
								maxDisRot = dis;
								haveTurningWheels = true;
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
				elseif haveTurningWheels then
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
			if courseplay:isInvertedToolNode(object, node) then
				setRotation(node, 0, rad(180), 0);
			end;

			if not haveStraitWheels and object.steeringAxleUpdateBackwards and steeringAxleScale < 0 then
				local tempNode, _ = courseplay:findJointNodeConnectingToNode(object, object.attacherJoint.rootNode, object.rootNode);
				if tempNode then
					local x, y, z;
					if tempNode == object.rootNode then
						x, y, z = getWorldTranslation(object.attacherJoint.node);
					else
						x, y, z = getWorldTranslation(tempNode);
					end;
					local _,_,dis = worldToLocal(node, x, y, z);
					local offset = (dis * abs(steeringAxleScale)) + Distance;
					setTranslation(node, 0, 0, offset);
					object.cp.steeringAxleUpdateBackwards = true;
				end;
			end;
		end;

		object.cp.turningNode = node;
	end;

	return object.cp.turningNode;
end;

function courseplay:getRealUnloadOrFillNode(workTool)
	if workTool.cp.unloadOrFillNode == nil then
		-- BALELOADERS and STRAWBLOWERS
		if courseplay:isBaleLoader(workTool) or (courseplay:isSpecialBaleLoader(workTool) and workTool.cp.specialUnloadDistance) or workTool.cp.isStrawBlower then
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

			if courseplay:isInvertedToolNode(workTool, node) then
				setRotation(node, 0, rad(180), 0);
			end;

			workTool.cp.unloadOrFillNode = node;

			-- NONE OF THE ABOVE
		else
			workTool.cp.unloadOrFillNode = false;
		end;
	end;

	return workTool.cp.unloadOrFillNode;
end;

function courseplay:getHighestToolTurnDiameter(object)
	local turnDiameter = 0;

	-- Tool attached to Steerable
	for _, implement in ipairs(object.attachedImplements) do
		local workTool = implement.object;

		if courseplay:isRearAttached(object, implement.jointDescIndex) then
			local ttr =  courseplay:getToolTurnRadius(workTool);
			turnDiameter = ttr * 2;
			courseplay:debug(('%s: toolTurnDiameter=%.2fm'):format(nameNum(workTool), turnDiameter), 6);

			-- Check rear attached tools for turnDiameters
			if workTool.attachedImplements and workTool.attachedImplements ~= {} then
				local ttd = courseplay:getHighestToolTurnDiameter(workTool);
				if ttd > turnDiameter then
					turnDiameter = ttd;
				end;
			end;
		end;
	end;

	return turnDiameter;
end;

function courseplay:getToolTurnRadius(workTool)
	local turnRadius	= 0; -- Default value if none is set

	if courseplay:isWheeledWorkTool(workTool) then
		local wheelBase		= 0;
		local rotMax		= 0;
		local CPRatio		= 0;
		local type			= "Tool";
		local TR			= 0;
		local frontLength	= 0;

		local attacherVehicle			= workTool.attacherVehicle;
		local attacherVehicleDistances	= attacherVehicle.cp.distances or courseplay:getDistances(attacherVehicle);
		local workToolDistances			= workTool.cp.distances or courseplay:getDistances(workTool);

		for i, attachedImplement in pairs(attacherVehicle.attachedImplements) do
			if attachedImplement.object == workTool then
				rotMax = attachedImplement.maxRotLimit[2];
				break;
			end;
		end;

		-- We have turningNodeToRearTrailerAttacherJoints value
		if attacherVehicleDistances.turningNodeToRearTrailerAttacherJoints then
			frontLength = attacherVehicleDistances.turningNodeToRearTrailerAttacherJoints[workTool.attacherJoint.jointType] or 0;

		-- We have turningNodeToTrailerAttacherJoints value
		elseif attacherVehicleDistances.turningNodeToTrailerAttacherJoints then
			frontLength = attacherVehicleDistances.turningNodeToTrailerAttacherJoints[workTool.attacherJoint.jointType] or 0;

		-- We have to go backwards to find the real front distance (attacherVehicle dont have wheels and might be a weight or something else)
		else
			frontLength = attacherVehicleDistances.attacherJointToRearTrailerAttacherJoints[workTool.attacherJoint.jointType] or 0;
			local backTrackVehicle = attacherVehicle;
			local oldBackTrackVehicle;
			while true do
				oldBackTrackVehicle = backTrackVehicle;
				backTrackVehicle = oldBackTrackVehicle.attacherVehicle;
				if backTrackVehicle and backTrackVehicle ~= {} then
					local distances = backTrackVehicle.cp.distances or courseplay:getDistances(backTrackVehicle);
					local jointType = oldBackTrackVehicle.attacherJoint.jointType;
					if distances.turningNodeToRearTrailerAttacherJoints then
						frontLength = frontLength + distances.turningNodeToRearTrailerAttacherJoints[jointType];
						break;
					elseif distances.turningNodeToTrailerAttacherJoints then
						frontLength = frontLength + distances.turningNodeToTrailerAttacherJoints[jointType];
						break;
					else
						frontLength = frontLength + (distances.attacherJointToRearTrailerAttacherJoints[jointType] or 0);
					end;
				else
					break;
				end;
			end;
		end;
		courseplay:debug(('%s -> TurnRadius: rotMax=%d°, frontLength=%.2fm'):format(nameNum(workTool), deg(rotMax), frontLength), 6);

		-- WE ARE A PIVOTED TRAILER / IMPLEMENT
		if workToolDistances.attacherJointToPivot then
			local pivotRotMax = 0;
			local _, _, rotLimits = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
			if rotLimits then
				for _, rotLimit in pairs(rotLimits) do
					if rotLimit[2] > pivotRotMax and rotLimit[2] > rad(15) then
						pivotRotMax = rotLimit[2];
					end;
				end;
			end;
			courseplay:debug(('%s -> TurnRadius: pivotRotMax=%d° (Pivot trailer/implement)'):format(nameNum(workTool), deg(pivotRotMax)), 6);

			-- We are an implement and should be handled a bit different
			if workTool.attacherJoint.jointType == Vehicle.jointTypeNameToInt["implement"] then
				-- We have a valid pivotRotMax, so calculate it normally.
				if pivotRotMax > rad(15) then
					frontLength = frontLength + workToolDistances.attacherJointToPivot;
					wheelBase = frontLength + workToolDistances.pivotToTurningNode;
					CPRatio = courseplay:getCenterPivotRatio(nil, wheelbase, frontLength);
					TR = courseplay:calculateTurnRadius(type, wheelBase, pivotRotMax, CPRatio);

				-- If pivotRotMax is not greater than 15 degrees,
				-- then giants have fucked up and we cant get the real pivotRotMax value.
				-- We will then use half of the length from attacherJoint to turningNode as the turnRadius instead.
				else
					TR = (workToolDistances.attacherJointToPivot + workToolDistances.pivotToTurningNode) / 2;
				end;
				courseplay:debug(('%s -> TurnRadius: turnRadius=%.2fm (Pivot implement)'):format(nameNum(workTool), TR), 6);

			-- We are an pivoted trailer
			else
				-- Dolly part
				wheelBase = frontLength + workToolDistances.attacherJointToPivot;
				CPRatio = courseplay:getCenterPivotRatio(nil, wheelbase, frontLength);
				local pivotTR = courseplay:calculateTurnRadius(type, wheelBase, rotMax, CPRatio);

				-- Trailer part
				wheelBase = workToolDistances.pivotToTurningNode;
				CPRatio = 0;
				TR = courseplay:calculateTurnRadius(type, wheelBase, pivotRotMax, CPRatio);

				-- Take the highest one
				if pivotTR > TR then
					TR = pivotTR;
				end;
				courseplay:debug(('%s -> TurnRadius: turnRadius=%.2fm (Pivot trailer)'):format(nameNum(workTool), TR), 6);
			end;

		-- WE ARE A NORMAL TRAILER OR IMPLEMENT
		else
			wheelBase = frontLength + (workToolDistances.pivotToTurningNode or 0);
			CPRatio = courseplay:getCenterPivotRatio(nil, wheelbase, frontLength);

			TR = courseplay:calculateTurnRadius(type, wheelBase, rotMax, CPRatio);
			courseplay:debug(('%s -> TurnRadius: turnRadius=%.2fm (Normal trailer/implement)'):format(nameNum(workTool), TR), 6);
		end;

		if TR > 0 then
			turnRadius = TR;
		end;

		-- If we are not an implement then check if half trailer length is bigger than the turnRadius and set it, if it is.
		if workTool.attacherJoint.jointType ~= Vehicle.jointTypeNameToInt["implement"] and workToolDistances.attacherJointToRearWheel then
			if (workToolDistances.attacherJointToRearWheel / 2) > turnRadius then
				turnRadius = workToolDistances.attacherJointToRearWheel / 2;
				courseplay:debug(('%s -> TurnRadius: Using half tool length = %.2fm'):format(nameNum(workTool), turnRadius), 6);
			end;
		end;
	else
		courseplay:debug(('%s -> TurnRadius: Have no wheels. turnRadius set to 0m'):format(nameNum(workTool), turnDiameter), 6);
	end;

	return turnRadius;
end;

function courseplay:getTotalLengthOnWheels(vehicle)
	courseplay:debug(('%s: getTotalLengthOnWheels()'):format(nameNum(vehicle)), 6);
	local totalLength = 0;
	local directionNodeToFrontWheelOffset;

	if not vehicle.cp.distances then
		vehicle.cp.distances = courseplay:getDistances(vehicle);
	end;

	-- STEERABLES
	if vehicle.cp.DirectionNode then
		directionNodeToFrontWheelOffset = vehicle.cp.distances.frontWheelToDirectionNodeOffset;

		local _, y, _ = getWorldTranslation(vehicle.cp.DirectionNode);

		local hasRearAttach = false;
		local jointType = 0;

		for _, implement in ipairs(vehicle.attachedImplements) do
			-- Check if it's rear attached
			if courseplay:isRearAttached(vehicle, implement.jointDescIndex) then
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
			-- Check if it's rear attached
			if courseplay:isRearAttached(vehicle, implement.jointDescIndex) then
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

function courseplay:getVehicleTurnRadius(vehicle)
	local turnRadius	= 5; -- Default value if none is set
	local wheelBase		= 0;
	local CPRatio		= 0;
	local rotMax		= 0;
	local TR			= 0;
	local type			= "2WS";

	-- Make sure the turning node have been updated (Script will only run once)
	courseplay:getRealTurningNode(vehicle);

	-- Giants have provided us with some info to use, so use them.
	if vehicle.cp.ackermannSteering and not vehicle.articulatedAxis then
		wheelBase = courseplay:getWheelBase(vehicle, true);
		rotMax = vehicle.cp.ackermannSteering.rotMax;

	-- We need to calculate it our self.
	else
		-- ArticulatedAxis Steering
		if vehicle.articulatedAxis then
			wheelBase = courseplay:getWheelBase(vehicle);
			CPRatio = courseplay:getCenterPivotRatio(vehicle, wheelbase);
			rotMax = abs(vehicle.articulatedAxis.rotMax);
			type = "ASW";

		-- 4 Wheel Steering
		elseif vehicle.cp.fourWheelSteerMaxRot then
			wheelBase = courseplay:getWheelBase(vehicle);
			rotMax = vehicle.cp.fourWheelSteerMaxRot;
			type = "4WS";

		-- 2 Wheel Steering
		elseif vehicle.wheels then
			for _, wheel in ipairs(vehicle.wheels) do
				if abs(wheel.rotMax) > rotMax then
					rotMax = abs(wheel.rotMax);
				end;
			end;
			wheelBase = courseplay:getWheelBase(vehicle, true);
		end;
	end;

	TR = courseplay:calculateTurnRadius(type, wheelBase, rotMax, CPRatio);

	if TR > 0 then
		turnRadius = TR;
	end;

	return turnRadius
end;

function courseplay:getWheelBase(vehicle, fromTurningNode)
	local wheelBase = 0;

	-- 2 Wheel Stering
	if fromTurningNode then
		local turningNode = courseplay:getRealTurningNode(vehicle);
		local _, y, _ = getWorldTranslation(turningNode);
		for _, wheel in ipairs(vehicle.wheels) do
			local x, _, z = getWorldTranslation(wheel.repr);
			local _, _, dis = worldToLocal(turningNode, x, y, z);

			if abs(dis) > wheelBase then
				wheelBase = abs(dis);
			end;
		end;

	-- 4 Wheel Steering and ArticulatedAxis Steering
	else
		local minDis, maxDis = 0, 0;
		local _, y, _ = getWorldTranslation(vehicle.rootNode);
		for i, wheel in ipairs(vehicle.wheels) do
			local x,_,z = getWorldTranslation(wheel.repr);
			local _,_,dis = worldToLocal(vehicle.rootNode, x, y, z);
			if i > 1 then
				if dis < minDis then minDis = dis; end;
				if dis > maxDis then maxDis = dis; end;
			else
				minDis = dis;
				maxDis = dis;
			end;
		end;

		wheelBase = abs(maxDis - minDis);
	end;

	return wheelBase;
end;

function courseplay:getCenterPivotRatio(vehicle, wheelbase, frontLength)
	if not wheelbase then
		if vehicle then
			wheelbase = courseplay:getWheelBase(vehicle);
		else
			wheelbase = 0;
		end;
	end;

	local distance = 0;
	if frontLength then
		if frontLength > 0 then
			distance = frontLength;
		end;
	else
		local turningNode = courseplay:getRealTurningNode(vehicle);
		local _, y, _ = getWorldTranslation(turningNode);
		for _, wheel in ipairs(vehicle.wheels) do
			local x, _, z = getWorldTranslation(wheel.repr);
			local _, _, dis = worldToLocal(turningNode, x, y, z);

			if dis > distance then
				distance = dis;
			end;
		end;
	end;

	local ratio = 0;
	if wheelbase > 0 then
		ratio = 1 / wheelbase * distance;
	end;

	return ratio;
end

function courseplay:isInvertedToolNode(workTool, node)
	-- Only check trailers
	if workTool.cp.DirectionNode then
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

function courseplay:isPartOfNode(node, partOfNode)
	-- Check if Node is part of partOfNode and not in a different component
	while node ~= 0 and node ~= nil do
		if node == partOfNode then
			return true;
		else
			node = getParent(node);
		end;
	end;

	return false;
end;

function courseplay:isRearAttached(object, jointDescIndex)
	local turningNode = object.cp.DirectionNode or courseplay:getRealTurningNode(object);
	local x, y, z = localToWorld(turningNode, 0, 0, 50);
	local deltaX, _, _ = worldToLocal(object.attacherJoints[jointDescIndex].jointTransform, x, y, z);

	if courseplay:isInvertedToolNode(object) then
		deltaX = deltaX * -1;
	end;

	return deltaX < 0;
end;

local allowedJointType = {};
function courseplay:isWheeledWorkTool(workTool)
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

function courseplay:setAckermannSteeringInfo(vehicle, xmlFile)
	if xmlFile ~= nil and xmlFile ~= 0 then
		local mainKey = "vehicle.ackermannSteering#";
		local rotMax = getXMLInt(xmlFile, mainKey.."rotMax");

		-- If rotMax is not set, Giants don't calculate the ackermannSteering.
		if not rotMax then
			return;

			-- Else set rotMax value
		else
			local ASInfo = {};
			ASInfo.rotMax = rad(rotMax);

			-- Get rotCenter if avalible.
			local str = getXMLString(xmlFile, mainKey.."rotCenter");
			if str then
				local centerWheels = Utils.splitString(' ', str);
				if #centerWheels == 2 then
					ASInfo.rotCenterX = tonumber(centerWheels[1]);
					ASInfo.rotCenterZ = tonumber(centerWheels[2]);
				end;
			end;

			-- Get all rotCenterWheel# if avalible.
			local i = 1;
			while true do
				local key = mainKey .. "rotCenterWheel" .. tostring(i);
				local val = getXMLInt(xmlFile, key);
				if val and vehicle.wheels[val + 1].driveNode then
					if not ASInfo.rotCenterWheels then
						ASInfo.rotCenterWheels = {};
					end;

					table.insert(ASInfo.rotCenterWheels, val + 1);
				else
					break;
				end;
				i = i + 1;
			end;

			vehicle.cp.ackermannSteering = ASInfo;
		end;
	end;
end;

function courseplay:setPathVehiclesSpeed(vehicle,dt)
	pathVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId]
	--print("update speed")
	if pathVehicle.speedDisplayDt == nil then
		pathVehicle.speedDisplayDt = 0
		pathVehicle.lastSpeed = 0
		pathVehicle.lastSpeedReal = 0
		pathVehicle.movingDirection = 1
	end
	pathVehicle.speedDisplayDt = pathVehicle.speedDisplayDt + dt
	if pathVehicle.speedDisplayDt > 100 then
		local newX, newY, newZ = getWorldTranslation(pathVehicle.rootNode)
		if pathVehicle.lastPosition == nil then
		  pathVehicle.lastPosition = {
			newX,
			newY,
			newZ
		  }
		end
		local lastMovingDirection = pathVehicle.movingDirection
		local dx, dy, dz = worldDirectionToLocal(pathVehicle.rootNode, newX - pathVehicle.lastPosition[1], newY - pathVehicle.lastPosition[2], newZ - pathVehicle.lastPosition[3])
		if dz > 0.001 then
		  pathVehicle.movingDirection = 1
		elseif dz < -0.001 then
		  pathVehicle.movingDirection = -1
		else
		  pathVehicle.movingDirection = 0
		end
		pathVehicle.lastMovedDistance = Utils.vector3Length(dx, dy, dz)
		local lastLastSpeedReal = pathVehicle.lastSpeedReal
		pathVehicle.lastSpeedReal = pathVehicle.lastMovedDistance * 0.01
		pathVehicle.lastSpeedAcceleration = (pathVehicle.lastSpeedReal * pathVehicle.movingDirection - lastLastSpeedReal * lastMovingDirection) * 0.01
		pathVehicle.lastSpeed = pathVehicle.lastSpeed * 0.85 + pathVehicle.lastSpeedReal * 0.15
		pathVehicle.lastPosition[1], pathVehicle.lastPosition[2], pathVehicle.lastPosition[3] = newX, newY, newZ
		pathVehicle.speedDisplayDt = pathVehicle.speedDisplayDt - 100
	 end
end

