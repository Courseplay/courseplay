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

courseplay = {}

function courseplay.createNode() return 1 end
function courseplay.destroyNode() end
courseplay.debugChannels = {}
courseplay.debugChannels[12] = true

function courseplay.debugVehicle(channel, vehicle, ...)
	print(string.format(...))
end

function courseplay.updateFillLevelsAndCapacities()
end

CpManager = {}
