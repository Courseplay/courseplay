--[[
@title:     Course Generation for Courseplay
@author:    Jakob Tischler
@version:   0.5
@date:      09 Feb 2013
@updated:   08 Mar 2013

@copyright: No reproduction, usage or copying without the explicit permission by the author allowed.

TODO: 
[DONE 1) North/South point positions]
[DONE 2) ridgeMarker is down but doesn't draw line]
[DONE 3) raise/lower implements at lane end doesn't work yet -- see notes in mode4]
4) pointInPoly too inaccurate with points too close at poly edge
[DONE 5) ridgeMarker deployed too early (already before last_recordnumber == firstInLane)]
[DONE 6) translate hud settings]
]]

function courseplay:generateCourse(self)
	print("----- ----- ----- -----");
	print(string.format("generateCourse() called for %s", tostring(self.current_course_name)));
	print("     *     *     *     ");

	-- Make sure everything's set and in order
	if self.Waypoints == nil or table.getn(self.Waypoints) < 5 
	or self.cp.hasStartingCorner == nil 
	or self.cp.hasStartingDirection == nil 
	or self.cp.startingCorner == 0 
	or self.cp.startingDirection == 0 then
		return;
	end;
	
	local poly = {};
	poly.points = self.Waypoints
	poly.numPoints = table.getn(poly.points);
	poly.xValues, poly.zValues = {}, {};
	
	for _,wp in pairs(poly.points) do
		table.insert(poly.xValues, wp.cx);
		table.insert(poly.zValues, wp.cz);
	end;
	
	courseplay:reset_course(self);
	
	---#################################################################
	-- (1) SET UP DIMENSIONS, CORNERS AND DIRECTIONS --
	--------------------------------------------------------------------
	local workWidth = self.toolWorkWidht;
	local corners = {
		[1] = "SW",
		[2] = "NW",
		[3] = "NE",
		[4] = "SE"
	};
	local directions = {
		[1] = "N",
		[2] = "E",
		[3] = "S",
		[4] = "W"
	};
	local ridgeMarker = {
		none = 0,
		left = 1,
		right = 2
	};
	local crn = corners[self.cp.startingCorner];
	local dir = directions[self.cp.startingDirection];
	
	courseplay:getAutoTurnradius(self, table.getn(self.attachedImplements) > 0);
	print(string.format("turn_radius=%f, autoTurnRadius=%f", self.turn_radius, self.autoTurnRadius));
				
	
	--get field dimensions
	local dimensions = courseplay:calcDimensions(poly.xValues, poly.zValues);
	print(string.format("minX = %s, maxX = %s", tostring(dimensions.minX), tostring(dimensions.maxX))); --WORKS
	print(string.format("minZ = %s, maxZ = %s", tostring(dimensions.minZ), tostring(dimensions.maxZ))); --WORKS
	print(string.format("width = %s, height = %s", tostring(dimensions.width), tostring(dimensions.height))); --WORKS
	
	
	---#################################################################
	-- (2) ALL PATH POINTS
	--------------------------------------------------------------------
	local numLanes, pointsPerLane = 0, 0;
	local curLaneDir;
	local pointDistance = 5;
	local pipSafety = 0.1;
	local pathPoints = {};
	
	if dir == "N" or dir == "S" then --North or South
		numLanes = math.ceil(dimensions.width / workWidth);
		pointsPerLane = math.ceil(dimensions.height / pointDistance);
		if numLanes * workWidth < dimensions.width then
			numLanes = numLanes + 1;
		end;
		--print(string.format("numLanes = %s, pointsPerLane = %s", tostring(numLanes), tostring(pointsPerLane))); --WORKS
		
		for curLane=1, numLanes do
			--Lane directions
			if dir == "S" then
				--NORTH->SOUTH, starting at NORTH
				if courseplay:isOdd(curLane) then
					curLaneDir = "S";
				elseif courseplay:isEven(curLane) then
					curLaneDir = "N";
				end;
			elseif dir == "N" then
				--SOUTH->NORTH, starting at SOUTH
				if courseplay:isOdd(curLane) then
					curLaneDir = "N";
				elseif courseplay:isEven(curLane) then
					curLaneDir = "S";
				end;
			end; 
			--print(string.format("curLane = %d, curLaneDir = %s", curLane, curLaneDir)); --WORKS
			
			for a=1, pointsPerLane do
				local curPoint = {
					num = a + ((curLane-1) * pointsPerLane);
					lane = curLane;
					laneDir = curLaneDir;
					x = dimensions.minX + (workWidth * curLane) - (workWidth/2);
					z = dimensions.minZ;
				};
				
				if crn == "NW" or crn == "SE" then
					if courseplay:isOdd(curLane) then
						curPoint.ridgeMarker = ridgeMarker["left"];
					elseif courseplay:isEven(curLane) then
						curPoint.ridgeMarker = ridgeMarker["right"];
					end;
				elseif crn == "SW" or crn == "NE" then 
					if courseplay:isOdd(curLane) then
						curPoint.ridgeMarker = ridgeMarker["right"];
					elseif courseplay:isEven(curLane) then
						curPoint.ridgeMarker = ridgeMarker["left"];
					end;
				end;
				
				if crn == "NE" or crn == "SE" then
					curPoint.x = dimensions.maxX - (workWidth * curLane) + (workWidth/2);
				end;
				
				if curLaneDir == "S" then
					curPoint.z = dimensions.minZ + (pointDistance * (a-1));
					
					if curPoint.z >= dimensions.maxZ then
						curPoint.z = dimensions.maxZ - pipSafety;
					end;
				elseif curLaneDir == "N" then
					curPoint.z = dimensions.maxZ - (pointDistance * (a-1));

					if curPoint.z <= dimensions.minZ then
						curPoint.z = dimensions.minZ + pipSafety;
					end;
				end;
				
				--last lane
				if curPoint.x <= dimensions.minX then
					curPoint.x = dimensions.minX + (workWidth/2);
				end;
				if curPoint.x >= dimensions.maxX then
					curPoint.x = dimensions.maxX - (workWidth/2);
				end;
				
				--is point in field?
				--if courseplay:pointInPolygon(poly.points, curPoint.x, curPoint.z) then
				if courseplay:pointInPolygon_v2(poly, curPoint.x, curPoint.z) then
					--print(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z));
					table.insert(pathPoints, curPoint);
				else
					--print(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z));
				end;
			end; --END for curPoint in pointsPerLane
		end; --END for curLane in numLanes
	--END North or South
	
	elseif dir == "E" or dir == "W" then --East or West
		numLanes = math.ceil(dimensions.height / workWidth);
		pointsPerLane = math.ceil(dimensions.width / pointDistance);
		if numLanes * workWidth < dimensions.height then
			numLanes = numLanes + 1;
		end;
		print(string.format("numLanes = %s, pointsPerLane = %s", tostring(numLanes), tostring(pointsPerLane))); --WORKS
		
		for curLane=1, numLanes do
			--Lane directions
			if dir == "E" then
				--WEST->EAST, starting at WEST
				if courseplay:isOdd(curLane) then
					curLaneDir = "E";
				elseif courseplay:isEven(curLane) then
					curLaneDir = "W";
				end;
			elseif dir == "W" then
				--EAST->WEST, starting at EAST
				if courseplay:isOdd(curLane) then
					curLaneDir = "W";
				elseif courseplay:isEven(curLane) then
					curLaneDir = "E";
				end;
			end; 
			--print(string.format("curLane = %d, curLaneDir = %s", curLane, curLaneDir)); --WORKS
			
			for a=1, pointsPerLane do
				local curPoint = {
					num = a + ((curLane-1) * pointsPerLane);
					lane = curLane;
					laneDir = curLaneDir;
					x = dimensions.minX;
					z = dimensions.minZ + (workWidth * curLane) - (workWidth/2);
				};
				
				if crn == "SW" or crn == "NE" then
					if courseplay:isOdd(curLane) then
						curPoint.ridgeMarker = ridgeMarker["left"];
					elseif courseplay:isEven(curLane) then
						curPoint.ridgeMarker = ridgeMarker["right"];
					end;
				elseif crn == "SE" or crn == "NW" then 
					if courseplay:isOdd(curLane) then
						curPoint.ridgeMarker = ridgeMarker["right"];
					elseif courseplay:isEven(curLane) then
						curPoint.ridgeMarker = ridgeMarker["left"];
					end;
				end;
				
				if crn == "SW" or crn == "SE" then
					curPoint.z = dimensions.maxZ - (workWidth * curLane) + (workWidth/2);
				end;
				
				if curLaneDir == "E" then
					curPoint.x = dimensions.minX + (pointDistance * (a-1));
					
					if curPoint.x >= dimensions.maxX then
						curPoint.x = dimensions.maxX - pipSafety;
					end;
				elseif curLaneDir == "W" then
					curPoint.x = dimensions.maxX - (pointDistance * (a-1));

					if curPoint.x <= dimensions.minX then
						curPoint.x = dimensions.minX + pipSafety;
					end;
				end;
				
				--last lane
				if curPoint.z <= dimensions.minZ then
					curPoint.z = dimensions.minZ + (workWidth/2);
				end;
				if curPoint.z >= dimensions.maxZ then
					curPoint.z = dimensions.maxZ - (workWidth/2);
				end;
				
				--is point in field?
				--if courseplay:pointInPolygon(poly.points, curPoint.x, curPoint.z) then
				if courseplay:pointInPolygon_v2(poly, curPoint.x, curPoint.z) then
					--print(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z));
					table.insert(pathPoints, curPoint);
				else
					--print(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z));
				end;
			end; --END for curPoint in pointsPerLane
		end; --END for curLane in numLanes
	end; --END East or West
	
	
	---###########################################################################
	-- (3) CHECK PATH LANES FOR VALID START AND END POINTS and FILL self.Waypoints
	------------------------------------------------------------------------------
	local numPoints = table.getn(pathPoints);
	for i=1, numPoints do
		local cp = pathPoints[i];   --current
		local np = pathPoints[i+1]; --next
		local pp = pathPoints[i-1]; --previous
		
		if i == 1 then
			pp = pathPoints[numPoints];
		end;
		if i == numPoints then
			np = pathPoints[1];
		end;
		
		cp.firstInLane = pp.lane ~= cp.lane; --previous point in different lane -> I'm first in lane
		cp.lastInLane = np.lane ~= cp.lane; --next point in different lane -> I'm last in lane
		local isLastLane = cp.lane == numLanes;
		
		
		--right = 0deg, top = 90deg, left = 180deg, bottom = 270deg
		local angleDeg;
		if cp.firstInLane or i == 1 then
			--angleDeg = math.deg(math.atan2(np.x - cp.x, np.z - cp.z));
			angleDeg = math.deg(math.atan2(np.z - cp.z, np.x - cp.x));
		else
			--angleDeg = math.deg(math.atan2(cp.x - pp.x, cp.z - pp.z));
			angleDeg = math.deg(math.atan2(cp.z - pp.z, cp.x - pp.x));
		end;
		
		if cp.firstInLane or i == 1 or isLastLane then 
			cp.ridgeMarker = 0;
		end;
		
		local point = { 
			cx = cp.x, 
			cz = cp.z,
			angle = angleDeg,
			wait = i == 1 or (i == numPoints and not self.cp.returnToFirstPoint),
			rev = false, 
			crossing = false,
			lane = cp.lane,
			laneDir = cp.laneDir,
			turnStart = cp.lastInLane and cp.lane < numLanes,
			turnEnd = cp.firstInLane and i > 1,
			ridgeMarker = cp.ridgeMarker,
			generated = true
		};
		
		local newFirstInLane, newLastInLane;
		
		--TURN MANEUVER ... AND STUFF
		if cp.firstInLane then
			local projectionAngle = courseplay:invertAngleDeg(point.angle);
			local testPoint, testLength = {}, 20;
			testPoint.x = cp.x + testLength * math.cos(Utils.degToRad(projectionAngle));
			testPoint.z = cp.z + testLength * math.sin(Utils.degToRad(projectionAngle));
			newFirstInLane = courseplay:lineIntersectsPoly(cp, testPoint, poly);
			
			if newFirstInLane ~= nil then
				--print(string.format("lane %d: newFirstInLane: x=%f, z=%f", cp.lane, newFirstInLane.x, newFirstInLane.z));
			
				newFirstInLane.cx = newFirstInLane.x;
				newFirstInLane.cz = newFirstInLane.z;
				newFirstInLane.angle = point.angle;
				newFirstInLane.wait = point.wait;
				newFirstInLane.crossing = point.crossing;
				newFirstInLane.lane = point.lane;
				newFirstInLane.laneDir = point.laneDir;
				newFirstInLane.firstInLane = true;				
				newFirstInLane.turn = point.turn;
				newFirstInLane.turnStart = false;
				newFirstInLane.turnEnd = true;
				newFirstInLane.ridgeMarker = 0;
				newFirstInLane.generated = true;
				
				--reset some vars in old first point
				point.wait = false;
				point.firstInLane = false;
				point.turn = nil;
				point.turnStart = false;
				point.turnEnd = false;
			end;
		end; --END cp.firstInLane
		
		if cp.lastInLane and i ~= numPoints then
			--North
			if cp.laneDir == "N" then
			--if math.floor(angleDeg) == 90 then
				if np.x < cp.x then point.turn = "left" end;
				if np.x > cp.x then point.turn = "right" end;
				
			--East
			elseif cp.laneDir == "E" then
			--elseif math.floor(angleDeg) == 0 then
				if np.z < cp.z then point.turn = "left" end;
				if np.z > cp.z then point.turn = "right" end;
			
			--South
			elseif cp.laneDir == "S" then
			--elseif math.floor(angleDeg) == -90 or math.floor(angleDeg) == 270 then
				if np.x < cp.x then point.turn = "right" end;
				if np.x > cp.x then point.turn = "left" end;
			
			--West
			elseif cp.laneDir == "W" then
			--elseif math.floor(angleDeg) == -180 or math.floor(angleDeg) == 180 then
				if np.z < cp.z then point.turn = "right" end;
				if np.z > cp.z then point.turn = "left" end;
			end;
			--print("--------------------------------------------------------------------");
			--print(string.format("laneDir=%s, point.turn=%s", cp.laneDir, tostring(point.turn)));
		
			angleDeg = courseplay:positiveAngleDeg(angleDeg);
			
			local testPoint, testLength = {}, 20;
			testPoint.x = cp.x + testLength * math.cos(Utils.degToRad(angleDeg));
			testPoint.z = cp.z + testLength * math.sin(Utils.degToRad(angleDeg));
			--print(string.format("x=%f, z=%f, testPoint: x=%f, z=%f", cp.x, cp.z, testPoint.x, testPoint.z));
	
			newLastInLane = courseplay:lineIntersectsPoly(cp, testPoint, poly);
			
			if newLastInLane ~= nil then
				--print(string.format("newLastInLane: x=%f, z=%f", newLastInLane.x, newLastInLane.z));
				newLastInLane.cx = newLastInLane.x;
				newLastInLane.cz = newLastInLane.z;
				newLastInLane.angle = point.angle;
				newLastInLane.wait = point.wait;
				newLastInLane.crossing = point.crossing;
				newLastInLane.lane = point.lane;
				newLastInLane.laneDir = point.laneDir;
				newLastInLane.lastInLane = true;
				newLastInLane.turn = point.turn;
				newLastInLane.turnStart = true;
				newLastInLane.turnEnd = false;
				newLastInLane.ridgeMarker = 0;
				newLastInLane.generated = true;
				
				point.wait = false;
				point.lastInLane = false;
				point.turn = nil;
				point.turnStart = false;
				point.turnEnd = false;

			end;
		end; --END cp.lastInLane

		if newFirstInLane ~= nil then
			table.insert(self.Waypoints, newFirstInLane);
		end;
		
		table.insert(self.Waypoints, point);
		
		if newLastInLane ~= nil then
			table.insert(self.Waypoints, newLastInLane);
		end;
		
	end; --END for i in numPoints
	
	if self.cp.returnToFirstPoint then
		self.Waypoints[table.getn(self.Waypoints)].wait = false;
		
		for b=5, 1, -1 do
			local origPathPoint = self.Waypoints[b];
			
			local point = {
				cx = origPathPoint.cx, 
				cz = origPathPoint.cz,
				angle = courseplay:invertAngleDeg(origPathPoint.angle),
				wait = b == 1,
				rev = false, 
				crossing = false,
				lane = 1,
				turnStart = false,
				turnEnd = false,
				ridgeMarker = 0,
				generated = true

			};
			table.insert(self.Waypoints, point);
		end;
	end;
	
	self.maxnumber = table.getn(self.Waypoints)
	self.recordnumber = 1
	self.play = true
	self.Waypoints[1].wait = true
	self.Waypoints[self.maxnumber].wait = true
	self.numCourses = 1;
	courseplay:RefreshSigns(self);
	
	self.cp.hasGeneratedCourse = true;
	courseplay:validateCourseGenerationData(self);
	courseplay:validateCanSwitchMode(self);
