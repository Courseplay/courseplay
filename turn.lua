local abs, min, max, floor, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.deg;
local _; --- The _ is an discart character for values not needed. Setting it to local, prevent's it from being an global variable.

--- SET VALUES
local wpDistance		= 1.5;  -- Waypoint Distance in Strait lines
local wpCircleDistance	= 1; 	-- Waypoint Distance in circles
-- if the direction difference between turnStart and turnEnd is bigger than this then
-- we consider that as a turn when switching to the next up/down lane and assume that
-- after the turn we'll be heading into the opposite direction. 
local laneTurnAngleThreshold = 135 

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

	local realDirectionNode					= vehicle.isReverseDriving and vehicle.cp.reverseDrivingDirectionNode or vehicle.cp.DirectionNode;
	local allowedToDrive 					= true;
	local moveForwards 						= true;
	local refSpeed 							= vehicle.cp.speeds.turn;
	local directionForce 					= 1;
	local lx, lz 							= 0, 1;
	local dtpX, dtpZ						= 0, 1;
	local turnOutTimer 						= 1500;
	local turnTimer 						= 1500;
	local wpChangeDistance 					= 3;
	local reverseWPChangeDistance			= 5;
	local reverseWPChangeDistanceWithTool	= vehicle.isReverseDriving and 3 or 3;
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

	--- Make sure front and back markers is calculated.
	if not vehicle.cp.haveCheckedMarkersThisTurn then
		vehicle.cp.aiFrontMarker = nil;
		vehicle.cp.backMarkerOffset = nil;
		for _,workTool in pairs(vehicle.cp.workTools) do
			courseplay:setMarkers(vehicle, workTool);
		end;
		vehicle.cp.haveCheckedMarkersThisTurn = true;
		if vehicle.cp.courseWorkWidth and vehicle.cp.courseWorkWidth > 0 and vehicle.cp.courseNumHeadlandLanes and vehicle.cp.courseNumHeadlandLanes > 0 then
			-- First headland is only half the work width
			vehicle.cp.headlandHeight = vehicle.cp.courseWorkWidth / 2;
			-- Add extra workwidth for each extra headland
			if vehicle.cp.courseNumHeadlandLanes - 1 > 0 then
				vehicle.cp.headlandHeight = vehicle.cp.headlandHeight + ((vehicle.cp.courseNumHeadlandLanes - 1) * vehicle.cp.courseWorkWidth);
			end;
		else
			vehicle.cp.headlandHeight = 0;
		end; 
		local frontMarker2 = Utils.getNoNil(vehicle.cp.aiFrontMarker, -3);
		local backMarker2 = Utils.getNoNil(vehicle.cp.backMarkerOffset,0);
		if vehicle.cp.hasPlough and (vehicle.cp.ploughFieldEdge or math.abs(frontMarker2 - backMarker2) < vehicle.cp.headlandHeight) then
			vehicle.cp.aiFrontMarker = backMarker2;
			vehicle.cp.backMarkerOffset = frontMarker2
		end
	end;

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
	-- this is the distance between the tractor's directionNode and the real turning node of the implement (?)
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
			courseplay:clearTurnTargets(vehicle, false); -- Make sure we have cleaned it from any previus usage.

			--- Setting default turnInfo values
			local turnInfo = {};
			turnInfo.directionNode					= realDirectionNode
			turnInfo.frontMarker					= frontMarker;
			turnInfo.halfVehicleWidth 				= 2.5;
			turnInfo.directionNodeToTurnNodeLength  = directionNodeToTurnNodeLength + 0.5; -- 0.5 is to make the start turn point just a tiny in front of the tractor
			turnInfo.wpChangeDistance				= wpChangeDistance;
			turnInfo.reverseWPChangeDistance 		= reverseWPChangeDistance;
			turnInfo.direction 						= -1;
			turnInfo.haveHeadlands 					= courseplay:haveHeadlands(vehicle);
			turnInfo.headlandHeight 				= vehicle.cp.headlandHeight;
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
			
			turnInfo.directionChangeDeg, turnInfo.isHeadlandCorner = getDirectionChangeOfTurn( vehicle )
			-- headland turn data 
			vehicle.cp.headlandTurn = turnInfo.isHeadlandCorner and {} or nil 
			-- direction halfway between dir of turnStart and turnEnd 
			turnInfo.halfAngle = math.deg( getAverageAngle( math.rad( vehicle.Waypoints[vehicle.cp.waypointIndex + 1 ].angle ), 
				math.rad( vehicle.Waypoints[vehicle.cp.waypointIndex].angle )))
			-- delta between turn start and turn end
			turnInfo.deltaAngle = math.pi - ( math.rad( vehicle.Waypoints[vehicle.cp.waypointIndex + 1 ].angle )
				- math.rad( vehicle.Waypoints[vehicle.cp.waypointIndex].angle ))

			turnInfo.startDirection = vehicle.Waypoints[vehicle.cp.waypointIndex].angle

			--- Get the turn radius either by the automatic or user provided turn circle.
			local extRadius = 0.5 + (0.15 * directionNodeToTurnNodeLength); -- The extra calculation is for dynamic trailer length to prevent jackknifing;
			turnInfo.turnRadius = vehicle.cp.turnDiameter * 0.5 + extRadius;
			turnInfo.turnDiameter = turnInfo.turnRadius * 2;

			--- Get the new turn target with offset
			if courseplay:getIsVehicleOffsetValid(vehicle) and turnInfo.isHeadlandCorner == false then
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
				local totalOffsetZ
				if vehicle.cp.headlandTurn then
					-- headland turns are not near 180 degrees so just moving the target left/right won't work. 
					-- we must to move it back as well
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
				drawDebugLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz, 0, 1, 0);
				-- this is an test
				courseplay:debug(("%s:(Turn) wp%d=%.1f°, wp%d=%.1f°, directionChangeDeg = %.1f° halfAngle = %.1f"):format(nameNum(vehicle), vehicle.cp.waypointIndex-1, vehicle.Waypoints[vehicle.cp.waypointIndex-1].angle, vehicle.cp.waypointIndex+1, vehicle.Waypoints[vehicle.cp.waypointIndex+1].angle, turnInfo.directionChangeDeg, turnInfo.halfAngle), 14);
			end;

			--- Get the local delta distances from the tractor to the targetNode
			turnInfo.targetDeltaX, _, turnInfo.targetDeltaZ = worldToLocal(turnInfo.directionNode, cx, vehicleY, cz);
			courseplay:debug(string.format("%s:(Turn) targetDeltaX=%.2f, targetDeltaZ=%.2f", nameNum(vehicle), turnInfo.targetDeltaX, turnInfo.targetDeltaZ), 14);

			--- Get the turn direction
			  if turnInfo.isHeadlandCorner then
				-- headland corner turns have a targetDeltaX around 0 so use the direction diff
				if turnInfo.directionChangeDeg > 0 then
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

			--- Find the zOffset based on tractors current position from the start turn wp
			_, _, turnInfo.zOffset = worldToLocal(turnInfo.directionNode, vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex].cz);
			-- remember this as we'll need it later
			turnInfo.deltaZBetweenVehicleAndTarget = turnInfo.targetDeltaZ
			-- targetDeltaZ is now the delta Z between the turn start and turn end waypoints.
			turnInfo.targetDeltaZ = turnInfo.targetDeltaZ - turnInfo.zOffset;

			--- Get headland height
			-- if vehicle.cp.courseWorkWidth and vehicle.cp.courseWorkWidth > 0 and vehicle.cp.courseNumHeadlandLanes and vehicle.cp.courseNumHeadlandLanes > 0 then
			-- 	-- First headland is only half the work width
			-- 	turnInfo.headlandHeight = vehicle.cp.courseWorkWidth / 2;
			-- 	-- Add extra workwidth for each extra headland
			-- 	if vehicle.cp.courseNumHeadlandLanes - 1 > 0 then
			-- 		turnInfo.headlandHeight = turnInfo.headlandHeight + ((vehicle.cp.courseNumHeadlandLanes - 1) * vehicle.cp.courseWorkWidth);
			-- 	end;
			-- end; 
			

			

			--- Calculate reverseOffset in case we need to reverse
			local offset = turnInfo.zOffset;
			if turnInfo.frontMarker > 0 then
				offset = -turnInfo.zOffset - turnInfo.frontMarker;
			end;
			if turnInfo.turnOnField and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward then
				turnInfo.reverseOffset = max((turnInfo.turnRadius + turnInfo.halfVehicleWidth - turnInfo.headlandHeight), offset);
			else
				turnInfo.reverseOffset = offset;
			end;

			courseplay:debug(("%s:(Turn Data) frontMarker=%q, backMarker=%q, halfVehicleWidth=%q, directionNodeToTurnNodeLength=%q, wpChangeDistance=%q"):format(nameNum(vehicle), tostring(turnInfo.frontMarker), tostring(backMarker), tostring(turnInfo.halfVehicleWidth), tostring(turnInfo.directionNodeToTurnNodeLength), tostring(turnInfo.wpChangeDistance)), 14);
			courseplay:debug(("%s:(Turn Data) reverseWPChangeDistance=%q, direction=%q, haveHeadlands=%q, headlandHeight=%q"):format(nameNum(vehicle), tostring(turnInfo.reverseWPChangeDistance), tostring(turnInfo.direction), tostring(turnInfo.haveHeadlands), tostring(turnInfo.headlandHeight)), 14);
			courseplay:debug(("%s:(Turn Data) numLanes=%q, onLaneNum=%q, turnOnField=%q, reverseOffset=%q"):format(nameNum(vehicle), tostring(turnInfo.numLanes), tostring(turnInfo.onLaneNum), tostring(turnInfo.turnOnField), tostring(turnInfo.reverseOffset)), 14);
			courseplay:debug(("%s:(Turn Data) haveWheeledImplement=%q, reversingWorkTool=%q, turnRadius=%q, turnDiameter=%q"):format(nameNum(vehicle), tostring(turnInfo.haveWheeledImplement), tostring(turnInfo.reversingWorkTool), tostring(turnInfo.turnRadius), tostring(turnInfo.turnDiameter)), 14);
			courseplay:debug(("%s:(Turn Data) targetNode=%q, targetDeltaX=%q, targetDeltaZ=%q, zOffset=%q"):format(nameNum(vehicle), tostring(turnInfo.targetNode), tostring(turnInfo.targetDeltaX), tostring(turnInfo.targetDeltaZ), tostring(turnInfo.zOffset)), 14);
			courseplay:debug(("%s:(Turn Data) reverseOffset=%q, isHarvester=%q"):format(nameNum(vehicle), tostring(turnInfo.reverseOffset), tostring(turnInfo.isHarvester)), 14);


            if not turnInfo.isHeadlandCorner then 
	        ----------------------------------------------------------
	        -- SWITCH TO THE NEXT LANE
	        ----------------------------------------------------------
				  courseplay:debug(string.format("%s:(Turn) Direction difference is %.1f, this is a lane switch.", nameNum(vehicle), turnInfo.directionChangeDeg), 14);
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
	        end
            else
	            -------------------------------------------------------------
	            -- A SHARP TURN, LIKELY ON THE HEADLAND BUT NOT A LANE SWITCH
	            -------------------------------------------------------------
	            courseplay:debug(string.format("%s:(Turn) Direction difference is %.1f, this is a corner, maneuver type = %d.", 
								nameNum(vehicle), turnInfo.directionChangeDeg, vehicle.cp.headland.reverseManeuverType), 14);
	            if turnInfo.isHarvester then
								if vehicle.cp.headland.reverseManeuverType == courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_STRAIGHT then
									courseplay.generateTurnTypeHeadlandCornerReverseStraightCombine(vehicle, turnInfo)
								elseif vehicle.cp.headland.reverseManeuverType == courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_CURVE then
									courseplay.generateTurnTypeHeadlandCornerReverseWithCurve(vehicle, turnInfo)
								end
	            else
		            courseplay.generateTurnTypeHeadlandCornerReverseStraightTractor(vehicle, turnInfo)
	            end

            end

			cpPrintLine(14, 1);
			courseplay:debug(string.format("%s:(Turn) Generated %d Turn Waypoints", nameNum(vehicle), #vehicle.cp.turnTargets), 14);
			cpPrintLine(14, 3);

			-- Rotate tools if needed.
			if vehicle.cp.toolOffsetX ~= 0 and turnInfo.isHeadlandCorner == false then
				if vehicle.cp.toolOffsetX < 0 then
					AIVehicle.aiRotateLeft(vehicle);
				else
					AIVehicle.aiRotateRight(vehicle);
				end;
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
					if vehicle.cp.curTurnIndex == #vehicle.cp.turnTargets then
						-- We are on the last waypoint, so we goto stage 3 without changing to new waypoints.
						vehicle.cp.turnStage = 3;
					else
						-- We have more waypoints, so we goto stage 4, which will still change waypoints together with checking if we can lower the implement
						vehicle.cp.turnStage = 4;
					end;
					courseplay:debug(string.format("%s:(Turn) Ending turn, stage %d", nameNum(vehicle), vehicle.cp.turnStage ), 14);
					return;
				end;

				if courseplay.debugChannels[14] then
					local x1, _, z1 = localToWorld( realDirectionNode, -1, 0, frontMarker )
					local x2, _, z2 = localToWorld( realDirectionNode, 1, 0, frontMarker )
					local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 0, z1 );
					drawDebugLine(x1, y + 5, z1, 1, 1, 0, x2, y + 5, z2, 1, 1, 0); 
					local x1, _, z1 = localToWorld( realDirectionNode, -1, 0, backMarker )
					local x2, _, z2 = localToWorld( realDirectionNode, 1, 0, backMarker )
					drawDebugLine(x1, y + 5, z1, 1, 0, 0, x2, y + 5, z2, 1, 0, 0); 
				end

				local dist = courseplay:distance(newTarget.posX, newTarget.posZ, vehicleX, vehicleZ);
				local distOrig = dist

				-- Set reversing settings.
				if newTarget.turnReverse then
					refSpeed = vehicle.cp.speeds.reverse;
					if reversingWorkTool and reversingWorkTool.cp.realTurningNode then
						local workToolX, _, workToolZ = getWorldTranslation(reversingWorkTool.cp.realTurningNode);
						local directionNodeToTurnNodeLengthOffset = courseplay:distance(workToolX, workToolZ, vehicleX, vehicleZ);
						-- set the correct distance when reversing
						dist = dist - (directionNodeToTurnNodeLength + (directionNodeToTurnNodeLength - directionNodeToTurnNodeLengthOffset));
					
						if courseplay.debugChannels[14] then
							local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, workToolX, 300, workToolZ);
							drawDebugLine(vehicleX, posY + 5, vehicleZ, 1, 1, 0, workToolX, posY + 5, workToolZ, 1, 1, 0);
						end
					end;

				-- If next wp is more than 10 meters ahead, use fieldwork speed.
				elseif dist > 10 and not newTarget.turnReverse then
					refSpeed = vehicle.cp.speeds.field;
				end;

				-- Change turn waypoint
				if dist < wpChangeDistance then
					courseplay:debug( string.format( "%s:(Turn) @( %.1f, %.1f) ix = %d, distOrig = %.1f, dist = %.1f, wpChangeDistance = %.1f", 
							nameNum( vehicle ), vehicleX, vehicleZ, vehicle.cp.curTurnIndex, distOrig, dist, wpChangeDistance ), 14)
					-- See if we have to raise/lower implements at this point
					if vehicle.cp.turnTargets[vehicle.cp.curTurnIndex].raiseImplement then
						courseplay:debug( string.format( "%s:(Turn) raising implement at turn waypoint %d", nameNum(vehicle), vehicle.cp.curTurnIndex ), 14 )
						courseplay:lowerImplements(vehicle, false, false )
					elseif vehicle.cp.turnTargets[vehicle.cp.curTurnIndex].lowerImplement then
						courseplay:debug( string.format( "%s:(Turn) lowering implement at turn waypoint %d", nameNum(vehicle), vehicle.cp.curTurnIndex ), 14 )
						courseplay:lowerImplements( vehicle, true, true )
					end
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
						dx, _, dz = localDirectionToWorld(realDirectionNode, 0, 0, 1);
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
			local deltaZ, lowerImplements
      if courseplay:onAlignmentCourse( vehicle ) then
        -- on alignment course to the waypoint, ignore front marker, we want to get the vehicle itself to get to the waypoint
        _, _, deltaZ = worldToLocal(realDirectionNode,vehicle.Waypoints[vehicle.cp.waypointIndex].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex].cz)
        lowerImplements = deltaZ < 3  
      else
        _, _, deltaZ = worldToLocal(realDirectionNode,vehicle.Waypoints[vehicle.cp.waypointIndex+1].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex+1].cz)
        lowerImplements = deltaZ < (isHarvester and frontMarker + 0.5 or frontMarker);
      end
    
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

        if courseplay:onAlignmentCourse( vehicle ) then
          courseplay:endAlignmentCourse( vehicle )
          courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex );
        else
          -- move on to the turnEnd (targetNode)
          courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1);
          -- and then to the next wp in front of us.
          courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle, true));
          courseplay:clearTurnTargets(vehicle);
        end
        
				return;
			end;

		----------------------------------------------------------
		-- TURN STAGES 4 - Lower implement and continue on next lane (Multi waypoint version)
		----------------------------------------------------------
		elseif vehicle.cp.turnStage == 4 then
			if newTarget.turnEnd and vehicle.cp.curTurnIndex == #vehicle.cp.turnTargets then
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
			end;
			-- Change turn waypoint
			if dist < wpChangeDistance then
				vehicle.cp.curTurnIndex = min(vehicle.cp.curTurnIndex + 1, #vehicle.cp.turnTargets);
				return;
			end;

			--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
			-- Check if we are at the start of the lane and lower if so and continue working.
			--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
			local _, _, deltaZ = worldToLocal(realDirectionNode,vehicle.Waypoints[vehicle.cp.waypointIndex+1].cx, vehicleY, vehicle.Waypoints[vehicle.cp.waypointIndex+1].cz)

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

		if vehicle.cp.lowerToolThisTurnLoop then
			if vehicle.getIsTurnedOn ~= nil and not vehicle:getIsTurnedOn() then
				vehicle:setIsTurnedOn(true, false);
			end;
			courseplay:lowerImplements(vehicle, true, true);
			vehicle.cp.lowerToolThisTurnLoop = false;
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
		local _, _, disZ = worldToLocal(realDirectionNode, wpX, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wpX, 300, wpZ), wpZ);

    -- we don't want to turn off anything during a headland turn.
    local _, isHeadlandCorner = getDirectionChangeOfTurn( vehicle )

		if disZ < backMarker then
			if not vehicle.cp.noStopOnTurn then
				vehicle.cp.waitForTurnTime = vehicle.timer + turnTimer;
			end;
			-- raise implements only if this is not a headland turn; in headland
			-- turns the turn waypoint attributs will control when to raise/lower implements
      if not isHeadlandCorner then
        courseplay:lowerImplements(vehicle, false, false);
      end
      vehicle.cp.turnStage = 1;
		end;
	end;

	----------------------------------------------------------
	--Set the driving direction
	----------------------------------------------------------
	if newTarget then
		local posX, posZ = newTarget.revPosX or newTarget.posX, newTarget.revPosZ or newTarget.posZ;
		local directionNode = vehicle.aiVehicleDirectionNode or vehicle.cp.DirectionNode;
		dtpX,_,dtpZ = worldToLocal(directionNode, posX, vehicleY, posZ);
		if courseplay:isWheelloader(vehicle) then
			dtpZ = dtpZ * 0.5; -- wheel loaders need to turn more
		end;
    --print( ("dtp %.1f, %.1f, %.1f"):format( dtpX, dtpZ, refSpeed ))

		lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, posX, vehicleY, posZ);
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
	if vehicle.isReverseDriving then
		lz = -lz
	end

	--vehicle,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
	if newTarget and ((newTarget.turnReverse and reversingWorkTool ~= nil) or (courseplay:onAlignmentCourse( vehicle ) and vehicle.cp.curTurnIndex < 2 )) then
		if math.abs(vehicle.lastSpeedReal) < 0.0001 and  not g_currentMission.missionInfo.stopAndGoBraking then
			if not moveForwards then
				vehicle.nextMovingDirection = -1
			else
				vehicle.nextMovingDirection = 1
			end
		end

		AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, directionForce, 0.5, 20, allowedToDrive, moveForwards, lx, lz, refSpeed, 1);
	else
		dtpZ = dtpZ * 0.85;
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
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);
	end;

	--- Get the 2 circle center cordinate
	center1.x,_,center1.z = localToWorld(turnInfo.directionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.reverseOffset);

	--- Get the circle intersection points
	intersect1.x, intersect1.z = center1.x, center1.z;
	intersect2.x, intersect2.z = center2.x, center2.z;
	intersect1, intersect2 = courseplay:getTurnCircleTangentIntersectionPoints(intersect1, intersect2, turnInfo.turnRadius, turnInfo.targetDeltaX > 0);

	--- Set start and stop dir for first turn circle
	startDir.x,_,startDir.z = localToWorld(turnInfo.directionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
	stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset);

	--- Generate turn circle 1
	courseplay:generateTurnCircle(vehicle, center1, startDir, intersect1, turnInfo.turnRadius, turnInfo.direction, true);
	--- Generate points between the 2 circles
	courseplay:generateTurnStraitPoints(vehicle, intersect1, intersect2);
	--- Generate turn circle 2
	courseplay:generateTurnCircle(vehicle, center2, intersect2, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

	--- Extra WP 2 - Reverse back to field edge
	if not canTurnOnHeadland and not turnInfo.isHarvester and not vehicle.cp.aiTurnNoBackward and turnInfo.turnOnField then
		-- Move a bit more forward
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset + directionNodeToTurnNodeLength + turnInfo.extraAlignLength + turnInfo.wpChangeDistance);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, nil, nil, nil, true);

		-- Reverse back
		if turnInfo.reverseOffset - 3 > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset - 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, true, turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
		else
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
			local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance));
			courseplay:addTurnTarget(vehicle, posX, posZ, true, true, revPosX, revPosZ);
		end;

		--- Extra WP 3 - Turn End
	else
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.reverseOffset + turnInfo.directionNodeToTurnNodeLength + 5);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, nil, true);
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
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, nil, turnInfo.reverseWPChangeDistance);-- Reverse back
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
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.directionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.directionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnRadius - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);

		--- Generate the second turn circles
		center.x,_,center.z = localToWorld(turnInfo.directionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnRadius - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
		startDir.x,_,startDir.z = localToWorld(turnInfo.directionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnRadius - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnRadius);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.directionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1);

		--- Generate line between second and third turn circles
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.directionNode, (vehicle.cp.courseWorkWidth - turnInfo.turnDiameter) * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset + turnInfo.turnDiameter);
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
		center.x,_,center.z = localToWorld(turnInfo.directionNode, turnInfo.turnRadius * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		startDir.x,_,startDir.z = localToWorld(turnInfo.directionNode, 0, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.directionNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
		courseplay:generateTurnCircle(vehicle, center, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction);

		--- Generate line between first and second turn circles
		fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.directionNode, turnInfo.turnDiameter * turnInfo.direction, 0, turnInfo.zOffset - turnInfo.reverseOffset);
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
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset + directionNodeToTurnNodeLength + turnInfo.extraAlignLength + turnInfo.wpChangeDistance);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, nil, nil, nil, true);

		-- Reverse back
		if turnInfo.reverseOffset - 3 > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.reverseOffset - 3);
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, true, turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance);
		else
			posX, _, posZ = localToWorld(turnInfo.targetNode, 0, 0, 0);
			local revPosX, _, revPosZ = localToWorld(turnInfo.targetNode, 0, 0, -(turnInfo.frontMarker + directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance));
			courseplay:addTurnTarget(vehicle, posX, posZ, true, true, revPosX, revPosZ);
		end;

		--- Extra WP 3 - Turn End
	else
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, -turnInfo.reverseOffset + turnInfo.directionNodeToTurnNodeLength + 5);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, nil, true);
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

	--- Get the Triangle sides
	local centerOffset = (turnInfo.targetDeltaX * turnInfo.direction) - turnInfo.turnRadius;
	local sideC = turnInfo.turnDiameter;
	local sideB = turnInfo.turnRadius + centerOffset;
	local centerHeight = square(sideC^2 - sideB^2);
	courseplay:debug(("%s:(Turn) centerOffset=%s, sideB=%s, sideC=%s, centerHeight=%s"):format(nameNum(vehicle), tostring(centerOffset), tostring(sideB), tostring(sideC), tostring(centerHeight)), 14);

	--- Check if we can turn on the headlands
	local spaceNeeded = 0;
	if vehicle.cp.oppositeTurnMode then
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
	if turnInfo.frontMarker > 0 then
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

	--- Do the oposite direction turns for bale loaders, so we avoide bales in the normal turn direction
	if doNormalTurn and turnInfo.reversingWorkTool and courseplay:isBaleLoader(turnInfo.reversingWorkTool) then
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
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
			courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, false, true);
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
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, newZOffset + directionNodeToTurnNodeLength + extraDistance + turnInfo.extraAlignLength + turnInfo.wpChangeDistance);
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
			toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 6);
			courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, false, true);

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

	if not ((courseplay:isCombine(vehicle) or courseplay:isChopper(vehicle)) and not courseplay:isHarvesterSteerable(vehicle)) then
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
			--- We don't have space on the side we want to turn into, so we do the turn in oposite sirection
			turnInfo.direction = turnInfo.direction * -1;
		end;
		courseplay:debug(("%s:(Turn) centerOffset=%s, centerHeight=%s"):format(nameNum(vehicle), tostring(turnInfo.centerOffset), tostring(turnInfo.centerHeight)), 14);

		--- Get the 2 circle center cordinate
		center1.x,_,center1.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.turnRadius * turnInfo.direction, 0, targetDeltaZ + turnInfo.zOffset + frontOffset);
		center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, targetDeltaZ + turnInfo.zOffset - turnInfo.centerHeight + frontOffset);

		startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, targetDeltaZ + turnInfo.zOffset + frontOffset);

		--- Generate Strait point up to start point
		if turnInfo.targetDeltaZ > 0 then
			fromPoint.x, _, fromPoint.z = localToWorld(turnInfo.directionNode, 0, 0, 0);
			courseplay:generateTurnStraitPoints(vehicle, fromPoint, startDir);
		end;

		--- Generate first turn circle (Forward)
		courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction, true);

		--- Move a little bit more forward, so we can reverse properly
		local dx, dz = courseplay.generation:getPointDirection(center1, center2, false);
		local rotationDeg = deg(Utils.getYRotationFromDirection(dx, dz));
		rotationDeg = rotationDeg + (90 * turnInfo.direction);
		dx, dz = Utils.getDirectionFromYRotation(rad(rotationDeg));
		local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
		fromPoint.x = wp.posX;
		fromPoint.z = wp.posZ;
		toPoint.x = wp.posX + ((2 + turnInfo.wpChangeDistance) * dx);
		toPoint.z = wp.posZ + ((2 + turnInfo.wpChangeDistance) * dz);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint);

		--- Generate second turn circle (Reversing)
		local zPossition = targetDeltaZ + turnInfo.zOffset - turnInfo.centerHeight + frontOffset;
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
		end;

		--- Finish the turn
		local x, z = toPoint.x, toPoint.z;
		fromPoint.x = x;
		fromPoint.z = z;
		toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, turnInfo.directionNodeToTurnNodeLength - turnInfo.zOffset + 5);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, false, true);
	else
		--- Get the 2 circle center cordinate
		local center1ZOffset = turnInfo.targetDeltaZ + turnInfo.zOffset + frontOffset;
		local center2ZOffset = turnInfo.zOffset + frontOffset;

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
		local dx, dz = courseplay.generation:getPointDirection(intersect2, intersect1, false);
		toPoint.x = intersect1.x + (turnInfo.wpChangeDistance * dx);
		toPoint.z = intersect1.z + (turnInfo.wpChangeDistance * dz);
		courseplay:generateTurnStraitPoints(vehicle, intersect1, toPoint);

	    --- Reverse back to the second turn circle start point
		fromPoint.x = intersect1.x - (2 * dx);
		fromPoint.z = intersect1.z - (2 * dz);
		toPoint.x = intersect2.x - ((2 + turnInfo.reverseWPChangeDistance) * dx);
		toPoint.z = intersect2.z - ((2 + turnInfo.reverseWPChangeDistance) * dz);
		courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true);

		--- Generate second turn circle (Forward)
		stopDir.x,_,stopDir.z = localToWorld(turnInfo.targetNode, 0, 0, center2ZOffset);
		courseplay:generateTurnCircle(vehicle, center2, intersect2, stopDir, turnInfo.turnRadius, turnInfo.direction, true);

	    --- Finish the turn
		toPoint.x,_,toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, abs(turnInfo.frontMarker) + 5);
		courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, false, true);
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

	--- Get the 2 circle center cordinate
	center1.x,_,center1.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX - turnInfo.turnRadius * turnInfo.direction, 0, 1 + targetDeltaZ);
	center2.x,_,center2.z = localToWorld(turnInfo.targetNode, turnInfo.turnRadius * turnInfo.direction * -1, 0, 1 + turnInfo.centerHeight + targetDeltaZ);

	--- Generate first turn circle (Reversing)
	startDir.x,_,startDir.z = localToWorld(turnInfo.targetNode, turnInfo.targetDeltaX, 0, 1 + targetDeltaZ);
	courseplay:generateTurnCircle(vehicle, center1, startDir, center2, turnInfo.turnRadius, turnInfo.direction * -1, true, true);

	--- Move a little bit more back, so we can align better when going forward
	local dx, dz = courseplay.generation:getPointDirection(center1, center2, false);
	local rotationDeg = deg(Utils.getYRotationFromDirection(dx, dz));
	rotationDeg = rotationDeg + (90 * turnInfo.direction);
	dx, dz = Utils.getDirectionFromYRotation(rad(rotationDeg));
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	fromPoint.x = wp.posX;
	fromPoint.z = wp.posZ;
	toPoint.x = wp.posX - ((2 + turnInfo.reverseWPChangeDistance) * dx);
	toPoint.z = wp.posZ - ((2 + turnInfo.reverseWPChangeDistance) * dz);
	courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true);

	--- Generate second turn circle (Forward)
	local zPossition = 1 + turnInfo.centerHeight + targetDeltaZ;
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
	end;

	--- Finish the turn
	local x, z = toPoint.x, toPoint.z;
	fromPoint.x = x;
	fromPoint.z = z;
	toPoint.x, _, toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, 0);
	courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, true, true, turnInfo.directionNodeToTurnNodeLength + abs(turnInfo.frontMarker) + turnInfo.reverseWPChangeDistance);
