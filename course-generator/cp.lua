--- This is the interface to Courseplay
-- all course generator related code dependent on CP/Giants functions go here

--- Convert the generated course to CP waypoint format
--
local function writeCourseToVehicleWaypoints( vehicle, course )
	vehicle.Waypoints = {};

	for i, point in ipairs( course ) do
		local wp = {}

		wp.generated = true
		wp.ridgeMarker = point.ridgeMarker
		wp.angle = courseGenerator.toCpAngle( point.nextEdge.angle )
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
		table.insert( vehicle.Waypoints, wp )
	end
end

function courseGenerator.generate( vehicle, name, poly, workWidth, islandNodes )

	local field = {}
	local headlandSettings = {}
	field.boundary = Polygon:new( courseGenerator.pointsToXy( poly.points ))
	field.boundary:calculateData()

	--  get the vehicle position

	if vehicle.cp.startingCorner == courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION and vehicle.cp.generationPosition.hasSavedPosition then
		headlandSettings.startLocation = courseGenerator.pointToXy({ x = vehicle.cp.generationPosition.x, z = vehicle.cp.generationPosition.z })
		courseplay.debugVehicle(7, vehicle, "Course starting location is last vehicle position at %.1f/%.1f",
			vehicle.cp.generationPosition.x, vehicle.cp.generationPosition.z )
	elseif courseGenerator.isOrdinalDirection( vehicle.cp.startingCorner ) then
		headlandSettings.startLocation = courseGenerator.getStartingLocation( field.boundary, vehicle.cp.startingCorner )
		courseplay.debugVehicle(7, vehicle, "Course starting location is corner %d", vehicle.cp.startingCorner )
	elseif vehicle.cp.startingCorner == courseGenerator.STARTING_LOCATION_VEHICLE_POSITION then
		local x, z
		x, _, z = getWorldTranslation( vehicle.rootNode )
		headlandSettings.startLocation = courseGenerator.pointToXy({ x = x, z = z })
		courseplay.debugVehicle(7, vehicle, "Course starting location is current vehicle position at %.1f/%.1f", x, z )
	elseif vehicle.cp.courseGeneratorSettings.startingLocationWorldPos then
		headlandSettings.startLocation = courseGenerator.pointToXy(vehicle.cp.courseGeneratorSettings.startingLocationWorldPos)
		courseplay.debugVehicle(7, vehicle, "Course starting location position selected on map at %.1f/%.1f",
			vehicle.cp.courseGeneratorSettings.startingLocationWorldPos.x,
			vehicle.cp.courseGeneratorSettings.startingLocationWorldPos.z)
	end

	local extendTracks = 0
	local minDistanceBetweenPoints = 0.5
	local doSmooth = true
	local roundCorners = false
	local centerSettings = {
		useBestAngle = vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_AUTOMATIC,
		useLongestEdgeAngle = vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_LONGEST_EDGE,
		rowAngle = vehicle.cp.rowDirectionDeg and math.rad( vehicle.cp.rowDirectionDeg ) or 0,
		nRowsToSkip = vehicle.cp.courseGeneratorSettings.nRowsToSkip,
		mode = vehicle.cp.courseGeneratorSettings.centerMode
	}

	local minSmoothAngle, maxSmoothAngle

	if vehicle.cp.headland.turnType == courseplay.HEADLAND_CORNER_TYPE_SMOOTH then
		-- do not generate turns on headland
		headlandSettings.minHeadlandTurnAngleDeg = 150
		-- use smoothing instead
		minSmoothAngle, maxSmoothAngle = math.rad( 25 ), math.rad( 150 )
	elseif vehicle.cp.headland.turnType == courseplay.HEADLAND_CORNER_TYPE_ROUND then
		-- generate turns for whatever is left after rounding the corners, for example
		-- the transitions between headland and up/down rows.
		headlandSettings.minHeadlandTurnAngleDeg = 75
		minSmoothAngle, maxSmoothAngle = math.rad( 25 ), math.rad( 75 )
		-- round all corners to the turn radius	
		roundCorners = true
	else
		-- generate turns over 75 degrees
		headlandSettings.minHeadlandTurnAngleDeg = 60
		-- smooth only below 75 degrees
		minSmoothAngle, maxSmoothAngle = math.rad( 25 ), math.rad( 60 )
	end
	-- use some overlap between headland passes to get better results
	-- (=less fruit missed) at smooth headland corners
	headlandSettings.overlapPercent = 7
	headlandSettings.nPasses = vehicle.cp.headland.getNumLanes()
	-- ignore headland order setting when there's no headland
	headlandSettings.headlandFirst = vehicle.cp.headland.orderBefore or vehicle.cp.headland.getNumLanes() == 0
	-- flip clockwise when starting with the up/down rows
	if vehicle.cp.headland.orderBefore then
		headlandSettings.isClockwise = vehicle.cp.headland.userDirClockwise
	else
		headlandSettings.isClockwise = not vehicle.cp.headland.userDirClockwise
	end
	headlandSettings.mode = vehicle.cp.headland.mode
	-- This is to adjust the turnradius to account for multiTools haveing more tracks than you would have with just one tool causing the innermost tool on the headland 
	-- turn tighter than possible
	-- Using vehicle.cp.turnDiameter has this is updated when the user changes the vaule
	local turnRadiusAdjustedForMultiTool = vehicle.cp.turnDiameter/2
	if vehicle.cp.multiTools then
		turnRadiusAdjustedForMultiTool = turnRadiusAdjustedForMultiTool + vehicle.cp.workWidth*((vehicle.cp.multiTools-1)/2)
	end
	--[[ commented out as there's not debug.traceback in FS19 so we don't know where we fail if we use xpcall
	local status, ok = xpcall( generateCourseForField, function() print( err, debug.traceback()) end,
		field, workWidth, headlandSettings,
		extendTracks, minDistanceBetweenPoints,
		minSmoothAngle, maxSmoothAngle, doSmooth,
		roundCorners, turnRadiusAdjustedForMultiTool,
		vehicle.cp.returnToFirstPoint, courseGenerator.pointsToXy( islandNodes ),
		vehicle.cp.courseGeneratorSettings.islandBypassMode, centerSettings
	)
	]]--
	local status = true
	local ok = generateCourseForField(
		field, workWidth, headlandSettings,
		extendTracks, minDistanceBetweenPoints,
		minSmoothAngle, maxSmoothAngle, doSmooth,
		roundCorners, turnRadiusAdjustedForMultiTool,
		vehicle.cp.returnToFirstPoint, courseGenerator.pointsToXy( islandNodes ),
		vehicle.cp.courseGeneratorSettings.islandBypassMode, centerSettings
	)

	-- return on exception (but continue on not ok as that is just a warning)
	if not status then
		return status, ok
	end

	removeRidgeMarkersFromLastTrack( field.course, not vehicle.cp.headland.orderBefore )

	writeCourseToVehicleWaypoints( vehicle, field.course )

	vehicle.cp.numWaypoints = #vehicle.Waypoints

	if vehicle.cp.numWaypoints == 0 then
		courseplay:debug('ERROR: #vehicle.Waypoints == 0 -> cancel and return', 7);
		return status, ok;
	end;

	courseplay:setWaypointIndex(vehicle, 1);
	vehicle:setCpVar('canDrive',true,courseplay.isClient);
	vehicle.Waypoints[1].wait = true;
	vehicle.Waypoints[1].crossing = true;
	vehicle.Waypoints[vehicle.cp.numWaypoints].wait = true;
	vehicle.Waypoints[vehicle.cp.numWaypoints].crossing = true;
	vehicle.cp.numCourses = 1;
	courseplay.signs:updateWaypointSigns(vehicle);

	-- extra data for turn maneuver
	vehicle.cp.courseWorkWidth = workWidth;
	-- use actually generated number of headlands
	if vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NORMAL then
		-- only in normal mode though, the narrow field mode will have
		-- any number of headlands but for the turn maneuvers it is really just
		-- one on the short edge
		vehicle.cp.headland.numLanes = #field.headlandTracks
	end
	vehicle.cp.courseNumHeadlandLanes = vehicle.cp.headland.getNumLanes();
	vehicle.cp.courseHeadlandDirectionCW = vehicle.cp.headland.userDirClockwise;

	vehicle.cp.hasGeneratedCourse = true;
	courseplay:setFieldEdgePath(vehicle, nil, 0);
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);

	-- SETUP 2D COURSE DRAW DATA
	vehicle.cp.course2dUpdateDrawData = true;
	return status, ok
end

local modDirectory = g_currentModDirectory

-- It is ugly to have a courseplay member function in this file but button.lua seems to be able to
-- use callbacks only if they are in the courseplay class.
function courseplay:openAdvancedCourseGeneratorSettings( vehicle )
	--- Prevent Dialog from locking up mouse and keyboard when closing it.
	courseplay:lockContext(false);

	if g_CourseGeneratorScreen == nil then
		g_CourseGeneratorScreen = CourseGeneratorScreen:new();
		g_gui:loadProfiles( modDirectory .. "course-generator/guiProfiles.xml" )
		g_gui:loadGui( modDirectory .. "course-generator/CourseGeneratorScreen.xml", "CourseGeneratorScreen", g_CourseGeneratorScreen)
	end
	g_CourseGeneratorScreen:setVehicle( vehicle )
	g_gui:showGui( 'CourseGeneratorScreen' )
	-- force reload screen so changes in XML do not require the entire game to be restarted, just reselect the screen
	g_CourseGeneratorScreen = nil
end

