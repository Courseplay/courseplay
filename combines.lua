local curFile = 'combines.lua';
local _;
function courseplay:getAllCombines()
	local combines = {}
	for _, vehicle in pairs(courseplay.combines) do
		if vehicle.cp == nil then
			vehicle.cp = {};
			courseplay:setNameVariable(vehicle);
		end;

		if not courseplay:isAttachedCombine(vehicle) or (vehicle.attacherVehicle ~= nil and not vehicle.cp.isPoettingerMex6) then
			table.insert(combines, vehicle);
		end;
	end;

	return combines;
end;


-- find combines on the same field (texture)
function courseplay:updateReachableCombines(vehicle)
	courseplay:debug(string.format("%s: updateReachableCombines()", nameNum(vehicle)), 4);

	vehicle.cp.reachableCombines = {};

	if not vehicle.cp.searchCombineAutomatically then
		if not vehicle.cp.savedCombine then
			-- manual mode, but no combine selected -> empty list
			return;
		end;

		local combine = vehicle.cp.savedCombine
		if combine.cp and combine.cp.isCheckedIn and not combine.cp.isChopper then
			courseplay:debug(nameNum(vehicle)..": combine (id"..tostring(combine.id)..") is manually set, but already checked in", 4);
		else
			courseplay:debug(nameNum(vehicle)..": combine (id"..tostring(combine.id)..") is manually set", 4);
			table.insert(vehicle.cp.reachableCombines, combine);
		end
		return;			
	end;

	local allCombines = courseplay:getAllCombines();
	courseplay:debug(string.format("%s: combines found: %d", nameNum(vehicle), #(allCombines)), 4)

	--DEV: check field pairing using fieldDefs
	local combineFound;
	if courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineOnField > 0 then
		local fieldData = courseplay.fields.fieldData[vehicle.cp.searchCombineOnField];
		for k,combine in pairs(allCombines) do
			local combineX,_,combineZ = getWorldTranslation(combine.cp.DirectionNode or combine.rootNode);
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
		lx, ly, lz = getWorldTranslation(combine.cp.DirectionNode or combine.rootNode)

		if courseplay:isLineField(vehicle.cp.DirectionNode, nil, nil, lx, lz) then
			courseplay:debug(string.format('%s: adding %q to reachableCombines table', nameNum(vehicle), nameNum(combine)), 4);
			table.insert(vehicle.cp.reachableCombines, combine);
		end;
	end;

	courseplay:debug(string.format("%s: combines reachable: %d ", nameNum(vehicle), #(vehicle.cp.reachableCombines)), 4)
end;


function courseplay:registerAtCombine(callerVehicle, combine)
	if combine.cp == nil then
		combine.cp = {};
	end;
	courseplay:debug(string.format("%s: registering at combine %s", nameNum(callerVehicle), tostring(combine.name)), 4)
	--courseplay:debug(tableShow(combine, tostring(combine.name), 4), 4)
	local numAllowedCourseplayers = 1
	callerVehicle.cp.calculatedCourseToCombine = false
	if combine.courseplayers == nil then
		combine.courseplayers = {};
	end;
	if combine.cp == nil then
		combine.cp = {};
	end;

	if combine.cp.isChopper or combine.cp.isSugarBeetLoader then
		numAllowedCourseplayers = CpManager.isDeveloper and 4 or 2;
	else
		
		if callerVehicle.cp.realisticDriving then
			if combine.cp.wantsCourseplayer == true or combine.cp.fillLevel >= combine.cp.capacity then
				courseplay:debug(string.format("%s: combine.cp.wantsCourseplayer(%s) or combine.cp.fillLevel >= combine.cp.capacity (%s)",nameNum(callerVehicle),tostring(combine.cp.wantsCourseplayer),tostring(combine.cp.fillLevel >= 0.99*combine.cp.capacity)),4)
			else
				-- force unload when combine is full
				-- is the pipe on the correct side?
				if (combine.turnStage ~= nil and combine.turnStage > 0) or combine.cp.turnStage ~= 0 then
					courseplay:debug(nameNum(callerVehicle)..": combine is turning -> don't register tractor",4)
					return false
				end
				local fruitSide = courseplay:sideToDrive(callerVehicle, combine, -10)
				if fruitSide == "none" then
					courseplay:debug(nameNum(callerVehicle)..": fruitSide is none -> try again with offset 0",4)
					fruitSide = courseplay:sideToDrive(callerVehicle, combine, 0)
				end
				courseplay:debug(nameNum(callerVehicle)..": courseplay:sideToDrive = "..tostring(fruitSide),4)
				
				if combine.cp.pipeSide == nil then
					courseplay:getCombinesPipeSide(combine)
				end				
				
				local pipeIsInFruit = (combine.cp.pipeSide == 1 and fruitSide == "left") or (combine.cp.pipeSide == -1 and fruitSide == "right")
				if pipeIsInFruit then
					courseplay:debug(nameNum(callerVehicle)..": path finding active and pipe(pipeSide "..tostring(combine.cp.pipeSide)..") is in fruit -> don't register tractor",4)
					for k, reachableCombine in pairs(callerVehicle.cp.reachableCombines) do
						if reachableCombine == combine then
							courseplay:debug(nameNum(callerVehicle).."removing combine from reachable combines list",4)
							callerVehicle.cp.reachableCombines[k] = nil
						end
					end
					return false
				else
					courseplay:debug(nameNum(callerVehicle)..": path finding active and pipe(pipeSide "..tostring(combine.cp.pipeSide)..") is not in fruit -> register tractor",4)
				end
			end
		else
			courseplay:debug(nameNum(callerVehicle)..": path finding inactive",4) 
		end
	end

	if #(combine.courseplayers) == numAllowedCourseplayers then
		courseplay:debug(string.format("%s (id %s): combine (id %s) is already registered", nameNum(callerVehicle), tostring(callerVehicle.id), tostring(combine.id)), 4);
		return false
	end

	--THOMAS' best_combine START
	if combine.cp.isCombine or (courseplay:isAttachedCombine(combine) and not courseplay:isSpecialChopper(combine)) then
		if combine.cp.driverPriorityUseFillLevel then
			local fillLevel = 0
			local vehicle_ID = 0
			for k, vehicle in pairs(CpManager.activeCoursePlayers) do
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
			if vehicle_ID ~= callerVehicle.id then
				courseplay:debug(nameNum(callerVehicle) .. " (id " .. tostring(callerVehicle.id) .. "): there's a tractor with more fillLevel that's trying to register: "..tostring(vehicle_ID), 4)
				return false
			else
				courseplay:debug(nameNum(callerVehicle) .. " (id " .. tostring(callerVehicle.id) .. "): it's my turn", 4);
			end
		else
			local distance = math.huge
			local vehicle_ID = 0
			for k, vehicle in pairs(CpManager.activeCoursePlayers) do
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
			if vehicle_ID ~= callerVehicle.id then
				courseplay:debug(nameNum(callerVehicle) .. " (id " .. tostring(callerVehicle.id) .. "): there's a closer tractor that's trying to register: "..tostring(vehicle_ID), 4)
				return false
			else
				courseplay:debug(nameNum(callerVehicle) .. " (id " .. tostring(callerVehicle.id) .. "): it's my turn", 4);
			end
		end
	end
	--THOMAS' best_combine END


	if #(combine.courseplayers) == numAllowedCourseplayers - 1 then
		local frontTractor = combine.courseplayers[numAllowedCourseplayers - 1];
		if frontTractor then
			local canFollowFrontTractor = frontTractor.cp.totalFillLevelPercent and frontTractor.cp.totalFillLevelPercent >= callerVehicle.cp.followAtFillLevel;
			courseplay:debug(string.format('%s: frontTractor (%s) fillLevelPct (%.1f), my followAtFillLevel=%d -> canFollowFrontTractor=%s', nameNum(callerVehicle), nameNum(frontTractor), frontTractor.cp.totalFillLevelPercent, callerVehicle.cp.followAtFillLevel, tostring(canFollowFrontTractor)), 4)
			if not canFollowFrontTractor then
				return false;
			end;
		end;
	end;

	-- you got a courseplayer, so stop yellin....
	if combine.cp.wantsCourseplayer ~= nil and combine.cp.wantsCourseplayer == true then
		combine.cp.wantsCourseplayer = false
	end

	courseplay:debug(string.format("%s is being checked in with %s", nameNum(callerVehicle), tostring(combine.name)), 4)
	combine.cp.isCheckedIn = true;
	callerVehicle.cp.callCombineFillLevel = nil
	callerVehicle.cp.distanceToCombine = nil
	callerVehicle.cp.combineID = nil
	table.insert(combine.courseplayers, callerVehicle)
	callerVehicle.cp.positionWithCombine = #(combine.courseplayers)
	callerVehicle.cp.activeCombine = combine
	callerVehicle.cp.reachableCombines = {}
	
	courseplay:askForSpecialSettings(combine:getRootAttacherVehicle(), combine)

	--OFFSET
	if callerVehicle.cp.combineOffsetAutoMode == true or callerVehicle.cp.combineOffset == 0 then
	  	if combine.cp.offset == nil then
			--print("no saved offset - initialise")
	   		courseplay:calculateInitialCombineOffset(callerVehicle, combine);
	  	else 
			--print("take the saved cp.offset")
	   		callerVehicle.cp.combineOffset = combine.cp.offset;
	  	end;
	end;
	--END OFFSET

	
	courseplay:addToCombinesIgnoreList(callerVehicle, combine);
	return true;
end





function courseplay:unregisterFromCombine(vehicle, combine)
	if vehicle.cp.activeCombine == nil or combine == nil then
		return true
	end
	courseplay:debug(string.format("%s: unregistering from combine id(%s)", nameNum(vehicle), tostring(combine.id)), 4)
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
	
	if combine.acParameters ~= nil and combine.acParameters.enabled and combine.isHired then
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
						local x, y, z = getWorldTranslation(leftMarker);
						combine.cp.lmX, _, _ = worldToLocal(currentCutter.rootNode, x, y, z);
						x, y, z = getWorldTranslation(rightMarker)						
						combine.cp.rmX, _, _ = worldToLocal(currentCutter.rootNode, x, y, z);
					end;
				end;
			end;
		end;
	end;
	
	local prnX,prnY,prnZ, prnwX,prnwY,prnwZ, combineToPrnX,combineToPrnY,combineToPrnZ = 0,0,0, 0,0,0, 0,0,0;
	if combine.pipeRaycastNode ~= nil then
		prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.cp.DirectionNode or combine.rootNode, prnwX, prnwY, prnwZ)
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
	elseif not combine.cp.isChopper and combine.pipeCurrentState == 2 and combine.pipeRaycastNode ~= nil then -- pipe is extended
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
	if combine.cp.isChopper and combine.cp.workTools ~= nil then
		for _,dolly in pairs(combine.cp.workTools) do
			if dolly.haeckseldolly then
				combine.haeckseldolly = true
				if dolly.bunkerrechts then
					return 6;
				else
					return -6;
				end
			end
		end
		if combine.haeckseldolly then
			combine.haeckseldolly = nil
		end
	end
	
	if combine.cp.isGrimmeRootster604 then
		return -4.5
 	end
	
	
	if combine.cp.isSugarBeetLoader and combine.cp.isHolmerTerraFelis2 then
		local utwX,utwY,utwZ = getWorldTranslation(combine.pipeRaycastNode);
		local combineToUtwX,_,_ = worldToLocal(combine.cp.DirectionNode or combine.rootNode, utwX,utwY,utwZ);
		return combineToUtwX;
	end;

	return nil;
end;

function courseplay:getCombinesPipeSide(combine)
	local prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
	local combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.cp.DirectionNode or combine.rootNode, prnwX, prnwY, prnwZ)
	
	if combineToPrnX >= 0 then
		combine.cp.pipeSide = 1; --left
		--print("pipe is left")
	else
		combine.cp.pipeSide = -1; --right
		--print("pipe is right")
	end;
end

function courseplay:getTrailerInPipeRangeState(combine)
        local validPipeState = 0;
        for trailer,value in pairs(combine.overloading.trailersInRange) do
            if value > 0 then
				local fillType = combine.cp.fillType
                if trailer:allowFillType(combine.cp.fillType) then
					if trailer:getFillLevel(fillType) < trailer:getCapacity(fillType) then
						validPipeState = 2;
						break;
					end
                end
            end
        end
		return validPipeState 
end		
		
function courseplay:releaseCombineStop(vehicle,combine)
	if combine == nil and vehicle.cp.activeCombine == nil then 
		return 
	end
	local combineToStart = combine or vehicle.cp.activeCombine
	if combineToStart.aiIsStarted and combineToStart.cruiseControl.speed == 0 then
		combineToStart.cruiseControl.speed = combineToStart.cp.lastCruiseControlSpeed
	end
end