end;

------------------------------------------------------------------------
-- Turns for headland corners (direction change way less than 180) to not
-- miss fuit in the corner.
--
-- We don't use turnStart in this manouver
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

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local centerReverse, tempCenterReverse, centerForward, startDir, stopDir = {}, {}, {}, {}, {}

	-- start with the easy one, get the center of the forward turning circle (this is based on the targetNode)
	centerForward.x,_,centerForward.z = localToWorld(turnInfo.targetNode, - turnInfo.direction * turnInfo.turnRadius, 0, 0 )
	-- create a tranform group there, rotation set to the half angle between turnStart and turnEnd.
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
	courseplay:generateTurnStraitPoints( vehicle, fromPoint, toPoint, false )

	--- Generate first turn circle (Reversing)
	startDir.x,_,startDir.z = localToWorld( turnStartNode, 0, 0, dzRevC )
	stopDir.x,_,stopDir.z = localToWorld( reverseCircleCenterNode, - turnInfo.direction * turnInfo.turnRadius, 0, 0 )
	courseplay:generateTurnCircle( vehicle, centerReverse, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true, true )

	-- now go straight back to where the forward arc starts (and a bit more )
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	fromPoint.x = wp.posX;
	fromPoint.z = wp.posZ;
	toPoint.x, _, toPoint.z = localToWorld( forwardCircleCenterNode, turnInfo.direction * turnInfo.turnRadius, 0, -turnInfo.reverseWPChangeDistance )
	courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true);

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

	local posX, posZ;
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
	courseplay:generateTurnStraitPoints( vehicle, fromPoint, toPoint, false )

	-- raise the implement before reversing 
	vehicle.cp.turnTargets[#vehicle.cp.turnTargets].raiseImplement = true

	-- now back up 
	local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
	fromPoint.x = wp.posX;
	fromPoint.z = wp.posZ;
	toPoint.x, _, toPoint.z = localToWorld( turnStartNode, 0, 0, - deltaZC - turnInfo.frontMarker - 3 )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightCombine(), straight from ( %.2f %.2f ), to ( %.2f %.2f )"):format(
		nameNum(vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z ), 14);
	courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true);
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
	courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, false, true );
	courseplay.destroyNode( turnStartNode )
