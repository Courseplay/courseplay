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
]]
---@class CombineUnloadAIDriver : AIDriver
CombineUnloadAIDriver = CpObject(AIDriver)

CombineUnloadAIDriver.safetyDistanceFromChopper = 0.75
CombineUnloadAIDriver.targetDistanceBehindChopper = 1
CombineUnloadAIDriver.targetOffsetBehindChopper = 3 -- 3 m to the right
CombineUnloadAIDriver.targetDistanceBehindReversingChopper = 2
CombineUnloadAIDriver.minDistanceFromReversingChopper = 10
CombineUnloadAIDriver.minDistanceFromWideTurnChopper = 5

CombineUnloadAIDriver.myStates = {
	ONFIELD = {},
	ONSTREET = {},
	FIND_COMBINE ={},
	WAITING_FOR_PATHFINDER={},
	FINDPATH_TO_TRACTOR={},
	DRIVE_TO_COMBINE = {},
	DRIVE_TO_TRACTOR={},
	FINDPATH_TO_COURSE={},
	DRIVE_TO_UNLOADCOURSE ={},
	DRIVE_BESIDE_TRACTOR ={},
	ALIGN_TO_TRACTOR = {},
	GET_ALIGNCOURSE_TO_TRACTOR ={},
	FOLLOW_COMBINE ={},
	FOLLOW_CHOPPER ={},
	FOLLOW_TRACTOR = {},
	PREPARE_TURN ={},
	DRIVE_TURN ={},
	DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE = {},
	DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER ={},
	DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE_NOTURN = {},
	DRIVE_STRAIGHTBACK_FROM_EMPTY_COMBINE = {},
	DRIVE_STRAIGHTBACK_FROM_REVERSING_TRACTOR = {},
	DRIVE_STRAIGHTBACK_FROM_TURNINGCOMBINE = {},
	DRIVE_STRAIGHTBACK_FROM_TURNINGCHOPPER = {},
	DRIVE_STRAIGHTBACK_FULL ={},
	HANDLE_COMBINE_TURN ={},
	HANDLE_CHOPPER_HEADLAND_TURN = {},
	HANDLE_CHOPPER_180_TURN = {},
	HANDLE_CHOPPER_WIDE_TURN = {},
	WAIT_FOR_COMBINES_FILLLEVEL = {},
	WAIT_FOR_CHOPPER_TURNED = {}
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

function CombineUnloadAIDriver:start(startingPoint)

	self.myVehicleData = PathfinderUtil.VehicleData(self.vehicle)
	self:beforeStart()
	self:addForwardProximitySensor()
	-- we'll take care of controlling our speed, don't need ADriver for that
	self.forwardLookingProximitySensorPack:disableSpeedControl()

	self.state = self.states.RUNNING

	self.unloadCourse = Course(self.vehicle, self.vehicle.Waypoints)
	-- just to have a course set up in any case for PPC to work with until we find a combine/path
	self:startCourse(self.unloadCourse, 1)

	local combineToWaitFor
	self.combineToUnload, combineToWaitFor = g_combineUnloadManager:giveMeACombineToUnload(self.vehicle)
	local dCombine = self.combineToUnload and courseplay:distanceToObject(self.vehicle, self.combineToUnload) or math.huge
	dCombine = math.min(dCombine, combineToWaitFor and courseplay:distanceToObject(self.vehicle, combineToWaitFor) or math.huge)

	local _, dClosest, _, _ = self.unloadCourse:getNearestWaypoints(AIDriverUtil.getDirectionNode(self.vehicle))
	self:debug('Closest combine to unload at %d m, closest unload course waypoint at %d m', dCombine, dClosest)

	local x,_,z = getWorldTranslation(self:getDirectionNode())
	if dCombine < dClosest or courseplay:isField(x, z) then
		self:debug('on the field or closer to a combine than to the unload course, go to field mode')
		if self.combineToUnload then self:setMyCombine(self.combineToUnload) end
		self:setNewCombineUnloadState(self.states.ONFIELD)
		self:setNewOnFieldState(self.states.FIND_COMBINE)
		self:disableCollisionDetection()
		self:setDriveUnloadNow(false)
	else
		local ix = self.unloadCourse:getStartingWaypointIx(AIDriverUtil.getDirectionNode(self.vehicle), startingPoint)
		self:startCourseWithPathfinding(self.unloadCourse, ix, 0, 0)
		self:setNewCombineUnloadState(self.states.ONSTREET)
		self:setNewOnFieldState(self.states.FIND_COMBINE)
	end
	self.distanceToFront = 0
end

function CombineUnloadAIDriver:dismiss()
	local x,_,z = getWorldTranslation(self:getDirectionNode())
	if self.combineToUnload then
		self.combineToUnload.cp.driver:deregisterUnloader(self)
		self:releaseUnloader()
	end
	if courseplay:isField(x, z) then
		self:setNewCombineUnloadState(self.states.ONFIELD)
		self:setNewOnFieldState(self.states.FIND_COMBINE)
	end
	AIDriver.dismiss(self)
end

function CombineUnloadAIDriver:drive(dt)
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	self:updateCombineInfo()
	local renderOffset = self.vehicle.cp.coursePlayerNum * 0.03
	self:renderText(0, 0.1 + renderOffset, "%s: self.onFieldState :%s", nameNum(self.vehicle), self.onFieldState.name)

	if self.combineUnloadState == self.states.ONSTREET then
		if not self:onUnLoadCourse(true, dt) then
			self:hold()
		end
		self:searchForTipTriggers()
		AIDriver.drive(self, dt)
	elseif self.combineUnloadState == self.states.ONFIELD then
		self:driveOnField(dt)
	end
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

	self:calculateRelativeSpeedToCombine(dt)

	-- make sure if we have a combine we stay registered
	if self.combineToUnload then
		self.combineToUnload.cp.driver:registerUnloader(self)
	end

	-- safety check #1: collision
	if self:findCollidingShapes() > 0 then
		self:renderText(0, 0.5, "Collision detected!")
		-- collision detected in the front, don't stop if we are already trying to back up
		if not self:isInReverseGear() and not self.ppc:isReversing() then
			--self:setSpeed(0)
		end
	end

	-- safety check #2: combine has active  AI driver
	if self.combineToUnload and not self.combineToUnload.cp.driver:isActive() then
		self:setSpeed(0)
	end

	if self.combineToUnload and self.combineToUnload.cp.driver.aiDriverData.backMarkerNode then
		DebugUtil.drawDebugNode(self.combineToUnload.cp.driver.aiDriverData.backMarkerNode, 'back marker')
	end

	if self.aiDriverData.frontMarkerNode then
		DebugUtil.drawDebugNode(self.aiDriverData.frontMarkerNode, 'front marker')
	end

	if self.vehicle.cp.forcedToStop then
		self:stopAndWait(dt)
		return
	end
	if self.onFieldState == self.states.FIND_COMBINE then
		local timeTillStartUnloading,combineToWaitFor
		if self:getDriveUnloadNow() or self:getAllTrailersFull() or self:shouldDriveOn() then
			self:debug('Go to unload course')
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			return
		end

		self.combineToUnload, combineToWaitFor, timeTillStartUnloading  = g_combineUnloadManager:giveMeACombineToUnload(self.vehicle)
		if self.combineToUnload ~= nil then
			--print("combine set")
			self:refreshHUD()
			self:setMyCombine(self.combineToUnload)
			self:startPathfindingToCombine()
		else
			if combineToWaitFor then
				courseplay:setInfoText(self.vehicle,string.format("COURSEPLAY_WAITING_FOR_FILL_LEVEL;%s;%d",nameNum(combineToWaitFor),timeTillStartUnloading));
			else
				courseplay:setInfoText(self.vehicle, "COURSEPLAY_NO_COMBINE_IN_REACH");
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
		if not self:trafficContollOK() then
			local blockingVehicle = g_currentMission.nodeToObject[g_trafficController:getBlockingVehicleId(self.vehicle.rootNode)]
			if blockingVehicle and blockingVehicle ~= self.tractorToFollow then
				g_trafficController:solve(self.vehicle.rootNode)
				self:hold()
			end
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

	elseif self.onFieldState == self.states.DRIVE_TO_COMBINE then
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_TO_COMBINE");
		--check whether the combine moved meanwhile
		--if courseplay:distanceToPoint(self.combineToUnload,self.lastCombinesCoords.x,self.lastCombinesCoords.y,self.lastCombinesCoords.z) > 50 then
		--	self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)
		--end
		--if we are in range , change to align mode
		if self:isInGoodPositionToStartFollowing() then
			self:debug('Close enough to combine, copy combine course and follow')
			g_trafficController:cancel(self.vehicle.rootNode)
			self:startFollowingCombine()
		end
		--use trafficController
		if not self:trafficContollOK() then
			local blockingVehicle = g_currentMission.nodeToObject[g_trafficController:getBlockingVehicleId(self.vehicle.rootNode)]
			if blockingVehicle and blockingVehicle ~= self.combineToUnload  and blockingVehicle ~= self.tractorToFollow then
				g_trafficController:solve(self.vehicle.rootNode)
				self:hold()
			end
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

		self.tightTurnOffset = AIDriverUtil.calculateTightTurnOffset(self.vehicle, self.course, self.tightTurnOffset, true)
		self:debug('TIGHT %.1f', self.tightTurnOffset)
		self.course:setOffset((self.tightTurnOffset or 0), 0)

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
		if not self:trafficContollOK() then
			local blockingVehicle = g_currentMission.nodeToObject[g_trafficController:getBlockingVehicleId(self.vehicle.rootNode)]
			if blockingVehicle and blockingVehicle ~= self.tractorToFollow  then
				g_trafficController:solve(self.vehicle.rootNode)
				self:hold()
			end
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

	elseif self.onFieldState == self.states.FOLLOW_COMBINE then
		-- if we have a chopper, switch to follow chopper
		if courseplay:isChopper(self.combineToUnload) then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER )
			return
		end

		--decide where to drive, behind or beside
		local targetNode = self:getTrailersTargetNode()
		local leftOK = g_combineUnloadManager:getPossibleSidesToDrive(self.combineToUnload)

		--when trailer is full then go to unload
		if self:getDriveUnloadNow() or self:getAllTrailersFull() then
			print(nameNum(self.vehicle)..": trailer full, set self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)")
			self:releaseUnloader()
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			return
		end

		if leftOK or self.combineToUnload.cp.driver and self.combineToUnload.cp.driver:isWaitingInPocket() then
			self:driveBesideCombine(dt,targetNode)
		else
			self:driveBehindCombine(dt)

			if self.combineToUnload.cp.driver.ppc:isReversing() then
				local reverseCourse = self:getStraightReverseCourse()
				AIDriver.startCourse(self,reverseCourse,1)
				self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE_NOTURN)
				return
			end
		end

		--when the combine is empty, stop and wait for next combine
		if self:getCombinesFillLevelPercent() <= 0.1 then
			--when the combine is in a pocket, make room to get back to course
			if self.combineToUnload.cp.driver and self.combineToUnload.cp.driver:isWaitingInPocket() then
				print(nameNum(self.vehicle)..": combine empty, set self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_EMPTY_COMBINE)")
				local reverseCourse = self:getStraightReverseCourse()
				AIDriver.startCourse(self,reverseCourse,1)
				self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_EMPTY_COMBINE)
				return
			else
				print(nameNum(self.vehicle)..": combine empty, set self:setNewOnFieldState(self.states.FIND_COMBINE)")
				self:releaseUnloader()
				self:setNewOnFieldState(self.states.FIND_COMBINE)
				return
			end
		end

		--when the combine is turning change, handling turn
		if self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.HANDLE_COMBINE_TURN)
		end

		return
	elseif self.onFieldState == self.states.HANDLE_COMBINE_TURN then
		if not self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
		end
		self:hold()

	elseif self.onFieldState == self.states.FOLLOW_CHOPPER then
		--get target node and check whether trailers are full
		local targetNode = self:getTrailersTargetNode()

		--when trailer is full then go to unload
		if self:getDriveUnloadNow() or self:getAllTrailersFull() then
			local reverseCourse = self:getStraightReverseCourse()
			self:startCourse(reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FULL)
			return
		end

		--decide
		self.combineOffset = self:getChopperOffset(self.combineToUnload)
		self.followCourse:setOffset(-self.combineOffset, 0)

		if self.combineOffset ~= 0 then
			self:driveBesideChopper(dt, targetNode)
		else
			self:driveBehindChopper(dt)
		end

		if self.combineToUnload.cp.driver:isTurningButNotEndingTurn()  then
			local combineTurnStartWpIx = self.combineToUnload.cp.driver:getTurnStartWpIx()
			if combineTurnStartWpIx then
				self:debug('chopper reached a turn waypoint, start chopper turn')
				self:startChopperTurn(combineTurnStartWpIx)
			else
				self:error('Combine is turning but does not have a turn start waypoint index.')
			end
		end

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

		self:setSavedCombineOffset(self.tractorToFollow.cp.combineOffset)
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
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_TRACTOR )
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

	elseif self.onFieldState == self.states.HANDLE_CHOPPER_WIDE_TURN then

		self:handleChopperWideTurn()

	elseif self.onFieldState == self.states.FINDPATH_TO_COURSE then
		if self:startCourseWithPathfinding(self.unloadCourse, 1) then
			self:setNewOnFieldState(self.states.DRIVE_TO_UNLOADCOURSE)
		else
			self:hold()
			self:startCourseWithAlignment(self.unloadCourse, 1)
			self:setNewOnFieldState(self.states.DRIVE_TO_UNLOADCOURSE)
		end

	elseif self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
		--use trafficController
		if not self:trafficContollOK() then
			-- TODO: don't solve anything for now, just wait
			--g_trafficController:solve(self.vehicle.rootNode)
			self:hold()
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

		self.tightTurnOffset = AIDriverUtil.calculateTightTurnOffset(self.vehicle, self.course, self.tightTurnOffset, true)
		self.course:setOffset((self.tightTurnOffset or 0), 0)

	elseif self.onFieldState == self.states.WAIT_FOR_CHOPPER_TURNED then
		--print("self.combineToUnload.cp.turnStage: "..tostring(self.combineToUnload.cp.turnStage))
		self:hold()
		if self.combineToUnload.cp.turnStage == 0 then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
		end

	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FULL then
		local d = self:getDistanceFromCombine()
		--print(string.format("z(%s)> self.vehicle.cp.turnDiameter * 2(%s)",tostring(z),tostring(self.vehicle.cp.turnDiameter * 2)))
		if d > self.vehicle.cp.turnDiameter / 2 then
			self:releaseUnloader()
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
		else
			local zDist = self:getZOffsetToCoordsBehind()
			if zDist < 5 then
				self:holdCombine()
			end
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

	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_EMPTY_COMBINE then
		local dx,dy,dz = self.course:getWaypointLocalPosition(self:getDirectionNode(), 1)
		if dz > 30 then
			self:releaseUnloader()
			self:setNewOnFieldState(self.states.FIND_COMBINE)
		else
			local z = self:getZOffsetToCoordsBehind()
			if z < 5 then
				self:holdCombine()
			end
		end

	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_TURNINGCHOPPER then
		local z = self:getZOffsetToCoordsBehind()
		if z > 5 then
			self:setNewOnFieldState(self.states.HANDLE_CHOPPER_HEADLAND_TURN)
		else
			self:holdCombine()
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER then
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

	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE_NOTURN then
		self:renderText(0, 0, "drive straight reverse :offset local :%s saved:%s", tostring(self.combineOffset), tostring(self.vehicle.cp.combineOffset))
		--local dx,dy,dz = self.course:getWaypointLocalPosition(self:getDirectionNode(), 1)
		local _, _, dz = localToLocal(AIDriverUtil.getDirectionNode(self.vehicle), AIDriverUtil.getDirectionNode(self.combineToUnload), 0, 0, 0)
		if dz < -10 then
			self:hold()
		else
			local z = self:getZOffsetToCoordsBehind()
			if z < 5 then
				self:holdCombine()
			end
		end
		if not self.combineToUnload.cp.driver.ppc:isReversing() then
			if self:combineIsMakingPocket() then
				self:hold()
			else
				self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
			end
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_TRACTOR then
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
	self:debug('Holding combine.')
	self.combineToUnload.cp.driver:hold()
