--[[
handles "mode9": Fill and empty shovel
--------------------------------------
0)  Course setup: 
	a) Start in front of silo
	b) drive forward, set waiting point #1
	c) drive forwards through silo, at end set waiting point #2
	d) drive reverse (back through silo) and turn at end
	e) drive forwards to bunker, set waiting point #3 and unload
	f) drive backwards, turn, drive forwards until before start
	
1)  drive course until waiting point #1 - set shovel to "filling" rotation
2)  [repeat] if lastFillLevel == currentFillLevel: drive ahead until is filling
2b) if waiting point #2 is reached, area is empty -> stop work
3)  if currentFillLevel == 100: set shovel to "transport" rotation, find closest point that's behind tractor, drive course from there
4)  drive course forwards until waiting point #3 - set shovel to "empty" rotation
5)  drive course with recorded direction (most likely in reverse) until end - continue and repeat to 1)
]]

function courseplay:handle_mode9(self, last_recordnumber, fill_level, allowedToDrive, dt)
	--state 1: goto BunkerSilo 
	--state 2: get ready to load / loading
	--state 3: transport to BGA 
	--state 4: get ready to unload
	--state 5: unload
	--state 6: leave BGA
	--state 7: wait for Trailer 10 before EmptyPoint
	
	--local isValid = self.cp.shovelState2Rot ~= nil and self.cp.shovelState3Rot ~= nil and self.cp.shovelState4Rot ~= nil and self.cp.shovelState5Rot ~= nil
	local isValid = self.cp.shovelStateRot ~= nil and self.cp.shovelStateRot["2"] ~= nil and self.cp.shovelStateRot["3"] ~= nil and self.cp.shovelStateRot["4"] ~= nil and self.cp.shovelStateRot["5"] ~= nil;
	if not isValid then
		self.cp.infoText = courseplay.locales.CPAssignShovel
		return false
	end
	if self.cp.tipperCapacity == nil or self.cp.tipperCapacity == 0 then
		self.cp.infoText = courseplay.locales.CPNoShovel
		return false
	end
	if self.cp.shovelFillStartPoint == nil or self.cp.shovelFillEndPoint == nil or self.cp.shovelEmptyPoint == nil then 
		self.cp.infoText = courseplay.locales.CPNoCourse
		return false
	end
	
	local mt, secondary = courseplay:getMovingTools(self)
			
	if self.recordnumber == 1 and self.cp.shovelState ~= 6 then  --backup for missed approach
		self.cp.shovelState = 1
		self.loaded = false
	end

	if self.cp.shovelState == 1 then
		if self.recordnumber + 1 > self.cp.shovelFillStartPoint then
			local hasTargetRotation = courseplay:hasTargetRotation(self, mt, secondary, self.cp.shovelStateRot["2"]);
			if hasTargetRotation ~= nil and not hasTargetRotation then
				courseplay:setMovingToolsRotation(self, dt, mt, secondary,  self.cp.shovelStateRot["2"]);
			end
			if hasTargetRotation then
				self.cp.shovelState = 2
				--print("set state 2")
			end
		end

	elseif self.cp.shovelState == 2 then
		if last_recordnumber == self.cp.shovelFillEndPoint then
			self.loaded = true;
		end
		
		if self.cp.shovelStopAndGo then
			if self.cp.shovelLastFillLevel == nil then
				self.cp.shovelLastFillLevel = fill_level;
			elseif self.cp.shovelLastFillLevel ~= nil and fill_level == self.cp.shovelLastFillLevel and fill_level < 100 then
				--allowedToDrive = true;
			elseif self.cp.shovelLastFillLevel ~= nil and self.cp.shovelLastFillLevel ~= fill_level then
				allowedToDrive = false;
			end;
			self.cp.shovelLastFillLevel = fill_level;
		end;

		if fill_level == 100 or last_recordnumber == self.cp.shovelFillEndPoint then 
			if not self.loaded then
				for i=self.recordnumber, self.maxnumber do
					local _,ty,_ = getWorldTranslation(self.rootNode)
					local _,_,z = worldToLocal(self.rootNode, self.Waypoints[i].cx , ty , self.Waypoints[i].cz)
					if z < -3 then
						--print("z taken:  "..tostring(z))
						self.recordnumber = i+1 
						self.loaded = true;
						break	
					end
				end			
			else
				local hasTargetRotation = courseplay:hasTargetRotation(self, mt, secondary, self.cp.shovelStateRot["3"]);
				if hasTargetRotation ~= nil and not hasTargetRotation then
					courseplay:setMovingToolsRotation(self, dt, mt, secondary, self.cp.shovelStateRot["3"]);
				end
				if hasTargetRotation then
					self.cp.shovelState = 3
					--print("set state 3")
				else
					allowedToDrive = false
				end


			end
		end

	elseif self.cp.shovelState == 3 then
		if last_recordnumber + 4 > self.cp.shovelEmptyPoint then
			local hasTargetRotation = courseplay:hasTargetRotation(self, mt, secondary, self.cp.shovelStateRot["4"]);
			if hasTargetRotation ~= nil and not hasTargetRotation then
				courseplay:setMovingToolsRotation(self, dt, mt, secondary, self.cp.shovelStateRot["4"]);
			end
			if hasTargetRotation then
				self.cp.shovel.trailerFound = nil
				self.cp.shovel.objectFound = nil
				self.cp.shovelState = 7
				--print("set state 7")
			end
		end
	elseif self.cp.shovelState == 7 then
		local p = self.cp.shovelEmptyPoint
		local _,ry,_ = getWorldTranslation(self.rootNode)
		local nx, nz = AIVehicleUtil.getDriveDirection(self.rootNode, self.Waypoints[p].cx, ry, self.Waypoints[p].cz);
		local lx,ly,lz = localDirectionToWorld(self.cp.DirectionNode, nx, 0, nz)
		for i=6,12 do
			local x,y,z = localToWorld(self.rootNode,0,4,i);
			raycastAll(x, y, z, lx, -1, lz, "findTrailerRaycastCallback", 10, self.cp.shovel);
			if courseplay.debugLevel > 0 then  drawDebugLine(x, y, z, 1, 0, 0, x+lx*10, y-10, z+lz*10, 1, 0, 0) end
		end
		local distance = courseplay:distance_to_point(self, self.Waypoints[p].cx, ry, self.Waypoints[p].cz)
		if self.cp.shovel.trailerFound == nil and self.cp.shovel.objectFound == nil and distance < 10 then 
			allowedToDrive = false
		elseif distance < 10 then
			self.cp.shovel.trailerFound = nil
			self.cp.shovel.objectFound = nil
			self.cp.shovelState = 4
			--print("set state 4")
		end
	elseif self.cp.shovelState == 4 then
		local x,y,z = localToWorld(self.cp.shovel.shovelTipReferenceNode,0,0,-1);
		local emptySpeed = self.cp.shovel:getShovelEmptyingSpeed()
		if emptySpeed == 0 then
			raycastAll(x, y, z, 0, -1, 0, "findTrailerRaycastCallback", 10, self.cp.shovel);
		end
	
		if self.cp.shovel.trailerFound ~= nil or self.cp.shovel.objectFound ~= nil or emptySpeed > 0 then
			--print("trailer/object found")
			local unloadAllowed = self.cp.shovel.trailerFoundSupported or self.cp.shovel.objectFoundSupported
			if unloadAllowed then
				local hasTargetRotation = courseplay:hasTargetRotation(self, mt, secondary, self.cp.shovelStateRot["5"]);
				if hasTargetRotation ~= nil and not hasTargetRotation then
					courseplay:setMovingToolsRotation(self, dt, mt, secondary, self.cp.shovelStateRot["5"]);
				end
				
				if hasTargetRotation then
					self.cp.shovelState = 5
					--print("set state 5") 
				else
					allowedToDrive = false
				end
			else	
				allowedToDrive = false
			end
		end

	elseif self.cp.shovelState == 5 then
		--courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
		courseplay:handleSpecialTools(self,self,true,nil,nil,nil,nil,nil)
		local stopUnloading = self.cp.shovel.trailerFound ~= nil and self.cp.shovel.trailerFound.fillLevel >= self.cp.shovel.trailerFound.capacity 
		if fill_level == 0 or stopUnloading then
			if self.loaded then
				for i = self.recordnumber,self.maxnumber do
					if self.Waypoints[i].rev then
						self.loaded = false
						self.recordnumber = i
						break	
					end
				end
			end
			local hasTargetRotation = courseplay:hasTargetRotation(self, mt, secondary, self.cp.shovelStateRot["4"]);
			if hasTargetRotation ~= nil and not hasTargetRotation then
				courseplay:setMovingToolsRotation(self, dt, mt, secondary, self.cp.shovelStateRot["4"]);
			end
			if hasTargetRotation and not self.Waypoints[self.recordnumber].rev then
				self.cp.shovelState = 6
				--print("set state 6")
			end	
		else
			allowedToDrive = false
		end

	elseif self.cp.shovelState == 6 then
		courseplay:handleSpecialTools(self,self,false,nil,nil,nil,nil,nil)
		local hasTargetRotation = courseplay:hasTargetRotation(self, mt, secondary, self.cp.shovelStateRot["3"]);
		if hasTargetRotation ~= nil and not hasTargetRotation then
			courseplay:setMovingToolsRotation(self, dt, mt, secondary, self.cp.shovelStateRot["3"]);
		end
		if self.recordnumber == 1 then
			self.cp.shovelState = 1
			--print("set state 1")
		end
	end
	return allowedToDrive
