--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Courseplay Dev team

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

---@class ShovelAIDriver : BunkerSiloAIDriver
ShovelAIDriver = CpObject(BunkerSiloAIDriver)

ShovelAIDriver.myStates = {
	DRIVING_UNLOADING_COURSE = {checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	WAITING_FOR_TRAILER = {},
	DRIVING_TO_TRAILER = {},
	DRIVING_TO_UNLOADING_TRIGGER = {},
	UNLOADING_AT_TRAILER = {},
	UNLOADING_AT_TRIGGER = {},
	DRIVING_BACK_FROM_UNLOADING_POINT = {checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true}
}

ShovelAIDriver.WORKING_TOOL_POSITIONS = {}
ShovelAIDriver.WORKING_TOOL_POSITIONS.LOADING = 1
ShovelAIDriver.WORKING_TOOL_POSITIONS.TRANSPORT = 2 
ShovelAIDriver.WORKING_TOOL_POSITIONS.PRE_UNLOADING = 3 
ShovelAIDriver.WORKING_TOOL_POSITIONS.UNLOADING = 4

--- Distance to unloading point to start the unloading progress.
ShovelAIDriver.WAIT_DISTANCE_TO_THE_UNLOAD_POINT = 5
--- Distance to disable the collision detection for unloading at trailers.
ShovelAIDriver.DISABLE_TRAFFIC_DETECTION_DISTANCE = 15
function ShovelAIDriver.create(vehicle)
	if AIDriverUtil.hasImplementWithSpecialization(vehicle, ConveyorBelt) or vehicle.spec_conveyorBelt then
		return BunkerSiloLoaderAIDriver(vehicle)
	end

	--- Disabled for now, as the mixer wagon driver needs trigger handler improvements. 
--	if AIDriverUtil.hasImplementWithSpecialization(vehicle, MixerWagon) or vehicle.spec_mixerWagon then
--		return MixerWagonAIDriver(vehicle)
--	end

	if vehicle.cp.settings.shovelModeAIDriverTriggerHandlerIsActive:is(false) then
		return ShovelAIDriver(vehicle)
	else
		return TriggerShovelAIDriver(vehicle)
	end
end


function ShovelAIDriver:init(vehicle)
	BunkerSiloAIDriver.init(self,vehicle)
	self:initStates(ShovelAIDriver.myStates)
	self.shovelState = self.states.DRIVING_UNLOADING_COURSE
	self.shovelDebugChannel = courseplay.DBG_MODE_9
	self.transitionCourseOffset = 20
end

function ShovelAIDriver:setHudContent()
	BunkerSiloAIDriver.setHudContent(self)
	courseplay.hud:setShovelModeAIDriverContent(self.vehicle)
end

function ShovelAIDriver:start(startingPoint)
	self.shovel = AIDriverUtil.getImplementWithSpecialization(self.vehicle,Shovel) or self.vehicle
	self.currentDischargeNode = self.shovel:getCurrentDischargeNode()

	if not self.shovel then 
		self:error("Error: shovel not found!!")
		courseplay.onStopCpAIDriver(self.vehicle,AIVehicle.STOP_REASON_UNKOWN)
		return
	end
	self.targetUnloadingNode = nil
	self.lastDistanceToEmptyPoint = math.huge
	self:changeShovelState(self.states.DRIVING_UNLOADING_COURSE)

	self.oldCanDischargeToGround = self.currentDischargeNode.canDischargeToGround
	self.currentDischargeNode.canDischargeToGround = false

	local vAI = self.vehicle:getAttachedImplements()
	for i,_ in pairs(vAI) do
		local object = vAI[i].object
		if object.ignoreVehicleDirectionOnLoad ~= nil then
			object.ignoreVehicleDirectionOnLoad = true
		end	
		local oAI = object:getAttachedImplements()
		if oAI ~= nil then
			for k,_ in pairs(oAI) do
				if oAI[k].object.ignoreVehicleDirectionOnLoad ~= nil then
					oAI[k].object.ignoreVehicleDirectionOnLoad = true
				end
			end
		end				
	end

	BunkerSiloAIDriver.start(self,startingPoint)
	if not self:checkForWaitPoints() then 
		self:displayWarning("COURSEPLAY_NO_VALID_COURSE")
		courseplay.onStopCpAIDriver(self.vehicle,AIVehicle.STOP_REASON_UNKOWN)
		return
	end	
end

function ShovelAIDriver:stop(msg)
	self.currentDischargeNode.canDischargeToGround = self.oldCanDischargeToGround
	self.oldCanDischargeToGround = nil
	BunkerSiloAIDriver.stop(self,msg)
end

--- Check if one wait point is present for the unloading.
function ShovelAIDriver:checkForWaitPoints()
	self.emptyWaitPoint = self.mainCourse:getNextWaitPointFromIx(1)
	return self.emptyWaitPoint
end

function ShovelAIDriver:isDrivingUnloadingCourse()
	return self.shovelState == self.states.DRIVING_UNLOADING_COURSE
end

function ShovelAIDriver:isWaitingForTrailer()
	return self.shovelState == self.states.WAITING_FOR_TRAILER
end

function ShovelAIDriver:isDrivingToTrailer()
	return self.shovelState == self.states.DRIVING_TO_TRAILER
end

function ShovelAIDriver:isDrivingToUnloadingTrigger()
	return self.shovelState == self.states.DRIVING_TO_UNLOADING_TRIGGER
end

function ShovelAIDriver:isUnloadingAtTrailer()
	return self.shovelState == self.states.UNLOADING_AT_TRAILER
end

function ShovelAIDriver:isUnloadingAtTrigger()
	return self.shovelState == self.states.UNLOADING_AT_TRIGGER
end

function ShovelAIDriver:isDrivingBackFromUnloadingPoint()
	return self.shovelState == self.states.DRIVING_BACK_FROM_UNLOADING_POINT
end

function ShovelAIDriver:drive(dt)
	if not self:areWorkingToolPositionsValid() then 
		self:hold()
	end
	if self:isDrivingUnloadingCourse() then 
		self:driveUnloadingCourse(dt)
	elseif self:isWaitingForTrailer() then 
		self:hold()
	elseif self:isDrivingToTrailer() then 
		self:driveToTrailer(dt)
	elseif self:isDrivingToUnloadingTrigger() then 
		self:driveToUnloadingTrigger(dt)
	elseif self:isUnloadingAtTrailer() then
		self:unloadingAtTrailer(dt)
	elseif self:isUnloadingAtTrigger() then
		self:unloadingAtTrigger(dt)
	elseif self:isDrivingBackFromUnloadingPoint() then 
		self:driveBackFromUnloadingPoint(dt)
	end

	BunkerSiloAIDriver.drive(self,dt)
end


function ShovelAIDriver:driveIntoSilo(dt)
	if not self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.LOADING) then 
		--- Waiting until the working position is reached.
		self:hold()
	end
	--- If the shovel is full drive back out of the silo and then drive the unloading course.
	if self:getIsShovelFull() then 
		self:setupDriveOutOfSiloCourse()
	end

	BunkerSiloAIDriver.driveIntoSilo(self,dt)
