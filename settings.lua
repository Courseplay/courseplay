local curFile = 'settings.lua';
local abs, ceil, max, min = math.abs, math.ceil, math.max, math.min;

function courseplay:openCloseHud(vehicle, open)
	courseplay:setMouseCursor(vehicle, open);
	vehicle.cp.hud.show = open;
	if open then
		courseplay:buttonsActiveEnabled(vehicle, 'all');
	else
		courseplay.buttons:setHoveredButton(vehicle, nil);
	end;
end;

function courseplay:setCpMode(vehicle, modeNum)
	if vehicle.cp.mode ~= modeNum then
		vehicle.cp.mode = modeNum;
		courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.currentModeIcon, courseplay.hud.bottomInfo.modeUVsPx[modeNum], courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
		courseplay:buttonsActiveEnabled(vehicle, 'all');
		if modeNum == 1 then
			courseplay:reset_tools(vehicle);
		end;
	end;
end;

function courseplay:toggleWantsCourseplayer(combine)
	combine.cp.wantsCourseplayer = not combine.cp.wantsCourseplayer;
end;

function courseplay:startStopCourseplayer(combine)
	local tractor = combine.courseplayers[1];
	tractor.cp.forcedToStop = not tractor.cp.forcedToStop;
end;

function courseplay:setVehicleWait(vehicle, active)
	vehicle.cp.wait = active;
end;

function courseplay:cancelWait(vehicle, cancelStopAtEnd)
	if vehicle.cp.wait then
		courseplay:setVehicleWait(vehicle, false);
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
	if vehicle.cp.isLoaded ~= bool then
		vehicle.cp.isLoaded = bool;
	end;
end;

function courseplay:sendCourseplayerHome(combine)
	courseplay:setIsLoaded(combine.courseplayers[1], true);
end

function courseplay:switchCourseplayerSide(combine)
	if combine.capacity == 0 then
		local tractor = combine.courseplayers[1];
		if tractor == nil then
			return;
		end;

		courseplay:setModeState(tractor, 10);

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

