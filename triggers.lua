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
			courseplay:debug(string.format("%s: found collision trigger", nameNum(self)), 3);
			local vehicle = g_currentMission.nodeToVehicle[otherId];
			local vehicleConcerned = g_currentMission.nodeToVehicle[otherId]
			local vehicleOnList = false
			if vehicle ~= nil then
				courseplay:debug(string.format("%s: checking CollisionIgnoreList", nameNum(self)), 3);
				for a,b in pairs (self.cpTrafficCollisionIgnoreList) do
					courseplay:debug(string.format("%s: %s vs %s", nameNum(self), tostring(g_currentMission.nodeToVehicle[a].name), tostring(vehicleConcerned.name)), 3);
					if g_currentMission.nodeToVehicle[a].id == vehicleConcerned.id then
						courseplay:debug(string.format("%s: %s is on list", nameNum(self), tostring(vehicleConcerned.name)), 3);
						vehicleOnList = true
						break		
					end
				end
			end
			if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil and vehicleOnList == false then
				if onEnter then
					courseplay:debug(string.format("%s: %s is not on list", nameNum(self), tostring(vehicleConcerned.name)), 3);
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
	if courseplay.debugChannels[1] then
		drawDebugPoint( x, y, z, 1, 1, 0, 1);
	end;

	if courseplay.confirmedNoneTriggers[transformId] == true then
		return true
	end

	local triggerObjects, triggerObjectsCount = courseplay.triggerObjects, courseplay.triggerObjectsCount
	local name = getName(transformId)	
	if triggerObjects ~= nil and triggerObjectsCount > 0 then
		courseplay:debug(nameNum(self) .. " transformId = ".. tostring(transformId)..": "..tostring(name), 1);
		local fruitType = self.tippers[1].currentFillType;

		if transformId ~= nil then
			local trigger = triggerObjects[transformId];

			if trigger ~= nil then
				if trigger.bunkerSilo ~= nil and trigger.bunkerSilo.state ~= 0 then 
					courseplay:debug(nameNum(self) .. ": bunkerSilo.state ~= 0 -> ignoring trigger", 1);
					return true
				end
				if self.cp.hasShield and trigger.bunkerSilo == nil then
					courseplay:debug(nameNum(self) .. ": has silage shield and trigger is not BGA -> ignoring trigger", 1);
					return true
				end	
						
				local triggerId = trigger.triggerId;
				if triggerId == nil then
					triggerId = trigger.tipTriggerId;
				end;
				courseplay:debug(string.format("%s: transformId %s is in triggerObjects (#%s) (triggerId=%s)", nameNum(self), tostring(transformId), tostring(triggerObjectsCount), tostring(triggerId)), 1);

				if trigger.isAlternativeTipTrigger then
					fruitType = FruitUtil.fillTypeToFruitType[fruitType];
				end;

				if trigger.acceptedFillTypes ~= nil and trigger.acceptedFillTypes[fruitType] then
					courseplay:debug(string.format("%s: trigger %s accepts fruit (%s)", nameNum(self), tostring(triggerId), tostring(fruitType)), 1);
					local fillTypeIsValid = true;
					if trigger.isAlternativeTipTrigger then
						fillTypeIsValid = trigger.currentFillType == 0 or trigger.currentFillType == fruitType;
						courseplay:debug(string.format("%s: AlternativeTipTrigger %s's current fruit == trailer fruit = %s", nameNum(self), tostring(triggerId), tostring(fillTypeIsValid)), 1);
					elseif trigger.isPlaceableHeapTrigger then
						fillTypeIsValid = trigger.fillType == 0 or trigger.fillType == fruitType;
						courseplay:debug(string.format("%s: PlaceableHeapTrigger %s's current fruit == trailer fruit = %s", nameNum(self), tostring(triggerId), tostring(fillTypeIsValid)), 1);
					end;

					if fillTypeIsValid then
						courseplay:debug(string.format("%s: self.cp.currentTipTrigger = %s", nameNum(self), tostring(triggerId)), 1);
						self.cp.currentTipTrigger = trigger;
						return false
					end;
				elseif trigger.acceptedFillTypes ~= nil then
					if trigger.isAlternativeTipTrigger then
						courseplay:debug(string.format("%s: trigger %s (AlternativeTipTrigger) does not accept fruit (%s)", nameNum(self), tostring(triggerId), tostring(fruitType)), 1);
					else
						courseplay:debug(string.format("%s: trigger %s does not accept fruit (%s)", nameNum(self), tostring(triggerId), tostring(fruitType)), 1);
					end;
					courseplay:debug(string.format("%s: trigger %s does only accept fruit:", nameNum(self), tostring(triggerId)), 1);
					if courseplay.debugChannels[1] then
						courseplay:printTipTriggersFruits(trigger)
					end
				else
					courseplay:debug(string.format("%s: trigger %s does not have acceptedFillTypes (fruitType=%s)", nameNum(self), tostring(triggerId), tostring(fruitType)), 1);
				end;
			else
				courseplay.confirmedNoneTriggers[transformId] = true
				courseplay.confirmedNoneTriggersCounter = courseplay.confirmedNoneTriggersCounter +1
				courseplay:debug(string.format("%s: added %s to blacklist", nameNum(self), tostring(name)), 1);
				courseplay:debug("courseplay.confirmedNoneTriggers:  "..tostring(courseplay.confirmedNoneTriggersCounter),1);
			end;
		end;
	end;
	return true
