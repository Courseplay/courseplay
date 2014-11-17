-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode1(vehicle, allowedToDrive)
	-- done tipping
	if vehicle.cp.unloadingTipper ~= nil and vehicle.cp.unloadingTipper.fillLevel == 0 then
		vehicle.cp.unloadingTipper = nil
		if vehicle.cp.tipperFillLevel == 0 then
			courseplay:resetTipTrigger(vehicle, true);
		end
	end

	-- tippers are not full
	if vehicle.cp.isLoaded ~= true and ((vehicle.recordnumber == 2 and vehicle.cp.tipperFillLevel < vehicle.cp.tipperCapacity and vehicle.cp.isUnloaded == false) or vehicle.cp.trailerFillDistance) then
		allowedToDrive = courseplay:load_tippers(vehicle, allowedToDrive);
		vehicle.cp.infoText = string.format(courseplay:loc("COURSEPLAY_LOADING_AMOUNT"), vehicle.cp.tipperFillLevel, vehicle.cp.tipperCapacity);
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
			local trigger_x, trigger_y, trigger_z = getWorldTranslation(trigger_id)
			local ctx, cty, ctz = getWorldTranslation(vehicle.rootNode);
			local distance_to_trigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z);

			-- Start reversing value is to check if we have started to reverse
			-- This is used in case we already registered a tipTrigger but changed the direction and might not be in that tipTrigger when unloading. (Bug Fix)
			local startReversing = vehicle.Waypoints[vehicle.recordnumber].rev and not vehicle.Waypoints[vehicle.cp.lastRecordnumber].rev;
			if startReversing then
				courseplay:debug(string.format("%s: Is starting to reverse. Tip trigger is reset.", nameNum(vehicle)), 13);
			end;

			if distance_to_trigger > 75 or startReversing then
				courseplay:resetTipTrigger(vehicle);
				courseplay:debug(nameNum(vehicle) .. ": distance to currentTipTrigger = " .. tostring(distance_to_trigger) .. " (> 75 or start reversing) --> currentTipTrigger = nil", 1);
			end	
		else
			courseplay:resetTipTrigger(vehicle);
		end;
	end;

	-- tipper is not empty and tractor reaches TipTrigger
	if vehicle.cp.tipperFillLevel > 0 and vehicle.cp.currentTipTrigger ~= nil and vehicle.recordnumber > 3 then
		allowedToDrive = courseplay:unload_tippers(vehicle, allowedToDrive);
		vehicle.cp.infoText = courseplay:loc("COURSEPLAY_TIPTRIGGER_REACHED");
	end;

	return allowedToDrive;
end;
