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

PathfinderUtil.defaultOffFieldPenalty = 7.5
PathfinderUtil.visualDebugLevel = 0

---Size/turn radius all other information on the vehicle and its implements
---@class PathfinderUtil.VehicleData
PathfinderUtil.VehicleData = CpObject()

--- VehicleData is used to perform a hierarchical collision detection. The vehicle's bounding box
--- includes all implements and checked first for collisions. If there is a hit, the individual parts
--- (vehicle and implements) are each checked for collision. This is to avoid false alarms in case of
--- non-rectangular shapes, like a combine with a wide header
--- If the vehicle has a trailer, it is handled separately from other implements to allow for the
--- pathfinding to consider the trailer's heading (which will be different from the vehicle's heading)
function PathfinderUtil.VehicleData:init(vehicle, withImplements, buffer)
    self.vehicle = vehicle
    self.rootVehicle = vehicle:getRootVehicle()
    self.name = vehicle.getName and vehicle:getName() or 'N/A'
    -- distance of the sides of a rectangle from the root node of the vehicle
    -- in other words, the X and Z offsets of the corners from the root node
    -- negative is to the rear and to the right
    -- this is the bounding box of the entire vehicle with all attached implements,
    -- except a towed trailer as that is calculated independently
    self.dFront, self.dRear, self.dLeft, self.dRight = 0, 0, 0, 0
    self.rectangles = {}
    self:calculateSizeOfObjectList(vehicle, {{object = vehicle}}, buffer, self.rectangles)
    -- we'll calculate the trailer's precise position an angle for the collision detection to not hit obstacles
    -- while turning. Get that object here, there may be more but we ignore that case.
    self.trailer = courseplay:getFirstReversingWheeledWorkTool(vehicle)
    if self.trailer then
        -- the trailer's heading is different than the vehicle's heading and will be calculated and
        -- checked for collision independently at each waypoint. Also, the trailer is rotated to its heading
        -- around the hitch (which we approximate as the front side of the size rectangle), not around the root node
        self.trailerRectangle = {
            name = self.trailer:getName(),
            vehicle = self.trailer,
            rootVehicle = self.trailer:getRootVehicle(),
            dFront = buffer or 0,
            dRear = - self.trailer.sizeLength - (buffer or 0),
            dLeft = self.trailer.sizeWidth / 2,
            dRight = -self.trailer.sizeWidth / 2
        }
				local inputAttacherJoint = self.trailer:getActiveInputAttacherJoint()
				if inputAttacherJoint then
						local _, _, dz = localToLocal(inputAttacherJoint.node, AIDriverUtil.getDirectionNode(vehicle), 0, 0, 0)
						self.trailerHitchOffset = dz
				else
						self.trailerHitchOffset = self.dRear
				end
    		courseplay.debugVehicle(courseplay.DBG_PATHFINDER, vehicle, 'trailer for the pathfinding is %s, hitch offset is %.1f',
                self.trailer:getName(), self.trailerHitchOffset)
    end
    if withImplements then
        self:calculateSizeOfObjectList(vehicle, vehicle:getAttachedImplements(), buffer, self.rectangles)
    end
end

