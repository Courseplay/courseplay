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
	RETURNING_TO_FIRST_POINT = {},
	UNLOAD_OR_REFILL_ON_FIELD = {},
	WAITING_FOR_UNLOAD_OR_REFILL ={}, -- while on the field
	ON_CONNECTING_TRACK = {},
	WAITING_FOR_LOWER = {},
	WAITING_FOR_RAISE = {},
	TURNING = {},
	ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE = {}
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
	self.aiDriverData.continueFieldworkAtWaypoint = 1
	-- force stop for unload/refill, for example by a tractor, otherwise the same as stopping because full or empty
	self.heldForUnloadRefill = false
	self.heldForUnloadRefillTimestamp = 0
	-- stop and raise implements while refilling/unloading on field
	self.stopImplementsWhileUnloadOrRefillOnField = true
	-- duration of the last turn maneuver. This is a default value and the driver will measure
	-- the actual turn times. Used to calculate the remaining fieldwork time
	self.turnDurationMs = 20000
	self:setMarkers()
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
	self:setMarkers()
	self:beforeStart()
	-- time to lower all implements
	self:findLoweringDurationMs()
	-- always enable alignment with first waypoint, this is needed to properly start/continue fieldwork
	self.alignmentEnabled = self.vehicle.cp.alignment.enabled
	self.vehicle.cp.alignment.enabled = true
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
		self:startFieldworkWithPathfinding(ix)
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
	if self:startCourseWithPathfinding(self.fieldworkCourse, ix) then
		self.state = self.states.ON_FIELDWORK_COURSE
		self.fieldworkState = self.states.TEMPORARY
	else
		self:changeToFieldwork()
	end
end

function FieldworkAIDriver:stop(msgReference)
	self:stopWork()
	AIDriver.stop(self, msgReference)
	-- Restore alignment settings. TODO: remove this setting from the HUD and always enable it
	self.vehicle.cp.alignment.enabled = self.alignmentEnabled
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
	elseif self.state == self.states.RETURNING_TO_FIRST_POINT then
		self:setSpeed(self:getFieldSpeed())
	elseif self.state == self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE then
		-- AutoDrive is driving, don't call AIDriver.drive()
		return
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
    		self:setSpeed(self:getWorkSpeed())
            self:manageConvoy()
		else
			self:debugSparse('waiting for all tools to lower')
			self:setSpeed(0)
			self:checkFillLevels()
		end
	elseif self.fieldworkState == self.states.WORKING then
		self:setSpeed(self:getWorkSpeed())
		self:manageConvoy()
		self:checkWeather()
		self:checkFillLevels()
	elseif self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		self:driveFieldworkUnloadOrRefill()
	elseif self.fieldworkState == self.states.TEMPORARY then
		self:setSpeed(self:getFieldSpeed())
        self:manageConvoy()
	elseif self.fieldworkState == self.states.ON_CONNECTING_TRACK then
		self:setSpeed(self:getFieldSpeed())
	elseif self.fieldworkState == self.states.TURNING then
		self:setSpeed(self.vehicle.cp.speeds.turn)
        self:manageConvoy()
	end
end

function FieldworkAIDriver:checkFillLevels()
	if not self:allFillLevelsOk() or self.heldForUnloadRefill then
		self:stopAndChangeToUnload()
	end
end

