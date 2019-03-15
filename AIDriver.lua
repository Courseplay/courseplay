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
	courseplay.debugVehicle(11,vehicle,'AIDriver:init()') 
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
	self.pathfinder = Pathfinder()
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
	if not self:hasTipTrigger() then
		self:setSpeed(self:getRecordedSpeed())
	end
	
	if self:getIsInFilltrigger() then
		self:setSpeed(self.vehicle.cp.speeds.approach)
	end

	-- slow down before wait points
	if self.course:hasWaitPointAround(self.ppc:getCurrentOriginalWaypointIx(), 1, 2) then
		self:setSpeed(self.vehicle.cp.speeds.turn)
	end

	self:updatePathfinding()

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
	--- Check if we are at the last waypoint and should we continue with first waypoint of the course
	-- or stop.
	if ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	elseif self.course:isWaitAt(ix) then
		-- default behaviour for mode 5 (transport), if a waypoint with the wait attribute is
		-- passed stop until the user presses the continue button
		self:stop('WAIT_POINT')
		-- show continue button
		courseplay.hud:setReloadPageOrder(self.vehicle, 1, true);
	end
end

function AIDriver:onLastWaypoint()
	if self:onTemporaryCourse() then
		self:endTemporaryCourse(self.courseAfterTemporary, self.waypointIxAfterTemporary)
	else
		self:debug('Last waypoint reached, end of course.')
		self:onEndCourse()
	end
end

--- End a temporary course and then continue on nextCourse at nextWpIx
function AIDriver:endTemporaryCourse(nextCourse, nextWpIx)
	-- temporary course to the first waypoint ended, start the main course now
	self.ppc:setLookaheadDistance(PurePursuitController.normalLookAheadDistance)
	self:startCourse(nextCourse, nextWpIx)
	self.temporaryCourse = nil
	self:debug('Temporary course finished, starting next course at waypoint %d', nextWpIx)
	self:onEndTemporaryCourse()
end

function AIDriver:isWaiting()
	return self.state == self.states.STOPPED
end

function AIDriver:hasTipTrigger()
	return self.vehicle.cp.currentTipTrigger ~= nil
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
	local vx, _, vz = getWorldTranslation(self.vehicle.cp.DirectionNode or self.vehicle.rootNode)
	local alignmentWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, vx, vz, x, z, math.rad( course:getWaypointAngleDeg(ix)), true)
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
		cpDebug:drawPoint(x, y + 3, z, 10, 0, 0)
		cpDebug:drawLine(x, y + 3, z, 0, 0, 100, nx, ny + 3, nz)
	end
end

function AIDriver:enableCollisionDetection()
	courseplay.debugVehicle(3,self.vehicle,'Collision detection enabled')
	self.collisionDetectionEnabled = true
	-- move the big collision box around the vehicle underground because this will stop
	-- traffic (not CP drivers though) around us otherwise
	if self.vehicle:getAINeedsTrafficCollisionBox() then
		courseplay.debugVehicle(3,self.vehicle,"Making sure cars won't stop around us")
		-- something deep inside the Giants vehicle sets the translation of this box to whatever
		-- is in aiTrafficCollisionTranslation, if you do a setTranslation() it won't remain there...
		self.vehicle.spec_aiVehicle.aiTrafficCollisionTranslation[2] = -1000
	end
end

function AIDriver:disableCollisionDetection()
	courseplay.debugVehicle(3,self.vehicle,'Collision detection disabled')
	self.collisionDetectionEnabled = false
	-- move the big collision box around the vehicle back over the ground so
	-- game traffic around us will stop while we are working on the field
	if self.vehicle:getAINeedsTrafficCollisionBox() then
		courseplay.debugVehicle(3,self.vehicle,'Cars will stop around us again.')
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

