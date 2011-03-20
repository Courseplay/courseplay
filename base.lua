function courseplay.prerequisitesPresent(specializations)
	return true;
end


function courseplay:load(xmlFile)
	self.recordnumber = 1
	self.tmr = 1
	self.timeout = 1
	self.timer = 0
	self.drive_slow_timer = 0
	self.courseplay_position = nil
	
	-- waypoints are stored in here
	self.Waypoints = {}
	-- loaded/saved courses saved in here
	self.courses = {}
	-- TODO still needed?
	self.play = false
	-- total number of course players
	self.working_course_player_num = nil
	
	-- info text on tractor
	self.info_text = nil
	
	-- global info text - also displayed when not in vehicle
	self.global_info_text = nil
	
	-- course modes: 1 circle route - 2 returning route
	self.course_mode = 1
	
	-- ai mode: 1 abfahrer, 2 kombiniert
	self.ai_mode = 1
	self.follow_mode = 1
	self.ai_state = 1
	self.next_ai_state = nil
	
	self.wait = true
	self.waitTimer = nil
	-- our arrow is displaying dirction to waypoints
	self.ArrowPath = Utils.getFilename("../aacourseplay/img/arrow.png", self.baseDirectory);
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
	
	-- forced waypoints	
	self.target_x = nil
	self.target_y = nil
	self.target_z = nil
	
	-- speed limits
	self.max_speed_level = nil
	self.max_speed = 50 / 3600
	self.turn_speed = 10 / 3600
	self.field_speed = 24 / 3600
	
	self.orgRpm = nil
	
	-- traffic collision	
	self.onTrafficCollisionTrigger = courseplay.onTrafficCollisionTrigger;
	self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	
	self.numCollidingVehicles = 0;
	self.numToolsCollidingVehicles = {};
	self.trafficCollisionIgnoreList = {};
	for k,v in pairs(self.components) do
	  self.trafficCollisionIgnoreList[v.node] = true;
	end;	
	
	-- tipTrigger
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	
	
	-- tippers
	self.tippers = {}
	self.tipper_attached = false	
	self.currentTrailerToFill = nil
	self.lastTrailerToFillDistance = nil
	self.unloaded = false	
	self.loaded  = false
	self.unloading_tipper = nil
	
	-- for user input like saving
	self.user_input_active = false
	self.user_input_message = nil
	self.user_input = nil
	self.save_name = false
	
	
	self.course_selection_active = false
	self.select_course = false
	self.selected_course_number = 0
	self.course_Del = false
	
	-- name search
	local aNameSearch = {"vehicle.name." .. g_languageShort, "vehicle.name.de", "vehicle.name.en", "vehicle.name", "vehicle#type"};
	
	for nIndex,sXMLPath in pairs(aNameSearch) do 
		self.name = getXMLString(xmlFile, sXMLPath);
		if self.name ~= nil then 
		break; 
		end;
	end;
	
	print("initialized courseplay for " .. self.name)
	
	-- combines
	
	self.reachable_combines = {}
	self.active_combine = nil
	self.combine_offset = 8
	self.chopper_offset = 8
	self.auto_mode = nil
	
	self.allow_following = false
	self.required_fill_level_for_follow = 50
	
	self.turn_factor = nil
	self.turn_radius = 17
	
	-- loading saved courses from xml
	courseplay:load_courses(self)
	
	self.mouse_enabled = false
	

	-- HUD  	-- Function in Signs
	self.hudInfoBasePosX = 0.755; 
	self.hudInfoBaseWidth = 0.24; 
	self.hudInfoBasePosY = 0.215; 
	self.hudInfoBaseHeight = 0.235; 
	
	self.infoPanelPath = Utils.getFilename("../aacourseplay/img/hud_bg.png", self.baseDirectory);
	self.hudInfoBaseOverlay = Overlay:new("hudInfoBaseOverlay", self.infoPanelPath, self.hudInfoBasePosX, self.hudInfoBasePosY, self.hudInfoBaseWidth, self.hudInfoBaseHeight);
	self.showHudInfoBase = 0;
	self.hudpage = {}
	self.hudpage[1]  = {}
    self.hudpage[1][1]  = {}
    self.hudpage[1][2]  = {}
    self.hudpage[2] = {}
    self.hudpage[2][1]  = {}
    self.hudpage[2][2]  = {}
	self.hudpage[3] = {}
    self.hudpage[3][1]  = {}
    self.hudpage[3][2]  = {}
    self.hudinfo = {}
