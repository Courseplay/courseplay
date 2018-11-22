function courseplay:getCurrentMovingToolsPosition(vehicle, movingTools, secondary , fixIndex) --NOTE: still needed for saveShovelPosition()
	if movingTools == nil then
		print(nameNum(vehicle) .. ': courseplay:getCurrentMovingToolsPosition() return nil');
		return nil;
	end;

	local rotAxis, transAxis = 1, 3; -- 1 = x, 3 = z;
	local curRot, curTrans = {}, {};
	if fixIndex then
		rotAxis = 3
		local mt = movingTools[fixIndex]
			if mt.curRot and mt.curRot[rotAxis] then
				table.insert(curRot, mt.curRot[rotAxis]);
			end;
			if mt.curTrans and mt.curTrans[transAxis] then
				table.insert(curTrans, mt.curTrans[transAxis]);
			end;		
	else
		for i,mt in pairs(movingTools) do
			if mt.curRot and mt.curRot[rotAxis] then
				table.insert(curRot, mt.curRot[rotAxis]);
			end;
			if mt.curTrans and mt.curTrans[transAxis] then
				table.insert(curTrans, mt.curTrans[transAxis]);
			end;
		end;
		if secondary ~= nil then
			for i,mt in pairs(secondary) do
				if mt.curRot and mt.curRot[rotAxis] then
					table.insert(curRot, mt.curRot[rotAxis]);
				end;
				if mt.curTrans and mt.curTrans[transAxis] then
					table.insert(curTrans, mt.curTrans[transAxis]);
				end;
			end;
		end;
	end 
	return curRot, curTrans;
end;

function courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, secondaryMovingTools, targetPositions, dt ,fixIndex)
	local targetRotations, targetTranslations = targetPositions.rot, targetPositions.trans;
	local changed = false;
	local numPrimaryMovingTools = #movingTools;
	local rotAxis, transAxis = 1, 3; -- 1 = x, 3 = z;

	for i=1,#targetRotations do
		local mt, mtMainObject;
		if fixIndex then
			mt = movingTools[fixIndex];
			rotAxis = mt.rotationAxis
			transAxis = mt.translationAxis
			mtMainObject = vehicle
		else
			if i <= numPrimaryMovingTools then
				mt = movingTools[i];
				mtMainObject = vehicle;
			else
				mt = secondaryMovingTools[i - numPrimaryMovingTools];
				mtMainObject = vehicle.cp.shovel;
			end;
		end
		if mt == nil then
			break
		end
		local curRot = mt.curRot[rotAxis];
		local curTrans = mt.curTrans[transAxis];
		local targetRot = targetRotations[i];
		local targetTrans = targetTranslations[i];
		if courseplay:round(curRot, 4) ~= courseplay:round(targetRot, 4) or courseplay:round(curTrans, 3) ~= courseplay:round(targetTrans, 3) then
			local newRot, newTrans;

			-- ROTATION
			local rotDir = Utils.sign(targetRot - curRot);
			if mt.node and rotDir and rotDir ~= 0 then
				local rotChange = mt.rotSpeed ~= nil and (mt.rotSpeed * dt) or (0.2/dt);
				newRot = curRot + (rotChange * rotDir)
				if (rotDir == 1 and newRot > targetRot) or (rotDir == -1 and newRot < targetRot) then
					newRot = targetRot;
				end;
				if newRot ~= curRot  then
					--courseplay:debug(string.format('%s: movingTool %d: curRot=%.5f, targetRot=%.5f -> newRot=%.5f', nameNum(vehicle), i, curRot, targetRot, newRot), 10);
					mt.curRot[rotAxis] = newRot;
					setRotation(mt.node, unpack(mt.curRot));
					if mt.delayedNode ~= nil then
						mt.delayedUpdates = 2;
						Cylindered.setDelayedNodeRotation(vehicle, mt);
					end
					changed = true;
				end;
			end;

			-- TRANSLATION
			if mt.transSpeed ~= nil then --only change values if transSpeed actually exists
				-- local transSpeed = mt.transSpeed * dt;
				local transDir = Utils.sign(targetTrans - curTrans);
				if mt.node and mt.transMin and mt.transMax and transDir and transDir ~= 0 then
					local transChange = math.min(mt.transSpeed, 0.001) * dt; -- maximum: 1mm/ms (1m/s)
					newTrans = Utils.clamp(curTrans + (transChange * transDir), mt.transMin, mt.transMax);
					if (transDir == 1 and newTrans > targetTrans) or (transDir == -1 and newTrans < targetTrans) then
						newTrans = targetTrans;
					end;
					if newTrans ~= curTrans and newTrans >= mt.transMin and newTrans <= mt.transMax then
						--courseplay:debug(string.format('%s: movingTool %d: curTrans=%.5f, targetTrans=%.5f -> newTrans=%.5f', nameNum(vehicle), i, curTrans, targetTrans, newTrans), 10);
						mt.curTrans[transAxis] = newTrans;
						setTranslation(mt.node, unpack(mt.curTrans));
						if mt.delayedNode ~= nil then
							mt.delayedUpdates = 2;
							Cylindered.setDelayedNodeTranslation(vehicle, mt);
						end
						changed = true;
					end;
				end;
			end;

			-- DIRTY FLAGS (movingTool)
			-- TODO: check if Cylindered.setMovingToolDirty() is better here
			if changed then
				if vehicle.cp.attachedFrontLoader ~= nil then
					Cylindered.setDirty(vehicle.cp.attachedFrontLoader, mt);
				else
					Cylindered.setDirty(mtMainObject, mt);
				end	
				vehicle:raiseDirtyFlags(mtMainObject.cylinderedDirtyFlag);
			end;
		end;
	end;

	-- DIRTY FLAGS (movingParts)
	if changed then
		if vehicle.activeDirtyMovingParts then
			for _, part in pairs(vehicle.activeDirtyMovingParts) do
				Cylindered.setDirty(vehicle, part);
			end;
		end;
		if vehicle.cp.shovel and vehicle.cp.shovel.activeDirtyMovingParts then
			for _, part in pairs(vehicle.cp.shovel.activeDirtyMovingParts) do
				Cylindered.setDirty(vehicle.cp.shovel, part);
			end;
		end;
	end;
	return not changed;
