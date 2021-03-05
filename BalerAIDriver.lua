--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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

---@class BalerAIDriver : UnloadableFieldworkAIDriver
BalerAIDriver = CpObject(UnloadableFieldworkAIDriver)

function BalerAIDriver:init(vehicle)
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER,vehicle,'BalerAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self.slowDownFillLevel = 200
    self.slowDownStartSpeed = 20
end

function BalerAIDriver:driveFieldwork(dt)
	-- this is due to the derived BaleWrapperAIDriver, not all bale wrappers are balers at the same time
	-- so handle balers only if we really have one.
	if self.baler then
		self:handleBaler()
	end
	return UnloadableFieldworkAIDriver.driveFieldwork(self, dt)
end

function BalerAIDriver:start(startingPoint)
	UnloadableFieldworkAIDriver.start(self,startingPoint)
	self:initializeBaler()
end

function BalerAIDriver:initializeBaler()
	self.baler = AIDriverUtil.getAIImplementWithSpecialization(self.vehicle, Baler)
	if self.baler then
		self.balerSpec = self.baler.spec_baler
		--use giants automaticDrop, so we don't have to do it
		if self.balerSpec then
			self.oldAutomaticDrop = self.balerSpec.automaticDrop
			self.balerSpec.automaticDrop = true
		end
	end
end

function BalerAIDriver:dismiss()
	UnloadableFieldworkAIDriver.dismiss(self)
	--revert possible change for the player to default 
	if self.balerSpec then
		self.balerSpec.automaticDrop = self.oldAutomaticDrop
	end
end

function BalerAIDriver:allFillLevelsOk()
	-- always fine, we'll stop when needed in driveFieldwork()
	return true
end

function BalerAIDriver:isHandlingAllowed()
	if self.fieldworkState == self.states.ON_CONNECTING_TRACK or
		self.fieldworkState == self.states.TEMPORARY or self.fieldworkState == self.states.TURNING then
		return false
	end
	return true
end

function BalerAIDriver:handleBaler()
	-- turn.lua will raise/lower as needed, don't touch the balers while the turn maneuver is executed or while on temporary alignment / connecting track
	if not self:isHandlingAllowed() then return end
	
	if not self.baler:getIsTurnedOn() then 
		if self.baler:getCanBeTurnedOn() then
			self.baler:setIsTurnedOn(true, false); 
		else --maybe this line is enough to handle bale dropping and waiting ?
			self:setSpeed(0)
			--baler needs refilling of some sort (net,...)
			if self.balerSpec.unloadingState == Baler.UNLOADING_CLOSED then 
				CpManager:setGlobalInfoText(self.vehicle, 'NEEDS_REFILLING');
			end
		end
	end

	if self.baler.setPickupState ~= nil then -- lower pickup after unloading
		if self.baler.spec_pickup ~= nil and not self.baler.spec_pickup.isLowered then
			self.baler:setPickupState(true, false)
			self:debug('lowering baler pickup')
		end
	end
	
	local fillLevel = self.baler:getFillUnitFillLevel(self.balerSpec.fillUnitIndex)
	local capacity = self.baler:getFillUnitCapacity(self.balerSpec.fillUnitIndex)
	
	if not self.balerSpec.nonStopBaling and (self.balerSpec.baleUnloadAnimationName ~= nil or self.balerSpec.allowsBaleUnloading) then	
		self:debugSparse("baleUnloadAnimationName: %s, allowsBaleUnloading: %s, nonStopBaling:%s",tostring(self.balerSpec.baleUnloadAnimationName),tostring(self.balerSpec.allowsBaleUnloading),tostring(self.balerSpec.nonStopBaling))
		--copy of giants code:  AIDriveStrategyBaler:getDriveData(dt, vX,vY,vZ) to avoid leftover when full
		local freeFillLevel = capacity - fillLevel
		if freeFillLevel < self.slowDownFillLevel then
			maxSpeed = 2 + (freeFillLevel / self.slowDownFillLevel) * self.slowDownStartSpeed
			self:setSpeed(maxSpeed)
		end
		
		--baler is full or is unloading so wait!
		if fillLevel == capacity or self.balerSpec.unloadingState ~= Baler.UNLOADING_CLOSED then
			self:setSpeed(0)
		end
	end
	return true
end
