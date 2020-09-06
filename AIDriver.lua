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
•	Drive turn maneuvers
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

-- steering angle (normalized, between 0 and 1) over which the speed is reduced
AIDriver.slowAngleLimit = 0.3
AIDriver.slowAcceleration = 0.5
AIDriver.slowDownFactor = 0.5

-- Proximity sensor
-- how far the sensor can see
AIDriver.proximitySensorRange = 10
-- the sensor will proportionally reduce speed when objects are in range down to this limit (won't set a speed lower than this)
AIDriver.proximityMinLimitedSpeed = 2
-- if anything closer than this, we stop
AIDriver.proximityLimitLow = 1

AIDriver.APPROACH_AUGER_TRIGGER_SPEED = 3
AIDriver.EMERGENCY_BRAKE_FORCE = 1000000
-- we use this as an enum
AIDriver.myStates = {
	TEMPORARY = {}, -- Temporary course, dynamically generated, for example alignment or fruit avoidance
	RUNNING = {},
	STOPPED = {},
	DONE = {}
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
	-- set up a global container on the vehicle to persist AI Driver related data between AIDriver incarnations
	if not vehicle.cp.aiDriverData then
		vehicle.cp.aiDriverData = {}
	end
	self.aiDriverData = vehicle.cp.aiDriverData
	self:debug('creating AIDriver')
	self.maxDrivingVectorLength = self.vehicle.cp.turnDiameter
	---@type PurePursuitController
	self.ppc = PurePursuitController(self.vehicle)
	self.vehicle.cp.ppc = self.ppc
	self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
	self.ppc:enable()
	self.nextWpIx = 1
	self.acceleration = 1
	self.state = self.states.STOPPED
	self.debugTicks = 100 -- show sparse debug information only at every debugTicks update
	-- AIDriver and its derived classes set the self.speed in various locations in
	-- the code and then getSpeed() will pass that on to AIDriver.driveCourse.
	self.speed = 0
	-- same for allowedToDrive, is reset at the end of each loop to true and needs to be set to false
	-- if someone wants to stop by calling hold()
	self.allowedToDrive = true
	self.collisionDetectionEnabled = true
	self.collisionDetector = nil
	-- list of active messages to display
	self.activeMsgReferences = {}
	-- make sure all vehicle settings are valid for this mode
	if self.vehicle.cp.settings then
		self:debug('Validating current settings...')
		self.vehicle.cp.settings:validateCurrentValues()
	end
	self:setHudContent()
	self.triggerHandler = TriggerHandler(self,self.vehicle,self:getSiloSelectedFillTypeSetting())
	self.triggerHandler:enableFuelLoading()
end

function AIDriver:updateLoadingText()
	local fillableObject = self.triggerHandler.fillableObject
	if fillableObject then
		local fillLevel = fillableObject.object:getFillUnitFillLevel(fillableObject.fillUnitIndex)
		local fillCapacity = fillableObject.object:getFillUnitCapacity(fillableObject.fillUnitIndex)
		if fillLevel and fillCapacity then
			if fillableObject.isLoading then 
				courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",math.floor(fillLevel),fillCapacity))
			else
				courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_UNLOADING_AMOUNT;%d;%d",math.floor(fillLevel),fillCapacity))
			end
		end
	end
end

function AIDriver:writeUpdateStream(streamId)
	self.triggerHandler:writeUpdateStream(streamId)
	streamWriteString(streamId,self.state.name)
	streamWriteBool(streamId,self.active)
--	streamWriteBool(streamId,self.vehicle.cp.isDriving)
end 

function AIDriver:readUpdateStream(streamId)
	self.triggerHandler:readUpdateStream(streamId)
	local nameState = streamReadString(streamId)
	self.state = self.states[nameState]
	self.active = streamReadBool(streamId)
--	self.vehicle.cp.isDriving = streamReadBool(streamId)
end

function AIDriver:postSync()

end

function AIDriver:setHudContent()
	courseplay.hud:setAIDriverContent(self.vehicle)
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
	for key, _ in pairs(states) do
		self.states[key] = {name = tostring(key)}
	end
end

function AIDriver:getMode()
	return self.mode
end

--- If you have your own start() implementation and you do not call AIDriver.start() then
-- make sure this is called from the derived start() to initialize all common stuff
function AIDriver:beforeStart()
	self.active = true
	self.nextCourse = nil
	if self.collisionDetector == nil then
		self.collisionDetector = CollisionDetector(self.vehicle)
	end
	self.normalBrakeForce = self.vehicle.spec_motorized.brakeForce
	self:setBackMarkerNode(self.vehicle)
	self:setFrontMarkerNode(self.vehicle)

	self:startEngineIfNeeded()
	self:initWages()
	self.firstReversingWheeledWorkTool = courseplay:getFirstReversingWheeledWorkTool(self.vehicle)
	-- for now, pathfinding generated courses can't be driven by towed tools
	self.allowReversePathfinding = self.firstReversingWheeledWorkTool == nil
	if self.vehicle:getAINeedsTrafficCollisionBox() then
		courseplay.debugVehicle(3,self.vehicle,"Making sure cars won't stop around us")
		-- something deep inside the Giants vehicle sets the translation of this box to whatever
		-- is in aiTrafficCollisionTranslation, if you do a setTranslation() it won't remain there...
		self.vehicle.spec_aiVehicle.aiTrafficCollisionTranslation[2] = -1000
	end
	self.triggerHandler:onStart()
end

--- Start driving
--- @param startingPoint number, one of StartingPointSetting.START_AT_* constants
function AIDriver:start(startingPoint)
	self:beforeStart()
	self.state = self.states.RUNNING
	-- derived classes must disable collision detection if they don't need its
	self:enableCollisionDetection()
	-- for now, initialize the course with the vehicle's current course
	-- main course is the one generated/loaded/recorded
	self.mainCourse = Course(self.vehicle, self.vehicle.Waypoints)
	local ix = self.mainCourse:getStartingWaypointIx(AIDriverUtil.getDirectionNode(self.vehicle), startingPoint)
	self:info('AI driver in mode %d starting at %d/%d waypoints (%s)',
			self:getMode(), ix, self.mainCourse:getNumberOfWaypoints(), tostring(startingPoint))
	self:startCourseWithAlignment(self.mainCourse, ix)
end

--- Dismiss the driver
function AIDriver:dismiss()
	if self.collisionDetector then
		self.collisionDetector:reset()		-- restore the default direction of the colli boxes
	end
	self:resetTrafficControl()
	self.vehicle:setBeaconLightsVisibility(false)
	self:clearAllInfoTexts()
	self:stop()
	self.active = false
end

--- Is the driver started?
function AIDriver:isActive()
	return self.active
end

--- Stop the driver
--- @param msgReference string as defined in globalInfoText.msgReference
function AIDriver:stop(msgReference)
	self:deleteCollisionDetector()
	self.triggerHandler:onStop()
	-- not much to do here, see the derived classes
	self:setInfoText(msgReference)
	self.state = self.states.STOPPED
end

--- Stop the driver when the work is done. Could just dismiss at this point,
--- the only reason we are still active is that we are displaying the info text while waiting to be dismissed
function AIDriver:setDone(msgReference)
	self:deleteCollisionDetector()
	self:setInfoText(msgReference)
	self.state = self.states.DONE
end

function AIDriver:continue()
	self:debug('Continuing...')
	self.state = self.states.RUNNING
	self.triggerHandler:onContinue()
	-- can be stopped for various reasons and those can have different msgReferences, so
	-- just remove all, if there's a condition which requires a message it'll call setInfoText() again anyway.
	self:clearAllInfoTexts()
end

--- Compatibility function for the legacy CP code so the course can be resumed
-- at the index as originally was in vehicle.Waypoints.
function AIDriver:resumeAtOriginalIx(cpIx)
	local i = self.course:findOriginalIx(cpIx)
	self:debug('resumeAtOriginalIx %d (legacy) %d (AIDriver', cpIx, i)
	self.ppc:initialize(i)
end

function AIDriver:resumeAt(ix)
	self.ppc:initialize(ix)
end

--- @param msgReference string as defined in globalInfoText.msgReference
function AIDriver:setInfoText(msgReference)
	if msgReference then
		self:debugSparse('set info text to %s', msgReference)
		self.activeMsgReferences[msgReference] = true
	end
end

--- @param msgReference string as defined in globalInfoText.msgReference
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

--- Update AI driver, everything that needs to run in every loop
function AIDriver:update(dt)
	self:updateProximitySensors()
	self:updatePathfinding()
	self:drive(dt)
	self:checkIfBlocked()
	self:payWages(dt)
	self:detectSlipping()
	self:resetSpeed()
	self:updateLoadingText()
	self.triggerHandler:onUpdate(dt)
end

--- UpdateTick AI driver
function AIDriver:updateTick(dt)
	self.triggerHandler:onUpdateTick(dt)
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

	if self.state == self.states.STOPPED or self.triggerHandler:isLoading() or self.triggerHandler:isUnloading() then
		self:hold()
		self:continueIfWaitTimeIsOver()
	end
	self:driveCourse(dt)
	self:drawTemporaryCourse()
end

--- Normal driving according to the course waypoints, using	 courseplay:goReverse() when needed
-- to reverse with trailer.
function AIDriver:driveCourse(dt)
	self:updateLights()
	-- check if reversing
	local lx, lz, moveForwards, isReverseActive = self:getReverseDrivingDirection()
	-- stop for fuel if needed
	if not self:checkFuel() then 
		self:hold()
	end
	if not self:getIsEngineReady() then
		if self:getSpeed() > 0 and self.allowedToDrive then
			self:startEngineIfNeeded()
			self:hold()
			self:debugSparse('Wait for the engine to start')
		end
	end
	-- use the recorded speed by default
	if not self:hasTipTrigger() then
		self:setSpeed(self:getRecordedSpeed())
	end
	local isInTrigger, isAugerWagonTrigger = self.triggerHandler:isInTrigger()
	if self:getIsInFilltrigger() or isInTrigger then
		self:setSpeed(self.vehicle.cp.speeds.approach)
		if isAugerWagonTrigger then 
			self:setSpeed(self.APPROACH_AUGER_TRIGGER_SPEED)
		end
	end
	
	self:slowDownForWaitPoints()

	self:stopEngineIfNotNeeded()

	if isReverseActive then
		-- we go wherever goReverse() told us to go
		self:driveVehicleInDirection(dt, self.allowedToDrive, moveForwards, lx, lz, self:getSpeed())
	elseif self.useDirection then
		lx, lz = self.ppc:getGoalPointDirection()
		self:debug('%.1f %.1f', lx, lz)
		self:driveVehicleInDirection(dt, self.allowedToDrive, moveForwards, lx / 2, lz, self:getSpeed())
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
	if AIDriverUtil.isReverseDriving(self.vehicle) then
		self:debugSparse('reverse driving, reversing steering')
		ax = -ax
	end
		-- TODO: remove allowedToDrive parameter and only use self.allowedToDrive
	if not self.allowedToDrive then allowedToDrive = false end

	maxSpeed, allowedToDrive = self:checkProximitySensor(maxSpeed, allowedToDrive, moveForwards)

	-- driveToPoint does not like speeds under 1.5 (will stop) so make sure we set at least 2
	if maxSpeed > 0.01 and maxSpeed < 2 then
		maxSpeed = 2
	end
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

--- Drive vehicle by using a steering angle. This is similar to the Giants AIVehicleUtil.driveInDirection() but
--- instead of the direction (lx, lz) uses a steering angle.
--- @param dt number dt
--- @param moveForwards boolean if true, we want the vehicle to move forwards, false for backwards
--- @param steeringAngleNormalized number between 0 and 1, 1 being the maximum steering angle.
--- @param turnLeft boolean true when turning to the left
--- @param maxSpeed number speed we want the vehicle to drive
function AIDriver:driveVehicleBySteeringAngle(dt, moveForwards, steeringAngleNormalized, turnLeft, maxSpeed)
	if not moveForwards then
		turnLeft = not turnLeft;
	end
	-- flip it again if in reverse driving vehicle
	if AIDriverUtil.isReverseDriving(self.vehicle) then
		turnLeft = not turnLeft;
	end
	local targetRotTime = 0;
	if turnLeft then
		--rotate to the left
		targetRotTime = self.vehicle.maxRotTime*math.min(steeringAngleNormalized, 1);
	else
		--rotate to the right
		targetRotTime = self.vehicle.minRotTime*math.min(steeringAngleNormalized, 1);
	end
	if targetRotTime > self.vehicle.rotatedTime then
		self.vehicle.rotatedTime = math.min(self.vehicle.rotatedTime + dt*self.vehicle:getAISteeringSpeed(), targetRotTime);
	else
		self.vehicle.rotatedTime = math.max(self.vehicle.rotatedTime - dt*self.vehicle:getAISteeringSpeed(), targetRotTime);
	end
	if self.vehicle.firstTimeRun then
		local acc = self.acceleration;
		
		maxSpeed, self.allowedToDrive = self:checkProximitySensor(maxSpeed, self.allowedToDrive, moveForwards)

		if maxSpeed ~= nil and maxSpeed ~= 0 then
			if steeringAngleNormalized >= self.slowAngleLimit then
				maxSpeed = maxSpeed * self.slowDownFactor;
			end
			self.vehicle.spec_motorized.motor:setSpeedLimit(maxSpeed);
			if self.vehicle.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
				self.vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
			end
		else
			if steeringAngleNormalized >= self.slowAngleLimit then
				acc = self.slowAcceleration;
			end
		end
		if not self.allowedToDrive or math.abs(maxSpeed) < 0.0001 then
			acc = 0;
		end
		if not moveForwards then
			acc = -acc;
		end
		WheelsUtil.updateWheelsPhysics(self.vehicle, dt, self.vehicle.lastSpeedReal*self.vehicle.movingDirection, acc, not self.allowedToDrive, true)
	end
end

-- node pointing in the direction the driver is facing, even in case of reverse driving tractors
function AIDriver:getDirectionNode()
	return AIDriverUtil.getDirectionNode(self.vehicle)
end

--- Start a course and continue with nextCourse at ix when done
---@param tempCourse Course
---@param nextCourse Course
---@param ix number
function AIDriver:startCourse(course, ix, nextCourse, nextWpIx)
	if nextWpIx then
		self:debug('Starting a course, at waypoint %d, will continue at waypoint %d afterwards.', ix, nextWpIx)
	else
		self:debug('Starting a course, at waypoint %d, no next course set.', ix)
	end
	self:resetTrafficControl()
	self.nextWpIx = nextWpIx
	self.nextCourse = nextCourse
	self.course = course
	self.ppc:setCourse(self.course)
	self.ppc:initialize(ix)
end

function AIDriver:getCurrentCourse()
	return self.course
end

--- Start course (with alignment if needed) and set course as the current one
---@param course Course
---@param ix number
---@return boolean true when an alignment course was added
function AIDriver:startCourseWithAlignment(course, ix)
	local alignmentCourse
	if self:isAlignmentCourseNeeded(course, ix) then
		alignmentCourse = self:setUpAlignmentCourse(course, ix)
	end
	if alignmentCourse then
		self:startCourse(alignmentCourse, 1, course, ix)
	else
		self:startCourse(course, ix)
	end
	return alignmentCourse
end



--- Do whatever is needed after switching to the next course
function AIDriver:onNextCourse()
	-- nothing in general, derived classes will implement when needed
end

--- Course ended
function AIDriver:onEndCourse()
	if self.vehicle.cp.settings.autoDriveMode:useForParkVehicle() then
		-- use AutoDrive to send the vehicle to its parking spot
		if self.vehicle.spec_autodrive and self.vehicle.spec_autodrive.GetParkDestination then
			self:debug('Let AutoDrive park this vehicle')
			-- we are not needed here anymore
			courseplay:stop(self.vehicle)
			-- TODO: encapsulate this in an AutoDriveInterface class
			local parkDestination = self.vehicle.spec_autodrive:GetParkDestination(self.vehicle)
			self.vehicle.spec_autodrive:StartDrivingWithPathFinder(self.vehicle, parkDestination, -3, nil, nil, nil)
		end
	elseif self.vehicle.cp.settings.stopAtEnd:is(true) then
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
	return AIVehicleUtil.getDriveDirection(self:getDirectionNode(), gx, gy, gz);
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
		self:setSpeed(self.vehicle.cp.speeds.reverse or self.vehicle.cp.speeds.crawl)
	end
	return lx, lz, moveForwards, isReverseActive
end

function AIDriver:onWaypointChange(newIx)
	-- for backwards compatibility, we keep the legacy CP waypoint index up to date
	courseplay:setWaypointIndex(self.vehicle, self.ppc:getCurrentOriginalWaypointIx())
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
		-- passed stop until the user presses the continue button or the timer elapses
		self:debug('Waiting point reached, wait time %d s', self.vehicle.cp.waitTime)
		self:stop('WAIT_POINT')		
		-- show continue button
		self:refreshHUD()
	end
end

function AIDriver:onLastWaypoint()
	if self.nextCourse then
		self:continueOnNextCourse(self.nextCourse, self.nextWpIx)
	else
		self:debug('Last waypoint reached, end of course.')
		self:onEndCourse()
	end
end

--- End a course and then continue on nextCourse at nextWpIx
function AIDriver:continueOnNextCourse(nextCourse, nextWpIx)
	self:startCourse(nextCourse, nextWpIx)
	self:debug('Starting next course at waypoint %d', nextWpIx)
	self:onNextCourse(nextWpIx)
end

--- When stopped at a wait point, check if the waiting time is over
-- and continue when needed
function AIDriver:continueIfWaitTimeIsOver()
	if self:isAutoContinueAtWaitPointEnabled() then
		if (self.vehicle.timer - self.lastMoveCommandTime) > self.vehicle.cp.waitTime * 1000 then
			self:debug('Waiting time of %d s is over, continuing', self.vehicle.cp.waitTime)
			self:continue()
		end
	end
end

--- Is automatically continuing after stopped at a waypoint enabled? This is the default behavior in
--- mode 5 when there's a wait time set. As long as the waitpoint is used for other purposes in other modes,
--- those modes have to override this.
-- TODO: consider deriving a TransportAIDriver class for mode 5 if there are mode 5 only behaviors.
function AIDriver:isAutoContinueAtWaitPointEnabled()
	return self.vehicle.cp.waitTime > 0
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

--- Speed on the field when not working
function AIDriver:getFieldSpeed()
	return self.vehicle.cp.speeds.field
end

--- Speed on the field when working
function AIDriver:getWorkSpeed()
	-- use the speed limit supplied by Giants for fieldwork
	local speedLimit = self.vehicle:getSpeedLimit() or math.huge
	return math.min(self.vehicle.cp.speeds.field, speedLimit)
end

function AIDriver:resetLastMoveCommandTime()
	self.lastMoveCommandTime = self.vehicle.timer
end

--- Don't auto stop engine. Keep calling this when you do something where the vehicle has a planned stop for a while
--- and you don't want to engine auto stop to engage (for example waiting in the convoy)
function AIDriver:overrideAutoEngineStop()
	self:resetLastMoveCommandTime()
end

--- Reset drive controls at the end of each loop
function AIDriver:resetSpeed()
	if self.speed > 0 and self.allowedToDrive then
		self:resetLastMoveCommandTime()
		if self.vehicle:getLastSpeed() > 0.5 then
			self.lastRealMovingTime = self.vehicle.timer
			self.stoppedButShouldBeMoving = false
		elseif not self.stoppedButShouldBeMoving then
			self.stoppedMovingAt = self.vehicle.timer
			self.stoppedButShouldBeMoving = true
		end
	else
		self.stoppedButShouldBeMoving = false
		self.lastStopCommandTime = self.vehicle.timer
	end
	-- reset speed limit for the next loop
	self.speed = math.huge
	self.allowedToDrive = true
end

--- Anyone wants to temporarily stop driving for whatever reason, call this
function AIDriver:hold()
	self.allowedToDrive = false
	-- prevent detecting this state as blocked. TODO: rethink this whole blocking logic, is now confusing as hell
	self:resetLastMoveCommandTime()
end

--- Function used by the driver to get the speed it is supposed to drive at
--
function AIDriver:getSpeed()
	return self.speed or 15
end

function AIDriver:getTotalLength()
	return self.vehicle.cp.totalLength
end

--- Get waypoint closest to the current position of the vehicle
function AIDriver:getRelevantWaypointIx()
	return self.ppc:getRelevantWaypointIx()
end

function AIDriver:getRecordedSpeed()
	-- default is the street speed (reduced in corners)
	local speed = self:getDefaultStreetSpeed(self.ppc:getCurrentWaypointIx()) or self.vehicle.cp.speeds.street
	if self.vehicle.cp.settings.useRecordingSpeed:is(true) then
		-- use default street speed if there's no recorded speed.
		speed = math.min(self.course:getAverageSpeed(self.ppc:getCurrentWaypointIx(), 4) or speed, speed)
	end
	return speed
end

-- get a default street speed in case there's no recorded speed. Slow down in corners and at the end of the course
function AIDriver:getDefaultStreetSpeed(ix)
	-- reduce speed before the end of the course
	local dToEnd = self.course:getDistanceToLastWaypoint(ix)
	if dToEnd < 15 then
		-- TODO make this smoother depending on the remaining distance?
		return self.vehicle.cp.speeds.turn
	end
	local radius = self.course:getMinRadiusWithinDistance(ix, 15)
	if radius then
		return math.max(self.vehicle.cp.speeds.turn, math.min(radius / 20 * self.vehicle.cp.speeds.street, self.vehicle.cp.speeds.street))
	end
end

function AIDriver:slowDownForWaitPoints()
	if self.course:hasWaitPointAround(self.ppc:getCurrentOriginalWaypointIx(), 1, 2) then
		self:setSpeed(self.vehicle.cp.speeds.turn)
	end
end

-- TODO: review this whole fillpoint/filltrigger thing.
function AIDriver:isNearFillPoint()
	if self.course == nil then
		return false
	else
		return self.course:havePhysicallyPassedWaypoint(self:getDirectionNode(),#self.course.waypoints) and self.ppc:getCurrentWaypointIx() <= 5;
	end
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

function AIDriver:startTurn(ix)
	self:debug('Attempting to starting a turn which is not implemented in this mode')
end

---@param course Course
function AIDriver:setUpAlignmentCourse(course, ix)
	local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(AIDriverUtil.getDirectionNode(self.vehicle), 0, 0)
	local start = State3D(x, -z, courseGenerator.fromCpAngle(yRot))
	x, _, z = course:getWaypointPosition(ix)
	local goal = State3D(x, -z, courseGenerator.fromCpAngle(math.rad(course:getWaypointAngleDeg(ix))))
	local turnRadius = AIDriverUtil.getTurningRadius(self.vehicle)

	local solution
	if self.allowReversePathfinding then
		solution = PathfinderUtil.reedSheppSolver:solve(start, goal, turnRadius)
	else
		solution = PathfinderUtil.dubinsSolver:solve(start, goal, turnRadius)
	end

	local alignmentWaypoints = solution:getWaypoints(start, turnRadius)
	if not alignmentWaypoints then
		self:debug("Can't find an alignment course, may be too close to target wp?" )
		return nil
	end
	if #alignmentWaypoints < 3 then
		self:debug("Alignment course would be only %d waypoints, it isn't needed then.", #alignmentWaypoints )
		return nil
	end
	self:debug('Alignment course with %d waypoints started.', #alignmentWaypoints)
		return Course(self.vehicle, courseGenerator.pointsToXzInPlace(alignmentWaypoints), true)
end

function AIDriver:debug(...)
	courseplay.debugVehicle(self.debugChannel, self.vehicle, ...)
end

function AIDriver:info(...)
	courseplay.infoVehicle(self.vehicle, ...)
end

function AIDriver:error(...)
	courseplay.infoVehicle(self.vehicle, ...)
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
	if not self.course:isTemporary() then return end
	if self.vehicle.cp.settings.enableVisualWaypointsTemporary:is(false) and
			not courseplay.debugChannels[self.debugChannel] then
		return
	end

	for i = 1, self.course:getNumberOfWaypoints() do
		local x, y, z = self.course:getWaypointPosition(i)
		cpDebug:drawPoint(x, y + 3, z, 10, 0, 0)
		Utils.renderTextAtWorldPosition(x, y + 3.2, z, tostring(i), getCorrectTextSize(0.012), 0)
		if i < self.course:getNumberOfWaypoints() then
			local nx, ny, nz = self.course:getWaypointPosition(i + 1)
			cpDebug:drawLine(x, y + 3, z, 0, 0, 100, nx, ny + 3, nz)
		end
	end
end

function AIDriver:enableCollisionDetection()
	courseplay.debugVehicle(3,self.vehicle,'Collision detection enabled')
	self.collisionDetectionEnabled = true
end

function AIDriver:disableCollisionDetection()
	courseplay.debugVehicle(3,self.vehicle,'Collision detection disabled')
	self.collisionDetectionEnabled = false
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

	return self.allowedToDrive
end

function AIDriver:areBeaconLightsEnabled()
	return self.vehicle.cp.settings.warningLightsMode:get() > WarningLightsModeSetting.WARNING_LIGHTS_NEVER
end

function AIDriver:updateLights()
	if not self.vehicle.spec_lights then return end
	if self:areBeaconLightsEnabled() then
		self.vehicle:setBeaconLightsVisibility(true)
	else
		self.vehicle:setBeaconLightsVisibility(false)
	end
end

function AIDriver:updateAILights(superFunc)
	if self.cp and self.cp.driver and self:getIsCourseplayDriving() and self.spec_lights then
		if self.cp.driver:shouldLightsBeUsedForEnvironment() then --fall back to base class AIDriver for this
			self.cp.driver:setLightsMask(self)
		elseif superFunc ~= nil then
			superFunc(self)
		end
	elseif superFunc ~= nil then
		superFunc(self)
	end
end
Lights.updateAILights = Utils.overwrittenFunction(Lights.updateAILights , AIDriver.updateAILights)

function AIDriver:shouldLightsBeUsedForEnvironment()
	-- How Giants decides lights in Lights:updateAILights
	local dayMinutes = g_currentMission.environment.dayTime / (1000 * 60)
	local nightTime = (dayMinutes > g_currentMission.environment.nightStartMinutes or dayMinutes < g_currentMission.environment.nightEndMinutes)
	local rainScale = g_currentMission.environment.weather:getRainFallScale()
	local timeSinceRain = g_currentMission.environment.weather:getTimeSinceLastRain()
	local raining = rainScale > 0

	local shouldLightsBeUsed = (nightTime or raining)

	return shouldLightsBeUsed
end

function AIDriver:setLightsMask(vehicle)
	local x,y,z = getWorldTranslation(vehicle.rootNode);
	if not courseplay:isField(x, z) then
		vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_STREET)
	else
		vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_FULL)
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

function AIDriver:onLeaveVehicle(superFunc)
	if self.cp and self.cp.driver and self:getIsCourseplayDriving() then
		self.cp.driver.debug(self.cp.driver, 'overriding onLeaveVehicle() to prevent turning off lights')
	elseif superFunc ~= nil then
		superFunc(self)
	end
end
Lights.onLeaveVehicle = Utils.overwrittenFunction(Lights.onLeaveVehicle , AIDriver.onLeaveVehicle)

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
				local isTipping = tipper.spec_dischargeable.currentRaycastDischargeNode.isEffectActive
				local _,_,z = worldToLocal(tipRefpoint, uX,uY,uZ);
				z = courseplay:isNodeTurnedWrongWay(vehicle,tipRefpoint)and -z or z

				local foundHeap = self:checkForHeapBehindMe(tipper)
				
				--when we reached the unload point, stop the tractor and inhibit any action from ppc till the trailer is empty
				if (foundHeap or z >= 0) and tipper.cp.fillLevel ~= 0 or tipper:getTipState() ~= Trailer.TIPSTATE_CLOSED then
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
				if g_updateLoopIndex % 50 == 0 and self.pullForward and isTipping then
					self.pullForward = false
				end

				self:debugSparse('foundHeap(%s) z(%s) readyToDischarge(%s) isTipping(%s) pullForward(%s)',
						tostring(foundHeap), tostring(z), tostring(readyToDischarge), tostring(isTipping), tostring(self.pullForward))

				--ready with tipping, go forward on the course
				if tipper.cp.fillLevel == 0 then
					self.ppc:initialize(self.course:getNextFwdWaypointIx(self.ppc:getCurrentWaypointIx()));
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
					self.pullForward = nil
				end
				
				--do the driving here because if we initalize the ppc, we dont have the unload point anymore
				if self.pullForward then
					takeOverSteering = true
					local fwdWaypoint = self.course:getNextFwdWaypointIxFromVehiclePosition(unloadPointIx, self:getDirectionNode(), self.ppc:getLookaheadDistance())
					local x,y,z = self.course:getWaypointPosition(fwdWaypoint)
					local lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.directionNode, x, y, z);
					AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, true, true, lx, lz, 5, 1)
				end
			end
		end
		
	else
		for _, tipper in pairs (vehicle.cp.workTools) do
			if tipper.spec_dischargeable then	
				readyToDischarge = false
				tipRefpoint = tipper:getCurrentDischargeNode().node or tipper.rootNode
				_,y,_ = getWorldTranslation(tipRefpoint);
				local currentDischargeNode = tipper:getCurrentDischargeNode()
				local isTipping = currentDischargeNode.isEffectActive
				_,_,z = worldToLocal(tipRefpoint, uX,uY,uZ);
				z = courseplay:isNodeTurnedWrongWay(vehicle,tipRefpoint)and -z or z
				
				--when we reached the unload point, stop the tractor 
				if z <= 0 and tipper.cp.fillLevel ~= 0 then
					stopForTipping = true
					readyToDischarge = true
				end	
				--force tipper to tip to ground
				if tipper.getTipState and (tipper:getTipState() == Trailer.TIPSTATE_CLOSED or tipper:getTipState() == Trailer.TIPSTATE_CLOSING) and readyToDischarge then
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
				end
				--if we can't tip here anymore, pull a bit further
				if tipper.getTipState and tipper:getTipState() == Trailer.TIPSTATE_OPEN and not isTipping then
					stopForTipping = false
				end
			end
		end
	end
	
	return not stopForTipping, takeOverSteering
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
	local allowedToDrive, takeOverSteering = true
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
			courseplay:setInfoText(self.vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
		else
			--dischargeAtObjects is handled by the new TriggerHandler
		--	allowedToDrive = self:tipIntoStandardTipTrigger()
		end;
	end
	return allowedToDrive, takeOverSteering
end

function AIDriver:tipIntoStandardTipTrigger()
	local stopForTipping = false
	local siloIsFull = false
	for _, tipper in pairs(self.vehicle.cp.workTools) do
		if tipper.spec_dischargeable ~= nil then
			if self:tipTriggerIsFull(trigger,tipper) then
				siloIsFull = true
				stopForTipping = true
			else
				for i=1,#tipper.spec_dischargeable.dischargeNodes do
					if tipper:getCanDischargeToObject(tipper.spec_dischargeable.dischargeNodes[i])then
						tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
						stopForTipping = true
					end
				end
			end
		end
	end
	if not self:getHasAllTippersClosed() then
		stopForTipping = true
	end
	if siloIsFull then
		self:setInfoText('FARM_SILO_IS_FULL')
	end
	
	return not stopForTipping
end

function AIDriver:tipIntoBGASiloTipTrigger(dt)
	local trigger = self.vehicle.cp.currentTipTrigger
	self:setOffsetInBGASilo()
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
				if tipper.cp.fillLevel == 0 then
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
				end
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
	if self:hasTipTrigger() and self.vehicle.cp.totalFillLevel == 0 and self:getHasAllTippersClosed() then
		courseplay:resetTipTrigger(self.vehicle, true);
		self:resetBGASiloTables()
	end

	self:cleanUpMissedTriggerExit()

	-- tipper is not empty and tractor reaches TipTrigger
	--if self.vehicle.cp.totalFillLevel > 0 then
		if  self:hasTipTrigger()
		and not self:isNearFillPoint() then
			self:setSpeed(self.vehicle.cp.speeds.approach)
			allowedToDrive, takeOverSteering = self:dischargeAtTipTrigger(dt)
		end
	--end
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
			local ctx, _, ctz = getWorldTranslation(self:getDirectionNode())
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

function AIDriver:tipTriggerIsFull(trigger,tipper)
	local trigger = self.vehicle.cp.currentTipTrigger
	local trailerFillType = tipper.cp.fillType
	if trigger and trigger.unloadingStation then
		local ownerFarmId = self.vehicle.getOwnerFarmId(self.vehicle);
		local fillLevel = trigger.unloadingStation:getFillLevel(trailerFillType, ownerFarmId);
		local capacity = trigger.unloadingStation:getCapacity(trailerFillType, ownerFarmId);
		courseplay.debugVehicle(2,self.vehicle,'    trigger (%s) fillLevel=%d, capacity=%d ',tostring(trigger.triggerId), fillLevel, capacity);
		if fillLevel>=capacity then
			courseplay.debugVehicle(2, self.vehicle,'    trigger (%s) Trigger is full',tostring(triggerId));
			return true;
		end
	end;
	return false;
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

function AIDriver:getHasAllTippersClosed()
	local allClosed = true
	for _, tipper in pairs (self.vehicle.cp.workTools) do
    if courseplay:isTrailer(tipper) then
      if tipper.spec_dischargeable ~= nil and tipper:getTipState() ~= Trailer.TIPSTATE_CLOSED then
        allClosed = false
      end
    end

	end
	return allClosed
end

function AIDriver:setOffsetInBGASilo()
	if self.BunkerSiloMap == nil then
		self.BunkerSilo = g_bunkerSiloManager:getTargetBunkerSiloByPointOnCourse(self.course,self.ppc:getCurrentWaypointIx()+3)
		if self.BunkerSilo ~= nil then
			self.BunkerSiloMap = g_bunkerSiloManager:createBunkerSiloMap(self.vehicle, self.BunkerSilo,3)
		end
	end
	if self.BunkerSiloMap ~= nil then
		if self.bestColumnToFill == nil then
			self.bestColumnToFill = g_bunkerSiloManager:getBestColumnToFill(self.BunkerSiloMap)
			self.ppc:initialize(g_bunkerSiloManager:setOffsetsPerWayPoint(self.course,self.BunkerSiloMap,self.bestColumnToFill,self.ppc:getCurrentWaypointIx()))
		end
	end
end

function AIDriver:resetBGASiloTables()
	self.BunkerSilo = nil
	self.BunkerSiloMap = nil
	self.offsetsPerWayPoint = nil
	self.bestColumnToFill = nil
end

------------------------------------------------------------------------------
--- PATHFINDING
------------------------------------------------------------------------------

--- Start course with pathfinding
--- Will find a path on a field avoiding fruit as much as possible from the
--- current position to waypoint ix of course and start driving.
--- When waypoint ix of course reached, switch to the course and continue driving.
---
--- If no path found will use an alignment course to reach waypoint ix of course.
---@param course Course
---@param ix number
---@param zOffset number or nil length offset of the goal from the goalWaypoint
---@param fieldNum number or nil if > 0, the pathfinding is restricted to the given field and its vicinity. Otherwise the
---@param alwaysUsePathfinding boolean use pathfinding even when close to target
---@return boolean true when a pathfinding successfully started or an alignment course was added
function AIDriver:startCourseWithPathfinding(course, ix, zOffset, fieldNum, alwaysUsePathfinding)
	-- make sure we have at least a direct course until we figure out a better path. This can happen
	-- when we don't have a course set yet when starting the pathfinding, for example when starting the course.
	self:resetTrafficControl()
	self.course = course
	self.ppc:setCourse(course)
	self.ppc:initialize(ix)
	-- no pathfinding when target too close
	local d = course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, ix)
	-- always enforce a minimum distance needed for pathfinding, otherwise we'll end up with vehicles making
	-- a circle just to end up 50 cm to the left or right...
	local pathfindingRange = alwaysUsePathfinding and self.vehicle.cp.turnDiameter or (3 * self.vehicle.cp.turnDiameter)
	if not alwaysUsePathfinding and d < pathfindingRange then
		self:debug('Too close to target (%.1fm), will not perform pathfinding', d)
		return self:startCourseWithAlignment(course, ix)
	end

	if self:driveToPointWithPathfinding(course:getWaypoint(ix), zOffset or 0, course, ix, fieldNum or 0) then
		return true
	else
		return self:startCourseWithAlignment(course, ix)
	end
end

--- Start driving to a point with pathfinding
--- Will find a path on a field avoiding fruit as much as possible from the
--- current position to the given coordinates. Will call onEndCourse when it
--- reaches that point, so you'll have to have your own implementation of that
---
--- If no path is found, onNoPathFound() is called, you'll need your own implementation
--- of that to handle that case.
---
---@param waypoint Waypoint The destination waypoint (x, z, angle)
---@param zOffset number length offset of the goal from the goalWaypoint
---@param allowReverse boolean allow reverse driving
---@param course Course course to start after pathfinding is done, can be nil
---@param ix number course to start at after pathfinding, can be nil
---@param fieldNum number if > 0, the pathfinding is restricted to the given field and its vicinity. Otherwise the
--- pathfinding considers any collision-free path valid, also outside of the field.
---@return boolean true when a pathfinding successfully started
function AIDriver:driveToPointWithPathfinding(waypoint, zOffset, course, ix, fieldNum)
	if self.vehicle.cp.settings.useRealisticDriving:is(true) then
		if not self.pathfinder or not self.pathfinder:isActive() then
			self.courseAfterPathfinding = course
			self.waypointIxAfterPathfinding = ix
			local done, path
			self.pathfindingStartedAt = self.vehicle.timer
			local courseOffsetX, courseOffsetZ = 0, 0
			if course then
				courseOffsetX, courseOffsetZ = course:getOffset()
			end
			self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
					self.vehicle, waypoint, courseOffsetX,courseOffsetZ + (zOffset or 0), self.allowReversePathfinding, fieldNum)
			if done then
				return self:onPathfindingDone(path)
			else
				self:setPathfindingDoneCallback(self, self.onPathfindingDone)
				return true
			end

		else
			self:debug('Pathfinder already active')
		end
		return true
	else
		self:debug('Pathfinding turned off, falling back to dumb mode')
	end
	self.courseAfterPathfinding = nil
	self.waypointIxAfterPathfinding = nil
	return false
