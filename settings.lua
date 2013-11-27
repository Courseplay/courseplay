function courseplay:openCloseHud(self, open)
	courseplay:setMouseCursor(self, open);
	self.cp.hud.show = open;

	--set ESLimiter
	if self.cp.hud.ESLimiterOrigPosY == nil and open and self.ESLimiter ~= nil and self.ESLimiter.xPos ~= nil and self.ESLimiter.yPos ~= nil and self.ESLimiter.overlay ~= nil and self.ESLimiter.overlayBg ~= nil and self.ESLimiter.overlayBar ~= nil then
		if self.ESLimiter.xPos > courseplay.hud.visibleArea.x1 and self.ESLimiter.xPos < courseplay.hud.visibleArea.x2 and self.ESLimiter.yPos > courseplay.hud.visibleArea.y1 and self.ESLimiter.yPos < courseplay.hud.visibleArea.y2 then
			self.cp.hud.ESLimiterOrigPosY = { 
				self.ESLimiter.yPos,
				self.ESLimiter.overlay.y,
				self.ESLimiter.overlayBg.y,
				self.ESLimiter.overlayBar.y
			};
		end;
	end;
	--toggle ESLimiter
	if self.cp.hud.ESLimiterOrigPosY ~= nil then
		if open then
			self.ESLimiter.yPos = -1;
			self.ESLimiter.overlay:setPosition(self.ESLimiter.overlay.x, -1);
			self.ESLimiter.overlayBg:setPosition(self.ESLimiter.overlayBg.x, -1);
			self.ESLimiter.overlayBar:setPosition(self.ESLimiter.overlayBar.x, -1);
		else
			self.ESLimiter.yPos = self.cp.hud.ESLimiterOrigPosY[1];
			self.ESLimiter.overlay:setPosition(self.ESLimiter.overlay.x, self.cp.hud.ESLimiterOrigPosY[2]);
			self.ESLimiter.overlayBg:setPosition(self.ESLimiter.overlayBg.x, self.cp.hud.ESLimiterOrigPosY[3]);
			self.ESLimiter.overlayBar:setPosition(self.ESLimiter.overlayBar.x, self.cp.hud.ESLimiterOrigPosY[4]);
		end;
	end;


	--set ThreshingCounter
	local isManualThreshingCounter = self.sessionHectars ~= nil and self.tcOverlay ~= nil and self.tcX ~= nil and self.tcY ~= nil;
	local isGlobalThreshingCounter = self.ThreshingCounter ~= nil and self.tcOverlay ~= nil and self.xPos ~= nil and self.yPos ~= nil;
	if self.cp.hud.ThreshingCounterOrigPosY == nil and open and (isManualThreshingCounter or isGlobalThreshingCounter) then
		local x, y = nil, nil;
		if isManualThreshingCounter then
			x, y = self.tcX, self.tcY;
		elseif isGlobalThreshingCounter then
			x, y = self.xPos, self.yPos;
		end;
		if x and y and x > courseplay.hud.visibleArea.x1 and x < courseplay.hud.visibleArea.x2 and y > courseplay.hud.visibleArea.y1 and y < courseplay.hud.visibleArea.y2 then
			self.cp.hud.ThreshingCounterOrigPosY = { 
				y,
				self.tcOverlay.y,
			};
		end;
	end;
	--toggle ThreshingCounter
	if self.cp.hud.ThreshingCounterOrigPosY ~= nil then
		if isManualThreshingCounter then
			if open then
				self.tcY = -1;
				self.tcOverlay:setPosition(self.tcOverlay.x, -1);
			else
				self.tcY = self.cp.hud.ThreshingCounterOrigPosY[1];
				self.tcOverlay:setPosition(self.tcOverlay.x, self.cp.hud.ThreshingCounterOrigPosY[2]);
			end;
		elseif isGlobalThreshingCounter then
			if open then
				self.yPos = -1;
				self.tcOverlay:setPosition(self.tcOverlay.x, -1);
			else
				self.yPos = self.cp.hud.ThreshingCounterOrigPosY[1];
				self.tcOverlay:setPosition(self.tcOverlay.x, self.cp.hud.ThreshingCounterOrigPosY[2]);
			end;
		end;
	end;


	--set Odometer
	if self.cp.hud.OdometerOrigPosY == nil and open and self.Odometer ~= nil and self.Odometer.HUD ~= nil and self.Odometer.posX ~= nil and self.Odometer.posY ~= nil then
		if self.Odometer.posX > courseplay.hud.visibleArea.x1 and self.Odometer.posX < courseplay.hud.visibleArea.x2 and self.Odometer.posY > courseplay.hud.visibleArea.y1 and self.Odometer.posY < courseplay.hud.visibleArea.y2 then
		--if courseplay:numberInSpan(self.Odometer.posX, courseplay.hud.visibleArea.x1, courseplay.hud.visibleArea.x2) and courseplay:numberInSpan(self.Odometer.posY, courseplay.hud.visibleArea.y1, courseplay.hud.visibleArea.y2) then
			self.cp.hud.OdometerOrigPosY = { 
				self.Odometer.posY,
				self.Odometer.HUD.y,
			};
		end;
	end;
	--toggle Odometer
	if self.cp.hud.OdometerOrigPosY ~= nil then
		if open then
			self.Odometer.posY = -1;
			self.Odometer.HUD:setPosition(self.Odometer.HUD.x, -1);
		else
			self.Odometer.posY = self.cp.hud.OdometerOrigPosY[1];
			self.Odometer.HUD:setPosition(self.Odometer.HUD.x, self.cp.hud.OdometerOrigPosY[2]);
		end;
	end;


	--set 4WD/Allrad
	if self.cp.hud.AllradOrigPosY == nil and open and self.AllradV4Active ~= nil and self.hudAllradONOverlay ~= nil and self.hudAllradOFFOverlay ~= nil and self.hudAllradPosX ~= nil and self.hudAllradPosY ~= nil then
		if self.hudAllradPosX > courseplay.hud.visibleArea.x1 and self.hudAllradPosX < courseplay.hud.visibleArea.x2 and self.hudAllradPosY > courseplay.hud.visibleArea.y1 and self.hudAllradPosY < courseplay.hud.visibleArea.y2 then
			self.cp.hud.AllradOrigPosY = { 
				self.hudAllradPosY,
				self.hudAllradONOverlay.y,
				self.hudAllradOFFOverlay.y,
			};
		end;
	end;
	--toggle 4WD/Allrad
	if self.cp.hud.AllradOrigPosY ~= nil then
		if open then
			self.hudAllradPosY = -1;
			self.hudAllradONOverlay:setPosition(self.hudAllradONOverlay.x, -1);
			self.hudAllradOFFOverlay:setPosition(self.hudAllradOFFOverlay.x, -1);
		else
			self.hudAllradPosY = self.cp.hud.AllradOrigPosY[1];
			self.hudAllradONOverlay:setPosition(self.hudAllradONOverlay.x, self.cp.hud.AllradOrigPosY[2]);
			self.hudAllradOFFOverlay:setPosition(self.hudAllradOFFOverlay.x, self.cp.hud.AllradOrigPosY[3]);
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
	if self.wait then
		self.wait = false;
	end;
	if self.StopEnd then
		self.StopEnd = false;
	end;