end

function CombineUnloadAIDriver:getRecordedSpeed()
	-- default is the street speed (reduced in corners)
	if self.combineUnloadState == self.states.ONSTREET then
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


function CombineUnloadAIDriver:driveBesideCombine(dt,targetNode)
	self:renderText(0, 0.02, "%s: driveBesideCombine:offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	local allowedToDrive = true
	local fwd = true
	--get required Speed
	local speed  = 0
	speed, allowedToDrive = self:getSpeedBesideCombine(targetNode)
	--get direction to drive to
	local gx, gy, gz, isBeside = self:getDrivingCoordsBeside()
	self:setSavedCombineOffset(self.combineOffset)
	local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, gx, gy, gz);
	self:driveInDirection(dt, lx, lz, fwd, speed, allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end


function CombineUnloadAIDriver:driveBesideChopper(dt,targetNode)
	self:renderText(0, 0.02,"%s: driveBesideCombine:offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	self:releaseAutoAimNode()
	local _, _, dz = localToLocal(targetNode, self.combineToUnload.rootNode, 0, 0, 5)
	renderText(0.2,0.325,0.02,string.format("dz:%s",tostring(dz)))
	self:setSpeed(math.max(0, (self.combineToUnload.lastSpeedReal * 3600) + (MathUtil.clamp(-dz, -10, 15))))
end


function CombineUnloadAIDriver:driveBehindChopper(dt)
	self:renderText(0, 0.05, "%s: driveBehindChopper offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	self:fixAutoAimNode()
	--get required Speed
	self:setSpeed(self:getSpeedBehindChopper())
end

function CombineUnloadAIDriver:driveBehindCombine(dt)
	self:renderText(0, 0.05, "%s: driveBehindCombine offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset))
	local allowedToDrive = true
	local fwd = true
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBehind(self.combineToUnload)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.directionNode, gx,gy,gz);
	--get required Speed
	local speed = self:getSpeedBehindCombine()

	--I'm not behind the combine and have to wait till i can get behind it
	local z = self:getZOffsetToCoordsBehind()
	if z < 0 then
		--print("STOOOOOOP")
		allowedToDrive = false
	else
		self:setSavedCombineOffset(self.combineOffset)
	end


	self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
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
	if self.combineUnloadState == self.states.ONSTREET then
		self:setNewCombineUnloadState(self.states.ONFIELD)
		self:setDriveUnloadNow(false)
		courseplay:openCloseCover(self.vehicle, not courseplay.SHOW_COVERS)
		self:disableCollisionDetection()
	end
end

function CombineUnloadAIDriver:onLastWaypoint()
	if self.combineUnloadState == self.states.ONFIELD then
		if self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
			self:setNewCombineUnloadState(self.states.ONSTREET)
			self:setNewOnFieldState(self.states.FIND_COMBINE)
			self:enableCollisionDetection()
			courseplay:openCloseCover(self.vehicle, courseplay.SHOW_COVERS)
			AIDriver.onLastWaypoint(self)
			g_trafficController:cancel(self.vehicle.rootNode)
			return
		elseif self.onFieldState == self.states.ALIGN_TO_TRACTOR then
			self:setNewOnFieldState(self.states.FOLLOW_TRACTOR)
			g_trafficController:cancel(self.vehicle.rootNode)
		end
	end
	AIDriver.onLastWaypoint(self)
end

function CombineUnloadAIDriver:setNewCombineUnloadState(newState)
	self.combineUnloadState = newState
	self:debug('setNewCombineUnloadState: %s', self.combineUnloadState.name)
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

function CombineUnloadAIDriver:getStraightReverseCourse()
	--print("called CombineUnloadAIDriver:getStraightReverseCourse()")
	local waypoints ={}
	for i=0,-100,-5 do
		local x,y,z =localToWorld(self.trailerToFill.rootNode,0,0,i)
		local point = {
						cx=x;
						cy=y;
						cz=z;
						rev= true;
		}
		table.insert(waypoints,point)
	end
		local tempCourse = Course(self.vehicle,waypoints)

		return tempCourse
	--else
	--	self:debug("Pull back course would be outside of the field")
	--	return nil
	--end
end

function CombineUnloadAIDriver:getTrailersTargetNode()
	local allTrailersFull = true
	for i=1,#self.vehicle.cp.workTools do
		local tipper = self.vehicle.cp.workTools[i]

		--tipper.spec_fillUnit.fillUnits[1].fillLevel =100

		local fillUnits = tipper:getFillUnits()
		for j=1,#fillUnits do
			local tipperFillType = tipper:getFillUnitFillType(j)
			local combineFillType = self.combineToUnload and self.combineToUnload:getFillUnitLastValidFillType(self.combineToUnload:getCurrentDischargeNode().fillUnitIndex) or FillType.UNKNOWN
			if tipper:getFillUnitFreeCapacity(j) > 0 then
				allTrailersFull = false
				if tipperFillType == FillType.UNKNOWN or tipperFillType == combineFillType or combineFillType == FillType.UNKNOWN then
					local targetNode = tipper:getFillUnitAutoAimTargetNode(1)
					if targetNode ~= nil then
						self.trailerToFill = tipper
						return targetNode, allTrailersFull
					end
				end
			end
		end
	end
	return nil,allTrailersFull
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

function CombineUnloadAIDriver:getColliPointHitsTheCombine()
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local cx,cy,cz = localToWorld(colliNode,-1.5,0,0)
	local tx,ty,tz = localToWorld(colliNode, 1.5,0,0)
	local x1,_,z1 = localToWorld(self.combineToUnload.cp.directionNode,-1.5,0,-self:getCombinesMeasuredBackDistance())
	local x2,_,z2 = localToWorld(self.combineToUnload.cp.directionNode, 1.5,0,-self:getCombinesMeasuredBackDistance())
	local x3,_,z3 = localToWorld(self.combineToUnload.cp.directionNode, -1.5,0,0)
	return  MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,cx,cz,tx-cx,tz-cz)
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
	local fwdDistance = self.forwardLookingProximitySensorPack:getClosestObjectDistance()
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

	local rightDistance = self.forwardLookingProximitySensorPack:getClosestObjectDistance(-90)
	local fwdRightDistance = self.forwardLookingProximitySensorPack:getClosestObjectDistance(-45)
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

function CombineUnloadAIDriver:getCombineOffset(combine)
	return g_combineUnloadManager:getCombinesPipeOffset(combine)
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
	return g_combineUnloadManager:getCombinesMeasuredBackDistance(self.combineToUnload)
end

function CombineUnloadAIDriver:getCanShowDriveOnButton()
	return self.combineUnloadState == self.states.ONFIELD
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
	g_combineUnloadManager:releaseUnloaderFromCombine(self.vehicle,self.combineToUnload)
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
		return combineDriver.fieldWorkUnloadOrRefillState == combineDriver.states.MAKING_POCKET
	end
end



function CombineUnloadAIDriver:fixAutoAimNode()
	self.autoAimNodeFixed = true
end

function CombineUnloadAIDriver:releaseAutoAimNode()
	self.autoAimNodeFixed = false
end

function CombineUnloadAIDriver:isAutoAimNodeFixed()
	return self.autoAimNodeFixed
end

--fix the autoAimTargetNode to not get in trouble while driving behind the chopper
function CombineUnloadAIDriver:updateFillUnitAutoAimTarget(superFunc,fillUnit)
	local tractor = self.getAttacherVehicle and self:getAttacherVehicle() or nil
	if tractor and tractor.cp.driver:isAutoAimNodeFixed() then
		local autoAimTarget = fillUnit.autoAimTarget
		if autoAimTarget.node ~= nil then
			if autoAimTarget.startZ ~= nil and autoAimTarget.endZ ~= nil then
				setTranslation(autoAimTarget.node, autoAimTarget.baseTrans[1], autoAimTarget.baseTrans[2], autoAimTarget.startZ)
			end
		end
	else
		superFunc(self,fillUnit)
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

function CombineUnloadAIDriver:renderText(x, y, ...)
	renderText(0.6 + x, 0.2 + y, 0.018, string.format(...))
end

function CombineUnloadAIDriver:isInGoodPositionToStartFollowing(maxDirectionDifferenceDeg)
	local dx, _, dz = localToLocal(self.vehicle.rootNode, AIDriverUtil.getDirectionNode(self.combineToUnload), 0, 0, 0)
	-- close enough and approximately same direction and behind
	return dz < 0 and MathUtil.vector2Length(dx, dz) < 50 and
			TurnContext.isSameDirection(AIDriverUtil.getDirectionNode(self.vehicle), AIDriverUtil.getDirectionNode(self.combineToUnload),
					maxDirectionDifferenceDeg or 30)
end

---@param skipTurnStart boolean if the current waypoint index of the combine is on a turn start, skip to the
--- turn end WP instead. This is to avoid starting following a combine at the turn start WP while the combine is
--- already finishing the course. The current waypoint remains the turn start waypoint during the turn (TODO: review
--- this legacy behavior)
function CombineUnloadAIDriver:startFollowingCombine(skipTurnStart)
	---@type Course
	self.combineCourse = self.combineToUnload.cp.driver:getFieldworkCourse()
	if not self.combineCourse then
		-- TODO: handle this more gracefully, or even better, don't even allow selecting combines with no course
		self:debugSparse('Waiting for combine to set up a course, can\'t follow')
		return
	end
	self.followCourse = self.combineCourse:copy(self.vehicle)
	self.followCourseIx = self.combineCourse:getCurrentWaypointIx()
	-- don't start at a turn start WP, this may throw us back to the previous row as the current WP ix isn't
	-- changed during the entire turn and keeps pointing to the turn start
	if skipTurnStart and self.combineCourse:isTurnStartAtIx(self.followCourseIx) then
		self.followCourseIx = self.followCourseIx + 1
	end

	if courseplay:isChopper(self.combineToUnload) then
		self.combineOffset = self:getChopperOffset(self.combineToUnload)
		self.followCourse:setOffset(-self.combineOffset, 0)
	else
		self.combineOffset = self:getCombineOffset(self.combineToUnload)
		local leftOK = g_combineUnloadManager:getPossibleSidesToDrive(self.combineToUnload)
		if leftOK then
			self.followCourse:setOffset(-self.combineOffset, 0)
		else
			self.followCourse:setOffset(0, 0)
		end
	end
	self:debug('Will follow combine\'s course at waypoint %d, side offset %.1f', self.followCourseIx, self.followCourse.offsetX)
	self:startCourse(self.followCourse, self.followCourseIx)
	self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
end

function CombineUnloadAIDriver:startPathfindingToCombine(xOffset, zOffset)
	self:debug('Finding path to %s', self.combineToUnload:getName())
	self:setNewOnFieldState(self.states.WAITING_FOR_PATHFINDER)

	-- TODO: figure out what to do with the tractor
	if self:getImSecondUnloader() then
		self.tractorToFollow = g_combineUnloadManager:getUnloaderByNumber(1, self.combineToUnload)
		self:setNewOnFieldState(self.states.FINDPATH_TO_TRACTOR)
	end

	if self:isInGoodPositionToStartFollowing(120) then
		self:debug('Close enough to combine, copy combine course and follow')
		g_trafficController:cancel(self.vehicle.rootNode)
		self:startFollowingCombine()
	else
		self:startPathfinding(self.combineToUnload.rootNode, xOffset or 0, zOffset or -10, 0,
				self.combineToUnload, self.onPathfindingDoneToCombine)
	end
end

function CombineUnloadAIDriver:onPathfindingDoneToCombine(path)
	if path and #path > 2 then
		self:debug('Found path (%d waypoints, %d ms) to %s', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0),
				self.combineToUnload:getName())
		local driveToCombineCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToCombineCourse, 1)
	else
		self:error('No path found to %s in %d ms', self.combineToUnload:getName(), self.vehicle.timer - (self.pathfindingStartedAt or 0))
	end
	self:setNewOnFieldState(self.states.DRIVE_TO_COMBINE)
