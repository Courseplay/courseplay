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
require("AIDriver")
require("GrainTransportAIDriver")
require("FieldworkAIDriver")
require("UnloadableFieldworkAIDriver")
require("FillableFieldworkAIDriver")
require("Waypoint")
require("PurePursuitController")
require("geo")
require("courseGenerator")

TestAIDriver = {}

function TestAIDriver:setUp()
	self.vehicle = giantsVehicle
	self.vehicle.Waypoints = th.waypoints
	self.vehicle.cp = cpVehicle
	function courseplay.distance()
		return 1
	end
	self.vehicle.cp.ppc = PurePursuitController(self.vehicle)
	self.vehicle.cp.ppc:initialize(1)
end

-- This is not a functional test, the only purpose is to run as much of the AIDriver code as possible
-- to find typos before restarting the game
function TestAIDriver:testAIDriver()
	local aiDriver = AIDriver(self.vehicle)
	aiDriver:start(1)
	aiDriver:drive(1)
end

function TestAIDriver:testGrainTransportAIDrvier()
	local aiDriver = GrainTransportAIDriver(self.vehicle)
	aiDriver:start(1)
	aiDriver:drive(1)
end

function TestAIDriver:testUnloadableFieldworkAIDriver()
	local driver = UnloadableFieldworkAIDriver(self.vehicle)
	driver:start(1)
	driver:drive(1)
end

errors = lu.LuaUnit.run()
os.exit(errors)
