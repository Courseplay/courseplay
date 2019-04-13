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
-- extendTracks
--   extend center tracks into the headland (meters) to prevent unworked
--   triangles with long plows.
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
-- returnToFirstPoint
--   Return to the first waypoint of the course after done. Will add a section from the 
--   last to the first wp if true.
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

function generateCourseForField( field, implementWidth, headlandSettings, extendTracks,
                                 minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth, fromInside,
                                 turnRadius, returnToFirstPoint, islandNodes, islandBypassMode, centerSettings )

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
	courseGenerator.debug("Headland mode %s, number of passes %d", courseGenerator.headlandModeTexts[headlandSettings.mode],
		headlandSettings.nPasses)

	if headlandSettings.nPasses > 0 and
		(headlandSettings.mode == courseGenerator.HEADLAND_MODE_NORMAL or
		 headlandSettings.mode == courseGenerator.HEADLAND_MODE_NARROW_FIELD) then
		generateAllHeadlandTracks(field, implementWidth, headlandSettings, centerSettings,
			minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth, fromInside, turnRadius)

		linkHeadlandTracks( field, implementWidth, headlandSettings.isClockwise, headlandSettings.startLocation, doSmooth, minSmoothAngle, maxSmoothAngle )

		field.track, field.bestAngle, field.nTracks, field.blocks, resultIsOk = generateTracks( field.headlandTracks, field.bigIslands,
			implementWidth, extendTracks, headlandSettings.nPasses, centerSettings )
	elseif headlandSettings.nPasses == 0 or -- TODO: use the mode only, not nPasses, this is only for backwards compatibility
		headlandSettings.mode == courseGenerator.HEADLAND_MODE_NONE then
		-- no headland pass wanted, still generate a dummy one on the field boundary so
		-- we have something to work with when generating the up/down tracks
		field.headlandTracks[ 1 ] = calculateHeadlandTrack( field.boundary, courseGenerator.HEADLAND_MODE_NORMAL, field.boundary.isClockwise, 0, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 0, doSmooth, not fromInside, nil, nil )
		linkHeadlandTracks( field, implementWidth, headlandSettings.isClockwise, headlandSettings.startLocation, doSmooth, minSmoothAngle, maxSmoothAngle )
		field.track, field.bestAngle, field.nTracks, field.blocks, resultIsOk = generateTracks( field.headlandTracks, field.bigIslands,
			implementWidth, extendTracks, headlandSettings.nPasses, centerSettings )
	elseif headlandSettings.mode == courseGenerator.HEADLAND_MODE_TWO_SIDE then
		-- force headland corners
		headlandSettings.minHeadlandTurnAngleDeg = 60
		-- start with rows over the field with no headland.
		local boundary
		field.headlandPath, boundary = generateTwoSideHeadlands( field.boundary, field.bigIslands,
			implementWidth, extendTracks, headlandSettings, centerSettings, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle)
		field.track, field.bestAngle, field.nTracks, field.blocks, resultIsOk = generateTracks({ boundary }, field.bigIslands,
			implementWidth, extendTracks - implementWidth / 2, 0, centerSettings )
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
		if returnToFirstPoint then
			courseGenerator.debug("Adding waypoints to return to first point.")
			addWpsToReturnToFirstPoint( field.course, field.boundary )
		end
		field.course:calculateData()
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
		local newPoint = copyPoint( course[ i ])
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

function addWpsToReturnToFirstPoint( course, boundary )
	-- should not check for fruit
	local path = courseGenerator.pathFinder:findPath( course[ #course ], course[ 1 ], boundary )
	-- already close enough, don't add extra return path
	if not path or #path < 5 then
		return
	else
		-- start at the third wp in order to be far enough 
		-- from the last course wp to avoid circling
		for i = 3, #path do
			path[ i ].returnToFirst = true -- just for debugging
			path[ i ].isConnectingTrack = true -- so it'll raise implements when driving back
			table.insert( course, path[ i ])
		end
	end
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

