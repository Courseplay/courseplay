local abs, min, max, floor, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.deg;
local _; --- The _ is an discart character for values not needed. Setting it to local, prevent's it from being an global variable.

function courseplay:turn(vehicle, dt)
	---- TURN STAGES:
	-- 0:	Raise implements
	-- 1:	Create Turn maneuver (Creating waypoints to follow)
	-- 2:	Drive Turn maneuver
	-- 3:	Lower implement and continue on next lane

	if vehicle.cp.isLoaded then
		vehicle.cp.isTurning = nil;
		courseplay:clearTurnTargets(vehicle);
		return;
	end

	local allowedToDrive 					= true;
	local moveForwards 						= true;
	local refSpeed 							= vehicle.cp.speeds.turn;
	local directionForce 					= 1;
	local lx, lz 							= 0, 1;
	local dtpX, dtpZ						= 0, 1;
	local turnOutTimer 						= 1500;
	local turnTimer 						= 1500;
	local wpChangeDistance 					= 3;
	local reverseWPChangeDistance			= 4;
	local reverseWPChangeDistanceWithTool	= 5;
	local isHarvester						= courseplay:isCombine(vehicle) or courseplay:isChopper(vehicle) or courseplay:isHarvesterSteerable(vehicle);
	local allowedAngle						= isHarvester and 15 or 3; -- Used for changing direction if the vehicle or vehicle and tool angle difference are below that.
	if vehicle.cp.noStopOnEdge then
		turnOutTimer = 0;
	end;

	--- Make sure front and back markers is calculated.
	if not vehicle.cp.haveCheckedMarkersThisTurn then
		vehicle.cp.aiFrontMarker = nil;
		vehicle.cp.backMarkerOffset = nil;
		for _,workTool in pairs(vehicle.cp.workTools) do
			courseplay:setMarkers(vehicle, workTool);
		end;
		vehicle.cp.haveCheckedMarkersThisTurn = true;
	end;

	--- Get front and back markers
	local frontMarker = Utils.getNoNil(vehicle.cp.aiFrontMarker, -3);
	local backMarker = Utils.getNoNil(vehicle.cp.backMarkerOffset,0);

	local vehicleX, vehicleY, vehicleZ = getWorldTranslation(vehicle.cp.DirectionNode);

	--- This is in case we use manually recorded fieldswork course and not generated.
	if not vehicle.cp.courseWorkWidth then
		courseplay:calculateWorkWidth(vehicle, true);
		vehicle.cp.courseWorkWidth = vehicle.cp.workWidth;
	end;

	----------------------------------------------------------
	-- Debug prints
	----------------------------------------------------------
	if courseplay.debugChannels[14] then
		if #vehicle.cp.turnTargets > 0 then
			-- Draw debug points for waypoints.
			for index, turnTarget in ipairs(vehicle.cp.turnTargets) do
				if index < #vehicle.cp.turnTargets then
					local nextTurnTarget = vehicle.cp.turnTargets[index + 1];
					local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.posX, 300, turnTarget.posZ);
					local nextPosY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nextTurnTarget.posX, 300, nextTurnTarget.posZ);
					if turnTarget.turnReverse then
						local color = { r = 0, g = 1, b = 0}; -- Green Line
						--if not nextTurnTarget.turnReverse then
						--	color["r"], color["g"], color["b"] = 0, 1, 1; -- Light Blue Line
						--end
						drawDebugLine(turnTarget.posX, posY + 3, turnTarget.posZ, color["r"], color["g"], color["b"], nextTurnTarget.posX, nextPosY + 3, nextTurnTarget.posZ, color["r"], color["g"], color["b"]); -- Green Line
						if turnTarget.revPosX and turnTarget.revPosZ then
							nextPosY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.revPosX, 300, turnTarget.revPosZ);
							drawDebugLine(turnTarget.posX, posY + 3, turnTarget.posZ, 1, 0, 0, turnTarget.revPosX, nextPosY + 3, turnTarget.revPosZ, 1, 0, 0);  -- Red Line
						end;
					else
						local color = { r = 0, g = 1, b = 1}; -- Light Blue Line
						if nextTurnTarget.changeWhenPosible then
							color["r"], color["g"], color["b"] = 1, 0.706, 0; -- Orange Line
						end
						drawDebugLine(turnTarget.posX, posY + 3, turnTarget.posZ, color["r"], color["g"], color["b"], nextTurnTarget.posX, nextPosY + 3, nextTurnTarget.posZ, color["r"], color["g"], color["b"]);  -- Light Blue Line
					end;
				elseif turnTarget.turnReverse and turnTarget.revPosX and turnTarget.revPosZ then
					local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.posX, 300, turnTarget.posZ);
					local nextPosY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.revPosX, 300, turnTarget.revPosZ);
					drawDebugLine(turnTarget.posX, posY + 3, turnTarget.posZ, 1, 0, 0, turnTarget.revPosX, nextPosY + 3, turnTarget.revPosZ, 1, 0, 0);  -- Red Line
				end;
			end;
		end;
	end;

	--- Get the directionNodeToTurnNodeLength used for reverse turn distances
	local directionNodeToTurnNodeLength = courseplay:getDirectionNodeToTurnNodeLength(vehicle);

	--- Get the firstReverseWheledWorkTool used for reversing
	local reversingWorkTool = courseplay:getFirstReversingWheeledWorkTool(vehicle);

	--- Reset reverseWPChangeDistance if we don't have an trailed implement
	if reversingWorkTool then
		reverseWPChangeDistance = reverseWPChangeDistanceWithTool;
	end;

	--- While driving (Stage 2 & 3), do we need to use the reversing WP change distance
	local newTarget = vehicle.cp.turnTargets[vehicle.cp.curTurnIndex];
	if newTarget and newTarget.turnReverse then
		wpChangeDistance = reverseWPChangeDistance;
	end;

	----------------------------------------------------------
	-- TURN STAGES 1 - 3
	----------------------------------------------------------
	if vehicle.cp.turnStage > 0 then

		----------------------------------------------------------
		-- TURN STAGES 1 - Create Turn maneuver (Creating waypoints to follow)
		----------------------------------------------------------
		if vehicle.cp.turnStage == 1 then
			--- Cleanup in case we already have old info
			courseplay:clearTurnTargets(vehicle); -- Make sure we have cleaned it from any previus usage.

			--- Setting default turnInfo values
			local turnInfo = {};
			turnInfo.frontMarker					= frontMarker;
			turnInfo.halfVehicleWidth 				= 2.5;
			turnInfo.directionNodeToTurnNodeLength  = directionNodeToTurnNodeLength;
			turnInfo.wpChangeDistance				= wpChangeDistance;
			turnInfo.reverseWPChangeDistance 		= reverseWPChangeDistance;
			turnInfo.direction 						= -1;
			turnInfo.haveHeadlands 					= courseplay:haveHeadlands(vehicle);
			turnInfo.headlandHeight 				= 0;
			turnInfo.numLanes ,turnInfo.onLaneNum 	= courseplay:getLaneInfo(vehicle);
			turnInfo.turnOnField 					= vehicle.cp.turnOnField;
			turnInfo.reverseOffset 					= 0;
			turnInfo.haveWheeledImplement 			= reversingWorkTool ~= nil;
			if turnInfo.haveWheeledImplement then
				turnInfo.reversingWorkTool 			= reversingWorkTool;
			end;
			turnInfo.isHarvester					= isHarvester;

			--- Get the turn radius either by the automatic or user provided turn circle.
			local extRadius = 0.5 + (0.15 * directionNodeToTurnNodeLength); -- The extra calculation is for dynamic trailer length to prevent jackknifing;
			turnInfo.turnRadius = vehicle.cp.turnDiameter * 0.5 + extRadius;
			turnInfo.turnDiameter = turnInfo.turnRadius * 2;

			--- Get the new turn target with offset
			if courseplay:getIsVehicleOffsetValid(vehicle) then
				courseplay:debug(string.format("%s:(Turn) turnWithOffset = true", nameNum(vehicle)), 14);
				courseplay:turnWithOffset(vehicle);
			end;

			local totalOffsetX = vehicle.cp.totalOffsetX * -1

			--- Create temp target node and translate it.
			turnInfo.targetNode = createTransformGroup("cpTempTargetNode");
			link(g_currentMission.terrainRootNode, turnInfo.targetNode);
			local cx,cz = vehicle.Waypoints[vehicle.cp.waypointIndex+1].cx, vehicle.Waypoints[vehicle.cp.waypointIndex+1].cz;
			local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 300, cz);
			setTranslation(turnInfo.targetNode, cx, cy, cz);

			-- Rotate it's direction to the next wp.
			local dx, dz = courseplay.generation:getPointDirection(vehicle.Waypoints[vehicle.cp.waypointIndex+1], vehicle.Waypoints[vehicle.cp.waypointIndex+2]);
			local yRot = Utils.getYRotationFromDirection(dx, dz);
			setRotation(turnInfo.targetNode, 0, yRot, 0);

			-- Retranslate it again to the correct position if there is offsets.
			if totalOffsetX ~= 0 then
				cx, cy, cz = localToWorld(turnInfo.targetNode, totalOffsetX, 0, 0);
				setTranslation(turnInfo.targetNode, cx, cy, cz);
			end;

			--- Debug Print
			if courseplay.debugChannels[14] then
				local x,y,z = getWorldTranslation(turnInfo.targetNode);
				local ctx,_,ctz = localToWorld(turnInfo.targetNode, 0, 0, 20);
				drawDebugLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz, 0, 1, 0);
				-- this is an test
				local directionDifferentce = vehicle.Waypoints[vehicle.cp.waypointIndex].angle + vehicle.Waypoints[vehicle.cp.waypointIndex-1].angle;
				courseplay:debug(("%s:(Turn) wp%d=%.1f°, wp%d=%.1f°, directionDifferentce = %.1f°"):format(nameNum(vehicle), vehicle.cp.waypointIndex, vehicle.Waypoints[vehicle.cp.waypointIndex].angle, vehicle.cp.waypointIndex-1, vehicle.Waypoints[vehicle.cp.waypointIndex-1].angle, directionDifferentce), 14);
			end;

			--- Get the local delta distances from the tractor to the targetNode
			turnInfo.targetDeltaX, _, turnInfo.targetDeltaZ = worldToLocal(vehicle.cp.DirectionNode, cx, vehicleY, cz);
			courseplay:debug(string.format("%s:(Turn) targetDeltaX=%.2f, targetDeltaZ=%.2f", nameNum(vehicle), turnInfo.targetDeltaX, turnInfo.targetDeltaZ), 14);

			--- Get the turn direction
			if turnInfo.targetDeltaX > 0 then
				turnInfo.direction = 1;
			end;

			--- Check if tool width will collide on turn (Value is set in askForSpecialSettings)
			for i=1, #(vehicle.cp.workTools) do
				local workTool = vehicle.cp.workTools[i];
				if workTool.cp.widthWillCollideOnTurn and vehicle.cp.courseWorkWidth and (vehicle.cp.workWidth / 2) > turnInfo.halfVehicleWidth then
					turnInfo.halfVehicleWidth = vehicle.cp.workWidth / 2;
				end;
			end

			--- Find the zOffset based on tractors current position from the start turn wp
			_, _, turnInfo.zOffset = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex].cz);
			turnInfo.targetDeltaZ = turnInfo.targetDeltaZ - turnInfo.zOffset;

			--- Get headland height
			if vehicle.cp.courseWorkWidth and vehicle.cp.courseWorkWidth > 0 and vehicle.cp.courseNumHeadlandLanes and vehicle.cp.courseNumHeadlandLanes > 0 then
				-- First headland is only half the work width
				turnInfo.headlandHeight = vehicle.cp.courseWorkWidth / 2;
				-- Add extra workwidth for each extra headland
				if vehicle.cp.courseNumHeadlandLanes - 1 > 0 then
					turnInfo.headlandHeight = turnInfo.headlandHeight + ((vehicle.cp.courseNumHeadlandLanes - 1) * vehicle.cp.courseWorkWidth);
				end;
			end;

			--- Calculate reverseOffset in case we need to reverse
			local offset = turnInfo.zOffset;
			if turnInfo.frontMarker > 0 then
				offset = -turnInfo.zOffset - turnInfo.frontMarker;
			end;
			if turnInfo.turnOnField then
				turnInfo.reverseOffset = max((turnInfo.turnRadius + turnInfo.halfVehicleWidth - turnInfo.headlandHeight), offset);
			else
				turnInfo.reverseOffset = offset;
			end;

			courseplay:debug(("%s:(Turn Data) frontMarker=%q, halfVehicleWidth=%q, directionNodeToTurnNodeLength=%q, wpChangeDistance=%q"):format(nameNum(vehicle), tostring(turnInfo.frontMarker), tostring(turnInfo.halfVehicleWidth), tostring(turnInfo.directionNodeToTurnNodeLength), tostring(turnInfo.wpChangeDistance)), 14);
			courseplay:debug(("%s:(Turn Data) reverseWPChangeDistance=%q, direction=%q, haveHeadlands=%q, headlandHeight=%q"):format(nameNum(vehicle), tostring(turnInfo.reverseWPChangeDistance), tostring(turnInfo.direction), tostring(turnInfo.haveHeadlands), tostring(turnInfo.headlandHeight)), 14);
			courseplay:debug(("%s:(Turn Data) numLanes=%q, onLaneNum=%q, turnOnField=%q, reverseOffset=%q"):format(nameNum(vehicle), tostring(turnInfo.numLanes), tostring(turnInfo.onLaneNum), tostring(turnInfo.turnOnField), tostring(turnInfo.reverseOffset)), 14);
			courseplay:debug(("%s:(Turn Data) haveWheeledImplement=%q, reversingWorkTool=%q, turnRadius=%q, turnDiameter=%q"):format(nameNum(vehicle), tostring(turnInfo.haveWheeledImplement), tostring(turnInfo.reversingWorkTool), tostring(turnInfo.turnRadius), tostring(turnInfo.turnDiameter)), 14);
			courseplay:debug(("%s:(Turn Data) targetNode=%q, targetDeltaX=%q, targetDeltaZ=%q, zOffset=%q"):format(nameNum(vehicle), tostring(turnInfo.targetNode), tostring(turnInfo.targetDeltaX), tostring(turnInfo.targetDeltaZ), tostring(turnInfo.zOffset)), 14);
			courseplay:debug(("%s:(Turn Data) reverseOffset=%q, isHarvester=%q"):format(nameNum(vehicle), tostring(turnInfo.reverseOffset), tostring(turnInfo.isHarvester)), 14);

			----------------------------------------------------------
			-- WIDE TURNS (Turns where the distance to next lane is bigger than the turning Diameter)
			----------------------------------------------------------
			if abs(turnInfo.targetDeltaX) >= turnInfo.turnDiameter then
				if abs(turnInfo.targetDeltaX) >= (turnInfo.turnDiameter * 2) and abs(turnInfo.targetDeltaZ) >= (turnInfo.turnRadius * 3) then
					courseplay:generateTurnTypeWideTurnWithAvoidance(vehicle, turnInfo);
				else
					courseplay:generateTurnTypeWideTurn(vehicle, turnInfo);
				end;


			----------------------------------------------------------
			-- NAROW TURNS (Turns where the distance to next lane is smaller than the turning Diameter)
			----------------------------------------------------------
			else
				--- If we have wheeled implement, then do turns based on that.
				if turnInfo.haveWheeledImplement then
					--- Get the Triangle sides
					local centerOffset = abs(turnInfo.targetDeltaX) / 2;
					local sideC = turnInfo.turnDiameter;
					local sideB = centerOffset + turnInfo.turnRadius;
					local centerHeight = square(sideC^2 - sideB^2);

					--- Check if there is enough space to make Ohm turn on the headland.
					local useOhmTurn = false;
					if (-turnInfo.zOffset + centerHeight + turnInfo.turnRadius + turnInfo.halfVehicleWidth) < turnInfo.headlandHeight then
						useOhmTurn = true;
					end;

					--- Ohm Turn
					if useOhmTurn or vehicle.cp.aiTurnNoBackward or not turnInfo.turnOnField then
						courseplay:generateTurnTypeOhmTurn(vehicle, turnInfo);

					--- Questionmark Turn
					else
						courseplay:generateTurnTypeQuestionmarkTurn(vehicle, turnInfo);
					end;

				--- If not wheeled implement, then do the short turns.
				else
					--- Get the Triangle sides
					turnInfo.centerOffset = (turnInfo.targetDeltaX * turnInfo.direction) - turnInfo.turnRadius;
					local sideC = turnInfo.turnDiameter;
					local sideB = turnInfo.turnRadius + turnInfo.centerOffset;
					turnInfo.centerHeight = square(sideC^2 - sideB^2);

					local neededSpace = abs(turnInfo.targetDeltaZ) + turnInfo.zOffset + 1 + turnInfo.centerHeight + (turnInfo.reverseWPChangeDistance * 1.5);
				    --- Forward 3 Point Turn
					if neededSpace < turnInfo.headlandHeight or turnInfo.isHarvester or not turnInfo.turnOnField then
						courseplay:generateTurnTypeForward3PointTurn(vehicle, turnInfo);

					--- Reverse 3 Point Turn
					else
						courseplay:generateTurnTypeReverse3PointTurn(vehicle, turnInfo);
					end;
				end;
			end;

			cpPrintLine(14, 1);
			courseplay:debug(string.format("%s:(Turn) Generated %d Turn Waypoints", nameNum(vehicle), #vehicle.cp.turnTargets), 14);
			cpPrintLine(14, 3);

			-- Rotate tools if needed.
			if turnInfo.targetDeltaX > 0 then
				AIVehicle.aiRotateLeft(vehicle);
			else
				AIVehicle.aiRotateRight(vehicle);
			end;

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
						local workToolX, _, workToolZ = getWorldTranslation(reversingWorkTool.cp.realTurningNode);
						local directionNodeToTurnNodeLengthOffset = courseplay:distance(workToolX, workToolZ, vehicleX, vehicleZ);
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

				-- Start reversing before time if we are allowed and if we can
				if newTarget.changeWhenPosible then
					-- Get the world rotation of the next lane
					local dx, dz = courseplay.generation:getPointDirection(vehicle.Waypoints[vehicle.cp.waypointIndex+1], vehicle.Waypoints[vehicle.cp.waypointIndex+2]);
					local laneRot = Utils.getYRotationFromDirection(dx, dz);
					laneRot = deg(laneRot);

					if reversingWorkTool and reversingWorkTool.cp.realTurningNode then
						-- Get the world rotation of the tool
						dx, _, dz = localDirectionToWorld(reversingWorkTool.cp.realTurningNode, 0, 0, 1);
					else
						-- Get the world rotation of the vehicle
						local directionNode = vehicle.aiVehicleDirectionNode or vehicle.cp.DirectionNode;
						dx, _, dz = localDirectionToWorld(directionNode, 0, 0, 1);
					end;
					local toolRot = Utils.getYRotationFromDirection(dx, dz);
					toolRot = deg(toolRot);
					--courseplay:debug(("%s:(Turn) laneRot=%.2f, toolRot=%.2f"):format(nameNum(vehicle), laneRot, toolRot), 14);

					-- Get the angle difference
					local angleDifference = min( abs((toolRot + 180 - laneRot) %360 - 180), abs((laneRot + 180 - toolRot) %360 - 180) )

					-- If the angle diff is less than the allowed angle, then goto the first wp in oposite drive direction
					if angleDifference then
						courseplay:debug(("%s:(Turn) Change direction when anglediff(%.2f) <= %.2f"):format(nameNum(vehicle), angleDifference, allowedAngle), 14);
						if angleDifference <= allowedAngle then
							local changeToForward = newTarget.turnReverse;
							for i = vehicle.cp.curTurnIndex, #vehicle.cp.turnTargets, 1 do
								if changeToForward and not vehicle.cp.turnTargets[i].turnReverse then
									courseplay:debug(("%s:(Turn) Changing to forward"):format(nameNum(vehicle)), 14);
									vehicle.cp.curTurnIndex = i;
									return;
								elseif not changeToForward and vehicle.cp.turnTargets[i].turnReverse then
									courseplay:debug(("%s:(Turn) Changing to reverse"):format(nameNum(vehicle)), 14);
									vehicle.cp.curTurnIndex = i;
									return;
								end;
							end;
						end;
					end;
				end;
			else
				vehicle.cp.turnStage = 1; -- (THIS SHOULD NEVER HAPPEN) Somehow we don't have any waypoints, so try recollect them.
				return;
			end;

		----------------------------------------------------------
		-- TURN STAGES 3 - Lower implement and continue on next lane
		----------------------------------------------------------
		elseif vehicle.cp.turnStage == 3 then
			local _, _, deltaZ = worldToLocal(vehicle.cp.DirectionNode,vehicle.Waypoints[vehicle.cp.waypointIndex+1].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex+1].cz)

			local lowerImplements = deltaZ < (isHarvester and frontMarker + 0.5 or frontMarker);
			if newTarget.turnReverse then
				refSpeed = vehicle.cp.speeds.reverse;
				lowerImplements = deltaZ > frontMarker;
			end;

			-- Lower implement and continue on next lane
			if lowerImplements then
				if vehicle.cp.abortWork == nil then
					courseplay:lowerImplements(vehicle, true, true);
				end;

				vehicle.cp.isTurning = nil;
				vehicle.cp.waitForTurnTime = vehicle.timer + turnOutTimer;

				courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1);
				courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle, true));
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
		--- Add WP to follow while doing last bit before raising Implement
		if not newTarget then
			local extraForward = 0;
			if backMarker < 0 then
				extraForward = abs(backMarker);
			end;
			local dx, dz = courseplay.generation:getPointDirection(vehicle.Waypoints[vehicle.cp.waypointIndex-1], vehicle.Waypoints[vehicle.cp.waypointIndex]);
			local cx, cz = courseplay:getVehicleOffsettedCoords(vehicle, vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vehicle.Waypoints[vehicle.cp.waypointIndex].cz);
			local posX, posZ = cx + (extraForward + 10) * dx, cz + (extraForward + 10) * dz;
			courseplay:addTurnTarget(vehicle, posX, posZ);
		end;

		if vehicle.isStrawEnabled then
			vehicle.cp.savedNoStopOnTurn = vehicle.cp.noStopOnTurn
			vehicle.cp.noStopOnTurn = false;
			turnTimer = vehicle.strawToggleTime or 5;
		elseif vehicle.cp.savedNoStopOnTurn ~= nil then
			vehicle.cp.noStopOnTurn = vehicle.cp.savedNoStopOnTurn;
			vehicle.cp.savedNoStopOnTurn = nil;
		end;

		--- Use the speed limit if we are still working and turn speed is higher that the speed limit.
		refSpeed = courseplay:getSpeedWithLimiter(vehicle, refSpeed);

	    local wpX, wpZ = vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vehicle.Waypoints[vehicle.cp.waypointIndex].cz;
		local _, _, disZ = worldToLocal(vehicle.cp.DirectionNode, wpX, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wpX, 300, wpZ), wpZ);

		if disZ < backMarker then
			if not vehicle.cp.noStopOnTurn then
				vehicle.cp.waitForTurnTime = vehicle.timer + turnTimer;
			end;
			courseplay:lowerImplements(vehicle, false, false);
			vehicle.cp.turnStage = 1;
		end;
	end;

	----------------------------------------------------------
	--Set the driving direction
	----------------------------------------------------------
	if newTarget then
		local directionNode = vehicle.aiVehicleDirectionNode or vehicle.cp.DirectionNode;
		dtpX,_,dtpZ = worldToLocal(directionNode, newTarget.posX, vehicleY, newTarget.posZ);
		if courseplay:isWheelloader(vehicle) then
			dtpZ = dtpZ * 0.5; -- wheel loaders need to turn more
		end;

		lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, newTarget.posX, vehicleY, newTarget.posZ);
		if newTarget.turnReverse then
			lx, lz, moveForwards = courseplay:goReverse(vehicle,lx,lz);
		end;
	end;

	----------------------------------------------------------
	-- Debug prints: Show Current Waypoint
	----------------------------------------------------------
	if courseplay.debugChannels[12] and newTarget then
		local posX, posZ = newTarget.revPosX or newTarget.posX, newTarget.revPosZ or newTarget.posZ;
		local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, posX, 300, posZ);
		drawDebugLine(posX, posY + 3, posZ, 0, 0, 1, posX, posY + 4, posZ, 0, 0, 1);  -- Blue Line
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
	if newTarget and (newTarget.turnReverse or not newTarget.useSmoothTurn) then
		if math.abs(vehicle.lastSpeedReal) < 0.0001 and  not g_currentMission.missionInfo.stopAndGoBraking then
			if not moveForwards then
				vehicle.nextMovingDirection = -1
			else
				vehicle.nextMovingDirection = 1
			end
		end

		AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, directionForce, 0.5, 20, allowedToDrive, moveForwards, lx, lz, refSpeed, 1);
	else
		AIVehicleUtil.driveToPoint(vehicle, dt, directionForce, allowedToDrive, moveForwards, dtpX, dtpZ, refSpeed);
	end;
	courseplay:setTrafficCollision(vehicle, lx, lz, true);
