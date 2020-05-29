local abs, min, max, floor, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.deg;
local _; --- The _ is an discard character for values not needed. Setting it to local, prevent's it from being an global variable.

--- SET VALUES
local wpDistance		= 1.5;  -- Waypoint Distance in Straight lines
local wpCircleDistance	= 1; 	-- Waypoint Distance in circles
-- if the direction difference between turnStart and turnEnd is bigger than this then
-- we consider that as a turn when switching to the next up/down lane and assume that
-- after the turn we'll be heading into the opposite direction. 
local laneTurnAngleThreshold = 150

---@param turnContext TurnContext
function courseplay:turn(vehicle, dt, turnContext)

	-- TODO: move this to TurnContext?
	local realDirectionNode					= AIDriverUtil.getDirectionNode(vehicle)
	local allowedToDrive 					= true;
	local moveForwards 						= true;
	local refSpeed 							= vehicle.cp.speeds.turn;
	local directionForce 					= 1;
	local lx, lz 							= 0, 1;
	local dtpX, dtpZ						= 0, 1;
	local turnOutTimer 						= 1500;
	local wpChangeDistance 					= 3;
	local reverseWPChangeDistance			= 5;
	local reverseWPChangeDistanceWithTool	= 3;
	local isHarvester						= Utils.getNoNil(courseplay:isCombine(vehicle) or courseplay:isChopper(vehicle) or courseplay:isHarvesterSteerable(vehicle), false);
	local allowedAngle						= vehicle.cp.changeDirAngle or isHarvester and 15 or 3; -- Used for changing direction if the vehicle or vehicle and tool angle difference are below that.
	if vehicle.cp.noStopOnEdge then
		turnOutTimer = 0;
	end;

	--- This is in case we use manually recorded fieldswork course and not generated.
	if not vehicle.cp.courseWorkWidth then
		courseplay:calculateWorkWidth(vehicle, true);
		vehicle.cp.courseWorkWidth = vehicle.cp.workWidth;
	end;

	-- find out the headland height to figure out if we have enough room on the headland to make turns
	if vehicle.cp.courseWorkWidth and vehicle.cp.courseWorkWidth > 0 and vehicle.cp.courseNumHeadlandLanes and vehicle.cp.courseNumHeadlandLanes > 0 then
		-- First headland is only half the work width
		vehicle.cp.headlandHeight = vehicle.cp.courseWorkWidth / 2 + ((vehicle.cp.courseNumHeadlandLanes - 1) * vehicle.cp.courseWorkWidth)
	else
		vehicle.cp.headlandHeight = 0
	end

	--- Get front and back markers
	local frontMarker = Utils.getNoNil(vehicle.cp.aiFrontMarker, -3);
	local backMarker = Utils.getNoNil(vehicle.cp.backMarkerOffset,0);

	local vehicleX, vehicleY, vehicleZ = getWorldTranslation(realDirectionNode);

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
						cpDebug:drawLine(turnTarget.posX, posY + 3, turnTarget.posZ, color["r"], color["g"], color["b"], nextTurnTarget.posX, nextPosY + 3, nextTurnTarget.posZ); -- Green Line
						if turnTarget.revPosX and turnTarget.revPosZ then
							nextPosY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.revPosX, 300, turnTarget.revPosZ);
							cpDebug:drawLine(turnTarget.posX, posY + 3, turnTarget.posZ, 1, 0, 0, turnTarget.revPosX, nextPosY + 3, turnTarget.revPosZ);  -- Red Line
						end;
					else
						local color = { r = 0, g = 1, b = 1}; -- Light Blue Line
						if nextTurnTarget.changeDirectionWhenAligned then
							color["r"], color["g"], color["b"] = 1, 0.706, 0; -- Orange Line
						end
						cpDebug:drawLine(turnTarget.posX, posY + 3, turnTarget.posZ, color["r"], color["g"], color["b"], nextTurnTarget.posX, nextPosY + 3, nextTurnTarget.posZ);  -- Light Blue Line
					end;
				elseif turnTarget.turnReverse and turnTarget.revPosX and turnTarget.revPosZ then
					local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.posX, 300, turnTarget.posZ);
					local nextPosY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, turnTarget.revPosX, 300, turnTarget.revPosZ);
					cpDebug:drawLine(turnTarget.posX, posY + 3, turnTarget.posZ, 1, 0, 0, turnTarget.revPosX, nextPosY + 3, turnTarget.revPosZ);  -- Red Line
				end;
			end;
		end;
		if turnContext and turnContext.turnStartWpNode and turnContext.turnEndWpNode then
			DebugUtil.drawDebugNode(turnContext.turnStartWpNode.node, 'Start')
			DebugUtil.drawDebugNode(turnContext.turnEndWpNode.node, 'End')
		end
	end;

	--- Get the directionNodeToTurnNodeLength used for reverse turn distances
	-- this is the distance between the tractor's directionNode and the real turning node of the implement (?)
	local directionNodeToTurnNodeLength = courseplay:getDirectionNodeToTurnNodeLength(vehicle);

	--- Get the firstReverseWheledWorkTool used for reversing
	local reversingWorkTool = courseplay:getFirstReversingWheeledWorkTool(vehicle);

	--- Reset reverseWPChangeDistance if we don't have an trailed implement
	if reversingWorkTool then
		reverseWPChangeDistance = reverseWPChangeDistanceWithTool;
	end;

	--- While driving (Stage 2 & 3), do we need to use the reversing WP change distance
	local curTurnTarget = vehicle.cp.turnTargets[vehicle.cp.curTurnIndex];
	if curTurnTarget and curTurnTarget.turnReverse then
		wpChangeDistance = reverseWPChangeDistance;
	end;



	----------------------------------------------------------
	-- TURN STAGES 1 - Create Turn maneuver (Creating waypoints to follow)
	----------------------------------------------------------
	if vehicle.cp.turnStage == 1 then
		--- Cleanup in case we already have old info
		courseplay:clearTurnTargets(vehicle); -- Make sure we have cleaned it from any previus usage.

		--- Setting default turnInfo values
		local turnInfo = {};
		turnInfo.directionNode					= realDirectionNode
		turnInfo.frontMarker					= frontMarker;
		turnInfo.backMarker						= backMarker;
		turnInfo.halfVehicleWidth 				= 2.5;
		turnInfo.directionNodeToTurnNodeLength  = directionNodeToTurnNodeLength + 0.5; -- 0.5 is to make the start turn point just a tiny in front of the tractor
		-- when PPC is driving we don't have to care about wp change distances, PPC takes care of that. Still use
		-- a small value to make sure none of the turn generator functions end up with overlapping waypoints
		turnInfo.wpChangeDistance				= 0.5
		turnInfo.reverseWPChangeDistance 		= 0.5
		turnInfo.direction 						= -1;
		turnInfo.haveHeadlands 					= courseplay:haveHeadlands(vehicle);
		-- Headland height in the waypoint overrides the generic headland height calculation. This is for the
		-- short edge headlands where we make 180 turns on te headland course. The generic calculation would use
		-- the number of headlands and think there is room on the headland to make the turn.
		-- Therefore, the course generator will add a headlandHeightForTurn = 0 for these turn waypoints to make
		-- sure on field turns are calculated correctly.
		turnInfo.headlandHeight 				= turnContext.turnStartWp.headlandHeightForTurn and
				turnContext.turnStartWp.headlandHeightForTurn or vehicle.cp.headlandHeight;
		turnInfo.numLanes ,turnInfo.onLaneNum 	= courseplay:getLaneInfo(vehicle);
		turnInfo.turnOnField 					= vehicle.cp.turnOnField;
		turnInfo.reverseOffset 					= 0;
		turnInfo.extraAlignLength				= 6;
		turnInfo.haveWheeledImplement 			= reversingWorkTool ~= nil;
		if turnInfo.haveWheeledImplement then
			turnInfo.reversingWorkTool 			= reversingWorkTool;
			turnInfo.extraAlignLength			= turnInfo.extraAlignLength + directionNodeToTurnNodeLength * 2;
		end;
		turnInfo.isHarvester					= isHarvester;

		-- headland turn data
		vehicle.cp.headlandTurn = turnContext:isHeadlandCorner() and {} or nil
		-- direction halfway between dir of turnStart and turnEnd
		turnInfo.halfAngle = math.deg( getAverageAngle( math.rad( turnContext.turnEndWp.angle ),
				math.rad( turnContext.turnStartWp.angle )))
		-- delta between turn start and turn end
		turnInfo.deltaAngle = math.pi - ( math.rad( turnContext.turnEndWp.angle )
				- math.rad( turnContext.turnStartWp.angle ))

		turnInfo.startDirection = turnContext.turnStartWp.angle

		--- Get the turn radius either by the automatic or user provided turn circle.
		local extRadius = 0.5 + (0.15 * directionNodeToTurnNodeLength); -- The extra calculation is for dynamic trailer length to prevent jackknifing;
		turnInfo.turnRadius = vehicle.cp.turnDiameter * 0.5 + extRadius;
		turnInfo.turnDiameter = turnInfo.turnRadius * 2;

		local totalOffsetX = vehicle.cp.totalOffsetX * -1

		--- Create temp target node and translate it.
		turnInfo.targetNode = createTransformGroup("cpTempTargetNode");
		link(g_currentMission.terrainRootNode, turnInfo.targetNode);
		local cx,cz = turnContext.turnEndWp.x, turnContext.turnEndWp.z
		local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 300, cz);
		setTranslation(turnInfo.targetNode, cx, cy, cz);
		turnContext:setTargetNode(targetNode)
		-- Rotate it's direction to the next wp.
		local yRot = MathUtil.getYRotationFromDirection(turnContext.turnEndWp.dx, turnContext.turnEndWp.dz);
		setRotation(turnInfo.targetNode, 0, yRot, 0);

		-- Retranslate it again to the correct position if there is offsets.
		if totalOffsetX ~= 0 then
			local totalOffsetZ
			if vehicle.cp.headlandTurn then
				-- headland turns are not near 180 degrees so just moving the target left/right won't work.
				-- we must move it back as well
				totalOffsetZ = totalOffsetX / math.tan( turnInfo.deltaAngle / 2 )
			else
				totalOffsetZ = 0
			end
			cx, cy, cz = localToWorld( turnInfo.targetNode, totalOffsetX, 0, totalOffsetZ )
			setTranslation(turnInfo.targetNode, cx, cy, cz);
			courseplay:debug(("%s:(Turn) Offset x = %.1f, z = %.1f"):format( nameNum( vehicle ), totalOffsetX, totalOffsetZ ), 14 )
		end;

		--- Debug Print
		if courseplay.debugChannels[14] then
			local x,y,z = getWorldTranslation(turnInfo.targetNode);
			local ctx,_,ctz = localToWorld(turnInfo.targetNode, 0, 0, 20);
			--drawDebugLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz, 0, 1, 0);
			cpDebug:drawLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz);
			-- this is an test
			courseplay:debug(("%s:(Turn) wp%d=%.1f°, wp%d=%.1f°, directionChangeDeg = %.1f° halfAngle = %.1f"):format(nameNum(vehicle),
					turnContext.beforeTurnStartWp.cpIndex, turnContext.beforeTurnStartWp.angle,  turnContext.turnEndWp.cpIndex, turnContext.turnEndWp.angle, turnContext.directionChangeDeg, turnInfo.halfAngle), 14);
		end;

		--- Get the local delta distances from the tractor to the targetNode
		turnInfo.targetDeltaX, _, turnInfo.targetDeltaZ = worldToLocal(turnInfo.directionNode, cx, vehicleY, cz);
		courseplay:debug(string.format("%s:(Turn) targetDeltaX=%.2f, targetDeltaZ=%.2f", nameNum(vehicle), turnInfo.targetDeltaX, turnInfo.targetDeltaZ), 14);

		--- Get the turn direction
		if turnContext:isHeadlandCorner() then
			-- headland corner turns have a targetDeltaX around 0 so use the direction diff
			if turnContext.directionChangeDeg > 0 then
				turnInfo.direction = 1;
			end
		else
			if turnInfo.targetDeltaX > 0 then
				turnInfo.direction = 1;
			end;
		end

		--- Check if tool width will collide on turn (Value is set in askForSpecialSettings)
		for i=1, #(vehicle.cp.workTools) do
			local workTool = vehicle.cp.workTools[i];
			if workTool.cp.widthWillCollideOnTurn and vehicle.cp.courseWorkWidth and (vehicle.cp.workWidth / 2) > turnInfo.halfVehicleWidth then
				turnInfo.halfVehicleWidth = vehicle.cp.workWidth / 2;
			end;
		end

		-- Relative position of the turn start waypoint from the vehicle.
		-- Note that as we start the turn when the backMarkerOffset reaches the turn start point, this zOffset
		-- is the same as the backMarkerOffset
		_, _, turnInfo.zOffset = worldToLocal(turnInfo.directionNode, turnContext.turnStartWp.x, vehicleY, turnContext.turnStartWp.z);
		-- remember this as we'll need it later
		turnInfo.deltaZBetweenVehicleAndTarget = turnInfo.targetDeltaZ
		-- targetDeltaZ is now the delta Z between the turn start and turn end waypoints.
		turnInfo.targetDeltaZ = turnInfo.targetDeltaZ - turnInfo.zOffset;

		-- Calculate reverseOffset in case we need to reverse.
		-- This is used in both wide turns and in the question mark turn
		local offset = turnInfo.zOffset;
		-- only if all implements are in the front
		if turnInfo.frontMarker > 0 and turnInfo.backMarker > 0 then
			offset = -turnInfo.zOffset - turnInfo.frontMarker;
		end;
		if turnInfo.turnOnField and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward then
			turnInfo.reverseOffset = max((turnInfo.turnRadius + turnInfo.halfVehicleWidth - turnInfo.headlandHeight), offset);
		elseif turnInfo.isHarvester and turnInfo.frontMarker > 0 then
			-- without fully understanding this reverseOffset, correct it for combines so they don't make
			-- unnecessarily wide turns (and hit trees outside the field)
			turnInfo.reverseOffset = -turnInfo.frontMarker
		else
			-- the weird thing about this is that reverseOffset here equals to zOffset and this is why
			-- the wide turn works at all, even if there's no reversing.
			turnInfo.reverseOffset = offset;
		end;

		courseplay:debug(("%s:(Turn Data) frontMarker=%q, backMarker=%q, halfVehicleWidth=%q, directionNodeToTurnNodeLength=%q, wpChangeDistance=%q"):format(nameNum(vehicle), tostring(turnInfo.frontMarker), tostring(backMarker), tostring(turnInfo.halfVehicleWidth), tostring(turnInfo.directionNodeToTurnNodeLength), tostring(turnInfo.wpChangeDistance)), 14);
		courseplay:debug(("%s:(Turn Data) reverseWPChangeDistance=%q, direction=%q, haveHeadlands=%q, headlandHeight=%q"):format(nameNum(vehicle), tostring(turnInfo.reverseWPChangeDistance), tostring(turnInfo.direction), tostring(turnInfo.haveHeadlands), tostring(turnInfo.headlandHeight)), 14);
		courseplay:debug(("%s:(Turn Data) numLanes=%q, onLaneNum=%q, turnOnField=%q, reverseOffset=%q"):format(nameNum(vehicle), tostring(turnInfo.numLanes), tostring(turnInfo.onLaneNum), tostring(turnInfo.turnOnField), tostring(turnInfo.reverseOffset)), 14);
		courseplay:debug(("%s:(Turn Data) haveWheeledImplement=%q, reversingWorkTool=%q, turnRadius=%q, turnDiameter=%q"):format(nameNum(vehicle), tostring(turnInfo.haveWheeledImplement), tostring(turnInfo.reversingWorkTool), tostring(turnInfo.turnRadius), tostring(turnInfo.turnDiameter)), 14);
		courseplay:debug(("%s:(Turn Data) targetNode=%q, targetDeltaX=%q, targetDeltaZ=%q, zOffset=%q"):format(nameNum(vehicle), tostring(turnInfo.targetNode), tostring(turnInfo.targetDeltaX), tostring(turnInfo.targetDeltaZ), tostring(turnInfo.zOffset)), 14);
		courseplay:debug(("%s:(Turn Data) reverseOffset=%q, isHarvester=%q"):format(nameNum(vehicle), tostring(turnInfo.reverseOffset), tostring(turnInfo.isHarvester)), 14);


		if not turnContext:isHeadlandCorner() then
			----------------------------------------------------------
			-- SWITCH TO THE NEXT LANE
			----------------------------------------------------------
			courseplay:debug(string.format("%s:(Turn) Direction difference is %.1f, this is a lane switch.", nameNum(vehicle), turnContext.directionChangeDeg), 14);
			----------------------------------------------------------
			-- WIDE TURNS (Turns where the distance to next lane is bigger than the turning Diameter)
			----------------------------------------------------------
			if abs(turnInfo.targetDeltaX) >= turnInfo.turnDiameter then
				if abs(turnInfo.targetDeltaX) >= (turnInfo.turnDiameter * 2) and abs(turnInfo.targetDeltaZ) >= (turnInfo.turnRadius * 3) then
					courseplay:generateTurnTypeWideTurnWithAvoidance(vehicle, turnInfo);
				else
					courseplay:generateTurnTypeWideTurn(vehicle, turnInfo);
				end

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
					if useOhmTurn or turnInfo.isHarvester or vehicle.cp.aiTurnNoBackward or not turnInfo.turnOnField then
						courseplay:generateTurnTypeOhmTurn(vehicle, turnInfo);
					else
						--- Questionmark Turn
						courseplay:generateTurnTypeQuestionmarkTurn(vehicle, turnInfo);
					end;

					--- If not wheeled implement, then do the short turns.
				else
					--- Get the Triangle sides
					turnInfo.centerOffset = (turnInfo.targetDeltaX * turnInfo.direction) - turnInfo.turnRadius;
					local sideC = turnInfo.turnDiameter;
					local sideB = turnInfo.turnRadius + turnInfo.centerOffset; -- which is exactly targetDeltaX, see above
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
			end
		else
			-------------------------------------------------------------
			-- A SHARP TURN, LIKELY ON THE HEADLAND BUT NOT A LANE SWITCH
			-------------------------------------------------------------
			courseplay:debug(string.format("%s:(Turn) Direction difference is %.1f, this is a corner, maneuver type = %d.",
					nameNum(vehicle), turnContext.directionChangeDeg, vehicle.cp.headland.reverseManeuverType), 14);

			vehicle.cp.turnCorner = turnContext:createCorner(vehicle, turnInfo.turnRadius)

			courseplay.generateTurnTypeHeadlandCornerReverseStraightTractor(vehicle, turnInfo)
		end

		cpPrintLine(14, 1);
		courseplay:debug(string.format("%s:(Turn) Generated %d Turn Waypoints", nameNum(vehicle), #vehicle.cp.turnTargets), 14);
		cpPrintLine(14, 3);

		unlink(turnInfo.targetNode);
		delete(turnInfo.targetNode);
	end

	----------------------------------------------------------
	--Set the driving direction
	----------------------------------------------------------
	if curTurnTarget then
		local posX, posZ = curTurnTarget.revPosX or curTurnTarget.posX, curTurnTarget.revPosZ or curTurnTarget.posZ;
		local directionNode = vehicle.aiVehicleDirectionNode or vehicle.cp.directionNode;
		dtpX,_,dtpZ = worldToLocal(directionNode, posX, vehicleY, posZ);
		if courseplay:isWheelloader(vehicle) then
			dtpZ = dtpZ * 0.5; -- wheel loaders need to turn more
		end;
		--print( ("dtp %.1f, %.1f, %.1f"):format( dtpX, dtpZ, refSpeed ))

		lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.directionNode, posX, vehicleY, posZ);
		if curTurnTarget.turnReverse then
			lx, lz, moveForwards = courseplay:goReverse(vehicle,lx,lz);
		end;
	end;
end

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
	if not turnInfo.haveHeadlands and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
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
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.directionNode, 0, 0, -directionNodeToTurnNodeLength);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.directionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset - directionNodeToTurnNodeLength - turnInfo.reverseWPChangeDistance);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);
	end;

	-- Get the 2 circle center coordinate
	-- I don't understand that turnInfo.zOffset here. That is our distance from the turn start WP, and with no reverseOffset it'll put the
	-- circle behind us. I think this is buggy, and only works with that magic at the beginning where we end up with the reverseOffset == zOffset
	center1.x,_,center1.z = localToWorld(turnInfo.directionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset);

	-- Get the circle intersection points
	intersect1.x, intersect1.z = center1.x, center1.z;
	intersect2.x, intersect2.z = center2.x, center2.z;
	intersect1, intersect2 = courseplay:getTurnCircleTangentIntersectionPoints(intersect1, intersect2, turnInfo.turnRadius, turnInfo.targetDeltaX > 0);

	--- Set start and stop dir for first turn circle
	startDir.x,_,startDir.z = localToWorld(turnInfo.directionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset);

	--- Generate turn circle 1
	courseplay:generateTurnCircle(vehicle, center1, startDir, intersect1, turnInfo.turnRadius, turnInfo.direction, true);
	--- Generate points between the 2 circles
	courseplay:generateTurnStraightPoints(vehicle, intersect1, intersect2);
	--- Generate turn circle 2
	courseplay:generateTurnCircle(vehicle, center2, intersect2, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

	--- Extra WP 2 - Reverse back to field edge
	if not canTurnOnHeadland and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
		-- Move a bit more forward
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset + directionNodeToTurnNodeLength + turnInfo.extraAlignLength + turnInfo.wpChangeDistance);
		courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, nil, nil, nil, true);

		-- Reverse back
		if turnInfo.reverseOffset - 3 > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset - 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, true, turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
		else
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
			local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance));
			courseplay:addTurnTarget(vehicle, posX, posZ, true, true, revPosX, revPosZ);
		end;

		--- Extra WP 3 - Turn End
	else
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.reverseOffset + turnInfo.directionNodeToTurnNodeLength + 5);
		courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, nil, true);
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
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.directionNode, 0, 0, -directionNodeToTurnNodeLength);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.directionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset - directionNodeToTurnNodeLength - turnInfo.reverseWPChangeDistance);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);-- Reverse back
	end;

	----------------------------------------------------------
	-- If new lane is in front of us, Do the 90-90-180 turn
	----------------------------------------------------------
	if turnInfo.targetDeltaZ > 0 then
		--- Generate the first turn circles
		center.x,_,center.z = localToWorld(turnInfo.directionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(turnInfo.directionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.directionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction);

		--- Generate line between first and second turn circles
		fromPoint.x, fromPoint.z = stopDir.x, stopDir.z
		toPoint.x, _, toPoint.z =  localToWorld(turnInfo.directionNode, turnInfo.targetDeltaX - turnInfo.direction * (turnInfo.turnRadius + turnInfo.turnDiameter), 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint);

		--- Generate the second turn circles
		center.x,_,center.z = localToWorld(turnInfo.directionNode, turnInfo.targetDeltaX - turnInfo.direction * (turnInfo.turnRadius + turnInfo.turnDiameter), 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
		startDir.x, startDir.z = toPoint.x, toPoint.z;
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.directionNode, turnInfo.targetDeltaX - turnInfo.direction * turnInfo.turnDiameter, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1);

		--- Generate line between second and third turn circles
		fromPoint.x, fromPoint.z = stopDir.x, stopDir.z;
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.reverseOffset);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint);

		--- Generate the third turn circles
		center.x,_,center.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.reverseOffset);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

		----------------------------------------------------------
		-- If new lane is behind  us, Do the 180-90-90 turn
		----------------------------------------------------------
	else
		--- Generate the first turn circles
		center.x,_,center.z = localToWorld(turnInfo.directionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(turnInfo.directionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.directionNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction);

		--- Generate line between first and second turn circles
		fromPoint.x, fromPoint.z = stopDir.x, stopDir.z
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.direction * turnInfo.turnDiameter, 0, turnInfo.reverseOffset - turnInfo.turnDiameter);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint);

		--- Generate the second turn circles
		center.x,_,center.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.direction * (turnInfo.turnRadius + turnInfo.turnDiameter), 0, turnInfo.reverseOffset - turnInfo.turnDiameter);
		startDir.x, startDir.z = toPoint.x, toPoint.z;
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.direction * (turnInfo.turnRadius + turnInfo.turnDiameter), 0, turnInfo.reverseOffset - turnInfo.turnRadius);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1);

		--- Generate line between second and third turn circles
		fromPoint.x, fromPoint.z = stopDir.x, stopDir.z
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset - turnInfo.turnRadius);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint);

		--- Generate the third turn circles
		center.x,_,center.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset);
		startDir.x, startDir.z = toPoint.x, toPoint.z;
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction, true);
	end;

	--- Extra WP 2 - Reverse back to field edge
	if not canTurnOnHeadland and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
		-- Move a bit more forward
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset + directionNodeToTurnNodeLength + turnInfo.extraAlignLength + turnInfo.wpChangeDistance);
		courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, nil, nil, nil, true);

		-- Reverse back
		if turnInfo.reverseOffset - 3 > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset - 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, true, turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
		else
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
			local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance));
			courseplay:addTurnTarget(vehicle, posX, posZ, true, true, revPosX, revPosZ);
		end;

		--- Extra WP 3 - Turn End
	else
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.reverseOffset + turnInfo.directionNodeToTurnNodeLength + 5);
		courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, nil, true);
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
		courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint);
	end;

	--- Extra WP - End Turn turnInfo.frontMarker
	posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.zOffset + (turnInfo.frontMarker < 0 and -turnInfo.frontMarker or 0) + 5);
	courseplay:addTurnTarget(vehicle, posX, posZ, true);