end

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
	if path and #path > 2 then
		self:debug('Found path (%d waypoints, %d ms) to %s, starting wide turn', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0),
				self.combineToUnload:getName())
		local driveToCombineCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(driveToCombineCourse, 1)
		self:setNewOnFieldState(self.states.HANDLE_CHOPPER_WIDE_TURN)
	else
		self:error('No path found to %s in %d ms, handle this as a normal 180 turn', self.combineToUnload:getName(), self.vehicle.timer - (self.pathfindingStartedAt or 0))
		self:setNewOnFieldState(self.states.HANDLE_CHOPPER_180_TURN)
	end
end

function CombineUnloadAIDriver:onPathfindingDoneBeforeFollowing(path)
	if path and #path > 2 then
		self:debug('Found path (%d waypoints, %d ms) close to %s', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0),
				self.combineToUnload:getName())
		local alignCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		alignCourse:print()
		self:startCourse(alignCourse, 1, self.followCourse, self.followCourseIx)
	else
		self:debug('No path found to %s in %d ms, no self unloading', self.combineToUnload:getName(), self.vehicle.timer - (self.pathfindingStartedAt or 0))
	end
	self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
end

function CombineUnloadAIDriver:startPathfinding(
		target, xOffset, zOffset, fieldNum, targetVehicle,
pathfindingCallbackFunc)
	if not self.pathfinder or not self.pathfinder:isActive() then
		local done, path
		self.pathfindingStartedAt = self.vehicle.timer

		if type(target) ~= 'number' then
			self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
					self.vehicle, target, xOffset or 0, zOffset or 0, self.allowReversePathfinding, fieldNum, {targetVehicle})
		else
			self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(
					self.vehicle, target, xOffset or 0, zOffset or 0, self.allowReversePathfinding, fieldNum, {targetVehicle})
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

