-- triggers

-- traffic collision
function courseplay:cpOnTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if not self.drive or not self.isMotorStarted then return; end;

	--oops i found myself
	if otherId == self.rootNode then 
		return
	end;
	--ignore objects on list
	if otherId and (courseplay.trafficCollisionIgnoreList[otherId] or self.cpTrafficCollisionIgnoreList[otherId]) then 
		return;
	end;
	--whcih trigger is it ? 
	local TriggerNumber = self.cp.trafficCollisionTriggerToTriggerIndex[triggerId];
	
	if onEnter or onLeave then --TODO check whether it is required to ask for this 
		if otherId == Player.rootNode then  --TODO check in Multiplayer --TODO (Jakob): g_currentMission.player.rootNode ?
			if onEnter then
				self.CPnumCollidingVehicles = self.CPnumCollidingVehicles + 1;
			elseif onLeave then
				self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles - 1, 0);
			end;
		else
			local vehicleOnList = false
			local OtherIdisCloser = true
			local vehicle = g_currentMission.nodeToVehicle[otherId];
			local collisionVehicle = g_currentMission.nodeToVehicle[self.cp.collidingVehicleId];
			
			local isInOtherTrigger = false --is this ID in one of the other triggers?
			for i=1,4 do
				if i ~= TriggerNumber and self.cp.collidingObjects[i][otherId] then
					isInOtherTrigger = true
				end
			end
			courseplay:debug(string.format("%s: Trigger%d: triggered collision with %d ", nameNum(self),TriggerNumber,otherId), 3);
			local trafficLightDistance = 0 
			if collisionVehicle ~= nil and collisionVehicle.rootNode == nil then
				local x,y,z = getWorldTranslation(self.cp.collidingVehicleId)
				_,_, trafficLightDistance = worldToLocal (self.rootNode, x,y,z)			
			end
			
			
			local fixDistance = 0 -- if ID.rootNode is nil set, distance fix to 25m needed for traffic lights
			if onEnter and vehicle ~= nil and vehicle.rootNode == nil then
				fixDistance = TriggerNumber * 5
				courseplay:debug(string.format("%s:	setting fix distance", nameNum(self)), 3);
			end
						
			if not isInOtherTrigger then
				--checking distance to saved and urrent ID
				if onEnter and self.cp.collidingVehicleId ~= nil 
						   and ((collisionVehicle ~= nil and collisionVehicle.rootNode ~= nil) or trafficLightDistance ~= 0 )
						   and ((vehicle ~= nil  and vehicle.rootNode ~= nil) or fixDistance ~= 0) then
					local distanceToOtherId = math.huge
					if fixDistance == 0 then
						distanceToOtherId= courseplay:distanceToObject(self, vehicle)
					else
						distanceToOtherId = fixDistance
					end
					local distanceToCollisionVehicle = math.huge
					if trafficLightDistance == 0 then
						distanceToCollisionVehicle = courseplay:distanceToObject(self, collisionVehicle)
					else
						distanceToCollisionVehicle = math.abs(trafficLightDistance)
					end
					
					courseplay:debug(nameNum(self)..": 	onEnter, checking Distances: new: "..tostring(distanceToOtherId).." vs. current: "..tostring(distanceToCollisionVehicle),3);
					if distanceToCollisionVehicle <= distanceToOtherId then
						OtherIdisCloser = false
						courseplay:debug(string.format('%s: 	target is not closer than existing target -> do not change "self.cp.collidingVehicleId"', nameNum(self)), 3);
					else
						courseplay:debug(string.format('%s: 	target is closer than existing target -> change "self.cp.collidingVehicleId"', nameNum(self)), 3);
					end
				end
				--checking CollisionIgnoreList
				if onEnter and vehicle ~= nil and OtherIdisCloser then
					courseplay:debug(string.format("%s: 	onEnter, checking CollisionIgnoreList", nameNum(self)), 3);
					if courseplay.trafficCollisionIgnoreList[otherId] then
							courseplay:debug(string.format("%s:		%q is on global list", nameNum(self), tostring(vehicle.name)), 3);
							vehicleOnList = true
					else
						for a,b in pairs (self.cpTrafficCollisionIgnoreList) do
							local veh1 = g_currentMission.nodeToVehicle[a];
							local veh1Name = veh1.name;
							if not veh1Name and veh1.cp then veh1Name = veh1.cp.xmlFileName; end;
							local veh2Name = vehicle.name;
							if not veh2Name and vehicle.cp then veh2Name = vehicle.cp.xmlFileName; end;
							courseplay:debug(string.format("%s:		%s vs %q", nameNum(self), tostring(veh1Name), tostring(veh2Name)), 3);
							if g_currentMission.nodeToVehicle[a].id == vehicle.id then
								courseplay:debug(string.format("%s:		%q is on local list", nameNum(self), tostring(veh2Name)), 3);
								vehicleOnList = true
								break
							end
						end
					end
				end
			else
				if onEnter then
					OtherIdisCloser = false
					courseplay:debug(string.format("%s: 	onEnter: %d is in other trigger -> ignore", nameNum(self),otherId ), 3);
				else
					courseplay:debug(string.format("%s: 	onLeave: %d is in other trigger -> ignore", nameNum(self),otherId), 3);
				end
			end
			
			if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil and vehicleOnList == false then
				if onEnter and OtherIdisCloser and not self.cp.collidingObjects.all[otherId] then
					self.cp.collidingObjects.all[otherId] = true
					self.cp.collidingVehicleId = otherId
					--self.CPnumCollidingVehicles = self.CPnumCollidingVehicles + 1;
					courseplay:debug(string.format('%s: 	%q is not on list, setting "self.cp.collidingVehicleId"', nameNum(self), tostring(vehicle.name)), 3);
				elseif onLeave and not isInOtherTrigger then
					self.cp.collidingObjects.all[otherId] = nil
					if self.cp.collidingVehicleId == otherId then
						if TriggerNumber ~= 4 then
							--self.CPnumCollidingVehicles = math.max(self.CPnumCollidingVehicles - 1, 0);
							--if self.CPnumCollidingVehicles == 0 then
								self.cp.collidingVehicleId = nil
							--end
							AIVehicleUtil.setCollisionDirection(self.cp.trafficCollisionTriggers[1], self.cp.trafficCollisionTriggers[2], 0, -1);
							courseplay:debug(string.format('%s: 	onLeave - setting "self.cp.collidingVehicleId" to nil', nameNum(self)), 3);
						else
							courseplay:debug(string.format('%s: 	onLeave - keep "self.CPnumCollidingVehicles"', nameNum(self)), 3);
						end
					else
						courseplay:debug(string.format('%s: 	onLeave - not valid for "self.cp.collidingVehicleId" keep it', nameNum(self)), 3);
					end
				else
					--courseplay:debug(string.format('%s: 	no registration:onEnter:%s, OtherIdisCloser:%s, registered: %s ,isInOtherTrigger: %s', nameNum(self),tostring(onEnter),tostring(OtherIdisCloser),tostring(self.cp.collidingObjects.all[otherId]),tostring(isInOtherTrigger)), 3);
				end;
			elseif not isInOtherTrigger then
				courseplay:debug(string.format('%s: 	Vehicle is nil - do nothing', nameNum(self)), 3);
			end
			
			if  onEnter then
				self.cp.collidingObjects[TriggerNumber][otherId] = true
			else
				self.cp.collidingObjects[TriggerNumber][otherId] = nil
			end	
		end;
	end;
