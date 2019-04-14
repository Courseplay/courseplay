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
	courseplay.debugVehicle(11,vehicle,'FieldworkAIDriver:init()')
	AIDriver.init(self, vehicle)
	self:initStates(FieldworkAIDriver.myStates)
	-- waiting for tools to turn on, unfold and lower
	self.waitingForTools = true
	self.debugChannel = 14
	-- waypoint index on main (fieldwork) course where we aborted the work before going on
	-- an unload/refill course
	self.fieldworkAbortedAtWaypoint = 1
	-- force stop for unload/refill, for example by a tractor, otherwise the same as stopping because full or empty
	self.heldForUnloadRefill = false
	self.heldForUnloadRefillTimestamp = 0
	-- stop and raise implements while refilling/unloading on field
	self.stopImplementsWhileUnloadOrRefillOnField = true
	-- time to lower all implements. This is a default value and will
	-- be adjusted by the driver as it learns and then used to start lowering implements in time
	-- so they reach the working position before the row starts.
	self.loweringDurationMs = 3000
	-- duration of the last turn maneuver. This is a default value and the driver will measure
	-- the actual turn times. Used to calculate the remaining fieldwork time
	self.turnDurationMs = 20000
end

function FieldworkAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setFieldWorkAIDriverContent(self.vehicle)
end

function FieldworkAIDriver.register()

	AIImplement.getCanImplementBeUsedForAI = Utils.overwrittenFunction(AIImplement.getCanImplementBeUsedForAI,
		function(self, superFunc)
			if SpecializationUtil.hasSpecialization(BaleLoader, self.specializations) then
				return true
			elseif SpecializationUtil.hasSpecialization(BaleWrapper, self.specializations) then
				return true
			elseif SpecializationUtil.hasSpecialization(Pickup, self.specializations) then
				return true
			elseif superFunc ~= nil then
				return superFunc(self)
			end
		end)

	-- Make sure the Giants helper can't be hired for implements which have no Giants AI functionality
	AIVehicle.getCanStartAIVehicle = Utils.overwrittenFunction(AIVehicle.getCanStartAIVehicle,
		function(self, superFunc)
			-- Only the courseplay helper can handle bale loaders.
			if FieldworkAIDriver.hasImplementWithSpecialization(self, BaleLoader) or
				FieldworkAIDriver.hasImplementWithSpecialization(self, BaleWrapper) or
				FieldworkAIDriver.hasImplementWithSpecialization(self, Pickup) then
				return false
			end
			if superFunc ~= nil then
				return superFunc(self)
			end
		end)

	BaleLoaderAIDriver.register()

	Pickup.onAIImplementStartLine = Utils.overwrittenFunction(Pickup.onAIImplementStartLine,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			self:setPickupState(true)
		end)

	Pickup.onAIImplementEndLine = Utils.overwrittenFunction(Pickup.onAIImplementEndLine,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			self:setPickupState(false)
		end)

	-- TODO: move these to another dedicated class for implements?
	local PickupRegisterEventListeners = function(vehicleType)
		print('## Courseplay: Registering event listeners for loader wagons.')
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStartLine", Pickup)
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEndLine", Pickup)
	end

	print('## Courseplay: Appending event listener for loader wagons.')
	Pickup.registerEventListeners = Utils.appendedFunction(Pickup.registerEventListeners, PickupRegisterEventListeners)
end

function FieldworkAIDriver.hasImplementWithSpecialization(vehicle, specialization)
	return FieldworkAIDriver.getImplementWithSpecialization(vehicle, specialization) ~= nil
end

function FieldworkAIDriver.getImplementWithSpecialization(vehicle, specialization)
	local aiImplements = vehicle:getAttachedAIImplements()
	for _, implement in ipairs(aiImplements) do
		if SpecializationUtil.hasSpecialization(specialization, implement.object.specializations) then
			return implement.object
		end
	end
end

