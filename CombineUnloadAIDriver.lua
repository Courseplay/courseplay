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

The unloader has a proximity sensor on the front to prevent running into the combine.
When unloading choppers, the tractor disables the generic speed control as it has to
drive very close to the chopper.

2. Turns

The combine stops when discharging during a turn, so at the end of a row or headland turn
it won't start the turn until it is empty.

3. Combine Ready For Unload

The unloader can also ask the combine if it is ready to unload (isReadyToUnload()), as we
expect the combine to know best when it is going to perform some maneuvers.

4. Cooperative Collision Avoidance Using the TrafficController

This is currently screwed up...


]]--

---@class CombineUnloadAIDriver : AIDriver
CombineUnloadAIDriver = CpObject(AIDriver)

CombineUnloadAIDriver.safetyDistanceFromChopper = 0.75
CombineUnloadAIDriver.targetDistanceBehindChopper = 1
CombineUnloadAIDriver.targetOffsetBehindChopper = 3 -- 3 m to the right
CombineUnloadAIDriver.targetDistanceBehindReversingChopper = 2
CombineUnloadAIDriver.minDistanceFromReversingChopper = 10
CombineUnloadAIDriver.minDistanceFromWideTurnChopper = 5
CombineUnloadAIDriver.safeManeuveringDistance = 30 -- distance to keep from a combine not ready to unload
CombineUnloadAIDriver.pathfindingRange = 5 -- won't do pathfinding if target is closer than this

CombineUnloadAIDriver.myStates = {
	ON_FIELD = {},
	ON_STREET = {},
	WAITING_FOR_COMBINE_TO_CALL ={},
	WAITING_FOR_PATHFINDER={},
	FINDPATH_TO_TRACTOR={},
	DRIVE_TO_COMBINE = {},
	DRIVE_TO_MOVING_COMBINE = {},
	DRIVE_TO_TRACTOR={},
	DRIVE_TO_UNLOAD_COURSE ={},
	DRIVE_BESIDE_TRACTOR ={},
	ALIGN_TO_TRACTOR = {},
	GET_ALIGNCOURSE_TO_TRACTOR ={},
	UNLOADING_MOVING_COMBINE ={},
	UNLOADING_STOPPED_COMBINE = {},
	FOLLOW_CHOPPER ={},
	FOLLOW_TRACTOR = {},
	DRIVE_BACK_FROM_REVERSING_CHOPPER ={},
	DRIVE_BACK_FROM_EMPTY_COMBINE = {},
	DRIVE_BACK_FROM_REVERSING_TRACTOR = {},
	DRIVE_BACK_FULL ={},
	HANDLE_CHOPPER_HEADLAND_TURN = {},
	HANDLE_CHOPPER_180_TURN = {},
	FOLLOW_CHOPPER_THROUGH_TURN = {},
	ALIGN_TO_CHOPPER_AFTER_TURN = {},
	MOVING_OUT_OF_WAY = {},
	WAITING_FOR_MANEUVERING_COMBINE = {}
}

--- Constructor
function CombineUnloadAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.debugChannel = 4
	self.mode = courseplay.MODE_COMBI
	self:initStates(CombineUnloadAIDriver.myStates)
	self.combineOffset = 0
	self.distanceToCombine = math.huge
	self.distanceToFront = 0
	self.vehicle.cp.possibleCombines ={}
	self.vehicle.cp.assignedCombines ={}
	self.vehicle.cp.combinesListHUDOffset = 0
	self.combineToUnloadReversing = 0
end

function CombineUnloadAIDriver:setHudContent()
	courseplay.hud:setCombineUnloadAIDriverContent(self.vehicle)
end

function CombineUnloadAIDriver:debug(...)
	local combineName = self.combineToUnload and nameNum(self.combineToUnload) or 'N/A'
	courseplay.debugVehicle(self.debugChannel, self.vehicle, ' -> ' .. combineName .. ': ' .. string.format( ... ))
end

function CombineUnloadAIDriver:start(startingPoint)

	self:beforeStart()
	self:addForwardProximitySensor()

	self.state = self.states.RUNNING

	self.unloadCourse = Course(self.vehicle, self.vehicle.Waypoints)
	-- just to have a course set up in any case for PPC to work with until we find a combine/path
	self:startCourse(self.unloadCourse, 1)
	self.ppc:setNormalLookaheadDistance()

	if startingPoint:is(StartingPointSetting.START_WITH_UNLOAD) then
		self:debug('Start unloading, waiting for a combine to call')
		self:setNewState(self.states.ON_FIELD)
		self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
		self:disableCollisionDetection()
		self:setDriveUnloadNow(false)
	else
		self:debug('Start on unload course')
		local ix = self.unloadCourse:getStartingWaypointIx(AIDriverUtil.getDirectionNode(self.vehicle), startingPoint)
		self:startCourseWithPathfinding(self.unloadCourse, ix, 0, 0)
		self:setNewState(self.states.ON_STREET)
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
		self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
	end
	AIDriver.dismiss(self)
end

function CombineUnloadAIDriver:drive(dt)
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	self:updateCombineStatus()

	if self.state == self.states.ON_STREET then
		-- disable speed control as it messes up the speed control during unload
		-- TODO: refactor that whole unload process, it was just copied from the legacy CP code
		self.forwardLookingProximitySensorPack:disableSpeedControl()
		self:searchForTipTriggers()
		local allowedToDrive, giveUpControl = self:onUnLoadCourse(true, dt)
		if not allowedToDrive then
			self:hold()
		end
		if not giveUpControl then
			AIDriver.drive(self, dt)
		end
	elseif self.state == self.states.ON_FIELD then
		local renderOffset = self.vehicle.cp.coursePlayerNum * 0.03
		self:renderText(0, 0.1 + renderOffset, "%s: self.onFieldState :%s", nameNum(self.vehicle), self.onFieldState.name)
		self:driveOnField(dt)
	end
