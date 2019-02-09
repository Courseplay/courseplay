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
	self.vehicle = vehicle
	self.course = course
	if CpManager.isDeveloper then
		self:removeLegacyCollisionTriggers()
	end
	self.numTrafficCollisionTriggers = 4
	self.trafficCollisionTriggers = {}
	self:createTriggers()
	self.ignoredNodes = {}
	self:addToIgnoreList(self.vehicle)
	self.collidingObjects = {}
	self.nCollidingObjects = 0
	self.nPreviousCollidingObjects = 0
end

-- destructor
function CollisionDetector:destroy()
	-- work from the back of the list as these are linked together and deleting the
	-- first one removes all and then there's a warning about deleting object before
	-- removing the trigger
	if self.trafficCollisionTriggers then
		for i = #self.trafficCollisionTriggers, 1, -1 do
			local node = self.trafficCollisionTriggers[i]
			if node then
				removeTrigger(node)
				if entityExists(node) then
					unlink(node)
					delete(node)
				end
			end
		end
		self.trafficCollisionTriggers = nil
	end
end

-- Remove legacy CP collision triggers as they are always created in base.lua. This
-- has the side effect that this vehicle won't have traffic collision detection when
-- not running with the AIDriver (the code in traffic.lua seems to be safely handle
-- the lack of collision triggers)
function CollisionDetector:removeLegacyCollisionTriggers()
	for i, node in ipairs(self.vehicle.cp.trafficCollisionTriggers) do
		if node then
			removeTrigger(node)
			if entityExists(node) then
				unlink(node)
				delete(node)
			end
		end
		CpManager.trafficCollisionIgnoreList[node] = nil
		self.vehicle.cp.trafficCollisionTriggers[i] = nil
		self.vehicle.cp.numTrafficCollisionTriggers = 0 -- why not #trafficCollisionTriggers???
	end
end

function CollisionDetector:findAiCollisionTrigger()
	local index = self.vehicle.i3dMappings.aiCollisionTrigger
	if index then
		self:debug('Collision detector initializing.')
		return I3DUtil.indexToObject(self.vehicle.components, index);
	else
		self:debug('No aiCollisionTrigger node found.')
	end
end

--- Create collision detection triggers: make four copies of the existing collision box and link them together
-- so they form a snake in front of the vehicle along the path. When this snakes collides with something, the
-- the onCollision() callback is triggered by the game engine
function CollisionDetector:createTriggers()
	self.aiTrafficCollisionTrigger = self:findAiCollisionTrigger()
	if not self.aiTrafficCollisionTrigger then return end
	CpManager.trafficCollisionIgnoreList[self.aiTrafficCollisionTrigger] = true
	for i = 1, self.numTrafficCollisionTriggers do
		local newTrigger = clone(self.aiTrafficCollisionTrigger, true)
		self.trafficCollisionTriggers[i] = newTrigger
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

--- Add and object to the list of ignored nodes. We must ignore collisions with our own collision boxes,
-- and with our own vehicle/implements. This one adds object and all the objects attached to it to the ignore list
-- recursively
function CollisionDetector:addToIgnoreList(object)
	self:debug('will ignore collisions with %q (%q)', nameNum(object), tostring(object.cp.xmlFileName))
	self.ignoredNodes[object.rootNode] = true;
	if object.components then
		self:debug('will ignore collisions with %q (%q) components', nameNum(object), tostring(object.cp.xmlFileName))
		for _, component in pairs(object.components) do
			self.ignoredNodes[component.node] = true;
		end;
	end;
	-- add all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:addToIgnoreList(impl.object)
	end
end

function CollisionDetector:isIgnored(node)
	local parent = getParent(node)
	if self.ignoredNodes[node] or CpManager.trafficCollisionIgnoreList[node] or
		self.ignoredNodes[parent] or CpManager.trafficCollisionIgnoreList[parent]then
		return true
	end
end

function CollisionDetector:onCollision(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	-- to detect the situation when we clear the traffic
	self.nPreviousCollidingObjects = self.nCollidingObjects
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

function CollisionDetector:justGotInTraffic()
	local justGotInTraffic = self.nPreviousCollidingObjects and self.nPreviousCollidingObjects == 0 and self.nCollidingObjects > 0
	if justGotInTraffic then self.nPreviousCollidingObjects = self.nCollidingObjects end
	return justGotInTraffic
end

function CollisionDetector:isInTraffic()
	return self.nCollidingObjects > 0
end

--- Did we just cleared traffic?
function CollisionDetector:justClearedTraffic()
	local justClearedTraffic = self.nPreviousCollidingObjects and self.nPreviousCollidingObjects > 0 and self.nCollidingObjects == 0
	if justClearedTraffic then self.nPreviousCollidingObjects = self.nCollidingObjects end
	return justClearedTraffic
end

--- Get the speed setting recommended by the collision detector
function CollisionDetector:getSpeed()
	return 0
end

--- Update the collision detection boxes. This bends the snake according to the next waypoints in the path so
-- we can detect objects along the path.
---@param course Course
function CollisionDetector:update(course, ix, lx, lz, disableLongCheck)
	local colDirX = lx
	local colDirZ = lz

	if self.trafficCollisionTriggers[1] ~= nil then
		courseplay:setCollisionDirection(self.vehicle.cp.DirectionNode, self.trafficCollisionTriggers[1], colDirX, colDirZ)
		local recordNumber = ix
		if self.vehicle.cp.collidingVehicleId == nil then
			for i = 2, #self.trafficCollisionTriggers do
				if disableLongCheck or recordNumber + i >= course:getNumberOfWaypoints() or recordNumber < 2 then
					courseplay:setCollisionDirection(self.trafficCollisionTriggers[i-1], self.trafficCollisionTriggers[i], 0, -1)
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
							courseplay:setCollisionDirection(self.trafficCollisionTriggers[1], self.trafficCollisionTriggers[i], 0, 1)
							break
						end
						index = index + 1
						oldValue = Z
					end
					nodeDirX, nodeDirY, nodeDirZ = worldDirectionToLocal(self.trafficCollisionTriggers[i - 1], nodeDirX, nodeDirY, nodeDirZ)
					courseplay:setCollisionDirection(self.trafficCollisionTriggers[i - 1], self.trafficCollisionTriggers[i], nodeDirX, nodeDirZ)
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
	courseplay.debugVehicle(12, self.vehicle, ...)
end
