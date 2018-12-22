-- temp file to copy out the parts needed for CombineUnlaodAIDriver
local abs, ceil, max, min = math.abs, math.ceil, math.max, math.min;
local _;


function courseplay:calculateCombineOffset(vehicle, combine)
	local curFile = "mode2.lua";
	local offs = vehicle.cp.combineOffset
	local offsPos = abs(vehicle.cp.combineOffset)
	local combineDirNode = combine.cp.DirectionNode or combine.rootNode;
	
	local prnX,prnY,prnZ, prnwX,prnwY,prnwZ, combineToPrnX,combineToPrnY,combineToPrnZ = 0,0,0, 0,0,0, 0,0,0;
	if combine.pipeRaycastNode ~= nil then
		prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combineDirNode, prnwX, prnwY, prnwZ)

		if combine.cp.pipeSide == nil then
			courseplay:getCombinesPipeSide(combine)
		end
	end;

	--special tools, special cases
	local specialOffset = courseplay:getSpecialCombineOffset(combine);
	if vehicle.cp.combineOffsetAutoMode and specialOffset then
		offs = specialOffset;
	
	--Sugarbeet Loaders (e.g. Ropa Euro Maus, Holmer Terra Felis) --TODO (Jakob): theoretically not needed, as it's being dealt with in getSpecialCombineOffset()
	elseif vehicle.cp.combineOffsetAutoMode and combine.cp.isSugarBeetLoader then
		local utwX,utwY,utwZ = getWorldTranslation(combine.pipeRaycastNode or combine.unloadingTrigger.node);
		local combineToUtwX,_,combineToUtwZ = worldToLocal(combineDirNode, utwX,utwY,utwZ);
		offs = combineToUtwX;

	--combine // combine_offset is in auto mode, pipe is open
	elseif not combine.cp.isChopper and vehicle.cp.combineOffsetAutoMode and combine.pipeCurrentState == 2 and combine.pipeRaycastNode ~= nil then --pipe is open
		local raycastNodeParent = getParent(combine.pipeRaycastNode);
		if raycastNodeParent == combine.rootNode then -- pipeRaycastNode is direct child of combine.root
			--safety distance so the trailer doesn't crash into the pipe (sidearm)
			local additionalSafetyDistance = 0;
			if combine.cp.isGrimmeTectron415 then
				additionalSafetyDistance = -0.5;
			end;

			offs = prnX + additionalSafetyDistance;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, offs), 4)
		elseif getParent(raycastNodeParent) == combine.rootNode then --pipeRaycastNode is direct child of pipe is direct child of combine.root
			local pipeX, pipeY, pipeZ = getTranslation(raycastNodeParent)
			offs = pipeX - prnZ;
			
			if prnZ == 0 or combine.cp.isGrimmeRootster604 then
				offs = pipeX - prnY;
			end;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipe > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, offs), 4)
		elseif combine.pipeRaycastNode ~= nil then --BACKUP pipeRaycastNode isn't direct child of pipe
			offs = combineToPrnX + 0.5;
			--courseplay:debug(string.format("%s(%i): %s @ %s: combineToPrnX // offs = %f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, offs), 4)
		elseif combine.cp.lmX ~= nil then --user leftMarker
			offs = combine.cp.lmX + 2.5;
		else --if all else fails
			offs = 8;
		end;

	--combine // combine_offset is in manual mode
	elseif not combine.cp.isChopper and not vehicle.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [manual] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);
	
	--combine // combine_offset is in auto mode
	elseif not combine.cp.isChopper and vehicle.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [auto] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);

	--chopper // combine_offset is in auto mode
	elseif combine.cp.isChopper and vehicle.cp.combineOffsetAutoMode then
		if combine.cp.lmX ~= nil then
			offs = max(combine.cp.lmX + 2.5, 7);
		else
			offs = 8;
		end;
		courseplay:sideToDrive(vehicle, combine, 10);
			
		if vehicle.sideToDrive ~= nil then
			if vehicle.sideToDrive == "left" then
				offs = abs(offs);
			elseif vehicle.sideToDrive == "right" then
				offs = abs(offs) * -1;
			end;
		end;
	end;
	
	--cornChopper forced side offset
	if combine.cp.isChopper and combine.cp.forcedSide ~= nil then
		if combine.cp.forcedSide == "left" then
			offs = abs(offs);
		elseif combine.cp.forcedSide == "right" then
			offs = abs(offs) * -1;
		end
		--courseplay:debug(string.format("%s(%i): %s @ %s: cp.forcedSide=%s => offs=%f", curFile, debug.getinfo(1).currentline, vehicle.name, combine.name, combine.cp.forcedSide, offs), 4)
	end

	--refresh for display in HUD and other calculations
	vehicle.cp.combineOffset = offs;
