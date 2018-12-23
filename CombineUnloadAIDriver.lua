--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

CombineUnloadAIDriver = CpObject(AIDriver)

CombineUnloadAIDriver.STATE_DEFAULT = 0
CombineUnloadAIDriver.STATE_WAIT_AT_START = 1
CombineUnloadAIDriver.STATE_DRIVE_TO_COMBINE = 2
CombineUnloadAIDriver.STATE_DRIVE_NEXT_TO_COMBINE = 3
CombineUnloadAIDriver.STATE_FOLLOW_PIPE = 4 
CombineUnloadAIDriver.STATE_DRIVE_COURSE_ON_FIELD = 5 
CombineUnloadAIDriver.STATE_FOLLOW_TRACTOR = 6 
CombineUnloadAIDriver.STATE_WAIT_FOR_PIPE = 7 
CombineUnloadAIDriver.STATE_WAIT_FOR_COMBINE_TO_GET_OUT_OF_WAY = 9 
CombineUnloadAIDriver.STATE_ALL_TRAILERS_FULL = 10 
CombineUnloadAIDriver.STATE_SWITCH_SIDE = 11 


--- Constructor
function CombineUnloadAIDriver:init(vehicle)
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_COMBI
	self:setModeState(self.STATE_DEFAULT)
	self.onTurnAwayCourse = false
end

function CombineUnloadAIDriver:start(ix)
	AIDriver.start(self, ix)
end

function CombineUnloadAIDriver:isAlignmentCourseNeeded(ix)
	
	return false
end

function CombineUnloadAIDriver:drive(dt)
	--we are on the way to unload
	local modeState = self:getModeState() 
	if modeState == self.STATE_DEFAULT then
		renderText(0.2, 0.105, 0.02, "CombineUnloadAIDriver:go unload course");
		self:driveUnloadCourse(dt)
	--stop and search for a combine
	elseif modeState == self.STATE_WAIT_AT_START then
		renderText(0.2, 0.105, 0.02, "CombineUnloadAIDriver:searchForCombines");
		self:searchForCombines(dt)
		courseplay:setIsLoaded(self.vehicle, false);
		courseplay:setWaypointIndex(self.vehicle, 1);
	--drive to the combine
	elseif modeState == self.STATE_DRIVE_TO_COMBINE then
		renderText(0.2, 0.105, 0.02, "CombineUnloadAIDriver:DRIVE_TO_COMBINE");
		self:driveToCombine(dt)
	--allign with the pipe
	elseif modeState == self.STATE_DRIVE_NEXT_TO_COMBINE then
		renderText(0.2, 0.105, 0.02, "CombineUnloadAIDriver:DRIVE_NEXT_TO_COMBINE");
		self:driveNextToCombine(dt)
	--follow the pipe	
	elseif modeState == self.STATE_FOLLOW_PIPE then
		renderText(0.2, 0.105, 0.02, "CombineUnloadAIDriver:FOLLOW_PIPE");
		self:followPipe(dt)
	elseif modeState == self.STATE_DRIVE_COURSE_ON_FIELD then
		renderText(0.2, 0.105, 0.02, "CombineUnloadAIDriver:STATE_DRIVE_COURSE_ON_FIELD");
		self:driveCourseOnField(dt)
	else 
		renderText(0.2, 0.105, 0.02, "Häää?? modeState: "..tostring(modeState));
	end
	
	if modeState > self.STATE_DEFAULT then
		self:checkFillLevels(dt)
	end
end

function CombineUnloadAIDriver:setOnTurnAwayCourse(onTurnAwayCourse)
	if self.onTurnAwayCourse ~= onTurnAwayCourse then
		self.onTurnAwayCourse = onTurnAwayCourse
	end
end

function CombineUnloadAIDriver:driveCourseOnField(dt)
	local vehicle = self.vehicle
	local allowedToDrive = true
	self.ppc:update()
	self:driveCourse(dt, allowedToDrive)
	self:checkLastWaypoint()
	
	if (courseplay.debugChannels[4] or courseplay.debugChannels[9])then
		for i,tp in pairs(vehicle.cp.nextTargets) do
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tp.x, 0, tp.z)
			cpDebug:drawPoint(tp.x, y +2, tp.z, 1, 0.65, 0);
			if i == 1 then
				--cpDebug:drawLine(vehicle.cp.curTarget.x, y + 2, vehicle.cp.curTarget.z, 1, 0, 1, tp.x, y + 2, tp.z);
			else
				local pp = vehicle.cp.nextTargets[i-1];
				local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pp.x, 0, pp.z)
				cpDebug:drawLine(pp.x, y+2, pp.z, 1, 0, 1, tp.x, y + 2, tp.z);
			end;
		end;		
	end
end


