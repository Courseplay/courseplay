lu = require("luaunit")
package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../course-generator/?.lua"
require('mock-GiantsEngine')
require('CpObject')
require('CourseManager')

-- clean up
local workingDir = io.popen"cd":read'*l'
os.execute('rmdir /s /q Courses')

------------------------------------------------------------------------------------------------------------------------
-- Directory
---------------------------------------------------------------------------------------------------------------------------

-- creates directory and figures out name correctly
local dir = Directory(workingDir .. '\\Courses')
assert(dir.name == 'Courses')
assert(dir:getFullPath() == workingDir .. '\\Courses')

-- create subdirectory
local test1 = dir:createDirectory('test1')
assert(test1.name == 'test1' )
assert(test1:getFullPath() == workingDir .. '\\Courses\\test1')
assert(test1:getParent() == dir)

-- create a file
os.execute('touch "' .. test1:getFullPath() .. '\\file1"')
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
local cm = CourseManager(workingDir .. '\\Courses')

assert(cm:getCurrentEntry() == 1)
assert(#cm:getEntries() == 2)

cm:setCurrentEntry(3)
assert(cm:getCurrentEntry() == 2)

cm:setCurrentEntry(-1)
assert(cm:getCurrentEntry() == 1)