end;

function courseplay:calculateVerticalOffset(vehicle, combine)
	local cwX, cwY, cwZ = getWorldTranslation( combine.spec_dischargeable.currentRaycastDischargeNode.node);
	local _, _, prnToCombineZ = worldToLocal(combine.cp.DirectionNode or combine.rootNode, cwX, cwY, cwZ);
	
	return prnToCombineZ;
end;

function courseplay:getTargetUnloadingCoords(vehicle, combine, trailerOffset, prnToCombineZ)
	local sourceRootNode = combine.cp.DirectionNode or combine.rootNode;

	if combine.cp.isChopper then
		prnToCombineZ = 0;
	end;

	local ttX, _, ttZ = localToWorld(sourceRootNode, vehicle.cp.combineOffset, 0, trailerOffset + prnToCombineZ);

	return ttX, ttZ;
end;

-- MODE STATE FUNCTIONS
function courseplay:setModeState(vehicle, state, debugLevel)
	debugLevel = debugLevel or 2;
 	if vehicle.cp.modeState ~= state then
		courseplay:debug( string.format( "%s: Switching state: %d -> %d", nameNum( vehicle ), vehicle.cp.modeState, Utils.getNoNil( state, -1 )), 9 )
		vehicle.cp.modeState = state;
	end;
	if vehicle.cp.isParking and state == STATE_WAIT_AT_START then
		vehicle.cp.isParking = nil	
	end
end;

function courseplay:setMode2NextState(vehicle, nextState)
	if nextState == nil then return; end;
  local oldNextState = vehicle.cp.mode2nextState or 0 
  courseplay:debug( string.format( "%s: Setting next state: %d -> %d", nameNum( vehicle ), oldNextState, nextState ), 9 )
	if vehicle.cp.mode2nextState ~= nextState then
		vehicle.cp.mode2nextState = nextState;
	end;
end;

function courseplay:switchToNextMode2State(vehicle)
	if vehicle.cp.mode2nextState == nil then return; end;

	courseplay:setModeState(vehicle, vehicle.cp.mode2nextState, 3);
end;

function courseplay:onModeStateChange(vehicle, oldState, newState)
end;

function courseplay:convertTable(turnTargets)
	local newTable = {}
	for i=1,#turnTargets do
		newTable[i] = {}
		newTable[i].x = turnTargets[i].posX
		newTable[i].z = turnTargets[i].posZ
		newTable[i].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newTable[i].x, 0, newTable[i].z);
		newTable[i].rev = turnTargets[i].turnReverse or false
		newTable[i].turn = true 
	end
	return  newTable
end

function courseplay:createTurnAwayCourse(vehicle,direction,sentDiameter,workwidth,zOffset)
		--inspired by Satis :-)
		local additionalZOffset = zOffset or 0;
		local targets = {}
		local center1, center2, startDir, stopDir = {}, {}, {}, {};
		local diameter = sentDiameter
		local radius = diameter/2
		local center1SideOffset = radius*direction
		local center2SideOffset = -(workwidth-radius)*direction
		local sideC = diameter;
		local sideB = abs(center1SideOffset-center2SideOffset);
		
		local centerHeight = math.sqrt(sideC^2 - sideB^2);
				
		--- Get the 2 circle center cordinate
		center1.x,_,center1.z = localToWorld(vehicle.cp.DirectionNode, center1SideOffset, 0, 0-additionalZOffset);
		center2.x,_,center2.z = localToWorld(vehicle.cp.DirectionNode, center2SideOffset, 0, -centerHeight-additionalZOffset);

		
		
		--- Generate first turn circle
		startDir.x,_,startDir.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, 0);
		courseplay:generateTurnCircle(vehicle, center1, startDir, center2, radius, direction);

		--- Generate second turn circle
		stopDir.x,_,stopDir.z = localToWorld(vehicle.cp.DirectionNode, -centerHeight*direction, 0, -centerHeight+radius-additionalZOffset);
		courseplay:generateTurnCircle(vehicle, center2, center1, stopDir, radius, -direction, true);
		
		targets = courseplay:convertTable(vehicle.cp.turnTargets)
		vehicle.cp.turnTargets = {}
		
		return targets
end