end;

function courseplay:generateTurnTypeQuestionmarkTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Questionmark Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local canTurnOnHeadland = false;
	local center1, center2, startDir, stopDir = {}, {}, {}, {};

	local isReverseingBaleLoader = turnInfo.reversingWorkTool and courseplay:isBaleLoader(turnInfo.reversingWorkTool)

	--- Get the Triangle sides
	local centerOffset = (turnInfo.targetDeltaX * turnInfo.direction) - turnInfo.turnRadius;
	local sideC = turnInfo.turnDiameter;
	local sideB = turnInfo.turnRadius + centerOffset;
	local centerHeight = square(sideC^2 - sideB^2);
	courseplay:debug(("%s:(Turn) centerOffset=%s, sideB=%s, sideC=%s, centerHeight=%s"):format(nameNum(vehicle), tostring(centerOffset), tostring(sideB), tostring(sideC), tostring(centerHeight)), 14);

	--- Check if we can turn on the headlands
	local spaceNeeded = 0;
	if vehicle.cp.oppositeTurnMode or isReverseingBaleLoader then
		spaceNeeded = -turnInfo.zOffset + centerHeight + turnInfo.turnRadius + turnInfo.halfVehicleWidth;
	else
		spaceNeeded = -turnInfo.zOffset + turnInfo.turnRadius + turnInfo.halfVehicleWidth;
	end;

	if spaceNeeded < turnInfo.headlandHeight then
		canTurnOnHeadland = true;
	end;

	courseplay:debug(("%s:(Turn) canTurnOnHeadland=%s, headlandHeight=%.2fm, spaceNeeded=%.2fm"):format(nameNum(vehicle), tostring(canTurnOnHeadland), turnInfo.headlandHeight, spaceNeeded), 14);

	--- Target is behind of us
	local targetOffsetZ = 0;
	if turnInfo.deltaZBetweenVehicleAndTarget < 0 then
		if canTurnOnHeadland then
			targetOffsetZ = abs(turnInfo.targetDeltaZ);
		else
			targetOffsetZ = turnInfo.zOffset + abs(turnInfo.targetDeltaZ);
		end;
	end;

	--- Front marker is in front of tractor
	local extraMoveBack = 0
	-- This works fine as long as there's no implement with a work area in the back as well. We don't really handle that
	-- case properly. In stage 0 we check for the backmarker to change to stage 1 so we'll be further ahead than with
	-- a front implement only. So no need to move the circle back, actually it should be moved forward but I don't have
	-- the motivation to change that, for now, just don't move back, this works most of the time.
	if turnInfo.frontMarker > 0 and turnInfo.backMarker > 0 then
		extraMoveBack = turnInfo.frontMarker;
	end;
	courseplay:debug(("%s:(Turn) targetOffsetZ=%s, extraMoveBack=%.2fm"):format(nameNum(vehicle), tostring(targetOffsetZ), extraMoveBack), 14);

	--- Get the center height offset
	local centerHeightOffset = -targetOffsetZ + turnInfo.reverseOffset + extraMoveBack;
	if not turnInfo.haveHeadlands then
		centerHeightOffset = centerHeightOffset + abs(turnInfo.targetDeltaZ * 0.75);
	end;

	--- Get the numLanes and onLaneNum, so we can switch to the right turn maneuver.
	local width = vehicle.cp.courseWorkWidth * 0.5;
	local doNormalTurn = true;
	local widthNeeded = turnInfo.turnDiameter + turnInfo.halfVehicleWidth - vehicle.cp.courseWorkWidth;
	if vehicle.cp.oppositeTurnMode then
		width = turnInfo.onLaneNum * vehicle.cp.courseWorkWidth - (vehicle.cp.courseWorkWidth * 0.5);
		doNormalTurn = (turnInfo.haveHeadlands and widthNeeded > (width + turnInfo.headlandHeight) or widthNeeded > width);
		courseplay:debug(("%s:(Turn) doNormalTurn=%s, haveHeadlands=%s, %.1fm > %.1fm"):format(nameNum(vehicle), tostring(doNormalTurn), tostring(turnInfo.haveHeadlands), widthNeeded, (turnInfo.haveHeadlands and (width + turnInfo.headlandHeight) or width)), 14);
	else
		width = (turnInfo.numLanes - turnInfo.onLaneNum) * vehicle.cp.courseWorkWidth - (vehicle.cp.courseWorkWidth * 0.5);
		doNormalTurn = (turnInfo.haveHeadlands and widthNeeded < (width + turnInfo.headlandHeight) or widthNeeded < width);
		courseplay:debug(("%s:(Turn) doNormalTurn=%s, haveHeadlands=%s, %.1fm < %.1fm"):format(nameNum(vehicle), tostring(doNormalTurn), tostring(turnInfo.haveHeadlands), widthNeeded, (turnInfo.haveHeadlands and (width + turnInfo.headlandHeight) or width)), 14);
	end;

	--- Do the opposite direction turns for bale loaders, so we avoid bales in the normal turn direction
	if doNormalTurn and isReverseingBaleLoader then
		courseplay.debugVehicle(14, vehicle, '(Turn) opposite direction for bale loaders to avoid bales')
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
				courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);
			else
				-- Move forward to the first turn circle
				fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, turnInfo.targetDeltaZ + turnInfo.zOffset);
				toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, centerHeightOffset);
				courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint);
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
		courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, (turnInfo.direction * -1), false);

		--- If we have headlands, then see if we can skip the reversing back part.
		if turnInfo.haveHeadlands and newZOffset < turnInfo.directionNodeToTurnNodeLength * 0.5 then
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
			courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, false, true);
		else
			--- Add extra length to the directionNodeToTurnNodeLength if there is an pivoted tool behind the tractor.
			-- This is to prevent too sharp turning when reversing to the first reverse point.
			local directionNodeToTurnNodeLength = turnInfo.directionNodeToTurnNodeLength;
			if turnInfo.haveWheeledImplement and turnInfo.reversingWorkTool.cp.isPivot then
				directionNodeToTurnNodeLength = directionNodeToTurnNodeLength * 1.25;
			end;

			--- Check if there is enough space to reverse back to the new lane start.
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
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint);
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset + 4);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset + directionNodeToTurnNodeLength + extraDistance + turnInfo.extraAlignLength + turnInfo.wpChangeDistance);
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);

			---newZOffset
			if fromDistance > 0 then
				--- Extra WP 2 - Reverse with End Turn
				fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, fromDistance);
				toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
				courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, true, directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance);
			else
				--- Extra WP 2 - Reverse with End Turn
				posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
				local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance));
				courseplay:addTurnTarget(vehicle, posX, posZ, true, true, revPosX, revPosZ);
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
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);
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
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
			courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, false, true);

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
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, centerHeightOffset + directionNodeToTurnNodeLength + extraDistance + turnInfo.extraAlignLength + turnInfo.wpChangeDistance);
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);

			if fromDistance >= 3 then
				--- Extra WP 2 - Reverse with End Turn
				fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, fromDistance);
				toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
				courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, true, directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance);
			else
				--- Extra WP 2 - Reverse with End Turn
				posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
				local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(directionNodeToTurnNodeLength + extraMoveBack + turnInfo.reverseWPChangeDistance));
				courseplay:addTurnTarget(vehicle, posX, posZ, true, true, revPosX, revPosZ);
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
	local center1, center2, startDir, intersect1, intersect2, stopDir = {}, {}, {}, {}, {}, {};

	local frontOffset = -1;
	if turnInfo.frontMarker > 0 then
		frontOffset = frontOffset - turnInfo.frontMarker;
	end;
	-- getAttachedImplementsAllowTurnBackward will return true for anything easy to reverse, that is has no towed implement,
	-- like combines or tractors with implements mounted on the 3 point hitch. Those should make the same turn (fishtail or K-turn)
	-- as combines do as it takes up a lot less space on the headland. Our calculation of how much space is needed is still off a bit
	-- so you may have to turn off 'turn on field' for this to work for tractors.
	if not ((courseplay:isCombine(vehicle) or courseplay:isChopper(vehicle)) and not courseplay:isHarvesterSteerable(vehicle)) and
		not AIVehicleUtil.getAttachedImplementsAllowTurnBackward(vehicle) then

		local targetDeltaZ = turnInfo.targetDeltaZ;
		if targetDeltaZ > 0 then
			targetDeltaZ = 0;
		end;

		--- Get the numLanes and onLaneNum, so we can switch to the right turn maneuver.
		local width = vehicle.cp.courseWorkWidth * 0.5;
		local doNormalTurn = true;
		local widthNeeded = turnInfo.turnDiameter + turnInfo.halfVehicleWidth - vehicle.cp.courseWorkWidth;
		if vehicle.cp.oppositeTurnMode then
			width = turnInfo.onLaneNum * vehicle.cp.courseWorkWidth - (vehicle.cp.courseWorkWidth * 0.5);
			doNormalTurn = widthNeeded > width;
			courseplay:debug(("%s:(Turn) doNormalTurn=%s, %.1fm > %.1fm"):format(nameNum(vehicle), tostring(doNormalTurn), widthNeeded, width), 14);
		else
			width = (turnInfo.numLanes - turnInfo.onLaneNum) * vehicle.cp.courseWorkWidth - (vehicle.cp.courseWorkWidth * 0.5);
			doNormalTurn = widthNeeded < width;
			courseplay:debug(("%s:(Turn) doNormalTurn=%s, %.1fm < %.1fm"):format(nameNum(vehicle), tostring(doNormalTurn), widthNeeded, width), 14);
		end;

		if not doNormalTurn then
			--- We don't have space on the side we want to turn into, so we do the turn in opposite direction
			turnInfo.direction = turnInfo.direction * -1;
		end;
		courseplay:debug(("%s:(Turn) centerOffset=%s, centerHeight=%s"):format(nameNum(vehicle), tostring(turnInfo.centerOffset), tostring(turnInfo.centerHeight)), 14);

		--- Get the 2 circle center coordinate
		center1.x,_,center1.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.turnRadius * turnInfo.direction, 0, targetDeltaZ + turnInfo.zOffset + frontOffset);
		center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, targetDeltaZ + turnInfo.zOffset - turnInfo.centerHeight + frontOffset);

		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, targetDeltaZ + turnInfo.zOffset + frontOffset);

		--- Generate Strait point up to start point
		if turnInfo.targetDeltaZ > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.directionNode, 0, 0, 0);
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, startDir);
		end;

		--- Generate first turn circle (Forward)
		courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction, true);

		--- Move a little bit more forward, so we can reverse properly
		local dx, dz = courseplay:getPointDirection(center1, center2, false);
		local rotationDeg = deg(MathUtil.getYRotationFromDirection(dx, dz));
		rotationDeg = rotationDeg + (90 * turnInfo.direction);
		dx, dz = MathUtil.getDirectionFromYRotation(rad(rotationDeg));
		local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
		fromPoint.x = wp.posX;
		fromPoint.z = wp.posZ;
		toPoint.x = wp.posX + ((2 + turnInfo.wpChangeDistance) * dx);
		toPoint.z = wp.posZ + ((2 + turnInfo.wpChangeDistance) * dz);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint);

		--- Generate second turn circle (Reversing)
		local zPosition = targetDeltaZ + turnInfo.zOffset - turnInfo.centerHeight + frontOffset;
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition);
		courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, turnInfo.direction, true, true);

		--- Move a bit further back
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition - 2);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition - (turnInfo.reverseWPChangeDistance * 1.5));
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, nil, nil, true);

		--- Move further back depending on the frontmarker
		if turnInfo.frontMarker < zPosition then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition - (turnInfo.reverseWPChangeDistance * 2));
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.frontMarker - (turnInfo.reverseWPChangeDistance * 2));
			courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, nil, nil, true);
		end;

		--- Finish the turn
		local x, z = toPoint.x, toPoint.z;
		fromPoint.x = x;
		fromPoint.z = z;
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength - turnInfo.zOffset + 5);
		courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, false, true);
	else
		--- Get the 2 circle center coordinate
		local center1ZOffset = turnInfo.targetDeltaZ + turnInfo.zOffset + frontOffset;
		local center2ZOffset = frontOffset

		center1.x,_,center1.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.turnRadius * turnInfo.direction, 0, center1ZOffset);
		center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, center2ZOffset);
		--- Get the circle intersection points
		intersect1.x, intersect1.z = center1.x, center1.z;
		intersect2.x, intersect2.z = center2.x, center2.z;
		intersect2, intersect1 = courseplay:getTurnCircleTangentIntersectionPoints(intersect2, intersect1, turnInfo.turnRadius, turnInfo.targetDeltaX > 0);

		--- Generate first turn circle (Forward)
		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, center1ZOffset);
		courseplay:generateTurnCircle(vehicle, center1, startDir, intersect1, turnInfo.turnRadius, turnInfo.direction, true);

		--- Move a little bit more forward, so we can reverse properly
		local dx, dz = courseplay:getPointDirection(intersect2, intersect1, false);
		toPoint.x = intersect1.x + (turnInfo.wpChangeDistance * dx);
		toPoint.z = intersect1.z + (turnInfo.wpChangeDistance * dz);
		courseplay:generateTurnStraightPoints(vehicle, intersect1, toPoint);

		--- Reverse back to the second turn circle start point
		fromPoint.x = intersect1.x - (2 * dx);
		fromPoint.z = intersect1.z - (2 * dz);
		toPoint.x = intersect2.x - ((2 + turnInfo.reverseWPChangeDistance) * dx);
		toPoint.z = intersect2.z - ((2 + turnInfo.reverseWPChangeDistance) * dz);
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true);

		--- Generate second turn circle (Forward)
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, center2ZOffset);
		courseplay:generateTurnCircle(vehicle, center2, intersect2, stopDir, turnInfo.turnRadius, turnInfo.direction, false);

		--- Finish the turn
		toPoint.x,_,toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, abs(turnInfo.frontMarker) + 5);
		courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, false, true);

		-- make sure implement is lowered by the time we get to the up/down row, so start lowering well before
	end;
