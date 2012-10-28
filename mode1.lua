-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode1(self)
	local allowedToDrive = true
	local active_tipper  = nil
	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	
	if tipper_fill_level == nil then tipper_fill_level = 0 end
	if tipper_capacity == nil then tipper_capacity = 0 end

	
	-- done tipping
	if self.unloading_tipper ~= nil and self.unloading_tipper.fillLevel == 0 then			
		if self.unloading_tipper.tipState ~=  Trailer.TIPSTATE_CLOSED then		  
		  self.unloading_tipper:toggleTipState(self.currentTipTrigger, 1)		  
		end       
		
		self.unloading_tipper = nil
		
		if tipper_fill_level == 0 then
			self.unloaded = true
			self.max_speed_level = 3
			self.currentTipTrigger = nil
		end		
	end

	-- tippers are not full
	-- tipper should be loaded 10 meters before wp 2	
	if self.loaded ~= true and ((self.recordnumber == 2 and tipper_fill_level < tipper_capacity and self.unloaded == false and self.dist < 10) or  self.lastTrailerToFillDistance) then
		allowedToDrive = courseplay:load_tippers(self)
		self.info_text = string.format(courseplay:get_locale(self, "CPloading") ,tipper_fill_level,tipper_capacity )
	end

	-- damn, i missed the trigger!
	if self.currentTipTrigger ~= nil then
	    local trigger_id = self.currentTipTrigger.triggerId
	    
	    if self.currentTipTrigger.specialTriggerId ~= nil then
	      trigger_id = self.currentTipTrigger.specialTriggerId
	    end
	    
		local trigger_x, trigger_y, trigger_z = getWorldTranslation(trigger_id)
		local ctx,cty,ctz = getWorldTranslation(self.rootNode);
		local distance_to_trigger = courseplay:distance(ctx ,ctz ,trigger_x ,trigger_z)		
		if distance_to_trigger > 60 then
			self.currentTipTrigger = nil
		end
	end

	-- tipper is not empty and tractor reaches TipTrigger
	if tipper_fill_level > 0 and self.currentTipTrigger ~= nil and self.recordnumber > 3  then		
		self.max_speed_level = 1
		allowedToDrive, active_tipper = courseplay:unload_tippers(self)
		self.info_text = courseplay:get_locale(self, "CPTriggerReached") -- "Abladestelle erreicht"		
	end
	
	return allowedToDrive, active_tipper
end  