function courseplay:buttonsActiveEnabled(vehicle, section)
	local anySection = section == nil or section == 'all';

	if anySection or section == 'pageNav' then
		for _,button in pairs(vehicle.cp.buttons.global) do
			if button.functionToCall == 'setHudPage' then
				local pageNum = button.parameter;
				button:setActive(pageNum == vehicle.cp.hud.currentPage);

				if vehicle.cp.mode == nil then
					button:setDisabled(false);
				elseif courseplay.hud.pagesPerMode[vehicle.cp.mode] ~= nil and courseplay.hud.pagesPerMode[vehicle.cp.mode][pageNum] then
					if pageNum == 0 then
						local disabled = not (vehicle.cp.minHudPage == 0 or vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader);
						button:setDisabled(disabled);
					else
						button:setDisabled(false);
					end;
				else
					button:setDisabled(true);
				end;

				button:setCanBeClicked(not button.isDisabled and not button.isActive);
			end;
		end;
	end;

	if vehicle.cp.hud.currentPage == 1 and (anySection or section == 'quickModes' or section == 'recording' or section == 'customFieldShow' or section == 'findFirstWaypoint') then
		for _,button in pairs(vehicle.cp.buttons[1]) do
			local fn, prm = button.functionToCall, button.parameter;
			if fn == 'setCpMode' and (anySection or section == 'quickModes') then
				button:setActive(vehicle.cp.mode == prm);
				local disabled = (prm == 7 and not vehicle.cp.isCombine and not vehicle.cp.isChopper and not vehicle.cp.isHarvesterSteerable)
							  or ((prm == 1 or prm == 2 or prm == 3 or prm == 4 or prm == 8 or prm == 9) and (vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable))
							  or ((prm ~= 5) and (vehicle.cp.isWoodHarvester or vehicle.cp.isWoodForwarder));
				button:setDisabled(disabled);
				button:setCanBeClicked(not button.isDisabled and not button.isActive);
			end;

			if fn == 'toggleCustomFieldEdgePathShow' and (anySection or section == 'customFieldShow') then
				button:setActive(vehicle.cp.fieldEdge.customField.show);
			end;

			if fn == 'toggleFindFirstWaypoint' and (anySection or section == 'findFirstWaypoint') then
				button:setActive(vehicle.cp.distanceCheck);
			end;

			if anySection or section == 'recording' then
				if fn == 'stop_record' then
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'setRecordingPause' then
					button:setActive(vehicle.cp.recordingIsPaused);
					button:setDisabled(vehicle.cp.HUDrecordnumber < 4 or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'delete_waypoint' then
					-- NOTE: during recording pause, HUDrecordnumber = recordnumber + 1, that's why <= 5 is used
					button:setDisabled(not vehicle.cp.recordingIsPaused or vehicle.cp.HUDrecordnumber <= 5);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'set_waitpoint' or fn == 'set_crossing' then
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'setRecordingTurnManeuver' then --isToggleButton
					button:setActive(vehicle.cp.isRecordingTurnManeuver);
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.drivingDirReverse);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'change_DriveDirection' then --isToggleButton
					button:setActive(vehicle.cp.drivingDirReverse);
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				end;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 2 and section == 'page2' then
		local enable, show = true, true;
		local numVisibleCourses = #(vehicle.cp.hud.courses);
		local nofolders = nil == next(g_currentMission.cp_folders);
		local indent = courseplay.hud.indent;
		local row;
		for _, button in pairs(vehicle.cp.buttons[-2]) do
			row = button.row;
			enable = true;
			show = true;

			if row > numVisibleCourses then
				show = false;
			else
				if button.functionToCall == 'expandFolder' then
					if vehicle.cp.hud.courses[row].type == 'course' then
						show = false;
					else
						-- position the expandFolder buttons
						button:setOffset(vehicle.cp.hud.courses[row].level * indent, 0)
						
						if vehicle.cp.hud.courses[row].id == 0 then
							show = false; --hide for level 0 'folder'
						else
							-- check if plus or minus should show up
							if vehicle.cp.folder_settings[vehicle.cp.hud.courses[row].id].showChildren then
								button:setSpriteSectionUVs('navMinus');
							else
								button:setSpriteSectionUVs('navPlus');
							end;
							if g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild == 0 then
								enable = false; -- button has no children
							end;
						end;
					end;
				else
					if vehicle.cp.hud.courses[row].type == 'folder' and (button.functionToCall == 'loadSortedCourse' or button.functionToCall == 'addSortedCourse') then
						show = false;
					elseif vehicle.cp.hud.choose_parent ~= true then
						if button.functionToCall == 'deleteSortedItem' and vehicle.cp.hud.courses[row].type == 'folder' and g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild ~= 0 then
							enable = false;
						elseif button.functionToCall == 'linkParent' then
							button:setSpriteSectionUVs('folderParentFrom');
							if nofolders then
								enable = false;
							end;
						end;
					else
						if button.functionToCall ~= 'linkParent' then
							enable = false;
						else
							button:setSpriteSectionUVs('folderParentTo');
						end;
					end;
				end;
			end;

			button:setDisabled(not enable or not show);
			button:setShow(show);
		end; -- for buttons
		courseplay.settings.validateCourseListArrows(vehicle);

	elseif vehicle.cp.hud.currentPage == 6 and (anySection or section == 'debug') then
		for _,button in pairs(vehicle.cp.buttons[6]) do
			if button.functionToCall == 'toggleDebugChannel' then
				button:setDisabled(button.parameter > courseplay.numDebugChannels);
				button:setActive(courseplay.debugChannels[button.parameter] == true);
				button:setCanBeClicked(not button.isDisabled);
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 8 and (anySection or section == 'generateCourse' or section == 'selectedFieldShow' or section == 'suc') then
		vehicle.cp.hud.generateCourseButton:setDisabled(not vehicle.cp.hasValidCourseGenerationData);
		if vehicle.cp.hud.showSelectedFieldEdgePathButton then
			vehicle.cp.hud.showSelectedFieldEdgePathButton:setActive(vehicle.cp.fieldEdge.selectedField.show);
		end;
		if vehicle.cp.suc.toggleHudButton then
			vehicle.cp.suc.toggleHudButton:setActive(vehicle.cp.suc.active);
		end;

	elseif vehicle.cp.hud.currentPage == 9 and (anySection or section == 'shovel') then
		for _,button in pairs(vehicle.cp.buttons[9]) do
			if button.functionToCall == 'saveShovelPosition' then --isToggleButton
				button:setActive(vehicle.cp.shovelStatePositions[button.parameter] ~= nil);
				button:setCanBeClicked(true);
			end;
		end;
	end;
end;

function courseplay:changeCombineOffset(vehicle, changeBy)
	local previousOffset = vehicle.cp.combineOffset;

	vehicle.cp.combineOffsetAutoMode = false;
	vehicle.cp.combineOffset = courseplay:round(vehicle.cp.combineOffset, 1) + changeBy;
	if abs(vehicle.cp.combineOffset) < 0.1 then
		vehicle.cp.combineOffset = 0.0;
		vehicle.cp.combineOffsetAutoMode = true;
	end;

	courseplay:debug(nameNum(vehicle) .. ": manual combine_offset change: prev " .. previousOffset .. " // new " .. vehicle.cp.combineOffset .. " // auto = " .. tostring(vehicle.cp.combineOffsetAutoMode), 4);
end

function courseplay:changeTipperOffset(vehicle, changeBy)
	vehicle.cp.tipperOffset = courseplay:round(vehicle.cp.tipperOffset, 1) + changeBy;
	if abs(vehicle.cp.tipperOffset) < 0.1 then
		vehicle.cp.tipperOffset = 0;
	end;
end

