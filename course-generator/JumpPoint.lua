---@class HybridAStar.JpsMotionPrimitives : HybridAstar.SimpleMotionPrimitives
HybridAStar.JpsMotionPrimitives = CpObject(HybridAStar.SimpleMotionPrimitives)
function HybridAStar.JpsMotionPrimitives:init(gridSize, deltaPosGoal, deltaThetaGoal)
	-- similar to the A*, the possible motion primitives (the neighbors) are in all 8 directions.
	HybridAStar.SimpleMotionPrimitives.init(self, gridSize)
	self.deltaPosGoal = deltaPosGoal
	self.deltaThetaGoal = deltaThetaGoal
end

function HybridAStar.JpsMotionPrimitives:isValidNode(x, y, t, constraints)
	local node = {x = x, y = y, t = t}

	if not constraints:isValidNode(node, true) then
		return false
	else
		-- we ignore off-field penalty. The problem with JPS is it works only for uniform cost grids, so a node
		-- is either invalid or valid, no such thing as higher cost to prefer other paths.
		local penalty = constraints:getNodePenalty(node, true)
		return penalty < 1
	end
end

-- Get the possible neighbors when coming from the predecessor node.
-- While the other HybridAStar derived algorithms use a real motion primitive, meaning it gives the relative
-- x, y and theta values which need to be added to the predecessor, JPS supplies the actual coordinates of
-- the successors here instead.
-- This is not the most elegant solution and the only reason we do this is to be able to reuse the whole
-- framework in HybridAStar.lua with JPS.
function HybridAStar.JpsMotionPrimitives:getPrimitives(node, constraints)
	local primitives = {}
	if node.pred then
		local x, y, t = node.x, node.y, node.t
		-- Node has a parent, we will prune some neighbours
		-- Gets the direction of move
		local dx = self.gridSize * (x - node.pred.x) / math.max(1, math.abs(x - node.pred.x))
		local dy = self.gridSize * (y - node.pred.y) / math.max(1, math.abs(y - node.pred.y))
		local dDiag = math.sqrt(dx * dx + dy * dy)
		local xOk, yOk = false, false
		if math.abs(dx) > 0.1 and math.abs(dy) > 0.1 then
			-- diagonal move
			if self:isValidNode(x, y + dy, t, constraints) then
				table.insert(primitives, {x = x, y = y + dy, t = math.atan2(dy, 0), d = math.abs(dy)})
				yOk = true
			end
			if self:isValidNode(x + dx, y, t, constraints) then
				table.insert(primitives, {x = x + dx, y = y, t = math.atan2(0, dx), d = math.abs(dx)})
				xOk = true
			end
			if xOk or yOk then
				table.insert(primitives, {x = x + dx, y = y + dy, t = math.atan2(dy, dx), d = dDiag})
			end
			-- Forced neighbors
			if not self:isValidNode(x - dx, y, t, constraints) and yOk then
				table.insert(primitives, {x = x - dx, y = y + dy, t = math.atan2(dy, -dx), d = dDiag})
			end
			if not self:isValidNode(x, y - dy, t, constraints) and xOk then
				table.insert(primitives, {x = x + dx, y = y - dy, t = math.atan2(-dy, dx), d = dDiag})
			end
		else
			if math.abs(dx) < 0.1 then
				-- move along the y axis
				if self:isValidNode(x, y + dy, t, constraints) then
					table.insert(primitives, {x = x, y = y + dy, t = math.atan2(dy, 0), d = math.abs(dy)})
				end
				-- Forced neighbors
				dDiag = math.sqrt(dy * dy + self.gridSize * self.gridSize)
				if not self:isValidNode(x + self.gridSize, y, t, constraints) then
					table.insert(primitives, {x = x + self.gridSize, y = y + dy,
											  t = math.atan2(dy, self.gridSize), d = dDiag})
					--table.insert(JumpPointSearch.markers, {label = 'forced x +', x = x + self.gridSize, y = y})
				end
				if not self:isValidNode(x - self.gridSize, y, t, constraints) then
					table.insert(primitives, {x = x - self.gridSize, y = y + dy,
											  t = math.atan2(dy, -self.gridSize), d = dDiag})
					--table.insert(JumpPointSearch.markers, {label = 'forced x -', x = x - self.gridSize, y = y})
				end
			else
				-- move along the x axis
				if self:isValidNode(x + dx, y, t, constraints) then
					table.insert(primitives, {x = x + dx, y = y, t = math.atan2(0, dx), d = math.abs(dx)})
				end
				-- Forced neighbors
				dDiag = math.sqrt(dx * dx + self.gridSize * self.gridSize)
				if not self:isValidNode(x, y + self.gridSize, t, constraints) then
					table.insert(primitives, {x = x + dx, y = y + self.gridSize,
											  t = math.atan2(self.gridSize, dx), d = dDiag})
					--table.insert(JumpPointSearch.markers, {label = 'forced y +', x = x, y = y + self.gridSize})
				end
				if not self:isValidNode(x, y - self.gridSize, t, constraints) then
					table.insert(primitives, {x = x + dx, y = y - self.gridSize,
											  t = math.atan2(-self.gridSize, dx), d = dDiag})
					--table.insert(JumpPointSearch.markers, {label = 'forced y -', x = x, y = y - self.gridSize})
				end
			end
		end
	else
		-- no parent, this is the start node
		for _, p in pairs(self.primitives) do
			-- JPS does not really use motion primitives, what we call primitives are actually the
			-- successors, with their real coordinates, not just a delta.
			table.insert(primitives, { x = node.x + p.dx, y = node.y + p.dy, t = p.dt, d = p.d})
		end
	end
	return primitives
