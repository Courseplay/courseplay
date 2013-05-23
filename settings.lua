function courseplay:openCloseHud(self, open)
	self.mouse_enabled = open;
	self.show_hud = open;
	InputBinding.setShowMouseCursor(self.mouse_enabled);

	--set ESLimiter
	if self.cp.ESLimiterOrigPosY == nil and open and self.ESLimiter ~= nil then
		if self.ESLimiter.xPos ~= nil and self.ESLimiter.yPos ~= nil then
			if self.ESLimiter.xPos > courseplay.hud.visibleArea.x1 and self.ESLimiter.xPos < courseplay.hud.visibleArea.x2 and self.ESLimiter.yPos > courseplay.hud.visibleArea.y1 and self.ESLimiter.yPos < courseplay.hud.visibleArea.y2 then
				self.cp.ESLimiterOrigPosY = { 
					self.ESLimiter.yPos,
					self.ESLimiter.overlay.y,
					self.ESLimiter.overlayBg.y,
					self.ESLimiter.overlayBar.y
				}
			end;
		end;
	end;

	--hide/show ESLimiter
	if self.cp.ESLimiterOrigPosY ~= nil then
		if open then
			self.ESLimiter.yPos = -1;
			self.ESLimiter.overlay:setPosition(self.ESLimiter.overlay.x, -1);
			self.ESLimiter.overlayBg:setPosition(self.ESLimiter.overlayBg.x, -1);
			self.ESLimiter.overlayBar:setPosition(self.ESLimiter.overlayBar.x, -1);
		else
			self.ESLimiter.yPos = self.cp.ESLimiterOrigPosY[1];
			self.ESLimiter.overlay:setPosition(self.ESLimiter.overlay.x, self.cp.ESLimiterOrigPosY[2]);
			self.ESLimiter.overlayBg:setPosition(self.ESLimiter.overlayBg.x, self.cp.ESLimiterOrigPosY[3]);
			self.ESLimiter.overlayBar:setPosition(self.ESLimiter.overlayBar.x, self.cp.ESLimiterOrigPosY[4]);
		end;
	end;


	--set ThreshingCounter
	if self.cp.ThreshingCounterOrigPosY == nil and open and self.sessionHectars ~= nil and self.totalHectars ~= nil and self.tcOverlay ~= nil then
		if self.tcX ~= nil and self.tcY ~= nil then
			if self.tcX > courseplay.hud.visibleArea.x1 and self.tcX < courseplay.hud.visibleArea.x2 and self.tcY > courseplay.hud.visibleArea.y1 and self.tcY < courseplay.hud.visibleArea.y2 then
				self.cp.ThreshingCounterOrigPosY = { 
					self.tcY,
					self.tcOverlay.y,
				};
			end;
		end;
	end;

	--hide/show ThreshingCounter
	if self.cp.ThreshingCounterOrigPosY ~= nil then
		if open then
			self.tcY = -1;
			self.tcOverlay:setPosition(self.tcOverlay.x, -1);
		else
			self.tcY = self.cp.ThreshingCounterOrigPosY[1];
			self.tcOverlay:setPosition(self.tcOverlay.x, self.cp.ThreshingCounterOrigPosY[2]);
		end;
	end;


	--set Odometer
	if self.cp.OdometerOrigPosY == nil and open and self.Odometer ~= nil and self.Odometer.HUD ~= nil then
		if self.Odometer.posX ~= nil and self.Odometer.posY ~= nil then
			if self.Odometer.posX > courseplay.hud.visibleArea.x1 and self.Odometer.posX < courseplay.hud.visibleArea.x2 and self.Odometer.posY > courseplay.hud.visibleArea.y1 and self.Odometer.posY < courseplay.hud.visibleArea.y2 then
			--if courseplay:numberInSpan(self.Odometer.posX, courseplay.hud.visibleArea.x1, courseplay.hud.visibleArea.x2) and courseplay:numberInSpan(self.Odometer.posY, courseplay.hud.visibleArea.y1, courseplay.hud.visibleArea.y2) then
				self.cp.OdometerOrigPosY = { 
					self.Odometer.posY,
					self.Odometer.HUD.y,
				};
			end;
		end;
	end;

	--hide/show Odometer
	if self.cp.OdometerOrigPosY ~= nil then
		if open then
			self.Odometer.posY = -1;
			self.Odometer.HUD:setPosition(self.Odometer.HUD.x, -1);
		else
			self.Odometer.posY = self.cp.OdometerOrigPosY[1];
			self.Odometer.HUD:setPosition(self.Odometer.HUD.x, self.cp.OdometerOrigPosY[2]);
		end;
	end;



	--set 4WD/Allrad
	if self.cp.AllradOrigPosY == nil and open and self.AllradV4Active ~= nil and self.hudAllradONOverlay ~= nil and self.hudAllradOFFOverlay ~= nil then
		if self.hudAllradPosX ~= nil and self.hudAllradPosY ~= nil then
			if self.hudAllradPosX > courseplay.hud.visibleArea.x1 and self.hudAllradPosX < courseplay.hud.visibleArea.x2 and self.hudAllradPosY > courseplay.hud.visibleArea.y1 and self.hudAllradPosY < courseplay.hud.visibleArea.y2 then
				self.cp.OdometerOrigPosY = { 
					self.hudAllradPosY,
					self.hudAllradONOverlay.y,
					self.hudAllradOFFOverlay.y,
				};
			end;
		end;
	end;

	--4WD/Allrad
	if self.cp.AllradOrigPosY ~= nil then
		if open then
			self.hudAllradPosY = -1;
			self.hudAllradONOverlay:setPosition(self.hudAllradONOverlay.x, -1);
			self.hudAllradOFFOverlay:setPosition(self.hudAllradOFFOverlay.x, -1);
		else
			self.hudAllradPosY = self.cp.OdometerOrigPosY[1];
			self.hudAllradONOverlay:setPosition(self.hudAllradONOverlay.x, self.cp.OdometerOrigPosY[2]);
			self.hudAllradOFFOverlay:setPosition(self.hudAllradOFFOverlay.x, self.cp.OdometerOrigPosY[3]);
		end;
	end;
