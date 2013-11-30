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

function courseplay:setAiMode(vehicle, modeNum)
	vehicle.cp.mode = modeNum;
	courseplay:buttonsActiveEnabled(vehicle, "all");
end;

function courseplay:call_player(combine)
	combine.wants_courseplayer = not combine.wants_courseplayer;
end;

function courseplay:start_stop_player(combine)
	local tractor = combine.courseplayers[1];
	tractor.cp.forcedToStop = not tractor.cp.forcedToStop;
end;

function courseplay:driveOn(vehicle, cancelStopAtEnd)
	if vehicle.wait then
		vehicle.wait = false;
	end;
	if vehicle.cp.mode == 3 then
		vehicle.cp.isUnloaded = true;
	end;
	if cancelStopAtEnd then
		courseplay:setStopAtEnd(vehicle, false);
	end;
end;

function courseplay:setStopAtEnd(vehicle, bool)
	vehicle.cp.stopAtEnd = bool;
end;

function courseplay:setIsLoaded(vehicle, bool)
	vehicle.cp.isLoaded = bool;
end;

function courseplay:send_player_home(combine)
	local tractor = combine.courseplayers[1];
	tractor.cp.isLoaded = true;
end

function courseplay:switch_player_side(combine)
	if combine.grainTankCapacity == 0 then
		local tractor = combine.courseplayers[1];
		if tractor == nil then
			return;
		end;

		tractor.cp.modeState = 10;

		if combine.cp.forcedSide == nil then
			combine.cp.forcedSide = "left";
		elseif combine.cp.forcedSide == "left" then
			combine.cp.forcedSide = "right";
		else
			combine.cp.forcedSide = nil;
		end;
	end;
end;

function courseplay:setHudPage(self, pageNum)
	if self.cp.mode == nil then
		self.cp.hud.currentPage = pageNum;
	elseif courseplay.hud.pagesPerMode[self.cp.mode] ~= nil and courseplay.hud.pagesPerMode[self.cp.mode][pageNum+1] then
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

	if self.cp.mode == nil then
		self.cp.hud.currentPage = newPage;
	elseif courseplay.hud.pagesPerMode[self.cp.mode] ~= nil then
		while courseplay.hud.pagesPerMode[self.cp.mode][newPage+1] == false do
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

				if self.cp.mode == nil then
					button.isDisabled = false;
				elseif courseplay.hud.pagesPerMode[self.cp.mode] ~= nil and courseplay.hud.pagesPerMode[self.cp.mode][pageNum+1] then
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


	if self.cp.hud.currentPage == 1 and (section == nil or section == "all" or section == "quickModes" or section == "customFieldShow") then
		for _,button in pairs(self.cp.buttons["1"]) do
			if button.function_to_call == "setAiMode" then
				button.isActive = self.cp.mode == button.parameter;
				button.isDisabled = button.parameter == 7 and not self.cp.isCombine and not self.cp.isChopper and not self.cp.isHarvesterSteerable;
				button.canBeClicked = not button.isDisabled and not button.isActive;
			elseif button.function_to_call == "toggleCustomFieldEdgePathShow" then
				button.isActive = self.cp.fieldEdge.customField.show;
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

	elseif self.cp.hud.currentPage == 8 and (section == nil or section == "all" or section == "selectedFieldShow") then
		for _,button in pairs(self.cp.buttons["8"]) do
			if button.function_to_call == "toggleSelectedFieldEdgePathShow" then
				button.isActive = self.cp.fieldEdge.selectedField.show;
				break;
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
	local previousOffset = self.cp.combineOffset

	self.cp.combineOffsetAutoMode = false
	self.cp.combineOffset = courseplay:round(self.cp.combineOffset, 1) + change_by
	if self.cp.combineOffset < 0.1 and self.cp.combineOffset > -0.1 then
		self.cp.combineOffset = 0.0
		self.cp.combineOffsetAutoMode = true
	end

	courseplay:debug(nameNum(self) .. ": manual combine_offset change: prev " .. previousOffset .. " // new " .. self.cp.combineOffset .. " // auto = " .. tostring(self.cp.combineOffsetAutoMode), 4)
end

function courseplay:change_tipper_offset(self, change_by)
	self.cp.tipperOffset = courseplay:round(self.cp.tipperOffset, 1) + change_by
	if self.cp.tipperOffset > -0.1 and self.cp.tipperOffset < 0.1 then
		self.cp.tipperOffset = 0.0
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
	if not noDraw and vehicle.cp.mode ~= 3 and vehicle.cp.mode ~= 7 then
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
	self.cp.driveOnAtFillLevel = Utils.clamp(self.cp.driveOnAtFillLevel + change_by, 0, 100);
end


function courseplay:change_required_fill_level(self, change_by)
	self.cp.followAtFillLevel = Utils.clamp(self.cp.followAtFillLevel + change_by, 0, 100);
end


function courseplay:changeTurnRadius(vehicle, changeBy)
	vehicle.cp.turnRadius = vehicle.cp.turnRadius + changeBy;
	vehicle.cp.turnRadiusAutoMode = false;

	if vehicle.cp.turnRadius < 0.5 then
		vehicle.cp.turnRadius = 0;
	end;

	if vehicle.cp.turnRadius <= 0 then
		vehicle.cp.turnRadiusAutoMode = true;
		vehicle.cp.turnRadius = vehicle.cp.turnRadiusAuto
	end;
end


function courseplay:change_turn_speed(self, change_by)
	local speed = self.cp.speeds.turn * 3600;
	speed = Utils.clamp(speed + change_by, 5, 60);
	self.cp.speeds.turn = speed / 3600;
end

function courseplay:changeWaitTime(vehicle, changeBy)
	vehicle.cp.waitTime = math.max(0, vehicle.cp.waitTime + changeBy);
end

function courseplay:change_field_speed(self, change_by)
	local speed = self.cp.speeds.field * 3600;
	speed = Utils.clamp(speed + change_by, 5, 60);
	self.cp.speeds.field = speed / 3600;
end

function courseplay:change_max_speed(self, change_by)
	if not self.cp.speeds.useRecordingSpeed then
		local speed = self.cp.speeds.max * 3600;
		speed = Utils.clamp(speed + change_by, 5, 60);
		self.cp.speeds.max = speed / 3600;
	end;
end

function courseplay:change_unload_speed(self, change_by)
	local speed = self.cp.speeds.unload * 3600;
	speed = Utils.clamp(speed + change_by, 3, 60);
	self.cp.speeds.unload = speed / 3600;
end

function courseplay:change_use_speed(self)
	self.cp.speeds.useRecordingSpeed = not self.cp.speeds.useRecordingSpeed
end

function courseplay:changeBeaconLightsMode(vehicle, changeBy)
	vehicle.cp.beaconLightsMode = vehicle.cp.beaconLightsMode + changeBy;
	if vehicle.cp.beaconLightsMode == 4 then
		vehicle.cp.beaconLightsMode = 1;
	end;
end;

function courseplay:toggleOpenHudWithMouse(vehicle)
	vehicle.cp.hud.openWithMouse = not vehicle.cp.hud.openWithMouse;
end;

function courseplay:switch_search_combine(self)
	self.search_combine = not self.search_combine
end

function courseplay:toggleRealisticDriving(vehicle)
	vehicle.cp.realisticDriving = not vehicle.cp.realisticDriving;
end;

