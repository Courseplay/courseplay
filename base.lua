function courseplay.prerequisitesPresent(specializations)
	return true;
end

function courseplay:load(xmlFile)
	
	self.setCourseplayFunc = SpecializationUtil.callSpecializationsFunction("setCourseplayFunc");

	--SEARCH AND SET self.name IF NOT EXISTING
	if self.name == nil then
		local nameSearch = { "vehicle.name." .. g_languageShort, "vehicle.name.en", "vehicle.name", "vehicle#type" };
		for i,xmlPath in pairs(nameSearch) do
			self.name = getXMLString(xmlFile, xmlPath);
			if self.name ~= nil then
				courseplay:debug(nameNum(self) .. ": self.name was nil, got new name from " .. xmlPath .. " in XML", 12);
				break;
			end;
		end;
		if self.name == nil then
			self.name = g_i18n:getText("UNKNOWN");
			courseplay:debug(tostring(self.configFileName) .. ": self.name was nil, new name is " .. self.name, 12);
		end;
	end;

	self.cp = {};

	courseplay:setNameVariable(self);
	self.cp.isCombine = courseplay:isCombine(self);
	self.cp.isChopper = courseplay:isChopper(self);
	self.cp.isHarvesterSteerable = courseplay:isHarvesterSteerable(self);
	self.cp.isKasi = nil
	self.cp.isSugarBeetLoader = courseplay:isSpecialCombine(self, "sugarBeetLoader");
	if self.cp.isCombine then
		self.cp.mode7Unloading = false
	end
	if self.isRealistic then
		self.cp.trailerPushSpeed = 0
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
	self.cp.closestTipDistance = math.huge

	self.auto_combine_offset = true
	self.mouse_right_key_enabled = true
	self.drive = false
	self.runOnceStartCourse = false;
	self.StopEnd = false
	self.calculated_course = false

	self.recordnumber = 1
	self.cp.last_recordnumber = 1;
	self.tmr = 1
	self.startlastload = 1
	self.timeout = 1
	self.timer = 0.00
	self.cp.timers = {}; 
	self.drive_slow_timer = 0
	self.courseplay_position = nil
	self.waitPoints = 0
	self.waitTime = 0
	self.crossPoints = 0
	self.cp.visualWaypointsMode = 1
	self.RulMode = 1
	self.cp.workWidthChanged = 0
	-- saves the shortest distance to the next waypoint (for recocnizing circling)
	self.shortest_dist = nil
	self.use_speed = true

	self.Waypoints = {}

	self.play = false --can drive course (has >4 waypoints, is not recording)
	self.cp.coursePlayerNum = nil;

	self.cp.infoText = nil -- info text on tractor

	-- global info text - also displayed when not in vehicle
	local git = courseplay.globalInfoText;
	self.cp.globalInfoTextOverlay = Overlay:new(string.format("globalInfoTextOverlay%d", self.rootNode), git.backgroundImg, git.backgroundX, git.backgroundY, 0.1, git.fontSize);
	self.testhe = false

	-- ai mode: 1 abfahrer, 2 kombiniert
	self.ai_mode = 1
	self.follow_mode = 1
	self.ai_state = 0
	self.next_ai_state = nil
	self.startWork = nil
	self.stopWork = nil
	self.abortWork = nil
	self.cp.hasUnloadingRefillingCourse = false;
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

	-- our arrow is displaying dirction to waypoints
	self.ArrowPath = Utils.getFilename("img/arrow.dds", courseplay.path);
	self.ArrowOverlay = Overlay:new("Arrow", self.ArrowPath, 0.55, 0.05, 0.250, 0.250);
	--self.ArrowOverlay:render()

	-- Visual i3D waypoint signs
	self.cp.signs = {
		crossing = {};
		current = {};
	};
	courseplay:updateWaypointSigns(self);

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

	-- data basis for the Course list
	self.cp.reloadCourseItems = true
	self.cp.sorted = {item={}, info={}}	
	self.cp.folder_settings = {}
	courseplay.settings.update_folders(self)

	if self.aiTrafficCollisionTrigger == nil and getNumOfChildren(self.rootNode) > 0 then
		if getChild(self.rootNode, "trafficCollisionTrigger") ~= 0 then
			self.aiTrafficCollisionTrigger = getChild(self.rootNode, "trafficCollisionTrigger");
		else
			for i=0,getNumOfChildren(self.rootNode)-1 do
				local child = getChildAt(self.rootNode, i);
				if getChild(child, "trafficCollisionTrigger") ~= 0 then
					self.aiTrafficCollisionTrigger = getChild(child, "trafficCollisionTrigger");
					break;
				end;
			end;
		end;
	end;

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
	end;
	self.cp.DirectionNode = DirectionNode;

	-- traffic collision
	self.onTrafficCollisionTrigger = courseplay.cponTrafficCollisionTrigger;
	--self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	self.steering_angle = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.wheels.wheel(1)" .. "#rotMax"), 30)
	self.cp.tempCollis = {}
	self.CPnumCollidingVehicles = 0;
	--	self.numToolsCollidingVehicles = {};
	--	self.trafficCollisionIgnoreList = {};
	self.cpTrafficCollisionIgnoreList = {};
	self.cp.TrafficBrake = false
	-- tipTrigger
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	self.findTrafficCollisionCallback = courseplay.findTrafficCollisionCallback;
	self.findBlockingObjectCallbackLeft = courseplay.findBlockingObjectCallbackLeft
	self.findBlockingObjectCallbackRight = courseplay.findBlockingObjectCallbackRight
	

	if self.numCollidingVehicles == nil then
		self.numCollidingVehicles = {};
	end
	if self.trafficCollisionIgnoreList == nil then
		self.trafficCollisionIgnoreList = {}
	end

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
	self.cp.tipLocation = 1;
	self.cp.tipperHasCover = false;
	self.cp.tippersWithCovers = {};
	self.cp.tipperFillLevel = nil;
	self.cp.tipperCapacity = nil;

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
	
	self.cp.EifokLiquidManure = {
		targetRefillObject = {};
		searchMapHoseRefStation = {
			pull = true;
			push = true;
		};
	};
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
	self.cp.selectedFieldEdgePathNumber = 0;

	self.mouse_enabled = false


	local w16px, h16px = 16/1920, 16/1080;
	local w24px, h24px = 24/1920, 24/1080;
	local w32px, h32px = 32/1920, 32/1080;

	-- HUD
	self.cp.hud = {
		background = Overlay:new("hudInfoBaseOverlay", Utils.getFilename("img/hud_bg.dds", courseplay.path), courseplay.hud.infoBasePosX - 10/1920, courseplay.hud.infoBasePosY - 10/1920, courseplay.hud.infoBaseWidth, courseplay.hud.infoBaseHeight);
		currentPage = 1;
		show = false;
		content = {
			global = {};
			pages = {};
		};
		mouseWheel = {
			icon = Overlay:new("cpMouseWheelIcon", "dataS2/menu/mouseControlsHelp/mouseMMB.png", 0, 0, w32px, h32px);
			render = false;
		};

		--3rd party huds backup
		ESLimiterOrigPosY = nil; --[table]
		ThreshingCounterOrigPosY = nil; --[table]
		OdometerOrigPosY = nil; --[table]
		AllradOrigPosY = nil; --[table]
	};

	for page=0,courseplay.hud.numPages do
		self.cp.hud.content.pages[page] = {};
		for line=1,courseplay.hud.numLines do
			self.cp.hud.content.pages[page][line] = {
				{ text = nil, isHovered = false, indention = 0 },
				{ text = nil }
			};
		end;
	end;
	
	-- course list
	self.cp.hud.filterEnabled = true;
	self.cp.hud.filter = "";
	self.cp.hud.choose_parent = false
	self.cp.hud.showFoldersOnly = false
	self.cp.hud.showZeroLevelFolder = false
	self.cp.hud.courses = {}
	self.cp.hud.courseListPrev = false;
	self.cp.hud.courseListNext = false; -- will be updated after loading courses into the hud
	self.cp.hud.reloadPage = {}
	self.cp.hud.reloadPage[-1] = true -- reload all

	-- clickable buttons
	self.cp.buttons = {};
	self.cp.buttons.global = {};
	self.cp.buttons["-2"] = {};
	for page=0, courseplay.hud.numPages do
		self.cp.buttons[tostring(page)] = {};
	end;

	--Camera backups: allowTranslation
	self.cp.camerasBackup = {};
	for camIndex, camera in pairs(self.cameras) do
		if camera.allowTranslation then
			self.cp.camerasBackup[camIndex] = camera.allowTranslation;
		end;
	end;

	--default hud conditional variables
	self.cp.HUD0noCourseplayer = false;
	self.cp.HUD0wantsCourseplayer = false;
	self.cp.HUD0tractorName = "";
	self.cp.HUD0tractorForcedToStop = false;
	self.cp.HUD0tractor = false;
	self.cp.HUD0combineForcedSide = nil;
	self.cp.HUD0isManual = false;
	self.cp.HUD0turnStage = 0;
	self.cp.HUD1notDrive = false;
	self.cp.HUD1goOn = false;
	self.cp.HUD1noWaitforFill = false;
	self.cp.HUD4combineName = "";
	self.cp.HUD4hasActiveCombine = false;
	self.cp.HUD4savedCombine = nil;
	self.cp.HUD4savedCombineName = "";

	courseplay:setMinHudPage(self, nil);

	--Hud titles
	if courseplay.hud.hudTitles == nil then
		courseplay.hud.hudTitles = {
			courseplay:get_locale(self, "CPCombineManagement"), -- Combine Controls
			courseplay:get_locale(self, "CPSteering"), -- "Abfahrhelfer Steuerung"
			{ courseplay:get_locale(self, "CPManageCourses"), courseplay:get_locale(self, "CPchooseFolder"), courseplay:get_locale(self, "CPcoursesFilterTitle") }, -- "Kurse verwalten"
			courseplay:get_locale(self, "CPCombiSettings"), -- "Einstellungen Combi Modus"
			courseplay:get_locale(self, "CPManageCombines"), -- "Drescher verwalten"
			courseplay:get_locale(self, "CPSpeedLimit"), -- "Speeds"
			courseplay:get_locale(self, "CPSettings"), -- "General settings"
			courseplay:get_locale(self, "CPHud7"), -- "Driving settings"
			courseplay:get_locale(self, "CPcourseGeneration"), -- "Course Generation"
			courseplay:get_locale(self, "CPShovelPositions") --Schaufel progammieren
		};
	end;


	-- ## BUTTONS FOR HUD ##
	local mouseWheelArea = {
		x = courseplay.hud.infoBasePosX + 0.005,
		w = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1 - (2 * 0.005),
		h = courseplay.hud.lineHeight
	};

	local listArrowX = courseplay.hud.visibleArea.x2 - (2 * 0.005) - w24px;

	-- Page nav
	local pageNav = {
		buttonW = w32px;
		buttonH = h32px;
		paddingRight = 0.005;
		posY = courseplay.hud.infoBasePosY + 0.271;
	};
	pageNav.totalWidth = ((courseplay.hud.numPages + 1) * pageNav.buttonW) + (courseplay.hud.numPages * pageNav.paddingRight); --numPages=9, real numPages=10
	pageNav.baseX = courseplay.hud.infoBaseCenter - pageNav.totalWidth/2;
	for p=0, courseplay.hud.numPages do
		local posX = pageNav.baseX + (p * (pageNav.buttonW + pageNav.paddingRight));
		courseplay:register_button(self, "global", string.format("pageNav_%d.dds", p), "setHudPage", p, posX, pageNav.posY, pageNav.buttonW, pageNav.buttonH);
	end;

	courseplay:register_button(self, "global", "navigate_left.dds", "switch_hud_page", -1, courseplay.hud.infoBasePosX + 0.035, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px); --ORIG: +0.242
	courseplay:register_button(self, "global", "navigate_right.dds", "switch_hud_page", 1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.infoBasePosY + 0.2395, w24px, h24px);

	courseplay:register_button(self, "global", "close.dds", "openCloseHud", false, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.infoBasePosY + 0.255, w24px, h24px);

	courseplay:register_button(self, "global", "disk.dds", "showSaveCourseForm", 'course', listArrowX - 15/1920 - w24px, courseplay.hud.infoBasePosY + 0.056, w24px, h24px);

	--Page 0: Combine controls
	for i=1, courseplay.hud.numLines do
		courseplay:register_button(self, 0, "blank.dds", "rowButton", i, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[i], courseplay.hud.visibleArea.width, 0.015, i, nil, true);
	end;


	--Page 1
	--ai_mode quickSwitch
	local aiModeQuickSwitch = {
		w = w32px;
		h = h32px;
		numColumns = 3;
		maxX = courseplay.hud.visibleArea.x2 - 0.01;
	};
	aiModeQuickSwitch.minX = aiModeQuickSwitch.maxX - (aiModeQuickSwitch.numColumns * aiModeQuickSwitch.w);
	for i=1, courseplay.numAiModes do
		local icon = string.format("quickSwitch_mode%d.dds", i);

		local l = math.ceil(i/aiModeQuickSwitch.numColumns);
		local col = i;
		while col > aiModeQuickSwitch.numColumns do
			col = col - aiModeQuickSwitch.numColumns;
		end;

		local posX = aiModeQuickSwitch.minX + (aiModeQuickSwitch.w * (col-1));
		local posY = courseplay.hud.linesPosY[1] + courseplay.hud.lineHeight --[[(20/1080)]] - (aiModeQuickSwitch.h * l);

		courseplay:register_button(self, 1, icon, "setAiMode", i, posX, posY, aiModeQuickSwitch.w, aiModeQuickSwitch.h);
	end;

	for i=1, courseplay.hud.numLines do
		courseplay:register_button(self, 1, "blank.dds", "rowButton", i, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[i], aiModeQuickSwitch.minX - courseplay.hud.infoBasePosX - 0.005, 0.015, i, nil, true);
	end;


	--Page 2: Course management
	--course navigation
	courseplay:register_button(self, 2, "navigate_up.dds",   "shiftHudCourses", -courseplay.hud.numLines, listArrowX, courseplay.hud.linesPosY[1] - 0.003,                       w24px, h24px, nil, -courseplay.hud.numLines*2);
	courseplay:register_button(self, 2, "navigate_down.dds", "shiftHudCourses",  courseplay.hud.numLines, listArrowX, courseplay.hud.linesPosY[courseplay.hud.numLines] - 0.003, w24px, h24px, nil,  courseplay.hud.numLines*2);

	local courseListMouseWheelArea = {
		x = mouseWheelArea.x,
		y = courseplay.hud.linesPosY[courseplay.hud.numLines],
		width = mouseWheelArea.w,
		height = courseplay.hud.linesPosY[1] + courseplay.hud.lineHeight - courseplay.hud.linesPosY[courseplay.hud.numLines]
	};
	courseplay:register_button(self, 2, nil, "shiftHudCourses",  -1, courseListMouseWheelArea.x, courseListMouseWheelArea.y, courseListMouseWheelArea.width, courseListMouseWheelArea.height, nil, -courseplay.hud.numLines, nil, true);

	--reload courses
	if g_server ~= nil then
		--courseplay:register_button(self, 2, "refresh.dds", "reloadCoursesFromXML", nil, courseplay.hud.infoBasePosX + 0.258, courseplay.hud.infoBasePosY + 0.24, w16px, h16px);
	end;

	--course actions
	local pad = w16px*10/16 --old padding = 0.009667 ~ 18.5px
	local buttonX = {};
	buttonX[0] = courseplay.hud.infoBasePosX + 0.005;
	buttonX[4] = listArrowX - (2 * pad) - w16px;
	buttonX[3] = buttonX[4] - pad - w16px;
	buttonX[2] = buttonX[3] - pad - w16px;
	buttonX[1] = buttonX[2] - pad - w16px;
	local hoverAreaWidth = buttonX[3] + w16px - buttonX[1];
	if g_server ~= nil then
		hoverAreaWidth = buttonX[4] + w16px - buttonX[1];
	end;
	for i=1, courseplay.hud.numLines do
		local expandButtonIndex = courseplay:register_button(self, -2, "folder_expand.png", "expandFolder", i, buttonX[0], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		courseplay.button.addOverlay(self.cp.buttons["-2"][expandButtonIndex], 2, "folder_reduce.png");
		courseplay:register_button(self, -2, "courseLoadAppend.png", "load_sorted_course", i, buttonX[1], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		courseplay:register_button(self, -2, "courseAdd.png", "add_sorted_course", i, buttonX[2], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		local linkParentButtonIndex = courseplay:register_button(self, -2, "folder_parent_from.png", "link_parent", i, buttonX[3], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		courseplay.button.addOverlay(self.cp.buttons["-2"][linkParentButtonIndex], 2, "folder_parent_to.png");
		if g_server ~= nil then
			courseplay:register_button(self, -2, "delete.png", "delete_sorted_item", i, buttonX[4], courseplay.hud.linesButtonPosY[i], w16px, h16px, i, nil, false);
		end;
		courseplay:register_button(self, -2, nil, nil, nil, buttonX[1], courseplay.hud.linesButtonPosY[i], hoverAreaWidth, mouseWheelArea.h, i, nil, true, false);
	end
	self.cp.hud.filterButtonIndex = courseplay:register_button(self, 2, "searchGlass.png", "showSaveCourseForm", "filter", buttonX[2], courseplay.hud.infoBasePosY + 0.2395, w24px, h24px);
	courseplay.button.addOverlay(self.cp.buttons["2"][self.cp.hud.filterButtonIndex], 2, "cancel.png");
	courseplay:register_button(self, 2, "folder_new.png", "showSaveCourseForm", 'folder', listArrowX, courseplay.hud.infoBasePosY + 0.056, w24px, h24px);

	--Page 3
	courseplay:register_button(self, 3, "navigate_minus.dds", "change_combine_offset", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -0.5, false);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_combine_offset",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  0.5, false);
	courseplay:register_button(self, 3, nil, "change_combine_offset", 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_tipper_offset", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -0.5, false);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_tipper_offset",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  0.5, false);
	courseplay:register_button(self, 3, nil, "change_tipper_offset", 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_turn_radius", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, -5, false);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_turn_radius",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  5, false);
	courseplay:register_button(self, 3, nil, "change_turn_radius", 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_required_fill_level", -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -10, false);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_required_fill_level",  5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  10, false);
	courseplay:register_button(self, 3, nil, "change_required_fill_level", 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 10, true, true);

	courseplay:register_button(self, 3, "navigate_minus.dds", "change_required_fill_level_for_drive_on", -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, -10, false);
	courseplay:register_button(self, 3, "navigate_plus.dds",  "change_required_fill_level_for_drive_on",  5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5,  10, false);
	courseplay:register_button(self, 3, nil, "change_required_fill_level_for_drive_on", 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 10, true, true);

	--Page 4: Combine management
	courseplay:register_button(self, 4, "navigate_up.dds",   "switch_combine", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, nil, false);
	courseplay:register_button(self, 4, "navigate_down.dds", "switch_combine",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, nil, false);
	courseplay:register_button(self, 4, nil, nil, nil, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], 0.015 + w16px, mouseWheelArea.h, 1, nil, true, false);

	courseplay:register_button(self, 4, "blank.dds", "switch_search_combine", nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], courseplay.hud.visibleArea.width, 0.015, 2, nil, true);

	--Page 5: Speeds
	courseplay:register_button(self, 5, "navigate_minus.dds", "change_turn_speed",   -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -5, false);
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_turn_speed",    1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  5, false);
	courseplay:register_button(self, 5, nil, "change_turn_speed", 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 5, true, true);

	courseplay:register_button(self, 5, "navigate_minus.dds", "change_field_speed",  -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, 2, -5, false);
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_field_speed",   1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  5, false);
	courseplay:register_button(self, 5, nil, "change_field_speed", 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 5, true, true);

	courseplay:register_button(self, 5, "navigate_minus.dds", "change_max_speed",    -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, 3, -5, false);
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_max_speed",     1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  5, false);
	courseplay:register_button(self, 5, nil, "change_max_speed", 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

	courseplay:register_button(self, 5, "navigate_minus.dds", "change_unload_speed", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[4], w16px, h16px, 4, -5, false);
	courseplay:register_button(self, 5, "navigate_plus.dds",  "change_unload_speed",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[4], w16px, h16px, 4,  5, false);
	courseplay:register_button(self, 5, nil, "change_unload_speed", 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	courseplay:register_button(self, 5, "blank.dds", "change_use_speed",1, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);


	--Page 6: General settings
	courseplay:register_button(self, 6, "blank.dds", "switch_realistic_driving",       nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[1], courseplay.hud.visibleArea.width, 0.015, 1, nil, true);
	courseplay:register_button(self, 6, "blank.dds", "switch_mouse_right_key_enabled", nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], courseplay.hud.visibleArea.width, 0.015, 2, nil, true);
	courseplay:register_button(self, 6, "blank.dds", "change_WaypointMode",            1,   courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[3], courseplay.hud.visibleArea.width, 0.015, 3, nil, true);
	courseplay:register_button(self, 6, "blank.dds", "change_RulMode",                 1,   courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[4], courseplay.hud.visibleArea.width, 0.015, 4, nil, true);

	if courseplay.fields ~= nil and courseplay.fields.fieldDefs ~= nil and courseplay.fields.numberOfFields > 0 then
		courseplay:register_button(self, 6, "navigate_up.dds",   "setFieldEdgePath", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
		courseplay:register_button(self, 6, "navigate_down.dds", "setFieldEdgePath",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
		courseplay:register_button(self, 6, nil, nil, nil, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], 0.015 + w16px, mouseWheelArea.h, 5, nil, true, false);
	end;

	local dbgW, dbgH = 22/1920, 22/1080;
	local dbgPosY = courseplay.hud.linesPosY[6] - 0.004;
	local dbgMaxX = courseplay.hud.infoBasePosX + 0.285 - 0.01;
	for dbg=1, courseplay.numAvailableDebugChannels do
		local col = ((dbg-1) % courseplay.numDebugChannelButtonsPerLine) + 1;
		local dbgPosX = dbgMaxX - (courseplay.numDebugChannelButtonsPerLine * dbgW) + ((col-1) * dbgW);
		courseplay:register_button(self, 6, "debugChannelButtons.png", "toggleDebugChannel", dbg, dbgPosX, dbgPosY, dbgW, dbgH);
	end;
	courseplay:register_button(self, 6, "navigate_up.png",   "changeDebugChannelSection", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[6], w16px, h16px, -1, nil, false);
	courseplay:register_button(self, 6, "navigate_down.png", "changeDebugChannelSection",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[6], w16px, h16px,  1, nil, false);

	--Page 7: Driving settings
	courseplay:register_button(self, 7, "navigate_minus.dds", "change_wait_time",  -5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -10, false);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "change_wait_time",   5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  10, false);
	courseplay:register_button(self, 7, nil, "change_wait_time", 5, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 10, true, true);

	courseplay:register_button(self, 7, "navigate_minus.dds", "changeWpOffsetX", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,  -0.5, false);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "changeWpOffsetX",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[2], w16px, h16px, 2,   0.5, false);
	courseplay:register_button(self, 7, nil, "changeWpOffsetX", 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);

	courseplay:register_button(self, 7, "navigate_minus.dds", "changeWpOffsetZ", -0.5, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,  -1, false);
	courseplay:register_button(self, 7, "navigate_plus.dds",  "changeWpOffsetZ",  0.5, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[3], w16px, h16px, 3,   1, false);
	courseplay:register_button(self, 7, nil, "changeWpOffsetZ", 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 0.5, true, true);

	courseplay:register_button(self, 7, "navigate_up.dds",   "switchDriverCopy", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay:register_button(self, 7, "navigate_down.dds", "switchDriverCopy",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay:register_button(self, 7, nil, nil, nil, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], 0.015 + w16px, mouseWheelArea.h, 5, nil, true, false);
	courseplay:register_button(self, 7, "copy.png",          "copyCourse",      nil, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[6], w16px, h16px);

	--Page 8: Course generation
	courseplay:register_button(self, 8, "navigate_minus.dds", "changeWorkWidth", -0.1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  -0.5, false);
	courseplay:register_button(self, 8, "navigate_plus.dds",  "changeWorkWidth",  0.1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,   0.5, false);
	courseplay:register_button(self, 8, nil, "changeWorkWidth", 0.1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);

	courseplay:register_button(self, 8, "blank.dds", "switchStartingCorner",     nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[2], courseplay.hud.visibleArea.width, 0.015, 2, nil, true);
	courseplay:register_button(self, 8, "blank.dds", "switchStartingDirection",  nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[3], courseplay.hud.visibleArea.width, 0.015, 3, nil, true);
	courseplay:register_button(self, 8, "blank.dds", "switchReturnToFirstPoint", nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[4], courseplay.hud.visibleArea.width, 0.015, 4, nil, true);

	courseplay:register_button(self, 8, "navigate_up.dds",   "setHeadlandLanes",   1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay:register_button(self, 8, "navigate_down.dds", "setHeadlandLanes",  -1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[5], w16px, h16px, 5, nil, false);
	courseplay:register_button(self, 8, nil, nil, nil, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[5], 0.015 + w16px, mouseWheelArea.h, 5, nil, true, false);

	courseplay:register_button(self, 8, "blank.dds", "generateCourse",           nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[6], courseplay.hud.visibleArea.width, 0.015, 6, nil, true);

	--Page 9: Shovel settings
	local wTemp = 22/1920;
	local hTemp = 22/1080;
	courseplay:register_button(self, 9, "shovelLoading.dds",      "saveShovelStatus", 2, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[1] - 0.003, wTemp, hTemp, 1, 2, true);
	courseplay:register_button(self, 9, "shovelTransport.dds",    "saveShovelStatus", 3, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[2] - 0.003, wTemp, hTemp, 2, 3, true);
	courseplay:register_button(self, 9, "shovelPreUnloading.dds", "saveShovelStatus", 4, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[3] - 0.003, wTemp, hTemp, 3, 4, true);
	courseplay:register_button(self, 9, "shovelUnloading.dds",    "saveShovelStatus", 5, courseplay.hud.infoBasePosX + 0.200, courseplay.hud.linesButtonPosY[4] - 0.003, wTemp, hTemp, 4, 5, true);

	courseplay:register_button(self, 9, "blank.dds", "setShovelStopAndGo", nil, courseplay.hud.infoBasePosX, courseplay.hud.linesPosY[5], courseplay.hud.visibleArea.width, 0.015, 5, nil, true);
	--END Page 9


	self.fold_move_direction = 1;

	courseplay:buttonsActiveEnabled(self, "all");
end

function courseplay:onLeave()
	if self.mouse_enabled then
		courseplay:setMouseCursor(self, false);
	end

	--hide visual i3D waypoint signs only when in vehicle
	courseplay:setSignsVisibility(self, false);
end

function courseplay:onEnter()
	if self.mouse_enabled then
		courseplay:setMouseCursor(self, true);
	end

	if self.drive and self.steeringEnabled then
	  self.steeringEnabled = false
	end

	--show visual i3D waypoint signs only when in vehicle
	courseplay:setSignsVisibility(self);
end

function courseplay:draw()
	if self.dcheck and table.getn(self.Waypoints) > 1 then
		courseplay:dcheck(self);
	end

	--WORKWIDTH DISPLAY
	if self.cp.workWidthChanged > self.timer then
		courseplay:showWorkWidth(self);
	end;

	--KEYBOARD ACTIONS and HELP BUTTON TEXTS
	--Note: located in draw() instead of update() so they're not displayed/executed for *all* vehicles but rather only for *self*
	if self:getIsActive() and self.isEntered then
		local kb = courseplay.inputBindings.keyboard;
		local mouse = courseplay.inputBindings.mouse;

		if (self.play or not self.mouse_right_key_enabled) and not InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
			g_currentMission:addHelpButtonText(courseplay:get_locale(self, "COURSEPLAY_FUNCTIONS"), InputBinding.COURSEPLAY_MODIFIER);
		end;

		if self.cp.hud.show then
			if self.mouse_enabled then
				g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:get_locale(self, "COURSEPLAY_MOUSEARROW_HIDE"));
			else
				g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:get_locale(self, "COURSEPLAY_MOUSEARROW_SHOW"));
			end;
		end;

		if self.mouse_right_key_enabled then
			if not self.cp.hud.show then
				g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:get_locale(self, "COURSEPLAY_HUD_OPEN"));
			end;
		else
			if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
				if not self.cp.hud.show then
					g_currentMission:addHelpButtonText(courseplay:get_locale(self, "COURSEPLAY_HUD_OPEN"), InputBinding.COURSEPLAY_HUD);
				else
					g_currentMission:addHelpButtonText(courseplay:get_locale(self, "COURSEPLAY_HUD_CLOSE"), InputBinding.COURSEPLAY_HUD);
				end;
			end;

			if InputBinding.hasEvent(InputBinding.COURSEPLAY_HUD_COMBINED) then
				--courseplay:openCloseHud(self, not self.cp.hud.show);
				self:setCourseplayFunc("openCloseHud", not self.cp.hud.show);
			end;
		end;

		if self.play then
			if self.drive then
				if InputBinding.hasEvent(InputBinding.COURSEPLAY_START_STOP_COMBINED) then
					self:setCourseplayFunc("stop", nil);
				elseif self.cp.HUD1goOn and InputBinding.hasEvent(InputBinding.COURSEPLAY_DRIVEON_COMBINED) then
					self:setCourseplayFunc("drive_on", nil);
				elseif self.cp.HUD1noWaitforFill and InputBinding.hasEvent(InputBinding.COURSEPLAY_DRIVENOW_COMBINED) then
					self:setCourseplayFunc("setIsLoaded", true);
				end;

				if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
					g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStop"), InputBinding.COURSEPLAY_START_STOP);
					if self.cp.HUD1goOn then
						g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CourseWaitpointStart"), InputBinding.COURSEPLAY_DRIVEON);
					end;
					if self.cp.HUD1noWaitforFill then
						g_currentMission:addHelpButtonText(courseplay:get_locale(self, "NoWaitforfill"), InputBinding.COURSEPLAY_DRIVENOW);
					end;
				end;
			else
				if InputBinding.hasEvent(InputBinding.COURSEPLAY_START_STOP_COMBINED) then
					self:setCourseplayFunc("start", nil);
				end;

				if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) then
					g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStart"), InputBinding.COURSEPLAY_START_STOP);
				end;
			end;
		end;
	end; -- self:getIsActive() and self.isEntered

	--RENDER
	courseplay:renderInfoText(self);
	if g_server ~= nil then
		self.cp.infoText = nil;
	end

	if self:getIsActive() then
		if self.cp.hud.show then
			courseplay:setHudContent(self);
			courseplay:renderHud(self);

			if self.mouse_enabled then
				InputBinding.setShowMouseCursor(self.mouse_enabled);
			end;
		end;
	end;
