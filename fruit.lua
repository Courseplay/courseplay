-- inspired by fieldstatus of Alan R. (ls-uk.info: thebadtouch)
function courseplay:areaHasFruit(x, z, fruitType, widthX, widthZ)
	widthX = widthX or 0.5;
	widthZ = widthZ or 0.5;
	if not courseplay:isField(x, z, widthX, widthZ) then
		return false;
	end;

	local density = 0;
	local maxDensity = 0;
	local maxFruitType = 0
	if fruitType ~= nil and fruitType ~= FruitType.UNKNOWN then
		local minHarvestable, maxHarvestable = 1, fruitType.numGrowthStates
	
		density = FieldUtil.getFruitArea(x, z, x - widthX, z - widthZ, x + widthX, z + widthZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
		if density > 0 then
			--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), 3)
			return true,fruitType;
		end;
	else
		for i = 1, #g_fruitTypeManager.fruitTypes do
			if i ~= g_fruitTypeManager.nameToIndex['GRASS'] and i ~= g_fruitTypeManager.nameToIndex['DRYGRASS'] then 
				local fruitType = g_fruitTypeManager.fruitTypes[i]
				local minHarvestable, maxHarvestable = 1, fruitType.numGrowthStates
				--function FieldUtil.getFruitArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, terrainDetailRequiredValueRanges, terrainDetailProhibitValueRanges, requiredFruitType, requiredMinGrowthState, requiredMaxGrowthState, prohibitedFruitType, prohibitedMinGrowthState, prohibitedMaxGrowthState, useWindrowed
				density,totalArea = FieldUtil.getFruitArea(x, z, x - widthX, z - widthZ, x + widthX, z + widthZ, {}, {}, i, minHarvestable , maxHarvestable, 0, 0, 0,false);
				if density > maxDensity then
					maxDensity = density
					maxFruitType = i
				end
			end;
		end;
		if maxDensity > 0 then
			--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), 3)
			--print("areaHasFruit: return "..tostring(maxFruitType))
			return true, maxFruitType;
		end;
	end;

	--courseplay:debug(string.format(" x: %d z %d - is really cut!", x, z ), 3)
	return false;
end;

function courseplay:initailzeFieldMod()
    --print("courseplay:initailzeFieldMod()")
	self.fieldMod = {}
    self.fieldMod.modifier = DensityMapModifier:new(g_currentMission.terrainDetailId, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels)
    self.fieldMod.filter = DensityMapFilter:new(self.fieldMod.modifier)
end

function courseplay:isField(x, z, widthX, widthZ)
    --print(string.format("running courseplay:isField(%s, %s, %s, %s)",tostring(x),tostring(z),tostring(widthX),tostring(widthZ)))
	widthX = widthX or 0.5
    widthZ = widthZ or 0.5
	local startWorldX, startWorldZ   = x, z
	local widthWorldX, widthWorldZ   = x - widthX, z - widthZ
	local heightWorldX, heightWorldZ = x + widthX, z + widthZ
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, startWorldX, 1, startWorldZ)

	--cpDebug:drawLine(startWorldX,y+1,startWorldZ, 0, 100, 0, widthWorldX,y+1,widthWorldZ)
	--cpDebug:drawLine(widthWorldX,y+1,widthWorldZ, 0, 100, 0, heightWorldX,y+1,heightWorldZ)
	--cpDebug:drawLine(heightWorldX,y+1,heightWorldZ, 0, 100, 0, startWorldX,y+1,startWorldZ)

    self.fieldMod.modifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, "ppp")
    self.fieldMod.filter:setValueCompareParams("greater", 0)

    local _, area, totalArea = self.fieldMod.modifier:executeGet( self.fieldMod.filter)
	local isField = area > 0
	return  isField
end


function courseplay:getLineHxHz(node, x1, z1, x2, z2)
	if node == nil and (x1 == nil or z1 == nil or x2 == nil and z2 == nil) then return; end;

	local createTg = node == nil;
	if createTg then
		node = createTransformGroup('cpFruitLineNode');
		link(getRootNode(), node);
		setTranslation(node, x1, 0, z1);

		-- set rotation
		local dx, _, dz, _ = courseplay:getWorldDirection(x1, 0, z1, x2, 0, z2);
		local rot = MathUtil.getYRotationFromDirection(dx, dz);
		setRotation(node, 0, rot, 0);
	end;

	-- get hx, hz
	--[[
	local lineWidth = 2; -- in metres
	local dlx, _, dlz = worldToLocal(node, x2, 0, z2);
	local dnx, dnz = dlz * -1, dlx;
	local angle = math.atan(dnz / dnx);
	dnx = math.cos(angle) * -lineWidth;
	dnz = math.sin(angle) * -lineWidth;
	local hx, _, hz = localToWorld(node, dnx, 0, dnz);
	]]
	local hx, _, hz = localToWorld(node, -2, 0, 0);

	if createTg then
		unlink(node);
		delete(node);
	end;

	-- courseplay:debug(string.format('getLineHxHz(..., [x1] %.1f, [z1] %.1f, [x2] %.1f, [z2] %.1f): hxTest,hzTest=%.3f,%.3f, hx,hz=%.3f,%.3f', x1, z1, x2, z2, hxTest, hzTest, hx, hz), 4);

	return hx, hz;