--- Calculate the relative coordinates of a rectangle's corners around a reference node, representing the implement
function PathfinderUtil.VehicleData:getRectangleForImplement(implement, referenceNode, buffer)
    local rootToReferenceNodeOffset = 0
    local attacherJoint = implement.object.getActiveInputAttacherJoint and implement.object:getActiveInputAttacherJoint()
    if attacherJoint and attacherJoint.node then
        -- the implement may not be aligned with the vehicle so we need to calculate this distance in two
        -- steps, first the distance between the vehicle's root node and the attacher joint and then
        -- from the attacher joint to the implement's root node
        -- < 0 when the attacher joint is behind the reference node
        local _, _, referenceToAttacherJoint = localToLocal(attacherJoint.node, referenceNode, 0, 0, 0)
        -- > 0 when the attacher node is in front of the implement's root node (we don't use the attacher joint node
        -- as a reference as it may point to any direction, we know the implement's root node points forward
        local _, _, attacherJointToImplementRoot = localToLocal(attacherJoint.node, implement.object.rootNode, 0, 0, 0)
        -- we call this offset, and is negative when behind the reference node, positive when in front of it
        -- (need to reverse attacherJointToImplementRoot)
        rootToReferenceNodeOffset = - attacherJointToImplementRoot + referenceToAttacherJoint
        courseplay.debugFormat(courseplay.DBG_PATHFINDER, '%s: ref to attacher joint %.1f, att to implement root %.1f, impl root to ref %.1f',
            nameNum(implement.object), referenceToAttacherJoint, attacherJointToImplementRoot, rootToReferenceNodeOffset)
    else
        _, _, rootToReferenceNodeOffset = localToLocal(implement.object.rootNode, referenceNode, 0, 0, 0)
    end
    -- default size, used by Giants to determine the drop area when buying something
    local rectangle = {
        dFront = rootToReferenceNodeOffset + implement.object.sizeLength / 2 + implement.object.lengthOffset + (buffer or 0),
        dRear = rootToReferenceNodeOffset - implement.object.sizeLength / 2 + implement.object.lengthOffset - (buffer or 0),
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
    return rectangle
end

--- calculate the bounding box of all objects in the implement list. This is not a very good way to figure out how
--- big a vehicle is as the sizes of foldable implements seem to be in the folded state but should be ok for
--- now.
function PathfinderUtil.VehicleData:calculateSizeOfObjectList(vehicle, implements, buffer, rectangles)
    for _, implement in ipairs(implements) do
        --print(implement.object:getName())
        local referenceNode = AIDriverUtil.getDirectionNode(vehicle) --vehicle.rootNode
        if implement.object ~= self.trailer then
            -- everything else is attached to the root vehicle and calculated as it was moving with it (having
            -- the same heading)
            local rectangle = self:getRectangleForImplement(implement, referenceNode, buffer)
            table.insert(rectangles, rectangle)
            self.dFront = math.max(self.dFront, rectangle.dFront)
            self.dRear  = math.min(self.dRear,  rectangle.dRear)
            self.dLeft  = math.max(self.dLeft,  rectangle.dLeft)
            self.dRight = math.min(self.dRight, rectangle.dRight)
        end
    end
    --courseplay.debugVehicle(courseplay.DBG_PATHFINDER, vehicle, 'Size: dFront %.1f, dRear %.1f, dLeft = %.1f, dRight = %.1f',
    --        self.dFront, self.dRear, self.dLeft, self.dRight)
end

--- Is this position on a field (any field)?
function PathfinderUtil.isPosOnField(x, y, z)
    if not y then
        _, y, _ = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
    end
    local densityBits = 0
    local bits = getDensityAtWorldPos(g_currentMission.terrainDetailId, x, y, z)
    densityBits = bitOR(densityBits, bits)
    return densityBits ~= 0
end

--- Is this node on a field (any field)?
---@param node table Giants engine node
function PathfinderUtil.isNodeOnField(node)
    local x, y, z = getWorldTranslation(node)
    return PathfinderUtil.isPosOnField(x, y, z)
end

--- Which field this node is on.
---@param node table Giants engine node
---@return number 0 if not on any field, otherwise the number of field, see note on getFieldItAtWorldPosition()
function PathfinderUtil.getFieldNumUnderNode(node)
    local x, _, z = getWorldTranslation(node)
    return PathfinderUtil.getFieldIdAtWorldPosition(x, z)
end

--- Which field this node is on. See above for more info
function PathfinderUtil.getFieldNumUnderVehicle(vehicle)
    return PathfinderUtil.getFieldNumUnderNode(vehicle.rootNode)
end

--- Returns the field ID (actually, land ID) for a position. The land is what you can buy in the game,
--- including the area around an actual field.
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

--- Is the land at this position owned by me?
function PathfinderUtil.isWorldPositionOwned(posX, posZ)
	local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
	local missionAllowed = g_missionManager:getIsMissionWorkAllowed(g_currentMission.player.farmId, posX, posZ, nil)
	return (farmland and farmland.isOwned) or missionAllowed
end

--- Pathfinder context
---@class PathfinderUtil.Context
PathfinderUtil.Context = CpObject()
function PathfinderUtil.Context:init(vehicle, vehiclesToIgnore)
    self.vehicleData = PathfinderUtil.VehicleData(vehicle, true, 0.5)
	self.trailerHitchLength = AIDriverUtil.getTowBarLength(vehicle)
	self.turnRadius = vehicle.cp and vehicle.cp.driver and AIDriverUtil.getTurningRadius(vehicle) or 10
	self.vehiclesToIgnore = vehiclesToIgnore
end

--- Calculate the four corners of a rectangle around a node (for example the area covered by a vehicle)
--- the data returned by this is the rectangle from the vehicle data translated and rotated to the node
function PathfinderUtil.getBoundingBoxInWorldCoordinates(node, vehicleData)
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

--- Place node on a world position, point it to the heading and set the rotation so the y axis is parallel
--- to the terrain normal vector. In other words, set the location and rotation of this node as if it was the
--- root node of a vehicle at that position, the vehicle's chassis parallel to the terrain
---@param node number
---@param x number
---@param z number
---@param heading number heading as y rotation
---@param yOffset number position offset above ground
function PathfinderUtil.setWorldPositionAndRotationOnTerrain(node, x, z, heading, yOffset)
		local xRot, yRot, zRot = PathfinderUtil.getNormalWorldRotation(x, z)
		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z);

		setTranslation(node, x, y + yOffset, z)
		setRotation(node, xRot, 0, zRot)
		xRot, yRot, zRot = localRotationToWorld(node, 0, heading, 0)
		setRotation(node, xRot, yRot, zRot)
