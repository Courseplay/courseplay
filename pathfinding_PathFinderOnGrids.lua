-- Path finder algorithms that are optimized for grids

local pathfinding = courseplay.pathfinding;
-- pathfinding.helpers = {}; --already done in algo_helpers - don't overwrite!
local helpers = pathfinding.helpers;
local Finders = {};

--[[ Using example:
-- create Grid
local hjsGrid = courseplay.pathfinding.helpers.Grid:new(tileSize, course.waypoints, 'cx', 'cz');
hjsGrid:setEvaluationFunction(myEvalFunc);
hjsGrid:evaluate();
-- create Finder and search a path
local hjsFinder = courseplay.pathfinding.Pathfinder:new(hjsGrid, 'HJS');
hjsFinder:setMode('ORTHOGONAL');
local hjsPath = hjsFinder:getPath(from.x, from.y, to.x, to.y)
--]]


--===================================================================================
--***********************************************************************************
--===================================================================================

-- Finders:


--[[===================================================================================--]]


--[[
Horoman Jump Search:
Algorithm developed by Roman Hofstetter (horoman) in 2013

This algorithm solves a shortest path problem on a two dimensional discrete map
where each node belongs to a category and 
has some crossing costs assigned which are grater or equal the Euclidean distance.
The categories are prioritized and the algorithm does not care about the costs of a category as long as the costs of the higher priority categories are minimized.

The algorithm is thought to be used on grid maps with areas of nodes of the same category and costs.
It is built on the so called Jump Point Search which itself has it seeds in the label correcting algorithm, in particular on the A*-algorithm.
--]]

local abs = math.abs
local sqrt = math.sqrt
local sqrt2 = sqrt(2)
local max, min = math.max, math.min

local function getG(finder, node, parent)
	local x, y = node.x, node.y;
	local dx, dy = node.x-parent.x, node.y-parent.y;
	local absX, absY = math.abs(dx), math.abs(dy);
	local costs = finder.grid:getCostsAt(x,y);
	local distance = ( (absX == absY) and sqrt2*absX ) or ( (absY==0) and absX) or (absX==0 and absY); --EUCLIDIAN distance

	local g = {};
	for i = 1,#parent.g do
		g[i] = parent.g[i];
	end
	
	if finder.grid:moreExpensive(x,y,x-dx,y-dy) == 0 then
		g[node.category] = parent.g[node.category] + distance*costs;
	elseif absX==0 and absY==1 or absX==1 and absY==0 or absX == 1 and absY==1 then
		local costs1 = finder.grid:getCostsAt(x-dx,y-dy);
		g[node.category] = parent.g[node.category] + distance/2*costs;
		g[parent.category] = parent.g[parent.category] + distance/2*costs1;
	else
	-- should never happen, to test:
		print('Fatal error in hjs ;-)');
		print(tostring(absX) .. ' / ' .. tostring(absY))
	end
	
	return g;
end