end;

function courseplay:getMovingTools(vehicle)
	local primaryMovingTools, secondaryMovingTools;
	local frontLoader, shovel ,pipe = 0, 0;
	for i=1, #(vehicle.attachedImplements) do
		if vehicle.attachedImplements[i].object.cp.hasSpecializationShovel then
			shovel = i;
		elseif courseplay:isFrontloader(vehicle.attachedImplements[i].object) then
			frontLoader = i;
		else
			pipe = i;
		end;
	end;

	courseplay:debug(('%s: getMovingTools(): frontLoader index=%d, shovel index=%d'):format(nameNum(vehicle), frontLoader, shovel), 10);

	if shovel ~= 0 then
		primaryMovingTools = vehicle.movingTools;
		secondaryMovingTools = vehicle.attachedImplements[shovel].object.movingTools;
		vehicle.cp.shovel = vehicle.attachedImplements[shovel].object;

		courseplay:debug(('    [1] primaryMt=%s, secondaryMt=%s, shovel=%s'):format(nameNum(vehicle), nameNum(vehicle.attachedImplements[shovel].object), nameNum(vehicle.cp.shovel)), 10);
	elseif frontLoader ~= 0 then
		local object = vehicle.attachedImplements[frontLoader].object;
		vehicle.cp.attachedFrontLoader = object
		primaryMovingTools = object.movingTools;
		if object.attachedImplements[1] ~= nil then
			secondaryMovingTools = object.attachedImplements[1].object.movingTools;
			vehicle.cp.shovel = object.attachedImplements[1].object;
			courseplay:debug(('    [2] attachedFrontLoader=%s, primaryMt=%s, secondaryMt=%s, shovel=%s'):format(nameNum(object), nameNum(object), nameNum(object.attachedImplements[1].object), nameNum(vehicle.cp.shovel)), 10);
		end;
		
	elseif pipe ~= 0 then
		primaryMovingTools = vehicle.attachedImplements[i].object.movingTools;
	else
		primaryMovingTools = vehicle.movingTools;
		vehicle.cp.shovel = vehicle;

		courseplay:debug(('    [3] primaryMt=%s, shovel=%s'):format(nameNum(vehicle), nameNum(vehicle.cp.shovel)), 10);
	end;

	return primaryMovingTools, secondaryMovingTools;
