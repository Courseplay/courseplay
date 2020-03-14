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

--[[
Fieldwork AI Driver

Can follow a fieldworking course, perform turn maneuvers, turn on/off and raise/lower implements,
add adjustment course if needed.
]]

---@class FieldworkAIDriver : AIDriver
FieldworkAIDriver = CpObject(AIDriver)

FieldworkAIDriver.myStates = {
	ON_FIELDWORK_COURSE = {},
	WORKING = {},
	ON_UNLOAD_OR_REFILL_COURSE = {},
	RETURNING_TO_FIRST_POINT = {},
	UNLOAD_OR_REFILL_ON_FIELD = {},
	WAITING_FOR_UNLOAD_OR_REFILL ={}, -- while on the field
	ON_CONNECTING_TRACK = {},
	WAITING_FOR_LOWER = {},
	WAITING_FOR_LOWER_DELAYED = {},
	WAITING_FOR_STOP = {},
	ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE = {},
	TURNING = {},
	FORWARD1 = {},
	FORWARD2 = {},
	REVERSE = {},
}

-- Our class implementation does not call the constructor of base classes
-- through multiple level of inheritances therefore we must explicitly call
-- the base class ctr.
function FieldworkAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'FieldworkAIDriver:init()')
	AIDriver.init(self, vehicle)
	self:initStates(FieldworkAIDriver.myStates)
	-- waiting for tools to turn on, unfold and lower
	self.waitingForTools = true
	self.debugChannel = 14
	-- waypoint index on main (fieldwork) course where we aborted the work before going on
	-- an unload/refill course
	self.aiDriverData.continueFieldworkAtWaypoint = 1
	-- force stop for unload/refill, for example by a tractor, otherwise the same as stopping because full or empty
	self.heldForUnloadRefill = false
	self.heldForUnloadRefillTimestamp = 0
	-- stop and raise implements while refilling/unloading on field
	self.stopImplementsWhileUnloadOrRefillOnField = true
	-- duration of the last turn maneuver. This is a default value and the driver will measure
	-- the actual turn times. Used to calculate the remaining fieldwork time
	self.turnDurationMs = 20000
end

function FieldworkAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setFieldWorkAIDriverContent(self.vehicle)
end

function FieldworkAIDriver.register()

	AIImplement.getCanImplementBeUsedForAI = Utils.overwrittenFunction(AIImplement.getCanImplementBeUsedForAI,
		function(self, superFunc)
			if SpecializationUtil.hasSpecialization(BaleLoader, self.specializations) then
				return true
			elseif SpecializationUtil.hasSpecialization(BaleWrapper, self.specializations) then
				return true
			elseif SpecializationUtil.hasSpecialization(Pickup, self.specializations) then
				return true
			elseif superFunc ~= nil then
				return superFunc(self)
			end
		end)

	-- Make sure the Giants helper can't be hired for implements which have no Giants AI functionality
	AIVehicle.getCanStartAIVehicle = Utils.overwrittenFunction(AIVehicle.getCanStartAIVehicle,
		function(self, superFunc)
			-- Only the courseplay helper can handle bale loaders.
			if FieldworkAIDriver.hasImplementWithSpecialization(self, BaleLoader) or
				FieldworkAIDriver.hasImplementWithSpecialization(self, BaleWrapper) or
				FieldworkAIDriver.hasImplementWithSpecialization(self, Pickup) then
				return false
			end
			if superFunc ~= nil then
				return superFunc(self)
			end
		end)

	BaleLoaderAIDriver.register()

	Pickup.onAIImplementStartLine = Utils.overwrittenFunction(Pickup.onAIImplementStartLine,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			self:setPickupState(true)
		end)

	Pickup.onAIImplementEndLine = Utils.overwrittenFunction(Pickup.onAIImplementEndLine,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			self:setPickupState(false)
		end)

	-- TODO: move these to another dedicated class for implements?
	local PickupRegisterEventListeners = function(vehicleType)
		print('## Courseplay: Registering event listeners for loader wagons.')
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStartLine", Pickup)
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEndLine", Pickup)
	end

	print('## Courseplay: Appending event listener for loader wagons.')
	Pickup.registerEventListeners = Utils.appendedFunction(Pickup.registerEventListeners, PickupRegisterEventListeners)
end

function FieldworkAIDriver.hasImplementWithSpecialization(vehicle, specialization)
	return FieldworkAIDriver.getImplementWithSpecialization(vehicle, specialization) ~= nil
end

function FieldworkAIDriver.getImplementWithSpecialization(vehicle, specialization)
	local aiImplements = vehicle:getAttachedAIImplements()
	for _, implement in ipairs(aiImplements) do
		if SpecializationUtil.hasSpecialization(specialization, implement.object.specializations) then
			return implement.object
		end
	end
end

--- Start the course and turn on all implements when needed
--- @param startingPoint StartingPointSetting at which waypoint to start the course
function FieldworkAIDriver:start(startingPoint)
	self:debug('Starting in mode %d', self.mode)
	self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
	self:setMarkers()
	self:beforeStart()
	-- time to lower all implements
	self:findLoweringDurationMs()
	-- always enable alignment with first waypoint, this is needed to properly start/continue fieldwork
	self.alignmentEnabled = self.vehicle.cp.alignment.enabled
	self.vehicle.cp.alignment.enabled = true
	-- stop at the last waypoint by default
	self.vehicle.cp.stopAtEnd = true
	-- any offset imposed by the driver itself (tight turns, end of course, etc.), additional to any
	-- tool offsets
	self.aiDriverOffsetX = 0
	self.aiDriverOffsetZ = 0

	self:setUpCourses()

	-- now that we have our unload/refill and fieldwork courses set up, see where to start
	local closestFieldworkIx, dClosestFieldwork, closestFieldworkIxRightDirection, dClosestFieldworkRightDirection =
	self.fieldworkCourse:getNearestWaypoints(AIDriverUtil.getDirectionNode(self.vehicle))

	-- default to math.huge in case there isn't an unload refill course to make sure it only the fieldwork Ix is used
	local closestUnloadRefillIx, dClosestUnloadRefill, closestUnloadRefillIxRightDirection, dClosestUnloadRefillRightDirection =
	0, math.huge, 0, math.huge

	if self.unloadRefillCourse then
		closestUnloadRefillIx, dClosestUnloadRefill, closestUnloadRefillIxRightDirection, dClosestUnloadRefillRightDirection =
		self.unloadRefillCourse:getNearestWaypoints(AIDriverUtil.getDirectionNode(self.vehicle))
	end

	local ix = self.course and self.course:getCurrentWaypointIx()
	local startWithFieldwork

	if startingPoint:is(StartingPointSetting.START_AT_NEAREST_POINT) then
		if dClosestFieldwork < dClosestUnloadRefill then
			ix = closestFieldworkIx
			startWithFieldwork = true
			self:debug('Starting at nearest waypoint %d on fieldwork course', ix)
		else
			ix = closestUnloadRefillIx
			startWithFieldwork = false
			self:debug('Starting at nearest waypoint %d on unload/refill course', ix)
		end
	end

	if startingPoint:is(StartingPointSetting.START_AT_NEXT_POINT) then
		if dClosestFieldworkRightDirection < dClosestUnloadRefillRightDirection then
			ix = closestFieldworkIxRightDirection
			startWithFieldwork = true
			self:debug('Starting at nearest waypoint %d (best direction) on fieldwork course', ix)
		else
			ix = closestUnloadRefillIxRightDirection
			startWithFieldwork = false
			self:debug('Starting at nearest waypoint %d (best direction) on unload/refill course', ix)
		end
	end
	if startingPoint:is(StartingPointSetting.START_AT_FIRST_POINT) then
		self:debug('Starting at first waypoint')
		ix = 1
		startWithFieldwork = true
	end

	if startingPoint:is(StartingPointSetting.START_AT_CURRENT_POINT) then
		-- use last fieldwork waypoint if we have the same fieldwork course as before
		if self.fieldworkCourseHash == self.aiDriverData.lastFieldworkCourseHash then
			self:debug('Starting at current waypoint %d', self.aiDriverData.lastFieldworkWaypointIx)
			ix = self.aiDriverData.lastFieldworkWaypointIx
		else
			self:debug('Current waypoint not found, starting at first')
			ix = 1
		end
		startWithFieldwork = true
	end

	self.waitingForTools = true
	self.ppc:setNormalLookaheadDistance()

	if startWithFieldwork then
		self:startFieldworkWithPathfinding(ix)
	else
		self:changeToUnloadOrRefill()
		self:startCourseWithAlignment(self.unloadRefillCourse, ix)
	end