end;

------------------------------------------------------------------------
-- Drive past turnEnd, up to the edge of the field (or current headland), then 
-- reverse back straight, then forward on a curve, reaching the target
-- direction well past turnEnd
-- During this turn the vehicle does not leave the field (or the current headland)
------------------------------------------------------------------------
function courseplay.generateTurnTypeHeadlandCornerReverseStraightTractor(vehicle, turnInfo)
	cpPrintLine(14, 3);
	courseplay:debug(string.format("%s:(Turn) Using Headland Corner Reverse Turn for tractors", nameNum(vehicle)), 14);
	cpPrintLine(14, 3);

	local posX, posZ;
	local fromPoint, toPoint = {}, {};
	local centerForward, startDir, stopDir = {}, {}, {}

	--
	-- create a helper node from turnTarget but this time rotated into the turnStart direction
	local tx, _, tz = localToWorld( turnInfo.targetNode, 0, 0, 0 )
	local turnStartNode = courseplay.createNode( "cpTurnStartNode", tx, tz, math.rad( turnInfo.startDirection ))
	tx, _, tz = localToWorld( turnStartNode, 0, 0, 0 )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), turn target node is ( %.2f %.2f )"):format(
		nameNum(vehicle), tx, tz ), 14)

	-- get the center of the forward turning circle
	turnInfo.turnRadius = turnInfo.turnRadius * 1.1
	local deltaZC = turnInfo.turnRadius / math.abs( math.tan( turnInfo.deltaAngle / 2 ))
	centerForward.x,_,centerForward.z = localToWorld(turnStartNode, - turnInfo.direction * turnInfo.turnRadius, 0, -deltaZC )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), fwdCircle( %.2f %.2f ), deltaAngle %.2f, deltaZC %.2f"):format(
		nameNum(vehicle), centerForward.x, centerForward.z, math.deg( turnInfo.deltaAngle ), deltaZC ), 14);

	-- drive forward until our implement reaches the headland after the turn
	fromPoint.x, _, fromPoint.z = localToWorld( turnInfo.directionNode, 0, 0, 0 )
	-- we want the work area of our implement reach the edge of headland after the turn
	toPoint.x, _, toPoint.z = localToWorld( turnStartNode, 0, 0, vehicle.cp.courseWorkWidth / 2 - turnInfo.frontMarker )
	-- is this now in front of us? We may not need to drive forward
	local _, _, dz = worldToLocal( turnInfo.directionNode, toPoint.x, 0, toPoint.z )
	-- at which waypoint we have to raise the implement
	local raiseImplementIndex
	if dz > 0 then
		courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), now driving forward so implement reaches headland"):format( nameNum( vehicle )), 14 )
		courseplay:generateTurnStraitPoints( vehicle, fromPoint, toPoint, false )
		local wp = vehicle.cp.turnTargets[#vehicle.cp.turnTargets];
		-- continue from here
		fromPoint.x = wp.posX;
		fromPoint.z = wp.posZ;
		-- raise implement before backing up
		raiseImplementIndex = #vehicle.cp.turnTargets
	else
		-- if we don't have to drive forward, then we reverse from where we are, but remember,
		-- in reverse our reference point is the implement's turn node
		fromPoint.x, _, fromPoint.z = localToWorld( turnInfo.directionNode, 0, 0, - turnInfo.directionNodeToTurnNodeLength )
		-- first waypoint is backing up already so raise it right there
		raiseImplementIndex = 1
	end

	-- now back up 
	toPoint.x, _, toPoint.z = localToWorld( turnStartNode, 0, 0, - deltaZC - turnInfo.directionNodeToTurnNodeLength - turnInfo.reverseWPChangeDistance)
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f) workWidth: %.1f, raise implement ix: %d"):format(
		nameNum(vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z, vehicle.cp.courseWorkWidth, raiseImplementIndex ), 14)
	courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true);
	-- raise the implement before reversing 
	vehicle.cp.turnTargets[ raiseImplementIndex ].raiseImplement = true

	-- Generate turn circle (Forward)
	startDir.x,_,startDir.z = localToWorld( turnStartNode, 0, 0, -deltaZC )
	stopDir.x, _, stopDir.z = localToWorld( turnInfo.targetNode, 0, 0, deltaZC )
	courseplay:generateTurnCircle( vehicle, centerForward, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true);

	-- Drive forward until our implement reaches the circle end and a bit more so it is hopefully aligned with the tractor
	-- and we can start reversing more or less straight.
	toPoint.x, _, toPoint.z = localToWorld( turnInfo.targetNode, 0, 0, deltaZC + turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + 5 )
	courseplay:debug(("%s:(Turn) courseplay:generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f)"):format(
		nameNum(vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z), 14);
	courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, false, false );

	-- now back up the implement to the edge of the field (or headland)
	fromPoint.x, fromPoint.z = toPoint.x, toPoint.z
	toPoint.x, _, toPoint.z = localToWorld( turnInfo.targetNode, 0, 0,
		- ( vehicle.cp.courseWorkWidth / 2 + turnInfo.directionNodeToTurnNodeLength + turnInfo.frontMarker + turnInfo.reverseWPChangeDistance))
	courseplay:generateTurnStraitPoints(vehicle, fromPoint, toPoint, true, false, turnInfo.reverseWPChangeDistance );

	-- lower the implement 
	vehicle.cp.turnTargets[#vehicle.cp.turnTargets].lowerImplement = true

	--- Finish the turn
	fromPoint.x, fromPoint.z = toPoint.x, toPoint.z
	toPoint.x,_,toPoint.z = localToWorld(turnInfo.targetNode, 0, 0, deltaZC + 3 );
	courseplay:generateTurnStraitPoints(vehicle, stopDir, toPoint, false, true);

	courseplay.destroyNode( turnStartNode )
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
	local wpDistance = wpDistance;
	local dist = courseplay:distance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z);
	local numPointsNeeded = ceil(dist / wpDistance);
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist;

	if turnEnd == true then
		endTurn = turnEnd;
	end;

	courseplay:addTurnTarget(vehicle, fromPoint.x, fromPoint.z, endTurn, reverse, nil, nil, nil, changeWhenPosible);

	local posX, posZ;
	if numPointsNeeded > 0 then
		wpDistance = dist / numPointsNeeded;
		for i=1, numPointsNeeded do
			posX = fromPoint.x + (i * wpDistance * dx);
			posZ = fromPoint.z + (i * wpDistance * dz);

			courseplay:addTurnTarget(vehicle, posX, posZ, endTurn, reverse, nil, nil, nil, changeWhenPosible);
		end;
	end;

	local revPosX, revPosZ;
	if reverse and secondaryReverseDistance then
		revPosX = toPoint.x + (secondaryReverseDistance * dx);
		revPosZ = toPoint.z + (secondaryReverseDistance * dz);
	end;

	posX = toPoint.x;
	posZ = toPoint.z;

	courseplay:addTurnTarget(vehicle, posX, posZ, endTurn, reverse, revPosX, revPosZ, nil, changeWhenPosible);