function CombineUnloadAIDriver:checkFillLevels(dt)
	local vehicle = self.vehicle
	local combine = vehicle.cp.activeCombine
	local currentTrailerToFill = vehicle.cp.currentTrailerToFill or 1
	local currentTipper = vehicle.cp.workTools[currentTrailerToFill]
	if currentTipper.cp.fillLevel >= currentTipper.cp.capacity or vehicle.cp.isLoaded then
		print("currentTipper.cp.fillLevel >= currentTipper.cp.capacity or vehicle.cp.isLoaded: "..tostring(vehicle.cp.isLoaded))
		self:setModeState(self.STATE_DEFAULT);
		self.ppc:setCourse(self.course)
		self.ppc:initialize(1)
		courseplay:setIsLoaded(vehicle, true);
		courseplay:releaseCombineStop(vehicle,vehicle.cp.activeCombine)
		courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine)
	end
end

function CombineUnloadAIDriver:checkTurnOnFieldEdge(dt)
	local vehicle = self.vehicle
	local combine = vehicle.cp.activeCombine
	local trailerOffset = vehicle.cp.tipperOffset
	local totalLength = vehicle.cp.totalLength+2
	local turnDiameter = vehicle.cp.turnDiameter+2
	local aiTurn = combine.spec_aiVehicle.isTurning
	local combineIsTurning = false
	--[[for index,strategy in pairs(combine.spec_aiVehicle.driveStrategies) do
		if strategy.activeTurnStrategy ~= nil then
			combine.cp.turnStrategyIndex = index
			strategy.activeTurnStrategy.didNotMoveTimer = strategy.activeTurnStrategy.didNotMoveTimeout;
			aiTurn = true
		end
	end	]]
	
	if combine ~= nil and (aiTurn or combine.cp.turnStage > 0) then
		--courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_IS_TURNING");
		combineIsTurning = true
		print(('%s: cp.turnStage=%d -> combineIsTurning=true'):format(nameNum(combine), combine.cp.turnStage));
	end
	if combineIsTurning then
		if combine.cp.isChopper then
			local fruitSide = courseplay:sideToDrive(vehicle, combine, -10,true);
			local maxDiameter = math.max(totalLength,turnDiameter)
			local extraAlignLength = 9
			if vehicle.cp.distances ~= nil and vehicle.cp.distances.frontWheelToRearWheel ~=nil then
				extraAlignLength = vehicle.cp.distances.frontWheelToRearWheel*3;
			end
			--local extraAlignLength = courseplay:getDirectionNodeToTurnNodeLength(vehicle)*2+6;	
			
			--another new chopper turn maneuver by Thomas Gärtner  
			if fruitSide == "left" then -- chopper will turn left

				if vehicle.cp.combineOffset > 0 then -- I'm left of chopper
					courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm left", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnDiameter);
					vehicle.cp.curTarget.rev = false
					courseplay:addNewTargetVector(vehicle, 2*turnDiameter*-1 ,  turnDiameter);
					vehicle.cp.chopperIsTurning = true

				else --i'm right of choppper
					if vehicle.cp.isReversePossible and not autoCombineCircleMode and combine.cp.forcedSide == nil and combine.cp.multiTools == 1 and vehicle.cp.turnOnField then
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm right. Turning the New Way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
						local maxDiameter = math.max(20,vehicle.cp.turnDiameter)
						local verticalWaypointShift = self:getWaypointShift(vehicle,combine)
						combine.cp.verticalWaypointShift = verticalWaypointShift
						--vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0,0,3);
						--vehicle.cp.curTarget.rev = false
						vehicle.cp.nextTargets  = self:createTurnAwayCourse(vehicle,-1,maxDiameter,combine.cp.workWidth)
									
						courseplay:addNewTargetVector(vehicle,combine.cp.workWidth,-(math.max(maxDiameter +vehicle.cp.totalLength+extraAlignLength,maxDiameter +vehicle.cp.totalLength +extraAlignLength -verticalWaypointShift)))
						courseplay:addNewTargetVector(vehicle,combine.cp.workWidth, 2 +verticalWaypointShift,nil,nil,true);
					else
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm right. Turning the Old Way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
						vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, turnDiameter*-1, 0, turnDiameter);
						vehicle.cp.chopperIsTurning = true
					end
				end
				
			else -- chopper will turn right
				if vehicle.cp.combineOffset < 0 then -- I'm right of chopper
					courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm right", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
					vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0, 0, turnDiameter);
					vehicle.cp.curTarget.rev = false
					courseplay:addNewTargetVector(vehicle, 2*turnDiameter,     turnDiameter);
					vehicle.cp.chopperIsTurning = true
				else -- I'm left of chopper
					if vehicle.cp.isReversePossible and not autoCombineCircleMode and combine.cp.forcedSide == nil and combine.cp.multiTools == 1 and vehicle.cp.turnOnField then
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm left. Turning the new way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
						local maxDiameter = math.max(20,vehicle.cp.turnDiameter)
						local verticalWaypointShift = self:getWaypointShift(vehicle,combine)
						combine.cp.verticalWaypointShift = verticalWaypointShift
						--vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, 0,0,3);
						--vehicle.cp.curTarget.rev = false
						vehicle.cp.nextTargets  = self:createTurnAwayCourse(vehicle,1,maxDiameter,combine.cp.workWidth)

						courseplay:addNewTargetVector(vehicle,-combine.cp.workWidth,-(math.max(maxDiameter +vehicle.cp.totalLength+extraAlignLength,maxDiameter +vehicle.cp.totalLength +extraAlignLength -verticalWaypointShift)))
						courseplay:addNewTargetVector(vehicle,-combine.cp.workWidth, 2 +verticalWaypointShift,nil,nil,true);
					else
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm left. Turning the old way", curFile, debug.getinfo(1).currentline, nameNum(vehicle), tostring(combine.name)), 4);
						vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = localToWorld(vehicle.cp.DirectionNode, turnDiameter, 0, turnDiameter);
						vehicle.cp.chopperIsTurning = true
					end
				end
			end

			if vehicle.cp.combineOffsetAutoMode then
				if vehicle.sideToDrive == "right" then
					vehicle.cp.combineOffset = combine.cp.offset * -1;
				elseif vehicle.sideToDrive == "left" then
					vehicle.cp.combineOffset = combine.cp.offset;
				end;
			else
				if vehicle.sideToDrive == "right" then
					vehicle.cp.combineOffset = math.abs(vehicle.cp.combineOffset) * -1;
				elseif vehicle.sideToDrive == "left" then
					vehicle.cp.combineOffset = math.abs(vehicle.cp.combineOffset);
				end;
			end;
			
			print("vehicle.cp.nextTargets: "..tostring(vehicle.cp.nextTargets).." call ppc")
		
			self.tempCourse = Course(self.vehicle, self.vehicle.cp.nextTargets)
			self.ppc:setCourse(self.tempCourse)
			self.ppc:setLookaheadDistance(self.ppc.shortLookaheadDistance)
			self.ppc:initialize(1)
			self:setOnTurnAwayCourse(true)
			self:setModeState(self.STATE_DRIVE_COURSE_ON_FIELD);

		
		end
	end
