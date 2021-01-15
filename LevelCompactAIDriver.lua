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
	DRIVE_TO_PARKING = {checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	WAITING_FOR_FREE_WAY = {},
	CHECK_SILO = {},
	CHECK_SHIELD = {},
	DRIVE_TO_PRE_START_POSITION = {},
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
	self.fillUpState = self.states.PUSH
	self:setLevelerWorkWidth()
end

function LevelCompactAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setLevelCompactAIDriverContent(self.vehicle)
end

function LevelCompactAIDriver:start(startingPoint)
	AIDriver.start(self,startingPoint)
	self:changeLevelState(self.states.DRIVE_TO_PARKING)
	self.fillUpState = self.states.PUSH
	self.alphaList = nil
	self.lastDrivenColumn = nil
	self.bestTarget = nil
	self.bunkerSiloManager = nil
	self.relevantWaypointNode = nil
	self:setLevelerWorkWidth()
end

function LevelCompactAIDriver:drive(dt)
	-- update current waypoint/goal point
	self:drawMap()
	self.allowedToDrive = true
	--are there any unloaders nearby ?
	local normalRadius = self.vehicle.cp.settings.levelCompactSearchRadius:get()
	--enlarge the searchRadius for waiting at waitpoint to avoid traffic problems
	local searchRadius = self:isWaitingForUnloaders() and normalRadius + 10 or normalRadius
	if self:foundUnloaderInRadius(searchRadius,not self:isWaitingForUnloaders()) then 
		self.hasFoundUnloaders = true
	else 
		self.hasFoundUnloaders = false
	end
	
	if self.levelState == self.states.DRIVE_TO_PARKING then
		self:moveShield('up',dt)
		self.ppc:update()
		AIDriver.driveCourse(self, dt)
	elseif self.levelState == self.states.WAITING_FOR_FREE_WAY then
		-- waiting until the unloaders are gone
		self:stopAndWait(dt)
		self:clearAllInfoTexts()
		if not self.hasFoundUnloaders then
			self:changeLevelState(self.states.DRIVE_TO_PARKING)
			self:clearInfoText('WAITING_FOR_UNLOADERS')
		else 
			self:setInfoText('WAITING_FOR_UNLOADERS')
		end
	elseif self.levelState == self.states.CHECK_SILO then
		--create the relevant BunkerSilo map
		self:stopAndWait(dt)
		if self:checkSilo() then
			self:changeLevelState(self.states.CHECK_SHIELD)
		end
	elseif self.levelState == self.states.CHECK_SHIELD then
		--initialized relevant shield data if needed and select the correct working mode
		self:stopAndWait(dt)
		if self:checkShield() then
			self:changeLevelState(self.states.DRIVE_TO_PRE_START_POSITION)
			self.tempTarget = nil
		end
	elseif self.levelState == self.states.DRIVE_TO_PRE_START_POSITION then
		self:driveToPreStartPosition(dt)
	elseif self.levelState == self.states.DRIVE_SILOFILLUP then
		self:driveSiloFillUp(dt)
	elseif self.levelState == self.states.DRIVE_SILOLEVEL then
		self:driveSiloLevel(dt)
	elseif self.levelState == self.states.DRIVE_SILOCOMPACT then
		self:driveSiloCompact(dt)
	end
	self:updateInfoText()
end

---search for unloaders nearby
---@param r number radius to search relativ from the unloader 
---@param setWaiting boolean if true then set the cp driver to wait else reset waiting if needed
---@return true if valid unloader is nearby
function LevelCompactAIDriver:foundUnloaderInRadius(r,setWaiting)
	if self.relevantWaypointNode == nil then 
		self.relevantWaypointNode = WaypointNode('relevantWaypointNode')
		self.relevantWaypointNode:setToWaypoint(self.course,self.course:getNumberOfWaypoints() , true)
	end
	if self:isDebugActive() then
		x,y,z = getTranslation(self.relevantWaypointNode.node)
		DebugUtil.drawDebugCircle(x,y+2,z, r, math.ceil(r/2))
	end
	local onlyStopFilledDrivers = self.vehicle.cp.settings.levelCompactSiloTyp:get()
	if g_currentMission then
		for _, vehicle in pairs(g_currentMission.vehicles) do
			if vehicle ~= self.vehicle then
				local d = calcDistanceFrom(self.relevantWaypointNode.node, vehicle.rootNode)
				--local d = courseplay:distanceToPoint(self.vehicle, relevantWaypoint.x, relevantWaypoint.y, relevantWaypoint.z)
				if d < r then
					local autodriveSpec = vehicle.spec_autodrive 
					if courseplay:isAIDriverActive(vehicle) and vehicle.cp.driver.triggerHandler:isAllowedToUnloadAtBunkerSilo() then
						--CombineUnloadAIDriver,GrainTransportAIDriver,UnloadableFieldworkAIDriver
						local isOkayToStop = true
						if onlyStopFilledDrivers then 
							if vehicle.cp.totalFillLevel < 0.02 then 
								isOkayToStop = false
							end
						end
						
						if setWaiting and isOkayToStop then 
							vehicle.cp.driver:hold()
							vehicle.cp.driver:setInfoText("WAITING_FOR_LEVELCOMPACTAIDRIVER")
							vehicle.cp.driver:disableTrafficConflictDetection()
						else 
							vehicle.cp.driver:clearInfoText("WAITING_FOR_LEVELCOMPACTAIDRIVER")
							vehicle.cp.driver:enableTrafficConflictDetection()
						end
						self:debugSparse("found cp driver : %s",nameNum(vehicle))
						return isOkayToStop
					elseif autodriveSpec and autodriveSpec.HoldDriving and vehicle.ad.stateModule and vehicle.ad.stateModule:isActive() then 
						--autodrive
						if setWaiting then
							autodriveSpec:HoldDriving(vehicle)
						end
						self:debugSparse("found autodrive driver : %s",nameNum(vehicle))
						return true
					elseif vehicle.getIsEntered and vehicle:getIsEntered() and AIDriverUtil.getImplementWithSpecialization(vehicle, Trailer) ~= nil then 
						--Player controlled vehicle
						if self.vehicle.cp.settings.levelCompactSearchOnlyAutomatedDriver:is(false) then
							--Player controlled vehicle is allowed to lookup
							self:debugSparse("found player driven vehicle : %s",nameNum(vehicle))
							return true
						end
					end
				end
			end
		end
	end
end

function LevelCompactAIDriver:isWaitingForUnloaders()
	return self.levelState == self.states.WAITING_FOR_FREE_WAY
end 

function LevelCompactAIDriver:isTrafficConflictDetectionEnabled()
	return self.trafficConflictDetectionEnabled and self.levelState and self.levelState.properties.checkForTrafficConflict
end

function LevelCompactAIDriver:isProximitySwerveEnabled()
	return self.levelState and self.levelState.properties.enableProximitySwerve
end

function LevelCompactAIDriver:isProximitySpeedControlEnabled()
	return self.levelState and self.levelState.properties.enableProximitySpeedControl
end

function LevelCompactAIDriver:checkShield()
	
	local leveler = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Leveler)
	if leveler then
		self:debugSparse("leveler found: %s",nameNum(leveler))
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
			self:debugSparse("fail no working combo found!")
		end
	else
		if self:getIsModeCompact() then
			return true
		else 
			self:debugSparse("fail no working combo found!")
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
		self:lowerImplements()
	end
	self.fillUpState = self.states.PUSH
