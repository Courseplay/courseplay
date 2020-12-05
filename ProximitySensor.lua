--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2020 Peter Vaiko

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
]]--

---@class ProximitySensor
ProximitySensor = CpObject()
--- No matter what angle, don't make it extend to left/right more than this
ProximitySensor.maxSideExtension = 4

function ProximitySensor:init(node, yRotationDeg, range, height, xOffset)
    self.node = node
    self.xOffset = xOffset
    self.yRotation = math.rad(yRotationDeg)
    self.lx, self.lz = MathUtil.getDirectionFromYRotation(self.yRotation)
    self.range = math.min(range, ProximitySensor.maxSideExtension / math.cos((math.pi / 2 - math.abs(self.yRotation))))
    self.dx, self.dz = self.lx * self.range, self.lz * self.range
    self.height = height or 0
    self.lastUpdateLoopIndex = 0
    self.enabled = true
    -- vehicles can only be ignored temporarily
    self.ignoredVehicle = CpTemporaryObject()
end

function ProximitySensor:enable()
    self.enabled = true
end

function ProximitySensor:disable()
    self.enabled = false
end

---@param vehicle table vehicle to ignore
---@param ttlMs number milliseconds to ignore this vehicle. After ttlMs ms it won't be ignored.
function ProximitySensor:setIgnoredVehicle(vehicle, ttlMs)
    self.ignoredVehicle:set(vehicle, ttlMs)
end

function ProximitySensor:update()
    -- already updated in this loop, no need to raycast again
    if g_updateLoopIndex == self.lastUpdateLoopIndex then return end
    self.lastUpdateLoopIndex = g_updateLoopIndex
    local x, y, z = localToWorld(self.node, self.xOffset, 0, 0)
    -- get the terrain height at the end of the raycast line
    local tx, _, tz = localToWorld(self.node, self.dx, 0, self.dz)
    local y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tx, 0, tz)
    -- make sure the raycast line is parallel with the ground
    local ny = (y2 - y) / self.range
    local nx, _, nz = localDirectionToWorld(self.node, self.lx, 0, self.lz)
    self.distanceOfClosestObject = math.huge
    self.objectId = nil
    if self.enabled then
        raycastClosest(x, y + self.height, z, nx, ny, nz, 'raycastCallback', self.range, self, bitOR(AIVehicleUtil.COLLISION_MASK, 2))
--        cpDebug:drawLine(x, y + self.height, z, 0, 1, 0, tx, y2 + self.height, tz)
    end
    if courseplay.debugChannels[12] and self.distanceOfClosestObject <= self.range then
        local green = self.distanceOfClosestObject / self.range
        local red = 1 - green
        cpDebug:drawLine(x, y + self.height, z, red, green, 0, self.closestObjectX, self.closestObjectY, self.closestObjectZ)
    end
end

function ProximitySensor:raycastCallback(objectId, x, y, z, distance)
    local object = g_currentMission:getNodeObject(objectId)
    if object and object.getRootVehicle and object:getRootVehicle() == self.ignoredVehicle:get() then
        -- ignore this vehicle
        return
    end
    self.distanceOfClosestObject = distance
    self.objectId = objectId
    self.closestObjectX, self.closestObjectY, self.closestObjectZ = x, y, z
end

function ProximitySensor:getClosestObjectDistance()
--    self:showDebugInfo()
    return self.distanceOfClosestObject
end

function ProximitySensor:getClosestRootVehicle()
    if self.objectId then
        local object = g_currentMission:getNodeObject(self.objectId)
        if object and object.getRootVehicle then
            return object:getRootVehicle()
        end
    end
end

function ProximitySensor:showDebugInfo()
    local text = string.format('%.1f ', self.distanceOfClosestObject)
    if self.objectId then
        local object = g_currentMission:getNodeObject(self.objectId)
        if object then
            if object.getRootVehicle then
                text = text .. 'vehicle' .. object:getName()
            else
                text = text .. object:getName()
            end
        else
            for key, classId in pairs(ClassIds) do
                if getHasClassId(self.objectId, classId) then
                    text = text .. ' ' .. key
                end
            end
        end
    end
    renderText(0.6, 0.4 + self.yRotation / 10, 0.018, text .. string.format(' %d', math.deg(self.yRotation)))