end

function FieldworkAIDriver:startFieldworkWithAlignment(ix)
	if self:startCourseWithAlignment(self.fieldworkCourse, ix) then
		self.state = self.states.ON_FIELDWORK_COURSE
		self.fieldworkState = self.states.TEMPORARY
	else
		self:changeToFieldwork()
	end
end

function FieldworkAIDriver:startFieldworkWithPathfinding(ix)
	if self:startCourseWithPathfinding(self.fieldworkCourse, ix) then
		self.state = self.states.ON_FIELDWORK_COURSE
		self.fieldworkState = self.states.TEMPORARY
	else
		self:debug('No path to fieldwork start found.')
		self:changeToFieldwork()
	end
end

--- Start course with pathfinding
--- Will find a path on a field avoiding fruit as much as possible from the
--- current position to waypoint ix of course and start driving.
--- When waypoint ix of course reached, switch to the course and continue driving.
---
--- If no path found will use an alignment course to reach waypoint ix of course.
---@param course Course
---@param ix number
---@return boolean true when a pathfinding successfully started or an alignment course was added
function FieldworkAIDriver:startCourseWithPathfinding(course, ix)
	-- if the implement is in the front, generate a path so the implement will be at the goal
	local zOffset = self.frontMarkerDistance > 0 and - self.frontMarkerDistance or 0
	return AIDriver.startCourseWithPathfinding(self, course, ix, zOffset,0)
end

function FieldworkAIDriver:xonPathfindingDone(path)
	if path and #path > 2 then
		self:debug('(FieldworkAIDriver) Pathfinding finished with %d waypoints (%d ms)', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0))
		local tempCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(tempCourse, 1, self.courseAfterPathfinding, self.waypointIxAfterPathfinding)
		return true
	else
		self:debug('(FieldworkAIDriver) Pathfinding was not able to find a path in %d ms', self.vehicle.timer - (self.pathfindingStartedAt or 0))
		self:startCourse(self.courseAfterPathfinding, self.waypointIxAfterPathfinding)
		return false
	end
end

function FieldworkAIDriver:stop(msgReference)
	self:stopWork()
	-- persist last fieldwork waypoint data (for 'start at current waypoint')
	self.aiDriverData.lastFieldworkCourseHash = self.fieldworkCourse:getHash()
	self.aiDriverData.lastFieldworkWaypointIx = self.fieldworkCourse:getCurrentWaypointIx()
	AIDriver.stop(self, msgReference)
	-- Restore alignment settings. TODO: remove this setting from the HUD and always enable it
	self.vehicle.cp.alignment.enabled = self.alignmentEnabled
end

function FieldworkAIDriver:drive(dt)
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	if self.state == self.states.ON_FIELDWORK_COURSE then
		if self:driveFieldwork(dt) then
			-- driveFieldwork is driving, no need for AIDriver
			return
		end
	elseif self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE then
		if self:driveUnloadOrRefill(dt) then
			-- someone else is driving, no need to call AIDriver.drive()
			return
		end
	elseif self.state == self.states.RETURNING_TO_FIRST_POINT then
		self:setSpeed(self:getFieldSpeed())
	elseif self.state == self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE then
		-- AutoDrive is driving, don't call AIDriver.drive()
		return
	end
	self:setRidgeMarkers()
	self:resetUnloadOrRefillHold()
	AIDriver.drive(self, dt)
	self:measureTurnTime()
end

-- Hold for unload (or refill) for example a combine can be asked by a an unloading tractor
-- to stop and wait. Must be called in every loop to keep waiting because it will automatically be
-- reset and the vehicle restarted. This way the users don't explicitly need to call resumeAfterUnloadOrRefill()
function FieldworkAIDriver:holdForUnloadOrRefill()
	self.heldForUnloadRefill = true
	self.heldForUnloadRefillTimestamp = g_updateLoopIndex
end

function FieldworkAIDriver:resumeAfterUnloadOrRefill()
	self.heldForUnloadRefill = false
end

function FieldworkAIDriver:resetUnloadOrRefillHold()
	if g_updateLoopIndex > self.heldForUnloadRefillTimestamp + 10 then
		self:resumeAfterUnloadOrRefill()
	end
end


--- Doing the fieldwork (headlands or up/down rows, including the turns)
---@return boolean true if driveFieldwork() is driving (no need to call ALDriver.drive())
function FieldworkAIDriver:driveFieldwork(dt)
	local iAmDriving = false
	self:updateFieldworkOffset()
	if self.fieldworkState == self.states.WAITING_FOR_LOWER_DELAYED then
		-- getCanAIVehicleContinueWork() seems to return false when the implement being lowered/raised (moving) but
		-- true otherwise. Due to some timing issues it may return true just after we started lowering it, so this
		-- here delays the check for another cycle.
		self.fieldworkState = self.states.WAITING_FOR_LOWER
	elseif self.fieldworkState == self.states.WAITING_FOR_LOWER then
		if self.vehicle:getCanAIVehicleContinueWork() then
			self:debug('all tools ready, start working')
			self.fieldworkState = self.states.WORKING
			self:setSpeed(self:getWorkSpeed())
		else
			self:debug('waiting for all tools to lower')
			self:setSpeed(0)
			self:checkFillLevels()
		end
	elseif self.fieldworkState == self.states.WORKING then
		self:setSpeed(self:getWorkSpeed())
		self:manageConvoy()
		self:checkWeather()
		self:checkFillLevels()
		self:checkFuelLevels()
	elseif self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		self:driveFieldworkUnloadOrRefill()
	elseif self.fieldworkState == self.states.TEMPORARY then
		self:setSpeed(self:getFieldSpeed())
	elseif self.fieldworkState == self.states.ON_CONNECTING_TRACK then
		self:setSpeed(self:getFieldSpeed())
	elseif self.fieldworkState == self.states.TURNING and self.aiTurn then
		iAmDriving = self.aiTurn:drive(dt)
	end
	return iAmDriving
end

function FieldworkAIDriver:checkFillLevels()
	if not self:allFillLevelsOk() or self.heldForUnloadRefill then
		self:stopAndChangeToUnload()
	end
