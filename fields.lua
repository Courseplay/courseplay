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
	self.customFieldMaxNum = 200;
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
	--Tommi:still needed ?  self.fieldChannels = { g_currentMission.cultivatorChannel, g_currentMission.plowChannel, g_currentMission.sowingChannel, g_currentMission.sowingWidthChannel };
	--Tommi: still needed ?  self.lastChannel = g_currentMission.cultivatorChannel;

	self.seedUsageCalculator.fruitTypes = self:getFruitTypes();
	self:setCustomFieldsSeedData();

	self.ingameDataSetUp = true;
end;

function courseplay.fields:setAllFieldEdges()
	self.curFieldScanIndex = self.curFieldScanIndex + 1;
	
	if self.curFieldScanIndex > #courseplay.fields.fieldDefinitionBase then
		self.allFieldsScanned = true;
		self.numAvailableFields = table.maxn(self.fieldData);
		self:dbg(string.format('%d fields scanned - done', self.curFieldScanIndex - 1), 'scan');
		return;
	end;

	self:dbg(string.rep('-', 50) .. '\ncall setAllFieldEdges() START (curFieldScandIndex=' .. tostring(self.curFieldScanIndex) .. ')', 'scan');

	local maxN = 2000;
	local numDirectionTries = 10;

	local fieldDef = courseplay.fields.fieldDefinitionBase[self.curFieldScanIndex];
	if fieldDef ~= nil then
		if not self.onlyScanOwnedFields or (self.onlyScanOwnedFields and (fieldDef.farmland.isOwned or fieldDef.currentMission)) then  --TODO: Check, whether I'm the owner
		--if not self.onlyScanOwnedFields or (self.onlyScanOwnedFields and fieldDef.ownedByPlayer) then
			local fieldNum = fieldDef.fieldId;
			if self.fieldData[fieldNum] == nil then
				local initObject = fieldDef.nameIndicator;
				local x,_,z = getWorldTranslation(initObject);
				if fieldNum and initObject and x and z then
					local isField = courseplay:isField(x, z, 0.1, 0.1);

					self:dbg(string.format("fieldDef %d (fieldNum=%d): x,z=%.1f,%.1f, isField=%s", self.curFieldScanIndex, fieldNum, x, z, tostring(isField)), 'scan');
					if isField then
						self:setSingleFieldEdgePath(initObject, x, z, self.scanStep, maxN, numDirectionTries, fieldNum, false, 'scan');
						--courseGenerator.findIslands( self.fieldData[ fieldNum ])
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
			local px,_,pz = getWorldTranslation(probe1);
			local rotAngle = 0.1; -- 5.73 deg

			local return2field = not courseplay:isField(px, pz, 0.1, 0.1); --there is NO guarantee that probe1 (px,pz) is in field just because tg is!
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
					local dis0 = MathUtil.vector2Length(px-coordinates[1].cx, pz-coordinates[1].cz)
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

							self.fieldData[fieldNum].fieldAreaText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_FIELD'):format(fieldNum, self:formatNumber(self.fieldData[fieldNum].areaHa, 2), g_i18n:getText('unit_ha'));
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

--
function courseplay.fields.updateFieldData(self, farmId) -- scan field when it's bought
	-- print(string.format('buyField(fieldDef, isOwned) [fieldNumber %s]', tostring(fieldDef.fieldNumber)));
	if g_currentMission.time > 0 and farmId ~= FarmlandManager.NO_OWNER_FARM_ID and courseplay.fields.automaticScan and courseplay.fields.onlyScanOwnedFields and courseplay.fields.fieldData[self.fieldId] == nil then
		-- print(string.format('\tisOwned=true, automaticScan=true, onlyScanOwnedFields=true, fieldData[%d]=nil', fieldDef.fieldNumber));
		local initObject = self.nameIndicator;
		if initObject then	
			local x,_,z = getWorldTranslation(initObject);
			print('scanning')
			courseplay.fields:setSingleFieldEdgePath(initObject, x, z, courseplay.fields.scanStep, 2000, 10, self.fieldId, false, 'scan');
		end
	elseif g_currentMission.time > 0 and farmId == FarmlandManager.NO_OWNER_FARM_ID and courseplay.fields.automaticScan and courseplay.fields.onlyScanOwnedFields and courseplay.fields.fieldData[self.fieldId] then
		print('deleting')
		courseplay.fields.fieldData[self.fieldId] = nil
		courseplay.fields.numAvailableFields = table.maxn(courseplay.fields.fieldData)
	end;
end;
Field.setFieldOwned = Utils.appendedFunction(Field.setFieldOwned, courseplay.fields.updateFieldData);

function courseplay.fields.addContractField(self) -- scan field when we take a contract
	-- print(string.format('buyField(fieldDef, isOwned) [fieldNumber %s]', tostring(fieldDef.fieldNumber)));
	if g_currentMission.time > 0 and courseplay.fields.automaticScan and courseplay.fields.onlyScanOwnedFields and courseplay.fields.fieldData[self.field.fieldId] == nil then
		-- print(string.format('\tisOwned=true, automaticScan=true, onlyScanOwnedFields=true, fieldData[%d]=nil', fieldDef.fieldNumber));
		local initObject = self.field.nameIndicator;
		if initObject then	
			print('scanning')
			local x,_,z = getWorldTranslation(initObject);
			courseplay.fields:setSingleFieldEdgePath(initObject, x, z, courseplay.fields.scanStep, 2000, 10, self.field.fieldId, false, 'scan');
		end
	end;
end;
AbstractFieldMission.addToMissionMap = Utils.appendedFunction(AbstractFieldMission.addToMissionMap, courseplay.fields.addContractField);


function courseplay.fields.removeContractField(self, success) -- scan field when we complete a contract
	-- print(string.format('buyField(fieldDef, isOwned) [fieldNumber %s]', tostring(fieldDef.fieldNumber)));
	if g_currentMission.time > 0 and courseplay.fields.automaticScan and courseplay.fields.onlyScanOwnedFields and courseplay.fields.fieldData[self.field.fieldId] then
		print('deleting')
		courseplay.fields.fieldData[self.field.fieldId] = nil 
		courseplay.fields.numAvailableFields = table.maxn(courseplay.fields.fieldData)
	end
end;
AbstractFieldMission.finish = Utils.appendedFunction(AbstractFieldMission.finish, courseplay.fields.removeContractField);

--XML SAVING
function courseplay.fields.saveCustomFields(self)
	local customFields = courseplay.fields;

	-- opening the file with io.open will delete its content...
	if g_server ~= nil and CpManager.cpCustomFieldsXmlFilePath ~= nil and customFields.numAvailableFields > 0 then
		local cpCFXml = createXMLFile("cpCustomFieldsXml", CpManager.cpCustomFieldsXmlFilePath, "CPCustomFields");
		if cpCFXml and cpCFXml ~= 0 then
			local fieldIndex = 0;
			for _,fieldData in pairs(customFields.fieldData) do
				if fieldData.isCustom then
					local key = ("CPCustomFields.field(%d)"):format(fieldIndex);
					setXMLInt(cpCFXml, key .. '#fieldNum',	fieldData.fieldNum);
					setXMLInt(cpCFXml, key .. '#numPoints',	fieldData.numPoints);
					for i,point in ipairs(fieldData.points) do
						setXMLString(cpCFXml, key .. (".point%d#pos"):format(i), ("%.2f %.2f %.2f"):format(point.cx, point.cy, point.cz))
					end;

					fieldIndex = fieldIndex + 1;
				end;
			end;

			saveXMLFile(cpCFXml);
			delete(cpCFXml);
		else
			print("Error: Courseplay's custom fields could not be saved to " .. CpManager.cpCustomFieldsXmlFilePath);
		end;
	end;
end;
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, courseplay.fields.saveCustomFields);