end

--- Get the world rotation of a node at x, z when the y axis is parallel to the normal vector at that position
--- (y axis is perpendicular to the terrain)
function PathfinderUtil.getNormalWorldRotation(x, z)
		local nx, ny, nz = getTerrainNormalAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)

		local xRot = MathUtil.getYRotationFromDirection(nz, ny)
		local yRot = MathUtil.getYRotationFromDirection(nx, nz)
		local zRot = -MathUtil.getYRotationFromDirection(nx, ny)

		return xRot, yRot, zRot
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
        if rootVehicle == self.vehicleData.rootVehicle or
                PathfinderUtil.elementOf(self.vehiclesToIgnore, rootVehicle) then
            -- just bumped into myself or a vehicle we want to ignore
            return
        end
        --courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'collision: %s', collidingObject:getName())
    end
   	if not getHasClassId(transformId, ClassIds.TERRAIN_TRANSFORM_GROUP) then
        local text = ''
        for key, classId in pairs(ClassIds) do
            if getHasClassId(transformId, classId) then
                text = text .. ' ' .. key
            end
        end
				self.collidingShapesText = text
        self.collidingShapes = self.collidingShapes + 1
    end
end

function PathfinderUtil.CollisionDetector:findCollidingShapes(node, vehicleData, vehiclesToIgnore, log)
    self.vehiclesToIgnore = vehiclesToIgnore or {}
    self.vehicleData = vehicleData
    -- the box for overlapBox() is symmetric, so if our root node is not in the middle of the vehicle rectangle,
    -- we have to translate it into the middle
    -- right/rear is negative
    local width = (math.abs(vehicleData.dRight) + math.abs(vehicleData.dLeft)) / 2
    local length = (math.abs(vehicleData.dFront) + math.abs(vehicleData.dRear)) / 2
	local zOffset = vehicleData.dFront - length
	local xOffset = vehicleData.dLeft - width

    local xRot, yRot, zRot = getWorldRotation(node)
    local x, y, z = localToWorld(node, xOffset, 1, zOffset)

    self.collidingShapes = 0
		self.collidingShapesText = 'unknown'

    overlapBox(x, y + 0.2, z, xRot, yRot, zRot, width, 1, length, 'overlapBoxCallback', self, bitOR(AIVehicleUtil.COLLISION_MASK, 2), true, true, true)
    if log and self.collidingShapes > 0 then
        table.insert(PathfinderUtil.overlapBoxes,
                { x = x, y = y + 0.2, z = z, xRot = xRot, yRot = yRot, zRot = zRot, width = width, length = length})
        courseplay.debugFormat(courseplay.DBG_PATHFINDER,
					'pathfinder colliding shapes %s with %s at x = %.1f, z = %.1f, (%.1fx%.1f), yRot = %d',
					self.collidingShapesText, vehicleData.name, x, z, width, length, math.deg(yRot))
    end
    DebugUtil.drawOverlapBox(x, y, z, xRot, yRot, zRot, width, 1, length, 100, 0, 0)

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
            --if g_updateLoopIndex % 200 == 0 then
                --courseplay.debugFormat(courseplay.DBG_PATHFINDER, '%.1f, %s, %s, %s %s', fruitValue, tostring(a), tostring(b), tostring(c), g_fruitTypeManager:getFruitTypeByIndex(fruitType.index).name)
            --end
            if fruitValue > 0 then
                return true, fruitValue, g_fruitTypeManager:getFruitTypeByIndex(fruitType.index).name
            end
        end
    end
    return false
