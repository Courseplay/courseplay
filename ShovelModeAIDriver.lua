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
	STATE_GO_BACK_FROM_EMPTYPOINT = {},
	STATE_WORK_FINISHED = {}
}


--- Constructor
function ShovelModeAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'ShovelModeAIDriver:init') 
	AIDriver.init(self, vehicle)
	self:initStates(ShovelModeAIDriver.myStates)
	--self.mode = courseplay.MODE_SHOVEL_FILL_AND_EMPTY
	self.shovelState = self.states.STATE_TRANSPORT
	self.refSpeed = 15
	self.foundTrailer = nil
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
	self.vehicle.cp.settings.stopAtEnd:set(false)
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
	self.shovelFillStartPoint = nil
	self.shovelFillEndPoint = nil
	self.shovelEmptyPoint = nil
	self.mode9SavedLastFillLevel = 0;
	local numWaitPoints = 0
	self.targetSilo = nil
	self.bestTarget = nil
	self.bunkerSilo = nil
	for i,wp in pairs(vehicle.Waypoints) do
		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
			vehicle.cp.waitPoints[numWaitPoints] = i;
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

--debug info
function ShovelModeAIDriver:onDraw()
	if self:isDebugActive() and self.shovel then 
		local y = 0.5
		y = self:renderText(y,"state: "..tostring(self.shovelState.name),0.4)
		y = self:renderText(y,"hasbunkerSiloManager: "..tostring(self.bunkerSiloManager ~= nil),0.4)
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
	return courseplay.debugChannels[10]
end

function ShovelModeAIDriver:drive(dt)
	if not self:checkShovelPositionsValid() or not self:checkWaypointsValid() then
		return
	end
	local notAllowedToDrive = false
	--get the relevant bunkerSilo/Heap data
	if self.shovelState == self.states.STATE_CHECKSILO then
		self:hold()
		if self:setShovelToPositionFinshed(2,dt) then
			--initialize first target point
			if self.bunkerSiloManager == nil then 
				local silo,isHeap = BunkerSiloManagerUtil.getTargetBunkerSilo(self.vehicle,nil,true)
				if silo then 
					self.bunkerSiloManager =  BunkerSiloManager(self.vehicle, silo, self:getWorkWidth(),self.shovel,isHeap)
				end
			end
			if self.bunkerSiloManager and self.bestTarget == nil then
				self.bestTarget, self.firstLine = self.bunkerSiloManager:getBestTargetFillUnitFillUp(self.bestTarget)
			end
		end
		self:drawMap()
		if self.bestTarget then
			self:setShovelState(self.states.STATE_GOINTO_SILO)
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
				self.tempTarget = self:getTargetToStraightOut()
				self:setShovelState(self.states.STATE_REVERSE_STRAIGHT_OUT_OF_SILO)
			else
				local _,_,Zoffset = self.course:getWaypointLocalPosition(self.vehicle.cp.directionNode, self.shovelFillStartPoint)
				local newPoint = self.course:getNextRevWaypointIxFromVehiclePosition(self.ppc:getCurrentWaypointIx(), self.vehicle.cp.directionNode,-Zoffset)
				self.ppc:initialize(newPoint)
				self:setShovelState(self.states.STATE_REVERSE_OUT_OF_SILO)
				self.bestTarget = nil
			end
		end

		return
	--driving back out of the bunkerSilo
	elseif self.shovelState == self.states.STATE_REVERSE_STRAIGHT_OUT_OF_SILO then
		self.refSpeed = self.vehicle.cp.speeds.reverse
		if not self:setShovelToPositionFinshed(3,dt) then
			self:hold()
		end
		self:drawMap()
		if self:getIsReversedOutOfSilo() then
			local _,_,Zoffset = self.course:getWaypointLocalPosition(self.vehicle.cp.directionNode, self.shovelFillStartPoint)
			local newPoint = self.course:getNextRevWaypointIxFromVehiclePosition(self.ppc:getCurrentWaypointIx(), self.vehicle.cp.directionNode,-Zoffset)
			self.ppc:initialize(newPoint)
			self:setShovelState(self.states.STATE_TRANSPORT)
			self.bestTarget = nil
		end
		--drive to temp target
		if self.tempTarget then
			local cx,cz = self.tempTarget.cx,self.tempTarget.cz
			local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
			local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, cx,cy,cz);
			lx,lz = -lx,-lz;
			self:driveInDirection(dt,lx,lz,false,self:getSpeed(),true)
			self:debugRouting()
			return
		end
	--driving back out of the bunkerSilo
	elseif self.shovelState == self.states.STATE_REVERSE_OUT_OF_SILO then
		self.refSpeed = self.vehicle.cp.speeds.reverse
		if not self:setShovelToPositionFinshed(3,dt) then
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
		if not self:setShovelToPositionFinshed(3,dt) then
			self:hold()
		end
	-- close to the unload waitpoint, so set pre unload shovel position and do a raycast for unload triggers, trailers
	elseif self.shovelState == self.states.STATE_WAIT_FOR_TARGET then
		self:driveWaitForTarget(dt)
	-- drive to the unload trigger/ trailer
	elseif self.shovelState == self.states.STATE_START_UNLOAD then
		notAllowedToDrive =	self:driveStartUnload(dt)
	-- handle unloading
	elseif self.shovelState == self.states.STATE_WAIT_FOR_UNLOADREADY then
		self:driveWaitForUnloadReady(dt)
	-- reverse back to the course
	elseif self.shovelState == self.states.STATE_GO_BACK_FROM_EMPTYPOINT then
		self:driveGoBackFromEmptyPoint(dt)
	--bunker silo/ heap is empty 
	elseif self.shovelState == self.states.STATE_WORK_FINISHED then
		self:driveWorkFinished(dt)
	end
	self:updateInfoText()
	self.ppc:update()
	if not notAllowedToDrive then
		AIDriver.drive(self, dt)
	end
	self:resetSpeed()
	self:checkLastWaypoint()
