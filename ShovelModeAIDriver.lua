--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Thomas Gaertner

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
handles "mode9": Fill and empty shovel
--------------------------------------
0)  Course setup:
	a) Start in front of silo
	b) drive forward, set waiting point #1
	c) drive forwards through silo, at end set waiting point #2
	d) drive reverse (back through silo) and turn at end
	e) drive forwards to bunker, set waiting point #3 and unload
	f) drive backwards, turn, drive forwards until before start

1)  drive course until waiting point #1 - set shovel to "filling" rotation
2)  [repeat] if lastFillLevel == currentFillLevel: drive ahead until is filling
2b) if waiting point #2 is reached, area is empty -> stop work
3)  if currentFillLevel == 100: set shovel to "transport" rotation, find closest point that's behind tractor, drive course from there
4)  drive course forwards until waiting point #3 - set shovel to "empty" rotation
5)  drive course with recorded direction (most likely in reverse) until end - continue and repeat to 1)

NOTE: although lx and lz are passed in as parameters, they are never used.
]]

--[[
TODO: 
	-maybe create a FrontLoaderAIDriver
	-and then create a seprate BunkerSiloShovelModeAIDriver and a new TriggerShovelAIDriver
]]--

---@class ShovelModeAIDriver : AIDriver
ShovelModeAIDriver = CpObject(AIDriver)

ShovelModeAIDriver.myStates = {
	STATE_CHECKSILO = {},
	STATE_GOINTO_SILO = {},
	STATE_REVERSE_OUT_OF_SILO = {},
	STATE_REVERSE_STRAIGHT_OUT_OF_SILO = {},
	STATE_TRANSPORT = {checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	STATE_WAIT_FOR_TARGET = {},
	STATE_START_UNLOAD = {},
	STATE_WAIT_FOR_UNLOADREADY = {},
	STATE_START_UNLOAD_TRAILER = {},
	STATE_WAIT_FOR_UNLOADREADY_TRAILER = {},
	STATE_GO_BACK_FROM_EMPTYPOINT = {},
	STATE_WORK_FINISHED = {}
}
ShovelModeAIDriver.SHOVEL_POSITIONS = {}
ShovelModeAIDriver.SHOVEL_POSITIONS.LOADING = 1
ShovelModeAIDriver.SHOVEL_POSITIONS.TRANSPORT = 2
ShovelModeAIDriver.SHOVEL_POSITIONS.PRE_UNLOADING = 3
ShovelModeAIDriver.SHOVEL_POSITIONS.UNLOADING = 4


--- Constructor
function ShovelModeAIDriver:init(vehicle)
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER,vehicle,'ShovelModeAIDriver:init')
	AIDriver.init(self, vehicle)
	self:initStates(ShovelModeAIDriver.myStates)
	self.mode = courseplay.MODE_SHOVEL_FILL_AND_EMPTY
	self.shovelState = self.states.STATE_TRANSPORT
	self.debugChannel = courseplay.DBG_MODE_9
	self.refSpeed = 15
end

function ShovelModeAIDriver.create(vehicle)
	if vehicle.cp.settings.shovelModeAIDriverTriggerHandlerIsActive:is(false) then
		return ShovelModeAIDriver(vehicle)
	else
		return TriggerShovelModeAIDriver(vehicle)
	end
end

function ShovelModeAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setShovelModeAIDriverContent(self.vehicle)
end

function ShovelModeAIDriver:start()
	self:beforeStart()
	self:disableCollisionDetection()

	self:findShovel(self.vehicle) 
	if not self.shovel then 
		self:error("Error: shovel not found!!")
		courseplay:stop(self.vehicle)
		return
	end
	--finding my working points
	local vehicle = self.vehicle
	self:validateWaitpoints()
	self:resetSiloData()
	self.bunkerSiloManager = nil
	self.unloadingObjectRaycastActive = false
	self.trailerCallback = nil
	local vAI = vehicle:getAttachedImplements()
	for i,_ in pairs(vAI) do
		local object = vAI[i].object
		if object.ignoreVehicleDirectionOnLoad ~= nil then
			object.ignoreVehicleDirectionOnLoad = true
		end	
		local oAI = object:getAttachedImplements()
		if oAI ~= nil then
			for k,_ in pairs(oAI) do
				if oAI[k].object.ignoreVehicleDirectionOnLoad ~= nil then
					oAI[k].object.ignoreVehicleDirectionOnLoad = true
			end
			end
		end				
	end
	self:setShovelState(self.states.STATE_TRANSPORT, 'setup');
	self.course = Course(self.vehicle , self.vehicle.Waypoints)
	self.ppc:setCourse(self.course)
	self.ppc:initialize()
	AIDriver.continue(self)
end

function ShovelModeAIDriver:shouldStopAtEndOfCourse()
	return false