end

function ShovelAIDriver:driveOutOfSilo(dt)
	self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.TRANSPORT)
end 

function ShovelAIDriver:driveUnloadingCourse(dt)
	self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.TRANSPORT)
end

--- Is the unloading point reached for unloading in a trailer.
function ShovelAIDriver:isUnloadingPointReached(dt)
	if self.targetUnloadingNode then
		local directionNode = self:getDirectionNode()
		local shovelNode = self:getTargetNode()
		local dischargeNode = self.currentDischargeNode.node
		local inputAttacherJoints = self.shovel:getInputAttacherJoints()
		local relevantAttacherJointNode = inputAttacherJoints[1].node
		---offset between shovel attacherNode and dischargeNode
		local nx,_,nz = localToLocal(relevantAttacherJointNode,dischargeNode,0,0,0)
		---get the world coordinates
		local ax,ay,az = localToWorld(dischargeNode,0,0,nz/2)
		local bx,by,bz = localToWorld(relevantAttacherJointNode,0,0,0)
		local dx,dy,dz = localToWorld(self.targetUnloadingNode,0,0,0)
		local distance = courseplay:distance(dx,dz,ax,az)
		if self:isShovelDebugActive() then
			DebugUtil.drawDebugNode(relevantAttacherJointNode, 'relevantAttacherJointNode')
			DebugUtil.drawDebugNode(self.targetUnloadingNode, 'exactFillRootNode')
			DebugUtil.drawDebugNode(shovelNode, 'shovelNode')
			DebugUtil.drawDebugNode(self:getDirectionNode(), 'driverNode')
		end

		self:shovelDebug("distanceToTrailer: %.2f",distance)
		self:setSpeed(MathUtil.clamp(distance*2,1,self:getRecordedSpeed()))
		
		if distance < 1.2 then 
			return true
		end
	end
