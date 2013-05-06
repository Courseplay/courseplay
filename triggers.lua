-- triggers

-- traffic collision
function courseplay:cponTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if otherId == self.rootNode then
		return
	end
	if onEnter or onLeave then
		if otherId == Player.rootNode then
			if onEnter then
				self.CPnumCollidingVehicles = self.CPnumCollidingVehicles + 1;
				self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1;
 			elseif onLeave then
				self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles - 1, 0);
				self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0);
 
			end;
		else
			courseplay:debug("found trigger",1)
			local vehicle = g_currentMission.nodeToVehicle[otherId];
			local vehicleConcerned = g_currentMission.nodeToVehicle[otherId]
			local vehicleOnList = false
			if vehicle ~= nil then
				courseplay:debug("checking CollisionIgnoreList",1)
				for a,b in pairs (self.cpTrafficCollisionIgnoreList) do
					courseplay:debug(tostring(g_currentMission.nodeToVehicle[a].name).." vs "..tostring(vehicleConcerned.name),1)
					if g_currentMission.nodeToVehicle[a].id == vehicleConcerned.id then
						courseplay:debug(tostring(vehicleConcerned.name).." is on list",1)
						vehicleOnList = true
						break		
					end
				end
			end
			if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil and vehicleOnList == false then
				if onEnter then
					courseplay:debug(tostring(vehicleConcerned.name).." is not on list",1)
					self.traffic_vehicle_in_front = otherId
					self.CPnumCollidingVehicles = self.CPnumCollidingVehicles + 1;
					self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1;
				elseif onLeave then
					self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles - 1, 0);
					self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0);
 				end;
			end;
		end;
	end;
end

-- tip trigger
function courseplay:findTipTriggerCallback(transformId, x, y, z, distance)
	--C.Schoch
	--local trigger_objects = g_currentMission.onCreateLoadedObjects
	local allowPrint = false
	if courseplay.debugLevel > 0 then
		allowPrint = true
	end
	if self.currentTipTrigger ~= nil then 
		allowPrint = false
	end
	local trigger_objects = {};
	if g_currentMission.onCreateLoadedObjects ~= nil then
		for k, trigger in pairs(g_currentMission.onCreateLoadedObjects) do
			table.insert(trigger_objects, trigger)
		end
	end
	
	if g_currentMission.placeables ~= nil then
		for xml, placeable in pairs(g_currentMission.placeables) do
			if Utils.endsWith(xml, "placeableheap.xml") then
				for k, trigger in pairs(placeable) do
					if (trigger.className and Utils.endsWith(trigger.className, "PlaceableHeap")) then
						--https://gist.github.com/JakobTischler/913f94f8b43c8c1afb79
						trigger.isPlaceableHeapTrigger = true;
						table.insert(trigger_objects, trigger)
					end;
				end;
			end;
		end
	end

	-- C.Schoch
	if g_currentMission.tipTriggers ~= nil then
		for k, trigger in pairs(g_currentMission.tipTriggers) do
			if trigger.isExtendedTrigger then
				trigger.isAlternativeTipTrigger = Utils.endsWith(trigger.className, "ExtendedTipTrigger");
				table.insert(trigger_objects, trigger);
			end;
		end
	end;
	-- C.Schoch
	-- courseplay:debug(table.show(trigger_objects), 4);

	if self.cp.lastCheckedTransformID ~= transformId then
		local name = getParent(transformId)
		if allowPrint then print("checking "..tostring(getName(name))) end
		if allowPrint then print("transformId:"..tostring(transformId).." name: "..tostring(getName(transformId))) end
		for k, trigger in pairs(trigger_objects) do
			--courseplay:debug(trigger.className, 3);
			if (trigger.className and (trigger.className == "SiloTrigger" or trigger.isPlaceableHeapTrigger or Utils.endsWith(trigger.className, "TipTrigger"))) then
				if allowPrint then print("	is Trigger") end
				-- transformId
				local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity();
				local fruitType = self.tippers[1].currentFillType;
				
				--AlternativeTipping
				if trigger.isAlternativeTipTrigger then
					fruitType = FruitUtil.fillTypeToFruitType[fruitType];
				end;
				if allowPrint then print("	checking Fruittype  "..tostring(fruitType)) end
				if transformId ~= nil and trigger.acceptedFillTypes ~= nil and trigger.acceptedFillTypes[fruitType] then
					if allowPrint then print("		accepted fruittype") end
					if allowPrint then print("		checking with: "..tostring(trigger.triggerId)) end
					if trigger.triggerId ~= nil and trigger.triggerId == transformId then
						if allowPrint then print("			is valid") end
						if allowPrint then print("			checking trigger.isAlternativeTipTrigger : "..tostring(trigger.isAlternativeTipTrigger)) end  
						if not trigger.isAlternativeTipTrigger or (trigger.isAlternativeTipTrigger and trigger.currentFillType == fruitType) then
							if allowPrint then print("				insert TipTrigger") end
							self.currentTipTrigger = trigger;
						end;
					elseif trigger.triggerIds ~= nil and table.contains(trigger.triggerIds, transformId) then
						self.currentTipTrigger = trigger
					elseif trigger.isPlaceableHeapTrigger and trigger.tipTriggerId ~= nil and trigger.tipTriggerId == transformId then
						self.currentTipTrigger = trigger;
						--print("currentTipTrigger=", tostring(self.currentTipTrigger), ", fruitType allowed = ", tostring(self.currentTipTrigger.acceptedFillTypes[self.tippers[1].currentFillType]));
					else 
						if allowPrint then print("			not valid") end
					end;
				else
					if allowPrint then print("		no valid fruittype") end
				end;
			end;
		end;
		self.cp.lastCheckedTransformID = transformId;
	end;
end;

function table.contains(table, element) --TODO: always use Utils.hasListElement
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

function startswith(sbig, slittle) --TODO: always use Utils.startsWith
	if type(slittle) == "table" then
		for k, v in ipairs(slittle) do
			if string.sub(sbig, 1, string.len(v)) == v then
				return true
			end
		end
		return false
	end
	return string.sub(sbig, 1, string.len(slittle)) == slittle
end

function endswith(sbig, slittle) --TODO: always use Utils.endsWith
	if type(slittle) == "table" then
		for k, v in ipairs(slittle) do
			if string.sub(sbig, string.len(sbig) - string.len(v) + 1) == v then
				return true
			end
		end
		return false
	end
	return string.sub(sbig, string.len(sbig) - string.len(slittle) + 1) == slittle
end
