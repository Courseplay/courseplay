
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

--TODO: Have FieldSupplyAIDriver be derived from GrainTransportDriver and not FillableFieldworkAIDriver,
--		as there is no need for FieldworkAIDriver functions 

---@class FieldSupplyAIDriver : FillableFieldworkAIDriver
FieldSupplyAIDriver = CpObject(FillableFieldworkAIDriver)

FieldSupplyAIDriver.myStates = {
	ON_REFILL_COURSE = {},
	WAITING_FOR_GETTING_UNLOADED = {}
}

--- Constructor
function FieldSupplyAIDriver:init(vehicle)
	FillableFieldworkAIDriver.init(self, vehicle)
	local settings = self.vehicle.cp.settings
	self.triggerHandler.driveOnAtFillLevel = settings.driveOnAtFillLevel
	self:initStates(FieldSupplyAIDriver.myStates)
	self.supplyState = self.states.ON_REFILL_COURSE
	self.mode=courseplay.MODE_FIELD_SUPPLY
	self.debugChannel = courseplay.DBG_MODE_8
end

function FieldSupplyAIDriver:postInit()
    ---Refresh the Hud content here,as otherwise the moveable pipe is not 
    ---detected the first time after loading a savegame. 
    self:setHudContent()
    FillableFieldworkAIDriver.postInit(self)
end

function FieldSupplyAIDriver:setHudContent()
	self:findPipe()
	AIDriver.setHudContent(self)
	courseplay.hud:setFieldSupplyAIDriverContent(self.vehicle)
end
--this one is should be better derived!!
function FieldSupplyAIDriver:start(startingPoint)
	self.refillState = self.states.REFILL_DONE
	self.supplyState = self.states.ON_REFILL_COURSE
	AIDriver.start(self,startingPoint)
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
end

function FieldSupplyAIDriver:stop(msgReference)
	-- TODO: revise why FieldSupplyAIDriver is derived from FieldworkAIDriver, as it has no fieldwork course
	-- so this override would not be necessary.
	AIDriver.stop(self, msgReference)
end

function FieldSupplyAIDriver:shouldStopAtEndOfCourse()
	return false
end

function FieldSupplyAIDriver:onEndCourse()
	AIDriver.onEndCourse(self)
end

function FieldSupplyAIDriver:isProximitySwerveEnabled()
	return self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE or
			self.state == self.states.RETURNING_TO_FIRST_POINT or
			self.supplyState == self.states.ON_REFILL_COURSE
end

function FieldSupplyAIDriver:drive(dt)
	-- update current waypoint/goal point
	if self.supplyState == self.states.ON_REFILL_COURSE  then
		FillableFieldworkAIDriver.driveUnloadOrRefill(self)
		self.unloadingText = nil
	elseif self.supplyState == self.states.WAITING_FOR_GETTING_UNLOADED then
		self:holdWithFuelSave()
		self:updateInfoText()
		if self.objectWithPipe then
			self.triggerHandler:enableFillTypeUnloadingAugerWagon()
			---TODO: Currently it's not possible to open the pipe after the mode 4 driver arrives,
			---		 as there is not trigger to detect it, while the pipe is closed.

		--	if AIDriverUtil.isTrailerUnderPipe(self.pipe,true) then 
				--- Open the pipe if there is a trailer under the pipe and standing still.
				self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_OPEN)
				self:isWorkingToolPositionReached(dt,1)
		--	else 
		--		self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
		--	end
		else
			self.triggerHandler:enableFillTypeUnloading()
		end
		self.triggerHandler:disableFillTypeLoading()
		--if i'm empty or fillLevel is below threshold then drive to get new stuff
		if self:isFillLevelToContinueReached() then
			self:continue()
			self.triggerHandler:resetLoadingState()
		end
	end
	AIDriver.drive(self, dt)
end

function FieldSupplyAIDriver:enableFillTypeLoading(isInWaitPointRange)
	if not isInWaitPointRange then 
		FillableFieldworkAIDriver.enableFillTypeLoading(self)
	end
end

function FieldSupplyAIDriver:continue()
	self:changeSupplyState(self.states.ON_REFILL_COURSE )
	AIDriver.continue(self)
end

function FieldSupplyAIDriver:onWaypointPassed(ix)
	if self.course:isWaitAt(ix) then 
		self:changeSupplyState(self.states.WAITING_FOR_GETTING_UNLOADED)
		self:setInfoText('REACHED_OVERLOADING_POINT')
		self:refreshHUD()
	end
	AIDriver.onWaypointPassed(self,ix)
end

function FieldSupplyAIDriver:changeSupplyState(newState)
	self.supplyState = newState;
end

function FieldSupplyAIDriver:isFillLevelToContinueReached()
	local fillTypeData, fillTypeDataSize= self.triggerHandler:getSiloSelectedFillTypeData()
	if fillTypeData == nil then
		return
	end
	--pipe still opening wait!
	if self.objectWithPipe and not self.objectWithPipe:getIsPipeStateChangeAllowed(AIDriverUtil.PIPE_STATE_CLOSED) then
		return
	end
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	for fillType, info in pairs(fillLevelInfo) do	
		for _,data in ipairs(fillTypeData) do
			if data.fillType == fillType then
				local fillLevelPercentage = info.fillLevel/info.capacity*100
				if fillLevelPercentage <= self.vehicle.cp.settings.moveOnAtFillLevel:get() and self:levelDidNotChange(fillLevelPercentage) then
					return true
				end
			end
		end
	end
end

function FieldSupplyAIDriver:needsFillTypeLoading()
	if not self.isInWaitPointRange  then
		return true
	end
end

function FieldSupplyAIDriver:findPipe()
    local implementWithPipe = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Pipe) or self.vehicle.spec_pipe and self.vehicle
    if implementWithPipe then
		self.objectWithPipe = implementWithPipe
		self.pipe = implementWithPipe.spec_pipe
    end
end

function FieldSupplyAIDriver:closePipeIfNeeded(isInWaitPointRange) 
	if self.objectWithPipe and not self.isInWaitPointRange then
		self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
	end
end

function FieldSupplyAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeFieldSupplyDriver
end

function FieldSupplyAIDriver:getCanShowDriveOnButton()
	return AIDriver.getCanShowDriveOnButton(self) or self.refillState == self.states.WAITING_FOR_GETTING_UNLOADED
end

function FieldSupplyAIDriver:getWorkingToolPositionsSetting()
	local setting = self.settings.pipeToolPositions
	return setting:getHasMoveablePipe() and setting:hasValidToolPositions() and setting
end