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

---@class TriggerShovelAIDriver : ShovelAIDriver
TriggerShovelAIDriver = CpObject(ShovelAIDriver)

TriggerShovelAIDriver.MAX_SPEED_IN_LOADING_TRIGGER = 7
function TriggerShovelAIDriver:start(startingPoint)
	ShovelAIDriver.start(self,startingPoint)
	--- Make sure unloading at bunker silo is overwritten.
	self:changeSiloState(self.states.DRIVING_NORMAL_COURSE)
end

function TriggerShovelAIDriver:setHudContent()
	BunkerSiloAIDriver.setHudContent(self)
	courseplay.hud:setTriggerHandlerShovelModeAIDriverContent(self.vehicle)
end

function TriggerShovelAIDriver:driveUnloadingCourse(dt)
	if self:getSiloSelectedFillTypeSetting():isEmpty() then
		self:hold()
		self:setInfoText('NO_SELECTED_FILLTYPE')
	else 
		self:clearInfoText('NO_SELECTED_FILLTYPE')
	end
	--- Only allow loading near the first waypoint.
	if self:isNearFillPoint() then
		self.triggerHandler:enableFillTypeLoading()
		self:setSpeed(self.MAX_SPEED_IN_LOADING_TRIGGER)
	else 
		self.triggerHandler:disableFillTypeLoading()
	end
	ShovelAIDriver.driveUnloadingCourse(self)
end

function TriggerShovelAIDriver:onEndCourse()
	if self:isDrivingUnloadingCourse() then 
		--- Make sure unloading at bunker silo is overwritten,
		--- so we don't call BunkerSiloAIDriver.onEndCourse() here.
		AIDriver.onEndCourse(self)
	end
end

--- The course is always a loop course.
function TriggerShovelAIDriver:shouldStopAtEndOfCourse()
	return false
end

function TriggerShovelAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeShovelModeDriver
end

