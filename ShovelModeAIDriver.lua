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

NOTE: rotation: movingTool.curRot[1] (only x-axis) / translation: movingTool.curTrans[3] (only z-axis)

NOTE: although lx and lz are passed in as parameters, they are never used.
]]

---@class ShovelModeAIDriver : LevelCompactAIDriver

ShovelModeAIDriver = CpObject(LevelCompactAIDriver)

ShovelModeAIDriver.myStates = {
	STATE_CHECKSILO ={},
	STATE_GOINTO_SILO= {},
	STATE_REVERSE_OUT_OF_SILO ={},
	STATE_REVERSE_STRAIGHT_OUT_OF_SILO={},
	STATE_TRANSPORT= {},
	STATE_WAIT_FOR_TARGET = {},
	STATE_START_UNLOAD = {},
	STATE_WAIT_FOR_UNLOADREADY = {},
	STATE_GO_BACK_FROM_EMPTYPOINT ={},
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
	self:setHudContent()
	self.foundTrailer = nil
end

function ShovelModeAIDriver:setHudContent()
	courseplay.hud:setShovelModeAIDriverContent(self.vehicle)
end

function ShovelModeAIDriver:start()
	self:findShovel(self.vehicle) 
	if not self.shovel then 
		self:error("Error: shovel not found!!")
		return
	end
	
	self:beforeStart()
	--finding my working points
	local vehicle = self.vehicle
	self.shovelFillStartPoint = nil
	self.shovelFillEndPoint = nil
	self.shovelEmptyPoint = nil
	self.mode9SavedLastFillLevel = 0;
	local numWaitPoints = 0
	self.targetSilo = nil
	self.bestTarget = nil
	self.vehicle.cp.shovel.targetFound = nil
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

	--get moving tools (only once after starting)
	if self.vehicle.cp.movingToolsPrimary == nil then
		self.vehicle.cp.movingToolsPrimary, self.vehicle.cp.movingToolsSecondary = courseplay:getMovingTools(self.vehicle);
	end;
	AIDriver.continue(self)
end

function ShovelModeAIDriver:drive(dt)
	if not self:checkShovelPositionsValid() or not self:checkWaypointsValid() then
		return
	end
	local notAllowedToDrive = false
	if self.shovelState == self.states.STATE_CHECKSILO then
		self:hold()
		if self:setShovelToPositionFinshed(2,dt) then
			--initialize first target point
			if self.targetSilo == nil then
				self.targetSilo = courseplay:getMode9TargetBunkerSilo(self.vehicle)
			end
			if self.bestTarget == nil or self.vehicle.cp.BunkerSiloMap == nil then
				self.bestTarget, self.firstLine = self:getBestTargetFillUnitFillUp(self.targetSilo,self.bestTarget)
			end
		end
		if self.bestTarget then
			self:setShovelState(self.states.STATE_GOINTO_SILO)
		end

	elseif self.shovelState == self.states.STATE_GOINTO_SILO then
		self.refSpeed = self.vehicle.cp.speeds.field
		local fwd = true
		self:driveIntoSilo(dt)

		if self:isAtEnd() and self:getIsShovelEmpty() then
			self:setShovelState(self.states.STATE_WORK_FINISHED)
			return
		end

		if self:getIsShovelFull() or self:isAtEnd() then
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
	elseif self.shovelState == self.states.STATE_REVERSE_STRAIGHT_OUT_OF_SILO then
		self.refSpeed = self.vehicle.cp.speeds.reverse
		if not self:setShovelToPositionFinshed(3,dt) then
			self:hold()
		end
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
	elseif self.shovelState == self.states.STATE_REVERSE_OUT_OF_SILO then
		self.refSpeed = self.vehicle.cp.speeds.reverse
		if not self:setShovelToPositionFinshed(3,dt) then
			self:hold()
		end
		if not self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) then
			self:setShovelState(self.states.STATE_TRANSPORT);
		end
	elseif self.shovelState == self.states.STATE_TRANSPORT then
		if self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, self.shovelEmptyPoint) < 15
			and self:iAmBeforeEmptyPoint()
			and self:iAmBehindFillEndPoint() then
				self:setShovelState(self.states.STATE_WAIT_FOR_TARGET)
		end
		--backup for starting somewhere in between
		if not self:setShovelToPositionFinshed(3,dt) then
			self:hold()
		end
	elseif self.shovelState == self.states.STATE_WAIT_FOR_TARGET then
		self.refSpeed = self.vehicle.cp.speeds.crawl
		if self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, self.shovelEmptyPoint) < 10 then 
			self:hold()
		end
		if self:setShovelToPositionFinshed(4,dt) then
			--search for UnloadStation(UnloadTrigger) or correct Trailer ahead, else wait
			self:searchForUnloadingObjectRaycast()
		end
	elseif self.shovelState == self.states.STATE_START_UNLOAD then
		self.refSpeed = self.vehicle.cp.speeds.turn
		local currentDischargeNode = self.shovel:getCurrentDischargeNode()
		if self.shovel:getCanDischargeToObject(currentDischargeNode) and currentDischargeNode.dischargeObject then
			if self:setShovelToPositionFinshed(5,dt) then
				self:setShovelState(self.states.STATE_WAIT_FOR_UNLOADREADY);
			end;
			self:hold()
		elseif currentDischargeNode.dischargeObject or currentDischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_NO_FREE_CAPACITY then 
			self:hold()
		else --drive in straight line to waitPoint is UnloadStation(UnloadTrigger) or correct Trailer was found
			notAllowedToDrive = true
			local gx, _, gz = self.course:getWaypointLocalPosition(self:getDirectionNode(),self.shovelEmptyPoint)
			self:driveVehicleToLocalPosition(dt, true, true, gx, gz, self.refSpeed)
		end
	elseif self.shovelState == self.states.STATE_WAIT_FOR_UNLOADREADY then
		self:hold()
		local dischargeNode = self.shovel:getCurrentDischargeNode()		
		if self:getIsShovelEmpty() or not self.shovel:getCanDischargeToObject(dischargeNode) and self.foundTrailer then
			if self:setShovelToPositionFinshed(4,dt) then
				local newPoint = self.course:getNextRevWaypointIxFromVehiclePosition(self.ppc:getCurrentWaypointIx(), self.vehicle.cp.directionNode, 3 )
				self.ppc:initialize(newPoint)
				self:setShovelState(self.states.STATE_GO_BACK_FROM_EMPTYPOINT);
			end
		end
	elseif self.shovelState == self.states.STATE_GO_BACK_FROM_EMPTYPOINT then
		self.refSpeed = self.vehicle.cp.speeds.reverse
		if not self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) then
			if not self:setShovelToPositionFinshed(3,dt) then
				--self:hold()
			else
				self.shovel.targetFound = nil
				self:setShovelState(self.states.STATE_TRANSPORT)
			end
		end
		self.foundTrailer=nil
	elseif self.shovelState == self.states.STATE_WORK_FINISHED then
		self:hold()
		self:setInfoText('WORK_END')
	end
	self:updateInfoText()
	self.ppc:update()
	if not notAllowedToDrive then
		AIDriver.driveCourse(self, dt)
	end
	self:resetSpeed()
	self:checkLastWaypoint()
