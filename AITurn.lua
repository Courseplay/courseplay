--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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
Turn maneuvers for the AI driver

All turns have three phases:

1. Finishing Row

Keep driving until it is time to raise the implements.

2. Turn

The actual turn maneuver starts at the moment when the implements are raised. The turn maneuver can be dynamically
controlled based on the vehicle's current position or follow a calculated course. Not all turns can be run dynamically,
and this also has to be enabled by the vehicle.cp.settings.useAiTurns.

Turn courses are calculated by the code in turn.lua (which historically also did the driving) and passed on the
PPC to follow.

3. Ending Turn

In this phase we put the vehicle on a path to align with the course following the turn and initiate the lowering
of implements when needed. From this point on, control is passed back to the AIDriver.

]]

---@class AITurn
---@field driver FieldworkAIDriver
---@field turnContext TurnContext
AITurn = CpObject()
AITurn.debugChannel = 12

function AITurn:init(vehicle, driver, turnContext, name)
	self:addState('INITIALIZING')
	self:addState('FINISHING_ROW')
	self:addState('TURNING')
	self:addState('ENDING_TURN')
	self:addState('REVERSING_AFTER_BLOCKED')
	self:addState('FORWARDING_AFTER_BLOCKED')
	self:addState('WAITING_FOR_PATHFINDER')
	self.vehicle = vehicle
	self.turningRadius = AIDriverUtil.getTurningRadius(vehicle)
	---@type AIDriver
	self.driver = driver
	-- turn handles its own waypoint changes
	self.driver.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
	---@type TurnContext
	self.turnContext = turnContext
	self.state = self.states.INITIALIZING
	self.name = name or 'AITurn'
end

function AITurn:addState(state)
	if not self.states then self.states = {} end
	self.states[state] = {name = state}
end

function AITurn:debug(...)
	courseplay.debugVehicle(self.debugChannel, self.vehicle, self.name .. ' state: ' .. self.state.name .. ' ' .. string.format( ... ))
end

--- Start the actual turn maneuver after the row is finished
function AITurn:startTurn()
	-- implement in derived classes
end

--- Stuff we need to do during the turn no matter what turn type we are using
function AITurn:turn()
	if self.driver:holdInTurnManeuver(false) then
		-- tell driver to stop if unloading or whatever
		self.driver:setSpeed(0)
	end
end

function AITurn:onBlocked()
	self:debug('onBlocked()')
end

function AITurn:onWaypointChange(ix)
	self:debug('onWaypointChange %d', ix)
	-- make sure to set the proper X offset if applicable (for turning plows for example)
	self.driver:setOffsetX()
end

function AITurn:onWaypointPassed(ix, course)
	self:debug('onWaypointPassed %d', ix)
	if ix == course:getNumberOfWaypoints() then
		self:debug('Last waypoint reached, this should not happen, resuming fieldwork')
		self.driver:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
	end
end

function AITurn.canMakeKTurn(vehicle, turnContext)
	if turnContext:isHeadlandCorner() then
		courseplay.debugVehicle(AITurn.debugChannel, vehicle, 'Headland turn, let turn.lua drive for now.')
		return false
	end
	if vehicle.cp.turnDiameter <= math.abs(turnContext.dx) then
		courseplay.debugVehicle(AITurn.debugChannel, vehicle, 'wide turn with no reversing (turn diameter = %.1f, dx = %.1f, let turn.lua do that for now.',
			vehicle.cp.turnDiameter, math.abs(turnContext.dx))
		return true
	end
	if not AIVehicleUtil.getAttachedImplementsAllowTurnBackward(vehicle) then
		courseplay.debugVehicle(AITurn.debugChannel, vehicle, 'Not all attached implements allow for reversing, use generated course turn')
		return false
	end
	if vehicle.cp.turnOnField and not AITurn.canTurnOnField(turnContext, vehicle) then
		courseplay.debugVehicle(AITurn.debugChannel, vehicle, 'Turn on field is on but there is not enough space, use generated course turn')
		return false
	end
	return true
end

