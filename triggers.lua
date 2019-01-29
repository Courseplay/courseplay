-- triggers
local _;


-- FIND TRIGGERS
function courseplay:doTriggerRaycasts(vehicle, triggerType, direction, sides, x, y, z, nx, ny, nz, distance)
	local numIntendedRaycasts = sides and 3 or 1;
	--[[if vehicle.cp.hasRunRaycastThisLoop[triggerType] and vehicle.cp.hasRunRaycastThisLoop[triggerType] >= numIntendedRaycasts then
		return;
	end;]]
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
			local x, _, z = localToWorld(vehicle.cp.DirectionNode, vehicle.cp.tipRefOffset, 0, 0);
			--local x, _, z = localToWorld(vehicle.aiTrafficCollisionTrigger, vehicle.cp.tipRefOffset, 0, 0);
			courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 2);
		end;

		if (triggerType == 'tipTrigger' and vehicle.cp.currentTipTrigger == nil) or (triggerType == 'specialTrigger' and vehicle.cp.fillTrigger == nil) then
			local x, _, z = localToWorld(vehicle.cp.DirectionNode, -vehicle.cp.tipRefOffset, 0, 0);
			--local x, _, z = localToWorld(vehicle.aiTrafficCollisionTrigger, -vehicle.cp.tipRefOffset, 0, 0);
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
		cpDebug:drawLine(x,y,z, r,g,b, x+(nx*distance),y+(ny*distance),z+(nz*distance));
	end;
end;

-- FIND TIP TRIGGER CALLBACK
function courseplay:findTipTriggerCallback(transformId, x, y, z, distance)
	if CpManager.confirmedNoneTipTriggers[transformId] == true then
		return true;
	end;

	if courseplay.debugChannels[1] then
		cpDebug:drawPoint( x, y, z, 1, 1, 0);
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
			local trigger = tipTriggers[transformId]
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

				courseplay:debug(('    trailerFillType=%s %s'):format(tostring(trailerFillType), trailerFillType and g_fillTypeManager.indexToName[trailerFillType] or ''), 1);
				if trailerFillType and trigger.acceptedFillTypes ~= nil and trigger.acceptedFillTypes[trailerFillType] then
					courseplay:debug(('    trigger (%s) accepts trailerFillType'):format(tostring(triggerId)), 1);

					-- check trigger fillLevel / capacity
					if trigger.fillLevels ~= nil and trigger.fillLevels[trailerFillType] and trigger.capacity and trigger.fillLevels[trailerFillType] >= trigger.capacity then
						courseplay:debug(('    trigger (%s) fillLevel=%d, capacity=%d -> abort'):format(tostring(triggerId), trigger.fillLevels[trailerFillType], trigger.capacity), 1);
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
						self.cp.currentTipTrigger.cpActualLength = courseplay:nodeToNodeDistance(self.cp.DirectionNode or self.rootNode, trigger.triggerId)*2
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
		cpDebug:drawPoint(x, y, z, 1, 1, 0);
	end;
	
	--[[Tommi TODO check if its still nessesary (mode8) 
	local name = tostring(getName(transformId));
	local parent = getParent(transformId);
	for _,implement in pairs(self:getAttachedImplements()) do
		if (implement.object ~= nil and implement.object.rootNode == parent) then
			courseplay:debug(('%s: trigger %s is from my own implement'):format(nameNum(self), tostring(transformId)), 19);
			return true
		end
	end	
	]]
	
	--print("findSpecialTriggerCallback found "..tostring(transformId).." "..getName(transformId))
	if courseplay.triggers.fillTriggers[transformId] then
		--print(transformId.." is in fillTrigers")
		self.cp.fillTrigger = transformId;
		courseplay:setCustomTimer(self, 'triggerFailBackup', 10);
		return false;
	end
			
	CpManager.confirmedNoneSpecialTriggers[transformId] = true;
	CpManager.confirmedNoneSpecialTriggersCounter = CpManager.confirmedNoneSpecialTriggersCounter + 1;
	courseplay:debug(('%s: added %d (%s) to trigger blacklist -> total=%d'):format(nameNum(self), transformId, name, CpManager.confirmedNoneSpecialTriggersCounter), 19);

	return true;
