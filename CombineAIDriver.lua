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

---@class CombineAIDriver : UnloadableFieldworkAIDriver
CombineAIDriver = CpObject(UnloadableFieldworkAIDriver)

-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
CombineAIDriver.PIPE_STATE_MOVING = 0
CombineAIDriver.PIPE_STATE_CLOSED = 1
CombineAIDriver.PIPE_STATE_OPEN = 2

-- fill level when we start making a pocket to unload if we are on the outermost headland
CombineAIDriver.pocketFillLevelFullPercentage = 95

CombineAIDriver.myStates = {
	PULLING_BACK_FOR_UNLOAD = {},
	WAITING_FOR_UNLOAD_AFTER_PULLED_BACK = {},
	RETURNING_FROM_PULL_BACK = {},
	REVERSING_TO_MAKE_A_POCKET = {},
	MAKING_POCKET = {},
	WAITING_FOR_UNLOAD_IN_POCKET = {},
	RETURNING_FROM_POCKET = {}
}

function CombineAIDriver:init(vehicle)
	courseplay.debugVehicle(11, vehicle, 'CombineAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self:initStates(CombineAIDriver.myStates)
	self.fruitLeft, self.fruitRight = 0, 0
	self.litersPerMeter = 0
	self.fillLevelAtLastWaypoint = 0
	self.beaconLightsActive = false
	-- distance keep to the right when pulling back to make room for the tractor
	self.pullBackSideOffset = math.min(self.vehicle.cp.workWidth, 6)
	-- should be at pullBackSideOffset to the right at pullBackDistanceStart
	self.pullBackDistanceStart = self.vehicle.cp.turnDiameter * 0.7
	-- and back up another bit
	self.pullBackDistanceEnd = self.pullBackDistanceStart + 10
	-- when making a pocket, how far to back up before changing to forward
	self.pocketReverseDistance = 25
	self.lastEmptyTimestamp = 0

	if self.vehicle.spec_combine then
		self.combine = self.vehicle.spec_combine
	else
		local combineImplement = FieldworkAIDriver.getImplementWithSpecialization(self.vehicle, Combine)
		if combineImplement then
			self.combine = combineImplement.spec_combine
		else
			self:error('Vehicle is not a combine and could not find implement with spec_combine')
		end
	end

	if self.vehicle.spec_pipe then
		self.pipe = self.vehicle.spec_pipe
	else
		local implementWithPipe = FieldworkAIDriver.getImplementWithSpecialization(self.vehicle, Pipe)
		if implementWithPipe then
			self.pipe = implementWithPipe.spec_pipe
		else
			self:info('Could not find implement with pipe')
		end
	end
end

function CombineAIDriver:setHudContent()
	UnloadableFieldworkAIDriver.setHudContent(self)
	courseplay.hud:setCombineAIDriverContent(self.vehicle)
end

function CombineAIDriver:drive(dt)
	-- handle the pipe in any state
	self:handlePipe()
	-- the rest is the same as the parent class
	UnloadableFieldworkAIDriver.drive(self, dt)
end

function CombineAIDriver:onWaypointPassed(ix)
	if self.turnIsDriving then
		self:debug('onWaypointPassed %d, ignored as turn is driving now', ix)
		return
	end
	self:checkFruit()
	-- make sure we start making a pocket while we still have some fill capacity left as we'll be
	-- harvesting fruit while making the pocket
	if self:shouldMakePocket() then
		self.fillLevelFullPercentage = self.pocketFillLevelFullPercentage
	end
	self:checkDistanceUntilFull(ix)
	if self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldWorkUnloadOrRefillState == self.states.MAKING_POCKET and
		self.unloadInPocketIx and ix == self.unloadInPocketIx then
		-- we are making a pocket and reached the waypoint where we are going to stop and wait for unload
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_OR_REFILL
		self:debug('Waiting for unload in the pocket')
		self:setInfoText(self:getFillLevelInfoText())
		self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_IN_POCKET
		-- reset offset to return to the original up/down row after we unloaded in the pocket
		self.aiDriverOffsetX = 0
	end
	if self.returnedFromPocketIx and self.returnedFromPocketIx == ix then
		-- back to normal look ahead distance for PPC, no tight turns are needed anymore
		self:debug('Reset PPC to normal lookahead distance')
		self.ppc:setNormalLookaheadDistance()
	end
	UnloadableFieldworkAIDriver.onWaypointPassed(self, ix)
end

function CombineAIDriver:changeToFieldworkUnloadOrRefill()
	if self.vehicle.cp.realisticDriving then
		self:checkFruit()
		-- TODO: check around turn maneuvers we may not want to pull back before a turn
		if self:shouldMakePocket() then
			-- I'm on the edge of the field or fruit is on both sides, make a pocket on the right side and wait there for the unload
			local pocketCourse, nextIx = self:createPocketCourse()
			if pocketCourse then
				self:debug('No room to the left, making a pocket for unload')
				self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
				self.fieldWorkUnloadOrRefillState = self.states.REVERSING_TO_MAKE_A_POCKET
				self:startCourse(pocketCourse, 1, self.course, nextIx)
				-- tighter turns
				self.ppc:setShortLookaheadDistance()
			else
				-- revert to normal behavior
				UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
			end
		elseif self:shouldPullBack() then
			-- is our pipe in the fruit? (assuming pipe is on the left side)
			local pullBackCourse = self:createPullBackCourse()
			if pullBackCourse then
				self:debug('Pipe in fruit, pulling back to make room for unloading')
				self.fieldworkState = self.states.UNLOAD_OR_REFILL_ON_FIELD
				self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_RAISE
				self.courseAfterPullBack = self.course
				self.ixAfterPullBack = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
				-- tighter turns
				self.ppc:setShortLookaheadDistance()
				self:startCourse(pullBackCourse, 1, self.course, self.ixAfterPullBack)
			else
				-- revert to normal behavior
				UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
			end
		else
			-- pipe not in fruit, combine not on outermost headland, just do the normal thing
			UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
		end
	else
		UnloadableFieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
	end
end

--- Stop for unload/refill while driving the fieldwork course
function CombineAIDriver:driveFieldworkUnloadOrRefill()
	if self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_RAISE then
		self:setSpeed(0)
		-- wait until we stopped before raising the implements
		if self:isStopped() then
			self:debug('implements raised, start pulling back')
			self:stopWork()
			self.fieldWorkUnloadOrRefillState = self.states.PULLING_BACK_FOR_UNLOAD
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldWorkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
		self:setSpeed(self.vehicle.cp.speeds.reverse)
	elseif self.fieldWorkUnloadOrRefillState == self.states.MAKING_POCKET then
		self:setSpeed(self:getWorkSpeed())
	elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
		self:setSpeed(self.vehicle.cp.speeds.turn)
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET then
		if self:unloadFinished() then
			self:clearInfoText(self:getFillLevelInfoText())
			self:debug('Unloading in pocket finished, returning to fieldwork')
			self.fillLevelFullPercentage = self.normalFillLevelFullPercentage
			self:changeToFieldwork()
		else
			self:setSpeed(0)
		end
	elseif self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK then
		-- don't move when pulled back until unloading is finished
		if self:unloadFinished() then
			self:clearInfoText(self:getFillLevelInfoText())
			local pullBackReturnCourse = self:createPullBackReturnCourse()
			if pullBackReturnCourse then
				self.fieldWorkUnloadOrRefillState = self.states.RETURNING_FROM_PULL_BACK
				self:debug('Unloading finished, returning to fieldwork on return course')
				self:startCourse(pullBackReturnCourse, 1, self.courseAfterPullBack, self.ixAfterPullBack)
			else
				self:debug('Unloading finished, returning to fieldwork directly')
				self.ppc:setNormalLookaheadDistance()
				self:changeToFieldwork()
			end
		else
			self:setSpeed(0)
		end
	else
		UnloadableFieldworkAIDriver.driveFieldworkUnloadOrRefill(self)
	end
end

function CombineAIDriver:onNextCourse(ix)
	if self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD then
		if self.fieldWorkUnloadOrRefillState == self.states.PULLING_BACK_FOR_UNLOAD then
			-- pulled back, now wait for unload
			self.fieldWorkUnloadOrRefillState = self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK
			self:debug('Pulled back, now wait for unload')
			self:setInfoText(self:getFillLevelInfoText())
		elseif self.fieldWorkUnloadOrRefillState == self.states.RETURNING_FROM_PULL_BACK then
			self:debug('Pull back finished, returning to fieldwork')
			self:changeToFieldwork()
		elseif self.fieldWorkUnloadOrRefillState == self.states.REVERSING_TO_MAKE_A_POCKET then
			self:debug('Reversed, now start making a pocket to waypoint %d', self.unloadInPocketIx)
			self.fieldWorkUnloadOrRefillState = self.states.MAKING_POCKET
			self.aiDriverOffsetX = self.pullBackSideOffset
		end
	elseif self.fieldworkState == self.states.TURNING then
		self.ppc:setNormalLookaheadDistance()
		-- make sure the next waypoint is in front of us. It can be behind us after a turn with multitools where the
		-- x offset is high (wide tools)
		self.ppc:initialize(self.course:getNextFwdWaypointIxFromVehiclePosition(ix, self:getDirectionNode(), 0))
		UnloadableFieldworkAIDriver.onNextCourse(self)
	else
		UnloadableFieldworkAIDriver.onNextCourse(self)
	end
end

function CombineAIDriver:unloadFinished()
	local discharging = false
	if self.pipe then
		discharging = self.pipe:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
	end
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)

	-- unload is done when fill levels are ok (not full) and not discharging anymore (either because we
	-- are empty or the trailer is full)
	return (self:allFillLevelsOk() and not discharging) or fillLevel < 0.1