end;

function courseplay:calcDimensions(polyXValues, polyZValues)
	local dimensions = {};
	
	dimensions.minX = math.min(unpack(polyXValues));
	dimensions.maxX = math.max(unpack(polyXValues));
	dimensions.minZ = math.min(unpack(polyZValues));
	dimensions.maxZ = math.max(unpack(polyZValues));
	
	dimensions.width = dimensions.maxX - dimensions.minX;
	dimensions.height = dimensions.maxZ - dimensions.minZ;

	return dimensions;
end;

------------------------------------------------------------------------
-- ############# HELPER FUNCTIONS
--raycast
function courseplay:pointInPolygon(polyPoints, x, z)
	local intersectionCount = 0;
	local polyCount = table.getn(polyPoints);
	local x0 = polyPoints[polyCount].cx - x;
	local z0 = polyPoints[polyCount].cz - z;
	for i = 1, polyCount do
		local x1 = polyPoints[i].cx - x;
		local z1 = polyPoints[i].cz - z;
		if z0 > 0 and z1 <= 0 and x1 * z0 > z1 * x0 then
			intersectionCount = intersectionCount + 1;
		end
		if z1 > 0 and z0 <= 0 and x0 * z1 > z0 * x1 then
			intersectionCount = intersectionCount + 1;
		end
		x0 = x1;
		z0 = z1;
	end
	
	return (intersectionCount % 2) == 1;
	--return courseplay:isOdd(intersectionCount);

	-- BIG TODO: points directly on edge of poly (minX/maxX/minZ/maxZ) are returned as NOT IN POLYGON
	--			 hence using safety measure ("pipSafety")
