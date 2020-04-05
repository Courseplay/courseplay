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
end

function ProximitySensor:update()
    -- already updated in this loop, no need to raycast again
    if g_updateLoopIndex == self.lastUpdateLoopIndex then return end
    self.lastUpdateLoopIndex = g_updateLoopIndex
    local x, y, z = getWorldTranslation(self.node)
    local nx, ny, nz = localDirectionToWorld(self.node, self.lx, 0, self.lz)
    self.distanceOfClosestObject = math.huge
    raycastClosest(x, y + self.height, z, nx, ny, nz, 'raycastCallback', self.range, self, bitOR(AIVehicleUtil.COLLISION_MASK, 2))
    if courseplay.debugChannels[12] and self.distanceOfClosestObject <= self.range then
        cpDebug:drawLine(x, y + self.height, z, 1, 1, 1, self.closestObjectX, self.closestObjectY, self.closestObjectZ)
    end
end

function ProximitySensor:raycastCallback(objectId, x, y, z, distance)
    self.distanceOfClosestObject = distance
    self.objectId = objectId
    self.closestObjectX, self.closestObjectY, self.closestObjectZ = x, y, z
end

function ProximitySensor:getClosestObjectDistance()
    self:showDebugInfo()
    return self.distanceOfClosestObject
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
    self.directionsDeg = directionsDeg
    for _, deg in ipairs(self.directionsDeg) do
        self.sensors[deg] = ProximitySensor(node, deg, range, height)
    end
end

function ProximitySensorPack:update()
    for _, deg in ipairs(self.directionsDeg) do
        self.sensors[deg]:update()
    end
end

function ProximitySensorPack:getClosestObjectDistance(deg)
    if deg then
        return self.sensors[deg] and self.sensors[deg]:getClosestObjectDistance() or math.huge
    else
        local closestDistance = math.huge
        for _, deg in ipairs(self.directionsDeg) do
            local d = self.sensors[deg]:getClosestObjectDistance()
            closestDistance = d < closestDistance and d or closestDistance
        end
        return closestDistance
    end
end

---@class ForwardLookingProximitySensorPack : ProximitySensorPack
ForwardLookingProximitySensorPack = CpObject(ProximitySensorPack)

function ForwardLookingProximitySensorPack:init(node, range, height)
    ProximitySensorPack.init(self, node, range, height,{0, 45, 90, -45, -90})
end