end;

function courseplay:generateTurnTypeWideTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Wide Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local canTurnOnHeadland = false;
	local center1, center2, startDir, intersect1, intersect2, stopDir = {}, {}, {}, {}, {}, {};

	-- Check if we can turn on the headlands
	if (-turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth) <= turnInfo.headlandHeight then
		canTurnOnHeadland = true;
	end;

	--- Get the center height offset
	if not turnInfo.haveHeadlands then
		turnInfo.reverseOffset = turnInfo.reverseOffset + abs(turnInfo.targetDeltaZ * 0.75);
	end;

	--- Add extra length to the directionNodeToTurnNodeLength if there is an pivoted tool behind the tractor.
	-- This is to prevent too sharp turning when reversing to the first reverse point.
	local directionNodeToTurnNodeLength = turnInfo.directionNodeToTurnNodeLength;
	if turnInfo.haveWheeledImplement and turnInfo.reversingWorkTool.cp.isPivot then
		directionNodeToTurnNodeLength = directionNodeToTurnNodeLength * 1.25;
	end;

	--- Extra WP 1 - Reverse back so we can turn inside the field (Only if we can't turn inside the headlands)
	if not canTurnOnHeadland and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
		-- Reverse back
		fromPoint.x, _, fromPoint.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, -directionNodeToTurnNodeLength);
		toPoint.x, _, toPoint.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset - directionNodeToTurnNodeLength - turnInfo.reverseWPChangeDistance);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);
	end;

	--- Get the 2 circle center cordinate
	center1.x,_,center1.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset);

	--- Get the circle intersection points
	intersect1.x, intersect1.z = center1.x, center1.z;
	intersect2.x, intersect2.z = center2.x, center2.z;
	intersect1, intersect2 = courseplay:getTurnCircleTangentIntersectionPoints(intersect1, intersect2, turnInfo.turnRadius, turnInfo.targetDeltaX > 0);

	--- Set start and stop dir for first turn circle
	startDir.x,_,startDir.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset);

	--- Generate turn circle 1
	courseplay:generateTurnCircle(vehicle, center1, startDir, intersect1, turnInfo.turnRadius, turnInfo.direction, true);
	--- Generate points between the 2 circles
	courseplay:generateTurnStraitPoints(vehicle, intersect1, intersect2);
	--- Generate turn circle 2
	courseplay:generateTurnCircle(vehicle, center2, intersect2, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

	--- Extra WP 2 - Reverse back to field edge
	if not canTurnOnHeadland and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
		-- Move a bit more forward
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset + directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, nil, nil, nil, true);

		-- Reverse back
		if turnInfo.reverseOffset - 3 > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset - 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, true, turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
		else
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
			local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance));
			courseplay:addTurnTarget(vehicle, posX, posZ, false, true, true, revPosX, revPosZ);
		end;

		--- Extra WP 3 - Turn End
	else
		posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.reverseOffset + turnInfo.directionNodeToTurnNodeLength + 5);
		courseplay:addTurnTarget(vehicle, posX, posZ, false, true);
	end;
