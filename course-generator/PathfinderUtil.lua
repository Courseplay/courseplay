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

PathfinderUtil = {}

PathfinderUtil.dubinsSolver = DubinsSolver()
PathfinderUtil.reedSheppSolver = ReedsSheppSolver()

---Size/turn radius all other information on the vehicle
---@class PathfinderUtil.VehicleData
PathfinderUtil.VehicleData = CpObject()

--- VehicleData is used to perform a hierarchical collision detection. The vehicle's bounding box
--- includes all implements and checked first for collisions. If there is a hit, the individual parts
--- (vehicle and implements) are each checked for collision. This is to avoid false alarms in case of
--- non-rectangular shapes, like a combine with a wide header
function PathfinderUtil.VehicleData:init(vehicle, withImplements, buffer)
    self.turnRadius = vehicle.cp and vehicle.cp.turnDiameter and vehicle.cp.turnDiameter / 2 or 10
    self.vehicle = vehicle
    self.name = vehicle.getName and vehicle:getName() or 'N/A'
    -- distance of the sides of a rectangle from the direction node of the vehicle
    -- in other words, the X and Z offsets of the corners from the direction node
    -- negative is to the rear and to the right
    -- this is the bounding box of the entire vehicle with all attached implements
    self.dFront, self.dRear, self.dLeft, self.dRight = 0, 0, 0, 0
    self.rectangles = {}
    self:calculateSizeOfObjectList(vehicle, {{object = vehicle}}, buffer, self.rectangles)
    if withImplements then
        self:calculateSizeOfObjectList(vehicle, vehicle:getAttachedImplements(), buffer, self.rectangles)
    end
end

--- calculate the bounding box of all objects in the implement list. This is not a very good way to figure out how
--- big a vehicle is as the sizes of foldable implements seem to be in the folded state but should be ok for
--- now.
function PathfinderUtil.VehicleData:calculateSizeOfObjectList(vehicle, implements, buffer, rectangles)
    -- we'll calculate the trailer's precise position an angle for the collision detection to not hit obstacles
    -- while turning. Get that object here, there may be more but we ignore that case.
    local trailer = courseplay:getFirstReversingWheeledWorkTool(vehicle)
    courseplay.debugVehicle(7, vehicle, 'trailer for the pathfinding is %s', trailer and trailer:getName() or 'not found')
    for _, implement in ipairs(implements) do
        --print(implement.object:getName())
        local referenceNode = AIDriverUtil.getDirectionNode(vehicle)
        local rootToDirectionNodeDistance  = 0
        _, _, rootToDirectionNodeDistance = localToLocal(implement.object.rootNode, referenceNode, 0, 0, 0)
        -- default size, used by Giants to determine the drop area when buying something
        local rectangle = {
            dFront = rootToDirectionNodeDistance + implement.object.sizeLength / 2 + implement.object.lengthOffset + (buffer or 0),
            dRear = rootToDirectionNodeDistance - implement.object.sizeLength / 2 - implement.object.lengthOffset + (buffer or 0),
            dLeft = implement.object.sizeWidth / 2,
            dRight = -implement.object.sizeWidth / 2
        }
        -- now see if we have something better, then use that. Since any of the six markers may be missing, we
        -- check them one by one.
        if implement.object.getAIMarkers then
            -- otherwise try the AI markers (work area), this will be bigger than the vehicle's physical size, for example
            -- in case of sprayers
            local aiLeftMarker, aiRightMarker, aiBackMarker = implement.object:getAIMarkers()
            if aiLeftMarker and aiRightMarker then
                rectangle.dLeft, _, rectangle.dFront = localToLocal(aiLeftMarker, referenceNode, 0, 0, 0)
                rectangle.dRight, _, _ = localToLocal(aiRightMarker, referenceNode, 0, 0, 0)
                if aiBackMarker then _, _, rectangle.dRear = localToLocal(aiBackMarker, referenceNode, 0, 0, 0) end
            end
        end
        if implement.object.getAISizeMarkers then
            -- but the best case is if we have the AI size markers
            local aiSizeLeftMarker, aiSizeRightMarker, aiSizeBackMarker = implement.object:getAISizeMarkers()
            if aiSizeLeftMarker then rectangle.dLeft, _, rectangle.dFront = localToLocal(aiSizeLeftMarker, referenceNode, 0, 0, 0) end
            if aiSizeRightMarker then rectangle.dRight, _, _ = localToLocal(aiSizeRightMarker, referenceNode, 0, 0, 0) end
            if aiSizeBackMarker then _, _, rectangle.dRear = localToLocal(aiSizeBackMarker, referenceNode, 0, 0, 0) end
        end
        table.insert(rectangles, rectangle)
        self.dFront = math.max(self.dFront, rectangle.dFront)
        self.dRear  = math.min(self.dRear,  rectangle.dRear)
        self.dLeft  = math.max(self.dLeft,  rectangle.dLeft)
        self.dRight = math.min(self.dRight, rectangle.dRight)
    end
    --courseplay.debugVehicle(7, vehicle, 'Size: dFront %.1f, dRear %.1f, dLeft = %.1f, dRight = %.1f',
    --        self.dFront, self.dRear, self.dLeft, self.dRight)