end;

function courseplay:hasLineFruit(node, x1, z1, x2, z2, fixedFruitType)
	if node and (x1 == nil or z1 == nil) then
		x1, _, z1 = getWorldTranslation(node);
	end;
	local hx, hz = courseplay:getLineHxHz(node, x1,z1, x2,z2);
	if hx == nil or hz == nil then return; end;
	print(string.format('hasLineFruit(): x1,z1=%s,%s, x2,z2=%s,%s, hx,hz=%s,%s', tostring(x1), tostring(z1), tostring(x2), tostring(z2), tostring(hx), tostring(hz)));

	if fixedFruitType then
		local minHarvestable, maxHarvestable = 1, fruitType.numGrowthStates
		local density, total = FieldUtil.getFruitArea(x1, z1, x2, z2, hx, hz, {}, {}, fixedFruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
		if density > 0 then
			return true, density, fixedFruitType, g_fruitTypeManager.indexToFruitType[fixedFruitType].name --IndexToDesc[fixedFruitType].name; this might wrong conversion
		end;
		return false;
	end;

	for i = 1, #g_fruitTypeManager.fruitTypes do
		if i ~= g_fruitTypeManager.nameToIndex['GRASS'] and i ~= g_fruitTypeManager.nameToIndex['DRYGRASS'] then 
			local fruitType = g_fruitTypeManager.fruitTypes[i]
			local minHarvestable, maxHarvestable = 1, fruitType.numGrowthStates
			local density, total = FieldUtil.getFruitArea(x1, z1, x2, z2, hx, hz, {}, {},  i, minHarvestable , maxHarvestable, 0, 0, 0,false);
			if density > 0 then
				local fruitName = 'test' --FruitTypeManager:getFruitTypeNameByIndex(i) -- FruitUtil.fruitIndexToDesc[i].name;  this might wrong conversion
				courseplay:debug(string.format('hasLineFruit(): fruitType %d (%s): density=%s (total=%s)', i, tostring(fruitName), tostring(density), tostring(total)), 4);
				return true, density, i, fruitName;
			end;
		end;
	end;

	return false;
end;

function courseplay:isLineField(node, x1, z1, x2, z2)
	
	if node and (x1 == nil or z1 == nil) then
		x1, _, z1 = getWorldTranslation(node);
	end;
	local hx, hz = courseplay:getLineHxHz(node, x1, z1, x2, z2);
	if hx == nil or hz == nil then return; end;
	-- courseplay:debug(string.format('isLineField(): x1,z1=%s,%s, x2,z2=%s,%s, hx,hz=%s,%s', tostring(x1), tostring(z1), tostring(x2), tostring(z2), tostring(hx), tostring(hz)), 4);

	local startWorldX, startWorldZ   = x1, z1;
	local widthWorldX, widthWorldZ   = x2, z2;
	local heightWorldX, heightWorldZ = hx, hz;

	courseplay.fields.modifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, "ppp")
	local n,area,totalArea = courseplay.fields.modifier:executeGet(courseplay.fields.filter) -- get all where is field
	local isField = area > 0 and area >= totalArea;
	courseplay:debug(string.format('isLineField(): x1,z1=%.2f,%.2f, x2,z2=%.2f,%.2f, hx,hz=%.2f,%.2f -> n=%s, area=%s, totalArea=%s -> return %s', x1, z1, x2, z2, hx, hz, tostring(n), tostring(area), tostring(totalArea), tostring(isField)), 4);

	return isField;
end;

