function courseplay:mouseEvent(posX, posY, isDown, isUp, button)
	if isDown and button == 3 and self.isEntered and self.mouse_right_key_enabled then
		if self.mouse_enabled then
			self.mouse_enabled = false
		else
			self.mouse_enabled = true
			if not self.show_hud then
				self.showHudInfoBase = self.min_hud_page
				self.show_hud = true
			end
		end
		InputBinding.setShowMouseCursor(self.mouse_enabled)
	end
	if isDown and button == 1 and self.show_hud and self.isEntered then
		--courseplay:debug(string.format("posX: %f posY: %f",posX,posY), 4)

		for _, button in pairs(self.buttons) do
			if (button.page == self.showHudInfoBase or button.page == nil or button.page == self.showHudInfoBase * -1) and (button.show == nil or (button.show ~= nil and button.show)) then

				if posX > button.x and posX < button.x2 and posY > button.y and posY < button.y2 then
					if InputBinding.isPressed(InputBinding.CP_Modifier_1) then --for some reason InputBinding works in :mouseEvent
						courseplay:debug("CP_Modifier_1 is pressed", 3)
						if button.modifiedParameter ~= nil then
							courseplay:debug("button.modifiedParameter = " .. tostring(button.modifiedParameter), 3)
							self:setCourseplayFunc(button.function_to_call, button.modifiedParameter)
						end
					else
						self:setCourseplayFunc(button.function_to_call, button.parameter)
					end
				end
			end
		end
		
	--hover
	elseif not isDown and self.show_hud and self.isEntered then
		if self.mouse_enabled then
			for _, button in pairs(self.buttons) do
				if (button.page == self.showHudInfoBase or button.page == nil or button.page == self.showHudInfoBase * -1) and (button.show == nil or (button.show ~= nil and button.show)) then
					local baseColor = {1, 1, 1, 1};
					local noHoverChange = false;

					--quick switch buttons: if active mode
					if button.function_to_call == "setAiMode" and self.ai_mode ~= nil and self.ai_mode == button.parameter then
						--baseColor[4] = 0.35;
						baseColor = {206/255, 83/255, 77/255, 1};
						noHoverChange = true;
					end;
					
					if not noHoverChange and posX > button.x and posX < button.x2 and posY > button.y and posY < button.y2 then
						if button.function_to_call == "close_hud" then
							setOverlayColor(button.overlay.overlayId, 180/255,0,0,1);
						else
							setOverlayColor(button.overlay.overlayId, courseplay.hud.hoverColor.r, courseplay.hud.hoverColor.g, courseplay.hud.hoverColor.b, courseplay.hud.hoverColor.a);
						end;
					else
						setOverlayColor(button.overlay.overlayId, unpack(baseColor));
					end;
				end;
			end;
		elseif self.showHudInfoBase == 1 then
			for _, button in pairs(self.buttons) do
				if (button.page == self.showHudInfoBase or button.page == nil or button.page == self.showHudInfoBase * -1) and (button.show == nil or (button.show ~= nil and button.show)) then
					--quick switch buttons: if active mode
					if button.function_to_call == "setAiMode" and self.ai_mode ~= nil and self.ai_mode == button.parameter then
						--baseColor[4] = 0.35;
						baseColor = {206/255, 83/255, 77/255, 1};
						setOverlayColor(button.overlay.overlayId, unpack(baseColor));
						print(tableShow(button, "ai_mode active button"));
					end;
				end;
			end;
		end;
	end;
end;


