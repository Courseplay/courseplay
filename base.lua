local cp_directory = g_currentModDirectory

function courseplay.prerequisitesPresent(specializations)
	return true;
end

function courseplay:load(xmlFile)
	-- global array for courses, no refreshing needed any more
	--if courseplay_courses == nil and g_server ~= nil then
	--  courseplay_courses = courseplay:load_courses()
	--elseif not courseplay_courses then
	--  courseplay_courses = {}
	--end

	self.setCourseplayFunc = SpecializationUtil.callSpecializationsFunction("setCourseplayFunc");

	local aNameSearch = { "vehicle.name." .. g_languageShort, "vehicle.name.en", "vehicle.name", "vehicle#type" };

	if not steerable_overwritten then
		steerable_overwritten = true
		if Steerable.load ~= nil then
			local orgSteerableLoad = Steerable.load
			courseplay:debug("overwriting steerable.load", 1)
			Steerable.load = function(self, xmlFile)
				orgSteerableLoad(self, xmlFile)

				for nIndex, sXMLPath in pairs(aNameSearch) do
					self.name = getXMLString(xmlFile, sXMLPath);
					if self.name ~= nil then break; end;
				end;
				if self.name == nil then self.name = g_i18n:getText("UNKNOWN") end;
			end;
		end;

		if Attachable.load ~= nil then
			courseplay:debug("overwriting Attachable.load", 1)
			local orgAttachableLoad = Attachable.load

			Attachable.load = function(self, xmlFile)
				orgAttachableLoad(self, xmlFile)

				for nIndex, sXMLPath in pairs(aNameSearch) do
					self.name = getXMLString(xmlFile, sXMLPath);
					if self.name ~= nil then break; end;
				end;
				if self.name == nil then self.name = g_i18n:getText("UNKNOWN") end;
			end
		end;
	end

	if self.name == nil then
		for nIndex, sXMLPath in pairs(aNameSearch) do
			self.name = getXMLString(xmlFile, sXMLPath);
			if self.name ~= nil then break; end;
		end;
		if self.name == nil then self.name = g_i18n:getText("UNKNOWN") end;
	end

	self.cp = {};
	self.toggledTipState = 0;
	
	self.auto_combine_offset = true
	self.mouse_right_key_enabled = true
	self.drive = false
	self.runOnceStartCourse = false;
	self.StopEnd = false
	self.lastGui = nil
	self.currentGui = nil
	self.input_gui = "emptyGui";
	self.calculated_course = false

	self.recordnumber = 1
	self.tmr = 1
	self.startlastload = 1
	self.timeout = 1
	self.timer = 0.00
	self.drive_slow_timer = 0
	self.courseplay_position = nil
	self.waitPoints = 0
	self.waitTime = 0
	self.crossPoints = 0
	self.waypointMode = 1
	self.RulMode = 1
	self.workWidthChanged = 0
	-- saves the shortest distance to the next waypoint (for recocnizing circling)
	self.shortest_dist = nil
	self.use_speed = true

	-- clickable buttons
	self.buttons = {}

	-- waypoints are stored in here
	self.Waypoints = {}

	-- TODO still needed?
	self.play = false
	-- total number of course players
	self.working_course_player_num = nil

	-- info text on tractor
	self.info_text = nil

	-- global info text - also displayed when not in vehicle
	self.global_info_text = nil
	self.testhe = false

	-- ai mode: 1 abfahrer, 2 kombiniert
	self.ai_mode = 1
	self.follow_mode = 1
	self.ai_state = 0
	self.next_ai_state = nil
	self.startWork = nil
	self.stopWork = nil
	self.abortWork = nil
	self.wait = true
	self.waitTimer = nil
	self.realistic_driving = true

	self.cp_directory = cp_directory

	-- our arrow is displaying dirction to waypoints
	self.ArrowPath = Utils.getFilename("img/arrow.dds", self.cp_directory);
	self.ArrowOverlay = Overlay:new("Arrow", self.ArrowPath, 0.4, 0.08, 0.250, 0.250);
	--self.ArrowOverlay:render()

	-- kegel der route	
	local baseDirectory = getAppBasePath()
	local i3dNode = Utils.loadSharedI3DFile("data/maps/models/objects/egg/egg.i3d", baseDirectory)
	local itemNode = getChildAt(i3dNode, 0)
	link(getRootNode(), itemNode)
	setRigidBodyType(itemNode, "NoRigidBody")
	setTranslation(itemNode, 0, 0, 0)
	setVisibility(itemNode, false)
	delete(i3dNode)
	self.sign = itemNode

	local i3dNode2 = Utils.loadSharedI3DFile("img/NurGerade/NurGerade.i3d", self.cp_directory)
	local itemNode2 = getChildAt(i3dNode2, 0)
	link(getRootNode(), itemNode2)
	setRigidBodyType(itemNode2, "NoRigidBody")
	setTranslation(itemNode2, 0, 0, 0)
	setVisibility(itemNode2, false)
	delete(i3dNode2)
	self.start_sign = itemNode2

	local i3dNode3 = Utils.loadSharedI3DFile("img/STOP/STOP.i3d", self.cp_directory)
	local itemNode3 = getChildAt(i3dNode3, 0)
	link(getRootNode(), itemNode3)
	setRigidBodyType(itemNode3, "NoRigidBody")
	setTranslation(itemNode3, 0, 0, 0)
	setVisibility(itemNode3, false)
	delete(i3dNode3)
	self.stop_sign = itemNode3

	local i3dNode4 = Utils.loadSharedI3DFile("img/VorfahrtAnDieserKreuzung/VorfahrtAnDieserKreuzung.i3d", self.cp_directory)
	local itemNode4 = getChildAt(i3dNode4, 0)
	link(getRootNode(), itemNode4)
	setRigidBodyType(itemNode4, "NoRigidBody")
	setTranslation(itemNode4, 0, 0, 0)
	setVisibility(itemNode4, false)
	delete(i3dNode4)
	self.cross_sign = itemNode4

	local i3dNode5 = Utils.loadSharedI3DFile("img/Parkplatz/Parkplatz.i3d", self.cp_directory)
	local itemNode5 = getChildAt(i3dNode5, 0)
	link(getRootNode(), itemNode5)
	setRigidBodyType(itemNode5, "NoRigidBody")
	setTranslation(itemNode5, 0, 0, 0)
	setVisibility(itemNode5, false)
	delete(i3dNode5)
	self.wait_sign = itemNode5

	-- visual waypoints saved in this
	self.signs = {}
	courseplay:RefreshGlobalSigns(self) -- Global Signs Crosspoints

	self.workMarkerLeft = clone(self.sign, true)
	setVisibility(self.workMarkerLeft, false)
	self.workMarkerRight = clone(self.sign, true)
	setVisibility(self.workMarkerRight, false)

	-- course name for saving
	self.current_course_name = nil
	self.courseID = 0
	-- array for multiple courses
	self.loaded_courses = {}
	self.direction = false
	-- forced waypoints	
	self.target_x = nil
	self.target_y = nil
	self.target_z = nil

	self.next_targets = {}

	-- speed limits
	self.max_speed_level = nil
	self.max_speed =    50 / 3600 -- >5
	self.turn_speed =   10 / 3600 -- >5
	self.field_speed =  24 / 3600 -- >5
	self.unload_speed =  6 / 3600 -- >3
	self.sl = 3
	self.tools_dirty = false

	self.orgRpm = nil;
	
	-- Course list
	self.courseListPrev = false;
	self.courseListNext = table.getn(g_currentMission.courseplay_courses) > 5;



	-- traffic collision	
	self.onTrafficCollisionTrigger = courseplay.cponTrafficCollisionTrigger;
	--self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	self.steering_angle = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.wheels.wheel(1)" .. "#rotMax"), 30)

	self.CPnumCollidingVehicles = 0;
	--	self.numToolsCollidingVehicles = {};
	--	self.trafficCollisionIgnoreList = {};
	self.cpTrafficCollisionIgnoreList = {};
	--	for k,v in pairs(self.components) do
	--	  self.trafficCollisionIgnoreList[v.node] = true;
	--	end;
	self.cpTrafficBrake = false
	-- tipTrigger
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;


	-- tippers
	self.tippers = {}
	self.tipper_attached = false
	self.currentTrailerToFill = nil
	self.lastTrailerToFillDistance = nil
	self.unloaded = false
	self.loaded = false
	self.unloading_tipper = nil
	self.last_fill_level = nil
	self.tipRefOffset = 0;
	self.cp.tipperHasCover = false;
	self.cp.tippersWithCovers = {};

	-- for user input like saving
	self.user_input_active = false
	self.user_input_message = nil
	self.user_input = nil
	self.save_name = false


	self.selected_course_number = 0
	self.course_Del = false

	-- combines	
	self.reachable_combines = {}
	self.active_combine = nil

	self.combine_offset = 0.0
	self.tipper_offset = 0.0

	self.forced_side = nil
	self.forced_to_stop = false

	self.allow_following = false
	self.required_fill_level_for_follow = 50
	self.required_fill_level_for_drive_on = 90

	self.turn_factor = nil
	self.turn_radius = 10;
	self.autoTurnRadius = 10;
	self.turnRadiusAutoMode = true;

	self.WpOffsetX = 0
	self.WpOffsetZ = 0
	self.toolWorkWidht = 3
	self.createCourse = false
	-- loading saved courses from xml

	self.search_combine = true
	self.saved_combine = nil
	self.selected_combine_number = 0

	self.mouse_enabled = false

	-- HUD  	-- Function in Signs
	self.hudInfoBaseWidth = 0.512; --try: 512/1920
	self.hudInfoBaseHeight = 0.512; --try: 512/1080

	self.infoPanelPath = Utils.getFilename("img/hud_bg.dds", self.cp_directory);
	self.hudInfoBaseOverlay = Overlay:new("hudInfoBaseOverlay", self.infoPanelPath, courseplay.hud.infoBasePosX - 10/1920, courseplay.hud.infoBasePosY - 10/1920, courseplay.hud.infoBaseWidth, courseplay.hud.infoBaseHeight);

	self.min_hud_page = 1
	if courseplay:is_a_combine(self) then
		self.min_hud_page = 0
	end

	self.showHudInfoBase = self.min_hud_page;

	self.hudpage = {}
	self.hudpage[0] = {}
	self.hudpage[0][1] = {}
	self.hudpage[0][2] = {}
	self.hudpage[0][3] = {}
	self.hudpage[0][4] = {}
	self.hudpage[1] = {}
	self.hudpage[1][1] = {}
	self.hudpage[1][2] = {}
	self.hudpage[2] = {}
	self.hudpage[2][1] = {}
	self.hudpage[2][2] = {}
	self.hudpage[3] = {}
	self.hudpage[3][1] = {}
	self.hudpage[3][2] = {}
	self.hudpage[4] = {}
	self.hudpage[4][1] = {}
	self.hudpage[4][2] = {}
	self.hudpage[5] = {}
	self.hudpage[5][1] = {}
	self.hudpage[5][2] = {}
	self.hudpage[6] = {}
	self.hudpage[6][1] = {}
	self.hudpage[6][2] = {}

	self.hudpage[7] = {}
	self.hudpage[7][1] = {}
	self.hudpage[7][2] = {}
	
	local w16px = 16/1920;
	local h16px = 16/1080;
	local w24px = 24/1920;
	local h24px = 24/1080;

	self.hudinfo = {}

	self.show_hud = false

	-- buttons for hud
	courseplay:register_button(self, nil, "navigate_left.dds", "switch_hud_page", -1, courseplay.hud.infoBasePosX + 0.035, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px); --ORIG: +0.242
	courseplay:register_button(self, nil, "navigate_right.dds", "switch_hud_page", 1, courseplay.hud.infoBasePosX + 0.280, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px);


	courseplay:register_button(self, nil, "close.dds", "close_hud", 1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.infoBasePosY + 0.255, w24px, h24px);

	courseplay:register_button(self, nil, "disk.dds", "save_course", 1, courseplay.hud.infoBasePosX + 0.280, courseplay.hud.infoBasePosY + 0.056, w24px, h24px);

	--Page 0
	courseplay:register_button(self, 0, "blank.dds", "row1", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[1], 0.32, 0.015);
	courseplay:register_button(self, 0, "blank.dds", "row2", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[2], 0.32, 0.015);
	courseplay:register_button(self, 0, "blank.dds", "row3", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[3], 0.32, 0.015);
	courseplay:register_button(self, 0, "blank.dds", "row4", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[4], 0.32, 0.015);

	--Page 1
	courseplay:register_button(self, 1, "blank.dds", "row1", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[1], 0.32, 0.015);
	courseplay:register_button(self, 1, "blank.dds", "row2", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[2], 0.32, 0.015);
	courseplay:register_button(self, 1, "blank.dds", "row3", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[3], 0.32, 0.015);
	courseplay:register_button(self, 1, "blank.dds", "row4", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[4], 0.32, 0.015);
	courseplay:register_button(self, 1, "blank.dds", "row5", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[5], 0.32, 0.015);
	courseplay:register_button(self, 1, "blank.dds", "change_DriveDirection", 1, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[5], 0.32, 0.015);

	--Page 2
	courseplay:register_button(self, 2, "blank.dds", "row1", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[1], 0.32, 0.015);
	courseplay:register_button(self, 2, "blank.dds", "row2", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[2], 0.32, 0.015);
	courseplay:register_button(self, 2, "blank.dds", "row3", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[3], 0.32, 0.015);

	courseplay:register_button(self, 2, "navigate_up.dds",   "change_selected_course", -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesPosY[1], w24px, h24px, nil, -10, "self.courseListPrev=true");
	courseplay:register_button(self, 2, "navigate_down.dds", "change_selected_course",  5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesPosY[5], w24px, h24px, nil,  10, "self.courseListNext=true");

	for i = 1, 5, 1 do
		local posy = courseplay.hud.infoBasePosY + 0.205 - (i - 1) * 0.021
		courseplay:register_button(self, -2, "folder.dds", "load_course", i, courseplay.hud.infoBasePosX + 0.212, courseplay.hud.linesButtonPosY[i], w16px, h16px, i);
		courseplay:register_button(self, -2, "folder_into.dds", "add_course", i, courseplay.hud.infoBasePosX + 0.235, courseplay.hud.linesButtonPosY[i], w16px, h16px, i);
		if g_server ~= nil then
			courseplay:register_button(self, -2, "delete.dds", "clear_course", i, courseplay.hud.infoBasePosX + 0.258, courseplay.hud.linesButtonPosY[i], w16px, h16px, i);
		end
	end

	--Page 3
	courseplay:register_button(self, 3, "navigate_minus.dds", "change_combine_offset", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil, -0.5);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_combine_offset",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,  0.5);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_tipper_offset", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil, -0.5);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_tipper_offset",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,  0.5);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_turn_radius", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil, -5);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_turn_radius",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,  5);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_required_fill_level", -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil, -10);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_required_fill_level",  5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil,  10);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_required_fill_level_for_drive_on", -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, nil, -10);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_required_fill_level_for_drive_on",  5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px, nil,  10);

	--Page 4
	courseplay:register_button(self, 4, "navigate_up.dds",   "switch_combine", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px);
	courseplay:register_button(self, 4, "navigate_down.dds", "switch_combine",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px);

	--courseplay:register_button(self, 4, "navigate_minus.dds", "change_num_ai_helpers", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px);
	--courseplay:register_button(self, 4, "navigate_plus.dds", "change_num_ai_helpers", 1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px);

	courseplay:register_button(self, 4, "blank.dds", "switch_search_combine", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[2], 0.32, 0.015);

	--Page 5
	courseplay:register_button(self, 5, "navigate_minus.dds", "change_turn_speed",   -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil, -5);
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_turn_speed",    1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,  5);

	courseplay:register_button(self, 5, "navigate_minus.dds", "change_field_speed",  -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil, -5);
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_field_speed",   1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,  5);

	courseplay:register_button(self, 5, "navigate_minus.dds", "change_max_speed",    -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil, -5, "self.use_speed=false");
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_max_speed",     1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,  5, "self.use_speed=false");
	
	courseplay:register_button(self, 5, "navigate_minus.dds", "change_unload_speed", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil, -5);
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_unload_speed",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil,  5);

	courseplay:register_button(self, 5, "blank.dds",          "change_use_speed",     1, courseplay.hud.infoBasePosX - 0.05,  courseplay.hud.linesPosY[5],       0.32,  0.015);
	
	--Page 6
	courseplay:register_button(self, 6, "blank.dds", "switch_realistic_driving", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[1], 0.32, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "mouse_right_key",          nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[2], 0.32, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "change_WaypointMode",      1,   courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[3], 0.32, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "change_RulMode",           1,   courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[4], 0.32, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "change_DebugLevel",        1,   courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[5], 0.32, 0.015);

	--Page 7: FAHR-Arbeitseinstellungen
	courseplay:register_button(self, 7, "navigate_minus.dds", "change_wait_time",  -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil, -10);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "change_wait_time",   5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,  10);

	courseplay:register_button(self, 7, "navigate_minus.dds", "changeWpOffsetX", -0.5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,  -1);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "changeWpOffsetX",  0.5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,   1);

	courseplay:register_button(self, 7, "navigate_minus.dds", "changeWpOffsetZ", -0.5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,  -1);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "changeWpOffsetZ",  0.5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,   1);

	courseplay:register_button(self, 7, "navigate_minus.dds", "changeWorkWidth", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil,  -0.5);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "changeWorkWidth",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil,   0.5);





	self.fold_move_direction = 1;

	register_courseplay();
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
	
	if self.drive and self.steeringEnabled then
	  self.steeringEnabled = false
	end