function FieldworkAIDriver:stopAndChangeToUnload()
	if self.unloadRefillCourse and not self.heldForUnloadRefill then
		self:rememberWaypointToContinueFieldwork()
		self:debug('at least one tool is empty/full, aborting work at waypoint %d.', self.aiDriverData.continueFieldworkAtWaypoint or -1)
		self:changeToUnloadOrRefill()
		self:startCourseWithPathfinding(self.unloadRefillCourse, 1)
	else
		if self.aiDriverData.autoDriveMode:is(AutoDriveModeSetting.UNLOAD_OR_REFILL) then
			-- Switch to AutoDrive when enabled 
			self:rememberWaypointToContinueFieldwork()
			self:stopWork()
			self:foldImplements()
			self.state = self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE
			self:debug('passing the control to AutoDrive to run the unload/refill course.')
			self.vehicle.spec_autodrive:StartDriving(self.vehicle, self.vehicle.ad.mapMarkerSelected, self.vehicle.ad.mapMarkerSelected_Unload, self, FieldworkAIDriver.onEndCourse, nil);
		else
			-- otherwise we'll 
			self:changeToFieldworkUnloadOrRefill()
		end;
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
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE or
		self.state == self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE then
		-- unload/refill course ended, return to fieldwork
		self:debug('AI driver in mode %d continue fieldwork at %d/%d waypoints', self:getMode(), self.aiDriverData.continueFieldworkAtWaypoint, self.fieldworkCourse:getNumberOfWaypoints())
		self:startFieldworkWithPathfinding(self.aiDriverData.continueFieldworkAtWaypoint)
	elseif self.state == self.states.RETURNING_TO_FIRST_POINT then
		AIDriver.onEndCourse(self)
	else
		self:debug('Fieldwork AI driver in mode %d ending course', self:getMode())
		if self:shouldReturnToFirstPoint() then
			self:debug('Returning to first point')
			local x, _, z = self.fieldworkCourse:getWaypointPosition(1)
			if self:driveToPointWithPathfinding(x, z) then
				-- pathfinding was successful, drive back to first point
				self.state = self.states.RETURNING_TO_FIRST_POINT
				self:raiseImplements()
				self:foldImplements()
			else
				-- no path or too short, stop here.
				AIDriver.onEndCourse(self)
			end
		else
			AIDriver.onEndCourse(self)
		end
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
	self:debug('onWaypointChange %d, connecting: %s, temp: %s',
		ix, tostring(self.course:isOnConnectingTrack(ix)), tostring(self.states == self.states.TEMPORARY))
	if self.state == self.states.ON_FIELDWORK_COURSE then
		self:updateRemainingTime(ix)
		self:calculateTightTurnOffset()
		self.aiDriverOffsetZ = 0
		if self.fieldworkState == self.states.ON_CONNECTING_TRACK then
			if not self.course:isOnConnectingTrack(ix) then
				-- reached the end of the connecting track, back to work
				self:debug('connecting track ended, back to work, first lowering implements.')
				self:changeToFieldwork()
			end
		end
		if self.fieldworkState == self.states.TEMPORARY then
			-- band aid to make sure we have our implements lowered by the time we end the
			-- temporary course
			if ix == self.course:getNumberOfWaypoints() then
				self:debug('temporary (alignment) course is about to end, start work')
				self:startWork()
			end
		-- towards the end of the field course make sure the implement reaches the last waypoint
		elseif ix > self.course:getNumberOfWaypoints() - 3 then
			if self.frontMarkerDistance then
				self:debug('adding offset (%.1f front marker) to make sure we do not miss anything when the course ends', self.frontMarkerDistance)
				self.aiDriverOffsetZ = -self.frontMarkerDistance
			end
		end
	end
	AIDriver.onWaypointChange(self, ix)
end

function FieldworkAIDriver:onTowedImplementPassedWaypoint(ix)
	self:debug('Implement passsed waypoint %d', ix)
end

--- Should we return to the first point of the course after we are done?
function FieldworkAIDriver:shouldReturnToFirstPoint()
	-- TODO: implement and check setting in course or HUD
	if self.fieldworkCourse:isOnHeadland(self.fieldworkCourse:getNumberOfWaypoints()) then
		self:debug('Course ends on headland, no return to first point')
		return false
	else
		return true
	end
end

--- Speed on the field when not working
function FieldworkAIDriver:getFieldSpeed()
	return self.vehicle.cp.speeds.field
end