end

function CombineUnloadAIDriver:onWaypointChange(newIx)
	-- for backwards compatibility, we keep the legacy CP waypoint index up to date
		if not self.onTurnAwayCourse then
		courseplay:setWaypointIndex(self.vehicle, newIx)
	else
		--still needed in reverse(198) till we got rid of vehicle.waypoints everywhere
		local point = self.ppc.course.waypoints[newIx]
		self.vehicle.cp.curTarget.x, self.vehicle.cp.curTarget.z = point.x, point.z
	end
end

function CombineUnloadAIDriver:checkLastWaypoint()
	local hasReachedLastWaypoint = false
	if self.ppc:reachedLastWaypoint() then
		print("self.ppc:reachedLastWaypoint: self.onTurnAwayCourse= "..tostring(self.onTurnAwayCourse))
		if self.onTurnAwayCourse then
			print("setModeState(self.STATE_FOLLOW_PIPE)")
			self:setModeState(self.STATE_FOLLOW_PIPE);
			self:setOnTurnAwayCourse(false)
		else
			print("setModeState(self.STATE_WAIT_AT_START)")
			self:setModeState(self.STATE_WAIT_AT_START)
			courseplay:setIsLoaded(self.vehicle, false);
		end
	end
end

function CombineUnloadAIDriver:followPipe(dt)
	self:checkTurnOnFieldEdge(dt)
	local vehicle = self.vehicle
	local combine = vehicle.cp.activeCombine
	local combineDirNode = combine.cp.DirectionNode or combine.rootNode;
	local refSpeed = vehicle.cp.speeds.field
	local combineIsStopped = combine.lastSpeedReal*3600 < 0.5
	local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode)
	local allowedToDrive = true
	
	speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))

	-- support multiple tippers
	if vehicle.cp.currentTrailerToFill == nil then
		vehicle.cp.currentTrailerToFill = 1
	end

	local currentTipper = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill]

	if currentTipper == nil then
		vehicle.cp.tooIsDirty = true
		return false
	end
	
	if vehicle.cp.currentTrailerToFill ~= nil then
		currentTipper = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill]
		if  not currentTipper.cp.realUnloadOrFillNode then
			currentTipper.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(currentTipper);
		end;
		xt, yt, zt = worldToLocal(currentTipper.cp.realUnloadOrFillNode, x, y, z)
	else
		--courseplay:debug(nameNum(vehicle) .. ": no cp.currentTrailerToFillSet", 4);
		xt, yt, zt = worldToLocal(vehicle.cp.workTools[1].rootNode, x, y, z)
	end

	-- support for tippers like hw80
	if zt < 0 then
		zt = zt * -1
	end

	local trailerOffset = zt + vehicle.cp.tipperOffset
	
	

	--CALCULATE HORIZONTAL OFFSET (side offset)
	if combine.cp.offset == nil and not combine.cp.isChopper then
		self:calculateCombineOffset(vehicle, combine);
	end
	currentX, currentY, currentZ = localToWorld(combineDirNode, vehicle.cp.combineOffset, 0, trailerOffset + 20)

	--CALCULATE VERTICAL OFFSET (tipper offset)
	local prnToCombineZ = self:calculateVerticalOffset(vehicle, combine);

	--SET TARGET UNLOADING COORDINATES @ COMBINE
	local ttX, ttZ = self:getTargetUnloadingCoords(vehicle, combine, trailerOffset, prnToCombineZ);

	local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, ttX, y, ttZ)
	dod = MathUtil.vector2Length(lx, lz)
	if dod > 40 or vehicle.cp.chopperIsTurning == true then
		self:setModeState(self.STATE_DRIVE_TO_COMBINE);
	end
	-- combine is not moving and trailer is under pipe
	--[[if lz < 5 and combine.cp.fillLevel > 100 then 
		-- print(string.format("lz: %.4f, prnToCombineZ: %.2f, trailerOffset: %.2f",lz,prnToCombineZ,trailerOffset))
	end]]
	if not combine.cp.isChopper and combineIsStopped and (lz <= 1 or lz < -0.1 * trailerOffset) then
		courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP"); 
		allowedToDrive = false
	elseif combine.cp.isChopper then
		if (combineIsStopped or courseplay:isSpecialChopper(combine)) and dod == -1 and vehicle.cp.chopperIsTurning == false then
			allowedToDrive = false
			courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");				
		end
		if lz < -2 then
			allowedToDrive = false
			courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");
			-- courseplay:setModeState(vehicle, STATE_DRIVE_TO_COMBINE);
		end
	elseif lz < -1.5 then
			allowedToDrive = false
			courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_WANTS_ME_TO_STOP");
	end
	if vehicle.cp.infoText == nil then
		courseplay:setInfoText(vehicle, "COURSEPLAY_DRIVE_NEXT_TO_COMBINE");
	end
	-- refspeed depends on the distance to the combine
	local combine_speed = combine.lastSpeed*3600
	if combine.cp.isChopper then
		if lz > 20 then
			refSpeed = vehicle.cp.speeds.field
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		elseif lz > 2 and (combine_speed*3600) > 5 then
			refSpeed = math.max(combine_speed *1.5,vehicle.cp.speeds.crawl)
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		elseif lz > 10 then
			refSpeed = vehicle.cp.speeds.turn
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed)) 
		elseif lz < -1 then
			refSpeed = math.max(combine_speed/2,vehicle.cp.speeds.crawl)
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		else
			refSpeed = math.max(combine_speed,vehicle.cp.speeds.crawl)
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		end
		
		if (combineIsTurning and lz < 20) or (combineIsStopped and lz < 5) then
			refSpeed = vehicle.cp.speeds.crawl
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		end
	else
		if lz > 5 then
			refSpeed = vehicle.cp.speeds.field
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		elseif lz < -0.5 then
			refSpeed = math.max(combine_speed - vehicle.cp.speeds.crawl,vehicle.cp.speeds.crawl)
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		elseif lz > 1 or not combine.overloading.isActive then  
			refSpeed = math.max(combine_speed + vehicle.cp.speeds.crawl,vehicle.cp.speeds.crawl)
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		else
			refSpeed = math.max(combine_speed,vehicle.cp.speeds.crawl)
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		end
		if (combineIsTurning and lz < 20) or (vehicle.timer < vehicle.cp.driveSlowTimer) or (combineIsStopped and lz < 15) then
			refSpeed = vehicle.cp.speeds.crawl
			speedDebugLine = ("mode2("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
			if combineIsTurning then
				vehicle.cp.driveSlowTimer = vehicle.timer + 2000
			end
		end
	end
	
	cpDebug:drawLine(x, y, z, 1, 0, 0, ttX, y, ttZ);
	local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, ttX, currentY, ttZ)
	AIDriver.driveVehicleInDirection(self,dt, allowedToDrive, true, lx, lz, refSpeed)
	