--- Start the course and turn on all implements when needed
function FieldworkAIDriver:start(ix)
	self:debug('Starting in mode %d', self.mode)
	self:beforeStart()
	-- stop at the last waypoint by default
	self.vehicle.cp.stopAtEnd = true
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


function FieldworkAIDriver:startFieldworkWithPathfinding(ix)
	if self:startCourseWithPathfinding(self.fieldworkCourse, ix, false) then
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
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
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
	self:measureTurnTime()
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
		if self.vehicle:getCanAIVehicleContinueWork() then
			self:debug('all tools ready, start working')
			self.fieldworkState = self.states.WORKING
			self:setSpeed(self:getFieldSpeed())
			self:calculateLoweringDuration()
		else
			self:debugSparse('waiting for all tools to lower')
			self:setSpeed(0)
			self:checkFillLevels()
		end
	elseif self.fieldworkState == self.states.WORKING then
		self:setSpeed(self:getFieldSpeed())
		self:manageConvoy()
		self:checkWeather()
		self:checkFillLevels()
	elseif self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		self:driveFieldworkUnloadOrRefill()
	elseif self.fieldworkState == self.states.TEMPORARY then
		self:setSpeed(self:getFieldSpeed())
	elseif self.fieldworkState == self.states.ON_CONNECTING_TRACK then
		self:setSpeed(self:getFieldSpeed())
	end
end

function FieldworkAIDriver:checkFillLevels()
	if not self:allFillLevelsOk() or self.heldForUnloadRefill then
		if self.unloadRefillCourse and not self.heldForUnloadRefill then
			---@see courseplay#setAbortWorkWaypoint if that logic needs to be implemented
			-- last wp may not be available shortly after a ppc initialization like after a turn
			self.fieldworkAbortedAtWaypoint = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
			self.vehicle.cp.fieldworkAbortedAtWaypoint = self.fieldworkAbortedAtWaypoint
			self:debug('at least one tool is empty/full, aborting work at waypoint %d.', self.fieldworkAbortedAtWaypoint or -1)
			self:changeToUnloadOrRefill()
			self:startCourseWithPathfinding(self.unloadRefillCourse, 1, true)
		else
			self:changeToFieldworkUnloadOrRefill()
		end
	end
end

---@return boolean true if unload took over the driving
function FieldworkAIDriver:driveUnloadOrRefill()
	if self.course:isTemporary() then
		-- use the courseplay speed limit until we get to the actual unload corse fields (on alignment/temporary)
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

--- Full during fieldwork
function FieldworkAIDriver:changeToFieldworkUnloadOrRefill()
	self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
	if self.stopImplementsWhileUnloadOrRefillOnField then
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_RAISE
	else
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
	end
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
			self:debug('unloaded, continue working')
			-- not full/empty anymore, maybe because Refilling to a trailer, go back to work
			self:clearInfoText(self:getFillLevelInfoText())
			self:changeToFieldwork()
		end
	end
end

function FieldworkAIDriver:changeToFieldwork()
	self:debug('change to fieldwork')
	self:disableCollisionDetection()
	self.state = self.states.ON_FIELDWORK_COURSE
	self.fieldworkState = self.states.WAITING_FOR_LOWER
	self:startWork()
	self:setDriveUnloadNow(false);
	self:refreshHUD();
end

function FieldworkAIDriver:changeToUnloadOrRefill()
	self:debug('changing to unload/refill course (%d waypoints)', self.unloadRefillCourse:getNumberOfWaypoints())
	self:stopWork()
	self:foldImplements()
	self:enableCollisionDetection()
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
end

function FieldworkAIDriver:onNextCourse()
	if self.state == self.states.ON_FIELDWORK_COURSE then
		self:changeToFieldwork()
	end
end