end

-- displays help text, user_input 	
function courseplay:draw()
	courseplay:loadHud(self)

	if self.dcheck and table.getn(self.Waypoints) > 1 then
		courseplay:dcheck(self);
	end

	if self.workWidthChanged > self.timer then
		courseplay:show_work_witdh(self)
	elseif self.work_with_shown then
		--setVisibility(self.workMarkerRight, false)
		--setVisibility(self.workMarkerLeft, false)
		self.work_with_shown = false
	end

	if self.mouse_enabled then
		InputBinding.setShowMouseCursor(self.mouse_enabled)
	end

	courseplay:showHud(self)
end

function courseplay:show_work_witdh(self)
	local x, y, z = getWorldTranslation(self.rootNode)
	local left =  self.toolWorkWidht *  0.5;
	local right = self.toolWorkWidht * -0.5;
	if self.WpOffsetX ~= nil and self.WpOffsetX ~= 0 then
		left =  left +  self.WpOffsetX;
		right = right + self.WpOffsetX;
	end;
	local pointLx, pointLy, pointLz = localToWorld(self.rootNode, left,  1, -6);
	local pointRx, pointRy, pointRz = localToWorld(self.rootNode, right, 1, -6);
	drawDebugPoint(pointLx, pointLy, pointLz, 1, 1, 0, 1);
	drawDebugPoint(pointRx, pointRy, pointRz, 1, 1, 0, 1);
	drawDebugLine(pointLx, pointLy, pointLz, 1, 0, 0, pointRx, pointRy, pointRz, 1, 0, 0);
	self.work_with_shown = true