end

--- Field info for pathfinding
---@class PathfinderUtil.FieldData
PathfinderUtil.FieldData = CpObject()

function PathfinderUtil.FieldData:init(fieldNum)
    if not fieldNum or fieldNum == 0 then
        -- do not restrict search to the field when none given
        self.minX, self.maxX, self.minY, self.maxY, self.minZ, self.maxZ =
            -math.huge, math.huge, -math.huge, math.huge, -math.huge, math.huge
        return
    end
    self.minX, self.maxX, self.minZ, self.maxZ = math.huge, -math.huge, math.huge, -math.huge
    if courseplay.fields.fieldData[fieldNum] then
        for _, point in ipairs(courseplay.fields.fieldData[fieldNum].points) do
            if ( point.cx < self.minX ) then self.minX = point.cx end
            if ( point.cz < self.minZ ) then self.minZ = point.cz end
            if ( point.cx > self.maxX ) then self.maxX = point.cx end
            if ( point.cz > self.maxZ ) then self.maxZ = point.cz end
        end
    end
    self.maxY = -self.minZ + 20
    self.minY = -self.maxZ - 20
    self.maxX = self.maxX + 20
    self.minX = self.minX - 20
end

---@class PathfinderUtil.Parameters
PathfinderUtil.Parameters = CpObject()
---@param maxFruitPercent number maximum percentage of fruit present before a node is marked as invalid
---@param offFieldPenalty number penalty to add for every off-field node The higher, the more likely the vehicle will
---stay on field
function PathfinderUtil.Parameters:init(maxFruitPercent, offFieldPenalty)
    self.maxFruitPercent = maxFruitPercent or 50
    self.offFieldPenalty = offFieldPenalty or 1
end

--- Pathfinder context
---@class PathfinderUtil.Context
PathfinderUtil.Context = CpObject()
function PathfinderUtil.Context:init(vehicleData, fieldData, parameters, vehiclesToIgnore, otherVehiclesCollisionData)
    self.vehicleData = vehicleData
    self.fieldData = fieldData
    self.parameters = parameters
    self.vehiclesToIgnore = vehiclesToIgnore
    self.otherVehiclesCollisionData = otherVehiclesCollisionData
end

--- Calculate the four corners of a rectangle around a node (for example the area covered by a vehicle)
--- the data returned by this is the rectangle from the vehicle data translated and rotated to the node
function PathfinderUtil.getCollisionData(node, vehicleData)
    local x, y, z
    local corners = {}
    x, y, z = localToWorld(node, vehicleData.dRight, 0, vehicleData.dRear)
    table.insert(corners, {x = x, y = y, z = z})
    x, y, z = localToWorld(node, vehicleData.dRight, 0, vehicleData.dFront)
    table.insert(corners, {x = x, y = y, z = z})
    x, y, z = localToWorld(node, vehicleData.dLeft, 0, vehicleData.dFront)
    table.insert(corners, {x = x, y = y, z = z})
    x, y, z = localToWorld(node, vehicleData.dLeft, 0, vehicleData.dRear)
    table.insert(corners, {x = x, y = y, z = z})
    x, y, z = localToWorld(node, 0, 0, 0)
    local center = {x = x, y = y, z = z}
    return {name = vehicleData.name, center = center, corners = corners}
end

function PathfinderUtil.elementOf(list, key)
    for _, element in ipairs(list or {}) do
        if element == key then return true end
    end
    return false
end

