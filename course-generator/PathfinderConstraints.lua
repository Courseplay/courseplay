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

function PathfinderConstraints:init(context, maxFruitPercent, offFieldPenalty, fieldNum, areaToAvoid)
	self.context = context
	self.maxFruitPercent = maxFruitPercent or 50
	self.offFieldPenalty = offFieldPenalty or PathfinderUtil.defaultOffFieldPenalty
	self.fieldNum = fieldNum or 0
	self.areaToAvoid = areaToAvoid
	self.areaToAvoidPenaltyCount = 0
	self.initialMaxFruitPercent = self.maxFruitPercent
	self.initialOffFieldPenalty = self.offFieldPenalty
	self.hybridVehicleData = context.vehicleData
	self:resetCounts()
	local areaText = self.areaToAvoid and
		string.format('%.1f x %.1f m', self.areaToAvoid.length, self.areaToAvoid.width) or 'none'
	courseplay.debugFormat(courseplay.DBG_PATHFINDER,
		'Pathfinder constraints: off field penalty %.1f, max fruit percent: %d, field number %d, area to avoid %s',
		self.offFieldPenalty, self.maxFruitPercent, self.fieldNum, areaText)
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
	local areaSize = 4
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
			offFieldPenalty = offFieldPenalty * 1.2
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
	if self.areaToAvoid and self.areaToAvoid:contains(node.x, -node.y) then
		penalty = penalty + PathfinderUtil.defaultAreaToAvoidPenalty
		self.areaToAvoidPenaltyCount = self.areaToAvoidPenaltyCount + 1
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

--- Check if node is valid: would we collide with another vehicle or shape here?
---@param node State3D
---@param log boolean log colliding shapes/vehicles
---@param ignoreTrailer boolean don't check the trailer
function PathfinderConstraints:isValidNode(node, log, ignoreTrailer)
	PathfinderUtil.ensureHelperNode()
	PathfinderUtil.setWorldPositionAndRotationOnTerrain(PathfinderUtil.helperNode,
		node.x, -node.y, courseGenerator.toCpAngle(node.t), 0.5)

	node.collidingShapes = PathfinderUtil.collisionDetector:findCollidingShapes(
		PathfinderUtil.helperNode, vehicleData or self.context.vehicleData,
		self.context.vehiclesToIgnore, self.context.objectsToIgnore, log)
	if self.context.vehicleData.trailer and not ignoreTrailer then
		-- now check the trailer or towed implement
		-- move the node to the rear of the vehicle (where approximately the trailer is attached)
		local x, y, z = localToWorld(PathfinderUtil.helperNode, 0, 0, self.context.vehicleData.trailerHitchOffset)

		PathfinderUtil.setWorldPositionAndRotationOnTerrain(PathfinderUtil.helperNode, x, z,
			courseGenerator.toCpAngle(node.tTrailer), 0.5)

		node.collidingShapes = node.collidingShapes + PathfinderUtil.collisionDetector:findCollidingShapes(
			PathfinderUtil.helperNode, self.context.vehicleData.trailerRectangle, self.context.vehiclesToIgnore,
			self.context.objectsToIgnore, log)
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
	courseplay.debugFormat(courseplay.DBG_PATHFINDER,
		'Nodes: %d, Penalties: fruit: %d, off-field: %d, collisions: %d, area to avoid: %d',
		self.totalNodeCount, self.fruitPenaltyNodeCount, self.offFieldPenaltyNodeCount, self.collisionNodeCount,
		self.areaToAvoidPenaltyCount)
	courseplay.debugFormat(courseplay.DBG_PATHFINDER, '  max fruit %.1f %%, off-field penalty: %.1f',
		self.maxFruitPercent, self.offFieldPenalty)
end

function PathfinderConstraints:resetConstraints()
	courseplay.debugFormat(courseplay.DBG_PATHFINDER, 'resetting pathfinder constraints: maximum fruit percent allowed is now %d',
		self.initialMaxFruitPercent)
	self.maxFruitPercent = self.initialMaxFruitPercent
	self:resetCounts()
end
