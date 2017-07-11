--- Functions to generate the headland passes
--
-- how close the vehicle must be to the field to automatically 
-- calculate a track starting near the vehicle's location
-- This is in meters
local maxDistanceFromField = 30
local n

--- Calculate a headland track inside polygon in offset distance
function calculateHeadlandTrack( polygon, targetOffset, minDistanceBetweenPoints, angleThreshold,
                                 currentOffset, doSmooth, inward )
  -- recursion limit
  if currentOffset == 0 then 
    n = 1
    courseGenerator.debug( string.format( "Generating headland track with offset %.2f", targetOffset ))
  else
    n = n + 1
  end
  if n > 200 then 
    courseGenerator.debug( string.format( "Recursion limit reached for headland generation"))
    return polygon
  end
  -- we'll use the grassfire algorithm and approach the target offset by 
  -- iteration, generating headland tracks close enough to the previous one
  -- so the resulting offset polygon is always clean (its edges don't intersect
  -- each other)
  -- this can be ensured by choosing an offset small enough
  local deltaOffset = polygon.shortestEdgeLength / 5

  --courseGenerator.debug( string.format( "** Before target=%.2f, current=%.2f, delta=%.2f", targetOffset, currentOffset, deltaOffset))
  if currentOffset >= targetOffset then return polygon end

  deltaOffset = math.min( deltaOffset, targetOffset - currentOffset )
  currentOffset = currentOffset + deltaOffset

  if not inward then
    deltaOffset = -deltaOffset
  end

  --courseGenerator.debug( string.format( "** After target=%.2f, current=%.2f, delta=%.2f", targetOffset, currentOffset, deltaOffset))
  local offsetEdges = {} 
  for i, point in ipairs( polygon ) do
    local newEdge = {} 
    local newFrom = addPolarVectorToPoint( point.nextEdge.from, point.nextEdge.angle + getInwardDirection( polygon.isClockwise ), deltaOffset )
    local newTo = addPolarVectorToPoint( point.nextEdge.to, point.nextEdge.angle + getInwardDirection( polygon.isClockwise ), deltaOffset )
    table.insert( offsetEdges, { from=newFrom, to=newTo })
  end
 
  local vertices = {} 
  for i, edge in ipairs( offsetEdges ) do
    local ix = i - 1
    if ix == 0 then ix = #offsetEdges end
    local prevEdge = offsetEdges[ix ]
    local vertex = getIntersection( edge.from.x, edge.from.y, edge.to.x, edge.to.y, 
                                    prevEdge.from.x, prevEdge.from.y, prevEdge.to.x, prevEdge.to.y )
    if vertex then
      table.insert( vertices, vertex )
    else
      if getDistanceBetweenPoints( prevEdge.to, edge.from ) < minDistanceBetweenPoints then
        local x, y = getPointInTheMiddle( prevEdge.to, edge.from )
        table.insert( vertices, { x=x, y=y })
      else
        table.insert( vertices, prevEdge.to )
        table.insert( vertices, edge.from )
      end
    end
  end
  calculatePolygonData( vertices )
  if doSmooth then
    vertices = smooth( vertices, angleThreshold, 1, false )
  end
  -- only filter points too close, don't care about angle
  applyLowPassFilter( vertices, math.pi, minDistanceBetweenPoints )
  return calculateHeadlandTrack( vertices, targetOffset, minDistanceBetweenPoints, angleThreshold, 
                                 currentOffset, doSmooth, inward )
end