--- Find all other vehicles and add them to our list of vehicles to avoid. Must be called before each pathfinding to
--- have the current position of the vehicles.
function PathfinderUtil.setUpVehicleCollisionData(myVehicle, vehiclesToIgnore)
    local vehicleCollisionData = {}
    local myRootVehicle = myVehicle and myVehicle:getRootVehicle() or nil
    for _, vehicle in pairs(g_currentMission.vehicles) do
        local otherRootVehicle = vehicle:getRootVehicle()
        -- ignore also if the root vehicle is ignored
        local ignore = PathfinderUtil.elementOf(vehiclesToIgnore, vehicle) or
                (otherRootVehicle and PathfinderUtil.elementOf(vehiclesToIgnore, otherRootVehicle))
        if ignore then
            courseplay.debugVehicle(14, myVehicle, 'ignoring %s for collisions during pathfinding', vehicle:getName())
        elseif vehicle:getRootVehicle() ~= myRootVehicle and vehicle.rootNode and vehicle.sizeWidth and vehicle.sizeLength then
            local x, _, z = getWorldTranslation(vehicle.rootNode)
            courseplay.debugVehicle(14, myVehicle, 'othervehicle %s at %.1f %.1f, otherroot %s, myroot %s',
                    vehicle:getName(), x, z, vehicle:getRootVehicle():getName(), myRootVehicle:getName())
            table.insert(vehicleCollisionData, PathfinderUtil.getCollisionData(vehicle.rootNode, PathfinderUtil.VehicleData(vehicle)))
        end
    end
    return vehicleCollisionData
end

function PathfinderUtil.findCollidingVehicles(myCollisionData, node, myVehicleData, otherVehiclesCollisionData, log)
    if not otherVehiclesCollisionData then return false end
    for _, collisionData in pairs(otherVehiclesCollisionData) do
        -- check for collision with the vehicle's bounding box
        if PathfinderUtil.doRectanglesOverlap(myCollisionData.corners, collisionData.corners) then
            if log then
                courseplay.debugFormat(7, 'pathfinder colliding vehicle x = %.1f, z = %.1f, %s', myCollisionData.center.x, myCollisionData.center.z, collisionData.name)
            end
            -- check for collision of the individual parts
            for _, rectangle in ipairs(myVehicleData.rectangles) do
                local partCollisionData = PathfinderUtil.getCollisionData(node, rectangle)
                if PathfinderUtil.doRectanglesOverlap(partCollisionData.corners, collisionData.corners) then
                    return true, collisionData.name
                end
            end
        end
    end
    return false
end

---@class PathfinderUtil.CollisionDetector
PathfinderUtil.CollisionDetector = CpObject()

function PathfinderUtil.CollisionDetector:init()
    self.vehiclesToIgnore = {}
    self.collidingShapes = 0
end

function PathfinderUtil.CollisionDetector:overlapBoxCallback(transformId)
    local collidingObject = g_currentMission.nodeToObject[transformId]
    if collidingObject and collidingObject.getRootVehicle then
        local rootVehicle = collidingObject:getRootVehicle()
        if rootVehicle == self.vehicleData.vehicle or PathfinderUtil.elementOf(self.vehiclesToIgnore, rootVehicle) then
            -- just bumped into myself or a vehicle we want to ignore
            return
        end
        --courseplay.debugFormat(7, 'collision: %s', collidingObject:getName())
    end
    if not getHasClassId(transformId, ClassIds.TERRAIN_TRANSFORM_GROUP) then
        --[[local text = ''
        for key, classId in pairs(ClassIds) do
            if getHasClassId(transformId, classId) then
                text = text .. ' ' .. key
            end
        end
        courseplay.debugFormat(7, 'collision %d, %s', transformId, text)]]--
        -- ignore collision with terrain (may happen on slopes)
        self.collidingShapes = self.collidingShapes + 1
    end
end

function PathfinderUtil.CollisionDetector:findCollidingShapes(node, vehicleData, vehiclesToIgnore, log)
    self.vehiclesToIgnore = vehiclesToIgnore or {}
    self.vehicleData = vehicleData
    -- the box for overlapBox() is symmetric, so if our direction node is not in the middle of the vehicle rectangle,
    -- we have to translate it into the middle
    -- right/rear is negative
    local xOffset = vehicleData.dRight + vehicleData.dLeft
    local zOffset = vehicleData.dFront + vehicleData.dRear
    local width = (math.abs(vehicleData.dRight) + math.abs(vehicleData.dLeft)) / 2
    local length = (math.abs(vehicleData.dFront) + math.abs(vehicleData.dRear)) / 2

    local _, _, yRot = PathfinderUtil.getNodePositionAndDirection(node)
    local x, y, z = localToWorld(node, xOffset, 1, zOffset)

    self.collidingShapes = 0

    overlapBox(x, y + 1, z, 0, yRot, 0, width, 1, length, 'overlapBoxCallback', self, bitOR(AIVehicleUtil.COLLISION_MASK, 2), true, true, true)
    if log and self.collidingShapes > 0 then
        courseplay.debugFormat(7, 'pathfinder colliding shapes (%s) at x = %.1f, z = %.1f, (%.1fx%.1f)',
                vehicleData.name, x, z, width, length)
    end
    --DebugUtil.drawOverlapBox(x, y, z, 0, yRot, 0, width, 1, length, 100, 0, 0)

    return self.collidingShapes
