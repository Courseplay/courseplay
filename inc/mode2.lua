-- AI-states
-- 1  warte am startpunkt auf arbeit
-- 2 fahre hinter drescher
-- 3 fahre zur pipe / abtanken
-- 4 warte an dieser stelle
-- 5 fahre zu wegpunkt
-- 7 drescher voll, fahre zu wegpunkt
-- 6 trailer voll, fahre zu wegpunkt
-- 8 alle trailer voll

function courseplay:handle_mode2(self, dt)
  local allowedToDrive = false
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
    
  if self.ai_state == 1 and self.active_combine ~= nil then
    self.active_combine = nil
  end
    
  -- trailer full
  if self.ai_state == 8 then
  	self.active_combine = nil
  	self.recordnumber = 3
  	self.ai_state = 1
  	self.loaded = true
  	return true
  end
  
  
  -- support multiple tippers  
  if self.currentTrailerToFill == nil then
  self.currentTrailerToFill = 1 
  end	  
  local current_tipper = self.tippers[self.currentTrailerToFill] 
  
  if current_tipper.fillLevel == current_tipper.capacity then    
    if table.getn(self.tippers) > self.currentTrailerToFill then			
      self.currentTrailerToFill = self.currentTrailerToFill + 1
    else
      self.currentTrailerToFill = nil
      if self.ai_state ~= 5 then
        self.waitTimer = self.timer + 200
        -- set waypoint 30 meters behind and 30 meters left from combine
        if self.active_combine ~= nil and courseplay:distance_to_object(self, self.active_combine) < 10 then
          self.target_x, self.target_y, self.target_z = localToWorld(self.active_combine.rootNode, 15, 0, -15)
        else
          self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, 15, 0, -15)
        end
        -- ai_state when waypoint is reached        
        self.ai_state = 5
        self.next_ai_state = 8
      end
    end
  end
  
  if self.active_combine ~= nil then
  	
	-- is there a trailer to fill, or at least a waypoint to go to?
	if self.currentTrailerToFill or self.ai_state == 5 then
      courseplay:unload_combine(self, dt)    
    end
  else
    -- are there any combines out there that need my help?
	if self.timeout < self.timer then
	  courseplay:update_combines(self)
	  courseplay:set_timeout(self, 200)
	end
	--is any of the reachable combines full?
	if table.getn(self.reachable_combines) > 0 then
	  for k,combine in pairs(self.reachable_combines) do
	    if (combine.grainTankFillLevel > (combine.grainTankCapacity*0.5)) or combine.grainTankCapacity == 0 then
	  	  self.active_combine = combine  	     
	  	  self.ai_state = 2
	    end
	  end
	end
  end
  
  return allowedToDrive
end

