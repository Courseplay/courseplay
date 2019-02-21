--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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

This is the base class of all AI drivers (modes) and implements MODE_TRANSPORT (5),
using the PurePursuitController (PPC). It replaces the code in drive.lua and has the
basic functionality:
•	Drive a course
•	Drive turn maneuvers (by passing on control to the code in turn.lua for the duration of the turn)
•	Add an alignment when needed before starting the course (this is a lot easier now as
it just initializes the PPC with the alignment course and after that is finished, initializes
it with the regular course)
•	Restarts or finishes the course at the last waypoint.
•	Uses reverse.lua to reverse with a trailer but can reverse single vehicles.
•	Has collision detection enabled by default

The AIDriver class implements all functionality common to all modes (like lights, covers, etc.).
Mode specific functions should all go into the derived classes. AIDriver MUST NOT HAVE any
IF statements with things like cp.mode == x!


Start/Stop
----------

Start the AIDriver with calling start(), stop it with dismiss().

If you implement your own start() and don't call AIDriver.start() then make sure you call
beforeStart() to perform some essential initialization.


Drive
-----

Call drive() in each update loop. Like with start() if you implement your own drive() function
it is a good idea to call AIDriver.drive() from that once you did your derived class specific
stuff. If you don't call AIDriver.drive() make sure you call at least self.ppc:update() at the
beginning of the function and resetSpeed() just before leaving drive() these are essential for
the AIDriver.

For some more control you can use any one of the drive*() function but driveVehicleToLocalPosition()
must always be called either through these or directly to do the actual driving.


Speed Control
-------------

The general idea is that the AIDriver follows the current course by steering the vehicle and switching to
forward or reverse. Then, based on various conditions we regulate the driving speed, for example to
stop for refill or wait for the implements to unfold, etc.

There are two functions provided to control the speed: hold() and setSpeed(). At the end of every loop
these are reset so if you don't do anything, the AIDriver will keep driving with the recorded speed.

If you want to momentarily stop the vehicle, you'll have to call hold() in every loop as long as you
don't want it to move (this will set allowedToDrive = false and stop abruptly). You can also stop the
vehicle by setting the speed to 0, this will just let it roll until it stops without applying the brake.

Likewise, if you want to drive with any speed different than the recorded one you have to call setSpeed()
at least once during the update loop, before driveVehicleToLocalPosition() is called. You can call
setSpeed() multiple times in a loop, the AIDriver will apply the lowest value set in the loop.


Triggering Position Based Events
--------------------------------

If you need to control your vehicle based on its position on the course please use the callback provided
by the PPC (like onWaypointPassed()) or the functions of the Course() class like hasUnloadPointAround())
and never the waypoints directly.


Displaying Messages
-------------------

Use setInfoText(<message>) to display a message where message is one of the globalInfoText.msgReference
entries. You can set it in each loop or set it once the condition (like NEEDS_UNLOADING) emerges. A message
turned on by calling setInfoText() will be shown until clearInfoText(<message>) is called again or the
helper is dismissed.

You can add multiple messages to display by calling setInfoText() multiple times with different messages.

Make sure to call updateInfoText() in each cycle to display the current message texts.



Note:
If the AIDriver does not seem to have the functionality you need please contact me, we'll figure something out.

Peter

]]

---@class AIDriver
AIDriver = CpObject()

AIDriver.slowAngleLimit = 20
AIDriver.slowAcceleration = 0.5
AIDriver.slowDownFactor = 0.5

-- we use this as an enum
AIDriver.myStates = {
	TEMPORARY = {}, -- Temporary course, dynamically generated, for example alignment or fruit avoidance
	RUNNING = {},
	STOPPED = {}
}

