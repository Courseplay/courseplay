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
function courseplay.checkFuel() return true end
function courseplay.turn() end

courseplay.debugChannels = {}
courseplay.debugChannels[12] = true

courseplay.settings = {}
courseplay.hud = {}

function courseplay.debugVehicle(channel, vehicle, ...)
	print(string.format(...))
end

function courseplay:loc(text)
	return text
end

function courseplay.updateFillLevelsAndCapacities()
end

function courseplay:distance(x1, z1, x2, z2)
	local dx, dz = x2 - x1, z2 - z1
	return math.sqrt(dx * dx + dz * dz)
end

-- this should be ok to redefine here, these won't change much
courseplay.MODE_GRAIN_TRANSPORT = 1;
courseplay.MODE_COMBI = 2;
courseplay.MODE_OVERLOADER = 3;
courseplay.MODE_SEED_FERTILIZE = 4;
courseplay.MODE_TRANSPORT = 5;
courseplay.MODE_FIELDWORK = 6;
courseplay.MODE_COMBINE_SELF_UNLOADING = 7;
courseplay.MODE_LIQUIDMANURE_TRANSPORT = 8;
courseplay.MODE_SHOVEL_FILL_AND_EMPTY = 9;
courseplay.MODE_BUNKERSILO_COMPACTER = 10;
courseplay.NUM_MODES = 10;

CpManager = {}

cpDebug = {}
cpDebug.drawLine = noOp
