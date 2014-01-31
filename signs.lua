--[[ TODO
	- run updateWaypointSigns() when course has been saved
]]

courseplay.utils.signs = {};

function courseplay:addSign(vehicle, x, z, rotationY, signType, insertIndex)
	signType = signType or "normal";

	local sign;
	local signFromBuffer = {};
	local receivedSignFromBuffer = courseplay.utils.table.move(courseplay.signs.buffer[signType], signFromBuffer);

	if receivedSignFromBuffer then
		sign = signFromBuffer[1].sign;
	else
		local rootSign = courseplay.signs.protoTypes[signType];
		sign = clone(rootSign, true);
	end;

	courseplay.utils.signs.setTranslation(sign, signType, x, z);
	rotationY = rotationY or 0;
	if signType ~= "normal" then
		setRotation(sign, 0, math.rad(rotationY), 0);
	end;
	setVisibility(sign, true);

	local signData = { type = signType, sign = sign, posX = x, posZ = z, rotY = rotationY };
	local section = courseplay.signs.sections[signType];
	insertIndex = insertIndex or (#vehicle.cp.signs[section] + 1);
	table.insert(vehicle.cp.signs[section], insertIndex, signData);
end;

function courseplay.utils.signs.moveToBuffer(vehicle, vehicleIndex, signData)
	local signType = signData.type;
	local section = courseplay.signs.sections[signType];

	if #courseplay.signs.buffer[signType] < courseplay.signs.bufferMax[signType] then
		setVisibility(signData.sign, false);
		courseplay.utils.table.move(vehicle.cp.signs[section], courseplay.signs.buffer[signType], vehicleIndex);
	else
		courseplay.utils.signs.deleteSign(signData.sign);
		vehicle.cp.signs[section][vehicleIndex] = nil;
	end;

end;

function courseplay.utils.signs.setTranslation(sign, signType, x, z)
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z);
	setTranslation(sign, x, terrainHeight + courseplay.signs.heightPos[signType], z);
end;

function courseplay.utils.signs.changeSignType(vehicle, vehicleIndex, oldType, newType)
	local section = courseplay.signs.sections[oldType];
	local signData = vehicle.cp.signs[section][vehicleIndex];
	courseplay.utils.signs.moveToBuffer(vehicle, vehicleIndex, signData);
	courseplay:addSign(vehicle, signData.posX, signData.posZ, signData.rotY, newType, vehicleIndex);
end;

function courseplay:updateWaypointSigns(vehicle, section)
	section = section or "all"; --section: "all", "crossing", "current"

	vehicle.cp.numWaitPoints = 0;
	vehicle.cp.numCrossingPoints = 0;
	vehicle.maxnumber = #vehicle.Waypoints;

	if section == "all" or section == "current" then
		local neededPoints = vehicle.maxnumber;

		--move not needed ones to buffer
		if #vehicle.cp.signs.current > neededPoints then
			for j=#vehicle.cp.signs.current, neededPoints+1, -1 do --go backwards so we can safely move/delete
				local signData = vehicle.cp.signs.current[j];
				courseplay.utils.signs.moveToBuffer(vehicle, j, signData);
			end;
		end;

		for i,wp in pairs(vehicle.Waypoints) do
			local neededSignType = "normal";
			if i == 1 then
				neededSignType = "start";
			elseif i == vehicle.maxnumber then
				neededSignType = "stop";
			elseif wp.wait then
				neededSignType = "wait";
			end;

			local existingSignData = vehicle.cp.signs.current[i];
			if existingSignData ~= nil then
				if existingSignData.type == neededSignType then
					courseplay.utils.signs.setTranslation(existingSignData.sign, existingSignData.type, wp.cx, wp.cz);
					if existingSignData.type ~= "normal" and wp.angle then
						setRotation(existingSignData.sign, 0, math.rad(wp.angle), 0);
					end;
				else
					courseplay.utils.signs.moveToBuffer(vehicle, i, existingSignData);
					courseplay:addSign(vehicle, wp.cx, wp.cz, wp.angle, neededSignType, i);
				end;
			else
				courseplay:addSign(vehicle, wp.cx, wp.cz, wp.angle, neededSignType, i);
			end;

			if wp.wait then
				vehicle.cp.numWaitPoints = vehicle.cp.numWaitPoints + 1;
			end;
			if wp.crossing then
				vehicle.cp.numCrossingPoints = vehicle.cp.numCrossingPoints + 1;
			end;
		end;
	end;


	if section == "all" or section == "crossing" then
		--TODO: adapt to MP
		if g_currentMission.cp_courses ~= nil then -- ??? MP Ready ???
			if #vehicle.cp.signs.crossing > 0 then
				for i=#vehicle.cp.signs.crossing, 1, -1 do --go backwards so we can safely move/delete
					local signData = vehicle.cp.signs.crossing[i];
					courseplay.utils.signs.moveToBuffer(vehicle, i, signData);
				end;
			end;

			for i,course in pairs(g_currentMission.cp_courses) do
				for j,wp in pairs(course.waypoints) do
					if wp.crossing then
						courseplay:addSign(vehicle, wp.cx, wp.cz, wp.angle, "cross");
					end;
				end;
			end;
		end;
	end;

	courseplay:setSignsVisibility(vehicle);
end;


function courseplay.utils.signs.deleteSign(sign)
	unlink(sign);
	delete(sign);
end;

function courseplay:setSignsVisibility(vehicle, forceHide)
	if vehicle.cp == nil or vehicle.cp.signs == nil or (#vehicle.cp.signs.current == 0 and #vehicle.cp.signs.crossing == 0) then
		return;
	end;

	local mode = vehicle.cp.visualWaypointsMode;
	--old waypointModes: 1 = only when recording, 2 = own waypoints, 3 = without crossing points, 4 = show all, 5 = none
	--new waypointModes: 1 = Start and end, 2 = Start and end [without crossing], 3 = all own waypoints [with crossing], 4 = none
	local numSigns = #vehicle.cp.signs.current;
	for k,signData in pairs(vehicle.cp.signs.current) do
		local vis = false;

		if mode == 1 or mode == 2 then
			vis = k <= 3 or k >= (numSigns - 2) or signData.type == "wait";
		elseif mode == 3 then
			vis = true;
		elseif mode == 4 then
			vis = false;
		end;

		if vehicle.cp.isRecording then
			vis = true;
		elseif forceHide or not vehicle.isEntered then
			vis = false;
		end;

		setVisibility(signData.sign, vis);
	end;

	for k,signData in pairs(vehicle.cp.signs.crossing) do
		local vis = mode == 1 or mode == 3;
		if forceHide or not vehicle.isEntered then
			vis = false;
		end;

		setVisibility(signData.sign, vis);
	end;
end;