function courseplay:changeLaneOffset(vehicle, changeBy, force)
	vehicle.cp.laneOffset = force or (courseplay:round(vehicle.cp.laneOffset, 1) + changeBy);
	if abs(vehicle.cp.laneOffset) < 0.1 then
		vehicle.cp.laneOffset = 0;
	end;
	vehicle.cp.totalOffsetX = vehicle.cp.laneOffset + vehicle.cp.toolOffsetX;
end;

function courseplay:changeToolOffsetX(vehicle, changeBy, force, noDraw)
	vehicle.cp.toolOffsetX = force or (courseplay:round(vehicle.cp.toolOffsetX, 1) + changeBy);
	if abs(vehicle.cp.toolOffsetX) < 0.1 then
		vehicle.cp.toolOffsetX = 0;
	end;
	vehicle.cp.totalOffsetX = vehicle.cp.laneOffset + vehicle.cp.toolOffsetX;

	if not noDraw and vehicle.cp.mode ~= 2 and vehicle.cp.mode ~= 3 and vehicle.cp.mode ~= 7 then
		courseplay:setCustomTimer(vehicle, 'showWorkWidth', 2);
	end;
end;

function courseplay:changeToolOffsetZ(vehicle, changeBy, force)
	vehicle.cp.toolOffsetZ = force or (courseplay:round(vehicle.cp.toolOffsetZ, 1) + changeBy);
	if abs(vehicle.cp.toolOffsetZ) < 0.1 then
		vehicle.cp.toolOffsetZ = 0;
	end;
end;

function courseplay:calculateWorkWidth(vehicle, noDraw)
	local l,r;

	courseplay:debug(('%s: calculateWorkWidth()'):format(nameNum(vehicle)), 7);
	local vehL,vehR = courseplay:getCuttingAreaValuesX(vehicle);
	courseplay:debug(('\tvehL=%s, vehR=%s'):format(tostring(vehL), tostring(vehR)), 7);

	local implL,implR = -9999,9999;
	if vehicle.attachedImplements then
		for i,implement in pairs(vehicle.attachedImplements) do
			local workWidth = courseplay:getSpecialWorkWidth(implement.object);
			if workWidth then
				courseplay:debug(('\tSpecial workWidth found: %.1fm'):format(workWidth), 7);
				courseplay:changeWorkWidth(vehicle, nil, workWidth, noDraw);
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

	courseplay:changeWorkWidth(vehicle, nil, workWidth, noDraw);
end;

function courseplay:getCuttingAreaValuesX(object)
	courseplay:debug(('\tgetCuttingAreaValuesX(%s)'):format(nameNum(object)), 7);

	if object.aiLeftMarker and object.aiRightMarker then
		local x, y, z = getWorldTranslation(object.aiLeftMarker);
		local left, _, _ = worldToLocal(object.cp.DirectionNode or object.rootNode, x, y, z);
		x, y, z = getWorldTranslation(object.aiRightMarker);
		local right, _, _ = worldToLocal(object.cp.DirectionNode or object.rootNode, x, y, z);

		courseplay:debug(('\t\taiMarkers: left=%s, right=%s'):format(tostring(left), tostring(right)), 7);

		if left < right then
			local rightBackup = right;
			right = left;
			left = rightBackup;
			courseplay:debug(('\t\tleft < right -> switch -> left=%s, right=%s'):format(tostring(left), tostring(right)), 7);
		end;

		return left, right;
	end;


	local areas = object.workAreas;

	local min, max = math.min, math.max;
	local left, right = -9999, 9999;
	if areas and #areas > 0 then
		for i=1,#areas do
			for caType,node in pairs(areas[i]) do
				if caType == 'start' or caType == 'height' or caType == 'width' then
					local x, y, z = getWorldTranslation(node);
					local caX, _, _ = worldToLocal(object.cp.DirectionNode or object.rootNode, x, y, z);
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

function courseplay:changeWorkWidth(vehicle, changeBy, force, noDraw)
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

		if (vehicle.cp.workWidth < 10 and vehicle.cp.workWidth + changeBy > 10) or (vehicle.cp.workWidth > 10 and vehicle.cp.workWidth + changeBy < 10) then
			vehicle.cp.workWidth = 10;
		else
			vehicle.cp.workWidth = max(vehicle.cp.workWidth + changeBy, 0.1);
		end;
	end;
	if not noDraw then
		courseplay:setCustomTimer(vehicle, 'showWorkWidth', 2);
	end;
end;

function courseplay:changeVisualWaypointsMode(vehicle, changeBy, force)
	vehicle.cp.visualWaypointsMode = force or courseplay:varLoop(vehicle.cp.visualWaypointsMode, changeBy, 4, 1);
	courseplay.signs:setSignsVisibility(vehicle);
end;


function courseplay:changeDriveOnAtFillLevel(vehicle, changeBy)
	vehicle.cp.driveOnAtFillLevel = Utils.clamp(vehicle.cp.driveOnAtFillLevel + changeBy, 0, 100);
end