function AIDriver:dischargeAtUnloadPoint(dt,unloadPointIx)
	local tipRefpoint = 0
	local stopForTipping = false
	local takeOverSteering = false
	local readyToDischarge = false
	local pullForward = false
	local vehicle = self.vehicle
	local uX,uY,uZ = self.course:getWaypointPosition(unloadPointIx)
	local unloadPointIsReverse = self.course:isReverseAt(unloadPointIx-1)
	
	if unloadPointIsReverse then
		for _, tipper in pairs (vehicle.cp.workTools) do
			if tipper.spec_dischargeable then	
				readyToDischarge = false
				tipRefpoint = tipper:getCurrentDischargeNode().node or tipper.rootNode
				nx,ny,nz = getWorldTranslation(tipRefpoint);
				local isTipping = tipper.spec_dischargeable.currentRaycastDischargeNode.isEffectActive
				_,_,z = worldToLocal(tipRefpoint, uX,uY,uZ);
				z = courseplay:isNodeTurnedWrongWay(vehicle,tipRefpoint)and -z or z

				local foundHeap = self:checkForHeapBehindMe(tipper)
				
				--when we reached the unload point, stop the tractor and inhibit any action from ppc till the trailer is empty
				if (foundHeap or z >= 0) and tipper.cp.fillLevel ~= 0 or tipper:getTipState() ~= Trailer.TIPSTATE_CLOSED then
					courseplay.debugVehicle(2,self.vehicle,'foundHeap(%s) or z(%s) >= 0  --> readyToDischarge ',tostring(foundHeap),tostring(z))
					stopForTipping = true
					readyToDischarge = true
				end

				--force tipper to tip to ground
				if (tipper:getTipState() == Trailer.TIPSTATE_CLOSED or tipper:getTipState() == Trailer.TIPSTATE_CLOSING) and readyToDischarge then
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
				end
				
				--if we can't tip here anymore, pull a bit further
				if tipper:getTipState() == Trailer.TIPSTATE_OPEN and not isTipping then
					self.pullForward = true
				end
				
				--when we can tip again, stop the movement
				if g_updateLoopIndex % 100 == 0 and self.pullForward and isTipping then
					self.pullForward = false
				end
				
				--ready with tipping, go forward on the course
				if tipper.cp.fillLevel == 0 then
					self.ppc:initialize(self.course:getNextFwdWaypointIx(self.ppc:getCurrentWaypointIx()));
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
					self.pullForward = nil
				end
				
				--do the driving here because if we initalize the ppc, we dont have the unload point anymore
				if self.pullForward then
					takeOverSteering = true
					local fwdWayoint = self.course:getNextFwdWaypointIxfromVehiclePosition(unloadPointIx,self.vehicle,self.ppc:getLookaheadDistance())
					local x,y,z = self.course:getWaypointPosition(fwdWayoint)
					--local x,z = vehicle.Waypoints[fwdWayoint].cx, vehicle.Waypoints[fwdWayoint].cz;
					--local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
					local lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, x, y, z);
					AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, true, true, lx, lz, 5, 1)
				end
			end
		end
		
	else
		for _, tipper in pairs (vehicle.cp.workTools) do
			readyToDischarge = false
			tipRefpoint = tipper:getCurrentDischargeNode().node or tipper.rootNode
			_,y,_ = getWorldTranslation(tipRefpoint);
			local isTipping = tipper.spec_dischargeable.currentRaycastDischargeNode.isEffectActive
			_,_,z = worldToLocal(tipRefpoint, uX,uY,uZ);
			z = courseplay:isNodeTurnedWrongWay(vehicle,tipRefpoint)and -z or z
			
			--when we reached the unload point, stop the tractor 
			if z <= 0 and tipper.cp.fillLevel ~= 0 then
				stopForTipping = true
				readyToDischarge = true
			end	
			--force tipper to tip to ground
			if (tipper:getTipState() == Trailer.TIPSTATE_CLOSED or tipper:getTipState() == Trailer.TIPSTATE_CLOSING) and readyToDischarge then
				tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
			end
			--if we can't tip here anymore, pull a bit further
			if tipper:getTipState() == Trailer.TIPSTATE_OPEN and not isTipping then
				stopForTipping = false
			end
		end
	end
	
	return not stopForTipping,takeOverSteering