end
---Checks and sets all valid Waitpoints
function ShovelModeAIDriver:validateWaitpoints()
	self.shovelFillStartPoint = nil
	self.shovelFillEndPoint = nil
	self.shovelEmptyPoint = nil
	local numWaitPoints = 0
	for i,wp in pairs(self.vehicle.Waypoints) do
		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
		end;

		if numWaitPoints == 1 and self.shovelFillStartPoint == nil then
			self.shovelFillStartPoint = i;
		end;
		if numWaitPoints == 2 and self.shovelFillEndPoint == nil then
			self.shovelFillEndPoint = i;
		end;
		if numWaitPoints == 3 and self.shovelEmptyPoint == nil then
			self.shovelEmptyPoint = i;
		end;
	end;
end

--debug info
function ShovelModeAIDriver:onDraw()
	if self:isDebugActive() and self.shovel then 
		local y = 0.5
		y = self:renderText(y,"state: "..tostring(self.shovelState.name),0.4)
		y = self:renderText(y,"hasBunkerSiloManager: "..tostring(self.bunkerSiloManager ~= nil),0.4)
		y = self:renderText(y,"hasBestTarget: "..tostring(self.bestTarget ~= nil),0.4)
		y = self:renderText(y,"isShovelFull: "..tostring(self:getIsShovelFull() == true),0.4)
		y = self:renderText(y,"isShovelEmpty: "..tostring(self:getIsShovelEmpty() == true),0.4)
	end
	AIDriver.onDraw(self)
end

function ShovelModeAIDriver:renderText(y,text,xOffset)
	renderText(xOffset and 0.3+xOffset or 0.3,y,0.02,tostring(text))
	return y-0.02
end

function ShovelModeAIDriver:isDebugActive()
	return courseplay.debugChannels[courseplay.DBG_MODE_9]
end