function courseplay:sideToDrive(vehicle, combine, distance, switchSide)
	local tractor = combine;
	if courseplay:isAttachedCombine(combine) then
		tractor = combine:getAttacherVehicle();
	end;

	-- COMBINE DIRECTION
	local x, y, z = localToWorld(tractor.cp.DirectionNode, 0, 0, distance);
	local node = combine.cp.DirectionNode or combine.rootNode;
	local dx,_,dz = localDirectionToWorld(node, 0, 0, 2);
	local length = MathUtil.vector2Length(dx,dz);
	local dirX = dx/length;
	local dirZ = dz/length;
	local sideX, sideZ = -dirZ, dirX;
	courseplay:calculateWorkWidth(tractor,true)
	local threshWidth = Utils.getNoNil(tractor.cp.workWidth,10)  
	courseplay:debug(string.format("%s:courseplay:sideToDrive: threshWidth: %.2f", nameNum(tractor), threshWidth), 4);
	local lStartX = x - sideX * 0.6 * threshWidth 
	local lStartZ = z - sideZ * 0.6 * threshWidth
	local lWidthX = lStartX - sideX * 0.7 * threshWidth;
	local lWidthZ = lStartZ - sideZ * 0.7 * threshWidth;
	local lHeightX = lStartX + dirX * 0.5 * threshWidth;
	local lHeightZ = lStartZ + dirZ * 0.5 * threshWidth;
	local rStartX = x + sideX * 0.6 * threshWidth 
	local rStartZ = z + sideZ * 0.6 * threshWidth
	local rWidthX = rStartX + sideX * 0.7 * threshWidth;
	local rWidthZ = rStartZ + sideZ * 0.7 * threshWidth;
	local rHeightX = rStartX + dirX * 0.5 * threshWidth;
	local rHeightZ = rStartZ + dirZ * 0.5 * threshWidth;
	local fruitType = combine.spec_combine.lastValidInputFruitType
	local hasFruit = false
	if fruitType == nil or fruitType == 0 then
		hasFruit,fruitType = courseplay:areaHasFruit(x, z, nil, threshWidth, threshWidth)
	end
	local minHarvestable, maxHarvestable = 1,1
	if hasFruit then
		maxHarvestable = g_fruitTypeManager.fruitTypes[fruitType].numGrowthStates
	else
		fruitType = 0 
	end
	local leftFruit, totalArealeft = FieldUtil.getFruitArea(lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
	local rightFruit, totalArearight = FieldUtil.getFruitArea(rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
	courseplay:debug(string.format("%s:courseplay:sideToDrive: fruit(%s): left %f, right %f", nameNum(combine),tostring(fruitType), leftFruit, rightFruit), 4);
	
	-- AUTO COMBINE
	if combine.acParameters ~= nil and combine.acParameters.enabled and combine.isHired and not combine.cp.isDriving then -- autoCombine
		courseplay:debug(string.format("%s:courseplay:sideToDrive: is AutoCombine", nameNum(combine)), 4);
		if not combine.acParameters.upNDown then
			if combine.acParameters.leftAreaActive then
				leftFruit,rightFruit = 0, 100; --fruitSide = "right"
			else
				leftFruit,rightFruit = 100, 0; --fruitSide = "left"
			end
		else
			if combine.acTurnStage == 0 then
				if combine.acParameters.leftAreaActive then 
					leftFruit,rightFruit = 0, 100; --fruitSide = "right"
				else
					leftFruit,rightFruit = 100, 0; --fruitSide = "left"
				end
			else
				if combine.acParameters.leftAreaActive then
					leftFruit,rightFruit = 100, 0; --fruitSide = "left"
				else
					leftFruit,rightFruit = 0, 100; --fruitSide = "right"
				end
			end;
		end
	
	-- AI HELPER COMBINE
	elseif combine.aiIsStarted then 
		courseplay:debug(string.format("%s:courseplay:sideToDrive: is AIThreshing", nameNum(combine)), 4);
		
		-- COURSEPLAY
	elseif tractor:getIsCourseplayDriving() then
		courseplay:debug(string.format("%s:courseplay:sideToDrive: is Courseplayer", nameNum(combine)), 4);
		local ridgeMarker = 0;
		local wayPoint = tractor.cp.waypointIndex;
		if tractor.cp.turnStage > 0 then
   			switchSide = true;
  		end;
		if not switchSide then
			wayPoint = wayPoint + 2;
		else
			wayPoint = wayPoint - 2;
		end;
		if tractor.Waypoints ~= nil and wayPoint ~= nil and tractor.Waypoints[wayPoint] ~= nil then
			ridgeMarker = Utils.getNoNil(tractor.Waypoints[wayPoint].ridgeMarker, 0);
		end;
		if ridgeMarker == 1 then
			leftFruit, rightFruit  = 100, 0;
		elseif ridgeMarker == 2 then
			leftFruit, rightFruit  = 0, 100;
		end;
	end;
	
	
	courseplay:debug(string.format("%s:courseplay:sideToDrive: fruit after check: left %f, right %f", nameNum(combine), leftFruit, rightFruit), 4);
	local fruitSide = 'none';
	if leftFruit > rightFruit then
		fruitSide = 'left';
	elseif leftFruit < rightFruit then
		fruitSide = 'right';
	end;

	if combine.cp.forcedSide == nil then
		if not switchSide then
			if fruitSide == 'right' then
				vehicle.sideToDrive = 'left';
			elseif fruitSide == 'left' then
				vehicle.sideToDrive = 'right';
			else
				vehicle.sideToDrive = nil;
			end;
		else
			if fruitSide == 'right' then
				vehicle.sideToDrive = 'right';
			elseif fruitSide == 'left' then
				vehicle.sideToDrive = 'left';
			end;
		end;
	elseif combine.cp.forcedSide == 'right' then
		vehicle.sideToDrive = 'right';
	else
		vehicle.sideToDrive = 'left';
	end;
	courseplay:debug(string.format("%s:courseplay:sideToDrive: return fruitside %s", nameNum(combine), fruitSide), 4);
	return fruitSide;
end