end;

function courseplay:createBunkerSiloMap(vehicle, Silo,width, height)
	local sx,sz = Silo.bunkerSiloArea.sx,Silo.bunkerSiloArea.sz;
	local wx,wz = Silo.bunkerSiloArea.wx,Silo.bunkerSiloArea.wz;
	local hx,hz = Silo.bunkerSiloArea.hx,Silo.bunkerSiloArea.hz;
	local sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 1, sz);
	local bunkerWidth = courseplay:distance(sx,sz, wx, wz)
	local bunkerLength = courseplay:distance(sx,sz, hx, hz)
	local startDistance = courseplay:distanceToPoint(vehicle, sx, sy, sz)
	local endDistance = courseplay:distanceToPoint(vehicle, hx, sy, hz)
	local widthDirX,widthDirY,widthDirZ,widthDistance = courseplay:getWorldDirection(sx,sy,sz, wx,sy,wz);
	local heightDirX,heightDirY,heightDirZ,heightDistance = courseplay:getWorldDirection(sx,sy,sz, hx,sy,hz);

	local widthCount = math.ceil(bunkerWidth/vehicle.cp.workWidth)
	if vehicle.cp.mode10.leveling and courseplay:isEven(widthCount) then
		widthCount = widthCount+1
	end
	
	local heightCount = math.ceil(bunkerLength/vehicle.cp.workWidth)
	local unitWidth = bunkerWidth/widthCount
	local unitHeigth = bunkerLength/heightCount
	local heightLengthX = (Silo.bunkerSiloArea.hx-Silo.bunkerSiloArea.sx)/heightCount
	local heightLengthZ = (Silo.bunkerSiloArea.hz-Silo.bunkerSiloArea.sz)/heightCount
	local widthLengthX = (Silo.bunkerSiloArea.wx-Silo.bunkerSiloArea.sx)/widthCount
	local widthLengthZ = (Silo.bunkerSiloArea.wz-Silo.bunkerSiloArea.sz)/widthCount
	local getOffTheWall = 0.5;
	
	local lastValidfillType = 0
	local map = {}
	for heightIndex = 1,heightCount do
		map[heightIndex]={}
		for widthIndex = 1,widthCount do
			local newWx = sx + widthLengthX
			local newWz = sz + widthLengthZ
			local newHx = sx + heightLengthX
			local newHz = sz + heightLengthZ
			
			local wY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newWx, 1, newWz); 
			local hY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newHx, 1, newHz);
			local fillType = TipUtil.getFillTypeAtLine(newWx, wY, newWz, newHx, hY, newHz, 5)
			if lastValidfillType ~= fillType and fillType ~= 0 then
				lastValidfillType = fillType
			end
			local newFillLevel = TipUtil.getFillLevelAtArea(fillType, sx, sz, newWx, newWz, newHx, newHz )
			local bx = sx + (widthLengthX/2) + (heightLengthX/2)  
			local bz = sz + (widthLengthZ/2) + (heightLengthZ/2)
			local offset = 0
			if vehicle.cp.mode9TargetSilo.type and vehicle.cp.mode9TargetSilo.type == "heap" then
				offset = unitWidth/2
			else
				if widthIndex == 1 then
					offset = getOffTheWall+ (vehicle.cp.workWidth/2)
				elseif widthIndex == widthCount then
					offset = unitWidth- (getOffTheWall+ (vehicle.cp.workWidth/2))
				else
					offset = unitWidth/2
				end
			end
			local cx,cz = sx +(widthDirX*offset)+(heightLengthX/2),sz +(widthDirZ*offset)+ (heightLengthZ/2)
			if vehicle.cp.mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY and heightIndex == heightCount then
				cx,cz = sx +(widthDirX*offset)+(heightLengthX),sz +(widthDirZ*offset)+ (heightLengthZ)
			end
			local unitArea = unitWidth*unitHeigth
			
			map[heightIndex][widthIndex] ={
										sx = sx;
										sz = sz;
										y = wY;
										wx = newWx;
										wz = newWz;
										hx = newHx;
										hz = newHz;
										cx = cx;
										cz = cz;
										bx = bx;
										bz = bz;
										area = unitArea;
										fillLevel = newFillLevel;
										fillType = fillType;
										bunkerLength = bunkerLength;
										bunkerWidth = bunkerWidth;
											}
											
			sx = map[heightIndex][widthIndex].wx
			sz = map[heightIndex][widthIndex].wz
		end
		sx = map[heightIndex][1].hx
		sz = map[heightIndex][1].hz
	end
	if lastValidfillType > 0 then
		courseplay:debug(('%s: Bunkersilo filled with %s(%i) will be devided in %d lines and %d columns'):format(nameNum(vehicle),g_fillTypeManager.indexToFillType[lastValidfillType].name ,lastValidfillType, heightCount, widthCount), 10);   
	else
		courseplay:debug(('%s: empty Bunkersilo will be devided in %d lines and %d columns'):format(nameNum(vehicle), heightCount, widthCount), 10);   
	end
	--invert table
	if endDistance < startDistance then
		courseplay:debug(('%s: Bunkersilo will be approached from the back -> turn map'):format(nameNum(vehicle)), 10);
		local newMap = {}	
		local lineCounter = #map 
		for lineIndex=1,lineCounter do 
			local newLineIndex = lineCounter+1-lineIndex;
			--print(string.format("put line%s into line%s",tostring(lineIndex),tostring(newLineIndex)))
			newMap[newLineIndex]={}
			local columnCount = #map[lineIndex]
			for columnIndex =1, columnCount do
				--print(string.format("  put column%s into column%s",tostring(columnIndex),tostring(columnCount+1-columnIndex)))
				newMap[newLineIndex][columnCount+1-columnIndex] = map[lineIndex][columnIndex]
			end
		end	
		map = newMap
	end
	return map
