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
	ON_FIELDWORK_COURSE = {},
	ON_UNLOAD_OR_REFILL_COURSE = {},
	UNLOAD_OR_REFILL_ON_FIELD = {},
	WAITING_FOR_UNLOAD_OR_REFILL ={}, -- while on the field
	ON_CONNECTING_TRACK = {},
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
	-- FieldworkAIDriver and its derived classes set the self.speed in various locations in
	-- the code and then getSpeed() will pass that on to the AIDriver.
	self.speed = 0
	self.debugChannel = 14
	-- waypoint index on main (fieldwork) course where we aborted the work before going on
	-- an unload/refill course
	self.fieldworkAbortedAtWaypoint = 1
	-- force stop for unload/refill, for example by a tractor, otherwise the same as stopping because full or empty
	self.heldForUnloadRefill = false
	self.heldForUnloadRefillTimestamp = 0
end

--- Start the course and turn on all implements when needed
function FieldworkAIDriver:start(ix)
	-- stop at the last waypoint by default
	self.vehicle.cp.stopAtEnd = true
	self.turnIsDriving = false
	self.temporaryCourse = nil
	-- any offset imposed by the driver itself (tight turns, end of course, etc.), addtional to any
	-- tool offsets
	self.aiDriverOffsetX = 0
	self.aiDriverOffsetZ = 0

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
		self:startFieldworkWithAlignment(ix)
	end
end

function FieldworkAIDriver:startFieldworkWithAlignment(ix)
	if self:startCourseWithAlignment(self.fieldworkCourse, ix) then
		self.state = self.states.ON_FIELDWORK_COURSE
		self.fieldworkState = self.states.TEMPORARY
	else
		self:changeToFieldwork()
	end
end

function FieldworkAIDriver:stop(msgReference)
	self:stopWork()
	AIDriver.stop(self, msgReference)
end

function FieldworkAIDriver:drive(dt)
	-- reset speed limit
	self.speed = math.huge
	if self.state == self.states.ON_FIELDWORK_COURSE then
		self:driveFieldwork()
	elseif self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE then
		if self:driveUnloadOrRefill(dt) then
			-- someone else is driving, no need to call AIDriver.drive()
			return
		end
	end
	self:setRidgeMarkers()
	self:resetUnloadOrRefillHold()
	AIDriver.drive(self, dt)
end

-- Hold for unload (or refill) for example a combine can be asked by a an unloading tractor
-- to stop and wait. Must be called in every loop to keep waiting because it will automatically be
-- reset and the vehicle restarted. This way the users don't explicitly need to call resumeAfterUnloadOrRefill()
function FieldworkAIDriver:holdForUnloadOrRefill()
	self.heldForUnloadRefill = true
	self.heldForUnloadRefillTimestamp = g_updateLoopIndex
end

function FieldworkAIDriver:resumeAfterUnloadOrRefill()
	self.heldForUnloadRefill = false
end

function FieldworkAIDriver:resetUnloadOrRefillHold()
	if g_updateLoopIndex > self.heldForUnloadRefillTimestamp + 10 then
		self:resumeAfterUnloadOrRefill()
	end
end


--- Doing the fieldwork (headlands or up/down rows, including the turns)
function FieldworkAIDriver:driveFieldwork()
	self:updateFieldworkOffset()
	if self.fieldworkState == self.states.WAITING_FOR_LOWER then
		if self:areAllWorkToolsReady() then
			self:debug('all tools ready, start working')
			self.fieldworkState = self.states.WORKING
			self:setSpeed(self:getFieldSpeed())
		else
			self:setSpeed(0)
		end
	elseif self.fieldworkState == self.states.WORKING then
		self:setSpeed(self:getFieldSpeed())
		if not self:allFillLevelsOk() or self.heldForUnloadRefill then
			if self.unloadRefillCourse and not self.heldForUnloadRefill then
				---@see courseplay#setAbortWorkWaypoint if that logic needs to be implemented
				-- last wp may not be available shortly after a ppc initialization like after a turn
				self.fieldworkAbortedAtWaypoint = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
				self.vehicle.cp.fieldworkAbortedAtWaypoint = self.fieldworkAbortedAtWaypoint
				self:debug('at least one tool is empty/full, aborting work at waypoint %d.', self.fieldworkAbortedAtWaypoint or -1)
				self:changeToUnloadOrRefill()
				self:startCourseWithAlignment(self.unloadRefillCourse, 1 )
			else
				self:changeToFieldworkUnloadOrRefill()
			end
		end
	elseif self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		self:driveFieldworkUnloadOrRefill()
	elseif self.fieldworkState == self.states.TEMPORARY then
		self:setSpeed(self:getFieldSpeed())
	end
