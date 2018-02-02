-- #################################################################
-- courseplay.button class

courseplay.button = {};
cpButton_mt = Class(courseplay.button);

function courseplay.button:new(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip)
	local self = setmetatable({}, cpButton_mt);

	if img then
		if type(img) == 'table' then
			if img[1] == 'iconSprite.png' then
				self.overlay = Overlay:new(img, courseplay.hud.iconSpritePath, x, y, width, height);
				self.spriteSection = img[2];
			end;
		else
			self.overlay = Overlay:new(img, Utils.getFilename('img/' .. img, courseplay.path), x, y, width, height);
		end;
	end;

	if hoverText == nil then
		hoverText = false;
	end;
	if isMouseWheelArea == nil then
		isMouseWheelArea = false;
	end;
	if isToggleButton == nil then
		isToggleButton = false;
	end;

	if not vehicle.isCourseplayManager then
		self.vehicle = vehicle;
	end;
	self.page = hudPage; 
	self.functionToCall = functionToCall; 
	self:setParameter(parameter);
	self.width = width;
	self.height = height;
	self.x_init = x;
	self.x = x;
	self.x2 = (x + width);
	self.y_init = y;
	self.y = y;
	self.y2 = (y + height);
	self.row = hudRow;
	self.hoverText = hoverText;
	self:setColor('white')
	self:setToolTip(toolTip);
	self.isMouseWheelArea = isMouseWheelArea and functionToCall ~= nil;
	self.isToggleButton = isToggleButton;
	self:setCanBeClicked(not isMouseWheelArea and functionToCall ~= nil);
	self:setShow(true);
	self:setClicked(false);
	self:setActive(false);
	self:setDisabled(false);
	self:setHovered(false);
	if modifiedParameter then 
		self.modifiedParameter = modifiedParameter;
	end
	if isMouseWheelArea then
		self.canScrollUp   = true;
		self.canScrollDown = true;
	end;

	if self.spriteSection then
		self:setSpriteSectionUVs(self.spriteSection);
	else
		self:setSpecialButtonUVs();
	end;

	if vehicle.isCourseplayManager then
		table.insert(vehicle[hudPage].buttons, self);
	else
		table.insert(vehicle.cp.buttons[hudPage], self);
	end;
	return self;
end;

function courseplay.button:setSpriteSectionUVs(spriteSection)
	if not spriteSection or courseplay.hud.buttonUVsPx[spriteSection] == nil then return; end;

	self.spriteSection = spriteSection;
	courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.buttonUVsPx[spriteSection], courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
end;

function courseplay.button:setSpecialButtonUVs()
	if not self.overlay then return; end;

	local fn = self.functionToCall;
	local prm = self.parameter;
	local txtSizeX, txtSizeY = courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y;

	if fn == 'setCpMode' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.modeButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'setHudPage' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'generateCourse' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[courseplay.hud.PAGE_COURSE_GENERATION], txtSizeX, txtSizeY);

	elseif fn == 'toggleDebugChannel' then
		self:setSpriteSectionUVs('recordingStop');

	-- CpManager buttons
	elseif fn == 'goToVehicle' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[courseplay.hud.PAGE_DRIVING_SETTINGS], txtSizeX, txtSizeY);
	end;
end;

