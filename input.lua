function courseplay:onMouseEvent(posX, posY, isDown, isUp, mouseButton)
	--RIGHT CLICK
	-- Input binding debug
	local vehicle = g_currentMission.controlledVehicle			
	
	if not courseplay.isEnabled(vehicle) then
		return 
	end
 	courseEditor:updateMouseState(vehicle, posX, posY, isDown, isUp, mouseButton)
	
	--print(string.format('courseplay:mouseEvent(posX(%s), posY(%s), isDown(%s), isUp(%s), mouseButton(%s))', tostring(posX), tostring(posY), tostring(isDown), tostring(isUp), tostring(mouseButton) ))
	--print(string.format("if isUp(%s) and mouseButton(%s) == courseplay.inputBindings.mouse.secondaryButtonId(%s) and Enterable.getIsEntered(self)(%s) then"
	--,tostring(isUp),tostring(mouseButton),tostring(courseplay.inputBindings.mouse.secondaryButtonId),tostring(Enterable.getIsEntered(self))))
	if isUp and mouseButton == courseplay.inputBindings.mouse.secondaryButtonId and vehicle:getIsEntered() then
		if vehicle.cp.hud.show then
			courseplay:setMouseCursor(vehicle, not vehicle.cp.mouseCursorActive);
		elseif not vehicle.cp.hud.show and courseplay.globalSettings.enableOpenHudWithMouseGlobal:is(true) and vehicle.cp.settings.enableOpenHudWithMouseVehicle:is(true) then
			courseplay:openCloseHud(vehicle, true)
		end;
	end;

	local hudGfx = courseplay.hud.visibleArea;
	local mouseIsInHudArea = vehicle.cp.mouseCursorActive and courseplay:mouseIsInArea(posX, posY, hudGfx.x1, hudGfx.x2, hudGfx.y1,  hudGfx.y2);
	-- if not mouseIsInHudArea then return; end;

	-- should we switch vehicles? Option must be active, must be in a vehicle, must not be in CP HUD Area (for AD, not sure how to add) and must have any mouse course active.
	if courseplay.globalSettings.clickToSwitch:is(true) and vehicle:getIsEntered() and not mouseIsInHudArea and
		mouseButton == courseplay.inputBindings.mouse.primaryButtonId and (g_inputBinding:getShowMouseCursor() == true) then
			clickToSwitch:updateMouseState(vehicle, posX, posY, isDown, isUp, mouseButton)
	end

	--LEFT CLICK
	if (isDown or isUp) and mouseButton == courseplay.inputBindings.mouse.primaryButtonId and vehicle.cp.mouseCursorActive and vehicle.cp.hud.show and vehicle:getIsEntered() and mouseIsInHudArea then
		local buttonToHandle;

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
	if vehicle.cp.course2dDrawData and vehicle.cp.settings.courseDrawMode:isCourseMapVisible() then
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
	courseplay:debug("setCourseplayFunc: function: " .. func .. " value: " .. tostring(value) .. " noEventSend: " .. tostring(noEventSend) .. " page: " .. tostring(page), courseplay.DBG_MULTIPLAYER)
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
	courseplay:debug("executeFunction: function: " .. func .. " value: " .. tostring(value) .. " page: " .. tostring(page), courseplay.DBG_MULTIPLAYER)
	--legancy code
	if StringUtil.startsWith(func,"self") or StringUtil.startsWith(func,"courseplay") then
		courseplay:debug("					setting value",courseplay.DBG_MULTIPLAYER)
		courseplay:setVarValueFromString(self, func, value)
		--courseplay:debug("					"..tostring(func)..": "..tostring(value),courseplay.DBG_MULTIPLAYER)
		return
	end
	if self:getIsEntered() then
		--The old sound playSample(courseplay.hud.clickSound, 1, 1, 0, 0, 0);
		-- The new gui click sound
		g_currentMission.hud.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
	end
	courseplay:debug(('%s: calling function "%s(%s)"'):format(nameNum(self), tostring(func), tostring(value)), courseplay.DBG_HUD);
	if func ~= "rowButton" then
		--@source: http://stackoverflow.com/questions/1791234/lua-call-function-from-a-string-with-function-name
		assert(loadstring('courseplay:' .. func .. '(...)'))(self, value);
		courseplay.hud:setReloadPageOrder(self, self.cp.hud.currentPage, true);
	else
		courseplay:debug(('%s: calling rowButton function !!!'):format(nameNum(self)), courseplay.DBG_MULTIPLAYER);
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

	end;
end;
