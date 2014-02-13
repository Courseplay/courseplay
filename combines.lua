function courseplay:find_combines(self)
	-- reseting reachable combines
	local found_combines = {}
	-- go through all vehicles and find filter all combines
	local all_vehicles = g_currentMission.vehicles
	for k, vehicle in pairs(all_vehicles) do
		-- trying to identify combines
		if vehicle.cp == nil then
			vehicle.cp = {};
			courseplay:setNameVariable(vehicle)
		end;
		
		if vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or courseplay:isAttachedCombine(vehicle) then
			if (courseplay:isAttachedCombine(vehicle) and vehicle.attacherVehicle ~= nil and not vehicle.cp.isPoettingerMex6) or not courseplay:isAttachedCombine(vehicle) then
				table.insert(found_combines, vehicle);
			end;
		end;

	end;

	return found_combines;
end


function courseplay:combine_allows_tractor(self, combine)
	if combine.courseplayers == nil then
		combine.courseplayers = {}
	end

	local num_allowed_courseplayers = 1
	if combine.cp.isChopper or combine.cp.isSugarBeetLoader then
		num_allowed_courseplayers = 2
	else
		if self.cp.realisticDriving then
			if combine.wants_courseplayer == true then
				courseplay:debug(nameNum(self)..": combine full or manual call -> allow tractor",4)
				return true
			end
			-- force unload when combine is full
			if combine.grainTankFillLevel == combine.grainTankCapacity then
				courseplay:debug(nameNum(self)..": set fill level reached -> allow tractor",4)
				return true
			end
			-- is the pipe on the correct side?
			if combine.turnStage == 1 or combine.turnStage == 2 or (combine.cp.turnStage ~= nil and combine.cp.turnStage ~= 0) or (combine.acTurnStage~= nil and combine.acTurnStage ~=0) then
				courseplay:debug(nameNum(self)..": combine is turning -> refuse tractor",4)
				courseplay:debug(string.format("%s:		combine.turnStage = %d, combine.cp.turnStage = %d, combine.acTurnStage = %s ",nameNum(self),combine.turnStage,combine.cp.turnStage,tostring(combine.acTurnStage)),4)
				return false
			end
			local fruitSide = courseplay:sideToDrive(self, combine, -10)
			if fruitSide == "none" then
				courseplay:debug(nameNum(self)..": fruitSide is none -> try again with offset 0",4)
				fruitSide = courseplay:sideToDrive(self, combine, 0)
			end
			if fruitSide == "left" then
				courseplay:debug(nameNum(self)..": path finding active and pipe in fruit -> refuse tractor",4)
				return false
			end
		end
	end

	if table.getn(combine.courseplayers) >= num_allowed_courseplayers then
		return false
	end

	if table.getn(combine.courseplayers) == 1 and not combine.courseplayers[1].cp.allowFollowing then
		return false
	end

	return true
end