end;

function courseplay:change_ai_state(self, change_by)
	self.ai_mode = self.ai_mode + change_by

	if self.ai_mode > courseplay.numAiModes or self.ai_mode == 0 then
		self.ai_mode = 1
	end
	courseplay:buttonsActiveEnabled(self, "all");
end
function courseplay:setAiMode(self, modeNum)
	self.ai_mode = modeNum;
	courseplay:buttonsActiveEnabled(self, "all");
end;

function courseplay:call_player(combine)
	combine.wants_courseplayer = not combine.wants_courseplayer;
end;

function courseplay:start_stop_player(combine)
	local tractor = combine.courseplayers[1];
	tractor.forced_to_stop = not tractor.forced_to_stop;
end;

function courseplay:drive_on(self)
	self.wait = false;
end;

function courseplay:send_player_home(combine)
	local tractor = combine.courseplayers[1];
	tractor.loaded = true;
end

function courseplay:switch_player_side(combine)
	if combine.grainTankCapacity == 0 then
		local tractor = combine.courseplayers[1];
		if tractor == nil then
			return;
		end;

		tractor.ai_state = 10;

		if combine.forced_side == nil then
			combine.forced_side = "left";
		elseif combine.forced_side == "left" then
			combine.forced_side = "right";
		else
			combine.forced_side = nil;
		end;
	end;
end;

function courseplay:setHudPage(self, pageNum)
	if self.ai_mode == nil then
		self.showHudInfoBase = pageNum;
	elseif courseplay.hud.pagesPerMode[self.ai_mode] ~= nil and courseplay.hud.pagesPerMode[self.ai_mode][pageNum+1] then
		if pageNum == 0 then
			if self.cp.minHudPage == 0 or self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader then
				self.showHudInfoBase = pageNum;
			end;
		else
			self.showHudInfoBase = pageNum;
		end;
	end;

	courseplay:buttonsActiveEnabled(self, "all");
end;