end; --END draw()

function courseplay:showWorkWidth(vehicle)
	local left =  vehicle.cp.workWidthDisplayPoints.left;
	local right = vehicle.cp.workWidthDisplayPoints.right;
	drawDebugPoint(left.x, left.y, left.z, 1, 1, 0, 1);
	drawDebugPoint(right.x, right.y, right.z, 1, 1, 0, 1);
	drawDebugLine(left.x, left.y, left.z, 1, 0, 0, right.x, right.y, right.z, 1, 0, 0);
end;

-- is been called everey frame
function courseplay:update(dt)
	-- we are in record mode
	if self.record then
		courseplay:record(self);
	end

	-- we are in drive mode
	if self.drive then
		courseplay:drive(self, dt);
	end
	 
	if self.cp.onSaveClick and not self.cp.doNotOnSaveClick then
		inputCourseNameDialogue:onSaveClick()
		self.cp.onSaveClick = false
		self.cp.doNotOnSaveClick = false
	end

	if g_server ~= nil  then 
		if self.drive then
			self.cp.HUD1goOn = (self.Waypoints[self.cp.last_recordnumber] ~= nil and self.Waypoints[self.cp.last_recordnumber].wait and self.wait) or (self.StopEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil));
			self.cp.HUD1noWaitforFill = not self.loaded and self.ai_mode ~= 5;
		end;

		if self.cp.hud.currentPage == 0 then
			local combine = self;
			if self.cp.attachedCombineIdx ~= nil and self.tippers ~= nil and self.tippers[self.cp.attachedCombineIdx] ~= nil then
				combine = self.tippers[self.cp.attachedCombineIdx];
			end;
			if combine.courseplayers == nil then
				self.cp.HUD0noCourseplayer = true
				combine.courseplayers = {};
			else
				self.cp.HUD0noCourseplayer = table.getn(combine.courseplayers) == 0
			end
			self.cp.HUD0wantsCourseplayer = combine.wants_courseplayer
			self.cp.HUD0combineForcedSide = combine.forced_side
			self.cp.HUD0isManual = not self.drive and not combine.isAIThreshing 
			self.cp.HUD0turnStage = self.cp.turnStage
			local tractor = combine.courseplayers[1]
			if tractor ~= nil then
				self.cp.HUD0tractorForcedToStop = tractor.forced_to_stop
				self.cp.HUD0tractorName = tostring(tractor.name)
				self.cp.HUD0tractor = true
			else
				self.cp.HUD0tractorForcedToStop = nil
				self.cp.HUD0tractorName = nil
				self.cp.HUD0tractor = false
			end
		elseif self.cp.hud.currentPage == 4 then
			self.cp.HUD4hasActiveCombine = self.active_combine ~= nil
			if self.cp.HUD4hasActiveCombine == true then
				self.cp.HUD4combineName = self.active_combine.name
			end
			self.cp.HUD4savedCombine = self.saved_combine ~= nil and self.saved_combine.rootNode ~= nil
			if self.saved_combine ~= nil then
			 self.cp.HUD4savedCombineName = self.saved_combine.name
			end
		end
	end

	if g_server ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer then 
		for _,v in pairs(courseplay.checkValues) do
			self.cp[v .. "Memory"] = courseplay:checkForChangeAndBroadcast(self, "self.cp." .. v , self.cp[v], self.cp[v .. "Memory"]);
		end
	end
