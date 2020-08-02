
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
Field Supply AI Driver to let fill tools with digestate or liquid manure on the field egde
Also known as mode 8
]]

---@class FieldSupplyAIDriver : FillableFieldworkAIDriver
FieldSupplyAIDriver = CpObject(FillableFieldworkAIDriver)

FieldSupplyAIDriver.myStates = {
	ON_REFILL_COURSE = {},
	WAITING_FOR_GETTING_UNLOADED = {}
}

--- Constructor
function FieldSupplyAIDriver:init(vehicle)
	FillableFieldworkAIDriver.init(self, vehicle)
	self:initStates(FieldSupplyAIDriver.myStates)
	self.supplyState = self.states.ON_REFILL_COURSE
	self.mode=courseplay.MODE_FIELD_SUPPLY 
	self:setHudContent()
end

function FieldSupplyAIDriver:setHudContent()
	courseplay.hud:setFieldSupplyAIDriverContent(self.vehicle)
end
--this one is should be better derived!!
function FieldSupplyAIDriver:start(startingPoint)
	self.refillState = self.states.REFILL_DONE
	TriggerAIDriver.start(self,startingPoint)
	self:getSiloSelectedFillTypeSetting():cleanUpOldFillTypes()
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
	self:findPipe() --for Augerwagons
end

function FieldSupplyAIDriver:stop(msgReference)
	-- TODO: revise why FieldSupplyAIDriver is derived from FieldworkAIDriver, as it has no fieldwork course
	-- so this override would not be necessary.
	TriggerAIDriver.stop(self, msgReference)
end

function FieldSupplyAIDriver:onEndCourse()
	TriggerAIDriver.onEndCourse(self)
end

function FieldSupplyAIDriver:drive(dt)
	-- update current waypoint/goal point
	if self.supplyState == self.states.ON_REFILL_COURSE  then
		FillableFieldworkAIDriver.driveUnloadOrRefill(self)
		TriggerAIDriver.drive(self, dt)
		self.unloadingText = nil
	elseif self.supplyState == self.states.WAITING_FOR_GETTING_UNLOADED then
		self:stopAndWait(dt)
		self:updateInfoText()
		if self.pipe then
			self.pipe:setPipeState(AIDriverUtil.PIPE_STATE_OPEN)
		end
		-- unload into a FRC if there is one
		self:activateUnloadingTriggerWhenAvailable(self.vehicle)
		if self.unloadingText then 
			courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_UNLOADING_AMOUNT;%d;%d",math.floor(self.unloadingText.fillLevel),self.unloadingText.capacity))
		end
		--if i'm empty or fillLevel is below threshold then drive to get new stuff
		if self:isFillLevelToContinueReached() then
			self:continue()
			self.loadingState = self.states.NOTHING
		end
	end
end

function FieldSupplyAIDriver:continue()
	self:changeSupplyState(self.states.ON_REFILL_COURSE )
	if self:isUnloading() then
		self.activeTriggers=nil
	end
	TriggerAIDriver.continue(self)
end

function FieldSupplyAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	--- Check if we are at the last waypoint and should we continue with first waypoint of the course
	-- or stop.
	if ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	elseif self.course:isWaitAt(ix) then
		-- show continue button
		self.state = self.states.STOPPED
		self:changeSupplyState(self.states.WAITING_FOR_GETTING_UNLOADED)
		self:setInfoText('REACHED_OVERLOADING_POINT')
		self:refreshHUD()
	end
end

function FieldSupplyAIDriver:changeSupplyState(newState)
	self.supplyState = newState;
end

function FieldSupplyAIDriver:isFillLevelToContinueReached()
	local fillTypeData, fillTypeDataSize= self:getSiloSelectedFillTypeData()
	if fillTypeData == nil then
		return
	end
	--pipe still opening wait!
	if self.pipe and not self.pipe:getIsPipeStateChangeAllowed(AIDriverUtil.PIPE_STATE_CLOSED) then
		return
	end
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	for fillType, info in pairs(fillLevelInfo) do	
		for _,data in ipairs(fillTypeData) do
			if data.fillType == fillType then
				local fillLevelPercentage = info.fillLevel/info.capacity*100
				if fillLevelPercentage <= self.vehicle.cp.settings.driveOnAtFillLevel:get() and self:levelDidNotChange(fillLevelPercentage) then
					return true
				end
			end
		end
	end
end

function FieldSupplyAIDriver:activateTriggersIfPossible(isInWaitPointRange)
	if not isInWaitPointRange  then
		self:activateFillTriggersWhenAvailable(self.vehicle)
		self:activateLoadingTriggerWhenAvailable()
	end
end

--TODO: figure out the usage of this one ??
function FieldSupplyAIDriver:stopAndWait(dt)
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, false, fwd, 0, 1, 0, 1)
end

function FieldSupplyAIDriver:findPipe()
    local implementWithPipe = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Pipe)
    if implementWithPipe then
        self.pipe = implementWithPipe
    end
end

function FieldSupplyAIDriver:closePipeIfNeeded(isInWaitPointRange) 
	if self.pipe and not isInWaitPointRange then
		self.pipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
	end
end

function FieldSupplyAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeFieldSupplyDriver
end

function FieldSupplyAIDriver:isOverloadingTriggerCallbackEnabled()
	return true
end

function FieldSupplyAIDriver:isUnloadingTriggerCallbackEnabled()
	return true
end

--Augerwagons handling
--Pipe callback used for augerwagons to open the cover on the fillableObject
function FieldSupplyAIDriver:unloadingTriggerCallback(superFunc,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then 
		if not rootVehicle.cp.driver:isOverloadingTriggerCallbackEnabled() then
			return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
		end
		local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil and object ~= self and object:isa(Vehicle) then
            local objectRootVehicle = object:getRootVehicle()
			if not courseplay:isAIDriverActive(objectRootVehicle)then 
				return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
			end
			objectRootVehicle.cp.driver:setInTriggerRange()
			if object.getFillUnitIndexFromNode ~= nil and not onLeave then
                local fillUnitIndex = object:getFillUnitIndexFromNode(otherId)
                if fillUnitIndex ~= nil then
                    local dischargeNode = self:getDischargeNodeByIndex(self:getPipeDischargeNodeIndex())
                    if dischargeNode ~= nil then
                        local fillType = self:getFillUnitFillType(dischargeNode.fillUnitIndex)
						local validFillUnitIndex = object:getFirstValidFillUnitToFill(fillType)
                        if fillType and validFillUnitIndex then 
							courseplay.debugFormat(2,"unloadingTriggerCallback open Cover for "..g_fillTypeManager:getFillTypeByIndex(fillType).title)
							SpecializationUtil.raiseEvent(object, "onAddedFillUnitTrigger",fillType,validFillUnitIndex,1)
							objectRootVehicle.cp.driver:setInTriggerRange(true)
						end
					end
				end
			elseif onLeave then
				SpecializationUtil.raiseEvent(object, "onRemovedFillUnitTrigger",0)
				courseplay.debugFormat(2,"unloadingTriggerCallback close Cover")
				objectRootVehicle.cp.driver:resetLoadingState()
			end
		end
		if onLeave then
			courseplay.debugFormat(2,"unloadingTriggerCallback onLeave")
		end
		if onEnter then 
			courseplay.debugFormat(2,"unloadingTriggerCallback onEnter")
		end
	end
	return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
end
Pipe.unloadingTriggerCallback = Utils.overwrittenFunction(Pipe.unloadingTriggerCallback,FieldSupplyAIDriver.unloadingTriggerCallback)

--stoping mode 4 driver for augerwagons
function FieldSupplyAIDriver:onDischargeStateChanged(superFunc,state)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) then
		if not rootVehicle.cp.driver:isOverloadingTriggerCallbackEnabled() then 
			return superFunc(self,state,noEventSend)
		end
		local dischargeNode = self:getCurrentDischargeNode()
		if dischargeNode and dischargeNode.dischargeObject then 
			if dischargeNode.dischargeObject:isa(Vehicle) then 
				local objectRootVehicle = dischargeNode.dischargeObject:getRootVehicle()
				if courseplay:isAIDriverActive(objectRootVehicle) then
					if state == Dischargeable.DISCHARGE_STATE_OFF then
						objectRootVehicle.cp.driver:resetLoadingState()
					else
						objectRootVehicle.cp.driver:setLoadingState(dischargeNode.dischargeObject,dischargeNode.dischargeFillUnitIndex,self:getDischargeFillType(dischargeNode))
					end
				end
			end
		end
	end
	return superFunc(self,state,noEventSend)
end
Pipe.onDischargeStateChanged = Utils.overwrittenFunction(Pipe.onDischargeStateChanged,FieldSupplyAIDriver.onDischargeStateChanged)

--loading/unloading text for mode 8
function FieldSupplyAIDriver:dischargeToObject(superFunc,dischargeNode, emptyLiters, object, targetFillUnitIndex)
	local dischargedLiters = superFunc(self,dischargeNode, emptyLiters, object, targetFillUnitIndex)
	local rootVehicle = self:getRootVehicle()
	if courseplay:isAIDriverActive(rootVehicle) and dischargedLiters~=0 then
		if not rootVehicle.cp.driver:isUnloadingTriggerCallbackEnabled() then 
			return dischargedLiters
		end
		local fillType = self:getDischargeFillType(dischargeNode)
		if object and object:isa(Vehicle) then
			local objectRootVehicle = object:getRootVehicle()
			if courseplay:checkAIDriver(objectRootVehicle) then
				local fillLevel = object:getFillUnitFillLevel(targetFillUnitIndex)
				local fillCapacity = object:getFillUnitCapacity(targetFillUnitIndex)
				objectRootVehicle.cp.driver:setLoadingText(fillType,fillLevel,fillCapacity)
			end
		end
		local fillLevel = self:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
		local fillCapacity = self:getFillUnitCapacity(dischargeNode.fillUnitIndex)
		rootVehicle.cp.driver:setUnloadingText(fillType,fillLevel,fillCapacity)
	end
	return dischargedLiters
end
Dischargeable.dischargeToObject = Utils.overwrittenFunction(Dischargeable.dischargeToObject,FieldSupplyAIDriver.dischargeToObject)