end	

-- displays help text, user_input 	
function courseplay:draw()
	self.hudpage[1][1] = {}
    self.hudpage[1][2] = {}
	if self.showHudInfoBase <= 1 then
        if self.play then
			if not self.drive then
			    self.hudpage[1][1][4]= g_i18n:getText("CourseReset")
				self.hudpage[1][2][4]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput3)
				if InputBinding.hasEvent(InputBinding.AHInput3) then
					courseplay:reset_course(self)
				end
	            self.hudpage[1][1][1]= g_i18n:getText("CoursePlayStart")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:start(self)
				end

			else
				if self.Waypoints[self.recordnumber].wait and self.wait then
	   				self.hudpage[1][1][2]= g_i18n:getText("CourseWaitpointStart")
					self.hudpage[1][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
	   				if InputBinding.hasEvent(InputBinding.AHInput2) then
						self.wait = false
					end
				end

				self.hudpage[1][1][1]= g_i18n:getText("CoursePlayStop")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:stop(self)
				end

				if not self.loaded then
					self.hudpage[1][1][3]= g_i18n:getText("NoWaitforfill")
					self.hudpage[1][2][3]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput3)
				end

				if InputBinding.hasEvent(InputBinding.AHInput3) then
					self.loaded = true
	   			end
			end
		end
		if not self.drive  then
			if not self.record and (table.getn(self.Waypoints) == 0)  then
				self.hudpage[1][1][1]= g_i18n:getText("PointRecordStart")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:start_record(self)
				end
	
	            self.hudpage[1][1][2]= g_i18n:getText("CourseLoad")
				self.hudpage[1][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
	            if InputBinding.hasEvent(InputBinding.AHInput2) then
	   				 courseplay:select_course(self)
				end
	
					
			elseif not self.record and (table.getn(self.Waypoints) ~= 0) then	
			    self.hudpage[1][1][3]= g_i18n:getText("ModusSet")
	            self.hudpage[1][2][3]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)

				if InputBinding.hasEvent(InputBinding.AHInput2) then
					if self.ai_mode == 4 then
					   self.ai_mode = 1
					else
						self.ai_mode = self.ai_mode + 1
					end
				end
	
			else
				self.hudpage[1][1][1]= g_i18n:getText("PointRecordStop")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:stop_record(self)
				end
	
	            self.hudpage[1][1][2]= g_i18n:getText("CourseWaitpointSet")
				self.hudpage[1][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
				if InputBinding.hasEvent(InputBinding.AHInput2) then
					courseplay:set_waitpoint(self)
				end
			end
		end
	

	
	elseif self.showHudInfoBase == 2 then
		self.hudpage[2][1][2]= g_i18n:getText("CourseLoad")
		self.hudpage[2][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
	        if InputBinding.hasEvent(InputBinding.AHInput2) then
	   			 courseplay:select_course(self)
			end	
			
		self.hudpage[2][1][3]= g_i18n:getText("CourseDel")
		self.hudpage[2][2][3]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput3)
        if InputBinding.hasEvent(InputBinding.AHInput3) then
		 -- comming soon
   		end
   			
		if not self.record and (table.getn(self.Waypoints) ~= 0) then
			self.hudpage[2][1][1]= g_i18n:getText("CourseSave")
			self.hudpage[2][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
			
			if InputBinding.hasEvent(InputBinding.AHInput1) then
   				 courseplay:input_course_name(self)
   		 	end
   		end
	elseif self.showHudInfoBase == 3 then
		self.hudpage[3][1][1]= "Combine Offset:"
	    self.hudpage[3][1][2]= "Start bei%:"
		self.hudpage[3][1][3]= "Turn Radius:"
		
		if self.ai_state ~= nil then
			self.hudpage[3][2][1]= string.format("%d", self.combine_offset)
		else
			self.hudpage[3][2][1]= "---"
		end
		if self.required_fill_level_for_follow ~= nil then
			self.hudpage[3][2][2]= string.format("%d", self.required_fill_level_for_follow)
		else
			self.hudpage[3][2][2]= "---"
		end

		if self.turn_radius ~= nil then
			self.hudpage[3][2][3]= string.format("%d", self.turn_radius)
		else
			self.hudpage[3][2][3]= "---"
		end	


	end
	if self.dcheck and table.getn(self.Waypoints) > 1 then
		courseplay:dcheck(self);
	end


	if self.user_input_message then
		courseplay:user_input(self);
	end


	if self.course_selection_active then
		courseplay:display_course_selection(self);
	end
	
-- Hud Control
	g_currentMission:addHelpButtonText(g_i18n:getText("HudControl"), InputBinding.HudControl);
	g_currentMission:addHelpButtonText(g_i18n:getText("MouseControl"), InputBinding.MouseControl);
	
	if InputBinding.hasEvent(InputBinding.MouseControl) then
	  if self.mouse_enabled then
	    self.mouse_enabled = false
	  else
	    self.mouse_enabled = true
	  end
	end
	
	-- Hud Control
	if InputBinding.hasEvent(InputBinding.HudControl) then
		if self.showHudInfoBase	== 3 then  --edit for more sites
			self.showHudInfoBase = 0
		else
			self.showHudInfoBase = self.showHudInfoBase + 1
		end
	end

    	-- HUD
	if (self.showHudInfoBase > 0) and self.isEntered then
		self.hudInfoBaseOverlay:render();

    	if self.ai_mode == 1 then
			self.hudinfo[1]= g_i18n:getText("CourseMode1")
		elseif self.ai_mode == 2 then
		    self.hudinfo[1]= g_i18n:getText("CourseMode2")
        elseif self.ai_mode == 3 then
		    self.hudinfo[1]= g_i18n:getText("CourseMode3")
        elseif self.ai_mode == 4 then
		    self.hudinfo[1]= g_i18n:getText("CourseMode4")
        elseif self.ai_mode == 5 then
		    self.hudinfo[1]= g_i18n:getText("CourseMode5")
		else
		     self.hudinfo[1]= "---"
		end

    	if self.current_course_name ~= nil then
			self.hudinfo[2]= "Kurs: "..self.current_course_name
		else
			self.hudinfo[2]=  "Kurs: kein Kurs geladen"
		end
		
		if self.Waypoints[self.recordnumber ] ~= nil then
		    self.hudinfo[3]= "Wegpunkt: "..self.recordnumber .." / "..self.maxnumber
		else
			self.hudinfo[3]=  "Keine Wegpunkte geladen"
		end
		setTextBold(false)
		local i = 0
        for v,name in pairs(self.hudinfo) do
            local yspace = 0.292 - (i * 0.021)
        	renderText(0.763, yspace, 0.021, name);
            i = i + 1
		end


		setTextBold(true)
		if self.showHudInfoBase == 1 then
			renderText(0.825, 0.408, 0.021, string.format("Tastenbelegung"));
			courseplay:HudPage(self);
		elseif self.showHudInfoBase == 2 then
	        renderText(0.825, 0.408, 0.021, string.format("Kurs Optionen"));
	        courseplay:HudPage(self);
	    elseif self.showHudInfoBase == 3 then
	      	renderText(0.825, 0.408, 0.021, string.format("Einstellungen"));
			courseplay:HudPage(self);
		end
	end
	
	if self.mouse_enabled then
	  InputBinding.setShowMouseCursor(true)
	else
	  setShowMouseCursor(false);
	end
end

-- is been called everey frame
function courseplay:update(dt)
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
	
	--attached or detached implement?
	if self.aiToolsDirty then
	  courseplay:reset_tools(self)
	end
	
	-- we are in drive mode
	if self.drive then
		courseplay:drive(self, dt);
	end	
	
	courseplay:infotext(self);
	self.timer = self.timer + 1
end		

function courseplay:delete()
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end	
end;	

function courseplay:set_timeout(self, interval)
  self.timeout = self.timer + interval
end