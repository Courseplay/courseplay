--require('mobdebug').start()

package.cpath = package.cpath .. ';C:/Users/nyovape1/AppData/Local/JetBrains/Toolbox/apps/IDEA-U/ch-0/211.6693.111.plugins/EmmyLua/classes/debugger/emmy/windows/x64/?.dll'
local dbg = require('emmy_core')
--dbg.tcpListen('localhost', 9966)
dbg.tcpConnect('localhost', 9966)


package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../course-generator/?.lua"

require("CpObject")
require('mock-GiantsEngine')
require('mock-Courseplay')
require("State3D")
require("HybridAStar")
require("JumpPoint")
require("BinaryHeap")
require("Dubins")
require("ReedsShepp")
require("ReedsSheppSolver")
require("settings")
require("courseGeneratorSettings")
require('TestPathfinderConstraints')

courseplay.globalCourseGeneratorSettings = SettingsContainer.createGlobalCourseGeneratorSettings()
courseplay.globalPathfinderSettings = SettingsContainer.createGlobalPathfinderSettings()

local obstacles = {
	{
		x1 = 113,
		y1 = 5,
		x2 = 115,
		y2 = 15
	},

	{
		x1 = 100,
		y1 = 15,
		x2 = 115,
		y2 = 17
	}
}

local mp = HybridAStar.JpsMotionPrimitives(3, 3, math.pi)
local constraints = TestPathfinderConstraints(obstacles)
local goal = State3D(120, 10, 0, 0)

local node = State3D(0, 0, 0)
local primitives = mp:getPrimitives(node, constraints)
for _, p in pairs(primitives) do
	local succ = mp:createSuccessor(node, p, 10, constraints, goal)
	print(tostring(succ))
	local next_primitives = mp:getPrimitives(succ, constraints)
	for _, p2 in pairs(next_primitives) do
		local succ2 = mp:createSuccessor(succ, p2, 10, goal)
		print('\t' .. tostring(succ2))
	end
end


local turnRadius = 5
local startHeading = 0 --math.pi

local scale, width, height = 5, 200, 100
local origin = {x = -width / 4, y = -height / 2}
local xOffset, yOffset = width / scale / 4, height / scale / 2

local start = State3D(0, 0, startHeading, 0)
local goal = State3D(120, 10, 0, 0)
local dubinsPath = {}
local pathFinder = HybridAStarWithJpsInTheMiddle(200, 100000)
local done, path

local vehicleData ={name = 'name', turnRadius = turnRadius, dFront = 3, dRear = 3, dLeft = 1.5, dRight = 1.5}
done, path = pathFinder:start(start, goal, vehicleData.turnRadius, true, constraints, 10)

print(done, path)
