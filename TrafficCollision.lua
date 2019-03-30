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

function CollisionDetector:init(vehicle, course)
	-- channel 12 until the legacy code is spamming channel 3
	self.debugChannel = 3
	self.debugTicks = 100 -- show sparse debug information only at every debugTicks update
	self.vehicle = vehicle
	self:debug('creating CollisionDetector')
	self.course = course
	--if CpManager.isDeveloper then
		self:removeLegacyCollisionTriggers()
	--end
	self.collidingObjects = {}
	self.nCollidingObjects = 0
	self.nPreviousCollidingObjects = 0
	self.ignoredNodes = {}
	self:addToIgnoreList(self.vehicle)
	self.numTrafficCollisionTriggers = 0
	self.requiredNumTriggers = 4
	self.trafficCollisionTriggers = {}
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
	end
end

-- Remove legacy CP collision triggers as they are always created in base.lua. This
-- has the side effect that this vehicle won't have traffic collision detection when
-- not running with the AIDriver (the code in traffic.lua seems to be safely handle
-- the lack of collision triggers)
function CollisionDetector:removeLegacyCollisionTriggers()
	for i=self.vehicle.cp.numTrafficCollisionTriggers,1,-1 do 
		local node = self.vehicle.cp.trafficCollisionTriggers[i]
		if node then
			removeTrigger(node)
			if entityExists(node) then
				unlink(node)
				self.vehicle:removeWashableNode(node)
				self.vehicle:removeWearableNode(node)
				delete(node)
			end
		end
		CpManager.trafficCollisionIgnoreList[node] = nil
		self.vehicle.cp.trafficCollisionTriggers[i] = nil
	end
	self.vehicle.cp.numTrafficCollisionTriggers = 0 -- why not #trafficCollisionTriggers???
end

function CollisionDetector:findAiCollisionTrigger(object)
	local index = object.i3dMappings.aiCollisionTrigger
	if index then
		self:debug('Collision detector initializing.')
		return I3DUtil.indexToObject(object.components, index);
	else
		self:debug('No aiCollisionTrigger node found.')
	end
end

--- Create collision detection triggers: make four copies of the existing collision box and link them together
-- so they form a snake in front of the vehicle along the path. When this snakes collides with something, the
-- the onCollision() callback is triggered by the game engine
function CollisionDetector:createTriggers()
	self.aiTrafficCollisionTrigger = self:findAiCollisionTrigger(self.vehicle)
	if not self.aiTrafficCollisionTrigger then return end
	CpManager.trafficCollisionIgnoreList[self.aiTrafficCollisionTrigger] = true
	self.vehicle.cp.trafficCollisionTriggerToTriggerIndex = {}
	self.vehicle.cp.aiTrafficCollisionTrigger = self.aiTrafficCollisionTrigger
	for i = 1, self.requiredNumTriggers do
		local newTrigger = clone(self.aiTrafficCollisionTrigger, true)
		self.trafficCollisionTriggers[i] = newTrigger
		self.vehicle.cp.trafficCollisionTriggerToTriggerIndex[newTrigger] = i;
		self.numTrafficCollisionTriggers = self.numTrafficCollisionTriggers + 1
		setName(newTrigger, 'cpAiCollisionTrigger ' .. tostring(i))
		if i > 1 then
			unlink(newTrigger)
			link(self.trafficCollisionTriggers[i - 1], newTrigger)
			setTranslation(newTrigger, 0, 0, 4)
		end;
		addTrigger(newTrigger, 'onCollision', self)
		CpManager.trafficCollisionIgnoreList[newTrigger] = true
	end;
end


function CollisionDetector:deleteTriggers()
	for i = #self.trafficCollisionTriggers, 1, -1 do
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
	end

end

--- Add and object to the list of ignored nodes. We must ignore collisions with our own collision boxes,
-- and with our own vehicle/implements and their collision triggers. This one adds object and all the objects
-- attached to it to the ignore list recursively
function CollisionDetector:addToIgnoreList(object)
	self:debug('will ignore collisions with %q (%q)', nameNum(object), tostring(object.cp.xmlFileName))
	self.ignoredNodes[object.rootNode] = true;
	-- add the vehicle or implement's own collision trigger to the ignore list
	local aiCollisionTrigger = self:findAiCollisionTrigger(object)
	if aiCollisionTrigger then
		self:debug('-- %q', getName(aiCollisionTrigger))
		self.ignoredNodes[aiCollisionTrigger] = true
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

--- make sure we have latest status (mainly refresh the ignore list with implement changes)
function CollisionDetector:refresh()
	self:debug('refreshing ignore list')
	self.ignoredNodes = {}
	self:addToIgnoreList(self.vehicle)
	-- trigger justGotInTraffic in case we start up in the traffic
	self.nPreviousCollidingObjects = 0
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
				if collidingVehicle.lastSpeedReal == nil or collidingVehicle.lastSpeedReal*3600 == 0 or not self:doesVehicleGoMyDirection(collidingVehicleId) then
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
	local x, y, z = getWorldTranslation(self.vehicle.cp.DirectionNode);
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
						distance = courseplay:nodeToNodeDistance(self.vehicle.cp.DirectionNode or self.vehicle.rootNode, targetId)
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
	--print("findTheValidCollisionVehicle: return:"..tostring(currentCollisionVehicleId))
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
	-- if bit21 is part of the collisionMask then set new vehicle in GCM.NTV
	if collisionVehicle == nil and bitAND(cm, 2097152) ~= 0 and not string.match(getName(nodeId),'Trigger') and not string.match(getName(nodeId),'trigger') then
		local pathVehicle = {
			rootNode = nodeId,
			isCpPathVehicle = true,
			name = "PathVehicle",
			sizeLength = 7,
			sizeWidth = 3,
				}
		g_currentMission.nodeToObject[nodeId] = pathVehicle
	end
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
		self:setCollisionDirection(self.vehicle.cp.DirectionNode, self.trafficCollisionTriggers[1], colDirX, colDirZ)
		local recordNumber = ix
		if self.vehicle.cp.collidingVehicleId == nil then
			for i = 2, #self.trafficCollisionTriggers do
				if disableLongCheck or recordNumber + i >= course:getNumberOfWaypoints() or recordNumber < 2 then
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
	if self.numTrafficCollisionTriggers > 0 then
		local height = 0;
		local step = (vehicle.sizeLength/2)+1 ;
		local stepBehind, stepFront = step, step;
		if vehicle.getAttachedImplements ~= nil then
			for index, implement in pairs(vehicle:getAttachedImplements()) do
				local tool = implement.object
				local x,y,z = getWorldTranslation(tool.rootNode);
			    local _,_,nz =  worldToLocal(vehicle.cp.DirectionNode, x, y, z);
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