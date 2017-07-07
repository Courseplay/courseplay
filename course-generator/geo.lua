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
  for i, vertex in ipairs( polygon ) do
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
--- Get the average of two angles. 
-- Works fine even for the transition from -pi/2 to +pi/2
function getAverageAngle( a1, a2 )
  -- convert the 0 - -180 range into 180 - 360
  if math.abs( a1 - a2 ) > math.pi then
    if a1 < 0 then a1 = 2 * math.pi + a1 end
    if a2 < 0 then a2 = 2 * math.pi + a2 end
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
    if a1 < 0 then a1 = 2 * math.pi + a1 end
    if a2 < 0 then a2 = 2 * math.pi + a2 end
  end
  -- calculate difference in this range
  return a2 - a1
end

--- This is kind of a low pass filter. If the 
-- direction change to the  next point is too big, 
-- the last point is removed
-- If the distance to the next point is less than distanceThreshold,
-- the current point is removed and the next one is replaced with a 
-- point between the current and the next.
function applyLowPassFilter( polygon, angleThreshold, distanceThreshold, isLine )
  local ix = function( a ) return getPolygonIndex( polygon, a ) end
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
    local cp, np = polygon[ ix( index )], polygon[ ix( index + 1 )]
    -- need to recalculate the edge length as we are moving points 
    -- around here
    local angle, length = toPolar( np.x - cp.x, np.y - cp.y )
    local isTooClose = length < distanceThreshold
    local isTooSharp = math.abs( getDeltaAngle( np.prevEdge.angle, cp.prevEdge.angle )) > angleThreshold 
    if isTooClose or isTooSharp then
      -- replace current and next point with something in the middle
      polygon[ ix( index + 1 )].x, polygon[ ix( index + 1 )].y = getPointInTheMiddle( cp, np )
    end
    if isTooSharp or isTooClose then
      table.remove( polygon, ix( index ))
      calculatePolygonData( polygon )
    else
      index = index + 1
    end
  until index > #polygon
end