function FieldworkAIDriver:onEndCourse()
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE then
		-- unload/refill course ended, return to fieldwork
		self:debug('AI driver in mode %d continue fieldwork at %d/%d waypoints', self:getMode(), self.fieldworkAbortedAtWaypoint, self.fieldworkCourse:getNumberOfWaypoints())
		self:startFieldworkWithPathfinding(self.vehicle.cp.fieldworkAbortedAtWaypoint or self.fieldworkAbortedAtWaypoint)
	else
		self:debug('Fieldwork AI driver in mode %d ending course', self:getMode())
		AIDriver.onEndCourse(self)
	end
end

function FieldworkAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	if self.turnIsDriving then
		self:debug('onWaypointPassed %d, ignored as turn is driving now', ix)
		return
	end
	if self.state == self.states.ON_FIELDWORK_COURSE then
		if self.fieldworkState == self.states.WORKING then
			-- check for transition to connecting track
			if self.course:isOnConnectingTrack(ix) then
				-- reached a connecting track (done with the headland, move to the up/down row or vice versa),
				-- raise all implements while moving
				self:debug('on a connecting track now, raising implements.')
				self:raiseImplements()
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
				self:debug('End connecting track, start working on up/down rows (waypoint %d) with alignment course if needed.', firstUpDownWpIx)
				self:startFieldworkWithAlignment(firstUpDownWpIx)
			end
		end
	end
	--- Check if we are at the last waypoint and should we continue with first waypoint of the course
	-- or stop.
	if ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	end
end