end

--- Driving to the trailer for unloading.
function ShovelAIDriver:driveToTrailer(dt)
	if not self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.PRE_UNLOADING) then
		self:hold()
	end
	--- Waiting until the driver has reached the correct unloading position.
	if self:isUnloadingPointReached() then
		self:changeShovelState(self.states.UNLOADING_AT_TRAILER)
	end
end

--- Driving to the unload trigger for unloading. 
function ShovelAIDriver:driveToUnloadingTrigger(dt)
	if not self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.PRE_UNLOADING) then
		self:hold()
	end
	--- If an unload trigger was found (dischargeObject) then we drive 2 additional meters,
	--- to make sure the unloading point is in the bounds of the trigger.	
	--- The calculation of the 2 additional meters is done by checking if the driver 
	--- has driven the additional meters.
	if self.distanceTraveledUntilTriggerWasFound  then 
		if self:getDistanceMovedSinceStart() - self.distanceTraveledUntilTriggerWasFound > 2 then 
			self:changeShovelState(self.states.UNLOADING_AT_TRIGGER)
			self.distanceTraveledUntilTriggerWasFound = nil
		end
	elseif self.currentDischargeNode.dischargeObject then 
		self.distanceTraveledUntilTriggerWasFound = self:getDistanceMovedSinceStart()
	end
end

--- Handles unloading in to trailers.
function ShovelAIDriver:unloadingAtTrailer(dt)
	self:hold()
	if self:getIsShovelEmpty() or self.currentDischargeNode.dischargeObject == nil or self.currentDischargeNode.dischargeFailedReason == Dischargeable.DISCHARGE_REASON_NO_FREE_CAPACITY then 
		self:setupDriveBackFromUnloadingPointCourse()
		return
	end
	-- discharge node can unload and dischargeObject was found
	if self.shovel:getCanDischargeToObject(self.currentDischargeNode) then 
		self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.UNLOADING) 				
	end
end


--- Handles unloading in to triggers.
function ShovelAIDriver:unloadingAtTrigger(dt)
	self:hold()
	if self:getIsShovelEmpty() then 
		self:setupDriveBackFromUnloadingPointCourse()
		return
	end
	local isUnloading = self.currentDischargeNode.isEffectActive
	--- Discharge node can unload or dischargeObject was found.
	if self.shovel:getCanDischargeToObject(self.currentDischargeNode) or self.currentDischargeNode.dischargeObject then 
		local objectAlmostFilled = self:isUnloadingTargetAlmostFilled()
		local objectHasEnoughSpace = self:hasUnloadingTargetEnoughFreeSpace()
		if objectAlmostFilled then 
			self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.PRE_UNLOADING)
			return
		end
		if objectHasEnoughSpace and not isUnloading then 
			self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.UNLOADING)
			return
		end
		if isUnloading then
			self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.UNLOADING)
		end
	end
end

--- Driving back from the unloading point.
function ShovelAIDriver:driveBackFromUnloadingPoint(dt)
	if not self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.PRE_UNLOADING) then 
		self:hold()
	end
	local currentIx = self.ppc:getCurrentWaypointIx()
	if not self.course:isReverseAt(currentIx) then 
		self:changeShovelState(self.states.DRIVING_UNLOADING_COURSE)
	end
end


--- If the driver is waiting for a trailer then create raycasts to search for trailers / triggers.
function ShovelAIDriver:updateTick(dt)
	if self:isWaitingForTrailer() then 
		self:searchForUnloadingObjectRaycast()
	end
	BunkerSiloAIDriver.updateTick(self,dt)
end

--- Setups a driving to trailer course.
---@param trailer table
---@param exactFillRootNode number
function ShovelAIDriver:setupDrivingToTrailerCourse(trailer,exactFillRootNode)
	local course = Course.createFromNodeToNode(self.vehicle, self:getDirectionNode(), exactFillRootNode, 0, 0, 5, 5, false)
	local startIx = course:getNextFwdWaypointIxFromVehiclePosition(1,self:getDirectionNode(),2)
	self:startCourse(course,startIx)
	self.targetUnloadingNode = exactFillRootNode
	self:changeShovelState(self.states.DRIVING_TO_TRAILER)