end

-- we want to come to a hard stop while the base class pathfinder is running (starting a course with pathfinding),
-- because the way AIDriver works, it'll initialize the PPC to the new course/waypoint, which will turn the
-- vehicle's wheels in that direction, and since setting speed to 0 will just let the vehicle roll for a while
-- it may be running into something (like the combine)
function CombineUnloadAIDriver:stopForPathfinding()
	self:hold()
end

function CombineUnloadAIDriver:stopAndWait(dt)
	self:driveInDirection(dt,0,1,true,0,false)
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
	elseif self.vehicle.cp.forcedToStop then
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
				courseplay:openCloseCover(self.vehicle, courseplay.OPEN_COVERS)
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

	elseif self.onFieldState == self.states.FINDPATH_TO_TRACTOR then
		--get coords of the combine
		local zOffset = -20
		local cx,cy,cz = localToWorld(self.tractorToFollow.rootNode,0,0,zOffset)
		if not courseplay:isField(cx,cz,0.1,0.1) then
			zOffset = 0
		end
		if self:driveToNodeWithPathfinding(self.tractorToFollow.rootNode, 0, zOffset, 0, self.tractorToFollow) then
					self:setNewOnFieldState(self.states.DRIVE_TO_TRACTOR)
					self.lastTractorsCoords = { x=cx;
					y=cy;
					z=cz;
					}
		end
	elseif self.onFieldState == self.states.DRIVE_TO_TRACTOR then
		self.forwardLookingProximitySensorPack:enableSpeedControl()

		--if  I'm the first Unloader switch to follow chopper
		if g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) == 1 then
			self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)
		end

		--check whether the tractor moved meanwhile
		if courseplay:distanceToPoint(self.tractorToFollow,self.lastTractorsCoords.x,self.lastTractorsCoords.y,self.lastTractorsCoords.z) > 50 then
			self:setNewOnFieldState(self.states.FINDPATH_TO_TRACTOR)
		end
		--if we are in range , change to align mode
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.rootNode)
		if courseplay:distanceToPoint(self.vehicle,cx,cy,cz) < 50 then
			self:setNewOnFieldState(self.states.GET_ALIGNCOURSE_TO_TRACTOR)
		end
		--use trafficController
		if not self:trafficControlOK() then
			local blockingVehicle = g_currentMission.nodeToObject[g_trafficController:getBlockingVehicleId(self.vehicle.rootNode)]
			if blockingVehicle and blockingVehicle ~= self.tractorToFollow then
				g_trafficController:solve(self.vehicle.rootNode)
				self:hold()
			end
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

	elseif self.onFieldState == self.states.DRIVE_TO_COMBINE then

		self.forwardLookingProximitySensorPack:enableSpeedControl()

		courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_TO_COMBINE");

		self:setFieldSpeed()

		--use trafficController
		if not self:trafficControlOK() then
			self:debugSparse('Traffic conflict, stop.')
			self:hold()
		end

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

		self:setSpeed(self.vehicle.cp.speeds.reverse)

	elseif self.onFieldState == self.states.GET_ALIGNCOURSE_TO_TRACTOR then
		local tempCourseToAlign = self:getCourseToAlignTo(self.tractorToFollow,0)
		if tempCourseToAlign ~= nil then
			self:startCourseWithAlignment(tempCourseToAlign, 1)
			self:setNewOnFieldState(self.states.ALIGN_TO_TRACTOR)
		end

	elseif self.onFieldState == self.states.ALIGN_TO_TRACTOR then
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_FOLLOWING_TRACTOR");

		if self:tractorIsReversing() then
			self:hold()
		end

		--if we are in range , change to follow mode
		local sx,sy,sz = getWorldTranslation(self.vehicle.rootNode)
		local dx,dy,dz = worldToLocal(self.tractorToFollow.rootNode,sx,sy,sz)
		if math.abs(dx)< 2 and dz > -40 and dz < 0 then
			self:setNewOnFieldState(self.states.FOLLOW_TRACTOR)
		end

		--use trafficController
		if not self:trafficControlOK() then
			local blockingVehicle = g_currentMission.nodeToObject[g_trafficController:getBlockingVehicleId(self.vehicle.rootNode)]
			if blockingVehicle and blockingVehicle ~= self.tractorToFollow  then
				g_trafficController:solve(self.vehicle.rootNode)
				self:hold()
			end
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

	elseif self.onFieldState == self.states.UNLOADING_MOVING_COMBINE then

		self.forwardLookingProximitySensorPack:disableSpeedControl()

		self:unloadMovingCombine(dt)

	elseif self.onFieldState == self.states.FOLLOW_CHOPPER then

		self:followChopper()

	elseif self.onFieldState == self.states.FOLLOW_TRACTOR then
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_FOLLOWING_TRACTOR");

		-- if the tractor is nearly full, pull over to take over the pipe
		if self:getTractorsFillLevelPercent() > 90 and self:getChopperOffset(self.combineToUnload) ~= 0 then
			self:setNewOnFieldState(self.states.DRIVE_BESIDE_TRACTOR)
		end

		--if  I'm the first Unloader switch to follow chopper
		if g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) == 1 then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
		end

		--self:setSavedCombineOffset(self.tractorToFollow.cp.combineOffset)
		--if chopper is turning , wait till turn is done
		if self:getCombineIsTurning() then
			self:hold()
		elseif not self.allowedToDrive then
			--reset because AIDriver:resetSpeed() is not called here
			self:resetSpeed()
		end

		--if the tractor is reversing, drive backwards
		if self:tractorIsReversing() then
			local reverseCourse = self:getStraightReverseCourse()
			AIDriver.startCourse(self,reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_BACK_FROM_REVERSING_TRACTOR )
		end

		self:driveBehindTractor(dt)
		return

	elseif self.onFieldState == self.states.DRIVE_BESIDE_TRACTOR then
		if g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) == 1 then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
		end

		if self:getCombineIsTurning() then
			self:hold()
		end

		self:driveBesideTractor(dt)
		return

	elseif self.onFieldState == self.states.HANDLE_CHOPPER_HEADLAND_TURN then

		self:handleChopperHeadlandTurn()

	elseif self.onFieldState == self.states.HANDLE_CHOPPER_180_TURN then

		self:handleChopper180Turn()

	elseif self.onFieldState == self.states.ALIGN_TO_CHOPPER_AFTER_TURN then

		self:alignToChopperAfterTurn()

	elseif self.onFieldState == self.states.FOLLOW_CHOPPER_THROUGH_TURN then

		self:followChopperThroughTurn()

	elseif self.onFieldState == self.states.DRIVE_TO_UNLOAD_COURSE then

		--use trafficController
		if not self:trafficControlOK() then
			-- TODO: don't solve anything for now, just wait
			--g_trafficController:solve(self.vehicle.rootNode)
			self:debugSparse('holding due to traffic')
			self:hold()
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

		-- try not crashing into our combine on the way to the unload course
		if self.combineJustUnloaded and self:isWithinSafeManeuveringDistance(self.combineJustUnloaded)
				 and self.combineJustUnloaded.cp.driver:isManeuvering() then
			self:debugSparse('holding combine %s while leaving for the unload course', self.combineJustUnloaded:getName())
			self.combineJustUnloaded.cp.driver:hold()
		end

	elseif self.onFieldState == self.states.DRIVE_BACK_FULL then
		local _, dx, dz = self:getDistanceFromCombine()
		-- drive back way further if we are behind a chopper to have room
		local dDriveBack = dx < 3 and 0.75 * self.vehicle.cp.turnDiameter or 0
		if dz > dDriveBack then
			self:releaseUnloader()
			self:startUnloadCourse()
		else
			self:holdCombine()
		end
		if self:getImFirstOfTwoUnloaders() and self:getChopperOffset(self.combineToUnload) ~= 0 then
			if not self:getCombineIsTurning() then
				if not self.combineToUnload.cp.driver:isStopped() then
					self:hold()
				end
			else
				self:holdCombine()
			end
		end

	elseif self.onFieldState == self.states.DRIVE_BACK_FROM_EMPTY_COMBINE then
		-- drive back until the combine is in front of us
		local _, _, dz = self:getDistanceFromCombine()
		if dz > 0 then
			self:releaseUnloader()
			self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
		else
			self:holdCombine()
		end

	elseif self.onFieldState == self.states.DRIVE_BACK_FROM_REVERSING_CHOPPER then
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

	elseif self.onFieldState == self.states.DRIVE_BACK_FROM_REVERSING_TRACTOR then
		if not self:tractorIsReversing() then
			self:setNewOnFieldState(self.states.FOLLOW_TRACTOR)
		end
	end
	AIDriver.drive(self, dt)
