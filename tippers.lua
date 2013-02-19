﻿function courseplay:detachImplement(implementIndex)
	self.tools_dirty = true;
end

function courseplay:reset_tools(self)
	self.tippers = {}
	-- are there any tippers?
	self.tipper_attached = courseplay:update_tools(self, self)
	self.currentTrailerToFill = nil
	self.lastTrailerToFillDistance = nil
	self.tools_dirty = false;
end

function courseplay:is_baler(workTool) -- is the tool a baler?
	return (SpecializationUtil.hasSpecialization(Baler, workTool.specializations) or workTool.balerUnloadingState ~= nil);
end;
function courseplay:is_baleLoader(workTool) -- is the tool a bale loader?
	return (SpecializationUtil.hasSpecialization(baleLoader, workTool.specializations) or SpecializationUtil.hasSpecialization(BaleLoader, workTool.specializations));
end;
function courseplay:is_sowingMachine(workTool) -- is the tool a sowing machine?
	return (SpecializationUtil.hasSpecialization(sowingMachine, workTool.specializations) or SpecializationUtil.hasSpecialization(SowingMachine, workTool.specializations));
end;
function courseplay:isFoldable(workTool) --is the tool foldable?
	return SpecializationUtil.hasSpecialization(Foldable, workTool.specializations) or SpecializationUtil.hasSpecialization(foldable, workTool.specializations);
end;
function courseplay:isUBT(workTool) --is the tool a UBT?
	return SpecializationUtil.hasSpecialization(ubt, workTool.specializations);
end;

