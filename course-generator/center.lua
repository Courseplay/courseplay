--- Functions to generate the up/down tracks in the center
--  of the field (non-headland tracks)

local rotatedMarks = {}

-- Distance of waypoints on the generated track in meters
courseGenerator.waypointDistance = 5
-- don't generate waypoints closer than minWaypointDistance 
local minWaypointDistance = courseGenerator.waypointDistance * 0.25
-- When splitting a field into blocks (due to islands or non-convexity) 
-- consider a block 'small' if it has less than smallBlockTrackCountLimit tracks. 
-- These are not prefered and will get a penalty in the scoring
local smallBlockTrackCountLimit = 5

--- find the corner where we will exit the block if entering at entry corner.
function getBlockExitCorner( entryCorner, nTracks )
	local oddTracks = nTracks % 2 == 1
	local exitCorner
	if entryCorner == courseGenerator.BLOCK_CORNER_BOTTOM_LEFT then
		exitCorner = oddTracks and courseGenerator.BLOCK_CORNER_TOP_RIGHT or courseGenerator.BLOCK_CORNER_TOP_LEFT
	elseif entryCorner == courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT then
		exitCorner = oddTracks and courseGenerator.BLOCK_CORNER_TOP_LEFT or courseGenerator.BLOCK_CORNER_TOP_RIGHT
	elseif entryCorner == courseGenerator.BLOCK_CORNER_TOP_LEFT then
		exitCorner = oddTracks and courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT or courseGenerator.BLOCK_CORNER_BOTTOM_LEFT
	elseif entryCorner == courseGenerator.BLOCK_CORNER_TOP_RIGHT then
		exitCorner = oddTracks and courseGenerator.BLOCK_CORNER_BOTTOM_LEFT or courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT
	end
	return exitCorner
end

function isCornerOnTheBottom( entryCorner )
	return entryCorner == courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT or entryCorner == courseGenerator.BLOCK_CORNER_BOTTOM_LEFT
end

function isCornerOnTheLeft( entryCorner )
	return entryCorner == courseGenerator.BLOCK_CORNER_TOP_LEFT or entryCorner == courseGenerator.BLOCK_CORNER_BOTTOM_LEFT