end;


--http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
function courseplay:pointInPolygon_v2(poly, x, z)
	--nvert: Number of vertices in the polygon. Whether to repeat the first vertex at the end.
	--vertx, verty: Arrays containing the x- and y-coordinates of the polygon's vertices.
	--testx, testy: X- and y-coordinate of the test point.

	local nvert = poly.numPoints;
	local vertx, verty = poly.xValues, poly.zValues;
	local testx, testy = x, z;

	local i, j;
	local c = false;
	
	for i=1, nvert do
		if i == 1 then
			j = nvert;
		else
			j = i - 1;
		end;
		
		if ((verty[i]>testy) ~= (verty[j]>testy)) and (testx < (vertx[j]-vertx[i]) * (testy-verty[i]) / (verty[j]-verty[i]) + vertx[i]) then
			c = not c;
		end;
	end;
	return c;
end;

function courseplay:invertAngleDeg(ang)
	if ang > 0 then
		return ang - 180;
	else
		return ang + 180;
	end;
end;
function courseplay:positiveAngleDeg(ang)
	while ang < 0 do
		ang = ang + 360;
	end;
	return ang;
end;

function courseplay:projectNewPoint(fromPointX, fromPointZ, dist, ang)
	local x = fromPointX + (dist * math.cos(Utils.degToRad(ang)));
	local z = fromPointZ + (dist * math.sin(Utils.degToRad(ang)));
	return x, z;