end;

function courseplay:getAllTipTriggers()
	local triggerObjects = {};
	local triggerObjectsCount = 0;
	
	--onCreate objects
	if g_currentMission.onCreateLoadedObjects ~= nil then
		for k, trigger in pairs(g_currentMission.onCreateLoadedObjects) do
			local triggerId = trigger.triggerId;
			if triggerId ~= nil and courseplay:isValidTipTrigger(trigger) then
				triggerObjects[triggerId] = trigger;
				triggerObjectsCount = triggerObjectsCount + 1;
			end;
		end
	end
	
	--placeables objects
	if g_currentMission.placeables ~= nil then
		for xml, placeable in pairs(g_currentMission.placeables) do
			if Utils.endsWith(xml, "placeableheap.xml") then
				for k, trigger in pairs(placeable) do
					if courseplay:isValidTipTrigger(trigger) and Utils.endsWith(trigger.className, "PlaceableHeap") then
						trigger.isPlaceableHeapTrigger = true;
						local triggerId = trigger.tipTriggerId;
						if triggerId ~= nil then
							triggerObjects[triggerId] = trigger;
							triggerObjectsCount = triggerObjectsCount + 1;
						end;
					end;
				end;
			end;
		end
	end

	--tipTriggers objects
	if g_currentMission.tipTriggers ~= nil then
		for k, trigger in pairs(g_currentMission.tipTriggers) do
			if trigger.isExtendedTrigger and courseplay:isValidTipTrigger(trigger) then
				trigger.isAlternativeTipTrigger = Utils.endsWith(trigger.className, "ExtendedTipTrigger");
				local triggerId = trigger.triggerId;
				if triggerId ~= nil then
					triggerObjects[triggerId] = trigger;
					triggerObjectsCount = triggerObjectsCount + 1;
				end;
			end;
		end
	end;
	courseplay.triggerObjects = {}
	courseplay.triggerObjects = triggerObjects 
	courseplay.triggerObjectsCount = triggerObjectsCount
end;

function courseplay:isValidTipTrigger(trigger)
	return trigger.className and (trigger.className == "SiloTrigger" or trigger.isPlaceableHeapTrigger or trigger.isAlternativeTipTrigger or Utils.endsWith(trigger.className, "TipTrigger") or Utils.endsWith(trigger.className, "PlaceableHeap"));
end;


function courseplay:printTipTriggersFruits(trigger)
	for k,v in pairs(trigger.acceptedFillTypes) do
		print("											"..tostring(k).." : "..tostring(Fillable.fillTypeIntToName[k]))
	end
end