function courseplay:changeFollowAtFillLevel(vehicle, changeBy)
	vehicle.cp.followAtFillLevel = Utils.clamp(vehicle.cp.followAtFillLevel + changeBy, 0, 100);
end


function courseplay:changeTurnDiameter(vehicle, changeBy)
	vehicle.cp.turnDiameter = vehicle.cp.turnDiameter + changeBy;
	vehicle.cp.turnDiameterAutoMode = false;

	if vehicle.cp.turnDiameter < 0.5 then
		vehicle.cp.turnDiameter = 0;
	end;

	if vehicle.cp.turnDiameter <= 0 then
		vehicle.cp.turnDiameterAutoMode = true;
		vehicle.cp.turnDiameter = vehicle.cp.turnDiameterAuto
	end;
end


function courseplay:changeWaitTime(vehicle, changeBy)
	vehicle.cp.waitTime = math.max(0, vehicle.cp.waitTime + changeBy);
end;

function courseplay:getCanHaveWaitTime(vehicle)
	return vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 5 or (vehicle.cp.mode == 6 and not vehicle.cp.hasBaleLoader) or vehicle.cp.mode == 8;
end;

function courseplay:changeTurnSpeed(vehicle, changeBy)
	local speed = vehicle.cp.speeds.turn;
	speed = Utils.clamp(speed + changeBy, vehicle.cp.speeds.minTurn, vehicle.cp.speeds.max);
	vehicle.cp.speeds.turn = speed ;
end

function courseplay:changeFieldSpeed(vehicle, changeBy)
	local speed = vehicle.cp.speeds.field;
	speed = Utils.clamp(speed + changeBy, vehicle.cp.speeds.minField, vehicle.cp.speeds.max);
	vehicle.cp.speeds.field = speed;
end

function courseplay:changeMaxSpeed(vehicle, changeBy)
	if not vehicle.cp.speeds.useRecordingSpeed then
		local speed = vehicle.cp.speeds.street;
		speed = Utils.clamp(speed + changeBy, vehicle.cp.speeds.minStreet, vehicle.cp.speeds.max);
		vehicle.cp.speeds.street = speed;
	end;
end

function courseplay:changeUnloadSpeed(vehicle, changeBy, force, forceReloadPage)
	local speed = force or (vehicle.cp.speeds.unload + changeBy);
	if not force then
		speed = Utils.clamp(speed, vehicle.cp.speeds.minUnload, vehicle.cp.speeds.max);
	end;
	vehicle.cp.speeds.unload = speed;

	if forceReloadPage then
		courseplay.hud:setReloadPageOrder(vehicle, 5, true);
	end;
end

function courseplay:toggleUseRecordingSpeed(vehicle)
	vehicle.cp.speeds.useRecordingSpeed = not vehicle.cp.speeds.useRecordingSpeed;
end;

function courseplay:changeWarningLightsMode(vehicle, changeBy)
	vehicle.cp.warningLightsMode = Utils.clamp(vehicle.cp.warningLightsMode + changeBy, courseplay.WARNING_LIGHTS_NEVER, courseplay.WARNING_LIGHTS_BEACON_ALWAYS);
end;

function courseplay:toggleOpenHudWithMouse(vehicle)
	vehicle.cp.hud.openWithMouse = not vehicle.cp.hud.openWithMouse;
end;

function courseplay:toggleRealisticDriving(vehicle)
	vehicle.cp.realisticDriving = not vehicle.cp.realisticDriving;
end;

function courseplay:toggleSearchCombineMode(vehicle)
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
	local combines = courseplay:getAllCombines();
	vehicle.cp.selectedCombineNumber = Utils.clamp(vehicle.cp.selectedCombineNumber + changeBy, 0, #combines);

	if vehicle.cp.selectedCombineNumber == 0 then
		vehicle.cp.savedCombine = nil;
		vehicle.cp.HUD4savedCombineName = nil;
	else
		vehicle.cp.savedCombine = combines[vehicle.cp.selectedCombineNumber];
		local combineName = vehicle.cp.savedCombine.name or courseplay:loc('COURSEPLAY_COMBINE');
		local x1 = courseplay.hud.col2posX[4];
		local x2 = courseplay.hud.buttonPosX[1] - getTextWidth(0.017, ' (9999m)');
		local shortenedName, firstChar, lastChar = Utils.limitTextToWidth(combineName, 0.017, x2 - x1, false, '...');
		vehicle.cp.HUD4savedCombineName = shortenedName;
	end;

	courseplay:removeActiveCombineFromTractor(vehicle);
end;

function courseplay:removeActiveCombineFromTractor(vehicle)
	if vehicle.cp.activeCombine ~= nil then
		courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine);
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

