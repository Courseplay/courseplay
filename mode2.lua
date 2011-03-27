-- AI-states
-- 1  warte am startpunkt auf arbeit
-- 2 fahre hinter drescher
-- 3 fahre zur pipe / abtanken
-- 4 fahre ans heck des dreschers
-- 5 fahre zu wegpunkt
-- 7 drescher voll, fahre zu wegpunkt
-- 6 trailer voll, fahre zu wegpunkt
-- 9 wenden
-- 8 alle trailer voll
-- 9 traktor folgen

function courseplay:handle_mode2(self, dt)
  local allowedToDrive = false
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  
  local fill_level = tipper_fill_level * 100 / tipper_capacity
  
  if fill_level > self.required_fill_level_for_follow then
    self.allow_following = true
  else
    self.allow_following  = false
  end
  
  if self.ai_state == 1 and self.active_combine ~= nil then
    courseplay:unregister_at_combine(self, self.active_combine)    
  end
    
  -- trailer full
  if self.ai_state == 8 then     
  	self.recordnumber = 2
  	courseplay:unregister_at_combine(self, self.active_combine)
  	self.ai_state = 1
  	self.loaded = true
  	return false
  end
  
  -- support multiple tippers  
  if self.currentTrailerToFill == nil then
    self.currentTrailerToFill = 1 
  end	  
  
  local current_tipper = self.tippers[self.currentTrailerToFill] 
  
  if (current_tipper.fillLevel == current_tipper.capacity) or self.loaded then
    if table.getn(self.tippers) > self.currentTrailerToFill then			
      self.currentTrailerToFill = self.currentTrailerToFill + 1
    else
      self.currentTrailerToFill = nil
      if self.ai_state ~= 5 then
        -- set waypoint 40 meters in front of combine
        if self.active_combine ~= nil and courseplay:distance_to_object(self, self.active_combine) < 10 then          
          self.target_x, self.target_y, self.target_z = localToWorld(self.active_combine.rootNode, self.chopper_offset*2, 0, 40)          
        else          
          self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, self.chopper_offset*2, 0, 40)
        end
        -- ai_state when waypoint is reached
		self.ai_state = 5
        self.next_ai_state = 8
      end
    end
  end
  
  if self.active_combine ~= nil then  	
  	if self.courseplay_position == 1 then
  	  -- is there a trailer to fill, or at least a waypoint to go to?
  	  if self.currentTrailerToFill or self.ai_state == 5 then
  	    courseplay:unload_combine(self, dt)    
  	  end
  	else
	  -- follow tractor in front of me
	  tractor = self.active_combine.courseplayers[self.courseplay_position-1]
	  courseplay:follow_tractor(self, dt, tractor)
    end
  else -- NO active combine
    -- STOP!!
    AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, 0, 1)
  
  	if self.loaded then
  	  self.recordnumber = 2
  	  self.ai_state = 1
  	  return false
  	end
  
    -- are there any combines out there that need my help?
	if self.timeout < self.timer then
	  courseplay:update_combines(self)
	  courseplay:set_timeout(self, 200)
	end
	
	--is any of the reachable combines full?
	if self.reachable_combines ~= nil then
		if table.getn(self.reachable_combines) > 0 then
		
		  local best_combine = nil
		  local highest_fill_level = 0
		  local num_courseplayers = 0
		
		  -- chose the combine who needs me the most
		  for k,combine in pairs(self.reachable_combines) do
		    if (combine.grainTankFillLevel > (combine.grainTankCapacity*self.required_fill_level_for_follow/100)) or combine.grainTankCapacity == 0 then
		      if combine.grainTankCapacity == 0 then	        
		        if combine.courseplayers == nil then
		          best_combine = combine
		        elseif table.getn(combine.courseplayers) <= num_courseplayers or best_combine == nil then
		          num_courseplayers = table.getn(combine.courseplayers)
		          
		          if table.getn(combine.courseplayers) > 0 then
		            if combine.courseplayers[1].allow_following then
		              best_combine = combine
		            end
		          else
		            best_combine = combine
		          end
		        end
		      else
		        if combine.grainTankFillLevel >= highest_fill_level then
		          highest_fill_level = combine.grainTankFillLevel
		          best_combine = combine
		        end
		      end
		    end
		  end
		  
		  if best_combine ~= nil then
		    if courseplay:register_at_combine(self, best_combine) then	  	  
		  	  self.ai_state = 2
		  	end
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
  
  local trailer_offset = zt + self.tipper_offset
  
  if self.sl == nil then
    self.sl = 3
  end
  
  local colX, colZ = nil, nil
  
  -- traffic collision  
  allowedToDrive = courseplay:check_traffic(self, false, allowedToDrive) 
  
  -- is combine turning ?
  if combine ~= nil and (combine.turnStage == 1 or combine.turnStage == 2) then
    self.info_text = courseplay:get_locale(self, "CPCombineTurning") -- "Drescher wendet. "
    combine_turning = true
  end
  
  if mode == 2 or mode == 3 or mode == 4 then
    if combine == nil then
      self.info_text = "this should never happen"
      allowedToDrive = false
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
	  self.sl = 2
	  refSpeed = self.field_speed
	  courseplay:remove_from_combines_ignore_list(self, combine)
	  self.info_text =courseplay:get_locale(self, "CPDriveBehinCombine") -- ""
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
	  if dod < 3 then
		mode = 4
		local last_offset = self.chopper_offset
		self.chopper_offset = self.combine_offset		
		
		if combine.grainTankCapacity == 0 then   	      
  	      -- decide on which side to drive based on ai-combine  	      
  	      
  	      local leftFruit, rightFruit =  courseplay:side_to_drive(self, combine, 20) 
  	      
  	      if leftFruit > rightFruit then
  	      	self.chopper_offset = self.combine_offset * -1
  	      elseif leftFruit == rightFruit then  	        
  	        self.chopper_offset = last_offset * -1
  	      end
  	    end
		
	  end
	 -- end mode 2
	
	elseif mode == 3 or mode == 4 then	  
	  courseplay:add_to_combines_ignore_list(self, combine)
	  
	  if mode == 3 then
	    self.info_text =courseplay:get_locale(self, "CPDriveNextCombine") -- "Fahre neben Drescher"
	  else
	    self.info_text =courseplay:get_locale(self, "CPDriveToCombine") -- "Fahre zum Drescher"
	  end   
	  
	  refSpeed = self.field_speed
	
	  if combine_fill_level == 0 then
	    -- combine empty	    
	    -- set waypoint 30 meters behind combine 
	    --if courseplay:distance_to_object(self, combine) < 30 then
	    self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, 30, 0, -20)
	    
	    -- turn left
	    self.turn_factor = 5
	    
	    -- insert waypoint behind combine
	    local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -10)
	    local next_wp = {x = next_x, y=next_y, z=next_z}
	    table.insert(self.next_targets, next_wp) 
	    
	    -- insert another point behind combine
	    local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -30)
	    local next_wp = {x = next_x, y=next_y, z=next_z}
	    
	    table.insert(self.next_targets, next_wp) 
	    mode = 9
	    -- ai_state when waypoint is reached
	    self.next_ai_state = 1
	    --else	    
	    --  mode = 1
	    --end	 
      end
            
      local tX, tY, tZ = nil, nil, nil
      local lx, ly, lz = nil, nil, nil
      
            
      -- it's a chopper!
      if combine.grainTankCapacity > 0 and self.chopper_offset < 0 then
        self.chopper_offset = self.chopper_offset * -1
      end     
        
      local offset_to_chopper = self.chopper_offset
      if combine.turnStage ~= 0 then
        offset_to_chopper = self.chopper_offset * 1.3
      end
      ttX, ttY, ttZ = localToWorld(combine.rootNode, offset_to_chopper, 0, trailer_offset/2)        
       
      if mode == 3 then
        tX, tY, tZ = localToWorld(combine.rootNode, self.chopper_offset, 0, trailer_offset)      	  
      else
        if combine.grainTankCapacity == 0 then
          tX, tY, tZ = localToWorld(combine.rootNode, self.chopper_offset*0.6, 0, -10)
        else
          tX, tY, tZ = localToWorld(combine.rootNode, self.chopper_offset, 0, -10)
        end
      end
      	
      cx, cz = tX, tZ
  
      lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, ttX, y, ttZ)
  
      if mode == 4 and cx ~= nil and cz ~= nil then
        local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx, y, cz)		  
        dod = Utils.vector2Length(lx, lz)
      else        
        dod = Utils.vector2Length(lx, lz)
      end
  
      if dod < 2 and mode == 4 then
        allowedToDrive = false
        mode = 3
      end    
      
      -- too far away from pipe, switch to state 2, and follow combine
      if dod > 60 then
        mode = 2
      end
  
  
      -- combine is not moving and trailer is under pipe
      if ((combine.movingDirection <= 0 and lz <= 0.5) or lz < -0.4 * trailer_offset) and mode == 3 then         
        self.info_text =courseplay:get_locale(self, "CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."   
        allowedToDrive = false        
      end   
      
      
      -- refspeed depends on the distance to the combine      
      local combine_speed = combine.lastSpeed
      
      --print(string.format("lz: %f combine.turnStage %d ", lz, combine.turnStage ))
       
      if combine_speed ~= nil then
        refSpeed = combine_speed + (combine_speed * lz * 3 / 10)
        if refSpeed > self.field_speed then
          refSpeed = self.field_speed
        end 
      else
        refSpeed = self.field_speed        
      end        
      self.sl = 2
      
      if (combine.turnStage ~= 0 and lz < 20) or self.timer < self.drive_slow_timer then
        refSpeed = 1/3600        
        self.motor.maxRpm[self.sl] = 200
        if combine.turnStage ~= 0 then
          self.drive_slow_timer = self.timer + 150
        end
      end
      
      if combine.movingDirection == 0 then
      	refSpeed = self.field_speed * 1.5
      	if mode == 3 and dod < 10 then
      	  --print("near wating combine")
      	  refSpeed = 1/3600  
      	end
      end
      
    end	 -- end mode 3 or 4
    
    if combine_turning and distance < 30 then
	  if mode == 3 or mode == 4 then
	    if combine.grainTankCapacity > 0 then
	      -- normal combine
	      self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, 30, 0, -20)
	    
	      -- turn left
	      self.turn_factor = 5
	      
	      -- insert waypoint behind combine
	      local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -10)
	      local next_wp = {x = next_x, y=next_y, z=next_z}
	      table.insert(self.next_targets, next_wp) 
	      
	      -- insert another point behind combine
	      local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -30)
	      local next_wp = {x = next_x, y=next_y, z=next_z}
	      
	      table.insert(self.next_targets, next_wp) 
	      mode = 9
	      
	      self.next_ai_state = 2
	    else
	      -- corn chopper	    
	      self.leftFruit, self.rightFruit =  courseplay:side_to_drive(self, combine, -20)
	      -- set waypoint self.turn_radius meters diagonal vorne links ;)
	      if self.chopper_offset > 0 then
	        self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, self.turn_radius, 0, self.turn_radius)
	        self.turn_factor = -5
	      else
	        self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, self.turn_radius*-1, 0, self.turn_radius)
	        self.turn_factor = 5
	      end	    
	      mode = 5
	      --self.waitTimer = self.timer + 350
	      -- ai_state when waypoint is reached
	      self.next_ai_state = 9
	    end
	  else
	    -- just wait until combine has turned
	    allowedToDrive = false
	  end
	end    
  end
  
  if self.waitTimer and self.timer < self.waitTimer then
    courseplay:remove_from_combines_ignore_list(self, combine)
    allowedToDrive = false    
  else  
	  -- wende manöver
	  if mode == 9 and self.target_x ~= nil and self.target_z ~= nil then    
	    courseplay:remove_from_combines_ignore_list(self, combine)
	    self.info_text = string.format(courseplay:get_locale(self, "CPTurningTo"), self.target_x, self.target_z )  	
	    allowedToDrive = false
	    local mx, mz = self.target_x, self.target_z
	    local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, mx, y, mz)
	    self.sl = 1	    
	    refSpeed = self.turn_speed
	    if lz > 0 and math.abs(lx) < lz * 0.5 then
	      if self.next_ai_state == 4 and not combine_turning then
	        self.target_x = nil
	        self.target_z = nil        
	        mode = self.next_ai_state    
	      end
	      
	      if self.next_ai_state == 1 or self.next_ai_state == 2 then
	        -- is there another waypoint to go to?
	        if table.getn(self.next_targets)> 0 then
	          mode = 5
	          self.target_x =  self.next_targets[1].x
	          self.target_y =  self.next_targets[1].y
	          self.target_z =  self.next_targets[1].z
	          
	          table.remove(self.next_targets, 1)
	        else
	          mode = self.next_ai_state 
	        end
	      end
	    else
	     cx, cy, cz = localToWorld(self.aiTractorDirectionNode, self.turn_factor, 0, 5)
	     allowedToDrive = true
	    end
	  end
	
	  
	
	  -- drive to given waypoint
	  if mode == 5 and self.target_x ~= nil and self.target_z ~= nil then
	    courseplay:remove_from_combines_ignore_list(self, combine)
	    self.info_text = string.format(courseplay:get_locale(self, "CPDriveToWP"), self.target_x, self.target_z )
	  	cx = self.target_x
	  	cy = self.target_y
	  	cz = self.target_z
	  	
	  	self.sl = 2
	  	refSpeed = self.field_speed
			  
	  	distance_to_wp = courseplay:distance_to_point(self, cx, y, cz)
	  	
	  	if distance_to_wp < 10 then
	  	  refSpeed = 3/3600
	  	end
	  	
	  	if distance_to_wp < 2 then
	  	  allowedToDrive = false
	  	  if table.getn(self.next_targets)> 0 then
	  	  	mode = 5
	  	    self.target_x =  self.next_targets[1].x
	  	    self.target_y =  self.next_targets[1].y
	  	    self.target_z =  self.next_targets[1].z
	  	    
	  	    table.remove(self.next_targets, 1)
	  	  else
		  	  if self.next_ai_state == 9 and combine_turning == nil then  	    
		  	  	self.chopper_offset = self.combine_offset  	  	
		  	  	
		  	  	-- only for corn choppers
		  	  	if combine.grainTankCapacity == 0 then 
		  	  	  local last_offset = self.chopper_offset	  	    
		  	      if self.leftFruit > self.rightFruit then
		  	        self.chopper_offset = self.combine_offset * -1
		  	      elseif self.leftFruit == self.rightFruit then      
		  	        self.chopper_offset = last_offset * -1
		  	      end
		  	    end
		  	    
		  	    self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, self.chopper_offset*0.5, 0, -10)
		  	    mode = 9  	    
		  	    self.next_ai_state = 4
		  	  elseif self.next_ai_state == 9 and combine_turning then
		  	    self.info_text =courseplay:get_locale(self, "CPWaitUntilCombineTurned") --  ""
		  	  elseif self.next_ai_state == 1  then	 
		  	    self.sl = 1	    
		  	    refSpeed = self.turn_speed
		  	    mode = self.next_ai_state  	    
		  	  else
		  	    mode = self.next_ai_state
		  	  end
		  end
	  	end  	
	  end
  end  
  
  self.ai_state = mode  
  
  if cx == nil or cz == nil then
    self.info_text = courseplay:get_locale(self, "CPWaitForWaypoint") -- "Warte bis ich neuen Wegpunkt habe"  	 
    allowedToDrive = false
  end
  
  if not allowedToDrive then
	local lx, lz = 0, 1
	self.motor:setSpeedLevel(0, false);
	AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, lx, lz)
    return 
  end  
  
  local target_x, target_z = AIVehicleUtil.getDriveDirection(self.aiTractorDirectionNode, cx, y, cz)
  
  
  local maxRpm = self.motor.maxRpm[self.sl]
  local real_speed = self.lastSpeedReal
  
  if refSpeed == nil then
    refSpeed = real_speed
  end
  
  --print(string.format("sl: %d old RPM %d  real_speed: %d refSpeed: %d ", self.sl, maxRpm, real_speed*3600, refSpeed*3600 ))
  
  
  
  if real_speed < refSpeed then
    if real_speed * 2 < refSpeed then
      maxRpm = maxRpm + 100
    elseif real_speed * 1.5 < refSpeed then
      maxRpm = maxRpm + 50
    else
	  maxRpm = maxRpm + 5
	end	  
  end
	
  if real_speed > refSpeed then
	if real_speed / 2 > refSpeed then
	  maxRpm = maxRpm - 100
    elseif real_speed / 1.5 > refSpeed then
      maxRpm = maxRpm - 50
    else
      maxRpm = maxRpm - 5
    end	  
  end
  
		  
   -- don't drive faster/slower than you can!
   if maxRpm > self.orgRpm[3] then
	  maxRpm = self.orgRpm[3]
   else
	 if maxRpm < self.motor.minRpm then
  	   maxRpm = self.motor.minRpm
	 end
   end   
  
  
  self.motor.maxRpm[self.sl] = maxRpm
  
  AIVehicleUtil.driveInDirection(self, dt, 45, 1, 0.8, 25, true, true, target_x, target_z, self.sl, 0.9)
  
  if colX == nil then  
  	courseplay:set_traffc_collision(self, target_x, target_z)
  else
    courseplay:set_traffc_collision(self, colX, colZ)
  end 
  
