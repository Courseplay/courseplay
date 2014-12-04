function courseplay:setHudContent(vehicle)
	-- BOTTOM GLOBAL INFO
	-- mode icon
	vehicle.cp.hud.content.global[0] = vehicle.cp.mode > 0 and vehicle.cp.mode <= courseplay.numAiModes;

	-- course name
	if vehicle.cp.currentCourseName ~= nil then
		vehicle.cp.hud.content.global[1] = vehicle.cp.currentCourseName;
	elseif vehicle.Waypoints[1] ~= nil then
		vehicle.cp.hud.content.global[1] = courseplay:loc('COURSEPLAY_TEMP_COURSE');
	else
		vehicle.cp.hud.content.global[1] = courseplay:loc('COURSEPLAY_NO_COURSE_LOADED');
	end;

	if vehicle.Waypoints[vehicle.cp.HUDrecordnumber] ~= nil or vehicle.cp.isRecording or vehicle.cp.recordingIsPaused then
		-- waypoints
		if not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused then
			vehicle.cp.hud.content.global[2] = ('%d/%d'):format(vehicle.cp.HUDrecordnumber, vehicle.maxnumber);
		else
			vehicle.cp.hud.content.global[2] = tostring(vehicle.cp.HUDrecordnumber);
		end;

		-- waitPoints
		vehicle.cp.hud.content.global[3] = tostring(vehicle.cp.numWaitPoints);

		-- crossingPoints
		vehicle.cp.hud.content.global[4] = tostring(vehicle.cp.numCrossingPoints);
	else
		vehicle.cp.hud.content.global[2] = nil;
		vehicle.cp.hud.content.global[3] = nil;
		vehicle.cp.hud.content.global[4] = nil;
	end;

	------------------------------------------------------------------

	-- AUTOMATIC PAGE RELOAD BASED ON VARIABLE STATE
	--ALL PAGES
	if vehicle.cp.hud.reloadPage[-1] then
		for page=0,courseplay.hud.numPages do
			courseplay.hud:setReloadPageOrder(vehicle, page, true);
		end;
		courseplay.hud:setReloadPageOrder(vehicle, -1, false);
	end;

	--CURRENT PAGE
	if vehicle.cp.hud.currentPage == 1 then
		if (vehicle.cp.isRecording or vehicle.cp.recordingIsPaused) and vehicle.cp.HUDrecordnumber == 4 and courseplay.utils:hasVarChanged(vehicle, 'HUDrecordnumber') then --record pause action becomes available
			--courseplay.hud:setReloadPageOrder(vehicle, 1, true);
			courseplay:buttonsActiveEnabled(vehicle, 'recording');
		elseif vehicle:getIsCourseplayDriving() then
		end;

	elseif vehicle.cp.hud.currentPage == 3 and vehicle:getIsCourseplayDriving() and (vehicle.cp.mode == 2 or vehicle.cp.mode == 3) then
		for i,varName in pairs({ 'combineOffset', 'turnRadius' }) do
			if courseplay.utils:hasVarChanged(vehicle, varName) then
				courseplay.hud:setReloadPageOrder(vehicle, 3, true);
				break;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 4 then
		if vehicle.cp.savedCombine ~= nil then --Force page 4 reload when combine distance is displayed
			courseplay.hud:setReloadPageOrder(vehicle, 4, true);
		end;

	elseif vehicle.cp.hud.currentPage == 7 then
		if vehicle.cp.copyCourseFromDriver ~= nil or courseplay.utils:hasVarChanged(vehicle, 'totalOffsetX') then --Force page 7 reload when vehicle distance is displayed
			courseplay.hud:setReloadPageOrder(vehicle, 7, true);
		end;
	end;

	-- RELOAD PAGE
	if vehicle.cp.hud.reloadPage[vehicle.cp.hud.currentPage] then
		for line=1,courseplay.hud.numLines do
			for column=1,2 do
				vehicle.cp.hud.content.pages[vehicle.cp.hud.currentPage][line][column].text = nil;
			end;
		end;
		courseplay.hud:loadPage(vehicle, vehicle.cp.hud.currentPage);
	end;
end; --END setHudContent()


