-- triggers
local _;
-- traffic collision
function courseplay:cpOnTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	-- prevent double or tripple runs for one event
	if self.cp.lastCheckedTrigger == triggerId 
	and self.cp.lastCheckedotherId == otherId
	and self.cp.lastCheckedonEnter == onEnter
	and self.cp.lastCheckedonLeave == onLeave then
		return
	end
	
	self.cp.lastCheckedTrigger = triggerId
	self.cp.lastCheckedotherId = otherId
	self.cp.lastCheckedonEnter = onEnter
	self.cp.lastCheckedonLeave = onLeave
	---
	
	
	if not self.isMotorStarted then return; end;

	--oops i found myself
	if otherId == self.rootNode then 
		return
	end;
	--ignore objects on list
	if otherId and (CpManager.trafficCollisionIgnoreList[otherId] or self.cpTrafficCollisionIgnoreList[otherId]) then 
		return;
	end;
	--whcih trigger is it ? 
	local TriggerNumber = self.cp.trafficCollisionTriggerToTriggerIndex[triggerId];
	-- print(('otherId=%d, getCollisionMask=%s, name=%q, className=%q'):format(otherId, tostring(getCollisionMask(otherId)), tostring(getName(otherId)), tostring(getClassName(otherId))));
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
			local debugMessage = "onEnter"
			if onLeave then 
				debugMessage = "onLeave"
			end

			local vehicle = g_currentMission.nodeToVehicle[otherId];
			local collisionVehicle = g_currentMission.nodeToVehicle[self.cp.collidingVehicleId];
			
			-- is this a traffic vehicle?
			local cm = getCollisionMask(otherId);
			if vehicle == nil and bitAND(cm, 2097152) ~= 0 then -- if bit21 is part of the collisionMask then set new vehicle in GCM.NTV
				courseplay:debug(string.format("%s: 	onEnter, g_currentMission.nodeToVehicle[%s] == nil -> setting %s as aPath vehicle", nameNum(self),otherId,tostring(getName(otherId))), 3);
				local pathVehicle = {}
				pathVehicle.rootNode = otherId
				pathVehicle.isCpPathvehicle = true
				pathVehicle.name = "PathVehicle"
				pathVehicle.sizeLength = 7
				pathVehicle.sizeWidth = 3
				g_currentMission.nodeToVehicle[otherId] = pathVehicle
				vehicle = pathVehicle
			end;	
			-------
			--is this ID in one of the other triggers?
			local isInOtherTrigger = false 
			for i=1,4 do
				if i ~= TriggerNumber and self.cp.collidingObjects[i][otherId] then
					isInOtherTrigger = true
				end
			end
			courseplay:debug(string.format("%s:%s Trigger%d: triggered collision with %d ", nameNum(self),debugMessage,TriggerNumber,otherId), 3);
			--is it a traffic light ?
			local trafficLightDistance = 0 
			if collisionVehicle ~= nil and collisionVehicle.rootNode == nil then
				local x,y,z = getWorldTranslation(self.cp.collidingVehicleId)
				_,_, trafficLightDistance = worldToLocal (self.cp.DirectionNode, x,y,z)
			end
			----
			--check traffic lights: stop or go?
			if vehicle ~= nil and vehicle.rootNode == nil then 
				local _,transY,_ = getTranslation(otherId);
				if transY < 0 then
					OtherIdisCloser = false
					courseplay:debug(tostring(otherId)..": trafficLight: transY = "..tostring(transY)..", so it's green or Off-> go on",3)
				end
			end
			---
			-- if Id.rootNode is nil, set distance fix to trigger * 5m needed for traffic lights
			local fixDistance = 0 
			if onEnter and vehicle ~= nil and vehicle.rootNode == nil then
				fixDistance = TriggerNumber * 5
				courseplay:debug(string.format("%s:	setting fix distance", nameNum(self)), 3);
			end
			----
				
			if not isInOtherTrigger then
				
				if onEnter then
					--checking distance to saved and current ID
					if self.cp.collidingVehicleId ~= nil 
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
					----
					--checking CollisionIgnoreList
					if vehicle ~= nil and OtherIdisCloser then
						courseplay:debug(string.format("%s: 	onEnter, checking CollisionIgnoreList", nameNum(self)), 3);
						if CpManager.trafficCollisionIgnoreList[otherId] then
							courseplay:debug(string.format("%s:		%q is on global list", nameNum(self), tostring(vehicle.name)), 3);
							vehicleOnList = true
						elseif self.trafficCollisionIgnoreList[otherId] then
							courseplay:debug(string.format("%s:		%q is on local list", nameNum(self), tostring(otherId)), 3);	
							vehicleOnList = true
						else
							for a,b in pairs (self.cpTrafficCollisionIgnoreList) do
								local veh1 = g_currentMission.nodeToVehicle[a];
								if veh1 ~= nil then
									local veh1Name = ""
									veh1Name = veh1.name;
									local veh2Name = vehicle.name;
									if not veh2Name and vehicle.cp then 
										veh2Name = vehicle.cp.xmlFileName; 
									end;
									courseplay:debug(string.format("%s:		%s vs %q", nameNum(self), tostring(veh1Name), tostring(veh2Name)), 3);
									if veh1.id == vehicle.id then
										courseplay:debug(string.format("%s:		%q is on local list", nameNum(self), tostring(veh2Name)), 3);
										vehicleOnList = true
										break
									end
								end
							end
						end
					end
					----
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
								--self.cp.collidingVehicleId = nil
							courseplay:deleteCollisionVehicle(self);
							--end
							courseplay:setCollisionDirection(self.cp.trafficCollisionTriggers[1], self.cp.trafficCollisionTriggers[2], 0, -1);
							courseplay:debug(string.format('%s: 	onLeave - setting "self.cp.collidingVehicleId" to nil', nameNum(self)), 3);
						else
							courseplay:debug(string.format('%s: 	onLeave - keep "self.CPnumCollidingVehicles"', nameNum(self)), 3);
						end
					elseif self.cp.collidingVehicleId ~= nil then
						courseplay:debug(string.format('%s: 	onLeave - not valid for "self.cp.collidingVehicleId" keep it', nameNum(self)), 3);
					else
						courseplay:debug(string.format('%s: 	onLeave - %d is out of all triggers', nameNum(self),otherId), 3);
					end
				else
					--courseplay:debug(string.format('%s: 	no registration:onEnter:%s, OtherIdisCloser:%s, registered: %s ,isInOtherTrigger: %s', nameNum(self),tostring(onEnter),tostring(OtherIdisCloser),tostring(self.cp.collidingObjects.all[otherId]),tostring(isInOtherTrigger)), 3);
				end;
			elseif not isInOtherTrigger then
				courseplay:debug(string.format('%s: 	Vehicle is nil or on ignoreList  -> do nothing', nameNum(self)), 3);
			end
			
			if  onEnter then
				self.cp.collidingObjects[TriggerNumber][otherId] = true
				if courseplay.debugChannels[3] then
					print(string.format('%s: 	added %d to self.cp.collidingObjects[%d]', nameNum(self),otherId,TriggerNumber));
					for trigger,_ in pairs(self.cp.collidingObjects)do
						if trigger ~= "all" then
							print(string.format('%s: 	self.cp.collidingObjects[%d]:',nameNum(self),trigger))
							for otherId,_ in pairs(self.cp.collidingObjects[trigger])do
								print(string.format('%s: 	                             %d %s',nameNum(self),otherId,tostring(getName(otherId))))
							end
						end
					end
				end	
			else
				self.cp.collidingObjects[TriggerNumber][otherId] = nil
				if courseplay.debugChannels[3] then
					print(string.format('%s: 	deleted %d from self.cp.collidingObjects[%d]', nameNum(self),otherId,TriggerNumber));
					for trigger,_ in pairs(self.cp.collidingObjects)do
						if trigger ~= "all" then
							print(string.format('%s: 	self.cp.collidingObjects[%d]:',nameNum(self),trigger))
							for otherId,_ in pairs(self.cp.collidingObjects[trigger])do
								print(string.format('%s: 	                             %d %s',nameNum(self),otherId,tostring(getName(otherId))))								
							end
						end
					end
				end
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
			local x, _, z = localToWorld(vehicle.aiTrafficCollisionTrigger, vehicle.cp.tipRefOffset, 0, 0);
			courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 2);
		end;

		if (triggerType == 'tipTrigger' and vehicle.cp.currentTipTrigger == nil) or (triggerType == 'specialTrigger' and vehicle.cp.fillTrigger == nil) then
			local x, _, z = localToWorld(vehicle.aiTrafficCollisionTrigger, -vehicle.cp.tipRefOffset, 0, 0);
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
			--courseplay:debug(('%s: %s raycast (%s) #%d: object found'):format(nameNum(vehicle), triggerType, direction, raycastNumber), debugChannel);
		end;
		drawDebugLine(x,y,z, r,g,b, x+(nx*distance),y+(ny*distance),z+(nz*distance), r,g,b);
	end;
