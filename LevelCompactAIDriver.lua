--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Thomas Gaertner

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

--[[
handles "mode10": level and compact
--------------------------------------
0)  Course setup:
	a) Start in the silo
	b) drive forward, set waiting point on parking postion out fot the way
	c) drive to the last point which should be alligned with the silo center line and be outside the silo



]]

---@class LevelCompactAIDriver : AIDriver

LevelCompactAIDriver = CpObject(AIDriver)

LevelCompactAIDriver.myStates = {
	DRIVE_TO_PARKING = {},
	WAITIN_FOR_FREE_WAY = {},
	CHECK_SILO = {},
	CHECK_SHIELD = {},
	DRIVE_IN_SILO = {},
	DRIVE_SILOFILLUP ={},
	DRIVE_SILOLEVEL ={},
	PUSH = {},
	PULLBACK = {}
}



--- Constructor
function LevelCompactAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'LevelCompactAIDriver:init') 
	AIDriver.init(self, vehicle)
	self:initStates(LevelCompactAIDriver.myStates)
	self.mode = courseplay.MODE_BUNKERSILO_COMPACTER
	self.refSpeed = 10
	self:setHudContent()
	self.fillUpState = self.states.PUSH
	self.stoppedCourseplayers = {}
end

function LevelCompactAIDriver:setHudContent()
	courseplay.hud:setLevelCompactAIDriverContent(self.vehicle)
	
	
end

function LevelCompactAIDriver:start(ix)
	self:beforeStart()
	
	self.course = Course(self.vehicle , self.vehicle.Waypoints)
	self.ppc:setCourse(self.course)
	self.ppc:initialize()
	self:changeLevelState(self.states.DRIVE_TO_PARKING)
	self.fillUpState = self.states.PUSH
	self.alphaList = nil
	self.lastDrivenColumn = nil
end

function LevelCompactAIDriver:drive(dt)
	-- update current waypoint/goal point
	
	self.allowedToDrive = true
	self:lookOutForCourseplayers()
	self:manageCourseplayersStopping()
	if self.levelState == self.states.DRIVE_TO_PARKING then
		self:moveShield('up',dt)
		self.ppc:update()
		AIDriver.driveCourse(self, dt)
	elseif self.levelState == self.states.WAITIN_FOR_FREE_WAY then
		self:stopAndWait(dt)

		if not self:shouldGoToSavePosition() then
			self:changeLevelState(self.states.DRIVE_TO_PARKING)
		end

	elseif self.levelState == self.states.CHECK_SILO then
		self:stopAndWait(dt)
		if self:checkSilo() then
			self:changeLevelState(self.states.CHECK_SHIELD)
		end
	elseif self.levelState == self.states.CHECK_SHIELD then
		self:stopAndWait(dt)
	
		--record alphaList if not existing
		if self.alphaList == nil then
			self:setIsAlphaListrecording()
		end
		if self:getIsAlphaListrecording() then
			self:recordAlphaList()
		else
			self:selectMode()
		end

	elseif self.levelState == self.states.DRIVE_SILOFILLUP then
		self:driveSiloFillUp(dt)
	elseif self.levelState == self.states.DRIVE_SILOLEVEL then
		self:driveSiloLevel(dt)
	end
end

function LevelCompactAIDriver:selectMode()
	if self:getIsModeFillUp() then
		print("self:changeLevelState(self.states.DRIVE_SILOFILLUP)")
		self:changeLevelState(self.states.DRIVE_SILOFILLUP)
	elseif self:getIsModeLeveling()then
		print("self:changeLevelState(self.states.DRIVE_SILOLEVEL)")
		self:changeLevelState(self.states.DRIVE_SILOLEVEL)
	elseif self:getIsModeCompact()then
		print("self:isModeCompact()")
	end
	self.fillUpState = self.states.PUSH
end

