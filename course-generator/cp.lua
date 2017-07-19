--- This is the interface to Courseplay
-- 

--- Convert the generated course to CP waypoint format
--
local function writeCourseToVehicleWaypoints( vehicle, course )
	vehicle.Waypoints = {};

  for i, point in ipairs( course ) do
    local wp = {}

    wp.generated = true
    wp.ridgeMarker = point.ridgeMarker
    wp.angle = toCpAngle( point.nextEdge.angle )
    wp.cx = point.x
    wp.cz = -point.y
    wp.wait = nil
    wp.rev = nil
    wp.crossing = nil

    if point.passNumber then
      wp.lane = -point.passNumber
    end
    if point.turnStart then
      wp.turnStart = true
    end
    if point.turnEnd then
      wp.turnEnd = true
    end
    table.insert( vehicle.Waypoints, wp )
  end
end

function courseGenerator.generate( vehicle, name, poly )

  local field = fromCpField( name, poly.points ) 
  calculatePolygonData( field.boundary )

  --  get the vehicle position
  local x, _, z = getWorldTranslation( vehicle.rootNode )
  if vehicle.cp.startingCorner == 6 and vehicle.cp.generationPosition.hasSavedPosition then
	x,z = vehicle.cp.generationPosition.x,vehicle.cp.generationPosition.z
  end
  
  
  -- translate it into our coordinate system
  local location = { x = x, y = -z }

  field.width = vehicle.cp.workWidth 
  field.headlandClockwise = vehicle.cp.userDirClockwise
  field.overlap = 10
  field.nTracksToSkip = 0
  field.extendTracks = 0
  field.minDistanceBetweenPoints = 0.5
  field.angleThresholdDeg = 30
  field.doSmooth = true
  field.roundCorners = false

  
  local status, err = xpcall( generateCourseForField, function() print( err, debug.traceback()) end, 
                              field, vehicle.cp.workWidth, vehicle.cp.headland.numLanes,
                              vehicle.cp.headland.userDirClockwise, location,
                              field.overlap, field.nTracksToSkip,
                              field.extendTracks, field.minDistanceBetweenPoints,
                              math.rad( field.angleThresholdDeg ), field.doSmooth,
                              field.roundCorners
                             )
  
  if not status then 
    -- show message if there was an exception
    local messageDialog = g_gui:showGui('InfoDialog');
      messageDialog.target:setText(courseplay:loc('COURSEPLAY_COULDNT_GENERATE_COURSE'));
      messageDialog.target:setCallback( function () g_gui:showGui('') end, self )
    return 
  end
 
  if not vehicle.cp.headland.orderBefore then
    -- work the center of the field first, then the headland
    field.course = reverseCourse( field.course )
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
	vehicle.cp.courseWorkWidth = vehicle.cp.workWidth;
	vehicle.cp.courseNumHeadlandLanes = numHeadlandLanesCreated;
	vehicle.cp.courseHeadlandDirectionCW = vehicle.cp.headland.userDirClockwise;

	vehicle.cp.hasGeneratedCourse = true;
	courseplay:setFieldEdgePath(vehicle, nil, 0);
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);

	-- SETUP 2D COURSE DRAW DATA
	vehicle.cp.course2dUpdateDrawData = true;

end

