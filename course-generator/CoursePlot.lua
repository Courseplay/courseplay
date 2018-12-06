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

CoursePlot = {}
CoursePlot.__index = CoursePlot

-- Position and size of the course plot as normalized screen coordinates
-- x = 0, y = 0 is the bottom left corner of the screen, terrainSize is in meters
function CoursePlot:new(x, y, width, height, terrainSize)
	newCoursePlot = {}
	setmetatable( newCoursePlot, self )
	self.courseOverlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds')
	self.startSignOverlayId = createImageOverlay(Utils.getFilename('img/signs/start.dds', courseplay.path))
	self.stopSignOverlayId = createImageOverlay(Utils.getFilename('img/signs/stop.dds', courseplay.path))
	self.x, self.y = x, y
	self.width, self.height = width, height
	self.startPosition = {}
	self.stopPosition = {}
	self.isVisible = false
	self.terrainSize = terrainSize
	self:setScale( self.width / self.terrainSize, self.height / self.terrainSize )
	self.worldOffsetX, self.worldOffsetZ = self.terrainSize / 2, self.terrainSize / 2
	return newCoursePlot
end

function CoursePlot:delete()
	if self.courseOverlayId ~= 0 then
		delete(self.courseOverlayId);
	end;
	if self.startSignOverlayId ~= 0 then
		delete(self.startSignOverlayId);
	end;
end

-- normalized screen coordinates
function CoursePlot:setPosition(x, y)
	self.x, self.y = x, y
end

-- normalized screen coordinates
function CoursePlot:setSize(width, height)
	self.width, self.height = width, height
	self:setScale( self.width / self.terrainSize, self.height / self.terrainSize )
end

function CoursePlot:setVisible( isVisible )
	self.isVisible = isVisible
end

function CoursePlot:setWaypoints( waypoints )
	self.waypoints = waypoints
end

-- start position used when generating the course, either first course wp
-- or the position selected by the user on the map. We'll show a sign there.
function CoursePlot:setStartPosition( x, z )
	self.startPosition.x, self.startPosition.z = x, z
end

-- end position of the course
function CoursePlot:setStopPosition( x, z )
	self.stopPosition.x, self.stopPosition.z = x, z
end

--- Set scale of the course plot. 1 m * scale = 1 m on plot in normalized screen coordinates
function CoursePlot:setScale(scaleX, scaleZ)
	self.scaleX = scaleX
	self.scaleZ = scaleZ
end

function CoursePlot:setWorldOffset( offsetX, offsetZ )
	self.worldOffsetX = offsetX
	self.worldOffsetZ = offsetZ
end

function CoursePlot:worldToScreen( worldX, worldZ )
	local x = self.x + self.scaleX * ( worldX + self.worldOffsetX )
	local y = self.y + self.height - self.scaleZ * ( worldZ + self.worldOffsetZ )
	-- don't render outside of our area
	-- TODO: is there an easier way to clip a rendering? Is there a built-in overlay function for that?
	if x < self.x or x > self.x + self.width then x = nil end
	if y < self.y or y > self.y + self.height then y = nil end
	return x, y
end

function CoursePlot:screenToWorld( x, y )
	local worldX = ((x - self.x) / self.scaleX) - self.worldOffsetX
	local worldZ = ((y - self.y - self.height) / -self.scaleZ) - self.worldOffsetZ
	return worldX, worldZ
end

-- World X/Z coordinates of the map center, width in world size
function CoursePlot:setView( worldX, worldZ, worldWidth )
	self:setScale( self.width / worldWidth, self.height / worldWidth )
	self:setWorldOffset( worldWidth / 2 - worldX, worldWidth / 2 - worldZ )
end

-- Draw the course in the screen area defined in new(), the bottom left corner
-- is at worldX/worldZ coordinates, the size shown is worldWidth wide (and high)
function CoursePlot:draw()

	if not self.isVisible then return end

	local lineThickness = 2 / g_screenHeight -- 2 pixels

	if self.waypoints and #self.waypoints > 1 then
		-- I know this is in helpers.lua already but that code has too many dependencies
		-- on global variables and vehicle.cp.
		local reducedWaypoints = courseplay.utils:removeCollinearPoints(self.waypoints, 2 )
		local np, startX, startY, endX, endY, dx, dz, dx2D, dy2D, width, rotation, r, g, b

		-- render a line between subsequent waypoints
		for i = 1, #reducedWaypoints - 1 do
			wp = reducedWaypoints[ i ]
			np = reducedWaypoints[ i + 1 ]

			startX, startY = self:worldToScreen( wp.cx, wp.cz )
			endX, endY	   = self:worldToScreen( np.cx, np.cz )
			-- render only if it is on the plot area
			if startX and startY and endX and endY then
				dx2D = endX - startX;
				dy2D = ( endY - startY ) / g_screenAspectRatio;
				width = MathUtil.vector2Length(dx2D, dy2D);

				dx = np.cx - wp.cx;
				dz = np.cz - wp.cz;
				rotation = MathUtil.getYRotationFromDirection(dx, dz) - math.pi * 0.5;

				r, g, b = courseplay.utils:getColorFromPct( 100 * wp.origIndex / #self.waypoints, CpManager.course2dColorTable, CpManager.course2dColorPctStep )

				setOverlayColor( self.courseOverlayId, r, g, b, 1 )
				setOverlayRotation( self.courseOverlayId, rotation, 0, 0 )
				renderOverlay( self.courseOverlayId, startX, startY, width, lineThickness )
			end
		end;
		setOverlayRotation( self.courseOverlayId, 0, 0, 0 ) -- reset overlay rotation
	end

	local signSizeMeters = 20
	local signWidth, signHeight = signSizeMeters * self.scaleX, signSizeMeters * self.scaleZ

	-- render a sign marking the end of the course
	if self.stopPosition.x and self.stopPosition.z then
		local x, y = self:worldToScreen( self.stopPosition.x, self.stopPosition.z )
		if x and y then
			setOverlayColor( self.stopSignOverlayId, 1, 1, 1, 0.8 )
			renderOverlay( self.stopSignOverlayId,
				x - signWidth / 2, -- offset so the middle of the sign is on the stoping location
				y - signHeight / 2,
				signWidth, signHeight)
		end
	end

	-- render a sign marking the current position used as a starting location for the course
	if self.startPosition.x and self.startPosition.z then
		local x, y = self:worldToScreen( self.startPosition.x, self.startPosition.z )
		if x and y then
			setOverlayColor( self.startSignOverlayId, 1, 1, 1, 0.8 )
			renderOverlay( self.startSignOverlayId,
				x - signWidth / 2, -- offset so the middle of the sign is on the starting location
				y - signHeight / 2,
				signWidth, signHeight)
		end
	end
end