function ShovelModeAIDriver:drive(dt)
	if not self:checkShovelPositionsValid() or not self:checkWaypointsValid() then
		return
	end
	local notAllowedToDrive = false
	--get the relevant bunkerSilo/Heap data
	if self.shovelState == self.states.STATE_CHECKSILO then
		self:hold()
		if self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.LOADING,dt) then
			--if bunkerSiloManager is nil, then search for a silo/heap
			if self.bunkerSiloManager == nil then
				local silo,isHeap = self:getTargetBunkerSilo()
				--silo/heap was found 
				if silo then 
					self.bunkerSiloManager =  BunkerSiloManager(self.vehicle, silo, self:getWorkWidth(),self.shovel.rootNode,BunkerSiloManager.MODE.SHOVEL,isHeap)
				else 
					self:debug("no silo was found")
				--	courseplay:setInfoText(self.vehicle, courseplay:loc('COURSEPLAY_MODE10_NOSILO'))
					self:setShovelState(self.states.STATE_WORK_FINISHED)
				end
			end
			---if bunkerSiloManager and siloMap are valid then search for best target
			if self.bunkerSiloManager and self.bunkerSiloManager:isSiloMapValid() then
				self.bestTarget, self.firstLine = self.bunkerSiloManager:getBestTargetFillUnitFillUp()
				--best target was found => STATE_GOINTO_SILO
				if self.bestTarget then 
					self:setShovelState(self.states.STATE_GOINTO_SILO)
				else 
					self.bunkerSiloManager = nil
					self:resetBGASiloTables()
					self:debug("could not find best target")
					self:setShovelState(self.states.STATE_WORK_FINISHED)
				end
			else
				self.bunkerSiloManager = nil
				self:resetBGASiloTables()
				self:debug("silo map setup is not valid")
				self:setShovelState(self.states.STATE_WORK_FINISHED)
			end
		end
	--driving into the bunkerSilo
	elseif self.shovelState == self.states.STATE_GOINTO_SILO then
		self.refSpeed = self.vehicle.cp.speeds.field
		local fwd = true
		self:driveIntoSilo(dt)
		self:drawMap()
		--bunkerSilo is empty => work is finished
		if self.bunkerSiloManager:isAtEnd(self.bestTarget) and self:getIsShovelEmpty() then
			self:setShovelState(self.states.STATE_WORK_FINISHED)
			return
		end
		--targeted siloPart is cleared, shovel is full, or driver is stuck
		if self:getIsShovelFull() or self.bunkerSiloManager:isAtEnd(self.bestTarget) or self:isStuck() then
			--driving back out of the bunkerSilo
			if self:getTargetIsOnBunkerWallColumn() then
				---create a temporary course, if the last target was near a bunker wall,
				---this one is only allowed if the silo map has at least two lines 
				self.tempTarget = self:getTargetToStraightOut()
				self:setShovelState(self.states.STATE_REVERSE_STRAIGHT_OUT_OF_SILO)
			else
				local directionNode = self:getDirectionNode()
				local _,_,Zoffset = self.course:getWaypointLocalPosition(directionNode, self.shovelFillStartPoint)
				local newPoint = self.course:getNextRevWaypointIxFromVehiclePosition(self.ppc:getCurrentWaypointIx(), directionNode,-Zoffset)
				self.ppc:initialize(newPoint)
				self:setShovelState(self.states.STATE_REVERSE_OUT_OF_SILO)
			end
		end

		return
	--driving back out of the bunkerSilo
	elseif self.shovelState == self.states.STATE_REVERSE_STRAIGHT_OUT_OF_SILO then
		self.refSpeed = self.vehicle.cp.speeds.reverse
		if not self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.TRANSPORT,dt) then
			self:hold()
		end
		self:drawMap()
		if self:getIsReversedOutOfSilo() then
			local directionNode = self:getDirectionNode()
			local _,_,Zoffset = self.course:getWaypointLocalPosition(directionNode, self.shovelFillStartPoint)
			local newPoint = self.course:getNextRevWaypointIxFromVehiclePosition(self.ppc:getCurrentWaypointIx(), directionNode,-Zoffset)
			self.ppc:initialize(newPoint)
			self:setShovelState(self.states.STATE_TRANSPORT)
		end
		--drive to temp target
		if self.tempTarget then
			local cx,cz = self.tempTarget.cx,self.tempTarget.cz
			local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
			local directionNode = self:getDirectionNode()
			local lx, lz = AIVehicleUtil.getDriveDirection(directionNode, cx,cy,cz);
			lx,lz = -lx,-lz;
			self:driveInDirection(dt,lx,lz,false,self:getSpeed(),true)
			self:debugRouting()
			return
		end
	--driving back out of the bunkerSilo
	elseif self.shovelState == self.states.STATE_REVERSE_OUT_OF_SILO then
		self.refSpeed = self.vehicle.cp.speeds.reverse
		if not self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.TRANSPORT,dt) then
			self:hold()
		end
		if not self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) then
			self:setShovelState(self.states.STATE_TRANSPORT);
		end
		self:drawMap()
	-- drive the course normally until we are relativ close to shovelEmptyPoint 
	elseif self.shovelState == self.states.STATE_TRANSPORT then
		-- we are close to the unload waitpoint and before shovelEmptyPoint and after shovelFillStartPoint  
		if self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, self.shovelEmptyPoint) < 15
			and self:iAmBeforeEmptyPoint()
			and self:iAmBehindFillEndPoint() then
				self:setShovelState(self.states.STATE_WAIT_FOR_TARGET)
				self:disableTrafficConflictDetection()
		end
		--backup for starting somewhere in between
		if not self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.TRANSPORT,dt) then
			self:hold()
		end
	-- close to the unload waitpoint, so set pre unload shovel position and do a raycast for unload triggers, trailers
	elseif self.shovelState == self.states.STATE_WAIT_FOR_TARGET then
		self:driveWaitForTarget(dt)
	-- drive to the unload at trigger
	elseif self.shovelState == self.states.STATE_START_UNLOAD then
		notAllowedToDrive =	self:driveStartUnload(dt)
		if notAllowedToDrive then 
			return 
		end
	-- handle unloading at trigger
	elseif self.shovelState == self.states.STATE_WAIT_FOR_UNLOADREADY then
		self:driveWaitForUnloadReady(dt)
	-- drive to the unload at trailer
	elseif self.shovelState == self.states.STATE_START_UNLOAD_TRAILER then
		notAllowedToDrive =	self:driveStartUnloadTrailer(dt)
		if notAllowedToDrive then 
			return 
		end
	-- handle unloading at trailer
	elseif self.shovelState == self.states.STATE_WAIT_FOR_UNLOADREADY_TRAILER then
		self:driveWaitForUnloadReadyTrailer(dt)
	-- reverse back to the course
	elseif self.shovelState == self.states.STATE_GO_BACK_FROM_EMPTYPOINT then
		self:driveGoBackFromEmptyPoint(dt)
	--bunker silo/ heap is empty 
	elseif self.shovelState == self.states.STATE_WORK_FINISHED then
		self:driveWorkFinished(dt)
	end
	self:updateInfoText()
	self.ppc:update()
	AIDriver.drive(self, dt)
	self:resetSpeed()
	self:checkLastWaypoint()
end

--using updateTick for raycasts performance, as updateTick represents the physic updates 
function ShovelModeAIDriver:updateTick(dt)
	AIDriver.updateTick(self,dt)
	if self:isUnloadingObjectRaycastActive() then 
		self:searchForUnloadingObjectRaycast()
	end
end

---Reset all relevant silo data
function ShovelModeAIDriver:resetSiloData()
	self.bestTarget = nil
	self.tempTarget = nil
	self.firstLine = nil
end