end


function courseplay:side_to_drive(self, combine, distance)
  
  local x,y,z = localToWorld(combine.aiTreshingDirectionNode, 0, 0, distance) --getWorldTranslation(combine.aiTreshingDirectionNode);
    
  local dirX, dirZ = combine.aiThreshingDirectionX, combine.aiThreshingDirectionZ;
  if dirX == nil or x == nil or dirZ == nil then
    return 0, 0 
  end
  local sideX, sideZ = -dirZ, dirX;
  
  local threshWidth = 20		  
  
  local lWidthX = x - sideX*0.5*threshWidth + dirX * combine.sideWatchDirOffset;
  local lWidthZ = z - sideZ*0.5*threshWidth + dirZ * combine.sideWatchDirOffset;
  local lStartX = lWidthX - sideX*0.7*threshWidth;
  local lStartZ = lWidthZ - sideZ*0.7*threshWidth;
  local lHeightX = lStartX + dirX*combine.sideWatchDirSize;
  local lHeightZ = lStartZ + dirZ*combine.sideWatchDirSize;
  
  local rWidthX = x + sideX*0.5*threshWidth + dirX * combine.sideWatchDirOffset;
  local rWidthZ = z + sideZ*0.5*threshWidth + dirZ * combine.sideWatchDirOffset;
  local rStartX = rWidthX + sideX*0.7*threshWidth;
  local rStartZ = rWidthZ + sideZ*0.7*threshWidth;
  local rHeightX = rStartX + dirX*self.sideWatchDirSize;
  local rHeightZ = rStartZ + dirZ*self.sideWatchDirSize;
  local leftFruit = 0
  local rightFruit = 0
  
  for i = 1, FruitUtil.NUM_FRUITTYPES do
    leftFruit = leftFruit + Utils.getFruitArea(i, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ)
  
    rightFruit = rightFruit + Utils.getFruitArea(i, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ)
  end
  
  --print(string.format("fruit:  left %f right %f",leftFruit,rightFruit ))
  
  return leftFruit,rightFruit