end;

function courseplay:generateTurnTypeWideTurnWithAvoidance(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Wide Turn With Corner Avoidance", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local canTurnOnHeadland = false;
	local center, startDir, stopDir = {}, {}, {};

	-- Check if we can turn on the headlands
	if (-turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth) < turnInfo.headlandHeight then
		canTurnOnHeadland = true;
	end;

	--- Add extra length to the directionNodeToTurnNodeLength if there is an pivoted tool behind the tractor.
	-- This is to prevent too sharp turning when reversing to the first reverse point.
	local directionNodeToTurnNodeLength = turnInfo.directionNodeToTurnNodeLength;
	if turnInfo.haveWheeledImplement and turnInfo.reversingWorkTool.cp.isPivot then
		directionNodeToTurnNodeLength = directionNodeToTurnNodeLength * 1.25;
	end;

	--- Extra WP 1 - Reverse back so we can turn inside the field (Only if we can't turn inside the headlands)
	if not canTurnOnHeadland and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
		-- Reverse back
		fromPoint.x, _, fromPoint.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, -directionNodeToTurnNodeLength);
		toPoint.x, _, toPoint.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset - directionNodeToTurnNodeLength - turnInfo.reverseWPChangeDistance);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);-- Reverse back
	end;

	----------------------------------------------------------
	-- If new lane is in front of us, Do the 90-90-180 turn
	----------------------------------------------------------
	if turnInfo.targetDeltaZ > 0 then
		--- Generate the first turn circles
		center.x,_,center.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		stopDir.x,_,stopDir.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction);

		--- Generate line between first and second turn circles
		fromPoint.x, _, fromPoint.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		toPoint.x, _, toPoint.z = localToWorld(vehicle.cp.DirectionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnRadius - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);

		--- Generate the second turn circles
		center.x,_,center.z = localToWorld(vehicle.cp.DirectionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnRadius - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
		startDir.x,_,startDir.z = localToWorld(vehicle.cp.DirectionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnRadius - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		stopDir.x,_,stopDir.z = localToWorld(vehicle.cp.DirectionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1);

		--- Generate line between second and third turn circles
		fromPoint.x, _, fromPoint.z = localToWorld(vehicle.cp.DirectionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.reverseOffset);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);

		--- Generate the third turn circles
		center.x,_,center.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.reverseOffset);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

	----------------------------------------------------------
	-- If new lane is behind of us, Do the 180-90-90 turn
	----------------------------------------------------------
	else
		--- Generate the first turn circles
		center.x,_,center.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		stopDir.x,_,stopDir.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction);

		--- Generate line between first and second turn circles
		fromPoint.x, _, fromPoint.z = localToWorld(vehicle.cp.DirectionNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnDiameter);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);

		--- Generate the second turn circles
		center.x,_,center.z = localToWorld(turnInfo.targetNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter - turnInfo.turnRadius) * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnDiameter);
		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnDiameter);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter - turnInfo.turnRadius) * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnRadius);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1);

		--- Generate line between second and third turn circles
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter - turnInfo.turnRadius) * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnRadius);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnRadius);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);

		--- Generate the third turn circles
		center.x,_,center.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnRadius);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction, true);
	end;

	--- Extra WP 2 - Reverse back to field edge
	if not canTurnOnHeadland and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
		-- Move a bit more forward
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset + directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, nil, nil, nil, true);

		-- Reverse back
		if turnInfo.reverseOffset - 3 > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset - 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, true, turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
		else
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
			local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance));
			courseplay:addTurnTarget(vehicle, posX, posZ, false, true, true, revPosX, revPosZ);
		end;

		--- Extra WP 3 - Turn End
	else
		posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.reverseOffset + turnInfo.directionNodeToTurnNodeLength + 5);
		courseplay:addTurnTarget(vehicle, posX, posZ, false, true);
	end;