end


--[[
Pathfinding is controlled by the constraints (validity and penalty) below. The pathfinder will call these functions
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

---@class PathfinderConstraints : PathfinderConstraintInterface
PathfinderConstraints = CpObject(PathfinderConstraintInterface)

function PathfinderConstraints:init(context, maxFruitPercent, offFieldPenalty, fieldNum)
    self.context = context
    self.maxFruitPercent = maxFruitPercent or 50
    self.offFieldPenalty = offFieldPenalty or PathfinderUtil.defaultOffFieldPenalty
    self.fieldNum = fieldNum or 0
    self.initialMaxFruitPercent = self.maxFruitPercent
    self.initialOffFieldPenalty = self.offFieldPenalty
    self:resetCounts()
    courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'Pathfinder constraints: off field penalty %.1f, max fruit percent: %d, field number %d',
        self.offFieldPenalty, self.maxFruitPercent, self.fieldNum)
end

function PathfinderConstraints:resetCounts()
    self.totalNodeCount = 0
    self.fruitPenaltyNodeCount = 0
    self.offFieldPenaltyNodeCount = 0
    self.collisionNodeCount = 0
end

--- Calculate penalty for this node. The penalty will be added to the cost of the node. This allows for
--- obstacle avoidance or forcing the search to remain in certain areas.
---@param node State3D
function PathfinderConstraints:getNodePenalty(node)
    -- tweak these two parameters to set up how far the path will be from the field or fruit boundary
    -- size of the area to check for field/fruit
    local areaSize = 3
    -- minimum ratio of the area checked must be on field/clear of fruit
    local minRequiredAreaRatio = 0.8
    local penalty = 0
    local isField, area, totalArea = courseplay:isField(node.x, -node.y, areaSize, areaSize)
    -- not on any field
    local offFieldPenalty = self.offFieldPenalty
    local offField = area / totalArea < minRequiredAreaRatio
    if self.fieldNum ~= 0 and not offField then
        -- if there's a preferred field and we are on a field
        if not PathfinderUtil.isWorldPositionOwned(node.x, -node.y) then
            -- the field we are on is not ours, more penalty!
            offField = true
            offFieldPenalty = self.offFieldPenalty * 1.2
        end
    end
    if offField then
        penalty = penalty + offFieldPenalty
        self.offFieldPenaltyNodeCount = self.offFieldPenaltyNodeCount + 1
        node.offField = true
    end
    --local fieldId = PathfinderUtil.getFieldIdAtWorldPosition(node.x, -node.y)
    if isField then
        local hasFruit, fruitValue = PathfinderUtil.hasFruit(node.x, -node.y, areaSize, areaSize)
        if hasFruit and fruitValue > self.maxFruitPercent then
            penalty = penalty + fruitValue / 2
            self.fruitPenaltyNodeCount = self.fruitPenaltyNodeCount + 1
        end
    end
    self.totalNodeCount = self.totalNodeCount + 1
    return penalty
end

--- When the pathfinder tries an analytic solution for the entire path from start to goal, we can't use node penalties
--- to find the optimum path, avoiding fruit. Instead, we just check for collisions with vehicles and objects as
--- usual and also mark anything overlapping fruit as invalid. This way a path will only be considered if it is not
--- in the fruit.
--- However, we are more relaxed here and allow the double amount of fruit as being too restrictive here means
--- that analytic paths are almost always invalid when they go near the fruit. Since analytic paths are only at the
--- beginning at the end of the course and mostly curves, it is no problem getting closer to the fruit than otherwise
function PathfinderConstraints:isValidAnalyticSolutionNode(node, log)
    local hasFruit, fruitValue = PathfinderUtil.hasFruit(node.x, -node.y, 3, 3)
    local analyticLimit = self.maxFruitPercent * 2
    if hasFruit and fruitValue > analyticLimit then
        if log then
            courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'isValidAnalyticSolutionNode: fruitValue %.1f, max %.1f @ %.1f, %.1f',
                    fruitValue, analyticLimit, node.x, -node.y)
        end
        return false
    end
    return self:isValidNode(node, log)
end

-- A helper node to calculate world coordinates
local function ensureHelperNode()
		if not PathfinderUtil.helperNode then
				PathfinderUtil.helperNode = courseplay.createNode('pathfinderHelper', 0, 0, 0)
		end
end

