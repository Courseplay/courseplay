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

GrainTransportAIDriver = CpObject(AIDriver)

--- Constructor
function GrainTransportAIDriver:init(vehicle)
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_GRAIN_TRANSPORT
	self.runCounter = 0
end

function GrainTransportAIDriver:start(ix)
	AIDriver.start(self, ix)
	self.runCounter = 0
end

function GrainTransportAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course for grain transport mode
	return false
end

function GrainTransportAIDriver:drive(dt)
	-- update current waypoint/goal point
	--print("GrainTransportAIDriver:drive(dt)")
	self.ppc:update()

	if self.isStopped then self:idle() return end

	local lx, lz = self:getDirectionToGoalPoint()
	-- should we keep driving?
	local allowedToDrive = self:checkLastWaypoint()

	-- RESET TRIGGER RAYCASTS from drive.lua. 
	-- TODO: Not sure how raycast can be called twice if everything is coded cleanly.
	self.vehicle.cp.hasRunRaycastThisLoop['tipTrigger'] = false
	self.vehicle.cp.hasRunRaycastThisLoop['specialTrigger'] = false

	courseplay:updateFillLevelsAndCapacities(self.vehicle)

	local giveUpControl = false

	-- TODO: are these checks really necessary?
	if self.vehicle.cp.totalFillLevel ~= nil
		and self.vehicle.cp.tipRefOffset ~= nil
		and self.vehicle.cp.workToolAttached then

		self:searchForTipTrigger(lx, lz)

		allowedToDrive = self:load(allowedToDrive)
		allowedToDrive, giveUpControl = self:unLoad(allowedToDrive, dt)
	else
		self:debug('Safety check failed')
	end

	if giveUpControl then
		-- unload_tippers does the driving
		return
	else
		-- we drive the course as usual
		self:driveCourse(dt, allowedToDrive)
	end
end

function GrainTransportAIDriver:onWaypointChange(newIx)
	self:debug('On waypoint change %d', newIx)
	AIDriver.onWaypointChange(self, newIx)
	if self.course:isLastWaypointIx(newIx) then
		self:debug('Reaching last waypoint')
		-- this is needed to trigger the loading. No idea why. No idea what isLoaded specifically means,
		-- no idea why start_stop.start sets it to true. frustrating
		courseplay:setIsLoaded(self.vehicle, false);
		courseplay:changeRunCounter(self.vehicle, false)
	end
end

function GrainTransportAIDriver:hasTipTrigger()
	-- TODO: come up with something better?
	return self.vehicle.cp.currentTipTrigger ~= nil
end

function GrainTransportAIDriver:isNearFillPoint()
	-- TODO: like above, we may have some better indication of this
	return self.ppc:getCurrentWaypointIx() >= 1 and self.ppc:getCurrentWaypointIx() <= 3
end

function GrainTransportAIDriver:getSpeed()
	if self:hasTipTrigger() then
		-- slow down around the tip trigger
		if self:getIsInBunksiloTrigger() then
			return self.vehicle.cp.speeds.reverse
		else
			return 10
		end
	else
		return AIDriver.getSpeed(self)
	end
end

function GrainTransportAIDriver:getIsInBunksiloTrigger()
	return self.vehicle.cp.backupUnloadSpeed ~= nil
end

function GrainTransportAIDriver:checkLastWaypoint()
	local allowedToDrive = true
	if self.ppc:reachedLastWaypoint() then
		if self.vehicle.cp.stopAtEnd and self.runCounter >= self.vehicle.cp.runNumber then
			-- stop at the last waypoint when the run counter expires
			allowedToDrive = false
			self.vehicle.cp.runReset = true;
			self:stop('END_POINT_MODE_1')
			self:debug('Mode 1 has tried to stop')
		else
			-- continue at the first waypoint
			self.ppc:initialize(1)
			-- Don't make life too complicated. Whenever we restart the course, we just
			-- increment the run counter
			self.runCounter = self.runCounter + 1
			-- .. and then brutally, just for backwards compatibility
			self.vehicle.cp.runCounter = self.runCounter
			self:debug('Finished run %d, continue with next.', self.runCounter)
		end
	end
	return allowedToDrive
end

