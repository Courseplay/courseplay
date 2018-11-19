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

local TestHelper = {}

TestHelper.waypoints = {{posX = 0, posZ = 0,  speed = 1},
					  {posX = 2, posZ = 0,  speed = 2},
					  {posX = 2, posZ = 2,  speed = 3},
					  {posX = 0, posZ = 2,  speed = 4},
					  {posX = 0, posZ = -2, speed = 5}}

--- Build a course, every three elements in the table define a waypoint: first element is, second is z, third is speed
function TestHelper.courseBuilder(wps)
	local result = {}
	for i = 1, #wps, 3 do
		table.insert(result, { x = wps[i], z = wps[i + 1], speed = wps[i + 2]})
	end
	return result
end

return TestHelper