end;

--FIND Trailer CALLBACK
function courseplay:findTrailerRaycastCallback(transformId, x, y, z, distance)
	local trailer = g_currentMission.nodeToObject[transformId];
	if trailer~= nil then
		local shovelFillUnits =  self.cp.shovel:getFillUnits()
		local shovelFillType = shovelFillUnits[1].fillType
		local fillUnits = trailer:getFillUnits()
		--print(string.format("trailer found; shovelFillType=%s ",tostring(shovelFillType)))
		for i=1,#fillUnits do
			local fillTypes = trailer:getFillUnitSupportedFillTypes(i)
			--print(string.format("fillUnit%s: supported:%s; fillType:%s; fillLevel:%s capacity:%s"
			--,tostring(i),tostring(fillTypes[shovelFillType]),tostring(fillUnits[i].fillType),tostring(fillUnits[i].fillLevel),tostring(fillUnits[i].capacity)))
			if fillTypes[shovelFillType]	
			and (fillUnits[i].fillType == shovelFillType or fillUnits[i].fillType == FillType.UNKNOWN)
			and fillUnits[i].fillLevel < fillUnits[i].capacity then
				self.cp.shovel.targetFound = trailer;
			end
		end
	end
	return true
end

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
		fillTriggers = {};
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
	courseplay.triggers.fillTriggersCount = 0;
	courseplay.triggers.allCount = 0;
	
	--[[
	courseplay.triggers.damageModTriggersCount = 0;
	courseplay.triggers.gasStationTriggersCount = 0;
	courseplay.triggers.liquidManureFillTriggersCount = 0;
	courseplay.triggers.sowingMachineFillTriggersCount = 0;
	courseplay.triggers.sprayerFillTriggersCount = 0;
	courseplay.triggers.waterReceiversCount = 0;
	courseplay.triggers.waterTrailerFillTriggersCount = 0;
	courseplay.triggers.weightStationsCount = 0;
	courseplay.triggers.allNonUpdateablesCount = 0;
	


	-- UPDATE
	
	-- nonUpdateable objects
	if g_currentMission.nonUpdateables ~= nil then
		courseplay:debug('\tcheck nonUpdateables', 1);
		local counter = 0;
		for k,v in pairs(g_currentMission.nonUpdateables) do
			counter = counter +1;
			
		end;
		courseplay:debug(('\t%i in list'):format(counter), 1);
	end;
	
	]]
	--itemsToSave (BigPacks)
	--print("g_currentMission.itemsToSave:"..tostring(g_currentMission.itemsToSave))
	if g_currentMission.itemsToSave ~= nil then
		courseplay:debug('\tcheck itemsToSave', 1);
		
		local counter = 0;
		for index,itemToSave in pairs (g_currentMission.itemsToSave) do
			counter = counter +1;
			local item = itemToSave.item
			if item.sellingStation ~= nil then
				local trigger = {}
				for _,unloadTrigger in pairs(item.sellingStation.unloadTriggers) do
					if unloadTrigger.baleTriggerNode then
						local triggerId = unloadTrigger.baleTriggerNode;
						trigger = {
									triggerId = triggerId;
									acceptedFillTypes = item.sellingStation.acceptedFillTypes;
													
								}
						courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
						courseplay:debug(string.format('\t\tadd %s(%i) to tipTriggers',item.sellingStation.stationName,triggerId), 1);
					end
				end
			end
		end
		courseplay:debug(('\t%i in list'):format(counter), 1);		
	end
	--[[
	-- updateable objects
	if g_currentMission.updateables ~= nil then
		courseplay:debug('\tcheck updateables', 1);
	end;

	-- onCreate objects
	local WaterMod;
	if g_currentMission.missionInfo.customEnvironment then
		WaterMod = getfenv(0)[g_currentMission.missionInfo.customEnvironment].WaterMod;
	end;
	if g_currentMission.onCreateLoadedObjects ~= nil then
		courseplay:debug('\tcheck onCreateLoadedObjects', 1);
		local counter = 0;
		for k, object in pairs(g_currentMission.onCreateLoadedObjects) do
			counter = counter +1;

		end;
		courseplay:debug(('\t%i in list'):format(counter), 1);
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
	end;]]
	-- placeables objects
	if g_currentMission.placeables ~= nil then
		courseplay:debug('\tcheck placeables', 1);
		local counter = 0
		for placeableIndex, placeable in pairs(g_currentMission.placeables) do
			counter = counter +1 

			if placeable.unloadingStation ~= nil then
				local trigger = {}
				for _,unloadTrigger in pairs(placeable.unloadingStation.unloadTriggers) do
					local triggerId = unloadTrigger.exactFillRootNode;
					trigger = {
								triggerId = triggerId;
								acceptedFillTypes = placeable.storages[1].fillTypes;
								capacity = placeable.storages[1].capacityPerFillType;
								fillLevels = placeable.storages[1].fillLevels;
					
							}
					courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
					courseplay:debug(string.format('\t\tadd %s(%i) to tipTriggers',placeable.unloadingStation.stationName,triggerId), 1);
				end
			end
			
			
			if placeable.sellingStation ~= nil then
				local trigger = {}
				for _,unloadTrigger in pairs(placeable.sellingStation.unloadTriggers) do
					local triggerId = unloadTrigger.exactFillRootNode;
					trigger = {
								triggerId = triggerId;
								acceptedFillTypes = placeable.sellingStation.acceptedFillTypes;
												
							}
					courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
					courseplay:debug(string.format('\t\tadd %s(%i) to tipTriggers',placeable.sellingStation.stationName,triggerId), 1);
				end
			end
			
			if placeable.modulesById ~= nil then
				for i=1,#placeable.modulesById do
					local myModule = placeable.modulesById[i]
					--[[print(string.format("myModule[%i]:",i))
					for index,value in pairs (myModule) do
						print(string.format("__%s:%s",tostring(index),tostring(value)))
					end]]
					if myModule.unloadPlace ~= nil then
							local triggerId = myModule.unloadPlace.target.unloadPlace.exactFillRootNode;
							local trigger = {	
												triggerId = triggerId;
												acceptedFillTypes = myModule.unloadPlace.fillTypes;
												--capacity = myModule.fillCapacity;
												--fillLevels = myModule.fillLevels;
											}
							courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
							courseplay:debug(string.format('\t\tadd %s(%i) to tipTriggers',myModule.moduleName,triggerId), 1);				
					end
										
					if myModule.feedingTrough ~= nil then
						local triggerId = myModule.feedingTrough.target.feedingTrough.exactFillRootNode;
						local trigger = {	
											triggerId = triggerId;
											acceptedFillTypes = myModule.feedingTrough.fillTypes;
											--capacity = myModule.fillCapacity;
											--fillLevels = myModule.fillLevels;
										}
						courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
						courseplay:debug(string.format('\t\tadd %s(%i) to tipTriggers',myModule.moduleName,triggerId), 1);
					end
				end
			end
			
			
			
			if placeable.buyingStation ~= nil then
				for _,loadTrigger in pairs (placeable.buyingStation.loadTriggers) do
					local triggerId = loadTrigger.triggerNode;
					courseplay:cpAddTrigger(triggerId, loadTrigger, 'fillTrigger');
					courseplay:debug(string.format('\t\tadd %s(%i) to fillTriggers', placeable.buyingStation.stationName,triggerId), 1);
				end
			end


		end
		courseplay:debug(('\t%i found'):format(counter), 1);
	end;
	
	if g_currentMission.vehicles ~= nil then
		courseplay:debug('\tcheck fillTriggerVehicles', 1);
		local counter = 0
		for vehicleIndex, vehicle in pairs(g_currentMission.vehicles) do
				if vehicle.spec_fillTriggerVehicle then
					if vehicle.spec_fillTriggerVehicle.fillTrigger ~= nil then
						counter = counter +1
						local trigger = vehicle.spec_fillTriggerVehicle.fillTrigger
						local triggerId = trigger.triggerId

						courseplay:cpAddTrigger(triggerId, trigger, 'fillTrigger');
						courseplay:debug(string.format('\t\tadd %s(%i) to fillTriggers', vehicle:getName(),triggerId), 1);
					end
				end
		end
		courseplay:debug(('\t%i found'):format(counter), 1);
	end;
		
	
		
		

	-- UPK triggers
	--[[if g_upkTrigger then
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
	]]
	if g_currentMission.bunkerSilos ~= nil then
		courseplay:debug('\tcheck bunkerSilos', 1);
		for _, trigger in pairs(g_currentMission.bunkerSilos) do
			if courseplay:isValidTipTrigger(trigger) and trigger.bunkerSilo then
				local triggerId = trigger.triggerId;
				local name = tostring(getName(triggerId));
				local className = tostring(trigger.className);
				local detailId = g_currentMission.terrainDetailId
				--local area = trigger.bunkerSiloArea
				--local px,pz, pWidthX,pWidthZ, pHeightX,pHeightZ = Utils.getXZWidthAndHeight(detailId, area.sx,area.sz, area.wx, area.wz, area.hx, area.hz);
				--local _ ,_,totalArea = getDensityParallelogram(detailId, px, pz, pWidthX, pWidthZ, pHeightX, pHeightZ, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels);
				trigger.capacity = 1000000 --DensityMapHeightUtil.volumePerPixel*totalArea*800 ;
				--print(string.format("capacity= %s  fillLevel= %s ",tostring(trigger.capacity),tostring(trigger.fillLevel)))
				courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
				courseplay:debug(('\t\tadd tipTrigger: id=%d, name=%q, className=%q, is BunkerSiloTipTrigger '):format(triggerId, name, className), 1);
			end
		end
	end
	--[[
	-- tipTriggers objects
	if g_currentMission.tipTriggers ~= nil then
		courseplay:debug('\tcheck tipTriggers', 1);
	end;

	if courseplay.liquidManureOverloaders ~= nil then
		for rootNode, vehicle in pairs(courseplay.liquidManureOverloaders) do
			local trigger = vehicle.unloadTrigger
			if trigger then
				local triggerId = trigger.triggerId
				trigger.isLiquidManureFillTrigger = true;
				trigger.isLiquidManureOverloaderFillTrigger = true;
				trigger.parentVehicle = vehicle
				courseplay:cpAddTrigger(triggerId, trigger, 'liquidManure', 'nonUpdateable');
				courseplay:debug(('\t\tadd overloader\'s liquidManureFillTrigger (id %d)'):format(triggerId), 1);
			end;
		end
	end]]
