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
    return math.random() > 0.7
  end
end

local function generateGridForPolygon( polygon, width )
  local grid = {}
  local horizontalLines = generateParallelTracks( polygon, width )
  -- now, add the grid points 
  local margin = width / 2
  for i, line in ipairs( horizontalLines ) do
    local nPoints = 0
    for x = line.from.x, line.to.x, width do
      for j = 1, #line.intersections, 2 do
        if line.intersections[ j + 1 ] then
          if x > line.intersections[ j ].x + margin and x < line.intersections[ j + 1 ].x - margin then
            local hasFruit = hasFruit( x, y, width )
            table.insert( grid, { x = x, y = line.from.y, hasFruit = hasFruit, ix = j, iy = i })
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
  local d = a_star.distance( theNode.x, theNode.y, node.x, node.y )
  -- must be close enough (little more than sqrt(2) to allow for diagonals
  -- and must not have fruit.
  return d < gridSpacing * 1.5 and not node.hasFruit
end

local function pointsToXY( points )
  local result = {}
  for _, p in ipairs( points) do
    table.insert( result, { x = x, y = -z })
  end
  return result
end

local function pointsToXZ( points )
  local result = {}
  for _, p in ipairs( points) do
    table.insert( result, { x = x, z = -y })
  end
  return result
end

local function pointToXy( point )
  return({ x = point.x, y = -point.z })
end


--- Find a path between from and to in a polygon using the A star
-- algorithm where the nodes are a grid with 'width' spacing. 
--
function pathFinder.findPath( polygon, from, to, width )
  gridSpacing = width
  local grid = generateGridForPolygon( pointsToXY( polygon ), width ) 
  -- from and to must be a node. change z to y as a-star works in x/y system
  table.insert( grid, pointToXy( from ))
  table.insert( grid, pointToXy( to ))
  local path = a_star.path( from, to, grid, isValidNeighbor )
  if not isRunningInGame then
    io.stdout:flush()
  end
  return pointsToXZ( path ), grid
end


