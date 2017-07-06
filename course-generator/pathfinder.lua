pathFinder = {}
--- Generate nodes for the A* algorithm. The nodes
-- cover the polygon and are arranged in a grid.
--
--
local gridSpacing
--- Does the area around x, z has fruit?
-- 
local function hasFruit( x, y, width )
  if courseGenerator.isRunningInGame() then
    return courseplay:areaHasFruit( x, -y, nil, width )  
  else
    -- for testing in standalone mode
    return math.random() > 1.8
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
  -- and must not have fruit.
  return d < gridSpacing * 1.5 and not node.hasFruit
end

--- a_star will call back here to get the valid neighbors
-- This is an optimization of the original algorithm which would iterate through all nodes
-- of the grid and see if theNode is close enough. We don't need that as we have our nodes in 
-- a grid and we know exactly which (up to) eight nodes are the neighbors.
-- This reduces the iterations by two magnitudes
local function getNeighbors( theNode, grid )
	local neighbors = {}
  if theNode.column and theNode.row then
    -- we have the grid coordinates of theNode, we can figure out its neighbors
    -- how big is the area to check for neighbors?
    local width, height = 2, 2
    for column = theNode.column - width, theNode.column + width do
      for row = theNode.row - height, theNode.row + height do
        -- skip own node
        if not ( column == theNode.column and row == theNode.row ) and grid.map[ row ] and grid.map[ row ][ column ] then
          pathFinder.count = pathFinder.count + 1
          neighbor = grid[ grid.map[ row ][ column ]]
          if neighbor and not neighbor.hasFruit then table.insert( neighbors, neighbor ) end
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


--- Find a path between from and to in a polygon using the A star
-- algorithm where the nodes are a grid with 'width' spacing. 
-- Expects FS coordinates (x,-z)
function pathFinder.findPath( from, to, cpPolygon, width )
  gridSpacing = width
  pathFinder.count = 0
  local grid = generateGridForPolygon( pointsToXy( cpPolygon ), width ) 
  -- from and to must be a node. change z to y as a-star works in x/y system
  local fromNode = pointToXy( from )
  local toNode = pointToXy( to )
	courseGenerator.debug( string.format( "Grid generated with %d points", #grid) , 9);
  addOffGridNode( grid, fromNode )
  addOffGridNode( grid, toNode )
  local path = a_star.path( fromNode, toNode, grid, isValidNeighbor, getNeighbors )
	courseGenerator.debug( string.format( "Number of iterations %d", pathFinder.count) , 9);
  if not courseGenerator.isRunningInGame() then
    io.stdout:flush()
  end
  if path then 
	  courseGenerator.debug( string.format( "Path generated with %d points", #path ) , 9);
    calculatePolygonData( path )
    path = smooth( path, math.rad( 30 ), 1, true )
    return pointsToXz( path ), grid 
  else
    return nil, grid 
  end
end


