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
	
	self.cp.isCombine = courseplay:isCombine(self);
	self.cp.isChopper = courseplay:isChopper(self);
	self.cp.isHarvesterSteerable = courseplay:isHarvesterSteerable(self);
	self.cp.isKasi = nil
	self.cp.isSugarBeetLoader = courseplay:isSpecialCombine(self, "sugarBeetLoader");
	if self.cp.isCombine then
		self.cp.mode7Unloading = false
	end	

	--turn maneuver
	self.cp.waitForTurnTime = 0.00   --float
	self.cp.turnStage = 0 --int
	self.cp.aiTurnNoBackward = false --bool
	self.cp.backMarkerOffset = nil --float
	self.cp.aiFrontMarker = nil --float
	self.cp.turnTimer = 8000 --int
	self.cp.noStopOnEdge = false --bool
	self.cp.noStopOnTurn = false --bool

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
	self.cp.buttons = {}

	self.Waypoints = {}

	self.play = false --can drive course (has >4 waypoints, is not recording)
	self.working_course_player_num = nil; -- total number of course players

	self.cp.infoText = nil -- info text on tractor

	-- global info text - also displayed when not in vehicle
	self.cp.globalInfoText = nil;
	self.cp.globalInfoTextLevel = 0;
	local git = courseplay.globalInfoText;
	self.cp.globalInfoTextOverlay = Overlay:new(string.format("globalInfoTextOverlay%d", self.rootNode), git.backgroundImg, git.backgroundX, 0, 0.1, git.fontSize);
	self.cp.globalInfoTextOverlay.isRendering = false;
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
	self.realistic_driving = true;
	self.cp.canSwitchMode = false;
	self.cp.startAtFirstPoint = false;
	
	self.cp.stopForLoading = false;

	self.cp.attachedCombineIdx = nil;

	-- ai mode 9: shovel
	self.cp.shovelEmptyPoint = nil;
	self.cp.shovelFillStartPoint = nil;
	self.cp.shovelFillEndPoint = nil;
	self.cp.shovelState = 1;
	self.cp.shovelStateRot = {};
	self.cp.shovel = {};
	self.cp.shovelStopAndGo = false;
	self.cp.shovelLastFillLevel = nil;

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

	self.cp.orgRpm = nil;
	
	-- Course list
	self.cp.courseListPrev = false;
	self.cp.courseListNext = table.getn(g_currentMission.courseplay_courses) > courseplay.hud.numLines;

	--Direction 
	local DirectionNode = nil;
	if self.aiTractorDirectionNode ~= nil then
		DirectionNode = self.aiTractorDirectionNode;
	elseif self.aiTreshingDirectionNode ~= nil then
		DirectionNode = self.aiTreshingDirectionNode;
	else
		if courseplay:isWheelloader(self)then
			DirectionNode = getParent(self.shovelTipReferenceNode)
			if self.wheels[1].rotMax ~= 0 then
				DirectionNode = self.rootNode;
			end
			if DirectionNode == nil then
				for i=1, table.getn(self.attacherJoints) do
					if self.rootNode ~= getParent(self.attacherJoints[i].jointTransform) then
						DirectionNode = getParent(self.attacherJoints[i].jointTransform)
						break
					end
				end
			end		
		end
		if DirectionNode == nil then
			DirectionNode = self.rootNode;
		end
		if getChild(self.rootNode, "trafficCollisionTrigger") ~= 0 then
			self.aiTractorDirectionNode = getChild(self.rootNode, "trafficCollisionTrigger");
		end;
	end;
	self.cp.DirectionNode = DirectionNode;

	-- traffic collision
	self.onTrafficCollisionTrigger = courseplay.cponTrafficCollisionTrigger;
	--self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	self.steering_angle = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.wheels.wheel(1)" .. "#rotMax"), 30)

	self.CPnumCollidingVehicles = 0;
	--	self.numToolsCollidingVehicles = {};
	--	self.trafficCollisionIgnoreList = {};
	self.cpTrafficCollisionIgnoreList = {};
	self.cpTrafficBrake = false
	-- tipTrigger
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	
	if self.numCollidingVehicles == nil then
		self.numCollidingVehicles = {};
	end
	if self.trafficCollisionIgnoreList == nil then
		self.trafficCollisionIgnoreList = {}
	end
	if self.aiTrafficCollisionTrigger == nil and getChild(self.rootNode, "trafficCollisionTrigger") ~= 0 then
		self.aiTrafficCollisionTrigger = getChild(self.rootNode, "trafficCollisionTrigger");
	end;
	
	courseplay:askForSpecialSettings(self,self)


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
	self.cp.tipperFillLevel = nil;
	self.cp.tipperCapacity = nil;

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

	self.cp.offset = nil --self = combine [flt]
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
	-- loading saved courses from xml

	self.search_combine = true
	self.saved_combine = nil
	self.selected_combine_number = 0
	
	--Copy course
	self.cp.hasFoundCopyDriver = false;
	self.cp.copyCourseFromDriver = nil;
	self.cp.selectedDriverNumber = 0;

	--Course generation
	self.cp.startingCorner = 0;
	self.cp.hasStartingCorner = false;
	self.cp.startingDirection = 0;
	self.cp.hasStartingDirection = false;
	self.cp.returnToFirstPoint = false;
	self.cp.hasGeneratedCourse = false;
	self.cp.hasValidCourseGenerationData = false;
	self.cp.ridgeMarkersAutomatic = true;
	self.cp.headland = {
		numLanes = 0;
	};
	
	self.mouse_enabled = false
	
	self.cp.ESLimiterOrigPosY = nil; --[table]
	self.cp.ThreshingCounterOrigPosY = nil; --[table]
	self.cp.OdometerOrigPosY = nil; --[table]
	self.cp.AllradOrigPosY = nil; --[table]
	-- HUD  	-- Function in Signs
	self.hudInfoBaseWidth = 0.512; --try: 512/1920
	self.hudInfoBaseHeight = 0.512; --try: 512/1080

	self.infoPanelPath = Utils.getFilename("img/hud_bg.dds", self.cp_directory);
	self.hudInfoBaseOverlay = Overlay:new("hudInfoBaseOverlay", self.infoPanelPath, courseplay.hud.infoBasePosX - 10/1920, courseplay.hud.infoBasePosY - 10/1920, courseplay.hud.infoBaseWidth, courseplay.hud.infoBaseHeight);

	self.showHudInfoBase = 1;
	courseplay:setMinHudPage(self, nil);

	self.hudpage = {}
	for a=0,courseplay.hud.numPages do
		self.hudpage[a] = {};
		for b=1,courseplay.hud.numLines do
			self.hudpage[a][b] = {};
		end;
	end;
	
	--HUD TITLES
	if courseplay.hud.hudTitles == nil then
		courseplay.hud.hudTitles = {
			courseplay:get_locale(self, "CPCombineMangament"), -- Combine Controls
			courseplay:get_locale(self, "CPSteering"), -- "Abfahrhelfer Steuerung"
			courseplay:get_locale(self, "CPManageCourses"), -- "Kurse verwalten"
			courseplay:get_locale(self, "CPCombiSettings"), -- "Einstellungen Combi Modus"
			courseplay:get_locale(self, "CPManageCombines"), -- "Drescher verwalten"
			courseplay:get_locale(self, "CPSpeedLimit"), -- "Speeds"
			courseplay:get_locale(self, "CPSettings"), -- "General settings"
			courseplay:get_locale(self, "CPHud7"), -- "Driving settings"
			courseplay:get_locale(self, "CPcourseGeneration"), -- "Course Generation"
			courseplay:get_locale(self, "CPShovelPositions") --Schaufel progammieren
		};
	end;


	local w16px = 16/1920;
	local h16px = 16/1080;
	local w24px = 24/1920;
	local h24px = 24/1080;
	local lineButtonWidth = 0.32;

	self.hudinfo = {}

	self.show_hud = false

	-- ## BUTTONS FOR HUD ##

	-- Page nav
	local pageNav = {
		buttonW = 32/1920;
		buttonH = 32/1080;
		paddingRight = 0.005;
		posY = courseplay.hud.infoBasePosY + 0.271;
	};
	pageNav.totalWidth = ((courseplay.hud.numPages + 1) * pageNav.buttonW) + (courseplay.hud.numPages * pageNav.paddingRight); --numPages=9, real numPages=10
	pageNav.baseX = courseplay.hud.infoBaseCenter - pageNav.totalWidth/2;
	for p=0, courseplay.hud.numPages do
		local posX = pageNav.baseX + (p * (pageNav.buttonW + pageNav.paddingRight));
		courseplay:register_button(self, nil, string.format("pageNav_%d.dds", p), "setHudPage", p, posX, pageNav.posY, pageNav.buttonW, pageNav.buttonH);
	end;

	courseplay:register_button(self, nil, "navigate_left.dds", "switch_hud_page", -1, courseplay.hud.infoBasePosX + 0.035, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px); --ORIG: +0.242
	courseplay:register_button(self, nil, "navigate_right.dds", "switch_hud_page", 1, courseplay.hud.infoBasePosX + 0.280, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px);

	courseplay:register_button(self, nil, "close.dds", "openCloseHud", false, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.infoBasePosY + 0.255, w24px, h24px);

	courseplay:register_button(self, nil, "disk.dds", "input_course_name", 1, courseplay.hud.infoBasePosX + 0.280, courseplay.hud.infoBasePosY + 0.056, w24px, h24px);

	for i=1, courseplay.hud.numLines do
		--Page 0: Combine controls
		courseplay:register_button(self, 0, "blank.dds", string.format("row%d", i), nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[i], lineButtonWidth, 0.015);
		
		--Page 1
		courseplay:register_button(self, 1, "blank.dds", string.format("row%d", i), nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[i], lineButtonWidth-0.08, 0.015);
	end;
	courseplay:register_button(self, 1, "blank.dds", "change_DriveDirection", 1, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[5], lineButtonWidth, 0.015, nil, nil, "self.record=true");


	--Page 1: ai_mode quickSwitch
	for i=1, courseplay.numAiModes do
		local icon = string.format("quickSwitch_mode%d.dds", i);
		local w = w16px * 2;
		local h = h16px * 2;
		--3 columns, 3 rows
		local numColumns = 3;

		local l = math.ceil(i/numColumns);
		local col = i;
		while col > numColumns do
			col = col - numColumns;
		end;
		
		local posX = courseplay.hud.infoBasePosX + 0.25 + (w * (col-1));
		local posY = courseplay.hud.linesPosY[1] + (20/1080) - (h*l);
		
		courseplay:register_button(self, 1, icon, "setAiMode", i, posX, posY, w, h, nil, nil, "self.cp.canSwitchMode=true");
	end;
	
	--Page 2: Course management
	courseplay:register_button(self, 2, "navigate_up.dds",   "change_selected_course", -courseplay.hud.numLines, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesPosY[1] - 0.003,                       w24px, h24px, nil, -courseplay.hud.numLines*2, "self.cp.courseListPrev=true");
	courseplay:register_button(self, 2, "navigate_down.dds", "change_selected_course",  courseplay.hud.numLines, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesPosY[courseplay.hud.numLines] - 0.003, w24px, h24px, nil,  courseplay.hud.numLines*2, "self.cp.courseListNext=true");

	for i=1, courseplay.hud.numLines do
		courseplay:register_button(self, -2, "folder.dds",      "load_course", i, courseplay.hud.infoBasePosX + 0.212, courseplay.hud.linesButtonPosY[i], w16px, h16px, i);
		courseplay:register_button(self, -2, "folder_into.dds", "add_course",  i, courseplay.hud.infoBasePosX + 0.235, courseplay.hud.linesButtonPosY[i], w16px, h16px, i);
		if g_server ~= nil then
			courseplay:register_button(self, -2, "delete.dds", "clear_course", i, courseplay.hud.infoBasePosX + 0.258, courseplay.hud.linesButtonPosY[i], w16px, h16px, i);
		end
	end

	--Page 3
	courseplay:register_button(self, 3, "navigate_minus.dds", "change_combine_offset", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil, -0.5);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_combine_offset",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,  0.5);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_tipper_offset", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil, -0.5);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_tipper_offset",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,  0.5);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_turn_radius", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil, -5, "self.turn_radius>0");
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_turn_radius",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,  5);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_required_fill_level", -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil, -10, "self.required_fill_level_for_follow>0");
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_required_fill_level",  5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil,  10, "self.required_fill_level_for_follow<100");

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_required_fill_level_for_drive_on", -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, nil, -10, "self.required_fill_level_for_drive_on>0");
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_required_fill_level_for_drive_on",  5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px, nil,  10, "self.required_fill_level_for_drive_on<100");

	--Page 4: Combine management
	courseplay:register_button(self, 4, "navigate_up.dds",   "switch_combine", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil, nil, "self.selected_combine_number>0");
	courseplay:register_button(self, 4, "navigate_down.dds", "switch_combine",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px);

	courseplay:register_button(self, 4, "blank.dds", "switch_search_combine", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[2], lineButtonWidth, 0.015);

	--Page 5: Speeds
	courseplay:register_button(self, 5, "navigate_minus.dds", "change_turn_speed",   -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil, -5, "self.turn_speed>5/3600");
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_turn_speed",    1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,  5);

	courseplay:register_button(self, 5, "navigate_minus.dds", "change_field_speed",  -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil, -5, "self.field_speed>5/3600");
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_field_speed",   1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,  5);

	courseplay:register_button(self, 5, "navigate_minus.dds", "change_max_speed",    -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil, -5, "self.use_speed=false");
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_max_speed",     1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,  5, "self.use_speed=false");
	
	courseplay:register_button(self, 5, "navigate_minus.dds", "change_unload_speed", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil, -5, "self.unload_speed>3/3600");
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_unload_speed",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px, nil,  5);

	courseplay:register_button(self, 5, "blank.dds",          "change_use_speed",     1, courseplay.hud.infoBasePosX - 0.05,  courseplay.hud.linesPosY[5],       lineButtonWidth,  0.015);
	
	--Page 6: General settings
	courseplay:register_button(self, 6, "blank.dds", "switch_realistic_driving",       nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[1], lineButtonWidth, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "switch_mouse_right_key_enabled", nil, courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[2], lineButtonWidth, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "change_WaypointMode",            1,   courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[3], lineButtonWidth, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "change_RulMode",                 1,   courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[4], lineButtonWidth, 0.015);
	courseplay:register_button(self, 6, "blank.dds", "change_DebugLevel",              1,   courseplay.hud.infoBasePosX - 0.05, courseplay.hud.linesPosY[5], lineButtonWidth, 0.015);

	--Page 7: Driving settings
	courseplay:register_button(self, 7, "navigate_minus.dds", "change_wait_time",  -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil, -10, "self.waitTime>0");
	courseplay:register_button(self, 7, "navigate_plus.dds",  "change_wait_time",   5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,  10);

	courseplay:register_button(self, 7, "navigate_minus.dds", "changeWpOffsetX", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,  -0.5);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "changeWpOffsetX",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, nil,   0.5);

	courseplay:register_button(self, 7, "navigate_minus.dds", "changeWpOffsetZ", -0.5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,  -1);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "changeWpOffsetZ",  0.5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, nil,   1);

	courseplay:register_button(self, 7, "navigate_up.dds",   "switchDriverCopy", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, nil, nil, "self.cp.selectedDriverNumber>0");
	courseplay:register_button(self, 7, "navigate_down.dds", "switchDriverCopy",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px);
	courseplay:register_button(self, 7, "copy3.dds",         "copyCourse",      nil, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[6], w16px, h16px, nil, nil, "self.cp.hasFoundCopyDriver=true");

	--Page 8: Course generation
	courseplay:register_button(self, 8, "navigate_minus.dds", "changeWorkWidth", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,  -0.5, "self.toolWorkWidht>0.1");
	courseplay:register_button(self, 8, "navigate_plus.dds",  "changeWorkWidth",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, nil,   0.5);

	courseplay:register_button(self, 8, "blank.dds", "switchStartingCorner",     nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], lineButtonWidth, 0.015, nil, nil);
	courseplay:register_button(self, 8, "blank.dds", "switchStartingDirection",  nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[3], lineButtonWidth, 0.015, nil, nil, "self.cp.hasStartingCorner=true");
	courseplay:register_button(self, 8, "blank.dds", "switchReturnToFirstPoint", nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[4], lineButtonWidth, 0.015, nil, nil);
	
	courseplay:register_button(self, 8, "navigate_up.dds",   "setHeadlandLanes",   1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, nil, nil, "self.cp.headland.numLanes<1");
	courseplay:register_button(self, 8, "navigate_down.dds", "setHeadlandLanes",  -1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px, nil, nil, "self.cp.headland.numLanes>-1");
	
	courseplay:register_button(self, 8, "blank.dds", "generateCourse",           nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[6], lineButtonWidth, 0.015, nil, nil, "self.cp.hasValidCourseGenerationData=true");
	
	--Page 9: Shovel settings
	local wTemp = 22/1920;
	local hTemp = 22/1080;
	courseplay:register_button(self, 9, "shovelLoading.dds",      "saveShovelStatus", 2, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[1] - 0.003, wTemp, hTemp, nil, 2);
	courseplay:register_button(self, 9, "shovelTransport.dds",    "saveShovelStatus", 3, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[2] - 0.003, wTemp, hTemp, nil, 3);
	courseplay:register_button(self, 9, "shovelPreUnloading.dds", "saveShovelStatus", 4, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[3] - 0.003, wTemp, hTemp, nil, 4);
	courseplay:register_button(self, 9, "shovelUnloading.dds",    "saveShovelStatus", 5, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[4] - 0.003, wTemp, hTemp, nil, 5);

	courseplay:register_button(self, 9, "blank.dds", "setShovelStopAndGo",   nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], lineButtonWidth, 0.015, nil, nil);
	--END Page 9


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
			courseplay:openCloseHud(self, not self.show_hud);
		end;

		if InputBinding.hasEvent(InputBinding.CP_Hud) and InputBinding.isPressed(InputBinding.CP_Modifier_2) and self.isEntered then
			initialize_courseplay();
		end;
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

	-- we are in record mode
	if self.record then
		courseplay:record(self);
	end

	-- we are in drive mode
	if self.drive then
		courseplay:drive(self, dt);
	end

	courseplay:renderInfoText(self);
	courseplay:setGlobalInfoText(self, nil, nil);
