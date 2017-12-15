--- An island in the field
--
Island = {}
Island.__index = Island

-- grid spacing used for island detection. Consequently, his will be the grid spacing 
-- of the island nodes.
Island.gridSpacing = 1

-- constructor
function Island:new( islandId ) 
	newIsland = {}
	setmetatable( newIsland, self )
  -- nodes of the island polygon
  newIsland.nodes = Polygon:new()
  newIsland.id = islandId
  newIsland.circled = false
  return newIsland
end

-- bypass types
Island.BYPASS_MODE_MIN = 1
Island.BYPASS_MODE_NONE = 1
Island.BYPASS_MODE_SIMPLE = 2
Island.BYPASS_MODE_CIRCLE = 3
Island.BYPASS_MODE_MAX = 3

Island.bypassModeText = {
	'COURSEPLAY_ISLAND_BYPASS_MODE_NONE',
	'COURSEPLAY_ISLAND_BYPASS_MODE_SIMPLE',
	'COURSEPLAY_ISLAND_BYPASS_MODE_CIRCLE' }

function Island.isTooCloseToAnyIsland( point, islandNodes, minDistance )
	for _, islandNode in ipairs( islandNodes ) do
		local d = getDistanceBetweenPoints( point, islandNode )
		if d < minDistance then
			return true
		end
	end
	return false
end

function Island.moveWaypointUntilFarEnoughFromIslands( wayPoint, angle, islandNodes, implementWidth )
	-- for now, only handle smaller islands, if we need to move too much than we give up
	-- try deviations up to six times of the work width.
	local lastOffset = 6 * implementWidth

	-- the turn start nodes point into the turn end node not in the direction of the 
	-- track so use the incoming edge's direction, otherwise we move the turn start
	-- wp in the wrong dir
	if wayPoint.turnStart then
		realWpAngle = wayPoint.prevEdge.angle
	else
		realWpAngle = wayPoint.nextEdge.angle
	end
	for offset = 1, lastOffset do
		local movedWaypoint = addPolarVectorToPoint( wayPoint, realWpAngle + angle, offset )
		if not Island.isTooCloseToAnyIsland( movedWaypoint, islandNodes, implementWidth / 2 ) then
			return movedWaypoint, offset
		end
	end
	-- just return the original waypoint if we weren't able to find one far enough
	return wayPoint, lastOffset
end

--- Attempt to bypass (smaller) islands in the field. This is used for Island.BYPASS_MODE_SIMPLE,
-- just moves the existing waypoints out of the island left or right.
function Island.bypassIslandNodes( course, width, islandNodes )
	-- current bypass direction. Needed so once we divert to a direction (left or right) then
	-- we stay on that side of the obstacle until we finish bypassing
	local bypassDirection = "None"
	for _, wayPoint in course:iterator() do
		if Island.isTooCloseToAnyIsland( wayPoint, islandNodes, width / 2 ) then
			-- so, we'll start walking to the left and to the right until we are at least 
			-- width / 2 distance from the island
			local movedWaypointToLeft, dLeft = Island.moveWaypointUntilFarEnoughFromIslands( wayPoint, math.rad( 90 ), islandNodes, width )
			local movedWaypointToRight, dRight = Island.moveWaypointUntilFarEnoughFromIslands( wayPoint, math.rad( -90 ), islandNodes, width )
			local movedWaypoint
			if bypassDirection == "None" then
				-- not yet bypassing, so take the direction which is closer to the original route
				-- TODO: this means we decide on left or right based on the first waypoint which is too
				-- close to the island. Should consider building both (left/right) bypasses and decide 
				-- later based on distance?
				movedWaypoint = dLeft < dRight and movedWaypointToLeft or movedWaypointToRight
				bypassDirection = dLeft < dRight and "Left" or "Right"
			else
				-- already started bypassing, so just stay on that side
				movedWaypoint = bypassDirection == "Left" and movedWaypointToLeft or movedWaypointToRight
			end
			wayPoint.x, wayPoint.y = movedWaypoint.x, movedWaypoint.y
			wayPoint.tooCloseToIsland = true
		else
			bypassDirection = "None"
		end
	end