---@param turnContext TurnContext
---@return boolean, number True if there's enough space to make a forward turn on the field. Also return the
---distance to reverse in order to be able to just make the turn on the field
function AITurn.canTurnOnField(turnContext, vehicle)
	local spaceNeededOnFieldForTurn = AIDriverUtil.getTurningRadius(vehicle) + vehicle.cp.workWidth / 2
	local distanceToFieldEdge = turnContext:getDistanceToFieldEdge(turnContext.vehicleAtTurnStartNode)
	courseplay.debugVehicle(AITurn.debugChannel, vehicle, 'Space needed to turn on field %.1f m', spaceNeededOnFieldForTurn)
	if distanceToFieldEdge then
		return (distanceToFieldEdge > spaceNeededOnFieldForTurn), spaceNeededOnFieldForTurn - distanceToFieldEdge
	else
		return false, 0
	end
end

function AITurn:setForwardSpeed()
	self.driver:setSpeed(math.min(self.vehicle.cp.speeds.turn, self.driver:getWorkSpeed()))
end

function AITurn:setReverseSpeed()
	self.driver:setSpeed(self.vehicle.cp.speeds.reverse)
end

function AITurn:drive(dt)
	local iAmDriving = true
	self:setForwardSpeed()
	if self.state == self.states.INITIALIZING then
		iAmDriving = false
		local rowFinishingCourse = self.turnContext:createFinishingRowCourse(self.vehicle)
		self.driver:startCourse(rowFinishingCourse, 1)
		self.state = self.states.FINISHING_ROW
		-- Finishing the current row
	elseif self.state == self.states.FINISHING_ROW then
		iAmDriving = self:finishRow(dt)
	elseif self.state == self.states.ENDING_TURN then
		-- Ending the turn (starting next row)
		iAmDriving = self:endTurn(dt)
	elseif self.state == self.states.WAITING_FOR_PATHFINDER then
		self.driver:setSpeed(0)
		iAmDriving = false
	else
		-- Performing the actual turn
		iAmDriving = self:turn(dt)
	end
	self.turnContext:drawDebug()
	return iAmDriving
end

-- default for 180 turns: we need to raise the implement (when finishing a row) when we reach the
-- workEndNode.
function AITurn:getRaiseImplementNode()
	return self.turnContext.workEndNode
end

function AITurn:finishRow(dt)
	-- keep driving straight until we need to raise our implements
	if self.driver:shouldRaiseImplements(self:getRaiseImplementNode()) then
		self.driver:raiseImplements()
		self:startTurn()
		self:debug('Row finished, starting turn.')
	end
	if self.driver:holdInTurnManeuver(true) then
		-- tell driver to stop while straw swath is active
		self.driver:setSpeed(0)
	end
	return false
end

