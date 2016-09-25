local abs, min, max, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.ceil, math.sqrt, math.pi, math.rad, math.deg;

function courseplay:newturn(vehicle, dt)
	---- TURN STAGES:
	-- 0:	Raise implements
	-- 1:	Create Turn maneuver (Creating waypoints to follow)
	-- 2:	Drive Turn maneuver
	-- 3:	Lower implement and continue on next lane

	local allowedToDrive 			= true;
	local moveForwards 				= true;
	local refSpeed 					= vehicle.cp.speeds.turn;
	local directionForce 			= 1;
	local lx, lz 					= 0, 1;
	local turnOutTimer 				= 1500;
	local turnTimer 				= 1500;
	local wpChangeDistance 			= 1.5;
	local reverseWPChangeDistance	= 5;

	local frontMarker = Utils.getNoNil(vehicle.cp.aiFrontMarker, -3);
	local backMarker = Utils.getNoNil(vehicle.cp.backMarkerOffset,0);
	if vehicle.cp.noStopOnEdge then
		turnOutTimer = 0;
	end;

	if not vehicle.cp.checkMarkers then
		vehicle.cp.checkMarkers = true;
		for _,workTool in pairs(vehicle.cp.workTools) do
			courseplay:setMarkers(vehicle, workTool);
			courseplay:askForSpecialSettings(vehicle, workTool);
		end;
	end;

	local vehicleX, vehicleY, vehicleZ = getWorldTranslation(vehicle.cp.DirectionNode);

	local newTarget = vehicle.cp.turnTargets[vehicle.cp.curTurnIndex];
	if newTarget and newTarget.turnReverse then
		wpChangeDistance = reverseWPChangeDistance;
	end;

	----------------------------------------------------------
	-- Debug prints
	----------------------------------------------------------
	if courseplay.debugChannels[14] then
		if #vehicle.cp.turnTargets > 0 then
			-- Draw debug points for waypoints.
			for _, turnTarget in ipairs(vehicle.cp.turnTargets) do
				local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.posX, 1, turnTarget.posZ);
				if turnTarget.turnReverse then
					drawDebugPoint(turnTarget.posX, posY + 3, turnTarget.posZ, 0, 1, 0, 1); -- Green Dot
					if turnTarget.revPosX and turnTarget.revPosZ then
						posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.revPosX, 1, turnTarget.revPosZ);
						drawDebugPoint(turnTarget.revPosX, posY + 3, turnTarget.revPosZ, 1, 0, 0, 1);  -- Red Dot
					end;
				else
					drawDebugPoint(turnTarget.posX, posY + 3, turnTarget.posZ, 0, 1, 1, 1);  -- Light Blue Dot
				end;
			end;
		end;
	end;

	----------------------------------------------------------
	-- Get the directionNodeToTurnNodeLength used for reverse turn distances
	----------------------------------------------------------
	local directionNodeToTurnNodeLength = courseplay:getDirectionNodeToTurnNodeLength(vehicle);

	----------------------------------------------------------
	-- Get the firstReverseWheledWorkTool used for reversing
	----------------------------------------------------------
	local reversingWorkTool = courseplay:getFirstReversingWheeledWorkTool(vehicle);

	----------------------------------------------------------
	-- TURN STAGES 1 - 3
	----------------------------------------------------------
	if vehicle.cp.turnStage > 0 then

		----------------------------------------------------------
		-- TURN STAGES 1 - Create Turn maneuver (Creating waypoints to follow)
		----------------------------------------------------------
		if vehicle.cp.turnStage == 1 then
			----------------------------------------------------------
			-- Cleanup in case we already have old info
			----------------------------------------------------------
			courseplay:clearTurnTargets(vehicle); -- Make sure we have cleaned it from any previus usage.
			vehicle.cp.curTurnIndex = 1; -- Reset the current target index to the first one.

			----------------------------------------------------------
			-- Setting default turnInfo values
			----------------------------------------------------------
			local turnInfo = {};
			turnInfo.halfVehicleWidth = 2;
			turnInfo.directionNodeToTurnNodeLength = directionNodeToTurnNodeLength;
			turnInfo.reverseWPChangeDistance = reverseWPChangeDistance;
			turnInfo.direction = -1;
			turnInfo.headlandHeight = 0;
			turnInfo.haveWheeledImplement = reversingWorkTool ~= nil;

			----------------------------------------------------------
			-- Get the turn radius either by the automatic or user provided turn circle.
			----------------------------------------------------------
			turnInfo.turnRadius = vehicle.cp.turnDiameter / 2 + 0.5; -- The + 0.5m is a safty messure in really small turn radiuses
			turnInfo.turnDiameter = turnInfo.turnRadius * 2;

			----------------------------------------------------------
			-- Get the new turn target with offset
			----------------------------------------------------------
			if (vehicle.cp.laneOffset ~= nil and vehicle.cp.laneOffset ~= 0) or (vehicle.cp.toolOffsetX ~= nil and vehicle.cp.toolOffsetX ~= 0) then
				courseplay:debug(string.format("%s:(Turn) turnWithOffset = true", nameNum(vehicle)), 14);
				courseplay:turnWithOffset(vehicle);
			end;

			local totalOffsetX = vehicle.cp.totalOffsetX * -1

			----------------------------------------------------------
			-- Create temp target node and translate it.
			----------------------------------------------------------
			turnInfo.targetNode = createTransformGroup("cpTempTargetNode");
			link(g_currentMission.terrainRootNode, turnInfo.targetNode);
			local cx,cz = vehicle.Waypoints[vehicle.cp.waypointIndex+1].cx, vehicle.Waypoints[vehicle.cp.waypointIndex+1].cz;
			local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
			setTranslation(turnInfo.targetNode, cx, cy, cz);

			--- Rotate it's direction to the next wp.
			local dx, dz = courseplay.generation:getPointDirection(vehicle.Waypoints[vehicle.cp.waypointIndex+1], vehicle.Waypoints[vehicle.cp.waypointIndex+2]);
			local yRot = Utils.getYRotationFromDirection(dx, dz);
			setRotation(turnInfo.targetNode, 0, yRot, 0);

			--- Retranslate it again to the correct position if there is offsets.
			if totalOffsetX ~= 0 then
				cx, cy, cz = localToWorld(turnInfo.targetNode, totalOffsetX, 0, 0);
				setTranslation(turnInfo.targetNode, cx, cy, cz);
			end;

			----------------------------------------------------------
			-- Debug Print
			----------------------------------------------------------
			if courseplay.debugChannels[14] then
				local x,y,z = getWorldTranslation(turnInfo.targetNode);
				local ctx,_,ctz = localToWorld(turnInfo.targetNode, 0, 0, 20);
				drawDebugLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz, 0, 1, 0);

				local directionDifferentce = vehicle.Waypoints[vehicle.cp.waypointIndex].angle + vehicle.Waypoints[vehicle.cp.waypointIndex-1].angle;
				courseplay:debug(("%s:(Turn) wp%d=%.1f°, wp%d=%.1f°, directionDifferentce = %.1f°"):format(nameNum(vehicle), vehicle.cp.waypointIndex, vehicle.Waypoints[vehicle.cp.waypointIndex].angle, vehicle.cp.waypointIndex-1, vehicle.Waypoints[vehicle.cp.waypointIndex-1].angle, directionDifferentce), 14);
			end;

			----------------------------------------------------------
			-- Get the local delta distances from the tractor to the targetNode
			----------------------------------------------------------
			turnInfo.targetDeltaX, _, turnInfo.targetDeltaZ = worldToLocal(vehicle.cp.DirectionNode, cx, vehicleY, cz);
			courseplay:debug(string.format("%s:(Turn) targetDeltaX=%.2f, targetDeltaZ=%.2f", nameNum(vehicle), turnInfo.targetDeltaX, turnInfo.targetDeltaZ), 14);

			----------------------------------------------------------
			-- Get the turn direction
			----------------------------------------------------------
			if turnInfo.targetDeltaX > 0 then
				turnInfo.direction = 1;
			end;

			----------------------------------------------------------
			-- Check if tool width will collide on turn (Value is set in askForSpecialSettings)
			----------------------------------------------------------
			for i=1, #(vehicle.cp.workTools) do
				local workTool = vehicle.cp.workTools[i];
				if workTool.cp.widthWillCollideOnTurn and vehicle.cp.courseWorkWidth and (vehicle.cp.workWidth / 2) > turnInfo.halfVehicleWidth then
					turnInfo.halfVehicleWidth = vehicle.cp.workWidth / 2;
				end;
			end

			----------------------------------------------------------
			-- Find the zOffset based on tractors current position from the start turn wp
			----------------------------------------------------------
			local _, _, z = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex].cz);
			turnInfo.targetDeltaZ = turnInfo.targetDeltaZ - z;
			turnInfo.zOffset = abs(z) + 1;

			----------------------------------------------------------
			-- Get headland height
			----------------------------------------------------------
			if vehicle.cp.courseWorkWidth and vehicle.cp.courseWorkWidth > 0 and vehicle.cp.courseNumHeadlandLanes and vehicle.cp.courseNumHeadlandLanes > 0 then
				-- First headland is only half the work width
				turnInfo.headlandHeight = vehicle.cp.courseWorkWidth / 2 + turnInfo.halfVehicleWidth;
				-- Add extra workwidth for each extra headland
				if vehicle.cp.courseNumHeadlandLanes - 1 > 0 then
					turnInfo.headlandHeight = turnInfo.headlandHeight + ((vehicle.cp.courseNumHeadlandLanes - 1) * vehicle.cp.courseWorkWidth);
				end;
			end;

			----------------------------------------------------------
			-- WIDE TURNS (Turns where the distance to next lane is bigger than the turning Diameter
			----------------------------------------------------------
			if abs(turnInfo.targetDeltaX) >= turnInfo.turnDiameter then
				courseplay:generateWideTurn(vehicle, turnInfo);


			----------------------------------------------------------
			-- NAROW TURNS (Turns where the distance to next lane is smaller than the turning Diameter
			----------------------------------------------------------
			else
				--- Get the Triangle sides
				local centerOffset = abs(turnInfo.targetDeltaX) / 2;
				local sideC = turnInfo.turnDiameter;
				local sideB = centerOffset + turnInfo.turnRadius;
				local centerHeight = square(sideC^2 - sideB^2);

				--- Check if there is enough space to make Ohm turn on the headland.
				local useOhmTurn = false;
				if (turnInfo.zOffset + centerHeight + turnInfo.turnRadius + turnInfo.halfVehicleWidth) < turnInfo.headlandHeight then
					useOhmTurn = true;
				end;

				--- Ohm Turn
				if useOhmTurn or vehicle.cp.aiTurnNoBackward then
					courseplay:generateOhmTurn(vehicle, turnInfo);

				--- Circle Reverse Turn
				else
					courseplay:generateCircleReverseTurn(vehicle, turnInfo);
				end;
			end;

			cpPrintLine(14, 1);
			courseplay:debug(string.format("%s:(Turn) Generated %d Turn Waypoints", nameNum(vehicle), #vehicle.cp.turnTargets), 14);
			cpPrintLine(14, 3);

			vehicle.cp.turnStage = 2;
			--vehicle.cp.turnStage = 100; -- Stop the tractor (Developing Tests)

			unlink(turnInfo.targetNode);
			delete(turnInfo.targetNode);

		----------------------------------------------------------
		-- TURN STAGES 2 - Drive Turn maneuver
		----------------------------------------------------------
		elseif vehicle.cp.turnStage == 2 then
			if newTarget then
				if newTarget.turnEnd then
					vehicle.cp.turnStage = 3;
					return;
				end;

				local dist = courseplay:distance(newTarget.posX, newTarget.posZ, vehicleX, vehicleZ);

				-- Set reverseing settings.
				if newTarget.turnReverse then
					refSpeed = vehicle.cp.speeds.reverse;
					if reversingWorkTool and reversingWorkTool.cp.realTurningNode then
						local vorkToolX, _, vorkToolZ = getWorldTranslation(reversingWorkTool.cp.realTurningNode);
						local directionNodeToTurnNodeLengthOffset = courseplay:distance(vorkToolX, vorkToolZ, vehicleX, vehicleZ);
						-- set the correct distance when reversing
						dist = dist - (directionNodeToTurnNodeLength + (directionNodeToTurnNodeLength - directionNodeToTurnNodeLengthOffset));
					end;

				-- If next wp is more than 10 meters ahead, use fieldwork speed.
				elseif dist > 10 and not newTarget.turnReverse then
					refSpeed = vehicle.cp.speeds.field;
				end;

				-- Change turn waypoint
				if dist < wpChangeDistance then
					vehicle.cp.curTurnIndex = min(vehicle.cp.curTurnIndex + 1, #vehicle.cp.turnTargets);
				end;

				if courseplay.debugChannels[14] then
					renderText(0.5,0.85-(0.03*vehicle.cp.coursePlayerNum),0.02,string.format("%s: Current Distance: %.2fm ",nameNum(vehicle),dist))
				end
			else
				vehicle.cp.turnStage = 1; -- (THIS SHOULD NEVER HAPPEN) Somehow we don't have any waypoints, so try recollect them.
				return;
			end;

		----------------------------------------------------------
		-- TURN STAGES 3 - Lower implement and continue on next lane
		----------------------------------------------------------
		elseif vehicle.cp.turnStage == 3 then
			local _, _, deltaZ = worldToLocal(vehicle.cp.DirectionNode,vehicle.Waypoints[vehicle.cp.waypointIndex+1].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex+1].cz)

			local lowerImplements = deltaZ < frontMarker;
			if newTarget.turnReverse then
				refSpeed = vehicle.cp.speeds.reverse;
				lowerImplements = deltaZ > frontMarker;
			end;

			-- Lower implement and continue on next lane
			if lowerImplements then
				courseplay:lowerImplements(vehicle, true, true);

				vehicle.cp.turnStage = 0;
				vehicle.cp.isTurning = nil;
				vehicle.cp.waitForTurnTime = vehicle.timer + turnOutTimer;

				courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1);
				courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
				courseplay:clearTurnTargets(vehicle);

				return;
			end;

		----------------------------------------------------------
		-- UNKNOWN TURN STAGE - Stop the vehicle from driving (Used for developing purpose)
		----------------------------------------------------------
		else
			allowedToDrive = false;
		end;


	----------------------------------------------------------
	-- TURN STAGES 0 - Finish lane and raice implement and togo turn stage 1
	----------------------------------------------------------
	else
		if vehicle.isStrawEnabled then
			vehicle.cp.savedNoStopOnTurn = vehicle.cp.noStopOnTurn
			vehicle.cp.noStopOnTurn = false;
			turnTimer = vehicle.strawToggleTime or 5;
		elseif vehicle.cp.savedNoStopOnTurn ~= nil then
			vehicle.cp.noStopOnTurn = vehicle.cp.savedNoStopOnTurn;
			vehicle.cp.savedNoStopOnTurn = nil;
		end;

		local offset = Utils.getNoNil(vehicle.cp.totalOffsetX, 0);
		local x,y,z = localToWorld(vehicle.cp.DirectionNode, offset, 0, backMarker);
		local dist = courseplay:distance(vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vehicle.Waypoints[vehicle.cp.waypointIndex].cz, x, z);
		if dist > 7.5 then
			refSpeed = courseplay:getSpeedWithLimiter(vehicle, vehicle.cp.speeds.field);
		end;
		if backMarker <= 0 then
			if dist < 0.5 then
				if not vehicle.cp.noStopOnTurn then
					vehicle.cp.waitForTurnTime = vehicle.timer + turnTimer;
				end;
				courseplay:lowerImplements(vehicle, false, false);
				vehicle.cp.turnStage = 1;
			end;
		else
			if dist < 0.5 and vehicle.cp.turnStage ~= -1 then
				vehicle.cp.turnStage = -1;
				courseplay:lowerImplements(vehicle, false, false);
			end;
			if dist > backMarker and vehicle.cp.turnStage == -1 then
				if not vehicle.cp.noStopOnTurn then
					vehicle.cp.waitForTurnTime = vehicle.timer + turnTimer;
				end;
				vehicle.cp.turnStage = 1;
			end;
		end;
	end;

	----------------------------------------------------------
	--Set the driving direction
	----------------------------------------------------------
	if newTarget then
		local nextTarget = vehicle.cp.turnTargets[min(vehicle.cp.curTurnIndex + 1, #vehicle.cp.turnTargets)];
		if nextTarget.use2PointDirection and not newTarget.turnReverse then
			lx, lz = AIVehicleUtil.getAverageDriveDirection(vehicle.cp.DirectionNode, newTarget.posX, vehicleY, newTarget.posZ, nextTarget.posX, vehicleY, nextTarget.posZ)
		else
			lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, newTarget.posX, vehicleY, newTarget.posZ);
		end;

		if newTarget.turnReverse then
			lx, lz, moveForwards = courseplay:goReverse(vehicle,lx,lz);
		end;
	end;
	if courseplay.debugChannels[12] and newTarget then
		local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newTarget.posX, 1, newTarget.posZ);
		drawDebugPoint(newTarget.posX, posY + 3, newTarget.posZ, 1, 1, 0, 1);
	end;

	----------------------------------------------------------
	-- allowedToDrive false -> SLOW DOWN TO STOP
	----------------------------------------------------------
	if not allowedToDrive then
		-- reset slipping timers
		courseplay:resetSlippingTimers(vehicle)
		if courseplay.debugChannels[21] then
			renderText(0.5,0.85-(0.03*vehicle.cp.coursePlayerNum),0.02,string.format("%s: vehicle.lastSpeedReal: %.8f km/h ",nameNum(vehicle),vehicle.lastSpeedReal*3600))
		end
		vehicle.cp.TrafficBrake = false;
		vehicle.cp.isTrafficBraking = false;

		if vehicle.cp.curSpeed > 1 then
			allowedToDrive = true;
			moveForwards = vehicle.movingDirection == 1;
			directionForce = -1;
		end;
		vehicle.cp.speedDebugLine = ("turn("..tostring(debug.getinfo(1).currentline-1).."): allowedToDrive false ")
	else
		vehicle.cp.speedDebugLine = ("turn("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		courseplay:setSpeed(vehicle, refSpeed )
	end;

	----------------------------------------------------------
	-- Traffic break if something is in front of us
	----------------------------------------------------------
	if vehicle.cp.TrafficBrake then
		moveForwards = vehicle.movingDirection == -1;
	end

	----------------------------------------------------------
	-- Vehicles with inverted driving direction.
	----------------------------------------------------------
	if vehicle.invertedDrivingDirection then
		lx = -lx
	end

	--vehicle,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
	AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, directionForce, 0.5, 20, allowedToDrive, moveForwards, lx, lz, refSpeed, 1);
	courseplay:setTrafficCollision(vehicle, lx, lz, true);
end;

function courseplay:generateWideTurn(vehicle, turnInfo)
	-- TODO: (Claus) If there are space for avoiding going outside the field, then do it
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Wide Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local _;
	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local canTurnOnHeadland = false;
	local reverseOffset = 0;
	local center1, center2, startDir, intersect1, intersect2, stopDir = {}, {}, {}, {}, {}, {};

	-- Check if we can turn on the headlands
	if (turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth + 1) < turnInfo.headlandHeight then
		canTurnOnHeadland = true;
	end;

	--- Extra WP 1 - Reverse back so we can turn inside the field (Only if we can't turn inside the headlands)
	if not canTurnOnHeadland and not vehicle.cp.aiTurnNoBackward then
		-- Set the reverse offset
		reverseOffset = turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth + 1;

		-- Reverse back
		fromPoint.x, _, fromPoint.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, (turnInfo.zOffset + turnInfo.directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance) * -1);
		toPoint.x, _, toPoint.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, (reverseOffset + turnInfo.directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance) * -1);
		courseplay:generateTurnReversePoints(vehicle, fromPoint, toPoint);
	end;

	--- Get the 2 circle center cordinate
	center1.x,_,center1.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnRadius * turnInfo.direction, 0, 1 - reverseOffset);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset * -1 + reverseOffset);

	--- Get the circle intersection points
	intersect1.x, intersect1.z = center1.x, center1.z;
	intersect2.x, intersect2.z = center2.x, center2.z;
	intersect1, intersect2 = courseplay:getTurnCircleTangentIntersectionPoints(intersect1, intersect2, turnInfo.turnRadius, turnInfo.targetDeltaX > 0);

	--- Set start and stop dir for first turn circle
	startDir.x,_,startDir.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, 1 - reverseOffset);
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, (turnInfo.zOffset) * -1 + reverseOffset);

	--- Generate the 2 turn circles
	courseplay:generateTurnCircle(vehicle, center1, startDir, intersect1, turnInfo.turnRadius, turnInfo.direction, true);
	courseplay:generateTurnCircle(vehicle, center2, intersect2, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

	--- Extra WP 2 - Reverse back to field edge
	if not canTurnOnHeadland and not vehicle.cp.aiTurnNoBackward then
		-- Move a bit more forward
		posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, reverseOffset + turnInfo.directionNodeToTurnNodeLength);
		courseplay:addTurnTarget(vehicle, posX, posZ);

		-- Reverse back
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, reverseOffset - turnInfo.directionNodeToTurnNodeLength - turnInfo.reverseWPChangeDistance);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
		courseplay:generateTurnReversePoints(vehicle, fromPoint, toPoint, true);

		--- Extra WP 3 - Turn End
	else
		posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.zOffset + 5);
		courseplay:addTurnTarget(vehicle, posX, posZ, true);

	end;
