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
---@class CombineUnloadAIDriver : AIDriver
CombineUnloadAIDriver = CpObject(AIDriver)

CombineUnloadAIDriver.myStates = {
	ONFIELD = {},
	ONSTREET = {},
	FIND_COMBINE ={},
	FINDPATH_TO_COMBINE={},
	FINDPATH_TO_TRACTOR={},
	DRIVE_TO_COMBINE = {},
	DRIVE_TO_TRACTOR={},
	FINDPATH_TO_COURSE={},
	DRIVE_TO_UNLOADCOURSE ={},
	DRIVE_BESIDE_TRACTOR ={},
	ALIGN_TO_COMBINE = {},
	ALIGN_TO_TRACTOR = {},
	GET_ALIGNCOURSE_TO_COMBINE ={},
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
	HANDLE_CHOPPER_TURN = {},
	WAIT_FOR_COMBINES_FILLLEVEL = {},
	WAIT_FOR_CHOPPER_TURNED = {}
}

--- Constructor
function CombineUnloadAIDriver:init(vehicle)
	print("CombineUnloadAIDriver:init()")
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_COMBI
	self:initStates(CombineUnloadAIDriver.myStates)
	self:setNewCombineUnloadState(self.states.ONSTREET)
	self:setNewOnFieldState(self.states.FIND_COMBINE)
	self.combineOffset = 0
	self.distanceToCombine = math.huge
	self.distanceToFront = 0
	self.vehicle.cp.possibleCombines ={}
	self.vehicle.cp.assignedCombines ={}
	self.vehicle.cp.combinesListHUDOffset = 0
end

function CombineUnloadAIDriver:setHudContent()
	courseplay.hud:setCombineUnloadAIDriverContent(self.vehicle)
end

function CombineUnloadAIDriver:start(ix)

	AIDriver.start(self, ix)
	local x,_,z = getWorldTranslation(self:getDirectionNode())
	if courseplay:isField(x, z) then
		self:setNewCombineUnloadState(self.states.ONFIELD)
		self:setNewOnFieldState(self.states.FIND_COMBINE)
		self:disableCollisionDetection()
		self:setDriveUnloadNow(false)
	end
	self.distanceToFront = 0
end

