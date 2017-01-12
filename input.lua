function courseplay:mouseEvent(posX, posY, isDown, isUp, mouseButton)
	--RIGHT CLICK
	if isUp and mouseButton == courseplay.inputBindings.mouse.secondaryButtonId and self.isEntered then
		if self.cp.hud.show then
			courseplay:setMouseCursor(self, not self.cp.mouseCursorActive);
		elseif not self.cp.hud.show and self.cp.hud.openWithMouse then
			courseplay:openCloseHud(self, true)
		end;
	end;

	local hudGfx = courseplay.hud.visibleArea;
	local mouseIsInHudArea = self.cp.mouseCursorActive and courseplay:mouseIsInArea(posX, posY, hudGfx.x1, hudGfx.x2, hudGfx.y1, self.cp.suc.active and courseplay.hud.suc.visibleArea.y2 or hudGfx.y2);

	-- if not mouseIsInHudArea then return; end;

	--LEFT CLICK
	if (isDown or isUp) and mouseButton == courseplay.inputBindings.mouse.primaryButtonId and self.cp.mouseCursorActive and self.cp.hud.show and self.isEntered and mouseIsInHudArea then
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
			if not buttonToHandle.isDisabled and buttonToHandle.hoverText and buttonToHandle.functionToCall ~= nil then
				self.cp.hud.content.pages[buttonToHandle.page][buttonToHandle.row][1].isClicked = isDown;
			end;
			if isUp then
				buttonToHandle:handleMouseClick();
			end;
			return;
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

				if button.hoverText and not button.isDisabled then
					self.cp.hud.content.pages[button.page][button.row][1].isHovered = button.isHovered;
				end;
			end;
		end;

		if self.cp.hud.currentPage == 2 then
			for _,button in pairs(self.cp.buttons[-2]) do
				button:setClicked(false);
				if button.show and not button.isHidden then
					button:setHovered(button:getHasMouse(posX, posY));

					if button.hoverText then
						self.cp.hud.content.pages[2][button.row][1].isHovered = button.isHovered;
					end;
				end;
			end;
		end;
	end;


	-- ##################################################
	-- 2D COURSE WINDOW: DRAG + DROP MOVE
	if self.cp.course2dDrawData and (self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_2DONLY or self.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_BOTH) then
		local plot = CpManager.course2dPlotField;
		if isDown and mouseButton == courseplay.inputBindings.mouse.primaryButtonId and self.cp.mouseCursorActive and self.isEntered and courseplay:mouseIsInArea(posX, posY, plot.x, plot.x + plot.width, plot.y, plot.y + plot.height) then
			CpManager.course2dDragDropMouseDown = { posX, posY };
			if self.cp.course2dPdaMapOverlay then
				self.cp.course2dPdaMapOverlay.origPos = { self.cp.course2dPdaMapOverlay.x, self.cp.course2dPdaMapOverlay.y };
			else
				self.cp.course2dBackground.origPos = { self.cp.course2dBackground.x, self.cp.course2dBackground.y };
			end;
		elseif isUp and CpManager.course2dDragDropMouseDown ~= nil then
			courseplay.utils:move2dCoursePlotField(self, posX, posY);
		elseif not isUp and not isDown and CpManager.course2dDragDropMouseDown ~= nil then
			courseplay.utils:update2dCourseBackgroundPos(self, posX, posY);
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
		CpManager:setGlobalInfoText(self, value, page)
		courseplay:debug("					setting infoText: "..value..", force remove: "..tostring(page),5)
		return
	elseif Utils.startsWith(func,"self") or Utils.startsWith(func,"courseplay") then
		courseplay:debug("					setting value",5)
		courseplay:setVarValueFromString(self, func, value)
		--courseplay:debug("					"..tostring(func)..": "..tostring(value),5)
		return
	end
	if self.isEntered then
		playSample(courseplay.hud.clickSound, 1, 1, 0);
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
					end;

				else -- driving
					if line == 1 then
						courseplay:stop(self);
					elseif line == 2 and self.cp.HUD1wait then
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
					end;
				end; -- end driving
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
			if line == 5 then 
				courseplay:getPipesRotation(self)
			end
			
		elseif page == 3 then
			if line == 2 then
				self.cp.turnOnField = not self.cp.turnOnField;
			end;
		
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

function courseplay:keyEvent(unicode, sym, modifier, isDown) end;


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

function courseplay.inputBindings.updateInputButtonData()
	-- print('updateInputButtonData()')

	-- MOUSE
	for _,type in ipairs( { 'primary', 'secondary' } ) do
		local inputName = 'COURSEPLAY_MOUSEACTION_' .. type:upper();
		local action = InputBinding.actions[ InputBinding[inputName] ];
		local mouseButtonId = action.mouseButtons[1]; -- can there be more than 1 mouseButton for 1 action?

		-- print(('\t%s: inputName=%q'):format(type, inputName));

		local txt = ('%s %s'):format(g_i18n:getText('ui_mouse'), MouseHelper.getButtonNames(action.mouseButtons)); -- TODO (Jakob): getButtonNames returns English, not i18n text
		courseplay.inputBindings.mouse[type .. 'TextI18n'] = txt;
		courseplay.inputBindings.mouse[type .. 'ButtonId'] = mouseButtonId;
		-- print(('\t\t%sTextI18n=%q, mouseButtonId=%d'):format(type, txt, mouseButtonId));

		if type == 'secondary' then
			local mouseButtonIdName = Input.mouseButtonIdToIdName[mouseButtonId];
			local fileName = courseplay.inputBindings.mouse.mouseButtonOverlays[mouseButtonIdName] or 'mouseRMB.png';
			 --print(('\t\tmouseButtonIdName=%q, fileName=%q'):format(tostring(mouseButtonIdName), tostring(fileName)));
			if courseplay.inputBindings.mouse.overlaySecondary then
				courseplay.inputBindings.mouse.overlaySecondary:delete();
			end;
			courseplay.inputBindings.mouse.overlaySecondary = Overlay:new('cpMouseIPB', courseplay.path .. 'img/mouseIcons/' .. fileName, 0, 0, 0.0, 0.0);
		end;
	end;

	-- KEYBOARD
	-- open/close hud (combined with modifier): get i18n text
	local modifierAction = InputBinding.actions[InputBinding.COURSEPLAY_MODIFIER];
	local modifierTextI18n = KeyboardHelper.getKeyNames(modifierAction.keys1);

	local openCloseHudAction = InputBinding.actions[InputBinding.COURSEPLAY_HUD];
	local openCloseHudTextI18n = KeyboardHelper.getKeyNames(openCloseHudAction.keys1);

	courseplay.inputBindings.keyboard.openCloseHudTextI18n = ('%s + %s'):format(modifierTextI18n, openCloseHudTextI18n);
	-- print(('\topenCloseHudTextI18n=%q'):format(courseplay.inputBindings.keyboard.openCloseHudTextI18n));
end;
InputBinding.storeBindings = Utils.appendedFunction(InputBinding.storeBindings, courseplay.inputBindings.updateInputButtonData);