function LevelCompactAIDriver:lookOutForCourseplayers()
	local vehicle = self.vehicle
	if vehicle.cp.mode10.searchCourseplayersOnly then
		for rootNode,courseplayer in pairs (CpManager.activeCoursePlayers) do
			local cx,cy,cz = self.course:getWaypointPosition(1)
			local distance = courseplay:distanceToPoint(courseplayer,cx,cy,cz) --courseplay:nodeToNodeDistance(vehicle.cp.DirectionNode, rootNode)
			--print(string.format("%s: distance = %s",tostring(rootNode),tostring(distance)))
			if distance  < vehicle.cp.mode10.searchRadius and courseplayer ~= vehicle and  courseplayer.cp.totalFillLevel ~= nil then
				local insert = true
				for i=1,#self.stoppedCourseplayers do
					if courseplayer == self.stoppedCourseplayers[i] then
						insert = false
					end
				end
				if insert then
					
					table.insert(self.stoppedCourseplayers ,courseplayer)
					print("add to stoppedCourseplayers: "..tostring(courseplayer).." new number: "..tostring(#self.stoppedCourseplayers))
				end
			end
		end
	else
		for _,steerable in pairs(g_currentMission.enterables) do
			local x,y,z = getWorldTranslation(steerable.rootNode)
			local cx,cy,cz = self.course:getWaypointPosition(1)
			local distance = courseplay:distance(x,z,cx,cz) 
			if distance  < vehicle.cp.mode10.searchRadius and steerable ~= vehicle and steerable.isMotorStarted then
				local insert = true
				for i=1,#self.stoppedCourseplayers do
					if steerable == self.stoppedCourseplayers[i] then
						insert = false
					end
				end
				if insert then
					table.insert(self.stoppedCourseplayers ,steerable)
				end
			end
		end
	end

end

function LevelCompactAIDriver:manageCourseplayersStopping()
	--stop them 
	for i=1, #self.stoppedCourseplayers do
		if not (i==1 and self:isWaitingForCourseplayers()) then
			self:stopCourseplayer(self.stoppedCourseplayers[i])
		end
	end 
	
	--check whether they have left
	for i=1, #self.stoppedCourseplayers do
		local x,y,z = getWorldTranslation(self.stoppedCourseplayers[i].rootNode)
		local cx,cy,cz = self.course:getWaypointPosition(1)
		local distance = courseplay:distance(x,z,cx,cz) 
		if distance  > self.vehicle.cp.mode10.searchRadius and self.stoppedCourseplayers[i].cp.totalFillLevel <1 then
			table.remove(self.stoppedCourseplayers,i)
			print("remove from stoppedCourseplayers: "..tostring(courseplayer).." new number: "..tostring(#self.stoppedCourseplayers))
		end
	end
end


function LevelCompactAIDriver:shouldGoToSavePosition()
	return #self.stoppedCourseplayers > 0 
end 


function LevelCompactAIDriver:stopCourseplayer(courseplayer)
	courseplayer.cp.driver:hold()
end 

function LevelCompactAIDriver:driveSiloLevel(dt)
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil or self.vehicle.cp.BunkerSiloMap == nil then
			self.bestTarget, self.firstLine, self.targetHeight = self:getBestTargetFillUnitLeveling(self.targetSilo,self.lastDrivenColumn)
			--just for debug reasons 
			self.vehicle.cp.actualTarget = self.bestTarget
			--
		end
		renderText(0.2,0.395,0.02,"self:drivePush(dt)")
		
		self:drivePush(dt)
		self:moveShield('down',dt,self:getDiffHeightforHeight(self.targetHeight))
	
		if self:isAtEnd()
		or self:hasShieldEmpty()
		then
			self.fillUpState = self.states.PULLBACK
		end
	
	
	elseif self.fillUpState == self.states.PULLBACK then
		renderText(0.2,0.365,0.02,"self:drivePull(dt)")
		if self:drivePull(dt) then
			self.fillUpState = self.states.PUSH
			self:deleteBestTargetLeveling()
		end
	end
end

function LevelCompactAIDriver:driveSiloFillUp(dt)
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil or self.vehicle.cp.BunkerSiloMap == nil then
			self.bestTarget, self.firstLine = self:getBestTargetFillUnitFillUp(self.targetSilo,self.bestTarget)
			--just for debug reasons 
			self.vehicle.cp.actualTarget = self.bestTarget
			--
		end
		
		self:drivePush(dt)
		self:moveShield('down',dt,0)
		--self:moveShield('down',dt,self:getDiffHeightforHeight(0))
		if self:lastLineFillLevelChanged()
		or self:isStuck()
		--or self:hasShieldEmpty()
		then
			if self:shouldGoToSavePosition() then
				self:changeLevelState(self.states.DRIVE_TO_PARKING)
				self:deleteBestTarget()
				return
			else
				self.fillUpState = self.states.PULLBACK
			end
		end	
	elseif self.fillUpState == self.states.PULLBACK then
		if self:drivePull(dt) or self:getHasMovedToFrontLine(dt) then
			self.fillUpState = self.states.PUSH
			self:deleteBestTarget()
		end
	end
end	
	
function LevelCompactAIDriver:drivePush(dt)
	local vehicle = self.vehicle
	local fwd = false
	local allowedToDrive = true
	local refSpeed = 15
	local cx ,cy,cz = 0,0,0
	
	--get coords of the target point
	local targetUnit = vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
	cx ,cz = targetUnit.cx, targetUnit.cz
	cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	--check whether its time to change the target point	
	self:updateTarget()
	--speed
	if self:isNearEnd() then
		refSpeed = math.min(10,vehicle.cp.speeds.bunkerSilo)
	else
		refSpeed = math.min(20,vehicle.cp.speeds.bunkerSilo)
	end		
	--drive
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, cx,cy,cz);
	if not fwd then
		lx, lz = -lx,-lz
	end
	self:driveInDirection(dt,lx,lz,fwd,refSpeed,allowedToDrive)
end	

function LevelCompactAIDriver:drivePull(dt)
	local pullDone = false
	local fwd = true
	local refSpeed = math.min(20,self.vehicle.cp.speeds.bunkerSilo)
	local allowedToDrive = self:moveShield('up',dt)
	local cx,cy,cz = self.course:getWaypointPosition(self.course:getNumberOfWaypoints())
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, cx,cy,cz);
	self:driveInDirection(dt,lx,lz,fwd,refSpeed,allowedToDrive)
	--end if I moved over the last way point
	if lz < 0 then
		pullDone = true
	end
	return pullDone
end

function LevelCompactAIDriver:getHasMovedToFrontLine(dt)
	local startUnit = self.vehicle.cp.BunkerSiloMap[self.firstLine][1]
	local _,ty,_ = getWorldTranslation(self.vehicle.cp.DirectionNode);
	local _,_,z = worldToLocal(self.vehicle.cp.DirectionNode, startUnit.cx , ty , startUnit.cz);
	if z < -15 then
		return true;			
	end
	return false;
end

function LevelCompactAIDriver:isNearEnd()
	return self.bestTarget.line >= #self.vehicle.cp.BunkerSiloMap-1
end


function LevelCompactAIDriver:lastLineFillLevelChanged()
	local vehicle = self.vehicle
	local newSx = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].sx 
	local newSz = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].sz 
	local newWx = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][#vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap]].wx
	local newWz = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][#vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap]].wz
	local newHx = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].hx
	local newHz = vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap][1].hz
	local wY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newWx, 1, newWz); 
	local hY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newHx, 1, newHz);

	local fillType = DensityMapHeightUtil.getFillTypeAtLine(newWx, wY, newWz, newHx, hY, newHz, 5)
	local newFillLevel = DensityMapHeightUtil.getFillLevelAtArea(fillType, newSx, newSz, newWx, newWz, newHx, newHz )

	if self.savedLastLineFillLevel == nil then
		self.savedLastLineFillLevel = newFillLevel 
	end
	
	if self.savedLastLineFillLevel ~= newFillLevel then
		self.savedLastLineFillLevel = nil
		print("dropout fillLevel")
		return true
		
	end	
