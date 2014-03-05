-- Helper functions and structures for several algorithms

local pathfinding = courseplay.pathfinding;
pathfinding.helpers = {};
local helpers = pathfinding.helpers;


--===================================================================================
--***********************************************************************************
--===================================================================================

-- Grid --

-- Standard evaluation function
local function evalMapAt(grid, x, y)
	return 1, true, 1;
end

--[[ Horoman's Grid:
grid.limits.minX
grid.limits.maxX
grid.limits.minY
grid.limits.maxY
grid.limits.maxIndexX
grid.limits.maxIndexY
grid.tileSize
grid.map[][] = {category, walkable, costs}
grid._evaluationFunction
grid.polygon = {points, xName, yName}
--]]

helpers.Grid = {};
helpers.Grid.__index = helpers.Grid;

-- Offsets for straights moves
helpers.Grid.straightOffsets = {
	{x = 1, y = 0} --[[W]], {x = -1, y =  0}, --[[E]]
	{x = 0, y = 1} --[[S]], {x =  0, y = -1}, --[[N]]
}

-- Offsets for diagonal moves
helpers.Grid.diagonalOffsets = {
	{x = -1, y = -1} --[[NW]], {x = 1, y = -1}, --[[NE]]
	{x = -1, y =  1} --[[SW]], {x = 1, y =  1}, --[[SE]]
}

function helpers.Grid:new(tileSize, polygon, xName, yName)
	local newGrid = {polygon={}, map={}, nodes={}, limits={}, _evaluationFunction=evalMapAt};
	setmetatable(newGrid, self);
	--self.__index = self;
	
	newGrid.tileSize = tileSize or 1;
	newGrid.polygon.xName = xName or 'x';
	newGrid.polygon.yName = yName or 'y';
	newGrid.polygon.points = polygon;
	newGrid:findLimits();
		
	return newGrid;
end

function helpers.Grid:getIndexAt(x, y)
	local indexX = Utils.clamp(math.ceil((x - self.limits.minX) / self.tileSize), 1, self.limits.maxIndexX);
	local indexY = Utils.clamp(math.ceil((y - self.limits.minY) / self.tileSize), 1, self.limits.maxIndexY);
	return indexX, indexY;
end

function helpers.Grid:getX(IndexX)
	local x;
	if IndexX > 0 and IndexX < self.limits.maxIndexX then
		x = self.limits.minX - self.tileSize/2 + (IndexX*self.tileSize);
	elseif IndexX == self.limits.maxIndexX then
		local prevX = (self.limits.minX - self.tileSize/2 + ((IndexX-1)*self.tileSize));
		x = prevX + (self.limits.maxX - prevX)/2;
	end
	return x
end

function helpers.Grid:getY(IndexY)
	local y;
	if IndexY > 0 and IndexY < self.limits.maxIndexY then
		y = self.limits.minY - self.tileSize/2 + (IndexY*self.tileSize);
	elseif IndexY == self.limits.maxIndexY then
		local prevY = (self.limits.minY - self.tileSize/2 + ((IndexY-1)*self.tileSize));
		y = prevY + (self.limits.maxY - prevY)/2;
	end
	return y
end

function helpers.Grid:findLimits()
	local minX, maxX
	local minY, maxY
	local x, y

	for k, point in pairs(self.polygon.points) do
		x = point[self.polygon.xName];
		y = point[self.polygon.yName];
		minX = not minX and x or (x<minX and x or minX)
		maxX = not maxX and x or (x>maxX and x or maxX)
		minY = not minY and y or (y<minY and y or minY)
		maxY = not maxY and y or (y>maxY and y or maxY)
	end
	
	self.limits.minX = minX;
	self.limits.maxX = maxX;
	self.limits.minY = minY;
	self.limits.maxY = maxY;
	self.limits.maxIndexX = math.ceil((maxX-minX)/self.tileSize);
	self.limits.maxIndexY = math.ceil((maxY-minY)/self.tileSize);
end

function helpers.Grid:isInRange(indexX, indexY)
	return not ( (indexX < 1 or indexX > self.limits.maxIndexX) or (indexY < 1 or indexY > self.limits.maxIndexY) );
end