end

function CombineUnloadAIDriver:getTractorsFillLevelPercent()
	return self.tractorToFollow.cp.totalFillLevelPercent
end

function CombineUnloadAIDriver:getFillLevelPercent()
	return self.vehicle.cp.totalFillLevelPercent
end

function CombineUnloadAIDriver:holdCombine()
	self:debugSparse('Holding combine.')
	self.combineToUnload.cp.driver:hold()
end

function CombineUnloadAIDriver:getRecordedSpeed()
	-- default is the street speed (reduced in corners)
	if self.state == self.states.ON_STREET then
		local speed = self:getDefaultStreetSpeed(self.ppc:getCurrentWaypointIx()) or self.vehicle.cp.speeds.street
		if self.vehicle.cp.speeds.useRecordingSpeed then
			-- use default street speed if there's no recorded speed.
			speed = math.min(self.course:getAverageSpeed(self.ppc:getCurrentWaypointIx(), 4) or speed, speed)
		end
		--course end
		if self.ppc:getCurrentWaypointIx()+3 >= self.course:getNumberOfWaypoints() then
			speed= self.vehicle.cp.speeds.approach
		end
		return speed
	else
		return self.vehicle.cp.speeds.field
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
	self:renderText(0, 0.02, "%s: driveBesideCombine: dz = %.1f, speed = %.1f, factor = %.1f",
			nameNum(self.vehicle), dz, speed, factor)
	DebugUtil.drawDebugNode(targetNode, 'target')
	self:setSpeed(math.max(0, speed))
end


