-- Load Lines for Hud
function courseplay:HudPage(self)
	courseplay:setFontSettings("white", false);
	
	local Page = self.showHudInfoBase;
	for column=1, 2 do
		for line, name in pairs(self.hudpage[Page][column]) do
			if column == 1 then
				renderText(courseplay.hud.infoBasePosX + 0.005, courseplay.hud.linesPosY[line], 0.019, name);
			elseif column == 2 then
				local posX = courseplay.hud.infoBasePosX + 0.122;
				if Page == 6 or Page == 8 then
					posX = courseplay.hud.infoBasePosX + 0.182;
				elseif Page == 9 then
					posX = courseplay.hud.infoBasePosX + 0.230;
				end;
				
				renderText(posX, courseplay.hud.linesPosY[line], 0.017, name);
			end;
		end;
	end;
end;

function courseplay:loadHud(self)
	for page=0,1 do
		for line=1, courseplay.hud.numLines do
			self.hudpage[page][line] = {};
		end;
	end;

	if self.show_hud then
		--setOverlayUVs(self.hudInfoBaseOverlay, 0,0, 0,0.95, 0.95,0, 0.95,0.95);
		self.hudInfoBaseOverlay:render();
		if self.showHudInfoBase == 0 then
			local combine = self;
			if self.cp.attachedCombineIdx ~= nil and self.tippers ~= nil and self.tippers[self.cp.attachedCombineIdx] ~= nil then
				combine = self.tippers[self.cp.attachedCombineIdx];
			end;

			-- no courseplayer!
			if combine.courseplayers == nil or table.getn(combine.courseplayers) == 0 then
				if combine.wants_courseplayer then
					self.hudpage[0][1][1] = courseplay:get_locale(self, "CoursePlayCalledPlayer")
				else
					self.hudpage[0][1][1] = courseplay:get_locale(self, "CoursePlayCallPlayer")
				end
			else
				self.hudpage[0][1][1] = courseplay:get_locale(self, "CoursePlayPlayer")
				local tractor = combine.courseplayers[1]
				self.hudpage[0][2][1] = tractor.name

				if tractor.forced_to_stop then
					self.hudpage[0][1][2] = courseplay:get_locale(self, "CoursePlayPlayerStart")
				else
					self.hudpage[0][1][2] = courseplay:get_locale(self, "CoursePlayPlayerStop")
				end
				self.hudpage[0][1][3] = courseplay:get_locale(self, "CoursePlayPlayerSendHome")

				--chopper
				if combine.cp.isChopper then
					local tractor = combine.courseplayers[1]
					if tractor ~= nil then
						self.hudpage[0][1][4] = courseplay:get_locale(self, "CoursePlayPlayerSwitchSide")
						if combine.forced_side == "left" then
							self.hudpage[0][2][4] = courseplay:get_locale(self, "CoursePlayPlayerSideLeft")
						elseif combine.forced_side == "right" then
							self.hudpage[0][2][4] = courseplay:get_locale(self, "CoursePlayPlayerSideRight")
						else
							self.hudpage[0][2][4] = courseplay:get_locale(self, "CoursePlayPlayerSideNone")
						end
						
						--manual chopping: initiate/end turning maneuver
						if not self.drive and not combine.isAIThreshing then
							self.hudpage[0][1][5] = courseplay:get_locale(self, "CPturnManeuver");
							if self.cp.turnStage == 0 then
								self.hudpage[0][2][5] = courseplay:get_locale(self, "CPStart");
							elseif self.cp.turnStage == 1 then
								self.hudpage[0][2][5] = courseplay:get_locale(self, "CPEnd");
							end;
						end
					end
				end
			end
		elseif self.showHudInfoBase == 1 then
			if self.play then
				if not self.drive then
					self.hudpage[1][1][4] = courseplay:get_locale(self, "CourseReset")

					self.hudpage[1][1][1] = courseplay:get_locale(self, "CoursePlayStart")
				else
					local last_recordnumber = nil

					if self.recordnumber > 1 then
						last_recordnumber = self.recordnumber - 1
					else
						last_recordnumber = 1
					end

					if (self.Waypoints[last_recordnumber].wait and self.wait) or (self.StopEnd and (self.recordnumber == self.maxnumber or self.currentTipTrigger ~= nil)) then
						self.hudpage[1][1][2] = courseplay:get_locale(self, "CourseWaitpointStart")
					end

					self.hudpage[1][1][1] = courseplay:get_locale(self, "CoursePlayStop")


					if not self.loaded and self.ai_mode ~= 5 then
						self.hudpage[1][1][3] = courseplay:get_locale(self, "NoWaitforfill")
					end

					if not self.StopEnd then
						self.hudpage[1][1][4] = courseplay:get_locale(self, "CoursePlayStopEnd")
					end
					
					if self.ai_mode == 4 then
						self.hudpage[1][1][5] = courseplay:get_locale(self, "CPridgeMarkers");
						
						if self.cp.ridgeMarkersAutomatic then
							self.hudpage[1][2][5] = courseplay:get_locale(self, "CPautomatic");
						else
							self.hudpage[1][2][5] = courseplay:get_locale(self, "CPmanual");
						end;
					end;
				end
			end
			if not self.drive then
				if (not self.record and not self.record_pause) and not self.play then --and (table.getn(self.Waypoints) == 0) and not self.createCourse
					if (table.getn(self.Waypoints) == 0) and not self.createCourse then
						self.hudpage[1][1][1] = courseplay:get_locale(self, "PointRecordStart")
					end

				elseif (not self.record and not self.record_pause) and (table.getn(self.Waypoints) ~= 0) then --TODO: use courseplay:validateCanSwitchMode(self)
					self.hudpage[1][1][2] = courseplay:get_locale(self, "ModusSet")

				else
					self.hudpage[1][1][1] = courseplay:get_locale(self, "PointRecordStop")

					if not self.record_pause then
						if self.recordnumber > 1 then
							self.hudpage[1][1][2] = courseplay:get_locale(self, "CourseWaitpointSet")

							self.hudpage[1][1][3] = courseplay:get_locale(self, "PointRecordInterrupt")

							self.hudpage[1][1][4] = courseplay:get_locale(self, "CourseCrossingSet")							
							self.hudpage[1][1][5] = courseplay:get_locale(self, "CourseDriveDirection")	.. " "
							if not self.direction  then
								self.hudpage[1][1][5] =  self.hudpage[1][1][5] .. courseplay:get_locale(self, "CourseDriveDirectionFor")
							else
								self.hudpage[1][1][5] =  self.hudpage[1][1][5] .. courseplay:get_locale(self, "CourseDriveDirectionBac")
							end
						end
					else
						if self.recordnumber > 4 then
							self.hudpage[1][1][2] = courseplay:get_locale(self, "PointRecordDelete")
						end

						self.hudpage[1][1][3] = courseplay:get_locale(self, "PointRecordContinue")
					end
				end
			end



		--Page 2 (course list)
		elseif self.showHudInfoBase == 2 then
			local number_of_courses = 0;
			if g_currentMission.courseplay_courses ~= nil then
				number_of_courses = table.getn(g_currentMission.courseplay_courses);
			end
			local start_course_num = self.selected_course_number
			local end_course_num = start_course_num + (courseplay.hud.numLines - 1)

			if end_course_num >= number_of_courses then
				end_course_num = number_of_courses - 1
			end

			for i = 0, 12, 1 do
				self.hudpage[2][1][i] = nil
			end


			local row = 1
			for i = start_course_num, end_course_num, 1 do
				for _, button in pairs(self.cp.buttons) do
					if button.page == -2 and button.row == row then
						button.overlay:render()
					end
				end
				local course_name = g_currentMission.courseplay_courses[i + 1].name

				if course_name == nil or course_name == "" then
					course_name = "-"
				end

				self.hudpage[2][1][row] = course_name
				row = row + 1
			end



		--Page 3
		elseif self.showHudInfoBase == 3 then
			self.hudpage[3][1][1] = courseplay:get_locale(self, "CPCombineOffset") --"seitl. Abstand:"
			self.hudpage[3][1][2] = courseplay:get_locale(self, "CPPipeOffset") --"Pipe Abstand:"
			self.hudpage[3][1][3] = courseplay:get_locale(self, "CPTurnRadius") --"Wenderadius:"
			self.hudpage[3][1][4] = courseplay:get_locale(self, "CPRequiredFillLevel") --"Start bei%:"
			self.hudpage[3][1][5] = courseplay:get_locale(self, "NoWaitforfillAt") --"abfahren bei%:"

			if self.ai_state ~= nil then
				if self.combine_offset ~= 0 then
					local combine_offset_mode = ''
					if self.auto_combine_offset then
						combine_offset_mode = "(auto)"
					else
						combine_offset_mode = "(mnl)"
					end
					self.hudpage[3][2][1] = string.format("%s %.1f", combine_offset_mode, self.combine_offset)
				else
					self.hudpage[3][2][1] = "auto"
				end
			else
				self.hudpage[3][2][1] = "---"
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
				self.hudpage[3][2][2] = tipperOffsetStr
			else
				self.hudpage[3][2][2] = "---"
			end

			if self.autoTurnRadius ~= nil or self.turn_radius ~= nil then
				local turnRadiusMode = ''
				if self.turnRadiusAutoMode then
					turnRadiusMode = "(auto)"
				else
					turnRadiusMode = "(mnl)"
				end
				self.hudpage[3][2][3] = string.format("%s %d", turnRadiusMode, self.turn_radius)
			else
				self.hudpage[3][2][3] = "---"
			end

			if self.required_fill_level_for_follow ~= nil then
				self.hudpage[3][2][4] = string.format("%d", self.required_fill_level_for_follow)
			else
				self.hudpage[3][2][4] = "---"
			end

			if self.required_fill_level_for_drive_on ~= nil then
				self.hudpage[3][2][5] = string.format("%d", self.required_fill_level_for_drive_on)
			else
				self.hudpage[3][2][5] = "---"
			end



		--Page 4: Assign combine
		elseif self.showHudInfoBase == 4 then

			self.hudpage[4][1][1] = courseplay:get_locale(self, "CPSelectCombine") -- "Drescher wählen:"
			self.hudpage[4][1][2] = courseplay:get_locale(self, "CPCombineSearch") -- "Dreschersuche:"
			self.hudpage[4][1][3] = courseplay:get_locale(self, "CPActual") -- "Aktuell:"
			--self.hudpage[4][1][4]= courseplay:get_locale(self, "CPMaxHireables") -- "Aktuell:"
			--self.hudpage[4][2][4] = string.format("%d", g_currentMission.maxNumHirables)

			if self.active_combine ~= nil then
				self.hudpage[4][2][3] = self.active_combine.name
			else
				self.hudpage[4][2][3] = courseplay:get_locale(self, "CPNone") -- "keiner"
			end

			if self.saved_combine ~= nil and self.saved_combine.rootNode ~= nil then
				local combine_name = self.saved_combine.name
				if combine_name == nil then
					combine_name = courseplay:get_locale(self, "CPCombine");
				end
				self.hudpage[4][2][1] = combine_name .. " (" .. string.format("%d", courseplay:distance_to_object(self, self.saved_combine)) .. "m)"
			else
				self.hudpage[4][2][1] = courseplay:get_locale(self, "CPNone") -- "keiner"
			end

			if self.search_combine then
				self.hudpage[4][2][2] = courseplay:get_locale(self, "CPFindAuto") -- "automatisch finden"
			else
				self.hudpage[4][2][2] = courseplay:get_locale(self, "CPFindManual") -- "manuell zuweisen"
			end;


		--Page 5: Speeds
		elseif self.showHudInfoBase == 5 then
			self.hudpage[5][1][1] = courseplay:get_locale(self, "CPTurnSpeed") -- "Wendemanöver:"
			self.hudpage[5][1][2] = courseplay:get_locale(self, "CPFieldSpeed") -- "Auf dem Feld:"
			self.hudpage[5][1][3] = courseplay:get_locale(self, "CPMaxSpeed") -- "Auf Straße:"
			self.hudpage[5][1][4] = courseplay:get_locale(self, "CPUnloadSpeed") -- "Abladen (BGA):"
			self.hudpage[5][1][5] = courseplay:get_locale(self, "CPuseSpeed") -- "Geschwindigkeit:"

			local localeSpeedMulti = 1; --kph
			if g_languageShort == "en" then
				localeSpeedMulti = 0.621371; --mph
			end;

			self.hudpage[5][2][1] = string.format("%d %s", self.turn_speed   * 3600 * localeSpeedMulti, courseplay.locales.CPspeedUnit);
			self.hudpage[5][2][2] = string.format("%d %s", self.field_speed  * 3600 * localeSpeedMulti, courseplay.locales.CPspeedUnit);
			self.hudpage[5][2][4] = string.format("%d %s", self.unload_speed * 3600 * localeSpeedMulti, courseplay.locales.CPspeedUnit);
			
			if self.use_speed then
				self.hudpage[5][2][3] = courseplay:get_locale(self, "CPautomaticSpeed");
				self.hudpage[5][2][5] = courseplay:get_locale(self, "CPuseSpeed1") -- "wie beim einfahren"
			else
				self.hudpage[5][2][3] = string.format("%d %s", self.max_speed * 3600 * localeSpeedMulti, courseplay.locales.CPspeedUnit);
				self.hudpage[5][2][5] = courseplay:get_locale(self, "CPuseSpeed2") -- "maximale Geschwindigkeit"
			end;



		--Page 6: General settings
		elseif self.showHudInfoBase == 6 then

			self.hudpage[6][1][1] = courseplay:get_locale(self, "CPaStar") -- Z-Offset:

			self.hudpage[6][1][2] = courseplay:get_locale(self, "CPopenHud") -- Z-Offset:
			self.hudpage[6][1][3] = courseplay:get_locale(self, "CPWPs") -- Z-Offset:

			if self.realistic_driving then
				self.hudpage[6][2][1] = courseplay:get_locale(self, "CPastarOn")
			else
				self.hudpage[6][2][1] = courseplay:get_locale(self, "CPastarOff") -- "keiner"
			end

			if self.mouse_right_key_enabled then
				self.hudpage[6][2][2] = courseplay:get_locale(self, "CPopenHudMouse")
			else
				local hudMod = string.lower(tostring(InputBinding.getKeyNamesOfDigitalAction(InputBinding.CP_Modifier_1)):split(" ")[2])
				local hudKey = string.lower(tostring(InputBinding.getKeyNamesOfDigitalAction(InputBinding.CP_Hud)):split(" ")[2])
				self.hudpage[6][2][2] = hudMod:gsub("^%l", string.upper) .. " + " .. hudKey:gsub("^%l", string.upper)
			end

			self.hudpage[6][1][4] = courseplay:get_locale(self, "Rul")
			self.hudpage[6][1][5] = courseplay:get_locale(self, "CPDebugLevel")

			self.hudpage[6][2][3] = courseplay:get_locale(self, string.format("WaypointMode%d", self.waypointMode));
			self.hudpage[6][2][4] = courseplay:get_locale(self, "RulMode" .. string.format("%d", self.RulMode));
			self.hudpage[6][2][5] = courseplay:get_locale(self, "CPDebugLevel" .. string.format("%d", CPDebugLevel))

		--Page 7: Driving settings
		elseif self.showHudInfoBase == 7 then
			self.hudpage[7][1][1] = courseplay:get_locale(self, "CPWaitTime") -- Wartezeit am Haltepunkt
			self.hudpage[7][2][1] = string.format("%.1f", self.waitTime) .. "sec"

			self.hudpage[7][1][2] = courseplay:get_locale(self, "CPWpOffsetX") -- X-Offset
			if self.WpOffsetX ~= nil then
				self.hudpage[7][2][2] = string.format("%.1f", self.WpOffsetX) .. "m (l/r)"
			else
				self.hudpage[7][2][2] = "---"
			end

			local direction = ""
			self.hudpage[7][1][3] = courseplay:get_locale(self, "CPWpOffsetZ") -- X-Offset
			if self.WpOffsetZ ~= nil then
				self.hudpage[7][2][3] = string.format("%.1f", self.WpOffsetZ) .. "m (h/v)"
			else
				self.hudpage[7][2][3] = "---"
			end

			--Copy course from driver
			self.hudpage[7][1][5] = courseplay:get_locale(self, "CPcopyCourse");
			if self.cp.copyCourseFromDriver ~= nil then
				local driverName = self.cp.copyCourseFromDriver.name;
				if driverName == nil then
					driverName = courseplay:get_locale(self, "CPDriver");
				end;
				
				local courseName = self.cp.copyCourseFromDriver.current_course_name;
				if courseName == nil then
					courseName = courseplay:get_locale(self, "CPtempCourse");
				end;
				
				self.hudpage[7][2][5] = string.format("%s (%dm)", driverName, courseplay:distance_to_object(self, self.cp.copyCourseFromDriver));
				self.hudpage[7][2][6] = string.format("(%s)", courseName);
			else
				self.hudpage[7][2][5] = courseplay:get_locale(self, "CPNone"); -- "keiner"
				self.hudpage[7][2][6] = "";
			end;
			

		--Page 8 (Course generation)
		elseif self.showHudInfoBase == 8 then
			--line 1 = work width
			self.hudpage[8][1][1] = courseplay:get_locale(self, "CPWorkingWidht"); -- Arbeitsbreite
			if self.toolWorkWidht ~= nil then
				self.hudpage[8][2][1] = string.format("%.1f m", self.toolWorkWidht)
			else
				self.hudpage[8][2][1] = "---"
			end

			--line 2 = starting corner
			self.hudpage[8][1][2] = courseplay:get_locale(self, "CPstartingCorner");
			-- 1 = SW, 2 = NW, 3 = NE, 4 = SE
			if self.cp.hasStartingCorner then
				self.hudpage[8][2][2] = courseplay:get_locale(self, string.format("CPcorner%d", self.cp.startingCorner)); -- NE/SE/SW/NW
			else
				self.hudpage[8][2][2] = "---";
			end;

			--line 3 = starting direction
			self.hudpage[8][1][3] = courseplay:get_locale(self, "CPstartingDirection");
			-- 1 = North, 2 = East, 3 = South, 4 = West
			if self.cp.hasStartingDirection then
				self.hudpage[8][2][3] = courseplay:get_locale(self, string.format("CPdirection%d", self.cp.startingDirection)); -- East/South/West/North
			else
				self.hudpage[8][2][3] = "---";
			end;

			--line 4 = return to first point
			self.hudpage[8][1][4] = courseplay:get_locale(self, "CPreturnToFirstPoint");
			if self.cp.returnToFirstPoint then
				self.hudpage[8][2][4] = courseplay:get_locale(self, "CPyes");
			else
				self.hudpage[8][2][4] = courseplay:get_locale(self, "CPno");
			end;

			--line 5 = headland
			self.hudpage[8][1][5] = courseplay:get_locale(self, "CPheadland");
			if self.cp.headland.numLanes == 0 then
				self.hudpage[8][2][5] = courseplay:get_locale(self, "CPdeactivated");
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

				self.hudpage[8][2][5] = string.format("%d %s (%s)", math.abs(self.cp.headland.numLanes), lanesStr, order);
			end;

			--line 6 = generate course action
			if self.cp.hasValidCourseGenerationData then
				self.hudpage[8][1][6] = courseplay:get_locale(self, "CourseGenerate");
			else
				self.hudpage[8][1][6] = "";
			end;

		--Page 9 (Shovel positions)
		elseif self.showHudInfoBase == 9 then
			self.hudpage[9][1][1] = courseplay:get_locale(self, "setLoad");  --"laden"
			self.hudpage[9][1][2] = courseplay:get_locale(self, "setTransport");  --"transportieren"
			self.hudpage[9][1][3] = courseplay:get_locale(self, "setPreUnload");  --"fertig zum entladen"
			self.hudpage[9][1][4] = courseplay:get_locale(self, "setUnload");  --"entladen"

			for a=2,5 do
				if self.cp.shovelStateRot[tostring(a)] ~= nil then
					self.hudpage[9][2][a-1] = "OK";
				else
					self.hudpage[9][2][a-1] = "";
				end;
			end;

			self.hudpage[9][1][5] = courseplay:get_locale(self, "cpShovelStopAndGo");
			if self.cp.shovelStopAndGo then
				self.hudpage[9][2][5] = courseplay:get_locale(self, "CPon");
			else
				self.hudpage[9][2][5] = courseplay:get_locale(self, "CPoff");
			end;
		end;
	end -- end if show_hud