end;

function courseplay:generateTurnTypeOhmTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Ohm Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

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

	if turnInfo.frontMarker > 0 then
		targetOffsetZ = targetOffsetZ + (turnInfo.frontMarker * 1.5);
	end;

	--- Get the 3 circle center cordinate, startDir and stopDir
	local center1, center2, center3, startDir, stopDir = {}, {}, {}, {}, {};
	center1.x,_,center1.z = localToWorld(turnInfo.targetNode, (abs(turnInfo.targetDeltaX) + turnInfo.turnRadius) * turnInfo.direction, 0, turnInfo.zOffset - targetOffsetZ);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, centerOffset * turnInfo.direction, 0, turnInfo.zOffset - targetOffsetZ - centerHeight);
	center3.x,_,center3.z = localToWorld(turnInfo.targetNode, -turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - targetOffsetZ);
	startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, turnInfo.zOffset - targetOffsetZ);
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.zOffset - targetOffsetZ);

	--- Generate the 3 turn circles
	courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, (turnInfo.direction * -1));
	courseplay:generateTurnCircle(vehicle, center2, center1, center3, turnInfo.turnRadius, turnInfo.direction);
	courseplay:generateTurnCircle(vehicle, center3, center2, stopDir, turnInfo.turnRadius, (turnInfo.direction * -1), true);

	--- Extra WP - Make strait points to field edge if needed
	if turnInfo.frontMarker < 0 and turnInfo.zOffset - targetOffsetZ < 0 then
		local toPoint = {}
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.frontMarker - 3);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint);
	end;

	--- Extra WP - End Turn turnInfo.frontMarker
	posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.zOffset + (turnInfo.frontMarker < 0 and -turnInfo.frontMarker or 0) + 5);
	courseplay:addTurnTarget(vehicle, posX, posZ, false, true);