-- find combines on the same field (texture)
function courseplay:update_combines(self)
	courseplay:debug(string.format("%s: update_combines()", nameNum(self)), 4);

	self.cp.reachableCombines = {}

	if not self.cp.searchCombineAutomatically and self.cp.savedCombine then
		courseplay:debug(nameNum(self)..": combine is manual set",4)
		table.insert(self.cp.reachableCombines, self.cp.savedCombine)
		return
	end

	courseplay:debug(string.format("%s: combines total: %d", nameNum(self), table.getn(self.cp.reachableCombines)), 4)

	local x, y, z = getWorldTranslation(self.cp.DirectionNode)
	local hx, hy, hz = localToWorld(self.cp.DirectionNode, -2, 0, 0)
	local lx, ly, lz = nil, nil, nil
	local terrain = g_currentMission.terrainDetailId

	local found_combines = courseplay:find_combines(self)

	courseplay:debug(string.format("%s: combines found: %d", nameNum(self), table.getn(found_combines)), 4)

	--[[
	--DEV: check field pairing using fieldDefs
	local combineFound;
	if courseplay.fields.numAvailableFields > 0 and self.cp.searchCombineOnField > 0 then
		local fieldData = courseplay.fields.fieldData[self.cp.searchCombineOnField];
		for k,combine in pairs(found_combines) do
			local combineX,_,combineZ = getWorldTranslation(combine.rootNode);
			if combineX >= fieldData.dimensions.minX and combineX <= fieldData.dimensions.maxX and combineZ >= fieldData.dimensions.minZ and combineZ <= fieldData.dimensions.maxZ then
				courseplay:debug(string.format('%s: combine %q is in field %d\'s dimensions', nameNum(self), nameNum(combine), self.cp.searchCombineOnField), 4);
				if courseplay:pointInPolygonV2b(fieldData.points, combineX, combineZ, true) then
					courseplay:debug(string.format('\tcombine is in field %d\'s poly', self.cp.searchCombineOnField), 4);
					courseplay:debug(string.format('%s: adding %q to reachableCombines table', nameNum(self), nameNum(combine)), 4);
					table.insert(self.cp.reachableCombines, combine);
					combineFound = true;
				end;
			end;
		end;
		courseplay:debug(string.format("%s: combines reachable: %d ", nameNum(self), #(self.cp.reachableCombines)), 4);
		if combineFound then
			return;
		end;
	end;
	]]

	-- go through found combines
	for k, combine in pairs(found_combines) do
		lx, ly, lz = getWorldTranslation(combine.rootNode)
		local dlx, dly, dlz = worldToLocal(self.cp.DirectionNode, lx, y, lz)
		local dnx = dlz * -1
		local dnz = dlx
		local angle = math.atan(dnz / dnx)
		dnx = math.cos(angle) * -2
		dnz = math.sin(angle) * -2
		hx, hy, hz = localToWorld(self.cp.DirectionNode, dnx, 0, dnz)
		local area0, area = Utils.getDensity(terrain, 0, x, z, lx, lz, hx, hz)
		local area1 = Utils.getDensity(terrain, 1, x, z, lx, lz, hx, hz)
		local area2 = Utils.getDensity(terrain, 2, x, z, lx, lz, hx, hz)
		local area3 = Utils.getDensity(terrain, 3, x, z, lx, lz, hx, hz)
		local areaAll = area0 + area1 + area2 + area3
		courseplay:debug(string.format('%s: to combine %q: area=%d, channels 0=%d, 1=%d, 2=%d, 3=%d, field in area = %d', nameNum(self), nameNum(combine), area, area0, area1, area2, area3, areaAll), 4);

		if areaAll >= area * 0.999 and areaAll <= area * 1.1 and courseplay:combine_allows_tractor(self, combine) then
			courseplay:debug(string.format('%s: adding %q to reachableCombines table', nameNum(self), nameNum(combine)), 4);
			table.insert(self.cp.reachableCombines, combine)
		end
	end

	courseplay:debug(string.format("%s: combines reachable: %d ", nameNum(self), table.getn(self.cp.reachableCombines)), 4)
end


function courseplay:register_at_combine(self, combine)
	local curFile = "combines.lua"
	courseplay:debug(string.format("%s: registering at combine %s", nameNum(self), tostring(combine.name)), 4)
	--courseplay:debug(tableShow(combine, tostring(combine.name), 4), 4)
	local num_allowed_courseplayers = 1
	self.cp.calculatedCourseToCombine = false
	if combine.courseplayers == nil then
		combine.courseplayers = {};
	end;
	if combine.cp == nil then
		combine.cp = {};
	end;

	if combine.cp.isChopper or combine.cp.isSugarBeetLoader then
		num_allowed_courseplayers = 2
	else
		
		if self.cp.realisticDriving then
			if combine.wants_courseplayer == true or combine.grainTankFillLevel == combine.grainTankCapacity then

			else
				-- force unload when combine is full
				-- is the pipe on the correct side?
				if combine.turnStage == 1 or combine.turnStage == 2 or combine.cp.turnStage ~= 0 then
					courseplay:debug(nameNum(self)..": combine is turning -> don't register tractor",4)
					return false
				end
				local fruitSide = courseplay:sideToDrive(self, combine, -10)
				if fruitSide == "none" then
					courseplay:debug(nameNum(self)..": fruitSide is none -> try again with offset 0",4)
					fruitSide = courseplay:sideToDrive(self, combine, 0)
				end
				courseplay:debug(nameNum(self)..": courseplay:sideToDrive = "..tostring(fruitSide),4)
				if fruitSide == "left" then
					courseplay:debug(nameNum(self)..": path finding active and pipe in fruit -> don't register tractor",4)
					return false
				end
			end
		end
	end

	if table.getn(combine.courseplayers) == num_allowed_courseplayers then
		courseplay:debug(string.format("%s (id %s): combine (id %s) is already registered", nameNum(self), tostring(self.id), tostring(combine.id)), 4);
		return false
	end

	--THOMAS' best_combine START
	if combine.cp.isCombine or (courseplay:isAttachedCombine(combine) and not courseplay:isSpecialChopper(combine)) then
		if combine.cp.driverPriorityUseFillLevel then
			local fillLevel = 0
			local vehicle_ID = 0
			for k, vehicle in pairs(courseplay.activeCoursePlayers) do
				if vehicle.combineID ~= nil then
					if vehicle.combineID == combine.id and vehicle.cp.activeCombine == nil then
						courseplay:debug(tostring(vehicle.id).." : callCombineFillLevel:"..tostring(vehicle.callCombineFillLevel).." for combine.id:"..tostring(combine.id), 4)
						if fillLevel <= vehicle.callCombineFillLevel then
							fillLevel = math.min(vehicle.callCombineFillLevel,0.1)
							vehicle_ID = vehicle.id
						end
					end
				end
			end
			if vehicle_ID ~= self.id then
				courseplay:debug(nameNum(self) .. " (id " .. tostring(self.id) .. "): there's a tractor with more fillLevel that's trying to register: "..tostring(vehicle_ID), 4)
				return false
			else
				courseplay:debug(nameNum(self) .. " (id " .. tostring(self.id) .. "): it's my turn", 4);
			end
		else
			local distance = 9999999
			local vehicle_ID = 0
			for k, vehicle in pairs(courseplay.activeCoursePlayers) do
				if vehicle.combineID ~= nil then
					--print(tostring(vehicle.name).." is calling for "..tostring(vehicle.combineID).."  combine.id= "..tostring(combine.id))
					if vehicle.combineID == combine.id and vehicle.cp.activeCombine == nil then
						courseplay:debug(tostring(vehicle.id).." : distanceToCombine:"..tostring(vehicle.distanceToCombine).." for combine.id:"..tostring(combine.id), 4)
						if distance > vehicle.distanceToCombine then
							distance = vehicle.distanceToCombine
							vehicle_ID = vehicle.id
						end
					end
				end
			end
			if vehicle_ID ~= self.id then
				courseplay:debug(nameNum(self) .. " (id " .. tostring(self.id) .. "): there's a closer tractor that's trying to register: "..tostring(vehicle_ID), 4)
				return false
			else
				courseplay:debug(nameNum(self) .. " (id " .. tostring(self.id) .. "): it's my turn", 4);
			end
		end
	end
	--THOMAS' best_combine END


	if table.getn(combine.courseplayers) == 1 and not combine.courseplayers[1].cp.allowFollowing then
		return false
	end

	-- you got a courseplayer, so stop yellin....
	if combine.wants_courseplayer ~= nil and combine.wants_courseplayer == true then
		combine.wants_courseplayer = false
	end

	courseplay:debug(string.format("%s is being checked in with %s", nameNum(self), tostring(combine.name)), 4)
	combine.isCheckedIn = 1;
	self.callCombineFillLevel = nil
	self.distanceToCombine = nil
	self.combineID = nil
	table.insert(combine.courseplayers, self)
	self.cp.positionWithCombine = table.getn(combine.courseplayers)
	self.cp.activeCombine = combine
	self.cp.reachableCombines = {}
	
	courseplay:askForSpecialSettings(combine:getRootAttacherVehicle(), combine)

	--OFFSET
	if combine.cp == nil then
		combine.cp = {};
	end;
	combine.cp.pipeSide = 1;

	if self.cp.combineOffsetAutoMode == true or self.cp.combineOffset == 0 then
	  	if combine.cp.offset == nil then
			--print("no saved offset - initialise")
	   		courseplay:calculateInitialCombineOffset(self, combine);
	  	else 
			--print("take the saved cp.offset")
	   		self.cp.combineOffset = combine.cp.offset;
	  	end;
	end;
	--END OFFSET

	
	courseplay:add_to_combines_ignore_list(self, combine);
	return true;
end





function courseplay:unregister_at_combine(self, combine)
	if self.cp.activeCombine == nil or combine == nil then
		return true
	end

	self.cp.calculatedCourseToCombine = false;
	courseplay:remove_from_combines_ignore_list(self, combine)
	combine.isCheckedIn = nil;
	table.remove(combine.courseplayers, self.cp.positionWithCombine)

	-- updating positions of tractors
	for k, tractor in pairs(combine.courseplayers) do
		tractor.cp.positionWithCombine = k
	end

	self.allow_follwing = false
	self.cp.positionWithCombine = nil
	self.cp.lastActiveCombine = self.cp.activeCombine
	self.cp.activeCombine = nil
	self.cp.modeState = 1

	if self.trafficCollisionIgnoreList[combine.rootNode] == true then
	   self.trafficCollisionIgnoreList[combine.rootNode] = nil
	end
	
	if combine.acParameters ~= nil then
		if combine.cp.turnStage ~= 0 then
			combine.cp.turnStage = 0
		end
	end
	
	return true
end

function courseplay:add_to_combines_ignore_list(self, combine)
	if combine == nil or combine.trafficCollisionIgnoreList == nil then
		return
	end
	if combine.trafficCollisionIgnoreList[self.rootNode] == nil then
		combine.trafficCollisionIgnoreList[self.rootNode] = true
	end
end


function courseplay:remove_from_combines_ignore_list(self, combine)
	if combine == nil or combine.trafficCollisionIgnoreList == nil then
		return
	end
	if combine.trafficCollisionIgnoreList[self.rootNode] == true then
		combine.trafficCollisionIgnoreList[self.rootNode] = nil
	end
end

function courseplay:calculateInitialCombineOffset(self, combine)
	local curFile = "combines.lua";
	local leftMarker = nil
	local currentCutter = nil
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
		prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.rootNode, prnwX, prnwY, prnwZ)

		if combineToPrnX >= 0 then
			combine.cp.pipeSide = 1; --left
			--print("pipe is left")
		else
			combine.cp.pipeSide = -1; --right
			--print("pipe is right")		
		end;
	end;

	--special tools, special cases
	if combine.cp.isJohnDeereS650 then
		self.cp.combineOffset =  7.7;
	elseif combine.cp.isCaseIH7130 then
		self.cp.combineOffset =  8.0;
	elseif combine.cp.isCaseIH9230 or combine.cp.isCaseIH9230Crawler then
		self.cp.combineOffset = 11.5;
	elseif combine.cp.isDeutz5465H then
		self.cp.combineOffset =  5.1;
	elseif combine.cp.isGrimmeRootster604 then
		self.cp.combineOffset = -4.3;
	elseif combine.cp.isGrimmeSE7555 then
		self.cp.combineOffset =  4.3;
	elseif combine.cp.isFahrM66 then
		self.cp.combineOffset =  4.4;
	elseif combine.cp.isJF1060 then
		self.cp.combineOffset = -7;
		combine.cp.offset = 7;
	elseif combine.cp.isRopaEuroTiger then
		self.cp.combineOffset =  5.2;
	elseif combine.cp.isSugarBeetLoader then
		local utwX,utwY,utwZ = getWorldTranslation(combine.unloadingTrigger.node);
		local combineToUtwX,_,_ = worldToLocal(combine.rootNode, utwX,utwY,utwZ);
		self.cp.combineOffset = combineToUtwX;
	
	--combine // combine_offset is in auto mode
	elseif not combine.cp.isChopper and combine.currentPipeState == 2 and combine.pipeRaycastNode ~= nil then -- pipe is extended
		self.cp.combineOffset = combineToPrnX;
		courseplay:debug(string.format("%s(%i): %s @ %s: using combineToPrnX=%f, self.cp.combineOffset=%f", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name), combineToPrnX, self.cp.combineOffset), 4)
	elseif not combine.cp.isChopper and combine.pipeRaycastNode ~= nil then --pipe is closed
		if getParent(combine.pipeRaycastNode) == combine.rootNode then -- pipeRaycastNode is direct child of combine.root
			self.cp.combineOffset = prnX;
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.root > pipeRaycastNode / self.cp.combineOffset=prnX=%f", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name), self.cp.combineOffset), 4)
		elseif getParent(getParent(combine.pipeRaycastNode)) == combine.rootNode then --pipeRaycastNode is direct child of pipe is direct child of combine.root
			local pipeX, pipeY, pipeZ = getTranslation(getParent(combine.pipeRaycastNode))
			self.cp.combineOffset = pipeX - prnZ;

			if prnZ == 0 or combine.cp.isGrimmeRootster604 then
				self.cp.combineOffset = pipeX - prnY;
			end
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.root > pipe > pipeRaycastNode / self.cp.combineOffset=pipeX-prnX=%f", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name), self.cp.combineOffset), 4)
		elseif combineToPrnX > combine.cp.lmX then
			self.cp.combineOffset = combineToPrnX + (5 * combine.cp.pipeSide);
			courseplay:debug(string.format("%s(%i): %s @ %s: using combineToPrnX=%f, self.cp.combineOffset=%f", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name), combineToPrnX, self.cp.combineOffset), 4)
		elseif combine.cp.lmX ~= nil then
			if combine.cp.lmX > 0 then --use leftMarker
				self.cp.combineOffset = combine.cp.lmX + 2.5;
				courseplay:debug(string.format("%s(%i): %s @ %s: using leftMarker+2.5, self.cp.combineOffset=%f", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name), self.cp.combineOffset), 4);
			end;
		else --BACKUP
			self.cp.combineOffset = 8 * combine.cp.pipeSide;
		end;
	elseif combine.cp.isChopper then
		courseplay:debug(string.format("%s(%i): %s @ %s: combine.cp.forcedSide=%s", curFile, debug.getinfo(1).currentline, nameNum(self), combine.name, tostring(combine.cp.forcedSide)), 4);
		if combine.cp.forcedSide ~= nil then
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.cp.forcedSide=%s, going by cp.forcedSide", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name), combine.cp.forcedSide), 4);
			if combine.cp.forcedSide == "left" then
				self.sideToDrive = "left";
				if combine.cp.lmX ~= nil then
					self.cp.combineOffset = combine.cp.lmX + 2.5;
				else
					self.cp.combineOffset = 8;
				end;
			elseif combine.cp.forcedSide == "right" then
				self.sideToDrive = "right";
				if combine.cp.lmX ~= nil then
					self.cp.combineOffset = (combine.cp.lmX + 2.5) * -1;
				else
					self.cp.combineOffset = -8;
				end;
			end
		else
			courseplay:debug(string.format("%s(%i): %s @ %s: combine.cp.forcedSide=%s, going by fruit", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name), tostring(combine.cp.forcedSide)), 4);
			local fruitSide = courseplay:sideToDrive(self, combine, 5);
			if fruitSide == "right" then
				if combine.cp.lmX ~= nil then
					self.cp.combineOffset = math.max(combine.cp.lmX + 2.5, 7);
				else --attached chopper
					self.cp.combineOffset = 7;
				end;
			elseif fruitSide == "left" then
				if combine.cp.lmX ~= nil then
					self.cp.combineOffset = math.max(combine.cp.lmX + 2.5, 7) * -1;
				else --attached chopper
					self.cp.combineOffset = -3;
				end;
			elseif fruitSide == "none" then
				if combine.cp.lmX ~= nil then
					self.cp.combineOffset = math.max(combine.cp.lmX + 2.5, 7);
				else --attached chopper
					self.cp.combineOffset = 7;
				end;
			end
			--print("saving offset")
			combine.cp.offset = math.abs(self.cp.combineOffset)
		end;
	end;
end;