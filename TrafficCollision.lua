--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vajko

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

---@class CollisionDetector
CollisionDetector = CpObject()

CollisionDetector.numTrafficCollisionTriggers = 4
CollisionDetector.debugChannel = 3

function CollisionDetector:init(vehicle, course)
	self.debugTicks = 100 -- show sparse debug information only at every debugTicks update
	self.vehicle = vehicle
	self:debug('CollisionDetector:init()')
	self.course = course

	self.collidingObjects = {}
	self.nCollidingObjects = 0
	self.ignoredNodes = {}
	self:addToIgnoreList(self.vehicle)
	self.trafficCollisionTriggers = {}
	self.trafficCollisionTriggers[1] = nil
	self:createTriggers()
	self:adaptCollisHeight()
end

-- destructor
function CollisionDetector:delete()
	self:debug('deleting CollisionDetector')
	-- work from the back of the list as these are linked together and deleting the
	-- first one removes all and then there's a warning about deleting object before
	-- removing the trigger
	if self.trafficCollisionTriggers then
		self:deleteTriggers()
		self.trafficCollisionTriggers = nil
		self.collidingObjects = {}				-- clear all detected collisions
		self.nCollidingObjects = 0				-- clear all detected collisions
		self.ignoredNodes = {}					-- clear all detected collisions
	end
end

function CollisionDetector:reset()
	self:debug('reset CollisionDetector triggers')
	if self.trafficCollisionTriggers then
		self:delete()
	end
	self:createTriggers()
end

--- Create collision detection triggers: make four copies of the existing collision box and link them together
-- so they form a snake in front of the vehicle along the path. When this snakes collides with something, the
-- the onCollision() callback is triggered by the game engine
function CollisionDetector:createTriggers()

	if not courseplay:findAiCollisionTrigger(self.vehicle) then return end	-- create triggers only for enterable vehicles

	if not self.trafficCollisionTriggers then
		self.trafficCollisionTriggers = {}
	end
	if self.trafficCollisionTriggers[1] == nil then
		for i = 1, self.numTrafficCollisionTriggers do
			local newTrigger = clone(self.vehicle.aiTrafficCollisionTrigger, true)
			self.trafficCollisionTriggers[i] = newTrigger
			setName(newTrigger, 'cpAiCollisionTrigger ' .. tostring(i))
			if i > 1 then
				unlink(newTrigger)
				link(self.trafficCollisionTriggers[i - 1], newTrigger)
				setTranslation(newTrigger, 0, 0, 4)
			end;
			addTrigger(newTrigger, 'onCollision', self)
		end;
	end
end


function CollisionDetector:deleteTriggers()
	for i = self.numTrafficCollisionTriggers, 1, -1 do
		local node = self.trafficCollisionTriggers[i]
		if node then
			removeTrigger(node)
			if entityExists(node) then
				unlink(node)
				self.vehicle:removeWashableNode(node)
				self.vehicle:removeWearableNode(node)
				delete(node)
			end
		end
		self.trafficCollisionTriggers[i] = nil
	end

end

--- Add and object to the list of ignored nodes. We must ignore collisions with our own collision boxes,
-- and with our own vehicle/implements and their collision triggers. This one adds object and all the objects
-- attached to it to the ignore list recursively
function CollisionDetector:addToIgnoreList(object)
	self:debug('will ignore collisions with %q (%q)', nameNum(object), tostring(object.cp.xmlFileName))
	self.ignoredNodes[object.rootNode] = true;
	-- add the vehicle or implement's own collision trigger to the ignore list
	courseplay:findAiCollisionTrigger(object)		-- get aiTrafficCollisionTrigger for vehicles
	if object.aiTrafficCollisionTrigger then
		self:debug('-- %q', getName(object.aiTrafficCollisionTrigger))
		self.ignoredNodes[object.aiTrafficCollisionTrigger] = true
	end
	if object.components then
		self:debug('will ignore collisions with %q (%q) components', nameNum(object), tostring(object.cp.xmlFileName))
		for _, component in pairs(object.components) do
			self:debug('-- %q', getName(component.node))
			self.ignoredNodes[component.node] = true;
		end
	end
	-- add all attached implements recursively
	for _, impl in pairs(object:getAttachedImplements()) do
		self:addToIgnoreList(impl.object)
	end