end

--drives form the start to the end and back for each line repeatedly
function LevelCompactAIDriver:driveSiloCompact(dt)
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil then
			self.bestTarget, self.firstLine = self:getBestTargetFillUnitCompacting(self.lastDrivenColumn)
		end

		self:drivePush(dt)
		if self:isAtEnd() then
			self.fillUpState = self.states.PULLBACK
			self:raiseImplements()
		end
	
	elseif self.fillUpState == self.states.PULLBACK then
		if self:drivePull(dt) then
			self.fillUpState = self.states.PUSH
			self:lowerImplements()
			self:deleteBestTargetLeveling()
		end
	end
end

function LevelCompactAIDriver:driveSiloLevel(dt)
	if self.fillUpState == self.states.PUSH then
		--initialize first target point
		if self.bestTarget == nil then
			self.bestTarget, self.firstLine, self.targetHeight = self:getBestTargetFillUnitLeveling(self.lastDrivenColumn)
		end
		renderText(0.2,0.395,0.02,"self:drivePush(dt)")

		self:drivePush(dt)
		self:moveShield('down',dt,self:getDiffHeightforHeight(self.targetHeight))
	
		if self:isAtEnd()
		--or self:hasShieldEmpty()
		or self:isStuck()
		then
			if self.hasFoundUnloaders then
				self:changeLevelState(self.states.DRIVE_TO_PARKING)
				self:deleteBestTarget()
				return
			else
				self.fillUpState = self.states.PULLBACK
			end
		end
	
	
	elseif self.fillUpState == self.states.PULLBACK then
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
		if self.bestTarget == nil then
			self.bestTarget, self.firstLine = self:getBestTargetFillUnitFillUp(self.lastDrivenColumn)
		end		
		self:drivePush(dt)
		self:moveShield('down',dt,0)
		--self:moveShield('down',dt,self:getDiffHeightforHeight(0))
		if self:lastLineFillLevelChanged()
		or self:isStuck()
		--or self:hasShieldEmpty()
		then
			if self.hasFoundUnloaders then
				self:changeLevelState(self.states.DRIVE_TO_PARKING)
				self:deleteBestTarget()
				return
			else
				self.fillUpState = self.states.PULLBACK
			end
		end	
	elseif self.fillUpState == self.states.PULLBACK then
		self:moveShield('up',dt)
		if self:drivePull(dt) then
			self.fillUpState = self.states.PUSH
			self:deleteBestTargetLeveling()
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
	local targetUnit = self.bunkerSiloManager.siloMap[self.bestTarget.line][self.bestTarget.column]
	cx ,cz = targetUnit.cx, targetUnit.cz
	cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	
	--check whether its time to change the target point	
	self:updateTarget()
	--speed
	if self:isNearEnd() then
		refSpeed = math.min(10,vehicle.cp.settings.bunkerSpeed:get())
	else
		refSpeed = math.min(20,vehicle.cp.settings.bunkerSpeed:get())
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
	local refSpeed = math.min(20,self.vehicle.cp.settings.bunkerSpeed:get())
	local allowedToDrive = true 
	local cx,cy,cz = self.course:getWaypointPosition(self.course:getNumberOfWaypoints())
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, cx,cy,cz);
	self:driveInDirection(dt,lx,lz,fwd,refSpeed,allowedToDrive)
	--end if I moved over the last way point
	if lz < 0 then
		pullDone = true
	end
	if self.hasFoundUnloaders then
		self:changeLevelState(self.states.DRIVE_TO_PARKING)
		self:deleteBestTarget()
		return false
	end
