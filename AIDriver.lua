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

AIDriver = CpObject()

AIDriver.slowAngleLimit = 20
AIDriver.slowAcceleration = 0.5
AIDriver.slowDownFactor = 0.5

--- Create a new driver (usage: aiDriver = AIDriver(vehicle)
-- @param vehicle to drive. Will set up a course to drive from vehicle.Waypoints
function AIDriver:init(vehicle)
	self.vehicle = vehicle
	-- for now, initialize the course with the vehicle's current course
	self.course = Course(vehicle, vehicle.Waypoints)
	self.firstWaypointIx = 1
	self.ppc = self.vehicle.cp.ppc -- shortcut
	self.ppc:setAIDriver(self)
	self.ppc:enable()
	self.acceleration = 1
	self.mode = courseplay.MODE_TRANSPORT
	self.maxDrivingVectorLength = self.vehicle.cp.turnDiameter
	self.clock = 0
	self.turnIsDriving = false -- code in turn.lua is driving
end

function AIDriver:getMode()
	return self.mode
end

--- Start driving
-- @param ix the waypoint index to start driving at
function AIDriver:start(ix)
	self.firstWaypointIx = ix
	self.turnIsDriving = false
	if self:isAlignmentCourseNeeded(ix) then
		self:setUpAlignmentCourse(ix)
	end
	if self.alignmentCourse then
		self.ppc:setCourse(self.alignmentCourse)
		self.ppc:setLookaheadDistance(self.ppc.shortLookaheadDistance)
		self.ppc:initialize(1)
	else
		self.ppc:setCourse(self.course)
		self.ppc:setLookaheadDistance(self.ppc.normalLookAheadDistance)
		self.ppc:initialize(ix)
	end
end

--- Main driving function
-- should be called from update()
-- This base implementation just follows the waypoints, anything more than that
-- should be implemented by the derived classes as needed.
function AIDriver:drive(dt)
	-- update current waypoint/goal point
	self.ppc:update()
	-- should we keep driving?
	local allowedToDrive = self:checkLastWaypoint()
	self:driveCourse(dt, allowedToDrive)
end

--- Normal driving according to the course waypoints, using courseplay:goReverse() when needed
-- to reverse with trailer.
function AIDriver:driveCourse(dt, allowedToDrive)
	-- check if reversing
	local lx, lz, moveForwards, isReverseActive = self:getReverseDrivingDirection()
	-- stop for fuel if needed
	allowedToDrive = courseplay:checkFuel(self.vehicle, allowedToDrive,lx,lz)
	if isReverseActive then
		-- we go wherever goReverse() told us to go
		self:driveVehicleInDirection(dt, allowedToDrive, moveForwards, lx, lz, self:getSpeed())
	elseif self:isTurning() then
		-- let the code in turn drive the turn maneuvers
		courseplay:turn(self.vehicle, dt)
	else
		-- use the PPC goal point when forward driving or reversing without trailer
		local gx, _, gz = self.ppc:getGoalPointLocalPosition()
		self:driveVehicleToLocalPosition(dt, allowedToDrive, moveForwards, gx, gz, self:getSpeed())
	end
end

--- Drive to a local position. This is the simplest driving mode towards the goal point
function AIDriver:driveVehicleToLocalPosition(dt, allowedToDrive, moveForwards, gx, gz, maxSpeed)
	-- gx and gz are vehicle local coordinates of the point we want the vehicle drive to.
	-- AIVehicleUtil.driveToPoint() does not seem to be able to handle the cases where:
	-- 	1. this point is too far and/or
	-- 	2. this point is behind the vehicle.
	-- In those case it drives the vehicle on a very large radius arc. Until we clarify why this happens,
	-- we adjust these coordinates to make sure the vehicle turns towards the point as soon as possible.
	local ax, az = gx, gz
	local l = MathUtil.vector2Length(gx, gz)
	if l > self.maxDrivingVectorLength then
		-- point too far, bring it closer so the AI driver will start steer towards it
		ax = gx * self.maxDrivingVectorLength / l
		az = gz * self.maxDrivingVectorLength / l
	end
	if (moveForwards and gz < 0) or (not moveForwards and gz > 0) then
		-- make sure point is not behind us (no matter if driving reverse or forward)
		az = 0
	end
	if self.clock % 20 == 0 then
		self:debug('x = %.1f -> %.1f  z = %.1f -> %.1f, speed = %.1f', gx, ax, gz, az, maxSpeed)
	end
	self.clock = self.clock + 1
	AIVehicleUtil.driveToPoint(self.vehicle, dt, self.acceleration, allowedToDrive, moveForwards, ax, az, maxSpeed, false)
end

-- many courseplay modes control the vehicle through the lx/lz normalized local directions.
-- this is an interface for those modes to drive the vehicle.
function AIDriver:driveVehicleInDirection(dt, allowedToDrive, moveForwards, lx, lz, maxSpeed)
	-- construct an artificial goal point to drive to
	local gx, gz = lx * self.ppc:getLookaheadDistance(), lz * self.ppc:getLookaheadDistance()
	self:driveVehicleToLocalPosition(dt, allowedToDrive, moveForwards, gx, gz, maxSpeed)
end


--- Check if we are at the last waypoint and should we continue with first waypoint of the course
-- or stop.
function AIDriver:checkLastWaypoint()
	local allowedToDrive = true
	if self.ppc:reachedLastWaypoint() then
		if self:onAlignmentCourse() then
			-- alignment course to the first waypoint ended, start the actual course now
			self.ppc:setCourse(self.course)
			self.ppc:setLookaheadDistance(PurePursuitController.normalLookAheadDistance)
			self.ppc:initialize(self.firstWaypointIx)
			self.alignmentCourse = nil
			self:debug('Alignment course finished, starting course at waypoint %d', self.firstWaypointIx)
		elseif self.vehicle.cp.stopAtEnd then
			-- stop at the last waypoint
			allowedToDrive = false
			CpManager:setGlobalInfoText(self.vehicle, 'END_POINT')
		else
			-- continue at the first waypoint
			self.ppc:initialize(1)
		end
	end
	return allowedToDrive
end

function AIDriver:getDirectionToGoalPoint()
	-- goal point to drive to
	local gx, gy, gz = self.ppc:getGoalPointPosition()
	-- direction to the goal point
	return AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx, gy, gz);
