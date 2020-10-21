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
			local rotDir = MathUtil.sign(targetRot - curRot);
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
					SpecializationUtil.raiseEvent(vehicle, "onMovingToolChanged", mt, mt.rotSpeed, dt)
					changed = true;
				end;
			end;

			-- TRANSLATION
			if mt.transSpeed ~= nil then --only change values if transSpeed actually exists
				-- local transSpeed = mt.transSpeed * dt;
				local transDir = MathUtil.sign(targetTrans - curTrans);
				if mt.node and mt.transMin and mt.transMax and transDir and transDir ~= 0 then
					local transChange = math.min(mt.transSpeed, 0.001) * dt; -- maximum: 1mm/ms (1m/s)
					newTrans = MathUtil.clamp(curTrans + (transChange * transDir), mt.transMin, mt.transMax);
					if (transDir == 1 and newTrans > targetTrans) or (transDir == -1 and newTrans < targetTrans) then
						newTrans = targetTrans;
					end;
					if newTrans ~= curTrans and newTrans >= mt.transMin and newTrans <= mt.transMax then
						--courseplay:debug(string.format('%s: movingTool %d: curTrans=%.5f, targetTrans=%.5f -> newTrans=%.5f', nameNum(vehicle), i, curTrans, targetTrans, newTrans), 10);
						mt.curTrans[transAxis] = newTrans;
						setTranslation(mt.node, unpack(mt.curTrans));
						SpecializationUtil.raiseEvent(vehicle, "onMovingToolChanged", mt, mt.transSpeed, dt)
						changed = true;
					end;
				end;
			end;

			-- DIRTY FLAGS (movingTool)
			-- TODO: check if Cylindered.setMovingToolDirty() is better here
			if changed then
				if vehicle.cp.attachedFrontLoader ~= nil then
					Cylindered.setDirty(vehicle.cp.attachedFrontLoader, mt);
					mt.networkPositionIsDirty = true
					vehicle.cp.attachedFrontLoader:raiseDirtyFlags(vehicle.cp.attachedFrontLoader.spec_cylindered.cylinderedDirtyFlag);
				else
					Cylindered.setDirty(mtMainObject, mt);
				end	
				mt.networkPositionIsDirty = true
				mtMainObject:raiseDirtyFlags(mtMainObject.spec_cylindered.cylinderedDirtyFlag);
				mtMainObject:raiseDirtyFlags(mt.dirtyFlag)
			end;

		end;
	end;

	-- DIRTY FLAGS (movingParts)
	if changed then
		if vehicle.spec_cylindered.activeDirtyMovingParts then
			for _, part in pairs(vehicle.spec_cylindered.activeDirtyMovingParts) do
				Cylindered.setDirty(vehicle, part);
			end;
		end;
		if vehicle.cp.shovel and vehicle.cp.shovel.spec_cylindered.activeDirtyMovingParts then
			for _, part in pairs(vehicle.cp.shovel.spec_cylindered.activeDirtyMovingParts) do
				Cylindered.setDirty(vehicle.cp.shovel, part);
			end;
		end;
	end;
	return not changed;
end;

function courseplay:getMovingTools(vehicle)
	local primaryMovingTools, secondaryMovingTools;
	local frontLoader, shovel ,pipe = 0, 0;
	local vAI = vehicle:getAttachedImplements()
	for i=1, #(vAI) do
		if vAI[i].object.cp.hasSpecializationShovel or vAI[i].object.spec_dynamicMountAttacher then
			shovel = i;
		elseif courseplay:isFrontloader(vAI[i].object) then
			frontLoader = i;
		else
			pipe = i;
		end;
	end;
	
	courseplay:debug(('%s: getMovingTools(): frontLoader index=%d, shovel index=%d'):format(nameNum(vehicle), frontLoader, shovel), 10);

	if shovel ~= 0 then
		primaryMovingTools = vehicle.spec_cylindered.movingTools;
		secondaryMovingTools = vAI[shovel].object.spec_cylindered.movingTools;
		vehicle.cp.shovel = vAI[shovel].object;

		courseplay:debug(('    [1] primaryMt=%s, secondaryMt=%s, shovel=%s'):format(nameNum(vehicle), nameNum(vAI[shovel].object), nameNum(vehicle.cp.shovel)), 10);
	elseif frontLoader ~= 0 then
		local object = vAI[frontLoader].object;
		vehicle.cp.attachedFrontLoader = object
		primaryMovingTools = object.spec_cylindered.movingTools;
		local oAI = object:getAttachedImplements()
		if oAI[1] ~= nil then
			secondaryMovingTools = oAI[1].object.spec_cylindered.movingTools;
			vehicle.cp.shovel = oAI[1].object;
			courseplay:debug(('    [2] attachedFrontLoader=%s, primaryMt=%s, secondaryMt=%s, shovel=%s'):format(nameNum(object), nameNum(object), nameNum(object:getAttachedImplements()[1].object), nameNum(vehicle.cp.shovel)), 10);
		end;
		
	elseif pipe ~= 0 then
		primaryMovingTools = vAI[i].object.spec_cylindered.movingTools;
	else
		primaryMovingTools = vehicle.spec_cylindered.movingTools;
		vehicle.cp.shovel = vehicle;

		courseplay:debug(('    [3] primaryMt=%s, shovel=%s'):format(nameNum(vehicle), nameNum(vehicle.cp.shovel)), 10);
	end;

	return primaryMovingTools, secondaryMovingTools;
end;



function courseplay:getMode9TargetBunkerSilo(vehicle,forcedPoint)
	local pointIndex = 0
	if forcedPoint then
		 pointIndex = forcedPoint;
	else
		pointIndex = vehicle.cp.driver.shovelFillStartPoint+2
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
			if MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z) then
				return bunker
			end
		end
	end
	
	--it's not a bunkersSilo, try to find a heap
	local heapFillType = 0
	if vehicle.cp.mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY then
		p1x,p1z = vehicle.Waypoints[vehicle.cp.driver.shovelFillStartPoint].cx,vehicle.Waypoints[vehicle.cp.driver.shovelFillStartPoint].cz;
		p2x,p2z = vehicle.Waypoints[vehicle.cp.driver.shovelFillEndPoint].cx,vehicle.Waypoints[vehicle.cp.driver.shovelFillEndPoint].cz;
		p1y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1x, 1, p1z);
		p2y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p2x, 1, p2z);
		heapFillType = DensityMapHeightUtil.getFillTypeAtLine(p1x, p1y, p1z, p2x, p2y, p2z, 5)
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
	local yRot = MathUtil.getYRotationFromDirection(dx, dz);
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
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
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
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX,tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
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
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
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