end;

function courseplay:generateTurnTypeQuestionmarkTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Questionmark Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local canTurnOnHeadland = false;
	local center1, center2, startDir, stopDir = {}, {}, {}, {};

	--- Get the Triangle sides
	local centerOffset = (turnInfo.targetDeltaX * turnInfo.direction) - turnInfo.turnRadius;
	local sideC = turnInfo.turnDiameter;
	local sideB = turnInfo.turnRadius + centerOffset;
	local centerHeight = square(sideC^2 - sideB^2);
	courseplay:debug(("%s:(Turn) centerOffset=%s, sideB=%s, sideC=%s, centerHeight=%s"):format(nameNum(vehicle), tostring(centerOffset), tostring(sideB), tostring(sideC), tostring(centerHeight)), 14);

	--- Check if we can turn on the headlands
	if (-turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth) < turnInfo.headlandHeight then
		canTurnOnHeadland = true;
	end;
	courseplay:debug(("%s:(Turn) canTurnOnHeadland=%s, headlandHeight=%.2fm, spaceNeeded=%.2fm"):format(nameNum(vehicle), tostring(canTurnOnHeadland), turnInfo.headlandHeight, (-turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth)), 14);

	--- Target is behind of us
	local targetOffsetZ = 0;
	if turnInfo.targetDeltaZ < turnInfo.zOffset then
		if canTurnOnHeadland then
			targetOffsetZ = abs(turnInfo.targetDeltaZ);
		else
			targetOffsetZ = turnInfo.zOffset + abs(turnInfo.targetDeltaZ);
		end;
	end;

	--- Front marker is in front of tractor
	local extraMoveBack = 0
	if turnInfo.frontMarker > 0 then
		extraMoveBack = turnInfo.frontMarker;
	end;

	--- Get the center height offset
	local centerHeightOffset = -targetOffsetZ + turnInfo.reverseOffset + extraMoveBack;
	if not turnInfo.haveHeadlands then
		centerHeightOffset = centerHeightOffset + abs(turnInfo.targetDeltaZ * 0.75);
	end;

	--- Get the numLanes and onLaneNum, so we can switch to the right turn maneuver.
	local widthLeft = (turnInfo.numLanes - turnInfo.onLaneNum) * vehicle.cp.courseWorkWidth;
	local doNormalTurn = (turnInfo.haveHeadlands and (turnInfo.turnDiameter + turnInfo.halfVehicleWidth) < (widthLeft + turnInfo.headlandHeight) or (turnInfo.turnDiameter + turnInfo.halfVehicleWidth) < widthLeft);
	courseplay:debug(("%s:(Turn) doNormalTurn=%s, haveHeadlands=%s, %d < %d,  %d < %d"):format(nameNum(vehicle), tostring(doNormalTurn), tostring(turnInfo.haveHeadlands), (turnInfo.turnDiameter + turnInfo.halfVehicleWidth), (widthLeft + turnInfo.headlandHeight), (turnInfo.turnDiameter + turnInfo.halfVehicleWidth), widthLeft), 14);

	--- Do the oposite direction turns for bale loaders, so we avoide bales in the normal turn direction
	if turnInfo.reversingWorkTool and courseplay:isBaleLoader(turnInfo.reversingWorkTool) then
		doNormalTurn = false;
	end;

	if doNormalTurn then
		----------------------------------------------------------
		-- Question Mark Turn.
		----------------------------------------------------------
		--- If we cant turn on headland, then reverse back into the field to turn there.
		--- This is to prevent vehicles to drive too much into fences and such
		if not canTurnOnHeadland then
			if turnInfo.targetDeltaZ + turnInfo.zOffset < centerHeightOffset then
				-- Reverse back
				fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset + 3);
				toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset + turnInfo.directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
				courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);
			else
				-- Move forward to the first turn circle
				fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, turnInfo.targetDeltaZ + turnInfo.zOffset);
				toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset);
				courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);
			end;
		end;

		--- Get the new zOffset
		local newZOffset = centerHeight + centerHeightOffset;
		courseplay:debug(("%s:(Turn) centerHeightOffset=%s, reverseOffset=%s, zOffset=%s, turnRadius=%s"):format(nameNum(vehicle), tostring(centerHeightOffset), tostring(turnInfo.reverseOffset), tostring(turnInfo.zOffset), tostring(turnInfo.turnRadius)), 14);

		--- Get the 2 circle center cordinate
		center1.x,_,center1.z = localToWorld(turnInfo.targetNode, centerOffset * turnInfo.direction, 0, centerHeightOffset);
		center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, newZOffset);

		--- Generate first turn circle
		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset);
		courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction);

		--- Generate second turn circle
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset);
		courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, (turnInfo.direction * -1), true);

		--- If we have headlands, then see if we can skip the reversing back part.
		if turnInfo.haveHeadlands and newZOffset < turnInfo.directionNodeToTurnNodeLength * 0.5 then
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
			courseplay:addTurnTarget(vehicle, posX, posZ, false, true);
		else
			--- Add extra length to the directionNodeToTurnNodeLength if there is an pivoted tool behind the tractor.
			-- This is to prevent too sharp turning when reversing to the first reverse point.
			local directionNodeToTurnNodeLength = turnInfo.directionNodeToTurnNodeLength;
			if turnInfo.haveWheeledImplement and turnInfo.reversingWorkTool.cp.isPivot then
				directionNodeToTurnNodeLength = directionNodeToTurnNodeLength * 1.25;
			end;

			--- Check if there is enought space to reverse back to the new lane start.
			local fromDistance = newZOffset - 3;
			local extraDistance = 0;
			if fromDistance < 0 then
				extraDistance = abs(fromDistance);
			end;

			--- Do we need to move extra back on the last reverse wp
			if turnInfo.targetDeltaZ > 0 then
				extraMoveBack = extraMoveBack + turnInfo.targetDeltaZ;
			end;

			--- Extra WP 1 - Move a bit more forward
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset + 3);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset + 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset + directionNodeToTurnNodeLength + extraDistance + turnInfo.wpChangeDistance + 6);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);

			---newZOffset
			if fromDistance > 0 then
				--- Extra WP 2 - Reverse with End Turn
				fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, fromDistance);
				toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
				courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, true, directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance);
			else
				--- Extra WP 2 - Reverse with End Turn
				posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
				local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance));
				courseplay:addTurnTarget(vehicle, posX, posZ, false, true, true, revPosX, revPosZ);
			end;
		end;
	else
		----------------------------------------------------------
		-- Reverse Question Mark Turn
		----------------------------------------------------------
		centerHeightOffset = centerHeightOffset + abs(turnInfo.targetDeltaZ * 0.25)
		--- Target is behind of us
		if turnInfo.targetDeltaZ < turnInfo.zOffset then
			centerHeightOffset = centerHeightOffset - abs(turnInfo.targetDeltaZ * 0.75)
		end;

		--- Get the new zOffset.
		local newZOffset = centerHeight + centerHeightOffset;

		--- If we cant turn on headland, then reverse back into the field to turn there.
		--- This is to prevent vehicles to drive too much into fences and such
		if not canTurnOnHeadland then
			--- Add the reverseOffset to centerHeigthOffset
			--centerHeightOffset = centerHeightOffset + turnInfo.reverseOffset;

			--- Recalculate the new zOffset since we need to reverse back.
			newZOffset = centerHeight + centerHeightOffset;

			--- Reverse back
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, turnInfo.targetDeltaZ + 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, newZOffset + turnInfo.directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);
		end;

		courseplay:debug(("%s:(Turn) centerHeightOffset=%s, reverseOffset=%s, zOffset=%s, turnRadius=%s"):format(nameNum(vehicle), tostring(centerHeightOffset), tostring(turnInfo.reverseOffset), tostring(turnInfo.zOffset), tostring(turnInfo.turnRadius)), 14);

		--- Get the 2 circle center cordinate
		center1.x,_,center1.z = localToWorld(turnInfo.targetNode, (abs(turnInfo.targetDeltaX) + turnInfo.turnRadius) * turnInfo.direction, 0, newZOffset);
		center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, centerHeightOffset);

		--- Generate first turn circle
		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, newZOffset);
		courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction * -1);

		--- Generate second turn circle
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, centerHeightOffset);
		courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

		--- Check if there is enought space to reverse back to the new lane start.
		local fromDistance = centerHeightOffset - 3;

		--- If the last turn circle ends 3m behind the new lane start, we dont need to reverse back.
		if fromDistance < -3 then
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
			courseplay:addTurnTarget(vehicle, posX, posZ, false, true);

		--- The last turn circle is less than 3m behind the lane start, so we have to reverse back.
		else
			local extraDistance = 0;
			if fromDistance < 3 then
				extraDistance = abs(fromDistance - 3);
			end;

			--- Do we need to move extra back on the last reverse wp
			if turnInfo.targetDeltaZ > 0 then
				extraMoveBack = extraMoveBack + turnInfo.targetDeltaZ;
			end;

			--- Add extra length to the directionNodeToTurnNodeLength if there is an pivoted tool behind the tractor.
			-- This is to prevent too sharp turning when reversing to the first reverse point.
			local directionNodeToTurnNodeLength = turnInfo.directionNodeToTurnNodeLength * 1.5;
			if turnInfo.haveWheeledImplement and turnInfo.reversingWorkTool.cp.isPivot then
				directionNodeToTurnNodeLength = turnInfo.directionNodeToTurnNodeLength * 1.75;
			end;

			--- Extra WP 1 - Move a bit more forward
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, centerHeightOffset);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, centerHeightOffset + directionNodeToTurnNodeLength + extraDistance + turnInfo.wpChangeDistance + 6);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);

			if fromDistance >= 3 then
				--- Extra WP 2 - Reverse with End Turn
				fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, fromDistance);
				toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
				courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, true, directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance);
			else
				--- Extra WP 2 - Reverse with End Turn
				posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
				local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance));
				courseplay:addTurnTarget(vehicle, posX, posZ, false, true, true, revPosX, revPosZ);
			end;
		end;
	end;