end

PathfinderUtil.collisionDetector = PathfinderUtil.CollisionDetector()

function PathfinderUtil.hasFruit(x, z, length, width)
    local fruitsToIgnore = {9, 13, 14} -- POTATO, GRASS, DRYGRASS, we can drive through these...
    for _, fruitType in ipairs(g_fruitTypeManager.fruitTypes) do
        local ignoreThis = false
        for _, fruitToIgnore in ipairs(fruitsToIgnore) do
            if fruitType.index == fruitToIgnore then
                ignoreThis = true
                break
            end
        end
        if not ignoreThis then
            -- if the last boolean parameter is true then it returns fruitValue > 0 for fruits/states ready for forage also
            local fruitValue, a, b, c = FSDensityMapUtil.getFruitArea(fruitType.index, x - width / 2, z - length / 2, x + width / 2, z, x, z + length / 2, true, true)
            if g_updateLoopIndex % 200 == 0 then
                --courseplay.debugFormat(7, '%.1f, %s, %s, %s %s', fruitValue, tostring(a), tostring(b), tostring(c), g_fruitTypeManager:getFruitTypeByIndex(fruitType.index).name)
            end
            if fruitValue > 0 then
                return true, fruitValue, g_fruitTypeManager:getFruitTypeByIndex(fruitType.index).name
            end
        end
    end
    return false
end


--- This is a simplified implementation of the Separating Axis Test, based on Stephan Schloesser's code in AutoDrive.
--- The implementation assumes that a and b are rectangles (not any polygon)
--- We use this during the pathfinding to drive around other vehicles
function PathfinderUtil.doRectanglesOverlap(a, b)

    if math.abs(a[1].x - b[1].x )> 50 then return false end

    for _, rectangle in pairs({a, b}) do

        -- leverage the fact that rectangles have parallel edges, only need to check the first two
        for i = 1, 3 do
            --grab 2 vertices to create an edge
            local p1 = rectangle[i]
            local p2 = rectangle[i + 1]

            -- find the line perpendicular to this edge
            local normal = {x = p2.z - p1.z, z = p1.x - p2.x}

            local minA = math.huge
            local maxA = -math.huge

            -- for each vertex in the first shape, project it onto the line perpendicular to the edge
            -- and keep track of the min and max of these values
            for _, corner in pairs(a) do
                local projected = normal.x * corner.x + normal.z * corner.z
                if projected < minA then
                    minA = projected
                end
                if projected > maxA then
                    maxA = projected
                end
            end

            --for each vertex in the second shape, project it onto the line perpendicular to the edge
            --and keep track of the min and max of these values
            local minB = math.huge
            local maxB = -math.huge
            for _, corner in pairs(b) do
                local projected = normal.x * corner.x + normal.z * corner.z
                if projected < minB then
                    minB = projected
                end
                if projected > maxB then
                    maxB = projected
                end
            end
            -- if there is no overlap between the projections, the edge we are looking at separates the two
            -- rectangles, and we know there is no overlap
            if maxA < minB or maxB < minA then
                return false
            end
        end
    end
    return true
end

--[[
Pathfinding is controlled by the validity and penalty functions below. The pathfinder will call these functions
for each node to determine their validity and penalty.

A node (also called a pose) has a position and a heading, as we don't just want to get to position x, z but
we also need to arrive in a given direction.

Validity

A node is always invalid if it collides with an obstacle (tree, pole, other vehicle). Such nodes are ignored by
the pathfinder. You can mark other nodes invalid too, for example nodes not on the field if we need to keep the
vehicle on the field, but that's usually better handled with a penalty.

The pathfinder can use two separate functions to determine a node's validity, one for the hybrid A* nodes and
a different one for the analytic solutions (Dubins or Reeds-Shepp)

Penalty

Valid nodes can also be prioritized by a penalty, like when in the fruit or off the field. The penalty increases
the cost of a path and the pathfinder will likely avoid nodes with a higher penalty. With this we can keep the path
out of the fruit or on the field.

Context

Both the validity and penalty functions use a context to fine tune their behavior. The context can be set up before
starting the pathfinding according to the caller's preferences.

The context consists of the vehicle data describing the vehicle we are searching a path for, the data of the field
we are working on and a number of parameters. These can be set up for different scenarios, for example turns on the
field or driving to/from the field edge on an unload/refill course.

]]--