end

function ShovelModeAIDriver:driveIntoSilo(dt)
	local vehicle = self.vehicle
	local fwd = true;
	local allowedToDrive = true
	local cx ,cy,cz = 0,0,0
	--get coords of the target point
	local targetUnit = vehicle.cp.BunkerSiloMap[self.bestTarget.line][self.bestTarget.column]
	cx ,cz = targetUnit.cx, targetUnit.cz
	cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	--check whether its time to change the target point
	self:updateTarget()

	--reduce speed at end o silo
	if self:isNearEnd() then
		refSpeed = math.min(10,self.refSpeed)
	end

	if vehicle.cp.shovelStopAndGo and self:getFillLevelDoesChange() then
		allowedToDrive = false;
	end

	--drive
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, cx,cy,cz);
	self:debugRouting()
	self:driveInDirection(dt,lx,lz,fwd,self:getSpeed(),allowedToDrive)
end

function ShovelModeAIDriver:getSpeed()
	if self:getCanGoWithStreetSpeed() then
		return AIDriver.getRecordedSpeed(self)
	else
		return self.refSpeed
	end
end

function ShovelModeAIDriver:getCanGoWithStreetSpeed()
	return self.shovelState == self.states.STATE_TRANSPORT
end

function ShovelModeAIDriver:setShovelToPositionFinshed(stage,dt)
	local mt, secondary = self.vehicle.cp.movingToolsPrimary, self.vehicle.cp.movingToolsSecondary;
	return courseplay:checkAndSetMovingToolsPosition(self.vehicle, mt, secondary, self.vehicle.cp.shovelStatePositions[stage], dt)
end