function GrainTransportAIDriver:searchForTipTrigger(lx, lz)
	if not self.vehicle.cp.hasAugerWagon
		and not self:hasTipTrigger()
		and self.vehicle.cp.totalFillLevel > 0
		and self.ppc:getCurrentWaypointIx() > 2
		and not self.ppc:reachedLastWaypoint()
		and not self.ppc:isReversing() then
		local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, lx, -0.1, lz)
		-- raycast start point in front of vehicle
		local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1, 3)
		courseplay:doTriggerRaycasts(self.vehicle, 'tipTrigger', 'fwd', true, x, y, z, nx, ny, nz)
	end
end

function GrainTransportAIDriver:load(allowedToDrive)
	-- Loading
	-- tippers are not full TODO: this condition smells, should be refactored. Totally confusing isLoaded/isUnloaded?
	if ((self.vehicle.cp.isLoaded and self.vehicle.cp.trailerFillDistance) or self.vehicle.cp.isLoaded ~= true)
		and
		((self:isNearFillPoint()
			and self.vehicle.cp.totalFillLevel < self.vehicle.cp.totalCapacity
			and self.vehicle.cp.isUnloaded == false)
		or self.vehicle.cp.trailerFillDistance) then
		allowedToDrive = courseplay:load_tippers(self.vehicle, allowedToDrive);
		courseplay:setInfoText(self.vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",courseplay.utils:roundToLowerInterval(self.vehicle.cp.totalFillLevel, 100),self.vehicle.cp.totalCapacity));
	end
	return allowedToDrive
end

function GrainTransportAIDriver:unLoad(allowedToDrive, dt)
	-- Unloading
	local takeOverSteering = false

	-- If we are an auger wagon, we don't have a tip point, so handle it as an auger wagon in mode 3
	-- This should be in drive.lua on line 305 IMO --pops64
	if self.vehicle.cp.hasAugerWagon then
		courseplay:handleMode3(self.vehicle, allowedToDrive, dt);
	else
		-- done tipping?
		if self:hasTipTrigger() and self.vehicle.cp.totalFillLevel == 0 then
			courseplay:resetTipTrigger(self.vehicle, true);
		end

		self:cleanUpMissedTriggerExit()

		-- tipper is not empty and tractor reaches TipTrigger
		if self.vehicle.cp.totalFillLevel > 0
			and self:hasTipTrigger()
			and not self:isNearFillPoint() then
			allowedToDrive, takeOverSteering = courseplay:unload_tippers(self.vehicle, allowedToDrive, dt);
			courseplay:setInfoText(self.vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
		end
	end
	return allowedToDrive, takeOverSteering;
end;

function GrainTransportAIDriver:cleanUpMissedTriggerExit() -- at least that's what it seems to be doing
	-- damn, I missed the trigger!
	if self:hasTipTrigger() then
		local t = self.vehicle.cp.currentTipTrigger;
		local trigger_id = t.triggerId;

		if t.specialTriggerId ~= nil then
			trigger_id = t.specialTriggerId;
		end;
		if t.isPlaceableHeapTrigger then
			trigger_id = t.rootNode;
		end;

		if trigger_id ~= nil then
			local trigger_x, _, trigger_z = getWorldTranslation(trigger_id)
			local ctx, _, ctz = getWorldTranslation(self.vehicle.cp.DirectionNode)
			local distToTrigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z)

			-- Start reversing value is to check if we have started to reverse
			-- This is used in case we already registered a tipTrigger but changed the direction and might not be in that tipTrigger when unloading. (Bug Fix)
			local startReversing = self.course:switchingToReverseAt(self.ppc:getCurrentWaypointIx() - 1)
			if startReversing then
				courseplay:debug(string.format("%s: Is starting to reverse. Tip trigger is reset.", nameNum(self.vehicle)), 13);
			end

			local isBGA = t.bunkerSilo ~= nil
			local triggerLength = Utils.getNoNil(self.vehicle.cp.currentTipTrigger.cpActualLength, 20)
			local maxDist = isBGA and (self.vehicle.cp.totalLength + 55) or (self.vehicle.cp.totalLength + triggerLength);
			if distToTrigger > maxDist or startReversing then --it's a backup, so we don't need to care about +/-10m
				courseplay:resetTipTrigger(self.vehicle)
				courseplay:debug(string.format("%s: distance to currentTipTrigger = %d (> %d or start reversing) --> currentTipTrigger = nil", nameNum(self.vehicle), distToTrigger, maxDist), 1);
			end
		else
			courseplay:resetTipTrigger(self.vehicle)
		end;
	end;
end