function ShovelModeAIDriver:isStuck()
	if self:doesNotMove() then
		if self.vehicle.cp.timers.slipping == nil or self.vehicle.cp.timers.slipping == 0 then
			courseplay:setCustomTimer(self.vehicle, 'slipping', 2);
			--courseplay:debug(('%s: setCustomTimer(..., "slippingStage", courseplay.DBG_TRAFFIC)'):format(nameNum(self.vehicle)), courseplay.DBG_MODE_9);
		elseif courseplay:timerIsThrough(self.vehicle, 'slipping') then
			--courseplay:debug(('%s: timerIsThrough(..., "slippingStage") -> return isStuck(), reset timer'):format(nameNum(self.vehicle)), courseplay.DBG_MODE_9);
			courseplay:resetCustomTimer(self.vehicle, 'slipping');
			self:debug("dropout isStuck")
			return true
		end;
	else
		courseplay:resetCustomTimer(self.vehicle, 'slipping');
	end
end

function ShovelModeAIDriver:doesNotMove()
	-- giants supplied last speed is in mm/s;
	-- does not move if we are less than 1km/h
	return math.abs(self.vehicle.lastSpeedReal) < 1/3600 and self.bestTarget.line > self.firstLine+1
end

-- close to the unload waitpoint, so set pre unload shovel position and do a raycast for unload triggers, trailers
function ShovelModeAIDriver:driveWaitForTarget(dt)
	self.refSpeed = self.vehicle.cp.speeds.crawl
	--wait until a possible trailer is near
	if self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, self.shovelEmptyPoint) < 10 then 
		self:hold()
	end
	if self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.PRE_UNLOADING,dt) then
		--search for UnloadStation(UnloadTrigger) or correct Trailer ahead, else wait
		self.unloadingObjectRaycastActive = true
	end
end

---trigger
-- drive to the unload trigger
function ShovelModeAIDriver:driveStartUnload(dt)
	self.unloadingObjectRaycastActive = false
	self.refSpeed = self:getDriveStartUnloadRefSpeed()
	local currentDischargeNode = self.shovel:getCurrentDischargeNode()
	-- if shovel is empty we can drive directly back from the trigger
	if self:getIsShovelEmpty() then 
		--wait until shovel position 3 is reached
		self:sendUnloaderBackFromEmptyPoint()
		self:hold()
		return false
	end
	-- discharge node can unload and dischargeObject was found
	if self.shovel:getCanDischargeToObject(currentDischargeNode) and currentDischargeNode.dischargeObject then 
		--enough free space in object found
		if self:hasEnoughSpaceInObject(currentDischargeNode) then 
			if self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.UNLOADING,dt) then
				self:setShovelState(self.states.STATE_WAIT_FOR_UNLOADREADY)
			end
		--not enough free space 
		else 
			self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.PRE_UNLOADING,dt)
		end
		self:hold()
	--trigger not yet reached
	else
		if self.course:getDistanceToNextWaypoint(self.shovelEmptyPoint) <2 then 
			-- the last 2m we drive straight to the unload trigger
			local gx, _, gz = self.course:getWaypointLocalPosition(self:getDirectionNode(),self.shovelEmptyPoint)
			self:driveVehicleToLocalPosition(dt, true, true, gx, gz, self.refSpeed)
			return true
		end
	end
	return false
end

-- handle unloading at trigger
function ShovelModeAIDriver:driveWaitForUnloadReady(dt)
	self:hold()
	local dischargeNode = self.shovel:getCurrentDischargeNode()		
	-- drive back to the course
	if self:getIsShovelEmpty() then
		if self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.PRE_UNLOADING,dt) then
			self:sendUnloaderBackFromEmptyPoint()
		end
	--stop unloading at unload trigger if there is no more free space
	elseif not self.shovel:getCanDischargeToObject(dischargeNode) or self:almostFullObject(dischargeNode) then
		self:setShovelState(self.states.STATE_START_UNLOAD);
	end		
end

