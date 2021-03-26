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

    -- make sure not calling this for something which does not have courseplay installed (only ones with spec_aiVehicle)
    if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle.spec_aiVehicle then

        if self.vehicle ~= g_currentMission.controlledVehicle then
            self.vehicleData = PathfinderUtil.VehicleData(g_currentMission.controlledVehicle, true)
        end

        self.vehicle = g_currentMission.controlledVehicle
        self.node = g_currentMission.controlledVehicle.rootNode
        lx, _, lz = localDirectionToWorld(self.node, 0, 0, 1)

        self:updateProximitySensors(self.vehicle)
    else
        -- camera node looks backwards so need to flip everything by 180 degrees
        self.node = g_currentMission.player.cameraNode
        lx, _, lz = localDirectionToWorld(self.node, 0, 0, -1)
        if not self.proxySensor then
            self.proxySensor = ProximitySensor(self.node, 180, 10, 1, 0)
        else
            self.proxySensor:update()
            self.proxySensor:showDebugInfo()
        end
    end

    self.yRot = math.atan2( lx, lz )
    self.data.yRotDeg = math.deg(self.yRot)
    self.data.yRotDeg2 = math.deg(MathUtil.getYRotationFromDirection(lx, lz))
    self.data.x, self.data.y, self.data.z = getWorldTranslation(self.node)
    self.data.fieldNum = courseplay.fields:getFieldNumForPosition(self.data.x, self.data.z)

    self.data.hasFruit, self.data.fruitValue, self.data.fruit = PathfinderUtil.hasFruit(self.data.x, self.data.z, 5, 3.6)
    self.data.isField, self.fieldArea, self.totalFieldArea = courseplay:isField(self.data.x, self.data.z, 3, 3)

    self.data.landId =  PathfinderUtil.getFieldIdAtWorldPosition(self.data.x, self.data.z)
    self.data.owned =  PathfinderUtil.isWorldPositionOwned(self.data.x, self.data.z)
	self.data.farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(self.data.x, self.data.z)
	self.data.farmland = g_farmlandManager:getFarmlandAtWorldPosition(self.data.x, self.data.z)
    self.data.fieldAreaPercent = 100 * self.fieldArea / self.totalFieldArea

	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.data.x, self.data.y, self.data.z)
	self.data.nx, self.data.ny, self.data.nz = getTerrainNormalAtWorldPos(g_currentMission.terrainRootNode, self.data.x, y, self.data.z)

	local xRot, yRot, zRot = PathfinderUtil.getNormalWorldRotation(self.data.x, self.data.z)

	self.data.txRotDeg = math.deg(xRot)
	self.data.tyRotDeg = math.deg(yRot)
	self.data.tzRotDeg = math.deg(zRot)

    self.data.collidingShapes = ''
    overlapBox(self.data.x, self.data.y + 0.2, self.data.z, 0, self.yRot, 0, 1.6, 1, 8, "overlapBoxCallback", self,
		bitOR(AIVehicleUtil.COLLISION_MASK, 2), true, true, true)

    if self.pathfinder and self.pathfinder:isActive() then
        local done, path = self.pathfinder:resume()
        if done then
            self:loadPath(path)
        end
    end

end

function DevHelper:overlapBoxCallback(transformId)
    local collidingObject = g_currentMission.nodeToObject[transformId]
    local text
    if collidingObject then
        if collidingObject.getRootVehicle then
            text = 'vehicle' .. collidingObject:getName()
        else
			if collidingObject:isa(Bale) then
				text = 'Bale'
			else
            	text = collidingObject.getName and collidingObject:getName() or 'N/A'
			end
        end
    else
        text = ''
        for key, classId in pairs(ClassIds) do
            if getHasClassId(transformId, classId) then
                text = text .. ' ' .. key
            end
        end
    end


    self.data.collidingShapes = self.data.collidingShapes .. '|' .. text
end

function DevHelper:updateProximitySensors(vehicle)
    if vehicle and vehicle.cp.driver then
        if vehicle.cp.driver.forwardLookingProximitySensorPack then
            local d, otherVehicle, object, deg, dAvg =
                vehicle.cp.driver.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
			--renderText(0.6, 0.4, 0.018, string.format('d=%.1f %s deg=%.1f dAvg=%.1f dx=%.1f (%s)',
			--	d, nameNum(otherVehicle), deg, dAvg, dAvg * math.sin(math.rad(deg)), nameNum(vehicle)))
		end
        if vehicle.cp.driver.backwardLookingProximitySensorPack then
            local d, otherVehicle, object, deg, dAvg =
                vehicle.cp.driver.backwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
        end
    end
