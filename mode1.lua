-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode1(self)
	local allowedToDrive = true
	local activeTipper = nil

	-- done tipping
	if self.cp.unloadingTipper ~= nil and self.cp.unloadingTipper.fillLevel == 0 then
		self.cp.unloadingTipper = nil
		if self.cp.tipperFillLevel == 0 then
			self.cp.isUnloaded = true;
			self.cp.currentTipTrigger = nil;
			self.cp.isReverseBGATipping = nil; -- Used for reverse BGA tipping
			self.cp.BGASelectedSection = nil; -- Used for reverse BGA tipping
		end
	end

	-- tippers are not full
	-- tipper should be loaded 10 meters before wp 2	
	--if self.cp.isLoaded ~= true and ((self.recordnumber == 2 and self.cp.tipperFillLevel < self.cp.tipperCapacity and self.cp.isUnloaded == false and self.dist < 10) or self.cp.lastTrailerToFillDistance) then
  	if self.cp.isLoaded ~= true and ((self.recordnumber == 2 and self.cp.tipperFillLevel < self.cp.tipperCapacity and self.cp.isUnloaded == false ) or self.cp.lastTrailerToFillDistance) then
		allowedToDrive = courseplay:load_tippers(self)
		self.cp.infoText = string.format(courseplay:loc("CPloading"), self.cp.tipperFillLevel, self.cp.tipperCapacity)
	end

	-- damn, i missed the trigger!

	if self.cp.currentTipTrigger ~= nil then
		local t = self.cp.currentTipTrigger;
		local trigger_id = t.triggerId;

		if t.specialTriggerId ~= nil then
			trigger_id = t.specialTriggerId;
		end;
		if t.isPlaceableHeapTrigger then
			trigger_id = t.rootNode;
		end;

		if trigger_id ~= nil then
			local trigger_x, trigger_y, trigger_z = getWorldTranslation(trigger_id)
			local ctx, cty, ctz = getWorldTranslation(self.rootNode);
			local distance_to_trigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z);
			
			if distance_to_trigger > 60 then 
				self.cp.currentTipTrigger = nil;
				self.cp.isReverseBGATipping = nil; -- Used for reverse BGA tipping
				self.cp.BGASelectedSection = nil; -- Used for reverse BGA tipping
				courseplay:debug(nameNum(self) .. ": distance to currentTipTrigger = " .. tostring(distance_to_trigger) .. " (> 60) --> currentTipTrigger = nil", 1);
			end	
		else
			self.cp.currentTipTrigger = nil;
			self.cp.isReverseBGATipping = nil; -- Used for reverse BGA tipping
			self.cp.BGASelectedSection = nil; -- Used for reverse BGA tipping
		end;
	end;

	-- tipper is not empty and tractor reaches TipTrigger
	if self.cp.tipperFillLevel > 0 and self.cp.currentTipTrigger ~= nil and self.recordnumber > 3 then
		allowedToDrive = courseplay:unload_tippers(self)


		self.cp.infoText = courseplay:loc("CPTriggerReached") -- "Abladestelle erreicht"
	end

	return allowedToDrive
end