end

function courseplay:follow_tractor(self, dt, tractor)
  local allowedToDrive = true
  local sl = tractor.sl
  local real_speed = self.lastSpeedReal
  local refSpeed = tractor.lastSpeedReal
  local mode = self.follow_mode
  local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
  local cx, cy, cz = nil, nil, nil
  
  -- drive behind tractor
    local x1, y1, z1 = worldToLocal(tractor.rootNode, x, y, z)
    local distance = Utils.vector2Length(x1, z1)
    
    
    self.info_text =courseplay:get_locale(self, "CPFollowTractor") -- "Fahre hinter Traktor"
    if z1 > 0 then
      -- tractor in front of tractor
      -- left side of tractor
      local cx_left, cy_left, cz_left = localToWorld(tractor.rootNode, 30, 0, -10)
      -- righ side of tractor
      local cx_right, cy_right, cz_right = localToWorld(tractor.rootNode, -30, 0, -10)
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
     -- tractor behind tractor
     cx, cy, cz = localToWorld(tractor.rootNode, 0, 0, -50)
    end

    local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx, cy, cz)

    dod = Utils.vector2Length(lx, lz)

    if dod < 2 then
      allowedToDrive = false
    end
  
    if distance > 50 then
      refSpeed = self.max_speed
    end  
  
  self.follow_mode = mode
  local maxRpm = self.motor.maxRpm[sl]
  
  if tractor.ai_state ~= 3 then
    self.follow_mode = 1 
    allowedToDrive = false
  end
  
  if cx == nil or cz == nil then
    self.info_text =courseplay:get_locale(self, "CPWaitForWaypoint") --  "Warte bis ich neuen Wegpunkt habe"  	 
    allowedToDrive = false
  end
  
  if not allowedToDrive then
   local lx, lz = 0, 1
   AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, lx, lz)
   return 
  end  
  
  if real_speed < refSpeed then	  
    maxRpm = maxRpm + 10	  
  end
  
  if real_speed > refSpeed then
    maxRpm = maxRpm - 10
  end
  
  -- don't drive faster/slower than you can!
  if maxRpm > self.orgRpm[3] then
    maxRpm = self.orgRpm[3]
  else
    if maxRpm < self.motor.minRpm then
      maxRpm = self.motor.minRpm
    end
  end   
  
  local target_x, target_z = AIVehicleUtil.getDriveDirection(self.aiTractorDirectionNode, cx, y, cz)
  
  self.motor.maxRpm[sl] = maxRpm
  
  AIVehicleUtil.driveInDirection(self, dt, 45, 1, 0.8, 25, true, true, target_x, target_z, sl, 0.9)
    
  courseplay:set_traffc_collision(self, target_x, target_z)  
end