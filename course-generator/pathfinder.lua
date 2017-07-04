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
    return math.random() > 0.75
  end
end

local function generateGridForPolygon( polygon, width )
  local grid = {}
  polygon.boundingBox = getBoundingBox( polygon )
  local horizontalLines = generateParallelTracks( polygon, width )
  -- now, add the grid points 
  local margin = width / 2
  for i, line in ipairs( horizontalLines ) do
    local nPoints = 0
    for x = line.from.x, line.to.x, width do
      for j = 1, #line.intersections, 2 do
        if line.intersections[ j + 1 ] then
          if x > line.intersections[ j ].x + margin and x < line.intersections[ j + 1 ].x - margin then
            local y = line.from.y
            local hasFruit = hasFruit( x, y, width )
            table.insert( grid, { x = x, y = y, hasFruit = hasFruit, ix = j, iy = i })
            nPoints = nPoints + 1
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

function pointsToXy( points )
  local result = {}
  for _, point in ipairs( points ) do
    table.insert( result, { x = point.cx, y = -point.cz })
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

local function pointToXy( point )
  return({ x = point.x, y = -point.z })
end

function pointToXz( point )
  return({ x = point.x, z = -point.y })
end


--- Find a path between from and to in a polygon using the A star
-- algorithm where the nodes are a grid with 'width' spacing. 
-- Expects FS coordinates (x,-z)
function pathFinder.findPath( from, to, cpPolygon, width )
  gridSpacing = width
  local grid = generateGridForPolygon( pointsToXy( cpPolygon ), width ) 
  -- from and to must be a node. change z to y as a-star works in x/y system
  local fromNode = pointToXy( from )
  local toNode = pointToXy( to )
  table.insert( grid, fromNode )
  table.insert( grid, toNode )
	courseGenerator.debug( string.format( "Grid generated with %d points", #grid) , 9);
  local path = a_star.path( fromNode, toNode, grid, isValidNeighbor )
  if not courseGenerator.isRunningInGame() then
    io.stdout:flush()
  end
  if path then 
    calculatePolygonData( path )
    path = smooth( path, math.rad( 30 ), 1, true )
	  courseGenerator.debug( string.format( "Path generated with %d points", #path ) , 9);
    return pointsToXz( path ), grid 
  else
    return nil, grid 
  end
end


