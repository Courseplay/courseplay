-- Field scanner
-- original algorithm by upsidedown, 24 Nov 2013 / incorporation into Courseplay by Jakob Tischler, 27 Nov 2013
-- steep angle algorithm by fck54

courseplay.fields.automaticScan = true;
courseplay.fields.onlyScanOwnedFields = true;
courseplay.fields.defaultScanStep = 5;
courseplay.fields.scanStep = courseplay.fields.defaultScanStep;

function courseplay.fields:setUpFieldsIngameData()
	--self = courseplay.fields
	self:dbg("call setUpIngameData()", 'scan');
	self.fieldChannels = { g_currentMission.cultivatorChannel, g_currentMission.ploughChannel, g_currentMission.sowingChannel, g_currentMission.sowingWidthChannel };
	self.lastChannel = g_currentMission.cultivatorChannel;
	self.ingameDataSetUp = true;
end;

function courseplay.fields:setAllFieldEdges()
	--self = courseplay.fields

	self.curFieldScanIndex = self.curFieldScanIndex + 1;
	if self.curFieldScanIndex > g_currentMission.fieldDefinitionBase.numberOfFields then
		self.allFieldsScanned = true;
		self.numAvailableFields = table.maxn(self.fieldData);
		self:dbg(string.format('%d fields scanned - done', self.curFieldScanIndex - 1), 'scan');
		return;
	end;

	self:dbg(string.rep('-', 50) .. '\ncall setAllFieldEdges() START (curFieldScandIndex=' .. tostring(self.curFieldScanIndex) .. ')', 'scan');

	local maxN = 2000;
	local numDirectionTries = 10;

	local fieldDef = g_currentMission.fieldDefinitionBase.fieldDefs[self.curFieldScanIndex];
	if fieldDef ~= nil then
		if not self.onlyScanOwnedFields or (self.onlyScanOwnedFields and fieldDef.ownedByPlayer) then
			local fieldNum = fieldDef.fieldNumber;
			local initObject = fieldDef.fieldMapIndicator;
			local x,_,z = getWorldTranslation(initObject);
			if fieldNum and initObject and x and z then
				local isField = courseplay:is_field(x, z, 0.1, 0.1);

				self:dbg(string.format("fieldDef %d (fieldNum=%d): x,z=%.1f,%.1f, isField=%s", self.curFieldScanIndex, fieldNum, x, z, tostring(isField)), 'scan');
				if isField then
					self:setSingleFieldEdgePath(initObject, x, z, self.scanStep, maxN, numDirectionTries, fieldNum, false, 'scan');
				end;

				self.numAvailableFields = table.maxn(self.fieldData);
			else
				self:dbg(string.format('fieldDef %s: fieldNum=%s, initObject=%s, x,z=%s,%s -> cancel', tostring(self.curFieldScanIndex), tostring(fieldNum), tostring(initObject), tostring(x), tostring(z)), 'scan');
			end;
		else
			self:dbg(string.format('fieldDef %s: onlyScanOwnedFields=%s, fieldDef.ownedByPlayer=%s -> skip field', tostring(self.curFieldScanIndex), tostring(self.onlyScanOwnedFields), tostring(fieldDef.ownedByPlayer)), 'scan');
		end;
	else
		self:dbg(string.format('fieldDef %s is nil', tostring(self.curFieldScanIndex)), 'scan');
	end;

	--Debug
	if self.debugScannedFields then
		--self:dbg(tableShow(courseplay.fields.fieldData, "fieldData"), 'scan');
	end;
	self:dbg('setAllFieldEdges() END\n' .. string.rep('-', 50), 'scan');
end;

