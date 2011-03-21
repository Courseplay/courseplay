function courseplay.prerequisitesPresent(specializations)
	return true;
end

function courseplay:load(xmlFile)
	self.locales = {}
	
	self.locales.HudControl = g_i18n:getText("HudControl")
	self.locales.CourseReset = g_i18n:getText("CourseReset")
	self.locales.CoursePlayStart = g_i18n:getText("CoursePlayStart")
	self.locales.CourseWaitpointStart = g_i18n:getText("CourseWaitpointStart")
	self.locales.CoursePlayStop = g_i18n:getText("CoursePlayStop")
	self.locales.NoWaitforfill = g_i18n:getText("NoWaitforfill")
	self.locales.PointRecordStart = g_i18n:getText("PointRecordStart")
	self.locales.CourseLoad = g_i18n:getText("CourseLoad")
	self.locales.ModusSet = g_i18n:getText("ModusSet")
	self.locales.PointRecordStop = g_i18n:getText("PointRecordStop")
	self.locales.CourseWaitpointSet = g_i18n:getText("CourseWaitpointSet")
	self.locales.CourseDel = g_i18n:getText("CourseDel")
	self.locales.CourseSave = g_i18n:getText("CourseSave")
	self.locales.CourseMode1 = g_i18n:getText("CourseMode1")
	self.locales.CourseMode2 = g_i18n:getText("CourseMode2")
	self.locales.CourseMode3 = g_i18n:getText("CourseMode3")
	self.locales.CourseMode4 = g_i18n:getText("CourseMode4")
	self.locales.CourseMode5 = g_i18n:getText("CourseMode5")
	
	
	self.lastGui = nil
	self.currentGui = nil
	self.input_gui = "inputGui";
	 
	g_gui:loadGui(Utils.getFilename("../aacourseplay/emptyGui.xml", self.baseDirectory), self.input_gui);

	self.recordnumber = 1
	self.tmr = 1
	self.timeout = 1
	self.timer = 0
	self.drive_slow_timer = 0
	self.courseplay_position = nil
	
	-- clickable buttons
	self.buttons = {}
	
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
	self.showHudInfoBase = 1;
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
    
    self.show_hud = false
    
    -- buttons for hud    
    courseplay:register_button(self, nil, "navigate_left.png", "switch_hud_page", -1, 0.79, 0.410, 0.020, 0.020)
    courseplay:register_button(self, nil, "navigate_right.png", "switch_hud_page", 1, 0.96, 0.410, 0.020, 0.020)
    
    courseplay:register_button(self, nil, "delete.png", "close_hud", 1, 0.978, 0.418, 0.016, 0.016)
    
    courseplay:register_button(self, 1, "blank.png", "row1", nil, 0.75, 0.385, 0.32, 0.015)
    courseplay:register_button(self, 1, "blank.png", "row2", nil, 0.75, 0.363, 0.32, 0.015)
    courseplay:register_button(self, 1, "blank.png", "row3", nil, 0.75, 0.342, 0.32, 0.015)
    
    courseplay:register_button(self, 2, "blank.png", "row1", nil, 0.75, 0.385, 0.32, 0.015)
    courseplay:register_button(self, 2, "blank.png", "row2", nil, 0.75, 0.363, 0.32, 0.015)
    courseplay:register_button(self, 2, "blank.png", "row3", nil, 0.75, 0.342, 0.32, 0.015)
    
    courseplay:register_button(self, 3, "navigate_minus.png", "change_combine_offset", -0.1, 0.955, 0.388, 0.010, 0.010)
    courseplay:register_button(self, 3, "navigate_plus.png", "change_combine_offset", 0.1, 0.97, 0.388, 0.010, 0.010)
    
    courseplay:register_button(self, 3, "navigate_minus.png", "change_required_fill_level", -1, 0.955, 0.366, 0.010, 0.010)
    courseplay:register_button(self, 3, "navigate_plus.png", "change_required_fill_level", 1, 0.97, 0.366, 0.010, 0.010)
    
    courseplay:register_button(self, 3, "navigate_minus.png", "change_turn_radius", -1, 0.955, 0.345, 0.010, 0.010)
    courseplay:register_button(self, 3, "navigate_plus.png", "change_turn_radius", 1, 0.97, 0.345, 0.010, 0.010)
    
end	


function courseplay:onLeave()
  if self.mouse_enabled then
    InputBinding.setShowMouseCursor(false);
  end
end

function courseplay:onEnter()
  if self.mouse_enabled then
    InputBinding.setShowMouseCursor(true);
  end
end

-- displays help text, user_input 	
function courseplay:draw()
	courseplay:loadHud(self)
		
	if self.dcheck and table.getn(self.Waypoints) > 1 then
		courseplay:dcheck(self);
	end

	if self.course_selection_active then
		courseplay:display_course_selection(self);
	end
	
	-- Hud Control
	g_currentMission:addHelpButtonText(courseplay:get_locale(self, "HudControl"), InputBinding.HudControl);
	
	if InputBinding.hasEvent(InputBinding.HudControl) then
		if self.show_hud then
		  self.show_hud = false
		else
		  self.showHudInfoBase = 1
		  self.show_hud = true
		end
	end
	
	if self.mouse_enabled then 
	  InputBinding.setShowMouseCursor(self.mouse_enabled)
	end

    courseplay:showHud(self)
end

-- is been called everey frame
function courseplay:update(dt)

	if self.user_input_active then
	  if self.currentGui == nil then
	    g_gui:showGui(self.input_gui);
	    self.currentGui = self.input_gui
	  end
    else
      if self.currentGui == self.input_gui then
        g_gui:showGui("");
      end
    end
    
    if self.user_input_message then
      courseplay:user_input(self);
    end

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


function courseplay:get_locale(self, key)
  return self.locales[key]
end