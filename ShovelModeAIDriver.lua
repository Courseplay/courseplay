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

---@class ShovelModeAIDriver : AIDriver

ShovelModeAIDriver = CpObject(AIDriver)
ShovelModeAIDriver.STATE_GOTO_SILO = 1
ShovelModeAIDriver.STATE_GOINTO_SILO = 2
ShovelModeAIDriver.STATE_TRANSPORT = 3
ShovelModeAIDriver.STATE_WAIT_FOR_TARGET = 4
ShovelModeAIDriver.STATE_START_UNLOAD = 5
ShovelModeAIDriver.STATE_WAIT_FOR_UNLOADREADY = 6
ShovelModeAIDriver.STATE_GO_BACKTO_START = 7

--- Constructor
function ShovelModeAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'ShovelModeAIDriver:init') 
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_SHOVEL_FILL_AND_EMPTY
	self.refSpeed = 3
end

function ShovelModeAIDriver:start(ix)
	self:beforeStart()
	--finding my working points
	local vehicle = self.vehicle
	vehicle.cp.shovelFillStartPoint = nil
	vehicle.cp.shovelFillEndPoint = nil
	vehicle.cp.shovelEmptyPoint = nil
	vehicle.cp.mode9SavedLastFillLevel = 0;
	local numWaitPoints = 0

	for i,wp in pairs(vehicle.Waypoints) do
		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
			vehicle.cp.waitPoints[numWaitPoints] = i;
		end;

		if numWaitPoints == 1 and vehicle.cp.shovelFillStartPoint == nil then
			vehicle.cp.shovelFillStartPoint = i;
		end;
		if numWaitPoints == 2 and vehicle.cp.shovelFillEndPoint == nil then
			vehicle.cp.shovelFillEndPoint = i;
		end;
		if numWaitPoints == 3 and vehicle.cp.shovelEmptyPoint == nil then
			vehicle.cp.shovelEmptyPoint = i;
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
	self:setShovelState(vehicle, self.STATE_GOTO_SILO, 'backup');
	--courseplay:setWaypointIndex(vehicle, 1);
	self.course = Course(self.vehicle , self.vehicle.Waypoints)
	self.ppc:setCourse(self.course)
	self.ppc:initialize(1)
	--get moving tools (only once after starting)
	if self.vehicle.cp.movingToolsPrimary == nil then
		self.vehicle.cp.movingToolsPrimary, self.vehicle.cp.movingToolsSecondary = courseplay:getMovingTools(self.vehicle);
	end;
end