end

function HybridAStar.JpsMotionPrimitives:jump(node, pred, constraints, goal, recursionCounter)
	if recursionCounter and recursionCounter > 2 then
		return node, recursionCounter
	end
	recursionCounter = recursionCounter and recursionCounter + 1 or 1
	local x,y, t = node.x, node.y, node.t
	if not self:isValidNode(x, y, t, constraints) then return nil end
	if node:equals(goal, self.deltaPosGoal, self.deltaThetaGoal) then return node end
	local dx = x - pred.x
	local dy = y - pred.y
	if math.abs(dx) > 0.1 and math.abs(dy) > 0.1 then
		-- diagonal move
		if  (self:isValidNode(x - dx, y + dy, t, constraints) and not self:isValidNode(x - dx, y, t, constraints)) or
			(self:isValidNode(x + dx, y - dy, t, constraints) and not self:isValidNode(x, y - dy, t, constraints)) then
			-- Current node is a jump point if one of its left or right neighbors ahead is forced
			return node
		end
	else
		if math.abs(dx) > 0.1 then
			-- move along the x axis
			if  (self:isValidNode(x + dx, y + self.gridSize, t, constraints) and not self:isValidNode(x, y + self.gridSize, t, constraints)) or
				(self:isValidNode(x + dx, y - self.gridSize, t, constraints) and not self:isValidNode(x, y - self.gridSize, t, constraints)) then
				-- Current node is a jump point if one of its left or right neighbors ahead is forced
				return node
			end
		else
			-- move along the y axis
			if  (self:isValidNode(x + self.gridSize, y + dy, t, constraints) and not self:isValidNode(x + self.gridSize, y, t, constraints)) or
				(self:isValidNode(x - self.gridSize, y + dy, t, constraints) and not self:isValidNode(x - self.gridSize, y, t, constraints)) then
				-- Current node is a jump point if one of its left or right neighbors ahead is forced
				return node
			end
		end
	end
	-- Recursive horizontal/vertical search
	if math.abs(dx) > 0.1 and math.abs(dy) > 0.1 then
		if self:jump(State3D(x + dx, y, node.t), node, constraints, goal, recursionCounter) then return node end
		if self:jump(State3D(x, y + dy, node.t), node, constraints, goal, recursionCounter) then return node end
	end
	-- Recursive diagonal search
	if self:isValidNode(x + dx, y, t, constraints) or self:isValidNode(x, y + dy, t, constraints) then
		return self:jump(State3D(x + dx, y + dy, node.t), node, constraints, goal, recursionCounter)
	end
end

function HybridAStar.JpsMotionPrimitives:createSuccessor(node, primitive, hitchLength, constraints, goal)
	local neighbor = State3D(primitive.x, primitive.y, primitive.t)
	local jumpNode, jumps = self:jump(neighbor, node, constraints, goal)
	primitive.d = jumps and jumps * primitive.d or primitive.d
	if jumpNode then
		return State3D(jumpNode.x, jumpNode.y, jumpNode.t, node.g, node, HybridAStar.Gear.Forward, HybridAStar.Steer.Straight,
			node:getNextTrailerHeading(self.gridSize, hitchLength))
	end
end


--- A Jump Point Search
---@class JumpPointSearch : AStar
JumpPointSearch = CpObject(AStar)
JumpPointSearch.markers = {}

function JumpPointSearch:init(yieldAfter, maxIterations)
	AStar.init(self, yieldAfter, maxIterations)
end

function JumpPointSearch:getMotionPrimitives(turnRadius, allowReverse)
	return HybridAStar.JpsMotionPrimitives(self.deltaPos, self.deltaPosGoal, self.deltaThetaGoal)
end