end

function Island.showPassOrTrackNumber( p )
  if p.passNumber then return string.format( 'pass %d', p.passNumber ) end
  if p.trackNumber then return string.format( 'track %d', p.trackNumber ) end
end

function Island.findNodeWithinDistance( node, otherNodes, d )
  for i, otherNode in ipairs( otherNodes ) do
    if getDistanceBetweenPoints( node, otherNode ) < d then
      return i, otherNode
    end
  end
  return nil, nil
end

function Island.getNumberOfIslandNeighbors( point, islandNodes, gridSpacing )
  local nNeighbors = 0
  for _, islandNode in ipairs( islandNodes ) do
    local d = getDistanceBetweenPoints( point, islandNode )
    -- 1.5 is around sqrt( 2 ), to find diagonal neigbors too
    if d < 1.5 * gridSpacing then
      nNeighbors = nNeighbors + 1
    end
  end
  return nNeighbors
end

function Island.getIslandPerimeterNodes( islandNodes )
  local perimeterNodes = {}
  for _, islandNode in ipairs( islandNodes ) do
    -- a node on the perimeter has at least two non-island neigbors (out of the possible
    -- 8 neighbors at most 6 can be island nodes). 
    if Island.getNumberOfIslandNeighbors( islandNode, islandNodes, Island.gridSpacing ) <= 6 then
      table.insert( perimeterNodes, islandNode )
    end
  end
  return perimeterNodes
end

