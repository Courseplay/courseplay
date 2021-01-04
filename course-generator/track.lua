--- Generate course for a field.
-- The result will be:
--
-- field.headlandPath 
--   array of points containing all headland passes linked together
--
-- field.headlandTracks
--   array of circular headland tracks (not connected). #field.headlandTracks
--   is the number of actually generated tracks, can be less than the requested
--   because it'll stop adding them once the field is fully covered with headland
--   tracks (spiral)
--   
-- field.connectingTracks
--   this is the path from the end of the innermost headland track to the start
--   of the parallel tracks in the middle of the field and the connecting tracks
--   between the blocks in the center if the field is non-convex and has been split
--   into blocks
--
-- field.track
--   parallel tracks in the middle of the field.
--
-- field.course
--   all waypoints of the resulting course 
--
-- Input paramters:
--
-- implementWidth 
--   width of the implement
-- 
-- headlandSettings.mode
--   see courseGenerator.HEADLAND_MODE_*
--
-- headlandSettings.nPasses
--   number of headland passes to generate
--
-- headlandSettings.isClockwise
--   headland track is clockwise when going inward if true, counterclockwise otherwise
--
-- headlandSettings.startLocation
--   location anywhere near the field boundary where the headland should start.
--
-- headlandSettings.overlapPercent 
--   headland pass overlap in percent, may reduce skipped fruit in corners
--
-- headlandSettings.headlandFirst
--   Start the course with the headland. If false, will start with the up/down rows
--   in the middle of the field and finish with the headland
--
-- headlandSettings.minHeadlandTurnAngle
--   Will generate turns (start/end waypoints) if the direction change over
--   headlandSettings.minHeadlandTurnAngle to use the turn system.
--
-- centerSettings.nRowsToSkip
--   center tracks to skip. When 0, normal alternating tracks are generated
--   when > 0, intermediate tracks are skipped to allow for wider turns
--
-- minDistanceBetweenPoints
--   minimum distance allowed between vertices. Keeps the number of generated
--   vertices for headland passes low. For fine tuning only
--
-- minSmoothAngle
--   angle between two subsequent edges above which the smoothing kicks in.
--   This is to smooth corners in the headland
--
-- maxSmoothAngle
--   angle between two subsequent edges above which the smoothing won't kick in
--
-- doSmooth
--   enable smoothing 
--
-- fromInside
--   calculate the headland tracks starting with the innermost one. This will first
--   generate the innermost headland track and then work outwards. If done this way,
--   there'll be no sharp corners in the headland tracks but the field corners will
--   be rounded.
--
-- turnRadius
--   turn radius of the vehicle. Will do whatever we can not to generate turns sharper
--   than this
--
-- islandNodes
--   List of points within the field which should be bypassed like utility poles or 
--   trees. 
--
-- islandBypassMode
--   See Island.lua, SIMPLE: just move existing waypoints out of the island, CIRCLE: 
--   generate headland track around island and use that for bypassing. Drive a full
--   circle around the island when first bypassing.
--   
-- centerSettings.useBestAngle
--   If true, the generator will find the optimal angle for the center rows
--
-- centerSettings.useLongestEdgeAngle
--   If true, the generator will generate the center tracks parallel to the field's 
--   longest edge. 
--
-- centerSettings.rowAngle
--   If this is supplied, the generator will generate the up/down rows at this angle,
--   instead of trying to find the optimal angle.
-- 