end
--- Find the best angle to use for the tracks in a polygon.
--  The best angle results in the minimum number of tracks
--  (and thus, turns) needed to cover the polygon.
function findBestTrackAngle( polygon, islands, width, centerSettings )
  local bestAngleStats = {}
  local bestAngleIndex 
  local score
  local minScore = 10000
	polygon:calculateData()	

	-- direction where the field is the longest
  local bestDirection = polygon.bestDirection.dir
	local minAngleDeg, maxAngleDeg, step

	if centerSettings.useLongestEdgeAngle then
		-- use the direction of the longest edge of the polygon
		minAngleDeg, maxAngleDeg, step = - bestDirection, - bestDirection, 1
		courseGenerator.debug( 'ROW ANGLE: USING THE LONGEST FIELD EDGE ANGLE OF %.0f', bestDirection )
	elseif centerSettings.useBestAngle then
		-- find the optimum angle
		minAngleDeg, maxAngleDeg, step = 0, 180, 2
		courseGenerator.debug( 'ROW ANGLE: FINDING THE OPTIMUM ANGLE' )
	else
		-- use the supplied angle
		minAngleDeg, maxAngleDeg, step = math.deg( centerSettings.rowAngle ), math.deg( centerSettings.rowAngle ), 1
		courseGenerator.debug( 'ROW ANGLE: USING THE SUPPLIED ANGLE OF %.0f', courseGenerator.getCompassAngleDeg( math.deg( centerSettings.rowAngle )))
	end
  for angle = minAngleDeg, maxAngleDeg, step do
    local rotated = rotatePoints( polygon, math.rad( angle ))	  

	  local rotatedIslands = Island.rotateAll( islands, math.rad( angle ))

	  local tracks = generateParallelTracks( rotated, rotatedIslands, width )
    local blocks = splitCenterIntoBlocks( tracks, width )
    local smallBlockScore = countSmallBlockScore( blocks )
    -- instead of just the number of tracks, consider some other factors. We prefer just one block (that is,
    -- the field has a convex solution) and angles closest to the direction of the longest edge of the field
    -- sin( angle - BestDir ) will be 0 when angle is the closest.
    local angleScore = 3 * math.abs( math.sin( getDeltaAngle( math.rad( angle ), math.rad( bestDirection )))) 
    score = 50 * smallBlockScore + 10 * #blocks + #tracks + angleScore
	  courseGenerator.debug( "Tried angle=%d, nBlocks=%d, smallBlockScore=%d, tracks=%d, score=%.1f",
	  angle, #blocks, smallBlockScore, #tracks, score)
    table.insert( bestAngleStats, { angle=angle, nBlocks=#blocks, nTracks=#tracks, score=score, smallBlockScore=smallBlockScore })
    if minScore > score then
      minScore = score  
      bestAngleIndex = #bestAngleStats
    end
  end
  local b = bestAngleStats[ bestAngleIndex ]
  courseGenerator.debug( "Best angle=%d, nBlocks=%d, nTracks=%d, smallBlockScore=%d, score=%.1f",
                         b.angle, b.nBlocks, b.nTracks, b.smallBlockScore, b.score)
  -- if we used the angle given by the user and got small blocks generated,
	-- warn them that the course may be less than perfect.
	return b.angle, b.nTracks, b.nBlocks, b.smallBlockScore == 0 or centerSettings.useBestAngle 
end

--- Count the blocks with just a few tracks 
function countSmallBlockScore( blocks )
  local nResult = 0
  -- if there's only one block, we don't care
  if #blocks == 1 then return nResult end
  for _, b in ipairs( blocks ) do
    -- TODO: consider implement width
    if #b < smallBlockTrackCountLimit then
	    nResult = nResult + smallBlockTrackCountLimit - #b
	    --nResult = nResult + 1
    end
  end 
  return nResult
end

--- Generate up/down tracks covering a polygon at the optimum angle
-- 
function generateTracks( polygon, islands, width, nTracksToSkip, extendTracks, addConnectingTracks, centerSettings )
  -- translate polygon so we can rotate it around its center. This way all points
  -- will be approximately the same distance from the origo and the rotation calculation
  -- will be more accurate
  local bb = polygon:getBoundingBox()
  local dx, dy = ( bb.maxX + bb.minX ) / 2, ( bb.maxY + bb.minY ) / 2 
  local translatedPolygon = translatePoints( polygon, -dx , -dy )
	local translatedIslands = Island.translateAll( islands, -dx, -dy )
	local bestAngle, nTracks, nBlocks, resultIsOk
	-- Now, determine the angle where the number of tracks is the minimum
	bestAngle, nTracks, nBlocks, resultIsOk = findBestTrackAngle( translatedPolygon, translatedIslands, width, centerSettings )
	if nBlocks < 1 then
		courseGenerator.debug( "No room for up/down tracks." )
		return nil, 0, 0
	end
	if not bestAngle then
		bestAngle = polygon.bestDirection.dir
		courseGenerator.debug( "No best angle found, use the longest edge direction " .. bestAngle )
	end
	rotatedMarks = Polygon:new()
	-- now, generate the tracks according to the implement width within the rotated polygon's bounding box
  -- using the best angle
  local rotatedBoundary = rotatePoints( translatedPolygon, math.rad( bestAngle ))
	local rotatedIslands = Island.rotateAll( translatedIslands, math.rad( bestAngle ))

	local parallelTracks = generateParallelTracks( rotatedBoundary, rotatedIslands, width )

  local blocks = splitCenterIntoBlocks( parallelTracks, width )

  for i, block in ipairs( blocks ) do
    courseGenerator.debug( "Block %d has %d tracks", i, #block )
    block.tracksWithWaypoints = addWaypointsToTracks( block, width, extendTracks )
    block.covered = false
  end
  
  -- We now have split the area within the headland into blocks. If this is 
  -- a convex polygon, there is only one block, non-convex ones may have multiple
  -- blocks. 
  -- Now we have to connect the first block with the end of the headland track
  -- and then connect each block so we cover the entire polygon.
	math.randomseed( courseGenerator.getCurrentTime())
	local blocksInSequence = findBlockSequence( blocks, rotatedBoundary, polygon.circleStart, polygon.circleStep)
	local workedBlocks = linkBlocks( blocksInSequence, rotatedBoundary, polygon.circleStart, polygon.circleStep)
	
  -- workedBlocks has now a the list of blocks we need to work on, including the track
  -- leading to the block from the previous block or the headland.
  local track = Polygon:new()
  local connectingTracks = {}
  for i, block in ipairs( workedBlocks ) do
	  connectingTracks[ i ] = Polygon:new()
	  local nPoints = block.trackToThisBlock and #block.trackToThisBlock or 0
    courseGenerator.debug( "Track to block %d has %d points", i, nPoints )
    for j = 1, nPoints do
      table.insert( connectingTracks[ i ], block.trackToThisBlock[ j ])
      if addConnectingTracks then
        table.insert( track, block.trackToThisBlock[ j ])
        if j > 3 and j < #block.trackToThisBlock - 1 then
          -- mark this section as a connecting track where implements should be raised as we are 
          -- driving on a previously worked headland track. 
          -- don't mark the first few waypoints to prevent a too early raise and too late lowering
          track[ #track ].isConnectingTrack = true
        end
      end
    end
	  courseGenerator.debug( '%d. block %d, entry corner %d, direction to next = %d, on the bottom = %s, on the left = %s', i, block.id, block.entryCorner,
	    block.directionToNextBlock or 0, tostring( isCornerOnTheBottom( block.entryCorner )), tostring( isCornerOnTheLeft( block.entryCorner )))
    local continueWithTurn = not block.trackToThisBlock
	  if continueWithTurn then
		  track[ #track ].turnStart = true 
	  end
	  linkParallelTracks( track, block.tracksWithWaypoints, 
      isCornerOnTheBottom( block.entryCorner ), isCornerOnTheLeft( block.entryCorner ), nTracksToSkip, continueWithTurn ) 
    fixLongTurns( track, width )
	  addRidgeMarkers( track )
  end

  -- now rotate and translate everything back to the original coordinate system
  if marks then 
    rotatedMarks = translatePoints( rotatePoints( rotatedMarks, -math.rad( bestAngle )), dx, dy )
    for i = 1, #rotatedMarks do
      table.insert( marks, rotatedMarks[ i ])
    end
  end
  for i = 1, #connectingTracks do
    connectingTracks[ i ] = translatePoints( rotatePoints( connectingTracks[ i ], -math.rad( bestAngle )), dx, dy )
  end
  polygon.connectingTracks = connectingTracks
	-- return the information about blocks for visualization
	for _, b in ipairs( blocks ) do
		b.polygon:rotate( -math.rad( bestAngle ))
		b.polygon:translate( dx, dy )
	end
  return translatePoints( rotatePoints( track, -math.rad( bestAngle )), dx, dy ), bestAngle, #parallelTracks, blocks, resultIsOk
end

----------------------------------------------------------------------------------
-- Functions below work on a field rotated so that all parallel tracks are 
-- horizontal ( y = constant ). This makes track calculation really easy.
----------------------------------------------------------------------------------

--- Generate a list of parallel tracks within the field's boundary
-- At this point, tracks are defined only by they endpoints and 
-- are not connected
function generateParallelTracks( polygon, islands, width )
  local tracks = {}
  local function addTrack( fromX, toX, y, ix )
    local from = { x = fromX, y = y, track=ix }
    local to = { x = toX, y = y, track=ix }
    -- for now, all tracks go from min to max, we'll take care of
    -- alternating directions later.
    table.insert( tracks, { from=from, to=to, intersections={}, originalTrackNumber = ix } )
  end
  local trackIndex = 1
  -- go up to maxY - width for now, because the last, uppermost trace must be exactly
  -- width/2 under maxY
  for y = polygon.boundingBox.minY + width / 2, polygon.boundingBox.maxY - width / 2, width do
    addTrack( polygon.boundingBox.minX, polygon.boundingBox.maxX, y, trackIndex ) 
    trackIndex = trackIndex + 1
  end
  -- add the last track 
  addTrack( polygon.boundingBox.minX, polygon.boundingBox.maxX, polygon.boundingBox.maxY - width / 2, trackIndex ) 
  -- tracks has now a list of segments covering the bounding box of the 
  -- field. 
  findIntersections( polygon, tracks )
	for _, island in ipairs( islands ) do
		if #island.headlandTracks > 0 then
			findIntersections( island.headlandTracks[ island.outermostHeadlandIx ], tracks, island.id )
		end
	end
  return tracks
end

--- Input is a field boundary (like the innermost headland track or a
--  headland around an island) and 
--  a list of segments. The segments represent the up/down rows. 
--  This function finds the intersections with the the field
--  boundary.
--  As result, tracks will have an intersections member with all 
--  intersection points with the headland, ordered from left to right
function findIntersections( headland, tracks, islandId )
  -- recalculate angles after the rotation for getDistanceBetweenTrackAndHeadland()
  headland:calculateData()
  -- loop through the polygon and check each vector from 
  -- the current point to the next
  for i, cp in headland:iterator() do
	  local np = headland[ i + 1 ] 
    for j, t in ipairs( tracks ) do
      local is = getIntersection( cp.x, cp.y, np.x, np.y, t.from.x, t.from.y, t.to.x, t.to.y ) 
      if is then
        -- the line between from and to (the track) intersects the vector from cp to np
        -- remember the polygon vertex where we are intersecting
        is.index = i
        -- remember the angle we cross the headland 
        is.angle = cp.tangent.angle
	      is.islandId = islandId
	      -- also remember which headland this was, we have one boundary around the entire 
	      -- field and one around each island.
	      is.headland = headland
	      is.originalTrackNumber = t.originalTrackNumber
	      t.onIsland = islandId
        addPointToListOrderedByX( t.intersections, is )
      end
    end
  end
	-- now that we know which tracks are on the island, detect tracks adjacent to an island
	if islandId then
		for i = 1, #tracks do
			local previousTrack = tracks[ i - 1 ]
			local t = tracks[ i ]
			--print( t.originalTrackNumber, previousTrack and previousTrack.onIsland or nil, t.onIsland )
			if previousTrack and previousTrack.onIsland and not t.onIsland then
				if not t.adjacentIslands then t.adjacentIslands = {} end
				t.adjacentIslands[ islandId ] = true
			end
			if previousTrack and not previousTrack.onIsland and t.onIsland then
				if not previousTrack.adjacentIslands then previousTrack.adjacentIslands = {} end
				previousTrack.adjacentIslands[ islandId ] = true
			end
			previousTrack = t
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
-- the field boundary (or innermost headland) and there are exactly two intersection points
function addWaypointsToTracks( tracks, width, extendTracks )
  local result = {}
  for i = 1, #tracks do
    if #tracks[ i ].intersections > 1 then
      local isFromIx = tracks[ i ].intersections[ 1 ].x < tracks[ i ].intersections[ 2 ].x and 1 or 2
      local newFrom = tracks[ i ].intersections[ isFromIx ].x + 
		  getDistanceBetweenTrackAndHeadland( width, tracks[ i ].intersections[ isFromIx ].angle ) -
		  math.max( extendTracks, width * 0.05 ) -- always overlap a bit with the headland to avoid missing fruit
      local isToIx = tracks[ i ].intersections[ 1 ].x >= tracks[ i ].intersections[ 2 ].x and 1 or 2
      local newTo = tracks[ i ].intersections[ isToIx ].x - 
		  getDistanceBetweenTrackAndHeadland( width, tracks[ i ].intersections[ isToIx ].angle ) + 
		  math.max( extendTracks, width * 0.05 ) -- always overlap a bit with the headland to avoid missing fruit
      -- if a track is very short (shorter than width) we may end up with newTo being
      -- less than newFrom. Just skip that track
      if newTo > newFrom then
        tracks[ i ].waypoints = {}
        for x = newFrom, newTo, courseGenerator.waypointDistance do
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
        courseGenerator.debug( "Track %d has only one waypoint, skipping.", i )
      end
    end
  end
  return result
end 

-- if the up/down tracks were perpendicular to the boundary, we'd have to cut them off
-- width/2 meters from the intersection point with the boundary. But if we drive on to the 
-- boundary at an angle, we have to drive further if we don't want to miss fruit.
-- Note, this also works on unrotated polygons/tracks, all we need is to use the 
-- angle difference between the up/down and headland tracks instead of just the angle
-- of the headland track
function getDistanceBetweenTrackAndHeadland( width, angle )
  -- distance between headland center and side at an angle 
  -- (is width / 2 when angle is 90 degrees)
  local dHeadlandCenterAndSide = math.abs( width / 2 / math.sin( angle ))
  -- and we need to move further so much so even the side of the up/down track
  -- reaches the area covered by the headland (this is 0 when angle is 90 degrees)
  local offset = math.abs( width / 2 / math.tan( angle ))
  return dHeadlandCenterAndSide - offset
end

--- Link the parallel tracks in the center of the field to one 
-- continuous track.
-- if bottomToTop == true then start at the bottom and work our way up
-- if leftToRight == true then start the first track on the left 
-- nTracksToSkip - number of tracks to skip when doing alternative 
-- tracks
function linkParallelTracks( result, parallelTracks, bottomToTop, leftToRight, nTracksToSkip, startWithTurn ) 
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
        if ( j == 1 and ( i ~= startTrack or startWithTurn )) then 
          point.turnEnd = true
        end
        -- the last point of a track is the start of the turn (except for the last track)
        if ( j == #parallelTracks[ i ].waypoints and i ~= endTrack ) then
          point.turnStart = true
        end
        -- these will come in handy for the ridge markers
        point.trackNumber = i 
	      point.originalTrackNumber = parallelTracks[ i ].originalTrackNumber
        point.adjacentIslands = parallelTracks[ i ].adjacentIslands
	      point.lastTrack = i == endTrack
        point.firstTrack = i == startTrack
        table.insert( result, point )
      end      
    else
      courseGenerator.debug( "Track %d has no waypoints, skipping.", i )
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
      if distanceFromTurnStart > courseGenerator.waypointDistance * 2 then
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
function splitCenterIntoBlocks( tracks, width )
	
	function createEmptyBlocks( n )
		local b = {}
		for i = 1, n do
			table.insert( b, {})
		end
		return b
	end
	
	--- We may end up with a bogus block if the island headland intersects the field 
	-- headland. This bogus block will be between the outermost island headland and the
	-- innermost field headland. Try to remove those intersection points.
	-- most likely can happen with a field headland only on non-convex fields but not sure
	-- how to handle that case.
	function cleanupIntersections( is )
		local onIsland = false
		for i = 2, #is do
			if not onIsland and is[ i - 1 ].islandId then
				is[ i - 1 ].deleteThis = true
				is[ i ].deleteThis = true
				onIsland = true
			elseif not onIsland and not is[ i - 1 ].islandId and is[ i ].islandId then
				onIsland = true
			elseif onIsland and not is[ i ].islandId then
				onIsland = false
			end
		end
		for i = #is, 1, -1 do
			if is[ i ].deleteThis then
				table.remove( is, i ) 
			end
		end
	end  
	
	function splitTrack( t )
		local splitTracks = {}
		cleanupIntersections( t.intersections )
		if #t.intersections % 2 ~= 0 or #t.intersections < 2 then
			courseGenerator.debug( 'Found track with odd number (%d) of intersections', #t.intersections )
			table.remove( t.intersections, #t.intersections )
		end
		if t.to.x - t.from.x < 30 then
			courseGenerator.debug( 'Found very short track %.1f m', t.to.x - t.from.x )
		end
		for i = 1, #t.intersections, 2 do
			local track = { from=t.from, to=t.to, 
				intersections={ copyPoint( t.intersections[ i ]), copyPoint( t.intersections[ i + 1 ])},
				originalTrackNumber = t.originalTrackNumber,
				adjacentIslands = t.adjacentIslands }
			table.insert( splitTracks, track )
		end
		return splitTracks
	end
	
	function closeCurrentBlocks( blocks, currentBlocks )
		if currentBlocks then
			for _, block in ipairs( currentBlocks ) do
				-- for our convenience, remember the corners
				block.bottomLeftIntersection = block[ 1 ].intersections[ 1 ]
				block.bottomRightIntersection = block[ 1 ].intersections[ 2 ]
				block.topLeftIntersection = block[ #block ].intersections[ 1 ]
				block.topRightIntersection = block[ #block ].intersections[ 2 ]
				-- this is for visualization only
				block.polygon = Polygon:new()
				block.polygon[ courseGenerator.BLOCK_CORNER_BOTTOM_LEFT ] = block.bottomLeftIntersection
				table.insert( rotatedMarks, block.bottomLeftIntersection )
				rotatedMarks[ #rotatedMarks ].label = courseGenerator.BLOCK_CORNER_BOTTOM_LEFT
				block.polygon[ courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT ] = block.bottomRightIntersection
				table.insert( rotatedMarks, block.bottomRightIntersection )
				rotatedMarks[ #rotatedMarks ].label = courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT
				block.polygon[ courseGenerator.BLOCK_CORNER_TOP_RIGHT ] = block.topRightIntersection
				table.insert( rotatedMarks, block.topRightIntersection )
				rotatedMarks[ #rotatedMarks ].label = courseGenerator.BLOCK_CORNER_TOP_RIGHT
				block.polygon[ courseGenerator.BLOCK_CORNER_TOP_LEFT ] = block.topLeftIntersection
				table.insert( rotatedMarks, block.topLeftIntersection )
				rotatedMarks[ #rotatedMarks ].label = courseGenerator.BLOCK_CORNER_TOP_LEFT
				table.insert( blocks, block )
				block.id = #blocks
			end
		end
	end

	local blocks = {}
	local previousNumberOfIntersections = 0
	local currentNumberOfSections = 0
	local currentBlocks
	for i, t in ipairs( tracks ) do
		local startNewBlock = false
		local splitTracks = splitTrack( t )
		for j, s in ipairs( splitTracks ) do
			if currentBlocks and #currentBlocks == #splitTracks and 
				#t.intersections == previousNumberOfIntersections and 
				not overlaps( currentBlocks[ j ][ #currentBlocks[ j ]], s ) then
				--print( string.format( '%d. overlap currentBlocks = %d, splitTracks = %d', j, currentBlocks and #currentBlocks or 0, #splitTracks ))
				startNewBlock = true
			end
		end
		-- number of track sections after splitting this track. Will be exactly one
		-- if there are no obstacles in the field.
		currentNumberOfSections = math.floor( #t.intersections / 2 )

		if #t.intersections ~= previousNumberOfIntersections or startNewBlock then
			-- start a new block, first save the current ones if exist
			previousNumberOfIntersections = #t.intersections
			closeCurrentBlocks( blocks, currentBlocks )
			currentBlocks = createEmptyBlocks( currentNumberOfSections )
		end
		--print( i, #blocks, #currentBlocks, #splitTracks, currentNumberOfSections )
		for j, s in ipairs( splitTracks ) do
			table.insert( currentBlocks[ j ], s )
		end
	end
	closeCurrentBlocks( blocks, currentBlocks )
	return blocks
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
  for i, p in track:iterator() do
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

--- Fix long turns. These show up when the up/down rows intersect the headland at a 
-- low angle, the turn end may be far away from the start. The turn system can handle these
-- fine but the turn maneuvers are slow and we may end up reversing hundreds of meters.
-- This function makes sure the turn start and end waypoints are close enough
function fixLongTurns( track, width )
	local i = 1
	track:calculateData()
	while i < #track - 1 do
		if track[ i ].turnStart and track[ i + 1 ].turnEnd then
			local d = getDistanceBetweenPoints( track[ i ], track[ i + 1 ])
			if d > 2 * width then
				-- we'll add a new point between the start and end
				local newPoint
				-- move to about width distance 
				local moveDistance = d - width
				if inFrontOf( track[ i + 1 ], track[ i ]) then
					newPoint = copyPoint( track[ i ])
					-- turn end is in front of turn start so move the turn start closer 
					newPoint.x, newPoint.y = getPointBetween( track[ i ], track[ i + 1 ], moveDistance )
					-- the new point is the turn start
					newPoint.turnStart = true
					-- old turn start is not turn start anymore
					track[ i ].turnStart = nil
				else
					-- turn end is behind the turn start, move turn end closer 
					newPoint = copyPoint( track[ i + 1 ])
					newPoint.x, newPoint.y = getPointBetween( track[ i + 1 ], track[ i ], moveDistance )
					newPoint.turnEnd = true
					track[ i + 1 ].turnEnd = nil
				end
				courseGenerator.debug( "Fixing a long (%.0fm) turn on track %d.", d, track[ i ].originalTrackNumber )
				-- insert the new point 
				table.insert( track, i + 1, newPoint )
				i = i + 1
			end
		end
		i = i + 1
	end
end
-- We are using a genetic algorithm to find the optimum sequence of the blocks to work on.
-- In case of a non-convex field or a field with island(s) in it, the field is divided into
-- multiple areas (blocks) which are covered by the up/down rows independently. 

-- We are looking for the optimum route to work these blocks, meaning the one with the shortest
-- path between the blocks. There are two factors determining the length of this path: 
-- 1. the sequence of blocks
-- 2. where do we start each block (which corner), which alse determines the exit corner of 
--    the block.
--
-- Most of this is based on the following paper:
-- Ibrahim A. Hameed, Dionysis Bochtis and Claus A. Sørensen: An Optimized Field Coverage Planning
-- Approach for Navigation of Agricultural Robots in Fields Involving Obstacle Areas

--- Composit chromosome for a field block to determine the best sequence of blocks 
FieldBlockChromosome = newClass()

function FieldBlockChromosome:new( nBlocks )
	local instance = {}
	local blockNumbers = {}
	-- array of +1 or -1. +1 at index 2 means that to reach the entry point of the second block
	-- from the exit point of the first you have to go increasing indexes on the headland.
	instance.directionToNextBlock = {}
	for i = 1, nBlocks do table.insert( blockNumbers, i ) end
	-- this chromosome has the sequence of blocks encoded
	instance.blockSequence = PermutationEncodedChromosome:new( nBlocks, blockNumbers )
	-- this chromosome has the entry point for each block encoded
	instance.entryCorner = ValueEncodedChromosome:new( nBlocks, { courseGenerator.BLOCK_CORNER_BOTTOM_LEFT, courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT,
		courseGenerator.BLOCK_CORNER_TOP_RIGHT, courseGenerator.BLOCK_CORNER_TOP_LEFT })
	return setmetatable( instance, self )
end

function FieldBlockChromosome:__tostring()
	local str = ''
	for _, b in ipairs( self.blockSequence ) do
		str = string.format( '%s%d(%d)-', str, b, self.entryCorner[ b ])
	end
	if self.distance and self.fitness then
		str = string.format( '%s f = %.1f, d = %.1f m', str, self.fitness, self.distance )
	end
	return str
end

function FieldBlockChromosome:fillWithRandomValues()
	self.blockSequence:fillWithRandomValues()
	self.entryCorner:fillWithRandomValues()
end

function FieldBlockChromosome:crossover( spouse ) 
	local offspring = FieldBlockChromosome:new( #self.blockSequence )
	offspring.blockSequence = self.blockSequence:crossover( spouse.blockSequence )
	offspring.entryCorner = self.entryCorner:crossover( spouse.entryCorner )
	return offspring
end

function FieldBlockChromosome:mutate( mutationRate )
	self.blockSequence:mutate( mutationRate )
	self.entryCorner:mutate( mutationRate )
end

--- Find the (near) optimum sequence of blocks and entry/exit points.
-- NOTE: remmeber to call randomseed before. It isn't part of this function
-- to allow for automatic tests.
-- headland is the innermost headland pass.
--
function findBlockSequence( blocks, headland, circleStart, circleStep )
	-- GA parameters, depending on the number of blocks
	local maxGenerations = 10 * #blocks
	local tournamentSize = 5
	local mutationRate = 0.03
	local populationSize = 40 * #blocks

	--- Calculate the fitness of a solution.
	--
	-- Calculate the distance to move between block exits and entrances for all 
	-- blocks in the given sequence. The fitness is the recoprocal of the distance
	-- so shorter routes are fitter.
	function calculateFitness( chromosome )
		chromosome.distance = 0
		for i = 1, #chromosome.blockSequence do
			local currentBlockIx = chromosome.blockSequence[ i ]
			local currentBlockExitCorner = getBlockExitCorner( chromosome.entryCorner[ currentBlockIx ], #blocks[ currentBlockIx ] )
			local currentBlockExitPoint = blocks[ currentBlockIx ].polygon[ currentBlockExitCorner ]
			-- in case of the first block we need to add the distance to drive from the end of the 
			-- innermost headland track to the entry point of the first block
			local distance, dir
			if i == 1 then
				local currentBlockEntryPoint = blocks[ currentBlockIx ].polygon[ chromosome.entryCorner[ currentBlockIx ]]
				-- TODO: this table comparison assumes the intersections were found on the same exact
				-- table instance as this upvalue headland. Ugly, should use some headland ID instead
				if headland == currentBlockEntryPoint.headland then
					distance, dir = getDistanceBetweenPointsOnHeadland( headland, circleStart, currentBlockEntryPoint.index, { circleStep } )
					chromosome.distance, chromosome.directionToNextBlock[ currentBlockIx ] = chromosome.distance + distance, dir
				else
					-- this block's entry point is not on the innermost headland (may be on an island)
					chromosome.distance, chromosome.directionToNextBlock[ currentBlockIx ] = math.huge, 1
				end 
			end
			-- add the distance to the next block (except for the last)
			if i < #chromosome.blockSequence then
				local nextBlockIx = chromosome.blockSequence[ i + 1 ]
				local nextBlockEntryPoint = blocks[ nextBlockIx ].polygon[ chromosome.entryCorner[ nextBlockIx ]]
				if currentBlockExitPoint.headland == nextBlockEntryPoint.headland then
					-- can reach the next block on the same headland					
					distance, dir = getDistanceBetweenPointsOnHeadland( currentBlockExitPoint.headland, currentBlockExitPoint.index, nextBlockEntryPoint.index, { -1, 1 } )
					chromosome.distance, chromosome.directionToNextBlock[ currentBlockIx ] = chromosome.distance + distance, dir
				else
					-- next block's entry point is on a different headland, do not allow this by making
					-- this solution unfit
					chromosome.distance, chromosome.directionToNextBlock[ currentBlockIx ] = math.huge, 1
				end
			end
		end
		chromosome.fitness = math.floor( 10000 / chromosome.distance )
		return chromosome.fitness
	end

	--- Distance when driving on a headland between is1 and is2. These are expected to be 
	-- intersection points with the headland stored. directions is a list of 
	-- values -1 or 1, and determines which directions we try to drive on the headland 
	function getDistanceBetweenPointsOnHeadland( headland, ix1, ix2, directions )
		local distanceMin = math.huge
		local directionMin = 0
		for _, d in ipairs( directions ) do
			local found = false
			local distance = 0
			for i in headland:iterator( ix1, ix1 - d, d ) do
				distance = distance + headland[ i ].nextEdge.length
				if i == ix2 then
					found = true
					break
				end
			end
			distance = found and distance or math.huge
			if distance < distanceMin then
				distanceMin = distance
				directionMin = d
			end
		end
		return distanceMin, directionMin
	end
	
	
	-- Set up the initial population with random solutions
	local population = Population:new( calculateFitness, tournamentSize, mutationRate )
	population:initialize( populationSize, function()
		local c = FieldBlockChromosome:new( #blocks )
		c:fillWithRandomValues()
		return c
	end )

	-- let the solution evolve through multiple generations
	population:calculateFitness()
	local generation = 1
	while generation < maxGenerations do
		local newGeneration = population:breed()
		population:recombine( newGeneration )
		generation = generation + 1
	end
	courseGenerator.debug( tostring( population.bestChromosome ))
	-- this table contains the blocks and other relevant data in the order they have to be worked on
	local blocksInSequence = {}
	for i = 1, #blocks do
		local blockIx = population.bestChromosome.blockSequence[ i ]
		local block = blocks[ blockIx ]
		block.entryCorner = population.bestChromosome.entryCorner[ blockIx ] -- corner where this block should be entered
		block.directionToNextBlock = population.bestChromosome.directionToNextBlock[ blockIx ] -- step direction on the headland index to take
		table.insert( blocksInSequence, block )
	end
	return blocksInSequence, population.bestChromosome
end


function getTrackBetweenPointsOnHeadland( headland, startIx, endIx, step )
	local track = Polyline:new()
	for i in headland:iterator( startIx, endIx, step ) do
		table.insert( track, headland[ i ])
	end
	-- remove first and last point to provide a smoother transition to the up/down rows.
	-- if we don't do this, the first or last waypoint on the headland may be behind 
	-- the current track wp and thus we first turn 180 back and then forward again
	table.remove( track, 1 )
	table.remove( track, #track )
	return track
end

function linkBlocks( blocksInSequence, innermostHeadland, circleStart, firstBlockDirection )
	local workedBlocks = {}
	for i, block in ipairs( blocksInSequence ) do
		if i == 1 then
			-- the track to the first block starts at the end of the innermost headland
			block.trackToThisBlock = getTrackBetweenPointsOnHeadland(	innermostHeadland, circleStart,
																													block.polygon[ block.entryCorner ].index, firstBlockDirection )
		end
		if i > 1 then
			-- for the rest of the blocks, the track to the block is from the exit point of the previous block
			local previousBlock = blocksInSequence[ i - 1 ]
			local previousBlockExitCorner = getBlockExitCorner( previousBlock.entryCorner, #previousBlock )
			local headland = block.polygon[ block.entryCorner ].headland
			local previousOriginalTrackNumber = previousBlock.polygon[ previousBlockExitCorner ].originalTrackNumber
			local thisOriginalTrackNumber = block.polygon[ block.entryCorner ].originalTrackNumber
			-- Don't need a connecting track when these were originally adjacent tracks.
			if math.abs( previousOriginalTrackNumber - thisOriginalTrackNumber ) ~= 1 then
				block.trackToThisBlock = getTrackBetweenPointsOnHeadland( headland, previousBlock.polygon[ previousBlockExitCorner ].index,
				block.polygon[ block.entryCorner ].index, previousBlock.directionToNextBlock )
			else
				
			end
		end
		table.insert( workedBlocks, block )
	end
	return workedBlocks
end


--- starting at i, find the first turn start waypoint in a reasonable distance 
-- and return the index of it
function skipToTurnStart( course, start, step ) 
	local ix = start
	local d = 0
	while d < 4 * courseGenerator.waypointDistance and ix < #course and ix > 1 do
		if course[ ix ].turnStart then return ix end
		d = d + course[ ix ].nextEdge.length
		ix = ix + step
	end
	return start
end

function removeTurn( course, i, step )
	if course[ i ].turnStart then
		course[ i ].turnStart = nil
		course[ i + 1 ].turnEnd = nil
	end
end