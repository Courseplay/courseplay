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

This is a simplified implementation of a pure pursuit algorithm
to follow a two dimensional path consisting of waypoints.

See the paper

Steering Control of an Autonomous Ground Vehicle with Application to the DARPA
Urban Challenge By Stefan F. Campbell

We use the terminology of that paper here, like 'relevant path segment', 'goal point', etc. and follow the
algorithm to search for the goal point as described in this paper.

PURPOSE

1. Provide a goal point to steer towards to.
   Contrary to the old implementation, we are not steering to a waypoint, instead to a goal
   point which is in a given look ahead distance from the vehicle on the path.

2. Determine when to switch to the next waypoint (and avoid circling)
   Regardless of the above, the rest of the Courseplay code still needs to know the current
   waypoint as we progress along the path.

HOW TO USE

1. add a PPC to the vehicle with new()
2. when the vehicle starts driving, call initialize()
3. in every update cycle, call update(). This will calculate the goal point and the current waypoint
4. this PPC can not reverse with a trailer (but it it fine without a trailer) We rely on the code in reverse.lua
   to do that. Therefore, use setReverseActive(true) to tell the PPC that now reverse is driving, so it
   can deactivate itself. When reverse is done, call initialize with the first forward waypoint and setReverseActive(false).waypoint
5. use the convenience functions getCurrentWaypointPosition(), shouldChangeWaypoint(), reachedLastWaypoint() and switchToNextWaypoint()
   in your code instead of directly checking and manipulating vehicle.Waypoints. These provide the legacy behavior when
   the PPC is not active (for example due to reverse driving) or when disabled
6. you can use enable() and disable() to enable/disable the PPC. When disabled and you are using the above functions,
   it'll behave as the legacy code.

]]

---@class PurePursuitController
PurePursuitController = CpObject()

-- normal lookahead distance
PurePursuitController.normalLookAheadDistance = 5
PurePursuitController.shortLookaheadDistance = 2.5

