pathFinder = {}
--- Generate nodes for the A* algorithm. The nodes
-- cover the polygon and are arranged in a grid.
--
--
local gridSpacing
local count
local biasToRight
local fruitToCheck
local hasFruit
--
--- add some area with fruit for tests
function pathFinder.addFruitDistanceFromBoundary( grid, polygon )
  local distance = 10
  for y, row in ipairs( grid.map ) do
    for x, index in pairs( row ) do
    local _, minDistanceToFieldBoundary = getClosestPointIndex( polygon, { x = grid[ index ].x, y = grid[ index ].y })
      if minDistanceToFieldBoundary > distance then
        grid[ index ].hasFruit = true
      end
    end
  end
end

function pathFinder.addFruitGridDistanceFromBoundary( grid, polygon )
  local distance = 1
  for y, row in ipairs( grid.map ) do
    for x, index in pairs( row ) do
      if x > distance + 1 and x <= #row - distance and y > distance and y <= #grid.map - distance then
        grid[ index ].hasFruit = true
      end
    end
  end
end

function pathFinder.addIsland( grid, polygon )
  local distance = 64
  for y, row in ipairs( grid.map ) do
    for x, index in pairs( row ) do
    local _, minDistanceToFieldBoundary = getClosestPointIndex( polygon, { x = grid[ index ].x, y = grid[ index ].y })
      if minDistanceToFieldBoundary > distance then
        grid[ index ].isOnField = true
      end
    end
  end
end

--- Is this node an island (like a tree in the middle of the field)?
--
local function isOnField( node )
  if courseGenerator.isRunningInGame() then
    if node.isOnField == nil then
		  local y = getTerrainHeightAtWorldPos( g_currentMission.terrainRootNode, node.x, 0, -node.y );
      local densityBits = getDensityAtWorldPos( g_currentMission.terrainDetailId, node.x, y, -node.y);
      node.isOnField = densityBits ~= 0
    end
  end
  return node.isOnField
end

--- Does the area around x, z has fruit?
--
local function defaultHasFruitFunc( node, width )
  if courseGenerator.isRunningInGame() then
    -- check the fruit if we haven't done so yet
    if node.hasFruit == nil then
      node.hasFruit = courseplay:areaHasFruit( node.x, -node.y, fruitToCheck, width )
    end
  end
  return node.hasFruit
end

local function generateGridForPolygon( polygon, gridSpacingHint )
  local grid = {}
  -- map[ row ][ column ] maps the row/column address of the grid to a linear
  -- array index in the grid.
  grid.map = {}
  polygon.boundingBox = polygon:getBoundingBox()
  polygon:calculateData()
  -- this will make sure that the grid will have approximately 64^2 = 4096 points
  -- TODO: probably need to take the aspect ratio into accont for odd shaped
  -- (long and narrow) fields
  -- But don't go below a certain limit as that would drive too close to the fruite
  -- for this limit, use a fraction to reduce the chance of ending up right on the field edge (assuming fields
  -- are drawn using integer sizes) as that may result in a row or two missing in the grid
  gridSpacing = gridSpacingHint or math.max( 4.071, math.sqrt( polygon.area ) / 64 )
  local horizontalLines = generateParallelTracks( polygon, gridSpacing )
  if not horizontalLines then return grid end
  -- we'll need this when trying to find the array index from the
  -- grid coordinates. All of these lines are the same length and start
  -- at the same x
  grid.width = math.floor( horizontalLines[ 1 ].from.x / gridSpacing )
  grid.height = #horizontalLines
  -- now, add the grid points
  local margin = gridSpacing / 2
  for row, line in ipairs( horizontalLines ) do
    local column = 0
    grid.map[ row ] = {}
    for x = line.from.x, line.to.x, gridSpacing do
      column = column + 1
      for j = 1, #line.intersections, 2 do
        if line.intersections[ j + 1 ] then
          if x > line.intersections[ j ].x + margin and x < line.intersections[ j + 1 ].x - margin then
            local y = line.from.y
            -- check an area bigger than the gridSpacing to make sure the path is not too close to the fruit
            table.insert( grid, { x = x, y = y, column = column, row = row })
            grid.map[ row ][ column ] = #grid
          end
        end
      end
    end
  end
  return grid, gridSpacing
end

function pathFinder.findIslands( polygon )
	local grid, _ = generateGridForPolygon( polygon, Island.gridSpacing )
	local islandNodes = {}
	for _, row in ipairs( grid.map ) do
		for _, index in pairs( row ) do
			if not isOnField( grid[ index ]) then
				-- add a node only if it is far enough from the field boundary
				-- to filter false positives around the field boundary
				local _, d = getClosestPointIndex( polygon, grid[ index ])
				-- TODO: should calculate the closest distance to polygon edge, not 
				-- the vertices. This may miss an island close enough to the field boundary
				if d > 8 * Island.gridSpacing then
					table.insert( islandNodes, grid[ index ])
					grid[ index ].island = true
				end
			end
		end
	end
	return islandNodes
