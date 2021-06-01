--- This is the interface to Courseplay
-- all course generator related code dependent on CP/Giants functions go here

--- Convert the generated course to CP waypoint format
--
local function writeCourseToVehicleWaypoints(vehicle, course)
	vehicle.Waypoints = {};

	for i, point in ipairs(course) do
		local wp = {}

		wp.generated = true
		wp.ridgeMarker = point.ridgeMarker
		wp.angle = courseGenerator.toCpAngleDeg(point.nextEdge.angle)
		wp.cx = point.x
		wp.cz = -point.y
		wp.wait = nil
		if point.rev then
			wp.rev = point.rev
		else
			wp.rev = false
		end
		wp.crossing = nil
		wp.speed = 0

		if point.passNumber then
			wp.lane = -point.passNumber
		end
		if point.turnStart then
			wp.turnStart = true
		end
		if point.turnEnd then
			wp.turnEnd = true
		end
		if point.isConnectingTrack then
			wp.isConnectingTrack = true
		end
		if point.mustReach then
			wp.mustReach = true
		end
		if point.align then
			wp.align = true
		end
		wp.headlandHeightForTurn = point.headlandHeightForTurn
		if point.islandBypass then
			-- save radius only for island bypass sections for now.
			wp.radius = point.radius
		end
		table.insert(vehicle.Waypoints, wp)
	end
end

