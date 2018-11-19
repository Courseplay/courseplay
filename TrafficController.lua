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

function Reservation:init(vehicleId, timeStamp, previousTile)
	self.vehicleId = vehicleId
	self.timeStamp = timeStamp
	-- link to the previous tile for easy clean up after the vehicle
	self.previousTile = previousTile
end


TrafficController = CpObject()

function TrafficController:init()
	self.prevTimeString = getDate(TrafficController.dateFormatString)
	self.clock = 0
	-- this is our window of traffic awareness, we only plan for the next 30 seconds
	self.lookaheadTimeSeconds = 30
	-- the reservation table grid size in meters. This should be less than the maximum waypoint distance
	self.gridSpacing = 6
	-- look back distance: when cleaning up waypoints travelled, go back so many steps to check if there's
	-- something left to clean up. Theoretically, 1 should work fine here.
	self.lookBackIx = 5
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
end

--- Make a reservation for the next lookaheadTimeSeconds interval
-- @param vehicleId unique ID of the reserving vehicle
-- @param course vehicle course
-- @param fromIx index of the course waypoint where we start the reservation
-- @param speed expected speed of the vehicle in km/h. If not given will use the speed in the course.
-- @return true if successfully reserved (no other vehicle reserved
function TrafficController:reserve(vehicleId, course, fromIx, speed)
	self:freePreviousTiles(vehicleId, course.waypoints[fromIx])
	local ok = self:reserveNextTiles(vehicleId, course, fromIx, speed)
	return ok
end

--- Free waypoints already passed
-- use the link to the previous tile to walk back until the oldest one is reached.
function TrafficController:freePreviousTiles(vehicleId, point)
	local function getPreviousTile(x, z)
		return self.reservations[x] and self.reservations[x][z] and self.reservations[x][z].previousTile
	end
	local x, z = self:getGridCoordinates(point)
	local tile = getPreviousTile(x, z)
	while tile do
		local previousTile = getPreviousTile(tile.x, tile.z)
		self:freeTile(tile, vehicleId)
		tile = previousTile
	end
end

function TrafficController:reserveNextTiles(vehicleId, course, fromIx, speed)
	local ok = true
	local tiles = self:getTiles(course, fromIx, speed)
	for i = 1, #tiles do
		ok = ok and self:reserveTile(tiles[i], Reservation(vehicleId, self.clock, tiles[i - 1]))
	end
	return ok
end

--- Get the list of tiles the course is passing through starting at startIx index, using the
-- speed in the course or the one supplied here. Will find the tiles reached in lookaheadTimeSeconds only
-- (based on the speed and the waypoint distance)
function TrafficController:getTiles(course, startIx, speed)
	local tiles = {}
	local travelTimeSeconds = 0
	for i = startIx, #course.waypoints - 1 do
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