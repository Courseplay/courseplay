---@class HybridAStar.JpsMotionPrimitives : HybridAstar.SimpleMotionPrimitives
HybridAStar.JpsMotionPrimitives = CpObject(HybridAStar.SimpleMotionPrimitives)
function HybridAStar.JpsMotionPrimitives:init(gridSize, deltaPosGoal, deltaThetaGoal)
	-- similar to the A*, the possible motion primitives (the neighbors) are in all 8 directions.
	-- we'll prune these in getPrimitives()

	self.primitives = {}
	self.gridSize = gridSize
	self.deltaPosGoal = deltaPosGoal
	self.deltaThetaGoal = deltaThetaGoal
	local dA = math.pi / 4
	for i = 0, 7 do
		table.insert(self.primitives, {x = gridSize * math.cos(i * dA), y = gridSize * math.sin(i * dA),
									   t = i * dA, d = gridSize})
	end
end

function HybridAStar.JpsMotionPrimitives:isValidNode(x, y, constraints)
	--print('isValidNode', x, y)
	local node = {x = x, y = y}
	if not constraints:isValidNode(node) then
		return false
	else
		local penalty = constraints:getNodePenalty(node)
		return penalty < 1
	end
end

-- Get the possible neighbors when coming from the predecessor node
function HybridAStar.JpsMotionPrimitives:getPrimitives(node, constraints)
	local primitives = {}
	if node.pred then
		local x,y = node.x, node.y
		-- Node has a parent, we will prune some neighbours
		-- Gets the direction of move
		local dx = (x - node.pred.x) / math.max(1, math.abs(x - node.pred.x))
		local dy = (y - node.pred.y) / math.max(1, math.abs(y - node.pred.y))
		local xOk, yOk = false, false
		if math.abs(dx) > 0.1 and math.abs(dy) > 0.1 then
			-- diagonal move
			if self:isValidNode(x, y + dy, constraints) then
				table.insert(primitives, {x = x, y = y + dy, t = math.atan2(dy, 0)})
				yOk = true
			end
			if self:isValidNode(x + dx, y, constraints) then
				table.insert(primitives, {x = x + dx, y = y, t = math.atan2(0, dx)})
				xOk = true
			end
			if xOk or yOk then
				table.insert(primitives, {x = x + dx, y = y + dy, t = math.atan2(dy, dx)})
			end
			-- Forced neighbors
			if not self:isValidNode(x - dx, y, constraints) and yOk then
				table.insert(primitives, {x = x - dx, y = y + dy, t = math.atan2(dy, -dx)})
			end
			if not self:isValidNode(x, y - dy, constraints) and xOk then
				table.insert(primitives, {x = x + dx, y = y - dy, t = math.atan2(-dy, dx)})
			end
		else
			if math.abs(dx) < 0.1 then
				-- move along the y axis
				if self:isValidNode(x, y + dy, constraints) then
					table.insert(primitives, {x = x, y = y + dy, t = math.atan2(dy, 0)})
				end
				-- Forced neighbors
				if not self:isValidNode(x + self.gridSize, y, constraints) then
					table.insert(primitives, {x = x + self.gridSize, y = y + dy, t = math.atan2(dy, self.gridSize)})
				end
				if not self:isValidNode(x - self.gridSize, y, constraints) then
					table.insert(primitives, {x = x - self.gridSize, y = y + dy, t = math.atan2(dy, -self.gridSize)})
				end
			else
				-- move along the x axis
				if self:isValidNode(x + dx, y, constraints) then
					table.insert(primitives, {x = x + dx, y = y, t = math.atan2(0, dx)})
				end
				-- Forced neighbors
				if not self:isValidNode(x, y + self.gridSize, constraints) then
					table.insert(primitives, {x = x + dx, y = y + self.gridSize, t = math.atan2(self.gridSize, dx)})
				end
				if not self:isValidNode(x, y - self.gridSize, constraints) then
					table.insert(primitives, {x = x + dx, y = y - self.gridSize, t = math.atan2(-self.gridSize, dx)})
				end
			end
		end
		return primitives
	else
		return self.primitives
	end
end

function HybridAStar.JpsMotionPrimitives:jump(node, pred, constraints, goal)
	local x,y = node.x, node.y
	if not self:isValidNode(x, y, constraints) then return nil end
	if node:equals(goal, self.deltaPosGoal, self.deltaThetaGoal) then return node end
	local dx = x - pred.x
	local dy = y - pred.y
	if math.abs(dx) > 0.1 and math.abs(dy) > 0.1 then
		-- diagonal move
		if  (self:isValidNode(x - dx, y + dy, constraints) and not self:isValidNode(x - dx, y, constraints)) or
			(self:isValidNode(x + dx, y - dy, constraints) and not self:isValidNode(x, y - dy, constraints)) then
			-- Current node is a jump point if one of its left or right neighbors ahead is forced
			return node
		end
	else
		if math.abs(dx) < 0.1 then
			-- move along the y axis
			if  (self:isValidNode(x + dx, y + self.gridSize, constraints) and not self:isValidNode(x, y + self.gridSize, constraints)) or
				(self:isValidNode(x + dx, y - self.gridSize, constraints) and not self:isValidNode(x, y - self.gridSize, constraints)) then
				-- Current node is a jump point if one of its left or right neighbors ahead is forced
				return node
			end
		else
			-- move along the x axis
			if  (self:isValidNode(x + self.gridSize, y + dy, constraints) and not self:isValidNode(x + self.gridSize, y, constraints)) or
				(self:isValidNode(x - self.gridSize, y + dy, constraints) and not self:isValidNode(x - self.gridSize, y, constraints)) then
				-- Current node is a jump point if one of its left or right neighbors ahead is forced
				return node
			end
		end
	end
	-- Recursive horizontal/vertical search
	if math.abs(dx) > 0.1 and math.abs(dy) > 0.1 then
		if self:jump(State3D(x + dx, y, node.t), node, constraints, goal) then return node end
		if self:jump(State3D(x, y + dy, node.t), node, constraints, goal) then return node end
	end
	-- Recursive diagonal search
	if self:isValidNode(x + dx, y, constraints) or self:isValidNode(x, y + dy, constraints) then
		return self:jump(State3D(x + dx, y + dy, node.t),node, constraints, goal)
	end
end

function HybridAStar.JpsMotionPrimitives:createSuccessor(node, primitive, hitchLength, constraints, goal)
	local neighbor = State3D(primitive.x, primitive.y, primitive.t)
	local jumpNode = self:jump(neighbor, node, constraints, goal)
	return State3D(jumpNode.x, jumpNode.y, jumpNode.t, node.g, node, HybridAStar.Gear.Forward, HybridAStar.Steer.Straight,
		node:getNextTrailerHeading(self.gridSize, hitchLength))
end


--- A Jump Point Search
---@class JumpPointSearch
JumpPointSearch = CpObject(AStar)

function JumpPointSearch:init(yieldAfter, maxIterations)
	AStar.init(self, yieldAfter, maxIterations)
end

function JumpPointSearch:getMotionPrimitives(turnRadius, allowReverse)
	return HybridAStar.JpsMotionPrimitives(self.deltaPos, self.deltaPosGoal, self.deltaThetaGoal)
end

