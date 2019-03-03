function courseplay:onMouseEvent(posX, posY, isDown, isUp, mouseButton)
	--RIGHT CLICK
	-- Input binding debug
	local vehicle = g_currentMission.controlledVehicle		
	if not vehicle or not vehicle.hasCourseplaySpec then return end
	
	--print(string.format('courseplay:mouseEvent(posX(%s), posY(%s), isDown(%s), isUp(%s), mouseButton(%s))', tostring(posX), tostring(posY), tostring(isDown), tostring(isUp), tostring(mouseButton) ))
	--print(string.format("if isUp(%s) and mouseButton(%s) == courseplay.inputBindings.mouse.secondaryButtonId(%s) and Enterable.getIsEntered(self)(%s) then"
	--,tostring(isUp),tostring(mouseButton),tostring(courseplay.inputBindings.mouse.secondaryButtonId),tostring(Enterable.getIsEntered(self))))
	if isUp and mouseButton == courseplay.inputBindings.mouse.secondaryButtonId and vehicle:getIsEntered() then
		if vehicle.cp.hud.show then
			courseplay:setMouseCursor(vehicle, not vehicle.cp.mouseCursorActive);
		elseif not vehicle.cp.hud.show and vehicle.cp.hud.openWithMouse then
			courseplay:openCloseHud(vehicle, true)
		end;
	end;

	local hudGfx = courseplay.hud.visibleArea;
	local mouseIsInHudArea = vehicle.cp.mouseCursorActive and courseplay:mouseIsInArea(posX, posY, hudGfx.x1, hudGfx.x2, hudGfx.y1, vehicle.cp.suc.active and courseplay.hud.suc.visibleArea.y2 or hudGfx.y2);
	-- if not mouseIsInHudArea then return; end;

	--LEFT CLICK
	if (isDown or isUp) and mouseButton == courseplay.inputBindings.mouse.primaryButtonId and vehicle.cp.mouseCursorActive and vehicle.cp.hud.show and vehicle:getIsEntered() and mouseIsInHudArea then
		local buttonToHandle;

		if vehicle.cp.suc.active then
			for _,button in pairs(vehicle.cp.buttons.suc) do
				if button.show and button:getHasMouse(posX, posY) then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			for _,button in pairs(vehicle.cp.buttons.global) do
				if button.show and button:getHasMouse(posX, posY) then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			for _,button in pairs(vehicle.cp.buttons[vehicle.cp.hud.currentPage]) do
				if button.canBeClicked and button.show and button:getHasMouse(posX, posY) then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			if vehicle.cp.hud.currentPage == 2 then
				for _,button in pairs(vehicle.cp.buttons[-2]) do
					if button.show and button:getHasMouse(posX, posY) then
						buttonToHandle = button;
						break;
					end;
				end;
			end;
		end;

		if buttonToHandle then
			buttonToHandle:setClicked(isDown);
			if not buttonToHandle.isDisabled and buttonToHandle.hoverText and buttonToHandle.functionToCall ~= nil then
				vehicle.cp.hud.content.pages[buttonToHandle.page][buttonToHandle.row][1].isClicked = isDown;
			end;
			if isUp then
				buttonToHandle:handleMouseClick();
			end;
			return;
		end;



	--HOVER
	elseif vehicle.cp.mouseCursorActive and not isDown and vehicle.cp.hud.show and vehicle:getIsEntered() then
		-- local currentHoveredButton;
		if vehicle.cp.suc.active then
			for _,button in pairs(vehicle.cp.buttons.suc) do
				if button.show and not button.isHidden then
					button:setClicked(false);
					button:setHovered(button:getHasMouse(posX, posY));
				end;
			end;
		end;

		for _,button in pairs(vehicle.cp.buttons.global) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setClicked(false);
				button:setHovered(button:getHasMouse(posX, posY));
			end;
		end;

		vehicle.cp.hud.mouseWheel.render = false;
		for _,button in pairs(vehicle.cp.buttons[vehicle.cp.hud.currentPage]) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setHovered(button:getHasMouse(posX, posY));
				if button.isHovered then
					if button.isMouseWheelArea and (button.canScrollUp or button.canScrollDown) then
						--Mouse wheel icon
						vehicle.cp.hud.mouseWheel.render = true;
						vehicle.cp.hud.mouseWheel.icon:setPosition(posX + 3/g_screenWidth, posY - 16/g_screenHeight);

						--action
						local parameter = button.parameter;
						if courseplay.inputActions.COURSEPLAY_MODIFIER.isPressed and button.modifiedParameter ~= nil then
							parameter = button.modifiedParameter;
						end;

						local upParameter = parameter;
						local downParameter = upParameter * -1;

						if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) and button.canScrollUp then
							courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_UP: %s(%s)", nameNum(vehicle), tostring(button.functionToCall), tostring(upParameter)), 18);
							vehicle:setCourseplayFunc(button.functionToCall, upParameter, false, button.page);
						elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) and button.canScrollDown then
							courseplay:debug(string.format("%s: MOUSE_BUTTON_WHEEL_DOWN: %s(%s)", nameNum(vehicle), tostring(button.functionToCall), tostring(downParameter)), 18);
							vehicle:setCourseplayFunc(button.functionToCall, downParameter, false, button.page);
						end;
					end;
				end;

				if button.hoverText and not button.isDisabled then
					vehicle.cp.hud.content.pages[button.page][button.row][1].isHovered = button.isHovered;
				end;
			end;
		end;

		if vehicle.cp.hud.currentPage == 2 then
			for _,button in pairs(vehicle.cp.buttons[-2]) do
				button:setClicked(false);
				if button.show and not button.isHidden then
					button:setHovered(button:getHasMouse(posX, posY));

					if button.hoverText then
						vehicle.cp.hud.content.pages[2][button.row][1].isHovered = button.isHovered;
					end;
				end;
			end;
		end;

		--- Prevent mouse from zooming when mouse cursor is inside the CP Hud Mouse Wheel area
		self:lockContext(vehicle.cp.hud.mouseWheel.render);
	end;


	-- ##################################################
	-- 2D COURSE WINDOW: DRAG + DROP MOVE
	if vehicle.cp.course2dDrawData and (vehicle.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_2DONLY or vehicle.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_BOTH) then
		local plot = CpManager.course2dPlotField;
		if isDown and mouseButton == courseplay.inputBindings.mouse.primaryButtonId and vehicle.cp.mouseCursorActive and vehicle:getIsEntered() and courseplay:mouseIsInArea(posX, posY, plot.x, plot.x + plot.width, plot.y, plot.y + plot.height) then
			CpManager.course2dDragDropMouseDown = { posX, posY };
			if vehicle.cp.course2dPdaMapOverlay then
				vehicle.cp.course2dPdaMapOverlay.origPos = { vehicle.cp.course2dPdaMapOverlay.x, vehicle.cp.course2dPdaMapOverlay.y };
			else
				vehicle.cp.course2dBackground.origPos = { vehicle.cp.course2dBackground.x, vehicle.cp.course2dBackground.y };
			end;
		elseif isUp and CpManager.course2dDragDropMouseDown ~= nil then
			courseplay.utils:move2dCoursePlotField(vehicle, posX, posY);
		elseif not isUp and not isDown and CpManager.course2dDragDropMouseDown ~= nil then
			courseplay.utils:update2dCourseBackgroundPos(vehicle, posX, posY);
		end;
	end;
