function courseplay:setHudContent(self)
	--GLOBAL
	if self.cp.mode > 0 and self.cp.mode <= courseplay.numAiModes then
		self.cp.hud.content.global[1] = courseplay:get_locale(self, string.format("CourseMode%d", self.cp.mode));
	else
		self.cp.hud.content.global[1] = "---";
	end;

	local courseName = '';
	if self.cp.currentCourseName ~= nil then
		courseName = string.format("%s %s", courseplay:get_locale(self, "CPCourse"), self.cp.currentCourseName);
	elseif self.Waypoints[1] ~= nil then
		courseName = string.format("%s %s", courseplay:get_locale(self, "CPCourse"), courseplay:get_locale(self, "CPtempCourse"));
	else
		courseName = courseplay:get_locale(self, "CPNoCourseLoaded");
	end;
	self.cp.hud.content.global[2] = courseName;

	if self.Waypoints[self.recordnumber] ~= nil then
		self.cp.hud.content.global[3] = string.format("%s%s/%s\t%s%s\t%s%s", courseplay:get_locale(self, "CPWaypoint"), tostring(self.recordnumber), tostring(self.maxnumber),  tostring(courseplay.locales.COURSEPLAY_WAITPOINTS), tostring(self.cp.numWaitPoints), tostring(courseplay.locales.COURSEPLAY_CROSSING_POINTS), tostring(self.cp.numCrossingPoints));
	elseif self.record or self.record_pause or self.createCourse then
		self.cp.hud.content.global[3] = string.format("%s%d\t%s%d\t%s%d", courseplay:get_locale(self, "CPWaypoint"), self.recordnumber, courseplay.locales.COURSEPLAY_WAITPOINTS, self.cp.numWaitPoints, courseplay.locales.COURSEPLAY_CROSSING_POINTS, self.cp.numCrossingPoints);
	else
		self.cp.hud.content.global[3] = courseplay:get_locale(self, "CPNoWaypoint");
	end

	if self.cp.hud.reloadPage[-1] then
		for page=0,courseplay.hud.numPages do
			self.cp.hud.reloadPage[page] = true
		end
		self.cp.hud.reloadPage[-1] = false
	end
	
	--CURRENT PAGE
	if self.cp.hud.currentPage ~= 2 or (self.cp.hud.reloadPage[ self.cp.hud.currentPage ]) then
		for line=1,courseplay.hud.numLines do
			for column=1,2 do
				self.cp.hud.content.pages[self.cp.hud.currentPage][line][column].text = nil;
			end;
		end;
	end;

	self.cp.hud.background:render();

	--Page 0 (Combine)
	if self.cp.hud.currentPage == 0 then
		local combine = self;

		--DRIVER PRIORITY
		if self.cp.isCombine then
			self.cp.hud.content.pages[0][4][1].text = courseplay:get_locale(self, "COURSEPLAY_DRIVERPRIOTITY");

			if self.cp.driverPriorityUseFillLevel then
				self.cp.hud.content.pages[0][4][2].text = courseplay:get_locale(self, "COURSEPLAY_FILLEVEL");
			else
				self.cp.hud.content.pages[0][4][2].text = courseplay:get_locale(self, "CPDistance");
			end;
		end;

		-- no courseplayer!
		if self.cp.HUD0noCourseplayer then
			if self.cp.HUD0wantsCourseplayer then
				self.cp.hud.content.pages[0][1][1].text = courseplay:get_locale(self, "CoursePlayCalledPlayer")
			else
				self.cp.hud.content.pages[0][1][1].text = courseplay:get_locale(self, "CoursePlayCallPlayer")
			end
		else
			self.cp.hud.content.pages[0][1][1].text = courseplay:get_locale(self, "CoursePlayPlayer")
			self.cp.hud.content.pages[0][1][2].text = self.cp.HUD0tractorName

			if self.cp.HUD0tractorForcedToStop then
				self.cp.hud.content.pages[0][2][1].text = courseplay:get_locale(self, "CoursePlayPlayerStart")
			else
				self.cp.hud.content.pages[0][2][1].text = courseplay:get_locale(self, "CoursePlayPlayerStop")
			end
			self.cp.hud.content.pages[0][3][1].text = courseplay:get_locale(self, "CoursePlayPlayerSendHome")

			--chopper
			local attachedIsChopper = self.tippers[1] ~= nil and self.tippers[1].cp.isChopper 
			if combine.cp.isChopper or attachedIsChopper then
				if self.cp.HUD0tractor then
					self.cp.hud.content.pages[0][4][1].text = courseplay:get_locale(self, "CoursePlayPlayerSwitchSide")
					if self.cp.HUD0combineForcedSide == "left" then
						self.cp.hud.content.pages[0][4][2].text = courseplay:get_locale(self, "COURSEPLAY_LEFT")
					elseif self.cp.HUD0combineForcedSide == "right" then
						self.cp.hud.content.pages[0][4][2].text = courseplay:get_locale(self, "COURSEPLAY_RIGHT")
					else
						self.cp.hud.content.pages[0][4][2].text = courseplay:get_locale(self, "CoursePlayPlayerSideNone")
					end

					--manual chopping: initiate/end turning maneuver
					if self.cp.HUD0isManual then
						self.cp.hud.content.pages[0][5][1].text = courseplay:get_locale(self, "CPturnManeuver");
						if self.cp.HUD0turnStage == 0 then
							self.cp.hud.content.pages[0][5][2].text = courseplay:get_locale(self, "CPStart");
						elseif self.cp.HUD0turnStage == 1 then
							self.cp.hud.content.pages[0][5][2].text = courseplay:get_locale(self, "CPEnd");
						end;
					end
				end
			end
		end

	--Page 1 (CP Control)
	elseif self.cp.hud.currentPage == 1 then
		if self.cp.canDrive then
			if not self.drive then
				self.cp.hud.content.pages[1][1][1].text = courseplay:get_locale(self, "CoursePlayStart")

				if self.cp.mode ~= 9 then
					self.cp.hud.content.pages[1][3][1].text = courseplay:get_locale(self, "cpStartAtFirstPoint");
					if self.cp.startAtFirstPoint then
						self.cp.hud.content.pages[1][3][2].text = courseplay:get_locale(self, "cpFirstPoint");
					else
						self.cp.hud.content.pages[1][3][2].text = courseplay:get_locale(self, "cpNearestPoint");
					end;
				end;

				self.cp.hud.content.pages[1][4][1].text = courseplay:get_locale(self, "CourseReset")
			else
				self.cp.hud.content.pages[1][1][1].text = courseplay:get_locale(self, "CoursePlayStop")

				if self.cp.HUD1goOn then
					self.cp.hud.content.pages[1][2][1].text = courseplay:get_locale(self, "CourseWaitpointStart")
				end

				if self.cp.HUD1noWaitforFill then
					self.cp.hud.content.pages[1][3][1].text = courseplay:get_locale(self, "NoWaitforfill")
				end

				if not self.cp.stopAtEnd then
					self.cp.hud.content.pages[1][4][1].text = courseplay:get_locale(self, "CoursePlayStopEnd")
				end

				if self.cp.mode == 4 and self.cp.hasSowingMachine then
					self.cp.hud.content.pages[1][5][1].text = courseplay:get_locale(self, "CPridgeMarkers");

					if self.cp.ridgeMarkersAutomatic then
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPautomatic");
					else
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPmanual");
					end;
				elseif self.cp.mode == 6 and self.cp.hasBaleLoader and not self.cp.hasUnloadingRefillingCourse then
					self.cp.hud.content.pages[1][5][1].text = courseplay:get_locale(self, "CPunloadingOnField");
					if self.cp.automaticUnloadingOnField then
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPautomatic");
					else
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPmanual");
					end;
				end;
			end

		elseif not self.drive then
			if (not self.record and not self.record_pause) and not self.cp.canDrive then
				if (#(self.Waypoints) == 0) and not self.createCourse then
					self.cp.hud.content.pages[1][1][1].text = courseplay:get_locale(self, "PointRecordStart");
				end;

				--CUSTOM FIELD EDGE PATH
				self.cp.hud.content.pages[1][3][1].text = courseplay:get_locale(self, "COURSEPLAY_SCAN_CURRENT_FIELD_EDGES");
				self.cp.hud.content.pages[1][4][1].text = "";
				self.cp.hud.content.pages[1][4][2].text = "";
				self.cp.hud.content.pages[1][5][1].text = "";
				if self.cp.fieldEdge.customField.isCreated then
					self.cp.hud.content.pages[1][4][1].text = courseplay:get_locale(self, "COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER");
					if self.cp.fieldEdge.customField.fieldNum > 0 then
						self.cp.hud.content.pages[1][4][2].text = tostring(self.cp.fieldEdge.customField.fieldNum);
						if self.cp.fieldEdge.customField.selectedFieldNumExists then
							self.cp.hud.content.pages[1][5][1].text = string.format(courseplay:get_locale(self, "COURSEPLAY_OVERWRITE_CUSTOM_FIELD_EDGE_PATH_IN_LIST"), self.cp.fieldEdge.customField.fieldNum);
						else
							self.cp.hud.content.pages[1][5][1].text = string.format(courseplay:get_locale(self, "COURSEPLAY_ADD_CUSTOM_FIELD_EDGE_PATH_TO_LIST"), self.cp.fieldEdge.customField.fieldNum);
						end;
					else
						self.cp.hud.content.pages[1][4][2].text = "---";
					end;
				end;

			elseif self.record or self.record_pause then
				self.cp.hud.content.pages[1][1][1].text = courseplay:get_locale(self, "PointRecordStop");

				if not self.record_pause then
					if self.recordnumber > 1 then
						self.cp.hud.content.pages[1][2][1].text = courseplay:get_locale(self, "CourseWaitpointSet");

						if self.recordnumber > 3 then
							self.cp.hud.content.pages[1][3][1].text = courseplay:get_locale(self, "PointRecordInterrupt");
						end;

						self.cp.hud.content.pages[1][4][1].text = courseplay:get_locale(self, "CourseCrossingSet");
						if not self.cp.drivingDirReverse  then
							self.cp.hud.content.pages[1][5][1].text = courseplay:get_locale(self, "CourseDriveDirection") .. " " .. courseplay:get_locale(self, "CourseDriveDirectionFor");
						else
							self.cp.hud.content.pages[1][5][1].text = courseplay:get_locale(self, "CourseDriveDirection") .. " " .. courseplay:get_locale(self, "CourseDriveDirectionBac");
						end;
					end;
				else
					self.cp.hud.content.pages[1][2][1].text = courseplay:get_locale(self, "PointRecordDelete");

					self.cp.hud.content.pages[1][3][1].text = courseplay:get_locale(self, "PointRecordContinue");
				end;
			end;
		end;


	--Page 2 (course list)
	elseif self.cp.hud.currentPage == 2 then
		-- this function is called every time draw is called
		-- on page 2 there is nothing to update that frequent, like a distance to some target
		-- (else I'd place it right here)
		
		-- it is updated when its content changes:
		if self.cp.hud.reloadPage[2] then
			courseplay.hud.loadPage(self, 2)
		end

	--Page 3
	elseif self.cp.hud.currentPage == 3 then
		self.cp.hud.content.pages[3][1][1].text = courseplay:get_locale(self, "CPCombineOffset") --"seitl. Abstand:"
		self.cp.hud.content.pages[3][2][1].text = courseplay:get_locale(self, "CPVerticalOffset") --"vertikaler Abstand:"
		self.cp.hud.content.pages[3][3][1].text = courseplay:get_locale(self, "CPTurnRadius") --"Wenderadius:"
		self.cp.hud.content.pages[3][4][1].text = courseplay:get_locale(self, "CPRequiredFillLevel") --"Start bei %:"
		self.cp.hud.content.pages[3][5][1].text = courseplay:get_locale(self, "NoWaitforfillAt") --"abfahren bei %:"

		if self.cp.modeState ~= nil then
			if self.cp.combineOffset ~= 0 then
				local combineOffsetMode = self.cp.combineOffsetAutoMode and "(auto)" or "(mnl)";
				self.cp.hud.content.pages[3][1][2].text = string.format("%s %.1f", combineOffsetMode, self.cp.combineOffset)
			else
				self.cp.hud.content.pages[3][1][2].text = "auto"
			end
		else
			self.cp.hud.content.pages[3][1][2].text = "---"
		end

		if self.cp.tipperOffset ~= nil then
			local tipperOffsetStr = ''
			if self.cp.tipperOffset == 0 then
				tipperOffsetStr = "auto"
			elseif self.cp.tipperOffset > 0 then
				tipperOffsetStr = string.format("auto+%.1f", self.cp.tipperOffset)
			elseif self.cp.tipperOffset < 0 then
				tipperOffsetStr = string.format("auto%.1f", self.cp.tipperOffset)
			end
			self.cp.hud.content.pages[3][2][2].text = tipperOffsetStr
		else
			self.cp.hud.content.pages[3][2][2].text = "---"
		end

		if self.cp.turnRadiusAuto ~= nil or self.cp.turnRadius ~= nil then
			local turnRadiusMode = self.cp.turnRadiusAutoMode and '(auto)' or '(mnl)';
			self.cp.hud.content.pages[3][3][2].text = string.format("%s %d", turnRadiusMode, self.cp.turnRadius);
		else
			self.cp.hud.content.pages[3][3][2].text = "---"
		end

		if self.cp.followAtFillLevel ~= nil then
			self.cp.hud.content.pages[3][4][2].text = string.format("%d", self.cp.followAtFillLevel)
		else
			self.cp.hud.content.pages[3][4][2].text = "---"
		end

		if self.cp.driveOnAtFillLevel ~= nil then
			self.cp.hud.content.pages[3][5][2].text = string.format("%d", self.cp.driveOnAtFillLevel)
		else
			self.cp.hud.content.pages[3][5][2].text = "---"
		end



	--Page 4: Assign combine
	elseif self.cp.hud.currentPage == 4 then

		self.cp.hud.content.pages[4][1][1].text = courseplay:get_locale(self, "CPSelectCombine") -- "Drescher wählen:"
		self.cp.hud.content.pages[4][2][1].text = courseplay:get_locale(self, "CPCombineSearch") -- "Dreschersuche:"
		self.cp.hud.content.pages[4][3][1].text = courseplay:get_locale(self, "COURSEPLAY_CURRENT");

		if self.cp.HUD4savedCombine then
			if self.cp.HUD4savedCombineName == nil then
				self.cp.HUD4savedCombineName = courseplay:get_locale(self, "CPCombine");
			end
			self.cp.hud.content.pages[4][1][2].text = string.format("%s (%dm)", self.cp.HUD4savedCombineName, courseplay:distance_to_object(self, self.cp.savedCombine));
		else
			self.cp.hud.content.pages[4][1][2].text = courseplay:get_locale(self, "CPNone") -- "keiner"
		end

		if self.search_combine then
			self.cp.hud.content.pages[4][2][2].text = courseplay:get_locale(self, "CPFindAuto") -- "automatisch finden"
		else
			self.cp.hud.content.pages[4][2][2].text = courseplay:get_locale(self, "CPFindManual") -- "manuell zuweisen"
		end;

		if self.cp.HUD4hasActiveCombine then
			self.cp.hud.content.pages[4][3][2].text = self.cp.HUD4combineName
		else
			self.cp.hud.content.pages[4][3][2].text = courseplay:get_locale(self, "CPNone") -- "keiner"
		end


	--Page 5: Speeds
	elseif self.cp.hud.currentPage == 5 then
		self.cp.hud.content.pages[5][1][1].text = courseplay:get_locale(self, "CPTurnSpeed") -- "Wendemanöver:"
		self.cp.hud.content.pages[5][2][1].text = courseplay:get_locale(self, "CPFieldSpeed") -- "Auf dem Feld:"
		self.cp.hud.content.pages[5][3][1].text = courseplay:get_locale(self, "CPMaxSpeed") -- "Auf Straße:"
		self.cp.hud.content.pages[5][4][1].text = courseplay:get_locale(self, "CPUnloadSpeed") -- "Abladen (BGA):"
		self.cp.hud.content.pages[5][5][1].text = courseplay:get_locale(self, "CPuseSpeed") -- "Geschwindigkeit:"

		self.cp.hud.content.pages[5][1][2].text = string.format("%d %s", g_i18n:getSpeed(self.cp.speeds.turn   * 3600), g_i18n:getText("speedometer"));
		self.cp.hud.content.pages[5][2][2].text = string.format("%d %s", g_i18n:getSpeed(self.cp.speeds.field  * 3600), g_i18n:getText("speedometer"));
		self.cp.hud.content.pages[5][4][2].text = string.format("%d %s", g_i18n:getSpeed(self.cp.speeds.unload * 3600), g_i18n:getText("speedometer"));

		if self.cp.speeds.useRecordingSpeed then
			self.cp.hud.content.pages[5][3][2].text = courseplay:get_locale(self, "CPautomaticSpeed");
			self.cp.hud.content.pages[5][5][2].text = courseplay:get_locale(self, "CPuseSpeed1") -- "wie beim einfahren"
		else
			self.cp.hud.content.pages[5][3][2].text = string.format("%d %s", g_i18n:getSpeed(self.cp.speeds.max * 3600), g_i18n:getText("speedometer"));
			self.cp.hud.content.pages[5][5][2].text = courseplay:get_locale(self, "CPuseSpeed2") -- "maximale Geschwindigkeit"
		end;



	--Page 6: General settings
	elseif self.cp.hud.currentPage == 6 then
		--ASTAR
		self.cp.hud.content.pages[6][1][1].text = courseplay:get_locale(self, "CPaStar");
		self.cp.hud.content.pages[6][1][2].text = self.cp.realisticDriving and courseplay:get_locale(self, "CPactivated") or courseplay:get_locale(self, "CPdeactivated");

		--OPEN HUD KEY
		self.cp.hud.content.pages[6][2][1].text = courseplay:get_locale(self, "CPopenHud");
		self.cp.hud.content.pages[6][2][2].text = self.cp.hud.openWithMouse and courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName or courseplay.inputBindings.keyboard.COURSEPLAY_HUD_COMBINED.displayName;

		--WAYPOINT MODE
		self.cp.hud.content.pages[6][3][1].text = courseplay:get_locale(self, "CPWPs");
		self.cp.hud.content.pages[6][3][2].text = courseplay:get_locale(self, string.format("WaypointMode%d", self.cp.visualWaypointsMode));

		--BEACON LIGHT
		self.cp.hud.content.pages[6][4][1].text = courseplay:get_locale(self, "COURSEPLAY_BEACON_LIGHTS");
		self.cp.hud.content.pages[6][4][2].text = courseplay:get_locale(self, string.format("COURSEPLAY_BEACON_LIGHTS_MODE_%d", self.cp.beaconLightsMode));

		--WAITING POINT: WAIT TIME
		if not (self.cp.mode == 3 or self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7) then
			self.cp.hud.content.pages[6][5][1].text = courseplay:get_locale(self, "CPWaitTime");
			self.cp.hud.content.pages[6][5][2].text = string.format("%.1f sec", self.cp.waitTime);
		end;

		--DEBUG CHANNELS
		self.cp.hud.content.pages[6][6][1].text = courseplay:get_locale(self, "CPDebugChannels");



	--Page 7: Driving settings
	elseif self.cp.hud.currentPage == 7 then
		for line=1,4 do
			self.cp.hud.content.pages[7][line][1].text = "";
			self.cp.hud.content.pages[7][line][2].text = "";
		end;

		if self.cp.mode == 3 or self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7 then
			--LANE OFFSET
			if self.cp.mode == 4 or self.cp.mode == 6 then
				self.cp.hud.content.pages[7][1][1].text = courseplay:get_locale(self, "COURSEPLAY_LANE_OFFSET");
				if self.cp.laneOffset ~= nil then
					local descrStr = "";
					if self.cp.laneOffset > 0 then
						descrStr = string.format("(%s)", courseplay:get_locale(self, "COURSEPLAY_RIGHT"));
					elseif self.cp.laneOffset < 0 then
						descrStr = string.format("(%s)", courseplay:get_locale(self, "COURSEPLAY_LEFT"));
					end;
					self.cp.hud.content.pages[7][1][2].text = string.format("%.1fm %s", math.abs(self.cp.laneOffset), descrStr);
				else
					self.cp.hud.content.pages[7][1][2].text = "---";
				end;
			end;

			--SYMMETRIC LANE CHANGE
			if self.cp.mode == 4 or self.cp.mode == 6 and self.cp.laneOffset ~= 0 then
				self.cp.hud.content.pages[7][2][1].text = courseplay:get_locale(self, "COURSEPLAY_SYMMETRIC_LANE_CHANGE");
				self.cp.hud.content.pages[7][2][2].text = self.cp.symmetricLaneChange and courseplay:get_locale(self, "CPactivated") or courseplay:get_locale(self, "CPdeactivated");
			end;

			--TOOL HORIZONTAL OFFSET
			self.cp.hud.content.pages[7][3][1].text = courseplay:get_locale(self, "COURSEPLAY_TOOL_OFFSET_X");
			if self.cp.toolOffsetX ~= nil then
				local descrStr = "";
				if self.cp.toolOffsetX > 0 then
					descrStr = string.format("(%s)", courseplay:get_locale(self, "COURSEPLAY_RIGHT"));
				elseif self.cp.toolOffsetX < 0 then
					descrStr = string.format("(%s)", courseplay:get_locale(self, "COURSEPLAY_LEFT"));
				end;
				self.cp.hud.content.pages[7][3][2].text = string.format("%.1fm %s", math.abs(self.cp.toolOffsetX), descrStr);
			else
				self.cp.hud.content.pages[7][3][2].text = "---";
			end;

			--TOOL VERTICAL OFFSET
			self.cp.hud.content.pages[7][4][1].text = courseplay:get_locale(self, "COURSEPLAY_TOOL_OFFSET_Z");
			if self.cp.toolOffsetZ ~= nil then
				local descrStr = "";
				if self.cp.toolOffsetZ > 0 then
					descrStr = string.format("(%s)", courseplay:get_locale(self, "COURSEPLAY_FRONT"));
				elseif self.cp.toolOffsetZ < 0 then
					descrStr = string.format("(%s)", courseplay:get_locale(self, "COURSEPLAY_BACK"));
				end;
				self.cp.hud.content.pages[7][4][2].text = string.format("%.1fm %s", math.abs(self.cp.toolOffsetZ), descrStr);
			else
				self.cp.hud.content.pages[7][4][2].text = "---";
			end;
		end;

		--COPY COURSE FROM DRIVER
		self.cp.hud.content.pages[7][5][1].text = courseplay:get_locale(self, "CPcopyCourse");
		if self.cp.copyCourseFromDriver ~= nil then
			local driverName = self.cp.copyCourseFromDriver.name;
			if driverName == nil then
				driverName = courseplay:get_locale(self, "CPDriver");
			end;

			local courseName = self.cp.copyCourseFromDriver.cp.currentCourseName;
			if courseName == nil then
				courseName = courseplay:get_locale(self, "CPtempCourse");
			end;

			self.cp.hud.content.pages[7][5][2].text = string.format("%s (%dm)", driverName, courseplay:distance_to_object(self, self.cp.copyCourseFromDriver));
			self.cp.hud.content.pages[7][6][2].text = string.format("(%s)", courseName);
		else
			self.cp.hud.content.pages[7][5][2].text = courseplay:get_locale(self, "CPNone"); -- "keiner"
			self.cp.hud.content.pages[7][6][2].text = "";
		end;


	--Page 8 (Course generation)
	elseif self.cp.hud.currentPage == 8 then
		--line 1 = CourseplayFields
		self.cp.hud.content.pages[8][1][1].text, self.cp.hud.content.pages[8][1][2].text = "", "";
		if courseplay.fields.numAvailableFields > 0 then
			self.cp.hud.content.pages[8][1][1].text = courseplay:get_locale(self, "COURSEPLAY_FIELD_EDGE_PATH");
			self.cp.hud.content.pages[8][1][2].text = self.cp.fieldEdge.selectedField.fieldNum > 0 and courseplay.fields.fieldData[self.cp.fieldEdge.selectedField.fieldNum].name or '---';
		end;

		--line 2 = work width
		self.cp.hud.content.pages[8][2][1].text = courseplay:get_locale(self, "COURSEPLAY_WORK_WIDTH"); -- Arbeitsbreite
		self.cp.hud.content.pages[8][2][2].text = self.cp.workWidth ~= nil and string.format("%.1fm", self.cp.workWidth) or '---';

		--line 3 = starting corner
		self.cp.hud.content.pages[8][3][1].text = courseplay:get_locale(self, "CPstartingCorner");
		-- 1 = SW, 2 = NW, 3 = NE, 4 = SE
		if self.cp.hasStartingCorner then
			self.cp.hud.content.pages[8][3][2].text = courseplay:get_locale(self, string.format("CPcorner%d", self.cp.startingCorner)); -- NE/SE/SW/NW
		else
			self.cp.hud.content.pages[8][3][2].text = "---";
		end;

		--line 4 = starting direction
		self.cp.hud.content.pages[8][4][1].text = courseplay:get_locale(self, "CPstartingDirection");
		-- 1 = North, 2 = East, 3 = South, 4 = West
		if self.cp.hasStartingDirection then
			self.cp.hud.content.pages[8][4][2].text = courseplay:get_locale(self, string.format("CPdirection%d", self.cp.startingDirection)); -- East/South/West/North
		else
			self.cp.hud.content.pages[8][4][2].text = "---";
		end;

		--line 5 = return to first point
		self.cp.hud.content.pages[8][5][1].text = courseplay:get_locale(self, "CPreturnToFirstPoint");
		self.cp.hud.content.pages[8][5][2].text = self.cp.returnToFirstPoint and  courseplay:get_locale(self, "CPactivated") or courseplay:get_locale(self, "CPdeactivated");

		--line 6 = headland
		self.cp.hud.content.pages[8][6][1].text = courseplay:get_locale(self, "CPheadland");
		if self.cp.headland.numLanes == 0 then
			self.cp.hud.content.pages[8][6][2].text = courseplay:get_locale(self, "CPdeactivated");
		elseif self.cp.headland.numLanes ~= 0 then
			local lanesStr = math.abs(self.cp.headland.numLanes) == 1 and courseplay:get_locale(self, "CPheadlandLane") or courseplay:get_locale(self, "CPheadlandLanes");
			local order = self.cp.headland.numLanes > 0 and courseplay:get_locale(self, "CPbefore") or courseplay:get_locale(self, "CPafter");
			self.cp.hud.content.pages[8][6][2].text = string.format("%d %s (%s)", math.abs(self.cp.headland.numLanes), lanesStr, order);
		end;

	--Page 9 (Shovel positions)
	elseif self.cp.hud.currentPage == 9 then
		self.cp.hud.content.pages[9][1][1].text = courseplay:get_locale(self, "setLoad");  --"laden"
		self.cp.hud.content.pages[9][2][1].text = courseplay:get_locale(self, "setTransport");  --"transportieren"
		self.cp.hud.content.pages[9][3][1].text = courseplay:get_locale(self, "setPreUnload");  --"fertig zum entladen"
		self.cp.hud.content.pages[9][4][1].text = courseplay:get_locale(self, "setUnload");  --"entladen"

		for a=2,5 do
			if self.cp.shovelStateRot[tostring(a)] ~= nil then
				self.cp.hud.content.pages[9][a-1][2].text = "OK";
			else
				self.cp.hud.content.pages[9][a-1][2].text = "";
			end;
		end;

		self.cp.hud.content.pages[9][5][1].text = courseplay:get_locale(self, "cpShovelStopAndGo");
		if self.cp.shovelStopAndGo then
			self.cp.hud.content.pages[9][5][2].text = courseplay:get_locale(self, "CPactivated");
		else
			self.cp.hud.content.pages[9][5][2].text = courseplay:get_locale(self, "CPdeactivated");
		end;
	end;
end; --END setHudContent()


function courseplay:renderHud(self)
	--BUTTONS
	courseplay:renderButtons(self, self.cp.hud.currentPage);
	if self.cp.hud.mouseWheel.render then
		self.cp.hud.mouseWheel.icon:render();
	end;

	--BOTTOM GLOBAL INFO
	courseplay:setFontSettings("white", false, "left");
	for v, text in pairs(self.cp.hud.content.global) do
		if text ~= nil then
			renderText(courseplay.hud.infoBasePosX + 0.006, courseplay.hud.linesBottomPosY[v], 0.017, text); --ORIG: +0.003
		end;
	end


	--VERSION INFO
	if courseplay.versionDisplay ~= nil then
		courseplay:setFontSettings("white", false, "right");
		renderText(courseplay.hud.visibleArea.x2 - 0.008, courseplay.hud.infoBasePosY + 0.016, 0.012, courseplay.versionDisplay);
	end;


	--HUD TITLES
	courseplay:setFontSettings("white", true, "left");
	local hudPageTitle = courseplay.hud.hudTitles[self.cp.hud.currentPage];
	if self.cp.hud.currentPage == 2 then
		if not self.cp.hud.choose_parent and self.cp.hud.filter == '' then
			hudPageTitle = courseplay.hud.hudTitles[self.cp.hud.currentPage][1];
		elseif self.cp.hud.choose_parent then
			hudPageTitle = courseplay.hud.hudTitles[self.cp.hud.currentPage][2];
		elseif self.cp.hud.filter ~= '' then
			hudPageTitle = string.format(courseplay.hud.hudTitles[self.cp.hud.currentPage][3], self.cp.hud.filter);
		end;
	end;
	renderText(courseplay.hud.infoBasePosX + 0.060, courseplay.hud.infoBasePosY + 0.240, 0.021, hudPageTitle);


	--MAIN CONTENT
	courseplay:setFontSettings("white", false);
	local page = self.cp.hud.currentPage;
	for line,columns in pairs(self.cp.hud.content.pages[page]) do
		for column,entry in pairs(columns) do
			if column == 1 and entry.text ~= nil and entry.text ~= "" then
				if entry.isHovered then
					courseplay:setFontSettings("hover", false);
				end;
				renderText(courseplay.hud.infoBasePosX + 0.005 + entry.indention, courseplay.hud.linesPosY[line], 0.019, entry.text);
				courseplay:setFontSettings("white", false);
			elseif column == 2 and entry.text ~= nil and entry.text ~= "" then
				renderText(self.cp.hud.content.pages[page][line][2].posX, courseplay.hud.linesPosY[line], 0.017, entry.text);
			end;
		end;
	end;
end;

function courseplay:setMinHudPage(self, workTool)
	self.cp.minHudPage = 1;

	local hasAttachedCombine = workTool ~= nil and courseplay:isAttachedCombine(workTool);
	if self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader or hasAttachedCombine then
		self.cp.minHudPage = 0;
	end;

	self.cp.hud.currentPage = math.max(self.cp.hud.currentPage, self.cp.minHudPage);
	courseplay:debug(string.format("setMinHudPage: minHudPage=%s, currentPage=%s", tostring(self.cp.minHudPage), tostring(self.cp.hud.currentPage)), 12);
	courseplay:buttonsActiveEnabled(self, "pageNav");
end;

function courseplay.hud.loadPage(vehicle, page)
	if page == 2 then
	
		-- update courses?
		if vehicle.cp.reloadCourseItems then
			courseplay.courses.reload(vehicle)
		end
		-- end update courses
		
		local n_courses = #(vehicle.cp.hud.courses)
		local offset = courseplay.hud.offset; --0.006 (button width)
		
		-- set line text
		local courseName = ""
		for line = 1, n_courses do
			courseName = vehicle.cp.hud.courses[line].displayname
			if courseName == nil or courseName == "" then
				courseName = "-";
			end;
			vehicle.cp.hud.content.pages[2][line][1].text = courseName;
			if vehicle.cp.hud.courses[line].type == "course" then
				vehicle.cp.hud.content.pages[2][line][1].indention = vehicle.cp.hud.courses[line].level * offset
			else
				vehicle.cp.hud.content.pages[2][line][1].indention = (vehicle.cp.hud.courses[line].level + 1) * offset
			end
		end;
		for line = n_courses+1, courseplay.hud.numLines do
			vehicle.cp.hud.content.pages[2][line][1].text = nil;
		end
	
		-- enable and disable buttons:
		courseplay.buttonsActiveEnabled(nil, vehicle, 'page2')
		
	end -- if page == 2
	
	vehicle.cp.hud.reloadPage[page] = false
end;
