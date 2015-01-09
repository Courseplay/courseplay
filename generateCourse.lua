--[[
@title:     Course Generation for Courseplay
@authors:   Jakob Tischler
@version:   0.71
@date:      09 Feb 2013

@coaothors: Fck54 (Franck Champlon)
@updated:   02 dec 2015

@copyright: No reproduction, usage or copying without the explicit permission by the author allowed.
]]--

function courseplay:generateCourse(vehicle)
	local self = courseplay.generation;

	-----------------------------------
	if not vehicle.cp.overlap then vehicle.cp.overlap = 1/4 end; --TODO add this in the menu
	if not vehicle.cp.minPointDistance then vehicle.cp.minPointDistance = .5 end;
	if not vehicle.cp.maxPointDistance then vehicle.cp.maxPointDistance = 5 end;

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

	local field={} ;
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		field = courseplay.utils.table.copy(courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points, true);
	else
		field = courseplay.utils.table.copy(vehicle.Waypoints, true);
	end;
	if not(self:isPolyClockwise(field)) then
		field = table.reverse(field);
	end;

	local pointsInField = #(field);
	local polyPoints = field;

	courseplay:debug(string.format('before headland: field = %s,  pointsInField = %d', tostring(field), pointsInField), 7);

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
	local orderCW = vehicle.cp.headland.userDirClockwise;
	local numLanes = vehicle.cp.headland.numLanes;
	local turnAround = numLanes > 5;
	local numHeadlanes ;

	---#################################################################
	-- (2) HEADLAND
	--------------------------------------------------------------------
	courseplay:debug('(2) HEADLAND', 7);

	if numLanes and numLanes > 0 then --we have headland, baby!

		courseplay:debug(string.format("generateCourse(%i): headland.numLanes=%s, headland.orderBefore=%s, turnAround = %s", debug.getinfo(1).currentline, tostring(vehicle.cp.headland.numLanes), tostring(vehicle.cp.headland.orderBefore), tostring(turnAround)), 7);

		vehicle.cp.headland.lanes = {};
		local offsetWidth = 0;
		local curLane = 1;

		while curLane <= numLanes or turnAround do

			-- set ridge marker side --
			local laneRidgeMarker = ridgeMarker.none;
			if numLanes > 1 then
				if vehicle.cp.headland.orderBefore and curLane < numLanes then
					laneRidgeMarker = orderCW and ridgeMarker.right or ridgeMarker.left;
				elseif not vehicle.cp.headland.orderBefore and curLane > 1 then
					laneRidgeMarker = orderCW and ridgeMarker.left or ridgeMarker.right;
				end;
			end;

			local offsetWidth = self:getOffsetWidth(vehicle, curLane);

			courseplay:debug(string.format('headland lane %d: laneRidgeMarker=%d, offset offsetWidth=%.1f', curLane, laneRidgeMarker, offsetWidth), 7);

			-- --------------------------------------------------
			-- (2.1) CREATE INITIAL OFFSET POINTS
			courseplay:debug('(2.1) CREATE INITIAL OFFSET POINTS', 7);
			local lane = courseplay:offsetPoly(polyPoints, -offsetWidth, vehicle);
			polyPoints = courseplay.utils.table.copy(lane,true); -- save result for next lane and field lanes calculation.
			if not(orderCW) then -- offset pline is always clockwise.
				lane = table.reverse(lane);
			end;

			-- --------------------------------------------------
			-- (2.2) FINALIZE (ADD POINT DATA)
			local numOffsetPoints, data = #lane, {};
			if numOffsetPoints > 2 then
				for i, point in ipairs(lane) do
					if i < numOffsetPoints then
						point.angle = courseplay.generation:signAngleDeg(point,lane[i+1]);
					else
						point.angle = courseplay.generation:signAngleDeg(point,lane[1]);
					end;
					if i > 1 then
						courseplay:debug(string.format('headland - lane %d (data.angle = %s, point.angle = %s)', curLane, tostring(data.angle), tostring(point.angle)),7);
					end;
					data = {
						cx = point.cx,
						cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, point.cx, 1, point.cz), --TODO: actually only needed for debugPoint/debugLine
						cz = point.cz,
						angle = point.angle,
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
				end;

				courseplay:debug(string.format("generateCourse(%i): #lane %s = %s", debug.getinfo(1).currentline, tostring(curLane), tostring(numOffsetPoints)), 7);
				--courseplay:debug(tableShow(lane, string.format('[line %d] lane %d', debug.getinfo(1).currentline, curLane), 7), 7); -- WORKS

				-- --------------------------------------------------
				-- (2.3) FINALIZE (ADD LANE TO HEADLAND)
				table.insert(vehicle.cp.headland.lanes, lane);
				courseplay:debug(string.format("generateCourse(%i): inserting lane #%d (%d points) into headland.lanes", debug.getinfo(1).currentline, curLane, numOffsetPoints), 7);
				-- courseplay:debug(tableShow(lane, string.format('[line %d] lane %d', debug.getinfo(1).currentline, curLane), 7), 7); --WORKS
				curLane = curLane + 1;
			else
				courseplay:debug(string.format('headland lane #%d has fewer than 2 points (invalid) -> stop headland calculation', curLane), 7);
				turnAround = true;
				break;
			end;
		end; --END while curLane in numLanes


		numHeadlanes = #(vehicle.cp.headland.lanes);
		courseplay:debug(string.format('generateCourse(%i):  #vehicle.cp.headland.lanes=%s', debug.getinfo(1).currentline, tostring(numHeadlanes)), 7);
		-- courseplay:debug(tableShow(vehicle.cp.headland.lanes, 'vehicle.cp.headland.lanes', 7), 7); --WORKS

		-- --------------------------------------------------
		-- (2.4) SETTING FIELD WORK COURSE BASE
		if numHeadlanes > 0 and not(turnAround) then
			if vehicle.cp.overlap ~= 0 then
				offsetWidth = self:getOffsetWidth(vehicle, numHeadlanes + 1);
				offsetWidth = (offsetWidth / 2) * (1 - vehicle.cp.overlap);
				polyPoints = courseplay:offsetPoly(polyPoints, -offsetWidth);
			end;
			numPoints = #(polyPoints);
			courseplay:debug(string.format('headland: numHeadlanes=%d, workArea has %s points', numHeadlanes, tostring(numPoints)), 7);
		end;

	end; --END if vehicle.cp.headland.numLanes ~= 0


	---#################################################################
	-- (3) DIMENSIONS, ALL PATH POINTS
	--------------------------------------------------------------------
	local StartPoint = {};

	------------------------------------------------------------------
	-- (3.1) DEF POINT IN FIELD CORNER FOR TURN AROUND
	-------------------------------------------------------------------
	-- (3.2) SETTING FIELD WORK COURSE BASE
	courseplay:debug('(3) DIMENSIONS, ALL PATH POINTS', 7);

	local fieldWorkCourse, fieldPoints = {}, {};

	local dimensions = courseplay.generation:getPolyDimensions(field);
	courseplay:debug(string.format('minX=%s, maxX=%s', tostring(dimensions.minX), tostring(dimensions.maxX)), 7); --WORKS
	courseplay:debug(string.format('minZ=%s, maxZ=%s', tostring(dimensions.minZ), tostring(dimensions.maxZ)), 7); --WORKS
	courseplay:debug(string.format('generateCourse(%i): width=%s, height=%s', debug.getinfo(1).currentline, tostring(dimensions.width), tostring(dimensions.height)), 7); --WORKS

	local numLanes, pointsPerLane = 0, 0;
	local curLaneDir = '';
	local pointDistance = 5;
	local pipSafety = 0.1;
	local pathPoints = {};

	if dir == "N" or dir == "S" then --North or South
		numLanes = math.ceil(dimensions.width / workWidth);
		pointsPerLane = math.ceil(dimensions.height / pointDistance);
		if (numLanes * workWidth) < dimensions.width then
			numLanes = numLanes + 1;
		end;
		courseplay:debug(string.format('generateCourse(%i): numLanes=%s, pointsPerLane=%s', debug.getinfo(1).currentline, tostring(numLanes), tostring(pointsPerLane)), 7); --WORKS

		local gotALane = false;
		for curLane=1, numLanes do
			--Lane directions
			if gotALane then
				if curLaneDir == "N" then
					curLaneDir = "S";
				else
					curLaneDir = "N";
				end;
			else
				curLaneDir = dir;
			end;
			courseplay:debug(string.format("curLane = %d, curLaneDir = %s", curLane, curLaneDir), 7); --WORKS

			for a=1, pointsPerLane do
				local curPoint = {
					num = a + ((curLane-1) * pointsPerLane),
					lane = curLane,
					laneDir = curLaneDir,
					cx = dimensions.minX + (workWidth * curLane) - (workWidth/2),
					cz = dimensions.minZ
				};

				if crn == "NW" or crn == "SW" then
					if curLaneDir == "S" then
						curPoint.ridgeMarker = ridgeMarker["left"];
					else
						curPoint.ridgeMarker = ridgeMarker["right"];
					end;
				elseif crn == "SE" or crn == "NE" then
					if curLaneDir == "S" then
						curPoint.ridgeMarker = ridgeMarker["right"];
					else
						curPoint.ridgeMarker = ridgeMarker["left"];
					end;
				end;

				if crn == "NE" or crn == "SE" then
					curPoint.cx = dimensions.maxX - (workWidth * curLane) + (workWidth/2);
				end;

				if curLaneDir == "S" then
					curPoint.cz = dimensions.minZ + (pointDistance * (a-1));

					if curPoint.cz >= dimensions.maxZ then
						curPoint.cz = dimensions.maxZ - pipSafety;
					end;
				elseif curLaneDir == "N" then
					curPoint.cz = dimensions.maxZ - (pointDistance * (a-1));

					if curPoint.cz <= dimensions.minZ then
						curPoint.cz = dimensions.minZ + pipSafety;
					end;
				end;

				--last lane
				curPoint.cx = Utils.clamp(curPoint.cx, dimensions.minX + (workWidth/2), dimensions.maxX - (workWidth/2));

				--is point in field?
				local _, pointInPoly = courseplay:minDistToPline(curPoint, polyPoints);
				if pointInPoly then
					courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.cx, curPoint.cz), 7);
					table.insert(pathPoints, curPoint);
					gotALane = true;
				else
					courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.cx, curPoint.cz), 7);
				end;
				_, pointInPoly = courseplay:minDistToPline(curPoint, field);
				if pointInPoly then
				    table.insert(fieldPoints, curPoint);
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

		local gotALane = false;
		for curLane=1, numLanes do
			--Lane directions
			if gotALane then
				if curLaneDir == "E" then
					curLaneDir = "W";
				else
					curLaneDir = "E";
				end;
			else
				curLaneDir = dir;
			end;

			courseplay:debug(string.format("curLane = %d, curLaneDir = %s", curLane, curLaneDir), 7); --WORKS

			for a=1, pointsPerLane do
				local curPoint = {
					num = a + ((curLane-1) * pointsPerLane),
					lane = curLane,
					laneDir = curLaneDir,
					cx = dimensions.minX,
					cz = dimensions.minZ + (workWidth * curLane) - (workWidth/2)
				};

				if crn == "SW" or crn == "SE" then
					if curLaneDir == "E" then
						curPoint.ridgeMarker = ridgeMarker["left"];
					else
						curPoint.ridgeMarker = ridgeMarker["right"];
					end;
				elseif crn == "NE" or crn == "NW" then
					if curLaneDir == "E" then
						curPoint.ridgeMarker = ridgeMarker["right"];
					else
						curPoint.ridgeMarker = ridgeMarker["left"];
					end;
				end;

				if crn == "SW" or crn == "SE" then
					curPoint.cz = dimensions.maxZ - (workWidth * curLane) + (workWidth/2);
				end;

				if curLaneDir == "E" then
					curPoint.cx = dimensions.minX + (pointDistance * (a-1));

					if curPoint.cx >= dimensions.maxX then
						curPoint.cx = dimensions.maxX - pipSafety;
					end;
				elseif curLaneDir == "W" then
					curPoint.cx = dimensions.maxX - (pointDistance * (a-1));

					if curPoint.cx <= dimensions.minX then
						curPoint.cx = dimensions.minX + pipSafety;
					end;
				end;

				--last lane
				curPoint.z = Utils.clamp(curPoint.cz, dimensions.minZ + (workWidth/2), dimensions.maxZ - (workWidth/2));

				--is point in field?
				local _, pointInPoly = courseplay:minDistToPline(curPoint, polyPoints);
				if pointInPoly then
					courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - in Poly - adding to pathPoints", curPoint.num, curLane, a, curPoint.cx, curPoint.cz), 7);
					table.insert(pathPoints, curPoint);
					gotALane = true;
				else
					courseplay:debug(string.format("Point %d (lane %d, point %d) - x=%.1f, z=%.1f - not in Poly - not adding to pathPoints", curPoint.num, curLane, a, curPoint.cx, curPoint.cz), 7);
				end;
				_, pointInPoly = courseplay:minDistToPline(curPoint, field);
				if pointInPoly then
				    table.insert(fieldPoints, curPoint);
				end;


			end; --END for curPoint in pointsPerLane
		end; --END for curLane in numLanes
	end; --END East or West

	---############################################################################
	-- (4) CHECK PATH LANES FOR VALID START AND END POINTS and FILL fieldWorkCourse
	-------------------------------------------------------------------------------
	courseplay:debug('(4) CHECK PATH LANES FOR VALID START AND END POINTS and FILL fieldWorkCourse', 7);
	local numPoints = #pathPoints;

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
			angleDeg     = math.deg(math.atan2(np.cz - cp.cz, np.cx - cp.cx));
			signAngleDeg = math.deg(math.atan2(np.cx - cp.cx, np.cz - cp.cz));
		else
			angleDeg     = math.deg(math.atan2(cp.cz - pp.cz, cp.cx - pp.cx));
			signAngleDeg = math.deg(math.atan2(cp.cx - pp.cx, cp.cz - pp.cz));
		end;

		if cp.firstInLane or i == 1 or isLastLane then
			cp.ridgeMarker = 0;
		end;

		local point = {
			cx = cp.cx,
			cz = cp.cz,
			angle = angleDeg,
			wait = nil, --will be set to true for first and last after all is set and done
			rev = nil,
			crossing = nil,
			lane = cp.lane,
			laneDir = cp.laneDir,
			turnStart = courseplay:trueOrNil(cp.lastInLane and cp.lane < numLanes),
			turnEnd = courseplay:trueOrNil(cp.firstInLane and i > 1),
			ridgeMarker = cp.ridgeMarker,
			generated = true
		};

		local newFirstInLane, newLastInLane;

		--TURN MANEUVER ... AND STUFF
		if cp.firstInLane then
			newFirstInLane = courseplay:findCrossing(np, cp, polyPoints, "PFIP"); -- search the intersection point before cp

			if newFirstInLane ~= nil then
				--courseplay:debug(string.format("lane %d: newFirstInLane: x=%f, z=%f", cp.lane, newFirstInLane.x, newFirstInLane.z), 7);

				newFirstInLane.angle = point.angle;
				newFirstInLane.wait = point.wait;
				newFirstInLane.crossing = point.crossing;
				newFirstInLane.rev = point.rev;
				newFirstInLane.lane = point.lane;
				newFirstInLane.laneDir = point.laneDir;
				newFirstInLane.firstInLane = true;
				newFirstInLane.turn = point.turn;
				newFirstInLane.turnStart = nil;
				newFirstInLane.turnEnd = courseplay:trueOrNil(i > 1);
				newFirstInLane.ridgeMarker = 0;
				newFirstInLane.generated = true;

				--reset some vars in old first point
				point.wait = nil;
				point.firstInLane = false;
				point.turn = nil;
				point.turnStart = nil;
				point.turnEnd = nil;
			end;
		end; --END cp.firstInLane

		if cp.lastInLane then

			--North
			if cp.laneDir == "N" then
				if np.cx < cp.cx then point.turn = "left" end;
				if np.cx > cp.cx then point.turn = "right" end;

			--East
			elseif cp.laneDir == "E" then
				if np.cz < cp.cz then point.turn = "left" end;
				if np.cz > cp.cz then point.turn = "right" end;

			--South
			elseif cp.laneDir == "S" then
				if np.cx < cp.cx then point.turn = "right" end;
				if np.cx > cp.cx then point.turn = "left" end;

			--West
			elseif cp.laneDir == "W" then
				if np.cz < cp.cz then point.turn = "right" end;
				if np.cz > cp.cz then point.turn = "left" end;
			end;
			--courseplay:debug("--------------------------------------------------------------------", 7);
			--courseplay:debug(string.format("laneDir=%s, point.turn=%s", cp.laneDir, tostring(point.turn)), 7);
			if i == numPoints then
				point.turn = nil;
			end;

			angleDeg = courseplay:positiveAngleDeg(angleDeg);

			newLastInLane = courseplay:findCrossing(pp, cp, polyPoints, "PFIP");

			if newLastInLane ~= nil then
				--courseplay:debug(string.format("newLastInLane: x=%f, z=%f", newLastInLane.x, newLastInLane.z), 7);
				newLastInLane.angle = point.angle;
				newLastInLane.wait = point.wait;
				newLastInLane.crossing = point.crossing;
				newLastInLane.rev = point.rev;
				newLastInLane.lane = point.lane;
				newLastInLane.laneDir = point.laneDir;
				newLastInLane.lastInLane = true;
				newLastInLane.turn = point.turn;
				newLastInLane.turnStart = courseplay:trueOrNil(i < numPoints);
				newLastInLane.turnEnd = nil;
				newLastInLane.ridgeMarker = 0;
				newLastInLane.generated = true;

				point.wait = nil;
				point.lastInLane = false;
				point.turn = nil;
				point.turnStart = nil;
				point.turnEnd = nil;

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

	if vehicle.cp.startingCorner == 0 then -- start on nearest point to vehicle ; TO BE ADDED TO HUD.
		local cx, _, cz = getWorldTranslation(vehicle.rootNode);
		local starIdx = self:getClosestPolyPoint(vehicle.cp.headland.lanes[1], cx, cz);
		startPoint = vehicle.cp.headland.lanes[startIdx];
	else

		startPoint = fieldPoints[1];
	end;

	---############################################################################
	-- (5) ROTATE HEADLAND COURSES
	-------------------------------------------------------------------------------
	courseplay:debug('(5) ROTATE HEADLAND COURSES', 7);
	if vehicle.cp.headland.numLanes > 0 then
		courseplay:debug(string.format('[before] rotating headland, number of lanes = %d', numHeadlanes),7);
		if numHeadlanes > 0 then
			-- -------------------------------------------------------------------------
			-- (5.1) ROTATE AND LINK HEADLAND LANES
			if vehicle.cp.headland.orderBefore then --each headland lane 's first point is closest to corresponding field begin point or previous lane end point
				local lanes = {};
				local prevLane = {};
				for i,lane in ipairs(vehicle.cp.headland.lanes) do
					local numPoints = #lane;
					courseplay:debug(string.format('curent lane has %d points',numPoints),7);
					local closest = self:getClosestPolyPoint(lane, startPoint.cx, startPoint.cz);
					courseplay:debug(string.format('closest point on lane is : %s (%.2f, %.2f)', tostring(closest), lane[closest].cx, lane[closest].cz), 7);
					courseplay:debug(string.format('[before] rotating headland lane=%d, closest=%d -> rotate: numPoints-(closest)=%d-(%d-1)=%d', i, closest, numPoints, closest, numPoints - (closest-1)), 7);
				    if orderCW then
				        lane = table.rotate(lane, numPoints - (closest - 1));
				    else
				        lane = table.rotate(lane, numPoints - closest -1);
				    end
					if i > 1 and orderCW then -- link lanes
						local p3 = lane[1];
						local p4 = lane[2];
						local idx = #prevLane;
						local p1, p2 = prevLane[idx-1], prevLane[idx];
						local crossing;
						if self:areOpposit(p4.angle,p1.angle,10,true) then
						    crossing = courseplay:lineIntersection(p1,p2,prevLane[1],prevLane[2]);
						    lane[1].turnEnd = true;
						    prevLane[idx].turnStart = true;
						    prevLane[idx].turn = orderCW and 'right' or 'left';
						else
        					if i < numHeadlanes then
        					    table.remove(lane);
        					    numPoints = numPoints - 1;
        					end;
    						crossing = courseplay:lineIntersection(p1, p2, p3, p4);
    						while crossing.ip1 == 'TIP' or crossing.ip1 == 'NFIP' do
    							table.remove(prevLane);
    							idx = idx - 1;
    							p1, p2 = prevLane[idx-1], prevLane[idx];
    							crossing = courseplay:lineIntersection(p1, p2, p3, p4);
    						end;
							prevLane[idx].cx = crossing.cx;
							prevLane[idx].cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, crossing.cx, 1, crossing.cz)
							prevLane[idx].cz = crossing.cz;
    					end;
						table.remove(lanes);
						table.insert(lanes,prevLane);
						numPoints = #lane;
						startPoint = lane[1];
					elseif i > 1 then
						local p3 = lane[1];
						local p4 = lane[2];
						local idx = #prevLane;
						local p1, p2 = prevLane[idx-1], prevLane[idx];
						local crossing;
						if i < numHeadlanes then
							table.remove(lane);
							numPoints = numPoints - 1;
						end;
						crossing = courseplay:lineIntersection(p1, p2, p3, p4);
						while crossing.ip1 == 'TIP' or crossing.ip1 == 'NFIP' do
							table.remove(prevLane);
							idx = idx - 1;
							p1, p2 = prevLane[idx-1], prevLane[idx];
							crossing = courseplay:lineIntersection(p1, p2, p3, p4);
						end;
						table.remove(lanes);
						table.insert(lanes,prevLane);
						numPoints = #lane;
						startPoint = lane[1];

					end;
					if i == numHeadlanes and not(turnAround) then -- last headlane link to first fieldWorkCourse point
						courseplay:debug(string.format('last direction is %.2f, field start direction is %.2f',lane[numPoints].angle,fieldWorkCourse[1].angle),7);
						if courseplay.generation:areOpposit(lane[numPoints].angle,fieldWorkCourse[1].angle,20,true) then
							local data = lane[numPoints];
							data.cx = (dir == "N" or dir == "S") and lane[numPoints].cx or fieldWorkCourse[1].cx;
							data.cz = (dir == "E" or dir == "W") and lane[numPoints].cz or fieldWorkCourse[1].cz;
							data.turnStart = true;
							data.turn = orderCW and 'right' or 'left';
							lane[numPoints] = data ;
							fieldWorkCourse[1].turnEnd = true;
						else
							local crossing = courseplay:lineIntersection(lane[numPoints-1],lane[numPoints],fieldWorkCourse[1],fieldWorkCourse[2]);
							while crossing.ip1 == 'TIP' or crossing.ip1 == 'NFIP' do
								table.remove(lane);
								numPoints = numPoints - 1;
								crossing = courseplay:lineIntersection(lane[numPoints-1],lane[numPoints],fieldWorkCourse[1],fieldWorkCourse[2]);
							end;
							local p1,p2,p3,p4 = lane[numPoints-1],lane[numPoints],fieldWorkCourse[1],fieldWorkCourse[2]
							local dist = Utils.vector2Length(p2.cx-p3.cx,p2.cz-p3.cz);
							if dist > 2 then
								local spline = courseplay.generation:smoothSpline(p1, p2, p3, p4, dist/2);
								local data = {};
								for i, point in pairs(spline) do
									if  i < #spline then
										point.angle = courseplay.generation:signAngleDeg(point,spline[i+1]);
									else
										point.angle = data.angle;
									end;
									data = {
										cx = point.cx,
										cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, point.cx, 1, point.cz), --TODO: actually only needed for debugPoint/debugLine
										cz = point.cz,
										angle = point.angle,
										wait = false,
										rev = false,
										crossing = false,
										generated = true,
										lane = p2.lane, --negative lane = headland
										-- cp.firstInLane = false;
										turn = nil,
										turnStart = false,
										turnEnd = false,
										ridgeMarker = 0
										};
									spline[i] = data;
								end;
								lane = courseplay:appendPoly(lane, spline, false, false);
							end;
						end;
					end;
					if i == 1 then
						-- set start point on the field edge
						local newStart = courseplay:findCrossing(lane[3],lane[2], field, 'PFIP');
						if orderCW then
						    startPoint = lane[2];
						else
						    startPoint = lane[1];
						end;
						lane[1].cx = newStart.cx;
						lane[1].cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newStart.cx, 1, newStart.cz)
						lane[1].cz = newStart.cz;
					end;
					prevLane = lane;
					table.insert(lanes,lane);
				end;
				vehicle.cp.headland.lanes = nil;
				vehicle.cp.headland.lanes = {};
				vehicle.cp.headland.lanes = lanes;

			elseif #fieldWorkCourse and not vehicle.cp.headland.orderBefore then --each headland lanes' first point is closest to last fieldwork course point
				local lastFieldworkPoint = fieldWorkCourse[#fieldWorkCourse];
				--courseplay:debug(tableShow(lastFieldworkPoint, 'lastFieldworkPoint'), 7); --TODO: is nil - whyyyyy?
				local headlandLanes = {} ;
				for i = numHeadlanes, 1, -1 do
					local lane = vehicle.cp.headland.lanes[i];
					table.remove(lane);
					local numPoints = #lane;
					local closest = self:getClosestPolyPoint(lane, lastFieldworkPoint.cx, lastFieldworkPoint.cz); --TODO: works, but how if lastFieldWorkPoint is nil???
					courseplay:debug(string.format('[after] rotating headland lane=%d, closest=%d -> rotate: numPoints-(closest-1)=%d-(%d-1)=%d', i, closest, numPoints, closest, numPoints - (closest-1)), 7);

					lane = table.rotate(lane, numPoints - (closest+1));
					if i == numHeadlandLanesCreated and self:near(self:pointAngle(lane[1],lane[2]) + 180,lastFieldworkPoint.angle, 5, 'deg') then
						--we will have to make a turn maneuver before entering headland
						tmpLane[1].turnEnd = true;
					end;
					lastFieldWorkPoint = lane[numPoints];
					table.insert(headlandLanes, lane);
				end;

				vehicle.cp.headland.lanes = nil;
				vehicle.cp.headland.lanes = {};
				vehicle.cp.headland.lanes = headlandLanes;
				--courseplay:debug(tableShow(vehicle.cp.headland.lanes, 'rotated headland lanes'), 7);
			end;
		end;
	end;

	---############################################################################
	-- (7) CONCATENATE HEADLAND COURSE and FIELDWORK COURSE
	-------------------------------------------------------------------------------
	courseplay:debug('(7) CONCATENATE HEADLAND COURSE and FIELDWORK COURSE', 7);

	vehicle.Waypoints = {};

	if vehicle.cp.headland.numLanes > 0 then
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
	local returnToStart = {};
	if vehicle.cp.returnToFirstPoint then
		vehicle.maxnumber = #(vehicle.Waypoints);
		vehicle.Waypoints[vehicle.maxnumber].wait = false;

		local p1 = vehicle.Waypoints[vehicle.maxnumber-1];
		local p2 = vehicle.Waypoints[vehicle.maxnumber];
		if not turnAround then
		    p1 = vehicle.Waypoints[vehicle.maxnumber-1];
		    p2 = vehicle.Waypoints[vehicle.maxnumber-2];
		end
		local p3 = vehicle.Waypoints[2];
		local p4 = vehicle.Waypoints[1];
		local dist = Utils.vector2Length(p2.cx-p3.cx,p2.cz-p3.cz);
		returnToStart = courseplay.generation:smoothSpline(p1, p2, p3, p4, dist/vehicle.cp.maxPointDistance);
		table.remove(returnToStart, 1);
		local data = {};
		for i, point in pairs(returnToStart) do
			if  i < #returnToStart then
				point.angle = courseplay.generation:signAngleDeg(point,returnToStart[i+1]);
			else
				point.angle = data.angle;
			end;
			data = {
				cx = point.cx,
				cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, point.cx, 1, point.cz), --TODO: actually only needed for debugPoint/debugLine
				cz = point.cz,
				angle = point.angle,
				wait = false,
				rev = false,
				crossing = false,
				generated = true,
				lane = p2.lane, --negative lane = headland
				-- cp.firstInLane = false;
				turn = nil,
				turnStart = false,
				turnEnd = false,
				ridgeMarker = 0
				};
			returnToStart[i] = data;
		end;
		p4.angle = courseplay:invertAngleDeg(p4.angle);
		table.insert(returnToStart,p4);

		-- local srcCourse = fieldWorkCourse;
		-- if vehicle.cp.headland.numLanes and vehicle.cp.headland.numLanes > 0 and vehicle.cp.headland.orderBefore and #(vehicle.cp.headland.lanes) > 0 then
			-- srcCourse = vehicle.cp.headland.lanes[1];
			-- courseplay:debug(string.format('lastFivePoints: #headland.lanes=%d, headland.orderBefore=%s -> srcCourse = headland.lanes[1]', #(vehicle.cp.headland.lanes), tostring(vehicle.cp.headland.orderBefore)), 7);
		-- end;

		-- for b=5, 1, -1 do
			-- local origPathPoint = srcCourse[b];

			-- local point = {
				-- cx = origPathPoint.cx,
				-- cz = origPathPoint.cz,
				-- angle = courseplay:invertAngleDeg(origPathPoint.angle),
				-- wait = false, --b == 1,
				-- rev = false,
				-- crossing = false,
				-- lane = 1,
				-- turnStart = false,
				-- turnEnd = false,
				-- ridgeMarker = 0,
				-- generated = true
			-- };
			-- table.insert(lastFivePoints, point);
		-- end;
	end;

	if #(returnToStart) > 0 then
		vehicle.Waypoints = tableConcat(vehicle.Waypoints, returnToStart);
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
	courseplay:debug(string.format("generateCourse() finished: %d lanes, %d headland", numLanes, #(vehicle.cp.headland.lanes)), 7);

end;


------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
-- ############# HELPER FUNCTIONS
-- function courseplay.generation:getPolyDimensions(polyXValues, polyZValues)
	-- local dimensions = {
		-- minX = math.min(unpack(polyXValues));
		-- maxX = math.max(unpack(polyXValues));
		-- minZ = math.min(unpack(polyZValues));
		-- maxZ = math.max(unpack(polyZValues));
	-- };
	-- dimensions.width = dimensions.maxX - dimensions.minX;
	-- dimensions.height = dimensions.maxZ - dimensions.minZ;

	-- return dimensions;
-- end;

function courseplay.generation:getPolyDimensions(poly)
	local dimensions = {
		minX = math.huge,
		maxX = -math.huge,
		minZ = math.huge,
		maxZ = -math.huge
	};
	for _, point in pairs(poly) do
		if point.cx < dimensions.minX then
			dimensions.minX = point.cx;
		end;
		if point.cx > dimensions.maxX then
			dimensions.maxX = point.cx;
		end;
		if point.cz < dimensions.minZ then
			dimensions.minZ = point.cz;
		end;
		if point.cz > dimensions.maxZ then
			dimensions.maxZ = point.cz;
		end;
	end;
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

function courseplay.generation:angleDeg(p1,p2)
	return math.deg(math.atan2(p2.cz-p1.cz, p2.cx-p1.cx));
end;

function courseplay.generation:signAngleDeg(p1,p2)
	return math.deg(math.atan2(p2.cx-p1.cx, p2.cz-p1.cz));
end;

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
	return w;
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

-- @src: http://www.efg2.com/Lab/Graphics/Jean-YvesQueinecBezierCurves.htm
function courseplay.generation:smoothSpline(refPoint1, startPoint, endPoint , refPoint2 , steps, useC, addHeight)
	if useC == nil then useC = true; end;
	if addHeight == nil then addHeight = false; end;

	local steps = steps or 5;
	local spline = {};
	local x,y,z = 'x','y','z';
	if useC then
		x,y,z = 'cx','cy','cz';
	end;
	local p1,p2,p3,p4;
	if refPoint1 or RefPoint2 then
		p1 = startPoint;
		p4 = endPoint;
		if refPoint1 and refPoint2 then
			local crossingPoint = courseplay:lineIntersection(refPoint1, startPoint, endPoint, refPoint2);
			if crossingPoint.ip1 == 'PFIP' and crossingPoint.ip2 == 'NFIP' then -- crossing point is used as reference
				crossingPoint.x, crossingPoint.z = crossingPoint.cx, crossingPoint.cz;
				courseplay:debug(string.format('lines are crossing at : %.4f, %.4f', crossingPoint[x], crossingPoint[z]), 7);
				p2 = crossingPoint;
				p3 = crossingPoint;
			else
				p2 = self:mirrorPoint(refPoint1, startPoint, useC);
				p3 = self:mirrorPoint(refPoint2, endPoint, useC);
			end;
		else
			if refPoint1 then
				p3 = self:mirrorPoint(refPoint1, startPoint, useC);
				p2 = p3;
			else
				p2 = self:mirrorPoint(refPoint2, endPoint, useC);
				p3 = p2;
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
	else
		table.insert(spline,startPoint);
		table.insert(spline,endPoint);
	end;
	return spline;
end;

function courseplay:appendPoly(poly1 ,poly2 ,withStart, withEnd) -- appends poly1 to poly2 with without start and end points of poly2
	local startidx = withStart and 1 or 2;
	local endidx = withend and #poly2 or #poly2 - 1;
	for idx = startidx, endidx do --add all but first and last point
		table.insert(poly1, poly2[idx]);
	end;
	return poly1;
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
	if tolerance == nil then tolerance = 0 end;
	if angle then
		local angle1, angle2 = v1, v2;
		if angle == 'deg' then
			tolerance = math.rad(tolerance);
			angle1 = math.rad(angle1);
			angle2 = math.rad(angle2);
		end;
		if math.abs(math.sin(angle1)-math.sin(angle2)) <= math.sin(tolerance) and math.abs(math.cos(angle1)-math.cos(angle2)) <= math.cos(tolerance) then
			--courseplay:debug(string.format('angle1 = %.4f and angle2 = %.4f are near', v1 ,v2 ), 7);
			areNear = true;
		end;
	elseif math.abs(v1 - v2) <= tolerance then
		--courseplay:debug(string.format('v1 = %.4f and v2 = %.4f are near', v1 ,v2 ), 7);
		areNear = true;
	else
		--courseplay:debug(string.format('v1 = %.4f and v2 = %.4f are not near', v1 ,v2 ), 7);
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
		--courseplay:debug(string.format('a1 = %.4f and a2 = %.4f are perpendicular', angle1 ,angle2 ), 7);
		return true;
	end;
	return false;
end;

function courseplay.generation:areOpposit(angle1,angle2,tolerance,isDeg)
	if tolerance == nil then tolerance = 0 end;
	if isDeg then
		angle1 = angle1 < 0 and angle1+360 or angle1;
		angle2 = angle2 < 0 and angle2+360 or angle2;
	else
		angle1 = angle1 < 0 and angle1+(math.pi*2) or angle1;
		angle2 = angle2 < 0 and angle2+(math.pi*2) or angle2;
	end;
	local diff = angle1 < angle2 and angle2 - angle1 or angle1 - angle2;
	diff = isDeg and 180 - diff or math.pi - diff;
	courseplay:debug(string.format('[areOpposit] angle1 = %.2f, angle2 = %.2f -> %s',angle1,angle2,tostring(diff<=tolerance)),7);
	return diff <= tolerance;
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
	local pos1, pos2, onEnd = 'NO', 'NO', false;
	if denom ~= 0 then
		local s = (-s1_y * (p1.cx - p3.cx) + s1_x * (p1.cz - p3.cz)) / denom; -- on p3-p4
		local t = ( s2_x * (p1.cz - p3.cz) - s2_y * (p1.cx - p3.cx)) / denom; -- on p1-p2

		x = p1.cx + (t * s1_x);
		z = p1.cz + (t * s1_y);
		onEnd = s==1 or s==0 or t==0 or t==1;
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
		courseplay:debug(string.format('lineCrossing -> %.2f, %.2f - %s - %s',x,z,pos1,pos2),7);
	end;
	return {
		cx = x,
		cz = z,
		ip1 = pos1,
		ip2 = pos2,
		notOnEnds = not(onEnd)
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
	table.insert(pline,pline[1]);
	local numPoints = #pline;
	local offPline = {};
	for idx1 = 1, numPoints do
		local idx2 = idx1 == numPoints and 1 or idx1 + 1;
		local idx3 = idx2 == numPoints and 1 or idx2 + 1;
		local normal = courseplay:getNormal(pline[idx1], pline[idx2]);
		local s1p1 = courseplay:offsetPoint(pline[idx1], normal, offset);
		local s1p2 = courseplay:offsetPoint(pline[idx2], normal, offset);
		normal = courseplay:getNormal(pline[idx2], pline[idx3]);
		local s2p1 = courseplay:offsetPoint(pline[idx2], normal, offset);
		local s2p2 = courseplay:offsetPoint(pline[idx3], normal, offset);
		local crossing = courseplay:lineIntersection(s1p1, s1p2, s2p1, s2p2);
		if idx1 == numPoints - 1 then
			table.insert(offPline, s1p2);
		elseif crossing.ip1 == 'TIP' and crossing.ip2 == 'TIP' then
			table.insert(offPline, crossing);
		elseif crossing.ip1 == 'PFIP' and crossing.ip2 == 'NFIP' then
			table.insert(offPline, crossing);
		else
			table.insert(offPline, s1p2);
			table.insert(offPline, s2p1);
		end;
	end;
	courseplay:debug(string.format('Untrimmed offset finished with %d points', #offPline),7);
	table.remove(pline);
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

function courseplay.generation:samePoints(p1,p2)
	return p1.cx == p2.cx and p1.cz == p2.cz;
end;

function courseplay:cleanPline(pline,boundingPline,offset,vehicle)
	local minPointDistance = 0.5;
	local maxPointDistance = 5;
	courseplay:debug('CLEANPLINE',7);
	local newPline, pointsInNewPline = {}, 0;
	table.insert(pline,pline[1]);
	local numPoints = #pline;
	for idx1 = 1, numPoints - 1 do
		local p1 = pline[idx1];
		if p1.cx == p1.cx and p1.cz == p1.cz then --taking away "nan" points
			local idx2 = idx1 + 1;
			--courseplay:debug(string.format('Searching selfintersections after point %d  ' , idx1),7);
			local p2 = pline[idx2];
			if idx2 == numPoints then
				if #newPline > 0 then
					p2 = newPline[1];
				else
					break;
				end;
			end;

			local keep1 = courseplay:keepPoint(p1, boundingPline, offset);
			local keep2 = courseplay:keepPoint(p2, boundingPline, offset);
			if (keep1 and keep2) and Utils.vector2Length(p1.cx-p2.cx,p1.cz-p2.cz) > .1 then
				table.insert(newPline,pline[idx1]);
				pointsInNewPline = pointsInNewPline + 1;
			elseif keep1 or keep2 then --courseplay:debug('Crossing to be found',7);
				for idx3 = 2 , numPoints - 1 do
					local idx4 = idx3 + 1;
					local crossing = courseplay:lineIntersection(p1, p2, pline[idx3], pline[idx4]);
					if (crossing.ip1 == 'TIP' and crossing.ip2 == 'TIP') and crossing.notOnEnds then
						if keep1 then
							table.insert(newPline,p1);
							pointsInNewPline = pointsInNewPline + 1;
							if courseplay:keepPoint(crossing, boundingPline, offset) then
								table.insert(newPline,crossing);
								pointsInNewPline = pointsInNewPline + 1;
							end;
						elseif pointsInNewPline >0 then
							if Utils.vector2Length(newPline[pointsInNewPline].cx-crossing.cx,newPline[pointsInNewPline].cz-crossing.cz) > .1 and courseplay:keepPoint(crossing, boundingPline, offset) then
								table.insert(newPline,crossing);
								pointsInNewPline = pointsInNewPline + 1;
							end;
						elseif courseplay:keepPoint(crossing, boundingPline, offset) then
							table.insert(newPline,crossing);
							pointsInNewPline = pointsInNewPline + 1;
						end;
					end;
				end;
			end;
		end;
	end;
	table.remove(pline);
	newPline = courseplay.generation:refinePoly(newPline, maxPointDistance);
	return newPline;
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
		local dist, _ = courseplay:pointDistToLine(point,cp,np);
		if dist < minDist then
			minDist = dist;
		end;
	end;
	pointInPline = pointInPline ~= -1 ;
	courseplay:debug(string.format('Point at %.4f InPoly = %s', minDist, tostring(pointInPline)),7);
	table.remove(pline);
	return minDist, pointInPline;
end;

function courseplay:keepPoint(point, pline, offset)
	local dist, inPline = courseplay:minDistToPline(point, pline);
	local keep = inPline and (courseplay:round(dist,5) >= courseplay:round(math.abs(offset),5)) ;
	courseplay:debug(string.format(' dist = %.8f offset = %.8f keep = %s ', courseplay:round(dist,5),courseplay:round(offset,5), tostring(keep)),7);
	return keep;
end;

function courseplay:offsetPoly(pline, offset, vehicle)
	local pline1 = courseplay:untrimmedOffsetPline(pline, offset);
	pline1 = courseplay:cleanPline(pline1, pline, offset, vehicle);
	return pline1;
end;

function courseplay:findCrossing(p1,p2, poly, where)
	if where == nil then where = 'TIP' end;
	local numPoints = #poly;
	table.insert(poly, poly[1]);
	local i, found = 0, false;
	local crossing = {};
	while not(found) and i < numPoints do
		i = i + 1;
		crossing = courseplay:lineIntersection(p1, p2, poly[i], poly[i+1]);
		if (crossing.ip1 == where and crossing.ip2 == 'TIP') then
			found = true;
		end;
	end;
	table.remove(poly);
	if found then
	    return crossing;
	else
	    return false;
	end;
end;

function courseplay.generation:refinePoly(poly, maxDistance)
	local pointsInPline = #poly;
	local newPline = {};
	for idx = 1, pointsInPline do
		local idxPrev = idx - 1 ;
		if idx == 1 then
			idxPrev = pointsInPline;
		end;
		local idxNext = idx + 1 ;
		if idx == pointsInPline then
			idxNext = 1;
		end;
		local idxNext2 = idxNext + 1 ;
		if idxNext == pointsInPline then
			idxNext2 = 1;
		end;
		local p1, p2, p3, p4 = poly[idxPrev], poly[idx], poly[idxNext], poly[idxNext2];
		if Utils.vector2Length(p2.cx - p3.cx, p2.cz - p3.cz) > maxDistance then
			local spline = courseplay.generation:smoothSpline(p1, p2, p3, p4, Utils.vector2Length(p2.cx - p3.cx, p2.cz - p3.cz)/maxDistance);
			newPline = courseplay:appendPoly(newPline, spline, true, false);
		else
			table.insert(newPline,p2);
		end;
	end;
	return newPline;
end;
