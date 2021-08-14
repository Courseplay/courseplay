--require('mobdebug').start()
package.cpath = package.cpath .. ';C:/Users/nyovape1/AppData/Local/JetBrains/Toolbox/apps/IDEA-U/ch-0/211.7628.21.plugins/EmmyLua/classes/debugger/emmy/windows/x64/?.dll'
local dbg = require('emmy_core')
--dbg.tcpListen('localhost', 9966)
dbg.tcpConnect('localhost', 9966)


package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../course-generator/?.lua"

require("CpObject")
require('mock-GiantsEngine')
require('mock-Courseplay')
require("courseGenerator")
require("State3D")
require("HybridAStar")
require("BinaryHeap")
require("Dubins")
require("ReedsShepp")
require("ReedsSheppSolver")
require("settings")
require("courseGeneratorSettings")
require('TestPathfinderConstraints')
PathfinderConstraints = TestPathfinderConstraints
require("JumpPoint")

courseplay.globalCourseGeneratorSettings = SettingsContainer.createGlobalCourseGeneratorSettings()
courseplay.globalPathfinderSettings = SettingsContainer.createGlobalPathfinderSettings()

local obstacles = {
	{ x1 = 13, y1 = 100, x2 = 403, y2 = 120 },
	{ x1 = -10, y1 = 5, x2 = -60, y2 = 10 },
}
local fruit = {
	--{ x1 = 25, y1 = 5, x2 = 110, y2 = 25 },
	{ x1 = 80, y1 = 25, x2 = 325, y2 = 40 }
}

local mp = HybridAStar.JpsMotionPrimitives(3, 3, math.pi * 2)
local constraints = TestPathfinderConstraints(obstacles, fruit)
--PathfinderConstraints = {isValidNode = constraints.isValidNode}
local turnRadius = 5
local startHeading = 0 --math.pi

local scale, width, height = 5, 200, 100
local origin = {x = -width / 4, y = -height / 2}
local xOffset, yOffset = width / scale / 4, height / scale / 2

local start = State3D(0, 0, startHeading, 0)
local goal = State3D(11.42, 5.39, 0, 0)
local pathfinder = JumpPointSearch(200, 100000)
local done, path, goalNodeInvalid

done, path, goalNodeInvalid = pathfinder:findPath(start, goal, turnRadius, false, constraints, 10)

if path then
	State3D.printPath(path)
else
	print('No path found!')
end


--local node = State3D(0, 0, 0)
--local primitives = mp:getPrimitives(node, constraints)
--for _, p in pairs(primitives) do
--	local succ = mp:createSuccessor(node, p, 10, constraints, goal)
----	print(tostring(succ))
--	local next_primitives = mp:getPrimitives(succ, constraints)
--	for _, p2 in pairs(next_primitives) do
--		local succ2 = mp:createSuccessor(succ, p2, 10, constraints, goal)
----		print('\t' .. tostring(succ2))
--	end
--end