function courseplay.fields:getSingleFieldEdge(initObject, scanStep, maxN, randomDir, dbgType)
	--self = courseplay.fields
	if randomDir == nil then randomDir = false; end;
	scanStep = scanStep or self.defaultScanStep;
	maxN = maxN or math.floor(10000/scanStep); --10 km circumference should be enough. otherwise state maxN as parameter
	local steepCornerTolerance = math.rad(11.25); --TODO: make customizable
	self:dbg(string.format('getSingleFieldEdge(initObject, [scanStep] %d, [maxN] %s, [randomDir] %s)', scanStep, tostring(maxN), tostring(randomDir)), dbgType);

	local x0,_,z0 = getWorldTranslation(initObject);

	local isField = courseplay:is_field(x0, z0, 0.1, 0.1);
	local coordinates, xValues, zValues = {}, {}, {};
	local numPoints = 0;
	self:dbg(string.format('Begin edge scanning at: %.2f, %.2f', x0, z0), dbgType);
	if isField then
		-- (1) SET INITIAL TG AND PROBE DATA
		local dis = 0;
		local stepA, stepB = 1, -0.05;
		local rx,ry,rz = getWorldRotation(initObject);

		local tg = createTransformGroup('courseplayFieldScanner');
		local probe1 = createTransformGroup('courseplayFieldProbe');
		link(getRootNode(), tg);
		link(tg, probe1);
		setTranslation(tg, x0, 0, z0);
		setTranslation(probe1, 0, 0, 0);

		if randomDir then
			math.randomseed(g_currentMission.time)
			ry = 2*math.pi*math.random();
			-- rx, rz = 5*math.random(), 5*math.random(); --TODO: why randomize x and z rotation?
		end;
		setRotation(tg, 0, ry, 0);

		-- (2) FIND INITIAL BORDER POINT
		self:dbg(string.format('\tSearching edge in direction: %.4f (%.1f deg)', ry, math.deg(ry)), dbgType);
		while courseplay:is_field(x0, z0, 0.1, 0.1) do --search fast forward (1m steps)
			dis = dis + stepA;
			setTranslation(probe1, 0, 0, dis);
			x0, _, z0 = getWorldTranslation(probe1);
			if math.abs(dis) > 2000 then
				break;
			end;
		end;
		-- now we have a point very close to the field boundary but definitely outside
		self:dbg(string.format('\tfound first point past field border: x0=%s, z0=%s, dis=%s', tostring(x0), tostring(z0), tostring(dis)), dbgType);

		while not courseplay:is_field(x0,z0,0.1,0.1) do --then backtrace in small 5cm steps
			dis = dis + stepB;
			setTranslation(probe1, 0, 0, dis);
			x0, _, z0 = getWorldTranslation(probe1);
		end;
		-- we found the exact border point (+/- 5cm) - move tg to that point
		self:dbg(string.format('\ttrace back, border point found: x0=%s, z0=%s, dis=%s', tostring(x0), tostring(z0), tostring(dis)), dbgType);
		setTranslation(tg, x0, 0, z0);


		-- (3) FIND NEXT BORDER POINT 10cm AWAY
		-- now we rotate this point to have it following the edge direction
		setTranslation(probe1, 0.1, 0, 0); --TODO: why translate on the x axis instead of the z axis?
		x0, _, z0 = getWorldTranslation(probe1);
		while not courseplay:is_field(x0, z0, 0.1, 0.1) do
			rotate(tg,0,.01,0); -- rotate by 0.573 deg
			x0, _, z0 = getWorldTranslation(probe1);
		end;

		local _,prevRot,_  = getRotation(tg);
		local scanAt = scanStep;
		directionChange = false;
		while numPoints < maxN do
			if not directionChange then
				setTranslation(tg, getWorldTranslation(probe1));
			end;
			setTranslation(probe1, scanAt, 0, 0);
			rotate(tg,0,math.pi/4,0); -- place probe1 inside the field (45 deg)
			px,_,pz = getWorldTranslation(probe1);
			local rotAngle = 0.1; -- 5.73 deg
			local turnSign = 1.0;

			local return2field = not courseplay:is_field(px, pz, 0.1, 0.1); --there is NO guarantee that probe1 (px,pz) is in field just because tg is!!!

			-- pendulum: increase rotAngle each step until probe is outside of field
			while courseplay:is_field(px, pz, 0.1, 0.1) or return2field do
				rotate(tg,0,rotAngle*turnSign,0);
				rotAngle = rotAngle*1.05;
				--rotAngle = rotAngle + 0.1; --alternative for performance tuning, don't know which one is better
				turnSign = -turnSign;
				px,_,pz = getWorldTranslation(probe1);

				if return2field then
					if courseplay:is_field(px, pz, 0.1, 0.1) then
						return2field = false;
					end;
				end;
			end;

			-- trace back into field in 0.573 deg steps
			local cnt, maxcnt = 0, 0;
			while not courseplay:is_field(px, pz, 0.1, 0.1) do
				rotate(tg,0,0.01*turnSign,0)
				px,_,pz = getWorldTranslation(probe1);
				--self:dbg('\t\trotate back', dbgType);
				cnt = cnt+1;
				if cnt > 2*math.pi/.01 then
					translate(probe1,-.5*scanAt,0,0);
					cnt = 0;
					maxcnt = maxcnt + 1;
					if maxcnt > 2 then
						break;
					end;
				end;
			end;
			if not courseplay:is_field(px, pz, 0.1, 0.1) then
				self:dbg('\tlost point', dbgType);
				break;
			end;
			local _,tgRot,_ = getRotation(tg);

			--[[
			local centerIsField = true;
			if numPoints > 0 then
				local prevPoint = coordinates[numPoints];
				local centerX, centerZ = (px+prevPoint.cx)/2, (pz+prevPoint.cz)/2;
				centerIsField = courseplay:is_field(centerX, centerZ, 0.1, 0.1);
				-- self:dbg(string.format('point %d: prev cx,cz=%.1f,%.1f, px,pz=%.1f,%.1f, centerX,centerZ=%.1f,%.1f, centerIsField=%s', numPoints+1, prevPoint.cx, prevPoint.cz, px, pz, centerX, centerZ, tostring(centerIsField)), dbgType);
			end;
			-- ]]

			--[[ -- STEEP ANGLE CHECK
			if math.abs(prevRot - tgRot) > steepCornerTolerance and scanAt >= 1 then -- dramatic direction change -> decrease scanAt in half steps
				directionChange = true;
				scanAt = scanAt/2;
				setRotation(tg,0,prevRot,0); -- reset tg rotation and scan again with a shorter scanstep
			]]

			--[[ --CENTER IS FIELD CHECK
			elseif not centerIsField and scanAt >= 1.0 then -- center point is not field -> decrease scanAt in half steps
				-- print(string.format('\tcenterIsField=false, scanAt=%.1f -> divide scanAt by 2, set directionChange to true', scanAt));
				scanAt = math.max(scanAt / 2, 0.99999); --scan again with a shorter scan step
				directionChange = true;
			-- ]]

			-- else  -- save the new found point
				table.insert(coordinates, { cx = px, cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 1, pz), cz = pz });
				table.insert(xValues, px);
				table.insert(zValues, pz);
				numPoints = numPoints + 1;
				scanAt = scanStep;
				prevRot = tgRot;
				directionChange = false;
				self:dbg(string.format('\tpoint %d set: cx=%s, cz=%s', numPoints, tostring(px), tostring(pz)), dbgType);
			-- end;

			if numPoints > 5 then
				local dis0 = Utils.vector2Length(px-coordinates[1].cx, pz-coordinates[1].cz)
				--print(dis0)
				if dis0 < scanAt*1.25 then --otherwise start and end points can be very close together
					self:dbg(string.format('\tdistance to first point [%.2f] < scanStep*1.25 [%.2f] -> break', dis0, scanStep * 1.25), 'scan');
					break;
				end;
			end;
		end;

		if coordinates and xValues and zValues then
			self:dbg(string.format('\tget: #coordinates=%d, #xValues=%d, #zValues=%d', #coordinates, #xValues, #zValues), dbgType);
		else
			self:dbg(string.format('\tget: coordinates=%s, xValues=%s, zValues=%s', tostring(coordinates), tostring(xValues), tostring(zValues)), dbgType);
		end;

		unlink(probe1);
		unlink(tg);
		delete(probe1);
		delete(tg);

		return coordinates, xValues, zValues;
	end;
end;

function courseplay.fields:setSingleFieldEdgePath(initObject, initX, initZ, scanStep, maxN, numDirectionTries, fieldNum, returnPoints, dbgType)
	for try=1,numDirectionTries do
		local edgePoints, xValues, zValues = self:getSingleFieldEdge(initObject, scanStep, maxN, try > 1, dbgType);

		if edgePoints then
			local numEdgePoints = #edgePoints;
			--self:dbg(string.format("\ttry %d: %d edge points found, #xValues=%s, #zValues=%s", try, numEdgePoints, tostring(#xValues), tostring(#zValues)), dbgType);
			if numEdgePoints >= 30 then
				self:dbg(string.format("\ttry %d: %d edge points found", try, numEdgePoints), dbgType);

				if courseplay:pointInPolygon_v2(edgePoints, xValues, zValues, initX, initZ) then
					self:dbg('\t\tinitObject is in poly --> valid, no retry', dbgType);

					if returnPoints then
						return edgePoints;
					end;

					if fieldNum then
						if self.fieldData[fieldNum] == nil then
							self.fieldData[fieldNum] = {
								fieldNum = fieldNum;
								points = edgePoints;
								numPoints = #edgePoints;
								dimensions = {
									minX = math.min(unpack(xValues));
									maxX = math.max(unpack(xValues));
									minZ = math.min(unpack(zValues));
									maxZ = math.max(unpack(zValues));
								};
								name = string.format("%s %d", courseplay:loc('COURSEPLAY_FIELD'), fieldNum);
							};
							self:dbg(string.format('\t\tcourseplay.fields.fieldData[%d] == nil => set as .fieldData[%d], break', fieldNum, fieldNum), dbgType);
						else
							self:dbg(string.format('\t\tcourseplay.fields.fieldData[%d] ~= nil => ignore scan, break', fieldNum), dbgType);
						end;
						break;
					end;
				else
					self:dbg(string.format('\t\tinitObject is NOT in poly --> invalid, retry=%s', tostring(try<numDirectionTries)), dbgType);
				end;
			else
				self:dbg(string.format("\ttry %d: %d edge points found --> invalid, retry=%s", try, numEdgePoints, tostring(try<numDirectionTries)), dbgType);
			end;
		else
			self:dbg(string.format('\ttry %d: edgePoints is nil -> invalid, retry=%s', try, tostring(try<numDirectionTries)), dbgType);
		end;
	end;
	if returnPoints then
		return nil;
	end;
end;

function courseplay.fields.buyField(self, fieldDef, isOwned) -- scan field when it's bought
	-- print(string.format('buyField(fieldDef, isOwned) [fieldNumber %s]', tostring(fieldDef.fieldNumber)));
	if g_currentMission.time > 0 and isOwned and courseplay.fields.automaticScan and courseplay.fields.onlyScanOwnedFields and courseplay.fields.fieldData[fieldDef.fieldNumber] == nil then
		-- print(string.format('\tisOwned=true, automaticScan=true, onlyScanOwnedFields=true, fieldData[%d]=nil', fieldDef.fieldNumber));
		local initObject = fieldDef.fieldMapIndicator;
		local x,_,z = getWorldTranslation(initObject);
		courseplay.fields:setSingleFieldEdgePath(initObject, x, z, courseplay.fields.scanStep, 2000, 10, fieldDef.fieldNumber, false, 'scan');
	end;
end;
FieldDefinition.setFieldOwnedByPlayer = Utils.prependedFunction(FieldDefinition.setFieldOwnedByPlayer, courseplay.fields.buyField);

--XML SAVING
function courseplay.fields:openOrCreateXML(forceCreation)
	--self = courseplay.fields
	-- returns the file if success, nil else
	forceCreation = forceCreation or false;

	local xmlFile;
	local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
	if savegame ~= nil then
		local filePath = savegame.savegameDirectory .. "/courseplayFields.xml"
		if fileExists(filePath) and (not forceCreation) then
			xmlFile = loadXMLFile("fieldsFile", filePath);
		else
			xmlFile = createXMLFile("fieldsFile", filePath, 'XML');
		end;
	else
		--this is a problem... xmlFile stays nil
	end;
	return xmlFile;
end;

function courseplay.fields:saveAllCustomFields()
	--self = courseplay.fields
	-- saves fields to xml-file
	-- opening the file with io.open will delete its content...
	if g_server ~= nil then
		local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
		if savegame ~= nil and self.numAvailableFields > 0 then
			local file = io.open(savegame.savegameDirectory .. '/courseplayFields.xml', 'w');
			if file ~= nil then
				file:write('<?xml version="1.0" encoding="utf-8" standalone="no" ?>\n<XML>\n');

				file:write('\t<fields>\n')
				for i,fieldData in pairs(self.fieldData) do
					if fieldData.isCustom then
						file:write(string.format('\t\t<field fieldNum="%d" numPoints="%d">\n', fieldData.fieldNum, fieldData.numPoints));
						for j,point in ipairs(fieldData.points) do
							file:write(string.format('\t\t\t<point%d pos="%.2f %.2f %.2f" />\n', j, point.cx, point.cy, point.cz));
						end;
						file:write('\t\t</field>\n');
					end;
				end;
				file:write('\t</fields>\n</XML>');
				file:close();
			else
				print("Error: Courseplay's custom fields could not be saved to " .. tostring(savegame.savegameDirectory) .. "/courseplayFields.xml");
			end;
		end;
	end;
end;

--XML LOADING
function courseplay.fields:loadAllCustomFields()
	--self = courseplay.fields
	if g_server ~= nil then
		local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
		if savegame ~= nil then
			local filePath = savegame.savegameDirectory .. "/courseplayFields.xml"
			if fileExists(filePath) then
				local xmlFile = loadXMLFile("fieldsFile", filePath);
				local i = 0;
				while true do
					local key = string.format('XML.fields.field(%d)', i);
					if not hasXMLProperty(xmlFile, key) then
						break;
					end;

					local fieldNum = getXMLInt(xmlFile, key .. '#fieldNum');
					local numPoints = getXMLInt(xmlFile, key .. '#numPoints');

					if fieldNum and numPoints and numPoints > 0 then
						local fieldData = {
							fieldNum = fieldNum;
							points = {};
							numPoints = numPoints;
							name = string.format("%s %d (%s)", courseplay:loc('COURSEPLAY_FIELD'), fieldNum, courseplay:loc('COURSEPLAY_USER'));
							isCustom = true;
						};
						for j=1,numPoints do
							local pointKey = key .. '.point' .. j;
							if hasXMLProperty(xmlFile, pointKey) then
								local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, pointKey .. '#pos'));
								if x and y and z then
									table.insert(fieldData.points, { cx = x, cy = y, cz = z });
								end;
							end;
						end;
						self.fieldData[fieldNum] = fieldData;
						if self.debugCustomLoadedFields then
							self:dbg(tableShow(fieldData, 'fieldData[' .. fieldNum .. ']'), 'customLoad');
						end;
						self.numAvailableFields = table.maxn(self.fieldData);
					end;
					i = i + 1;
				end;
			end;
		end;
	end;
end;

function courseplay.fields:dbg(str, debugType)
	if (debugType == 'scan' and self.debugScannedFields) or (debugType == 'customLoad' and self.debugCustomLoadedFields) then
		print(tostring(str));
	end;
end;