end

function ShovelModeAIDriver:isStuck()
	if self:doesNotMove() then
		if self.vehicle.cp.timers.slipping == nil or self.vehicle.cp.timers.slipping == 0 then
			courseplay:setCustomTimer(self.vehicle, 'slipping', 2);
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
	if self:setShovelToPositionFinshed(4,dt) then
		--search for UnloadStation(UnloadTrigger) or correct Trailer ahead, else wait
		self:searchForUnloadingObjectRaycast()
	end
end
-- drive to the unload trigger/ trailer
function ShovelModeAIDriver:driveStartUnload(dt)
	self.refSpeed = self:getDriveStartUnloadRefSpeed()
	local currentDischargeNode = self.shovel:getCurrentDischargeNode()
	-- if shovel is empty we can return direct back from the trigger
	if self:getIsShovelEmpty() then 
		self:setShovelState(self.states.STATE_WAIT_FOR_UNLOADREADY);
	end
	-- if we can discharge at unload trigger or trailer has enough free space
	if self.shovel:getCanDischargeToObject(currentDischargeNode) and currentDischargeNode.dischargeObject and (self:hasEnoughSpaceInObject(currentDischargeNode) or self.foundTrailer) then
		if self:setShovelToPositionFinshed(5,dt) then
			self:setShovelState(self.states.STATE_WAIT_FOR_UNLOADREADY);
		end;
		self:hold()
	-- if there is no more free space move shovel back to pre unload position
	elseif currentDischargeNode.dischargeObject or currentDischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_NO_FREE_CAPACITY then 
		self:setShovelToPositionFinshed(4,dt)
		self:hold()
	--drive in straight line to waitPoint is UnloadStation(UnloadTrigger) or correct Trailer was found
	elseif not self:getIsShovelEmpty() then 
		if self.course:getDistanceToNextWaypoint(self.shovelEmptyPoint) <2 then 
			-- the last 2m we drive straight to the unload trigger/ trailer
			notAllowedToDrive = true
			local gx, _, gz = self.course:getWaypointLocalPosition(self:getDirectionNode(),self.shovelEmptyPoint)
			self:driveVehicleToLocalPosition(dt, true, true, gx, gz, self.refSpeed)
		end
	end
	return notAllowedToDrive
end
-- handle unloading
function ShovelModeAIDriver:driveWaitForUnloadReady(dt)
	self:hold()
	local dischargeNode = self.shovel:getCurrentDischargeNode()		
	-- drive back to the course
	if self:getIsShovelEmpty() or not self.shovel:getCanDischargeToObject(dischargeNode) and self.foundTrailer then
		if self:setShovelToPositionFinshed(4,dt) then
			local newPoint = self.course:getNextRevWaypointIxFromVehiclePosition(self.ppc:getCurrentWaypointIx(), self.vehicle.cp.directionNode, 3 )
			self.ppc:initialize(newPoint)
			self:setShovelState(self.states.STATE_GO_BACK_FROM_EMPTYPOINT);
		end
	--stop unloading at unload trigger if there is no more free space
	elseif (not self.shovel:getCanDischargeToObject(dischargeNode) or self:almostFullObject(dischargeNode)) and not self.foundTrailer then
		self:setShovelState(self.states.STATE_START_UNLOAD);
	end		
