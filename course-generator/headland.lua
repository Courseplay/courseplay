--- Functions to generate the headland passes
--
-- how close the vehicle must be to the field to automatically 
-- calculate a track starting near the vehicle's location
-- This is in meters
local maxDistanceFromField = 30
local n

--- Calculate a headland track inside polygon in offset distance
function calculateHeadlandTrack( polygon, targetOffset, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle,
                                 currentOffset, doSmooth, inward )
  -- recursion limit
  if currentOffset == 0 then 
    n = 1
    courseGenerator.debug( "Generating headland track with offset %.2f", targetOffset )
  else
    n = n + 1
  end
  -- limit of the number of recursions based on how far we want to go
  -- TODO: this may be linked to the factor for calculating the deltaOffset below
  -- also, make sure there's a minimum (for example when we are generating a dummy headland with 0 offset
  local recursionLimit = math.max( math.floor( targetOffset * 20 ), 200 )
  if n > recursionLimit then 
    courseGenerator.debug( "Recursion limit of %d reached for headland generation", recursionLimit )
    -- this will throw an exception but that's better than silently generating wrong tracks
    return nil
  end
  -- we'll use the grassfire algorithm and approach the target offset by 
  -- iteration, generating headland tracks close enough to the previous one
  -- so the resulting offset polygon is always clean (its edges don't intersect
  -- each other)
  -- this can be ensured by choosing an offset small enough
  local deltaOffset = polygon.shortestEdgeLength / 8

  -- courseGenerator.debug( "** Before target=%.2f, current=%.2f, delta=%.2f, target-current=%.2f", targetOffset, currentOffset, deltaOffset, targetOffset - currentOffset )
  if currentOffset >= targetOffset then return polygon end

  deltaOffset = math.min( deltaOffset, targetOffset - currentOffset )
  currentOffset = currentOffset + deltaOffset

  if not inward then
    deltaOffset = -deltaOffset
  end

  -- courseGenerator.debug( "** After target=%.2f, current=%.2f, delta=%.2f", targetOffset, currentOffset, deltaOffset)
  local offsetEdges = {} 
  for i, point in ipairs( polygon ) do
    local newEdge = {} 
    local newFrom = addPolarVectorToPoint( point.nextEdge.from, point.nextEdge.angle + getInwardDirection( polygon.isClockwise ), deltaOffset )
    local newTo = addPolarVectorToPoint( point.nextEdge.to, point.nextEdge.angle + getInwardDirection( polygon.isClockwise ), deltaOffset )
    table.insert( offsetEdges, { from=newFrom, to=newTo })
  end
 
  local vertices = {} 
  local intersections = 0
  for i, edge in ipairs( offsetEdges ) do
    local ix = i - 1
    if ix == 0 then ix = #offsetEdges end
    local prevEdge = offsetEdges[ix ]
    local vertex = getIntersection( edge.from.x, edge.from.y, edge.to.x, edge.to.y, 
                                    prevEdge.from.x, prevEdge.from.y, prevEdge.to.x, prevEdge.to.y )
    if vertex then
      table.insert( vertices, vertex )
      intersections = intersections + 1
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
    vertices = smooth( vertices, minSmoothAngle, maxSmoothAngle, 1, false )
  end
  -- only filter points too close, don't care about angle
  applyLowPassFilter( vertices, math.pi, minDistanceBetweenPoints )
  return calculateHeadlandTrack( vertices, targetOffset, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 
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
function linkHeadlandTracks( field, implementWidth, isClockwise, startLocation, doSmooth, minSmoothAngle, maxSmoothAngle )
  -- first, find the intersection of the outermost headland track and the 
  -- vehicles heading vector. 
  local headlandPath = {}
  -- find closest point to starting position on outermost headland track 
  local fromIndex = getClosestPointIndex( field.headlandTracks[ 1 ], startLocation )
  local toIndex = getPolygonIndex( field.headlandTracks[ 1 ], fromIndex + 1 ) 
  vectors = {}
  -- direction we'll be looking for the next inward headland track (relative to
  -- the headland vertex direcions) We want to go a bit forward, not directly 
  -- perpendicular 
  local inwardAngleOffset = 60 
  local inwardAngle
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
      inwardAngle = inwardAngleOffset
    else
      -- must reverse direction
      -- driving direction is in decreasing index, so we start at fromIndex and go a full circle
      -- to toIndex 
      addTrackToHeadlandPath( headlandPath, field.headlandTracks[ i ], i, fromIndex, toIndex, -1 )
      startLocation = field.headlandTracks[ i ][ fromIndex ]
      field.headlandTracks[ i ].circleStart = fromIndex
      field.headlandTracks[ i ].circleEnd = toIndex 
      field.headlandTracks[ i ].circleStep = -1
      inwardAngle = 180 - inwardAngleOffset
    end
    -- remember this, we'll need when generating the link from the last headland pass
    -- to the parallel tracks
    -- switch to the next headland track
    local heading = field.headlandTracks[ i ][ fromIndex ].nextEdge.angle + getInwardDirection( field.headlandTracks[ i ].isClockwise, math.rad( inwardAngle ))
    -- We should be able to find the next headland track within a reasonable distance but this 
    -- may not work around corners so we try further
    local distances = { implementWidth * 1.5, implementWidth * 3, implementWidth * 6, implementWidth * 12 }
    for _, distance in ipairs( distances ) do
      -- we may have an issue finding the next track around corners, so try a couple of other headings
      local headings = { heading }
      for h = 10,120,10 do 
          table.insert( headings, heading + math.rad( h ))
          table.insert( headings, heading - math.rad( h ))
      end
      for _, h in ipairs( headings ) do
        if lines then
          table.insert( lines, { startLocation, addPolarVectorToPoint( startLocation, h, distance )})
        end
        if field.headlandTracks[ i + 1 ] then
          fromIndex, toIndex = getIntersectionOfLineAndPolygon( field.headlandTracks[ i + 1 ], startLocation, 
                               addPolarVectorToPoint( startLocation, h, distance ))
          if fromIndex then
            courseGenerator.debug( "Linked headland track %d to next track, heading %.1f, distance %.1f, inwardAngle = %d", i, math.deg( h ), distance, inwardAngle )
            break
          end
        end
      end
      if fromIndex then
        break
      else
        courseGenerator.debug( "Could not link headland track %d to next track at distance %.2f", i, distance )
      end
    end
  end
  if doSmooth then
    -- skip the first and last point when smoothing, this makes sure smooth() won't try
    -- to wrap around the ends like in case of a closed polygon, this is just a line here.
    field.headlandPath = smooth( headlandPath, minSmoothAngle, maxSmoothAngle, 2, true )
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