end;

function courseplay:generateOhmTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Ohm Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local _;
	local posX, posZ;

	--- Get the Triangle sides
	local centerOffset = abs(turnInfo.targetDeltaX) / 2;
	local sideC = turnInfo.turnDiameter;
	local sideB = centerOffset + turnInfo.turnRadius;
	local centerHeight = square(sideC^2 - sideB^2);

	--- Target is behind of us
	local targetOffsetZ = 0;
	if turnInfo.targetDeltaZ < 0 then
		targetOffsetZ = abs(turnInfo.targetDeltaZ);
	end;

	--- Get the 3 circle center cordinate, startDir and stopDir
	local center1, center2, center3, startDir, stopDir = {}, {}, {}, {}, {};
	center1.x,_,center1.z = localToWorld(turnInfo.targetNode, (abs(turnInfo.targetDeltaX) + turnInfo.turnRadius) * turnInfo.direction, 0, (targetOffsetZ + turnInfo.zOffset) * -1);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, centerOffset * turnInfo.direction, 0, (targetOffsetZ + centerHeight + turnInfo.zOffset) * -1);
	center3.x,_,center3.z = localToWorld(turnInfo.targetNode, -turnInfo.turnRadius * turnInfo.direction, 0, (targetOffsetZ + turnInfo.zOffset) * -1);
	startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, (targetOffsetZ + turnInfo.zOffset) * -1);
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, (targetOffsetZ + turnInfo.zOffset) * -1);

	--- Generate the 3 turn circles
	courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, (turnInfo.direction * -1));
	courseplay:generateTurnCircle(vehicle, center2, center1, center3, turnInfo.turnRadius, turnInfo.direction);
	courseplay:generateTurnCircle(vehicle, center3, center2, stopDir, turnInfo.turnRadius, (turnInfo.direction * -1), true);

	--- Extra WP 1 - End Turn
	posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.zOffset + 5);
	courseplay:addTurnTarget(vehicle, posX, posZ, true);
