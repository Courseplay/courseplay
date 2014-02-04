function courseplay:setHudContent(vehicle)
	--GLOBAL
	if vehicle.cp.mode > 0 and vehicle.cp.mode <= courseplay.numAiModes then
		vehicle.cp.hud.content.global[1] = courseplay:loc(string.format("CourseMode%d", vehicle.cp.mode));
	else
		vehicle.cp.hud.content.global[1] = "---";
	end;

	if vehicle.cp.currentCourseName ~= nil then
		vehicle.cp.hud.content.global[2] = string.format("%s %s", courseplay:loc("CPCourse"), vehicle.cp.currentCourseName);
	elseif vehicle.Waypoints[1] ~= nil then
		vehicle.cp.hud.content.global[2] = string.format("%s %s", courseplay:loc("CPCourse"), courseplay:loc("CPtempCourse"));
	else
		vehicle.cp.hud.content.global[2] = courseplay:loc("CPNoCourseLoaded");
	end;
	if vehicle.Waypoints[vehicle.cp.HUDrecordnumber] ~= nil then
		vehicle.cp.hud.content.global[3] = string.format("%s%s/%s\t%s%s\t%s%s", courseplay:loc("CPWaypoint"), tostring(vehicle.cp.HUDrecordnumber), tostring(vehicle.maxnumber), courseplay:loc('COURSEPLAY_WAITPOINTS'), tostring(vehicle.cp.numWaitPoints), courseplay:loc('COURSEPLAY_CROSSING_POINTS'), tostring(vehicle.cp.numCrossingPoints));
	elseif vehicle.cp.isRecording or vehicle.cp.recordingIsPaused then
		vehicle.cp.hud.content.global[3] = string.format("%s%d\t%s%d\t%s%d", courseplay:loc("CPWaypoint"), vehicle.cp.HUDrecordnumber, courseplay:loc('COURSEPLAY_WAITPOINTS'), vehicle.cp.numWaitPoints, courseplay:loc('COURSEPLAY_CROSSING_POINTS'), vehicle.cp.numCrossingPoints);
	else
		vehicle.cp.hud.content.global[3] = courseplay:loc("CPNoWaypoint");
	end

	------------------------------------------------------------------

	--ALL PAGES
	if vehicle.cp.hud.reloadPage[-1] then
		for page=0,courseplay.hud.numPages do
			courseplay.hud:setReloadPageOrder(vehicle, page, true);
		end;
		courseplay.hud:setReloadPageOrder(vehicle, -1, false);
	end;

	--CURRENT PAGE
	if vehicle.cp.hud.currentPage == 0 then
		for i,varName in pairs({ 'HUD0noCourseplayer', 'HUD0wantsCourseplayer', 'HUD0tractorName', 'HUD0tractorForcedToStop', 'HUD0tractor', 'HUD0combineForcedSide', 'HUD0isManual', 'HUD0turnStage' }) do
			if courseplay.utils:hasVarChanged(vehicle, varName) then
				courseplay.hud:setReloadPageOrder(vehicle, 0, true);
				break;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 1 then
		if (vehicle.cp.isRecording or vehicle.cp.recordingIsPaused) and vehicle.cp.HUDrecordnumber == 4 and courseplay.utils:hasVarChanged(vehicle, 'HUDrecordnumber') then --record pause action becomes available
			--courseplay.hud:setReloadPageOrder(vehicle, 1, true);
			courseplay:buttonsActiveEnabled(vehicle, 'recording');
		elseif vehicle.drive then
			for i,varName in pairs({ --[['HUD1notDrive',]] 'HUD1goOn', 'HUD1noWaitforFill' }) do
				if courseplay.utils:hasVarChanged(vehicle, varName) then
					courseplay.hud:setReloadPageOrder(vehicle, 1, true);
					break;
				end;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 3 and vehicle.drive and (vehicle.cp.mode == 2 or vehicle.cp.mode == 3) then
		for i,varName in pairs({ 'combineOffset', 'turnRadius' }) do
			if courseplay.utils:hasVarChanged(vehicle, varName) then
				courseplay.hud:setReloadPageOrder(vehicle, 3, true);
				break;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 4 then
		if vehicle.cp.savedCombine ~= nil then --Force page 4 reload when combine distance is displayed
			courseplay.hud:setReloadPageOrder(vehicle, 4, true);
		else
			for i,varName in pairs({ 'HUD4combineName', 'HUD4hasActiveCombine', 'HUD4savedCombine', 'HUD4savedCombineName' }) do
				if courseplay.utils:hasVarChanged(vehicle, varName) then
					courseplay.hud:setReloadPageOrder(vehicle, 4, true);
					break;
				end;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 7 then
		if vehicle.cp.copyCourseFromDriver ~= nil or courseplay.utils:hasVarChanged(vehicle, 'totalOffsetX') then --Force page 7 reload when vehicle distance is displayed
			courseplay.hud:setReloadPageOrder(vehicle, 7, true);
		end;
	end;

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
	vehicle.cp.hud.background:render();

	--BUTTONS
	courseplay:renderButtons(vehicle, vehicle.cp.hud.currentPage);
	if vehicle.cp.hud.mouseWheel.render then
		vehicle.cp.hud.mouseWheel.icon:render();
	end;

	--BOTTOM GLOBAL INFO
	courseplay:setFontSettings("white", false, "left");
	for v, text in pairs(vehicle.cp.hud.content.global) do
		if text ~= nil then
			renderText(courseplay.hud.infoBasePosX + 0.006, courseplay.hud.linesBottomPosY[v], 0.017, text); --ORIG: +0.003
		end;
	end


	--VERSION INFO
	if courseplay.versionDisplayStr ~= nil then
		courseplay:setFontSettings("white", false, "right");
		renderText(courseplay.hud.visibleArea.x2 - 0.008, courseplay.hud.infoBasePosY + 0.016, 0.012, courseplay.versionDisplayStr);
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
	renderText(courseplay.hud.infoBasePosX + 0.060, courseplay.hud.infoBasePosY + 0.240, 0.021, hudPageTitle);


	--MAIN CONTENT
	courseplay:setFontSettings("white", false);
	local page = vehicle.cp.hud.currentPage;
	for line,columns in pairs(vehicle.cp.hud.content.pages[page]) do
		for column,entry in pairs(columns) do
			if column == 1 and entry.text ~= nil and entry.text ~= "" then
				if entry.isHovered then
					courseplay:setFontSettings("hover", false);
				end;
				renderText(courseplay.hud.infoBasePosX + 0.005 + entry.indention, courseplay.hud.linesPosY[line], 0.019, entry.text);
				courseplay:setFontSettings("white", false);
			elseif column == 2 and entry.text ~= nil and entry.text ~= "" then
				renderText(vehicle.cp.hud.content.pages[page][line][2].posX, courseplay.hud.linesPosY[line], 0.017, entry.text);
			end;
		end;
	end;
