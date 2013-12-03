-- triggers

-- traffic collision
function courseplay:cponTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if otherId == self.rootNode then
		return
	end
	if onLeave then
		courseplay:debug(nameNum(self)..": Trigger: call handleTrafficCollisions onLeave" ,3)
		courseplay:handleTrafficCollisions(self, triggerId, otherId, onEnter, onLeave)
	elseif onEnter then
		local name = getName(otherId)
		local idsMatch = false
		for transformId,_ in pairs (self.cp.tempCollis) do
			if transformId == otherId then
				idsMatch = true
				break
			end
		end
		if idsMatch then
			courseplay:debug(nameNum(self)..": Trigger: onEnter raycast already found ["..tostring(otherId).."]-> do nothing " ,3)
		else
			courseplay:debug(nameNum(self)..": Trigger: call handleTrafficCollisions onEnter ["..tostring(otherId).."]" ,3)
			courseplay:handleTrafficCollisions(self, triggerId, otherId, onEnter, onLeave)
		end
	end
	

end

function courseplay:findTrafficCollisionCallback(transformId, x, y, z, distance)
	local name = getName(transformId)
	if courseplay.debugChannels[3] then  drawDebugPoint(x, y, z, 1, 1, 0, 1); end
	courseplay:debug(nameNum(self)..": raycast callback response: ["..tostring(transformId).."] in "..tostring(distance),3)
	local triggerId = self.aiTrafficCollisionTrigger 
	if self.cp.tempCollis[transformId] == nil then
		self.cp.tempCollis[transformId] = true
		courseplay:debug(nameNum(self)..": raycast callback: found \""..tostring(name).."\" -> call handleTrafficCollisions onEnter",3)
		courseplay:handleTrafficCollisions(self, triggerId, transformId, true, false)
	else
		return true
	end
	return false
end