end;

function courseplay:setIsLoaded(vehicle, bool)
	vehicle.loaded = bool;
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
		self.cp.hud.currentPage = pageNum;
	elseif courseplay.hud.pagesPerMode[self.ai_mode] ~= nil and courseplay.hud.pagesPerMode[self.ai_mode][pageNum+1] then
		if pageNum == 0 then
			if self.cp.minHudPage == 0 or self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader then
				self.cp.hud.currentPage = pageNum;
			end;
		else
			self.cp.hud.currentPage = pageNum;
		end;
	end;

	courseplay:buttonsActiveEnabled(self, "all");
end;

function courseplay:switch_hud_page(self, change_by)
	newPage = courseplay:minMaxPage(self, self.cp.hud.currentPage + change_by);

	if self.ai_mode == nil then
		self.cp.hud.currentPage = newPage;
	elseif courseplay.hud.pagesPerMode[self.ai_mode] ~= nil then
		while courseplay.hud.pagesPerMode[self.ai_mode][newPage+1] == false do
			newPage = courseplay:minMaxPage(self, newPage + change_by);
		end;
		self.cp.hud.currentPage = newPage;
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
	if section == nil or section == "all" or section == "pageNav" then
		for _,button in pairs(self.cp.buttons.global) do
			if button.function_to_call == "setHudPage" then
				local pageNum = button.parameter;
				button.isActive = pageNum == self.cp.hud.currentPage;

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
	end;


	if self.cp.hud.currentPage == 1 and (section == nil or section == "all" or section == "quickModes") then
		for _,button in pairs(self.cp.buttons["1"]) do
			if button.function_to_call == "setAiMode" then
				button.isActive = self.ai_mode == button.parameter;
				button.isDisabled = button.parameter == 7 and not self.cp.isCombine and not self.cp.isChopper and not self.cp.isHarvesterSteerable;
				button.canBeClicked = not button.isDisabled and not button.isActive;
			end;
		end;
		
	elseif self.cp.hud.currentPage == 2 and section == 'page2' then
		local enable, hide = true, false
		local n_courses = #(self.cp.hud.courses)
		local nofolders = nil == next(g_currentMission.cp_folders);
		local offset = courseplay.hud.offset  --0.006 (button width)
		local row
		for _, button in pairs(self.cp.buttons['-2']) do
			row = button.row
			enable = true
			hide = false
					
			if row > n_courses then
				hide = true
			else
				if button.function_to_call == "expandFolder" then
					if self.cp.hud.courses[row].type == 'course' then
						hide = true
					else
						-- position the expandFolder buttons
						courseplay.button.setOffset(button, self.cp.hud.courses[row].level * offset, 0)
						
						if self.cp.hud.courses[row].id == 0 then
							hide = true --hide for level 0 "folder"
						else
							-- check if plus or minus should show up
							if self.cp.folder_settings[self.cp.hud.courses[row].id].showChildren then
								courseplay.button.setOverlay(button,2)
							else
								courseplay.button.setOverlay(button,1)
							end
							if g_currentMission.cp_sorted.info[ self.cp.hud.courses[row].uid ].lastChild == 0 then
								enable = false	-- button has no children
							end
						end
					end
				else
					if self.cp.hud.courses[row].type == 'folder' and (button.function_to_call == "load_sorted_course" or button.function_to_call == "add_sorted_course") then
						hide = true
					elseif self.cp.hud.choose_parent ~= true then
						if button.function_to_call == 'delete_sorted_item' and self.cp.hud.courses[row].type == 'folder' and g_currentMission.cp_sorted.info[ self.cp.hud.courses[row].uid ].lastChild ~= 0 then
							enable = false
						elseif button.function_to_call == 'link_parent' then
							courseplay.button.setOverlay(button, 1);
							if nofolders then
								enable = false;
							end;
						end
					else
						if button.function_to_call ~= 'link_parent' then
							enable = false
						else
							courseplay.button.setOverlay(button, 2);
						end
					end
				end
			end
			
			button.isDisabled = (not enable) or hide
			button.isHidden = hide
		end -- for buttons
		courseplay.settings.validateCourseListArrows(self)

	elseif self.cp.hud.currentPage == 6 and (section == nil or section == "all" or section == "debug") then
		for _,button in pairs(self.cp.buttons["6"]) do
			if button.function_to_call == "toggleDebugChannel" then
				button.isDisabled = button.parameter > courseplay.numDebugChannels;
				button.isActive = courseplay.debugChannels[button.parameter] == true;
				button.canBeClicked = not button.isDisabled;
			end;
		end;

	elseif self.cp.hud.currentPage == 9 and (section == nil or section == "all" or section == "shovel") then
		for _,button in pairs(self.cp.buttons["9"]) do
			if button.function_to_call == "saveShovelStatus" then
				button.isActive = self.cp.shovelStateRot[tostring(button.parameter)] ~= nil;
				button.canBeClicked = true;
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