--- Create a new driver (usage: aiDriver = AIDriver(vehicle)
-- @param vehicle to drive. Will set up a course to drive from vehicle.Waypoints
function AIDriver:init(vehicle)
	self.debugChannel = 14
	self.mode = courseplay.MODE_TRANSPORT
	self.states = {}
	self:initStates(AIDriver.myStates)
	self.vehicle = vehicle
	self:debug('creating AIDriver')
	self.maxDrivingVectorLength = self.vehicle.cp.turnDiameter
	---@type PurePursuitController
	self.ppc = PurePursuitController(self.vehicle)
	self.vehicle.cp.ppc = self.ppc
	self.ppc:setAIDriver(self)
	self.ppc:enable()
	self.waypointIxAfterTemporary = 1
	self.acceleration = 1
	self.turnIsDriving = false -- code in turn.lua is driving
	self.temporaryCourse = nil
	self.state = self.states.STOPPED
	self.debugTicks = 100 -- show sparse debug information only at every debugTicks update
	-- AIDriver and its derived classes set the self.speed in various locations in
	-- the code and then getSpeed() will pass that on to AIDriver.driveCourse.
	self.speed = 0
	-- same for allowedToDrive, is reset at the end of each loop to true and needs to be set to false
	-- if someone wants to stop by calling hold()
	self.allowedToDrive = true
	self.collisionDetectionEnabled = false
	self.collisionDetector = CollisionDetector(self.vehicle)
	-- list of active messages to display
	self.activeMsgReferences = {}
end

-- destructor. The reason for having this is the collisionDetector which creates nodes and
-- we want those nodes removed when the AIDriver instance is deleted.
function AIDriver:delete()
	self:debug('delete AIDriver')
	self:deleteCollisionDetector()
end

function AIDriver:deleteCollisionDetector()
	if self.collisionDetector then
		self.collisionDetector:delete()
	end
	self.collisionDetector = nil
end

--- Aggregation of states from this and all descendant classes
function AIDriver:initStates(states)
	for key, state in pairs(states) do
		self.states[key] = state
	end
end

function AIDriver:getMode()
	return self.mode
end

-- TODO: remove this once mode 2 is cleaned up!
function AIDriver:getCpMode()
	return self.vehicle.cp.mode
end

--- If you have your own start() implementation and you do not call AIDriver.start() then
-- make sure this is called from the derived start() to initialize all common stuff
function AIDriver:beforeStart()
	self.turnIsDriving = false
	self.temporaryCourse = nil
	self:deleteCollisionDetector()
end

--- Start driving
-- @param ix the waypoint index to start driving at
function AIDriver:start(ix)
	self:beforeStart()
	self.state = self.states.RUNNING
	-- derived classes must disable collision detection if they don't need its
	self:enableCollisionDetection()
	-- for now, initialize the course with the vehicle's current course
	-- main course is the one generated/loaded/recorded
	self.mainCourse = Course(self.vehicle, self.vehicle.Waypoints)
	self:debug('AI driver in mode %d starting at %d/%d waypoints', self:getMode(), ix, self.mainCourse:getNumberOfWaypoints())
	self:startCourseWithAlignment(self.mainCourse, ix)
end

--- Dismiss the driver
function AIDriver:dismiss()
	self.vehicle:deactivateLights()
	self:clearAllInfoTexts()
	self:stop()
end

--- Stop the driver
-- @param reason as defined in globalInfoText.msgReference
function AIDriver:stop(msgReference)
	-- not much to do here, see the derived classes
	self:setInfoText(msgReference)
	self.state = self.states.STOPPED
	self.turnIsDriving = false
	-- don't delete the collision detector in dev mode so we can see collisions logged while manually driving
	if not CpManager.isDeveloper then
		self:deleteCollisionDetector()
	end
end

function AIDriver:continue()
	self:debug('Continuing...')
	self.state = self.states.RUNNING
	-- can be stopped for various reasons and those can have different msgReferences, so
	-- just remove all, if there's a condition which requires a message it'll call setInfoText() again anyway.
	self:clearAllInfoTexts()
end

--- Compatibility function for the legacy CP code so the course can be resumed
-- at the index as originally was in vehicle.Waypoints.
function AIDriver:resumeAt(cpIx)
	local i = self.course:findOriginalIx(cpIx)
	self:debug('resumeAt %d (legacy) %d (AIDriver', cpIx, i)
	self.ppc:initialize(i)
end

function AIDriver:setInfoText(msgReference)
	if msgReference then
		self:debugSparse('set info text to %s', msgReference)
		self.activeMsgReferences[msgReference] = true
	end
end

function AIDriver:clearInfoText(msgReference)
	if msgReference then
		self.activeMsgReferences[msgReference] = nil
	end
end

function AIDriver:clearAllInfoTexts()
	self.activeMsgReferences = {}
end

-- This has to be called in each update cycle to show messages
function AIDriver:updateInfoText()
	for msg, _ in pairs(self.activeMsgReferences) do
		CpManager:setGlobalInfoText(self.vehicle, msg)
	end
end

--- Main driving function
-- should be called from update()
-- This base implementation just follows the waypoints, anything more than that
-- should be implemented by the derived classes as needed.
function AIDriver:drive(dt)
	-- update current waypoint/goal point
	self.ppc:update()
	-- collision detection
	self:detectCollision(dt)

	self:updateInfoText()

	if self.state == self.states.STOPPED then
		self:hold()
	end

	self:checkLastWaypoint()
	self:driveCourse(dt)

	self:drawTemporaryCourse()
	self:resetSpeed()
end

--- Normal driving according to the course waypoints, using	 courseplay:goReverse() when needed
-- to reverse with trailer.
function AIDriver:driveCourse(dt)
	self:updateLights()
	-- check if reversing
	local lx, lz, moveForwards, isReverseActive = self:getReverseDrivingDirection()
	-- stop for fuel if needed
	if not courseplay:checkFuel(self.vehicle, lx, lz, true)
	or not courseplay:getIsEngineReady(self.vehicle) then
		self:hold()
	end

	-- use the recorded speed by default
	self:setSpeed(self:getRecordedSpeed())

	if self:getIsInFilltrigger() then
		self:setSpeed(self.vehicle.cp.speeds.approach)
	end

	-- slow down before wait points
	if self.course:hasWaitPointAround(self.ppc:getCurrentOriginalWaypointIx(), 1, 2) then
		self:setSpeed(self.vehicle.cp.speeds.turn)
	end

	if isReverseActive then
		-- we go wherever goReverse() told us to go
		self:driveVehicleInDirection(dt, self.allowedToDrive, moveForwards, lx, lz, self:getSpeed())
	elseif self.turnIsDriving then
		-- let the code in turn drive the turn maneuvers
		-- TODO: refactor turn so it does not actually drives but only gives us the direction like goReverse()
		courseplay:turn(self.vehicle, dt)
	elseif self.course:isTurnStartAtIx(self.ppc:getCurrentWaypointIx()) then
		-- a turn is coming up, relinquish control to turn.lua
		self:onTurnStart()
	else
		-- use the PPC goal point when forward driving or reversing without trailer
		local gx, _, gz = self.ppc:getGoalPointLocalPosition()
		self:driveVehicleToLocalPosition(dt, self.allowedToDrive, moveForwards, gx, gz, self:getSpeed())
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
	-- TODO: remove allowedToDrive parameter and only use self.allowedToDrive
	if not self.allowedToDrive then allowedToDrive = false end
	self:debugSparse('Speed = %.1f, gx=%.1f gz=%.1f l=%.1f ax=%.1f az=%.1f allowed=%s fwd=%s', maxSpeed, gx, gz, l, ax, az,
		allowedToDrive, moveForwards)
	if self.collisionDetector then
		self.collisionDetector:update(self.course, self.ppc:getCurrentWaypointIx(), ax, az)
	end
	AIVehicleUtil.driveToPoint(self.vehicle, dt, self.acceleration, allowedToDrive, moveForwards, ax, az, maxSpeed, false)
end

-- many courseplay modes control the vehicle through the lx/lz normalized local directions.
-- this is an interface for those modes to drive the vehicle.
function AIDriver:driveVehicleInDirection(dt, allowedToDrive, moveForwards, lx, lz, maxSpeed)
	-- construct an artificial goal point to drive to
	local gx, gz = lx * self.ppc:getLookaheadDistance(), lz * self.ppc:getLookaheadDistance()
	self:driveVehicleToLocalPosition(dt, allowedToDrive, moveForwards, gx, gz, maxSpeed)
end

--- Start course and set course as the current one
---@param course Course
---@param ix number
function AIDriver:startCourse(course, ix)
	self.course = course
	self.ppc:setCourse(self.course)
	self.ppc:initialize(ix)
end

--- Start course (with alignment if needed) and set course as the current one
---@param course Course
---@param ix number
---@return boolean true when an alignment course was added
function AIDriver:startCourseWithAlignment(course, ix)
	self.turnIsDriving = false
	local alignmentCourse = nil
	if self.vehicle.cp.alignment.enabled and self:isAlignmentCourseNeeded(course, ix) then
		alignmentCourse = self:setUpAlignmentCourse(course, ix)
	end
	if alignmentCourse then
		self:startTemporaryCourse(alignmentCourse, course, ix)
	else
		-- alignment course not enabled/needed/cannot be generated,
		-- start the main course then
		self.course = course
		self.ppc:setCourse(self.course)
		self.ppc:initialize(ix)
	end
	return alignmentCourse
end

--- Start a temporary course and continue with nextCourse at ix when done
---@param tempCourse Course
---@param nextCourse Course
---@param ix number
function AIDriver:startTemporaryCourse(tempCourse, nextCourse, ix)
	self:debug('Starting a temporary course, will continue at waypoint %d afterwards.', ix)
	self.temporaryCourse = tempCourse
	self.waypointIxAfterTemporary = ix
	self.courseAfterTemporary = nextCourse
	self.course = self.temporaryCourse
	self.ppc:setCourse(self.course)
	self.ppc:initialize(1)
end

--- Check if we are at the last waypoint and should we continue with first waypoint of the course
-- or stop.
function AIDriver:checkLastWaypoint()
	if self.ppc:reachedLastWaypoint() then
		if self:onTemporaryCourse() then
			-- alignment course to the first waypoint ended, start the main course now
			self.ppc:setLookaheadDistance(PurePursuitController.normalLookAheadDistance)
			self:startCourse(self.courseAfterTemporary, self.waypointIxAfterTemporary)
			self.temporaryCourse = nil
			self:debug('Temporary course finished, starting next course at waypoint %d', self.waypointIxAfterTemporary)
			self:onEndTemporaryCourse()
		else
			self:onEndCourse()
		end
	end
end

--- Do whatever is needed after the temporary course is ended
function AIDriver:onEndTemporaryCourse()
	-- nothing in general, derived classes will implement when needed
end

--- Course ended
function AIDriver:onEndCourse()
	if self.vehicle.cp.stopAtEnd then
		if self.state ~= self.states.STOPPED then
			self:stop('END_POINT')
		end
	else
		-- continue at the first waypoint
		self.ppc:initialize(1)
	end
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
	-- TODO: refactor this! No dependencies on modes here!
	local isMode2 = self:getCpMode() == courseplay.MODE_COMBI
	-- get the direction to drive to
	local lx, lz = self:getDirectionToGoalPoint()
	-- take care of reversing
	if self.ppc:isReversing() then
		-- TODO: currently goReverse() calls ppc:initialize(), this is not really transparent,
		-- should be refactored so it returns a status telling us to drive forward from waypoint x instead.
		lx, lz, moveForwards, isReverseActive = courseplay:goReverse(self.vehicle, lx, lz, isMode2)
		-- as of now we need to invert the direction from goReverse to work correctly with
		-- AI Driver, it seems to have a different reference
		lx, lz = -lx, -lz
		self:setSpeed(self.vehicle.cp.speeds.reverse or self.vehicle.cp.speeds.crawl)
	end
	return lx, lz, moveForwards, isReverseActive
end

function AIDriver:onWaypointChange(newIx)
	-- for backwards compatibility, we keep the legacy CP waypoint index up to date
	-- except while turn is driving as that does not like changing the waypoint during the turn
	if not self.turnIsDriving then
		courseplay:setWaypointIndex(self.vehicle, self.ppc:getCurrentOriginalWaypointIx())
	end
	-- rest is implemented by the derived classes
end

function AIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	-- default behaviour for mode 5 (transport), if a waypoint with the wait attribute is
	-- passed stop until the user presses the continue button
	if self.course:isWaitAt(ix) then
		self:stop('WAIT_POINT')
		-- show continue button
		courseplay.hud:setReloadPageOrder(self.vehicle, 1, true);
	end
end

function AIDriver:isWaiting()
	return self.state == self.states.STOPPED
end


--- Set the speed. The idea is that self.speed is reset at the beginning of every loop and
-- every function calls setSpeed() and the speed will be set to the minimum
-- speed set in this loop.
function AIDriver:setSpeed(speed)
	self.speed = math.min(self.speed, speed)
end

--- Reset drive controls at the end of each loop
function AIDriver:resetSpeed()
	-- reset speed limit for the next loop
	self.speed = math.huge
	self.allowedToDrive = true
end

--- Anyone wants to temporarily stop driving for whatever reason, call this
function AIDriver:hold()
	self.allowedToDrive = false
end

--- Function used by the driver to get the speed it is supposed to drive at
--
function AIDriver:getSpeed()
	return self.speed or 15
end

function AIDriver:getRecordedSpeed()
	local speed
	if self.vehicle.cp.speeds.useRecordingSpeed then
		-- use maximum street speed if there's no recorded speed.
		speed = math.min(
			self.course:getAverageSpeed(self.ppc:getCurrentWaypointIx(), 4) or self.vehicle.cp.speeds.street,
			self.vehicle.cp.speeds.street)
	else
		speed = self.vehicle.cp.speeds.street
	end
	return speed
end

-- TODO: review this whole fillpoint/filltrigger mess.
function AIDriver:isNearFillPoint()
	-- TODO: like above, we may have some better indication of this
	return self.ppc:getCurrentWaypointIx() >= 1 and self.ppc:getCurrentWaypointIx() <= 3 or self.vehicle.cp.tipperLoadMode > 0
end

function AIDriver:getIsInFilltrigger()
	return self.vehicle.cp.fillTrigger ~= nil or self:isNearFillPoint()
end
--- Is an alignment course needed to reach waypoint ix in the current course?
-- override in derived classes as needed
---@param course Course
function AIDriver:isAlignmentCourseNeeded(course, ix)
	local d = course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, ix)
	return d > self.vehicle.cp.turnDiameter and self.vehicle.cp.alignment.enabled
end

function AIDriver:onTemporaryCourse()
	return self.temporaryCourse ~= nil
end

function AIDriver:onTurnStart()
	self.turnIsDriving = true
	-- make sure turn has the current waypoint set to the the turn start wp
	-- TODO: refactor turn.lua so it does not assume the waypoint ix won't change
	courseplay:setWaypointIndex(self.vehicle, self.ppc:getCurrentOriginalWaypointIx())
	self:debug('Starting a turn.')
end

function AIDriver:onTurnEnd()
	self.turnIsDriving = false
	-- for now, we rely on turn.lua to set the next waypoint at the end of the turn and
	self.ppc:initialize()
	self:debug('Turn ended, continue at waypoint %d.', self.ppc:getCurrentWaypointIx())
end

---@param course Course
function AIDriver:setUpAlignmentCourse(course, ix)
	local x, _, z = course:getWaypointPosition(ix)
	-- to work with individual course waypoints here.
	local alignmentWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, x, z, math.rad( course:getWaypointAngleDeg(ix)), true)
	if not alignmentWaypoints then
		self:debug("Can't find an alignment course, may be too close to target wp?" )
		return nil
	end
	if #alignmentWaypoints < 3 then
		self:debug("Alignment course would be only %d waypoints, it isn't needed then.", #alignmentWaypoints )
		return nil
	end
	self:debug('Alignment course with %d waypoints started.', #alignmentWaypoints)
	return Course(self.vehicle, alignmentWaypoints)
end

function AIDriver:debug(...)
	courseplay.debugVehicle(self.debugChannel, self.vehicle, ...)
end

--- output debug message only at every debugTicks loop
function AIDriver:debugSparse(...)
	if g_updateLoopIndex % self.debugTicks == 0 then
		courseplay.debugVehicle(self.debugChannel, self.vehicle, ...)
	end
end

function AIDriver:isStopped()
	-- giants supplied last speed is in mm/s
	return math.abs(self.vehicle.lastSpeedReal) < 0.0001
end

function AIDriver:drawTemporaryCourse()
	if not self.temporaryCourse then return end
	if not courseplay.debugChannels[self.debugChannel] then return end
	for i = 1, self.temporaryCourse:getNumberOfWaypoints() - 1 do
		local x, y, z = self.temporaryCourse:getWaypointPosition(i)
		local nx, ny, nz = self.temporaryCourse:getWaypointPosition(i + 1)
		cpDebug:drawLine(x, y + 3, z, 100, 0, 100, nx, ny + 3, nz)
	end
end

function AIDriver:enableCollisionDetection()
	if courseplay.debugChannels[3] then
		self:debug('Collision detection enabled')
	else
		self:debug('Will stop on collision only if debug channel 3 is on')
	end
	self.collisionDetectionEnabled = true
	-- move the big collision box around the vehicle underground because this will stop
	-- traffic (not CP drivers though) around us otherwise
	if self.vehicle:getAINeedsTrafficCollisionBox() then
		self:debug("Making sure cars won't stop around us")
		-- something deep inside the Giants vehicle sets the translation of this box to whatever
		-- is in aiTrafficCollisionTranslation, if you do a setTranslation() it won't remain there...
		self.vehicle.spec_aiVehicle.aiTrafficCollisionTranslation[2] = -1000
	end
end

function AIDriver:disableCollisionDetection()
	self:debug('Collision detection disabled')
	self.collisionDetectionEnabled = false
	-- move the big collision box around the vehicle back over the ground so
	-- game traffic around us will stop while we are working on the field
	if self.vehicle:getAINeedsTrafficCollisionBox() then
		self:debug('Cars will stop around us again.')
		self.vehicle.spec_aiVehicle.aiTrafficCollisionTranslation[2] = 0
	end
end

function AIDriver:detectCollision(dt)
	-- if no detector yet, no problem, create it now.
	if not self.collisionDetector then
		self.collisionDetector = CollisionDetector(self.vehicle)
	end

	local isInTraffic, trafficSpeed = self.collisionDetector:getStatus(dt)

	if self.collisionDetectionEnabled then
		if trafficSpeed ~= 0 then
			--get the speed from the target vehicle
			self:setSpeed(trafficSpeed)
		end

		-- setting the speed to 0 won't slow us down fast enough so use the more effective allowedToDrive = false
		if isInTraffic then
			self:hold()
		end
	end

	if isInTraffic then
		self:setInfoText('TRAFFIC')
	else
		self:clearInfoText('TRAFFIC')
	end

end

function AIDriver:areBeaconLightsEnabled()
	return self.vehicle.cp.warningLightsMode > courseplay.lights.WARNING_LIGHTS_NEVER
end

function AIDriver:updateLights()
	if not self.vehicle.spec_lights then return end
	if self:areBeaconLightsEnabled() then
		self.vehicle:setBeaconLightsVisibility(true)
	else
		self.vehicle:setBeaconLightsVisibility(false)
	end
end

function AIDriver:onAIEnd(superFunc)
	if self.cp and self.cp.driver and self:getIsCourseplayDriving() then
		self.cp.driver.debug(self.cp.driver, 'overriding onAIEnd() to prevent engine stop')
	elseif superFunc ~= nil then
		superFunc(self)
	end
end
Motorized.onAIEnd = Utils.overwrittenFunction(Motorized.onAIEnd , AIDriver.onAIEnd)