function CombineUnloadAIDriver:setMyCombine(combine)
	self.combineVehicleData = PathfinderUtil.VehicleData(combine, true)
end

function CombineUnloadAIDriver:findCollidingShapes()
	local frontMarkerNode = self:getFrontMarkerNode(self.vehicle)
	if not frontMarkerNode then return 0 end
	local x, y, z = localToWorld(frontMarkerNode, 0, 0, 0)
	local lx, _, lz = localDirectionToWorld(self.vehicle.rootNode, 0, 0, 1)
	local yRot = math.atan2(lx, lz)
	-- not so sure about this box size calculation, it seems that width/length is the half size of the box
	local width = (math.abs(self.myVehicleData.dRight) + math.abs(self.myVehicleData.dLeft)) / 2
	local length = self.targetDistanceBehindChopper * 0.7
	self.collidingShapes = 0
	overlapBox(x, y + 1, z, 0, yRot, 0, width, 1, length,
			'overlapBoxCallback', self, bitOR(AIVehicleUtil.COLLISION_MASK, 2), true, true, true)
	DebugUtil.drawOverlapBox(x, y + 1, z, 0, yRot, 0, width, 1, length, 100, 0, 0)
	return self.collidingShapes
end

function CombineUnloadAIDriver:overlapBoxCallback(transformId)
	local collidingObject = g_currentMission.nodeToObject[transformId]
	if collidingObject and collidingObject.getRootVehicle then

		local rootVehicle = collidingObject:getRootVehicle()
		if rootVehicle == self.myVehicleData.vehicle or PathfinderUtil.elementOf(self.vehiclesToIgnore, rootVehicle) then
			-- just bumped into myself or a vehicle we want to ignore
			return
		end
		self.collidingShapes = self.collidingShapes + 1
	end