--- Check if node is valid: would we collide with another vehicle or shape here?
---@param node State3D
---@param log boolean log colliding shapes/vehicles
---@param ignoreTrailer boolean don't check the trailer
function PathfinderConstraints:isValidNode(node, log, ignoreTrailer)
		ensureHelperNode()
		PathfinderUtil.setWorldPositionAndRotationOnTerrain(PathfinderUtil.helperNode,
			node.x, -node.y, courseGenerator.toCpAngle(node.t), 0.5)

    -- check the vehicle and all implements attached to it except a trailer or towed implement
    local myCollisionData = PathfinderUtil.getBoundingBoxInWorldCoordinates(PathfinderUtil.helperNode, self.context.vehicleData, 'me')
    -- for debug purposes only, store validity info on node
    node.collidingShapes = PathfinderUtil.collisionDetector:findCollidingShapes(
            PathfinderUtil.helperNode, self.context.vehicleData, self.context.vehiclesToIgnore, log)
    if self.context.vehicleData.trailer and not ignoreTrailer then
        -- now check the trailer or towed implement
        -- move the node to the rear of the vehicle (where approximately the trailer is attached)
        local x, y, z = localToWorld(PathfinderUtil.helperNode, 0, 0, self.context.vehicleData.trailerHitchOffset)

				PathfinderUtil.setWorldPositionAndRotationOnTerrain(PathfinderUtil.helperNode, x, z,
					courseGenerator.toCpAngle(node.tTrailer), 0.5)

        node.collidingShapes = node.collidingShapes + PathfinderUtil.collisionDetector:findCollidingShapes(
                PathfinderUtil.helperNode, self.context.vehicleData.trailerRectangle, self.context.vehiclesToIgnore, log)
    end
    local isValid = node.collidingShapes == 0
    if not isValid then
        self.collisionNodeCount = self.collisionNodeCount + 1
    end
    return isValid
end

function PathfinderConstraints:relaxConstraints()
    self:showStatistics()
    courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'relaxing pathfinder constraints: allow driving through fruit')
    self.maxFruitPercent = math.huge
    self:resetCounts()
end

function PathfinderConstraints:showStatistics()
    courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'Nodes: %d, Penalties: fruit: %d, off-field: %d, collisions: %d',
            self.totalNodeCount, self.fruitPenaltyNodeCount, self.offFieldPenaltyNodeCount, self.collisionNodeCount)
    courseplay.debugFormat(courseplay.DBG_PATHFINDER, '  max fruit %.1f %%, off-field penalty: %.1f',
            self.maxFruitPercent, self.offFieldPenalty)
end

function PathfinderConstraints:resetConstraints()
    courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'resetting pathfinder constraints: maximum fruit percent allowed is now %d',
            self.initialMaxFruitPercent)
    self.maxFruitPercent = self.initialMaxFruitPercent
    self:resetCounts()
end

---@param start State3D
---@param vehicleData PathfinderUtil.VehicleData
function PathfinderUtil.initializeTrailerHeading(start, vehicleData)
    -- initialize the trailer's heading for the starting point
    if vehicleData.trailer then
        local _, _, yRot = PathfinderUtil.getNodePositionAndDirection(vehicleData.trailer.rootNode, 0, 0)
        start:setTrailerHeading(courseGenerator.fromCpAngle(yRot))
    end
end

---@param start State3D
---@param goal State3D
function PathfinderUtil.startPathfindingFromVehicleToGoal(vehicle, goal,
                                                          allowReverse, fieldNum,
                                                          vehiclesToIgnore, maxFruitPercent, offFieldPenalty, mustBeAccurate)

		local start = PathfinderUtil.getVehiclePositionAsState3D(vehicle)

    local vehicleData = PathfinderUtil.VehicleData(vehicle, true, 0.5)

		PathfinderUtil.initializeTrailerHeading(start, vehicleData)

    local context = PathfinderUtil.Context(vehicle, vehiclesToIgnore)

    local constraints = PathfinderConstraints(context,
            maxFruitPercent or (vehicle.cp.settings.useRealisticDriving:is(true) and 50 or math.huge),
            offFieldPenalty or PathfinderUtil.defaultOffFieldPenalty,
            fieldNum)

    return PathfinderUtil.startPathfinding(start, goal, context, constraints, allowReverse, mustBeAccurate)
end

