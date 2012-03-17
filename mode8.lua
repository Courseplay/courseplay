-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode8(self)
	if not self.tipper_attached then
	  return false, nil
	end


	local allowedToDrive = true
	local active_tipper  = nil
	local fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	
	if fill_level == nil then fill_level = 0 end
	if tipper_capacity == nil then tipper_capacity = 0 end

	

	-- tippers are not full
	-- tipper should be loaded 10 meters before wp 2	
	if self.loaded ~= true and ((self.recordnumber == 2 and fill_level < tipper_capacity and self.unloaded == false and self.dist < 10)) then
	
		if self.tippers ~= nil then
			for i=1, table.getn(self.tippers) do
				local activeTool = self.tippers[i]
				if fill_level < self.required_fill_level_for_drive_on and not self.loaded and activeTool.sprayerFillTriggers ~= nil and table.getn(activeTool.sprayerFillTriggers) > 0 then
					allowedToDrive = false
					self.info_text = string.format(courseplay:get_locale(self, "CPloading") ,fill_level,tipper_capacity )
					local sprayer = activeTool.sprayerFillTriggers[1]
					activeTool:setIsSprayerFilling(true, sprayer.fillType, sprayer.isSiloTrigger, false)
				end
				if MapBGA ~= nil then
					for i=1, table.getn(MapBGA.ModEvent.bunkers) do      --support Heady?s BGA
						if fill_level < self.required_fill_level_for_drive_on and not self.loaded and MapBGA.ModEvent.bunkers[i].manure.trailerInTrigger ==  activeTool then
							self.info_text = "BGA LADEN"
							allowedToDrive = false
							MapBGA.ModEvent.bunkers[i].manure.fill = true 
						end
					end
				end
			end
		end
	
		   	  
		if self.timeout < self.timer or self.last_fill_level == nil then
		  if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level > self.required_fill_level_for_follow then
			allowedToDrive = true
		   end
		   self.last_fill_level = fill_level
		   courseplay:set_timeout(self, 7000)
		 end
		  
		 if fill_level == 100 or allowedToDrive then
		  self.last_fill_level = nil
		  self.loaded = true
		  self.lastTrailerToFillDistance = nil
		  self.currentTrailerToFill = nil
		 end
		 
		self.info_text = string.format(courseplay:get_locale(self, "CPloading") ,fill_level,tipper_capacity )
	end

	return allowedToDrive, active_tipper
end  