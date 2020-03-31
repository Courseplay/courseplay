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
]]

---@class ProximitySensor
ProximitySensor = CpObject()

function ProximitySensor:init(node, lx, lz, range, height)
    self.node = node
    self.lx, self.lz = lx, lz
    self.range = range
    self.height = height or 0
end

function ProximitySensor:update()
    local x, y, z = getWorldTranslation(self.node)
    local nx, ny, nz = localDirectionToWorld(self.node, self.lx, 0, self.lz)
    self.distanceOfClosestObject = math.huge
    raycastClosest(x, y + self.height, z, nx, ny, nz, 'raycastCallback', self.range, self, bitOR(AIVehicleUtil.COLLISION_MASK, 2))
    if self.distanceOfClosestObject <= self.range then
        cpDebug:drawLine(x, y + self.height, z, 1, 1, 1, self.closestObjectX, self.closestObjectY, self.closestObjectZ)
    end
end

function ProximitySensor:raycastCallback(objectId, x, y, z, distance)
    self.distanceOfClosestObject = distance
    self.objectId = objectId
    self.closestObjectX, self.closestObjectY, self.closestObjectZ = x, y, z
end

function ProximitySensor:getClosestObjectDistance()
    self:update()
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
    renderText(0.6, 0.4, 0.018, text)
end