end

function CombineUnloadAIDriver:driveNextToCombine(dt)
	local vehicle = self.vehicle
	local combine = vehicle.cp.activeCombine
	local combineDirNode = combine.cp.DirectionNode or combine.rootNode;
	local refSpeed = vehicle.cp.speeds.field
	local allowedToDrive = true
	courseplay:setInfoText(vehicle, "COURSEPLAY_DRIVE_TO_COMBINE"); 
	
	if combine.cp.offset == nil or vehicle.cp.combineOffset == 0 then
		--print("offset not saved - calculate")
		self:calculateCombineOffset(vehicle, combine);
	elseif not combine.cp.isChopper and not combine.cp.isSugarBeetLoader and vehicle.cp.combineOffsetAutoMode and vehicle.cp.combineOffset ~= combine.cp.offset then
		--print("set saved offset")
		vehicle.cp.combineOffset = combine.cp.offset			
	end
	--courseplay:addToCombinesIgnoreList(vehicle, combine)

	--get the coordinates to align with the pipe
	local currentX, currentY, currentZ
	if combine.cp.isSugarBeetLoader then
		local prnToCombineZ = courseplay:calculateVerticalOffset(vehicle, combine);
		currentX, currentY, currentZ = localToWorld(combineDirNode, vehicle.cp.combineOffset, 0, prnToCombineZ -5);
	else			
		currentX, currentY, currentZ = localToWorld(combineDirNode, vehicle.cp.combineOffset, 0, -5);
	end

	local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, currentX, currentY, currentZ)
	AIDriver.driveVehicleInDirection(self,dt, true, true, lx, lz, refSpeed)
	
	local distanceToPoint = courseplay:distanceToPoint(vehicle, currentX, currentY, currentZ)
	
	if distanceToPoint > 50 then
		self:setModeState(self.STATE_DRIVE_TO_COMBINE);
	elseif distanceToPoint < 2 then 
		allowedToDrive = false
		self:setModeState(self.STATE_FOLLOW_PIPE);
		vehicle.cp.chopperIsTurning = false
	end
	local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode)
	cpDebug:drawLine(x, y, z, 1, 0, 0, currentX,currentY, currentZ);
	local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, currentX, currentY, currentZ)
	AIDriver.driveVehicleInDirection(self,dt, allowedToDrive, true, lx, lz, refSpeed)