--- Link the generated, parallel circular headland tracks to
-- a single spiral track
-- First, We have to find where to start our course. 
--  If we work on the headland first:
--  - the starting point will be on the outermost headland track
--    close to the current vehicle position. 
--  - for the subsequent headland passes, we add a 90 degree vector 
--    to the first point of the first pass and then continue from there
--    inwards
--
function linkHeadlandTracks( field, implementWidth, isClockwise, startLocation, doSmooth, angleThreshold )
  -- first, find the intersection of the outermost headland track and the 
  -- vehicles heading vector. 
  local headlandPath = {}
  -- find closest point to starting position on outermost headland track 
  local fromIndex = getClosestPointIndex( field.headlandTracks[ 1 ], startLocation )
  local toIndex = getPolygonIndex( field.headlandTracks[ 1 ], fromIndex + 1 ) 
  vectors = {}
  for i = 1, #field.headlandTracks do
    -- now find out which direction we have to drive on the headland pass.
    if field.headlandTracks[ i ].isClockwise == isClockwise then
      -- increasing index is clockwise, so 
      -- driving direction is in increasing index, start at toIndex and go a full circle
      -- back to fromIndex
      addTrackToHeadlandPath( headlandPath, field.headlandTracks[ i ], i, toIndex, fromIndex, 1 )
      startLocation = field.headlandTracks[ i ][ toIndex ]
      field.headlandTracks[ i ].circleStart = toIndex
      field.headlandTracks[ i ].circleEnd = fromIndex 
      field.headlandTracks[ i ].circleStep = 1
    else
      -- must reverse direction
      -- driving direction is in decreasing index, so we start at fromIndex and go a full circle
      -- to toIndex 
      addTrackToHeadlandPath( headlandPath, field.headlandTracks[ i ], i, fromIndex, toIndex, -1 )
      startLocation = field.headlandTracks[ i ][ fromIndex ]
      field.headlandTracks[ i ].circleStart = fromIndex
      field.headlandTracks[ i ].circleEnd = toIndex 
      field.headlandTracks[ i ].circleStep = -1
    end
    -- remember this, we'll need when generating the link from the last headland pass
    -- to the parallel tracks
    -- switch to the next headland track
    local tangent = field.headlandTracks[ i ][ fromIndex ].tangent.angle
    local heading = field.headlandTracks[ i ][ fromIndex ].tangent.angle + getInwardDirection( field.headlandTracks[ i ].isClockwise )
    -- We should be able to find the next headland track within a reasonable distance but this 
    -- may not work around corners so we try further
    local distances = { implementWidth * 1.5, implementWidth * 2, implementWidth * 5 }
    for _, distance in ipairs( distances ) do
      -- we may have an issue finding the next track around corners, so try a couple of other headings
      local headings = { heading }
      for h = 15,120,15 do 
          table.insert( headings, heading + math.rad( h ))
          table.insert( headings, heading - math.rad( h ))
      end
      for _, h in ipairs( headings ) do
        if lines then
          table.insert( lines, { startLocation, addPolarVectorToPoint( startLocation, h, distance )})
        end
        if field.headlandTracks[ i + 1 ] then
          courseGenerator.debug( string.format( "Trying to link headland track %d to next track at angle %.2f (tangent is %.2f)", i, math.deg( h ),
                 math.deg(tangent)))
          fromIndex, toIndex = getIntersectionOfLineAndPolygon( field.headlandTracks[ i + 1 ], startLocation, 
                               addPolarVectorToPoint( startLocation, h, distance ))
          if fromIndex then
            break
          else
            courseGenerator.debug( string.format( "Could not link headland track %d to next track at angle %.2f", i, math.deg( h )))
          end
        end
      end
      if fromIndex then
        break
      else
        courseGenerator.debug( string.format( "Could not link headland track %d to next track at distance %.2f", i, distance ))
      end
    end
  end
  if doSmooth then
    -- skip the first and last point when smoothing, this makes sure smooth() won't try
    -- to wrap around the ends like in case of a closed polygon, this is just a line here.
    field.headlandPath = smooth( headlandPath, angleThreshold, 2, true )
    addMissingPassNumber( field.headlandPath )
  else
    field.headlandPath = headlandPath
  end
end

--- add a series of points (track) to the headland path. This is to 
-- assemble the complete spiral headland path from the individual 
-- parallel headland tracks.
function addTrackToHeadlandPath( headlandPath, track, passNumber, from, to, step)
  for i, point in polygonIterator( track, from, to, step ) do
    table.insert( headlandPath, track[ i ])
    headlandPath[ #headlandPath ].passNumber = passNumber
  end
end

-- smooth adds new points where we loose the passNumber attribute.
-- here we fix that. I know it's ugly and there must be a better way to 
-- do this somehow smooth should preserve these, but whatever...
function addMissingPassNumber( headlandPath )
  local currentPassNumber = 0
  for i, point in ipairs( headlandPath ) do
    if point.passNumber then 
      if point.passNumber ~= currentPassNumber then 
        currentPassNumber = point.passNumber
      end
    else
      point.passNumber = currentPassNumber
    end
  end
end