function courseplay:changeLaneOffset(vehicle, changeBy, force)
	vehicle.cp.laneOffset = force or (vehicle.cp.laneOffset + changeBy);
	if math.abs(vehicle.cp.laneOffset) < 0.1 then
		vehicle.cp.laneOffset = 0.0;
	end;
	vehicle.cp.totalOffsetX = vehicle.cp.laneOffset + vehicle.cp.toolOffsetX;
end;

function courseplay:changeToolOffsetX(vehicle, changeBy, force, noDraw)
	vehicle.cp.toolOffsetX = force or (vehicle.cp.toolOffsetX + changeBy);
	if math.abs(vehicle.cp.toolOffsetX) < 0.1 then
		vehicle.cp.toolOffsetX = 0.0;
	end;
	vehicle.cp.totalOffsetX = vehicle.cp.laneOffset + vehicle.cp.toolOffsetX;

	noDraw = noDraw or false;
	if not noDraw and vehicle.ai_mode ~= 3 and vehicle.ai_mode ~= 7 then
		courseplay:calculateWorkWidthDisplayPoints(vehicle);
		vehicle.cp.workWidthChanged = vehicle.timer + 2000;
	end
end;

function courseplay:changeToolOffsetZ(vehicle, changeBy, force)
	vehicle.cp.toolOffsetZ = force or (vehicle.cp.toolOffsetZ + changeBy);
	if math.abs(vehicle.cp.toolOffsetZ) < 0.1 then
		vehicle.cp.toolOffsetZ = 0.0;
	end;
end;

function courseplay:changeWorkWidth(vehicle, changeBy)
	if vehicle.cp.workWidth + changeBy > 10 then
		if math.abs(changeBy) == 0.1 then
			changeBy = 0.5 * Utils.sign(changeBy);
		elseif math.abs(changeBy) == 0.5 then
			changeBy = 2 * Utils.sign(changeBy);
		end;
	end;
	vehicle.cp.workWidth = math.max(vehicle.cp.workWidth + changeBy, 0.1);
	courseplay:calculateWorkWidthDisplayPoints(vehicle);
	vehicle.cp.workWidthChanged = vehicle.timer + 2000;
end;

