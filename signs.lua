courseplay.signs = {};

local deg, rad = math.deg, math.rad;
--[[ TODO
	- run updateWaypointSigns() when course has been saved
]]

local signData = {
	normal = { 10000, 'current',  4.5 }, -- orig height=5
	start =  {   500, 'current',  4.5 }, -- orig height=3
	stop =   {   500, 'current',  4.5 }, -- orig height=3
	wait =   {  1000, 'current',  4.5 }, -- orig height=3
	unload = {  2000, 'current', 4.0 },
	cross =  {  2000, 'crossing', 4.0 }
};
local diamondColors = {
	regular   = { 1.000, 0.212, 0.000, 1.000 }; -- orange
	turnStart = { 0.200, 0.900, 0.000, 1.000 }; -- green
	turnEnd   = { 0.896, 0.000, 0.000, 1.000 }; -- red
};

function courseplay.signs:setup()
	print('## Courseplay: setting up signs');

	local globalRootNode = getRootNode();

	self.buffer = {};
	self.bufferMax = {};
	self.sections = {};
	self.heightPos = {};
	self.protoTypes = {};

	for signType,data in pairs(signData) do
		self.buffer[signType] =    {};
		self.bufferMax[signType] = data[1];
		self.sections[signType] =  data[2];
		self.heightPos[signType] = data[3];

		local i3dNode = Utils.loadSharedI3DFile('img/signs/' .. signType .. '.i3d', courseplay.path);
		local itemNode = getChildAt(i3dNode, 0);
		link(globalRootNode, itemNode);
		setRigidBodyType(itemNode, 'NoRigidBody');
		setTranslation(itemNode, 0, 0, 0);
		setVisibility(itemNode, false);
		delete(i3dNode);
		self.protoTypes[signType] = itemNode;
	end;
end;


function courseplay.signs:addSign(vehicle, signType, x, z, rotX, rotY, insertIndex, distanceToNext, diamondColor)
	signType = signType or 'normal';

	local sign;
	local signFromBuffer = {};
	local receivedSignFromBuffer = courseplay.utils.table.move(self.buffer[signType], signFromBuffer);

	if receivedSignFromBuffer then
		sign = signFromBuffer[1].sign;
	else
		sign = clone(self.protoTypes[signType], true);
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
		if distanceToNext and distanceToNext > 0.01 then
			self:setWaypointSignLine(sign, distanceToNext, true);
		else
			self:setWaypointSignLine(sign, nil, false);
		end;
	end;
	setVisibility(sign, true);

	local signData = { type = signType, sign = sign, posX = x, posZ = z, rotY = rotY };
	if diamondColor and signType ~= 'cross' then
		self:setSignColor(signData, diamondColor);
	end;

	local section = self.sections[signType];
	insertIndex = insertIndex or (#vehicle.cp.signs[section] + 1);
	table.insert(vehicle.cp.signs[section], insertIndex, signData);
end;

function courseplay.signs:moveToBuffer(vehicle, vehicleIndex, signData)
	-- self = courseplay.signs
	local signType = signData.type;
	local section = self.sections[signType];

	if #self.buffer[signType] < self.bufferMax[signType] then
		setVisibility(signData.sign, false);
		courseplay.utils.table.move(vehicle.cp.signs[section], self.buffer[signType], vehicleIndex);
	else
		self:deleteSign(signData.sign);
		vehicle.cp.signs[section][vehicleIndex] = nil;
	end;

end;

function courseplay.signs:setTranslation(sign, signType, x, z)
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z);
	setTranslation(sign, x, terrainHeight + self.heightPos[signType], z);
end;

function courseplay.signs:changeSignType(vehicle, vehicleIndex, oldType, newType)
	local section = self.sections[oldType];
	local signData = vehicle.cp.signs[section][vehicleIndex];
	self:moveToBuffer(vehicle, vehicleIndex, signData);
	self:addSign(vehicle, newType, signData.posX, signData.posZ, signData.rotX, signData.rotY, vehicleIndex, nil, 'regular');
end;

function courseplay.signs:setWaypointSignLine(sign, distance, vis)
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

