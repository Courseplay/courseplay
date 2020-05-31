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
	self.vehicle.cp.ppc = PurePursuitController(self.vehicle)
	self.vehicle.cp.ppc:enable()
	--self.vehicle.cp.ppc:initialize(1)
end


errors = lu.LuaUnit.run()
os.exit(errors)