end


function LevelCompactAIDriver:isStuck()
	if AIDriver.isStopped(self) then
		if self.vehicle.cp.timers.slipping == nil or self.vehicle.cp.timers.slipping == 0 then
			courseplay:setCustomTimer(self.vehicle, 'slipping', 3);
			--courseplay:debug(('%s: setCustomTimer(..., "slippingStage", 3)'):format(nameNum(self.vehicle)), 10);
		elseif courseplay:timerIsThrough(self.vehicle, 'slipping') then
			--courseplay:debug(('%s: timerIsThrough(..., "slippingStage") -> return isStuck(), reset timer'):format(nameNum(self.vehicle)), 10);
			courseplay:resetCustomTimer(self.vehicle, 'slipping');
			print("dropout isStuck")
			return true
		end;
	else
		courseplay:resetCustomTimer(self.vehicle, 'slipping');
	end

end

function LevelCompactAIDriver:hasShieldEmpty()
	--return self.vehicle.cp.workTools[1]:getFillUnitFillLevel(1) < 100 and self.bestTarget.line > self.firstLine
	if self.vehicle.cp.workTools[1]:getFillUnitFillLevel(1) < 100 then
		if self.vehicle.cp.timers.bladeEmpty == nil or self.vehicle.cp.timers.bladeEmpty == 0 then
			print("setTimer")
			courseplay:setCustomTimer(self.vehicle, 'bladeEmpty', 2);
		elseif courseplay:timerIsThrough(self.vehicle, 'bladeEmpty') and self.bestTarget.line > self.firstLine+1 then 
			courseplay:resetCustomTimer(self.vehicle, 'bladeEmpty');
			print("dropout bladeEmpty")
			return true
		end;
	else
		courseplay:resetCustomTimer(self.vehicle, 'bladeEmpty');
	end	

