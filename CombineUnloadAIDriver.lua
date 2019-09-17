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
	DRIVE_TO_COMBINE = {},
	FINDPATH_TO_COURSE={},
	DRIVE_TO_UNLOADCOURSE ={},
	DRIVE_BESIDE_TRACTOR ={},
	ALIGN_TO_COMBINE = {},
	GET_ALIGNCOURSE_TO_COMBINE ={},
	FOLLOW_COMBINE ={},
	FOLLOW_CHOPPER ={},
	FOLLOW_TRACTOR = {},
	PREPARE_TURN ={},
	DRIVE_TURN ={},
	DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE = {},
	DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER ={},
	DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE_NOTURN = {},
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
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_COMBI
	self:initStates(CombineUnloadAIDriver.myStates)
	self:setNewCombineUnloadState(self.states.ONSTREET)
	self:setHudContent()
	self:setNewOnFieldState(self.states.FIND_COMBINE)
	self.combineOffset = 0
	self.distanceToCombine = math.huge
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
	self.distanceToFront = nil
end

function CombineUnloadAIDriver:drive(dt)
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
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

function CombineUnloadAIDriver:driveOnField(dt)
	local renderOffset = self.vehicle.cp.coursePlayerNum *0.03
	renderText(0.2,0.225+renderOffset,0.02,string.format("%s: self.onFieldState :%s",nameNum(self.vehicle),self.statusString))
	if self:getDriveUnloadNow() or self:getAllTrailersFull() then
		--print("unloadnow or trailer full")
		if self.onFieldState ~= self.states.FINDPATH_TO_COURSE
		and self.onFieldState ~= self.states.DRIVE_TO_UNLOADCOURSE
		and self.onFieldState ~= self.states.DRIVE_STRAIGHTBACK_FULL then
			if self.onFieldState == self.states.FOLLOW_CHOPPER then
				local reverseCourse = self:getStraightReverseCourse()
				AIDriver.startCourse(self,reverseCourse,1)
				self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FULL)
			else
				self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			end
			self.vehicle.isAssigned = false
		end
	end

	if self.onFieldState == self.states.FIND_COMBINE then
		g_combineUnloadManager:enterField(self.vehicle)
		self.combineToUnload = g_combineUnloadManager:giveMeACombineToUnload(self.vehicle)
		if self.combineToUnload ~= nil then
			--print("combine set")
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
			local number = g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload)
			if number > 1 then
				self.tractorToFollow = g_combineUnloadManager:getUnloaderByNumber(number-1, self.combineToUnload)
			end
		else
			courseplay:setInfoText(self.vehicle, "COURSEPLAY_NO_COMBINE_IN_REACH");
		end
		self:hold()

	elseif self.onFieldState == self.states.FINDPATH_TO_COMBINE then
		--get coords of the combine
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.rootNode)
		if self:driveToPointWithPathfinding(cx, cz) then
			self:setNewOnFieldState(self.states.DRIVE_TO_COMBINE)
			self.lastCombinesCoords = { x=cx;
										y=cy;
										z=cz;
			}
		end

	elseif self.onFieldState == self.states.DRIVE_TO_COMBINE then
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_TO_COMBINE");
		--check whether the combine moved meanwhile
		if courseplay:distanceToPoint(self.combineToUnload,self.lastCombinesCoords.x,self.lastCombinesCoords.y,self.lastCombinesCoords.z) > 30 then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
		end

		--if we are in range , change to drive directly
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.rootNode)
		if courseplay:distanceToPoint(self.vehicle,cx,cy,cz) < 50 then
			self:setNewOnFieldState(self.states.GET_ALIGNCOURSE_TO_COMBINE)
		end
		self.ppc:setOffset(3, 0)
		-- maybe do obstacle avoiding
	elseif self.onFieldState == self.states.GET_ALIGNCOURSE_TO_COMBINE then
		self.ppc:setOffset(0, 0)
		if courseplay:isChopper(self.combineToUnload) then
			self.combineOffset = self:getChopperOffset(self.combineToUnload)
		else
			self.combineOffset = self:getCombineOffset(self.combineToUnload)
		end
		local tempCourseToAlign = self:getCourseToAlignTo(self.combineToUnload)
		if tempCourseToAlign ~= nil then
			self:startCourseWithAlignment(tempCourseToAlign, 1)
			self:setNewOnFieldState(self.states.ALIGN_TO_COMBINE)
		end
	elseif self.onFieldState == self.states.ALIGN_TO_COMBINE then
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_DRIVE_BEHIND_COMBINE");
		--do nothing just drive

	elseif self.onFieldState == self.states.FOLLOW_COMBINE then
		if courseplay:isChopper(self.combineToUnload) then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER )
			return
		end

		local targetNode = self:getTrailersTargetNode()
		local leftOK = g_combineUnloadManager:getPossibleSidesToDrive(self.combineToUnload)
		if leftOK then
			self:driveBesideCombine(dt,targetNode)
		else
			self:driveBehindCombine(dt)
			if self.combineToUnload.cp.driver.ppc:isReversing() then
				local reverseCourse = self:getStraightReverseCourse()
				AIDriver.startCourse(self,reverseCourse,1)
				self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_COMBINE_NOTURN)
			end
		end
		if self:getCombinesFillLevelPercent() == 0 then
			print("combine empty, set self:setNewOnFieldState(self.states.FIND_COMBINE)")
			self:setNewOnFieldState(self.states.FIND_COMBINE)
		end
		if self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.HANDLE_COMBINE_TURN)
			print("combine is turning")
		end

		return
	elseif self.onFieldState == self.states.HANDLE_COMBINE_TURN then
		if not self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
		end
		self:hold()

	elseif self.onFieldState == self.states.FOLLOW_CHOPPER then
		if g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) > 1 then
			self:setNewOnFieldState(self.states.FOLLOW_TRACTOR)
		end

		--get target node and check whether trailers are full
		local targetNode = self:getTrailersTargetNode()

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
		if self:getTractorsFillLevelPercent() >90 and self:getChopperOffset(self.combineToUnload) ~= 0 then
			self:setNewOnFieldState(self.states.DRIVE_BESIDE_TRACTOR)
		end

		if g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) == 1 then
			self:setNewOnFieldState(self.states.FOLLOW_CHOPPER)
		end

		self:setSavedCombineOffset(self.tractorToFollow.cp.combineOffset)
		if self:getCombineIsTurning() then
			self:hold()
		end


		if self.tractorToFollow.cp.driver.ppc:isReversing() then
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
		if self.combineToUnload.cp.driver.ppc:isReversing() then
			local reverseCourse = self:getStraightReverseCourse()
			AIDriver.startCourse(self,reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER )
		end

		if self.combineToUnload.cp.turnStage ~= nil then
			if self.combineToUnload.cp.turnStage> 1 then
				if self:getFillLevelPercent() > self:getDriveOnThreshold() then
					local reverseCourse = self:getStraightReverseCourse()
					AIDriver.startCourse(self,reverseCourse,1)
					self:setNewOnFieldState(self.states.DRIVE_STRAIGHTBACK_FULL)
					return
				end
				self:setNewOnFieldState(self.states.WAIT_FOR_CHOPPER_TURNED)
			end
		end

		if self.combineOffset ~= 0 then
			local z = self:getZOffsetToCoordsBehind()
			local dirSelfX,_,dirSelfZ = localDirectionToWorld(self:getDirectionNode(),0,0,1)
			local dirCombineX = localDirectionToWorld(self.combineToUnload.cp.DirectionNode,0,0,1)
			local savedOffset = self:getSavedCombineOffset()
			--print(string.format("vehicle.rotatedTime:%s",tostring(self.combineToUnload.rotatedTime)))

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
		self:releaseUnloader()
		g_combineUnloadManager:leaveField(self.vehicle)
	elseif self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
		self.ppc:setOffset(3, 0)
		-- maybe do obstacle avoiding
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
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			self:recoverOriginalWaypoints()
		end
		if g_combineUnloadManager:getNumUnloaders(self.combineToUnload) >1
			and g_combineUnloadManager:getUnloadersNumber(self.vehicle, self.combineToUnload) == 1
			and self:getChopperOffset(self.combineToUnload) ~= 0 then
			if not self:getCombineIsTurning() then
				self:hold()
			else
				self.combineToUnload.cp.driver:hold()
			end
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_TURNINGCHOPPER then
		local z = self:getZOffsetToCoordsBehind()
		if z > 5 then
			self:setNewOnFieldState(self.states.HANDLE_CHOPPER_TURN)
			self:recoverOriginalWaypoints()
		else
			self.combineToUnload.cp.driver:hold()
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_CHOPPER then
		renderText(0.2,0.195,0.02,string.format("drive straight reverse :offset local :%s saved:%s",tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
		local dx,dy,dz = self.course:getWaypointLocalPosition(self:getDirectionNode(), 1)
		if dz > 15 then
			self:hold()
		else
			local z = self:getZOffsetToCoordsBehind()
			if z < 5 then
				self.combineToUnload.cp.driver:hold()
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
			self.combineToUnload.cp.driver:hold()
		end
		if not self.combineToUnload.cp.driver.ppc:isReversing() then
			print("not reversing: self:setNewOnFieldState(self.states.FOLLOW_COMBINE)")
			self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
			self:recoverOriginalWaypoints()
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHTBACK_FROM_REVERSING_TRACTOR then
		if not self.tractorToFollow.cp.driver.ppc:isReversing() then
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

function CombineUnloadAIDriver:getRecordedSpeed()
	-- default is the street speed (reduced in corners)
	if self.state == self.combineUnloadState == self.states.ONSTREET then
		local speed = self:getDefaultStreetSpeed(self.ppc:getCurrentWaypointIx()) or self.vehicle.cp.speeds.street
		if self.vehicle.cp.speeds.useRecordingSpeed then
			-- use default street speed if there's no recorded speed.
			speed = math.min(self.course:getAverageSpeed(self.ppc:getCurrentWaypointIx(), 4) or speed, speed)
		end
		--course end
		if self.ppc:getCurrentWaypointIx()+3 >= Course:getNumberOfWaypoints() then
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
	if not isBeside then
		speed = self:getSpeedBehindCombine()
	end
	self:setSavedCombineOffset(self.combineOffset)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end


function CombineUnloadAIDriver:driveBesideChopper(dt,targetNode)
	renderText(0.2,0.135,0.02,string.format("%s: driveBesideCombine:offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
	local allowedToDrive = true
	local fwd = true
	--get required Speed
	local speed = 0
	speed, allowedToDrive = self:getSpeedBesideChopper(targetNode)
	--get direction to drive to
	local gx,gy,gz,isBeside = self:getDrivingCoordsBeside()
	local z = self:getZOffsetToCoordsBehind()
	if not isBeside and z > -2 then
		speed = self:getSpeedBehindChopper()
		if z < 0 and self.distanceToCombine <2 then
			print("STOOOOOOP")
			allowedToDrive = false
		end
	else
		self:setSavedCombineOffset(self.combineOffset)
	end
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end


function CombineUnloadAIDriver:driveBehindChopper(dt)
	renderText(0.2,0.165,0.02,string.format("%s: driveBehindCombine offset local :%s saved:%s",nameNum(self.vehicle),tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
	local allowedToDrive = true
	local fwd = true
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBehind(self.combineToUnload)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	--get required Speed
	local speed = self:getSpeedBehindChopper()

	--I'm not behind the combine and have to wait till i can get behind it
	local z = self:getZOffsetToCoordsBehind()
	if z < 0 and self.distanceToCombine <3 then
		--print("STOOOOOOP")
		allowedToDrive = false
	else
		self:setSavedCombineOffset(self.combineOffset)
	end

	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
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



	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
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
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
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
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
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
			if self.ppc:getOffset() ~= 0 then
				self.ppc:setOffset(0, 0)
			end
		elseif self.onFieldState == self.states.ALIGN_TO_COMBINE then
			self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
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


function CombineUnloadAIDriver:getCourseToAlignTo(combine)
	local waypoints = {}
	for i=-15,20,5 do
		local x,y,z = localToWorld(combine.rootNode,self.combineOffset,0,i)
		local point = { cx = x;
						cy = y;
						cz = z;
						}
		table.insert(waypoints,point)
	end
	local tempCourse = Course(self.vehicle,waypoints)

--[[   1 :: table: 0x02a609433738
--2019-08-31 19:34       ridgeMarker :: 0
--2019-08-31 19:34       dirX :: -0.023623896329334
--2019-08-31 19:34       cx :: 50.34
--2019-08-31 19:34       speed :: 40
--2019-08-31 19:34       rotY :: -3.1179665457138
--2019-08-31 19:34       dirZ :: -0.9997203401186
--2019-08-31 19:34       angle :: -178.64632373239
--2019-08-31 19:34       unload :: false
--2019-08-31 19:34       rev :: false
--2019-08-31 19:34       turnStart :: false
--2019-08-31 19:34       distToNextPoint :: 9.3126043618313
--2019-08-31 19:34       turnEnd :: false
--2019-08-31 19:34       rotX :: -0.0010738136758804
--2019-08-31 19:34       cy :: 112.57
--2019-08-31 19:34       crossing :: true
--2019-08-31 19:34       cz :: 117.15
--2019-08-31 19:34       dirY :: 0.0010738134695157
--2019-08-31 19:34       wait :: false]]
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
			local combineFillType = self.combineToUnload and self.combineToUnload:getFillUnitLastValidFillType(self.combineToUnload:getCurrentDischargeNode().fillUnitIndex) or 0
			if tipper:getFillUnitFreeCapacity(j) > 0 then
				allTrailersFull = false
				if (tipperFillType == FillType.UNKNOWN or tipperFillType == combineFillType) then
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

	local lx,lz = AIVehicleUtil.getDriveDirection(self.combineToUnload.cp.DirectionNode, tx,ty,tz);
	if self.combineOffset > 0 then
		lx = math.max(0.25,lx)
	else
		lx = math.min(-0.25,lx)
	end
	local nx,ny,nz = localDirectionToWorld(self.combineToUnload.cp.DirectionNode, lx, 0, lz)
	local cx,cy,cz = getWorldTranslation(self.combineToUnload.cp.DirectionNode)
	local x,y,z = cx+(nx*math.abs(self.combineOffset)),cy,cz+(nz*math.abs(self.combineOffset))
	local offsetDifference = self.combineOffset - sideShift
	local isBeside = math.abs(offsetDifference) < 0.5

	if lz >0 or isBeside then
		x,y,z = localToWorld(self.combineToUnload.cp.DirectionNode,self.combineOffset,0,backShift)
	end
	cpDebug:drawLine(cx,cy+1,cz,100,100,100,x,y+1,z)
	return x,y,z,isBeside
end

function CombineUnloadAIDriver:getDrivingCoordsBehind()
	local x,y,z = localToWorld(self.combineToUnload.cp.DirectionNode,0,0, - (self:getCombinesMeasuredBackDistance()))

	--just Debug
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local sx,sy,sz = getWorldTranslation(colliNode)
	cpDebug:drawLine(sx,sy,sz, 100, 100, 100, x,sy,z)
	--

	return x,y,z
end

function CombineUnloadAIDriver:getDrivingCoordsBehindTractor(tractorToFollow)
	local tx,ty,tz = localToWorld(tractorToFollow.cp.DirectionNode,0,0,-30)
	return tx,ty,tz
end

function CombineUnloadAIDriver:getDrivingCoordsBesideTractor(tractorToFollow)
	local offset = self:getChopperOffset(self.combineToUnload)
	local sx,sy,sz = localToWorld(self:getDirectionNode(),0,0,7)
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
	renderText(0.2,0.225,0.02,string.format("dz:%s",tostring(dz)))
	if dz < -1 then
		allowedToDrive = false
	end
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(dz,-10,35)),allowedToDrive
end

function CombineUnloadAIDriver:getSpeedBehindCombine()
	if self.distanceToFront == nil then
		self:raycastFront()
		return
	else
		self:raycastDistance(30)
	end
	local targetGap = 20
	local targetDistance = self.distanceToCombine - targetGap
	renderText(0.2,0.195,0.02,string.format("self.distanceToCombine:%s, targetDistance:%s speed:%s",tostring(self.distanceToCombine),tostring(targetDistance),tostring((self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15)))))
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15))
end

function CombineUnloadAIDriver:getSpeedBehindChopper()
	if self.distanceToFront == nil then
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

function CombineUnloadAIDriver:getTotalLength()
	return self.vehicle.cp.totalLength
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
	local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1.5, 10)
	raycastAll(x, y, z, nx, ny, nz, 'raycastFrontCallback', 10, self)
end

function CombineUnloadAIDriver:raycastFrontCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and object == self.vehicle and self.distanceToFront == nil then
			self.distanceToFront = 10 - distance
			local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
			local nx,ny,nz = getWorldTranslation(colliNode)
			local _,_,sz = worldToLocal(self:getDirectionNode(),nx,ny,nz)
			local Tx,Ty,Tz = getTranslation(colliNode,self:getDirectionNode());
			print(string.format("self.distanceToFront(%s) = 10 - distance(%s)",tostring(self.distanceToFront),tostring(distance)))
			if sz < self.distanceToFront+ 0.8 then
				setTranslation(colliNode, Tx,Ty,Tz+(self.distanceToFront+ 0.8-sz))
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
end