function helpers.Grid:isPointInPolygon(x,y)
--@src: http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
		
	local j;
	local point = self.polygon.points;
	local N = #point;
	local xName, yName = self.polygon.xName, self.polygon.yName;
	local inside = false;
	
	for i = 1, N do
		j = i == 1 and N or i-1;
		xi, yi = point[i][xName], point[i][yName];
		xj, yj = point[j][xName], point[j][yName];
		if ( (yi > y) ~= (yj > y) ) and (x < (xj-xi) * (y-yi) / (yj-yi) + xi) then
			inside = not inside;
		end
	end
	
	return inside;
end

function helpers.Grid:setEvaluationFunction(evalFunction)
	self._evaluationFunction = evalFunction;
end

function helpers.Grid:evaluate()
	local category, walkable, costs;
	local x, y;
	for indexY = 1,self.limits.maxIndexY do
		y = self:getY(indexY);
		if not self.map[indexY] then
			self.map[indexY] = {};
		end
		for indexX = 1,self.limits.maxIndexX do
			x = self:getX(indexX);
			if self:isPointInPolygon(x,y) then
				category, walkable, costs = self:_evaluationFunction(x, y);
			else
				category, walkable, costs = 1, false, 1;
			end
			self.map[indexY][indexX] = {category=category, walkable=walkable, costs=costs};
			self.categoryMax = not self.categoryMax and category or ((self.categoryMax < category and category) or self.categoryMax);
		end
	end;

	-- print(self:getVisualGrid());
end;

function helpers.Grid:getVisualGrid()
	-- category: 1 = no fruit, 2 = fruit
	-- walkable: true = walkable, false = not walkable
	-- costs:	 1 = ?
	local output = '';
	for indexY = 1, self.limits.maxIndexY do
		local line = '';
		for indexX = 1, self.limits.maxIndexX do
			local data = self.map[indexY][indexX];
			local col = ' ';
			if not data.walkable then
				col = 'X';
			elseif data.category == 2 then
				col = 'F';
			end;
			line = line .. col;
		end;
		output = output .. line .. '\n';
	end;

	return output;
end;

function helpers.Grid:getCategoryAt(indexX, indexY)
	return self.map[indexY][indexX].category;
end

function helpers.Grid:isWalkableAt(indexX, indexY)
	if self:isInRange(indexX, indexY) then
		return self.map[indexY][indexX].walkable;
	else
		return false;
	end
end

function helpers.Grid:getCostsAt(indexX, indexY)
	if self:isInRange(indexX, indexY) then
		return self.map[indexY][indexX].costs;
	end
end

function helpers.Grid:moreExpensive(indexX1, indexY1, indexX2, indexY2)
	local result = 0;
	if self.map[indexY1][indexX1].category > self.map[indexY2][indexX2].category then
		result = 1;
	elseif self.map[indexY1][indexX1].category < self.map[indexY2][indexX2].category then
		result = 2;
	else
		if self.map[indexY1][indexX1].costs > self.map[indexY2][indexX2].costs then
			result = 1;
		elseif self.map[indexY1][indexX1].costs < self.map[indexY2][indexX2].costs then
			result = 2;
		end
	end
	return result;
end

function helpers.Grid:getNodeAt(indexX, indexY)
	local node = nil;
	if self:isInRange(indexX, indexY) then
		if not self.nodes[indexY] then
			self.nodes[indexY] = {};
		end
		if not self.nodes[indexY][indexX] then
			local category = self:getCategoryAt(indexX, indexY);
			self.nodes[indexY][indexX] = helpers.NodeClass:new(indexX, indexY, category);
		end		
		node = self.nodes[indexY][indexX];
	end
	return node;
end