--- Accepts a list of perimeter nodes and creates an island 
-- polygon. The list may define multiple islands, in that
-- case, it creates one island, removing the nodes used 
-- for that island from perimeterNodes and returns the
-- remaining nodes.
function Island:createFromPerimeterNodes( perimeterNodes )
  if #perimeterNodes < 1 then return perimeterNodes end
  local currentNode = perimeterNodes[ 1 ]
  table.insert( self.nodes, currentNode )
  table.remove( perimeterNodes, 1 )
  local ix, otherNode 
  otherNode = currentNode
  while otherNode do
    -- find the next node, try closest first. 3.01 so it is guaranteed to be closer than 3 * gridSpacing
    for _, d in ipairs({ self.gridSpacing * 1.01, 1.5 * self.gridSpacing, 2.3 * self.gridSpacing, 3.01 * self.gridSpacing }) do
      ix, otherNode = Island.findNodeWithinDistance( currentNode, perimeterNodes, d )
      if ix then
        table.insert( self.nodes, otherNode )
        table.remove( perimeterNodes, ix )
        -- next node found, continue from that node
        currentNode = otherNode
        break
      end
    end
  end
  self.nodes:calculateData()
  self.width = self.nodes.boundingBox.maxX - self.nodes.boundingBox.minX
  self.height = self.nodes.boundingBox.maxY - self.nodes.boundingBox.minY
  courseGenerator.debug( "Island #%d with %d nodes created, %.0fx%0.f, area %.0f", self.id, #self.nodes, self.width, self.height, self.nodes.area )
end 

--- Does the line from pointA to pointB intersect this island?
function Island:intersects( pointA, pointB )
  return getAllIntersectionsOfLineAndPolygon( self.headlandTracks[ 1 ], pointA, pointB )
end

function Island:generateHeadlands( nHeadlandPasses, implementWidth, minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, doSmooth )
  local previousHeadland = self.nodes
  self.headlandTracks = {}
  -- we need at least one headland track around the island but don't think more than 3 makes sense
  nHeadlandPasses = math.min( math.max( nHeadlandPasses, 1 ), 3 )
  for i = 1, nHeadlandPasses do
    local width = i == 1 and implementWidth / 2 or implementWidth 
    self.headlandTracks[ i ] = calculateHeadlandTrack( previousHeadland, width, 
      minDistanceBetweenPoints, minSmoothAngle, maxSmoothAngle, 0, doSmooth, false )
    courseGenerator.debug( "Generated headland track #%d, area %.1f, clockwise = %s for island %s", i, self.headlandTracks[ i ].area, 
      tostring( self.headlandTracks[ i ].isClockwise ), self.id )
    previousHeadland = self.headlandTracks[ i ]
  end
end

--- Insert a waypoint into course at ix, using the coordinates from wp
-- but all other properties from sampleWp
function Island:insertWaypoint( course, ix, wp, sampleWp )
  courseGenerator.debug( "Island %d: adding a waypoint (%.1f, %.1f) at %d.",
    self.id, wp.x, wp.y, ix )
  table.insert( course, ix, wp )
  course[ ix ].trackNumber = sampleWp.trackNumber
  course[ ix ].passNumber = sampleWp.passNumber
end

--- Find where a part of a course (anywhere beyond startIx) intersects the 
-- section between p1 and p2.
function Island:getIntersectionWithCourse( course, startIx, p1, p2 )
  for i = startIx, #course - 1 do
    local c1, c2 = course[ i ], course[ i + 1 ]
    local intersectionPoint = getIntersection( c1.x, c1.y, c2.x, c2.y, p1.x, p1.y, p2.x, p2.y )
    if intersectionPoint then
      --courseGenerator.debug( "Island %d: headland intersects at wp %d ", self.id, i )
      if course[ startIx ].passNumber and course[ i ].passNumber and 
          course[ startIx ].passNumber == course[ i ].passNumber then
        courseGenerator.debug( "Island %d: headland intersects pass number %d at wp %d again.", self.id, 
          course[ i ].passNumber, i )
        return i, intersectionPoint
      end
      if course[ startIx ].trackNumber and course[ i ].trackNumber and
          course[ startIx ].trackNumber == course[ i ].trackNumber then
        courseGenerator.debug( "Island %d: headland intersects track number %d at wp %d again.", self.id, 
          course[ i ].trackNumber, i )
        return i, intersectionPoint
      end
    end   
  end
  return nil, nil
end

--- TODO: Add all the original properties of the course waypoints to the
-- newly created bypass waypoints.
-- TODO: Also, add missing turnStart/turnEnd properties
function Island:decorateBypassWaypoints( course )
  -- calculate point attributes, especially the radius
  course:calculateData()
  for _, p in course:iterator() do
    p.islandBypass = true
  end
end

--- Find the spot where this track (up/down row or headland) meets again the
-- first headland and assemble a course to there from course[ startIx ]
-- @param startIx index of course waypoint where it intersects the headland
-- @param fromIx 
-- @param toIx course intersected the headland polygon between the indexes fromIx-toIx 
function Island:bypassOnHeadland( course, startIx, fromIx, toIx, doCircle, doSmooth )
  -- walk around the island on the  headland until we meet the course again.
  -- we can start walking either at fromIx or at toIx, that is to go left or right
  -- (don't know which one is left or right but that is not relevant)
  local pathA, pathB = Polyline:new(), Polyline:new()
  -- index of course waypoint andintersection point where we again met it
  local returnIxA, returnIxB, intersectionA, intersectionB
  local dA, dB = 0, 0
  
  -- if we want a circle around the island before bypassing...
  if not self.circled and doCircle then
    self.circled = true
    -- create the waypoints for the circle around the island.
    courseGenerator.debug( "Island %d: circle around first", self.id )
    for _, cp in self.headlandTracks[ 1 ]:iterator( toIx, fromIx, 1 ) do
      table.insert( pathA, cp )
    end
    for _, cp in self.headlandTracks[ 1 ]:iterator( fromIx, toIx, -1 ) do
      table.insert( pathB, cp )
    end
  end
  -- try path A first, going around from toIx to fromIx 
  for i, cp in self.headlandTracks[ 1 ]:iterator( toIx, fromIx, 1 ) do
    table.insert( pathA, cp )
    dA = dA + cp.nextEdge.length
    local np = self.headlandTracks[ 1 ][ i + 1 ]
    -- does this section of headland intersects the course and where?
    returnIxA, intersectionA = self:getIntersectionWithCourse( course, startIx + 1, cp, np )
    if returnIxA then break end
  end
  -- now try path B, going around from fromIx to toIx 
  for i, cp in self.headlandTracks[ 1 ]:iterator( fromIx, toIx, -1 ) do
    table.insert( pathB, cp )
    dB = dB + cp.nextEdge.length
    local np = self.headlandTracks[ 1 ][ i - 1 ]
    -- does this section of headland intersects the course and where?
    returnIxB, intersectionB = self:getIntersectionWithCourse( course, startIx + 1, cp, np )
    if returnIxB then break end
  end
  courseGenerator.debug( "Island %d: path A %.0f m, path B %0.f m", self.id, dA, dB )
  -- now pick the shortest path
  local returnIx = dA < dB and returnIxA or returnIxB
  local path = dA < dB and pathA or pathB
  self:decorateBypassWaypoints( path )
  if returnIx then
    local removeFrom, insertAt = startIx + 1, startIx
	  if course:hasTurnWaypoint( course:iterator( removeFrom, returnIx )) then
		  -- we don't really know what to do if there are turn waypoints on the island, so
		  -- just don't change anything in that case
		  courseGenerator.debug( "Island %d: Course has turn start or end waypoints between %d-%d, no bypass", self.id, removeFrom, returnIx )
	  else
		  -- local removeFrom, insertAt = startIx, startIx - 1 -- if we don't want to have the intersection point in the course
		  -- remove original course waypoints
		  courseGenerator.debug( "Island %d: Removing original waypoints (on the island) %d-%d", self.id, removeFrom, returnIx )
		  for i = removeFrom, returnIx do
			  table.remove( course, removeFrom )
		  end
		  -- add the headland waypoints instead
		  courseGenerator.debug( "Island %d: Adding %d headland path waypoints around the island starting at %d", self.id,
		    #path, insertAt )
		  for i, p in ipairs( path ) do
			  self:insertWaypoint( course, insertAt + i, p, course[ removeFrom - 1 ])
		  end
		  local origLength = #course
		  if doSmooth then
			  course:smooth( math.rad( 20 ), math.rad( 120 ), 2, startIx - 1, startIx + #path + 1 )
		  end 
		  -- continue after the inserted headland piece (just need to adjust 
		  -- the length as smooth may have added waypoints
			return startIx + #path + #course - origLength
	  end
  end
  -- nothing changed, continue
  return startIx
end

--- Adjust course to bypass this island. Used for Island.BYPASS_MODE_CIRCLE. 
-- this will bypass the island on a headland generated around it.
-- @param doCircle drive a full circle around the island when first hit.
function Island:bypass( course, doCircle, doSmooth)
  local enterIntersection, exitIntersection, enterIx
  local ix = 1
  while ix < #course - 1 do
    local intersections = self:intersects( course[ ix ], course[ ix + 1 ])
    if #intersections > 0 then
      -- First intersection with the island. 
      if marks then table.insert( marks, intersections[ 1 ].point ) end
      courseGenerator.debug( "Island %d: Intersection headland #1 and %s at course waypoint %d-%d", self.id, 
        self.showPassOrTrackNumber( course[ ix ]), ix, ix + 1 )
      self:insertWaypoint( course, ix + 1, intersections[ 1 ].point, course[ ix ])
      if #intersections == 2 then
        -- course enters and leaves the island between two waypoints, so 
        -- add here a waypoint for the exit too
        self:insertWaypoint( course, ix + 2, intersections[ 2 ].point, course[ ix ])
      end
	    local startIx = ix + 1
      ix = self:bypassOnHeadland( course, startIx, intersections[ 1 ].fromIx, intersections[ 1 ].toIx, doCircle, doSmooth )
    end
    ix = ix + 1
  end
end