function courseplay:unload_combine(self, dt)
  local allowedToDrive = true
  local combine = self.active_combine
  local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
  local cx, cy, cz = nil, nil, nil
  
  local dod, sl = nil, nil
  local mode = self.ai_state
  local combine_fill_level, combine_turning = nil, nil
  local refSpeed = nil
  local handleTurn = false
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  local tipper_percentage = tipper_fill_level/tipper_capacity * 100
  local xt, yt, zt = nil, nil, nil  
  if self.currentTrailerToFill ~= nil then
  	xt, yt, zt = worldToLocal(self.tippers[self.currentTrailerToFill].rootNode, x, y, z)
  else
    xt, yt, zt = worldToLocal(self.tippers[1].rootNode, x, y, z)
  end
  local trailer_offset = zt
  local sl = 3
  
  -- traffic collision  
  allowedToDrive = courseplay:check_traffic(self, false, allowedToDrive) 
  
  if mode == 2 or mode == 3 then
	if combine == nil then
	  self.info_text = "Mähdrescher verschwunden - Das kann eigentlich gar nicht sein! "
	  allowedToDrive = false
	elseif (combine.turnStage == 1 or combine.turnStage == 2) or combine.turnTimer < combine.turnTimeout then
	  self.info_text = "Drescher wendet. "
	  combine_turning = true
	end
		
	if combine.grainTankCapacity > 0 then
	  combine_fill_level = combine.grainTankFillLevel * 100 / combine.grainTankCapacity
	else -- combine is a chopper / has no tank
	  combine_fill_level = 51
	end
  
	--local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)
	--local distance = courseplay:distance_to_object
	
	local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)
	local distance = Utils.vector2Length(x1, z1)
	
	if mode == 2 then
	  if z1 > 0 then
	    -- tractor in front of combine
	    -- left side of combine
		local cx_left, cy_left, cz_left = localToWorld(combine.rootNode, 30, 0, -10)
		-- righ side of combine
		local cx_right, cy_right, cz_right = localToWorld(combine.rootNode, -30, 0, -10)
		local lx, ly, lz =	worldToLocal(self.aiTractorDirectionNode, cx_left, y, cz_left)
		-- distance to left position
		local disL = Utils.vector2Length(lx, lz)
		local rx, ry, rz = worldToLocal(self.aiTractorDirectionNode, cx_right, y, cz_right)
		-- distance to right position
		local disR = Utils.vector2Length(rx, rz)
		if disL < disR then
		  cx, cy, cz = cx_left, cy_left, cz_left
	    else
		  cx, cy, cz = cx_right, cy_right, cz_right
	    end
	  else
	    -- tractor behind combine
	    cx, cy, cz = localToWorld(combine.rootNode, 0, 0, -40)
	  end
	  
	  		  
	  local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx, cy, cz)
		  
      dod = Utils.vector2Length(lx, lz)
		  
	  -- near point
	  if dod < 2 then
		mode = 3
	  end
	 -- end mode 2
	
	elseif mode == 3 then
	  -- TODO eintellbar
	  local pipeOffset = 0	  
	  sl = 2
	
	  if combine_fill_level == 0 then
	    -- combine empty	    
	    self.waitTimer = self.timer + 200
	    -- set waypoint 30 meters behind combine 
	    if courseplay:distance_to_object(self, combine) < 10 then
	      self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, 0, 0, -20)
	      mode = 5
	      -- ai_state when waypoint is reached
	      self.next_ai_state = 1
	    else	    
	      mode = 1
	    end	    
	    
      end
      
      local rx, ry, rz = getWorldTranslation(combine.pipeRaycastNode)
      local tX, tY, tZ = nil, nil, nil
      local ttX, ttY, ttZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, trailer_offset)
      local lx, ly, lz = nil, nil, nil
      
      if combine.isHired and combine.openPipe ~= nil then
        combine.openPipe(combine)
      end
      
      -- it's a chopper!
      if combine.grainTankCapacity == 0 then
      	tX, tY, tZ = localToWorld(combine.rootNode, self.chopper_offset, 0, trailer_offset)
      	cx, cz = tX, tZ
      else      
        -- pipe closed
	    if combine.currentPipeState == 1 then
	      tX, tY, tZ = localToWorld(combine.pipeRaycastNode, 0, 0, trailer_offset)
	      cx, cz = tX, tZ
	      tX, tY, tZ = localToWorld(combine.pipeRaycastNode, trailer_offset, 0, 0)
	    else
	      -- pipe opening or open
          tX, tY, tZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, trailer_offset * -2)
          lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, tX, y, tZ)
          
          if lz <= 0.75 then
            tX, tY, tZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, trailer_offset * 2)
          end      
          cx, cz = tX, tZ
          tX, tY, tZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, trailer_offset)
        end        
      end
  
      lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, ttX, y, ttZ)
      dod = Utils.vector2Length(lx, lz)
      
      -- too far away from pipe, switch to state 2, and follow combine
      if dod > 50 then
        mode = 2
      end
  
      -- combine is not moving and trailer is under pipe
      
      
      if (combine.movingDirection <= 0 and lz <= 0.5) or lz < -0.4 * trailer_offset then
        if dod < 30 then     
          self.info_text ="Drescher sagt ich soll anhalten."   
          allowedToDrive = false
        end
      end            
      
      -- speed limit
      if dod > 10 then
        refSpeed = self.field_speed
      else
        sl = 2
        refSpeed = combine.lastSpeed
        if lz > 0.5 then
          refSpeed = combine.lastSpeed * 1.1
          if lz > 2 then
            refSpeed = combine.lastSpeed * 1.6
          elseif lz < -0.5 then
            refSpeed = combine.lastSpeed * 0.9
            if lz < -2 then
              refSpeed = combine.lastSpeed * 0.7
            end
          end          
        end
      end
      
      if combine.movingDirection == 0 then
      	refSpeed = self.field_speed * 1.5
      end
      
    end	 -- end mode 3
    
    if combine_turning and distance < 30 then
	  if mode == 3 then
	    -- combine empty	    
	    -- set waypoint 15 meters diagonal vorne links ;)
	    if self.chopper_offset > 0 then
	      self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, 20, 0, 15)
	    else
	      self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, -20, 0, 15)
	    end 
	    mode = 5
	    -- ai_state when waypoint is reached
	    self.next_ai_state = 2
	  else
	    -- just wait until combine has turned
	    allowedToDrive = false
	  end
	end    
  end

  -- drive to given waypoint
  if mode == 5 and self.target_x ~= nil and self.target_z ~= nil then
  	cx = self.target_x
  	cy = self.target_y
  	cz = self.target_z
  	
  	sl = 3
		  
  	distance_to_wp = courseplay:distance_to_point(self, cx, y, cz)
  	
  	if distance_to_wp < 2 then
  	  allowedToDrive = false
  	  if self.next_ai_state == 2 and not combine_turning then
  	    mode = 2
  	    self.chopper_offset = self.chopper_offset * -1 
  	  elseif self.next_ai_state == 2 and combine_turning then
  	    self.info_text = "Warte bis Drescher gewendet hat. "  	    
  	  else
  	    mode = self.next_ai_state
  	  end
  	end  	
  end
  
  self.ai_state = mode
  
  if self.waitTimer and self.timer < self.waitTimer then
  	allowedToDrive = false
  	self.info_text = "Warte auf bessere Zeiten."
  end
  
  if cx == nil or cz == nil then
    self.info_text = "Warte bis ich neuen Wegpunkt habe"  	 
    allowedToDrive = false
  end
  
  if not allowedToDrive then
	local lx, lz = 0, 1
	AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, lx, lz)
    return 
  end  
  
  local target_x, target_z = AIVehicleUtil.getDriveDirection(self.aiTractorDirectionNode, cx, y, cz)
  
  local maxRpm = self.motor.maxRpm[sl]
  
  local realSpeed = self.lastSpeedReal
  if mode == 3 then
	  if refSpeed then
	    if refSpeed < realSpeed then
	      maxRpm = maxRpm - 3
	      if refSpeed * 1.5 < realSpeed then
	        maxRpm = maxRpm - 50
	      elseif realSpeed < refSpeed then
		    maxRpm = maxRpm + 3
	      elseif self.max_speed < realSpeed then
		    maxRpm = maxRpm - 5
		  
		    if self.max_speed * 1.5 < realSpeed then
		      maxRpm = maxRpm - 50
	        elseif realSpeed < self.max_speed then
		      maxRpm = maxRpm + 5
		    elseif mode == 5 then
		      realSpeed = self.lastSpeedReal
		  
		      if self.max_speed < realSpeed then
		        maxRpm = maxRpm - 10
		      elseif realSpeed < self.max_speed then
		        maxRpm = maxRpm + 10
		      end
		    end
	      end
	    end
	  end
	 if self.motor.maxRpm[3] < maxRpm then
	  maxRpm = self.motor.maxRpm[3]
    else
	  if maxRpm < self.motor.minRpm then
	    maxRpm = self.motor.minRpm
	  end
    end
  else      
    sl = 3
  end
	
  AIVehicleUtil.driveInDirection(self, dt, 45, 1, 0.8, 25, true, true, target_x, target_z, sl, 0.8)
  self.motor.maxRpm[sl] = maxRpm
end