end


---@return number, number, number distance between the tractor's front and the combine's back (always positive),
--- side offset (local x) of the combine's back in the tractor's front coordinate system (positive if the tractor is on
--- the right side of the combine)
--- back offset (local z) of the combine's back in the tractor's front coordinate system (positive if the tractor is behind
--- the combine)
function CombineUnloadAIDriver:getDistanceFromCombine()
	local dx, _, dz = localToLocal(self:getBackMarkerNode(self.combineToUnload), self:getFrontMarkerNode(self.vehicle), 0, 0, 0)
	return MathUtil.vector2Length(dx, dz), dx, dz
end

function CombineUnloadAIDriver:updateCombineInfo()
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

function CombineUnloadAIDriver:calculateRelativeSpeedToCombine(dt)
	if not self.combineToUnload then return end
	self.relativeSpeedToCombine = 3600 * (self.vehicle.lastSpeedReal - self.combineToUnload.lastSpeedReal)
	self:renderText(0, 0.73, 'relative speed = %.1f', self.relativeSpeedToCombine)
end

------------------------------------------------------------------------------------------------------------------------
-- Check for full trailer
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:changeToUnloadWhenFull()
	--if the fillLevel is reached while turning go to Unload course
	if self:shouldDriveOn() then
		self:debug('Trailer full, changing to unload course')
		local reverseCourse = self:getStraightReverseCourse()
		self:startCourse(reverseCourse, 1)
		self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FULL)
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
		self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER )
	end

	self:changeToUnloadWhenFull()

	--when the turn is finished, return to follow chopper
	if not self:getCombineIsTurning() then
		self:debug('Combine stopped turning, resuming follow course')
		-- resume course beside combine
		self:startCourse(self.followCourse, self.combineCourse:getCurrentWaypointIx())
		self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turn 180
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:handleChopper180Turn()

	self:changeToUnloadWhenFull()

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
		d = self:getDistanceFromCombine()
		if d > self.combineToUnload.cp.driver:getWorkWidth() * 2 and self.turnContext then
			self:debug('Combine is at %1.f m > 2 times to work width, switching to wide turn mode', d)
			self:startPathfindingToTurnEnd()
		end
	else
		-- combine stopped turning, set up a path to follow again
		self:startFollowingCombine(true)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper wide turn
