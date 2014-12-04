-- Field scanner
-- original algorithm by upsidedown, 24 Nov 2013 / incorporation into Courseplay by Jakob Tischler, 27 Nov 2013
-- steep angle algorithm by fck54

courseplay.fields = {};

function courseplay.fields:setup()
	print('## Courseplay: setting up fields (basic)');
	self.fieldData = {};
	self.numAvailableFields = 0;
	self.fieldChannels = {};
	self.lastChannel = 0;
	self.curFieldScanIndex = 0;
	self.allFieldsScanned = false;
	self.ingameDataSetUp = false;
	self.customFieldMaxNum = 150;
	self.automaticScan = true;
	self.onlyScanOwnedFields = true;
	self.debugScannedFields = false;
	self.debugCustomLoadedFields = false;
	self.defaultScanStep = 5;
	self.scanStep = 5;
	self.seedUsageCalculator = {};
	self.seedUsageCalculator.fieldsWithoutSeedData = {};
end;

function courseplay.fields:setUpFieldsIngameData()
	--self = courseplay.fields
	self:dbg("call setUpIngameData()", 'scan');
	self.fieldChannels = { g_currentMission.cultivatorChannel, g_currentMission.ploughChannel, g_currentMission.sowingChannel, g_currentMission.sowingWidthChannel };
	self.lastChannel = g_currentMission.cultivatorChannel;

	self.seedUsageCalculator.fruitTypes = self:getFruitTypes();
	self:setCustomFieldsSeedData();

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
			if self.fieldData[fieldNum] == nil then
				local initObject = fieldDef.fieldMapIndicator;
				local x,_,z = getWorldTranslation(initObject);
				if fieldNum and initObject and x and z then
					local isField = courseplay:isField(x, z, 0.1, 0.1);

					self:dbg(string.format("fieldDef %d (fieldNum=%d): x,z=%.1f,%.1f, isField=%s", self.curFieldScanIndex, fieldNum, x, z, tostring(isField)), 'scan');
					if isField then
						self:setSingleFieldEdgePath(initObject, x, z, self.scanStep, maxN, numDirectionTries, fieldNum, false, 'scan');
					end;

					self.numAvailableFields = table.maxn(courseplay.fields.fieldData);
				else
					self:dbg(string.format('fieldDef %s: fieldNum=%s, initObject=%s, x,z=%s,%s -> cancel', tostring(self.curFieldScanIndex), tostring(fieldNum), tostring(initObject), tostring(x), tostring(z)), 'scan');
				end;
			else
				self:dbg(string.format('fieldDef %s: fieldNum=%s, fieldData already exists (custom field) -> cancel', tostring(self.curFieldScanIndex), tostring(fieldNum)), 'scan');
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
	local steepCornerTolerance = math.rad(15); --TODO: make customizable
	self:dbg(string.format('getSingleFieldEdge(initObject, [scanStep] %d, [maxN] %s, [randomDir] %s)', scanStep, tostring(maxN), tostring(randomDir)), dbgType);

	local x0,_,z0 = getWorldTranslation(initObject);

	local isField = courseplay:isField(x0, z0, 0.1, 0.1);
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
		setTranslation(probe1, 0, 0, 0.2);

		if randomDir then
			math.randomseed(g_currentMission.time)
			ry = 2*math.pi*math.random();
		end;
		setRotation(tg, 0, ry, 0);

		-- (2) FIND INITIAL BORDER POINT
		self:dbg(string.format('\tSearching edge in direction: %.4f (%.1f deg)', ry, math.deg(ry)), dbgType);
		while courseplay:isField(x0, z0, 0.1, 0.1) do --search fast forward (1m steps)
			dis = dis + stepA;
			translate(tg, 0, 0, stepA);
			x0, _, z0 = getWorldTranslation(tg);
			if math.abs(dis) > 2000 then
				break;
			end;
		end;

		-- now we have a point very close to the field boundary but definitely outside
		self:dbg(string.format('\t\tfound first point past field border: x0=%s, z0=%s, dis=%s', tostring(x0), tostring(z0), tostring(dis)), dbgType);

		while not courseplay:isField(x0,z0,0.1,0.1) do --then backtrace in small 5cm steps
			dis = dis + stepB;
			translate(tg, 0, 0, stepB);
			x0, _, z0 = getWorldTranslation(tg);
		end;
		-- we found the exact border point (+/- 5cm) - move tg to that point
		self:dbg(string.format('\t\ttrace back, border point found: x0=%s, z0=%s, dis=%s', tostring(x0), tostring(z0), tostring(dis)), dbgType);
		-- setTranslation(tg, x0, 0, z0); Already done


		-- (3) FIND NEXT BORDER POINT 10cm AWAY
		-- now we rotate this point to have it following the edge direction
		x0, _, z0 = getWorldTranslation(probe1);
		while not courseplay:isField(x0, z0, 0.1, 0.1) do
			rotate(tg,0,.001,0); -- rotate by 0.0573 deg
			x0, _, z0 = getWorldTranslation(probe1);
		end;
		self:dbg('\tProbe1 is on field edge')

		local _,prevRot,_ = getRotation(tg);
		local scanAt = scanStep;
		while numPoints < maxN do
			setTranslation(probe1, 0, 0, scanAt);
			rotate(tg,0,math.pi/2,0); -- place probe1 inside the field (90 deg)
			px,_,pz = getWorldTranslation(probe1);
			local rotAngle = 0.1; -- 5.73 deg

			local return2field = not courseplay:isField(px, pz, 0.1, 0.1); --there is NO guarantee that probe1 (px,pz) is in field just because tg is!!!
			self:dbg(string.format('return to field first : %s', tostring(return2field)), dbgType);
			local cnt = 2*math.pi/0.1;
			while courseplay:isField(px, pz, 0.1, 0.1) or return2field do
				cnt = cnt - .1;
				rotate(tg,0,-rotAngle,0);
				px,_,pz = getWorldTranslation(probe1);
				if cnt < 0 then
					self:dbg('\tlost', dbgType);
					break;
				end;
				if return2field then
					if courseplay:isField(px, pz, 0.1, 0.1) then
						return2field = false;
					end;
				end;
			end;

			-- trace back into field in 0.573 deg steps
			local cnt, maxcnt = 0, 0;
			while not courseplay:isField(px, pz, 0.1, 0.1) do
				rotate(tg,0,0.01,0)
				px,_,pz = getWorldTranslation(probe1);
				--self:dbg('\t\trotate back', dbgType);
				cnt = cnt+1;
				if cnt > 10 then
					scanAt = scanAt *.5;
					translate(probe1,0,0,-scanAt);
					cnt = 0;
					maxcnt = maxcnt + 1;
					if maxcnt > 2 then
						break;
					end;
				end;
			end;

			if not courseplay:isField(px, pz, 0.1, 0.1) then
				self:dbg('\tlost point', dbgType);
				break;
			end;

			local _,tgRot,_ = getRotation(tg);
			local edgeTurn = math.abs(prevRot - tgRot);
			if edgeTurn < steepCornerTolerance or scanAt <= .5 then
				if scanAt < 1 then 
					table.remove(coordinates);
					table.remove(xValues);
					table.remove(zValues);
					numPoints = numPoints - 1;
				end;
				table.insert(coordinates, { cx = px, cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 1, pz), cz = pz });
				table.insert(xValues, px);
				table.insert(zValues, pz);
				self:dbg(string.format('\tpoint %d set: cx=%s, cz=%s at %.2f m', numPoints, tostring(px), tostring(pz), scanAt), dbgType);
				numPoints = numPoints + 1;
				scanAt = scanStep;
				prevRot = tgRot;
				setTranslation(tg, getWorldTranslation(probe1));

				if numPoints > 5 then
					local dis0 = Utils.vector2Length(px-coordinates[1].cx, pz-coordinates[1].cz)
					--print(dis0)
					if dis0 < scanAt*1.25 then --otherwise start and end points can be very close together
						self:dbg(string.format('\tdistance to first point [%.2f] < scanStep*1.25 [%.2f] -> break', dis0, scanStep * 1.25), 'scan');
						break;
					end;
				end;
			else 
				scanAt = math.abs(math.cos(edgeTurn) * scanAt); -- if in a 90° corner then the corner should be at that distance
				self:dbg(string.format('\t\tScanAt reduced to %.2f', scanAt), dbgType);
				setRotation(tg, 0, prevRot, 0);
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

				local area, centerInPoly, dimensions = self:getPolygonData(edgePoints, initX, initZ, true);
				if centerInPoly then
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
								areaSqm = area;
								areaHa = area / 10000;
								dimensions = dimensions;
								name = string.format('%s %d', courseplay:loc('COURSEPLAY_FIELD'), fieldNum);
							};

							self.fieldData[fieldNum].fieldAreaText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_FIELD'):format(fieldNum, self:formatNumber(self.fieldData[fieldNum].areaHa, 2), g_i18n:getText('area_unit_short'));
							self.fieldData[fieldNum].seedUsage, self.fieldData[fieldNum].seedPrice, self.fieldData[fieldNum].seedDataText = self:getFruitData(area);

							self.numAvailableFields = table.maxn(courseplay.fields.fieldData);

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

