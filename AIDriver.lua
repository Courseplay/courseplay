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

AIDriver = {}
AIDriver.__index = AIDriver

AIDriver.slowAngleLimit = 20
AIDriver.slowAcceleration = 0.5
AIDriver.slowDownFactor = 0.5

function AIDriver:new(vehicle)
	local newAIDriver = {}
	setmetatable( newAIDriver, self )
	newAIDriver.vehicle = vehicle
	-- for now, initialize the course with the vehicle's current course
	newAIDriver.course = Course:new(vehicle.Waypoints)
	newAIDriver.vehicle.cp.ppc:enable()
	newAIDriver.acceleration = 1
	return newAIDriver
end

function AIDriver:start(ix)
	self.vehicle.cp.ppc:setCourse(self.course)
	self.vehicle.cp.ppc:initialize(ix)
end

function AIDriver:drive(dt)

	self.vehicle.cp.ppc:update()

	local allowedToDrive = true

	if self.vehicle.cp.ppc:atLastWaypoint() then
		if self.vehicle.cp.stopAtEnd then
			-- stop at the last waypoint
			allowedToDrive = false
			CpManager:setGlobalInfoText(self.vehicle, 'END_POINT')
		else
			-- continue at the first waypoint
			self.vehicle.cp.ppc:initialize(1)
		end
	else
	end
	-- goal point to drive to
	local gx, gy, gz = self.vehicle.cp.ppc:getCurrentWaypointPosition()
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx, gy, gz);
	local moveForwards = not self:isReversing()
	lx = moveForwards and lx or -lx
	self:driveVehicle(dt, allowedToDrive, not self:isReversing(), lx, lz, self:getSpeed())

end

function AIDriver:driveVehicle(dt, allowedToDrive, moveForwards, lx, lz, maxSpeed)
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, self.acceleration,
		self.slowAcceleration, self.slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, self.slowDownFactor);
end

function AIDriver:onWaypointChange(newIx)
	-- implemented by the derived classes
end

function AIDriver:isReversing()
	local currentWpIx = self.vehicle.cp.ppc:getCurrentWaypointIx()
	return self.course:isReverseAt(currentWpIx) or self.course:switchingToForwardAt(currentWpIx)
end

function AIDriver:getSpeed()
	-- override by the derived classes
	return 15
end