--- Calculate penalty for this node. The penalty will be added to the cost of the node. This allows for
--- obstacle avoidance or forcing the search to remain in certain areas.
---@param node State3D
function PathfinderUtil.getNodePenalty(node, context)
    -- tweak these two parameters to set up how far the path will be from the field or fruit boundary
    -- size of the area to check for field/fruit
    local areaSize = 3
    -- minimum ratio of the area checked must be on field/clear of fruit
    local minRequiredAreaRatio = 0.8
    local penalty = 0
    local isField, area, totalArea = courseplay:isField(node.x, -node.y, areaSize, areaSize)
    if area / totalArea < minRequiredAreaRatio then
        penalty = penalty + context.parameters.offFieldPenalty
    end
    --local fieldId = PathfinderUtil.getFieldIdAtWorldPosition(node.x, -node.y)
    if isField then
        local hasFruit, fruitValue = PathfinderUtil.hasFruit(node.x, -node.y, areaSize, areaSize)
        if hasFruit and fruitValue > context.parameters.maxFruitPercent then
            penalty = penalty + fruitValue / 2
        end
    end
    return penalty
end

--- When the pathfinder tries an analytic solution for the entire path from start to goal, we can't use node penalties
--- to find the optimum path, avoiding fruit. Instead, we just check for collisions with vehicles and objects as
--- usual and also mark anything overlapping fruit as invalid. This way a path will only be considered if it is not
--- in the fruit.
function PathfinderUtil.isValidAnalyticSolutionNode(node, context)
    local hasFruit, fruitValue = PathfinderUtil.hasFruit(node.x, -node.y, 3, 3)
    if hasFruit and fruitValue > context.parameters.maxFruitPercent then return false end
    return PathfinderUtil.isValidNode(node, context)
end

--- Check if node is valid: would we collide with another vehicle or shape here?
---@param node State3D
---@param userData PathfinderUtil.Context
---@param log boolean log colliding shapes/vehicles
function PathfinderUtil.isValidNode(node, context, log)

    -- If the pathfinding is constrained to a field, fieldData contains the limits
    if node.x < context.fieldData.minX or node.x > context.fieldData.maxX or node.y < context.fieldData.minY or node.y > context.fieldData.maxY then
        -- not on field
        return false
    end

    -- A helper node to calculate world coordinates
    if not PathfinderUtil.helperNode then
        PathfinderUtil.helperNode = courseplay.createNode('pathfinderHelper', node.x, -node.y, 0)
    end
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, node.x, 0, -node.y);
    setTranslation(PathfinderUtil.helperNode, node.x, y + 0.5, -node.y)
    setRotation(PathfinderUtil.helperNode, 0, courseGenerator.toCpAngle(node.t), 0)

    local myCollisionData = PathfinderUtil.getCollisionData(PathfinderUtil.helperNode, context.vehicleData, 'me')
    -- for debug purposes only, store validity info on node
    node.collidingShapes = PathfinderUtil.collisionDetector:findCollidingShapes(
            PathfinderUtil.helperNode, context.vehicleData, context.vehiclesToIgnore, log)
    node.isColliding, node.vehicle = PathfinderUtil.findCollidingVehicles(
            myCollisionData,
            PathfinderUtil.helperNode,
            context.vehicleData,
            context.otherVehiclesCollisionData,
            log)
    return (not node.isColliding and node.collidingShapes == 0)
end

---@param course Course
---@return Polygon outermost headland as a  polygon (x, y)
function PathfinderUtil.getOutermostHeadland(course)
    local headland = Polygon:new()
    for i = 1, course:getNumberOfWaypoints() do
        if course:isOnOutermostHeadland(i) then
            local x, y, z = course:getWaypointPosition(i)
            headland:add({x = x, y = -z})
        end
    end
    return headland
end

---@param course Course
---@return Polygon all headlands of the course as polyline (x, y)
function PathfinderUtil.getAllHeadlands(course)
    local headlands = Polyline:new()
    for i = 1, course:getNumberOfWaypoints() do
        if course:isOnHeadland(i) then
            local x, y, z = course:getWaypointPosition(i)
            local lane = course:getHeadlandNumber(i)
            headlands:add({x = x, y = -z, lane = lane})
        end
    end
    return headlands