courseplay.fields.getPointDirection = courseplay.generation.getPointDirection; -- TODO (Jakob): generateCourse is sourced after fields, so this shouldn't really work!

function courseplay.fields:getPolygonData(poly, px, pz, useC, skipArea, skipDimensions)
	-- This function gets a polygon's area, a boolean if x,z is inside the polygon, the poly's dimensions and the poly's direction (clockwise vs. counter-clockwise).
	-- Since all of those queries require a for loop through the polygon's vertices, it is better to combine them into one big query.

	if useC == nil then useC = true; end;
	local x,z = useC and 'cx' or 'x', useC and 'cz' or 'z';
	local numPoints = #poly;
	local cp,np,pp;
	local fp = poly[1];

	-- POINT IN POLYGON (Jordan method) -- @src: http://de.wikipedia.org/wiki/Punkt-in-Polygon-Test_nach_Jordan
	-- returns:
	--	 1	point is inside of poly
	--	-1	point is outside of poly
	--	 0	point is directly on poly
	local getPointInPoly = px ~= nil and pz ~= nil;
	local pointInPoly = -1;
	local point = { [x] = px, [z] = pz };

	-- AREA -- @src: https://gist.github.com/listochkin/1200393
	-- area will be twice the signed area of the polygon. If the poly is counter-clockwise, the area will be positive. If clockwise, the area will be negative.
	-- returns: real area (|area| / 2)
	local area = 0;

	-- DIMENSIONS
	local dimensions = {
		minX =  999999,
		maxX = -999999,
		minZ =  999999,
		maxZ = -999999
	};

	--[[
	-- DIRECTION
	-- offset test points
	local dirX,dirZ = self:getPointDirection(poly[1], poly[2], useC);
	local offsetRight = {
		[x] = poly[2][x] - dirZ,
		[z] = poly[2][z] + dirX,
		isInPoly = false
	};
	local offsetLeft = {
		[x] = poly[2][x] + dirZ,
		[z] = poly[2][z] - dirX,
		isInPoly = false
	};
	-- clockwise vs counterclockwise variables
	local dirArea, dirSuccess, dirTries = 0, false, 1;
	]]

	-- ############################################################

	for i=1, numPoints do
		cp = poly[i];
		np = i < numPoints and poly[i+1] or poly[1];
		pp = i > 1 and poly[i-1] or poly[numPoints];

		-- point in polygon
		if getPointInPoly and pointInPoly ~= 0 then
			pointInPoly = pointInPoly * courseplay.utils:crossProductQuery(point, cp, np, useC);
		end;

		-- area
		if not skipArea then
			area = area + cp[x] * np[z];
			area = area - cp[z] * np[x];
		end;

		-- dimensions
		if not skipDimensions then
			if cp[x] < dimensions.minX then dimensions.minX = cp[x]; end;
			if cp[x] > dimensions.maxX then dimensions.maxX = cp[x]; end;
			if cp[z] < dimensions.minZ then dimensions.minZ = cp[z]; end;
			if cp[z] > dimensions.maxZ then dimensions.maxZ = cp[z]; end;
		end;

		--[[
		-- direction
		if i < numPoints then
			local pointStart = {
				[x] = cp[x] - fp[x];
				[z] = cp[z] - fp[z];
			};
			local pointEnd = {
				[x] = np[x] - fp[x];
				[z] = np[z] - fp[z];
			};
			dirArea = dirArea + (pointStart[x] * -pointEnd[z]) - (pointEnd[x] * -pointStart[z]);
		end;

		-- offset right point in poly
		if ((cp[z] > offsetRight[z]) ~= (pp[z] > offsetRight[z])) and (offsetRight[x] < (pp[x] - cp[x]) * (offsetRight[z] - cp[z]) / (pp[z] - cp[z]) + cp[x]) then
			offsetRight.isInPoly = not offsetRight.isInPoly;
		end;

		-- offset left point in poly
		if ((cp[z] > offsetLeft[z])  ~= (pp[z] > offsetLeft[z]))  and (offsetLeft[x]  < (pp[x] - cp[x]) * (offsetLeft[z]  - cp[z]) / (pp[z] - cp[z]) + cp[x]) then
			offsetLeft.isInPoly = not offsetLeft.isInPoly;
		end;
		]]
	end;

	if getPointInPoly then
		pointInPoly = pointInPoly ~= -1;
	else
		pointInPoly = nil;
	end;

	if not skipDimensions then
		dimensions.width  = dimensions.maxX - dimensions.minX;
		dimensions.height = dimensions.maxZ - dimensions.minZ;
	else
		dimensions = nil;
	end;

	local isClockwise;
	if not skipArea then
		area = math.abs(area) / 2;
		isClockwise = area < 0;
	else
		area = nil;
		isClockwise = nil;
	end;

	return area, pointInPoly, dimensions, isClockwise;
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
	if CpManager.cpFieldsXmlFilePath ~= nil then
		local filePath = CpManager.cpFieldsXmlFilePath;
		if fileExists(filePath) and (not forceCreation) then
			xmlFile = loadXMLFile('fieldsFile', filePath);
		else
			xmlFile = createXMLFile('fieldsFile', filePath, 'XML');
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
		if CpManager.cpFieldsXmlFilePath ~= nil and self.numAvailableFields > 0 then
			local file = io.open(CpManager.cpFieldsXmlFilePath, 'w');
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
				print("Error: Courseplay's custom fields could not be saved to " .. CpManager.cpFieldsXmlFilePath);
			end;
		end;
	end;
