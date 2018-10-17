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

We use the terminology of that paper here, like 'relevant path segment', 'goal point', etc.

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
5. use the convenience functions getCurrentWaypointPosition(), shouldChangeWaypoint(), atLastWaypoint() and switchToNextWaypoint()
   in your code instead of directly checking and manipulating vehicle.Waypoints. These provide the legacy behavior when
   the PPC is not active (for example due to reverse driving) or when disabled
6. you can use enable() and disable() to enable/disable the PPC. When disabled and you are using the above functions,
   it'll behave as the legacy code.

]]

PurePursuitController = {}
PurePursuitController.__index = PurePursuitController

-- constructor
function PurePursuitController:new(vehicle)
	local newPpc = {}
	setmetatable( newPpc, self )
	-- base lookahead distance
	newPpc.baseLookAheadDistance = 5
	-- adapted look ahead distance 
	newPpc.lookAheadDistance = newPpc.baseLookAheadDistance
	-- when transitioning from forward to reverse, this close we have to be to the waypoint where we
	-- change direction before we switch to the next waypoint
	newPpc.distToSwitchWhenChangingToReverse = 1
	newPpc.vehicle = vehicle
	newPpc.name = nameNum(vehicle)
	-- node on the current waypoint
	newPpc.currentWpNode = WaypointNode:new( newPpc.name .. '-currentWpNode', true)
	-- waypoint at the start of the relevant segment
	newPpc.relevantWpNode = WaypointNode:new( newPpc.name .. '-relevantWpNode', true)
	-- waypoint at the end of the relevant segment
	newPpc.nextWpNode = WaypointNode:new( newPpc.name .. '-nextWpNode', true)
	-- the current goal node
	newPpc.goalWpNode = WaypointNode:new( newPpc.name .. '-goalWpNode', false)
	-- vehicle position projected on the path, not used for anything other than debug display
	newPpc.projectedPosNode = courseplay.createNode( newPpc.name .. '-projectedPosNode', 0, 0, 0)
	newPpc.isReverseActive = false
	-- enable PPC by default for developers only
	newPpc.enabled = CpManager.isDeveloper
	newPpc.goalPointDiagText = ''		
	return newPpc
end

-- destructor
function PurePursuitController:delete()
	self.currentWpNode:destroy()
	self.relevantWpNode:destroy()
	self.nextWpNode:destroy()
	courseplay.destroyNode(self.projectedPosNode)
	self.goalWpNode:destroy();
end

-- initialize controller before driving
function PurePursuitController:initialize()
	-- we rely on the code in start_stop.lua to select the first waypoint
	self.course = Course:new(self.vehicle)
	--local segment, ix = self.course:initializeSegments(self.vehicle.cp.waypointIndex)
	--self.currentSegment = segment
	-- relevantWpNode always points to the point where the relevant path segment starts
	self.relevantWpNode:setToWaypoint(self.course, self.vehicle.cp.waypointIndex)
	self.nextWpNode:setToWaypoint(self.course, self.vehicle.cp.waypointIndex + 1)
	self.wpBeforeGoalPointIx = self.nextWpNode.ix
	self.currentWpNode:setToWaypoint(self.course, self.vehicle.cp.waypointIndex)
	courseplay.debugVehicle(12, self.vehicle, 'PPC: initialized to waypoint %d', self.vehicle.cp.waypointIndex)
	self.isReverseActive = false
	self.isGoalPointValid = false
end

function PurePursuitController:getCurrentWaypointIx()
	return self.currentWpNode.ix
end


function PurePursuitController:update()
	self:findRelevantSegment()
	self:findGoalPoint()
end

function PurePursuitController:havePassedWaypoint(wpNode)
	local vx, vy, vz = getWorldTranslation(self.vehicle.cp.DirectionNode or self.vehicle.rootNode)
	local dx, _, dz = worldToLocal(wpNode.node, vx, vy, vz);
	local dFromNext = Utils.vector2Length(dx, dz)
	--courseplay.debugVehicle(12, self.vehicle, 'PPC: checking %d, dz: %.1f', wpNode.ix, dz)
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
		-- (as we may already be in front of it), so try get within the turn diameter.
		if dz >= 0 and dFromNext < self.vehicle.cp.vehicleTurnRadius * 2 then
			result = true
		end
	end
	if result and not self:atLastWaypoint() then
		-- disable debugging once we reached the last waypoint. Otherwise we'd keep logging
		-- until the user presses 'Stop driver'.
		courseplay.debugVehicle(12, self.vehicle, 'PPC: waypoint %d passed, dz: %.1f %s %s', wpNode.ix, dz,
			self.course.waypoints[wpNode.ix].rev and 'reversed' or '',
			self.course:switchingDirectionAt(wpNode.ix) and 'switching direction' or '')
	end	
	return result
end

function PurePursuitController:havePassedAnyWaypointBetween(fromIx, toIx)
	local node = WaypointNode:new( self.name .. '-node', false)
	local result, passedWaypointIx = false, 0
	--courseplay.debugVehicle(12, self.vehicle, 'PPC: checking between %d and %d', fromIx, toIx)
	for ix = fromIx, toIx do
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
	local vx, vy, vz = getWorldTranslation(self.vehicle.cp.DirectionNode or self.vehicle.rootNode)
	local crossTrackError, _, dzFromRelevant = worldToLocal(self.relevantWpNode.node, vx, vy, vz);
	-- adapt our lookahead distance based on the error
	self.lookAheadDistance = math.min(self.baseLookAheadDistance + math.abs(crossTrackError), self.baseLookAheadDistance * 2)
	-- projected vehicle position/rotation	
	local px, py, pz = localToWorld(self.relevantWpNode.node, 0, 0, dzFromRelevant)
	local _, yRot, _ = getRotation(self.nextWpNode.node)
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
		if not self:atLastWaypoint() then
			-- disable debugging once we reached the last waypoint. Otherwise we'd keep logging
			-- until the user presses 'Stop driver'.
			courseplay.debugVehicle(12, self.vehicle, 'PPC: relevant waypoint: %d, crosstrack error: %.1f', self.relevantWpNode.ix, crossTrackError)
		end
	end
	setTranslation(self.projectedPosNode, px, py, pz)
	setRotation(self.projectedPosNode, 0, yRot, 0)
	if courseplay.debugChannels[12] then
		drawDebugLine(px, py + 3, pz, 1, 1, 0, px, py + 1, pz, 1, 1, 0);
		DebugUtil.drawDebugNode(self.relevantWpNode.node, string.format('ix = %d\nrelevant\nnode', self.relevantWpNode.ix, dz))
		DebugUtil.drawDebugNode(self.projectedPosNode, 'projected\nvehicle\nposition')
	end
end

-- Now, from the relevant section forward we search for the goal point, which is the one
-- lying lookAheadDistance in front of us on the path
function PurePursuitController:findGoalPoint()
	local d1, d2

	local vx, vy, vz = getWorldTranslation(self.vehicle.cp.DirectionNode or self.vehicle.rootNode);
	--local vx, vy, vz = getWorldTranslation(self.projectedPosNode);

	-- create helper nodes at the relevant and the next wp. We'll move these up on the path until we reach the segment
	-- in lookAheadDistance
	local node1 = WaypointNode:new( self.name .. '-node1', false)
	local node2 = WaypointNode:new( self.name .. '-node2', false)

	local isGoalPointValid = false
	self.goalPointDiagText = ''
	-- starting at the relevant segment walk up the path to find the segment on
	-- which the goal point lies. This is the segment intersected by the circle with lookAheadDistance radius
	-- around the vehicle.
	local ix = self.relevantWpNode.ix
	--courseplay.debugVehicle(12, self.vehicle, 'relevant Ix: %d', self.relevantWpNode.ix) -- -----------------------
	while ix <= #self.vehicle.Waypoints do
		node1:setToWaypoint(self.course, ix)
		node2:setToWaypointOrBeyond(self.course, ix + 1, self.lookAheadDistance)
		local x1, y1, z1 = getWorldTranslation(node1.node)
		local x2, y2, z2 = getWorldTranslation(node2.node)
		-- distance between the vehicle position and the end of the segment
		d1 = courseplay:distance(vx, vz, x2, z2)
		--courseplay.debugVehicle(12, self.vehicle, 'ix: %d, d1: %.4f, la: %.1f', ix, d1, self.lookAheadDistance) -- -----------------------
		self.goalPointDiagText = string.format('ix: %d dToNext: %.4f', ix, d1) -- -----------------------
		if d1 > self.lookAheadDistance then
			-- far end of this segment is farther than lookAheadDistance so the goal point must be on
			-- this segment
			d2 = courseplay:distance(x1, z1, vx, vz)
			self.goalPointDiagText = string.format('ix: %d dFromPrev: %.4f dToNext: %.4f', ix, d2, d1) -- -----------------------
			if d2 > self.lookAheadDistance then
				-- too far from either end of the relevant segment
				if not self.isGoalPointValid then
					-- If we weren't on track yet (after initialization, on our way to the first/initialized waypoint)
					-- set the goal to the relevant WP
					self.goalWpNode:setToWaypoint(self.course, self.relevantWpNode.ix)
					-- and also the current waypoint is now at the relevant WP
					self.currentWpNode:setToWaypointOrBeyond(self.course, self.relevantWpNode.ix, self.lookAheadDistance)
					if courseplay.debugChannels[12] then
						DebugUtil.drawDebugNode(self.goalWpNode.node, string.format('\n\n\n\ntoo far\ninitializing'))
					end
					self.goalPointDiagText = self.goalPointDiagText .. ' too far, initializing'
					--courseplay.debugVehicle(12, self.vehicle, 'too far initializing ix: %d dFromPrev: %.4f dToNext: %.4f', ix, d2, d1) -- -----------------------
					break
				else
					-- we already were tracking the path but now both points are too far.
					-- this can be the case when ix and ix + 1 are more than lookAheadDistance away and
					-- we are on the path between them
					-- we can go ahead and find the goal point as usual, as we start approximating
					-- from the front waypoint and will find the goal point in front of us.
					-- isGoalPointValid = true
					if courseplay.debugChannels[12] then
						DebugUtil.drawDebugNode(self.goalWpNode.node, string.format('\n\n\n\ntoo far'))
					end
					self.goalPointDiagText = self.goalPointDiagText .. ' too far'
					--courseplay.debugVehicle(12, self.vehicle, 'too far ix: %d dFromPrev: %.4f dToNext: %.4f', ix, d2, d1) -- -----------------------
				end
			end
			-- this is the current waypoint for the rest of Courseplay code, the waypoint we are driving to
			-- but never, ever go back. Instead just leave this loop and keep driving to the current goal node
			if ix + 1 < self.currentWpNode.ix then
				self.goalPointDiagText = self.goalPointDiagText .. ' no step back'
				--courseplay.debugVehicle(12, self.vehicle, "PPC: Won't step current waypoint back from %d to %d.", self.currentWpNode.ix, ix + 1)
				isGoalPointValid = true
				break 
			end
			self.currentWpNode:setToWaypointOrBeyond(self.course, ix + 1, self.lookAheadDistance)

			-- our goal point is now between ix and ix + 1, let's find it
			-- distance between current and next waypoint
			local dToNext = courseplay:distance(x1, z1, x2, z2)
			local minDz, maxDz, currentDz, currentRange = 0, dToNext, dToNext / 2, dToNext

			-- successive approximation of the intersection between this path segment and the
			-- lookAheadDistance radius circle around the vehicle. That intersection point will be our goal point
			-- starting from the far end makes sure we find the correct point even in the case when the
			-- circle around the vehicle intersects with this section twice.
			
			local bits = 12  -- successive approximator (ADC) bits
			local step = 0   -- current step
			local gx, gy, gz
			while step < bits do
				-- point in currentDz distance from node1 on the section between node1 and node2
				gx, gy, gz = localToWorld(node1.node, 0, 0, currentDz)
				d1 = courseplay:distance(vx, vz, gx, gz)
				
				if d1 < self.lookAheadDistance then
					minDz = currentDz
				else
					maxDz = currentDz
				end
				step = step + 1
				currentRange = currentRange / 2
				currentDz = minDz + currentRange
			end
			--courseplay.debugVehicle(12, self.vehicle,'*** range: %.4f d1: %.4f, dz: %.4f', currentRange, d1, currentDz) -- -----------------------------
			gy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, gx, 0, gz)
			setTranslation(self.goalWpNode.node, gx, gy, gz)
			isGoalPointValid = true
			self.wpBeforeGoalPointIx = ix
			break
		end
		ix = ix + 1
	end
	
	node1:destroy()
	node2:destroy()
	
	self:setGoalPointValid(isGoalPointValid)
	
	if courseplay.debugChannels[12] then
		if self.isGoalPointValid then
			local gx, gy, gz = localToWorld(self.goalWpNode.node, 0, 0, 0)
			drawDebugLine(gx, gy + 3, gz, 0, 1, 0, gx, gy + 1, gz, 0, 1, 0);
			DebugUtil.drawDebugNode(self.goalWpNode.node, string.format('ix = %d\nd = %.1f\ngoal\npoint', self.wpBeforeGoalPointIx, d1))
		end
		DebugUtil.drawDebugNode(self.currentWpNode.node, string.format('ix = %d\ncurrent\nwaypoint', self.currentWpNode.ix))
	end
end

function PurePursuitController:setGoalPointValid(isGoalPointValid)
	if self.isGoalPointValid ~= isGoalPointValid then
		if isGoalPointValid then
			courseplay.debugVehicle(12, self.vehicle, 'PPC: Goal point found.')
		else
			courseplay.debugVehicle(12, self.vehicle, 'PPC: Goal point lost: ' .. self.goalPointDiagText)
		end
		self.isGoalPointValid = isGoalPointValid
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

function PurePursuitController:isActive()
	-- Let the code in reverse.lua do its magic when reversing.
	-- That code seems to be robust against circling anyway
	-- we only control when the user enabled us and not reverse.lua is driving
	return self.enabled and not self.isReverseActive
end

function PurePursuitController:getDirection(lz)

	local ctx, cty, ctz = self:getClosestWaypointData()
	if not ctx then return lz end
	local dx, _, dz  = worldToLocal(self.vehicle.cp.DirectionNode, ctx, cty, ctz)
	local x, _, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 0, 0)
	local distance = math.sqrt(dx * dx + dz * dz)
	local r = distance * distance / 2 / dx
	local steeringAngle = math.atan(self.vehicle.cp.distances.frontWheelToRearWheel / r)
	return math.cos(steeringAngle)
end

function PurePursuitController:getCurrentWaypointPosition()
	local cx, cz
	if self:isActive() then
		if self.isGoalPointValid then
			cx, _, cz = getWorldTranslation(self.goalWpNode.node)
		else
			cx, _, cz = getWorldTranslation(self.currentWpNode.node)
		end
	else
		cx, cz = self.vehicle.Waypoints[self.vehicle.cp.waypointIndex].cx, self.vehicle.Waypoints[self.vehicle.cp.waypointIndex].cz
	end
	return cx, cz
end

function PurePursuitController:switchToNextWaypoint()
	if self:isActive() then
		courseplay:setWaypointIndex(self.vehicle, self:getCurrentWaypointIx());
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
		shouldChangeWaypoint = self:getCurrentWaypointIx() ~= self.vehicle.cp.waypointIndex or self:atLastWaypoint()
	else
		shouldChangeWaypoint = self.vehicle.cp.distanceToTarget <= distToChange
	end
	return shouldChangeWaypoint
end

function PurePursuitController:atLastWaypoint()
	local atLastWaypoint
	if self:isActive() then
		atLastWaypoint = self.relevantWpNode.ix >= self.vehicle.cp.numWaypoints
	else
		atLastWaypoint = self.vehicle.cp.waypointIndex >= self.vehicle.cp.numWaypoints			
	end
	return atLastWaypoint
end
