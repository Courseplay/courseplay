-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode1(vehicle, allowedToDrive,dt)
	local takeOverSteering = false
	
	-- done tipping
	
	if vehicle.cp.currentTipTrigger and vehicle.cp.totalFillLevel == 0 then
		courseplay:resetTipTrigger(vehicle, true);
	end

	-- tippers are not full
	if ((vehicle.cp.driveUnloadNow and vehicle.cp.trailerFillDistance) or vehicle.cp.driveUnloadNow ~= true) and
		((vehicle.cp.waypointIndex >= 1 and vehicle.cp.waypointIndex <= 3 and vehicle.cp.totalFillLevel < vehicle.cp.totalCapacity and vehicle.cp.isUnloaded == false)
			or vehicle.cp.trailerFillDistance) then
		allowedToDrive = courseplay:load_tippers(vehicle, allowedToDrive);
		courseplay:setInfoText(vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",courseplay.utils:roundToLowerInterval(vehicle.cp.totalFillLevel, 100),vehicle.cp.totalCapacity));
	end;

	-- If we are an auger wagon, we don't have an tip point, so handle it as an auger wagon in mode 3
	-- This should be in drive.lua on line 305 IMO --pops64
	if vehicle.cp.hasAugerWagon then
		courseplay:handleMode3(vehicle, allowedToDrive, dt);
	end

	-- damn, I missed the trigger!
	if vehicle.cp.currentTipTrigger ~= nil then
		local t = vehicle.cp.currentTipTrigger;
		local trigger_id = t.triggerId;

		if t.specialTriggerId ~= nil then
			trigger_id = t.specialTriggerId;
		end;
		if t.isPlaceableHeapTrigger then
			trigger_id = t.rootNode;
		end;

		if trigger_id ~= nil then
			local trigger_x, _, trigger_z = getWorldTranslation(trigger_id)
			local ctx, _, ctz = getWorldTranslation(vehicle.cp.DirectionNode);
			local distToTrigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z);

			-- Start reversing value is to check if we have started to reverse
			-- This is used in case we already registered a tipTrigger but changed the direction and might not be in that tipTrigger when unloading. (Bug Fix)
			local startReversing = vehicle.Waypoints[vehicle.cp.waypointIndex].rev and not vehicle.Waypoints[vehicle.cp.previousWaypointIndex].rev;
			if startReversing then
				courseplay:debug(string.format("%s: Is starting to reverse. Tip trigger is reset.", nameNum(vehicle)), 13);
			end;

			local isBGA = t.bunkerSilo ~= nil
			local triggerLength = Utils.getNoNil(vehicle.cp.currentTipTrigger.cpActualLength,20)
			local maxDist = isBGA and (vehicle.cp.totalLength + 55) or (vehicle.cp.totalLength + triggerLength);
			if distToTrigger > maxDist or startReversing then --it's a backup, so we don't need to care about +/-10m
				courseplay:resetTipTrigger(vehicle);
				courseplay:debug(string.format("%s: distance to currentTipTrigger = %d (> %d or start reversing) --> currentTipTrigger = nil", nameNum(vehicle), distToTrigger, maxDist), 1);
			end
		else
			courseplay:resetTipTrigger(vehicle);
		end;
	end;

	-- tipper is not empty and tractor reaches TipTrigger
	if vehicle.cp.totalFillLevel > 0 and vehicle.cp.currentTipTrigger ~= nil and vehicle.cp.waypointIndex > 3 then
		allowedToDrive,takeOverSteering = courseplay:unload_tippers(vehicle, allowedToDrive,dt);
		courseplay:setInfoText(vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
	end;

	return allowedToDrive,takeOverSteering;
end;