end;

-- FIND TIP TRIGGER CALLBACK
function courseplay:findTipTriggerCallback(transformId, x, y, z, distance)
	if CpManager.confirmedNoneTipTriggers[transformId] == true then
		return true;
	end;

	if courseplay.debugChannels[1] then
		drawDebugPoint( x, y, z, 1, 1, 0, 1);
	end;

	local name = tostring(getName(transformId));

	-- TIPTRIGGERS
	local tipTriggers, tipTriggersCount = courseplay.triggers.tipTriggers, courseplay.triggers.tipTriggersCount
	courseplay:debug(('%s: found %s'):format(nameNum(self), name), 1);
	
	if self.cp.workTools[1] ~= nil and tipTriggers ~= nil and tipTriggersCount > 0 then
		courseplay:debug(('%s: transformId=%s: %s'):format(nameNum(self), tostring(transformId), name), 1);
		local trailerFillType = self.cp.workTools[1].cp.fillType;
		if trailerFillType == nil or trailerFillType == 0 then
			for i=1,#(self.cp.workTools) do
				trailerFillType = self.cp.workTools[i].cp.fillType;
				if trailerFillType ~= nil and trailerFillType ~= 0 then 
					break
				end
			end
		end
		if transformId ~= nil then
			local trigger = tipTriggers[transformId];

			if trigger ~= nil then
				if trigger.bunkerSilo ~= nil and trigger.state ~= 0 then 
					courseplay:debug(('%s: bunkerSilo.state=%d -> ignoring trigger'):format(nameNum(self), trigger.state), 1);
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
				courseplay:debug(('%s: transformId %s is in tipTriggers (#%s) (triggerId=%s)'):format(nameNum(self), tostring(transformId), tostring(tipTriggersCount), tostring(triggerId)), 1);

				if trigger.isFermentingSiloTrigger then
					trigger = trigger.TipTrigger
					courseplay:debug('    trigger is FermentingSiloTrigger', 1);
				elseif trigger.isAlternativeTipTrigger then
					courseplay:debug('    trigger is AlternativeTipTrigger', 1);
				elseif trigger.isPlaceableHeapTrigger then
					courseplay:debug('    trigger is PlaceableHeap', 1);
				end;

				courseplay:debug(('    trailerFillType=%s %s'):format(tostring(trailerFillType), trailerFillType and FillUtil.fillTypeIntToName[trailerFillType] or ''), 1);
				if trailerFillType and trigger.acceptedFillTypes ~= nil and trigger.acceptedFillTypes[trailerFillType] then
					courseplay:debug(('    trigger (%s) accepts trailerFillType'):format(tostring(triggerId)), 1);

					-- check trigger fillLevel / capacity
					if trigger.fillLevel and trigger.capacity and trigger.fillLevel >= trigger.capacity then
						courseplay:debug(('    trigger (%s) fillLevel=%d, capacity=%d -> abort'):format(tostring(triggerId), trigger.fillLevel, trigger.capacity), 1);
						return true;
					end;

					-- check single fillType validity
					local fillTypeIsValid = true;
					if trigger.currentFillType then
						fillTypeIsValid = trigger.currentFillType == 0 or trigger.currentFillType == trailerFillType;
						courseplay:debug(('    trigger (%s): currentFillType=%d -> fillTypeIsValid=%s'):format(tostring(triggerId), trigger.currentFillType, tostring(fillTypeIsValid)), 1);
					elseif trigger.getFillType then
						local triggerFillType = trigger:getFillType();
						fillTypeIsValid = triggerFillType == 0 or triggerFillType == trailerFillType;
						courseplay:debug(('    trigger (%s): trigger:getFillType()=%d -> fillTypeIsValid=%s'):format(tostring(triggerId), triggerFillType, tostring(fillTypeIsValid)), 1);
					end;

					if fillTypeIsValid then
						self.cp.currentTipTrigger = trigger;
						--self.cp.currentTipTrigger.cpActualLength = courseplay:distanceToObject(self, trigger)*2
						self.cp.currentTipTrigger.cpActualLength = courseplay:nodeToNodeDistance(self.cp.DirectionNode or self.rootNode, trigger.rootNode)*2
						courseplay:debug(('%s: self.cp.currentTipTrigger=%s , cpActualLength=%s'):format(nameNum(self), tostring(triggerId),tostring(self.cp.currentTipTrigger.cpActualLength)), 1);
						return false
					end;
				elseif trigger.acceptedFillTypes ~= nil then

					if courseplay.debugChannels[1] then
						courseplay:debug(('    trigger (%s) does not accept trailerFillType (%s)'):format(tostring(triggerId), tostring(trailerFillType)), 1);
						courseplay:debug(('    trigger (%s) acceptedFillTypes:'):format(tostring(triggerId)), 1);
						courseplay:printTipTriggersFruits(trigger)
					end
				else
					courseplay:debug(string.format("%s: trigger %s does not have acceptedFillTypes (trailerFillType=%s)", nameNum(self), tostring(triggerId), tostring(trailerFillType)), 1);
				end;
				return true;
			end;
		end;
	end;

	CpManager.confirmedNoneTipTriggers[transformId] = true;
	CpManager.confirmedNoneTipTriggersCounter = CpManager.confirmedNoneTipTriggersCounter + 1;
	courseplay:debug(('%s: added %s to trigger blacklist -> total=%d'):format(nameNum(self), name, CpManager.confirmedNoneTipTriggersCounter), 1);

	return true;
