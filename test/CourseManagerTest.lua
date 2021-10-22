lu = require("luaunit")
package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../course-generator/?.lua"
require('mock-GiantsEngine')
require('CpObject')
require('CourseManager')

-- clean up
local workingDir = io.popen"cd":read'*l'
deleteFolder(workingDir .. '\\modsSettings')
local coursesDir = 'modsSettings\\Courseplay\\Courses'
os.execute('mkdir ' .. coursesDir)
local mapCoursesDir = workingDir .. '\\' .. coursesDir .. '\\' .. g_currentMission.missionInfo.mapId
------------------------------------------------------------------------------------------------------------------------
-- Directory
------------------------------------------------------------------------------------------------------------------------

-- creates directory and figures out name correctly
local dir = Directory(mapCoursesDir)
print(dir.name)
assert(dir.name == g_currentMission.missionInfo.mapId)
assert(dir:getFullPath() == mapCoursesDir)

-- create subdirectory
local test1 = dir:createDirectory('test1')
assert(test1.name == 'test1' )
assert(test1:getFullPath() == mapCoursesDir .. '\\test1')
assert(test1:getParent() == dir)

-- create a file
os.execute('echo x > "' .. test1:getFullPath() .. '\\file1"')
dir:refresh()
assert(dir.entries['test1'].entries['file1'].name == 'file1')
assert(test1.entries['file1'].name == 'file1')
assert(test1.entries['file1']:getParent() == test1)

-- create another level of subdirectory
local test2 = test1:createDirectory('test2')
assert(test2.name == 'test2' )
assert(test2:getParent() == test1)

-- delete file
local file1FullPath = test1.entries['file1']:getFullPath()
assert(fileExists(file1FullPath))
test1:deleteFile('file1')
assert(test1.entries['file1'] == nil)
assert(not fileExists(file1FullPath))

os.execute('echo "" > "' .. dir:getFullPath() .. '\\file1"')
os.execute('echo "" > "' .. test1:getFullPath() .. '\\file1"')
os.execute('echo "" > "' .. test1:getFullPath() .. '\\file2"')
os.execute('echo "" > "' .. test1:getFullPath() .. '\\file3"')

os.execute('echo "" > "' .. test2:getFullPath() .. '\\file1"')
os.execute('echo "" > "' .. test2:getFullPath() .. '\\file2"')
dir:refresh()

------------------------------------------------------------------------------------------------------------------------
-- DirectoryView
------------------------------------------------------------------------------------------------------------------------
local dv = DirectoryView(dir)
local e = dv:getEntries()
assert(tostring(dv) == [[test1
file1
]])

assert(e[1]:isDirectory())
e[1]:unfold()
e = dv:getEntries()
assert(tostring(dv) == [[test1
  test2
  file1
  file2
  file3
file1
]])

e[2]:unfold()
e = dv:getEntries()
assert(tostring(dv) == [[test1
  test2
    file1
    file2
  file1
  file2
  file3
file1
]])

e[1]:fold()
assert(tostring(dv) == [[test1
file1
]])

------------------------------------------------------------------------------------------------------------------------
-- CourseManager
---------------------------------------------------------------------------------------------------------------------------
local cm = CourseManager(coursesDir)
assert(cm:getCurrentEntry() == 1)
assert(#cm:getEntries() == 2)

cm:setCurrentEntry(3)
assert(cm:getCurrentEntry() == 2)

cm:setCurrentEntry(-1)
assert(cm:getCurrentEntry() == 1)

cm:unfold(1)
assert(tostring(cm:getEntries()[2]) == FileSystemEntityView.indentString .. 'test2\n')

deleteFolder(mapCoursesDir)
cm:refresh()
print(tostring(cm.courseDirView))

assert(#cm:getEntries() == 0)

-- Migration
local folders = {
	{level = 1, id = 3, parent = 1, name = 'Level1-1'},
	{level = 0, id = 1, parent = 0, name = 'Level0-1'},
	{level = 0, id = 2, parent = 0, name = 'Level0-2'},
}

local courses = {
	{parent = 0, name = 'Course One'},
	{parent = 1, name = 'Course Two Under 0-1'},
	{parent = 2, name = 'Course Three Under 0-2'},
	{parent = 3, name = 'Course Four Under 1-1'},
}

-- mocking out everything for load/save XML courses in migrateOldCourses
loadXMLFile = noOp

-- this normally returns an XML handle which is used later in saveXMLFile. We just
-- return the full path, so when saveXMLFile is called with this, we know the file name.
createXMLFile = function(_, fullPath, _)
	return fullPath
end

-- instead of the original XML handle we get the full path returned by the mocked createXMLFile so we know
-- what file to create
saveXMLFile = function(fullPath)
	os.execute('echo x > "' .. fullPath .. '"')
end

MockCourse = CpObject()
function MockCourse:init()
	self.name = 'mock'
end
function MockCourse:setName(name)
	self.name = name
end
function MockCourse:getName()
	return self.name
end
function MockCourse:saveToXml()
end

Course = {}
Course.createFromXml = function () return MockCourse() end

cm:migrateOldCourses(folders, courses)
cm:refresh()
local entries = cm:getEntries()
assert(entries[1].name == 'Level0-1')
assert(entries[2].name == 'Level0-2')
assert(entries[3].name == 'Course One')
entries[1]:unfold()
entries = cm:getEntries()
assert(entries[2].name == 'Level1-1')
assert(entries[3].name == 'Course Two Under 0-1')
assert(entries[5].name == 'Course One')

-- no folders
deleteFolder(mapCoursesDir)
folders = {}
courses = {
	{parent = 0, name = 'Course One'},
	{parent = 0, name = 'Course Two'},
	{parent = 0, name = 'Course Three'},
	{parent = 0, name = 'Course Four'},
}
cm:migrateOldCourses(folders, courses)
cm:refresh()
entries = cm:getEntries()
assert(entries[1].name == 'Course Four')
assert(entries[4].name == 'Course Two')

-- no folders, no courses
deleteFolder(mapCoursesDir)
folders = {}
courses = {}
cm:migrateOldCourses(folders, courses)
cm:refresh()
entries = cm:getEntries()
assert(#entries == 0)