end;

-- startDir and stopDir are points (x,z). The arc starts where the line from the center of the circle
-- to startDir intersects the circle and ends where the line from the center of the circle to stopDir
-- intersects the circle.
--
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
	local wpDistance	= 1;
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
		courseplay:addTurnTarget(vehicle, posX, posZ, nil, reverse, nil, nil, true);

		local _,rot,_ = getRotation(point);
		courseplay:debug(string.format("%s:(Turn:generateTurnCircle) waypoint %d curentRotation=%d", nameNum(vehicle), i, deg(rot)), 14);
	end;

	-- Clean up the created node.
	unlink(point);
	delete(point);
end;

function courseplay:addTurnTarget(vehicle, posX, posZ, turnEnd, turnReverse, revPosX, revPosZ, dontPrint, changeWhenPosible)
	local target = {};
	target.posX 			  = posX;
	target.posZ 			  = posZ;
	target.turnEnd			  = turnEnd;
	target.turnReverse		  = turnReverse;
	target.revPosX 			  = revPosX;
	target.revPosZ 			  = revPosZ;
	target.changeWhenPosible = changeWhenPosible;
	table.insert(vehicle.cp.turnTargets, target);

	if not dontPrint then
		courseplay:debug(("%s:(Turn:addTurnTarget) posX=%.2f, posZ=%.2f, turnEnd=%s, turnReverse=%s, changeWhenPosible=%s"):format(nameNum(vehicle), posX, posZ, tostring(turnEnd and true or false), tostring(turnReverse and true or false), tostring(changeWhenPosible and true or false)), 14);
	end;