end

function courseplay:setMovingToolsRotation(self, dt, movingTools, secondary, targetRot)
	local curRot = courseplay:getCurrentRotation(self, movingTools, secondary)
	local changed = false;
	if curRot == nil then
		return
	end
	local primNum = table.getn(movingTools)
	for i=1, table.getn(curRot) do
		local tool 
		if i <= primNum then
			tool = movingTools[i];
		else
			tool = secondary[i-primNum]
		end

		local rotSpeed = 0.2/dt;
		if tool.rotSpeed ~= nil then
			rotSpeed = tool.rotSpeed * dt;
		end;
		
		local oldRot = curRot[i];
		local newRot = nil;
		local dir = targetRot[i] - oldRot;
		dir = math.abs(dir)/dir;
		
		if tool.node ~= nil and tool.rotMin ~= nil and tool.rotMax ~= nil and dir ~= nil and dir ~= 0 then
			newRot = Utils.clamp(oldRot + (rotSpeed * dir), tool.rotMin, tool.rotMax);
			if (dir == 1 and newRot > targetRot[i]) or (dir == -1 and newRot < targetRot[i]) then
				newRot = targetRot[i];
			end;
			if newRot ~= oldRot and newRot > tool.rotMin and newRot < tool.rotMax then
				tool.curRot[1] = newRot;
				setRotation(tool.node, unpack(tool.curRot));
				Cylindered.setDirty(self, tool);
				self:raiseDirtyFlags(self.cylinderedDirtyFlag);
				--print(string.format("%s: MT1 rot=%s, MT2 rot=%s", tostring(self.name), tostring(self.movingTools[1].curRot[1]), tostring(self.movingTools[2].curRot[1])));
				changed = true;
			end;
		end;
	end;
 
	if changed then
		for _, part in pairs(self.activeDirtyMovingParts) do
			Cylindered.setDirty(self, part);
		end;
	end;
