-- inspired by fieldstatus of Alan R. (ls-uk.info: thebadtouch)
function courseplay:area_has_fruit(x, z, fruit_type)
	if not courseplay:is_field(x, z) then
		return false
	end
	local numFruits = table.getn(g_currentMission.fruits);
	local getdenFunc = Utils.getDensity;
	local getfruitFunc = Utils.getFruitArea;
	local chnum = 0;
	local density = 0
	local startX, startZ, endX, endZ, widthX, widthZ, heightX, heightZ;

	local widthX = 0.5;
	local widthZ = 0.5;

	--x = x - 2.5
	--z = z - 2.5
	if fruit_type ~= nil then
		density = Utils.getFruitArea(fruit_type, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ);

		if density > 0 then
			--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), 3)
			return true
		end
	else
		for i = 1, FruitUtil.NUM_FRUITTYPES do
			if i ~= FruitUtil.FRUITTYPE_GRASS then

				density = Utils.getFruitArea(i, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ);

				if density > 0 then
					--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), 3)
					return true
				end
			end
		end
	end

	--courseplay:debug(string.format(" x: %d z %d - is really cut!", x, z ), 3)
	return false
end

function courseplay:is_field(x, z)
	local widthX = 0.5;
	local widthZ = 0.5;
	
	for i=0,3 do
		if Utils.getDensity(g_currentMission.terrainDetailId, i, x, z, x - widthX, z - widthZ, x + widthX, z + widthZ) ~= 0 then
			return true;
		end;
	end;
	return false;
end;

function courseplay:check_for_fruit(self, distance)

	local x, y, z = localToWorld(self.aiTractorDirectionNode, 0, 0, distance) --getWorldTranslation(combine.aiTreshingDirectionNode);

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
	-- if there is a forced side to drive return this
	--print("sideToDrive:")
	local x, y, z = localToWorld(combine.aiTreshingDirectionNode, 0, 0, distance) --getWorldTranslation(combine.aiTreshingDirectionNode);
	local dirX, dirZ = combine.aiThreshingDirectionX, combine.aiThreshingDirectionZ;
	if not (combine.isAIThreshing or combine.drive) then 
			local dx,_,dz = localDirectionToWorld(combine.rootNode, 0, 0, 2);
			local length = Utils.vector2Length(dx,dz);
			dirX = dx/length;
			dirZ = dz/length;
	end
	local sideX, sideZ = -dirZ, dirX;

	local threshWidth = 10
	local lWidthX = x - sideX * 0.5 * threshWidth + dirX * combine.sideWatchDirOffset;
	local lWidthZ = z - sideZ * 0.5 * threshWidth + dirZ * combine.sideWatchDirOffset;
	local lStartX = lWidthX - sideX * 0.7 * threshWidth;
	local lStartZ = lWidthZ - sideZ * 0.7 * threshWidth;
	local lHeightX = lStartX + dirX * combine.sideWatchDirSize;
	local lHeightZ = lStartZ + dirZ * combine.sideWatchDirSize;

	local rWidthX = x + sideX * 0.5 * threshWidth + dirX * combine.sideWatchDirOffset;
	local rWidthZ = z + sideZ * 0.5 * threshWidth + dirZ * combine.sideWatchDirOffset;
	local rStartX = rWidthX + sideX * 0.7 * threshWidth;
	local rStartZ = rWidthZ + sideZ * 0.7 * threshWidth;
	local rHeightX = rStartX + dirX * self.sideWatchDirSize;
	local rHeightZ = rStartZ + dirZ * self.sideWatchDirSize;
	local leftFruit = 0
	local rightFruit = 0

	leftFruit = leftFruit + Utils.getFruitArea(combine.lastValidInputFruitType, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ,true)
	rightFruit = rightFruit + Utils.getFruitArea(combine.lastValidInputFruitType, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ,true)
	--print("	leftFruit:  "..tostring(leftFruit).."  rightFruit:  "..tostring(rightFruit))
	courseplay:debug(string.format("%s: fruit: left %f right %f", combine.name, leftFruit, rightFruit), 3)
	local fruitSide 
	if combine.isAIThreshing then
		--print("	isAITreshing")
		local tempFruit
		if (not combine.waitingForDischarge and combine.waitForTurnTime > combine.time) or (combine.turnStage == 1) then
			--Fruit side switch at end of field line
			--print("	automatic changeover")
			tempFruit = leftFruit;
			leftFruit = rightFruit;
			rightFruit = tempFruit;
		end;
	elseif combine.drive then
		--print("	is in mode6") 
		local Dir = 0;
		local wayPoint = combine.recordnumber
		if not switchSide then
			wayPoint = wayPoint +2
		else
			wayPoint = wayPoint -2
		end						
		if combine.Waypoints ~= nil and wayPoint ~= nil and combine.Waypoints[wayPoint] ~= nil then
			Dir = Utils.getNoNil(combine.Waypoints[wayPoint].ridgeMarker , 0);
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
	if combine.forced_side == nil then
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
	elseif combine.forced_side == "right" then
		--print("	forced side right")
		self.sideToDrive = "right";
	else
		--print("	forced side left")
		self.sideToDrive = "left";
	end



	--print("	return: fruitSide: "..tostring(fruitSide))
	return fruitSide
end