--	self:drawMap()
	return pullDone
end

---make sure we start with enough distance to the first bunkersilo target, so we don't drive into the silo wall 
---currently we just drive 10 m ahead and then start normaly drive the buker course
function LevelCompactAIDriver:driveToPreStartPosition(dt)
	local refSpeed = math.min(20,self.vehicle.cp.settings.bunkerSpeed:get())
	self:moveShield('up',dt)
	if self.tempTarget == nil then
		local gx,gy,gz = localToWorld(self.vehicle.rootNode,0,0,10)
		self.tempTarget = {}
		self.tempTarget.x = gx
		self.tempTarget.y = gy
		self.tempTarget.z = gz
	end
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, self.tempTarget.x,self.tempTarget.y,self.tempTarget.z);
	local distX,_,distZ = localToWorld(self.vehicle.rootNode,0,0,0)
	if math.abs(distZ-self.tempTarget.z) > 1 then
		self:driveInDirection(dt,lx,lz,true,refSpeed,true)
	else 
		self:selectMode()
	end
end

function LevelCompactAIDriver:getHasMovedToFrontLine(dt)
	local startUnit = self.bunkerSiloManager.siloMap[self.firstLine][1]
	local _,ty,_ = getWorldTranslation(self:getLevelerNode(self.leveler));
	local _,_,z = worldToLocal(self:getLevelerNode(self.leveler), startUnit.cx , ty , startUnit.cz);
	if math.abs(z) < 1 then
		return true;			
	end
	return false;
end

function LevelCompactAIDriver:isNearEnd()
	return self.bunkerSiloManager:isNearEnd(self.bestTarget)
end