end

function LevelCompactAIDriver:updateTarget()
	local targetUnit = self.vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
	local cx ,cz = targetUnit.cx, targetUnit.cz
	local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	local x,y,z = getWorldTranslation(self.vehicle.cp.workTools[1].rootNode)
	local distance2Target =  courseplay:distance(x,z, cx, cz) --distance from shovel to target
	if distance2Target < 1 then
		self.bestTarget.line = math.min(self.bestTarget.line + 1,#self.vehicle.cp.BunkerSiloMap)
	end		
end

function LevelCompactAIDriver:isAtEnd()
	local targetUnit = self.vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
	local cx ,cz = targetUnit.cx, targetUnit.cz
	local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	local x,y,z = getWorldTranslation(self.vehicle.cp.workTools[1].rootNode)
	local distance2Target =  courseplay:distance(x,z, cx, cz) --distance from shovel to target
	if distance2Target < 1 then
		if self.bestTarget.line == #self.vehicle.cp.BunkerSiloMap then
			print("dropout atEnd")
			return true
		end
	end
end

function LevelCompactAIDriver:deleteBestTarget()
	self.bestTarget = nil
end

function LevelCompactAIDriver:deleteBestTargetLeveling()
	self.lastDrivenColumn = self.bestTarget.column
	self.bestTarget = nil
end


function LevelCompactAIDriver:isWaitingForCourseplayers()
	return self.levelState == self.states.WAITIN_FOR_FREE_WAY
end 

function LevelCompactAIDriver:getIsModeFillUp()
	return not self.vehicle.cp.mode10.leveling
end

function LevelCompactAIDriver:getIsModeLeveling()
	return self.vehicle.cp.mode10.leveling and not self.vehicle.cp.mode10.drivingThroughtLoading
end

function LevelCompactAIDriver:getIsModeCompact()
	return self.vehicle.cp.mode10.leveling and self.vehicle.cp.mode10.drivingThroughtLoading
end

function LevelCompactAIDriver:onWaypointPassed(ix)
	if self.course:isWaitAt(ix) then
		self:changeLevelState(self.states.WAITIN_FOR_FREE_WAY)
	end
	AIDriver.onWaypointPassed(self, ix)
end

function LevelCompactAIDriver:continue()
	self:changeLevelState(self.states.DRIVE_TO_PARKING)
end

function LevelCompactAIDriver:stopAndWait(dt)
	self:driveInDirection(dt,0,1,true,0,false)
end

function LevelCompactAIDriver:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function LevelCompactAIDriver:onEndCourse()
	self.ppc:initialize(1)
	self:changeLevelState(self.states.CHECK_SILO)
end

function LevelCompactAIDriver:updateLastMoveCommandTime()
	AIDriver.setLastMoveCommandTime(self, self.vehicle.timer)
end

function LevelCompactAIDriver:changeLevelState(newState)
	self.levelState = newState
end

function LevelCompactAIDriver:findNextRevWaypoint(currentPoint)
	local vehicle = self.vehicle;
	local _,ty,_ = getWorldTranslation(vehicle.cp.DirectionNode);
	for i= currentPoint, self.vehicle.cp.numWaypoints do
		local _,_,z = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[i].cx , ty , vehicle.Waypoints[i].cz);
		if z < -3 and vehicle.Waypoints[i].rev  then
			return i
		end;
	end;
	return currentPoint;
end

function LevelCompactAIDriver:getSpeed()
	local speed = 0
	if self.levelState == self.states.DRIVE_TO_PARKING then
		speed = AIDriver.getRecordedSpeed(self)
	else
		speed = self.refSpeed
	end	
	return speed
end

function LevelCompactAIDriver:debug(...)
	courseplay.debugVehicle(10, self.vehicle, ...)
end

function LevelCompactAIDriver:checkSilo()
	if self.targetSilo == nil then
		self.targetSilo = courseplay:getMode9TargetBunkerSilo(self.vehicle,1)
	end
	if not self.targetSilo then
		courseplay:setInfoText(self.vehicle, courseplay:loc('COURSEPLAY_MODE10_NOSILO'));
	else
		return true
	end