function courseplay.button:render()
	-- self = courseplay.button

	local vehicle, pg, fn, prm = self.vehicle, self.page, self.functionToCall, self.parameter;
	local hoveredButton = false;

	--mouseWheelAreas conditionals
	if self.isMouseWheelArea then
		local canScrollUp, canScrollDown;
		if pg == courseplay.hud.PAGE_CP_CONTROL then
			if fn == "setCustomFieldEdgePathNumber" then
				canScrollUp   = vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				canScrollDown = vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
			elseif fn == "changeSiloFillType" then
				canScrollUp   = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT and #vehicle.cp.easyFillTypeList > 0;
				canScrollDown = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT and #vehicle.cp.easyFillTypeList > 0;
			elseif fn == 'changeRunNumber' then
 				local canChange = true
				if ((vehicle.cp.fillTrigger or vehicle.cp.isInFilltrigger) or vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT) and not vehicle.cp.runCounterBool then
					canChange = vehicle.cp.runNumber - vehicle.cp.runCounter > 1
				end
 				canScrollUp = vehicle.cp.runNumber < 11 and (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and vehicle.cp.canDrive and (not vehicle.cp.runReset or vehicle.cp.runCounter == 0) and #vehicle.cp.easyFillTypeList > 0;
 				canScrollDown = vehicle.cp.runNumber > vehicle.cp.runCounter and vehicle.cp.runNumber > 1 and (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT)  and vehicle.cp.canDrive and canChange and #vehicle.cp.easyFillTypeList > 0;
			end;

		elseif pg == courseplay.hud.PAGE_MANAGE_COURSES then
			if fn == "shiftHudCourses" then
				canScrollUp   = vehicle.cp.hud.courseListPrev == true;
				canScrollDown = vehicle.cp.hud.courseListNext == true;
			end;

		elseif pg == courseplay.hud.PAGE_COMBI_MODE then
			if fn == 'changeCombineOffset' or fn == 'changeTipperOffset' then
				canScrollUp = vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_OVERLOADER;
				canScrollDown = canScrollUp;
			elseif fn == "changeTurnDiameter" then
				canScrollUp   = true;
				canScrollDown = vehicle.cp.turnDiameter > 0;
			elseif fn == "changeFollowAtFillLevel" then
				canScrollUp   = vehicle.cp.followAtFillLevel < 100;
				canScrollDown = vehicle.cp.followAtFillLevel > 0;
			elseif fn == "changeDriveOnAtFillLevel" then
				canScrollUp   = vehicle.cp.driveOnAtFillLevel < 100;
				canScrollDown = vehicle.cp.driveOnAtFillLevel > 0;
			elseif fn == 'changeRefillUntilPct' then
				canScrollUp   = (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and vehicle.cp.refillUntilPct < 100;
				canScrollDown = (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and vehicle.cp.refillUntilPct > 1;
			end;

		elseif pg == courseplay.hud.PAGE_MANAGE_COMBINES then
			if fn == 'setSearchCombineOnField' then
				canScrollUp   = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField > 0;
				canScrollDown = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
			end;

		elseif pg == courseplay.hud.PAGE_SPEEDS then
			if fn == 'changeTurnSpeed' then
				canScrollUp   = vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
			elseif fn == 'changeFieldSpeed' then
				canScrollUp   = vehicle.cp.speeds.field < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
			elseif fn == 'changeMaxSpeed' then
				canScrollUp   = vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
			elseif fn == 'changeReverseSpeed' then
				canScrollUp   = vehicle.cp.speeds.reverse < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.reverse > vehicle.cp.speeds.minReverse;
			end;

		elseif pg == courseplay.hud.PAGE_GENERAL_SETTINGS then
			if fn == "changeWaitTime" then
				canScrollUp   = courseplay:getCanHaveWaitTime(vehicle);
				canScrollDown = canScrollUp and vehicle.cp.waitTime > 0;
			elseif fn == 'changeDebugChannelSection' then
				canScrollUp   = courseplay.debugChannelSection > 1;
				canScrollDown = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
			end;

		elseif pg == courseplay.hud.PAGE_DRIVING_SETTINGS then
			if fn == "changeLaneOffset" then
				canScrollUp   = vehicle.cp.multiTools == 1 and (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK)
				canScrollDown = canScrollUp;
			elseif fn == 'changeLaneNumber' then
				canScrollUp = math.floor(vehicle.cp.multiTools/2) > vehicle.cp.laneNumber
				canScrollDown = math.floor(vehicle.cp.multiTools/2)*-1 < vehicle.cp.laneNumber
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				canScrollUp   = vehicle.cp.mode == courseplay.MODE_OVERLOADER
							 or vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE
							 or vehicle.cp.mode == courseplay.MODE_FIELDWORK
							 or vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING
							 or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT;
				canScrollDown = canScrollUp;
			elseif fn == "changeLoadUnloadOffsetX" or fn == "changeLoadUnloadOffsetZ" then
				canScrollUp   = vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT
							 or vehicle.cp.mode == courseplay.MODE_OVERLOADER
							 or vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE
							 or vehicle.cp.mode == courseplay.MODE_FIELDWORK
							 or vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING
							 or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT;
				canScrollDown = canScrollUp;
			end;

		elseif pg == courseplay.hud.PAGE_COURSE_GENERATION then
			if fn == "setFieldEdgePath" then
				canScrollUp   = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
				canScrollDown = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "changeWorkWidth" then
				canScrollUp   = true;
				canScrollDown = vehicle.cp.workWidth > 0.1;
			elseif fn == 'changeMultiTools' then
				canScrollUp = vehicle.cp.multiTools < 8
				canScrollDown = vehicle.cp.multiTools > 1
			elseif fn == 'changeRowAngle' then
				canScrollUp = true
				canScrollDown = true
			end;
			
		elseif pg == courseplay.hud.PAGE_SHOVEL_POSITIONS then
			if fn == "changeWorkWidth" then
				canScrollUp   = true;
				canScrollDown = vehicle.cp.workWidth > 0.1;
			end
			
		elseif pg == courseplay.hud.PAGE_BUNKERSILO_SETTINGS then
			if fn == "changeMode10Radius" then
				canScrollUp   = true;
				canScrollDown = vehicle.cp.mode10.searchRadius > 1;				
			elseif fn == "changeShieldHeight" then
				canScrollUp   = not vehicle.cp.mode10.automaticHeigth and vehicle.cp.mode10.shieldHeight < 1.5
				canScrollDown = not vehicle.cp.mode10.automaticHeigth and vehicle.cp.mode10.shieldHeight > 0
			elseif fn == "changeBunkerSpeed" then
				local uMayUseIt = (vehicle.cp.mode10.leveling and not vehicle.cp.mode10.automaticSpeed) or not vehicle.cp.mode10.leveling
				canScrollUp   = uMayUseIt and vehicle.cp.speeds.bunkerSilo < 20;
				canScrollDown = uMayUseIt and vehicle.cp.speeds.bunkerSilo > 3;
			elseif fn == "changeWorkWidth" then
				canScrollUp   = true;
				canScrollDown = vehicle.cp.workWidth > 0.1;
			end
		end;

		if canScrollUp ~= nil then
			self:setCanScrollUp(canScrollUp);
		end;
		if canScrollDown ~= nil then
			self:setCanScrollDown(canScrollDown);
		end;

	elseif self.overlay ~= nil then
		if pg ~= -courseplay.hud.PAGE_MANAGE_COURSES then -- NOTE: course buttons' (page -2) visibility are handled in buttonsActiveEnabled(), section 'page2'
			local show = true;
			-- CONDITIONAL DISPLAY
			-- Global
			if pg == "global" then
				if fn == "showSaveCourseForm" and prm == "course" then
					show = vehicle.cp.canDrive and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and vehicle.Waypoints ~= nil and vehicle.cp.numWaypoints > 0;
				end;

				-- Page 1
			elseif pg == courseplay.hud.PAGE_CP_CONTROL then
				if fn == "setCpMode" then
					show = vehicle.cp.canSwitchMode and not vehicle.cp.distanceCheck;
				elseif fn == "clearCustomFieldEdge" or fn == "toggleCustomFieldEdgePathShow" then
					show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated;
				elseif fn == "setCustomFieldEdgePathNumber" then
					if prm < 0 then
						show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
					elseif prm > 0 then
						show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
					end;
				elseif fn == 'toggleFindFirstWaypoint' then
					show = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused;
				elseif fn == 'stop_record' or fn == 'setRecordingPause' or fn == 'delete_waypoint' or fn == 'set_waitpoint' or   fn == 'set_unloadPoint' or  fn == 'set_crossing' or fn == 'setRecordingTurnManeuver' or fn == 'change_DriveDirection' or fn == 'addSplitRecordingPoints' then
					show = vehicle.cp.isRecording or vehicle.cp.recordingIsPaused;
				elseif fn == 'clearCurrentLoadedCourse' then
					show = vehicle.cp.canDrive and not vehicle.cp.isDriving;
				elseif fn == 'changeSiloFillType' then
					show = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT and #vehicle.cp.easyFillTypeList > 0;
				elseif fn == 'movePipeToPosition' then
					show = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and vehicle.cp.hasAugerWagon and not vehicle.cp.hasSugarCaneAugerWagon and (vehicle.cp.mode == courseplay.MODE_OVERLOADER or vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT);
				elseif fn == 'changeRunNumber' then
					if prm < 0 then
						local canChange = true
						if ((vehicle.cp.fillTrigger or vehicle.cp.isInFilltrigger) or vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT) and not vehicle.cp.runCounterBool then
							canChange = vehicle.cp.runNumber - vehicle.cp.runCounter > 1
						end
						show = vehicle.cp.runNumber > vehicle.cp.runCounter and vehicle.cp.runNumber > 1 and (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and vehicle.cp.canDrive and canChange and #vehicle.cp.easyFillTypeList > 0;
					elseif prm > 0 then
						show = vehicle.cp.runNumber < 11 and (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and vehicle.cp.canDrive and (not vehicle.cp.runReset or vehicle.cp.runCounter == 0) and #vehicle.cp.easyFillTypeList > 0;
					end;
				end;

				-- Page 2
			elseif pg == courseplay.hud.PAGE_MANAGE_COURSES then
				if fn == "reloadCoursesFromXML" then
					show = g_server ~= nil and not vehicle.cp.canDrive and not g_currentMission.missionDynamicInfo.isMultiplayer;
				elseif fn == "showSaveCourseForm" and prm == "filter" then
					show = not vehicle.cp.hud.choose_parent;
				elseif fn == 'clearCurrentLoadedCourse' then
					show = vehicle.cp.canDrive and not vehicle.cp.isDriving;
				elseif fn == "shiftHudCourses" then
					if prm < 0 then
						show = vehicle.cp.hud.courseListPrev;
					elseif prm > 0 then
						show = vehicle.cp.hud.courseListNext;
					end;
				end;

				-- Page 3
			elseif pg == courseplay.hud.PAGE_COMBI_MODE then
				if fn == 'changeCombineOffset' or fn == 'changeTipperOffset' then
					show = vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_OVERLOADER;
				elseif fn == "changeTurnDiameter" and prm < 0 then
					show = vehicle.cp.turnDiameter > 0;
				elseif fn == "changeFollowAtFillLevel" then
					if prm < 0 then
						show = vehicle.cp.followAtFillLevel > 0;
					elseif prm > 0 then
						show = vehicle.cp.followAtFillLevel < 100;
					end;
				elseif fn == "changeDriveOnAtFillLevel" then
					if prm < 0 then
						show = vehicle.cp.driveOnAtFillLevel > 0;
					elseif prm > 0 then
						show = vehicle.cp.driveOnAtFillLevel < 100;
					end;
				elseif fn == 'changeRefillUntilPct' then
					if prm < 0 then
						show = (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and vehicle.cp.refillUntilPct > 1;
					elseif prm > 0 then
						show = (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and vehicle.cp.refillUntilPct < 100;
					end;
				elseif fn == 'changeLastValidTipDistance' then
					show = vehicle.cp.lastValidTipDistance ~= nil
				end;

				-- Page 4
			elseif pg == courseplay.hud.PAGE_MANAGE_COMBINES then
				if fn == 'selectAssignedCombine' then
					show = not vehicle.cp.searchCombineAutomatically;
					if show and prm < 0 then
						show = vehicle.cp.selectedCombineNumber > 0;
					end;
				elseif fn == 'setSearchCombineOnField' then
					show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically;
					if show then
						if prm < 0 then
							show = vehicle.cp.searchCombineOnField > 0;
						else
							show = vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
						end;
					end;
				elseif fn == 'removeActiveCombineFromTractor' then
					show = vehicle.cp.activeCombine ~= nil;
				end;

				-- Page 5
			elseif pg == courseplay.hud.PAGE_SPEEDS then
				if fn == 'changeTurnSpeed' then
					if prm < 0 then
						show = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
					elseif prm > 0 then
						show = vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
					end;
				elseif fn == 'changeFieldSpeed' then
					if prm < 0 then
						show = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
					elseif prm > 0 then
						show = vehicle.cp.speeds.field < vehicle.cp.speeds.max;
					end;
				elseif fn == 'changeMaxSpeed' then
					if prm < 0 then
						show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
					elseif prm > 0 then
						show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
					end;
				elseif fn == 'changeReverseSpeed' then
					if prm < 0 then
						show = vehicle.cp.speeds.reverse > vehicle.cp.speeds.minReverse;
					elseif prm > 0 then
						show = vehicle.cp.speeds.reverse < vehicle.cp.speeds.max;
					end;
				elseif fn == 'changeDriveControlMode' then
					if prm < 0 then
						show = vehicle.cp.hasDriveControl and vehicle.cp.driveControl.hasFourWD and vehicle.cp.driveControl.mode > vehicle.cp.driveControl.OFF
					else
						show = vehicle.cp.hasDriveControl and vehicle.cp.driveControl.hasFourWD and vehicle.cp.driveControl.mode < vehicle.cp.driveControl.AWD_BOTH_DIFF
					end;
				end;

				-- Page 6
			elseif pg == courseplay.hud.PAGE_GENERAL_SETTINGS then
				if fn == 'toggleRealisticDriving' then
					show = vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_OVERLOADER;
				elseif fn == 'changeWarningLightsMode' then
					if prm < 0 then
						show = vehicle.cp.warningLightsMode > courseplay.WARNING_LIGHTS_NEVER;
					else
						show = vehicle.cp.warningLightsMode < courseplay.WARNING_LIGHTS_BEACON_ALWAYS;
					end;
				elseif fn == "changeWaitTime" then
					show = courseplay:getCanHaveWaitTime(vehicle);
					if show and prm < 0 then
						show = vehicle.cp.waitTime > 0;
					end;
				elseif fn == "toggleDebugChannel" then
					show = prm >= courseplay.debugChannelSectionStart and prm <= courseplay.debugChannelSectionEnd;
				elseif fn == "changeDebugChannelSection" then
					if prm < 0 then
						show = courseplay.debugChannelSection > 1;
					elseif prm > 0 then
						show = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
					end;
				end;

				-- Page 7
			elseif pg == courseplay.hud.PAGE_DRIVING_SETTINGS then
				if fn == "changeLaneOffset" then
					show = vehicle.cp.multiTools == 1 and (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK);
				elseif fn == 'changeLaneNumber' then
					if prm > 0 then
						show = math.floor(vehicle.cp.multiTools/2) > vehicle.cp.laneNumber
					elseif prm < 0 then
						show = math.floor(vehicle.cp.multiTools/2)*-1 < vehicle.cp.laneNumber
					end;
				elseif fn == "toggleSymmetricLaneChange" then
					show = (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK) and vehicle.cp.laneOffset ~= 0;
				elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
					show = vehicle.cp.mode == courseplay.MODE_OVERLOADER
					or vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE
					or vehicle.cp.mode == courseplay.MODE_FIELDWORK
					or vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING
					or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT;
				elseif fn == "changeLoadUnloadOffsetX" or fn == "changeLoadUnloadOffsetZ" then
					show = vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT
					or vehicle.cp.mode == courseplay.MODE_OVERLOADER
					or vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE
					or vehicle.cp.mode == courseplay.MODE_FIELDWORK
					or vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING
					or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT;
				elseif fn == "switchDriverCopy" and prm < 0 then
					show = vehicle.cp.selectedDriverNumber > 0;
				elseif fn == "copyCourse" then
					show = vehicle.cp.hasFoundCopyDriver;
				end;

				-- Page 8
			elseif pg == courseplay.hud.PAGE_COURSE_GENERATION then
				if fn == 'clearCurrentLoadedCourse' then
					show = vehicle.cp.canDrive and not vehicle.cp.isDriving;
				elseif fn == 'toggleSucHud' then
					show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
				elseif fn == "toggleSelectedFieldEdgePathShow" then
					show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
				elseif fn == "setFieldEdgePath" then
					show = courseplay.fields.numAvailableFields > 0;
					if show then
						if prm < 0 then
							show = vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
						elseif prm > 0 then
							show = vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
						end;
					end;
				elseif fn == "changeWorkWidth" and prm < 0 then
					show = vehicle.cp.workWidth > 0.1;
				elseif fn == "changeStartingDirection" then
					show = vehicle.cp.hasStartingCorner;
				elseif fn == 'toggleHeadlandDirection' or fn == 'toggleHeadlandOrder' then
					show = vehicle.cp.headland.numLanes > 0;
				elseif fn == 'changeHeadlandNumLanes' then
					if prm < 0 then
						show = vehicle.cp.headland.numLanes > 0;
					elseif prm > 0 then
						show = vehicle.cp.headland.numLanes < vehicle.cp.headland.maxNumLanes;
					end;
				-- NOTE: generateCourse button is handled in buttonsActiveEnabled(), section 'generateCourse'
				elseif fn == 'changeMultiTools' then
					if prm > 0 then 
						show = vehicle.cp.multiTools < 8
					elseif prm < 0 then
						show = vehicle.cp.multiTools > 1
					end;
				elseif fn == 'changeRowAngle' then
					-- This whole button show/not show thing should be refactored, this is not the right place for it
					-- and this three hundred line if statement is bad a joke...
					show = vehicle.cp.startingDirection == courseGenerator.ROW_DIRECTION_MANUAL
			    end;
			-- Page 10
			elseif pg == courseplay.hud.PAGE_BUNKERSILO_SETTINGS then
				if fn == 'changeShieldHeight' then
					show = (not vehicle.cp.mode10.automaticHeigth) and vehicle.cp.mode10.leveling			
					if show and prm < 0 then
						show = vehicle.cp.mode10.shieldHeight > 0;
					end				
				elseif fn == 'changeBunkerSpeed' then
					show = (not vehicle.cp.mode10.automaticSpeed or not vehicle.cp.mode10.leveling)
					if show then 
						if prm < 0 then
							show = vehicle.cp.speeds.bunkerSilo > 3
						else
							show = (vehicle.cp.speeds.bunkerSilo < 15 and vehicle.cp.mode10.leveling) or (vehicle.cp.speeds.bunkerSilo < 20 and not vehicle.cp.mode10.leveling)
						end
					end	
				elseif fn == "changeWorkWidth" and prm < 0 then
					show = vehicle.cp.workWidth > 0.1;
				elseif fn == 'changeMode10Radius' then
					if prm < 0 then
						show = vehicle.cp.mode10.searchRadius > 1
					end
				end
			end;
			self:setShow(show);
		end;


		if self.show then
			-- set color
			local currentColor = self.curColor;
			local targetColor = currentColor;
			local hoverColor = 'hover';
			if fn == 'openCloseHud' then
				hoverColor = 'closeRed';
			end;

			if fn == 'movePipeToPosition' then
				if vehicle.cp.pipeWorkToolIndex ~= nil and vehicle.cp.manualPipePositionOrder then
					targetColor = 'warningRed';
				elseif vehicle.cp.pipeWorkToolIndex ~= nil then
					targetColor = 'activeGreen';
				end	
			elseif fn == 'moveShovelToPosition' and not self.isDisabled and vehicle.cp.manualShovelPositionOrder and vehicle.cp.manualShovelPositionOrder == prm then  -- forced color
				targetColor = 'warningRed';
			elseif not self.isDisabled and not self.isActive and not self.isHovered and self.canBeClicked and not self.isClicked then
				targetColor = 'white';
			elseif self.isDisabled then
				targetColor = 'whiteDisabled';
			elseif not self.isDisabled and self.canBeClicked and self.isClicked and fn ~= 'openCloseHud' then
				targetColor = 'activeRed';
			elseif self.isHovered and ((not self.isDisabled and self.isToggleButton and self.isActive and self.canBeClicked and not self.isClicked) or (not self.isDisabled and not self.isActive and self.canBeClicked and not self.isClicked)) then
				targetColor = hoverColor;
				hoveredButton = true;
				if self.isToggleButton then
					--print(string.format('self %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> hoverColor', fn, g_updateLoopIndex, tostring(self.isHovered), tostring(self.isActive), tostring(self.isDisabled), tostring(self.canBeClicked)));
				end;
			elseif self.isActive and (not self.isToggleButton or (self.isToggleButton and not self.isHovered)) then
				targetColor = 'activeGreen';
				if self.isToggleButton then
					--print(string.format('button %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> activeGreen', fn, g_updateLoopIndex, tostring(self.isHovered), tostring(self.isActive), tostring(self.isDisabled), tostring(self.canBeClicked)));
				end;
			end;

			if currentColor ~= targetColor then
				self:setColor(targetColor);
			end;

			-- render
			self.overlay:render();
		end;
	end;	--elseif button.overlay ~= nil

	return hoveredButton;
end;

function courseplay.button:setColor(colorName)
	if self.overlay and colorName and (self.curColor == nil or self.curColor ~= colorName) and courseplay.hud.colors[colorName] then
		self.overlay:setColor(unpack(courseplay.hud.colors[colorName]));
		self.curColor = colorName;
	end;
end;

function courseplay.button:setPosition(posX, posY)
	self.x = posX;
	self.x_init = posX;
	self.x2 = posX + self.width;

	self.y = posY;
	self.y_init = posY;
	self.y2 = posY + self.height;

	if not self.overlay then return; end;
	self.overlay:setPosition(self.x, self.y);
end;

function courseplay.button:setOffset(offsetX, offsetY)
	offsetX = offsetX or 0
	offsetY = offsetY or 0

	self.x = self.x_init + offsetX;
	self.y = self.y_init + offsetY;
	self.x2 = self.x + self.width;
	self.y2 = self.y + self.height;

	if not self.overlay then return; end;
	self.overlay:setPosition(self.x, self.y);
end

function courseplay.button:setParameter(parameter)
	if self.parameter ~= parameter then
		self.parameter = parameter;
	end;
end;

function courseplay.button:setToolTip(text)
	if self.toolTip ~= text then
		self.toolTip = text;
	end;
end;

function courseplay.button:setActive(active)
	if self.isActive ~= active then
		self.isActive = active;
	end;
end;

function courseplay.button:setCanBeClicked(canBeClicked)
	if self.canBeClicked ~= canBeClicked then
		self.canBeClicked = canBeClicked;
	end;
end;

function courseplay.button:setClicked(clicked)
	if self.isClicked ~= clicked then
		self.isClicked = clicked;
	end;
end;

function courseplay.button:setDisabled(disabled)
	if self.isDisabled ~= disabled then
		self.isDisabled = disabled;
	end;
end;

function courseplay.button:setHovered(hovered)
	if self.isHovered ~= hovered then
		self.isHovered = hovered;
	end;
end;

function courseplay.button:setCanScrollUp(canScrollUp)
	if self.canScrollUp ~= canScrollUp then
		self.canScrollUp = canScrollUp;
	end;
end;

function courseplay.button:setCanScrollDown(canScrollDown)
	if self.canScrollDown ~= canScrollDown then
		self.canScrollDown = canScrollDown;
	end;
end;

function courseplay.button:setShow(show)
	if self.show ~= show then
		self.show = show;
	end;
end;

function courseplay.button:setAttribute(attribute, value)
	if self[attribute] ~= value then
		self[attribute] = value;
	end;
end;

function courseplay.button:deleteOverlay()
	if self.overlay ~= nil and self.overlay.overlayId ~= nil and self.overlay.delete ~= nil then
		self.overlay:delete();
	end;
end;

function courseplay.button:getHasMouse(mouseX, mouseY)
	-- return mouseX > self.x and mouseX < self.x2 and mouseY > self.y and mouseY < self.y2;
	return courseplay:mouseIsInArea(mouseX, mouseY, self.x, self.x2, self.y, self.y2);
end;



-- #################################################################
-- courseplay.buttons

function courseplay.buttons:renderButtons(vehicle, page)
	-- self = courseplay.buttons

	local hoveredButton;

	for _,button in pairs(vehicle.cp.buttons.global) do
		if button:render() then
			hoveredButton = button;
		end;
	end;

	for _,button in pairs(vehicle.cp.buttons[page]) do
		if button:render() then
			hoveredButton = button;
		end;
	end;

	if page == courseplay.hud.PAGE_MANAGE_COURSES then 
		for _,button in pairs(vehicle.cp.buttons[-courseplay.hud.PAGE_MANAGE_COURSES]) do
			if button:render() then
				hoveredButton = button;
			end;
		end;
	end;

	if vehicle.cp.suc.active then
		if vehicle.cp.suc.fruitNegButton:render() then
			hoveredButton = vehicle.cp.suc.fruitNegButton;
		end;
		if vehicle.cp.suc.fruitPosButton:render() then
			hoveredButton = vehicle.cp.suc.fruitPosButton;
		end;
	end;

	-- set currently hovered button in vehicle
	self:setHoveredButton(vehicle, hoveredButton);
end;

function courseplay.buttons:setHoveredButton(vehicle, button)
	if vehicle.cp.buttonHovered == button then
		return;
	end;
	vehicle.cp.buttonHovered = button;

	self:onHoveredButtonChanged(vehicle);
end;

function courseplay.buttons:onHoveredButtonChanged(vehicle)
	-- set toolTip in vehicle
	if vehicle.cp.buttonHovered ~= nil and vehicle.cp.buttonHovered.toolTip ~= nil then
		courseplay:setToolTip(vehicle, vehicle.cp.buttonHovered.toolTip);
	elseif vehicle.cp.buttonHovered == nil then
		courseplay:setToolTip(vehicle, nil);
	end;
end;

function courseplay.buttons:deleteButtonOverlays(vehicle)
	for k,buttonSection in pairs(vehicle.cp.buttons) do
		for i,button in pairs(buttonSection) do
			button:deleteOverlay();
		end;
	end;
end;

function courseplay.buttons:setActiveEnabled(vehicle, section)
	local anySection = section == nil or section == 'all';

	if anySection or section == 'pageNav' then
		for _,button in pairs(vehicle.cp.buttons.global) do
			if button.functionToCall == 'setHudPage' then
				local pageNum = button.parameter;
				button:setActive(pageNum == vehicle.cp.hud.currentPage);

				if vehicle.cp.mode == nil then
					button:setDisabled(false);
				elseif courseplay.hud.pagesPerMode[vehicle.cp.mode] ~= nil and courseplay.hud.pagesPerMode[vehicle.cp.mode][pageNum] then
					if pageNum == 0 then
						local disabled = not (vehicle.cp.minHudPage == 0 or vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or vehicle.cp.attachedCombine ~= nil);
						button:setDisabled(disabled);
					else
						button:setDisabled(false);
					end;
				else
					button:setDisabled(true);
				end;

				button:setCanBeClicked(not button.isDisabled and not button.isActive);
			end;
		end;
	end;

	if vehicle.cp.hud.currentPage == 1 and (anySection or section == 'quickModes' or section == 'recording' or section == 'customFieldShow' or section == 'findFirstWaypoint') then
		for _,button in pairs(vehicle.cp.buttons[1]) do
			local fn, prm = button.functionToCall, button.parameter;
			if fn == 'setCpMode' and (anySection or section == 'quickModes') then
				button:setActive(vehicle.cp.mode == prm);
				local disabled = not courseplay:getCanVehicleUseMode(vehicle, prm);
				button:setDisabled(disabled);
				button:setCanBeClicked(not button.isDisabled and not button.isActive);
			end;

			if fn == 'toggleCustomFieldEdgePathShow' and (anySection or section == 'customFieldShow') then
				button:setActive(vehicle.cp.fieldEdge.customField.show);
			end;

			if fn == 'toggleFindFirstWaypoint' and (anySection or section == 'findFirstWaypoint') then
				button:setActive(vehicle.cp.distanceCheck);
			end;

			if anySection or section == 'recording' then
				if fn == 'stop_record' then
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'setRecordingPause' then
					button:setActive(vehicle.cp.recordingIsPaused);
					button:setDisabled(vehicle.cp.waypointIndex < 4 or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'delete_waypoint' then
					button:setDisabled(not vehicle.cp.recordingIsPaused or vehicle.cp.waypointIndex <= 4);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'set_waitpoint' or fn == 'set_crossing' then
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'setRecordingTurnManeuver' then --isToggleButton
					button:setActive(vehicle.cp.isRecordingTurnManeuver);
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.drivingDirReverse);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'change_DriveDirection' then --isToggleButton
					button:setActive(vehicle.cp.drivingDirReverse);
					button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
					button:setCanBeClicked(not button.isDisabled);
				elseif fn == 'addSplitRecordingPoints' then
					button:setDisabled(not vehicle.cp.recordingIsPaused);
					button:setCanBeClicked(not button.isDisabled);
				end;
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 2 and (anySection or section == 'page2') then
		local enable, show = true, true;
		local numVisibleCourses = #(vehicle.cp.hud.courses);
		local nofolders = nil == next(g_currentMission.cp_folders);
		local indent = courseplay.hud.indent;
		local row, fn;
		for _, button in pairs(vehicle.cp.buttons[-2]) do
			row = button.row;
			fn = button.functionToCall;
			enable = true;
			show = true;

			if row > numVisibleCourses then
				show = false;
			else
				if fn == 'expandFolder' then
					if vehicle.cp.hud.courses[row].type == 'course' then
						show = false;
					else
						-- position the expandFolder buttons
						button:setOffset(vehicle.cp.hud.courses[row].level * indent, 0)
						
						if vehicle.cp.hud.courses[row].id == 0 then
							show = false; --hide for level 0 'folder'
						else
							-- check if plus or minus should show up
							if vehicle.cp.folder_settings[vehicle.cp.hud.courses[row].id].showChildren then
								button:setSpriteSectionUVs('navMinus');
							else
								button:setSpriteSectionUVs('navPlus');
							end;
							if g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild == 0 then
								enable = false; -- button has no children
							end;
						end;
					end;
				else
					if vehicle.cp.hud.courses[row].type == 'folder' and (fn == 'loadSortedCourse' or fn == 'addSortedCourse') then
						show = false;
					elseif vehicle.cp.hud.choose_parent ~= true then
						if fn == 'deleteSortedItem' and vehicle.cp.hud.courses[row].type == 'folder' and g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild ~= 0 then
							enable = false;
						elseif fn == 'linkParent' then
							button:setSpriteSectionUVs('folderParentFrom');
							if nofolders then
								enable = false;
							end;
						elseif vehicle.cp.hud.courses[row].type == 'course' and (fn == 'loadSortedCourse' or fn == 'addSortedCourse' or fn == 'deleteSortedItem') and vehicle.cp.isDriving then
							enable = false;
						end;
					else
						if fn ~= 'linkParent' then
							enable = false;
						else
							button:setSpriteSectionUVs('folderParentTo');
						end;
					end;
				end;
			end;

			button:setDisabled(not enable or not show);
			button:setShow(show);
		end; -- for buttons
		courseplay.settings.validateCourseListArrows(vehicle);

	elseif vehicle.cp.hud.currentPage == 3 and anySection then
		local isMode4or6 = vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK;
		for _,button in pairs(vehicle.cp.buttons[3]) do
			if (button.row == 1 or button.row == 2) and button.functionToCall == 'rowButton' then
				button:setDisabled(not isMode4or6);
				button:setShow(isMode4or6);
				button:setActive(vehicle.cp.turnOnField);
				button:setCanBeClicked(not button.isDisabled);
			elseif button.functionToCall == 'changeLastValidTipDistance' then
				local activate = vehicle.cp.lastValidTipDistance ~= nil
				button:setDisabled(not activate);
				button:setCanBeClicked(activate);
				button:setShow(activate);
			end;
		end;

	elseif vehicle.cp.hud.currentPage == 6 then
		if anySection or section == 'debug' then
			for _,button in pairs(vehicle.cp.buttons[6]) do
				if button.functionToCall == 'toggleDebugChannel' then
					button:setDisabled(button.parameter > courseplay.numDebugChannels);
					button:setActive(courseplay.debugChannels[button.parameter] == true);
					button:setCanBeClicked(not button.isDisabled);
				end;
			end;
		end;

		if anySection or section == 'visualWaypoints' then
			vehicle.cp.visualWaypointsStartEndButton1:setActive(vehicle.cp.visualWaypointsStartEnd);
			vehicle.cp.visualWaypointsStartEndButton1:setCanBeClicked(true);

			vehicle.cp.visualWaypointsStartEndButton2:setActive(vehicle.cp.visualWaypointsStartEnd);
			vehicle.cp.visualWaypointsStartEndButton2:setCanBeClicked(true);

			vehicle.cp.visualWaypointsAllEndButton:setActive(vehicle.cp.visualWaypointsAll);
			vehicle.cp.visualWaypointsAllEndButton:setCanBeClicked(true);

			vehicle.cp.visualWaypointsCrossingButton:setActive(vehicle.cp.visualWaypointsCrossing);
			vehicle.cp.visualWaypointsCrossingButton:setCanBeClicked(true);
		end;

	elseif vehicle.cp.hud.currentPage == 8 and (anySection or section == 'generateCourse' or section == 'selectedFieldShow' or section == 'suc') then
		vehicle.cp.hud.generateCourseButton:setDisabled(not vehicle.cp.hasValidCourseGenerationData);
		if vehicle.cp.hud.showSelectedFieldEdgePathButton then
			vehicle.cp.hud.showSelectedFieldEdgePathButton:setActive(vehicle.cp.fieldEdge.selectedField.show);
		end;
		if vehicle.cp.suc.toggleHudButton then
			vehicle.cp.suc.toggleHudButton:setActive(vehicle.cp.suc.active);
		end;

	elseif vehicle.cp.hud.currentPage == 9 and (anySection or section == 'shovel') then
		for _,button in pairs(vehicle.cp.buttons[9]) do
			if button.functionToCall == 'saveShovelPosition' then --isToggleButton
				button:setActive(vehicle.cp.shovelStatePositions[button.parameter] ~= nil);
				button:setCanBeClicked(true);
			elseif button.functionToCall == 'moveShovelToPosition' then
				button:setDisabled(not vehicle.cp.hasShovelStatePositions[button.parameter]);
			end;
		end;
	end;	
end;

