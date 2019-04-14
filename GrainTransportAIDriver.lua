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
	self.runCounter = 0
	-- just for backwards compatibility
end

function GrainTransportAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setGrainTransportAIDriverContent(self.vehicle)
end

function GrainTransportAIDriver:start(ix)
	self.vehicle:setCruiseControlMaxSpeed(self.vehicle:getSpeedLimit() or math.huge)
	self:beforeStart()
	AIDriver.start(self, ix)
	self:setDriveUnloadNow(false);
end

function GrainTransportAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course for grain transport mode
	return false
end

function GrainTransportAIDriver:drive(dt)
	-- make sure we apply the unload offset when needed
	self:updateOffset()
	-- update current waypoint/goal point
	self.ppc:update()

	self:updateInfoText()

	-- RESET TRIGGER RAYCASTS from drive.lua.
	-- TODO: Not sure how raycast can be called twice if everything is coded cleanly.
	self.vehicle.cp.hasRunRaycastThisLoop['tipTrigger'] = false
	self.vehicle.cp.hasRunRaycastThisLoop['specialTrigger'] = false

	courseplay:updateFillLevelsAndCapacities(self.vehicle)

	-- should we give up control so some other code can drive?
	local giveUpControl = false
	-- should we keep driving?
	local allowedToDrive = self:checkLastWaypoint()

	-- TODO: are these checks really necessary?
	if self.vehicle.cp.totalFillLevel ~= nil
		and self.vehicle.cp.tipRefOffset ~= nil
		and self.vehicle.cp.workToolAttached then

		self:searchForTipTriggers()

		allowedToDrive = self:load(allowedToDrive)
		allowedToDrive, giveUpControl = self:onUnLoadCourse(allowedToDrive, dt)
	else
		self:debug('Safety check failed')
	end

	-- TODO: clean up the self.allowedToDrives above and use a local copy
	if self.state == self.states.STOPPED or not allowedToDrive then
		self:hold()
	end

	if giveUpControl then
		-- unload_tippers does the driving
		return
	else
		-- collision detection
		self:detectCollision(dt)
		-- we drive the course as usual
		self:driveCourse(dt)
	end
	self:resetSpeed()
end

function GrainTransportAIDriver:onWaypointChange(newIx)
	self:debug('On waypoint change %d', newIx)
	AIDriver.onWaypointChange(self, newIx)
	if self.course:isLastWaypointIx(newIx) then
		self:debug('Reaching last waypoint')
		self:setDriveUnloadNow(false);
	end
	-- Close cover after leaving the silo, assuming the silo is at waypoint 1
	if not self:hasTipTrigger() and not self:isNearFillPoint() then
		courseplay:openCloseCover(self.vehicle, courseplay.SHOW_COVERS)
	end
	
	--temp solution till load_tippers is refactored
	-- and we can have a non cyclic value that the loading process is finished
	if newIx == 4 and self:getDriveUnloadNow() then
		self:incrementRunCounter()
	end	
end

-- TODO: move this into onWaypointPassed() instead
function GrainTransportAIDriver:checkLastWaypoint()
	local allowedToDrive = true
	if self.ppc:getCurrentWaypointIx() == self.course:getNumberOfWaypoints() then
		courseplay:openCloseCover(self.vehicle, not courseplay.SHOW_COVERS)
		if self.runCounter >= self.vehicle.cp.maxRunNumber then
			-- stop at the last waypoint when the run counter expires
			allowedToDrive = false
			self:stop('END_POINT_MODE_1')
			self:debug('Last run (%d) finished, stopping.', self.runCounter)
		else
			-- continue at the first waypoint
			self.ppc:initialize(1)
			self:debug('Finished run %d, continue with next.', self.runCounter)
		end
	end
	return allowedToDrive
end

function GrainTransportAIDriver:load(allowedToDrive)
	-- Loading
	-- tippers are not full
	if self:isNearFillPoint() and self.vehicle.cp.totalFillLevel <= self.vehicle.cp.totalCapacity then
		allowedToDrive = courseplay:load_tippers(self.vehicle, allowedToDrive);
		courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",courseplay.utils:roundToLowerInterval(self.vehicle.cp.totalFillLevel, 100),self.vehicle.cp.totalCapacity));
		courseplay:openCloseCover(self.vehicle, not courseplay.SHOW_COVERS)
	end
	return allowedToDrive
end

function GrainTransportAIDriver:updateLights()
	self.vehicle:setBeaconLightsVisibility(false)
end

function GrainTransportAIDriver:getCanShowDriveOnButton()
	return self:isNearFillPoint()
end

function GrainTransportAIDriver:getIsRunCounterActive()
	return self.vehicle.cp.runCounterActive;
end

function GrainTransportAIDriver:incrementRunCounter()
	if self:getIsRunCounterActive() then
		self.runCounter = self.runCounter + 1
	end
end

function GrainTransportAIDriver:resetRunCounter()
	self.runCounter = 0
end