-- if there's fruit between me and the combine, calculate a path around it and return true.
-- if there's no fruit or no path around it or couldn't calculate path, return false				
function courseplay:calculateAstarPathToCoords( vehicle, combine, tx, tz, endBeforeTargetDistance, mode4_6)
	local cx, cz = 0, 0
	local fruitType = 0

  -- if a combine was passed, use it's location
	if combine ~= nil then
		cx, _, cz = getWorldTranslation( combine.rootNode )
	else
		cx, cz = tx, tz
	end
  --
	-- pathfinding is expensive and we don't want it happen in every update cycle
	if not courseplay:timerIsThrough( vehicle, 'pathfinder', true ) then
		courseplay.debugVehicle( 9, vehicle, "Pathfinding: has been called too many times exiting" )
		return false
	end
	courseplay:setCustomTimer( vehicle, 'pathfinder', 5 )

	local hasFruit, density, fruitType, fruitName = courseplay:hasLineFruit( vehicle.cp.DirectionNode,nil, nil, cx, cz, fixedFruitType )
	--Ingore this condintal if I am being used by Mode4/6
	if not hasFruit and not mode4_6 then
		-- no fruit between tractor and combine, can continue in STATE_DRIVE_TO_COMBINE 
		-- and drive directly to the combine.
		courseplay.debugVehicle( 9, vehicle, "Pathfinding: no fruit between tractor and combine" )	
		return false
	elseif not mode4_6 then
		courseplay.debugVehicle( 9, vehicle, "there is %.1f %s(%d) in my way -> create path around it",density,fruitName,fruitType)
	end
  
	-- tractor coordinates
	local vx,vy,vz =	getWorldTranslation( vehicle.cp.DirectionNode )

	-- where am I ?
	if courseplay.fields == nil then
		courseplay.debugVehicle( 9, vehicle, "Pathfinding: no field data available!" )		
		courseplay.debugVehicle( 9, vehicle, "to use the full function of pathfinding, you have to activate the automatic field scan or scan this field manually")
		return false
	end

	local fieldNum = courseplay:onWhichFieldAmI( vehicle ); 
		
	if fieldNum == 0 then														-- No combines are aviable use us again
		local combine = vehicle.cp.activeCombine or vehicle.cp.lastActiveCombine or vehicle;
		fieldNum = courseplay:onWhichFieldAmI( combine );
		if fieldNum == 0 and mode4_6 then
			-- My unloading course doesn't end on a field so I need to know on which field I am returning to by using the waypoint x and z
			fieldNum = courseplay:getFieldNumForPosition( tx, tz )
		end
		if fieldNum == 0 then
			courseplay.debugVehicle( 9, vehicle, "I'm not on field, my combine isn't either" )
			return false
		else
			courseplay.debugVehicle( 9, vehicle, "I'm not on field, my combine is on ".. tostring( fieldNum ))
			-- pathfinding works only within the field, so we'll have to get to the field first
			local closestPointToVehicleIx = courseplay.generation:getClosestPolyPoint( courseplay.fields.fieldData[ fieldNum ].points, vx, vz )
			-- we'll use this instead of the vehicle location, so tractor will drive directly to this point first 
			vx = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cx
			vz = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cz
		end
	else
		courseplay.debugVehicle( 9, vehicle, "I'm on field " .. tostring( fieldNum ))
		local _, pointInPoly, _, _ = courseplay.fields:getPolygonData(courseplay.fields.fieldData[fieldNum].points, cx, cz, true, true, true);
		if not pointInPoly then
			local closestPointToVehicleIx = courseplay.generation:getClosestPolyPoint( courseplay.fields.fieldData[ fieldNum ].points, cx, cz )
			cx = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cx
			cz = courseplay.fields.fieldData[ fieldNum ].points[ closestPointToVehicleIx ].cz
		end	
	end

  courseplay.debugVehicle( 9, vehicle, "Finding path between %.2f, %.2f and %.2f, %.2f", vx, vz, cx, cz )
  local path = courseGenerator.findPath( { x = vx, z = vz }, { x = cx, z = cz }, 
                                    courseplay.fields.fieldData[fieldNum].points, fruitType )
   
  if path then
    courseplay.debugVehicle( 9, vehicle, "Path found with %d waypoints", #path )
  elseif path == nil and mode4_6 then
	-- I couldn't find a path but I still really want a path because I really want to stay on the field but don't care about fruit
	path = courseGenerator.findPath( { x = vx, z = vz }, { x = cx, z = cz }, 
									courseplay.fields.fieldData[fieldNum].points, function() return false end )
	courseplay.debugVehicle( 9, vehicle, "Path found with %d waypoints ingore fruit cause first attempt failed", #path )
  end
  if path == nil then
	-- Still Couldn't Find a path we will just go with what we know which is head straight there, TODO allowed to drive if in mode4/6 = false or true what would be better
	-- Stopping and dispalying a halt message or just going for it and hope for the best. Also TODO check to see if the track between start n end is 100% or not 
	-- in wich cause we don't need to use this expenisve function
    courseplay.debugVehicle( 9, vehicle, "No path found, reverting to dumb mode" )
    return false
  end

  -- path only has x,z, add y, most likely for the debug lines only.
  if g_currentMission then
   -- courseplay:debug( tableShow( g_currentMission, "currentMission", 9, ' ', 3 ), 9 )
    for _, point in ipairs( path ) do
      point.y = getTerrainHeightAtWorldPos( g_currentMission.terrainRootNode, point.x, 1, point.z )
    end
  else
    courseplay:debug( string.format( "g_currentMission does not exist, oops. " ))
    return false
  end
  -- make sure path begins far away from the tractor so it won't circle around
  local pointFarEnoughIx = 1
  for _, point in ipairs( path ) do 
		local lx, ly, lz = worldToLocal( vehicle.cp.DirectionNode, point.x, point.y, point.z )
		local d = MathUtil.vector2Length(lx, lz)
    if d > Utils.getNoNil( vehicle.cp.turnDiameter, 5 ) then break end
    pointFarEnoughIx = pointFarEnoughIx + 1
  end
  for i = 1, pointFarEnoughIx do
    table.remove( path, 1 ) 
  end
  -- make sure path ends far away from the target so it can switch to the next mode
  -- without circling
  local pointFarEnoughIx = #path
  for i = #path, 1, -1 do
    local point = path[ i ]
    local d = MathUtil.vector2Length( cx - point.x, cz - point.z )
    if d > Utils.getNoNil( endBeforeTargetDistance, 0 ) then break end
    pointFarEnoughIx = pointFarEnoughIx - 1
  end
  for i = #path, pointFarEnoughIx, -1 do
    table.remove( path ) 
  end
  if #path < 2 then
    courseplay.debugVehicle( 9, vehicle, "Path hasn't got enough waypoints (%d), no fruit avoidance", #path )
    return false
  else
	vehicle.cp.nextTargets = path
    return true                                 
  end
end



function courseplay:onWhichFieldAmI(vehicle)
	local positionX,_,positionZ = getWorldTranslation(vehicle.cp.DirectionNode or vehicle.rootNode);
	return courseplay:getFieldNumForPosition( positionX, positionZ )
end

function courseplay:getFieldNumForPosition( positionX, positionZ )
	local fieldNum = 0;
	for index, field in pairs(courseplay.fields.fieldData) do
		if positionX >= field.dimensions.minX and positionX <= field.dimensions.maxX and positionZ >= field.dimensions.minZ and positionZ <= field.dimensions.maxZ then
			local _, pointInPoly, _, _ = courseplay.fields:getPolygonData(field.points, positionX, positionZ, true, true, true);
			if pointInPoly then
				fieldNum = index
				break
			end
		end	
	end
	return fieldNum
end

function courseplay:getWaypointShift(vehicle,tractor)
	if not tractor:getIsCourseplayDriving() then
		return 0;
	else
		local px,pz = tractor.Waypoints[tractor.cp.waypointIndex].cx, tractor.Waypoints[tractor.cp.waypointIndex].cz
		local py = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 0, pz)
		local _,_,vehicleShift = worldToLocal(tractor.cp.DirectionNode,px,py,pz)

		local nx,nz = tractor.Waypoints[tractor.cp.waypointIndex+1].cx, tractor.Waypoints[tractor.cp.waypointIndex+1].cz
		local ny = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nx, 0, nz)
		local _,_,npShift = worldToLocal(tractor.cp.DirectionNode,nx,ny,nz)
		return npShift-vehicleShift+tractor.sizeLength*0.5;
	end
end

function courseplay:getSafetyDistanceFromCombine( combine )
	local safetyDistance = 11;
	if combine.cp.isHarvesterSteerable or combine.cp.isSugarBeetLoader or combine.cp.isWoodChipper or combine.cp.isPoettingerMex5 then
		safetyDistance = 24;
	elseif courseplay:isAttachedCombine(combine) then
		safetyDistance = 11;
	elseif combine.cp.isCombine then
		safetyDistance = 10;
	elseif combine.cp.isChopper then
		safetyDistance = 11;
	end;
  return safetyDistance
end
-- do not remove this comment
-- vim: set noexpandtab:
