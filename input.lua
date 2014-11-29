function courseplay:mouseEvent(posX, posY, isDown, isUp, mouseButton)
	--RIGHT CLICK
	if isDown and mouseButton == courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.buttonId and self.isEntered then
		if self.cp.hud.show then
			courseplay:setMouseCursor(self, not self.cp.mouseCursorActive);
		elseif not self.cp.hud.show and self.cp.hud.openWithMouse then
			courseplay:openCloseHud(self, true)
			courseplay:buttonsActiveEnabled(self, "all");
		end;
	end;

	local hudGfx = courseplay.hud.visibleArea;
	local mouseIsInHudArea = self.cp.mouseCursorActive and courseplay:mouseIsInArea(posX, posY, hudGfx.x1, hudGfx.x2, hudGfx.y1, self.cp.suc.active and hudGfx.y2InclSuc or hudGfx.y2);

	-- if not mouseIsInHudArea then return; end;

	--LEFT CLICK
	if (isDown or isUp) and mouseButton == courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION.buttonId and self.cp.mouseCursorActive and self.cp.hud.show and self.isEntered and mouseIsInHudArea then
		local buttonToHandle;

		if self.cp.suc.active then
			for _,button in pairs(self.cp.buttons.suc) do
				if button.show and button:getHasMouse(posX, posY) then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			for _,button in pairs(self.cp.buttons.global) do
				if button.show and button:getHasMouse(posX, posY) then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			for _,button in pairs(self.cp.buttons[self.cp.hud.currentPage]) do
				if button.canBeClicked and button.show and button:getHasMouse(posX, posY) then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			if self.cp.hud.currentPage == 2 then
				for _,button in pairs(self.cp.buttons[-2]) do
					if button.show and button:getHasMouse(posX, posY) then
						buttonToHandle = button;
						break;
					end;
				end;
			end;
		end;

		if buttonToHandle then
			buttonToHandle:setClicked(isDown);
			if buttonToHandle.hoverText and buttonToHandle.functionToCall ~= nil then
				self.cp.hud.content.pages[buttonToHandle.page][buttonToHandle.row][1].isClicked = isDown;
			end;
			if isUp then
				buttonToHandle:handleMouseClick();
			end;
		end;



	--HOVER
	elseif self.cp.mouseCursorActive and not isDown and self.cp.hud.show and self.isEntered then
		-- local currentHoveredButton;
		if self.cp.suc.active then
			for _,button in pairs(self.cp.buttons.suc) do
				if button.show and not button.isHidden then
					button:setClicked(false);
					button:setHovered(button:getHasMouse(posX, posY));
				end;
			end;
		end;

		for _,button in pairs(self.cp.buttons.global) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setClicked(false);
				button:setHovered(button:getHasMouse(posX, posY));
			end;
		end;

		self.cp.hud.mouseWheel.render = false;
		for _,button in pairs(self.cp.buttons[self.cp.hud.currentPage]) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setHovered(button:getHasMouse(posX, posY));
				if button.isHovered then

					if button.isMouseWheelArea and (button.canScrollUp or button.canScrollDown) then
						--Mouse wheel icon
						self.cp.hud.mouseWheel.render = true;
						self.cp.hud.mouseWheel.icon:setPosition(posX + 3/g_screenWidth, posY - 16/g_screenHeight);

						--action
						local parameter = button.parameter;
						if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) and button.modifiedParameter ~= nil then
							parameter = button.modifiedParameter;
						end;

						local upParameter = parameter;
						local downParameter = upParameter * -1;

						if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) and button.canScrollUp then
							courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_UP: %s(%s)", nameNum(self), tostring(button.functionToCall), tostring(upParameter)), 18);
							self:setCourseplayFunc(button.functionToCall, upParameter, false, button.page);
						elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) and button.canScrollDown then
							courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_DOWN: %s(%s)", nameNum(self), tostring(button.functionToCall), tostring(downParameter)), 18);
							self:setCourseplayFunc(button.functionToCall, downParameter, false, button.page);
						end;
					end;
				end;

				if button.hoverText then
					self.cp.hud.content.pages[button.page][button.row][1].isHovered = button.isHovered;
				end;
			end;
		end;

		if self.cp.hud.currentPage == 2 then
			for _,button in pairs(self.cp.buttons[-2]) do
				button:setClicked(false);
				if button.show and not button.isHidden then
					button:setHovered(false);
					if button:getHasMouse(posX, posY) then
						button:setClicked(false);
						button:setHovered(true);
					end;

					if button.hoverText then
						self.cp.hud.content.pages[2][button.row][1].isHovered = button.isHovered;
					end;
				end;
			end;
		end;
	end;
