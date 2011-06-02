
-- drives recored course
function courseplay:drive(self, dt)
	  
  -- unregister at combine, if there is one
  if self.loaded == true and courseplay_position ~= nil then
    courseplay:unregister_at_combine(self, self.active_combine)
  end
  
  -- switch lights on!
  if not self.isControlled then
  	-- we want to hear our courseplayers
    setVisibility(self.aiMotorSound, true)
    if g_currentMission.environment.needsLights then
       self:setLightsVisibility(true);
    else
       self:setLightsVisibility(false);
    end;
  end;

  -- actual position
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  -- coordinates of next waypoint
  if self.recordnumber > self.maxnumber then
    -- this should never happen
    self.recordnumber = self.maxnumber
  end
  
  local last_recordnumber = nil
  
   if self.recordnumber > 1 then
     last_recordnumber = self.recordnumber - 1    
    else
     last_recordnumber = 1
   end
  
  --[[local next3_recordnumber = nil
   
   if self.recordnumber < self.maxnumber-3 then
     next3_recordnumber = self.recordnumber +3
   else
   	 next3_recordnumber = self.recordnumber
   end
  local angle = nil
  cx ,cz, angle = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz, self.Waypoints[self.recordnumber].angle]]--
  --local last_cx, last_cz = nil
  --last_cx ,last_cz = self.Waypoints[next3_recordnumber].cx, self.Waypoints[next3_recordnumber].cz
  
  cx ,cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
  
  -- offset - endlich lohnt sich der mathe-lk von vor 1000 Jahren ;)
  if self.ai_mode == 6 and self.recordnumber > self.startWork and self.recordnumber < self.stopWork and self.recordnumber > 1 and self.WpOffsetX ~= nil and self.WpOffsetZ ~= nil and (self.WpOffsetX ~= 0 or self.WpOffsetZ ~= 0) then
  	--courseplay:addsign(self, cx, 10, cz)
  	--print(string.format("old WP: %d x %d ", cx, cz ))
	
	-- direction vector
	local vcx, vcz
	if self.recordnumber == 1 then
		vcx = self.Waypoints[2].cx - cx 
		vcz = self.Waypoints[2].cz - cz
	else
		if self.Waypoints[last_recordnumber].rev then
			vcx = self.Waypoints[last_recordnumber].cx - cx
			vcz = self.Waypoints[last_recordnumber].cz - cz
		else
			vcx = cx - self.Waypoints[last_recordnumber].cx
			vcz = cz - self.Waypoints[last_recordnumber].cz
		end
	end
	
	-- length of vector
	local vl = math.sqrt(vcx * vcx + vcz * vcz)
	-- if not too short: normalize and add offsets
	if vl ~= nil and vl > 0.01 then
		vcx = vcx / vl
		vcz = vcz / vl
		cx  = cx - vcz * self.WpOffsetX + vcx * self.WpOffsetZ
		cz  = cz + vcx * self.WpOffsetX + vcz * self.WpOffsetZ	
	end
		
    --print(string.format("new WP: %d x %d (angle) %d ", cx, cz, angle ))
    --courseplay:addsign(self, cx, 10, cz)
  end  
  
  self.dist = courseplay:distance(cx ,cz ,ctx ,ctz)
  --print(string.format("Tx: %f2 Tz: %f2 WPcx: %f2 WPcz: %f2 dist: %f2 ", ctx, ctz, cx, cz, self.dist ))
  -- what about our tippers?
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  local fill_level = nil
  if tipper_fill_level ~= nil then
     fill_level = tipper_fill_level * 100 / tipper_capacity
  end
  -- may i drive or should i hold position for some reason?
  local allowedToDrive = true
  -- in a traffic yam?
  
  self.max_speed_level = nil
     
  -- coordinates of coli
  local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
  -- direction of tractor
  local nx, ny, nz = localDirectionToWorld(self.aiTractorDirectionNode, 0, 0, 1)
  -- the tipper that is currently loaded/unloaded
  local active_tipper = nil


 
  
	if self.Waypoints[last_recordnumber].wait and self.wait then
		if self.ai_mode == 3 then
		   	self.global_info_text = courseplay:get_locale(self, "CPReachedOverloadPoint") --'hat Überladepunkt erreicht.'
		   	if self.tipper_attached then
		   	
		   	  -- drive on if fill_level doesn't change and fill level is < 100-self.required_fill_level_for_follow
		   	  local drive_on = false		   	  
		   	  if self.timeout < self.timer or self.last_fill_level == nil then
		   	    if self.last_fill_level ~= nil and fill_level == self.last_fill_level and fill_level < 100-self.required_fill_level_for_follow then
		   	      drive_on = true
		   	    end
		   	    self.last_fill_level = fill_level
		   	    courseplay:set_timeout(self, 400)
		   	  end
		   	
		   	  if fill_level == 0 or drive_on then
		   		self.wait = false
		   		self.last_fill_level = nil
		   		self.unloaded = true
		   	  end
			end
		elseif self.ai_mode == 4 then
			if last_recordnumber == self.startWork and fill_level ~= 0 then
				self.wait = false
			end
			if last_recordnumber == self.stopWork and self.abortWork ~= nil then
		    	self.wait = false
			end
			if last_recordnumber == self.stopWork and self.abortWork == nil then
		    	self.global_info_text = courseplay:get_locale(self, "CPWorkEnd") --'hat Arbeit beendet.'
			end
		elseif self.ai_mode == 6 then
			if last_recordnumber == self.startWork and fill_level ~= 100 then
				self.wait = false
			end
			if last_recordnumber == self.stopWork and self.abortWork ~= nil then
		    	self.wait = false
			end
			if last_recordnumber == self.stopWork and self.abortWork == nil then
		    	self.global_info_text = courseplay:get_locale(self, "CPWorkEnd") --'hat Arbeit beendet.'
			else
				self.global_info_text = courseplay:get_locale(self, "CPUnloadBale") -- "Ballen werden entladen"	
				if fill_level == 0 or drive_on then
					self.wait = false
				end			
			end
  		else
		   	self.global_info_text = courseplay:get_locale(self, "CPReachedWaitPoint") --'bereit zum entladen.'
		end
		
		
     	allowedToDrive = false
	else
		-- abfahrer-mode
		if (self.ai_mode == 1 and self.tipper_attached and tipper_fill_level ~= nil) or (self.loaded and self.ai_mode == 2) then
		-- is there a tipTrigger within 10 meters?
			raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
		-- handle mode
			allowedToDrive, active_tipper = courseplay:handle_mode1(self)
		end
		
		-- combi-mode
		if (((self.ai_mode == 2 or self.ai_mode == 3) and self.recordnumber < 2) or self.active_combine) and self.tipper_attached then	      
		  return courseplay:handle_mode2(self, dt)
		else
		  self.ai_state = 0
		end
		
		-- Fertilice loading --only for one Implement !
		if self.ai_mode == 4 and self.tipper_attached and self.startWork ~= nil and self.stopWork ~= nil then
			if self.recordnumber == 2 and fill_level < 100 and not self.loaded then   --or self.loaded
				allowedToDrive = false
		    	self.info_text = string.format(courseplay:get_locale(self, "CPloading") ,tipper_fill_level,tipper_capacity )
		    	
				if self.tippers ~= nil then
				  local tools= table.getn(self.tippers)
				  for i=1, tools do
				    local activeTool = self.tippers[i]
				    if activeTool.sprayerFillActivatable:getIsActivatable() == true then  -- only work with self on tractor to do
				       if activeTool.isSprayerFilling == false and fill_level < 100 then
				         activeTool.sprayerFillActivatable:onActivateObject()
				       end
				    end
				  end
				end
   			else
				allowedToDrive = true		 		    
			end
        elseif  self.ai_mode == 4 and (self.startWork == nil or self.stopWork == nil) then
			allowedToDrive = false
			self.info_text = self.locales.CPNoWorkArea
 		end
 		
 		if self.ai_mode ~= 5 and self.ai_mode ~= 6 and not self.tipper_attached then
 		    self.info_text = self.locales.CPWrongTrailer
 		    allowedToDrive = false
		end
		
 		
 		if self.fuelFillLevel < 50 then
 			self.global_info_text = self.locales.CPFuelWarning
		elseif self.fuelFillLevel < 25 then
		    allowedToDrive = false
		    self.global_info_text = self.locales.CPNoFuelStop
 		end
 		
 		if self.showWaterWarning then
		    allowedToDrive = false
		    self.global_info_text = self.locales.CPWaterDrive
 		end
  	end
  
   -- ai_mode 4 = fertilize
	local workArea = false
	local workSpeed = false

	if self.ai_mode == 4 and self.tipper_attached and self.startWork ~= nil and self.stopWork ~= nil   then
		allowedToDrive, workArea, workSpeed = courseplay:handle_mode4(self,allowedToDrive, workArea, workSpeed, fill_level, last_recordnumber)
	end
	
	-- Mode 6 Fieldwork for balers and foragewagon
	if self.ai_mode == 6 and self.startWork ~= nil and self.stopWork ~= nil then
		-- is there a tipTrigger within 10 meters?
		raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
		allowedToDrive, workArea, workSpeed, active_tipper = courseplay:handle_mode6(self, allowedToDrive, workArea, workSpeed, fill_level, last_recordnumber)
	end
  
  
  allowedToDrive = courseplay:check_traffic(self, true, allowedToDrive)
   
  -- stop or hold position
  if not allowedToDrive then  
     
     self.motor:setSpeedLevel(0, false);
     
     if g_server ~= nil then
       AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0.5, 0.5, 28, false, moveForwards, 0, 1)
     end
	 
     -- unload active tipper if given
     if active_tipper then
       self.info_text = string.format(courseplay:get_locale(self, "CPUnloading"), tipper_fill_level,tipper_capacity )
       if active_tipper.tipState == 0 then				  
		  active_tipper:toggleTipState(self.currentTipTrigger)		  
		  self.unloading_tipper = active_tipper
       end       
     end
     -- important, otherwhise i would drive on
     return;
   end
  
 
	
	  -- which speed?
	local ref_speed = nil
	local slowStartEnd =  self.recordnumber > self.maxnumber - 3 or self.recordnumber < 3
	local slowDownWP   = false
	local slowDownRev = false
	local real_speed = self.lastSpeedReal
    local maxRpm = self.motor.maxRpm[self.sl]
	 
	if self.recordnumber < (self.maxnumber - 3) then
 		slowDownWP = (self.Waypoints[self.recordnumber+2].wait or self.Waypoints[self.recordnumber+1].wait or self.Waypoints[self.recordnumber].wait)
		slowDownRev = (self.Waypoints[self.recordnumber+2].rev or self.Waypoints[self.recordnumber+1].rev or self.Waypoints[self.recordnumber].rev)
	else
		slowDownWP = self.Waypoints[self.recordnumber].wait
		slowDownRev = self.Waypoints[self.recordnumber].rev
	end

	if slowDownWP or self.ai_mode ~= 6 and slowDownRev or self.max_speed_level == 1 then
		self.sl = 1
    	ref_speed = self.turn_speed
	elseif slowStartEnd or workSpeed then
	    self.sl = 2
	    ref_speed = self.field_speed
	else
		self.sl = 3
		ref_speed = self.max_speed
	end
	
	if (self.sl == 3 and not self.beaconLightsActive) or (self.sl ~=3 and self.beaconLightsActive) then
	  	self:setBeaconLightsVisibility(not self.beaconLightsActive);	  
	end
	
	-- Speed Control
	maxRpm = self.motor.maxRpm[self.sl]
	 
	if real_speed < ref_speed then
		maxRpm = maxRpm + 10
	elseif real_speed > ref_speed then
		maxRpm = maxRpm - 10
	end
	  	  
	-- don't drive faster/slower than you can!
	if maxRpm > self.orgRpm[3] then
  		maxRpm = self.orgRpm[3]
	elseif maxRpm < self.motor.minRpm then
		maxRpm = self.motor.minRpm
	end
	
	self.motor.maxRpm[self.sl] = maxRpm

	  -- where to drive?
	local fwd = nil
	local distToChange = nil
	local lx, lz = AIVehicleUtil.getDriveDirection(self.rootNode,cx,cty,cz);

	if self.Waypoints[self.recordnumber].rev then
		lz = lz * -1
		lx = lx * -1
		fwd = false
	else
		fwd = true
	end
	
	-- go, go, go!
	if self.recordnumber + 1 <= self.maxnumber then
	local beforeReverse = (self.Waypoints[self.recordnumber+1].rev and not self.Waypoints[last_recordnumber].rev)
	local afterReverse =  (not self.Waypoints[self.recordnumber+1].rev and self.Waypoints[last_recordnumber].rev)
		if self.Waypoints[self.recordnumber].wait or self.recordnumber == 1 or beforeReverse or afterReverse then
			distToChange = 1
		elseif self.Waypoints[self.recordnumber].rev then
		    distToChange = 3
		else	
			distToChange = 5
		end
    else
		distToChange = 5
	end
	
	
	
	-- record shortest distance to the next waypoint
	if self.shortest_dist == nil or self.shortest_dist > self.dist then
	  self.shortest_dist = self.dist
	end
	
	if beforeReverse then
		self.shortest_dist = nil
	end
	
	-- if distance grows i must be circling	
	if self.dist > self.shortest_dist and self.recordnumber > 3 and self.dist < 15 and self.Waypoints[self.recordnumber].rev ~= true  then
	  distToChange = self.dist + 1
	end
	
	if self.dist > distToChange then
	  if g_server ~= nil then
	    AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0.5, 0.5, 8, true, fwd, lx, lz, self.sl, 0.5);
	    courseplay:set_traffc_collision(self, lx, lz)
	  end
  	else	     
  		-- reset distance to waypoint
  		self.shortest_dist = nil
		if self.recordnumber < self.maxnumber  then
		  if not self.wait then
		    self.wait = true
		  end
		  self.recordnumber = self.recordnumber + 1
		  -- ignore reverse Waypoints for mode 6
		  local in_work_area = false
		  if self.startWork ~= nil and self.stopWork ~= nil and self.recordnumber >= self.startWork and self.recordnumber <= self.stopWork then
		    in_work_area = true
		  end
		  while self.ai_mode == 6 and self.recordnumber < self.maxnumber and in_work_area and self.Waypoints[self.recordnumber].rev do
			self.recordnumber = self.recordnumber + 1
		  end
		else	-- reset some variables   
		  self.recordnumber = 1
		  self.unloaded = false
		  self.loaded = false		  
		  self.record = false
		  self.play = true	  
	  	end	
 	 end
end;  


function courseplay:set_traffc_collision(self, lx, lz)
  local maxlx = 0.7071067; --math.sin(maxAngle);

  local colDirX = lx;
  local colDirZ = lz;
   
  if colDirX > maxlx then
   colDirX = maxlx;
  elseif colDirX < -maxlx then
   colDirX = -maxlx;
  end;
  
  if colDirZ < -0.4 then
    colDirZ = 0.4;
  end;
  
  --print(string.format("colDirX: %f colDirZ %f ",colDirX,colDirZ ))	  
	  
  if self.aiTrafficCollisionTrigger ~= nil and  SpecializationUtil.hasSpecialization(aiTractor, self) and g_server ~= nil  then
    AIVehicleUtil.setCollisionDirection(self.aiTractorDirectionNode, self.aiTrafficCollisionTrigger, colDirX, colDirZ);
  end
end


function courseplay:check_traffic(self, display_warnings, allowedToDrive)
  local in_traffic = false;
  
  -- are there any other vehicles in front?
  if self.numCollidingVehicles > 0 then
    allowedToDrive = false;
    in_traffic = true;
  end
  
  -- are there vehicles in front of any of my implements?
  for k,v in pairs(self.numToolsCollidingVehicles) do
    if v > 0 then
      allowedToDrive = false;
      in_traffic = true;
      break;
    end;
  end;
  
  if display_warnings and in_traffic then
    self.global_info_text = courseplay:get_locale(self, "CPInTraffic") --' steckt im Verkehr fest'
  end
  
  return allowedToDrive
end