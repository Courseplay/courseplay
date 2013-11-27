-- Field scanner
-- original algorithm by upsidedown, 24 Nov 2013

function courseplay:setUpFieldsIngameData()
	--print("call setUpIngameData()");
	courseplay.fields.fieldChannels = { g_currentMission.cultivatorChannel, g_currentMission.ploughChannel, g_currentMission.sowingChannel, g_currentMission.sowingWidthChannel };
	courseplay.fields.lastChannel = g_currentMission.cultivatorChannel;
	courseplay.fields.ingameDataSetUp = true;
end;

function courseplay:setAllFieldEdges()
	--print("call getAllFieldEdges()");
	local result = {};
	local scanStep = 5;
	local maxN = 2000;
	local numDirectionTries = 10;

	for i=1, g_currentMission.fieldDefinitionBase.numberOfFields do
		local fieldDef = g_currentMission.fieldDefinitionBase.fieldDefs[i];
		local fieldNum = fieldDef.fieldNumber;
		--local x,z = fieldDef.fieldMapHotspot.xMapPos, fieldDef.fieldMapHotspot.yMapPos;
		local x,_,z = getWorldTranslation(fieldDef.fieldBuyTrigger);
		local isField = courseplay:is_field(x, z);
		--print(string.format("fieldDef %d (fieldNum=%d): x,z=%.1f,%.1f, isField=%s", i, fieldNum, x, z, tostring(isField)));

		if isField then
			for try=1,numDirectionTries do
				local edgePoints = courseplay:getSingleFieldEdge(fieldDef.fieldBuyTrigger, scanStep, maxN, try > 1);
				if #edgePoints >= 30 then
					result[fieldNum] = {
						fieldNum = fieldNum;
						points = edgePoints;
						numPoints = #edgePoints;
						name = string.format("%s %d", courseplay.locales.COURSEPLAY_FIELD, fieldNum);
					};
					--print(string.format("Field %d: >= 30 edge points found --> valid, no retry", fieldNum));
					break;
				else
					--print(string.format("Field %d: less than 30 edge points found --> not valid, retry=%s", fieldNum, tostring(try<numDirectionTries)));
				end;
			end;
		end;
	end;
	courseplay.fields.allFieldsScanned = true;

	courseplay.fields.fieldData = result;
	courseplay.fields.numAvailableFields = #courseplay.fields.fieldData;

	--[[
	--Debug
	--print(tableShow(result, "fieldData"));
	print(tableShow(result[1], "fieldData 1"));
	]]

end;

function courseplay:getSingleFieldEdge(initObject, scanStep, maxN, randomDir)
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

		local yy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, xx, 1, zz);
		local tg = createTransformGroup("scanner");
		link(getRootNode(), tg);
		local probe1 = createTransformGroup("probe1");
		link(tg,probe1)
		setTranslation(probe1,scanStep,0,0);

		--rotate 90° against object

		local _,ry,_ = getWorldRotation(object);
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