local function findNeighbours(finder, node, tunnel)
	if node.parent then
		local neighbours = {}
		local x,y = node.x, node.y
		-- Node have a parent, we will prune some neighbours
		-- Gets the direction of move
		local dx = (x-node.parent.x)/max(abs(x-node.parent.x),1)
		local dy = (y-node.parent.y)/max(abs(y-node.parent.y),1)
	
		-- Diagonal move case
		if dx~=0 and dy~=0 then
			local walkY, walkX
	
			-- Natural neighbours
			if finder.grid:isWalkableAt(x,y+dy) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y+dy)
			  walkY = true
			end
			if finder.grid:isWalkableAt(x+dx,y) then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y)
			  walkX = true
			end
			if walkX or walkY then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y+dy)
			end
	
			-- Forced neighbours
			if ((not finder.grid:isWalkableAt(x-dx,y)) or (finder.grid:moreExpensive(x,y,x-dx,y)==2)) and walkY then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x-dx,y+dy)
			end
			if ((not finder.grid:isWalkableAt(x,y-dy)) or (finder.grid:moreExpensive(x,y,x,y-dy)==2)) and walkX then
			  neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y-dy)
			end
	
		-- Move along Y-axis case
		elseif dx==0 then
			local walkY
			if finder.grid:isWalkableAt(x,y+dy) then
				neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y+dy)
	
				if finder.allowDiagonal then
					-- Forced neighbours are left and right ahead along Y
					if ((not finder.grid:isWalkableAt(x+1,y)) or (finder.grid:moreExpensive(x,y,x+1,y)==2)) then
						neighbours[#neighbours+1] = finder.grid:getNodeAt(x+1,y+dy)
					end
					if ((not finder.grid:isWalkableAt(x-1,y)) or (finder.grid:moreExpensive(x,y,x-1,y)==2)) then
						neighbours[#neighbours+1] = finder.grid:getNodeAt(x-1,y+dy)
					end
				end
			end
			-- In case diagonal moves are forbidden : Needs to be optimized
			if not finder.allowDiagonal then
				if finder.grid:isWalkableAt(x+1,y) then
					neighbours[#neighbours+1] = finder.grid:getNodeAt(x+1,y)
				end
				if finder.grid:isWalkableAt(x-1,y)
					then neighbours[#neighbours+1] = finder.grid:getNodeAt(x-1,y)
				end
			end
			
		-- Move along X-axis case
		else
			if finder.grid:isWalkableAt(x+dx,y) then
				neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y)
	
				if finder.allowDiagonal then
					-- Forced neighbours are up and down ahead along X
					if ((not finder.grid:isWalkableAt(x,y+1)) or (finder.grid:moreExpensive(x,y,x,y+1)==2)) then
						neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y+1)
					end
					if ((not finder.grid:isWalkableAt(x,y-1)) or (finder.grid:moreExpensive(x,y,x,y-1)==2)) then
						neighbours[#neighbours+1] = finder.grid:getNodeAt(x+dx,y-1)
					end
				end
			end
			-- : In case diagonal moves are forbidden
			if not finder.allowDiagonal then
				if finder.grid:isWalkableAt(x,y+1) then
					neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y+1)
				end
				if finder.grid:isWalkableAt(x,y-1) then
					neighbours[#neighbours+1] = finder.grid:getNodeAt(x,y-1)
				end
			 end
		end
		return neighbours
	end

	-- Node do not have parent, we return all neighbouring nodes
	return finder.grid:getNeighbours(node, finder.allowDiagonal, tunnel);
end

local function jump(finder, node, parent, endNode, disallowRecursion)
	if not node then return end

	local x,y = node.x, node.y
	local dx, dy = x - parent.x,y - parent.y

	-- If the node to be examined is unwalkable, return nil
	if not finder.grid:isWalkableAt(x,y) then return end

	-- If the node to be examined is the endNode, return this node
	if node == endNode then return node end
	
	-- If the node to be examined has different costs than parent, return this node
	if finder.grid:moreExpensive(x, y, x-dx, y-dy)~=0 then 
		courseplay:debug('\t\t\t1', 4);
		return node 
	end;
	
	-- If we are before a cost change, return node
	if dx~=0 and dy~=0 and
		( (finder.grid:isWalkableAt(x+dx,y) and finder.grid:moreExpensive(x, y, x+dx, y)~=0) or 
		(finder.grid:isWalkableAt(x,y+dy) and finder.grid:moreExpensive(x, y, x, y+dy)~=0) ) then
		courseplay:debug('\t\t\t2', 4);
		return node;
	end
	if (finder.grid:isWalkableAt(x+dx,y+dy) and finder.grid:moreExpensive(x, y, x+dx, y+dy)~=0) then
		courseplay:debug('\t\t\t3', 4);
		return node
	end;

	-- Diagonal search case
	if dx~=0 and dy~=0 then
		-- Current node is a jump point if one of his leftside/rightside neighbours ahead is forced
		-- Current node is a jump point if it is less expensive than one of his leftside/rightside neighbours
		if (finder.grid:isWalkableAt(x-dx,y+dy) and ((not finder.grid:isWalkableAt(x-dx,y)) or (finder.grid:moreExpensive(x,y,x-dx,y)==2))) or
		(finder.grid:isWalkableAt(x+dx,y-dy) and ((not finder.grid:isWalkableAt(x,y-dy)) or (finder.grid:moreExpensive(x,y,x,y-dy)==2))) then
			courseplay:debug('\t\t\t4', 4);
			return node;
		end	
	
	-- Search along X-axis case
	elseif dx~=0 then
		if finder.allowDiagonal then
			-- Current node is a jump point if one of his upside/downside neighbours is forced
			if (finder.grid:isWalkableAt(x+dx,y+1) and ((not finder.grid:isWalkableAt(x,y+1)) or (finder.grid:moreExpensive(x,y,x,y+1)==2))) or
			(finder.grid:isWalkableAt(x+dx,y-1) and ((not finder.grid:isWalkableAt(x,y-1)) or (finder.grid:moreExpensive(x,y,x,y-1)==2))) then
				courseplay:debug('\t\t\t5', 4);
				return node;
			end
		else
			-- : in case diagonal moves are forbidden
			if (finder.grid:isWalkableAt(x,y+1,finder.walkable) and ((not finder.grid:isWalkableAt(x-dx,y+1)) or (finder.grid:moreExpensive(x,y,x-dx,y+1)==2))) or 
			(finder.grid:isWalkableAt(x,y-1,finder.walkable) and ((not finder.grid:isWalkableAt(x-dx,y-1)) or (finder.grid:moreExpensive(x,y,x-dx,y-1)==2))) then
				courseplay:debug('\t\t\t5b', 4);
				return node;
			end
		end
		
	-- Search along Y-axis case
	else		
		-- Current node is a jump point if one of his leftside/rightside neighbours is forced
		if finder.allowDiagonal then
			if (finder.grid:isWalkableAt(x+1,y+dy) and ((not finder.grid:isWalkableAt(x+1,y)) or (finder.grid:moreExpensive(x,y,x+1,y)==2))) or
			(finder.grid:isWalkableAt(x-1,y+dy) and ((not finder.grid:isWalkableAt(x-1,y)) or (finder.grid:moreExpensive(x,y,x-1,y)==2))) then
				courseplay:debug('\t\t\t6', 4);
				return node;
			end
		else
			-- : in case diagonal moves are forbidden
			if (finder.grid:isWalkableAt(x+1,y,finder.walkable) and ((not finder.grid:isWalkableAt(x+1,y-dy)) or (finder.grid:moreExpensive(x,y,x+1,y-dy)==2))) or
			(finder.grid:isWalkableAt(x-1,y,finder.walkable) and ((not finder.grid:isWalkableAt(x-1,y-dy)) or (finder.grid:moreExpensive(x,y,x-1,y-dy)==2))) then
				courseplay:debug('\t\t\t6b', 4);
				return node;
			end
		end
	end

	-- Since we arrived here: No reason to stop so far, so let's search recursively for a jump node:
	if dx~=0 and dy~=0 then
		if jump(finder,finder.grid:getNodeAt(x+dx,y),node,endNode) then courseplay:debug('\t\t\t7', 4); return node end
		if jump(finder,finder.grid:getNodeAt(x,y+dy),node,endNode) then courseplay:debug('\t\t\t8', 4); return node end
		if finder.grid:isWalkableAt(x+dx,y) or finder.grid:isWalkableAt(x,y+dy) then
			return jump(finder,finder.grid:getNodeAt(x+dx,y+dy),node,endNode);
		end
	elseif dx ~=0 then
		if (not finder.allowDiagonal) and (not disallowRecursion) then
			if jump(finder,finder.grid:getNodeAt(x,y+1), node, endNode, true) or jump(finder,finder.grid:getNodeAt(x,y-1), node, endNode, true) then courseplay:debug('\t\t\t9', 4); return node end
		end
		if finder.grid:isWalkableAt(x+dx,y) then
			return jump(finder,finder.grid:getNodeAt(x+dx,y),node,endNode, disallowRecursion);
		end		
	else
		if (not finder.allowDiagonal) and (not disallowRecursion) then
			if jump(finder,finder.grid:getNodeAt(x+1,y), node, endNode, true) or jump(finder,finder.grid:getNodeAt(x-1,y), node, endNode, true) then courseplay:debug('\t\t\t10', 4); return node end
		end
		if finder.grid:isWalkableAt(x,y+dy) then
			return jump(finder,finder.grid:getNodeAt(x,y+dy),node,endNode, disallowRecursion);
		end
	end
end

local function identifySuccessors(finder,node,endNode,toClear, tunnel)
	-- Gets the valid neighbours of the given node
	-- Looks for a jump point in the direction of each neighbour
	local neighbours = findNeighbours(finder,node, tunnel);
	for i = #neighbours,1,-1 do
		local skip = false;
		local neighbour = neighbours[i];
		-- print(string.format('\tneighbour: x,y: %d,%d / cat: %d', neighbour.x, neighbour.y, neighbour.category));
		
		local jumpNode = jump(finder,neighbour,node,endNode);
		if jumpNode then
			-- print(string.format('\t\tjump: x,y: %d,%d / cat: %d', jumpNode.x, jumpNode.y, jumpNode.category));
		else
			-- print('\t\tjump: none');
		end
		
		-- : in case a diagonal jump point was found in straight mode, skip it.
		if jumpNode and not finder.allowDiagonal then
			if ((jumpNode.x ~= node.x) and (jumpNode.y ~= node.y)) then skip = true end
		end

		-- Performs regular A-star on a set of jump points
		if jumpNode and not skip then
			-- Update the jump node
			local newG = getG(finder, jumpNode, node);
			jumpNode.h = jumpNode.h or (finder.heuristic(jumpNode.x-endNode.x,jumpNode.y-endNode.y));
			if jumpNode:isBetterG(newG) and endNode:isBetterG(newG, jumpNode.h) then
				toClear[jumpNode] = true; -- Records this node to reset its properties later.
				jumpNode.g = newG;
				jumpNode.parent = node;
				if not jumpNode.inBin then
					finder.openList:push(jumpNode);  --, jumpNode.category);
					jumpNode.inBin = true;
				else
					finder.openList:heapify(jumpNode); --, jumpNode.category);
				end
			end
		end -- if not skip
	end
end



function Finders.HJS(finder, startNode, endNode, toClear, tunnel)
	startNode.f = 0; -- not true but does not matter for startNode
	for i = 1,finder.grid.categoryMax do
		startNode.g[i] = 0; -- costs from startNode
	end
	finder.openList:clear();
	finder.openList:push(startNode);   --, startNode.category);
	startNode.inBin = true;
	toClear[startNode] = true;

	local node;
	while not finder.openList:empty() do
		-- Pops the lowest F-cost node, moves it in the closed list
		node = finder.openList:pop();
		node.inBin = false;
		-- print(string.format('work on node: x,y: %d,%d / cat: %d / Bin: %d', node.x, node.y, node.category, finder.openList.size));
		
		-- If the popped node is the endNode, return it
		if node == endNode then
			return node;
		end
		
		-- otherwise, identify successors of the popped node
		identifySuccessors(finder, node, endNode, toClear, tunnel);
	end

	-- No path found, return nil
	return nil;
