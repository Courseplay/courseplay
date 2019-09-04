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
	DRIVE_STRAIGHT_REVERSE = {}
}

--- Constructor
function CombineUnloadAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_COMBI
	self:initStates(CombineUnloadAIDriver.myStates)
	self.combineUnloadState =self.states.ONSTREET
	self:setHudContent()
	self:setNewOnFieldState(self.states.DRIVE_TURN) --FIND_COMBINE)
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
			if self.vehicle.cp.combineOffsetAutoMode then
				self.vehicle.cp.combineOffset = self:getCombineOffset(self.combineToUnload)
				self:refreshHUD()
			end
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
		local allowedToDrive = true
		local fwd = true
		--get target node and check whether trailers are full
		local targetNode,allTrailersFull = self:getTrailersTargetNode()
		if allTrailersFull then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COURSE)
			return
		end

		if false then
			self:driveBesideCombine(dt,targetNode)
		else
			self:driveBehindCombine(dt)
		end

		if self:getCombineIsTurning() then
			self:setNewOnFieldState(self.states.PREPARE_TURN)
			print("combine is turning")
		end

		if self.combineToUnload.cp.driver.ppc:isReversing() then
			print("combine is reversing")
			local tempCourse = self:getStraightReverseCourse()
			AIDriver.startCourse(self,tempCourse,1)
			self:setNewOnFieldState(self.states.DRIVE_STRAIGHT_REVERSE)
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
		self:hold()
		if not self:getCombineIsTurning() then
			self.vehicle.cp.combineOffset = self:getCombineOffset(self.combineToUnload)
			local tempCourseToAlign = self:getCourseToAlignTo(self.combineToUnload)
			if tempCourseToAlign ~= nil then
				self:startCourseWithAlignment(tempCourseToAlign, 1)
			end
			if self.course:getAllPointsAreOnField() then
				self:setNewOnFieldState(self.states.ALIGN_TO_COMBINE)
			else


			end
		end
	elseif self.onFieldState == self.states.DRIVE_TURN then
		local tempCourse = self:getStraightReverseCourse()
		AIDriver.startCourse(self,tempCourse,1)
		self:setNewOnFieldState(self.states.DRIVE_STRAIGHT_REVERSE)

	elseif self.onFieldState == self.states.DRIVE_STRAIGHT_REVERSE then
		--self.combineToUnload.cp.driver:hold()

	end
	AIDriver.drive(self, dt)

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
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
end


function CombineUnloadAIDriver:onEndCourse()
	if self.combineUnloadState == self.states.ONSTREET then
		self.combineUnloadState = self.states.ONFIELD
		courseplay:openCloseCover(self.vehicle, not courseplay.SHOW_COVERS)
	end


end
function CombineUnloadAIDriver:onLastWaypoint()
	if self.combineUnloadState == self.states.ONFIELD then
		if self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
			self.combineUnloadState = self.states.ONSTREET
			self:setNewOnFieldState(self.states.FIND_COMBINE)
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
	-- all we need is a waypoint on our right side towards the back
	self.returnPoint = {}
	self.returnPoint.x, _, self.returnPoint.z = getWorldTranslation(self.vehicle.rootNode)

	local dx,_,dz = localDirectionToWorld(self:getDirectionNode(), 0, 0, 1)
	self.returnPoint.rotation = MathUtil.getYRotationFromDirection(dx, dz)
	dx,_,dz = localDirectionToWorld(self:getDirectionNode(), 0, 0, -1)
	local reverseRotation = MathUtil.getYRotationFromDirection(dx, dz)

	local x1, _, z1 = localToWorld(self:getDirectionNode(), 0, 0, -30)
	local x2, _, z2 = localToWorld(self:getDirectionNode(), 0, 0, -35)
	-- both points must be on the field
	--if courseplay:isField(x1, z1) and courseplay:isField(x2, z2) then
		local vx, _, vz = getWorldTranslation(self:getDirectionNode())
		self:debug('%.2f %.2f %d %d', self.returnPoint.rotation, reverseRotation, math.deg(self.returnPoint.rotation), math.deg(reverseRotation))
		local pullBackWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, vx, vz, x1, z1, reverseRotation, true)
		if not pullBackWaypoints then
			self:debug("Can't create alignment course for pull back")
			return nil
		end
		table.insert(pullBackWaypoints, {x = x2, z = z2})
		-- this is the backing up part, so make sure we are reversing here
		for _, p in ipairs(pullBackWaypoints) do
			p.rev = true
		end
		return Course(self.vehicle, pullBackWaypoints, true)
	--else
	--	self:debug("Pull back course would be outside of the field")
	--	return nil
	--end