end

function CombineUnloadAIDriver:driveToCombine(dt)
		local vehicle = self.vehicle
		local combine = vehicle.cp.activeCombine
		local refSpeed = vehicle.cp.speeds.field
		local turnDiameter = vehicle.cp.turnDiameter+2
		local safetyDistance = self:getSafetyDistanceFromCombine( combine )
		courseplay:setInfoText(vehicle, "COURSEPLAY_DRIVE_BEHIND_COMBINE");

		-- calculate a world position (currentX/Y/Z) and a vector (lx/lz) to a point near the combine (which is sometimes called 'tractor')
		-- here, 'tractor' is the combine, x, y, z is the tractor unloading the combine, z1, y1, z1 is the tractor's local coordinates from 
		-- the combine
		local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode)
		local x1, y1, z1 = worldToLocal(combine.cp.DirectionNode or combine.rootNode, x, y, z)
		x1,z1 = x1,z1;

		if not combine.cp.isChopper then
			cx_behind, cy_behind, cz_behind = localToWorld(combine.cp.DirectionNode or combine.rootNode, vehicle.cp.combineOffset, 0, -(turnDiameter + safetyDistance))
		else
			cx_behind, cy_behind, cz_behind = localToWorld(combine.cp.DirectionNode or combine.rootNode, 0, 0, -(turnDiameter + safetyDistance))
		end
		
		if z1 > -(turnDiameter + safetyDistance) then 
			-- tractor in front of combine, drive to a position where we can safely transfer to STATE_DRIVE_TO_REAR mode
			-- left side of combine, 30 meters back, 20 to the left
			local cx_left, cy_left, cz_left = localToWorld(combine.cp.DirectionNode or combine.rootNode, 20, 0, -30)
			-- righ side of combine, 30 meters back, 20 to the right
			local cx_right, cy_right, cz_right = localToWorld(combine.cp.DirectionNode or combine.rootNode, -20, 0, -30)

			local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = MathUtil.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(vehicle.cp.DirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = MathUtil.vector2Length(rx, rz)

			-- prefer the one closest to the combine
			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end

		else
			-- tractor behind combine, drive to a position behind the combine
		  currentX, currentY, currentZ = cx_behind, cy_behind, cz_behind
		end

		-- at this point, currentX/Y/Z is a world position near the combine
		
		-- with no path finding, get vector to currentX/currentZ
		local lx, ly, lz = worldToLocal(vehicle.cp.DirectionNode, currentX, currentY, currentZ)
		lx,lz = lx,lz
		
		dod = MathUtil.vector2Length(lx, lz)
		
		lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, currentX, y, currentZ)
		-- PATHFINDING / REALISTIC DRIVING -
		-- if it is enabled and we are not too close to the combine, we abort STATE_DRIVE_TO_COMBINE mode and 
		-- switch to follow course mode to avoid fruit instead of driving directly 
		-- to currentX/currentZ
		if vehicle.cp.realisticDriving and dod > 20 then 
			-- if there's fruit between me and the combine, calculate a path around it to a point 
			-- behind the combine.
			print("call calculateAstarPathToCoords")
			if self:calculateAstarPathToCoords(vehicle, nil, cx_behind, cz_behind, nil ) then
			  -- there's fruit and a path could be calculated, switch to waypoint mode
				courseplay.debugVehicle( 4, vehicle, "Combine is %.1f meters away, switching to pathfinding, drive to a point %.1f (%.1f safety distance and %.1f turn diameter) behind to combine",
													dod, safetyDistance + turnDiameter, safetyDistance, turnDiameter )
				--courseplay:setCurrentTargetFromList(vehicle, 1);
				--courseplay:setModeState(vehicle, STATE_FOLLOW_TARGET_WPS);
				--courseplay:setMode2NextState(vehicle, STATE_DRIVE_TO_COMBINE); -- modeState when waypoint is reached
				--vehicle.cp.shortestDistToWp = nil;
			end;
		else
			--AIDriver:driveVehicleToLocalPosition(dt, allowedToDrive, moveForwards, gx, gz, maxSpeed)
			--AIDriver.driveVehicleToLocalPosition(self,dt, true, true, currentX, currentZ, refSpeed)
			
			cpDebug:drawLine(x, y, z, 1, 0, 0, currentX,currentY, currentZ);
			AIDriver.driveVehicleInDirection(self,dt, true, true, lx, lz, refSpeed)
		end;
		
	
		-- near point
		if dod < 3 then -- change to vehicle.cp.modeState 4 == drive behind combine or cornChopper
			if combine.cp.isChopper and (not vehicle.cp.chopperIsTurning or combineIsAutoCombine) then -- decide on which side to drive based on ai-combine
				courseplay:sideToDrive(vehicle, combine, 10)
				if vehicle.sideToDrive == "right" then
					vehicle.cp.combineOffset = math.abs(vehicle.cp.combineOffset) * -1;
				else 
					vehicle.cp.combineOffset = math.abs(vehicle.cp.combineOffset);
				end
			end
			self:setModeState(self.STATE_DRIVE_NEXT_TO_COMBINE )	
		end;