function courseplay:switch_hud_page(self, change_by)
	newPage = courseplay:minMaxPage(self, self.showHudInfoBase + change_by);

	if self.ai_mode == nil then
		self.showHudInfoBase = newPage;
	elseif courseplay.hud.pagesPerMode[self.ai_mode] ~= nil then
		while courseplay.hud.pagesPerMode[self.ai_mode][newPage+1] == false do
			newPage = courseplay:minMaxPage(self, newPage + change_by);
		end;
		self.showHudInfoBase = newPage;
	end;

	courseplay:buttonsActiveEnabled(self, "all");
end;

function courseplay:minMaxPage(self, pageNum)
	if pageNum < self.cp.minHudPage then
		pageNum = courseplay.hud.numPages;
	elseif pageNum > courseplay.hud.numPages then
		pageNum = self.cp.minHudPage;
	end;
	return pageNum;
end;

function courseplay:buttonsActiveEnabled(self, section)
	for _,button in pairs(self.cp.buttons) do
		if section == nil or section == "all" or section == "pageNav" then
			if button.function_to_call == "setHudPage" then
				local pageNum = button.parameter;
				button.isActive = pageNum == self.showHudInfoBase;
				
				if self.ai_mode == nil then
					button.isDisabled = false;
				elseif courseplay.hud.pagesPerMode[self.ai_mode] ~= nil and courseplay.hud.pagesPerMode[self.ai_mode][pageNum+1] then
					if pageNum == 0 then
						button.isDisabled = not (self.cp.minHudPage == 0 or self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader);
					else
						button.isDisabled = false;
					end;
				else
					button.isDisabled = true;
				end;
				
				button.canBeClicked = not button.isDisabled and not button.isActive;
			end;
		end;
		
		if section == nil or section == "all" or section == "quickModes" then
			if self.showHudInfoBase == 1 and button.function_to_call == "setAiMode" then
				button.isActive = self.ai_mode == button.parameter;
				button.canBeClicked = not button.isActive;
			end;
		end;

		if section == nil or section == "all" or section == "shovel" then
			if self.showHudInfoBase == 9 and button.function_to_call == "saveShovelStatus" then
				button.isActive = self.cp.shovelStateRot[tostring(button.parameter)] ~= nil;
				button.canBeClicked = true;
			end;
		end;

		if section == nil or section == "all" or section == "debug" then
			if self.showHudInfoBase == 6 and button.function_to_call == "toggleDebugChannel" then
				button.isActive = courseplay.debugChannels[button.parameter] == true;
				button.canBeClicked = true;
				--button.canBeClicked = button.parameter ~= 5;
			end;
		end;
	end;
end;


function courseplay:change_combine_offset(self, change_by)
	local previousOffset = self.combine_offset
	
	self.auto_combine_offset = false
	self.combine_offset = courseplay:round(self.combine_offset, 1) + change_by
	if self.combine_offset < 0.1 and self.combine_offset > -0.1 then
		self.combine_offset = 0.0
		self.auto_combine_offset = true
	end
	
	courseplay:debug(nameNum(self) .. ": manual combine_offset change: prev " .. previousOffset .. " // new " .. self.combine_offset .. " // auto = " .. tostring(self.auto_combine_offset), 4)
end

function courseplay:change_tipper_offset(self, change_by)
	self.tipper_offset = courseplay:round(self.tipper_offset, 1) + change_by
	if self.tipper_offset > -0.1 and self.tipper_offset < 0.1 then
		self.tipper_offset = 0.0
	end
end


function courseplay:changeWpOffsetX(self, change_by)
	self.WpOffsetX = self.WpOffsetX + change_by
end

function courseplay:changeWpOffsetZ(self, change_by)
	self.WpOffsetZ = self.WpOffsetZ + change_by
end

function courseplay:changeWorkWidth(self, change_by)
	if self.toolWorkWidht + change_by > 10 then
		if math.abs(change_by) == 0.1 then
			change_by = 0.5 * Utils.sign(change_by);
		elseif math.abs(change_by) == 0.5 then
			change_by = 2 * Utils.sign(change_by);
		end;
	end;
	self.toolWorkWidht = self.toolWorkWidht + change_by;
	self.workWidthChanged = self.timer + 2000
	if self.toolWorkWidht < 0.1 then
		self.toolWorkWidht = 0.1
	end
end