------trailer
---drive to the unload trigger/ trailer
function ShovelModeAIDriver:driveStartUnloadTrailer(dt)
	self.unloadingObjectRaycastActive = false
	self.refSpeed = self:getDriveStartUnloadRefSpeed()
	local dischargeNode = self.shovel:getCurrentDischargeNode()
	
	if self:getIsShovelEmpty() then 
		self:sendUnloaderBackFromEmptyPoint()
		return
	end
	if self.trailerCallback then 
	---drive to exactFillRootNode and stop if the attacherNode of the shovel is roughly near it	
		if self.course:getDistanceToNextWaypoint(self.shovelEmptyPoint) <5 then 
			local exactFillRootNode = self.trailerCallback.exactFillRootNode
			local trailer = self.trailerCallback.trailer
			local inputAttacherJoints = self.shovel:getInputAttacherJoints()
			local relevantAttacherJointNode = inputAttacherJoints[1].node
			---offset between shovel attacherNode and dischargeNode
			local nx,_,nz = localToLocal(relevantAttacherJointNode,dischargeNode.node,0,0,0)
			---get the world coordinates
			local ax,ay,az = localToWorld(dischargeNode.node,0,0,nz/2)
			local bx,by,bz = localToWorld(relevantAttacherJointNode,0,0,0)
			local dx,dy,dz = localToWorld(exactFillRootNode,0,0,0)
			local distance = courseplay:distance(dx,dz,ax,az)
			if self:isDebugActive() then
				cpDebug:drawLine(dx,dy,dz,1,0,1,ax,ay,az)
				DebugUtil.drawDebugNode(relevantAttacherJointNode, 'relevantAttacherJointNode')
				DebugUtil.drawDebugNode(exactFillRootNode, 'exactFillRootNode')
				DebugUtil.drawDebugNode(dischargeNode.node, 'dischargeNode.node')
			end
			self:debug("distanceToTrailer: %.2f",distance)
			--additional offset so the driver doesn't crash into the trailer
			if distance > 1.2 then 
				---shovel attacherNode is not near enough to the exactFillRootNode
				---get the direction of the dischargeNode to the exactFillRootNode(dx,dy,dz)
				local lx, lz = AIVehicleUtil.getDriveDirection(dischargeNode.node, dx,dy,dz);
				local MIN_SPEED = 4
				local speed = MathUtil.clamp(distance,MIN_SPEED,self.refSpeed)
				self:driveInDirection(dt,lx,lz,true,speed,true)				
				return true
			else
				---position is reached, so start unloading if possible down below
				self:debug("reached trailer start unloading")
				self.trailerCallback = nil
				self:setSpeed(0)
				self:hold() 
			end
		end
	else 
		-- if we can discharge at trailer 
		if self.shovel:getCanDischargeToObject(dischargeNode) and dischargeNode.dischargeObject then
			if self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.UNLOADING,dt) then
				self:setShovelState(self.states.STATE_WAIT_FOR_UNLOADREADY_TRAILER)
			end
		end
		self:hold()
	end
	return false
end

-- handle unloading
function ShovelModeAIDriver:driveWaitForUnloadReadyTrailer(dt)
	self:hold()
	local dischargeNode = self.shovel:getCurrentDischargeNode()		
	--drive back to the course
	if self:getIsShovelEmpty() or not self.shovel:getCanDischargeToObject(dischargeNode) or dischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_NO_FREE_CAPACITY  then
		self:sendUnloaderBackFromEmptyPoint()
	end
end

------

function ShovelModeAIDriver:sendUnloaderBackFromEmptyPoint()
	if self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.PRE_UNLOADING,dt) then
		local directionNode = self:getDirectionNode()
		local newPoint = self.course:getNextRevWaypointIxFromVehiclePosition(self.ppc:getCurrentWaypointIx(), directionNode, 3 )
		self.ppc:initialize(newPoint)
		self:setShovelState(self.states.STATE_GO_BACK_FROM_EMPTYPOINT)
	end
end

-- reverse back to the course
function ShovelModeAIDriver:driveGoBackFromEmptyPoint(dt)
	self.refSpeed = self.vehicle.cp.speeds.reverse
	if not self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) then
		if not self:setShovelToPositionFinshed(self.SHOVEL_POSITIONS.TRANSPORT,dt) then
			--self:hold()
		else
			self:setShovelState(self.states.STATE_TRANSPORT)
		end
	end
end
--bunker silo/ heap is empty 
function ShovelModeAIDriver:driveWorkFinished(dt)
	self:hold()
	self:setInfoText('WORK_END')
end

function ShovelModeAIDriver:getDriveStartUnloadRefSpeed()
	return self.vehicle.cp.speeds.turn
end

---Check if the current dischargeObject has enough free space
---@param dischargeNode dischargeNode of the shovel
---@return boolean object has enough free space, freeSpace > self:getMinNeededFreeCapacity()
function ShovelModeAIDriver:hasEnoughSpaceInObject(dischargeNode)
	local fillType = self.shovel:getDischargeFillType(dischargeNode)
	local object = dischargeNode.dischargeObject
	if object.getFillUnitFreeCapacity ~= nil then
		local freeSpace = object:getFillUnitFreeCapacity(dischargeNode.dischargeFillUnitIndex, fillType, self.vehicle:getActiveFarm())
		local minNeededFreeSpace = self:getMinNeededFreeCapacity()
		self:debugSparse("freeSpace"..tostring(freeSpace).." minNeededFreeSpace: "..tostring(minNeededFreeSpace))
		if freeSpace >= minNeededFreeSpace then 
			return true
		end
	end
end

---Check if the current dischargeObject is almost full ?
---@param dischargeNode dischargeNode of the shovel
---@return boolean object is almost full, free capacity < 300*1/self.shovel:getDischargeNodeEmptyFactor()
---		   the factor is used to compensate for shovels that unload to fast 
function ShovelModeAIDriver:almostFullObject(dischargeNode)
	local fillType = self.shovel:getDischargeFillType(dischargeNode)
	local object = dischargeNode.dischargeObject
	if object.getFillUnitFreeCapacity ~= nil and object:getFillUnitFreeCapacity(dischargeNode.dischargeFillUnitIndex, fillType, self.vehicle:getActiveFarm()) <=300*1/self.shovel:getDischargeNodeEmptyFactor(dischargeNode)  then
		return true
	end