end;

function courseplay:generateCircleReverseTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Circle Reverse Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local _;
	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local canTurnOnHeadland = false;
	local reverseOffset = 0;
	local center1, center2, startDir, stopDir = {}, {}, {}, {};

	--- Get the Triangle sides
	local centerOffset = (turnInfo.targetDeltaX * turnInfo.direction) - turnInfo.turnRadius;
	local sideC = turnInfo.turnDiameter;
	local sideB = turnInfo.turnRadius + centerOffset;
	local centerHeight = square(sideC^2 - sideB^2);
	courseplay:debug(("%s:(Turn) centerOffset=%s, sideB=%s, sideC=%s, centerHeight=%s"):format(nameNum(vehicle), tostring(centerOffset), tostring(sideB), tostring(sideC), tostring(centerHeight)), 14);

	--- Target is behind of us
	local targetOffsetZ = 0;
	if turnInfo.targetDeltaZ < 0 then
		targetOffsetZ = abs(turnInfo.targetDeltaZ);
	end;

	--- Get the center height offset
	local centerHeightOffset = (turnInfo.zOffset - 1 + targetOffsetZ) * -1;

	--- Check if we can turn on the headlands
	if (turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth) < turnInfo.headlandHeight then
		canTurnOnHeadland = true;
	end;

	--- If we cant turn on headland, then reverse back into the field to turn there.
	--- This is to prevent vehicles to drive too much into fences and such
	if not canTurnOnHeadland then
		-- Set the reverse offset
		reverseOffset = turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth - 1;

		-- Add the reverseOffset to centerHeigthOffset
		centerHeightOffset = centerHeightOffset + reverseOffset;

		-- Reverse back
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset + 3);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset + turnInfo.directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance + 3);
		courseplay:generateTurnReversePoints(vehicle, fromPoint, toPoint);
	end;

	--- Get the new zOffset
	local newZOffset = centerHeight + centerHeightOffset;
	courseplay:debug(("%s:(Turn) centerHeightOffset=%s, reverseOffset=%s, zOffset=%s, turnRadius=%s"):format(nameNum(vehicle), tostring(centerHeightOffset), tostring(reverseOffset), tostring(turnInfo.zOffset), tostring(turnInfo.turnRadius)), 14);

	--- Get the 2 circle center cordinate
	center1.x,_,center1.z = localToWorld(turnInfo.targetNode, centerOffset * turnInfo.direction, 0, centerHeightOffset);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, newZOffset);

	--- Generate first turn circle
	startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset);
	courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction);

	--- Generate second turn circle
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset);
	courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, (turnInfo.direction * -1), true);

	--- Extra WP 1
	posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + ((reverseOffset > 0) and reverseOffset or (turnInfo.zOffset + turnInfo.halfVehicleWidth)) + 6);
	courseplay:addTurnTarget(vehicle, posX, posZ);

	--- Extra WP 2 - Reverse with End Turn
	fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, ((reverseOffset > 0) and reverseOffset or (turnInfo.zOffset + turnInfo.halfVehicleWidth)) - 6);
	toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
	courseplay:generateTurnReversePoints(vehicle, fromPoint, toPoint, true);