-- update implements to find attached tippers
function courseplay:update_tools(self, tractor_or_implement)
	--steerable (tractor, combine etc.)
	local tipper_attached = false
	if SpecializationUtil.hasSpecialization(AITractor, tractor_or_implement.specializations) then
		local object = tractor_or_implement
		if self.ai_mode == 1 or self.ai_mode == 2 then
			-- if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 3 then -- Overlader
			if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then --to do
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 4 then -- Fertilizer
			if SpecializationUtil.hasSpecialization(Sprayer, object.specializations) or courseplay:is_sowingMachine(object) or object.name == "AmazoneUX5200" then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 6 then -- Baler, foragewagon, baleloader
			if courseplay:is_baler(object) 
			or courseplay:is_baleLoader(object) 
			or SpecializationUtil.hasSpecialization(Tedder, object.specializations) 
			or SpecializationUtil.hasSpecialization(windrower, object.specializations) 
			or SpecializationUtil.hasSpecialization(cultivator, object.specializations) 
			or SpecializationUtil.hasSpecialization(plough, object.specializations) 
			or object.allowTipDischarge 
			or courseplay:isUBT(object) 
			or courseplay:isFoldable(object) then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 8 then -- Baler, foragewagon, baleloader
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(self.tippers, object)
			-- end
		end
	end


	-- go through all implements
	self.cpTrafficCollisionIgnoreList = {}
	for k, implement in pairs(tractor_or_implement.attachedImplements) do
		local object = implement.object
		
		--in front or in the back?
		if object.cp == nil then
			object.cp = {};
		end;
		local impXw, impYw, impZw = getWorldTranslation(object.rootNode);
		local vehToImpX, vehToImpY, vehToImpZ = worldToLocal(self.rootNode, impXw, impYw, impZw);
		if vehToImpZ > 0 then --implement in front of vehicle
			object.cp.positionToVehicle = 1;
			--print(string.format("Implement %s position = %d (in front) (vehToImpZ = %f)", object.name, object.cp.positionToVehicle, vehToImpZ));
		else
			object.cp.positionToVehicle = -1;
			--print(string.format("Implement %s position = %d (in back) (vehToImpZ = %f)", object.name, object.cp.positionToVehicle, vehToImpZ));
		end;
		--END in front or in the back

		if self.ai_mode == 1 or self.ai_mode == 2 then
			--	if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 3 then -- Overlader
			if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then --to do 
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 4 then -- Fertilizer and Seeding
			if SpecializationUtil.hasSpecialization(Sprayer, object.specializations) or courseplay:is_sowingMachine(object) or object.name == "AmazoneUX5200" then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 5 then -- Überführung
			if object.setPlane ~= nil then --open/close cover
				tipper_attached = true;
				table.insert(self.tippers, object);
			end;
		elseif self.ai_mode == 6 then -- Baler, foragewagon, baleloader
			if courseplay:is_baler(object) 
			or courseplay:is_baleLoader(object) 
			or SpecializationUtil.hasSpecialization(Tedder, object.specializations) 
			or SpecializationUtil.hasSpecialization(windrower, object.specializations) 
			or SpecializationUtil.hasSpecialization(cultivator, object.specializations) 
			or SpecializationUtil.hasSpecialization(plough, object.specializations) 
			or object.allowTipDischarge 
			or courseplay:isUBT(object) 
			or courseplay:isFoldable(object) then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 8 then -- Baler, foragewagon, baleloader
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(self.tippers, object)
			--		end
		end

		-- are there more tippers attached to the current implement?
		local other_tipper_attached
		if table.getn(object.attachedImplements) ~= 0 then
			other_tipper_attached = courseplay:update_tools(self, object)
		end
		if other_tipper_attached == true then
			tipper_attached = true
		end
		
		courseplay:debug(string.format("courseplay:update_tools() (%s)", self.name), 2);

		for k,v in pairs(self.components) do --TODO: self.components needed?
			self.cpTrafficCollisionIgnoreList[v.node] = true;
		end;
		courseplay:debug(tostring(object.name).." - adding to cpTrafficCollisionIgnoreList", 2)
		self.cpTrafficCollisionIgnoreList[object.rootNode] = true;
	end; --END for implement in attachedImplements

	if CPDebugLevel > 0 then
		print(string.format("%s cpTrafficCollisionIgnoreList", self.name));
		for a,b in pairs(self.cpTrafficCollisionIgnoreList) do
			local name = g_currentMission.nodeToVehicle[a].name
			print(string.format("\\___ %s = %s", tostring(a), tostring(name)));
		end;
	end

	courseplay:getAutoTurnradius(self, tipper_attached);
	
	--tipreferencepoints 
	self.tipRefOffset = 0;
	if tipper_attached and self.tippers[1].rootNode ~= nil and self.tippers[1].tipReferencePoints ~= nil then
		local tipperX, tipperY, tipperZ = getWorldTranslation(self.tippers[1].rootNode);
		if tipper_attached and table.getn(self.tippers[1].tipReferencePoints) > 1 then
			for n=1 ,table.getn(self.tippers[1].tipReferencePoints) do
				local tipRefPointX, tipRefPointY, tipRefPointZ = worldToLocal(self.tippers[1].tipReferencePoints[n].node, tipperX, tipperY, tipperZ);
				tipRefPointX = math.abs(tipRefPointX);
				if tipRefPointX > 0.1 then
					self.tipRefOffset = tipRefPointX;
					break;
				end;
			end;
		else 
			self.tipRefOffset = 0;
		end;
	end;


	--tippers with covers
	self.cp.tipperHasCover = false;
	self.cp.tippersWithCovers = nil;
	self.cp.tippersWithCovers = {};
	--courseplay:debug(self.name .. ": tipper_attached = ".. tostring(tipper_attached), 3);
	if tipper_attached then
		for i=1, table.getn(self.tippers) do
			if self.tippers[i].setPlane ~= nil then
				courseplay:debug(string.format("Implement \"%s\" has a cover (setPlane ~= nil)", self.tippers[i].name), 3);
				self.cp.tipperHasCover = true;
				table.insert(self.cp.tippersWithCovers, i);
			else
				courseplay:debug(string.format("Implement \"%s\" doesn't have a cover (setPlane == nil)", self.tippers[i].name), 3);
			end;
		end;
	end;
	courseplay:debug(tableShow(self.cp.tippersWithCovers, self.name .. ": self.cp.tippersWithCovers"), 4);
	--END tippers with covers
	
	
	if tipper_attached then
		return true
	end
	return nil
end

