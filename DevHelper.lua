--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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

--- Development helper utilities to easily test and diagnose things.
--- To test the pathfinding:
--- 1. mark the start location/heading with Alt + <
--- 2. mark the goal location/heading with Alt + >
--- 3. watch the path generated ...
--- 4. use Ctrl + > to regenerate the path
---
--- Also showing field/fruit/collision information when walking around
DevHelper = CpObject()

function DevHelper:init()
    self.data = {}
    self.isVisualDebugEnabled = false
end

function DevHelper:debug(...)
    print(string.format(...))
end

function DevHelper:update()
    if not CpManager.isDeveloper then return end
    local lx, lz, hasCollision, vehicle

    if g_currentMission.controlledVehicle then

        if self.vehicle ~= g_currentMission.controlledVehicle then
            PathfinderUtil.setUpVehicleCollisionData(g_currentMission.controlledVehicle)
        end

        self.vehicle = g_currentMission.controlledVehicle
        self.node = AIDriverUtil.getDirectionNode(g_currentMission.controlledVehicle)
        lx, _, lz = localDirectionToWorld(self.node, 0, 0, 1)
        self.vehicleData = PathfinderUtil.VehicleData(g_currentMission.controlledVehicle, true)
    else
        self.node = g_currentMission.player.cameraNode
        lx, _, lz = localDirectionToWorld(self.node, 0, 0, -1)
    end

    if self.vehicleData then
        self.collisionData = PathfinderUtil.getCollisionData(self.node, self.vehicleData, 'me')
        hasCollision, vehicle = PathfinderUtil.findCollidingVehicles(self.collisionData, self.node, self.vehicleData)
        if hasCollision then
            self.data.vehicleOverlap = vehicle
        else
            self.data.vehicleOverlap = 'none'
        end
    end

    self.yRot = math.atan2( lx, lz )
    self.data.yRotDeg = math.deg(self.yRot)
    self.data.x, self.data.y, self.data.z = getWorldTranslation(self.node)
    self.data.fieldNum = courseplay.fields:getFieldNumForPosition(self.data.x, self.data.z)

    self.data.hasFruit, self.data.fruitValue, self.data.fruit = PathfinderUtil.hasFruit(self.data.x, self.data.z, 2, 2)
    self.data.isField, self.fieldArea, self.totalFieldArea = courseplay:isField(self.data.x, self.data.z, 10, 10)
    self.data.fieldAreaPercent = 100 * self.fieldArea / self.totalFieldArea

    self.data.collidingShapes = ''
    overlapBox(self.data.x, self.data.y + 1, self.data.z, 0, self.yRot, 0, 3, 3, 3, "overlapBoxCallback", self, AIVehicleUtil.COLLISION_MASK, false, true, true)

    if self.pathfinder and self.pathfinder:isActive() then
        local done, path = self.pathfinder:resume()
        if done then
            self:loadPath(path)
        end
    end

    if self.context then
        if self.data.x < self.context.fieldData.minX or self.data.x > self.context.fieldData.maxX or -self.data.z < self.context.fieldData.minY or -self.data.z > self.context.fieldData.maxY then
            self.data.minX = self.context.fieldData.minX
            self.data.minY = self.context.fieldData.minY
            self.data.validNode = 'off field'
        else
            self.data.validNode = 'on field'
        end
    end

end

function DevHelper:overlapBoxCallback(transformId)
    local collidingObject = g_currentMission.nodeToObject[transformId]
    self.data.collidingShapes = self.data.collidingShapes .. '|' .. (collidingObject and collidingObject:getName() or tostring(collidingObject))
end


function DevHelper:keyEvent(unicode, sym, modifier, isDown)
    if not CpManager.isDeveloper then return end
    if bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_comma then
        -- Left Alt + < mark start
        self.context = PathfinderUtil.Context(self.vehicleData, PathfinderUtil.FieldData(self.data.fieldNum))
        self.start = State3D(self.data.x, -self.data.z, courseGenerator.fromCpAngleDeg(self.data.yRotDeg))
        self:debug('Start %s', tostring(self.start))
    elseif bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_period then
        -- Left Alt + > mark goal
        self.goal = State3D(self.data.x, -self.data.z, courseGenerator.fromCpAngleDeg(self.data.yRotDeg))

        local x, y, z = getWorldTranslation(self.node)
        local _, yRot, _ = getRotation(self.node)
        if self.goalNode then
            setTranslation( self.goalNode, x, y, z );
            setRotation( self.goalNode, 0, yRot, 0);
        else
            self.goalNode = courseplay.createNode('devhelper', x, z, yRot)
        end

        self:debug('Goal %s', tostring(self.goal))
        --self:startPathfinding()
    elseif bitAND(modifier, Input.MOD_LCTRL) ~= 0 and isDown and sym == Input.KEY_period then
        -- Left Ctrl + > find path
        self:debug('Calculate')
        self:startPathfinding()
    end
end