end;

function courseplay:getTurnCircleTangentIntersectionPoints(cp, np, radius, leftTurn)
	local point = createTransformGroup("cpTempTurnCircleTangentIntersectionPoint");
	link(g_currentMission.terrainRootNode, point);

	-- Rotate it in the right direction
	local dx, dz = courseplay.generation:getPointDirection(cp, np, false);
	local yRot = Utils.getYRotationFromDirection(dx, dz);
	setRotation(point, 0, yRot, 0);

	if leftTurn then
		radius = radius * -1;
	end;

	-- Get the Tangent Intersection Point from start point.
	setTranslation(point, cp.x, 0, cp.z);
	cp.x, _, cp.z = localToWorld(point, radius, 0, 0);

	-- Get the Tangent Intersection Point from end point.
	setTranslation(point, np.x, 0, np.z);
	np.x, _, np.z = localToWorld(point, radius, 0, 0);

	-- Clean up the created node.
	unlink(point);
	delete(point);

	-- return the values.
	return cp, np;
end;

function courseplay:generateTurnReversePoints(vehicle, fromPoint, toPoint, turnEnd, secondaryReverseDistance)
	secondaryReverseDistance = secondaryReverseDistance or 10;
	local endTurn = false;
	local wpDistance = 3;
	local dist = courseplay:distance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z);
	local numPointsNeeded = ceil(dist / wpDistance) - 1;
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist;

	courseplay:addTurnTarget(vehicle, fromPoint.x, fromPoint.z, nil, true);

	local posX, posZ;
	for i=1, numPointsNeeded do
		local revPosX, revPosZ;
		if i == numPointsNeeded then
			posX = toPoint.x;
			posZ = toPoint.z;
			revPosX = toPoint.x + (secondaryReverseDistance * dx);
			revPosZ = toPoint.z + (secondaryReverseDistance * dz);
			if turnEnd == true then endTurn = turnEnd; end;
		else
			posX = fromPoint.x + (i * wpDistance * dx);
			posZ = fromPoint.z + (i * wpDistance * dz);
		end;

		courseplay:addTurnTarget(vehicle, posX, posZ, endTurn, true, revPosX, revPosZ);
	end;
