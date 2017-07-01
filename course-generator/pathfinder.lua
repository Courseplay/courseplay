
--- Generate nodes for the A* algorithm. The nodes
-- cover the polygon and are arranged in a grid.
--
--
local gridDistance

function generateGridForPolygon( polygon, width )
  local grid = {}
  local bb = getBoundingBox( polygon )
  local w = bb.maxX - bb.minX
  local h = bb.maxY - bb.minY
  local fminX, fmaxX, fminY, fmaxY = bb.minX + w * 0.3, bb.maxX - w * 0.3, bb.minY + h * 0.2, bb.maxY - h * 0.2 
  local horizontalLines = generateParallelTracks( polygon, width )
  -- now, add the grid points 
  local margin = width / 2
  for i, line in ipairs( horizontalLines ) do
    for x = line.from.x, line.to.x, width do
      for j = 1, #line.intersections,2 do
        if line.intersections[ j + 1 ] then
          if x > line.intersections[ j ].x + margin and x < line.intersections[ j + 1 ].x - margin then
            if (( x < fminX or x > fmaxX ) or ( line.from.y < fminY or line.from.y > fmaxY )) then
            table.insert( grid, { x = x, y = line.from.y, ix = j, iy = i })
          end
          end
        end
      end
    end
  end
  return grid
end

function isValidNeighbor( theNode, node )
  local d = a_star.distance( theNode.x, theNode.y, node.x, node.y )
  return d < gridDistance * 1.5 
end

function findPath( polygon, from, to, width )
  gridDistance = width
  local grid = generateGridForPolygon( polygon, width ) 
  table.insert( grid, from )
  table.insert( grid, to )
  print( from.x, from.y )
  local path = a_star.path( from, to, grid, isValidNeighbor )
  print( "Path done", path ) 
  if not isRunningInGame then
    io.stdout:flush()
  end
  return path
end