function courseGenerator.generate(vehicle)
	local selectedField = vehicle.cp.courseGeneratorSettings.selectedField:get()
	local fieldCourseName = tostring(vehicle.cp.currentCourseName);
	if selectedField > 0 then
		fieldCourseName = courseplay.fields.fieldData[selectedField].name;
	end ;
	courseplay:debug(string.format("generateCourse() called for %q", fieldCourseName), courseplay.DBG_COURSES);

	vehicle.cp.courseGeneratorSettings:debug(courseplay.DBG_COURSES)

	local poly = {}
	local islandNodes = {}
	if selectedField > 0 then
		poly.points = courseplay.utils.table.copy(courseplay.fields.fieldData[selectedField].points, true);
		poly.numPoints = courseplay.fields.fieldData[selectedField].numPoints;
		if not vehicle.cp.courseGeneratorSettings.islandBypassMode:is(Island.BYPASS_MODE_NONE) then
			if not courseplay.fields.fieldData[selectedField].islandNodes then
				courseGenerator.findIslands(courseplay.fields.fieldData[selectedField])
			end
			islandNodes = courseplay.fields.fieldData[selectedField].islandNodes
		end
	else
		poly.points = courseplay.utils.table.copy(vehicle.Waypoints, true);
		poly.numPoints = #(poly.points);
	end ;

	courseplay:clearCurrentLoadedCourse(vehicle);

	local workWidth = vehicle.cp.courseGeneratorSettings.workWidth:get();
	if vehicle.cp.courseGeneratorSettings.multiTools:get() > 1 then
		workWidth = workWidth * vehicle.cp.courseGeneratorSettings.multiTools:get()
	end

	if vehicle.cp.courseGeneratorSettings.startingLocation:is(courseGenerator.STARTING_LOCATION_VEHICLE_POSITION) then
		vehicle.cp.generationPosition.x, _, vehicle.cp.generationPosition.z = getWorldTranslation(vehicle.rootNode)
		vehicle.cp.generationPosition.hasSavedPosition = true
		vehicle:setCpVar('generationPosition.fieldNum', selectedField, courseplay.isClient)
	end

	local field = {}
	local headlandSettings = {}
	field.boundary = Polygon:new(courseGenerator.pointsToXy(poly.points))
	field.boundary:calculateData()

	--  get the vehicle position
	if courseGenerator.isOrdinalDirection(vehicle.cp.courseGeneratorSettings.startingLocation:get()) then
		headlandSettings.startLocation = courseGenerator.getStartingLocation(field.boundary,
			vehicle.cp.courseGeneratorSettings.startingLocation:get())
		courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, "Course starting location is corner %d",
			vehicle.cp.courseGeneratorSettings.startingLocation:get())
	else
		local pos = vehicle.cp.courseGeneratorSettings.startingLocation:getWorldPosition()
		headlandSettings.startLocation = courseGenerator.pointToXy(pos)
		courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, "Course starting location is %.1f/%.1f", pos.x, pos.z)
	end

	local minDistanceBetweenPoints = 0.5
	local doSmooth = true
	local roundCorners = false
	local pipeOnLeftSide = true
	if vehicle.cp.driver and vehicle.cp.driver:is_a(CombineAIDriver) then
		pipeOnLeftSide = vehicle.cp.driver:isPipeOnLeft()
	end
	local centerSettings = {
		useBestAngle = vehicle.cp.courseGeneratorSettings.rowDirection:is(courseGenerator.ROW_DIRECTION_AUTOMATIC),
		useLongestEdgeAngle = vehicle.cp.courseGeneratorSettings.rowDirection:is(courseGenerator.ROW_DIRECTION_LONGEST_EDGE),
		rowAngle = vehicle.cp.courseGeneratorSettings.manualRowAngle:get(),
		nRowsToSkip = vehicle.cp.courseGeneratorSettings.rowsToSkip:get(),
		mode = vehicle.cp.courseGeneratorSettings.centerMode:get(),
		nRowsPerLand = vehicle.cp.courseGeneratorSettings.numberOfRowsPerLand:get(),
		pipeOnLeftSide = pipeOnLeftSide
	}

	local minSmoothAngle, maxSmoothAngle

	if vehicle.cp.courseGeneratorSettings.headlandCornerType:is(courseGenerator.HEADLAND_CORNER_TYPE_SMOOTH) then
		-- do not generate turns on headland
		headlandSettings.minHeadlandTurnAngleDeg = 150
		-- use smoothing instead
		minSmoothAngle, maxSmoothAngle = math.rad(25), math.rad(150)
	elseif vehicle.cp.courseGeneratorSettings.headlandCornerType:is(courseGenerator.HEADLAND_CORNER_TYPE_ROUND) then
		-- generate turns for whatever is left after rounding the corners, for example
		-- the transitions between headland and up/down rows.
		headlandSettings.minHeadlandTurnAngleDeg = 75
		minSmoothAngle, maxSmoothAngle = math.rad(25), math.rad(75)
		-- round all corners to the turn radius	
		roundCorners = true
	else
		-- generate turns over 75 degrees
		headlandSettings.minHeadlandTurnAngleDeg = 60
		-- smooth only below 75 degrees
		minSmoothAngle, maxSmoothAngle = math.rad(25), math.rad(60)
	end
	-- use some overlap between headland passes to get better results
	-- (=less fruit missed) at smooth headland corners
	headlandSettings.overlapPercent = vehicle.cp.courseGeneratorSettings.headlandOverlapPercent:get()
	headlandSettings.nPasses = vehicle.cp.courseGeneratorSettings.headlandPasses:get()
	-- ignore headland order setting when there's no headland
	headlandSettings.headlandFirst =
		vehicle.cp.courseGeneratorSettings.startOnHeadland:is(courseGenerator.HEADLAND_START_ON_HEADLAND) or
		vehicle.cp.courseGeneratorSettings.headlandPasses:is(0)
	-- flip clockwise when starting with the up/down rows
	if vehicle.cp.courseGeneratorSettings.startOnHeadland:is(courseGenerator.HEADLAND_START_ON_HEADLAND) then
		headlandSettings.isClockwise = vehicle.cp.courseGeneratorSettings.headlandDirection:is(courseGenerator.HEADLAND_CLOCKWISE)
	else
		headlandSettings.isClockwise = vehicle.cp.courseGeneratorSettings.headlandDirection:is(courseGenerator.HEADLAND_COUNTERCLOCKWISE)
	end
	headlandSettings.mode = vehicle.cp.courseGeneratorSettings.headlandMode:get()
	-- This is to adjust the turn radius to account for multiTools having more tracks than you would have with just one
	-- tool causing the innermost tool on the headland
	-- turn tighter than possible
	-- Using vehicle.cp.turnDiameter as this is updated when the user changes the value
	local turnRadiusAdjustedForMultiTool = vehicle.cp.turnDiameter / 2 +
		vehicle.cp.courseGeneratorSettings.workWidth:get() *
			(vehicle.cp.courseGeneratorSettings.multiTools:get() - 1) / 2
	local status, ok = xpcall(generateCourseForField, function(err)
		printCallstack();
		return err
	end,
		field, workWidth, headlandSettings,
		minDistanceBetweenPoints,
		minSmoothAngle, maxSmoothAngle, doSmooth,
		roundCorners, turnRadiusAdjustedForMultiTool,
		courseGenerator.pointsToXy(islandNodes),
		vehicle.cp.courseGeneratorSettings.islandBypassMode:get(), centerSettings
	)

	-- return on exception (but continue on not ok as that is just a warning)
	if not status then
		return status, ok
	end

	removeRidgeMarkersFromLastTrack(field.course,
		vehicle.cp.courseGeneratorSettings.startOnHeadland:is(courseGenerator.HEADLAND_START_ON_UP_DOWN_ROWS))

	writeCourseToVehicleWaypoints(vehicle, field.course)

	vehicle.cp.numWaypoints = #vehicle.Waypoints

	if vehicle.cp.numWaypoints == 0 then
		courseplay:debug('ERROR: #vehicle.Waypoints == 0 -> cancel and return', courseplay.DBG_COURSES);
		return status, ok;
	end ;

	courseplay:setWaypointIndex(vehicle, 1);
	vehicle:setCpVar('canDrive', true, courseplay.isClient);
	vehicle.Waypoints[1].wait = true;
	vehicle.Waypoints[1].crossing = true;
	vehicle.Waypoints[vehicle.cp.numWaypoints].wait = true;
	vehicle.Waypoints[vehicle.cp.numWaypoints].crossing = true;
	vehicle.cp.numCourses = 1;
	courseplay.signs:updateWaypointSigns(vehicle);

	-- extra data for turn maneuver
	vehicle.cp.courseWorkWidth = workWidth;
	-- use actually generated number of headlands
	if vehicle.cp.courseGeneratorSettings.headlandMode:is(courseGenerator.HEADLAND_MODE_NORMAL) then
		-- only in normal mode though, the narrow field mode will have
		-- any number of headlands but for the turn maneuvers it is really just
		-- one on the short edge
		vehicle.cp.courseGeneratorSettings.headlandPasses:set(#field.headlandTracks)
	end
	vehicle.cp.courseNumHeadlandLanes = vehicle.cp.courseGeneratorSettings.headlandPasses:get()
	vehicle.cp.courseHeadlandDirectionCW = vehicle.cp.courseGeneratorSettings.headlandDirection:is(courseGenerator.HEADLAND_CLOCKWISE)

	vehicle.cp.hasGeneratedCourse = true;
	courseplay:validateCanSwitchMode(vehicle);

	-- SETUP 2D COURSE DRAW DATA
	vehicle.cp.course2dUpdateDrawData = true;

	if CpManager.isMP then
		CourseEvent.sendEvent(vehicle, vehicle.Waypoints)
		CourseplayEvent.sendEvent(vehicle, "self.cp.courseWorkWidth", vehicle.cp.courseWorkWidth) -- need a setting for this one
		CourseplayEvent.sendEvent(vehicle, "self.cp.workWidth", vehicle.cp.workWidth) -- need a setting for this one
		CourseplayEvent.sendEvent(vehicle, "self.cp.laneNumber", vehicle.cp.laneNumber) -- need a setting for this one
		--setMultiTools
	end

	return status, ok
end