end;

-- FIND SPECIAL TRIGGER CALLBACK
function courseplay:findSpecialTriggerCallback(transformId, x, y, z, distance)
	if CpManager.confirmedNoneSpecialTriggers[transformId] then
		return true;
	end;

	if courseplay.debugChannels[19] then
		drawDebugPoint(x, y, z, 1, 1, 0, 1);
	end;

	local name = tostring(getName(transformId));
	local parent = getParent(transformId);
	for _,implement in pairs(self.attachedImplements) do
		if (implement.object ~= nil and implement.object.rootNode == parent) then
			courseplay:debug(('%s: trigger %s is from my own implement'):format(nameNum(self), tostring(transformId)), 19);
			return true
		end
	end	
	
	-- OTHER TRIGGERS
	if courseplay.triggers.allNonUpdateables[transformId] then
		local trigger = courseplay.triggers.allNonUpdateables[transformId];
		courseplay:debug(('%s: transformId=%s: %s is allNonUpdateables'):format(nameNum(self), tostring(transformId), name), 19);

		if trigger.isWeightStation and courseplay:canUseWeightStation(self) then
			self.cp.fillTrigger = transformId;
			courseplay:debug(('%s: trigger %s is valid'):format(nameNum(self), tostring(transformId)), 19);
		elseif self.cp.mode == 4 then
			if trigger.isSowingMachineFillTrigger and not self.cp.hasSowingMachine then
				return true;
			elseif trigger.isSprayerFillTrigger and not self.cp.hasSprayer then
				return true;
			end;
			self.cp.fillTrigger = transformId;
			courseplay:debug(('%s: trigger %s is valid-> set self.cp.fillTrigger'):format(nameNum(self), tostring(transformId)), 19);
		elseif self.cp.mode == 8 and (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger or trigger.isSchweinemastLiquidManureTrigger) then
			if trigger.parentVehicle then
				local tractor = trigger.parentVehicle:getRootAttacherVehicle()
				if not (tractor and tractor.hasCourseplaySpec and tractor.cp.mode == 8 and tractor.cp.isDriving) then
					self.cp.fillTrigger = transformId;
					courseplay:debug(('%s: trigger %s is valid-> set self.cp.fillTrigger'):format(nameNum(self), tostring(transformId)), 19);
				else
					courseplay:debug(('%s: trigger %s is running mode8 -> refuse'):format(nameNum(self), tostring(transformId)), 19);
				end
			else
				self.cp.fillTrigger = transformId;
				courseplay:debug(('%s: trigger %s is valid-> set self.cp.fillTrigger'):format(nameNum(self), tostring(transformId)), 19);
			end
		elseif trigger.isGasStationTrigger or trigger.isDamageModTrigger then
			self.cp.fillTrigger = transformId;
			courseplay:debug(('%s: trigger %s is valid-> set self.cp.fillTrigger'):format(nameNum(self), tostring(transformId)), 19);
		end;
		return true;
	end;

	CpManager.confirmedNoneSpecialTriggers[transformId] = true;
	CpManager.confirmedNoneSpecialTriggersCounter = CpManager.confirmedNoneSpecialTriggersCounter + 1;
	courseplay:debug(('%s: added %d (%s) to trigger blacklist -> total=%d'):format(nameNum(self), transformId, name, CpManager.confirmedNoneSpecialTriggersCounter), 19);

	return true;
