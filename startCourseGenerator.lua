--- Find saved Courseplay fieldwork courses, prompt the user
--  to select one to optimize.
--  Create a copy of the selected course, enter it into the courseManager.xml
--  file and then open the course generator with the copied course.
--
--  There, you can set course generation paramteres, generate and check the 
--  course and finally, save it.
--
--  The new course should be available in the game, with the name
--  (Customized) original name
--
dofile( 'file.lua' )
dofile( 'geo.lua' )

-- generated courses will be prefixed with this string
prefix="(Customized)"

managerFilename="courseManager.xml"
careerSavegameFilename="careerSavegame.xml"
courseplayCustomFieldsFilename="courseplayCustomFields.xml"

function getSelection( tab )
  while true do
    local selection = tonumber( io.stdin:read())
    if selection == 0 then return nil end
    if tab[ selection ] ~= nil then
      return selection 
    end
  end
end

if not arg[ 1 ] then 
  print( "Usage: lua startCourseGenerator.lua <courseplay save directory for a map | savegame directory>")
  return 
end

dir =  arg[ 1 ] 

-- see if we were given a savegame directory 
careerFile = io.open( dir .."\\" .. careerSavegameFilename )
if careerFile then
  -- yes, we'll work with saved fields then.
  useSavedFields = true
  -- then find the CP course directory based on that
  mapId = getMapId( careerFile )
  careerFile:close()
  courseDir = dir .. "\\..\\CoursePlay_Courses\\" .. mapId 
  print( string.format( "This is a savedir for map %s, will save generated course to %s", mapId, courseDir ))

else
  -- we only have a CP course directory, we'll work with saved courses
  useSavedFields = false
  courseDir = dir
end

-- gather a list of saved courses
managerFileFullPath = courseDir .. "\\" .. managerFilename
managerFile = io.open( managerFileFullPath, "r" )
if not managerFile then
  print( string.format( "Can't open %s.", managerFileFullPath ))
  return
end
savedCourses, nextFreeId, nextFreeSequence = getSavedCourses( managerFile )
managerFile:close()

print()

if useSavedFields then
  print( "Select the saved field you want to use for the course generation:\n" )
  -- using saved fields, prompt the user for the field to use and a name for the course.
  savedFields = loadSavedFields( dir .. "\\" .. courseplayCustomFieldsFilename  )
  for i, field in ipairs( savedFields ) do
    print( string.format( " [ %d ] - Field '%d'", i, field.number ))
  end
  print( string.format( "\nEnter number ( %d - %d ) for the selected field or 0 (zero) to exit\n", 1, #savedFields ))
  io.flush()
  selectedFieldIndex = getSelection( savedFields )
  -- save in the root folder (except when later an existing target course is selected) 
  newParent=0
  if not selectedFieldIndex then return end
else
  -- select an existing course. 
  print( "Select the saved course you want to use as the basis the course generation:\n" )
  -- using saved course, prompt the user to select a course
  for id, course in pairs( savedCourses ) do
    print( string.format( " [ %d ] - '%s' (%s)", course.sequence, course.name, course.fileName ))
  end
  print( string.format( "\nEnter number ( %d - %d ) for the selected course or 0 (zero) to exit\n", 1, #savedCourses ))
  io.flush()
  selectedOldCourseSequence = getSelection( savedCourses )
  -- save in the same folder
  newParent = savedCourses[ selectedOldCourseSequence ].parent
  if not selectedOldCourseSequence then return end
end

print( "\nNow select where you want to save the new course:\n" )
-- list existing courses
for id, course in pairs( savedCourses ) do
  print( string.format( " [ %d ] - '%s' (%s)", course.sequence, course.name, course.fileName ))
end
print( string.format( "\nEnter number ( %d - %d ) for the selected course or 0 to create a new course\n", 1, #savedCourses ))
io.flush()
selectedNewCourseSequence = getSelection( savedCourses )

-- now prepare a new course when needed
local newCourse = {}

if not selectedNewCourseSequence then
  -- creating a new course
  print( string.format( "Enter a name for the new course:\n" ))
  io.flush()
  newCourseName = io.stdin:read()
  newCourse = { id=nextFreeId, 
                name= newCourseName,
                parent=newParent,
                fileName=string.format( "courseStorage%04d.xml", nextFreeSequence ),
                sequence=nextFreeSequence }
else
  -- no new course, overwriting an existing one
  if string.match( savedCourses[ selectedNewCourseSequence ].name, prefix ) then
    newCourseName = savedCourses[ selectedNewCourseSequence ].name
  else
    newCourseName = prefix .. savedCourses[ selectedNewCourseSequence ].name
  end
  newCourse = savedCourses[ selectedNewCourseSequence ]
end

-- final confirmation
print( string.format( "Is it ok to create/overwrite '%s' (%s)? [y/n]" , newCourse.name, newCourse.fileName ))
io.flush()
local answer = io.stdin:read()
if answer ~= "y" and answer ~= "Y" then
  return
end

-- create basis of new course
if useSavedFields then
  -- new course based on saved field
  writeSavedFieldToCourseFile( savedFields[ selectedFieldIndex ], courseDir .. "\\" .. newCourse.fileName )
else
  -- new course based on saved course
  if selectedOldCourseSequence ~= selectedNewCourseSequence then
    -- not overwriting the old one
    copyCourse( dir, savedCourses[ selectedOldCourseSequence ], newCourse, managerFilename )
  end
end

-- not overwriting an existing one
if not selectedNewCourseSequence then
  addCourseToManagerFile( courseDir, managerFilename, newCourse)
end

-- finally, start the course generator with the new saved course file
if useSavedFields then
  os.execute( 'LOVE\\love.exe . fromField "' .. courseDir .. "\\" .. newCourse.fileName .. '"' )
else
  os.execute( 'LOVE\\love.exe . fromCourse "' .. courseDir .. "\\" .. newCourse.fileName .. '"' )
end