end

-- Left-Alt + , (<) = mark current position as start for pathfinding
-- Left-Alt + , (<) = mark current position as start for pathfinding
-- Left-Alt + . (>) = mark current position as goal for pathfinding
-- Left-Ctrl + . (>) = start pathfinding from marked start to marked goal
-- Left-Ctrl + , (<) = mark current field as field for pathfinding
-- Left-Alt + Space = save current vehicle position
-- Left-Ctrl + Space = restore current vehicle position
function DevHelper:keyEvent(unicode, sym, modifier, isDown)
    if not CpManager.isDeveloper then return end
    if bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_comma then
        -- Left Alt + < mark start
        self.start = State3D(self.data.x, -self.data.z, courseGenerator.fromCpAngleDeg(self.data.yRotDeg))
        self:debug('Start %s', tostring(self.start))
		PathfinderUtil.checkForObstaclesAhead(self.vehicle, 6)
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
    elseif bitAND(modifier, Input.MOD_LCTRL) ~= 0 and isDown and sym == Input.KEY_comma then
        self.fieldNumForPathfinding = PathfinderUtil.getFieldNumUnderNode(self.node)
        self:debug('Set field %d for pathfinding', self.fieldNumForPathfinding)
    elseif bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_space then
        -- save vehicle position
        g_currentMission.controlledVehicle.vehiclePositionData = {}
        DevHelper.saveVehiclePosition(g_currentMission.controlledVehicle, g_currentMission.controlledVehicle.vehiclePositionData)
    elseif bitAND(modifier, Input.MOD_LCTRL) ~= 0 and isDown and sym == Input.KEY_space then
        -- restore vehicle position
        DevHelper.restoreVehiclePosition(g_currentMission.controlledVehicle)
    end
end