end

-- is been called everey frame
function courseplay:update(dt)
	if self:getIsActive() then
		if InputBinding.isPressed(InputBinding.CP_Modifier_1) and not self.mouse_right_key_enabled then
			if self.show_hud then
				g_currentMission:addHelpButtonText(g_i18n:getText("CPHudClose"), InputBinding.CP_Hud)
			elseif not self.show_hud then
				g_currentMission:addHelpButtonText(g_i18n:getText("CPHudOpen"), InputBinding.CP_Hud)
			end
		end
		
		-- inspired by knagsted's 8400 MouseOverride
		if InputBinding.hasEvent(InputBinding.CP_Hud) and InputBinding.isPressed(InputBinding.CP_Modifier_1) and self.isEntered and not self.mouse_right_key_enabled then
			if self.mouse_enabled then
				self.mouse_enabled = false
				if self.show_hud then
					self.show_hud = false
				end
			else
				self.mouse_enabled = true
				if not self.show_hud then
					self.showHudInfoBase = self.min_hud_page
					self.show_hud = true
				end
			end
			InputBinding.setShowMouseCursor(self.mouse_enabled)
		end

		if InputBinding.hasEvent(InputBinding.CP_Hud) and InputBinding.isPressed(InputBinding.CP_Modifier_2) and self.isEntered then
			initialize_courseplay()
		end
	end

	if self.isEntered then

		if self.user_input_active == true then
			if self.currentGui == nil then
				g_gui:loadGui(Utils.getFilename("emptyGui.xml", self.cp_directory), self.input_gui);
				g_gui:showGui(self.input_gui);
				self.currentGui = self.input_gui
			end

			for unicode, isDown in pairs(Input.keyPressedState) do
				if isDown then
					self:setCourseplayFunc("key_input", unicode)
				end
			end
			Input.keyPressedState = {};
		else
			if self.currentGui == self.input_gui then
				g_gui:showGui("");
				self.currentGui = nil
			end
		end

		if self.user_input_message then
			courseplay:user_input(self);
		end
	end


	courseplay:infotext(self);


	-- we are in record mode
	if self.record then
		courseplay:record(self);
	end

	-- we are in drive mode
	if self.drive then
		courseplay:drive(self, dt);
	end