function ShovelModeAIDriver:getIsShovelFull()
	return self.shovel:getFillUnitFillLevel(1) >= self.shovel:getFillUnitCapacity(1)*0.98
end

function ShovelModeAIDriver:getIsShovelEmpty()
	return self.shovel:getFillUnitFillLevel(1) <= self.shovel:getFillUnitCapacity(1)*0.01
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

function ShovelModeAIDriver:searchForUnloadingObjectRaycast()
	local vehicle = self.vehicle
	local rx, ry, rz = self.course:getWaypointPosition(self.shovelEmptyPoint)
	local nx, nz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, rx, ry, rz);
	local lx7,ly7,lz7 = localDirectionToWorld(vehicle.cp.directionNode, nx, -1, nz);
	for i=6,12 do
		if self.shovelState == self.states.STATE_WAIT_FOR_TARGET then
			local x,y,z = localToWorld(vehicle.cp.directionNode,0,4,i);
			raycastAll(x, y, z, lx7, ly7, lz7, "searchForUnloadingObjectRaycastCallback", 10, self);
			if courseplay.debugChannels[10] then
				cpDebug:drawLine(x, y, z, 1, 0, 0, x+lx7*10, y+ly7*10, z+lz7*10);
			end;
		end
	end;
end

function ShovelModeAIDriver:searchForUnloadingObjectRaycastCallback(transformId, x, y, z, distance)
	local trailer = g_currentMission.nodeToObject[transformId]
	if trailer then
		if trailer:isa(Vehicle) then 
			if trailer.getFillUnitSupportsToolType then
				for fillUnitIndex,fillUnit in pairs(trailer:getFillUnits()) do
					local allowedToFillByShovel = trailer:getFillUnitSupportsToolType(fillUnitIndex, ToolType.DISCHARGEABLE)
					local dischargeNode = self.shovel:getCurrentDischargeNode()		
					local fillType = self.shovel:getDischargeFillType(dischargeNode)
					local supportedFillType = trailer:getFillUnitSupportsFillType(fillUnitIndex,fillType)
					if allowedToFillByShovel then 
						self:debug("allowedToFillByShovel")
						if supportedFillType then 
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
		elseif trailer:isa(UnloadTrigger) then 
			self:debug("UnloadTrigger found!")
			self:setShovelState(self.states.STATE_START_UNLOAD)
			return
		end
	else
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

function ShovelModeAIDriver:checkShovelPositionsValid()
	if self.vehicle.cp.shovelStatePositions == nil or self.vehicle.cp.shovelStatePositions[2] == nil or self.vehicle.cp.shovelStatePositions[3] == nil or self.vehicle.cp.shovelStatePositions[4] == nil or self.vehicle.cp.shovelStatePositions[5] == nil then
			courseplay:setInfoText(self.vehicle, 'COURSEPLAY_SHOVEL_POSITIONS_MISSING');
			return false;
	end
	return true
end

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
		self.vehicle.cp.BunkerSiloMap = nil
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
	return self.bestTarget.column == 1 or self.bestTarget.column == #vehicle.cp.BunkerSiloMap[#vehicle.cp.BunkerSiloMap]
end

function ShovelModeAIDriver:getClosestPointToStartFill()
	local vehicle = self.vehicle;
	local closestDistance = math.huge
	local closestPoint = 0
	for i= self.ppc:getCurrentWaypointIx(), self.course:getNumberOfWaypoints() do
		local px, _, pz = self.course:getWaypointPosition(vehicle.cp.shovelFillStartPoint)
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
	local sX,sZ = vehicle.cp.BunkerSiloMap[2][self.bestTarget.column].cx,vehicle.cp.BunkerSiloMap[2][self.bestTarget.column].cz
	local tX,tZ = vehicle.cp.BunkerSiloMap[1][self.bestTarget.column].cx,vehicle.cp.BunkerSiloMap[1][self.bestTarget.column].cz
	local dx,_,dz = courseplay:getWorldDirection(sX, 0, sZ, tX, 0, tZ)
	local tempTarget = {
							cx = sX+(dx*30);
							cz = sZ+(dz*30);
	}

	return tempTarget
end

function ShovelModeAIDriver:getIsReversedOutOfSilo()
	local x,z = self.vehicle.cp.BunkerSiloMap[1][self.bestTarget.column].cx,self.vehicle.cp.BunkerSiloMap[1][self.bestTarget.column].cz
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
		ShovelModeAIDriver:findShovel(impl.object)
	end
end