end; 
 
function courseplay:hasTargetRotation(self, movingTools, secondary, targetRot)
	local curRot = courseplay:getCurrentRotation(self, movingTools, secondary)
	local curRotNum, targetRotNum = table.getn(curRot), table.getn(targetRot);
	if curRotNum ~= targetRotNum then
		self.cp.shovelStateRot["2"] = nil
		self.cp.shovelStateRot["3"] = nil
		self.cp.shovelStateRot["4"] = nil
		self.cp.shovelStateRot["5"] = nil
		print(self.name, ": courseplay:hasTargetRotation() return nil")
		return nil;
	end;
	local rotationsMatch = true;
	for i=1, curRotNum do
		local a, b = courseplay:round(curRot[i], 1), courseplay:round(targetRot[i], 1);
		if a ~= b then
			courseplay:debug(string.format("%s: curRot[%d]=%s (%s), targetRot[%d]=%s (%s)", self.name, i, tostring(curRot[i]), tostring(a), i, tostring(targetRot[i]), tostring(b)), 2);
			rotationsMatch = false;
			break;
		end;
	end;
	return rotationsMatch;
end; 

function courseplay:getCurrentRotation(self, movingTools, secondary)
	if movingTools == nil then
		print(self.name, ": courseplay:getCurrentRotation() return nil")
		return nil
	end
	local curRot = {}
	for i=1,table.getn(movingTools) do
		if movingTools[i].curRot ~= nil and movingTools[i].curRot[1] ~= nil then
			table.insert(curRot, movingTools[i].curRot[1]);
		end;
	end
	if secondary ~= nil then
		for i=1,table.getn(secondary) do
			if secondary[i].curRot ~= nil and secondary[i].curRot[1] ~= nil then
				table.insert(curRot, secondary[i].curRot[1]);
			end;
		end
	end
	return curRot
end

function courseplay:getMovingTools(self)
	local mt, secondary = nil, nil
	local frontLoader, shovel = 0,0
	for i=1, table.getn(self.attachedImplements) do		
		if SpecializationUtil.hasSpecialization(Shovel, self.attachedImplements[i].object.specializations) then 
			shovel = i
		elseif courseplay:isFrontloader(self.attachedImplements[i].object) then 
			frontLoader = i
		end
	end
	if shovel ~= 0 then
		mt = self.movingTools
		secondary = self.attachedImplements[shovel].object.movingTools
		self.cp.shovel = self.attachedImplements[shovel].object
	elseif frontLoader ~= 0 then
		
		local object = self.attachedImplements[frontLoader].object
		mt = object.movingTools
		if object.attachedImplements[1] ~= nil then
			secondary = object.attachedImplements[1].object.movingTools
			self.cp.shovel = object.attachedImplements[1].object
		end
	else
		mt = self.movingTools
		self.cp.shovel = self	
	end
	return mt, secondary
end