--[[ TODO
	- run updateWaypointSigns() when course has been saved
]]
local deg, rad = math.deg, math.rad;

function courseplay.utils.signs:addSign(vehicle, signType, x, z, rotX, rotY, insertIndex, distanceToNext)
	signType = signType or 'normal';

	local sign;
	local signFromBuffer = {};
	local receivedSignFromBuffer = courseplay.utils.table.move(courseplay.signs.buffer[signType], signFromBuffer);

	if receivedSignFromBuffer then
		sign = signFromBuffer[1].sign;
	else
		sign = clone(courseplay.signs.protoTypes[signType], true);
	end;

	self:setTranslation(sign, signType, x, z);
	rotX = rotX or 0;
	rotY = rotY or 0;
	setRotation(sign, rad(rotX), rad(rotY), 0);
	if signType == 'normal' or signType == 'start' or signType == 'wait' then
		if signType == 'start' or signType == 'wait' then
			local signPart = getChildAt(sign, 1);
			setRotation(signPart, rad(-rotX), 0, 0);
		end;
		if distanceToNext and distanceToNext ~= 0 then
			self:setWaypointSignLine(sign, distanceToNext, true);
		else
			self:setWaypointSignLine(sign, nil, false);
		end;
	end;
	setVisibility(sign, true);

	local signData = { type = signType, sign = sign, posX = x, posZ = z, rotY = rotY };
	local section = courseplay.signs.sections[signType];
	insertIndex = insertIndex or (#vehicle.cp.signs[section] + 1);
	table.insert(vehicle.cp.signs[section], insertIndex, signData);
end;

function courseplay.utils.signs:moveToBuffer(vehicle, vehicleIndex, signData)
	-- self = courseplay.utils.signs
	local signType = signData.type;
	local section = courseplay.signs.sections[signType];

	if #courseplay.signs.buffer[signType] < courseplay.signs.bufferMax[signType] then
		setVisibility(signData.sign, false);
		courseplay.utils.table.move(vehicle.cp.signs[section], courseplay.signs.buffer[signType], vehicleIndex);
	else
		self:deleteSign(signData.sign);
		vehicle.cp.signs[section][vehicleIndex] = nil;
	end;

end;

function courseplay.utils.signs:setTranslation(sign, signType, x, z)
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z);
	setTranslation(sign, x, terrainHeight + courseplay.signs.heightPos[signType], z);
end;

function courseplay.utils.signs:changeSignType(vehicle, vehicleIndex, oldType, newType)
	local section = courseplay.signs.sections[oldType];
	local signData = vehicle.cp.signs[section][vehicleIndex];
	self:moveToBuffer(vehicle, vehicleIndex, signData);
	self:addSign(vehicle, newType, signData.posX, signData.posZ, signData.rotX, signData.rotY, vehicleIndex);
end;

function courseplay.utils.signs:setWaypointSignLine(sign, distance, vis)
	local line = getChildAt(sign, 0);
	if line ~= 0 then
		if vis and distance ~= nil then
			setScale(line, 1, 1, distance);
		end;
		if vis ~= nil then
			setVisibility(line, vis);
		end;
	end;
end;