end;

function courseplay:generateTurnTypeReverse3PointTurn(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Reversing 3 Point Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local center1, center2, startDir, stopDir = {}, {}, {}, {};

	local targetDeltaZ = 0;
	if turnInfo.targetDeltaZ > 0 then
		targetDeltaZ = turnInfo.targetDeltaZ;
	end;

	--- Get the numLanes and onLaneNum, so we can switch to the right turn maneuver.
	local width = vehicle.cp.courseWorkWidth * 0.5;
	local doNormalTurn = true;
	local widthNeeded = turnInfo.turnDiameter + turnInfo.halfVehicleWidth - vehicle.cp.courseWorkWidth;
	-- TODO: even if getLaneInfo() was working correctly, this part only works for rectangular fields
	if vehicle.cp.oppositeTurnMode then
		width = turnInfo.onLaneNum * vehicle.cp.courseWorkWidth - (vehicle.cp.courseWorkWidth * 0.5);
		doNormalTurn = widthNeeded > width;
		courseplay:debug(("%s:(Turn) doNormalTurn=%s, %.1fm > %.1fm"):format(nameNum(vehicle), tostring(doNormalTurn), widthNeeded, width), 14);
	else
		width = (turnInfo.numLanes - turnInfo.onLaneNum) * vehicle.cp.courseWorkWidth - (vehicle.cp.courseWorkWidth * 0.5);
		doNormalTurn = widthNeeded < width;
		courseplay:debug(("%s:(Turn) doNormalTurn=%s, %.1fm < %.1fm"):format(nameNum(vehicle), tostring(doNormalTurn), widthNeeded, width), 14);
	end;

	if not doNormalTurn then
		--- We don't have space on the side we want to turn into, so we do the turn in oposite direction
		turnInfo.direction = turnInfo.direction * -1;
	end;

	--- Get the 2 circle center coordinate
	center1.x,_,center1.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.turnRadius * turnInfo.direction, 0, 1 + targetDeltaZ);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, 1 + turnInfo.centerHeight + targetDeltaZ);

	--- Generate first turn circle (Reversing)
	startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, 1 + targetDeltaZ);
	courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction * -1, true, true);

	--- Move a little bit more back, so we can align better when going forward
	local dx, dz = courseplay:getPointDirection(center1, center2, false);
	local rotationDeg = deg(MathUtil.getYRotationFromDirection(dx, dz));
	rotationDeg = rotationDeg + (90 * turnInfo.direction);
	dx, dz = MathUtil.getDirectionFromYRotation(rad(rotationDeg));
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	fromPoint.x = wp.posX;
	fromPoint.z = wp.posZ;
	toPoint.x = wp.posX - ((2 + turnInfo.reverseWPChangeDistance) * dx);
	toPoint.z = wp.posZ - ((2 + turnInfo.reverseWPChangeDistance) * dz);
	courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true);

	--- Generate second turn circle (Forward)
	local zPosition = 1 + turnInfo.centerHeight + targetDeltaZ;
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition);
	courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true);

	--- Move a bit further forward
	fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition + 2);
	toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition + 2 - turnInfo.zOffset + turnInfo.wpChangeDistance);
	courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);

	--- Move further forward depending on the frontmarker
	if turnInfo.frontMarker + zPosition + turnInfo.zOffset < 0 then
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition + (turnInfo.wpChangeDistance * 2));
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, zPosition + 2 + turnInfo.zOffset + abs(turnInfo.frontMarker) + (turnInfo.wpChangeDistance * 2));
		courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, nil, nil, nil, true);
	end;

	--- Finish the turn
	local x, z = toPoint.x, toPoint.z;
	fromPoint.x = x;
	fromPoint.z = z;
	toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
	courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, true, true, turnInfo.directionNodeToTurnNodeLength + abs(turnInfo.frontMarker) + turnInfo.reverseWPChangeDistance);
