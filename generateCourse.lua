--[[
@title:     Course Generation for Courseplay
@authors:   Jakob Tischler
@version:   0.71
@date:      09 Feb 2013

@coaothors: Fck54 (Franck Champlon)
@updated:   04 august 2014

@copyright: No reproduction, usage or copying without the explicit permission by the author allowed.
]]

function courseplay:generateCourse(vehicle)
	local self = courseplay.generation;
	-----------------------------------
	vehicle.cp.headland.overlap = 1/4; --TODO add this in the menu

	local fieldCourseName = tostring(vehicle.cp.currentCourseName);
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		fieldCourseName = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].name;
	end;
	courseplay:debug(string.format("generateCourse() called for %q", fieldCourseName), 7);

	-- Make sure everything's set and in order
	courseplay:validateCourseGenerationData(vehicle);
	if not vehicle.cp.hasValidCourseGenerationData then
		return;
	end;

	local poly = {};
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		poly.points = courseplay.utils.table.copy(courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points, true);
		poly.numPoints = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].numPoints;
	else
		poly.points = courseplay.utils.table.copy(vehicle.Waypoints, true);
		poly.numPoints = #(poly.points);
	end;
	local field = poly.points ;
	courseplay:debug(string.format('before headland: poly=%s, poly.points=%s, poly.numPoints=%s', tostring(poly), tostring(poly.points), tostring(poly.numPoints)), 7);
	
	--TODO: needed here?
	--[[
	poly.xValues, poly.zValues = {}, {};
	for i,cp in pairs(poly.points) do
		-- courseplay:debug(string.format('generateCourse(%i): x/zValues (%d): add cp.cx [%.1f] to xValues, add cp.cz [%.1f] to zValues', debug.getinfo(1).currentline, i, cp.cx, cp.cz), 7);
		table.insert(poly.xValues, cp.cx);
		table.insert(poly.zValues, cp.cz);
	end;
	]]

	courseplay:clearCurrentLoadedCourse(vehicle);

	---#################################################################
	-- (1) SET UP CORNERS AND DIRECTIONS --
	--------------------------------------------------------------------
	courseplay:debug('(1) SET UP CORNERS AND DIRECTIONS', 7);

	local workWidth = vehicle.cp.workWidth;
	local corners = {
		[1] = 'SW',
		[2] = 'NW',
		[3] = 'NE',
		[4] = 'SE'
	};
	local directions = {
		[1] = 'N',
		[2] = 'E',
		[3] = 'S',
		[4] = 'W'
	};
	local ridgeMarker = {
		none = 0,
		left = 1,
		right = 2
	};
	local crn = corners[vehicle.cp.startingCorner];
	local dir = directions[vehicle.cp.startingDirection];
	local fieldEdge = poly.points;
	
	---#################################################################
	-- (2) HEADLAND
	--------------------------------------------------------------------
	courseplay:debug('(2) HEADLAND', 7);
	
	if vehicle.cp.headland.numLanes and vehicle.cp.headland.numLanes > 0 then --we have headland, baby!

		courseplay:debug(string.format("generateCourse(%i): headland.numLanes=%s, headland.orderBefore=%s", debug.getinfo(1).currentline, tostring(vehicle.cp.headland.numLanes), tostring(vehicle.cp.headland.orderBefore)), 7);


		local orderCW = vehicle.cp.headland.userDirClockwise;
		local numLanes = vehicle.cp.headland.numLanes;
		local polyPoints = poly.points; 
		if not(self:isPolyClockwise(polyPoints)) then
			polyPoints = table.reverse(polyPoints);
		end;
		local polyLength = poly.numPoints;

		vehicle.cp.headland.lanes = {};
		local offsetWidth, noGoWidth = 0,0;

		for curLane=1, numLanes do

			local laneRidgeMarker = ridgeMarker.none;
			if numLanes > 1 then
				if vehicle.cp.headland.orderBefore and curLane < numLanes then
					laneRidgeMarker = orderCW and ridgeMarker.right or ridgeMarker.left;
				elseif not vehicle.cp.headland.orderBefore and curLane > 1 then
					laneRidgeMarker = orderCW and ridgeMarker.left or ridgeMarker.right;
				end;
			end;

			local laneOffsetWidth, laneNoGoWidth = self:getOffsetWidth(vehicle, curLane);
			noGoWidth = offsetWidth + laneNoGoWidth;
			offsetWidth = offsetWidth + laneOffsetWidth;

			courseplay:debug(string.format('headland lane %d: laneRidgeMarker=%d, offset offsetWidth=%.1f, noGoWidth=%.2f', curLane, laneRidgeMarker, offsetWidth, noGoWidth), 7);

			-- --------------------------------------------------
			-- (2.1) CREATE INITIAL OFFSET POINTS
			courseplay:debug('(2.1) CREATE INITIAL OFFSET POINTS', 7);
			local lane = courseplay:offsetPoly(polyPoints, -offsetWidth, vehicle);
			if not(orderCW) then
				lane = table.reverse(lane);
			end;

			local numOffsetPoints = #lane;
			table.insert(lane, lane[1]);
			for i = 1, numOffsetPoints do
				local point = lane[i];
				local nextPoint = lane[i+1];
				local pointAngle = math.deg(courseplay.generation:pointAngle(point,nextPoint));
				local data = {
					cx = point.cx,
					cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, point.cx, 1, point.cz), --TODO: actually only needed for debugPoint/debugLine
					cz = point.cz,
					angle = pointAngle,
					wait = false,
					rev = false,
					crossing = false,
					generated = true,
					lane = curLane * -1, --negative lane = headland
					-- cp.firstInLane = false;
					turn = nil,
					turnStart = false,
					turnEnd = false,
					ridgeMarker = laneRidgeMarker
				};
				lane[i] = data;
				--[[if i > 1 then
					local prevAngle = lane[i-1].angle;
						
					courseplay:debug(string.format('angles are (%.2f / %.2f)',prevAngle, pointAngle),7);
					 
					if self:arePerpendicular(pointAngle,prevAngle,20,true) then
						if orederCW then
							lane[i].turn = 'right90';
						else
							lane[i].turn = 'left90';
						end;
						lane[i].turnStart = true;
						lane[i+1].turnEnd = true;
					elseif self:areOpposit(pointAngle,prevAngle,45,true) then
						if orderCW then
							lane[i].turn = 'right';
						else
							lane[i].turn = 'left';
						end;
						lane[i].turnStart = true;
						lane[i+1].turnEnd = true;
					end;
				end;]]--
			end;
			table.remove(lane);
		

			
			courseplay:debug(string.format("generateCourse(%i): #lane %s = %s", debug.getinfo(1).currentline, tostring(curLane), tostring(numOffsetPoints)), 7);
			--courseplay:debug(tableShow(lane, string.format('[line %d] lane %d', debug.getinfo(1).currentline, curLane), 7), 7); -- WORKS


			-- --------------------------------------------------

			-- --------------------------------------------------

			if numOffsetPoints > 0 then
				-- --------------------------------------------------
				-- (2.4) FINALIZE (ADD POINT DATA)
				courseplay:debug('(2.4) FINALIZE (ADD POINT DATA)', 7);
	
				table.insert(vehicle.cp.headland.lanes, lane);
				courseplay:debug(string.format("generateCourse(%i): inserting lane #%d (%d points) into headland.lanes", debug.getinfo(1).currentline, curLane, numOffsetPoints), 7);
				-- courseplay:debug(tableShow(lane, string.format('[line %d] lane %d', debug.getinfo(1).currentline, curLane), 7), 7); --WORKS
			else
				courseplay:debug(string.format('headland lane #%d has fewer than 5 points (invalid) -> stop headland calculation', curLane), 7);
				break;
			end;
		end; --END for curLane in numLanes
		
		
		local numCreatedLanes = #(vehicle.cp.headland.lanes);
		courseplay:debug(string.format('generateCourse(%i):  #vehicle.cp.headland.lanes=%s', debug.getinfo(1).currentline, tostring(numCreatedLanes)), 7);
		-- courseplay:debug(tableShow(vehicle.cp.headland.lanes, 'vehicle.cp.headland.lanes', 7), 7); --WORKS

		--base field work course on headland path
		if numCreatedLanes > 0 then
			poly.points = vehicle.cp.headland.lanes[numCreatedLanes];
			if vehicle.cp.headland.overlap ~= 0 then
				local laneOffsetWidth, laneNoGoWidth = self:getOffsetWidth(vehicle, curLane);
				noGoWidth = offsetWidth + laneNoGoWidth * vehicle.cp.headland.overlap;
				offsetWidth = offsetWidth + laneOffsetWidth * vehicle.cp.headland.overlap;
				poly.points = courseplay:offsetPoly(polyPoints, -offsetWidth);
			end;
			poly.numPoints = #(poly.points);
			courseplay:debug(string.format('headland: numCreatedLanes=%d -> poly=%s, poly.points=%s, poly.numPoints=%s, #poly.points=%s', numCreatedLanes, tostring(poly), tostring(poly.points), tostring(poly.numPoints), tostring(poly.points and #poly.points or 'nil')), 7);
		end;
		
	end; --END if vehicle.cp.headland.numLanes ~= 0


	---#################################################################
	-- (3) DIMENSIONS, ALL PATH POINTS
	--------------------------------------------------------------------
	courseplay:debug('(3) DIMENSIONS, ALL PATH POINTS', 7);

	local _, _, dimensions = courseplay.fields:getPolygonData(field, nil, nil, true, true);
	courseplay:debug(string.format('minX=%s, maxX=%s', tostring(dimensions.minX), tostring(dimensions.maxX)), 7); --WORKS
	courseplay:debug(string.format('minZ=%s, maxZ=%s', tostring(dimensions.minZ), tostring(dimensions.maxZ)), 7); --WORKS
	courseplay:debug(string.format('generateCourse(%i): width=%s, height=%s', debug.getinfo(1).currentline, tostring(dimensions.width), tostring(dimensions.height)), 7); --WORKS

	local numLanes, pointsPerLane = 0, 0;
	local curLaneDir;
	local pointDistance = 5;
	local pipSafety = 0.1;
	local pathPoints, fieldPoints = {}, {};

	if dir == "N" or dir == "S" then --North or South
		numLanes = math.ceil(dimensions.width / workWidth);
		pointsPerLane = math.ceil(dimensions.height / pointDistance);
		if numLanes * workWidth < dimensions.width then
			numLanes = numLanes + 1;
		end;
		courseplay:debug(string.format('generateCourse(%i): numLanes=%s, pointsPerLane=%s', debug.getinfo(1).currentline, tostring(numLanes), tostring(pointsPerLane)), 7); --WORKS

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
				local _, pointInPoly = courseplay.fields:getPolygonData(poly.points, curPoint.x, curPoint.z, true, true, true);
				if pointInPoly then
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
					table.insert(pathPoints, curPoint);
				else
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
				end;
				local _, pointInPoly = courseplay.fields:getPolygonData(field, curPoint.x, curPoint.z, true, true, true);
				if pointInPoly then
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
					local point = {
						cx = curPoint.x,
						cz = curPoint.z
					};
					table.insert(fieldPoints, point);
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
				local _, pointInPoly = courseplay.fields:getPolygonData(poly.points, curPoint.x, curPoint.z, true, true, true);
        		if pointInPoly then
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
					table.insert(pathPoints, curPoint);
				else
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
				end;
				local _, pointInPoly = courseplay.fields:getPolygonData(field, curPoint.x, curPoint.z, true, true, true);
				if pointInPoly then
					--courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.x, curPoint.z), 7);
					local point = {
						cx = curPoint.x,
						cz = curPoint.z
					};
					table.insert(fieldPoints, point);
				end;

			end; --END for curPoint in pointsPerLane
		end; --END for curLane in numLanes
	end; --END East or West


	---############################################################################
	-- (4) CHECK PATH LANES FOR VALID START AND END POINTS and FILL fieldWorkCourse
	-------------------------------------------------------------------------------
	courseplay:debug('(4) CHECK PATH LANES FOR VALID START AND END POINTS and FILL fieldWorkCourse', 7);
	local fieldWorkCourse = {};
	local numPoints = #(pathPoints);

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
			newFirstInLane = self:lineIntersectsPoly(cp, testPoint, poly);

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

				--reset some locals in old first point
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

			newLastInLane = self:lineIntersectsPoly(cp, testPoint, poly);

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
	local startPoint = fieldWorkCourse[1];

	---############################################################################
	-- (5) ROTATE HEADLAND COURSES
	-------------------------------------------------------------------------------
	courseplay:debug('(5) ROTATE HEADLAND COURSES', 7);
	local numHeadlandLanesCreated = 0;
	local turnAtHeadEnd = false;
	local startOnEdge = courseplay:findCrossing(fieldPoints[2], fieldPoints[1], field, 'PFIP');
	if vehicle.cp.headland.numLanes > 0 then
		numHeadlandLanesCreated = #(vehicle.cp.headland.lanes);
		if numHeadlandLanesCreated > 0 then
			if vehicle.cp.headland.orderBefore then --each headland lanes' first point is closest to corresponding field edge corner point
				local lanes = {};
				local prevLane;
				for i,lane in ipairs(vehicle.cp.headland.lanes) do
					local closest = self:getClosestPolyPoint(lane, startOnEdge.cx, startOnEdge.cz);
					courseplay:debug(string.format('closest point on lane is : %d (%.2f, %.2f)', closest, lane[closest].cx, lane[closest].cz), 7);
					local numPoints = #lane;
					courseplay:debug(string.format('[before] rotating headland lane=%d, closest=%d -> rotate: numPoints-(closest)=%d-(%d-1)=%d', i, closest, numPoints, closest, numPoints - (closest)), 7);
					local lane = table.rotate(lane, numPoints - (closest));
					--remove last points where distance to first point is under work width 
					if (i > 1 and i <= vehicle.cp.headland.numLanes) then
						local p3 = lane[1];
						local p4 = lane[2];
						--[[local searching = true;
						local idx = #prevLane;
						while searching do
							local crossing = courseplay:lineIntersection(prevLane[idx],prevLane[idx-1],p3,p4);
							if crossing.ip1 == 'TIP' then
								prevLane[idx].cx = crossing.cx;
								prevLane[idx].cz = crossing.cz;
								if crossing.ip2 == 'TIP' then
									table.remove(lane,1);
								end;
								break;
							end;
							table.remove(prevLane);
							idx = idx - 1;
							courseplay:debug(string.format('Last point remove on headlane %d / %d', i-1, vehicle.cp.headland.numLanes), 7);
						end;]]--
						local pointsInPrevLane = #prevLane
						local pointAngle = lane[1].angle;
						local prevAngle = prevLane[pointsInPrevLane].angle;	
						courseplay:debug(string.format('angles are (%.2f / %.2f)',prevAngle, pointAngle),7);
						 
						if self:arePerpendicular(pointAngle,prevAngle,20,true) then
							if orderCW then
								prevLane[pointsInPrevLane].turn = 'right90';
							else
								prevLane[pointsInPrevLane].turn = 'left90';
							end;
							prevLane[pointsInPrevLane].turnStart = true;
							lane[1].turnEnd = true;
						elseif self:areOpposit(pointAngle,prevAngle,45,true) then
							if orderCW then
								prevLane[pointsInPrevLane].turn = 'right';
							else
								prevLane[pointsInPrevLane].turn = 'left';
							end;
							prevLane[pointsInPrevLane].turnStart = true;
							lane[1].turnEnd = true;
						end;

						table.remove(lanes);
						table.insert(lanes,prevLane);
						
						if (i == vehicle.cp.headland.numLanes) and fieldWorkCourse then
							courseplay:debug(string.format('last direction is %.2f, field start direction is %.2f',math.deg(self:pointAngle(lane[numPoints-1],lane[numPoints])),fieldWorkCourse[1].angle),7);
							if self:near(math.deg(self:pointAngle(lane[numPoints-1],lane[numPoints])),fieldWorkCourse[1].angle, 5, 'deg') then --make a turn before starting lane
								courseplay:debug('turn at headland end',7);
								lane[numPoints].turnStart = true;
								turnAtHeadEnd = true;
								if vehicle.cp.headland.userDirClockwise then
									lane[numPoints].turn = 'right';
								else
									lane[numPoints].turn = 'left';
								end;
							elseif #fieldWorkCourse > 1 then
								local p3 = fieldWorkCourse[1];
								local p4 = fieldWorkCourse[2];
								local searching = true;
								local idx = #lane;
								while searching do
									local crossing = courseplay:lineIntersection(lane[idx],lane[idx-1],p3,p4);
									if crossing.ip1 == 'NFIP' then
										break;
									end;
									table.remove(lane);
									idx = idx - 1;
									courseplay:debug(string.format('Last point remove on last lane %d / %d', i, vehicle.cp.headland.numLanes), 7);
								end;
								local pointsInLane = #lane
								local points = {};
								points[1] = lane[pointsInLane-1];
								points[2] = lane[pointsInLane];
								points[3] = fieldWorkCourse[1];
								points[4] = fieldWorkCourse[2];
								local spline = courseplay.generation:smoothSpline(points,5);
								local splinePoints = #spline;
								for idx = 2, splinePoints -1 do --add all but first and last point
									table.insert(lane, spline[idx]);
									courseplay:debug(string.format('Spline point %d added',idx),7);
								end;

							end;
						end;
					elseif i == 1 then
						-- set start point on the field edge
						local edgeCrossing = courseplay:findCrossing(lane[3],lane[2], fieldEdge, 'PFIP');
						lane[1].cx = edgeCrossing.cx;
						lane[1].cz = edgeCrossing.cz;
					end;
					prevLane = lane;
					table.insert(lanes,lane);
				end;	
				vehicle.cp.headland.lanes = nil;
				vehicle.cp.headland.lanes = {};
				vehicle.cp.headland.lanes = lanes;
				
			else --each headland lanes' first point is closest to last fieldwork course point
				local lastFieldworkPoint = fieldWorkCourse[#(fieldWorkCourse)];
				--courseplay:debug(tableShow(lastFieldWorkPoint, 'lastFieldWorkPoint'), 7); --TODO: is nil - whyyyyy?
				local headlandLanes = {} ;
				for i=numHeadlandLanesCreated, 1, -1 do
					local lane = vehicle.cp.headland.lanes[i];
					local numPoints = #lane;
					local closest = self:getClosestPolyPoint(lane, lastFieldworkPoint.cx, lastFieldworkPoint.cz); --TODO: works, but how if lastFieldWorkPoint is nil???
					courseplay:debug(string.format('[after] rotating headland lane=%d, closest=%d -> rotate: numPoints-(closest-1)=%d-(%d-1)=%d', i, closest, numPoints, closest, numPoints - (closest-1)), 7);

					local tmpLane = table.rotate(lane, numPoints - (closest-1));
					if i == numHeadlandLanesCreated and self:near(self:pointAngle(lane[1],lane[2]) + 180,startPoint.angle, 5, 'deg') then
						--we will have to make a turn maneuver before entering headland
						tmpLane[1].turnEnd = true;
						turnAtHeadEnd = true;
					end;
					table.insert(headlandLanes, tmpLane);
				end;

				vehicle.cp.headland.lanes = nil;
				vehicle.cp.headland.lanes = {};
				vehicle.cp.headland.lanes = headlandLanes;
				--courseplay:debug(tableShow(vehicle.cp.headland.lanes, 'rotated headland lanes'), 7);
			end;
		end;
	end;
	---############################################################################
	-- (5.1) ADD TURN INFORMATION AT FIELDWORK BEGIN OR END IF NEEDED
	-------------------------------------------------------------------------------
	if turnAtHeadEnd then
		
		if vehicle.cp.headland.orderBefore then
			local point = fieldWorkCourse[1];
			point.turnEnd = true ;
			fieldWorkCourse[1] = point;
		else
			local point = fieldWorkCourse[#fieldWorkCourse];
			point.turnStart = true;
			if vehicle.cp.headland.userDirClockwise then
				point.turn = 'right';
			else
				point.turn = 'left';
			end;
			fieldWorkCourse[#fieldWorkCourse] = point;
		end;
	end;

	---############################################################################
	-- (6) CONCATENATE HEADLAND COURSE and FIELDWORK COURSE
	-------------------------------------------------------------------------------
	courseplay:debug('(6) CONCATENATE HEADLAND COURSE and FIELDWORK COURSE', 7);
	local lastFivePoints = {};
	if vehicle.cp.returnToFirstPoint then
		fieldWorkCourse[#fieldWorkCourse].wait = false;

		local srcCourse = fieldWorkCourse;
		if vehicle.cp.headland.numLanes and vehicle.cp.headland.numLanes > 0 and vehicle.cp.headland.orderBefore and #(vehicle.cp.headland.lanes) > 0 then
			srcCourse = vehicle.cp.headland.lanes[1];
			courseplay:debug(string.format('lastFivePoints: #headland.lanes=%d, headland.orderBefore=%s -> srcCourse = headland.lanes[1]', #(vehicle.cp.headland.lanes), tostring(vehicle.cp.headland.orderBefore)), 7);
		end;

		for b=5, 1, -1 do
			local origPathPoint = srcCourse[b];

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




	vehicle.Waypoints = {};

	if numHeadlandLanesCreated > 0 then
		if vehicle.cp.headland.orderBefore then
			for i=1, #(vehicle.cp.headland.lanes) do
				vehicle.Waypoints = tableConcat(vehicle.Waypoints, vehicle.cp.headland.lanes[i]);
			end;
			vehicle.Waypoints = tableConcat(vehicle.Waypoints, fieldWorkCourse);
		else
			vehicle.Waypoints = tableConcat(vehicle.Waypoints, fieldWorkCourse);
			for i=1, #(vehicle.cp.headland.lanes) do
				vehicle.Waypoints = tableConcat(vehicle.Waypoints, vehicle.cp.headland.lanes[i]);
			end;
		end;
	else
		vehicle.Waypoints = fieldWorkCourse;
	end;

	if #(lastFivePoints) > 0 then
		vehicle.Waypoints = tableConcat(vehicle.Waypoints, lastFivePoints);
	end;



	---############################################################################
	-- (7) FINAL COURSE DATA
	-------------------------------------------------------------------------------
	courseplay:debug('(7) FINAL COURSE DATA', 7);
	vehicle.maxnumber = #(vehicle.Waypoints)
	if vehicle.maxnumber == 0 then
		courseplay:debug('ERROR: #vehicle.Waypoints == 0 -> cancel and return', 7);
		return;
	end;

	vehicle.recordnumber = 1;
	vehicle.cp.canDrive = true;
	vehicle.Waypoints[1].wait = true;
	vehicle.Waypoints[1].crossing = true;
	vehicle.Waypoints[vehicle.maxnumber].wait = true;
	vehicle.Waypoints[vehicle.maxnumber].crossing = true;
	vehicle.cp.numCourses = 1;
	courseplay.signs:updateWaypointSigns(vehicle);

	vehicle.cp.hasGeneratedCourse = true;
	courseplay:setFieldEdgePath(vehicle, nil, 0);
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);

	courseplay:debug(string.format("generateCourse() finished: %d lanes, %d headland %s", numLanes, numHeadlandLanesCreated, numHeadlandLanesCreated == 1 and 'lane' or 'lanes'), 7);
end;


------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
-- ############# HELPER FUNCTIONS
function courseplay.generation:getPolyDimensions(polyXValues, polyZValues)
	local dimensions = {
		minX = math.min(unpack(polyXValues));
		maxX = math.max(unpack(polyXValues));
		minZ = math.min(unpack(polyZValues));
		maxZ = math.max(unpack(polyZValues));
	};
	dimensions.width = dimensions.maxX - dimensions.minX;
	dimensions.height = dimensions.maxZ - dimensions.minZ;

	return dimensions;
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

--[[
function courseplay:projectNewPoint(fromPointX, fromPointZ, dist, ang)
	local x = fromPointX + (dist * math.cos(Utils.degToRad(ang)));
	local z = fromPointZ + (dist * math.sin(Utils.degToRad(ang)));
	return x, z;
end;
]]

function courseplay.generation:lineIntersectsPoly(point1, point2, poly)
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

function courseplay:segmentsIntersection(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y, where) --@src: http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect#comment19248344_1968345
	if where == nil then
		where = 'segment';
	end;
	
	local s1_x = A2x - A1x;
	local s1_y = A2y - A1y;
	local s2_x = B2x - B1x;
	local s2_y = B2y - B1y;

	local denom = (-s2_x * s1_y + s1_x * s2_y);
	if math.abs(denom) > 0 then 
		local s = (-s1_y * (A1x - B1x) + s1_x * (A1y - B1y)) / denom; --concerns p3,p4
		local t = ( s2_x * (A1y - B1y) - s2_y * (A1x - B1x)) / denom; --concerns p1,p2
		if ((s >= 0 and s <= 1 and t >= 0 and t <= 1) and where == 'segment')
			or (s <= 0 and t >= 0 and where == 'between')
			or (s >= 0 and s <= 1 and t >= 0 and where == 'lineonsegment') then 
			--Collision detected
			--courseplay:debug(string.format('segInter ( %s, denom = %.4f, s = %.4f, t = %.4f )',where, denom, s, t), 7);
			local x = A1x + (t * s1_x);
			local z = A1y + (t * s1_y);
			return { x = x, z = z };
		end;
	end;
	--No collision
	return nil;
end;

--@src: https://github.com/ChubbRck/Cosmic-Crossfire/blob/master/mathlib.lua#L322
--NOTE: combined area check with 2 virtual offset points (1 on each side) 'in poly' check
function courseplay.generation:isPolyClockwise(poly)
	--offset test points
	local dirX,dirZ = self:getPointDirection(poly[1],poly[2]);
	local offsetRight = {
		cx = poly[2].cx - dirZ,
		cz = poly[2].cz + dirX,
		isInPoly = false
	};
	local offsetLeft = {
		cx = poly[2].cx + dirZ,
		cz = poly[2].cz - dirX,
		isInPoly = false
	};

	-- clockwise vs counterclockwise variables
	local area, success, tries = 0, false, 1;

	-- point in poly variables
	local numPoints = #poly;

	local cp, np, pp;
	local fp = poly[1];
	for i=1, numPoints do
		cp = poly[i];
		np = poly[i+1];
		pp = poly[i-1];
		if i == 1 then
			pp = poly[numPoints];
		end;

		-- clockwise vs counterclockwise
		if i < numPoints then
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

		-- offset right point in poly
		if ((cp.cz > offsetRight.cz) ~= (pp.cz > offsetRight.cz)) and (offsetRight.cx < (pp.cx - cp.cx) * (offsetRight.cz - cp.cz) / (pp.cz - cp.cz) + cp.cx) then
			offsetRight.isInPoly = not offsetRight.isInPoly;
		end;

		-- offset left point in poly
		if ((cp.cz > offsetLeft.cz)  ~= (pp.cz > offsetLeft.cz))  and (offsetLeft.cx  < (pp.cx - cp.cx) * (offsetLeft.cz  - cp.cz) / (pp.cz - cp.cz) + cp.cx) then
			offsetLeft.isInPoly = not offsetLeft.isInPoly;
		end;
	end;

	local isClockwise = area < 0;
	if isClockwise then
		courseplay:debug(string.format('isPolyClockwise(): isClockwise=%s, offsetRight.isInPoly=%s -> %s', tostring(isClockwise), tostring(offsetRight.isInPoly), offsetRight.isInPoly and 'match' or 'no match'), 7);
	else
		courseplay:debug(string.format('isPolyClockwise(): isClockwise=%s, offsetLeft.isInPoly=%s -> %s', tostring(isClockwise), tostring(offsetLeft.isInPoly), offsetLeft.isInPoly and 'match' or 'no match'), 7);
	end;

	return isClockwise;
end;

function courseplay.generation:getPointDirection(cp, np, useC)
	if useC == nil then useC = true; end;
	local x,z = 'x','z';
	if useC then
		x,z = 'cx','cz';
	end;

	local dx, dz = np[x] - cp[x], np[z] - cp[z];
	local vl = Utils.vector2Length(dx, dz);
	if vl and vl > 0.0001 then
		dx = dx / vl;
		dz = dz / vl;
	end;
	return dx, dz, vl;
end;

function courseplay.generation:getOffsetWidth(vehicle, laneNum)
	local w = vehicle.cp.workWidth;
	if laneNum == 1 then
		w = w/2;
	end;
	local noGoWidth = w * vehicle.cp.headland.noGoWidthRatio;
	return w, noGoWidth;
end;

function courseplay.generation:mirrorPoint(p1, p2, useC)
	--returns p1 mirrored at p2 
	if useC == nil then useC = true;  end;
	local x, z = 'x', 'z';
	if useC then
		x, z = 'cx', 'cz';
	end;
	local sp = {
		[x] = p2[x] + (p2[x] - p1[x]),
		[z] = p2[z] + (p2[z] - p1[z])
	} ;
	return sp;
end;

function courseplay.generation:pointAngle(p1,p2)
	return Utils.getYRotationFromDirection(p1.cx-p2.cx, p1.cz-p2.cz);
end;


-- @src: http://www.efg2.com/Lab/Graphics/Jean-YvesQueinecBezierCurves.htm
function courseplay.generation:smoothSpline(points, steps, useC, addHeight)
	if useC == nil then useC = true; end;
	if addHeight == nil then addHeight = false; end;

	local numPoints = #points;
	local steps = steps or 5;
	local spline = {};
	local p1, p2, p3, p4;
	local x,y,z = 'x','y','z';
	if useC then
		x,y,z = 'cx','cy','cz';
	end;
	
	p1, p2, p3, p4 = points[1], points[2], points[3], points[4];
	if numPoints == 3 then --  p3 mirrored on p2 is defined as reference
		p4 = p3;
		p3 = self:mirrorPoint(p3, p2, useC);
		p2 = p3;
	else
		local crossingPoint = courseplay:segmentsIntersection(p1[x], p1[z], p2[x], p2[z], p3[x], p3[z], p4[x], p4[z],'between');
		if crossingPoint then --crossing point is used as reference
			crossingPoint.cx, crossingPoint.cz = crossingPoint.x, crossingPoint.z;
			courseplay:debug(string.format('lines are crossing at : %.4f, %.4f', crossingPoint[x], crossingPoint[z]), 7);
			p1 = p2;
			p4 = p3;
			p2 = crossingPoint;
			p3 = p2;
		else
			local sP2, sP3 = p2, p3; -- p1 and p4 mirrored points are used as reference, p2, p3 as starting and ending points 
			p2 = self:mirrorPoint(p1, p2, useC);
			p3 = self:mirrorPoint(p4, p3, useC);
			p1 = sP2;
			p4 = sP3;
		end;
	end;
			
	for t = 0, 1, (1/steps) do
		local point = {
			[x] = math.pow(1-t, 3) * p1[x] + 3 * math.pow(1-t, 2) * t * p2[x] + 3 * (1-t) * t*t *  p3[x] + t*t*t * p4[x], 
			[z] = math.pow(1-t, 3) * p1[z] + 3 * math.pow(1-t, 2) * t * p2[z] + 3 * (1-t) * t*t *  p3[z] + t*t*t * p4[z],
			[y] = addHeight and getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, point[x], 1, point[z]) + 3 or nil
		};
		table.insert(spline, point);
		courseplay:debug(string.format('smoothSpline adding point : %.2f, %.2f', point[x], point[z]), 7);
	end;

	return spline;
end;


function courseplay.generation:getClosestPolyPoint(poly, x, z)
	local closestDistance = math.huge;
	local closestPointIndex;

	for i, point in pairs(poly) do
		local distanceToPoint = Utils.vector2Length(point.cx-x, point.cz-z);
		if distanceToPoint < closestDistance then
			closestDistance = distanceToPoint;
			closestPointIndex = i;
		end;
	end;
	return closestPointIndex;
end;
	
function courseplay.generation:near(v1, v2, tolerance,angle)

	--returns true if difference between v1 and v2 is under the tolerance value
	local areNear = false;
	if tolerance == nil then tolerance = 0.001 end;
	if angle then
		local angle1, angle2 = v1, v2;
		if angle == 'deg' then
			tolerance = math.rad(tolerance);
			angle1 = math.rad(angle1);
			angle2 = math.rad(angle2);
		end;
		tolerance = math.tan(tolerance);
		if math.abs(math.sin(angle1)-math.sin(angle2)) <= tolerance	and math.abs(math.cos(angle1)-math.cos(angle2)) <= tolerance then
			courseplay:debug(string.format('angle1 = %.4f and angle2 = %.4f are near', v1 ,v2 ), 7);
			areNear = true;
		end;
	elseif math.abs(v1 - v2) < tolerance then 
		courseplay:debug(string.format('v1 = %.4f and v2 = %.4f are near', v1 ,v2 ), 7);
		areNear = true;
	else
		courseplay:debug(string.format('v1 = %.4f and v2 = %.4f are not near', v1 ,v2 ), 7);
	end;
	return areNear;
end;

function courseplay.generation:arePerpendicular(angle1,angle2,tolerance,isDeg)
	if tolerance == nil then tolerance = 0 end;
	if isDeg then
		tolerance = math.rad(tolerance);
		angle1 = math.rad(angle1);
		angle2 = math.rad(angle2);
	end;
	tolerance = math.tan(tolerance);

	if math.abs(math.cos(angle1))-math.abs(math.sin(angle2)) <= tolerance and math.abs(math.sin(angle1))-math.abs(math.cos(angle2)) <= tolerance then
		courseplay:debug(string.format('a1 = %.4f and a2 = %.4f are perpendicular', angle1 ,angle2 ), 7);
		return true;
	end;
	return false;
end;

function courseplay.generation:areOpposit(angle1,angle2,tolerance,isDeg)
	if tolerance == nil then tolerance = 0 end;
	if isDeg then
		tolerance = math.rad(tolerance);
		angle1 = math.rad(angle1);
		angle2 = math.rad(angle2);
	end;
	tolerance = math.tan(tolerance);
	-- angles are opposit when cos angle1 = - cos angle2 and sin angle1 = sin angle2 
	if math.abs(math.cos(angle1)+math.cos(angle2)) <= tolerance	and math.abs(math.sin(angle1)+math.sin(angle2)) <= tolerance then 
		return true;
	end;
	return false;
end;

function courseplay:getNormal(p1,p2)
	local length = Utils.vector2Length(p1.cx-p2.cx, p1.cz-p2.cz);
	return {
		nx = (p2.cz-p1.cz) / length,
		nz = (p1.cx-p2.cx) / length
	};
end;

function courseplay:offsetPoint(point, normal, offset)
	local x = point.cx + (normal.nx * offset);
	local z = point.cz + (normal.nz * offset);
	--courseplay:debug(string.format(' point %.4f, %.4f offset to %.4f, %.4f', point.cx,point.cz,x,z),7);
	return {
		cx = x,
		cz = z
	};
end;

function courseplay:lineIntersection(p1, p2, p3, p4) --@src: http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect#comment19248344_1968345
--	courseplay:debug(string.format('/t/t%.4f,%.4f - %.4f,%.4f ',p1.cx,p1.cz,p2.cx,p2.cz),7);
--	courseplay:debug(string.format('/t/t%.4f,%.4f - %.4f,%.4f ',p3.cx,p3.cz,p4.cx,p4.cz),7);
	local s1_x, s1_y, s2_x, s2_y, x, z;
	s1_x = p2.cx - p1.cx;
	s1_y = p2.cz - p1.cz;
	s2_x = p4.cx - p3.cx;
	s2_y = p4.cz - p3.cz;
	
	local denom = (-s2_x * s1_y + s1_x * s2_y);
	local pos1, pos2 = 'NO', 'NO';
	if denom ~= 0 then
		local s = (-s1_y * (p1.cx - p3.cx) + s1_x * (p1.cz - p3.cz)) / denom; -- on p3-p4
		local t = ( s2_x * (p1.cz - p3.cz) - s2_y * (p1.cx - p3.cx)) / denom; -- on p1-p2

		x = p1.cx + (t * s1_x);
		z = p1.cz + (t * s1_y);
		if (s >= 0 and s <= 1) then
			pos2 = 'TIP';
		elseif s > 1 then
			pos2 = 'PFIP';
		else 
			pos2 = 'NFIP';
		end;
		if (t >= 0 and t <= 1) then
			pos1 ='TIP';
		elseif t > 1 then
			pos1 = 'PFIP';
		else 
			pos1 = 'NFIP';
		end;
		--courseplay:debug(string.format('lineCrossing -> %.2f, %.2f - %s - %s',x,z,pos1,pos2),7);
	end;
	return {
		cx = x,
		cz = z,
		ip1 = pos1,
		ip2 = pos2
	};
end;

function courseplay:appendArc(points, center, radius, startPoint, endPoint)
	radius = math.abs(radius);
	local twoPi = math.pi*2;
	local startAngle = math.atan2(startPoint.cz- center.cz, startPoint.cx - center.cx);
	local endAngle = math.atan2(endPoint.cz - center.cz, endPoint.cx - center.cx);
	if startAngle < 0 then
		startAngle = startAngle + twoPi;
	end;
	if endAngle < 0 then
		endAngle = endAngle + twoPi;
	end;
	local angle;
	if startAngle > endAngle then
		angle = startAngle - endAngle;
	else
		angle = startAngle + twoPi - endAngle;
	end;
	local arcSegmentCount = angle * radius / 5;
	local arcAngle = -angle / arcSegmentCount;
	courseplay:debug(string.format('angle is %2.f, %.2f points in arc',math.deg(angle),arcSegmentCount),7);
	table.insert(points, startPoint);
	for i = 1, arcSegmentCount do
		local angle = startAngle + arcAngle * i;
		local point = {
			cx = center.cx + math.cos(angle) * radius,
			cz = center.cz + math.sin(angle) * radius
		};
		table.insert(points, point);
	end;
	table.insert(points, endPoint);
	return points;
end;

function courseplay:untrimmedOffsetPline(pline, offset)
	local idx, numPoints = 1, #pline;
	table.insert(pline, pline[1]);
	local offPline = {};
	local prevP1, prevP2;
	while idx <= numPoints do
		local p1, p2 = pline[idx], pline[idx+1];
		local normal = courseplay:getNormal(p1, p2);
		p1 = courseplay:offsetPoint(p1, normal, offset);
		p2 = courseplay:offsetPoint(p2, normal, offset);
		if idx > 1 then
			local crossing = courseplay:lineIntersection(prevP1, prevP2, p1, p2);
			if (crossing.ip1 == 'TIP' and crossing.ip2 == 'TIP') then
				table.insert(offPline, crossing);	
			elseif crossing.ip1 == 'PFIP' and crossing.ip2 == 'NFIP' then
				offPline = courseplay:appendArc(offPline, pline[idx], offset, prevP2, p1);
			end;
		else
			table.insert(offPline, p1);
		end;
		prevP1, prevP2 = p1, p2;
		idx = idx + 1;
	end;
	if courseplay:keepPoint(prevP2, pline, offset) then
		table.insert(offPline, prevP2);
	end;
	courseplay:debug(string.format('point %.2f, %.2f added',prevP2.cx, prevP2.cz),7);
	courseplay:debug(string.format('Untrimmed offset finished with %d points', #offPline),7);
	return offPline; 
end;

function courseplay:pointDistToLine(point,linePoint1,linePoint2)
	local segLength = Utils.vector2Length(linePoint1.cx-linePoint2.cx,linePoint1.cz-linePoint2.cz);
	local dist;
	local t = math.huge;
	if segLenth == 0 then
		dist = Utils.vector2Length(linePoint1.cx - point.cx,linePoint1.cz - point.cz);
	else
		t = ((point.cx - linePoint1.cx) * (linePoint2.cx - linePoint1.cx) + (point.cz - linePoint1.cz) * (linePoint2.cz - linePoint1.cz) ) / (segLength * segLength);
		if t < 0 then
			dist = Utils.vector2Length(linePoint1.cx - point.cx,linePoint1.cz - point.cz);
		elseif t > 1 then
			dist = Utils.vector2Length(linePoint2.cx - point.cx,linePoint2.cz - point.cz);
		else
			local x = linePoint1.cx + t * (linePoint2.cx - linePoint1.cx);
			local z = linePoint1.cz + t * (linePoint2.cz - linePoint1.cz);
			dist = Utils.vector2Length(point.cx - x, point.cz - z);
		end;
	end;
	return dist, (t >= 0 and t <= 1);
end;

function courseplay:cleanPline(pline,boundingPline,offset,vehicle)
	local minPointDistance = 0.5;
	local maxPointDistance = 5;
	courseplay:debug('CLEANPLINE',7);
	local newPline = {};
	local numPoints = #pline;
	table.insert(pline,pline[1]);
	courseplay:debug(string.format('Searching selfintersections on %d seg' , numPoints),7);
	local idx1 = 1;
	while idx1 <= numPoints do
		local p1 = pline[idx1];
		local p2 = pline[idx1+1];
		table.insert(newPline, p1);
		for idx2 = 1 , numPoints do
			if idx2 - 1 < idx1 or idx1 < idx2 + 1 then
				local p3 = pline[idx2];
				local p4 = pline[idx2+1];
				crossing = courseplay:lineIntersection(p1, p2, p3, p4);
				if crossing.ip2 == 'TIP' and crossing.ip1 == 'TIP' then
					table.insert(newPline, crossing);
					courseplay:debug(string.format(' crossing point after %d (%.10f,%.10f) added',idx1,crossing.cx, crossing.cz),7);
					break;
				end;
			end;
		end;
		idx1 = idx1 + 1;
	end;
	pline = {};
	savedPoints = 0;
	local prevPoint = false;
	local prevAngle = false;
	table.insert(newPline,newPline[1]);
	local numPoints = #newPline;
	for i, point in ipairs(newPline) do
		if courseplay:keepPoint(point, boundingPline, offset) then
			if not prevPoint then
				table.insert(pline,point);
				savedPoints = savedPoints + 1;
				courseplay:debug(string.format('point %d saved as %d',i, savedPoints),7);
			else
				local segLength = Utils.vector2Length(point.cx - prevPoint.cx, point.cz - prevPoint.cz);
				local curAngle = courseplay.generation:pointAngle(point,prevPoint);
				courseplay:debug(string.format('%d (%.2f,%.2f) -> %d (%.2f m) angle = %.2f',i,point.cx,point.cz,savedPoints,segLength, curAngle),7);
				if segLength > minPointDistance and segLength <= maxPointDistance then
					table.insert(pline,point);
					savedPoints = savedPoints + 1;
					courseplay:debug(string.format('point %d saved as %d',i, savedPoints),7);
				elseif segLength > maxPointDistance then
					local steps = math.ceil(segLength / maxPointDistance);
					local points = {};
					points[1] = pline[savedPoints - 1];
					points[2] = prevPoint;
					points[3] = point;
					points[4] = i == numPoints and pline[2] or newPline[i+1];
					if savedPoints == 1 then
						for idx = 1, 3 do
							points[idx] = points[idx+1];
						end;
						points[4] = nil;
					end;
					local spline = courseplay.generation:smoothSpline(points,steps);
					local splinePoints = #spline;
					for idx = 2, splinePoints do --add all but first ( prevPoint )
						table.insert(pline, spline[idx]);
						savedPoints = savedPoints + 1;
						courseplay:debug(string.format('Spline point %d saved as %d',idx, savedPoints),7);
					end;
				end;
				prevAngle = curAngle;
			end;
			prevPoint = point;
		end;
	end;
	table.remove(pline);
	return pline;			
end;	

function courseplay:minDistToPline(point, pline)
	local numPoints = #pline;
	table.insert(pline,pline[1]);
	local pointInPline = -1;
	local minDist = math.huge;
	for i=1, numPoints do
		local cp = pline[i];
		local np = pline[i+1];
		pointInPline = pointInPline * courseplay.utils:crossProductQuery(point, cp, np, true);
		local dist, useIt = courseplay:pointDistToLine(point,cp,np);
		if dist < minDist then
			minDist = dist;
		end;
	end;
	pointInPline = pointInPline ~= -1 ;
	courseplay:debug(string.format('Point at %.4f InPoly = %s', minDist, tostring(pointInPline)),7);
	return minDist, pointInPline;
end;

function courseplay:keepPoint(point, pline, offset)
	local dist, inPline = courseplay:minDistToPline(point, pline);
	local keep = inPline and (courseplay:round(math.abs(offset),5) <= courseplay:round(dist,5));
	courseplay:debug(string.format(' dist = %.8f offset = %.8f keep = %s ', dist,offset, tostring(keep)),7);
	return keep;
end;

function courseplay:offsetPoly(pline, offset, vehicle)
	local pline1 = courseplay:untrimmedOffsetPline(pline, offset);
	pline1 = courseplay:cleanPline(pline1, pline, offset, vehicle);
	return pline1;
end;

function courseplay:findCrossing(p1,p2, poly, where)
	where = where or 'TIP';
	local numPoints = #poly;
	table.insert(poly, poly[1]);
	for i = 1, numPoints do
		local crossing = courseplay:lineIntersection(p1, p2, poly[i], poly[i+1]);
		if crossing.ip1 == where and crossing.ip2 == 'TIP' then
			return crossing;
		end;
	end;
end;