end

function AIDriver:checkForHeapBehindMe(tipper)
	local dischargeNode = tipper:getCurrentDischargeNode().node
	local offset = -self.vehicle.cp.loadUnloadOffsetZ
	offset = courseplay:isNodeTurnedWrongWay(self.vehicle,dischargeNode)and -offset or offset
	local startX,startY,startZ = localToWorld(dischargeNode,0,0,offset) ;
	local tempHeightX,tempHeightY,tempHeightZ = localToWorld(dischargeNode,0,0,offset+0.5) 
	local searchWidth = 1	
	local fillType = DensityMapHeightUtil.getFillTypeAtLine(startX,startY,startZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
	if fillType == tipper.cp.fillType then
		return true;
	end
end

function AIDriver:dischargeAtTipTrigger(dt)
	local trigger = self.vehicle.cp.currentTipTrigger
	local allowedToDrive = true
	if trigger ~= nil then
		local isBGA = trigger.bunkerSilo ~= nil;
		if isBGA then
			if not self.ppc:isReversing() then
				--we are going forward into the BGA silo, so tip when I'm in and adjust the speed
				self:tipIntoBGASiloTipTrigger(dt)
			else
				--we are reversing into the BGA Silo. We are taking the last rev waypoint as virtual unloadpoint and start tipping there the same way as on unload point
				allowedToDrive, takeOverSteering = self:dischargeAtUnloadPoint(dt,self.course:getLastReverseAt(self.ppc:getCurrentWaypointIx()))     
			end
		else
			--using all standard tip triggers
			allowedToDrive = self:tipIntoStandardTipTrigger()
		end;
	end
	return allowedToDrive,takeOverSteering
end

function AIDriver:tipIntoStandardTipTrigger()
	local stopForTipping = false
	for _, tipper in pairs(self.vehicle.cp.workTools) do
		if tipper.spec_dischargeable ~= nil then
			for i=1,#tipper.spec_dischargeable.dischargeNodes do
				if tipper:getCanDischargeToObject(tipper.spec_dischargeable.dischargeNodes[i])then
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
					stopForTipping = true
				end
			end
		end
	end

	return not stopForTipping
end

function AIDriver:tipIntoBGASiloTipTrigger(dt)
	local trigger = self.vehicle.cp.currentTipTrigger
	for _, tipper in pairs (self.vehicle.cp.workTools) do
		if tipper.spec_dischargeable ~= nil and trigger ~= nil then
			--figure out , when i'm in the silo area
			local currentDischargeNode = tipper:getCurrentDischargeNode().node
			local x,y,z = getWorldTranslation(currentDischargeNode)
			local tx,ty,tz = x,y,z+1
			local x1,z1 = trigger.bunkerSiloArea.sx,trigger.bunkerSiloArea.sz
			local x2,z2 = trigger.bunkerSiloArea.wx,trigger.bunkerSiloArea.wz
			local x3,z3 = trigger.bunkerSiloArea.hx,trigger.bunkerSiloArea.hz
			local trailerInTipRange = MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z)
			
			--tip when I'm inside the Silo
			if trailerInTipRange then
				if not self.unloadSpeed then
					--calculate the speed needed to unload in this silo
					local sx, sy, sz = worldToLocal(trigger.triggerStartId, x, y, z);
					local ex, ey, ez = worldToLocal(trigger.triggerEndId, x, y, z);
					local totalLength = courseplay:distance3D(sx, sy, sz, ex, ey, ez)
					local dischargeNode = tipper:getCurrentDischargeNode()
					local totalTipDuration = ((tipper.cp.fillLevel / dischargeNode.emptySpeed )/ 1000) + 2 --adding 2 sec for the time between setting tipstate and start of real unloading
					local meterPrSeconds = totalLength / totalTipDuration;
					self.unloadSpeed = meterPrSeconds*3.6
					courseplay.debugVehicle(2,self.vehicle,'%s in mode %s: entering BGASilo:',tostring(tipper.getName and tipper:getName() or 'no name'), tostring(self.vehicle.cp.mode))
					courseplay.debugVehicle(2,self.vehicle,'emptySpeed: %sl/sek; fillLevel: %0.1fl',tostring(dischargeNode.emptySpeed*1000),tipper.cp.fillLevel)
					courseplay.debugVehicle(2,self.vehicle,'Silo length: %sm/Total unload time: %ss *3.6 = unload speed: %.2fkmh',tostring(totalLength) ,tostring(totalTipDuration),self.unloadSpeed)
				end
				
				local tipState = tipper:getTipState()
				if tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING then
					courseplay.debugVehicle(2,self.vehicle,"start tipping")
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
				end				
			else
				if self.unloadSpeed then
					courseplay.debugVehicle(2,self.vehicle,"reset self.unloadSpeed")
				end
				self.unloadSpeed = nil
			end
			self.speed = self.unloadSpeed or self.speed
		end
	end