function courseplay:renderHud(vehicle)
	if vehicle.cp.suc.active then
		vehicle.cp.hud.backgroundSuc:render();
		if vehicle.cp.suc.selectedFruit.overlay then
			vehicle.cp.suc.selectedFruit.overlay:render();
		end;
	else
		vehicle.cp.hud.background:render();
	end;


	--BUTTONS
	courseplay.buttons:renderButtons(vehicle, vehicle.cp.hud.currentPage);
	if vehicle.cp.hud.mouseWheel.render then
		vehicle.cp.hud.mouseWheel.icon:render();
	end;

	--BOTTOM GLOBAL INFO
	courseplay:setFontSettings('white', false, 'left');
	for i, text in pairs(vehicle.cp.hud.content.global) do
		if text ~= nil then
			if i == 0 then -- mode icon
				if text == true then
					vehicle.cp.hud.currentModeIcon:render();
				end;
			else
				local textX;
				if i == 1 then
					textX = courseplay.hud.bottomInfo.modeTextX;
				elseif i == 2 then
					textX = courseplay.hud.bottomInfo.waypointTextX;
					vehicle.cp.hud.currentWaypointIcon:render();
				elseif i == 3 then
					textX = courseplay.hud.bottomInfo.waitPointsTextX;
					vehicle.cp.hud.waitPointsIcon:render();
				elseif i == 4 then
					textX = courseplay.hud.bottomInfo.crossingPointsTextX;
					vehicle.cp.hud.crossingPointsIcon:render();
				end;
				renderText(textX, courseplay.hud.bottomInfo.textPosY, courseplay.hud.fontSizes.bottomInfo, text);
			end;
		end;
	end


	--VERSION INFO
	if courseplay.versionDisplayStr ~= nil then
		courseplay:setFontSettings("white", false, "right");
		renderText(courseplay.hud.visibleArea.x2 - 0.01, courseplay.hud.infoBasePosY + 0.02, courseplay.hud.fontSizes.version, courseplay.versionDisplayStr);
	end;


	--HUD TITLES
	courseplay:setFontSettings("white", true, "left");
	local hudPageTitle = courseplay.hud.hudTitles[vehicle.cp.hud.currentPage];
	if vehicle.cp.hud.currentPage == 2 then
		if not vehicle.cp.hud.choose_parent and vehicle.cp.hud.filter == '' then
			hudPageTitle = courseplay.hud.hudTitles[vehicle.cp.hud.currentPage][1];
		elseif vehicle.cp.hud.choose_parent then
			hudPageTitle = courseplay.hud.hudTitles[vehicle.cp.hud.currentPage][2];
		elseif vehicle.cp.hud.filter ~= '' then
			hudPageTitle = string.format(courseplay.hud.hudTitles[vehicle.cp.hud.currentPage][3], vehicle.cp.hud.filter);
		end;
	end;
	renderText(courseplay.hud.infoBasePosX + 0.035, courseplay.hud.infoBasePosY + 0.240, courseplay.hud.fontSizes.hudTitle, hudPageTitle);


	--MAIN CONTENT
	courseplay:setFontSettings('white', false);
	local page = vehicle.cp.hud.currentPage;
	for line,columns in pairs(vehicle.cp.hud.content.pages[page]) do
		for column,entry in pairs(columns) do
			if column == 1 and entry.text ~= nil and entry.text ~= '' then
				if entry.isClicked then
					courseplay:setFontSettings('activeRed', false);
				elseif entry.isHovered then
					courseplay:setFontSettings('hover', false);
				end;
				renderText(courseplay.hud.col1posX + entry.indention, courseplay.hud.linesPosY[line], courseplay.hud.fontSizes.contentTitle, entry.text);
				courseplay:setFontSettings('white', false);
			elseif column == 2 and entry.text ~= nil and entry.text ~= "" then
				renderText(vehicle.cp.hud.content.pages[page][line][2].posX, courseplay.hud.linesPosY[line], courseplay.hud.fontSizes.contentValue, entry.text);
			end;
		end;
	end;
	if page == 6 then -- debug channels text
		courseplay:setFontSettings('textDark', true, 'center');
		local channelNum;
		for i,data in ipairs(courseplay.debugButtonPosData) do
			channelNum = courseplay.debugChannelSectionStart + (i - 1);
			renderText(data.textPosX, data.textPosY, courseplay.hud.fontSizes.contentValue, tostring(channelNum));
		end;
		courseplay:setFontSettings('white', false, 'left');
	end;

	-- SEED USAGE CALCULATOR
	if vehicle.cp.suc.active then
		local x = vehicle.cp.suc.textMinX;
		local selectedField = courseplay.fields.fieldData[ vehicle.cp.fieldEdge.selectedField.fieldNum ];
		local selectedFruit = vehicle.cp.suc.selectedFruit;
		courseplay:setFontSettings('shadow', true);
		renderText(x, vehicle.cp.suc.lines.title.posY - 0.001, vehicle.cp.suc.lines.title.fontSize, vehicle.cp.suc.lines.title.text);
		courseplay:setFontSettings('white', true);
		renderText(x, vehicle.cp.suc.lines.title.posY        , vehicle.cp.suc.lines.title.fontSize, vehicle.cp.suc.lines.title.text);

		courseplay:setFontSettings('white', false);
		renderText(x, vehicle.cp.suc.lines.field.posY, vehicle.cp.suc.lines.field.fontSize, selectedField.fieldAreaText);
		renderText(x, vehicle.cp.suc.lines.fruit.posY, vehicle.cp.suc.lines.fruit.fontSize, selectedFruit.sucText);

		renderText(x, vehicle.cp.suc.lines.result.posY, vehicle.cp.suc.lines.result.fontSize, selectedField.seedDataText[selectedFruit.name]);
	end;
end;

function courseplay:setMinHudPage(vehicle, workTool)
	vehicle.cp.minHudPage = 1;

	local hasAttachedCombine = workTool ~= nil and courseplay:isAttachedCombine(workTool);
	if vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or hasAttachedCombine then
		vehicle.cp.minHudPage = 0;
	end;

	courseplay:setHudPage(vehicle, math.max(vehicle.cp.hud.currentPage, vehicle.cp.minHudPage));
	courseplay:debug(string.format("setMinHudPage: minHudPage=%s, currentPage=%s", tostring(vehicle.cp.minHudPage), tostring(vehicle.cp.hud.currentPage)), 18);
	courseplay:buttonsActiveEnabled(vehicle, "pageNav");
end;

function courseplay.hud:loadPage(vehicle, page)
	--self = courseplay.hud

	courseplay:debug(string.format('%s: loadPage(..., %d), set content', nameNum(vehicle), page), 18);

	--PAGE 0: COMBINE SETTINGS
	if page == 0 then
		local combine = vehicle;
		if vehicle.cp.attachedCombineIdx ~= nil then
			combine = vehicle.cp.workTools[vehicle.cp.attachedCombineIdx];
		end;

		if not combine.cp.isChopper then
			--Driver priority
			vehicle.cp.hud.content.pages[0][4][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_PRIORITY');
			vehicle.cp.hud.content.pages[0][4][2].text = combine.cp.driverPriorityUseFillLevel and courseplay:loc('COURSEPLAY_FILLEVEL') or courseplay:loc('COURSEPLAY_DISTANCE');

			if vehicle:getIsCourseplayDriving() and vehicle.cp.mode == 6 then
				vehicle.cp.hud.content.pages[0][5][1].text = courseplay:loc('COURSEPLAY_STOP_DURING_UNLOADING');
				vehicle.cp.hud.content.pages[0][5][2].text = combine.cp.stopWhenUnloading and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
			end;
		end;

		-- no courseplayer!
		if vehicle.cp.HUD0noCourseplayer then
			if vehicle.cp.HUD0wantsCourseplayer then
				vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_REQUESTED');
			else
				vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc('COURSEPLAY_REQUEST_UNLOADING_DRIVER');
			end
		else
			vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc('COURSEPLAY_DRIVER');
			vehicle.cp.hud.content.pages[0][1][2].text = vehicle.cp.HUD0tractorName;

			if vehicle.cp.HUD0tractorForcedToStop then
				vehicle.cp.hud.content.pages[0][2][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_START');
			else
				vehicle.cp.hud.content.pages[0][2][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_STOP');
			end
			vehicle.cp.hud.content.pages[0][3][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_SEND_HOME');

			--chopper
			if combine.cp.isChopper then
				if vehicle.cp.HUD0tractor then
					vehicle.cp.hud.content.pages[0][4][1].text = courseplay:loc('COURSEPLAY_UNLOADING_SIDE');
					if vehicle.cp.HUD0combineForcedSide == 'left' then
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc('COURSEPLAY_LEFT');
					elseif vehicle.cp.HUD0combineForcedSide == 'right' then
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc('COURSEPLAY_RIGHT');
					else
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc('COURSEPLAY_UNLOADING_SIDE_NONE');
					end;

					--manual chopping: initiate/end turning maneuver
					if vehicle.cp.HUD0isManual then
						vehicle.cp.hud.content.pages[0][5][1].text = courseplay:loc('COURSEPLAY_TURN_MANEUVER');
						if vehicle.cp.HUD0turnStage == 0 then
							vehicle.cp.hud.content.pages[0][5][2].text = courseplay:loc('COURSEPLAY_START');
						elseif vehicle.cp.HUD0turnStage == 1 then
							vehicle.cp.hud.content.pages[0][5][2].text = courseplay:loc('COURSEPLAY_FINISH');
						end;
					end;
				end;
			end;
		end;


	--PAGE 1: COURSEPLAY CONTROL
	elseif page == 1 then
		if vehicle.cp.canDrive then
			if not vehicle:getIsCourseplayDriving() then
				vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc('COURSEPLAY_START_COURSE')

				if vehicle.cp.mode ~= 9 then
					vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc('COURSEPLAY_START_AT_POINT');
					if vehicle.cp.startAtPoint == courseplay.START_AT_NEAREST_POINT then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc('COURSEPLAY_NEAREST_POINT');
					elseif vehicle.cp.startAtPoint == courseplay.START_AT_FIRST_POINT then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc('COURSEPLAY_FIRST_POINT');
					elseif vehicle.cp.startAtPoint == courseplay.START_AT_CURRENT_POINT then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc('COURSEPLAY_CURRENT_POINT');
					end;
				end;

				vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc('COURSEPLAY_RESET_COURSE')

				if vehicle.cp.mode == 1 and vehicle.cp.workTools[1] ~= nil and vehicle.cp.workTools[1].allowFillFromAir and vehicle.cp.workTools[1].allowTipDischarge then
					vehicle.cp.hud.content.pages[1][6][1].text = courseplay:loc('COURSEPLAY_FARM_SILO_FILL_TYPE');
					vehicle.cp.hud.content.pages[1][6][2].text = Fillable.fillTypeIndexToDesc[vehicle.cp.multiSiloSelectedFillType].nameI18N;
				end;
			else
				vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc('COURSEPLAY_STOP_COURSE')

				if vehicle.cp.HUD1wait then
					vehicle.cp.hud.content.pages[1][2][1].text = courseplay:loc('COURSEPLAY_CONTINUE')
				end

				if vehicle.cp.HUD1noWaitforFill then
					vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc('COURSEPLAY_DRIVE_NOW')
				end

				if not vehicle.cp.stopAtEnd then
					vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc('COURSEPLAY_STOP_AT_LAST_POINT')
				end

				if vehicle.cp.mode == 4 and vehicle.cp.hasSowingMachine then
					vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc('COURSEPLAY_RIDGEMARKERS');
					vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.ridgeMarkersAutomatic and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_MANUAL');

				elseif vehicle.cp.mode == 6 and vehicle.cp.hasBaleLoader and not vehicle.cp.hasUnloadingRefillingCourse then
					vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc('COURSEPLAY_UNLOADING_ON_FIELD');
					vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.automaticUnloadingOnField and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_MANUAL');
				end;

				if vehicle.cp.tipperHasCover and (vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 5 or vehicle.cp.mode == 6) then
					vehicle.cp.hud.content.pages[1][6][1].text = courseplay:loc('COURSEPLAY_COVER_HANDLING');
					vehicle.cp.hud.content.pages[1][6][2].text = vehicle.cp.automaticCoverHandling and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_MANUAL');
				end;
			end

		elseif not vehicle:getIsCourseplayDriving() then
			if (not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused) and not vehicle.cp.canDrive then
				if #vehicle.Waypoints == 0 then
					vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc('COURSEPLAY_RECORDING_START');
				end;

				--Custom field edge path
				vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc('COURSEPLAY_SCAN_CURRENT_FIELD_EDGES');
				if vehicle.cp.fieldEdge.customField.isCreated then
					vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc('COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER');
					if vehicle.cp.fieldEdge.customField.fieldNum > 0 then
						vehicle.cp.hud.content.pages[1][4][2].text = tostring(vehicle.cp.fieldEdge.customField.fieldNum);
						if vehicle.cp.fieldEdge.customField.selectedFieldNumExists then
							vehicle.cp.hud.content.pages[1][5][1].text = string.format(courseplay:loc('COURSEPLAY_OVERWRITE_CUSTOM_FIELD_EDGE_PATH_IN_LIST'), vehicle.cp.fieldEdge.customField.fieldNum);
						else
							vehicle.cp.hud.content.pages[1][5][1].text = string.format(courseplay:loc('COURSEPLAY_ADD_CUSTOM_FIELD_EDGE_PATH_TO_LIST'), vehicle.cp.fieldEdge.customField.fieldNum);
						end;
					else
						vehicle.cp.hud.content.pages[1][4][2].text = '---';
					end;
				end;
			end;
		end;


	--PAGE 2: COURSE LIST
	elseif page == 2 then
		-- update courses?
		if vehicle.cp.reloadCourseItems then
			courseplay.courses.reload(vehicle)
			CourseplayEvent.sendEvent(vehicle,'self.cp.onMpSetCourses',true)
		end
		-- end update courses

		local numCourses = #(vehicle.cp.hud.courses)

		-- set line text
		local courseName = ''
		for line = 1, numCourses do
			courseName = vehicle.cp.hud.courses[line].displayname
			if courseName == nil or courseName == '' then
				courseName = '-';
			end;
			vehicle.cp.hud.content.pages[2][line][1].text = courseName;
			if vehicle.cp.hud.courses[line].type == 'course' then
				vehicle.cp.hud.content.pages[2][line][1].indention = vehicle.cp.hud.courses[line].level * self.indent;
			else
				vehicle.cp.hud.content.pages[2][line][1].indention = (vehicle.cp.hud.courses[line].level + 1) * self.indent;
			end
		end;
		for line = numCourses+1, self.numLines do
			vehicle.cp.hud.content.pages[2][line][1].text = nil;
		end

		-- enable and disable buttons:
		courseplay:buttonsActiveEnabled(vehicle, 'page2');


	--PAGE 3: MODE 2 SETTINGS
	elseif page == 3 then
		vehicle.cp.hud.content.pages[3][1][1].text = courseplay:loc('COURSEPLAY_COMBINE_OFFSET_HORIZONTAL');
		vehicle.cp.hud.content.pages[3][2][1].text = courseplay:loc('COURSEPLAY_COMBINE_OFFSET_VERTICAL');
		vehicle.cp.hud.content.pages[3][3][1].text = courseplay:loc('COURSEPLAY_TURN_RADIUS');
		vehicle.cp.hud.content.pages[3][4][1].text = courseplay:loc('COURSEPLAY_START_AT');
		vehicle.cp.hud.content.pages[3][5][1].text = courseplay:loc('COURSEPLAY_DRIVE_ON_AT');

		if vehicle.cp.mode == 4 or vehicle.cp.mode == 8 then
			vehicle.cp.hud.content.pages[3][6][1].text = courseplay:loc('COURSEPLAY_REFILL_UNTIL_PCT');
		end;

		if vehicle.cp.modeState ~= nil then
			if vehicle.cp.combineOffset ~= 0 then
				local combineOffsetMode = vehicle.cp.combineOffsetAutoMode and '(auto)' or '(mnl)';
				vehicle.cp.hud.content.pages[3][1][2].text = string.format('%s %.1fm', combineOffsetMode, vehicle.cp.combineOffset);
			else
				vehicle.cp.hud.content.pages[3][1][2].text = 'auto';
			end;
		else
			vehicle.cp.hud.content.pages[3][1][2].text = '---';
		end;

		if vehicle.cp.tipperOffset ~= nil then
			if vehicle.cp.tipperOffset == 0 then
				vehicle.cp.hud.content.pages[3][2][2].text = 'auto';
			elseif vehicle.cp.tipperOffset > 0 then
				vehicle.cp.hud.content.pages[3][2][2].text = string.format('auto+%.1fm', vehicle.cp.tipperOffset);
			elseif vehicle.cp.tipperOffset < 0 then
				vehicle.cp.hud.content.pages[3][2][2].text = string.format('auto%.1fm', vehicle.cp.tipperOffset);
			end;
		else
			vehicle.cp.hud.content.pages[3][2][2].text = '---';
		end;

		if vehicle.cp.turnRadiusAuto ~= nil or vehicle.cp.turnRadius ~= nil then
			local turnRadiusMode = vehicle.cp.turnRadiusAutoMode and '(auto)' or '(mnl)';
			vehicle.cp.hud.content.pages[3][3][2].text = string.format('%s %dm', turnRadiusMode, vehicle.cp.turnRadius);
		else
			vehicle.cp.hud.content.pages[3][3][2].text = '---';
		end;

		vehicle.cp.hud.content.pages[3][4][2].text = vehicle.cp.followAtFillLevel ~= nil and string.format('%d%%', vehicle.cp.followAtFillLevel) or '---';

		vehicle.cp.hud.content.pages[3][5][2].text = vehicle.cp.driveOnAtFillLevel ~= nil and string.format('%d%%', vehicle.cp.driveOnAtFillLevel) or '---';

		if vehicle.cp.mode == 4 or vehicle.cp.mode == 8 then
			vehicle.cp.hud.content.pages[3][6][2].text = ('%d%%'):format(vehicle.cp.refillUntilPct);
		end;


	--PAGE 4: COMBINE ASSIGNMENT
	elseif page == 4 then
		--Line 1: combine search mode (automatic vs manual)
		vehicle.cp.hud.content.pages[4][1][1].text = courseplay:loc('COURSEPLAY_COMBINE_SEARCH_MODE'); --always
		vehicle.cp.hud.content.pages[4][1][2].text = vehicle.cp.searchCombineAutomatically and courseplay:loc('COURSEPLAY_AUTOMATIC_SEARCH') or courseplay:loc('COURSEPLAY_MANUAL_SEARCH');

		--Line 2: select combine manually
		if not vehicle.cp.searchCombineAutomatically then
			vehicle.cp.hud.content.pages[4][2][1].text = courseplay:loc('COURSEPLAY_CHOOSE_COMBINE'); --only if manual
			if vehicle.cp.HUD4savedCombine then
				if vehicle.cp.HUD4savedCombineName == nil then
					vehicle.cp.HUD4savedCombineName = courseplay:loc('COURSEPLAY_COMBINE');
				end;
				vehicle.cp.hud.content.pages[4][2][2].text = string.format('%s (%dm)', vehicle.cp.HUD4savedCombineName, courseplay:distanceToObject(vehicle, vehicle.cp.savedCombine));
			else
				vehicle.cp.hud.content.pages[4][2][2].text = courseplay:loc('COURSEPLAY_NONE');
			end;
		end;

		--[[
		--Line 3: choose field for automatic search --only if automatic
		if vehicle.cp.searchCombineAutomatically and courseplay.fields.numAvailableFields > 0 then
			vehicle.cp.hud.content.pages[4][3][1].text = courseplay:loc('COURSEPLAY_SEARCH_COMBINE_ON_FIELD'):format(vehicle.cp.searchCombineOnField > 0 and tostring(vehicle.cp.searchCombineOnField) or '---');
		end;
		--]]

		--Line 4: current assigned combine
		vehicle.cp.hud.content.pages[4][4][1].text = courseplay:loc('COURSEPLAY_CURRENT'); --always
		vehicle.cp.hud.content.pages[4][4][2].text = vehicle.cp.HUD4hasActiveCombine and vehicle.cp.HUD4combineName or courseplay:loc('COURSEPLAY_NONE');

		--Line 5: remove active combine from tractor
		if vehicle.cp.activeCombine ~= nil then --only if activeCombine
			vehicle.cp.hud.content.pages[4][5][1].text = courseplay:loc('COURSEPLAY_REMOVEACTIVECOMBINEFROMTRACTOR');
		end;


	--PAGE 5: SPEEDS
	elseif page == 5 then
		vehicle.cp.hud.content.pages[5][1][1].text = courseplay:loc('COURSEPLAY_SPEED_TURN');
		vehicle.cp.hud.content.pages[5][2][1].text = courseplay:loc('COURSEPLAY_SPEED_FIELD');
		vehicle.cp.hud.content.pages[5][3][1].text = courseplay:loc('COURSEPLAY_SPEED_MAX');
		vehicle.cp.hud.content.pages[5][4][1].text = courseplay:loc('COURSEPLAY_SPEED_UNLOAD');
		vehicle.cp.hud.content.pages[5][5][1].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE');

		vehicle.cp.hud.content.pages[5][1][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.turn), g_i18n:getSpeedMeasuringUnit());
		vehicle.cp.hud.content.pages[5][2][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.field), g_i18n:getSpeedMeasuringUnit());
		vehicle.cp.hud.content.pages[5][4][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.unload), g_i18n:getSpeedMeasuringUnit());

		if vehicle.cp.speeds.useRecordingSpeed then
			vehicle.cp.hud.content.pages[5][3][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_AUTOMATIC');
			vehicle.cp.hud.content.pages[5][5][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_RECORDING');
		else
			vehicle.cp.hud.content.pages[5][3][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.street), g_i18n:getSpeedMeasuringUnit());
			vehicle.cp.hud.content.pages[5][5][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_MAX');
		end;


	--PAGE 6: GENERAL SETTINGS
	elseif page == 6 then
		-- pathfinding
		vehicle.cp.hud.content.pages[6][1][1].text = courseplay:loc('COURSEPLAY_PATHFINDING');
		vehicle.cp.hud.content.pages[6][1][2].text = vehicle.cp.realisticDriving and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

		-- Open hud key
		vehicle.cp.hud.content.pages[6][2][1].text = courseplay:loc('COURSEPLAY_OPEN_HUD_MODE');
		vehicle.cp.hud.content.pages[6][2][2].text = vehicle.cp.hud.openWithMouse and courseplay.inputBindings.mouse.secondaryTextI18n or courseplay.inputBindings.keyboard.openCloseHudTextI18n;

		-- Waypoint mode
		vehicle.cp.hud.content.pages[6][3][1].text = courseplay:loc('COURSEPLAY_WAYPOINT_MODE');
		vehicle.cp.hud.content.pages[6][3][2].text = courseplay:loc(string.format('COURSEPLAY_WAYPOINT_MODE_%d', vehicle.cp.visualWaypointsMode));

		-- Beacon lights
		vehicle.cp.hud.content.pages[6][4][1].text = courseplay:loc('COURSEPLAY_BEACON_LIGHTS');
		vehicle.cp.hud.content.pages[6][4][2].text = courseplay:loc(string.format('COURSEPLAY_BEACON_LIGHTS_MODE_%d', vehicle.cp.beaconLightsMode));

		-- Waiting point: wait time
		if courseplay:getCanHaveWaitTime(vehicle) then
			vehicle.cp.hud.content.pages[6][5][1].text = courseplay:loc('COURSEPLAY_WAITING_TIME');
			local minutes, seconds = math.floor(vehicle.cp.waitTime/60), vehicle.cp.waitTime % 60;
			local str = courseplay:loc('COURSEPLAY_SECONDS'):format(seconds);
			if minutes > 0 then
				str = courseplay:loc('COURSEPLAY_MINUTES'):format(minutes);
				if seconds > 0 then
					str = str .. ', ' .. courseplay:loc('COURSEPLAY_SECONDS'):format(seconds);
				end;
			end;
			vehicle.cp.hud.content.pages[6][5][2].text = str;
		end;

		-- Ingame map icon text
		if courseplay.ingameMapIconActive and courseplay.ingameMapIconShowTextLoaded then
			vehicle.cp.hud.content.pages[6][6][1].text = courseplay:loc('COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT');
			vehicle.cp.hud.content.pages[6][6][2].text = courseplay.ingameMapIconShowText and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
		end;

		-- Debug channels
		vehicle.cp.hud.content.pages[6][8][1].text = courseplay:loc('COURSEPLAY_DEBUG_CHANNELS');


	--PAGE 7: DRIVING SETTINGS
	elseif page == 7 then
		if vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7 or vehicle.cp.mode == 8 then
			--Lane offset
			if vehicle.cp.mode == 4 or vehicle.cp.mode == 6 then
				vehicle.cp.hud.content.pages[7][1][1].text = courseplay:loc('COURSEPLAY_LANE_OFFSET');
				if vehicle.cp.laneOffset and vehicle.cp.laneOffset ~= 0 then
					if vehicle.cp.laneOffset > 0 then
						vehicle.cp.hud.content.pages[7][1][2].text = string.format('%.1fm (%s)', math.abs(vehicle.cp.laneOffset), courseplay:loc('COURSEPLAY_RIGHT'));
					elseif vehicle.cp.laneOffset < 0 then
						vehicle.cp.hud.content.pages[7][1][2].text = string.format('%.1fm (%s)', math.abs(vehicle.cp.laneOffset), courseplay:loc('COURSEPLAY_LEFT'));
					end;
				else
					vehicle.cp.hud.content.pages[7][1][2].text = '---';
				end;
			end;

			--Symmetrical lane change
			if vehicle.cp.mode == 4 or vehicle.cp.mode == 6 and vehicle.cp.laneOffset ~= 0 then
				vehicle.cp.hud.content.pages[7][2][1].text = courseplay:loc('COURSEPLAY_SYMMETRIC_LANE_CHANGE');
				vehicle.cp.hud.content.pages[7][2][2].text = vehicle.cp.symmetricLaneChange and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
			end;

			--Tool horizontal offset
			vehicle.cp.hud.content.pages[7][3][1].text = courseplay:loc('COURSEPLAY_TOOL_OFFSET_X');
			if vehicle.cp.toolOffsetX and vehicle.cp.toolOffsetX ~= 0 then
				if vehicle.cp.toolOffsetX > 0 then
					vehicle.cp.hud.content.pages[7][3][2].text = string.format('%.1fm (%s)', math.abs(vehicle.cp.toolOffsetX), courseplay:loc('COURSEPLAY_RIGHT'));
				elseif vehicle.cp.toolOffsetX < 0 then
					vehicle.cp.hud.content.pages[7][3][2].text = string.format('%.1fm (%s)', math.abs(vehicle.cp.toolOffsetX), courseplay:loc('COURSEPLAY_LEFT'));
				end;
			else
				vehicle.cp.hud.content.pages[7][3][2].text = '---';
			end;

			--Tool vertical offset
			vehicle.cp.hud.content.pages[7][4][1].text = courseplay:loc('COURSEPLAY_TOOL_OFFSET_Z');
			if vehicle.cp.toolOffsetZ and vehicle.cp.toolOffsetZ ~= 0 then
				if vehicle.cp.toolOffsetZ > 0 then
					vehicle.cp.hud.content.pages[7][4][2].text = string.format('%.1fm (%s)', math.abs(vehicle.cp.toolOffsetZ), courseplay:loc('COURSEPLAY_FRONT'));
				elseif vehicle.cp.toolOffsetZ < 0 then
					vehicle.cp.hud.content.pages[7][4][2].text = string.format('%.1fm (%s)', math.abs(vehicle.cp.toolOffsetZ), courseplay:loc('COURSEPLAY_BACK'));
				end;
			else
				vehicle.cp.hud.content.pages[7][4][2].text = '---';
			end;
		end;

		--Copy course from driver
		vehicle.cp.hud.content.pages[7][5][1].text = courseplay:loc('COURSEPLAY_COPY_COURSE');
		if vehicle.cp.copyCourseFromDriver ~= nil then
			local driverName = vehicle.cp.copyCourseFromDriver.name or courseplay:loc('COURSEPLAY_VEHICLE');
			vehicle.cp.hud.content.pages[7][5][2].text = string.format('%s (%dm)', driverName, courseplay:distanceToObject(vehicle, vehicle.cp.copyCourseFromDriver));
			vehicle.cp.hud.content.pages[7][6][2].text = '(' .. (vehicle.cp.copyCourseFromDriver.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE')) .. ')';
		else
			vehicle.cp.hud.content.pages[7][5][2].text = courseplay:loc('COURSEPLAY_NONE');
		end;


	-- PAGE 8: COURSE GENERATION
	elseif page == 8 then
		-- line 1 = field edge path
		vehicle.cp.hud.content.pages[8][1][1].text = courseplay:loc('COURSEPLAY_FIELD_EDGE_PATH');
		if courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
			vehicle.cp.hud.content.pages[8][1][2].text = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].name;
		elseif #vehicle.Waypoints >= 4 then
			vehicle.cp.hud.content.pages[8][1][2].text = courseplay:loc('COURSEPLAY_CURRENTLY_LOADED_COURSE');
		else
			vehicle.cp.hud.content.pages[8][1][2].text = '---';
		end;

		-- line 2 = work width
		vehicle.cp.hud.content.pages[8][2][1].text = courseplay:loc('COURSEPLAY_WORK_WIDTH');
		vehicle.cp.hud.content.pages[8][2][2].text = vehicle.cp.workWidth ~= nil and string.format('%.1fm', vehicle.cp.workWidth) or '---';

		-- line 3 = starting corner
		vehicle.cp.hud.content.pages[8][3][1].text = courseplay:loc('COURSEPLAY_STARTING_CORNER');
		-- 1 = SW, 2 = NW, 3 = NE, 4 = SE
		if vehicle.cp.hasStartingCorner then
			vehicle.cp.hud.content.pages[8][3][2].text = courseplay:loc(string.format('COURSEPLAY_CORNER_%d', vehicle.cp.startingCorner)); -- NE/SE/SW/NW
		else
			vehicle.cp.hud.content.pages[8][3][2].text = '---';
		end;

		-- line 4 = starting direction
		vehicle.cp.hud.content.pages[8][4][1].text = courseplay:loc('COURSEPLAY_STARTING_DIRECTION');
		-- 1 = North, 2 = East, 3 = South, 4 = West
		if vehicle.cp.hasStartingDirection then
			vehicle.cp.hud.content.pages[8][4][2].text = courseplay:loc(string.format('COURSEPLAY_DIRECTION_%d', vehicle.cp.startingDirection)); -- East/South/West/North
		else
			vehicle.cp.hud.content.pages[8][4][2].text = '---';
		end;

		-- line 5 = return to first point
		vehicle.cp.hud.content.pages[8][5][1].text = courseplay:loc('COURSEPLAY_RETURN_TO_FIRST_POINT');
		vehicle.cp.hud.content.pages[8][5][2].text = vehicle.cp.returnToFirstPoint and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

		-- line 6 = headland
		vehicle.cp.hud.content.pages[8][6][1].text = courseplay:loc('COURSEPLAY_HEADLAND');
		vehicle.cp.hud.content.pages[8][6][2].text = vehicle.cp.headland.numLanes ~= 0 and tostring(vehicle.cp.headland.numLanes) or '-';


	-- PAGE 9: SHOVEL SETTINGS
	elseif page == 9 then
		vehicle.cp.hud.content.pages[9][1][1].text = courseplay:loc('COURSEPLAY_SHOVEL_LOADING_POSITION');
		vehicle.cp.hud.content.pages[9][2][1].text = courseplay:loc('COURSEPLAY_SHOVEL_TRANSPORT_POSITION');
		vehicle.cp.hud.content.pages[9][3][1].text = courseplay:loc('COURSEPLAY_SHOVEL_PRE_UNLOADING_POSITION');
		vehicle.cp.hud.content.pages[9][4][1].text = courseplay:loc('COURSEPLAY_SHOVEL_UNLOADING_POSITION');

		for state=2,5 do
			vehicle.cp.hud.content.pages[9][state-1][2].text = vehicle.cp.hasShovelStatePositions[state] and 'OK' or '';
		end;

		vehicle.cp.hud.content.pages[9][5][1].text = courseplay:loc('COURSEPLAY_SHOVEL_STOP_AND_GO');
		vehicle.cp.hud.content.pages[9][5][2].text = vehicle.cp.shovelStopAndGo and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

	end; -- END if page == n

	courseplay.hud:setReloadPageOrder(vehicle, page, false);
end;

function courseplay.hud:setReloadPageOrder(vehicle, page, bool)
	if vehicle.cp.hud.reloadPage[page] ~= bool then
		vehicle.cp.hud.reloadPage[page] = bool;
		if courseplay.debugChannels[18] and bool == true then
			courseplay:debug(string.format('%s: set reloadPage[%d] to %s (called from %s)', nameNum(vehicle), page, tostring(bool), courseplay.utils:getFnCallPath(4)), 18);
		end;
	end;
end;