function courseplay.signs:updateWaypointSigns(vehicle, section)
	section = section or 'all'; --section: 'all', 'crossing', 'current'

	vehicle.cp.numWaitPoints = 0;
	vehicle.cp.numCrossingPoints = 0;
	vehicle:setCpVar('numWaypoints', #vehicle.Waypoints,courseplay.isClient);

	if section == 'all' or section == 'current' then
		local neededPoints = vehicle.cp.numWaypoints;

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
			elseif i == vehicle.cp.numWaypoints then
				neededSignType = 'stop';
			elseif wp.wait then
				neededSignType = 'wait';
			elseif wp.unload then
				neededSignType = 'unload';
			end;

			-- direction + angle
			if wp.rotX == nil then wp.rotX = 0; end;
			if wp.cy == nil or wp.cy == 0 then
				wp.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.cx, 0, wp.cz);
			end;

			if i < vehicle.cp.numWaypoints then
				np = vehicle.Waypoints[i + 1];
				if np.cy == nil or np.cy == 0 then
					np.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, np.cx, 0, np.cz);
				end;

				wp.dirX, wp.dirY, wp.dirZ, wp.distToNextPoint = courseplay:getWorldDirection(wp.cx, wp.cy, wp.cz, np.cx, np.cy, np.cz);
				if wp.distToNextPoint <= 0.01 and i > 1 then
					local pp = vehicle.Waypoints[i - 1];
					wp.dirX, wp.dirY, wp.dirZ = pp.dirX, pp.dirY, pp.dirZ;
				end;
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

			local diamondColor = 'regular';
			if wp.turnStart then
				diamondColor = 'turnStart';
			elseif wp.turnEnd then
				diamondColor = 'turnEnd';
			end;

			local existingSignData = vehicle.cp.signs.current[i];
			if existingSignData ~= nil then
				if existingSignData.type == neededSignType then
					self:setTranslation(existingSignData.sign, existingSignData.type, wp.cx, wp.cz);
					if wp.rotX and wp.rotY then
						setRotation(existingSignData.sign, wp.rotX, wp.rotY, 0);
						if neededSignType == 'normal' or neededSignType == 'start' or neededSignType == 'wait' or neededSignType == 'unload' then
							if neededSignType == 'start' or neededSignType == 'wait' or neededSignType == 'unload' then
								local signPart = getChildAt(existingSignData.sign, 1);
								setRotation(signPart, -wp.rotX, 0, 0);
							end;
							self:setWaypointSignLine(existingSignData.sign, wp.distToNextPoint, true);
						end;
						if neededSignType ~= 'cross' then
							self:setSignColor(existingSignData, diamondColor);
						end;
					end;
				else
					self:moveToBuffer(vehicle, i, existingSignData);
					self:addSign(vehicle, neededSignType, wp.cx, wp.cz, deg(wp.rotX), wp.angle, i, wp.distToNextPoint, diamondColor);
				end;
			else
				self:addSign(vehicle, neededSignType, wp.cx, wp.cz, deg(wp.rotX), wp.angle, i, wp.distToNextPoint, diamondColor);
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

function courseplay.signs:setSignColor(signData, colorName)
	if signData.type ~= 'cross' and (signData.color == nil or signData.color ~= colorName) then
		local x,y,z,w = unpack(diamondColors[colorName]);
		-- print(('setSignColor (%q): sign=%s, x=%.3f, y=%.3f, z=%.3f, w=%d'):format(colorName, tostring(signData.sign), x, y, z, w));
		setShaderParameter(signData.sign, 'diffuseColor', x,y,z,w, false);
		signData.color = colorName;
	end;
end;


function courseplay.signs:deleteSign(sign)
	unlink(sign);
	delete(sign);
end;

function courseplay.signs:setSignsVisibility(vehicle, forceHide)
	if vehicle.cp == nil or vehicle.cp.signs == nil or (#vehicle.cp.signs.current == 0 and #vehicle.cp.signs.crossing == 0) then
		return;
	end;

	local numSigns = #vehicle.cp.signs.current;
	local vis, isStartEndPoint;
	for k,signData in pairs(vehicle.cp.signs.current) do
		vis = false;
		isStartEndPoint = k <= 2 or k >= (numSigns - 2);

		if (signData.type == 'wait' or signData.type == 'unload') and (vehicle.cp.visualWaypointsStartEnd or vehicle.cp.visualWaypointsAll) then
			vis = true;
			local line = getChildAt(signData.sign, 0);
			if vehicle.cp.visualWaypointsStartEnd then
				setVisibility(line, isStartEndPoint);
			else
				setVisibility(line, true);
			end;
		else
			if vehicle.cp.visualWaypointsAll then
				vis = true;
			elseif vehicle.cp.visualWaypointsStartEnd and isStartEndPoint then
				vis = true;
			end;
		end;

		if vehicle.cp.isRecording then
			vis = true;
		elseif forceHide or not vehicle.isEntered then
			vis = false;
		end;

		setVisibility(signData.sign, vis);
	end;

	for k,signData in pairs(vehicle.cp.signs.crossing) do
		local vis = vehicle.cp.visualWaypointsCrossing;
		if forceHide or not vehicle.isEntered then
			vis = false;
		end;

		setVisibility(signData.sign, vis);
	end;
end;
