pathFinder = {}
--- Generate nodes for the A* algorithm. The nodes
-- cover the polygon and are arranged in a grid.
--
--
local gridSpacing
local count

--- add some area with fruit for tests
local function addFruit( grid )
  for y, row in ipairs( grid.map ) do
    for x, index in pairs( row ) do
      if y > 40 and y < #row - 50 and x > 14 and x < #row / 2 then
        grid[ index ].hasFruit = true
      end
    end
  end
end

--- Does the area around x, z has fruit?
-- 
local function hasFruit( x, y, width )
  if courseGenerator.isRunningInGame() then
    return courseplay:areaHasFruit( x, -y, nil, width )  
  else
    -- for testing in standalone mode
    return false 
  end
end

local function generateGridForPolygon( polygon, width )
  local grid = {}
  -- map[ row ][ column ] maps the row/column address of the grid to a linear
  -- array index in the grid.
  grid.map = {}
  polygon.boundingBox = getBoundingBox( polygon )
  local horizontalLines = generateParallelTracks( polygon, width )
  if not horizontalLines then return grid end
  -- we'll need this when trying to find the array index from the 
  -- grid coordinates. All of these lines are the same length and start 
  -- at the same x
  grid.width = math.floor( horizontalLines[ 1 ].from.x / width )
  grid.height = #horizontalLines
  -- now, add the grid points 
  local margin = width / 2
  for row, line in ipairs( horizontalLines ) do
    local column = 0
    grid.map[ row ] = {}
    for x = line.from.x, line.to.x, width do
      column = column + 1
      for j = 1, #line.intersections, 2 do
        if line.intersections[ j + 1 ] then
          if x > line.intersections[ j ].x + margin and x < line.intersections[ j + 1 ].x - margin then
            local y = line.from.y
            -- check an area bigger than the width to make sure the path is not too close to the fruit
            local hasFruit = hasFruit( x, y, width * 2 )
            table.insert( grid, { x = x, y = y, hasFruit = hasFruit, column = column, row = row })
            grid.map[ row ][ column ] = #grid
          end
        end
      end
    end
  end
  return grid
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
          neighbor = grid[ grid.map[ row ][ column ]]
          if neighbor then table.insert( neighbors, neighbor ) end
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
  if neighbor.hasFruit then
    -- this is the key parameter to tweak. This is basically the distance you are 
    -- willing to travel in order not to cross one grid spacing of fruit. So, for 
    -- example with a grid spacing of 3 meters, you rather go around 250 meters 
    -- than to cross 3 meters of fruit. The purpose of this is to allow for a path
    -- with some fruit in it, which comes in handy when your combine is full on the
    -- first headland. This will minimize to amount of fruit you have to drive through.
    return 250
  else
    return a_star.distance( node.x, node.y, neighbor.x, neighbor.y )
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


function pointsToXy( points )
  local result = {}
  for _, point in ipairs( points ) do
    table.insert( result, { x = point.x or point.cx, y = - ( point.z or point.cz )})
  end
  return result
end

function pointsToXz( points )
  local result = {}
  for _, point in ipairs( points) do
    table.insert( result, { x = point.x, z = -point.y })
  end
  return result
end

function pointsToCxCz( points )
  local result = {}
  for _, point in ipairs( points) do
    table.insert( result, { cx = point.x, cz = -point.y })
  end
  return result
end

local function pointToXy( point )
  return({ x = point.x or point.cx, y = - ( point.z or point.cz )})
end

function pointToXz( point )
  return({ x = point.x, z = -point.y })
end

function pointToXz( point )
  return({ x = point.x, z = -point.y })
end

--- Find a path between from and to in a polygon using the A star
-- algorithm where the nodes are a grid with 'width' spacing. 
-- Expects FS coordinates (x,-z)
function pathFinder.findPath( from, to, cpPolygon, width )
  gridSpacing = width
  count = 0
  local grid = generateGridForPolygon( pointsToXy( cpPolygon ), width ) 
  -- from and to must be a node. change z to y as a-star works in x/y system
  local fromNode = pointToXy( from )
  local toNode = pointToXy( to )
  if not courseGenerator.isRunningInGame() then
    addFruit( grid )
  end
	courseGenerator.debug( string.format( "Grid generated with %d points", #grid) , 9);
  addOffGridNode( grid, fromNode )
  addOffGridNode( grid, toNode )
  -- limit number of iterations depending on the grid size to avoid long freezes
  local path = a_star.path( fromNode, toNode, grid, isValidNeighbor, getNeighbors, gScoreToNeighbor, #grid * 0.75 )
	courseGenerator.debug( string.format( "Number of iterations %d", count) , 9);
  if path then 
    calculatePolygonData( path )
    path = smooth( path, math.rad( 0 ), 1, true )
	  courseGenerator.debug( string.format( "Path generated with %d points", #path ) , 9);
    calculatePolygonData( path )
    path = space( path, math.rad( 15 ), 5 )
	  courseGenerator.debug( string.format( "Path spaced, has now  %d points", #path ) , 9);
    if not courseGenerator.isRunningInGame() then
      io.stdout:flush()
    end
    return pointsToXz( path ), grid 
  else
    return nil, grid 
  end
end