end

function CombineAIDriver:shouldMakePocket()
	-- on the outermost headland clockwise (field edge) or fruit both sides
	return not self.fieldOnLeft or (self.fruitLeft > 0.75 and self.fruitRight > 0.75)
end

function CombineAIDriver:shouldPullBack()
	-- is our pipe in the fruit? (assuming pipe is on the left side)
	return self.fruitLeft > self.fruitRight
end

function CombineAIDriver:checkFruit()
	-- getValidityOfTurnDirections() wants to have the vehicle.aiDriveDirection, so get that here.
	local dx,_,dz = localDirectionToWorld(self.vehicle:getAIVehicleDirectionNode(), 0, 0, 1)
	local length = MathUtil.vector2Length(dx,dz)
	dx = dx / length
	dz = dz / length
	self.vehicle.aiDriveDirection = {dx, dz}
	self.fruitLeft, self.fruitRight = AIVehicleUtil.getValidityOfTurnDirections(self.vehicle)
	-- Is there field on my left side?
	local x, _, z = localToWorld(self:getDirectionNode(), self.vehicle.cp.workWidth, 0, 0)
	self.fieldOnLeft = courseplay:isField(x, z, 1, 1)
	self:debug('Fruit left: %.2f right %.2f, field on left %s', self.fruitLeft, self.fruitRight, tostring(self.fieldOnLeft))
end

function CombineAIDriver:checkDistanceUntilFull(ix)
	-- calculate fill rate so the combine driver knows if it can make the next row without unloading
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
	if ix > 1 then
		if self.fillLevelAtLastWaypoint and self.fillLevelAtLastWaypoint > 0 and self.fillLevelAtLastWaypoint <= fillLevel then
			self.litersPerMeter = (fillLevel - self.fillLevelAtLastWaypoint) / self.course:getDistanceToNextWaypoint(ix - 1)
			-- smooth a bit
			self.fillLevelAtLastWaypoint = (self.fillLevelAtLastWaypoint + fillLevel) / 2
		else
			-- no history yet, so make sure we don't end up with some unrealistic numbers
			self.litersPerMeter = 0
			self.fillLevelAtLastWaypoint = fillLevel
		end
		self:debug('Fill rate is %.1f liter/meter', self.litersPerMeter)
	end
	local dToNextTurn = self.course:getDistanceToNextTurn(ix) or -1
	local lNextRow = self.course:getNextRowLength(ix) or -1
	if dToNextTurn > 0 and lNextRow > 0 and self.litersPerMeter > 0 then
		local dUntilFull = (self.combine:getFillUnitCapacity(self.combine.fillUnitIndex) - fillLevel) / self.litersPerMeter
		self:debug('dUntilFull: %.1f m, dToNextTurn: %.1f m, lNextRow = %.1f m', dUntilFull, dToNextTurn, lNextRow)
		if dUntilFull > dToNextTurn and dUntilFull < dToNextTurn + lNextRow then
			self:debug('Will be full in the next row' )
		end
	end
end