end

--- Setups a driving to unloading trigger course.
--- This is used to have the driver drive straight to the trigger,
--- as this is not always working, 
--- the driver might try to reverse back before it can unload on the main course.
---@param trigger table
function ShovelAIDriver:setupDrivingToUnloadingTriggerCourse(trigger)
	local x,_,z = getWorldTranslation(self:getDirectionNode())
	local dx,_,dz = self.mainCourse:getWaypointPosition(self.emptyWaitPoint)
	local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 0, 0, 5, 5, false)
	local startIx = course:getNextFwdWaypointIxFromVehiclePosition(1,self:getDirectionNode(),2)
	self:startCourse(course,startIx)
	self.targetUnloadingNode = trigger:getFillUnitExactFillRootNode()
	self:changeShovelState(self.states.DRIVING_TO_UNLOADING_TRIGGER)
end

--- Setups a driving back from unloading point course.
function ShovelAIDriver:setupDriveBackFromUnloadingPointCourse()
	local nextIx = self.mainCourse:getNextRevWaypointIxFromVehiclePosition(self.emptyWaitPoint,self:getDirectionNode(),3)
	self:startCourse(self.mainCourse,nextIx)
	self:shovelDebug("Start drive back from unloading point course at %d",nextIx)
	self:changeShovelState(self.states.DRIVING_BACK_FROM_UNLOADING_POINT)
end

--- Checks if the current dischargeObject has enough free space.
---@return boolean object has enough free space, freeSpace > self:getMinNeededFreeCapacity()
function ShovelAIDriver:hasUnloadingTargetEnoughFreeSpace()
	local fillType = self.shovel:getDischargeFillType(self.currentDischargeNode)
	local object = self.currentDischargeNode.dischargeObject
	local freeSpace = object.getFillUnitFreeCapacity ~= nil and  object:getFillUnitFreeCapacity(self.currentDischargeNode.dischargeFillUnitIndex, fillType, self.vehicle:getActiveFarm())
	local minNeededFreeSpace = self:getFreeCapacityToStartUnloading()
	if freeSpace then 
		if freeSpace >= minNeededFreeSpace then 
			self:shovelDebug("Free capacity: %.2f, min needed free capacity to start: %.2f",freeSpace,minNeededFreeSpace)
			return true
		end
	else 
		return true 
	end
end

---Check if the current dischargeObject is almost filled ?
---@return boolean object is almost filled, free capacity < 300*1/self.shovel:getDischargeNodeEmptyFactor()
---		   the factor is used to compensate for shovels that unload to fast 
function ShovelAIDriver:isUnloadingTargetAlmostFilled()
	local fillType = self.shovel:getDischargeFillType(self.currentDischargeNode)
	local object = self.currentDischargeNode.dischargeObject
	local freeCapacity = object.getFillUnitFreeCapacity ~= nil and object:getFillUnitFreeCapacity(self.currentDischargeNode.dischargeFillUnitIndex, fillType, self.vehicle:getActiveFarm())
	local minNeededFreeSpace = self:getFreeCapacityToStopUnloading()
	if freeCapacity and freeCapacity <= minNeededFreeSpace  then
		self:shovelDebug("Free capacity: %.2f, min needed free capacity : %.2f",freeCapacity,minNeededFreeSpace)
		return true
	end
end

---Get the minimum required free space to start unloading,
---so we are not constantly starting to unload and the stop again directly
---@return number minimum required free space, shovel min(capacity/5,fillLevel)
function ShovelAIDriver:getFreeCapacityToStartUnloading()
	return math.min(2*self.shovel:getFillUnitCapacity(1)/5,self.shovel:getFillUnitFillLevel(1))
end

---Get the minimum required free space to continue unloading,
---so we are not constantly starting to unload and the stop again directly
---@return number minimum required free space, shovel min(capacity/5,fillLevel)
function ShovelAIDriver:getFreeCapacityToStopUnloading()
	return math.min(self.shovel:getFillUnitCapacity(1)/5,self.shovel:getFillUnitFillLevel(1))
end

function ShovelAIDriver:getIsShovelFull()
	return self.shovel:getFillUnitFillLevel(1) >= self.shovel:getFillUnitCapacity(1)*0.98
end

