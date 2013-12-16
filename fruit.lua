-- inspired by fieldstatus of Alan R. (ls-uk.info: thebadtouch)
function courseplay:area_has_fruit(x, z, fruitType, widthX, widthZ)
	widthX = widthX or 0.5;
	widthZ = widthZ or 0.5;
	if not courseplay:is_field(x, z, widthX, widthZ) then
		return false;
	end;

	local density = 0;
	if fruitType ~= nil then
		density = Utils.getFruitArea(fruitType, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ);
		if density > 0 then
			--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), 3)
			return true;
		end;
	else
		for i = 1, FruitUtil.NUM_FRUITTYPES do
			if i ~= FruitUtil.FRUITTYPE_GRASS then
				density = Utils.getFruitArea(i, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ);
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

function courseplay:is_field(x, z, widthX, widthZ)
	widthX = widthX or 0.5;
	widthZ = widthZ or 0.5;

	if courseplay.fields.lastChannel ~= nil then
		if Utils.getDensity(g_currentMission.terrainDetailId, courseplay.fields.lastChannel, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ) ~= 0 then
			return true;
		end;
	end;

	for i,channel in ipairs(courseplay.fields.fieldChannels) do
		if Utils.getDensity(g_currentMission.terrainDetailId, channel, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ) ~= 0 then
			courseplay.fields.lastChannel = channel;
			return true;
		end;
	end;
	return false;
end;

function courseplay:check_for_fruit(self, distance)

	local x, y, z = localToWorld(self.cp.DirectionNode, 0, 0, distance) --getWorldTranslation(combine.aiTreshingDirectionNode);

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
			leftFruit = leftFruit + Utils.getFruitArea(i, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ)

			rightFruit = rightFruit + Utils.getFruitArea(i, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ)
		end
	end

	return leftFruit, rightFruit;
end


function courseplay:side_to_drive(self, combine, distance,switchSide)
end


function courseplay:sideToDrive(self, combine, distance,switchSide)
	-- if there is a forced side to drive return this
	--print("courseplay:sideToDrive:") 
	local tractor = combine
	if courseplay:isAttachedCombine(combine) then
		tractor = combine.attacherVehicle
	end


	local x, y, z = 0,0,0
	x, y, z = localToWorld(tractor.cp.DirectionNode, 0, 0, distance -5)
	local dirX, dirZ = combine.aiThreshingDirectionX, combine.aiThreshingDirectionZ;
	if (not (combine.isAIThreshing or combine.drive)) or  combine.aiThreshingDirectionX == nil or combine.aiThreshingDirectionZ == nil or combine.acParameters ~= nil then
			local dx,_,dz = localDirectionToWorld(combine.rootNode, 0, 0, 2);
			local length = Utils.vector2Length(dx,dz);
			dirX = dx/length;
			dirZ = dz/length;
	end
	local sideX, sideZ = -dirZ, dirX;
	local sideWatchDirOffset = Utils.getNoNil(combine.sideWatchDirOffset,-8)
	local sideWatchDirSize = Utils.getNoNil(combine.sideWatchDirSize,3)
	local selfSideWatchDirSize = Utils.getNoNil(self.sideWatchDirSize,3)

	local threshWidth = 10
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
	local leftFruit = 0
	local rightFruit = 0

	leftFruit = leftFruit + Utils.getFruitArea(combine.lastValidInputFruitType, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ,true)
	rightFruit = rightFruit + Utils.getFruitArea(combine.lastValidInputFruitType, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ,true)
	--print("	leftFruit:  "..tostring(leftFruit).."  rightFruit:  "..tostring(rightFruit))
	--courseplay:debug(string.format("%s: fruit: left %f right %f", combine.name, leftFruit, rightFruit), 3)
	local fruitSide 
	if combine.acParameters ~= nil and combine.acParameters.enabled then -- autoCombine
		--print(" combine.acParameters.leftAreaActive: "..tostring(combine.acParameters.leftAreaActive).."  combine.acTurnStage: "..tostring(combine.acTurnStage))
		if not combine.acParameters.upNDown then
			if combine.acParameters.leftAreaActive then
				leftFruit,rightFruit = 0,100 
				--fruitSide = "right"
			else
				leftFruit,rightFruit = 100,0
				--fruitSide = "left"
			end
		end	
	elseif combine.isAIThreshing then --helper
		--print("	isAITreshing")
		local tempFruit
		if (not combine.waitingForDischarge and combine.waitForTurnTime > combine.time) or (combine.turnStage == 1) then
			--Fruit side switch at end of field line
			--print("	automatic changeover")
			tempFruit = leftFruit;
			leftFruit = rightFruit;
			rightFruit = tempFruit;
		end;
	
	elseif tractor.drive then  --Courseplay
		--print("	is in mode6") 
		local Dir = 0;
		local wayPoint = tractor.recordnumber
		if tractor.cp.turnStage > 0 then
   			switchSide = true
  		end
		if not switchSide then
			wayPoint = wayPoint +2
		else
			wayPoint = wayPoint -2
		end						
		if tractor.Waypoints ~= nil and wayPoint ~= nil and tractor.Waypoints[wayPoint] ~= nil then
			Dir = Utils.getNoNil(tractor.Waypoints[wayPoint].ridgeMarker , 0);
		end;
		if Dir == 1 then
			leftFruit , rightFruit  = 100,0
		elseif Dir == 2 then
			leftFruit , rightFruit  = 0,100
		end
	end
	
	if leftFruit > rightFruit then
		fruitSide = "left"
	elseif leftFruit < rightFruit then
		fruitSide = "right"
	else
		fruitSide = "none"
	end
	if combine.cp.forcedSide == nil then
		--print("	forced side == nil")
		if not switchSide then
			if fruitSide == "right" then
				self.sideToDrive = "left";
			elseif fruitSide == "left" then
				self.sideToDrive = "right";
			else
				self.sideToDrive = nil;
			end;
		else
			if fruitSide == "right" then
				self.sideToDrive = "right";
			elseif fruitSide == "left" then
				self.sideToDrive = "left";
			end;
		end;
	elseif combine.cp.forcedSide == "right" then
		--print("	forced side right")
		self.sideToDrive = "right";
	else
		--print("	forced side left")
		self.sideToDrive = "left";
	end



	--print("	return: fruitSide: "..tostring(fruitSide))
	return fruitSide
end