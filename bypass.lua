function courseplay:isTheWayToTargetFree(self,lx,lz, targetX, targetZ )
	if lx > 0.5 then
		lx = 0.5;
	elseif lx < -0.5 then
		lx = -0.5;
	end;
	local distance = 20
	local heigth = 0.5
  -- a world point 4 m in front of the vehicle center, 0.5 m higher
  -- This is where we start checking for obstacles
	local tx, ty, tz = localToWorld(self.cp.DirectionNode,0,heigth,4)
  -- world direction 
	local nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, 0, lz)
  -- terrain height at 20 m further ahead of the 4 m point (not sure why can't we directly localToWorld to it, why nx,nz?)
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tx+(nx*distance), 0, tz+(nz*distance))
	local _, ly,_ = courseplay:getDriveDirection(self.cp.DirectionNode, tx+(nx*distance), terrainHeight, tz+(nz*distance))
  -- world normal vector towards a point 20 m ahead, considering terrain height.
  nx, ny, nz = localDirectionToWorld(self.cp.DirectionNode, lx, ly, lz)
  -- if there's a target waypoint, check the way to that point, not just dead ahead.
  if targetX and targetZ then
    local targetY = getTerrainHeightAtWorldPos( g_currentMission.terrainRootNode, targetX, 0, targetZ )
    local dx, dy, dz = targetX - tx, targetY - ty, targetZ - tz
    -- this is the distance from the front of the vehicle to the target  
    distance = Utils.vector3Length( dx, dy, dz )
    if distance > 0 then
      -- normal direction from the front of the vehicle to the target
      nx, ny, nz = dx / distance, dy / distance, dz / distance
    end
  end

  -- At this point, we have the tx, ty and tz world coordinates at the front of the vehicle
  -- and the nx, ny, nz world direction and the distance. So we'll check if there are any 
  -- obstacles from tx, ty, tz in direction nx, ny, nz within distance.

	if self.cp.foundColli ~= nil and table.getn(self.cp.foundColli) > 0  then
    -- but first take care of any previously found obstacles
		local vehicle = g_currentMission.nodeToVehicle[self.cp.foundColli[1].id];
		local vehicleSpeed = 0
		local xC,yC,zC = 0,0,0
		if vehicle == nil then
			local parent = getParent(self.cp.foundColli[1].id)
			vehicle = g_currentMission.nodeToVehicle[parent]
		end
    -- this is where the obstacle is in local coordinates
		local x,y,z = worldToLocal(self.cp.DirectionNode,self.cp.foundColli[1].x, self.cp.foundColli[1].y, self.cp.foundColli[1].z)
		local bypass = Utils.getNoNil(self.cp.foundColli[1].bp,5)
		local sideStep = x +(bypass* self.cp.foundColli[1].s)
		--y = math.max(y,4)
		xC,yC,zC = localToWorld(self.cp.DirectionNode,sideStep,y,z+bypass)
		if vehicleSpeed == 0 then
			if not self.cp.bypassWaypointsSet then
				courseplay:debug(string.format("%s setting bypassing point at x:%s, y%s, z:%s",nameNum(self) ,tostring(sideStep),tostring(y),tostring(z+bypass)),3)
				self.cp.bypassWaypointsSet = true
				self.cp.bypassWaypoints = {}
				self.cp.bypassWaypoints.x = xC
				self.cp.bypassWaypoints.y = yC
				self.cp.bypassWaypoints.z = zC
			else
				xC = self.cp.bypassWaypoints.x
				yC = self.cp.bypassWaypoints.y
				zC = self.cp.bypassWaypoints.z
			end
		else
			if courseplay.debugChannels[3] then drawDebugLine(tx, ty, tz, 1, 0, 0, tx+(nx*distance), ty+(ny*distance), tz+(nz*distance), 1, 0, 0) end;
			if self.cp.foundColli[1].s > 0 then
				raycastAll(tx, ty, tz, nx, ny, nz, "findBlockingObjectCallbackRight", distance, self)
			elseif self.cp.foundColli[1].s < 0 then
				raycastAll(tx, ty, tz, nx, ny, nz, "findBlockingObjectCallbackLeft", distance, self)
			end
		end
		if courseplay.debugChannels[3] then drawDebugPoint(xC,yC,zC, 1, 1, 1, 1) end;
		local lxC, lzC = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode,xC,yC,zC );
		if z < 0 then
			self.cp.foundColli = {}
			self.cp.bypassWaypointsSet = false
			self.cp.bypassWaypoints = {}
			courseplay:debug(nameNum(self) .."empty self.cp.foundColli ,stop bypassing",3)
			courseplay:debug("",3)
			return lx,lz
		end
		lx,lz = lxC, lzC
	else
    -- no obstacles found yet
		for i = -2 ,2,0.5 do
      -- from a world position 4 m ahead, 0.5 m higher, right, left and middle ...
			local tx, ty, tz = localToWorld(self.cp.DirectionNode,i,heigth,4)
			if courseplay.debugChannels[3] then drawDebugLine(tx, ty, tz, 1, 0, 0, tx+(nx*distance), ty+(ny*distance), tz+(nz*distance), 1, 0, 0) end ;
      -- ... look forward into the driving direction (taking into account the terrain height)
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
	or CpManager.trafficCollisionIgnoreList[transformId]
	or (self.cp.activeCombine ~= nil and self.cp.activeCombine.acI3D ~= nil and self.cp.activeCombine.acI3D == parent)
	or (self.cp.activeCombine ~= nil and (self.cp.activeCombine.rootNode == transformId or self.cp.activeCombine.rootNode == parent or self.cp.activeCombine.rootNode == parentParent ))
	or self.cpTrafficCollisionIgnoreList[transformId] or self.cpTrafficCollisionIgnoreList[parent] or self.cpTrafficCollisionIgnoreList[parentParent]
	or (self.cp.foundColli ~= nil and table.getn(self.cp.foundColli) > 0 and (self.cp.foundColli[1].id == transformId 
									      or (self.cp.foundColli[1].vehicleId ~= nil and vehicleId ~= nil
									      and self.cp.foundColli[1].vehicleId == vehicle.id)))
	then
		return true
	end
	if self.cp.activeCombine ~= nil then
		courseplay:debug(nameNum(self) .."found : "..tostring(getName(transformId)).."["..tostring(transformId).."]	self.rootNode: "..tostring(self.rootNode).."	parent: "..tostring(parent).." parentParent: "..tostring(parentParent).." self.cp.activeCombine.rootNode: "..tostring(self.cp.activeCombine.rootNode).."  self.cpTrafficCollisionIgnoreList: "..tostring(self.cpTrafficCollisionIgnoreList[transformId] or self.cpTrafficCollisionIgnoreList[parent]),3)
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
	courseplay:debug(nameNum(self) .."added : "..tostring(getName(transformId)).."["..tostring(transformId).."] to self.cp.foundColli[1] , start bypassing",3)

end
