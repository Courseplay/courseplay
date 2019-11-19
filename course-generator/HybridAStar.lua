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

This implementation of the hybrid A* is based on Karl Kurzer's code and
master thesis. See:

https://github.com/karlkurzer/path_planner

@mastersthesis{kurzer2016,
  author       = {Karl Kurzer},
  title        = {Path Planning in Unstructured Environments : A Real-time Hybrid A* Implementation for Fast and Deterministic Path Generation for the KTH Research Concept Vehicle},
  school       = {KTH Royal Institute of Technology},
  year         = 2016,
  month        = 12,
}

]]

--- Interface definition for all pathfinders
---@class PathfinderInterface
PathfinderInterface = CpObject()

function PathfinderInterface:init()
end

--- Start a pathfinding. This is the interface to use if you want to run the pathfinding algorithm through
-- multiple update loops so it does not block the game. This starts a coroutine and will periodically return control
-- (yield).
-- If you don't want to use coroutines and wait until the path is found, call findPath directly.
--
-- After start(), call resume() until it returns done == true.
---@see PathfinderInterface#findPath also on how to use.
function PathfinderInterface:start(...)
	if not self.coroutine then
		self.coroutine = coroutine.create(self.run)
	end
	return self:resume(...)
end

--- Is a pathfinding currently active?
-- @return true if the pathfinding has started and not yet finished
function PathfinderInterface:isActive()
	return self.coroutine ~= nil
end

--- Resume the pathfinding
---@return boolean true if the pathfinding is done, false if it isn't ready. In this case you'll have to call resume() again
---@return Polyline path if the path found or nil if none found.
-- @return array of the points of the grid used for the pathfinding, for test purposes only
function PathfinderInterface:resume(...)
	local ok, done, path, grid = coroutine.resume(self.coroutine, self, ...)
	if not ok or done then
		self.coroutine = nil
		return true, path, grid
	end
	return false
end

function PathfinderInterface:debug(...)
    courseGenerator.debug(...)
end


---@class HybridAStar
HybridAStar = CpObject(PathfinderInterface)

--- Motion primitives for node expansions, contains the dx/dy/dt values for
--- driving straight/right/left. The idea is to calculate these once as they are
--- only dependent on the turn radius, and then use the precalculated values during the search.
---@class HybridAstar.MotionPrimitives
HybridAStar.MotionPrimitives = CpObject()
-- forward straight/right/left
HybridAStar.MotionPrimitiveTypes = {FS = 'FS', FR = 'FR', FL = 'FL', RS = 'RS', RR = 'RR', RL = 'RL', LL = 'LL', RR = 'RR', NA = 'NA'}

---@param r number turning radius
---@param expansionDegree number degrees of arc in one expansion step
---@param allowReverse boolean allow for reversing
function HybridAStar.MotionPrimitives:init(r, expansionDegree, allowReverse)
	-- motion primitive table:
	self.primitives = {}
	-- distance travelled in one expansion step (length of an expansionDegree arc of a circle with radius r)
	local d = 2 * r * math.pi * expansionDegree / 360
	-- heading (theta) change in one step
	local dt = math.rad(expansionDegree)
	local dx = r * math.sin(dt)
	local dy = r - r * math.cos(dt)
	-- forward right
	table.insert(self.primitives, {dx = dx, dy = -dy, dt = dt, d = d, type = HybridAStar.MotionPrimitiveTypes.FR})
	--table.insert(self.primitives, {dx = 2 * dx, dy = -dy, dt = dt, d = 2 * d, type = HybridAStar.MotionPrimitiveTypes.FR})
	-- forward left
	table.insert(self.primitives, {dx = dx, dy = dy, dt = -dt, d = d, type = HybridAStar.MotionPrimitiveTypes.FL})
	--table.insert(self.primitives, {dx = 2 * dx, dy = dy, dt = -dt, d = 2 * d, type = HybridAStar.MotionPrimitiveTypes.FL})
	-- forward straight
	table.insert(self.primitives, {dx = d, dy = 0, dt = 0, d = d, type = HybridAStar.MotionPrimitiveTypes.FS})
	--table.insert(self.primitives, {dx = 2 * d, dy = 0, dt = 0, d = 2 * d, type = HybridAStar.MotionPrimitiveTypes.FS})
	if allowReverse then
		-- reverse straight
		table.insert(self.primitives, {dx = -d, dy = 0, dt = 0, d = d, type = HybridAStar.MotionPrimitiveTypes.RS})
		-- reverse right
		table.insert(self.primitives, {dx = -dx, dy = -dy, dt = dt, d = d, type = HybridAStar.MotionPrimitiveTypes.RR})
		-- reverse left
		table.insert(self.primitives, {dx = -dx, dy = dy, dt = -dt, d = d, type = HybridAStar.MotionPrimitiveTypes.RL})
	end
