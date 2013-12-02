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
	self:dbg(string.rep('-', 50) .. '\ncall setAllFieldEdges() START', 'scan');
	local scanStep = 5;
	local maxN = 2000;
	local numDirectionTries = 10;

	for i=1, g_currentMission.fieldDefinitionBase.numberOfFields do
		local fieldDef = g_currentMission.fieldDefinitionBase.fieldDefs[i];
		local fieldNum = fieldDef.fieldNumber;
		local initObject = fieldDef.fieldMapIndicator; --OLD: fieldDef.fieldBuyTrigger
		local x,_,z = getWorldTranslation(initObject);
		local isField = courseplay:is_field(x, z);
		self:dbg(string.format("fieldDef %d (fieldNum=%d): x,z=%.1f,%.1f, isField=%s", i, fieldNum, x, z, tostring(isField)), 'scan');

		if isField then
			for try=1,numDirectionTries do
				local edgePoints = self:getSingleFieldEdge(initObject, scanStep, maxN, try > 1);
				local numEdgePoints = #edgePoints;
				if numEdgePoints >= 30 then
					self:dbg(string.format("\ttry %d: %d edge points found --> valid, no retry", try, numEdgePoints), 'scan');
					if self.fieldData[fieldNum] == nil then
						self.fieldData[fieldNum] = {
							fieldNum = fieldNum;
							points = edgePoints;
							numPoints = #edgePoints;
							name = string.format("%s %d", courseplay.locales.COURSEPLAY_FIELD, fieldNum);
						};
						self:dbg(string.format('\t\tcourseplay.fields.fieldData[%d] == nil => set as .fieldData[%d], break', fieldNum, fieldNum), 'scan');
					else
						self:dbg(string.format('\t\tcourseplay.fields.fieldData[%d] ~= nil => ignore scan, break', fieldNum), 'scan');
					end;
					break;
				else
					self:dbg(string.format("\ttry %d: %d edge points found --> invalid, retry=%s", try, numEdgePoints, tostring(try<numDirectionTries)), 'scan');
				end;
			end;
		end;
	end;
	self.allFieldsScanned = true;
	self.numAvailableFields = table.maxn(self.fieldData);

	--Debug
	if self.debugScannedFields then
		self:dbg(tableShow(courseplay.fields.fieldData, "fieldData"), 'scan');
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

	local isField = courseplay:is_field(x0,z0);
	-- print(x0,"  ",z0);
	-- print(isField)
	local coordinates = {};

	if isField then
		--print("isField")
		local dis = 0;
		local isSearchPointOnField = true;
		local stepA = 1;
		local stepB = -.05;

		local xx, zz;
		while isSearchPointOnField do --search fast forward (1m steps)
			dis = dis + stepA;
			xx = x0 + dis*dX;
			zz = z0 + dis*dZ;
			isSearchPointOnField = courseplay:is_field(xx,zz);
			if math.abs(dis) > 2000 then
				break;
			end;
		end;

		while not isSearchPointOnField do --then backtrace in small 5cm steps
			dis = dis + stepB;
			xx = x0 + dis*dX;
			zz = z0 + dis*dZ;
			isSearchPointOnField = courseplay:is_field(xx,zz);
		end;

		--now we have a point very close to the field boundary but definitely inside :)

		--local yy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, xx, 1, zz); --TODO: not needed?
		local tg = createTransformGroup("scanner");
		link(getRootNode(), tg);
		local probe1 = createTransformGroup("probe1");
		link(tg,probe1)
		setTranslation(probe1,scanStep,0,0);

		--rotate 90° against initObject

		local _,ry,_ = getWorldRotation(initObject);
		setRotation(tg,0,ry,0)
		if randomDir then
			rotate(tg,0,2*math.pi*math.random(),0)
		else
			rotate(tg,0,math.pi/2,0) --turn side
		end;

		-- local dirX = dZ;
		-- local dirZ = -dirX; --90° of search direction;
		local px = xx;
		local pz = zz;
		while #coordinates < maxN do
			setTranslation(tg,px,y,pz)
			setTranslation(probe1,scanStep,0,0); --reset scanstep
			--local rx,ry,ry = getRotation(probe1);

			px,_,pz = getWorldTranslation(probe1);
			local rotAngle = 0.1;
			local turnSign = -1.0;
			while courseplay:is_field(px,pz) do
				--rotate(tg,0,0.1,0)
				rotate(tg,0,rotAngle*turnSign,0)
				rotAngle = rotAngle*1.05;
				turnSign = -turnSign;
				px,_,pz = getWorldTranslation(probe1);
				--print("rotate")
			end;
			local cnt, maxcnt = 0, 0;
			while not courseplay:is_field(px,pz) do
				rotate(tg,0,0.01*turnSign,0)
				px,_,pz = getWorldTranslation(probe1);
				--print("rotate back")
				cnt = cnt+1;
				if cnt > 2*math.pi/.01 then
					translate(probe1,.5*scanStep,0,0);
					cnt = 0;
					maxcnt = maxcnt + 1;
					if maxcnt > 2 then
						break;
					end;
					--break; --translate and cnt=0!
				end;
			end;
			if not courseplay:is_field(px,pz) then
				--print("lost it")
				break;
			end;

			--print("found")
			table.insert(coordinates, { cx = px, cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 1, pz), cz = pz });

			if #coordinates > 5 then
				local dis0 = Utils.vector2Length(px-coordinates[1].cx, pz-coordinates[1].cz) --doch [1]?
				--print(dis0)
				if dis0 < scanStep then
					break;
				end;
			end;
		end;

		unlink(probe1);
		unlink(tg);
		delete(probe1);
		delete(tg);

		return coordinates;
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
							name = string.format("%s %d (%s)", courseplay.locales.COURSEPLAY_FIELD, fieldNum, courseplay.locales.COURSEPLAY_USER);
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