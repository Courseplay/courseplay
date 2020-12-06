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
		self.coroutine = coroutine.create(self.findPath)
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
	local ok, done, path, goalNodeInvalid = coroutine.resume(self.coroutine, self, ...)
	if not ok or done then
		self.coroutine = nil
		return true, path, goalNodeInvalid
	end
	return false
end

function PathfinderInterface:debug(...)
    courseGenerator.debug(...)
end

--- Interface definition for pathfinder constraints (for dependency injection of node penalty/validity checks
---@class PathfinderConstraintInterface
PathfinderConstraintInterface = CpObject()

function PathfinderConstraintInterface:init()
end

--- Is this a valid node?
---@param node State3D
function PathfinderConstraintInterface:isValidNode(node)
	return true
end

--- Is this a valid node for an analytic solution?
---@param node State3D
function PathfinderConstraintInterface:isValidAnalyticSolutionNode(node)
	return true
end

--- Calculate penalty for this node. The penalty will be added to the cost of the node. This allows for
--- obstacle avoidance or forcing the search to remain in certain areas.
---@param node State3D
function PathfinderConstraintInterface:getNodePenalty(node)
	return 0
end

--- Relax pathfinder constraints (like reduce fruit penalty?)
function PathfinderConstraintInterface:relaxConstraints()
end

--- Reset pathfinder constraints to their original value
function PathfinderConstraintInterface:resetConstraints()
end

--- Interface for analytic solutions of pathfinding problems
---@class AnalyticSolution
AnalyticSolution = CpObject()

---@param turnRadius number needed as the solution is usually normalized for the unit circle
---@return number length of the analytic solution in meters
function AnalyticSolution:getLength(turnRadius)
	return 0
end

---@param start State3D
---@param turnRadius number
---@return State3D[] array of path points of the solution
function AnalyticSolution:getWaypoints(start, turnRadius)
end

--- Interface for all analytic path problem solvers (Dubins and Reeds-Shepp)
---@class AnalyticSolver
AnalyticSolver = CpObject()

--- Solve a pathfinding problem (find drivable path between start and goal
--- for a vehicle with the given turn radius
---@param start State3D
---@param goal State3D
---@param turnRadius number
---@return AnalyticSolution a path descriptor
function AnalyticSolver:solve(start, goal, turnRadius)
	return AnalyticSolution()
end

---@class HybridAStar
HybridAStar = CpObject(PathfinderInterface)

HybridAStar.Gear =
{
	Forward = {},
	Backward = {}
}

HybridAStar.Steer =
{
	Left = {},
	Straight = {},
	Right = {}
}

--- Get length of path
---@param path Vector[]
---@return number length of path
function HybridAStar.length(path)
	local d = 0
	for i = 2, #path do
		local segment = path[i] - path[i - 1]
		d = d + segment:length()
	end
	return d
end
---
--- Shorten path by d meters at the start
---@param path Vector[]
---@param d number
function HybridAStar.shortenStart(path, d)
	local dCut = d
	local to = #path - 1
	for i = 1, to  do
		local segment = path[2] - path[1]
		-- check for something else than zero to make sure the new point does not overlap with the last we did not cut
		if dCut < segment:length() - 0.1 then
			segment:setLength(dCut)
			path[1]:add(segment)
			return true
		end
		dCut = dCut - segment:length()
		table.remove(path, 1)
	end
end

--- Shorten path by d meters at the end
---@param path Vector[]
---@param d number
function HybridAStar.shortenEnd(path, d)
	local dCut = d
	local from = #path - 1
	for i = from, 1, -1  do
		local segment = path[#path] - path[#path - 1]
		-- check for something else than zero to make sure the new point does not overlap with the last we did not cut
		if dCut < segment:length() - 0.1 then
			segment:setLength(dCut)
			path[#path]:add(- segment)
			return true
		end
		dCut = dCut - segment:length()
		table.remove(path)
	end
end


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
	-- forward straight
	table.insert(self.primitives, {dx = d, dy = 0, dt = 0, d = d,
								   gear = HybridAStar.Gear.Forward,
								   steer = HybridAStar.Steer.Straight,
								   type = HybridAStar.MotionPrimitiveTypes.FS})
	-- forward right
	table.insert(self.primitives, {dx = dx, dy = -dy, dt = dt, d = d,
								   gear = HybridAStar.Gear.Forward,
								   steer = HybridAStar.Steer.Right,
								   type = HybridAStar.MotionPrimitiveTypes.FR})
	-- forward left
	table.insert(self.primitives, {dx = dx, dy = dy, dt = -dt, d = d,
								   gear = HybridAStar.Gear.Forward,
								   steer = HybridAStar.Steer.Left,
								   type = HybridAStar.MotionPrimitiveTypes.FL})
	if allowReverse then
		-- reverse straight
		table.insert(self.primitives, {dx = -d, dy = 0, dt = 0, d = d,
									   gear = HybridAStar.Gear.Backward,
									   steer = HybridAStar.Steer.Straight,
									   type = HybridAStar.MotionPrimitiveTypes.RS})
		-- reverse right
		table.insert(self.primitives, {dx = -dx, dy = -dy, dt = dt, d = d,
									   gear = HybridAStar.Gear.Backward,
									   steer = HybridAStar.Steer.Right,
									   type = HybridAStar.MotionPrimitiveTypes.RR})
		-- reverse left
		table.insert(self.primitives, {dx = -dx, dy = dy, dt = -dt, d = d,
									   gear = HybridAStar.Gear.Backward,
									   steer = HybridAStar.Steer.Left,
									   type = HybridAStar.MotionPrimitiveTypes.RL})
	end
end

---@param node State3D
---@param primitive table
---@param hitchLength number hitch length of a trailer (length between hitch on the towing vehicle and the
--- rear axle of the trailer), can be nil
---@return State3D
function HybridAStar.MotionPrimitives:createSuccessor(node, primitive, hitchLength)
	local xSucc = node.x + primitive.dx * math.cos(node.t) - primitive.dy * math.sin(node.t)
	local ySucc = node.y + primitive.dx * math.sin(node.t) + primitive.dy * math.cos(node.t)
	-- if the motion primitive has a fixed heading, use that, otherwise the delta
	local tSucc = primitive.t or node.t + primitive.dt
	return State3D(xSucc, ySucc, tSucc, node.g, node, primitive.gear, primitive.steer,
			node:getNextTrailerHeading(primitive.d, hitchLength))
end

function HybridAStar.MotionPrimitives:__tostring()
	local output = ''
	for i, primitive in ipairs(self.primitives) do
		output = output .. string.format('%d: dx: %.4f dy: %.4f dt: %.4f d:%.4f\n', i, primitive.dx, primitive.dy, primitive.dt, primitive.d)
	end
	return output
end

function HybridAStar.MotionPrimitives:getPrimitives(node)
	return self.primitives
end

--- A simple set of motion primitives to use with an A* algorithm, pointing to 8 directions
---@param gridSize number search grid size in meters
HybridAStar.SimpleMotionPrimitives = CpObject(HybridAStar.MotionPrimitives)
function HybridAStar.SimpleMotionPrimitives:init(gridSize, allowReverse)
	-- motion primitive table:
	self.primitives = {}
	local d = gridSize
	local dSqrt2 = math.sqrt(2) * d
	table.insert(self.primitives, {dx =  d, dy =  0, dt = 0, d = d, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
	table.insert(self.primitives, {dx =  d, dy =  d, dt = 1 * math.pi / 4, d = dSqrt2, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
	table.insert(self.primitives, {dx =  0, dy =  d, dt = 2 * math.pi / 4, d = d, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
	table.insert(self.primitives, {dx = -d, dy =  d, dt = 3 * math.pi / 4 , d = dSqrt2, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
	table.insert(self.primitives, {dx = -d, dy =  0, dt = 4 * math.pi / 4, d = d, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
	table.insert(self.primitives, {dx = -d, dy = -d, dt = 6 * math.pi / 4, d = dSqrt2, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
	table.insert(self.primitives, {dx =  0, dy = -d, dt = 6 * math.pi / 4, d = d, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
	table.insert(self.primitives, {dx =  d, dy = -d, dt = 7 * math.pi / 4, d = dSqrt2, gear = HybridAStar.Gear.Forward, steer = HybridAStar.Steer.Straight, type = HybridAStar.MotionPrimitiveTypes.NA})
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

function HybridAStar.NodeList:getHeuristicValue(node, goal)
	local heuristicNode = self:get(node)
	if heuristicNode then
		local diff  = node:distance(goal) - heuristicNode.h
		if math.abs(diff) > 1 then
			print('diff', diff, node:distance(goal), heuristicNode.h)
		end
		return heuristicNode.h
	else
		return node:distance(goal)
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


function HybridAStar:init(yieldAfter, maxIterations, mustBeAccurate)
	self.count = 0
	self.yields = 0
	self.yieldAfter = yieldAfter or 200
	self.maxIterations = maxIterations or 40000
	self.mustBeAccurate = mustBeAccurate
	self.path = {}
	self.iterations = 0
	-- state space resolution
	self.deltaPos = 1.1
	self.deltaThetaDeg = 6
	-- if the goal is within self.deltaPos meters we consider it reached
	self.deltaPosGoal = 2 * self.deltaPos
	-- if the goal heading is within self.deltaThetaDeg degrees we consider it reached
	self.deltaThetaGoal = math.rad(self.deltaThetaDeg)
	self.maxDeltaTheta = courseplay.globalPathfinderSettings.maxDeltaAngleAtGoal:get()
	self.originalDeltaThetaGoal = self.deltaThetaGoal
	-- the same two parameters are used to discretize the continuous state space
	self.analyticSolverEnabled = true
	self.ignoreValidityAtStart = true
end


function HybridAStar:getMotionPrimitives(turnRadius, allowReverse)
	return HybridAStar.MotionPrimitives(turnRadius, 6.75, allowReverse)
end

---@param start State3D start node
---@param goal State3D goal node
---@param allowReverse boolean allow reverse driving
---@param constraints PathfinderConstraintInterface constraints (validity, penalty) for the pathfinder
--- must have the following functions defined:
---   getNodePenalty() function get penalty for a node, see getNodePenalty()
---   isValidNode()) function function to check if a node should even be considered
---   isValidAnalyticSolutionNode()) function function to check if a node of an analytic solution should even be considered.
---                              when we search for a valid analytic solution we use this instead of isValidNode()
---@param hitchLength number hitch length of a trailer (length between hitch on the towing vehicle and the
--- rear axle of the trailer), can be nil
function HybridAStar:findPath(start, goal, turnRadius, allowReverse, constraints, hitchLength)
	self:debug('Start pathfinding between %s and %s', tostring(start), tostring(goal))
	self.constraints = constraints
	-- a motion primitive is straight or a few degree turn to the right or left
	local hybridMotionPrimitives = self:getMotionPrimitives(turnRadius, allowReverse)
	-- create the open list for the nodes as a binary heap where
	-- the node with the lowest total cost is at the top
	local openList = BinaryHeap.minUnique(function(a, b) return a:lt(b) end)

	-- create the configuration space
	---@type HybridAStar.NodeList closedList
	self.nodes = HybridAStar.NodeList(self.deltaPos, self.deltaThetaDeg)

	if allowReverse then
		self.analyticSolver = ReedsSheppSolver()
	else
		self.analyticSolver = DubinsSolver()
	end

	if not constraints:isValidNode(goal, true) then
		self:debug('Goal node is invalid, abort pathfinding.')
		return true, nil, true
	end

	if not constraints:isValidAnalyticSolutionNode(goal) then
		-- goal node is invalid (for example in fruit), does not make sense to try analytic solutions
		self.goalNodeIsInvalid = true
	end

	start:updateH(goal, 0)
	self.distanceToGoal = start.h
	start:insert(openList)
	--self.nodes:add(start)

	self.iterations = 0
	self.expansions = 0
	self.yields = 0
	while openList:size() > 0 and self.iterations < self.maxIterations do
		-- pop lowest cost node from queue
		---@type State3D
		local pred = State3D.pop(openList)
		--self:debug('pop %s', tostring(pred))

		if pred:equals(goal, self.deltaPosGoal, self.deltaThetaGoal) then
			-- done!
			self:debug('Popped the goal (%d).', self.iterations)
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
			-- analytical expansion: try a Dubins/Reeds-Shepp path from here randomly, more often as we getting closer to the goal
			-- also, try it before we start with the pathfinding
			if pred.h then
				if self.analyticSolverEnabled and not self.goalNodeIsInvalid and
						(self.iterations == 1 or math.random() > 2 * pred.h / self.distanceToGoal) then
					---@type AnalyticSolution
					local analyticSolution, pathType = self.analyticSolver:solve(pred, goal, turnRadius, allowReverse)
					--self:debug('Check analytical solution at iteration %d, %.1f, %.1f', self.iterations, pred.h, pred.h / self.distanceToGoal)
					local analyticPath = analyticSolution:getWaypoints(pred, turnRadius)
					-- making sure we continue with the correct trailer heading
					analyticPath[1]:setTrailerHeading(pred:getTrailerHeading())
					State3D.calculateTrailerHeadings(analyticPath, hitchLength)
					if self:isPathValid(analyticPath) then
						State3D.printPath(analyticPath, 'ANALYTIC')
						self:debug('Found collision free analytic path (%s) at iteration %d', pathType, self.iterations)
						-- remove first node of returned analytic path as it is the same as pred
						table.remove(analyticPath, 1)
						self:rollUpPath(pred, goal, analyticPath)
						return true, self.path
					end
				end
			end
			-- create the successor nodes
			for _, primitive in ipairs(hybridMotionPrimitives:getPrimitives(pred)) do
				---@type State3D
				local succ = hybridMotionPrimitives:createSuccessor(pred, primitive, hitchLength)
				if succ:equals(goal, self.deltaPosGoal, self.deltaThetaGoal) then
					succ.pred = succ.pred
					self:debug('Successor at the goal (%d).', self.iterations)
					self:rollUpPath(succ, goal)
					return true, self.path
				end
				local existingSuccNode = self.nodes:get(succ)
				if not existingSuccNode or (existingSuccNode and not existingSuccNode:isClosed()) then
					-- ignore invalidity of a node in the first few iterations: this is due to the fact that sometimes
					-- we end up being in overlap with another vehicle when we start the pathfinding and all we need is
					-- an iteration or two to bring us out of that position
					if self.ignoreValidityAtStart and self.iterations < 3 or constraints:isValidNode(succ) then
						succ:updateG(primitive, constraints:getNodePenalty(succ))
						local analyticSolutionCost = 0
						if self.analyticSolverEnabled then
							local analyticSolution = self.analyticSolver:solve(succ, goal, turnRadius, allowReverse)
							analyticSolutionCost = analyticSolution:getLength(turnRadius)
							succ:updateH(goal, analyticSolutionCost)
						else
							succ:updateH(goal, 0, succ:distance(goal) * 1.5)
						end

						--self:debug('     %s', tostring(succ))
						if existingSuccNode then
							--self:debug('   existing node %s', tostring(existingSuccNode))
							-- there is already a node at this (discretized) position
							-- add a small number before comparing to adjust for floating point calculation differences
							if existingSuccNode:getCost() + 0.001 >= succ:getCost() then
								--self:debug('%.6f replacing %s with %s', succ:getCost() - existingSuccNode:getCost(),  tostring(existingSuccNode), tostring(succ))
								if openList:valueByPayload(existingSuccNode) then
									-- existing node is on open list already, remove it here, will replace with
									existingSuccNode:remove(openList)
								end
								-- add (update) to the state space
								self.nodes:add(succ)
								-- add to open list
								succ:insert(openList)
							else
								--self:debug('insert existing node back %s (iteration %d), diff %s', tostring(succ), self.iterations, tostring(succ:getCost() - existingSuccNode:getCost()))
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
					end -- valid node
				end
			end
			-- node as been expanded, close it to prevent expansion again
			--self:debug(tostring(pred))
			pred:close()
			self.expansions = self.expansions + 1
		end
		self.iterations = self.iterations + 1
		if self.iterations % 1000 == 0 then
			self:debug('iteration %d...', self.iterations)
		end
		local r = self.iterations / self.maxIterations
		-- as we reach the maximum iterations, relax our criteria to reach the goal: allow for arriving at
		-- bigger angle differences (except if we have to be accurate, for example combine self unloading must
		-- accurately find the trailer)
		if not self.mustBeAccurate then
			self.deltaThetaGoal = math.min(self.maxDeltaTheta,
					self.originalDeltaThetaGoal + courseplay.globalPathfinderSettings.deltaAngleRelaxFactor:get() * r)
		end
	end
	--self:printOpenList(openList)
	self.path = {}
	self:debug('No path found: iterations %d, yields %d, cost %.1f - %.1f, deltaTheta %.1f', self.iterations, self.yields,
            self.nodes.lowestCost, self.nodes.highestCost, math.deg(self.deltaThetaGoal))
    return true, nil
end

function HybridAStar:isPathValid(path)
	if not path or #path < 2 then return false end
	for i, n in ipairs(path) do
		if not self.constraints:isValidAnalyticSolutionNode(n) then
			return false
		end
	end
	return true
end

---@param node State3D
function HybridAStar:rollUpPath(node, goal, path)
	self.path = path or {}
	local currentNode = node
	self:debug('Goal node at %.2f/%.2f, cost %.1f (%.1f - %.1f)', goal.x, goal.y, node.cost,
			self.nodes.lowestCost, self.nodes.highestCost)
	table.insert(self.path, 1, currentNode)
	while currentNode.pred and currentNode ~= currentNode.pred do
		--self:debug('  %s', currentNode.pred)
		table.insert(self.path, 1, currentNode.pred)
		currentNode = currentNode.pred
	end
	-- start node always points forward, make sure it is reverse if the second node is reverse...
	self.path[1].gear = self.path[2] and self.path[2].gear or self.path[1].gear
	self:debug('Nodes %d, iterations %d, yields %d, deltaTheta %.1f', #self.path, self.iterations, self.yields,
			math.deg(self.deltaThetaGoal))
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
--- 3 dimensional as we do not take the heading into account and we use a different set of motion primitives
AStar = CpObject(HybridAStar)

function AStar:init(yieldAfter)
	HybridAStar.init(self, yieldAfter)
	-- this needs to be small enough that no vehicle fit between the grid points (and remain undetected)
	self.deltaPos = 3
	self.deltaPosGoal = self.deltaPos
	self.deltaThetaDeg = 181
	self.deltaThetaGoal = math.rad(self.deltaThetaDeg)
	self.maxDeltaTheta = math.pi
	self.originalDeltaThetaGoal = self.deltaThetaGoal
	self.analyticSolverEnabled = false
	self.ignoreValidityAtStart = false
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
---@param mustBeAccurate boolean must be accurately find the goal position/angle (optional)
function HybridAStarWithAStarInTheMiddle:init(hybridRange, yieldAfter, maxIterations, mustBeAccurate)
	-- path generation phases
	self.START_TO_MIDDLE = 1
	self.MIDDLE = 2
	self.MIDDLE_TO_END = 3
	self.ALL_HYBRID = 4 -- start and goal close enough, we only need a single phase with hybrid
	self.hybridRange = hybridRange
	self.yieldAfter = yieldAfter or 100
	self.hybridAStarPathfinder = HybridAStar(self.yieldAfter, maxIterations, mustBeAccurate)
	self.aStarPathfinder = self:getAStar()
end

function HybridAStarWithAStarInTheMiddle:getAStar()
	return AStar(self.yieldAfter)
end

---@param start State3D start node
---@param goal State3D goal node
---@param allowReverse boolean allow reverse driving
---@param constraints PathfinderConstraintInterface constraints (validity, penalty) for the pathfinder
--- must have the following functions defined:
---   getNodePenalty() function get penalty for a node, see getNodePenalty()
---   isValidNode()) function function to check if a node should even be considered
---   isValidAnalyticSolutionNode()) function function to check if a node of an analytic solution should even be considered.
---                              when we search for a valid analytic solution we use this instead of isValidNode()
---@param hitchLength number hitch length of a trailer (length between hitch on the towing vehicle and the
--- rear axle of the trailer), can be nil
function HybridAStarWithAStarInTheMiddle:start(start, goal, turnRadius, allowReverse, constraints, hitchLength)
	self.retries = 0
	self.startNode, self.goalNode = State3D:copy(start), State3D:copy(goal)
	self.originalStartNode = State3D:copy(self.startNode)
	self.turnRadius, self.allowReverse, self.hitchLength = turnRadius, allowReverse, hitchLength
	self.constraints = constraints
	self.hybridRange = self.hybridRange and self.hybridRange or turnRadius * 3
	-- how far is start/goal apart?
	self.startNode:updateH(self.goalNode, turnRadius)
	self.phase = self.MIDDLE
	self:debug('Finding direct path between start and goal...')
	self.coroutine = coroutine.create(self.aStarPathfinder.findPath)
	self.currentPathfinder = self.aStarPathfinder
	self.startToMiddleRetries = 0
	self.middleToEndRetries = 0
	self.allHybridRetries = 0
	self.constraints:resetConstraints()
	return self:resume(self.startNode, self.goalNode, turnRadius, false, constraints, hitchLength)
end

-- distance between start and goal is relatively short, one phase hybrid A* all the way
function HybridAStarWithAStarInTheMiddle:findHybridStartToEnd()
	self.phase = self.ALL_HYBRID
	self:debug('Goal is closer than %d, use one phase pathfinding only', self.hybridRange * 3)
	self.coroutine = coroutine.create(self.hybridAStarPathfinder.findPath)
	self.currentPathfinder = self.hybridAStarPathfinder
	return self:resume(self.startNode, self.goalNode, self.turnRadius, self.allowReverse, self.constraints, self.hitchLength)
end

-- start and goal far away, this is the hybrid A* from start to the middle section
function HybridAStarWithAStarInTheMiddle:findPathFromStartToMiddle()
	self:debug('Finding path between start and middle section...')
	self.phase = self.START_TO_MIDDLE
	-- generate a hybrid part from the start to the middle section's start
	self.coroutine = coroutine.create(self.hybridAStarPathfinder.findPath)
	self.currentPathfinder = self.hybridAStarPathfinder
	local goal = State3D(self.middlePath[1].x, self.middlePath[1].y, (self.middlePath[2] - self.middlePath[1]):heading())
	return self:resume(self.startNode, goal, self.turnRadius, self.allowReverse, self.constraints, self.hitchLength)
end

-- start and goal far away, this is the hybrid A* from the middle section to the goal
function HybridAStarWithAStarInTheMiddle:findPathFromMiddleToEnd()
	-- generate middle to end
	self.phase = self.MIDDLE_TO_END
	self:debug('Finding path between middle section and goal (allow reverse %s)...', tostring(self.allowReverse))
	self.coroutine = coroutine.create(self.hybridAStarPathfinder.findPath)
	self.currentPathfinder = self.hybridAStarPathfinder
	return self:resume(self.middleToEndStart, self.goalNode, self.turnRadius, self.allowReverse, self.constraints, self.hitchLength)
end

--- The resume() of this pathfinder is more complicated as it handles essentially three separate pathfinding runs
function HybridAStarWithAStarInTheMiddle:resume(...)
	local ok, done, path, goalNodeInvalid = coroutine.resume(self.coroutine, self.currentPathfinder, ...)
	if not ok then
		self.coroutine = nil
		return true, nil, goalNodeInvalid
	end
	if done then
		self.coroutine = nil
		if self.phase == self.ALL_HYBRID then
			if path then
				-- start and goal near, just one phase, all hybrid, we are done
				-- remove last waypoint as it is the approximate goal point and may not be aligned
				local result = Polygon:new(path)
				result:calculateData()
				result:space(math.pi / 20, 2)
				return true, result
			else
				if self.allHybridRetries < 1 then
					self:debug('all hybrid path did not work out, relax constraints and try again')
					self.allHybridRetries = self.allHybridRetries + 1
					self.constraints:relaxConstraints()
					return self:findHybridStartToEnd()
				end
			end
		elseif self.phase == self.MIDDLE then
			if not path then return true, nil end
			local lMiddlePath = HybridAStar.length(path)
			self:debug('Direct path is %d m', lMiddlePath)
			-- do we even need to use the normal A star or the nodes are close enough that the hybrid A star will be fast enough?
			if lMiddlePath < self.hybridRange * 2 then
				return self:findHybridStartToEnd()
			end
			-- middle part ready, now trim start and end to make room for the hybrid parts
			self.middlePath = path
			HybridAStar.shortenStart(self.middlePath, self.hybridRange)
			HybridAStar.shortenEnd(self.middlePath, self.hybridRange)
			if #self.middlePath < 2 then return true, nil end
			State3D.smooth(self.middlePath)
			State3D.setHeading(self.middlePath)
			State3D.calculateTrailerHeadings(self.middlePath, self.hitchLength, true)
			return self:findPathFromStartToMiddle()
		elseif self.phase == self.START_TO_MIDDLE then
			if path then
				-- start and middle sections ready, continue with the piece from the middle to the end
				-- but reset the constraints first (in case we relaxed them when building the start -> middle piece
				self.constraints:resetConstraints()
				self.path = path
				-- create start point at the last waypoint of middlePath before shortening
				self.middleToEndStart = State3D:copy(self.middlePath[#self.middlePath])
				-- now shorten both ends of middlePath to avoid short fwd/reverse sections due to overlaps (as the
				-- patfhinding may end anywhere within deltaPosGoal
				HybridAStar.shortenStart(self.middlePath,self.hybridAStarPathfinder.deltaPosGoal * 2)
				HybridAStar.shortenEnd(self.middlePath, self.hybridAStarPathfinder.deltaPosGoal * 2)
				-- append middle to start
				for i = 1, #self.middlePath do
					table.insert(self.path, self.middlePath[i])
				end
				return self:findPathFromMiddleToEnd()
			else
				if self.startToMiddleRetries < 1 then
					self:debug('start to middle did not work out, relax constraints and try again')
					self.startToMiddleRetries = self.startToMiddleRetries + 1
					self.constraints:relaxConstraints()
					return self:findPathFromStartToMiddle()
				else
					self:debug('start to middle: we already tried with relaxed constraints, this did not work out')
					return true, nil, goalNodeInvalid
				end
			end
		elseif self.phase == self.MIDDLE_TO_END then
			if path then
				-- last piece is ready, this was generated from the goal point to the end of the middle section so
				-- first remove the last point of the middle section to make the transition smoother
				-- and then add the last section in reverse order
				-- also, for reasons we don't fully understand, this section may have a direction change at the last waypoint,
				-- so we just ignore the last one
				for i = 1, #path do
					table.insert(self.path, path[i])
				end
				State3D.smooth(self.path)
			else
				if self.middleToEndRetries < 1 then
					self:debug('middle to end did not work out, relax constraints and retry')
					self.middleToEndRetries = self.middleToEndRetries + 1
					self.constraints:relaxConstraints()
					return self:findPathFromMiddleToEnd()
				else
					self:debug('middle to end: we already tried with relaxed constraints, this did not work out')
					return true, nil, goalNodeInvalid
				end
			end
			return true, self.path
		end
	end
	return false
end


--- Dummy A* pathfinder implementation, does not calculate a path, just returns a pre-calculated path passed in 
--- to its constructor. 
---@see HybridAStarWithPathInTheMiddle
---@class DummyAStar : HybridAStar
DummyAStar = CpObject(HybridAStar)

---@param path State3D[] collection of nodes defining the configuration space
function DummyAStar:init(path)
	self.path = path
end

function DummyAStar:findPath()
	return true, self.path
end

--- Similar to HybridAStarWithAStarInTheMiddle, but the middle section is not calculated using the A*, instead
--- it is passed in to to constructor, already created by the caller. 
--- This is used to find a path on the headland to the next row. The headland section is calculated by the caller
--- based on the vehicle's course, HybridAStarWithPathInTheMiddle only finds the path from the vehicle's position
--- to the headland and from the headland to the start of the next row.   
HybridAStarWithPathInTheMiddle = CpObject(HybridAStarWithAStarInTheMiddle)

---@param hybridRange number range in meters around start/goal to use hybrid A *
---@param yieldAfter number coroutine yield after so many iterations (number of iterations in one update loop)
---@param path State3D[] path to use in the middle part
function HybridAStarWithPathInTheMiddle:init(hybridRange, yieldAfter, path)
	self.path = path
	self:debug('Start pathfinding on headland, hybrid A* range is %.1f, %d points on headland', hybridRange, #path)
	HybridAStarWithAStarInTheMiddle.init(self, hybridRange, yieldAfter, 10000)
end

function HybridAStarWithPathInTheMiddle:getAStar()
	return DummyAStar(self.path)
end