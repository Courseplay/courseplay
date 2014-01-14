-- Field scanner
-- original algorithm by upsidedown, 24 Nov 2013 / incorporation into Courseplay by Jakob Tischler, 27 Nov 2013

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
	
	local scanStep = 5;
	local maxN = 2000;
	local numDirectionTries = 10;

	local fieldDef = g_currentMission.fieldDefinitionBase.fieldDefs[self.curFieldScanIndex];
	if fieldDef ~= nil then
		local fieldNum = fieldDef.fieldNumber;
		local initObject = fieldDef.fieldMapIndicator;
		local x,_,z = getWorldTranslation(initObject);
		if fieldNum and initObject and x and z then
			local isField = courseplay:is_field(x, z, 0.1, 0.1);

			self:dbg(string.format("fieldDef %d (fieldNum=%d): x,z=%.1f,%.1f, isField=%s", self.curFieldScanIndex, fieldNum, x, z, tostring(isField)), 'scan');
			if isField then
				self:setSingleFieldEdgePath(initObject, x, z, scanStep, maxN, numDirectionTries, fieldNum, false, 'scan');
			end;

			self.numAvailableFields = table.maxn(self.fieldData);
		else
			self:dbg(string.format('fieldDef %s: fieldNum=%s, initObject=%s, x,z=%s,%s -> cancel', tostring(self.curFieldScanIndex), tostring(fieldNum), tostring(initObject), tostring(x), tostring(z)), 'scan');
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

function courseplay.fields:getSingleFieldEdge(initObject, scanStep, maxN, randomDir)
	--self = courseplay.fields
	scanStep = scanStep or 5;
	maxN = maxN or math.floor(10000/scanStep); --10 km circumference should be enough. otherwise state maxN as parameter
	randomDir = randomDir or false;

	local x0,_,z0 = getWorldTranslation(initObject);
	local x,y,z = localDirectionToWorld(initObject, 0, 0, 1);

	if randomDir then
		math.randomseed(g_currentMission.time)
		x = 2*math.random()-1;
		z = 2*math.random()-1;
	end;

	local length = Utils.vector2Length(x,z);
	local dX = x/length;
	local dZ = z/length;

	local isField = courseplay:is_field(x0, z0, 0.1, 0.1);
	local coordinates, xValues, zValues = {}, {}, {};

	if isField then
		local dis = 0;
		local isSearchPointOnField = true;
		local stepA = 1;
		local stepB = -.05;

		local xx, zz;
		while isSearchPointOnField do --search fast forward (1m steps)
			dis = dis + stepA;
			xx = x0 + dis*dX;
			zz = z0 + dis*dZ;
			isSearchPointOnField = courseplay:is_field(xx, zz, 0.1, 0.1);
			if math.abs(dis) > 2000 then
				break;
			end;
		end;
		self:dbg(string.format('\tfound first point past field border: xx=%s, zz=%s, dis=%s', tostring(xx), tostring(zz), tostring(dis)), 'scan');

		while not isSearchPointOnField do --then backtrace in small 5cm steps
			dis = dis + stepB;
			xx = x0 + dis*dX;
			zz = z0 + dis*dZ;
			isSearchPointOnField = courseplay:is_field(xx, zz, 0.1, 0.1);
		end;
		self:dbg(string.format('\ttrace back, border point found: xx=%s, zz=%s, dis=%s', tostring(xx), tostring(zz), tostring(dis)), 'scan');

		--now we have a point very close to the field boundary but definitely inside :)

		local tg = createTransformGroup("scanner");
		link(getRootNode(), tg);
		local probe1 = createTransformGroup("probe1");
		link(tg, probe1);
		setTranslation(probe1,-scanStep,0,0);

		--rotate 90° against initObject --unnecessary, as it's already been rotated in the above line (x coordinate)

		--local _,ry,_ = getWorldRotation(initObject);
		--setRotation(tg,0,ry,0)
		if randomDir then
			rotate(tg,0,2*math.pi*math.random(),0)
		else
			rotate(tg,0,math.pi/2,0) --turn side
		end;
		self:dbg(string.format('\trotate tg'), 'scan');

		-- local dirX = dZ;
		-- local dirZ = -dirX; --90° of search direction;
		local px, pz = xx, zz;

		while #coordinates < maxN do
			setTranslation(tg,px,y,pz)
			setTranslation(probe1,-scanStep,0,0); --reset scanstep (already rotated)
			--local rx,ry,ry = getRotation(probe1);

			px,_,pz = getWorldTranslation(probe1); 
			local rotAngle = 0.1;
			local turnSign = 1.0;
			
			local return2field = not courseplay:is_field(px, pz, 0.1, 0.1); --there is NO guarantee that probe1 (px,pz) is in field just because tg is!!! 
			
			while courseplay:is_field(px, pz, 0.1, 0.1) or return2field do
				rotate(tg,0,rotAngle*turnSign,0)
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

			local cnt, maxcnt = 0, 0;
			while not courseplay:is_field(px, pz, 0.1, 0.1) do
				rotate(tg,0,0.01*turnSign,0)
				px,_,pz = getWorldTranslation(probe1);
				--self:dbg('\t\trotate back', 'scan');
				cnt = cnt+1;
				if cnt > 2*math.pi/.01 then
					translate(probe1,.5*scanStep,0,0);
					cnt = 0;
					maxcnt = maxcnt + 1;
					if maxcnt > 2 then
						break;
					end;
				end;
			end;
			if not courseplay:is_field(px, pz, 0.1, 0.1) then
				self:dbg('\tlost point', 'scan');
				break;
			end;

			--print("found")
			table.insert(coordinates, { cx = px, cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 1, pz), cz = pz });
			table.insert(xValues, px);
			table.insert(zValues, pz);
			self:dbg(string.format('\tpoint %d set: cx=%s, cz=%s', #coordinates, tostring(px), tostring(pz)), 'scan');

			if #coordinates > 5 then
				local dis0 = Utils.vector2Length(px-coordinates[1].cx, pz-coordinates[1].cz) 
				--print(dis0)
				if dis0 < scanStep*1.25 then --otherwise start and end points can be very close together
					self:dbg(string.format('\tdistance to first point [%.2f] < scanStep*1.25 [%.2f] -> break', dis0, scanStep * 1.25), 'scan');
					break;
				end;
			end;
		end;

		unlink(probe1);
		unlink(tg);
		delete(probe1);
		delete(tg);

		if coordinates and xValues and zValues then
			self:dbg(string.format('\tget: #coordinates=%d, #xValues=%d, #zValues=%d', #coordinates, #xValues, #zValues), 'scan');
		else
			self:dbg(string.format('\tget: coordinates=%s, xValues=%s, zValues=%s', tostring(coordinates), tostring(xValues), tostring(zValues)), 'scan');
		end;

		return coordinates, xValues, zValues;
	end;
end;

function courseplay.fields:setSingleFieldEdgePath(initObject, initX, initZ, scanStep, maxN, numDirectionTries, fieldNum, returnPoints, dbgType)
	for try=1,numDirectionTries do
		local edgePoints, xValues, zValues = self:getSingleFieldEdge(initObject, scanStep, maxN, try > 1);

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