-- loads all tippers
function courseplay:load_tippers(self)
	local allowedToDrive = false
	local cx, cz = self.Waypoints[2].cx, self.Waypoints[2].cz
	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	if tipper_fill_level == nil then tipper_fill_level = 0 end
	if tipper_capacity == nil then tipper_capacity = 0 end
	local fill_level = 0
	if tipper_capacity ~= 0 then
		fill_level = tipper_fill_level * 100 / tipper_capacity
	end

	if self.currentTrailerToFill == nil then
		self.currentTrailerToFill = 1
	end

	-- drive on when required fill level is reached
	local drive_on = false
	if self.timeout < self.timer or self.last_fill_level == nil then
		if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level > self.required_fill_level_for_follow then
			drive_on = true
		end
		self.last_fill_level = fill_level
		courseplay:set_timeout(self, 7000)
	end

	if fill_level == 100 or drive_on then
		self.last_fill_level = nil
		self.loaded = true
		self.lastTrailerToFillDistance = nil
		self.currentTrailerToFill = nil
		return true
	end

	if self.lastTrailerToFillDistance == nil then

		local current_tipper = self.tippers[self.currentTrailerToFill]

		-- drive on if actual tipper is full
		if current_tipper.fillLevel == current_tipper.capacity then
			if table.getn(self.tippers) > self.currentTrailerToFill then
				local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.currentTrailerToFill].rootNode)

				self.lastTrailerToFillDistance = courseplay:distance(cx, cz, tipper_x, tipper_z)

				self.currentTrailerToFill = self.currentTrailerToFill + 1
			else
				self.currentTrailerToFill = nil
				self.lastTrailerToFillDistance = nil
			end
			allowedToDrive = true
		end

	else
		local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.currentTrailerToFill].rootNode)

		local distance = courseplay:distance(cx, cz, tipper_x, tipper_z)

		if distance > self.lastTrailerToFillDistance and self.lastTrailerToFillDistance ~= nil then
			allowedToDrive = true
		else
			allowedToDrive = false
			local current_tipper = self.tippers[self.currentTrailerToFill]
			if current_tipper.fillLevel == current_tipper.capacity then
				if table.getn(self.tippers) > self.currentTrailerToFill then
					local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.currentTrailerToFill].rootNode)
					self.lastTrailerToFillDistance = courseplay:distance(cx, cz, tipper_x, tipper_z)
					self.currentTrailerToFill = self.currentTrailerToFill + 1
				else
					self.currentTrailerToFill = nil
					self.lastTrailerToFillDistance = nil
				end
			end
		end
	end

	-- normal mode if all tippers are empty
	return allowedToDrive
end

-- unloads all tippers
function courseplay:unload_tippers(self)
	local allowedToDrive = true
	for k, tipper in pairs(self.tippers) do
		--if not tipper.allowsDetaching then
		local numReferencePoints = table.getn(tipper.tipReferencePoints);
		local fruitType = tipper.currentFillType

		if self.currentTipTrigger.bunkerSilo ~= nil then
			
			local silos = table.getn(self.currentTipTrigger.bunkerSilo.movingPlanes)
			local x, y, z = getWorldTranslation(tipper.tipReferencePoints[1].node)
			local sx, sy, sz = worldToLocal(self.currentTipTrigger.bunkerSilo.movingPlanes[1].nodeId, x, y, z)
			local ex, ey, ez = worldToLocal(self.currentTipTrigger.bunkerSilo.movingPlanes[silos].nodeId, x, y, z)
			self.startentfernung =  Utils.vector2Length(sx, sz) 
			self.endentfernung = Utils.vector2Length(ex, ez)
			local laenge = courseplay:distance(sx, sz, ex, ez) 
			self.position = self.startentfernung*100/laenge
			self.gofortipping = false
			if self.runonce == nil then
				self.runonce = 0
			end
			self.filling1 = 0
			self.filling2 = 0
			self.filling3 = 0
			if self.runonce == 0 then
				if self.startentfernung < self.endentfernung then   --Richtungsentscheidung
					self.BGAdirection = 1   --vorwärts
				else	
					self.BGAdirection = 0   --rückwärts
				end
				for k = 1,silos,1 do
					local filling = self.currentTipTrigger.bunkerSilo.movingPlanes[k].fillLevel
					if k <= math.ceil(silos * 0.3) then
						self.filling1 =	self.filling1 + filling
						--print(tostring(k)..":1:"..tostring(self.filling1))
					elseif k <= math.ceil(silos * 0.6) then
						self.filling2 =	self.filling2 + filling
						--print(tostring(k)..":2:"..tostring(self.filling2))
					elseif k <= silos then 
						self.filling3 =	self.filling3 + filling
						--print(tostring(k)..":3:"..tostring(self.filling3))
					end
				end;
				print(string.format("bga section 1: %f, bga section 3: %f, bga section 3: %f", self.filling1, self.filling2, self.filling3));
				
				if self.filling1 <= self.filling2 and self.filling1 < self.filling3 then
					self.tipLocation = 1
				elseif self.filling2 <= self.filling3 and self.filling2 < self.filling1 then
					self.tipLocation = 2
				elseif self.filling3 < self.filling1 and self.filling3 < self.filling2 then
					self.tipLocation = 3
				else
					self.tipLocation = 1
				end
				print(string.format("BGA tipLocation = %d", self.tipLocation));
				self.runonce = 1
			end
			if self.tipLocation == 1 then
				if self.position >= 0 and self.position <= 40 then
					self.gofortipping = true
				end
			elseif self.tipLocation == 2 then
				if self.position >= 30 and self.position <= 70 then
					self.gofortipping = true
				end
			elseif self.tipLocation == 3 then
				if self.position >= 60 then
					self.gofortipping = true
				end
			end
		else
			self.gofortipping = true
		end
		if self.currentTipTrigger.acceptedFillTypes[fruitType] and self.gofortipping == true then  
			if tipper.tipState == Trailer.TIPSTATE_CLOSED then
				if self.currentTipTrigger:getTipDistanceFromTrailer(tipper, tipper.currentTipReferencePointIndex)  == 0 or self.currentTipTrigger.bunkerSilo ~= nil then   --courtesy of Satis
					if self.toggledTipState < numReferencePoints then
						self.toggledTipState = self.toggledTipState +1
						tipper:toggleTipState(self.currentTipTrigger,self.toggledTipState);
						self.unloading_tipper = tipper
					else
						self.toggledTipState = 0
					end
				end
			elseif tipper.tipState ~= Trailer.TIPSTATE_CLOSING then 
				allowedToDrive = false
			end 
					
			if self.currentTipTrigger.bunkerSilo ~= nil then
				allowedToDrive = true
			end
		else
			courseplay:debug("trigger does not accept fruit or self.gofortipping = false(BGA) ", 1);
		end
	end
	return allowedToDrive
