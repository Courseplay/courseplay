--- Setting up packages
courseGenerator = {}

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