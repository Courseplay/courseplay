--
--  Geometry functions. No dependency on track/field/FS/courseplay
--  2D functions in the x,y plane
--


-- a point has the following attributes:
-- x
-- y
-- prevEdge : vector from the previous to this point
-- nextEdge : vector from this point to the next
-- tangent : the tangent vector of the curve at this point,
--           calculated as the vector between the 
--           the previous and next points
-- directionStats : edge lengths per direction range, used
--                  to figure out the longest edge, or, the
--                  optimum direction of tracks
--                  The key in this table is a 20 degree wide range
--                  between -180 and +180, the value is the total
--                  length of edges pointing in that range

-- calculates the polar coordinates of x, y with some filtering
-- around pi/2 where tan is infinite
function toPolar( x, y )
  local length = math.sqrt( x * x + y * y )
  local bigEnough = 1000
  if ( x == 0 ) or ( math.abs( y/x ) > bigEnough ) then
    -- pi/2 or -pi/2
    if y >= 0 then 
      return math.pi / 2, length  -- north
    else 
      return - math.pi / 2, length -- south
    end 
  else
    return math.atan2( y, x ), length 
  end
end

function getDistanceBetweenPoints( p1, p2 )
  local dx = p2.x - p1.x
  local dy = p2.y - p1.y
  return math.sqrt( dx * dx + dy * dy )
end

function getClosestPointIndex( polygon, p )
  local minDistance = 10000
  local ix
  for i, vertex in polygon:iterator() do
    local d = getDistanceBetweenPoints( vertex, p )
    if d < minDistance then
      minDistance = d
      ix = i
    end
  end
  return ix, minDistance
end

--- Add a vector defined by polar coordinates to a point
-- @param point x and y coordinates of point
-- @param angle angle of polar vector
-- @param length length of polar vector
-- @return x and y of the resulting point
function addPolarVectorToPoint( point, angle, length )
  return { x = point.x + length * math.cos( angle ),
           y = point.y + length * math.sin( angle )}
end

function normalizeAngle( a ) 
	return a >= 0 and a or 2 * math.pi + a	
end
--- Get the average of two angles. 
-- Works fine even for the transition from -pi/2 to +pi/2
function getAverageAngle( a1, a2 )
  -- convert the 0 - -180 range into 180 - 360
  if math.abs( a1 - a2 ) > math.pi then
	  a1 = normalizeAngle( a1 )
	  a2 = normalizeAngle( a2 )
  end
  -- calculate average in this range
  local avg = ( a1 + a2 ) / 2
  -- convert back to 0 - -180 if necessary
  if avg > math.pi then avg = avg - 2 * math.pi end
  return avg
end

--- Get difference between two angles, even through 
-- -pi/2 and + pi/2
function getDeltaAngle( a1, a2 )
  -- convert the 0 - -180 range into 180 - 360
  if math.abs( a1 - a2 ) > math.pi then
	  a1 = normalizeAngle( a1 )
	  a2 = normalizeAngle( a2 )
  end
  -- calculate difference in this range
  return a2 - a1
end

-- TODO: put this into Polyline
--- This is kind of a low pass filter. If the 
-- direction change to the  next point is too big, 
-- the last point is removed
-- If the distance to the next point is less than distanceThreshold,
-- the current point is removed and the next one is replaced with a 
-- point between the current and the next.
function applyLowPassFilter( polygon, angleThreshold, distanceThreshold, isLine )
  local index, lastIndex
  if isLine then 
    -- don't wrap around the ends if it is a line
    index = 1
    lastIndex = #polygon - 1
  else
    index = 1
    lastIndex = #polygon
  end
  repeat
    local cp, np = polygon[ index], polygon[ index + 1 ]
    -- need to recalculate the edge length as we are moving points 
    -- around here
    local angle, length = toPolar( np.x - cp.x, np.y - cp.y )
    local isTooClose = length < distanceThreshold
    local isTooSharp = math.abs( getDeltaAngle( np.prevEdge.angle, cp.prevEdge.angle )) > angleThreshold 
    if isTooClose or isTooSharp then
      -- replace current and next point with something in the middle
      polygon[ index + 1 ].x, polygon[ index + 1 ].y = getPointInTheMiddle( cp, np )
    end
    if isTooSharp or isTooClose then
      table.remove( polygon, polygon:getIndex( index ))
      polygon:calculateData()
    else
      index = index + 1
    end
  until index > #polygon