function courseplay:change_WaypointMode(self, change_by)
	self.waypointMode = self.waypointMode + change_by
	if self.waypointMode == 6 then
		self.waypointMode = 1
	end
	courseplay:RefreshSigns(self)
end


function courseplay:change_required_fill_level_for_drive_on(self, change_by)
	self.required_fill_level_for_drive_on = Utils.clamp(self.required_fill_level_for_drive_on + change_by, 0, 100);
end


function courseplay:change_required_fill_level(self, change_by)
	self.required_fill_level_for_follow = Utils.clamp(self.required_fill_level_for_follow + change_by, 0, 100);
end


function courseplay:change_turn_radius(self, change_by)
	self.turn_radius = self.turn_radius + change_by;
	self.turnRadiusAutoMode = false;

	if self.turn_radius < 0.5 then
		self.turn_radius = 0;
	end;
	
	if self.turn_radius <= 0 then
		self.turnRadiusAutoMode = true;
		self.turn_radius = self.autoTurnRadius
	end;
end


function courseplay:change_turn_speed(self, change_by)
	local speed = self.turn_speed * 3600
	speed = speed + change_by
	if speed < 5 then
		speed = 5
	end
	self.turn_speed = speed / 3600
end

function courseplay:change_wait_time(self, change_by)
	local speed = self.waitTime

	speed = speed + change_by

	if speed < 0 then
		speed = 0
	end
	self.waitTime = speed
end

function courseplay:change_field_speed(self, change_by)
	local speed = self.field_speed * 3600
	speed = speed + change_by
	if speed < 5 then
		speed = 5
	end
	self.field_speed = speed / 3600
end

function courseplay:change_max_speed(self, change_by)
	if not self.use_speed then
		local speed = self.max_speed * 3600;
		speed = speed + change_by;
		if speed < 5 then
			speed = 5;
		end
		self.max_speed = speed / 3600;
	end;
end

function courseplay:change_unload_speed(self, change_by)
	local speed = self.unload_speed * 3600;
	speed = speed + change_by;
	if speed < 3 then
		speed = 3;
	end
	self.unload_speed = speed / 3600;
end

function courseplay:change_RulMode(self, change_by)
	self.RulMode = self.RulMode + change_by
	if self.RulMode == 4 then
		self.RulMode = 1
	end
end

function courseplay:switch_mouse_right_key_enabled(self)
	self.mouse_right_key_enabled = not self.mouse_right_key_enabled
end

function courseplay:switch_search_combine(self)
	self.search_combine = not self.search_combine
end

function courseplay:switch_realistic_driving(self)
	self.realistic_driving = not self.realistic_driving
end


function courseplay:change_use_speed(self)
	self.use_speed = not self.use_speed
end

function courseplay:switch_combine(self, change_by)
	local combines = courseplay:find_combines(self)

	local selected_combine_number = self.selected_combine_number + change_by

	if selected_combine_number < 0 then
		selected_combine_number = 0
	end

	if selected_combine_number > table.getn(combines) then
		selected_combine_number = table.getn(combines)
	end

	self.selected_combine_number = selected_combine_number

	if self.selected_combine_number == 0 then
		self.saved_combine = nil
	else
		self.saved_combine = combines[self.selected_combine_number]
	end
end

function courseplay:switchDriverCopy(self, change_by)
	local drivers = courseplay:findDrivers(self);

	if drivers ~= nil then
		local selectedDriverNumber = self.cp.selectedDriverNumber + change_by;
		self.cp.selectedDriverNumber = Utils.clamp(selectedDriverNumber, 0, table.getn(drivers));

		if self.cp.selectedDriverNumber == 0 then
			self.cp.copyCourseFromDriver = nil;
			self.cp.hasFoundCopyDriver = false;
		else
			self.cp.copyCourseFromDriver = drivers[self.cp.selectedDriverNumber];
			self.cp.hasFoundCopyDriver = true;
		end;
	else
		self.cp.copyCourseFromDriver = nil;
		self.cp.selectedDriverNumber = 0;
		self.cp.hasFoundCopyDriver = false;
	end;
end;

