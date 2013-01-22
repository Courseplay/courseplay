function courseplay:detachImplement(implementIndex)
	self.tools_dirty = true
end

function courseplay:reset_tools(self)
	self.tippers = {}
	-- are there any tippers?
	self.tipper_attached = courseplay:update_tools(self, self)
	self.currentTrailerToFill = nil
	self.lastTrailerToFillDistance = nil
	self.tools_dirty = false;
end

-- is the tool a baler?
function courseplay:is_baler(workTool)
	if SpecializationUtil.hasSpecialization(Baler, workTool.specializations) or workTool.balerUnloadingState ~= nil then
		return true
	else
		return false
	end
end

-- update implements to find attached tippers
function courseplay:update_tools(self, tractor_or_implement)
	local tipper_attached = false
	if SpecializationUtil.hasSpecialization(AITractor, tractor_or_implement.specializations) then
		local object = tractor_or_implement
		if self.ai_mode == 1 or self.ai_mode == 2 then
			-- if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 3 then -- Overlader
			if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then --to do
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 4 then -- Fertilizer
			if SpecializationUtil.hasSpecialization(Sprayer, object.specializations) then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 6 then -- Baler, foragewagon, baleloader
			if courseplay:is_baler(object) or SpecializationUtil.hasSpecialization(BaleLoader, object.specializations) or object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 8 then -- Baler, foragewagon, baleloader
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(self.tippers, object)
			-- end
		end
	end

	-- go through all implements
	for k, implement in pairs(tractor_or_implement.attachedImplements) do
		local object = implement.object
		if self.ai_mode == 1 or self.ai_mode == 2 then
			--	if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 3 then -- Overlader
			if SpecializationUtil.hasSpecialization(Trailer, object.specializations) then --to do 
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 4 then -- Fertilizer
			if SpecializationUtil.hasSpecialization(Sprayer, object.specializations) or object.name == "AmazoneUX5200" then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 6 then -- Baler, foragewagon, baleloader
			if courseplay:is_baler(object) or SpecializationUtil.hasSpecialization(BaleLoader, object.specializations) or object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.ai_mode == 8 then -- Baler, foragewagon, baleloader
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(self.tippers, object)
			--		end
		end
		-- are there more tippers attached to the current implement?
		local other_tipper_attached
		if table.getn(object.attachedImplements) ~= 0 then
			other_tipper_attached = courseplay:update_tools(self, object)
		end
		if other_tipper_attached == true then
			tipper_attached = true
		end
	end

	if tipper_attached then
		return true
	end
	return nil
end


-- loads all tippers
function courseplay:load_tippers(self)
	local allowedToDrive = false
	local cx, cz = self.Waypoints[2].cx, self.Waypoints[2].cz
	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	if tipper_fill_level == nil then tipper_fill_level = 0 end
	if tipper_capacity == nil then tipper_capacity = 0 end
	local fill_level = 0
	if tipper_capacity ~= 0 then
		fill_level = tipper_fill_level * 100 / tipper_capacity
	end

	if self.currentTrailerToFill == nil then
		self.currentTrailerToFill = 1
	end

	-- drive on when required fill level is reached
	local drive_on = false
	if self.timeout < self.timer or self.last_fill_level == nil then
		if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level > self.required_fill_level_for_follow then
			drive_on = true
		end
		self.last_fill_level = fill_level
		courseplay:set_timeout(self, 7000)
	end

	if fill_level == 100 or drive_on then
		self.last_fill_level = nil
		self.loaded = true
		self.lastTrailerToFillDistance = nil
		self.currentTrailerToFill = nil
		return true
	end

	if self.lastTrailerToFillDistance == nil then

		local current_tipper = self.tippers[self.currentTrailerToFill]

		-- drive on if actual tipper is full
		if current_tipper.fillLevel == current_tipper.capacity then
			if table.getn(self.tippers) > self.currentTrailerToFill then
				local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.currentTrailerToFill].rootNode)

				self.lastTrailerToFillDistance = courseplay:distance(cx, cz, tipper_x, tipper_z)

				self.currentTrailerToFill = self.currentTrailerToFill + 1
			else
				self.currentTrailerToFill = nil
				self.lastTrailerToFillDistance = nil
			end
			allowedToDrive = true
		end

	else
		local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.currentTrailerToFill].rootNode)

		local distance = courseplay:distance(cx, cz, tipper_x, tipper_z)

		if distance > self.lastTrailerToFillDistance and self.lastTrailerToFillDistance ~= nil then
			allowedToDrive = true
		else
			allowedToDrive = false
			local current_tipper = self.tippers[self.currentTrailerToFill]
			if current_tipper.fillLevel == current_tipper.capacity then
				if table.getn(self.tippers) > self.currentTrailerToFill then
					local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.currentTrailerToFill].rootNode)
					self.lastTrailerToFillDistance = courseplay:distance(cx, cz, tipper_x, tipper_z)
					self.currentTrailerToFill = self.currentTrailerToFill + 1
				else
					self.currentTrailerToFill = nil
					self.lastTrailerToFillDistance = nil
				end
			end
		end
	end

	-- normal mode if all tippers are empty

	return allowedToDrive
end

-- unloads all tippers
function courseplay:unload_tippers(self)
	local allowedToDrive = true
	for k, tipper in pairs(self.tippers) do
		--if not tipper.allowsDetaching then
		local numReferencePoints = table.getn(tipper.tipReferencePoints);
		local fruitType = tipper:getCurrentFruitType()
          
      if self.currentTipTrigger.acceptedFillTypes[fruitType] then
         if tipper.tipState == Trailer.TIPSTATE_CLOSED then

            if self.toggledTipState < numReferencePoints then
               self.toggledTipState = self.toggledTipState + 1
               tipper:toggleTipState(self.currentTipTrigger, self.toggledTipState);
            else
               self.toggledTipState = 0
            end

         elseif tipper.tipState ~= Trailer.TIPSTATE_CLOSING then
            allowedToDrive = false  
         end

          if self.currentTipTrigger.bunkerSilo ~= nil then
            allowedToDrive = true
          end
       else
         courseplay:debug("trigger does not accept fruit", 1);
       end
   --  end
  end
	return allowedToDrive
end
