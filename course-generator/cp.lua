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
    if point.islandBypass then
      -- save radius only for island bypass sections for now.
      wp.radius = point.radius
    end
    table.insert( vehicle.Waypoints, wp )
  end
end

function courseGenerator.generate( vehicle, name, poly, workWidth, islandNodes )

  local field = {}
  field.boundary = Polygon:new( courseGenerator.pointsToXy( poly.points ))
  field.boundary:calculateData() 

  --  get the vehicle position
  local startingLocation
  if vehicle.cp.startingCorner == courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION and vehicle.cp.generationPosition.hasSavedPosition then
	startingLocation = courseGenerator.pointToXy({ x = vehicle.cp.generationPosition.x, z = vehicle.cp.generationPosition.z })
  elseif courseGenerator.isOrdinalDirection( vehicle.cp.startingCorner ) then
	startingLocation = courseGenerator.getStartingLocation( field.boundary, vehicle.cp.startingCorner )
  else
	local x, z
	x, _, z = getWorldTranslation( vehicle.rootNode )
	startingLocation = courseGenerator.pointToXy({ x = x, z = z })
  end

  local overlap = 7
  local nTracksToSkip = 0
  local extendTracks = 0
  local minDistanceBetweenPoints = 0.5
  local doSmooth = true
  local roundCorners = false
	local centerSettings = { 
		useBestAngle = vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_AUTOMATIC,
		useLongestEdgeAngle = vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_LONGEST_EDGE,
		rowAngle = vehicle.cp.rowDirectionDeg and math.rad( vehicle.cp.rowDirectionDeg ) or 0
	}

  local minSmoothAngle, maxSmoothAngle, minHeadlandTurnAngle 

  if vehicle.cp.headland.turnType == courseplay.HEADLAND_CORNER_TYPE_SMOOTH then
    -- do not generate turns on headland
    minHeadlandTurnAngle = math.rad( 150 )
    -- use smoothing instead
    minSmoothAngle, maxSmoothAngle = math.rad( 25 ), math.rad( 150 )
  else
    -- generate turns over 60 degrees
    minHeadlandTurnAngle = math.rad( 60 )
    -- smooth only below 60 degrees
    minSmoothAngle, maxSmoothAngle = math.rad( 25 ), math.rad( 60 )
  end
  -- flip clockwise when starting with the up/down rows
  local clockwise
  if vehicle.cp.headland.orderBefore then
	clockwise = vehicle.cp.headland.userDirClockwise
  else
	clockwise = not vehicle.cp.headland.userDirClockwise
  end
  local status, ok = xpcall( generateCourseForField, function() print( err, debug.traceback()) end,
                              field, workWidth, vehicle.cp.headland.numLanes,
                              clockwise, startingLocation,
                              overlap, nTracksToSkip,
                              extendTracks, minDistanceBetweenPoints,
                              minSmoothAngle, maxSmoothAngle, doSmooth,
                              roundCorners, vehicle.cp.vehicleTurnRadius, minHeadlandTurnAngle,
  							              vehicle.cp.returnToFirstPoint, courseGenerator.pointsToXy( islandNodes ),
                              -- ignore headland order setting when there's no headland
                              vehicle.cp.headland.orderBefore or vehicle.cp.headland.numLanes == 0, 
                              vehicle.cp.islandBypassMode, centerSettings
                             )
  
  if not status then 
    -- show message if there was an exception
    local messageDialog = g_gui:showGui('InfoDialog');
      messageDialog.target:setText(courseplay:loc('COURSEPLAY_COULDNT_GENERATE_COURSE'));
      messageDialog.target:setCallback( function () g_gui:showGui('') end, self )
    return 
  end

	if not ok then
		-- show message if the generated course may have issues due to the selected track direction
		local messageDialog = g_gui:showGui('InfoDialog');
		messageDialog.target:setText(courseplay:loc('COURSEPLAY_COURSE_SUBOPTIMAL'));
		messageDialog.target:setCallback( function () g_gui:showGui('') end, self )
	end
	
  removeRidgeMarkersFromLastTrack( field.course, not vehicle.cp.headland.orderBefore )

  writeCourseToVehicleWaypoints( vehicle, field.course )

	vehicle.cp.numWaypoints = #vehicle.Waypoints	
	
	if vehicle.cp.numWaypoints == 0 then
		courseplay:debug('ERROR: #vehicle.Waypoints == 0 -> cancel and return', 7);
		return;
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
  vehicle.cp.headland.numLanes = #field.headlandTracks
	vehicle.cp.courseNumHeadlandLanes = vehicle.cp.headland.numLanes;
	vehicle.cp.courseHeadlandDirectionCW = vehicle.cp.headland.userDirClockwise;

	vehicle.cp.hasGeneratedCourse = true;
	courseplay:setFieldEdgePath(vehicle, nil, 0);
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);

	-- SETUP 2D COURSE DRAW DATA
	vehicle.cp.course2dUpdateDrawData = true;

end