end

---@return boolean true if unload took over the driving
function FieldworkAIDriver:driveUnloadOrRefill()
	if self.temporaryCourse then
		-- use the courseplay speed limit for fields
		self:setSpeed(self.vehicle.cp.speeds.field)
	else
		-- just drive normally
		self:setSpeed(self:getRecordedSpeed())
	end
	-- except when in reversing, then always use reverse speed
	if self.ppc:isReversing() then
		self:setSpeed(self.vehicle.cp.speeds.reverse or self.vehicle.cp.speeds.crawl)
	end
	return false
end

--- Grain tank full during fieldwork
function FieldworkAIDriver:changeToFieldworkUnloadOrRefill()
	self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
	self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_RAISE
end

--- Stop for unload/refill while driving the fieldwork course
function FieldworkAIDriver:driveFieldworkUnloadOrRefill()
	-- don't move while empty
	self:setSpeed(0)
	if self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_RAISE then
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('implements raised, stop')
			self:stopWork()
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL then
		if self:allFillLevelsOk() and not self.heldForUnloadRefill then
			self:debug('unloaded/refilled, continue working')
			-- not full/empty anymore, maybe because Refilling to a trailer, go back to work
			self:clearInfoText()
			self:changeToFieldwork()
		end
	end
end

function FieldworkAIDriver:changeToFieldwork()
	self:debug('change to fieldwork')
	self.state = self.states.ON_FIELDWORK_COURSE
	self.fieldworkState = self.states.WAITING_FOR_LOWER
	self:startWork()
end

function FieldworkAIDriver:changeToUnloadOrRefill()
	self:stopWork()
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
	self:debug('changing to unload/refill course (%d waypoints)', self.unloadRefillCourse:getNumberOfWaypoints())
end

function FieldworkAIDriver:onEndTemporaryCourse()
	if self.state == self.states.ON_FIELDWORK_COURSE then
		self:debug('starting fieldwork')
		self.fieldworkState = self.states.WAITING_FOR_LOWER
		self:startWork()
	end
end

function FieldworkAIDriver:onEndCourse()
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE then
		-- unload/refill course ended, return to fieldwork
		self:debug('AI driver in mode %d continue fieldwork at %d/%d waypoints', self:getMode(), self.fieldworkAbortedAtWaypoint, self.fieldworkCourse:getNumberOfWaypoints())
		self:startFieldworkWithAlignment(self.vehicle.cp.fieldworkAbortedAtWaypoint or self.fieldworkAbortedAtWaypoint)
	else
		AIDriver.onEndCourse(self)
	end
end

function FieldworkAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	if self.state == self.states.ON_FIELDWORK_COURSE then
		if self.fieldworkState == self.states.WORKING then
			-- check for transition to connecting track
			if self.course:isOnConnectingTrack(ix) then
				-- reached a connecting track (done with the headland, move to the up/down row or vice versa),
				-- raise all implements while moving
				self:debug('on a connecting track now, raising implements.')
				self:stopWork()
				self.fieldworkState = self.states.ON_CONNECTING_TRACK
			end
		end
		if self.fieldworkState ~= self.states.TEMPORARY and self.course:isOnConnectingTrack(ix) then
			-- passed a connecting track waypoint
			-- check transition from connecting track to the up/down rows
			-- we are close to the end of the connecting track, transition back to the up/down rows with
			-- an alignment course
			local d, firstUpDownWpIx = self.course:getDistanceToFirstUpDownRowWaypoint(ix)
			self:debug('up/down rows start in %s meters.', tostring(d))
			if d < self.vehicle.cp.turnDiameter * 2 and firstUpDownWpIx then
				self:debug('start working on up/down rows (waypoint %d) with alignment course if needed.', firstUpDownWpIx)
				self:startFieldworkWithAlignment(firstUpDownWpIx)
			end
		end
	end
