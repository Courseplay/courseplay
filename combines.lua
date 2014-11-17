local curFile = 'combines.lua';

function courseplay:getAllCombines()
	local combines = {}
	for _, vehicle in pairs(g_currentMission.vehicles) do --TODO (Jakob): create courseplay combine table, add each combine during load()
		if vehicle.cp == nil then
			vehicle.cp = {};
			courseplay:setNameVariable(vehicle);
		end;
		
		if vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or courseplay:isAttachedCombine(vehicle) then
			if not courseplay:isAttachedCombine(vehicle) or (courseplay:isAttachedCombine(vehicle) and vehicle.attacherVehicle ~= nil and not vehicle.cp.isPoettingerMex6) then --TODO (Jakob): re-check Pöttinger Mex 6 support
				table.insert(combines, vehicle);
			end;
		end;
	end;

	return combines;
end;


-- find combines on the same field (texture)
function courseplay:updateReachableCombines(vehicle)
	courseplay:debug(string.format("%s: updateReachableCombines()", nameNum(vehicle)), 4);

	vehicle.cp.reachableCombines = {};

	if not vehicle.cp.searchCombineAutomatically and vehicle.cp.savedCombine then
		courseplay:debug(nameNum(vehicle)..": combine is manually set", 4);
		table.insert(vehicle.cp.reachableCombines, vehicle.cp.savedCombine);
		return;
	end;

	local allCombines = courseplay:getAllCombines();
	courseplay:debug(string.format("%s: combines found: %d", nameNum(vehicle), #(allCombines)), 4)

	--DEV: check field pairing using fieldDefs
	local combineFound;
	if courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineOnField > 0 then
		local fieldData = courseplay.fields.fieldData[vehicle.cp.searchCombineOnField];
		for k,combine in pairs(allCombines) do
			local combineX,_,combineZ = getWorldTranslation(combine.rootNode);
			if combineX >= fieldData.dimensions.minX and combineX <= fieldData.dimensions.maxX and combineZ >= fieldData.dimensions.minZ and combineZ <= fieldData.dimensions.maxZ then
				courseplay:debug(string.format('%s: combine %q is in field %d\'s dimensions', nameNum(vehicle), nameNum(combine), vehicle.cp.searchCombineOnField), 4);
				-- if courseplay:pointInPolygonV2b(fieldData.points, combineX, combineZ, true) then
				local _, pointInPoly, _, _ = courseplay.fields:getPolygonData(fieldData.points, combineX, combineZ, true, true, true);
				if pointInPoly then
					courseplay:debug(string.format('\tcombine is in field %d\'s poly', vehicle.cp.searchCombineOnField), 4);
					courseplay:debug(string.format('%s: adding %q to reachableCombines table', nameNum(vehicle), nameNum(combine)), 4);
					table.insert(vehicle.cp.reachableCombines, combine);
					combineFound = true;
				end;
			end;
		end;
		courseplay:debug(string.format("%s: combines reachable: %d ", nameNum(vehicle), #(vehicle.cp.reachableCombines)), 4);
		if combineFound then
			return;
		end;
	end;

	-- go through found combines
	local lx, ly, lz;
	for k, combine in pairs(allCombines) do
		lx, ly, lz = getWorldTranslation(combine.rootNode)

		if courseplay:isLineField(vehicle.cp.DirectionNode, nil, nil, lx, lz) then
			courseplay:debug(string.format('%s: adding %q to reachableCombines table', nameNum(vehicle), nameNum(combine)), 4);
			table.insert(vehicle.cp.reachableCombines, combine);
		end;
	end;

	courseplay:debug(string.format("%s: combines reachable: %d ", nameNum(vehicle), #(vehicle.cp.reachableCombines)), 4)
end;


function courseplay:registerAtCombine(vehicle, combine)
	if combine.cp == nil then
		combine.cp = {};
	end;
	courseplay:debug(string.format("%s: registering at combine %s", nameNum(vehicle), tostring(combine.name)), 4)
	--courseplay:debug(tableShow(combine, tostring(combine.name), 4), 4)
	local numAllowedCourseplayers = 1
	vehicle.cp.calculatedCourseToCombine = false
	if combine.courseplayers == nil then
		combine.courseplayers = {};
	end;
	if combine.cp == nil then
		combine.cp = {};
	end;

	if combine.cp.isChopper or combine.cp.isSugarBeetLoader then
		numAllowedCourseplayers = courseplay.isDeveloper and 4 or 2;
	else
		
		if vehicle.cp.realisticDriving then
			if combine.cp.wantsCourseplayer == true or combine.fillLevel == combine.capacity then

			else
				-- force unload when combine is full
				-- is the pipe on the correct side?
				if combine.turnStage == 1 or combine.turnStage == 2 or combine.cp.turnStage ~= 0 then
					courseplay:debug(nameNum(vehicle)..": combine is turning -> don't register tractor",4)
					return false
				end
				local fruitSide = courseplay:sideToDrive(vehicle, combine, -10)
				if fruitSide == "none" then
					courseplay:debug(nameNum(vehicle)..": fruitSide is none -> try again with offset 0",4)
					fruitSide = courseplay:sideToDrive(vehicle, combine, 0)
				end
				courseplay:debug(nameNum(vehicle)..": courseplay:sideToDrive = "..tostring(fruitSide),4)
				
				if combine.cp.pipeSide == nil then
					courseplay:getCombinesPipeSide(combine)
				end				
				
				local pipeIsInFruit = (combine.cp.pipeSide == 1 and fruitSide == "left") or (combine.cp.pipeSide == -1 and fruitSide == "right")
				if pipeIsInFruit then
					courseplay:debug(nameNum(vehicle)..": path finding active and pipe in fruit -> don't register tractor",4)
					return false
				end
			end
		end
	end

	if #(combine.courseplayers) == numAllowedCourseplayers then
		courseplay:debug(string.format("%s (id %s): combine (id %s) is already registered", nameNum(vehicle), tostring(vehicle.id), tostring(combine.id)), 4);
		return false
	end

	--THOMAS' best_combine START
	if combine.cp.isCombine or (courseplay:isAttachedCombine(combine) and not courseplay:isSpecialChopper(combine)) then
		if combine.cp.driverPriorityUseFillLevel then
			local fillLevel = 0
			local vehicle_ID = 0
			for k, vehicle in pairs(courseplay.activeCoursePlayers) do
				if vehicle.cp.combineID ~= nil then
					if vehicle.cp.combineID == combine.id and vehicle.cp.activeCombine == nil then
						courseplay:debug(tostring(vehicle.id).." : cp.callCombineFillLevel:"..tostring(vehicle.cp.callCombineFillLevel).." for combine.id:"..tostring(combine.id), 4)
						if fillLevel <= vehicle.cp.callCombineFillLevel then
							fillLevel = math.min(vehicle.cp.callCombineFillLevel,0.1)
							vehicle_ID = vehicle.id
						end
					end
				end
			end
			if vehicle_ID ~= vehicle.id then
				courseplay:debug(nameNum(vehicle) .. " (id " .. tostring(vehicle.id) .. "): there's a tractor with more fillLevel that's trying to register: "..tostring(vehicle_ID), 4)
				return false
			else
				courseplay:debug(nameNum(vehicle) .. " (id " .. tostring(vehicle.id) .. "): it's my turn", 4);
			end
		else
			local distance = 9999999
			local vehicle_ID = 0
			for k, vehicle in pairs(courseplay.activeCoursePlayers) do
				if vehicle.cp.combineID ~= nil then
					--print(tostring(vehicle.name).." is calling for "..tostring(vehicle.cp.combineID).."  combine.id= "..tostring(combine.id))
					if vehicle.cp.combineID == combine.id and vehicle.cp.activeCombine == nil then
						courseplay:debug(('%s (%d): distanceToCombine=%s for combine.id %s'):format(nameNum(vehicle), vehicle.id, tostring(vehicle.cp.distanceToCombine), tostring(combine.id)), 4);
						if distance > vehicle.cp.distanceToCombine then
							distance = vehicle.cp.distanceToCombine
							vehicle_ID = vehicle.id
						end
					end
				end
			end
			if vehicle_ID ~= vehicle.id then
				courseplay:debug(nameNum(vehicle) .. " (id " .. tostring(vehicle.id) .. "): there's a closer tractor that's trying to register: "..tostring(vehicle_ID), 4)
				return false
			else
				courseplay:debug(nameNum(vehicle) .. " (id " .. tostring(vehicle.id) .. "): it's my turn", 4);
			end
		end
	end
	--THOMAS' best_combine END


	if #(combine.courseplayers) == numAllowedCourseplayers - 1 then
		local frontTractor = combine.courseplayers[numAllowedCourseplayers - 1];
		if frontTractor then
			local canFollowFrontTractor = frontTractor.cp.tipperFillLevelPct and frontTractor.cp.tipperFillLevelPct >= vehicle.cp.followAtFillLevel;
			courseplay:debug(string.format('%s: frontTractor (%s) fillLevelPct (%.1f), my followAtFillLevel=%d -> canFollowFrontTractor=%s', nameNum(vehicle), nameNum(frontTractor), frontTractor.cp.tipperFillLevelPct, vehicle.cp.followAtFillLevel, tostring(canFollowFrontTractor)), 4)
			if not canFollowFrontTractor then
				return false;
			end;
		end;
	end;

	-- you got a courseplayer, so stop yellin....
	if combine.cp.wantsCourseplayer ~= nil and combine.cp.wantsCourseplayer == true then
		combine.cp.wantsCourseplayer = false
	end

	courseplay:debug(string.format("%s is being checked in with %s", nameNum(vehicle), tostring(combine.name)), 4)
	combine.cp.isCheckedIn = 1;
	vehicle.cp.callCombineFillLevel = nil
	vehicle.cp.distanceToCombine = nil
	vehicle.cp.combineID = nil
	table.insert(combine.courseplayers, vehicle)
	vehicle.cp.positionWithCombine = #(combine.courseplayers)
	vehicle.cp.activeCombine = combine
	vehicle.cp.reachableCombines = {}
	
	courseplay:askForSpecialSettings(combine:getRootAttacherVehicle(), combine)

	--OFFSET
	combine.cp.pipeSide = 1;

	if vehicle.cp.combineOffsetAutoMode == true or vehicle.cp.combineOffset == 0 then
	  	if combine.cp.offset == nil then
			--print("no saved offset - initialise")
	   		courseplay:calculateInitialCombineOffset(vehicle, combine);
	  	else 
			--print("take the saved cp.offset")
	   		vehicle.cp.combineOffset = combine.cp.offset;
	  	end;
	end;
	--END OFFSET

	
	courseplay:addToCombinesIgnoreList(vehicle, combine);
	return true;
end





function courseplay:unregisterFromCombine(vehicle, combine)
	if vehicle.cp.activeCombine == nil or combine == nil then
		return true
	end

	vehicle.cp.calculatedCourseToCombine = false;
	courseplay:removeFromCombinesIgnoreList(vehicle, combine)
	combine.cp.isCheckedIn = nil;
	table.remove(combine.courseplayers, vehicle.cp.positionWithCombine)

	-- updating positions of tractors
	for k, tractor in pairs(combine.courseplayers) do
		tractor.cp.positionWithCombine = k
	end

	vehicle.allow_follwing = false
	vehicle.cp.positionWithCombine = nil
	vehicle.cp.lastActiveCombine = vehicle.cp.activeCombine
	vehicle.cp.activeCombine = nil
	courseplay:setModeState(vehicle, 1);


	if vehicle.trafficCollisionIgnoreList[combine.rootNode] == true then
		vehicle.trafficCollisionIgnoreList[combine.rootNode] = nil
	end
	
	if combine.acParameters ~= nil and combine.acParameters.enabled then
		if combine.cp.turnStage ~= 0 then
			combine.cp.turnStage = 0
		end
	end
	
	return true
end

function courseplay:addToCombinesIgnoreList(vehicle, combine)
	if combine == nil or combine.trafficCollisionIgnoreList == nil then
		return
	end
	if combine.trafficCollisionIgnoreList[vehicle.rootNode] == nil then
		combine.trafficCollisionIgnoreList[vehicle.rootNode] = true
	end
end


function courseplay:removeFromCombinesIgnoreList(vehicle, combine)
	if combine == nil or combine.trafficCollisionIgnoreList == nil then
		return
	end
	if combine.trafficCollisionIgnoreList[vehicle.rootNode] == true then
		combine.trafficCollisionIgnoreList[vehicle.rootNode] = nil
	end
end

function courseplay:calculateInitialCombineOffset(vehicle, combine) --TODO (Jakob): combine this fn and calculateCombineOffset() into one single function
	local curFile = "combines.lua";
	local leftMarker, rightMarker;
	local currentCutter;
	combine.cp.lmX, combine.cp.rmX = 1.5, -1.5;
	--print("run initial offset")
	if combine.attachedCutters ~= nil then
		for cutter, implement in pairs(combine.attachedCutters) do
			if cutter.aiLeftMarker ~= nil then
				if leftMarker == nil then
					leftMarker = cutter.aiLeftMarker;
					rightMarker = cutter.aiRightMarker;
					currentCutter = cutter;
					if leftMarker ~= nil and rightMarker ~= nil then
						local x, y, z = getWorldTranslation(currentCutter.rootNode);
						combine.cp.lmX, _, _ = worldToLocal(leftMarker, x, y, z);
						combine.cp.rmX, _, _ = worldToLocal(rightMarker, x, y, z);
					end;
				end;
			end;
		end;
	end;
	
	local prnX,prnY,prnZ, prnwX,prnwY,prnwZ, combineToPrnX,combineToPrnY,combineToPrnZ = 0,0,0, 0,0,0, 0,0,0;
	if combine.pipeRaycastNode ~= nil then
		prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.rootNode, prnwX, prnwY, prnwZ)
		if combine.cp.pipeSide == nil then
			courseplay:getCombinesPipeSide(combine)
		end
	end;

	--special combines
	local specialOffset, chopperOffset = courseplay:getSpecialCombineOffset(combine);
	if specialOffset then
		vehicle.cp.combineOffset = specialOffset;
		if chopperOffset then
			combine.cp.offset = chopperOffset;
		end;

	-- combine // combine_offset is in auto mode
	elseif not combine.cp.isChopper and combine.currentPipeState == 2 and combine.pipeRaycastNode ~= nil then -- pipe is extended
		vehicle.cp.combineOffset = combineToPrnX;
		courseplay:debug(string.format("%s(%i): %s @ %s: using combineToPrnX=%f, vehicle.cp.combineOffset=%f", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name), combineToPrnX, vehicle.cp.combineOffset), 4)
	elseif not combine.cp.isChopper and combine.pipeRaycastNode ~= nil then -- pipe is closed
		local raycastNodeParent = getParent(combine.pipeRaycastNode);
		if raycastNodeParent == combine.rootNode then -- pipeRaycastNode is direct child of combine.root
			vehicle.cp.combineOffset = prnX;
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.root > pipeRaycastNode / vehicle.cp.combineOffset=prnX=%f", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name), vehicle.cp.combineOffset), 4)
		elseif getParent(raycastNodeParent) == combine.rootNode then -- pipeRaycastNode is direct child of pipe is direct child of combine.root
			local pipeX, pipeY, pipeZ = getTranslation(raycastNodeParent)
			vehicle.cp.combineOffset = pipeX - prnZ;

			if prnZ == 0 or combine.cp.isGrimmeRootster604 then
				vehicle.cp.combineOffset = pipeX - prnY;
			end
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.root > pipe > pipeRaycastNode / vehicle.cp.combineOffset=pipeX-prnX=%f", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name), vehicle.cp.combineOffset), 4)
		elseif combineToPrnX > combine.cp.lmX then
			vehicle.cp.combineOffset = combineToPrnX + (5 * combine.cp.pipeSide);
			courseplay:debug(string.format("%s(%i): %s @ %s: using combineToPrnX=%f, vehicle.cp.combineOffset=%f", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name), combineToPrnX, vehicle.cp.combineOffset), 4)
		elseif combine.cp.lmX ~= nil then
			if combine.cp.lmX > 0 then -- use leftMarker
				vehicle.cp.combineOffset = combine.cp.lmX + 2.5;
				courseplay:debug(string.format("%s(%i): %s @ %s: using leftMarker+2.5, vehicle.cp.combineOffset=%f", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name), vehicle.cp.combineOffset), 4);
			end;
		else --BACKUP
			vehicle.cp.combineOffset = 8 * combine.cp.pipeSide;
		end;

	-- chopper
	elseif combine.cp.isChopper then
		courseplay:debug(string.format("%s(%i): %s @ %s: combine.cp.forcedSide=%s", curFile, debug.getinfo(1).currentline, nameNum(vehicle), combine.name, tostring(combine.cp.forcedSide)), 4);
		if combine.cp.forcedSide ~= nil then
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.cp.forcedSide=%s, going by cp.forcedSide", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name), combine.cp.forcedSide), 4);
			if combine.cp.forcedSide == "left" then
				vehicle.sideToDrive = "left";
				if combine.cp.lmX ~= nil then
					vehicle.cp.combineOffset = combine.cp.lmX + 2.5;
				else
					vehicle.cp.combineOffset = 8;
				end;
			elseif combine.cp.forcedSide == "right" then
				vehicle.sideToDrive = "right";
				if combine.cp.lmX ~= nil then
					vehicle.cp.combineOffset = (combine.cp.lmX + 2.5) * -1;
				else
					vehicle.cp.combineOffset = -8;
				end;
			end
		else
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.cp.forcedSide=%s, going by fruit", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name), tostring(combine.cp.forcedSide)), 4);
			local fruitSide = courseplay:sideToDrive(vehicle, combine, 5);
			if fruitSide == "right" then
				if combine.cp.lmX ~= nil then
					vehicle.cp.combineOffset = math.max(combine.cp.lmX + 2.5, 7);
				else --attached chopper
					vehicle.cp.combineOffset = 7;
				end;
			elseif fruitSide == "left" then
				if combine.cp.lmX ~= nil then
					vehicle.cp.combineOffset = math.max(combine.cp.lmX + 2.5, 7) * -1;
				else --attached chopper
					vehicle.cp.combineOffset = -3;
				end;
			elseif fruitSide == "none" then
				if combine.cp.lmX ~= nil then
					vehicle.cp.combineOffset = math.max(combine.cp.lmX + 2.5, 7);
				else --attached chopper
					vehicle.cp.combineOffset = 7;
				end;
			end
			--print("saving offset")
			combine.cp.offset = math.abs(vehicle.cp.combineOffset)
		end;
	end;
end;

function courseplay:getSpecialCombineOffset(combine)
	if combine.cp == nil then return nil; end;

	if combine.cp.isCaseIH7130 then
		return  8.0;
	elseif combine.cp.isCaseIH9230Crawler then
		return 11.5;
	elseif combine.cp.isNewHollandTC590 then
		return 5.1;
	elseif combine.cp.isNewHollandCR1090 then
		return 9.6;
	elseif combine.cp.isSampoRosenlewC6 then
		return 4.8;
	elseif combine.cp.isGrimmeRootster604 then
		return -4.3;
	elseif combine.cp.isSugarBeetLoader then
		local utwX,utwY,utwZ = getWorldTranslation(combine.unloadingTrigger.node);
		local combineToUtwX,_,_ = worldToLocal(combine.rootNode, utwX,utwY,utwZ);
		return combineToUtwX;
	end;

	return nil;
end;

function courseplay:getCombinesPipeSide(combine)
	local prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
	local combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.rootNode, prnwX, prnwY, prnwZ)

	if combineToPrnX >= 0 then
		combine.cp.pipeSide = 1; --left
		--print("pipe is left")
	else
		combine.cp.pipeSide = -1; --right
		--print("pipe is right")
	
	
	end;
end