end;

function courseplay:cpAddTrigger(triggerId, trigger, groupType)
	--courseplay:debug(('%s: courseplay:cpAddTrigger: TriggerId: %s,trigger: %s, triggerType: %s,groupType: %s'):format(nameNum(self), tostring(triggerId), tostring(trigger), tostring(triggerType), tostring(groupType)), 1);
	local t = courseplay.triggers;
	if t.all[triggerId] ~= nil then return; end;

	t.all[triggerId] = trigger;
	t.allCount = t.allCount + 1;
--[[
	if groupType then
		if groupType == 'nonUpdateable' then
			t.allNonUpdateables[triggerId] = trigger;
			t.allNonUpdateablesCount = t.allNonUpdateablesCount + 1;
		end;
	end;
]]
	-- tipTriggers
	if groupType == 'tipTrigger' then
		t.tipTriggers[triggerId] = trigger;
		t.tipTriggersCount = t.fillTriggersCount + 1;
	elseif groupType == 'fillTrigger' then	
		t.fillTriggers[triggerId] = trigger;
		t.fillTriggersCount = t.fillTriggersCount + 1;
		
		
--[[
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
		t.waterReceiversCount = t.waterReceiversCount + 1;]]
	end;
end;

--Tommi TODO check if its still needed
function courseplay:isValidTipTrigger(trigger)
	local isValid = trigger.className and (trigger.className == 'SiloTrigger' or trigger.isAlternativeTipTrigger or StringUtil.endsWith(trigger.className, 'TipTrigger'));
	return isValid;