function ShovelModeAIDriver:drive(dt)
	-- update current waypoint/goal point
	self.ppc:update()
	local lx, lz = 0,0
	local allowedToDrive = true
	local moveForwards
	local vehicle = self.vehicle;
	courseplay:updateFillLevelsAndCapacities(vehicle)
	local fillLevelPct = vehicle.cp.totalFillLevelPercent
	local mt, secondary = vehicle.cp.movingToolsPrimary, vehicle.cp.movingToolsSecondary;
	
	if self.ppc:getCurrentWaypointIx() == 1 and vehicle.cp.shovelState ~= self.STATE_GO_BACKTO_START then  --backup for missed approach
		self:setShovelState(vehicle, self.STATE_GOTO_SILO, 'backup');
		courseplay:setIsLoaded(vehicle, false);
	end;
	
	-- STATE 1: DRIVE TO BUNKER SILO (1st waiting point)
	if vehicle.cp.shovelState == self.STATE_GOTO_SILO then
		self.refSpeed = AIDriver.getSpeed(self)
		if self.ppc:getCurrentWaypointIx() + 1 > vehicle.cp.shovelFillStartPoint then
			if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[2], dt) then
				self:setShovelState(vehicle, self.STATE_GOINTO_SILO);
			elseif vehicle.cp.shovelStopAndGo then
				allowedToDrive = false
			end;
			if fillLevelPct >= 98 then
				vehicle.cp.shovel:setFillUnitFillLevelToDisplay(1 ,vehicle.cp.shovel.cp.capacity * 0.97, vehicle.cp.shovel.cp.fillType);
			end;
			if vehicle.cp.mode9TargetSilo == nil then
				self:debug('%s: vehicle.cp.mode9TargetSilo = nil call getTargetBunkerSilo',nameNum(vehicle));
				vehicle.cp.mode9TargetSilo = courseplay:getMode9TargetBunkerSilo(vehicle)
			end
			if vehicle.cp.mode9TargetSilo then
				if vehicle.cp.BunkerSiloMap == nil then
					local label = vehicle.cp.mode9TargetSilo.saveId or "heap"
					self:debug('%s: vehicle.cp.mode9TargetSilo = %s call createMap',nameNum(vehicle),tostring(label))
					vehicle.cp.BunkerSiloMap = courseplay:createBunkerSiloMap(vehicle, vehicle.cp.mode9TargetSilo)
					if vehicle.cp.BunkerSiloMap ~= nil then
						local stopSearching = false
						local mostFillLevelAtLine = 0
						local mostFillLevelIndex = 2
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
									if vehicle.cp.mode9SavedLastFillLevel == courseplay:round(fillUnit.fillLevel,1) then
										self:debug('%s triesTheSameFillUnit fillLevel: %s',nameNum(vehicle),tostring(vehicle.cp.mode9SavedLastFillLevel))
										vehicle.cp.mode9triesTheSameFillUnit = true
									end
									vehicle.cp.actualTarget = {
														line = lineIndex;
														column = mostFillLevelIndex;
																}
									vehicle.cp.mode9SavedLastFillLevel = courseplay:round(fillUnit.fillLevel,1)
									
									stopSearching = true
									break
								end
							end
						end
					end
				else
					
					
				
				end
			end
		end;


	-- STATE 2: PREPARE LOADING
	elseif vehicle.cp.shovelState == self.STATE_GOINTO_SILO then
		self.refSpeed = self.vehicle.cp.speeds.turn
		local heapEnd = false
		if vehicle.cp.mode9TargetSilo and vehicle.cp.BunkerSiloMap and vehicle.cp.actualTarget then
			local targetUnit = vehicle.cp.BunkerSiloMap[vehicle.cp.actualTarget.line][vehicle.cp.actualTarget.column]
			local cx , cz = targetUnit.cx, targetUnit.cz
			local dischargeNode = vehicle.cp.shovel:getCurrentDischargeNode()
			local nx,ny,nz = getWorldTranslation(dischargeNode.node)
			local _,_,backUpZ = worldToLocal(vehicle.cp.DirectionNode, cx , targetUnit.y , cz); -- its the savety switch in case I miss the point 
			local distanceToTarget =  courseplay:distance(nx, nz, cx, cz) --distance from shovel to target
			
			if distanceToTarget < 1 or backUpZ < 2 then
				if vehicle.cp.actualTarget.line == #vehicle.cp.BunkerSiloMap and vehicle.cp.mode9TargetSilo.type and vehicle.cp.mode9TargetSilo.type == "heap" then
					heapEnd = true
				end
				vehicle.cp.actualTarget.line = math.min(vehicle.cp.actualTarget.line + 1,#vehicle.cp.BunkerSiloMap)
				vehicle.cp.mode9triesTheSameFillUnit = false
			end
			if vehicle.cp.mode9triesTheSameFillUnit and distanceToTarget < 3 then
				local fillType = targetUnit.fillType 
				if courseplay:getFreeCapacity(vehicle.cp.shovel,fillType)>= targetUnit.fillLevel then
					local takenFromGround = DensityMapHeightUtil.removeFromGroundByArea(targetUnit.sx, targetUnit.sz, targetUnit.wx, targetUnit.wz, targetUnit.hx, targetUnit.hz,fillType )
					if takenFromGround > 0 then
						vehicle.cp.shovel:setUnitFillLevel(1, takenFromGround + vehicle.cp.shovel:getFillLevel(fillType), 0, true)
						self:debug('%s couldnt get the material %s[%i]-> remove %s fromArea',nameNum(vehicle),g_fillTypeManager.indexToFillType[fillType].name,fillType,tostring(takenFromGround))
					end
				else
					self:debug('%s couldnt get the material %s[%i] but its too much for the shovel-> not remove fromArea',nameNum(vehicle),g_fillTypeManager.indexToFillType[fillType].name,fillType)
				end
			end
			lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, cx, targetUnit.y, cz);
		end
		if vehicle.cp.shovelStopAndGo then
			if vehicle.cp.shovelLastFillLevel == nil then
				vehicle.cp.shovelLastFillLevel = fillLevelPct;
			elseif vehicle.cp.shovelLastFillLevel ~= nil and fillLevelPct == vehicle.cp.shovelLastFillLevel and fillLevelPct < 100 then
				--allowedToDrive = true;
			elseif vehicle.cp.shovelLastFillLevel ~= nil and vehicle.cp.shovelLastFillLevel ~= fillLevelPct then
				allowedToDrive = false;
			end;
			vehicle.cp.shovelLastFillLevel = fillLevelPct;
		end;
						--vv TODO checkif its a Giants Bug the Shovel never gets 100%
		if fillLevelPct >= 99 or vehicle.cp.isLoaded or vehicle.cp.slippingStage == 2 or heapEnd then
			if not vehicle.cp.isLoaded then
				local newWP = self:findNextRevWaypoint(self.ppc:getCurrentWaypointIx())
				--courseplay:setWaypointIndex(vehicle, newWP)
				self.ppc:initialize(newWP);
				self.ppc:update()
				courseplay:setIsLoaded(vehicle, true);
				
				if not g_currentMission.missionInfo.stopAndGoBraking then
					vehicle.nextMovingDirection = -1
				end
			else
				if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[3], dt) then
					if vehicle.cp.slippingStage == 2 then
						vehicle.cp.slippingStageBreak = true
						self:setShovelState(vehicle, self.STATE_TRANSPORT,' aborted by slipping');
					else
						self:setShovelState(vehicle, self.STATE_TRANSPORT);
					end
				else
					allowedToDrive = false;
				end;
			end;
		end;
		
		AIDriver.driveVehicleInDirection(self, dt, allowedToDrive, true, lx, lz, self.vehicle.cp.speeds.turn)
		return
	-- STATE 3: TRANSPORT TO BGA
	elseif vehicle.cp.shovelState == self.STATE_TRANSPORT then
		self.refSpeed = AIDriver.getSpeed(self)
		local p = vehicle.cp.shovelFillStartPoint
		local _,y,_ = getWorldTranslation(vehicle.cp.DirectionNode);
		local _,_,z = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[p].cx ,y, vehicle.Waypoints[p].cz); 
		--[[if vehicle.cp.BunkerSiloMap ~= nil and self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) and z < -5 then
			lx, lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, vehicle.Waypoints[p].cx, y, vehicle.Waypoints[p].cz);
		end]]
		if vehicle.cp.slippingStageBreak and not self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) then
			vehicle.cp.slippingStageBreak = nil
			if fillLevelPct < 75 then
				courseplay:setIsLoaded(vehicle, false);
				self:setShovelState(vehicle, self.STATE_GOTO_SILO,'try again');
				--courseplay:setWaypointIndex(vehicle, vehicle.cp.shovelFillStartPoint - 1);
				vehicle.cp.BunkerSiloMap = nil
			end
		end
		
		local distanceToEmptyPoint = self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, vehicle.cp.shovelEmptyPoint)
		if distanceToEmptyPoint < 15 then
			self:setShovelState(vehicle, self.STATE_WAIT_FOR_TARGET);

		end;
	-- STATE 4: WAIT FOR TRAILER 10m BEFORE EMPTYING POINT
	elseif vehicle.cp.shovelState == self.STATE_WAIT_FOR_TARGET then
		self.refSpeed = self.vehicle.cp.speeds.crawl
		if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[4], dt) then
			vehicle.cp.shovel.targetFound = nil;
			local rx, ry, rz = self.course:getWaypointPosition(vehicle.cp.shovelEmptyPoint)
			local nx, nz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, rx, ry, rz);
			local lx7,ly7,lz7 = localDirectionToWorld(vehicle.cp.DirectionNode, nx, -1, nz);
			for i=6,12 do
				if vehicle.cp.shovel.targetFound == nil then
					local x,y,z = localToWorld(vehicle.cp.DirectionNode,0,4,i);
					raycastAll(x, y, z, lx7, ly7, lz7, "findTrailerRaycastCallback", 10, vehicle);
					if courseplay.debugChannels[10] then
						cpDebug:drawLine(x, y, z, 1, 0, 0, x+lx7*10, y+ly7*10, z+lz7*10);
					end;
				end
			end;
			local distanceToEmptyPoint = self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, vehicle.cp.shovelEmptyPoint)
			if vehicle.cp.shovel.targetFound == nil and distanceToEmptyPoint < 10 then
				allowedToDrive = false;
			elseif distanceToEmptyPoint < 10 then
				vehicle.cp.shovel.targetFound = nil;
				self:setShovelState(vehicle, self.STATE_START_UNLOAD);
			end;
		end
	-- STATE 5: PREPARE UNLOADING
	elseif vehicle.cp.shovelState == self.STATE_START_UNLOAD then
		self.refSpeed = self.vehicle.cp.speeds.turn
		local dischargeNode = vehicle.cp.shovel:getCurrentDischargeNode()
		local x,y,z = localToWorld(dischargeNode.node,0,0,0);
		local lx7,ly7,lz7 = localDirectionToWorld(vehicle.cp.DirectionNode, 0, -1, 0);
		local dischargeTarget = vehicle.cp.shovel:getDischargeTargetObject(dischargeNode)
		if false then
			raycastAll(x, y, z, lx7, ly7, lz7, "findTrailerRaycastCallback", 10, vehicle);
			if courseplay.debugChannels[10] then
				cpDebug:drawLine(x, y, z, 1, 0, 0, x+lx7*10, y+ly7*10, z+lz7*10);
			end;
		end;
		if vehicle.cp.shovel:getCanDischargeToObject(dischargeNode) then
			if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[5], dt) then
				self:setShovelState(vehicle, self.STATE_WAIT_FOR_UNLOADREADY);
			else
				allowedToDrive = false;
			end;
		end;
		

	-- STATE 6: UNLOADING
	elseif vehicle.cp.shovelState == self.STATE_WAIT_FOR_UNLOADREADY then
		self.refSpeed = AIDriver.getSpeed(self)
		--courseplay:handleSpecialTools(vehicle,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
		courseplay:handleSpecialTools(vehicle,vehicle,true,nil,nil,nil,nil,nil)
		local dischargeNode = vehicle.cp.shovel:getCurrentDischargeNode()
		local stopUnloading = not vehicle.cp.shovel:getCanDischargeToObject(dischargeNode)
		if fillLevelPct <= 1 or stopUnloading then
			if courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[4], dt) then
				if vehicle.cp.isLoaded then
					local newWP = self:findNextRevWaypoint(self.ppc:getCurrentWaypointIx())
					--courseplay:setWaypointIndex(vehicle, newWP);
					vehicle.cp.ppc:initialize(newWP);
					self.ppc:update()
					courseplay:setIsLoaded(vehicle, false);
				end;
				if not self.course:isReverseAt(self.ppc:getCurrentWaypointIx()) then
					self:setShovelState(vehicle, self.STATE_GO_BACKTO_START);
				end
			else
				allowedToDrive = false;
			end;
		else
			allowedToDrive = false;
		end;

		if vehicle.cp.mode9TargetSilo and vehicle.cp.mode9TargetSilo.type and vehicle.cp.mode9TargetSilo.type == "heap" then
			vehicle.cp.mode9TargetSilo = nil
		end
		
	-- STATE 7: RETURN FROM BGA TO START POINT
	elseif vehicle.cp.shovelState == self.STATE_GO_BACKTO_START then
		self.refSpeed = AIDriver.getSpeed(self)
		courseplay:handleSpecialTools(vehicle,vehicle,false,nil,nil,nil,nil,nil);
		courseplay:checkAndSetMovingToolsPosition(vehicle, mt, secondary, vehicle.cp.shovelStatePositions[3], dt);
	end;
	
	if allowedToDrive then
		--courseplay:handleSlipping(vehicle, self:getSpeed())
		--Tommi implement it if drivecontrol is out self:setFourWheelDrive(vehicle, true)
	end
	
	self:checkLastWaypoint()
	self.allowedToDrive = allowedToDrive
	AIDriver.driveCourse(self, dt)
		
end

function ShovelModeAIDriver:checkLastWaypoint()
	if self.ppc:reachedLastWaypoint() then
		self.ppc:initialize(1)
		self.vehicle.cp.BunkerSiloMap = nil
		self.vehicle.cp.actualTarget = nil
		self:setShovelState(self.vehicle, self.STATE_GOTO_SILO);
	end
end



function ShovelModeAIDriver:findNextRevWaypoint(currentPoint)
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

function ShovelModeAIDriver:onWaypointPassed(ix)
	-- nothing for now
end


function ShovelModeAIDriver:getSpeed()
	return self.refSpeed
end

function ShovelModeAIDriver:debug(...)
	courseplay.debugVehicle(10, self.vehicle, ...)
end


function ShovelModeAIDriver:setShovelState(vehicle, state, extraText)
	if vehicle.cp.shovelState ~= state then
		vehicle.cp.shovelState = state;
		if courseplay.debugChannels[10] then
			if extraText then
				courseplay:debug(('%s: set shovel state to %d (%s)'):format(nameNum(vehicle), state, extraText), 10);
			else
				courseplay:debug(('%s: set shovel state to %d'):format(nameNum(vehicle), state), 10);
			end;
		end;
	end
end;
