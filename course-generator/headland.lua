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

--- Functions to generate the headland passes
--
-- how close the vehicle must be to the field to automatically 
-- calculate a track starting near the vehicle's location
-- This is in meters
local maxDistanceFromField = 30
-- recursion count
local n


-- calculate distance from previous headland at the current location.
-- this is used for courseGenerator.HEADLAND_MODE_NARROW_FIELD to have the
-- headlands on the short edge of the field all overlap completely, so on
-- the short edge every headland pass will use the exact same path
--  ,--------------------------------------------------------------,
--  |--------------------------------------------------------------|
--  |--------------------------------------------------------------|
--  |--------------------------------------------------------------|
--  |--------------------------------------------------------------|
--  '--------------------------------------------------------------'
local function getLocalDeltaOffset( polygon, point, mode, centerSettings, deltaOffset, currentPassNumber )
	-- never touch the outermost headland pass
	if currentPassNumber == 1 then return deltaOffset end
	if mode == courseGenerator.HEADLAND_MODE_NARROW_FIELD then
		local longDirectionAngle
		if centerSettings.useLongestEdgeAngle or centerSettings.useBestAngle then
			-- if no angle given, use the longest edge
			-- TODO: implement best angle
			longDirectionAngle = math.rad( polygon.bestDirection.dir )
		elseif centerSettings.rowAngle then
			longDirectionAngle = centerSettings.rowAngle
		end
		-- is the current edge in the long or short direction?
		local da = getDeltaAngle( longDirectionAngle, point.nextEdge.angle )
		-- the closer this edge's angle is to the longest edge, the bigger is the offset
		--print( string.format( '%.1f, %.1f, %.1f', math.abs(math.deg(da)), math.deg( longDirectionAngle), math.deg( point.nextEdge.angle )))
		return deltaOffset * math.abs( math.cos( da ))
	else
		return deltaOffset
	end
end

-- smooth adds new points where we loose the passNumber attribute.
-- here we fix that. I know it's ugly and there must be a better way to
-- do this somehow smooth should preserve these, but whatever...
local function addMissingPassNumber( headlandPath )
	local currentPassNumber = 0
	for i, point in headlandPath:iterator() do
		if point.passNumber then
			if point.passNumber ~= currentPassNumber then
				currentPassNumber = point.passNumber
			end
		else
			point.passNumber = currentPassNumber
		end
	end
end

--- Calculate a headland track inside polygon in offset distance
function calculateHeadlandTrack( polygon, mode, rightSide, targetOffset, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle,
                                 currentOffset, doSmooth, inward, centerSettings, currentPassNumber )
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

	--courseGenerator.debug( "** Before target=%.2f, current=%.2f, delta=%.2f, target-current=%.2f", targetOffset, currentOffset, deltaOffset, targetOffset - currentOffset )
	if currentOffset >= targetOffset then return polygon end

	deltaOffset = math.min( deltaOffset, targetOffset - currentOffset )
	currentOffset = currentOffset + deltaOffset

	if not inward then
		deltaOffset = -deltaOffset
	end
	--courseGenerator.debug( "** After target=%.2f, current=%.2f, delta=%.2f", targetOffset, currentOffset, deltaOffset)
	local offsetEdges = {}
	for i, edge, from in polygon:edgeIterator() do
		local localOffset = getLocalDeltaOffset( polygon, from, mode, centerSettings, deltaOffset, currentPassNumber )
		local newFrom = addPolarVectorToPoint( edge.from, edge.angle + getInwardDirection( rightSide ), localOffset )
		local newTo = addPolarVectorToPoint( edge.to, edge.angle + getInwardDirection( rightSide ), localOffset )
		table.insert( offsetEdges, { from=newFrom, to=newTo })
	end


	local vertices = polygon:cloneEmpty()
	cleanupOffsetEdges(offsetEdges, vertices, minDistanceBetweenPoints)

	if doSmooth then
		vertices:smooth( minSmoothAngle, maxSmoothAngle, 1 )
	end
	-- only filter points too close, don't care about angle
	applyLowPassFilter( vertices, math.pi, minDistanceBetweenPoints )
	return calculateHeadlandTrack( vertices, mode, rightSide, targetOffset, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle,
		currentOffset, doSmooth, inward, centerSettings, currentPassNumber )