end

function courseplay:getMode9TargetBunkerSilo(vehicle,forcedPoint)
	local pointIndex = 0
	if forcedPoint then
		 pointIndex = forcedPoint;
	else
		pointIndex = vehicle.cp.shovelFillStartPoint+1
	end
	local x,z = vehicle.Waypoints[pointIndex].cx,vehicle.Waypoints[pointIndex].cz			
	local tx,tz = x,z + 0.50
	local p1x,p1z,p2x,p2z,p1y,p2y = 0,0,0,0,0,0
	if g_currentMission.bunkerSilos ~= nil then
		for _, bunker in pairs(g_currentMission.bunkerSilos) do
			local x1,z1 = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local x2,z2 = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local x3,z3 = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			bunker.type = "silo"
			if Utils.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z) then
				return bunker
			end
		end
	end
	
	--it's not a bunkersSilo, try to find a heap
	local heapFillType = 0
	if vehicle.cp.mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY then
		p1x,p1z = vehicle.Waypoints[vehicle.cp.shovelFillStartPoint].cx,vehicle.Waypoints[vehicle.cp.shovelFillStartPoint].cz;
		p2x,p2z = vehicle.Waypoints[vehicle.cp.shovelFillEndPoint].cx,vehicle.Waypoints[vehicle.cp.shovelFillEndPoint].cz;
		p1y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1x, 1, p1z);
		p2y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p2x, 1, p2z);
		heapFillType = TipUtil.getFillTypeAtLine(p1x, p1y, p1z, p2x, p2y, p2z, 5)
	end
	
	if heapFillType ~= 0 then
		courseplay:debug(string.format("%s: heap with %s found",nameNum(vehicle),tostring(heapFillType)),10)
		return courseplay:getMode9HeapsMinMaxCoords(vehicle,heapFillType,p1x,p1y,p1z,p2x,p2y,p2z)
	else
		return
	end
	return false