function CombineUnloadAIDriver:driveBesideChopper()
	local targetNode = self:getTrailersTargetNode()
	self:renderText(0, 0.02,"%s: driveBesideChopper:offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	self:releaseAutoAimNode()
	local _, _, dz = localToLocal(targetNode, self:getCombineRootNode(), 0, 0, 5)
	renderText(0.2,0.325,0.02,string.format("dz: %.1f", dz))
	self:setSpeed(math.max(0, (self.combineToUnload.lastSpeedReal * 3600) + (MathUtil.clamp(-dz, -10, 15))))
end


function CombineUnloadAIDriver:driveBehindChopper()
	self:renderText(0, 0.05, "%s: driveBehindChopper offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	self:fixAutoAimNode()
	--get required Speed
	self:setSpeed(self:getSpeedBehindChopper())
end

function CombineUnloadAIDriver:driveBehindTractor(dt)

	local allowedToDrive = true
	local fwd = true
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBehindTractor(self.tractorToFollow)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, gx,gy,gz);
	--get required Speed
	local speed = self:getSpeedBehindTractor(self.tractorToFollow)
	if not courseplay:isField(gx, gz) then
		allowedToDrive = false
	end
	allowedToDrive = allowedToDrive and self.allowedToDrive
	self:renderText(0, 0.05, "%s: driveBehindTractor distance: %.2f",nameNum(self.vehicle),courseplay:distanceToObject(self.vehicle, self.tractorToFollow))
	self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function CombineUnloadAIDriver:driveBesideTractor(dt)

	local allowedToDrive = true
	local speed = 0
	local fwd = true
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBesideTractor(self.tractorToFollow)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, gx,gy,gz);
	--get required Speed
	local targetNode = self:getTrailersTargetNode()
	speed, allowedToDrive = self:getSpeedBesideChopper(targetNode)
	allowedToDrive = allowedToDrive and self.allowedToDrive
	self:renderText(0, 0.05, "driveBesideTractor distance: %.2f",courseplay:distanceToObject(self.vehicle, self.tractorToFollow))
	self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function CombineUnloadAIDriver:onEndCourse()
	if self.state == self.states.ON_STREET then
		self:setNewState(self.states.ON_FIELD)
		self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
		self:setDriveUnloadNow(false)
		courseplay:openCloseCover(self.vehicle, courseplay.OPEN_COVERS)
		self:disableCollisionDetection()
	end
end

function CombineUnloadAIDriver:onLastWaypoint()
	if self.state == self.states.ON_FIELD then
		if self.onFieldState == self.states.DRIVE_TO_UNLOAD_COURSE then
			self:setNewState(self.states.ON_STREET)
			self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
			self:enableCollisionDetection()
			courseplay:openCloseCover(self.vehicle, courseplay.CLOSE_COVERS)
			AIDriver.onLastWaypoint(self)
			g_trafficController:cancel(self.vehicle.rootNode)
			return
		elseif self.onFieldState == self.states.ALIGN_TO_TRACTOR then
			self:setNewOnFieldState(self.states.FOLLOW_TRACTOR)
			g_trafficController:cancel(self.vehicle.rootNode)
		elseif self.onFieldState == self.states.DRIVE_TO_COMBINE or
			self.onFieldState == self.states.DRIVE_TO_MOVING_COMBINE then
			g_trafficController:cancel(self.vehicle.rootNode)
			self:startWorking()
		elseif self.onFieldState == self.states.MOVING_OUT_OF_WAY then
			self:setNewOnFieldState(self.stateAfterMovedOutOfWay)
		end
	end
	AIDriver.onLastWaypoint(self)
end

function CombineUnloadAIDriver:setFieldSpeed()
	if self.course then
		-- slow down a bit towards the end of the course.
		if self.course:getNumberOfWaypoints() - self.course:getCurrentWaypointIx() < 10 then
			self:setSpeed(self.vehicle.cp.speeds.field / 2)
		else
			self:setSpeed(self.vehicle.cp.speeds.field)
		end
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

function CombineUnloadAIDriver:getStraightReverseCourse(length)
	local waypoints = {}
	local l = length or 100
	for i=0, -l, -5 do
		local x, y, z = localToWorld(self.trailerToFill.rootNode, 0, 0, i)
		table.insert(waypoints, {x = x, y = y, z = z, rev = true})
	end
	return Course(self.vehicle, waypoints, true)
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
					self.trailerToFill = tipper
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

function CombineUnloadAIDriver:getDrivingCoordsBeside()
	-- TODO: use localToLocal
	-- target position 5 m in front of the tractor
	local tx, ty, tz = localToWorld(AIDriverUtil.getDirectionNode(self.vehicle), 0, 0, 5)
	-- tractor's local position in the combine's coordinate system
	local sideShift, _, backShift = worldToLocal(self.combineToUnload.cp.directionNode, tx, ty, tz)
	local backDistance = self:getCombinesMeasuredBackDistance() + 3
	-- unit vector from the combine to the target
	local origLx, origLz = AIVehicleUtil.getDriveDirection(self.combineToUnload.cp.directionNode, tx, ty, tz)
	local lx, lz = origLx, origLz
	local isBeside = false
	if self.combineOffset > 0 then
		-- pipe on the right
		lx = math.max(0.25, lx)
		--if I'm on the wrong side, drive to combines back first
		if backShift > 0 and sideShift < 0 then
			-- front of the combine or on the left
			lx = 0
			lz= -1
		end
	else
		lx = math.min(-0.25, lx)
		--if I'm on the wrong side, drive to combines back first
		if backShift > 0 and sideShift > 0 then
			-- front of the combine or on the right
			lx = 0
			lz= -1
		end
	end
	-- no idea how are we calculating this, especially the backDistance part does not seem to make sense with lx
	local rayLength = (math.abs(self.combineOffset)*math.abs(lx)) + (backDistance - (backDistance * math.abs(lx)))
	-- this is waaay too complicated, why not just use
	local nx, _, nz = localDirectionToWorld(self.combineToUnload.cp.directionNode, lx, 0, lz)
	local cx, cy, cz = getWorldTranslation(self.combineToUnload.cp.directionNode)
	local x, y, z = cx + (nx * rayLength), cy, cz + (nz * rayLength)
	local offsetDifference = self.combineOffset - sideShift
	--self:debug('lz %.1f, lx %.1f, raylength %.1f, backdistance %.1f, sideshift %.1f, backsift %.1f', lz, lx, rayLength, backDistance, sideShift , backShift)
	local distanceToTarget = courseplay:distance(tx, tz, x, z)
	--we are on the correct side but not close to the target point, so got directly to the offsetTarget
	if self.combineOffset > 0 then
		if origLx > 0 then
			--print("distanceToTarget: "..tostring(distanceToTarget))
			isBeside = distanceToTarget > 4
		end
	else
		if origLx < 0 then
			--print("distanceToTarget: "..tostring(distanceToTarget))
			isBeside = distanceToTarget > 4
		end
	end

	isBeside = isBeside or math.abs(offsetDifference) < 0.5
	if lz > 0 or isBeside then
		x, y, z = localToWorld(self.combineToUnload.cp.directionNode, self.combineOffset, 0, backShift)
		cpDebug:drawLine(cx, cy + 1, cz, 1, 0, 0, x, y + 1, z)
	else
		cpDebug:drawLine(cx, cy + 1, cz, 0, 1, 0, x, y + 1, z)
	end
	return x, y, z, isBeside