end

---@class ProximitySensorPack
ProximitySensorPack = CpObject()

-- maximum angle we rotate the sensor pack into the direction the vehicle is turning
ProximitySensorPack.maxRotation = math.rad(30)

---@param name string a name for this sensor, when multiple sensors are attached to the same node, they need
--- a unique name
---@param vehicle table vehicle we attach the sensor to, used only to rotate the sensor with the steering angle
---@param ppc PurePursuitController PPC of the vehicle, used only to rotate the sensor towards the goal point
---@param node number node (front or back) to attach the sensor to
---@param range number range of the sensor in meters
---@param height number height relative to the node in meters
---@param directionsDeg table of numbers, list of angles in degrees to emit a ray to find objects, 0 is forward, >0 left, <0 right
---@param xOffsets table of numbers, left/right offset of the corresponding sensor in meters, left > 0, right < 0
function ProximitySensorPack:init(name, vehicle, ppc, node, range, height, directionsDeg, xOffsets)
    ---@type ProximitySensor[]
    self.sensors = {}
    self.vehicle = vehicle
    self.ppc = ppc
    self.range = range
    self.name = name
    self.node = getChild(node, name)
    if self.node <= 0 then
        -- node with this name does not yet exist
        -- add a separate node for the proximity sensor (so we can rotate it independently from 'node'
        self.node = courseplay.createNode(name, 0, 0, 0, node)
    end
    -- reset it on the parent node
    setTranslation(self.node, 0, 0, 0)
    setRotation(self.node, 0, 0, 0)
    self.directionsDeg = directionsDeg
    self.xOffsets = xOffsets
    self.rotateToGoalPoint = false
    self.rotation = 0
    for i, deg in ipairs(self.directionsDeg) do
        self.sensors[deg] = ProximitySensor(self.node, deg, self.range, height, xOffsets[i] or 0)
    end
end

function ProximitySensorPack:debug(...)
    courseplay.debugVehicle(12, self.vehicle, ...)
end

function ProximitySensorPack:adjustForwardPosition()
    -- are we looking forward
    local forward = 1
    -- if a sensor about in the middle is pointing back, we are looking back
    if math.abs(self.directionsDeg[math.floor(#self.directionsDeg / 2)]) > 90 then
        forward = -1
    end
    local x, y, z = getTranslation(self.node)
    self:debug('moving proximity sensor %s %.1f so it does not interfere with own vehicle', self.name, forward * 0.1)
    -- move pack forward/back a bit
    setTranslation(self.node, x, y, z + forward * 0.1)
end

function ProximitySensorPack:getRange()
    return self.range
end

function ProximitySensorPack:callForAllSensors(func, ...)
    for _, deg in ipairs(self.directionsDeg) do
        func(self.sensors[deg], ...)
    end
end

function ProximitySensorPack:disableRotateToGoalPoint()
    self.rotateToGoalPoint = false
end

function ProximitySensorPack:update()

    if self.rotateToGoalPoint then
        -- rotate the entire pack in the direction of the goal point
        local dx, dz = self.ppc:getGoalPointDirection()
        local yRot = MathUtil.getYRotationFromDirection(dx, dz)
        self.rotation = MathUtil.clamp(yRot, -ProximitySensorPack.maxRotation, ProximitySensorPack.maxRotation)
        setRotation(self.node, 0, self.rotation, 0)
    end

    self:callForAllSensors(ProximitySensor.update)

    -- show the position of the pack
    if courseplay.debugChannels[12] then
        local x, y, z = getWorldTranslation(self.node)
        local x1, y1, z1 = localToWorld(self.node, 0, 0, 0.5)
        cpDebug:drawLine(x, y, z, 0, 0, 1, x, y + 3, z)
        cpDebug:drawLine(x, y + 1, z, 0, 1, 0, x1, y1 + 1, z1)
    end
end

function ProximitySensorPack:enable()
    self:callForAllSensors(ProximitySensor.enable)
end

function ProximitySensorPack:disable()
    self:callForAllSensors(ProximitySensor.disable)
end

function ProximitySensorPack:setIgnoredVehicle(vehicle, ttlMs)
    self:callForAllSensors(ProximitySensor.setIgnoredVehicle, vehicle, ttlMs)
end

--- @return number, table, number distance of closest object in meters, root vehicle of the closest object, average direction
--- of the obstacle in degrees, > 0 right, < 0 left
function ProximitySensorPack:getClosestObjectDistanceAndRootVehicle(deg)
    -- make sure we have the latest info, the sensors will make sure they only raycast once per loop
    self:update()
    if deg and self.sensors[deg] then
        return self.sensors[deg]:getClosestObjectDistance(), self.sensors[deg]:getClosestRootVehicle(), deg
    else
        local closestDistance = math.huge
        local closestRootVehicle
        -- weighted average over the different direction, weight depends on how close the closest object is
        local totalWeight, totalDegs, totalDistance = 0, 0, 0
        for _, deg in ipairs(self.directionsDeg) do
            local d = self.sensors[deg]:getClosestObjectDistance()
            if d < self.range then
                local weight = (self.range - d) / self.range
                totalWeight = totalWeight + weight
                -- the direction should be in the tractor's system, therefore we need to compensate here with the
                -- current rotation of the pack
                totalDegs = totalDegs + weight * (deg + math.deg(self.rotation))
                totalDistance = totalDistance + weight * d
            end
            if d < closestDistance then
                closestDistance = d
                closestRootVehicle = self.sensors[deg]:getClosestRootVehicle()
            end
        end
        if closestRootVehicle == self.vehicle then
            self:adjustForwardPosition()
        end
        return closestDistance, closestRootVehicle, totalDegs / totalWeight, totalDistance / totalWeight
    end
    return math.huge, nil, deg
end

function ProximitySensorPack:disableRightSide()
    for _, deg in ipairs(self.directionsDeg) do
        if deg <= 0 then
            self.sensors[deg]:disable()
        end
    end
end

function ProximitySensorPack:enableRightSide()
    for _, deg in ipairs(self.directionsDeg) do
        if deg <= 0 then
            self.sensors[deg]:enable()
        end
    end
end

---@class ForwardLookingProximitySensorPack : ProximitySensorPack
ForwardLookingProximitySensorPack = CpObject(ProximitySensorPack)

--- Pack looking forward, all sensors are in the middle of the vehicle
function ForwardLookingProximitySensorPack:init(vehicle, ppc, node, range, height)
    ProximitySensorPack.init(self, 'forward', vehicle, ppc, node, range, height,
            {0, 15, 30, 60, 80, -15, -30, -60, -80},
            {0,  0,  0,  0,  0,   0,   0,   0,  0})
end

---@class WideForwardLookingProximitySensorPack : ProximitySensorPack
WideForwardLookingProximitySensorPack = CpObject(ProximitySensorPack)

--- Pack looking forward, but sensors distributed evenly through the width of the vehicle
function WideForwardLookingProximitySensorPack:init(vehicle, ppc, node, range, height, width)
    local directionsDeg = {80, 60, 30, 15, 0, -15, -30, -60, -80}
    local xOffsets = {}
    -- spread them out evenly across the width
    local dx = width / #directionsDeg
    for xOffset = width / 2 - dx / 2, - width / 2 + dx / 2 - 0.1, - dx do
        table.insert(xOffsets, xOffset)
    end
    ProximitySensorPack.init(self, 'wideForward', vehicle, ppc, node, range, height,
            directionsDeg, xOffsets)
end

---@class BackwardLookingProximitySensorPack : ProximitySensorPack
BackwardLookingProximitySensorPack = CpObject(ProximitySensorPack)

function BackwardLookingProximitySensorPack:init(vehicle, ppc, node, range, height)
    ProximitySensorPack.init(self, 'backward', vehicle, ppc, node, range, height,
            {120, 150, 180, -150, -120},
            {0,     0,   0,    0,    0})
end