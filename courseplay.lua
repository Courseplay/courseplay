--
-- Courseplay v0.8
-- Specialization for Courseplay
--
-- @author  Lautschreier / Hummel
-- @version:	v0.8.20.02.11
-- @testing:    bullgore80
-- @history:	
--      02.01.11/06.02.11 course recording and driving (Lautschreier)
--      14.02.11 added courseMode (Hummel)
--		15.02.11 refactoring and collisiontrigger (Hummel)
--		16.02.11 signs are disapearing, tipper support (Hummel)
--      17.02.11 info text and global saving of "course_players" (Hummel)
--      18.02.11 more than one tipper recognized by tractor // name of tractor in global info message
-- 		19.02.11 trailer unloads on trigger, kegel gefixt // (Hummel/Lautschreier)
--      19.02.11 changed loading/unloading logic, changed sound, added hire() dismiss()  (hummel)
--      19.02.11 auf/ablade logik erweitert - ablade trigger vergrößert  (hummel)
--      20.02.11 laden/speichern von kursen (hummel)
courseplay = {};

-- working tractors saved in this
working_course_players = {};

function courseplay.prerequisitesPresent(specializations)
    return true;
end

function courseplay:load(xmlFile)
	-- current number of waypoint
	self.recordnumber = 1
	self.lastrecordnumber = nil
	-- TODO what is this?
	self.tmr = 1
	-- waypoints are stored in here
	self.Waypoints = {}
	-- loaded/saved courses saved in here
	self.courses = {}
	-- TODO still needed?
	self.play = false
	-- TODO still needed?
	self.back = false 	
	-- total number of course players
	self.working_course_player_num = nil
	
	-- info text on tractor
	self.info_text = nil
	
	-- global info text - also displayed when not in vehicle
	self.global_info_text = nil
	
	-- course modes: 1 circle route - 2 returning route
	self.course_mode = 1
	
	-- ai mode: 1 abfahrer
	self.ai_mode = 1
	
	-- our arrow is displaying dirction to waypoints
	self.ArrowPath = Utils.getFilename("Specializations/arrow.png", self.baseDirectory);
	self.ArrowOverlay = Overlay:new("Arrow", self.ArrowPath, 0.4, 0.08, 0.250, 0.250);
	self.ArrowOverlay:render()
	
	-- kegel der route	
	local baseDirectory = getAppBasePath()
	local i3dNode = Utils.loadSharedI3DFile("data/maps/models/objects/beerKeg/beerKeg.i3d", baseDirectory)
	local itemNode = getChildAt(i3dNode, 0)
	link(getRootNode(), itemNode)
	setRigidBodyType(itemNode, "NoRigidBody")
	setTranslation(itemNode, 0, 0, 0)
	setVisibility(itemNode, false)
	delete(i3dNode)
	self.sign = itemNode
	-- visual waypoints saved in this
	self.signs = {}
	
	-- course name for saving
	self.current_course_name = nil
	
	-- individual speed limit
	self.max_speed = nil
	
	-- traffic collision	
	self.onTrafficCollisionTrigger = courseplay.onTrafficCollisionTrigger;
	self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	
	self.numCollidingVehicles = 0;
	self.numToolsCollidingVehicles = {};
	
	
	-- tipTrigger
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	
	
	-- tippers
	self.tippers = {}
	self.tipper_attached = false	
	self.currentTrailerToFill = nil
	self.lastTrailerToFillDistance = nil
	self.unloaded = false	
	self.unloading_tipper = nil
	
	-- for user input like saving
	self.user_input_active = false
	self.user_input_message = nil
	self.user_input = nil
	self.save_name = false
	
	
	self.course_selection_active = false
	self.select_course = false
	self.selected_course_number = 0
	
	-- name search - look for the tractors name for messages on screen
	local aNameSearch = {"vehicle.name." .. g_languageShort, "vehicle.name.en", "vehicle.name", "vehicle#type"};
	
	if Steerable.load ~= nil then
		local orgSteerableLoad = Steerable.load
		
		Steerable.load = function(self,xmlFile)
			orgSteerableLoad(self,xmlFile)			
			for nIndex,sXMLPath in pairs(aNameSearch) do 
				self.name = getXMLString(xmlFile, sXMLPath);
				if self.name ~= nil then break; end;
			end;
			if self.name == nil then self.name = g_i18n:getText("UNKNOWN") end;
		end;
	end;
	
	-- loading saved courses from xml
	courseplay:load_courses(self)