end

function HybridAStar.MotionPrimitives.isSameDirection(p1, p2)
	return p1.type:byte(1) == p2.type:byte(1)
end

function HybridAStar.MotionPrimitives.isReverse(p1)
	return p1.type:byte(1) == string.byte('R')
end

function HybridAStar.MotionPrimitives.isTurn(p1)
	return p1.type:byte(2) ~= string.byte('S')
end

function HybridAStar.MotionPrimitives:__tostring()
	local output = ''
	for i, primitive in ipairs(self.primitives) do
		output = output .. string.format('%d: dx: %.4f dy: %.4f dt: %.4f\n', i, primitive.dx, primitive.dy, primitive.dt)
	end
	return output
end

function HybridAStar.MotionPrimitives:getPrimitives()
	return self.primitives
end

--- Motion primitives for a simple A Star algorithm
HybridAStar.SimpleMotionPrimitives = CpObject(HybridAStar.MotionPrimitives)

--- A simple set of motion primitives to use with an A start algorlithm, pointing to 10 directions
---@param gridSize number search grid size in meters
HybridAStar.SimpleMotionPrimitives = CpObject(HybridAStar.MotionPrimitives)
function HybridAStar.SimpleMotionPrimitives:init(gridSize, allowReverse)
	local dx = gridSize
	local dy = gridSize
	local d = math.sqrt(dx * dx + dy * dy)
	-- motion primitive table:
	self.primitives = {}
	for angle = 0, 350, 10 do
		dx = gridSize * math.cos(math.rad(angle))
		dy = gridSize * math.sin(math.rad(angle))
		table.insert(self.primitives, {dx = dx, dy = dy, dt = 0, d = gridSize, type = HybridAStar.MotionPrimitiveTypes.NA})
	end
end

---@class HybridAStar.NodeList
HybridAStar.NodeList = CpObject()

--- Configuration space: discretized three dimensional space with x, y and theta coordinates
--- A node with x, y, theta will be assigned to a three dimensional cell in the space
---@param gridSize number size of the cell in the x/y dimensions
---@param thetaResolutionDeg number size of the cell in the theta dimension in degrees
function HybridAStar.NodeList:init(gridSize, thetaResolutionDeg)
	self.nodes = {}
	self.gridSize = gridSize
	self.thetaResolutionDeg = thetaResolutionDeg
	self.lowestCost = math.huge
	self.highestCost = -math.huge
end

---@param node State3D
function HybridAStar.NodeList:getNodeIndexes(node)
	local x = math.floor(node.x / self.gridSize)
	local y = math.floor(node.y / self.gridSize)
	local t = math.floor(math.deg(node.t) / self.thetaResolutionDeg)
	return x, y, t
end

function HybridAStar.NodeList:inSameCell(n1, n2)
	local x1, y1, t1 = self:getNodeIndexes(n1)
	local x2, y2, t2 = self:getNodeIndexes(n2)
	return x1 == x2 and y1 == y2 and t1 == t2
end

---@param node State3D
function HybridAStar.NodeList:get(node)
	local x, y, t = self:getNodeIndexes(node)
	if self.nodes[x] and self.nodes[x][y] then
		return self.nodes[x][y][t]
	end
end

--- Add a node to the configuration space
---@param node State3D
function HybridAStar.NodeList:add(node)
	local x, y, t = self:getNodeIndexes(node)
	if not self.nodes[x] then
		self.nodes[x] = {}
	end
	if not self.nodes[x][y] then
		self.nodes[x][y] = {}
	end
	self.nodes[x][y][t] = node
	if node.cost >= self.highestCost then
		self.highestCost = node.cost
	end
	if node.cost < self.lowestCost then
		self.lowestCost = node.cost
	end
