--[[
@title:     Course Generation for Courseplay
@authors:   Jakob Tischler, skyDancer
@version:   0.62
@date:      09 Feb 2013
@updated:   08 Jun 2013

@copyright: No reproduction, usage or copying without the explicit permission by the author allowed.

TODO:
1) pointInPoly too inaccurate with points too close at poly edge
]]

function courseplay:generateCourse(self)
	local fieldCourseName = tostring(self.cp.currentCourseName);
	if self.cp.fieldEdge.selectedField.fieldNum > 0 then
		fieldCourseName = courseplay.fields.fieldData[self.cp.fieldEdge.selectedField.fieldNum].name;
	end;
	courseplay:debug(string.format("generateCourse() called for %q", fieldCourseName), 7);

	-- Make sure everything's set and in order
	courseplay:validateCourseGenerationData(self);
	if not self.cp.hasValidCourseGenerationData then
		return;
	end;

	local poly = {};
	if self.cp.fieldEdge.selectedField.fieldNum > 0 then
		poly.points = courseplay.fields.fieldData[self.cp.fieldEdge.selectedField.fieldNum].points;
	else
		poly.points = self.Waypoints;
	end;

	poly.numPoints = #(poly.points);
	poly.xValues, poly.zValues = {}, {};

	for i,wp in pairs(poly.points) do
		table.insert(poly.xValues, wp.cx);
		table.insert(poly.zValues, wp.cz);
	end;

	courseplay:reset_course(self);

	---#################################################################
	-- (1) SET UP CORNERS AND DIRECTIONS --
	--------------------------------------------------------------------
	local workWidth = self.cp.workWidth;
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


	---#################################################################
	-- (2) HEADLAND
	--------------------------------------------------------------------
	if self.cp.headland.numLanes ~= nil and self.cp.headland.numLanes ~= 0 then --we have headland, baby!
		local clockwise = courseplay:isPolyClockwise(poly.points);
		if clockwise then
			self.cp.headland.direction = "clockwise";
		else
			self.cp.headland.direction = "counterclockwise";
		end;

		if self.cp.headland.numLanes > 0 then
			self.cp.headland.order = "before";
		elseif self.cp.headland.numLanes < 0 then
			self.cp.headland.order = "after";
		end;
		courseplay:debug(string.format("generateCourse(%i): self.cp.headland.numLanes = %s, self.cp.headland.order = %s", debug.getinfo(1).currentline, tostring(self.cp.headland.numLanes), tostring(self.cp.headland.order)), 7);


		local numLanes = math.abs(self.cp.headland.numLanes);
		local fieldEdgePath = poly.points;
		self.cp.headland.lanes = {};

		for curLane=1, numLanes do
			local lane = {};
			local polyLength = table.getn(fieldEdgePath);
			local fieldEdgePathXvalues, fieldEdgePathZvalues = {}, {};
			for _,wp in pairs(fieldEdgePath) do
				table.insert(fieldEdgePathXvalues, wp.cx);
				table.insert(fieldEdgePathZvalues, wp.cz);
			end;
			local width = self.cp.workWidth;
			if curLane == 1 then
				width = self.cp.workWidth / 2;
			end;

			for i=1, polyLength do
				--courseplay:debug("curLane="..curLane..", i=" .. i, 7);
				local p1 = fieldEdgePath[i];
				local p2 = fieldEdgePath[i+1];
				local p3 = fieldEdgePath[i+2];

				if i == polyLength - 1 then --penultimate point
					p2 = fieldEdgePath[i+1];
					p3 = fieldEdgePath[1];
				elseif i == polyLength then --last point
					p2 = fieldEdgePath[1];
					p3 = fieldEdgePath[2];
				end;

				if p1.cx == p2.cx then
					p2.cx = p2.cx + 0.1;
					--courseplay:debug(i.." p2.cx == p1.cx, adding 0.1, new="..p2.cx, 7);
				end;
				if p1.cz == p2.cz then
					p2.cz = p2.cz + 0.1;
					--courseplay:debug(i.." p2.cz == p1.cz, adding 0.1, new="..p2.cz, 7);
				end;
				if p2.cx == p3.cx then
					p3.cx = p3.cx + 0.1;
					--courseplay:debug(i.." p3.cx == p2.cx, adding 0.1, new="..p3.cx, 7);
				end;
				if p2.cz == p3.cz then
					p3.cz = p3.cz + 0.1;
					--courseplay:debug(i.." p3.cz == p2.cz, adding 0.1, new="..p3.cz, 7);
				end;

				local x,z = courseplay:getOffsetCornerPoint(self, p1, p2, p3, width);
				--courseplay:debug(string.format("curLane=%d, point=%d, getOffsetCornerPoint: x=%s y=%s", curLane, i, tostring(x), tostring(z)), 7);
				if courseplay:pointInPolygon_v2(fieldEdgePath, fieldEdgePathXvalues, fieldEdgePathZvalues, x, z) then
					--courseplay:debug(string.format("curLane=%d, point=%d, point is in fieldEdgePath", curLane, i), 7);
					local pos = {
						cx = x,
						cz = z,
					};

					table.insert(lane, pos);
				end;
			end; --END for i in poly

			courseplay:debug(string.format("generateCourse(%i): #lane %s = %s", debug.getinfo(1).currentline, tostring(curLane), tostring(table.getn(lane))), 7);
			local fixedLane = courseplay:removeIntersections(lane, 7); --DEFAULT: 7 // TEST: 12
			courseplay:debug(string.format("generateCourse(%i): #fixedLane = %s", debug.getinfo(1).currentline, tostring(table.getn(fixedLane))), 7);

			if curLane == 1 then
				repeat
					change = false;
					local lastPoint = table.getn(fixedLane);
					local distance = courseplay:distance(fixedLane[1].cx, fixedLane[1].cz, fixedLane[lastPoint].cx, fixedLane[lastPoint].cz);
					if distance <= self.cp.workWidth then --TODO: self.cp.workWidth or self.cp.workWidth/2 ???
						table.remove(fixedLane, lastPoint);
						change = true;
					end
				until change == false;
			end;
			courseplay:debug(string.format("generateCourse(%i): #fixedLane (after distance checks) = %s", debug.getinfo(1).currentline, tostring(table.getn(fixedLane))), 7);


			local laneRidgeMarker = ridgeMarker["none"];
			if numLanes == 2 then
				if self.cp.headland.order == "before" and curLane == 1 then
					if self.cp.headland.direction == "clockwise" then
						laneRidgeMarker = ridgeMarker["right"];
					elseif self.cp.headland.direction == "counterclockwise" then
						laneRidgeMarker = ridgeMarker["left"];
					end;
				elseif self.cp.headland.order == "after" and curLane == 2 then
					if self.cp.headland.direction == "clockwise" then
						laneRidgeMarker = ridgeMarker["left"];
					elseif self.cp.headland.direction == "counterclockwise" then
						laneRidgeMarker = ridgeMarker["right"];
					end;
				end;
			end;

			for j,curPoint in pairs(fixedLane) do
				local signAngleDeg;
				if j == 1 then
					local nextPoint = fixedLane[j+1];
					signAngleDeg = math.deg(math.atan2(nextPoint.cx - curPoint.cx, nextPoint.cz - curPoint.cz));
				else
					local prevPoint = fixedLane[j-1];
					signAngleDeg = math.deg(math.atan2(curPoint.cx - prevPoint.cx, curPoint.cz - prevPoint.cz));
				end;
				curPoint.angle = signAngleDeg;
				curPoint.wait = false;
				curPoint.rev = false;
				curPoint.crossing = false;
				curPoint.generated = true;
				curPoint.lane = curLane * -1; --negative lane = headland
				curPoint.firstInLane = false;
				curPoint.turn = nil;
				curPoint.turnStart = false;
				curPoint.turnEnd = false;
				curPoint.ridgeMarker = laneRidgeMarker;
			end;

			fieldEdgePath = fixedLane;
			courseplay:debug(string.format("generateCourse(%i): inserting fixedLane #%s into headland.lanes", debug.getinfo(1).currentline, tostring(curLane)), 7);
			table.insert(self.cp.headland.lanes, fixedLane);
		end; --END for curLane in numLanes


		--base field work course on headland path
		local numCreatedLanes = table.getn(self.cp.headland.lanes);
		if numCreatedLanes > 0 then
			poly.points = self.cp.headland.lanes[numCreatedLanes];
			poly.numPoints = table.getn(poly.points);
		end;

		courseplay:debug(string.format("generateCourse(%i):  #self.cp.headland.lanes = %s", debug.getinfo(1).currentline, tostring(table.getn(self.cp.headland.lanes))), 7);
		--courseplay:debug(tableShow(self.cp.headland.lanes, "self.cp.headland.lanes"), 7);
	end; --END if self.cp.headland.numLanes ~= 0



	---#################################################################
	-- (3) DIMENSIONS, ALL PATH POINTS
	--------------------------------------------------------------------
	--reset x/z values and get field dimensions
	poly.xValues, poly.zValues = {}, {};
	for _,wp in pairs(poly.points) do
		table.insert(poly.xValues, wp.cx);
		table.insert(poly.zValues, wp.cz);
	end;
	local dimensions = courseplay:calcDimensions(poly.xValues, poly.zValues);
	courseplay:debug(string.format("minX = %s, maxX = %s", tostring(dimensions.minX), tostring(dimensions.maxX)), 7); --WORKS
	courseplay:debug(string.format("minZ = %s, maxZ = %s", tostring(dimensions.minZ), tostring(dimensions.maxZ)), 7); --WORKS
	courseplay:debug(string.format("generateCourse(%i): width = %s, height = %s", debug.getinfo(1).currentline, tostring(dimensions.width), tostring(dimensions.height)), 7); --WORKS

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
		courseplay:debug(string.format("generateCourse(%i): numLanes = %s, pointsPerLane = %s", debug.getinfo(1).currentline, tostring(numLanes), tostring(pointsPerLane)), 7); --WORKS

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
			courseplay:debug(string.format("curLane = %d, curLaneDir = %s", curLane, curLaneDir), 7); --WORKS

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
				curPoint.x = Utils.clamp(curPoint.x, dimensions.minX + (workWidth/2), dimensions.maxX - (workWidth/2));

				--is point in field?
				--if courseplay:pointInPolygon(poly.points, curPoint.x, curPoint.z) then
				if courseplay:pointInPolygon_v2(poly.points, poly.xValues, poly.zValues, curPoint.x, curPoint.z) then
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
					table.insert(pathPoints, curPoint);
				else
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
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
		courseplay:debug(string.format("generateCourse(%i): numLanes = %s, pointsPerLane = %s", debug.getinfo(1).currentline, tostring(numLanes), tostring(pointsPerLane)), 7); --WORKS

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
			courseplay:debug(string.format("curLane = %d, curLaneDir = %s", curLane, curLaneDir), 7); --WORKS

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
				curPoint.z = Utils.clamp(curPoint.z, dimensions.minZ + (workWidth/2), dimensions.maxZ - (workWidth/2));

				--is point in field?
				--if courseplay:pointInPolygon(poly.points, curPoint.x, curPoint.z) then
				if courseplay:pointInPolygon_v2(poly.points, poly.xValues, poly.zValues, curPoint.x, curPoint.z) then
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
					table.insert(pathPoints, curPoint);
				else
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
				end;
			end; --END for curPoint in pointsPerLane
		end; --END for curLane in numLanes
	end; --END East or West


	---############################################################################
	-- (4) CHECK PATH LANES FOR VALID START AND END POINTS and FILL fieldWorkCourse
	-------------------------------------------------------------------------------
	local fieldWorkCourse = {};
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


		--REAL ANGLE: right = 0deg, top = 90deg, left = 180deg, bottom = 270deg
		--SIGN ANGLE: N=180, E=90, S=0, W=270
		local angleDeg, signAngleDeg;
		if cp.firstInLane or i == 1 then
			angleDeg     = math.deg(math.atan2(np.z - cp.z, np.x - cp.x));
			signAngleDeg = math.deg(math.atan2(np.x - cp.x, np.z - cp.z));
		else
			angleDeg     = math.deg(math.atan2(cp.z - pp.z, cp.x - pp.x));
			signAngleDeg = math.deg(math.atan2(cp.x - pp.x, cp.z - pp.z));
		end;

		if cp.firstInLane or i == 1 or isLastLane then
			cp.ridgeMarker = 0;
		end;

		local point = {
			cx = cp.x,
			cz = cp.z,
			angle = angleDeg,
			wait = false, --will be set to true for first and last after all is set and done
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
				--courseplay:debug(string.format("lane %d: newFirstInLane: x=%f, z=%f", cp.lane, newFirstInLane.x, newFirstInLane.z), 7);

				newFirstInLane.cx = newFirstInLane.x;
				newFirstInLane.cz = newFirstInLane.z;
				newFirstInLane.angle = point.angle;
				newFirstInLane.wait = point.wait;
				newFirstInLane.crossing = point.crossing;
				newFirstInLane.rev = point.rev;
				newFirstInLane.lane = point.lane;
				newFirstInLane.laneDir = point.laneDir;
				newFirstInLane.firstInLane = true;
				newFirstInLane.turn = point.turn;
				newFirstInLane.turnStart = false;
				newFirstInLane.turnEnd = i > 1 --true;
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
				if np.x < cp.x then point.turn = "left" end;
				if np.x > cp.x then point.turn = "right" end;

			--East
			elseif cp.laneDir == "E" then
				if np.z < cp.z then point.turn = "left" end;
				if np.z > cp.z then point.turn = "right" end;

			--South
			elseif cp.laneDir == "S" then
				if np.x < cp.x then point.turn = "right" end;
				if np.x > cp.x then point.turn = "left" end;

			--West
			elseif cp.laneDir == "W" then
				if np.z < cp.z then point.turn = "right" end;
				if np.z > cp.z then point.turn = "left" end;
			end;
			--courseplay:debug("--------------------------------------------------------------------", 7);
			--courseplay:debug(string.format("laneDir=%s, point.turn=%s", cp.laneDir, tostring(point.turn)), 7);

			angleDeg = courseplay:positiveAngleDeg(angleDeg);

			local testPoint, testLength = {}, 20;
			testPoint.x = cp.x + testLength * math.cos(Utils.degToRad(angleDeg));
			testPoint.z = cp.z + testLength * math.sin(Utils.degToRad(angleDeg));
			--courseplay:debug(string.format("x=%f, z=%f, testPoint: x=%f, z=%f", cp.x, cp.z, testPoint.x, testPoint.z), 7);

			newLastInLane = courseplay:lineIntersectsPoly(cp, testPoint, poly);

			if newLastInLane ~= nil then
				--courseplay:debug(string.format("newLastInLane: x=%f, z=%f", newLastInLane.x, newLastInLane.z), 7);
				newLastInLane.cx = newLastInLane.x;
				newLastInLane.cz = newLastInLane.z;
				newLastInLane.angle = point.angle;
				newLastInLane.wait = point.wait;
				newLastInLane.crossing = point.crossing;
				newLastInLane.rev = point.rev;
				newLastInLane.lane = point.lane;
				newLastInLane.laneDir = point.laneDir;
				newLastInLane.lastInLane = true;
				newLastInLane.turn = point.turn;
				newLastInLane.turnStart = i < numPoints --true;
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
			newFirstInLane.angle = signAngleDeg;
			table.insert(fieldWorkCourse, newFirstInLane);
		end;

		point.angle = signAngleDeg;
		table.insert(fieldWorkCourse, point);

		if newLastInLane ~= nil then
			newLastInLane.angle = signAngleDeg;
			table.insert(fieldWorkCourse, newLastInLane);
		end;

	end; --END for i in numPoints

	local lastFivePoints = {};
	if self.cp.returnToFirstPoint then
		fieldWorkCourse[table.getn(fieldWorkCourse)].wait = false;

		for b=5, 1, -1 do
			local origPathPoint = fieldWorkCourse[b];

			local point = {
				cx = origPathPoint.cx,
				cz = origPathPoint.cz,
				angle = courseplay:invertAngleDeg(origPathPoint.angle),
				wait = false, --b == 1,
				rev = false,
				crossing = false,
				lane = 1,
				turnStart = false,
				turnEnd = false,
				ridgeMarker = 0,
				generated = true
			};
			table.insert(lastFivePoints, point);
		end;
	end;



	---############################################################################
	-- (5) ROTATE HEADLAND COURSES
	-------------------------------------------------------------------------------
	local numHeadlandLanesCreated = 0;
	if math.abs(self.cp.headland.numLanes) > 0 then
		numHeadlandLanesCreated = table.getn(self.cp.headland.lanes);
		if numHeadlandLanesCreated > 0 then
			if self.cp.headland.order == "before" then --each headland lanes' first point is closest to first fieldwork course point

				for i=1, numHeadlandLanesCreated do
					local lane = self.cp.headland.lanes[i];
					local closest = courseplay:closestPolyPoint(lane, fieldWorkCourse[1].cx, fieldWorkCourse[1].cz);
					courseplay:debug(string.format("[before] rotating headland lane=%d, closest=%s", i, tostring(closest)), 7);
					self.cp.headland.lanes[i] = courseplay:rotateTable(lane, table.getn(lane) - (closest-1));
					--courseplay:debug(tableShow(self.cp.headland.lanes[i], "rotated headland lane "..i), 7);
				end;
			elseif self.cp.headland.order == "after" then --each headland lanes' first point is closest to last fieldwork course point
				local lastFieldworkPoint = fieldWorkCourse[table.getn(fieldWorkCourse)];
				--courseplay:debug(tableShow(lastFieldWorkPoint, "lastFieldWorkPoint"), 7); --TODO: is nil - whyyyyy?
				local headlandLanes = {}
				for i=numHeadlandLanesCreated, 1, -1 do
					local lane = self.cp.headland.lanes[i];
					local closest = courseplay:closestPolyPoint(lane, lastFieldworkPoint.cx, lastFieldworkPoint.cz); --TODO: works, but how if lastFieldWorkPoint is nil???
					courseplay:debug(string.format("[after] rotating headland lane=%d, closest=%s", i, tostring(closest)), 7);
					table.insert(headlandLanes, courseplay:rotateTable(lane, table.getn(lane) - (closest-1)));
				end;

				self.cp.headland.lanes = nil;
				self.cp.headland.lanes = {};
				self.cp.headland.lanes = headlandLanes;
				--courseplay:debug(tableShow(self.cp.headland.lanes, "rotated headland lanes"), 7);
			end;
		end;
	end;



	---############################################################################
	-- (6) CONCATENATE HEADLAND COURSE and FIELDWORK COURSE
	-------------------------------------------------------------------------------
	self.Waypoints = {};

	if numHeadlandLanesCreated > 0 then
		if self.cp.headland.order == "before" then
			for i=1, table.getn(self.cp.headland.lanes) do
				self.Waypoints = tableConcat(self.Waypoints, self.cp.headland.lanes[i]);
			end;
			self.Waypoints = tableConcat(self.Waypoints, fieldWorkCourse);
		elseif self.cp.headland.order == "after" then
			self.Waypoints = tableConcat(self.Waypoints, fieldWorkCourse);
			for i=1, table.getn(self.cp.headland.lanes) do
				self.Waypoints = tableConcat(self.Waypoints, self.cp.headland.lanes[i]);
			end;
		end;
	else
		self.Waypoints = fieldWorkCourse;
	end;

	if table.getn(lastFivePoints) > 0 then
		self.Waypoints = tableConcat(self.Waypoints, lastFivePoints);
	end;



	---############################################################################
	-- (7) FINAL COURSE DATA
	-------------------------------------------------------------------------------
	self.maxnumber = table.getn(self.Waypoints)
	if self.maxnumber == 0 then
		return;
	end;

	self.recordnumber = 1;
	self.cp.canDrive = true;
	self.Waypoints[1].wait = true;
	self.Waypoints[1].crossing = true;
	self.Waypoints[self.maxnumber].wait = true;
	self.Waypoints[self.maxnumber].crossing = true;
	self.numCourses = 1;
	courseplay:updateWaypointSigns(self);

	self.cp.hasGeneratedCourse = true;
	courseplay:setFieldEdgePath(self, nil, 0);
	courseplay:validateCourseGenerationData(self);
	courseplay:validateCanSwitchMode(self);

	courseplay:debug(string.format("generateCourse() finished: %d lanes, %d headland lane(s)", numLanes, numHeadlandLanesCreated), 7);
end;


------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
-- ############# HELPER FUNCTIONS
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


function courseplay:pointInPolygon_v2(polygon, xValues, zValues, x, z) --@src: http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
	--nvert: Number of vertices in the polygon. Whether to repeat the first vertex at the end.
	--vertx, verty: Arrays containing the x- and y-coordinates of the polygon's vertices.
	--testx, testy: X- and y-coordinate of the test point.

	local nvert = table.getn(polygon);
	local vertx, verty = xValues, zValues;
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

function courseplay:segmentsIntersection(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y) --@src: http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect#comment19248344_1968345
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

function courseplay:isPolyClockwise(poly) --@src: https://github.com/ChubbRck/Cosmic-Crossfire/blob/master/mathlib.lua#L322
	local area = 0;
	local cp, np, fp;

	for i=1, table.getn(poly)-1 do
		cp = poly[i];
		np = poly[i+1];
		fp = poly[1];

		local pointStart = {
			x = cp.cx - fp.cx;
			z = cp.cz - fp.cz;
		};
		local pointEnd = {
			x = np.cx - fp.cx;
			z = np.cz - fp.cz;
		};

		area = area + (pointStart.x * -pointEnd.z) - (pointEnd.x * -pointStart.z);
	end;

	return (area < 0);
end;


function courseplay:calcOffsetPoint(self, pt1, pt2, offset)
	theta = math.atan2(pt2.cz - pt1.cz, pt2.cx - pt1.cx);

	if self.cp.headland.direction == "clockwise" then
		theta = theta - math.pi/2;
	elseif self.cp.headland.direction == "counterclockwise" then
		theta = theta + math.pi/2;
	end;

	x = pt1.cx - math.cos(theta) * offset;
	z = pt1.cz - math.sin(theta) * offset;
	return x, z;
end
function courseplay:getOffsetIntercept(self, pt1, pt2, m, offset)
	x,z = courseplay:calcOffsetPoint(self, pt1, pt2, offset)
	return z - m * x;
end
function courseplay:getPt(self, pt1, pt2, pt3, offset)
	m = (pt2.cz - pt1.cz) / (pt2.cx - pt1.cx);
	bOffset = courseplay:getOffsetIntercept(self, pt1, pt2, m, offset);
	mPrime = (pt3.cz - pt2.cz) / (pt3.cx - pt2.cx);
	bOffsetPrime = courseplay:getOffsetIntercept(self, pt2, pt3, mPrime, offset);
	newX = (bOffsetPrime - bOffset) / (m - mPrime);
	newY = m * newX + bOffset;
	return newX, newY;
end
function courseplay:getSlopeAndIntercept(self, pt1, pt2, offset)
	m = (pt2.cz - pt1.cz) / (pt2.cx - pt1.cx);
	b = courseplay:getOffsetIntercept(self, pt1, pt2, m, offset);
	return m, b;
end
function courseplay:getOffsetCornerPoint(self, pt1, pt2, pt3, offset)
	if pt2.cz - pt1.cz == 0.0 then
		ycoord = pt1.cz - math.cos(math.atan2(0.0, pt2.cx - pt1.cx)) * offset;
		if pt3.cx - pt2.cx == 0.0 then
			xcoord = pt2.cx + math.sin(math.atan2(pt3.cz - pt2.cz, 0.0)) * offset;
		else
			local m,offsetIntercept = courseplay:getSlopeAndIntercept(self, pt2, pt3, offset);
			xcoord = (ycoord - offsetIntercept)/m;
		end;
	end;
	if pt2.cx - pt1.cx == 0.0 then
		xcoord = pt1.cx + math.sin(math.atan2(pt2.cz - pt1.cz, 0.0)) * offset;
		if (pt3.cz - pt2.cz == 0.0) then
			ycoord = pt2.cz - math.cos(math.atan2(0.0, pt3.cx - pt2.cx)) * offset;
		else
			local m,offsetIntercept = courseplay:getSlopeAndIntercept(self, pt2, pt3, offset);
			ycoord = m * xcoord + offsetIntercept;
		end;
	end;
	if (pt2.cz - pt1.cz ~= 0.0 and pt2.cx - pt1.cx ~= 0.0) then
		if (pt3.cz - pt2.cz == 0.0) then
			ycoord = pt2.cz - math.cos(math.atan2(0.0, pt3.cx - pt2.cx)) * offset;
			local m,offsetIntercept = courseplay:getSlopeAndIntercept(self, pt2, pt3, offset);
			xcoord = (ycoord - offsetIntercept)/m;
		elseif (pt3.cx - pt2.cx == 0.0) then
			xcoord = pt2.cx + math.sin(math.atan2(pt3.cz - pt2.cz, 0.0)) * offset;
			local m,offsetIntercept = courseplay:getSlopeAndIntercept(self, pt2, pt3, offset);
			ycoord = m * xcoord + offsetIntercept;
		else
			xcoord, ycoord = courseplay:getPt(self, pt1, pt2, pt3, offset);
		end;
	end;
    return xcoord, ycoord;
end

function courseplay:removeIntersections(poly, lookAhead)
	local outputList = poly;
	if lookAhead == nil then
		lookAhead = 7;
	end;

	repeat
		hasChanged = false;
		for m=3, lookAhead do
			local inputList = outputList;
			--courseplay:debug(tableShow(inputList, "inputList"), 7);
			outputList = {};

			i = 1;
			while i <= table.getn(inputList) do
				local p1 = i;
				local p2 = i+1;
				local p3 = i+m-1;
				local p4 = i+m;

				if p2 > table.getn(inputList) then
					p2 = p2 - table.getn(inputList);
				end;
				if p3 > table.getn(inputList) then
					p3 = p3 - table.getn(inputList);
				end;
				if p4 > table.getn(inputList) then
					p4 = p4 - table.getn(inputList);
				end;

				local intersect = courseplay:segmentsIntersection(inputList[p1].cx,inputList[p1].cz, inputList[p2].cx,inputList[p2].cz, inputList[p3].cx,inputList[p3].cz, inputList[p4].cx,inputList[p4].cz);
				if intersect then
					local p = {
						cx = intersect.x;
						cz = intersect.z;
					};
					table.insert(outputList, p);
					i = i+m;
					hasChanged = true
				else
					local p = {
						cx = inputList[p1].cx;
						cz = inputList[p1].cz;
					};
					table.insert(outputList, p);
					i = i + 1;
				end;
			end; --END while
		end; --END for m=3,lookAhead
	until hasChanged == false;
	return outputList;
end;

function courseplay:closestPolyPoint(poly, x, z)
	--local closestDistance = 999999999; --TODO: testing math.huge
	local closestDistance = math.huge;
	local closestPointIndex;
	local rotatedPoly = poly;

	for i=1, table.getn(poly) do
		local cp = poly[i];
		local distanceToPoint = courseplay:distance(cp.cx, cp.cz, x, z);
		if distanceToPoint < closestDistance then
			closestDistance = distanceToPoint;
			closestPointIndex = i;
		end;
	end;

	return closestPointIndex;
end;

function courseplay:rotateTable(tableArray, inc) --@gist: https://gist.github.com/JakobTischler/b4bb7a4d1c8cf8d2d85f
	if inc == nil or inc == 0 then
		return tableArray;
	end;

	local t = tableArray;
	local rot = math.abs(inc);

	if inc < 0 then
		for i=1,rot do
			local p = t[1];
			table.remove(t, 1);
			table.insert(t, p);
		end;
	else
		for i=1,rot do
			local n = table.getn(t);
			local p = t[n];
			table.remove(t, n);
			table.insert(t, 1, p);
		end;
	end;

	return t;
end;

