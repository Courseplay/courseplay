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
Fieldwork AI Driver

Can follow a fieldworking course, perform turn maneuvers, turn on/off and raise/lower implements,
add adjustment course if needed.
]]

---@class FieldworkAIDriver : AIDriver
FieldworkAIDriver = CpObject(AIDriver)

FieldworkAIDriver.myStates = {
	FIELDWORK = {},
	UNLOAD_OR_REFILL = {},
	ON_CONNECTING_TRACK = {},
	HELD = {},
	WAITING_FOR_LOWER = {},
	WAITING_FOR_RAISE = {}
}

-- Our class implementation does not call the constructor of base classes
-- through multiple level of inheritances therefore we must explicitly call
-- the base class ctr.
function FieldworkAIDriver:init(vehicle)
	AIDriver.init(self, vehicle)
	self:initStates(FieldworkAIDriver.myStates)
	-- waiting for tools to turn on, unfold and lower
	self.waitingForTools = true
	self.speed = 0
	self.debugChannel = 14
	-- waypoint index on main (fieldwork) course where we aborted the work before going on
	-- an unload/refill course
	self.fieldworkAbortedAtWaypoint = 1
end

--- Start the course and turn on all implements when needed
function FieldworkAIDriver:start(ix)
	-- stop at the last waypoint by default
	self.vehicle.cp.stopAtEnd = true

	self:setUpCourses()

	self.waitingForTools = true
	-- on which course are we starting?
	-- the ix we receive here is the waypoint index in the fieldwork course and the unload/fill
	-- course concatenated.
	if ix > self.fieldworkCourse:getNumberOfWaypoints() then
		-- beyond the first, fieldwork course: we are on the unload/refill part
		self:changeToUnloadOrRefill()
		self:startCourseWithAlignment(self.unloadRefillCourse, ix - self.fieldworkCourse:getNumberOfWaypoints())
	else
		-- we are on the fieldwork part
		if self:startCourseWithAlignment(self.fieldworkCourse, ix) then
			self.state = self.states.FIELDWORK
			self.fieldWorkState = self.states.ALIGNMENT
		else
			self:changeToFieldwork()
		end

	end
end

function FieldworkAIDriver:stop(msgReference)
	self:stopWork()
	AIDriver.stop(self, msgReference)
end

function FieldworkAIDriver:drive(dt)
	if self.state == self.states.FIELDWORK then
		self:driveFieldwork()
	elseif self.state == self.states.UNLOAD_OR_REFILL then
		if self.alignmentCourse then
			-- use the courseplay speed limit for fields
			self.speed = self.vehicle.cp.speeds.field
		else
			-- just drive normally
			self.speed = self.vehicle.cp.speeds.street
		end
	end

	AIDriver.drive(self, dt)
end

function FieldworkAIDriver:changeToFieldwork()
	self:debug('change to fieldwork')
	self.state = self.states.FIELDWORK
	self.fieldWorkState = self.states.WAITING_FOR_LOWER
	self:startWork()
end

function FieldworkAIDriver:changeToUnloadOrRefill()
	self:stopWork()
	self.state = self.states.UNLOAD_OR_REFILL
	self:debug('changing to unload/refill course (%d waypoints)', self.unloadRefillCourse:getNumberOfWaypoints())
end

function FieldworkAIDriver:onEndAlignmentCourse()
	if self.state == self.states.FIELDWORK then
		self:debug('starting fieldwork')
		self.fieldWorkState = self.states.WAITING_FOR_LOWER
		self:startWork()
	end
end

function FieldworkAIDriver:onEndCourse()
	if self.state == self.states.UNLOAD_OR_REFILL then
		-- unload/refill course ended, return to fieldwork
		self:debug('AI driver in mode %d continue fieldwork at %d/%d waypoints', self:getMode(), self.fieldworkAbortedAtWaypoint, self.fieldworkCourse:getNumberOfWaypoints())
		self:changeToFieldwork()
		self:startCourseWithAlignment(self.fieldworkCourse, self.vehicle.cp.fieldworkAbortedAtWaypoint or self.fieldworkAbortedAtWaypoint)
	else
		AIDriver.onEndCourse(self)
	end
end

function FieldworkAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	if self.state == self.states.FIELDWORK then
		if self.fieldworkState == self.states.WORKING then
			if self.course:isOnConnectingTrack(ix) then
				-- reached a connecting track (done with the headland, move to the up/down row or vice versa),
				-- raise all implements while moving
				self:stopWork()
				self.fieldworkState = self.states.ON_CONNECTING_TRACK
				self:debug('on a connecting track now, raising implements.')
			end
		end
	end