end	
	
-- displays help text, user_input 	
function courseplay:draw()
	if not self.drive then
		if not self.record then		
			-- switch course mode
			if self.course_mode == 1 then
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayRound"), InputBinding.CourseMode);			      
			else
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayReturn"), InputBinding.CourseMode);			      
			end
				
			if InputBinding.hasEvent(InputBinding.CourseMode) then 
				if self.course_mode == 1 then
					self.course_mode = 0
				else
					self.course_mode = 1
				end
			end
				
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStart"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				courseplay:start_record(self)
			end
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStop"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				courseplay:stop_record(self)
			end
		end	
	end  
	
	if self.play then
		if not self.drive then 
			g_currentMission:addHelpButtonText(g_i18n:getText("CourseReset"), InputBinding.CourseReset);
			if InputBinding.hasEvent(InputBinding.CourseReset) then 
				courseplay:reset_course(self)
			end	
		
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStart"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				courseplay:start(self)
			end	
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStop"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				courseplay:stop(self)
			end
		end				
	end
	
	if self.dcheck and table.getn(self.Waypoints) > 1 then
		courseplay:dcheck(self);	  
	end
	
	courseplay:infotext(self);
	if self.user_input_message then
		courseplay:user_input(self);
	end
	
	
	if self.course_selection_active then
		courseplay:display_course_selection(self);
	end
end	


-- is been called everey frame
function courseplay:update()
	-- show visual waypoints only when in vehicle
	if self.isEntered then
		courseplay:sign_visibility(self, true)
	else
		courseplay:sign_visibility(self, false)
	end

	-- we are in record mode
	if self.record then 
	  courseplay:record(self);
	end	
	
	-- we are in drive mode
	if self.drive then
	  courseplay:drive(self);
	end	
end		


-- starts driving the course
function courseplay:start(self)    
	
	self.numCollidingVehicles = 0;
	self.numToolsCollidingVehicles = {};
	self.drive  = false
	self.record = false
	
	
	-- add do working players if not already added
	if self.working_course_player_num == nil then
		self.working_course_player_num = courseplay:add_working_player(self)
	end	
	
	self.tippers = {}
	-- are there any tippers?	
	self.tipper_attached, self.tippers = courseplay:update_tools(self, self.tippers)
		
	if self.tipper_attached then
		-- tool (collision)triggers for tippers
		for k,object in pairs(self.tippers) do
		  AITractor.addToolTrigger(self, object)
		end
	end
	
	if self.lastrecordnumber ~= nil then
		self.recordnumber = self.lastrecordnumber
		self.lastrecordnumber = nil
	else
		-- TODO still needed?
		if self.back then
			self.recordnumber = self.maxnumber - 2
		else
			self.recordnumber = 1
		end
	end
	
	
	
	-- show arrow
	self.dcheck = true
	-- current position
	local ctx,cty,ctz = getWorldTranslation(self.rootNode);
	-- positoin of next waypoint
	local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
	-- distance
	dist = courseplay:distance(ctx ,ctz ,cx ,cz)
	
	
	if dist < 15 then
		-- hire a helper
		self:hire()
		-- ok i am near the waypoint, let's go
		self.drive  = true
		if self.aiTrafficCollisionTrigger ~= nil then
		   addTrigger(self.aiTrafficCollisionTrigger, "onTrafficCollisionTrigger", self);
		end
		self.record = false
		self.dcheck = false
	end			
end


-- adds courseplayer to global table, so that the system knows all of them
function courseplay:add_working_player(self)
   table.insert(working_course_players, self)
   return table.getn(working_course_players)