end;

function courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, radius, clockWice, addEndPoint)
	-- Convert clockWice to the fight format
	if clockWice == nil then clockWice = 1 end;
	if clockWice == false or clockWice < 0 then
		clockWice = -1;
	else
		clockWice = 1;
	end;

	-- Define some basic values to use
	local numWP 		= 1;
	local degreeToTurn	= 0;
	local wpDistance	= 2;
	local degreeStep	= 360 / (2 * radius * math.pi) * wpDistance;
	local startRot		= 0;
	local endRot		= 0;

	-- Get the start and end rotation
	local dx, dz = courseplay.generation:getPointDirection(center, startDir, false);
	startRot = deg(Utils.getYRotationFromDirection(dx, dz));
	dx, dz = courseplay.generation:getPointDirection(center, stopDir, false);
	endRot = deg(Utils.getYRotationFromDirection(dx, dz));

	-- Create new transformGroupe to use for placing waypoints
	local point = createTransformGroup("cpTempGenerateTurnCircle");
	link(g_currentMission.terrainRootNode, point);

	-- Move the point to the center
	local cY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, center.x, 1, center.z);
	setTranslation(point, center.x, cY, center.z);

	-- Rotate it to the start direction
	setRotation(point, 0, rad(startRot), 0);

	-- Fix the rotation values in some special cases
	if clockWice == 1 then
		--(Turn:generateTurnCircle) startRot=90, endRot=-29, degreeStep=20, degreeToTurn=240, clockWice=1
		if startRot > endRot then
			degreeToTurn = endRot + 360 - startRot;
		else
			degreeToTurn = endRot - startRot;
		end;
	else
		--(Turn:generateTurnCircle) startRot=150, endRot=90, degreeStep=-20, degreeToTurn=60, clockWice=-1
		if startRot < endRot then
			degreeToTurn = startRot + 360 - endRot;
		else
			degreeToTurn = startRot - endRot;
		end;
	end;
	courseplay:debug(string.format("%s:(Turn:generateTurnCircle) startRot=%d, endRot=%d, degreeStep=%d, degreeToTurn=%d, clockWice=%d", nameNum(vehicle), startRot, endRot, (degreeStep * clockWice), degreeToTurn, clockWice), 14);

	-- Get the number of waypoints
	numWP = ceil(degreeToTurn / degreeStep);
	-- Recalculate degreeStep
	degreeStep = (degreeToTurn / numWP) * clockWice;
	-- Add extra waypoint if addEndPoint is true
	if addEndPoint then numWP = numWP + 1; end;

	courseplay:debug(string.format("%s:(Turn:generateTurnCircle) numberOfWaypoints=%d, newDegreeStep=%d", nameNum(vehicle), numWP, degreeStep), 14);

	-- Generate the waypoints
	local i = 1;
	for i = 1, numWP, 1 do
		if i ~= 1 then
			local _,currentRot,_ = getRotation(point);
			local newRot = deg(currentRot) + degreeStep;

			setRotation(point, 0, rad(newRot), 0);
		end;

		local posX,_,posZ = localToWorld(point, 0, 0, radius);
		courseplay:addTurnTarget(vehicle, posX, posZ, nil, nil, nil, nil, true);

		local _,rot,_ = getRotation(point);
		courseplay:debug(string.format("%s:(Turn:generateTurnCircle) waypoint %d curentRotation=%d", nameNum(vehicle), i, deg(rot)), 14);
	end;

	-- Clean up the created node.
	unlink(point);
	delete(point);
