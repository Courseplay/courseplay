function courseplay:mouseEvent(posX, posY, isDown, isUp, button)
	if isDown and button == 3 and self.isEntered then
		if self.show_hud then
			self.mouse_enabled = not self.mouse_enabled;
			InputBinding.setShowMouseCursor(self.mouse_enabled);
		elseif not self.show_hud and self.mouse_right_key_enabled then
			courseplay:openCloseHud(self, true)
			courseplay:buttonsActiveEnabled(self, "all");
		end
	end;
	
	local hudGfx = courseplay.hud.visibleArea;
	local mouseIsInHudArea = self.mouse_enabled and posX > hudGfx.x1 and posX < hudGfx.x2 and posY > hudGfx.y1 and posY < hudGfx.y2;
	
	if self.mouse_enabled and isDown and button == 1 and self.show_hud and self.isEntered and mouseIsInHudArea then
		for _, button in pairs(self.cp.buttons) do
			button.isClicked = false;

			if (button.page == self.showHudInfoBase or button.page == nil or button.page == self.showHudInfoBase * -1) and (button.show == nil or (button.show ~= nil and button.show)) then
				if posX > button.x and posX < button.x2 and posY > button.y and posY < button.y2 then
					local parameter = button.parameter;
					if InputBinding.isPressed(InputBinding.CP_Modifier_1) and button.modifiedParameter ~= nil then --for some reason InputBinding works in :mouseEvent
						courseplay:debug("button.modifiedParameter = " .. tostring(button.modifiedParameter), 12);
						parameter = button.modifiedParameter;
					end;

					--if (button.show == nil or (button.show ~= nil and button.show)) and (button.canBeClicked == nil or (button.canBeClicked ~= nil and button.canBeClicked)) then
					if courseplay:nilOrBool(button.show, true) and courseplay:nilOrBool(button.canBeClicked, true) then
						button.isClicked = true;
						if button.function_to_call == "showSaveCourseForm" then
							self.cp.imWriting = true
						end
						self:setCourseplayFunc(button.function_to_call, parameter);
					end;
				end
			end
		end
		
	--hover
	elseif self.mouse_enabled and not isDown and self.show_hud and self.isEntered then
		--if mouseIsInHudArea then
			for _, button in pairs(self.cp.buttons) do
				if (button.page == self.showHudInfoBase or button.page == nil or button.page == self.showHudInfoBase * -1) and courseplay:nilOrBool(button.show, true) then
					if posX > button.x and posX < button.x2 and posY > button.y and posY < button.y2 then
						button.isHovered = true;
					else
						button.isHovered = false;
					end;
				end;
				button.isClicked = false;
			end;
		--end;
	end;
end; --END mouseEvent()


function courseplay:setCourseplayFunc(func, value, noEventSend)
	if noEventSend ~= true then
		CourseplayEvent.sendEvent(self, func, value); -- Die Funktion ruft sendEvent auf und übergibt 3 Werte   (self "also mein ID", action, "Ist eine Zahl an der ich festmache welches Fenster ich aufmachen will", state "Ist der eigentliche Wert also true oder false"
	end;
	if value == "nil" then
		value = nil
	end
	courseplay:deal_with_mouse_input(self, func, value)
end

function courseplay:deal_with_mouse_input(self, func, value)
	if Utils.startsWith(func,"self") or Utils.startsWith(func,"courseplay") then
		courseplay:debug("					setting value",5)
		courseplay:setVarValueFromString(self, func, value)
		--courseplay:debug("					"..tostring(func)..": "..tostring(value),5)
		return
	end
	playSample(courseplay.hud.clickSound, 1, 1, 0);
	courseplay:debug(nameNum(self) .. ": calling function \"" .. tostring(func) .. "(" .. tostring(value) .. ")\"", 12);

	local str1,str2 = string.find(func, "row%d");
	local isRowFunction = str1 ~= nil and str2 ~= nil and str1 == 1 and str2 == string.len(func);

	if not isRowFunction then
		--@source: http://stackoverflow.com/questions/1791234/lua-call-function-from-a-string-with-function-name
		assert(loadstring('courseplay:' .. func .. '(...)'))(self, value);
		

	else
		if self.showHudInfoBase == 0 then
			local combine = self;
			if self.cp.attachedCombineIdx ~= nil and self.tippers ~= nil and self.tippers[self.cp.attachedCombineIdx] ~= nil then
				combine = self.tippers[self.cp.attachedCombineIdx];
			end;
			
			if combine.courseplayers == nil or table.getn(combine.courseplayers) == 0 then
				if func == "row1" then
					courseplay:call_player(combine)
				end
			else
				if func == "row2" then
					courseplay:start_stop_player(combine)
				end

				if func == "row3" then
					courseplay:send_player_home(combine)
				end

				if func == "row4" then
					courseplay:switch_player_side(combine)
				end
				
				--manual chopping: initiate/end turning maneuver
				if func == "row5" and combine.cp.isChopper and not self.drive and not self.isAIThreshing then
					if self.cp.turnStage == 0 then
						self.cp.turnStage = 1;
					elseif self.cp.turnStage == 1 then
						self.cp.turnStage = 0;
					end;
				end
			end

		elseif self.showHudInfoBase == 1 then
			if self.play then
				if not self.drive then
					if func == "row1" then
						courseplay:start(self)
					end

					if func == "row3" and self.ai_mode ~= 9 then
						courseplay:setStartAtFirstPoint(self)
					end

					if func == "row4" then
						courseplay:reset_course(self)
					end

				else -- driving
					
					if self.cp.last_recordnumber ~= nil and self.Waypoints[self.cp.last_recordnumber].wait and self.wait and func == "row2" then
						self.wait = false
					end

					if func == "row2" and self.StopEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil) then
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


			elseif not self.drive then
				if (not self.record and not self.record_pause) and not self.play then --- - and (table.getn(self.Waypoints) == 0) then
					if (table.getn(self.Waypoints) == 0) and not self.createCourse then
						if func == "row1" then
							courseplay:start_record(self)
						end
					end

				elseif self.record or self.record_pause then
					if func == "row1" then
						courseplay:stop_record(self)
					end;

					if not self.record_pause then
						if func == "row2" then --and self.recordnumber > 3
							courseplay:set_waitpoint(self)
						end

						if func == "row4" then --and self.recordnumber > 3
							courseplay:set_crossing(self)
						end

						if func == "row3" and self.recordnumber > 3 then
							courseplay:interrupt_record(self)
						end

					else
						if func == "row2" then
							courseplay:delete_waypoint(self)
						end
						if func == "row3" then
							courseplay:continue_record(self)
						end
					end
				end
			end --END if not self.drive
		end --END is page 0 or 1
	end --END isRowFunction
end

function courseplay:keyEvent(unicode, sym, modifier, isDown)
end