function courseplay:findDrivers(vehicle)
	local foundDrivers = {}; -- resetting all drivers
	for _,otherVehicle in pairs(g_currentMission.steerables) do
		if otherVehicle.Waypoints ~= nil and otherVehicle.hasCourseplaySpec  then
			if otherVehicle.rootNode ~= vehicle.rootNode and #(otherVehicle.Waypoints) > 0 then
				table.insert(foundDrivers, otherVehicle);
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
		courseplay:setRecordNumber(vehicle, 1);
		vehicle.maxnumber = #(vehicle.Waypoints);
		vehicle.cp.numWaitPoints = src.cp.numWaitPoints;
		vehicle.cp.numCrossingPoints = src.cp.numCrossingPoints;

		courseplay:setIsRecording(vehicle, false);
		courseplay:setRecordingIsPaused(vehicle, false);
		vehicle:setIsCourseplayDriving(false);
		vehicle.cp.distanceCheck = false;
		vehicle.cp.canDrive = true;
		vehicle.cp.abortWork = nil;

		vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = nil, nil, nil;
		vehicle.cp.nextTargets = {};
		if vehicle.cp.activeCombine ~= nil then
			courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine);
		end

		if vehicle.cp.mode == 2 or vehicle.cp.mode == 3 then
			courseplay:setModeState(vehicle, 0);
			-- print(('%s [%s(%d)]: copyCourse(): mode=%d -> set modeState to 0'):format(nameNum(vehicle), curFile, debug.getinfo(1).currentline, vehicle.cp.mode)); -- DEBUG140301
		else
			courseplay:setModeState(vehicle, 1);
			-- print(('%s [%s(%d)]: copyCourse() -> set modeState to 1'):format(nameNum(vehicle), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
		end;
		vehicle.cp.recordingTimer = 1;

		courseplay.signs:updateWaypointSigns(vehicle, 'current');

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
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
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
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
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
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				v.cp.reloadCourseItems = true
				--print(string.format("courseplay.hud:setReloadPageOrder(%s, 2, true) TypeName: %s ;",tostring(v.name), v.typeName))
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
	index = courseplay.courses:getMeOrBestFit(self, index)
	
	if index ~= 0 then
		-- insert first entry
		table.insert(self.cp.hud.courses, self.cp.sorted.item[index])
		i = i+1
		
		-- now search for the next entries
		while i <= hudLines do
			index = courseplay.courses:getNextCourse(self,index)
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
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
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
		index = courseplay.courses:getNextCourse(vehicle,index)
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
		index = courseplay.courses:getNextCourse(vehicle, index, true)
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
			elseif 0 == courseplay.courses:getNextCourse(vehicle, vehicle.cp.sorted.info[ vehicle.cp.hud.courses[n_hudcourses].uid ].sorted_index) then
				next = false
			end
		end
		vehicle.cp.hud.courseListPrev = prev
		vehicle.cp.hud.courseListNext = next
	else
		-- update all vehicles
		for k,v in pairs(g_currentMission.steerables) do
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
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
					elseif 0 == courseplay.courses:getNextCourse(v, v.cp.sorted.info[v.cp.hud.courses[n_hudcourses].uid].sorted_index) then
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

function courseplay:toggleDebugChannel(self, channel, force)
	if courseplay.debugChannels[channel] ~= nil then
		courseplay.debugChannels[channel] = Utils.getNoNil(force, not courseplay.debugChannels[channel]);
		courseplay:buttonsActiveEnabled(self, "debug");
	end;
end;

--Course generation
function courseplay:switchStartingCorner(vehicle)
	vehicle.cp.startingCorner = vehicle.cp.startingCorner + 1;
	if vehicle.cp.startingCorner > 4 then
		vehicle.cp.startingCorner = 1;
	end;
	vehicle.cp.hasStartingCorner = true;
	vehicle.cp.hasStartingDirection = false;
	vehicle.cp.startingDirection = 0;

	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:changeStartingDirection(vehicle)
	-- corners: 1 = SW, 2 = NW, 3 = NE, 4 = SE
	-- directions: 1 = North, 2 = East, 3 = South, 4 = West

	local validDirections = {};
	if vehicle.cp.hasStartingCorner then
		if vehicle.cp.startingCorner == 1 then --SW
			validDirections[1] = 1; --N
			validDirections[2] = 2; --E
		elseif vehicle.cp.startingCorner == 2 then --NW
			validDirections[1] = 2; --E
			validDirections[2] = 3; --S
		elseif vehicle.cp.startingCorner == 3 then --NE
			validDirections[1] = 3; --S
			validDirections[2] = 4; --W
		elseif vehicle.cp.startingCorner == 4 then --SE
			validDirections[1] = 4; --W
			validDirections[2] = 1; --N
		end;

		--would be easier with i=i+1, but more stored variables would be needed
		if vehicle.cp.startingDirection == 0 then
			vehicle.cp.startingDirection = validDirections[1];
		elseif vehicle.cp.startingDirection == validDirections[1] then
			vehicle.cp.startingDirection = validDirections[2];
		elseif vehicle.cp.startingDirection == validDirections[2] then
			vehicle.cp.startingDirection = validDirections[1];
		end;
		vehicle.cp.hasStartingDirection = true;
	end;

	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:toggleReturnToFirstPoint(vehicle)
	vehicle.cp.returnToFirstPoint = not vehicle.cp.returnToFirstPoint;
end;

function courseplay:changeHeadlandNumLanes(vehicle, changeBy)
	vehicle.cp.headland.numLanes = Utils.clamp(vehicle.cp.headland.numLanes + changeBy, 0, vehicle.cp.headland.maxNumLanes);
	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:toggleHeadlandDirection(vehicle)
	vehicle.cp.headland.userDirClockwise = not vehicle.cp.headland.userDirClockwise;
	vehicle.cp.headland.directionButton:setSpriteSectionUVs(vehicle.cp.headland.userDirClockwise and 'headlandDirCW' or 'headlandDirCCW');
end;

function courseplay:toggleHeadlandOrder(vehicle)
	vehicle.cp.headland.orderBefore = not vehicle.cp.headland.orderBefore;
	vehicle.cp.headland.orderButton:setSpriteSectionUVs(vehicle.cp.headland.orderBefore and 'headlandOrdBef' or 'headlandOrdAft');
	-- courseplay:debug(string.format('toggleHeadlandOrder(): orderBefore=%s -> set to %q, setOverlay(orderButton, %d)', tostring(not vehicle.cp.headland.orderBefore), tostring(vehicle.cp.headland.orderBefore), vehicle.cp.headland.orderBefore and 1 or 2), 7);
end;

function courseplay:validateCourseGenerationData(vehicle)
	local numWaypoints = 0;
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		numWaypoints = #(courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points);
	elseif vehicle.Waypoints ~= nil then
		numWaypoints = #(vehicle.Waypoints);
	end;

	local hasEnoughWaypoints = numWaypoints >= 4
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
	courseplay:buttonsActiveEnabled(vehicle, 'generateCourse');

	if courseplay.debugChannels[7] then
		courseplay:debug(string.format("%s: hasGeneratedCourse=%s, hasEnoughWaypoints=%s, hasStartingCorner=%s, hasStartingDirection=%s, numCourses=%s, fieldEdge.selectedField.fieldNum=%s ==> hasValidCourseGenerationData=%s", nameNum(vehicle), tostring(vehicle.cp.hasGeneratedCourse), tostring(hasEnoughWaypoints), tostring(vehicle.cp.hasStartingCorner), tostring(vehicle.cp.hasStartingDirection), tostring(vehicle.cp.numCourses), tostring(vehicle.cp.fieldEdge.selectedField.fieldNum), tostring(vehicle.cp.hasValidCourseGenerationData)), 7);
	end;
end;

function courseplay:validateCanSwitchMode(vehicle)
	vehicle.cp.canSwitchMode = not vehicle:getIsCourseplayDriving() and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and not vehicle.cp.fieldEdge.customField.isCreated;
	if courseplay.debugChannels[12] then
		courseplay:debug(string.format("%s: validateCanSwitchMode(): drive=%s, record=%s, record_pause=%s, customField.isCreated=%s ==> canSwitchMode=%s", nameNum(vehicle), tostring(vehicle:getIsCourseplayDriving()), tostring(vehicle.cp.isRecording), tostring(vehicle.cp.recordingIsPaused), tostring(vehicle.cp.fieldEdge.customField.isCreated), tostring(vehicle.cp.canSwitchMode)), 12);
	end;
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

function courseplay:toggleShovelStopAndGo(vehicle)
	vehicle.cp.shovelStopAndGo = not vehicle.cp.shovelStopAndGo;
end;

function courseplay:changeStartAtPoint(vehicle)
	vehicle.cp.startAtPoint = courseplay:varLoop(vehicle.cp.startAtPoint, 1, courseplay.START_AT_CURRENT_POINT, courseplay.START_AT_NEAREST_POINT);
end;

function courseplay:reloadCoursesFromXML(vehicle)
	courseplay:debug("reloadCoursesFromXML()", 8);
	if g_server ~= nil then
		courseplay.courses:loadCoursesAndFoldersFromXml();

		courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		courseplay:debug("g_currentMission.cp_courses = courseplay.courses:loadCoursesAndFoldersFromXml()", 8);
		if not vehicle:getIsCourseplayDriving() then
			local loadedCoursesBackup = vehicle.cp.loadedCourses;
			courseplay:clearCurrentLoadedCourse(vehicle);
			vehicle.cp.loadedCourses = loadedCoursesBackup;
			courseplay:reloadCourses(vehicle, true);
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
			button:setHovered(false);
		end;
		for i,button in pairs(self.cp.buttons[self.cp.hud.currentPage]) do
			button:setHovered(false);
		end;
		if self.cp.hud.currentPage == 2 then
			for i,button in pairs(self.cp.buttons[-2]) do
				button:setHovered(false);
			end;
		end;

		for line=1,courseplay.hud.numLines do
			self.cp.hud.content.pages[self.cp.hud.currentPage][line][1].isHovered = false;
		end;

		courseplay.buttons:setHoveredButton(self, nil);

		self.cp.hud.mouseWheel.render = false;
	end;
end;

function courseplay:changeDebugChannelSection(vehicle, changeBy)
	courseplay.debugChannelSection = Utils.clamp(courseplay.debugChannelSection + changeBy, 1, ceil(courseplay.numAvailableDebugChannels / courseplay.numDebugChannelButtonsPerLine));
	courseplay.debugChannelSectionEnd = courseplay.numDebugChannelButtonsPerLine * courseplay.debugChannelSection;
	courseplay.debugChannelSectionStart = courseplay.debugChannelSectionEnd - courseplay.numDebugChannelButtonsPerLine + 1;


	-- update buttons' functions, toolTips and disabled status
	for channel = courseplay.debugChannelSectionStart, courseplay.debugChannelSectionEnd do
		local col = ((channel-1) % courseplay.numDebugChannelButtonsPerLine) + 1;
		local button = vehicle.cp.hud.debugChannelButtons[col];
		button:setParameter(channel);
		button:setToolTip(courseplay.debugChannelsDesc[channel]);
	end;
	courseplay:buttonsActiveEnabled(vehicle, 'debug');
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
	-- print(string.format("%s: goToVehicle(): targetVehicle=%q", nameNum(curVehicle), nameNum(targetVehicle)));
	g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(targetVehicle, g_settingsNickname));
	g_currentMission.isPlayerFrozen = false;
	CpManager.playerOnFootMouseEnabled = false;
	InputBinding.setShowMouseCursor(targetVehicle.cp.mouseCursorActive);
end;



--FIELD EDGE PATHS
function courseplay:createFieldEdgeButtons(vehicle)
	if not vehicle.cp.fieldEdge.selectedField.buttonsCreated and courseplay.fields.numAvailableFields > 0 then
		local w, h = courseplay.hud.buttonSize.small.w, courseplay.hud.buttonSize.small.h;
		local mouseWheelArea = {
			x = courseplay.hud.contentMinX,
			w = courseplay.hud.contentMaxWidth,
			h = courseplay.hud.lineHeight
		};
		vehicle.cp.suc.toggleHudButton = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'calculator' }, 'toggleSucHud', nil, courseplay.hud.buttonPosX[4], courseplay.hud.linesButtonPosY[1], w, h, 1, nil, false, false, true);
		vehicle.cp.hud.showSelectedFieldEdgePathButton = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'eye' }, 'toggleSelectedFieldEdgePathShow', nil, courseplay.hud.buttonPosX[3], courseplay.hud.linesButtonPosY[1], w, h, 1, nil, false);
		courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navUp' }, 'setFieldEdgePath',  1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w, h, 1,  5, false);
		courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navDown' }, 'setFieldEdgePath', -1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w, h, 1, -5, false);
		courseplay.button:new(vehicle, 8, nil, 'setFieldEdgePath', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 5, true, true);
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

function courseplay:toggleDrawWaypointsLines(vehicle)
	if not CpManager.isDeveloper then return; end;
	vehicle.cp.drawWaypointsLines = not vehicle.cp.drawWaypointsLines;
	vehicle.cp.toggleDrawWaypointsLinesButton:setActive(vehicle.cp.drawWaypointsLines);
end;

function courseplay:setEngineState(vehicle, on)
	if vehicle == nil or on == nil or vehicle.isMotorStarted == on then
		return;
	end;

	-- driveControl engine start/stop
	if vehicle.cp.hasDriveControl and vehicle.cp.driveControl.hasManualMotorStart then
		local changed = false;
		if on and not vehicle.driveControl.manMotorStart.isMotorStarted then
			vehicle.driveControl.manMotorStart.isMotorStarted = true; -- TODO: timer (800 ms) instead of immediate starting
			changed = true;
		elseif not on and vehicle.driveControl.manMotorStart.isMotorStarted and not vehicle.cp.driveControl.hasMotorKeepTurnedOn then
			vehicle.driveControl.manMotorStart.isMotorStarted = false;
			changed = true;
		end;
		if changed and driveControlInputEvent ~= nil then
			driveControlInputEvent.sendEvent(vehicle);
		end;
		return;
	end;

	-- default
	if vehicle.startMotor and vehicle.stopMotor then
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

function courseplay:addNewTargetVector(vehicle, x, z, trailer)
	local tx, ty, tz = 0,0,0
	if trailer ~= nil then
		tx, ty, tz = localToWorld(trailer.rootNode, x, 0, z);
	else
		tx, ty, tz = localToWorld(vehicle.cp.DirectionNode or vehicle.rootNode, x, 0, z);
	end
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
		courseplay:setInfoText(vehicle, nil);
	end;
	courseplay:buttonsActiveEnabled(vehicle, 'findFirstWaypoint');
end;

function courseplay:canUseWeightStation(vehicle)
	return vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 8;
end;

function courseplay:canScanForWeightStation(vehicle)
	local scan = false;
	if vehicle.cp.mode == 1 or vehicle.cp.mode == 2 then
		scan = vehicle.recordnumber > 2;
	elseif vehicle.cp.mode == 4 or vehicle.cp.mode == 6 then
		scan = vehicle.cp.stopWork ~= nil and vehicle.recordnumber > vehicle.cp.stopWork;
	elseif vehicle.cp.mode == 8 then
		scan = true;
	end;

	return scan;
end;

function courseplay:setSlippingStage(vehicle, stage)
	if vehicle.cp.slippingStage ~= stage then
		courseplay:debug(('%s: setSlippingStage(..., %d)'):format(nameNum(vehicle), stage), 14);
		vehicle.cp.slippingStage = stage;
	end;
end;

-- INGAME MAP ICONS
function courseplay:createMapHotspot(vehicle)
	local name = 'cpDriver';
	if CpManager.ingameMapIconShowText then
		name = '';
		if CpManager.ingameMapIconShowName then
			name = nameNum(vehicle, true) .. '\n';
		end;
		if CpManager.ingameMapIconShowCourse then
			name = name .. ('(%s)'):format(vehicle.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE'));
		end;
	end;

	local iconPath = Utils.getFilename('img/hud.png', courseplay.path);
	local x = vehicle.components[1].lastTranslation[1];
	local y = vehicle.components[1].lastTranslation[3];
	local h = 24 / 1080;
	local w = h / g_screenAspectRatio;
	vehicle.cp.ingameMapHotSpot = g_currentMission.ingameMap:createMapHotspot(name, iconPath, x, y, w, h, false, false, CpManager.ingameMapIconShowText, vehicle.rootNode, false, true);

	if vehicle.cp.ingameMapHotSpot and vehicle.cp.ingameMapHotSpot.overlay then
		courseplay.utils:setOverlayUVsPx(vehicle.cp.ingameMapHotSpot.overlay, courseplay.hud.ingameMapIconsUVs[vehicle.cp.mode], courseplay.hud.baseTextureSize.x, courseplay.hud.baseTextureSize.y);
	end;
end;
function courseplay:deleteMapHotspot(vehicle)
	if vehicle.cp.ingameMapHotSpot then
		g_currentMission.ingameMap:deleteMapHotspot(vehicle.cp.ingameMapHotSpot);
		vehicle.cp.ingameMapHotSpot = nil;
	end;
end;
function courseplay:toggleIngameMapIconShowText()
	CpManager.ingameMapIconShowText = not CpManager.ingameMapIconShowText;
	-- for _,vehicle in pairs(g_currentMission.steerables) do
	for _,vehicle in pairs(CpManager.activeCoursePlayers) do
		if vehicle.cp.ingameMapHotSpot then
			courseplay:deleteMapHotspot(vehicle);
			courseplay:createMapHotspot(vehicle);
			courseplay.hud:setReloadPageOrder(vehicle, 7, true);
		end;
	end;
end;

function courseplay:toggleAlwaysUseFourWD(vehicle)
	vehicle.cp.driveControl.alwaysUseFourWD = not vehicle.cp.driveControl.alwaysUseFourWD;
end;

function courseplay:getAndSetFixedWorldPosition(object)
	if object.cp.fixedWorldPosition == nil then
		object.cp.fixedWorldPosition = {};
		object.cp.fixedWorldPosition.px, object.cp.fixedWorldPosition.py, object.cp.fixedWorldPosition.pz = getWorldTranslation(object.components[1].node);
		object.cp.fixedWorldPosition.rx, object.cp.fixedWorldPosition.ry, object.cp.fixedWorldPosition.rz = getWorldRotation(object.components[1].node);
	end;
	local fwp = object.cp.fixedWorldPosition;
	object:setWorldPosition(fwp.px,fwp.py,fwp.pz, fwp.rx,fwp.ry,fwp.rz, 1);
end;

----------------------------------------------------------------------------------------------------

function courseplay:setCpVar(varName, value)
	if self.cp[varName] ~= value then
		local oldValue = self.cp[varName];
		self.cp[varName] = value;
		courseplay:onCpVarChanged(self, varName, oldValue);
	end;
end;

function courseplay:onCpVarChanged(vehicle, varName, oldValue)
	-- print(('%s: onCpVarChanged(%q, %q) [old value=%q]'):format(nameNum(vehicle), tostring(varName), tostring(vehicle.cp[varName]), tostring(oldValue)));

	-- TODO (Jakob): this is hud related and doesn't really belong here but rather in the hud.lua
	if varName:sub(1, 3) == 'HUD' then
		if Utils.startsWith(varName, 'HUD0') then
			courseplay.hud:setReloadPageOrder(vehicle, 0, true);
		elseif Utils.startsWith(varName, 'HUD1') then
			courseplay.hud:setReloadPageOrder(vehicle, 1, true);
		elseif Utils.startsWith(varName, 'HUD4') then
			courseplay.hud:setReloadPageOrder(vehicle, 4, true);
		end;
	end;
end;