end

-- stops driving the course
function courseplay:stop(self)
	self:dismiss()
	self.record = false
	-- removing collision trigger
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end
	
	-- removing tippers
	if self.tipper_attached then
		for key,tipper in pairs(self.tippers) do
		  AITractor.removeToolTrigger(self, tipper)
		  tipper:aiTurnOff()
		end
	end
	
	-- reseting variables
	self.unloaded = false
	self.currentTipTrigger = nil
	self.drive  = false	
	self.play = true
	self.dcheck = false
	--self.motor:setSpeedLevel(0, false);
	--self.motor.maxRpmOverride = nil;
	WheelsUtil.updateWheelsPhysics(self, 0, 0, 0, false, self.requiredDriveMode)
	self.lastrecordnumber = self.recordnumber
	self.recordnumber = 1	
end


-- starts course recording -- just setting variables
function courseplay:start_record(self)
    courseplay:reset_course(self)
	
	self.record = true
	self.drive  = false
	-- show arrow to start if in circle mode
	if self.course_mode == 1 then
		self.dcheck = true
	end
	self.recordnumber = 1
	self.tmr = 101
end		

-- stops course recording -- just setting variables
function courseplay:stop_record(self)
	self.record = false
	self.drive  = false	
	self.dcheck = false
	self.play = true
	self.maxnumber = self.recordnumber - 1
	self.back = false
end		

-- resets actual course -- just setting variables
function courseplay:reset_course(self)	
	self.recordnumber = 1
	self.tmr = 1
	self.Waypoints = {}
	courseplay:sign_visibility(self, false)
	self.signs = {}
	self.play = false
	self.back = false
	self.course_mode = 1
end	

		

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
  local allowedToDrive = true;  
  -- in a traffic yam?
  local in_traffic = false;
    
  -- coordinates of coli
  local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
  -- direction of tractor
  local nx, ny, nz = localDirectionToWorld(self.aiTractorDirectionNode, 0, 0, 1)
  -- the tipper that is currently loaded/unloaded
  local active_tipper = nil
      
  -- abfahrer-mode
  if self.ai_mode == 1 and self.tipper_attached and tipper_fill_level ~= nil then  
	-- is there a tipTrigger within 10 meters?
	raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
	-- handle mode
	allowedToDrive, active_tipper = courseplay:handle_mode1(self)
  end
  
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
	  AIVehicleUtil.driveInDirection(self, 1,  30, 0, 0, 28, true, true, lx, lz ,self.sl, 2);
  else	
	  -- i'm not returning right now?
	  
	  if not self.back then	      
		  if self.recordnumber < self.maxnumber  then
		
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
  
  
-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode1(self)
	local allowedToDrive = true
	local active_tipper  = nil
	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	
	-- done tipping
	if self.unloading_tipper ~= nil and self.unloading_tipper.fillLevel == 0 then			
		if self.unloading_tipper.tipState ~= 0 then		  
		  self.unloading_tipper:toggleTipState(self.currentTipTrigger)		  
		end       
		
		self.unloading_tipper = nil
		
		if tipper_fill_level == 0 then
			self.unloaded = true
			self.max_speed = 3
			self.currentTipTrigger = nil
		end
		
	end


	-- tippers are not full
	-- tipper should be loaded 10 meters before wp 2	

	if (self.recordnumber == 2 and tipper_fill_level < tipper_capacity and self.unloaded == false and self.dist < 10) or  self.lastTrailerToFillDistance then
		allowedToDrive = courseplay:load_tippers(self)
		self.info_text = string.format("Wird beladen: %d von %d ",tipper_fill_level,tipper_capacity )
	end

	-- damn, i missed the trigger!
	if self.currentTipTrigger ~= nil then
		local trigger_x, trigger_y, trigger_z = getWorldTranslation(self.currentTipTrigger.triggerId)
		local ctx,cty,ctz = getWorldTranslation(self.rootNode);
		local distance_to_trigger = courseplay:distance(ctx ,ctz ,trigger_x ,trigger_z)
		if distance_to_trigger > 30 then
			self.currentTipTrigger = nil
		end
	end

	-- tipper is not empty and tractor reaches TipTrigger
	if tipper_fill_level > 0 and self.currentTipTrigger ~= nil then		
		self.max_speed = 1
		allowedToDrive, active_tipper = courseplay:unload_tippers(self)
		self.info_text = "Abladestelle erreicht"
	end
	
	return allowedToDrive, active_tipper
