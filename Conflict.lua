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

--- A traffic conflict between two vehicles.
--- A conflict is created when the collision boxes of two vehicles overlap.
---@class Conflict
Conflict = CpObject()

-- a collision trigger must be present for at least so many milliseconds before it is considered for a conflict
Conflict.detectionThresholdMilliSec = 0
-- a collision trigger must be cleared for at least so many milliseconds before it is removed from a conflict
Conflict.clearThresholdMilliSecNormal = 1000
-- swerving does not require now a head-on conflict, so there's no need for this to be bigger
Conflict.clearThresholdMilliSecHeadOn = 1000
-- after maxAge seconds clear every conflict, this is to clean up if something got stuck for whatever reason
-- (like buggy programming)
Conflict.maxTriggerAge = 30000

function Conflict:init(vehicle, otherVehicle, triggerId, d, eta, otherD, otherEta, yRotDiff)
	self.debugChannel = courseplay.DBG_TRAFFIC
	self.vehicle = vehicle
	self.otherVehicle = otherVehicle
    self.triggers = {}
	-- need to count them ourselves as the triggers table is a hash, not an array
	self.nTriggers = 0
	-- we don't yet know who has the right of way in this conflict
	self.rightOfWayEvaluated = false
	self:onDetected(triggerId, d, eta, otherD, otherEta, yRotDiff)
	self:evaluateRightOfWay()
end

function Conflict:debug(...)
	courseplay.debugVehicle(self.debugChannel, self.vehicle,
			string.format('in conflict with %s: ', nameNum(self.otherVehicle)) .. string.format(...))
end

function Conflict:isVehicleInvolved(vehicle)
	return vehicle == self.vehicle or vehicle == self.otherVehicle
end

function Conflict:isBetween(vehicle, otherVehicle)
	if vehicle == self.vehicle and otherVehicle == self.otherVehicle then
		return true
	elseif vehicle == self.otherVehicle and otherVehicle == self.vehicle then
		return true
	else
		return false
	end
end

function Conflict:isWith(otherVehicle)
	return self.otherVehicle == otherVehicle
end

function Conflict:isCleared()
	return self.nTriggers < 1
end

function Conflict:onDetected(triggerId, d, eta, otherD, otherEta, yRotDiff)
	self.triggers[triggerId] = {d = d, eta = eta, otherD = otherD, otherEta = otherEta,
								yRotDiff = yRotDiff, detectedAt = g_time}
	self:update()
end

function Conflict:onCleared(triggerId)
	if not self.triggers[triggerId] then return end
	self.triggers[triggerId].timeCleared = g_time
	self:update()
end

function Conflict:getClearThresholdMilliSec()
	if self.headOn then
		return Conflict.clearThresholdMilliSecHeadOn
	else
		return Conflict.clearThresholdMilliSecNormal
	end
end

function Conflict:isTriggerStale(trigger)
	if g_time - trigger.detectedAt > Conflict.maxTriggerAge then
		-- this has been here for a while, check if other vehicle still has a conflict with us
		if self.otherVehicle.cp.driver and self.otherVehicle.cp.driver:haveConflictWith(self.vehicle) then
			courseplay.infoVehicle(self.vehicle, 'removing stale conflict with %s', nameNum(self.otherVehicle))
			return true
		end
	end
	return false
end

function Conflict:update()
	local minEta = math.huge
	self.nTriggers = 0
	local triggersToRemove = {}
	for id, trigger in pairs(self.triggers) do
		local stale = self:isTriggerStale(trigger)
		if not trigger.timeCleared and not stale and trigger.eta < minEta and g_time - trigger.detectedAt > Conflict.detectionThresholdMilliSec then
			self.closestTrigger = trigger
			minEta = self.closestTrigger.eta
		end
		self.nTriggers = self.nTriggers + 1
		if (trigger.timeCleared and g_time - trigger.timeCleared > self:getClearThresholdMilliSec()) or stale then
			-- been cleared long ago or too old, mark for removal
			table.insert(triggersToRemove, id)
			self.nTriggers = self.nTriggers - 1
		end
	end
	-- remove cleared triggers
	for _, id in pairs(triggersToRemove) do
		self.triggers[id] = nil
	end
end

function Conflict:getDistance()
	if self.closestTrigger then
		return self.closestTrigger.d, self.closestTrigger.eta
	else
		return math.huge, math.huge
	end
end

function Conflict:getConflictingVehicle()
	return self.otherVehicle
end

function Conflict:__tostring()
	local result = string.format('Traffic conflict: %s <-> %s %d triggers', self.vehicle:getName(), self.otherVehicle:getName(), self.nTriggers)
	if self.closestTrigger then
		result = string.format('%s, closest %.1f m %d sec %.1f° ', result, self.closestTrigger.d or -1, self.closestTrigger.eta or -1,
				self.closestTrigger.yRotDiff and math.deg(self.closestTrigger.yRotDiff) or 0)
	end
	return result
end

--- Decide who has the right of way
function Conflict:evaluateRightOfWay()
	-- already know, never re-evaluate
	self:debug('Evaluating right-of-way, closest conflict %s, evaluated %s', tostring(self), self.rightOfWayEvaluated)
	if self.rightOfWayEvaluated == true then return end
	if self.closestTrigger then
		if math.abs(self.closestTrigger.yRotDiff) < math.rad(45) then
			-- one vehicle is behind the other, hold the one behind, let the one on the front drive...
			if AIDriverUtil.isBehindOtherVehicle(self.vehicle, self.otherVehicle) then
				self.mustYield = true
				self:debug('behind other vehicle, I must yield')
			else
				self.mustYield = false
				self:debug('in front of other vehicle, I have right of way')
			end
		else
			-- vehicles crossing paths, decide on priority
			if self.vehicle.cp.driver:is_a(CombineUnloadAIDriver) and
					self.otherVehicle.cp.driver:is_a(CombineAIDriver) then
				self.mustYield = true
				self:debug('I am unloader, other vehicle is combine, I must yield')
			elseif self.otherVehicle.cp.driver:is_a(CombineUnloadAIDriver) and
					self.vehicle.cp.driver:is_a(CombineAIDriver) then
				self.mustYield = false
				self:debug('I am combine, other vehicle is unloader, I have right of way')
			else
				self.mustYield = false
				self:debug('I detected the conflict first, I have right of way')
			end
			if math.abs(self.closestTrigger.yRotDiff) > math.rad(110) then
				-- head on conflict, the proximity sensor will take care of this
				self:debug('head on conflict')
				self.headOn = true
			end
		end
		if self.otherVehicle.cp.driver then
			-- tell the other vehicle the result of our decision. Whoever gets here first, makes the decision
			-- about the right of way for both participants of the conflict
			self.otherVehicle.cp.driver:onRightOfWayEvaluated(self.vehicle, not self.mustYield, self.headOn)
		end
	end
end

-- The other vehicle in the conflict just decided who has the right of way
function Conflict:onRightOfWayEvaluated(mustYield, headOn)
	self.mustYield = mustYield
	self.headOn = headOn
	self.rightOfWayEvaluated = true
end

