--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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

A bale loader AI driver who can find and collect bales on a field
without a field course.

For unloading, it has the same behavior as the BaleLoaderAIDriver.

It also works with a bale wrapper, find and wrap all wrappable bales.

--]]

---@class BaleCollectorAIDriver : BaleLoaderAIDriver
BaleCollectorAIDriver = CpObject(BaleLoaderAIDriver)

BaleCollectorAIDriver.myStates = {
	SEARCHING_FOR_NEXT_BALE = {},
	WAITING_FOR_PATHFINDER = {},
	DRIVING_TO_NEXT_BALE = {},
	APPROACHING_BALE = {},
	WORKING_ON_BALE = {},
	REVERSING_AFTER_PATHFINDER_FAILURE ={}
}

function BaleCollectorAIDriver:init(vehicle)
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER,vehicle,'BaleCollectorAIDriver:init()')
	BaleLoaderAIDriver.init(self, vehicle)
	self:initStates(BaleCollectorAIDriver.myStates)
	self.mode = courseplay.MODE_BALE_COLLECTOR
	self.debugChannel = courseplay.DBG_MODE_7
	self.fieldId = 0
	self.bales = {}
end

function BaleCollectorAIDriver:setHudContent()
	-- skip the inheritance from fieldwork/bale loader as this is very special
	AIDriver.setHudContent(self)
	courseplay.hud:setBaleCollectorAIDriverContent(self.vehicle)
end

function BaleCollectorAIDriver:setUpAndStart(startingPoint)
	-- make sure we have a good turning radius set
	self.turnRadius = AIDriverUtil.getTurningRadius(self.vehicle)
	-- we only have an unload course since we are driving on the field autonomously
	self.unloadRefillCourse = Course(self.vehicle, self.vehicle.Waypoints, false)
	-- Set the offset to 0, we'll take care of getting the grabber to the right place
	self.vehicle.cp.settings.toolOffsetX:set(0)
	self.pathfinderFailureCount = 0

	if startingPoint:is(StartingPointSetting.START_COLLECTING_BALES) then
		-- to always have a valid course (for the traffic conflict detector mainly)
		self.fieldworkCourse = self:getStraightForwardCourse(25)
		self:startCourse(self.fieldworkCourse, 1)
		local myField = self.vehicle.cp.settings.baleCollectionField:get()
		if not myField or myField < 1 then
			self:stop("NO_FIELD_SELECTED")
			return
		end
		BaleWrapperAIDriver.initializeBaleWrapper(self)
		self.bales = self:findBales(myField)
		self:changeToFieldwork()
		self:collectNextBale()
	else
		local closestIx, _, closestIxRightDirection, _ =
			self.unloadRefillCourse:getNearestWaypoints(AIDriverUtil.getDirectionNode(self.vehicle))
		local startIx = 1
		if startingPoint:is(StartingPointSetting.START_AT_NEAREST_POINT) then
			startIx = closestIx
		elseif startingPoint:is(StartingPointSetting.START_AT_NEXT_POINT) then
			startIx = closestIxRightDirection
		end
		self:changeToUnloadOrRefill()
		self:startCourseWithPathfinding(self.unloadRefillCourse, startIx)
	end
end

function BaleCollectorAIDriver:setBaleCollectingState(state)
	self.baleCollectingState = state
	self:debug('baleCollectingState: %s', self.baleCollectingState.name)
end


function BaleCollectorAIDriver:collectNextBale()
	self:setBaleCollectingState(self.states.SEARCHING_FOR_NEXT_BALE)
	if #self.bales > 0 then
		self:findPathToNextBale()
	else
		self:info('No bales found, scan the field once more before leaving for the unload course.')
		self.bales = self:findBales(self.vehicle.cp.settings.baleCollectionField:get())
		if #self.bales > 0 then
			self:info('Found more bales, collecting them')
			self:findPathToNextBale()
			return
		end
		self:info('There really are no more bales on the field')
		if self.baleLoader and self:getFillLevel() > 0.1 then
			self:changeToUnloadOrRefill()
			self:startCourseWithPathfinding(self.unloadRefillCourse, 1)
		else
			self:stop('WORK_END')
		end
	end
