--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Thomas Gaertner

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

--[[
handles "mode10": level and compact
--------------------------------------
0)  Course setup:
	a) Start in the silo
	b) drive forward, set waiting point on parking postion out fot the way
	c) drive to the last point which should be alligned with the silo center line and be outside the silo



]]

---@class LevelCompactAIDriver : AIDriver

LevelCompactAIDriver = CpObject(AIDriver)

LevelCompactAIDriver.myStates = {
	DRIVE_TO_PARKING = {},
	DRIVE_TO_SILO = {},
	DRIVE_IN_SILO = {}
}



--- Constructor
function LevelCompactAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'LevelCompactAIDriver:init') 
	AIDriver.init(self, vehicle)
	self:initStates(LevelCompactAIDriver.myStates)
	self.mode = courseplay.MODE_BUNKERSILO_COMPACTER
	self.refSpeed = 10
	self:setHudContent()
end

function LevelCompactAIDriver:setHudContent()
	courseplay.hud:setLevelCompactAIDriverContent(self.vehicle)
	
	
end

function LevelCompactAIDriver:start(ix)
	self:beforeStart()
	local vehicle = self.vehicle

	--courseplay:setWaypointIndex(vehicle, 1);
	self.course = Course(self.vehicle , self.vehicle.Waypoints)
	self.ppc:setCourse(self.course)
	self.ppc:initialize(1)
	self.state = self.states.DRIVE_TO_SILO	
	
	--get moving tools (only once after starting)
	if self.vehicle.cp.movingToolsPrimary == nil then
		--self.vehicle.cp.movingToolsPrimary, self.vehicle.cp.movingToolsSecondary = courseplay:getMovingTools(self.vehicle);
	end;
	
	
end

function LevelCompactAIDriver:drive(dt)
	-- update current waypoint/goal point
	self.ppc:update()
	self.allowedToDrive = true
	
	if self.state == self.states.DRIVE_TO_SILO then
		AIDriver.driveCourse(self, dt)
	elseif self.state == self.states.DRIVE_IN_SILO then
		self.allowedToDrive = false
	end
end

function LevelCompactAIDriver:onEndCourse()
	self.ppc:initialize(1)
	print("change state to DRIVE_IN_SILO")
	self.state = self.states.DRIVE_IN_SILO

end

function LevelCompactAIDriver:updateLastMoveCommandTime()
	AIDriver.setLastMoveCommandTime(self, self.vehicle.timer)
end

function LevelCompactAIDriver:findNextRevWaypoint(currentPoint)
	local vehicle = self.vehicle;
	local _,ty,_ = getWorldTranslation(vehicle.cp.DirectionNode);
	for i= currentPoint, self.vehicle.cp.numWaypoints do
		local _,_,z = worldToLocal(vehicle.cp.DirectionNode, vehicle.Waypoints[i].cx , ty , vehicle.Waypoints[i].cz);
		if z < -3 and vehicle.Waypoints[i].rev  then
			return i
		end;
	end;
	return currentPoint;
end

function LevelCompactAIDriver:getSpeed()
	return self.refSpeed
end

function LevelCompactAIDriver:debug(...)
	courseplay.debugVehicle(10, self.vehicle, ...)
end