end; --END update()

function courseplay:updateTick(dt)
	--attached or detached implement?
	if self.tools_dirty then
		courseplay:reset_tools(self)
	end

	self.timer = self.timer + dt
	--courseplay:debug(string.format("timer: %f", self.timer ), 2)
end

function courseplay:delete()
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end;

	if self.cp ~= nil then
		if self.cp.hud.background ~= nil then
			self.cp.hud.background:delete();
		end;
		if self.ArrowOverlay ~= nil then
			self.ArrowOverlay:delete();
		end;
		if self.cp.buttons ~= nil then
			courseplay.button.deleteButtonOverlays(self);
		end;
		if self.cp.globalInfoTextOverlay ~= nil then
			self.cp.globalInfoTextOverlay:delete();
		end;
		if self.cp.signs ~= nil then
			for _,section in pairs(self.cp.signs) do
				for k,signData in pairs(section) do
					courseplay.utils.signs.deleteSign(signData.sign);
				end;
			end;
			self.cp.signs = nil;
		end;
	end;
end;

function courseplay:set_timeout(self, interval)
	self.timeout = self.timer + interval
end


function courseplay:get_locale(self, key)
	return Utils.getNoNil(courseplay.locales[key], key);
end;


function courseplay:readStream(streamId, connection)
	courseplay:debug("id: "..tostring(self.id).."  base: readStream", 5)

	self.ai_mode = streamDebugReadInt32(streamId)
	self.autoTurnRadius = streamDebugReadFloat32(streamId)
	self.auto_combine_offset = streamDebugReadBool(streamId);
	self.combine_offset = streamDebugReadFloat32(streamId)
	self.cp.hasStartingCorner = streamDebugReadBool(streamId);
	self.cp.hasStartingDirection = streamDebugReadBool(streamId);
	self.cp.hasValidCourseGenerationData = streamDebugReadBool(streamId);
	self.cp.headland.numLanes = streamDebugReadInt32(streamId)
	self.cp.infoText = streamDebugReadString(streamId);
	self.cp.returnToFirstPoint = streamDebugReadBool(streamId);
	self.cp.ridgeMarkersAutomatic = streamDebugReadBool(streamId);
	self.cp.shovelStopAndGo = streamDebugReadBool(streamId);
	self.drive = streamDebugReadBool(streamId)
	self.mouse_right_key_enabled = streamDebugReadBool(streamId)
	self.realistic_driving = streamDebugReadBool(streamId);
	self.required_fill_level_for_drive_on = streamDebugReadFloat32(streamId)
	self.required_fill_level_for_follow = streamDebugReadFloat32(streamId)
	self.tipper_offset = streamDebugReadFloat32(streamId)
	self.toolWorkWidht = streamDebugReadFloat32(streamId) 
	self.turnRadiusAutoMode = streamDebugReadBool(streamId);
	self.turn_radius = streamDebugReadFloat32(streamId)
	self.use_speed = streamDebugReadBool(streamId) 
	self.cp.coursePlayerNum = streamReadFloat32(streamId)
	self.WpOffsetX = streamDebugReadFloat32(streamId)
	self.WpOffsetZ = streamDebugReadFloat32(streamId)
	self.cp.hud.currentPage = streamDebugReadInt32(streamId)
	self.cp.HUD0noCourseplayer = streamDebugReadBool(streamId)
	self.cp.HUD0wantsCourseplayer = streamDebugReadBool(streamId)
	self.cp.HUD0combineForcedSide = streamDebugReadString(streamId);
	self.cp.HUD0isManual = streamDebugReadBool(streamId)
	self.cp.HUD0turnStage = streamDebugReadInt32(streamId)
	self.cp.HUD0tractorForcedToStop = streamDebugReadBool(streamId)
	self.cp.HUD0tractorName = streamDebugReadString(streamId);
	self.cp.HUD0tractor = streamDebugReadBool(streamId)
	self.cp.HUD1goON = streamDebugReadBool(streamId)
	self.cp.HUD1noWaitforFill = streamDebugReadBool(streamId)
	self.cp.HUD4hasActiveCombine = streamDebugReadBool(streamId)
	self.cp.HUD4combineName = streamDebugReadString(streamId);
	self.cp.HUD4savedCombine = streamDebugReadBool(streamId)
	self.cp.HUD4savedCombineName = streamDebugReadString(streamId);

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
		self.loaded_courses = Utils.splitString(",", courses);
		courseplay:reload_courses(self, true)
	end

	local debugChannelsString = streamDebugReadString(streamId)
	for k,v in pairs(Utils.splitString(",", debugChannelsString)) do
		courseplay.debugChannels[k] = v == "true";
	end;