end

function LevelCompactAIDriver:moveShield(moveDir,dt,fixHeight)
	local leveler = self.vehicle.cp.workTools[1]
	local moveFinished = false
	if leveler.spec_attacherJointControl ~= nil then
		local spec = leveler.spec_attacherJointControl
		local jointDesc = spec.jointDesc
		if moveDir == "down" then
			
			--move attacherJoint down
			if spec.heightController.moveAlpha ~= jointDesc.lowerAlpha then
				spec.heightTargetAlpha = jointDesc.lowerAlpha
			else
				local newAlpha = self:getClosestAlpha(fixHeight)
				leveler:controlAttacherJoint(spec.controls[2],newAlpha)				
				moveFinished = true
			end

		elseif moveDir == "up" then
			if spec.heightController.moveAlpha ~= spec.jointDesc.upperAlpha then
				spec.heightTargetAlpha = jointDesc.upperAlpha
				if not fixHeight then
					leveler:controlAttacherJoint(spec.controls[2], spec.controls[2].moveAlpha + 0.1)
				end
			else
				moveFinished = true
			end			
		end
	end;
	return moveFinished
end

function LevelCompactAIDriver:getClosestAlpha(height)
	local closestIndex = 99
	local closestValue = 99
	for indexHeight,_ in pairs (self.alphaList) do
		--print("try "..tostring(indexHeight))
		local diff = math.abs(height-indexHeight)
		if closestValue > diff then
			--print(string.format("%s is closer- set as closest",tostring(closestValue)))
			closestIndex = indexHeight
			closestValue = diff
		end				
	end
	return self.alphaList[closestIndex]
end

function LevelCompactAIDriver:getIsAlphaListrecording()
	return self.isAlphaListrecording;
end

function LevelCompactAIDriver:resetIsAlphaListrecording()
	self.isAlphaListrecording = nil
end
function LevelCompactAIDriver:setIsAlphaListrecording()
	self.isAlphaListrecording = true
	self.alphaList ={}
end
function LevelCompactAIDriver:getDiffHeightforHeight(targetHeight)
	local blade = self.vehicle.cp.workTools[1]
	local bladeX,bladeY,bladeZ = getWorldTranslation(self:getLevelerNode(blade))
	local bladeTerrain = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, bladeX,bladeY,bladeZ);
	local _,_,offSetZ = worldToLocal(self.vehicle.rootNode,bladeX,bladeY,bladeZ)
	local _,projectedTractorY,_  = localToWorld(self.vehicle.rootNode,0,0,offSetZ)

	return targetHeight- (projectedTractorY-bladeTerrain)
end


function LevelCompactAIDriver:recordAlphaList()
	local blade = self.vehicle.cp.workTools[1]
	local spec = blade.spec_attacherJointControl
	local jointDesc = spec.jointDesc
	local bladeX,bladeY,bladeZ = getWorldTranslation(self:getLevelerNode(blade))
	local bladeTerrain = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, bladeX,bladeY,bladeZ);
	local _,_,offSetZ = worldToLocal(self.vehicle.rootNode,bladeX,bladeY,bladeZ)
	local _,projectedTractorY,_  = localToWorld(self.vehicle.rootNode,0,0,offSetZ) 
	local tractorToGround = courseplay:round(projectedTractorY-bladeTerrain,3)
	local bladeToGound = courseplay:round(bladeY-bladeTerrain,3)
	
	if spec.heightController.moveAlpha ~= jointDesc.lowerAlpha then
		spec.heightTargetAlpha = jointDesc.lowerAlpha
		blade:controlAttacherJoint(spec.controls[2], spec.controls[2].moveAlpha + 0.1)
	else
		blade:controlAttacherJoint(spec.controls[2], spec.controls[2].moveAlpha - 0.005)
		
		--record the related alphas to the alpha list
		local alphaEntry = courseplay:round(bladeToGound-tractorToGround,3)
		if self.alphaList[alphaEntry] ~= nil then
			print("resetIsAlphaListrecording")
			self:resetIsAlphaListrecording()
		else
			print(string.format("self.alphaList[%s] = %s",tostring(alphaEntry),tostring(spec.controls[2].moveAlpha)))
			self.alphaList[alphaEntry] = spec.controls[2].moveAlpha 
		end	
	end
end

function LevelCompactAIDriver:getLevelerNode(blade)
	for _, levelerNode in pairs (blade.spec_leveler.nodes) do
		if levelerNode.node ~= nil then
			return levelerNode.node
		end
	end