end

function HybridAStar.NodeList:print()
	for _, row in pairs(self.nodes) do
		for _, column in pairs(row) do
			for _, cell in pairs(column) do
				print(cell)
			end
		end
	end
end

---Environment data
---@class HybridAStar.EnvironmentData
HybridAStar.EnvironmentData = CpObject()


function HybridAStar:init(yieldAfter)
	self.count = 0
	self.yields = 0
	self.yieldAfter = yieldAfter or 200
	self.path = {}
	self.iterations = 0
	-- if the goal is within self.deltaPos meters we consider it reached
	self.deltaPos = 1.1
	-- if the goal heading is within self.deltaThetaDeg degrees we consider it reached
	self.deltaThetaDeg = 5
	-- the same two parameters are used to discretize the continuous state space
end

--- Calculate penalty for this node. The penalty will be added to the cost of the node. This allows for
--- obstacle avoidance or forcing the search to remain in certain areas.
---@param node State3D
function HybridAStar.getNodePenalty(node)
	return 0
end

function HybridAStar.isValidNode(node, userData)
	return true
end

function HybridAStar:getMotionPrimitives(turnRadius, allowReverse)
	return HybridAStar.MotionPrimitives(turnRadius, 6.75, allowReverse)
end

---@param start State3D start node
---@param goal State3D goal node
---@param userData table anything you want to pass on to the isValidNodeFunc
---@param allowReverse boolean allow reverse driving
---@param getNodePenaltyFunc function get penalty for a node, see getNodePenalty()
---@param isValidNodeFunc function function to check if a node should even be considered
function HybridAStar:findPath(start, goal, turnRadius, userData, allowReverse, getNodePenaltyFunc, isValidNodeFunc)
	self:debug('Start pathfinding between %s and %s', tostring(start), tostring(goal))
	if not getNodePenaltyFunc then getNodePenaltyFunc = self.getNodePenalty end
	self.isValidNodeFunc = isValidNodeFunc or self.isValidNode
	-- a motion primitive is straight or a few degree turn to the right or left
	local hybridMotionPrimitives = self:getMotionPrimitives(turnRadius, allowReverse)

	-- create the open list for the nodes as a binary heap where
	-- the node with the lowest total cost is at the top
	local openList = BinaryHeap.minUnique(function(a, b) return a:lt(b) end)

	-- create the configuration space
	---@type HybridAStar.NodeList closedList
	self.nodes = HybridAStar.NodeList(self.deltaPos, self.deltaThetaDeg)

	start:updateH(goal)
	start:insert(openList)
	self.nodes:add(start)

	self.iterations = 0
	self.expansions = 0
	self.yields = 0

	while openList:size() > 0 and self.iterations < 200000 do
		-- pop lowest cost node from queue
		---@type State3D
		local pred = State3D.pop(openList)
		if pred:equals(goal, self.deltaPos, math.rad(self.deltaThetaDeg)) then
			-- done!
			self:rollUpPath(pred, goal)
			return true, self.path
		end

		self.count = self.count + 1
		-- yield only when we were started in a coroutine.
		if coroutine.running() and self.count % self.yieldAfter == 0 then
			self.yields = self.yields + 1
			coroutine.yield(false)
		end

		if not pred:isClosed() then
			-- create the successor nodes
			for _, primitive in ipairs(hybridMotionPrimitives:getPrimitives()) do
				---@type State3D
				local succ = pred:createSuccessor(primitive)
				if succ:equals(goal, self.deltaPos, math.rad(self.deltaThetaDeg)) then
					succ.pred = succ.pred
					self:rollUpPath(succ, goal)
					return true, self.path
				end
				local existingSuccNode = self.nodes:get(succ)
				if not existingSuccNode or (existingSuccNode and not existingSuccNode:isClosed()) then
					-- ignore invalidity of a node in the first few iterations: this is due to the fact that sometimes
					-- we end up being in overlap with another vehicle when we start the pathfinding and all we need is
					-- an iteration or two to bring us out of that position
					if self.iterations < 3 or self.isValidNodeFunc(succ, userData) then
						succ:updateG(primitive, getNodePenaltyFunc(succ))
						succ:updateH(goal, turnRadius)
						if existingSuccNode then
							-- there is already a node at this (discretized) position
							if existingSuccNode:getCost() + 0.1 > succ:getCost() then
								-- successor cell already exist but the new one is cheaper, replace
								-- may add 0.1 to the existing one's cost to prefer replacement
								if self.nodes:inSameCell(succ, pred) then
									existingSuccNode.pred = pred.pred
								end
								if openList:valueByPayload(existingSuccNode) then
									-- existing node is on open list already, replace by removing
									-- it here first
									existingSuccNode:remove(openList)
								end
								-- add (update) to the state space
								self.nodes:add(succ)
								-- add to open list
								succ:insert(openList)
							end
						else
							-- successor cell does not yet exist
							self.nodes:add(succ)
							-- put it on the open list as well
							succ:insert(openList)
						end
					else
						--self:debug('Invalid node %s (iteration %d)', tostring(succ), self.iterations)
						succ:close()
						self.nodes:add(succ)
					end -- valid node
				end
			end
			-- node as been expanded, close it to prevent expansion again
			--self:debug(tostring(pred))
			pred:close()
			self.expansions = self.expansions + 1
		end
		self.iterations = self.iterations + 1
	end
	self.path = {}
	self:debug('No path found: iterations %d, yields %d, cost %.1f - %.1f', self.iterations, self.yields,
            self.nodes.lowestCost, self.nodes.highestCost)

    return true, nil