function courseplay:handleTrafficCollisions(self, triggerId, otherId, onEnter, onLeave)
	courseplay:debug(string.format("%s: handleTrafficCollisions:", nameNum(self)), 3);
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
			courseplay:debug(string.format("%s: 	found collision trigger", nameNum(self)), 3);
			local vehicleOnList = false
			local OtherIdisCloser = true
			local vehicle = g_currentMission.nodeToVehicle[otherId];
			local vehicleInFront = g_currentMission.nodeToVehicle[self.cp.collidingVehicle];
			if onEnter and self.cp.collidingVehicle ~= nil and vehicleInFront ~= nil and vehicle ~= nil then
				local distanceToOtherId = courseplay:distance_to_object(self, vehicle)
				local distanceToVehicleInFront = courseplay:distance_to_object(self, vehicleInFront)
				courseplay:debug(nameNum(self)..": 	checking Distances: new: "..tostring(distanceToOtherId).." vs. current: "..tostring(distanceToVehicleInFront),3);
				if distanceToVehicleInFront < distanceToOtherId then
					OtherIdisCloser = false
					courseplay:debug(string.format("%s: 	target is not closer than existing target -> do not change \"self.cp.collidingVehicle\"", nameNum(self)), 3);
				else
					courseplay:debug(string.format("%s: 	target is closer than existing target -> change \"self.cp.collidingVehicle\"", nameNum(self)), 3);
				end
			end
			if vehicle ~= nil and onEnter then
				courseplay:debug(string.format("%s: 	checking CollisionIgnoreList", nameNum(self)), 3);
				for a,b in pairs (self.cpTrafficCollisionIgnoreList) do
					courseplay:debug(string.format("%s:		%s vs \"%s\"", nameNum(self), tostring(g_currentMission.nodeToVehicle[a].name), tostring(vehicle.name)), 3);
					if g_currentMission.nodeToVehicle[a].id == vehicle.id then
						courseplay:debug(string.format("%s:		\"%s\" is on list", nameNum(self), tostring(vehicle.name)), 3);
						vehicleOnList = true
						break
					end
				end
			end
			if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil and vehicleOnList == false then
				if onEnter and OtherIdisCloser then
					courseplay:debug(string.format("%s: 	\"%s\" is not on list, setting \"self.cp.collidingVehicle\"", nameNum(self), tostring(vehicle.name)), 3);
					self.cp.collidingVehicle = otherId
					self.CPnumCollidingVehicles = self.CPnumCollidingVehicles + 1;
					self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1;
				elseif onLeave then
					self.cp.tempCollis[otherId] = nil
					courseplay:debug(string.format("%s: 	onLeave - remove one of \"self.CPnumCollidingVehicles\"", nameNum(self)), 3);
					self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles - 1, 0);
					self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0);
 				end;
			else
				courseplay:debug(string.format("%s: 	Vehicle is nil - do nothing", nameNum(self)), 3);
			end
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

	local tipTriggers, tipTriggersCount = courseplay.triggers.tipTriggers, courseplay.triggers.tipTriggersCount
	local name = getName(transformId)
	courseplay:debug(nameNum(self)..": found "..tostring(name),1)
	if self.tippers[1] ~= nil and tipTriggers ~= nil and tipTriggersCount > 0 then
		courseplay:debug(nameNum(self) .. " transformId = ".. tostring(transformId)..": "..tostring(name), 1);
		local fruitType = self.tippers[1].currentFillType;
		if fruitType == nil then
			for i=2,#(self.tippers) do
				fruitType = self.tippers[i].currentFillType;
				if fruitType ~= nil then 
					break
				end
			end
		end
		if transformId ~= nil then
			local trigger = tipTriggers[transformId];

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
				courseplay:debug(string.format("%s: transformId %s is in tipTriggers (#%s) (triggerId=%s)", nameNum(self), tostring(transformId), tostring(tipTriggersCount), tostring(triggerId)), 1);

				if trigger.isAlternativeTipTrigger then
					--fruitType = FruitUtil.fillTypeToFruitType[fruitType];
				end;

				if trigger.acceptedFillTypes ~= nil and trigger.acceptedFillTypes[fruitType] then
					courseplay:debug(string.format("%s: trigger %s accepts fruit (%s)", nameNum(self), tostring(triggerId), tostring(fruitType)), 1);
					local fillTypeIsValid = true;
					if trigger.isAlternativeTipTrigger then
						fillTypeIsValid = trigger.currentFillType == 0 or trigger.currentFillType == fruitType;
						if trigger.fillLevel ~= nil and trigger.capacity ~= nil and trigger.fillLevel >= trigger.capacity then
							courseplay:debug(string.format("%s: AlternativeTipTrigger %s is full ", nameNum(self), tostring(triggerId)), 1);
							return true
						end;
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
			return true
			end;
		end;
	end
	if courseplay.triggers.allNonUpdateables[transformId] then
		local trigger = courseplay.triggers.allNonUpdateables[transformId]
		courseplay:debug(nameNum(self) .. " transformId = ".. tostring(transformId)..": "..tostring(name).." is allNonUpdateables", 1);
		if self.cp.mode == 4 then
			self.cp.fillTrigger = transformId;
		elseif self.cp.mode == 8 and (trigger.isSprayerFillTrigger 
								  or trigger.isLiquidManureFillTrigger
								  or trigger.isSchweinemastLiquidManureTrigger 
								  or trigger.isGasStationTrigger) then
			self.cp.fillTrigger = transformId;									
		elseif trigger.isGasStationTrigger or trigger.isDamageModTrigger then
			self.cp.fillTrigger = transformId;
		end
		return true
	end
				
	courseplay.confirmedNoneTriggers[transformId] = true
	courseplay.confirmedNoneTriggersCounter = courseplay.confirmedNoneTriggersCounter +1
	courseplay:debug(string.format("%s: added %s to blacklist", nameNum(self), tostring(name)), 1);
	courseplay:debug("courseplay.confirmedNoneTriggers:  "..tostring(courseplay.confirmedNoneTriggersCounter),1);
	
	return true
end;

