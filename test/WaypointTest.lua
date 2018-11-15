--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]


lu = require("luaunit")
th = require("testhelper")
package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../course-generator/?.lua"
require("CpObject")
require("Waypoint")
require("geo")
require("courseGenerator")

TestCourse = {}

function TestCourse:setUp()
	self.waypoints = th.waypoints
end

function TestCourse:testAddWaypointAngles()
	local course = Course(nil, self.waypoints)
	lu.assertAlmostEquals(course.waypoints[1].angle, 90)
	lu.assertAlmostEquals(course.waypoints[2].angle, 0)
	lu.assertAlmostEquals(course.waypoints[3].angle, -90)
	lu.assertAlmostEquals(course.waypoints[4].angle, 180)
	lu.assertAlmostEquals(course.waypoints[5].angle, 180)
end

function TestCourse:testGetAverageSpeed()
	local course = Course(nil, self.waypoints)
	lu.assertAlmostEquals(course:getAverageSpeed(1, 3), 2, 0.1)
	lu.assertAlmostEquals(course:getAverageSpeed(2, 3), 3, 0.1)
	lu.assertAlmostEquals(course:getAverageSpeed(4, 3), 3.33, 0.1)
	lu.assertAlmostEquals(course:getAverageSpeed(5, 5), 3, 0.1)
end

lu.LuaUnit.run()