end

--- Override this if you for example want to completely stop (speed 0 will keep rolling for a while)
function AIDriver:stopForPathfinding()
	self:setSpeed(0)
end

function AIDriver:updatePathfinding()
	if self.pathfinder and self.pathfinder:isActive() then
		-- stop while pathfinding is running
		self:stopForPathfinding()
		local done, path = self.pathfinder:resume()
		if done then
			self.pathfindingDoneCallbackFunc(self.pathfindingDoneObject, path)
		end
	end
end

function AIDriver:setPathfindingDoneCallback(object, func)
	self.pathfindingDoneObject = object
	self.pathfindingDoneCallbackFunc = func
end

--- If we have a path now then set it up as a temporary course, also appending an alignment between the end
--- of the path and the target course
---@return boolean true if a temporary course (path/align) is started, false otherwise
function AIDriver:onPathfindingDone(path)
	if path and #path > 2 then
		self:debug('Pathfinding finished with %d waypoints (%d ms)', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0))
		local temporaryCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(temporaryCourse, 1, self.courseAfterPathfinding, self.waypointIxAfterPathfinding)
		return true
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
	if self.courseAfterPathfinding then
		if not self:startCourseWithAlignment(self.courseAfterPathfinding, self.waypointIxAfterPathfinding) then
			-- no alignment course needed or possible, skip to the end of temp course to continue on the normal course
			self:continueOnNextCourse(self.courseAfterPathfinding, self.waypointIxAfterPathfinding)
			return false
		else
			return true
		end
	else
		return false
	end
