--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--- Functions to generate the up/down tracks in the center
--  of the field (non-headland tracks)

local rotatedMarks = {}

-- Up/down mode is a regular up/down pattern, may skip rows between for wider turns

courseGenerator.CENTER_MODE_UP_DOWN = 1

-- Spiral mode: the center is split into multiple blocks, one block
-- is not more than 10 rows wide. Each block is then worked in a spiral
-- fashion from the outside to the inside, see below:

--  ----- 1 ---- < -------  \
--  ----- 3 ---- < -------  |
--  ----- 5 ---- < -------  |
--  ----- 6 ---- > -------  | Block 1
--  ----- 4 ---- > -------  |
--  ----- 2 ---- > -------  /
--  ----- 7 ---- < -------  \
--  ----- 9 ---- < -------  |
--  -----11 ---- < -------  | Block 2
--  -----12 ---- > -------  |
--  -----10 ---- > -------  |
--  ----- 8 ---- > -------  /
courseGenerator.CENTER_MODE_SPIRAL = 2

-- Circular mode, (for now) the area is split into multiple blocks which are then worked one by one. Work in each
-- block starts around the middle, skipping a maximum of four rows to avoid 180 turns and working the block in
-- a circular, racetrack like pattern.
-- Depending on the number of rows, there may be a few of them left at the end which will need to be worked in a
-- regular up/down pattern
--  ----- 2 ---- > -------     \
--  ----- 4 ---- > -------     |
--  ----- 6 ---- > -------     |
--  ----- 8 ---- > -------     | Block 1
--  ----- 1 ---- < -------     |
--  ----- 3 ---- < -------     |
--  ----- 5 ---- < ------      |
--  ----- 7 ---- < -------     /
--  -----10 ---- > -------    \
--  -----12 ---- > -------     |
--  ----- 9 ---- < -------     | Block 2
--  -----11 ---- < -------     /
courseGenerator.CENTER_MODE_CIRCULAR = 3
courseGenerator.centerModeTexts = {'up/down', 'spiral', 'circular'}
courseGenerator.CENTER_MODE_MIN = courseGenerator.CENTER_MODE_UP_DOWN
courseGenerator.CENTER_MODE_MAX = courseGenerator.CENTER_MODE_CIRCULAR

-- Distance of waypoints on the generated track in meters
courseGenerator.waypointDistance = 5
-- don't generate waypoints closer than minWaypointDistance 
local minWaypointDistance = courseGenerator.waypointDistance * 0.25
-- When splitting a field into blocks (due to islands or non-convexity) 
-- consider a block 'small' if it has less than smallBlockTrackCountLimit tracks. 
-- These are not prefered and will get a penalty in the scoring
local smallBlockTrackCountLimit = 5

-- 3D table returning the exit corner
-- first dimension is the entry corner
-- second dimension is a boolean: if true, the exit is on the same side (left/right)
-- third dimension is a boolean: if true, the exit is on the same edge (top/bottom)
local exitCornerMap = {
	[courseGenerator.BLOCK_CORNER_BOTTOM_LEFT] = {
		[true] = { [true] = courseGenerator.BLOCK_CORNER_BOTTOM_LEFT, [false] = courseGenerator.BLOCK_CORNER_TOP_LEFT },
		[false] = {[true] = courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT,[false] = courseGenerator.BLOCK_CORNER_TOP_RIGHT}
	},
	[courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT] = {
		[true] = { [true] = courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT,[false] = courseGenerator.BLOCK_CORNER_TOP_RIGHT },
		[false] = {[true] = courseGenerator.BLOCK_CORNER_BOTTOM_LEFT, [false] = courseGenerator.BLOCK_CORNER_TOP_LEFT}
	},
	[courseGenerator.BLOCK_CORNER_TOP_LEFT] = {
		[true] = { [true] = courseGenerator.BLOCK_CORNER_TOP_LEFT,    [false] = courseGenerator.BLOCK_CORNER_BOTTOM_LEFT },
		[false] = {[true] = courseGenerator.BLOCK_CORNER_TOP_RIGHT,   [false] = courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT}
	},
	[courseGenerator.BLOCK_CORNER_TOP_RIGHT] = {
		[true] = { [true] = courseGenerator.BLOCK_CORNER_TOP_RIGHT,   [false] = courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT },
		[false] = {[true] = courseGenerator.BLOCK_CORNER_TOP_LEFT,    [false] = courseGenerator.BLOCK_CORNER_BOTTOM_LEFT}
	},
}