end; --END mouseEvent()

function courseplay:mouseIsInArea(mouseX, mouseY, areaX1, areaX2, areaY1, areaY2)
	return mouseX >= areaX1 and mouseX <= areaX2 and mouseY >= areaY1 and mouseY <= areaY2;
end;

function courseplay.button:handleMouseClick(vehicle)
	vehicle = vehicle or self.vehicle;
	local parameter = self.parameter;
	if courseplay.inputActions.COURSEPLAY_MODIFIER.isPressed and self.modifiedParameter ~= nil then
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
		--Reload vehicle preference just after saved them, correcting the HUD show window trouble 
		courseplay:loadVehicleCPSettings(vehicle, courseplay.savegame_custom.xmlFile, courseplay.savegame_custom.key, courseplay.savegame_custom.resetVehicles);
	end;
end;

function courseplay:setCourseplayFunc(func, value, noEventSend, page)
	--print(string.format("courseplay:setCourseplayFunc( %s, %s, %s, %s)",tostring(func), tostring(value), tostring(noEventSend), tostring(page)))
	if noEventSend ~= true then
		--Tommi CourseplayEvent.sendEvent(self, func, value,noEventSend,page); -- Die Funktion ruft sendEvent auf und übergibt 3 Werte   (self "also mein ID", action, "Ist eine Zahl an der ich festmache welches Fenster ich aufmachen will", state "Ist der eigentliche Wert also true oder false"
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
		CpManager:setGlobalInfoText(self, value, page)
		courseplay:debug("					setting infoText: "..value..", force remove: "..tostring(page),5)
		return
	elseif StringUtil.startsWith(func,"self") or StringUtil.startsWith(func,"courseplay") then
		courseplay:debug("					setting value",5)
		courseplay:setVarValueFromString(self, func, value)
		--courseplay:debug("					"..tostring(func)..": "..tostring(value),5)
		return
	end
	if self:getIsEntered() then
		--The old sound playSample(courseplay.hud.clickSound, 1, 1, 0, 0, 0);
		-- The new gui click sound
		g_currentMission.hud.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
	end
	courseplay:debug(('%s: calling function "%s(%s)"'):format(nameNum(self), tostring(func), tostring(value)), 18);

	if func ~= "rowButton" then
		--@source: http://stackoverflow.com/questions/1791234/lua-call-function-from-a-string-with-function-name
		assert(loadstring('courseplay:' .. func .. '(...)'))(self, value);

	else
		local page = Utils.getNoNil(page, self.cp.hud.currentPage);
		local line = value;
		if page == 0 then
			local combine = self;
			if self.cp.attachedCombine ~= nil then
				combine = self.cp.attachedCombine;
			end;

			if not combine.cp.isChopper then
				if line == 4 then
					courseplay:toggleDriverPriority(combine);
				elseif line == 5 and self.cp.mode == courseplay.MODE_FIELDWORK then
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
				elseif line == 5 and combine.cp.isChopper and not self:getIsCourseplayDriving() and not self.aiIsStarted then --manual chopping: initiate/end turning maneuver
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
						courseplay:getPipesRotation(self);
					elseif line == 5 then
						courseplay:toggleFertilizeOption(self);
					end;

				else -- driving
					if line == 1 then
						courseplay:stop(self);
					elseif line == 2 and (self.cp.HUD1wait or (self.cp.driver and self.cp.driver:isWaiting())) then
						if self.cp.stopAtEnd and (self.cp.waypointIndex == self.cp.numWaypoints or self.cp.currentTipTrigger ~= nil) then
							courseplay:setStopAtEnd(self, false);
						else
							courseplay:cancelWait(self);
						end;
					elseif line == 3 and not self.cp.isLoaded then
						courseplay:setIsLoaded(self, true);
					elseif line == 4 then
						courseplay:setStopAtEnd(self, not self.cp.stopAtEnd);
					elseif line == 5 then
						if self.cp.mode == courseplay.MODE_SEED_FERTILIZE and self.cp.hasSowingMachine then
							self.cp.ridgeMarkersAutomatic = not self.cp.ridgeMarkersAutomatic;
						elseif self.cp.mode == courseplay.MODE_FIELDWORK and self.cp.hasBaleLoader and not self.hasUnloadingRefillingCourse then
							self.cp.automaticUnloadingOnField = not self.cp.automaticUnloadingOnField;
						end;
					elseif line == 6 then
						if self.cp.tipperHasCover and (self.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or self.cp.mode == courseplay.MODE_COMBI or self.cp.mode == courseplay.MODE_TRANSPORT or self.cp.mode == courseplay.MODE_FIELDWORK) then
							self.cp.automaticCoverHandling = not self.cp.automaticCoverHandling;
						end;
					elseif line == 7 then
						self.cp.turnOnField = not self.cp.turnOnField;
					elseif line == 8 then
						self.cp.oppositeTurnMode = not self.cp.oppositeTurnMode;
					end;

				end; -- end driving
				if line == 5 then
					courseplay:toggleConvoyActive(self)
				end
			elseif not self:getIsCourseplayDriving() then
				if not self.cp.isRecording and not self.cp.recordingIsPaused and not self.cp.canDrive and self.cp.numWaypoints == 0 then
					if line == 1 then
						courseplay:start_record(self);
					elseif line == 3 then
						courseplay:setCustomSingleFieldEdge(self);
					elseif line == 5 and self.cp.fieldEdge.customField.fieldNum > 0 then
						courseplay:addCustomSingleFieldEdgeToList(self);
					end;
				end;
			end; --END if not self:getIsCourseplayDriving()

		elseif page == 10 then
			if line == 1 and not self:getIsCourseplayDriving() then
				courseplay:toggleMode10Mode(self)
			elseif line == 2 then
				courseplay:toggleMode10SearchMode(self)
			elseif line == 5 then
				courseplay:toggleMode10automaticSpeed(self)
			elseif line == 6 then
				if self.cp.mode10.leveling then
					courseplay:toggleMode10AutomaticHeight(self)
				end
			elseif 	line == 7 then
				courseplay:toggleMode10drivingThroughtLoading(self)
			end 
		end; --END is page 0 or 1 or 3 or 10
	end; --END isRowFunction
end;

--- Lock/Unlock mouse and keyboard form any interaction outside the courseplay hud
function courseplay:lockContext(lockIt)
	local lockIt = lockIt ~= false;
	if lockIt and g_inputBinding:getContextName() ~= courseplay.INPUT_CONTEXT_NAME then
		g_inputBinding:setContext(courseplay.INPUT_CONTEXT_NAME, true, false);
	elseif not lockIt and g_inputBinding:getContextName() == courseplay.INPUT_CONTEXT_NAME then
		g_inputBinding:revertContext(true);
	end
end;

courseplay.inputBindings = {};
courseplay.inputBindings.mouse = {};
courseplay.inputBindings.mouse.mouseButtonOverlays = {
	MOUSE_BUTTON_NONE	   = 'mouseNMB.png',
	MOUSE_BUTTON_LEFT	   = 'mouseLMB.png',
	MOUSE_BUTTON_RIGHT	   = 'mouseRMB.png',
	MOUSE_BUTTON_MIDDLE	   = 'mouseMMB.png',
	MOUSE_BUTTON_LEFTRIGHT = 'mouseBMB.png'
};
courseplay.inputBindings.keyboard = {};

function courseplay:onKeyEvent(unicode, sym, modifier, isDown) 
	--print(string.format("%s: unicode(%s), sym(%s), modifier(%s), isDown(%s)",tostring(Input.keyIdToIdName[sym]),tostring(unicode),tostring(sym),tostring(modifier),tostring(isDown)))
	for name,action in pairs (courseplay.inputActions) do
		if sym == action.bindingSym then
			--print("set "..tostring(name)..' to '..tostring(isDown))
			action.isPressed = isDown
			action.hasEvent = isDown
		end
	end	
end;

--- appendedFunction onActionBindingsChanged for InputDisplayManager.onActionBindingsChanged
-- Used to update hud if keybindings have been changed when ingame.
function courseplay:onActionBindingsChanged(...)
	if g_currentMission and g_currentMission.enterables then
		--print("onActionBindingsChanged");

		courseplay.inputBindings.updateInputButtonData();

		for _, vehicle in pairs(g_currentMission.enterables) do
			if vehicle.cp and vehicle.cp.hud then
				courseplay.hud:setReloadPageOrder(vehicle, courseplay.hud.PAGE_GENERAL_SETTINGS, true);
			end
		end
	end
end
InputDisplayManager.onActionBindingsChanged = Utils.appendedFunction(InputDisplayManager.onActionBindingsChanged, courseplay.onActionBindingsChanged);

function courseplay.inputBindings.updateInputButtonData()
	-- print('updateInputButtonData()')

	-- MOUSE
	for _,inputNameType in ipairs( { 'primary', 'secondary' } ) do
		local inputName = 'COURSEPLAY_MOUSEACTION_' .. inputNameType:upper();
		local action = g_inputBinding:getActionByName(inputName);
		local mouseButtonName = "MOUSE_BUTTON_NONE";
		local mouseInputDisplayText;
		for index, binding in ipairs(action.bindings) do
			if binding.isMouse and mouseButtonName == "MOUSE_BUTTON_NONE" then
				mouseButtonName = binding.axisNames[1];
				mouseInputDisplayText = MouseHelper.getInputDisplayText(binding.axisNames);
			end
		end
		-- print(('\t%s: inputName=%q'):format(inputNameType, inputName));

		local txt;
		if tonumber(mouseInputDisplayText) then
			txt = g_i18n:getText('COURSEPLAY_MOUSE_BUTTON_NR'):format(tonumber(mouseInputDisplayText));
		elseif type(mouseInputDisplayText) == "string" and g_i18n.texts[("COURSEPLAY_MOUSE_BUTTON_%s"):format(mouseInputDisplayText:upper())] then
			txt = g_i18n:getText(("COURSEPLAY_MOUSE_BUTTON_%s"):format(mouseInputDisplayText:upper()));
		else
			--- Should never happen but could happen if no mouse button was set.
			txt = g_i18n:getText('UNKNOWN');
		end

		courseplay.inputBindings.mouse[inputNameType .. 'TextI18n'] = txt;
		courseplay.inputBindings.mouse[inputNameType .. 'ButtonId'] = Input[mouseButtonName];
		-- print(('\t\t%sTextI18n=%q, mouseButtonId=%d'):format(inputNameType, txt, mouseButtonId));

		--[[ TODO: Rewrite input key bindings to use Giants default registerActionEvent
		More info can be found here:
                https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=70&class=7302#onRegisterActionEvents120704
                https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=1&class=7052#registerActionEvent118548

		Code below is from Jos.
		local _, eventId = self.inputManager:registerActionEvent(InputAction.SEASONS_SHOW_MENU, self, self.onToggleMenu, false, true, false, true)
    	self.inputManager:setActionEventTextVisibility(eventId, true)
		setActionEventTextPriority(eventId, priority)
		setActionEventActive(eventId, isActive)
		]]

		--- Do not activate below code: It will activate variables that dont exist anymore. Read the todo above
		--if inputNameType == 'secondary' then
		--	local fileName = courseplay.inputBindings.mouse.mouseButtonOverlays[mouseButtonName] or 'mouseRMB.png';
		--	 --print(('\t\tmouseButtonIdName=%q, fileName=%q'):format(tostring(mouseButtonIdName), tostring(fileName)));
		--	if courseplay.inputBindings.mouse.overlaySecondary then
		--		courseplay.inputBindings.mouse.overlaySecondary:delete();
		--	end;
		--	courseplay.inputBindings.mouse.overlaySecondary = Overlay:new(courseplay.path .. 'img/mouseIcons/' .. fileName, 0, 0, 0.0, 0.0);
		--end;
	end;


	courseplay.inputActions = {}
	--print("set up courseplay.inputActions:")
	for index, action in pairs (g_gui.inputManager.nameActions) do
		if string.match(index,'COURSEPLAY_') then
			--print(string.format("%s: (%s) %s",tostring(index),type(action),tostring(action)))
			local actionTable = {
					binding = '',
					bindingSym = '',
					hasBinding = false,
					isPressed = false,
					hasEvent = false
			}
			if action.primaryKeyboardInput then
				--print("  primaryKeyboardInput:"..tostring(action.primaryKeyboardInput))
				actionTable.hasBinding = true
				actionTable.binding = action.primaryKeyboardInput
				actionTable.bindingSym = Input[actionTable.binding]
				
			end
			courseplay.inputActions[index]= actionTable
		end
	end

	-- KEYBOARD
	local modifierTextI18n = g_inputDisplayManager:getKeyboardInputActionKey("COURSEPLAY_MODIFIER");
	local openCloseHudTextI18n = g_inputDisplayManager:getKeyboardInputActionKey("COURSEPLAY_HUD");

	courseplay.inputBindings.keyboard.openCloseHudTextI18n = ('%s + %s'):format(modifierTextI18n, openCloseHudTextI18n);
	-- print(('\topenCloseHudTextI18n=%q'):format(courseplay.inputBindings.keyboard.openCloseHudTextI18n));
end;