end;

function courseplay:addTurnTarget(vehicle, posX, posZ, turnEnd, turnReverse, revPosX, revPosZ, use2PointDirection)
	local target = {};
	target.posX 				= posX;
	target.posZ 				= posZ;
	target.turnEnd				= turnEnd;
	target.turnReverse			= turnReverse;
	target.revPosX 				= revPosX;
	target.revPosZ 				= revPosZ;
	target.use2PointDirection	= use2PointDirection;
	table.insert(vehicle.cp.turnTargets, target);
end

function courseplay:clearTurnTargets(vehicle)
	vehicle.cp.turnTargets = {};
end

function courseplay:turn(self, dt) --!!!
	--[[ TURN STAGES:
	0:	raise implements
	1:	start forward turn
	2:	
	3:	reversing
	4:	
	5:	
	6:	
	]]
	
	if self.cp.mode == 4 then
		courseplay:newturn(self, dt);
		return;
	end;
	
	local newTargetX, newTargetY, newTargetZ;
	local moveForwards = true;
	local updateWheels = true;
	local turnOutTimer = 1500
	local turnTimer = 1500
	--local frontMarker = Utils.getNoNil(self.cp.backMarkerOffset, -3)
	--local backMarker = Utils.getNoNil(self.cp.aiFrontMarker,0)
	local frontMarker = Utils.getNoNil(self.cp.aiFrontMarker, -3)
	local backMarker = Utils.getNoNil(self.cp.backMarkerOffset,0)
	if self.cp.noStopOnEdge then
		turnOutTimer = 0
	end
	if self.cp.lastDistanceToTurnPoint == nil then
		self.cp.lastDistanceToTurnPoint = math.huge;
	end
	if not self.cp.checkMarkers then
		self.cp.checkMarkers = true
		for _,workTool in pairs(self.cp.workTools) do
			courseplay:setMarkers(self, workTool)
			courseplay:askForSpecialSettings(self, workTool)
		end
	end
	
	self.cp.turnTimer = self.cp.turnTimer - dt;

	-- TURN STAGES 1 - 6
	if self.cp.turnTimer < 0 or self.cp.turnStage > 0 then

		-- TURN STAGES 2 - 6
		if self.cp.turnStage > 1 then
			local x,y,z = getWorldTranslation(self.cp.DirectionNode);
			local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
			local myDirX, myDirY, myDirZ = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);

			newTargetX = self.aiTractorTargetX;
			newTargetY = y;
			newTargetZ = self.aiTractorTargetZ;

			-- TURN STAGE 2
			if self.cp.turnStage == 2 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if self.cp.isTurning == "left" then
					AITractor.aiRotateLeft(self);
				else
					AITractor.aiRotateRight(self);
				end
				if myDirX*dirX + myDirZ*dirZ > 0.2 or self.turnStageTimer < 0 then
					if self.cp.aiTurnNoBackward or
					(courseplay:distance(newTargetX, newTargetZ, self.Waypoints[self.cp.waypointIndex-1].cx, self.Waypoints[self.cp.waypointIndex-1].cz) > self.cp.turnDiameter * 1.2) then
						self.cp.turnStage = 4;
					else
						self.cp.turnStage = 3;
						moveForwards = false;
					end;
					if self.turnStageTimer < 0 then
						self.aiTractorTargetBeforeSaveX = self.aiTractorTargetX;
						self.aiTractorTargetBeforeSaveZ = self.aiTractorTargetZ;
						newTargetX = self.aiTractorTargetBeforeTurnX;
						newTargetZ = self.aiTractorTargetBeforeTurnZ;
						moveForwards = false;
						self.cp.turnStage = 6;
						self.turnStageTimer = Utils.getNoNil(self.turnStage6Timeout,3000)
					else
						self.turnStageTimer = Utils.getNoNil(self.turnStage3Timeout,20000)
					end;
				end;

			-- TURN STAGE 3
			elseif self.cp.turnStage == 3 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if myDirX*dirX + myDirZ*dirZ > 0.95 or self.turnStageTimer < 0 then
					self.cp.turnStage = 4;
				else
					moveForwards = false;
				end;

			-- TURN STAGE 4
			elseif self.cp.turnStage == 4 then
				local dx, dz = x-newTargetX, z-newTargetZ;
				local dot = dx*dirX + dz*dirZ;
				if self.cp.noStopOnEdge then
					courseplay:lowerImplements(self, true, false)
				end
				if -dot < Utils.getNoNil(self.turnEndDistance, 4) then
					if self.turnTargetMoveBack ~= nil and self.aiToolExtraTargetMoveBack ~= nil then
						newTargetX = self.aiTractorTargetX + dirX*(self.turnTargetMoveBack + self.aiToolExtraTargetMoveBack);
						newTargetY = y;
						newTargetZ = self.aiTractorTargetZ + dirZ*(self.turnTargetMoveBack + self.aiToolExtraTargetMoveBack);
					else
						newTargetX = self.aiTractorTargetX
						newTargetY = y;
						newTargetZ = self.aiTractorTargetZ
					end
					self.cp.turnStage = 5;
				end;

			-- TURN STAGE 5
			elseif self.cp.turnStage == 5 then
				local backX, backY, backZ = localToWorld(self.cp.DirectionNode,0,0,frontMarker);
				local dx, dz = backX-newTargetX, backZ-newTargetZ;
				local dot = dx*dirX + dz*dirZ;
				local moveback = 0
				if self.turnEndBackDistance ~= nil and self.aiToolExtraTargetMoveBack ~= nil then
					moveback = self.turnEndBackDistance+self.aiToolExtraTargetMoveBack
				else
					moveback = 10
				end
				if -dot < moveback  then
					self.cp.turnStage = 0;
					local _,_,z1 = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.waypointIndex+1].cx, backY, self.Waypoints[self.cp.waypointIndex+1].cz);
					local _,_,z2 = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.waypointIndex+2].cx, backY, self.Waypoints[self.cp.waypointIndex+2].cz);
					local _,_,z3 = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.waypointIndex+3].cx, backY, self.Waypoints[self.cp.waypointIndex+3].cz);
					if self.cp.isCombine then
						if z2 > 6 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 2);
						elseif z3 > 6 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 3);
						else
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 4);
						end
					else
						if z1 > 0 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 1);
						elseif z2 > 0 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 2);
						else
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 3);
						end
					end;
					courseplay:lowerImplements(self, true, true)
					self.cp.turnTimer = 8000
					self.cp.isTurning = nil 
					self.cp.waitForTurnTime = self.timer + turnOutTimer;
				end;

			-- TURN STAGE 6
			elseif self.cp.turnStage == 6 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if self.turnStageTimer < 0 then
					self.turnStageTimer = Utils.getNoNil(self.turnStage2Timeout,20000)
					self.cp.turnStage = 2;

					newTargetX = self.aiTractorTargetBeforeSaveX;
					newTargetZ = self.aiTractorTargetBeforeSaveZ;
				else
					local x,y,z = getWorldTranslation(self.cp.DirectionNode);
					local dirX, dirZ = -self.aiTractorDirectionX, -self.aiTractorDirectionZ;
					-- just drive along direction
					local targetX, targetZ = self.aiTractorTargetX, self.aiTractorTargetZ;
					local dx, dz = x-targetX, z-targetZ;
					local dot = dx*dirX + dz*dirZ;

					local projTargetX = targetX +dirX*dot;
					local projTargetZ = targetZ +dirZ*dot;
					local aheadDistance = Utils.getNoNil(self.aiTractorLookAheadDistance,10)
					newTargetX = projTargetX-dirX*aheadDistance;
					newTargetZ = projTargetZ-dirZ*aheadDistance;
					moveForwards = false;
				end;
			end;
			if courseplay.debugChannels[12] then
				drawDebugPoint(newTargetX, y+3, newTargetZ, 1, 1, 0, 1);
			end;

		-- TURN STAGE 1
		elseif self.cp.turnStage == 1 then
			-- turn
			self.cp.lastDistanceToTurnPoint = math.huge;
			local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
			if self.cp.isTurning == "right" then
				self.aiTractorTurnLeft = false;
			else
				self.aiTractorTurnLeft = true;
			end;
			local cx,cz = self.Waypoints[self.cp.waypointIndex+1].cx, self.Waypoints[self.cp.waypointIndex+1].cz;
			if (self.cp.laneOffset ~= nil and self.cp.laneOffset ~= 0) or (self.cp.toolOffsetX ~= nil and self.cp.toolOffsetX ~= 0) then
				cx,cz = courseplay:turnWithOffset(self)
			end;
			newTargetX = cx
			newTargetY = y;
			newTargetZ = cz
			
			self.aiTractorTargetBeforeTurnX = self.aiTractorTargetX;
			self.aiTractorTargetBeforeTurnZ = self.aiTractorTargetZ;

			self.aiTractorDirectionX = -dirX;
			self.aiTractorDirectionZ = -dirZ;
			self.cp.turnStage = 2;
			self.turnStageTimer = Utils.getNoNil(self.turnStage2Timeout,20000)

		-- TURN STAGE ??? --TODO (Jakob): what's the situation here? turnStage not > 1 and not > 0 ? When do we get to this point?
		else              -- The situation is when a turn timeout appears...
			self.cp.turnStage = 1;
			if self.cp.noStopOnTurn == false then
				self.waitForTurnTime = self.timer + turnTimer;
			end
			courseplay:lowerImplements(self, false, true)
			updateWheels = false;
		end;

	-- TURN STAGE 0
	else
		if self.isStrawEnabled then 
			self.cp.savedNoStopOnTurn = self.cp.noStopOnTurn
			self.cp.noStopOnTurn = false
			turnTimer = self.strawToggleTime or 5;
		elseif self.cp.savedNoStopOnTurn ~= nil then
			self.cp.noStopOnTurn = self.cp.savedNoStopOnTurn
			self.cp.savedNoStopOnTurn = nil
		end
		
		local offset = Utils.getNoNil(self.cp.totalOffsetX, 0)
		local targetX,targetZ = self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz;
		local x,y,z = localToWorld(self.cp.DirectionNode, offset, 0, backMarker)
		local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,targetX,0,targetZ)
		local dist = courseplay:distance3D(targetX,terrainHeight,targetZ, x,y,z)
		--local dist = courseplay:distance(targetX,targetZ,x,z)
		-- print(string.format("distance: %f; backmarker %f; y:%.3f vs Height:%.3f",dist,backMarker,y,terrainHeight))
		if backMarker <= 0 then
			if  dist < 0.5 or self.cp.lastDistanceToTurnPoint < dist then
				if not self.cp.noStopOnTurn then
					self.cp.waitForTurnTime = self.timer + turnTimer
				end
				courseplay:lowerImplements(self, false, false)
				updateWheels = false;
				self.cp.turnStage = 1;
			else
				self.cp.lastDistanceToTurnPoint = dist;
			end
		else
			if dist < 0.5 and self.cp.turnStage ~= -1 then
				self.cp.turnStage = -1
				courseplay:lowerImplements(self, false, false)
			end
			if dist > backMarker and self.cp.turnStage == -1 then
				if self.cp.noStopOnTurn == false then
					self.cp.waitForTurnTime = self.timer + turnTimer
				end
				updateWheels = false;
				self.cp.turnStage = 1;
			end
		end
		x,y,z = localToWorld(self.cp.DirectionNode, 0, 0, 1)
		self.aiTractorTargetX, self.aiTractorTargetZ = x,z
		
		x,y,z = getWorldTranslation(self.cp.DirectionNode);
		local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
		local targetX, targetZ = self.aiTractorTargetX, self.aiTractorTargetZ;
		local dx, dz = x-targetX, z-targetZ;
		local dot = dx*dirX + dz*dirZ;

		local projTargetX = targetX +dirX*dot;
		local projTargetZ = targetZ +dirZ*dot;
		
		
		newTargetX = projTargetX+self.aiTractorDirectionX
		newTargetY = y;
		newTargetZ = projTargetZ+self.aiTractorDirectionZ
	end;

	if updateWheels then
		local allowedToDrive = true
		local refSpeed = self.cp.speeds.turn
		self.cp.speedDebugLine = ("turn("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		courseplay:setSpeed(self, refSpeed )
		
		local lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, newTargetX, newTargetY, newTargetZ);
		if self.cp.turnStage == 3 and math.abs(lx) < 0.1 then
			self.cp.turnStage = 4;
			moveForwards = true;
		end;
		if self.cp.TrafficBrake then
			moveForwards = self.movingDirection == -1;
			lx = 0
			lz = 1
		end
		if self.invertedDrivingDirection then
			lx = -lx
		end
		AIVehicleUtil.driveInDirection(self, dt, 25, 1, 0.5, 20, true, moveForwards, lx, lz, refSpeed, 1);
		courseplay:setTrafficCollision(self, lx, lz, true)
	end;
	
	if newTargetX ~= nil and newTargetZ ~= nil then
		self.aiTractorTargetX = newTargetX;
		self.aiTractorTargetZ = newTargetZ;
	end;
