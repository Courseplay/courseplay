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

function nameNum(vehicle)
	return 'some vehicle'
end

function getName(node)
	return 'some node'
end

function noOp() end

setTranslation = noOp
setRotation = noOp
function getRotation() return 0 end

function getWorldTranslation() return 0, 0, 0 end
function worldToLocal() return 0, 0, 0 end
localToWorld = worldToLocal
function localDirectionToWorld() return 0, 0, 0 end

Utils = {}
function Utils.vector2Length() return 0 end

DebugUtil = {}
DebugUtil.drawDebugNode = noOp
drawDebugLine = noOp

AIVehicleUtil = {}
function AIVehicleUtil.getDriveDirection() return 0, 0 end
AIVehicleUtil.driveInDirection = noOp