end

function AIDriver:searchForTipTriggers()
	if not self.vehicle.cp.hasAugerWagon
		and not self:hasTipTrigger()
		and self.vehicle.cp.totalFillLevel > 0
		and self.ppc:getCurrentWaypointIx() > 2
		and not self.ppc:reachedLastWaypoint()
		and not self.ppc:isReversing() then
		local raycastDistance = 10
		local dx,dz = self.course:getDirectionToWPInDistance(self.ppc:getCurrentWaypointIx(),self.vehicle,raycastDistance)
		local x,y,z,nx,ny,nz = courseplay:getTipTriggerRaycastDirection(self.vehicle,dx,dz,raycastDistance)	
		courseplay:doTriggerRaycasts(self.vehicle, 'tipTrigger', 'fwd', true, x, y, z, nx, ny, nz,raycastDistance)
	end
end

function AIDriver:onUnLoadCourse(allowedToDrive, dt)
	-- Unloading
	local takeOverSteering = false
	local isNearUnloadPoint, unloadPointIx = self.course:hasUnloadPointWithinDistance(self.ppc:getCurrentWaypointIx(),20)
	self:setSpeed(self:getRecordedSpeed())
	
	--handle cover 
	if self:hasTipTrigger() or isNearUnloadPoint then
		courseplay:openCloseCover(self.vehicle, not courseplay.SHOW_COVERS)
	end
	-- done tipping?
	if self:hasTipTrigger() and self.vehicle.cp.totalFillLevel == 0 then
		courseplay:resetTipTrigger(self.vehicle, true);
	end

	self:cleanUpMissedTriggerExit()

	-- tipper is not empty and tractor reaches TipTrigger
	if self.vehicle.cp.totalFillLevel > 0
		and self:hasTipTrigger()
		and not self:isNearFillPoint() then
		self:setSpeed(self.vehicle.cp.speeds.approach)
		allowedToDrive, takeOverSteering = self:dischargeAtTipTrigger(dt)
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
	end
	-- tractor reaches unloadPoint
	if isNearUnloadPoint then
		self:setSpeed(self.vehicle.cp.speeds.approach)
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
		allowedToDrive, takeOverSteering = self:dischargeAtUnloadPoint(dt,unloadPointIx)
	end
	return allowedToDrive, takeOverSteering;
end;