end

function CombineUnloadAIDriver:searchForCombines(dt)
	local vehicle = self.vehicle
	
	-- STOP!!
	courseplay:checkSaveFuel(vehicle,false)
	local allowedToDrive = false
	AIVehicleUtil.driveToPoint(vehicle, dt, 1, allowedToDrive, moveForwards, 0, 1, 0, false)
	
	-- are there any combines out there that need my help?
	if CpManager.realTime5SecsTimerThrough then
		if vehicle.cp.lastActiveCombine ~= nil then
			local distance = courseplay:distanceToObject(vehicle, vehicle.cp.lastActiveCombine)
			if distance > 20 or vehicle.cp.totalFillLevelPercent == 100 then
				vehicle.cp.lastActiveCombine = nil
				courseplay:debug(string.format("%s (%s): last combine = nil", nameNum(vehicle), tostring(vehicle.id)), 4);
			else
				courseplay:debug(string.format("%s (%s): last combine is just %.0fm away, so wait", nameNum(vehicle), tostring(vehicle.id), distance), 4);
			end
		end
		if vehicle.cp.lastActiveCombine == nil then -- it's important to call this function in the same loop like nilling  vehicle.cp.lastActiveCombine
			courseplay:updateReachableCombines(vehicle)
		end
	end
	--is any of the reachable combines full?
	if vehicle.cp.reachableCombines ~= nil then
		if #vehicle.cp.reachableCombines > 0 then
			-- choose the combine that needs me the most
			if vehicle.cp.bestCombine ~= nil and vehicle.cp.activeCombine == nil then
				courseplay:debug(string.format("%s (%s): request check-in @ %s", nameNum(vehicle), tostring(vehicle.id), tostring(vehicle.cp.combineID)), 4);
				local registered,combineIsTurning  = self:registerAtCombine(vehicle, vehicle.cp.bestCombine)
				if registered then
					self:setModeState(self.STATE_DRIVE_TO_COMBINE);
				elseif combineIsTurning then
					courseplay:setInfoText(vehicle,"COURSEPLAY_COMBINE_IS_TURNING")
				end
			else
				courseplay:setInfoText(vehicle,"COURSEPLAY_WAITING_FOR_FILL_LEVEL")
			end

			local smallestTimeDiff = math.huge;
			local highest_fill_level = 0;
			local num_courseplayers = 0; --TODO: = fewest courseplayers ?
			local distance = 0;

			vehicle.cp.bestCombine = nil;
			vehicle.cp.combineID = 0;
			vehicle.cp.distanceToCombine = math.huge;

			-- chose the combine who needs me the most
			for k, combine in pairs(vehicle.cp.reachableCombines) do
				courseplay:setOwnFillLevelsAndCapacities(combine)
				local fillLevel, capacity = combine.cp.fillLevel, combine.cp.capacity
				if combine.acParameters ~= nil and combine.acParameters.enabled and combine.isHired and fillLevel >= 0.99*capacity and not combine.cp.isDriving then --AC stops at 99% fillLevel so we have to set this as full
					combine.cp.wantsCourseplayer = true
				end
				if (fillLevel >= (capacity * vehicle.cp.followAtFillLevel / 100)) or capacity == 0 or combine.cp.wantsCourseplayer or combine.cp.isSugarBeetLoader then
					if capacity == 0 or combine.cp.isSugarBeetLoader then
						if combine.courseplayers == nil then
							vehicle.cp.bestCombine = combine
						else
							local numCombineCourseplayers = #combine.courseplayers;
							if numCombineCourseplayers <= num_courseplayers or vehicle.cp.bestCombine == nil then
								num_courseplayers = numCombineCourseplayers;
								if numCombineCourseplayers > 0 then
									frontTractor = combine.courseplayers[num_courseplayers];
									local canFollowFrontTractor = frontTractor.cp.totalFillLevelPercent and frontTractor.cp.totalFillLevelPercent >= vehicle.cp.followAtFillLevel;
									courseplay:debug(string.format('%s: frontTractor (pos %d)=%q, canFollowFrontTractor=%s', nameNum(vehicle), numCombineCourseplayers, nameNum(frontTractor), tostring(canFollowFrontTractor)), 4);
									if canFollowFrontTractor then
										vehicle.cp.bestCombine = combine
									end
								else
									vehicle.cp.bestCombine = combine
								end
							end;
						end 

					elseif fillLevel >= highest_fill_level and combine.cp.isCheckedIn == nil then
						highest_fill_level = fillLevel
						vehicle.cp.bestCombine = combine
						distance = courseplay:distanceToObject(vehicle, combine);
						vehicle.cp.distanceToCombine = distance
						vehicle.cp.callCombineFillLevel = vehicle.cp.totalFillLevelPercent
						vehicle.cp.combineID = combine.id
					end
				-- experimental script for big fields
				-- checks the time needed to reach combine in time and start earlier if it's time to
				-- it's not a precise calculation but it should work somehow... (calculating the true path to all combines every 5 sec is too expensive)
				elseif combine.cp.fillLitersPerSecond and not combine.cp.driverPriorityUseFillLevel then
						local distanceToCombine = courseplay:distanceToObject(vehicle, combine);
						local capacity = combine:getUnitCapacity(combine.spec_combine.fillUnitIndex)
						local fillLevel = combine:getUnitFillLevel(combine.spec.combine.fillUnitIndex)
						local triggerFillLevel = capacity* vehicle.cp.followAtFillLevel / 100
						local timeToReachFillLevel = (triggerFillLevel - fillLevel)/combine.cp.fillLitersPerSecond
						local approxTimeToCombine = distanceToCombine /(vehicle.cp.speeds.field/3.6)
						--print(string.format("timeToReachFillLevel:%s ; approxTimeToCombine: %s ",tostring(timeToReachFillLevel),tostring(approxTimeToCombine)))
						if timeToReachFillLevel < approxTimeToCombine then
							--print(string.format("timeToReachFillLevel:%s ; approxTimeToCombine: %s ",tostring(timeToReachFillLevel),tostring(approxTimeToCombine)))
							if smallestTimeDiff > approxTimeToCombine-timeToReachFillLevel then
								smallestTimeDiff = approxTimeToCombine-timeToReachFillLevel
								local otherIsCloser = false
								--is an other mode2 courseplayer closer ?
								for k, courseplayer in pairs(CpManager.activeCoursePlayers) do
									if courseplayer.cp.mode == 2 and courseplayer.cp.modeState == STATE_WAIT_AT_START then
										local vehiclesDistance = courseplay:distanceToObject(courseplayer, combine);
										if vehiclesDistance < distanceToCombine then
											otherIsCloser = true
											--print(" "..nameNum(courseplayer).." is closer so don't check in")
										end
									end
								end
								if not otherIsCloser then
									vehicle.cp.bestCombine = combine
									vehicle.cp.distanceToCombine = distanceToCombine
									vehicle.cp.callCombineFillLevel = vehicle.cp.totalFillLevelPercent
									vehicle.cp.combineID = combine.id
								end
							end							
						end
				end
			end

			if vehicle.cp.combineID ~= 0 then
				courseplay:debug(string.format("%s (%s): call combine: %s", nameNum(vehicle), tostring(vehicle.id), tostring(vehicle.cp.combineID)), 4);
			end
		elseif vehicle.cp.reachableCombineIsInFruit then
			courseplay:setInfoText(vehicle, "COURSEPLAY_COMBINE_IN_FRUIT");
		else
			courseplay:setInfoText(vehicle, "COURSEPLAY_NO_COMBINE_IN_REACH");
		end
	end

