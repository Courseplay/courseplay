local curFile = 'settings.lua';

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

function courseplay:setCpMode(vehicle, modeNum)
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

function courseplay:setHudPage(vehicle, pageNum)
	if vehicle.cp.mode == nil then
		vehicle.cp.hud.currentPage = pageNum;
	elseif courseplay.hud.pagesPerMode[vehicle.cp.mode] ~= nil and courseplay.hud.pagesPerMode[vehicle.cp.mode][pageNum] then
		if pageNum == 0 then
			if vehicle.cp.minHudPage == 0 or vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader then
				vehicle.cp.hud.currentPage = pageNum;
			end;
		else
			vehicle.cp.hud.currentPage = pageNum;
		end;
	end;

	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);

	courseplay:buttonsActiveEnabled(vehicle, "all");
end;

function courseplay:switch_hud_page(vehicle, changeBy)
	local newPage = courseplay:minMaxPage(vehicle, vehicle.cp.hud.currentPage + changeBy);

	if vehicle.cp.mode == nil then
		vehicle.cp.hud.currentPage = newPage;
	elseif courseplay.hud.pagesPerMode[vehicle.cp.mode] ~= nil then
		while courseplay.hud.pagesPerMode[vehicle.cp.mode][newPage] == false do
			newPage = courseplay:minMaxPage(vehicle, newPage + changeBy);
		end;
		vehicle.cp.hud.currentPage = newPage;
	end;

	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);

	courseplay:buttonsActiveEnabled(vehicle, "all");
end;

function courseplay:minMaxPage(vehicle, pageNum)
	if pageNum < vehicle.cp.minHudPage then
		pageNum = courseplay.hud.numPages;
	elseif pageNum > courseplay.hud.numPages then
		pageNum = vehicle.cp.minHudPage;
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
				elseif courseplay.hud.pagesPerMode[self.cp.mode] ~= nil and courseplay.hud.pagesPerMode[self.cp.mode][pageNum] then
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

	if self.cp.hud.currentPage == 1 and (section == nil or section == "all" or section == "quickModes" or section == "recording" or section == "customFieldShow" or section == 'findFirstWaypoint') then
		for _,button in pairs(self.cp.buttons["1"]) do
			local fn = button.function_to_call;
			if fn == "setCpMode" then
				button.isActive = self.cp.mode == button.parameter;
				button.isDisabled = button.parameter == 7 and not self.cp.isCombine and not self.cp.isChopper and not self.cp.isHarvesterSteerable;
				button.canBeClicked = not button.isDisabled and not button.isActive;
			elseif fn == "toggleCustomFieldEdgePathShow" then
				button.isActive = self.cp.fieldEdge.customField.show;
			elseif fn == 'toggleFindFirstWaypoint' then
				button.isActive = self.cp.distanceCheck;

			elseif fn == 'stop_record' then
				button.isDisabled = self.cp.recordingIsPaused or self.cp.isRecordingTurnManeuver;
				button.canBeClicked = not button.isDisabled;
			elseif fn == 'setRecordingPause' then
				button.isActive = self.cp.recordingIsPaused;
				button.isDisabled = self.cp.HUDrecordnumber < 4 or self.cp.isRecordingTurnManeuver;
				button.canBeClicked = not button.isDisabled;
			elseif fn == 'delete_waypoint' then
				-- NOTE: during recording pause, HUDrecordnumber = recordnumber + 1, that's why <= 5 is used
				button.isDisabled = not self.cp.recordingIsPaused or self.cp.HUDrecordnumber <= 5;
				button.canBeClicked = not button.isDisabled;
			elseif fn == 'set_waitpoint' or fn == 'set_crossing' then
				button.isDisabled = self.cp.recordingIsPaused or self.cp.isRecordingTurnManeuver;
				button.canBeClicked = not button.isDisabled;
			elseif fn == 'setRecordingTurnManeuver' then --isToggleButton
				button.isActive = self.cp.isRecordingTurnManeuver;
				button.isDisabled = self.cp.recordingIsPaused or self.cp.drivingDirReverse;
				button.canBeClicked = not button.isDisabled;
			elseif fn == 'change_DriveDirection' then --isToggleButton
				button.isActive = self.cp.drivingDirReverse;
				button.isDisabled = self.cp.recordingIsPaused or self.cp.isRecordingTurnManeuver;
				button.canBeClicked = not button.isDisabled;
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

	elseif self.cp.hud.currentPage == 8 and (section == nil or section == 'all' or section == 'suc') then
		self.cp.suc.toggleHudButton.isActive = self.cp.suc.active;

	elseif self.cp.hud.currentPage == 9 and (section == nil or section == "all" or section == "shovel") then
		for _,button in pairs(self.cp.buttons["9"]) do
			if button.function_to_call == 'saveShovelPosition' then --isToggleButton
				button.isActive = self.cp.shovelStatePositions[button.parameter] ~= nil;
				button.canBeClicked = true;
			end;
		end;
	end;