end

function FieldworkAIDriver:stopAndChangeToUnload()
	if self.unloadRefillCourse and not self.heldForUnloadRefill then
		self:rememberWaypointToContinueFieldwork()
		self:debug('at least one tool is empty/full, aborting work at waypoint %d.', self.aiDriverData.continueFieldworkAtWaypoint or -1)
		self:changeToUnloadOrRefill()
		self:startCourseWithPathfinding(self.unloadRefillCourse, 1)
	else
		if self.vehicle.cp.settings.autoDriveMode:useForUnloadOrRefill() then
			-- Switch to AutoDrive when enabled 
			self:rememberWaypointToContinueFieldwork()
			self:stopWork()
			self:foldImplements()
			self.state = self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE
			self:debug('passing the control to AutoDrive to run the unload/refill course.')
			self.vehicle.spec_autodrive:StartDrivingWithPathFinder(self.vehicle, self.vehicle.ad.mapMarkerSelected, self.vehicle.ad.mapMarkerSelected_Unload, self, FieldworkAIDriver.onEndCourse, nil);
		else
			-- otherwise we'll 
			self:changeToFieldworkUnloadOrRefill()
		end;
	end
end

function FieldworkAIDriver:checkFuelLevels()
	if self.vehicle.getConsumerFillUnitIndex ~= nil then
		local dieselIndex = self.vehicle:getConsumerFillUnitIndex(FillType.DIESEL)
		local currentFuelPercentage = self.vehicle:getFillUnitFillLevelPercentage(dieselIndex) * 100;
		
		if currentFuelPercentage < 15 then
			self:stopAndRefuel()
		end;
	end
end

function FieldworkAIDriver:stopAndRefuel()
	if self.vehicle.cp.settings.autoDriveMode:useForUnloadOrRefill() then
		-- Switch to AutoDrive when enabled 
		self:rememberWaypointToContinueFieldwork()
		self:stopWork()
		self:foldImplements()
		self.state = self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE
		self:debug('passing the control to AutoDrive to run the fuel refill course.')
		self.vehicle.spec_autodrive:StartDrivingWithPathFinder(self.vehicle, self.vehicle.ad.mapMarkerSelected, -2, self, FieldworkAIDriver.onEndCourse, nil);
	end
end

---@return boolean true if unload took over the driving
function FieldworkAIDriver:driveUnloadOrRefill()
	if self.course:isTemporary() then
		-- use the courseplay speed limit until we get to the actual unload course fields (on alignment/temporary)
		self:setSpeed(self.vehicle.cp.speeds.field)
	else
		-- just drive normally
		self:setSpeed(self:getRecordedSpeed())
	end
	-- except when in reversing, then always use reverse speed
	if self.ppc:isReversing() then
		self:setSpeed(self.vehicle.cp.speeds.reverse or self.vehicle.cp.speeds.crawl)
	end
	return false
end

--- Full during fieldwork
function FieldworkAIDriver:changeToFieldworkUnloadOrRefill()
	self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
	if self.stopImplementsWhileUnloadOrRefillOnField then
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_STOP
	else
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
	end
end

--- Stop for unload/refill while driving the fieldwork course
function FieldworkAIDriver:driveFieldworkUnloadOrRefill()
	-- don't move while empty
	self:setSpeed(0)
	if self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_STOP then
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('implements raised, stop')
			self:stopWork()
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL then
		if self:allFillLevelsOk() and not self.heldForUnloadRefill then
			self:debug('unloaded, continue working')
			-- not full/empty anymore, maybe because Refilling to a trailer, go back to work
			self:clearInfoText(self:getFillLevelInfoText())
			self:changeToFieldwork()
		end
	end
end

function FieldworkAIDriver:changeToFieldwork()
	self:debug('change to fieldwork')
	self.state = self.states.ON_FIELDWORK_COURSE
	self.fieldworkState = self.states.WAITING_FOR_LOWER
	self:startWork()
	self:setDriveUnloadNow(false);
	self:refreshHUD();
end

function FieldworkAIDriver:changeToUnloadOrRefill()
	self:debug('changing to unload/refill course (%d waypoints)', self.unloadRefillCourse:getNumberOfWaypoints())
	self:stopWork()
	self:foldImplements()
	self:enableCollisionDetection()
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
end

function FieldworkAIDriver:onNextCourse()
	if self.state == self.states.ON_FIELDWORK_COURSE then
		if self.fieldworkState == self.states.TURNING then
			self:debug('onNextCourse: a turn course ended')
			-- a turn just ended, at this point all implements should already be lowered as the turn end course ended
			-- but just in case, lower them now
			self:lowerImplements()
			self.fieldworkState = self.states.WORKING
		else
			self:debug('onNextCourse: not a turn course ended')
			self:changeToFieldwork()
		end
	end
end

function FieldworkAIDriver:onEndCourse()
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE or
		self.state == self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE then
		-- unload/refill course ended, return to fieldwork
		self:debug('AI driver in mode %d continue fieldwork at %d/%d waypoints', self:getMode(), self.aiDriverData.continueFieldworkAtWaypoint, self.fieldworkCourse:getNumberOfWaypoints())
		self:startFieldworkWithPathfinding(self.aiDriverData.continueFieldworkAtWaypoint)
	elseif self.state == self.states.RETURNING_TO_FIRST_POINT then
		AIDriver.onEndCourse(self)
	else
		self:debug('Fieldwork AI driver in mode %d ending fieldwork course', self:getMode())
		if self:shouldReturnToFirstPoint() then
			self:debug('Returning to first point')
			if self:driveToPointWithPathfinding(self.fieldworkCourse:getWaypoint(1)) then
				-- pathfinding was successful, drive back to first point
				self.state = self.states.RETURNING_TO_FIRST_POINT
				self:raiseImplements()
				self:foldImplements()
			else
				-- no path or too short, stop here.
				AIDriver.onEndCourse(self)
				-- (onEndCourse calls stopWork which raises the implements, fold must be called after that)
				-- TODO: add an option to enable fold implement on work end and make it part of stopWork()
				self:foldImplements()
			end
		else
			AIDriver.onEndCourse(self)
			self:foldImplements()
		end
	end
end

function FieldworkAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	if self.state == self.states.ON_FIELDWORK_COURSE then
		if self.fieldworkState == self.states.WORKING then
			-- check for transition to connecting track
			if self.course:isOnConnectingTrack(ix) then
				-- reached a connecting track (done with the headland, move to the up/down row or vice versa),
				-- raise all implements while moving
				self:debug('on a connecting track now, raising implements.')
				self:raiseImplements()
				self.fieldworkState = self.states.ON_CONNECTING_TRACK
			end
		end
		if self.fieldworkState ~= self.states.TEMPORARY and self.course:isOnConnectingTrack(ix) then
			-- passed a connecting track waypoint
			-- check transition from connecting track to the up/down rows
			-- we are close to the end of the connecting track, transition back to the up/down rows with
			-- an alignment course
			local d, firstUpDownWpIx = self.course:getDistanceToFirstUpDownRowWaypoint(ix)
			self:debug('up/down rows start in %s meters.', tostring(d))
			if d < self.vehicle.cp.turnDiameter * 2 and firstUpDownWpIx then
				self:debug('End connecting track, start working on up/down rows (waypoint %d) with alignment course if needed.', firstUpDownWpIx)
				self:startFieldworkWithAlignment(firstUpDownWpIx)
			end
		end
	end
	--- Check if we are at the last waypoint and should we continue with first waypoint of the course
	-- or stop.
	if ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	end
