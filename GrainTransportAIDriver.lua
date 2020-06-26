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

---@class GrainTransportAIDriver : AIDriver
GrainTransportAIDriver = CpObject(AIDriver)

GrainTransportAIDriver.myStates = {
	NOTHING  = {},
	IS_LOADING = {},
	IS_UNLOADING = {}
}

--- Constructor
function GrainTransportAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'GrainTransportAIDriver:init()')
	AIDriver.init(self, vehicle)
	self:initStates(GrainTransportAIDriver.myStates)
	self.mode = courseplay.MODE_GRAIN_TRANSPORT
	self.loadingState = self.states.NOTHING
	self.runCounter = 0
	self.trigger = nil
	self.totalFillCapacity = 0
	-- just for backwards compatibility
end

function GrainTransportAIDriver:writeUpdateStream(streamId)
	AIDriver.writeUpdateStream(self,streamId)
	streamWriteUIntN(streamId,self.runCounter,4)
end 

function GrainTransportAIDriver:readUpdateStream(streamId)
	AIDriver.readUpdateStream(self,streamId)
	self.runCounter = streamReadUIntN(streamId,4)
end

function GrainTransportAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setGrainTransportAIDriverContent(self.vehicle)
end

function GrainTransportAIDriver:start(startingPoint)
	self.loadingState = self.states.NOTHING
	self.totalFillCapacity = self:getTotalFillCapacitys(self.vehicle)
	courseplay:openCloseCover(self.vehicle, true) --check if we are already in trigger on start 
	courseplay:isTriggerAvailable(self.vehicle) --check if we are already in trigger on start 
	self:beforeStart()
	self.vehicle:setCruiseControlMaxSpeed(self.vehicle:getSpeedLimit() or math.huge)
	AIDriver.start(self, startingPoint)
	self:setDriveUnloadNow(false)
	self.vehicle.cp.settings.stopAtEnd:set(false)
end

function GrainTransportAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course for grain transport mode
	return false
end

function GrainTransportAIDriver:drive(dt)
	-- make sure we apply the unload offset when needed
	self:updateOffset()
		
	if self.loadingState == self.states.IS_LOADING then 
		self:hold()
		if not self:checkFillLevelsOk() then
			if self.trigger and self.trigger.isLoading then 
				self.trigger:setIsLoading(false)
			end
		end
		courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",math.floor(self:getTotalFillLevels(self.vehicle)),self.totalFillCapacity))
	end
	if self.loadingState == self.states.IS_UNLOADING then 
		self:hold()
	end
	courseplay:isUnloadingTriggerAvailable(self.vehicle)
	
	self:updateInfoText()
	self.ppc:update()
	self:checkLastWaypoint()
	AIDriver.driveCourse(self, dt)
	self:resetSpeed()
	

end
-- this one is not working ?????
function GrainTransportAIDriver:checkLastWaypoint()
	if self.ppc:reachedLastWaypoint() then
		if self:passedRunCounter() then 
			self:stop('END_POINT_MODE_1')
			self:debug('Last run (%d) finished, stopping.', self.runCounter)
			courseplay.debugVehicle(19, vehicle,'Last run (%d) finished, stopping.', self.runCounter)
		else 
			self.loadingState = self.states.IS_LOADING
			self:incrementRunCounter()
			self.ppc:initialize(1)
			self:debug('Finished run %d, continue with next.', self.runCounter)
			courseplay.debugVehicle(19, vehicle,'Finished run %d, continue with next.', self.runCounter)
		end	
	end
end

function GrainTransportAIDriver:updateLights()
	self.vehicle:setBeaconLightsVisibility(false)
end

function GrainTransportAIDriver:getCanShowDriveOnButton()
	return self.loadingState==self.states.IS_LOADING
end

function GrainTransportAIDriver:incrementRunCounter()
	if self.vehicle.cp.settings.runCounterMax:getIsRunCounterActive() then
		self.runCounter = self.runCounter + 1
	end
end

function GrainTransportAIDriver:passedRunCounter()
	return self.vehicle.cp.settings.runCounterMax:getIsRunCounterActive() and self.runCounter >= self.vehicle.cp.settings.runCounterMax:get()
end

function GrainTransportAIDriver:resetRunCounter()
	self.runCounter = 0
end

function GrainTransportAIDriver:checkFillLevelsOk()
	if self:getTotalFillLevelPercentage() < self.vehicle.cp.refillUntilPct then 
		return true 
	end
	return false
end

function GrainTransportAIDriver:getTotalFillLevelPercentage()
	local totalFillLevels = self:getTotalFillLevels(self.vehicle)
	return self.totalFillCapacity/totalFillLevels*100
end

function GrainTransportAIDriver:getTotalFillLevels(object,totalFillLevels)
	if totalFillLevels == nil then
		totalFillLevels = 0
	end
	if object.spec_trailer and object.spec_dischargeable then 
		local dischargeNode = object:getCurrentDischargeNode()
		totalFillLevels = totalFillLevels + object:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		totalFillLevels = self:getTotalFillLevels(impl.object,totalFillLevels)
	end
	return totalFillLevels
end

function GrainTransportAIDriver:getTotalFillCapacitys(object,totalFillCapacity)
	if totalFillCapacity == nil then
		totalFillCapacity = 0
	end
	if object.spec_trailer and object.spec_dischargeable then 
		local dischargeNode = object:getCurrentDischargeNode()
		totalFillCapacity = totalFillCapacity + object:getFillUnitCapacity(dischargeNode.fillUnitIndex)
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		totalFillCapacity = self:getTotalFillCapacitys(impl.object,totalFillCapacity)
	end
	return totalFillCapacity
end


function GrainTransportAIDriver:setLoadingState()
	self.loadingState=self.states.IS_LOADING
end

function GrainTransportAIDriver:resetLoadingState()
	if self:checkFillLevelsOk() then 
		CpManager:setGlobalInfoText(self.vehicle, 'FARM_SILO_IS_EMPTY')
	else
		self.trigger = nil
		self.loadingState = self.states.NOTHING
	end
end

function GrainTransportAIDriver:resetUnloadingState()
	self.loadingState=self.states.NOTHING
end

function GrainTransportAIDriver:setUnloadingState()
	self.loadingState=self.states.IS_UNLOADING
end
-- not sure if needed
function GrainTransportAIDriver:setTrigger(trigger)
	self.trigger = trigger
end