end

function courseplay:lowerImplements(self, moveDown, workToolonOff)
	--moveDown true= lower,  false = raise , workToolonOff true = switch on worktool,  false = switch off worktool
	if moveDown == nil then 
		moveDown = false; 
	end;

	local state  = 1;
	if moveDown then
		state  = -1;
    end;

    local specialTool;
	for _,workTool in pairs(self.cp.workTools) do
					--courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
		specialTool = courseplay:handleSpecialTools(self,workTool,true,moveDown,workToolonOff,nil,nil,nil);
		
		if not specialTool and workTool.setPickupState ~= nil then
			if workTool.isPickupLowered ~= nil and workTool.isPickupLowered ~= moveDown then
				workTool:setPickupState(moveDown, false);
			end;
		end;
	
	end;
	if not specialTool then
		if self.setAIImplementsMoveDown ~= nil then
			self:setAIImplementsMoveDown(moveDown,true);
		elseif self.setFoldState ~= nil then
			self:setFoldState(state, true);
		end;
		if self.cp.mode == 4 then
			for _,workTool in pairs(self.cp.workTools) do								 --vvTODO (Tom) why is this here vv?
				if workTool.setIsTurnedOn ~= nil and not courseplay:isFolding(workTool) and (true or workTool ~= self) and workTool.isTurnedOn ~= workToolonOff then
					workTool:setIsTurnedOn(workToolonOff, false);                          -- disabled for Pantera
				end;
			end;
		end;
	end;