function DevHelper:startPathfinding()
    self.pathfinderStartTime = g_time
    self:debug('Starting pathfinding between %s and %s', tostring(self.start), tostring(self.goal))

    local done, path
    if self.vehicle and self.vehicle.cp.driver and self.vehicle.cp.driver.fieldworkCourse then
        self:debug('Starting pathfinding for turn between %s and %s', tostring(self.start), tostring(self.goal))
        self.pathfinder, done, path = PathfinderUtil.findPathForTurn(self.vehicle, 0, self.goalNode, 0,
                1.05 * self.vehicle.cp.turnDiameter / 2, false, self.vehicle.cp.driver.fieldworkCourse)
    else
        self:debug('Starting pathfinding (no reverse) between %s and %s, field %d',
                tostring(self.start), tostring(self.goal), self.fieldNumForPathfinding or 0)
        local start = State3D:copy(self.start)

        self.pathfinder, done, path =  PathfinderUtil.startPathfindingFromVehicleToGoal(self.vehicle, self.goal,
                false, self.fieldNumForPathfinding or 0, {}, 10)

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
    DebugUtil.renderTable(0.65, 0.3, 0.013, data, 0.05)
    self:drawCourse()
    self:showVehicleSize()
    self:showFillNodes()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle ~= g_currentMission.controlledVehicle and vehicle.cp and vehicle.cp.driver then
            vehicle.cp.driver:onDraw()
        end
    end
    PathfinderUtil.showNodes(self.pathfinder)
    PathfinderUtil.showOverlapBoxes()

	if not self.tNode then
		self.tNode = createTransformGroup("devhelper")
		link(g_currentMission.terrainRootNode, self.tNode)
	end

	PathfinderUtil.setWorldPositionAndRotationOnTerrain(self.tNode, self.data.x, self.data.z, self.yRot, 0.5)

	DebugUtil.drawDebugNode(self.tNode, 'Terrain normal')
	local nx, ny, nz = getTerrainNormalAtWorldPos(g_currentMission.terrainRootNode, self.data.x, self.data.y, self.data.z)

	local x, y, z = localToWorld(self.node, 0, -1, -3)

	cpDebug:drawLine(x, y, z, 1, 1, 1, x + nx, y + ny, z + nz)
	local xRot, yRot, zRot = getWorldRotation(self.tNode)
	DebugUtil.drawOverlapBox(self.data.x, self.data.y, self.data.z, xRot, yRot, zRot, 4, 1, 4, 0, 100, 0)

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
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(vehicle.rootNode)
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

            drawDebugLine(x1,y1,z1,0.2, 0.2 ,1,x2,y2,z2,0.2, 0.2,1);
            drawDebugLine(x1,y1,z1,0.2, 0.2 ,1,x3,y3,z3,0.2, 0.2,1);
            drawDebugLine(x2,y2,z2,0.2, 0.2 ,1,x4,y4,z4,0.2, 0.2,1);
            drawDebugLine(x3,y3,z3,0.2, 0.2 ,1,x4,y4,z4,0.2, 0.2,1);
        end
        if self.vehicleData.trailerRectangle then
			PathfinderUtil.initializeTrailerHeading(node, self.vehicleData)
            local x, y, z = localToWorld(g_devHelper.helperNode, 0, 0, self.vehicleData.trailerHitchOffset)
            setTranslation(g_devHelper.helperNode, x, y, z)
            setRotation(g_devHelper.helperNode, 0, courseGenerator.toCpAngle(node.tTrailer), 0)
            local x1,y1,z1 = localToWorld(g_devHelper.helperNode, self.vehicleData.trailerRectangle.dRight, 2, self.vehicleData.trailerRectangle.dFront);
            local x2,y2,z2 = localToWorld(g_devHelper.helperNode, self.vehicleData.trailerRectangle.dLeft, 2, self.vehicleData.trailerRectangle.dFront);
            local x3,y3,z3 = localToWorld(g_devHelper.helperNode, self.vehicleData.trailerRectangle.dRight, 2, self.vehicleData.trailerRectangle.dRear);
            local x4,y4,z4 = localToWorld(g_devHelper.helperNode, self.vehicleData.trailerRectangle.dLeft, 2, self.vehicleData.trailerRectangle.dRear);

            drawDebugLine(x1,y1,z1,0,1,0,x2,y2,z2,0,1,0);
            drawDebugLine(x1,y1,z1,0,1,0,x3,y3,z3,0,1,0);
            drawDebugLine(x2,y2,z2,0,1,0,x4,y4,z4,0,1,0);
            drawDebugLine(x3,y3,z3,0,1,0,x4,y4,z4,0,1,0);
        end
    end
    DebugUtil.drawDebugNode(g_devHelper.helperNode, 'devhelper')
end

function DevHelper.saveVehiclePosition(vehicle, vehiclePositionData)
    local savePosition = function(object)
        local savedPosition = {}
        savedPosition.x, savedPosition.y, savedPosition.z = getWorldTranslation(object.rootNode)
        savedPosition.xRot, savedPosition.yRot, savedPosition.zRot = getWorldRotation(object.rootNode)
        return savedPosition
    end
    if not vehicle.getAttachedImplements then return end
    table.insert(vehiclePositionData, {vehicle, savePosition(vehicle)})
    for _,impl in pairs(vehicle:getAttachedImplements()) do
        DevHelper.saveVehiclePosition(impl.object, vehiclePositionData)
    end
    courseplay.info('Saved position of %s', nameNum(vehicle))
end

function DevHelper.restoreVehiclePosition(vehicle)
    if vehicle.vehiclePositionData then
        for _, savedPosition in pairs(vehicle.vehiclePositionData) do
            savedPosition[1]:setAbsolutePosition(savedPosition[2].x, savedPosition[2].y, savedPosition[2].z,
                    savedPosition[2].xRot, savedPosition[2].yRot, savedPosition[2].zRot)
            courseplay.info('Restored position of %s', nameNum(savedPosition[1]))
        end
    end
end

function DevHelper.restoreAllVehiclePositions()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle.vehiclePositionData then
            DevHelper.restoreVehiclePosition(vehicle)
        end
    end
end

function DevHelper.saveAllVehiclePositions()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        vehicle.vehiclePositionData = {}
        DevHelper.saveVehiclePosition(vehicle, vehicle.vehiclePositionData)
    end
end

-- make sure to recreate the global dev helper whenever this script is (re)loaded
g_devHelper = DevHelper()