function courseplay:updateAllTriggers()
	--RESET
	if courseplay.triggers ~= nil then
		for k,triggerGroup in pairs(courseplay.triggers) do
			triggerGroup = nil;
		end;
		courseplay.triggers = nil;
	end;
	courseplay.triggers = {
		tipTriggers = {};
		damageModTriggers = {};
		gasStationTriggers = {};
		liquidManureFillTriggers = {};
		sowingMachineFillTriggers = {};
		sprayerFillTriggers = {};
		waterTrailerFillTriggers = {};
		allNonUpdateables = {};
		all = {};
	};
	local tipTriggersCount, damageModTriggersCount, gasStationTriggersCount, liquidManureFillTriggersCount, sowingMachineFillTriggersCount, sprayerFillTriggersCount, waterTrailerFillTriggersCount, allNonUpdateablesCount, allCount = 0, 0, 0, 0, 0, 0, 0, 0, 0;

	--UPDATE
	--nonUpdateable objects
	if g_currentMission.nonUpdateables ~= nil then
		for k,v in pairs(g_currentMission.nonUpdateables) do
			if g_currentMission.nonUpdateables[k] ~= nil then
				local trigger = g_currentMission.nonUpdateables[k];
				local triggerId = trigger.triggerId;
				if triggerId ~= nil then
					--GasStationTriggers
					if trigger.mapHotspot and trigger.mapHotspot.name and trigger.mapHotspot.name == "FuelStation" then
						trigger.isGasStationTrigger = true;
						courseplay.triggers.gasStationTriggers[triggerId] = trigger;
						courseplay.triggers.allNonUpdateables[triggerId] = trigger;
						courseplay.triggers.all[triggerId] = trigger;
						gasStationTriggersCount = gasStationTriggersCount + 1;
						allNonUpdateablesCount = allNonUpdateablesCount + 1;
						allCount = allCount + 1;

					--SowingMachineFillTriggers
					--elseif trigger.fillType ~= nil and trigger.fillType == 17 then --17 = seeds
					elseif trigger.fillType and Fillable.fillTypeIntToName[trigger.fillType] == "seeds" then
						trigger.isSowingMachineFillTrigger = true;
						courseplay.triggers.sowingMachineFillTriggers[triggerId] = trigger;
						courseplay.triggers.allNonUpdateables[triggerId] = trigger;
						courseplay.triggers.all[triggerId] = trigger;
						sowingMachineFillTriggersCount = sowingMachineFillTriggersCount + 1;
						allNonUpdateablesCount = allNonUpdateablesCount + 1;
						allCount = allCount + 1;

					--SprayerFillTriggers
					--elseif (trigger.sprayTypeDesc ~= nil and trigger.sprayTypeDesc.name == "fertilizer") or (trigger.fillType ~= nil and trigger.fillType == 23) then --23 = fertilizer
					elseif (trigger.sprayTypeDesc and trigger.sprayTypeDesc.name == "fertilizer") or (Fillable.fillTypeIntToName[trigger.fillType] == "fertilizer") then
						trigger.isSprayerFillTrigger = true;
						courseplay.triggers.sprayerFillTriggers[triggerId] = trigger;
						courseplay.triggers.allNonUpdateables[triggerId] = trigger;
						courseplay.triggers.all[triggerId] = trigger;
						sprayerFillTriggersCount = sprayerFillTriggersCount + 1;
						allNonUpdateablesCount = allNonUpdateablesCount + 1;
						allCount = allCount + 1;

					--[[
					--WaterTrailerFillTriggers
					--Note: priceScale seems to only exist with WaterTrailerFillTriggers, which in turn don't have fillTypes to check against
					elseif trigger.priceScale then
						trigger.isWaterTrailerFillTrigger = true;
						courseplay.triggers.waterTrailerFillTriggers[triggerId] = trigger;
						courseplay.triggers.allNonUpdateables[triggerId] = trigger;
						courseplay.triggers.all[triggerId] = trigger;
						sprayerFillTriggersCount = waterTrailerFillTriggersCount + 1;
						allNonUpdateablesCount = allNonUpdateablesCount + 1;
						allCount = allCount + 1;
					--]]
					end;
				end;
			end;
		end;
	end;

	--onCreate objects
	if g_currentMission.onCreateLoadedObjects ~= nil then
		for k, trigger in pairs(g_currentMission.onCreateLoadedObjects) do
			local triggerId = trigger.triggerId;
			if triggerId ~= nil then
				if courseplay:isValidTipTrigger(trigger) then
					courseplay.triggers.tipTriggers[triggerId] = trigger;
					courseplay.triggers.all[triggerId] = trigger;
					tipTriggersCount = tipTriggersCount + 1;
					allCount = allCount + 1;
				elseif trigger.ManureLagerDirtyFlag or Utils.endsWith(trigger.className, "ManureLager") then
					trigger.isManureLager = true;
					trigger.isLiquidManureFillTrigger = true;
					courseplay.triggers.liquidManureFillTriggers[triggerId] = trigger;
					courseplay.triggers.allNonUpdateables[triggerId] = trigger;
					courseplay.triggers.all[triggerId] = trigger;
					liquidManureFillTriggersCount = liquidManureFillTriggersCount + 1;
					allNonUpdateablesCount = allNonUpdateablesCount + 1;
					allCount = allCount + 1;
				end;
			elseif trigger.numSchweine ~= nil and trigger.liquidManureSiloTrigger ~= nil and trigger.liquidManureSiloTrigger.triggerId ~= nil then
				triggerId = trigger.liquidManureSiloTrigger.triggerId;
				trigger.isSchweinemastLiquidManureTrigger = true;
				trigger.isLiquidManureFillTrigger = true;
				courseplay.triggers.liquidManureFillTriggers[triggerId] = trigger;
				courseplay.triggers.allNonUpdateables[triggerId] = trigger;
				courseplay.triggers.all[triggerId] = trigger;
				liquidManureFillTriggersCount = liquidManureFillTriggersCount + 1;
				allNonUpdateablesCount = allNonUpdateablesCount + 1;
				allCount = allCount + 1;
			end;
		end;
	end;

	--placeables objects
	if g_currentMission.placeables ~= nil then
		for xml, placeable in pairs(g_currentMission.placeables) do
			for k, trigger in pairs(placeable) do
				--PlaceableHeap
				if Utils.endsWith(xml, "placeableheap.xml") and courseplay:isValidTipTrigger(trigger) and Utils.endsWith(trigger.className, "PlaceableHeap") then
					trigger.isPlaceableHeapTrigger = true;
					local triggerId = trigger.tipTriggerId;
					if triggerId ~= nil then
						courseplay.triggers.tipTriggers[triggerId] = trigger;
						courseplay.triggers.all[triggerId] = trigger;
						tipTriggersCount = tipTriggersCount + 1;
						allCount = allCount + 1;
					end;

				--SowingMachineFillTriggers (placeable)
				elseif trigger.SowingMachineFillTriggerId then
					local data = {
						triggerId = trigger.SowingMachineFillTriggerId;
						nodeId = trigger.nodeId;
						isSowingMachineFillTrigger = true;
						isSowingMachineFillTriggerPlaceable = true;
					};
					courseplay.triggers.sowingMachineFillTriggers[trigger.SowingMachineFillTriggerId] = data;
					courseplay.triggers.allNonUpdateables[trigger.SowingMachineFillTriggerId] = data;
					courseplay.triggers.all[trigger.SowingMachineFillTriggerId] = data;
					sowingMachineFillTriggersCount = sowingMachineFillTriggersCount + 1;
					allNonUpdateablesCount = allNonUpdateablesCount + 1;
					allCount = allCount + 1;

				--SprayerFillTriggers (placeable)
				elseif trigger.SprayerFillTriggerId then
					local data = {
						triggerId = trigger.SprayerFillTriggerId;
						nodeId = trigger.nodeId;
						isSprayerFillTrigger = true;
						isSprayerFillTriggerPlaceable = true;
					};
					courseplay.triggers.sprayerFillTriggers[trigger.SprayerFillTriggerId] = data;
					courseplay.triggers.allNonUpdateables[trigger.SprayerFillTriggerId] = data;
					courseplay.triggers.all[trigger.SprayerFillTriggerId] = data;
					sprayerFillTriggersCount = sprayerFillTriggersCount + 1;
					allNonUpdateablesCount = allNonUpdateablesCount + 1;
					allCount = allCount + 1;

				elseif trigger.customEnvironment == 'DamageMod' or Utils.endsWith(xml, 'garage.xml') then
					local data = {
						triggerId = trigger.triggerId;
						nodeId = trigger.nodeId;
						isDamageModTrigger = true;
						isDamageModTriggerPlaceable = true;
					};
					courseplay.triggers.damageModTriggers[trigger.triggerId] = data;
					courseplay.triggers.allNonUpdateables[trigger.triggerId] = data;
					courseplay.triggers.all[trigger.triggerId] = data;
					damageModTriggersCount = damageModTriggersCount + 1;
					allNonUpdateablesCount = allNonUpdateablesCount + 1;
					allCount = allCount + 1;
				end;
			end;
		end
	end

	--tipTriggers objects
	if g_currentMission.tipTriggers ~= nil then
		for k, trigger in pairs(g_currentMission.tipTriggers) do
			--Regular tipTriggers
			if trigger.isExtendedTrigger and courseplay:isValidTipTrigger(trigger) then
				trigger.isAlternativeTipTrigger = Utils.endsWith(trigger.className, "ExtendedTipTrigger");
				local triggerId = trigger.triggerId;
				if triggerId ~= nil then
					courseplay.triggers.tipTriggers[triggerId] = trigger;
					courseplay.triggers.all[triggerId] = trigger;
					tipTriggersCount = tipTriggersCount + 1;
					allCount = allCount + 1;
				end;

			--LiquidManureSiloTriggers [BGA]
			elseif trigger.bga and trigger.bga.liquidManureSiloTrigger then
				local t = trigger.bga.liquidManureSiloTrigger;
				local triggerId = t.triggerId;
				t.isLiquidManureFillTrigger = true;
				t.isBGAliquidManureFillTrigger = true;
				courseplay.triggers.liquidManureFillTriggers[triggerId] = t;
				courseplay.triggers.allNonUpdateables[triggerId] = t;
				courseplay.triggers.all[triggerId] = t;
				liquidManureFillTriggersCount = liquidManureFillTriggersCount + 1;
				allNonUpdateablesCount = allNonUpdateablesCount + 1;
				allCount = allCount + 1;

			--LiquidManureSiloTriggers [Cows]
			elseif trigger.animalHusbandry and trigger.animalHusbandry.liquidManureTrigger then
				local t = trigger.animalHusbandry.liquidManureTrigger;
				local triggerId = t.triggerId;
				t.isLiquidManureFillTrigger = true;
				t.isCowsLiquidManureFillTrigger = true;
				courseplay.triggers.liquidManureFillTriggers[triggerId] = t;
				courseplay.triggers.allNonUpdateables[triggerId] = t;
				courseplay.triggers.all[triggerId] = t;
				liquidManureFillTriggersCount = liquidManureFillTriggersCount + 1;
				allNonUpdateablesCount = allNonUpdateablesCount + 1;
				allCount = allCount + 1;
			end;
		end
	end;

	courseplay.triggers.tipTriggersCount, courseplay.triggers.damageModTriggersCount, courseplay.triggers.gasStationTriggersCount, courseplay.triggers.liquidManureFillTriggersCount, courseplay.triggers.sowingMachineFillTriggersCount, courseplay.triggers.sprayerFillTriggersCount, courseplay.triggers.waterTrailerFillTriggersCount, courseplay.triggers.allNonUpdateablesCount, courseplay.triggers.allCount = tipTriggersCount, damageModTriggersCount, gasStationTriggersCount, liquidManureFillTriggersCount, sowingMachineFillTriggersCount, sprayerFillTriggersCount, waterTrailerFillTriggersCount, allNonUpdateablesCount, allCount;
end;

--[[
--ALTERNATIVE APPENDING FUNCTION (when trigger is created)
local oldGasStationNew = GasStation.new;
GasStation.new = function(self, id, trailer, customMt)
	local data = {
		triggerId = id;
		isGasStationTrigger = true;
	};
	courseplay.tempTriggers.gasStationTriggers[id] = data;
	courseplay.tempTriggers.allNonUpdateables[id] = data;
	courseplay.tempTriggers.all[id] = data;
	return oldGasStationNew(self, id, trailer, customMt);
end;
--]]




function courseplay:isValidTipTrigger(trigger)
	return trigger.className and (trigger.className == "SiloTrigger" or trigger.isPlaceableHeapTrigger or trigger.isAlternativeTipTrigger or Utils.endsWith(trigger.className, "TipTrigger") or Utils.endsWith(trigger.className, "PlaceableHeap"));
end;


function courseplay:printTipTriggersFruits(trigger)
	for k,v in pairs(trigger.acceptedFillTypes) do
		print("											"..tostring(k).." : "..tostring(Fillable.fillTypeIntToName[k]))
	end
end