function AITurn:endTurn(dt)
	-- keep driving on the turn ending temporary course until we need to lower our implements
	-- check implements only if we are more or less in the right direction (next row's direction)
	if self.turnContext:isDirectionCloseToEndDirection(self.driver:getDirectionNode(), 30) and
		self.driver:shouldLowerImplements(self.turnContext.turnEndWpNode.node, false) then
		self:debug('Turn ended, resume fieldwork')
		self.driver:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
	end
	return false
end

--[[
A K (3 point) turn to make a 180 to continue on the next row.addState
]]

---@class KTurn : AITurn
KTurn = CpObject(AITurn)

function KTurn:init(vehicle, driver, turnContext)
	AITurn.init(self, vehicle, driver, turnContext, 'KTurn')
	self:addState('FORWARD')
	self:addState('REVERSE')
	self:addState('FORWARD_ARC')
end

function KTurn:startTurn()
	self.state = self.states.FORWARD
end

function KTurn:turn(dt)
	-- we end the K turn with a temporary course leading straight into the next row. During this turn the
	-- AI driver's state remains TURNING and thus calls AITurn:drive() which wil take care of raising the implements
	local endTurn = function()
		self.vehicle:raiseAIEvent("onAITurnProgress", "onAIImplementTurnProgress", 100, self.turnContext:isLeftTurn())
		self.state = self.states.ENDING_TURN
		self.driver:startFieldworkCourseWithTemporaryCourse(self.endingTurnCourse, self.turnContext.turnEndWpIx)
	end

	AITurn.turn(self)

	local turnRadius = self.vehicle.cp.turnDiameter / 2
	if self.state == self.states.FORWARD then
		local dx, _, dz = self.turnContext:getLocalPositionFromTurnEnd(self.driver:getDirectionNode())
		self:setForwardSpeed()
		if dz > 0 then
			-- drive straight until we are beyond the turn end
			self.driver:driveVehicleBySteeringAngle(dt, true, 0, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		elseif not self.turnContext:isDirectionPerpendicularToTurnEndDirection(self.driver:getDirectionNode()) then
			-- full turn towards the turn end waypoint
			self.driver:driveVehicleBySteeringAngle(dt, true, 1, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		else
			-- drive straight ahead until we cross turn end line
			self.driver:driveVehicleBySteeringAngle(dt, true, 0, self.turnContext:isLeftTurn(), self.driver:getSpeed())
			if self.turnContext:isLateralDistanceGreater(dx, turnRadius * 1.05) then
				-- no need to reverse from here, we can make the turn
				self.endingTurnCourse = self.turnContext:createEndingTurnCourse2(self.vehicle)
				self:debug('K Turn: dx = %.1f, r = %.1f, no need to reverse.', dx, turnRadius)
				endTurn()
			else
				-- reverse until we can make turn to the turn end point
				self.vehicle:raiseAIEvent("onAITurnProgress", "onAIImplementTurnProgress", 50, self.turnContext:isLeftTurn())
				self.state = self.states.REVERSE
				self.endingTurnCourse = self.turnContext:createEndingTurnCourse2(self.vehicle)
				self:debug('K Turn: dx = %.1f, r = %.1f, reversing now.', dx, turnRadius)
			end
		end
	elseif self.state == self.states.REVERSE then
		-- reversing parallel to the direction between the turn start and turn end waypoints
		self:setReverseSpeed()
		self.driver:driveVehicleBySteeringAngle(dt, false, 0, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		local _, _, dz = self.endingTurnCourse:getWaypointLocalPosition(self.driver:getDirectionNode(), 1)
		if dz > 0  then
			-- we can make the turn from here
			self:debug('K Turn ending turn')
			endTurn()
		end
	elseif self.state == self.states.REVERSING_AFTER_BLOCKED then
		self:setReverseSpeed()
		self.driver:driveVehicleBySteeringAngle(dt, false, 0.6, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		if self.vehicle.timer > self.blockedTimer + 3500 then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after reversed due to being blocked')
		end
	elseif self.state == self.states.FORWARDING_AFTER_BLOCKED then
		self:setForwardSpeed()
		self.driver:driveVehicleBySteeringAngle(dt, true, 0.6, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		if self.vehicle.timer > self.blockedTimer + 3500 then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after forwarded due to being blocked')
		end
	end
	return true
end

function KTurn:onBlocked()
	if self.driver:holdInTurnManeuver(false) then
		-- not really blocked just waiting for the straw for example
		return
	end
	self.stateAfterBlocked = self.state
	self.blockedTimer = self.vehicle.timer
	if self.state == self.states.REVERSE then
		self.state = self.states.FORWARDING_AFTER_BLOCKED
		self:debug('Blocked, try forwarding a bit')
	elseif self.state == self.states.FORWARD then
		self.state = self.states.REVERSING_AFTER_BLOCKED
		self:debug('Blocked, try reversing a bit')
	end
end

--[[
  Headland turn for combines:
  1. drive forward to the field edge or the headland path edge
  2. start turning forward
  3. reverse straight and then align with the direction after the
     corner while reversing
  4. forward to the turn start to continue on headland
]]
---@class CombineHeadlandTurn : AITurn
CombineHeadlandTurn = CpObject(AITurn)

---@param driver AIDriver
---@param turnContext TurnContext
function CombineHeadlandTurn:init(vehicle, driver, turnContext)
	AITurn.init(self, vehicle, driver, turnContext, 'CombineHeadlandTurn')
	self:addState('FORWARD')
	self:addState('REVERSE_STRAIGHT')
	self:addState('REVERSE_ARC')
	self.turnRadius = self.vehicle.cp.turnDiameter / 2
	self.cornerAngleToTurn = turnContext:getCornerAngleToTurn()
	self.angleToTurnInReverse = math.abs(self.cornerAngleToTurn / 2)
	self.dxToStartReverseTurn = self.turnRadius - math.abs(self.turnRadius - self.turnRadius * math.cos(self.cornerAngleToTurn))
end

function CombineHeadlandTurn:startTurn()
	self.state = self.states.FORWARD
	self:debug('Starting combine headland turn')
end

-- in a combine headland turn we want to raise the header after it reached the field edge (or headland edge on an inner
-- headland.
function CombineHeadlandTurn:getRaiseImplementNode()
	return self.turnContext.lateWorkEndNode
end


function CombineHeadlandTurn:turn(dt)
	AITurn.turn(self)
	local dx, _, dz = self.turnContext:getLocalPositionFromTurnEnd(self.driver:getDirectionNode())
	local angleToTurnEnd = math.abs(self.turnContext:getAngleToTurnEndDirection(self.driver:getDirectionNode()))

	if self.state == self.states.FORWARD then
		self:setForwardSpeed()
		if angleToTurnEnd > self.angleToTurnInReverse then --and not self.turnContext:isLateralDistanceLess(dx, self.dxToStartReverseTurn) then
			-- full turn towards the turn end direction
			self.driver:driveVehicleBySteeringAngle(dt, true, 1, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		else
			-- reverse until we can make turn to the turn end point
			self.state = self.states.REVERSE_STRAIGHT
			self:debug('Combine headland turn start reversing straight')
		end

	elseif self.state == self.states.REVERSE_STRAIGHT then
		self:setReverseSpeed()
		self.driver:driveVehicleBySteeringAngle(dt, false, 0, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		if math.abs(dx) < 0.2  then
			self.state = self.states.REVERSE_ARC
			self:debug('Combine headland turn start reversing arc')
		end

	elseif self.state == self.states.REVERSE_ARC then
		self:setReverseSpeed()
		self.driver:driveVehicleBySteeringAngle(dt, false, 1, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		--if self.turnContext:isPointingToTurnEnd(self.driver:getDirectionNode(), 5)  then
		if angleToTurnEnd < math.rad(20) then
			self.state = self.states.ENDING_TURN
			self:debug('Combine headland turn forwarding again')
			-- lower implements here unconditionally (regardless of the direction, self:endTurn() would wait until we
			-- are pointing to the turn target direction)
			self.driver:lowerImplements()
			self.driver:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
		end
	elseif self.state == self.states.REVERSING_AFTER_BLOCKED then
		self:setReverseSpeed()
		self.driver:driveVehicleBySteeringAngle(dt, false, 0.6, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		if self.vehicle.timer > self.blockedTimer + 3500 then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after reversed due to being blocked')
		end
	elseif self.state == self.states.FORWARDING_AFTER_BLOCKED then
		self:setForwardSpeed()
		self.driver:driveVehicleBySteeringAngle(dt, true, 0.6, self.turnContext:isLeftTurn(), self.driver:getSpeed())
		if self.vehicle.timer > self.blockedTimer + 3500 then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after forwarded due to being blocked')
		end
	end
	return true
end

function CombineHeadlandTurn:onBlocked()
	self.stateAfterBlocked = self.state
	self.blockedTimer = self.vehicle.timer
	if self.state == self.states.REVERSE_ARC or self.state == self.states.REVERSE_STRAIGHT then
		self.state = self.states.FORWARDING_AFTER_BLOCKED
		self:debug('Blocked, try forwarding a bit')
	else
		self.state = self.states.REVERSING_AFTER_BLOCKED
		self:debug('Blocked, try reversing a bit')
	end
end

--[[
A turn maneuver following a course (waypoints created by turn.lua)
]]

---@class CourseTurn : AITurn
CourseTurn = CpObject(AITurn)

function CourseTurn:init(vehicle, driver, turnContext, fieldworkCourse, name)
	AITurn.init(self, vehicle, driver, turnContext, name or 'CourseTurn')
	-- adjust turn course for tight turns only for headland corners by default
	self.useTightTurnOffset = turnContext:isHeadlandCorner()
	self.fieldworkCourse = fieldworkCourse
end

function CourseTurn:setForwardSpeed()
	if self.turnCourse then
		local currentWpIx = self.turnCourse:getCurrentWaypointIx()
		if self.turnCourse:getDistanceFromFirstWaypoint(currentWpIx) > 10 and
				self.turnCourse:getDistanceToLastWaypoint(currentWpIx) > 10 then
			-- in the middle of a long turn maneuver we can drive faster...
			self.driver:setSpeed((self.vehicle.cp.speeds.field + self.vehicle.cp.speeds.turn) / 2)
		end
	else
		AITurn.setForwardSpeed(self)
	end
end

-- this turn starts when the vehicle reached the point where the implements are raised.
-- now use turn.lua to generate the turn maneuver waypoints
function CourseTurn:startTurn()
	if self.turnContext:isWideTurn(self.turningRadius * 2) then
		self:generatePathfinderTurn()
	else
		self:generateCalculatedTurn()
		self.driver:startFieldworkCourseWithTemporaryCourse(self.turnCourse, self.turnContext.turnEndWpIx)
		self.state = self.states.TURNING
	end
end

function CourseTurn:turn()

	AITurn.turn(self)
	self:updateTurnProgress()
	self:changeDirectionWhenAligned()

	if self.turnCourse:isTurnEndAtIx(self.turnCourse:getCurrentWaypointIx()) then
		self.state = self.states.ENDING_TURN
		self:debug('About to end turn')
	end
	-- return false to indicate we aren't driving, we want the PPC to drive
	return false
end

function CourseTurn:endTurn(dt)
-- keep driving on the turn course until we need to lower our implements
	if not self.implementsLowered and self.driver:shouldLowerImplements(self.turnContext.workStartNode, self.driver.ppc:isReversing()) then
		self:debug('Turn ending, lowering implements')
		self.driver:lowerImplements()
		self.implementsLowered = true
		if self.driver.ppc:isReversing() then
			-- when ending a turn in reverse, don't drive the rest of the course, switch right back to fieldwork
			self.driver:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
		end
	end
	return false
end

function CourseTurn:updateTurnProgress()
	local progress = self.turnCourse:getCurrentWaypointIx() / #self.turnCourse
	self.vehicle:raiseAIEvent("onAITurnProgress", "onAIImplementTurnProgress", progress, self.turnContext:isLeftTurn())
end

function CourseTurn:onWaypointChange(ix)
	AITurn.onWaypointChange(self, ix)
	if self.turnCourse then
		if self.useTightTurnOffset or self.turnCourse:useTightTurnOffset(ix) then
			-- adjust the course a bit to the outside in a curve to keep a towed implement on the course
			self.tightTurnOffset = AIDriverUtil.calculateTightTurnOffset(self.vehicle, self.turnCourse, self.tightTurnOffset, true)
			self.turnCourse:setOffset(self.tightTurnOffset, 0)
		end
	end
end


--- When switching direction during a turn, especially when switching to reverse we want to make sure
--- that a towed implement is aligned with the reverse direction (already straight behind the tractor when
--- starting to reverse). Turn courses are generated with a very long alignment section to allow for this with
--- the changeDirectionWhenAligned property set, indicating that we don't have to travel along the path, we can
--- change direction as soon as the implement is aligned.
--- So check that here and force a direction change when possible.
function CourseTurn:changeDirectionWhenAligned()
	if self.turnCourse:isChangeDirectionWhenAligned(self.turnCourse:getCurrentWaypointIx()) then
		local aligned = self.driver:areAllImplementsAligned(self.turnContext.turnEndWpNode.node)
		self:debug('aligned: %s', tostring(aligned))
		if aligned then
			-- find the next direction switch and continue course from there
			local nextDirectionChangeIx = self.turnCourse:getNextDirectionChangeFromIx(self.turnCourse:getCurrentWaypointIx())
			if nextDirectionChangeIx then
				self:debug('skipping to next direction change at %d', nextDirectionChangeIx + 1)
				self.driver:resumeAt(nextDirectionChangeIx + 1)
			end
		end
	end
end

function CourseTurn:generateCalculatedTurn()
	-- TODO: fix ugly dependency on global variables, there should be one function to create the turn maneuver
	self.vehicle.cp.turnStage = 1
	-- call turn() with stage 1 which will generate the turn waypoints (dt isn't used by that part)
	courseplay:turn(self.vehicle, 1, self.turnContext)
	-- they waypoints should now be in turnTargets, create a course based on that
	---@type Course
	self.turnCourse = Course(self.vehicle, self.vehicle.cp.turnTargets, true)
	-- clean up the turn global data
	courseplay:clearTurnTargets(self.vehicle)
end

function CourseTurn:generatePathfinderTurn()
	self.pathFindingStartedAt = self.vehicle.timer
	local done, path
	local turnEndNode, startOffset, goalOffset = self.turnContext:getTurnEndNodeAndOffsets()
	local canTurnOnField, distanceToReverse = AITurn.canTurnOnField(self.turnContext, self.vehicle)
	if not canTurnOnField and self.vehicle.cp.turnOnField then
		self:debug('Turn on field is on, generating reverse course before turning.')
		self.reverseBeforeStartingTurnWaypoints = self.turnContext:createReverseWaypointsBeforeStartingTurn(self.vehicle, distanceToReverse)
		startOffset = startOffset - distanceToReverse
	end

	if self.vehicle.cp.settings.usePathfindingInTurns:is(false) or self.turnContext:isSimpleWideTurn(self.turningRadius * 2) then
		self:debug('Wide turn: generate turn with Dubins path')
		path = PathfinderUtil.findDubinsPath(self.vehicle, startOffset, turnEndNode, goalOffset, self.turningRadius)
		return self:onPathfindingDone(path)
	else
		self:debug('Wide turn: generate turn with hybrid A*')
		self.driver.pathfinder, done, path = PathfinderUtil.findPathForTurn(self.vehicle, startOffset, turnEndNode, goalOffset,
				self.turningRadius, nil, self.fieldworkCourse)
		if done then
			return self:onPathfindingDone(path)
		else
			self.state = self.states.WAITING_FOR_PATHFINDER
			self.driver:setPathfindingDoneCallback(self, self.onPathfindingDone)
		end
	end
end

function CourseTurn:onPathfindingDone(path)
	if path and #path > 2 then
		self:debug('Pathfinding finished with %d waypoints (%d ms)', #path, self.vehicle.timer - (self.pathFindingStartedAt or 0))
		if self.reverseBeforeStartingTurnWaypoints and #self.reverseBeforeStartingTurnWaypoints > 0 then
			self.turnCourse = Course(self.vehicle, self.reverseBeforeStartingTurnWaypoints, true)
			self.turnCourse:appendWaypoints(courseGenerator.pointsToXzInPlace(path))
		else
			self.turnCourse = Course(self.vehicle, courseGenerator.pointsToXzInPlace(path), true)
		end
		self.turnCourse:setTurnEndForLastWaypoints(5)
		-- make sure we use tight turn offset towards the end of the course so a towed implement is aligned with the new row
		self.turnCourse:setUseTightTurnOffsetForLastWaypoints(10)
		self.turnContext:appendEndingTurnCourse(self.turnCourse)
		-- and once again, if there is an ending course, keep adjusting the tight turn offset
		-- TODO: should probably better done on onWaypointChange, to reset to 0
		self.turnCourse:setUseTightTurnOffsetForLastWaypoints(10)
	else
		self:debug('No path found in %d ms, falling back to normal turn course generator', self.vehicle.timer - (self.pathFindingStartedAt or 0))
		self:generateCalculatedTurn()
	end
	self.driver:startFieldworkCourseWithTemporaryCourse(self.turnCourse, self.turnContext.turnEndWpIx)
	self.state = self.states.TURNING
end

--- Combines (in general, when harvesting) in headland corners we want to work the corner first, then back up and then
--- turn so we harvest any area before we drive over it
---@class CombineCourseTurn : CourseTurn
CombineCourseTurn = CpObject(CourseTurn)

---@param driver AIDriver
---@param turnContext TurnContext
function CombineCourseTurn:init(vehicle, driver, turnContext, fieldworkCourse)
	CourseTurn.init(self, vehicle, driver, turnContext, fieldworkCourse,'CombineCourseTurn')
end

-- in a combine headland turn we want to raise the header after it reached the field edge (or headland edge on an inner
-- headland.
function CombineCourseTurn:getRaiseImplementNode()
	return self.turnContext.lateWorkEndNode
end