function ShovelAIDriver:getIsShovelEmpty()
	return self.shovel:getFillUnitFillLevel(1) <= self.shovel:getFillUnitCapacity(1)*0.01
end


--- Creates raycasts for searching of trailers/triggers near the shovelEmptyPoint (first wait point).
function ShovelAIDriver:searchForUnloadingObjectRaycast()
	local ix = self.emptyWaitPoint
	local node = WaypointNode('proxyNode')
	node:setToWaypoint(self.course, ix, true)
	setRotation(node.node, 0, self.course:getWaypointYRotation(ix-1), 0)
	local lx, lz = MathUtil.getDirectionFromYRotation(self.course:getWaypointYRotation(ix-1))
	local ly = -5
	for i=1,12 do
		if self:isWaitingForTrailer() then
			local x,y,z = localToWorld(node.node,0,8,i/2);
			raycastAll(x, y, z, lx, ly, lz, "searchForUnloadingObjectRaycastCallback", 10, self);
			if self:isShovelDebugActive() then
				cpDebug:drawLine(x, y, z, 1, 0, 0, x+lx*10, y+ly*10, z+lz*10);
			end;
		end
	end;
	node:destroy()
end

--- Raycast callback for searching of trailers/triggers near the shovelEmptyPoint (first wait point).
function ShovelAIDriver:searchForUnloadingObjectRaycastCallback(transformId, x, y, z, distance, nx, ny, nz, subShapeIndex, hitShapeId)
	local object = g_currentMission:getNodeObject(transformId)
	--has the target already been hit ?

	if not self:isWaitingForTrailer() then
		return
	end
	if object then
		--is object a vehicle, trailer,...
		if object:isa(Vehicle) then 
			--object supports filltype, bassicly trailer and so on
			if object.getFillUnitSupportsToolType then
				for fillUnitIndex,fillUnit in pairs(object:getFillUnits()) do
					--object supports filling by shovel
					local allowedToFillByShovel = object:getFillUnitSupportsToolType(fillUnitIndex, ToolType.DISCHARGEABLE)	
					local fillType = self.shovel:getDischargeFillType(self.currentDischargeNode)
					--object supports fillType
					local supportedFillType = object:getFillUnitSupportsFillType(fillUnitIndex,fillType)
					if allowedToFillByShovel then 
						self:shovelDebug("allowedToFillByShovel")
						if supportedFillType then 
							--valid trailer/ fillableObject found
							
							--check if the vehicle is stopped 
							local rootVehicle = object:getRootVehicle()
							if not AIDriverUtil.isStopped(rootVehicle) then 
								return
							end
							---
							local exactFillRootNode = object:getFillUnitExactFillRootNode(fillUnitIndex) or object.rootNode
							self:shovelDebug("supportedFillType")
							self:shovelDebug("Trailer found!")
							self:setupDrivingToTrailerCourse(object,exactFillRootNode)
							return
						else
							self:shovelDebug("not  supportedFillType")
						end
					else
						self:shovelDebug("not  allowedToFillByShovel")
					end
				end
			else
				self:shovelDebug("FillUnit not found!")
			end
			return
		--UnloadTrigger found
		elseif object:isa(UnloadTrigger) then 
		--	DebugUtil.printTableRecursively(object, "  ", 0, 2)
			self:shovelDebug("UnloadTrigger found!")
			local fillUnitIndex = object:getFillUnitIndexFromNode(hitShapeId)
			self:setupDrivingToUnloadingTriggerCourse(object)
			return
		--some diffrent object which is valid
		elseif object.getFillUnitIndexFromNode ~= nil then
		--	DebugUtil.printTableRecursively(object, "  ", 0, 2)
			local fillUnitIndex = object:getFillUnitIndexFromNode(hitShapeId)
			if fillUnitIndex ~= nil then	
				local fillType = self.shovel:getDischargeFillType(self.currentDischargeNode)
				if object:getFillUnitSupportsFillType(fillUnitIndex, fillType) then
					self:shovelDebug("Trigger found!")
					self:setupDrivingToUnloadingTriggerCourse(object)
				else 
					self:shovelDebug("fillType not supported!")
				end
			else 
				self:shovelDebug("no fillUnitIndex found!")
			end
		end
	else
		self:shovelDebug("Nothing found!")
		return
	end
end

function ShovelAIDriver:changeShovelState(newState)
	if self.shovelState ~= newState then
		self.shovelState = newState
		self:siloDebug("New siloState => %s",newState.name)
	end