end

function CombineUnloadAIDriver:getFieldNumber()
	local positionX,_,positionZ = getWorldTranslation(self.vehicle.cp.DirectionNode or self.vehicle.rootNode);
	return self:getFieldNumForPosition( positionX, positionZ )
end

function CombineUnloadAIDriver:getFieldNumForPosition( positionX, positionZ )
	local fieldNum = 0;
	for index, field in pairs(courseplay.fields.fieldData) do
		if positionX >= field.dimensions.math.minX and positionX <= field.dimensions.math.maxX and positionZ >= field.dimensions.math.minZ and positionZ <= field.dimensions.math.maxZ then
			local _, pointInPoly, _, _ = courseplay.fields:getPolygonData(field.points, positionX, positionZ, true, true, true);
			if pointInPoly then
				fieldNum = index
				break
			end
		end
	end
	return fieldNum
end

function CombineUnloadAIDriver:getTrailersTargetNode()
	local allTrailersFull = true
	for i=1,#self.vehicle.cp.workTools do
		local tipper = self.vehicle.cp.workTools[i]
		local fillUnits = tipper:getFillUnits()
		for j=1,#fillUnits do
			local tipperFillType = tipper:getFillUnitFillType(j)
			local combineFillType = self.combineToUnload:getFillUnitLastValidFillType(self.combineToUnload:getCurrentDischargeNode().fillUnitIndex)
			if tipper:getFillUnitFreeCapacity(j) > 0 then
				allTrailersFull = false
				if (tipperFillType == FillType.UNKNOWN or tipperFillType == combineFillType) then
					local targetNode = tipper:getFillUnitAutoAimTargetNode(1)
					if targetNode ~= nil then
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
	local x,y,z = localToWorld(self.combineToUnload.rootNode,0,0,self:getTotalLength())
	return x,y,z
end

function CombineUnloadAIDriver:getSpeedBesideCombine(targetNode)
	local baseNode = self:getPipesBaseNode(self.combineToUnload).node
	local dnX,dnY,dnZ = getWorldTranslation(baseNode)

	--Discharge Node to AutoAimNode
	local wx,wy,wz = getWorldTranslation(targetNode)
	cpDebug:drawLine(dnX,dnY,dnZ, 100, 100, 100, wx,wy,wz)

	local _,_,dz = worldToLocal(targetNode,dnX,dnY,dnZ)
	return (combine.lastSpeedReal * 3600) +(MathUtil.clamp(dz,-10,15))
end

function CombineUnloadAIDriver:getSpeedBehindCombine()
	if self.distanceToFront == nil then
		self:raycastFront()
		return
	else
		self:raycastDistance()
	end
	local targetGap = 1
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
	return self.combineToUnload.cp.driver.turnIsDriving
end

function CombineUnloadAIDriver:getCombineOffset(combine)
	if courseplay:isChopper(combine) then
		local offset = (combine.cp.workWidth/2)+2.5
		local fruitSide = courseplay:sideToDrive(self.vehicle, combine, 5);
		--if fruitSide == "right" then
		--	return offset
		--elseif fruitSide == "left" then
		--	return -offset
		--else
			return 0
		--end
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
	local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, 0, 0, 1)
	local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1, self.distanceToFront+0.5)
	local distance = 20

	cpDebug:drawLine(x, y, z, 100, 100, 100, x+(nx*distance), y+(ny*distance), z+(nz*distance))
	raycastClosest(x, y, z, nx, ny, nz, 'raycastDistanceCallback', distance, self)
end

function CombineUnloadAIDriver:raycastDistanceCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object then
			print("distance= "..tostring(distance))
			self.distanceToCombine = distance
		end
	end
end