end

function FieldworkAIDriver:onWaypointChange(ix)
	self:debug('onWaypointChange %d', ix)
	if self.state == self.states.ON_FIELDWORK_COURSE then
		if self.fieldworkState == self.states.ON_CONNECTING_TRACK then
			if not self.course:isOnConnectingTrack(ix) then
				-- reached the end of the connecting track, back to work
				self:debug('connecting track ended, back to work, first lowering implements.')
				self:changeToFieldwork()
			end
		end
		-- towards the end of the field course make sure the implement reaches the last waypoint
		if ix > self.course:getNumberOfWaypoints() - 3 then
			if self.vehicle.cp.aiFrontMarker then
				self:debug('adding offset (%.1f front marker) to make sure we do not miss anything when the course ends', self.vehicle.cp.aiFrontMarker)
				self.aiDriverOffsetZ = -self.vehicle.cp.aiFrontMarker
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

--- Set the speed. The idea is that self.speed is reset at the beginning of every loop and
-- every function calls setSpeed() and the speed will be set to the minimum
-- speed set in this loop.
function FieldworkAIDriver:setSpeed(speed)
	self.speed = math.min(self.speed, speed)
end

--- Pass on self.speed set elsewhere to the AIDriver.
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
	-- send the event first and _then_ lower otherwise it sometimes does not turn it on
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	courseplay:lowerImplements(self.vehicle)
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
	local isAiImplementReady = self.vehicle:getCanAIImplementContinueWork()
	courseplay.debugVehicle(12, workTool, 'islowered=%s isAiReady=%s isturnedon=%s unfolded=%s',
		isLowered, isAiImplementReady, isTurnedOn, isUnfolded)
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
	if #self.vehicle.Waypoints > endFieldCourseIx and endFieldCourseIx ~= 0 then
		self:debug('There seems to be an unload/refill course starting at waypoint %d', endFieldCourseIx + 1)
		---@type Course
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, 1, endFieldCourseIx)
		-- apply the current offset to the fieldwork part (lane+tool, where, confusingly, totalOffsetX contains the toolOffsetX)
		self.fieldworkCourse:setOffset(self.vehicle.cp.totalOffsetX, self.vehicle.cp.toolOffsetZ)
		---@type Course
		self.unloadRefillCourse = Course(self.vehicle, self.vehicle.Waypoints, endFieldCourseIx + 1, #self.vehicle.Waypoints)
	else
		self:debug('There seems to be no unload/refill course')
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, 1, #self.vehicle.Waypoints)
	end
end

function FieldworkAIDriver:setRidgeMarkers()
	if not self.vehicle.cp.ridgeMarkersAutomatic then return end
	local active = self.state == self.states.FIELDWORK and not self.turnIsDriving
	for _, workTool in ipairs(self.vehicle.cp.workTools) do
		if workTool.spec_ridgeMarker then
			local state = active and self.course:getRidgeMarkerState(self.ppc:getCurrentWaypointIx()) or 0
			if workTool.spec_ridgeMarker.ridgeMarkerState ~= state then
				self:debug('Setting ridge markers to %d', state)
				workTool:setRidgeMarkerState(state)
			end
		end
	end
end

--- We already set the offsets on the course at start, this is to update those values
-- if the user changed them during the run or the AI driver wants to add an offset
function FieldworkAIDriver:updateFieldworkOffset()
	-- pass this in through the PPC instead of setting it on the course directly as we don't know what
	-- course it is running at the moment
	self.ppc:setOffset(self.vehicle.cp.totalOffsetX + self.aiDriverOffsetX, self.vehicle.cp.toolOffsetZ + self.aiDriverOffsetZ)
end