end

function AIDriver:getClosestPointOnFieldBoundary(x, z, fieldNum)
	-- theoretically x/z could be on a _different_ field, but for now we ignore that case
	if fieldNum > 0 and not courseplay:isField(x, z) then
		-- the pathfinder needs both from/to positions to be on the field so if a  point is not on the
		-- field, we need to use the closest point on the field boundary instead.
		local closestPointToTargetIx = courseplay:getClosestPolyPoint(courseplay.fields.fieldData[fieldNum].points, x, z)
		return courseplay.fields.fieldData[ fieldNum ].points[ closestPointToTargetIx ].cx,
			courseplay.fields.fieldData[ fieldNum ].points[ closestPointToTargetIx ].cz
	else
		return x, z
	end
end

function AIDriver:startEngineIfNeeded()
	if self.vehicle.spec_motorized and not self.vehicle.spec_motorized:getIsMotorStarted() then
		self.vehicle:startMotor()
	end
	-- reset motor auto stop timer when someone starts the engine so we won't stop it for a while just because
	-- our speed is 0 (for example while waiting for the implements to lower)
	self:resetLastMoveCommandTime()
end

function AIDriver:getIsEngineReady()
	local spec = self.vehicle.spec_motorized
	return spec and (spec:getIsMotorStarted() and spec:getMotorStartTime() < g_currentMission.time)
