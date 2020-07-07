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

--- Constructor
function GrainTransportAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'GrainTransportAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_GRAIN_TRANSPORT
	self.loadingState = self.states.NOTHING
	self.runCounter = 0
	self.totalFillCapacity = 0
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
	local totalFillCapacity = {} --fix these table to int ??
	self:getTotalFillCapacitys(self.vehicle,totalFillCapacity)
	self.totalFillCapacity = totalFillCapacity.fillCapacity
	courseplay.debugVehicle(19, vehicle,'totalFillCapacity: %d',self.totalFillCapacity)
--	courseplay.debugVehicle(19, vehicle,'Last run (%d) finished, stopping.', self.runCounter)
	--probably do TriggerRaycast: onStay -> openCover ??
	courseplay:openCloseCover(self.vehicle, true) --check if we are already in trigger on start --????
	AIDriver.start(self, startingPoint)
	self.vehicle.cp.settings.stopAtEnd:set(false) -- should be used for runcounter!
--	courseplay:isTriggerAvailable(self.vehicle) -- temp solution to check on start if under trigger
end

function GrainTransportAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course for grain transport mode
	return false
end

function GrainTransportAIDriver:drive(dt)
	-- make sure we apply the unload offset when needed
	self:updateOffset()
	
	if self.loadingState == self.states.IS_LOADING then 
		if self:checkFillLevelsOk() then
			self:resetLoadingState(object)
		end
	end
	AIDriver.drive(self, dt)
end

function GrainTransportAIDriver:onLastWaypoint()
	if not self.vehicle.cp.settings.siloSelectedFillType:isActive() then
		
		self:setLoadingState()
	else
	
	end
	AIDriver.onLastWaypoint(self)
--[[	
	if self:passedRunCounter() then 
		--self:stop('END_POINT_MODE_1') --should be called in AIDriver:onLastWaypoint
		self:debug('Last run (%d) finished, stopping.', self.runCounter)
		courseplay.debugVehicle(19, vehicle,'Last run (%d) finished, stopping.', self.runCounter)
	else 
		if not self.vehicle.cp.settings.siloSelectedFillType:isActive() then
			self:setLoadingState()
		end
	--	self:incrementRunCounter()
	--	self:checkRunCounter()
		self:debug('Finished run %d, continue with next.', self.runCounter)
		courseplay.debugVehicle(19, vehicle,'Finished run %d, continue with next.', self.runCounter)
	end	
	AIDriver.onLastWaypoint(self)]]--
end

function GrainTransportAIDriver:checkRunCounter()
	if self:passedRunCounter() then 
		self.vehicle.cp.settings.stopAtEnd:set(true)
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
	if self:getTotalFillLevelPercentage() >= self.vehicle.cp.settings.refillUntilPct:get() then 
		return true 
	end
	return false
end

function GrainTransportAIDriver:getTotalFillLevelPercentage()
	local totalFillLevels = {}
	self:getTotalFillLevels(self.vehicle,totalFillLevels)
--	courseplay.debugVehicle(19, vehicle,'totalFillLevel: %d',totalFillLevels.fillLevel)
	return (totalFillLevels.fillLevel/self.totalFillCapacity)*100
end

function GrainTransportAIDriver:getTotalFillLevels(object,totalFillLevels)
	if totalFillLevels.fillLevel == nil then 
		totalFillLevels.fillLevel = 0
	end
	if object.spec_trailer and object.spec_dischargeable then 
		local dischargeNode = object:getCurrentDischargeNode()
		totalFillLevels.fillLevel = totalFillLevels.fillLevel + object:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getTotalFillLevels(impl.object,totalFillLevels)
	end
end

function GrainTransportAIDriver:getTotalFillCapacitys(object,totalFillCapacity)
	if totalFillCapacity.fillCapacity == nil then 
		totalFillCapacity.fillCapacity = 0
	end
	if object.spec_trailer and object.spec_dischargeable then 
		local dischargeNode = object:getCurrentDischargeNode()
		totalFillCapacity.fillCapacity = totalFillCapacity.fillCapacity + object:getFillUnitCapacity(dischargeNode.fillUnitIndex)
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getTotalFillCapacitys(impl.object,totalFillCapacity)
	end
end