end

---@param node State3D
function HybridAStar:rollUpPath(node, goal)
	self.path = {}
	local currentNode = node
	self:debug('Goal node at %.2f/%.2f, cost %.1f (%.1f - %.1f)', goal.x, goal.y, node.cost,
			self.nodes.lowestCost, self.nodes.highestCost)
	self:debug('Iterations %d, yields %d', self.iterations, self.yields)
	table.insert(self.path, 1, currentNode)
	while currentNode.pred and currentNode ~= currentNode.pred do
		table.insert(self.path, 1, currentNode.pred)
		currentNode = currentNode.pred
	end
end

function HybridAStar:printOpenList(openList)
	print('--- Open list ----')
	for i, node in ipairs(openList.values) do
		print(node)
		if i > 5 then break end
	end
	print('--- Open list end ----')
end

--- A simple A star implementation based on the hybrid A star. The difference is that the state space isn't really
--- 3 dimensional as we do not take the heading into account and we use a differen set of motion primitives
AStar = CpObject(HybridAStar)

function AStar:init(yieldAfter)
	HybridAStar.init(self, yieldAfter)
	self.deltaPos = 5
	self.deltaThetaDeg = 181
end

function AStar:getMotionPrimitives(turnRadius, allowReverse)
	return HybridAStar.SimpleMotionPrimitives(self.deltaPos, allowReverse)
end

--- A pathfinder combining the (slow) hybrid A * and the (fast) regular A * star.
--- Near the start and the goal the hybrid A * is used to ensure the generated path is drivable (direction changes 
--- always obey the turn radius), but use the A * between the two.
--- We'll run 3 pathfindings: one A * between start and goal (phase 1), then trim the ends of the result in hybridRange
--- Now run a hybrid A * from the start to the beginning of the trimmed A * path (phase 2), then another hybrid A * from the
--- end of the trimmed A * to the goal (phase 3).
HybridAStarWithAStarInTheMiddle = CpObject(PathfinderInterface)

---@param hybridRange number range in meters around start/goal to use hybrid A *
---@param yieldAfter number coroutine yield after so many iterations (number of iterations in one update loop)
function HybridAStarWithAStarInTheMiddle:init(hybridRange, yieldAfter)
	-- path generation phases
	self.START_TO_MIDDLE = 1
	self.MIDDLE = 2
	self.MIDDLE_TO_END = 3
	self.ALL_HYBRID = 4 -- start and goal close enough, we only need a single phase with hybrid
	self.hybridRange = hybridRange
	self.yieldAfter = yieldAfter or 200
end