end;

--XML LOADING
function courseplay.fields:loadAllCustomFields()
	--self = courseplay.fields
	if g_server ~= nil then
		if CpManager.cpFieldsXmlFilePath ~= nil then
			if fileExists(CpManager.cpFieldsXmlFilePath) then
				local xmlFile = loadXMLFile("fieldsFile", CpManager.cpFieldsXmlFilePath);
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
							areaSqm = 0;
							areaHa = 0;
							seedUsage = {};
							seedPrice = {};
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
						local area, _, dimensions = self:getPolygonData(fieldData.points, nil, nil, true);
						fieldData.areaSqm = area;
						fieldData.areaHa = area / 10000;
						fieldData.fieldAreaText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_FIELD'):format(fieldNum, self:formatNumber(fieldData.areaHa, 2), g_i18n:getText('area_unit_short'));
						fieldData.dimensions = dimensions;


						self.fieldData[fieldNum] = fieldData;
						if self.debugCustomLoadedFields then
							self:dbg(tableShow(fieldData, 'fieldData[' .. fieldNum .. ']'), 'customLoad');
						end;

						self.numAvailableFields = table.maxn(courseplay.fields.fieldData);

						table.insert(self.seedUsageCalculator.fieldsWithoutSeedData, fieldNum);
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

-- SeedUsageCalculator functions
function courseplay.fields:getFruitTypes()
	--GET FRUITTYPES
	local fruitTypes = {};
	local hudW = g_currentMission.hudTipperOverlay.width * 2.75;
	local hudH = hudW * g_screenAspectRatio;
	local hudX = courseplay.hud.infoBasePosX - 16/1920 + 93/1920 + 449/1920 - hudW;
	local hudY = courseplay.hud.infoBasePosY - 7/1080 + 335/1080;
	for name,fruitType in pairs(FruitUtil.fruitTypes) do
		if fruitType.allowsSeeding and fruitType.seedUsagePerSqm then
			local fillType = FruitUtil.fruitTypeToFillType[fruitType.index];
			local fillTypeDesc = Fillable.fillTypeIndexToDesc[ fillType ];
			if fillTypeDesc then
				local fruitData = {
					index = fruitType.index,
					name = fruitType.name,
					nameI18N = fillTypeDesc.nameI18N,
					sucText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_SEEDTYPE'):format(tostring(fillTypeDesc.nameI18N))
				};

				if fillType and g_currentMission.fillTypeOverlays[fillType] then
					local hudOverlayPath = g_currentMission.fillTypeOverlays[fillType].filename;
					if hudOverlayPath and hudOverlayPath ~= '' then
						if Utils.startsWith(hudOverlayPath, 'dataS2') or fileExists(hudOverlayPath) then
							fruitData.overlay = Overlay:new(('suc_fruit_%s'):format(fruitType.name), hudOverlayPath, hudX, hudY, hudW, hudH);
							fruitData.overlay:setColor(1, 1, 1, 0.25);
							-- print(('SUC fruitType %s: hudPath=%q, overlay=%s'):format(fruitType.name, tostring(hudOverlayPath), tostring(fruitData.overlay)));
						end;
					end;
				end;

				fruitData.usagePerSqm = fruitType.seedUsagePerSqm;
				fruitData.pricePerLiter = fillTypeDesc.pricePerLiter;

				if fruitData.nameI18N and fruitData.usagePerSqm and fruitData.pricePerLiter then
					table.insert(fruitTypes, fruitData);
				end;
			end;
		end;
	end;
	self.seedUsageCalculator.numFruits = #fruitTypes;
	table.sort(fruitTypes, function(a,b) return a.nameI18N:lower() < b.nameI18N:lower() end);
	self.seedUsageCalculator.enabled = self.seedUsageCalculator.numFruits > 0;
	return fruitTypes;