function courseplay.utils.signs:updateWaypointSigns(vehicle, section)
	section = section or 'all'; --section: 'all', 'crossing', 'current'

	vehicle.cp.numWaitPoints = 0;
	vehicle.cp.numCrossingPoints = 0;
	vehicle.maxnumber = #vehicle.Waypoints;

	if section == 'all' or section == 'current' then
		local neededPoints = vehicle.maxnumber;

		--move not needed ones to buffer
		if #vehicle.cp.signs.current > neededPoints then
			for j=#vehicle.cp.signs.current, neededPoints+1, -1 do --go backwards so we can safely move/delete
				local signData = vehicle.cp.signs.current[j];
				self:moveToBuffer(vehicle, j, signData);
			end;
		end;

		local np;
		for i,wp in pairs(vehicle.Waypoints) do
			local neededSignType = 'normal';
			if i == 1 then
				neededSignType = 'start';
			elseif i == vehicle.maxnumber then
				neededSignType = 'stop';
			elseif wp.wait then
				neededSignType = 'wait';
			end;

			-- direction + angle
			if wp.rotX == nil then wp.rotX = 0; end;
			if wp.cy == nil or wp.cy == 0 then
				wp.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.cx, 0, wp.cz);
			end;

			if i < vehicle.maxnumber then
				np = vehicle.Waypoints[i + 1];
				if np.cy == nil or np.cy == 0 then
					np.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, np.cx, 0, np.cz);
				end;

				wp.dirX, wp.dirY, wp.dirZ, wp.distToNextPoint = courseplay:getWorldDirection(wp.cx, wp.cy, wp.cz, np.cx, np.cy, np.cz);
				wp.rotY = Utils.getYRotationFromDirection(wp.dirX, wp.dirZ);
				wp.angle = deg(wp.rotY);

				local dy = np.cy - wp.cy;
				local dist2D = Utils.vector2Length(np.cx - wp.cx, np.cz - wp.cz);
				wp.rotX = -Utils.getYRotationFromDirection(dy, dist2D);
			else
				local pp = vehicle.Waypoints[i - 1];
				wp.dirX, wp.dirY, wp.dirZ, wp.distToNextPoint = pp.dirX, pp.dirY, pp.dirZ, 0;
				wp.rotX = 0;
				wp.rotY = pp.rotY;
			end;

			local existingSignData = vehicle.cp.signs.current[i];
			if existingSignData ~= nil then
				if existingSignData.type == neededSignType then
					self:setTranslation(existingSignData.sign, existingSignData.type, wp.cx, wp.cz);
					if wp.rotX and wp.rotY then
						setRotation(existingSignData.sign, wp.rotX, wp.rotY, 0);
						if neededSignType == 'normal' or neededSignType == 'start' or neededSignType == 'wait' then
							if neededSignType == 'start' or neededSignType == 'wait' then
								local signPart = getChildAt(existingSignData.sign, 1);
								setRotation(signPart, -wp.rotX, 0, 0);
							end;
							self:setWaypointSignLine(existingSignData.sign, wp.distToNextPoint, true);
						end;
					end;
				else
					self:moveToBuffer(vehicle, i, existingSignData);
					self:addSign(vehicle, neededSignType, wp.cx, wp.cz, deg(wp.rotX), wp.angle, i, wp.distToNextPoint);
				end;
			else
				self:addSign(vehicle, neededSignType, wp.cx, wp.cz, deg(wp.rotX), wp.angle, i, wp.distToNextPoint);
			end;

			if wp.wait then
				vehicle.cp.numWaitPoints = vehicle.cp.numWaitPoints + 1;
			end;
			if wp.crossing then
				vehicle.cp.numCrossingPoints = vehicle.cp.numCrossingPoints + 1;
			end;
		end;
	end;


	if section == 'all' or section == 'crossing' then
		--TODO: adapt to MP
		if g_currentMission.cp_courses ~= nil then -- ??? MP Ready ???
			if #vehicle.cp.signs.crossing > 0 then
				for i=#vehicle.cp.signs.crossing, 1, -1 do --go backwards so we can safely move/delete
					local signData = vehicle.cp.signs.crossing[i];
					self:moveToBuffer(vehicle, i, signData);
				end;
			end;

			for i,course in pairs(g_currentMission.cp_courses) do
				for j,wp in pairs(course.waypoints) do
					if wp.crossing then
						self:addSign(vehicle, 'cross', wp.cx, wp.cz, nil, wp.angle);
					end;
				end;
			end;
		end;
	end;

	self:setSignsVisibility(vehicle);
end;


function courseplay.utils.signs:deleteSign(sign)
	unlink(sign);
	delete(sign);
end;

function courseplay.utils.signs:setSignsVisibility(vehicle, forceHide)
	if vehicle.cp == nil or vehicle.cp.signs == nil or (#vehicle.cp.signs.current == 0 and #vehicle.cp.signs.crossing == 0) then
		return;
	end;

	local mode = vehicle.cp.visualWaypointsMode;
	-- waypointModes: 1 = Start and end, 2 = Start and end [without crossing], 3 = all own waypoints [with crossing], 4 = none
	local numSigns = #vehicle.cp.signs.current;
	for k,signData in pairs(vehicle.cp.signs.current) do
		local vis = false;

		if mode == 1 or mode == 2 then
			vis = k <= 3 or k >= (numSigns - 2) or signData.type == 'wait';
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

		if signData.type == 'wait' then
			local line = getChildAt(signData.sign, 0);
			if mode == 1 or mode == 2 then
				setVisibility(line, k <= 2 or k >= (numSigns - 2));
			elseif vis then
				setVisibility(line, true);
			end;
		end;
	end;

	for k,signData in pairs(vehicle.cp.signs.crossing) do
		local vis = mode == 1 or mode == 3;
		if forceHide or not vehicle.isEntered then
			vis = false;
		end;

		setVisibility(signData.sign, vis);
	end;
end;