end

function FieldworkAIDriver:onWaypointChange(ix)
	self:debug('onWaypointChange %d, connecting: %s, temp: %s',
		ix, tostring(self.course:isOnConnectingTrack(ix)), tostring(self.states == self.states.TEMPORARY))
	if self.state == self.states.ON_FIELDWORK_COURSE then
		self:updateRemainingTime(ix)
		self:calculateTightTurnOffset()
		self:debug('Tight turn offset = %.1f', self.tightTurnOffset)
		self.aiDriverOffsetZ = 0
		if self.fieldworkState == self.states.ON_CONNECTING_TRACK then
			if not self.course:isOnConnectingTrack(ix) then
				-- reached the end of the connecting track, back to work
				self:debug('connecting track ended, back to work, first lowering implements.')
				self:changeToFieldwork()
			end
		end
		if self.fieldworkState == self.states.TEMPORARY then
			-- band aid to make sure we have our implements lowered by the time we end the
			-- temporary course
			-- TODO: fix this and also PlowAIDriver:startWork()
			if ix == self.course:getNumberOfWaypoints() then
				self:debug('temporary (alignment) course is about to end, start work')
				self:startWork()
			end
		-- towards the end of the field course make sure the implement reaches the last waypoint
		-- TODO: this needs refactoring, for now don't do this for temporary courses like a turn as it messes up reversing
		elseif ix > self.course:getNumberOfWaypoints() - 3 and not self.course:isTemporary() then
			if self.frontMarkerDistance then
				self:debug('adding offset (%.1f front marker) to make sure we do not miss anything when the course ends', self.frontMarkerDistance)
				self.aiDriverOffsetZ = -self.frontMarkerDistance
			end
		end
		if self.fieldworkState ~= self.states.TURNING and self.course:isTurnStartAtIx(ix) then
			self:startTurn(ix)
		end
	end
	-- update the legacy waypoint counter on the HUD
	if self.state == self.states.ON_FIELDWORK_COURSE or self.states.ON_UNLOAD_OR_REFILL_COURSE then
		courseplay:setWaypointIndex(self.vehicle, self.ppc:getCurrentOriginalWaypointIx())
	end
end

function FieldworkAIDriver:onTowedImplementPassedWaypoint(ix)
	self:debug('Implement passsed waypoint %d', ix)
end

--- Should we return to the first point of the course after we are done?
function FieldworkAIDriver:shouldReturnToFirstPoint()
	-- TODO: implement and check setting in course or HUD
	if self.vehicle.cp.settings.returnToFirstPoint:is(true) then
		self:debug('Returning to first point.')
		return true
	else
		self:debug('Not returning to first point.')
		return false
	end
end

--- Speed on the field when not working
function FieldworkAIDriver:getFieldSpeed()
	return self.vehicle.cp.speeds.field
end

-- Speed on the field when working
function FieldworkAIDriver:getWorkSpeed()
	-- use the speed limit supplied by Giants for fieldwork
	local speedLimit = self.vehicle:getSpeedLimit() or math.huge
	return math.min(self.vehicle.cp.speeds.field, speedLimit)
end

--- Pass on self.speed set elsewhere to the AIDriver.
function FieldworkAIDriver:getSpeed()
	local speed = AIDriver.getSpeed(self)
	-- as long as other CP components mess with the cruise control we need to reset this, for example after
	-- a turn
	self.vehicle:setCruiseControlMaxSpeed(speed)
	return speed
end

--- Start the actual work. Lower and turn on implements
function FieldworkAIDriver:startWork()
	self:debug('Starting work: turn on and lower implements.')
	-- send the event first and _then_ lower otherwise it sometimes does not turn it on
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	self.vehicle:requestActionEventUpdate()
	self:startEngineIfNeeded()
	self:lowerImplements(self.vehicle)
end


--- Stop working. Raise and stop implements
function FieldworkAIDriver:stopWork()
	self:debug('Ending work: turn off and raise implements.')
	self:raiseImplements()
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
	self.vehicle:requestActionEventUpdate()
	self:clearRemainingTime()
end

--- Check if need to refill/unload anything
function FieldworkAIDriver:allFillLevelsOk()
	if not self.vehicle.cp.workTools then return false end
	-- what here comes is basically what Giants' getFillLevelInformation() does but this returns the real fillType,
	-- not the fillTypeToDisplay as this latter is different for each type of seed
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	return self:areFillLevelsOk(fillLevelInfo)
end

function FieldworkAIDriver:getAllFillLevels(object, fillLevelInfo)
	-- get own fill levels
	if object.getFillUnits then
		for _, fillUnit in pairs(object:getFillUnits()) do
			local fillType = self:getFillTypeFromFillUnit(fillUnit)
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
			self:debugSparse('%s: Fill levels: %s: %.1f/%.1f', object:getName(), fillTypeName, fillUnit.fillLevel, fillUnit.capacity)
			if not fillLevelInfo[fillType] then fillLevelInfo[fillType] = {fillLevel=0, capacity=0} end
			fillLevelInfo[fillType].fillLevel = fillLevelInfo[fillType].fillLevel + fillUnit.fillLevel
			fillLevelInfo[fillType].capacity = fillLevelInfo[fillType].capacity + fillUnit.capacity
		end
	end
 	-- collect fill levels from all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getAllFillLevels(impl.object, fillLevelInfo)
	end
end

function FieldworkAIDriver:getFillTypeFromFillUnit(fillUnit)
	local fillType = fillUnit.lastValidFillType or fillUnit.fillType
	-- TODO: do we need to check more supported fill types? This will probably cover 99.9% of the cases
	if fillType == FillType.UNKNOWN then
		-- just get the first valid supported fill type
		for ft, valid in pairs(fillUnit.supportedFillTypes) do
			if valid then return ft end
		end
	else
		return fillType
	end

end

-- is the fill level ok to continue?
function FieldworkAIDriver:areFillLevelsOk()
	-- implement specifics in the derived classes
	return true
end