--- make sure points in line are at least d apart
-- except in curves 
function space( line, angleThreshold, d )
  local result = { line[ 1 ]}
  for i = 2, #line do
    local cp, pp = line[ i ], result[ #result ]
    local isCurve = math.abs( getDeltaAngle( cp.prevEdge.angle, pp.prevEdge.angle )) > angleThreshold 
    if getDistanceBetweenPoints( cp, pp ) > d or isCurve then
      table.insert( result, cp ) 
    end
  end
  return result
end

function calculatePolygonData( polygon )
  local ix = function( a ) return getPolygonIndex( polygon, a ) end
  local directionStats = {}
  local dAngle = 0
  local shortestEdgeLength = 1000
  for i, point in ipairs( polygon ) do
    local pp, cp, np = polygon[ ix( i - 1 )], polygon[ ix( i )], polygon[ ix( i + 1 )]
    -- vector from the previous to the next point
    local dx = np.x - pp.x 
    local dy = np.y - pp.y
    local angle, length = toPolar( dx, dy )
    polygon[ i ].tangent = { angle=angle, length=length, dx=dx, dy=dy }
    -- vector from the previous to this point
    dx = cp.x - pp.x
    dy = cp.y - pp.y
    angle, length = toPolar( dx, dy )
    polygon[ i ].prevEdge = { from={ x=pp.x, y=pp.y} , to={ x=cp.x, y=cp.y }, angle=angle, length=length, dx=dx, dy=dy }
    -- vector from this to the next point 
    dx = np.x - cp.x
    dy = np.y - cp.y
    angle, length = toPolar( dx, dy )
    polygon[ i ].nextEdge = { from = { x=cp.x, y=cp.y }, to={x=np.x, y=np.y}, angle=angle, length=length, dx=dx, dy=dy }
    if length < shortestEdgeLength then shortestEdgeLength = length end
    -- detect clockwise/counterclockwise direction 
    if pp.prevEdge and cp.prevEdge then
      if pp.prevEdge.angle and cp.prevEdge.angle then
        dAngle = dAngle + getDeltaAngle( cp.prevEdge.angle, pp.prevEdge.angle )
      end
    end
    addToDirectionStats( directionStats, angle, length )
  end
  polygon.directionStats = directionStats
  polygon.bestDirection = getBestDirection( directionStats )
  polygon.isClockwise = dAngle > 0
  polygon.shortestEdgeLength = shortestEdgeLength
  polygon.boundingBox = getBoundingBox( polygon )
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
    toIx = getIndexInDistance( polygon, i, d )
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


-- Find the index of the vertex in d distance
-- from startIx of a polygon
--
function getIndexInDistance( polygon, fromIx, distance )
  local d = 0
  local toIx = fromIx
  while ( toIx < #polygon and d < distance ) do 
    d = d + polygon[ toIx ].nextEdge.length  
    toIx = toIx + 1
  end
  return toIx
end


function addToDirectionStats( directionStats, angle, length )
  local width = 10 
  local range = math.floor( math.deg( angle ) / width ) * width + width / 2
  if directionStats[ range ] then  
    directionStats[ range ].length = directionStats[ range ].length + length
    table.insert( directionStats[ range ].dirs, math.deg( angle ))
  else
    directionStats[ range ] = { length=0, dirs={}}
  end
end

--- Trying to figure out in which direction 
-- the field is the longest.
function getBestDirection( directionStats )
  local best = { range = 0, length = 0 }
  for range, stats in pairs( directionStats ) do
    if stats.length > best.length then 
      best.length = stats.length
      best.range = range
    end
  end
  local sum = 0
  if directionStats[ best.range ] then
    for i, dir in ipairs( directionStats[ best.range ].dirs ) do
      sum = sum + dir
    end
    best.dir = math.floor( sum / #directionStats[ best.range ].dirs)
  end
  return best
end

--- Iterate through an elements of a polygon starting
-- between any from and to indexes with the given step.
-- This will do a full circle, that is roll over from 
-- #polygon to 1 or 1 to #polygon if step < 0
--
function polygonIterator( polygon, from, to, step )
  local i = from
  local lastOne = false
  return function()
           if ( not lastOne ) then
             lastOne = ( i == to )
             local index, value = i, polygon[ i ] 
             i = getPolygonIndex( polygon, i + step )
             return index, value
           end
         end
end

--- handle negative indices by circling back to 
-- the end of the polygon
function getPolygonIndex( polygon, index )
  if index > #polygon then
    return index - #polygon
  elseif index > 0 then
    return index
  elseif index == 0 then
    return #polygon
  else
    return #polygon + index 
  end
end

-- Does the line defined by p1 and p2 intersect the polygon?
-- If yes, return two indices. The line intersects the polygon between
-- these two indices
function getIntersectionOfLineAndPolygon( polygon, p1, p2 ) 
  local ix = function( a ) return getPolygonIndex( polygon, a ) end
  -- loop through the polygon and check each vector from 
  -- the current point to the next
  for i, cp in ipairs( polygon ) do
    local np = polygon[ ix( i + 1 )] 
    if getIntersection( cp.x, cp.y, np.x, np.y, p1.x, p1.y, p2.x, p2.y ) then
      -- the line between p1 and p2 intersects the vector from cp to np
      return i, ix( i + 1 )
    end
  end
  return nil, nil
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
  --print( ab.from.x, ab.from.y, ab.to.x, ab.to.y,
   --                           cd.from.x, cd.from.y, cd.to.x, cd.to.y )
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

function getBoundingBox( polygon )
  local minX, maxX, minY, maxY = 10000, -10000, 10000, -10000
  for i, point in ipairs( polygon ) do
    if ( point.x < minX ) then minX = point.x end
    if ( point.y < minY ) then minY = point.y end
    if ( point.x > maxX ) then maxX = point.x end
    if ( point.y > maxY ) then maxY = point.y end
  end
  return { minX=minX, maxX=maxX, minY=minY, maxY=maxY }
end 

function translatePoints( points, dx, dy )
  local result = {}
  for i, point in ipairs( points ) do
    local newPoint = copyPoint( point )
    newPoint.x = points[ i ].x + dx
    newPoint.y = points[ i ].y + dy 
    table.insert( result, newPoint )
  end
  return result
end

function rotatePoints( points, angle )
  local result = {}
  local sin = math.sin( angle )
  local cos = math.cos( angle )
  for i, point in ipairs( points ) do
    local newPoint = copyPoint( point )
    newPoint.x = points[ i ].x * cos - points[ i ].y  * sin
    newPoint.y = points[ i ].x * sin + points[ i ].y  * cos
    table.insert( result, newPoint )
  end
  result.boundingBox = getBoundingBox( result )
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

function getInwardDirection( isClockwise )
  if isClockwise then
    return - math.pi / 2 
  else
    return math.pi / 2
  end
end

function getOutwardDirection( isClockwise )
  return - getInwardDirection( isClockwise )
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

--- Less than operator with limited precision
-- to tolerate floating point precision errors
function lt( a, b )
  -- for courseplay, we are calculating in meters, so 
  -- we are fine with one millimeter precision
  local epsilon = 0.001
  return a < ( b - epsilon )
end
