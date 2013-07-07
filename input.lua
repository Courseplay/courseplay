function courseplay:mouseEvent(posX, posY, isDown, isUp, button)
	local mouseKey = button;

	--RIGHT CLICK
	if isDown and mouseKey == 3 and self.isEntered then
	--if self.isEntered and Input.isMouseButtonPressed(Input.MOUSE_BUTTON_RIGHT) then
		if self.cp.hud.show then
			courseplay:setMouseCursor(self, not self.mouse_enabled);
		elseif not self.cp.hud.show and self.mouse_right_key_enabled then
			courseplay:openCloseHud(self, true)
			courseplay:buttonsActiveEnabled(self, "all");
		end;
	end;

	local hudGfx = courseplay.hud.visibleArea;
	local mouseIsInHudArea = self.mouse_enabled and posX > hudGfx.x1 and posX < hudGfx.x2 and posY > hudGfx.y1 and posY < hudGfx.y2;

	--LEFT CLICK
	if isDown and mouseKey == 1 and self.mouse_enabled and self.cp.hud.show and self.isEntered and mouseIsInHudArea then
		local continueSearchingButton = true;
		for _,button in pairs(self.cp.buttons.global) do
			if button.show and courseplay:mouseIsInButtonArea(posX, posY, button) then
				continueSearchingButton = false;
				courseplay:handleMouseClickForButton(self, button);
				break;
			end;
		end;

		if continueSearchingButton then
			for _,button in pairs(self.cp.buttons[tostring(self.cp.hud.currentPage)]) do
				if button.canBeClicked and button.show and courseplay:mouseIsInButtonArea(posX, posY, button) then
					continueSearchingButton = false;
					courseplay:handleMouseClickForButton(self, button);
					break;
				end;
			end;
		end;

		if continueSearchingButton then
			if self.cp.hud.currentPage == 2 then
				for _,button in pairs(self.cp.buttons["-2"]) do
					if button.show and courseplay:mouseIsInButtonArea(posX, posY, button) then
						courseplay:handleMouseClickForButton(self, button);
						break;
					end;
				end;
			end;
		end;

	--HOVER
	elseif self.mouse_enabled and not isDown and self.cp.hud.show and self.isEntered then
		for _,button in pairs(self.cp.buttons.global) do
			button.isClicked = false;
			if button.show then
				button.isHovered = false;
				if courseplay:mouseIsInButtonArea(posX, posY, button) then
					button.isClicked = false;
					button.isHovered = true;
				end;
			end;
		end;

		self.cp.hud.mouseWheel.render = false;
		for _,button in pairs(self.cp.buttons[tostring(self.cp.hud.currentPage)]) do
			button.isClicked = false;
			if button.show then
				button.isHovered = false;
				if courseplay:mouseIsInButtonArea(posX, posY, button) then
					button.isHovered = true;

					if button.isMouseWheelArea and (button.canScrollUp or button.canScrollDown) then
						--Mouse wheel icon
						self.cp.hud.mouseWheel.render = true;
						self.cp.hud.mouseWheel.icon:setPosition(posX + 3/1920, posY - 16/1080);

						--action
						local parameter = button.parameter;
						if InputBinding.isPressed(InputBinding.CP_Modifier_1) and button.modifiedParameter ~= nil then
							parameter = button.modifiedParameter;
						end;

						local upParameter = parameter;
						local downParameter = upParameter * -1;

						if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) and button.canScrollUp then
							courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_UP: %s(%s)", nameNum(self), tostring(button.function_to_call), tostring(upParameter)), 12);
							self:setCourseplayFunc(button.function_to_call, upParameter);
						elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) and button.canScrollDown then
							courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_DOWN: %s(%s)", nameNum(self), tostring(button.function_to_call), tostring(downParameter)), 12);
							self:setCourseplayFunc(button.function_to_call, downParameter);
						end;
					end;
				end;

				if button.hoverText then
					self.cp.hud.content.pages[button.page][button.row][1].isHovered = button.isHovered;
				end;
			end;
		end;

		if self.cp.hud.currentPage == 2 then
			for _,button in pairs(self.cp.buttons["-2"]) do
				button.isClicked = false;
				if button.show then
					button.isHovered = false;
					if courseplay:mouseIsInButtonArea(posX, posY, button) then
						button.isClicked = false;
						button.isHovered = true;
					end;

					if button.hoverText then
						self.cp.hud.content.pages[2][button.row][1].isHovered = button.isHovered;
					end;
				end;
			end;
		end;
	end;
end; --END mouseEvent()

function courseplay:mouseIsInButtonArea(x, y, button)
	return x > button.x and x < button.x2 and y > button.y and y < button.y2;
end;

function courseplay:handleMouseClickForButton(self, button)
	local parameter = button.parameter;
	if InputBinding.isPressed(InputBinding.CP_Modifier_1) and button.modifiedParameter ~= nil then --for some reason InputBinding works in :mouseEvent
		courseplay:debug("button.modifiedParameter = " .. tostring(button.modifiedParameter), 12);
		parameter = button.modifiedParameter;
	end;

	if button.show and button.canBeClicked and not button.isDisabled then
		if button.function_to_call == "rowButton" and self.cp.hud.content.pages[self.cp.hud.currentPage][button.parameter][1].text == nil then
			return;
		end;

		button.isClicked = true;
		if button.function_to_call == "showSaveCourseForm" then
			self.cp.imWriting = true
		end
		self:setCourseplayFunc(button.function_to_call, parameter);
		button.isClicked = false;
	end;
end;

function courseplay:setCourseplayFunc(func, value, noEventSend)
	if noEventSend ~= true then
		CourseplayEvent.sendEvent(self, func, value); -- Die Funktion ruft sendEvent auf und übergibt 3 Werte   (self "also mein ID", action, "Ist eine Zahl an der ich festmache welches Fenster ich aufmachen will", state "Ist der eigentliche Wert also true oder false"
	end;
	if value == "nil" then
		value = nil
	end
	courseplay:executeFunction(self, func, value)
end

function courseplay:executeFunction(self, func, value, overwrittenPage)
	if Utils.startsWith(func,"self") or Utils.startsWith(func,"courseplay") then
		courseplay:debug("					setting value",5)
		courseplay:setVarValueFromString(self, func, value)
		--courseplay:debug("					"..tostring(func)..": "..tostring(value),5)
		return
	end
	playSample(courseplay.hud.clickSound, 1, 1, 0);
	courseplay:debug(nameNum(self) .. ": calling function \"" .. tostring(func) .. "(" .. tostring(value) .. ")\"", 12);

	if func ~= "rowButton" then
		--@source: http://stackoverflow.com/questions/1791234/lua-call-function-from-a-string-with-function-name
		assert(loadstring('courseplay:' .. func .. '(...)'))(self, value);

	else
		local page = Utils.getNoNil(overwrittenPage, self.cp.hud.currentPage);
		local line = value;
		if page == 0 then
			local combine = self;
			if self.cp.attachedCombineIdx ~= nil and self.tippers ~= nil and self.tippers[self.cp.attachedCombineIdx] ~= nil then
				combine = self.tippers[self.cp.attachedCombineIdx];
			end;

			if combine.courseplayers == nil or table.getn(combine.courseplayers) == 0 then
				if line == 1 then
					courseplay:call_player(combine);
				end;
			else
				if line == 2 then
					courseplay:start_stop_player(combine);
				elseif line == 3 then
					courseplay:send_player_home(combine);
				elseif line == 4 then
					courseplay:switch_player_side(combine);
				elseif line == 5 and combine.cp.isChopper and not self.drive and not self.isAIThreshing then --manual chopping: initiate/end turning maneuver
					if self.cp.turnStage == 0 then
						self.cp.turnStage = 1;
					elseif self.cp.turnStage == 1 then
						self.cp.turnStage = 0;
					end;
				end;
			end;

		elseif page == 1 then
			if self.play then
				if not self.drive then
					if line == 1 then
						courseplay:start(self);
					elseif line == 3 and self.ai_mode ~= 9 then
						courseplay:setStartAtFirstPoint(self);
					elseif line == 4 then
						courseplay:reset_course(self);
					end;

				else -- driving
					if line == 1 then
						courseplay:stop(self);
					elseif line == 2 and self.cp.last_recordnumber ~= nil and self.Waypoints[self.cp.last_recordnumber].wait and self.wait then
						self.wait = false;
					elseif line == 2 and self.StopEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil) then
						self.StopEnd = false;
					elseif line == 3 and not self.loaded then
						self.loaded = true;
					elseif line == 4 and not self.StopEnd then
						self.StopEnd = true
					elseif line == 5 then
						if self.ai_mode == 1 or self.ai_mode == 2 then
							self.cp.unloadAtSiloStart = not self.cp.unloadAtSiloStart;
						elseif self.ai_mode == 4 then
							self.cp.ridgeMarkersAutomatic = not self.cp.ridgeMarkersAutomatic;
						end;
					end;
				end; -- end driving


			elseif not self.drive then
				if not self.record and not self.record_pause and not self.play and table.getn(self.Waypoints) == 0 and not self.createCourse then
					if line == 1 then
						courseplay:start_record(self);
					end;

				elseif self.record or self.record_pause then
					if line == 1 then
						courseplay:stop_record(self);

					elseif not self.record_pause then
						if line == 2 then --and self.recordnumber > 3
							courseplay:set_waitpoint(self);
						elseif line == 3 and self.recordnumber > 3 then
							courseplay:interrupt_record(self);
						elseif line == 4 then --and self.recordnumber > 3
							courseplay:set_crossing(self);
						elseif line == 5 then
							courseplay:change_DriveDirection(self);
						end;

					else
						if line == 2 then
							courseplay:delete_waypoint(self);
						elseif line == 3 then
							courseplay:continue_record(self);
						end;
					end;
				end;
			end; --END if not self.drive
		end; --END is page 0 or 1
	end; --END isRowFunction
end;

function courseplay:keyEvent(unicode, sym, modifier, isDown)
end