--XML LOADING
function courseplay.fields:loadCustomFields(importFromOldFile)
	--self = courseplay.fields
	if (CpManager.cpCustomFieldsXmlFilePath ~= nil and fileExists(CpManager.cpCustomFieldsXmlFilePath)) or importFromOldFile then
		local cpCFXml;
		if importFromOldFile then
			print('## Courseplay: Importing old custom fields from "courseplayFields.xml"');
			cpCFXml = loadXMLFile("cpOldCustomFieldsXml", CpManager.cpOldCustomFieldsXmlFilePath);
		else
			cpCFXml = loadXMLFile("cpCustomFieldsXml", CpManager.cpCustomFieldsXmlFilePath);
		end;

		local i = 0;
		while true do
			local key;
			if importFromOldFile then
				key = string.format('XML.fields.field(%d)', i);
			else
				key = string.format('CPCustomFields.field(%d)', i);
			end;

			if not hasXMLProperty(cpCFXml, key) then
				break;
			end;

			local fieldNum = getXMLInt(cpCFXml, key .. '#fieldNum');
			local numPoints = getXMLInt(cpCFXml, key .. '#numPoints');

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
					if hasXMLProperty(cpCFXml, pointKey) then
						local x,y,z = StringUtil.getVectorFromString(getXMLString(cpCFXml, pointKey .. '#pos'));
						if x and y and z then
							table.insert(fieldData.points, { cx = x, cy = y, cz = z });
						end;
					end;
				end;
				local area, _, dimensions = self:getPolygonData(fieldData.points, nil, nil, true);
				fieldData.areaSqm = area;
				fieldData.areaHa = area / 10000;
				fieldData.fieldAreaText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_FIELD'):format(fieldNum, self:formatNumber(fieldData.areaHa, 2), g_i18n:getText('unit_ha'));
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

		delete(cpCFXml);

		if importFromOldFile then
			self:saveCustomFields(); -- this will prevent importing again if the game was not saved.

			-------------------------------------------------------------------------
			-- Delete content of old file
			-------------------------------------------------------------------------
			local cpOldCFFile = createXMLFile("cpOldCFFile", CpManager.cpOldCustomFieldsXmlFilePath, 'XML');
			saveXMLFile(cpOldCFFile);
			delete(cpOldCFFile);
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
	local hudW = courseplay.hud.suc.visibleArea.overlayWidth;
	local hudH = courseplay.hud.suc.visibleArea.overlayHeight;
	local hudX = courseplay.hud.suc.visibleArea.overlayPosX;
	local hudY = courseplay.hud.suc.visibleArea.overlayPosY;
	for name,fruitType in pairs(g_fruitTypeManager.fruitTypes) do
		if fruitType.allowsSeeding and fruitType.seedUsagePerSqm then
			local fillTypeDesc = g_fruitTypeManager.fruitTypeIndexToFillType[fruitType.index];
			if fillTypeDesc then
				local fruitData = {
					index = fruitType.index,
					name = fruitType.name,
					nameI18N = fillTypeDesc.title,
					sucText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_SEEDTYPE'):format(fillTypeDesc.title)
				};

				if fillTypeDesc.hudOverlayFilenameSmall ~= '' then
					local hudOverlayPath = fillTypeDesc.hudOverlayFilenameSmall;
					if StringUtil.startsWith(hudOverlayPath, 'dataS2') or fileExists(hudOverlayPath) then
						fruitData.overlay = Overlay:new(hudOverlayPath, hudX, hudY, hudW, hudH);
						fruitData.overlay:setColor(1, 1, 1, 0.25);
						--print(('SUC fruitType %s: hudPath=%q, overlay=%s'):format(fruitData.name, tostring(hudOverlayPath), tostring(fruitData.overlay)));
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

	if self.seedUsageCalculator.fruitTypes then
		for i,fruitData in ipairs(self.seedUsageCalculator.fruitTypes) do
			local name = fruitData.name;
			usage[name] = fruitData.usagePerSqm * area;
			price[name] = fruitData.pricePerLiter * usage[name];
			text[name] = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_USAGE'):format(courseplay:round(g_i18n:getFluid(usage[name])), g_i18n:getText('unit_liter'), g_i18n:formatMoney(g_i18n:getCurrency(price[name])));
		end;
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


function courseplay.fields.saveAllFields()
	if g_server ~= nil and CpManager.cpCoursesFolderPath ~= nil then
		local fileName = createXMLFile("cpFields", CpManager.cpCoursesFolderPath .. "/cpFields.xml", "CPFields");
		print( "Saving all fields to " .. CpManager.cpCoursesFolderPath .. "/cpFields.xml")
		if fileName and fileName ~= 0 then
			local fieldIndex = 0;
			for _,fieldData in pairs(courseplay.fields.fieldData) do
				print( "Saving field " .. fieldData.fieldNum .. "..." )
				local key = ("CPFields.field(%d)"):format(fieldIndex);
				setXMLInt(fileName, key .. '#fieldNum',	fieldData.fieldNum);
				setXMLInt(fileName, key .. '#numPoints',	fieldData.numPoints);
				for i,point in ipairs(fieldData.points) do
					setXMLString(fileName, key .. (".point%d#pos"):format(i), ("%.2f %.2f %.2f"):format(point.cx, point.cy, point.cz))
				end;
				if not fieldData.islandNodes then
					courseGenerator.findIslands( fieldData )
				end
				for i, islandNode in ipairs( fieldData.islandNodes ) do
					setXMLString( fileName, key .. ( ".islandNode%d#pos"):format( i ), ("%.2f %2.f"):format( islandNode.cx, islandNode.cz ))
				end
				
				fieldIndex = fieldIndex + 1;
			end;

			saveXMLFile(fileName);
			delete(fileName);
		else
			print("Error: Courseplay's custom fields could not be saved to " .. CpManager.cpCoursesFolderPath);
		end;
	end;
end


function courseplay.fields:onWhichFieldAmI(vehicle)
	local positionX, _, positionZ = getWorldTranslation(vehicle.cp.DirectionNode or vehicle.rootNode);
	return self:getFieldNumForPosition( positionX, positionZ )
end

function courseplay.fields:getFieldNumForPosition(positionX, positionZ)
	local fieldNum = 0;
	for index, field in pairs(courseplay.fields.fieldData) do
		if positionX >= field.dimensions.minX and positionX <= field.dimensions.maxX and positionZ >= field.dimensions.minZ and positionZ <= field.dimensions.maxZ then
			local _, pointInPoly, _, _ = self:getPolygonData(field.points, positionX, positionZ, true, true, true);
			if pointInPoly then
				fieldNum = index
				break
			end
		end
	end
	return fieldNum
end