--- find the corner where we will exit the block if entering at entry corner.
function getBlockExitCorner( entryCorner, nRows, nRowsToSkip )
	-- if we have an even number of rows, we'll end up on the same side (left/right)
	local sameSide = nRows % 2 == 0
	-- if we skip an odd number of rows, we'll end up where we started (bottom/top)
	local sameEdge = nRowsToSkip % 2 == 1
	return exitCornerMap[ entryCorner ][ sameSide ][ sameEdge ]
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
function findBestTrackAngle( polygon, islands, width, distanceFromBoundary, centerSettings )
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

		local tracks = generateParallelTracks( rotated, rotatedIslands, width, distanceFromBoundary )
		local blocks = splitCenterIntoBlocks( tracks, width )
		local smallBlockScore = countSmallBlockScore( blocks )
		-- instead of just the number of tracks, consider some other factors. We prefer just one block (that is,
		-- the field has a convex solution) and angles closest to the direction of the longest edge of the field
		-- sin( angle - BestDir ) will be 0 when angle is the closest.
		local angleScore = bestDirection and
			3 * math.abs( math.sin( getDeltaAngle( math.rad( angle ), math.rad( bestDirection )))) or 0
		score = 50 * smallBlockScore + 10 * #blocks + #tracks + angleScore
		-- courseGenerator.debug( "Tried angle=%d, nBlocks=%d, smallBlockScore=%d, tracks=%d, score=%.1f",
		--	angle, #blocks, smallBlockScore, #tracks, score)
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
function generateTracks( headlands, islands, width, extendTracks, nHeadlandPasses, centerSettings )
	local distanceFromBoundary
	if nHeadlandPasses == 0 then
		-- ugly hack: if there are no headlands, our tracks go right up to the field boundary. So extend tracks
		-- exactly width / 2
		extendTracks = extendTracks + width / 2
		distanceFromBoundary = width / 2
	else
		distanceFromBoundary = width
	end

	-- translate headlands so we can rotate them around their center. This way all points
	-- will be approximately the same distance from the origin and the rotation calculation
	-- will be more accurate
	-- get the innermost headland
	local boundary = headlands[#headlands]
	local dx, dy = boundary:getCenter()
	-- headlands transformed in the field centered coordinate system. First, just translate, will rotate once
	-- we figure out the angle
	local transformedHeadlands = {}
	for _, headland in ipairs(headlands) do
		local h = Polygon:copy(headland)
		h:translate(-dx, -dy)
		table.insert(transformedHeadlands, h)
	end

	local translatedIslands = Island.translateAll( islands, -dx, -dy )

	local bestAngle, nTracks, nBlocks, resultIsOk
	-- Now, determine the angle where the number of tracks is the minimum
	bestAngle, nTracks, nBlocks, resultIsOk = findBestTrackAngle( transformedHeadlands[#transformedHeadlands], translatedIslands, width, distanceFromBoundary, centerSettings )
	if nBlocks < 1 then
		courseGenerator.debug( "No room for up/down rows." )
		return nil, 0, 0, nil, true
	end
	if not bestAngle then
		bestAngle = boundary.bestDirection.dir
		courseGenerator.debug( "No best angle found, use the longest edge direction " .. bestAngle )
	end
	rotatedMarks = Polygon:new()
	-- now, generate the tracks according to the implement width within the rotated boundary's bounding box
	-- using the best angle
	-- rotate everything we'll need later
	for _, headland in ipairs(transformedHeadlands) do
		headland:rotate(math.rad(bestAngle))
	end
	local transformedBoundary = transformedHeadlands[#transformedHeadlands]
	local rotatedIslands = Island.rotateAll( translatedIslands, math.rad( bestAngle ))
	local parallelTracks = generateParallelTracks( transformedBoundary, rotatedIslands, width, distanceFromBoundary )

	local blocks = splitCenterIntoBlocks( parallelTracks, width )

	-- using a while loop as we'll remove blocks if they have no tracks
	local nTotalTracks = 0
	local i = 1
	while blocks[i] do
		local block = blocks[i]
		nTotalTracks = nTotalTracks + #block
		courseGenerator.debug( "Block %d has %d tracks", i, #block )
		block.tracksWithWaypoints = addWaypointsToTracks( block, width, extendTracks )
		block.covered = false
		-- we may end up with blocks without tracks in case we did not find a single track
		-- with at least two waypoints. Now remove those blocks
		if #blocks[i].tracksWithWaypoints == 0 then
			courseGenerator.debug( "Block %d removed as it has no tracks with waypoints", i)
			table.remove(blocks, i)
		else
			i = i + 1
		end
	end

	if #blocks > 30 or ( #blocks > 1 and ( nTotalTracks / #blocks ) < 2 ) then
		-- don't waste time on unrealistic problems
		courseGenerator.debug( 'Implausible number of blocks/tracks (%d/%d), not generating up/down rows', #blocks, nTotalTracks )
		return nil, 0, 0, nil, false
	end

	-- We now have split the area within the headland into blocks. If this is
	-- a convex polygon, there is only one block, non-convex ones may have multiple
	-- blocks.
	-- Now we have to connect the first block with the end of the headland track
	-- and then connect each block so we cover the entire polygon.
	math.randomseed( courseGenerator.getCurrentTime())
	local blocksInSequence = findBlockSequence( blocks, transformedBoundary, boundary.circleStart, boundary.circleStep, nHeadlandPasses, centerSettings.nRowsToSkip)
	local workedBlocks = linkBlocks( blocksInSequence, transformedBoundary, boundary.circleStart, boundary.circleStep, centerSettings.nRowsToSkip)

	-- workedBlocks has now a the list of blocks we need to work on, including the track
	-- leading to the block from the previous block or the headland.
	local track = Polygon:new()
	local connectingTracks = {} -- only for visualization/debug
	for i, block in ipairs( workedBlocks ) do
		connectingTracks[ i ] = Polygon:new()
		local nPoints = block.trackToThisBlock and #block.trackToThisBlock or 0
		courseGenerator.debug( "Connecting track to block %d has %d points", i, nPoints )
		-- do not add connecting tracks to the first block if there's no headland
		if nHeadlandPasses > 0 then
			for j = 1, nPoints do
				table.insert( connectingTracks[ i ], block.trackToThisBlock[ j ])
				table.insert( track, block.trackToThisBlock[ j ])
				-- mark this section as a connecting track where implements should be raised as we are
				-- driving on a previously worked headland track.
				track[ #track ].isConnectingTrack = true
			end
		end
		courseGenerator.debug( '%d. block %d, entry corner %d, direction to next = %d, on the bottom = %s, on the left = %s', i, block.id, block.entryCorner,
			block.directionToNextBlock or 0, tostring( isCornerOnTheBottom( block.entryCorner )), tostring( isCornerOnTheLeft( block.entryCorner )))
		local continueWithTurn = not block.trackToThisBlock
		if continueWithTurn then
			track[ #track ].turnStart = true
		end
		local linkedTracks = linkParallelTracks(block.tracksWithWaypoints,
			isCornerOnTheBottom( block.entryCorner ), isCornerOnTheLeft( block.entryCorner ), centerSettings, continueWithTurn,
			transformedHeadlands, rotatedIslands, width)
		if not continueWithTurn then
			-- this is a transition to/from up/down rows and may need to be fixed
			-- by adding a turn if the delta angle is high enough.
			-- for now, mark it, will fix after everything is finished
			linkedTracks[1].mayNeedTurn = true
		end
		for _, p in ipairs(linkedTracks) do
			table.insert(track, p)
		end
		-- TODO: This seems to be causing circling with large implements, disabling for now.
		-- fixLongTurns( track, width )
	end

	if centerSettings.nRowsToSkip == 0 then
		-- do not add ridge markers if we are skipping rows, don't need when working with GPS :)
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
	boundary.connectingTracks = connectingTracks
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
function generateParallelTracks( polygon, islands, width, distanceFromBoundary )
	local tracks = {}
	local function addTrack( fromX, toX, y, ix )
		local from = { x = fromX, y = y, track=ix }
		local to = { x = toX, y = y, track=ix }
		-- for now, all tracks go from min to max, we'll take care of
		-- alternating directions later.
		table.insert( tracks, { from=from, to=to, intersections={}, originalTrackNumber = ix } )
	end
	local trackIndex = 1
	for y = polygon.boundingBox.minY + distanceFromBoundary, polygon.boundingBox.maxY - distanceFromBoundary, width do
		addTrack( polygon.boundingBox.minX, polygon.boundingBox.maxX, y, trackIndex )
		trackIndex = trackIndex + 1
	end
	-- add the last track
	addTrack( polygon.boundingBox.minX, polygon.boundingBox.maxX, polygon.boundingBox.maxY - distanceFromBoundary, trackIndex )
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
				-- remember where we intersect the headland.
				is.headlandVertexIx = i
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
		else
			courseGenerator.debug('Track %d has no waypoints', i)
		end
	end
	courseGenerator.debug('Generated %d tracks for this block', #result)
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
-- centerSettings - all center related settings
-- tracks
function linkParallelTracks(parallelTracks, bottomToTop, leftToRight, centerSettings, startWithTurn, headlands,
														islands, workWidth)
	if not bottomToTop then
		-- we start at the top, so reverse order of tracks as after the generation,
		-- the last one is on the top
		parallelTracks = reverseTracks( parallelTracks )
	end
	if centerSettings.mode == courseGenerator.CENTER_MODE_UP_DOWN then
		parallelTracks = reorderTracksForAlternateFieldwork(parallelTracks, centerSettings.nRowsToSkip)
	elseif centerSettings.mode == courseGenerator.CENTER_MODE_SPIRAL then
		parallelTracks = reorderTracksForSpiralFieldwork(parallelTracks)
	elseif centerSettings.mode == courseGenerator.CENTER_MODE_CIRCULAR then
		parallelTracks = reorderTracksForCircularFieldwork(parallelTracks)
	end
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
	local result = Polyline:new()
	local startTrack = 1
	local endTrack = #parallelTracks
	for i = startTrack, endTrack do
		if parallelTracks[ i ].waypoints then
			-- use turn maneuver from one track to the other if they are close to each other
			local useHeadlandFromPreviousRow = useHeadlandToNextRow
			for j, point in ipairs( parallelTracks[ i ].waypoints) do
				-- the first point of a track is the end of the turn (except for the first track)
				if ( j == 1 and ( i ~= startTrack or startWithTurn ) and not useHeadlandFromPreviousRow) then
					point.turnEnd = true
				end
				-- these will come in handy for the ridge markers
				point.trackNumber = i
				point.originalTrackNumber = parallelTracks[ i ].originalTrackNumber
				point.adjacentIslands = parallelTracks[ i ].adjacentIslands
				point.lastTrack = i == endTrack
				point.firstTrack = i == startTrack
				-- the last point of a track is the start of the turn (except for the last track)
				if ( j == #parallelTracks[ i ].waypoints and i ~= endTrack ) then
					point.turnStart = true
					table.insert( result, point )
				else
					table.insert( result, point )
				end
			end
		else
			courseGenerator.debug( "Track %d has no waypoints, skipping.", i )
		end
	end
	return result
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
function reorderTracksForAlternateFieldwork( parallelTracks, nRowsToSkip )
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
		for i = start, #parallelTracks, nRowsToSkip + 1 do
			table.insert( reorderedTracks, parallelTracks[ i ])
			workedTracks[ i ] = true
			lastWorkedTrack = i
		end
		-- we reached the last track, now turn back and work on the
		-- rest, find the last unworked track first
		for i = lastWorkedTrack + 1, 1, - ( nRowsToSkip + 1 ) do
			if ( i <= #parallelTracks ) and not workedTracks[ i ] then
				table.insert( reorderedTracks, parallelTracks[ i ])
				workedTracks[ i ] = true
			end
		end
	end
	return reorderedTracks
end

--- See courseGenerator.CENTER_MODE_SPIRAL for an explanation
function reorderTracksForSpiralFieldwork(parallelTracks)
	local reorderedTracks = {}
	for i = 1, math.floor(#parallelTracks / 2) do
		table.insert(reorderedTracks, parallelTracks[i])
		table.insert(reorderedTracks, parallelTracks[#parallelTracks - i + 1])
	end
	if #parallelTracks % 2 ~= 0 then
		table.insert(reorderedTracks, parallelTracks[math.ceil(#parallelTracks /2)])
	end
	return reorderedTracks
end

--- See courseGenerator.CENTER_MODE_CIRCULAR for an explanation
function reorderTracksForCircularFieldwork(parallelTracks)
	local reorderedTracks = {}
	local SKIP_FWD = {} -- skipping rows towards the end of field
	local SKIP_BACK = {} -- skipping rows towards the beginning of the field
	local FILL_IN = {} -- filling in whatever is left after skipping
	local n = #parallelTracks
	local nSkip = 4
	local rowsDone = {}
	-- start in the middle
	local i = nSkip + 1
	table.insert(reorderedTracks, parallelTracks[i])
	rowsDone[i] = true
	local nDone = 1
	local mode = SKIP_BACK
	-- start circling
	while nDone < n do
		local nextI
		if mode == SKIP_FWD then
			nextI = i + nSkip + 1
			mode = SKIP_BACK
		elseif mode == SKIP_BACK then
			nextI = i - nSkip
			mode = SKIP_FWD
		elseif mode == FILL_IN then
			nextI = i + 1
		end
		if rowsDone[nextI] then
			-- this has been done already, so skip forward to the next block
			nextI = i + nSkip + 1
			mode = SKIP_BACK
		end
		if nextI > n then
			-- reached the end of the field with the current skip, start skipping less, but keep skipping rows
			-- as long as we can to prevent backing up in turn maneuvers
			nSkip = math.floor((n - nDone) / 2)
			if nSkip > 0 then
				nextI = i + nSkip + 1
				mode = SKIP_BACK
			else
				-- no room to skip anymore
				mode = FILL_IN
				nextI = i + 1
			end
		end
		i = nextI
		rowsDone[i] = true
		table.insert(reorderedTracks, parallelTracks[i])
		nDone = nDone + 1
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
		if t.to.x - t.from.x < 15 then
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

--- Add ridge markers to all up/down tracks, including the first and the last.
-- The last one does not need it but we'll take care of that once we know 
-- which track will really be the last one, because if we reverse the course
-- this changes.
--
function addRidgeMarkers( track )
	-- ridge markers should be on the unworked side so
	-- just check the turn at the end of the row.
	-- If it is a right turn then we start with the ridge marker on the right
	function getNextTurnDir(startIx)
		for i = startIx, #track do
			-- it is an up/down row if it has track number. Otherwise ignore turns
			if track[i].trackNumber and track[i].turnStart and track[i].deltaAngle then
				if track[i].deltaAngle >= 0 then
					return i, courseplay.RIDGEMARKER_RIGHT
				else
					return i, courseplay.RIDGEMARKER_LEFT
				end
			end
		end
		return nil
	end

	track:calculateData()
	local i = 1

	while (i < #track) do
		local startTurnIx, turnDirection = getNextTurnDir(i)
		if not startTurnIx then break end
		-- drive up to the next turn and add ridge markers where applicable
		while (i < startTurnIx) do
			-- don't use ridge markers at the first and the last row of the block as
			-- blocks can be worked in any order and we may screw up the adjacent block
			if track[i].trackNumber and not track[i].lastTrack and not track[i].firstTrack then
				if turnDirection == courseplay.RIDGEMARKER_RIGHT then
					track[i].ridgeMarker = courseplay.RIDGEMARKER_RIGHT
				else
					track[i].ridgeMarker = courseplay.RIDGEMARKER_LEFT
				end
			end
			i = i + 1
		end
		-- we are at the start of the turn now, step over the turn start/end
		-- waypoints and work on the next row, find the next turn
		i = i + 2
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
			p.ridgeMarker = courseplay.RIDGEMARKER_NONE
		end
		-- if it is reversed, the first track becomes the last
		if isReversed and p.firstTrack then
			p.ridgeMarker = courseplay.RIDGEMARKER_NONE
		end
		-- if the previous wp is a turn end, remove
		-- (dunno why, this is how the old course generator works)
		if i > 1 and course[ i - 1 ].turnEnd then
			p.ridgeMarker = courseplay.RIDGEMARKER_NONE
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
function findBlockSequence( blocks, headland, circleStart, circleStep, nHeadlandPasses, nRowsToSkip )
	-- GA parameters, depending on the number of blocks
	local maxGenerations = 10 * #blocks
	local tournamentSize = 5
	local mutationRate = 0.03
	local populationSize = 40 * #blocks

	--- Calculate the fitness of a solution.
	--
	-- Calculate the distance to move between block exits and entrances for all 
	-- blocks in the given sequence. The fitness is the reciprocal of the distance
	-- so shorter routes are fitter.
	function calculateFitness( chromosome )
		chromosome.distance = 0
		for i = 1, #chromosome.blockSequence do
			local currentBlockIx = chromosome.blockSequence[ i ]
			local currentBlockExitCorner = getBlockExitCorner( chromosome.entryCorner[ currentBlockIx ], #blocks[ currentBlockIx ], nRowsToSkip )
			local currentBlockExitPoint = blocks[ currentBlockIx ].polygon[ currentBlockExitCorner ]
			-- in case of the first block we need to add the distance to drive from the end of the 
			-- innermost headland track to the entry point of the first block
			local distance, dir
			if i == 1 then
				local currentBlockEntryPoint = blocks[ currentBlockIx ].polygon[ chromosome.entryCorner[ currentBlockIx ]]
				-- TODO: this table comparison assumes the intersections were found on the same exact
				-- table instance as this upvalue headland. Ugly, should use some headland ID instead
				if headland == currentBlockEntryPoint.headland then
					if nHeadlandPasses > 0 then
						distance, dir = getDistanceBetweenPointsOnHeadland( headland, circleStart, currentBlockEntryPoint.index, { circleStep } )
					else
						-- if ther's no headland, look for the closest point no matter what direction (as we can ignore the clockwise/ccw settings)
						distance, dir = getDistanceBetweenPointsOnHeadland( headland, circleStart, currentBlockEntryPoint.index, { -1, 1 } )
					end
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
		chromosome.fitness = ( 10000 / chromosome.distance )
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
		courseGenerator.debug( 'generation %d %s', generation, tostring( population.bestChromosome ))
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

-- TODO: make sure this work with the spiral and circular center patterns as well.
function linkBlocks( blocksInSequence, innermostHeadland, circleStart, firstBlockDirection, nRowsToSkip )
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
			local previousBlockExitCorner = getBlockExitCorner( previousBlock.entryCorner, #previousBlock, nRowsToSkip )
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