function courseplay:findDrivers(self)
	local foundDrivers = {}; -- resetting all drivers
	local all_vehicles = g_currentMission.vehicles -- go through all vehicles that have a course -- TODO: only check courseplayers
	for k, vehicle in pairs(all_vehicles) do
		if vehicle.Waypoints ~= nil then
			if vehicle.rootNode ~= self.rootNode and table.getn(vehicle.Waypoints) > 0 then
				table.insert(foundDrivers, vehicle);
			end;
		end;
	end;

	return foundDrivers;
end;

function courseplay:copyCourse(self)
	if self.cp.hasFoundCopyDriver ~= nil and self.cp.copyCourseFromDriver ~= nil then
		local src = self.cp.copyCourseFromDriver;
		
		self.Waypoints = src.Waypoints;
		self.current_course_name = src.current_course_name;
		self.loaded_courses = src.loaded_courses;
		self.numCourses = src.numCourses;
		self.recordnumber = 1;
		self.maxnumber = table.getn(self.Waypoints);

		self.record = false;
		self.record_pause = false;
		self.drive = false;
		self.dcheck = false;
		self.play = true;
		self.back = false;
		self.abortWork = nil;

		self.target_x, self.target_y, self.target_z = nil, nil, nil;
		if self.active_combine ~= nil then
			courseplay:unregister_at_combine(self, self.active_combine);
		end
		
		self.ai_state = 1;
		self.tmr = 1;

		courseplay:RefreshSigns(self);
		
		--reset variables
		self.cp.selectedDriverNumber = 0;
		self.cp.hasFoundCopyDriver = false;
		self.cp.copyCourseFromDriver = nil;
		
		courseplay:validateCanSwitchMode(self);
	end;
end;

function courseplay:change_selected_course(self, change_by)

	local selected_course_number = self.selected_course_number
	selected_course_number = selected_course_number + change_by

	self.cp.courseListPrev = true;
	self.cp.courseListNext = true;

	local number_of_courses = table.getn(g_currentMission.courseplay_courses);

	if selected_course_number >= number_of_courses - (courseplay.hud.numLines - 1) then
		selected_course_number = number_of_courses - courseplay.hud.numLines;
	end

	if selected_course_number < 0 then
		selected_course_number = 0
	end
	
	if selected_course_number == 0 then 
		self.cp.courseListPrev = false;
	end;
	if selected_course_number == (number_of_courses - courseplay.hud.numLines) then
		self.cp.courseListNext = false;
	end;

	self.selected_course_number = selected_course_number
end

function courseplay:change_num_ai_helpers(self, change_by)
	local num_helpers = g_currentMission.maxNumHirables
	num_helpers = num_helpers + change_by

	if num_helpers < 1 then
		num_helpers = 1
	end

	g_currentMission.maxNumHirables = num_helpers
end

function courseplay:change_DebugLevel(self, change_by)
	courseplay.debugLevel = courseplay.debugLevel + change_by;
	if courseplay.debugLevel > 4 then
		courseplay.debugLevel = 0;
	end;
end;

function courseplay:toggleDebugChannel(self, channel)
	if courseplay.debugChannels[channel] ~= nil then
		courseplay.debugChannels[channel] = not courseplay.debugChannels[channel];
		courseplay:buttonsActiveEnabled(self, "debug");
	end;
end;

--Course generation
function courseplay:switchStartingCorner(self)
	self.cp.startingCorner = self.cp.startingCorner + 1;
	if self.cp.startingCorner > 4 then
		self.cp.startingCorner = 1;
	end;
	self.cp.hasStartingCorner = true;
	self.cp.hasStartingDirection = false;
	self.cp.startingDirection = 0;

	courseplay:validateCourseGenerationData(self);
end;