end;

------------------------------------------------------------------------
-- Turns for headland corners (direction change way less than 180) to not
-- miss fruit in the corner.
--
-- We don't use turnStart in this maneuver
-- 
-- We assume the following:
--
-- turnEnd       x-----
--               |
-- turnStart     ^
--               |
--               |
--
------------------------------------------------------------------------
-- Drive past turnEnd, up to the edge of the field (or current headland), then 
-- reverse back with a curve, covering half the direction change, then
-- forward on a curve, reaching the target direction at turnEnd
------------------------------------------------------------------------
function courseplay.generateTurnTypeHeadlandCornerReverseWithCurve(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Headland Corner Turn", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local fromPoint, toPoint = {}, {};
	local centerReverse, tempCenterReverse, centerForward, startDir, stopDir = {}, {}, {}, {}, {}

	-- start with the easy one, get the center of the forward turning circle (this is based on the targetNode)
	centerForward.x,_,centerForward.z = localToWorld(turnInfo.targetNode, - turnInfo.direction * turnInfo.turnRadius, 0, 0 )
	-- create a transform group there, rotation set to the half angle between turnStart and turnEnd.
	local forwardCircleCenterNode =
	courseplay.createNode( "cpForwardCircleCenterNode", centerForward.x, centerForward.z, math.rad( turnInfo.halfAngle ))

	-- temporary center of the reversing arc
	tempCenterReverse.x,_,tempCenterReverse.z = localToWorld( forwardCircleCenterNode, 2 * turnInfo.direction * turnInfo.turnRadius, 0, 0 )
	-- because we'll have to move it into turnInfo.halfAngle direction until it touches the turnStart direction line from turnTarget
	local tempReverseCircleCenterNode =
	courseplay.createNode( "cpTempReverseCircleCenterNode", tempCenterReverse.x, tempCenterReverse.z, math.rad( turnInfo.halfAngle ))

	-- so create a helper node from turnTarget but this time rotated into the turnStart direction
	local tx, _, tz = localToWorld( turnInfo.targetNode, 0, 0, 0 )
	local turnStartNode = courseplay.createNode( "cpTurnStartNode", tx, tz, math.rad( turnInfo.startDirection ))

	local dxTRevC, _, dzTRevC = worldToLocal( turnStartNode, tempCenterReverse.x, 0, tempCenterReverse.z )

	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCorner(), local T->TempRevC ( %.2f %.2f )"):format(
		nameNum(vehicle), dxTRevC, dzTRevC ), 14);

	-- temp circle must be moved until it is exactly turnRadius away from the turnStart line
	local beta = math.pi / 2 - math.abs( getDeltaAngle( math.rad( turnInfo.halfAngle ), math.rad(turnInfo.startDirection )))
	local xOffset =  math.abs( dxTRevC ) - turnInfo.turnRadius
	local lzOffset = xOffset / math.cos( beta )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCorner(), beta %.2f, xOffset %.2f, lzOffset %.2f"):format(
		nameNum(vehicle), beta, xOffset, lzOffset ), 14);
	centerReverse.x, _,  centerReverse.z = localToWorld( tempReverseCircleCenterNode, 0, 0, lzOffset )
	local reverseCircleCenterNode =
	courseplay.createNode( "cpReverseCircleCenterNode", centerReverse.x, centerReverse.z, math.rad( turnInfo.halfAngle ))

	local dxRevC, _, dzRevC = worldToLocal( turnStartNode, centerReverse.x, 0, centerReverse.z ) -- dxRevC must be equal to radius here

	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCorner(), tempRevCircle ( %.2f %.2f ), fwdCircle( %.2f %.2f )"):format(
		nameNum(vehicle), tempCenterReverse.x, tempCenterReverse.z, centerForward.x, centerForward.z ), 14);
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCorner(), local T->RevC ( %.2f %.2f )"):format(
		nameNum(vehicle), dxRevC, dzRevC ), 14);
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCorner(), revCircle ( %.2f %.2f ), fwdCircle( %.2f %.2f )"):format(
		nameNum(vehicle), centerReverse.x, centerReverse.z, centerForward.x, centerForward.z ), 14);
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCorner(), targetNode ( %.2f %.2f )"):format(
		nameNum(vehicle), tx, tz ), 14);

	-- get to the point where we want to start the reverse turn
	fromPoint.x, _, fromPoint.z = localToWorld( turnInfo.directionNode, 0, 0, 0 )
	-- drive a little past of our target, so we'll start reversing only when we 
	-- really reached turnEnd
	toPoint.x, _, toPoint.z = localToWorld( turnStartNode, 0, 0, dzRevC + 3 )
	courseplay:generateTurnStraightPoints( vehicle, fromPoint, toPoint, false )

	--- Generate first turn circle (Reversing)
	startDir.x,_,startDir.z = localToWorld( turnStartNode, 0, 0, dzRevC )
	stopDir.x,_,stopDir.z = localToWorld( reverseCircleCenterNode, - turnInfo.direction * turnInfo.turnRadius, 0, 0 )
	courseplay:generateTurnCircle( vehicle, centerReverse, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true, true )

	-- now go straight back to where the forward arc starts (and a bit more )
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	fromPoint.x = wp.posX;
	fromPoint.z = wp.posZ;
	toPoint.x, _, toPoint.z = localToWorld( forwardCircleCenterNode, turnInfo.direction * turnInfo.turnRadius, 0, -turnInfo.reverseWPChangeDistance )
	courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true);

	--- Generate second turn circle (Forward)
	startDir.x, _, startDir.z = localToWorld( tempReverseCircleCenterNode, 0, 0, 0 )
	stopDir.x, _, stopDir.z = localToWorld( turnInfo.targetNode, 0, 0, 0 )
	courseplay:generateTurnCircle( vehicle, centerForward, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true);

	-- drive straight back to the targetNode
	wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	fromPoint.x = wp.posX;
	fromPoint.z = wp.posZ;
	toPoint.x, _, toPoint.z = localToWorld( turnInfo.targetNode, 0, 0, 0 )
	--courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, false, true )

	vehicle.cp.turnTargets[#vehicle.cp.turnTargets].turnEnd = true;
	courseplay.destroyNode( turnStartNode )
	courseplay.destroyNode( tempReverseCircleCenterNode )
	courseplay.destroyNode( reverseCircleCenterNode )
	courseplay.destroyNode( forwardCircleCenterNode )
end;

------------------------------------------------------------------------
-- Drive past turnEnd, up to the edge of the field (or current headland), then 
-- reverse back straight, then forward on a curve, reaching the target
-- direction well past turnEnd
-- During this turn the vehicle does not leave the field (or the current headland)
------------------------------------------------------------------------
function courseplay.generateTurnTypeHeadlandCornerReverseStraightCombine(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay.debugVehicle( 14, vehicle, "(Turn) Using Headland Corner Reverse Turn" )
	cpPrintLine(14, 3);

	local fromPoint, toPoint = {}, {};
	local centerForward, startDir, stopDir = {}, {}, {}

	--
	-- create a helper node from turnTarget but this time rotated into the turnStart direction
	local tx, _, tz = localToWorld( turnInfo.targetNode, 0, 0, 0 )
	local turnStartNode = courseplay.createNode( "cpTurnStartNode", tx, tz, math.rad( turnInfo.startDirection ))

	-- get the center of the forward turning circle
	-- delta between turn start and turn end
	turnInfo.turnRadius = turnInfo.turnRadius * 1.1
	local deltaZC = turnInfo.turnRadius / math.abs( math.tan( turnInfo.deltaAngle / 2 ))
	centerForward.x,_,centerForward.z = localToWorld(turnStartNode, - turnInfo.direction * turnInfo.turnRadius, 0, -deltaZC )
	courseplay.debugVehicle( 14, vehicle,
		"(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightCombine(), fwdCircle( %.2f %.2f ), deltaAngle %.2f, deltaZC %.2f",
		centerForward.x, centerForward.z, math.deg( turnInfo.deltaAngle ), deltaZC )

	-- drive forward to the edge of the field
	fromPoint.x, _, fromPoint.z = localToWorld( turnInfo.directionNode, 0, 0, 0 )
	-- we want the work area of our implement reach the edge of the field. We are on a headland, the field edge
	-- is workwidth/2 from us, but our front marker must reach it.
	toPoint.x, _, toPoint.z = localToWorld( turnStartNode, 0, 0, vehicle.cp.courseWorkWidth / 2 - turnInfo.frontMarker + turnInfo.wpChangeDistance + 0.5 )
	courseplay.debugVehicle( 14, vehicle,
		"(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightCombine(), from ( %.2f %.2f ), to ( %.2f %.2f) workWidth: %.1f, frontMarker: %.1f",
		fromPoint.x, fromPoint.z, toPoint.x, toPoint.z, vehicle.cp.courseWorkWidth, turnInfo.frontMarker )
	courseplay:generateTurnStraightPoints( vehicle, fromPoint, toPoint, false )

	-- raise the implement before reversing 
	vehicle.cp.turnTargets[#vehicle.cp.turnTargets].raiseImplement = true

	-- now back up 
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	fromPoint.x = wp.posX;
	fromPoint.z = wp.posZ;
	toPoint.x, _, toPoint.z = localToWorld( turnStartNode, 0, 0, - deltaZC - turnInfo.frontMarker - 3 )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightCombine(), straight from ( %.2f %.2f ), to ( %.2f %.2f )"):format(
		nameNum(vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z ), 14);
	courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true);
	--
	-- lower the implement 
	vehicle.cp.turnTargets[#vehicle.cp.turnTargets].lowerImplement = true

	--- Generate turn circle (Forward)
	startDir.x,_,startDir.z = localToWorld( turnStartNode, 0, 0, -deltaZC )
	stopDir.x, _, stopDir.z = localToWorld( turnInfo.targetNode, 0, 0, deltaZC )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightCombine(), circle from ( %.2f %.2f ), to ( %.2f %.2f )"):format(
		nameNum(vehicle), startDir.x, startDir.z, stopDir.x, stopDir.z ), 14);
	courseplay:generateTurnCircle( vehicle, centerForward, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true);

	-- Append a short straight section to make sure we finish the turn before switching to 
	-- the next waypoint.
	toPoint.x, _, toPoint.z = localToWorld( turnInfo.targetNode, 0, 0, deltaZC + 2 )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightCombine(), straight from ( %.2f %.2f ), to ( %.2f %.2f )"):format(
		nameNum(vehicle), stopDir.x, stopDir.z, toPoint.x, toPoint.z ), 14);
	courseplay:generateTurnStraightPoints(vehicle, stopDir, toPoint, false, true );
	courseplay.destroyNode( turnStartNode )