function CombineUnloadAIDriver:dismiss()
	local x,_,z = getWorldTranslation(self:getDirectionNode())
	if self.combineToUnload then
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
	local renderOffset = self.vehicle.cp.coursePlayerNum *0.03
	renderText(0.2,0.225+renderOffset,0.02,string.format("%s: self.onFieldState :%s",nameNum(self.vehicle),self.statusString))

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
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function CombineUnloadAIDriver:driveOnField(dt)
	if self.vehicle.cp.forcedToStop then
		self:stopAndWait(dt)
		return
	end
	if self.onFieldState == self.states.FIND_COMBINE then
		local timeTillStartUnloading,combineToWaitFor
		if self:getDriveUnloadNow() or self:getAllTrailersFull() or self:shouldDriveOn() then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			return
		end

		self.combineToUnload, combineToWaitFor, timeTillStartUnloading  = g_combineUnloadManager:giveMeACombineToUnload(self.vehicle)
		if self.combineToUnload ~= nil then
			--print("combine set")
			self:refreshHUD()
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
			if self:getImSecondUnloader() then
				self.tractorToFollow = g_combineUnloadManager:getUnloaderByNumber(1, self.combineToUnload)
			end
		else
			if combineToWaitFor then
				courseplay:setInfoText(self.vehicle,string.format("COURSEPLAY_WAITING_FOR_FILL_LEVEL;%s;%d",nameNum(combineToWaitFor),timeTillStartUnloading));
			else
				courseplay:setInfoText(self.vehicle, "COURSEPLAY_NO_COMBINE_IN_REACH");
			end
		end
		self:hold()

	elseif self.onFieldState == self.states.FINDPATH_TO_COMBINE then
		if self:getImSecondUnloader() then
			self:setNewOnFieldState(self.states.FINDPATH_TO_TRACTOR)
			return
		end

		--get coords of the combine
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.rootNode)
		if self:driveToPointWithPathfinding(cx, cz) then
			self:setNewOnFieldState(self.states.DRIVE_TO_COMBINE)
			self.lastCombinesCoords = { x=cx;
										y=cy;
										z=cz;
			}
		end
	elseif self.onFieldState == self.states.FINDPATH_TO_TRACTOR then
		--get coords of the combine
		local cx,cy,cz = localToWorld(self.tractorToFollow.rootNode,0,0,-20)
		if not courseplay:isField(cx,cz,0.1,0.1) then
			cx,cy,cz = getWorldTranslation(self.tractorToFollow.rootNode)
		end
		if self:driveToPointWithPathfinding(cx, cz) then
					self:setNewOnFieldState(self.states.DRIVE_TO_TRACTOR)
					self.lastTractorsCoords = { x=cx;
					y=cy;
					z=cz;
					}
		end
	elseif self.onFieldState == self.states.DRIVE_TO_TRACTOR then
		--if  I'm the first Unloader switch to follow chopper
		if g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) == 1 then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
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
		--set Offset to avoid crashing into traffic moving to course
		self.ppc:setOffset(3, 0)
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
		if courseplay:distanceToPoint(self.combineToUnload,self.lastCombinesCoords.x,self.lastCombinesCoords.y,self.lastCombinesCoords.z) > 50 then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
		end
		--if we are in range , change to align mode
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.rootNode)
		if courseplay:distanceToPoint(self.vehicle,cx,cy,cz) < 50 then
			self:setNewOnFieldState(self.states.GET_ALIGNCOURSE_TO_COMBINE)
		end
		--set Offset to avoid crashing into traffic moving to course
		self.ppc:setOffset(3, 0)
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

	elseif self.onFieldState == self.states.GET_ALIGNCOURSE_TO_COMBINE then
		self.ppc:setOffset(0, 0)
		local tempCourseToAlign
		if courseplay:isChopper(self.combineToUnload) then
			self.combineOffset = self:getChopperOffset(self.combineToUnload)
			tempCourseToAlign = self:getCourseToAlignTo(self.combineToUnload,self.combineOffset)
		else
			self.combineOffset = self:getCombineOffset(self.combineToUnload)
			local leftOK = g_combineUnloadManager:getPossibleSidesToDrive(self.combineToUnload)
			if leftOK then
				tempCourseToAlign = self:getCourseToAlignTo(self.combineToUnload,self.combineOffset)
			else
				tempCourseToAlign = self:getCourseToAlignTo(self.combineToUnload,0)
			end
		end
		if tempCourseToAlign ~= nil then
			self:startCourseWithAlignment(tempCourseToAlign, 1)
			self:setNewOnFieldState(self.states.ALIGN_TO_COMBINE)
			g_trafficController:cancel(self.vehicle.rootNode)
		end
	elseif self.onFieldState == self.states.GET_ALIGNCOURSE_TO_TRACTOR then
		self.ppc:setOffset(0, 0)
		local tempCourseToAlign = self:getCourseToAlignTo(self.tractorToFollow,0)
		if tempCourseToAlign ~= nil then
			self:startCourseWithAlignment(tempCourseToAlign, 1)
			self:setNewOnFieldState(self.states.ALIGN_TO_TRACTOR)
		end

	elseif self.onFieldState == self.states.ALIGN_TO_COMBINE then
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_BEHIND_COMBINE");
		--do nothing just drive
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
			AIDriver.startCourse(self,reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FULL)
			return
		end

		--decide
		self.combineOffset = self:getChopperOffset(self.combineToUnload)
		if self.combineOffset ~= 0 then
			self:driveBesideChopper(dt,targetNode)
		else
			self:driveBehindChopper(dt)
		end

		if self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.HANDLE_CHOPPER_TURN)
		end

		return


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

	elseif self.onFieldState == self.states.HANDLE_CHOPPER_TURN then
		--if the chopper is reversing, drive backwards
		if self.combineToUnload.cp.driver.ppc:isReversing() then
			local reverseCourse = self:getStraightReverseCourse()
			AIDriver.startCourse(self,reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER )
		end

		--standard turns
		if self.combineToUnload.cp.turnStage ~= nil then
			if self.combineToUnload.cp.turnStage> 1 then
				self:setNewOnFieldState(self.states.WAIT_FOR_CHOPPER_TURNED)
			end
		end

		--if the fillLevel is reached while turning go to Unload course
		if self:shouldDriveOn() then
			local reverseCourse = self:getStraightReverseCourse()
			AIDriver.startCourse(self,reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FULL)
			return
		end

		--decide whether to drive beside or behind choppper
		if self.combineOffset ~= 0 then
			local z = self:getZOffsetToCoordsBehind()
			local savedOffset = self:getSavedCombineOffset()

			--when I'm beside the chopper and it turns towards me, drive backwards out of the way
			if z < 0
				and ((savedOffset < 0 and self.combineToUnload.rotatedTime < -0.5)
				or (savedOffset > 0 and self.combineToUnload.rotatedTime > 0.5))then
				--print(string.format("vehicle.rotatedTime:%s z:%s; offset:%s; dirSelfX:%s; dirSelfZ:%s; dirCombine:%s ",tostring(self.combineToUnload.rotatedTime) ,tostring(z),tostring(savedOffset),tostring(dirSelfX),tostring(dirSelfZ),tostring(dirCombineX)))
				if savedOffset <0 and self.combineToUnload.rotatedTime < 0.5 then
					print("turns right, I'm right")
				else
					print("turns left, I'm left")
				end

				local reverseCourse = self:getStraightReverseCourse()
				AIDriver.startCourse(self,reverseCourse,1)
				self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_TURNINGCHOPPER)
				self.combineOffset = 0
				return
			end

			local targetNode,allTrailersFull = self:getTrailersTargetNode()
			self:driveBesideChopper(dt,targetNode)
		else
			self:driveBehindChopper(dt)
		end
		--when the turn is finshed, return to follow chopper
		if not self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
		end
		return


	elseif self.onFieldState == self.states.FINDPATH_TO_COURSE then
		if self:startCourseWithPathfinding(self.mainCourse, 1) then
			self:setNewOnFieldState(self.states.DRIVE_TO_UNLOADCOURSE)
		else
			self:hold()
			self:startCourseWithAlignment(self.mainCourse, 1)
			self:setNewOnFieldState(self.states.DRIVE_TO_UNLOADCOURSE)
		end

	elseif self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
		self.ppc:setOffset(3, 0)
		--use trafficController
		if not self:trafficContollOK() then
			g_trafficController:solve(self.vehicle.rootNode)
			self:hold()
		else
			g_trafficController:resetSolver(self.vehicle.rootNode)
		end

	elseif self.onFieldState == self.states.WAIT_FOR_CHOPPER_TURNED then
		--print("self.combineToUnload.cp.turnStage: "..tostring(self.combineToUnload.cp.turnStage))
		self:hold()
		if self.combineToUnload.cp.turnStage == 0 then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
		end

	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FULL then
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.cp.DirectionNode)
		local _,_,z = worldToLocal(self:getDirectionNode(),cx,cy,cz)
		--print(string.format("z(%s)> self.vehicle.cp.turnDiameter * 2(%s)",tostring(z),tostring(self.vehicle.cp.turnDiameter * 2)))
		if z> self.vehicle.cp.turnDiameter * 2 then
			self:releaseUnloader()
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			self:recoverOriginalWaypoints()
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
			self:recoverOriginalWaypoints()
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
			self:setNewOnFieldState(self.states.HANDLE_CHOPPER_TURN)
			self:recoverOriginalWaypoints()
		else
			self:holdCombine()
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER then
		renderText(0.2,0.195,0.02,string.format("drive straight reverse :offset local :%s saved:%s",tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
		local dx,dy,dz = self.course:getWaypointLocalPosition(self:getDirectionNode(), 1)
		if dz > 15 then
			self:hold()
		else
			local z = self:getZOffsetToCoordsBehind()
			if z < 5 then
				self:holdCombine()
			end
		end
		if not self.combineToUnload.cp.driver.ppc:isReversing() then
			self:setNewOnFieldState(self.states.HANDLE_CHOPPER_TURN)
			self:recoverOriginalWaypoints()
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE_NOTURN then
		renderText(0.2,0.195,0.02,string.format("drive straight reverse :offset local :%s saved:%s",tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
		local dx,dy,dz = self.course:getWaypointLocalPosition(self:getDirectionNode(), 1)
		if dz > 30 then
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
				self:recoverOriginalWaypoints()
			end
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_TRACTOR then
		if not self:tractorIsReversing() then
			self:setNewOnFieldState(self.states.FOLLOW_TRACTOR)
			self:recoverOriginalWaypoints()
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
	renderText(0.2,0.135,0.02,string.format("%s: driveBesideCombine:offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
	local allowedToDrive = true
	local fwd = true
	--get required Speed
	local speed  = 0
	speed, allowedToDrive = self:getSpeedBesideCombine(targetNode)
	--get direction to drive to
	local gx,gy,gz,isBeside = self:getDrivingCoordsBeside()
	self:setSavedCombineOffset(self.combineOffset)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end


function CombineUnloadAIDriver:driveBesideChopper(dt,targetNode)
	renderText(0.2,0.135,0.02,string.format("%s: driveBesideCombine:offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
	self:releaseAutoAimNode()
	local allowedToDrive = true
	local fwd = true
	--get required Speed
	local speed = 0
	speed, allowedToDrive = self:getSpeedBesideChopper(targetNode)
	--get direction to drive to
	local gx,gy,gz,isBeside = self:getDrivingCoordsBeside()
	if not isBeside then
		speed = self:getSpeedBehindChopper()
		if self:getColliPointHitsTheCombine() then
			--print("STOOOOOOP")
			allowedToDrive = false
		end
	else
		self:setSavedCombineOffset(self.combineOffset)
	end
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end


function CombineUnloadAIDriver:driveBehindChopper(dt)
	renderText(0.2,0.165,0.02,string.format("%s: driveBehindCombine offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
	self:fixAutoAimNode()
	local allowedToDrive = true
	local fwd = true
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBehind(self.combineToUnload)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	--get required Speed
	local speed = self:getSpeedBehindChopper()

	--I'm not behind the combine and have to wait till i can get behind it
	local sx,sy,sz = getWorldTranslation(self:getDirectionNode())
	local _,_,backShiftNode = worldToLocal(self.combineToUnload.cp.DirectionNode,sx,sy,sz)
	local _,_,backShiftTarget = worldToLocal(self.combineToUnload.cp.DirectionNode,gx,gy,gz)
	local z = self:getZOffsetToCoordsBehind()
	if backShiftNode < backShiftTarget then
		if z < 0 then
			--print("STOOOOOOP")
			allowedToDrive = false
		else
			self:setSavedCombineOffset(self.combineOffset)
		end
	end
	self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function CombineUnloadAIDriver:driveBehindCombine(dt)
	renderText(0.2,0.165,0.02,string.format("%s: driveBehindCombine offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
	local allowedToDrive = true
	local fwd = true
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBehind(self.combineToUnload)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
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
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	--get required Speed
	local speed = self:getSpeedBehindTractor(self.tractorToFollow)
	if not courseplay:isField(gx, gz) then
		allowedToDrive = false
	end
	allowedToDrive = allowedToDrive and self.allowedToDrive
	renderText(0.2,0.165,0.02,string.format("%s: driveBehindTractor distance: %.2f",nameNum(self.vehicle),courseplay:distanceToObject(self.vehicle, self.tractorToFollow)))
	self:driveInDirection(dt,lx,lz,fwd,speed,allowedToDrive)
	--AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function CombineUnloadAIDriver:driveBesideTractor(dt)

	local allowedToDrive = true
	local speed = 0
	local fwd = true
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBesideTractor(self.tractorToFollow)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	--get required Speed
	local targetNode = self:getTrailersTargetNode()
	speed, allowedToDrive = self:getSpeedBesideChopper(targetNode)
	allowedToDrive = allowedToDrive and self.allowedToDrive
	renderText(0.2,0.165,0.02,string.format("driveBesideTractor distance: %.2f",courseplay:distanceToObject(self.vehicle, self.tractorToFollow)))
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
			self.ppc:setOffset(0, 0)
			g_trafficController:cancel(self.vehicle.rootNode)
			return
		elseif self.onFieldState == self.states.ALIGN_TO_COMBINE then
			self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
			g_trafficController:cancel(self.vehicle.rootNode)
		elseif self.onFieldState == self.states.ALIGN_TO_TRACTOR then
			self:setNewOnFieldState(self.states.FOLLOW_TRACTOR)
			g_trafficController:cancel(self.vehicle.rootNode)
		end
	end
	AIDriver.onLastWaypoint(self)
end

function CombineUnloadAIDriver:setNewCombineUnloadState(newState)
	self.combineUnloadState = newState
	local printString = 'nil'
	for name, state in pairs(self.states) do
		if state == self.combineUnloadState then
			printString = name
			self.statusString = name
			break
		end
	end
	print(tostring(self.vehicle.name)..": setNewCombineUnloadState: "..printString)
end


function CombineUnloadAIDriver:setNewOnFieldState(newState)
	self.onFieldState = newState
	local printString = 'nil'
	for name, state in pairs(self.states) do
		if state == self.onFieldState then
			printString = name
			self.statusString = name
			break
		end
	end
	print(tostring(self.vehicle.name)..": setNewOnFieldState: "..printString)
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

--[[   1 :: table: 0x02a609433738
--  ridgeMarker :: 0
--  dirX :: -0.023623896329334
--  cx :: 50.34
--  speed :: 40
--  rotY :: -3.1179665457138
--  dirZ :: -0.9997203401186
--  angle :: -178.64632373239
--  unload :: false
--  rev :: false
--  turnStart :: false
--  distToNextPoint :: 9.3126043618313
--  turnEnd :: false
--  rotX :: -0.0010738136758804
--  cy :: 112.57
--  crossing :: true
--  cz :: 117.15
--  dirY :: 0.0010738134695157
--  wait :: false]]

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
		self:setNewVehiclesWaypoints(waypoints)

		return tempCourse
	--else
	--	self:debug("Pull back course would be outside of the field")
	--	return nil
	--end
end

function CombineUnloadAIDriver:setNewVehiclesWaypoints(waypoints)
	self.vehicle.WaypointsBackup = self.vehicle.Waypoints
	self.vehicle.cp.numWaypointsBackup = self.vehicle.cp.numWaypoints
	self.vehicle.Waypoints = waypoints
	self.vehicle.cp.numWaypoints = #waypoints
end

function CombineUnloadAIDriver:recoverOriginalWaypoints()
	self.vehicle.Waypoints = self.vehicle.WaypointsBackup
	self.vehicle.cp.numWaypoints= self.vehicle.cp.numWaypointsBackup
	self.vehicle.WaypointsBackup= nil
	self.vehicle.cp.numWaypointsBackup = nil
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
						return targetNode,allTrailersFull
					end
				end
			end
		end
	end
	return nil,allTrailersFull
end

function CombineUnloadAIDriver:getDrivingCoordsBeside()
	local tx,ty,tz = localToWorld(self:getDirectionNode(),0,0,5)
	local sideShift,_,backShift = worldToLocal(self.combineToUnload.cp.DirectionNode,tx,ty,tz)
	local backDistance = self:getCombinesMeasuredBackDistance() +3
	local origLx,origLz = AIVehicleUtil.getDriveDirection(self.combineToUnload.cp.DirectionNode, tx,ty,tz);
	local lx,lz = origLx,origLz
	local isBeside = false
	if self.combineOffset > 0 then
		lx = math.max(0.25,lx)
		--if I'm on the wrong side, drive to combines back first
		if backShift>0 and sideShift<0 then
			lx = 0;
			lz= -1
		end
	else
		lx = math.min(-0.25,lx)
		--if I'm on the wrong side, drive to combines back first
		if backShift>0 and sideShift>0 then
			lx = 0;
			lz= -1
		end
	end

	local rayLength = (math.abs(self.combineOffset)*math.abs(lx))+(backDistance -(backDistance*math.abs(lx)))
	local nx,ny,nz = localDirectionToWorld(self.combineToUnload.cp.DirectionNode, lx, 0, lz)
	local cx,cy,cz = getWorldTranslation(self.combineToUnload.cp.DirectionNode)
	local x,y,z = cx+(nx*rayLength),cy,cz+(nz*rayLength)
	local offsetDifference = self.combineOffset - sideShift
	local distanceToTarget = courseplay:distance(tx, tz, x, z)
	--we are on the correct side but not close to the target point, so got dirctely to the offsetTarget
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
	if lz >0 or isBeside then
		x,y,z = localToWorld(self.combineToUnload.cp.DirectionNode,self.combineOffset,0,backShift)
	end
	cpDebug:drawLine(cx,cy+1,cz,100,100,100,x,y+1,z)
	return x,y,z,isBeside
end

function CombineUnloadAIDriver:getDrivingCoordsBehind()

	local tx,ty,tz = localToWorld(self:getDirectionNode(),0,0,5)
	local sideShift,_,backShift = worldToLocal(self.combineToUnload.cp.DirectionNode,tx,ty,tz)
	local x,y,z = 0,0,0
	local sx,sy,sz = getWorldTranslation(self:getDirectionNode())
	local _,_,backShiftNode = worldToLocal(self.combineToUnload.cp.DirectionNode,sx,sy,sz)
	if backShiftNode > -self:getCombinesMeasuredBackDistance() then
		local lx,lz = AIVehicleUtil.getDriveDirection(self.combineToUnload.cp.DirectionNode, tx,ty,tz);
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.cp.DirectionNode)
		local fixOffset = g_combineUnloadManager:getCombinesPipeOffset(self.combineToUnload)
		if sideShift > 0 then
			x,y,z = localToWorld(self.combineToUnload.cp.DirectionNode,fixOffset,0,backShift)
		else
			x,y,z = localToWorld(self.combineToUnload.cp.DirectionNode,-fixOffset,0,backShift)
		end
		cpDebug:drawLine(cx,cy+1,cz, 100, 100, 100, x,cy+1,z)
	else
		x,y,z = localToWorld(self.combineToUnload.cp.DirectionNode,0,0, - (self:getCombinesMeasuredBackDistance()))
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
	local sideShift,_,backShift = worldToLocal(tractorToFollow.cp.DirectionNode,sx,sy,sz)
	local tx,ty,tz = localToWorld(tractorToFollow.cp.DirectionNode,0,0,math.max(-30,backShift))
	return tx,ty,tz
end

function CombineUnloadAIDriver:getDrivingCoordsBesideTractor(tractorToFollow)
	local offset = self:getChopperOffset(self.combineToUnload)
	local sx,sy,sz = localToWorld(self:getDirectionNode(),0,0,5)
	local sideShift,_,backShift = worldToLocal(tractorToFollow.cp.DirectionNode,sx,sy,sz)
	local newX = 0
	if offset < 0 then
		newX = - 4.5
	else
		newX = 4.5
	end
	local tx,ty,tz = localToWorld(tractorToFollow.cp.DirectionNode,newX,0,math.max(-20,backShift))
	cpDebug:drawLine(sx,sy+1,sz, 100, 100, 100, tx,ty+1,tz)
	return tx,ty,tz
end

function CombineUnloadAIDriver:getColliPointHitsTheCombine()
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local cx,cy,cz = localToWorld(colliNode,-1.5,0,0)
	local tx,ty,tz = localToWorld(colliNode, 1.5,0,0)
	local x1,_,z1 = localToWorld(self.combineToUnload.cp.DirectionNode,-1.5,0,-self:getCombinesMeasuredBackDistance())
	local x2,_,z2 = localToWorld(self.combineToUnload.cp.DirectionNode, 1.5,0,-self:getCombinesMeasuredBackDistance())
	local x3,_,z3 = localToWorld(self.combineToUnload.cp.DirectionNode, -1.5,0,0)
	return  MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,cx,cz,tx-cx,tz-cz)
end

function CombineUnloadAIDriver:getZOffsetToCoordsBehind()
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local sx,sy,sz = getWorldTranslation(colliNode)
	local _,_,z = worldToLocal(self.combineToUnload.cp.DirectionNode,sx,sy,sz)
	return -(z + self:getCombinesMeasuredBackDistance())
end

function CombineUnloadAIDriver:getSpeedBesideChopper(targetNode)
	local allowedToDrive = true
	local baseNode = self:getPipesBaseNode(self.combineToUnload)
	local bnX,bnY,bnZ = getWorldTranslation(baseNode)
	--Discharge Node to AutoAimNode
	local wx,wy,wz = getWorldTranslation(targetNode)
	--cpDebug:drawLine(dnX,dnY,dnZ, 100, 100, 100, wx,wy,wz)
	local dx,_,dz = worldToLocal(targetNode,bnX,bnY,bnZ)
	--am I too far in front but beside the chopper ?
	if dz < -3 and math.abs(dx)< math.abs(self:getSavedCombineOffset())+1 then
		allowedToDrive = false
	end
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(dz,-10,15)),allowedToDrive
end

function CombineUnloadAIDriver:getSpeedBesideCombine(targetNode)
	local allowedToDrive = true
	local dischargeNode = self.combineToUnload:getCurrentDischargeNode().node
	local dnX,dnY,dnZ = getWorldTranslation(dischargeNode)
	local _,_,dz = worldToLocal(targetNode,dnX,dnY,dnZ)
	--renderText(0.2,0.225,0.02,string.format("dz:%s",tostring(dz)))
	if dz < 0 then
		allowedToDrive = false
	end
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(dz,-10,35)),allowedToDrive
end

function CombineUnloadAIDriver:getSpeedBehindCombine()
	if self.distanceToFront == 0 then
		self:raycastFront()
		return
	else
		self:raycastDistance(30)
	end
	local targetGap = 20
	local targetDistance = self.distanceToCombine - targetGap
	--renderText(0.2,0.195,0.02,string.format("self.distanceToCombine:%s, targetDistance:%s speed:%s",tostring(self.distanceToCombine),tostring(targetDistance),tostring((self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15)))))
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15))
end

function CombineUnloadAIDriver:getSpeedBehindChopper()
	if self.distanceToFront == 0 then
		self:raycastFront()
		return
	else
		self:raycastDistance(10)
	end
	local targetGap = 0.5
	local targetDistance = self.distanceToCombine - targetGap
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15))
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
	return self.combineToUnload.cp.driver and self.combineToUnload.cp.driver.turnIsDriving or self.combineToUnload.cp.driver.fieldworkState == self.combineToUnload.cp.driver.states.TURNING
end

function CombineUnloadAIDriver:getCombineOffset(combine)
	return g_combineUnloadManager:getCombinesPipeOffset(combine)
end

function CombineUnloadAIDriver:getChopperOffset(combine)
	local offset =  g_combineUnloadManager:getCombinesPipeOffset(combine)
	local leftOk,rightOK = g_combineUnloadManager:getPossibleSidesToDrive(combine)
	local savedOffset = self.vehicle.cp.combineOffset

	if not leftOk and not rightOK then
		return 0
	end
	if leftOk and not rightOK then
		if savedOffset >= 0 then
			return offset
		else
			return 0
		end
	end

	if not leftOk and rightOK then
		if savedOffset <= 0 then
			return -offset
		else
			return 0
		end
	end
	return savedOffset
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
end

function CombineUnloadAIDriver:raycastFront()
	local nx, ny, nz = localDirectionToWorld(self:getDirectionNode(), 0, 0, -1)
	self.distanceToFront = 0
	for x=-1.5,1.5,0.1 do
		for y=0.2,3,0.1 do
			local rx,ry,rz = localToWorld(self.vehicle.cp.DirectionNode, x, y, 10)
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

function CombineUnloadAIDriver:raycastDistance(maxDistance)
	self.distanceToCombine = math.huge
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local nodeX, nodeY, nodeZ = getWorldTranslation(colliNode)
	local gx,gy,gz = localToWorld(self.combineToUnload.cp.DirectionNode,0,0, -(self:getCombinesMeasuredBackDistance()))
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
FillUnit.updateFillUnitAutoAimTarget =  Utils.overwrittenFunction(FillUnit.updateFillUnitAutoAimTarget,CombineUnloadAIDriver.updateFillUnitAutoAimTarget)
