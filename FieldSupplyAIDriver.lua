
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
--[[
Field Supply AI Driver to let fill tools with digestate or liquid manure on the field egde
Also known as mode 8
]]

---@class FieldSupplyAIDriver : FillableFieldworkAIDriver
FieldSupplyAIDriver = CpObject(FillableFieldworkAIDriver)

FieldSupplyAIDriver.myStates = {
	ON_REFILL_COURSE = {},
	WAITING_FOR_GETTING_UNLOADED = {}
}

--- Constructor
function FieldSupplyAIDriver:init(vehicle)
	FillableFieldworkAIDriver.init(self, vehicle)
	self:initStates(FieldSupplyAIDriver.myStates)
	self.supplyState = self.states.ON_REFILL_COURSE
	--self.mode = courseplay.MODE_BUNKERSILO_COMPACTER
	self:setHudContent()
end

function FieldSupplyAIDriver:setHudContent()
	courseplay.hud:setFieldSupplyAIDriverContent(self.vehicle)
end

function FieldSupplyAIDriver:start(startingPoint)
	self:beforeStart()
	self.course = Course(self.vehicle, self.vehicle.Waypoints)
	local ix = self.course:getStartingWaypointIx(AIDriverUtil.getDirectionNode(self.vehicle), startingPoint)
	self.ppc:setCourse(self.course)
	self.ppc:initialize(ix)
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
	self.refillState = self.states.REFILL_DONE
	AIDriver.continue(self)
end

function FieldSupplyAIDriver:stop(msgReference)
	-- TODO: revise why FieldSupplyAIDriver is derived from FieldworkAIDriver, as it has no fieldwork course
	-- so this override would not be necessary.
	AIDriver.stop(self, msgReference)
end


function FieldSupplyAIDriver:drive(dt)
	-- update current waypoint/goal point
	self.allowedToDrive = true
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	if self.supplyState == self.states.ON_REFILL_COURSE  then
		FillableFieldworkAIDriver.driveUnloadOrRefill(self)
		AIDriver.drive(self, dt)
	elseif self.supplyState == self.states.WAITING_FOR_GETTING_UNLOADED then
		self:stopAndWait(dt)
		-- unload into a FRC if there is one
		AIDriver.tipIntoStandardTipTrigger(self)
		--if i'm empty or fillLevel is below threshold then drive to get new stuff
		if self:isFillLevelToContinueReached() then
			self:continue()
		end
	end
end

function FieldSupplyAIDriver:continue()
	self:changeSupplyState(self.states.ON_REFILL_COURSE )
	self.state = self.states.RUNNING
end

function FieldSupplyAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	--- Check if we are at the last waypoint and should we continue with first waypoint of the course
	-- or stop.
	if ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	elseif self.course:isWaitAt(ix) then
		-- show continue button
		self.state = self.states.STOPPED
		self:refreshHUD()
		self:changeSupplyState(self.states.WAITING_FOR_GETTING_UNLOADED)

	end
end

function FieldSupplyAIDriver:changeSupplyState(newState)
	self.supplyState = newState;
end

function FieldSupplyAIDriver:isFillLevelToContinueReached()
	local fillLevelInformations ={}
	for _, workTool in pairs (self.vehicle.cp.workTools) do
		workTool:getFillLevelInformation(fillLevelInformations)
	end
	local fillLevel = 0
	local capacity =  0
	for _, fillTypeInfo in pairs(fillLevelInformations) do
		fillLevel = fillTypeInfo.fillLevel
		capacity = fillTypeInfo.capacity
	end
	local fillLevelPercent = (fillLevel/capacity) *100
	if fillLevelPercent < self.vehicle.cp.driveOnAtFillLevel and self:levelDidNotChange(fillLevelPercent) then
		return true
	end
end

function FieldSupplyAIDriver:levelDidNotChange(fillLevelPercent)
	--fillLevel changed in last loop-> start timer
	if self.prevFillLevelPct == nil or self.prevFillLevelPct ~= fillLevelPercent then
		self.prevFillLevelPct = fillLevelPercent
		courseplay:setCustomTimer(self.vehicle, "fillLevelChange", 3);
	end
	--if time is up and no fillLevel change happend, return true
	if courseplay:timerIsThrough(self.vehicle, "fillLevelChange",false) then
		if self.prevFillLevelPct == fillLevelPercent then
			return true
		end
		courseplay:resetCustomTimer(self.vehicle, "fillLevelChange",true);
	end
end

function FieldSupplyAIDriver:stopAndWait(dt)
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, false, fwd, 0, 1, 0, 1)
end

