
-- drives recored course
function courseplay:drive(self)
  if not self.isEntered then
	-- we want to hear our courseplayers
	setVisibility(self.aiMotorSound, true)
   end

  -- actual position
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  -- coordinates of next waypoint
  cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  -- distance to waypoint
  self.dist = courseplay:distance(cx ,cz ,ctx ,ctz)
  -- what about our tippers?
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  -- may i drive or should i hold position for some reason?
  local allowedToDrive = true
  -- in a traffic yam?
  local in_traffic = false;
   
   
 
  
  -- coordinates of coli
  local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
  -- direction of tractor
  local nx, ny, nz = localDirectionToWorld(self.aiTractorDirectionNode, 0, 0, 1)
  -- the tipper that is currently loaded/unloaded
  local active_tipper = nil
  
  
   if  self.Waypoints[self.recordnumber].wait and self.wait then
     self.global_info_text = 'Abfahrer hat Wartepunkt erreicht.'
     allowedToDrive = false
    else
	  -- abfahrer-mode
	  if self.ai_mode == 1 and self.tipper_attached and tipper_fill_level ~= nil then  
		-- is there a tipTrigger within 10 meters?
		raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
		-- handle mode
		allowedToDrive, active_tipper = courseplay:handle_mode1(self)
	  end
  end
  
  -- are there any other vehicles in front?
  if self.numCollidingVehicles > 0 then
    allowedToDrive = false;
    in_traffic = true;
    self.global_info_text = 'Abfahrer steckt im Verkehr fest'
  end

  -- are there vehicles in front of any of my implements?
   for k,v in pairs(self.numToolsCollidingVehicles) do
		if v > 0 then
			allowedToDrive = false;
			in_traffic = true;			
			self.global_info_text = 'Abfahrer steckt im Verkehr fest'
			break;
		end;
    end;
   
   
  -- stop or hold position
  if not allowedToDrive then  
     self.motor:setSpeedLevel(0, false);
     self.motor.maxRpmOverride = nil;
     AIVehicleUtil.driveInDirection(self, 1, 30, 0, 0, 28, false, moveForwards, 0, 1)	
	 
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
   end;
  
  -- more than 5 meters away from next waypoint?
  if self.dist > 5 then
	  -- speed limit at the end an the beginning of course
	  if self.recordnumber > self.maxnumber - 4 or self.recordnumber < 4 then
		  self.sl = 2
	  else
		  self.sl = 3					
	  end	
	  
	  -- is there an individual speed limit? e.g. for triggers
	  if self.max_speed ~= nil then	    
	    self.sl = self.max_speed
	  end	  

	  -- where to drive?
	  local lx, lz = AIVehicleUtil.getDriveDirection(self.rootNode,cx,cty,cz);
	  
	  self.motor.maxRpmOverride = self.motor.maxRpm[self.sl]
	  -- go, go, go!
	  AIVehicleUtil.driveInDirection(self, 1,  25, 0.5, 0.5, 20, true, true, lx, lz ,self.sl, 0.9);
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
				  self.motor.maxRpmOverride = nil;
				  WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode)
				  self.recordnumber = 1
				  self.back = false
			  end	
		  end	
	  end
	  
  end
end;  