end

function LevelCompactAIDriver:getBestTargetFillUnitFillUp(Silo,actualTarget)
	--print(string.format("courseplay:getActualTarget(vehicle) called by %s",tostring(courseplay.utils:getFnCallPath(3))))
	local vehicle = self.vehicle
	local firstLine = 0
	vehicle.cp.BunkerSiloMap = courseplay:createBunkerSiloMap(vehicle, Silo)
	if vehicle.cp.BunkerSiloMap ~= nil then
		local stopSearching = false
		local mostFillLevelAtLine = 0
		local mostFillLevelIndex = 2
		local fillLevelsPerColumn = {}
		local levelingTarget = {}
		local fillingTarget = {}
		local totalFillLevel = Silo.fillLevel
		if courseplay.debugChannels[10] then
			for lineIndex, line in pairs(vehicle.cp.BunkerSiloMap) do
				local printString = ""
				for column, fillUnit in pairs(line) do
					if fillUnit.fillLevel > 10000 then
						printString = printString.."[XXX]"
					elseif fillUnit.fillLevel > 1000 then
						printString = printString.."[ XX]"
					elseif fillUnit.fillLevel > 0 then
						printString = printString.."[ X ]"
					else
						printString = printString.."[   ]"
					end
				end
				print(printString)
			end
		end
		
		-- find column with most fillLevel and figure out whether its empty
		for lineIndex, line in pairs(vehicle.cp.BunkerSiloMap) do
			if stopSearching then
				break
			end
			mostFillLevelAtLine = 0
			for column, fillUnit in pairs(line) do
				if 	mostFillLevelAtLine < fillUnit.fillLevel then
					mostFillLevelAtLine = fillUnit.fillLevel
					mostFillLevelIndex = column
				end
				if column == #line and mostFillLevelAtLine > 0 then
					fillUnit = line[mostFillLevelIndex]
					fillingTarget = {
										line = lineIndex;
										column = mostFillLevelIndex;
										empty = false;
												}
					stopSearching = true
					break
				end
			end
		end
		if mostFillLevelAtLine == 0 then
			fillingTarget = {
										line = 1;
										column = 1;
										empty = true;
												}
		end
		
		if vehicle.cp.mode10.leveling and not fillingTarget.empty then
			actualTarget = levelingTarget
		else
			actualTarget = fillingTarget
		end
		firstLine = actualTarget.line
	end
	
	return actualTarget, firstLine
end

function LevelCompactAIDriver:getBestTargetFillUnitLeveling(Silo,lastDrivenColumn)
	local firstLine = 1
	local targetHeight = 0.5
	local vehicle = self.vehicle
	local newApproach = lastDrivenColumn == nil 
	local newBestTarget = {}
	vehicle.cp.BunkerSiloMap = courseplay:createBunkerSiloMap(vehicle, Silo)
	if not printOnce then
		printOnce = true
		courseplay:printMeThisTable(vehicle.cp.BunkerSiloMap,0,5,"vehicle.cp.BunkerSiloMap")
	end
	if vehicle.cp.BunkerSiloMap ~= nil then
		local newColumn = math.ceil(#vehicle.cp.BunkerSiloMap[1]/2)
		if newApproach then
			newBestTarget = { 
								line = 1;
								column = newColumn;
								empty = false;
								}
		else
			newColumn = lastDrivenColumn +1;
			if newColumn > #vehicle.cp.BunkerSiloMap[1] then
				newColumn = 1;
			end
			newBestTarget= {
							line = 1;
							column = newColumn;							
							empty = false;
							}
		end
		targetHeight = self:getColumnsTargetHeight(newColumn)
	end
	
	return newBestTarget, firstLine, targetHeight
end

function LevelCompactAIDriver:getColumnsTargetHeight(newColumn)
	local totalArea = 0
	local totalFillLevel = 0
	for i=1,#self.vehicle.cp.BunkerSiloMap do
		totalArea = totalArea + self.vehicle.cp.BunkerSiloMap[i][newColumn].area
		totalFillLevel = totalFillLevel + self.vehicle.cp.BunkerSiloMap[i][newColumn].fillLevel
	end
	local newHeight = math.max(0.3,(totalFillLevel/1000)/totalArea)
	print(string.format("getTargetHeigth: totalFillLevel:%s; totalArea:%s Height%s",tostring(totalFillLevel),tostring(totalArea),tostring(newHeight)))
	return newHeight
	
end