end
-- reverse back to the course
function ShovelModeAIDriver:driveGoBackFromEmptyPoint(dt)
	self.refSpeed = self.vehicle.cp.speeds.reverse
	if not self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) then
		if not self:setShovelToPositionFinshed(3,dt) then
			--self:hold()
		else
			self:setShovelState(self.states.STATE_TRANSPORT)
		end
	end
	self.foundTrailer=nil
end
--bunker silo/ heap is empty 
function ShovelModeAIDriver:driveWorkFinished(dt)
	self:hold()
	self:setInfoText('WORK_END')
end

function ShovelModeAIDriver:getDriveStartUnloadRefSpeed()
	return self.vehicle.cp.speeds.turn
end

--check for enough free space to start unloading
---@param dischargeNode dischargeNode of the shovel
---@return boolean has enough free space
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

--check if no more free space here
---@param dischargeNode dischargeNode of the shovel
---@return boolean not enough free space left
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
	local cx ,cy,cz = 0,0,0
	--get coords of the target point
	local targetUnit = self.bunkerSiloManager.siloMap[self.bestTarget.line][self.bestTarget.column]
	cx ,cz = targetUnit.cx, targetUnit.cz
	cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
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
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, cx,cy,cz);
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
---@param int next shovel position offset by +1 because of old code
---@return boolean has reached shovel position ?
function ShovelModeAIDriver:setShovelToPositionFinshed(stage,dt)
	return self.vehicle.cp.settings.frontloaderToolPositions:updatePositions(dt,stage-1)
end

function ShovelModeAIDriver:getIsShovelFull()
	return self.shovel:getFillUnitFillLevel(1) >= self.shovel:getFillUnitCapacity(1)*0.98
end

function ShovelModeAIDriver:getIsShovelEmpty()
	return self.shovel:getFillUnitFillLevel(1) <= self.shovel:getFillUnitCapacity(1)*0.01
end


-- get the minimum required free space
---@return boolean min needed free space
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
			if courseplay.debugChannels[10] then
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
							self:debug("supportedFillType")
							self:debug("Trailer found!")
							self:setShovelState(self.states.STATE_START_UNLOAD)
							self.foundTrailer = true
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

-- are all the shovel positions correctly set ?
---@return boolean are shovel positions okay
function ShovelModeAIDriver:checkShovelPositionsValid()
	local validToolPositions = self.vehicle.cp.settings.frontloaderToolPositions:hasValidToolPositions()
	if not validToolPositions then 
		courseplay:setInfoText(self.vehicle, 'COURSEPLAY_SHOVEL_POSITIONS_MISSING');
	end
	return validToolPositions
end

-- are all 3 needed waitpoint correctly setup ?
---@return boolean has necessary waitpoints 
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
		self.bunkerSiloManager = nil
	end
end

function ShovelModeAIDriver:updateLastMoveCommandTime()
	self:resetLastMoveCommandTime()
end

function ShovelModeAIDriver:findNextRevWaypoint(currentPoint)
	local vehicle = self.vehicle;
	local _,ty,_ = getWorldTranslation(vehicle.cp.directionNode);
	for i= currentPoint, self.vehicle.cp.numWaypoints do
		local _,_,z = worldToLocal(vehicle.cp.directionNode, vehicle.Waypoints[i].cx , ty , vehicle.Waypoints[i].cz);
		if z < -3 and vehicle.Waypoints[i].rev  then
			return i
		end;
	end;
	return currentPoint;
end

function ShovelModeAIDriver:debug(...)
	courseplay.debugVehicle(10, self.vehicle, ...)
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

function ShovelModeAIDriver:getTargetIsOnBunkerWallColumn()
	local vehicle = self.vehicle
	return self.bestTarget.column == 1 or self.bestTarget.column == #self.bunkerSiloManager.siloMap[#self.bunkerSiloManager.siloMap]
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
	local vehicle = self.vehicle
	local sX,sZ = self.bunkerSiloManager.siloMap[2][self.bestTarget.column].cx,self.bunkerSiloManager.siloMap[2][self.bestTarget.column].cz
	local tX,tZ = self.bunkerSiloManager.siloMap[1][self.bestTarget.column].cx,self.bunkerSiloManager.siloMap[1][self.bestTarget.column].cz
	local dx,_,dz = courseplay:getWorldDirection(sX, 0, sZ, tX, 0, tZ)
	local tempTarget = {
							cx = sX+(dx*30);
							cz = sZ+(dz*30);
	}

	return tempTarget
end

function ShovelModeAIDriver:getIsReversedOutOfSilo()
	local x,z = self.bunkerSiloManager.siloMap[1][self.bestTarget.column].cx,self.bunkerSiloManager.siloMap[1][self.bestTarget.column].cz
	local px,py,pz = worldToLocal(self.vehicle.cp.directionNode,x,0,z)
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
