--- Functions to generate the tracks in the center
--  of the field (non-headland tracks)

local rotatedMarks = {}

-- Distance of waypoints on the generated track in meters
local waypointDistance = 5
-- don't generate waypoints closer than minWaypointDistance 
local minWaypointDistance = waypointDistance * 0.25

--- Find the best angle to use for the tracks in a polygon.
--  The best angle results in the minimum number of tracks
--  (and thus, turns) needed to cover the polygon.
function findBestTrackAngle( polygon, width )
  local bestAngleStats = {}
  local bestAngleIndex 
  local score
  local minScore = 10000
  calculatePolygonData( polygon )
  -- direction where the field is the longest
  local bestDirection = polygon.bestDirection.dir
  for angle = 0, 180, 2 do
    local rotated = rotatePoints( polygon, math.rad( angle ))
    local tracks = generateParallelTracks( rotated, width )
    local nFullTracks, nSplitTracks, nBlocks = countTracks( tracks )
    local blocks = {}
    blocks = splitCenterIntoBlocks( tracks, blocks, width )
    local nSmallBlocks = countSmallBlocks( blocks )
    -- instead of just the number of tracks, consider some other factors. We prefer just one block (that is,
    -- the field has a convex solution) and angles closest to the direction of the longest edge of the field
    -- bestDirection + angle is the longest edge dir at the current rotation. cos( angle - currentBestDir ) will be 0 
    -- when angle is the closest.
    score = 50 * nSmallBlocks + 20 * #blocks + 5 * nSplitTracks + nFullTracks + 2 * math.abs( math.cos( math.rad( angle - bestDirection + angle )))
    table.insert( bestAngleStats, { angle=angle, nBlocks=#blocks, nFullTracks=nFullTracks, nSplitTracks=nSplitTracks, score=score })
    if score < minScore then
      minScore = score
      bestAngleIndex = #bestAngleStats
    end
  end
  local b = bestAngleStats[ bestAngleIndex ]
  courseGenerator.debug( string.format( "Best angle=%d, nBlocks=%d, nFullTracks=%d, nSplitTracks=%d, score=%.1f",
                         b.angle, b.nBlocks, b.nFullTracks, b.nSplitTracks, b.score))
  return b.angle, b.nFullTracks + b.nSplitTracks, b.nBlocks 
end

--- Count the blocks with just a few tracks 
function countSmallBlocks( blocks )
  local nResult = 0
  -- if there's only one block, we don't care
  if #blocks == 1 then return nResult end
  for _, b in ipairs( blocks ) do
    -- TODO: consider implement width
    if #b < 5 then
      nResult = nResult + 1
    end
  end 
  return nResult
end

--- Generate up/down tracks covering a polygon at the optimum angle
-- 
function generateTracks( polygon, width, nTracksToSkip, extendTracks )
  -- translate polygon so we can rotate it around its center. This way all points
  -- will be approximately the same distance from the origo and the rotation calculation
  -- will be more accurate
  local bb = getBoundingBox( polygon )
  local dx, dy = ( bb.maxX + bb.minX ) / 2, ( bb.maxY + bb.minY ) / 2 
  local translatedPolygon = translatePoints( polygon, -dx , -dy )
  -- Now, determine the angle where the number of tracks is the minimum
  polygon.bestAngle, polygon.nTracks = findBestTrackAngle( translatedPolygon, width )
  if not polygon.bestAngle then
    polygon.bestAngle = polygon.bestDirection.dir
    courseGenerator.debug( "No best angle found, use the longest edge direction " .. polygon.bestAngle )
  end
  rotatedMarks = {}
  -- now, generate the tracks according to the implement width within the rotated polygon's bounding box
  -- using the best angle
  local rotated = rotatePoints( translatedPolygon, math.rad( polygon.bestAngle ))

  local parallelTracks = generateParallelTracks( rotated, width )

  local blocks = {}
  blocks = splitCenterIntoBlocks( parallelTracks, blocks, width )

  for i, block in ipairs( blocks ) do
    for _, j in ipairs({ 1, #block }) do
      table.insert( rotatedMarks, block[ j ].intersections[ 1 ])
      rotatedMarks[ #rotatedMarks ].label = string.format( "%d-%d/1", i, j )
      table.insert( rotatedMarks, block[ j ].intersections[ 2 ])
      rotatedMarks[ #rotatedMarks ].label = string.format( "%d-%d/2", i, j )
    end
    courseGenerator.debug( string.format( "Block %d has %d tracks", i, #block ))
    block.tracksWithWaypoints = addWaypointsToTracks( block, width, extendTracks )
    block.covered = false
  end
  
  -- We now have split the area within the headland into blocks. If this is 
  -- a convex polygon, there is only one block, non-convex ones may have multiple
  -- blocks. 
  -- Now we have to connect the first block with the end of the headland track
  -- and then connect each block so we cover the entire polygon.

  local startIx, endIx, step = polygon.circleStart, polygon.circleEnd, polygon.circleStep
  local workedBlocks = {} 
  while startIx do
    startIx, endIx, block = findTrackToNextBlock( blocks, rotated, startIx, endIx, step )
    table.insert( workedBlocks, block )
  end

  -- workedBlocks has now a the list of blocks we need to work on, including the track
  -- leading to the block from the previous block or the headland.
  local track = {}
  local connectingTracks = {}
  for i, block in ipairs( workedBlocks ) do
    connectingTracks[ i ] = {}
    courseGenerator.debug( string.format( "Track to block %d has %d points", i, #block.trackToThisBlock ))
    for j = 1, #block.trackToThisBlock do
      table.insert( track, block.trackToThisBlock[ j ])
      table.insert( connectingTracks[ i ], block.trackToThisBlock[ j ])
    end
    linkParallelTracks( track, block.tracksWithWaypoints, block.bottomToTop, block.leftToRight, nTracksToSkip ) 
    addRidgeMarkers( track )
  end

  -- now rotate and translate everything back to the original coordinate system
  if marks then 
    rotatedMarks = translatePoints( rotatePoints( rotatedMarks, -math.rad( polygon.bestAngle )), dx, dy )
  -- will be approximately the same distance from the origo and the rotation calculation
  -- will be more accurate
    for i = 1, #rotatedMarks do
      table.insert( marks, rotatedMarks[ i ])
    end
  end
  for i = 1, #connectingTracks do
    connectingTracks[ i ] = translatePoints( rotatePoints( connectingTracks[ i ], -math.rad( polygon.bestAngle )), dx, dy )
  end
  polygon.connectingTracks = connectingTracks
  return translatePoints( rotatePoints( track, -math.rad( polygon.bestAngle )), dx, dy )
end

----------------------------------------------------------------------------------
-- Functions below work on a field rotated so that all parallel tracks are 
-- horizontal ( y = constant ). This makes track calculation really easy.
----------------------------------------------------------------------------------

--- Generate a list of parallel tracks within the field's boundary
-- At this point, tracks are defined only by they endpoints and 
-- are not connected
function generateParallelTracks( polygon, width )
  local tracks = {}
  local trackIndex = 1
  for y = polygon.boundingBox.minY + width / 2, polygon.boundingBox.maxY, width do
    local from = { x = polygon.boundingBox.minX, y = y, track=trackIndex }
    local to = { x = polygon.boundingBox.maxX, y = y, track=trackIndex }
    -- for now, all tracks go from min to max, we'll take care of
    -- alternating directions later.
    table.insert( tracks, { from=from, to=to, intersections={}} )
    trackIndex = trackIndex + 1
  end
  -- tracks has now a list of segments covering the bounding box of the 
  -- field. 
  findIntersections( polygon, tracks )
  return tracks
end

--- Input is a field boundary (like the innermost headland track) and 
--  a list of segments. The segments represent the parallel tracks. 
--  This function finds the intersections with the the field
--  boundary.
--  As result, tracks will have an intersections member with all 
--  intersection points with polygon, ordered from left to right
function findIntersections( polygon, tracks )
  local ix = function( a ) return getPolygonIndex( polygon, a ) end
  -- loop through the polygon and check each vector from 
  -- the current point to the next
  for i, cp in ipairs( polygon ) do
    local np = polygon[ ix( i + 1 )] 
    for j, t in ipairs( tracks ) do
      local is = getIntersection( cp.x, cp.y, np.x, np.y, t.from.x, t.from.y, t.to.x, t.to.y ) 
      if is then
        -- the line between from and to (the track) intersects the vector from cp to np
        -- remember the polygon vertex where we are intersecting
        is.index = i
        addPointToListOrderedByX( t.intersections, is )
      end
    end
  end
end

--- convert a list of tracks to waypoints, also cutting off
-- the part of the track which is outside of the field.
--
-- use the fact that at this point the field and the tracks
-- are rotated so that the tracks are parallel to the x axle and 
-- the first track has the lowest y coordinate
--
-- Also, we expect the tracks already have the intersection points with
-- the field boundary and there are exactly two intersection points
function addWaypointsToTracks( tracks, width, extendTracks )
  local result = {}
  for i = 1, #tracks do
    if #tracks[ i ].intersections > 1 then
      local newFrom = math.min( tracks[ i ].intersections[ 1 ].x, tracks[ i ].intersections[ 2 ].x ) + width / 2 - extendTracks
      local newTo = math.max( tracks[ i ].intersections[ 1 ].x, tracks[ i ].intersections[ 2 ].x ) - width / 2 + extendTracks
      -- if a track is very short (shorter than width) we may end up with newTo being
      -- less than newFrom. Just skip that track
      if newTo > newFrom then
        tracks[ i ].waypoints = {}
        for x = newFrom, newTo, waypointDistance do
          table.insert( tracks[ i ].waypoints, { x=x, y=tracks[ i ].from.y, track=i })
        end
        -- make sure we actually reached newTo, if waypointDistance is too big we may end up 
        -- well before the innermost headland track or field boundary, or even worse, with just
        -- a single waypoint
        if newTo - tracks[ i ].waypoints[ #tracks[ i ].waypoints ].x > minWaypointDistance then
          table.insert( tracks[ i ].waypoints, { x=newTo, y=tracks[ i ].from.y, track=i })
        end
      end
    end
    -- return only tracks with at least two waypoints
    if tracks[ i ].waypoints then
      if #tracks[ i ].waypoints > 1 then
        table.insert( result, tracks[ i ])
      else
        courseGenerator.debug( string.format( "Track %d has only one waypoint, skipping.", i ))
      end
    end
  end
  return result
end 

--- Start walking on the headland at the given point until
-- we bump onto a corner of an unworked block. 
-- returns the to/from index in headland where the work for this 
-- block ends, that is, where we should start looking for the next block 
function findTrackToNextBlock( blocks, headland, from, to, step )
  local track = {}
  local ix
  for i in polygonIterator( headland, from, to, step ) do
    for j, b in ipairs( blocks ) do
      if not b.covered then
        -- TODO: we are repeating ourselves here a lot, should be refactored
        if i == b.bottomLeftIntersection.index then
          courseGenerator.debug( string.format( "Starting block %d at bottom left", j ))
          b.bottomToTop, b.leftToRight = true, true
          b.covered = true
          -- where we end working the block depends on the number of track
          -- TODO: works only for alternating tracks as long as no track
          -- skipped.
          if #b % 2 == 0 then 
            ix = b.topLeftIntersection.index
            table.insert( track, b.topLeftIntersection.point )
          else
            ix = b.topRightIntersection.index 
            table.insert( track, b.topRightIntersection.point )
          end
          b.trackToThisBlock = track
          return ix, getPolygonIndex( headland, ix - step ), b
        elseif i == b.bottomRightIntersection.index then
          courseGenerator.debug( string.format( "Starting block %d at bottom right", j ))
          b.bottomToTop, b.leftToRight = true, false
          b.covered = true
          if #b % 2 == 0 then 
            ix = b.topRightIntersection.index
            table.insert( track, b.topRightIntersection.point )
          else
            ix = b.topLeftIntersection.index 
            table.insert( track, b.topLeftIntersection.point )
          end
          b.trackToThisBlock = track
          return ix, getPolygonIndex( headland, ix - step ), b
        elseif i == b.topLeftIntersection.index then 
          courseGenerator.debug( string.format( "Starting block %d at top left", j ))
          b.bottomToTop, b.leftToRight = false, true
          b.covered = true
          if #b % 2 == 0 then 
            ix = b.bottomLeftIntersection.index
            table.insert( track, b.bottomLeftIntersection.point )
          else
            ix = b.bottomRightIntersection.index 
            table.insert( track, b.bottomRightIntersection.point )
          end
          b.trackToThisBlock = track
          return ix, getPolygonIndex( headland, ix - step ), b
        elseif i == b.topRightIntersection.index then
          courseGenerator.debug( string.format( "Starting block %d at top right", j ))
          b.bottomToTop, b.leftToRight = false, false
          b.covered = true
          if #b % 2 == 0 then 
            ix = b.bottomRightIntersection.index
            table.insert( track, b.bottomRightIntersection.point )
          else
            ix = b.bottomLeftIntersection.index 
            table.insert( track, b.bottomLeftIntersection.point )
          end
          b.trackToThisBlock = track
          return ix, getPolygonIndex( headland, ix - step ), b
        end
      end
    end -- for all blocks
    table.insert( track, headland[ i ])
  end -- for all points of the headland
  return nil, nil, nil
end

--- Link the parallel tracks in the center of the field to one 
-- continuous track.
-- if bottomToTop == true then start at the bottom and work our way up
-- if leftToRight == true then start the first track on the left 
-- nTracksToSkip - number of tracks to skip when doing alternative 
-- tracks
function linkParallelTracks( result, parallelTracks, bottomToTop, leftToRight, nTracksToSkip ) 
  if not bottomToTop then
    -- we start at the top, so reverse order of tracks as after the generation, 
    -- the last one is on the top
    parallelTracks = reverseTracks( parallelTracks )
  end
  parallelTracks = reorderTracksForAlternateFieldwork( parallelTracks, nTracksToSkip )
  
  -- now make sure that the we work on the tracks in alternating directions
  -- we generate track from left to right, so the ones which we'll traverse
  -- in the other direction must be reversed.
  local start
  if leftToRight then
    -- starting on the left, the first track is not reversed
    start = 2 
  else
    start = 1
  end
  -- reverse every second track
  for i = start, #parallelTracks, 2 do
    parallelTracks[ i ].waypoints = reverse( parallelTracks[ i ].waypoints)
  end
  local startTrack = 1
  local endTrack = #parallelTracks
  local trackStep = 1
  for i = startTrack, endTrack, trackStep do
    if parallelTracks[ i ].waypoints then
      for j, point in ipairs( parallelTracks[ i ].waypoints) do
        -- the first point of a track is the end of the turn (except for the first track)
        if ( j == 1 and i ~= startTrack ) then 
          point.turnEnd = true
        end
        -- the last point of a track is the start of the turn (except for the last track)
        if ( j == #parallelTracks[ i ].waypoints and i ~= endTrack ) then
          point.turnStart = true
        end
        -- these will come in handy for the ridge markers
        point.trackNumber = i 
        point.lastTrack = i == endTrack
        point.firstTrack = i == startTrack
        table.insert( result, point )
      end      
    else
      courseGenerator.debug( string.format( "Track %d has no waypoints, skipping.", i ))
    end
  end
end

--- Check parallel tracks to see if the turn start and turn end waypoints
-- are too far away. If this is the case, add waypoints
-- Assume this is called at the first waypoint of a new track (turnEnd == true)
--
-- This may help the auto turn algorithm, sometimes it can't handle turns 
-- when turnstart and turnend are too far apart
--
function addWaypointsForTurnsWhenNeeded( track )
  local result = {}
  for i, point in ipairs( track ) do
    if point.turnEnd then
      local distanceFromTurnStart = getDistanceBetweenPoints( point, track[ i - 1 ])
      if distanceFromTurnStart > waypointDistance * 2 then
        -- too far, add a waypoint between the start of the current track and 
        -- the end of the previous one.
        local x, y = getPointInTheMiddle( point, track[ i - 1])
        -- also, we are moving the turn end to this new point
        track[ i - 1 ].turnStart = nil
        table.insert( result, { x=x, y=y, turnStart=true })
      end
    end
    table.insert( result, point )
  end
  courseGenerator.debug( "track had " .. #track .. ", result has " .. #result )
  return result
end

--- count tracks based on their intersection with a field boundary
-- if there are two intersections, it is one track
-- if there are more than two, it is actually two or more tracks because of a concave field 
function countTracks( tracks )
  local nFullTracks = 0
  -- tracks intersecting a concave field boundary
  local nSplitTracks = 0 
  -- try to estimate the number of blocks (in case of a non-convex field there'll be at least two)
  local nBlocks = 0
  local nPrevIntersections = 0
  for j, t in ipairs( tracks ) do
    if #t.intersections > 2 then 
      nSplitTracks = nSplitTracks + ( #t.intersections - 2 ) / 2
    else
      nFullTracks = nFullTracks + 1
    end
    -- whenever there's more intersections then it was before then
    -- most likely a new block must be created
    if #t.intersections > nPrevIntersections then
      nBlocks = nBlocks + ( #t.intersections - nPrevIntersections ) / 2
      nPrevIntersections = #t.intersections
    end
    if #t.intersections < nPrevIntersections then
      nPrevIntersections = #t.intersections
    end
  end
  return nFullTracks, nSplitTracks, nBlocks
end

function reverseTracks( tracks )
  local reversedTracks = {}
  for i = #tracks, 1, -1 do
    table.insert( reversedTracks, tracks[ i ])
  end
  return reversedTracks
end

--- Reorder parallel tracks for alternating track fieldwork.
-- This allows for example for working on every odd track first 
-- and then on the even ones so turns at track ends can be wider.
--
-- For example, if we have five tracks: 1, 2, 3, 4, 5, and we 
-- want to skip every second track, we'd work in the following 
-- order: 1, 3, 5, 4, 2
--
function reorderTracksForAlternateFieldwork( parallelTracks, nTracksToSkip )
  -- start with the first track and work up to the last,
  -- skipping every nTrackToSkip tracks.
  local reorderedTracks = {}
  local workedTracks = {}
  local lastWorkedTrack
  -- need to work on this until all tracks are covered
  while ( #reorderedTracks < #parallelTracks ) do
    -- find first non-worked track
    local start = 1
    while workedTracks[ start ] do start = start + 1 end
    for i = start, #parallelTracks, nTracksToSkip + 1 do
      table.insert( reorderedTracks, parallelTracks[ i ])
      workedTracks[ i ] = true
      lastWorkedTrack = i
    end
    -- we reached the last track, now turn back and work on the 
    -- rest, find the last unworked track first
    for i = lastWorkedTrack + 1, 1, - ( nTracksToSkip + 1 ) do
      if ( i <= #parallelTracks ) and not workedTracks[ i ] then
        table.insert( reorderedTracks, parallelTracks[ i ])
        workedTracks[ i ] = true
      end
    end
  end
  return reorderedTracks
end

--- Find blocks of center tracks which have to be worked separately
-- in case of non-convex fields or islands
--
-- These blocks consist of tracks and each of these tracks will have
-- exactly two intersection points with the headland
--
function splitCenterIntoBlocks( tracks, blocks, width )
  local block = {}
  local previousTrack = nil
  for i, t in ipairs( tracks ) do
    -- start at the bottommost track
    -- as long as there are only 2 intersections with the field boundary, we
    -- are ok as this is a convex area
    if #t.intersections >= 2 then
      local trackLength = t.intersections[ 2 ].x - t.intersections[ 1 ].x 
      if trackLength >= width + minWaypointDistance then
        -- add this track to the new block
        -- but move the leftmost two intersections of the original track to this block
        -- first find the two leftmost intersections (min x), which are ix 1 and 2 as 
        -- the list of intersections is ordered by x
        local newTrack = { from=t.from, to=t.to, intersections={ copyPoint( t.intersections[ 1 ]), copyPoint( t.intersections[ 2 ])}}
        -- continue with this block only if the tracks overlap, otherwise we are done with this
        -- block. Don't check first track obviously
        if previousTrack and not overlaps( newTrack, previousTrack ) then
          break
        end
        previousTrack = newTrack
        table.insert( block, newTrack )
        table.remove( t.intersections, 1 )
        table.remove( t.intersections, 1 )
      end
    end
  end
  if #block == 0 then
    -- no tracks could be added to the block, we are done
    return blocks
  else
    -- block has new tracks, add it to the list and continue splitting
    -- for our convenience, remember the corners
    block.bottomLeftIntersection = block[ 1 ].intersections[ 1 ]
    block.bottomRightIntersection = block[ 1 ].intersections[ 2 ]
    block.topLeftIntersection = block[ #block ].intersections[ 1 ]
    block.topRightIntersection = block[ #block ].intersections[ 2 ]
    table.insert( blocks, block )
    return splitCenterIntoBlocks( tracks, blocks, width )
  end
end

--- add a point to a list of intersections but make sure the 
-- list is ordered from left to right, that is, the first element has 
-- the smallest x, the last the greatest x
function addPointToListOrderedByX( is, point )
  local i = #is
  while i > 0 and point.x < is[ i ].x do 
    i = i - 1
  end
  -- don't enter duplicates as that'll result in grid points outside the 
  -- field (when used for the pathfinding)
  if i == 0 or point.x ~= is[ i ].x then
    table.insert( is, i + 1, point )
  end
end

--- check if two tracks overlap. We assume tracks are horizontal
-- and therefore check only the x coordinate
-- also, we assume that both track's endpoints are defined in the
-- intersections list and there are only two intersections.
function overlaps( t1, t2 )
  local t1x1, t1x2 = t1.intersections[ 1 ].x, t1.intersections[ 2 ].x
  local t2x1, t2x2 = t2.intersections[ 1 ].x, t2.intersections[ 2 ].x
  if t1x2 < t2x1 or t2x2 < t1x1 then 
    return false
  else
    return true
  end
end

-- ugly copy paste, should be refactored
local ridgeMarker = {
  none = 0,
  left = 1,
  right = 2
};

--- Add ridge markers to all up/down tracks, including the first and the last.
-- The last one does not need it but we'll take care of that once we know 
-- which track will really be the last one, because if we reverse the course
-- this changes.
--
function addRidgeMarkers( track )
  -- ridge markers should be on the unworked side so 
  -- just check the turn at the end of the first track.
  -- If it is a right turn then we start with the ridge marker on the right
  local turnStartIx = 0
  for i=1, #track do
    if track[ i ].turnStart then 
      turnStartIx = i
      break
    end
  end
  -- first track has one point only, should not happen 
  if turnStartIx < 2 or #track < 3 then return end
  -- Leverage the fact that at this point tracks are parallel to the x axis.
  local drivingToTheRight = track[ turnStartIx ].x > track[ turnStartIx - 1 ].x 
  local turningDown = track[ turnStartIx ].y > track[ turnStartIx + 1 ].y
  local startRidgeMarkerOnTheRight = ( drivingToTheRight and turningDown ) or
                                     ( not drivingToTheRight and not turningDown )
  for i, p in ipairs( track ) do
    if p.trackNumber and not p.turnStart and not p.turnEnd then 
      if p.trackNumber % 2 == 1 then
        -- odd tracks
        if startRidgeMarkerOnTheRight then
          p.ridgeMarker = ridgeMarker.right
        else 
          p.ridgeMarker = ridgeMarker.left
        end
      else 
        -- even tracks
        if startRidgeMarkerOnTheRight then
          p.ridgeMarker = ridgeMarker.left
        else 
          p.ridgeMarker = ridgeMarker.right
        end
      end
    end
  end
end

--- Make sure the last worked up down track does not have 
-- ridge markers.
-- Also, remove the ridge marker after the turn end so it is off
-- during the turn
function removeRidgeMarkersFromLastTrack( course, isReversed )
  for i, p in ipairs( course ) do
    -- if the course is not reversed (working on headland first)
    -- remove ridge markers from the last track
    if not isReversed and p.lastTrack then
      p.ridgeMarker = ridgeMarker.none
    end
    -- if it is reversed, the first track becomes the last
    if isReversed and p.firstTrack then
      p.ridgeMarker = ridgeMarker.none 
    end
    -- if the previous wp is a turn end, remove 
    -- (dunno why, this is how the old course generator works)
    if i > 1 and course[ i - 1 ].turnEnd then
      p.ridgeMarker = ridgeMarker.none
    end
  end
end