end  
  
-- records waypoints for course
function courseplay:record(self)
	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ)) 


	if self.recordnumber < 4 then
		self.rotatedTime = 0
	end 
	if self.recordnumber > 2 then
		local oldcx ,oldcz ,oldangle= self.Waypoints[self.recordnumber - 1].cx,self.Waypoints[self.recordnumber - 1].cz,self.Waypoints[self.recordnumber - 1].angle
		anglediff = math.abs(newangle - oldangle)
		self.dist = courseplay:distance(cx ,cz ,oldcx ,oldcz)
		if self.dist > 5 and (anglediff > 5 or dist > 10) then
			self.tmr = 101
		end
	end 

	if self.recordnumber == 2 then
		local oldcx ,oldcz = self.Waypoints[1].cx,self.Waypoints[1].cz

		self.dist = courseplay:distance(cx ,cz ,oldcx ,oldcz)
		if self.dist > 10 then
			self.tmr = 101
		end
	end 
	if self.tmr > 100 then 
		self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle}
		if self.recordnumber < 3 then 
			courseplay:addsign(self, cx, cy,cz)
		end 
		self.tmr = 1
		self.recordnumber = self.recordnumber + 1
	end
end;


-- displays arrow and distance to start point
function courseplay:dcheck(self)
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  if self.back then 
      number = self.maxnumber - 2
  else
      number = 1
  end	
  
  local arrowUV = {}
  local lx, ly, lz = worldToLocal(self.rootNode, self.Waypoints[number].cx, 0, self.Waypoints[number].cz)
  local arrowRotation = Utils.getYRotationFromDirection(lx, lz)
  
  arrowUV[1] = -0.5 * math.cos(-arrowRotation) + 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[2] = -0.5 * math.sin(-arrowRotation) - 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[3] = -0.5 * math.cos(-arrowRotation) - 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[4] = -0.5 * math.sin(-arrowRotation) + 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[5] = 0.5 * math.cos(-arrowRotation) + 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[6] = 0.5 * math.sin(-arrowRotation) - 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[7] = 0.5 * math.cos(-arrowRotation) - 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[8] = 0.5 * math.sin(-arrowRotation) + 0.5 * math.cos(-arrowRotation) + 0.5
  
  setOverlayUVs(self.ArrowOverlay.overlayId, arrowUV[1], arrowUV[2], arrowUV[3], arrowUV[4], arrowUV[5], arrowUV[6], arrowUV[7], arrowUV[8])
  self.ArrowOverlay:render()
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  if self.record then
    return
  end
  local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  dist = courseplay:distance(ctx ,ctz ,cx ,cz)
  self.info_text = string.format("entfernung: %d ",dist )  
end;


function courseplay:delete()
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end
	
end;	

function courseplay:mouseEvent(posX, posY, isDown, isUp, button)
end		