---@param start State3D start node
---@param goal State3D goal node
---@param userData table anything you want to pass on to the isValidNodeFunc
---@param allowReverse boolean allow reverse driving
---@param getNodePenaltyFunc function function to calculate the penalty for a node. Typically you want to penalize
--- off-field locations and locations with fruit on the field.
---@param isValidNodeFunc function function to check if a node should even be considered
function HybridAStarWithAStarInTheMiddle:start(start, goal, turnRadius, userData, allowReverse, getNodePenaltyFunc, isValidNodeFunc)
	self.hybridAStarPathFinder = HybridAStar(self.yieldAfter)
	self.aStarPathFinder = AStar(self.yieldAfter)
	self.retries = 0
	self.startNode, self.goalNode = State3D:copy(start), State3D:copy(goal)
	self.originalStartNode = State3D:copy(self.startNode)
	self.turnRadius, self.userData, self.allowReverse = turnRadius, userData, allowReverse
	self.getNodePenaltyFunc = getNodePenaltyFunc
	self.isValidNodeFunc = isValidNodeFunc
	self.hybridRange = self.hybridRange and self.hybridRange or turnRadius * 3
	-- how far is start/goal apart?
	self.startNode:updateH(self.goalNode)
	-- do we even need to use the normal A star or the nodes are close enough that the hybrid A star will be fast enough?
	if self.startNode:getCost() < self.hybridRange * 3 then
		self.phase = self.ALL_HYBRID
        self:debug('Goal is closer than %d, use one phase pathfinding only', self.hybridRange * 3)
		self.coroutine = coroutine.create(self.hybridAStarPathFinder.findPath)
		self.currentPathfinder = self.hybridAStarPathFinder
		-- swap start and goal as the path will always start exactly at the start point but will only approximately end
		-- at the goal. Here we want to end up exactly on the goal point
		self.startNode:reverseHeading()
		self.goalNode:reverseHeading()
        -- TODO: solve this somehow cleaner, we have to pass on to the isValidNodeFunc the fact that we are searching
        -- backwards so in case of collision check the vehicle must be turned 180
		if self.userData then self.userData.reverseHeading = true end
		return self:resume(self.goalNode, self.startNode, turnRadius, self.userData, self.allowReverse, getNodePenaltyFunc, isValidNodeFunc)
	else
		self.phase = self.MIDDLE
        self:debug('Finding direct path between start and goal...')
		self.coroutine = coroutine.create(self.aStarPathFinder.findPath)
		self.currentPathfinder = self.aStarPathFinder
		self.userData.reverseHeading = false
		return self:resume(self.startNode, self.goalNode, turnRadius, self.userData, false, getNodePenaltyFunc, isValidNodeFunc)
	end
end

