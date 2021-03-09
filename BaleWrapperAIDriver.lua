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
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER,vehicle,'BaleWrapperAIDriver:init()')
	-- the only reason this is derived from BalerAIDriver is that some wrappers are also balers. Our concept
	-- derived classes may not fly when there are multiple specializations to handle, if we had a bale loader
	-- which is also a bale wrapper then we would probably have to put everything back into the baler.
	BalerAIDriver.init(self, vehicle)
end

function BaleWrapperAIDriver:start(startingPoint)
	BalerAIDriver.start(self,startingPoint)
	self:initializeBaleWrapper()
end

function BaleWrapperAIDriver:initializeBaleWrapper()
	self.baleWrapper = AIDriverUtil.getAIImplementWithSpecialization(self.vehicle, BaleWrapper)

	if not self.baler and self.baleWrapper then
		-- Bale wrappers which aren't balers have no AI markers as they have no pick up so add a function here
		-- to get the markers
		self.baleWrapper.getAIMarkers = function(object)
			return UnloadableFieldworkAIDriver.getAIMarkersFromGrabberNode(object, object.spec_baleWrapper)
		end
	end
end

function BaleWrapperAIDriver:driveFieldwork(dt)
	-- Don't drop the bale in the turn or on temporary alignment or connecting tracks
	if self:isHandlingAllowed() then
		self:handleBaleWrapper()
	end
	return BalerAIDriver.driveFieldwork(self, dt)
end


function BaleWrapperAIDriver:handleBaleWrapper()
	-- stop while wrapping only if we don't have a baler. If we do we should continue driving and working
	-- on the next bale, the baler code will take care about stopping if we need to
	if self.baleWrapper.spec_baleWrapper.baleWrapperState ~= BaleWrapper.STATE_NONE and not self.baler then
		self:setSpeed(0)
	end
	-- Yes, Giants has a typo in the state
	if self.baleWrapper.spec_baleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
		local loweringDropTime, turnDropTime
		-- inserts unload threshold after lowering the implement, useful after e.g. transition from connecting track to fieldwork
		if self.fieldworkState == self.states.WAITING_FOR_LOWER then
			local unloadThreshold = 2500 --delay in msecs, 2.5 secs seems to work well
			loweringDropTime = self.vehicle.timer + unloadThreshold
		elseif loweringDropTime == nil then
			loweringDropTime = 0
		end
		-- inserts unload threshold after turn so bales don't drop on headlands
		if self.turnStartedAt and self.realTurnDurationMs then
			local unloadThreshold = 4000 --delay in msecs, 4 secs seems to work well
			turnDropTime = self.turnStartedAt + self.realTurnDurationMs + unloadThreshold
		else
			turnDropTime = 0 --avoids problems in case of condition variables not existing / empty e.g. before the first turn
		end
		if self.vehicle.timer > math.max(loweringDropTime,turnDropTime) then --chooses the bigger delay
			self.baleWrapper:doStateChange(BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE)
		end
	end
end