end

function courseplay:getAutoTurnradius(self, tipper_attached)
	local sinAlpha = 0       --Sinus vom Lenkwinkel
	local wheelbase = 0      --Radstand
	local track = 0		 --Spurweite
	local turnRadius         --Wendekreis unbereinigt
	if self.foundWheels == nil then
		self.foundWheels = {}
	end
	for i=1,#self.wheels do
		local wheel =  self.wheels[i]
		if wheel.rotMax ~= 0 then
			if self.foundWheels[1] == nil then
				sinAlpha = wheel.rotMax
				self.foundWheels[1] = wheel
			elseif self.foundWheels[2] == nil then
				self.foundWheels[2] = wheel
			end
		elseif self.foundWheels[3] == nil then
			self.foundWheels[3] = wheel
		end
	
	end
	if table.getn(self.foundWheels) == 3 then
		local wh1X, wh1Y, wh1Z = getWorldTranslation(self.foundWheels[1].driveNode);
		local wh2X, wh2Y, wh2Z = getWorldTranslation(self.foundWheels[2].driveNode);	
		local wh3X, wh3Y, wh3Z = getWorldTranslation(self.foundWheels[3].driveNode);	 
		track  = courseplay:distance(wh1X, wh1Z, wh2X, wh2Z)
		wheelbase = courseplay:distance(wh1X, wh1Z, wh3X, wh3Z)
		turnRadius = 2*wheelbase/sinAlpha+track
		self.foundWheels = {}	
	else
		turnRadius = self.turn_radius                  -- Kasi and Co are not supported. Nobody does hauling with a Kasi or Quadtrack !!! 
	end	
	if tipper_attached then
		local n = table.getn(self.tippers)
		if n == 1 then
			if self.tippers[1].attacherVehicle ~= self then
				self.autoTurnRadius = turnRadius * 2 --Dolly
			else
				self.autoTurnRadius = turnRadius --normaler Trailer
			end
		else
			self.autoTurnRadius = (turnRadius * n) -->1 Trailers
		end
	else
		self.autoTurnRadius = turnRadius
	end

	if self.turnRadiusAutoMode then
		self.turn_radius = self.autoTurnRadius;
	end;
end