end

function cleanupOffsetEdges(offsetEdges, result, minDistanceBetweenPoints)
	for i = 1, #offsetEdges do
		local edge = offsetEdges[i]
		local ix = i - 1
		if ix == 0 then ix = #offsetEdges end

		local prevEdge, vertex

		if result:canWrapAround() then
			-- closed polygon, wrap around the end and use the last edge
			prevEdge = offsetEdges[ix]
			vertex = getIntersection( edge.from.x, edge.from.y, edge.to.x, edge.to.y,
				prevEdge.from.x, prevEdge.from.y, prevEdge.to.x, prevEdge.to.y )
		else
			-- just a line, no wrap around
			prevEdge = edge
			vertex = edge.from
		end

		if vertex then
			-- previous edge intersects current, use the intersection point then
			table.insert( result, vertex )
		else
			-- previous edge does not intersect current
			if getDistanceBetweenPoints( prevEdge.to, edge.from ) < minDistanceBetweenPoints then
				-- but their ends are close enough, so add a point between the two.
				local x, y = getPointInTheMiddle( prevEdge.to, edge.from )
				table.insert( result, { x=x, y=y })
			else
				-- previous ends far away from the current start, add both
				table.insert( result, prevEdge.to )
				table.insert( result, edge.from )
			end
		end
	end
	if not result.canWrapAround() then
		-- if we did not wrap around, we missed the end of the last edge
		table.insert(result, offsetEdges[#offsetEdges].to)
	end
	result:calculateData()
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
	local headlandPath = Polyline:new()
	-- find closest point to starting position on outermost headland track
	local fromIndex =  field.headlandTracks[ 1 ]:getClosestPointIndex(startLocation)
	local toIndex = field.headlandTracks[ 1 ]:getIndex( fromIndex + 1 )
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
					fromIndex, toIndex = field.headlandTracks[ i + 1 ]:getIntersectionWithLine( startLocation, addPolarVectorToPoint( startLocation, h, distance ))
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
		headlandPath:smooth( minSmoothAngle, maxSmoothAngle, 2 )
		field.headlandPath = headlandPath
		addMissingPassNumber( field.headlandPath )
	else
		field.headlandPath = headlandPath
	end
end

--- add a series of points (track) to the headland path. This is to 
-- assemble the complete spiral headland path from the individual 
-- parallel headland tracks.
function addTrackToHeadlandPath( headlandPath, track, passNumber, from, to, step)
	for i, point in track:iterator( from, to, step ) do
		table.insert( headlandPath, track[ i ])
		headlandPath[ #headlandPath ].passNumber = passNumber
	end
end


-- in courseGenerator.HEADLAND_MODE_NARROW_FIELD mode we want to lift the
-- implements on the short edge (except for the outermost headland).
-- So we mark those waypoints as connecting tracks here. (would have been
-- too difficult to propagate this info from the grassfire algorithm so
-- we just do it again here.
local function markShortEdgesAsConnectingTrack( headlands, mode, centerSettings )
	for i, headland in ipairs( headlands ) do
		for j, point in headland:iterator() do
			local fakeWidth = 1
			local localDeltaOffset = getLocalDeltaOffset( headland, point, mode, centerSettings, fakeWidth, i )
			if localDeltaOffset < fakeWidth / 2 then
				-- offset reduced, this must be on the short edge
				point.isConnectingTrack = true
			end
		end
	end
end

function generateAllHeadlandTracks(field, implementWidth, headlandSettings, centerSettings,
	minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth, fromInside, turnRadius)

	local previousTrack, startHeadlandPass, endHeadlandPass, step
	if fromInside then
		courseGenerator.debug( "Generating innermost headland track" )
		local distanceOfInnermostHeadlandFromBoundary = ( implementWidth - implementWidth * headlandSettings.overlapPercent / 100 ) * ( headlandSettings.nPasses - 1 ) + implementWidth / 2
		field.headlandTracks[ headlandSettings.nPasses ] = calculateHeadlandTrack( field.boundary, headlandSettings.mode, field.boundary.isClockwise, distanceOfInnermostHeadlandFromBoundary,
			minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 0, doSmooth, true, centerSettings, nil )
		roundCorners( field.headlandTracks[ headlandSettings.nPasses ], turnRadius )
		previousTrack = field.headlandTracks[ headlandSettings.nPasses ]
		startHeadlandPass = headlandSettings.nPasses - 1
		endHeadlandPass = 1
		step = -1
	else
		startHeadlandPass = 1
		previousTrack = field.boundary
		step = 1
		if headlandSettings.mode == courseGenerator.HEADLAND_MODE_NARROW_FIELD then
			-- in this mode we add headlands until they cover the entire field
			-- (but use a finite number, not math.huge just to be on the safe side
			endHeadlandPass = 100
		else
			endHeadlandPass = headlandSettings.nPasses
		end
	end
	for j = startHeadlandPass, endHeadlandPass, step do
		local width
		if j == 1 and not fromInside then
			-- when working from inside, the half width is already factored in when
			-- the innermost pass is generated
			width = implementWidth / 2
		else
			width = implementWidth * ( 100 - headlandSettings.overlapPercent ) / 100
		end

		field.headlandTracks[ j ] = calculateHeadlandTrack( previousTrack, headlandSettings.mode, previousTrack.isClockwise, width,
			minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 0, doSmooth, not fromInside,
			centerSettings, j )
		courseGenerator.debug( "Generated headland track #%d, area %1.f, clockwise = %s", j, field.headlandTracks[ j ].area, tostring( field.headlandTracks[ j ].isClockwise ))
		-- check if the area within the last headland has a reasonable size
		local minArea = 0.75 * width * field.headlandTracks[ j ].circumference / 2

		if ( field.headlandTracks[ j ].area >= previousTrack.area or field.headlandTracks[ j ].area <= minArea ) and not fromInside then
			courseGenerator.debug( "Can't fit more headlands in field, using %d", j - 1 )
			field.headlandTracks[ j ] = nil
			break
		end
		previousTrack = field.headlandTracks[ j ]
	end
	markShortEdgesAsConnectingTrack( field.headlandTracks, headlandSettings.mode, centerSettings )
end


--- calculate n headland tracks for any section (between startIx and endIx) of a field boundary
-- if rightSide is true, the headland is on the right side of the previous headland.
function calculateOneSide(boundary, innerBoundary, startIx, endIx, step, rightSide, headlandSettings, implementWidth,
													minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle)
	---@type Polyline[]
	local headlands = {}
	-- construct the boundary
	headlands[0] = Polyline:new()
	for i, p in boundary:iterator(startIx, endIx, step) do
		table.insert(headlands[0], copyPoint(p))
	end
	headlands[0]:calculateData()

	for i = 1, headlandSettings.nPasses do
		local width = i == 1 and implementWidth / 2 or implementWidth
		headlands[i] = calculateHeadlandTrack(headlands[i - 1], headlandSettings.mode, rightSide, width,
			minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 0, false, true,
			centerSettings, i)
		extendLineToOtherLine(headlands[i], boundary, implementWidth * 2)
		headlands[i]:space(math.pi, minDistanceBetweenPoints)
		local side = rightSide and 'right' or 'left'
		courseGenerator.debug( "Generated %s side headland track #%d at %.1f m with %d points", side, i, width, #headlands[i])
	end
	-- we don't need this anymore, was just used as the boundary
	headlands[0] = nil
	return headlands
end

function generateTwoSideHeadlands( polygon, islands, implementWidth, extendTracks, headlandSettings, centerSettings,
																	 minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle )
	-- translate polygon so we can rotate it around its center. This way all points
	-- will be approximately the same distance from the origin and the rotation calculation
	-- will be more accurate
	local dx, dy = polygon:getCenter()
	local boundary = Polygon:copy(polygon)
	boundary:translate(-dx , -dy)
	local translatedIslands = Island.translateAll( islands, -dx, -dy )

	local bestAngle, nTracks, nBlocks, resultIsOk
	-- Now, determine the angle where the number of tracks is the minimum
	bestAngle, nTracks, nBlocks, resultIsOk = findBestTrackAngle( boundary, translatedIslands, implementWidth, 0, centerSettings )
	if nBlocks < 1 then
		courseGenerator.debug( "No room for up/down rows." )
		return nil, 0, 0, nil, true
	end
	if not bestAngle then
		bestAngle = polygon.bestDirection.dir
		courseGenerator.debug( "No best angle found, use the longest edge direction " .. bestAngle )
	end

	-- now, generate the tracks according to the implement width within the rotated polygon's bounding box
	-- using the best angle
	boundary:rotate(math.rad(bestAngle))
	local rotatedIslands = Island.rotateAll( translatedIslands, math.rad( bestAngle ))
	-- use a distanceFromBoundary > 0 to avoid problems with rectangular fields with not
	-- perfectly straight sides
	local parallelTracks = generateParallelTracks( boundary, rotatedIslands, implementWidth, implementWidth / 2 )

	local startTrack, endTrack = 1, #parallelTracks

	-- find the first and last track with at least 2 intersections
	-- this is usually the first and last track except on odd shaped fields.
	for i = 1, #parallelTracks, 1 do
		if #parallelTracks[i].intersections > 1 then
			startTrack = i
			break
		end
	end

	for i = #parallelTracks, 1, -1 do
		if #parallelTracks[i].intersections > 1 then
			endTrack = i
			break
		end
	end

	-- We have now the up/down rows in parallelTracks, each with a list of intersections with
	-- headlands. The first and last intersection in the list is hopefully the intersection with the boundary
	-- on the left and the right. The tracks are now also parallel to the x axis, track #1 on the bottom.
	-- Find the section of the boundary we'll use our headland, first on the left:
	local bottomLeftIx = parallelTracks[startTrack].intersections[1].headlandVertexIx
	local topLeftIx = parallelTracks[endTrack].intersections[1].headlandVertexIx
	local bottomRightIx = parallelTracks[startTrack].intersections[#parallelTracks[startTrack].intersections].headlandVertexIx
	local topRightIx = parallelTracks[endTrack].intersections[#parallelTracks[endTrack].intersections].headlandVertexIx

	-- we need this for the part which connects the left and right side headlands.
	local headlandAround = calculateHeadlandTrack(boundary, headlandSettings.mode, boundary.isClockwise, implementWidth / 2,
		minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 0, true, true,
		centerSettings, 1)

	local step = boundary.isClockwise and 1 or -1
	local leftHeadlands = calculateOneSide(boundary, headlandAround, bottomLeftIx, topLeftIx, step, true, headlandSettings, implementWidth,
		minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle)

	step = boundary.isClockwise and -1 or 1
	local rightHeadlands = calculateOneSide(boundary, headlandAround, bottomRightIx, topRightIx, step, false, headlandSettings, implementWidth,
		minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle)

	-- figure out where to start the course. It will be the headland end closest to the
	-- start location
	local startLocation = PointXY:copy(headlandSettings.startLocation)
	startLocation:translate(-dx, -dy)
	startLocation:rotate(math.rad(bestAngle))

	local ixLeft, dLeft = leftHeadlands[1]:getClosestPointIndex(startLocation)
	local ixRight, dRight = rightHeadlands[1]:getClosestPointIndex(startLocation)

	-- start with the left side or right side?
	local startLeft = dLeft <= dRight
	local firstHeadlands = startLeft and leftHeadlands or rightHeadlands
	local lastHeadlands = startLeft and rightHeadlands or leftHeadlands

	-- this entire logic assumes that we turned our field so that the headlands are on the left and right side of it
	-- figure out if we start the headland on the top or the bottom
	local startTop = startLeft and ixLeft > 1 or ixRight > 1

	-- trim the headlands both ends so they don't reach all the way to the field edge
	for i = 1, #firstHeadlands do
			if i == 1 then
				-- except the very first headland, that must not be shortened at the course start.
				if startTop then
					firstHeadlands[i]:shortenStart(implementWidth / 2)
				else
					firstHeadlands[i]:shortenEnd(implementWidth / 2)
				end
			else
				firstHeadlands[i]:shortenStart(implementWidth / 2)
				firstHeadlands[i]:shortenEnd(implementWidth / 2)
			end
			firstHeadlands[i]:space(math.pi, minDistanceBetweenPoints)
	end
	for i = 1, #lastHeadlands do
		lastHeadlands[i]:shortenStart(implementWidth / 2)
		lastHeadlands[i]:shortenEnd(implementWidth / 2)
		lastHeadlands[i]:space(math.pi, minDistanceBetweenPoints)
	end

	-- the boundary of the up down row area, nPasses headlands on two sides, one headland on one side
	-- and the field boundary on the other.
	local innerBoundary = Polygon:new()

	-- now that we know which side to start, put the headland course together
	local currentLocation = startLocation
	local result = Polyline:new()
	for i = 1, #firstHeadlands do
		for j, p in firstHeadlands[i]:iteratorFromEndClosestToPoint(currentLocation) do
			if #result > 0 and result[#result].turnStart then
				p.turnEnd = true
			end
			table.insert(result, p)
			if i == #firstHeadlands then
				table.insert(innerBoundary, copyPoint(p))
			end
		end
		result[#result].turnStart = true
		-- make sure the turn system will handle this 180 turn as if there were no headland to make the turn
		result[#result].headlandHeightForTurn = 0
		currentLocation = result[#result]
	end

	-- ok, find the section of headland connecting the start and the end side
	local closestIx, _, _ = lastHeadlands[1]:getIteratorParamsFromEndClosestToPoint(result[#result])
	local sectionBetweenLeftAndRight = headlandAround:getSectionBetweenPoints(result[#result], lastHeadlands[1][closestIx])
	local innerSectionBetweenLeftAndRight = headlandAround:getSectionBetweenPoints(result[#result], lastHeadlands[#lastHeadlands][closestIx])
	result:appendLine(sectionBetweenLeftAndRight, implementWidth * 2)
	result:appendLine(lastHeadlands[1], implementWidth * 2)

	result[#result].turnStart = true
	result[#result].headlandHeightForTurn = 0

	-- now add the end headlands
	currentLocation = result[#result]
	for i = 2, #lastHeadlands do
		for j, p in lastHeadlands[i]:iteratorFromEndClosestToPoint(currentLocation) do
			if #result > 0 and result[#result].turnStart then
				p.turnEnd = true
			end
			table.insert(result, p)
		end
		result[#result].turnStart = true
		result[#result].headlandHeightForTurn = 0
		currentLocation = result[#result]
	end

	if headlandSettings.nPasses % 2 == 0 then
		result:calculateData()
		result:shortenEnd(implementWidth / 2)
	end

	innerBoundary:appendLine(innerSectionBetweenLeftAndRight, implementWidth * 2)
	innerBoundary:appendLine(lastHeadlands[#lastHeadlands], implementWidth * 2)

	-- the last point in result is now where the up/down rows should start
	innerBoundary.circleStart = innerBoundary:getClosestPointIndex(result[#result])

	local otherSectionBetweenLeftAndRight = boundary:getSectionBetweenPoints(innerBoundary[#innerBoundary], innerBoundary[1])
	innerBoundary:appendLine(otherSectionBetweenLeftAndRight, implementWidth * 2)
	innerBoundary:calculateData()
	--result:trimEnd(innerBoundary, true)

	innerBoundary:rotate(-math.rad(bestAngle))
	innerBoundary:translate(dx, dy)

	result:calculateData()
	result:space(math.pi / 3, minDistanceBetweenPoints)

	result:rotate(-math.rad(bestAngle))
	result:translate(dx, dy)
	return result, innerBoundary
end

--- Extend (or trim) line both ends until it intersects with otherLine
---@param line Polyline
---@param otherLine Polyline
---@param extension number
function extendLineToOtherLine(line, otherLine, extension)
	-- extend upotherLine
	local up = addPolarVectorToPoint(line[1], line[1].nextEdge.angle, -extension * 2)
	local _, _, is = otherLine:getIntersectionWithLine(line[1], up)
	if is then table.insert(line, 1, is) end
	local down = addPolarVectorToPoint(line[#line], line[#line].prevEdge.angle, extension * 2)
	_, _, is = otherLine:getIntersectionWithLine(line[#line], down)
	if is then table.insert(line, is) end
	line:calculateData()
end