end

function ShovelAIDriver:isShovelDebugActive()
	return courseplay.debugChannels[courseplay.DBG_MODE_9]
end

function ShovelAIDriver:shovelDebug(...)
	courseplay.debugVehicle(self.shovelDebugChannel, self.vehicle,...)
end

function ShovelAIDriver:getWorkingToolPositionsSetting()
	return self.vehicle.cp.settings.frontloaderToolPositions
end

function ShovelAIDriver:getTargetNode()
	return self.shovel.spec_shovel.shovelNodes[1].node
end

--- The driver always drives into the silo forwards.
function ShovelAIDriver:isDriveDirectionReverse()
	return false
end

--- Only allows filled silos/heaps.
function ShovelAIDriver:isEmptySiloAllowed()
	return false
end

--- Enables heap search.
function ShovelAIDriver:isHeapSearchAllowed()
	return true
end

function ShovelAIDriver:getBestTarget()
	return self.bunkerSiloManager:getBestTargetFillUnitFillUp()
end

--- If max silo fillLevel is reached, then continue with the main course.
function ShovelAIDriver:getCanContinueDrivingSiloCourse()
	return not self:getIsShovelFull()
end

--- Let the driver reverse a bit to have more room for driving into the silo.
--- Only if the silo isn't a heap silo and the target is near a bunker wall.
---@param bestTarget table first target for driving into the silo.
function ShovelAIDriver:isStartDistanceToSiloNeeded(bestTarget)
	local numColumn = self.bunkerSiloManager:getNumberOfColumns()
	return not self.bunkerSiloManager:isHeapSiloMap() and self:isBestTargetAtBunkerWall(bestTarget) and bestTarget.line <= math.ceil(numColumn/2)
end

--- Is the silo target at a bunker wall ?
---@param bestTarget table first target for driving into the silo.
function ShovelAIDriver:isBestTargetAtBunkerWall(bestTarget)
	return bestTarget.column == 1 or bestTarget.column == self.bunkerSiloManager:getNumberOfColumns()
end

--- Disables stopping at wait points by the AIDriver, as it gets handled separately.
function ShovelAIDriver:isStoppingAtWaitPointAllowed()
	return false
end

function ShovelAIDriver:onEndCourse()
	--- Only handle ending of course if they were created relative to the bunker silo.
	if self:isDrivingUnloadingCourse() then 
		BunkerSiloAIDriver.onEndCourse(self)
	end
end

function ShovelAIDriver:onWaypointPassed(ix)
	--- If the distance to the shovel empty point is less than 5m, then search for trailers/ triggers.
	if self:getCanUnload() and self.emptyWaitPoint and self.ppc:getCurrentWaypointIx() < self.emptyWaitPoint then 
		self.lastDistanceToEmptyPoint = self.course:getDistanceBetweenWaypoints(self.ppc:getCurrentWaypointIx(), self.emptyWaitPoint)
		if self.lastDistanceToEmptyPoint < self.WAIT_DISTANCE_TO_THE_UNLOAD_POINT then
			self:changeShovelState(self.states.WAITING_FOR_TRAILER)
		end
	else 
		self.lastDistanceToEmptyPoint = math.huge
	end

	BunkerSiloAIDriver.onWaypointPassed(self,ix)
end

function ShovelAIDriver:getCanUnload()
	return not self:getIsShovelEmpty() and self:isDrivingUnloadingCourse() and self:isDrivingNormalCourse()
end

function ShovelAIDriver:isTrafficConflictDetectionEnabled()
	return BunkerSiloAIDriver.isTrafficConflictDetectionEnabled(self) and self.shovelState.properties.checkForTrafficConflict
end

function ShovelAIDriver:isProximitySwerveEnabled()
	return BunkerSiloAIDriver.isProximitySwerveEnabled(self) and self.shovelState.properties.enableProximitySwerve
end

function ShovelAIDriver:isProximitySpeedControlEnabled()
	return BunkerSiloAIDriver.isProximitySpeedControlEnabled(self) and self.shovelState.properties.enableProximitySpeedControl
end

function ShovelAIDriver:isCollisionDetectionEnabled()
	return self.shovelState.properties.checkForTrafficConflict and self.lastDistanceToEmptyPoint > self.DISABLE_TRAFFIC_DETECTION_DISTANCE
end