end;


function courseplay:printTipTriggersFruits(trigger)
	for k,_ in pairs(trigger.acceptedFillTypes) do
		print(('    %s: %s'):format(tostring(k), tostring(g_fillTypeManager.indexToName[k])));
	end
end;



--------------------------------------------------
-- Adding easy access to SiloTrigger
--------------------------------------------------
local SiloTrigger_TriggerCallback = function(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local trailer = g_currentMission.nodeToObject[otherShapeId];
	if trailer ~= nil then
		-- Make sure cp table is present in the trailer.
		if not trailer.cp then
			trailer.cp = {};
		end;
		if not trailer.cp.siloTriggerHits then
			trailer.cp.siloTriggerHits = 0;
		end;
		-- self.Schnecke is only set for MischStation and that one is not an real SiloTrigger and should not be used as one.
		if onEnter then --and not self.Schnecke and trailer.getAllowFillFromAir ~= nil and trailer:getAllowFillFromAir() then
			-- Add the current SiloTrigger to the cp table, for easier access.
			if not trailer.cp.currentSiloTrigger then
				trailer.cp.currentSiloTrigger = self;
				courseplay:debug(('%s: SiloTrigger Added! (onEnter)'):format(nameNum(trailer)), 2);
			end;
			trailer.cp.siloTriggerHits = trailer.cp.siloTriggerHits + 1;
		elseif onLeave and not self.Schnecke and trailer.cp.siloTriggerHits >= 1 then 
			-- Remove the current SiloTrigger.
			if trailer.cp.currentSiloTrigger ~= nil and trailer.cp.siloTriggerHits == 1 then
				trailer.cp.currentSiloTrigger = nil;
				courseplay:debug(('%s: SiloTrigger Removed! (onLeave)'):format(nameNum(trailer)), 2);
			end;
			trailer.cp.siloTriggerHits = trailer.cp.siloTriggerHits - 1;
		end;
	end;
end;
LoadTrigger.loadTriggerCallback = Utils.appendedFunction(LoadTrigger.loadTriggerCallback, SiloTrigger_TriggerCallback);

-- this could be used to fill sowing machines, but better may be a better way to find out what Vehicle.addFillUnitTrigger() does.
local cpFillTriggerCallback = function(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter then
		courseplay.debugFormat(2, 'fillTrigger onEnter')
	elseif onLeave then
		courseplay.debugFormat(2, 'fillTrigger onLeave')
	end
end
FillTrigger.fillTriggerCallback = Utils.appendedFunction(FillTrigger.fillTriggerCallback, cpFillTriggerCallback)

local oldBunkerSiloLoad = BunkerSilo.load;
function BunkerSilo:load(...)
	local old = oldBunkerSiloLoad(self,...);
	local trigger = self
	
	trigger.triggerId = trigger.interactionTriggerNode
	trigger.bunkerSilo = true
	trigger.className = "BunkerSiloTipTrigger"
	trigger.rootNode = self.nodeId
	trigger.triggerStartId = trigger.bunkerSiloArea.start
	trigger.triggerEndId = trigger.bunkerSiloArea.height
	trigger.triggerWidth = courseplay:nodeToNodeDistance(trigger.bunkerSiloArea.start, trigger.bunkerSiloArea.width)
	--trigger.getTipDistanceFromTrailer = TipTrigger.getTipDistanceFromTrailer
	--trigger.getTipInfoForTrailer = TipTrigger.getTipInfoForTrailer
	--trigger.getAllowFillTypeFromTool = TipTrigger.getAllowFillTypeFromTool
	--[[trigger.allowedToolTypes = 	{
								[trigger.inputFillType] = 	{
															[TipTrigger.TOOL_TYPE_TRAILER] = true
															}
								}
	]]
	if g_currentMission.bunkerSilos == nil then
		g_currentMission.bunkerSilos = {}
	end
	g_currentMission.bunkerSilos[trigger.triggerId] = trigger
	
	return old
end
-- do not remove this comment
-- vim: set noexpandtab:
