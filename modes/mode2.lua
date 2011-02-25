
function courseplay:handle_mode2(self, dt)
  local allowedToDrive = false
  local cx = nil
  local cz = nil
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  
  if self.ai_mode == 8 then
  	self.active_combine = nil
  	self.recordnumber = 3
  	self.ai_mode = 2
  end
  
  if self.active_combine ~= nil then
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
		end
	  end
	if self.currentTrailerToFill then
      courseplay:unload_combine(self, dt)    
    end
  else
	  if self.timeout < self.timer then
	  	courseplay:update_combines(self)
	  	courseplay:set_timeout(self, 200)
	  end
	  --is any of the reachable combines full?
	  if table.getn(self.reachable_combines) > 0 then
	  	for k,combine in pairs(self.reachable_combines) do
	  	   if (combine.grainTankFillLevel > (combine.grainTankCapacity*0.5)) or combine.grainTankCapacity == 0 then
	  	     self.active_combine = combine  	     
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
  local maxRpm = self.motor.maxRpm[2]
  local dod, sl = nil, nil
  local mode = self.ai_mode
  local fillLevel, isTurning = nil, nil
  local refSpeed = nil
  local handleTurn = false
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  local tipper_percentage = tipper_fill_level/tipper_capacity * 100
  local xt, yt, zt = worldToLocal(self.tippers[self.currentTrailerToFill].rootNode, x, y, z)
  local offset = zt
  
  if self.numCollidingVehicles > 0 then
  	allowedToDrive = false
  end
  
  for k,v in pairs(self.numToolsCollidingVehicles) do
  	if v > 0 then
  		allowedToDrive = false
	end
  end
  
  if mode ~= 7 then
	if combine == nil then
	  print("no combine")
	  allowedToDrive = false
	elseif combine.turnStage ~= 0 or combine.turnTimer < combine.turnTimeout then
	  print("combine turining")
	  isTurning = true
	end
	
	if combine.grainTankCapacity > 0 then
	  fillLevel = combine.grainTankFillLevel * 100 / combine.grainTankCapacity
	else
	  fillLevel = 51
	end
  
	local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)
	local distance = Utils.vector2Length(x1, z1)
	
	if mode == 2 then
	  if z1 > 0 then
	    -- tractor in front of combine
	    -- left side of combine
		local cxl, cyl, czl = localToWorld(combine.rootNode, 25, 0, -10)
		-- righ side of combine
		local cxr, cyr, czr = localToWorld(combine.rootNode, -25, 0, -10)
		local lx, ly, lz =	worldToLocal(self.aiTractorDirectionNode, cxl, y, czl)
		-- distance to left position
		local disL = Utils.vector2Length(lx, lz)
		local rx, ry, rz = worldToLocal(self.aiTractorDirectionNode, cxr, y, czr)
		-- distance to right position
		local disR = Utils.vector2Length(rx, rz)
		if disL < disR then
		  cx, cy, cz = cxl, cyl, czl
	    else
		  cx, cy, cz = cxr, cyr, czr
	    end
	  else
	    -- tractor behind combine
	    cx, cy, cz = localToWorld(combine.rootNode, 0, 0, -30)
	  end
	  
	  		  
	  local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx, cy, cz)
		  
      dod = Utils.vector2Length(lx, lz)
		  
	  -- near combine
	  if dod < 3 then
		mode = 6
	  end
	 -- end mode 2
	
	elseif mode == 6 then
	  -- TODO eintellbar
	  local pipeOffset = 0
	  
	
	  if fillLevel == 0 then
	    handleTurn = true
	    print("handling turn!")
	    self.waitTimer = self.timer 
	    mode = 7
      elseif trailerFill == 100 then
        mode = 8
        print("full")
        self.waitTimer = self.timer 
      end
      
      local rx, ry, rz = getWorldTranslation(combine.pipeRaycastNode)
      local tX, tY, tZ = nil, nil, nil
      local ttX, ttY, ttZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, offset)
      local lx, ly, lz = nil, nil, nil
      
      if combine.isHired and combine.openPipe ~= nil then
        combine.openPipe(combine)
      end
      
      -- it's a chopper!
      if combine.grainTankCapacity == 0 then
      	tX, tY, tZ = localToWorld(combine.rootNode, 8, 0, offset)
      	cx, cz = tX, tZ
      else      
	    if combine.currentPipeState ~=1 then
          tX, tY, tZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, offset * -2)
          lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, tX, y, tZ)
          
          if lz <= 0.75 then
            tX, tY, tZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, offset * 2)
          end
      
          cx, cz = tX, tZ
          tX, tY, tZ = localToWorld(combine.pipeRaycastNode, pipeOffset, 0, offset)
        else
          tX, tY, tZ = localToWorld(combine.pipeRaycastNode, 0, 0, offset)
          cx, cz = tX, tZ
          tX, tY, tZ = localToWorld(combine.pipeRaycastNode, offset, 0, offset)
        end        
      end
  
      lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, ttX, y, ttZ)
      dod = Utils.vector2Length(lx, lz)
  
      if (combine.movingDirection <= 0 and lz <= 0.5) or lz < -0.4 * offset then        
        allowedToDrive = false
      end
      
      
      if dod > 30 then
        mode = 2
      end
      
      -- speed limit
      if dod > 10 then
        refSpeed = self.field_speed
      else
        refSpeed = combine.lastSpeed
        if lz > 0.5 then
          refSpeed = combine.lastSpeed * 1.1
          if lz > 2 then
            refSpeed = combine.lastSpeed * 1.3
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
      
    end	 -- end mode 6
    
    if isTurning and distance < 30 then
	  if mode == 6 then
	    handleTurn = true
	    mode = 7
	  else
	    allowedToDrive = false
	  end
	end
    
  end -- end mode ~= 7
  
  if handleTurn and tipper_percentage < 90 then