function DevHelper:startPathfinding()
    self.pathfinderStartTime = g_time
    self:debug('Starting pathfinding between %s and %s', tostring(self.start), tostring(self.goal))

    local done, path
    if self.vehicle and self.vehicle.cp.driver and self.vehicle.cp.driver.fieldworkCourse then
        self:debug('Starting pathfinding for turn between %s and %s', tostring(self.start), tostring(self.goal))
        self.pathfinder, done, path = PathfinderUtil.findPathForTurn(self.vehicle, 0, self.goalNode, 0,
                1.05 * self.vehicle.cp.turnDiameter / 2, true, self.vehicle.cp.driver.fieldworkCourse)
    else
        self:debug('Starting pathfinding (allow reverse) between %s and %s', tostring(self.start), tostring(self.goal))
        local start = State3D:copy(self.start)
        self.pathfinder, done, path = PathfinderUtil.startPathfinding(start, self.goal, self.context, true)
    end

    if done then
        if path then
            self:loadPath(path)
        else
            self:debug('No path found')
        end
    end
end

function DevHelper:mouseEvent(posX, posY, isDown, isUp, mouseKey)
end

function DevHelper:toggleVisualDebug()
    self.isVisualDebugEnabled = not self.isVisualDebugEnabled
end

function DevHelper:draw()
    if not CpManager.isDeveloper then return end
    if not self.isVisualDebugEnabled then return end
    local data = {}
    for key, value in pairs(self.data) do
        table.insert(data, {name = key, value = value})
    end
    DebugUtil.renderTable(0.3, 0.3, 0.02, data, 0.05)
    self:drawCourse()
    self:showVehicleSize()
    self:showFillNodes()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle ~= g_currentMission.controlledVehicle and vehicle.cp and vehicle.cp.driver then
            vehicle.cp.driver:onDraw()
        end
    end
    PathfinderUtil.showNodes(self.pathfinder)
end

---@param path State3D[]
function DevHelper:loadPath(path)
    if path then
        self:debug('Path with %d waypoint found, finished in %d ms', #path, g_time - self.pathfinderStartTime)
        self.course = Course(nil, courseGenerator.pointsToXzInPlace(path), true)
    else
        self:debug('No path!')
    end
end

function DevHelper:drawCourse()
    if not self.course then return end
    for i = 1, self.course:getNumberOfWaypoints() do
        local x, y, z = self.course:getWaypointPosition(i)
        cpDebug:drawPoint(x, y + 3, z, 10, 0, 0)
        Utils.renderTextAtWorldPosition(x, y + 3.2, z, tostring(i), getCorrectTextSize(0.012), 0)
        if i < self.course:getNumberOfWaypoints() then
            local nx, ny, nz = self.course:getWaypointPosition(i + 1)
            cpDebug:drawLine(x, y + 3, z, 0, 0, 100, nx, ny + 3, nz)
        end
    end
end


function DevHelper:showFillNodes()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if SpecializationUtil.hasSpecialization(Trailer, vehicle.specializations) then
            DebugUtil.drawDebugNode(vehicle.rootNode, 'Root node')
            local fillUnits = vehicle:getFillUnits()
            for i = 1, #fillUnits do
                local fillRootNode = vehicle:getFillUnitExactFillRootNode(i)
                if fillRootNode then DebugUtil.drawDebugNode(fillRootNode, 'Fill node ' .. tostring(i)) end
            end
        end
    end
end

function DevHelper:showVehicleSize()
    local vehicle = g_currentMission.controlledVehicle
    if not vehicle then return end
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(vehicle))
    local node = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    if not g_devHelper.helperNode then
        g_devHelper.helperNode = courseplay.createNode('pathfinderHelper', node.x, -node.y, 0)
    end
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, node.x, 0, -node.y);
    setTranslation(g_devHelper.helperNode, node.x, y, -node.y)
    setRotation(g_devHelper.helperNode, 0, courseGenerator.toCpAngle(node.t), 0)
   
    if self.vehicleData then
        for _, rectangle in ipairs(self.vehicleData.rectangles) do
            local x1,y1,z1 = localToWorld(g_devHelper.helperNode, rectangle.dRight, 2, rectangle.dFront);
            local x2,y2,z2 = localToWorld(g_devHelper.helperNode, rectangle.dLeft, 2, rectangle.dFront);
            local x3,y3,z3 = localToWorld(g_devHelper.helperNode, rectangle.dRight, 2, rectangle.dRear);
            local x4,y4,z4 = localToWorld(g_devHelper.helperNode, rectangle.dLeft, 2, rectangle.dRear);

            drawDebugLine(x1,y1,z1,0,0,1,x2,y2,z2,0,0,1);
            drawDebugLine(x1,y1,z1,0,0,1,x3,y3,z3,0,0,1);
            drawDebugLine(x2,y2,z2,0,0,1,x4,y4,z4,0,0,1);
            drawDebugLine(x3,y3,z3,0,0,1,x4,y4,z4,0,0,1);
        end
    end
    if self.collisionData then
        for i = 1, 4 do
            local cp = self.collisionData.corners[i]
            local pp = self.collisionData.corners[i > 1 and i - 1 or 4]
            cpDebug:drawLine(cp.x, cp.y + 0.4, cp.z, 1, 1, 0, pp.x, pp.y + 0.4, pp.z)
        end
    end
end

-- make sure to recreate the global dev helper whenever this script is (re)loaded
g_devHelper = DevHelper()
