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

---@class BaleWrapperAIDriver : BalerAIDriver
BaleWrapperAIDriver = CpObject(BalerAIDriver)

function BaleWrapperAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'BaleWrapperAIDriver:init()')
	-- the only reason this is derived from BalerAIDriver is that some wrappers are also balers. Our concept
	-- derived classes may not fly when there are multiple specializations to handle, if we had a bale loader
	-- which is also a bale wrapper then we would probably have to put everything back into the baler.
	BalerAIDriver.init(self, vehicle)
	self.baleWrapper = FieldworkAIDriver.getImplementWithSpecialization(vehicle, BaleWrapper)
end

function BaleWrapperAIDriver:driveFieldwork()
	-- Don't drop the bale in the turn
	if not self.turnIsDriving then
		-- stop while wrapping only if we deon't have a baler. If we do we should continue driving and working
		-- on the next bale, the baler code will take care about stopping if we need to
		if self.baleWrapper.spec_baleWrapper.baleWrapperState ~= BaleWrapper.STATE_NONE and not self.baler then
			self:setSpeed(0)
		end
		-- Yes, Giants has a typo in the state
		if self.baleWrapper.spec_baleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
			self.baleWrapper:doStateChange(BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE)
		end
	end
	BalerAIDriver.driveFieldwork(self)
end