end


function courseplay:showHud(self)
	-- HUD
	if self.show_hud and self.isEntered then
		courseplay:setFontSettings("white", false);

		courseplay:render_buttons(self, self.showHudInfoBase)

		if self.ai_mode > 0 and self.ai_mode <= courseplay.numAiModes then
			self.hudinfo[1] = courseplay:get_locale(self, "CourseMode" .. string.format("%d", self.ai_mode))
		else
			self.hudinfo[1] = "---"
		end

		if self.current_course_name ~= nil then
			self.hudinfo[2] = courseplay:get_locale(self, "CPCourse") .. " " .. self.current_course_name
		else
			self.hudinfo[2] = courseplay:get_locale(self, "CPNoCourseLoaded") -- "Kurs: kein Kurs geladen"
		end

		if self.Waypoints[self.recordnumber] ~= nil then
			--self.hudinfo[3] = courseplay:get_locale(self, "CPWaypoint") .. self.recordnumber .. "/" .. self.maxnumber .. "	" .. courseplay.locales.WaitPoints .. self.waitPoints .. "	" .. courseplay.locales.CrossPoints .. self.crossPoints
			self.hudinfo[3] = string.format("%s%s/%s	%s%s	%s%s", courseplay:get_locale(self, "CPWaypoint"), tostring(self.recordnumber), tostring(self.maxnumber),  tostring(courseplay.locales.WaitPoints), tostring(self.waitPoints), tostring(courseplay.locales.CrossPoints), tostring(self.crossPoints));
		elseif self.record or self.record_pause or self.createCourse then
			self.hudinfo[3] = courseplay:get_locale(self, "CPWaypoint") .. self.recordnumber .. "	" .. courseplay.locales.WaitPoints .. self.waitPoints .. "	" .. courseplay.locales.CrossPoints .. self.crossPoints
		else
			self.hudinfo[3] = courseplay:get_locale(self, "CPNoWaypoint") -- "Keine Wegpunkte geladen"
		end

		local i = 0
		for v, name in pairs(self.hudinfo) do
			--local yspace = courseplay.hud.infoBasePosY + 0.077 - (i * 0.021); --ORIG: +0.077
			renderText(courseplay.hud.infoBasePosX + 0.006, courseplay.hud.linesBottomPosY[v], 0.017, name); --ORIG: +0.003
			i = i + 1
		end


		courseplay:setFontSettings("white", true);
		local hud_headline = courseplay.hud.hudTitles[self.showHudInfoBase + 1];
		renderText(courseplay.hud.infoBasePosX + 0.060, courseplay.hud.infoBasePosY + 0.240, 0.021, hud_headline);
		courseplay:HudPage(self);
	end

	if self.play then
		--local helpButtonModifier = " (+ " .. tostring(InputBinding.getKeyNamesOfDigitalAction(InputBinding.CP_Modifier_1)):split(" ")[2] .. ")"
		-- hud not displayed - display start stop
		if self.drive then
			if InputBinding.isPressed(InputBinding.CP_Modifier_1) then
				g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStop"), InputBinding.AHInput1)
				g_currentMission:addHelpButtonText(courseplay:get_locale(self, "NoWaitforfill"), InputBinding.AHInput3);
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					self:setCourseplayFunc("stop", nil)
				end;
				if InputBinding.hasEvent(InputBinding.AHInput3) then
					self.loaded = true;
				end;
			end

			local last_recordnumber = nil

			if self.recordnumber > 1 then
				last_recordnumber = self.recordnumber - 1
			else
				last_recordnumber = 1
			end

			if --[[self.Waypoints[last_recordnumber].wait and]] self.wait then
				if InputBinding.isPressed(InputBinding.CP_Modifier_1) then
					g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CourseWaitpointStart"), InputBinding.AHInput2)
				
					if InputBinding.hasEvent(InputBinding.AHInput2) then
						self:setCourseplayFunc("drive_on", nil)
					end
				end
			end

		elseif InputBinding.isPressed(InputBinding.CP_Modifier_1) then
			g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStart"), InputBinding.AHInput1);
			if InputBinding.hasEvent(InputBinding.AHInput1) then
				self:setCourseplayFunc("start", nil);
			end
		end;
	end
end

function courseplay:setMinHudPage(self, workTool)
	self.cp.minHudPage = 1;
	
	local hasAttachedCombine = workTool ~= nil and courseplay:isAttachedCombine(workTool);
	
	if self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader or hasAttachedCombine then
		self.cp.minHudPage = 0;
	end;
	
	self.showHudInfoBase = math.max(self.showHudInfoBase, self.cp.minHudPage);
	--print(string.format("setMinHudPage: minHudPage=%s, showHudInfoBase=%s", tostring(self.cp.minHudPage), tostring(self.showHudInfoBase)));
	courseplay:buttonsActiveEnabled(self, "pageNav");
end;