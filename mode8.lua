function courseplay:handleMode8(vehicle, load, unload, allowedToDrive, lx, lz, dt, tx, ty, tz, nx, ny, nz)
	courseplay:debug(('%s: handleMode8(load=%s, unload=%s, allowedToDrive=%s)'):format(nameNum(vehicle), tostring(load), tostring(unload), tostring(allowedToDrive)), 23);

	if not vehicle.cp.workToolAttached then
		return false, lx, lz;
	end;


	-- LOADING
	if load then
		courseplay:doTriggerRaycasts(vehicle, 'specialTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		allowedToDrive, lx, lz = courseplay:refillWorkTools(vehicle, vehicle.cp.refillUntilPct, allowedToDrive, lx, lz, dt);

	-- UNLOADING
	elseif unload then
		local workTool = vehicle.cp.workTools[1];
		local tankIsFull = false
		
		if vehicle.cp.prevFillLevelPct then
			vehicle.cp.isUnloading = vehicle.cp.totalFillLevelPercent < vehicle.cp.prevFillLevelPct;
		end;

		-- liquid manure sprayers/transporters
		if workTool.cp.isLiquidManureSprayer or workTool.cp.isLiquidManureOverloader then
			CpManager:setGlobalInfoText(vehicle, 'OVERLOADING_POINT');
			--                                            courseplay:handleSpecialTools(vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload)
			local isSpecialTool, allowedToDrive, lx, lz = courseplay:handleSpecialTools(vehicle, workTool, nil,    nil,   nil,    allowedToDrive, nil,   true  );
			if not isSpecialTool then
				-- trailer
				if workTool.cp.isLiquidManureOverloader and workTool.overloading ~= nil and courseplay:getTrailerInPipeRangeState(workTool) > 0 and not workTool.isOverloadingActive then
					for trailer,_ in pairs(workTool.overloading.trailersInRange) do
						courseplay:setOwnFillLevelsAndCapacities(trailer)
						if trailer.unloadTrigger ~= nil and trailer.cp.fillLevel < trailer.cp.capacity then
							workTool:setOverloadingActive(true);
							vehicle.cp.lastMode8UnloadTriggerId = trailer.unloadTrigger.triggerId;
							courseplay:debug(('    %s: [trailer] setOverloadingActive(true), triggerId=%d'):format(nameNum(workTool), vehicle.cp.lastMode8UnloadTriggerId), 23);
						end;
					end;

				-- ManureLager
				elseif workTool.setIsReFilling ~= nil and workTool.ReFillTrigger ~= nil and workTool.fillLevel > 0 and not workTool.isReFilling and workTool.ReFillTrigger.fillLevel < workTool.ReFillTrigger.capacity then
					workTool:setIsReFilling(true);
					vehicle.cp.lastMode8UnloadTriggerId = workTool.ReFillTrigger.manureTrigger;
					courseplay:debug(('    %s: [ManureLager] setIsReFilling(true), triggerId=%d'):format(nameNum(workTool), vehicle.cp.lastMode8UnloadTriggerId), 23);

				-- BGA extension V3.0
				elseif workTool.fillTriggers[1] and workTool.fillTriggers[1].bga and workTool.fillTriggers[1].bga.fermenter_bioOK and workTool.fillTriggers[1].fillLevel < workTool.fillTriggers[1].capacity then
					if not workTool.isFilling and workTool.fillLevel > 1 then
						workTool:setIsFilling(true);
						vehicle.cp.lastMode8UnloadTriggerId = workTool.fillTriggers[1].triggerId;
						courseplay:debug(('    %s: [BGAextension] setIsFilling(true), triggerId=%d'):format(nameNum(workTool), vehicle.cp.lastMode8UnloadTriggerId), 23);
					end;
				end;
			end;

		-- fuel trailers
		elseif workTool.cp.isFuelTrailer then
			-- do nothing


		-- water trailers
		elseif workTool.cp.isWaterTrailer then
			-- check if workTool is in waterReceiver trigger
			courseplay:debug(('    %s: unload'):format(nameNum(workTool)), 23);
			if not workTool.cp.waterReceiverTrigger then
				for _,obj in pairs(courseplay.triggers.waterReceivers) do
					-- WaterMod
					if obj.isWaterMod then
						courseplay:debug(('        [WATERMOD] obj.isWaterMod'):format(nameNum(workTool)), 23);
						for i,trailer in pairs(obj.WaterTrailers) do
							courseplay:debug(('            check trailer %q against workTool'):format(nameNum(trailer)), 23);
							if trailer == workTool then
								courseplay:debug('                workTool.cp.waterReceiverTrigger = obj', 23);
								workTool.cp.waterReceiverTrigger = obj;
								break;
							end;
						end;

					-- Schweinezucht water
					elseif obj.isSchweinezuchtWater then
						courseplay:debug(('        [SCHWEINEZUCHT WATER] obj.isSchweinezuchtWater'):format(nameNum(workTool)), 23);
						if obj.WaterTrailerInRange then
							courseplay:debug(('            check trailer %q against workTool'):format(nameNum(obj.WaterTrailerInRange)), 23);
							if obj.WaterTrailerInRange == workTool then
								courseplay:debug('                workTool.cp.waterReceiverTrigger = obj', 23);
								workTool.cp.waterReceiverTrigger = obj;
							end;
						end;

					-- Greenhouse
					elseif obj.isGreenhouse then
						courseplay:debug(('        [GREENHOUSE] obj.isGreenhouse'):format(nameNum(workTool)), 23);
						for i,trailer in pairs(obj.waterTrailers) do
							courseplay:debug(('            check trailer %q against workTool'):format(nameNum(trailer)), 23);
							if trailer == workTool then
								courseplay:debug('                workTool.cp.waterReceiverTrigger = obj', 23);
								workTool.cp.waterReceiverTrigger = obj;
								break;
							end;
						end;
					end;

					if workTool.cp.waterReceiverTrigger then
						break;
					end
				end
				
				--standard water tiptriggers cow, sheep and pigs
				if not workTool.cp.waterReceiverTrigger then	
					local triggers = g_currentMission.trailerTipTriggers[workTool]
					if triggers ~= nil then
						if workTool.tipState == Trailer.TIPSTATE_OPENING or workTool.tipState == Trailer.TIPSTATE_OPEN then
							vehicle.cp.isUnloading = true
						else
							if workTool.tipState == Trailer.TIPSTATE_CLOSED then
								workTool:toggleTipState(triggers[1],1);
							elseif workTool.tipState == Trailer.TIPSTATE_CLOSING then
								vehicle.cp.isUnloading = false
								tankIsFull = true
							end							
						end
					end
				end				
			end;

			-- start unloading placeables
			local tank = workTool.cp.waterReceiverTrigger;
			
			if tank then
				-- courseplay:debug(('        tank.WaterTrailerActivatable=%s, tank.waterTrailerActivatable=%s'):format(tostring(tank.WaterTrailerActivatable), tostring(tank.waterTrailerActivatable)), 23);
				local activatable, isFilling, setterFn;
				if tank.isWaterMod then -- WaterMod
					activatable = tank.WaterTrailerActivatable;
					isFilling = tank.isWaterFilling;
					setterFn = 'setIsWaterFilling';
				elseif tank.isSchweinezuchtWater then -- Schweinezucht water
					activatable = tank.WaterTrailerActivatable;
					isFilling = tank.isWaterTankFilling;
					setterFn = 'setIsWaterTankFilling';
				elseif tank.isGreenhouse then -- Greenhouse
					activatable = tank.waterTrailerActivatable;
					isFilling = tank.isWaterTankFilling;
					setterFn = 'setIsWaterTankFilling';
				else -- no valid receiving trigger
					return false, lx, lz;
				end;

				if tank.waterTrailerActivatable ~= nil and not isFilling then
					courseplay:debug(('        isWaterMod=%s, isSchweinezuchtWater=%s, isGreenhouse=%s, getIsActivatable()=%s, isFilling=%s -> %s(true)'):format(tostring(tank.isWaterMod), tostring(tank.isSchweinezuchtWater), tostring(tank.isGreenhouse), tostring(isActivatable), tostring(isFilling), setterFn), 23);
					if tank.isGreenhouse then
						tank[setterFn](tank, true, workTool);
						vehicle.cp.isUnloading = true
						
					else
						tank[setterFn](tank, true);
					end;
				else
					tankIsFull = tank.waterTankFillLevel == tank.waterTankCapacity
				end;
			end;
				
		end;


		local driveOn = vehicle.cp.totalFillLevelPercent == 0 or tankIsFull ;
		if not driveOn and vehicle.cp.prevFillLevelPct ~= nil then
			if vehicle.cp.totalFillLevelPercent > 0 and vehicle.cp.isUnloading then
				courseplay:setCustomTimer(vehicle, 'fillLevelChange', 7);
			else
				-- courseplay:debug(('        isUnloading=%s, totalFillLevelPercent=%.2f, prevFillLevelPct=%.2f, equal=%s, followAtFillLevel=%d, timerThrough=%s'):format(tostring(vehicle.cp.isUnloading), vehicle.cp.totalFillLevelPercent, vehicle.cp.prevFillLevelPct, tostring(vehicle.cp.totalFillLevelPercent == vehicle.cp.prevFillLevelPct), vehicle.cp.followAtFillLevel, tostring(courseplay:timerIsThrough(vehicle, 'fillLevelChange', false))), 23);
				if vehicle.cp.totalFillLevelPercent == vehicle.cp.prevFillLevelPct and vehicle.cp.totalFillLevelPercent < vehicle.cp.followAtFillLevel and courseplay:timerIsThrough(vehicle, 'fillLevelChange', false) then
					driveOn = true; -- drive on if fillLevelPct doesn't change for 7 seconds and fill level is < followAtFillLevel
					courseplay:debug('        no fillLevel change for 7 seconds -> driveOn', 23);
				end;
			end;
		elseif driveOn then
			courseplay:debug('        totalFillLevelPercent == 0 or tank.waterTankFillLevel == tank.waterTankCapacity -> driveOn', 23);
		end;

		vehicle.cp.prevFillLevelPct = vehicle.cp.totalFillLevelPercent;

		if driveOn and not vehicle.cp.isUnloading then
			vehicle.cp.prevFillLevelPct = nil;
			courseplay:cancelWait(vehicle);
			vehicle.cp.isUnloaded = true;
			vehicle.cp.isUnloading = false;
			if workTool.cp.waterReceiverTrigger then
				courseplay:debug('        driveOn -> set waterReceiverTrigger to nil', 23);
				workTool.cp.waterReceiverTrigger = nil;
			end;
		end;
	end;

	return allowedToDrive, lx, lz;
end;
