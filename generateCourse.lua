--[[
@title:     Course Generation for Courseplay
@authors:   Jakob Tischler
@version:   0.71
@date:      09 Feb 2013
@updated:   27 Feb 2014

@copyright: No reproduction, usage or copying without the explicit permission by the author allowed.
]]



function courseplay:generateCourse(vehicle)
	local self = courseplay.generation;
	-----------------------------------

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

	local poly = {}
	local islandNodes = {}
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		poly.points = courseplay.utils.table.copy(courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points, true);
		poly.numPoints = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].numPoints;
		if vehicle.cp.islandBypassMode ~= Island.BYPASS_MODE_NONE then
			if not courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].islandNodes then
				courseGenerator.findIslands( courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum])
			end
			islandNodes = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].islandNodes
		end
	else
		poly.points = courseplay.utils.table.copy(vehicle.Waypoints, true);
		poly.numPoints = #(poly.points);
	end;

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
	if vehicle.cp.multiTools > 1 then
		workWidth = workWidth * vehicle.cp.multiTools
	end

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

	-- Automatic direction selected so use the algorithm that can generate lanes in any direction
	if vehicle.cp.isNewCourseGenSelected() then
		if vehicle.cp.startingCorner == courseGenerator.STARTING_LOCATION_VEHICLE_POSITION then
			vehicle.cp.generationPosition.x, _, vehicle.cp.generationPosition.z = getWorldTranslation(vehicle.rootNode)
			vehicle.cp.generationPosition.hasSavedPosition = true
			--vehicle.cp.generationPosition.fieldNum = vehicle.cp.fieldEdge.selectedField.fieldNum
			vehicle:setCpVar('generationPosition.fieldNum',vehicle.cp.fieldEdge.selectedField.fieldNum,courseplay.isClient)
		end
		courseGenerator.generate( vehicle, fieldCourseName, poly, workWidth, islandNodes )
		return
	end

  -- Otherwise, revert to the N/E/S/W directions

	---#################################################################
	-- (2) HEADLAND
	--------------------------------------------------------------------
	courseplay:debug('(2) HEADLAND', 7);
	if vehicle.cp.headland.numLanes and vehicle.cp.headland.numLanes > 0 then --we have headland, baby!
		local isClockwise = self:isPolyClockwise(poly.points);
		courseplay:debug(string.format('headland: poly isClockwise=%s', tostring(isClockwise)), 7);
		if isClockwise ~= vehicle.cp.headland.userDirClockwise then
			courseplay:debug(string.format('\tuserDirClockwise=%s -> reverse poly.points', tostring(vehicle.cp.headland.userDirClockwise)), 7);
			poly.points = table.reverse(poly.points);
		end;

		courseplay:debug(string.format("generateCourse(%i): headland.numLanes=%s, headland.orderBefore=%s", debug.getinfo(1).currentline, tostring(vehicle.cp.headland.numLanes), tostring(vehicle.cp.headland.orderBefore)), 7);


		local orderCW = vehicle.cp.headland.userDirClockwise;
		local numLanes = vehicle.cp.headland.numLanes;
		local polyPoints = poly.points;
		local polyLength = poly.numPoints;

		vehicle.cp.headland.lanes = {};

		for curLane=1, numLanes do
			local lane = {};
			-- polyLength = #(polyPoints); --TODO: try to use count in loop
			local numOffsetPoints = 0;

			local laneRidgeMarker = ridgeMarker.none;
			if numLanes > 1 then
				if vehicle.cp.headland.orderBefore and curLane < numLanes then
					laneRidgeMarker = orderCW and ridgeMarker.right or ridgeMarker.left;
				elseif not vehicle.cp.headland.orderBefore and curLane > 1 then
					laneRidgeMarker = orderCW and ridgeMarker.left or ridgeMarker.right;
				end;
			end;

			local offsetWidth, noGoWidth = self:getOffsetWidth(vehicle, curLane,workWidth);
			courseplay:debug(string.format('headland lane %d: laneRidgeMarker=%d, offset offsetWidth=%.1f, noGoWidth=%.2f', curLane, laneRidgeMarker, offsetWidth, noGoWidth), 7);

			-- --------------------------------------------------
			-- (2.1) CREATE INITIAL OFFSET POINTS
			courseplay:debug('(2.1) CREATE INITIAL OFFSET POINTS', 7);

			for i,cp in pairs(polyPoints) do
				local np = polyPoints[i + 1];
				local pp = polyPoints[i - 1];
				if i == 1 then
					pp = polyPoints[polyLength];
				elseif i == polyLength then
					np = polyPoints[1];
				end;

				local insert = true;

				cp.dirX, cp.dirZ, cp.distToNextPoint = self:getPointDirection(cp, np);
				cp.cy = cp.cy or 0;

				-- last point: distance to first point -> try to decrease angle when jumping into next lane;
				if i == polyLength then
					local minDistance = offsetWidth; -- * 3/4;
					if cp.distToNextPoint < minDistance then
						insert = false;
					end;
				end;

				local offsetX,offsetZ;
				if insert then
					local dirX,dirZ,vl = self:getPointDirection(pp, cp);
					-- courseplay:debug(string.format('\tpoint %d: cp.cx,cz=%.1f,%.1f, pp.cx,cz=%.1f,%.1f -> dirX,dirZ=%.1f,%.1f, vl=%.1f', i, cp.cx,cp.cz, pp.cx,pp.cz, dirX,dirZ, vl), 7);
					if vl and vl > 0.0001 then
						if orderCW then --offset to the right
							offsetX = cp.cx - dirZ * offsetWidth;
							offsetZ = cp.cz + dirX * offsetWidth;
							-- courseplay:debug(string.format('\t\toffsetX=cp.cx - dirZ * workWidth=%.1f - %.1f * %.1f = %.1f', cp.cx,dirZ, offsetWidth, offsetX), 7);
							-- courseplay:debug(string.format('\t\toffsetZ=cp.cz + dirX * workWidth=%.1f + %.1f * %.1f = %.1f', cp.cz,dirX, offsetWidth, offsetZ), 7);
						else --offset to the left
							offsetX = cp.cx + dirZ * offsetWidth;
							offsetZ = cp.cz - dirX * offsetWidth;
							-- courseplay:debug(string.format('\t\toffsetX=cp.cx + dirZ * workWidth=%.1f + %.1f * %.1f = %.1f', cp.cx,dirZ, offsetWidth, offsetX), 7);
							-- courseplay:debug(string.format('\t\toffsetZ=cp.cz - dirX * workWidth=%.1f - %.1f * %.1f = %.1f', cp.cz,dirX, offsetWidth, offsetZ), 7);
						end;

						-- check intersection with previous offset vector
						if numOffsetPoints > 0 then
							local prevOffsP = lane[numOffsetPoints];
							if courseplay:segmentsIntersection(cp.cx, cp.cz, offsetX, offsetZ, pp.cx, pp.cz, prevOffsP.cx, prevOffsP.cz) then
								courseplay:debug(string.format('\tpoint %d: intersection with previous offset vector -> skip this point', i), 7);
								insert = false;
							end;
						end;
					end;
				end; --END if insert

				if insert and offsetX and offsetZ then
					local data = {
						cx = offsetX,
						cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, offsetX, 1, offsetZ), --TODO: actually only needed for debugPoint/debugLine
						cz = offsetZ,
						origPointIdx = i,
						offsetLane = curLane
					};
					table.insert(lane, data);
					numOffsetPoints = numOffsetPoints + 1;
				end;
			end; --END for i,cp in pairs(polyPoints)

			-- check intersections for first offset vector
			if numOffsetPoints > 0 then
				local op1 = lane[1];
				local p1 = polyPoints[op1.origPointIdx];
				local op2 = lane[numOffsetPoints]; 
				local p2 = polyPoints[op2.origPointIdx];
				if courseplay:segmentsIntersection(p1.cx, p1.cz, op1.cx, op1.cz, p2.cx, p2.cz, op2.cx, op2.cz) then
					courseplay:debug('\tpoint 1: intersection with previous offset vector -> skip this point', 7);
					table.remove(lane, 1);
					numOffsetPoints = numOffsetPoints - 1;
				end;
			end;

			courseplay:debug(string.format("generateCourse(%i): #lane %s = %s", debug.getinfo(1).currentline, tostring(curLane), tostring(numOffsetPoints)), 7);
			-- courseplay:debug(tableShow(lane, string.format('[line %d] lane %d', debug.getinfo(1).currentline, curLane), 7), 7); -- WORKS


			-- --------------------------------------------------
			-- (2.2) CHECK AND DELETE OVERLAPS
			courseplay:debug('(2.2) CHECK AND DELETE OVERLAPS', 7);

			local toBeDeleted = {};
			for i,offsP in pairs(lane) do
				if not offsP.toBeDeleted then
					local checkOverlap = true;

					-- (2.2.1) check intersections
					local previousDeleted = false;
					local p1, p2, p3, p4 = lane[i - 2], lane[i - 1], lane[i + 1], lane[i + 2];

					if p1 and p2 and p3 and p4 then
						local intersect = courseplay:segmentsIntersection(p1.cx, p1.cz, p2.cx, p2.cz, p3.cx, p3.cz, p4.cx, p4.cz);
						if intersect then
							local newPoint = { cx = intersect.x, cy = 0, cz = intersect.z, offsetLane = curLane };
							-- newPoint.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, intersect.x, 1, intersect.z); --TODO: needed for anything else than debugPoint/debugLine?
							newPoint.dirX,newPoint.dirZ = self:getPointDirection(offsP, p3);

							courseplay:debug(string.format('\tintersection found (%d-%d and %d-%d): x,y,z=%.1f,%.1f,%.1f', i - 2, i - 1, i + 1, i + 2, newPoint.cx, newPoint.cy, newPoint.cz), 7);
							table.insert(toBeDeleted, i - 1);
							lane[i] = newPoint;
							offsP = newPoint;
							table.insert(toBeDeleted, i + 1);
							lane[i + 1].toBeDeleted = true;
							courseplay:debug(string.format('\tdelete %d and %d, set intersection as new point %d, skip checking overlap', i - 1, i + 1, i), 7);
							previousDeleted = true;
							checkOverlap = false;
						end;
					end;

					-- (2.2.2) check overlap -- TODO: include pointInPoly check in the while loop
					if checkOverlap then
						local checkNum = i;
						local swingDir = 1;
						local count = 0;

						while true do
							count = count + 1;
							if count > polyLength then
								break;
							end;

							local cp = polyPoints[checkNum];

							--set and rotate tg
							setTranslation(vehicle.cp.headland.tg, cp.cx, cp.cy, cp.cz);
							local rot = Utils.getYRotationFromDirection(cp.dirX, cp.dirZ);
							setRotation(vehicle.cp.headland.tg, 0, rot, 0);
							-- courseplay:debug(string.format('\ttg setTranslation(%s, [x] %.1f, [y] %.1f, [z] %.1f), setRotation() [y] %.1f', tostring(vehicle.cp.headland.tg), cp.cx, cp.cy, cp.cz, rot), 7);

							-- check overlap
							local dx,dy,dz = worldToLocal(vehicle.cp.headland.tg, offsP.cx, offsP.cy, offsP.cz);
							local overlap = dx > -noGoWidth and dx < noGoWidth and dz > 0 and dz < cp.distToNextPoint * vehicle.cp.headland.rectWidthRatio;
							if overlap then
								courseplay:debug(string.format('\toffset point %d: OVERLAP!', i), 7);
								courseplay:debug(string.format('\t\tcount=%d, swingDir=%d, checkNum=%d', count, swingDir, checkNum), 7);
								courseplay:debug(string.format('\t\tdx,dy,dz=%.1f,%.1f,%.1f', dx,dy,dz), 7);
								-- courseplay:debug(string.format('\t\tdx > -noGoWidth = %s // dx < noGoWidth = %s // dz > 0 = %s, dz < cp.distToNextPoint * vehicle.cp.headland.rectWidthRatio = %s', tostring(dx > -noGoWidth), tostring(dx < noGoWidth), tostring(dz > 0), tostring(dz < cp.distToNextPoint * vehicle.cp.headland.rectWidthRatio)), 7);

								table.insert(toBeDeleted, i);
								break;
							else
								-- courseplay:debug(string.format('\t\tNO OVERLAP! --> new checkNum = %d + (%d * %d) = %d', checkNum, count, swingDir, checkNum + (count * swingDir)), 7);
								checkNum = checkNum + (count * swingDir);
								--rudimentary looped table
								if checkNum < 1 then
									checkNum = polyLength - math.abs(checkNum);
									-- courseplay:debug(string.format('\t\t\tcheckNum < 1 --> checkNum = %d', checkNum), 7);
								elseif checkNum > polyLength then
									checkNum = checkNum - polyLength;
									-- courseplay:debug(string.format('\t\t\tcheckNum > numPoints --> checkNum = %d', checkNum), 7);
								end;

								swingDir = swingDir * -1;
							end;
						end; --END while true
					end; --END if checkOverlap
				end; --END if not offsP.toBeDeleted
			end;

			for i,offsPointNum in pairs(toBeDeleted) do
				lane[offsPointNum] = nil;
				-- numOffsetPoints = table.maxn(lane);
				numOffsetPoints = numOffsetPoints - 1;
				courseplay:debug(string.format('delete offset point(%d) -> new numOffsetPoints=%d', offsPointNum, numOffsetPoints), 7);
			end;
			-- courseplay:debug(tableShow(lane, string.format('[line %d] lane %d', debug.getinfo(1).currentline, curLane), 7), 7); --WORKS


			-- --------------------------------------------------
			-- (2.3) CHECK AND FIX DISTANCES
			courseplay:debug('(2.3) CHECK AND FIX DISTANCES', 7);

			local finalPoints = {};
			local pointsInserted = 0;
			for i,offsP in pairs(lane) do
				local insertCurrent = true;

				local np1Idx, np1 = next(lane, i);
				local pp = finalPoints[pointsInserted - 1];
				if np1 then
					local dist = Utils.vector2Length(np1.cx - offsP.cx, np1.cz - offsP.cz);
					-- courseplay:debug(string.format('\t%d: dist to next=%.1f', i, dist), 7);

					-- check min distance, if less: delete cur point
					if dist < vehicle.cp.headland.minPointDistance then
						courseplay:debug(string.format('\tpoint %d: distance to next [%d] = %.1f (< minDistance %.1f) -> delete cur point', i, np1Idx, dist, vehicle.cp.headland.minPointDistance), 7);
						insertCurrent = false;

					-- check max distance, if more: smooth spline (add points)
					elseif dist > vehicle.cp.headland.maxPointDistance then
						local np2Idx, np2 = next(lane, np1Idx);
						if np2 and pp then
							insertCurrent = false;
							-- courseplay:debug(string.format('\tinsert point %d into "finalPoints"', i), 7);
							table.insert(finalPoints, offsP);
							pointsInserted = pointsInserted + 1;

							local steps = math.ceil(dist/5);
							courseplay:debug(string.format('\tpoint %d: distance to next [%d] = %.1f -> smooth with %d steps', i, np1Idx, dist, steps), 7);
							courseplay:debug(string.format('\twith points { pp [%.1f/%.1f], offsP [%.1f/%.1f], np1 [%.1f/%.1f], np2 [%.1f/%.1f] }', pp.cx, pp.cz, offsP.cx, offsP.cz, np1.cx, np1.cz, np2.cx, np2.cz), 7);
							local smoothed = self:smoothSpline({ pp, offsP, np1, np2 }, steps, true);
							for j, smoothPoint in pairs(smoothed) do
								if j > steps + 1 and j <= steps + steps then --NOTE: smoothSpline's return includes the initial points, so they have to be skipped
									-- smoothPoint.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, smoothPoint.cx, 1, smoothPoint.cz); --TODO: only needed for debugPoint/debugLine ?
									if courseplay:round(finalPoints[#finalPoints].cx,4) == courseplay:round(smoothPoint.cx,4) and 
									courseplay:round(finalPoints[#finalPoints].cz,4) == courseplay:round(smoothPoint.cz,4) then
										courseplay:debug(string.format('\t\t not inserted smoothPoint because of double entry'), 7);
									else
										smoothPoint.cy = 0;
										smoothPoint.offsetLane = curLane;
										courseplay:debug(string.format('\t\tinsert smoothPoint %d (cx,cz=%.1f,%.1f) into "finalPoints"', j, smoothPoint.cx, smoothPoint.cz), 7);

										table.insert(finalPoints, smoothPoint);
										pointsInserted = pointsInserted + 1;
									end
								elseif j > steps + steps then
									break;
								end;
							end; --END for j, smoothPoint in pairs(smoothed)
						end; --END if np2 and pp
					end; --END if dist
				end; --END if np1

				if insertCurrent then
					-- courseplay:debug(string.format('\tinsert point %d into "finalPoints"', i), 7);
					table.insert(finalPoints, offsP);
					pointsInserted = pointsInserted + 1;
				end;
			end; --END for i,offsP in pairs(lane)

			numOffsetPoints = pointsInserted;
			-- courseplay:debug(tableShow(finalPoints, string.format('[line %d] finalPoints %d', debug.getinfo(1).currentline, curLane), 7), 7); --WORKS


			if numOffsetPoints >= 5 then
				-- --------------------------------------------------
				-- (2.4) FINALIZE (ADD POINT DATA)
				courseplay:debug('(2.4) FINALIZE (ADD POINT DATA)', 7);

				lane = finalPoints;
				for i,cp in pairs(lane) do
					local np = lane[i+1];
					if i == numOffsetPoints then
						np = lane[1];
					end;
					local dirX,dirZ = self:getPointDirection(cp, np);

					cp.angle = Utils.getYRotationFromDirection(dirX, dirZ);
					cp.wait = nil;
					cp.rev = nil;
					cp.crossing = nil;
					cp.generated = true;
					cp.lane = curLane * -1; --negative lane = headland
					cp.turnStart = nil;
					cp.turnEnd = nil;
					cp.ridgeMarker = laneRidgeMarker;
				end;

				polyPoints = lane;
				polyLength = numOffsetPoints;
				courseplay:debug(string.format("generateCourse(%i): inserting lane #%d (%d points) into headland.lanes", debug.getinfo(1).currentline, curLane, numOffsetPoints), 7);
				-- courseplay:debug(tableShow(lane, string.format('[line %d] lane %d', debug.getinfo(1).currentline, curLane), 7), 7); --WORKS
				table.insert(vehicle.cp.headland.lanes, lane);
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
			poly.points = vehicle.cp.headland.lanes[numCreatedLanes]; --up/down based on last offset lane (= 1/2 workWidth overlap) - TODO: smaller overlap (1/4) ?
			poly.numPoints = #(poly.points);
			courseplay:debug(string.format('headland: numCreatedLanes=%d -> poly=%s, poly.points=%s, poly.numPoints=%s, #poly.points=%s', numCreatedLanes, tostring(poly), tostring(poly.points), tostring(poly.numPoints), tostring(poly.points and #poly.points or 'nil')), 7);
		end;

	end; --END if vehicle.cp.headland.numLanes ~= 0


	---#################################################################
	-- (3) DIMENSIONS, ALL PATH POINTS
	--------------------------------------------------------------------
	courseplay:debug('(3) DIMENSIONS, ALL PATH POINTS', 7);

	local _, _, dimensions = courseplay.fields:getPolygonData(poly.points, nil, nil, true, true);
	courseplay:debug(string.format('minX=%s, maxX=%s', tostring(dimensions.minX), tostring(dimensions.maxX)), 7); --WORKS
	courseplay:debug(string.format('minZ=%s, maxZ=%s', tostring(dimensions.minZ), tostring(dimensions.maxZ)), 7); --WORKS
	courseplay:debug(string.format('generateCourse(%i): width=%s, height=%s', debug.getinfo(1).currentline, tostring(dimensions.width), tostring(dimensions.height)), 7); --WORKS

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
			end; --END for curPoint in pointsPerLane
		end; --END for curLane in numLanes
	end; --END East or West


	---############################################################################
	-- (4) CHECK PATH LANES FOR VALID START AND END POINTS and FILL fieldWorkCourse
	-------------------------------------------------------------------------------
	courseplay:debug('(4) CHECK PATH LANES FOR VALID START AND END POINTS and FILL fieldWorkCourse #pathPoints:'..tostring(#pathPoints), 7);
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
			wait = nil, --will be set to true for first and last after all is set and done
			rev = nil,
			crossing = nil,
			lane = cp.lane,
			turnStart = courseplay:trueOrNil(cp.lastInLane and cp.lane < numLanes),
			turnEnd = courseplay:trueOrNil(cp.firstInLane and i > 1),
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
				newFirstInLane.firstInLane = true;
				newFirstInLane.turnStart = nil;
				newFirstInLane.turnEnd = courseplay:trueOrNil(i > 1);
				newFirstInLane.ridgeMarker = 0;
				newFirstInLane.generated = true;

				--reset some vars in old first point
				point.wait = nil;
				point.firstInLane = false;
				point.turnStart = nil;
				point.turnEnd = nil;
			end;
		end; --END cp.firstInLane

		if cp.lastInLane and i ~= numPoints then
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
				newLastInLane.lastInLane = true;
				newLastInLane.turnStart = courseplay:trueOrNil(i < numPoints);
				newLastInLane.turnEnd = nil;
				newLastInLane.ridgeMarker = 0;
				newLastInLane.generated = true;

				point.wait = nil;
				point.lastInLane = false;
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



	---############################################################################
	-- (5) ROTATE HEADLAND COURSES
	-------------------------------------------------------------------------------
	courseplay:debug('(5) ROTATE HEADLAND COURSES', 7);
	local numHeadlandLanesCreated = 0;
	if vehicle.cp.headland.numLanes > 0 then
		numHeadlandLanesCreated = #(vehicle.cp.headland.lanes);
		if numHeadlandLanesCreated > 0 then
			if vehicle.cp.headland.orderBefore then --each headland lanes' first point is closest to first fieldwork course point
				for i,lane in pairs(vehicle.cp.headland.lanes) do
					local numPoints = #lane;
					local closest = self:getClosestPolyPoint(lane, fieldWorkCourse[1].cx, fieldWorkCourse[1].cz);
					courseplay:debug(string.format('[before] rotating headland lane=%d, closest=%d -> rotate: numPoints-(closest-1)=%d-(%d-1)=%d', i, closest, numPoints, closest, numPoints - (closest-1)), 7);
					vehicle.cp.headland.lanes[i] = table.rotate(lane, numPoints - (closest-1));
					--courseplay:debug(tableShow(vehicle.cp.headland.lanes[i], 'rotated headland lane '..i), 7);
				end;

			else --each headland lanes' first point is closest to last fieldwork course point
				local lastFieldworkPoint = fieldWorkCourse[#(fieldWorkCourse)];
				--courseplay:debug(tableShow(lastFieldWorkPoint, 'lastFieldWorkPoint'), 7); --TODO: is nil - whyyyyy?
				local headlandLanes = {}
				for i=numHeadlandLanesCreated, 1, -1 do
					local lane = vehicle.cp.headland.lanes[i];
					local numPoints = #lane;
					local closest = self:getClosestPolyPoint(lane, lastFieldworkPoint.cx, lastFieldworkPoint.cz); --TODO: works, but how if lastFieldWorkPoint is nil???
					courseplay:debug(string.format('[after] rotating headland lane=%d, closest=%d -> rotate: numPoints-(closest-1)=%d-(%d-1)=%d', i, closest, numPoints, closest, numPoints - (closest-1)), 7);

					table.insert(headlandLanes, table.rotate(lane, numPoints - (closest-1)));
				end;

				vehicle.cp.headland.lanes = nil;
				vehicle.cp.headland.lanes = {};
				vehicle.cp.headland.lanes = headlandLanes;
				--courseplay:debug(tableShow(vehicle.cp.headland.lanes, 'rotated headland lanes'), 7);
			end;
		end;
	end;



	---############################################################################
	-- (6) CONCATENATE HEADLAND COURSE and FIELDWORK COURSE
	-------------------------------------------------------------------------------
	courseplay:debug('(6) CONCATENATE HEADLAND COURSE and FIELDWORK COURSE #fieldWorkCourse:'..tostring(#fieldWorkCourse), 7);
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
				wait = nil,
				rev = nil,
				crossing = nil,
				lane = 1,
				turnStart = nil,
				turnEnd = nil,
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
	--vehicle:setCpVar('numWaypoints', #vehicle.Waypoints,courseplay.isClient);
	vehicle.cp.numWaypoints = #vehicle.Waypoints;
	if vehicle.cp.numWaypoints == 0 then
		courseplay:debug('ERROR: #vehicle.Waypoints == 0 -> cancel and return', 7);
		return;
	end;

	courseplay:setWaypointIndex(vehicle, 1);
	vehicle:setCpVar('canDrive',true,courseplay.isClient);
	vehicle.Waypoints[1].wait = true;
	vehicle.Waypoints[1].crossing = true;
	vehicle.Waypoints[vehicle.cp.numWaypoints].wait = true;
	vehicle.Waypoints[vehicle.cp.numWaypoints].crossing = true;
	vehicle.cp.numCourses = 1;
	courseplay.signs:updateWaypointSigns(vehicle);

	-- extra data for turn maneuver
	vehicle.cp.courseWorkWidth = workWidth;
	vehicle.cp.courseNumHeadlandLanes = numHeadlandLanesCreated;
	vehicle.cp.courseHeadlandDirectionCW = vehicle.cp.headland.userDirClockwise;

	vehicle.cp.hasGeneratedCourse = true;
	courseplay:setFieldEdgePath(vehicle, nil, 0);
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);

	-- SETUP 2D COURSE DRAW DATA
	vehicle.cp.course2dUpdateDrawData = true;

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
	return ang % 360;
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

function courseplay.generation:getOffsetWidth(vehicle, laneNum,workWidth)
	local w = workWidth;
	if laneNum == 1 then
		w = w/2;
	end;
	local noGoWidth = w * vehicle.cp.headland.noGoWidthRatio;
	return w, noGoWidth;
end;

-- @src: https://love2d.org/forums/viewtopic.php?f=5&t=1516&start=10
function courseplay.generation:smoothSpline(points, steps, useC, addHeight)
	if useC == nil then useC = true; end;
	if addHeight == nil then addHeight = false; end;

	local numPoints = #points;
	if numPoints < 3 then return points end;
	local steps = steps or 5;
	local spline = {};
	local count = numPoints - 1;
	local p0, p1, p2, p3, nx, nz;
	local x,y,z = 'x','y','z';
	if useC then
		x,y,z = 'cx','cy','cz';
	end;

	for i = 1, count do
		if i == 1 then
			p0, p1, p2, p3 = points[i], points[i], points[i + 1], points[i + 2];
		elseif i == count then
			p0, p1, p2, p3 = points[numPoints - 2], points[numPoints - 1], points[numPoints], points[numPoints];
		else
			p0, p1, p2, p3 = points[i - 1], points[i], points[i + 1], points[i + 2];
		end;
		for t = 0, 1, 1 / steps do
			nx = 0.5*((2*p1[x])+(p2[x]-p0[x])*t+(2*p0[x]-5*p1[x]+4*p2[x]-p3[x])*t*t+(3*p1[x]-p0[x]-3*p2[x]+p3[x])*t*t*t);
			nz = 0.5*((2*p1[z])+(p2[z]-p0[z])*t+(2*p0[z]-5*p1[z]+4*p2[z]-p3[z])*t*t+(3*p1[z]-p0[z]-3*p2[z]+p3[z])*t*t*t);

			--prevent duplicate entries
			local numSplinePoints = #spline;
			if not (numSplinePoints > 0 and spline[numSplinePoints].cx == nx and spline[numSplinePoints].cz == nz) then
				local point = {
					[x] = nx,
					[y] = addHeight and getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nx, 1, nz) + 3 or nil,
					[z] = nz
				};
				table.insert(spline, point); -- table of indexed points
			end;
		end;
	end;
	return spline;
end;

function courseplay.generation:getClosestPolyPoint(poly, x, z)
	local closestDistance = math.huge;
	local closestPointIndex;
	local rotatedPoly = poly;

	for i=1, #(poly) do
		local cp = poly[i];
		local distanceToPoint = courseplay:distance(cp.cx, cp.cz, x, z);
		if distanceToPoint < closestDistance then
			closestDistance = distanceToPoint;
			closestPointIndex = i;
		end;
	end;

	return closestPointIndex;
end;