--    local area = courseplay:checkForFruit(self) + courseplay:checkForFruit(self.tippers[self.currentTrailerToFill])
--    if area == 0 then
--      allowedToDrive = false
--      mode = 7
--    else
      local x, y, z = localDirectionToWorld(combine.rootNode, 0, 0, 1)
      self.comDirX, self.comDirZ = x, z
      if not self.turnTargetX and not self.turnTargetZ then
        local x, y, z = localToWorld(combine.rootNode, 0, 0, -35)
        self.turnTargetX, self.turnTargetZ = x, z
        mode = 2
      end
    --end
  end
  
  if self.turnTargetX ~= nil and self.turnTargetZ ~= nil then
   -- local area = courseplay:checkForFruit(self)
    --local area2 = courseplay:checkForFruit(self.tippers[self.currentTrailerToFill])
    allowedToDrive = true
    local mx, mz = self.turnTargetX, self.turnTargetZ
    local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, mx, y, mz)
    if lz > 0 and math.abs(lx) < lz * 0.5 then
      self.turnDone = true
    elseif self.waitTimer then
	  cx, cy, cz = localToWorld(self.aiTractorDirectionNode, -5, 0, 5)
    else
  	  cx, cy, cz = localToWorld(self.aiTractorDirectionNode, 5, 0, 5)
	end
	if self.turnDone then
--	  if area == 0 and area2 == 0 and lz < 5 then
		self.turnTargetX, self.turnTargetZ = nil
		self.turnDone = nil
		self.waitTimer = nil
	  mode = 2
--	  elseif lz < 0 then
	  if lz < 0 then
	    local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
		cx, cz = x + self.comDirX * -10, z + self.comDirZ * -10
	  else
		cx, cz = mx, mz
	  end
	end
  end
  
  self.ai_mode = mode
  
  if self.waitTimer and self.timer < self.waitTimer + 7500 then
  	allowedToDrive = false
  	print("Timer active")
  end
  
  if cx == nil or cz == nil then
    allowedToDrive = false
    print("this should never happen")
  end
  
  if not allowedToDrive then
	local lx, lz = 0, 1
	AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, lx, lz)
    return 
  end  
  
  local tarx, tarz = AIVehicleUtil.getDriveDirection(self.aiTractorDirectionNode, cx, y, cz)
  
  local realSpeed = self.lastSpeedReal
  if mode == 6 or mode >= 7 then
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
  end
	
  if self.motor.maxRpm[3] < maxRpm then
	  maxRpm = self.motor.maxRpm[3]
  else
	  if maxRpm < self.motor.minRpm then
	    maxRpm = self.motor.minRpm
	  end
  end
  
  AIVehicleUtil.driveInDirection(self, dt, 45, 1, 0.8, 25, true, true, tarx, tarz, 2, 0.8)
  --self.motor.maxRpm[2] = maxRpm
end


function courseplay.checkForFruit(object)
  local node = object.rootNode
  local width = 5
  local length = 10
  local x, y, z = localToWorld(node, -width / 2, 0, -length / 2)
  local hx, hy, hz = localToWorld(node, width / 2, 0, -length / 2)
  local wx, wy, wz = localToWorld(node, -width / 2, 0, length / 2)
  local sum = 0
  for i = 1, FruitUtil.NUM_FRUITTYPES do
    local area = Utils.getFruitArea(i, x, z, wx, wz, hx, hz)
    sum = sum + area
  end
  return sum
end
