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

require("geo")
require("CpObject")
require("Waypoint")
require("Conflict")
require("test.mock-GiantsEngine")
require("test.mock-courseplay")
require("courseGenerator")

TestTrafficController = {}
TestTrafficController.date = '000000'

function getDate()
	return TestTrafficController.date
end

function TestTrafficController:setUp()
	self.tc = TrafficController()
	self.vehicle = {}

end

function TestTrafficController:testClock()
	lu.assertEquals(self.tc.clock, 0)
	self.tc:update(1)
	lu.assertEquals(self.tc.clock, 0)
	TestTrafficController.date = '000001'
	self.tc:update(1)
	lu.assertEquals(self.tc.clock, 1)
end

function TestTrafficController:testIntermediatePoints()
	local a = {x = 0, z = 0}
	local b = {x = 10, z = 10}
	self.tc.gridSpacing = 5 * math.sqrt(2)
	local ips = self.tc:getIntermediatePoints(a, b)
	lu.assertAlmostEquals(ips[1].x, 5)
	lu.assertAlmostEquals(ips[1].z, 5)
	self.tc.gridSpacing = 3 * math.sqrt(2)
	ips = self.tc:getIntermediatePoints(a, b)
	lu.assertEquals(#ips, 3)
	lu.assertAlmostEquals(ips[1].x, 3)
	lu.assertAlmostEquals(ips[1].z, 3)
	lu.assertAlmostEquals(ips[2].x, 6)
	lu.assertAlmostEquals(ips[2].z, 6)
	lu.assertAlmostEquals(ips[3].x, 9)
	lu.assertAlmostEquals(ips[3].z, 9)

	a = {x = 0, z = 0}
	b = {x = -10, z = 0}
	self.tc.gridSpacing = 5
	ips = self.tc:getIntermediatePoints(a, b)
	lu.assertEquals(#ips, 1)
	lu.assertAlmostEquals(ips[1].x, -5)


end

function TestTrafficController:testGetGridPoints()
	local wps = th.courseBuilder(
		{ 0, 0, 10,
		  5, 0, 10,
		  10, 0, 10,
		  15, 0, 10,
		  20, 0, 10,
		  25, 0, 10,
		  30, 0, 10,
		  35, 0, 10,
		  40, 0, 10,
		  45, 0, 10,
		  50, 0, 10,
		}
	)
	local course = Course(self.vehicle, wps)
	self.tc.lookaheadTimeSeconds = 10
	self.tc.gridSpacing = 10
	local tiles = self.tc:getGridPointsUnderCourse(course, self.tc:forwardIterator(1, #course.waypoints - 1), 1 * 3.6)
	lu.assertEquals(#tiles, 3)
	lu.assertAlmostEquals(tiles[1].x, 0)
	lu.assertAlmostEquals(tiles[1].z, 0)
	lu.assertAlmostEquals(tiles[2].x, 0)
	lu.assertAlmostEquals(tiles[3].x, 1)

	self.tc.lookaheadTimeSeconds = 9
	self.tc.gridSpacing = 10
	tiles = self.tc:getGridPointsUnderCourse(course, self.tc:forwardIterator(1, #course.waypoints - 1), 1 * 3.6)
	lu.assertEquals(#tiles, 2)
	lu.assertAlmostEquals(tiles[1].x, 0)
	lu.assertAlmostEquals(tiles[1].z, 0)
	lu.assertAlmostEquals(tiles[2].x, 0)

	self.tc.lookaheadTimeSeconds = 30
	self.tc.gridSpacing = 10
	tiles = self.tc:getGridPointsUnderCourse(course, self.tc:forwardIterator(3, #course.waypoints - 1), 1 * 3.6)
	lu.assertEquals(#tiles, 7)
	lu.assertAlmostEquals(tiles[1].x, 1)
	lu.assertAlmostEquals(tiles[1].z, 0)
	lu.assertAlmostEquals(tiles[3].x, 2)
	lu.assertAlmostEquals(tiles[7].x, 4)

	wps = th.courseBuilder(
		{ 0, 0, 10,
		  -5, 0, 10,
		  -10, 0, 10,
		  -15, 0, 10,
		  -20, 0, 10,
		  -25, 0, 10,
		  -30, 0, 10,
		  -35, 0, 10,
		  -40, 0, 10,
		  -45, 0, 10,
		  -50, 0, 10,
		}
	)
	course = Course(self.vehicle, wps)
	self.tc.lookaheadTimeSeconds = 35
	self.tc.gridSpacing = 10
	tiles = self.tc:getGridPointsUnderCourse(course, self.tc:forwardIterator(1, #course.waypoints - 1), 1 * 3.6)
	lu.assertEquals(#tiles, 8)
	lu.assertAlmostEquals(tiles[1].x, 0)
	lu.assertAlmostEquals(tiles[1].z, 0)
	lu.assertAlmostEquals(tiles[2].x, -1)
	lu.assertAlmostEquals(tiles[4].x, -2)
	lu.assertAlmostEquals(tiles[7].x, -3)
	lu.assertAlmostEquals(tiles[8].x, -4)

	wps = th.courseBuilder(
		{ 0, 0, 0,
		  5, 0, 0,
		  10, 0, 0,
		  15, 0, 0,
		  20, 0, 0,
		  25, 0, 0,
		  30, 0, 0,
		  35, 0, 0,
		  40, 0, 0,
		  45, 0, 0,
		  50, 0, 0,
		}
	)
	course = Course(self.vehicle, wps)
	self.tc.lookaheadTimeSeconds = 10
	self.tc.gridSpacing = 10
	tiles = self.tc:getGridPointsUnderCourse(course, self.tc:forwardIterator(1, #course.waypoints - 1))
	-- speed zero, reserve first tile only
	lu.assertEquals(#tiles, 1)

end

function TestTrafficController:testGridPointsWithIntermediatePoints()
	local wps = th.courseBuilder(
		{ 0, 0, 10,
		  10, 0, 10,
		  20, 0, 10,
		  30, 0, 10,
		  40, 0, 10,
		  50, 0, 10,
		}
	)
	local course = Course(self.vehicle, wps)
	self.tc.lookaheadTimeSeconds = 10
	self.tc.gridSpacing = 5

	local tiles = self.tc:getGridPointsUnderCourse(course, self.tc:forwardIterator(1, #course.waypoints - 1), 1 * 3.6)
	lu.assertEquals(#tiles, 4)
	lu.assertAlmostEquals(tiles[1].x, 0)
	lu.assertAlmostEquals(tiles[1].z, 0)
	lu.assertAlmostEquals(tiles[2].x, 1)
	lu.assertAlmostEquals(tiles[3].x, 2)
	lu.assertAlmostEquals(tiles[4].x, 3)
end

function TestTrafficController:testReserveFree()
	local reservation1 = Reservation(3, 1)
	local reservation2 = Reservation(2, 1)
	self.tc.reservations = {}
	local ok = self.tc:reserveTile(Point(1, 1), reservation1)
	lu.assertTrue(ok)
	ok = self.tc:reserveTile(Point(1, 1), reservation1)
	-- it is ok to reserve the same tile for the same vehicle twice
	lu.assertTrue(ok)

	-- can reserve free tiles
	ok = self.tc:reserveTile(Point(2, 1), reservation2)
	lu.assertTrue(ok)
	ok = self.tc:reserveTile(Point(1, 2), reservation2)
	lu.assertTrue(ok)

	-- can't reserve and already reserved tile
	ok = self.tc:reserveTile(Point(1, 1), reservation2)
	lu.assertFalse(ok)

	self.tc:freeTile(Point(1, 1), reservation1.vehicleId)
	-- can reserve once freed
	ok = self.tc:reserveTile(Point(1, 1), reservation2)
	lu.assertTrue(ok)
end


-- This isn't really a unit test, more like a module test so may be too fragile
function TestTrafficController:testReserve()
	print()
	self.tc.lookaheadTimeSeconds = 30
	self.tc.gridSpacing = 10
	-- at 10 km/h we move about 83 meters in 30 seconds so the entire course will be reserved
	local wps1 = th.courseBuilder(
		{
		  10, 35, 5,
		  15, 35, 5,
		  20, 35, 5,
		  25, 35, 5,
		  30, 35, 5,
		  35, 35, 5,
		  40, 35, 5,
		  45, 35, 5,
		  55, 35, 5,
		  60, 35, 5,
		  65, 35, 5,
		  70, 35, 5,
		  75, 35, 5,
		}
	)
	local course1 = Course(self.vehicle, wps1)
	local vehicleId1 = 1
	local ok = self.tc:reserve(vehicleId1, course1, 1)
	lu.assertTrue(ok)

	lu.assertEquals(tostring(self.tc),
[[
...1......
..111.....
..111.....
..111.....
..111.....
...1......
..........
..........
..........
..........
]])

	local wps2 = th.courseBuilder(
		{ 18, -10, 10,
		   18,  -5, 10,
		   18, 0, 10,
		   18, 10, 10,
		   18, 15, 10,
		   18, 20, 10,
		   18, 25, 10,
		   18, 30, 10,
		   18, 35, 10,
		   18, 40, 10,
		   18, 45, 10,
		}
	)

	local course2 = Course(self.vehicle, wps2)
	local vehicleId2 = 2
	ok = self.tc:reserve(vehicleId2, course2, 1)
	-- conflicting course, will reserve only part of the course
	lu.assertFalse(ok)

	-- move first vehicle
	ok = self.tc:reserve(vehicleId1, course1, 3)
	lu.assertTrue(ok)
	lu.assertEquals(tostring(self.tc),
[[
22........
22.1......
22111.....
..111.....
..111.....
..111.....
..111.....
...1......
..........
..........
]])

	ok = self.tc:reserve(vehicleId2, course2, 1)
	-- still conflicting
	lu.assertFalse(ok)

	ok = self.tc:reserve(vehicleId1, course1, 5)
	lu.assertTrue(ok)

	ok = self.tc:reserve(vehicleId2, course2, 1)
	-- still conflicting
	lu.assertFalse(ok)

	ok = self.tc:reserve(vehicleId1, course1, 7)
	lu.assertTrue(ok)

	ok = self.tc:reserve(vehicleId2, course2, 1)
	-- no more conflicts
	lu.assertTrue(ok)

	self.tc:cancel(vehicleId1)
	lu.assertEquals(tostring(self.tc),
[[
22222.....
222222....
22222.....
..........
..........
..........
..........
..........
..........
..........
]])

	local empty =
[[
..........
..........
..........
..........
..........
..........
..........
..........
..........
..........
]]

	self.tc:cancel(vehicleId2)
	lu.assertEquals(tostring(self.tc), empty)

	ok = self.tc:reserve(vehicleId1, course1, 1)
	lu.assertTrue(ok)
	ok = self.tc:reserve(vehicleId2, course2, 1)
	lu.assertFalse(ok)
local reserved =
	[[
22.1......
22111.....
22111.....
..111.....
..111.....
...1......
..........
..........
..........
..........
]]
	lu.assertEquals(tostring(self.tc), reserved)
	self.tc:cleanUp()
	-- no clean up as clock not advanced yet
	lu.assertEquals(tostring(self.tc), reserved)
	self.tc.clock = self.tc.lookaheadTimeSeconds * 3 - 1
	self.tc:cleanUp()
	-- still reserved as not reached the clean up time
	lu.assertEquals(tostring(self.tc), reserved)
	self.tc.clock = self.tc.clock + 1
	self.tc:cleanUp()
	lu.assertEquals(tostring(self.tc), empty)

end

lu.LuaUnit.run()