end; --END mouseEvent()

function courseplay:mouseIsInArea(mouseX, mouseY, areaX1, areaX2, areaY1, areaY2)
	return mouseX >= areaX1 and mouseX <= areaX2 and mouseY >= areaY1 and mouseY <= areaY2;
end;

function courseplay.button:handleMouseClick(vehicle)
	vehicle = vehicle or self.vehicle;
	local parameter = self.parameter;
	if InputBinding.isPressed(InputBinding.COURSEPLAY_MODIFIER) and self.modifiedParameter ~= nil then --for some reason InputBinding works in :mouseEvent
		courseplay:debug("self.modifiedParameter = " .. tostring(self.modifiedParameter), 18);
		parameter = self.modifiedParameter;
	end;

	if self.show and not self.isHidden and self.canBeClicked and not self.isDisabled then
		if self.functionToCall == "rowButton" and vehicle.cp.hud.content.pages[vehicle.cp.hud.currentPage][self.parameter][1].text == nil then
			return;
		end;

		-- self:setClicked(true);
		if self.functionToCall == "showSaveCourseForm" then
			vehicle.cp.imWriting = true
		end
		if self.functionToCall == "goToVehicle" then
			courseplay:executeFunction(vehicle, "goToVehicle", parameter)
		else
			vehicle:setCourseplayFunc(self.functionToCall, parameter, false, self.page);
		end
		-- self:setClicked(false);
	end;
end;