end

function CombineUnloadAIDriver:getDrivingCoordsBehind()

	local tx,ty,tz = localToWorld(self:getDirectionNode(),0,0,5)
	local sideShift,_,backShift = worldToLocal(self.combineToUnload.cp.directionNode,tx,ty,tz)
	local x,y,z = 0,0,0
	local sx,sy,sz = getWorldTranslation(self:getDirectionNode())
	local _,_,backShiftNode = worldToLocal(self.combineToUnload.cp.directionNode,sx,sy,sz)
	if backShiftNode > -self:getCombinesMeasuredBackDistance() then
		local lx,lz = AIVehicleUtil.getDriveDirection(self.combineToUnload.cp.directionNode, tx,ty,tz);
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.cp.directionNode)
		local fixOffset = g_combineUnloadManager:getCombinesPipeOffset(self.combineToUnload)
		if sideShift > 0 then
			x,y,z = localToWorld(self.combineToUnload.cp.directionNode,fixOffset,0,backShift)
		else
			x,y,z = localToWorld(self.combineToUnload.cp.directionNode,-fixOffset,0,backShift)
		end
		cpDebug:drawLine(cx,cy+1,cz, 100, 100, 100, x,cy+1,z)
	else
		x,y,z = localToWorld(self.combineToUnload.cp.directionNode,0,0, - (self:getCombinesMeasuredBackDistance()))
	end

	--just Debug
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local sx,sy,sz = getWorldTranslation(colliNode)
	cpDebug:drawLine(sx,sy,sz, 100, 100, 100, x,sy,z)
	--

	return x,y,z
end

function CombineUnloadAIDriver:getDrivingCoordsBehindTractor(tractorToFollow)
	local sx,sy,sz = localToWorld(self:getDirectionNode(),0,0,5)
	local sideShift,_,backShift = worldToLocal(tractorToFollow.cp.directionNode,sx,sy,sz)
	local tx,ty,tz = localToWorld(tractorToFollow.cp.directionNode,0,0,math.max(-30,backShift))
	return tx,ty,tz
end

function CombineUnloadAIDriver:getDrivingCoordsBesideTractor(tractorToFollow)
	local offset = self:getChopperOffset(self.combineToUnload)
	local sx,sy,sz = localToWorld(self:getDirectionNode(),0,0,5)
	local sideShift,_,backShift = worldToLocal(tractorToFollow.cp.directionNode,sx,sy,sz)
	local newX = 0
	if offset < 0 then
		newX = - 4.5
	else
		newX = 4.5
	end
	local tx,ty,tz = localToWorld(tractorToFollow.cp.directionNode,newX,0,math.max(-20,backShift))
	cpDebug:drawLine(sx,sy+1,sz, 100, 100, 100, tx,ty+1,tz)
	return tx,ty,tz
end

function CombineUnloadAIDriver:getZOffsetToCoordsBehind()
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local sx,sy,sz = getWorldTranslation(colliNode)
	local _,_,z = worldToLocal(self.combineToUnload.cp.directionNode,sx,sy,sz)
	return -(z + self:getCombinesMeasuredBackDistance())
end

function CombineUnloadAIDriver:getSpeedBesideChopper(targetNode)
	local allowedToDrive = true
	local baseNode = self:getPipesBaseNode(self.combineToUnload)
	local bnX, bnY, bnZ = getWorldTranslation(baseNode)
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
	renderText(0.2,0.225,0.02,string.format("dz:%s",tostring(dz)))
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
	--renderText(0.2,0.195,0.02,string.format("self.distanceToCombine:%s, targetDistance:%s speed:%s",tostring(self.distanceToCombine),tostring(targetDistance),tostring((self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15)))))
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15))
end

function CombineUnloadAIDriver:getSpeedBehindChopper()
	local distanceToChoppersBack, _, dz = self:getDistanceFromCombine()
	local fwdDistance = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
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

	local rightDistance = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle(-90)
	local fwdRightDistance = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle(-45)
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
	return self.state == self.states.ON_FIELD
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
	return self.vehicle.cp.followAtFillLevel
end

function CombineUnloadAIDriver:getDriveOnThreshold()
	return self.vehicle.cp.driveOnAtFillLevel
end

function CombineUnloadAIDriver:releaseUnloader()
	g_combineUnloadManager:releaseUnloaderFromCombine(self.vehicle, self.combineToUnload)
	-- TODO: may not have to release the unloader at this point at all so no need to remember
	self.combineJustUnloaded = self.combineToUnload
	self.combineToUnload = nil
	self:refreshHUD()
end

function CombineUnloadAIDriver:getImSecondUnloader()
	return g_combineUnloadManager:getNumUnloaders(self.combineToUnload)==2 and g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) ==2
end

function CombineUnloadAIDriver:getImFirstOfTwoUnloaders()
	return g_combineUnloadManager:getNumUnloaders(self.combineToUnload)==2 and g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) ==1
end

function CombineUnloadAIDriver:tractorIsReversing()
	return self.tractorToFollow.movingDirection == -1 and self.tractorToFollow.lastSpeedReal*3600 > 1

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