end

-- FIND TRIGGERS
function courseplay:doTriggerRaycasts(vehicle, triggerType, direction, sides, x, y, z, nx, ny, nz, distance)
	local numIntendedRaycasts = sides and 3 or 1;
	if vehicle.cp.hasRunRaycastThisLoop[triggerType] and vehicle.cp.hasRunRaycastThisLoop[triggerType] >= numIntendedRaycasts then
		return;
	end;

	local callBack, debugChannel, r, g, b;
	if triggerType == 'tipTrigger' then
		callBack = 'findTipTriggerCallback';
		debugChannel = 1;
		r, g, b = 1, 0, 1;
	elseif triggerType == 'specialTrigger' then
		callBack = 'findSpecialTriggerCallback';
		debugChannel = 19;
		r, g, b = 0, 1, 0.6;
	else
		return;
	end;

	distance = distance or 10;
	direction = direction or 'fwd';

	--------------------------------------------------

	courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 1);

	if sides and vehicle.cp.tipRefOffset ~= 0 then
		if (triggerType == 'tipTrigger' and vehicle.cp.currentTipTrigger == nil) or (triggerType == 'specialTrigger' and vehicle.cp.fillTrigger == nil) then
			x, y, z = localToWorld(vehicle.aiTrafficCollisionTrigger, vehicle.cp.tipRefOffset, 0, 0);
			courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 2);
		end;

		if (triggerType == 'tipTrigger' and vehicle.cp.currentTipTrigger == nil) or (triggerType == 'specialTrigger' and vehicle.cp.fillTrigger == nil) then
			x, y, z = localToWorld(vehicle.aiTrafficCollisionTrigger, -vehicle.cp.tipRefOffset, 0, 0);
			courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 3);
		end;
	end;

	vehicle.cp.hasRunRaycastThisLoop[triggerType] = numIntendedRaycasts;