end;

------------------------------------------------------------------------
-- Drive past turnEnd, up to implement width from the edge of the field (or current headland), raise implements, then
-- reverse back straight, then forward on a curve, then back up to the corner, lower implements there.
------------------------------------------------------------------------
function courseplay.generateTurnTypeHeadlandCornerReverseStraightTractor(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Headland Corner Reverse Turn for tractors", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local fromPoint, toPoint = {}, {}
	local centerForward = vehicle.cp.turnCorner:getArcCenter()
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), fwdCircle( %.2f %.2f ), deltaAngle %.2f"):format(
		nameNum(vehicle), centerForward.x, centerForward.z, math.deg( turnInfo.deltaAngle )), 14);

	-- drive forward until our implement reaches the headland after the turn
	fromPoint.x, _, fromPoint.z = localToWorld( turnInfo.directionNode, 0, 0, 0 )
	-- drive forward only until our implement reaches the headland area after the turn so we leave an unworked area here at the corner
	toPoint = vehicle.cp.turnCorner:getPointAtDistanceFromCornerStart((vehicle.cp.workWidth / 2) + turnInfo.frontMarker - turnInfo.wpChangeDistance)
	-- is this now in front of us? We may not need to drive forward
	local _, _, dz = worldToLocal( turnInfo.directionNode, toPoint.x, toPoint.y, toPoint.z )
	-- at which waypoint we have to raise the implement
	local raiseImplementIndex
	if dz > 0 then
		courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), now driving forward so implement reaches headland"):format( nameNum( vehicle )), 14 )
		courseplay:generateTurnStraightPoints( vehicle, fromPoint, toPoint, false )
		raiseImplementIndex = #vehicle.cp.turnTargets
	else
		-- first waypoint is backing up already so raise it right there
		raiseImplementIndex = 1
	end
	-- in reverse our reference point is the implement's turn node so put the first reverse waypoint behind us
	fromPoint.x, _, fromPoint.z = localToWorld( turnInfo.directionNode, 0, 0, - turnInfo.directionNodeToTurnNodeLength )

	-- allow for a little buffer so we can straighten out the implement
	local buffer = turnInfo.directionNodeToTurnNodeLength * 0.8

	-- now back up so the tractor is at the start of the arc
	toPoint = vehicle.cp.turnCorner:getPointAtDistanceFromArcStart(turnInfo.directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance + buffer)
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f) workWidth: %.1f, raise implement ix: %d"):format(
		nameNum(vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z, vehicle.cp.workWidth, raiseImplementIndex ), 14)
	courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true);
	-- raise the implement before reversing 
	vehicle.cp.turnTargets[ raiseImplementIndex ].raiseImplement = true

	-- Generate turn circle (Forward)
	local startDir = vehicle.cp.turnCorner:getArcStart()
	local stopDir = vehicle.cp.turnCorner:getArcEnd()
	courseplay:generateTurnCircle( vehicle, centerForward, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true);

	-- Drive forward until our implement reaches the circle end and a bit more so it is hopefully aligned with the tractor
	-- and we can start reversing more or less straight.
	fromPoint = vehicle.cp.turnCorner:getPointAtDistanceFromArcEnd((turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + buffer) * 0.2)
	toPoint = vehicle.cp.turnCorner:getPointAtDistanceFromArcEnd(turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + buffer)
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f)"):format(
		nameNum(vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z), 14);
	courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, false, false );

	-- now back up the implement to the edge of the field (or headland)
	fromPoint = vehicle.cp.turnCorner:getArcEnd()

	if turnInfo.reversingWorkTool and turnInfo.reversingWorkTool.cp.realTurningNode then
		-- with towed reversing tools the reference point is the tool, not the tractor so don't care about frontMarker and such
		toPoint = vehicle.cp.turnCorner:getPointAtDistanceFromCornerEnd(-(vehicle.cp.workWidth / 2) - turnInfo.reverseWPChangeDistance - 10)
	else
		toPoint = vehicle.cp.turnCorner:getPointAtDistanceFromCornerEnd(-(vehicle.cp.workWidth / 2) - turnInfo.frontMarker - turnInfo.reverseWPChangeDistance - 10)
	end

	courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, true, true, turnInfo.reverseWPChangeDistance);

	-- lower the implement 
	vehicle.cp.turnTargets[#vehicle.cp.turnTargets].lowerImplement = true

	--- Finish the turn
	toPoint = vehicle.cp.turnCorner:getPointAtDistanceFromArcEnd(3)
	-- add just one target well forward, making sure it is in front of the tractor
	--courseplay:addTurnTarget(vehicle, toPoint.x, toPoint.z, true, false)
end

function courseplay:getTurnCircleTangentIntersectionPoints(cp, np, radius, leftTurn)
	local point = createTransformGroup("cpTempTurnCircleTangentIntersectionPoint");
	link(g_currentMission.terrainRootNode, point);

	-- Rotate it in the right direction
	local dx, dz = courseplay:getPointDirection(cp, np, false);
	local yRot = MathUtil.getYRotationFromDirection(dx, dz);
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

-- TODO: move this logic into the course
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

function courseplay:generateTurnStraightPoints(vehicle, fromPoint, toPoint, reverse, turnEnd, secondaryReverseDistance, changeDirectionWhenAligned, doNotAddLastPoint)
	local endTurn = false;
	local wpDistance = wpDistance;
	local dist = courseplay:distance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z);
	local numPointsNeeded = ceil(dist / wpDistance);
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist;

	if turnEnd == true then
		endTurn = turnEnd;
	end;

	-- add first point
	courseplay:addTurnTarget(vehicle, fromPoint.x, fromPoint.z, endTurn, reverse, nil, nil, nil, changeDirectionWhenAligned);

	-- add points between the first and last
	local posX, posZ;
	if numPointsNeeded > 1 then
		wpDistance = dist / numPointsNeeded;
		for i=1, numPointsNeeded - 1 do
			posX = fromPoint.x + (i * wpDistance * dx);
			posZ = fromPoint.z + (i * wpDistance * dz);

			courseplay:addTurnTarget(vehicle, posX, posZ, endTurn, reverse, nil, nil, nil, changeDirectionWhenAligned);
		end;
	end;

	if doNotAddLastPoint then return end

	-- add last point
	local revPosX, revPosZ;
	if reverse and secondaryReverseDistance then
		revPosX = toPoint.x + (secondaryReverseDistance * dx);
		revPosZ = toPoint.z + (secondaryReverseDistance * dz);
	end;

	posX = toPoint.x;
	posZ = toPoint.z;

	courseplay:addTurnTarget(vehicle, posX, posZ, endTurn, reverse, revPosX, revPosZ, nil, changeDirectionWhenAligned);

end;

-- startDir and stopDir are points (x,z). The arc starts where the line from the center of the circle
-- to startDir intersects the circle and ends where the line from the center of the circle to stopDir
-- intersects the circle.
--
function courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, radius, clockwise, addEndPoint, reverse)
	-- Convert clockwise to the right format
	if clockwise == nil then clockwise = 1 end;
	if clockwise == false or clockwise < 0 then
		clockwise = -1;
	else
		clockwise = 1;
	end;

	-- Define some basic values to use
	local numWP 		= 1;
	local degreeToTurn	= 0;
	local wpDistance	= 1;
	local degreeStep	= 360 / (2 * radius * math.pi) * wpDistance;
	local startRot		= 0;
	local endRot		= 0;

	-- Get the start and end rotation
	local dx, dz = courseplay:getPointDirection(center, startDir, false);
	startRot = deg(MathUtil.getYRotationFromDirection(dx, dz));
	dx, dz = courseplay:getPointDirection(center, stopDir, false);
	endRot = deg(MathUtil.getYRotationFromDirection(dx, dz));

	-- Create new transformGroupe to use for placing waypoints
	local point = createTransformGroup("cpTempGenerateTurnCircle");
	link(g_currentMission.terrainRootNode, point);

	-- Move the point to the center
	local cY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, center.x, 300, center.z);
	setTranslation(point, center.x, cY, center.z);

	-- Rotate it to the start direction
	setRotation(point, 0, rad(startRot), 0);

	-- Fix the rotation values in some special cases
	if clockwise == 1 then
		--(Turn:generateTurnCircle) startRot=90, endRot=-29, degreeStep=20, degreeToTurn=240, clockwise=1
		if startRot > endRot then
			degreeToTurn = endRot + 360 - startRot;
		else
			degreeToTurn = endRot - startRot;
		end;
	else
		--(Turn:generateTurnCircle) startRot=150, endRot=90, degreeStep=-20, degreeToTurn=60, clockwise=-1
		if startRot < endRot then
			degreeToTurn = startRot + 360 - endRot;
		else
			degreeToTurn = startRot - endRot;
		end;
	end;
	courseplay:debug(string.format("%s:(Turn:generateTurnCircle) startRot=%d, endRot=%d, degreeStep=%d, degreeToTurn=%d, clockwise=%d", nameNum(vehicle), startRot, endRot, (degreeStep * clockwise), degreeToTurn, clockwise), 14);

	-- Get the number of waypoints
	numWP = ceil(degreeToTurn / degreeStep);
	-- Recalculate degreeStep
	degreeStep = (degreeToTurn / numWP) * clockwise;
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
		courseplay:addTurnTarget(vehicle, posX, posZ, nil, reverse, nil, nil, true);

		local _,rot,_ = getRotation(point);
		courseplay:debug(string.format("%s:(Turn:generateTurnCircle) waypoint %d curentRotation=%d", nameNum(vehicle), i, deg(rot)), 14);
	end;

	-- Clean up the created node.
	unlink(point);
	delete(point);
end;