end

--- Find bales on field
---@return BaleToCollect[] list of bales found
function BaleCollectorAIDriver:findBales(fieldId)
	self:debug('Finding bales on field %d...', fieldId or 0)
	local balesFound = {}
	for _, object in pairs(g_currentMission.nodeToObject) do
		if BaleToCollect.isValidBale(object, self.baleWrapper) then
			local bale = BaleToCollect(object)
			-- if the bale has a mountObject it is already on the loader so ignore it
			if (not fieldId or fieldId == 0 or bale:getFieldId() == fieldId) and
				not object.mountObject and
				object:getOwnerFarmId() == self.vehicle:getOwnerFarmId()
			then
				-- bales may have multiple nodes, using the object.id deduplicates the list
				balesFound[object.id] = bale
			end
		end
	end
	-- convert it to a normal array so lua can give us the number of entries
	local bales = {}
	for _, bale in pairs(balesFound) do
		table.insert(bales, bale)
	end
	self:debug('Found %d bales on field %d', #bales, fieldId)
	return bales
end

---@return BaleToCollect, number closest bale and its distance
function BaleCollectorAIDriver:findClosestBale(bales)
	local closestBale, minDistance, ix = nil, math.huge
	for i, bale in ipairs(bales) do
		local _, _, _, d = bale:getPositionInfoFromNode(AIDriverUtil.getDirectionNode(self.vehicle))
		self:debug('%d. bale (%d) in %.1f m', i, bale:getId(), d)
		if d < self.vehicle.cp.turnDiameter * 2 then
			-- if it is really close, check the length of the Dubins path
			-- as we may need to drive a loop first to get to it
			d = self:getDubinsPathLengthToBale(bale)
			self:debug('    Dubins length is %.1f m', d)
		end
		if d < minDistance then
			closestBale = bale
			minDistance = d
			ix = i
		end
	end
	return closestBale, minDistance, ix
end

function BaleCollectorAIDriver:getDubinsPathLengthToBale(bale)
	local start = PathfinderUtil.getVehiclePositionAsState3D(self.vehicle)
	local goal = self:getBaleTarget(bale)
	local solution = PathfinderUtil.dubinsSolver:solve(start, goal, self.turnRadius)
	return solution:getLength(self.turnRadius)
end

function BaleCollectorAIDriver:findPathToNextBale()
	if not self.bales then return end
	local bale, d, ix = self:findClosestBale(self.bales)
	if ix then
		if bale:isLoaded() then
			self:debug('Bale %d is already loaded, skipping', bale:getId())
			table.remove(self.bales, ix)
		elseif not self:isObstacleAhead() then
			self:startPathfindingToBale(bale)
			-- remove bale from list
			table.remove(self.bales, ix)
		else
			self:debug('There is an obstacle ahead, backing up a bit and retry')
			self:startReversing()
		end
	end
end

--- The trick here is to get a target direction at the bale
function BaleCollectorAIDriver:getBaleTarget(bale)
	-- first figure out the direction at the goal, as the pathfinder needs that.
	-- for now, just use the direction from our location towards the bale
	local xb, zb, yRot, d = bale:getPositionInfoFromNode(AIDriverUtil.getDirectionNode(self.vehicle))
	return State3D(xb, -zb, courseGenerator.fromCpAngle(yRot))
end

---@param bale BaleToCollect
function BaleCollectorAIDriver:startPathfindingToBale(bale)
	if not self.pathfinder or not self.pathfinder:isActive() then
		self.pathfindingStartedAt = self.vehicle.timer
		local safeDistanceFromBale = bale:getSafeDistance()
		local halfVehicleWidth = self.vehicle.sizeWidth and self.vehicle.sizeWidth / 2 or 1.5
		self:debug('Start pathfinding to next bale (%d), safe distance from bale %.1f, half vehicle width %.1f',
			bale:getId(), safeDistanceFromBale, halfVehicleWidth)
		local goal = self:getBaleTarget(bale)
		local offset = Vector(0, safeDistanceFromBale + halfVehicleWidth + 0.2)
		goal:add(offset:rotate(goal.t))
		local done, path, goalNodeInvalid
		self.pathfinder, done, path, goalNodeInvalid =
			PathfinderUtil.startPathfindingFromVehicleToGoal(self.vehicle, goal, false, self.fieldId, {})
		if done then
			return self:onPathfindingDoneToNextBale(path, goalNodeInvalid)
		else
			self:setBaleCollectingState(self.states.WAITING_FOR_PATHFINDER)
			self:setPathfindingDoneCallback(self, self.onPathfindingDoneToNextBale)
			return true
		end
	else
		self:debug('Pathfinder already active')
	end
end

function BaleCollectorAIDriver:onPathfindingDoneToNextBale(path, goalNodeInvalid)
	if path and #path > 2 then
		self.pathfinderFailureCount = 0
		self:debug('Found path (%d waypoints, %d ms)', #path, self.vehicle.timer - (self.pathfindingStartedAt or 0))
		self.fieldworkCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		self:startCourse(self.fieldworkCourse, 1)
		self:debug('Driving to next bale')
		self:setBaleCollectingState(self.states.DRIVING_TO_NEXT_BALE)
		return true
	else
		self.pathfinderFailureCount = self.pathfinderFailureCount + 1
		if self.pathfinderFailureCount == 1 then
			self:debug('Finding path to next bale failed, trying next bale')
			self:setBaleCollectingState(self.states.SEARCHING_FOR_NEXT_BALE)
		elseif self.pathfinderFailureCount == 2 then
			if self:isNearFieldEdge() then
				self.pathfinderFailureCount = 0
				self:debug('Finding path to next bale failed twice, we are close to the field edge, back up a bit and then try again')
				self:startReversing()
			else
				self:debug('Finding path to next bale failed twice, but we are not too close to the field edge, trying another bale')
				self:setBaleCollectingState(self.states.SEARCHING_FOR_NEXT_BALE)
			end
		else
			self:info('Pathfinding failed three times, giving up')
			self.pathfinderFailureCount = 0
			self:stop('WORK_END')
		end
		return false
	end
end

function BaleCollectorAIDriver:startReversing()
	self:startCourse(self:getStraightReverseCourse(10), 1)
	self:setBaleCollectingState(self.states.REVERSING_AFTER_PATHFINDER_FAILURE)
end

function BaleCollectorAIDriver:isObstacleAhead()
	-- check the proximity sensor first
	if self.forwardLookingProximitySensorPack then
		local d, vehicle, _, deg, dAvg = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
		if d < 1.2 * self.turnRadius then
			self:debug('Obstacle ahead at %.1f m', d)
			return true
		end
	end
	-- then a more thorough check
	local leftOk, rightOk, straightOk = PathfinderUtil.checkForObstaclesAhead(self.vehicle, self.turnRadius)
	-- if at least one is ok, we are good to go.
	return not (leftOk or rightOk or straightOk)
end

function BaleCollectorAIDriver:isNearFieldEdge()
	local x, _, z = localToWorld(AIDriverUtil.getDirectionNode(self.vehicle), 0, 0, 0)
	local vehicleIsOnField = courseplay:isField(x, z, 1, 1)
	x, _, z = localToWorld(AIDriverUtil.getDirectionNode(self.vehicle), 0, 0, 1.2 * self.turnRadius)
	local isFieldInFrontOfVehicle = courseplay:isField(x, z, 1, 1)
	self:debug('vehicle is on field: %s, field in front of vehicle: %s',
		tostring(vehicleIsOnField), tostring(isFieldInFrontOfVehicle))
	return vehicleIsOnField and not isFieldInFrontOfVehicle
end

function BaleCollectorAIDriver:onLastWaypoint()
	if self.state == self.states.ON_FIELDWORK_COURSE and self.fieldworkState == self.states.WORKING then
		if self.baleCollectingState == self.states.DRIVING_TO_NEXT_BALE then
			self:debug('last waypoint while driving to next bale reached')
			self:startApproachingBale()
		elseif self.baleCollectingState == self.states.WORKING_ON_BALE then
			self:debug('last waypoint on bale pickup reached, start collecting bales again')
			self:collectNextBale()
		elseif self.baleCollectingState == self.states.APPROACHING_BALE then
			self:debug('looks like somehow missed a bale, rescanning field')
			self.bales = self:findBales(self.vehicle.cp.settings.baleCollectionField:get())
			self:collectNextBale()
		elseif self.baleCollectingState == self.states.REVERSING_AFTER_PATHFINDER_FAILURE then
			self:debug('backed up after pathfinder failed, trying again')
			self:setBaleCollectingState(self.states.SEARCHING_FOR_NEXT_BALE)
		end
	else
		BaleLoaderAIDriver.onLastWaypoint(self)
	end
end

function BaleCollectorAIDriver:onEndCourse()
	if self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE or
		self.state == self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE then
		self:debug('Back from unload course, check for bales again')
		self.bales = self:findBales(self.vehicle.cp.settings.baleCollectionField:get())
		self:changeToFieldwork()
		self:collectNextBale()
	else
		BaleLoaderAIDriver.onEndCourse(self)
	end
end

function BaleCollectorAIDriver:startApproachingBale()
	self:debug('Approaching bale...')
	self:startCourse(self:getStraightForwardCourse(20), 1)
	self:setBaleCollectingState(self.states.APPROACHING_BALE)
end

--- Called from the generic driveFieldwork(), this the part doing the actual work on the field after/before all
--- implements are started/lowered etc.
function BaleCollectorAIDriver:work()
	if self.baleCollectingState == self.states.SEARCHING_FOR_NEXT_BALE then
		self:setSpeed(0)
		self:debug('work: searching for next bale')
		self:collectNextBale()
	elseif self.baleCollectingState == self.states.WAITING_FOR_PATHFINDER then
		self:setSpeed(0)
	elseif self.baleCollectingState == self.states.DRIVING_TO_NEXT_BALE then
		self:setSpeed(self.vehicle:getSpeedLimit())
	elseif self.baleCollectingState == self.states.APPROACHING_BALE then
		self:setSpeed(self:getWorkSpeed() / 2)
		self:approachBale()
	elseif self.baleCollectingState == self.states.WORKING_ON_BALE then
		self:workOnBale()
		self:setSpeed(0)
	elseif self.baleCollectingState == self.states.REVERSING_AFTER_PATHFINDER_FAILURE then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	end
	self:checkFillLevels()
end

function BaleCollectorAIDriver:approachBale()
	if self.baleLoader then
		if self.baleLoader.spec_baleLoader.grabberMoveState then
			self:debug('Start picking up bale')
			self:setBaleCollectingState(self.states.WORKING_ON_BALE)
		end
	end
	if self.baleWrapper then
		BaleWrapperAIDriver.handleBaleWrapper(self)
		if self.baleWrapper.spec_baleWrapper.baleWrapperState ~= BaleWrapper.STATE_NONE then
			self:debug('Start wrapping bale')
			self:setBaleCollectingState(self.states.WORKING_ON_BALE)
		end
	end
end

function BaleCollectorAIDriver:workOnBale()
	if self.baleLoader then
		if not self.baleLoader.spec_baleLoader.grabberMoveState then
			self:debug('Bale picked up, moving on to the next')
			self:collectNextBale()
		end
	end
	if self.baleWrapper then
		BaleWrapperAIDriver.handleBaleWrapper(self)
		if self.baleWrapper.spec_baleWrapper.baleWrapperState == BaleWrapper.STATE_NONE then
			self:debug('Bale wrapped, moving on to the next')
			self:collectNextBale()
		end
	end
end

function BaleCollectorAIDriver:calculateTightTurnOffset()
	self.tightTurnOffset = 0
end

function BaleCollectorAIDriver:getFillLevel()
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	for fillType, info in pairs(fillLevelInfo) do
		if 	fillType == FillType.SQUAREBALE or
			fillType == FillType.SQUAREBALE_WHEAT or
			fillType == FillType.SQUAREBALE_BARLEY or
			fillType == FillType.ROUNDBALE or
			fillType == FillType.ROUNDBALE_WHEAT or
			fillType == FillType.ROUNDBALE_BARLEY or
			fillType == FillType.ROUNDBALE_GRASS or
			fillType == FillType.ROUNDBALE_DRYGRASS then
			return info.fillLevel
		end
	end
end