function courseplay:setCourseplayFunc(func, value, noEventSend)
	if noEventSend ~= true then
		CourseplayEvent.sendEvent(self, func, value); -- Die Funktion ruft sendEvent auf und übergibt 3 Werte   (self "also mein ID", action, "Ist eine Zahl an der ich festmache welches Fenster ich aufmachen will", state "Ist der eigentliche Wert also true oder false"
	end;
	courseplay:deal_with_mouse_input(self, func, value)
end

function courseplay:deal_with_mouse_input(self, func, value)
	--TODO: überhaupt nicht DRY das geht bestimmt irgendwie schöner
	--TODO: (Jakob, 25 Jan 2013) http://stackoverflow.com/questions/1791234/lua-call-function-from-a-string-with-function-name
	if func == "switch_hud_page" then
		courseplay:switch_hud_page(self, value)
	end

	if func == "change_combine_offset" then
		courseplay:change_combine_offset(self, value)
	end

	if func == "add_course" then
		courseplay:add_course(self, value, false)
	end

	if func == "mouse_right_key" then
		courseplay:switch_mouse_right_key_enabled(self)
	end

	if func == "key_input" then
		courseplay:key_input(self, value)
	end

	if func == "load_course" then
		courseplay:load_course(self, value, false)
	end

	if func == "save_course" then
		courseplay:input_course_name(self)
	end

	if func == "start" then
		courseplay:start(self, value)
	end

	if func == "stop" then
		courseplay:stop(self, value)
	end

	if func == "drive_on" then
		self.wait = false
	end

	if func == "clear_course" then
		courseplay:clear_course(self, value)
	end

	if func == "change_turn_radius" then
		courseplay:change_turn_radius(self, value)
	end

	if func == "change_tipper_offset" then
		courseplay:change_tipper_offset(self, value)
	end

	if func == "change_required_fill_level" then
		courseplay:change_required_fill_level(self, value)
	end

	if func == "change_required_fill_level_for_drive_on" then
		courseplay:change_required_fill_level_for_drive_on(self, value)
	end

	if func == "change_turn_speed" then
		courseplay:change_turn_speed(self, value)
	end

	if func == "switch_realistic_driving" then
		courseplay:switch_realistic_driving(self, value)
	end



	if func == "change_wait_time" then
		courseplay:change_wait_time(self, value)
	end

	if func == "change_num_ai_helpers" then
		--courseplay:change_num_ai_helpers(self, value)
	end

	if func == "change_field_speed" then
		courseplay:change_field_speed(self, value)
	end

	if func == "change_max_speed" then
		courseplay:change_max_speed(self, value)
	end

	if func == "change_unload_speed" then
		courseplay:change_unload_speed(self, value)
	end

	if func == "change_RulMode" then
		courseplay:change_RulMode(self, value)
	end

	if func == "change_DriveDirection" then
		courseplay:set_direction(self)
	end

	if func == "change_DebugLevel" then
		courseplay:change_DebugLevel(value)
	end

	if func == "change_use_speed" then
		courseplay:switch_use_speed(self)
	end

	if func == "switch_search_combine" then
		courseplay:switch_search_combine(self)
	end

	if func == "change_selected_course" then
		courseplay:change_selected_course(self, value)
	end


	if func == "switch_combine" then
		courseplay:switch_combine(self, value)
	end

	if func == "switchDriverCopy" then
		courseplay:switchDriverCopy(self, value)
	end

	if func == "copyCourse" then
		courseplay:copyCourse(self)
	end

	if func == "changeWpOffsetX" then
		courseplay:changeCPWpOffsetX(self, value)
	end

	if func == "changeWpOffsetZ" then
		courseplay:changeCPWpOffsetZ(self, value)
	end

	if func == "changeWorkWidth" then
		courseplay:changeWorkWidth(self, value)
	end

	if func == "change_WaypointMode" then
		courseplay:change_WaypointMode(self, value)
	end

	--Course generation
	if func == "switchStartingCorner" then
		courseplay:switchStartingCorner(self);
	end;
	if func == "switchStartingDirection" then
		courseplay:switchStartingDirection(self);
	end;
	if func == "switchReturnToFirstPoint" then
		courseplay:switchReturnToFirstPoint(self);
	end;
	if func == "generateCourse" then
		courseplay:generateCourse(self);
	end;

	if func == "setAiMode" then
		courseplay:setAiMode(self, value);
	end;

	if func == "close_hud" then
		self.mouse_enabled = false
		self.show_hud = false
		InputBinding.setShowMouseCursor(self.mouse_enabled)
	end


	if func == "row1" or func == "row2" or func == "row3" or func == "row4" or func == "row5" then
		if self.showHudInfoBase == 0 then
			if self.courseplayers == nil or table.getn(self.courseplayers) == 0 then
				if func == "row1" then
					courseplay:call_player(self)
				end
			else
				if func == "row2" then
					courseplay:start_stop_player(self)
				end

				if func == "row3" then
					courseplay:send_player_home(self)
				end

				if func == "row4" then
					courseplay:switch_player_side(self)
				end
				
				--manual chopping: initiate/end turning maneuver
				--TODO: self.cp.turnStage (when ready)
				if func == "row5" and courseplay:isChopper(self) and not self.drive and not self.isAIThreshing then
					if self.turnStage == 0 then
						self.turnStage = 1;
					elseif self.turnStage == 1 then
						self.turnStage = 0;
					end;
				end
			end
		end
		if self.showHudInfoBase == 1 then
			if self.play then
				if not self.drive then
					if func == "row4" then
						courseplay:reset_course(self)
					end

					if func == "row1" then
						courseplay:start(self)
					end

				else -- driving
					local last_recordnumber = nil

					if self.recordnumber > 1 then
						last_recordnumber = self.recordnumber - 1
					else
						last_recordnumber = 1
					end

					if last_recordnumber ~= nil and self.Waypoints[last_recordnumber].wait and self.wait and func == "row2" then
						self.wait = false
					end

					if func == "row2" and self.StopEnd and (self.recordnumber == self.maxnumber or self.currentTipTrigger ~= nil) then
						self.StopEnd = false
					end

					if func == "row1" then
						courseplay:stop(self)
					end

					if not self.loaded and func == "row3" then
						self.loaded = true
					end

					if not self.StopEnd and func == "row4" then
						self.StopEnd = true
					end
					
					if self.ai_mode == 4 and func == "row5" then
						self.cp.ridgeMarkersAutomatic = not self.cp.ridgeMarkersAutomatic;
					end;
				end -- end driving
			end -- playing


			if not self.drive then
				if (not self.record and not self.record_pause) and not self.play then --- - and (table.getn(self.Waypoints) == 0) then
					if (table.getn(self.Waypoints) == 0) and not self.createCourse then
						if func == "row1" then
							courseplay:start_record(self)
						end
					end



				elseif (not self.record and not self.record_pause) and (table.getn(self.Waypoints) ~= 0) and self.play then
					if func == "row2" then
						courseplay:change_ai_state(self, 1)
					end
				else
					if func == "row1" then
						courseplay:stop_record(self)
					end


					if not self.record_pause then
						if func == "row2" then --and self.recordnumber > 3
							courseplay:set_waitpoint(self)
						end

						if func == "row4" then --and self.recordnumber > 3
							courseplay:set_crossing(self)
						end

						if func == "row3" then --and self.recordnumber > 3
							courseplay:interrupt_record(self)
						end

					else
						if func == "row2" then --and self.recordnumber > 4
							courseplay:delete_waypoint(self)
						end
						if func == "row3" then
							courseplay:continue_record(self)
						end
					end
				end
			end
		end
	end
end


function courseplay:key_input(self, unicode)
	if 31 < unicode and unicode < 127 then
		if self.user_input ~= nil then
			if self.user_input:len() <= 20 then
				self.user_input = self.user_input .. string.char(unicode)
			end
		end
	end

	-- backspace
	if unicode == 8 then
		if self.user_input ~= nil then
			if self.user_input:len() >= 1 then
				self.user_input = self.user_input:sub(1, self.user_input:len() - 1)
			end
		end
	end

	-- enter
	if unicode == 13 then
		courseplay:handle_user_input(self)
	end
end


-- deals with keyEvents
function courseplay:keyEvent(unicode, sym, modifier, isDown)
	-- user input fu
	if isDown and self.user_input_active then
		self:setCourseplayFunc("key_input", unicode)
	end
end



--  does something with the user input
function courseplay:handle_user_input(self)
	-- name for current_course
	if self.save_name then
		--courseplay:load_courses(self)
		self.user_input_active = false
		self.current_course_name = self.user_input
		local maxID = 0
		for i = 1, table.getn(g_currentMission.courseplay_courses) do
			if g_currentMission.courseplay_courses[i].id ~= nil then
				if g_currentMission.courseplay_courses[i].id > maxID then
					maxID = g_currentMission.courseplay_courses[i].id
				end
			end
		end
		self.courseID = maxID + 1
		course = { name = self.current_course_name, id = self.courseID, waypoints = self.Waypoints }
		self.numCourses = 1;
		if g_currentMission.courseplay_courses == nil then
			g_currentMission.courseplay_courses = {}
		end
		table.insert(g_currentMission.courseplay_courses, course)

		self.user_input = ""
		self.user_input_message = nil
		self.steeringEnabled = true --test
		courseplay:save_courses(self)
		
		if table.getn(g_currentMission.courseplay_courses) > courseplay.hud.numLines then
			self.cp.courseListPrev = self.selected_course_number > 0;
			self.cp.courseListNext = self.selected_course_number < (table.getn(g_currentMission.courseplay_courses) - courseplay.hud.numLines);
		end;
	end
end

-- renders input form
function courseplay:user_input(self)
	renderText(0.4, 0.9, 0.02, self.user_input_message .. self.user_input);
end
