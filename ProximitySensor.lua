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

function ProximitySensor:init(node, yRotationDeg, range, height)
    self.node = node
    self.yRotation = math.rad(yRotationDeg)
    self.lx, self.lz = MathUtil.getDirectionFromYRotation(self.yRotation)
    self.range = range
    self.height = height or 0
    self.lastUpdateLoopIndex = 0
    self.enabled = true
end

function ProximitySensor:enable()
    self.enabled = true
end

function ProximitySensor:disable()
    self.enabled = false
end

function ProximitySensor:update()
    -- already updated in this loop, no need to raycast again
    if g_updateLoopIndex == self.lastUpdateLoopIndex then return end
    self.lastUpdateLoopIndex = g_updateLoopIndex
    local x, y, z = getWorldTranslation(self.node)
    local nx, ny, nz = localDirectionToWorld(self.node, self.lx, 0, self.lz)
    self.distanceOfClosestObject = math.huge
    self.objectId = nil
    if self.enabled then
        raycastClosest(x, y + self.height, z, nx, ny, nz, 'raycastCallback', self.range, self, bitOR(AIVehicleUtil.COLLISION_MASK, 2))
    end
    if courseplay.debugChannels[12] and self.distanceOfClosestObject <= self.range then
        local green = self.distanceOfClosestObject / self.range
        local red = 1 - green
        cpDebug:drawLine(x, y + self.height, z, red, green, 0, self.closestObjectX, self.closestObjectY, self.closestObjectZ)
    end
end

function ProximitySensor:raycastCallback(objectId, x, y, z, distance)
    self.distanceOfClosestObject = distance
    self.objectId = objectId
    self.closestObjectX, self.closestObjectY, self.closestObjectZ = x, y, z
end

function ProximitySensor:getClosestObjectDistance()
    --self:showDebugInfo()
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
function ProximitySensorPack:init(node, range, height, directionsDeg)
    ---@type ProximitySensor[]
    self.sensors = {}
    self.range = range
    self.node = node
    self.directionsDeg = directionsDeg
    self.speedControlEnabled = true
    for _, deg in ipairs(self.directionsDeg) do
        self.sensors[deg] = ProximitySensor(node, deg, self.range, height)
    end
end

function ProximitySensorPack:getRange()
    return self.range
end

function ProximitySensorPack:callForAllSensors(func, ...)
    for _, deg in ipairs(self.directionsDeg) do
        func(self.sensors[deg], ...)
    end
end

function ProximitySensorPack:disableSpeedControl()
    self.speedControlEnabled = false
end

function ProximitySensorPack:enableSpeedControl()
    self.speedControlEnabled = true
end

--- Should this pack used to control the speed of the vehicle (or just delivers info about proximity)
function ProximitySensorPack:isSpeedControlEnabled()
    return self.speedControlEnabled
end

function ProximitySensorPack:update()
    self:callForAllSensors(ProximitySensor.update)

    -- show the position of the pack
    if courseplay.debugChannels[12] then
        local x, y, z = getWorldTranslation(self.node)
        cpDebug:drawLine(x, y, z, 0, 0, 1, x, y + 3, z)
    end
end

function ProximitySensorPack:enable()
    self:callForAllSensors(ProximitySensor.enable)
end

function ProximitySensorPack:disable()
    self:callForAllSensors(ProximitySensor.disable)
end

function ProximitySensorPack:getClosestObjectDistanceAndRootVehicle(deg)
    if deg and self.sensors[deg] then
        return self.sensors[deg]:getClosestObjectDistance(), self.sensors[deg]:getClosestRootVehicle()
    else
        local closestDistance = math.huge
        local closestRootVehicle
        for _, deg in ipairs(self.directionsDeg) do
            local d = self.sensors[deg]:getClosestObjectDistance()
            if d < closestDistance then
                closestDistance = d
                closestRootVehicle = self.sensors[deg]:getClosestRootVehicle()
            end
        end
        return closestDistance, closestRootVehicle
    end
    return math.huge, nil
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

function ForwardLookingProximitySensorPack:init(node, range, height)
    ProximitySensorPack.init(self, node, range, height,{0, 45, 90, -45, -90})
end


---@class BackwardLookingProximitySensorPack : ProximitySensorPack
BackwardLookingProximitySensorPack = CpObject(ProximitySensorPack)

function BackwardLookingProximitySensorPack:init(node, range, height)
    ProximitySensorPack.init(self, node, range, height,{120, 150, 180, -150, -120})
end