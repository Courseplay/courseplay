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
	courseplay.debugVehicle(11,vehicle,'BalerAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self.baler = FieldworkAIDriver.getImplementWithSpecialization(vehicle, Baler)
end

function BalerAIDriver:driveFieldwork()
	-- this is due to the derived BaleWrapperAIDriver, not all bale wrappers are balers at the same time
	-- so handle balers only if we really have one.
	if self.baler then
		self:handleBaler()
	end
	UnloadableFieldworkAIDriver.driveFieldwork(self)
end

function BalerAIDriver:allFillLevelsOk()
	-- always fine, we'll stop when needed in driveFieldwork()
	return true
end

function BalerAIDriver:handleBaler()
	-- turn.lua will raise/lower as needed, don't touch the balers while the turn maneuver is executed
	if self.turnIsDriving then return end

	--if vehicle.cp.waypointIndex >= vehicle.cp.startWork + 1 and vehicle.cp.waypointIndex < vehicle.cp.stopWork and vehicle.cp.turnStage == 0 then
	--  vehicle, self.baler, unfold, lower, turnOn, allowedToDrive, cover, unload, ridgeMarker,forceSpeedLimit,workSpeed)
	local specialTool, allowedToDrive, stoppedForReason = courseplay:handleSpecialTools(self.vehicle, self.baler, true, true, true, true, nil, nil, nil);
	if not specialTool then
		-- automatic opening for balers
		local capacity = self.baler.cp.capacity
		local fillLevel = self.baler.cp.fillLevel
		if self.baler.spec_baler ~= nil then

			--print(string.format("if courseplay:isRoundbaler(self.baler)(%s) and fillLevel(%s) > capacity(%s) * 0.9 and fillLevel < capacity and self.baler.spec_baler.unloadingState(%s) == Baler.UNLOADING_CLOSED(%s) then",
			--tostring(courseplay:isRoundbaler(self.baler)),tostring(fillLevel),tostring(capacity),tostring(self.baler.spec_baler.unloadingState),tostring(Baler.UNLOADING_CLOSED)))
			if courseplay:isRoundbaler(self.baler) and fillLevel > capacity * 0.9 and fillLevel < capacity and self.baler.spec_baler.unloadingState == Baler.UNLOADING_CLOSED then
				if not self.baler.spec_turnOnVehicle.isTurnedOn and not stoppedForReason then
					self.baler:setIsTurnedOn(true, false);
				end;
				self:setSpeed(self.vehicle.cp.speeds.turn)
			elseif fillLevel >= capacity and self.baler.spec_baler.unloadingState == Baler.UNLOADING_CLOSED then
				allowedToDrive = false;
				if #(self.baler.spec_baler.bales) > 0 and self.baler.spec_baleWrapper == nil then --Ensures the baler wrapper combo is empty before unloading
					self.baler:setIsUnloadingBale(true, false)
				end
			elseif self.baler.spec_baler.unloadingState ~= Baler.UNLOADING_CLOSED then
				allowedToDrive = false
				if self.baler.spec_baler.unloadingState == Baler.UNLOADING_OPEN then
					self.baler:setIsUnloadingBale(false)
				end
			elseif fillLevel >= 0 and not self.baler:getIsTurnedOn() and self.baler.spec_baler.unloadingState == Baler.UNLOADING_CLOSED then
				self.baler:setIsTurnedOn(true, false);
			end
		end
		if self.baler.setPickupState ~= nil then
			if self.baler.spec_pickup ~= nil and not self.baler.spec_pickup.isLowered then
				self.baler:setPickupState(true, false);
				courseplay:debug('lowering baler pickup')
			end;
		end;
	end
	if not allowedToDrive then
		self:setSpeed(0)
	end

	return true
end