function CombineAIDriver:updateLightsOnField()
	-- handle beacon lights to call unload driver
	-- copy/paste from AIDriveStrategyCombine
	local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
	local capacity = self.vehicle:getFillUnitCapacity(self.combine.fillUnitIndex)
	if fillLevel > (0.8 * capacity) then
		if not self.beaconLightsActive then
			self.vehicle:setAIMapHotspotBlinking(true)
			self.vehicle:setBeaconLightsVisibility(true)
			self.beaconLightsActive = true
		end
	else
		if self.beaconLightsActive then
			self.vehicle:setAIMapHotspotBlinking(false)
			self.vehicle:setBeaconLightsVisibility(false)
			self.beaconLightsActive = false
		end
	end
end

--- Create a temporary course to pull back to the right when the pipe is in the fruit so the tractor does not have
-- to drive in the fruit to get under the pipe
function CombineAIDriver:createPullBackCourse()
	-- all we need is a waypoint on our right side towards the back
	self.returnPoint = {}
	self.returnPoint.x, _, self.returnPoint.z = getWorldTranslation(self.vehicle.rootNode)

	local dx,_,dz = localDirectionToWorld(self:getDirectionNode(), 0, 0, 1)
	self.returnPoint.rotation = MathUtil.getYRotationFromDirection(dx, dz)
	dx,_,dz = localDirectionToWorld(self:getDirectionNode(), 0, 0, -1)
	local reverseRotation = MathUtil.getYRotationFromDirection(dx, dz)

	local x1, _, z1 = localToWorld(self:getDirectionNode(), -self.pullBackSideOffset, 0, -self.pullBackDistanceStart)
	local x2, _, z2 = localToWorld(self:getDirectionNode(), -self.pullBackSideOffset, 0, -self.pullBackDistanceEnd)
	-- both points must be on the field
	if courseplay:isField(x1, z1) and courseplay:isField(x2, z2) then
		local vx, _, vz = getWorldTranslation(self:getDirectionNode())
		self:debug('%.2f %.2f %d %d', self.returnPoint.rotation, reverseRotation, math.deg(self.returnPoint.rotation), math.deg(reverseRotation))
		local pullBackWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, vx, vz, x1, z1, reverseRotation, true)
		if not pullBackWaypoints then
			self:debug("Can't create alignment course for pull back")
			return nil
		end
		table.insert(pullBackWaypoints, {x = x2, z = z2})
		-- this is the backing up part, so make sure we are reversing here
		for _, p in ipairs(pullBackWaypoints) do
			p.rev = true
		end
		return Course(self.vehicle, pullBackWaypoints, true)
	else
		self:debug("Pull back course would be outside of the field")
		return nil
	end
end

function CombineAIDriver:createPullBackReturnCourse()
	local x1, _, z1 = localToWorld(self:getDirectionNode(), 0, 0, self.pullBackDistanceStart / 2)
	-- don't need to check if points are on the field, we did it when we got here
	local pullBackReturnWaypoints = courseplay:getAlignWpsToTargetWaypoint(self.vehicle, x1, z1, self.returnPoint.x, self.returnPoint.z, self.returnPoint.rotation, true)
	if not pullBackReturnWaypoints then
		self:debug("Can't create alignment course for pull back return")
		return nil
	end
	return Course(self.vehicle, pullBackReturnWaypoints, true)
end

--- Create a temporary course to make a pocket in the fruit on the right, so we can move into that pocket and
--- wait for the unload there. This way the unload tractor does not have to leave the field.
--- We create a temporary course to reverse back far enough. After that, we return to the main course but
--- set an offset to the right
function CombineAIDriver:createPocketCourse()
	local startIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
	-- find the waypoint we want to back up to
	local backIx = self.course:getPreviousWaypointIxWithinDistance(startIx, self.pocketReverseDistance)
	if not backIx then return nil end
	-- this is where we'll stop in the pocket for unload
	self.unloadInPocketIx = startIx - 2
	-- this where we are back on track after returning from the pocket
	self.returnedFromPocketIx = self.ppc:getCurrentWaypointIx()
	self:debug('Backing up %.1f meters from waypoint %d to %d to make a pocket', self.pocketReverseDistance, startIx, backIx)
	if startIx - backIx > 2 then
		local pocketReverseWaypoints = {}
		for i = startIx, backIx, -1 do
			if self.course:isTurnStartAtIx(i) then
				self:debug('There is a turn behind me at waypoint %d, no pocket', i)
				return nil
			end
			local x, _, z = self.course:getWaypointPosition(i)
			table.insert(pocketReverseWaypoints, {x = x, z = z, rev = true})
		end
		return Course(self.vehicle, pocketReverseWaypoints, true), backIx + 1
	else
		self:debug('Not enough waypoints behind me, no pocket')
		return nil
	end
end

--- Disable auto stop for choppers as when we stop the engine they'll also raise implements and the way we restart them
--- won't lower the header. So for now, just don't let them to stop the engine
function CombineAIDriver:isEngineAutoStopEnabled()
	return not self:isChopper() and AIDriver.isEngineAutoStopEnabled(self)
end

--- Compatibility function for turn.lua to check if the vehicle should stop during a turn (for example while it
--- is held for unloading or waiting for the straw swath to stop
--- Turn.lua calls this in every cycle during the turn and will stop the vehicle if this returns true.
---@param isApproaching boolean if true we are still in the turn approach phase (still working on the field,
---not yet reached the turn start
function CombineAIDriver:holdInTurnManeuver(isApproaching)
	self:debugSparse('held for unload %s, straw active %s, approaching = %s',
		tostring(self.heldForUnloadRefill), tostring(self.combine.strawPSenabled), tostring(isApproaching))
	return self.heldForUnloadRefill or (self.combine.strawPSenabled and not isApproaching)
end

--- Should we return to the first point of the course after we are done?
function CombineAIDriver:shouldReturnToFirstPoint()
	-- Combines stay where they are after finishing work
	-- TODO: call unload driver
	return false
end

-- TODO: either implement these cleanly or remove them from AIDriver
function CombineAIDriver:getHasCourseplayers()
	return self.vehicle.courseplayers and #self.vehicle.courseplayers ~= 0
end

function CombineAIDriver:getFirstCourseplayer()
	return self.vehicle.courseplayers and self.vehicle.courseplayers[1]
end

--- Interface for AutoDrive
---@return boolean true when the combine is waiting to be unloaded
function CombineAIDriver:isWaitingForUnload()
	return self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		(self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL or
		 self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_IN_POCKET or
		 self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_AFTER_PULLED_BACK)
end

function CombineAIDriver:startTurn(ix)
	self:debug('Starting a combine turn.')

	self:setMarkers()
	self.turnContext = TurnContext(self.course, ix, self.aiDriverData, self.vehicle.cp.workWidth)

	-- Combines drive special headland corner maneuvers
	if self.turnContext:isHeadlandCorner() then
		if courseplay.globalSettings.useAITurns:is(true) and
			(not self.course:isOnOutermostHeadland(ix) or
			(self.course:isOnOutermostHeadland(ix) and not self.vehicle.cp.turnOnField))
		then
			self:debug('Use AI turn in the headland corner.')
			self.aiTurn = CombineHeadlandTurn(self.vehicle, self, self.turnContext)
			self.fieldworkState = self.states.TURNING
		else
			local cornerCourse, nextIx = self:createHeadlandCornerCourse(ix, self.turnContext)
			if cornerCourse then
				self:debug('Starting a corner with a course with %d waypoints, will continue fieldwork at waypoint %d',
					cornerCourse:getNumberOfWaypoints(), nextIx)
				self.fieldworkState = self.states.TURNING
				self:startCourse(cornerCourse, 1, self.course, nextIx)
				-- tighter turns
				self.ppc:setShortLookaheadDistance()
			else
				self:debug('Could not create a corner course, falling back to default headland turn')
				UnloadableFieldworkAIDriver.startTurn(self, ix)
			end
		end
	else
		self:debug('Non headland turn.')
		UnloadableFieldworkAIDriver.startTurn(self, ix)
	end
end

---@param turnContext TurnContext
---@param ix number
function CombineAIDriver:createHeadlandCornerCourse(ix, turnContext)
	if self.course:isOnOutermostHeadland(ix) and self.vehicle.cp.turnOnField then
		-- create a pocket in the corner so the combine stays on the field
		return self:createOuterHeadlandCornerCourse(turnContext)
	else
		return self:createInnerHeadlandCornerCourse(turnContext)
	end
end

--- Simple combine headland corner maneuver
---@param turnContext TurnContext
function CombineAIDriver:createInnerHeadlandCornerCourse(turnContext)
	local cornerWaypoints = {}
	local turnRadius = self.vehicle.cp.turnDiameter / 2
	local offset = turnRadius * 0.25
	local corner = turnContext:createCorner(self.vehicle, turnRadius)
	local wp = corner:getPointAtDistanceFromCornerStart(self.vehicle.cp.workWidth / 2)
	table.insert(cornerWaypoints, wp)
	-- drive forward up to the headland edge
	local wp = corner:getPointAtDistanceFromCornerStart(-self.vehicle.cp.workWidth / 2)
	table.insert(cornerWaypoints, wp)
	-- drive further forward and start turning slightly
	wp = corner:getPointAtDistanceFromCornerStart(-self.vehicle.cp.workWidth / 2 - offset, -offset)
	table.insert(cornerWaypoints, wp)
	-- reverse back to set up for the headland after the corner
	wp = corner:getPointAtDistanceFromCornerEnd(-turnRadius * 0.5, self.vehicle.cp.workWidth / 2 + offset)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	-- this last waypoint isn't really needed. The only reason we add it is to turn the combine into the
	-- (sort of) new direction before finishing the turn, so if this is a combine on multitool turn with offset on
	-- the inner side of the corner, it'll find the right waypoint to continue and does not drive a loop (at least until
	-- we properly generate offset courses as those have a problem at corners)
	wp = corner:getPointAtDistanceFromCornerEnd(self.vehicle.cp.workWidth / 2, self.vehicle.cp.workWidth / 3)
	table.insert(cornerWaypoints, wp)
	corner:delete()
	return Course(self.vehicle, cornerWaypoints, true), turnContext.turnEndWpIx
end

--- Create a pocket in the next row at the corner to stay on the field during the turn maneuver.
---@param turnContext TurnContext
function CombineAIDriver:createOuterHeadlandCornerCourse(turnContext)
	local cornerWaypoints = {}
	local turnRadius = self.vehicle.cp.turnDiameter / 2
	local offset = math.min(turnRadius * 0.6, self.vehicle.cp.workWidth)
	local corner = turnContext:createCorner(self.vehicle, turnRadius)
	local d = -self.vehicle.cp.workWidth / 2 + self.frontMarkerDistance
	local wp = corner:getPointAtDistanceFromCornerStart(d + 2)
	wp.speed = self.vehicle.cp.speeds.turn * 0.75
	table.insert(cornerWaypoints, wp)
	-- drive forward up to the field edge
	wp = corner:getPointAtDistanceFromCornerStart(d)
	wp.speed = self.vehicle.cp.speeds.turn * 0.75
	table.insert(cornerWaypoints, wp)
	-- drive back to prepare for making a pocket
	-- reverse back to set up for the headland after the corner
	wp = corner:getPointAtDistanceFromCornerStart(d + turnRadius)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(d + turnRadius * 2)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	-- now make a pocket in the inner headland to make room to turn
	wp = corner:getPointAtDistanceFromCornerStart(d + turnRadius * 1.6, -offset * 0.8)
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(d + turnRadius * 1.2, -offset * 0.9)
	if not courseplay:isField(wp.x, wp.z) then
		self:debug('No field where the pocket would be, this seems to be a 270 corner')
		corner:delete()
		return nil
	end
	table.insert(cornerWaypoints, wp)
	-- drive forward to the field edge on the inner headland
	wp = corner:getPointAtDistanceFromCornerStart(d, -offset)
	wp.speed = self.vehicle.cp.speeds.turn * 0.75
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(d + turnRadius)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerEnd(turnRadius / 3, turnRadius / 4)
	wp.speed = self.vehicle.cp.speeds.turn * 0.5
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerEnd(turnRadius, turnRadius / 4)
	wp.speed = self.vehicle.cp.speeds.turn * 0.5
	table.insert(cornerWaypoints, wp)
	corner:delete()
	return Course(self.vehicle, cornerWaypoints, true), turnContext.turnEndWpIx
end

function CombineAIDriver:onBlocked()
	self:debug('Combine blocked, trying to switch to next waypoint...')
	local nextWpIx = self.ppc:getCurrentWaypointIx() + 1
	if nextWpIx > self.course:getNumberOfWaypoints() then
		self:debug('Combine blocked, already at last waypoint, ending course.')
		self:onLastWaypoint()
	else
		self:debug('Combine blocked, trying to switch to next (%d) waypoint', nextWpIx)
		self.ppc:initialize(nextWpIx)
	end
end


function CombineAIDriver:isChopper()
	return self.combine:getFillUnitCapacity(self.combine.fillUnitIndex) > 10000000
end

function CombineAIDriver:handlePipe()
	if self.pipe then
		if self:isChopper() then
			self:handleChopperPipe()
		else
			self:handleCombinePipe()
		end
	end
end

function CombineAIDriver:handleCombinePipe()
	if self:isFillableTrailerUnderPipe() or self:isAutoDriveWaitingForPipe() then
		self:openPipe()
	else
		self:closePipe()
	end
end


--- Support for AutoDrive mod: they'll only find us if we open the pipe
function CombineAIDriver:isAutoDriveWaitingForPipe()
	return self.vehicle.spec_autodrive and self.vehicle.spec_autodrive.combineIsCallingDriver and self.vehicle.spec_autodrive:combineIsCallingDriver(self.vehicle)
end

function CombineAIDriver:handleChopperPipe()
	if self.state == self.states.ON_FIELDWORK_COURSE then
		-- chopper always opens the pipe
		self:openPipe()
		-- and stops if there's no trailer in sight
		local fillLevel = self.vehicle:getFillUnitFillLevel(self.combine.fillUnitIndex)
		--self:debug('filltype = %s, fillLevel = %.1f', self:getFillType(), fillLevel)
		-- not using isFillableTrailerUnderPipe() as the chopper sometimes has FillType.UNKNOWN
		if fillLevel > 0.01 and self:getFillType() ~= FillType.UNKNOWN and
			not (self:isFillableTrailerUnderPipe() and self:canDischarge())	then
			self:debugSparse('Chopper waiting for trailer, fill level %f', fillLevel)
			self:setSpeed(0)
		end
	else
		self:closePipe()
	end
end

function CombineAIDriver:openPipe()
	if self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_MOVING and
		self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_OPEN then
		self:debug('Opening pipe')
		self.pipe:setPipeState(self.PIPE_STATE_OPEN)
	end
end

function CombineAIDriver:closePipe()
	if self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_MOVING and
		self.pipe.currentState ~= CombineAIDriver.PIPE_STATE_CLOSED then
		self:debug('Closing pipe')
		self.pipe:setPipeState(self.PIPE_STATE_CLOSED)
	end
end

function CombineAIDriver:shouldStopForUnloading(pc)
	local stop = false
	if self.vehicle.cp.stopWhenUnloading and self.pipe then
		if self.pipe.currentState == CombineAIDriver.PIPE_STATE_OPEN and
			g_updateLoopIndex > self.lastEmptyTimestamp + 600 then
			-- stop only if the pipe is open AND we have been emptied more than 1000 cycles ago.
			-- this makes sure the combine will start driving after it is emptied but the trailer
			-- is still under the pipe
			stop = true
		end
	end
	if pc and pc < 0.1 then
		-- remember the time we were completely unloaded.
		self.lastEmptyTimestamp = g_updateLoopIndex
	end
	return stop
end

function CombineAIDriver:isFillableTrailerUnderPipe()
	local canLoad = false
	if self.pipe then
		for trailer, value in pairs(self.pipe.objectsInTriggers) do
			if value > 0 then
				local fillType = self:getFillType()
				--self:debug('ojects = %d, fillType = %s fus=%s', value, tostring(fillType), tostring(trailer:getFillUnits()))
				if fillType then
					local fillUnits = trailer:getFillUnits()
					for i=1, #fillUnits do
						local supportedFillTypes = trailer:getFillUnitSupportedFillTypes(i)
						if supportedFillTypes[fillType] and trailer:getFillUnitFreeCapacity(i) > 0 then
							canLoad = true
						end
					end
				end
			end
		end
	end
	return canLoad
end

-- even if there is a trailer in range, we should not start moving until the pipe is turned towards the
-- trailer and can start discharging.
function CombineAIDriver:canDischarge()
	-- TODO: self.vehicle should be the combine, which may not be the vehicle in case of towed harvesters
	local dischargeNode = self.combine:getCurrentDischargeNode()
	local targetObject, _ = self.combine:getDischargeTargetObject(dischargeNode)
	return targetObject
end