end;

function courseplay:setMinHudPage(vehicle, workTool)
	vehicle.cp.minHudPage = 1;

	local hasAttachedCombine = workTool ~= nil and courseplay:isAttachedCombine(workTool);
	if vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or hasAttachedCombine then
		vehicle.cp.minHudPage = 0;
	end;

	courseplay:setHudPage(vehicle, math.max(vehicle.cp.hud.currentPage, vehicle.cp.minHudPage));
	courseplay:debug(string.format("setMinHudPage: minHudPage=%s, currentPage=%s", tostring(vehicle.cp.minHudPage), tostring(vehicle.cp.hud.currentPage)), 12);
	courseplay:buttonsActiveEnabled(vehicle, "pageNav");
end;

function courseplay.hud:loadPage(vehicle, page)
	--self = courseplay.hud

	courseplay:debug(string.format('%s: loadPage(..., %d), set content', nameNum(vehicle), page), 12);

	--PAGE 0: COMBINE SETTINGS
	if page == 0 then
		local combine = vehicle;
		if vehicle.cp.attachedCombineIdx ~= nil then
			combine = vehicle.tippers[vehicle.cp.attachedCombineIdx];
		end;

		if not combine.cp.isChopper then
			--Driver priority
			vehicle.cp.hud.content.pages[0][4][1].text = courseplay:loc("COURSEPLAY_DRIVERPRIOTITY");
			vehicle.cp.hud.content.pages[0][4][2].text = combine.cp.driverPriorityUseFillLevel and courseplay:loc("COURSEPLAY_FILLEVEL") or courseplay:loc("CPDistance");

			vehicle.cp.hud.content.pages[0][5][1].text = courseplay:loc('COURSEPLAY_STOP_DURING_UNLOADING');
			vehicle.cp.hud.content.pages[0][5][2].text = combine.cp.stopWhenUnloading and courseplay:loc("CPactivated") or courseplay:loc("CPdeactivated");
		end;

		-- no courseplayer!
		if vehicle.cp.HUD0noCourseplayer then
			if vehicle.cp.HUD0wantsCourseplayer then
				vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc("CoursePlayCalledPlayer");
			else
				vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc("CoursePlayCallPlayer");
			end
		else
			vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc("CoursePlayPlayer");
			vehicle.cp.hud.content.pages[0][1][2].text = vehicle.cp.HUD0tractorName;

			if vehicle.cp.HUD0tractorForcedToStop then
				vehicle.cp.hud.content.pages[0][2][1].text = courseplay:loc("CoursePlayPlayerStart");
			else
				vehicle.cp.hud.content.pages[0][2][1].text = courseplay:loc("CoursePlayPlayerStop");
			end
			vehicle.cp.hud.content.pages[0][3][1].text = courseplay:loc("CoursePlayPlayerSendHome");

			--chopper
			if combine.cp.isChopper then
				if vehicle.cp.HUD0tractor then
					vehicle.cp.hud.content.pages[0][4][1].text = courseplay:loc("CoursePlayPlayerSwitchSide");
					if vehicle.cp.HUD0combineForcedSide == "left" then
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc("COURSEPLAY_LEFT");
					elseif vehicle.cp.HUD0combineForcedSide == "right" then
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc("COURSEPLAY_RIGHT");
					else
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc("CoursePlayPlayerSideNone");
					end;

					--manual chopping: initiate/end turning maneuver
					if vehicle.cp.HUD0isManual then
						vehicle.cp.hud.content.pages[0][5][1].text = courseplay:loc("CPturnManeuver");
						if vehicle.cp.HUD0turnStage == 0 then
							vehicle.cp.hud.content.pages[0][5][2].text = courseplay:loc("CPStart");
						elseif vehicle.cp.HUD0turnStage == 1 then
							vehicle.cp.hud.content.pages[0][5][2].text = courseplay:loc("CPEnd");
						end;
					end;
				end;
			end;
		end;


	--PAGE 1: COURSEPLAY CONTROL
	elseif page == 1 then
		if vehicle.cp.canDrive then
			if not vehicle.drive then
				vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc("CoursePlayStart")

				if vehicle.cp.mode ~= 9 then
					vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc("cpStartAtFirstPoint");
					if vehicle.cp.startAtFirstPoint then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc("cpFirstPoint");
					else
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc("cpNearestPoint");
					end;
				end;

				vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc("CourseReset")
			else
				vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc("CoursePlayStop")

				if vehicle.cp.HUD1goOn then
					vehicle.cp.hud.content.pages[1][2][1].text = courseplay:loc("CourseWaitpointStart")
				end

				if vehicle.cp.HUD1noWaitforFill then
					vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc("NoWaitforfill")
				end

				if not vehicle.cp.stopAtEnd then
					vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc("CoursePlayStopEnd")
				end

				if vehicle.cp.mode == 4 and vehicle.cp.hasSowingMachine then
					vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc("CPridgeMarkers");
					vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.ridgeMarkersAutomatic and courseplay:loc("CPautomatic") or courseplay:loc("CPmanual");

				elseif vehicle.cp.mode == 6 and vehicle.cp.hasBaleLoader and not vehicle.cp.hasUnloadingRefillingCourse then
					vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc("CPunloadingOnField");
					vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.automaticUnloadingOnField and courseplay:loc("CPautomatic") or courseplay:loc("CPmanual");
				end;

				if vehicle.cp.tipperHasCover and (vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 5 or vehicle.cp.mode == 6) then
					vehicle.cp.hud.content.pages[1][6][1].text = courseplay:loc('COURSEPLAY_COVER_HANDLING');
					vehicle.cp.hud.content.pages[1][6][2].text = vehicle.cp.automaticCoverHandling and courseplay:loc("CPautomatic") or courseplay:loc("CPmanual");
				end;
			end

		elseif not vehicle.drive then
			if (not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused) and not vehicle.cp.canDrive then
				if (#(vehicle.Waypoints) == 0) then
					vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc("PointRecordStart");
				end;

				--Custom field edge path
				vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc("COURSEPLAY_SCAN_CURRENT_FIELD_EDGES");
				if vehicle.cp.fieldEdge.customField.isCreated then
					vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc("COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER");
					if vehicle.cp.fieldEdge.customField.fieldNum > 0 then
						vehicle.cp.hud.content.pages[1][4][2].text = tostring(vehicle.cp.fieldEdge.customField.fieldNum);
						if vehicle.cp.fieldEdge.customField.selectedFieldNumExists then
							vehicle.cp.hud.content.pages[1][5][1].text = string.format(courseplay:loc("COURSEPLAY_OVERWRITE_CUSTOM_FIELD_EDGE_PATH_IN_LIST"), vehicle.cp.fieldEdge.customField.fieldNum);
						else
							vehicle.cp.hud.content.pages[1][5][1].text = string.format(courseplay:loc("COURSEPLAY_ADD_CUSTOM_FIELD_EDGE_PATH_TO_LIST"), vehicle.cp.fieldEdge.customField.fieldNum);
						end;
					else
						vehicle.cp.hud.content.pages[1][4][2].text = "---";
					end;
				end;
			end;
		end;


	--PAGE 2: COURSE LIST
	elseif page == 2 then
		-- update courses?
		if vehicle.cp.reloadCourseItems then
			courseplay.courses.reload(vehicle)
			CourseplayEvent.sendEvent(vehicle,"self.cp.onMpSetCourses",true)
		end
		-- end update courses

		local numCourses = #(vehicle.cp.hud.courses)

		-- set line text
		local courseName = ""
		for line = 1, numCourses do
			courseName = vehicle.cp.hud.courses[line].displayname
			if courseName == nil or courseName == "" then
				courseName = "-";
			end;
			vehicle.cp.hud.content.pages[2][line][1].text = courseName;
			if vehicle.cp.hud.courses[line].type == "course" then
				vehicle.cp.hud.content.pages[2][line][1].indention = vehicle.cp.hud.courses[line].level * self.offset
			else
				vehicle.cp.hud.content.pages[2][line][1].indention = (vehicle.cp.hud.courses[line].level + 1) * self.offset
			end
		end;
		for line = numCourses+1, self.numLines do
			vehicle.cp.hud.content.pages[2][line][1].text = nil;
		end

		-- enable and disable buttons:
		--courseplay.buttonsActiveEnabled(nil, vehicle, 'page2')
		courseplay:buttonsActiveEnabled(vehicle, 'page2');


	--PAGE 3: MODE 2 SETTINGS
	elseif page == 3 then
		vehicle.cp.hud.content.pages[3][1][1].text = courseplay:loc("CPCombineOffset") --"seitl. Abstand:"
		vehicle.cp.hud.content.pages[3][2][1].text = courseplay:loc("CPVerticalOffset") --"vertikaler Abstand:"
		vehicle.cp.hud.content.pages[3][3][1].text = courseplay:loc("CPTurnRadius") --"Wenderadius:"
		vehicle.cp.hud.content.pages[3][4][1].text = courseplay:loc("CPRequiredFillLevel") --"Start bei %:"
		vehicle.cp.hud.content.pages[3][5][1].text = courseplay:loc("NoWaitforfillAt") --"abfahren bei %:"

		if vehicle.cp.modeState ~= nil then
			if vehicle.cp.combineOffset ~= 0 then
				local combineOffsetMode = vehicle.cp.combineOffsetAutoMode and "(auto)" or "(mnl)";
				vehicle.cp.hud.content.pages[3][1][2].text = string.format("%s %.1f", combineOffsetMode, vehicle.cp.combineOffset);
			else
				vehicle.cp.hud.content.pages[3][1][2].text = "auto";
			end;
		else
			vehicle.cp.hud.content.pages[3][1][2].text = "---";
		end;

		if vehicle.cp.tipperOffset ~= nil then
			if vehicle.cp.tipperOffset == 0 then
				vehicle.cp.hud.content.pages[3][2][2].text = "auto";
			elseif vehicle.cp.tipperOffset > 0 then
				vehicle.cp.hud.content.pages[3][2][2].text = string.format("auto+%.1f", vehicle.cp.tipperOffset);
			elseif vehicle.cp.tipperOffset < 0 then
				vehicle.cp.hud.content.pages[3][2][2].text = string.format("auto%.1f", vehicle.cp.tipperOffset);
			end;
		else
			vehicle.cp.hud.content.pages[3][2][2].text = "---";
		end;

		if vehicle.cp.turnRadiusAuto ~= nil or vehicle.cp.turnRadius ~= nil then
			local turnRadiusMode = vehicle.cp.turnRadiusAutoMode and '(auto)' or '(mnl)';
			vehicle.cp.hud.content.pages[3][3][2].text = string.format("%s %d", turnRadiusMode, vehicle.cp.turnRadius);
		else
			vehicle.cp.hud.content.pages[3][3][2].text = "---";
		end;

		vehicle.cp.hud.content.pages[3][4][2].text = vehicle.cp.followAtFillLevel ~= nil and string.format("%d", vehicle.cp.followAtFillLevel) or '---';

		vehicle.cp.hud.content.pages[3][5][2].text = vehicle.cp.driveOnAtFillLevel ~= nil and string.format("%d", vehicle.cp.driveOnAtFillLevel) or '---';


	--PAGE 4: COMBINE ASSIGNMENT
	elseif page == 4 then
		--Line 1: combine search mode (automatic vs manual)
		vehicle.cp.hud.content.pages[4][1][1].text = courseplay:loc("COURSEPLAY_COMBINE_SEARCH_MODE"); --always
		vehicle.cp.hud.content.pages[4][1][2].text = vehicle.cp.searchCombineAutomatically and courseplay:loc("COURSEPLAY_AUTOMATIC_SEARCH") or courseplay:loc("COURSEPLAY_MANUAL_SEARCH");

		--Line 2: select combine manually
		if not vehicle.cp.searchCombineAutomatically then
			vehicle.cp.hud.content.pages[4][2][1].text = courseplay:loc("COURSEPLAY_CHOOSE_COMBINE"); --only if manual
			if vehicle.cp.HUD4savedCombine then
				if vehicle.cp.HUD4savedCombineName == nil then
					vehicle.cp.HUD4savedCombineName = courseplay:loc("CPCombine");
				end;
				vehicle.cp.hud.content.pages[4][2][2].text = string.format("%s (%dm)", vehicle.cp.HUD4savedCombineName, courseplay:distance_to_object(vehicle, vehicle.cp.savedCombine));
			else
				vehicle.cp.hud.content.pages[4][2][2].text = courseplay:loc("CPNone");
			end;
		end;

		--[[
		--Line 3: choose field for automatic search --only if automatic
		if vehicle.cp.searchCombineAutomatically and courseplay.fields.numAvailableFields > 0 then
			vehicle.cp.hud.content.pages[4][3][1].text = courseplay:loc("COURSEPLAY_SEARCH_COMBINE_ON_FIELD"):format(vehicle.cp.searchCombineOnField > 0 and tostring(vehicle.cp.searchCombineOnField) or '---');
		end;
		--]]

		--Line 4: current assigned combine
		vehicle.cp.hud.content.pages[4][4][1].text = courseplay:loc("COURSEPLAY_CURRENT"); --always
		vehicle.cp.hud.content.pages[4][4][2].text = vehicle.cp.HUD4hasActiveCombine and vehicle.cp.HUD4combineName or courseplay:loc("CPNone");

		--Line 5: remove active combine from tractor
		if vehicle.cp.activeCombine ~= nil then --only if activeCombine
			vehicle.cp.hud.content.pages[4][5][1].text = courseplay:loc('COURSEPLAY_REMOVEACTIVECOMBINEFROMTRACTOR');
		end;


	--PAGE 5: SPEEDS
	elseif page == 5 then
		vehicle.cp.hud.content.pages[5][1][1].text = courseplay:loc("CPTurnSpeed") -- "Wendemanöver:"
		vehicle.cp.hud.content.pages[5][2][1].text = courseplay:loc("CPFieldSpeed") -- "Auf dem Feld:"
		vehicle.cp.hud.content.pages[5][3][1].text = courseplay:loc("CPMaxSpeed") -- "Auf Straße:"
		vehicle.cp.hud.content.pages[5][4][1].text = courseplay:loc("CPUnloadSpeed") -- "Abladen (BGA):"
		vehicle.cp.hud.content.pages[5][5][1].text = courseplay:loc("CPuseSpeed") -- "Geschwindigkeit:"

		vehicle.cp.hud.content.pages[5][1][2].text = string.format("%d %s", g_i18n:getSpeed(vehicle.cp.speeds.turn   * 3600), g_i18n:getText("speedometer"));
		vehicle.cp.hud.content.pages[5][2][2].text = string.format("%d %s", g_i18n:getSpeed(vehicle.cp.speeds.field  * 3600), g_i18n:getText("speedometer"));
		vehicle.cp.hud.content.pages[5][4][2].text = string.format("%d %s", g_i18n:getSpeed(vehicle.cp.speeds.unload * 3600), g_i18n:getText("speedometer"));

		if vehicle.cp.speeds.useRecordingSpeed then
			vehicle.cp.hud.content.pages[5][3][2].text = courseplay:loc("CPautomaticSpeed");
			vehicle.cp.hud.content.pages[5][5][2].text = courseplay:loc("CPuseSpeed1") -- "wie beim einfahren"
		else
			vehicle.cp.hud.content.pages[5][3][2].text = string.format("%d %s", g_i18n:getSpeed(vehicle.cp.speeds.max * 3600), g_i18n:getText("speedometer"));
			vehicle.cp.hud.content.pages[5][5][2].text = courseplay:loc("CPuseSpeed2") -- "maximale Geschwindigkeit"
		end;

	--PAGE 6: GENERAL SETTINGS
	elseif page == 6 then
		--aStar
		vehicle.cp.hud.content.pages[6][1][1].text = courseplay:loc("CPaStar");
		vehicle.cp.hud.content.pages[6][1][2].text = vehicle.cp.realisticDriving and courseplay:loc("CPactivated") or courseplay:loc("CPdeactivated");

		--Open hud key
		vehicle.cp.hud.content.pages[6][2][1].text = courseplay:loc("CPopenHud");
		vehicle.cp.hud.content.pages[6][2][2].text = vehicle.cp.hud.openWithMouse and courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName or courseplay.inputBindings.keyboard.COURSEPLAY_HUD_COMBINED.displayName;

		--Waypoint mode
		vehicle.cp.hud.content.pages[6][3][1].text = courseplay:loc("CPWPs");
		vehicle.cp.hud.content.pages[6][3][2].text = courseplay:loc(string.format("WaypointMode%d", vehicle.cp.visualWaypointsMode));

		--Beacon lights
		vehicle.cp.hud.content.pages[6][4][1].text = courseplay:loc("COURSEPLAY_BEACON_LIGHTS");
		vehicle.cp.hud.content.pages[6][4][2].text = courseplay:loc(string.format("COURSEPLAY_BEACON_LIGHTS_MODE_%d", vehicle.cp.beaconLightsMode));

		--Waiting point: wait time
		if not (vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7) then
			vehicle.cp.hud.content.pages[6][5][1].text = courseplay:loc("CPWaitTime");
			local minutes, seconds = math.floor(vehicle.cp.waitTime/60), vehicle.cp.waitTime % 60;
			local str = string.format(courseplay:loc("COURSEPLAY_SECONDS"), seconds);
			if minutes > 0 then
				str = string.format(courseplay:loc("COURSEPLAY_MINUTES"), minutes);
				if seconds > 0 then
					str = str .. ', ' .. string.format(courseplay:loc("COURSEPLAY_SECONDS"), seconds);
				end;
			end;
			vehicle.cp.hud.content.pages[6][5][2].text = str;
		end;

		--Debug channels
		vehicle.cp.hud.content.pages[6][6][1].text = courseplay:loc("CPDebugChannels");


	--PAGE 6: DRIVING SETTINGS
	elseif page == 7 then
		if vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7 or vehicle.cp.mode == 8 then
			--Lane offset
			if vehicle.cp.mode == 4 or vehicle.cp.mode == 6 then
				vehicle.cp.hud.content.pages[7][1][1].text = courseplay:loc("COURSEPLAY_LANE_OFFSET");
				if vehicle.cp.laneOffset and vehicle.cp.laneOffset ~= 0 then
					if vehicle.cp.laneOffset > 0 then
						vehicle.cp.hud.content.pages[7][1][2].text = string.format("%.1fm (%s)", math.abs(vehicle.cp.laneOffset), courseplay:loc("COURSEPLAY_RIGHT"));
					elseif vehicle.cp.laneOffset < 0 then
						vehicle.cp.hud.content.pages[7][1][2].text = string.format("%.1fm (%s)", math.abs(vehicle.cp.laneOffset), courseplay:loc("COURSEPLAY_LEFT"));
					end;
				else
					vehicle.cp.hud.content.pages[7][1][2].text = "---";
				end;
			end;

			--Symmetrical lane change
			if vehicle.cp.mode == 4 or vehicle.cp.mode == 6 and vehicle.cp.laneOffset ~= 0 then
				vehicle.cp.hud.content.pages[7][2][1].text = courseplay:loc("COURSEPLAY_SYMMETRIC_LANE_CHANGE");
				vehicle.cp.hud.content.pages[7][2][2].text = vehicle.cp.symmetricLaneChange and courseplay:loc("CPactivated") or courseplay:loc("CPdeactivated");
			end;

			--Tool horizontal offset
			vehicle.cp.hud.content.pages[7][3][1].text = courseplay:loc("COURSEPLAY_TOOL_OFFSET_X");
			if vehicle.cp.toolOffsetX and vehicle.cp.toolOffsetX ~= 0 then
				if vehicle.cp.toolOffsetX > 0 then
					vehicle.cp.hud.content.pages[7][3][2].text = string.format("%.1fm (%s)", math.abs(vehicle.cp.toolOffsetX), courseplay:loc("COURSEPLAY_RIGHT"));
				elseif vehicle.cp.toolOffsetX < 0 then
					vehicle.cp.hud.content.pages[7][3][2].text = string.format("%.1fm (%s)", math.abs(vehicle.cp.toolOffsetX), courseplay:loc("COURSEPLAY_LEFT"));
				end;
			else
				vehicle.cp.hud.content.pages[7][3][2].text = "---";
			end;

			--Tool vertical offset
			vehicle.cp.hud.content.pages[7][4][1].text = courseplay:loc("COURSEPLAY_TOOL_OFFSET_Z");
			if vehicle.cp.toolOffsetZ and vehicle.cp.toolOffsetZ ~= 0 then
				if vehicle.cp.toolOffsetZ > 0 then
					vehicle.cp.hud.content.pages[7][4][2].text = string.format("%.1fm (%s)", math.abs(vehicle.cp.toolOffsetZ), courseplay:loc("COURSEPLAY_FRONT"));
				elseif vehicle.cp.toolOffsetZ < 0 then
					vehicle.cp.hud.content.pages[7][4][2].text = string.format("%.1fm (%s)", math.abs(vehicle.cp.toolOffsetZ), courseplay:loc("COURSEPLAY_BACK"));
				end;
			else
				vehicle.cp.hud.content.pages[7][4][2].text = "---";
			end;
		end;

		--Copy course from driver
		vehicle.cp.hud.content.pages[7][5][1].text = courseplay:loc("CPcopyCourse");
		if vehicle.cp.copyCourseFromDriver ~= nil then
			local driverName = vehicle.cp.copyCourseFromDriver.name or courseplay:loc("CPDriver");
			vehicle.cp.hud.content.pages[7][5][2].text = string.format("%s (%dm)", driverName, courseplay:distance_to_object(vehicle, vehicle.cp.copyCourseFromDriver));
			vehicle.cp.hud.content.pages[7][6][2].text = '(' .. (vehicle.cp.copyCourseFromDriver.cp.currentCourseName or courseplay:loc("CPtempCourse")) .. ')';
		else
			vehicle.cp.hud.content.pages[7][5][2].text = courseplay:loc("CPNone"); -- "keiner"
		end;


	--PAGE 8: COURSE GENERATION
	elseif page == 8 then
		--line 1 = CourseplayFields
		vehicle.cp.hud.content.pages[8][1][1].text, vehicle.cp.hud.content.pages[8][1][2].text = "", "";
		if courseplay.fields.numAvailableFields > 0 then
			vehicle.cp.hud.content.pages[8][1][1].text = courseplay:loc("COURSEPLAY_FIELD_EDGE_PATH");
			vehicle.cp.hud.content.pages[8][1][2].text = vehicle.cp.fieldEdge.selectedField.fieldNum > 0 and courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].name or '---';
		end;

		--line 2 = work width
		vehicle.cp.hud.content.pages[8][2][1].text = courseplay:loc("COURSEPLAY_WORK_WIDTH"); -- Arbeitsbreite
		vehicle.cp.hud.content.pages[8][2][2].text = vehicle.cp.workWidth ~= nil and string.format("%.1fm", vehicle.cp.workWidth) or '---';

		--line 3 = starting corner
		vehicle.cp.hud.content.pages[8][3][1].text = courseplay:loc("CPstartingCorner");
		-- 1 = SW, 2 = NW, 3 = NE, 4 = SE
		if vehicle.cp.hasStartingCorner then
			vehicle.cp.hud.content.pages[8][3][2].text = courseplay:loc(string.format("CPcorner%d", vehicle.cp.startingCorner)); -- NE/SE/SW/NW
		else
			vehicle.cp.hud.content.pages[8][3][2].text = "---";
		end;

		--line 4 = starting direction
		vehicle.cp.hud.content.pages[8][4][1].text = courseplay:loc("CPstartingDirection");
		-- 1 = North, 2 = East, 3 = South, 4 = West
		if vehicle.cp.hasStartingDirection then
			vehicle.cp.hud.content.pages[8][4][2].text = courseplay:loc(string.format("CPdirection%d", vehicle.cp.startingDirection)); -- East/South/West/North
		else
			vehicle.cp.hud.content.pages[8][4][2].text = "---";
		end;

		--line 5 = return to first point
		vehicle.cp.hud.content.pages[8][5][1].text = courseplay:loc("CPreturnToFirstPoint");
		vehicle.cp.hud.content.pages[8][5][2].text = vehicle.cp.returnToFirstPoint and courseplay:loc("CPactivated") or courseplay:loc("CPdeactivated");

		--line 6 = headland
		vehicle.cp.hud.content.pages[8][6][1].text = courseplay:loc("CPheadland");
		vehicle.cp.hud.content.pages[8][6][2].text = vehicle.cp.headland.numLanes ~= 0 and tostring(vehicle.cp.headland.numLanes) or '-';


	--PAGE 9: SHOVEL SETTINGS
	elseif page == 9 then
		vehicle.cp.hud.content.pages[9][1][1].text = courseplay:loc("setLoad");  --"laden"
		vehicle.cp.hud.content.pages[9][2][1].text = courseplay:loc("setTransport");  --"transportieren"
		vehicle.cp.hud.content.pages[9][3][1].text = courseplay:loc("setPreUnload");  --"fertig zum entladen"
		vehicle.cp.hud.content.pages[9][4][1].text = courseplay:loc("setUnload");  --"entladen"

		for a=2,5 do
			vehicle.cp.hud.content.pages[9][a-1][2].text = vehicle.cp.hasShovelStateRot[tostring(a)] and 'OK' or '';
		end;

		vehicle.cp.hud.content.pages[9][5][1].text = courseplay:loc("cpShovelStopAndGo");
		vehicle.cp.hud.content.pages[9][5][2].text = vehicle.cp.shovelStopAndGo and courseplay:loc("CPactivated") or courseplay:loc("CPdeactivated");

	end; --END if page == n

	courseplay.hud:setReloadPageOrder(vehicle, page, false);
end;

function courseplay.hud:setReloadPageOrder(vehicle, page, bool)
	if vehicle.cp.hud.reloadPage[page] ~= bool then
		vehicle.cp.hud.reloadPage[page] = bool;
		if courseplay.debugChannels[12] and bool == true then
			courseplay:debug(string.format('%s: set reloadPage[%d] to %s (called from %s)', nameNum(vehicle), page, tostring(bool), courseplay.utils:getFnCallPath(4)), 12);
		end;
	end;
end;