-- deals with keyEvents
function courseplay:keyEvent(unicode, sym, modifier, isDown)
  if isDown and sym == Input.KEY_s and bitAND(modifier, Input.MOD_CTRL) > 0 then
	courseplay:input_course_name(self)
  end
  
  
  if isDown and sym == Input.KEY_o and bitAND(modifier, Input.MOD_CTRL) > 0 then
	courseplay:select_course(self)
  end
  
  -- user input fu
  if isDown and self.user_input_active then
	if 31 < unicode and unicode < 127 then 
		if self.user_input:len() <= 20 then
			self.user_input = self.user_input .. string.char(unicode)
		end
	end
	
	-- backspace
	if sym == 8 then
		if  self.user_input:len() >= 1 then
			 self.user_input =  self.user_input:sub(1, self.user_input:len() - 1)
		end
	end
	
	-- enter
	if sym == 13 then
		courseplay:handle_user_input(self)
	end
  end
  
  if isDown and self.course_selection_active then
	-- enter
	if sym == 13 then
		self.select_course = true
		courseplay:handle_user_input(self)
	end
	
	if sym == 273 then
	  if self.selected_course_number > 1 then
		self.selected_course_number = self.selected_course_number - 1
	  end
	end
	
	if sym == 274 then
	  if self.selected_course_number < 10 then
		self.selected_course_number = self.selected_course_number + 1
	  end
	end
  end
end;	


-- enables input for course name
function courseplay:input_course_name(self)
 self.user_input = ""
 self.user_input_active = true
 self.save_name = true
 self.user_input_message = "Name des Kurses: "
end

--  does something with the user input
function courseplay:handle_user_input(self)
	-- name for current_course
	if self.save_name then
	   courseplay:load_courses(self)
	   self.user_input_active = false
	   self.current_course_name = self.user_input
	   self.user_input = ""	   
	   self.user_input_message = nil
	   self.courses[self.current_course_name] = self.Waypoints
	   courseplay:save_courses(self)
	end
	
	if self.select_course then
		self.course_selection_active = false
		if self.current_course_name ~= nil then
		  courseplay:reset_course(self)
		  self.Waypoints = self.courses[self.current_course_name]
		  self.play = true
		  self.maxnumber = table.getn(self.Waypoints)
		end
	end
end

-- renders input form
function courseplay:user_input(self)
	renderText(0.4, 0.9,0.02, self.user_input_message .. self.user_input);
end

function courseplay:display_course_selection(self)
  self.current_course_name = nil
  renderText(0.4, 0.9 ,0.02, "Kurs Laden:");
  
  local i = 0
  for name,wps in pairs(self.courses) do
    local addit = ""
	i = i + 1
	if self.selected_course_number == i then
	  addit = " <<<< "
	  self.current_course_name = name
	end
	local yspace = 0.9 - (i * 0.022)
	
	renderText(0.4, yspace ,0.02, name .. addit);
  end
  
end

-- renders info_text and global text for courseplaying tractors
function courseplay:infotext(self)
	if self.isEntered then
		if self.info_text ~= nil then
		  renderText(0.4, 0.001,0.02, self.info_text);
		end
	end
	
	if self.global_info_text ~= nil then
	  local yspace = self.working_course_player_num * 0.022
	  local show_name = ""
	  if self.name ~= nil then
	    show_name = self.name
	  end
	  renderText(0.4, yspace ,0.02, show_name .. " " .. self.global_info_text);
	end
	self.info_text = nil
	self.global_info_text = nil
end


-- distance between two coordinates
function courseplay:distance(x1 ,z1 ,x2 ,z2)
	xd = (x1 - x2) * (x1 - x2)
	zd = (z1 -z2) * (z1 - z2)
	dist = math.sqrt(math.abs(xd + zd) )
	return dist
end

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

	if distance > self.lastTrailerToFillDistance then	
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
  -- drive forward until actual tipper reaches trigger
  
    -- position of trigger
    local trigger_x, trigger_y, trigger_z = getWorldTranslation(self.currentTipTrigger.triggerId)
    
    -- tipReferencePoint of each tipper    
    for k,tipper in pairs(self.tippers) do 
      local tipper_x, tipper_y, tipper_z = getWorldTranslation(tipper.tipReferencePoint)
      local distance_to_trigger = Utils.vector2Length(trigger_x - tipper_x, trigger_z - tipper_z)
	  
	  g_currentMission.tipTriggerRangeThreshold = 2
	  
      -- if tipper is on trigger
      if distance_to_trigger <= g_currentMission.tipTriggerRangeThreshold then
		active_tipper = tipper
      end            
    end
    
  if active_tipper then    
	local trigger = self.currentTipTrigger
	-- if trigger accepts fruit
	if trigger.acceptedFruitTypes[active_tipper:getCurrentFruitType()] then
		allowedToDrive = false
	else
		allowedToDrive = true
	end
  else
    allowedToDrive = true
  end 
  
  return allowedToDrive, active_tipper
