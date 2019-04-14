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
				if button.show and button:getHasMouse(posX, posY) and not button.isMouseWheelArea then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			for _,button in pairs(vehicle.cp.buttons[vehicle.cp.hud.currentPage]) do
				if button.canBeClicked and button.show and not button.isDisabled and button:getHasMouse(posX, posY) and not button.isMouseWheelArea then
					buttonToHandle = button;
					break;
				end;
			end;
		end;

		if buttonToHandle == nil then
			if vehicle.cp.hud.currentPage == 2 then
				for _,button in pairs(vehicle.cp.buttons[-2]) do
					if button.show and button:getHasMouse(posX, posY) and not button.isMouseWheelArea then
						buttonToHandle = button;
						break;
					end;
				end;
			end;
		end;

		if buttonToHandle then
			buttonToHandle:setClicked(isDown);
			--[[if not buttonToHandle.isDisabled and buttonToHandle.hoverText and buttonToHandle.functionToCall ~= nil then
				vehicle.cp.hud.content.pages[buttonToHandle.page][buttonToHandle.row][1].isClicked = isDown;
			end;]]
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
		vehicle.cp.hud.mouseWheel.render = false;
		
		for _,button in pairs(vehicle.cp.buttons.global) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setClicked(false);
				button:setHovered(button:getHasMouse(posX, posY));
				if button.isHovered then
					button:handleHoverAction(vehicle, posX, posY)
				end;
			end;
		end;
		
		for _,button in pairs(vehicle.cp.buttons[vehicle.cp.hud.currentPage]) do
			button:setClicked(false);
			if button.show and not button.isHidden then
				button:setHovered(button:getHasMouse(posX, posY));
				if button.isHovered then
					button:handleHoverAction(vehicle, posX, posY)
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
		courseplay.hud:setReloadPageOrder(self, self.cp.hud.currentPage, true);
	--[[else
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
						--courseplay:start(self);
					elseif line == 3 and self.cp.mode ~= 9 then
						courseplay:changeStartAtPoint(self);
					elseif line == 4 then
						courseplay:getPipesRotation(self);
					elseif line == 5 then
						courseplay:toggleFertilizeOption(self);
					end;

				else -- driving
					if line == 1 then
						--courseplay:stop(self);
					elseif line == 2 and (self.cp.HUD1wait or (self.cp.driver and self.cp.driver:isWaiting())) then
						if self.cp.stopAtEnd and (self.cp.waypointIndex == self.cp.numWaypoints or self.cp.currentTipTrigger ~= nil) then
							courseplay:setStopAtEnd(self, false);
						else
							courseplay:cancelWait(self);
						end;
					elseif line == 3 and not self.cp.driveUnloadNow then
						courseplay:setDriveUnloadNow(self, true);
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
		end; --END is page 0 or 1 or 3 or 10]]
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
	--[[for name,action in pairs (courseplay.inputActions) do
		if sym == action.bindingSym then
			--print("set "..tostring(name)..' to '..tostring(isDown))
			action.isPressed = isDown
			action.hasEvent = isDown
		end
	end]]	
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


	--[[
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
	end]]

	-- KEYBOARD
	local modifierTextI18n = g_inputDisplayManager:getKeyboardInputActionKey("COURSEPLAY_MODIFIER");
	local openCloseHudTextI18n = g_inputDisplayManager:getKeyboardInputActionKey("COURSEPLAY_HUD");

	courseplay.inputBindings.keyboard.openCloseHudTextI18n = ('%s + %s'):format(modifierTextI18n, openCloseHudTextI18n);
	-- print(('\topenCloseHudTextI18n=%q'):format(courseplay.inputBindings.keyboard.openCloseHudTextI18n));
end;


function courseplay.inputActionCallback(vehicle, actionName, keyStatus)
	courseplay.inputModifierIsPressed = g_gui.inputManager.nameActions.COURSEPLAY_MODIFIER.activeBindings[1].isPressed
	--print(string.format("inputActionCallback:(vehicle(%s), actionName(%s), keyStatus(%s))",tostring(vehicle:getName()),tostring(actionName),tostring(keyStatus)))
	if courseplay.inputModifierIsPressed then
		
		if keyStatus == 1 and vehicle:getIsActive() and vehicle:getIsEntered() then
			if actionName == 'COURSEPLAY_START_STOP' then
				if vehicle.cp.canDrive then
					if vehicle.cp.isDriving then
						vehicle:setCourseplayFunc('stop', nil, false, 1);
					else
						vehicle:setCourseplayFunc('start', nil, false, 1);
					end;
				else
					if not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and vehicle.cp.numWaypoints == 0 then
						vehicle:setCourseplayFunc('start_record', nil, false, 1);
					elseif vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and not vehicle.cp.isRecordingTurnManeuver then
						vehicle:setCourseplayFunc('stop_record', nil, false, 1);
					end;
				end;
			elseif actionName == 'COURSEPLAY_CANCELWAIT' and
				(vehicle.cp.HUD1wait and vehicle.cp.canDrive and vehicle.cp.isDriving) or (vehicle.cp.driver and vehicle.cp.driver:isWaiting()) then
				vehicle:setCourseplayFunc('cancelWait', true, false, 1);
			elseif actionName == 'COURSEPLAY_DRIVENOW' and vehicle.cp.HUD1noWaitforFill and vehicle.cp.canDrive and vehicle.cp.isDriving then
				vehicle:setCourseplayFunc('setDriveUnloadNow', true, false, 1);
			elseif actionName == 'COURSEPLAY_STOP_AT_END' and vehicle.cp.canDrive and vehicle.cp.isDriving then
				vehicle:setCourseplayFunc('setStopAtEnd', not vehicle.cp.stopAtEnd, false, 1);
			elseif vehicle.cp.canSwitchMode and vehicle.cp.nextMode and actionName == 'COURSEPLAY_NEXTMODE' then
				vehicle:setCourseplayFunc('setCpMode', vehicle.cp.nextMode, false, 1);
			elseif vehicle.cp.canSwitchMode and vehicle.cp.prevMode and actionName == 'COURSEPLAY_PREVMODE' then
				vehicle:setCourseplayFunc('setCpMode', vehicle.cp.prevMode, false, 1);
			elseif actionName == 'COURSEPLAY_SHOVEL_MOVE_TO_LOADING_POSITION' then
					vehicle:setCpVar('shovelPositionFromKey', true, courseplay.isClient);
					courseplay:moveShovelToPosition(vehicle, 2);
			elseif actionName == 'COURSEPLAY_SHOVEL_MOVE_TO_TRANSPORT_POSITION' then
					vehicle:setCpVar('shovelPositionFromKey', true, courseplay.isClient);
					courseplay:moveShovelToPosition(vehicle, 3);
			elseif actionName == 'COURSEPLAY_SHOVEL_MOVE_TO_PRE_UNLOADING_POSITION' then
					vehicle:setCpVar('shovelPositionFromKey', true, courseplay.isClient);
					courseplay:moveShovelToPosition(vehicle, 4);
			elseif actionName == 'COURSEPLAY_SHOVEL_MOVE_TO_UNLOADING_POSITION' then
					vehicle:setCpVar('shovelPositionFromKey', true, courseplay.isClient);
					courseplay:moveShovelToPosition(vehicle, 5);
			end;

			if not vehicle.cp.openHudWithMouse and actionName == 'COURSEPLAY_HUD' then
				vehicle:setCourseplayFunc('openCloseHud', not vehicle.cp.hud.show, true);
			end;
		end; -- END vehicle:getIsActive() and Enterable.getIsEntered(vehicle) and modifierPressed
	end
		

end