end

function courseplay:updateTick(dt)
	--attached or detached implement?
	if self.tools_dirty then
		courseplay:reset_tools(self)
	end

	-- show visual waypoints only when in vehicle
	if self.isEntered and self.waypointMode ~= 5 then
		courseplay:sign_visibility(self, true)
	else
		courseplay:sign_visibility(self, false);
	end

	self.timer = self.timer + dt
	--courseplay:debug(string.format("timer: %f", self.timer ), 2)
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
	if courseplay.locales[key] ~= nil then
		return courseplay.locales[key];
	else
		return key;
	end;
end


function courseplay:readStream(streamId, connection)
	courseplay:debug("reading stream", 4)


	self.abortWork = streamDebugReadInt32(streamId)
	self.ai_mode = streamDebugReadInt32(streamId)
	self.ai_state = streamDebugReadInt32(streamId)
	self.allow_following = streamDebugReadBool(streamId)
	self.autoTurnRadius = streamDebugReadFloat32(streamId)
	self.combine_offset = streamDebugReadFloat32(streamId)
	self.courseListPrev = streamDebugReadBool(streamId)
	self.courseListNext = streamDebugReadBool(streamId)
	self.courseplay_position = streamDebugReadInt32(streamId)
	self.CPnumCollidingVehicles = streamDebugReadInt32(streamId)
	self.cpTrafficBrake = streamDebugReadBool(streamId)
	self.cp.tipperHasCover = streamDebugReadBool(streamId);
	self.crossPoints = streamDebugReadInt32(streamId)
	self.drive = streamDebugReadBool(streamId)
	self.drive_slow_timer = streamDebugReadInt32(streamId)
	self.field_speed = streamDebugReadFloat32(streamId)
	self.fold_move_direction = streamDebugReadInt32(streamId)
	self.follow_mode = streamDebugReadInt32(streamId)
	self.forced_side = streamDebugReadString(streamId)
	self.forced_to_stop = streamDebugReadBool(streamId)
	self.global_info_text = streamDebugReadString(streamId)
	self.info_text = streamDebugReadString(streamId)
	self.last_fill_level = streamDebugReadInt32(streamId)
	self.lastTrailerToFillDistance = streamDebugReadFloat32(streamId)
	self.loaded = streamDebugReadBool(streamId)
	self.max_speed = streamDebugReadFloat32(streamId)
	self.mouse_enabled = streamDebugReadBool(streamId)
	self.mouse_right_key_enabled = streamDebugReadBool(streamId)
	self.next_ai_state = streamDebugReadInt32(streamId)
	self.play = streamDebugReadBool(streamId)
	self.recordnumber = streamDebugReadInt32(streamId)
	self.required_fill_level_for_drive_on = streamDebugReadFloat32(streamId)
	self.required_fill_level_for_follow = streamDebugReadFloat32(streamId)
	self.runOnceStartCourse = streamDebugReadBool(streamId)
	self.save_name = streamDebugReadBool(streamId)
	self.search_combine = streamDebugReadBool(streamId)
	self.selected_combine_number = streamDebugReadInt32(streamId)
	self.selected_course_number = streamDebugReadInt32(streamId)
	self.shortest_dist = streamDebugReadFloat32(streamId) -- 20.
	self.show_hud = streamDebugReadBool(streamId)
	self.showHudInfoBase = streamDebugReadInt32(streamId)
	self.sl = streamDebugReadInt32(streamId)
	self.startWork = streamDebugReadInt32(streamId)
	self.stopWork = streamDebugReadInt32(streamId)
	self.target_x = streamDebugReadFloat32(streamId)
	self.target_y = streamDebugReadFloat32(streamId)
	self.target_z = streamDebugReadFloat32(streamId)
	self.timeout = streamDebugReadInt32(streamId)
	self.timer = streamDebugReadFloat32(streamId)
	self.tipper_attached = streamDebugReadBool(streamId)
	self.tipper_offset = streamDebugReadFloat32(streamId)
	self.tipRefOffset = streamDebugReadFloat32(streamId)
	self.tmr = streamDebugReadInt32(streamId)
	self.turn_radius = streamDebugReadFloat32(streamId)
	self.turn_speed = streamDebugReadFloat32(streamId)
	self.turnRadiusAutoMode = streamDebugReadBool(streamId);
	self.unload_speed = streamDebugReadFloat32(streamId)
	self.unloaded = streamDebugReadBool(streamId) -- 40.
	self.use_speed = streamDebugReadBool(streamId)
	self.user_input = streamDebugReadString(streamId)
	self.user_input_active = streamDebugReadBool(streamId)
	self.user_input_message = streamDebugReadString(streamId)
	self.wait = streamDebugReadBool(streamId)
	self.waitPoints = streamDebugReadInt32(streamId)
	self.waitTime = streamDebugReadInt32(streamId)
	self.waitTimer = streamDebugReadInt32(streamId)
	self.working_course_player_num = streamDebugReadInt32(streamId)
	self.WpOffsetX = streamDebugReadFloat32(streamId)
	self.WpOffsetZ = streamDebugReadFloat32(streamId)

	local saved_combine_id = streamDebugReadInt32(streamId)
	if saved_combine_id then
		self.saved_combine = networkGetObject(saved_combine_id)
	end
	if self.drive then
		self.orgRpm = {}
		self.orgRpm[1] = self.motor.maxRpm[1]
		self.orgRpm[2] = self.motor.maxRpm[2]
		self.orgRpm[3] = self.motor.maxRpm[3]
	end
	local active_combine_id = streamDebugReadInt32(streamId)
	if active_combine_id then
		self.active_combine = networkGetObject(active_combine_id)
	end

	local current_trailer_id = streamDebugReadInt32(streamId)
	if current_trailer_id then
		self.currentTrailerToFill = networkGetObject(current_trailer_id)
	end

	local unloading_tipper_id = streamDebugReadInt32(streamId)
	if unloading_tipper_id then
		self.unloading_tipper = networkGetObject(unloading_tipper_id)
	end

	courseplay:reinit_courses(self)


	-- kurs daten
	local courses = streamDebugReadString(streamId) -- 60.



	if courses ~= nil then
		self.loaded_courses = courses:split(",")
		courseplay:reload_courses(self, true)
	end