end

function courseplay:clearTurnTargets(vehicle, lowerToolThisTurnLoop)
	vehicle.cp.lowerToolThisTurnLoop = Utils.getNoNil(lowerToolThisTurnLoop, true); -- if lowerToolThisTurnLoop is set to false, it will not lower any implements in the next turn loop
	vehicle.cp.turnStage = 0;
	vehicle.cp.turnTargets = {};
	vehicle.cp.curTurnIndex = 1;
	vehicle.cp.haveCheckedMarkersThisTurn = false;
  vehicle.cp.headlandTurn = nil 
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
		
		if not specialTool then
			if workTool.setPickupState ~= nil then
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
			end;		
			if self.cp.mode == 4 then
																						 --vvTODO (Tom) why is this here vv?
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
			if self.cp.multiTools == 1 then
				courseplay:changeLaneOffset(self, nil, -self.cp.laneOffset);
			else
				courseplay:changeLaneNumber(self, -2*self.cp.laneNumber)
			end;
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

function courseplay.createNode( name, x, z, yRotation, rootNode )
	local node = createTransformGroup( name )
	link( rootNode or g_currentMission.terrainRootNode, node )
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z);
	setTranslation( node, x, y, z );
	setRotation( node, 0, yRotation, 0);
  return node
end

function courseplay.destroyNode( node )
	if node then
		unlink( node )
		delete( node )
	end