function courseplay:addTurnTarget(vehicle, posX, posZ, turnEnd, turnReverse, revPosX, revPosZ, dontPrint, changeDirectionWhenAligned)
	local target = {};
	target.posX 			  = posX;
	target.posZ 			  = posZ;
	target.turnEnd			  = turnEnd;
	target.turnReverse		  = turnReverse;
	target.revPosX 			  = revPosX;
	target.revPosZ 			  = revPosZ;
	target.changeDirectionWhenAligned = changeDirectionWhenAligned;
	table.insert(vehicle.cp.turnTargets, target);

	if not dontPrint then
		courseplay:debug(("%s:(Turn:addTurnTarget %d) posX=%.2f, posZ=%.2f, turnEnd=%s, turnReverse=%s, changeDirectionWhenAligned=%s"):format(nameNum(vehicle), #vehicle.cp.turnTargets, posX, posZ, tostring(turnEnd and true or false), tostring(turnReverse and true or false), tostring(changeDirectionWhenAligned and true or false)), 14);
	end;
end

function courseplay:clearTurnTargets(vehicle)
	vehicle.cp.turnStage = 0;
	vehicle.cp.turnTargets = {};
	vehicle.cp.curTurnIndex = 1;
	vehicle.cp.haveCheckedMarkersThisTurn = false;
	vehicle.cp.headlandTurn = nil

	if vehicle.cp.turnCorner then
		vehicle.cp.turnCorner:delete()
		vehicle.cp.turnCorner = nil
	end
end

-- @return true if all implements which have been started lowering are still moving, false if they are in their
-- final position or have not been started lowering
function courseplay:needToWaitForTools(vehicle)
	local wait = false
	for _,workTool in pairs(vehicle.cp.workTools) do
		-- the stock Giants getIsLowered() returns true from the moment the tool starts lowering
		if workTool.getIsLowered and workTool:getIsLowered() then
			-- started lowering, is it now really lowered? if not, must wait
			wait = not workTool:getCanAIImplementContinueWork() or wait
		end
	end
	return wait
end

function courseplay.createNode( name, x, z, yRotation, rootNode )
	local node = createTransformGroup( name )
	link( rootNode or g_currentMission.terrainRootNode, node )
	-- y is zero when we link to an existing node
	local y = rootNode and 0 or getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z);
	setTranslation( node, x, y, z );
	setRotation( node, 0, yRotation, 0);
	return node
end

function courseplay.createNodeFromNode( name, otherNode )
	local x, y, z = getWorldTranslation(otherNode)
	local _, yRot, _ = getRotation(otherNode)
	return courseplay.createNode(name, x, z, yRot, otherNode)
end

function courseplay.destroyNode( node )
	if node and entityExists(node) then
		unlink( node )
		delete( node )
	end
end

--[[
The vehicle at vehiclePos moving into the direction of WP waypoint. 
The direction it should be when reaching the waypoint is wpAngle. 
We need to determine a T1 target where the vehicle can drive to and actually reach WP in wpAngle direction.
Then we add waypoints on a circle from T1 to WP.
see https://ggbm.at/RN3cawGc
--]]

function courseplay:getAlignWpsToTargetWaypoint( vehicle, vx, vz, tx, tz, tDirection, generateStraightWaypoints )
	vehicle.cp.turnTargets = {}
	-- make the radius a bit bigger to make sure we can make the turn
	local turnRadius = 1.1 * vehicle.cp.turnDiameter / 2
	-- target waypoint we want to reach
	local wpNode = courseplay.createNode( "wpNode", tx, tz, tDirection )
	-- which side of the target node are we?
	local vy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, vx, 0, vz)
	local dx, _, _ = worldToLocal( wpNode, vx, vy, vz )
	-- right -1, left +1
	local leftOrRight = dx < 0 and -1 or 1
	-- center of turn circle. Also, move it back a meter so the alignment course ends up 
	-- a bit further back from the waypoint to prevent circling
	local c1x, _, c1z = localToWorld( wpNode, leftOrRight * turnRadius, 0, -1 )
	local vehicleToC1Distance = courseplay:distance( vx, vz, c1x, c1z )
	local vehicleToC1Direction = math.atan2(c1x - vx, c1z - vz )
	local angleBetweenTangentAndC1 = math.pi / 2 - math.asin( turnRadius / vehicleToC1Distance )
	-- check for NaN, may happen when we are closer than turnRadius
	if angleBetweenTangentAndC1 ~= angleBetweenTangentAndC1 then
		courseplay.debugVehicle(14, vehicle, "can't create alignment course, r=%.1f, c-v=%.1f", turnRadius, vehicleToC1Distance)
		courseplay.destroyNode( wpNode )
		return nil
	end
	local c1Node = courseplay.createNode( "c1Node", c1x, c1z, vehicleToC1Direction )
	local t1Node = courseplay.createNode( "t1Node", 0, 0, - leftOrRight * ( math.pi - angleBetweenTangentAndC1 ), c1Node )

	courseplay:debug(string.format("%s:(Align) vehicleToC1Distance = %.1f, vehicleToC1Direction = %.1f angleBetween = %.1f, wpAngle = %.1f, turnRadius = %.1f, %.1f",
		nameNum(vehicle), vehicleToC1Distance, math.deg( vehicleToC1Direction ), math.deg( angleBetweenTangentAndC1 ), math.deg( tDirection ),
		turnRadius, - leftOrRight * math.deg( math.pi - angleBetweenTangentAndC1 )), 14);

	local c1 = {}
	c1.x, _, c1.z = localToWorld( c1Node, 0, 0, 0 )
	local t1 = {}
	t1.x, _, t1.z = localToWorld( t1Node, 0, 0, turnRadius )
	local wp = { x = tx, z = tz }

	-- add waypoints to the straight section from the vehicle to T1 (the start of the arc)
	if generateStraightWaypoints then
		courseplay:generateTurnStraightPoints(vehicle, {x = vx, z = vz}, t1, false, false, false, false, true)
	end
	-- leverage Claus' nice turn generator
	courseplay:generateTurnCircle( vehicle, c1, t1, wp, turnRadius, leftOrRight, false, false )
	local result = vehicle.cp.turnTargets
	-- TODO: check if this is a dangerous (has a side effect on result?)
	vehicle.cp.turnTargets = {}

	courseplay.destroyNode( t1Node )
	courseplay.destroyNode( c1Node )
	courseplay.destroyNode( wpNode )
	return result
end

--- Helper class providing information about a turn maneuver corner.

---@class Corner
Corner = CpObject()

---@param vehicle table the vehicle
---@param startAngleDeg number the angle we are arriving at the turn start waypoint (not the angle of the turn start wp, the angle
---of the one before!)
---@param startWp Waypoint turn start waypoint
---@param endAngleDeg number direction we want to end the turn
---@param endWp Waypoint turn end waypoint
---@param turnRadius number radius to use in this turn
---@param offsetX number left/right offset of the course. The Corner uses the un-offset coordinates of the start/end
--- waypoints and the offsetX to move the corner point diagonally inward or outward if the course has a side offset
function Corner:init(vehicle, startAngleDeg, startWp, endAngleDeg, endWp, turnRadius, offsetX)
	self.debugChannel = 14
	self.vehicle = vehicle
	self.startWp = startWp
	self.endWp = endWp
	self.endAngleDeg = endAngleDeg
	self.offsetX = offsetX
	self.startNode = courseplay.createNode(tostring(self) .. '-cpTurnStartNode', self.startWp.x, self.startWp.z, math.rad(startAngleDeg))
	self.endNode = courseplay.createNode(tostring(self) .. '-cpTurnEndNode', self.endWp.x, self.endWp.z, math.rad(self.endAngleDeg))
	self.alpha, self.reverseStartAngle = Corner.getAngles(startAngleDeg, endAngleDeg)
	self.turnDirection = self.alpha > 0 and 1 or -1
	self:debug('start: %.1f end: %.1f alpha: %.1f dir: %d',
		startAngleDeg, self.endAngleDeg, math.deg(self.alpha), self.turnDirection)

	self:findCornerNodes(startAngleDeg)
	self:findCircle(turnRadius)
end

function Corner.getAngles(startAngleDeg, endAngleDeg)
	-- the startAngle reversed by 180
	local reverseStartAngle = startAngleDeg > 0 and startAngleDeg - 180 or startAngleDeg + 180
	-- this is the corner angle
	local alpha = getDeltaAngle(math.rad(endAngleDeg), math.rad(reverseStartAngle))
	return alpha, reverseStartAngle
end

function Corner:delete()
	courseplay.destroyNode(self.startNode)
	courseplay.destroyNode(self.endNode)
	courseplay.destroyNode(self.cornerStartNode)
	courseplay.destroyNode(self.cornerNode)
	courseplay.destroyNode(self.cornerEndNode)
end

--
--                              /
--                             /
--                   endNode  /
--                           x
--
--
--
--                      /
--                        alpha
--                    x  --         <-----x
--             cornerNode             startNode
--
function Corner:findCornerNodes(startAngle)
	-- As there's no guarantee that either of the start or end waypoints are in the corner,
	-- we first find the corner based on these turn start/end waypoints.
	-- The corner is at the intersection of the lines:
	-- line 1 through startWp at startAngle, and
	-- line 2 through endWp at endAngle

	-- So go ahead and find that point. First we need to make the lines long enough so they actually intersect
	-- must look far enough, start/end waypoints may be far away
	local extensionDistance = math.max(50, 1.5 * courseplay:distance(self.startWp.x, self.startWp.z, self.endWp.x, self.endWp.z))
	-- extend line 1 back and forth
	local l1x1, _, l1z1 = localToWorld(self.startNode, 0, 0, -extensionDistance)
	local l1x2, _, l1z2 = localToWorld(self.startNode, 0, 0, extensionDistance)
	local l2x1, _, l2z1 = localToWorld(self.endNode, 0, 0, -extensionDistance)
	local l2x2, _, l2z2 = localToWorld(self.endNode, 0, 0, extensionDistance)
	-- The Giants MathUtil line intersection function is undocumented so use what we have:
	local is = courseplay:segmentsIntersection(l1x1, l1z1, l1x2, l1z2, l2x1, l2z1, l2x2, l2z2)
	if is then
		-- points to the inside of the corner from the corner, half angle between start and end. The center of the arc
		-- making a nice turn in this corner is on this line
		self.cornerNode = courseplay.createNode(tostring(self) .. '-cpTurnHalfNode', is.x, is.z,
			getAverageAngle(math.rad(self.reverseStartAngle), math.rad(self.endAngleDeg)))
		self:debug('startAngle: %.1f, endAngle %.1f avg %.1f',
			self.reverseStartAngle, self.endAngleDeg, math.deg(getAverageAngle(math.rad(startAngle) + math.pi, math.rad(self.endAngleDeg))))
		-- move corner back according to the offset and turn direction it moves to the inside or outside
		local x, y, z = localToWorld(self.cornerNode, 0, 0, - self.offsetX / math.sin(self.alpha / 2))
		setTranslation(self.cornerNode, x, y, z)
		-- child nodes pointing towards the start and end waypoint. Every important location in the corner lies on these
		-- two lines, extending outwards from the corner.
		-- node at the corner, pointing back in the direction we were coming from to the turn start waypoint
		self.cornerStartNode = courseplay.createNode(tostring(self) .. '-cpCornerStartNode', 0, 0, self.alpha / 2, self.cornerNode)
		-- node at the corner, pointing in the direction we will be leaving the turn end waypoint
		self.cornerEndNode = courseplay.createNode(tostring(self) .. '-cpCornerEndNode', 0, 0, -self.alpha / 2, self.cornerNode)
		self:debug('corner: %.1f %.1f, startAngle: %.1f, endAngle %.1f',
			is.x, is.z, startAngle, self.endAngleDeg)
	else
		self:debug('Could not find turn corner, using turn end waypoint')
		self.cornerNode = self.endNode
		self.cornerStartNode = self.startNode
		self.cornerEndNode = self.startNode
	end
end

-- Circle (arc) between the start and end lines
function Corner:findCircle(turnRadius)
	-- tangent points on the arc
	local r = turnRadius * 1.0
	-- distance between the corner and the tangent points
	self.dCornerToTangentPoints = math.abs(r / math.tan(self.alpha / 2))
	self.dCornerToCircleCenter = math.abs(self.dCornerToTangentPoints / math.cos(self.alpha / 2))
	self:debug('r=%.1f d=%.1f', r, self.dCornerToTangentPoints)
	self.arcStart, self.arcEnd, self.center = {}, {}, {}
	self.arcStart.x, _, self.arcStart.z = localToWorld(self.cornerStartNode, 0, 0, self.dCornerToTangentPoints)
	self.arcEnd.x, _, self.arcEnd.z = localToWorld(self.cornerEndNode, 0, 0, self.dCornerToTangentPoints)
	self.center.x, _, self.center.z = localToWorld(self.cornerNode, 0, 0, self.dCornerToCircleCenter)
	self:debug('arc start: %.1f %.1f, arc end: %.1f %.1f, arc center: %.1f %.1f ',
		self.arcStart.x, self.arcStart.z, self.arcEnd.x, self.arcEnd.z, self.center.x, self.center.z)
end

function Corner:getCornerStartNode()
	return self.cornerStartNode
end

--- Point in distance from the corner in the turn start direction. Positive number until the corner is reached
function Corner:getPointAtDistanceFromCornerStart(d, sideOffset)
	local x, y, z = localToWorld(self.cornerStartNode, sideOffset and sideOffset * self.turnDirection or 0, 0, d)
	return {x = x, y = y, z = z}
end

--- Point in distance from the point on the start leg where the arc begins. Positive until we reach the arc
function Corner:getPointAtDistanceFromArcStart(d)
	local x, y, z = localToWorld(self.cornerStartNode, 0, 0, self.dCornerToTangentPoints + d)
	return {x = x, y = y, z = z}
end

function Corner:getPointAtDistanceFromCornerEnd(d, sideOffset)
	local x, y, z = localToWorld(self.cornerEndNode, sideOffset and sideOffset * self.turnDirection or 0, 0, d)
	return {x = x, y = y, z = z}
end

function Corner:getPointAtDistanceFromArcEnd(d)
	local x, y, z = localToWorld(self.cornerEndNode, 0, 0, d + self.dCornerToTangentPoints)
	return {x = x, y = y, z = z}
end

function Corner:getCornerEndNode()
	return self.cornerEndNode
end

function Corner:getArcStart()
	return self.arcStart
end

function Corner:getArcEnd()
	return self.arcEnd
end

function Corner:getArcCenter()
	return self.center
end

function Corner:getEndAngleDeg()
	return self.endAngleDeg
end