function courseplay:switch_combine(vehicle, change_by)
	local combines = courseplay:find_combines(vehicle);
	vehicle.selected_combine_number = Utils.clamp(vehicle.selected_combine_number + change_by, 0, #combines);

	if vehicle.selected_combine_number == 0 then
		vehicle.cp.savedCombine = nil;
	else
		vehicle.cp.savedCombine = combines[vehicle.selected_combine_number];
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
		self.cp.currentCourseName = src.cp.currentCourseName;
		self.cp.loadedCourses = src.cp.loadedCourses;
		self.numCourses = src.numCourses;
		self.recordnumber = 1;
		self.maxnumber = table.getn(self.Waypoints);

		self.record = false;
		self.record_pause = false;
		self.drive = false;
		self.dcheck = false;
		self.cp.canDrive = true;
		self.cp.abortWork = nil;

		self.target_x, self.target_y, self.target_z = nil, nil, nil;
		if self.cp.activeCombine ~= nil then
			courseplay:unregister_at_combine(self, self.cp.activeCombine);
		end

		self.cp.modeState = 1;
		self.cp.recordingTimer = 1;

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
	
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		numWaypoints = #(courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points);
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

	if (vehicle.cp.fieldEdge.selectedField.fieldNum > 0 or not vehicle.cp.hasGeneratedCourse)
	and hasEnoughWaypoints
	and vehicle.cp.hasStartingCorner == true 
	and vehicle.cp.hasStartingDirection == true 
	and (vehicle.numCourses == nil or (vehicle.numCourses ~= nil and vehicle.numCourses == 1) or vehicle.cp.fieldEdge.selectedField.fieldNum > 0) 
	then
		vehicle.cp.hasValidCourseGenerationData = true;
	else
		vehicle.cp.hasValidCourseGenerationData = false;
	end;

	courseplay:debug(string.format("%s: hasGeneratedCourse=%s, hasEnoughWaypoints=%s, hasStartingCorner=%s, hasStartingDirection=%s, numCourses=%s, fieldEdge.selectedField.fieldNum=%s ==> hasValidCourseGenerationData=%s", nameNum(vehicle), tostring(vehicle.cp.hasGeneratedCourse), tostring(hasEnoughWaypoints), tostring(vehicle.cp.hasStartingCorner), tostring(vehicle.cp.hasStartingDirection), tostring(vehicle.numCourses), tostring(vehicle.cp.fieldEdge.selectedField.fieldNum), tostring(vehicle.cp.hasValidCourseGenerationData)), 7);
end;

function courseplay:validateCanSwitchMode(vehicle)
	vehicle.cp.canSwitchMode = not vehicle.drive and not vehicle.record and not vehicle.record_pause and not vehicle.cp.fieldEdge.customField.isCreated;
	courseplay:debug(string.format("%s: validateCanSwitchMode(): play=%s, drive=%s, record=%s, record_pause=%s, customField.isCreated=%s ==> canSwitchMode=%s", nameNum(vehicle), tostring(vehicle.cp.canDrive), tostring(vehicle.drive), tostring(vehicle.record), tostring(vehicle.record_pause), tostring(vehicle.cp.fieldEdge.customField.isCreated), tostring(vehicle.cp.canSwitchMode)), 12);
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
			local loadedCoursesBackup = self.cp.loadedCourses;
			courseplay:reset_course(self);
			self.cp.loadedCourses = loadedCoursesBackup;
			courseplay:reload_courses(self, true);
			courseplay:debug("courseplay:reload_courses(self, true)", 8);
		end;
		courseplay.settings.update_folders()
		courseplay.settings.setReloadCourseItems()
		--courseplay.hud.reloadCourses()
	end
end;

function courseplay:setMouseCursor(self, show)
	self.cp.mouseCursorActive = show;
	InputBinding.setShowMouseCursor(show);

	--Cameras: deactivate/reactivate zoom function in order to allow CP mouse wheel
	for camIndex,_ in pairs(self.cp.camerasBackup) do
		self.cameras[camIndex].allowTranslation = not show;
		--print(string.format("%s: right mouse key (mouse cursor=%s): camera %d allowTranslation=%s", nameNum(self), tostring(self.cp.mouseCursorActive), camIndex, tostring(self.cameras[camIndex].allowTranslation)));
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
	InputBinding.setShowMouseCursor(targetVehicle.cp.mouseCursorActive);
end;



--FIELD EDGE PATHS
function courseplay:createFieldEdgeButtons(vehicle)
	if not vehicle.cp.fieldEdge.selectedField.buttonsCreated and courseplay.fields.numAvailableFields > 0 then
		local w16px, h16px = 16/1920, 16/1080;
		local mouseWheelArea = {
			x = courseplay.hud.infoBasePosX + 0.005,
			w = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1 - (2 * 0.005),
			h = courseplay.hud.lineHeight
		};
		courseplay:register_button(vehicle, 8, "eye.png", "toggleSelectedFieldEdgePathShow", nil, courseplay.hud.infoBasePosX + 0.270, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, nil, false);
		courseplay:register_button(vehicle, 8, "navigate_up.png",   "setFieldEdgePath", -1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -5, false);
		courseplay:register_button(vehicle, 8, "navigate_down.png", "setFieldEdgePath",  1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  5, false);
		courseplay:register_button(vehicle, 8, nil, "setFieldEdgePath", -1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, -5, true, true);
		vehicle.cp.fieldEdge.selectedField.buttonsCreated = true;
	end;
end;

function courseplay:setFieldEdgePath(vehicle, changeDir, force)
	local newFieldNum = force or vehicle.cp.fieldEdge.selectedField.fieldNum + changeDir;
	if newFieldNum == 0 then
		vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;
		return;
	end;

	while courseplay.fields.fieldData[newFieldNum] == nil do
		if newFieldNum == 0 then
			vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;
			return;
		end;
		newFieldNum = Utils.clamp(newFieldNum + changeDir, 0, courseplay.fields.numAvailableFields);
	end;

	vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;

	--courseplay:toggleSelectedFieldEdgePathShow(vehicle, false);
	if vehicle.cp.fieldEdge.customField.show then
		courseplay:toggleCustomFieldEdgePathShow(vehicle, false);
	end;
	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:toggleSelectedFieldEdgePathShow(vehicle, force)
	vehicle.cp.fieldEdge.selectedField.show = Utils.getNoNil(force, not vehicle.cp.fieldEdge.selectedField.show);
	--print(string.format("%s: selectedField.show=%s", nameNum(vehicle), tostring(vehicle.cp.fieldEdge.selectedField.show)));
	courseplay:buttonsActiveEnabled(vehicle, "selectedFieldShow");
end;

--CUSTOM SINGLE FIELD EDGE PATH
function courseplay:setCustomSingleFieldEdge(vehicle)
	--print(string.format("%s: call setCustomSingleFieldEdge()", nameNum(vehicle)));

	local x,y,z = getWorldTranslation(vehicle.rootNode);
	vehicle.cp.fieldEdge.customField.points = nil;
	local numDirectionTries = 10;
	if x and z and courseplay:is_field(x, z) then
		for try=1,numDirectionTries do
			local edgePoints = courseplay.fields:getSingleFieldEdge(vehicle.rootNode, 5, 2000, try > 1);
			if #edgePoints >= 30 then
				vehicle.cp.fieldEdge.customField.points = edgePoints;
				vehicle.cp.fieldEdge.customField.numPoints = #edgePoints;
				--print(string.format("\t\t\tcustom field: >= 30 edge points found --> valid, no retry"));
				break;
			else
				--print(string.format("\t\t\tcustom field: less than 30 edge points found --> not valid, retry=%s", tostring(try<numDirectionTries)));
			end;
		end;
	end;

	--print(tableShow(vehicle.cp.fieldEdge.customField.points, nameNum(vehicle) .. " fieldEdge.customField.points"));
	vehicle.cp.fieldEdge.customField.isCreated = vehicle.cp.fieldEdge.customField.points ~= nil;
	courseplay:toggleCustomFieldEdgePathShow(vehicle, vehicle.cp.fieldEdge.customField.isCreated);
	courseplay:validateCanSwitchMode(vehicle);
end;

function courseplay:clearCustomFieldEdge(vehicle)
	vehicle.cp.fieldEdge.customField.points = nil;
	vehicle.cp.fieldEdge.customField.numPoints = 0;
	vehicle.cp.fieldEdge.customField.isCreated = false;
	courseplay:setCustomFieldEdgePathNumber(vehicle, nil, 0);
	courseplay:toggleCustomFieldEdgePathShow(vehicle, false);
	courseplay:validateCanSwitchMode(vehicle);
end;

function courseplay:toggleCustomFieldEdgePathShow(vehicle, force)
	vehicle.cp.fieldEdge.customField.show = Utils.getNoNil(force, not vehicle.cp.fieldEdge.customField.show);
	--print(string.format("%s: customField.show=%s", nameNum(vehicle), tostring(vehicle.cp.fieldEdge.customField.show)));
	courseplay:buttonsActiveEnabled(vehicle, "customFieldShow");
end;

function courseplay:setCustomFieldEdgePathNumber(vehicle, changeBy, force)
	vehicle.cp.fieldEdge.customField.fieldNum = force or Utils.clamp(vehicle.cp.fieldEdge.customField.fieldNum + changeBy, 0, courseplay.fields.customFieldMaxNum);
	vehicle.cp.fieldEdge.customField.selectedFieldNumExists = courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum] ~= nil;
	--print(string.format("%s: customField.fieldNum=%d, selectedFieldNumExists=%s", nameNum(vehicle), vehicle.cp.fieldEdge.customField.fieldNum, tostring(vehicle.cp.fieldEdge.customField.selectedFieldNumExists)));