---@param course Course
---@return Polygon outermost headland as a  polygon (x, y)
local function getOutermostHeadland(course)
    local headland = Polygon:new()
    for i = 1, course:getNumberOfWaypoints() do
        if course:isOnOutermostHeadland(i) then
            local x, y, z = course:getWaypointPosition(i)
            headland:add({x = x, y = -z})
        end
    end
    return headland
end

---@param start State3D
---@param goal State3D
---@param course Course
---@param turnRadius number
---@return State3D[]
local function findShortestPathOnHeadland(start, goal, course, turnRadius)
    -- to be able to use the existing getSectionBetweenPoints, we first create a Polyline[], then construct a State3D[]
    local headland = getOutermostHeadland(course)
    headland:calculateData()
    local path = {}
    for _, p in ipairs(headland:getSectionBetweenPoints(start, goal)) do
        --courseGenerator.debug('%.1f %.1f', p.x, p.y)
        table.insert(path, State3D(p.x, p.y, 0))
    end
    return path
end

------------------------------------------------------------------------------------------------------------------------
--- Interface function to start the pathfinder
------------------------------------------------------------------------------------------------------------------------
---@param start State3D start node
---@param goal State3D goal node
---@param context PathfinderUtil.Context
---@param constraints PathfinderConstraints
---@param allowReverse boolean allow reverse driving
---@param mustBeAccurate boolean must be accurately find the goal position/angle (optional)
function PathfinderUtil.startPathfinding(start, goal, context, constraints, allowReverse, mustBeAccurate)
    PathfinderUtil.overlapBoxes = {}
    local pathfinder = HybridAStarWithAStarInTheMiddle(context.turnRadius * 4, 100, 40000, mustBeAccurate)
    local done, path, goalNodeInvalid = pathfinder:start(start, goal, context.turnRadius, allowReverse,
            constraints, context.trailerHitchLength)
    return pathfinder, done, path, goalNodeInvalid
end

------------------------------------------------------------------------------------------------------------------------
--- Interface function to start the pathfinder for a turn maneuver
------------------------------------------------------------------------------------------------------------------------
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
        local headlandPath = findShortestPathOnHeadland(start, goal, course, turnRadius)
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

    local fieldNum = PathfinderUtil.getFieldNumUnderVehicle(vehicle)
    local context = PathfinderUtil.Context(
            vehicle,
            vehiclesToIgnore)
    local constraints = PathfinderConstraints(context, nil, vehicle.cp.settings.turnOnField:is(true) and 10 or nil, fieldNum)
    local done, path, goalNodeInvalid = pathfinder:start(start, goal, turnRadius, allowReverse,
            constraints, context.trailerHitchLength)
    return pathfinder, done, path, goalNodeInvalid
end

------------------------------------------------------------------------------------------------------------------------
--- Generate a Dubins path between the vehicle and the goal node
------------------------------------------------------------------------------------------------------------------------
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

---@param vehicle Vehicle
---@return State3D position/heading of vehicle
function PathfinderUtil.getVehiclePositionAsState3D(vehicle)
		local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(vehicle))
		return State3D(x, -z, courseGenerator.fromCpAngle(yRot))
end

------------------------------------------------------------------------------------------------------------------------
--- Interface function to start the pathfinder in the game
------------------------------------------------------------------------------------------------------------------------
---@param vehicle table, will be used as the start location/heading, turn radius and size
---@param goalWaypoint Waypoint The destination waypoint (x, z, angle)
---@param xOffset number side offset of the goal from the goalWaypoint
---@param zOffset number length offset of the goal from the goalWaypoint
---@param allowReverse boolean allow reverse driving
---@param fieldNum number if > 0, the pathfinding is restricted to the given field and its vicinity. Otherwise the
--- pathfinding considers any collision-free path valid, also outside of the field.
---@param vehiclesToIgnore table[] list of vehicles to ignore for the collision detection (optional)
---@param maxFruitPercent number maximum percentage of fruit present before a node is marked as invalid (optional)
---@param offFieldPenalty number penalty to apply to nodes off the field
function PathfinderUtil.startPathfindingFromVehicleToWaypoint(vehicle, goalWaypoint,
                                                              xOffset, zOffset, allowReverse,
                                                              fieldNum, vehiclesToIgnore, maxFruitPercent, offFieldPenalty)

    local goal = State3D(goalWaypoint.x, -goalWaypoint.z, courseGenerator.fromCpAngleDeg(goalWaypoint.angle))
    local offset = Vector(zOffset, -xOffset)
    goal:add(offset:rotate(goal.t))
    return PathfinderUtil.startPathfindingFromVehicleToGoal(
            vehicle, goal, allowReverse, fieldNum, vehiclesToIgnore, maxFruitPercent, offFieldPenalty)