end;

function courseplay.fields:getFruitData(area)
	local usage, price, text = {}, {}, {};

	for i,fruitData in ipairs(self.seedUsageCalculator.fruitTypes) do
		local name = fruitData.name;
		usage[name] = fruitData.usagePerSqm * area;
		price[name] = fruitData.pricePerLiter * usage[name];
		text[name] = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_USAGE'):format(courseplay:round(g_i18n:getFluid(usage[name])), g_i18n:getText('fluid_unit_short'), g_i18n:formatMoney(g_i18n:getCurrency(price[name])));
	end;

	return usage, price, text;
end;

function courseplay.fields:setCustomFieldsSeedData()
	for i,fieldNum in ipairs(self.seedUsageCalculator.fieldsWithoutSeedData) do
		self.fieldData[fieldNum].seedUsage, self.fieldData[fieldNum].seedPrice, self.fieldData[fieldNum].seedDataText = self:getFruitData(self.fieldData[fieldNum].areaSqm);
	end;
	self.seedUsageCalculator.fieldsWithoutSeedData = {};
end;

local saveFillTypeHudPath = function(self, fillType, filename)
	self.fillTypeOverlays[fillType].filename = filename;
end;
FSBaseMission.addFillTypeOverlay = Utils.appendedFunction(FSBaseMission.addFillTypeOverlay, saveFillTypeHudPath);

function courseplay.fields:formatNumber(number, precision, money)
	precision = precision or 0;

	local firstDigit, rest, decimal = ('%1.' .. precision .. 'f'):format(number):match('^([^%d]*%d)(%d*).?(%d*)');
	local str = firstDigit .. rest:reverse():gsub('(%d%d%d)', '%1' .. courseplay.numberSeparator):reverse();
	if decimal:len() > 0 then
		str = ('%s%s%s'):format(str, courseplay.numberDecimalSeparator, decimal:sub(1, precision));
	end;
	if money then
		str = ('%s %s'):format(str, g_i18n:getCurrencySymbol(true));
	end;
	return str;
end;