end

function courseplay:writeStream(streamId, connection)
	courseplay:debug("writing stream", 4)

	streamDebugWriteInt32(streamId,self.abortWork)
	streamDebugWriteInt32(streamId,self.ai_mode)
	streamDebugWriteInt32(streamId,self.ai_state)
	streamDebugWriteBool(streamId, self.allow_following)
	streamDebugWriteFloat32(streamId,self.autoTurnRadius)
	streamDebugWriteFloat32(streamId,self.combine_offset)
	streamDebugWriteBool(streamId, self.courseListPrev)
	streamDebugWriteBool(streamId, self.courseListNext)
	streamDebugWriteInt32(streamId,self.courseplay_position)
	streamDebugWriteInt32(streamId,self.CPnumCollidingVehicles)
	streamDebugWriteBool(streamId, self.cpTrafficBrake)
	streamDebugWriteBool(streamId, self.cp.tipperHasCover);
	streamDebugWriteInt32(streamId, self.crossPoints);
	streamDebugWriteBool(streamId,self.drive)
	streamDebugWriteInt32(streamId,self.drive_slow_timer)
	streamDebugWriteFloat32(streamId,self.field_speed)
	streamDebugWriteInt32(streamId,self.fold_move_direction)
	streamDebugWriteInt32(streamId,self.follow_mode)
	streamDebugWriteString(streamId,self.forced_side)
	streamDebugWriteBool(streamId,self.forced_to_stop)
	streamDebugWriteString(streamId,self.global_info_text)
	streamDebugWriteString(streamId,self.info_text)
	streamDebugWriteInt32(streamId,self.last_fill_level)
	streamDebugWriteFloat32(streamId,self.lastTrailerToFillDistance)
	streamDebugWriteBool(streamId,self.loaded)
	streamDebugWriteFloat32(streamId,self.max_speed)
	streamDebugWriteBool(streamId,self.mouse_enabled)
	streamDebugWriteBool(streamId,self.mouse_right_key_enabled)
	streamDebugWriteInt32(streamId,self.next_ai_state)
	streamDebugWriteBool(streamId,self.play)
	streamDebugWriteInt32(streamId,self.recordnumber)
	streamDebugWriteFloat32(streamId,self.required_fill_level_for_drive_on)
	streamDebugWriteFloat32(streamId,self.required_fill_level_for_follow)
	streamDebugWriteBool(streamId, self.runOnceStartCourse)
	streamDebugWriteBool(streamId,self.save_name)
	streamDebugWriteBool(streamId,self.search_combine)
	streamDebugWriteInt32(streamId,self.selected_combine_number)
	streamDebugWriteInt32(streamId,self.selected_course_number)
	streamDebugWriteFloat32(streamId,self.shortest_dist)
	streamDebugWriteBool(streamId,self.show_hud)
	streamDebugWriteInt32(streamId,self.showHudInfoBase)
	streamDebugWriteInt32(streamId,self.sl)
	streamDebugWriteInt32(streamId,self.startWork)
	streamDebugWriteInt32(streamId,self.stopWork)
	streamDebugWriteFloat32(streamId,self.target_x)
	streamDebugWriteFloat32(streamId,self.target_y)
	streamDebugWriteFloat32(streamId,self.target_z)
	streamDebugWriteInt32(streamId,self.timeout)
	streamDebugWriteFloat32(streamId,self.timer)
	streamDebugWriteBool(streamId,self.tipper_attached)
	streamDebugWriteFloat32(streamId,self.tipper_offset)
	streamDebugWriteFloat32(streamId,self.tipRefOffset)
	streamDebugWriteInt32(streamId,self.tmr)
	streamDebugWriteFloat32(streamId,self.turn_radius)
	streamDebugWriteFloat32(streamId,self.turn_speed)
	streamDebugWriteBool(streamId,self.turnRadiusAutoMode)
	streamDebugWriteFloat32(streamId,self.unload_speed)
	streamDebugWriteBool(streamId,self.unloaded)
	streamDebugWriteBool(streamId,self.use_speed)
	streamDebugWriteString(streamId,self.user_input)
	streamDebugWriteBool(streamId,self.user_input_active)
	streamDebugWriteString(streamId,self.user_input_message)
	streamDebugWriteBool(streamId,self.wait)
	streamDebugWriteInt32(streamId,self.waitPoints)
	streamDebugWriteInt32(streamId,self.waitTime)
	streamDebugWriteInt32(streamId,self.waitTimer)
	streamDebugWriteInt32(streamId,self.working_course_player_num)
	streamDebugWriteFloat32(streamId,self.WpOffsetX)
	streamDebugWriteFloat32(streamId,self.WpOffsetZ)

	local saved_combine_id = nil
	if self.saved_combine ~= nil then
		saved_combine_id = networkGetObject(self.saved_combine)
	end
	streamDebugWriteInt32(streamId, saved_combine_id)

	local active_combine_id = nil
	if self.active_combine ~= nil then
		active_combine_id = networkGetObject(self.active_combine)
	end
	streamDebugWriteInt32(streamId, active_combine_id)

	local current_trailer_id = nil
	if self.currentTrailerToFill ~= nil then
		current_trailer_id = networkGetObject(self.currentTrailerToFill)
	end
	streamDebugWriteInt32(streamId, current_trailer_id)

	local unloading_tipper_id = nil
	if self.unloading_tipper ~= nil then
		unloading_tipper_id = networkGetObject(self.unloading_tipper)
	end
	streamDebugWriteInt32(streamId, unloading_tipper_id)

	local loaded_courses = nil
	if table.getn(self.loaded_courses) then
		loaded_courses = table.concat(self.loaded_courses, ",")
	end
	streamDebugWriteString(streamId, loaded_courses) -- 60.