function FieldworkAIDriver:onWaypointChange(ix)
	self:debug('onWaypointChange %d', ix)
	if self.state == self.states.ON_FIELDWORK_COURSE then
		self:updateRemainingTime(ix)
		self:calculateTightTurnOffset()
		if self.fieldworkState == self.states.ON_CONNECTING_TRACK then
			if not self.course:isOnConnectingTrack(ix) then
				-- reached the end of the connecting track, back to work
				self:debug('connecting track ended, back to work, first lowering implements.')
				self:changeToFieldwork()
			end
		end
		if self.fieldworkState == self.states.TEMPORARY then
			-- band aid to make sure we have our implements lowered by the time we end the`
			-- temporary course
			if ix == self.course:getNumberOfWaypoints() then
				self:debug('temporary (alignment) course is about to end, start work')
				self:startWork()
			end
		-- towards the end of the field course make sure the implement reaches the last waypoint
		elseif ix > self.course:getNumberOfWaypoints() - 3 then
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

--- Pass on self.speed set elsewhere to the AIDriver.
function FieldworkAIDriver:getSpeed()
	local speed = AIDriver.getSpeed(self)
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
	self.vehicle:requestActionEventUpdate() 
	self:startEngineIfNeeded()
	self:lowerImplements(self.vehicle)
end


--- Stop working. Raise and stop implements
function FieldworkAIDriver:stopWork()
	self:debug('Ending work: turn off and raise implements.')
	self:raiseImplements()
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
	self.vehicle:requestActionEventUpdate()
	self:clearRemainingTime()
end

--- Check if need to refill/unload anything
function FieldworkAIDriver:allFillLevelsOk()
	if not self.vehicle.cp.workTools then return false end
	-- what here comes is basically what Giants' getFillLevelInformation() does but this returns the real fillType,
	-- not the fillTypeToDisplay as this latter is different for each type of seed
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	return self:areFillLevelsOk(fillLevelInfo)
end

function FieldworkAIDriver:getAllFillLevels(object, fillLevelInfo)
	-- get own fill levels
	if object.getFillUnits then
		for _, fillUnit in pairs(object:getFillUnits()) do
			local fillType = self:getFillTypeFromFillUnit(fillUnit)
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
			self:debugSparse('%s: Fill levels: %s: %.1f/%.1f', object:getName(), fillTypeName, fillUnit.fillLevel, fillUnit.capacity)
			if not fillLevelInfo[fillType] then fillLevelInfo[fillType] = {fillLevel=0, capacity=0} end
			fillLevelInfo[fillType].fillLevel = fillLevelInfo[fillType].fillLevel + fillUnit.fillLevel
			fillLevelInfo[fillType].capacity = fillLevelInfo[fillType].capacity + fillUnit.capacity
		end
	end
 	-- collect fill levels from all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getAllFillLevels(impl.object, fillLevelInfo)
	end
end

function FieldworkAIDriver:getFillTypeFromFillUnit(fillUnit)
	local fillType = fillUnit.lastValidFillType or fillUnit.fillType
	-- TODO: do we need to check more supported fill types? This will probably cover 99.9% of the cases
	if fillType == FillType.UNKNOWN then
		-- just get the first valid supported fill type
		for ft, valid in pairs(fillUnit.supportedFillTypes) do
			if valid then return ft end
		end
	else
		return fillType
	end

end

-- is the fill level ok to continue?
function FieldworkAIDriver:areFillLevelsOk()
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
		self:debug('Course with %d waypoints set up, there seems to be an unload/refill course starting at waypoint %d',
			#self.vehicle.Waypoints, endFieldCourseIx + 1)
		---@type Course
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, false, 1, endFieldCourseIx)
		---@type Course
		self.unloadRefillCourse = Course(self.vehicle, self.vehicle.Waypoints, false, endFieldCourseIx + 1, #self.vehicle.Waypoints)
	else
		self:debug('Course with %d waypoints set up, there seems to be no unload/refill course', #self.vehicle.Waypoints)
		self.fieldworkCourse = Course(self.vehicle, self.vehicle.Waypoints, false, 1, #self.vehicle.Waypoints)
	end
	-- apply the current offset to the fieldwork part (lane+tool, where, confusingly, totalOffsetX contains the toolOffsetX)
	self.fieldworkCourse:setOffset(self.vehicle.cp.totalOffsetX, self.vehicle.cp.toolOffsetZ)
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
	-- (as lua passes tables by reference, we can directly change self.fieldworkCourse even if we passed self.course
	-- to the PPC to drive)
	self.fieldworkCourse:setOffset(self.vehicle.cp.totalOffsetX + self.aiDriverOffsetX + (self.tightTurnOffset or 0),
		self.vehicle.cp.toolOffsetZ + self.aiDriverOffsetZ)
end

function FieldworkAIDriver:hasSameCourse(otherVehicle)
	if otherVehicle.cp.driver and otherVehicle.cp.driver.fieldworkCourse then
		return self.fieldworkCourse:equals(otherVehicle.cp.driver.fieldworkCourse)
	else
		return false
	end
end

--- When working in a group (convoy), do I have to hold so I don't get too close to the
-- other vehicles in front of me?
function FieldworkAIDriver:manageConvoy()
	if not self.vehicle.cp.convoyActive then return false end
	--get my position in convoy and look for the closest combine
	local position = 1
	local total = 1
	local closestDistance = math.huge
	for _, otherVehicle in pairs(CpManager.activeCoursePlayers) do
		if otherVehicle ~= self.vehicle and otherVehicle.cp.convoyActive and self:hasSameCourse(otherVehicle) then
			local myWpIndex = self.ppc:getCurrentWaypointIx()
			local otherVehicleWpIndex = otherVehicle.cp.ppc:getCurrentWaypointIx()
			total = total + 1
			if myWpIndex < otherVehicleWpIndex then
				position = position + 1
				local distance = (otherVehicleWpIndex - myWpIndex) * courseGenerator.waypointDistance
				if distance < closestDistance then
					closestDistance = distance
				end
			end
		end
	end

	-- stop when I'm too close to the combine in front of me
	if position > 1 then
		if closestDistance < self.vehicle.cp.convoy.minDistance then
			self:debugSparse('too close (%.1f) to other vehicles in group, holding.', closestDistance)
			self:setSpeed(0)
		end
	else
		closestDistance = 0
	end

	-- TODO: check for change should be handled by setCpVar()
	if self.vehicle.cp.convoy.distance ~= closestDistance then
		self.vehicle:setCpVar('convoy.distance',closestDistance)
	end
	if self.vehicle.cp.convoy.number ~= position then
		self.vehicle:setCpVar('convoy.number',position)
	end
	if self.vehicle.cp.convoy.members ~= total then
		self.vehicle:setCpVar('convoy.members',total)
	end
end

-- Although raising the AI start/stop events supposed to fold/unfold the implements, it does not always happen.
-- So use these to explicitly do so
function FieldworkAIDriver:unfoldImplements()
	for _,workTool in pairs(self.vehicle.cp.workTools) do
		if courseplay:isFoldable(workTool) then
			local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool)
			if not isUnfolded then
				self:debug('Unfolding %s', workTool:getName())
				workTool:setFoldDirection(workTool.cp.realUnfoldDirection)
			end
		end
	end
end

function FieldworkAIDriver:foldImplements()
	for _,workTool in pairs(self.vehicle.cp.workTools) do
		if courseplay:isFoldable(workTool) then
			local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool)
			if not isFolded then
				self:debug('Folding %s', workTool:getName())
				workTool:setFoldDirection(-workTool.cp.realUnfoldDirection)
			end
		end
	end
end

function FieldworkAIDriver:isAllUnfolded()
	for _,workTool in pairs(self.vehicle.cp.workTools) do
		if courseplay:isFoldable(workTool) then
			local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool)
			if not isUnfolded then return false end
		end
	end
	return true
end

function FieldworkAIDriver:clearRemainingTime()
	self.vehicle.cp.timeRemaining = nil
end

function FieldworkAIDriver:updateRemainingTime(ix)
	if self.state == self.states.ON_FIELDWORK_COURSE then
		local dist, turns = self.course:getRemainingDistanceAndTurnsFrom(ix)
		local turnTime = turns * self.turnDurationMs / 1000
		self.vehicle.cp.timeRemaining = math.max(0, dist / (self:getFieldSpeed() / 3.6) + turnTime)
		self:debug('Distance to go: %.1f; Turns left: %d; Time left: %ds', dist, turns, self.vehicle.cp.timeRemaining)
	else
		self:clearRemainingTime()
	end
end

function FieldworkAIDriver:measureTurnTime()
	if self.turnWasDriving and not self.turnIsDriving then
		-- end of turn
		if self.turnStartedAt then
			-- use sliding average to smooth jumps
			self.turnDurationMs = (self.turnDurationMs + self.vehicle.timer - self.turnStartedAt) / 2
			self:debug('Measured turn duration is %.0f ms', self.turnDurationMs)
		end
	elseif not self.turnWasDriving and self.turnIsDriving then
		-- start of turn
		self.turnStartedAt = self.vehicle.timer
	end
	self.turnWasDriving = self.turnIsDriving
end

function FieldworkAIDriver:checkWeather()
	if self.vehicle.getIsThreshingAllowed and not self.vehicle:getIsThreshingAllowed() then
		self:debugSparse('No threshing in rain...')
		self:setSpeed(0)
		self:setInfoText('WEATHER')
	else
		self:clearInfoText('WEATHER')
	end
end

function FieldworkAIDriver:updateLights()
	if not self.vehicle.spec_lights then return end
	-- turn on beacon lights on unload/refill course when enabled
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE and self:areBeaconLightsEnabled() then
		self.vehicle:setBeaconLightsVisibility(true)
	else
		self:updateLightsOnField()
	end
end

function FieldworkAIDriver:updateLightsOnField()
	-- there are no beacons used on the field by default
	self.vehicle:setBeaconLightsVisibility(false)
end

function FieldworkAIDriver:startLoweringDurationTimer()
	-- then start but only after everything is unfolded as we don't want to include the
	-- unfold duration (since we don't fold at the end of the row).
	if self:isAllUnfolded() then
		self.startedLoweringAt = self.vehicle.timer
	end
end

function FieldworkAIDriver:calculateLoweringDuration()
	if self.startedLoweringAt then
		self.loweringDurationMs = self.vehicle.timer - self.startedLoweringAt
		self:debug('Measured implement lowering duration is %.0f ms', self.loweringDurationMs)
		self.startedLoweringAt = nil
	end
end

function FieldworkAIDriver:getLoweringDurationMs()
	return self.loweringDurationMs
end

--- If we are towing an implement, move to a bigger radius in tight turns
-- making sure that the towed implement's trajectory remains closer to the
-- course.
function FieldworkAIDriver:calculateTightTurnOffset()
	local function smoothOffset(offset)
		self.tightTurnOffset = (offset + 3 * (self.tightTurnOffset or 0 )) / 4
		return self.tightTurnOffset
	end
	-- first of all, does the current waypoint have radius data?
	local r = self.course:getWaypointRadius(self.ppc:getCurrentWaypointIx())
	if not r then
		return smoothOffset(0)
	end

	local towBarLength = self:getTowBarLength()

	-- Is this really a tight turn? It is when the tow bar is longer than radius / 3, otherwise
	-- we ignore it.
	if towBarLength < r / 3 then
		return smoothOffset(0)
	end

	-- Ok, looks like a tight turn, so we need to move a bit left or right of the course
	-- to keep the tool on the course.
	local offset = self:getOffsetForTowBarLength(r, towBarLength)

	-- figure out left or right now?
	local nextAngle = self.course:getWaypointAngleDeg(self.ppc:getCurrentWaypointIx() + 1)
	local currentAngle = self.course:getWaypointAngleDeg(self.ppc:getCurrentWaypointIx())
	if not nextAngle or not currentAngle then
		return smoothOffset(0)
	end

	if getDeltaAngle(math.rad(nextAngle), math.rad(currentAngle)) > 0 then offset = -offset end

	-- smooth the offset a bit to avoid sudden changes
	smoothOffset(offset)
	self:debug('Tight turn, r = %.1f, tow bar = %.1f m, currentAngle = %.0f, nextAngle = %.0f, offset = %.1f, smoothOffset = %.1f',	r, towBarLength, currentAngle, nextAngle, offset, self.tightTurnOffset )
	-- remember the last value for smoothing
	return self.tightTurnOffset
end

function FieldworkAIDriver:getTowBarLength()
	-- is there a wheeled implement behind the tractor and is it on a pivot?
	local workTool = courseplay:getFirstReversingWheeledWorkTool(self.vehicle)
	if not workTool or not workTool.cp.realTurningNode then
		return 0
	end
	-- get the distance between the tractor and the towed implement's turn node
	-- (not quite accurate when the angle between the tractor and the tool is high)
	local tractorX, _, tractorZ = getWorldTranslation( self.vehicle.cp.DirectionNode )
	local toolX, _, toolZ = getWorldTranslation( workTool.cp.realTurningNode )
	local towBarLength = courseplay:distance( tractorX, tractorZ, toolX, toolZ )
	return towBarLength
end

function FieldworkAIDriver:getOffsetForTowBarLength(r, towBarLength)
	local rTractor = math.sqrt( r * r + towBarLength * towBarLength ) -- the radius the tractor should be on
	return rTractor - r
end

function FieldworkAIDriver:getFillLevelInfoText()
	return 'NEEDS_REFILLING'
end

function FieldworkAIDriver:lowerImplements()
	for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
		implement.object:aiImplementStartLine()
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)
	self:startLoweringDurationTimer()
end

function FieldworkAIDriver:raiseImplements()
	for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
		implement.object:aiImplementEndLine()
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
end

function FieldworkAIDriver:getCanShowDriveOnButton()
	return self.state == self.states.ON_FIELDWORK_COURSE 
end