function courseplay:calculateWorkWidthDisplayPoints(vehicle)
	--calculate points for display
	local x, y, z = getWorldTranslation(vehicle.rootNode)
	local left =  (vehicle.cp.workWidth *  0.5) + (vehicle.cp.toolOffsetX or 0);
	local right = (vehicle.cp.workWidth * -0.5) + (vehicle.cp.toolOffsetX or 0);
	local pointLx, pointLy, pointLz = localToWorld(vehicle.rootNode, left,  1, -6);
	local pointRx, pointRy, pointRz = localToWorld(vehicle.rootNode, right, 1, -6);
	vehicle.cp.workWidthDisplayPoints = {
		left =  { x = pointLx; y = pointLy, z = pointLz; };
		right = { x = pointRx; y = pointRy, z = pointRz; };
	};
end;

function courseplay:change_WaypointMode(self, changeBy)
	self.cp.visualWaypointsMode = courseplay:varLoop(self.cp.visualWaypointsMode, changeBy, 4, 1);
	courseplay:setSignsVisibility(self);
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
	local speed = self.turn_speed * 3600;
	speed = Utils.clamp(speed + change_by, 5, 60);
	self.turn_speed = speed / 3600;
end

function courseplay:change_wait_time(self, change_by)
	self.waitTime = math.max(0, self.waitTime + change_by);
end

function courseplay:change_field_speed(self, change_by)
	local speed = self.field_speed * 3600;
	speed = Utils.clamp(speed + change_by, 5, 60);
	self.field_speed = speed / 3600;
end

function courseplay:change_max_speed(self, change_by)
	if not self.use_speed then
		local speed = self.max_speed * 3600;
		speed = Utils.clamp(speed + change_by, 5, 60);
		self.max_speed = speed / 3600;
	end;
end

function courseplay:change_unload_speed(self, change_by)
	local speed = self.unload_speed * 3600;
	speed = Utils.clamp(speed + change_by, 3, 60);
	self.unload_speed = speed / 3600;
end

function courseplay:change_use_speed(self)
	self.use_speed = not self.use_speed
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