end;

function courseplay:updateAllTriggers()
	courseplay:debug('updateAllTriggers()', 1);

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
		waterReceivers = {};
		waterTrailerFillTriggers = {};
		weightStations = {};
		allNonUpdateables = {};
		all = {};
	};
	courseplay.triggers.tipTriggersCount = 0;
	courseplay.triggers.damageModTriggersCount = 0;
	courseplay.triggers.gasStationTriggersCount = 0;
	courseplay.triggers.liquidManureFillTriggersCount = 0;
	courseplay.triggers.sowingMachineFillTriggersCount = 0;
	courseplay.triggers.sprayerFillTriggersCount = 0;
	courseplay.triggers.waterReceiversCount = 0;
	courseplay.triggers.waterTrailerFillTriggersCount = 0;
	courseplay.triggers.weightStationsCount = 0;
	courseplay.triggers.allNonUpdateablesCount = 0;
	courseplay.triggers.allCount = 0;


	-- UPDATE
	-- nonUpdateable objects
	if g_currentMission.nonUpdateables ~= nil then
		courseplay:debug('\tcheck nonUpdateables', 1);
		for k,v in pairs(g_currentMission.nonUpdateables) do
			if g_currentMission.nonUpdateables[k] ~= nil then
				local trigger = g_currentMission.nonUpdateables[k];
				local triggerId = trigger.triggerId;
				if triggerId ~= nil and trigger.isEnabled then
					-- GasStationTriggers
					if trigger.isa and trigger:isa(GasStation) then
						trigger.isGasStationTrigger = true;
						courseplay:cpAddTrigger(triggerId, trigger, 'gasStation', 'nonUpdateable');
						courseplay:debug('\t\tadd GasStationTrigger', 1);

					-- SowingMachineFillTriggers
					elseif trigger.fillType and trigger.fillType == FillUtil.FILLTYPE_SEEDS then
						trigger.isSowingMachineFillTrigger = true;
						courseplay:cpAddTrigger(triggerId, trigger, 'sowingMachine', 'nonUpdateable');
						courseplay:debug('\t\tadd SowingMachineFillTrigger', 1);

					-- SprayerFillTriggers
					elseif trigger.fillType and (trigger.fillType == FillUtil.FILLTYPE_FERTILIZER or trigger.fillType == FillUtil.FILLTYPE_LIQUIDFERTILIZER) then
						trigger.isSprayerFillTrigger = true;
						courseplay:cpAddTrigger(triggerId, trigger, 'sprayer', 'nonUpdateable');
						courseplay:debug('\t\tadd SprayerFillTrigger', 1);
					-- WaterTrailerFillTriggers
					elseif trigger.isa and trigger:isa(WaterTrailerFillTrigger) then
						trigger.isWaterTrailerFillTrigger = true;
						courseplay:cpAddTrigger(triggerId, trigger, 'water', 'nonUpdateable');
						courseplay:debug('\t\tadd waterTrailerFillTrigger', 1);
					end;
				end;
			end;
		end;
	end;
	
	--itemsToSave (BigPacks)
	--print("g_currentMission.itemsToSave:"..tostring(g_currentMission.itemsToSave))
	if g_currentMission.itemsToSave ~= nil then
		courseplay:debug('\tcheck itemsToSave', 1);
		for _,valueTable in pairs (g_currentMission.itemsToSave) do
			if valueTable.item ~= nil then
				if valueTable.item.fillTrigger ~= nil then
					local trigger = valueTable.item.fillTrigger
					local triggerId = trigger.triggerId
					if triggerId ~= nil and trigger.isEnabled then
						-- GasStationTriggers
						if trigger.isa and trigger:isa(GasStation) then
							trigger.isGasStationTrigger = true;
							courseplay:cpAddTrigger(triggerId, trigger, 'gasStation', 'nonUpdateable');
							courseplay:debug('\t\tadd GasStationTrigger', 1);

						-- SowingMachineFillTriggers
						elseif trigger.fillType and trigger.fillType == FillUtil.FILLTYPE_SEEDS then
							trigger.isSowingMachineFillTrigger = true;
							courseplay:cpAddTrigger(triggerId, trigger, 'sowingMachine', 'nonUpdateable');
							courseplay:debug('\t\tadd SowingMachineFillTrigger', 1);

						-- SprayerFillTriggers
						elseif trigger.fillType and (trigger.fillType == FillUtil.FILLTYPE_FERTILIZER or trigger.fillType == FillUtil.FILLTYPE_LIQUIDFERTILIZER) then
							trigger.isSprayerFillTrigger = true;
							courseplay:cpAddTrigger(triggerId, trigger, 'sprayer', 'nonUpdateable');
							courseplay:debug('\t\tadd SprayerFillTrigger', 1);
						-- WaterTrailerFillTriggers
						elseif trigger.isa and trigger:isa(WaterTrailerFillTrigger) then
							trigger.isWaterTrailerFillTrigger = true;
							courseplay:cpAddTrigger(triggerId, trigger, 'water', 'nonUpdateable');
							courseplay:debug('\t\tadd waterTrailerFillTrigger', 1);
						end;
					end;
				end
				if valueTable.item.waterTankTriggerNode ~= nil then
					local triggerId = valueTable.item.waterTankTriggerNode;
					valueTable.item.isGreenhouse = true
					courseplay:cpAddTrigger(triggerId, valueTable.item, 'waterReceiver', 'nonUpdateable');
					courseplay:debug('\t\tadd Greenhouse receiver trigger (placeable)', 1);
				end;				
			end
		end		
	end
	
	-- updateable objects
	if g_currentMission.updateables ~= nil then
		courseplay:debug('\tcheck updateables', 1);
		-- weight station
		if g_currentMission.WeightStation ~= nil and #g_currentMission.WeightStation > 0 then
			for t,object in pairs(g_currentMission.updateables) do
				if object.isWeightStation or (object.stationId and object.stationId ~= 0 and g_currentMission.WeightStation[object.stationId]) and object.isEnabled and object.requestTimer and object.triggerId then
					local station = g_currentMission.WeightStation[object.stationId];
					object.isWeightStation = true;
					station.isWeightStation = true;
					courseplay:cpAddTrigger(object.triggerId, station, 'weightStation', 'nonUpdateable');
					courseplay:debug('\t\tadd weightStation [mod]', 1);
				end;
			end;
		end;
	end;

	-- onCreate objects
	local WaterMod;
	if g_currentMission.missionInfo.customEnvironment then
		WaterMod = getfenv(0)[g_currentMission.missionInfo.customEnvironment].WaterMod;
	end;
	if g_currentMission.onCreateLoadedObjects ~= nil then
		courseplay:debug('\tcheck onCreateLoadedObjects', 1);
		for k, object in pairs(g_currentMission.onCreateLoadedObjects) do

			--newBGA DigestateSiloTrigger
			if object.tipTriggerTargets ~= nil then
				for index, value in pairs(object.tipTriggerTargets) do
					if type(value)=='table' and value.digestateSiloTrigger then
						local trigger = value.digestateSiloTrigger
						trigger.isLiquidManureFillTrigger = true
						courseplay:cpAddTrigger(trigger.triggerId, trigger, 'liquidManure', 'nonUpdateable');
						courseplay:debug(('\t\tadd liquidManureFillTrigger (id %d) [digestateBGA]'):format(trigger.triggerId), 1);
					end
				end

			end
			-- Cows husbandry: liquidManureSiloTrigger
			if object.isa and object:isa(AnimalHusbandry) and object.liquidManureTrigger then
				local trigger = object.liquidManureTrigger;
				trigger.isLiquidManureFillTrigger = true;
				trigger.isCowsLiquidManureFillTrigger = true;
				local name = object.animalDesc.name
				courseplay:cpAddTrigger(trigger.triggerId, trigger, 'liquidManure', 'nonUpdateable');
				courseplay:debug(('\t\tadd liquidManureFillTrigger (id %d) [%s]'):format(trigger.triggerId,name), 1);

			-- ManureLager
			elseif object.triggerId ~= nil then
				if object.isManureLager or object.ManureLagerDirtyFlag or Utils.endsWith(object.className, 'ManureLager') then
					object.isManureLager = true;
					object.isLiquidManureFillTrigger = true;
					courseplay:cpAddTrigger(object.triggerId, object, 'liquidManure', 'nonUpdateable');
					courseplay:debug('\t\tadd ManureLager [mod]', 1);
				end;

			-- Pigs [marhu]
			elseif object.SchweineZuchtDirtyFlag or object.numSchweine ~= nil then
				if object.liquidManureSiloTrigger ~= nil and object.liquidManureSiloTrigger.triggerId ~= nil then
					local trigger = object.liquidManureSiloTrigger;
					local triggerId = trigger.triggerId;
					trigger.isSchweinemastLiquidManureTrigger = true;
					trigger.isLiquidManureFillTrigger = true;
					courseplay:cpAddTrigger(triggerId, object, 'liquidManure', 'nonUpdateable');
					courseplay:debug('\t\tadd pigs liquidManureFillTrigger [mod]', 1);
				end;
			end;
		end;
	end;
	--HeapTipTrigger
	if g_currentMission.heapTipTriggers ~= nil then
		courseplay:debug('\tcheck HeapTipTriggers', 1);
		for index,trigger in pairs(g_currentMission.heapTipTriggers)do
			if trigger.triggerId ~= nil then
				courseplay:cpAddTrigger(trigger.triggerId, trigger, 'tipTrigger');
				courseplay:debug('\t\tadd HeapTipTrigger', 1);
			end;		
		end;	
	end;
	-- placeables objects
	if g_currentMission.placeables ~= nil then
		courseplay:debug('\tcheck placeables', 1);
		local counter = 0
		for xml, placeable in pairs(g_currentMission.placeables) do
			counter = counter +1 
			for k, trigger in pairs(placeable) do
				--	FermentingSilo
				if (Utils.endsWith(xml, 'ermentingsilo_low.xml') or Utils.endsWith(xml, 'ermentingsilo_high.xml')) and trigger.silagePerHour ~= nil then
					trigger.isFermentingSiloTrigger = true;
					local triggerId = trigger.TipTrigger.triggerId;
					if triggerId ~= nil then
						courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
						courseplay:debug('\t\tadd FermentingSiloTrigger [mod]', 1);
					end;

				-- SowingMachineFillTriggers (placeable)
				elseif trigger.SowingMachineFillTriggerId then
					local data = {
						triggerId = trigger.SowingMachineFillTriggerId;
						nodeId = trigger.nodeId;
						isSowingMachineFillTrigger = true;
						isSowingMachineFillTriggerPlaceable = true;
					};
					courseplay:cpAddTrigger(data.triggerId, data, 'sowingMachine', 'nonUpdateable');
					courseplay:debug('\t\tadd SowingMachineFillTrigger [placeable] [mod]', 1);

				-- SprayerFillTriggers (placeable)
				elseif trigger.SprayerFillTriggerId then
					local data = {
						triggerId = trigger.SprayerFillTriggerId;
						nodeId = trigger.nodeId;
						isSprayerFillTrigger = true;
						isSprayerFillTriggerPlaceable = true;
					};
					courseplay:cpAddTrigger(data.triggerId, data, 'sprayer', 'nonUpdateable');
					courseplay:debug('\t\tadd SprayerFillTrigger [placeable] [mod]', 1);

				-- DamageMod (placeable)
				elseif trigger.customEnvironment == 'DamageMod' or Utils.endsWith(xml, 'garage.xml') then
					local data = {
						triggerId = trigger.triggerId;
						nodeId = trigger.nodeId;
						isDamageModTrigger = true;
						isDamageModTriggerPlaceable = true;
					};
					courseplay:cpAddTrigger(trigger.triggerId, data, 'damageMod', 'nonUpdateable');
					courseplay:debug('\t\tadd DamageModTrigger [mod]', 1);

				-- mixing station (placeable)
				elseif Utils.endsWith(xml, 'mischstation.xml') then
					for i,triggerData in pairs(trigger.TipTriggers) do
						local triggerId = triggerData.triggerId;
						if triggerId then
							triggerData.isMixingStationTrigger = true;
							courseplay:cpAddTrigger(triggerId, triggerData, 'tipTrigger');
							courseplay:debug('\t\tadd MixingStationTrigger [mod]', 1);
						end;
					end;

				-- BioHeatPlant / WoodChip storage tipTrigger (Forest Mod) (placeable)
				elseif trigger.isStorageTipTrigger and trigger.acceptedFillType ~= nil and FillUtil.fillTypeNameToInt.woodChip ~= nil and trigger.acceptedFillType == FillUtil.fillTypeNameToInt.woodChip and trigger.triggerId ~= nil then
					courseplay:cpAddTrigger(trigger.triggerId, trigger, 'tipTrigger');
					courseplay:debug('\t\tadd BioHeatPlant / WoodChop storage trigger [forest mod]', 1);

				-- manureLager (placeable)
				elseif trigger.ManureLagerPlaceableDirtyFlag or Utils.endsWith(xml, 'placeablemanurelager.xml') then
					trigger.isManureLager = true;
					trigger.isLiquidManureFillTrigger = true;
					local triggerId = trigger.manureTrigger
					courseplay:cpAddTrigger(triggerId, trigger, 'liquidManure', 'nonUpdateable');
					courseplay:debug('\t\tadd ManureLager [placeable] [mod]', 1);

				-- Greenhouse (water tank) (placeable) (*receives* water from trailer)
				elseif trigger.isGreenhouse or trigger.waterTrailerActivatable then
					trigger.isGreenhouse = true;
					local triggerId = trigger.waterTankTriggerNode;
					courseplay:cpAddTrigger(triggerId, trigger, 'waterReceiver', 'onCreateLoadedObjects');
					courseplay:debug('\t\tadd greenhouse water trigger [placeable]', 1);
				end;
			end;
		end
		courseplay:debug(('\t%i found'):format(counter), 1);
	end;

	-- UPK triggers
	if g_upkTrigger then
		courseplay:debug('\tcheck g_upkTrigger', 1);
		for i,trigger in ipairs(g_upkTrigger) do
			local triggerId = trigger.triggerId;
			if triggerId and trigger.isEnabled then
				-- if trigger.type == 'dumptrigger' then -- TODO: kinda like tipTrigger?
				-- elseif trigger.type == 'filltrigger' then
				if trigger.type == 'gasstationtrigger' then
					trigger.isGasStationTrigger = true;
					trigger.isUpkGasStationTrigger = true;
					courseplay:cpAddTrigger(triggerId, trigger, 'gasStation', 'nonUpdateable');
					courseplay:debug(('\t\tadd gasStationTrigger (id %d)'):format(triggerId), 1);
				elseif trigger.type == 'liquidmanurefilltrigger' then
					trigger.isLiquidManureFillTrigger = true;
					trigger.isUpkLiquidManureFillTrigger = true;
					courseplay:cpAddTrigger(triggerId, trigger, 'liquidManure', 'nonUpdateable');
					courseplay:debug(('\t\tadd liquidManureFillTrigger (id %d)'):format(triggerId), 1);
				elseif trigger.type == 'sprayerfilltrigger' then
					trigger.isSprayerFillTrigger = true;
					trigger.isUpkSprayerFillTrigger = true;
					courseplay:cpAddTrigger(triggerId, trigger, 'sprayer', 'nonUpdateable');
					courseplay:debug(('\t\tadd sprayerFillTrigger (id %d)'):format(triggerId), 1);
				elseif trigger.type == 'tiptrigger' then
					trigger.isUpkTipTrigger = true;
					if trigger.i18nNameSpace == 'PlaceableHeaps' then
						trigger.isPlaceableHeapTrigger = true;
					end;
					courseplay:debug(('\t\tadd tipTrigger (id %d), isPlaceableHeapTrigger=%s'):format(triggerId, tostring(trigger.isPlaceableHeapTrigger)), 1);
					courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
				elseif trigger.type == 'waterfilltrigger' then
					trigger.isWaterTrailerFillTrigger = true;
					courseplay:cpAddTrigger(triggerId, trigger, 'water', 'nonUpdateable');
					courseplay:debug(('\t\tadd waterTrailerFillTrigger (id %d)'):format(triggerId), 1);
				end;
			end;
		end;
	end;
	if g_currentMission.bunkerSilos ~= nil then
		courseplay:debug('\tcheck bunkerSilos', 1);
		for _, trigger in pairs(g_currentMission.bunkerSilos) do
			if courseplay:isValidTipTrigger(trigger) and trigger.bunkerSilo then
				local triggerId = trigger.triggerId;
				local name = tostring(getName(triggerId));
				local className = tostring(trigger.className);
				local detailId = g_currentMission.terrainDetailId
				local area = trigger.bunkerSiloArea
				local px,pz, pWidthX,pWidthZ, pHeightX,pHeightZ = Utils.getXZWidthAndHeight(detailId, area.sx,area.sz, area.wx, area.wz, area.hx, area.hz);
				local _ ,_,totalArea = getDensityParallelogram(detailId, px, pz, pWidthX, pWidthZ, pHeightX, pHeightZ, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels);
				trigger.capacity = TipUtil.volumePerPixel*totalArea*800 ;
				--print(string.format("capacity= %s  fillLevel= %s ",tostring(trigger.capacity),tostring(trigger.fillLevel)))
				courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
				courseplay:debug(('\t\tadd tipTrigger: id=%d, name=%q, className=%q, is BunkerSiloTipTrigger '):format(triggerId, name, className), 1);
			end
		end
	end
	-- tipTriggers objects
	if g_currentMission.tipTriggers ~= nil then
		courseplay:debug('\tcheck tipTriggers', 1);
		for k, trigger in pairs(g_currentMission.tipTriggers) do
			-- Regular and Extended tipTriggers
			if courseplay:isValidTipTrigger(trigger) then
				local triggerId = trigger.triggerId;
				-- Extended tipTriggers (AlternativeTipTrigger)
				if trigger.isExtendedTrigger then
					trigger.isAlternativeTipTrigger = Utils.endsWith(trigger.className, 'ExtendedTipTrigger');
				end;
				if triggerId ~= nil then
					courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
					local name = tostring(getName(triggerId));
					local className = tostring(trigger.className);
					if trigger.isa and trigger:isa(FeedingTroughTipTrigger) then
						courseplay:debug(('\t\tadd tipTrigger: id=%d, name=%q, className=%q, is FeedingTroughTipTrigger'):format(triggerId, name, className), 1);
					elseif trigger.isa and trigger:isa(BgaTipTrigger) then
						courseplay:debug(('\t\tadd tipTrigger: id=%d, name=%q, className=%q, is BgaTipTrigger'):format(triggerId, name, className), 1);
					elseif trigger.bunkerSilo then
						courseplay:debug(('\t\tadd tipTrigger: id=%d, name=%q, className=%q, is BunkerSiloTipTrigger, #movingPlanes=%d'):format(triggerId, name, className, #trigger.bunkerSilo.movingPlanes), 1);
					else
						courseplay:debug(('\t\tadd tipTrigger: id=%d, name=%q, className=%q, isAlternativeTipTrigger=%s'):format(triggerId, name, className, tostring(trigger.isAlternativeTipTrigger)), 1);
					end;
				end;
			end;
		end
	end;

	if courseplay.liquidManureOverloaders ~= nil then
		for rootNode, vehicle in pairs(courseplay.liquidManureOverloaders) do
			local trigger = vehicle.unloadTrigger
			local triggerId = trigger.triggerId
			trigger.isLiquidManureFillTrigger = true;
			trigger.isLiquidManureOverloaderFillTrigger = true;
			trigger.parentVehicle = vehicle
			courseplay:cpAddTrigger(triggerId, trigger, 'liquidManure', 'nonUpdateable');
			courseplay:debug(('\t\tadd overloader\'s liquidManureFillTrigger (id %d)'):format(triggerId), 1);
		end
	end
end;


function courseplay:cpAddTrigger(triggerId, trigger, triggerType, groupType)
	--courseplay:debug(('%s: courseplay:cpAddTrigger: TriggerId: %s,trigger: %s, triggerType: %s,groupType: %s'):format(nameNum(self), tostring(triggerId), tostring(trigger), tostring(triggerType), tostring(groupType)), 1);
	local t = courseplay.triggers;
	if t.all[triggerId] ~= nil then return; end;

	t.all[triggerId] = trigger;
	t.allCount = t.allCount + 1;

	if groupType then
		if groupType == 'nonUpdateable' then
			t.allNonUpdateables[triggerId] = trigger;
			t.allNonUpdateablesCount = t.allNonUpdateablesCount + 1;
		end;
	end;

	-- tipTriggers
	if triggerType == 'tipTrigger' then
		t.tipTriggers[triggerId] = trigger;
		t.tipTriggersCount = t.tipTriggersCount + 1;

	-- other triggers
	elseif triggerType == 'damageMod' then
		t.damageModTriggers[triggerId] = trigger;
		t.damageModTriggersCount = t.damageModTriggersCount + 1;
	elseif triggerType == 'gasStation' then
		t.gasStationTriggers[triggerId] = trigger;
		t.gasStationTriggersCount = t.gasStationTriggersCount + 1;
	elseif triggerType == 'liquidManure' then
		t.liquidManureFillTriggers[triggerId] = trigger;
		t.liquidManureFillTriggersCount = t.liquidManureFillTriggersCount + 1;
	elseif triggerType == 'sowingMachine' then
		t.sowingMachineFillTriggers[triggerId] = trigger;
		t.sowingMachineFillTriggersCount = t.sowingMachineFillTriggersCount + 1;
	elseif triggerType == 'sprayer' then
		t.sprayerFillTriggers[triggerId] = trigger;
		t.sprayerFillTriggersCount = t.sprayerFillTriggersCount + 1;
	elseif triggerType == 'water' then
		t.waterTrailerFillTriggers[triggerId] = trigger;
		t.waterTrailerFillTriggersCount = t.waterTrailerFillTriggersCount + 1;
	elseif triggerType == 'weightStation' then
		t.weightStations[triggerId] = trigger;
		t.weightStationsCount = t.weightStationsCount + 1;
	elseif triggerType == 'waterReceiver' then
		t.waterReceivers[triggerId] = trigger;
		t.waterReceiversCount = t.waterReceiversCount + 1;
	end;
end;

function courseplay:isValidTipTrigger(trigger)
	local isValid = trigger.className and (trigger.className == 'SiloTrigger' or trigger.isAlternativeTipTrigger or Utils.endsWith(trigger.className, 'TipTrigger'));


	return isValid;
end;


function courseplay:printTipTriggersFruits(trigger)
	for k,_ in pairs(trigger.acceptedFillTypes) do
		print(('    %s: %s'):format(tostring(k), tostring(FillUtil.fillTypeIntToName[k])));
	end
end;



--------------------------------------------------
-- Adding easy access to SiloTrigger
--------------------------------------------------
local SiloTrigger_TriggerCallback = function(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local trailer = g_currentMission.objectToTrailer[otherShapeId];
	--print(self.selectedFillType and self.selectedFillType or "no go");
	if trailer ~= nil and trailer.getAllowFillFromAir ~= nil and trailer:getAllowFillFromAir() then
		-- Make sure cp table is pressent in the trailer.
		if not trailer.cp then
			trailer.cp = {};
		end;

		if onEnter then
			-- Add the current SiloTrigger to the cp table, for easier access.
			-- self.Schnecke is only set for MischStation and that one is not an real SiloTrigger and should not be used as one.
			if not trailer.cp.currentSiloTrigger and not self.Schnecke then
				trailer.cp.currentSiloTrigger = self;
				courseplay:debug(('%s: SiloTrigger Added! (onEnter)'):format(nameNum(trailer)), 2);
			end;
		elseif onLeave then
			-- Remove the current SiloTrigger. (Is here in case Giants fixes the above bug))
			if trailer.cp.currentSiloTrigger ~= nil then
				trailer.cp.currentSiloTrigger = nil;
				courseplay:debug(('%s: SiloTrigger Removed! (onLeave)'):format(nameNum(trailer)), 2);
			end;
		end;
	end;
end;
SiloTrigger.triggerCallback = Utils.appendedFunction(SiloTrigger.triggerCallback, SiloTrigger_TriggerCallback);


local oldBunkerSiloLoad = BunkerSilo.load;
function BunkerSilo:load(nodeId)
	local old = oldBunkerSiloLoad(self,nodeId);
	local trigger = self
	
	trigger.triggerId = trigger.interactionTriggerId
	trigger.bunkerSilo = true
	trigger.className = "BunkerSiloTipTrigger"
	trigger.rootNode = nodeId
	trigger.triggerStartId = trigger.bunkerSiloArea.start
	trigger.triggerEndId = trigger.bunkerSiloArea.height
	trigger.triggerWidth = courseplay:nodeToNodeDistance(trigger.bunkerSiloArea.start, trigger.bunkerSiloArea.width)
	trigger.getTipDistanceFromTrailer = TipTrigger.getTipDistanceFromTrailer
	trigger.getTipInfoForTrailer = TipTrigger.getTipInfoForTrailer
	trigger.getAllowFillTypeFromTool = TipTrigger.getAllowFillTypeFromTool
	trigger.allowedToolTypes = 	{
								[trigger.inputFillType] = 	{
															[TipTrigger.TOOL_TYPE_TRAILER] = true
															}
								}
	
	if g_currentMission.bunkerSilos == nil then
		g_currentMission.bunkerSilos = {}
	end
	g_currentMission.bunkerSilos[trigger.triggerId] = trigger
	
	return old
end
