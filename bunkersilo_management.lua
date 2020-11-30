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