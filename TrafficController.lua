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
-- currently only includes the vehicleId and the index of the waypoint. This can later be extended with
-- an estimated time of arrival
Reservation = CpObject()

function Reservation:init(vehicleId, ix, timeStamp)
	self.vehicleId = vehicleId
	self.ix = ix
	self.timeStamp = timeStamp
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
	self:freePassedSection(vehicleId, course, fromIx)
	local ok = self:reserveNextSection(vehicleId, course, fromIx, speed)
	return ok
end

--- Free waypoints already passed
function TrafficController:freePassedSection(vehicleId, course, fromIx)
	local ok = true
	for i = math.min(fromIx - 1, 2), math.max(fromIx - self.lookBackIx, 1), -1 do
		local x, z = self:getGridCoordinates(course.waypoints[i])
		self:freeTile(x, z, vehicleId)
	end
end

function TrafficController:reserveNextSection(vehicleId, course, fromIx, speed)
	local ok = true
	local tiles = self:getTiles(course, fromIx, speed)
	for i = fromIx, #course.waypoints - 1 do
		local x, z = self:getGridCoordinates(course.waypoints[i])
		ok = ok and self:reserveTile(x, z, Reservation(vehicleId, i, self.clock))
	end
	return ok
end

function TrafficController:getTiles(course, fromIx, speed)
	local tiles = {}
	local travelTimeSeconds = 0
	for i = fromIx, #course.waypoints - 1 do
		local v = speed or course.waypoints[i].speed or 10
		local s = course:getDistanceToNextWaypoint(i)
		local x, z = self:getGridCoordinates(course.waypoints[i])
		table.insert(tiles, {x = x, z = z})
		-- if waypoints are futher apart than our grid spacing then we need to add points
		-- in between to not miss a tile
		if s > self.gridSpacing then
			local ips = self:getIntermediatePoints(course.waypoints[i], course.waypoints[i + 1])
			for _, wp in ipairs(ips) do
				x, z = self:getGridCoordinates(wp)
				table.insert(tiles, {x = x, z = z})
			end
		end
		travelTimeSeconds = travelTimeSeconds + s / (v * 3.6)
		if travelTimeSeconds > self.lookaheadTimeSeconds then
			break
		end
	end
	return tiles
end

--- If waypoint a and b a farther apart than the grid spacing then we need to
-- add points in between so wo don't miss a tile
function TrafficController:getIntermediatePoints(a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local d = math.sqrt(dx * dx + dz * dz)
	local nx, nz = dx / d, dz / d
	local nPoints = math.floor(d / self.gridSpacing)
	local x, z = a.x, a.z
	local intermediatePoints = {}
	for i = 1, nPoints do
		x, z = x + self.gridSpacing * nx, z + self.gridSpacing * nz
		table.insert(intermediatePoints, {x = x, z = z})
	end
	return intermediatePoints
end

function TrafficController:freeTile(x, z, vehicleId)
	if not self.reservations[x] then
		return
	end
	if not self.reservations[x][z] then
		return
	end
	if self.reservations[x][z][vehicleId] then
		self.reservations[x][z][vehicleId] = nil
	end
	if #self.reservations[x][z] < 1 then
		-- no more reservations left, remove entry
		self.reservations[x][z] = nil
		if #self.reservations[x] < 1 then
			-- and the entire row if it is now empty
			self.reservations[x] = nil
		end
	end
end

function TrafficController:reserveTile(x, z, reservation)
	if not self.reservations[x] then
		self.reservations[x] = {}
	end
	if not self.reservations[x][z] then
		self.reservations[x][z] = {}
	end
	self.reservation[x][z][reservation.vehicleId] = reservation
	-- return true if no one reserved this tile yet
	return #self.reservation[x][z] == 1
end

function TrafficController:getGridCoordinates(wp)
	local gridX = math.floor(wp.x / self.gridSpacing)
	local gridZ = math.floor(wp.z / self.gridSpacing)
	return gridX, gridZ
end