end

--[[===================================================================================--]]

-- Here is the place for finder 2
-- (none yet...)


--===================================================================================
--***********************************************************************************
--===================================================================================

--PATHFINDER
--local function isAGrid(grid)
--	return getmetatable(grid) and getmetatable(getmetatable(grid)) == helpers.Grid
--end

local function collect_keys(t)
	local keys = {}
	for k,v in pairs(t) do keys[#keys+1] = k end
	return keys
end

local toClear = {}

local function reset()
	for node in pairs(toClear) do
	  node.g, node.h, node.f = nil, nil, nil
	  node.opened, node.closed, node.parent = nil, nil, nil
	end
	toClear = {}
end

local searchModes = {['DIAGONAL'] = true, ['ORTHOGONAL'] = true}

local function traceBackPath(finder, node, startNode)
	local path = helpers.Path:new()
	path.grid = finder.grid
	local lastPathCost = node.f or path:getLength() --todo adapt?

	while node.parent do
		table.insert(path,1,node)
		node = node.parent
	end
	table.insert(path,1,startNode)
	return path, lastPathCost;
end

pathfinding.Pathfinder = {}
pathfinding.Pathfinder.__index = pathfinding.Pathfinder

function pathfinding.Pathfinder:new(grid, finderName, walkable)
	local newPathfinder = {}
	setmetatable(newPathfinder, pathfinding.Pathfinder)
	newPathfinder:setGrid(grid)
	newPathfinder:setFinder(finderName)
--	newPathfinder:setWalkable(walkable)
	newPathfinder:setMode('DIAGONAL')
	newPathfinder:setHeuristic('EUCLIDIAN')
	newPathfinder.openList = helpers.Heap:new()
	return newPathfinder
end

function pathfinding.Pathfinder:setGrid(grid)
	--assert(isAGrid(grid), 'Bad argument #1. Expected a \'grid\' object') --TODO !!!
	self.grid = grid
	self.grid.__eval = self.walkable and type(self.walkable) == 'function'
	return self
end

function pathfinding.Pathfinder:getGrid()
	return self.grid
end

function pathfinding.Pathfinder:setWalkable(walkable)
	--assert(('stringintfunctionnil'):match(type(walkable)), ('Bad argument #2. Expected \'string\', \'number\' or \'function\', got %s.'):format(type(walkable))) --TODO !!!
	self.walkable = walkable
	self.grid.__eval = type(self.walkable) == 'function'
	return self
end

function pathfinding.Pathfinder:getWalkable()
	return self.walkable
end

function pathfinding.Pathfinder:setFinder(finderName)
	local finderName = finderName
	if not finderName then
		if not self.finder then 
			finderName = 'ASTAR' 
		else return 
		end
	end
	assert(Finders[finderName],'Not a valid finder name!')
	self.finder = finderName
	return self
end

function pathfinding.Pathfinder:getFinder()
	return self.finder
end

function pathfinding.Pathfinder:getFinders()
	return collect_keys(Finders)
end

function pathfinding.Pathfinder:setHeuristic(heuristic)
	assert(helpers.Heuristics[heuristic] or (type(heuristic) == 'function'), 'Not a valid heuristic!');
	self.heuristic = helpers.Heuristics[heuristic] or heuristic
	return self
end

function pathfinding.Pathfinder:getHeuristic()
	return self.heuristic
end

function pathfinding.Pathfinder:getHeuristics()
	return collect_keys(helpers.Heuristics)
end

function pathfinding.Pathfinder:setMode(mode)
	assert(searchModes[mode],'Invalid mode')
	self.allowDiagonal = (mode == 'DIAGONAL')
	return self
end

function pathfinding.Pathfinder:getMode()
	return (self.allowDiagonal and 'DIAGONAL' or 'ORTHOGONAL')
end

function pathfinding.Pathfinder:getModes()
	return collect_keys(searchModes)
end

function pathfinding.Pathfinder:version()
	return _VERSION, _RELEASEDATE
end

function pathfinding.Pathfinder:getPath(startX, startY, endX, endY, tunnel)
	reset();
	print(string.format('getPath([start] %.1f,%.1f, [end] %.1f,%.1f, [tunnel] %s)', startX, startY, endX, endY, tostring(tunnel)));
	-- local startIndexX, startIndexY = self.grid:getIndexAt(startX, startY);
	-- local endIndexX, endIndexY = self.grid:getIndexAt(endX, endY);
	local startIndexX, startIndexY = self.grid:getIndexAt(startY, startX); --since x and y are switched, we also need to pass them switched to getIndexAt()
	local endIndexX, endIndexY = self.grid:getIndexAt(endY, endX);

	local startNode = self.grid:getNodeAt(startIndexX, startIndexY);
	local endNode = self.grid:getNodeAt(endIndexX, endIndexY);
	print(string.format('\tstartIndexX=%s, startIndexY=%s', tostring(startIndexX), tostring(startIndexY)));
	print(string.format('\tendIndexX=%s, endIndexY=%s', tostring(endIndexX), tostring(endIndexY)));
	print(string.format('\tstartNode=%s, endNode=%s', tostring(startNode), tostring(endNode)));
	assert(startNode, ('Invalid location [%d (%d), %d (%d)]'):format(startX, startIndexX, startY, startIndexY));
	assert(endNode and self.grid:isWalkableAt(endIndexX, endIndexY), ('Invalid or unreachable location [%d (%d), %d (%d)]'):format(endX, endIndexX, endY, endIndexY));
	local _endNode = Finders[self.finder](self, startNode, endNode, toClear, tunnel);
	if _endNode then 
		return traceBackPath(self, _endNode, startNode);
	end
	
	return nil, 0
end