end

function courseplay:writeStream(streamId, connection)
	courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write stream", 5)

	streamDebugWriteInt32(streamId,self.ai_mode)
	streamDebugWriteFloat32(streamId,self.autoTurnRadius)
	streamWriteBool(streamId, self.auto_combine_offset);
	streamDebugWriteFloat32(streamId,self.combine_offset)
	streamWriteFloat32(streamId, self.cp.globalInfoTextLevel);
	streamDebugWriteBool(streamId, self.cp.hasStartingCorner);
	streamDebugWriteBool(streamId, self.cp.hasStartingDirection);
	streamDebugWriteBool(streamId, self.cp.hasValidCourseGenerationData);
	streamDebugWriteInt32(streamId,self.cp.headland.numLanes);
	streamDebugWriteString(streamId, self.cp.infoText);
	streamDebugWriteBool(streamId, self.cp.returnToFirstPoint);
	streamDebugWriteBool(streamId, self.cp.ridgeMarkersAutomatic);
	streamDebugWriteBool(streamId, self.cp.shovelStopAndGo);
	streamDebugWriteBool(streamId,self.drive)
	streamDebugWriteBool(streamId,self.mouse_right_key_enabled)
	streamDebugWriteBool(streamId, self.realistic_driving);
	streamDebugWriteFloat32(streamId,self.required_fill_level_for_drive_on)
	streamDebugWriteFloat32(streamId,self.required_fill_level_for_follow)
	streamDebugWriteFloat32(streamId,self.tipper_offset)
	streamDebugWriteFloat32(streamId,self.toolWorkWidht);
	streamDebugWriteBool(streamId,self.turnRadiusAutoMode)
	streamDebugWriteFloat32(streamId,self.turn_radius)
	streamDebugWriteBool(streamId,self.use_speed)
	streamDebugWriteFloat32(streamId,self.cp.coursePlayerNum);
	streamDebugWriteFloat32(streamId,self.WpOffsetX)
	streamDebugWriteFloat32(streamId,self.WpOffsetZ)
	streamDebugWriteInt32(streamId,self.cp.hud.currentPage)
	streamDebugWriteBool(streamId,self.cp.HUD0noCourseplayer)
	streamDebugWriteBool(streamId,self.cp.HUD0wantsCourseplayer)
	streamDebugWriteString(streamId,self.cp.HUD0combineForcedSide)
	streamDebugWriteBool(streamId,self.cp.HUD0isManual)
	streamDebugWriteInt32(streamId,self.cp.HUD0turnStage)
	streamDebugWriteBool(streamId,self.cp.HUD0tractorForcedToStop)
	streamDebugWriteString(streamId,self.cp.HUD0tractorName)
	streamDebugWriteBool(streamId,self.cp.HUD0tractor)
	streamDebugWriteBool(streamId,self.cp.HUD1goON)
	streamDebugWriteBool(streamId,self.cp.HUD1noWaitforFill)
	streamDebugWriteBool(streamId,self.cp.HUD4hasActiveCombine)
	streamDebugWriteString(streamId,self.cp.HUD4combineName)
	streamDebugWriteBool(streamId,self.cp.HUD4savedCombine)
	streamDebugWriteString(streamId,self.cp.HUD4savedCombineName)

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

	local debugChannelsString = table.concat(table.map(courseplay.debugChannels, tostring), ",");
	streamDebugWriteString(streamId, debugChannelsString) 