--- The resume() of this pathfinder is more complicated as it handles essentially three separate pathfinding runs
function HybridAStarWithAStarInTheMiddle:resume(...)
	local ok, done, path = coroutine.resume(self.coroutine, self.currentPathfinder, ...)
	if not ok then
		self.coroutine = nil
		print(done)
		return true, nil
	end
	if done then
		self.coroutine = nil
		if not path then return true, nil end
		self.nodes = self.hybridAStarPathFinder.nodes
		if self.phase == self.ALL_HYBRID then
			-- start and node near, just one phase, all hybrid, we are done
			-- remove last waypoint as it is the approximate goal point and may not be aligned
			table.remove(path)
			-- since we generated a path from the goal -> start we now have to reverse it
			self:reverseTable(path)
			local result = Polygon:new(path)
			result:calculateData()
			result:space(math.pi / 20, 2)
			self:fixReverseForCourseplay(result)
			return true, result
		elseif self.phase == self.MIDDLE then
            -- middle part ready, now trim start and end to make room for the hybrid parts
			self.middlePath = Polyline:new(path)
			self.middlePath:calculateData()
			self.middlePath:shortenStart(self.hybridRange)
			self.middlePath:shortenEnd(self.hybridRange)
            self:debug('Finding path between start and middle section...')
			self.phase = self.START_TO_MIDDLE
			-- generate a hybrid part from the start to the middle section's start
			self.coroutine = coroutine.create(self.hybridAStarPathFinder.findPath)
			self.currentPathfinder = self.hybridAStarPathFinder
			local goal = State3D(self.middlePath[1].x, self.middlePath[1].y, self.middlePath[1].nextEdge.angle)
            --print(tostring(self.middlePath))
            --print(tostring(self.startNode))
            --print(tostring(goal))
			self.userData.reverseHeading = false
			return self:resume(self.startNode, goal, self.turnRadius, self.userData, self.allowReverse, self.getNodePenaltyFunc, self.isValidNodeFunc)
		elseif self.phase == self.START_TO_MIDDLE then
			-- start and middle sections ready
			-- append middle to start
			self.path = Polygon:new(path)
			-- ignore first and last wp of middle path to avoid short fwd/reverse sections due to overlaps
			for i = 2, #self.middlePath - 1 do
				table.insert(self.path, self.middlePath[i])
			end
			self.path:calculateData()
			-- generate middle to end
			self.phase = self.MIDDLE_TO_END
            self:debug('Finding path between middle section and goal...')
			self.coroutine = coroutine.create(self.hybridAStarPathFinder.findPath)
			self.currentPathfinder = self.hybridAStarPathFinder
			-- swap start and goal as the path will always start exactly at the start point but will only approximately end
			-- at the goal. Here we want to end up exactly on the goal point
			local start = State3D(self.middlePath[#self.middlePath].x, self.middlePath[#self.middlePath].y, self.middlePath[#self.middlePath].prevEdge.angle)
            start:reverseHeading()
			self.userData.reverseHeading = true
			self.goalNode:reverseHeading()
            return self:resume(self.goalNode, start, self.turnRadius, self.userData, self.allowReverse, self.getNodePenaltyFunc, self.isValidNodeFunc)
		else
			if path then
				-- last piece is ready, this was generated from the goal point to the end of the middle section so
				-- first remove the last point of the middle section to make the transition smoother
				-- and then add the last section in reverse order
				-- also, for reasons we don't fully understand, this section may have a direction change at the last waypoint,
				-- so we just ignore the last one
				for i = #path, 1, -1 do
					table.insert(self.path, path[i])
				end
				self.path:calculateData()
                self.path:smooth(math.pi / 30, math.pi / 2, 3, 10, #self.path - 10)
				self.path:calculateData()
				self.path:space(math.pi / 20, 2)
				self:fixReverseForCourseplay(self.path)
			end
			return true, self.path
		end
	end
	return false
end

--- Figure out which waypoints should have the reverse attribute in order to make it drivable by the PPC
function HybridAStarWithAStarInTheMiddle:fixReverseForCourseplay(path)
    --print(tostring(path))
	path:calculateData()
    -- we rely here on the fact that the start waypoint will be approximately aligned with the vehicle either forward or backward
    -- (about 0 or 180 degrees)
    local angleBetweenStartAndFirstWp = math.abs(path[1].nextEdge.angle - self.originalStartNode.t)
    self:debug('Angle between start (%.1f) and first wp (%.1f) is %.1f', math.deg(self.originalStartNode.t), math.deg(path[1].nextEdge.angle), math.deg(angleBetweenStartAndFirstWp))
	local maxDeltaAngle = math.pi / 2
	-- if not approximately the same angle then start in reverse
    local currentReverse = not (angleBetweenStartAndFirstWp < maxDeltaAngle or angleBetweenStartAndFirstWp > 2 * math.pi - maxDeltaAngle)
    path[1].reverse = currentReverse
    -- and then keep changing direction when the waypoint direction changes a lot
	for i = 2, #path do
        path[i].reverse = currentReverse
		if math.abs(getDeltaAngle(path[i].prevEdge.angle, path[i].nextEdge.angle)) > 2 * math.pi / 3 then
            currentReverse = not currentReverse
		end
	end
	path:calculateData()
	--print(tostring(path))
end

-- TODO: put this in a global lib, instead of helpers.lua as helpers.lua depends on courseplay.
function HybridAStarWithAStarInTheMiddle:reverseTable(t)
	local i, j = 1, #t
	while i < j do
		t[i], t[j] = t[j], t[i]
		i = i + 1
		j = j - 1
	end
end;