end;

function courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, raycastNumber)
	if courseplay.debugChannels[debugChannel] then
		courseplay:debug(('%s: call %s raycast (%s) #%d'):format(nameNum(vehicle), triggerType, direction, raycastNumber), debugChannel);
	end;
	local num = raycastAll(x,y,z, nx,ny,nz, callBack, distance, vehicle);
	if courseplay.debugChannels[debugChannel] then
		if num > 0 then
			courseplay:debug(('%s: %s raycast (%s) #%d: object found'):format(nameNum(vehicle), triggerType, direction, raycastNumber), debugChannel);
		end;
		drawDebugLine(x,y,z, r,g,b, x+(nx*distance),y+(ny*distance),z+(nz*distance), r,g,b);
	end;
end;

-- FIND TIP TRIGGER CALLBACK
function courseplay:findTipTriggerCallback(transformId, x, y, z, distance)
	if courseplay.confirmedNoneTipTriggers[transformId] == true then
		return true;
	end;

	if courseplay.debugChannels[1] then
		drawDebugPoint( x, y, z, 1, 1, 0, 1);
	end;

	local name = tostring(getName(transformId));

	-- TIPTRIGGERS
	local tipTriggers, tipTriggersCount = courseplay.triggers.tipTriggers, courseplay.triggers.tipTriggersCount
	courseplay:debug(('%s: found %s'):format(nameNum(self), name), 1);

	if self.tippers[1] ~= nil and tipTriggers ~= nil and tipTriggersCount > 0 then
		courseplay:debug(('%s: transformId=%s: %s'):format(nameNum(self), tostring(transformId), name), 1);
		local fruitType = self.tippers[1].currentFillType;
		if fruitType == nil or fruitType == 0 then
			for i=2,#(self.tippers) do
				fruitType = self.tippers[i].currentFillType;
				if fruitType ~= nil and fruitType ~= 0 then 
					break
				end
			end
		end
		if transformId ~= nil then
			local trigger = tipTriggers[transformId];

			if trigger ~= nil then
				if trigger.bunkerSilo ~= nil and trigger.bunkerSilo.state ~= 0 then 
					courseplay:debug(('%s: bunkerSilo.state=%d -> ignoring trigger'):format(nameNum(self), bunkerSilo.state), 1);
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
				return true;
			end;
		end;
	end;

	courseplay.confirmedNoneTipTriggers[transformId] = true;
	courseplay.confirmedNoneTipTriggersCounter = courseplay.confirmedNoneTipTriggersCounter + 1;
	courseplay:debug(('%s: added %s to trigger blacklist -> total=%d'):format(nameNum(self), name, courseplay.confirmedNoneTipTriggersCounter), 1);

	return true;
end;