end;

function courseplay:generateTurnTypeForward3PointTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Forward 3 Point Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	--local canTurnOnHeadland = false;
	local center1, center2, startDir, stopDir = {}, {}, {}, {};

	--- Get the numLanes and onLaneNum, so we can switch to the right turn maneuver.
	local widthLeft = (turnInfo.numLanes - turnInfo.onLaneNum) * vehicle.cp.courseWorkWidth;
	local doNormalTurn = (turnInfo.turnDiameter + turnInfo.halfVehicleWidth) < widthLeft;
	courseplay:debug(("%s:(Turn) doNormalTurn=%s, %d < %d"):format(nameNum(vehicle), tostring(doNormalTurn), (turnInfo.turnDiameter + turnInfo.halfVehicleWidth), widthLeft), 14);

	if not doNormalTurn then
		--- We don't have space on the side we want to turn into, so we do the turn in oposite sirection
		turnInfo.direction = turnInfo.direction * -1;
	end;
	courseplay:debug(("%s:(Turn) centerOffset=%s, centerHeight=%s"):format(nameNum(vehicle), tostring(turnInfo.centerOffset), tostring(turnInfo.centerHeight)), 14);

	--if turnInfo.isHarvester then

	--- Get the 2 circle center cordinate
	center1.x,_,center1.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.targetDeltaZ + turnInfo.zOffset);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, turnInfo.targetDeltaZ + turnInfo.zOffset - turnInfo.centerHeight);

	--- Generate first turn circle (Forward)
	startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, turnInfo.targetDeltaZ + turnInfo.zOffset);
	courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction, true);

	--- Move a little bit more forward, so we can reverse properly
	local dx, dz = courseplay.generation:getPointDirection(center1, center2, false);
	local rotationDeg = deg(Utils.getYRotationFromDirection(dx, dz));
	rotationDeg = rotationDeg + (90 * turnInfo.direction);
	dx, dz = Utils.getDirectionFromYRotation(rad(rotationDeg));
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	posX = wp.posX + (2 * dx);
	posZ = wp.posZ + (2 * dz);
	courseplay:addTurnTarget(vehicle, posX, posZ);
	posX = wp.posX + (4 * dx);
	posZ = wp.posZ + (4 * dz);
	courseplay:addTurnTarget(vehicle, posX, posZ);
	posX = wp.posX + ((2 + turnInfo.wpChangeDistance) * dx);
	posZ = wp.posZ + ((2 + turnInfo.wpChangeDistance) * dz);
	courseplay:addTurnTarget(vehicle, posX, posZ);

	--- Generate second turn circle (Reversing)
	local zPossition = turnInfo.targetDeltaZ + turnInfo.zOffset - turnInfo.centerHeight;
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition);
	courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, turnInfo.direction, true, true);

	--- Move a bit furthen back
	fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition - 2);
	toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition - (turnInfo.reverseWPChangeDistance * 1.5));
	courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, nil, true);

	--- Move furthen back depending on the frontmarker
	if turnInfo.frontMarker < zPossition then
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition - (turnInfo.reverseWPChangeDistance * 2));
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.frontMarker - (turnInfo.reverseWPChangeDistance * 2));
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, nil, true);

		--- Generate forward straite line if needed
	else
		local extraLength = 2 + turnInfo.wpChangeDistance
		if turnInfo.frontMarker > 0 then
			extraLength = extraLength + turnInfo.frontMarker;
		end;
		if zPossition + extraLength < -3 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition + extraLength);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);
		end;
	end;

	--- Finish the turn
	posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength - turnInfo.zOffset + 5);
	courseplay:addTurnTarget(vehicle, posX, posZ, false, true);