function AIDriver:cleanUpMissedTriggerExit() -- at least that's what it seems to be doing
	-- damn, I missed the trigger!
	if self:hasTipTrigger() then
		local t = self.vehicle.cp.currentTipTrigger;
		local trigger_id = t.triggerId;

		if t.specialTriggerId ~= nil then
			trigger_id = t.specialTriggerId;
		end;
		if t.isPlaceableHeapTrigger then
			trigger_id = t.rootNode;
		end;

		if trigger_id ~= nil then
			local trigger_x, _, trigger_z = getWorldTranslation(trigger_id)
			local ctx, _, ctz = getWorldTranslation(self.vehicle.cp.DirectionNode)
			local distToTrigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z)

			-- Start reversing value is to check if we have started to reverse
			-- This is used in case we already registered a tipTrigger but changed the direction and might not be in that tipTrigger when unloading. (Bug Fix)
			local startReversing = self.course:switchingToReverseAt(self.ppc:getCurrentWaypointIx() - 1)
			if startReversing then
				courseplay:debug(string.format(2,"%s: Is starting to reverse. Tip trigger is reset.", nameNum(self.vehicle)), 13);
			end

			local isBGA = t.bunkerSilo ~= nil
			local triggerLength = Utils.getNoNil(self.vehicle.cp.currentTipTrigger.cpActualLength, 20)
			local maxDist = isBGA and (self.vehicle.cp.totalLength + 55) or (self.vehicle.cp.totalLength + triggerLength);
			if distToTrigger > maxDist or startReversing then --it's a backup, so we don't need to care about +/-10m
				courseplay:resetTipTrigger(self.vehicle)
				courseplay.debugVehicle(1,self.vehicle,"%s: distance to currentTipTrigger = %d (> %d or start reversing) --> currentTipTrigger = nil", nameNum(self.vehicle), distToTrigger, maxDist);
			end
		else
			courseplay:resetTipTrigger(self.vehicle)
		end;
	end;
end

