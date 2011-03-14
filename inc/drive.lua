
-- drives recored course
function courseplay:drive(self, dt)
   
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
  cx ,cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
  -- distance to waypoint
  self.dist = courseplay:distance(cx ,cz ,ctx ,ctz)
  -- what about our tippers?
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
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
  
  
   if  self.Waypoints[self.recordnumber].wait and self.wait then
     self.global_info_text = 'hat Wartepunkt erreicht.'
     allowedToDrive = false
    else
	  -- abfahrer-mode
	  if (self.ai_mode == 1 and self.tipper_attached and tipper_fill_level ~= nil) or self.loaded then  
		-- is there a tipTrigger within 10 meters?
		raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
		-- handle mode
		allowedToDrive, active_tipper = courseplay:handle_mode1(self)
	  end
	  
	  -- combi-mode
	  if (self.ai_mode == 2 and self.recordnumber < 3 and self.tipper_attached) or self.active_combine then	      
		  return courseplay:handle_mode2(self, dt)
	  end
  end
  
  allowedToDrive = courseplay:check_traffic(self, true, allowedToDrive)
   
  -- stop or hold position
  if not allowedToDrive then  
     self.motor:setSpeedLevel(0, false);
     AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, 0, 1)	
	 
     -- unload active tipper if given
     if active_tipper then
       self.info_text = string.format("Wird entladen: %d von %d ",tipper_fill_level,tipper_capacity )
       if active_tipper.tipState == 0 then				  
		  active_tipper:toggleTipState(self.currentTipTrigger)		  
		  self.unloading_tipper = active_tipper
       end       
     end
     -- important, otherwhise i would drive on
     return;
   end
  
  -- more than 5 meters away from next waypoint?
  if self.dist > 5 then
  
  	  print(string.format("distance to WP: %f", self.dist ))
	  -- speed limit at the end an the beginning of course
	  if self.recordnumber > self.maxnumber - 4 or self.recordnumber < 4 then
		  self.sl = 2
	  else
		  self.sl = 3					
	  end		  
	  -- is there an individual speed limit? e.g. for triggers
	  if self.max_speed_level ~= nil then	    
	    self.sl = self.max_speed_level
	  end	  
	  
	  -- which speed?
	  local ref_speed = nil
	  local real_speed = self.lastSpeedReal
	  
	  if self.sl == 1 then
	    ref_speed = self.turn_speed
	  end
	  
	  if self.sl == 2 then
	  	ref_speed = self.field_speed
	  end
	  
	  if self.sl == 3 then
	  	ref_speed = self.max_speed
	  end	  
	  
	  -- slow down before waitpoint	  
	  if self.recordnumber < self.maxnumber-2 and self.Waypoints[self.recordnumber+1].wait then
	  	ref_speed = self.turn_speed
	  end
	  	  
	  local maxRpm = self.motor.maxRpm[self.sl]
	  
	  if real_speed < ref_speed then
	  	maxRpm = maxRpm + 10
	  elseif real_speed > ref_speed then
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
	  
	  self.motor.maxRpm[self.sl] = maxRpm

	  -- where to drive?
	  local lx, lz = AIVehicleUtil.getDriveDirection(self.rootNode,cx,cty,cz);
	  
	  -- go, go, go!
	  AIVehicleUtil.driveInDirection(self, dt,  45, 1, 0.7, 20, true, true, lx, lz , self.sl, 0.9);
	  
      if self.aiTrafficCollisionTrigger ~= nil then
        AIVehicleUtil.setCollisionDirection(self.aiTractorDirectionNode, self.aiTrafficCollisionTrigger, lx, lz);
      end
  else	
	  -- i'm not returning right now?	  
	  if not self.back then	      
		  if self.recordnumber < self.maxnumber  then
			  if not self.wait then
			    self.wait = true
			  end
			  self.recordnumber = self.recordnumber + 1
		  else	-- reset some variables
			  -- dont stop if in circle mode
			  if self.course_mode == 1 then
			    self.back = false
			    self.recordnumber = 1
				self.unloaded = false
			  else
			    self.back = true
			  end
			  
			  self.record = false
			  self.play = true
				  
		  end	
	  else	-- TODO is this realy needed?
		  if self.back then	
			  if self.recordnumber > 1  then
				  self.recordnumber = self.recordnumber - 1
			  else
				  self.record = false
				  self.drive  = false	
				  self.play = true
				  self.motor:setSpeedLevel(0, false);				  
				  WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode)
				  self.recordnumber = 1
				  self.back = false
			  end	
		  end	
	  end
	  
  end
end;  


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
    self.global_info_text = ' steckt im Verkehr fest'
  end
  
  return allowedToDrive
end