end

---@param start State3D
---@param goal State3D
---@param course Course
---@param turnRadius number
---@return State3D[]
function PathfinderUtil.findShortestPathOnHeadland(start, goal, course, turnRadius)
    -- to be able to use the existing getSectionBetweenPoints, we first create a Polyline[], then construct a State3D[]
    local headland = PathfinderUtil.getOutermostHeadland(course)
    headland:calculateData()
    local path = {}
    for _, p in ipairs(headland:getSectionBetweenPoints(start, goal)) do
        --courseGenerator.debug('%.1f %.1f', p.x, p.y)
        table.insert(path, State3D(p.x, p.y, 0))
    end
    return path
end

--- Interface function to start the pathfinder
---@param start State3D start node
---@param goal State3D goal node
---@param context PathfinderUtil.Context
---@param allowReverse boolean allow reverse driving
---@param mustBeAccurate boolean must be accurately find the goal position/angle (optional)
function PathfinderUtil.startPathfinding(start, goal, context, allowReverse, mustBeAccurate)
    local pathfinder = HybridAStarWithAStarInTheMiddle(context.vehicleData.turnRadius * 3, 100, 50000, mustBeAccurate)
    local done, path, goalNodeInvalid = pathfinder:start(start, goal, context.vehicleData.turnRadius, context, allowReverse,
            PathfinderUtil.getNodePenalty, PathfinderUtil.isValidNode, PathfinderUtil.isValidAnalyticSolutionNode)
    return pathfinder, done, path, goalNodeInvalid
end

--- Interface function to start the pathfinder for a turn maneuver
---@param vehicle table
---@param startOffset number offset in meters relative to the vehicle position (forward positive, backward negative) where
--- we want the turn to start
---@param goalReferenceNode table node used to determine the goal
---@param goalOffset number offset in meters relative to the goal node (forward positive, backward negative)
--- Together with the goalReferenceNode defines the goal
---@param turnRadius number vehicle turning radius
---@param allowReverse boolean allow reverse driving
---@param course Course fieldwork course, needed to find the headland
---@param vehiclesToIgnore table[] list of vehicles to ignore for the collision detection
function PathfinderUtil.findPathForTurn(vehicle, startOffset, goalReferenceNode, goalOffset, turnRadius, allowReverse, course, vehiclesToIgnore)
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(vehicle), 0, startOffset or 0)
    local start = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    x, z, yRot = PathfinderUtil.getNodePositionAndDirection(goalReferenceNode, 0, goalOffset or 0)
    local goal = State3D(x, -z, courseGenerator.fromCpAngle(yRot))

    local pathfinder
    if course:getNumberOfHeadlands() > 0 then
        -- if there's a headland, we want to drive on the headland to the next row
        local headlandPath = PathfinderUtil.findShortestPathOnHeadland(start, goal, course, turnRadius)
        -- is the first wp of the headland in front of us?
        local _, y, _ = getWorldTranslation(AIDriverUtil.getDirectionNode(vehicle))
        local dx, _, dz = worldToLocal(AIDriverUtil.getDirectionNode(vehicle), headlandPath[1].x, y, - headlandPath[1].y)
        local dirDeg = math.deg(math.abs(math.atan2(dx, dz)))
        if dirDeg > 45 or true then
            courseGenerator.debug('First headland waypoint isn\'t in front of us (%.1f), remove first few waypoints to avoid making a circle %.1f %.1f', dirDeg, dx, dz)
        end
        pathfinder = HybridAStarWithPathInTheMiddle(turnRadius * 3, 200, headlandPath)
    else
        pathfinder = HybridAStarWithAStarInTheMiddle(turnRadius * 3, 200, 10000)
    end

    local fieldNum = courseplay.fields:onWhichFieldAmI(vehicle)
    local otherVehiclesCollisionData =PathfinderUtil.setUpVehicleCollisionData(vehicle, vehiclesToIgnore)
    local parameters = PathfinderUtil.Parameters(nil, vehicle.cp.settings.turnOnField:is(true) and 10 or nil, false)
    local context = PathfinderUtil.Context(
            PathfinderUtil.VehicleData(vehicle, true, 0.2),
            PathfinderUtil.FieldData(fieldNum),
            parameters,
            vehiclesToIgnore,
            otherVehiclesCollisionData)
    local done, path, goalNodeInvalid = pathfinder:start(start, goal, turnRadius, context, allowReverse, PathfinderUtil.getNodePenalty, PathfinderUtil.isValidNode, PathfinderUtil.isValidAnalyticSolutionNode)
    return pathfinder, done, path, goalNodeInvalid
end

--- Generate a Dubins path between the vehicle and the goal node
---@param vehicle table
---@param startOffset number offset in meters relative to the vehicle position (forward positive, backward negative) where
--- we want the turn to start
---@param goalReferenceNode table node used to determine the goal
---@param xOffset number offset in meters relative to the goal node (left positive, right negative)
---@param zOffset number offset in meters relative to the goal node (forward positive, backward negative)
--- Together with the goalReferenceNode defines the goal
---@param turnRadius number vehicle turning radius
function PathfinderUtil.findDubinsPath(vehicle, startOffset, goalReferenceNode, xOffset, zOffset, turnRadius)
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(vehicle), 0, startOffset or 0)
    local start = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    x, z, yRot = PathfinderUtil.getNodePositionAndDirection(goalReferenceNode, xOffset or 0, zOffset or 0)
    local goal = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    local solution = PathfinderUtil.dubinsSolver:solve(start, goal, turnRadius)
    local dubinsPath = solution:getWaypoints(start, turnRadius)
    return dubinsPath, solution:getLength(turnRadius)
end

function PathfinderUtil.getNodePositionAndDirection(node, xOffset, zOffset)
    local x, _, z = localToWorld(node, xOffset or 0, 0, zOffset or 0)
    local lx, _, lz = localDirectionToWorld(node, 0, 0, 1)
    local yRot = math.atan2(lx, lz)
    return x, z, yRot
end

--- Interface function to start the pathfinder in the game
---@param vehicle table, will be used as the start location/heading, turn radius and size
---@param goalWaypoint Waypoint The destination waypoint (x, z, angle)
---@param xOffset number side offset of the goal from the goalWaypoint
---@param zOffset number length offset of the goal from the goalWaypoint
---@param allowReverse boolean allow reverse driving
---@param fieldNum number if > 0, the pathfinding is restricted to the given field and its vicinity. Otherwise the
--- pathfinding considers any collision-free path valid, also outside of the field.
---@param vehiclesToIgnore table[] list of vehicles to ignore for the collision detection (optional)
---@param maxFruitPercent number maximum percentage of fruit present before a node is marked as invalid (optional)
function PathfinderUtil.startPathfindingFromVehicleToWaypoint(vehicle, goalWaypoint,
                                                              xOffset, zOffset, allowReverse,
                                                              fieldNum, vehiclesToIgnore, maxFruitPercent)
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(vehicle))
    local start = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    local goal = State3D(goalWaypoint.x, -goalWaypoint.z, courseGenerator.fromCpAngleDeg(goalWaypoint.angle))
    local offset = Vector(zOffset, -xOffset)
    goal:add(offset:rotate(goal.t))
    return PathfinderUtil.startPathfindingFromVehicleToGoal(vehicle, start, goal, allowReverse, fieldNum, vehiclesToIgnore, maxFruitPercent)
end

--- Interface function to start the pathfinder in the game. The goal is a point at sideOffset meters from the goal node
--- (sideOffset > 0 is left)
---@param vehicle table, will be used as the start location/heading, turn radius and size
---@param goalNode table The goal node
---@param xOffset number side offset of the goal from the goal node
---@param zOffset number length offset of the goal from the goal node
---@param allowReverse boolean allow reverse driving
---@param fieldNum number if other than 0 or nil the pathfinding is restricted to the given field and its vicinity
---@param vehiclesToIgnore table[] list of vehicles to ignore for the collision detection (optional)
---@param maxFruitPercent number maximum percentage of fruit present before a node is marked as invalid (optional)
---@param mustBeAccurate boolean must be accurately find the goal position/angle (optional)
function PathfinderUtil.startPathfindingFromVehicleToNode(vehicle, goalNode,
                                                          xOffset, zOffset, allowReverse,
                                                          fieldNum, vehiclesToIgnore, maxFruitPercent, offFieldPenalty,
                                                          mustBeAccurate)
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(vehicle))
    local start = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    x, z, yRot = PathfinderUtil.getNodePositionAndDirection(goalNode, xOffset, zOffset)
    local goal = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    return PathfinderUtil.startPathfindingFromVehicleToGoal(
            vehicle, start, goal, allowReverse, fieldNum,
            vehiclesToIgnore, maxFruitPercent, offFieldPenalty, mustBeAccurate)
end

function PathfinderUtil.startPathfindingFromVehicleToGoal(vehicle, start, goal,
                                                          allowReverse, fieldNum,
                                                          vehiclesToIgnore, maxFruitPercent, offFieldPenalty, mustBeAccurate)
    local otherVehiclesCollisionData = PathfinderUtil.setUpVehicleCollisionData(vehicle, vehiclesToIgnore)
    local parameters = PathfinderUtil.Parameters(maxFruitPercent or (vehicle.cp.settings.useRealisticDriving:is(true) and 50 or math.huge), offFieldPenalty or 1)
    local context = PathfinderUtil.Context(
            PathfinderUtil.VehicleData(vehicle, true, 0.2),
            PathfinderUtil.FieldData(fieldNum),
            parameters,
            vehiclesToIgnore,
            otherVehiclesCollisionData)
    return PathfinderUtil.startPathfinding(start, goal, context, allowReverse, mustBeAccurate)
end

function PathfinderUtil.toggleVisualDebug()
    PathfinderUtil.isVisualDebugEnabled = not PathfinderUtil.isVisualDebugEnabled
end

function PathfinderUtil.showNodes(pathfinder)
    if not PathfinderUtil.isVisualDebugEnabled then return end
    if pathfinder then
        local nodes
        if pathfinder.hybridAStarPathfinder and pathfinder.hybridAStarPathfinder.nodes then
            nodes = pathfinder.hybridAStarPathfinder.nodes
        elseif pathfinder.aStarPathfinder and pathfinder.aStarPathfinder.nodes then
            nodes = pathfinder.aStarPathfinder.nodes
        elseif pathfinder.nodes then
            nodes = pathfinder.nodes
        end
        if nodes then
            for _, row in pairs(nodes.nodes) do
                for _, column in pairs(row) do
                    for _, cell in pairs(column) do
                        if cell.x and cell.y then
                            local range = nodes.highestCost - nodes.lowestCost
                            local color = (cell.cost - nodes.lowestCost) * 250 / range
                            local r, g, b
                            if cell:isClosed() or true then
                                r, g, b = 100 + color, 250 - color, 0
                            else
                                r, g, b = cell.cost *3, 80, 0
                            end
                            local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cell.x, 0, -cell.y)
                            if cell.pred and cell.pred.y then
                                cpDebug:drawLineRGB(cell.x, y + 1, -cell.y, r, g, b, cell.pred.x, y + 1, -cell.pred.y)
                            end
                            if cell.isColliding then
                                cpDebug:drawPoint(cell.x, y + 1.2, -cell.y, 100, 0, 0)
                            end
                        end
                    end
                end
            end
        end
    end
    if pathfinder and pathfinder.middlePath then
        for i = 2, #pathfinder.middlePath do
            local cp = pathfinder.middlePath[i]
            -- an in-place conversion may have taken place already, make sure we have a valid z
            cp.z = cp.y and -cp.y or cp.z
            local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cp.x, 0, cp.z)
            local pp = pathfinder.middlePath[i - 1]
            pp.z = pp.y and -pp.y or pp.z
            local py = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pp.x, 0, pp.z)
            cpDebug:drawLine(cp.x, cy + 3, cp.z, 10, 0, 0, pp.x, py + 3, pp.z)
        end
    end
    if PathfinderUtil.helperNode then
        DebugUtil.drawDebugNode(PathfinderUtil.helperNode, 'Pathfinder')
    end
    if myCollisionData then
        for i = 1, 4 do
            local cp = myCollisionData.corners[i]
            local pp = myCollisionData.corners[i > 1 and i - 1 or 4]
            cpDebug:drawLine(cp.x, cp.y + 0.4, cp.z, 1, 1, 0, pp.x, pp.y + 0.4, pp.z)
        end
    end
    if PathfinderUtil.vehicleCollisionData then
        for _, collisionData in pairs(PathfinderUtil.vehicleCollisionData) do
            for i = 1, 4 do
                local cp = collisionData.corners[i]
                local pp = collisionData.corners[i > 1 and i - 1 or 4]
                cpDebug:drawLine(cp.x, cp.y + 0.4, cp.z, 1, 1, 0, pp.x, pp.y + 0.4, pp.z)
            end
        end
    end
end

function PathfinderUtil.getFieldIdAtWorldPosition(posX, posZ)
    local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
    if farmland ~= nil then
        local fieldMapping = g_fieldManager.farmlandIdFieldMapping[farmland.id]
        if fieldMapping ~= nil and fieldMapping[1] ~= nil then
            return fieldMapping[1].fieldId
        end
    end
    return 0
end