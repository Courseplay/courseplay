function courseplay:isTheWayToTargetFree(self,lx,lz)
	if lx > 0.5 then
		lx = 0.5;
	elseif lx < -0.5 then
		lx = -0.5;
	end;
	local distance = 20
	local heigth = 0.25
	local tx, ty, tz = localToWorld(self.cp.DirectionNode,0,heigth,4)
	local nx, _, nz = localDirectionToWorld(self.cp.DirectionNode, lx, 0, lz)
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tx+(nx*distance), 0, tz+(nz*distance))
	local _, ly,_ = courseplay:getDriveDirection(self.cp.DirectionNode, tx+(nx*distance), terrainHeight, tz+(nz*distance))
	nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, ly, lz)
	if self.cp.foundColli ~= nil and table.getn(self.cp.foundColli) > 0  then
		local vehicle = g_currentMission.nodeToVehicle[self.cp.foundColli[1].id];
		if vehicle == nil then
			local parent = getParent(self.cp.foundColli[1].id)
			vehicle = g_currentMission.nodeToVehicle[parent]
		end
		local x,y,z = 0,0,0
		if vehicle ~= nil then
			x,y,z = getWorldTranslation(vehicle.rootNode)
			x,y,z = worldToLocal(self.cp.DirectionNode,x,y,z)
		else
			x,y,z = worldToLocal(self.cp.DirectionNode,self.cp.foundColli[1].x, self.cp.foundColli[1].y, self.cp.foundColli[1].z)
		end
		local bypass = Utils.getNoNil(self.cp.foundColli[1].bp,5)
		local sideStep = x +(bypass* self.cp.foundColli[1].s)
		y = math.max(y,4)
		local xC,yC,zC = localToWorld(self.cp.DirectionNode,sideStep,y,z)
		if courseplay.debugChannels[3] then drawDebugPoint(xC,yC,zC, 1, 1, 1, 1) end;
		local lxC, lzC = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode,xC,yC,zC );
		if z < 0 then
			self.cp.foundColli = {}
			return lx,lz
		end
		if courseplay.debugChannels[3] then drawDebugLine(tx, ty, tz, 1, 0, 0, tx+(nx*distance), ty+(ny*distance), tz+(nz*distance), 1, 0, 0) end;
		if self.cp.foundColli[1].s > 0 then
			raycastAll(tx, ty, tz, nx, ny, nz, "findBlockingObjectCallbackRight", distance, self)
		elseif self.cp.foundColli[1].s < 0 then
			raycastAll(tx, ty, tz, nx, ny, nz, "findBlockingObjectCallbackLeft", distance, self)
		end
		lx,lz = lxC, lzC
	else
		for i = -2 ,2,0.5 do
			local tx, ty, tz = localToWorld(self.cp.DirectionNode,i,heigth,4)
			if courseplay.debugChannels[3] then drawDebugLine(tx, ty, tz, 1, 0, 0, tx+(nx*distance), ty+(ny*distance), tz+(nz*distance), 1, 0, 0) end ;
			if i < 0 then
				raycastAll(tx, ty, tz, nx, ny, nz, "findBlockingObjectCallbackRight", distance, self)
			elseif i > 0 then
				raycastAll(tx, ty, tz, nx, ny, nz, "findBlockingObjectCallbackLeft", distance, self)
			end
		end;
	end

	return lx,lz


end

function courseplay:findBlockingObjectCallbackRight(transformId, x, y, z, distance)
	courseplay:AnalyseRaycastResponse(self,"right",transformId, x, y, z, distance)
	return false
end

function courseplay:findBlockingObjectCallbackLeft(transformId, x, y, z, distance)
	courseplay:AnalyseRaycastResponse(self,"left",transformId, x, y, z, distance)
	return false
end

function courseplay:AnalyseRaycastResponse(self,side,transformId, x, y, z, distance)
	if courseplay.debugChannels[3] then drawDebugPoint(x, y, z, 1, 1, 1, 1) end;
	local parent = getParent(transformId)
	local parentParent = getParent(parent)
	local vehicle = g_currentMission.nodeToVehicle[transformId];
	if vehicle == nil then
		vehicle = g_currentMission.nodeToVehicle[parent]
	end
	local sideFactor = 1
	local idName = getName(transformId)
	if side == "left" then
		sideFactor = -1
	end
	
	if transformId == g_currentMission.terrainRootNode or parent == g_currentMission.terrainRootNode 
	or (self.active_combine ~= nil and (self.active_combine.rootNode == transformId or self.active_combine.rootNode == parent or self.active_combine.rootNode == parentParent ))
	or self.cpTrafficCollisionIgnoreList[transformId] or self.cpTrafficCollisionIgnoreList[parent] or self.cpTrafficCollisionIgnoreList[parentParent]
	or (self.cp.foundColli ~= nil and table.getn(self.cp.foundColli) > 0 and (self.cp.foundColli[1].id == transformId 
									      or (self.cp.foundColli[1].vehicleId ~= nil and vehicleId ~= nil
									      and self.cp.foundColli[1].vehicleId == vehicle.id)))
	then
		return true
	end
	if self.active_combine ~= nil then
		courseplay:debug(nameNum(self) .."found : "..tostring(getName(transformId)).."["..tostring(transformId).."]	self.rootNode: "..tostring(self.rootNode).."	parent: "..tostring(parent).."	self.active_combine.rootNode: "..tostring(self.active_combine.rootNode).."  self.cpTrafficCollisionIgnoreList: "..tostring(self.cpTrafficCollisionIgnoreList[transformId] or self.cpTrafficCollisionIgnoreList[parent]),3)	
	else
		courseplay:debug(nameNum(self) .."found : "..tostring(getName(transformId)).."["..tostring(transformId).."]	self.rootNode: "..tostring(self.rootNode).."	parent: "..tostring(parent).."  self.cpTrafficCollisionIgnoreList: "..tostring(self.cpTrafficCollisionIgnoreList[transformId] or self.cpTrafficCollisionIgnoreList[parent]),3)	
	end
	self.cp.foundColli ={}
	self.cp.foundColli[1] = {}
	self.cp.foundColli[1].x = x
	self.cp.foundColli[1].y = y
	self.cp.foundColli[1].z = z
	self.cp.foundColli[1].s = sideFactor
	self.cp.foundColli[1].id = transformId
	if vehicle ~= nil then
		self.cp.foundColli[1].bp = math.sqrt(vehicle.sizeLength^2 + vehicle.sizeWidth^2)
		self.cp.foundColli[1].vehicleId = vehicle.id
	end
	

end