end


--- Get the goal point when courseplay:goReverse is driving.
-- if isReverseActive is false, use the returned gx, gz for driveToPoint, otherwise get them
-- from PPC
function AIDriver:getReverseDrivingDirection()
	local moveForwards = true
	local isReverseActive = false
	-- get the direction to drive to
	local lx, lz = self:getDirectionToGoalPoint()
	-- take care of reversing
	if self.ppc:isReversing() then
		-- TODO: currently goReverse() calls ppc:initialize(), this is not really transparent,
		-- should be refactored so it returns a status telling us to drive forward from waypoint x instead.
		lx, lz, moveForwards, isReverseActive = courseplay:goReverse(self.vehicle, lx, lz)
		-- as of now we need to invert the direction from goReverse to work correctly with
		-- AI Driver, it seems to have a different reference
		lx, lz = -lx, -lz
	end
	return lx, lz, moveForwards, isReverseActive
end

function AIDriver:onWaypointChange(newIx)
	-- for backwards compatibility, we keep the legacy CP waypoint index up to date
	-- except while turn is driving as that does not like changing the waypoint during the turn
	if not self.turnIsDriving then
		courseplay:setWaypointIndex(self.vehicle, newIx)
	end
	-- rest is implemented by the derived classes	
end


function AIDriver:getSpeed()
	-- override by the derived classes
	self.vehicle.cp.curSpeed = self.vehicle.lastSpeedReal * 3600
	local speed
	if self.ppc:isReversing() then
		speed = self.vehicle.cp.speeds.reverse or self.vehicle.cp.speeds.crawl
	else
		if self.vehicle.cp.speeds.useRecordingSpeed then
			speed = math.max(
				self.course:getAverageSpeed(self.ppc:getCurrentWaypointIx(), 4),
				self.vehicle.cp.speeds.street)
		else
			speed = self.vehicle.cp.speeds.street
		end
	end
	if self:getIsInFilltrigger() then
		speed = self.vehicle.cp.speeds.turn
	end
	return speed and speed or 15
end


function AIDriver:getIsInFilltrigger()
	return self.vehicle.cp.fillTrigger ~= nil or self.vehicle.cp.tipperLoadMode > 0
end
--- Is an alignment course needed to reach waypoint ix in the current course?
-- override in derived classes as needed
function AIDriver:isAlignmentCourseNeeded(ix)
	local d = self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, ix)
	return d > self.vehicle.cp.turnDiameter and self.vehicle.cp.alignment.enabled
end

function AIDriver:onAlignmentCourse()
	return self.alignmentCourse ~= nil
end

function AIDriver:isTurning()
	if self.turnIsDriving then
		-- already in a turn
		return true
	elseif self.course:isTurnStartAtIx(self.ppc:getCurrentWaypointIx()) then
		-- a turn is coming up, relinquish control to turn.lua
		self.turnIsDriving = true
		self:debug('Starting a turn.')
		return true
	else
		-- not in a turn
		return false
	end
end

function AIDriver:onTurnEnd()
	self.turnIsDriving = false
	-- for now, we rely on turn.lua to set the next waypoint at the end of the turn and
	self.ppc:initialize()
	self:debug('Turn ended, continue at waypoint %d.', self.ppc:getCurrentWaypointIx())
end

function AIDriver:setUpAlignmentCourse(ix)
	local x, _, z = self.course:getWaypointPosition(ix)
	--Readjust x and z for offset being used
	-- TODO: offset should be an attribute of the course and handled by the course itself.
	if courseplay:getIsVehicleOffsetValid(self.vehicle) then
		x, z = courseplay:getVehicleOffsettedCoords(self.vehicle, x, z);
	end;
	-- TODO: maybe the course itself should return an alignment course to its own waypoint ix as we don't want
	-- to work with individual course waypoints here.
	local alignmentWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, x, z, math.rad( self.course:getWaypointAngleDeg(ix)))
	if not alignmentWaypoints then
		self:debug("Can't find an alignment course, may be too close to target wp?" )
		return
	end
	if #alignmentWaypoints < 3 then
		self:debug("Alignment course would be only %d waypoints, it isn't needed then.", #alignmentWaypoints )
		return
	end
	self:debug('Alignment course with %d started.', #alignmentWaypoints)
	self.alignmentCourse = Course(self.vehicle, alignmentWaypoints)
end

function AIDriver:debug(...)
	courseplay.debugVehicle(12, self.vehicle, ...)
end