--- Set up the main (fieldwork) course and the unload/refill course and initial state
-- Currently, the legacy CP code just dumps all loaded courses to vehicle.Waypoints so
-- now we have to figure out which of that is the actual fieldwork course and which is the
-- refill/unload part.
-- This should better be handled by the course management though and should be refactored.
function FieldworkAIDriver:setUpCourses()
	local nWaits = 0
	local endFieldCourseIx = 0
	for i, wp in ipairs(self.vehicle.Waypoints) do
		if wp.wait then
			nWaits = nWaits + 1
			-- the second wp with the wait attribute is the end of the field course (assuming
			-- the field course has been loaded first.
			if nWaits == 2 then
				endFieldCourseIx = i
				break
			end
		end
	end
	if #self.vehicle.Waypoints > endFieldCourseIx and endFieldCourseIx ~= 0 then
		self:debug('Course with %d waypoints set up, there seems to be an unload/refill course starting at waypoint %d',
			#self.vehicle.Waypoints, endFieldCourseIx + 1)
		---@type Course
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, false, 1, endFieldCourseIx)
		---@type Course
		if #self.vehicle.Waypoints - endFieldCourseIx > 2 then
			self.unloadRefillCourse = Course(self.vehicle, self.vehicle.Waypoints, false, endFieldCourseIx + 1, #self.vehicle.Waypoints)
		else
			self:debug('Unload/refill course too short, ignoring')
		end
	else
		self:debug('Course with %d waypoints set up, there seems to be no unload/refill course', #self.vehicle.Waypoints)
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, false, 1, #self.vehicle.Waypoints)
	end
	-- get a signature of the course now, before offsetting it so can compare for the convoy
	self.fieldworkCourseHash = self.fieldworkCourse:getHash()
	-- apply the current tool offset to the fieldwork part (multitool offset is added by calculateOffsetCourse when needed)
	self.fieldworkCourse:setOffset(self.vehicle.cp.toolOffsetX, self.vehicle.cp.toolOffsetZ)
	-- TODO: consolidate the working width calculation and usage, this is currently an ugly mess
	self.fieldworkCourse:setWorkWidth(self.vehicle.cp.courseWorkWidth or courseplay:getWorkWidth(self.vehicle))
	if self.vehicle.cp.multiTools > 1 then
		self:debug('Calculating offset course for position %d of %d', self.vehicle.cp.laneNumber, self.vehicle.cp.multiTools)
		self.fieldworkCourse = self.fieldworkCourse:calculateOffsetCourse(
				self.vehicle.cp.multiTools, self.vehicle.cp.laneNumber,  courseplay:getWorkWidth(self.vehicle),
				self.vehicle.cp.settings.symmetricLaneChange:is(true))
	end
end

function FieldworkAIDriver:setRidgeMarkers()
	-- no ridge markers with multitools to avoid collisions.
	if not self.vehicle.cp.ridgeMarkersAutomatic or self.vehicle.cp.multiTools > 1 then return end
	local active = self.state == self.states.ON_FIELDWORK_COURSE and self.fieldworkState ~= self.states.TURNING
	for _, workTool in ipairs(self.vehicle.cp.workTools) do
		-- yes, another Giants typo. And not sure why implements with no ridge markers even have the spec_ridgeMarker
		if workTool.spec_ridgeMarker and workTool.spec_ridgeMarker.numRigdeMarkers > 0 then
			local state = active and self.course:getRidgeMarkerState(self.ppc:getCurrentWaypointIx()) or 0
			if workTool.spec_ridgeMarker.ridgeMarkerState ~= state then
				self:debug('Setting ridge markers to %d', state)
				workTool:setRidgeMarkerState(state)
			end
		end
	end
end

--- We already set the offsets on the course at start, this is to update those values
-- if the user changed them during the run or the AI driver wants to add an offset
function FieldworkAIDriver:updateFieldworkOffset()
	-- (as lua passes tables by reference, we can directly change self.fieldworkCourse even if we passed self.course
	-- to the PPC to drive)
	self.fieldworkCourse:setOffset(self.vehicle.cp.toolOffsetX + self.aiDriverOffsetX + (self.tightTurnOffset or 0),
		self.vehicle.cp.toolOffsetZ + self.aiDriverOffsetZ)
end

function FieldworkAIDriver:hasSameCourse(otherVehicle)
	if otherVehicle.cp.driver and otherVehicle.cp.driver.fieldworkCourseHash then
		return self.fieldworkCourseHash == otherVehicle.cp.driver.fieldworkCourseHash
	else
		return false
	end
end

function FieldworkAIDriver:getCurrentFieldworkWaypointIx()
	return self.fieldworkCourse:getCurrentWaypointIx()
end

--- When working in a group (convoy), do I have to hold so I don't get too close to the
-- other vehicles in front of me?
function FieldworkAIDriver:manageConvoy()
	if not self.vehicle.cp.convoyActive then return false end
	--get my position in convoy and look for the closest combine
	local position = 1
	local total = 1
	local closestDistance = math.huge
	for _, otherVehicle in pairs(CpManager.activeCoursePlayers) do
		if otherVehicle ~= self.vehicle and otherVehicle.cp.convoyActive and self:hasSameCourse(otherVehicle) then
			local myWpIndex = self:getCurrentFieldworkWaypointIx()
			local otherVehicleWpIndex = otherVehicle.cp.driver:getCurrentFieldworkWaypointIx()
			total = total + 1
			if myWpIndex < otherVehicleWpIndex then
				position = position + 1
				local distance = (otherVehicleWpIndex - myWpIndex) * courseGenerator.waypointDistance
				if distance < closestDistance then
					closestDistance = distance
				end
			end
		end
	end

	-- stop when I'm too close to the combine in front of me
	if position > 1 then
		if closestDistance < self.vehicle.cp.convoy.minDistance then
			self:debugSparse('too close (%.1f) to other vehicles in group, holding.', closestDistance)
			self:setSpeed(0)
			self:overrideAutoEngineStop()
		end
	else
		closestDistance = 0
	end

	-- TODO: check for change should be handled by setCpVar()
	if self.vehicle.cp.convoy.distance ~= closestDistance then
		self.vehicle:setCpVar('convoy.distance',closestDistance)
	end
	if self.vehicle.cp.convoy.number ~= position then
		self.vehicle:setCpVar('convoy.number',position)
	end
	if self.vehicle.cp.convoy.members ~= total then
		self.vehicle:setCpVar('convoy.members',total)
	end
end

-- Although raising the AI start/stop events supposed to fold/unfold the implements, it does not always happen.
-- So use these to explicitly do so
function FieldworkAIDriver:unfoldImplements()
	for _,workTool in pairs(self.vehicle.cp.workTools) do
		if courseplay:isFoldable(workTool) then
			local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool)
			if not isUnfolded and workTool:getIsFoldAllowed(workTool.cp.realUnfoldDirection) then
				self:debug('Unfolding %s', workTool:getName())
				workTool:setFoldDirection(workTool.cp.realUnfoldDirection)
			end
		end
	end
end

function FieldworkAIDriver:foldImplements()
	for _,workTool in pairs(self.vehicle.cp.workTools) do
		if courseplay:isFoldable(workTool) then
			local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool)
			if not isFolded and workTool:getIsFoldAllowed(-workTool.cp.realUnfoldDirection) then
				self:debug('Folding %s', workTool:getName())
				workTool:setFoldDirection(-workTool.cp.realUnfoldDirection)
			end
		end
	end
end

function FieldworkAIDriver:isAllUnfolded()
	for _,workTool in pairs(self.vehicle.cp.workTools) do
		if courseplay:isFoldable(workTool) then
			local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool)
			if not isUnfolded then return false end
		end
	end
	return true
end

function FieldworkAIDriver:clearRemainingTime()
	self.vehicle.cp.timeRemaining = nil
end

function FieldworkAIDriver:updateRemainingTime(ix)
	if self.state == self.states.ON_FIELDWORK_COURSE then
		local dist, turns = self.course:getRemainingDistanceAndTurnsFrom(ix)
		local turnTime = turns * self.turnDurationMs / 1000
		self.vehicle.cp.timeRemaining = math.max(0, dist / (self:getWorkSpeed() / 3.6) + turnTime)
		self:debug('Distance to go: %.1f; Turns left: %d; Time left: %ds', dist, turns, self.vehicle.cp.timeRemaining)
	else
		self:clearRemainingTime()
	end
end

function FieldworkAIDriver:measureTurnTime()
	local isTurning = self.state == self.states.ON_FIELDWORK_COURSE and self.fieldworkState == self.states.TURNING
	if self.wasTurning and not isTurning then
		-- end of turn
		if self.turnStartedAt then
			-- use sliding average to smooth jumps
			self.turnDurationMs = (self.turnDurationMs + self.vehicle.timer - self.turnStartedAt) / 2
			self.realTurnDurationMs = self.vehicle.timer - self.turnStartedAt
			self:debug('Measured turn duration is %.0f ms', self.turnDurationMs)
		end
	elseif not self.wasTurning and isTurning then
		-- start of turn
		self.turnStartedAt = self.vehicle.timer
	end
	self.wasTurning = isTurning
end

function FieldworkAIDriver:checkWeather()
	if self.vehicle.getIsThreshingAllowed and not self.vehicle:getIsThreshingAllowed() then
		self:debugSparse('No threshing in rain...')
		self:setSpeed(0)
		self:setInfoText('WEATHER')
	else
		self:clearInfoText('WEATHER')
	end
end

function FieldworkAIDriver:updateLights()
	if not self.vehicle.spec_lights then return end
	-- turn on beacon lights on unload/refill course when enabled
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE and self:areBeaconLightsEnabled() then
		self.vehicle:setBeaconLightsVisibility(true)
	else
		self:updateLightsOnField()
	end
end

function FieldworkAIDriver:updateLightsOnField()
	-- there are no beacons used on the field by default
	self.vehicle:setBeaconLightsVisibility(false)
end

function FieldworkAIDriver:startLoweringDurationTimer()
	-- then start but only after everything is unfolded as we don't want to include the
	-- unfold duration (since we don't fold at the end of the row).
	if self:isAllUnfolded() then
		self.startedLoweringAt = self.vehicle.timer
	end
end

function FieldworkAIDriver:calculateLoweringDuration()
	if self.startedLoweringAt then
		self.loweringDurationMs = self.vehicle.timer - self.startedLoweringAt
		self:debug('Measured implement lowering duration is %.0f ms', self.loweringDurationMs)
		self.startedLoweringAt = nil
	end
end

function FieldworkAIDriver:getLoweringDurationMs()
	return self.loweringDurationMs
end

function FieldworkAIDriver:calculateTightTurnOffset()
    self.tightTurnOffset = AIDriverUtil.calculateTightTurnOffset(self.vehicle, self.course, self.tightTurnOffset)
end

function FieldworkAIDriver:getFillLevelInfoText()
	return 'NEEDS_REFILLING'
end

function FieldworkAIDriver:lowerImplements()
	for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
		implement.object:aiImplementStartLine()
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)
	if FieldworkAIDriver.hasImplementWithSpecialization(self.vehicle, SowingMachine) or self.ppc:isReversing() then
		-- sowing machines want to stop while the implement is being lowered
		-- also, when reversing, we assume that we'll switch to forward, so stop while lowering, then start forward
		self.fieldworkState = self.states.WAITING_FOR_LOWER_DELAYED
	end
end

function FieldworkAIDriver:raiseImplements()
	for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
		implement.object:aiImplementEndLine()
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
end

function FieldworkAIDriver:rememberWaypointToContinueFieldwork()
	local bestKnownCurrentWpIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
	-- after we return from a refill/unload, continue a bit before the point where we left to
	-- make sure not leaving any unworked patches
	self.aiDriverData.continueFieldworkAtWaypoint = self.course:getPreviousWaypointIxWithinDistance(bestKnownCurrentWpIx, 10)
	if self.aiDriverData.continueFieldworkAtWaypoint then
		-- anything other than a turn start wp will work fine
		if self.course:isTurnStartAtIx(self.aiDriverData.continueFieldworkAtWaypoint) then
			self.aiDriverData.continueFieldworkAtWaypoint = self.aiDriverData.continueFieldworkAtWaypoint - 1
		end
	else
		self.aiDriverData.continueFieldworkAtWaypoint = bestKnownCurrentWpIx
	end
	self:debug('Will return to fieldwork at waypoint %d', self.aiDriverData.continueFieldworkAtWaypoint)
end


function FieldworkAIDriver:getCanShowDriveOnButton()
	return self.state == self.states.ON_FIELDWORK_COURSE 
end

function FieldworkAIDriver:getLoweringDurationMs()
	return self.loweringDurationMs
end

function FieldworkAIDriver:findLoweringDurationMs()
	local function getLoweringDurationMs(object)
		if object.spec_animatedVehicle then
			-- TODO: implement these in the specifications?
			return math.max(object.spec_animatedVehicle:getAnimationDuration('lowerAnimation'),
				object.spec_animatedVehicle:getAnimationDuration('rotatePickup'))
		else
			return 0
		end
	end

	self.loweringDurationMs = getLoweringDurationMs(self.vehicle)
	self:debug('Lowering duration: %d ms', self.loweringDurationMs)

	-- check all implements first
	local implements = self.vehicle:getAttachedImplements()
	for _, implement in ipairs(implements) do
		local implementLoweringDurationMs = getLoweringDurationMs(implement.object)
		self:debug('Lowering duration (%s): %d ms', implement.object:getName(), implementLoweringDurationMs)
		if implementLoweringDurationMs > self.loweringDurationMs then
			self.loweringDurationMs = implementLoweringDurationMs
		end
		local jointDescIndex = implement.jointDescIndex
		-- now check the attacher joints
		if self.vehicle.spec_attacherJoints and jointDescIndex then
			local ajs = self.vehicle.spec_attacherJoints:getAttacherJoints()
			local ajLoweringDurationMs = ajs[jointDescIndex] and ajs[jointDescIndex].moveDefaultTime or 0
			self:debug('Lowering duration (%s attacher joint): %d ms', implement.object:getName(), ajLoweringDurationMs)
			if ajLoweringDurationMs > self.loweringDurationMs then
				self.loweringDurationMs = ajLoweringDurationMs
			end
		end
	end
	if not self.loweringDurationMs or self.loweringDurationMs <= 1 then
		self.loweringDurationMs = 2000
		self:debug('No lowering duration found, setting to: %d ms', self.loweringDurationMs)
	end
	self:debug('Final lowering duration: %d ms', self.loweringDurationMs)
end

--- Never continue automatically at a wait point
function FieldworkAIDriver:isAutoContinueAtWaitPointEnabled()
	return false
end

-- instantiate generic turn course, derived classes may override
function FieldworkAIDriver:createTurnCourse()
	return CourseTurn(self.vehicle, self, self.turnContext, self.fieldworkCourse)
end

function FieldworkAIDriver:getTurnEndSideOffset()
	return 0
end

function FieldworkAIDriver:startTurn(ix)
	-- set a short lookahead distance for PPC to increase accuracy, especially after switching back from
	-- turn.lua. That often happens too early (when lowering the implement) when we still have a cross track error,
	-- this should help returning to the course faster.
	self.ppc:setShortLookaheadDistance()
	self:setMarkers()
	self.turnContext = TurnContext(self.course, ix, self.aiDriverData, self.vehicle.cp.workWidth, self.frontMarkerDistance,
			self:getTurnEndSideOffset())
	if self.vehicle.cp.settings.useAITurns:is(true) then
		if self:startAiTurn(ix) then
			return
		end
	end
	self.aiTurn = self:createTurnCourse()
	self.fieldworkState = self.states.TURNING
	self:debug('Generating turn course...')
end

--- Find the foremost and rearmost AI marker
function FieldworkAIDriver:setMarkers()
	local markers= {}
	local addMarkers = function(object, referenceNode)
		self:debug('Finding AI markers of %s', nameNum(object))
		local aiLeftMarker, aiRightMarker, aiBackMarker = self:getAIMarkers(object)
		if aiLeftMarker and aiBackMarker and aiRightMarker then
			local _, _, leftMarkerDistance = localToLocal(aiLeftMarker, referenceNode, 0, 0, 0)
			local _, _, rightMarkerDistance = localToLocal(aiRightMarker, referenceNode, 0, 0, 0)
			local _, _, backMarkerDistance = localToLocal(aiBackMarker, referenceNode, 0, 0, 0)
			table.insert(markers, leftMarkerDistance)
			table.insert(markers, rightMarkerDistance)
			table.insert(markers, backMarkerDistance)
			self:debug('%s: left = %.1f, right = %.1f, back = %.1f', nameNum(object), leftMarkerDistance, rightMarkerDistance, backMarkerDistance)
		end
	end

	local referenceNode = AIDriverUtil.getDirectionNode(self.vehicle)
	-- now go ahead and try to find the real markers
	-- work areas of the vehicle itself
	addMarkers(self.vehicle, referenceNode)
	-- and then the work areas of all the implements
	for _, implement in pairs( self:getAllAIImplements(self.vehicle)) do
		addMarkers(implement.object, referenceNode)
	end

	if #markers == 0 then
		-- make sure we always have a default front/back marker, placed on the direction node if nothing else found
		table.insert(markers, 0)
		table.insert(markers, 3)
	end
	-- now that we have all, find the foremost and the last
	self.frontMarkerDistance, self.backMarkerDistance = 0, 0
	local frontMarkerDistance, backMarkerDistance = -math.huge, math.huge
	for _, d in pairs(markers) do
		if d > frontMarkerDistance then
			frontMarkerDistance = d
		end
		if d < backMarkerDistance then
			backMarkerDistance = d
		end
	end
	-- set these up for turn.lua. TODO: pass in with the turn context and get rid of the aiFrontMarker and backMarkerOffset completely
	self.vehicle.cp.aiFrontMarker = frontMarkerDistance
	self.frontMarkerDistance = frontMarkerDistance
	self.vehicle.cp.backMarkerOffset = backMarkerDistance
	self.backMarkerDistance = backMarkerDistance
	self:debug('front marker: %.1f, back marker: %.1f', frontMarkerDistance, backMarkerDistance)
end

function FieldworkAIDriver:getAIMarkers(object, suppressLog)
	local aiLeftMarker, aiRightMarker, aiBackMarker
	if object.getAIMarkers then
		aiLeftMarker, aiRightMarker, aiBackMarker = object:getAIMarkers()
	end
	if not aiLeftMarker or not aiRightMarker or not aiLeftMarker then
		-- use the root node if there are no AI markers
		if not suppressLog then
			self:debug('%s has no AI markers, try work areas', nameNum(object))
		end
		aiLeftMarker, aiRightMarker, aiBackMarker = self:getAIMarkersFromWorkAreas(object)
		if not aiLeftMarker or not aiRightMarker or not aiLeftMarker then
			if not suppressLog then
				self:debug('%s has no work areas, giving up', nameNum(object))
			end
			return nil, nil, nil
		else
			return aiLeftMarker, aiRightMarker, aiBackMarker
		end
	else
		return aiLeftMarker, aiRightMarker, aiBackMarker
	end
end

--- When finishing a turn, is it time to lower all implements here?
-- TODO: remove the reversing parameter and use ppc to find out once not called from turn.lua
function FieldworkAIDriver:shouldLowerImplements(turnEndNode, reversing)
	-- see if the vehicle has AI markers -> has work areas (built-in implements like a mower or cotton harvester)
	local doLower, vehicleHasMarkers = self:shouldLowerThisImplement(self.vehicle, turnEndNode, reversing)
	if not vehicleHasMarkers and reversing then
		-- making sure the 'and' below will work if reversing and the vehicle has no markers
		doLower = true
	end
	-- and then check all implements
	for _, implement in ipairs(self:getAllAIImplements(self.vehicle)) do
		if reversing then
			-- when driving backward, all implements must reach the turn end node before lowering, hence the 'and'
			doLower = doLower and self:shouldLowerThisImplement(implement.object, turnEndNode, reversing)
		else
			-- when driving forward, if it is time to lower any implement, we'll lower all, hence the 'or'
			doLower = doLower or self:shouldLowerThisImplement(implement.object, turnEndNode, reversing)
		end
	end
	return doLower
end

---@param object table is a vehicle or implement object with AI markers (marking the working area of the implement)
---@param turnEndNode number node at the first waypoint of the row, pointing in the direction of travel. This is where
--- the implement should be in the working position after a turn
---@param reversing boolean are we reversing? When reversing towards the turn end point, we must lower the implements
--- when we are _behind_ the turn end node (dz < 0), otherwise once we reach it (dz > 0)
---@return boolean, boolean the second one is true when the first is valid
function FieldworkAIDriver:shouldLowerThisImplement(object, turnEndNode, reversing)
	local aiLeftMarker, aiRightMarker, aiBackMarker = self:getAIMarkers(object, true)
	if not aiLeftMarker then return false, false end
	local _, _, dzLeft = localToLocal(aiLeftMarker, turnEndNode, 0, 0, 0)
	local _, _, dzRight = localToLocal(aiRightMarker, turnEndNode, 0, 0, 0)
	local _, _, dzBack = localToLocal(aiBackMarker, turnEndNode, 0, 0, 0)
	local loweringDistance
	if FieldworkAIDriver.hasImplementWithSpecialization(self.vehicle, SowingMachine) then
		-- sowing machines are stopped while lowering, but leave a little reserve to allow for stopping
		-- TODO: rather slow down while approaching the lowering point
		loweringDistance = 0.5
	else
		-- others can be lowered without stopping so need to start lowering before we get to the turn end to be
		-- in the working position by the time we get to the first waypoint of the next row
		loweringDistance = self.vehicle.lastSpeed * self:getLoweringDurationMs() + 0.5 -- vehicle.lastSpeed is in meters per millisecond
	end
	local dzFront = (dzLeft + dzRight) / 2
	self:debug('%s: dzLeft = %.1f, dzRight = %.1f, dzFront = %.1f, dzBack = %.1f, loweringDistance = %.1f, reversing %s',
		nameNum(object), dzLeft, dzRight, dzFront, dzBack, loweringDistance, tostring(reversing))
	local dz = self.vehicle.cp.settings.implementLowerTime:is(ImplementRaiseLowerTimeSetting.EARLY) and dzFront or dzBack
	if reversing then
		return dz < 0 , true
	else
		-- dz will be negative as we are behind the target node
		return dz > - loweringDistance, true
	end
end

function FieldworkAIDriver:shouldRaiseImplements(turnStartNode)
	-- see if the vehicle has AI markers -> has work areas (built-in implements like a mower or cotton harvester)
	local doRaise = self:shouldRaiseThisImplement(self.vehicle, turnStartNode)
	-- and then check all implements
	for _, implement in ipairs(self:getAllAIImplements(self.vehicle)) do
		-- only when _all_ implements can be raised will we raise them all, hence the 'and'
		doRaise = doRaise and self:shouldRaiseThisImplement(implement.object, turnStartNode)
	end
	return doRaise
end

---@param turnStartNode node at the last waypoint of the row, pointing in the direction of travel. This is where
--- the implement should be raised when beginning a turn
function FieldworkAIDriver:shouldRaiseThisImplement(object, turnStartNode)
	local aiFrontMarker, _, aiBackMarker = self:getAIMarkers(object, true)
	-- if something (like a combine) does not have an AI marker it should not prevent from raising other implements
	-- like the header, which does have markers), therefore, return true here
	if not aiBackMarker or not aiFrontMarker then return true end
	local marker = self.vehicle.cp.settings.implementRaiseTime:is(ImplementRaiseLowerTimeSetting.EARLY) and aiFrontMarker or aiBackMarker
	-- turn start node in the back marker node's coordinate system
	local _, _, dz = localToLocal(marker, turnStartNode, 0, 0, 0)
	self:debug('%s: shouldRaiseImplements: dz = %.1f', nameNum(object), dz)
	-- marker is just in front of the turn start node
	return dz > 0
end

--- Are all implements now aligned with the node? Can be used to find out if we are for instance aligned with the
--- turn end node direction in a question mark turn and can start reversing.
function FieldworkAIDriver:areAllImplementsAligned(node)
	-- see if the vehicle has AI markers -> has work areas (built-in implements like a mower or cotton harvester)
	local allAligned = self:isThisImplementAligned(self.vehicle, node)
	-- and then check all implements
	for _, implement in ipairs(self:getAllAIImplements(self.vehicle)) do
		-- _all_ implements must be aligned, hence the 'and'
		allAligned = allAligned and self:isThisImplementAligned(implement.object, node)
	end
	return allAligned
end

function FieldworkAIDriver:isThisImplementAligned(object, node)
	local aiFrontMarker, _, _ = self:getAIMarkers(object, true)
	if not aiFrontMarker then return true end
	return TurnContext.isSameDirection(aiFrontMarker, node, 2)
end

function FieldworkAIDriver:onDraw()

	if not courseplay.debugChannels[6] then return end

	local function showAIMarkersOfObject(object)
		if object.getAIMarkers then
			local aiLeftMarker, aiRightMarker, aiBackMarker = object:getAIMarkers()
			if aiLeftMarker then
				DebugUtil.drawDebugNode(aiLeftMarker, object:getName() .. ' AI Left')
			end
			if aiRightMarker then
				DebugUtil.drawDebugNode(aiRightMarker, object:getName() .. ' AI Right')
			end
			if aiBackMarker then
				DebugUtil.drawDebugNode(aiBackMarker, object:getName() .. ' AI Back')
			end
		end
		if object.getAISizeMarkers then
			local aiSizeLeftMarker, aiSizeRightMarker, aiSizeBackMarker = object:getAISizeMarkers()
			if aiSizeLeftMarker then
				DebugUtil.drawDebugNode(aiSizeLeftMarker, object:getName() .. ' AI Size Left')
			end
			if aiSizeRightMarker then
				DebugUtil.drawDebugNode(aiSizeRightMarker, object:getName() .. ' AI Size Right')
			end
			if aiSizeBackMarker then
				DebugUtil.drawDebugNode(aiSizeBackMarker, object:getName() .. ' AI Size Back')
			end
		end
		DebugUtil.drawDebugNode(object.cp.directionNode or object.rootNode, object:getName() .. ' root')
	end

	showAIMarkersOfObject(self.vehicle)
	-- draw the Giant's supplied AI markers for all implements
	local implements = self:getAllAIImplements(self.vehicle)
	if implements then
		for _, implement in ipairs(implements) do
			showAIMarkersOfObject(implement.object)
		end
	end

	if self.plowReferenceNode then
		DebugUtil.drawDebugNode(self.plowReferenceNode, 'Plow reference')
	end

	AIDriver.onDraw(self)
end

function FieldworkAIDriver:isValidWorkArea(area)
	return area.start and area.height and area.width and
		area.type ~= WorkAreaType.RIDGEMARKER and
		area.type ~= WorkAreaType.COMBINESWATH and
		area.type ~= WorkAreaType.COMBINECHOPPER
end

--- Calculate the front and back marker nodes of a work area
function FieldworkAIDriver:getAIMarkersFromWorkAreas(object)
	-- work areas are defined by three nodes: start, width and height. These nodes
	-- define a rectangular work area which you can make visible with the
	-- gsVehicleDebugAttributes console command and then pressing F5
	for _, area in courseplay:workAreaIterator(object) do
		if self:isValidWorkArea(area) then
			-- for now, just use the first valid work area we find
			self:debug('%s: Using %s work area markers as AIMarkers', nameNum(object), g_workAreaTypeManager.workAreaTypes[area.type].name)
			return area.start, area.width, area.height
		end
	end
end

function FieldworkAIDriver:getAllAIImplements(object, implements)
	if not implements then implements = {} end
	for _, implement in ipairs(object:getAttachedImplements()) do
		-- ignore everything which has no work area
		if self:isValidAIImplement(implement.object) then
			table.insert(implements, implement)
		end
		self:getAllAIImplements(implement.object, implements)
	end
	return implements
end

-- Is this and implement we should consider when deciding when to lift/raise implements at the end/start of a row?
function FieldworkAIDriver:isValidAIImplement(object)
	if courseplay:hasWorkAreas(object) then
		-- has work areas, good.
		return true
	else
		local aiLeftMarker, _, _ = self:getAIMarkers(object, true)
		if aiLeftMarker then
			-- has AI markers, good
			return true
		else
			-- no work areas, no AI markers, can't use.
			return false
		end
	end
end

function FieldworkAIDriver:startAiTurn(ix)
	self:debug('Starting an AI turn.')
	if AITurn.canMakeKTurn(self.vehicle, self.turnContext) then
		self:debug('Starting a K turn')
		---@type AITurn
		self.aiTurn = KTurn(self.vehicle, self, self.turnContext)
		self.fieldworkState = self.states.TURNING
		return true
	else
		self:debug('Can\'t make K turn, reverting to turn.lua')
		return false
	end
end

function FieldworkAIDriver:startFieldworkCourseWithTemporaryCourse(temporaryCourse, fieldworkIx)
	self:startCourse(temporaryCourse, 1, self.fieldworkCourse, fieldworkIx)
end

-- switch back to fieldwork after the turn ended.
function FieldworkAIDriver:resumeFieldworkAfterTurn(ix)
	self.ppc:setNormalLookaheadDistance()
	self.fieldworkState = self.states.WORKING
	self:lowerImplements()
	-- restore our own listeners for waypoint changes
	self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
	self:startCourse( self.fieldworkCourse, self.fieldworkCourse:getNextFwdWaypointIxFromVehiclePosition(ix, AIDriverUtil.getDirectionNode(self.vehicle), 0))
end

--- Don't pay worker double when AutoDrive is driving
function FieldworkAIDriver:shouldPayWages()
	return self.state ~= self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE
end

function FieldworkAIDriver:onBlocked()
	if self.state == self.states.ON_FIELDWORK_COURSE and self.fieldworkState == self.states.TURNING and self.aiTurn then
		self.aiTurn:onBlocked()
	end
end

function FieldworkAIDriver:setOffsetX()
	-- implement in derived classes if needed
end
