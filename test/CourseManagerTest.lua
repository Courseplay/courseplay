lu = require("luaunit")
package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../course-generator/?.lua"
require('mock-GiantsEngine')
require('CpObject')
require('CourseManager')

-- clean up
local workingDir = io.popen"cd":read'*l'
os.execute('rmdir /s /q Courses')

-- creates directory and figures out name correctly
local dir = Directory(workingDir .. '\\Courses')
assert(dir.name == 'Courses')
assert(dir:getFullPath() == workingDir .. '\\Courses')

-- create subdirectory
local test1 = dir:mkdir('test1')
assert(test1.name == 'test1' )
assert(test1:getFullPath() == workingDir .. '\\Courses\\test1')

-- create a file
os.execute('touch "' .. test1:getFullPath() .. '\\file1"')
dir:refresh()
assert(dir.entries['test1'].entries['file1'].name == 'file1')
assert(test1.entries['file1'].name == 'file1')

local test2 = test1:mkdir('test2')
assert(test2.name == 'test2' )
os.execute('touch "' .. test2:getFullPath() .. '\\file1"')


print(dir)