function generateCourseForField( field, implementWidth, headlandSettings,
																 minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth, fromInside,
																 turnRadius, islandNodes, islandBypassMode, centerSettings )

	local resultIsOk = true

	field.boundingBox =  field.boundary:getBoundingBox()
	field.boundary = Polygon:new( field.boundary )
	field.boundary:calculateData()

	field.smallIslands = {}
	field.bigIslands = {}
	field.islands = {}
	if islandBypassMode ~= Island.BYPASS_MODE_NONE then
		setupIslands( field, headlandSettings.nPasses, implementWidth, headlandSettings.overlapPercent, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth, islandNodes )
	end

	field.headlandTracks = {}

	courseGenerator.debug("####### COURSE GENERATOR START ##########################################################")
	courseGenerator.debug("Headland mode %s, number of passes %d, center mode %s, min headland turn angle %.1f",
			courseGenerator.headlandModeTexts[headlandSettings.mode], headlandSettings.nPasses,
			courseGenerator.centerModeTexts[centerSettings.mode], headlandSettings.minHeadlandTurnAngleDeg)

	if headlandSettings.nPasses > 0 and
		(headlandSettings.mode == courseGenerator.HEADLAND_MODE_NORMAL or
			headlandSettings.mode == courseGenerator.HEADLAND_MODE_NARROW_FIELD) then
		generateAllHeadlandTracks(field, implementWidth, headlandSettings, centerSettings,
			minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth, fromInside, turnRadius)

		linkHeadlandTracks( field, implementWidth, headlandSettings.isClockwise, headlandSettings.startLocation, doSmooth, minSmoothAngle, maxSmoothAngle )

		field.track, field.bestAngle, field.nTracks, field.blocks, resultIsOk = generateTracks( field.headlandTracks, field.bigIslands,
			implementWidth, headlandSettings.nPasses, centerSettings )
	elseif headlandSettings.nPasses == 0 or -- TODO: use the mode only, not nPasses, this is only for backwards compatibility
		headlandSettings.mode == courseGenerator.HEADLAND_MODE_NONE then
		-- no headland pass wanted, still generate a dummy one on the field boundary so
		-- we have something to work with when generating the up/down tracks
		field.headlandTracks[ 1 ] = calculateHeadlandTrack( field.boundary, courseGenerator.HEADLAND_MODE_NORMAL, field.boundary.isClockwise, 0, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 0, doSmooth, not fromInside, nil, nil )
		linkHeadlandTracks( field, implementWidth, headlandSettings.isClockwise, headlandSettings.startLocation, doSmooth, minSmoothAngle, maxSmoothAngle )
		field.track, field.bestAngle, field.nTracks, field.blocks, resultIsOk = generateTracks( field.headlandTracks, field.bigIslands,
			implementWidth, headlandSettings.nPasses, centerSettings )
	elseif headlandSettings.mode == courseGenerator.HEADLAND_MODE_TWO_SIDE then
		-- force headland corners
		headlandSettings.minHeadlandTurnAngleDeg = 60
		-- start with rows over the field with no headland.
		local boundary
		field.headlandPath, boundary = generateTwoSideHeadlands( field.boundary, field.bigIslands,
			implementWidth, headlandSettings, centerSettings, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle)
		field.track, field.bestAngle, field.nTracks, field.blocks, resultIsOk = generateTracks({ boundary }, field.bigIslands,
			implementWidth, 0, centerSettings )
	end
	courseGenerator.debug("####### COURSE GENERATOR END ###########################################################")

	-- assemble complete course now
	field.course = Polygon:new()
	if field.headlandPath and headlandSettings.nPasses > 0 then
		for _, point in field.headlandPath:iterator() do
			table.insert( field.course, point )
		end
	end
	if field.track then
		for _, point in field.track:iterator() do
			table.insert( field.course, point )
		end
	end
	if #field.course > 0 then
		addHeadlandToCenterTransition(field.course, headlandSettings, centerSettings, turnRadius, field.bigIslands, field.headlandTracks, implementWidth)
		if not headlandSettings.headlandFirst then
			field.course = reverseCourse( field.course )
		end
		if islandBypassMode ~= Island.BYPASS_MODE_NONE then
			Island.circleBigIslands( field.course, field.bigIslands, headlandSettings.headlandFirst, implementWidth, minSmoothAngle, maxSmoothAngle )
			field.course:calculateData()
		end
		addTurnsToCorners( field.course, math.rad( headlandSettings.minHeadlandTurnAngleDeg ),
			centerSettings.mode ~= courseGenerator.CENTER_MODE_UP_DOWN)
	end
	-- flush STDOUT when not in the game for debugging
	if not courseGenerator.isRunningInGame() then
		io.stdout:flush()
	end
	-- make sure we do not return the dummy headland track generated when no headland requested
	if headlandSettings.nPasses == 0 then
		field.headlandTracks = {}
	end
	if #islandNodes > 0 then
		if islandBypassMode == Island.BYPASS_MODE_SIMPLE then
			Island.bypassIslandNodes(field.course, implementWidth, islandNodes)
		elseif islandBypassMode == Island.BYPASS_MODE_CIRCLE then
			for _, island in ipairs( field.smallIslands ) do
				island:bypass( field.course, true, doSmooth )
			end
		end
		field.course:calculateData()
	end
	courseGenerator.debug("Course with %d waypoints generated.", #field.course)
	return resultIsOk
end

--- Reverse a course. This is to build a sowing/cultivating etc. course
-- from a harvester course.
-- We build our courses working from the outside inwards (harverster).
-- This function reverses that course so it can be used for fieldwork
-- starting in the middle of the course.
--
function reverseCourse( course )
	local result = Polygon:new()
	-- remove any non-center track turns first
	--removeHeadlandTurns( course )
	for i = #course, 1, -1 do
		local newPoint = shallowCopy( course[ i ])
		-- reverse center track turns
		if newPoint.turnStart then
			newPoint.turnStart = nil
			newPoint.turnEnd = true
		elseif newPoint.turnEnd then
			newPoint.turnEnd = nil
			newPoint.turnStart = true
		elseif newPoint.mustReach then
			newPoint.mustReach = nil
			newPoint.align = true
		elseif newPoint.align then
			newPoint.align = nil
			newPoint.mustReach = true
		end
		table.insert( result, newPoint )
	end
	-- regenerate non-center track turns for the reversed course
	result:calculateData()
	--addTurnsToCorners( result, width, turnRadius, headlandSettings.minHeadlandTurnAngle )
	return result
end

-- Remove all turns inserted by addTurnsToCorners 
function removeHeadlandTurns( course )
	for i, p in ipairs( course ) do
		if p.headlandTurn then
			p.turnStart = nil
			p.turnEnd = nil
			p.headlandCorner = nil
			p.text = nil
		end
	end
end

function addTurnsToCorners( vertices, minHeadlandTurnAngle, headlandOnly)
	-- start at the second wp to avoid having the first waypoint a turn start,
	-- that throws an nil in getPointDirection (due to the way calculatePolygonData
	-- works, the prevEdge to the first point is bogus anyway)
	local i = 2
	while i < #vertices - 1 do
		local cp = vertices[ i ]
		local np = vertices[ i + 1 ]
		local nnp = vertices[ i + 2 ]
		if not headlandOnly or (headlandOnly and not cp.trackNumber and not np.trackNumber) then
			-- cp.trackNumber is set for the up/down rows where we don't want to add turn start/ends when headlandOnly is true
			if cp.prevEdge and np.nextEdge then
				-- start a turn at the current point only if the next one is not a start of the turn already
				-- or not an island bypass point or a reversing waypoint
				-- and there really is a turn
				if not np.turnStart and not cp.turnStart and not cp.turnEnd and
					not cp.islandBypass and not np.islandBypass and
					not cp.rev and not np.rev and not nnp.rev and
					math.abs( getDeltaAngle( np.nextEdge.angle, np.prevEdge.angle )) > minHeadlandTurnAngle then
					cp.turnStart = true
					cp.headlandTurn = true
					np.turnEnd = true
					np.headlandTurn = true
					i = i + 2
				end
			end
		end
		i = i + 1
	end
end

--- Add the transition from headland to the center (up/down rows)
---
--- The innermost headland always has an extra round added (one complete round working and one more marked as connecting
--- track), see linkHeadlandTracks(). We certainly have to drive the first round to complete the work, how much of the
--- second round is needed depends on where the up/down rows start. This will be somewhere in the first half of the
--- extra round.
---
--- Here, we traverse that extra round backwards from the headland waypoint closest to the first up/down waypoint
--- and then cut that section from the course.
---
---@param course Polyline course waypoints, in the order of driving
---@param i number index of a waypoint which is a start of an up/down row block
function addHeadlandToCenterTransition(course, headlandSettings, centerSettings, turnRadius, islands, headlands, width)
	-- get p2's coordinates in p1's space
	local function worldToLocal(p1, p2)
		local x = (p2.x - p1.x) * math.cos(p1.nextEdge.angle) + (p2.y - p1.y) * math.sin(p1.nextEdge.angle)
		local y = -(p2.x - p1.x) * math.sin(p1.nextEdge.angle) + (p2.y - p1.y) * math.cos(p1.nextEdge.angle)
		return x, y
	end
	-- is p2 on the good side of p1, where p1 is the first up/down waypoint, p2 is the last headland waypoint.
	-- we want to make sure the turn from p1 to p2 is less than 90 degrees.
	local function isOnGoodSide(p1, p2)
		local _, y = worldToLocal(p1, p2)
		if headlandSettings.isClockwise then
			-- p2 on the right side in p1's space
			return y < 0
		else
			-- p2 on the left side in p1's space
			return y >= 0
		end
	end
	course:calculateData()
	local i = 2
	while i < #course do
		if course[i].upDownRowStart then
			-- this is where the up/down rows start (and the extra headland round ends)
			course[i].upDownRowStart = nil
			local cutFromHere, cutToHere = 0, i - 1
			-- walk back from the up/down row on the headland and find the headland waypoint closest to the
			-- first up/down waypoint (also, it has to be on the right side of the up/down row start waypoint
			local dMin = math.huge
			for j, point in course:iterator(i - 1, 1, -1) do
				local d = getDistanceBetweenPoints(course[i], point)
				if d < dMin and isOnGoodSide(course[i], point) then
					-- this is closer, remember it
					-- we add a little just to make sure that if we encounter the same distance again (because we
					-- did a full circle on the extra waypoints), that will overwrite cutFromHere, making sure the
					-- we cut as close as possible to the end of the real (non-extra) headland and there'll be no
					-- unecessary connecting track.
					-- TODO: this still results in almost a full circle when the starting point is very close to the
					-- start of the up/down rows in the lands pattern.
					dMin = d + 0.01
					cutFromHere = j + 1
				end
				-- we reached the end of the headland (went through all extra waypoints)
				if point.endOfHeadland then
					break
				end
			end
			-- remove the extra waypoints
			if cutFromHere > 0 then
				courseGenerator.debug('Removing waypoints %d - %d to fix headland-up/down transition', cutFromHere, cutToHere)
				for _ = cutFromHere, cutToHere do
					table.remove(course, cutFromHere)
				end
			end
			course:calculateData()
			local deltaAngle = getDeltaAngle(course[cutFromHere].nextEdge.angle, course[cutFromHere - 1].prevEdge.angle)
			if math.abs(deltaAngle) > math.rad(headlandSettings.minHeadlandTurnAngleDeg) then
				-- Do not add a turn here for now, we rely on the FieldworkAIDriver to create an alignment course
				-- for the headland->center transition.
				--courseGenerator.debug('Adding a turn starting at %d for the headland-up/down transition', cutFromHere - 1)
				--course[cutFromHere - 1].turnStart = true
				--course[cutFromHere].turnEnd = true
			end
			break
		end
		i = i + 1
	end
	course:calculateData()
end

-- set up all island related data for the field  
function setupIslands( field, nPasses, implementWidth, overlapPercent, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle,
                       doSmooth, islandNodes )
	field.islandPerimeterNodes = Island.getIslandPerimeterNodes( islandNodes )
	field.origIslandPerimeterNodes = deepCopy( field.islandPerimeterNodes )
	local islandId = 1
	while #field.islandPerimeterNodes > 0 do
		local island = Island:new( islandId )
		island:createFromPerimeterNodes( field.islandPerimeterNodes )
		-- ignore too really small islands (under 5 sqm), there are too many issues with the 
		-- headland generation for them
		if island.nodes.area > 5 then
			island:generateHeadlands( nPasses, implementWidth, overlapPercent, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth )
			if island:tooBigToBypass( implementWidth ) then
				table.insert( field.bigIslands, island )
			else
				table.insert( field.smallIslands, island )
			end
			table.insert( field.islands, island )
			islandId = islandId + 1
		end
	end
end