---@param goalWaypoint Waypoint The destination waypoint (x, z, angle)
---@param zOffset number length offset of the goal from the goalWaypoint
---@param allowReverse boolean allow reverse driving
---@param course Course course to start after pathfinding is done, can be nil
---@param ix number course to start at after pathfinding, can be nil
---@param fieldNum number if > 0, the pathfinding is restricted to the given field and its vicinity. Otherwise the
--- pathfinding considers any collision-free path valid, also outside of the field.
---@return boolean true when a pathfinding successfully started
function CombineUnloadAIDriver:driveToNodeWithPathfinding(node, xOffset, zOffset, fieldNum, targetVehicle)
	if not self.pathfinder or not self.pathfinder:isActive() then
		self.courseAfterPathfinding = nil
		self.waypointIxAfterPathfinding = nil
		local done, path
		self.pathfindingStartedAt = self.vehicle.timer
		self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(
				self.vehicle, node, xOffset or 0, zOffset or 0, self.allowReversePathfinding, fieldNum, {targetVehicle})
		if done then
			return self:onPathfindingDone(path)
		else
			self:setPathfindingDoneCallback(self, self.onPathfindingDone)
			return true
		end

	else
		self:debug('Pathfinder already active')
	end
	return false
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
	if dz >= 0 and math.abs(dx) < math.abs(pipeOffset) * 1.1 and math.abs(dx) > math.abs(pipeOffset) * 0.9 and
			MathUtil.vector2Length(dx, dz) < 30 and
			TurnContext.isSameDirection(AIDriverUtil.getDirectionNode(self.vehicle), AIDriverUtil.getDirectionNode(self.combineToUnload),
					maxDirectionDifferenceDeg or 15) and
			not self.combineToUnload.cp.driver:willWaitForUnloadToFinish() then
		return true
	else
		return false
	end
end

function CombineUnloadAIDriver:isOkToStartFollowingChopper()
	return self.combineToUnload.cp.driver:isChopper() and self:isBehindAndAlignedToChopper()
end

function CombineUnloadAIDriver:isOkToStartUnloadingCombine()
	if self.combineToUnload.cp.driver:isChopper() then return false end
	if self.combineToUnload.cp.driver:isReadyToUnload() then
		return self:isBehindAndAlignedToCombine() or self:isInFrontAndAlignedToMovingCombine()
	else
		self:debugSparse('combine not ready to unload, waiting')
		return false
	end
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
	courseplay:openCloseCover(self.vehicle, courseplay.CLOSE_COVERS)
end

------------------------------------------------------------------------------------------------------------------------
-- Start to unload the combine (driving to the pipe/closer to combine)
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startUnloadingCombine()
	g_trafficController:cancel(self.vehicle.rootNode)
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

function CombineUnloadAIDriver:setupFollowCourse()
	---@type Course
	self.combineCourse = self.combineToUnload.cp.driver:getFieldworkCourse()
	if not self.combineCourse then
		-- TODO: handle this more gracefully, or even better, don't even allow selecting combines with no course
		self:debugSparse('Waiting for combine to set up a course, can\'t follow')
		return
	end
	local followCourse = self.combineCourse:copy(self.vehicle)
	local followCourseIx = self.combineCourse:getCurrentWaypointIx()
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

function CombineUnloadAIDriver:isPathFound(path)
	if path and #path > 2 then
		self:debug('Found path (%d waypoints, %d ms)', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0))
		return true
	else
		self:error('No path found to %s in %d ms', self.combineToUnload and self.combineToUnload:getName() or 'N/A',
				self.vehicle.timer - (self.pathfindingStartedAt or 0))
		return false
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
	self:debug('Start finding path to chopper')
	self:startPathfindingToCombine(self.onPathfindingDoneToCombine, nil, -15)
end

------------------------------------------------------------------------------------------------------------------------
--Start driving to combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startDrivingToCombine()
	if self.combineToUnload.cp.driver:isWaitingForUnload() then
		self:debug('Combine is waiting for unload, start finding path to combine')
		self:startPathfindingToCombine(self.onPathfindingDoneToCombine, nil, -15)
	else
		-- combine is moving, agree on a rendezvous
		-- for now, just use the Eucledian distance. This should rather be the length of a pathfinder generated
		-- path, using the simple A* should be good enough for estimation, the hybrid A* would be too slow
		local d = self:getDistanceFromCombine()
		local estimatedSecondsEnroute = d / (self:getFieldSpeed() / 3.6) + 3 -- add a few seconds to allow for starting the engine/accelerating
		local rendezvousWaypoint, rendezvousWaypointIx = self.combineToUnload.cp.driver:getUnloaderRendezvousWaypoint(estimatedSecondsEnroute)
		local xOffset = self:getPipeOffset(self.combineToUnload)
		local zOffset = -15
		if rendezvousWaypoint and self:isPathfindingNeeded(self.vehicle, rendezvousWaypoint, xOffset, zOffset) then
			self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)
			self:debug('Start pathfinding to moving combine, %d m, ETE: %d s, meet combine at waypoint %d, xOffset = %.1f, zOffset = %.1f',
					d, estimatedSecondsEnroute, rendezvousWaypointIx, xOffset, zOffset)
			self:startPathfinding(rendezvousWaypoint, xOffset, zOffset, 0,
					self.combineToUnload, self.onPathfindingDoneToMovingCombine)
		else
			self:debug('can\'t find rendezvous waypoint to combine, waiting')
			self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
		end
	end
end

function CombineUnloadAIDriver:onPathfindingDoneToMovingCombine(path)
	if self:isPathFound(path) and self.onFieldState == self.states.WAITING_FOR_PATHFINDER then
		local driveToCombineCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToCombineCourse, 1)
		self:setNewOnFieldState(self.states.DRIVE_TO_MOVING_COMBINE)
		return true
	else
		self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
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
		self:startPathfinding(self:getCombineRootNode(), xOffset, zOffset, 0, nil, onPathfindingDoneFunc)
	else
		self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
		self:debug('Can\'t start pathfinding, too close?')
	end