end
------------------------------------------------------------------------------------------------------------------------
--- Interface function to start the pathfinder in the game. The goal is a point at sideOffset meters from the goal node
--- (sideOffset > 0 is left)
------------------------------------------------------------------------------------------------------------------------
---@param vehicle table, will be used as the start location/heading, turn radius and size
---@param goalNode table The goal node
---@param xOffset number side offset of the goal from the goal node
---@param zOffset number length offset of the goal from the goal node
---@param allowReverse boolean allow reverse driving
---@param fieldNum number if other than 0 or nil the pathfinding is restricted to the given field and its vicinity
---@param vehiclesToIgnore table[] list of vehicles to ignore for the collision detection (optional)
---@param maxFruitPercent number maximum percentage of fruit present before a node is marked as invalid (optional)
---@param offFieldPenalty number penalty to apply to nodes off the field
---@param mustBeAccurate boolean must be accurately find the goal position/angle (optional)
function PathfinderUtil.startPathfindingFromVehicleToNode(vehicle, goalNode,
                                                          xOffset, zOffset, allowReverse,
                                                          fieldNum, vehiclesToIgnore, maxFruitPercent, offFieldPenalty,
                                                          mustBeAccurate)
    x, z, yRot = PathfinderUtil.getNodePositionAndDirection(goalNode, xOffset, zOffset)
    local goal = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    return PathfinderUtil.startPathfindingFromVehicleToGoal(
            vehicle, goal, allowReverse, fieldNum,
            vehiclesToIgnore, maxFruitPercent, offFieldPenalty, mustBeAccurate)
end

------------------------------------------------------------------------------------------------------------------------
--- Interface function to start a simple A* pathfinder in the game. The goal is a node
------------------------------------------------------------------------------------------------------------------------
---@param vehicle table, will be used as the start location/heading, turn radius and size
---@param goalNode table The goal node
---@param xOffset number side offset of the goal from the goal node (> 0 is left)
---@param zOffset number length offset of the goal from the goal node (> 0 is front)
---@param fieldNum number if other than 0 or nil the pathfinding is restricted to the given field and its vicinity
---@param vehiclesToIgnore table[] list of vehicles to ignore for the collision detection (optional)
---@param maxFruitPercent number maximum percentage of fruit present before a node is marked as invalid (optional)
function PathfinderUtil.startAStarPathfindingFromVehicleToNode(vehicle, goalNode,
                                                          xOffset, zOffset,
                                                          fieldNum, vehiclesToIgnore, maxFruitPercent)
    local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(vehicle))
    local start = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
    x, z, yRot = PathfinderUtil.getNodePositionAndDirection(goalNode, xOffset, zOffset)
    local goal = State3D(x, -z, courseGenerator.fromCpAngle(yRot))

    local vehicleData = PathfinderUtil.VehicleData(vehicle, true, 0.5)

		PathfinderUtil.initializeTrailerHeading(start, vehicleData)

    local context = PathfinderUtil.Context(vehicle, vehiclesToIgnore)

    local constraints = PathfinderConstraints(context,
            maxFruitPercent or (vehicle.cp.settings.useRealisticDriving:is(true) and 50 or math.huge),
            PathfinderUtil.defaultOffFieldPenalty,
            fieldNum)

    local pathfinder = AStar(100, 10000)
    local done, path, goalNodeInvalid = pathfinder:start(start, goal, context.turnRadius, false,
            constraints, context.trailerHitchLength)
    return pathfinder, done, path, goalNodeInvalid
end