end


function courseplay:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles and g_server ~= nil then
		self.max_speed = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#max_speed")), 50 / 3600);
		self.use_speed = Utils.getNoNil(getXMLBool(xmlFile, key .. string.format("#use_speed")), false);
		self.turn_speed = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#turn_speed")), 10 / 3600);
		self.field_speed = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#field_speed")), 24 / 3600);
		self.unload_speed = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#unload_speed")), 6 / 3600);
		self.realistic_driving = Utils.getNoNil(getXMLBool(xmlFile, key .. string.format("#realistic_driving")), true);    
		self.tipper_offset = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#tipper_offset")), 0);
		self.combine_offset = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#combine_offset")), 0);

		self.required_fill_level_for_follow = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#fill_follow")), 50);
		self.required_fill_level_for_drive_on = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#fill_drive")), 90);
		self.WpOffsetX = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#OffsetX")), 0);
		self.mouse_right_key_enabled = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#mouse_right_key_enabled")), true);
		self.WpOffsetZ = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#OffsetZ")), 0);
		self.waitTime = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#waitTime")), 0);
		self.abortWork = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#AbortWork")), nil);
		self.turn_radius = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#turn_radius")), 10);
		self.RulMode = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#rul_mode")), 1);
		local courses = Utils.getNoNil(getXMLString(xmlFile, key .. string.format("#courses")), "");
		self.toolWorkWidht = Utils.getNoNil(getXMLFloat(xmlFile, key .. string.format("#toolWorkWidht")), 3);
		self.loaded_courses = courses:split(",")
		self.selected_course_number = 0

		courseplay:reload_courses(self, true)

		self.ai_mode = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#ai_mode")), 1);

		if self.abortWork == 0 then
			self.abortWork = nil
		end
	end
	return BaseMission.VEHICLE_LOAD_OK;