end

function FieldworkAIDriver:onWaypointChange(ix)
	self:debug('onWaypointChange %d', ix)
	if self.state == self.states.FIELDWORK then
		if self.fieldworkState == self.states.ON_CONNECTING_TRACK then
			if not self.course:isOnConnectingTrack(ix) then
				-- reached the end of the connecting track, back to work
				self:debug('connecting track ended, back to work, first lowering implements.')
				self:changeToFieldwork()
			end
		end
	end
	AIDriver.onWaypointChange(self, ix)
end

function FieldworkAIDriver:getFieldSpeed()
	-- use the speed limit supplied by Giants for fieldwork
	local speedLimit = self.vehicle:getSpeedLimit() or math.huge
	return math.min(self.vehicle.cp.speeds.field, speedLimit)
end

function FieldworkAIDriver:getSpeed()
	local speed = self.speed or 10
	-- as long as other CP components mess with the cruise control we need to reset this, for example after
	-- a turn
	self.vehicle:setCruiseControlMaxSpeed(speed)
	return speed
end

--- Start the actual work. Lower and turn on implements
function FieldworkAIDriver:startWork()
	self:debug('Starting work: turn on and lower implements.')
	courseplay:lowerImplements(self.vehicle)
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
end

--- Stop working. Raise and stop implements
function FieldworkAIDriver:stopWork()
	self:debug('Ending work: turn off and raise implements.')
	courseplay:raiseImplements(self.vehicle)
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
end

--- Check all worktools to see if we are ready
function FieldworkAIDriver:areAllWorkToolsReady()
	if not self.vehicle.cp.workTools then return true end
	local allToolsReady = true
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		allToolsReady = self:isWorktoolReady(workTool) and allToolsReady
	end
	return allToolsReady
end

--- Check if need to refill anything
function FieldworkAIDriver:allFillLevelsOk()
	if not self.vehicle.cp.workTools then return false end
	local allOk = true
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		allOk = self:fillLevelsOk(workTool) and allOk
	end
	return allOk
end

--- Check fill levels in all tools and stop when one of them isn't
-- ok (empty or full, depending on the derived class)
function FieldworkAIDriver:fillLevelsOk(workTool)
	if workTool.getFillUnits then
		for index, fillUnit in pairs(workTool:getFillUnits()) do
			-- let's see if we can get by this abstraction for all kinds of tools
			local ok = self:isLevelOk(workTool, index, fillUnit)
			if not ok then
				return false
			end
		end
	end
	-- all fill levels ok
	return true
end

--- Check if worktool is ready for work
function FieldworkAIDriver:isWorktoolReady(workTool)
	local _, _, isUnfolded = courseplay:isFolding(workTool)

	-- TODO: move these to a generic helper?
	local isTurnedOn = true
	if workTool.spec_turnOnVehicle then
		isTurnedOn = workTool:getAIRequiresTurnOn() and workTool:getIsTurnedOn()
	end

	local isLowered = courseplay:isLowered(workTool)
	courseplay.debugVehicle(12, workTool, 'islowered=%s isturnedon=%s unfolded=%s', isLowered, isTurnedOn, isUnfolded)
	return isLowered and isTurnedOn and isUnfolded
end

-- is the fill level ok to continue?
function FieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	-- implement specifics in the derived classes
	return true
end

--- Set up the main (fieldwork) course and the unload/refill course and initial state
-- Currently, the legacy CP code just dumps all loaded courses to vehicle.Waypoints so
-- now we have to figure out which of that is the actual fieldwork course and which is the
-- refill/unload part.
-- This should better be handled by the course management though and should be refactored.
function FieldworkAIDriver:setUpCourses()
	local nWaits = 0
	local endFieldCourseIx = 0
	for i, wp in ipairs(self.vehicle.Waypoints) do
		if wp.wait then
			nWaits = nWaits + 1
			-- the second wp with the wait attribute is the end of the field course (assuming
			-- the field course has been loaded first.
			if nWaits == 2 then
				endFieldCourseIx = i
				break
			end
		end
	end
	if #self.vehicle.Waypoints > endFieldCourseIx then
		self:debug('There seems to be an unload/refill course starting at waypoint %d', endFieldCourseIx + 1)
		---@type Course
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, 1, endFieldCourseIx)
		---@type Course
		self.unloadRefillCourse = Course(self.vehicle, self.vehicle.Waypoints, endFieldCourseIx + 1, #self.vehicle.Waypoints)
	else
		self:debug('There seems to be no unload/refill course')
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, 1, #self.vehicle.Waypoints)
	end
end