end
--- Is 'node' a valid neighbor of 'theNode'?
--
local function isValidNeighbor( theNode, node )
  -- this is called by a_star so we are in the x/y system
  --courseplay:debug( string.format( "theNode: %.2f, %2.f", theNode.x, theNode.y))
  --courseplay:debug( string.format( "node: %.2f, %.2f", node.x, node.y ))
  local d = a_star.distance( theNode.x, theNode.y, node.x, node.y )
  -- must be close enough (little more than sqrt(2) to allow for diagonals
  return d < gridSpacing * 1.5
end

--- a_star will call back here to get the valid neighbors
-- This is an optimization of the original algorithm which would iterate through all nodes
-- of the grid and see if theNode is close enough. We don't need that as we have our nodes in
-- a grid and we know exactly which (up to) eight nodes are the neighbors.
-- This reduces the iterations by two magnitudes
local function getNeighbors( theNode, grid )
	local neighbors = {}
  count = count + 1
  if theNode.column and theNode.row then
    -- we have the grid coordinates of theNode, we can figure out its neighbors
    -- how big is the area to check for neighbors?
    local width, height = 2, 2
    for column = theNode.column - width, theNode.column + width do
      for row = theNode.row - height, theNode.row + height do
        -- skip own node
        if not ( column == theNode.column and row == theNode.row ) and grid.map[ row ] and grid.map[ row ][ column ] then
          local neighbor = grid[ grid.map[ row ][ column ]]
          local theNodeHasFruit = hasFruit( theNode, gridSpacing * 2 )
          local neighborHasFruit = neighbor and hasFruit( neighbor, gridSpacing * 2 )
          if neighbor and
            -- we only care about nodes with no fruit ...
            ( not neighborHasFruit or
            -- ... or, if they have fruit, but the current node does not. This
            -- eliminates most nodes with fruit (except the ones close to the harvested area)
            -- and thus reduces the number of iterations significantly. However, no path will be
            -- generated when one of the end points is in the fruit.
            ( neighborHasFruit and not theNodeHasFruit ))
            then
              table.insert( neighbors, neighbor )
              theNode.visited = true
            end
        end
      end
    end
  end
  if theNode.neighborIndexes then
    for _, nodeIndex in ipairs( theNode.neighborIndexes ) do
      table.insert( neighbors, grid[ nodeIndex ])
    end
  end
	return neighbors
end

--- g() score to neighbor, A star will call back here when calculating the score
--
function gScoreToNeighbor( node, neighbor )
  if hasFruit( neighbor, gridSpacing * 2 ) then
    -- this is the key parameter to tweak. This is basically the distance you are
    -- willing to travel in order not to cross one grid spacing of fruit. So, for
    -- example with a grid spacing of 3 meters, you rather go around 250 meters
    -- than to cross 3 meters of fruit. The purpose of this is to allow for a path
    -- with some fruit in it, which comes in handy when your combine is full on the
    -- first headland. This will minimize to amount of fruit you have to drive through.
    return 250
  else
    -- add a little bias so a path from point A to B will be slightly different from the
    -- point from B to A to avoid collisions when multiple tractors use the same route
    return a_star.distance( node.x + biasToRight, node.y + biasToRight, neighbor.x, neighbor.y )
  end
end

--- Add a non-grid node to the grid
-- the purpose of this is to set up the neighbors
local function addOffGridNode( grid, newNode )
  for column, node in ipairs ( grid ) do
    if newNode ~= node and isValidNeighbor( newNode, node ) then
      if newNode.neighborIndexes then
        -- tell the new node about its neighbors
        table.insert ( newNode.neighborIndexes, column )
      else
        newNode.neighborIndexes = { column }
      end
      -- tell the other node about the new node
      if node.neighborIndexes then
        -- new node will be added as the last element of the grid
        table.insert( node.neighborIndexes, #grid + 1 )
      else
        node.neighborIndexes = { #grid + 1 }
      end
    end
  end
  table.insert( grid, newNode )
end


--- Find a path between from and to in a polygon using the A star
-- algorithm
-- expects x/y coordinates
function pathFinder.findPath( fromNode, toNode, polygon, fruit, customHasFruitFunc, addFruitFunc )
  count = 0
  fruitToCheck = fruit
  hasFruit = customHasFruitFunc or defaultHasFruitFunc
  local grid, width = generateGridForPolygon( polygon )
  -- hold a bit to the right
  biasToRight = fromNode.x < toNode.x and width / 2 or -width / 2
  if not courseGenerator.isRunningInGame() and addFruitFunc then
    addFruitFunc( grid, polygon )
  end 
  courseGenerator.debug( "Grid generated with %d points", #grid)
  addOffGridNode( grid, fromNode )
  addOffGridNode( grid, toNode )
  -- limit number of iterations depending on the grid size to avoid long freezes
  local path = a_star.path( fromNode, toNode, grid, isValidNeighbor, getNeighbors, gScoreToNeighbor, #grid * 0.75 )
	courseGenerator.debug( "Number of iterations %d", count)
  if path then
    path = Polygon:new( path )
    path:calculateData()
    path = smooth( path, math.rad( 0 ), math.rad( 180 ), 1, true )
	  courseGenerator.debug( "Path generated with %d points", #path )
    path:calculateData()
    path = space( path, math.rad( 15 ), 5 )
	  courseGenerator.debug( "Path spaced, has now  %d points", #path )
    if not courseGenerator.isRunningInGame() then
      io.stdout:flush()
    end
  end 
  return path, grid
end
