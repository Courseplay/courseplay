-- inspired by fieldstatus of Alan R. (ls-uk.info: thebadtouch)
function courseplay:areaHasFruit(x, z, fruitType, widthX, widthZ)
	widthX = widthX or 0.5;
	widthZ = widthZ or 0.5;
	if not courseplay:isField(x, z, widthX, widthZ) then
		return false;
	end;

	local density = 0;
	if fruitType ~= nil then
		density = Utils.getFruitArea(fruitType, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ, true);
		if density > 0 then
			--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), 3)
			return true;
		end;
	else
		for i = 1, FruitUtil.NUM_FRUITTYPES do
			if i ~= FruitUtil.FRUITTYPE_GRASS then
				density = Utils.getFruitArea(i, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ, true);
				if density > 0 then
					--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), 3)
					return true;
				end;
			end;
		end;
	end;

	--courseplay:debug(string.format(" x: %d z %d - is really cut!", x, z ), 3)
	return false;
end;

function courseplay:isField(x, z, widthX, widthZ)
	widthX = widthX or 0.5;
	widthZ = widthZ or 0.5;
	local startWorldX, startWorldZ   = x, z;
	local widthWorldX, widthWorldZ   = x - widthX, z - widthZ;
	local heightWorldX, heightWorldZ = x + widthX, z + widthZ;

	local detailId = g_currentMission.terrainDetailId;
	local px,pz, pWidthX,pWidthZ, pHeightX,pHeightZ = Utils.getXZWidthAndHeight(detailId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
	setDensityCompareParams(detailId, 'greater', 0, 0, 0, 0);
	local _,area,totalArea = getDensityParallelogram(detailId, px, pz, pWidthX, pWidthZ, pHeightX, pHeightZ, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels);
	setDensityCompareParams(detailId, 'greater', -1);

	return area > 0;
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
		local rot = Utils.getYRotationFromDirection(dx, dz);
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
	-- print(string.format('hasLineFruit(): x1,z1=%s,%s, x2,z2=%s,%s, hx,hz=%s,%s', tostring(x1), tostring(z1), tostring(x2), tostring(z2), tostring(hx), tostring(hz)));

	if fixedFruitType then
		local density, total = Utils.getFruitArea(fixedFruitType, x1,z1, x2,z2, hx,hz, true);
		if density > 0 then
			return true, density, fixedFruitType, FruitUtil.fruitIndexToDesc[fixedFruitType].name;
		end;
		return false;
	end;

	for i = 1, FruitUtil.NUM_FRUITTYPES do
		if i ~= FruitUtil.FRUITTYPE_GRASS then
			local density, total = Utils.getFruitArea(i, x1,z1, x2,z2, hx,hz, true);
			if density > 0 then
				local fruitName = FruitUtil.fruitIndexToDesc[i].name;
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

	local detailId = g_currentMission.terrainDetailId;
	local px,pz, pWidthX,pWidthZ, pHeightX,pHeightZ = Utils.getXZWidthAndHeight(detailId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
	setDensityCompareParams(detailId, 'greater', 0, 0, 0, 0);
	local n,area,totalArea = getDensityParallelogram(detailId, px, pz, pWidthX, pWidthZ, pHeightX, pHeightZ, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels);
	setDensityCompareParams(detailId, 'greater', -1);

	local isField = area > 0 and area >= totalArea;
	courseplay:debug(string.format('isLineField(): x1,z1=%.2f,%.2f, x2,z2=%.2f,%.2f, hx,hz=%.2f,%.2f -> n=%s, area=%s, totalArea=%s -> return %s', x1, z1, x2, z2, hx, hz, tostring(n), tostring(area), tostring(totalArea), tostring(isField)), 4);

	return isField;
end;


function courseplay:check_for_fruit(vehicle, distance) --TODO (Jakob): this function isn't used anywhere anymore
	local x, y, z = localToWorld(vehicle.cp.DirectionNode, 0, 0, distance) --getWorldTranslation(combine.aiTreshingDirectionNode);

	local length = Utils.vector2Length(x, z);
	local aiThreshingDirectionX = x / length;
	local aiThreshingDirectionZ = z / length;

	local dirX, dirZ = aiThreshingDirectionX, aiThreshingDirectionZ;
	if dirX == nil or x == nil or dirZ == nil then
		return 0, 0
	end
	local sideX, sideZ = -dirZ, dirX;

	local threshWidth = 3

	local sideWatchDirOffset = -8
	local sideWatchDirSize = 3


	local lWidthX = x - sideX * 0.5 * threshWidth + dirX * sideWatchDirOffset;
	local lWidthZ = z - sideZ * 0.5 * threshWidth + dirZ * sideWatchDirOffset;
	local lStartX = lWidthX - sideX * 0.7 * threshWidth;
	local lStartZ = lWidthZ - sideZ * 0.7 * threshWidth;
	local lHeightX = lStartX + dirX * sideWatchDirSize;
	local lHeightZ = lStartZ + dirZ * sideWatchDirSize;

	local rWidthX = x + sideX * 0.5 * threshWidth + dirX * sideWatchDirOffset;
	local rWidthZ = z + sideZ * 0.5 * threshWidth + dirZ * sideWatchDirOffset;
	local rStartX = rWidthX + sideX * 0.7 * threshWidth;
	local rStartZ = rWidthZ + sideZ * 0.7 * threshWidth;
	local rHeightX = rStartX + dirX * sideWatchDirSize;
	local rHeightZ = rStartZ + dirZ * sideWatchDirSize;
	local leftFruit = 0
	local rightFruit = 0

	for i = 1, FruitUtil.NUM_FRUITTYPES do
		if i ~= FruitUtil.FRUITTYPE_GRASS then
			leftFruit = leftFruit + Utils.getFruitArea(i, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ); -- TODO: add "true" to allow preparingFruit (potatoes, sugarBeet) ?

			rightFruit = rightFruit + Utils.getFruitArea(i, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ); -- TODO: add "true" to allow preparingFruit (potatoes, sugarBeet) ?
		end
	end

	return leftFruit, rightFruit;
end


function courseplay:sideToDrive(vehicle, combine, distance, switchSide)
	local tractor = combine;
	if courseplay:isAttachedCombine(combine) then
		tractor = combine.attacherVehicle;
	end;

	-- COMBINE DIRECTION
	local x, y, z = localToWorld(tractor.cp.DirectionNode, 0, 0, distance - 5);
	local dirX, dirZ = combine.aiThreshingDirectionX, combine.aiThreshingDirectionZ;
	if (not (combine.isAIThreshing or combine:getIsCourseplayDriving())) or combine.aiThreshingDirectionX == nil or combine.aiThreshingDirectionZ == nil or (combine.acParameters ~= nil and combine.acParameters.enabled and combine.isHired) then
		local node = combine.cp.DirectionNode or combine.rootNode;
		local dx,_,dz = localDirectionToWorld(node, 0, 0, 2);
		local length = Utils.vector2Length(dx,dz);
		dirX = dx/length;
		dirZ = dz/length;
	end;

	local sideX, sideZ = -dirZ, dirX;
	local sideWatchDirOffset = Utils.getNoNil(combine.sideWatchDirOffset, -8);
	local sideWatchDirSize = Utils.getNoNil(combine.sideWatchDirSize, 3); -- TODO (Jakob): default AICombine value is 8
	local selfSideWatchDirSize = Utils.getNoNil(vehicle.sideWatchDirSize, 3); -- TODO (Jakob): default AITractor value is 7

	local threshWidth = Utils.getNoNil(combine.cp.workWidth,10)  
	courseplay:debug(string.format("%s:courseplay:sideToDrive: threshWidth: %.2f", nameNum(combine), threshWidth), 4);
	local lWidthX = x - sideX * 0.5 * threshWidth + dirX * sideWatchDirOffset;
	local lWidthZ = z - sideZ * 0.5 * threshWidth + dirZ * sideWatchDirOffset;
	local lStartX = lWidthX - sideX * 0.7 * threshWidth;
	local lStartZ = lWidthZ - sideZ * 0.7 * threshWidth;
	local lHeightX = lStartX + dirX * sideWatchDirSize;
	local lHeightZ = lStartZ + dirZ * sideWatchDirSize;

	local rWidthX = x + sideX * 0.5 * threshWidth + dirX * sideWatchDirOffset;
	local rWidthZ = z + sideZ * 0.5 * threshWidth + dirZ * sideWatchDirOffset;
	local rStartX = rWidthX + sideX * 0.7 * threshWidth;
	local rStartZ = rWidthZ + sideZ * 0.7 * threshWidth;
	local rHeightX = rStartX + dirX * selfSideWatchDirSize;
	local rHeightZ = rStartZ + dirZ * selfSideWatchDirSize;

	-- TODO (Jakob): the last "true" means we're also including preparing fruit. Should this only be done if the combine has indeed a fruit preparer?
	local leftFruit = Utils.getFruitArea(combine.lastValidInputFruitType, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ, true);
	local rightFruit = Utils.getFruitArea(combine.lastValidInputFruitType, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ, true);

	courseplay:debug(string.format("%s:courseplay:sideToDrive: fruit: left %f, right %f", nameNum(combine), leftFruit, rightFruit), 4);
	
	-- AUTO COMBINE
	if combine.acParameters ~= nil and combine.acParameters.enabled and combine.isHired then -- autoCombine
		courseplay:debug(string.format("%s:courseplay:sideToDrive: is AutoCombine", nameNum(combine)), 4);
		if not combine.acParameters.upNDown then
			if combine.acParameters.leftAreaActive then
				leftFruit,rightFruit = 0, 100; --fruitSide = "right"
			else
				leftFruit,rightFruit = 100, 0; --fruitSide = "left"
			end
		else
			if combine.acTurnStage == 0 or (combine.acTurnStage >= 20 and combine.acTurnStage <= 22) then
				if combine.acParameters.leftAreaActive then 
					leftFruit,rightFruit = 0, 100; --fruitSide = "right"
				else
					leftFruit,rightFruit = 100, 0; --fruitSide = "left"
				end
			end
		end
	
	-- AI HELPER COMBINE
	elseif combine.isAIThreshing then 
		courseplay:debug(string.format("%s:courseplay:sideToDrive: is AIThreshing", nameNum(combine)), 4);
		-- Fruit side switch at end of field line
		if (not combine.waitingForDischarge and combine.waitForTurnTime > combine.timer) or (combine.turnStage == 1) then
			local tempFruit = leftFruit;
			leftFruit = rightFruit;
			rightFruit = tempFruit;
		end;
	
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