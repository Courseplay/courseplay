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
		self:checkSilo()
	elseif self.levelState == self.states.CHECK_SHIELD then
		self:stopAndWait(dt)
		if self:isModeFillUp(self.vehicle) then
			if self:moveShield('down',dt) then
				self:changeLevelState(self.states.DRIVE_SILOFILLUP)
			end
		else
			--mode Level and compact
		end
	elseif self.levelState == self.states.DRIVE_SILOFILLUP then
		self:driveSiloFillUp(dt)
	end
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



function LevelCompactAIDriver:driveSiloFillUp(dt)
	local vehicle = self.vehicle
	local fwd = true
	local allowedToDrive = true
	local refSpeed = 15
	local cx ,cy,cz = 0,0,0
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil or vehicle.cp.BunkerSiloMap == nil then
			self.bestTarget, self.firstLine = self:getBestTargetFillUnit(vehicle,self.targetSilo,self.bestTarget)
			
			--just for debug reasons
			self.vehicle.cp.actualTarget = self.bestTarget
			--
		end
		
		allowedToDrive = self:moveShield('down',dt)
		fwd = false




		
		local targetUnit = vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
		cx ,cz = targetUnit.cx, targetUnit.cz
		cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
		
		
		self:updateTarget()
		
		
		if self:isAtEnd() 
		or self:lastLineFillLevelChanged()
		or self:isStuck()
		or self:hasShieldEmpty()
		then
			if self:shouldGoToSavePosition() then
				self:changeLevelState(self.states.DRIVE_TO_PARKING)
				self:deleteBestTarget()
				return
			else
				self.fillUpState = self.states.PULLBACK
			end
		end
		
		
		
		
		
		if self:isNearEnd() then
			refSpeed = math.min(10,vehicle.cp.speeds.bunkerSilo)
		else
			refSpeed = math.min(20,vehicle.cp.speeds.bunkerSilo)
		end		
		
		local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, cx,cy,cz);
		if not fwd then
			lx, lz = -lx,-lz
		end
		self:driveInDirection(dt,lx,lz,fwd,refSpeed,allowedToDrive)
	
	
	
	
	
	
	elseif self.fillUpState == self.states.PULLBACK then



		refSpeed = math.min(20,vehicle.cp.speeds.bunkerSilo)
		allowedToDrive = self:moveShield('up',dt)
		cx,cy,cz = self.course:getWaypointPosition(self.course:getNumberOfWaypoints())
		local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, cx,cy,cz);
		self:driveInDirection(dt,lx,lz,fwd,refSpeed,allowedToDrive)
		
		if lz < 0 then
			self.fillUpState = self.states.PUSH
			self:deleteBestTarget()
		end
		
		
		local startUnit = vehicle.cp.BunkerSiloMap[self.firstLine][1]
		local _,ty,_ = getWorldTranslation(self.vehicle.cp.DirectionNode);
		local _,_,z = worldToLocal(vehicle.cp.DirectionNode, startUnit.cx , ty , startUnit.cz);
		if z < -15 then
			self.fillUpState = self.states.PUSH
			self:deleteBestTarget()
		
		end

		
	end
	
	
	
	
	
	
	
	
	
	
	
	--self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
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

function LevelCompactAIDriver:isWaitingForCourseplayers()
	return self.levelState == self.states.WAITIN_FOR_FREE_WAY
end 

function LevelCompactAIDriver:isModeFillUp(vehicle)
	return not vehicle.cp.mode10.leveling
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
		self:changeLevelState(self.states.CHECK_SHIELD)
	end
end

function LevelCompactAIDriver:moveShield(moveUp,dt,fixAlpha)
	local leveler = self.vehicle.cp.workTools[1]
	local moveFinished = false
	if leveler.spec_attacherJointControl ~= nil then
		local spec = leveler.spec_attacherJointControl
		local jointDesc = spec.jointDesc
		if moveUp == "down" then
			
			--move attacherJoint down
			if spec.heightController.moveAlpha ~= jointDesc.lowerAlpha then
				spec.heightTargetAlpha = jointDesc.lowerAlpha
				_, self.savedHeightOverGround,_  = getWorldTranslation(self.vehicle.cp.DirectionNode) --(jointDesc.rotationNode2)
			else
				--tilt attacherJoint till Shield touches ground
				local _, newHeightOverGround,_  = getWorldTranslation(self.vehicle.cp.DirectionNode) --(jointDesc.rotationNode2)
				
				if newHeightOverGround > self.savedHeightOverGround + 0.05 then
					moveFinished = true
				else
					leveler:controlAttacherJoint(spec.controls[2], spec.controls[2].moveAlpha - 0.01)
				end
			end
		elseif moveUp == "up" then
			if spec.heightController.moveAlpha ~= spec.jointDesc.upperAlpha then
				spec.heightTargetAlpha = jointDesc.upperAlpha
				leveler:controlAttacherJoint(spec.controls[2], spec.controls[2].moveAlpha + 0.1)
			else
				moveFinished = true
			end			
		end
	end;
	return moveFinished
end

function LevelCompactAIDriver:getBestTargetFillUnit(vehicle,Silo,actualTarget)
	--print(string.format("courseplay:getActualTarget(vehicle) called by %s",tostring(courseplay.utils:getFnCallPath(3))))
	local newApproach = actualTarget == nil or vehicle.cp.mode10.newApproach
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