end

function getDirectionChangeOfTurn( vehicle )
  local directionChangeDeg = math.deg( getDeltaAngle( math.rad( vehicle.Waypoints[vehicle.cp.waypointIndex + 1 ].angle ),
                                                        math.rad( vehicle.Waypoints[vehicle.cp.waypointIndex - 1 ].angle )))
  local isHeadlandCornerTurn = math.abs( directionChangeDeg ) < laneTurnAngleThreshold
  return directionChangeDeg, isHeadlandCornerTurn
end

--[[
The vehicle at vehiclePos moving into the direction of WP waypoint. 
The direction it should be when reaching the waypoint is wpAngle. 
We need to determine a T1 target where the vehicle can drive to and actually reach WP in wpAngle direction.
Then we add waypoints on a circle from T1 to WP.
see https://ggbm.at/RN3cawGc
--]]

function courseplay:getAlignWpsToTargetWaypoint( vehicle, tx, tz, tDirection )
	-- make the radius a bit bigger to make sure we can make the turn
	local turnRadius = 1.2 * vehicle.cp.turnDiameter / 2
	-- target waypoint we want to reach
	local wpNode = courseplay.createNode( "wpNode", tx, tz, tDirection )
  -- which side of the target node are we?
	local vx, vy, vz = getWorldTranslation(vehicle.cp.DirectionNode or vehicle.rootNode);
	local dx, _, _ = worldToLocal( wpNode, vx, vy, vz )
	-- right -1, left +1
	local leftOrRight = dx < 0 and -1 or 1
	-- center of turn circle
	local c1x, _, c1z = localToWorld( wpNode, leftOrRight * turnRadius, 0, 0 )
	local vehicleToC1Distance = courseplay:distance( vx, vz, c1x, c1z )
	local vehicleToC1Direction = math.atan2(c1x - vx, c1z - vz )
	local angleBetweenTangentAndC1 = math.pi / 2 - math.asin( turnRadius / vehicleToC1Distance )
	-- check for NaN, may happen when we are closer han turnRadius
	if angleBetweenTangentAndC1 ~= angleBetweenTangentAndC1 then
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

	-- leverage Claus' nice turn generator
  courseplay:generateTurnCircle( vehicle, c1, t1, wp, turnRadius, leftOrRight, false, false )
	local result = vehicle.cp.turnTargets
	vehicle.cp.turnTargets = {}

	courseplay.destroyNode( t1Node )
	courseplay.destroyNode( c1Node )
	courseplay.destroyNode( wpNode )
	return result 
