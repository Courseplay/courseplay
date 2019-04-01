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

---@class BaleWrapperAIDriver : UnloadableFieldworkAIDriver
BaleWrapperAIDriver = CpObject(UnloadableFieldworkAIDriver)

function BaleWrapperAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'BaleWrapperAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self.baleWrapper = FieldworkAIDriver.getImplementWithSpecialization(vehicle, BaleWrapper)
end

function BaleWrapperAIDriver:driveFieldwork()
	if self.baleWrapper.spec_baleWrapper.baleWrapperState ~= BaleWrapper.STATE_NONE then
		self:setSpeed(0)
	end
	if self.baleWrapper.spec_baleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then --Unloads the baler wrapper combo
		self.baleWrapper:doStateChange(BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE)
	end
	UnloadableFieldworkAIDriver.driveFieldwork(self)
end