end;

function courseplay:changeCombineOffset(vehicle, changeBy)
	local previousOffset = vehicle.cp.combineOffset;

	vehicle.cp.combineOffsetAutoMode = false;
	vehicle.cp.combineOffset = courseplay:round(vehicle.cp.combineOffset, 1) + changeBy;
	if math.abs(vehicle.cp.combineOffset) < 0.1 then
		vehicle.cp.combineOffset = 0.0;
		vehicle.cp.combineOffsetAutoMode = true;
	end;

	courseplay:debug(nameNum(vehicle) .. ": manual combine_offset change: prev " .. previousOffset .. " // new " .. vehicle.cp.combineOffset .. " // auto = " .. tostring(vehicle.cp.combineOffsetAutoMode), 4);
end

function courseplay:changeTipperOffset(vehicle, changeBy)
	vehicle.cp.tipperOffset = courseplay:round(vehicle.cp.tipperOffset, 1) + changeBy;
	if math.abs(vehicle.cp.tipperOffset) < 0.1 then
		vehicle.cp.tipperOffset = 0;
	end;
end

function courseplay:changeLaneOffset(vehicle, changeBy, force)
	vehicle.cp.laneOffset = force or (courseplay:round(vehicle.cp.laneOffset, 1) + changeBy);
	if math.abs(vehicle.cp.laneOffset) < 0.1 then
		vehicle.cp.laneOffset = 0;
	end;
	vehicle.cp.totalOffsetX = vehicle.cp.laneOffset + vehicle.cp.toolOffsetX;
end;

function courseplay:changeToolOffsetX(vehicle, changeBy, force, noDraw)
	vehicle.cp.toolOffsetX = force or (courseplay:round(vehicle.cp.toolOffsetX, 1) + changeBy);
	if math.abs(vehicle.cp.toolOffsetX) < 0.1 then
		vehicle.cp.toolOffsetX = 0;
	end;
	vehicle.cp.totalOffsetX = vehicle.cp.laneOffset + vehicle.cp.toolOffsetX;

	if noDraw == nil then noDraw = false; end;
	if not noDraw and vehicle.cp.mode ~= 3 and vehicle.cp.mode ~= 7 then
		courseplay:calculateWorkWidthDisplayPoints(vehicle);
		vehicle.cp.workWidthChanged = vehicle.timer + 2000;
	end
end;

function courseplay:changeToolOffsetZ(vehicle, changeBy, force)
	vehicle.cp.toolOffsetZ = force or (courseplay:round(vehicle.cp.toolOffsetZ, 1) + changeBy);
	if math.abs(vehicle.cp.toolOffsetZ) < 0.1 then
		vehicle.cp.toolOffsetZ = 0;
	end;
end;

function courseplay:calculateWorkWidth(vehicle)
	local l,r;

	courseplay:debug(('%s: calculateWorkWidth()'):format(nameNum(vehicle)), 7);
	local vehL,vehR = courseplay:getCuttingAreaValuesX(vehicle);
	courseplay:debug(('\tvehL=%s, vehR=%s'):format(tostring(vehL), tostring(vehR)), 7);

	local min, max, abs = math.min, math.max, math.abs;
	local implL,implR = -9999,9999;
	if vehicle.attachedImplements then
		for i,implement in pairs(vehicle.attachedImplements) do
			local workWidth = courseplay:getSpecialWorkWidth(implement.object);
			if workWidth then
				courseplay:debug(('\tSpecial workWidth found: %.1fm'):format(workWidth), 7);
				courseplay:changeWorkWidth(vehicle, nil, workWidth);
				return;
			end;

			local left, right = courseplay:getCuttingAreaValuesX(implement.object);
			if left and right then
				implL = max(implL, left);
				implR = min(implR, right);
			end;
			courseplay:debug(('\t-> implL=%s, implR=%s'):format(tostring(implL), tostring(implR)), 7);
			if implement.object.attachedImplements then
				for j,subImplement in pairs(implement.object.attachedImplements) do
					local subLeft, subRight = courseplay:getCuttingAreaValuesX(subImplement.object);
					if subLeft and subRight then
						implL = max(implL, subLeft);
						implR = min(implR, subRight);
					end;
					courseplay:debug(('\t-> implL=%s, implR=%s'):format(j, tostring(implL), tostring(implR)), 7);
				end;
			end;
		end;
	end;
	if implL == -9999 or implR == 9999 then
		implL, implR = nil, nil;
		courseplay:debug('\timplL=nil, implR=nil', 7);
	end;

	if vehL and vehR then
		if implL and implR then
			l = max(vehL, implL);
			r = min(vehR, implR);
		else
			l = vehL;
			r = vehR;
		end;
	else
		if implL and implR then
			l = implL;
			r = implR;
		else
			l =  1.5;
			r = -1.5;
		end;
	end;

	local workWidth = l - r;
	courseplay:debug(('\tl=%s, r=%s -> workWidth=l-r=%s'):format(tostring(l), tostring(r), tostring(workWidth)), 7);

	courseplay:changeWorkWidth(vehicle, nil, workWidth);