end

function CollisionDetector:isIgnored(node)
	local parent = getParent(node)
	if self.ignoredNodes[node] or CpManager.trafficCollisionIgnoreList[node] or
		self.ignoredNodes[parent] or CpManager.trafficCollisionIgnoreList[parent] then
		return true
	end
end

function CollisionDetector:onCollision(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if not self:isIgnored(otherId) then
		if onEnter then
			if not self.collidingObjects[otherId] then
				self.collidingObjects[otherId] = otherId
				self.nCollidingObjects = self.nCollidingObjects + 1
				self:debug('collision trigger %s entered: %s, %d colliding objects.', getName(triggerId), getName(otherId), self.nCollidingObjects)
			end
		end
	end
	if onLeave and self.collidingObjects[otherId] then
		self.nCollidingObjects = self.nCollidingObjects - 1
		self:debug('collision trigger %s left: %s, %d colliding objects.', getName(triggerId), getName(otherId), self.nCollidingObjects)
		self.collidingObjects[otherId] = nil
	end
end

function CollisionDetector:getStatus(dt)
	local isInTraffic = false
	local trafficSpeed = 0
	if self.nCollidingObjects > 0 then
		local collidingVehicleId = self:findTheValidCollisionVehicle()
		if collidingVehicleId ~= nil then
			local collidingVehicle = g_currentMission.nodeToObject[collidingVehicleId]
			if collidingVehicle ~= nil then
				if collidingVehicle.isCpPathVehicle then
					self:setPathVehiclesSpeed(collidingVehicle, dt)
				end
				if collidingVehicle.lastSpeedReal == nil or collidingVehicle.lastSpeedReal*3600 < 0.01 then		-- collidingVehicle not moving -> STOP
					isInTraffic = true
				else	
					trafficSpeed = collidingVehicle.lastSpeedReal*3600
				end
			end
		end
	end	
	
	return isInTraffic, trafficSpeed
end

function CollisionDetector:doesVehicleGoMyDirection(collidingVehicleId)
	local x, y, z = getWorldTranslation(self.vehicle.cp.directionNode);
	local x1,z1 = AIVehicleUtil.getDriveDirection(collidingVehicleId, x, y, z);
	if z1 > -0.9 then 
		-- I'm in front of vehicle, face2face or beside < 4 o'clock
		return false;
	end;
	return true;
end

function CollisionDetector:findTheValidCollisionVehicle()
--go throught the objects to figure out the valid target
	local currentCollisionVehicleId = 0
	local distanceToCollisionVehicle = math.huge
	local distance = math.huge
	--toggle through my collisionTriggerHits
	for targetId,_ in pairs (self.collidingObjects) do
		--does it still exist? (straw bales)
		if entityExists(targetId) then
			--get the vehicle concerned
			local collisionVehicle = g_currentMission.nodeToObject[targetId]
			--print(string.format("collisionVehicle[%s](%s): %s",tostring(targetId),tostring(getName(targetId)),tostring(collisionVehicle)))
			if collisionVehicle ~= nil then
				--if the collisionVehicle is valid, check whether it's the closest
				if self:isItARailCrossing(collisionVehicle) then
					local _,transY,_ = getTranslation(targetId);
					if transY > 0 then
						distance = courseplay:nodeToNodeDistance(self.vehicle.cp.directionNode or self.vehicle.rootNode, targetId)
					end
				else
					distance = courseplay:distanceToObject(self.vehicle, collisionVehicle)
				end
				if distanceToCollisionVehicle > distance then
					--print(string.format("   %d is closer (%.2f m)",targetId,distance));
					distanceToCollisionVehicle = distance
					currentCollisionVehicleId = targetId;
				end

			else
				self:isItATrafficVehicle(targetId)
			end
		else
			--delete NodeID e.g. StrawBales will be deleted and don't get onLeave
		end
	end 
	return currentCollisionVehicleId
end

--check whether we hit the trafficBlokker of an railway crossing
function CollisionDetector:isItARailCrossing(collisionVehicle)
	if collisionVehicle.railroadObjects then
		return true;
	end
end

-- check, whether its a traffic vehicle.
-- if yes ,set it to g_cM.nodeToObject
function CollisionDetector:isItATrafficVehicle(nodeId)
	local cm = getCollisionMask(nodeId);
	local currentCollisionVehicleId
	-- if bit21 is part of the collisionMask then set new vehicle in GCM.NTV
	-- if nodeId == nil and bitAND(cm, 2097152) ~= 0 and not string.match(getName(nodeId),'Trigger') and not string.match(getName(nodeId),'trigger') then
	if currentCollisionVehicleId == nil and bitAND(cm, 2097152) ~= 0 and not string.match(getName(nodeId),'Trigger') and not string.match(getName(nodeId),'trigger') then
		local pathVehicle = {
			rootNode = nodeId,
			isCpPathVehicle = true,
			name = "PathVehicle",
			sizeLength = 7,
			sizeWidth = 3,
				}
		g_currentMission.nodeToObject[nodeId] = pathVehicle
		-- currentCollisionVehicleId = nodeId;
	end
	return currentCollisionVehicleId
end


--- Update the collision detection boxes. This bends the snake according to the next waypoints in the path so
-- we can detect objects along the path.
---@param course Course
-- @param lx, lz vehicle-local coordinates of the goal point the vehicle is driving to
function CollisionDetector:update(course, ix, lx, lz, disableLongCheck)
	local colDirX = lx
	local colDirZ = lz

	self:debugSparse('has %d colliding object(s)', self.nCollidingObjects)

	if self.trafficCollisionTriggers[1] ~= nil then
		self:setCollisionDirection(self.vehicle.cp.directionNode, self.trafficCollisionTriggers[1], colDirX, colDirZ)
		local recordNumber = ix
		for i = 2, self.numTrafficCollisionTriggers do
			-- if disableLongCheck or recordNumber + i >= course:getNumberOfWaypoints() or recordNumber < 2 then
			if disableLongCheck or recordNumber + i >= course:getNumberOfWaypoints() then		-- enable the snake on the way to the start point of a course
				self:setCollisionDirection(self.trafficCollisionTriggers[i-1], self.trafficCollisionTriggers[i], 0, -1)
			else
				local nodeX, nodeY, nodeZ = getWorldTranslation(self.trafficCollisionTriggers[i])
				local x, y, z = course:getWaypointPosition(recordNumber)
				local nodeDirX, nodeDirY, nodeDirZ, distance = courseplay:getWorldDirection(nodeX,nodeY,nodeZ, x, y, z)
				local _,_,Z = worldToLocal(self.trafficCollisionTriggers[i], x, y, z)
				local index = 1
				local oldValue = Z
				while Z < 5.5 do
					recordNumber = recordNumber + index
					if recordNumber > course:getNumberOfWaypoints() then -- just a backup
						break
					end
					x, y, z = course:getWaypointPosition(recordNumber)
					nodeDirX, nodeDirY, nodeDirZ, distance = courseplay:getWorldDirection(nodeX, nodeY, nodeZ, x, y, z)
					_,_,Z = worldToLocal(self.trafficCollisionTriggers[i], x, y, z)
					if oldValue > Z then
						self:setCollisionDirection(self.trafficCollisionTriggers[1], self.trafficCollisionTriggers[i], 0, 1)
						break
					end
					index = index + 1
					oldValue = Z
				end
				nodeDirX, nodeDirY, nodeDirZ = worldDirectionToLocal(self.trafficCollisionTriggers[i - 1], nodeDirX, nodeDirY, nodeDirZ)
				self:setCollisionDirection(self.trafficCollisionTriggers[i - 1], self.trafficCollisionTriggers[i], nodeDirX, nodeDirZ)
			end
		end
	end
end

function CollisionDetector:setCollisionDirection(node, col, colDirX, colDirZ)
	local parent = getParent(col)
	local colDirY = 0
	if parent ~= node then
		colDirX, colDirY, colDirZ = worldDirectionToLocal(parent, localDirectionToWorld(node, colDirX, 0, colDirZ))
	end
	if not ( math.abs( colDirX ) < 0.001 and math.abs( colDirZ ) < 0.001 ) then
		setDirection(col, colDirX, colDirY, colDirZ, 0, 1, 0)
	end
end

function CollisionDetector:debug(...)
	courseplay.debugVehicle(self.debugChannel, self.vehicle, ...)
end

function CollisionDetector:debugSparse(...)
	if g_updateLoopIndex % self.debugTicks == 0 then
		courseplay.debugVehicle(self.debugChannel, self.vehicle, ...)
	end
end

function CollisionDetector:setPathVehiclesSpeed(pathVehicle,dt)
	--print("update speed")
	if pathVehicle.speedDisplayDt == nil then
		pathVehicle.speedDisplayDt = 0;
		pathVehicle.lastSpeed = 0;
		pathVehicle.lastSpeedReal = 0;
		pathVehicle.movingDirection = 1;
	end;
	pathVehicle.speedDisplayDt = pathVehicle.speedDisplayDt + dt;
	if pathVehicle.speedDisplayDt > 100 then
		local newX, newY, newZ = getWorldTranslation(pathVehicle.rootNode);
		if pathVehicle.lastPosition == nil then
		  pathVehicle.lastPosition = {
			newX,
			newY,
			newZ
		  };
		end;
		local lastMovingDirection = pathVehicle.movingDirection;
		local dx, dy, dz = worldDirectionToLocal(pathVehicle.rootNode, newX - pathVehicle.lastPosition[1], newY - pathVehicle.lastPosition[2], newZ - pathVehicle.lastPosition[3]);
		if dz > 0.001 then
		  pathVehicle.movingDirection = 1;
		elseif dz < -0.001 then
		  pathVehicle.movingDirection = -1;
		else
		  pathVehicle.movingDirection = 0;
		end;
		pathVehicle.lastMovedDistance = MathUtil.vector3Length(dx, dy, dz);
		local lastLastSpeedReal = pathVehicle.lastSpeedReal;
		pathVehicle.lastSpeedReal = pathVehicle.lastMovedDistance * 0.01;
		pathVehicle.lastSpeedAcceleration = (pathVehicle.lastSpeedReal * pathVehicle.movingDirection - lastLastSpeedReal * lastMovingDirection) * 0.01;
		pathVehicle.lastSpeed = pathVehicle.lastSpeed * 0.85 + pathVehicle.lastSpeedReal * 0.15;
		pathVehicle.lastPosition[1], pathVehicle.lastPosition[2], pathVehicle.lastPosition[3] = newX, newY, newZ;
		pathVehicle.speedDisplayDt = pathVehicle.speedDisplayDt - 100;
	end;
end


-- adapt collis height to vehicles height
function CollisionDetector:adaptCollisHeight()
	local vehicle = self.vehicle
	if self.trafficCollisionTriggers[1] ~= nil then	
		local height = 0;
		local step = (vehicle.sizeLength/2)+1 ;
		local stepBehind, stepFront = step, step;
		if vehicle.getAttachedImplements ~= nil then
			for index, implement in pairs(vehicle:getAttachedImplements()) do
				local tool = implement.object
				local x,y,z = getWorldTranslation(tool.rootNode);
			    local _,_,nz =  worldToLocal(vehicle.cp.directionNode, x, y, z);
				if nz > 0 then
					stepFront = stepFront + (tool.sizeLength)+2				
				else
					stepBehind = stepBehind + (tool.sizeLength)+2	
				end
			end
		end
		
		local distance = math.max(vehicle.sizeLength,5)
		local nx, ny, nz = localDirectionToWorld(vehicle.rootNode, 0, -1, 0);	
		vehicle.cp.HeightsFound = 0;
		vehicle.cp.HeightsFoundColli = 0;			
		for i=-stepBehind,stepFront,0.5 do				
			local x,y,z = localToWorld(vehicle.rootNode, 0, distance, i);
			raycastAll(x, y, z, nx, ny, nz, "findVehicleHeights", distance, vehicle);
			--print("drive raycast "..tostring(i).." end");
			--cpDebug:drawLine(x, y, z, 1, 0, 0, x+(nx*distance), y+(ny*distance), z+(nz*distance));
		end
		local difference = vehicle.cp.HeightsFound - vehicle.cp.HeightsFoundColli;
		local trigger = self.trafficCollisionTriggers[1];
		local Tx,Ty,Tz = getTranslation(trigger,vehicle.rootNode);
		setTranslation(trigger, Tx,Ty+difference,Tz);
	end
end

---@class TrafficConflictDetector : CollisionDetector
TrafficConflictDetector = CpObject(CollisionDetector)
TrafficConflictDetector.debugChannel = 3
TrafficConflictDetector.boxDistance = 4
TrafficConflictDetector.numTrafficCollisionTriggers = 20
TrafficConflictDetector.timeScale = 2
TrafficConflictDetector.speedAverageCycles = 20
-- if a conflict is closer than this, hold
TrafficConflictDetector.holdDistance = 15
-- if a conflict is closer than this, slow down
TrafficConflictDetector.slowDownDistance = 30
TrafficConflictDetector.updatePeriodMs = 1000

--- @param vehicle table
--- @param course Course
--- @param collisionTriggerObject table object to use to find a collision trigger, by default the vehicle
function TrafficConflictDetector:init(vehicle, course, collisionTriggerObject)
	---@type Conflict[]
	self.conflicts = {}
	self.baseHeight = 6
    self.lastUpdatedTime = 0
	self.collisionTriggerObject = collisionTriggerObject or vehicle
	CollisionDetector.init(self, vehicle, course)
	self:debug('TrafficConflictDetector:init()')
	self.speedControlEnabled = true
	self.ignoreVehicleForSpeedControl = nil
end

-- This currently does not do anything in TrafficConflictDetector, just provides a container
-- for this property
function TrafficConflictDetector:isSpeedControlEnabled()
	return self.speedControlEnabled
end

function TrafficConflictDetector:enableSpeedControl()
	self.speedControlEnabled = true
	self.ignoreVehicleForSpeedControl = nil
	self:debug('Traffic conflict speed control enabled')
end

function TrafficConflictDetector:disableSpeedControl()
	self.speedControlEnabled = false
end

-- we'll not tell anyone to hold, slow down or recalculate for this vehicle until
-- enableSpeedControl() is called or the conflict with this vehicle is cleared.
-- this is to ignore a conflicting vehicle which caused a recalculation until we actually drive around
-- it, at which point the conflict is resolved.
function TrafficConflictDetector:disableSpeedControlForVehicle(vehicle)
	self:debug('Traffic conflict speed control disabled for %s', nameNum(vehicle))
	self.ignoreVehicleForSpeedControl = vehicle
end

function TrafficConflictDetector:createTriggers()
	if not courseplay:findAiCollisionTrigger(self.collisionTriggerObject) then return end

	if not self.trafficCollisionTriggers then
		self.trafficCollisionTriggers = {}
	end
	for i = 1, self.numTrafficCollisionTriggers do
		local newTrigger = clone(self.collisionTriggerObject.aiTrafficCollisionTrigger, false)
		link(g_currentMission.terrainRootNode, newTrigger)
		self.trafficCollisionTriggers[i] = newTrigger
		setName(newTrigger, nameNum(self.vehicle) .. ' trigger #' .. tostring(i))
		local x, y, z = getWorldTranslation(self.vehicle.rootNode)
		local _, yRot, _ = getWorldRotation(self.vehicle.rootNode)
		setTranslation(newTrigger, x, i + y + self.baseHeight, z)
		setRotation(newTrigger, 0, yRot, 0)
		setUserAttribute(newTrigger, 'vehicleRootNode', 'Integer', self.vehicle.rootNode)
		setUserAttribute(newTrigger, 'trafficConflictDetector', 'Boolean', true)
		addTrigger(newTrigger, 'onCollision', self)
	end
end

function TrafficConflictDetector:adaptCollisHeight()
	return
end


--- Update the position of each collision trigger box.
---
--- For the expected course of the vehicle calculate the expected position at every
--- TrafficConflictDetector.boxDistance meters.
---
--- If the vehicle is driving on a course, these will be positions on the course, otherwise on an estimated
--- straight line in the direction the vehicle is currently driving.
---
--- Now place a collision box on each position but at different heights: instead of a snake on the ground (like
--- with the CollisionDetector) this is going to be a stairway to heaven :).
---
--- The altitude of each box above ground is proportional (TrafficConflictDetector.timeScale * seconds) to the
--- estimated time of arrival (ETA) of the vehicle to that x/z position.
---
--- This way a conflict will only be triggered (by a collision with another vehicle's TrafficConflictDetector
--- boxes) when the vehicles are forecast to be a the same position at the same time.
---
---@param course Course course the vehicle is driving on, may be nil, if a directionNode is given
---@param ix number current waypoint on the course
---@param nominalSpeed number speed to use to calculate ETA if there is no course or course has no speed info
--- The next two parameters are needed only when the vehicle isn't driving on a course
---@param moveForwards boolean true if vehicle is moving forwards
---@param directionNode number direction node of the vehicle
function TrafficConflictDetector:updateCollisionBoxes(course, ix, nominalSpeed, moveForwards, directionNode)

    if g_time - self.lastUpdatedTime < TrafficConflictDetector.updatePeriodMs then return end

	self.lastUpdatedTime = g_time

	local positions
	if course then
		positions = course:getPositionsOnCourse(nominalSpeed, ix,
				TrafficConflictDetector.boxDistance, TrafficConflictDetector.numTrafficCollisionTriggers)
		self:debug('updating collision boxes at waypoint %d, have %d positions', ix, #positions)
	else
		positions = self:getPositionsAtDirection(nominalSpeed, moveForwards, directionNode)
		self:debug('updating collision boxes (no course), have %d positions', #positions)
	end
	local posIx = 1
	local eta = 0
	if #positions > 0 then
		for i, trigger in ipairs(self.trafficCollisionTriggers) do
			local d = (i - 1) * TrafficConflictDetector.boxDistance
			local speed = positions[posIx].speed or nominalSpeed
			local metersPerSec = speed / 3.6
			eta = d / (metersPerSec > 0 and metersPerSec or 0.001)
			-- don't stack them more than baseHeight meters apart as that's how high these boxes usually are
			-- and this way there's no gap between them
			setTranslation(trigger,
					positions[posIx].x,
					positions[posIx].y + math.min(self.baseHeight * i, eta * TrafficConflictDetector.timeScale),
					positions[posIx].z)
			setRotation(trigger, 0, positions[posIx].yRot, 0)
			--DebugUtil.drawDebugNode(trigger, string.format('%.1f\n%.1f s', metersPerSec * 3.6, eta))
			setUserAttribute(trigger, 'distance', 'Integer', d)
			setUserAttribute(trigger, 'eta', 'Integer', eta)
			setUserAttribute(trigger, 'yRot', 'Float', positions[posIx].yRot)
			if posIx < #positions then
				-- if we have less positions than triggers, just use the last position for the rest of the triggers
				posIx = posIx + 1
			end
		end
	end
end

--- Get estimated positions of the vehicle (in case there is no course, for example when the AI is driving
--- the turn using steering angles only.
---@return table list of positions every TrafficConflictDetector.boxDistance meters as if the vehicle was driving
--- in the current direction at the given speed
function TrafficConflictDetector:getPositionsAtDirection(speed, moveForwards, directionNode)
	local direction = moveForwards and 1 or -1
	local x, y, z = localDirectionToWorld(directionNode, 0, 0, direction)
	local yRot = MathUtil.getYRotationFromDirection(x, z)
	local positions = {}
	-- this is for short temporary courses driven without a generated course so don't create a position for all triggers
	-- as the vehicle will most likely turn
	local dz = 0
	local step = math.min(speed / 3.6, TrafficConflictDetector.boxDistance)
	for i = 0, TrafficConflictDetector.numTrafficCollisionTriggers do
		dz = dz + step
		x, y, z = localToWorld(directionNode, 0, 0, direction * dz)
		y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
		table.insert(positions, {x = x,
								 y = y,
								 z = z,
								 yRot =yRot,
								 speed = speed})

	end
	return positions
end

function TrafficConflictDetector:isIgnored(otherId)
	for i = 1, self.numTrafficCollisionTriggers do
		if otherId == self.trafficCollisionTriggers[i] then
			return true
		end
	end
end

function TrafficConflictDetector:onCollision(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	-- is this even a traffic conflict detector trigger?
	if not getUserAttribute(triggerId, 'trafficConflictDetector') then return end
	local otherVehicleRootNode = getUserAttribute(otherId, 'vehicleRootNode')
	if otherVehicleRootNode and otherVehicleRootNode ~= self.vehicle.rootNode then
		local otherYRot = getUserAttribute(otherId, 'yRot')
		local myYRot = getUserAttribute(triggerId, 'yRot')
		local yRotDiff = otherYRot and myYRot and MathUtil.getAngleDifference(myYRot, otherYRot)
		local otherVehicle = g_currentMission.nodeToObject[otherVehicleRootNode]
		if onEnter then
			self:debug('onCollision: onEnter with %s (%s with %s)', nameNum(otherVehicle), getName(triggerId), getName(otherId))
			-- call every time, even if we already have a conflict with this vehicle to update d and ETA
			self:onConflictDetected(otherVehicle, triggerId,
					getUserAttribute(triggerId, 'distance'), getUserAttribute(triggerId, 'eta'),
					getUserAttribute(otherId, 'distance'), getUserAttribute(otherId, 'eta'), yRotDiff)
		end
		if onLeave then
			self:debug('onCollision: onLeave with %s (%s with %s)', nameNum(otherVehicle), getName(triggerId), getName(otherId))
			self:onConflictCleared(otherVehicle, triggerId)
		end
	elseif not otherVehicleRootNode then
		--self:debug('onCollision: %s with %s', self.vehicle:getName(), getName(otherId))
	end
end

function TrafficConflictDetector:onConflictDetected(otherVehicle, triggerId, d, eta, otherD, otherEta, yRotDiff)
	for _, conflict in ipairs(self.conflicts) do
		if conflict:isWith(otherVehicle) then
			conflict:onDetected(triggerId, d, eta, otherD, otherEta, yRotDiff)
			return
		end
	end
	-- first conflict for this vehicle pair
	table.insert(self.conflicts, Conflict(self.vehicle, otherVehicle, triggerId, d, eta, otherD, otherEta, yRotDiff))
	self:debug('Conflict added: %s', self.conflicts[#self.conflicts])
end

function TrafficConflictDetector:onConflictCleared(otherVehicle, triggerId)
	for _, conflict in ipairs(self.conflicts) do
		if conflict:isWith(otherVehicle) then
			conflict:onCleared(triggerId)
			return
		end
	end
end

function TrafficConflictDetector:updateConflicts()
	local closestConflictDistance = math.huge
	---@type Conflict
	local closestConflict
	-- iterate backwards as we'll remove table elements
	for i = #self.conflicts, 1, -1 do
		---@type Conflict
		local conflict = self.conflicts[i]
		conflict:update()
		if conflict:isCleared() then
			self:debug('Conflict cleared: %s', self.conflicts[i])
			if self.ignoreVehicleForSpeedControl == conflict:getConflictingVehicle() then
				self.ignoreVehicleForSpeedControl = nil
			end
			table.remove(self.conflicts, i)
		else
			if conflict:getDistance() < closestConflictDistance then
				closestConflict = conflict
			end
		end
	end
	if self.closestConflict ~= closestConflict then
		self.closestConflict = closestConflict
		if self.closestConflict then
			self.closestConflict:evaluateRightOfWay()
		end
	end
end

function TrafficConflictDetector:update(course, ix, nominalSpeed, moveForwards, directionNode)
	self:updateCollisionBoxes(course, ix, nominalSpeed, moveForwards, directionNode)
	self:updateConflicts()
end

function TrafficConflictDetector:getClosestConflictDistance()
	if self.closestConflict then
		return self.closestConflict:getDistance()
	else
		return math.huge
	end
end

function TrafficConflictDetector:getClosestConflictingVehicle()
	if self.closestConflict then
		return self.closestConflict:getConflictingVehicle()
	else
		return nil
	end
end


--- Notification from another vehicle in conflict with us that it has evaluated the conflict. This is to
--- make sure both vehicles in a conflict agree on a resolution
function TrafficConflictDetector:onRightOfWayEvaluated(otherVehicle, mustYield, headOn)
	for _, conflict in ipairs(self.conflicts) do
		if conflict:isWith(otherVehicle) then
			conflict:onRightOfWayEvaluated(mustYield, headOn)
			return
		end
	end
end

function TrafficConflictDetector:shouldHold()
	for _, conflict in ipairs(self.conflicts) do
		if self.ignoreVehicleForSpeedControl ~= conflict:getConflictingVehicle() then
			-- if close enough and I must yield but it is not a head on (as that is being take care by the proximity sensors)
			if conflict.mustYield and not conflict.headOn and conflict:getDistance() < TrafficConflictDetector.holdDistance then
				return true
			end
		end
	end
	return false
end

function TrafficConflictDetector:shouldSlowDown()
	for _, conflict in ipairs(self.conflicts) do
		if self.ignoreVehicleForSpeedControl ~= conflict:getConflictingVehicle() then
			-- if close enough and I must yield
			if (conflict.mustYield or conflict.headOn) and conflict:getDistance() < TrafficConflictDetector.slowDownDistance then
				return true
			end
		end
	end
	return false
end

-- TODO: a lambda would be nicer for these two
function TrafficConflictDetector:haveHeadOnConflictWith(vehicle)
	for _, conflict in ipairs(self.conflicts) do
		if vehicle == conflict:getConflictingVehicle() and conflict.headOn then
			return true
		end
	end
	return false
end

function TrafficConflictDetector:haveConflictWith(vehicle)
	for _, conflict in ipairs(self.conflicts) do
		if vehicle == conflict:getConflictingVehicle() then
			return true
		end
	end
	return false
end


function TrafficConflictDetector:delete()
	self:removeAllConflicts()
	CollisionDetector.delete(self)
end

function TrafficConflictDetector:removeAllConflicts()
	self:debug('Removing all traffic conflicts')
	for _, conflict in ipairs(self.conflicts) do
		local conflictingVehicle = conflict:getConflictingVehicle()
		if conflictingVehicle.cp.driver then
			conflictingVehicle.cp.driver:removeAllConflictsForVehicle(self.vehicle)
		end
	end
	self.conflicts = {}
end

function TrafficConflictDetector:removeAllConflictsForVehicle(vehicle)
	self:debug('Removing all traffic conflicts for %s', nameNum(vehicle))
	for i = #self.conflicts, 1, -1 do
		---@type Conflict
		local conflict = self.conflicts[i]
		if conflict:isVehicleInvolved(vehicle) then
			table.remove(self.conflicts, i)
		end
	end
end

function TrafficConflictDetector:drawDebugInfo(y)
	if not courseplay.debugChannels[self.debugChannel] then return end
	local x, size = 0.1, 0.012

	for i, conflict in ipairs(self.conflicts) do
		renderText(x, y, size, string.format('%d %s', i, conflict))
		y = y - size * 1.1
	end
	return y
end

function TrafficConflictDetector.drawAllDebugInfo()
	if not courseplay.debugChannels[TrafficConflictDetector.debugChannel] then return end
	local y = 0.1
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if vehicle.cp and vehicle.cp.driver and vehicle.cp.driver.trafficConflictDetector then
			y = vehicle.cp.driver.trafficConflictDetector:drawDebugInfo(y)
		end
	end
end