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
require("test.mock-Courseplay")
require("test.mock-GiantsEngine")
require("CpObject")
require("Waypoint")
require("geo")
require("courseGenerator")
require("helpers")

TestPoint = {}

function TestPoint:testWorldToLocal()
	local EPS = 0.001

	local p = Point(0, 0, 0)
	local x, z = p:worldToLocal(0,0)
	lu.assertEquals(x, 0)
	lu.assertEquals(z, 0)
	x, z = p:localToWorld(x, z)
	lu.assertEquals(x, 0)
	lu.assertEquals(z, 0)


	p = Point(0, 0, math.pi / 2)
	x, z = p:worldToLocal(0,0)
	lu.assertEquals(x, 0)
	lu.assertEquals(z, 0)
	x, z = p:localToWorld(x, z)
	lu.assertEquals(x, 0)
	lu.assertEquals(z, 0)

	p = Point(3, 4, 0)
	x, z = p:worldToLocal(0, 0)
	lu.assertEquals(x, -3)
	lu.assertEquals(z, -4)
	x, z = p:localToWorld(x, z)
	lu.assertEquals(x, 0)
	lu.assertEquals(z, 0)

	p = Point(1, 2, 0)
	x, z = p:worldToLocal(3, 4)
	lu.assertEquals(x, 2)
	lu.assertEquals(z, 2)
	x, z = p:localToWorld(x, z)
	lu.assertEquals(x, 3)
	lu.assertEquals(z, 4)

	p = Point(0, 0, 2 * math.pi)
	x, z = p:worldToLocal(3, 4)
	lu.assertAlmostEquals(x, 3, EPS)
	lu.assertAlmostEquals(z, 4, EPS)
	x, z = p:localToWorld(x, z)
	lu.assertAlmostEquals(x, 3, EPS)
	lu.assertAlmostEquals(z, 4, EPS)

	p = Point(0, 0, math.pi)
	x, z = p:worldToLocal(3, 4)
	lu.assertAlmostEquals(x, -3, EPS)
	lu.assertAlmostEquals(z, -4, EPS)
	x, z = p:localToWorld(x, z)
	lu.assertAlmostEquals(x, 3, EPS)
	lu.assertAlmostEquals(z, 4, EPS)

	p = Point(0, 0, math.pi / 2)
	x, z = p:worldToLocal(3, 4)
	lu.assertAlmostEquals(x, -4, EPS)
	lu.assertAlmostEquals(z, 3, EPS)
	x, z = p:localToWorld(x, z)
	lu.assertAlmostEquals(x, 3, EPS)
	lu.assertAlmostEquals(z, 4, EPS)

	p = Point(0, 0, math.pi / 4)
	x, z = p:worldToLocal(1, 1)
	lu.assertAlmostEquals(x, 0, EPS)
	lu.assertAlmostEquals(z, math.sqrt(2), EPS)
	x, z = p:localToWorld(x, z)
	lu.assertAlmostEquals(x, 1, EPS)
	lu.assertAlmostEquals(z, 1, EPS)

	p = Point(1, 2, math.pi / 2)
	x, z = p:worldToLocal(3, 4)
	lu.assertAlmostEquals(x, -2, EPS)
	lu.assertAlmostEquals(z, 2, EPS)
	x, z = p:localToWorld(x, z)
	lu.assertAlmostEquals(x, 3, EPS)
	lu.assertAlmostEquals(z, 4, EPS)
end

TestCourse = {}

function TestCourse:setUp()
	self.waypoints = th.waypoints
end

function TestCourse:testEnrichWaypointData()
	local course = Course(nil, self.waypoints)
	lu.assertAlmostEquals(course.waypoints[1].angle, 90)
	lu.assertAlmostEquals(course.waypoints[1].dx, 1)
	lu.assertAlmostEquals(course.waypoints[1].dz, 0)
	lu.assertAlmostEquals(course.waypoints[2].angle, 0)
	lu.assertAlmostEquals(course.waypoints[2].dx, 0)
	lu.assertAlmostEquals(course.waypoints[2].dz, 1)
	lu.assertAlmostEquals(course.waypoints[3].angle, -90)
	lu.assertAlmostEquals(course.waypoints[3].dx, -1)
	lu.assertAlmostEquals(course.waypoints[3].dz, 0)
	lu.assertAlmostEquals(course.waypoints[4].angle, 180)
	lu.assertAlmostEquals(course.waypoints[4].dx, 0)
	lu.assertAlmostEquals(course.waypoints[4].dz, -1)
	lu.assertAlmostEquals(course.waypoints[5].angle, 180)
	lu.assertAlmostEquals(course.waypoints[5].dx, 0)
	lu.assertAlmostEquals(course.waypoints[5].dz, -1)
end

function TestCourse:testGetAverageSpeed()
	local course = Course(nil, self.waypoints)
	lu.assertAlmostEquals(course:getAverageSpeed(1, 3), 2, 0.1)
	lu.assertAlmostEquals(course:getAverageSpeed(2, 3), 3, 0.1)
	lu.assertAlmostEquals(course:getAverageSpeed(4, 3), 3.33, 0.1)
	lu.assertAlmostEquals(course:getAverageSpeed(5, 5), 3, 0.1)
end

function TestCourse:testGetWaypointsWithinDrivingTime()
	local waypoints = {
		{posX = 0, 	posZ = 0,  speed = 3.6},
		{posX = 10, posZ = 0,  speed = 3.6},
		{posX = 20, posZ = 0,  speed = 3.6},
		{posX = 30, posZ = 0,  speed = 3.6},
		{posX = 40, posZ = 0,  speed = 3.6}
	}
	local course = Course(nil, waypoints)
	local result = course:getWaypointsWithinDrivingTime(1, true, 10)
	lu.assertEquals(#result, 2)
end

lu.LuaUnit.run()