end;

function courseplay:turnWithOffset(self)
	--SYMMETRIC LANE CHANGE
	if self.cp.symmetricLaneChange then
		if self.cp.switchLaneOffset then
			courseplay:changeLaneOffset(self, nil, self.cp.laneOffset * -1);
			self.cp.switchLaneOffset = false;
			courseplay:debug(string.format("%s: cp.turnStage == 1, switchLaneOffset=true -> new laneOffset=%.1f, new totalOffset=%.1f, set switchLaneOffset to false", nameNum(self), self.cp.laneOffset, self.cp.totalOffsetX), 12);
		end;
	end;
	--TOOL OFFSET TOGGLE
	if self.cp.hasPlough then
		if self.cp.switchToolOffset then
			courseplay:changeToolOffsetX(self, nil, self.cp.toolOffsetX * -1, true);
			self.cp.switchToolOffset = false;
			courseplay:debug(string.format("%s: cp.turnStage == 1, switchToolOffset=true -> new toolOffset=%.1f, new totalOffset=%.1f, set switchToolOffset to false", nameNum(self), self.cp.toolOffsetX, self.cp.totalOffsetX), 12);
		end;
	end;

	-- TODO: (Claus) Delete old retrofit code below, when converted 100% over to the new turn system.

	local curPoint = self.Waypoints[self.cp.waypointIndex+1]
	local cx, cz = curPoint.cx, curPoint.cz;
	local offsetX = self.cp.totalOffsetX
	if curPoint.turnEnd and curPoint.laneDir ~= nil then --TODO (Jakob): use point's direction to next point to get the proper offset
		local dir = curPoint.laneDir;
		local turnDir = curPoint.turn;
		
		if dir == "E" then
			cz = curPoint.cz + offsetX;
		elseif dir == "W" then
			cz = curPoint.cz - offsetX;
		elseif dir == "N" then
			cx = curPoint.cx + offsetX;
		elseif dir == "S" then
			cx = curPoint.cx - offsetX;
		end;
	end;
	return cx,cz
end