-- FIND SPECIAL TRIGGER CALLBACK
function courseplay:findSpecialTriggerCallback(transformId, x, y, z, distance)
	if courseplay.confirmedNoneSpecialTriggers[transformId] then
		return true;
	end;

	if courseplay.debugChannels[19] then
		drawDebugPoint(x, y, z, 1, 1, 0, 1);
	end;

	local name = tostring(getName(transformId));

	-- OTHER TRIGGERS
	if courseplay.triggers.allNonUpdateables[transformId] then
		local trigger = courseplay.triggers.allNonUpdateables[transformId];
		courseplay:debug(('%s: transformId=%s: %s is allNonUpdateables'):format(nameNum(self), tostring(transformId), name), 19);

		if trigger.isWeightStation and courseplay:canUseWeightStation(self) then
			self.cp.fillTrigger = transformId;
		elseif self.cp.mode == 4 then
			if trigger.isSowingMachineFillTrigger and not self.cp.hasSowingMachine then
				return true;
			elseif trigger.isSprayerFillTrigger and not self.cp.hasSprayer then
				return true;
			end;
			self.cp.fillTrigger = transformId;
		elseif self.cp.mode == 8 and (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger or trigger.isSchweinemastLiquidManureTrigger) then
			self.cp.fillTrigger = transformId;
		elseif trigger.isGasStationTrigger or trigger.isDamageModTrigger then
			self.cp.fillTrigger = transformId;
		end;
		return true;
	end;

	courseplay.confirmedNoneSpecialTriggers[transformId] = true;
	courseplay.confirmedNoneSpecialTriggersCounter = courseplay.confirmedNoneSpecialTriggersCounter + 1;
	courseplay:debug(('%s: added %d (%s) to trigger blacklist -> total=%d'):format(nameNum(self), transformId, name, courseplay.confirmedNoneSpecialTriggersCounter), 19);

	return true;
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
		weightStations = {};
		allNonUpdateables = {};
		all = {};
	};
	local tipTriggersCount, damageModTriggersCount, gasStationTriggersCount, liquidManureFillTriggersCount, sowingMachineFillTriggersCount, sprayerFillTriggersCount, waterTrailerFillTriggersCount, weightStationsCount, allNonUpdateablesCount, allCount = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;

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

	-- updateable objects
	if g_currentMission.updateables ~= nil then
		-- weight station
		if g_currentMission.WeightStation ~= nil and #g_currentMission.WeightStation > 0 then
			for t,object in pairs(g_currentMission.updateables) do
				if object.isWeightStation or object.stationId and object.stationId ~= 0 and g_currentMission.WeightStation[object.stationId] and object.isEnabled and object.requestTimer and object.triggerId then
					local station = g_currentMission.WeightStation[object.stationId];
					object.isWeightStation = true;
					station.isWeightStation = true;
					courseplay.triggers.weightStations[object.triggerId] = station;
					courseplay.triggers.allNonUpdateables[object.triggerId] = station;
					courseplay.triggers.all[object.triggerId] = station;
					weightStationsCount = weightStationsCount + 1;
					allNonUpdateablesCount = allNonUpdateablesCount + 1;
					allCount = allCount + 1;
				end;
			end;
			-- print(tableShow(courseplay.triggers.weightStations, 'courseplay.triggers.weightStations'));
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

				--DamageMod (placeable)
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

				--mixing station (placeable)
				elseif Utils.endsWith(xml, 'mischstation.xml') then
					for i,triggerData in pairs(trigger.TipTriggers) do
						local triggerId = triggerData.triggerId;
						if triggerId then
							triggerData.isMixingStationTrigger = true;
							courseplay.triggers.tipTriggers[triggerId] = triggerData;
							courseplay.triggers.all[triggerId] = triggerData;
							tipTriggersCount = tipTriggersCount + 1;
							allCount = allCount + 1;
						end;
					end;
				end;
			end;
		end
	end;

	-- UPK tipTriggers
	if g_upkTipTrigger then
		for i,trigger in ipairs(g_upkTipTrigger) do
			local triggerId = trigger.triggerId;
			if triggerId and trigger.isEnabled and trigger.type == 'tiptrigger' then
				trigger.isUpkTipTrigger = true;
				courseplay.triggers.tipTriggers[triggerId] = trigger;
				courseplay.triggers.all[triggerId] = trigger;
				tipTriggersCount = tipTriggersCount + 1;
				allCount = allCount + 1;
			end;
		end;
	end;

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

	courseplay.triggers.tipTriggersCount, courseplay.triggers.damageModTriggersCount, courseplay.triggers.gasStationTriggersCount, courseplay.triggers.liquidManureFillTriggersCount, courseplay.triggers.sowingMachineFillTriggersCount, courseplay.triggers.sprayerFillTriggersCount, courseplay.triggers.waterTrailerFillTriggersCount, courseplay.triggers.weightStationsCount, courseplay.triggers.allNonUpdateablesCount, courseplay.triggers.allCount = tipTriggersCount, damageModTriggersCount, gasStationTriggersCount, liquidManureFillTriggersCount, sowingMachineFillTriggersCount, sprayerFillTriggersCount, waterTrailerFillTriggersCount, weightStationsCount, allNonUpdateablesCount, allCount;
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
	local isValid = trigger.className and (trigger.className == "SiloTrigger" or trigger.isPlaceableHeapTrigger or trigger.isAlternativeTipTrigger or Utils.endsWith(trigger.className, "TipTrigger") or Utils.endsWith(trigger.className, "PlaceableHeap"));
	if isValid and trigger.bunkerSilo and trigger.bunkerSilo.movingPlanes == nil then
		isValid = false;
	end;
	return isValid;
end;


function courseplay:printTipTriggersFruits(trigger)
	for k,v in pairs(trigger.acceptedFillTypes) do
		print("											"..tostring(k).." : "..tostring(Fillable.fillTypeIntToName[k]))
	end
end