function LevelCompactAIDriver:lastLineFillLevelChanged()
	local vehicle = self.vehicle
	local siloMap = self.bunkerSiloManager:getSiloMap()
	local newSx = siloMap[#siloMap][1].sx 
	local newSz = siloMap[#siloMap][1].sz 
	local newWx = siloMap[#siloMap][#siloMap[#siloMap]].wx
	local newWz = siloMap[#siloMap][#siloMap[#siloMap]].wz
	local newHx = siloMap[#siloMap][1].hx
	local newHz = siloMap[#siloMap][1].hz
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
	local tool = self.leveler
	if tool:getFillUnitFillLevel(1) < 100 then
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
	return self.bunkerSiloManager:updateTarget(self.bestTarget)
end

function LevelCompactAIDriver:isAtEnd()
	if not self.bunkerSiloManager then return false end
	return self.bunkerSiloManager:isAtEnd(self.bestTarget)
end

function LevelCompactAIDriver:deleteBestTarget()
	self.lastDrivenColumn = nil
	self.bestTarget = nil
end

function LevelCompactAIDriver:deleteBestTargetLeveling()
	self.lastDrivenColumn = self.bestTarget.column
	self.bestTarget = nil
end


function LevelCompactAIDriver:getIsModeFillUp()
	return self.vehicle.cp.settings.levelCompactMode:get() == LevelCompactModeSetting.FILLING
end

function LevelCompactAIDriver:getIsModeLeveling()
	return self.vehicle.cp.settings.levelCompactMode:get() == LevelCompactModeSetting.LEVELING
end

function LevelCompactAIDriver:getIsModeCompact()
	return self.vehicle.cp.settings.levelCompactMode:get() == LevelCompactModeSetting.COMPACTING
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

function LevelCompactAIDriver:stop(stopMsg)
	self:foundUnloaderInRadius(self.vehicle.cp.settings.levelCompactSearchRadius:get())
	self.relevantWaypointNode = nil	
	AIDriver.stop(self,stopMsg)
end

function LevelCompactAIDriver:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	-- TODO: we should not call AIVehicleUtil.driveInDirection, this should be refactored that AIDriver does all the
	-- driving
	local node = fwd and self:getFrontMarkerNode(self.vehicle) or self:getBackMarkerNode(self.vehicle)
	self:updateTrafficConflictDetector(nil, nil, speed, fwd, node)
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
	if self.bunkerSiloManager == nil then
		local silo = BunkerSiloManagerUtil.getTargetBunkerSilo(self.vehicle,1)
		if silo then 
			self.bunkerSiloManager = BunkerSiloManager(self.vehicle,silo,self:getWorkWidth(),self:getValidBackImplement())
		end
	
	end
	if not self.bunkerSiloManager then
		courseplay:setInfoText(self.vehicle, courseplay:loc('COURSEPLAY_MODE10_NOSILO'));
	else
		return true
	end
end

function LevelCompactAIDriver:lowerImplements()
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	self.vehicle:requestActionEventUpdate()
	for _, implement in pairs(self.vehicle:getAttachedImplements()) do
		if implement.object.aiImplementStartLine then
			implement.object:aiImplementStartLine()
		--	if implement.object.getCanBeTurnedOn and implement.object:getCanBeTurnedOn() then 
		--		implement.object:setIsTurnedOn(true)
		--	end
		end
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)
end

function LevelCompactAIDriver:raiseImplements()
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
	self.vehicle:requestActionEventUpdate()
	for _, implement in pairs(self.vehicle:getAttachedImplements()) do
		if implement.object.aiImplementEndLine then
			implement.object:aiImplementEndLine()
		--	if implement.object.getCanBeTurnedOn then 
		--		implement.object:setIsTurnedOn(false)
		--	end
		end
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
end


function LevelCompactAIDriver:moveShield(moveDir,dt,fixHeight)
	local leveler = self.leveler
	local moveFinished = false
	if leveler and leveler.spec_attacherJointControl ~= nil then
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
	local blade = self.leveler
	local bladeX,bladeY,bladeZ = getWorldTranslation(self:getLevelerNode(blade))
	local bladeTerrain = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, bladeX,bladeY,bladeZ);
	local _,_,offSetZ = worldToLocal(self.vehicle.rootNode,bladeX,bladeY,bladeZ)
	local _,projectedTractorY,_  = localToWorld(self.vehicle.rootNode,0,0,offSetZ)

	return targetHeight- (projectedTractorY-bladeTerrain)
end


function LevelCompactAIDriver:recordAlphaList()
	local blade = self.leveler
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
	if courseplay.debugChannels[10] and self.bunkerSiloManager.siloMap then
		for _, line in pairs(self.bunkerSiloManager.siloMap) do
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

function LevelCompactAIDriver:getBestTargetFillUnitCompacting(lastDrivenColumn)
	local newBestTarget = {}
	local firstLine = 1
	local siloMap = self.bunkerSiloManager:getSiloMap()
	if siloMap ~= nil then
		local newColumn = lastDrivenColumn and lastDrivenColumn + 1 or 1
		if newColumn > #siloMap[1] then 
			newColumn = 1
		end
		local newBestTarget= {
			line = 1,
			column = newColumn,						
			empty = false
			}
		return newBestTarget, firstLine
	end
end

--- get the bestTarget, firstLine of the bestTarget work with
---@param int lastDrivenColumn of the silo
---@return bestTarget, firstLine of the bestTarget
function LevelCompactAIDriver:getBestTargetFillUnitFillUp(lastDrivenColumn)
	local siloMap = self.bunkerSiloManager:getSiloMap()
	
	local newColumn = lastDrivenColumn and lastDrivenColumn + 1 or 1
	if newColumn > #siloMap[1] then 
		newColumn = 1
	end
	local firstLine = 1
	local bestTarget = {
		line = 1;
		column = newColumn;
		empty = true;
	}
	-- find column with most fillLevel and figure out whether it is empty
	for lineIndex, line in pairs(siloMap) do
		local fillUnit = siloMap[lineIndex][newColumn]
		if fillUnit.fillLevel > 0 then
			bestTarget = {
				line = lineIndex;
				column = newColumn;
				empty = false;
			}
			firstLine = bestTarget.line
			break
		end
	end
	return bestTarget, firstLine
end

function LevelCompactAIDriver:getBestTargetFillUnitLeveling(lastDrivenColumn)
	local siloMap = self.bunkerSiloManager:getSiloMap()
	local firstLine = 1
	local targetHeight = 0.5
	local vehicle = self.vehicle
	local newApproach = lastDrivenColumn == nil 
	local newBestTarget = {}
	if siloMap ~= nil then
		local newColumn = math.ceil(#siloMap[1]/2)
		if newApproach then
			newBestTarget, firstLine = self.bunkerSiloManager:getBestTargetFillUnitFillUp(self.bestTarget)
			self:debug('Best leveling target at line %d, column %d, height %d, first line %d (fist approach)',
					newBestTarget.line, newBestTarget.column, targetHeight, firstLine)
			return newBestTarget, firstLine, targetHeight
		else
			newColumn = lastDrivenColumn + 1;
			if newColumn > #siloMap[1] then
				newColumn = 1;
			end
			firstLine = self:findFirstNonEmptyRow(siloMap, newColumn)
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
	local siloMap = self.bunkerSiloManager:getSiloMap()
	for i=1,#siloMap do
		--calculate the area without first and last line
		if i~= 1 and i~= #siloMap then
			totalArea = totalArea + siloMap[i][newColumn].area
		end
		totalFillLevel = totalFillLevel + siloMap[i][newColumn].fillLevel
	end
	local newHeight = math.max(0.6,(totalFillLevel/1000)/totalArea)
	self:debug("getTargetHeight: totalFillLevel:%s; totalArea:%s Height%s",tostring(totalFillLevel),tostring(totalArea),tostring(newHeight))
	return newHeight
	
end

function LevelCompactAIDriver:debugRouting()
	if self:isDebugActive() and self.bunkerSiloManager then
		self.bunkerSiloManager:debugRouting(self.bestTarget)
	end
end

function LevelCompactAIDriver:drawMap()
	if self:isDebugActive() and self.bunkerSiloManager then
		self.bunkerSiloManager:drawMap()
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

---if we have a leveler return the leveler.rootNode, else return the backMakerNode
---@return node self.leveler.rootNode or backMakerNode
function LevelCompactAIDriver:getValidBackImplement()
	local backMarkerNode = self:getBackMarkerNode(self.vehicle)
	return self.leveler and self.leveler.rootNode or backMarkerNode
end

function LevelCompactAIDriver:isDebugActive()
	return courseplay.debugChannels[10]
end


--debug info
function LevelCompactAIDriver:onDraw()
	if self:isDebugActive() then 
		local y = 0.5
		y = self:renderText(y,"levelState: "..tostring(self.levelState and self.levelState.name))
		y = self:renderText(y,"hasBunkerSiloMap: "..tostring(self.bunkerSiloManager ~= nil))
		y = self:renderText(y,"fillUpState: "..tostring(self.fillUpState and self.fillUpState.name))
		y = self:renderText(y,"hasBestTarget: "..tostring(self.bestTarget ~= nil))
		y = self:renderText(y,"lastDrivenColumn: "..tostring(self.lastDrivenColumn))
		y = self:renderText(y,"hasFoundUnloaders: "..tostring(self.hasFoundUnloaders))
		y = self:renderText(y,"isAtEnd: "..tostring(self:isAtEnd()))
	end
	AIDriver.onDraw(self)
end

function LevelCompactAIDriver:renderText(y,text,xOffset)
	renderText(xOffset and 0.3+xOffset or 0.3,y,0.02,tostring(text))
	return y-0.02
end