end;

function courseplay:lineIntersectsPoly(point1, point2, poly)
	for k,wp in pairs(poly.points) do
		local nextPointIdx;
		if k < poly.numPoints then 
			nextPointIdx = k + 1;
		elseif k == poly.numPoints then
			nextPointIdx = 1;
		end;
		local nextPoint = poly.points[nextPointIdx];
		
		local intersects = courseplay:segmentsIntersection(point1.x, point1.z, point2.x, point2.z, wp.cx, wp.cz, nextPoint.cx, nextPoint.cz);
		if intersects then
			return intersects;
		end;
	end;
	return nil;
end;

--http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect#comment19248344_1968345
function courseplay:segmentsIntersection(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y)
	local s1_x, s1_y, s2_x, s2_y; 
	s1_x = A2x - A1x; 
	s1_y = A2y - A1y; 
	s2_x = B2x - B1x; 
	s2_y = B2y - B1y; 
	
	local s, t; 
	s = (-s1_y * (A1x - B1x) + s1_x * (A1y - B1y)) / (-s2_x * s1_y + s1_x * s2_y); 
	t = ( s2_x * (A1y - B1y) - s2_y * (A1x - B1x)) / (-s2_x * s1_y + s1_x * s2_y);
	
	if (s >= 0 and s <= 1 and t >= 0 and t <= 1) then
		--Collision detected 
		local x = A1x + (t * s1_x); 
		local z = A1y + (t * s1_y); 
		return { x = x, z = z }; 
	end;
	
	--No collision
	return nil;
end;
