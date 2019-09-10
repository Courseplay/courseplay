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
	ALIGN_TO_COMBINE = {},
	GET_ALIGNCOURSE_TO_COMBINE ={},
	FOLLOW_COMBINE ={},
	FOLLOW_CHOPPER ={},
	PREPARE_TURN ={},
	DRIVE_TURN ={},
	DRIVE_STRAIGHT_FROM_REVERSINGCOMBINE = {},
	DRIVE_STRAIGHT_FROM_TURNINGCOMBINE = {},
	HANDLE_COMBINE_TURN ={}
}

--- Constructor
function CombineUnloadAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_COMBI
	self:initStates(CombineUnloadAIDriver.myStates)
	self.combineUnloadState =self.states.ONSTREET
	self:setHudContent()
	self:setNewOnFieldState(self.states.FIND_COMBINE)
	self.combineOffset = 0
end

function CombineUnloadAIDriver:setHudContent()
	courseplay.hud:setCombineUnloadAIDriverContent(self.vehicle)
end

function CombineUnloadAIDriver:start(ix)
	AIDriver.start(self, ix)
	local x,_,z = getWorldTranslation(self:getDirectionNode())
	if courseplay:isField(x, z) then
		self.combineUnloadState = self.states.ONFIELD
		self:setNewOnFieldState(self.states.FIND_COMBINE)
		self:disableCollisionDetection()
	end
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
	if self.onFieldState == self.states.FIND_COMBINE then
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_NO_COMBINE_IN_REACH");

		self.combineToUnload = g_combineUnloadManager:giveMeACombineToUnload(self.vehicle)
		if self.combineToUnload ~= nil then
			--print("combine set")
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
		else
			--print("no combine")
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


		-- maybe do obstacle avoiding
	elseif self.onFieldState == self.states.GET_ALIGNCOURSE_TO_COMBINE then
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
		end

	elseif self.onFieldState == self.states.FOLLOW_CHOPPER then
		--get target node and check whether trailers are full
		local targetNode,allTrailersFull = self:getTrailersTargetNode()
		if allTrailersFull then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			return
		end
		self.combineOffset = self:getChopperOffset(self.combineToUnload)

		if self.combineOffset ~= 0 then
			self:driveBesideCombine(dt,targetNode)
		else
			self:driveBehindChopper(dt)
		end

		if self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.HANDLE_COMBINE_TURN)
			print("combine is turning")
		end
		return


	elseif self.onFieldState == self.states.HANDLE_COMBINE_TURN then
		if self.combineToUnload.cp.driver.ppc:isReversing() then
			local reverseCourse = self:getStraightReverseCourse()
			AIDriver.startCourse(self,reverseCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHT_FROM_REVERSINGCOMBINE)
		end

		if self.combineOffset ~= 0 then
			local z = self:getZOffsetToCoordsBehind()
			local dirSelfX,_,dirSelfZ = localDirectionToWorld(self:getDirectionNode(),0,0,1)
			local dirCombineX = localDirectionToWorld(self.combineToUnload.cp.DirectionNode,0,0,1)
			local savedOffset = self:getSavedCombineOffset()
			--print(string.format("vehicle.rotatedTime:%s",tostring(self.combineToUnload.rotatedTime)))

			if z < 0
				and ((savedOffset <0 and self.combineToUnload.rotatedTime < 0.5)
				or (savedOffset > 0 and self.combineToUnload.rotatedTime > 0.5))then
				--print(string.format("vehicle.rotatedTime:%s z:%s; offset:%s; dirSelfX:%s; dirSelfZ:%s; dirCombine:%s ",tostring(self.combineToUnload.rotatedTime) ,tostring(z),tostring(savedOffset),tostring(dirSelfX),tostring(dirSelfZ),tostring(dirCombineX)))
				if savedOffset <0 and self.combineToUnload.rotatedTime < 0.5 then
					print("turns right, I'm right")
				else
					print("turns left, I'm left")
				end

				local reverseCourse = self:getStraightReverseCourse()
				AIDriver.startCourse(self,reverseCourse,1)
				self:setNewOnFieldState(self.states.DRIVE_STRAIGHT_FROM_TURNINGCOMBINE)
				self.combineOffset = 0
				return
			end
			local targetNode,allTrailersFull = self:getTrailersTargetNode()
			self:driveBesideCombine(dt,targetNode)
		else
			self:driveBehindChopper(dt)
		end

		if not self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
		end
		return


	elseif self.onFieldState == self.states.FINDPATH_TO_COURSE then
		if self:startCourseWithPathfinding(self.mainCourse, 1) then
			self:setNewOnFieldState(self.states.DRIVE_TO_UNLOADCOURSE)
		end
	elseif self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
		--do nothing just drive
		-- maybe do obstacle avoiding
	elseif self.onFieldState == self.states.PREPARE_TURN then
	elseif self.onFieldState == self.states.DRIVE_STRAIGHT_FROM_TURNINGCOMBINE then
		local z = self:getZOffsetToCoordsBehind()
		if z > 5 then
			self:setNewOnFieldState(self.states.HANDLE_COMBINE_TURN)
			self:recoverOriginalWaypoints()
		else
			self.combineToUnload.cp.driver:hold()
		end
	elseif self.onFieldState == self.states.DRIVE_STRAIGHT_FROM_REVERSINGCOMBINE then
		renderText(0.2,0.195,0.02,string.format("drive straight reverse :offset local :%s saved:%s",tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
		local dx,dy,dz = self.combineToUnload.cp.driver.course:getWaypointLocalPosition(self:getDirectionNode(), 4)
		if dz > 15 then
			self:hold()
		else
			self.combineToUnload.cp.driver:hold()
		end
		if not self.combineToUnload.cp.driver.ppc:isReversing() then
			self:setNewOnFieldState(self.states.HANDLE_COMBINE_TURN)
			self:recoverOriginalWaypoints()
		end
	end
	AIDriver.drive(self, dt)
end


function CombineUnloadAIDriver:driveBesideCombine(dt,targetNode)
	renderText(0.2,0.135,0.02,string.format("driveBesideCombine:offset local :%s saved:%s",tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
	local allowedToDrive = true
	local fwd = true
	--get required Speed
	local speed = self:getSpeedBesideCombine(targetNode)
	--get direction to drive to
	local gx,gy,gz,isBeside = self:getDrivingCoordsBeside()
	if not isBeside then
		speed = self:getSpeedBehindCombine()
	else
		self:setSavedCombineOffset(self.combineOffset)
	end
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function CombineUnloadAIDriver:driveBehindChopper(dt)
	renderText(0.2,0.165,0.02,string.format("driveBehindCombine offset local :%s saved:%s",tostring(self.combineOffset),tostring(self.vehicle.cp.combineOffset)))
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


function CombineUnloadAIDriver:onEndCourse()
	if self.combineUnloadState == self.states.ONSTREET then
		self.combineUnloadState = self.states.ONFIELD
		courseplay:openCloseCover(self.vehicle, not courseplay.SHOW_COVERS)
		self:disableCollisionDetection()
	end


end

function CombineUnloadAIDriver:onLastWaypoint()
	if self.combineUnloadState == self.states.ONFIELD then
		if self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
			self.combineUnloadState = self.states.ONSTREET
			self:setNewOnFieldState(self.states.FIND_COMBINE)
			self:enableCollisionDetection()
			courseplay:openCloseCover(self.vehicle, courseplay.SHOW_COVERS)
		elseif self.onFieldState == self.states.ALIGN_TO_COMBINE then
			self:setNewOnFieldState(self.states.FOLLOW_COMBINE)
		end


	end
	AIDriver.onLastWaypoint(self)
end

function CombineUnloadAIDriver:setNewOnFieldState(newState)
	self.onFieldState = newState
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
	print("called CombineUnloadAIDriver:getStraightReverseCourse()")
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

		tipper.spec_fillUnit.fillUnits[1].fillLevel =100

		local fillUnits = tipper:getFillUnits()
		for j=1,#fillUnits do
			local tipperFillType = tipper:getFillUnitFillType(j)
			local combineFillType = self.combineToUnload:getFillUnitLastValidFillType(self.combineToUnload:getCurrentDischargeNode().fillUnitIndex)
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
		lx = math.max(-0.01,lx)
	else
		lx = math.min(0.01,lx)
	end
	local nx,ny,nz = localDirectionToWorld(self.combineToUnload.cp.DirectionNode, lx, 0, lz)
	local cx,cy,cz = getWorldTranslation(self.combineToUnload.cp.DirectionNode)
	local x,y,z = cx+(nx*math.abs(self.combineOffset)),cy,cz+(nz*math.abs(self.combineOffset))
	local offsetDifference = self.combineOffset - sideShift
	local isBeside = math.abs(offsetDifference) < 0.5

	if lz >0 or isBeside then
		x,y,z = localToWorld(self.combineToUnload.cp.DirectionNode,self.combineOffset,0,backShift)
	end
	cpDebug:drawLine(cx,cy+1,cz,100,100,100,x,y,z)
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

function CombineUnloadAIDriver:getZOffsetToCoordsBehind()
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local sx,sy,sz = getWorldTranslation(colliNode)
	local _,_,z = worldToLocal(self.combineToUnload.cp.DirectionNode,sx,sy,sz)
	return -(z + self:getCombinesMeasuredBackDistance())
end

function CombineUnloadAIDriver:getSpeedBesideCombine(targetNode)
	local baseNode = self:getPipesBaseNode(self.combineToUnload).node
	local dnX,dnY,dnZ = getWorldTranslation(baseNode)
	--Discharge Node to AutoAimNode
	local wx,wy,wz = getWorldTranslation(targetNode)
	--cpDebug:drawLine(dnX,dnY,dnZ, 100, 100, 100, wx,wy,wz)

	local _,_,dz = worldToLocal(targetNode,dnX,dnY,dnZ)
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(dz,-10,15))
end

function CombineUnloadAIDriver:getSpeedBehindCombine()
	if self.distanceToFront == nil then
		self:raycastFront()
		return
	else
		self:raycastDistance()
	end
	local targetGap = 0.5
	local targetDistance = self.distanceToCombine - targetGap
	return (self.combineToUnload.lastSpeedReal * 3600) +(MathUtil.clamp(targetDistance,-10,15))
end


function CombineUnloadAIDriver:getPipesBaseNode(combine)
	for i=1,#combine.spec_pipe.nodes do
		local node = combine.spec_pipe.nodes[i]
		if node.autoAimYRotation then
			return node
		end
	end
end

function CombineUnloadAIDriver:getTotalLength()
	return self.vehicle.cp.totalLength
end

function CombineUnloadAIDriver:getCombineIsTurning()
	return self.combineToUnload.cp.driver and self.combineToUnload.cp.driver.turnIsDriving or self.combineToUnload.cp.driver.fieldworkState == self.combineToUnload.cp.driver.states.TURNING
end

function CombineUnloadAIDriver:getCombineIsOnConnectionTrack()
	return self.combineToUnload.cp.driver and self.combineToUnload.cp.driver.fieldworkState == self.combineToUnload.cp.driver.states.ON_CONNECTING_TRACK
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
	local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, 0, 0, -1)
	local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1.5, 10)
	raycastAll(x, y, z, nx, ny, nz, 'raycastFrontCallback', 10, self)
end

function CombineUnloadAIDriver:raycastFrontCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and object == self.vehicle and self.distanceToFront == nil then
			self.distanceToFront = 10 - distance
			print(string.format("self.distanceToFront(%s) = 15 - distance(%s)",tostring(self.distanceToFront),tostring(distance)))
		else
			return true
		end
	end
end

function CombineUnloadAIDriver:raycastDistance()
	self.distanceToCombine = math.huge
	local colliNode = self.vehicle.cp.driver.collisionDetector.trafficCollisionTriggers[1]
	local nodeX, nodeY, nodeZ = getWorldTranslation(colliNode)
	local gx,gy,gz = self:getDrivingCoordsBehind(self.combineToUnload)
	local lx,lz =  AIVehicleUtil.getDriveDirection(colliNode, gx,gy,gz)
	local nx, ny, nz = localDirectionToWorld(colliNode, lx, 0, lz)
	local distance = 10
	--cpDebug:drawLine(nodeX, nodeY, nodeZ, 100, 100, 100, nodeX+(nx*distance), nodeY+(ny*distance), nodeZ+(nz*distance))
	raycastClosest(nodeX, nodeY, nodeZ, nx, ny, nz, 'raycastDistanceCallback', distance, self)
end

function CombineUnloadAIDriver:raycastDistanceCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and object== self.combineToUnload then
			cpDebug:drawPoint(x, y, z, 1, 1 , 1);
			self.distanceToCombine = distance
		else
			return true
		end
	end
end

function CombineUnloadAIDriver:getCombinesMeasuredBackDistance()
	return g_combineUnloadManager:getCombinesMeasuredBackDistance(self.combineToUnload)
end