end


function courseplay:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles and g_server ~= nil then
		self.max_speed                        = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#max_speed"              ), 50 / 3600);
		self.use_speed                        = Utils.getNoNil(getXMLBool(  xmlFile, key .. "#use_speed"              ), false);
		self.turn_speed                       = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#turn_speed"             ), 10 / 3600);
		self.field_speed                      = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#field_speed"            ), 24 / 3600);
		self.unload_speed                     = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#unload_speed"           ),  6 / 3600);
		self.realistic_driving                = Utils.getNoNil(getXMLBool(  xmlFile, key .. "#realistic_driving"      ), true);    
		self.tipper_offset                    = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#tipper_offset"          ), 0);
		self.combine_offset                   = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#combine_offset"         ), 0);

		self.required_fill_level_for_follow   = Utils.getNoNil(getXMLInt(   xmlFile, key .. "#fill_follow"            ), 50);
		self.required_fill_level_for_drive_on = Utils.getNoNil(getXMLInt(   xmlFile, key .. "#fill_drive"             ), 90);
		self.WpOffsetX                        = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#OffsetX"                ), 0);
		self.mouse_right_key_enabled          = Utils.getNoNil(getXMLBool(  xmlFile, key .. "#mouse_right_key_enabled"), true);
		self.WpOffsetZ                        = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#OffsetZ"                ), 0);
		self.waitTime                         = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#waitTime"               ), 0);
		self.abortWork                        = Utils.getNoNil(getXMLInt(   xmlFile, key .. "#AbortWork"              ), nil);
		self.turn_radius                      = Utils.getNoNil(getXMLInt(   xmlFile, key .. "#turn_radius"            ), 10);
		self.RulMode                          = Utils.getNoNil(getXMLInt(   xmlFile, key .. "#rul_mode"               ), 1);
		local courses                         = Utils.getNoNil(getXMLString(xmlFile, key .. "#courses"                ), "");
		self.toolWorkWidht                    = Utils.getNoNil(getXMLFloat( xmlFile, key .. "#toolWorkWidht"          ), 3);
		self.cp.ridgeMarkersAutomatic         = Utils.getNoNil(getXMLBool(  xmlFile, key .. "#ridgeMarkersAutomatic"  ), true);
		self.loaded_courses = Utils.splitString(",", courses);
		self.selected_course_number = 0

		courseplay:reload_courses(self, true)

		self.ai_mode = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#ai_mode")), 1);

		if self.abortWork == 0 then
			self.abortWork = nil
		end

		--Shovel positions
		local shovelRots = getXMLString(xmlFile, key .. string.format("#shovelRots"));
		if shovelRots ~= nil then
			courseplay:debug(tableShow(self.cp.shovelStateRot, nameNum(self) .. " shovelStateRot (before loading)", 10), 10);
			self.cp.shovelStateRot = nil;
			self.cp.shovelStateRot = {};
			local shovelStates = Utils.splitString(";", shovelRots);
			if table.getn(shovelStates) == 4 then
				for i=1,4 do
					local shovelStateSplit = table.map(Utils.splitString(" ", shovelStates[i]), tonumber);
					self.cp.shovelStateRot[tostring(i+1)] = shovelStateSplit;
				end;
				courseplay:debug(tableShow(self.cp.shovelStateRot, nameNum(self) .. " shovelStateRot (after loading)", 10), 10);
				courseplay:buttonsActiveEnabled(self, "shovel");
			end;
		end;

		courseplay:validateCanSwitchMode(self);

	end
	return BaseMission.VEHICLE_LOAD_OK;