end;

function courseplay:addCustomSingleFieldEdgeToList(vehicle)
	--print(string.format("%s: call addCustomSingleFieldEdgeToList()", nameNum(vehicle)));
	courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum] = {
		fieldNum = vehicle.cp.fieldEdge.customField.fieldNum;
		points = vehicle.cp.fieldEdge.customField.points;
		numPoints = vehicle.cp.fieldEdge.customField.numPoints;
		name = string.format("%s %d (%s)", courseplay.locales.COURSEPLAY_FIELD, vehicle.cp.fieldEdge.customField.fieldNum, courseplay.locales.COURSEPLAY_USER);
		isCustom = true;
	};
	courseplay.fields.numAvailableFields = table.maxn(courseplay.fields.fieldData);
	--print(string.format("\tfieldNum=%d, name=%s, #points=%d", courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum].fieldNum, courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum].name, #courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum].points));

	--SAVE TO XML
	courseplay.fields:saveAllCustomFields();

	--RESET
	courseplay:setCustomFieldEdgePathNumber(vehicle, nil, 0);
	courseplay:clearCustomFieldEdge(vehicle);
	courseplay:toggleSelectedFieldEdgePathShow(vehicle, false);
	--print(string.format("\t[AFTER RESET] fieldNum=%d, points=%s, fieldEdge.customField.isCreated=%s", vehicle.cp.fieldEdge.customField.fieldNum, tostring(vehicle.cp.fieldEdge.customField.points), tostring(vehicle.cp.fieldEdge.customField.isCreated)));
end;

function courseplay:showFieldEdgePath(vehicle, pathType)
	local points, numPoints = nil, 0;
	if pathType == "customField" then
		points = vehicle.cp.fieldEdge.customField.points;
		numPoints = vehicle.cp.fieldEdge.customField.numPoints;
	elseif pathType == "selectedField" then
		points = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points;
		numPoints = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].numPoints;
	end;

	if numPoints > 0 then
		local pointHeight = 3;
		for i,point in pairs(points) do
			if i < numPoints then
				local nextPoint = points[i + 1];
				drawDebugLine(point.cx,point.cy+pointHeight,point.cz, 0,0,1, nextPoint.cx,nextPoint.cy+pointHeight,nextPoint.cz, 0,0,1);

				if i == 1 then
					drawDebugPoint(point.cx, point.cy + pointHeight, point.cz, 0,1,0,1);
				else
					drawDebugPoint(point.cx, point.cy + pointHeight, point.cz, 1,1,0,1);
				end;
			else
				drawDebugPoint(point.cx, point.cy + pointHeight, point.cz, 1,0,0,1);
			end;
		end;
	end;
end;