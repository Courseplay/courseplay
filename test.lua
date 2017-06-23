dofile( 'courseGenerator.lua' )
dofile( 'track.lua' )
dofile( 'file.lua' )
dofile( 'headland.lua' )
dofile( 'center.lua' )
dofile( 'geo.lua' )
dofile( 'bspline.lua' )
dofile( 'Pickle.lua' )

function eq( a, b )
  local epsilon = 0.00001
  return a < ( b + epsilon ) and a > ( b - epsilon )
end


pt = { 1, 2, 3, 4, 5 }
pt = reorderTracksForAlternateFieldwork( pt, 0 )
assert( pt[ 1 ] == 1 and pt[ 2 ] == 2 and pt[ 3 ] == 3 and pt[ 4 ] == 4 and pt[ 5 ] == 5 )
assert( #pt == 5 )

pt = { 1, 2, 3, 4, 5, 6 }
pt = reorderTracksForAlternateFieldwork( pt, 1 )
assert( pt[ 1 ] == 1 and pt[ 2 ] == 3 and pt[ 3 ] == 5 and pt[ 4 ] == 6 and pt[ 5 ] == 4 and pt[ 6 ] == 2 )
assert( #pt == 6 )

pt = { 1, 2, 3, 4, 5, 6 }
pt = reorderTracksForAlternateFieldwork( pt, 2 )
assert( pt[ 1 ] == 1 and pt[ 2 ] == 4 and pt[ 3 ] == 5 and pt[ 4 ] == 2 and pt[ 5 ] == 3 and pt[ 6 ] == 6 )
assert( #pt == 6 )

pt = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
pt = reorderTracksForAlternateFieldwork( pt, 1 )
assert( pt[ 1 ] == 1 and pt[ 2 ] == 3 and pt[ 3 ] == 5 and pt[ 4 ] == 7 and pt[ 5 ] == 9 and pt[ 6 ] == 11 )
assert( pt[ 7 ] == 10 and pt[ 8 ] == 8 and pt[ 9 ] == 6 and pt[ 10 ] == 4 and pt[ 11 ] == 2 )
assert( #pt == 11 )

pt = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
pt = reorderTracksForAlternateFieldwork( pt, 2 )
assert( pt[ 1 ] == 1 and pt[ 2 ] == 4 and pt[ 3 ] == 7 and pt[ 4 ] == 10 and pt[ 5 ] == 11 and pt[ 6 ] == 8 )
assert( pt[ 7 ] == 5 and pt[ 8 ] == 2 and pt[ 9 ] == 3 and pt[ 10 ] == 6 and pt[ 11 ] == 9 )
assert( #pt == 11 )

pt = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
pt = reorderTracksForAlternateFieldwork( pt, 3 )
assert( pt[ 1 ] == 1 and pt[ 2 ] == 5 and pt[ 3 ] == 9 and pt[ 4 ] == 10 and pt[ 5 ] == 6 and pt[ 6 ] == 2 )
assert( pt[ 7 ] == 3 and pt[ 8 ] == 7 and pt[ 9 ] == 11 and pt[ 10 ] == 8 and pt[ 11 ] == 4 )
assert( #pt == 11 )

--
--------------------------------------------------------------
-- Polygon iterator
--------------------------------------------------------------
t = { 1, 2, 3, 4 }
r = {}
for i, val in polygonIterator( t, 1, 4, 1 ) do
  table.insert( r, i ) 
end
assert( #r == #t )
assert( r[ 1 ] == 1, r[ 2 ] == 2, r[ 3 ] == 3, r[ 4 ] == 4 )

r = {}
for i, val in polygonIterator( t, 4, 1, -1 ) do
  table.insert( r, i ) 
end
assert( #r == #t )
assert( r[ 1 ] == 4, r[ 2 ] == 3, r[ 3 ] == 2, r[ 4 ] == 1 )

r = {}
for i, val in polygonIterator( t, 2, 1, 1 ) do
  table.insert( r, i ) 
end
assert( #r == #t )
assert( r[ 1 ] == 2, r[ 2 ] == 3, r[ 3 ] == 4, r[ 4 ] == 1 )

r = {}
for i, val in polygonIterator( t, 2, 3, -1 ) do
  table.insert( r, i ) 
end
assert( #r == #t )
assert( r[ 1 ] == 2, r[ 2 ] == 1, r[ 3 ] == 4, r[ 4 ] == 3 )

--------------------------------------------------------------
-- toPolar
--------------------------------------------------------------
a, l = toPolar( 3, 4 )
assert( l == 5, "Got " .. l  )
a, l = toPolar( -3, 4 )
assert( l == 5, "Got " .. l  )
assert( math.deg( toPolar( 1, 1 )) == 45)
assert( math.deg( toPolar( -1, 1 )) == 135)
assert( math.deg( toPolar( -1, -1 )) == -135)
assert( math.deg( toPolar( 1, -1 )) == -45)

assert( math.deg( toPolar( 1, 0 )) == 0)
assert( math.deg( toPolar( 0, 1 )) == 90)
assert( math.deg( toPolar( -1, 0 )) == 180 )
assert( math.deg( toPolar( 0, -1 )) == -90 )

--------------------------------------------------------------
-- addPolarVectorToPoint
--------------------------------------------------------------
epsilon = 0.001
point = { x = 1, y = 1 }
point = addPolarVectorToPoint( point, 0, 1 ) 
assert( point.x == 2 and point.y == 1, string.format( "Got %d, %d", point.x, point.y ))

point = { x = 0, y = 0 }
point = addPolarVectorToPoint( point, math.rad( 90 ), 1 )
assert( math.abs(point.x) < epsilon and point.y == 1, string.format( "Got %f, %f", point.x, point.y ))
point = { x = 0, y = 0 }
point = addPolarVectorToPoint( point, math.rad( 180 ), 1 )
assert( point.x == -1 and math.abs(point.y) < epsilon, string.format( "Got %f, %f", point.x, point.y ))
point = { x = 0, y = 0 }
point = addPolarVectorToPoint( point, math.rad( -90 ), 1 )
assert( math.abs(point.x) < epsilon and point.y == -1, string.format( "Got %f, %f", point.x, point.y ))

--------------------------------------------------------------
-- getAverageAngle
--------------------------------------------------------------
avg = math.deg( getAverageAngle( math.rad( 10 ), math.rad( 50 )))
assert( eq( avg, 30 ), "Got " ..  avg );
avg = math.deg( getAverageAngle( math.rad( -10 ), math.rad( -20 )))
assert( eq( avg, -15), "Got " ..  avg );
avg = math.deg( getAverageAngle( math.rad( -140 ), math.rad( 140 )))
assert( eq( avg, 180), "Got " ..  avg );
avg = math.deg( getAverageAngle( math.rad( -178 ), math.rad( 176 )))
assert( eq( avg, 179), "Got " ..  avg );
avg = math.deg( getAverageAngle( math.rad( -10 ), math.rad( 30 )))
assert( eq( avg, 10), "Got " ..  avg );
avg = math.deg( getAverageAngle( math.rad( -89 ), math.rad( 89 )))
assert( eq( avg, 0), "Got " ..  avg );
avg = math.deg( getAverageAngle( math.rad( -89 ), math.rad( 91 )))
assert( eq( avg, 1), "Got " ..  avg );

local t = { name='hello', loc = {{x=1,y=2},{x=3,y=4}}}

local f = io.output( "test.pickle" )
io.write( pickle( t )) 
io.close( f )

f = io.input( "test.pickle" )
local r = unpickle( io.read( "*all" ))
assert( r.loc[ 1 ].x == 1 and r.loc[ 1 ].y == 2 )
io.close( f )
os.execute( "del test.pickle" )


--------------------------------------------------------------
-- reverse table
--------------------------------------------------------------

t = { 1, 2, 3, 4 }
r = reverse( t )
assert( #r == #t )
assert( r[ 1 ] == 4, r[ 2 ] == 3, r[ 3 ] == 2, r[ 4 ] == 1 )

--------------------------------------------------------------
-- add point to ordered list
--------------------------------------------------------------
is = {}
p = {x=1}
addPointToListOrderedByX( is, p )
assert( #is == 1 )
assert( is[ 1 ].x == 1 )
p = {x=2}
addPointToListOrderedByX( is, p )
assert( #is == 2 )
assert( is[ 1 ].x == 1 and is[ 2 ].x == 2 )
p = {x=-2}
addPointToListOrderedByX( is, p )
assert( #is == 3 )
assert( is[ 1 ].x == -2 and is[ 2 ].x == 1 and is[ 3 ].x == 2 )
p = {x=1.5}
addPointToListOrderedByX( is, p )
assert( #is == 4 )
assert( is[ 1 ].x == -2 and is[ 2 ].x == 1 and is[ 3 ].x == 1.5 and is[ 4 ].x == 2 )

--------------------------------------------------------------
-- overlaps
--------------------------------------------------------------
t1 = { intersections={{ x=1 }, { x=4 }}}
t2 = { intersections={{ x=5 }, { x=6 }}}
assert( not overlaps( t1, t2 ))
assert( not overlaps( t2, t1 ))
t1 = { intersections={{ x=1 }, { x=4 }}}
t2 = { intersections={{ x=3 }, { x=6 }}}
assert( overlaps( t1, t2 ))
assert( overlaps( t2, t1 ))
t1 = { intersections={{ x=1 }, { x=4 }}}
t2 = { intersections={{ x=2 }, { x=3 }}}
assert( overlaps( t1, t2 ))
assert( overlaps( t2, t1 ))

nonConvexField = createRectangularPolygon( 0, 0, 200, 100, 5 )
-- so far it is convex, now make it non-convex
for i, point in ipairs( nonConvexField ) do
  if point.y == 0 and point.x >= 50 and point.x <= 150 then
    point.y = 50
  end
end
marks = {}
lines = {}
field = {}
field.boundary = nonConvexField
calculatePolygonData( field.boundary )
field.vehicle = { location = {x=-5, y=5}, heading = 0 }
field.nHeadlandPasses = 2
field.width = 3
generateCourseForField( field, 2, 3, true, field.vehicle.location, 0, 0, 0, 0.5, 30, false, true )
writeCourseToFile( field, "CoursePlay_Courses\\test\\course0101.xml" )
--------------------------------------------------------------
-- Smoke test
--------------------------------------------------------------

marks = {}
for i, fieldName in ipairs( { "pickles/8", "pickles/9", "pickles/23" }) do
  for width = 3, 6 do
    print( string.format( "\nGenerating course for field %s with width %d", fieldName, width ))
    local field = loadFieldFromPickle( fieldName )
    generateCourseForField( field, width, 5, false, field.vehicle.location, 0, 0, 0, 0.5, 30, false, false )
    generateCourseForField( field, width, 2, false, field.vehicle.location, 20, 1, 3, 0.5, 30, true, true )
    field = loadFieldFromPickle( fieldName .. "_reversed" )
    generateCourseForField( field, width, 5, true, field.vehicle.location, 0, 0, 0, 0.5, 30, false, false )
    generateCourseForField( field, width, 2, true, field.vehicle.location, 20, 1, 3, 0.5, 30, true, true )
  end
end


local fileName = "CoursePlay_Courses\\courseStorage0004.xml"

field = {}
field = loadFieldFromPickle("pickles/23")
field.nHeadlandPasses = 5
field.width = 4.4
field.isClockwise = "true"

generateCourseForField( field, field.width, field.nHeadlandPasses, false, field.vehicle.location, 0, 0, 0, 0.5, 30, false, false )
writeCourseToFile( field, fileName ) 
os.execute( "del " .. fileName )

testDir = "CoursePlay_Courses\\test\\"
managerFileName="courseManager.xml"

-- course creation based on existing courses
for selected = 1, 14 do 
  os.execute( "copy " .. testDir .. managerFileName .. " " .. testDir .. managerFileName .. ".orig" )
  managerFile = io.open( testDir .. managerFileName, "r" )
  savedCourses, nextFreeId, nextFreeSequence = getSavedCourses( managerFile )
  managerFile:close()
  oldCourse = savedCourses[ selected ]
  print( oldCourse.id, oldCourse.fileName )
  newCourse = { id=nextFreeId, 
                name= "(test) " .. oldCourse.name,
                parent=oldCourse.parent,
                fileName=string.format( "courseStorage%04d.xml", nextFreeSequence ),
                sequence=nextFreeSequence }
  copyCourse( testDir, oldCourse, newCourse, managerFileName ) 
  addCourseToManagerFile( testDir, managerFileName, newCourse)
  -- reread managerfile
  managerFile = io.open( testDir .. managerFileName, "r" )
  savedCourses, nextFreeId, nextFreeSequence = getSavedCourses( managerFile )
  managerFile:close()
  assert( #savedCourses == 15 )
  createdCourse = savedCourses[ 15 ]
  assert( createdCourse.id == newCourse.id and 
          createdCourse.fileName == newCourse.fileName and 
          createdCourse.sequence == newCourse.sequence and 
          createdCourse.parent == newCourse.parent )
  -- delete copied course file and restore the manager file
  os.execute( "del " .. testDir .. createdCourse.fileName )
  os.execute( "move " .. testDir .. managerFileName .. ".orig " .. testDir .. managerFileName  )

end