end

function CombineUnloadAIDriver:driveUnloadCourse(dt)
	self.ppc:update()
	local lx, lz = self:getDirectionToGoalPoint()
	-- should we keep driving?
	local allowedToDrive = true
	self:checkLastWaypoint()
	-- RESET TRIGGER RAYCASTS from drive.lua. 
	-- TODO: Not sure how raycast can be called twice if everything is coded cleanly.
	self.vehicle.cp.hasRunRaycastThisLoop['tipTrigger'] = false
	self.vehicle.cp.hasRunRaycastThisLoop['specialTrigger'] = false

	courseplay:updateFillLevelsAndCapacities(self.vehicle)

	local giveUpControl = false

	-- TODO: are these checks really necessary?
	if self.vehicle.cp.totalFillLevel ~= nil
		and self.vehicle.cp.tipRefOffset ~= nil
		and self.vehicle.cp.workToolAttached then

		self:searchForTipTrigger(lx, lz)
		allowedToDrive, giveUpControl = self:unLoad(allowedToDrive, dt)
	else
		self:debug('Safety check failed')
	end
	if giveUpControl then
		-- unload_tippers does the driving
		return
	else
		-- we drive the course as usual
		self:driveCourse(dt, allowedToDrive)
	end
end

function CombineUnloadAIDriver:hasTipTrigger()
	-- TODO: come up with something better?
	return self.vehicle.cp.currentTipTrigger ~= nil
end

function CombineUnloadAIDriver:getSpeed()
	if self:hasTipTrigger() then
		-- slow down around the tip trigger
		if self:getIsInBunksiloTrigger() then
			return self.vehicle.cp.speeds.reverse
		else
			return 10
		end
	elseif self.onTurnAwayCourse then
		return self.vehicle.cp.speeds.turn
	else
		return AIDriver.getSpeed(self)
	end
end

