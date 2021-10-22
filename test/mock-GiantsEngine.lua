--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vaiko

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
delete = noOp
setTranslation = noOp
setRotation = noOp
function getRotation() return 0 end
function getTerrainHeightAtWorldPos() return 0 end
function getWorldTranslation() return 0, 0, 0 end
function worldToLocal() return 0, 0, 0 end
function localToLocal() return 0, 0, 0 end
localToWorld = worldToLocal
function localDirectionToWorld() return 0, 0, 0 end

Cylindered = {}

Utils = {}
Utils.appendedFunction = noOp
Utils.overwrittenFunction = noOp

MathUtil = {}
function MathUtil.vector2Length(x, y)
	return math.sqrt(x*x + y*y)
end

function MathUtil.vector3Length(x, y, z)
	return math.sqrt(x*x + z*z)
end

function MathUtil.vector2Normalize(x, y)
	local l = math.sqrt(x * x + y * y)
	if l > 0 then
		return x / l, y / l
	else
		return 0, 0
	end
end

function MathUtil.getYRotationFromDirection(dx, dz)
	return math.atan2(dx, dz)
end

DebugUtil = {}
DebugUtil.drawDebugNode = noOp

AIVehicleUtil = {}
function AIVehicleUtil.getDriveDirection() return 0, 0 end
AIVehicleUtil.driveInDirection = noOp
AIVehicleUtil.driveToPoint = noOp

function getDate(formatString)
	return os.date('%H%M%S')
end

g_updateLoopIndex = 1
g_currentMission = {}
g_currentMission.mock = true
g_currentMission.missionInfo = {}
g_currentMission.missionInfo.mapId = 'MockMap'
giantsVehicle = {}
giantsVehicle.lastSpeedReal = 10

g_careerScreen = {}
g_careerScreen.selectedIndex = 1

courseplay = {}
courseplay.hud = {}

function courseplay.debugFormat(channel, ...)
	print('debug: ', string.format(...))
end

function giantsVehicle.raiseAIEvent(vehicleEvent, otherEvent)
	print(vehicleEvent, otherEvent)
end

function giantsVehicle.getSpeedLimit()
	return 10
end

function giantsVehicle.setCruiseControlMaxSpeed() end

g_time = 0

function getUserProfileAppPath()
	return './'
end

function createFolder(folder)
	os.execute('mkdir "' .. folder .. '"')
end

function getFiles(folder, callback, object)
	for dir in io.popen('dir "' .. folder .. '" /b /ad'):lines() do
		object[callback](object, dir, true)
	end
	for file in io.popen('dir "' .. folder .. '" /b /a-d'):lines() do
		object[callback](object, file, false)
	end
end

function getfenv()
	return _G
end

function deleteFile(fullPath)
	os.execute('del "' .. fullPath .. '"')
end

function deleteFolder(fullPath)
	os.execute('del /s /q "' .. fullPath .. '\\*"')
	os.execute('for /d %i in ("' .. fullPath .. '\\*") do rd /s /q "%i"')
end

function fileExists(fullPath)
	for _ in io.popen('dir "' .. fullPath .. '" /b'):lines() do
		return true
	end
	return false
end

-- course_management.lua mocks
courseplay.courses = {}
function courseplay.courses:loadCourseFromFile(course)
end

function courseplay.courses:writeCourseFile(fullPath, course)
	os.execute('echo "' .. fullPath .. '" > "' .. fullPath)
end

