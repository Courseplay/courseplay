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
require("mock-GiantsEngine")
require("mock-Courseplay")
require("CpObject")
require("Waypoint")
require("PurePursuitController")
require("settings")

TestSettings = {}

function TestSettings:setUp()
	self.vehicle = {}
	self.vehicle.Waypoints = th.waypoints
	self.vehicle.cp = {}
	self.vehicle.cp.ppc = PurePursuitController:new(self.vehicle)
	self.vehicle.cp.ppc:enable()
	--self.vehicle.cp.ppc:initialize(1)
end

-- This is not a functional test, the only purpose is to run as much of the AIDriver code as possible
-- to find typos before restarting the game
function TestSettings:testDrivingModeSettingList()
	self.vehicle.cp.mode = courseplay.MODE_TRANSPORT
	local drivingMode = DrivingModeSetting(self.vehicle)
	lu.assertEquals(drivingMode:get(), DrivingModeSetting.DRIVING_MODE_NORMAL)
	lu.assertIsTrue(drivingMode:is(DrivingModeSetting.DRIVING_MODE_NORMAL))
	lu.assertIsFalse(self.vehicle.cp.ppc:isEnabled())
	drivingMode:next()
	lu.assertEquals(drivingMode:get(), DrivingModeSetting.DRIVING_MODE_PPC)
	lu.assertIsTrue(self.vehicle.cp.ppc:isEnabled())
	drivingMode:next()
	lu.assertEquals(drivingMode:get(), DrivingModeSetting.DRIVING_MODE_AIDRIVER)
	lu.assertIsTrue(self.vehicle.cp.ppc:isEnabled())
	drivingMode:next()
	lu.assertEquals(drivingMode:get(), DrivingModeSetting.DRIVING_MODE_NORMAL)
	lu.assertIsFalse(self.vehicle.cp.ppc:isEnabled())
	self.vehicle.cp.mode = courseplay.MODE_COMBI
	drivingMode:next()
	drivingMode:next()
	lu.assertEquals(drivingMode:get(), DrivingModeSetting.DRIVING_MODE_NORMAL)
	lu.assertIsFalse(self.vehicle.cp.ppc:isEnabled())

	drivingMode:set(DrivingModeSetting.DRIVING_MODE_PPC)
	lu.assertEquals(drivingMode:get(), DrivingModeSetting.DRIVING_MODE_PPC)
	lu.assertEquals(drivingMode:getText(), 'COURSEPLAY_PPC_ON')
	lu.assertIsTrue(self.vehicle.cp.ppc:isEnabled())
end

errors = lu.LuaUnit.run()
os.exit(errors)