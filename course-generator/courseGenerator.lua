--- Setting up packages
courseGenerator = {}

-- Distance of waypoints on the generated track in meters
courseGenerator.waypointDistance = 5

courseGenerator.ROW_DIRECTION_NORTH = 1
courseGenerator.ROW_DIRECTION_EAST = 2
courseGenerator.ROW_DIRECTION_SOUTH = 3
courseGenerator.ROW_DIRECTION_WEST = 4
courseGenerator.ROW_DIRECTION_AUTOMATIC = 5
courseGenerator.ROW_DIRECTION_LONGEST_EDGE = 6
courseGenerator.ROW_DIRECTION_MANUAL = 7

courseGenerator.trackDirectionRanges = {
	{ angle =  0  }, 
	{ angle =  1 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_N' },
	{ angle =  3 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NNE' },
	{ angle =  5 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NE' },
	{ angle =  7 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_ENE' },
	{ angle =  9 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_E' },
	{ angle = 11 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_ESE' },
	{ angle = 13 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SE' },
	{ angle = 15 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SSE' },
	{ angle = 17 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_S' },
	{ angle = 19 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SSW' },
	{ angle = 21 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SW' },
	{ angle = 23 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_WSW' },
	{ angle = 25 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_W' },
	{ angle = 27 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_WNW' },
	{ angle = 29 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NW' },
	{ angle = 31 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NNW' },
	{ angle = 32 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_N' },
}

-- corners of a field block
courseGenerator.BLOCK_CORNER_BOTTOM_LEFT = 1
courseGenerator.BLOCK_CORNER_BOTTOM_RIGHT = 2
courseGenerator.BLOCK_CORNER_TOP_RIGHT = 3
courseGenerator.BLOCK_CORNER_TOP_LEFT = 4

-- starting location
courseGenerator.STARTING_LOCATION_MIN = 1
courseGenerator.STARTING_LOCATION_SW_LEGACY = 1
courseGenerator.STARTING_LOCATION_NW_LEGACY = 2
courseGenerator.STARTING_LOCATION_NE_LEGACY = 3
courseGenerator.STARTING_LOCATION_SE_LEGACY = 4
courseGenerator.STARTING_LOCATION_VEHICLE_POSITION = 5
courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION = 6
courseGenerator.STARTING_LOCATION_SW = 7
courseGenerator.STARTING_LOCATION_NW = 8
courseGenerator.STARTING_LOCATION_NE = 9
courseGenerator.STARTING_LOCATION_SE = 10
courseGenerator.STARTING_LOCATION_MAX = 10

function courseGenerator.isOrdinalDirection( startingLocation )
	return startingLocation >= courseGenerator.STARTING_LOCATION_SW and
		startingLocation <= courseGenerator.STARTING_LOCATION_SE
end

--- Debug print, will either just call print when running standalone
--  or use the CP debug channel when running in the game.
function courseGenerator.debug( ... )
  if courseGenerator.isRunningInGame() then
	  courseplay:debug( string.format( ... ), 7 )
  else
    print( string.format( ... ))
  end
end

--- Return true when running in the game
-- used by file and log functions to determine how exactly to do things,
-- for example, io.flush is not available from within the game.
--
function courseGenerator.isRunningInGame()
  return courseplay ~= nil;
end

function courseGenerator.getCurrentTime()
	if courseGenerator.isRunningInGame() then
		return g_currentMission.time
	else
		return os.time()
	end
end
--- Function to convert between CP/Giants coordinate representations
-- and the course generator conventional x/y coordinates.
--
function courseGenerator.pointsToXy( points )
	local result = {}
	for _, point in ipairs( points ) do
		table.insert( result, { x = point.x or point.cx, y = - ( point.z or point.cz )})
	end
	return result
end

function courseGenerator.pointsToXz( points )
	local result = {}
	for _, point in ipairs( points) do
		table.insert( result, { x = point.x, z = -point.y })
	end
	return result
end

function courseGenerator.pointsToCxCz( points )
	local result = {}
	for _, point in ipairs( points) do
		table.insert( result, { cx = point.x, cz = -point.y })
	end
	return result
end

function courseGenerator.pointToXy( point )
	return({ x = point.x or point.cx, y = - ( point.z or point.cz )})
end

function courseGenerator.pointToXz( point )
	return({ x = point.x, z = -point.y })
end

function courseGenerator.pointToXz( point )
	return({ x = point.x, z = -point.y })
end

--- Convert our angle representation (measured from the x axis up in radians)
-- into CP's, where 0 is to the south, to our negative y axis.
--
function courseGenerator.toCpAngle( angle )
  local a = math.deg( angle ) + 90
  if a > 180 then
    a = a - 360
  end
  return a
end


--- Pathfinder wrapper for CP 
-- Expects FS coordinates (x,-z)
function courseGenerator.findPath( from, to, cpPolygon, fruit )
	local path, grid = pathFinder.findPath( courseGenerator.pointToXy( from ), courseGenerator.pointToXy( to ),
		Polygon:new( courseGenerator.pointsToXy( cpPolygon )), fruit, nil, nil )
	if path then
		return courseGenerator.pointsToXz( path ), grid
	else
		return nil, grid
	end
end

--- Island finder wrapper for CP, 
-- expects FS coordinates
function courseGenerator.findIslands( fieldData )
	local islandNodes = pathFinder.findIslands( Polygon:new( courseGenerator.pointsToXy( fieldData.points )))
	fieldData.islandNodes = courseGenerator.pointsToCxCz( islandNodes )
end

--- Find the starting location coordinates when the user wants to start
-- at a corner. Use the appropriate bounding box coordinates of the field
-- as the starting location and let the generator find the closest part
-- of the field which will be the corner as long as it is more or less
-- rectangular. Oddly shaped fields may produce odd results.
function courseGenerator.getStartingLocation( boundary, startingCorner )
	local x, y = 0, 0
	if startingCorner == courseGenerator.STARTING_LOCATION_NW then
		x, y = boundary.boundingBox.minX, boundary.boundingBox.maxY
	elseif startingCorner == courseGenerator.STARTING_LOCATION_NE then
		x, y = boundary.boundingBox.maxX, boundary.boundingBox.maxY
	elseif startingCorner == courseGenerator.STARTING_LOCATION_SE then
		x, y = boundary.boundingBox.maxX, boundary.boundingBox.minY
	elseif startingCorner == courseGenerator.STARTING_LOCATION_SW then
		x, y = boundary.boundingBox.minX, boundary.boundingBox.minY
	end
	return { x = x, y = y }
end

function courseGenerator.getCompassDirectionText( gameAngleDeg ) 
	local compassAngle = math.rad( courseGenerator.getCompassAngleDeg( gameAngleDeg ))
	for r = 2, #courseGenerator.trackDirectionRanges, 1 do
		if compassAngle >= courseGenerator.trackDirectionRanges[ r - 1 ].angle and
			compassAngle < courseGenerator.trackDirectionRanges[ r ].angle then
			return courseGenerator.trackDirectionRanges[ r ].text
		end
	end
end

--- Convert the game direction angles to compass direction
function courseGenerator.getCompassAngleDeg( gameAngleDeg )
	return ( 360 + gameAngleDeg - 90 ) % 360
end