function helpers.Grid:getNeighbours(node, allowDiagonal, tunnel)
	local neighbours = {};
	for i = 1,#helpers.Grid.straightOffsets do
		local n = self:getNodeAt(node.x + helpers.Grid.straightOffsets[i].x, node.y + helpers.Grid.straightOffsets[i].y);
		if n and self:isWalkableAt(n.x, n.y) then
			neighbours[#neighbours+1] = n;
		end
	end

	if allowDiagonal then
		tunnel = not not tunnel;
		for i = 1,#helpers.Grid.diagonalOffsets do
			local n = self:getNodeAt(node.x + helpers.Grid.diagonalOffsets[i].x, node.y + helpers.Grid.diagonalOffsets[i].y);
			if n and self:isWalkableAt(n.x, n.y) then
				if tunnel then
					neighbours[#neighbours+1] = n;
				else
					-- avoid this situation:
					--  nw  w
					--  w   nw
					local skipThisNode = false;
					local n1 = self:getNodeAt(node.x+helpers.Grid.diagonalOffsets[i].x, node.y);
					local n2 = self:getNodeAt(node.x, node.y+helpers.Grid.diagonalOffsets[i].y);
					if ((n1 and n2) and not self:isWalkableAt(n1.x, n1.y) and not self:isWalkableAt(n2.x, n2.y)) then
						skipThisNode = true;
					end
					if not skipThisNode then neighbours[#neighbours+1] = n; end
				end
			end
		end
	end

	return neighbours
end

--===================================================================================
--***********************************************************************************
--===================================================================================

-- Path
helpers.Path = {}
helpers.Path.__index = helpers.Path

function helpers.Path:new()
	return setmetatable({}, helpers.Path)
end
function helpers.Path:iter()
	local i,pathLen = 1,#self
	return function()
		if self[i] then
			i = i+1
			return self[i-1],i-1
		end
	end
end
helpers.Path.nodes = helpers.Path.iter
function helpers.Path:getLength()
	local len = 0
	for i = 2,#self do
		local dx = self[i].x - self[i-1].x
		local dy = self[i].y - self[i-1].y
		len = len + helpers.Heuristics.EUCLIDIAN(dx, dy)
	end
	return len
end


--===================================================================================
--***********************************************************************************
--===================================================================================

--HEAP
local floor = math.floor

-- Lookup for value in a table
local indexOf = function(t,v)
	for i = 1,#t do
		if t[i] == v then return i end
	end
	return nil
end

-- Default comparison function
local function f_min(a,b) 
	return a < b 
end

-- Percolates up
local function percolate_up(heap, index)
	if index == 1 then return end
	local pIndex
	if index <= 1 then return end
	if index%2 == 0 then
		pIndex =  index/2
	else
		pIndex = (index-1)/2
	end
	if not heap.sort(heap.__heap[pIndex], heap.__heap[index]) then
		heap.__heap[pIndex], heap.__heap[index] = 
		heap.__heap[index], heap.__heap[pIndex]
		percolate_up(heap, pIndex)
	end
end

local function percolate_down(heap,index)
	local lfIndex,rtIndex,minIndex
	lfIndex = 2*index
	rtIndex = lfIndex + 1
	if rtIndex > heap.size then
		if lfIndex > heap.size then
			return
		else 
			minIndex = lfIndex
		end
	else
		if heap.sort(heap.__heap[lfIndex],heap.__heap[rtIndex]) then
			minIndex = lfIndex
		else
			minIndex = rtIndex
		end
	end
	if not heap.sort(heap.__heap[index],heap.__heap[minIndex]) then
		heap.__heap[index],heap.__heap[minIndex] = heap.__heap[minIndex],heap.__heap[index]
		percolate_down(heap,minIndex)
	end
end

helpers.Heap = {};
helpers.Heap.__index = helpers.Heap

function helpers.Heap:new(template,comp)
	--return setmetatable({__heap = {}, sort = comp or f_min, size = 0}, template)
	return setmetatable({__heap = {}, sort = comp or f_min, size = 0}, template or helpers.Heap)
end

function helpers.Heap:empty()
	return (self.size==0)
end

function helpers.Heap:clear()
	self.__heap = {}
	self.size = 0
	self.sort = self.sort or f_min
	return self
end

function helpers.Heap:push(item)
	if item then
		self.size = self.size + 1
		self.__heap[self.size] = item
		percolate_up(self, self.size)
	end
  return self
end

function helpers.Heap:pop()
	local root
	if self.size > 0 then
		root = self.__heap[1]
		self.__heap[1] = self.__heap[self.size]
		self.__heap[self.size] = nil
		self.size = self.size-1
		if self.size>1 then
			percolate_down(self, 1)
		end
	end
	return root
end

function helpers.Heap:heapify(item)
	if item then
		local i = indexOf(self.__heap,item)
		if i then 
			percolate_down(self, i)
			percolate_up(self, i)
		end
		return
	end
	for i = floor(self.size/2),1,-1 do
		percolate_down(self,i)
	end
	return self
end


--[[===================================================================================--]]


helpers.multiHeap = {}

function helpers.multiHeap:new(template,comp)
	local mH = {__heap = {}, sort = comp or f_min, maxHeapNr = 0, nrHeaps = 0, size = 0};
	setmetatable(mH, template or self);
	self.__index = self;
	return mH;
end

function helpers.multiHeap:empty()
	return (self.size==0);
end

function helpers.multiHeap:clear()
	self.__heap = {};
	self.sort = self.sort or f_min;	
	self.maxHeapNr = 0;
	self.nrHeaps = 0;
	self.size = 0;
	return self;
end

function helpers.multiHeap:createHeap(heapNr)
	if not self.__heap[heapNr] then
		if self.maxHeapNr < heapNr then
			self.maxHeapNr = heapNr;
		end
		self.__heap[heapNr] = helpers.Heap:new(nil, self.sort);
		self.nrHeaps = self.nrHeaps + 1;
	end
end

function helpers.multiHeap:push(item, heapNr)
	if not heapNr then
		heapNr = 1;
	end
	if item then		
		if not self.__heap[heapNr] then
			self:createHeap(heapNr);
		end
		self.__heap[heapNr]:push(item);
		self.size = self.size + 1
	end
  	return self;
end
 
function helpers.multiHeap:pop(heapNr)
	local root;
	if self.size > 0 then
		if heapNr then
			if (not self.__heap[heapNr]) or self.__heap[heapNr]:empty() then
				return;
			end
		else
			heapNr = 1;
			while ( (not self.__heap[heapNr]) or self.__heap[heapNr]:empty() ) and heapNr <= self.maxHeapNr do
				heapNr = heapNr + 1;
			end
		end	
			
		if heapNr <= self.maxHeapNr then
			root = self.__heap[heapNr]:pop();
			self.size = self.size - 1;
		end
	end
	return root;
end

function helpers.multiHeap:heapify(item, heapNr)
	self._heap[heapNr]:heapify(item);
end

--===================================================================================
--***********************************************************************************
--===================================================================================

--HEURISTICS
local abs = math.abs
local sqrt = math.sqrt
local sqrt2 = sqrt(2)
local max, min = math.max, math.min

helpers.Heuristics = {}
function helpers.Heuristics.MANHATTAN(dx,dy) return abs(dx)+abs(dy) end
function helpers.Heuristics.EUCLIDIAN(dx,dy) return sqrt(dx*dx+dy*dy) end
function helpers.Heuristics.DIAGONAL(dx,dy) return max(abs(dx),abs(dy)) end
function helpers.Heuristics.CARDINTCARD(dx,dy) 
	dx, dy = abs(dx), abs(dy)
	return min(dx,dy) * sqrt2 + max(dx,dy) - min(dx,dy)
end


--===================================================================================
--***********************************************************************************
--===================================================================================

-- Nodes

helpers.NodeClass = {};

function helpers.NodeClass:new(x,y,category)
	local newNode = {x=x, y=y, category=category, inBin=false, parent=nil, h=0, f=math.huge, g={} };
	setmetatable(newNode, self);
	self.__index = self;
	
	return newNode;
end

function helpers.NodeClass.__lt(A,B)
	local i = #A.g;
	while A.g[i] == B.g[i] and i>1 do
		i = i-1;
	end
	return ((i==1 and A.g[i]+A.h < B.g[i]+B.h) or A.g[i] < B.g[i]);
end

function helpers.NodeClass:isBetterG(g ,h)
	if #self.g == 0 then
		return true;
	elseif #self.g ~= #g then
		return nil;
	end
	
	local i = #self.g;
	while g[i] == self.g[i] and i>1 do
		i = i-1;
	end
	
	return ((h and i==1 and (g[i]+h < self.g[i])) or (g[i] < self.g[i]));
end
