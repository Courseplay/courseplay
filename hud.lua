function courseplay:setHudContent(self)
	--GLOBAL
	if self.ai_mode > 0 and self.ai_mode <= courseplay.numAiModes then
		self.cp.hud.content.global[1] = courseplay:get_locale(self, string.format("CourseMode%d", self.ai_mode));
	else
		self.cp.hud.content.global[1] = "---";
	end;

	if self.current_course_name ~= nil then
		--self.cp.hud.content.global[2] = courseplay:get_locale(self, "CPCourse") .. " " .. self.current_course_name;
		self.cp.hud.content.global[2] = string.format("%s %s", courseplay:get_locale(self, "CPCourse"), self.current_course_name);
	else
		self.cp.hud.content.global[2] = courseplay:get_locale(self, "CPNoCourseLoaded");
	end;

	if self.Waypoints[self.recordnumber] ~= nil then
		self.cp.hud.content.global[3] = string.format("%s%s/%s\t%s%s\t%s%s", courseplay:get_locale(self, "CPWaypoint"), tostring(self.recordnumber), tostring(self.maxnumber),  tostring(courseplay.locales.WaitPoints), tostring(self.waitPoints), tostring(courseplay.locales.CrossPoints), tostring(self.crossPoints));
	elseif self.record or self.record_pause or self.createCourse then
		--self.cp.hud.content.global[3] = courseplay:get_locale(self, "CPWaypoint") .. self.recordnumber .. "	" .. courseplay.locales.WaitPoints .. self.waitPoints .. "	" .. courseplay.locales.CrossPoints .. self.crossPoints;
		self.cp.hud.content.global[3] = string.format("%s%d\t%s%d\t%s%d", courseplay:get_locale(self, "CPWaypoint"), self.recordnumber, courseplay.locales.WaitPoints, self.waitPoints, courseplay.locales.CrossPoints, self.crossPoints);
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
	if self.cp.hud.currentPage == 0 then
		local combine = self;
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
						self.cp.hud.content.pages[0][4][2].text = courseplay:get_locale(self, "CoursePlayPlayerSideLeft")
					elseif self.cp.HUD0combineForcedSide == "right" then
						self.cp.hud.content.pages[0][4][2].text = courseplay:get_locale(self, "CoursePlayPlayerSideRight")
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
		if self.play then
			if not self.drive then
				self.cp.hud.content.pages[1][1][1].text = courseplay:get_locale(self, "CoursePlayStart")

				if self.ai_mode ~= 9 then
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

				if not self.StopEnd then
					self.cp.hud.content.pages[1][4][1].text = courseplay:get_locale(self, "CoursePlayStopEnd")
				end
				if self.ai_mode == 4 and self.cp.hasSowingMachine then
					self.cp.hud.content.pages[1][5][1].text = courseplay:get_locale(self, "CPridgeMarkers");

					if self.cp.ridgeMarkersAutomatic then
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPautomatic");
					else
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPmanual");
					end;
				elseif self.ai_mode == 6 and self.cp.hasBaleLoader and not self.cp.hasUnloadingRefillingCourse then
					self.cp.hud.content.pages[1][5][1].text = courseplay:get_locale(self, "CPunloadingOnField");
					if self.cp.automaticUnloadingOnField then
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPautomatic");
					else
						self.cp.hud.content.pages[1][5][2].text = courseplay:get_locale(self, "CPmanual");
					end;
				end;
			end

		elseif not self.drive then
			if (not self.record and not self.record_pause) and not self.play then
				if (table.getn(self.Waypoints) == 0) and not self.createCourse then
					self.cp.hud.content.pages[1][1][1].text = courseplay:get_locale(self, "PointRecordStart");
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
						if not self.direction  then
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

		if self.ai_state ~= nil then
			if self.combine_offset ~= 0 then
				local combine_offset_mode = "(mnl)";
				if self.auto_combine_offset then
					combine_offset_mode = "(auto)";
				end;
				self.cp.hud.content.pages[3][1][2].text = string.format("%s %.1f", combine_offset_mode, self.combine_offset)
			else
				self.cp.hud.content.pages[3][1][2].text = "auto"
			end
		else
			self.cp.hud.content.pages[3][1][2].text = "---"
		end

		if self.tipper_offset ~= nil then
			local tipperOffsetStr = ''
			if self.tipper_offset == 0 then
				tipperOffsetStr = "auto"
			elseif self.tipper_offset > 0 then
				tipperOffsetStr = string.format("auto+%.1f", self.tipper_offset)
			elseif self.tipper_offset < 0 then
				tipperOffsetStr = string.format("auto%.1f", self.tipper_offset)
			end
			self.cp.hud.content.pages[3][2][2].text = tipperOffsetStr
		else
			self.cp.hud.content.pages[3][2][2].text = "---"
		end

		if self.autoTurnRadius ~= nil or self.turn_radius ~= nil then
			local turnRadiusMode = ''
			if self.turnRadiusAutoMode then
				turnRadiusMode = "(auto)"
			else
				turnRadiusMode = "(mnl)"
			end
			self.cp.hud.content.pages[3][3][2].text = string.format("%s %d", turnRadiusMode, self.turn_radius)
		else
			self.cp.hud.content.pages[3][3][2].text = "---"
		end

		if self.required_fill_level_for_follow ~= nil then
			self.cp.hud.content.pages[3][4][2].text = string.format("%d", self.required_fill_level_for_follow)
		else
			self.cp.hud.content.pages[3][4][2].text = "---"
		end

		if self.required_fill_level_for_drive_on ~= nil then
			self.cp.hud.content.pages[3][5][2].text = string.format("%d", self.required_fill_level_for_drive_on)
		else
			self.cp.hud.content.pages[3][5][2].text = "---"
		end



	--Page 4: Assign combine
	elseif self.cp.hud.currentPage == 4 then

		self.cp.hud.content.pages[4][1][1].text = courseplay:get_locale(self, "CPSelectCombine") -- "Drescher wählen:"
		self.cp.hud.content.pages[4][2][1].text = courseplay:get_locale(self, "CPCombineSearch") -- "Dreschersuche:"
		self.cp.hud.content.pages[4][3][1].text = courseplay:get_locale(self, "CPActual") -- "Aktuell:"

		if self.cp.HUD4savedCombine then
			if self.cp.HUD4savedCombineName == nil then
				self.cp.HUD4savedCombineName = courseplay:get_locale(self, "CPCombine");
			end
			self.cp.hud.content.pages[4][1][2].text = string.format("%s (%dm)", self.cp.HUD4savedCombineName, courseplay:distance_to_object(self, self.saved_combine));
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

		self.cp.hud.content.pages[5][1][2].text = string.format("%d %s", g_i18n:getSpeed(self.turn_speed   * 3600), g_i18n:getText("speedometer"));
		self.cp.hud.content.pages[5][2][2].text = string.format("%d %s", g_i18n:getSpeed(self.field_speed  * 3600), g_i18n:getText("speedometer"));
		self.cp.hud.content.pages[5][4][2].text = string.format("%d %s", g_i18n:getSpeed(self.unload_speed * 3600), g_i18n:getText("speedometer"));

		if self.use_speed then
			self.cp.hud.content.pages[5][3][2].text = courseplay:get_locale(self, "CPautomaticSpeed");
			self.cp.hud.content.pages[5][5][2].text = courseplay:get_locale(self, "CPuseSpeed1") -- "wie beim einfahren"
		else
			self.cp.hud.content.pages[5][3][2].text = string.format("%d %s", g_i18n:getSpeed(self.max_speed * 3600), g_i18n:getText("speedometer"));
			self.cp.hud.content.pages[5][5][2].text = courseplay:get_locale(self, "CPuseSpeed2") -- "maximale Geschwindigkeit"
		end;



	--Page 6: General settings
	elseif self.cp.hud.currentPage == 6 then
		self.cp.hud.content.pages[6][1][1].text = courseplay:get_locale(self, "CPaStar");
		if self.realistic_driving then
			self.cp.hud.content.pages[6][1][2].text = courseplay:get_locale(self, "CPactivated");
		else
			self.cp.hud.content.pages[6][1][2].text = courseplay:get_locale(self, "CPdeactivated");
		end;

		self.cp.hud.content.pages[6][2][1].text = courseplay:get_locale(self, "CPopenHud");
		if self.mouse_right_key_enabled then
			self.cp.hud.content.pages[6][2][2].text = courseplay:get_locale(self, "CPopenHudMouse");
		else
			self.cp.hud.content.pages[6][2][2].text = self.cp.hud.modKey .. " + " .. self.cp.hud.hudKey;
		end;

		self.cp.hud.content.pages[6][3][1].text = courseplay:get_locale(self, "CPWPs");
		self.cp.hud.content.pages[6][3][2].text = courseplay:get_locale(self, string.format("WaypointMode%d", self.cp.visualWaypointsMode));

		self.cp.hud.content.pages[6][4][1].text = courseplay:get_locale(self, "Rul");
		self.cp.hud.content.pages[6][4][2].text = courseplay:get_locale(self, "RulMode" .. string.format("%d", self.RulMode));

		self.cp.hud.content.pages[6][5][1].text = "";
		self.cp.hud.content.pages[6][5][2].text = "";
		if courseplay.fields ~= nil and courseplay.fields.fieldDefs ~= nil and courseplay.fields.numberOfFields > 0 then
			self.cp.hud.content.pages[6][5][1].text = courseplay:get_locale(self, "CPfieldEdgePath");
			if self.cp.selectedFieldEdgePathNumber > 0 then
				self.cp.hud.content.pages[6][5][2].text = string.format("%s %d", courseplay:get_locale(self, "CPfield"), self.cp.selectedFieldEdgePathNumber);
			else
				self.cp.hud.content.pages[6][5][2].text = "---";
			end;
		end;

		self.cp.hud.content.pages[6][6][1].text = courseplay:get_locale(self, "CPDebugChannels");



	--Page 7: Driving settings
	elseif self.cp.hud.currentPage == 7 then
		self.cp.hud.content.pages[7][1][1].text = courseplay:get_locale(self, "CPWaitTime"); -- Wartezeit am Haltepunkt
		self.cp.hud.content.pages[7][1][2].text = string.format("%.1f sec", self.waitTime);

		self.cp.hud.content.pages[7][2][1].text, self.cp.hud.content.pages[7][2][2].text, self.cp.hud.content.pages[7][3][1].text, self.cp.hud.content.pages[7][3][2].text = "", "", "", "";
		if self.ai_mode == 4 or self.ai_mode == 6 then
			self.cp.hud.content.pages[7][2][1].text = courseplay:get_locale(self, "CPWpOffsetX") -- X-Offset
			if self.WpOffsetX ~= nil then
				self.cp.hud.content.pages[7][2][2].text = string.format("%.1fm (l/r)", self.WpOffsetX)
			else
				self.cp.hud.content.pages[7][2][2].text = "---"
			end

			self.cp.hud.content.pages[7][3][1].text = courseplay:get_locale(self, "CPWpOffsetZ") -- X-Offset
			if self.WpOffsetZ ~= nil then
				self.cp.hud.content.pages[7][3][2].text = string.format("%.1fm (h/v)", self.WpOffsetZ);
			else
				self.cp.hud.content.pages[7][3][2].text = "---"
			end
		end;

		--Copy course from driver
		self.cp.hud.content.pages[7][5][1].text = courseplay:get_locale(self, "CPcopyCourse");
		if self.cp.copyCourseFromDriver ~= nil then
			local driverName = self.cp.copyCourseFromDriver.name;
			if driverName == nil then
				driverName = courseplay:get_locale(self, "CPDriver");
			end;

			local courseName = self.cp.copyCourseFromDriver.current_course_name;
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
		--line 1 = work width
		self.cp.hud.content.pages[8][1][1].text = courseplay:get_locale(self, "CPWorkingWidht"); -- Arbeitsbreite
		if self.toolWorkWidht ~= nil then
			self.cp.hud.content.pages[8][1][2].text = string.format("%.1fm", self.toolWorkWidht)
		else
			self.cp.hud.content.pages[8][1][2].text = "---"
		end

		--line 2 = starting corner
		self.cp.hud.content.pages[8][2][1].text = courseplay:get_locale(self, "CPstartingCorner");
		-- 1 = SW, 2 = NW, 3 = NE, 4 = SE
		if self.cp.hasStartingCorner then
			self.cp.hud.content.pages[8][2][2].text = courseplay:get_locale(self, string.format("CPcorner%d", self.cp.startingCorner)); -- NE/SE/SW/NW
		else
			self.cp.hud.content.pages[8][2][2].text = "---";
		end;

		--line 3 = starting direction
		self.cp.hud.content.pages[8][3][1].text = courseplay:get_locale(self, "CPstartingDirection");
		-- 1 = North, 2 = East, 3 = South, 4 = West
		if self.cp.hasStartingDirection then
			self.cp.hud.content.pages[8][3][2].text = courseplay:get_locale(self, string.format("CPdirection%d", self.cp.startingDirection)); -- East/South/West/North
		else
			self.cp.hud.content.pages[8][3][2].text = "---";
		end;

		--line 4 = return to first point
		self.cp.hud.content.pages[8][4][1].text = courseplay:get_locale(self, "CPreturnToFirstPoint");
		if self.cp.returnToFirstPoint then
			self.cp.hud.content.pages[8][4][2].text = courseplay:get_locale(self, "CPactivated");
		else
			self.cp.hud.content.pages[8][4][2].text = courseplay:get_locale(self, "CPdeactivated");
		end;

		--line 5 = headland
		self.cp.hud.content.pages[8][5][1].text = courseplay:get_locale(self, "CPheadland");
		if self.cp.headland.numLanes == 0 then
			self.cp.hud.content.pages[8][5][2].text = courseplay:get_locale(self, "CPdeactivated");
		elseif self.cp.headland.numLanes ~= 0 then
			local lanesString;
			local order;

			if math.abs(self.cp.headland.numLanes) == 1 then
				lanesStr = courseplay:get_locale(self, "CPheadlandLane");
			else
				lanesStr = courseplay:get_locale(self, "CPheadlandLanes");
			end;
			if self.cp.headland.numLanes > 0 then
				order = courseplay:get_locale(self, "CPbefore");
			else
				order = courseplay:get_locale(self, "CPafter");
			end;

			self.cp.hud.content.pages[8][5][2].text = string.format("%d %s (%s)", math.abs(self.cp.headland.numLanes), lanesStr, order);
		end;

		--line 6 = generate course action
		if self.cp.hasValidCourseGenerationData then
			self.cp.hud.content.pages[8][6][1].text = courseplay:get_locale(self, "CourseGenerate");
		else
			self.cp.hud.content.pages[8][6][1].text = "";
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
	courseplay:setFontSettings("white", false, "right");
	if courseplay.versionDisplay ~= nil then
		renderText(courseplay.hud.visibleArea.x2 - 0.008, courseplay.hud.infoBasePosY + 0.015, 0.012, "v" .. courseplay.versionDisplay[1] .. "." .. courseplay.versionDisplay[2]);
		if table.getn(courseplay.versionDisplay) < 3 then
			renderText(courseplay.hud.visibleArea.x2 - 0.008, courseplay.hud.infoBasePosY + 0.003, 0.012, ".0000");
		else
			renderText(courseplay.hud.visibleArea.x2 - 0.008, courseplay.hud.infoBasePosY + 0.003, 0.012, "." .. courseplay.versionDisplay[3]);
		end;
	else
		renderText(courseplay.hud.visibleArea.x2 - 0.008, courseplay.hud.infoBasePosY + 0.015, 0.012, "no");
		renderText(courseplay.hud.visibleArea.x2 - 0.008, courseplay.hud.infoBasePosY + 0.003, 0.012, "version");
	end;


	--HUD TITLES
	courseplay:setFontSettings("white", true, "left");
	local hudPageTitle = courseplay.hud.hudTitles[self.cp.hud.currentPage + 1];
	if self.cp.hud.currentPage == 2 then
		if not self.cp.hud.choose_parent and self.cp.hud.filter == '' then
			hudPageTitle = courseplay.hud.hudTitles[self.cp.hud.currentPage + 1][1];
		elseif self.cp.hud.choose_parent then
			hudPageTitle = courseplay.hud.hudTitles[self.cp.hud.currentPage + 1][2];
		elseif self.cp.hud.filter ~= '' then
			hudPageTitle = string.format(courseplay.hud.hudTitles[self.cp.hud.currentPage + 1][3], self.cp.hud.filter);
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
				renderText(courseplay.hud.col2posX[page + 1], courseplay.hud.linesPosY[line], 0.017, entry.text);
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