end

function CombineUnloadAIDriver:onPathfindingDoneToCombine(path)
	if self:isPathFound(path) and self.onFieldState == self.states.WAITING_FOR_PATHFINDER then
		local driveToCombineCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToCombineCourse, 1)
		self:setNewOnFieldState(self.states.DRIVE_TO_COMBINE)
		return true
	else
		self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
		return false
	end
end

------------------------------------------------------------------------------------------------------------------------
--Pathfinding for wide turns
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startPathfindingToTurnEnd(xOffset, zOffset)
	self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)

	if not self.pathfinder or not self.pathfinder:isActive() then
		local done, path
		self.pathfindingStartedAt = self.vehicle.timer
		local turnEndNode, startOffset, goalOffset = self.turnContext:getTurnEndNodeAndOffsets()
		-- ignore combine for pathfinding, it is moving anyway and our turn functions make sure we won't hit it
		self.pathfinder, done, path = PathfinderUtil.findPathForTurn(self.vehicle, startOffset, turnEndNode, goalOffset,
				self.vehicle.cp.turnDiameter / 2, self:getAllowReversePathfinding(), self.followCourse, {self.combineToUnload})
		if done then
			return self:onPathfindingDoneToTurnEnd(path)
		else
			self:setPathfindingDoneCallback(self, self.onPathfindingDoneToTurnEnd)
			return true
		end
	else
		self:debug('Pathfinder already active')
	end
	return false
end

function CombineUnloadAIDriver:onPathfindingDoneToTurnEnd(path)
	if self:isPathFound(path) then
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
-- This should avoid generating a big circle path to a point a few meters ahead
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:isPathfindingNeeded(vehicle, target, xOffset, zOffset)
	local targetNode = self:getTargetNode(target)
	if not targetNode then return false end
	local startNode = AIDriverUtil.getDirectionNode(vehicle)
	local dx, _, dz = localToLocal(targetNode, startNode, xOffset, 0, zOffset)
	local d = MathUtil.vector2Length(dx, dz)
	local sameDirection = TurnContext.isSameDirection(startNode, targetNode, 30)
	if d < self.pathfindingRange and sameDirection then
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
		target, xOffset, zOffset, fieldNum, vehicleToIgnore,
		pathfindingCallbackFunc)
	if not self.pathfinder or not self.pathfinder:isActive() then

		local maxFruitPercent = 10
		if self:isFruitAt(target, xOffset, zOffset) then
			self:info('There is fruit at the target, disabling fruit avoidance')
			maxFruitPercent = math.huge
		end

		local done, path
		self.pathfindingStartedAt = self.vehicle.timer

		if type(target) ~= 'number' then
			-- TODO: clarify this xOffset thing, it looks like the course interprets the xOffset differently (left < 0) than
			-- the Giants coordinate system and the waypoint uses the course's conventions. This is confusing, should use
			-- the same reference everywhere
			self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
					self.vehicle, target, -xOffset or 0, zOffset or 0, self.allowReversePathfinding,
					fieldNum, { vehicleToIgnore }, self.vehicle.cp.realisticDriving and 10 or math.huge)
		else
			self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(
					self.vehicle, target, xOffset or 0, zOffset or 0, self.allowReversePathfinding,
					fieldNum, { vehicleToIgnore }, self.vehicle.cp.realisticDriving and 10 or math.huge)
		end
		if done then
			return pathfindingCallbackFunc(self, path)
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
function CombineUnloadAIDriver:getDistanceFromCombine()
	local dx, _, dz = localToLocal(self:getBackMarkerNode(self.combineToUnload), self:getFrontMarkerNode(self.vehicle), 0, 0, 0)
	return MathUtil.vector2Length(dx, dz), dx, dz
end

------------------------------------------------------------------------------------------------------------------------
-- Can drive beside combine?
-- Other code will take care of using the correct offset, all we want to know here is
-- if we can drive under the pipe, regardless of which side it is on
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:canDriveBesideCombine(combine)
	-- no fruit avoidance, don't care
	if not self.vehicle.cp.realisticDriving then return true end
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
		local reverseCourse = self:getStraightReverseCourse()
		self:startCourse(reverseCourse, 1)
		self:setNewOnFieldState(self.states.DRIVE_BACK_FULL)
	end
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
		self:releaseUnloader()
		self:startUnloadCourse()
		return true
	end
	return false
end

------------------------------------------------------------------------------------------------------------------------
-- Drive to moving combine
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:driveToMovingCombine()
	self.forwardLookingProximitySensorPack:enableSpeedControl()

	courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_TO_COMBINE");

	self:setFieldSpeed()

	-- don't use trafficController, the maneuvering stuff will keep us away from the combine (as long there are
	-- no other vehicles around)