end

function ShovelModeAIDriver:driveIntoSilo(dt)
	local vehicle = self.vehicle
	local fwd = true;
	local allowedToDrive = true
	--get coords of the target point
	local cx,cz = self.bunkerSiloManager:getSiloPartPosition(self.bestTarget.line,self.bestTarget.column)
	local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	--check whether its time to change the target point
	self.bunkerSiloManager:updateTarget(self.bestTarget)

	--reduce speed at end of bunker silo
	if self.bunkerSiloManager:isNearEnd(self.bestTarget) then
		refSpeed = math.min(10,self.refSpeed)
	end

	if vehicle.cp.settings.shovelStopAndGo:is(true) and self:getFillLevelDoesChange() then
		allowedToDrive = false;
	end

	--drive
	local directionNode = self:getDirectionNode()
	local lx, lz = AIVehicleUtil.getDriveDirection(directionNode, cx,cy,cz);
	self:debugRouting()
	self:driveInDirection(dt,lx,lz,fwd,self:getSpeed(),allowedToDrive)
end

function ShovelModeAIDriver:getSpeed()
	if self:getCanGoWithStreetSpeed() then
		-- STATE_TRANSPORT uses recorded speed
		return AIDriver.getRecordedSpeed(self)
	else
		-- custom speed
		return self.refSpeed
	end
end

function ShovelModeAIDriver:getCanGoWithStreetSpeed()
	return self.shovelState == self.states.STATE_TRANSPORT
end

-- check and set the needed shovel position
---@param int next shovel position 
---@return boolean has reached shovel position ?
function ShovelModeAIDriver:setShovelToPositionFinshed(stage,dt)
	return self.vehicle.cp.settings.frontloaderToolPositions:updatePositions(dt,stage)
end

function ShovelModeAIDriver:getIsShovelFull()
	return self.shovel:getFillUnitFillLevel(1) >= self.shovel:getFillUnitCapacity(1)*0.98
end

function ShovelModeAIDriver:getIsShovelEmpty()
	return self.shovel:getFillUnitFillLevel(1) <= self.shovel:getFillUnitCapacity(1)*0.01
end


---Get the minimum required free space to start unloading,
---so we are not constantly starting to unload and the stop again directly
---@return float minimum required free space, shovel min(capacity/5,fillLevel)
function ShovelModeAIDriver:getMinNeededFreeCapacity()
	return math.min(self.shovel:getFillUnitCapacity(1)/5,self.shovel:getFillUnitFillLevel(1))
end

function ShovelModeAIDriver:getFillLevelDoesChange()
	local fillLevel = self.shovel:getFillUnitFillLevel(1)
	if not self.savedLastFillLevel or self.savedLastFillLevel ~= fillLevel then
		self.savedLastFillLevel = fillLevel
		return true
	end
end

function ShovelModeAIDriver:iAmBehindFillEndPoint()
	return self.ppc:getCurrentWaypointIx() > self.shovelFillEndPoint
end

function ShovelModeAIDriver:iAmBeforeEmptyPoint()
	return self.ppc:getCurrentWaypointIx() < self.shovelEmptyPoint
end

function ShovelModeAIDriver:isUnloadingObjectRaycastActive()
	return self.unloadingObjectRaycastActive
end

-- raycast for unloading trigger or trailer at the shovelEmptyPoint
function ShovelModeAIDriver:searchForUnloadingObjectRaycast()
	local ix = self.shovelEmptyPoint
	local node = WaypointNode('proxyNode')
	node:setToWaypoint(self.course, ix, true)
	setRotation(node.node, 0, self.course:getWaypointYRotation(ix-1), 0)
	local lx, lz = MathUtil.getDirectionFromYRotation(self.course:getWaypointYRotation(ix-1))
	local ly = -5
	for i=1,12 do
		if self.shovelState == self.states.STATE_WAIT_FOR_TARGET then
			local x,y,z = localToWorld(node.node,0,8,i/2);
			raycastAll(x, y, z, lx, ly, lz, "searchForUnloadingObjectRaycastCallback", 10, self);
			if courseplay.debugChannels[courseplay.DBG_MODE_9] then
				cpDebug:drawLine(x, y, z, 1, 0, 0, x+lx*10, y+ly*10, z+lz*10);
			end;
		end
	end;
	node:destroy()
end