------------------------------------------------------------------------------------------------------------------------
function CombineUnloadAIDriver:handleChopperWideTurn()

	self:changeToUnloadWhenFull()

	if self.combineToUnload.cp.driver:isTurning() then
		-- follow course, make sure we are keeping distance from the chopper
		local d = self:getDistanceFromCombine()
		local combineSpeed = (self.combineToUnload.lastSpeedReal * 3600)
		local speed = combineSpeed + MathUtil.clamp(d - self.minDistanceFromWideTurnChopper, -combineSpeed, self.vehicle.cp.speeds.field)
		self:setSpeed(speed)
		self:renderText(0, 0.7, 'd = %.1f, speed = %.1f', d, speed)

	else
		-- chopper is ending/ended turn, go back to follow mode
		self:startFollowingCombine(true)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Combine Event Listeners
------------------------------------------------------------------------------------------------------------------------

function CombineUnloadAIDriver:onCombineTurnStart(ix, turnType)
	if self.combineUnloadState == self.states.ONFIELD then
		if self.onFieldState == self.states.FOLLOW_CHOPPER then
			self:debug('chopper reached turn waypoint %d, start chopper turn', ix)
			--self:startChopperTurn(ix, turnType)
		end
	end
end

FillUnit.updateFillUnitAutoAimTarget =  Utils.overwrittenFunction(FillUnit.updateFillUnitAutoAimTarget,CombineUnloadAIDriver.updateFillUnitAutoAimTarget)