function courseplay:switchStartingDirection(self)
	-- corners: 1 = SW, 2 = NW, 3 = NE, 4 = SE
	-- directions: 1 = North, 2 = East, 3 = South, 4 = West

	local validDirections = {};
	if self.cp.hasStartingCorner then
		if self.cp.startingCorner == 1 then --SW
			validDirections[1] = 1; --N
			validDirections[2] = 2; --E
		elseif self.cp.startingCorner == 2 then --NW
			validDirections[1] = 2; --E
			validDirections[2] = 3; --S
		elseif self.cp.startingCorner == 3 then --NE
			validDirections[1] = 3; --S
			validDirections[2] = 4; --W
		elseif self.cp.startingCorner == 4 then --SE
			validDirections[1] = 4; --W
			validDirections[2] = 1; --N
		end;

		--would be easier with i=i+1, but more stored variables would be needed
		if self.cp.startingDirection == 0 then
			self.cp.startingDirection = validDirections[1];
		elseif self.cp.startingDirection == validDirections[1] then
			self.cp.startingDirection = validDirections[2];
		elseif self.cp.startingDirection == validDirections[2] then
			self.cp.startingDirection = validDirections[1];
		end;
		self.cp.hasStartingDirection = true;
	end;
	
	courseplay:validateCourseGenerationData(self);
end;

function courseplay:switchReturnToFirstPoint(self)
	self.cp.returnToFirstPoint = not self.cp.returnToFirstPoint;
end;

function courseplay:setHeadlandLanes(self, change_by)
	self.cp.headland.numLanes = Utils.clamp(self.cp.headland.numLanes + change_by, -1, 1);
	courseplay:validateCourseGenerationData(self);
end;

function courseplay:validateCourseGenerationData(self)
	local hasEnoughWaypoints = table.getn(self.Waypoints) > 4;
	if self.cp.headland.numLanes ~= 0 then
		hasEnoughWaypoints = table.getn(self.Waypoints) >= 20;
	end;

	if not self.cp.hasGeneratedCourse
	and self.Waypoints ~= nil 
	and hasEnoughWaypoints
	and self.cp.hasStartingCorner == true 
	and self.cp.hasStartingDirection == true 
	and (self.numCourses == nil or (self.numCourses ~= nil and self.numCourses == 1)) 
	then
		self.cp.hasValidCourseGenerationData = true;
	else
		self.cp.hasValidCourseGenerationData = false;
	end;

	courseplay:debug(string.format("%s: hasGeneratedCourse=%s, #Waypoints=%s, hasStartingCorner=%s, hasStartingDirection=%s, numCourses=%s ==> hasValidCourseGenerationData=%s", nameNum(self), tostring(self.cp.hasGeneratedCourse), tostring(#self.Waypoints), tostring(self.cp.hasStartingCorner), tostring(self.cp.hasStartingDirection), tostring(self.numCourses), tostring(self.cp.hasValidCourseGenerationData)), 7);
end;

function courseplay:validateCanSwitchMode(self)
	self.cp.canSwitchMode = self.play and not self.drive and not self.record and not self.record_pause and (self.Waypoints ~= nil and table.getn(self.Waypoints) ~= 0);
	if self.Waypoints ~= nil then
		courseplay:debug(string.format("%s: validateCanSwitchMode(): play=%s, drive=%s, record=%s, record_pause=%s, #Waypoints=%s ==> canSwitchMode=%s", nameNum(self), tostring(self.play), tostring(self.drive), tostring(self.record), tostring(self.record_pause), tostring(table.getn(self.Waypoints)), tostring(self.cp.canSwitchMode)), 12);
	else
		courseplay:debug(string.format("%s: validateCanSwitchMode(): play=%s, drive=%s, record=%s, record_pause=%s, Waypoints=nil ==> canSwitchMode=%s", nameNum(self), tostring(self.play), tostring(self.drive), tostring(self.record), tostring(self.record_pause), tostring(self.cp.canSwitchMode)), 12);
	end;
end;

function courseplay:saveShovelStatus(self, stage)
	if stage == nil then
		return;
	end;
	
	local mt, secondary = courseplay:getMovingTools(self)

	if stage >= 2 and stage <= 5 then
		self.cp.shovelStateRot[tostring(stage)] = courseplay:getCurrentRotation(self, mt, secondary);
	end;
	courseplay:buttonsActiveEnabled(self, "shovel");
end;

function courseplay:setShovelStopAndGo(self)
	self.cp.shovelStopAndGo = not self.cp.shovelStopAndGo;
end;

function courseplay:setStartAtFirstPoint(self)
	self.cp.startAtFirstPoint = not self.cp.startAtFirstPoint;
end;