end

-- TODO: put this into Polyline
--- make sure points in line are at least d apart
-- except in curves 
function space( line, angleThreshold, d )
  local result = Polyline:new({ line[ 1 ]})
  for i = 2, #line - 1 do
    local cp, pp = line[ i ], result[ #result ]
    local isCurve = math.abs( getDeltaAngle( cp.nextEdge.angle, pp.nextEdge.angle )) > angleThreshold 
    if getDistanceBetweenPoints( cp, pp ) > d or isCurve then
      table.insert( result, cp ) 
    end
  end
  return result
end

--- Round corners of a polygon to turningRadius
--
function roundCorners( polygon, turningRadius )
  local result = {}
  -- check for corners in a distance depending on the turning radius
  local d = turningRadius * 3 
  local angleThreshold = math.rad( 45 )
  i = 1
  while ( i <= #polygon ) do
    toIx = getTurnData( polygon, i, d )
    table.insert( result, polygon[ i ])
    if toIx then
      -- Is there a significant direction change within d distance?
      local da = getDeltaAngle( polygon[ i ].prevEdge.angle,
                        polygon[ toIx ].nextEdge.angle )
      if math.abs( da ) > angleThreshold then
        print( polygon[ i ].prevEdge.to.x - polygon[ i ].x )
        local points = findArcBetweenEdges( polygon[ i ].prevEdge, 
                                            polygon[ toIx ].nextEdge,
                                            turningRadius )
        if points then
          print( string.format( "OK, Arc with %.2f radius found between %d and %d", turningRadius, i, toIx ))  
          polygon[ i ].cornerScore = 1
          points[ 1 ].cornerScore = 2
          points[ #points ].cornerScore = 4
          -- replace points between i and toIx with the arc
          for j, point in ipairs( points ) do
            table.insert( result, point )
          end
          i = toIx
        else
          print( string.format( "FAIL, Can't find an arc with %.2f radius", turningRadius ))  
        end
      end
    end
    i = i + 1
  end
  return result
end

-- add headland turn information to the waypoints if this is a sharp 
-- corner. 
-- Returns the next index to continue the iteration, that is i + 1 if 
-- there was no turn, or the index of the next waypoint after the turn.
function addTurnInfo( vertices, i, turnRadius, minHeadlandTurnAngle )
  local d = 0
  -- see if we can make a turn to the next wp
  local r, dA = getTurningRadiusBetweenTwoPoints( vertices[ i ], vertices[ i + 1 ])
  if r < turnRadius then 
    -- we can't make it the next see if we have a corner starting here 
    vertices[ i ].text = string.format( "r=%.1f (%d)", r, i )
    local toIx, dA, d = getTurnData( vertices, i, turnRadius * math.pi / 2 )
    print( string.format( "%d-%d, %.1f, %.1f", i, toIx, math.deg( dA ), r ))
    if math.abs( dA ) > minHeadlandTurnAngle then
      print( "****" )
      vertices[ i ].turnStart = true
      vertices[ i ].headlandTurn = true
      vertices[ toIx ].turnEnd = true
      return toIx
    end
  end
  return i + 1
end

-- get the theoretical turning radius we need to go from 'from' to 'to', 
-- starting in the from.prevEdge.angle direction and ending up in 
-- to.nextEdge.angle
function getTurningRadiusBetweenTwoPoints( from, to )
  local dA = getDeltaAngle( to.nextEdge.angle, from.prevEdge.angle )
  local r = math.abs( from.nextEdge.length / dA )
  return r, dA
end

-- Find the index of the vertex where the turn ends but not further than d distance
-- from startIx of a polygon 
-- Also, return the accumulated direction change total, negative and positive
--
function getTurnData( polygon, fromIx, distance )
  local d = 0
  local dDirChange = 0 -- distance where the direction actually changes
  local totalDirChange, posDirChange, negDirChange = 0, 0, 0
  local prevTotalDirChange = math.huge
  local toIx = fromIx
  while toIx < #polygon and d < distance and 
    -- stop when direction does not change much over a significant distance 
    not ( math.abs( totalDirChange - prevTotalDirChange ) < math.rad( 10 ) and 
          polygon[ toIx ].prevEdge.length > distance / 10 ) do
    d = d + polygon[ toIx ].nextEdge.length  
    toIx = toIx + 1
    prevTotalDirChange = totalDirChange
    totalDirChange = totalDirChange + polygon[ toIx ].deltaAngle
    if polygon[ toIx ].deltaAngle > 0 then
      posDirChange = posDirChange + polygon[ toIx ].deltaAngle
    else
      negDirChange = negDirChange + polygon[ toIx ].deltaAngle
    end
  end
  return math.max( toIx - 1, fromIx ), totalDirChange, dDirChange, posDirChange, negDirChange
end


function addToDirectionStats( directionStats, angle, length )
  local width = 2
	-- normalize angle
	local a = math.deg( angle )
	a = a < 0 and ( a + 180 ) or a
	a = a % 180
  local range = math.floor( a / width ) * width + width / 2
  if directionStats[ range ] then  
    directionStats[ range ].length = directionStats[ range ].length + length
    table.insert( directionStats[ range ].dirs, a )
  else
    directionStats[ range ] = { length=0, dirs={ a }}
  end
end

--- Trying to figure out in which direction 
-- the field is the longest.
function getBestDirection( directionStats )
  local best = { range = 0, length = 0 }
  -- find the angle range which has to most length
	for range, stats in pairs( directionStats ) do
		if stats.length > best.length then 
      best.length = stats.length
      best.range = range
    end
  end
  local sum = 0
	-- calculate the average direction of the best range
  if directionStats[ best.range ] then
    for i, dir in ipairs( directionStats[ best.range ].dirs ) do
      sum = sum + dir
    end
    best.dir = math.floor( sum / #directionStats[ best.range ].dirs + 0.5 )
  end
  return best
end

-- Does the line defined by p1 and p2 intersect the polygon?
-- If yes, return two indices. The line intersects the polygon between
-- these two indices
function getIntersectionOfLineAndPolygon( polygon, p1, p2 ) 
  -- loop through the polygon and check each vector from 
  -- the current point to the next
  for i, cp in polygon:iterator() do
    local np = polygon[ i + 1 ] 
    local interSectionPoint = getIntersection( cp.x, cp.y, np.x, np.y, p1.x, p1.y, p2.x, p2.y )
    if interSectionPoint then
      -- the line between p1 and p2 intersects the vector from cp to np
      return i, polygon:getIndex( i + 1 ), interSectionPoint
    end
  end
  return nil, nil
end

--- Same as getIntersectionOfLineAndPolygon but returns all 
-- intersections in a table
function getAllIntersectionsOfLineAndPolygon( polygon, p1, p2 )
  local intersections = {}
  -- loop through the polygon and check each vector from 
  -- the current point to the next
  for i, cp in polygon:iterator() do
    local np = polygon[ i + 1 ]
    local intersectionPoint = getIntersection( cp.x, cp.y, np.x, np.y, p1.x, p1.y, p2.x, p2.y )
    if intersectionPoint then
      -- only add if this is not found already. Can happen if the p1-p2 goes right through 
      -- a vertex of the polygon, so it getIntersection will be true for two edges of the polygon
      local found = false
      for i, p in ipairs( intersections ) do
        found = getDistanceBetweenPoints( p.point, intersectionPoint ) < 0.1
      end
      if not found then
        table.insert( intersections, { fromIx = i, toIx = polygon:getIndex( i + 1 ), point = intersectionPoint,
          d = getDistanceBetweenPoints( p1, intersectionPoint )})
      end
    end
  end
  -- now bubble sort the intersection points by they distance from p1 so the one closest
  -- to p1 is the first in the table
  for i = 1, #intersections -1 do
    if intersections[ i + 1 ].d < intersections[ i ].d then
      intersections[ i ], intersections[ i + 1 ] = intersections[ i + 1 ], intersections[ i ]
    end
  end
  return intersections
end

--- Find the points of an arc with radius r connecting to 
--  edges of a polygon.
--  e1, e2 are the edges like in calculatePolygonData
--  and we assume that as we walk around the polygon with increasing
--  vertice indexes, e1 comes first, then e2.
--  We want to use this to round sharp edges of polygon.
--
function findArcBetweenEdges( e1, e2, r )
  -- first, find the intersection of ab and cd. We most likely 
  -- have to make them longer, as they are edges of a polygon 
  -- lengthen ab forward and cd backwards by double radius
  -- calculate distance from 'is' to the point where a circle
  -- with r radius would touch ab/cd
  local is = getIntersectionOfExtendedEdges( e1, e2, 2 * r * math.pi )
  if is == nil then return nil end
  -- need to reverse one of the edges to get the correct angle between the two
  local alpha = getDeltaAngle( reverseAngle( e1.angle ), e2.angle )
  -- this is how far from 'is' the circle touches the e1 e2 lines
  local d = math.abs( r / math.tan( alpha / 2 ))
  -- our edges must be at least d distance from 'is' to be able
  -- to connect them with an arc  
  local e1ToIs = getDistanceBetweenPoints( e1.to, is ) 
  local isToE2 = getDistanceBetweenPoints( is, e2.from ) 
  if lt( e1ToIs, d ) or lt( isToE2, d ) then
    return nil 
  end
  -- let's check if we really need to find an arc here. If we can
  -- draw a circle with a radius > r, there's nothing to do here.
  local rCalculated = math.abs( math.min( e1ToIs, isToE2 ) * math.tan( alpha / 2 ))
  print( string.format( "rCalculated=%.2f", rCalculated )) 
  if r < rCalculated then 
    r = rCalculated 
    d = math.min( e1ToIs, isToE2 )
    is = getIntersectionOfExtendedEdges( e1, e2, 2 * r * math.pi )
  end
  -- looks good, so start adding waypoints between e1.to and e2.from.
  -- first, go straight until we are exactly at d from is
  local points = {}
  local delta = e1ToIs - d
  local p = { x=e1.to.x + delta * e1.dx / e1.length,
              y=e1.to.y + delta * e1.dy / e1.length }
  table.insert( points, p )
  -- from here, go around in an arc until we are heading to e2.angle
  alpha = getDeltaAngle( e1.angle, e2.angle )
  -- do about 10 degree steps
  local nSteps = math.abs( math.floor( alpha * 36 / ( 2 * math.pi )))
  -- delta angle for one step
  local deltaAlpha = alpha / ( nSteps + 1 )
  -- length of a step
  local length = 2 * r * math.abs( math.sin( alpha / nSteps / 2 ))
  local currentAlpha = e1.angle + deltaAlpha
  -- now walk around the arc
  for n = 1, nSteps, 1 do
    p = addPolarVectorToPoint( p, currentAlpha, length )
    table.insert( points, p )
    currentAlpha = currentAlpha + deltaAlpha
  end
  return points 
end

-- Find the intersection of ab and cd. We extend them both with
-- extensionLength, ab forward, cd backwards as they are edges 
-- of a polygon
function getIntersectionOfExtendedEdges( ab, cd, extensionLength )
  local ab = deepCopy( ab, true )
  local cd = deepCopy( cd, true )
  ab.to.x = ab.to.x + extensionLength * ab.dx / ab.length
  ab.to.y = ab.to.y + extensionLength * ab.dy / ab.length
  cd.from.x = cd.from.x - extensionLength * cd.dx / cd.length
  cd.from.y = cd.from.y - extensionLength * cd.dy / cd.length
  -- see if they inersect now 
  local is = getIntersection( ab.from.x, ab.from.y, ab.to.x, ab.to.y,
                              cd.from.x, cd.from.y, cd.to.x, cd.to.y )
  return is
end

function getIntersection(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y)
	local s1_x, s1_y, s2_x, s2_y ;
	s1_x = A2x - A1x;
	s1_y = A2y - A1y;
	s2_x = B2x - B1x;
	s2_y = B2y - B1y;

	local s, t;
	s = (-s1_y * (A1x - B1x) + s1_x * (A1y - B1y)) / (-s2_x * s1_y + s1_x * s2_y);
	t = ( s2_x * (A1y - B1y) - s2_y * (A1x - B1x)) / (-s2_x * s1_y + s1_x * s2_y);

	if (s >= 0 and s <= 1 and t >= 0 and t <= 1) then
		--Collision detected
		local x = A1x + (t * s1_x);
		local y = A1y + (t * s1_y);
		return { x = x, y = y };
	end;

	--No collision
	return nil;
end;

function createRectangularPolygon( x, y, dx, dy, step )
  local rect = {}
  for ix = x, x + dx, step do
    table.insert( rect, { x = ix, y = y })
  end
  for iy = y + step, y + dy, step do
    table.insert( rect, { x = x + dx, y = iy })
  end
  for ix = x + dx - step, x, -step do
    table.insert( rect, { x = ix, y = y + dy })
  end
  for iy = y + dy - step, y, -step do
    table.insert( rect, { x = x, y = iy })
  end
  return rect
end

-- TODO: put this into Polyline

function translatePoints( points, dx, dy )
  local result = Polygon:new()
  for i, point in points:iterator() do
    local newPoint = copyPoint( point )
    newPoint.x = points[ i ].x + dx
    newPoint.y = points[ i ].y + dy 
    table.insert( result, newPoint )
  end
  return result
end

-- TODO: put this into Polyline

function rotatePoints( points, angle )
  local result = Polygon:new()
  local sin = math.sin( angle )
  local cos = math.cos( angle )
  for i, point in points:iterator() do
    local newPoint = copyPoint( point )
    newPoint.x = points[ i ].x * cos - points[ i ].y  * sin
    newPoint.y = points[ i ].x * sin + points[ i ].y  * cos
    table.insert( result, newPoint )
  end
  result.boundingBox = result:getBoundingBox()
  return result
end

--- Reverse elements of an array
function reverse( t )
  local result = {}
  for i = #t, 1, -1 do
    table.insert( result, t[ i ])
  end
  return result
end

function reverseAngle( angle )
  local r = angle + math.pi
  if r > math.pi * 2 then
    r = r - math.pi * 2 
  end
  return r
end

function getInwardDirection( isClockwise, angle )
  if not angle then
    angle = math.pi / 2
  end
  if isClockwise then
    return -1 * angle
  else
    return angle
  end
end

function getOutwardDirection( isClockwise, angle )
  return - getInwardDirection( isClockwise, angle )
end

-- shallow copy for preserving point attributes through 
-- transformations
function copyPoint( point )
  local result = {}
  for k, v in pairs( point ) do
    result[ k ] = v
  end
  return result
end

-- this is from courseplay/helper.lua, should be removed once integrated with courseplay
function deepCopy(tab, recursive)
-- note that if 'recursive' is not 'true', only tab is copied. 
-- if tab contains tables itself again, these tables are not copied 
-- but referenced again (the reference is copied).
	local result = {};
	for k,v in pairs(tab) do
		if recursive and type(v) == 'table' then
			result[k] = deepCopy(v, recursive);
		else
			result[k] = v;
		end;
	end;
	return result;
end;

function getPointInTheMiddle( a, b )
	return a.x + (( b.x - a.x ) / 2 ),
	a.y + (( b.y - a.y ) / 2 )
end

function getPointBetween( a, b, dFromA )
	local dx, dy = b.x - a.x, b.y - a.y
	local ratio = dFromA / math.sqrt( dx * dx + dy * dy )
	return a.x + (( b.x - a.x ) * ratio ),
	a.y + (( b.y - a.y ) * ratio )
end


function printTable( t )
	for key, value in pairs( t ) do
		print( key, value )
	end
end

--- Less than operator with limited precision
-- to tolerate floating point precision errors
function lt( a, b )
  -- for courseplay, we are calculating in meters, so 
  -- we are fine with one millimeter precision
  local epsilon = 0.001
  return a < ( b - epsilon )
end
	
--- Classes (these should all be in their own files but require does not 
-- work in the Giants engine so all files must be explicetly loaded with source()
-- and every single file added to courseplay.lua)

-- for 5.1 and 5.2 compatibility
local unpack = unpack or table.unpack

-------------------------------------------------------------------------------

Polyline = {}
Polyline.__index = Polyline

--- Polyline constructor.
-- Integer indices are the vertices of the polygon
function Polyline:new( vertices )
  local newPolyline
  if vertices then
    newPolyline = { unpack( vertices ) }
  else
    newPolyline = {}
  end
  return setmetatable( newPolyline, self )
end

function Polyline:copy( other )
	local newPolyline = {}
	for i, p in ipairs( other ) do
		newPolyline[ i ] = copyPoint( p )
	end
	return setmetatable( newPolyline, self )
end


--- Iterator that won't return nil for i < 1 and i > size
function Polyline:iterator( from, to, step )
  local s = step or 1
  local i, n
  if s > 0 then
    i = from and math.max( from, 1 ) or 1
    n = to and math.min( to, #self ) or #self
  else
    i = from and math.min( from, #self ) or #self
    n = to and math.max( to, 1 ) or 1
  end 
  local lastOne = false
  return function()
    if ( not lastOne and #self > 0 ) then
      if s > 0 then 
        lastOne = i >= n 
      else
        lastOne = i <= n 
      end
      local key, value = i, self[ i ]
      i = i + s 
      return key, value
    end
  end
end

function Polyline:calculateData()
  local directionStats = {}
  local dAngle = 0
  local area = 0
  local shortestEdgeLength = 1000
	local dx, dy, angle, length
  for i, point in self:iterator() do
    local pp, cp, np = self[ i - 1 ], self[ i ], self[ i + 1 ]
	  if pp then
		  -- vector from the previous to this point
		  dx = cp.x - pp.x
		  dy = cp.y - pp.y
		  angle, length = toPolar( dx, dy )
		  self[ i ].prevEdge = { from={ x=pp.x, y=pp.y} , to={ x=cp.x, y=cp.y }, angle=angle, length=length, dx=dx, dy=dy }
		  if length < shortestEdgeLength then shortestEdgeLength = length end
		  -- detect clockwise/counterclockwise direction 
		  if pp.prevEdge and cp.prevEdge then
			  if pp.prevEdge.angle and cp.prevEdge.angle then
				  dAngle = dAngle + getDeltaAngle( cp.prevEdge.angle, pp.prevEdge.angle )
			  end
		  end
	  end
	  if np then
		  -- vector from this to the next point 
		  dx = np.x - cp.x
		  dy = np.y - cp.y
		  angle, length = toPolar( dx, dy )
		  self[ i ].nextEdge = { from = { x=cp.x, y=cp.y }, to={x=np.x, y=np.y}, angle=angle, length=length, dx=dx, dy=dy }
		  if length < shortestEdgeLength then shortestEdgeLength = length end
		  addToDirectionStats( directionStats, angle, length )
		  area = area + ( cp.x * np.y - cp.y * np.x )
	  end
	  if pp and np then
		  -- vector from the previous to the next point
		  dx = np.x - pp.x
		  dy = np.y - pp.y
		  angle, length = toPolar( dx, dy )
		  self[ i ].tangent = { angle=angle, length=length, dx=dx, dy=dy }
		  self[ i ].deltaAngle = getDeltaAngle( self[ i ].nextEdge.angle, self[ i ].prevEdge.angle )
		  self[ i ].radius = math.abs( self[ i ].nextEdge.length / ( 2 * math.asin( self[ i ].deltaAngle / 2 )))
	  end
  end
  self.directionStats = directionStats
  self.bestDirection = getBestDirection( directionStats )
  self.isClockwise = dAngle > 0
  self.area = self.isClockwise and - area / 2 or area / 2
  self.shortestEdgeLength = shortestEdgeLength
  self.boundingBox = self:getBoundingBox()
end

function Polyline:getBoundingBox()
  local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
  for i, point in self:iterator() do
    if ( point.x < minX ) then minX = point.x end
    if ( point.y < minY ) then minY = point.y end
    if ( point.x > maxX ) then maxX = point.x end
    if ( point.y > maxY ) then maxY = point.y end
  end
  return { minX=minX, maxX=maxX, minY=minY, maxY=maxY }
end

function Polyline:hasTurnWaypoint( iterator )
	for _, p in ( iterator or self:iterator()) do
		if p.turnStart or p.turnEnd then
			return true
		end
	end
	return false
end

-- spline functions: smooth, tuck and refine
-- http://stackoverflow.com/questions/29612584/creating-cubic-and-or-quadratic-bezier-curves-to-fit-a-path

-- insert a point in the middle of each edge.
function Polyline:refine( iterator, minSmoothAngle, maxSmoothAngle )
	local pointsToInsert = {}
	-- iterate through the existing table but do not insert the 
	-- new points, only remember the index where they would end up
	-- (as we do not want to modify the table while iterating)
	local ix = -1
	for i, _ in iterator do
		-- initialize ix to the first value of i
		if ix < 0 then ix = i end
		if self[ i + 1 ] and self[ i ].deltaAngle then
			if math.abs( self[ i ].deltaAngle ) > minSmoothAngle and
			   math.abs( self[ i ].deltaAngle ) < maxSmoothAngle then
				-- insert points only when there is really a curve here
				-- also, preserve all attributes of the point
				local newPoint = copyPoint( self[ i ])
				newPoint.x, newPoint.y =  getPointInTheMiddle( self[ i ], self[ i + 1 ])
				newPoint.text = 'refined'
				newPoint.smoothed = true
				ix = ix + 1
				table.insert( pointsToInsert, { ix = ix, point = newPoint })
			end
		end
		self[ i ].smoothed = true
		ix = ix + 1;
	end
	for _, p in ipairs( pointsToInsert ) do
		table.insert( self, p.ix, p.point )
	end
	self:calculateData()
end

-- move the current point a bit towards the previous and next. 
function Polyline:tuck( iterator, s, minSmoothAngle, maxSmoothAngle )
	for i, _ in iterator do
		local pp, cp, np = self[ i - 1 ], self[ i ], self[ i + 1 ]
		-- tuck points only when there is really a curve here
		-- but if this is a line, don't touch the ends
		if pp and np and 
			math.abs( self[ i ].deltaAngle ) > minSmoothAngle and
			math.abs( self[ i ].deltaAngle ) < maxSmoothAngle then
			-- mid point between the previous and next
			local midPNx, midPNy = getPointInTheMiddle( pp, np )
			-- vector from current point to mid point
			local mx, my = midPNx - cp.x, midPNy - cp.y
			-- move current point towards (or away from) the midpoint by the factor s
			self[ i ] = { x=cp.x + mx * s, y=cp.y + my * s }
		else
			self[ i ] = cp
		end
	end
	self:calculateData()
end

function Polyline:smooth( minSmoothAngle, maxSmoothAngle, order, from, to )
	if ( order <= 0  ) then
		return
	else
		local origSize = #self
		self:refine( self:iterator( from, to ), minSmoothAngle, maxSmoothAngle )
		-- if refine added waypoints we need to extend the range
		if to then to = to + #self - origSize end
		self:tuck( self:iterator( from, to ), 0.5, minSmoothAngle, maxSmoothAngle )
		self:tuck( self:iterator( from, to ), -0.15, minSmoothAngle, maxSmoothAngle )
		return self:smooth( minSmoothAngle, maxSmoothAngle, order - 1, from, to )
	end
end

--- In place translation
function Polyline:translate( dx, dy )
	for i, point in ipairs( self ) do
		point.x = point.x + dx
		point.y = point.y + dy
	end
	self:calculateData()
end

--- In place rotation
function Polyline:rotate( angle )
	local sin = math.sin( angle )
	local cos = math.cos( angle )
	for _, point in ipairs( self ) do
		point.x, point.y = point.x * cos - point.y  * sin, point.x * sin + point.y  * cos
	end
	self:calculateData()
end


function Polyline:space( angleThreshold, d )
	local i = 2
	while i < #self do
		local cp, pp = self[ i ], self[ i - 1 ]
		local isCurve = math.abs( getDeltaAngle( cp.nextEdge.angle, pp.nextEdge.angle )) > angleThreshold
		if getDistanceBetweenPoints( cp, pp ) > d or isCurve then
			i = i + 1
		else
			table.remove( self, i )
		end
	end
	self:calculateData()
end
-------------------------------------------------------------------------------

Polygon = {}
-- base class is the polyline
setmetatable( Polygon, { __index = Polyline })

Polygon.__index = function( t, k )
  if not rawget( t, k ) and type( k ) == "number" then
    -- roll over integer indexes
    return rawget( t, t:getIndex( k ))
  else
    return Polygon[ k ]
  end
end


--- Always return a valid index to allow iterating over
-- the beginning or end of a closed polygon.
function Polygon:getIndex( index )
  if index == 0 then
    return #self
  elseif index > #self then
    return index % #self
  elseif index > 0 then
    return index
  else
    return #self + index
  end
end

--- Iterate through elements of a polygon starting
-- between any from and to indexes with the given step.
-- This will do a full circle, that is, roll over from 
-- #polygon to 1 or 1 to #polygon if step < 0
function Polygon:iterator( from, to, step ) 
  local i = from or 1
  local n = to or #self
  local s = step or 1
  local lastOne = false
  return function()
    if ( not lastOne and #self > 0 ) then
      lastOne = ( i == n )
      local key, value = i, rawget( self, i )
      i = self:getIndex( i + s )
      return key, value
    end
  end
end