function Corner:debug(...)
	courseplay.debugVehicle(self.debugChannel, self.vehicle, ...)
end

function Corner:drawDebug()
	if courseplay.debugChannels[self.debugChannel] then
		local cx, cy, cz
		local nx, ny, nz
		if self.cornerNode then
			cx, cy, cz = localToWorld(self.cornerNode, 0, 0, 0)
			nx, ny, nz = localToWorld(self.cornerNode, 0, 0, 3)
			cpDebug:drawPoint(cx, cy + 6, cz, 0, 0, 70)
			cpDebug:drawLine(cx, cy + 6, cz, 0, 0, 30, nx, ny + 6, nz)
			nx, ny, nz = localToWorld(self.cornerStartNode, 0, 0, 3)
			cpDebug:drawLine(cx, cy + 6, cz, 0, 30, 0, nx, ny + 6, nz)
			nx, ny, nz = localToWorld(self.cornerEndNode, 0, 0, 3)
			cpDebug:drawLine(cx, cy + 6, cz, 30, 0, 0, nx, ny + 6, nz)
		end
	end
end

---@class TurnContext
---@field turnStartWp Waypoint
---@field beforeTurnStartWp Waypoint
---@field turnEndWp Waypoint
---@field afterTurnEndWp Waypoint
TurnContext = CpObject()

--- All data needed to create a turn
-- TODO: this uses a bit too many course internal info, should maybe moved into Course?
-- TODO: could this be done a lot easier with child nodes sitting on a single corner node?
---@param course Course
---@param turnStartIx number
---@param aiDriverData table to store the turn start/end waypoint nodes (which are created if nil passed in)
--- we store the nodes some global, long lived table to avoid creating new nodes every time a TurnContext object
--- is created
---@param workWidth number working width
---@param frontMarkerDistance number distance of the frontmost work area from the vehicle's root node (positive is
--- in front of the vehicle. We'll add a node (vehicleAtTurnEndNode) offset by frontMarkerDistance from the turn end
--- node so when the vehicle's root node reaches the vehicleAtTurnEndNode, the front of the work area will exactly be on the
--- turn end node. (The vehicle must be steered to the vehicleAtTurnEndNode instead of the turn end node so the implements
--- reach exactly the row end)
---@param turnEndSideOffset number offset of the turn end in meters to left (>0) or right (<0) to end the turn left or
--- right of the turn end node. Used when there's an offset to consider, for example because the implement is not
--- in the middle, like plows.
function TurnContext:init(course, turnStartIx, aiDriverData, workWidth, frontMarkerDistance, turnEndSideOffset)
	self.debugChannel = 14
	self.workWidth = workWidth

	--- Setting up turn waypoints
	---
	---@type Waypoint
	self.beforeTurnStartWp = course.waypoints[turnStartIx - 1]
	---@type Waypoint
	self.turnStartWp = course.waypoints[turnStartIx]
	self.turnStartWpIx = turnStartIx
	---@type Waypoint
	self.turnEndWp = course.waypoints[turnStartIx + 1]
	self.turnEndWpIx = turnStartIx + 1
	---@type Waypoint
	self.afterTurnEndWp = course.waypoints[math.min(course:getNumberOfWaypoints(), turnStartIx + 2)]
	self.directionChangeDeg = math.deg( getDeltaAngle( math.rad(self.turnEndWp.angle), math.rad(self.beforeTurnStartWp.angle)))

	self:setupTurnStart(course, aiDriverData)

	-- this is the node the vehicle's root node must be at so the front of the work area is exactly at the turn start
	self.frontMarkerDistance = frontMarkerDistance or 0
	if not aiDriverData.vehicleAtTurnStartNode then
		aiDriverData.vehicleAtTurnStartNode = courseplay.createNode( 'vehicleAtTurnStart', 0, - self.frontMarkerDistance, 0, self.workEndNode )
	end
	setTranslation(aiDriverData.vehicleAtTurnStartNode, 0, 0, - self.frontMarkerDistance)

	self.vehicleAtTurnStartNode = aiDriverData.vehicleAtTurnStartNode

	self:setupTurnEnd(course, aiDriverData, turnEndSideOffset)

	-- this is the node the vehicle's root node must be at so the front of the work area is exactly at the turn end
	self.frontMarkerDistance = frontMarkerDistance or 0
	if not aiDriverData.vehicleAtTurnEndNode then
		aiDriverData.vehicleAtTurnEndNode = courseplay.createNode( 'vehicleAtTurnEnd', 0, - self.frontMarkerDistance, 0, self.turnEndWpNode.node )
	end
	setTranslation(aiDriverData.vehicleAtTurnEndNode, 0, 0, - self.frontMarkerDistance)
	self.vehicleAtTurnEndNode = aiDriverData.vehicleAtTurnEndNode

	self.dx, _, self.dz = localToLocal(self.turnEndWpNode.node, self.workEndNode, 0, 0, 0)
	self.leftTurn = self.dx > 0
	self:debug('start ix = %d', turnStartIx)
end

function TurnContext:debug(...)
	courseplay.debugFormat(self.debugChannel, 'Turn context: ' .. string.format(...))
end