function CombineUnloadAIDriver:getIsInBunksiloTrigger()
	return self.vehicle.cp.backupUnloadSpeed ~= nil
end

function CombineUnloadAIDriver:searchForTipTrigger(lx, lz)
	if not self.vehicle.cp.hasAugerWagon
		and not self:hasTipTrigger()
		and self.vehicle.cp.totalFillLevel > 0
		and self.ppc:getCurrentWaypointIx() > 2
		and not self.ppc:reachedLastWaypoint()
		and not self.ppc:isReversing() then
		local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, lx, -0.1, lz)
		-- raycast start point in front of vehicle
		local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1, 3)
		courseplay:doTriggerRaycasts(self.vehicle, 'tipTrigger', 'fwd', true, x, y, z, nx, ny, nz)
	end
end

function CombineUnloadAIDriver:unLoad(allowedToDrive, dt)
	-- Unloading
	local takeOverSteering = false

	-- If we are an auger wagon, we don't have a tip point, so handle it as an auger wagon in mode 3
	-- This should be in drive.lua on line 305 IMO --pops64
	if self.vehicle.cp.hasAugerWagon then
		courseplay:handleMode3(self.vehicle, allowedToDrive, dt);
	else
		-- done tipping?
		if self:hasTipTrigger() and self.vehicle.cp.totalFillLevel == 0 then
			courseplay:resetTipTrigger(self.vehicle, true);
		end

		self:cleanUpMissedTriggerExit()

		-- tipper is not empty and tractor reaches TipTrigger
		if self.vehicle.cp.totalFillLevel > 0
			and self:hasTipTrigger() then
			allowedToDrive, takeOverSteering = courseplay:unload_tippers(self.vehicle, allowedToDrive, dt);
			courseplay:setInfoText(self.vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
		end
	end
	return allowedToDrive, takeOverSteering;
end;

function CombineUnloadAIDriver:cleanUpMissedTriggerExit() -- at least that's what it seems to be doing
	-- damn, I missed the trigger!
	if self:hasTipTrigger() then
		local t = self.vehicle.cp.currentTipTrigger;
		local trigger_id = t.triggerId;

		if t.specialTriggerId ~= nil then
			trigger_id = t.specialTriggerId;
		end;
		if t.isPlaceableHeapTrigger then
			trigger_id = t.rootNode;
		end;

		if trigger_id ~= nil then
			local trigger_x, _, trigger_z = getWorldTranslation(trigger_id)
			local ctx, _, ctz = getWorldTranslation(self.vehicle.cp.DirectionNode)
			local distToTrigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z)

			-- Start reversing value is to check if we have started to reverse
			-- This is used in case we already registered a tipTrigger but changed the direction and might not be in that tipTrigger when unloading. (Bug Fix)
			local startReversing = self.course:switchingToReverseAt(self.ppc:getCurrentWaypointIx() - 1)
			if startReversing then
				courseplay:debug(string.format("%s: Is starting to reverse. Tip trigger is reset.", nameNum(self.vehicle)), 13);
			end

			local isBGA = t.bunkerSilo ~= nil
			local triggerLength = Utils.getNoNil(self.vehicle.cp.currentTipTrigger.cpActualLength, 20)
			local maxDist = isBGA and (self.vehicle.cp.totalLength + 55) or (self.vehicle.cp.totalLength + triggerLength);
			if distToTrigger > maxDist or startReversing then --it's a backup, so we don't need to care about +/-10m
				courseplay:resetTipTrigger(self.vehicle)
				courseplay:debug(string.format("%s: distance to currentTipTrigger = %d (> %d or start reversing) --> currentTipTrigger = nil", nameNum(self.vehicle), distToTrigger, maxDist), 1);
			end
		else
			courseplay:resetTipTrigger(self.vehicle)
		end;
	end;
end

function CombineUnloadAIDriver:getModeState()
	return self.modeState
end

function CombineUnloadAIDriver:setModeState(newState)
	if self.modeState ~= newState then
		print("CombineUnloadAIDriver:setModeState:"..tostring(self.modeState))
		self.modeState = newState;
	end
end

function CombineUnloadAIDriver:registerAtCombine(callerVehicle, combine)
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
					return false, true
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
				local combineIsInConvoy = combine.cp.convoyActive and combine.cp.convoy.number > 1 
				local pipeIsInFruit = (combine.cp.pipeSide == 1 and fruitSide == "left") or (combine.cp.pipeSide == -1 and fruitSide == "right")
				if pipeIsInFruit and not combineIsInConvoy then
					courseplay:debug(nameNum(callerVehicle)..": path finding active and pipe(pipeSide "..tostring(combine.cp.pipeSide)..") is in fruit -> don't register tractor",4)
					for k, reachableCombine in pairs(callerVehicle.cp.reachableCombines) do
						if reachableCombine == combine then
							courseplay:debug(nameNum(callerVehicle).."removing combine from reachable combines list",4)
							callerVehicle.cp.reachableCombines[k] = nil
							callerVehicle.cp.reachableCombineIsInFruit = true
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
	
	courseplay:askForSpecialSettings(combine:getRootVehicle(), combine)

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