end;

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
	self.cp.attachedCombineIdx = streamDebugReadInt32(streamId)
	self.cp.canSwitchMode = streamDebugReadBool(streamId)
	self.cp.courseListPrev = streamDebugReadBool(streamId)
	self.cp.courseListNext = streamDebugReadBool(streamId)
	self.courseplay_position = streamDebugReadInt32(streamId)
	self.CPnumCollidingVehicles = streamDebugReadInt32(streamId)
	self.cpTrafficBrake = streamDebugReadBool(streamId)
	self.cp.globalInfoTextOverlay.isRendering = streamDebugReadBool(streamId);
	self.cp.hasFoundCopyDriver = streamDebugReadBool(streamId);
	self.cp.hasStartingCorner = streamDebugReadBool(streamId);
	self.cp.hasStartingDirection = streamDebugReadBool(streamId);
	self.cp.hasGeneratedCourse = streamDebugReadBool(streamId);
	self.cp.hasValidCourseGenerationData = streamDebugReadBool(streamId);
	self.cp.isCombine = streamDebugReadBool(streamId);
	self.cp.isChopper = streamDebugReadBool(streamId);
	self.cp.isHarvesterSteerable = streamDebugReadBool(streamId);
	self.cp.isKasi = streamDebugReadFloat32(streamId)
	self.cp.isSugarBeetLoader = streamDebugReadBool(streamId);
	self.cp.minHudPage = streamDebugReadInt32(streamId);
	self.cp.mode7Unloading = streamDebugReadBool(streamId);
	self.cp.ridgeMarkersAutomatic = streamDebugReadBool(streamId);
	self.cp.returnToFirstPoint = streamDebugReadBool(streamId);
	self.cp.selectedDriverNumber = streamDebugReadInt32(streamId);
	self.cp.shovelEmptyPoint = streamDebugReadInt32(streamId);
	self.cp.shovelFillStartPoint = streamDebugReadInt32(streamId);
	self.cp.shovelFillEndPoint = streamDebugReadInt32(streamId);
	self.cp.shovelState = streamDebugReadInt32(streamId);
	self.cp.shovelStopAndGo = streamDebugReadBool(streamId);
	self.cp.shovelLastFillLevel = streamDebugReadFloat32(streamId);
	self.cp.startAtFirstPoint = streamDebugReadBool(streamId);
	self.cp.startingCorner = streamDebugReadInt32(streamId);
	self.cp.startingDirection = streamDebugReadInt32(streamId);
	self.cp.stopForLoading = streamDebugReadBool(streamId);
	self.cp.tipperHasCover = streamDebugReadBool(streamId);
	self.cp.tipperFillLevel = streamDebugReadFloat32(streamId);
	self.cp.tipperCapacity = streamDebugReadFloat32(streamId);
	self.cp.waitForTurnTime = streamDebugReadFloat32(streamId)
	self.cp.turnStage = streamDebugReadInt32(streamId);
	self.cp.aiTurnNoBackward = streamDebugReadBool(streamId);
	self.cp.backMarkerOffset = streamDebugReadFloat32(streamId)
	self.cp.aiFrontMarker = streamDebugReadFloat32(streamId)
	self.cp.turnTimer = streamDebugReadInt32(streamId);
	self.cp.noStopOnEdge = streamDebugReadBool(streamId);
	self.cp.noStopOnTurn = streamDebugReadBool(streamId);
	self.cp.offset = streamDebugReadFloat32(streamId);
	self.crossPoints = streamDebugReadInt32(streamId)
	self.drive = streamDebugReadBool(streamId)
	self.drive_slow_timer = streamDebugReadInt32(streamId)
	self.field_speed = streamDebugReadFloat32(streamId)
	self.fold_move_direction = streamDebugReadInt32(streamId)
	self.follow_mode = streamDebugReadInt32(streamId)
	self.forced_side = streamDebugReadString(streamId)
	self.forced_to_stop = streamDebugReadBool(streamId)
	self.cp.globalInfoText = streamDebugReadString(streamId);
	self.cp.globalInfoTextLevel = streamDebugReadInt32(streamId);
	self.cp.infoText = streamDebugReadString(streamId)
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
	self.shortest_dist = streamDebugReadFloat32(streamId)
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
	self.unloaded = streamDebugReadBool(streamId)
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
	streamDebugWriteInt32(streamId, self.cp.attachedCombineIdx);
	streamDebugWriteBool(streamId, self.cp.canSwitchMode);
	streamDebugWriteBool(streamId, self.cp.courseListPrev)
	streamDebugWriteBool(streamId, self.cp.courseListNext)
	streamDebugWriteInt32(streamId,self.courseplay_position)
	streamDebugWriteInt32(streamId,self.CPnumCollidingVehicles)
	streamDebugWriteBool(streamId, self.cpTrafficBrake)
	streamDebugWriteBool(streamId, self.cp.globalInfoTextOverlay.isRendering);
	streamDebugWriteBool(streamId, self.cp.hasFoundCopyDriver);
	streamDebugWriteBool(streamId, self.cp.hasStartingCorner);
	streamDebugWriteBool(streamId, self.cp.hasStartingDirection);
	streamDebugWriteBool(streamId, self.cp.hasGeneratedCourse);
	streamDebugWriteBool(streamId, self.cp.hasValidCourseGenerationData);
	streamDebugWriteBool(streamId, self.cp.isCombine);
	streamDebugWriteBool(streamId, self.cp.isChopper);
	streamDebugWriteBool(streamId, self.cp.isHarvesterSteerable);
	streamDebugWriteFloat32(streamId, self.cp.isKasi);
	streamDebugWriteBool(streamId, self.cp.isSugarBeetLoader);
	streamDebugWriteInt32(streamId, self.cp.minHudPage);
	streamDebugWriteBool(streamId, self.cp.mode7Unloading)
	streamDebugWriteBool(streamId, self.cp.ridgeMarkersAutomatic);
	streamDebugWriteBool(streamId, self.cp.returnToFirstPoint);
	streamDebugWriteInt32(streamId, self.cp.selectedDriverNumber);
	streamDebugWriteInt32(streamId, self.cp.shovelEmptyPoint);
	streamDebugWriteInt32(streamId, self.cp.shovelFillStartPoint);
	streamDebugWriteInt32(streamId, self.cp.shovelFillEndPoint);
	streamDebugWriteInt32(streamId, self.cp.shovelState);
	streamDebugWriteBool(streamId, self.cp.shovelStopAndGo);
	streamDebugWriteFloat32(streamId, self.cp.shovelLastFillLevel);
	streamDebugWriteBool(streamId, self.cp.startAtFirstPoint);
	streamDebugWriteInt32(streamId, self.cp.startingCorner);
	streamDebugWriteInt32(streamId, self.cp.startingDirection);
	streamDebugWriteBool(streamId, self.cp.stopForLoading);
	streamDebugWriteBool(streamId, self.cp.tipperHasCover);
	streamDebugWriteFloat32(streamId,self.cp.tipperFillLevel);
	streamDebugWriteFloat32(streamId,self.cp.tipperCapacity);
	streamDebugWriteFloat32(streamId,self.cp.waitForTurnTime)
	streamDebugWriteInt32(streamId, self.cp.turnStage)
	streamDebugWriteBool(streamId, self.cp.aiTurnNoBackward)
	streamDebugWriteFloat32(streamId,self.cp.backMarkerOffset)
	streamDebugWriteFloat32(streamId,self.cp.aiFrontMarker)
	streamDebugWriteInt32(streamId, self.cp.turnTimer)
	streamDebugWriteBool(streamId, self.cp.noStopOnEdge)
	streamDebugWriteBool(streamId, self.cp.noStopOnTurn)
	streamDebugWriteFloat32(streamId, self.cp.offset);
	streamDebugWriteInt32(streamId, self.crossPoints);
	streamDebugWriteBool(streamId,self.drive)
	streamDebugWriteInt32(streamId,self.drive_slow_timer)
	streamDebugWriteFloat32(streamId,self.field_speed)
	streamDebugWriteInt32(streamId,self.fold_move_direction)
	streamDebugWriteInt32(streamId,self.follow_mode)
	streamDebugWriteString(streamId,self.forced_side)
	streamDebugWriteBool(streamId,self.forced_to_stop)
	streamDebugWriteString(streamId,self.cp.globalInfoText);
	streamDebugWriteInt32(streamId,self.cp.globalInfoTextLevel);
	streamDebugWriteString(streamId,self.cp.infoText)
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
		self.max_speed                        = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#max_speed")              ), 50 / 3600);
		self.use_speed                        = Utils.getNoNil(getXMLBool(  xmlFile, key .. string.format("#use_speed")              ), false);
		self.turn_speed                       = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#turn_speed")             ), 10 / 3600);
		self.field_speed                      = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#field_speed")            ), 24 / 3600);
		self.unload_speed                     = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#unload_speed")           ),  6 / 3600);
		self.realistic_driving                = Utils.getNoNil(getXMLBool(  xmlFile, key .. string.format("#realistic_driving")      ), true);    
		self.tipper_offset                    = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#tipper_offset")          ), 0);
		self.combine_offset                   = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#combine_offset")         ), 0);

		self.required_fill_level_for_follow   = Utils.getNoNil(getXMLInt(   xmlFile, key .. string.format("#fill_follow")            ), 50);
		self.required_fill_level_for_drive_on = Utils.getNoNil(getXMLInt(   xmlFile, key .. string.format("#fill_drive")             ), 90);
		self.WpOffsetX                        = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#OffsetX")                ), 0);
		self.mouse_right_key_enabled          = Utils.getNoNil(getXMLBool(  xmlFile, key .. string.format("#mouse_right_key_enabled")), true);
		self.WpOffsetZ                        = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#OffsetZ")                ), 0);
		self.waitTime                         = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#waitTime")               ), 0);
		self.abortWork                        = Utils.getNoNil(getXMLInt(   xmlFile, key .. string.format("#AbortWork")              ), nil);
		self.turn_radius                      = Utils.getNoNil(getXMLInt(   xmlFile, key .. string.format("#turn_radius")            ), 10);
		self.RulMode                          = Utils.getNoNil(getXMLInt(   xmlFile, key .. string.format("#rul_mode")               ), 1);
		local courses                         = Utils.getNoNil(getXMLString(xmlFile, key .. string.format("#courses")                ), "");
		self.toolWorkWidht                    = Utils.getNoNil(getXMLFloat( xmlFile, key .. string.format("#toolWorkWidht")          ), 3);
		self.loaded_courses = courses:split(",")
		self.selected_course_number = 0

		courseplay:reload_courses(self, true)

		self.ai_mode = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#ai_mode")), 1);

		if self.abortWork == 0 then
			self.abortWork = nil
		end
		
		courseplay:validateCanSwitchMode(self);
		
	end
	return BaseMission.VEHICLE_LOAD_OK;