end;


--- Is auto stop engine enabled?
function AIDriver:isEngineAutoStopEnabled()
	-- do not auto stop engine when auto motor start is enabled as it'll try to restart the engine on each update tick.
	return self.vehicle.cp.settings.saveFuelOption:is(true) and not g_currentMission.missionInfo.automaticMotorStartEnabled
end

--- Check the engine state and stop if we have the fuel save option and been stopped too long
function AIDriver:stopEngineIfNotNeeded()
	if self:isEngineAutoStopEnabled() then
		if self.vehicle.timer - (self.lastMoveCommandTime or math.huge) > 30000 then
			if self.vehicle.spec_motorized and self.vehicle.spec_motorized.isMotorStarted then
				self:debug('Been stopped for more than 30 seconds, stopping engine. %d %d', self.vehicle.timer, (self.lastMoveCommandTime or math.huge))
				self.vehicle:stopMotor()
			end
		end
	end
end

--- Compatibility function for turn.lua to check if the vehicle should stop during a turn (for example while it
--- is held for unloading or waiting for the straw swath to stop
--- Turn.lua calls this in every cycle during the turn and will stop the vehicle if this returns true.
---@param isApproaching boolean if true we are still in the turn approach phase (still working on the field,
---not yet reached the turn start
---@param isHeadlandCorner boolean is this a headland turn?
function AIDriver:holdInTurnManeuver(isApproaching, isHeadlandCorner)
	return false
end

--- called from courseplay:onDraw, a placeholder for showing debug infos, which can this way be added and reloaded
--- without restarting the game.
function AIDriver:onDraw()
	if CpManager.isDeveloper and self.course and
		(self.vehicle.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_DBGONLY or self.vehicle.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_BOTH)  then
		self.course:draw()
	end
	if CpManager.isDeveloper and self.pathfinder then
		PathfinderUtil.showNodes(self.pathfinder)
	end

end
--TODO: do we want to continue using this setter/getter for driveUnloadNow??
function AIDriver:setDriveUnloadNow(driveUnloadNow)
	courseplay:setDriveUnloadNow(self.vehicle, driveUnloadNow or false)
end

function AIDriver:setDriveNow()
	if self:isWaiting() then 
		self:continue()
		self.vehicle.cp.wait = false
		--is this one needed ??
		if self.vehicle.cp.mode == 1 or self.vehicle.cp.mode == 3 then
			self.vehicle.cp.isUnloaded = true;
		end;
	end
	self.triggerHandler:onDriveNow()
end

function AIDriver:getDriveUnloadNow()
	return self.vehicle.cp.settings.driveUnloadNow:get()
end

function AIDriver:refreshHUD()
	courseplay.hud:setReloadPageOrder(self.vehicle, self.vehicle.cp.hud.currentPage, true);
end

function AIDriver:checkIfBlocked()
	if self.stoppedButShouldBeMoving and self.stoppedMovingAt then
		self:debugSparse('stopped moving at %d (%d)', self.stoppedMovingAt, self.vehicle.timer - self.stoppedMovingAt)
	end
	if self.stoppedButShouldBeMoving and self.stoppedMovingAt and self.stoppedMovingAt + 3000 < self.vehicle.timer then
		if not self.blocked then
			self:onBlocked()
		end
		self.blocked = true
	else
		if self.blocked then
			self:onUnBlocked()
		end
		self.blocked = false
	end
end

function AIDriver:onBlocked()
	self:debug('Blocked...')
end

function AIDriver:onUnBlocked()
	self:debug('Unblocked...')
end

function AIDriver:trafficControlOK()
	-- TODO: why the root node? Why not the vehicle itself?
	return g_trafficController:reserve(self.vehicle.rootNode, self.course, self.ppc:getCurrentWaypointIx())
end

function AIDriver:resetTrafficControl()
	g_trafficController:cancel(self.vehicle.rootNode)
end

function AIDriver:detectSlipping()
	if self.vehicle.spec_motorized then
		local slippingNow = self.vehicle:getMotor():getClutchRotSpeed() > 10 and math.abs(self.vehicle:getLastSpeed()) < 0.5
		if not slippingNow then
			if self.isSlipping then
				self:debug('Stopped slipping')
				self:clearInfoText('SLIPPING_1')
				self.startedSlippingAt = math.huge
			end
			self.isSlipping = false
		end
		if slippingNow then
			if self.startedSlippingAt and self.vehicle.timer - self.startedSlippingAt > 4000 then
				self:debugSparse('Slipping')
				self:setInfoText('SLIPPING_1')
			end
			if not self.isSlipping then
				self.startedSlippingAt = self.vehicle.timer
			end
			self.isSlipping = true
		end
	end
end

function AIDriver:initWages()
	local spec = self.vehicle.spec_aiVehicle
	if spec.startedFarmId == nil or spec.startedFarmId == 0 then
		-- to make the wage paying in AIVehicle work it needs to have the correct farm ID
		spec.startedFarmId = self.vehicle.controllerFarmId
	end
end

function AIDriver:payWages(dt)
	local spec = self.vehicle.spec_aiVehicle
	local courseplayMultiplier
	-- The Giants AIVehicle always pays wages so we need to take that into account and compensate for it
	-- when paying less than 100% (hence the -1)
	if courseplay.globalSettings.earnWages:is(true) and self:shouldPayWages() then
		courseplayMultiplier = courseplay.globalSettings.workerWages:get() / 100 - 1
	else
		-- compensate for all the Giants wage paying
		courseplayMultiplier = -1
	end
	if spec and g_server ~= nil then
		local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier
		local wage = -dt * difficultyMultiplier * courseplayMultiplier * spec.pricePerMS
		g_currentMission:addMoney(wage, spec.startedFarmId, MoneyType.AI, true)
	end
end

--- By default, do pay wages when enabled. Some derived classes may decide not to pay under circumstances
function AIDriver:shouldPayWages()
	return true
end

function AIDriver:getAllowReversePathfinding()
	return self.allowReversePathfinding and self.vehicle.cp.settings.allowReverseForPathfindingInTurns:is(true)
end

-- Note that this may temporarily return false even if it is reversing
function AIDriver:isReversing()
	if (self:isInReverseGear() and math.abs(self.vehicle.lastSpeedReal) > 0.00001) or
			self.ppc:isReversing() then
		return true
	else
		return false
	end
end

function AIDriver:isInReverseGear()
	return self.vehicle.getMotor and self.vehicle:getMotor():getGearRatio() < 0
end

-- Put a node on the back of the vehicle for easy distance checks use this instead of the root/direction node
-- TODO: check for towed implements/trailers
function AIDriver:setBackMarkerNode(vehicle)

	local backMarkerOffset = 0
	local referenceNode
	local reverserNode, debugText = AIDriverUtil.getReverserNode(self.vehicle)
	if AIDriverUtil.hasImplementsOnTheBack(vehicle) then
		local lastImplement
		lastImplement, backMarkerOffset = AIDriverUtil.getLastAttachedImplement(vehicle)
		referenceNode = lastImplement.rootNode
		self:debug('Using the last implement\'s root node for the rear proximity sensor, %d m from root node', backMarkerOffset)
	elseif reverserNode then
		-- if there is a reverser node, use that, mainly because that most likely will turn with an implement
		-- or with the back component of an articulated vehicle. Just need to find out the distance correctly
		local dx, _, dz = localToLocal(reverserNode, vehicle.rootNode, 0, 0, 0)
		local dBetweenRootAndReverserNode = MathUtil.vector2Length(dx, dz)
		backMarkerOffset = dBetweenRootAndReverserNode - vehicle.sizeLength / 2 - vehicle.lengthOffset
		referenceNode = reverserNode
		self:debug('Using the %s node for the rear proximity sensor %d m from root node (%d m between root and reverser)',
				debugText, backMarkerOffset, dBetweenRootAndReverserNode)
	else
		referenceNode = vehicle.rootNode
		backMarkerOffset = - vehicle.sizeLength / 2 - vehicle.lengthOffset
		self:debug('Using the vehicle\'s root node for the rear proximity sensor, %d m from root node', backMarkerOffset)
	end
	if not vehicle.cp.driver.aiDriverData.backMarkerNode then
		vehicle.cp.driver.aiDriverData.backMarkerNode = courseplay.createNode('backMarkerNode', 0, 0, 0, referenceNode)
	else
		-- relink to current reference node (in case of implement change for example
		unlink(vehicle.cp.driver.aiDriverData.backMarkerNode)
		link(referenceNode, vehicle.cp.driver.aiDriverData.backMarkerNode)
	end
	setTranslation(vehicle.cp.driver.aiDriverData.backMarkerNode, 0, 0, backMarkerOffset)
end

function AIDriver:getBackMarkerNode(vehicle)
	return vehicle.cp.driver.aiDriverData.backMarkerNode
end

-- Put a node on the front of the vehicle for easy distance checks use this instead of the root/direction node
-- TODO: check for implements at front like weights
function AIDriver:setFrontMarkerNode(vehicle)
	local firstImplement, frontMarkerOffset = AIDriverUtil.getFirstAttachedImplement(vehicle)
	self:debug('Using the %s\'s root node for the front proximity sensor, %d m from root node',
			firstImplement.getName and firstImplement:getName() or 'N/A', frontMarkerOffset)

	if not vehicle.cp.driver.aiDriverData.frontMarkerNode then
		vehicle.cp.driver.aiDriverData.frontMarkerNode = courseplay.createNode('frontMarkerNode', 0, 0, 0, vehicle.rootNode)
	else
		unlink(vehicle.cp.driver.aiDriverData.frontMarkerNode)
		link(firstImplement.rootNode, vehicle.cp.driver.aiDriverData.frontMarkerNode)
	end
	setTranslation(vehicle.cp.driver.aiDriverData.frontMarkerNode, 0, 0, frontMarkerOffset)
end

function AIDriver:getFrontMarkerNode(vehicle)
	return vehicle.cp.driver.aiDriverData.frontMarkerNode
end

function AIDriver:addForwardProximitySensor()
	self:setFrontMarkerNode(self.vehicle)
	self.forwardLookingProximitySensorPack = ForwardLookingProximitySensorPack(self:getFrontMarkerNode(self.vehicle), self.proximitySensorRange, 1)
end

function AIDriver:addBackwardProximitySensor()
	self:setBackMarkerNode(self.vehicle)
	self.backwardLookingProximitySensorPack = BackwardLookingProximitySensorPack(self:getBackMarkerNode(self.vehicle), self.proximitySensorRange, 1)
end

function AIDriver:updateProximitySensors()
	if self.forwardLookingProximitySensorPack then
		self.forwardLookingProximitySensorPack:update()
	end
	if self.backwardLookingProximitySensorPack then
		self.backwardLookingProximitySensorPack:update()
	end
end

function AIDriver:checkProximitySensor(maxSpeed, allowedToDrive, moveForwards)
	if maxSpeed == 0 or not allowedToDrive then
		-- we are not going anywhere anyway, no use of proximity sensor here
		return maxSpeed, allowedToDrive
	end
	-- minimum distance from any object in the proximity sensor's range
	local d, range = math.huge, 10
	if moveForwards then
		if self.forwardLookingProximitySensorPack and self.forwardLookingProximitySensorPack:isSpeedControlEnabled() then
			d = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
			range = self.forwardLookingProximitySensorPack:getRange()
		end
	else
		if self.backwardLookingProximitySensorPack and self.backwardLookingProximitySensorPack:isSpeedControlEnabled() then
			d = self.backwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
			range = self.backwardLookingProximitySensorPack:getRange()
		end
	end
	if d < AIDriver.proximityLimitLow then
		-- too close, stop
		self:debugSparse('proximity: d = %.1f, too close, stop.', d)
		return maxSpeed, false
	end
	local normalizedD = d / (range - AIDriver.proximityLimitLow)
	if normalizedD > 1 then
		-- nothing in range (d is a huge number, at least bigger than range), don't change anything
		return maxSpeed, allowedToDrive
	end
	-- something in range, reduce speed proportionally
	local deltaV = maxSpeed - AIDriver.proximityMinLimitedSpeed
	local newSpeed = AIDriver.proximityMinLimitedSpeed + normalizedD * deltaV
	self:debugSparse('proximity: d = %.1f (%d %%), speed = %.1f', d, 100 * normalizedD, newSpeed)
	return newSpeed, allowedToDrive
end

function AIDriver:isAutoDriveDriving()
	return false
end

function AIDriver:checkFuel()
	--override
	local allowedToDrive = true
	if self.vehicle.getConsumerFillUnitIndex ~= nil then
		local dieselIndex = self.vehicle:getConsumerFillUnitIndex(FillType.DIESEL)
		local currentFuelPercentage = self.vehicle:getFillUnitFillLevelPercentage(dieselIndex) * 100;
		if currentFuelPercentage < 5 then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self.vehicle, 'FUEL_MUST');
		elseif currentFuelPercentage < 20 then
			CpManager:setGlobalInfoText(self.vehicle, 'FUEL_SHOULD');
		elseif currentFuelPercentage < 99.99 then
		--	CpManager:setGlobalInfoText(vehicle, 'FUEL_IS');
		end;
	end
	return allowedToDrive;
end

function AIDriver:getSiloSelectedFillTypeSetting()

end

function AIDriver:getSeperateFillTypeLoadingSetting()

end

function AIDriver:notAllowedToLoadNextFillType()

end

function AIDriver:getCanShowDriveOnButton()
	return self.triggerHandler:isLoading() or self.triggerHandler:isUnloading() or self:isWaiting()
end