end

-- adds a visual waypoint to the map
function courseplay:addsign(self, x, y, z)  
    local height = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)
    local root = self.sign
    local sign = clone(root, true)
    setTranslation(sign, x, height + 1 + self.recordnumber, z)
    setVisibility(sign, true)
    table.insert(self.signs, sign)
	return(sign)
end

-- should the signs be visible?
function courseplay:sign_visibility(self, visibilty)
  for k,v in pairs(self.signs) do    
      setVisibility(v, visibilty)	
  end
end

-- triggers

-- traffic collision
function courseplay:onTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        if otherId == Player.rootNode then
            if onEnter then
                self.numCollidingVehicles = self.numCollidingVehicles+1;
            elseif onLeave then
                self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);
		
            end;
        else
            local vehicle = g_currentMission.nodeToVehicle[otherId];
            if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil then
                if onEnter then
                    self.numCollidingVehicles = self.numCollidingVehicles+1;
                elseif onLeave then
                    self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);
		
                end;
            end;
        end;
    end;
end;

-- tip trigger
function courseplay:findTipTriggerCallback(transformId, x, y, z, distance)  
  for k,trigger in pairs(g_currentMission.tipTriggers) do
	if trigger.triggerId == transformId then
		self.currentTipTrigger = trigger		
	end
  end
end

-- saving // loading coures


function courseplay:select_course(self)
  if self.course_selection_active then
	self.course_selection_active = false
  else
	self.course_selection_active = true
  end
end

-- saves coures to xml-file
function courseplay:save_courses(self)
  local path = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex .. "/"
  local File = io.open(path .. "courseplay.xml", "w")
  local tab = "   "
  if File ~= nil then
    File:write("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\" ?>\n<XML>\n<courses>\n")
    for name,x in pairs(self.courses) do
      File:write(tab .. "<course name=\"" .. name .. "\">\n")
      for i = 1, table.getn(x) do
        local v = x[i]
        File:write(tab .. tab .. "<waypoint" .. i .. " pos=\"" .. v.cx .. " " .. v.cz .. "\" angle=\"" .. v.angle .. "\" />\n")
      end
      File:write(tab .. "</course>\n")
    end
    File:write("</courses>\n")
    
    File:write("\n</XML>\n")
    File:close()
  end
end


function courseplay:load_courses(self)
	local finish_all = false
	self.courses = {}
	local path = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex .. "/"
	local File = io.open(path .. "courseplay.xml", "a")
	File:close()
	File = loadXMLFile("courseFile", path .. "courseplay.xml")
	local i = 0
	repeat
		
		local baseName = string.format("XML.courses.course(%d)", i)
		local name = getXMLString(File, baseName .. "#name")
		if name == nil then
			finish_all = true
			break
		end
		local tempCourse = {}
	  
		local s = 1
		
		local finish_wp = false
		repeat
		  local key = baseName .. ".waypoint" .. s
		  local x, z = Utils.getVectorFromString(getXMLString(File, key .. "#pos"))
		  if x ~= nil then
			if z == nil then
			  finish_wp = true
			  break
			end
			local dangle = Utils.getVectorFromString(getXMLString(File, key .. "#angle"))				
			tempCourse[s] = {cx = x, cz = z, angle = dangle}
			s = s + 1
		  else
			self.courses[name] = tempCourse
			i = i + 1
			finish_wp = true
			break
		  end
		until finish_wp == true
	until finish_all == true
end


-- debugging data dumper
-- just for development and debugging
function table.show(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return string.format("%q", so .. ", C function")
         else 
            -- the information is defined through lines
            return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
         end
      elseif type(o) == "number" then
         return so
      else
         return string.format("%q", so)
      end
   end

   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] 
                        .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end