--- Update the unload offset from the current settings and apply it when needed
function AIDriver:updateOffset()
	local currentWaypointIx = self.ppc:getCurrentWaypointIx()
	local useOffset = false

	if not self.vehicle.cp.hasAugerWagon and (currentWaypointIx > self.course:getNumberOfWaypoints() - 6 or currentWaypointIx <= 4) then
		-- around the fill trigger (don't understand the auger wagon part though)
		useOffset = true
	elseif self.course:hasWaitPointAround(currentWaypointIx, 6, 3) then
		-- around wait points
		useOffset = true
	elseif self.course:hasUnloadPointAround(currentWaypointIx, 6, 3) then
		-- around unload points
		useOffset = true
	end

	if useOffset then
		self.ppc:setOffset(self.vehicle.cp.loadUnloadOffsetX, self.vehicle.cp.loadUnloadOffsetZ)
	else
		self.ppc:setOffset(0, 0)
	end
end

------------------------------------------------------------------------------
--- PATHFINDING
------------------------------------------------------------------------------

--- Start course (with pathfinding if needed) and set course as the current one
--- Will find a path on a field avoiding fruit as far as possible from the
--- current position to the start of course.
---@param course Course
---@param ix number
---@param vehicleIsOnField boolean use the vehicle's position to determine for which field
-- we need a path. If false, we assume that the course's waypoint at ix is on the field.
---@return boolean true when an alignment course was added
function AIDriver:startCourseWithPathfinding(course, ix, vehicleIsOnField)
	self.turnIsDriving = false
	if self.vehicle.cp.realisticDriving then
		local vx, _, vz = getWorldTranslation(self.vehicle.rootNode)
		local tx, _, tz = course:getWaypointPosition(ix)

		local fieldNum
		if vehicleIsOnField then
			-- vehicle is on field, target waypoint may be out of field
			fieldNum = courseplay.fields:getFieldNumForPosition(vx, vz)
			tx, tz = self:getClosestPointOnFieldBoundary(tx, tz, fieldNum)
		else
			-- target waypoint is on field, vehicle may be off field
			fieldNum = courseplay.fields:getFieldNumForPosition(tx, tz)
			vx, vz = self:getClosestPointOnFieldBoundary(vx, vz, fieldNum)
		end
		if fieldNum > 0 then
			if not self.pathfinder:isActive() then
				self:debug('Start pathfinding on field %d', fieldNum)
				self.waypointIxAfterPathfinding = ix
				self.courseAfterPathfinding = course
				self.pathFindingStartedAt = self.vehicle.timer
				-- TODO: move this coordinate transformation into the pathfinder, it is internal
				local done, path = self.pathfinder:start({x = vx, y = -vz}, {x = tx, y = -tz},
					Polygon:new(courseGenerator.pointsToXy(courseplay.fields.fieldData[fieldNum].points)))
				if done then
					return self:onPathfindingDone(path)
				end
			else
				self:debug('Pathfinder already active')
			end
			return true
		else
			self:debug('Do not know which field I am on, falling back to alignment course')
		end
	else
		self:debug('Pathfinding turned off, falling back to alignment course')
	end
	return self:startCourseWithAlignment(course, ix)
end

function AIDriver:updatePathfinding()
	if self.pathfinder:isActive() then
		-- stop while pathfinding is running
		self:setSpeed(0)
		local done, path = self.pathfinder:resume()
		if done then
			self:onPathfindingDone(path)
		end
	end
end

--- If we have a path now then set it up as a temporary course, also appending an alignment between the end
--- of the path and the target course
---@return boolean true if a temporary course (path/align) is started, false otherwise
function AIDriver:onPathfindingDone(path)
	if path and #path > 5 then
		self:debug('Pathfinding finished with %d waypoints (%d ms)', #path, self.vehicle.timer - (self.pathFindingStartedAt or 0))
		local temporaryCourse = Course(self.vehicle, courseGenerator.pointsToXz(path))
		-- first remove a few waypoints from the path so we have room for the alignment course
		if temporaryCourse:getLength() > self.vehicle.cp.turnDiameter * 3 and temporaryCourse:shorten(self.vehicle.cp.turnDiameter * 1.5) then
			self:debug('Path shortened to accommodate alignment, has now %d waypoints', temporaryCourse:getNumberOfWaypoints())
			-- append an alignment course at the end of the path to the target waypoint
			local x, _, z = temporaryCourse:getWaypointPosition(temporaryCourse:getNumberOfWaypoints())
			local tx, _, tz = self.courseAfterPathfinding:getWaypointPosition(self.waypointIxAfterPathfinding)
			local alignmentWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, x, z, tx, tz,
				math.rad(self.courseAfterPathfinding:getWaypointAngleDeg(self.waypointIxAfterPathfinding)), true)
			if alignmentWaypoints then
				self:debug('Append an alignment course with %d waypoints to the path', #alignmentWaypoints)
				temporaryCourse:append(alignmentWaypoints)
			else
				self:debug('Could not append an alignment course to the path')
			end
			self:startTemporaryCourse(temporaryCourse, self.courseAfterPathfinding, self.waypointIxAfterPathfinding)
			return true
		else
			return self:onNoPathFound('Path too short, reverting to alignment course.')
		end
	else
		if path then
			return self:onNoPathFound('Path found but too short (%d), reverting to alignment course.', #path)
		else
			return self:onNoPathFound('Pathfinding finished, no path found, reverting to alignment course')
		end
	end
end

---@return boolean true if a temporary course is started
function AIDriver:onNoPathFound(...)
	self:debug(...)
	if not self:startCourseWithAlignment(self.courseAfterPathfinding, self.waypointIxAfterPathfinding) then
		-- no alignment course needed or possible, skip to the end of temp course to continue on the normal course
		self:endTemporaryCourse(self.courseAfterPathfinding, self.waypointIxAfterPathfinding)
		return false
	else
		return true
	end
end

function AIDriver:getClosestPointOnFieldBoundary(x, z, fieldNum)
	-- theoretically x/z could be on a _different_ field, but for now we ignore that case
	if fieldNum > 0 and not courseplay:isField(x, z) then
		-- the pathfinder needs both from/to positions to be on the field so if a  point is not on the
		-- field, we need to use the closest point on the field boundary instead.
		local closestPointToTargetIx = courseplay.generation:getClosestPolyPoint(courseplay.fields.fieldData[fieldNum].points, x, z)
		return courseplay.fields.fieldData[ fieldNum ].points[ closestPointToTargetIx ].cx,
		courseplay.fields.fieldData[ fieldNum ].points[ closestPointToTargetIx ].cz
	else
		return x, z
	end
end