end


function courseplay:getSaveAttributesAndNodes(nodeIdent)
	local shovelRotsTmp, shovelRotsAttr = {}, "";
	local hasAllShovelRots = self.cp.shovelStateRot ~= nil and self.cp.shovelStateRot["2"] ~= nil and self.cp.shovelStateRot["3"] ~= nil and self.cp.shovelStateRot["4"] ~= nil and self.cp.shovelStateRot["5"] ~= nil;
	if hasAllShovelRots then
		courseplay:debug(tableShow(self.cp.shovelStateRot, nameNum(self) .. " shovelStateRot (before saving)", 10), 10);
		local shovelStateRotSaveTable = {};
		for a=1,4 do
			shovelStateRotSaveTable[a] = {};
			local rotTable = self.cp.shovelStateRot[tostring(a+1)];
			for i=1,table.getn(rotTable) do
				shovelStateRotSaveTable[a][i] = courseplay:round(rotTable[i], 4);
			end;
			table.insert(shovelRotsTmp, tostring(table.concat(shovelStateRotSaveTable[a], " ")));
		end;
		if table.getn(shovelRotsTmp) > 0 then
			shovelRotsAttr = ' shovelRots="' .. tostring(table.concat(shovelRotsTmp, ";")) .. '"';
			courseplay:debug(nameNum(self) .. ": shovelRotsAttr=" .. shovelRotsAttr, 10);
		end;
	end;

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
		' ridgeMarkersAutomatic="'   .. tostring(self.cp.ridgeMarkersAutomatic)          .. '"' ..
		shovelRotsAttr .. 
		' ai_mode="'                 .. tostring(self.ai_mode) .. '"';
	return attributes, nil;
end

