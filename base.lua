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
	self.max_speed = 40 / 3600
	self.turn_speed = 10 / 3600
	self.field_speed = 24 / 3600
	
	self.orgRpm = nil
	
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
	self.chopper_offset = 0
	self.auto_mode = nil
	
	self.allow_following = false
	self.required_fill_level_for_follow = 50
	
	self.turn_factor = nil
	self.turn_radius = 17
	
	-- loading saved courses from xml
	courseplay:load_courses(self)
	
		-- HUD
	self.hudInfoBasePosX = 0.755; --  position Links/ rechts.
	self.hudInfoBaseWidth = 0.24; -- Breite  Je Größer die Zahl, desto größer wird das Bild in die Breite "gezogen".
	self.hudInfoBasePosY = 0.215; --position höhe
	self.hudInfoBaseHeight = 0.485; -- Höhe Je Größer die Zahl, desto größer wird das Bild in die Höhe "gezogen"
	self.infoPanelPath = Utils.getFilename("../aacourseplay/img/hud_bg.png", self.baseDirectory);
	self.hudInfoBaseOverlay = Overlay:new("hudInfoBaseOverlay", self.infoPanelPath, self.hudInfoBasePosX, self.hudInfoBasePosY, self.hudInfoBaseWidth, self.hudInfoBaseHeight);
	self.showHudInfoBase = 0;
	self.hudpage = {}
	-- Function in Signs
	courseplay:load_Hud(self)
	
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

			if self.ai_mode == 1 then
				g_currentMission:addHelpButtonText(g_i18n:getText("CourseMode1"), InputBinding.CourseAiMode);
			else
				g_currentMission:addHelpButtonText(g_i18n:getText("CourseMode2"), InputBinding.CourseAiMode);
			end

			if InputBinding.hasEvent(InputBinding.CourseAiMode) then
				if self.ai_mode == 1 then
					self.ai_mode = 2
				else
					self.ai_mode = 1
				end
			end

		
			if table.getn(self.Waypoints) == 0  then
				g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStart"), InputBinding.PointRecord);
				if InputBinding.hasEvent(InputBinding.PointRecord) then
					courseplay:start_record(self)
				end
			end
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStop"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then
				courseplay:stop_record(self)
			end


			g_currentMission:addHelpButtonText(g_i18n:getText("CourseWaitpointSet"), InputBinding.CourseWait);
			if InputBinding.hasEvent(InputBinding.CourseWait) then
				courseplay:set_waitpoint(self)
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
			if self.Waypoints[self.recordnumber].wait and self.wait then
   				g_currentMission:addHelpButtonText(g_i18n:getText("CourseWaitpointStart"), InputBinding.CourseWait);
   				if InputBinding.hasEvent(InputBinding.CourseWait) then
					self.wait = false
				end
			end

			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStop"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then
				courseplay:stop(self)
			end
			
			if not self.loaded then
			  g_currentMission:addHelpButtonText(g_i18n:getText("NoWaitforfill"), InputBinding.NoWaitforfill);
			end
			
			if InputBinding.hasEvent(InputBinding.NoWaitforfill) then
				self.loaded = true
   			end
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
	g_currentMission:addHelpButtonText(g_i18n:getText("HudControl"), InputBinding.HudControl);
		-- Hud Control
	if InputBinding.hasEvent(InputBinding.HudControl) then
		if self.showHudInfoBase	== 3 then
			self.showHudInfoBase = 0
		else
			self.showHudInfoBase = self.showHudInfoBase + 1
		end
	end

    	-- HUD
	if (self.showHudInfoBase > 0) and self.isEntered then
		self.hudInfoBaseOverlay:render();

		setTextBold(true)
			if self.showHudInfoBase == 1 then
				renderText(0.825, 0.625, 0.021, string.format("Tastenbelegung"));
				courseplay:HudPage(self);
			elseif self.showHudInfoBase == 2 then
		        renderText(0.825, 0.625, 0.021, string.format("Optionen"));
		        courseplay:HudPage(self);
		    elseif self.showHudInfoBase == 3 then
		      	renderText(0.825, 0.625, 0.021, string.format("Einstellungen"));
				courseplay:HudPage(self);
			end
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