end;

function courseplay:getCuttingAreaValuesX(object)
	courseplay:debug(('\tgetCuttingAreaValuesX(%s)'):format(nameNum(object)), 7);

	if object.aiLeftMarker and object.aiRightMarker then
		local x, y, z = getWorldTranslation(object.aiLeftMarker);
		local left, _, _ = worldToLocal(object.rootNode, x, y, z);
		x, y, z = getWorldTranslation(object.aiRightMarker);
		local right, _, _ = worldToLocal(object.rootNode, x, y, z);

		courseplay:debug(('\t\taiMarkers: left=%s, right=%s'):format(tostring(left), tostring(right)), 7);

		if left < right then
			local rightBackup = right;
			right = left;
			left = rightBackup;
			courseplay:debug(('\t\tleft < right -> switch -> left=%s, right=%s'):format(tostring(left), tostring(right)), 7);
		end;

		return left, right;
	end;


	local areas;
	if courseplay:isBigM(object) then
		areas = object.mowerCutAreas;
		courseplay:debug('\t\tareas = mowerCutAreas (isBigM)', 7);
	elseif object.typeName == 'defoliator_animated' then
		areas = object.fruitPreparerAreas;
		courseplay:debug('\t\tareas = fruitPreparerAreas', 7);
	elseif object.cp.isPoettingerAlpha then -- Pöttinger Alpha mower
		areas = object.alpMot.cuttingAreas;
		courseplay:debug('\t\tareas = alpMot.cuttingAreas (isPoettingerAlpha)', 7);
	elseif object.cp.isPoettingerX8 then -- Pöttinger X8 mower
		areas = object.mowerCutAreasSend;
		courseplay:debug('\t\tareas = mowerCutAreasSend (isPoettingerX8)', 7);
	else
		areas = object.cuttingAreas;
		courseplay:debug('\t\tareas = cuttingAreas', 7);
	end;

	local min, max = math.min, math.max;
	local left, right = -9999, 9999;
	if areas and #areas > 0 then
		for i=1,#areas do
			for caType,node in pairs(areas[i]) do
				if caType == 'start' or caType == 'height' or caType == 'width' then
					local x, y, z = getWorldTranslation(node);
					local caX, _, _ = worldToLocal(object.rootNode, x, y, z);
					left = max(left, caX);
					right = min(right, caX);
					courseplay:debug(('\t\t\tarea %d, type=%s, caX=%s -> left=%s, right=%s'):format(i, tostring(caType), tostring(caX), tostring(left), tostring(right)), 7);
				end;
			end;
		end;
	end;
	if left == -9999 or right == 9999 then
		left, right = nil, nil;
		courseplay:debug('\t\t\tareas=nil -> left=nil, right=nil', 7);
	end;

	courseplay:debug(('\t\tareas: left=%s, right=%s'):format(tostring(left), tostring(right)), 7);
	return left, right;
end;

function courseplay:changeWorkWidth(vehicle, changeBy, force)
	local abs, max = math.abs, math.max;
	if force then
		vehicle.cp.workWidth = max(courseplay:round(abs(force), 1), 0.1);
	else
		if vehicle.cp.workWidth + changeBy > 10 then
			if abs(changeBy) == 0.1 then
				changeBy = 0.5 * Utils.sign(changeBy);
			elseif abs(changeBy) == 0.5 then
				changeBy = 2 * Utils.sign(changeBy);
			end;
		end;
		vehicle.cp.workWidth = max(vehicle.cp.workWidth + changeBy, 0.1);
	end;
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

function courseplay:changeVisualWaypointsMode(vehicle, changeBy, force)
	vehicle.cp.visualWaypointsMode = force or courseplay:varLoop(vehicle.cp.visualWaypointsMode, changeBy, 4, 1);
	courseplay.utils.signs:setSignsVisibility(vehicle);
end;


function courseplay:changeDriveOnAtFillLevel(vehicle, changeBy)
	vehicle.cp.driveOnAtFillLevel = Utils.clamp(vehicle.cp.driveOnAtFillLevel + changeBy, 0, 100);
end


function courseplay:changeFollowAtFillLevel(vehicle, changeBy)
	vehicle.cp.followAtFillLevel = Utils.clamp(vehicle.cp.followAtFillLevel + changeBy, 0, 100);
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


function courseplay:changeWaitTime(vehicle, changeBy)
	vehicle.cp.waitTime = math.max(0, vehicle.cp.waitTime + changeBy);
end

function courseplay:changeTurnSpeed(vehicle, changeBy)
	local speed = vehicle.cp.speeds.turn * 3600;
	speed = Utils.clamp(speed + changeBy, 5, 60);
	vehicle.cp.speeds.turn = speed / 3600;
end

function courseplay:changeFieldSpeed(vehicle, changeBy)
	local speed = vehicle.cp.speeds.field * 3600;
	speed = Utils.clamp(speed + changeBy, 5, 60);
	vehicle.cp.speeds.field = speed / 3600;
end

function courseplay:changeMaxSpeed(vehicle, changeBy)
	if not vehicle.cp.speeds.useRecordingSpeed then
		local speed = vehicle.cp.speeds.max * 3600;
		speed = Utils.clamp(speed + changeBy, 5, 60);
		vehicle.cp.speeds.max = speed / 3600;
	end;
end

function courseplay:changeUnloadSpeed(vehicle, changeBy)
	local speed = vehicle.cp.speeds.unload * 3600;
	speed = Utils.clamp(speed + changeBy, 3, 60);
	vehicle.cp.speeds.unload = speed / 3600;
end

function courseplay:changeUseRecordingSpeed(vehicle)
	vehicle.cp.speeds.useRecordingSpeed = not vehicle.cp.speeds.useRecordingSpeed;
end;

function courseplay:changeBeaconLightsMode(vehicle, changeBy)
	vehicle.cp.beaconLightsMode = vehicle.cp.beaconLightsMode + changeBy;
	if vehicle.cp.beaconLightsMode == 4 then
		vehicle.cp.beaconLightsMode = 1;
	end;
end;

function courseplay:toggleOpenHudWithMouse(vehicle)
	vehicle.cp.hud.openWithMouse = not vehicle.cp.hud.openWithMouse;
end;

function courseplay:toggleRealisticDriving(vehicle)
	vehicle.cp.realisticDriving = not vehicle.cp.realisticDriving;
end;

function courseplay:switchSearchCombineMode(vehicle)
	vehicle.cp.searchCombineAutomatically = not vehicle.cp.searchCombineAutomatically;
	if not vehicle.cp.searchCombineAutomatically then
		courseplay:setSearchCombineOnField(vehicle, nil, 0);
	end;
end;

function courseplay:setSearchCombineOnField(vehicle, changeDir, force)
	if courseplay.fields.numAvailableFields == 0 or not vehicle.cp.searchCombineAutomatically then
		vehicle.cp.searchCombineOnField = 0;
		return;
	end;
	if force and courseplay.fields.fieldData[force] then
		vehicle.cp.searchCombineOnField = force;
		return;
	end;

	local newFieldNum = vehicle.cp.searchCombineOnField + changeDir;
	if newFieldNum == 0 then
		vehicle.cp.searchCombineOnField = newFieldNum;
		return;
	end;

	while courseplay.fields.fieldData[newFieldNum] == nil do
		if newFieldNum == 0 then
			vehicle.cp.searchCombineOnField = newFieldNum;
			return;
		end;
		newFieldNum = Utils.clamp(newFieldNum + changeDir, 0, courseplay.fields.numAvailableFields);
	end;

	vehicle.cp.searchCombineOnField = newFieldNum;
end;

function courseplay:selectAssignedCombine(vehicle, changeBy)
	local combines = courseplay:find_combines(vehicle);
	vehicle.cp.selectedCombineNumber = Utils.clamp(vehicle.cp.selectedCombineNumber + changeBy, 0, #combines);

	if vehicle.cp.selectedCombineNumber == 0 then
		vehicle.cp.savedCombine = nil;
	else
		vehicle.cp.savedCombine = combines[vehicle.cp.selectedCombineNumber];
	end;

	courseplay:removeActiveCombineFromTractor(vehicle);
end;

function courseplay:removeActiveCombineFromTractor(vehicle)
	if vehicle.cp.activeCombine ~= nil then
		courseplay:unregister_at_combine(vehicle, vehicle.cp.activeCombine);
	end;
	vehicle.cp.lastActiveCombine = nil;
	courseplay.hud:setReloadPageOrder(vehicle, 4, true);
end;

function courseplay:removeSavedCombineFromTractor(vehicle)
	vehicle.cp.savedCombine = nil;
	vehicle.cp.selectedCombineNumber = 0;
	vehicle.cp.HUD4savedCombine = false;
	vehicle.cp.HUD4savedCombineName = '';
	courseplay.hud:setReloadPageOrder(vehicle, 4, true);
end;

function courseplay:switchDriverCopy(vehicle, changeBy)
	local drivers = courseplay:findDrivers(vehicle);

	if drivers ~= nil then
		vehicle.cp.selectedDriverNumber = Utils.clamp(vehicle.cp.selectedDriverNumber + changeBy, 0, #(drivers));

		if vehicle.cp.selectedDriverNumber == 0 then
			vehicle.cp.copyCourseFromDriver = nil;
			vehicle.cp.hasFoundCopyDriver = false;
		else
			vehicle.cp.copyCourseFromDriver = drivers[vehicle.cp.selectedDriverNumber];
			vehicle.cp.hasFoundCopyDriver = true;
		end;
	else
		vehicle.cp.copyCourseFromDriver = nil;
		vehicle.cp.selectedDriverNumber = 0;
		vehicle.cp.hasFoundCopyDriver = false;
	end;
end;

function courseplay:findDrivers(self)
	local foundDrivers = {}; -- resetting all drivers
	for k, vehicle in pairs(g_currentMission.steerables) do
		if vehicle.Waypoints ~= nil then
			if vehicle.rootNode ~= self.rootNode and #(vehicle.Waypoints) > 0 then
				table.insert(foundDrivers, vehicle);
			end;
		end;
	end;

	return foundDrivers;
end;

function courseplay:copyCourse(vehicle)
	if vehicle.cp.hasFoundCopyDriver ~= nil and vehicle.cp.copyCourseFromDriver ~= nil then
		local src = vehicle.cp.copyCourseFromDriver;

		vehicle.Waypoints = src.Waypoints;
		vehicle.cp.currentCourseName = src.cp.currentCourseName;
		vehicle.cp.loadedCourses = src.cp.loadedCourses;
		vehicle.cp.numCourses = src.cp.numCourses;
		vehicle.recordnumber = 1;
		vehicle.maxnumber = #(vehicle.Waypoints);
		vehicle.cp.numWaitPoints = src.cp.numWaitPoints;
		vehicle.cp.numCrossingPoints = src.cp.numCrossingPoints;

		vehicle.cp.isRecording = false;
		vehicle.cp.recordingIsPaused = false;
		vehicle.drive = false;
		vehicle.cp.distanceCheck = false;
		vehicle.cp.canDrive = true;
		vehicle.cp.abortWork = nil;

		vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = nil, nil, nil;
		vehicle.cp.nextTargets = {};
		if vehicle.cp.activeCombine ~= nil then
			courseplay:unregister_at_combine(vehicle, vehicle.cp.activeCombine);
		end

		vehicle.cp.modeState = 1;
		-- print(('%s [%s(%d)]: copyCourse() -> set modeState to 1'):format(nameNum(vehicle), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
		if vehicle.cp.mode == 2 or vehicle.cp.mode == 3 then
			vehicle.cp.modeState = 0;
			-- print(('%s [%s(%d)]: copyCourse(): mode=%d -> set modeState to 0'):format(nameNum(vehicle), curFile, debug.getinfo(1).currentline, vehicle.cp.mode)); -- DEBUG140301
		end;
		vehicle.cp.recordingTimer = 1;

		courseplay.utils.signs:updateWaypointSigns(vehicle, 'current');

		--reset variables
		vehicle.cp.selectedDriverNumber = 0;
		vehicle.cp.hasFoundCopyDriver = false;
		vehicle.cp.copyCourseFromDriver = nil;

		courseplay:validateCanSwitchMode(vehicle);
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
		courseplay.hud:setReloadPageOrder(vehicle, 2, true);
	else
		for k,v in pairs(g_currentMission.steerables) do
			if v.cp ~= nil then 		-- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				v.cp.reloadCourseItems = true
				courseplay.hud:setReloadPageOrder(v, 2, true);
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

	courseplay.hud:setReloadPageOrder(self, 2, true);
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
	
	courseplay.hud:setReloadPageOrder(vehicle, 2, true);
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

function courseplay:setHeadlandNumLanes(vehicle, changeBy)
	vehicle.cp.headland.numLanes = Utils.clamp(vehicle.cp.headland.numLanes + changeBy, 0, vehicle.cp.headland.maxNumLanes);
	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:setHeadlandDir(vehicle)
	vehicle.cp.headland.userDirClockwise = not vehicle.cp.headland.userDirClockwise;
	courseplay.button.setOverlay(vehicle.cp.headland.directionButton, vehicle.cp.headland.userDirClockwise and 1 or 2);
	courseplay:debug(string.format('setHeadlandDir(): userDirClockwise=%s -> set to %q, setOverlay(directionButton, %d)', tostring(not vehicle.cp.headland.userDirClockwise), tostring(vehicle.cp.headland.userDirClockwise), vehicle.cp.headland.userDirClockwise and 1 or 2), 7);
end;

function courseplay:setHeadlandOrder(vehicle)
	vehicle.cp.headland.orderBefore = not vehicle.cp.headland.orderBefore;
	courseplay.button.setOverlay(vehicle.cp.headland.orderButton, vehicle.cp.headland.orderBefore and 1 or 2);
	courseplay:debug(string.format('setHeadlandOrder(): orderBefore=%s -> set to %q, setOverlay(orderButton, %d)', tostring(not vehicle.cp.headland.orderBefore), tostring(vehicle.cp.headland.orderBefore), vehicle.cp.headland.orderBefore and 1 or 2), 7);
end;

function courseplay:validateCourseGenerationData(vehicle)
	local numWaypoints = 0;
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		numWaypoints = #(courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points);
	elseif vehicle.Waypoints ~= nil then
		numWaypoints = #(vehicle.Waypoints);
	end;

	local hasEnoughWaypoints = numWaypoints > 4
	if vehicle.cp.headland.numLanes ~= 0 then
		hasEnoughWaypoints = numWaypoints >= 20;
	end;

	if (vehicle.cp.fieldEdge.selectedField.fieldNum > 0 or not vehicle.cp.hasGeneratedCourse)
	and hasEnoughWaypoints
	and vehicle.cp.hasStartingCorner == true 
	and vehicle.cp.hasStartingDirection == true 
	and (vehicle.cp.numCourses == nil or (vehicle.cp.numCourses ~= nil and vehicle.cp.numCourses == 1) or vehicle.cp.fieldEdge.selectedField.fieldNum > 0) 
	then
		vehicle.cp.hasValidCourseGenerationData = true;
	else
		vehicle.cp.hasValidCourseGenerationData = false;
	end;

	courseplay:debug(string.format("%s: hasGeneratedCourse=%s, hasEnoughWaypoints=%s, hasStartingCorner=%s, hasStartingDirection=%s, numCourses=%s, fieldEdge.selectedField.fieldNum=%s ==> hasValidCourseGenerationData=%s", nameNum(vehicle), tostring(vehicle.cp.hasGeneratedCourse), tostring(hasEnoughWaypoints), tostring(vehicle.cp.hasStartingCorner), tostring(vehicle.cp.hasStartingDirection), tostring(vehicle.cp.numCourses), tostring(vehicle.cp.fieldEdge.selectedField.fieldNum), tostring(vehicle.cp.hasValidCourseGenerationData)), 7);
end;

function courseplay:validateCanSwitchMode(vehicle)
	vehicle.cp.canSwitchMode = not vehicle.drive and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and not vehicle.cp.fieldEdge.customField.isCreated;
	courseplay:debug(string.format("%s: validateCanSwitchMode(): drive=%s, record=%s, record_pause=%s, customField.isCreated=%s ==> canSwitchMode=%s", nameNum(vehicle), tostring(vehicle.drive), tostring(vehicle.cp.isRecording), tostring(vehicle.cp.recordingIsPaused), tostring(vehicle.cp.fieldEdge.customField.isCreated), tostring(vehicle.cp.canSwitchMode)), 12);
end;

function courseplay:saveShovelPosition(vehicle, stage)
	if stage == nil then return; end;

	if stage >= 2 and stage <= 5 then
		if vehicle.cp.shovelStatePositions[stage] ~= nil then
			vehicle.cp.shovelStatePositions[stage] = nil;
			vehicle.cp.hasShovelStatePositions[stage] = false;
		else
			local mt, secondary = courseplay:getMovingTools(vehicle);
			local curRot, curTrans = courseplay:getCurrentMovingToolsPosition(vehicle, mt, secondary);
			courseplay:debug(tableShow(curRot, ('saveShovelPosition(%q, %d) curRot'):format(nameNum(vehicle), stage), 10), 10);
			courseplay:debug(tableShow(curTrans, ('saveShovelPosition(%q, %d) curTrans'):format(nameNum(vehicle), stage), 10), 10);
			if curRot and curTrans then
				vehicle.cp.shovelStatePositions[stage] = {
					rot = curRot,
					trans = curTrans
				};
			end;
			vehicle.cp.hasShovelStatePositions[stage] = vehicle.cp.shovelStatePositions[stage] ~= nil;
		end;

	end;
	courseplay:buttonsActiveEnabled(vehicle, 'shovel');
end;

function courseplay:setShovelStopAndGo(vehicle)
	vehicle.cp.shovelStopAndGo = not vehicle.cp.shovelStopAndGo;
end;

function courseplay:setStartAtFirstPoint(vehicle)
	vehicle.cp.startAtFirstPoint = not vehicle.cp.startAtFirstPoint;
end;

function courseplay:reloadCoursesFromXML(vehicle)
	courseplay:debug("reloadCoursesFromXML()", 8);
	if g_server ~= nil then
		courseplay_manager:load_courses();
		courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		courseplay:debug("g_currentMission.cp_courses = courseplay_manager:load_courses()", 8);
		if not vehicle.drive then
			local loadedCoursesBackup = vehicle.cp.loadedCourses;
			courseplay:clearCurrentLoadedCourse(vehicle);
			vehicle.cp.loadedCourses = loadedCoursesBackup;
			courseplay:reload_courses(vehicle, true);
			courseplay:debug("courseplay:reload_courses(vehicle, true)", 8);
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

function courseplay:changeDebugChannelSection(vehicle, changeBy)
	courseplay.debugChannelSection = Utils.clamp(courseplay.debugChannelSection + changeBy, 1, math.ceil(courseplay.numAvailableDebugChannels / courseplay.numDebugChannelButtonsPerLine));
	courseplay.debugChannelSectionEnd = courseplay.numDebugChannelButtonsPerLine * courseplay.debugChannelSection;
	courseplay.debugChannelSectionStart = courseplay.debugChannelSectionEnd - courseplay.numDebugChannelButtonsPerLine + 1;
end;

function courseplay:toggleSymmetricLaneChange(vehicle, force)
	vehicle.cp.symmetricLaneChange = Utils.getNoNil(force, not vehicle.cp.symmetricLaneChange);
	vehicle.cp.switchLaneOffset = vehicle.cp.symmetricLaneChange;
end;

function courseplay:toggleDriverPriority(combine)
	if combine.cp.driverPriorityUseFillLevel == nil then combine.cp.driverPriorityUseFillLevel = false; end;
	combine.cp.driverPriorityUseFillLevel = not combine.cp.driverPriorityUseFillLevel;
end;

function courseplay:toggleStopWhenUnloading(combine)
	if combine.cp.isChopper then
		combine.cp.stopWhenUnloading = false;
		return;
	end;
	if combine.cp.stopWhenUnloading == nil then combine.cp.stopWhenUnloading = false; end;
	combine.cp.stopWhenUnloading = not combine.cp.stopWhenUnloading;
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
		local toggleSucHudButtonIdx = courseplay:register_button(vehicle, 8, 'calculator.png', 'toggleSucHud', nil, courseplay.hud.infoBasePosX + 0.255, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, nil, false, false, true);
		vehicle.cp.suc.toggleHudButton = vehicle.cp.buttons['8'][toggleSucHudButtonIdx];
		courseplay:register_button(vehicle, 8, 'eye.png', 'toggleSelectedFieldEdgePathShow', nil, courseplay.hud.infoBasePosX + 0.270, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, nil, false);
		courseplay:register_button(vehicle, 8, 'navigate_up.png',   'setFieldEdgePath',  1, courseplay.hud.infoBasePosX + 0.285, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1,  5, false);
		courseplay:register_button(vehicle, 8, 'navigate_down.png', 'setFieldEdgePath', -1, courseplay.hud.infoBasePosX + 0.300, courseplay.hud.linesButtonPosY[1], w16px, h16px, 1, -5, false);
		courseplay:register_button(vehicle, 8, nil, 'setFieldEdgePath', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 5, true, true);
		vehicle.cp.fieldEdge.selectedField.buttonsCreated = true;
	end;
end;

function courseplay:setFieldEdgePath(vehicle, changeDir, force)
	local newFieldNum = force or vehicle.cp.fieldEdge.selectedField.fieldNum + changeDir;
	if newFieldNum == 0 then
		vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;
		if vehicle.cp.suc.active then
			courseplay:toggleSucHud(vehicle);
		end;
		return;
	end;

	while courseplay.fields.fieldData[newFieldNum] == nil do
		if newFieldNum == 0 then
			vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;
			if vehicle.cp.suc.active then
				courseplay:toggleSucHud(vehicle);
			end;
			return;
		end;
		newFieldNum = Utils.clamp(newFieldNum + changeDir, 0, courseplay.fields.numAvailableFields);
	end;

	vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;

	if newFieldNum == 0 and vehicle.cp.suc.active then
		courseplay:toggleSucHud(vehicle);
	end;

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
	local isField = x and z and courseplay:isField(x, z, 0, 0); --TODO: use width/height of 0.1 ?
	courseplay.fields:dbg(string.format("Custom field scan: x,z=%.1f,%.1f, isField=%s", x, z, tostring(isField)), 'customLoad');
	vehicle.cp.fieldEdge.customField.points = nil;
	if isField then
		local edgePoints = courseplay.fields:setSingleFieldEdgePath(vehicle.rootNode, x, z, courseplay.fields.scanStep, 2000, 10, nil, true, 'customLoad');
		vehicle.cp.fieldEdge.customField.points = edgePoints;
		vehicle.cp.fieldEdge.customField.numPoints = edgePoints ~= nil and #edgePoints or 0;
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
	local data = {
		fieldNum = vehicle.cp.fieldEdge.customField.fieldNum;
		points = vehicle.cp.fieldEdge.customField.points;
		numPoints = vehicle.cp.fieldEdge.customField.numPoints;
		name = string.format("%s %d (%s)", courseplay:loc('COURSEPLAY_FIELD'), vehicle.cp.fieldEdge.customField.fieldNum, courseplay:loc('COURSEPLAY_USER'));
		isCustom = true;
	};
	local area, _, dimensions = courseplay.fields:getPolygonData(data.points, nil, nil, true);
	data.areaSqm = area;
	data.areaHa = area / 10000;
	data.dimensions = dimensions;
	data.fieldAreaText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_FIELD'):format(data.fieldNum, courseplay.fields:formatNumber(data.areaHa, 2), g_i18n:getText('area_unit_short'));
	data.seedUsage, data.seedPrice, data.seedDataText = courseplay.fields:getFruitData(area);

	courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum] = data;
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

function courseplay:setDrawWaypointsLines(vehicle)
	if not courseplay.isDeveloper then return; end;
	vehicle.cp.drawWaypointsLines = not vehicle.cp.drawWaypointsLines;
end;

function courseplay:setEngineState(vehicle, on)
	if vehicle == nil or on == nil or vehicle.isMotorStarted == on then
		return;
	end;

	--Manual ignition v3.01/3.04 (self-installing)
	if vehicle.setManualIgnitionMode ~= nil and vehicle.ignitionMode ~= nil then
		vehicle:setManualIgnitionMode(on and 2 or 0);

	--Manual ignition v3.x (in steerable as lua)
	elseif vehicle.ignitionKey ~= nil and vehicle.allowedIgnition ~= nil then
		vehicle.ignitionKey = on;
        vehicle.allowedIgnition = on;

	--default
	elseif vehicle.startMotor and vehicle.stopMotor then
		if on then
			vehicle:startMotor(true);
		else
			vehicle.lastAcceleration = 0;
			vehicle:stopMotor(true);
		end;
	end;
end;

function courseplay:setCurrentTargetFromList(vehicle, index)
	if #vehicle.cp.nextTargets == 0 then return; end;
	index = index or 1;

	vehicle.cp.curTarget = vehicle.cp.nextTargets[index];
	if index == 1 then
		table.remove(vehicle.cp.nextTargets, 1);
		return;
	end;

	for i=index,1,-1 do
		table.remove(vehicle.cp.nextTargets, i);
	end;
end;

function courseplay:addNewTarget(vehicle, x, z)
	local tx, ty, tz = localToWorld(vehicle.rootNode, x, 0, z);
	table.insert(vehicle.cp.nextTargets, { x = tx, y = ty, z = tz });
end;

function courseplay:changeRefillUntilPct(vehicle, changeBy)
	vehicle.cp.refillUntilPct = Utils.clamp(vehicle.cp.refillUntilPct + changeBy, 1, 100);
end;

function courseplay:toggleSucHud(vehicle)
	vehicle.cp.suc.active = not vehicle.cp.suc.active;
	courseplay:buttonsActiveEnabled(vehicle, 'suc');
	if vehicle.cp.suc.selectedFruit == nil then
		vehicle.cp.suc.selectedFruitIdx = 1;
		vehicle.cp.suc.selectedFruit = courseplay.fields.seedUsageCalculator.fruitTypes[1];
	end;
end;

function courseplay:sucChangeFruit(vehicle, change)
	local newIdx = vehicle.cp.suc.selectedFruitIdx + change;
	if newIdx > courseplay.fields.seedUsageCalculator.numFruits then
		newIdx = newIdx - courseplay.fields.seedUsageCalculator.numFruits;
	elseif newIdx < 1 then
		newIdx = courseplay.fields.seedUsageCalculator.numFruits - newIdx;
	end;
	vehicle.cp.suc.selectedFruitIdx = newIdx;
	vehicle.cp.suc.selectedFruit = courseplay.fields.seedUsageCalculator.fruitTypes[vehicle.cp.suc.selectedFruitIdx];
end;

function courseplay:toggleFindFirstWaypoint(vehicle)
	vehicle.cp.distanceCheck = not vehicle.cp.distanceCheck;
	if g_server ~= nil and not vehicle.cp.distanceCheck then
		vehicle.cp.infoText = nil;
	end;
	courseplay:buttonsActiveEnabled(vehicle, 'findFirstWaypoint');
end;