-- raycastCallback for unloading trigger or trailer at the shovelEmptyPoint
function ShovelModeAIDriver:searchForUnloadingObjectRaycastCallback(transformId, x, y, z, distance, nx, ny, nz, subShapeIndex, hitShapeId)
	local object = g_currentMission:getNodeObject(transformId)
	--has the target already been hit ?

	if self.shovelState ~= self.states.STATE_WAIT_FOR_TARGET then
		return
	end
	if object then
		--is object a vehicle, trailer,...
		if object:isa(Vehicle) then 
			--object supports filltype, bassicly trailer and so on
			if object.getFillUnitSupportsToolType then
				for fillUnitIndex,fillUnit in pairs(object:getFillUnits()) do
					--object supports filling by shovel
					local allowedToFillByShovel = object:getFillUnitSupportsToolType(fillUnitIndex, ToolType.DISCHARGEABLE)
					local dischargeNode = self.shovel:getCurrentDischargeNode()		
					local fillType = self.shovel:getDischargeFillType(dischargeNode)
					--object supports fillType
					local supportedFillType = object:getFillUnitSupportsFillType(fillUnitIndex,fillType)
					if allowedToFillByShovel then 
						self:debug("allowedToFillByShovel")
						if supportedFillType then 
							--valid trailer/ fillableObject found
							
							--check if the vehicle is stopped 
							local rootVehicle = object:getRootVehicle()
							if not AIDriverUtil.isStopped(rootVehicle) then 
								return
							end
							---
							local exactFillRootNode = object:getFillUnitExactFillRootNode(fillUnitIndex) or object.rootNode
							self:debug("supportedFillType")
							self:debug("Trailer found!")
							self.trailerCallback = {
								trailer = object,
								exactFillRootNode = exactFillRootNode
							}
							self:setShovelState(self.states.STATE_START_UNLOAD_TRAILER)
							return
						else
							self:debug("not  supportedFillType")
						end
					else
						self:debug("not  allowedToFillByShovel")
					end
				end
			else
				self:debug("FillUnit not found!")
			end
			return
		--UnloadTrigger found
		elseif object:isa(UnloadTrigger) then 
		--	DebugUtil.printTableRecursively(object, "  ", 0, 2)
			self:debug("UnloadTrigger found!")
			self:setShovelState(self.states.STATE_START_UNLOAD)
			return
		--some diffrent object which is valid
		elseif object.getFillUnitIndexFromNode ~= nil then
		--	DebugUtil.printTableRecursively(object, "  ", 0, 2)
			local fillUnitIndex = object:getFillUnitIndexFromNode(hitShapeId)
			if fillUnitIndex ~= nil then
				local dischargeNode = self.shovel:getCurrentDischargeNode()		
				local fillType = self.shovel:getDischargeFillType(dischargeNode)
				if object:getFillUnitSupportsFillType(fillUnitIndex, fillType) then
					self:debug("Trigger found!")
					self:setShovelState(self.states.STATE_START_UNLOAD)
				else 
					self:debug("fillType not supported!")
				end
			else 
				self:debug("no fillUnitIndex found!")
			end
		end
	else
		self:debug("Nothing found!")
		return
	end
end

function ShovelModeAIDriver:onWaypointPassed(ix)
	if self.course:isWaitAt(ix+1) then
		if ix+1 == self.shovelFillStartPoint then
			self:setShovelState(self.states.STATE_CHECKSILO)
		end
	end
end

---Check if all shovel positions are set correctly
---@return boolean are all shovel positions valid ?
function ShovelModeAIDriver:checkShovelPositionsValid()
	local validToolPositions = self.vehicle.cp.settings.frontloaderToolPositions:hasValidToolPositions()
	if not validToolPositions then 
		courseplay:setInfoText(self.vehicle, 'COURSEPLAY_SHOVEL_POSITIONS_MISSING');
	end
	return validToolPositions
end

---Check if all wait points are set correctly
---@return boolean are all wait points valid ?
function ShovelModeAIDriver:checkWaypointsValid()
	if self.shovelFillStartPoint == nil or self.shovelFillEndPoint == nil or self.shovelEmptyPoint == nil then
		courseplay:setInfoText(self.vehicle, 'COURSEPLAY_NO_VALID_COURSE');
		return false;
	end;
	return true
end

function ShovelModeAIDriver:checkLastWaypoint()
	if self.ppc:reachedLastWaypoint() then
		self.ppc:initialize(1)
		self:resetSiloData()
	end
end

function ShovelModeAIDriver:updateLastMoveCommandTime()
	self:resetLastMoveCommandTime()
end

---old code
function ShovelModeAIDriver:findNextRevWaypoint(currentPoint)
	local vehicle = self.vehicle;
	local directionNode = self:getDirectionNode()
	local _,ty,_ = getWorldTranslation(directionNode);
	for i= currentPoint, self.vehicle.cp.numWaypoints do
		local _,_,z = worldToLocal(directionNode, vehicle.Waypoints[i].cx , ty , vehicle.Waypoints[i].cz);
		if z < -3 and vehicle.Waypoints[i].rev  then
			return i
		end;
	end;
	return currentPoint;