function courseplay:switch_combine(vehicle, change_by)
	local combines = courseplay:find_combines(vehicle);
	vehicle.selected_combine_number = Utils.clamp(vehicle.selected_combine_number + change_by, 0, #combines);

	if vehicle.selected_combine_number == 0 then
		vehicle.saved_combine = nil;
	else
		vehicle.saved_combine = combines[vehicle.selected_combine_number];
	end;
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

		courseplay:updateWaypointSigns(self, "current");

		--reset variables
		self.cp.selectedDriverNumber = 0;
		self.cp.hasFoundCopyDriver = false;
		self.cp.copyCourseFromDriver = nil;

		courseplay:validateCanSwitchMode(self);
	end;
end;

function courseplay.settings.add_folder_settings(folder)
	folder.showChildren = false
	folder.skipMe = false
end

function courseplay.settings.add_folder(input1, input2)
-- function might be called like add_folder(vehicle, id) or like add_folder(id)
	local vehicle, id
	
	if input2 ~= nil then
		vehicle = input1
		id = input2
	else
		vehicle = false
		id = input1
	end
	
	if vehicle == false then
	-- no vehicle given -> add folder to all vehicles
		for k,v in pairs(g_currentMission.steerables) do
			if v.cp ~= nil then 		-- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				v.cp.folder_settings[id] = {}
				courseplay.settings.add_folder_settings(v.cp.folder_settings[id])
			end	
		end
	else
	-- vehicle given -> add folder to that vehicle
		vehicle.cp.folder_settings[id] = {}
		courseplay.settings.add_folder_settings(vehicle.cp.folder_settings[id])
	end
end

function courseplay.settings.update_folders(vehicle)
	local old_settings
	
	if vehicle == nil then
	-- no vehicle given -> update all folders in all vehicles
		for k,v in pairs(g_currentMission.steerables) do
			if v.cp ~= nil then 		-- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				old_settings = v.cp.folder_settings
				v.cp.folder_settings = {}
				for _,f in pairs(g_currentMission.cp_folders) do
					if old_settings[f.id] ~= nil then
						v.cp.folder_settings[f.id] = old_settings[f.id]
					else
						v.cp.folder_settings[f.id] = {}
						courseplay.settings.add_folder_settings(v.cp.folder_settings[f.id])
					end
				end
				old_settings = nil
			end	
		end
	else
	-- vehicle given -> update all folders in that vehicle
		old_settings = vehicle.cp.folder_settings
		vehicle.cp.folder_settings = {}
		for _,f in pairs(g_currentMission.cp_folders) do
			if old_settings[f.id] ~= nil then
				vehicle.cp.folder_settings[f.id] = old_settings[f.id]
			else
				vehicle.cp.folder_settings[f.id] = {}
				courseplay.settings.add_folder_settings(vehicle.cp.folder_settings[f.id])
			end
		end
	end
	old_settings = nil
end

function courseplay.settings.setReloadCourseItems(vehicle)
	if vehicle ~= nil then
		vehicle.cp.reloadCourseItems = true
		vehicle.cp.hud.reloadPage[2] = true
	else
		for k,v in pairs(g_currentMission.steerables) do
			if v.cp ~= nil then 		-- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				v.cp.reloadCourseItems = true
				v.cp.hud.reloadPage[2] = true
			end
		end
	end
end

function courseplay.settings.toggleFilter(vehicle, enable)
	if enable and not vehicle.cp.hud.filterEnabled then
		vehicle.cp.sorted = vehicle.cp.filtered;
		vehicle.cp.hud.filterEnabled = true;
	elseif not enable and vehicle.cp.hud.filterEnabled then
		vehicle.cp.filtered = vehicle.cp.sorted;
		vehicle.cp.sorted = g_currentMission.cp_sorted;
		vehicle.cp.hud.filterEnabled = false;
	end;
end;

function courseplay.hud.setCourses(self, start_index)
	start_index = start_index or 1
	if start_index < 1 then 
		start_index = 1
	elseif start_index > #self.cp.sorted.item then
		start_index = #self.cp.sorted.item
	end
	
	-- delete content of hud.courses
	self.cp.hud.courses = {}
	
	local index = start_index
	local hudLines = courseplay.hud.numLines
	local i = 1
	
	if index == 1 and self.cp.hud.showZeroLevelFolder then
		table.insert(self.cp.hud.courses, { id=0, uid=0, name='Level 0', displayname='Level 0', parent=0, type='folder', level=0})
		i = 2	-- = i+1
	end
	
	-- is start_index even showed?
	index = courseplay.courses.getMeOrBestFit(self, index)
	
	if index ~= 0 then
		-- insert first entry
		table.insert(self.cp.hud.courses, self.cp.sorted.item[index])
		i = i+1
		
		-- now search for the next entries
		while i <= hudLines do
			index = courseplay.courses.getNextCourse(self,index)
			if index == 0 then
				-- no next item found: fill table with previous items and abort the loop
				if start_index > 1 then
					-- shift up
					courseplay:shiftHudCourses(self, -(hudLines - i + 1))
				end
				i = hudLines+1 -- abort the loop
			else
				table.insert(self.cp.hud.courses, self.cp.sorted.item[index])
				i = i + 1
			end
		end --while
	end -- i<3
	
	self.cp.hud.reloadPage[2] = true
end

function courseplay.hud.reloadCourses(vehicle)
	local index = 1
	local i = 1
	if vehicle ~= nil then
		while i <= #vehicle.cp.hud.courses and vehicle.cp.sorted.info[ vehicle.cp.hud.courses[i].uid ] == nil do
			i = i + 1
		end		
		if i <= #vehicle.cp.hud.courses then 
			index = vehicle.cp.sorted.info[ vehicle.cp.hud.courses[i].uid ].sorted_index
		end
		courseplay.hud.setCourses(vehicle, index)
	else
		for k,v in pairs(g_currentMission.steerables) do
			if v.cp ~= nil then 		-- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				i = 1
				-- course/folder in the hud might have been deleted -> info no longer available				
				while i <= #v.cp.hud.courses and v.cp.sorted.info[ v.cp.hud.courses[i].uid ] == nil do
					i = i + 1
				end
				if i > #v.cp.hud.courses then
					index = 1
				else
					index = v.cp.sorted.info[ v.cp.hud.courses[i].uid ].sorted_index
				end
				courseplay.hud.setCourses(v,index)
			end
		end
	end
end

function courseplay:shiftHudCourses(vehicle, change_by)	
	local hudLines = courseplay.hud.numLines
	local index = hudLines
	
	while change_by > 0 do
		-- get the index of the last showed item
		index = vehicle.cp.sorted.info[vehicle.cp.hud.courses[#(vehicle.cp.hud.courses)].uid].sorted_index
		
		-- search for the next item
		index = courseplay.courses.getNextCourse(vehicle,index)
		if index == 0 then
			-- there is no next item: abort
			change_by = 0
		else
			if #(vehicle.cp.hud.courses) == hudLines then
				-- remove first entry...
				table.remove(vehicle.cp.hud.courses, 1)
			end
			-- ... and add one at the end
			table.insert(vehicle.cp.hud.courses, vehicle.cp.sorted.item[index])
			change_by = change_by - 1
		end		
	end

	while change_by < 0 do
		-- get the index of the first showed item
		index = vehicle.cp.sorted.info[vehicle.cp.hud.courses[1].uid].sorted_index
		
		-- search reverse for the next item
		index = courseplay.courses.getNextCourse(vehicle, index, true)
		if index == 0 then
			-- there is no next item: abort
			change_by = 0
			
			-- show LevelZeroFolder?
			if vehicle.cp.hud.showZeroLevelFolder then
				if #(vehicle.cp.hud.courses) >= hudLines then
					-- remove last entry...
					table.remove(vehicle.cp.hud.courses)
				end
				table.insert(vehicle.cp.hud.courses, 1, { id=0, uid=0, name='Level 0', displayname='Level 0', parent=0, type='folder', level=0})
			end
			
		else
			if #(vehicle.cp.hud.courses) >= hudLines then
				-- remove last entry...
				table.remove(vehicle.cp.hud.courses)
			end
			-- ... and add one at the beginning:	
			table.insert(vehicle.cp.hud.courses, 1, vehicle.cp.sorted.item[index])
			change_by = change_by + 1
		end		
	end
	
	vehicle.cp.hud.reloadPage[2] = true
end

--Update all vehicles' course list arrow displays
function courseplay.settings.validateCourseListArrows(vehicle)
	local n_courses = #(vehicle.cp.sorted.item)
	local n_hudcourses, prev, next
	
	if vehicle then
		-- update vehicle only
		prev = true
		next = true
		n_hudcourses = #(vehicle.cp.hud.courses)
		if not (n_hudcourses > 0) then
			prev = false
			next = false
		else
			-- update prev
			if vehicle.cp.hud.showZeroLevelFolder then
				if vehicle.cp.hud.courses[1].uid == 0 then
					prev = false
				end
			elseif vehicle.cp.sorted.info[ vehicle.cp.hud.courses[1].uid ].sorted_index == 1 then
				prev = false
			end
			-- update next
			if n_hudcourses < courseplay.hud.numLines then
				next = false
			elseif vehicle.cp.hud.showZeroLevelFolder and vehicle.cp.hud.courses[n_hudcourses].uid == 0 then
				next = false
			elseif 0 == courseplay.courses.getNextCourse(vehicle, vehicle.cp.sorted.info[ vehicle.cp.hud.courses[n_hudcourses].uid ].sorted_index) then
				next = false
			end
		end
		vehicle.cp.hud.courseListPrev = prev
		vehicle.cp.hud.courseListNext = next
	else
		-- update all vehicles
		for k,v in pairs(g_currentMission.steerables) do
			if v.cp ~= nil then 		-- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				prev = true
				next = true
				n_hudcourses = #(v.cp.hud.courses)
				if not (n_hudcourses > 0) then
					prev = false
					next = false
				else
					-- update prev
					if v.cp.hud.showZeroLevelFolder then
						if v.cp.hud.courses[1].uid == 0 then
							prev = false
						end
					elseif v.cp.sorted.info[v.cp.hud.courses[1].uid].sorted_index == 1 then
						prev = false
					end
					-- update next
					if n_hudcourses < coursplay.hud.numLines then
						next = false
					elseif 0 == courseplay.courses.getNextCourse(v, v.cp.sorted.info[v.cp.hud.courses[n_hudcourses].uid].sorted_index) then
						next = false
					end
				end
				v.cp.hud.courseListPrev = prev
				v.cp.hud.courseListNext = next
			end -- if hasSpecialization
		end -- in pairs(steerables)
	end -- if vehicle
end;

function courseplay:expandFolder(vehicle, index)
-- expand/reduce a folder in the hud
	if vehicle.cp.hud.courses[index].type == 'folder' then
		local f = vehicle.cp.folder_settings[ vehicle.cp.hud.courses[index].id ]
		f.showChildren = not f.showChildren
		if f.showChildren then
		-- from not showing to showing -> put it on top to see as much of the content as possible
			courseplay.hud.setCourses(vehicle, vehicle.cp.sorted.info[vehicle.cp.hud.courses[index].uid].sorted_index)
		else
		-- from showing to not showing -> stay where it was
			courseplay.hud.reloadCourses(vehicle)
		end
	end
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

function courseplay:validateCourseGenerationData(vehicle)
	local numWaypoints = 0;
	local hasEnoughWaypoints = false;
	
	if vehicle.cp.selectedFieldEdgePathNumber > 0 then
		numWaypoints = #(courseplay.fields.fieldData[vehicle.cp.selectedFieldEdgePathNumber].points);
		hasEnoughWaypoints = numWaypoints > 4
		if vehicle.cp.headland.numLanes ~= 0 then
			hasEnoughWaypoints = numWaypoints >= 20;
		end;
	elseif vehicle.Waypoints ~= nil then
		numWaypoints = #(vehicle.Waypoints);
		hasEnoughWaypoints = numWaypoints > 4;
		if vehicle.cp.headland.numLanes ~= 0 then
			hasEnoughWaypoints = numWaypoints >= 20;
		end;
	end;

	if (vehicle.cp.selectedFieldEdgePathNumber > 0 or not vehicle.cp.hasGeneratedCourse)
	and hasEnoughWaypoints
	and vehicle.cp.hasStartingCorner == true 
	and vehicle.cp.hasStartingDirection == true 
	and (vehicle.numCourses == nil or (vehicle.numCourses ~= nil and vehicle.numCourses == 1) or vehicle.cp.selectedFieldEdgePathNumber > 0) 
	then
		vehicle.cp.hasValidCourseGenerationData = true;
	else
		vehicle.cp.hasValidCourseGenerationData = false;
	end;

	courseplay:debug(string.format("%s: hasGeneratedCourse=%s, hasEnoughWaypoints=%s, hasStartingCorner=%s, hasStartingDirection=%s, numCourses=%s, selectedFieldEdgePathNumber=%s ==> hasValidCourseGenerationData=%s", nameNum(vehicle), tostring(vehicle.cp.hasGeneratedCourse), tostring(hasEnoughWaypoints), tostring(vehicle.cp.hasStartingCorner), tostring(vehicle.cp.hasStartingDirection), tostring(vehicle.numCourses), tostring(vehicle.cp.selectedFieldEdgePathNumber), tostring(vehicle.cp.hasValidCourseGenerationData)), 7);
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

function courseplay:reloadCoursesFromXML(self)
	courseplay:debug("reloadCoursesFromXML()", 8);
	if g_server ~= nil then
		courseplay_manager:load_courses();
		courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		courseplay:debug("g_currentMission.cp_courses = courseplay_manager:load_courses()", 8);
		if not self.drive then
			local loadedCoursesBackup = self.loaded_courses;
			courseplay:reset_course(self);
			self.loaded_courses = loadedCoursesBackup;
			courseplay:reload_courses(self, true);
			courseplay:debug("courseplay:reload_courses(self, true)", 8);
		end;
		courseplay.settings.update_folders()
		courseplay.settings.setReloadCourseItems()
		--courseplay.hud.reloadCourses()
	end
end;

function courseplay:setFieldEdgePath(vehicle, changeDir)
	--print("setFieldEdgePath()");
	--print("\\___ currentNum = " .. tostring(vehicle.cp.selectedFieldEdgePathNumber));
	local newFieldNum = vehicle.cp.selectedFieldEdgePathNumber + changeDir;
	--print("\\___ newFieldNum = " .. tostring(newFieldNum));

	if newFieldNum == 0 then
		vehicle.cp.selectedFieldEdgePathNumber = newFieldNum;
		return;
	end;

	while courseplay.fields.fieldData[newFieldNum] == nil do
		--print("\\___ courseplay.fields.fieldDefs[newFieldNum] == nil");
		if newFieldNum == 0 then
			vehicle.cp.selectedFieldEdgePathNumber = newFieldNum;
			return;
		end;
		newFieldNum = Utils.clamp(newFieldNum + changeDir, 0, courseplay.fields.numAvailableFields);
		--print("     \\___ newFieldNum = " .. tostring(newFieldNum));
	end;

	vehicle.cp.selectedFieldEdgePathNumber = newFieldNum;
	--print("\\___ vehicle.cp.selectedFieldEdgePathNumber = " .. tostring(newFieldNum));

	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:setMouseCursor(self, show)
	self.mouse_enabled = show;
	InputBinding.setShowMouseCursor(show);

	--Cameras: deactivate/reactivate zoom function in order to allow CP mouse wheel
	for camIndex,_ in pairs(self.cp.camerasBackup) do
		self.cameras[camIndex].allowTranslation = not show;
		--print(string.format("%s: right mouse key (mouse cursor=%s): camera %d allowTranslation=%s", nameNum(self), tostring(self.mouse_enabled), camIndex, tostring(self.cameras[camIndex].allowTranslation)));
	end;

	if not show then
		for i,button in pairs(self.cp.buttons.global) do
			button.isHovered = false;
		end;
		for i,button in pairs(self.cp.buttons[tostring(self.cp.hud.currentPage)]) do
			button.isHovered = false;
		end;
		if self.cp.hud.currentPage == 2 then
			for i,button in pairs(self.cp.buttons["-2"]) do
				button.isHovered = false;
			end;
		end;

		for line=1,courseplay.hud.numLines do
			self.cp.hud.content.pages[self.cp.hud.currentPage][line][1].isHovered = false;
		end;

		self.cp.hud.mouseWheel.render = false;
	end;
end;

function courseplay:changeDebugChannelSection(self, changeBy)
	courseplay.debugChannelSection = Utils.clamp(courseplay.debugChannelSection + changeBy, 1, math.ceil(courseplay.numAvailableDebugChannels / courseplay.numDebugChannelButtonsPerLine));
	courseplay.debugChannelSectionEnd = courseplay.numDebugChannelButtonsPerLine * courseplay.debugChannelSection;
	courseplay.debugChannelSectionStart = courseplay.debugChannelSectionEnd - courseplay.numDebugChannelButtonsPerLine + 1;
end;

function courseplay:toggleSymmetricLaneChange(vehicle, force)
	vehicle.cp.symmetricLaneChange = Utils.getNoNil(force, not vehicle.cp.symmetricLaneChange);
	vehicle.cp.switchLaneOffset = vehicle.cp.symmetricLaneChange;
end;

function courseplay:toggleDriverPriority(combine)
	combine.cp.driverPriorityUseFillLevel = not combine.cp.driverPriorityUseFillLevel;
end;

function courseplay:goToVehicle(curVehicle, targetVehicle)
	--print(string.format("%s: goToVehicle(): targetVehicle=%q", nameNum(curVehicle), nameNum(targetVehicle)));
	g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(targetVehicle, g_settingsNickname));
	g_currentMission.isPlayerFrozen = false;
	courseplay_manager.playerOnFootMouseEnabled = false;
	InputBinding.setShowMouseCursor(targetVehicle.mouse_enabled);
end;


--FIELD EDGE PATHS
function courseplay:createFieldEdgeButtons(vehicle)
	if not vehicle.cp.fieldEdgeButtonsCreated and courseplay.fields.numAvailableFields > 0 then
		local w16px, h16px = 16/1920, 16/1080;
		local mouseWheelArea = {
			x = courseplay.hud.infoBasePosX + 0.005,
			w = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1 - (2 * 0.005),
			h = courseplay.hud.lineHeight
		};
		courseplay:register_button(vehicle, 8, "navigate_up.dds",   "setFieldEdgePath", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -5, false);
		courseplay:register_button(vehicle, 8, "navigate_down.dds", "setFieldEdgePath",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  5, false);
		courseplay:register_button(vehicle, 8, nil, "setFieldEdgePath", -1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, -5, true, true);
		vehicle.cp.fieldEdgeButtonsCreated = true;
	end;
end;

--CUSTOM SINGLE FIELD EDGE PATH
function courseplay:setCustomSingleFieldEdge(vehicle)
	--print(string.format("%s: call setCustomSingleFieldEdge()", nameNum(vehicle)));

	local x,y,z = getWorldTranslation(vehicle.rootNode);
	--print(string.format("\t rootNode x,y,z=%s,%s,%s", tostring(x), tostring(y), tostring(z)));
	vehicle.cp.customSingleFieldEdge = nil;
	local numDirectionTries = 10;
	if x and z and courseplay:is_field(x, z) then
		--print(string.format("\t\tisField=true"));
		for try=1,numDirectionTries do
			local edgePoints = courseplay:getSingleFieldEdge(vehicle.rootNode, 5, 2000, try > 1);
			if #edgePoints >= 30 then
				vehicle.cp.customSingleFieldEdge = edgePoints;
				--print(string.format("\t\t\tcustom field: >= 30 edge points found --> valid, no retry"));
				break;
			else
				--print(string.format("\t\t\tcustom field: less than 30 edge points found --> not valid, retry=%s", tostring(try<numDirectionTries)));
			end;
		end;
	end;

	vehicle.cp.customFieldScanned = vehicle.cp.customSingleFieldEdge ~= nil;
	--print(tableShow(vehicle.cp.customSingleFieldEdge, nameNum(vehicle) .. " customSingleFieldEdge"));
end;

function courseplay:setCustomFieldEdgePathNumber(vehicle, changeBy)
	local newFieldNum = vehicle.cp.customFieldNumber + changeBy;
	if newFieldNum == 0 then
		vehicle.cp.customFieldNumber = newFieldNum;
		return;
	end;
	while courseplay.fields.fieldData[newFieldNum] ~= nil do
		newFieldNum = Utils.clamp(newFieldNum + changeBy, 0, courseplay.fields.customFieldMaxNum);
		if newFieldNum == courseplay.fields.customFieldMaxNum and courseplay.fields.fieldData[newFieldNum] ~= nil then
			vehicle.cp.customFieldNumber = 0;
			return;
		end;
	end;

	vehicle.cp.customFieldNumber = newFieldNum;
end;

function courseplay:addCustomSingleFieldEdgeToList(vehicle)
	--print(string.format("%s: call addCustomSingleFieldEdgeToList()", nameNum(vehicle)));
	courseplay.fields.fieldData[vehicle.cp.customFieldNumber] = {
		fieldNum = vehicle.cp.customFieldNumber;
		points = vehicle.cp.customSingleFieldEdge;
		name = string.format("%s %d", courseplay.locales.COURSEPLAY_FIELD, vehicle.cp.customFieldNumber);
		isCustom = true;
	};
	courseplay.fields.numAvailableFields = #courseplay.fields.fieldData;
	--print(string.format("\tfieldNum=%d, name=%s, #points=%d", courseplay.fields.fieldData[vehicle.cp.customFieldNumber].fieldNum, courseplay.fields.fieldData[vehicle.cp.customFieldNumber].name, #courseplay.fields.fieldData[vehicle.cp.customFieldNumber].points));

	--RESET
	vehicle.cp.customFieldNumber = 0;
	vehicle.cp.customSingleFieldEdge = nil;
	vehicle.cp.customFieldScanned = false;
	--print(string.format("\t[AFTER RESET] fieldNum=%d, points=%s, customFieldScanned=%s", vehicle.cp.customFieldNumber, tostring(vehicle.cp.customSingleFieldEdge), tostring(vehicle.cp.customFieldScanned)));
end;