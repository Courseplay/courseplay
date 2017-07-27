--
-- Functions to manipulate tracks 
--
--

--- Generate course for a field.
-- The result will be:
--
-- field.headlandPath 
--   array of points containing all headland passes
--   
-- field.connectingTracks
--   this is the path from the end of the innermost headland track to the start
--   of the parallel tracks in the middle of the field and the connecting tracks
--   between the blocks in the center if the field is non-convex and has been split
--   into blocks
--
-- field.track
--   parallel tracks in the middle of the field.
--
-- field.course
--   all waypoints of the resulting course 
--
-- Input paramters:
--
-- implementWidth 
--   width of the implement
-- 
-- nHeadlandPasses 
--   number of headland passes to generate
--
-- headlandClockwise
--   headland track is clockwise when going inward if true, counterclockwise otherwise
--
-- headlandStartLocation
--   location anywhere near the field boundary where the headland should start.
--
-- overlapPercent 
--   headland pass overlap in percent, may reduce skipped fruit in corners
--
-- nTracksToSkip 
--   center tracks to skip. When 0, normal alternating tracks are generated
--   when > 0, intermediate tracks are skipped to allow for wider turns
--
-- extendTracks
--   extend center tracks into the headland (meters) to prevent unworked
--   triangles with long plows.
--
-- minDistanceBetweenPoints 
--   minimum distance allowed between vertices. Keeps the number of generated
--   vertices for headland passes low. For fine tuning only
--
-- angleThreshold
--   angle between two subsequent edges above which the smoothing kicks in.
--   This is to smooth corners in the headland
--
-- doSmooth
--   enable smoothing 
--
-- fromInside
--   calculate the headland tracks starting with the innermost one. This will first
--   generate the innermost headland track and then work outwards. If done this way,
--   there'll be no sharp corners in the headland tracks but the field corners will
--   be rounded.
--
function generateCourseForField( field, implementWidth, nHeadlandPasses, headlandClockwise, 
                                 headlandStartLocation, overlapPercent, 
                                 nTracksToSkip, extendTracks,
                                 minDistanceBetweenPoints, angleThreshold, doSmooth, fromInside )
  field.boundingBox = getBoundingBox( field.boundary )
  calculatePolygonData( field.boundary )
  field.headlandTracks = {}
  local previousTrack, startHeadlandPass, endHeadlandPass, step
  if fromInside then 
    courseGenerator.debug( "Generating innermost headland track" )
    local distanceOfInnermostHeadlandFromBoundary = ( implementWidth - implementWidth * overlapPercent / 100 ) * ( nHeadlandPasses - 1 ) + implementWidth / 2
    field.headlandTracks[ nHeadlandPasses ] = calculateHeadlandTrack( field.boundary, distanceOfInnermostHeadlandFromBoundary, 
                                                          minDistanceBetweenPoints, angleThreshold, 0, doSmooth, true ) 
    previousTrack = field.headlandTracks[ nHeadlandPasses ]
    startHeadlandPass = nHeadlandPasses - 1
    endHeadlandPass = 1
    step = -1
  else
    previousTrack = field.boundary
    startHeadlandPass = 1
    endHeadlandPass = nHeadlandPasses
    step = 1
  end
  for j = startHeadlandPass, endHeadlandPass, step do
    local width
    if j == 1 and not fromInside then 
      -- when working from inside, the half width is already factored in when
      -- the innermost pass is generated
      width = implementWidth / 2
    else 
      width = implementWidth
    end
    courseGenerator.debug( string.format( "Generating headland track #%d", j ))
    field.headlandTracks[ j ] = calculateHeadlandTrack( previousTrack, width - width * overlapPercent / 100, 
                                                        minDistanceBetweenPoints, angleThreshold, 0, doSmooth, not fromInside ) 
    previousTrack = field.headlandTracks[ j ]
  end
  linkHeadlandTracks( field, implementWidth, headlandClockwise, headlandStartLocation, doSmooth, angleThreshold )
  field.track = generateTracks( field.headlandTracks[ nHeadlandPasses ], implementWidth, nTracksToSkip, extendTracks )
  field.bestAngle = field.headlandTracks[ nHeadlandPasses ].bestAngle
  field.nTracks = field.headlandTracks[ nHeadlandPasses ].nTracks
  -- assemble complete course now
  field.course = {}
  if field.headlandPath then
    for i, point in ipairs( field.headlandPath ) do
      table.insert( field.course, point )
    end
  end
  if field.track then
    for i, point in ipairs( field.track ) do
      table.insert( field.course, point )
    end
  end
  if #field.course > 0 then
    calculatePolygonData( field.course )
    addTurnsToCorners( field.course, math.rad( 150 ))
  end
  -- flush STDOUT when not in the game for debugging
  if not courseGenerator.isRunningInGame() then
    io.stdout:flush()
  end
end


--- Reverse a course. This is to build a sowing/cultivating etc. course
-- from a harvester course.
-- We build our courses working from the outside inwards (harverster).
-- This function reverses that course so it can be used for fieldwork
-- starting in the middle of the course.
--
function reverseCourse( course )
  local result = {}
  -- remove any non-center track turns first
  removeHeadlandTurns( course )
  for i = #course, 1, -1 do
    local newPoint = copyPoint( course[ i ])
    -- reverse center track turns
    if newPoint.turnStart then
      newPoint.turnStart = nil
      newPoint.turnEnd = true
    elseif newPoint.turnEnd then
      newPoint.turnEnd = nil
      newPoint.turnStart = true
    end
    table.insert( result, newPoint )
  end
  -- regenerate non-center track turns for the reversed course
  calculatePolygonData( result )
  addTurnsToCorners( result, math.rad( 150 ))
  return result
end

-- Remove all turns inserted by addTurnsToCorners 
function removeHeadlandTurns( course )
  for i, p in ipairs( course ) do
    if p.headlandTurn then
      p.turnStart = nil
      p.turnEnd = nil
      p.text = nil
    end
  end
end

--- This makes sense only when these turns are implemented in Coursplay.
-- as of now, it'll generate nice turns only for 180 degree
function addTurnsToCorners( vertices, angleThreshold )
  -- start at the second wp to avoid having the first waypoint a turn start,
  -- that throws an nil in getPointDirection (due to the way calculatePolygonData 
  -- works, the prevEdge to the first point is bogus anyway)
  i = 2
  while i < #vertices - 1 do
    local cp = vertices[ i ]
    local np = vertices[ i + 1 ]
    if cp.prevEdge and np.nextEdge then
      -- start a turn at the current point only if the next one is not a start of the turn already
      -- and there really is a turn
      if not np.turnStart and not cp.turnStart and not cp.turnEnd and 
        math.abs( getDeltaAngle( np.nextEdge.angle, cp.prevEdge.angle )) > angleThreshold and
        math.abs( getDeltaAngle( np.nextEdge.angle, cp.nextEdge.angle )) > angleThreshold then
        cp.turnStart = true
        cp.headlandTurn = true
        cp.text = string.format( "turn start %.1f", math.deg( cp.nextEdge.angle ))
        np.turnEnd = true
        np.headlandTurn = true
        np.text = string.format( "turn end %.1f", math.deg( np.nextEdge.angle ))
        i = i + 2
      end
    end
    i = i + 1
  end
end