function courseplay:setCourseplayFunc(func, value, noEventSend, page)
	--print(string.format("courseplay:setCourseplayFunc( %s, %s, %s, %s)",tostring(func), tostring(value), tostring(noEventSend), tostring(page)))
	if noEventSend ~= true then
		CourseplayEvent.sendEvent(self, func, value,noEventSend,page); -- Die Funktion ruft sendEvent auf und übergibt 3 Werte   (self "also mein ID", action, "Ist eine Zahl an der ich festmache welches Fenster ich aufmachen will", state "Ist der eigentliche Wert also true oder false"
	end;
	if value == "nil" then
		value = nil
	end
	courseplay:executeFunction(self, func, value, page);
	if page and self.cp.hud.reloadPage[page] ~= nil then
		courseplay.hud:setReloadPageOrder(self, page, true);
	end;
end

function courseplay:executeFunction(self, func, value, page)
	if func == "setMPGlobalInfoText" then
		courseplay:setGlobalInfoText(self, value, page)
		courseplay:debug("					setting infoText: "..value..", force remove: "..tostring(page),5)
		return
	elseif Utils.startsWith(func,"self") or Utils.startsWith(func,"courseplay") then
		courseplay:debug("					setting value",5)
		courseplay:setVarValueFromString(self, func, value)
		--courseplay:debug("					"..tostring(func)..": "..tostring(value),5)
		return
	end
	playSample(courseplay.hud.clickSound, 1, 1, 0);
	courseplay:debug(('%s: calling function "%s(%s)"'):format(nameNum(self), tostring(func), tostring(value)), 18);

	if func ~= "rowButton" then
		--@source: http://stackoverflow.com/questions/1791234/lua-call-function-from-a-string-with-function-name
		assert(loadstring('courseplay:' .. func .. '(...)'))(self, value);

	else
		local page = Utils.getNoNil(page, self.cp.hud.currentPage);
		local line = value;
		if page == 0 then
			local combine = self;
			if self.cp.attachedCombineIdx ~= nil and self.cp.workTools ~= nil and self.cp.workTools[self.cp.attachedCombineIdx] ~= nil then
				combine = self.cp.workTools[self.cp.attachedCombineIdx];
			end;

			if not combine.cp.isChopper then
				if line == 4 then
					courseplay:toggleDriverPriority(combine);
				elseif line == 5 and self:getIsCourseplayDriving() and self.cp.mode == 6 then
					courseplay:toggleStopWhenUnloading(combine);
				end;
			end;

			if combine.courseplayers == nil or #(combine.courseplayers) == 0 then
				if line == 1 then
					courseplay:toggleWantsCourseplayer(combine);
				end;
			else
				if line == 2 then
					courseplay:startStopCourseplayer(combine);
				elseif line == 3 then
					courseplay:sendCourseplayerHome(combine);
				elseif line == 4 and combine.cp.isChopper then
					courseplay:switchCourseplayerSide(combine);
				elseif line == 5 and combine.cp.isChopper and not self:getIsCourseplayDriving() and not self.isAIThreshing then --manual chopping: initiate/end turning maneuver
					if self.cp.turnStage == 0 then
						self.cp.turnStage = 1;
					elseif self.cp.turnStage == 1 then
						self.cp.turnStage = 0;
					end;
				end;
			end;

		elseif page == 1 then
			if self.cp.canDrive then
				if not self:getIsCourseplayDriving() then
					if line == 1 then
						courseplay:start(self);
					elseif line == 3 and self.cp.mode ~= 9 then
						courseplay:changeStartAtPoint(self);
					elseif line == 4 then
						courseplay:clearCurrentLoadedCourse(self);
					elseif line == 6 and self.cp.mode == 1 and self.cp.workTools[1] ~= nil and self.cp.workTools[1].allowFillFromAir and self.cp.workTools[1].allowTipDischarge then
						self.cp.multiSiloSelectedFillType = courseplay:getNextFillableFillType(self);
					end;

				else -- driving
					if line == 1 then
						courseplay:stop(self);
					elseif line == 2 and self.cp.HUD1wait then
						courseplay:cancelWait(self);
					elseif line == 2 and self.cp.stopAtEnd and (self.recordnumber == self.maxnumber or self.cp.currentTipTrigger ~= nil) then
						courseplay:setStopAtEnd(self, false);
					elseif line == 3 and not self.cp.isLoaded then
						courseplay:setIsLoaded(self, true);
					elseif line == 4 and not self.cp.stopAtEnd then
						courseplay:setStopAtEnd(self, true);
					elseif line == 5 then
						if self.cp.mode == 4 and self.cp.hasSowingMachine then
							self.cp.ridgeMarkersAutomatic = not self.cp.ridgeMarkersAutomatic;
						elseif self.cp.mode == 6 and self.cp.hasBaleLoader and not self.hasUnloadingRefillingCourse then
							self.cp.automaticUnloadingOnField = not self.cp.automaticUnloadingOnField;
						end;
					elseif line == 6 then
						if self.cp.tipperHasCover and (self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 5 or self.cp.mode == 6) then
							self.cp.automaticCoverHandling = not self.cp.automaticCoverHandling;
						end;
					end;
				end; -- end driving


			elseif not self:getIsCourseplayDriving() then
				if not self.cp.isRecording and not self.cp.recordingIsPaused and not self.cp.canDrive and #(self.Waypoints) == 0 then
					if line == 1 then
						courseplay:start_record(self);
					elseif line == 3 then
						courseplay:setCustomSingleFieldEdge(self);
					elseif line == 5 and self.cp.fieldEdge.customField.fieldNum > 0 then
						courseplay:addCustomSingleFieldEdgeToList(self);
					end;
				end;
			end; --END if not self:getIsCourseplayDriving()
		end; --END is page 0 or 1
	end; --END isRowFunction
end;

function courseplay:keyEvent(unicode, sym, modifier, isDown)
end;

function courseplay:setInputBindings()
	courseplay.inputBindings = {
		keyboard = {};
		mouse = {};
	};

	--MODIFIER
	local modifierAction = InputBinding.actions[InputBinding.COURSEPLAY_MODIFIER];
	courseplay.inputBindings.modifier = {
		inputBinding = InputBinding.COURSEPLAY_MODIFIER;
		actionIndex = modifierAction.actionIndex;
		keyId = modifierAction.keys1[1];
		isRealModifier = Input.keyIdIsModifier[modifierAction.keys1[1]];
		keyName = Input.keyIdToIdName[modifierAction.keys1[1]];
		displayName = KeyboardHelper.getKeyNames(modifierAction.keys1)
	};
	if not courseplay.inputBindings.modifier.isRealModifier then
		print(string.format('Warning: Courseplay InputBinding modifier %q (%s) is not a real modifier. Conflicts with other mods may arise.', courseplay.inputBindings.modifier.keyName, courseplay.inputBindings.modifier.displayName));
	end;

	--KEYBOARD
	local courseplayKeyboardInputs = { 'COURSEPLAY_HUD', 'COURSEPLAY_START_STOP', 'COURSEPLAY_CANCELWAIT', 'COURSEPLAY_DRIVENOW' };
	for i,name in pairs(courseplayKeyboardInputs) do
		courseplay:createNewCombinedInputBinding(name);
	end;
	--print(tableShow(courseplay.inputBindings.keyboard, 'courseplay.inputBindings.keyboard'));


	--MOUSE
	local courseplayMouseInputs = { 'COURSEPLAY_MOUSEACTION', 'COURSEPLAY_MOUSEACTION_SECONDARY' };
	for i,name in pairs(courseplayMouseInputs) do
		local action = InputBinding.actions[InputBinding[name]];
		local mouseButtonId = action.mouseButtons[1]; --can there be more than 1 mouseButton for 1 action?
		if mouseButtonId == nil then
			print(string.format('Warning: Courseplay InputBinding %q has no mouse button attached to it. Functionality will not be guaranteed.', name));
		end;

		courseplay.inputBindings.mouse[name] = {
			name = name;
			buttonId = mouseButtonId;
			keyName = Input.mouseButtonIdToIdName[mouseButtonId];
			displayName = g_i18n:getText('mouse') .. ' ' .. MouseHelper.getButtonNames(action.mouseButtons);
			actionIndex = action.actionIndex;
			inputBinding = InputBinding[name];
		};
	end;
	--print(tableShow(courseplay.inputBindings.mouse, 'courseplay.inputBindings.mouse'));
end;

function courseplay:createNewCombinedInputBinding(name)
	local originalAction = InputBinding.actions[InputBinding[name]];

	if #(originalAction.keys1) == 1 then
		local action = courseplay.utils.table.copy(originalAction);
		local actionIndex = #(InputBinding.actions) + 1;

		action.name = name .. '_COMBINED';
		local keyNameList = courseplay.inputBindings.modifier.keyName .. ' ' .. Input.keyIdToIdName[originalAction.keys1[1]];
		action.keys1 = InputBinding.loadKeyList(keyNameList, action.name);
		action.keys1Set = Utils.listToSet(action.keys1);
		action.actionIndex = actionIndex;
		InputBinding[action.name] = actionIndex;
		table.insert(InputBinding.actions, action);

		courseplay.inputBindings.keyboard[action.name] = {
			originalKeyActionName = name;
			originalKeyInputBinding = InputBinding[name];
			originalModifierInputBinding = courseplay.inputBindings.modifier.inputBinding;
			actionIndex = actionIndex;
			displayName = courseplay.inputBindings.modifier.displayName .. ' + ' .. KeyboardHelper.getKeyNames(originalAction.keys1);
		};

		if g_i18n:hasText(name) then
			local text = g_i18n:getText(name) .. ' (COMBINED)';
			g_i18n:setText(action.name, text);
			g_i18n.globalI18N.texts[action.name] = text;
			-- print(string.format('CP: set newly created inputbinding text for %q to %q', tostring(action.name), tostring(text)));
		end;
	end;
end;