--- Get overshoot for a headland corner (how far further we need to drive if the corner isn't 90 degrees 
--- for full coverage
function TurnContext:getOvershootForHeadlandCorner()
	local headlandAngle = math.rad(math.abs(math.abs(self.directionChangeDeg) - 90))
	local overshoot = self.workWidth / 2 * math.tan(headlandAngle)
	self:debug('work start node headland angle = %.1f, overshoot = %.1f', math.deg(headlandAngle), overshoot)
	return overshoot
end

--- Set up the turn end node and all related nodes (relative to the turn end node)
function TurnContext:setupTurnEnd(course, aiDriverData, turnEndSideOffset)
	-- making sure we have the nodes created, and created only once
	if not aiDriverData.turnEndWpNode then
		aiDriverData.turnEndWpNode = WaypointNode('turnEnd')
	end
	-- Turn end waypoint node, pointing to the direction after the turn
	aiDriverData.turnEndWpNode:setToWaypoint(course, self.turnEndWpIx)
	self.turnEndWpNode = aiDriverData.turnEndWpNode

	-- if there's an offset move the turn end node (and all others based on it)
	if turnEndSideOffset and turnEndSideOffset ~= 0 then
		self:debug('Applying %.1f side offset to turn end', turnEndSideOffset)
		local x, y, z = localToWorld(self.turnEndWpNode.node, turnEndSideOffset, 0, 0)
		setTranslation(self.turnEndWpNode.node, x, y, z)
	end

	-- Set up a node where the implement must be lowered when starting to work after the turn maneuver
	if not aiDriverData.workStartNode then
		aiDriverData.workStartNode = courseplay.createNode('workStart', 0, 0, 0, aiDriverData.turnEndWpNode.node)
	end
	if not aiDriverData.lateWorkStartNode then
		-- this is for the headland turns where we want to cover the corner in the inbound direction (before turning)
		-- so we can start working later after the turn
		aiDriverData.lateWorkStartNode = courseplay.createNode('lateWorkStartNode', 0, 0, 0, aiDriverData.workStartNode)
	end

	if self:isHeadlandCorner() then
		local overshoot = math.min(self:getOvershootForHeadlandCorner(), self.workWidth * 2)
		-- for headland turns, when we cover the corner in the outbound direction, which is half self.workWidth behind
		-- the turn end node
		setTranslation(aiDriverData.workStartNode, 0, 0, - self.workWidth / 2 - overshoot)
		setTranslation(aiDriverData.lateWorkStartNode, 0, 0, self.workWidth)
	end
	self.workStartNode = aiDriverData.workStartNode
	self.lateWorkStartNode = aiDriverData.lateWorkStartNode
end

--- Set up the turn end node and all related nodes (relative to the turn end node)
function TurnContext:setupTurnStart(course, aiDriverData)
	if not aiDriverData.turnStartWpNode then
		aiDriverData.turnStartWpNode = WaypointNode('turnStart')
	end
	-- Turn start waypoint node, pointing to the direction of the turn end node
	aiDriverData.turnStartWpNode:setToWaypoint(course, self.turnStartWpIx)
	self.turnStartWpNode = aiDriverData.turnStartWpNode

	-- Set up a node where the implement must be raised when finishing a row before the turn
	if not aiDriverData.workEndNode then
		aiDriverData.workEndNode = courseplay.createNode('workEnd', 0, 0, 0)
	end
	if not aiDriverData.lateWorkEndNode then
		-- this is for the headland turns where we want to cover the corner in the inbound direction (before turning)
		aiDriverData.lateWorkEndNode = courseplay.createNode('lateWorkEnd', 0, 0, 0, aiDriverData.workEndNode)
	end
	if self:isHeadlandCorner() then
		-- for headland turns (about 45-135 degrees) the turn end node is on the corner but pointing to
		-- the direction after the turn. So create a node at the same location but pointing into the incoming direction
		-- to be used to find out when to raise the implements during a headland turn
		course:setNodeToWaypoint(aiDriverData.workEndNode, self.turnEndWpIx)
		-- use the rotation and offset of the waypoint before the turn start to make sure that we continue straight
		-- until the implements are raised
		setRotation(aiDriverData.workEndNode, 0, course:getWaypointYRotation(self.turnStartWpIx - 1), 0)
		local x, y, z = course:getOffsetPositionWithOtherWaypointDirection(self.turnEndWpIx, self.turnStartWpIx)
		setTranslation(aiDriverData.workEndNode, x, y, z)
		local overshoot = math.min(self:getOvershootForHeadlandCorner(), self.workWidth * 2)
		-- for headland turns, we cover the corner in the outbound direction, so here we can end work when 
		-- the implement is half self.workWidth before the turn end node
		x, y, z = localToWorld(aiDriverData.workEndNode, 0, 0, - self.workWidth / 2 + overshoot)
		setTranslation(aiDriverData.workEndNode, x, y, z)
		setTranslation(aiDriverData.lateWorkEndNode, 0, 0, self.workWidth)
	else
		-- For 180 turns, create a node pointing in the incoming direction of the turn start waypoint. This will be used
		-- to determine relative position to the turn start. (the turn start WP can't be used as it is
		-- pointing towards the turn end waypoint which may be anything around 90 degrees)
		-- there's no need for an overshoot as it is being taken care during the course generation
		course:setNodeToWaypoint(aiDriverData.workEndNode, self.turnStartWpIx)
		setRotation(aiDriverData.workEndNode, 0, course:getWaypointYRotation(self.turnStartWpIx - 1), 0)
		setTranslation(aiDriverData.lateWorkEndNode, 0, 0, 0)
	end

	self.workEndNode = aiDriverData.workEndNode
	self.lateWorkEndNode = aiDriverData.lateWorkEndNode
end

-- node's position in the turn end wp node's coordinate system
function TurnContext:getLocalPositionFromTurnEnd(node)
	return localToLocal(node, self.vehicleAtTurnEndNode, 0, 0, 0)
end

-- node's position in the turn start wp node's coordinate system
function TurnContext:getLocalPositionFromTurnStart(node)
	return localToLocal(node, self.turnStartWpNode.node, 0, 0, 0)
end

-- node's position in the work end node's coordinate system
function TurnContext:getLocalPositionFromWorkEnd(node)
	return localToLocal(node, self.workEndNode, 0, 0, 0)
end

-- turn end wp node's position in node's coordinate system
function TurnContext:getLocalPositionOfTurnEnd(node)
	return localToLocal(self.vehicleAtTurnEndNode, node, 0, 0, 0)
end

function TurnContext:isPointingToTurnEnd(node, thresholdDeg)
	local lx, _, lz = localToLocal(self.turnEndWpNode.node, node, 0, 0, 0)
	return math.abs(math.atan2(lx, lz)) < math.rad(thresholdDeg)
end

function TurnContext:isHeadlandCorner()
	-- TODO: there should be a better way to find this out
	return math.abs( self.directionChangeDeg ) < laneTurnAngleThreshold
end

function TurnContext:isPathfinderTurn(turnDiameter)
	local d = math.sqrt(self.dx * self.dx + self.dz * self.dz)
	return not self:isHeadlandCorner() and (math.abs(self.dx) > turnDiameter or d > 2 * turnDiameter)
end

--- A simple wide turn is where there's no corner to avoid, no headland to follow, there is a straight line on the
--- field between the turn start and end
--- Currently we don't have a really good way to find this out so assume that if the turn end is reasonably close
--- to the turn start, there'll be nothing in our way.
function TurnContext:isSimpleWideTurn(turnDiameter)
	return not self:isHeadlandCorner() and math.abs(self.dx) > turnDiameter and math.abs(self.dx) < turnDiameter * 1.5 and math.abs(self.dz) < turnDiameter
end

function TurnContext:isWideTurn(turnDiameter)
	return not self:isHeadlandCorner() and math.abs(self.dx) > turnDiameter
end

function TurnContext:isLeftTurn()
	if self:isHeadlandCorner() then
		local cornerAngle = self:getCornerAngle()
		return cornerAngle > 0
	else
		return self.leftTurn
	end
end

function TurnContext:setTargetNode(node)
	self.targetNode = node
end

-- TODO: this should be a global util function, not under TurnContext
function TurnContext:getNodeDirection(node)
	local lx, _, lz = localDirectionToWorld(node, 0, 0, 1)
	return math.atan2( lx, lz )
end

--- Returns true if node1 is pointing approximately in node2's direction
---@param thresholdDeg number defines what 'approximately' means, by default if the difference is less than 10 degrees
function TurnContext.isSameDirection(node1, node2, thresholdDeg)
	local lx, _, lz = localDirectionToLocal(node1, node2, 0, 0, 1)
	return math.abs(math.atan2(lx, lz)) < math.rad(thresholdDeg or 5)
end

--- Returns true if node is pointing approximately in the turn start direction, that is, the direction from
--- turn start waypoint to the turn end waypoint.
function TurnContext:isDirectionCloseToStartDirection(node, thresholdDeg)
	return TurnContext.isSameDirection(node, self.turnStartWpNode.node, thresholdDeg)
end

--- Returns true if node is pointing approximately in the turn's ending direction, that is, the direction of the turn
--- end waypoint, the direction the vehicle will continue after the turn
function TurnContext:isDirectionCloseToEndDirection(node, thresholdDeg)
	return TurnContext.isSameDirection(node, self.turnEndWpNode.node, thresholdDeg)
end

--- Use to find out if we can make a turn: are we farther away from the next row than our turn radius
--- @param dx number lateral distance from the next row (dx from turn end node)
--- @return boolean True if dx is bigger than r, considering the turn's direction
function TurnContext:isLateralDistanceGreater(dx, r)
	if self:isLeftTurn() then
		-- more than r meters to the left
		return dx > r
	else
		-- more than r meters to the right
		return dx < -r
	end
end

function TurnContext:isLateralDistanceLess(dx, r)
	if self:isLeftTurn() then
		-- less than r meters to the left
		return dx < r
	else
		-- less than r meters to the right
		return dx > -r
	end
end

function TurnContext:getAngleToTurnEndDirection(node)
	local lx, _, lz = localDirectionToLocal(self.turnEndWpNode.node, node, 0, 0, 1)
	-- TODO: check for nan?
	return math.atan2(lx, lz)
end

function TurnContext:isDirectionPerpendicularToTurnEndDirection(node, thresholdDeg)
	local lx, _, lz = localDirectionToLocal(self.turnEndWpNode.node, node, self:isLeftTurn() and -1 or 1, 0, 0)
	return math.abs(math.atan2(lx, lz)) < math.rad(thresholdDeg or 5)
end

--- An angle of 0 means the headland is perpendicular to the up/down rows
function TurnContext:getHeadlandAngle()
	local lx, _, lz = localDirectionToLocal(self.turnEndWpNode.node, self.turnStartWpNode.node, self:isLeftTurn() and -1 or 1, 0, 0)
	return math.abs(math.atan2(lx, lz))
end


function TurnContext:getAverageEndAngleDeg()
	-- use the average angle of the turn end and the next wp as there is often a bend there
	return math.deg(getAverageAngle(math.rad(self.turnEndWp.angle), math.rad(self.afterTurnEndWp.angle)))
end

--- @return number the angle to turn in this corner (if the corner is less than 90 degrees, you'll have to turn > 90 degrees)
function TurnContext:getCornerAngle()
	local endAngleDeg = self:getAverageEndAngleDeg()
	local alpha, _ = Corner.getAngles(self.turnStartWp.angle, endAngleDeg)
	return alpha
end

--- @return number the angle to turn in this corner (if the corner is less than 90 degrees, you'll have to turn > 90 degrees)
function TurnContext:getCornerAngleToTurn()
	local endAngleDeg = self:getAverageEndAngleDeg()
	return getDeltaAngle(math.rad(endAngleDeg), math.rad(self.turnStartWp.angle))
end

--- Create a corner based on the turn context's start and end waypoints
---@param vehicle table
---@param r number turning radius in m
---@param sideOffset number (left < 0, right > 0) side offset to use when the course has an offset, for example
--- due to a tool setting. When not supplied the tool offset X set for the vehicle is used
function TurnContext:createCorner(vehicle, r, sideOffset)
	-- use the average angle of the turn end and the next wp as there is often a bend there
	local endAngleDeg = self:getAverageEndAngleDeg()
	courseplay.debugVehicle(14, vehicle, 'start angle: %.1f, end angle: %.1f (from %.1f and %.1f)', self.beforeTurnStartWp.angle,
		endAngleDeg, self.turnEndWp.angle, self.afterTurnEndWp.angle)
	return Corner(vehicle, self.beforeTurnStartWp.angle, self.turnStartWp, endAngleDeg, self.turnEndWp, r, sideOffset or vehicle.cp.toolOffsetX)
end

--- Create a turn ending course using the vehicle's current position and the front marker node (where the vehicle must
--- be in the moment it starts on the next row. Use the Corner class to generate a nice arc.
-- TODO: use Dubins instead?
---@param vehicle table
---@param corner Corner if caller already has a corner to use, can pass in here. If nil, we will create our own
---@return Course
function TurnContext:createEndingTurnCourse(vehicle, corner)
	local startAngle = math.deg(self:getNodeDirection(AIDriverUtil.getDirectionNode(vehicle)))
	local r = vehicle.cp.turnDiameter / 2
	local startPos, endPos = {}, {}
	startPos.x, _, startPos.z = getWorldTranslation(AIDriverUtil.getDirectionNode(vehicle))
	endPos.x, _, endPos.z = getWorldTranslation(self.vehicleAtTurnEndNode)
	-- use side offset 0 as all the offsets is already included in the vehicleAtTurnEndNode
	local myCorner = corner or Corner(vehicle, startAngle, startPos, self.turnEndWp.angle, endPos	, r, 0)
	courseplay:clearTurnTargets(vehicle)
	local center = myCorner:getArcCenter()
	local startArc = myCorner:getArcStart()
	local endArc = myCorner:getArcEnd()
	courseplay:generateTurnCircle(vehicle, center, startArc, endArc, r, self:isLeftTurn() and 1 or -1, false);
	-- make sure course reaches the front marker node so end it well behind that node
	local endStraight = {}
	endStraight.x, _, endStraight.z = localToWorld(self.vehicleAtTurnEndNode, 0, 0, 3)
	courseplay:generateTurnStraightPoints(vehicle, endArc, endStraight)
	local course = Course(vehicle, vehicle.cp.turnTargets, true)
	-- if we created our corner, delete it now.
	if not corner then myCorner:delete() end
	courseplay:clearTurnTargets(vehicle)
	return course
end

--- Course to reverse before starting a turn to make sure the turn is completely on the field
--- @param vehicle table
--- @param reverseDistance number distance to reverse in meters
function TurnContext:createReverseWaypointsBeforeStartingTurn(vehicle, reverseDistance)
	local reverserNode = AIDriverUtil.getReverserNode(vehicle)
	local _, _, dStart = localToLocal(reverserNode or AIDriverUtil.getDirectionNode(vehicle), self.workEndNode, 0, 0, 0)
	local waypoints = {}
	for d = dStart, dStart - reverseDistance - 1, -1 do
		local x, y, z = localToWorld(self.workEndNode, 0, 0, d)
		table.insert(waypoints, {x = x, y = y, z = z, rev = true})
	end
	return waypoints
end

--- Course to end a pathfinder turn, a straight line from where pathfinder ended, into to next row,
--- making sure it is long enough so the vehicle reaches the point to lower the implements on this course
---@param course Course pathfinding course to append the ending course to
function TurnContext:appendEndingTurnCourse(course)
	-- make sure course reaches the front marker node so end it well behind that node
	local _, _, dzFrontMarker = course:getWaypointLocalPosition(self.vehicleAtTurnEndNode, course:getNumberOfWaypoints())
	local _, _, dzWorkStart = course:getWaypointLocalPosition(self.workStartNode, course:getNumberOfWaypoints())
	local waypoints = {}
	-- A line between the front marker and the work start node, regardless of which one is first
	local startNode = dzFrontMarker < dzWorkStart and self.vehicleAtTurnEndNode or self.workStartNode
    -- +1 so the first waypoint of the appended line won't overlap with the last wp of course
	for d = math.min(dzFrontMarker, dzWorkStart) + 1, math.max(dzFrontMarker, dzWorkStart) + 3, 1 do
		local x, y, z = localToWorld(startNode, 0, 0, d)
		table.insert(waypoints, {x = x, y = y, z = z, turnEnd = true})
	end
	course:appendWaypoints(waypoints)
end


--- Course to finish a row before the turn, just straight ahead, ignoring the corner
---@return Course
function TurnContext:createFinishingRowCourse(vehicle)
	local waypoints = {}
	-- must be at least as long as the front marker distance so we are not reaching the end of the course before
	-- the implement reaches the field edge (a negative frontMarkerDistance means the implement is behind the
	-- vehicle, this isn't a problem for a positive frontMarkerDistance as the implement reaches the field edge
	-- before the vehicle (except for very wide work widths of course, so make sure we have enough course to cross
	-- the headland)
	-- TODO: fix this properly, maybe we should check the end course during turns instead
	for d = 0, math.max(self.workWidth * 1.5, -self.frontMarkerDistance * 6), 1 do
		local x, _, z = localToWorld(self.workEndNode, 0, 0, d)
		table.insert(waypoints, {x = x, z = z})
	end
	return Course(vehicle, waypoints, true)
end

--- How much space we have from node to the field edge (in the direction of the node)?
---@return number
function TurnContext:getDistanceToFieldEdge(node)
	for d = 0, 100, 1 do
		local x, _, z = localToWorld(node, 0, 0, d)
		local isField, area, totalArea = courseplay:isField(x, z, 1, 1)
		if d == 0 and not isField then
			self:debug('Field edge not found (vehicle not on field)')
			return nil
		end
		local fieldRatio = area / totalArea
		if not isField or fieldRatio < 0.5 then
			self:debug('Field edge is at %d m, ratio %.2f', d, fieldRatio)
			return d
		end
	end
	-- edge not found
	self:debug('Field edge more than 100 m away')
	return math.huge
end

--- Assuming a vehicle just finished a row, provide parameters for calculating a path to the start
--- of the next row, making sure that the vehicle and the implement arrives there aligned with the row direction
---@return number, number, number the node where the turn ends, z offset to use with the start node, z offset to use with the end node
function TurnContext:getTurnEndNodeAndOffsets()
	local turnEndNode, startOffset, goalOffset
	if self.frontMarkerDistance > 0 then
		-- implement in front of vehicle. Turn should end with the implement at the work start position, this is where
		-- the vehicle's root node is on the vehicleAtTurnEndNode
		turnEndNode = self.vehicleAtTurnEndNode
		startOffset = self.frontMarkerDistance
		goalOffset = 0
	else
		-- implement behind vehicle. Since we are turning, we want to be aligned with the next row with our vehicle
		-- on the work start node so by the time the implement reaches it, it is also aligned
		turnEndNode = self.workStartNode
		startOffset = 0
		goalOffset = self.frontMarkerDistance
	end
	return turnEndNode, startOffset, goalOffset
end

function TurnContext:debug(...)
	courseplay.debugFormat(self.debugChannel, 'TurnContext: ' .. string.format(...))
end

function TurnContext:drawDebug()
	if courseplay.debugChannels[self.debugChannel] then
		local cx, cy, cz
		local nx, ny, nz
		local height = 1
		if self.workStartNode then
			cx, cy, cz = localToWorld(self.workStartNode, -self.workWidth / 2, 0, 0)
			nx, ny, nz = localToWorld(self.workStartNode, self.workWidth / 2, 0, 0)
			cpDebug:drawLine(cx, cy + height, cz, 0, 1, 0, nx, ny + height, nz)
		end
		if self.lateWorkStartNode then
			cx, cy, cz = localToWorld(self.lateWorkStartNode, -self.workWidth / 2, 0, 0)
			nx, ny, nz = localToWorld(self.lateWorkStartNode, self.workWidth / 2, 0, 0)
			cpDebug:drawLine(cx, cy + height, cz, 0, 0.7, 0, nx, ny + height, nz)
		end
		if self.workEndNode then
			cx, cy, cz = localToWorld(self.workEndNode, -self.workWidth / 2, 0, 0)
			nx, ny, nz = localToWorld(self.workEndNode, self.workWidth / 2, 0, 0)
			cpDebug:drawLine(cx, cy + height, cz, 1, 0, 0, nx, ny + height, nz)
		end
		if self.lateWorkEndNode then
			cx, cy, cz = localToWorld(self.lateWorkEndNode, -self.workWidth / 2, 0, 0)
			nx, ny, nz = localToWorld(self.lateWorkEndNode, self.workWidth / 2, 0, 0)
			cpDebug:drawLine(cx, cy + height, cz, 0.7, 0, 0, nx, ny + height, nz)
		end
		if self.vehicleAtTurnEndNode then
			cx, cy, cz = localToWorld(self.vehicleAtTurnEndNode, 0, 0, 0)
			cpDebug:drawLine(cx, cy, cz, 1, 1, 0, cx, cy + 2, cz)
		end
	end
end

-- do not delete this line
-- vim: set noexpandtab:
