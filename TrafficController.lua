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

--- A reservation we put in the reservation table.
Reservation = CpObject()

function Reservation:init(vehicleId, timeStamp)
	self.vehicleId = vehicleId
	self.timeStamp = timeStamp
end


--- TrafficController provides a cooperative collision avoidance facility for all Courseplay driven vehicles.
--
-- The TrafficController is a singleton object and should be initialized once after CP is loaded and
-- then call update() to update its clock (the clock is needed to remove stale reservations)
--
-- Vehicles should call reserve() when they reach a waypoint to reserve the next section of their path and to make sure
-- their path is not in conflict with another vehicle's future path.
--
-- Reservations are per tile in a grid representing the map. When a vehicle asks for a reservation, TrafficController
-- reserves the tiles under the future path of the vehicle (based on the course it is driving).
--
-- TrafficController looks into the future for lookaheadTimeSeconds (30 by default) only. So when a vehicle calls
-- reserve() with a waypoint index, only the part of the course lying within lookaheadTimeSeconds from that waypoint
-- is actually reserved.
--
-- The calculation is based on the speed stored in the course, or if that does not exist, the speed passed in to
-- reserve() or if none, it defaults to 10 km/h.
--
-- When reserve() is called, TrafficController also frees all tiles reserved for the waypoints behind the passed
-- in waypoint index.
--
-- When the course of the vehicle is updated or multiple waypoints are skipped, the vehicle should call cancel()
-- to cancel all existing reservations and then reserve() again from the current waypoint index.
--
-- TrafficController also periodically cleans up all stale reservations based on the timestamp recorded at
-- the time of the reservation and on the internal clock value. This is to make sure that forgotten reservations
-- don't block other vehicles forever.
--

TrafficController = CpObject()

function TrafficController:init()
	self.prevTimeString = getDate(TrafficController.dateFormatString)
	self.clock = 0
	-- this is our window of traffic awareness, we only plan for the next 30 seconds
	self.lookaheadTimeSeconds = 30
	-- the reservation table grid size in meters. This should be less than the maximum waypoint distance
	self.gridSpacing = 2.5
	-- every so often we clean up stale reservations
	self.cleanUpIntervalSeconds = 30
	self.staleReservationTimeoutSeconds = 3 * self.lookaheadTimeSeconds
	-- this holds all the reservations
	self.reservations = {}
	self.dateFormatString = '%H%M%S'
end

--- Update our clock and take care of stale entries
-- This should be called once in an update cycle (globally, not vehicle specific)
function TrafficController:update(dt)
	-- The Giants engine does not seem to provide a clock, so implement our own.
	local currentTimeString = getDate(TrafficController.dateFormatString)
	if self.prevTimeString ~= currentTimeString then
		self.prevTimeString = currentTimeString
		self.clock = self.clock + 1
	end
	if self.clock % self.cleanUpIntervalSeconds == 0 then
		self:cleanUp()
	end
end

--- Make a reservation for the next lookaheadTimeSeconds interval
-- @param vehicleId unique ID of the reserving vehicle
-- @param course vehicle course
-- @param fromIx index of the course waypoint where we start the reservation
-- @param speed expected speed of the vehicle in km/h. If not given will use the speed in the course.
-- @return true if successfully reserved _all_ tiles. When returning false it may
-- reserve some of the tiles though.
function TrafficController:reserve(vehicleId, course, fromIx, speed)
	self:freePreviousTiles(vehicleId, course, fromIx, speed)
	local ok = self:reserveNextTiles(vehicleId, course, fromIx, speed)
	return ok
end

--- Free waypoints already passed
-- use the link to the previous tile to walk back until the oldest one is reached.
function TrafficController:freePreviousTiles(vehicleId, course, fromIx, speed)
	local tiles = self:getGridPointsUnderCourse(course, self:backwardIterator(fromIx), speed)
	for i = 1, #tiles do
		self:freeGridPoint(tiles[i], vehicleId)
	end
end

function TrafficController:reserveNextTiles(vehicleId, course, fromIx, speed)
	local ok = true
	local gridPoints = self:getGridPointsUnderCourse(course, self:forwardIterator(fromIx, #course.waypoints - 1), speed)
	for i = 1, #gridPoints do
		ok = ok and self:reserveGridPoint(gridPoints[i], Reservation(vehicleId, self.clock))
	end
	return ok
end

--- Get the list of tiles the segment of the course defined by the iterator is passing through, using the
-- speed in the course or the one supplied here. Will find the tiles reached in lookaheadTimeSeconds only
-- (based on the speed and the waypoint distance)
function TrafficController:getGridPointsUnderCourse(course, iterator, speed)
	local tiles = {}
	local travelTimeSeconds = 0
	for i in iterator() do
		local v = speed or course.waypoints[i].speed or 10
		local s = course:getDistanceToNextWaypoint(i)
		local x, z = self:getGridCoordinates(course.waypoints[i])
		table.insert(tiles, Point(x, z))
		-- if waypoints are further apart than our grid spacing then we need to add points
		-- in between to not miss a tile
		if s > self.gridSpacing then
			local ips = self:getIntermediatePoints(course.waypoints[i], course.waypoints[i + 1])
			for _, wp in ipairs(ips) do
				x, z = self:getGridCoordinates(wp)
				table.insert(tiles, Point(x, z))
			end
		end
		travelTimeSeconds = travelTimeSeconds + s / (v / 3.6)
		if travelTimeSeconds > self.lookaheadTimeSeconds then
			return tiles
		end
	end
	-- if we ended up here then we went all the way to the waypoint before the last, so
	-- add the last one here
	local x, z = self:getGridCoordinates(course.waypoints[#course.waypoints])
	table.insert(tiles, Point(x, z))
	return tiles
end

--- If waypoint a and b a farther apart than the grid spacing then we need to
-- add points in between so wo don't miss a tile
function TrafficController:getIntermediatePoints(a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local d = math.sqrt(dx * dx + dz * dz)
	local nx, nz = dx / d, dz / d
	local nPoints = math.floor((d - 0.001) / self.gridSpacing) -- 0.001 makes sure we have only one wp even if a and b are exactly on the grid
	local x, z = a.x, a.z
	local intermediatePoints = {}
	for i = 1, nPoints do
		x, z = x + self.gridSpacing * nx, z + self.gridSpacing * nz
		table.insert(intermediatePoints, {x = x, z = z})
	end
	return intermediatePoints
end

--- Add tiles around x, z to the list of tiles.
function TrafficController:getTilesAroundPoint(point)
	return {
		point,
		Point(point.x - 1, point.z),
		Point(point.x + 1, point.z),
		Point(point.x, point.z - 1),
		Point(point.x, point.z + 1)
	}
end

--- Reserve a grid point. This will reserve the tile the point is on and the adjacent tiles (above, below, left and right,
-- but not diagonally) as well to make sure the vehicle has enough clearance from all sides.
function TrafficController:reserveGridPoint(point, reservation)
	-- reserve tiles around point
	for _, tile in ipairs(self:getTilesAroundPoint(point)) do
		if not self:reserveTile(tile, reservation) then
			return false
		end
	end
	return true
end

function TrafficController:freeGridPoint(point, vehicleId)
	-- free tiles around point
	for _, tile in ipairs(self:getTilesAroundPoint(point)) do
		self:freeTile(tile, vehicleId)
	end
end

function TrafficController:freeTile(point, vehicleId)
	if not self.reservations[point.x] then
		return
	end
	if not self.reservations[point.x][point.z] then
		return
	end
	if self.reservations[point.x][point.z].vehicleId == vehicleId then
		-- no more reservations left, remove entry
		self.reservations[point.x][point.z] = nil
	end
end

function TrafficController:reserveTile(point, reservation)
	if not self.reservations[point.x] then
		self.reservations[point.x] = {}
	end
	if self.reservations[point.x][point.z] then
		if self.reservations[point.x][point.z].vehicleId == reservation.vehicleId then
			-- already reserved for this vehicle
			return true
		else
			-- reserved for another vehicle
			return false
		end
	end
	self.reservations[point.x][point.z] = reservation
	return true
end

function TrafficController:getGridCoordinates(wp)
	local gridX = math.floor(wp.x / self.gridSpacing)
	local gridZ = math.floor(wp.z / self.gridSpacing)
	return gridX, gridZ
end

--- Cancel all reservations for a vehicle
function TrafficController:cancel(vehicleId)
	for row in pairs(self.reservations) do
		for col in pairs(self.reservations[row]) do
			local reservation = self.reservations[row][col]
			if reservation and reservation.vehicleId == vehicleId then
				self.reservations[row][col] = nil
			end
		end
	end
end

--- Clean up all stale reservations
function TrafficController:cleanUp(vehicleId)
	for row in pairs(self.reservations) do
		for col in pairs(self.reservations[row]) do
			local reservation = self.reservations[row][col]
			if reservation and reservation.timeStamp <= (self.clock - self.staleReservationTimeoutSeconds) then
				self.reservations[row][col] = nil
			end
		end
	end
end

function TrafficController:forwardIterator(from, to)
	return  function()
		local i, n = from - 1, to
		return function()
			i = i + 1
			if i <= n then return i end
		end
	end
end

function TrafficController:backwardIterator(from)
	return  function()
		local i = from
		return function()
			i = i - 1
			if i >= 1 then return i end
		end
	end
end

--- Cancel all reservations for a vehicle
function TrafficController:__tostring()
	local result = ''
	for row = 0, 9 do
		for col = 0, 9 do
			local reservation = self.reservations[row] and self.reservations[row][col]
			if reservation then
				result = result .. reservation.vehicleId
			else
				result = result .. '.'
			end
		end
		result = result .. '\n'
	end
	return result
end
