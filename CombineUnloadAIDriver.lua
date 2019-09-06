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
	PREPARE_TURN ={},
	DRIVE_TURN ={},
	DRIVE_STRAIGHT_REVERSE = {},
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
end

function CombineUnloadAIDriver:setHudContent()
	courseplay.hud:setCombineUnloadAIDriverContent(self.vehicle)
end

function CombineUnloadAIDriver:start(ix)
	AIDriver.start(self, ix)
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
		self.combineToUnload = g_combineUnloadManager:giveMeACombineToUnload()
		if self.combineToUnload ~= nil then
			--print("combine set")
			self.vehicle.cp.combineOffset = self:getCombineOffset(self.combineToUnload)
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
			self:updateCombineStatus()
			self.lastCombinesCoords = { x=cx;
										y=cy;
										z=cz;
			}
		end

	elseif self.onFieldState == self.states.DRIVE_TO_COMBINE then
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
		local tempCourseToAlign = self:getCourseToAlignTo(self.combineToUnload)
		if tempCourseToAlign ~= nil then
			self:startCourseWithAlignment(tempCourseToAlign, 1)
			self:setNewOnFieldState(self.states.ALIGN_TO_COMBINE)
		end


	elseif self.onFieldState == self.states.ALIGN_TO_COMBINE then
		--do nothing just drive
	elseif self.onFieldState == self.states.FOLLOW_COMBINE then
		--get target node and check whether trailers are full
		local targetNode,allTrailersFull = self:getTrailersTargetNode()
		if allTrailersFull then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			return
		end

		if self:canGoUnloadingBeside() then
			self:driveBesideCombine(dt,targetNode)
		else
			self:driveBehindCombine(dt)
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
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHT_REVERSE)
		end

		if self:canGoUnloadingBeside() then
			--turn beside Combine

		else
			self:driveBehindCombine(dt)
		end

		if not self:getCombineIsTurning() then
			self:updateCombineStatus()
			self.vehicle.cp.combineOffset = self:getCombineOffset(self.combineToUnload)
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
	elseif self.onFieldState == self.states.DRIVE_TURN then
	elseif self.onFieldState == self.states.DRIVE_STRAIGHT_REVERSE then
		if self.combineToUnload.cp.driver.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, 4) >15 then
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
function CombineUnloadAIDriver:canGoUnloadingBeside()
	return g_combineUnloadManager:getCanBeUnloadedBeside(self.combineToUnload)
end

function CombineUnloadAIDriver:updateCombineStatus()
	g_combineUnloadManager:updateOnFieldSituation(self.combineToUnload)
end

function CombineUnloadAIDriver:driveBesideCombine(dt,targetNode)
	local allowedToDrive = true
	local fwd = true
	--get required Speed
	local speed = self:getSpeedBesideCombine(targetNode)

	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBeside()
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end

function CombineUnloadAIDriver:driveBehindCombine(dt)
	local allowedToDrive = true
	local fwd = true
	--get required Speed
	local speed = self:getSpeedBehindCombine()
	--get direction to drive to
	local gx,gy,gz = self:getDrivingCoordsBehind(self.combineToUnload)
	local lx,lz = AIVehicleUtil.getDriveDirection(self.vehicle.cp.DirectionNode, gx,gy,gz);
	--get required Speed
	local speed = self:getSpeedBehindCombine()
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
		local x,y,z = localToWorld(combine.rootNode,self.vehicle.cp.combineOffset,0,i)
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
	local x,y,z = localToWorld(self.combineToUnload.rootNode,self.vehicle.cp.combineOffset,0,self:getTotalLength())
	return x,y,z
end

function CombineUnloadAIDriver:getDrivingCoordsBehind()
	local x,y,z = localToWorld(self.combineToUnload.rootNode,0,0,-3)
	return x,y,z
end

function CombineUnloadAIDriver:getSpeedBesideCombine(targetNode)
	local baseNode = self:getPipesBaseNode(self.combineToUnload).node
	local dnX,dnY,dnZ = getWorldTranslation(baseNode)

	--Discharge Node to AutoAimNode
	local wx,wy,wz = getWorldTranslation(targetNode)
	cpDebug:drawLine(dnX,dnY,dnZ, 100, 100, 100, wx,wy,wz)

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
	return self.combineToUnload.cp.driver.turnIsDriving or self.combineToUnload.cp.driver.fieldworkState == self.combineToUnload.cp.driver.states.TURNING
end

function CombineUnloadAIDriver:getCombineOffset(combine)
	if self.vehicle.cp.combineOffsetAutoMode then
		local newOffset = g_combineUnloadManager:getUnloadSideOffset(combine)
		print("self.vehicle.cp.combineOffset = "..tostring(newOffset))
		self:refreshHUD()
		return newOffset
	else
		print("self.vehicle.cp.combineOffset = "..tostring(self.vehicle.cp.combineOffset))
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
	local distance = 20

	cpDebug:drawLine(nodeX, nodeY, nodeZ, 100, 100, 100, nodeX+(nx*distance), nodeY+(ny*distance), nodeZ+(nz*distance))
	raycastClosest(nodeX, nodeY, nodeZ, nx, ny, nz, 'raycastDistanceCallback', distance, self)
end

function CombineUnloadAIDriver:raycastDistanceCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object then
			self.distanceToCombine = distance
		end
	end
end