end;

function courseplay:generateTurnTypeReverse3PointTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Reversing 3 Point Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	--local canTurnOnHeadland = false;
	local center1, center2, startDir, stopDir = {}, {}, {}, {};

	--- Get the numLanes and onLaneNum, so we can switch to the right turn maneuver.
	local widthLeft = (turnInfo.numLanes - turnInfo.onLaneNum) * vehicle.cp.courseWorkWidth;
	local doNormalTurn = (turnInfo.turnDiameter + turnInfo.halfVehicleWidth) < widthLeft;
	courseplay:debug(("%s:(Turn) doNormalTurn=%s, %d < %d"):format(nameNum(vehicle), tostring(doNormalTurn), (turnInfo.turnDiameter + turnInfo.halfVehicleWidth), widthLeft), 14);

	if not doNormalTurn then
		--- We don't have space on the side we want to turn into, so we do the turn in oposite sirection
		turnInfo.direction = turnInfo.direction * -1;
	end;

	--- Get the 2 circle center cordinate
	center1.x,_,center1.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.turnRadius * turnInfo.direction, 0, 1);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, 1 + turnInfo.centerHeight);

	--- Generate first turn circle (Forward) (Reversing)
	startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, 1);
	courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction * -1, true, true);

	--- Move a little bit more back, so we can align better when going forward
	local dx, dz = courseplay.generation:getPointDirection(center1, center2, false);
	local rotationDeg = deg(Utils.getYRotationFromDirection(dx, dz));
	rotationDeg = rotationDeg + (90 * turnInfo.direction);
	dx, dz = Utils.getDirectionFromYRotation(rad(rotationDeg));
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	posX = wp.posX - (2 * dx);
	posZ = wp.posZ - (2 * dz);
	courseplay:addTurnTarget(vehicle, posX, posZ, nil, nil, true);
	posX = wp.posX - (4 * dx);
	posZ = wp.posZ - (4 * dz);
	courseplay:addTurnTarget(vehicle, posX, posZ, nil, nil, true);
	posX = wp.posX - ((2 + turnInfo.reverseWPChangeDistance) * dx);
	posZ = wp.posZ - ((2 + turnInfo.reverseWPChangeDistance) * dz);
	courseplay:addTurnTarget(vehicle, posX, posZ, nil, nil, true);

	--- Generate second turn circle
	local zPossition = 1 + turnInfo.centerHeight;
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition);
	courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true);

	--- Move a bit furthen forward
	fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition + 2);
	toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition + 2 - turnInfo.zOffset + turnInfo.wpChangeDistance);
	courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);

	--- Move furthen forward depending on the frontmarker
	if turnInfo.frontMarker + zPossition + turnInfo.zOffset < 0 then
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition + (turnInfo.wpChangeDistance * 2));
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition + 2 + turnInfo.zOffset + abs(turnInfo.frontMarker) + (turnInfo.wpChangeDistance * 2));
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);

	--- Generate reverse straite line if needed
	else
		local extraLength = -2 - turnInfo.reverseWPChangeDistance;
		if turnInfo.frontMarker < 0 then
			extraLength = extraLength - turnInfo.frontMarker;
		end;
		if zPossition + extraLength > 3 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPossition + extraLength);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 2);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true);
		end;
	end;

	--- Finish the turn
	posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
	local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(turnInfo.directionNodeToTurnNodeLength + abs(turnInfo.frontMarker) + turnInfo.reverseWPChangeDistance));
	courseplay:addTurnTarget(vehicle, posX, posZ, false, true, true, revPosX, revPosZ);
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