------------------------------------------------------------------------------------------------------------------------
--- Is an obstacle in front of the vehicle?
-- Create three short Dubins paths, a 90 degree turn to the left, one to the right and one straight ahead.
-- (straight ahead does not have to be Dubins, but whatever...)
-- Then check all three for collisions with obstacles.
---@return boolean, boolean, boolean true if no obstacles left, right, straight ahead
------------------------------------------------------------------------------------------------------------------------
function PathfinderUtil.checkForObstaclesAhead(vehicle, turnRadius)

	local function isValidPath(constraints, path)
		for i, node in ipairs(path) do
			if not constraints:isValidNode(node, false, false) then
				return false
			end
		end
		return true
	end

	local function findPath(start, hitchLength, xOffset, zOffset)
		local x, y, z = localToWorld(AIDriverUtil.getDirectionNode(vehicle), xOffset, 0, zOffset)
		setTranslation(PathfinderUtil.helperNode, x, y, z)
		local dx, dy, dz = localDirectionToWorld(AIDriverUtil.getDirectionNode(vehicle), xOffset, 0, xOffset == 0 and 1 or 0)
		local yRot = MathUtil.getYRotationFromDirection(dx, dz)
		setRotation(PathfinderUtil.helperNode, 0, yRot, 0)
		local path, len = PathfinderUtil.findDubinsPath(vehicle, 0, PathfinderUtil.helperNode, 0, 0, turnRadius)
		-- making sure we continue with the correct trailer heading
		path[1]:setTrailerHeading(start:getTrailerHeading())
		State3D.calculateTrailerHeadings(path, hitchLength)
		return path
	end

	PathfinderUtil.overlapBoxes = {}
	local start = PathfinderUtil.getVehiclePositionAsState3D(vehicle)
	local vehicleData = PathfinderUtil.VehicleData(vehicle, true, 0.5)
	PathfinderUtil.initializeTrailerHeading(start, vehicleData)
	local context = PathfinderUtil.Context(vehicle, {})
	local constraints = PathfinderConstraints(context, math.huge, 0, 0)
	ensureHelperNode()

	-- quarter circle to left
	local path
	-- make sure Dubins can reach every target with a 90 degree turn (and not a 270)
	local safeTurnRadius = 1.1 * turnRadius
	path = findPath(start, context.trailerHitchLength, safeTurnRadius, safeTurnRadius)
	local leftOk = isValidPath(constraints, path)
	path = findPath(start, context.trailerHitchLength,-safeTurnRadius, safeTurnRadius)
	local rightOk = isValidPath(constraints, path)
	path = findPath(start, context.trailerHitchLength, 0, safeTurnRadius)
	local straightOk = isValidPath(constraints, path)
	courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'Obstacle check: left ok: %s, right ok: %s, straight ok %s',
		tostring(leftOk), tostring(rightOk), tostring(straightOk))
	return leftOk, rightOk, straightOk
end


------------------------------------------------------------------------------------------------------------------------
-- Debug stuff
---------------------------------------------------------------------------------------------------------------------------
function PathfinderUtil.setVisualDebug(d)
    PathfinderUtil.visualDebugLevel = d
end

function PathfinderUtil.showNodes(pathfinder)
    if PathfinderUtil.visualDebugLevel < 1 then return end
    if pathfinder then
        local nodes
        if PathfinderUtil.visualDebugLevel > 1 and
                pathfinder.hybridAStarPathfinder and pathfinder.hybridAStarPathfinder.nodes then
            nodes = pathfinder.hybridAStarPathfinder.nodes
        elseif PathfinderUtil.visualDebugLevel > 0 and pathfinder.aStarPathfinder and pathfinder.aStarPathfinder.nodes then
            nodes = pathfinder.aStarPathfinder.nodes
        elseif PathfinderUtil.visualDebugLevel > 0 and pathfinder.nodes then
            nodes = pathfinder.nodes
        end
        if nodes then
            for _, row in pairs(nodes.nodes) do
                for _, column in pairs(row) do
                    for _, cell in pairs(column) do
                        if cell.x and cell.y then
                            local range = nodes.highestCost - nodes.lowestCost
                            local color = (cell.cost - nodes.lowestCost) / range
                            local r, g, b
                            if cell.offField then
                                r, g, b = 250 * color, 250 - 250 * color, 0
                            else
                                r, g, b = color, 1 - color, 0
                            end
                            local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cell.x, 0, -cell.y)
                            cpDebug:drawPoint(cell.x, y + 1, -cell.y, r, g, b)
                            if cell.pred and cell.pred.y then
--                                cpDebug:drawLineRGB(cell.x, y + 1 + height, -cell.y, r, g, b, cell.pred.x, y + 1 + height, -cell.pred.y)
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

function PathfinderUtil.showOverlapBoxes()
    if not PathfinderUtil.overlapBoxes then return end
    for _, box in ipairs(PathfinderUtil.overlapBoxes) do
        DebugUtil.drawOverlapBox(box.x, box.y, box.z, box.xRot, box.yRot, box.zRot, box.width, 1, box.length, 0, 100, 0)
    end
end