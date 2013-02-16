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
	local trigger_objects = {};
	if g_currentMission.onCreateLoadedObjects ~= nil then
		for k, trigger in pairs(g_currentMission.onCreateLoadedObjects) do
			table.insert(trigger_objects, trigger)
		end
	end
	--C.Schoch
	if g_currentMission.tipAnywhereTriggers ~= nil then
		for k, trigger in pairs(g_currentMission.tipAnywhereTriggers) do
			table.insert(trigger_objects, trigger)
		end
	end
	-- C.Schoch
	if g_currentMission.tipTriggers ~= nil then
		for k, trigger in pairs(g_currentMission.tipTriggers) do
			if trigger.isExtendedTrigger or trigger.className == "HeapTipTrigger" then
				table.insert(trigger_objects, trigger);
			end;
		end
	end;
	-- C.Schoch
	-- courseplay:debug(table.show(trigger_objects), 4);
	for k, trigger in pairs(trigger_objects) do
		--courseplay:debug(trigger.className, 3);
		if (trigger.className and (trigger.className == "SiloTrigger" or trigger.className == "HeapTipTrigger" or endswith(trigger.className, "TipTrigger") or startswith(trigger.className, "MapBGA"))) or trigger.isTipAnywhereTrigger then
			-- transformId
			if not trigger.className then
				-- little hack ;)
				trigger.className = "TipAnyWhere"
			end
			local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
			if trigger.triggerId ~= nil and trigger.triggerId == transformId and (trigger.bunkerSilo == nil or (trigger.bunkerSilo.fillLevel + tipper_capacity) < trigger.bunkerSilo.capacity) then
				courseplay:debug(table.show(trigger), 4);
				local fruitType = self.tippers[1].currentFillType

				if trigger.acceptedFillTypes[fruitType] then
					self.currentTipTrigger = trigger
				end
			elseif trigger.triggerIds ~= nil and transformId ~= nil and table.contains(trigger.triggerIds, transformId) then
				self.currentTipTrigger = trigger
			elseif trigger.specialTriggerId ~= nil and trigger.specialTriggerId == transformId then
				-- support map bga by headshot xxl
				if trigger.silage.fillLevel < trigger.silage.maxFillLevel then
					self.currentTipTrigger = trigger
				end
			end
		end
	end
end


function table.contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

function startswith(sbig, slittle)
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

function endswith(sbig, slittle)
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