-- Speed on the field when working
function FieldworkAIDriver:getWorkSpeed()
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
		if #self.vehicle.Waypoints - endFieldCourseIx > 2 then
			self.unloadRefillCourse = Course(self.vehicle, self.vehicle.Waypoints, false, endFieldCourseIx + 1, #self.vehicle.Waypoints)
		else
			self:debug('Unload/refill course too short, ignoring')
		end
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

--- When working in a group (convoy), 
--    do I have to hold so I don't get too close to the leading vehicle?
--    do I have to hold so I don't get too far from the trailing vehicle?
function FieldworkAIDriver:manageConvoy()
	if not self.vehicle.cp.convoyActive then return false end
    
    -- If we're not on the convoy head
    if self.vehicle.cp.convoy.number > 1 then
        local vehLead = CpManager.convoys[self.vehicle.cp.convoy.id][self.vehicle.cp.convoy.number-1]
        
        -- If we're not on a work course
        if self.fieldworkState ~= self.states.WORKING then
            -- Keep true distance
            self.vehicle:setCpVar('convoy.leadDist',courseplay:nodeToNodeDistance(self.vehicle.rootNode, vehLead.rootNode))
        -- If leading vechicle is on a generated manoeuvre course
        elseif vehLead.cp.driver.turnIsDriving then
            -- Keep true distance
            self.vehicle:setCpVar('convoy.leadDist',courseplay:nodeToNodeDistance(self.vehicle.rootNode, vehLead.rootNode))
        -- If leading vechicle is on connecting track (a transfer path between a headland and the up/down rows)       
        elseif vehLead.cp.driver.course:isOnConnectingTrack(vehLead.cp.ppc:getCurrentWaypointIx()) then
            -- Stop to allow the leading vechile perform the transfer (sometime they need to reverse, so better to stay back)
            self.vehicle:setCpVar('convoy.leadDist',courseplay:nodeToNodeDistance(self.vehicle.rootNode, vehLead.rootNode))
            self:setSpeed(0)
        -- Otherwise the leading vehicle is probably working
        else 
            -- Make sure we stay behind on the course
            self.vehicle:setCpVar('convoy.leadDist',(vehLead.cp.ppc:getCurrentWaypointIx() - self.ppc:getCurrentWaypointIx()) * courseGenerator.waypointDistance)
        end
        
        -- If we're too close to the leading vehicle
        if self.vehicle.cp.convoy.leadDist < self.vehicle.cp.convoy.minDistance then
            --self:setSpeed(0)
            local spdAdj = ((self.vehicle.cp.convoy.leadDist - self.vehicle.cp.convoy.minDistance) / (self.vehicle.cp.convoy.maxDistance - self.vehicle.cp.convoy.minDistance)) + 0.5
            if spdAdj > 1 then
                spdAdj = 1
            end
            self:setSpeed(self:getSpeed()*spdAdj)
            -- For some reason this print generates a format nil error but haven't figured out why
            --self:debugSparse('too close (%u) to leading vehicle, holding.', leadingDist)
        end
    end
    
    
    -- If we're not on the convoy tail
    if self.vehicle.cp.convoy.number < self.vehicle.cp.convoy.members then
        local vehTrail = CpManager.convoys[self.vehicle.cp.convoy.id][self.vehicle.cp.convoy.number+1]
        
        -- If we're not on a work course
        if self.fieldworkState ~= self.states.WORKING then
            -- Keep true distance
            self.vehicle:setCpVar('convoy.trailDist',courseplay:nodeToNodeDistance(self.vehicle.rootNode, vehTrail.rootNode))
        -- If trailing vechicle is on a generated manoeuvre course
        elseif vehTrail.cp.driver.turnIsDriving then
            -- Keep true distance
            self.vehicle:setCpVar('convoy.trailDist',courseplay:nodeToNodeDistance(self.vehicle.rootNode, vehTrail.rootNode))
        -- Otherwise the trailing vehicle is probably working
        else 
            -- Make sure we stay behind on the course
            self.vehicle:setCpVar('convoy.trailDist',(self.ppc:getCurrentWaypointIx() - vehTrail.cp.ppc:getCurrentWaypointIx()) * courseGenerator.waypointDistance)
        end
        
        -- Make sure max distance is always greater than trailing vehicle's min distance
        if (self.vehicle.cp.convoy.maxDistance < vehTrail.cp.convoy.minDistance) then
            self.vehicle.cp.convoy.maxDistance = vehTrail.cp.convoy.minDistance + 10
            courseplay.debugVehicle(self.debugChannel,self.vehicle,'Clamping maxDistance to %u', self.vehicle.cp.convoy.maxDistance)
        end
        
        -- If we're too far from the trailing vehicle
        if self.vehicle.cp.convoy.trailDist > self.vehicle.cp.convoy.maxDistance then
            --self:setSpeed(0)
            local spdAdj = ((self.vehicle.cp.convoy.maxDistance - self.vehicle.cp.convoy.trailDist) / (self.vehicle.cp.convoy.maxDistance - self.vehicle.cp.convoy.minDistance)) + 0.5
            if spdAdj > 1 then
                spdAdj = 1
            end
            self:setSpeed(self:getSpeed()*spdAdj)
            -- For some reason this print generates a format nil error but haven't figured out why
            --self:debugSparse('too far (%u) from trailing vehicle, holding.', trailingDist)
        end
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
		self.vehicle.cp.timeRemaining = math.max(0, dist / (self:getWorkSpeed() / 3.6) + turnTime)
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
			self.realTurnDurationMs = self.vehicle.timer - self.turnStartedAt
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
	if not r or r ~= r then
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
	if offset ~= offset then
		-- check for nan
		return smoothOffset(0)
	end
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
	if FieldworkAIDriver.hasImplementWithSpecialization(self.vehicle, SowingMachine) then
		-- sowing machines want to stop while the implement is being lowered
		self.fieldworkState = self.states.WAITING_FOR_LOWER
	end
end

function FieldworkAIDriver:raiseImplements()
	for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
		implement.object:aiImplementEndLine()
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
end

function FieldworkAIDriver:rememberWaypointToContinueFieldwork()
	local bestKnownCurrentWpIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
	-- after we return from a refill/unload, continue a bit before the point where we left to
	-- make sure not leaving any unworked patches
	self.aiDriverData.continueFieldworkAtWaypoint = self.course:getPreviousWaypointIxWithinDistance(bestKnownCurrentWpIx, 10)
	if self.aiDriverData.continueFieldworkAtWaypoint then
		-- anything other than a turn start wp will work fine
		if self.course:isTurnStartAtIx(self.aiDriverData.continueFieldworkAtWaypoint) then
			self.aiDriverData.continueFieldworkAtWaypoint = self.aiDriverData.continueFieldworkAtWaypoint - 1
		end
	else
		self.aiDriverData.continueFieldworkAtWaypoint = bestKnownCurrentWpIx
	end
	self:debug('Will return to fieldwork at waypoint %d', self.aiDriverData.continueFieldworkAtWaypoint)
end


function FieldworkAIDriver:getCanShowDriveOnButton()
	return self.state == self.states.ON_FIELDWORK_COURSE 
end

function FieldworkAIDriver:getLoweringDurationMs()
	return self.loweringDurationMs
end

function FieldworkAIDriver:findLoweringDurationMs()
	local function getLoweringDurationMs(object)
		if object.spec_animatedVehicle then
			-- TODO: implement these in the specifications?
			return math.max(object.spec_animatedVehicle:getAnimationDuration('lowerAnimation'),
				object.spec_animatedVehicle:getAnimationDuration('rotatePickup'))
		else
			return 0
		end
	end

	self.loweringDurationMs = getLoweringDurationMs(self.vehicle)
	self:debug('Lowering duration: %d ms', self.loweringDurationMs)

	-- check all implements first
	local implements = self.vehicle:getAttachedImplements()
	for _, implement in ipairs(implements) do
		local implementLoweringDurationMs = getLoweringDurationMs(implement.object)
		self:debug('Lowering duration (%s): %d ms', implement.object:getName(), implementLoweringDurationMs)
		if implementLoweringDurationMs > self.loweringDurationMs then
			self.loweringDurationMs = implementLoweringDurationMs
		end
		local jointDescIndex = implement.jointDescIndex
		-- now check the attacher joints
		if self.vehicle.spec_attacherJoints and jointDescIndex then
			local ajs = self.vehicle.spec_attacherJoints:getAttacherJoints()
			local ajLoweringDurationMs = ajs[jointDescIndex] and ajs[jointDescIndex].moveDefaultTime or 0
			self:debug('Lowering duration (%s attacher joint): %d ms', implement.object:getName(), ajLoweringDurationMs)
			if ajLoweringDurationMs > self.loweringDurationMs then
				self.loweringDurationMs = ajLoweringDurationMs
			end
		end
	end
	if not self.loweringDurationMs or self.loweringDurationMs <= 1 then
		self.loweringDurationMs = 2000
		self:debug('No lowering duration found, setting to: %d ms', self.loweringDurationMs)
	end
	self:debug('Final lowering duration: %d ms', self.loweringDurationMs)
end

--- Never continue automatically at a wait point
function FieldworkAIDriver:isAutoContinueAtWaitPointEnabled()
	return false
end

--- For each work area: create nodes to mark the front and the back of the area. These will be used
--- to determine when to raise/lower the tools
function FieldworkAIDriver:setMarkers()
	local addMarkers = function(object)
		self:debug('Finding work areas of %s', nameNum(object))
		for k, area in courseplay:workAreaIterator(object) do
			-- TODO: generalize work area types to ignore
			if area.start and area.height and area.width and
				area.type ~= WorkAreaType.RIDGEMARKER and
				area.type ~= WorkAreaType.COMBINESWATH and
				area.type ~= WorkAreaType.COMBINECHOPPER
			then
				-- place a node at the middle of the work area front
				local width, _, _ = localToLocal(area.width, area.start, 0, 0, 0)
				local frontMarkerNode = courseplay.createNode(nameNum(object) .. ' front marker', width / 2, 0, 0, area.start)
				-- place a node at the middle of the work area back
				local backMarkerNode = courseplay.createNode(nameNum(object) .. ' back marker', width / 2, 0, 0, area.height)
				table.insert(self.markers, {object = object, workArea = area, front = frontMarkerNode, back = backMarkerNode})
				self:debug('Markers added to %s - %s', nameNum(object), g_workAreaTypeManager.workAreaTypes[area.type].name)
			end
		end
	end
	-- first remove any old markers
	if self.markers then
		for _, markers in pairs(self.markers) do
			courseplay.destroyNode(markers.front)
			courseplay.destroyNode(markers.back)
		end
	end
	self.markers = {}
	-- now go ahead and try to find the real markers
	-- work areas of the vehicle itself
	addMarkers(self.vehicle)
	-- and then the work areas of all the implements
	for _, implement in pairs(self.vehicle:getAttachedImplements()) do
		addMarkers(implement.object)
	end
	local referenceNode = self.vehicle.cp.DirectionNode or self.vehicle.rootNode
	if #self.markers == 0 then
		-- make sure we always have a default front/back marker, placed on the direction node
		self.aiDriverData.frontMarkerNode = courseplay.createNode(self.vehicle:getName() .. ' front marker', 0, 0, 0, referenceNode)
		self.aiDriverData.backMarkerNode = courseplay.createNode(self.vehicle:getName() .. ' back marker', 0, 0, 0, referenceNode)
		table.insert(self.markers,
			{object = self.vehicle, front = self.aiDriverData.frontMarkerNode, back = self.aiDriverData.backMarkerNode})
	end
	-- now that we have all, find the foremost and the last
	-- place everything on the vehicle root node first
	self.frontMarkerDistance, self.backMarkerDistance = 0, 0
	local frontMarkerDistance, backMarkerDistance = math.huge, -math.huge
	for _, markers in pairs(self.markers) do
		local _, _, dz = localToLocal(referenceNode, markers.front, 0, 0, 0)
		self:debug(' -> %s: dz = %.1f', getName(markers.front), dz)
		if dz < frontMarkerDistance then
			frontMarkerDistance = dz
			self.frontMarkerDistance = -dz
			self.aiDriverData.frontMarkerNode = markers.front
		end
		_, _, dz = localToLocal(referenceNode, markers.back, 0, 0, 0)
		self:debug(' -> %s: dz = %.1f', getName(markers.back), dz)
		if dz > backMarkerDistance then
			backMarkerDistance = dz
			self.backMarkerDistance = -dz
			self.aiDriverData.backMarkerNode = markers.back
		end
	end
	-- set these up for turn.lua. TODO: pass in with the turn context and get rid of the aiFrontMarker and backMarkerOffset completely
	self.vehicle.cp.aiFrontMarker = self.frontMarkerDistance
	self.vehicle.cp.backMarkerOffset = self.backMarkerDistance

	self:debug('Front marker node: %s (%.1f m), back %s (%.1f) m',
		getName(self.aiDriverData.frontMarkerNode), self.frontMarkerDistance,
		getName(self.aiDriverData.backMarkerNode), self.backMarkerDistance)
end

---@param waypoint Waypoint
function FieldworkAIDriver:getFrontMarkerDistanceToWaypoint(ix)
	if self.aiDriverData.frontMarkerNode then
		local _, _, dz = self.course:getWaypointLocalPosition(self.aiDriverData.frontMarkerNode, ix)
		return dz
	else
		return nil
	end
end

---@param targetNode node at the first waypoint of the row, pointing in the direction of travel. This is where
--- the implement should be in the working position after a turn
function FieldworkAIDriver:shouldLowerImplements(turnEndNode, reversing)
	local _, _, dz = localToLocal(self.aiDriverData.frontMarkerNode or self.vehicle.rootNode, turnEndNode, 0, 0, 0)
	local loweringDistance
	if FieldworkAIDriver.hasImplementWithSpecialization(self.vehicle, SowingMachine) then
		-- sowing machines are stopped while lowering
		loweringDistance = 0
	else
		-- others can be lowered without stopping so need to start lowering before we get to the turn end to be
		-- in the working position by the time we get to the first waypoint of the next row
		loweringDistance = self.vehicle.lastSpeed * self:getLoweringDurationMs() + 0.5 -- vehicle.lastSpeed is in meters per millisecond
	end
		self:debug('dz = %.1f, loweringDistance = %.1f', dz, loweringDistance)
	if reversing then
		return dz < 0
	else
		-- dz will be negative as we are behind the target node
		return dz > - loweringDistance
	end
end

---@param targetNode node at the last waypoint of the row, pointing in the direction of travel. This is where
--- the implement should be raised when beginning a turn
function FieldworkAIDriver:shouldRaiseImplements(turnStartNode)
	-- turn start node in the front marker node's coordinate system
	local _, _, dz = localToLocal(turnStartNode, self.aiDriverData.frontMarkerNode or self.vehicle.rootNode, 0, 0, 0)
	self:debugSparse('shouldRaiseImplements: dz = %.1f', dz)
	-- turn start node just behind the marker
	return dz < 0
end


function FieldworkAIDriver:onDraw()
	if self.aiDriverData.frontMarkerNode and self.aiDriverData.backMarkerNode then
		DebugUtil.drawDebugNode(self.aiDriverData.frontMarkerNode, getName(self.aiDriverData.frontMarkerNode))
		DebugUtil.drawDebugNode(self.aiDriverData.backMarkerNode, getName(self.aiDriverData.backMarkerNode))
	end
	AIDriver.onDraw(self)
end