function courseplay:getLaneInfo(vehicle)
	local numLanes			= 1;
	local onLaneNum			= 0;

	for index, wP in ipairs(vehicle.Waypoints) do
		local isWorkArea = index >= vehicle.cp.startWork and index <= vehicle.cp.stopWork;
		if (wP.generated or isWorkArea) and (not wP.lane or wP.lane >= 0) then
			if vehicle.cp.waypointIndex == index then
				onLaneNum = numLanes;
			end;

			if wP.turnStart then
				numLanes = numLanes + 1;
			end;
		end;
	end;

	courseplay:debug(("%s:(Turn) courseplay:getLaneInfo(), On Lane Nummber = %d, Number of Lanes = %d"):format(nameNum(vehicle), onLaneNum, numLanes), 14);
	return numLanes, onLaneNum;
end;

function courseplay:haveHeadlands(vehicle)
	return vehicle.cp.courseNumHeadlandLanes and vehicle.cp.courseNumHeadlandLanes > 0;
end;

function courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, reverse, turnEnd, secondaryReverseDistance, changeWhenPosible)
	local endTurn = false;
	local wpDistance = 3;
	local dist = courseplay:distance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z);
	local numPointsNeeded = ceil(dist / wpDistance);
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist;

	courseplay:addTurnTarget(vehicle, fromPoint.x, fromPoint.z, false, nil, reverse, nil, nil, nil, changeWhenPosible);

	local posX, posZ;
	if numPointsNeeded > 0 then
		wpDistance = dist / numPointsNeeded;
		for i=1, numPointsNeeded do
			posX = fromPoint.x + (i * wpDistance * dx);
			posZ = fromPoint.z + (i * wpDistance * dz);

			courseplay:addTurnTarget(vehicle, posX, posZ ,false, nil, reverse, nil, nil, nil, changeWhenPosible);
		end;
	end;

	local revPosX, revPosZ;
	if reverse and secondaryReverseDistance then
		revPosX = toPoint.x + (secondaryReverseDistance * dx);
		revPosZ = toPoint.z + (secondaryReverseDistance * dz);
	end;

	posX = toPoint.x;
	posZ = toPoint.z;

	if turnEnd == true then
		endTurn = turnEnd;
	end;

	courseplay:addTurnTarget(vehicle, posX, posZ, false, endTurn, reverse, revPosX, revPosZ, nil, changeWhenPosible);

end;

function courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, radius, clockWice, addEndPoint, reverse)
	-- Convert clockWice to the right format
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
	local cY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, center.x, 300, center.z);
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
		courseplay:addTurnTarget(vehicle, posX, posZ, true, nil, reverse, nil, nil, true);

		local _,rot,_ = getRotation(point);
		courseplay:debug(string.format("%s:(Turn:generateTurnCircle) waypoint %d curentRotation=%d", nameNum(vehicle), i, deg(rot)), 14);
	end;

	-- Clean up the created node.
	unlink(point);
	delete(point);
end;

function courseplay:addTurnTarget(vehicle, posX, posZ, useSmoothTurn, turnEnd, turnReverse, revPosX, revPosZ, dontPrint, changeWhenPosible)
	local target = {};
	target.posX 			  = posX;
	target.posZ 			  = posZ;
	target.useSmoothTurn	  = useSmoothTurn;
	target.turnEnd			  = turnEnd;
	target.turnReverse		  = turnReverse;
	target.revPosX 			  = revPosX;
	target.revPosZ 			  = revPosZ;
	target.changeWhenPosible = changeWhenPosible;
	table.insert(vehicle.cp.turnTargets, target);

	if not dontPrint then
		courseplay:debug(("%s:(Turn:addTurnTarget) posX=%.2f, posZ=%.2f, useSmoothTurn=%s, turnEnd=%s, turnReverse=%s, changeWhenPosible=%s"):format(nameNum(vehicle), posX, posZ, tostring(useSmoothTurn and true or false), tostring(turnEnd and true or false), tostring(turnReverse and true or false), tostring(changeWhenPosible and true or false)), 14);
	end;
end

function courseplay:clearTurnTargets(vehicle)
	vehicle.cp.turnStage = 0;
	vehicle.cp.turnTargets = {};
	vehicle.cp.curTurnIndex = 1;
	vehicle.cp.haveCheckedMarkersThisTurn = false;
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
		if moveDown then
			if workTool.aiLower ~= nil and not workTool:isLowered() then
				workTool:aiLower();
			end
		elseif workTool.aiRaise ~= nil and workTool:isLowered() then
				workTool:aiRaise()
		end

	end;
	if not specialTool then
		if self.cp.mode == 4 then
			for _,workTool in pairs(self.cp.workTools) do								 --vvTODO (Tom) why is this here vv?
				if workTool.setIsTurnedOn ~= nil and not courseplay:isFolding(workTool) and (true or workTool ~= self) and workTool.turnOnVehicle.isTurnedOn ~= workToolonOff then
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
end;
