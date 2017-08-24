-- http://stackoverflow.com/questions/29612584/creating-cubic-and-or-quadratic-bezier-curves-to-fit-a-path
--
-- insert a point in the middle of each edge.
function _refine( points, minSmoothAngle, maxSmoothAngle, isLine ) 
  local ix = function( a ) return getPolygonIndex( points, a ) end
  local refined = {}
  local rIx = 1;
  for i = 1, #points do 
    local point = points[ i ];
    refined[ rIx ] = point
    if points[ ix( i + 1 )] then 
      -- if this is a line, don't touch the ends
      if math.abs( points[ i ].deltaAngle ) > minSmoothAngle and 
         math.abs( points[ i ].deltaAngle ) < maxSmoothAngle and 
         (( not isLine ) or ( isLine and i > 1  and i < #points )) then
        -- insert points only when there is really a curve here
        -- table.insert( marks, points[ i ])
        local x, y =  getPointInTheMiddle( point, points[ ix( i + 1 )]);
        rIx = rIx + 1
        refined[ rIx ] = { x = x, y = y }
      end
    end
    rIx = rIx + 1;
  end
  return refined;
end

-- insert point in the middle of each edge and remove the old points.
function _dual( points ) 
  local ix = function( a ) return getPolygonIndex( points, a ) end
  local dualed = {}
  local index = 1
  for i = 1, #points do 
    local point = points[ i ];
    if points[ ix( index + 1 )] then
      x, y = getPointInTheMiddle( point, points[ ix( index + 1 )]);
      dualed[ index ] = { x = x, y = y }
    end
    index = index + 1;
  end
  return dualed;
end

-- move the current point a bit towards the previous and next. 
function _tuck( points, s, minSmoothAngle, maxSmoothAngle, isLine )
  local tucked = {}
  local index = 1
  local ix = function( a ) return getPolygonIndex( points, a ) end
  for i = 1, #points do 
    local pp, cp, np = points[ ix( i - 1 )], points[ ix( i )], points[ ix( i + 1 )]
    -- tuck points only when there is really a curve here
    -- but if this is a line, don't touch the ends
    if math.abs( points[ i ].deltaAngle ) > minSmoothAngle and 
       math.abs( points[ i ].deltaAngle ) < maxSmoothAngle and 
       ( not isLine or ( isLine and i > 1  and i < #points )) then
      -- mid point between the previous and next
      local midPNx, midPNy = getPointInTheMiddle( pp, np )
      -- vector from current point to mid point
      local mx, my = midPNx - cp.x, midPNy - cp.y
      -- move current point towards (or away from) the midpoint by the factor s
      tucked[ index ] = { x=cp.x + mx * s, y=cp.y + my * s }
    else
      tucked[ index ] = cp
    end
    index = index + 1
  end
  return tucked
end

function getPointInTheMiddle( a, b ) 
  return a.x + (( b.x - a.x ) / 2 ),
         a.y + (( b.y - a.y ) / 2 )
end

function smooth(points, minSmoothAngle, maxSmoothAngle, order, isLine )
  if ( order <= 0  ) then
    return points
  else
    local refined = _refine( points, minSmoothAngle, maxSmoothAngle, isLine )
    calculatePolygonData( refined )
    refined = _tuck( refined, 0.5, minSmoothAngle, maxSmoothAngle, isLine )
    calculatePolygonData( refined )
    refined = _tuck( refined, -0.15, minSmoothAngle, maxSmoothAngle, isLine )
    calculatePolygonData( refined )
    return smooth( refined, minSmoothAngle, maxSmoothAngle, order - 1, isLine )
  end
end