end

function courseplay:getMode9HeapsMinMaxCoords(vehicle,heapFillType,p1x,p1y,p1z,p2x,p2y,p2z)

	--create temp node 
	local point = createTransformGroup("cpTempHeapFindingPoint");
	link(g_currentMission.terrainRootNode, point);

	-- Rotate it in the right direction
	local dx,_,dz, distance = courseplay:getWorldDirection(p1x,p1y,p1z,p2x,p2y,p2z);
	
	setTranslation(point,p1x,p1y,p1z);
	local yRot = Utils.getYRotationFromDirection(dx, dz);
	setRotation(point, 0, yRot, 0);

	--debug line vor search area to be sure, the point is set correctly
	vehicle.cp.tempMOde9PointX,vehicle.cp.tempMOde9PointY,vehicle.cp.tempMOde9PointZ = getWorldTranslation(point)
	vehicle.cp.tempMOde9PointX2,vehicle.cp.tempMOde9PointY2,vehicle.cp.tempMOde9PointZ2 = localToWorld(point,0,0,distance*2)
	
	-- move the line to find out the size of the heap
	
	--find maxX 
	local stepSize = 0.1
	local searchWidth = 0.1
	local maxX = 0
	local tempStartX, tempStartZ,tempHeightX,tempHeightZ = 0,0,0,0;
	for i=stepSize,250,stepSize do
		tempStartX,tempStartY,tempStartZ = localToWorld(point,i,0,0)
		tempHeightX,tempHeightY,tempHeightZ= localToWorld(point,i,0,distance*2)
		local fillType = TipUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
		--print(string.format("fillType:%s distance: %.1f",tostring(fillType),i))	
		if fillType ~= heapFillType then
			maxX = i-stepSize
			courseplay:debug("maxX= "..tostring(maxX),10)
			break
		end
	end
	
	--find minX 
	local minX = 0
	local tempStartX, tempStartZ,tempHeightX,tempHeightZ = 0,0,0,0;
	for i=stepSize,250,stepSize do
		tempStartX,tempStartY,tempStartZ = localToWorld(point,-i,0,0)
		tempHeightX,tempHeightY,tempHeightZ= localToWorld(point,-i,0,distance*2)
		local fillType = TipUtil.getFillTypeAtLine(tempStartX,tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
		--print(string.format("fillType:%s distance: %.1f",tostring(fillType),i))	
		if fillType ~= heapFillType then
			minX = i-stepSize
			courseplay:debug("minX= "..tostring(minX),10)
			break
		end
	end
	
	--find minZ and maxZ
	local foundHeap = false
	local minZ, maxZ = 0,0
	for i=0,250,stepSize do
		tempStartX,tempStartY,tempStartZ = localToWorld(point,maxX,0,i)
		tempHeightX,tempHeightY,tempHeightZ= localToWorld(point,-minX,0,i)
		local fillType = TipUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
		if not foundHeap then
			if fillType == heapFillType then
				foundHeap = true
				minZ = i-stepSize
				courseplay:debug("minZ= "..tostring(minZ),10)
			end
		else
			if fillType ~= heapFillType then
				maxZ = i-stepSize+1
				courseplay:debug("maxZ= "..tostring(maxZ),10)
				break
			end
		end	
	end
	
	--set found values into bunker table and return it
	local bunker = {}
	bunker.bunkerSiloArea = {}
	bunker.bunkerSiloArea.sx,_,bunker.bunkerSiloArea.sz = localToWorld(point,maxX,0,minZ);
	bunker.bunkerSiloArea.wx,_,bunker.bunkerSiloArea.wz = localToWorld(point,-minX,0,minZ)
	bunker.bunkerSiloArea.hx,_,bunker.bunkerSiloArea.hz = localToWorld(point,maxX,0,maxZ)
	bunker.type = "heap"

		
	-- Clean up the temporary node.
	unlink(point);
	delete(point);
	
	
	return bunker
end