end


function courseplay:getSaveAttributesAndNodes(nodeIdent)

	local attributes =
		' max_speed="'               .. tostring(self.max_speed)                         .. '"' ..
		' use_speed="'               .. tostring(self.use_speed)                         .. '"' ..
		' turn_speed="'              .. tostring(self.turn_speed)                        .. '"' ..
		' field_speed="'             .. tostring(self.field_speed)                       .. '"' ..
		' unload_speed="'            .. tostring(self.unload_speed)                      .. '"' ..
		' tipper_offset="'           .. tostring(self.tipper_offset)                     .. '"' ..
		' combine_offset="'          .. tostring(self.combine_offset)                    .. '"' ..
		' fill_follow="'             .. tostring(self.required_fill_level_for_follow)    .. '"' ..
		' fill_drive="'              .. tostring(self.required_fill_level_for_drive_on)  .. '"' ..
		' OffsetX="'                 .. tostring(self.WpOffsetX)                         .. '"' ..
		' OffsetZ="'                 .. tostring(self.WpOffsetZ)                         .. '"' ..
		' AbortWork="'               .. tostring(self.abortWork)                         .. '"' ..
		' turn_radius="'             .. tostring(self.turn_radius)                       .. '"' ..
		' waitTime="'                .. tostring(self.waitTime)                          .. '"' ..
		' courses="'                 .. tostring(table.concat(self.loaded_courses, ",")) .. '"' ..
		' mouse_right_key_enabled="' .. tostring(self.mouse_right_key_enabled)           .. '"' .. --should save as bool string ("true"/"false")
		' rul_mode="'                .. tostring(self.RulMode)                           .. '"' ..
		' toolWorkWidht="'           .. tostring(self.toolWorkWidht)                     .. '"' ..
		' realistic_driving="'       .. tostring(self.realistic_driving)                 .. '"' ..
		' ai_mode="'                 .. tostring(self.ai_mode) .. '"';
	return attributes, nil;
end


function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields + 1] = c end)
	return fields
end
