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
local n

--- Calculate a headland track inside polygon in offset distance
function calculateHeadlandTrack( polygon, mode, targetOffset, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle,
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

	-- courseGenerator.debug( "** Before target=%.2f, current=%.2f, delta=%.2f, target-current=%.2f", targetOffset, currentOffset, deltaOffset, targetOffset - currentOffset )
	if currentOffset >= targetOffset then return polygon end

	deltaOffset = math.min( deltaOffset, targetOffset - currentOffset )
	currentOffset = currentOffset + deltaOffset

	if not inward then
		deltaOffset = -deltaOffset
	end
	-- courseGenerator.debug( "** After target=%.2f, current=%.2f, delta=%.2f", targetOffset, currentOffset, deltaOffset)
	local offsetEdges = {}
	for i, point in polygon:iterator() do
		local localOffset = getLocalDeltaOffset( polygon, point, mode, centerSettings, deltaOffset, currentPassNumber )
		local newFrom = addPolarVectorToPoint( point.nextEdge.from, point.nextEdge.angle + getInwardDirection( polygon.isClockwise ), localOffset )
		local newTo = addPolarVectorToPoint( point.nextEdge.to, point.nextEdge.angle + getInwardDirection( polygon.isClockwise ), localOffset )
		table.insert( offsetEdges, { from=newFrom, to=newTo })
	end

	local vertices = Polygon:new()
	for i, edge in ipairs( offsetEdges ) do
		local ix = i - 1
		if ix == 0 then ix = #offsetEdges end
		local prevEdge = offsetEdges[ix ]
		local vertex = getIntersection( edge.from.x, edge.from.y, edge.to.x, edge.to.y,
			prevEdge.from.x, prevEdge.from.y, prevEdge.to.x, prevEdge.to.y )
		if vertex then
			-- previous edge intersects current, use the intersection point then
			table.insert( vertices, vertex )
		else
			-- previous edge does not intersect current
			if getDistanceBetweenPoints( prevEdge.to, edge.from ) < minDistanceBetweenPoints then
				-- but their ends are close enough, so add a point between the two.
				local x, y = getPointInTheMiddle( prevEdge.to, edge.from )
				table.insert( vertices, { x=x, y=y })
			else
				-- previous ends far away from the current start, add both
				table.insert( vertices, prevEdge.to )
				table.insert( vertices, edge.from )
			end
		end
	end
	vertices:calculateData()
	if doSmooth then
		vertices:smooth( minSmoothAngle, maxSmoothAngle, 1 )
	end
	-- only filter points too close, don't care about angle
	applyLowPassFilter( vertices, math.pi, minDistanceBetweenPoints )
	return calculateHeadlandTrack( vertices, mode, targetOffset, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle,
		currentOffset, doSmooth, inward, centerSettings, currentPassNumber )
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
	local fromIndex = getClosestPointIndex( field.headlandTracks[ 1 ], startLocation )
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

-- smooth adds new points where we loose the passNumber attribute.
-- here we fix that. I know it's ugly and there must be a better way to 
-- do this somehow smooth should preserve these, but whatever...
function addMissingPassNumber( headlandPath )
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
function getLocalDeltaOffset( polygon, point, mode, centerSettings, deltaOffset, currentPassNumber )
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

-- in courseGenerator.HEADLAND_MODE_NARROW_FIELD mode we want to lift the
-- implements on the short edge (except for the outermost headland).
-- So we mark those waypoints as connecting tracks here. (would have been
-- too difficult to propagate this info from the grassfire algorithm so
-- we just do it again here.
function markShortEdgesAsConnectingTrack( headlands, mode, centerSettings )
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