end

function ShovelModeAIDriver:debug(...)
	courseplay.debugVehicle(courseplay.DBG_MODE_9, self.vehicle, ...)
end

function ShovelModeAIDriver:setShovelState(state, extraText)
	local nameString = "none"
	for name,stateState in pairs (self.states) do
		if state == stateState then
			nameString = name
		end
	end
	if self.shovelState ~= state then
		self.shovelState = state;
		self:debug("called setShovelState to "..nameString)
	end
end;

---TODO: Do we want to use this function with heaps ?
---Was the best target directly near a bunker wall 
---@return best target is directly near a bunker wall
function ShovelModeAIDriver:getTargetIsOnBunkerWallColumn()
	local numLines,numColumns =  self.bunkerSiloManager:getNumberOfLinesAndColumns()
	--only allow a straight out reverse course,
	--if there are at least two lines , which is not always the case with heaps 
	if numLines < 2 then 
		return false
	end
	return self.bestTarget.column == 1 or self.bestTarget.column == numColumns
end

--not used ?
function ShovelModeAIDriver:getClosestPointToStartFill()
	local vehicle = self.vehicle;
	local closestDistance = math.huge
	local closestPoint = 0
	for i= self.ppc:getCurrentWaypointIx(), self.course:getNumberOfWaypoints() do
		local px, _, pz = self.course:getWaypointPosition(self.shovelFillStartPoint)
		local distance = self.course:getDistanceBetweenPointAndWaypoint(px, pz, i)
		--print(string.format("try %s distance %s rev %s ",tostring(i),tostring(distance),tostring(self.course:isReverseAt(i))))
		if distance < closestDistance and self.course:isReverseAt(i) then
			--print("set closestPoint to "..i)
			closestDistance = distance
			closestPoint = i
		end
	end
	--print("return "..closestPoint)
	return closestPoint;
end
function ShovelModeAIDriver:getTargetToStraightOut()
	local sX,sZ = self.bunkerSiloManager:getSiloPartPosition(2,self.bestTarget.column)
	local tX,tZ = self.bunkerSiloManager:getSiloPartPosition(1,self.bestTarget.column)
	local dx,_,dz = courseplay:getWorldDirection(sX, 0, sZ, tX, 0, tZ)
	local tempTarget = {
							cx = sX+(dx*30);
							cz = sZ+(dz*30);
	}

	return tempTarget
end

function ShovelModeAIDriver:getIsReversedOutOfSilo()
	local x,z = self.bunkerSiloManager:getSiloPartPosition(self.bestTarget.line,self.bestTarget.column)
	local directionNode = self:getDirectionNode()
	local px,py,pz = worldToLocal(directionNode,x,0,z)
	return pz > 4
end

function ShovelModeAIDriver:setLightsMask(vehicle)
	vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_FULL)
end

function ShovelModeAIDriver:findShovel(object)
	if SpecializationUtil.hasSpecialization(Shovel, object.specializations) and not self.shovel then 
		self.shovel = object
		return
	end
	
	for _,impl in pairs(object:getAttachedImplements()) do
		self:findShovel(impl.object)
	end
end

function ShovelModeAIDriver:getWorkWidth()
	return self.vehicle.cp.workWidth
end

function ShovelModeAIDriver:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	-- TODO: we should not call AIVehicleUtil.driveInDirection, this should be refactored that AIDriver does all the
	-- driving
	local node = fwd and self:getFrontMarkerNode(self.vehicle) or self:getBackMarkerNode(self.vehicle)
	self:updateTrafficConflictDetector(nil, nil, speed, fwd, node)
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function ShovelModeAIDriver:debugRouting()
	if self:isDebugActive() and self.bunkerSiloManager then
		self.bunkerSiloManager:debugRouting(self.bestTarget,self.tempTarget)
	end
end

function ShovelModeAIDriver:drawMap()
	if self:isDebugActive() and self.bunkerSiloManager then
		self.bunkerSiloManager:drawMap()
	end
end

function ShovelModeAIDriver:isTrafficConflictDetectionEnabled()
	return self.trafficConflictDetectionEnabled and self.shovelState.properties.checkForTrafficConflict
end

function ShovelModeAIDriver:isProximitySwerveEnabled()
	return self.shovelState.properties.enableProximitySwerve
end

function ShovelModeAIDriver:isProximitySpeedControlEnabled()
	return self.shovelState.properties.enableProximitySpeedControl
end

---Checks for bunker silo or heaps in between shovelFillStartPoint and shovelFillEndPoint
---@return table bunker silo or simulated heap silo
---@return boolean is the found silo a heap ?
function ShovelModeAIDriver:getTargetBunkerSilo()
	return BunkerSiloManagerUtil.getTargetBunkerSiloBetweenWaypoints(self.vehicle,self.course,self.shovelFillStartPoint,self.shovelFillEndPoint,true)
end