-- constructor
function PurePursuitController:init(vehicle)
	self.normalLookAheadDistance = math.min(vehicle.cp.turnDiameter / 2, 6)
	self.shortLookaheadDistance = self.normalLookAheadDistance / 2
	self.veryShortLookaheadDistance = 2
	-- normal lookahead distance
	self.baseLookAheadDistance = self.normalLookAheadDistance
	-- adapted look ahead distance 
	self.lookAheadDistance = self.baseLookAheadDistance
	-- when transitioning from forward to reverse, this close we have to be to the waypoint where we
	-- change direction before we switch to the next waypoint
	self.distToSwitchWhenChangingToReverse = 1
	self.vehicle = vehicle
	self:resetControlledNode()
	self.name = nameNum(vehicle)
	-- node on the current waypoint
	self.currentWpNode = WaypointNode( self.name .. '-currentWpNode', true)
	-- waypoint at the start of the relevant segment
	self.relevantWpNode = WaypointNode( self.name .. '-relevantWpNode', true)
	-- waypoint at the end of the relevant segment
	self.nextWpNode = WaypointNode( self.name .. '-nextWpNode', true)
	-- the current goal node
	self.goalWpNode = WaypointNode( self.name .. '-goalWpNode', false)
	-- vehicle position projected on the path, not used for anything other than debug display
	self.projectedPosNode = courseplay.createNode( self.name .. '-projectedPosNode', 0, 0, 0)
	self.isReverseActive = false
	-- enable PPC by default for developers only
	self.enabled = CpManager.isDeveloper
	-- current goal point search case as described in the paper, for diagnostics only
	self.case = 0
	-- index of the first node of the path (where PPC is initialized and starts driving
	self.firstIx = 1
	self.crossTrackError = 0
	self.lastPassedWaypointIx = nil
end

-- destructor
function PurePursuitController:delete()
	self.currentWpNode:destroy()
	self.relevantWpNode:destroy()
	self.nextWpNode:destroy()
	courseplay.destroyNode(self.projectedPosNode)
	self.goalWpNode:destroy()
end

---@param course Course
function PurePursuitController:setCourse(course)
	self.course = course
end

--- Set an offset for the current course.
function PurePursuitController:setOffset(x, z)
	self.course:setOffset(x, z)
end

--- Use a different node to track/control, for example the root node of a trailed implement
-- instead of the tractor's root node.
function PurePursuitController:setControlledNode(node)
	self.controlledNode = node
end

--- reset controlled node to the default (vehicle's own root node)
function PurePursuitController:resetControlledNode()
	-- our reference node we are tracking/controlling, by default it is the vehicle's root/direction node
	self.controlledNode = self.vehicle.cp.DirectionNode or self.vehicle.rootNode
end

-- initialize controller before driving
function PurePursuitController:initialize(ix, aiDriver)
	-- for now, if no course set, use the vehicle's current waypoints
	if not self.course then
		self.course = Course(self.vehicle, self.vehicle.Waypoints)
	end
	-- if we use the legacy waypointIndex then we need the original index (in case of combined courses)
	-- TODO: always require to pass in the index, don't use global variable
	self.firstIx = ix and ix or self.course:findOriginalIx(self.vehicle.cp.waypointIndex)
	-- relevantWpNode always points to the point where the relevant path segment starts
	self.relevantWpNode:setToWaypoint(self.course, self.firstIx )
	self.nextWpNode:setToWaypoint(self.course, self.firstIx)
	self.wpBeforeGoalPointIx = self.nextWpNode.ix
	self.currentWpNode:setToWaypoint(self.course, self.firstIx )
	courseplay.debugVehicle(12, self.vehicle, 'PPC: initialized to waypoint %d of %d', self.firstIx, self.course:getNumberOfWaypoints())
	self.isReverseActive = false
	self.lastPassedWaypointIx = nil
	if aiDriver then
		self.aiDriver = aiDriver
	end
	self.sendWaypointChange = nil
	self.sendWaypointPassed = nil
end

-- TODO: make this more generic and allow registering multiple listeners?
-- could also implement listeners for events like notify me when within x meters of a waypoint, etc.
function PurePursuitController:setAIDriver(aiDriver)
	-- for backwards compatibility, PPC currently is initialized by the legacy code so
	-- by the time AIDriver takes over, it is already there. So let AIDriver tell PPC who's driving.
	self.aiDriver = aiDriver
end

function PurePursuitController:setLookaheadDistance(d)
	self.baseLookAheadDistance = d
end

function PurePursuitController:setNormalLookaheadDistance()
	self.baseLookAheadDistance = self.normalLookAheadDistance
end

function PurePursuitController:setShortLookaheadDistance()
	self.baseLookAheadDistance = self.shortLookaheadDistance
end

function PurePursuitController:getLookaheadDistance()
	return self.baseLookAheadDistance
end

function PurePursuitController:getCurrentWaypointIx()
	return self.currentWpNode.ix
end

function PurePursuitController:getLastPassedWaypointIx()
	return self.lastPassedWaypointIx
end

--- Compatibility function to return the original waypoint index as in vehicle.Waypoints. This
-- is the same as self.currentWpNode.ix unless we have combined courses where the legacy CP code
-- concatenates all courses into one Waypoints array (as opposed to the AIDriver which splits these
-- combined courses into its parts). The rest of the CP code however (HUD, reverse, etc.) works with
-- vehicle.Waypoints and vehicle.cp.waypointIndex and therefore expects the combined index
function PurePursuitController:getCurrentOriginalWaypointIx()
	return self.course.waypoints[self:getCurrentWaypointIx()].cpIndex
end

function PurePursuitController:update()
	self:findRelevantSegment()
	self:findGoalPoint()
	self:notifyListeners()
end

function PurePursuitController:notifyListeners()
	if self.aiDriver then
		if self.sendWaypointChange and self.aiDriver.onWaypointChange then
			self.aiDriver:onWaypointChange(self.sendWaypointChange)
		end
		if self.sendWaypointPassed and self.aiDriver.onWaypointPassed then
			self.aiDriver:onWaypointPassed(self.sendWaypointPassed)
		end
	end
	self.sendWaypointChange = nil
	self.sendWaypointPassed = nil
end


function PurePursuitController:havePassedWaypoint(wpNode)
	local vx, vy, vz = getWorldTranslation(self.controlledNode)
	local dx, _, dz = worldToLocal(wpNode.node, vx, vy, vz);
	local dFromNext = MathUtil.vector2Length(dx, dz)
	-- courseplay.debugVehicle(12, self.vehicle, 'PPC: checking %d, dz: %.1f, dFromNext: %.1f', wpNode.ix, dz, dFromNext)
	local result = false
	if self.course:switchingDirectionAt(wpNode.ix) then
		-- switching direction at this waypoint, so this is pointing into the opposite direction.
		-- we have to make sure we drive up to this waypoint close enough before we switch to the next
		-- so wait until dz < 0, that is, we are behind the waypoint 
		if dz < 0 then
			result = true
		end
	else
		-- we are not transitioning between forward and reverse
		-- we have passed the next waypoint if our dz in the waypoints coordinate system is positive, that is,
		-- when looking into the direction of the waypoint, we are ahead of it.
		-- Also, when on the process of aligning to the course, like for example the vehicle just started
		-- driving towards the first waypoint, we have to make sure we actually get close to the waypoint 
		-- (as we may already be in front of it), so try get within the turn diameter * 2.
		if dz >= 0 and dFromNext < self.vehicle.cp.turnDiameter * 2 then
			result = true
		end
	end
	if result and not self:reachedLastWaypoint() then
		if not self.lastPassedWaypointIx or (self.lastPassedWaypointIx ~= wpNode.ix) then
			self.lastPassedWaypointIx = wpNode.ix
			courseplay.debugVehicle(12, self.vehicle, 'PPC: waypoint %d passed, dz: %.1f %s %s', wpNode.ix, dz,
				self.course.waypoints[wpNode.ix].rev and 'reversed' or '',
				self.course:switchingDirectionAt(wpNode.ix) and 'switching direction' or '')
			-- notify listeners about the passed waypoint
			self.sendWaypointPassed = self.lastPassedWaypointIx
		end
	end
	return result
end

function PurePursuitController:havePassedAnyWaypointBetween(fromIx, toIx)
	local node = WaypointNode( self.name .. '-node', false)
	local result, passedWaypointIx = false, 0
	-- math.max so we do one loop even if toIx < fromIx
	-- courseplay.debugVehicle(12, self.vehicle, 'PPC: checking between %d and %d', fromIx, toIx)
	for ix = fromIx, math.max(toIx, fromIx) do
		node:setToWaypoint(self.course, ix)
		if self:havePassedWaypoint(node) then
			result = true
			passedWaypointIx = ix
			break
		end

	end
	node:destroy()
	return result, passedWaypointIx
end

-- Finds the relevant segment.
-- Sets the vehicle's projected position on the path.
function PurePursuitController:findRelevantSegment()
	-- vehicle position
	local vx, vy, vz = getWorldTranslation(self.controlledNode)
	local lx, _, dzFromRelevant = worldToLocal(self.relevantWpNode.node, vx, vy, vz);
	self.crossTrackError = lx
	-- adapt our lookahead distance based on the error
	self.lookAheadDistance = math.min(self.baseLookAheadDistance + math.abs(self.crossTrackError), self.baseLookAheadDistance * 2)
	-- projected vehicle position/rotation	
	local px, py, pz = localToWorld(self.relevantWpNode.node, 0, 0, dzFromRelevant)
	local _, yRot, _ = getRotation(self.relevantWpNode.node)
	setTranslation(self.projectedPosNode, px, py, pz)
	setRotation(self.projectedPosNode, 0, yRot, 0)
	-- we check all waypoints between the relevant and the one before the goal point as the goal point
	-- may have moved several waypoints up if there's a very sharp turn for example and in that case 
	-- the vehicle may never reach some of the waypoint in between.
	local passed, ix
	if self.course:switchingDirectionAt(self.nextWpNode.ix) then
		-- don't look beyond a direction switch as we'll always be past a reversing waypoint
		-- before we reach it.
		passed, ix = self:havePassedWaypoint(self.nextWpNode), self.nextWpNode.ix
	else
		passed, ix = self:havePassedAnyWaypointBetween(self.nextWpNode.ix, self.wpBeforeGoalPointIx)
	end
	if passed then
		self.relevantWpNode:setToWaypoint(self.course, ix)
		self.nextWpNode:setToWaypoint(self.course, self.relevantWpNode.ix + 1)
		if not self:reachedLastWaypoint() then
			-- disable debugging once we reached the last waypoint. Otherwise we'd keep logging
			-- until the user presses 'Stop driver'.
			courseplay.debugVehicle(12, self.vehicle, 'PPC: relevant waypoint: %d, crosstrack error: %.1f', self.relevantWpNode.ix, self.crossTrackError)
		end
	end
	if courseplay.debugChannels[12] then
		cpDebug:drawLine(px, py + 3, pz, 1, 1, 0, px, py + 1, pz);
		DebugUtil.drawDebugNode(self.relevantWpNode.node, string.format('ix = %d\nrelevant\nnode', self.relevantWpNode.ix))
		DebugUtil.drawDebugNode(self.projectedPosNode, 'projected\nvehicle\nposition')
	end
end

-- Now, from the relevant section forward we search for the goal point, which is the one
-- lying lookAheadDistance in front of us on the path
-- this is the algorithm described in Chapter 2 of the paper
function PurePursuitController:findGoalPoint()

	local vx, _, vz = getWorldTranslation(self.controlledNode)
	--local vx, vy, vz = getWorldTranslation(self.projectedPosNode);

	-- create helper nodes at the relevant and the next wp. We'll move these up on the path until we reach the segment
	-- in lookAheadDistance
	local node1 = WaypointNode( self.name .. '-node1', false)
	local node2 = WaypointNode( self.name .. '-node2', false)

	-- starting at the relevant segment walk up the path to find the segment on
	-- which the goal point lies. This is the segment intersected by the circle with lookAheadDistance radius
	-- around the vehicle.
	local ix = self.relevantWpNode.ix
	while ix <= self.course:getNumberOfWaypoints() do
		node1:setToWaypoint(self.course, ix)
		node2:setToWaypointOrBeyond(self.course, ix + 1, self.lookAheadDistance)
		local x1, _, z1 = getWorldTranslation(node1.node)
		local x2, _, z2 = getWorldTranslation(node2.node)
		-- distance between the vehicle position and the ends of the segment
		local q1 = courseplay:distance(x1, z1, vx, vz) -- distance from node 1
		local q2 = courseplay:distance(x2, z2, vx, vz) -- distance from node 2
		local l = courseplay:distance(x1, z1, x2, z2)  -- length of path segment (distance between node 1 and 2
		--courseplay.debugVehicle(12, self.vehicle, 'PPC: ix=%d, q1=%.1f, q2=%.1f la=%.1f l=%.1f', ix, q1, q2, self.lookAheadDistance, l)

		-- case i (first node outside virtual circle but not yet reached) or (not the first node but we are way off the track)
		if (ix == self.firstIx and ix ~= self.lastPassedWaypointIx) and
			q1 >= self.lookAheadDistance and q2 >= self.lookAheadDistance then
			self:showGoalpointDiag(1, 'PPC: initializing, ix=%d, q1=%.1f, q2=%.1f, la=%.1f', ix, q1, q2, self.lookAheadDistance)
			-- If we weren't on track yet (after initialization, on our way to the first/initialized waypoint)
			-- set the goal to the relevant WP
			self.goalWpNode:setToWaypoint(self.course, self.relevantWpNode.ix)
			-- and also the current waypoint is now at the relevant WP
			self:setCurrentWaypoint(self.relevantWpNode.ix)
			break
		end

		-- case ii (common case)
		if q1 <= self.lookAheadDistance and q2 >= self.lookAheadDistance then
			self:showGoalpointDiag(2, 'PPC: common case, ix=%d, q1=%.1f, q2=%.1f la=%.1f', ix, q1, q2, self.lookAheadDistance)
			local cosGamma = ( q2 * q2 - q1 * q1 - l * l ) / (-2 * l * q1)
			local p = q1 * cosGamma + math.sqrt(q1 * q1 * (cosGamma * cosGamma - 1) + self.lookAheadDistance * self.lookAheadDistance)
			local gx, gy, gz = localToWorld(node1.node, 0, 0, p)
			setTranslation(self.goalWpNode.node, gx, gy + 1, gz)
			self.wpBeforeGoalPointIx = ix
			-- current waypoint is the waypoint at the end of the path segment
			self:setCurrentWaypoint(ix + 1)
			--courseplay.debugVehicle(12, self.vehicle, "PPC: %d, p=%.1f", self.currentWpNode.ix, p)
			break
		end

		-- cases iii, iv and v
		-- these two may have a problem and actually prevent the vehicle go back to the waypoint
		-- when wandering way off track, therefore we try to catch this case in case i
		if ix == self.relevantWpNode.ix and q1 >= self.lookAheadDistance and q2 >= self.lookAheadDistance then
			if math.abs(self.crossTrackError) <= self.lookAheadDistance then
				-- case iii (two intersection points)
				self:showGoalpointDiag(3, 'PPC: two intersection points, ix=%d, q1=%.1f, q2=%.1f, la=%.1f, cte=%.1f', ix, q1, q2, 
					self.lookAheadDistance, self.crossTrackError)
				local p = math.sqrt(self.lookAheadDistance * self.lookAheadDistance - self.crossTrackError * self.crossTrackError)
				local gx, gy, gz = localToWorld(self.projectedPosNode, 0, 0, p)
				setTranslation(self.goalWpNode.node, gx, gy + 1, gz)
				self.wpBeforeGoalPointIx = ix
				-- current waypoint is the waypoint at the end of the path segment
				self:setCurrentWaypoint(ix + 1)
			else
				-- case iv (no intersection points)
				-- case v ( goal point dead zone)
				self:showGoalpointDiag(4, 'PPC: no intersection points, ix=%d, q1=%.1f, q2=%.1f, la=%.1f, cte=%.1f', ix, q1, q2, 
					self.lookAheadDistance, self.crossTrackError)
				-- set the goal to the projected position
				local gx, gy, gz = localToWorld(self.projectedPosNode, 0, 0, 0)
				setTranslation(self.goalWpNode.node, gx, gy + 1, gz)
				self.wpBeforeGoalPointIx = ix
				-- current waypoint is the waypoint at the end of the path segment
				self:setCurrentWaypoint(ix + 1)
			end
			break
		end
		-- none of the above, continue search with the next path segment
		ix = ix + 1
	end
	
	node1:destroy()
	node2:destroy()
	
	if courseplay.debugChannels[12] then
		local gx, gy, gz = localToWorld(self.goalWpNode.node, 0, 0, 0)
		cpDebug:drawLine(gx, gy + 3, gz, 0, 1, 0, gx, gy + 1, gz);
		DebugUtil.drawDebugNode(self.currentWpNode.node, string.format('ix = %d\ncurrent\nwaypoint', self.currentWpNode.ix))
	end
end

-- set the current waypoint for the rest of Courseplay and to notify listeners
function PurePursuitController:setCurrentWaypoint(ix)
	-- this is the current waypoint for the rest of Courseplay code, the waypoint we are driving to
	-- but never, ever go back. Instead just leave this loop and keep driving to the current goal node
	if ix < self.currentWpNode.ix then
		if g_updateLoopIndex % 60 == 0 then
			courseplay.debugVehicle(12, self.vehicle, "PPC: Won't step current waypoint back from %d to %d.", self.currentWpNode.ix, ix)
		end
	elseif ix >= self.currentWpNode.ix then
		local prevIx = self.currentWpNode.ix
		self.currentWpNode:setToWaypointOrBeyond(self.course, ix, self.lookAheadDistance)
		-- if ix > #self.course, currentWpNode.ix will always be set to #self.course and the change detection won't work
		-- therefore, only call listeners if ix <= #self.course
		if ix ~= prevIx and ix <= self.course:getNumberOfWaypoints() then
			-- remember to send notification at the end of the loop
			self.sendWaypointChange = self.currentWpNode.ix
		end
	end
end

function PurePursuitController:showGoalpointDiag(case, ...)
	local diagText = string.format(...)
	if courseplay.debugChannels[12] then
		DebugUtil.drawDebugNode(self.goalWpNode.node, diagText)
	end
	if case ~= self.case then
		courseplay.debugVehicle(12, self.vehicle, ...)
		self.case = case
	end
end

-- is the code in reverse.lua driving? This happens when the
-- tractor has a trailer or some attachment. We can't handle that
-- here as then we have to control the trailer and not the tractor
-- so let that code do the waypoint switching
function PurePursuitController:setReverseActive(isReverseActive)
	self.isReverseActive = isReverseActive
end

function PurePursuitController:disable()
	if self.enabled then
		courseplay.debugVehicle(12, self.vehicle, 'PPC: disabled.', self.currentWpNode.ix)
	end
	self.enabled = false
end

function PurePursuitController:enable()
	if not self.enabled then
		courseplay.debugVehicle(12, self.vehicle, 'PPC: enabled.', self.currentWpNode.ix)
	end
	self.enabled = true
end

function PurePursuitController:toggleEnable()
	if self.enabled then
		self:disable()
	else
		self:enable()
	end
end

function PurePursuitController:isEnabled()
	return self.enabled
end

function PurePursuitController:isActive()
	-- Let the code in reverse.lua do its magic when reversing.
	-- That code seems to be robust against circling anyway
	-- we only control when the user enabled us and not reverse.lua is driving
	return self.enabled and not self.isReverseActive
end

--- Should we be driving in reverse based on the current position on course
function PurePursuitController:isReversing()
	return self.course:isReverseAt(self:getCurrentWaypointIx()) or self.course:switchingToForwardAt(self:getCurrentWaypointIx())
end

function PurePursuitController:getDirection(lz)
	local ctx, cty, ctz = self:getClosestWaypointData()
	if not ctx then return lz end
	local dx, _, dz  = worldToLocal(self.controlledNode, ctx, cty, ctz)
	local distance = math.sqrt(dx * dx + dz * dz)
	local r = distance * distance / 2 / dx
	local steeringAngle = math.atan(self.vehicle.cp.distances.frontWheelToRearWheel / r)
	return math.cos(steeringAngle)
end

-- goal point local position in the vehicle's coordinate system
function PurePursuitController:getGoalPointLocalPosition()
	return localToLocal(self.goalWpNode.node, self.controlledNode, 0, 0, 0)
end


function PurePursuitController:getGoalPointPosition()
	return getWorldTranslation(self.goalWpNode.node)
end

function PurePursuitController:getCurrentWaypointPosition()
	local cx, cy, cz
	if self:isActive() then
		cx, cy, cz = self:getGoalPointPosition()
	else
		cy = 0
		cx, cz = self.vehicle.Waypoints[self.vehicle.cp.waypointIndex].cx, self.vehicle.Waypoints[self.vehicle.cp.waypointIndex].cz
	end
	return cx, cy, cz
end

function PurePursuitController:switchToNextWaypoint()
	if self:isActive() then
		courseplay:setWaypointIndex(self.vehicle, self:getCurrentOriginalWaypointIx());
	else
		courseplay:setWaypointIndex(self.vehicle, self.vehicle.cp.waypointIndex + 1);
	end
end

-- This is to be used in drive.lua in place of the dist < distToChange check, that is, when we
-- reached the next waypoint.
function PurePursuitController:shouldChangeWaypoint(distToChange)
	local shouldChangeWaypoint
	if self:isActive() then
		-- true when the current waypoint calculated by PPC does not match the CP waypoint anymore, or
		-- true when at the last waypoint (to trigger the last waypoint processing in drive.lua (which was triggered by
		-- the distToChange condition before PPC)
		-- TODO: remove that reachedLastWaypoint() when not needed anymore for backward compatibility
		shouldChangeWaypoint = self:getCurrentWaypointIx() ~= self.vehicle.cp.waypointIndex or self:reachedLastWaypoint()
	else
		shouldChangeWaypoint = self.vehicle.cp.distanceToTarget <= distToChange
	end
	return shouldChangeWaypoint
end

function PurePursuitController:reachedLastWaypoint()
	local atLastWaypoint
	if self:isActive() then
		atLastWaypoint = self.relevantWpNode.ix >= self.course:getNumberOfWaypoints()
	else
		atLastWaypoint = self.vehicle.cp.waypointIndex >= self.vehicle.cp.numWaypoints			
	end
	return atLastWaypoint
end

function PurePursuitController:haveJustPassedWaypoint(ix)
	return self.lastPassedWaypointIx and self.lastPassedWaypointIx == ix or false
end

function PurePursuitController:haveAlreadyPassedWaypoint(ix)
	return self.lastPassedWaypointIx and self.lastPassedWaypointIx <= ix or false
end