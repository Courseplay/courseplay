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

-- Position and size of the coruse plot as normalized screen coordinates
-- x = 0, y = 0 is the bottom left corner of the screen
function CoursePlot:new( x, y, width, height )
	newCoursePlot = {}
	setmetatable( newCoursePlot, self )
	self.overlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds')
	self.x, self.y = x, y
	self.width, self.height = width, height
	return newCoursePlot
end

function CoursePlot:delete()
	if self.overlayId ~= 0 then
		delete(self.overlayId);
	end;
end

function CoursePlot:setWaypoints( waypoints )
	self.waypoints = waypoints
end

--- Set scale of the course plot. 1 m * scale = 1 m on plot in normalized screen coordinates
function CoursePlot:setScale( scaleX, scaleZ )
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
	return x, y
end

-- World X/Z coordinates of the map center, width in world size
function CoursePlot:setView( worldX, worldZ, worldWidth )
	self:setScale( self.width / worldWidth, self.height / worldWidth )
	self:setWorldOffset( worldWidth / 2 - worldX, worldWidth / 2 - worldZ )
end

-- Draw the course in the screen area defined in new(), the bottom left corner
-- is at worldX/worldZ coordinates, the size shown is worldWidth wide (and high)
function CoursePlot:draw()
	-- I know this is in helpers.lua already but that code has too many dependencies
	-- on global variables and vehicle.cp.

	if not self.waypoints or #self.waypoints < 1 then return end

	local lineThickness = 2 / g_screenHeight -- 2 pixels
	local reducedWaypoints = courseplay.utils:removeCollinearPoints(self.waypoints, 2 )

	local np, startX, startY, endX, endY, dx, dz, dx2D, dy2D, width, rotation, r, g, b

	-- render a line between subsequent waypoints
	for i, wp in ipairs( reducedWaypoints ) do
		np = i < #reducedWaypoints and reducedWaypoints[i + 1] or reducedWaypoints[1]

		startX, startY = self:worldToScreen( wp.cx, wp.cz )
		endX, endY	   = self:worldToScreen( np.cx, np.cz )

		dx2D = endX - startX;
		dy2D = ( endY - startY ) / g_screenAspectRatio;
		width = Utils.vector2Length(dx2D, dy2D);

		dx = np.cx - wp.cx;
		dz = np.cz - wp.cz;
		rotation = Utils.getYRotationFromDirection(dx, dz) - math.pi * 0.5;

		r, g, b = courseplay.utils:getColorFromPct( 100 * wp.origIndex / #self.waypoints, CpManager.course2dColorTable, CpManager.course2dColorPctStep )

		setOverlayColor( self.overlayId, r, g, b, 1 )
		setOverlayRotation( self.overlayId, rotation, 0, 0 )
		renderOverlay( self.overlayId, startX, startY, width, lineThickness )
	end;
	setOverlayRotation( self.overlayId, 0, 0, 0 ) -- reset overlay rotation
	--renderOverlay( self.overlayId, self.x, self.y, self.width, lineThickness )
	--renderOverlay( self.overlayId, self.x, self.y + self.width * g_screenWidth / g_screenHeight, self.width, lineThickness )
end