
-- update implements to find attached tippers
function courseplay:update_tools(tractor_or_implement, tippers)    
  local tipper_attached = false
  -- go through all implements
  for k,implement in pairs(tractor_or_implement.attachedImplements) do
    local object = implement.object
    if object.allowTipDischarge then
      tipper_attached = true
      table.insert(tippers, object)
    end    
	-- are there more tippers attached to the current implement?
    if table.getn(object.attachedImplements) ~= 0 then
	  
      local c, f = courseplay:update_tools(object, tippers)
      if c and f then
        tippers = f
      end
    end
  end
  if tipper_attached then
    return true, tippers
  end
  return nil
end


-- loads all tippers
-- TODO only works for one tipper
function courseplay:load_tippers(self)
  local allowedToDrive = false
  local cx ,cz = self.Waypoints[2].cx,self.Waypoints[2].cz
  
  if self.currentTrailerToFill == nil then
	self.currentTrailerToFill = 1
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
-- TODO only works for one tipper
function courseplay:unload_tippers(self)
  local allowedToDrive = false
  local active_tipper = nil
  local trigger = self.currentTipTrigger
  g_currentMission.tipTriggerRangeThreshold = 2
  -- drive forward until actual tipper reaches trigger
  
    -- position of trigger
    local trigger_id = self.currentTipTrigger.triggerId
	    
    if self.currentTipTrigger.specialTriggerId ~= nil then
    trigger_id = self.currentTipTrigger.specialTriggerId
    end
    local trigger_x, trigger_y, trigger_z = getWorldTranslation(trigger_id)
    
    -- tipReferencePoint of each tipper    
    for k,tipper in pairs(self.tippers) do 
      local tipper_x, tipper_y, tipper_z = getWorldTranslation(tipper.tipReferencePoint)
      local distance_to_trigger = Utils.vector2Length(trigger_x - tipper_x, trigger_z - tipper_z)
	  
	  local needed_distance = g_currentMission.tipTriggerRangeThreshold
	  
	  if trigger.className ~= "TipTrigger" then
	    needed_distance = 15
	  end
	  
      -- if tipper is on trigger
      if distance_to_trigger <= needed_distance then
		active_tipper = tipper
      end            
    end
    
  if active_tipper then    
	local trigger = self.currentTipTrigger
	-- if trigger accepts fruit
	if (trigger.acceptedFruitTypes ~= nil and trigger.acceptedFruitTypes[active_tipper:getCurrentFruitType()]) or trigger.className == "MapBGASilo" then
		allowedToDrive = false
	else
		allowedToDrive = true
	end
  else
    allowedToDrive = true
  end 
  
  return allowedToDrive, active_tipper
end