--	if not self:trafficControlOK() then
--		self:debugSparse('Traffic conflict, stop.')
--		self:hold()
--	end

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
				local reverseCourse = self:getStraightReverseCourse()
				self:startCourse(reverseCourse, 1)
				self.ppc:setNormalLookaheadDistance()
				self:setNewOnFieldState(self.states.DRIVE_BACK_FULL)
			else
				self:driveBesideCombine()
			end
		else
			self:debug('finished unloading stopped combine, move back a bit to make room for it to continue')
			local reverseCourse = self:getStraightReverseCourse()
			self:startCourse(reverseCourse,1)
			self.ppc:setNormalLookaheadDistance()
			self:setNewOnFieldState(self.states.DRIVE_BACK_FROM_EMPTY_COMBINE)
		end
	else
		self:driveBesideCombine()
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Unload combine (moving)
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:unloadMovingCombine()

	-- TODO: handle pipe on the left side
	-- disable looking to the right so the proximity sensor won't slow us down while driving beside the combine
	self.forwardLookingProximitySensorPack:disableRightSide()

	-- allow on the fly offset changes
	self.combineOffset = self:getPipeOffset(self.combineToUnload)
	self.followCourse:setOffset(-self.combineOffset, 0)

	if self:changeToUnloadWhenFull() then return end

	if self:canDriveBesideCombine(self.combineToUnload) or (self.combineToUnload.cp.driver and self.combineToUnload.cp.driver:isWaitingInPocket()) then
		self:driveBesideCombine()
	else
		self:debug('Can\'t drive beside combine, releasing it.')
		self:releaseUnloader()
		self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
		return
	end

	--when the combine is empty, stop and wait for next combine
	if self:getCombinesFillLevelPercent() <= 0.1 then
		--when the combine is in a pocket, make room to get back to course
		if self.combineToUnload.cp.driver and self.combineToUnload.cp.driver:isWaitingInPocket() then
			self:debug('combine empty and in pocket, drive back')
			local reverseCourse = self:getStraightReverseCourse()
			AIDriver.startCourse(self, reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_BACK_FROM_EMPTY_COMBINE)
			return
		else
			self:debug('combine empty and moving forward')
			self:releaseUnloader()
			self:setNewOnFieldState(self.states.WAITING_FOR_COMBINE_TO_CALL)
			return
		end
	end

	-- don't move until ready to unload
	if not self.combineToUnload.cp.driver:isReadyToUnload() then
		self:setSpeed(0)
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
	elseif not self:isOkToStartUnloadingCombine() then
		self:debug('not in a good position to unload, trying to recover')
		-- switch to driving only when not holding for maneuvering combine
		-- for some reason (like combine turned) we are not in a good position anymore then set us up again
		self:startDrivingToCombine()
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turns
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:startChopperTurn(ix)
	if self.combineToUnload.cp.driver:isTurningOnHeadland() then
		self:setNewOnFieldState(self.states.HANDLE_CHOPPER_HEADLAND_TURN)
	else
		self.turnContext = TurnContext(self.followCourse, ix, self.aiDriverData,
				self.combineToUnload.cp.workWidth, self.frontMarkerDistance, 0)
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
	self.forwardLookingProximitySensorPack:disableSpeedControl()

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
		self:setNewOnFieldState(self.states.DRIVE_BACK_FROM_REVERSING_CHOPPER )
	end

	self:changeToUnloadWhenDriveOnLevelReached()

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
		local reverseCourse = self:getStraightReverseCourse()
		self:startCourse(reverseCourse,1)
		self:setNewOnFieldState(self.states.DRIVE_BACK_FULL)
		return
	end

	if self.course:isTemporary() and self.course:getDistanceToLastWaypoint(self.course:getCurrentWaypointIx()) > 5 then
		-- have not started on the combine's fieldwork course yet (still on the temporary alignment course)
		-- just drive the course
		self.forwardLookingProximitySensorPack:enableSpeedControl()
	else
		-- we'll take care of controlling our speed, don't need ADriver for that
		self.forwardLookingProximitySensorPack:disableSpeedControl()
		-- when on the fieldwork course, drive behind or beside the chopper, staying in the range of the pipe
		self.combineOffset = self:getChopperOffset(self.combineToUnload)
		self.followCourse:setOffset(-self.combineOffset, 0)

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

	self:changeToUnloadWhenDriveOnLevelReached()

	self.forwardLookingProximitySensorPack:enableSpeedControl()

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

	self.forwardLookingProximitySensorPack:enableSpeedControl()

	self:changeToUnloadWhenDriveOnLevelReached()

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

	self.forwardLookingProximitySensorPack:enableSpeedControl()

	self:setSpeed(self.vehicle.cp.speeds.turn)

	if self:isBehindAndAlignedToChopper(45) then
		self:debug('Now aligned with chopper, continue on the side/behind')
		self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Combine Event Listeners
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:onCombineTurnStart(ix, turnType)
	if self.state == self.states.ON_FIELD then
		if self.onFieldState == self.states.FOLLOW_CHOPPER then
			self:debug('chopper reached turn waypoint %d, start chopper turn', ix)
			--self:startChopperTurn(ix, turnType)
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- We are blocking another vehicle who wants us to move out of way
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:onBlockingOtherVehicle(blockedVehicle)
	self:debug('%s wants me to move out of way', blockedVehicle:getName())
	if blockedVehicle.cp.driver:isChopper() then
		-- TODO: think about how to best handle choppers, since they always stop when no trailer
		-- is in range they always send these blocking events.
		return
	end
	if self.onFieldState ~= self.states.MOVING_OUT_OF_WAY and
			self.onFieldState ~= self.states.DRIVE_BACK_FROM_REVERSING_CHOPPER and
			self.onFieldState ~= self.states.DRIVE_BACK_FROM_EMPTY_COMBINE and
			self.onFieldState ~= self.states.HANDLE_CHOPPER_HEADLAND_TURN and
			self.onFieldState ~= self.states.HANDLE_CHOPPER_180_TURN and
			self.onFieldState ~= self.states.DRIVE_BACK_FULL
	then
		-- reverse back a bit, this usually solves the problem
		-- TODO: there may be better strategies depending on the situation
		local reverseCourse = self:getStraightReverseCourse(10)
		self:startCourse(reverseCourse, 1, self.course, self.course:getCurrentWaypointIx())
		self.stateAfterMovedOutOfWay = self.onFieldState
		self:setNewOnFieldState(self.states.MOVING_OUT_OF_WAY)
	else
		self:debug('Already busy moving out of the way')
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