end


function courseplay:getSaveAttributesAndNodes(nodeIdent)

	local attributes =
		' max_speed="' .. tostring(self.max_speed) .. '"' ..
		' use_speed="' .. tostring(self.use_speed) .. '"' ..
		' turn_speed="' .. tostring(self.turn_speed) .. '"' ..
		' field_speed="' .. tostring(self.field_speed) .. '"' ..
		' unload_speed="' .. tostring(self.unload_speed) .. '"' ..
		' tipper_offset="' .. tostring(self.tipper_offset) .. '"' ..
		' combine_offset="' .. tostring(self.combine_offset) .. '"' ..
		' fill_follow="' .. tostring(self.required_fill_level_for_follow) .. '"' ..
		' fill_drive="' .. tostring(self.required_fill_level_for_drive_on) .. '"' ..
		' OffsetX="' .. tostring(self.WpOffsetX) .. '"' ..
		' OffsetZ="' .. tostring(self.WpOffsetZ) .. '"' ..
		' AbortWork="' .. tostring(self.abortWork) .. '"' ..
		' turn_radius="' .. tostring(self.turn_radius) .. '"' ..
		' waitTime="' .. tostring(self.waitTime) .. '"' ..
		' courses="' .. tostring(table.concat(self.loaded_courses, ",")) .. '"' ..
		' mouse_right_key_enabled="' .. tostring(self.mouse_right_key_enabled) .. '"' ..
		' rul_mode="'..tostring(self.RulMode) .. '"' ..
		' toolWorkWidht="'..tostring(self.toolWorkWidht) .. '"' ..
		' realistic_driving="'..tostring(self.realistic_driving) .. '"' ..
		' ai_mode="' .. tostring(self.ai_mode) .. '"';
	return attributes, nil;
end


function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields + 1] = c end)
	return fields
end

function roundCustom(number, numDecimals)
	local positiveNegative = 1
	if number < 0 then positiveNegative = -1 end
	
	local mult = 10^(numDecimals or 0)
	--local mult = math.pow(10, numDecimals or 0)
	return math.floor(number*positiveNegative * mult + 0.5) / mult * positiveNegative
end

