--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2020 Thomas Gärtner, Peter Vaiko

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
]]--

--[[

How do we make sure the unloader does not collide with the combine?

1. ProximitySensor

The ProximitySensor is a generic AIDriver feature.

The combine has a proximity sensor on the back and will slow down and stop
if something is in range.

The unloader has a proximity sensor on the front to prevent running into the combine
and to swerve other vehicles in case of a head on collision for example.

In some states, for instance when unloading choppers, the tractor disables the generic
speed control as it has to drive very close to the chopper.

There is an additional proximity sensor dedicated to following the chopper. This has
all controlling features disabled.

2. Turns

The combine stops when discharging during a turn, so at the end of a row or headland turn
it won't start the turn until it is empty.

3. Combine Ready For Unload

The unloader can also ask the combine if it is ready to unload (isReadyToUnload()), as we
expect the combine to know best when it is going to perform some maneuvers.

4. Cooperative Collision Avoidance Using the TrafficController

This is currently screwed up...


]]--

-- TODO: swerve to the correct direction at low angles
-- TODO: move back second unloader when first one moves back
-- TODO: recalculate path when stuck in traffic longer

---@class CombineUnloadAIDriver : AIDriver
CombineUnloadAIDriver = CpObject(AIDriver)

CombineUnloadAIDriver.safetyDistanceFromChopper = 0.75
CombineUnloadAIDriver.targetDistanceBehindChopper = 1
CombineUnloadAIDriver.targetOffsetBehindChopper = 3 -- 3 m to the right
CombineUnloadAIDriver.targetDistanceBehindReversingChopper = 2
CombineUnloadAIDriver.minDistanceFromReversingChopper = 10
CombineUnloadAIDriver.minDistanceFromWideTurnChopper = 5
CombineUnloadAIDriver.minDistanceWhenMovingOutOfWay = 5
CombineUnloadAIDriver.safeManeuveringDistance = 30 -- distance to keep from a combine not ready to unload
CombineUnloadAIDriver.unloaderFollowingDistance = 30 -- distance to keep between two unloaders assigned to the same chopper
CombineUnloadAIDriver.pathfindingRange = 5 -- won't do pathfinding if target is closer than this
CombineUnloadAIDriver.proximitySensorRange = 15

CombineUnloadAIDriver.myStates = {
	ON_FIELD = {},
	ON_UNLOAD_COURSE =
		{checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	WAITING_FOR_COMBINE_TO_CALL ={},
	WAITING_FOR_PATHFINDER= {},
	DRIVE_TO_COMBINE =
		{checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	DRIVE_TO_MOVING_COMBINE =
		{checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	DRIVE_TO_FIRST_UNLOADER =
		{checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	DRIVE_TO_UNLOAD_COURSE =
		{checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	UNLOADING_MOVING_COMBINE = {},
	UNLOADING_STOPPED_COMBINE = {},
	FOLLOW_CHOPPER =
		{isUnloadingChopper = true, enableProximitySpeedControl = true},
	FOLLOW_FIRST_UNLOADER =
		{checkForTrafficConflict = true},
	MOVE_BACK_FROM_REVERSING_CHOPPER =
		{isUnloadingChopper = true},
	MOVE_BACK_FROM_EMPTY_COMBINE = {},
	MOVE_BACK_FULL = {},
	HANDLE_CHOPPER_HEADLAND_TURN = {isUnloadingChopper = true, isHandlingChopperTurn = true},
	HANDLE_CHOPPER_180_TURN =
		{isUnloadingChopper = true, isHandlingChopperTurn = true, enableProximitySpeedControl = true},
	FOLLOW_CHOPPER_THROUGH_TURN =
		{isUnloadingChopper = true, isHandlingChopperTurn = true, enableProximitySpeedControl = true},
	ALIGN_TO_CHOPPER_AFTER_TURN =
		{isUnloadingChopper = true, isHandlingChopperTurn = true, enableProximitySpeedControl = true},
	MOVING_OUT_OF_WAY = {isUnloadingChopper = true},
	WAITING_FOR_MANEUVERING_COMBINE = {},
}

--- Constructor
function CombineUnloadAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	self.assignedCombinesSetting = AssignedCombinesSetting(vehicle)
	AIDriver.init(self, vehicle)
	self.debugChannel = 4
	self.mode = courseplay.MODE_COMBI
	self:initStates(CombineUnloadAIDriver.myStates)
	self.combineOffset = 0
	self.distanceToCombine = math.huge
	self.distanceToFront = 0
	self.combineToUnloadReversing = 0
	self.doNotSwerveForVehicle = CpTemporaryObject()
end

function CombineUnloadAIDriver:getAssignedCombines()
	return self.assignedCombinesSetting:getData()
end

function CombineUnloadAIDriver:getAssignedCombinesSetting()
	return self.assignedCombinesSetting
end

function CombineUnloadAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setCombineUnloadAIDriverContent(self.vehicle,self.assignedCombinesSetting)
end

function CombineUnloadAIDriver:onWriteStream(streamId)
	self.assignedCombinesSetting:onWriteStream(streamId)
	AIDriver.onWriteStream(self,streamId)
end

function CombineUnloadAIDriver:onReadStream(streamId)
	self.assignedCombinesSetting:onReadStream(streamId)
	AIDriver.onReadStream(self,streamId)
end

function CombineUnloadAIDriver:debug(...)
	local combineName = self.combineToUnload and (' -> ' .. nameNum(self.combineToUnload)) or '(unassigned)'
	courseplay.debugVehicle(self.debugChannel, self.vehicle, combineName .. ': ' .. string.format( ... ))
end

function CombineUnloadAIDriver:start(startingPoint)

	self:beforeStart()
	-- disable the legacy collision detection snake
	self:disableCollisionDetection()

	self:resetPathfinder()
	self:addChopperProximitySensor()

	self.state = self.states.RUNNING

	self.unloadCourse = Course(self.vehicle, self.vehicle.Waypoints)
	self.ppc:setNormalLookaheadDistance()

	if startingPoint:is(StartingPointSetting.START_WITH_UNLOAD) then
		if CpManager.isDeveloper then
			-- automatically select closest combine
			self.assignedCombinesSetting:selectClosest()
		end
		self:info('Start unloading, waiting for a combine to call')
		self:setNewState(self.states.ON_FIELD)
		self:disableCollisionDetection()
		self:setDriveUnloadNow(false)
		self:startWaitingForCombine()
	else
		-- just to have a course set up in any case for PPC to work with until we find a combine/path
		self:startCourse(self.unloadCourse, 1)
		local ix = self.unloadCourse:getStartingWaypointIx(AIDriverUtil.getDirectionNode(self.vehicle), startingPoint)
		self:info('AI driver in mode %d starting at %d/%d waypoints (%s)',
				self:getMode(), ix, self.unloadCourse:getNumberOfWaypoints(), tostring(startingPoint))
		self:startCourseWithPathfinding(self.unloadCourse, ix, 0, 0)
		self:setNewState(self.states.ON_UNLOAD_COURSE)
	end
	self.distanceToFront = 0
end

function CombineUnloadAIDriver:dismiss()
	local x,_,z = getWorldTranslation(self:getDirectionNode())
	if self.combineToUnload then
		self.combineToUnload.cp.driver:deregisterUnloader(self)
	end
	self:releaseUnloader()
	if courseplay:isField(x, z) then
		self:setNewState(self.states.ON_FIELD)
		self:startWaitingForCombine()
	end
	AIDriver.dismiss(self)
end

function CombineUnloadAIDriver:drive(dt)
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	self:updateCombineStatus()

	if self.state == self.states.ON_UNLOAD_COURSE then
		self:driveUnloadCourse(dt)
		self:enableFillTypeUnloading()
	elseif self.state == self.states.ON_FIELD then
		self.triggerHandler:disableFillTypeUnloading()
		local renderOffset = self.vehicle.cp.coursePlayerNum * 0.03
		self:renderText(0, 0.1 + renderOffset, "%s: self.onFieldState :%s", nameNum(self.vehicle), self.onFieldState.name)
		self:driveOnField(dt)
	end
end

--enables unloading for CombineUnloadAIDriver with triggerHandler, but gets overwritten by OverloaderAIDriver, as it's not needed for it.
function CombineUnloadAIDriver:enableFillTypeUnloading()
	self.triggerHandler:enableFillTypeUnloading()
	self.triggerHandler:enableFillTypeUnloadingBunkerSilo()
end

function CombineUnloadAIDriver:driveUnloadCourse(dt)
	-- TODO: refactor that whole unload process, it was just copied from the legacy CP code
	self:searchForTipTriggers()
	local allowedToDrive, giveUpControl = self:onUnLoadCourse(true, dt)
	if not allowedToDrive then
		self:hold()
	end
	if not giveUpControl then
		AIDriver.drive(self, dt)
	end
end

function CombineUnloadAIDriver:resetPathfinder()
	self.maxFruitPercent = 10
	-- prefer driving on field, don't do this too aggressively until we take into account the field owner
	-- otherwise we'll be driving through others' fields
	self.offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty
	self.pathfinderFailureCount = 0
end

function CombineUnloadAIDriver:addForwardProximitySensor()
	self:setFrontMarkerNode(self.vehicle)
	self.forwardLookingProximitySensorPack = WideForwardLookingProximitySensorPack(
			self.vehicle, self.ppc, self:getFrontMarkerNode(self.vehicle), self.proximitySensorRange, 1, 2)
end

--- Proximity sensor to check the chopper's distance
function CombineUnloadAIDriver:addChopperProximitySensor()
	self:setFrontMarkerNode(self.vehicle)
	---@type ProximitySensorPack
	self.chopperProximitySensorPack = ProximitySensorPack('chopper',
			self.vehicle, self.ppc, self:getFrontMarkerNode(self.vehicle), 10, 1.2, {0, 45, 90, -45, -90}, {0, 0, 0, 0, 0})
	self.chopperProximitySensorPack:disableRotateToGoalPoint()
end

function CombineUnloadAIDriver:isTrafficConflictDetectionEnabled()
	return self.trafficConflictDetectionEnabled and
			(self.state == self.states.ON_UNLOAD_COURSE and self.state.properties.checkForTrafficConflict) or
			(self.state == self.states.ON_FIELD and self.onFieldState.properties.checkForTrafficConflict)
end

function CombineUnloadAIDriver:isProximitySwerveEnabled(vehicle)
	if vehicle == self.doNotSwerveForVehicle:get() then return false end
	return (self.state == self.states.ON_UNLOAD_COURSE and self.state.properties.enableProximitySwerve) or
			(self.state == self.states.ON_FIELD and self.onFieldState.properties.enableProximitySwerve)
end

function CombineUnloadAIDriver:isProximitySpeedControlEnabled()
	return (self.state == self.states.ON_UNLOAD_COURSE and self.state.properties.enableProximitySpeedControl) or
			(self.state == self.states.ON_FIELD and self.onFieldState.properties.enableProximitySpeedControl)
end

function CombineUnloadAIDriver:startWaitingForCombine()
	-- to always have a valid course (for the traffic conflict detector mainly)
	self:startCourse(self:getStraightForwardCourse(25), 1)
	self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
end

-- we want to come to a hard stop while the base class pathfinder is running (starting a course with pathfinding),
-- because the way AIDriver works, it'll initialize the PPC to the new course/waypoint, which will turn the
-- vehicle's wheels in that direction, and since setting speed to 0 will just let the vehicle roll for a while
-- it may be running into something (like the combine)
function CombineUnloadAIDriver:stopForPathfinding()
	self:hold()
end

function CombineUnloadAIDriver:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
	-- TODO: use this directly everywhere, seems to work better than the vanilla AIVehicleUtil version
	self:driveVehicleInDirection(dt, allowedToDrive, fwd, lx, lz, speed)
end

function CombineUnloadAIDriver:driveOnField(dt)

	self:drawDebugInfo()

	-- make sure if we have a combine we stay registered
	if self.combineToUnload then
		self.combineToUnload.cp.driver:registerUnloader(self)
	end

	-- safety check: combine has active AI driver
	if self.combineToUnload and not self.combineToUnload.cp.driver:isActive() then
		self:setSpeed(0)
	elseif self.vehicle.cp.settings.forcedToStop:is(true) then
		self:setSpeed(0)
	elseif self.onFieldState == self.states.WAITING_FOR_COMBINE_TO_CALL then
		local combineToWaitFor
		if self:getDriveUnloadNow() or self:getAllTrailersFull() or self:shouldDriveOn() then
			self:debug('Was waiting for a combine but drive now requested or trailer full')
			self:startUnloadCourse()
			return
		end

		-- check for an available combine but not in every loop, not needed
		if g_updateLoopIndex % 100 == 0 then
			self.combineToUnload, combineToWaitFor = g_combineUnloadManager:giveMeACombineToUnload(self.vehicle)
			if self.combineToUnload ~= nil then
				self:refreshHUD()
				self:openCovers(self.vehicle)
				self:startWorking()
			else
				if combineToWaitFor then
					courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_WAITING_FOR_FILL_LEVEL;%s", nameNum(combineToWaitFor)));
				else
					courseplay:setInfoText(self.vehicle, "COURSEPLAY_NO_COMBINE_IN_REACH");
				end
			end
		end
		self:hold()

	elseif self.onFieldState == self.states.WAITING_FOR_PATHFINDER then
		-- just wait for the pathfinder to finish
		self:setSpeed(0)

	elseif self.onFieldState == self.states.DRIVE_TO_FIRST_UNLOADER then

		-- previous first unloader not unloading anymore
		if self:iAmFirstUnloader() then
			-- switch to drive to chopper or following chopper
			self:startWorking()
		end

		self:setFieldSpeed()

		if self:isOkToStartFollowingFirstUnloader() then
			self:startFollowingFirstUnloader()
		end

	elseif self.onFieldState == self.states.WAITING_FOR_FIRST_UNLOADER then
		-- wait to become first unloader or until first unloader can be followed
		if self:iAmFirstUnloader() then
			-- switch to drive to chopper or following chopper
			self:startWorking()
		end

		self:setSpeed(0)

		if self:isOkToStartFollowingFirstUnloader() then
			self:startFollowingFirstUnloader()
		end

	elseif self.onFieldState == self.states.DRIVE_TO_COMBINE then

		-- do not swerve for our combine, otherwise we won't be able to align with it when coming from
		-- the wrong angle
		self.doNotSwerveForVehicle:set(self.combineToUnload, 2000)

		courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_TO_COMBINE");

		self:setFieldSpeed()

		-- stop when too close to a combine not ready to unload (wait until it is done with turning for example)
		if self:isWithinSafeManeuveringDistance(self.combineToUnload) then
			self:debugSparse('Too close to maneuvering combine, stop.')
			--self:hold()
		else
			self:setFieldSpeed()
		end

		if self:isOkToStartUnloadingCombine() then
			self:startUnloadingCombine()
		elseif self:isOkToStartFollowingChopper() then
			self:startFollowingChopper()
		end

	elseif self.onFieldState == self.states.DRIVE_TO_MOVING_COMBINE then

		self:driveToMovingCombine()

	elseif self.onFieldState == self.states.UNLOADING_STOPPED_COMBINE then

		self:unloadStoppedCombine()

	elseif self.onFieldState == self.states.WAITING_FOR_MANEUVERING_COMBINE then

		self:waitForManeuveringCombine()

	elseif self.onFieldState == self.states.MOVING_OUT_OF_WAY then

		self:moveOutOfWay()

	elseif self.onFieldState == self.states.UNLOADING_MOVING_COMBINE then

		self:disableProximitySpeedControl()
		self:disableProximitySwerve()

		self:unloadMovingCombine(dt)

	elseif self.onFieldState == self.states.FOLLOW_CHOPPER then

		self:followChopper()

	elseif self.onFieldState == self.states.FOLLOW_FIRST_UNLOADER then

		self:followFirstUnloader()

	elseif self.onFieldState == self.states.HANDLE_CHOPPER_HEADLAND_TURN then

		self:handleChopperHeadlandTurn()

	elseif self.onFieldState == self.states.HANDLE_CHOPPER_180_TURN then

		self:handleChopper180Turn()

	elseif self.onFieldState == self.states.ALIGN_TO_CHOPPER_AFTER_TURN then

		self:alignToChopperAfterTurn()

	elseif self.onFieldState == self.states.FOLLOW_CHOPPER_THROUGH_TURN then

		self:followChopperThroughTurn()

	elseif self.onFieldState == self.states.DRIVE_TO_UNLOAD_COURSE then

		self:setFieldSpeed()

		-- try not crashing into our combine on the way to the unload course
		if self.combineJustUnloaded and
				not self.combineJustUnloaded.cp.driver:isChopper() and
				self:isWithinSafeManeuveringDistance(self.combineJustUnloaded) and
				self.combineJustUnloaded.cp.driver:isManeuvering() then
			self:debugSparse('holding for maneuvering combine %s on the unload course', self.combineJustUnloaded:getName())
			--self.combineJustUnloaded.cp.driver:hold()
		end

	elseif self.onFieldState == self.states.MOVE_BACK_FULL then
		local _, dx, dz = self:getDistanceFromCombine(self.combineJustUnloaded)
		-- drive back way further if we are behind a chopper to have room
		local dDriveBack = math.abs(dx) < 3 and 0.75 * self.vehicle.cp.turnDiameter or -10
		if dz > dDriveBack then
			self:startUnloadCourse()
		end

	elseif self.onFieldState == self.states.MOVE_BACK_FROM_EMPTY_COMBINE then
		-- drive back until the combine is in front of us
		local _, _, dz = self:getDistanceFromCombine(self.combineJustUnloaded)
		if dz > 0 then
			self:startWaitingForCombine()
		end

	elseif self.onFieldState == self.states.MOVE_BACK_FROM_REVERSING_CHOPPER then
		self:renderText(0, 0, "drive straight reverse :offset local :%s saved:%s", tostring(self.combineOffset), tostring(self.vehicle.cp.combineOffset))

		local d = self:getDistanceFromCombine()
		local combineSpeed = (self.combineToUnload.lastSpeedReal * 3600)
		local speed = combineSpeed + MathUtil.clamp(self.minDistanceFromReversingChopper - d, -combineSpeed, self.vehicle.cp.speeds.reverse * 1.5)

		self:renderText(0, 0.7, 'd = %.1f, distance diff = %.1f speed = %.1f', d, self.minDistanceFromReversingChopper - d, speed)
		-- keep 15 m distance from chopper
		self:setSpeed(speed)
		if not self:isMyCombineReversing() then
			-- resume forward course
			self:startCourse(self.followCourse, self.followCourse:getCurrentWaypointIx())
			self:setNewOnFieldState(self.states.HANDLE_CHOPPER_HEADLAND_TURN)
		end
	end
	AIDriver.drive(self, dt)
end

function CombineUnloadAIDriver:setCombineToUnloadClient(combineToUnload)
	self.combineToUnload = combineToUnload
	self.combineToUnload.cp.driver:registerUnloader(self.vehicle)
end

function CombineUnloadAIDriver:getTractorsFillLevelPercent()
	return self.tractorToFollow.cp.totalFillLevelPercent
end

function CombineUnloadAIDriver:getFillLevelPercent()
	return self.vehicle.cp.totalFillLevelPercent
end

function CombineUnloadAIDriver:getNominalSpeed()
	if self.state == self.states.ON_UNLOAD_COURSE then
		return self:getRecordedSpeed()
	else
		return self:getFieldSpeed()
	end
end

function CombineUnloadAIDriver:driveBesideCombine()
	-- we don't want a moving target
	self:fixAutoAimNode()
	local targetNode = self:getTrailersTargetNode()
	local _, offsetZ = self:getPipeOffset(self.combineToUnload)
	-- TODO: this - 1 is a workaround the fact that we use a simple P controller instead of a PI
	local _, _, dz = localToLocal(targetNode, self:getCombineRootNode(), 0, 0, - offsetZ - 1)
	-- use a factor to make sure we reach the pipe fast, but be more gentle while discharging
	local factor = self.combineToUnload.cp.driver:isDischarging() and 0.5 or 2
	local speed = self.combineToUnload.lastSpeedReal * 3600 + MathUtil.clamp(-dz * factor, -10, 15)

  	-- slow down while the pipe is unfoling to avoid crashing onto it
	if self.combineToUnload.cp.driver:isPipeMoving() then
		speed = (math.min(speed, self.combineToUnload:getLastSpeed() + 2))
    end

	self:renderText(0, 0.02, "%s: driveBesideCombine: dz = %.1f, speed = %.1f, factor = %.1f",
			nameNum(self.vehicle), dz, speed, factor)
	if  courseplay.debugChannels[self.debugChannel] then
		DebugUtil.drawDebugNode(targetNode, 'target')
	end
	self:setSpeed(math.max(0, speed))
end

function CombineUnloadAIDriver:driveBesideChopper()
	local targetNode = self:getTrailersTargetNode()
	self:renderText(0, 0.02,"%s: driveBesideChopper:offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	self:releaseAutoAimNode()
	local _, _, dz = localToLocal(targetNode, self:getCombineRootNode(), 0, 0, 5)
	self:setSpeed(math.max(0, (self.combineToUnload.lastSpeedReal * 3600) + (MathUtil.clamp(-dz, -10, 15))))
end


function CombineUnloadAIDriver:driveBehindChopper()
	self:renderText(0, 0.05, "%s: driveBehindChopper offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	self:fixAutoAimNode()
	--get required Speed
	self:setSpeed(self:getSpeedBehindChopper())
end

function CombineUnloadAIDriver:onEndCourse()
	if self.state == self.states.ON_UNLOAD_COURSE then
		self:setNewState(self.states.ON_FIELD)
		self:startWaitingForCombine()
		self:setDriveUnloadNow(false)
		self:openCovers(self.vehicle)
		self:disableCollisionDetection()
	end
end

function CombineUnloadAIDriver:onLastWaypoint()
	if self.state == self.states.ON_FIELD then
		if self.onFieldState == self.states.DRIVE_TO_UNLOAD_COURSE then
			self:setNewState(self.states.ON_UNLOAD_COURSE)
			self:closeCovers(self.vehicle)
			AIDriver.onLastWaypoint(self)
			return
		elseif self.onFieldState == self.states.DRIVE_TO_FIRST_UNLOADER then
			self:startDrivingToChopper()
		elseif self.onFieldState == self.states.DRIVE_TO_COMBINE or
			self.onFieldState == self.states.DRIVE_TO_MOVING_COMBINE then
			self:startWorking()
		elseif self.onFieldState == self.states.MOVING_OUT_OF_WAY then
			self:setNewOnFieldState(self.stateAfterMovedOutOfWay)
		end
	end
	AIDriver.onLastWaypoint(self)
end

-- if closer than this to the last waypoint, start slowing down
function CombineUnloadAIDriver:getSlowDownDistanceBeforeLastWaypoint()
	local d = AIDriver.defaultSlowDownDistanceBeforeLastWaypoint
	-- in some states there's no need to slow down before reaching the last waypoints
	if self.state == self.states.ON_FIELD then
		if self.onFieldState == self.states.DRIVE_TO_FIRST_UNLOADER then
			d = 0
		end
	end
	return d
end

function CombineUnloadAIDriver:setFieldSpeed()
	if self.course then
		self:setSpeed(self.vehicle.cp.speeds.field)
	end
end

function CombineUnloadAIDriver:setNewState(newState)
	self.state = newState
	self:debug('setNewState: %s', self.state.name)
end


function CombineUnloadAIDriver:setNewOnFieldState(newState)
	self.onFieldState = newState
	self:debug('setNewOnFieldState: %s', self.onFieldState.name)
end


function CombineUnloadAIDriver:getCourseToAlignTo(vehicle,offset)
	local waypoints = {}
	for i=-20,20,5 do
		local x,y,z = localToWorld(vehicle.rootNode,offset,0,i)
		local point = { cx = x;
						cy = y;
						cz = z;
						}
		table.insert(waypoints,point)
	end
	local tempCourse = Course(self.vehicle,waypoints)
	return tempCourse
end

function CombineUnloadAIDriver:getStraightForwardCourse(length)
	local l = length or 100
	return Course.createFromNode(self.vehicle, self.vehicle.rootNode, 0, 0, l, 5, false)
end

function CombineUnloadAIDriver:getStraightReverseCourse(length)
	local lastTrailer = AIDriverUtil.getLastAttachedImplement(self.vehicle)
	local l = length or 100
	return Course.createFromNode(self.vehicle, lastTrailer.rootNode, 0, 0, -l, -5, true)
end

function CombineUnloadAIDriver:getTrailersTargetNode()
	local allTrailersFull = true
	for i=1, #self.vehicle.cp.workTools do
		local tipper = self.vehicle.cp.workTools[i]

		local fillUnits = tipper:getFillUnits()
		for j=1, #fillUnits do
			local tipperFillType = tipper:getFillUnitFillType(j)
			local combineFillType = self.combineToUnload and self.combineToUnload.cp.driver.combine:getFillUnitLastValidFillType(self.combineToUnload.cp.driver.combine:getCurrentDischargeNode().fillUnitIndex) or FillType.UNKNOWN
			if tipper:getFillUnitFreeCapacity(j) > 0 then
				allTrailersFull = false
				if tipperFillType == FillType.UNKNOWN or tipperFillType == combineFillType or combineFillType == FillType.UNKNOWN then
					local targetNode = tipper:getFillUnitAutoAimTargetNode(1)
					if targetNode then
						return targetNode, allTrailersFull
					else
						return tipper.rootNode, allTrailersFull
					end
				end
			end
		end
	end
	self:debugSparse('Can\'t find trailer target node')
	return self.vehicle.cp.workTools[1].rootNode, allTrailersFull
end

function CombineUnloadAIDriver:getZOffsetToBehindCombine()
	return -self:getCombinesMeasuredBackDistance() - 2
end

function CombineUnloadAIDriver:getSpeedBesideChopper(targetNode)
	local allowedToDrive = true
	local baseNode = self:getPipesBaseNode(self.combineToUnload)
	--Discharge Node to AutoAimNode
	local wx, wy, wz = getWorldTranslation(targetNode)
	--cpDebug:drawLine(dnX,dnY,dnZ, 100, 100, 100, wx,wy,wz)
	-- pipe's local position in the trailer's coordinate system
	local dx,_,dz = worldToLocal(baseNode, wx, wy, wz)
	--am I too far in front but beside the chopper ?
	if dz < 3 and math.abs(dx)< math.abs(self:getSavedCombineOffset())+1 then
		allowedToDrive = false
	end
	-- negative speeds are invalid
	return math.max(0, (self.combineToUnload.lastSpeedReal * 3600) + (MathUtil.clamp(-dz, -10, 15))), allowedToDrive
end

function CombineUnloadAIDriver:getSpeedBesideCombine(targetNode)
end

function CombineUnloadAIDriver:getSpeedBehindCombine()
	if self.distanceToFront == 0 then
		self:raycastFront()
		return 0
	else
		self:raycastDistance(30)
	end
	local targetGap = 20
	local targetDistance = self.distanceToCombine - targetGap
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15))
end

function CombineUnloadAIDriver:getSpeedBehindChopper()
	local distanceToChoppersBack, _, dz = self:getDistanceFromCombine()
	local fwdDistance = self.chopperProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
	if dz < 0 then
		-- I'm way too forward, stop here as I'm most likely beside the chopper, let it pass before
		-- moving to the middle
		self:setSpeed(0)
	end
	local errorSafety = self.safetyDistanceFromChopper - fwdDistance
	local errorTarget = self.targetDistanceBehindChopper - dz
	local error = math.abs(errorSafety) < math.abs(errorTarget) and errorSafety or errorTarget
	local deltaV = MathUtil.clamp(-error * 2, -10, 15)
	local speed = (self.combineToUnload.lastSpeedReal * 3600) + deltaV
	self:renderText(0, 0.7, 'd = %.1f, dz = %.1f, speed = %.1f, errSafety = %.1f, errTarget = %.1f',
			distanceToChoppersBack, dz, speed, errorSafety, errorTarget)
	return speed
end


function CombineUnloadAIDriver:getOffsetBehindChopper()
	local distanceToChoppersBack, dx, dz = self:getDistanceFromCombine()

	local rightDistance = self.chopperProximitySensorPack:getClosestObjectDistanceAndRootVehicle(-90)
	local fwdRightDistance = self.chopperProximitySensorPack:getClosestObjectDistanceAndRootVehicle(-45)
	local minDistance = math.min(rightDistance, fwdRightDistance / 1.4)

	local currentOffsetX, _ = self.followCourse:getOffset()
	-- TODO: course offset seems to be inverted
	currentOffsetX = - currentOffsetX
	local error
	if dz < 0 and minDistance < 1000 then
		-- proximity sensor in range, use that to adjust our target offset
		-- TODO: use actual vehicle width instead of magic constant (we need to consider vehicle width
		-- as the proximity sensor is in the middle
		error = (self.safetyDistanceFromChopper + 1) - minDistance
		self.targetOffsetBehindChopper = MathUtil.clamp(self.targetOffsetBehindChopper + 0.02 * error, -20, 20)
		self:debug('err %.1f target %.1f', error, self.targetOffsetBehindChopper)
	end
	error = self.targetOffsetBehindChopper - currentOffsetX
	local newOffset = currentOffsetX + error * 0.2
	self:renderText(0, 0.68, 'right = %.1f, fwdRight = %.1f, current = %.1f, err = %1.f',
			rightDistance, fwdRightDistance, currentOffsetX, error)
	self:debug('right = %.1f, fwdRight = %.1f, current = %.1f, err = %1.f',
			rightDistance, fwdRightDistance, currentOffsetX, error)
	return MathUtil.clamp(-newOffset, -50, 50)
end

function CombineUnloadAIDriver:getSpeedBehindTractor(tractorToFollow)
	local targetDistance = 35
	local diff =  courseplay:distanceToObject(self.vehicle, tractorToFollow) - targetDistance
	return math.min(self.vehicle.cp.speeds.field,(tractorToFollow.lastSpeedReal*3600) +(MathUtil.clamp( diff,-10,25)))
end


function CombineUnloadAIDriver:getPipesBaseNode(combine)
	return g_combineUnloadManager:getPipesBaseNode(combine)
end

function CombineUnloadAIDriver:getCombineIsTurning()
	return self.combineToUnload.cp.driver and self.combineToUnload.cp.driver:isTurning()
end

-- TODO: remove this legacy function and use getPipeOffset everywhere
function CombineUnloadAIDriver:getCombineOffset(combine)
	return g_combineUnloadManager:getCombinesPipeOffset(combine)
end

---@return number, number x and z offset of the pipe's end from the combine's root node in the Giants coordinate system
---(x > 0 left, z > 0 forward) corrected with the manual offset settings
function CombineUnloadAIDriver:getPipeOffset(combine)
	return combine.cp.driver:getPipeOffset(-self.vehicle.cp.combineOffset, self.vehicle.cp.tipperOffset)
end

function CombineUnloadAIDriver:getChopperOffset(combine)
	local pipeOffset = g_combineUnloadManager:getCombinesPipeOffset(combine)
	local leftOk, rightOk = g_combineUnloadManager:getPossibleSidesToDrive(combine)
	local currentOffset = self.combineOffset
	local newOffset = currentOffset

	-- fruit on both sides, stay behind the chopper
	if not leftOk and not rightOk then
		newOffset = 0
	elseif leftOk and not rightOk then
		-- no fruit to the left
		if currentOffset >= 0 then
			-- we are already on the left or middle, go to left
			newOffset = pipeOffset
		else
			-- we are on the right, move to the middle
			newOffset = 0
		end
	elseif not leftOk and rightOk then
		-- no fruit to the right
		if currentOffset <= 0 then
			-- we are already on the right or in the middle, move to the right
			newOffset = -pipeOffset
		else
			-- we are on the left, move to the middle
			newOffset = 0
		end
	end
	if newOffset ~= currentOffset then
		self:debug('Change combine offset: %.1f -> %.1f (pipe %.1f), leftOk: %s rightOk: %s',
				currentOffset, newOffset, pipeOffset, tostring(leftOk), tostring(rightOk))
	end
	return newOffset
end

function CombineUnloadAIDriver:setSavedCombineOffset(newOffset)
	if self.vehicle.cp.combineOffsetAutoMode then
		self.vehicle.cp.combineOffset = newOffset
		self:refreshHUD()
		return newOffset
	else
		--TODO Handle manual offsets
	end
end

function CombineUnloadAIDriver:getSavedCombineOffset()
	if self.vehicle.cp.combineOffset then
		return self.vehicle.cp.combineOffset
	end
	-- else???? this does not make any sense, this is still just a nil ...
end

function CombineUnloadAIDriver:raycastFront()
	local nx, ny, nz = localDirectionToWorld(self:getDirectionNode(), 0, 0, -1)
	self.distanceToFront = 0
	for x=-1.5,1.5,0.1 do
		for y=0.2,3,0.1 do
			local rx,ry,rz = localToWorld(self.vehicle.cp.directionNode, x, y, 10)
			raycastAll(rx, ry, rz, nx, ny, nz, 'raycastFrontCallback', 10, self)
		end
	end
	print(string.format("%s: self.distanceToFront(%s)",nameNum(self.vehicle),tostring(self.distanceToFront)))
end

function CombineUnloadAIDriver:raycastFrontCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and object == self.vehicle then
			local frontDistance = 10 - distance
			if self.distanceToFront < frontDistance then
				self.distanceToFront = frontDistance
			end
			local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
			local nodeX,nodeY,nodeZ = getWorldTranslation(colliNode)
			local _,_,sz = worldToLocal(self:getDirectionNode(),nodeX,nodeY,nodeZ)
			local Tx,Ty,Tz = getTranslation(colliNode,self:getDirectionNode());
			if sz < self.distanceToFront+0.1 then
				setTranslation(colliNode, Tx,Ty,Tz+(self.distanceToFront+0.1-sz))
			end
		else
			return true
		end
	end
end

-- This all seems to be here to figure out how far we are from the combine
-- looks too complicated and fragile as it is using the collisionDetector internals and who knows where that
-- is in any moment.
function CombineUnloadAIDriver:raycastDistance(maxDistance)
	self.distanceToCombine = math.huge
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local nodeX, nodeY, nodeZ = getWorldTranslation(colliNode)
	local gx,gy,gz = localToWorld(self.combineToUnload.cp.directionNode,0,0, -(self:getCombinesMeasuredBackDistance()))
	local lx,lz =  AIVehicleUtil.getDriveDirection(colliNode, gx,gy,gz)
	local terrain = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, gx, 1, gz);
	local nx, ny, nz = localDirectionToWorld(colliNode, lx, 0, lz)
	--cpDebug:drawLine(nodeX, nodeY, nodeZ, 100, 100, 100, nodeX+(nx*distance), nodeY+(ny*distance), nodeZ+(nz*distance))
	for i=1,3 do
		raycastAll(nodeX, terrain+i, nodeZ, nx, ny, nz, 'raycastDistanceCallback', maxDistance, self)
	end
end

function CombineUnloadAIDriver:raycastDistanceCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		--print(string.format("%s in %s m",tostring(getName(hitObjectId)),tostring(distance)))
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and object == self.combineToUnload then
			cpDebug:drawPoint(x, y, z, 1, 1 , 1);
			self.distanceToCombine = math.min(distance,self.distanceToCombine)
		else
			return true
		end
	end
end

function CombineUnloadAIDriver:getCombinesMeasuredBackDistance()
	return self.combineToUnload.cp.driver:getMeasuredBackDistance()
end

function CombineUnloadAIDriver:getCanShowDriveOnButton()
	return self.state == self.states.ON_FIELD or AIDriver.getCanShowDriveOnButton(self)
end

function CombineUnloadAIDriver:setDriveNow()
	if self.state == self.states.ON_FIELD then 
		self:debug('drive now requested, changing to unload course.')
		self:releaseUnloader()
		self:startUnloadCourse()
	else 
		AIDriver.setDriveNow(self)
	end
end

function CombineUnloadAIDriver:getAllTrailersFull()
	local _, allFull = self:getTrailersTargetNode()
	return allFull
end

function CombineUnloadAIDriver:shouldDriveOn()
	return self:getFillLevelPercent() > self:getDriveOnThreshold()
end

function CombineUnloadAIDriver:getCombinesFillLevelPercent()
	return g_combineUnloadManager:getCombinesFillLevelPercent(self.combineToUnload)
end

function CombineUnloadAIDriver:getFillLevelThreshold()
	return self.vehicle.cp.settings.followAtFillLevel:get()
end

function CombineUnloadAIDriver:getDriveOnThreshold()
	return self.vehicle.cp.settings.driveOnAtFillLevel:get()
end

function CombineUnloadAIDriver:onUserUnassignedActiveCombine()
	self:debug('User unassigned active combine.')
	self:releaseUnloader()
	self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
end

function CombineUnloadAIDriver:releaseUnloader()
	g_combineUnloadManager:releaseUnloaderFromCombine(self.vehicle, self.combineToUnload)
	-- TODO: may not have to release the unloader at this point at all so no need to remember
	self.combineJustUnloaded = self.combineToUnload
	self.combineToUnload = nil
	self:refreshHUD()
end

function CombineUnloadAIDriver:getImFirstOfTwoUnloaders()
	return g_combineUnloadManager:getNumUnloaders(self.combineToUnload)==2 and g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) ==1
end

function CombineUnloadAIDriver:combineIsMakingPocket()
	local combineDriver = self.combineToUnload.cp.driver
	if combineDriver ~= nil then
		return combineDriver.fieldworkUnloadOrRefillState == combineDriver.states.MAKING_POCKET
	end
end

-- Make sure the autoAimTargetNode is not moving with the fill level
function CombineUnloadAIDriver:fixAutoAimNode()
	self.autoAimNodeFixed = true
end

-- Release the auto aim target to restore default behaviour
function CombineUnloadAIDriver:releaseAutoAimNode()
	self.autoAimNodeFixed = false
end

function CombineUnloadAIDriver:isAutoAimNodeFixed()
	return self.autoAimNodeFixed
end

-- Make sure the autoAimTargetNode is not moving with the fill level (which adds realism trying to
-- distribute the load more evenly in the trailer but makes life difficult for us)
-- TODO: instead of turning it off completely, could try to reduce the range it is adjusted
function CombineUnloadAIDriver:updateFillUnitAutoAimTarget(superFunc,fillUnit)
	local tractor = self.getAttacherVehicle and self:getAttacherVehicle() or nil
	if tractor and tractor.cp.driver and tractor.cp.driver.isAutoAimNodeFixed and tractor.cp.driver:isAutoAimNodeFixed() then
		local autoAimTarget = fillUnit.autoAimTarget
		if autoAimTarget.node ~= nil then
			if autoAimTarget.startZ ~= nil and autoAimTarget.endZ ~= nil then
				setTranslation(autoAimTarget.node, autoAimTarget.baseTrans[1], autoAimTarget.baseTrans[2], autoAimTarget.startZ)
			end
		end
	else
		superFunc(self, fillUnit)
	end
end

function CombineUnloadAIDriver:isWithinSafeManeuveringDistance(vehicle)
	local d = calcDistanceFrom(self.vehicle.rootNode, AIDriverUtil.getDirectionNode(vehicle))
	return d < self.safeManeuveringDistance
end

function CombineUnloadAIDriver:isBehindAndAlignedToChopper(maxDirectionDifferenceDeg)
	local dx, _, dz = localToLocal(self.vehicle.rootNode, AIDriverUtil.getDirectionNode(self.combineToUnload), 0, 0, 0)

	-- close enough and approximately same direction and behind and not too far to the left or right
	return dz < 0 and MathUtil.vector2Length(dx, dz) < 30 and
			TurnContext.isSameDirection(AIDriverUtil.getDirectionNode(self.vehicle), AIDriverUtil.getDirectionNode(self.combineToUnload),
					maxDirectionDifferenceDeg or 45)

end

function CombineUnloadAIDriver:isBehindAndAlignedToCombine(maxDirectionDifferenceDeg)
	local dx, _, dz = localToLocal(self.vehicle.rootNode, AIDriverUtil.getDirectionNode(self.combineToUnload), 0, 0, 0)
	local pipeOffset = self:getPipeOffset(self.combineToUnload)

	-- close enough and approximately same direction and behind and not too far to the left or right
	return dz < 0 and math.abs(dx) < math.abs(1.5 * pipeOffset) and MathUtil.vector2Length(dx, dz) < 30 and
			TurnContext.isSameDirection(AIDriverUtil.getDirectionNode(self.vehicle), AIDriverUtil.getDirectionNode(self.combineToUnload),
					maxDirectionDifferenceDeg or 45)

end

--- In front of the combine, right distance from pipe to start unloading and the combine is moving
function CombineUnloadAIDriver:isInFrontAndAlignedToMovingCombine(maxDirectionDifferenceDeg)
	local dx, _, dz = localToLocal(self.vehicle.rootNode, AIDriverUtil.getDirectionNode(self.combineToUnload), 0, 0, 0)
	local pipeOffset = self:getPipeOffset(self.combineToUnload)

	-- in front of the combine, close enough and approximately same direction, about pipe offset side distance
	-- and is not waiting (stopped) for the unloader
	if dz >= 0 and math.abs(dx) < math.abs(pipeOffset) * 1.5 and math.abs(dx) > math.abs(pipeOffset) * 0.5 and
			MathUtil.vector2Length(dx, dz) < 30 and
			TurnContext.isSameDirection(AIDriverUtil.getDirectionNode(self.vehicle), AIDriverUtil.getDirectionNode(self.combineToUnload),
					maxDirectionDifferenceDeg or 30) and
			not self.combineToUnload.cp.driver:willWaitForUnloadToFinish() then
		return true
	else
		return false
	end
end

function CombineUnloadAIDriver:isOkToStartFollowingChopper()
	return self.combineToUnload.cp.driver:isChopper() and self:isBehindAndAlignedToChopper() and self:iAmFirstUnloader()
end

function CombineUnloadAIDriver:isFollowingChopper()
	return self.state == self.states.ON_FIELD and
			self.onFieldState == self.states.FOLLOW_CHOPPER
end

function CombineUnloadAIDriver:isHandlingChopperTurn()
	return self.state == self.states.ON_FIELD and self.onFieldState.properties.isHandlingChopperTurn
end

function CombineUnloadAIDriver:isOkToStartFollowingFirstUnloader()
	if self.firstUnloader and self.firstUnloader.cp.driver:isFollowingChopper() then
		local unloaderDirectionNode = AIDriverUtil.getDirectionNode(self.firstUnloader)
		local _, _, dz = localToLocal(self.vehicle.rootNode, unloaderDirectionNode, 0, 0, 0)
		local d = calcDistanceFrom(self.vehicle.rootNode, unloaderDirectionNode)
		-- close enough and either in the same direction or behind
		if d < 1.5 * self.unloaderFollowingDistance and
				(TurnContext.isSameDirection(AIDriverUtil.getDirectionNode(self.vehicle), unloaderDirectionNode, 45) or
						dz < -(self.safeManeuveringDistance / 2)) then
			self:debug('At %d meters (%.1f behind) from first unloader %s, start following it',
					d, dz, nameNum(self.firstUnloader))
			return true
		end
	end
	return false
end

function CombineUnloadAIDriver:isOkToStartUnloadingCombine()
	if self.combineToUnload.cp.driver:isChopper() then return false end
	if self.combineToUnload.cp.driver:isReadyToUnload(self.vehicle.cp.settings.useRealisticDriving:is(true)) then
		return self:isBehindAndAlignedToCombine() or self:isInFrontAndAlignedToMovingCombine()
	else
		self:debugSparse('combine not ready to unload, waiting')
		return false
	end
end

function CombineUnloadAIDriver:iAmFirstUnloader()
	return self.vehicle == g_combineUnloadManager:getUnloaderByNumber(1, self.combineToUnload)
end

------------------------------------------------------------------------------------------------------------------------
-- Start the real work now!
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startWorking()
	if self.combineToUnload.cp.driver:isChopper() then
		if self:isOkToStartFollowingChopper() then
			self:startFollowingChopper()
		else
			self:startDrivingToChopper()
		end
	else
		if self:isOkToStartUnloadingCombine() then
			-- Right behind the combine, aligned, go for the pipe
			self:startUnloadingCombine()
		else
			self:startDrivingToCombine()
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Start the course to unload the trailers
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startUnloadCourse()
	self:debug('Changing to unload course.')
	self:startCourseWithPathfinding(self.unloadCourse, 1, 0, 0, true)
	self:setNewOnFieldState(self.states.DRIVE_TO_UNLOAD_COURSE)
	self:closeCovers(self.vehicle)
end

------------------------------------------------------------------------------------------------------------------------
-- Start to unload the combine (driving to the pipe/closer to combine)
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startUnloadingCombine()
	if self.combineToUnload.cp.driver:willWaitForUnloadToFinish() then
		self:debug('Close enough to a stopped combine, drive to pipe')
		self:startUnloadingStoppedCombine()
	else
		self:debug('Close enough to moving combine, copy combine course and follow')
		self:startCourseFollowingCombine()
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Start to unload a stopped combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startUnloadingStoppedCombine()
	-- get a path to the pipe, make the pipe 0.5 m longer so the path will be 0.5 more to the outside to make
	-- sure we don't bump into the pipe
	local offsetX, offsetZ = self:getPipeOffset(self.combineToUnload)
	local unloadCourse = Course.createFromNode(self.vehicle, self:getCombineRootNode(), offsetX, offsetZ - 5, 30, 2, false)
	self:startCourse(unloadCourse, 1)
	-- make sure to get to the course as soon as possible
	self.ppc:setShortLookaheadDistance()
	self:setNewOnFieldState(self.states.UNLOADING_STOPPED_COMBINE)
end

------------------------------------------------------------------------------------------------------------------------
-- Start to follow a chopper
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startFollowingChopper()
	self.followCourse, self.followCourseIx = self:setupFollowCourse()

	-- don't start at a turn start WP, unless the chopper is still finishing the row before the turn
	-- and waiting for us now. We don't want to start following the chopper at a turn start waypoint if the chopper
	-- isn't turning anymore
	if self.combineCourse:isTurnStartAtIx(self.followCourseIx) then
		self:debug('start following at turn start waypoint %d', self.followCourseIx)
		if not self.combineToUnload.cp.driver:isFinishingRow() then
			self:debug('chopper already started turn so moving to the next (turn end) waypoint')
			-- if the chopper is started the turn already or in the process of ending the turn, skip to the turn end waypoint
			self.followCourseIx = self.followCourseIx + 1
		end
	end

	self.followCourse:setOffset(0, 0)
	self:startCourse(self.followCourse, self.followCourseIx)
	self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
end

------------------------------------------------------------------------------------------------------------------------
-- Start to follow the first unloader (currently unloading a chopper)
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startFollowingFirstUnloader()

	if self.firstUnloader and not self.firstUnloader.cp.driver:iAmFirstUnloader() then
		self:debug('%s is not the first unloader anymore.', nameNum(self.firstUnloader))
		self:startWorking()
		return
	end

	if self.firstUnloader.cp.driver.state == self.states.ON_FIELD and
			not self.firstUnloader.cp.driver.onFieldState.properties.isUnloadingChopper then
			self:debug('%s is the first unloader but not following the chopper, has state %s', nameNum(self.firstUnloader),
				self.firstUnloader.cp.driver.onFieldState.name)
		self:startWorking()
		return
	end

	self.followCourse, _ = self:setupFollowCourse()

	self.followCourseIx = self:getWaypointIxBehindFirstUnloader(self.followCourse)

	if not self.followCourseIx then
		self:debug('Can\'t find waypoint behind %s, the first unloader', nameNum(self.firstUnloader))
		self:startWorking()
		return
	end

	self:startCourse(self.followCourse, self.followCourseIx)
	self:setNewOnFieldState(self.states.FOLLOW_FIRST_UNLOADER)
end

function CombineUnloadAIDriver:getWaypointIxBehindFirstUnloader(course)
	local firstUnloaderWpIx = self.firstUnloader.cp.driver and self.firstUnloader.cp.driver:getRelevantWaypointIx()
	return course:getPreviousWaypointIxWithinDistance(firstUnloaderWpIx, self.unloaderFollowingDistance)
end

function CombineUnloadAIDriver:setupFollowCourse()
	---@type Course
	self.combineCourse = self.combineToUnload.cp.driver:getFieldworkCourse()
	if not self.combineCourse then
		-- TODO: handle this more gracefully, or even better, don't even allow selecting combines with no course
		self:debugSparse('Waiting for combine to set up a course, can\'t follow')
		return
	end
	local followCourse = self.combineCourse:copy(self.vehicle)
	-- relevant waypoint is the closest to the combine, prefer that so our PPC will get us on course with the proper offset faster
	local followCourseIx = self.combineToUnload.cp.driver:getClosestFieldworkWaypointIx() or self.combineCourse:getCurrentWaypointIx()
	return followCourse, followCourseIx
end

------------------------------------------------------------------------------------------------------------------------
-- Start following a combine a course
-- This assumes we are in a good position to do that and can start on the course without pathfinding
-- or alignment, that is, we only call this when isOkToStartUnloadingCombine() says it is ok
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startCourseFollowingCombine()
	self.followCourse, self.followCourseIx = self:setupFollowCourse()
	self.combineOffset = self:getPipeOffset(self.combineToUnload)
	self.followCourse:setOffset(-self.combineOffset, 0)
	self:debug('Will follow combine\'s course at waypoint %d, side offset %.1f',
			self.followCourseIx, self.followCourse.offsetX)
	self:startCourse(self.followCourse, self.followCourseIx)
	self:setNewOnFieldState(self.states.UNLOADING_MOVING_COMBINE)
end

function CombineUnloadAIDriver:isPathFound(path, goalNodeInvalid, goalDescriptor)
	if path and #path > 2 then
		self:debug('Found path (%d waypoints, %d ms)', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0))
		self:resetPathfinder()
		return true
	else
		if goalNodeInvalid then
			self:error('No path found to %s, goal occupied by a vehicle, waiting...', goalDescriptor)
			return false
		else
			self.pathfinderFailureCount = self.pathfinderFailureCount + 1
			if self.pathfinderFailureCount > 1 then
				self:error('No path found to %s in %d ms, pathfinder failed at least twice, trying a path through crop and relaxing pathfinder field constraint...',
						goalDescriptor,
						self.vehicle.timer - (self.pathfindingStartedAt or 0))
				self.maxFruitPercent = math.huge
				self.offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty / 2
			elseif self.pathfinderFailureCount == 1 then
				self:error('No path found to %s in %d ms, pathfinder failed once, relaxing pathfinder field constraint...',
						goalDescriptor,
						self.vehicle.timer - (self.pathfindingStartedAt or 0))
				self.offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty / 2
			end
			return false
		end
	end
end

function CombineUnloadAIDriver:getCombineRootNode()
	-- for attached harvesters this gets the root node of the harvester as that is our reference point to the
	-- pipe offsets
	return self.combineToUnload.cp.driver:getCombine().rootNode
end

------------------------------------------------------------------------------------------------------------------------
--Start driving to chopper
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startDrivingToChopper()
	if self:iAmFirstUnloader() then
		self:debug('First unloader, start pathfinding to chopper')
		self:startPathfindingToCombine(self.onPathfindingDoneToCombine, nil, -15)
	else
		self.firstUnloader = g_combineUnloadManager:getUnloaderByNumber(1, self.combineToUnload)
		self:debug('Second unloader, start pathfinding to first unloader')
		if self:isOkToStartFollowingFirstUnloader() then
			self:startFollowingFirstUnloader()
		else
			self:startPathfindingToFirstUnloader(self.onPathfindingDoneToFirstUnloader)
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
--Start driving to combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startDrivingToCombine()
	if self.combineToUnload.cp.driver:isWaitingForUnload() then
		self:debug('Combine is waiting for unload, start finding path to combine')
		self:startPathfindingToCombine(self.onPathfindingDoneToCombine, nil, self:getZOffsetToBehindCombine())
	else
		-- combine is moving, agree on a rendezvous
		-- for now, just use the Eucledian distance. This should rather be the length of a pathfinder generated
		-- path, using the simple A* should be good enough for estimation, the hybrid A* would be too slow
		local d = self:getDistanceFromCombine()
		local estimatedSecondsEnroute = d / (self:getFieldSpeed() / 3.6) + 3 -- add a few seconds to allow for starting the engine/accelerating
		local rendezvousWaypoint, rendezvousWaypointIx = self.combineToUnload.cp.driver:getUnloaderRendezvousWaypoint(estimatedSecondsEnroute)
		local xOffset = self:getPipeOffset(self.combineToUnload)
		local zOffset = self:getZOffsetToBehindCombine()
		if rendezvousWaypoint then
			if self:isPathfindingNeeded(self.vehicle, rendezvousWaypoint, xOffset, zOffset, 25) then
				self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)
				self:debug('Start pathfinding to moving combine, %d m, ETE: %d s, meet combine at waypoint %d, xOffset = %.1f, zOffset = %.1f',
						d, estimatedSecondsEnroute, rendezvousWaypointIx, xOffset, zOffset)
				self:startPathfinding(rendezvousWaypoint, xOffset, zOffset,
						PathfinderUtil.getFieldNumUnderVehicle(self.combineToUnload),
						{self.combineToUnload}, self.onPathfindingDoneToMovingCombine)
			else
				self:debug('Rendezvous waypoint %d to moving combine too close, wait a bit', rendezvousWaypointIx)
				self:startWaitingForCombine()
			end
		else
			self:debug('can\'t find rendezvous waypoint to combine, waiting')
			self:startWaitingForCombine()
		end
	end
end

function CombineUnloadAIDriver:onPathfindingDoneToMovingCombine(path, goalNodeInvalid)
	if self:isPathFound(path, goalNodeInvalid, nameNum(self.combineToUnload)) and self.onFieldState == self.states.WAITING_FOR_PATHFINDER then
		local driveToCombineCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToCombineCourse, 1)
		self:setNewOnFieldState(self.states.DRIVE_TO_MOVING_COMBINE)
		return true
	else
		self:startWaitingForCombine()
		return false
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Pathfinding to combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startPathfindingToCombine(onPathfindingDoneFunc, xOffset, zOffset)
	local x, z = self:getPipeOffset(self.combineToUnload)
	xOffset = xOffset or x
	zOffset = zOffset or z
	self:debug('Finding path to %s, xOffset = %.1f, zOffset = %.1f', self.combineToUnload:getName(), xOffset, zOffset)
	-- TODO: here we may have to pass in the combine to ignore once we start driving to a moving combine, at least
	-- when it is on the headland.
	if self:isPathfindingNeeded(self.vehicle, self:getCombineRootNode(), xOffset, zOffset) then
		self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)
		self:startPathfinding(self:getCombineRootNode(), xOffset, zOffset,
				PathfinderUtil.getFieldNumUnderVehicle(self.combineToUnload), {}, onPathfindingDoneFunc)
	else
		self:debug('Can\'t start pathfinding, too close?')
		self:startWorking()
	end
end

function CombineUnloadAIDriver:onPathfindingDoneToCombine(path, goalNodeInvalid)
	if self:isPathFound(path, goalNodeInvalid, nameNum(self.combineToUnload)) and self.onFieldState == self.states.WAITING_FOR_PATHFINDER then
		local driveToCombineCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToCombineCourse, 1)
		self:setNewOnFieldState(self.states.DRIVE_TO_COMBINE)
		return true
	else
		self:startWaitingForCombine()
		return false
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Pathfinding to first unloader of a chopper. This is how the second unloader gets to the chopper.
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startPathfindingToFirstUnloader(onPathfindingDoneFunc)
	self:debug('Finding path to unloader %s', nameNum(self.firstUnloader))
	-- TODO: here we may have to pass in the combine to ignore once we start driving to a moving combine, at least
	-- when it is on the headland.
	if self:isPathfindingNeeded(self.vehicle, AIDriverUtil.getDirectionNode(self.firstUnloader), 0, 0) then
		self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)
		-- ignore everyone as by the time we get there they'll have moved anyway
		self:startPathfinding(self.combineToUnload.rootNode, 0, -5,
				PathfinderUtil.getFieldNumUnderVehicle(self.combineToUnload),
				{self.combineToUnload, self.firstUnloader}, onPathfindingDoneFunc)
	else
		self:debug('Won\'t start pathfinding to first unloader, too close?')
		if self:isOkToStartFollowingFirstUnloader() then
			self:startFollowingFirstUnloader()
		else
			self:setNewOnFieldState(self.states.WAITING_FOR_FIRST_UNLOADER)
			self:debug('First unloader is not ready to be followed, waiting.')
		end
	end
end

function CombineUnloadAIDriver:onPathfindingDoneToFirstUnloader(path, goalNodeInvalid)
	if self:isPathFound(path, goalNodeInvalid, nameNum(self.firstUnloader)) and self.onFieldState == self.states.WAITING_FOR_PATHFINDER then
		local driveToFirstUnloaderCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToFirstUnloaderCourse, 1)
		self:setNewOnFieldState(self.states.DRIVE_TO_FIRST_UNLOADER)
		return true
	else
		self:startWaitingForCombine()
		return false
	end
end

------------------------------------------------------------------------------------------------------------------------
--Pathfinding for wide turns
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startPathfindingToTurnEnd(xOffset, zOffset)
	self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)

	if not self.pathfinder or not self.pathfinder:isActive() then
		local done, path, goalNodeInvalid
		self.pathfindingStartedAt = self.vehicle.timer
		local turnEndNode, startOffset, goalOffset = self.turnContext:getTurnEndNodeAndOffsets()
		-- ignore combine for pathfinding, it is moving anyway and our turn functions make sure we won't hit it
		self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.findPathForTurn(self.vehicle, startOffset, turnEndNode, goalOffset,
				self.vehicle.cp.turnDiameter / 2, self:getAllowReversePathfinding(), self.followCourse, {self.combineToUnload})
		if done then
			return self:onPathfindingDoneToTurnEnd(path, goalNodeInvalid)
		else
			self:setPathfindingDoneCallback(self, self.onPathfindingDoneToTurnEnd)
			return true
		end
	else
		self:debug('Pathfinder already active')
	end
	return false
end

function CombineUnloadAIDriver:onPathfindingDoneToTurnEnd(path, goalNodeInvalid)
	if self:isPathFound(path, goalNodeInvalid, 'turn end') then
		local driveToCombineCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToCombineCourse, 1)
		self:setNewOnFieldState(self.states.FOLLOW_CHOPPER_THROUGH_TURN)
	else
		self:setNewOnFieldState(self.states.HANDLE_CHOPPER_180_TURN)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- target can be a waypoint or a node, return a node
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:getTargetNode(target)
	local targetNode
	if type(target) ~= 'number' then
		-- target is a waypoint
		if not CombineUnloadAIDriver.helperNode then
			CombineUnloadAIDriver.helperNode = courseplay.createNode('combineUnloadAIDriverHelper', target.x, target.z, target.yRot)
		end
		setTranslation(CombineUnloadAIDriver.helperNode, target.x, target.y, target.z)
		setRotation(CombineUnloadAIDriver.helperNode, 0, target.yRot, 0)
		targetNode = CombineUnloadAIDriver.helperNode
	elseif entityExists(target) then
		-- target is a node
		targetNode = target
	else
		self:debug('Target is not a waypoint or node')
	end
	return targetNode
end

------------------------------------------------------------------------------------------------------------------------
-- Check if it makes sense to start pathfinding to the target
-- This should avoid generating a big circle path to a point a few meters ahead or behind
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:isPathfindingNeeded(vehicle, target, xOffset, zOffset, range)
	local targetNode = self:getTargetNode(target)
	if not targetNode then return false end
	local startNode = AIDriverUtil.getDirectionNode(vehicle)
	local dx, _, dz = localToLocal(targetNode, startNode, xOffset, 0, zOffset)
	local d = MathUtil.vector2Length(dx, dz)
	local sameDirection = TurnContext.isSameDirection(startNode, targetNode, 30)
	if d < (range or self.pathfindingRange) and sameDirection then
		self:debug('No pathfinding needed, d = %.1f, same direction %s', d, tostring(sameDirection))
		return false
	else
		self:debug('Ok to start pathfinding, d = %.1f, same direction %s', d, tostring(sameDirection))
		return true
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Is there fruit at the target (node or waypoint)
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:isFruitAt(target, xOffset, zOffset)
	local targetNode = self:getTargetNode(target)
	if not targetNode then return false end
	local x, _, z = localToWorld(targetNode, xOffset, 0, zOffset)
	return PathfinderUtil.hasFruit(x, z, 1, 1)
end

------------------------------------------------------------------------------------------------------------------------
-- Generic pathfinder wrapper
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startPathfinding(
		target, xOffset, zOffset, fieldNum, vehiclesToIgnore,
		pathfindingCallbackFunc)
	if not self.pathfinder or not self.pathfinder:isActive() then

		if self:isFruitAt(target, xOffset, zOffset) then
			self:info('There is fruit at the target, disabling fruit avoidance')
			self.maxFruitPercent = math.huge
		end

		local done, path, goalNodeInvalid
		self.pathfindingStartedAt = self.vehicle.timer

		if type(target) ~= 'number' then
			-- TODO: clarify this xOffset thing, it looks like the course interprets the xOffset differently (left < 0) than
			-- the Giants coordinate system and the waypoint uses the course's conventions. This is confusing, should use
			-- the same reference everywhere
			self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
					self.vehicle, target, -xOffset or 0, zOffset or 0, self.allowReversePathfinding,
					fieldNum, vehiclesToIgnore,
					self.vehicle.cp.settings.useRealisticDriving:is(true) and self.maxFruitPercent or math.huge, self.offFieldPenalty)
		else
			self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
					self.vehicle, target, xOffset or 0, zOffset or 0, self.allowReversePathfinding,
					fieldNum, vehiclesToIgnore,
					self.vehicle.cp.settings.useRealisticDriving:is(true) and self.maxFruitPercent or math.huge, self.offFieldPenalty)
		end
		if done then
			return pathfindingCallbackFunc(self, path, goalNodeInvalid)
		else
			self:setPathfindingDoneCallback(self, pathfindingCallbackFunc)
			return true
		end
	else
		self:debug('Pathfinder already active')
	end
	return false
end

------------------------------------------------------------------------------------------------------------------------
-- Where are we related to the combine?
------------------------------------------------------------------------------------------------------------------------
---@return number, number, number distance between the tractor's front and the combine's back (always positive),
--- side offset (local x) of the combine's back in the tractor's front coordinate system (positive if the tractor is on
--- the right side of the combine)
--- back offset (local z) of the combine's back in the tractor's front coordinate system (positive if the tractor is behind
--- the combine)
function CombineUnloadAIDriver:getDistanceFromCombine(combine)
	local dx, _, dz = localToLocal(self:getBackMarkerNode(combine or self.combineToUnload),
			self:getFrontMarkerNode(self.vehicle), 0, 0, 0)
	return MathUtil.vector2Length(dx, dz), dx, dz
end

------------------------------------------------------------------------------------------------------------------------
-- Can drive beside combine?
-- Other code will take care of using the correct offset, all we want to know here is
-- if we can drive under the pipe, regardless of which side it is on
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:canDriveBesideCombine(combine)
	-- no fruit avoidance, don't care
	if self.vehicle.cp.settings.useRealisticDriving:is(false) then return true end
	-- TODO: or just use combine:pipeInFruit() instead?
	local leftOk, rightOk = g_combineUnloadManager:getPossibleSidesToDrive(combine)
	if leftOk and combine.cp.driver:isPipeOnLeft() then
		return true
	elseif rightOk and not combine.cp.driver:isPipeOnLeft() then
		return true
	else
		return false
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Update combine status
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:updateCombineStatus()
	if not self.combineToUnload then return end
	-- add hysteresis to reversing info from combine, isReversing() may temporarily return false during reversing, make sure we need
	-- multiple update loops to change direction
	local combineToUnloadReversing = self.combineToUnloadReversing + (self.combineToUnload.cp.driver:isReversing() and 0.1 or -0.1)
	if self.combineToUnloadReversing < 0 and combineToUnloadReversing >= 0 then
		-- direction changed
		self.combineToUnloadReversing = 1
	elseif self.combineToUnloadReversing > 0 and combineToUnloadReversing <= 0 then
		-- direction changed
		self.combineToUnloadReversing = -1
	else
		self.combineToUnloadReversing = MathUtil.clamp(combineToUnloadReversing, -1, 1)
	end
end

function CombineUnloadAIDriver:isMyCombineReversing()
	return self.combineToUnloadReversing > 0
end

------------------------------------------------------------------------------------------------------------------------
-- Check for full trailer/drive on setting when following a chopper
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:changeToUnloadWhenDriveOnLevelReached()
	--if the fillLevel is reached while turning go to Unload course
	if self:shouldDriveOn() then
		self:debug('Drive on level reached, changing to unload course')
		self:startMovingBackFromCombine(self.states.MOVE_BACK_FULL)
		return true
	end
	return false
end

------------------------------------------------------------------------------------------------------------------------
-- Check for full trailer when unloading a combine
---@return boolean true when changed to unload course
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:changeToUnloadWhenFull()
	--when trailer is full then go to unload
	if self:getDriveUnloadNow() or self:getAllTrailersFull() then
		if self:getDriveUnloadNow() then
			self:debug('drive now requested, changing to unload course.')
		else
			self:debug('trailer full, changing to unload course.')
		end
		if self.followCourse and self.followCourse:isCloseToNextTurn(10) and not self.followCourse:isCloseToLastTurn(20) then
			self:debug('... but we are too close to the end of the row, moving back before changing to unload course')
			self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
		else
			self:releaseUnloader()
			self:startUnloadCourse()
		end
		return true
	end
	return false
end

------------------------------------------------------------------------------------------------------------------------
-- Drive to moving combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:driveToMovingCombine()

	courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_TO_COMBINE");

	self:setFieldSpeed()

	-- stop when too close to a combine not ready to unload (wait until it is done with turning for example)
	if self:isWithinSafeManeuveringDistance(self.combineToUnload) and self.combineToUnload.cp.driver:isManeuvering() then
		self:startWaitingForManeuveringCombine()
	elseif self:isOkToStartUnloadingCombine() then
		self:startUnloadingCombine()
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Waiting for maneuvering combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startWaitingForManeuveringCombine()
	self:debugSparse('Too close to maneuvering combine, stop.')
	-- remember where the combine was when we started waiting
	self.lastCombinePos = {}
	self.lastCombinePos.x, self.lastCombinePos.y, self.lastCombinePos.z = getWorldTranslation(self.combineToUnload.rootNode)
	_, self.lastCombinePos.yRotation, _ = getWorldRotation(self.combineToUnload.rootNode)
	self.stateAfterWaitingForManeuveringCombine = self.onFieldState
	self:setNewOnFieldState(self.states.WAITING_FOR_MANEUVERING_COMBINE)
end

function CombineUnloadAIDriver:waitForManeuveringCombine()
	if self:isWithinSafeManeuveringDistance(self.combineToUnload) and self.combineToUnload.cp.driver:isManeuvering() then
		self:hold()
	else
		self:debug('Combine stopped maneuvering')
		--check whether the combine moved significantly while we were waiting
		local _, yRotation, _ = getWorldRotation(self.combineToUnload.rootNode)
		if math.abs(yRotation - self.lastCombinePos.yRotation) > math.pi / 6 or
				courseplay:distanceToPoint(self.combineToUnload, self.lastCombinePos.x, self.lastCombinePos.y, self.lastCombinePos.z) > 30 then
			self:debug('Combine moved or turned significantly while I was waiting, re-evaluate situation')
			self:startWorking()
		else
			self:setNewOnFieldState(self.stateAfterWaitingForManeuveringCombine)
		end
	end
end


------------------------------------------------------------------------------------------------------------------------
-- Unload combine (stopped)
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:unloadStoppedCombine()
	if self:changeToUnloadWhenFull() then return end
	local combineDriver = self.combineToUnload.cp.driver
	if combineDriver:unloadFinished() then
		if combineDriver:isWaitingForUnloadAfterCourseEnded() then
			if combineDriver:getFillLevelPercentage() < 0.1 then
				self:debug('Finished unloading combine at end of fieldwork, changing to unload course')
				self.ppc:setNormalLookaheadDistance()
				self:startMovingBackFromCombine(self.states.MOVE_BACK_FULL)
			else
				self:driveBesideCombine()
			end
		else
			self:debug('finished unloading stopped combine, move back a bit to make room for it to continue')
			self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
			self.ppc:setNormalLookaheadDistance()
		end
	else
		self:driveBesideCombine()
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Unload combine (moving)
-- We are driving on a copy of the combine's course with an offset
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:unloadMovingCombine()

	-- ignore combine for the proximity sensor
	self:ignoreVehicleProximity(self.combineToUnload, 3000)
	-- make sure the combine won't slow down when seeing us
	self.combineToUnload.cp.driver:ignoreVehicleProximity(self.vehicle, 3000)

	-- allow on the fly offset changes
	self.combineOffset = self:getPipeOffset(self.combineToUnload)
	self.followCourse:setOffset(-self.combineOffset, 0)

	if self:changeToUnloadWhenFull() then return end

	if self:canDriveBesideCombine(self.combineToUnload) or (self.combineToUnload.cp.driver and self.combineToUnload.cp.driver:isWaitingInPocket()) then
		self:driveBesideCombine()
	else
		self:debugSparse('Can\'t drive beside combine as probably fruit under the pipe but ignore that for now and continue unloading.')
		self:driveBesideCombine()
		--self:releaseUnloader()
		--self:startWaitingForCombine()
		--return
	end

	--when the combine is empty, stop and wait for next combine
	if self:getCombinesFillLevelPercent() <= 0.1 then
		--when the combine is in a pocket, make room to get back to course
		if self.combineToUnload.cp.driver and self.combineToUnload.cp.driver:isWaitingInPocket() then
			self:debug('combine empty and in pocket, drive back')
			self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
			return
		elseif self.followCourse:isCloseToNextTurn(10) and not self.followCourse:isCloseToLastTurn(20) then
			self:debug('combine empty and moving forward but we are too close to the end of the row, moving back')
			self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
			return
		else
			self:debug('combine empty and moving forward')
			self:releaseUnloader()
			self:startWaitingForCombine()
			return
		end
	end

	-- combine stopped in the meanwhile, like for example end of course
	if self.combineToUnload.cp.driver:willWaitForUnloadToFinish() then
		self:debug('change to unload stopped combine')
		self:setNewOnFieldState(self.states.UNLOADING_STOPPED_COMBINE)
		return
	end

	-- when the combine is turning just don't move
	if self.combineToUnload.cp.driver:isManeuvering() then
		self:hold()
	elseif not self:isBehindAndAlignedToCombine() and not self:isInFrontAndAlignedToMovingCombine() then
		local dx, _, dz = localToLocal(self.vehicle.rootNode, AIDriverUtil.getDirectionNode(self.combineToUnload), 0, 0, 0)
		local pipeOffset = self:getPipeOffset(self.combineToUnload)
		local sameDirection = TurnContext.isSameDirection(AIDriverUtil.getDirectionNode(self.vehicle),
			AIDriverUtil.getDirectionNode(self.combineToUnload), 15)
		local willWait = self.combineToUnload.cp.driver:willWaitForUnloadToFinish()
		self:info('not in a good position to unload, trying to recover')
		self:info('dx = %.2f, dz = %.2f, offset = %.2f, sameDir = %s', dx, dz, pipeOffset, tostring(sameDirection))
		-- switch to driving only when not holding for maneuvering combine
		-- for some reason (like combine turned) we are not in a good position anymore then set us up again
		self:startDrivingToCombine()
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Start moving back from empty combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startMovingBackFromCombine(newState)
	self:releaseUnloader()
	local reverseCourse = self:getStraightReverseCourse()
	self:startCourse(reverseCourse, 1)
	self:setNewOnFieldState(newState)
	return
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turns
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startChopperTurn(ix)
	if self.combineToUnload.cp.driver:isTurningOnHeadland() then
		self:startCourse(self.followCourse, ix)
		self:setNewOnFieldState(self.states.HANDLE_CHOPPER_HEADLAND_TURN)
	else
		self.turnContext = TurnContext(self.followCourse, ix, self.aiDriverData,
				self.combineToUnload.cp.workWidth, self.frontMarkerDistance, 0, 0)
		local finishingRowCourse = self.turnContext:createFinishingRowCourse(self.vehicle)
		self:startCourse(finishingRowCourse, 1)
		self:setNewOnFieldState(self.states.HANDLE_CHOPPER_180_TURN)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turn on headland
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:handleChopperHeadlandTurn()

	-- we'll take care of controlling our speed, don't need ADriver for that
	self:disableProximitySpeedControl()
	self:disableProximitySwerve()

	local d, _, dz = self:getDistanceFromCombine()
	local minD = math.min(d, dz)
	local speed = (self.combineToUnload.lastSpeedReal * 3600) +
			(MathUtil.clamp(minD - self.targetDistanceBehindChopper, -self.vehicle.cp.speeds.turn, self.vehicle.cp.speeds.turn))
	self:renderText(0, 0.7, 'd = %.1f, dz = %.1f, minD = %.1f, speed = %.1f', d, dz, minD, speed)
	self:setSpeed(speed)

	--if the chopper is reversing, drive backwards
	if self:isMyCombineReversing() then
		self:debug('Detected reversing chopper.')
		local reverseCourse = self:getStraightReverseCourse()
		self:startCourse(reverseCourse,1)
		self:setNewOnFieldState(self.states.MOVE_BACK_FROM_REVERSING_CHOPPER )
	end

	if self:changeToUnloadWhenDriveOnLevelReached() then return end

	--when the turn is finished, return to follow chopper
	if not self:getCombineIsTurning() then
		self:debug('Combine stopped turning, resuming follow course')
		-- resume course beside combine
		-- skip over the turn start waypoint as it will throw the PPC off course
		self:startCourse(self.followCourse, self.combineCourse:skipOverTurnStart(self.combineCourse:getCurrentWaypointIx()))
		self:setNewOnFieldState(self.states.ALIGN_TO_CHOPPER_AFTER_TURN)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Follow chopper
-- In this mode we drive the same course as the chopper but with an offset. The course may be started with
-- a temporary (pathfinder generated) course to align to the waypoint we start at.
-- After that we drive behind or beside the chopper, following the choppers fieldwork course but controlling
-- our speed to stay in the range of the pipe.
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:followChopper()

	--when trailer is full then go to unload
	if self:getDriveUnloadNow() or self:getAllTrailersFull() then
		self:startMovingBackFromCombine(self.states.MOVE_BACK_FULL)
		return
	end

	if self.course:isTemporary() and self.course:getDistanceToLastWaypoint(self.course:getCurrentWaypointIx()) > 5 then
		-- have not started on the combine's fieldwork course yet (still on the temporary alignment course)
		-- just drive the course
	else
		-- The dedicated chopper proximity sensor takes care of controlling our speed, the normal one
		-- should therefore ignore the chopper (but not others)
		self:ignoreVehicleProximity(self.combineToUnload, 3000)
		-- make sure the chopper won't slow down when seeing us
		self.combineToUnload.cp.driver:ignoreVehicleProximity(self.vehicle, 3000)
		-- when on the fieldwork course, drive behind or beside the chopper, staying in the range of the pipe
		self.combineOffset = self:getChopperOffset(self.combineToUnload)

		local dx = self:findOtherUnloaderAroundCombine(self.combineToUnload, self.combineOffset)
		if dx then
			-- there's another unloader around the combine, on either side
			if math.abs(dx) > 1 then
				-- stay behind the chopper
				self.followCourse:setOffset(0, 0)
				self.combineOffset = 0
			end
		else
			self.followCourse:setOffset(-self.combineOffset, 0)
		end


		if self.combineOffset ~= 0 then
			self:driveBesideChopper()
		else
			self:driveBehindChopper()
		end
	end

	if self.combineToUnload.cp.driver:isTurningButNotEndingTurn() then
		local combineTurnStartWpIx = self.combineToUnload.cp.driver:getTurnStartWpIx()
		if combineTurnStartWpIx then
			self:debug('chopper reached a turn waypoint, start chopper turn')
			self:startChopperTurn(combineTurnStartWpIx)
		else
			self:error('Combine is turning but does not have a turn start waypoint index.')
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turn 180
-- The default strategy here is to stop before reaching the end of the row and then wait for the combine
-- to finish the 180 turn. After it finished the turn, we drive forward a bit to make sure we are behind the
-- chopper and then continue on the chopper's fieldwork course with the appropriate offset without pathfinding.
--
-- If the combine says that it won't reverse during the turn (for example performs a wide turn because the
-- next row to work on is not adjacent the current row), we switch to 'follow chopper through the turn' mode
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:handleChopper180Turn()

	if self:changeToUnloadWhenDriveOnLevelReached() then return end

	if self.combineToUnload.cp.driver:isTurningButNotEndingTurn() then
		-- move forward until we reach the turn start waypoint
		local _, _, d = self.turnContext:getLocalPositionFromWorkEnd(self:getFrontMarkerNode(self.vehicle))
		self:debugSparse('Waiting for the chopper to turn, distance from row end %.1f', d)
		-- stop a bit before the end of the row to let the tractor slow down.
		if d > -3 then
			self:setSpeed(0)
		elseif d > 0 then
			self:hold()
		else
			self:setSpeed(self.vehicle.cp.speeds.turn)
		end
		if self.combineToUnload.cp.driver:isTurnForwardOnly() then
			---@type Course
			local turnCourse = self.combineToUnload.cp.driver:getTurnCourse()
			if turnCourse then
				self:debug('Follow chopper through the turn')
				self:startCourse(turnCourse:copy(self.vehicle), 1)
				self:setNewOnFieldState(self.states.FOLLOW_CHOPPER_THROUGH_TURN)
			else
				self:debugSparse('Chopper said turn is forward only but has no turn course')
			end
		end
	else
		local _, _, dz = self:getDistanceFromCombine()
		self:setSpeed(self.vehicle.cp.speeds.turn)
		-- start the chopper course (and thus, turning towards it) only after we are behind it
		if dz < -3 then
			self:debug('now behind chopper, continue on chopper\'s course.')
			-- reset offset, as we don't know which side is going to work after the turn.
			self.followCourse:setOffset(0, 0)
			-- skip over the turn start waypoint as it will throw the PPC off course
			self:startCourse(self.followCourse, self.combineCourse:skipOverTurnStart(self.combineCourse:getCurrentWaypointIx()))
			-- TODO: shouldn't we be using lambdas instead?
			self:setNewOnFieldState(self.states.ALIGN_TO_CHOPPER_AFTER_TURN)
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Follow chopper through turn
-- here we drive the chopper's turn course carefully keeping our distance from the combine.
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:followChopperThroughTurn()

	if self:changeToUnloadWhenDriveOnLevelReached() then return end

	local d = self:getDistanceFromCombine()
	if self.combineToUnload.cp.driver:isTurning() then
		-- making sure we are never ahead of the chopper on the course (we both drive the same course), this
		-- prevents the unloader cutting in front of the chopper when for example the unloader is on the
		-- right side of the chopper and the chopper reaches a right turn.
		if self.course:getCurrentWaypointIx() > self.combineToUnload.cp.driver.course:getCurrentWaypointIx() then
			self:hold()
		end
		-- follow course, make sure we are keeping distance from the chopper
		-- TODO: or just rely on the proximity sensor here?
		local combineSpeed = (self.combineToUnload.lastSpeedReal * 3600)
		local speed = combineSpeed + MathUtil.clamp(d - self.minDistanceFromWideTurnChopper, -combineSpeed, self.vehicle.cp.speeds.field)
		self:setSpeed(speed)
		self:renderText(0, 0.7, 'd = %.1f, speed = %.1f', d, speed)
	else
		self:debug('chopper is ending/ended turn, return to follow mode')
		self.followCourse:setOffset(0, 0)
		self:startCourse(self.followCourse, self.combineCourse:getCurrentWaypointIx())
		self:setNewOnFieldState(self.states.ALIGN_TO_CHOPPER_AFTER_TURN)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper ended a turn, we are now on the copper's course but still pointing
-- in the wrong direction. Rely on PPC to turn us around and switch to normal follow mode when
-- about in the same direction
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:alignToChopperAfterTurn()

	self:setSpeed(self.vehicle.cp.speeds.turn)

	if self:isBehindAndAlignedToChopper(45) then
		self:debug('Now aligned with chopper, continue on the side/behind')
		self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Follow first unloader who is still busy unloading a chopper. Be ready to take over if it is full
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:followFirstUnloader()
	courseplay:setInfoText(self.vehicle, "COURSEPLAY_FOLLOWING_TRACTOR");

	-- previous first unloader not unloading anymore
	if self:iAmFirstUnloader()  then
		-- switch to drive to chopper or following chopper
		self:startWorking()
		return
	end

	local dFromFirstUnloader = self.followCourse:getDistanceBetweenWaypoints(self:getRelevantWaypointIx(),
			self.firstUnloader.cp.driver:getRelevantWaypointIx())

	if self.firstUnloader.cp.driver:isStopped() or self.firstUnloader.cp.driver:isReversing() then
		self:debugSparse('holding for stopped or reversing first unloader %s', nameNum(self.firstUnloader))
		self:setSpeed(0)
	elseif self.firstUnloader.cp.driver:isHandlingChopperTurn() then
		self:debugSparse('holding for first unloader %s handing the chopper turn', nameNum(self.firstUnloader))
		self:setSpeed(0)
	else
		-- adjust our speed if we are too close or too far
		local error = dFromFirstUnloader - self.unloaderFollowingDistance
		local deltaV = MathUtil.clamp(error, -2, 2)
		local speed = self.firstUnloader.lastSpeedReal * 3600 + deltaV
		self:setSpeed(speed)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- We are blocking another vehicle who wants us to move out of way
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:onBlockingOtherVehicle(blockedVehicle)
	if not self:isActive() then return end
	self:debugSparse('%s wants me to move out of way', blockedVehicle:getName())
	if blockedVehicle.cp.driver:isChopper() then
		-- TODO: think about how to best handle choppers, since they always stop when no trailer
		-- is in range they always send these blocking events.
		--return
		self:debug('temporarily enable moving out of a chopper\'s way')
	end
	if self.onFieldState ~= self.states.MOVING_OUT_OF_WAY and
			self.onFieldState ~= self.states.MOVE_BACK_FROM_REVERSING_CHOPPER and
			self.onFieldState ~= self.states.MOVE_BACK_FROM_EMPTY_COMBINE and
			self.onFieldState ~= self.states.HANDLE_CHOPPER_HEADLAND_TURN and
			self.onFieldState ~= self.states.MOVE_BACK_FULL
	then
		-- reverse back a bit, this usually solves the problem
		-- TODO: there may be better strategies depending on the situation
		local reverseCourse = self:getStraightReverseCourse(25)
		self:startCourse(reverseCourse, 1, self.course, self.course:getCurrentWaypointIx())
		self.stateAfterMovedOutOfWay = self.onFieldState
		self:debug('Moving out of the way for %s', blockedVehicle:getName())
		self.blockedVehicle = blockedVehicle
		self:setNewOnFieldState(self.states.MOVING_OUT_OF_WAY)
		-- this state ends when we reach the end of the course or when the combine stops reversing
	else
		self:debugSparse('Already busy moving out of the way')
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Moving out of the way of a combine or chopper
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:moveOutOfWay()
	-- check both distances and use the smaller one, proximity sensor may not see the combine or
	-- d may be big enough but parts of the combine still close
	local d = self:getDistanceFromCombine(self.blockedVehicle)
	local dProximity = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
	local combineSpeed = (self.blockedVehicle.lastSpeedReal * 3600)
	local speed = combineSpeed +
			MathUtil.clamp(self.minDistanceWhenMovingOutOfWay - math.min(d, dProximity), -combineSpeed, self.vehicle.cp.speeds.reverse * 1.2)

	self:setSpeed(speed)

	if not self:isMyCombineReversing() then
		-- end reversing course prematurely, it'll resume previous course
		self:onLastWaypoint()
	end
end

function CombineUnloadAIDriver:findOtherUnloaderAroundCombine(combine, combineOffset)
	if not combine then return nil end
	if g_currentMission then
		for _, vehicle in pairs(g_currentMission.vehicles) do
			if vehicle ~= self.vehicle and vehicle.cp.driver and vehicle.cp.driver:is_a(CombineUnloadAIDriver) then
				local dx, _, dz = localToLocal(vehicle.rootNode, AIDriverUtil.getDirectionNode(combine), 0, 0, 0)
				if math.abs(dz) < 30 and math.abs(dx) <= (combineOffset + 3) then
					-- this is another unloader not too far from my combine
					-- which side it is?
					self:debugSparse('There is an other unloader (%s) around my combine (%s), dx = %.1f',
						nameNum(vehicle), nameNum(combine), dx)
					return dx
				end
			end
		end
	end
end


------------------------------------------------------------------------------------------------------------------------
-- Debug
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:drawDebugInfo()

	if not courseplay.debugChannels[self.debugChannel] then return end

	if self.combineToUnload and self.combineToUnload.cp.driver.aiDriverData.backMarkerNode then
		DebugUtil.drawDebugNode(self.combineToUnload.cp.driver.aiDriverData.backMarkerNode, 'back marker')
	end

	if self.aiDriverData.frontMarkerNode then
		DebugUtil.drawDebugNode(self.aiDriverData.frontMarkerNode, 'front marker')
	end

end

function CombineUnloadAIDriver:renderText(x, y, ...)

	if not courseplay.debugChannels[self.debugChannel] then return end

	renderText(0.6 + x, 0.2 + y, 0.018, string.format(...))
end


FillUnit.updateFillUnitAutoAimTarget =  Utils.overwrittenFunction(FillUnit.updateFillUnitAutoAimTarget,CombineUnloadAIDriver.updateFillUnitAutoAimTarget)