end

-- Start the vehicle on an alignment course towards targetWaypoint.
-- The alignment course consists of a circle segment ending at targetWaypoint,
-- with the tangent showing into the direction to the waypoint after targetWaypoint.
-- This makes sure the vehicle arrives at targetWaypoint in the correct
-- direction and won't circle around it.
--
-- The alignment course is implemented as a turn maneuver.
--
-- No obstacles are checked.
function courseplay:startAlignmentCourse( vehicle, targetWaypoint )
	if not vehicle.cp.alignment.enabled then return end
	if not ( targetWaypoint and targetWaypoint.angle ) then
		courseplay.debugVehicle( 14, vehicle, "No target waypoint or no angle on target waypoint, can't generate alginment course.")
		printCallstack()
		return
	end
	local points = courseplay:getAlignWpsToTargetWaypoint( vehicle, targetWaypoint.cx, targetWaypoint.cz, math.rad( targetWaypoint.angle ))
	if not points then
		courseplay.debugVehicle( 14, vehicle, "(Align) can't find an alignment course, may be too close to target wp?" )
		return
	end
	if #points < 3 then
		courseplay.debugVehicle( 14, vehicle, "(Align) Alignment course would be only %d waypoints, it isn't neeeded then.", #points )
		return
	end
  courseplay:clearTurnTargets( vehicle )
	for _, point in ipairs( points ) do
		courseplay:addTurnTarget( vehicle, point.posX, point.posZ, false )
		courseplay.debugVehicle( 14, vehicle, "(Align) Adding an alignment wp: (%1.f, %1.f)", point.posX, point.posZ )
	end
	vehicle.cp.turnTargets[#vehicle.cp.turnTargets].turnEnd = true
	vehicle.cp.turnStage = 2
	vehicle.cp.isTurning = true
  vehicle.cp.alignment.onAlignmentCourse = true
end

-- is the vehicle currently on an alignment course?
function courseplay:onAlignmentCourse( vehicle )
	return vehicle.cp.alignment.onAlignmentCourse
end

function courseplay:getAlignmentCourseWpChangeDistance( vehicle )
	-- same for all vehicles for now
	return 3
end

-- End the alignment course, restore the original course and continue on it.
function courseplay:endAlignmentCourse( vehicle )
	if courseplay:onAlignmentCourse( vehicle ) then
		courseplay:debug(string.format("%s:(Align) Ending alignment course, countinue on original course at waypoint %d.", nameNum(vehicle), vehicle.cp.waypointIndex), 14 )
		vehicle.cp.alignment.onAlignmentCourse = false
	else
		courseplay:debug(string.format("%s:(Align) Ending alignment course but not on alignment course.", nameNum(vehicle)), 14 )
	end
	courseplay:clearTurnTargets( vehicle )
end

-- do not delete this line
-- vim: set noexpandtab:
