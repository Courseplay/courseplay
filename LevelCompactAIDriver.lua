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
	DRIVE_TO_PARKING = {checkForTrafficConflict = true},
	WAITING_FOR_FREE_WAY = {},
	CHECK_SILO = {},
	CHECK_SHIELD = {},
	DRIVE_IN_SILO = {},
	DRIVE_SILOFILLUP ={},
	DRIVE_SILOLEVEL ={},
	DRIVE_SILOCOMPACT = {},
	PUSH = {},
	PULLBACK = {}
}

--- Constructor
function LevelCompactAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'LevelCompactAIDriver:init') 
	AIDriver.init(self, vehicle)
	self:initStates(LevelCompactAIDriver.myStates)
	self.mode = courseplay.MODE_BUNKERSILO_COMPACTER
	self.debugChannel = 10
	self.refSpeed = 10
	self:setHudContent()
	self.fillUpState = self.states.PUSH
	self.stoppedCourseplayers = {}
	self:setLevelerWorkWidth()
end

function LevelCompactAIDriver:setHudContent()
	courseplay.hud:setLevelCompactAIDriverContent(self.vehicle)
end

function LevelCompactAIDriver:start(startingPoint)
	AIDriver.start(self,startingPoint)
	self:changeLevelState(self.states.DRIVE_TO_PARKING)
	self.fillUpState = self.states.PUSH
	self.alphaList = nil
	self.lastDrivenColumn = nil
	-- reset target silo in case we want to work on a different one...
	self.targetSilo = nil
	self:setLevelerWorkWidth()
end

function LevelCompactAIDriver:drive(dt)
	-- update current waypoint/goal point
	self:drawMap()
	self.allowedToDrive = true
	self:lookOutForCourseplayers()
	self:manageCourseplayersStopping()
	if self.levelState == self.states.DRIVE_TO_PARKING then
		self:moveShield('up',dt)
		self.ppc:update()
		AIDriver.driveCourse(self, dt)
	elseif self.levelState == self.states.WAITING_FOR_FREE_WAY then
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
		if self:checkShield() then
			self:selectMode()
		end
	elseif self.levelState == self.states.DRIVE_SILOFILLUP then
		self:driveSiloFillUp(dt)
	elseif self.levelState == self.states.DRIVE_SILOLEVEL then
		self:driveSiloLevel(dt)
	elseif self.levelState == self.states.DRIVE_SILOCOMPACT then
		self:driveSiloCompact(dt)
	end
end

function LevelCompactAIDriver:isTrafficConflictDetectionEnabled()
	return self.trafficConflictDetectionEnabled and self.levelState and self.levelState.properties.checkForTrafficConflict
end

function LevelCompactAIDriver:checkShield()
	local workTool = self.vehicle.cp.workTools[1]
	
	if SpecializationUtil.hasSpecialization(Leveler, workTool.specializations) then
		if self:getIsModeFillUp() or self:getIsModeLeveling() then
			--record alphaList if not existing
			if self.alphaList == nil then
				self:setIsAlphaListrecording()
			end
			if self:getIsAlphaListrecording() then
				self:recordAlphaList()
			else
				return true
			end
		else
			courseplay:setInfoText(self.vehicle, 'COURSEPLAY_WRONG_TOOL');
		end
	elseif SpecializationUtil.hasSpecialization(BunkerSiloCompacter, workTool.specializations) then
		if self:getIsModeCompact() then
			return true
		else
			courseplay:setInfoText(self.vehicle, 'COURSEPLAY_WRONG_TOOL');
		end
	end		
end


function LevelCompactAIDriver:selectMode()
	if self:getIsModeFillUp() then
		self:debug("self:getIsModeFillUp()")
		self:changeLevelState(self.states.DRIVE_SILOFILLUP)
	elseif self:getIsModeLeveling() then
		self:debug("self:getIsModeLeveling()")
		self:changeLevelState(self.states.DRIVE_SILOLEVEL)
	elseif self:getIsModeCompact()then
		self:debug("self:isModeCompact()")
		self:changeLevelState(self.states.DRIVE_SILOCOMPACT)
	end
	self.fillUpState = self.states.PUSH
end

function LevelCompactAIDriver:lookOutForCourseplayers()
	local vehicle = self.vehicle
	if vehicle.cp.mode10.searchCourseplayersOnly then
		for rootNode,courseplayer in pairs (CpManager.activeCoursePlayers) do
			local cx,cy,cz = self.course:getWaypointPosition(1)
			local distance = courseplay:distanceToPoint(courseplayer,cx,cy,cz) --courseplay:nodeToNodeDistance(vehicle.cp.directionNode, rootNode)
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
					self:debug("add to stoppedCourseplayers: "..tostring(courseplayer).." new number: "..tostring(#self.stoppedCourseplayers))
				end
			end
		end
	else
		for _,steerable in pairs(g_currentMission.enterables) do
			local x,y,z = getWorldTranslation(steerable.rootNode)
			local cx,cy,cz = self.course:getWaypointPosition(1)
			local distance = courseplay:distance(x,z,cx,cz)
			if distance  < vehicle.cp.mode10.searchRadius and steerable ~= vehicle and (steerable.getIsMotorStarted and steerable:getIsMotorStarted()) then
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
			self:debug("remove from stoppedCourseplayers: "..tostring(courseplayer).." new number: "..tostring(#self.stoppedCourseplayers))
		end
	end
end


function LevelCompactAIDriver:shouldGoToSavePosition()
	return #self.stoppedCourseplayers > 0 
end 


function LevelCompactAIDriver:stopCourseplayer(courseplayer)
	if courseplayer.cp.driver ~= nil then
		courseplayer.cp.driver:hold()
	end
	if courseplayer ~= nil and courseplayer.spec_autodrive and courseplayer.spec_autodrive.HoldDriving then
		courseplayer.spec_autodrive:HoldDriving(courseplayer)
	end
end 

function LevelCompactAIDriver:driveSiloCompact(dt)
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil or self.vehicle.cp.BunkerSiloMap == nil then
			self.bestTarget, self.firstLine, self.targetHeight = self:getBestTargetFillUnitLeveling(self.targetSilo,self.lastDrivenColumn)
		end

		self:drivePush(dt)
		self:lowerImplements()
		if self:isAtEnd() then
			if self:shouldGoToSavePosition() then
				self:changeLevelState(self.states.DRIVE_TO_PARKING)
				self:deleteBestTarget()
				self:raiseImplements()
				return
			else
				self.fillUpState = self.states.PULLBACK
			end
		end
	
	elseif self.fillUpState == self.states.PULLBACK then
		if self:drivePull(dt) then
			self.fillUpState = self.states.PUSH
			self:deleteBestTargetLeveling()
			self:raiseImplements()
		end
	end
end

function LevelCompactAIDriver:driveSiloLevel(dt)
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil or self.vehicle.cp.BunkerSiloMap == nil then
			self.bestTarget, self.firstLine, self.targetHeight = self:getBestTargetFillUnitLeveling(self.targetSilo,self.lastDrivenColumn)
		end
		renderText(0.2,0.395,0.02,"self:drivePush(dt)")

		self:drivePush(dt)
		self:moveShield('down',dt,self:getDiffHeightforHeight(self.targetHeight))
	
		if self:isAtEnd()
		or self:hasShieldEmpty()
		or self:isStuck()
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
		renderText(0.2,0.365,0.02,"self:drivePull(dt)")
		self:moveShield('up',dt)
		if self:isStuck() then
			self.fillUpState = self.states.PUSH
		end
		if self:drivePull(dt) then
			self.fillUpState = self.states.PUSH
			self:deleteBestTargetLeveling()
		end
	end
end

function LevelCompactAIDriver:driveSiloFillUp(dt)
--	self:drawMap()
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil or self.vehicle.cp.BunkerSiloMap == nil then
			self.bestTarget, self.firstLine = self:getBestTargetFillUnitFillUp(self.targetSilo,self.bestTarget)
		end

		self:drivePush(dt)
		self:moveShield('down',dt,0)
		--self:moveShield('down',dt,self:getDiffHeightforHeight(0))
		if self:lastLineFillLevelChanged()
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
	elseif self.fillUpState == self.states.PULLBACK then
		self:moveShield('up',dt)
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
	local cx, cy, cz = 0,0,0
	
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
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, cx,cy,cz);
	if not fwd then
		lx, lz = -lx,-lz
	end
	self:debugRouting()
--	self:drawMap()
	self:driveInDirection(dt,lx,lz,fwd,refSpeed,allowedToDrive)
end	

function LevelCompactAIDriver:drivePull(dt)
	local pullDone = false
	local fwd = true
	local refSpeed = math.min(20,self.vehicle.cp.speeds.bunkerSilo)
	local allowedToDrive = true 
	local cx,cy,cz = self.course:getWaypointPosition(self.course:getNumberOfWaypoints())
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, cx,cy,cz);
	self:driveInDirection(dt,lx,lz,fwd,refSpeed,allowedToDrive)
	--end if I moved over the last way point
	if lz < 0 then
		pullDone = true
	end
--	self:drawMap()
	return pullDone
end

function LevelCompactAIDriver:getHasMovedToFrontLine(dt)
	local startUnit = self.vehicle.cp.BunkerSiloMap[self.firstLine][1]
	local _,ty,_ = getWorldTranslation(self.vehicle.cp.directionNode);
	local _,_,z = worldToLocal(self.vehicle.cp.directionNode, startUnit.cx , ty , startUnit.cz);
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
		self:debug("dropout fillLevel")
		return true
		
	end	
end


function LevelCompactAIDriver:isStuck()
	if self:doesNotMove() then
		if self.vehicle.cp.timers.slipping == nil or self.vehicle.cp.timers.slipping == 0 then
			courseplay:setCustomTimer(self.vehicle, 'slipping', 3);
			--courseplay:debug(('%s: setCustomTimer(..., "slippingStage", 3)'):format(nameNum(self.vehicle)), 10);
		elseif courseplay:timerIsThrough(self.vehicle, 'slipping') then
			--courseplay:debug(('%s: timerIsThrough(..., "slippingStage") -> return isStuck(), reset timer'):format(nameNum(self.vehicle)), 10);
			courseplay:resetCustomTimer(self.vehicle, 'slipping');
			self:debug("dropout isStuck")
			return true
		end;
	else
		courseplay:resetCustomTimer(self.vehicle, 'slipping');
	end

end

function LevelCompactAIDriver:doesNotMove()
	-- giants supplied last speed is in mm/s;
	-- does not move if we are less than 1km/h
	return math.abs(self.vehicle.lastSpeedReal) < 1/3600 and self.bestTarget.line > self.firstLine+1
end

function LevelCompactAIDriver:hasShieldEmpty()
	--return self.vehicle.cp.workTools[1]:getFillUnitFillLevel(1) < 100 and self.bestTarget.line > self.firstLine
	if self.vehicle.cp.workTools[1]:getFillUnitFillLevel(1) < 100 then
		if self.vehicle.cp.timers.bladeEmpty == nil or self.vehicle.cp.timers.bladeEmpty == 0 then
			courseplay:setCustomTimer(self.vehicle, 'bladeEmpty', 3);
		elseif courseplay:timerIsThrough(self.vehicle, 'bladeEmpty') and self.bestTarget.line > self.firstLine + 1 then
			courseplay:resetCustomTimer(self.vehicle, 'bladeEmpty');
			self:debug("dropout bladeEmpty")
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
		self.bestTarget.line = math.min(self.bestTarget.line + 1, #self.vehicle.cp.BunkerSiloMap)
	end		
end

function LevelCompactAIDriver:isAtEnd()
	if not self.vehicle.cp.BunkerSiloMap or not bestTarget then 
		return
	end
	
	local targetUnit = self.vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
	local cx ,cz = targetUnit.cx, targetUnit.cz
	local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	local x,y,z = getWorldTranslation(self.vehicle.cp.workTools[1].rootNode)
	local distance2Target =  courseplay:distance(x,z, cx, cz) --distance from shovel to target
	if distance2Target < 1 then
		if self.bestTarget.line == #self.vehicle.cp.BunkerSiloMap then
			self:debug("dropout atEnd")
			return true
		end
	end
end

function LevelCompactAIDriver:deleteBestTarget()
	self.lastDrivenColumn = nil
	self.bestTarget = nil
end

function LevelCompactAIDriver:deleteBestTargetLeveling()
	self.lastDrivenColumn = self.bestTarget.column
	self.bestTarget = nil
end


function LevelCompactAIDriver:isWaitingForCourseplayers()
	return self.levelState == self.states.WAITING_FOR_FREE_WAY
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
		self:changeLevelState(self.states.WAITING_FOR_FREE_WAY)
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
	self:resetLastMoveCommandTime()
end

function LevelCompactAIDriver:changeLevelState(newState)
	self.levelState = newState
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

function LevelCompactAIDriver:lowerImplements()
	for _, implement in pairs(self.vehicle:getAttachedImplements()) do
		if implement.object.aiImplementStartLine then
			implement.object:aiImplementStartLine()
		end
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)
end

function LevelCompactAIDriver:raiseImplements()
	for _, implement in pairs(self.vehicle:getAttachedImplements()) do
		if implement.object.aiImplementEndLine then
			implement.object:aiImplementEndLine()
		end
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
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
			self:debug("resetIsAlphaListrecording")
			self:resetIsAlphaListrecording()
		else
			self:debug(string.format("self.alphaList[%s] = %s",tostring(alphaEntry),tostring(spec.controls[2].moveAlpha)))
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

function LevelCompactAIDriver:printMap()
	if courseplay.debugChannels[10] and self.vehicle.cp.BunkerSiloMap then
		for _, line in pairs(self.vehicle.cp.BunkerSiloMap) do
			local printString = ""
			for _, fillUnit in pairs(line) do
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
			self:debug(printString)
		end
	end
end

function LevelCompactAIDriver:getBestTargetFillUnitFillUp(Silo,actualTarget)
	--print(string.format("courseplay:getActualTarget(vehicle) called by %s",tostring(courseplay.utils:getFnCallPath(3))))
	local vehicle = self.vehicle
	local firstLine = 0
	vehicle.cp.BunkerSiloMap = g_bunkerSiloManager:createBunkerSiloMap(vehicle, Silo, self:getWorkWidth())
	if vehicle.cp.BunkerSiloMap ~= nil then
		local stopSearching = false
		local mostFillLevelAtLine = 0
		local mostFillLevelIndex = 2
		local fillingTarget = {}

		-- find column with most fillLevel and figure out whether it is empty
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
		
		actualTarget = fillingTarget
		firstLine = actualTarget.line
	end
	
	return actualTarget, firstLine
end
-- TODO: create a BunkerSiloMap class ...
-- Find the first row in the map where this column is not empty
function LevelCompactAIDriver:findFirstNonEmptyRow(map, column)
	for i, row in ipairs(map) do
		if row[column].fillLevel > 0 then
			return i
		end
	end
	return #map
end

function LevelCompactAIDriver:getBestTargetFillUnitLeveling(Silo, lastDrivenColumn)
	local firstLine = 1
	local targetHeight = 0.5
	local vehicle = self.vehicle
	local newApproach = lastDrivenColumn == nil 
	local newBestTarget = {}
	vehicle.cp.BunkerSiloMap = g_bunkerSiloManager:createBunkerSiloMap(vehicle, Silo, self:getWorkWidth())
	if vehicle.cp.BunkerSiloMap ~= nil then
		local newColumn = math.ceil(#vehicle.cp.BunkerSiloMap[1]/2)
		if newApproach then
			newBestTarget, firstLine = self:getBestTargetFillUnitFillUp(Silo, {})
			self:debug('Best leveling target at line %d, column %d, height %d, first line %d (fist approach)',
					newBestTarget.line, newBestTarget.column, targetHeight, firstLine)
			return newBestTarget, firstLine, targetHeight
		else
			newColumn = lastDrivenColumn + 1;
			if newColumn > #vehicle.cp.BunkerSiloMap[1] then
				newColumn = 1;
			end
			firstLine = self:findFirstNonEmptyRow(vehicle.cp.BunkerSiloMap, newColumn)
			newBestTarget= {
							line = firstLine;
							column = newColumn;							
							empty = false;
							}
		end
		targetHeight = self:getColumnsTargetHeight(newColumn)
	end
	self:debug('Best leveling target at line %d, column %d, height %d, first line %d',
			newBestTarget.line, newBestTarget.column, targetHeight, firstLine)
	return newBestTarget, firstLine, targetHeight
end

function LevelCompactAIDriver:getColumnsTargetHeight(newColumn)
	local totalArea = 0
	local totalFillLevel = 0
	for i=1,#self.vehicle.cp.BunkerSiloMap do
		--calculate the area without first and last line
		if i~= 1 and i~= #self.vehicle.cp.BunkerSiloMap then
			totalArea = totalArea + self.vehicle.cp.BunkerSiloMap[i][newColumn].area
		end
		totalFillLevel = totalFillLevel + self.vehicle.cp.BunkerSiloMap[i][newColumn].fillLevel
	end
	local newHeight = math.max(0.6,(totalFillLevel/1000)/totalArea)
	self:debug("getTargetHeight: totalFillLevel:%s; totalArea:%s Height%s",tostring(totalFillLevel),tostring(totalArea),tostring(newHeight))
	return newHeight
	
end

function LevelCompactAIDriver:debugRouting()
	if courseplay.debugChannels[10] and self.vehicle.cp.BunkerSiloMap ~= nil and self.bestTarget ~= nil then

		local fillUnit = self.vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
		--print(string.format("fillUnit %s; self.cp.actualTarget.line %s; self.cp.actualTarget.column %s",tostring(fillUnit),tostring(self.cp.actualTarget.line),tostring(self.cp.actualTarget.column)))
		local sx,sz = fillUnit.sx,fillUnit.sz
		local wx,wz = fillUnit.wx,fillUnit.wz
		local bx,bz = fillUnit.bx,fillUnit.bz
		local hx,hz = fillUnit.hx +(fillUnit.wx-fillUnit.sx) ,fillUnit.hz +(fillUnit.wz-fillUnit.sz)
		local _,tractorHeight,_ = getWorldTranslation(self.vehicle.cp.directionNode)
		local y = tractorHeight + 1.5;

		cpDebug:drawLine(sx, y, sz, 1, 0, 0, wx, y, wz);
		cpDebug:drawLine(wx, y, wz, 1, 0, 0, hx, y, hz);
		cpDebug:drawLine(fillUnit.hx, y, fillUnit.hz, 1, 0, 0, sx, y, sz);
		cpDebug:drawLine(fillUnit.cx, y, fillUnit.cz, 1, 0, 1, bx, y, bz);
		cpDebug:drawPoint(fillUnit.cx, y, fillUnit.cz, 1, 1 , 1);

		local bunker = self.targetSilo
		if bunker ~= nil then
			local sx,sz = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local wx,wz = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local hx,hz = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			cpDebug:drawLine(sx,y+2,sz, 0, 0, 1, wx,y+2,wz);
			--drawDebugLine(sx,y+2,sz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
			--drawDebugLine(wx,y+2,wz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
			cpDebug:drawLine(sx,y+2,sz, 0, 0, 1, hx,y+2,hz);
			cpDebug:drawLine(wx,y+2,wz, 0, 0, 1, hx,y+2,hz);
		end
		if self.tempTarget ~= nil then
			local tx,tz = self.tempTarget.cx,self.tempTarget.cz
			local fillUnit = self.vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
			local sx,sz = fillUnit.sx,fillUnit.sz
			cpDebug:drawLine(tx, y, tz, 1, 0, 1, sx, y, sz);
			cpDebug:drawPoint(tx, y, tz, 1, 1 , 1);
		end
	end

end

function LevelCompactAIDriver:drawMap()
	function drawTile(f, r, g, b)
		cpDebug:drawLine(f.sx, f.y + 1, f.sz, r, g, b, f.wx, f.y + 1, f.wz)
		cpDebug:drawLine(f.wx, f.y + 1, f.wz, r, g, b, f.hx, f.y + 1, f.hz)
		cpDebug:drawLine(f.hx, f.y + 1, f.hz, r, g, b, f.sx, f.y + 1, f.sz);
		cpDebug:drawLine(f.cx, f.y + 1, f.cz, 1, 1, 1, f.bx, f.y + 1, f.bz);
	end

	if not self.vehicle.cp.BunkerSiloMap or not courseplay.debugChannels[self.debugChannel] then return end
	for _, line in pairs(self.vehicle.cp.BunkerSiloMap) do
		for _, fillUnit in pairs(line) do
			drawTile(fillUnit, 1/1 - fillUnit.fillLevel, 1, 0)
		end
	end
	if not self.targetSilo then return end
	if self.targetSilo.bunkerSiloArea.start then 
		DebugUtil.drawDebugNode(self.targetSilo.bunkerSiloArea.start, 'startBunkerNode')
		DebugUtil.drawDebugNode(self.targetSilo.bunkerSiloArea.width, 'widthBunkerNode')
		DebugUtil.drawDebugNode(self.targetSilo.bunkerSiloArea.height, 'heightBunkerNode')
	else --for heaps where we have no bunker nodes (start/width/height)
		cpDebug:drawPoint(self.targetSilo.bunkerSiloArea.sx, 1, self.targetSilo.bunkerSiloArea.sz, 1, 1, 1)
		cpDebug:drawPoint(self.targetSilo.bunkerSiloArea.wx, 1, self.targetSilo.bunkerSiloArea.wz, 1, 1, 1)
		cpDebug:drawPoint(self.targetSilo.bunkerSiloArea.hx, 1, self.targetSilo.bunkerSiloArea.hz, 1, 1, 1)
	end
end


function LevelCompactAIDriver:setLightsMask(vehicle)
	vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_FULL)
end

function LevelCompactAIDriver:setLevelerWorkWidth()
	self.workWidth = 3
	self.leveler = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Leveler)
	if not self.leveler then
		self:debug('No leveler found, using default width %.1f', self.workWidth)
		return
	end
	local spec = self.leveler.spec_leveler
	-- find the outermost leveler nodes
	local maxLeftX, minRightX = -math.huge, math.huge
	for _, levelerNode in pairs(spec.nodes) do
		local leftX, _, _ = localToLocal(levelerNode.node, self.vehicle.rootNode, -levelerNode.width, 0, levelerNode.maxDropDirOffset)
		local rightX, _, _ = localToLocal(levelerNode.node, self.vehicle.rootNode, levelerNode.width, 0, levelerNode.maxDropDirOffset)
		maxLeftX = math.max(maxLeftX, leftX)
		minRightX = math.min(minRightX, rightX)
	end
	self.workWidth = -minRightX + maxLeftX
	self:debug('Leveler width = %.1f (left %.1f, right %.1f)', self.workWidth, maxLeftX, -minRightX)
end

function LevelCompactAIDriver:getWorkWidth()
	return math.max(self.workWidth,self.vehicle.cp.workWidth)
end