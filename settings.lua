local curFile = 'settings.lua';

local abs, ceil, max, min = math.abs, math.ceil, math.max, math.min;

function courseplay:openCloseHud(vehicle, open)
	courseplay:setMouseCursor(vehicle, open);
	vehicle.cp.hud.show = open;
	--print(string.format("courseplay:openCloseHud set to %s",tostring(vehicle.cp.hud.show)))
	if open then
		--courseplay.buttons:setActiveEnabled(vehicle, 'all');
	else
		courseplay.buttons:setHoveredButton(vehicle, nil);
	end;
end;

function courseplay:setCpMode(vehicle, modeNum)
	if vehicle.cp.mode ~= modeNum then
		vehicle.cp.mode = modeNum;
		--courseplay:setNextPrevModeVars(vehicle);
		courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.currentModeIcon, courseplay.hud.bottomInfo.modeUVsPx[modeNum], courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
		--courseplay.buttons:setActiveEnabled(vehicle, 'all');

		--if not CpManager.isDeveloper then
			if modeNum == courseplay.MODE_COMBI then
				vehicle.cp.drivingMode:set(DrivingModeSetting.DRIVING_MODE_NORMAL)
			else
				vehicle.cp.drivingMode:set(DrivingModeSetting.DRIVING_MODE_AIDRIVER)
			end
		--end
		courseplay:setAIDriver(vehicle, modeNum)
	end;
end;

function courseplay:setAIDriver(vehicle, mode)
	if vehicle.cp.driver then
		vehicle.cp.driver:delete()
	end
	if mode == courseplay.MODE_TRANSPORT then
		---@type AIDriver
		vehicle.cp.driver = AIDriver(vehicle)
	elseif mode == courseplay.MODE_GRAIN_TRANSPORT then
		vehicle.cp.driver = GrainTransportAIDriver(vehicle)	
	elseif mode == courseplay.MODE_COMBI then
		CombineUnloadAIDriver:setHudContent(vehicle)
	--	vehicle.cp.driver = CombineUnloadAIDriver(vehicle)
	elseif mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY then
		vehicle.cp.driver = ShovelModeAIDriver(vehicle)
	elseif mode == courseplay.MODE_SEED_FERTILIZE then
		vehicle.cp.driver = FillableFieldworkAIDriver(vehicle)
	elseif mode == courseplay.MODE_FIELDWORK then
		vehicle.cp.driver = UnloadableFieldworkAIDriver.create(vehicle)
	elseif mode == courseplay.MODE_BUNKERSILO_COMPACTER then
		vehicle.cp.driver = LevelCompactAIDriver(vehicle)
	elseif mode == courseplay.MODE_FIELD_SUPPLY then
		vehicle.cp.driver = FieldSupplyAIDriver(vehicle)
	end
end

--[[function courseplay:setNextPrevModeVars(vehicle)
	local curMode = vehicle.cp.mode;
	local nextMode, prevMode, nextModeTest, prevModeTest = nil, nil, curMode + 1, curMode - 1;

	if curMode > courseplay.MODE_GRAIN_TRANSPORT then
		while prevModeTest >= courseplay.MODE_GRAIN_TRANSPORT do
			if courseplay:getCanVehicleUseMode(vehicle, prevModeTest) then
				prevMode = prevModeTest;
				break;
			else
				-- invalid mode --> skip
				prevModeTest = prevModeTest - 1;
			end;
		end;
	end;
	vehicle.cp.prevMode = prevMode;

	if curMode < courseplay.NUM_MODES then
		while nextModeTest <= courseplay.NUM_MODES do
			if courseplay:getCanVehicleUseMode(vehicle, nextModeTest) then
				nextMode = nextModeTest;
				break;
			else
				-- invalid mode --> skip
				nextModeTest = nextModeTest + 1;
			end;
		end;
	end;
	vehicle.cp.nextMode = nextMode;
end;]]

--[[function courseplay:getCanVehicleUseMode(vehicle, mode)
	if not CpManager.isDeveloper then
		if mode == courseplay.MODE_OVERLOADER
		or mode == courseplay.MODE_COMBINE_SELF_UNLOADING
		or mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT
		or mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY
		or mode == courseplay.MODE_BUNKERSILO_COMPACTER then
		return false;
		end
	end	
	if mode == courseplay.MODE_COMBINE_SELF_UNLOADING and not vehicle.cp.isCombine and not vehicle.cp.isChopper and not vehicle.cp.isHarvesterSteerable then
		return false;
	elseif (vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable) and (mode ~= courseplay.MODE_TRANSPORT and mode ~= courseplay.MODE_FIELDWORK ) then -- and mode ~= courseplay.MODE_COMBINE_SELF_UNLOADING) then
		return false;
	elseif mode ~= courseplay.MODE_TRANSPORT and (vehicle.cp.isWoodHarvester or vehicle.cp.isWoodForwarder) then
		return false;
	end;

	return true;
end;]]

function courseplay:setDriveNow(vehicle)
	courseplay:setDriveUnloadNow(vehicle, true);
end

function courseplay:forceGoToUnloadCourse(vehicle)
	vehicle.cp.driver:stopAndChangeToUnload()
end


function courseplay:toggleShowMiniHud(vehicle)
	vehicle.cp.hud.showMiniHud = not vehicle.cp.hud.showMiniHud
end

function courseplay:toggleConvoyActive(vehicle)
	vehicle.cp.convoyActive =  not vehicle.cp.convoyActive
	--self:setCpVar('convoyActive', self.cp.convoyActive, courseplay.isClient);
end

function courseplay:setConvoyMinDistance(vehicle, changeBy)
	vehicle.cp.convoy.minDistance = MathUtil.clamp(vehicle.cp.convoy.minDistance + changeBy*10, 20, 2000);
end

function courseplay:setConvoyMaxDistance(vehicle, changeBy)
	vehicle.cp.convoy.maxDistance = MathUtil.clamp(vehicle.cp.convoy.maxDistance + changeBy*10, 40, 3000);
end

function courseplay:toggleFuelSaveOption(self)
	self.cp.saveFuelOptionActive = not self.cp.saveFuelOptionActive 
end

function courseplay:toggleFertilizeOption(self)
	self.cp.fertilizerEnabled = not self.cp.fertilizerEnabled
end

function courseplay:toggleRidgeMarkersAutomatic(self)
	self.cp.ridgeMarkersAutomatic = not self.cp.ridgeMarkersAutomatic
end

function courseplay:toggleAutomaticUnloadingOnField(self)
	self.cp.automaticUnloadingOnField = not self.cp.automaticUnloadingOnField;
end

function courseplay:toggleAutoRefuel(self)
	self.cp.allwaysSearchFuel = not self.cp.allwaysSearchFuel 
end

function courseplay:toggleAutomaticCoverHandling (self)
	self.cp.automaticCoverHandling = not self.cp.automaticCoverHandling 
end

function courseplay:toggleMode10automaticSpeed(self)
	if self.cp.mode10.leveling then
		self.cp.mode10.automaticSpeed = not self.cp.mode10.automaticSpeed
	end
end
function courseplay:toggleMode10drivingThroughtLoading(self)
	self.cp.mode10.drivingThroughtLoading = not self.cp.mode10.drivingThroughtLoading
end

function courseplay:toggleMode10AutomaticHeight(self)
	self.cp.mode10.automaticHeigth = not self.cp.mode10.automaticHeigth 
end

function courseplay:toggleMode10Mode(self)
	self.cp.mode10.leveling = not self.cp.mode10.leveling
end

function courseplay:toggleMode10SearchMode(self)
	self.cp.mode10.searchCourseplayersOnly = not self.cp.mode10.searchCourseplayersOnly
end

function courseplay:toggleWantsCourseplayer(combine)
	combine.cp.wantsCourseplayer = not combine.cp.wantsCourseplayer;
end;

function courseplay:toggleOppositeTurnMode(vehicle)
	vehicle.cp.oppositeTurnMode = not vehicle.cp.oppositeTurnMode
end

function courseplay:startStop(vehicle)
	if vehicle.cp.canDrive then
		if not vehicle:getIsCourseplayDriving() then
			courseplay:start(vehicle);
		else
			courseplay:stop(vehicle);
		end
	else
		courseplay:start_record(vehicle);
	end
	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
end;

function courseplay:startStopCourseplayer(combine)
	local tractor = combine.courseplayers[1];
	tractor.cp.forcedToStop = not tractor.cp.forcedToStop;
end;

function courseplay:setVehicleWait(vehicle, active)
	vehicle.cp.wait = active;
end;

function courseplay:cancelWait(vehicle, cancelStopAtEnd)
	if vehicle.cp.driver then
		vehicle.cp.driver:continue()
	end
	if vehicle.cp.wait then
		courseplay:setVehicleWait(vehicle, false);
	end;
	if vehicle.cp.mode == 1 or vehicle.cp.mode == 3 then
		vehicle.cp.isUnloaded = true;
	end;
	if cancelStopAtEnd then
		courseplay:setStopAtEnd(vehicle, false);
	end;
end;

function courseplay:setStopAtEnd(vehicle, bool)
	--if bool is nil or a number, toggle stopAtEnd
	-- 'line' was introduced in addRowButton in the new mode 2 branch as a parameter to pass on to the callback functions
	-- for selecting the combine. It breaks this function though as it expects a nil when toggled in the HUD.
	-- Since the HUD/button callback code is so broken/messy that I don't want to touch it, I just put
	-- one of the most embarrassing hacks of my IT career in here. I'm ashamed of myself.
	if bool == nil or type(bool) == 'number' then
		vehicle.cp.stopAtEnd = not vehicle.cp.stopAtEnd
	else
		vehicle.cp.stopAtEnd = bool;
	end
	--vehicle:setCpVar('stopAtEnd', vehicle.cp.stopAtEnd, courseplay.isClient);
end;

function courseplay:setDriveUnloadNow(vehicle, bool)
	if vehicle.cp.driveUnloadNow ~= bool then
		vehicle.cp.driveUnloadNow = bool;
		courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
	end;
		
end;

function courseplay:sendCourseplayerHome(combine)
	courseplay:setDriveUnloadNow(combine.courseplayers[1], true);
end

function courseplay:toggleTurnStage(combine)
	combine.cp.turnStage = self.cp.turnStage== 0 and 1 or 0 ;
end

function courseplay:switchCourseplayerSide(combine)
	if courseplay:isChopper(combine) then
		local tractor = combine.courseplayers[1];
		if tractor == nil then
			return;
		end;

		courseplay:setModeState(tractor, 10);

		if combine.cp.forcedSide == nil then
			combine.cp.forcedSide = "left";
		elseif combine.cp.forcedSide == "left" then
			combine.cp.forcedSide = "right";
		else
			combine.cp.forcedSide = nil;
		end;
	end;
end;

function courseplay:setHudPage(vehicle, pageNum)
	vehicle.cp.hud.hudPageButtons[vehicle.cp.hud.currentPage]:setActive(false)
	vehicle.cp.hud.currentPage = pageNum;
	vehicle.cp.hud.hudPageButtons[pageNum]:setActive(true)
	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
end;

function courseplay:changeCombineOffset(vehicle, changeBy)
	local previousOffset = vehicle.cp.combineOffset;

	vehicle.cp.combineOffsetAutoMode = false;
	vehicle.cp.combineOffset = courseplay:round(vehicle.cp.combineOffset, 1) + changeBy*0.1;
	if abs(vehicle.cp.combineOffset) < 0.1 then
		vehicle.cp.combineOffset = 0.0;
		vehicle.cp.combineOffsetAutoMode = true;
	end;

	courseplay:debug(nameNum(vehicle) .. ": manual combine_offset change: prev " .. previousOffset .. " // new " .. vehicle.cp.combineOffset .. " // auto = " .. tostring(vehicle.cp.combineOffsetAutoMode), 4);
end

function courseplay:changeTipperOffset(vehicle, changeBy)
	vehicle.cp.tipperOffset = courseplay:round(vehicle.cp.tipperOffset, 1) + changeBy*0.1;
	if abs(vehicle.cp.tipperOffset) < 0.1 then
		vehicle.cp.tipperOffset = 0;
	end;
end

function courseplay:changeLaneOffset(vehicle, changeBy, force)
	vehicle.cp.laneOffset = force or (courseplay:round(vehicle.cp.laneOffset, 1) + changeBy*0.1);
	if abs(vehicle.cp.laneOffset) < 0.1 then
		vehicle.cp.laneOffset = 0;
	end;
end;

function courseplay:changeLaneNumber(vehicle, changeBy, reset)
	--This function takes input from the hud. And claculates laneOffset by dividing tool workwidth and multiplying that by the lane number counting outwards.
	local toolsIsEven = vehicle.cp.multiTools%2 == 0
	
	if reset then
		vehicle.cp.laneNumber = 0;
		vehicle.cp.laneOffset = 0
	else
		--skip zero if multiTools is even
		if toolsIsEven then
			if vehicle.cp.laneNumber == -1 and changeBy > 0 then
				changeBy = 2
			elseif vehicle.cp.laneNumber == 1 and changeBy < 0 then
				changeBy = -2
			end
		end
		vehicle.cp.laneNumber = MathUtil.clamp(vehicle.cp.laneNumber + changeBy, math.floor(vehicle.cp.multiTools/2)*-1, math.floor(vehicle.cp.multiTools/2));
		local newOffset = 0
		if toolsIsEven then
			if vehicle.cp.laneNumber > 0 then
				newOffset = vehicle.cp.workWidth/2 + (vehicle.cp.workWidth*(vehicle.cp.laneNumber-1))
			else
				newOffset = -vehicle.cp.workWidth/2 + (vehicle.cp.workWidth*(vehicle.cp.laneNumber+1))
			end
		else
			newOffset = vehicle.cp.workWidth*vehicle.cp.laneNumber
		end
		courseplay:changeLaneOffset(vehicle, nil , newOffset)
	end;

end;

function courseplay:changeToolOffsetX(vehicle, changeBy, force, noDraw)
	vehicle.cp.toolOffsetX = force or (courseplay:round(vehicle.cp.toolOffsetX, 1) + changeBy*0.1);
	if abs(vehicle.cp.toolOffsetX) < 0.1 then
		vehicle.cp.toolOffsetX = 0;
	end;
	vehicle.cp.totalOffsetX = vehicle.cp.toolOffsetX;
	if not noDraw then
		courseplay:setCustomTimer(vehicle, 'showWorkWidth', 2);
	end;
end;

function courseplay:setAutoToolOffsetX(vehicle)
	-- set the auto tool offset if exists or 0
	self:changeToolOffsetX(vehicle, nil, vehicle.cp.automaticToolOffsetX and vehicle.cp.automaticToolOffsetX or 0)
end

function courseplay:changeToolOffsetZ(vehicle, changeBy, force, noDraw)
	vehicle.cp.toolOffsetZ = force or (courseplay:round(vehicle.cp.toolOffsetZ, 1) + changeBy*0.1);
	if abs(vehicle.cp.toolOffsetZ) < 0.1 then
		vehicle.cp.toolOffsetZ = 0;
	end;

	if not noDraw then
		courseplay:setCustomTimer(vehicle, 'showWorkWidth', 2);
	end;
end;

function courseplay:changeLoadUnloadOffsetX(vehicle, changeBy, force)
	vehicle.cp.loadUnloadOffsetX = force or (courseplay:round(vehicle.cp.loadUnloadOffsetX, 1) + changeBy*0.1);
	if abs(vehicle.cp.loadUnloadOffsetX) < 0.1 then
		vehicle.cp.loadUnloadOffsetX = 0;
	end;
end;

function courseplay:changeLoadUnloadOffsetZ(vehicle, changeBy, force)
	vehicle.cp.loadUnloadOffsetZ = force or (courseplay:round(vehicle.cp.loadUnloadOffsetZ, 1) + changeBy*0.1);
	if abs(vehicle.cp.loadUnloadOffsetZ) < 0.1 then
		vehicle.cp.loadUnloadOffsetZ = 0;
	end;
end;

function courseplay:calculateWorkWidth(vehicle, noDraw)
	
	if vehicle.cp.manualWorkWidth and noDraw ~= nil then
		--courseplay:changeWorkWidth(vehicle, nil, vehicle.cp.manualWorkWidth, noDraw); 
		return
	end

	courseplay:changeWorkWidth(vehicle, nil, courseplay:getWorkWidth(vehicle), noDraw);

end;

function courseplay:changeBladeWorkWidth(vehicle, changeBy, force, noDraw)
	courseplay:changeWorkWidth(vehicle, changeBy/10, force, noDraw)
end

function courseplay:changeWorkWidth(vehicle, changeBy, force, noDraw)
	local isSetManually = false
	if force == nil and noDraw == nil then
		--print("is set manually")
		isSetManually = true
	elseif force ~= nil and noDraw ~= nil then
		--print("is set by script")
		if not vehicle.cp.isDriving and vehicle.cp.manualWorkWidth then
			return
		end
	elseif force ~= nil and noDraw == nil then
		vehicle.cp.manualWorkWidth = nil
		courseplay:changeLaneNumber(vehicle, 0, true)
		courseplay:setMultiTools(vehicle, 1)
		--print("is set by calculate button")
	end
	if force then
		if force == 0 then
			return
		end
		local newWidth = max(courseplay:round(abs(force), 1), 0.1)
		--vehicle.cp.workWidth = min(vehicle.cp.workWidth,newWidth); --TODO: check what is better:the smallest or the widest work width to consider
		vehicle.cp.workWidth = newWidth
	else
		if vehicle.cp.workWidth + changeBy > 10 then
			if abs(changeBy) == 0.1 and not (Input.keyPressedState[Input.KEY_lalt]) then -- pressing left Alt key enables to have small 0.1 steps even over 10.0 
				changeBy = 0.5 * MathUtil.sign(changeBy);
			elseif abs(changeBy) == 0.5 then
				changeBy = 2 * MathUtil.sign(changeBy);
			end;
		end;

		if (vehicle.cp.workWidth < 10 and vehicle.cp.workWidth + changeBy > 10) or (vehicle.cp.workWidth > 10 and vehicle.cp.workWidth + changeBy < 10) then
			vehicle.cp.workWidth = 10;
		else
			vehicle.cp.workWidth = max(vehicle.cp.workWidth + changeBy, 0.1);
		end;
	end;
	if isSetManually then
		vehicle.cp.manualWorkWidth = vehicle.cp.workWidth
	end
	if not noDraw then
		courseplay:setCustomTimer(vehicle, 'showWorkWidth', 2);
	end;

	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
	
end;


function courseplay:changeSiloFillType(vehicle, modifier, currentSelectedFilltype)
	local eftl = vehicle.cp.easyFillTypeList;
	local newVal = 1;
	if currentSelectedFilltype and currentSelectedFilltype ~= FillType.UNKNOWN then
		for index, fillType in ipairs(eftl) do
			if currentSelectedFilltype == fillType then
				newVal = index;
			end;
		end;
	else
		newVal = vehicle.cp.siloSelectedEasyFillType + modifier
		if newVal < 1 then
			newVal = #eftl;
		elseif newVal > #eftl then
			newVal = 1;
		end
	end;
	vehicle.cp.siloSelectedEasyFillType = newVal;
	vehicle.cp.siloSelectedFillType = eftl[newVal];

end;


function courseplay:toggleShowVisualWaypointsStartEnd(vehicle, force, visibilityUpdate)
	vehicle.cp.visualWaypointsStartEnd = Utils.getNoNil(force, not vehicle.cp.visualWaypointsStartEnd);

	-- also deactivate "all" points when deactivating startEnd
	if not vehicle.cp.visualWaypointsStartEnd then
		courseplay:toggleShowVisualWaypointsAll(vehicle, false, false);
	end;

	if visibilityUpdate == nil or visibilityUpdate then
		courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
		courseplay.signs:setSignsVisibility(vehicle);
	end;
end;

function courseplay:toggleShowVisualWaypointsAll(vehicle, force, visibilityUpdate)
	vehicle.cp.visualWaypointsAll = Utils.getNoNil(force, not vehicle.cp.visualWaypointsAll);

	-- also activate "start/end" points when activating "all"
	if vehicle.cp.visualWaypointsAll then
		courseplay:toggleShowVisualWaypointsStartEnd(vehicle, true, false);
	end;

	if visibilityUpdate == nil or visibilityUpdate then
		courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
		courseplay.signs:setSignsVisibility(vehicle);
	end;
end;

function courseplay:toggleShowVisualWaypointsCrossing(vehicle, force, visibilityUpdate)
	vehicle.cp.visualWaypointsCrossing = Utils.getNoNil(force, not vehicle.cp.visualWaypointsCrossing);
	if visibilityUpdate == nil or visibilityUpdate then
		courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
		courseplay.signs:setSignsVisibility(vehicle);
	end;
end;

function courseplay:toggleTurnOnField(vehicle)
	vehicle.cp.turnOnField = not vehicle.cp.turnOnField
end
	
function courseplay:changeMode10Radius (vehicle, changeBy)
	vehicle.cp.mode10.searchRadius = math.max(1,vehicle.cp.mode10.searchRadius + changeBy)
end

function courseplay:changeShieldHeight (vehicle, changeBy)
	vehicle.cp.mode10.shieldHeight = MathUtil.clamp(vehicle.cp.mode10.shieldHeight + changeBy,0,1.5)
end

function courseplay:changeDriveOnAtFillLevel(vehicle, changeBy)
	vehicle.cp.driveOnAtFillLevel = MathUtil.clamp(vehicle.cp.driveOnAtFillLevel + changeBy, 0, 100);
end


function courseplay:changeFollowAtFillLevel(vehicle, changeBy)
	vehicle.cp.followAtFillLevel = MathUtil.clamp(vehicle.cp.followAtFillLevel + changeBy, 0, 100);
end


function courseplay:changeTurnDiameter(vehicle, changeBy)
	vehicle.cp.turnDiameter = vehicle.cp.turnDiameter + changeBy;
	vehicle.cp.turnDiameterAutoMode = false;

	if vehicle.cp.turnDiameter < 0.5 then
		vehicle.cp.turnDiameter = 0;
	end;

	if vehicle.cp.turnDiameter <= 0 then
		vehicle.cp.turnDiameterAutoMode = true;
		vehicle.cp.turnDiameter = vehicle.cp.turnDiameterAuto
	end;
end


function courseplay:changeWaitTime(vehicle, changeBy)
	vehicle.cp.waitTime = math.max(0, vehicle.cp.waitTime + changeBy);
end;

function courseplay:getCanHaveWaitTime(vehicle)
	return vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 5 or (vehicle.cp.mode == 6 and not vehicle.cp.hasBaleLoader) or vehicle.cp.mode == 8;
end;

function courseplay:changeTurnSpeed(vehicle, changeBy)
	local speed = vehicle.cp.speeds.turn;
	speed = MathUtil.clamp(speed + changeBy, vehicle.cp.speeds.minTurn, vehicle.cp.speeds.max);
	vehicle.cp.speeds.turn = speed ;
end

function courseplay:changeFieldSpeed(vehicle, changeBy)
	local speed = vehicle.cp.speeds.field;
	speed = MathUtil.clamp(speed + changeBy, vehicle.cp.speeds.minField, vehicle.cp.speeds.max);
	vehicle.cp.speeds.field = speed;
end

function courseplay:changeMaxSpeed(vehicle, changeBy)
	if not vehicle.cp.speeds.useRecordingSpeed then
		local speed = vehicle.cp.speeds.street;
		speed = MathUtil.clamp(speed + changeBy, vehicle.cp.speeds.minStreet, vehicle.cp.speeds.max);
		vehicle.cp.speeds.street = speed;
	end;
end

function courseplay:changeReverseSpeed(vehicle, changeBy, force, forceReloadPage)
	local speed = force or (vehicle.cp.speeds.reverse + changeBy);
	if not force then
		speed = MathUtil.clamp(speed, vehicle.cp.speeds.minReverse, vehicle.cp.speeds.max);
	end;
	vehicle.cp.speeds.reverse = speed;

	if forceReloadPage then
		courseplay.hud:setReloadPageOrder(vehicle, 5, true);
	end;
end
function courseplay:changeBunkerSpeed(vehicle, changeBy)
	local upperLimit = 20 
	local speed = vehicle.cp.speeds.bunkerSilo;
	if vehicle.cp.mode10.leveling then
		upperLimit = 15
	end
	speed = MathUtil.clamp(speed + changeBy, 3, upperLimit);
	vehicle.cp.speeds.bunkerSilo = speed;
end

function courseplay:toggleUseRecordingSpeed(vehicle)
	vehicle.cp.speeds.useRecordingSpeed = not vehicle.cp.speeds.useRecordingSpeed;
end;

function courseplay:changeWarningLightsMode(vehicle, changeBy)
	vehicle.cp.warningLightsMode = MathUtil.clamp(vehicle.cp.warningLightsMode + changeBy, courseplay.lights.WARNING_LIGHTS_NEVER, courseplay.lights.WARNING_LIGHTS_BEACON_ALWAYS);
end;

function courseplay:toggleOpenHudWithMouse(vehicle)
	vehicle.cp.hud.openWithMouse = not vehicle.cp.hud.openWithMouse;
end;

function courseplay:toggleRealisticDriving(vehicle)
	vehicle.cp.realisticDriving = not vehicle.cp.realisticDriving;
end;

function courseplay:toggleDrivingMode(vehicle)
	vehicle.cp.drivingMode:next()
	courseplay.debugVehicle(12, vehicle, 'Driving mode: %d', vehicle.cp.drivingMode:get())
end

function courseplay:toggleAutoDriveMode(vehicle)
	vehicle.cp.settings.autoDriveMode:next()
	courseplay.debugVehicle(12, vehicle, 'AutoDrive mode: %d', vehicle.cp.settings.autoDriveMode:get())
end


function courseplay:toggleAlignmentWaypoint( vehicle )
	vehicle.cp.alignment.enabled = not vehicle.cp.alignment.enabled
end

function courseplay:togglePlowFieldEdge(self)
	self.cp.plowFieldEdge = not self.cp.plowFieldEdge;
end;


function courseplay:toggleSearchCombineMode(vehicle)
	vehicle.cp.searchCombineAutomatically = not vehicle.cp.searchCombineAutomatically;
	if not vehicle.cp.searchCombineAutomatically then
		courseplay:setSearchCombineOnField(vehicle, nil, 0);
	end;
end;

function courseplay:setSearchCombineOnField(vehicle, changeDir, force)
	if courseplay.fields.numAvailableFields == 0 or not vehicle.cp.searchCombineAutomatically then
		vehicle.cp.searchCombineOnField = 0;
		return;
	end;
	if force and courseplay.fields.fieldData[force] then
		vehicle.cp.searchCombineOnField = force;
		return;
	end;

	local newFieldNum = vehicle.cp.searchCombineOnField + changeDir;
	if newFieldNum == 0 then
		vehicle.cp.searchCombineOnField = newFieldNum;
		return;
	end;

	while courseplay.fields.fieldData[newFieldNum] == nil do
		if newFieldNum == 0 then
			vehicle.cp.searchCombineOnField = newFieldNum;
			return;
		end;
		newFieldNum = MathUtil.clamp(newFieldNum + changeDir, 0, courseplay.fields.numAvailableFields);
	end;

	vehicle.cp.searchCombineOnField = newFieldNum;
end;

function courseplay:selectAssignedCombine(vehicle, changeBy)
	local combines = courseplay:getAllCombines();
	vehicle.cp.selectedCombineNumber = MathUtil.clamp(vehicle.cp.selectedCombineNumber + changeBy, 0, #combines);

	if vehicle.cp.selectedCombineNumber == 0 then
		vehicle.cp.savedCombine = nil;
		vehicle:setCpVar('HUD4savedCombineName',"",courseplay.isClient);
	else
		vehicle.cp.savedCombine = combines[vehicle.cp.selectedCombineNumber];
		local combineName = vehicle.cp.savedCombine.name or courseplay:loc('COURSEPLAY_COMBINE');
		local x1 = courseplay.hud.col2posX[4];
		local x2 = courseplay.hud.buttonPosX[1] - getTextWidth(courseplay.hud.fontSizes.contentValue, ' (9999m)');
		local shortenedName, firstChar, lastChar = Utils.limitTextToWidth(combineName, courseplay.hud.fontSizes.contentValue, x2 - x1, false, '...');
		vehicle:setCpVar('HUD4savedCombineName',shortenedName,courseplay.isClient);
	end;

	courseplay:removeActiveCombineFromTractor(vehicle);
end;

function courseplay:removeActiveCombineFromTractor(vehicle)
	if vehicle.cp.activeCombine ~= nil then
		courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine);
	end;
	courseplay:removeFromVehicleLocalIgnoreList(vehicle, vehicle.cp.lastActiveCombine)
	vehicle.cp.lastActiveCombine = nil;
	courseplay.hud:setReloadPageOrder(vehicle, 4, true);
end;

function courseplay:removeSavedCombineFromTractor(vehicle)
	vehicle.cp.savedCombine = nil;
	vehicle.cp.selectedCombineNumber = 0;
	vehicle:setCpVar('HUD4savedCombine',nil,courseplay.isClient);
	vehicle:setCpVar('HUD4savedCombineName',nil,courseplay.isClient);
	courseplay.hud:setReloadPageOrder(vehicle, 4, true);
end;

function courseplay:switchDriverCopy(vehicle, changeBy)
	local drivers = courseplay:findDrivers(vehicle);
	
	if drivers ~= nil then
		vehicle.cp.selectedDriverNumber = MathUtil.clamp(vehicle.cp.selectedDriverNumber + changeBy, 0, #(drivers));

		if vehicle.cp.selectedDriverNumber == 0 then
			vehicle.cp.copyCourseFromDriver = nil;
			vehicle.cp.hasFoundCopyDriver = false;
		else
			vehicle.cp.copyCourseFromDriver = drivers[vehicle.cp.selectedDriverNumber];
			vehicle.cp.hasFoundCopyDriver = true;
		end;
	else
		vehicle.cp.copyCourseFromDriver = nil;
		vehicle.cp.selectedDriverNumber = 0;
		vehicle.cp.hasFoundCopyDriver = false;
	end;
end;

function courseplay:findDrivers(vehicle)
	local foundDrivers = {}; -- resetting all drivers
	for _,otherVehicle in pairs(g_currentMission.enterables) do
		if otherVehicle.Waypoints ~= nil and otherVehicle.hasCourseplaySpec  then
			if otherVehicle.rootNode ~= vehicle.rootNode and #(otherVehicle.Waypoints) > 0 then
				table.insert(foundDrivers, otherVehicle);
			end;
		end;
	end;

	return foundDrivers;
end;



function courseplay.settings.add_folder_settings(folder)
	folder.showChildren = false
	folder.skipMe = false
end

function courseplay.settings.add_folder(input1, input2)
-- function might be called like add_folder(vehicle, id) or like add_folder(id)
	local vehicle, id
	
	if input2 ~= nil then
		vehicle = input1
		id = input2
	else
		vehicle = false
		id = input1
	end
	
	if vehicle == false then
	-- no vehicle given -> add folder to all vehicles
		for k,v in pairs(g_currentMission.enterables) do
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				v.cp.folder_settings[id] = {}
				courseplay.settings.add_folder_settings(v.cp.folder_settings[id])
			end	
		end
	else
	-- vehicle given -> add folder to that vehicle
		vehicle.cp.folder_settings[id] = {}
		courseplay.settings.add_folder_settings(vehicle.cp.folder_settings[id])
	end
end

function courseplay.settings.update_folders(vehicle)
	local old_settings
	
	if vehicle == nil then
	-- no vehicle given -> update all folders in all vehicles
		for k,v in pairs(g_currentMission.enterables) do
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				old_settings = v.cp.folder_settings
				v.cp.folder_settings = {}
				for _,f in pairs(g_currentMission.cp_folders) do
					if old_settings[f.id] ~= nil then
						v.cp.folder_settings[f.id] = old_settings[f.id]
					else
						v.cp.folder_settings[f.id] = {}
						courseplay.settings.add_folder_settings(v.cp.folder_settings[f.id])
					end
				end
				old_settings = nil
			end	
		end
	else
	-- vehicle given -> update all folders in that vehicle
		old_settings = vehicle.cp.folder_settings
		vehicle.cp.folder_settings = {}
		for _,f in pairs(g_currentMission.cp_folders) do
			if old_settings[f.id] ~= nil then
				vehicle.cp.folder_settings[f.id] = old_settings[f.id]
			else
				vehicle.cp.folder_settings[f.id] = {}
				courseplay.settings.add_folder_settings(vehicle.cp.folder_settings[f.id])
			end
		end
	end
	old_settings = nil
end

function courseplay.settings.setReloadCourseItems(vehicle)
	if vehicle ~= nil then
		vehicle.cp.reloadCourseItems = true
		courseplay.hud:setReloadPageOrder(vehicle, 2, true);
	else
		-- make sure the course list is reloaded when tabbed to all vehicles.
		for k,v in pairs(g_currentMission.enterables) do
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				v.cp.reloadCourseItems = true
				courseplay.debugVehicle(8, v,"courseplay.hud:setReloadPageOrder(%s, 2, true) TypeName: %s ;",tostring(v.name), v.typeName)
				courseplay.hud:setReloadPageOrder(v, 2, true);
			end
		end
	end
end

function courseplay.settings.toggleFilter(vehicle, enable)
	if enable and not vehicle.cp.hud.filterEnabled then
		vehicle.cp.sorted = vehicle.cp.filtered;
		vehicle.cp.hud.filterEnabled = true;
	elseif not enable and vehicle.cp.hud.filterEnabled then
		vehicle.cp.filtered = vehicle.cp.sorted;
		vehicle.cp.sorted = g_currentMission.cp_sorted;
		vehicle.cp.hud.filterEnabled = false;
	end;
end;

function courseplay.hud.setCourses(self, start_index)
	start_index = start_index or 1
	if start_index < 1 then 
		start_index = 1
	elseif start_index > #self.cp.sorted.item then
		start_index = #self.cp.sorted.item
	end
	
	-- delete content of hud.courses
	self.cp.hud.courses = {}
	
	local index = start_index
	local hudLines = courseplay.hud.numLines
	local i = 1
	
	if index == 1 and self.cp.hud.showZeroLevelFolder then
		table.insert(self.cp.hud.courses, { id=0, uid=0, name='Level 0', displayname='Level 0', parent=0, type='folder', level=0})
		i = 2	-- = i+1
	end
	
	-- is start_index even showed?
	index = courseplay.courses:getMeOrBestFit(self, index)
	
	if index ~= 0 then
		-- insert first entry
		table.insert(self.cp.hud.courses, self.cp.sorted.item[index])
		i = i+1
		
		-- now search for the next entries
		while i <= hudLines do
			index = courseplay.courses:getNextCourse(self,index)
			if index == 0 then
				-- no next item found: fill table with previous items and abort the loop
				if start_index > 1 then
					-- shift up
					courseplay:shiftHudCourses(self, -(hudLines - i + 1))
				end
				i = hudLines+1 -- abort the loop
			else
				table.insert(self.cp.hud.courses, self.cp.sorted.item[index])
				i = i + 1
			end
		end --while
	end -- i<3

	courseplay.hud:setReloadPageOrder(self, 2, true);
end

function courseplay.hud.reloadCourses(vehicle)
	local index = 1
	local i = 1
	if vehicle ~= nil then
		while i <= #vehicle.cp.hud.courses and vehicle.cp.sorted.info[ vehicle.cp.hud.courses[i].uid ] == nil do
			i = i + 1
		end		
		if i <= #vehicle.cp.hud.courses then 
			index = vehicle.cp.sorted.info[ vehicle.cp.hud.courses[i].uid ].sorted_index
		end
		courseplay.hud.setCourses(vehicle, index)
	else
		for k,v in pairs(g_currentMission.enterables) do
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				i = 1
				-- course/folder in the hud might have been deleted -> info no longer available				
				while i <= #v.cp.hud.courses and v.cp.sorted.info[ v.cp.hud.courses[i].uid ] == nil do
					i = i + 1
				end
				if i > #v.cp.hud.courses then
					index = 1
				else
					index = v.cp.sorted.info[ v.cp.hud.courses[i].uid ].sorted_index
				end
				courseplay.hud.setCourses(v,index)
			end
		end
	end
end

function courseplay:shiftHudCourses(vehicle, change_by)	
	local hudLines = courseplay.hud.numLines
	local index = hudLines
	
	while change_by > 0 do
		-- get the index of the last showed item
		index = vehicle.cp.sorted.info[vehicle.cp.hud.courses[#(vehicle.cp.hud.courses)].uid].sorted_index
		
		-- search for the next item
		index = courseplay.courses:getNextCourse(vehicle,index)
		if index == 0 then
			-- there is no next item: abort
			change_by = 0
		else
			if #(vehicle.cp.hud.courses) == hudLines then
				-- remove first entry...
				table.remove(vehicle.cp.hud.courses, 1)
			end
			-- ... and add one at the end
			table.insert(vehicle.cp.hud.courses, vehicle.cp.sorted.item[index])
			change_by = change_by - 1
		end		
	end

	while change_by < 0 do
		-- get the index of the first showed item
		index = vehicle.cp.sorted.info[vehicle.cp.hud.courses[1].uid].sorted_index
		
		-- search reverse for the next item
		index = courseplay.courses:getNextCourse(vehicle, index, true)
		if index == 0 then
			-- there is no next item: abort
			change_by = 0
			
			-- show LevelZeroFolder?
			if vehicle.cp.hud.showZeroLevelFolder then
				if #(vehicle.cp.hud.courses) >= hudLines then
					-- remove last entry...
					table.remove(vehicle.cp.hud.courses)
				end
				table.insert(vehicle.cp.hud.courses, 1, { id=0, uid=0, name='Level 0', displayname='Level 0', parent=0, type='folder', level=0})
			end
			
		else
			if #(vehicle.cp.hud.courses) >= hudLines then
				-- remove last entry...
				table.remove(vehicle.cp.hud.courses)
			end
			-- ... and add one at the beginning:	
			table.insert(vehicle.cp.hud.courses, 1, vehicle.cp.sorted.item[index])
			change_by = change_by + 1
		end		
	end
	
	courseplay.hud:setReloadPageOrder(vehicle, 2, true);
end

--Update all vehicles' course list arrow displays
function courseplay.settings.validateCourseListArrows(vehicle)
	local n_courses = #(vehicle.cp.sorted.item)
	local n_hudcourses, prev, next
	
	if vehicle then
		-- update vehicle only
		prev = true
		next = true
		n_hudcourses = #(vehicle.cp.hud.courses)
		if not (n_hudcourses > 0) then
			prev = false
			next = false
		else
			-- update prev
			if vehicle.cp.hud.showZeroLevelFolder then
				if vehicle.cp.hud.courses[1].uid == 0 then
					prev = false
				end
			elseif vehicle.cp.sorted.info[ vehicle.cp.hud.courses[1].uid ].sorted_index == 1 then
				prev = false
			end
			-- update next
			if n_hudcourses < courseplay.hud.numLines then
				next = false
			elseif vehicle.cp.hud.showZeroLevelFolder and vehicle.cp.hud.courses[n_hudcourses].uid == 0 then
				next = false
			elseif 0 == courseplay.courses:getNextCourse(vehicle, vehicle.cp.sorted.info[ vehicle.cp.hud.courses[n_hudcourses].uid ].sorted_index) then
				next = false
			end
		end
		return prev, next;
		--vehicle.cp.hud.courseListPrev = prev
		--vehicle.cp.hud.courseListNext = next
	--[[else
		-- update all vehicles
			for k,v in pairs(g_currentMission.enterables) do
			if v.hasCourseplaySpec then -- alternative way to check if SpecializationUtil.hasSpecialization(courseplay, v.specializations)
				prev = true
				next = true
				n_hudcourses = #(v.cp.hud.courses)
				if not (n_hudcourses > 0) then
					prev = false
					next = false
				else
					-- update prev
					if v.cp.hud.showZeroLevelFolder then
						if v.cp.hud.courses[1].uid == 0 then
							prev = false
						end
					elseif v.cp.sorted.info[v.cp.hud.courses[1].uid].sorted_index == 1 then
						prev = false
					end
					-- update next
					if n_hudcourses < coursplay.hud.numLines then
						next = false
					elseif 0 == courseplay.courses:getNextCourse(v, v.cp.sorted.info[v.cp.hud.courses[n_hudcourses].uid].sorted_index) then
						next = false
					end
				end
				v.cp.hud.courseListPrev = prev
				v.cp.hud.courseListNext = next
			end -- if hasSpecialization
		end]] -- in pairs(enterables)
	end -- if vehicle
end;

function courseplay:expandFolder(vehicle, index)
-- expand/reduce a folder in the hud
	if vehicle.cp.hud.courses[index].type == 'folder' then
		local f = vehicle.cp.folder_settings[ vehicle.cp.hud.courses[index].id ]
		f.showChildren = not f.showChildren
		if f.showChildren then
		-- from not showing to showing -> put it on top to see as much of the content as possible
			courseplay.hud.setCourses(vehicle, vehicle.cp.sorted.info[vehicle.cp.hud.courses[index].uid].sorted_index)
		else
		-- from showing to not showing -> stay where it was
			courseplay.hud.reloadCourses(vehicle)
		end
	end
end

function courseplay:toggleDebugChannel(self, channel, force)
	if courseplay.debugChannels[channel] ~= nil then
		courseplay.debugChannels[channel] = Utils.getNoNil(force, not courseplay.debugChannels[channel]);
		courseplay.hud:updateDebugChannelButtons(self);
	end;
end;

--Course generation
function courseplay:switchStartingCorner(vehicle)
	local newStartingCorner = vehicle.cp.startingCorner + 1
	if newStartingCorner == courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION and not vehicle.cp.generationPosition.hasSavedPosition then
		-- must have saved position for this, if not, skip it
		newStartingCorner = newStartingCorner + 1
	end
	if newStartingCorner > courseGenerator.STARTING_LOCATION_MAX then
		newStartingCorner = courseGenerator.STARTING_LOCATION_MIN
	end;
	self:setStartingCorner( vehicle, newStartingCorner )
end

function courseplay:setStartingCorner( vehicle, newStartingCorner )
	vehicle.cp.startingCorner = newStartingCorner
	vehicle.cp.hasStartingCorner = true;
	if vehicle.cp.isNewCourseGenSelected() then
		-- starting direction is always auto when starting corner is vehicle location
		vehicle.cp.hasStartingDirection = true;
		vehicle.cp.startingDirection = vehicle.cp.rowDirectionMode
		courseplay:changeHeadlandNumLanes(vehicle, 0)
	else
		vehicle:setCpVar('hasStartingDirection',false,courseplay.isClient);
		vehicle:setCpVar('startingDirection',0,courseplay.isClient);
		courseplay:changeHeadlandNumLanes(vehicle, 0)
	end
	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:setRowDirectionMode( vehicle, newRowDirectionMode )
	vehicle:setCpVar('rowDirectionMode', newRowDirectionMode, courseplay.isClient);
	vehicle:setCpVar('startingDirection', newRowDirectionMode, courseplay.isClient);
end

function courseplay:changeRowAngle( vehicle, changeBy )
	if vehicle.cp.startingDirection == courseGenerator.ROW_DIRECTION_MANUAL then
		vehicle.cp.rowDirectionDeg = ( vehicle.cp.rowDirectionDeg + changeBy ) % 360
	end 
end
	
function courseplay:changeStartingDirection(vehicle)
	-- corners: 1 = SW, 2 = NW, 3 = NE, 4 = SE, 5 = Vehicle location, 6 = Last vehicle location
	-- directions: 1 = North, 2 = East, 3 = South, 4 = West, 5 = auto generated, see courseGenerator.ROW_DIRECTION*
	local clockwise = true
	if vehicle.cp.hasStartingCorner then
		if vehicle.cp.isNewCourseGenSelected() then -- Vehicle location
			if vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_AUTOMATIC then
				vehicle:setCpVar('rowDirectionMode', courseGenerator.ROW_DIRECTION_LONGEST_EDGE, courseplay.isClient);
			elseif vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_LONGEST_EDGE then
				vehicle:setCpVar('rowDirectionMode', courseGenerator.ROW_DIRECTION_MANUAL, courseplay.isClient);
			else  
				vehicle:setCpVar('rowDirectionMode', courseGenerator.ROW_DIRECTION_AUTOMATIC, courseplay.isClient);
			end
			vehicle:setCpVar('startingDirection', vehicle.cp.rowDirectionMode, courseplay.isClient);
		else
			-- legacy course generator
			local validDirections = {};
			if vehicle.cp.startingCorner == 1 then --SW
				validDirections[1] = 1; --N
				validDirections[2] = 2; --E
			elseif vehicle.cp.startingCorner == 2 then --NW
				validDirections[1] = 2; --E
				validDirections[2] = 3; --S
			elseif vehicle.cp.startingCorner == 3 then --NE
				validDirections[1] = 3; --S
				validDirections[2] = 4; --W
			elseif vehicle.cp.startingCorner == 4 then --SE
				validDirections[1] = 4; --W
				validDirections[2] = 1; --N
			end;
			--would be easier with i=i+1, but more stored variables would be needed
			if vehicle.cp.startingDirection == 0 then
				vehicle:setCpVar('startingDirection',validDirections[1],courseplay.isClient);
			elseif vehicle.cp.startingDirection == validDirections[1] then
				vehicle:setCpVar('startingDirection',validDirections[2],courseplay.isClient);
				clockwise = false
			elseif vehicle.cp.startingDirection == validDirections[2] then
				vehicle:setCpVar('startingDirection',validDirections[1],courseplay.isClient);
			end;
		end
		vehicle:setCpVar('hasStartingDirection',true,courseplay.isClient);
	end;
	if vehicle.cp.headland.userDirClockwise ~= clockwise then
		courseplay:toggleHeadlandDirection(vehicle)
	end
	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:toggleReturnToFirstPoint(vehicle)
	-- TODO refactor the HUD to enable calling non-courseplay functions (pass in object)
	vehicle.cp.settings.returnToFirstPoint:toggle()
end;

function courseplay:changeHeadlandNumLanes(vehicle, changeBy)
	vehicle.cp.headland.numLanes = MathUtil.clamp(vehicle.cp.headland.numLanes + changeBy,
		vehicle.cp.headland.getMinNumLanes(), vehicle.cp.headland.getMaxNumLanes());
	if vehicle.cp.headland.numLanes < 0 then
		vehicle.cp.headland.mode = courseGenerator.HEADLAND_MODE_NARROW_FIELD
	elseif vehicle.cp.headland.numLanes == 0 then
		vehicle.cp.headland.mode = courseGenerator.HEADLAND_MODE_NONE
	else
		vehicle.cp.headland.mode = courseGenerator.HEADLAND_MODE_NORMAL
	end
	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:toggleHeadlandDirection(vehicle)
	vehicle.cp.headland.userDirClockwise = not vehicle.cp.headland.userDirClockwise;
	vehicle.cp.headland.directionButton:setSpriteSectionUVs(vehicle.cp.headland.userDirClockwise and 'headlandDirCW' or 'headlandDirCCW');
end;

function courseplay:toggleHeadlandOrder(vehicle)
	vehicle.cp.headland.orderBefore = not vehicle.cp.headland.orderBefore;
	--vehicle.cp.headland.orderButton:setSpriteSectionUVs(vehicle.cp.headland.orderBefore and 'headlandOrdBef' or 'headlandOrdAft');
	-- courseplay:debug(string.format('toggleHeadlandOrder(): orderBefore=%s -> set to %q, setOverlay(orderButton, %d)', tostring(not vehicle.cp.headland.orderBefore), tostring(vehicle.cp.headland.orderBefore), vehicle.cp.headland.orderBefore and 1 or 2), 7);
end;

function courseplay:changeIslandBypassMode(vehicle)
	vehicle.cp.courseGeneratorSettings.islandBypassMode = vehicle.cp.courseGeneratorSettings.islandBypassMode + 1
	if vehicle.cp.courseGeneratorSettings.islandBypassMode > Island.BYPASS_MODE_MAX then
		vehicle.cp.courseGeneratorSettings.islandBypassMode = Island.BYPASS_MODE_MIN
	end
end;

function courseplay:changeHeadlandTurnType( vehicle )
  if vehicle.cp.headland.exists() then
    local newTurnType = vehicle.cp.headland.turnType + 1
    if newTurnType > courseplay.HEADLAND_CORNER_TYPE_MAX then
      newTurnType = courseplay.HEADLAND_CORNER_TYPE_MIN
    end
	vehicle:setCpVar('headland.turnType',newTurnType,courseplay.isClient)
	end
end

function courseplay:changeHeadlandReverseManeuverType( vehicle )
		vehicle.cp.headland.reverseManeuverType = vehicle.cp.headland.reverseManeuverType + 1
		if vehicle.cp.headland.reverseManeuverType > courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_MAX then
			vehicle.cp.headland.reverseManeuverType = courseplay.HEADLAND_REVERSE_MANEUVER_TYPE_MIN
		end
end

function courseplay:changeByMultiTools(vehicle, changeBy)
	courseplay:setMultiTools(vehicle, MathUtil.clamp(vehicle.cp.multiTools + changeBy, 1, 8))
end;
function courseplay:setMultiTools(vehicle, set)
	vehicle:setCpVar('multiTools',set,courseplay.isClient)
	if vehicle.cp.multiTools%2 == 0 then
		courseplay:changeLaneNumber(vehicle, 1)
	else
		courseplay:changeLaneNumber(vehicle, 0, true)
	end;
end;

function courseplay:validateCourseGenerationData(vehicle)
	local numWaypoints = 0;
	if vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
		numWaypoints = #(courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points);
	elseif vehicle.Waypoints ~= nil then
		numWaypoints = #(vehicle.Waypoints);
	end;

	local hasEnoughWaypoints = numWaypoints >= 4
	if vehicle.cp.headland.exists() then
		hasEnoughWaypoints = numWaypoints >= 20;
	end;

	if (vehicle.cp.fieldEdge.selectedField.fieldNum > 0 or not vehicle.cp.hasGeneratedCourse)
	and hasEnoughWaypoints
	and vehicle.cp.hasStartingCorner == true 
	and vehicle.cp.hasStartingDirection == true 
	and (vehicle.cp.numCourses == nil or (vehicle.cp.numCourses ~= nil and vehicle.cp.numCourses == 1) or vehicle.cp.fieldEdge.selectedField.fieldNum > 0) 
	then
		vehicle.cp.hasValidCourseGenerationData = true;
	else
		vehicle.cp.hasValidCourseGenerationData = false;
	end;
	--courseplay.buttons:setActiveEnabled(vehicle, 'generateCourse');

	if courseplay.debugChannels[7] then
		courseplay:debug(string.format("%s: hasGeneratedCourse=%s, hasEnoughWaypoints=%s, hasStartingCorner=%s, hasStartingDirection=%s, numCourses=%s, fieldEdge.selectedField.fieldNum=%s ==> hasValidCourseGenerationData=%s", nameNum(vehicle), tostring(vehicle.cp.hasGeneratedCourse), tostring(hasEnoughWaypoints), tostring(vehicle.cp.hasStartingCorner), tostring(vehicle.cp.hasStartingDirection), tostring(vehicle.cp.numCourses), tostring(vehicle.cp.fieldEdge.selectedField.fieldNum), tostring(vehicle.cp.hasValidCourseGenerationData)), 7);
	end;
end;

function courseplay:validateCanSwitchMode(vehicle)
	vehicle:setCpVar('canSwitchMode', not vehicle:getIsCourseplayDriving() and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and not vehicle.cp.fieldEdge.customField.isCreated,courseplay.isClient);
	if courseplay.debugChannels[12] then
		courseplay:debug(('%s: validateCanSwitchMode(): isDriving=%s, isRecording=%s, recordingIsPaused=%s, customField.isCreated=%s ==> canSwitchMode=%s'):format(nameNum(vehicle), tostring(vehicle:getIsCourseplayDriving()), tostring(vehicle.cp.isRecording), tostring(vehicle.cp.recordingIsPaused), tostring(vehicle.cp.fieldEdge.customField.isCreated), tostring(vehicle.cp.canSwitchMode)), 12);
	end;
end;

function courseplay:saveShovelPosition(vehicle, stage)
	if stage == nil then return; end;

	courseplay:debug(('%s: saveShovelPosition(..., %s)'):format(nameNum(vehicle), tostring(stage)), 10);
	if stage >= 2 and stage <= 5 then
		if vehicle.cp.shovelStatePositions[stage] ~= nil then
			vehicle.cp.shovelStatePositions[stage] = nil;
		else
			local mt, secondary = courseplay:getMovingTools(vehicle);
			local curRot, curTrans = courseplay:getCurrentMovingToolsPosition(vehicle, mt, secondary);
			--courseplay:debug(tableShow(curRot, ('saveShovelPosition(%q, %d) curRot'):format(nameNum(vehicle), stage), 10), 10);
			--courseplay:debug(tableShow(curTrans, ('saveShovelPosition(%q, %d) curTrans'):format(nameNum(vehicle), stage), 10), 10);
			if curRot and next(curRot) ~= nil and curTrans and next(curTrans) ~= nil then
				vehicle.cp.shovelStatePositions[stage] = {
					rot = curRot,
					trans = curTrans
				};
			end;
		end;
		vehicle.cp.hasShovelStatePositions[stage] = vehicle.cp.shovelStatePositions[stage] ~= nil;
		courseplay:debug('    hasShovelStatePositions=' .. tostring(vehicle.cp.hasShovelStatePositions[stage]), 10);

	end;
	--courseplay.buttons:setActiveEnabled(vehicle, 'shovel');
end;

function courseplay:moveShovelToPosition(vehicle, stage)
	courseplay:debug(('%s: moveShovelToPosition(..., %s)'):format(nameNum(vehicle), tostring(stage)), 10);
	if not stage or not vehicle.cp.hasShovelStatePositions[stage] or not courseplay:getIsEngineReady(vehicle) then
		courseplay:debug(('    return (hasShovelStatePositions=%s)'):format(tostring(vehicle.cp.hasShovelStatePositions[stage])), 10);
		return;
	end;

	local mtPrimary, mtSecondary = courseplay:getMovingTools(vehicle);
	if mtPrimary then
		vehicle.cp.manualShovelPositionOrder = stage;
		vehicle.cp.movingToolsPrimary, vehicle.cp.movingToolsSecondary = mtPrimary, mtSecondary;
		courseplay:setCustomTimer(vehicle, 'manualShovelPositionOrder', 12); -- backup timer: if position hasn't been set within time frame, abort
	else
		courseplay:debug(('    movingToolsPrimary=%s, movingToolsSecondary=%s -> abort'):format(tostring(mtPrimary), tostring(mtSecondary)), 10);
	end;
end;

function courseplay:resetManualShovelPositionOrder(vehicle)
	courseplay:debug(('%s: resetManualShovelPositionOrder()'):format(nameNum(vehicle)), 10);
	vehicle.cp.manualShovelPositionOrder = nil;
	vehicle.cp.movingToolsPrimary, vehicle.cp.movingToolsSecondary = nil, nil;
	courseplay:resetCustomTimer(vehicle, 'manualShovelPositionOrder');
end;

function courseplay:movePipeToPosition(vehicle,pos)
	--print(string.format("%s: movePipeToPosition %s",tostring(vehicle.name),tostring(pos)))
	vehicle.cp.manualPipePositionOrder = pos
	courseplay:setCustomTimer(vehicle, 'manualPipePositionOrder', 12); -- backup timer: if position hasn't been set within time frame, abort
end


function courseplay:resetManualPipePositionOrder(vehicle)
	vehicle.cp.manualPipePositionOrder = nil;
	courseplay:resetCustomTimer(vehicle, 'manualPipePositionOrder');
end

function courseplay:toggleShovelStopAndGo(vehicle)
	vehicle.cp.shovelStopAndGo = not vehicle.cp.shovelStopAndGo;
end;

function courseplay:changeStartAtPoint(vehicle)
	vehicle.cp.settings.startingPoint:next()
end;

function courseplay:reloadCoursesFromXML(vehicle)
	courseplay:debug("reloadCoursesFromXML()", 8);
	if g_server ~= nil then
		courseplay.courses:loadCoursesAndFoldersFromXml();

		--courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		courseplay:debug("g_currentMission.cp_courses = courseplay.courses:loadCoursesAndFoldersFromXml()", 8);
		if not vehicle:getIsCourseplayDriving() then
			local loadedCoursesBackup = vehicle.cp.loadedCourses;
			courseplay:clearCurrentLoadedCourse(vehicle);
			vehicle.cp.loadedCourses = loadedCoursesBackup;
			courseplay:reloadCourses(vehicle, true);
		end;
		courseplay.settings.update_folders()
		courseplay.settings.setReloadCourseItems()
		--courseplay.hud.reloadCourses()
	end
end;

function courseplay:setMouseCursor(self, show)
	self.cp.mouseCursorActive = show;
	g_inputBinding:setShowMouseCursor(show);

	--Cameras: deactivate/reactivate zoom function in order to allow CP mouse wheel
	for camIndex,_ in pairs(self.cp.camerasBackup) do
		self.spec_enterable.cameras[camIndex].allowTranslation = not show;
		--print(string.format("%s: right mouse key (mouse cursor=%s): camera %d allowTranslation=%s", nameNum(self), tostring(self.cp.mouseCursorActive), camIndex, tostring(self.cameras[camIndex].allowTranslation)));
	end;

	if not show then
		for i,button in pairs(self.cp.buttons.global) do
			button:setHovered(false);
		end;
		for i,button in pairs(self.cp.buttons[self.cp.hud.currentPage]) do
			button:setHovered(false);
		end;
		if self.cp.hud.currentPage == 2 then
			for i,button in pairs(self.cp.buttons[-2]) do
				button:setHovered(false);
			end;
		end;

		for line=1,courseplay.hud.numLines do
			self.cp.hud.content.pages[self.cp.hud.currentPage][line][1].isHovered = false;
		end;

		courseplay.buttons:setHoveredButton(self, nil);

		self.cp.hud.mouseWheel.render = false;
	end;
end;

function courseplay:changeDebugChannelSection(vehicle, changeBy)
	courseplay.debugChannelSection = MathUtil.clamp(courseplay.debugChannelSection + changeBy, 1, ceil(courseplay.numAvailableDebugChannels / courseplay.numDebugChannelButtonsPerLine));
	courseplay.debugChannelSectionEnd = courseplay.numDebugChannelButtonsPerLine * courseplay.debugChannelSection;
	courseplay.debugChannelSectionStart = courseplay.debugChannelSectionEnd - courseplay.numDebugChannelButtonsPerLine + 1;


	-- update buttons' functions, toolTips and disabled status
	for channel = courseplay.debugChannelSectionStart, courseplay.debugChannelSectionEnd do
		local col = ((channel-1) % courseplay.numDebugChannelButtonsPerLine) + 1;
		local button = vehicle.cp.hud.debugChannelButtons[col];
		button:setParameter(channel);
		button:setToolTip(courseplay.debugChannelsDesc[channel]);
	end;
	
	--courseplay.buttons:setActiveEnabled(vehicle, 'debug');
end;

function courseplay:toggleSymmetricLaneChange(vehicle)
	vehicle.cp.settings.symmetricLaneChange:toggle()
end;

function courseplay:toggleDriverPriority(combine)
	if combine.cp.driverPriorityUseFillLevel == nil then combine.cp.driverPriorityUseFillLevel = false; end;
	combine.cp.driverPriorityUseFillLevel = not combine.cp.driverPriorityUseFillLevel;
end;

function courseplay:toggleStopWhenUnloading(combine)
	if combine.cp.isChopper then
		combine.cp.stopWhenUnloading = false;
		return;
	end;
	if combine.cp.stopWhenUnloading == nil then combine.cp.stopWhenUnloading = false; end;
	combine.cp.stopWhenUnloading = not combine.cp.stopWhenUnloading;
end;

function courseplay:goToVehicle(curVehicle, targetVehicle)
	-- print(string.format("%s: goToVehicle(): targetVehicle=%q", nameNum(curVehicle), nameNum(targetVehicle)));
	g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(targetVehicle, g_currentMission.missionInfo.playerStyle, g_currentMission.player.ownerFarmId));
	g_currentMission.isPlayerFrozen = false;
	CpManager.playerOnFootMouseEnabled = false;
	g_inputBinding:setShowMouseCursor(targetVehicle.cp.mouseCursorActive);
end;



--FIELD EDGE PATHS
function courseplay:createFieldEdgeButtons(vehicle)
	if not vehicle.cp.fieldEdge.selectedField.buttonsCreated and courseplay.fields.numAvailableFields > 0 then
		local w, h = courseplay.hud.buttonSize.small.w, courseplay.hud.buttonSize.small.h;
		local mouseWheelArea = {
			x = courseplay.hud.contentMinX,
			w = courseplay.hud.contentMaxWidth,
			h = courseplay.hud.lineHeight
		};
		vehicle.cp.suc.toggleHudButton = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'calculator' }, 'toggleSucHud', nil, courseplay.hud.buttonPosX[4], courseplay.hud.linesButtonPosY[1], w, h, 1, nil, false, false, true);
		vehicle.cp.hud.showSelectedFieldEdgePathButton = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'eye' }, 'toggleSelectedFieldEdgePathShow', nil, courseplay.hud.buttonPosX[3], courseplay.hud.linesButtonPosY[1], w, h, 1, nil, false);
		courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navUp' }, 'setFieldEdgePath',  1, courseplay.hud.buttonPosX[1], courseplay.hud.linesButtonPosY[1], w, h, 1,  5, false);
		courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navDown' }, 'setFieldEdgePath', -1, courseplay.hud.buttonPosX[2], courseplay.hud.linesButtonPosY[1], w, h, 1, -5, false);
		courseplay.button:new(vehicle, 8, nil, 'setFieldEdgePath', 1, mouseWheelArea.x, courseplay.hud.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 5, true, true);
		vehicle.cp.fieldEdge.selectedField.buttonsCreated = true;
	end;
end;

function courseplay:setFieldEdgePath(vehicle, changeDir, force)
	local newFieldNum = force or vehicle.cp.fieldEdge.selectedField.fieldNum + changeDir;
	if newFieldNum == 0 then
		vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;
		if vehicle.cp.suc.active then
			courseplay:toggleSucHud(vehicle);
		end;
		return;
	end;
	while courseplay.fields.fieldData[newFieldNum] == nil do
		if newFieldNum == 0 then
			vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;
			if vehicle.cp.suc.active then
				courseplay:toggleSucHud(vehicle);
			end;
			return;
		end;
		newFieldNum = MathUtil.clamp(newFieldNum + changeDir, 0, courseplay.fields.numAvailableFields);
	end;

	vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;

	if newFieldNum == 0 and vehicle.cp.suc.active then
		courseplay:toggleSucHud(vehicle);
	end;

	--courseplay:toggleSelectedFieldEdgePathShow(vehicle, false);
	if vehicle.cp.fieldEdge.customField.show then
		courseplay:toggleCustomFieldEdgePathShow(vehicle, false);
	end;
	
	courseplay:validateCourseGenerationData(vehicle);
end;

function courseplay:toggleSelectedFieldEdgePathShow(vehicle, force)
	vehicle.cp.fieldEdge.selectedField.show = Utils.getNoNil(force, not vehicle.cp.fieldEdge.selectedField.show);
	--print(string.format("%s: selectedField.show=%s", nameNum(vehicle), tostring(vehicle.cp.fieldEdge.selectedField.show)));
	--courseplay.buttons:setActiveEnabled(vehicle, "selectedFieldShow");
end;

--CUSTOM SINGLE FIELD EDGE PATH
function courseplay:setCustomSingleFieldEdge(vehicle)
	--print(string.format("%s: call setCustomSingleFieldEdge()", nameNum(vehicle)));

	local x,y,z = getWorldTranslation(vehicle.rootNode);
	local isField = x and z and courseplay:isField(x, z, 0, 0); --TODO: use width/height of 0.1 ?
	courseplay.fields:dbg(string.format("Custom field scan: x,z=%.1f,%.1f, isField=%s", x, z, tostring(isField)), 'customLoad');
	vehicle.cp.fieldEdge.customField.points = nil;
	if isField then
		local edgePoints = courseplay.fields:setSingleFieldEdgePath(vehicle.rootNode, x, z, courseplay.fields.scanStep, 2000, 10, nil, true, 'customLoad');
		vehicle.cp.fieldEdge.customField.points = edgePoints;
		vehicle.cp.fieldEdge.customField.numPoints = edgePoints ~= nil and #edgePoints or 0;
	end;

	--print(tableShow(vehicle.cp.fieldEdge.customField.points, nameNum(vehicle) .. " fieldEdge.customField.points"));
	vehicle.cp.fieldEdge.customField.isCreated = vehicle.cp.fieldEdge.customField.points ~= nil;
	courseplay:toggleCustomFieldEdgePathShow(vehicle, vehicle.cp.fieldEdge.customField.isCreated);
	courseplay:validateCanSwitchMode(vehicle);
end;

function courseplay:clearCustomFieldEdge(vehicle)
	vehicle.cp.fieldEdge.customField.points = nil;
	vehicle.cp.fieldEdge.customField.numPoints = 0;
	vehicle.cp.fieldEdge.customField.isCreated = false;
	courseplay:setCustomFieldEdgePathNumber(vehicle, nil, 0);
	courseplay:toggleCustomFieldEdgePathShow(vehicle, false);
	courseplay:validateCanSwitchMode(vehicle);
end;

function courseplay:toggleCustomFieldEdgePathShow(vehicle, force)
	vehicle.cp.fieldEdge.customField.show = Utils.getNoNil(force, not vehicle.cp.fieldEdge.customField.show);
	--print(string.format("%s: customField.show=%s", nameNum(vehicle), tostring(vehicle.cp.fieldEdge.customField.show)));
	--courseplay.buttons:setActiveEnabled(vehicle, "customFieldShow");
end;

function courseplay:setCustomFieldEdgePathNumber(vehicle, changeBy, force)
	vehicle.cp.fieldEdge.customField.fieldNum = force or MathUtil.clamp(vehicle.cp.fieldEdge.customField.fieldNum + changeBy, 0, courseplay.fields.customFieldMaxNum);
	vehicle.cp.fieldEdge.customField.selectedFieldNumExists = courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum] ~= nil;
	--print(string.format("%s: customField.fieldNum=%d, selectedFieldNumExists=%s", nameNum(vehicle), vehicle.cp.fieldEdge.customField.fieldNum, tostring(vehicle.cp.fieldEdge.customField.selectedFieldNumExists)));
end;

function courseplay:addCustomSingleFieldEdgeToList(vehicle)
	--print(string.format("%s: call addCustomSingleFieldEdgeToList()", nameNum(vehicle)));
	local data = {
		fieldNum = vehicle.cp.fieldEdge.customField.fieldNum;
		points = vehicle.cp.fieldEdge.customField.points;
		numPoints = vehicle.cp.fieldEdge.customField.numPoints;
		name = string.format("%s %d (%s)", courseplay:loc('COURSEPLAY_FIELD'), vehicle.cp.fieldEdge.customField.fieldNum, courseplay:loc('COURSEPLAY_USER'));
		isCustom = true;
	};
	local area, _, dimensions = courseplay.fields:getPolygonData(data.points, nil, nil, true);
	data.areaSqm = area;
	data.areaHa = area / 10000;
	data.dimensions = dimensions;
	data.fieldAreaText = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR_FIELD'):format(data.fieldNum, courseplay.fields:formatNumber(data.areaHa, 2), g_i18n:getText('unit_ha'));
	data.seedUsage, data.seedPrice, data.seedDataText = courseplay.fields:getFruitData(area);

	courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum] = data;
	courseplay.fields.numAvailableFields = table.maxn(courseplay.fields.fieldData);

	--print(string.format("\tfieldNum=%d, name=%s, #points=%d", courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum].fieldNum, courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum].name, #courseplay.fields.fieldData[vehicle.cp.fieldEdge.customField.fieldNum].points));

	--RESET
	courseplay:setCustomFieldEdgePathNumber(vehicle, nil, 0);
	courseplay:clearCustomFieldEdge(vehicle);
	courseplay:toggleSelectedFieldEdgePathShow(vehicle, false);
	--print(string.format("\t[AFTER RESET] fieldNum=%d, points=%s, fieldEdge.customField.isCreated=%s", vehicle.cp.fieldEdge.customField.fieldNum, tostring(vehicle.cp.fieldEdge.customField.points), tostring(vehicle.cp.fieldEdge.customField.isCreated)));
end;

function courseplay:showFieldEdgePath(vehicle, pathType)
	local points, numPoints = nil, 0;
	if pathType == "customField" then
		points = vehicle.cp.fieldEdge.customField.points;
		numPoints = vehicle.cp.fieldEdge.customField.numPoints;
	elseif pathType == "selectedField" then
		points = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].points;
		numPoints = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].numPoints;
	end;

	if numPoints > 0 then
		local pointHeight = 3;
		for i,point in pairs(points) do
			if i < numPoints then
				local nextPoint = points[i + 1];
				cpDebug:drawLine(point.cx,point.cy+pointHeight,point.cz, 0,0,1, nextPoint.cx,nextPoint.cy+pointHeight,nextPoint.cz);

				if i == 1 then
					cpDebug:drawPoint(point.cx, point.cy + pointHeight, point.cz, 0,1,0);
				else
					cpDebug:drawPoint(point.cx, point.cy + pointHeight, point.cz, 1,1,0);
				end;
			else
				cpDebug:drawPoint(point.cx, point.cy + pointHeight, point.cz, 1,0,0);
			end;
		end;
	end;
end;

function courseplay:changeDrawCourseMode(vehicle, changeBy)
	vehicle.cp.drawCourseMode = courseplay:varLoop(vehicle.cp.drawCourseMode, changeBy, courseplay.COURSE_2D_DISPLAY_BOTH, courseplay.COURSE_2D_DISPLAY_OFF);
	vehicle.cp.hud.changeDrawCourseModeButton:setActive(vehicle.cp.drawCourseMode ~= courseplay.COURSE_2D_DISPLAY_OFF);
end;

function courseplay:setEngineState(vehicle, on)
	if vehicle == nil or on == nil or vehicle.spec_motorized.isMotorStarted == on then
		return;
	end;

	-- driveControl engine start/stop
	if vehicle.cp.hasDriveControl and vehicle.cp.driveControl.hasManualMotorStart then
		local changed = false;
		if on and not vehicle.driveControl.manMotorStart.isMotorStarted then
			vehicle.driveControl.manMotorStart.isMotorStarted = true; -- TODO: timer (800 ms) instead of immediate starting
			changed = true;
		elseif not on and vehicle.driveControl.manMotorStart.isMotorStarted and not vehicle.cp.driveControl.hasMotorKeepTurnedOn then
			vehicle.driveControl.manMotorStart.isMotorStarted = false;
			changed = true;
		end;
		if changed and driveControlInputEvent ~= nil then
			driveControlInputEvent.sendEvent(vehicle);
		end;
		return;
	end;

	-- default
	if vehicle.startMotor and vehicle.stopMotor then
		if on then
			vehicle:startMotor();
		else
			vehicle.lastAcceleration = 0;
			vehicle:stopMotor();
		end;
	end;
end;

function courseplay:setCurrentTargetFromList(vehicle, index)
	if #vehicle.cp.nextTargets == 0 then return; end;
	index = index or 1;

	vehicle.cp.curTarget = vehicle.cp.nextTargets[index];
	if index == 1 then
		table.remove(vehicle.cp.nextTargets, 1);
		return;
	end;

	for i=index,1,-1 do
		table.remove(vehicle.cp.nextTargets, i);
	end;
end;

function courseplay:addNewTargetVector(vehicle, x, z, trailer,node,rev)
	local tx, ty, tz = 0,0,0
	local pointReverse = false
	if node ~= nil then
		tx, ty, tz = localToWorld(node, x, 0, z);
	elseif trailer ~= nil then
		tx, ty, tz = localToWorld(trailer.rootNode, x, 0, z);
	else
		tx, ty, tz = localToWorld(vehicle.cp.directionNode or vehicle.rootNode, x, 0, z);
	end
	if rev then
		pointReverse = true
	end
	table.insert(vehicle.cp.nextTargets, { x = tx, y = ty, z = tz,rev = pointReverse });
end;

function courseplay:changeRefillUntilPct(vehicle, changeBy)
	vehicle.cp.refillUntilPct = MathUtil.clamp(vehicle.cp.refillUntilPct + changeBy, 1, 100);
end;

function courseplay:changeLastValidTipDistance(vehicle, changeBy)
	vehicle.cp.lastValidTipDistance = MathUtil.clamp(vehicle.cp.lastValidTipDistance + changeBy, -500, 0);
end;

function courseplay:changemaxRunNumber(vehicle, changeBy)
 	vehicle.cp.maxRunNumber = MathUtil.clamp(vehicle.cp.maxRunNumber + changeBy, 1, 10);
end;

function courseplay:toggleRunCounterActive(vehicle, changeBy)
 	vehicle.cp.runCounterActive = not vehicle.cp.runCounterActive;
end;

function courseplay:resetRunCounter(vehicle)
	vehicle.cp.driver:resetRunCounter()
end

function courseplay:toggleSucHud(vehicle)
	vehicle.cp.suc.active = not vehicle.cp.suc.active;
	---courseplay.buttons:setActiveEnabled(vehicle, 'suc');
	if vehicle.cp.suc.selectedFruit == nil then
		vehicle.cp.suc.selectedFruitIdx = 1;
		vehicle.cp.suc.selectedFruit = courseplay.fields.seedUsageCalculator.fruitTypes[1];
	end;
end;

function courseplay:sucChangeFruit(vehicle, change)
	local newIdx = vehicle.cp.suc.selectedFruitIdx + change;
	if newIdx > courseplay.fields.seedUsageCalculator.numFruits then
		newIdx = newIdx - courseplay.fields.seedUsageCalculator.numFruits;
	elseif newIdx < 1 then
		newIdx = courseplay.fields.seedUsageCalculator.numFruits - newIdx;
	end;
	vehicle.cp.suc.selectedFruitIdx = newIdx;
	vehicle.cp.suc.selectedFruit = courseplay.fields.seedUsageCalculator.fruitTypes[vehicle.cp.suc.selectedFruitIdx];
end;

function courseplay:toggleFindFirstWaypoint(vehicle)
	vehicle:setCpVar('distanceCheck',not vehicle.cp.distanceCheck,courseplay.isClient);
	if not courseplay.isClient and not vehicle.cp.distanceCheck then
		courseplay:setInfoText(vehicle, nil);
	end;
	--courseplay.buttons:setActiveEnabled(vehicle, 'findFirstWaypoint');
end;

function courseplay:canUseWeightStation(vehicle)
	return vehicle.cp.mode == 1 or vehicle.cp.mode == 2 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 8;
end;

function courseplay:canScanForWeightStation(vehicle)
	local scan = false;
	if vehicle.cp.mode == 1 or vehicle.cp.mode == 2 then
		scan = vehicle.cp.waypointIndex > 2;
	elseif vehicle.cp.mode == 4 or vehicle.cp.mode == 6 then
		scan = vehicle.cp.stopWork ~= nil and vehicle.cp.waypointIndex > vehicle.cp.stopWork;
	elseif vehicle.cp.mode == 8 then
		scan = true;
	end;

	return scan;
end;

function courseplay:setSlippingStage(vehicle, stage)
	if vehicle.cp.slippingStage ~= stage then
		courseplay:debug(('%s: setSlippingStage(..., %d)'):format(nameNum(vehicle), stage), 14);
		vehicle.cp.slippingStage = stage;
	end;
end;

-- INGAME MAP ICONS

function courseplay:getMapHotspotText(vehicle)
	local text = '';
	if CpManager.ingameMapIconShowText then
		if CpManager.ingameMapIconShowName then
			text = nameNum(vehicle, true) .. '\n';
		end;
		if CpManager.ingameMapIconShowCourse then
			text = text .. ('(%s)'):format(vehicle.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE'));
		end;
	end
	return text
end


function courseplay:createMapHotspot(vehicle)
	if vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING then
		return
	end
	--[[
	local hotspotX, _, hotspotZ = getWorldTranslation(vehicle.rootNode);
	local _, textSize = getNormalizedScreenValues(0, 6);
	local _, textOffsetY = getNormalizedScreenValues(0, 9.5);
	local width, height = getNormalizedScreenValues(11,11);
]]
	local hotspotX, _, hotspotZ = getWorldTranslation(vehicle.rootNode)
	local _, textSize = getNormalizedScreenValues(0, 9)
	local _, textOffsetY = getNormalizedScreenValues(0, 18)
	local width, height = getNormalizedScreenValues(24, 24)
	vehicle.cp.mapHotspot = MapHotspot:new("cpHelper", MapHotspot.CATEGORY_AI)
	vehicle.cp.mapHotspot:setSize(width, height)
	vehicle.cp.mapHotspot:setLinkedNode(vehicle.components[1].node)											-- objectId to what the hotspot is attached to
	vehicle.cp.mapHotspot:setText('CP\n' .. courseplay:getMapHotspotText(vehicle))
	vehicle.cp.mapHotspot:setImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER), {0.052, 0.1248, 0.672, 1})
	vehicle.cp.mapHotspot:setBackgroundImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER))
	vehicle.cp.mapHotspot:setIconScale(0.7)
	vehicle.cp.mapHotspot:setTextOptions(textSize, nil, textOffsetY, {1, 1, 1, 1}, Overlay.ALIGN_VERTICAL_MIDDLE)
	vehicle.cp.mapHotspot:setColor(Utils.getNoNil(courseplay.hud.ingameMapIconsUVs[vehicle.cp.mode], courseplay.hud.ingameMapIconsUVs[courseplay.MODE_GRAIN_TRANSPORT]))
	g_currentMission:addMapHotspot(vehicle.cp.mapHotspot)


	--[[ FS17 doc, left here for later reference only
		"cpHelper",                                 -- name: 				mapHotspot Name
		"CP\n"..name,                               -- fullName: 			Text shown in icon
		nil,                                        -- imageFilename:		Image path for custome images (If nil, then it will use Giants default image file)
		getNormalizedUVs({768, 768, 256, 256}),     -- imageUVs:			UVs location of the icon in the image file. Use getNormalizedUVs to get an correct UVs array
		colour,                                     -- baseColor:			What colour to show
		hotspotX,                                   -- xMapPos:				x position of the hotspot on the map
		hotspotZ,                                   -- zMapPos:				z position of the hotspot on the map
		width,                                      -- width:				Image width
		height,                                     -- height:				Image height
		false,                                      -- blinking:			If the hotspot is blinking (Like the icons do, when a great demands is active)
		false,                                      -- persistent:			Do the icon needs to be shown even when outside map ares (Like Greatdemands are shown at the minimap edge if outside the minimap)
		true,                                       -- showName:			Should we show the fullName or not.
		vehicle.components[1].node,                 -- objectId:			objectId to what the hotspot is attached to
		true,                                       -- renderLast:			Does this need to be renderes as one of the last icons
		MapHotspot.CATEGORY_VEHICLE_STEERABLE,      -- category:			The MapHotspot category.
		textSize,                                   -- textSize:			fullName text size. you can use getNormalizedScreenValues(x, y) to get the normalized text size by using the return value of the y.
		textOffsetY,                                -- textOffsetY:			Text offset horizontal
		{1, 1, 1, 1},                               -- textColor:			Text colour (r, g, b, a) in 0-1 format
		nil,                                        -- bgImageFilename:		Image path for custome background images (If nil, then it will use Giants default image file)
		getNormalizedUVs({768, 768, 256, 256}),     -- bgImageUVs:			UVs location of the background icon in the image file. Use getNormalizedUVs to get an correct UVs array
		Overlay.ALIGN_VERTICAL_MIDDLE,              -- verticalAlignment:	The alignment of the image based on the attached node
		0.8                                         -- overlayBgScale:		Background icon scale, like making an border. (smaller is bigger border)
	) ]]
end

function courseplay:deleteMapHotspot(vehicle)
	if vehicle.cp.mapHotspot then
		g_currentMission:removeMapHotspot(vehicle.cp.mapHotspot)
		vehicle.cp.mapHotspot:delete()
		vehicle.cp.mapHotspot = nil
	end
end

function courseplay:toggleIngameMapIconShowText()
	if not CpManager.ingameMapIconShowName and not CpManager.ingameMapIconShowCourse then
		CpManager.ingameMapIconShowName = true;
	elseif CpManager.ingameMapIconShowName and not CpManager.ingameMapIconShowCourse then
		CpManager.ingameMapIconShowCourse = true
	else
		CpManager.ingameMapIconShowName = false;
		CpManager.ingameMapIconShowCourse = false
	end
	--TODO broadcast change to other Multiplayers
	
	-- for _,vehicle in pairs(g_currentMission.enterables) do
	for _,vehicle in pairs(CpManager.activeCoursePlayers) do
		if vehicle.cp.mapHotspot then
			vehicle.cp.mapHotspot:setText('CP\n' .. courseplay:getMapHotspotText(vehicle))
			courseplay.hud:setReloadPageOrder(vehicle, 7, true);
		end;
	end;
end;

function courseplay:changeDriveControlMode(vehicle, changeBy)
	vehicle.cp.driveControl.mode = MathUtil.clamp(vehicle.cp.driveControl.mode + changeBy, vehicle.cp.driveControl.OFF, vehicle.cp.driveControl.AWD_BOTH_DIFF);
end;

function courseplay:getAndSetFixedWorldPosition(object, recursive)
	if object.cp.fixedWorldPosition == nil then
		object.cp.fixedWorldPosition = {};
		object.cp.fixedWorldPosition.px, object.cp.fixedWorldPosition.py, object.cp.fixedWorldPosition.pz = getWorldTranslation(object.components[1].node);
		object.cp.fixedWorldPosition.rx, object.cp.fixedWorldPosition.ry, object.cp.fixedWorldPosition.rz = getWorldRotation(object.components[1].node);
	end;
	local fwp = object.cp.fixedWorldPosition;
	object:setWorldPosition(fwp.px,fwp.py,fwp.pz, fwp.rx,fwp.ry,fwp.rz, 1);

	if recursive and object.getAttachedImplements then
		for _,impl in pairs(object:getAttachedImplements()) do
			courseplay:getAndSetFixedWorldPosition(impl.object);
		end;
	end;
end;

function courseplay:deleteFixedWorldPosition(object, recursive)
	object.cp.fixedWorldPosition = nil;

	if recursive and object.getAttachedImplements then
		for _,impl in pairs(object:getAttachedImplements()) do
			courseplay:deleteFixedWorldPosition(impl.object);
		end;
	end;
end;

function courseplay:setAttachedCombine(vehicle)
	--- If vehicle do not have courseplay spec, then skip it.
	if not vehicle.hasCourseplaySpec then
		return
	end

	courseplay:debug(('%s: setAttachedCombine()'):format(nameNum(vehicle)), 6);
	vehicle.cp.attachedCombine = nil;
	if not (vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader) and vehicle.attachedImplements then
		for _,impl in pairs(vehicle:getAttachedImplements()) do
			if impl.object and courseplay:isAttachedCombine(impl.object) then
				vehicle.cp.attachedCombine = impl.object;
				courseplay:debug(('    attachedCombine=%s, attachedCombine .cp=%s'):format(nameNum(impl.object), tostring(impl.object.cp)), 6);
				break;
			end;
		end;
	end;

end;

function courseplay:getIsEngineReady(vehicle)
	return (vehicle.spec_motorized.isMotorStarted or vehicle.cp.saveFuel) and (vehicle.spec_motorized.motorStartTime == nil or vehicle.spec_motorized.motorStartTime < g_currentMission.time);
end;

----------------------------------------------------------------------------------------------------

function courseplay:setCpVar(varName, value, noEventSend)
	local split = StringUtil.splitString(".", varName);
	if #split ==1 then
		if self.cp[varName] ~= value then
			local oldValue = self.cp[varName]; --TODO check whether needed or not
			self.cp[varName] = value;		
			if CpManager.isMP and not noEventSend then
				--print(courseplay.utils:getFnCallPath(2))
				courseplay:debug(string.format("setCpVar: %s: %s -> send Event",varName,tostring(value)), 5);
				CourseplayEvent.sendEvent(self, "self.cp."..varName, value)
			end
			if varName == "isDriving" then
				courseplay:debug("reload page 1", 5);
				courseplay.hud:setReloadPageOrder(self, 1, true);
			elseif varName:sub(1, 3) == 'HUD' then
				-- TODO: using the variable name to trigger a HUD refresh is not a good idea.
				--print('broken settings 1860')
				if StringUtil.startsWith(varName, 'HUD0') then
					courseplay:debug("reload page 0", 5);
					courseplay.hud:setReloadPageOrder(self, 0, true);
				elseif StringUtil.startsWith(varName, 'HUD1') then
					courseplay:debug("reload page 1", 5);
					courseplay.hud:setReloadPageOrder(self, 1, true);
				elseif StringUtil.startsWith(varName, 'HUD4') then
					courseplay:debug("reload page 4", 5);
					courseplay.hud:setReloadPageOrder(self, 4, true);
				end;
			elseif varName == 'waypointIndex' and self.cp.hud.currentPage == courseplay.hud.PAGE_CP_CONTROL and (self.cp.isRecording or self.cp.recordingIsPaused) and value and value == 4 then -- record pause action becomes available
				--courseplay.buttons:setActiveEnabled(self, 'recording');
			end;
		end;
	elseif #split == 2 then
		if self.cp[split[1]][split[2]] ~= value then
			self.cp[split[1]][split[2]] = value
		end
		-- TODO: this is unclear, shouldn't this be only called when the value changed?
		if CpManager.isMP and not noEventSend then
			--print(courseplay.utils:getFnCallPath(2))
			courseplay:debug(string.format("setCpVar: %s: %s -> send Event",varName,tostring(value)), 5);
			CourseplayEvent.sendEvent(self, "self.cp."..varName, value)
		end
	end
end;

---@class Setting
Setting = CpObject()

--- Interface for settings
--- @param name string name of this settings, will be used as an identifier in containers and XML
--- @param label string text ID in translations used as a label for this setting on the GUI
--- @param toolTip string text ID in translations used as a tooltip for this setting on the GUI
--- @param vehicle table vehicle, needed for vehicle specific settings for multiplayer syncs
function Setting:init(name, label, toolTip, vehicle, value)
	self.name = name
	self.label = label
	self.toolTip = toolTip
	self.value = value
	-- Required to send sync events for settings changes
	self.vehicle = vehicle
	self.syncValue = false
	-- override
	self.xmlKey = name
	self.xmlAttribute = '#value'
end

-- Get the current value
function Setting:get()
	return self.value
end

-- Is the current value same as the param?
function Setting:is(value)
	return self.value == value
end

function Setting:equals(value)
	return self.value == value
end

-- Get the current text to be shown on the UI
function Setting:getText()
	return tostring(self.value)
end

function Setting:getLabel()
	return courseplay:loc(self.label)
end

function Setting:getToolTip()
	return courseplay:loc(self.toolTip)
end

-- function only called from network to set synced setting
function Setting:setFromNetwork(value)
	self:set(value)
	self:onChange()
end

function Setting:onWriteStream(stream)
	streamDebugWriteBool(stream, true)
	streamDebugWriteString(stream, self.name)
	-- rest is override
end

--- Set to a specific value
function Setting:set(value)
	self.value = value
end

function Setting:onChange()
	-- setting specific implementation in the derived classes
end

function Setting:getKey(parentKey)
	return parentKey .. '.' .. self.xmlKey .. self.xmlAttribute
end

function Setting:loadFromXml(xml, parentKey)
	-- override
end

function Setting:saveToXml(xml, parentKey)
	-- override
end

---@class FloatSetting
FloatSetting = CpObject(Setting)
--- @param name string name of this settings, will be used as an identifier in containers and XML
--- @param label string text ID in translations used as a label for this setting on the GUI
--- @param toolTip string text ID in translations used as a tooltip for this setting on the GUI
--- @param vehicle table vehicle, needed for vehicle specific settings for multiplayer syncs
function FloatSetting:init(name, label, toolTip, vehicle, value)
	Setting.init(self, name, label, toolTip, vehicle, value)
end

function FloatSetting:loadFromXml(xml, parentKey)
	local value = getXMLFloat(xml, self:getKey(parentKey))
	if value then
		self:set(value)
	end
end

function FloatSetting:saveToXml(xml, parentKey)
	setXMLFloat(xml, self:getKey(parentKey), self:get())
end

---@class SettingList
SettingList = CpObject(Setting)

--- A setting that can have a predefined set of values
--- @param name string name of this settings, will be used as an identifier in containers and XML
--- @param label string text ID in translations used as a label for this setting on the GUI
--- @param toolTip string text ID in translations used as a tooltip for this setting on the GUI
--- @param vehicle table vehicle, needed for vehicle specific settings for multiplayer syncs
--- @param values table with the valid values
--- @param texts string[] name in the translation XML files describing the corresponding value
function SettingList:init(name, label, toolTip, vehicle, values, texts)
	Setting.init(self, name, label, toolTip, vehicle)
	self.values = values
	self.texts = texts
	-- index of the current value/text
	self.current = 1
	-- index of the previous value/text
	self.previous = 1
end

-- Get the current value
function SettingList:get()
	return self.values[self.current]
end

-- Is the current value same as the param?
function SettingList:is(value)
	return self.values[self.current] == value
end

-- Get the current text
function SettingList:getText()
	return courseplay:loc(self.texts[self.current])
end

--- Set the next value
function SettingList:next()
	local new = self:checkAndSetValidValue(self.current + 1)
	self:setToIx(new)
end

-- private function to set to the value at ix
function SettingList:setToIx(ix)
	if ix ~= self.current then
		self.previous = self.current
		self.current = ix
		self:onChange()
		if self.syncValue then
			CourseplaySettingsSyncEvent.sendEvent(self.vehicle, self.name, self.current)
		end
	end
end

-- function only called from network to set synced setting
function SettingList:setFromNetwork(ix)
	if ix ~= self.current then
		self.previous = self.current
		self.current = ix
		self:onChange()
	end
end

--- Set to a specific value
function SettingList:set(value)
	local new
	-- find the value requested
	for i = 1, #self.values do
		if self.values[i] == value then
			new = self:checkAndSetValidValue(i)
			self:setToIx(new)
			return
		end
	end
end

function SettingList:checkAndSetValidValue(new)
	if new > #self.values then
		return 1
	elseif new < 1 then
		return #self.values
	else
		return new
	end
end

function SettingList:onChange()
	-- setting specific implementation in the derived classes
end

--- Helper functions for the case when used with a GUI multi text option element
function SettingList:getGuiElementTexts()
	local texts = {}
	for _, text in ipairs(self.texts) do
		table.insert(texts, courseplay:loc(text))
	end
	return texts
end

function SettingList:getValueFromGuiElementState(state)
	return self.values[state]
end

function SettingList:setGuiElement(element)
	self.guiElement = element
end

function SettingList:getGuiElement()
	return self.guiElement
end

function SettingList:getGuiElementState()
	return self:getGuiElementStateFromValue(self.values[self.current])
end

function SettingList:getGuiElementStateFromValue(value)
	for i = 1, #self.values do
		if self.values[i] == value then
			return i
		end
	end
	return nil
end

function SettingList:getKey(parentKey)
	return parentKey .. '.' .. self.xmlKey .. self.xmlAttribute
end

function SettingList:loadFromXml(xml, parentKey)
	local value = getXMLInt(xml, self:getKey(parentKey))
	if value then
		self:set(value)
	end
end

function SettingList:saveToXml(xml, parentKey)
	setXMLInt(xml, self:getKey(parentKey), self:get())
end

--- Generic boolean setting
---@class BooleanSetting : SettingList
BooleanSetting = CpObject(SettingList)

function BooleanSetting:init(name, label, toolTip, vehicle, texts)
	if not texts then
		texts = {
			'COURSEPLAY_DEACTIVATED',
			'COURSEPLAY_ACTIVATED'
		}
	end
	SettingList.init(self, name, label, toolTip, vehicle,
		{
			false,
			true
		}, texts)
	self.xmlAttribute = '#active'
end

function BooleanSetting:toggle()
	self:set(not self:get())
end

function BooleanSetting:loadFromXml(xml, parentKey)
	local value = getXMLBool(xml, self:getKey(parentKey))
	if value ~= nil then
		self:set(value)
	end
end

function BooleanSetting:saveToXml(xml, parentKey)
	setXMLBool(xml, self:getKey(parentKey), self:get())
end


--- AutoDrive mode setting
---@class AutoDriveModeSetting : SettingList
AutoDriveModeSetting = CpObject(SettingList)

-- How to use AutoDrive
AutoDriveModeSetting.NO_AUTODRIVE			= 0  -- AutoDrive not found
AutoDriveModeSetting.DONT_USE				= 1  -- Don't use AutoDrive
AutoDriveModeSetting.UNLOAD_OR_REFILL 		= 2  -- Use AutoDrive for unload and refill
AutoDriveModeSetting.PARK 					= 3  -- Use AutoDrive to park vehicle after work is done
AutoDriveModeSetting.UNLOAD_OR_REFILL_PARK 	= 4  -- Use AutoDrive for unload and refill and park after work is done

function AutoDriveModeSetting:init(vehicle)
	SettingList.init(self, 'autoDriveMode', 'COURSEPLAY_AUTODRIVE_MODE', '', vehicle,
		{
			AutoDriveModeSetting.DONT_USE,
			AutoDriveModeSetting.UNLOAD_OR_REFILL,
			AutoDriveModeSetting.PARK,
			AutoDriveModeSetting.UNLOAD_OR_REFILL_PARK,
		},
		{
			'COURSEPLAY_AUTODRIVE_DONT_USE',
			'COURSEPLAY_AUTODRIVE_UNLOAD_OR_REFILL',
			'COURSEPLAY_AUTODRIVE_PARK',
			'COURSEPLAY_AUTODRIVE_UNLOAD_OR_REFILL_PARK',
		})
	self:update()
end

function AutoDriveModeSetting:isAutoDriveAvailable()
	return self.vehicle.spec_autodrive and self.vehicle.spec_autodrive.StartDriving
end

function AutoDriveModeSetting:update()
	if self.vehicle.spec_autodrive and self.vehicle.spec_autodrive.GetParkDestination then
		local parkDestination = self.vehicle.spec_autodrive:GetParkDestination(self.vehicle)
		if parkDestination and #self.values == 2 then
			-- add park options when the available
			table.insert(self.values, AutoDriveModeSetting.PARK)
			table.insert(self.values, AutoDriveModeSetting.UNLOAD_OR_REFILL_PARK)
			table.insert(self.texts, 'COURSEPLAY_AUTODRIVE_PARK')
			table.insert(self.texts, 'COURSEPLAY_AUTODRIVE_UNLOAD_OR_REFILL_PARK')
		elseif not parkDestination and #self.values == 4 then
			-- remove park options if they are on our list but are not available
			table.remove(self.values, 3)
			table.remove(self.values, 3)
			table.remove(self.texts, 3)
			table.remove(self.texts, 3)
		end
	end
end

function AutoDriveModeSetting:useForUnloadOrRefill()
	return self:is(AutoDriveModeSetting.UNLOAD_OR_REFILL) or self:is(AutoDriveModeSetting.UNLOAD_OR_REFILL_PARK)
end

function AutoDriveModeSetting:useForParkVehicle()
	return self:is(AutoDriveModeSetting.PARK) or self:is(AutoDriveModeSetting.UNLOAD_OR_REFILL_PARK)
end

--- Starting point setting (at which waypoint should the vehicle start the course)
---@class StartingPointSetting : SettingList
StartingPointSetting = CpObject(SettingList)

StartingPointSetting.START_AT_NEAREST_POINT = 1 -- nearest waypoint regardless of direction
StartingPointSetting.START_AT_FIRST_POINT   = 2 -- first waypoint
StartingPointSetting.START_AT_CURRENT_POINT = 3 -- current waypoint
StartingPointSetting.START_AT_NEXT_POINT    = 4 -- nearest waypoint with approximately same direction as vehicle

function StartingPointSetting:init(vehicle)
	SettingList.init(self, 'startingPoint', 'COURSEPLAY_START_AT_POINT', 'COURSEPLAY_START_AT_POINT', vehicle,
			{
		        StartingPointSetting.START_AT_NEAREST_POINT,
				StartingPointSetting.START_AT_FIRST_POINT  ,
				StartingPointSetting.START_AT_CURRENT_POINT,
				StartingPointSetting.START_AT_NEXT_POINT
			},
			{
				"COURSEPLAY_NEAREST_POINT",
				"COURSEPLAY_FIRST_POINT"  ,
				"COURSEPLAY_CURRENT_POINT",
				"COURSEPLAY_NEXT_POINT"
			})
end

--- Driving mode setting
---@class DrivingModeSetting : SettingList
DrivingModeSetting = CpObject(SettingList)

-- Driving modes
DrivingModeSetting.DRIVING_MODE_NORMAL   = 0  -- legacy
DrivingModeSetting.DRIVING_MODE_PPC      = 1  -- legacy with pure pursuit controller
DrivingModeSetting.DRIVING_MODE_AIDRIVER = 2  -- AI driver

--- Constructor needs a vehicle to be able to check CP mode
function DrivingModeSetting:init(vehicle)
	SettingList.init(self, 'drivingMode', 'COURSEPLAY_DRIVER', '', vehicle,
		{
			DrivingModeSetting.DRIVING_MODE_NORMAL,
			DrivingModeSetting.DRIVING_MODE_PPC,
			DrivingModeSetting.DRIVING_MODE_AIDRIVER
		},
		{
			'COURSEPLAY_PPC_OFF',
			'COURSEPLAY_PPC_ON',
			'COURSEPLAY_AIDRIVER'
		})
	-- make sure the vehicle's settings are in sync
	self:onChange()
end

--- Until not all modes are available with AI Drive, we disable it for those modes
function DrivingModeSetting:checkAndSetValidValue(new)
	if self.vehicle.cp.mode ~= courseplay.MODE_GRAIN_TRANSPORT
		and self.vehicle.cp.mode ~= courseplay.MODE_TRANSPORT
		and self.vehicle.cp.mode ~= courseplay.MODE_SHOVEL_FILL_AND_EMPTY
		and self.vehicle.cp.mode ~= courseplay.MODE_SEED_FERTILIZE
		and self.vehicle.cp.mode ~= courseplay.MODE_FIELDWORK
		and self.vehicle.cp.mode ~= courseplay.MODE_BUNKERSILO_COMPACTER
		and self.vehicle.cp.mode ~= courseplay.MODE_FIELD_SUPPLY
		--and self.vehicle.cp.mode ~= courseplay.MODE_COMBI
		and new == #self.values then
		-- enable AI Driver for mode 1, 4, 5, 6 ,8 , 9 and 10 only until it can handle other modes
		return 1
	else
		return SettingList.checkAndSetValidValue(self, new)
	end
end

--- Disable PPC for the legacy driving mode
function DrivingModeSetting:onChange()
	if self.vehicle.cp.ppc then
		if self:get() == DrivingModeSetting.DRIVING_MODE_NORMAL then
			self.vehicle.cp.ppc:disable()
		else
			self.vehicle.cp.ppc:enable()
		end
	end
end

---@class StartingLocationSetting : SettingList
StartingLocationSetting = CpObject(SettingList)

function StartingLocationSetting:init(vehicle)
	SettingList.init(self, 'startingLocation', 'COURSEPLAY_STARTING_LOCATION', '', vehicle,
		{
			courseGenerator.STARTING_LOCATION_VEHICLE_POSITION,
			courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION,
			courseGenerator.STARTING_LOCATION_SW,
			courseGenerator.STARTING_LOCATION_NW,
			courseGenerator.STARTING_LOCATION_NE,
			courseGenerator.STARTING_LOCATION_SE,
			courseGenerator.STARTING_LOCATION_SELECT_ON_MAP
		},
		{
			'COURSEPLAY_CORNER_5',
			'COURSEPLAY_CORNER_6',
			'COURSEPLAY_CORNER_7',
			'COURSEPLAY_CORNER_8',
			'COURSEPLAY_CORNER_9',
			'COURSEPLAY_CORNER_10',
			'COURSEPLAY_CORNER_11'
		})
	if not self.vehicle.cp.generationPosition.hasSavedPosition then
		table.remove(self.values, 2)
		table.remove(self.texts, 2)
	end
end

--- Course gen center mode setting
---@class CenterModeSetting : SettingList
CenterModeSetting = CpObject(SettingList)

function CenterModeSetting:init()
	SettingList.init(self, 'centerMode', 'COURSEPLAY_CENTER_MODE', '', nil,
		{
			courseGenerator.CENTER_MODE_UP_DOWN,
			courseGenerator.CENTER_MODE_CIRCULAR,
			courseGenerator.CENTER_MODE_SPIRAL
		},
		{
			'COURSEPLAY_CENTER_MODE_UP_DOWN',
			'COURSEPLAY_CENTER_MODE_CIRCULAR',
			'COURSEPLAY_CENTER_MODE_SPIRAL'
		})
end

--- Implement raise/lower  setting
---@class ImplementRaiseLowerTimeSetting : SettingList
ImplementRaiseLowerTimeSetting = CpObject(SettingList)

-- Raise or lower implements early or late
-- implement raised when the front marker reaches the end of the area to be worked
-- implement lowered when the front marker reaches the end of the area to be worked
ImplementRaiseLowerTimeSetting.EARLY	= 1
-- implement raised when the back marker reaches the start of the area to be worked
-- implement lowered when the back marker reaches the start of the area to be worked
ImplementRaiseLowerTimeSetting.LATE		= 2

function ImplementRaiseLowerTimeSetting:init(vehicle, name, label, tooltip)
	SettingList.init(self,  name, label, tooltip, vehicle,
		{
			ImplementRaiseLowerTimeSetting.EARLY,
			ImplementRaiseLowerTimeSetting.LATE,
		},
		{
			'COURSEPLAY_IMPLEMENT_RAISE_LOWER_EARLY',
			'COURSEPLAY_IMPLEMENT_RAISE_LOWER_LATE',
		})
end

---@class ImplementRaiseTimeSetting : ImplementRaiseLowerTimeSetting
ImplementRaiseTimeSetting = CpObject(ImplementRaiseLowerTimeSetting)
function ImplementRaiseTimeSetting:init(vehicle)
	ImplementRaiseLowerTimeSetting.init(self, vehicle, 'implementRaiseTime', 'COURSEPLAY_IMPLEMENT_RAISE_TIME', 'COURSEPLAY_IMPLEMENT_RAISE_TIME_TOOLTIP')
	self:set(ImplementRaiseLowerTimeSetting.EARLY)
end

---@class ImplementLowerTimeSetting : ImplementRaiseLowerTimeSetting
ImplementLowerTimeSetting = CpObject(ImplementRaiseLowerTimeSetting)
function ImplementLowerTimeSetting:init(vehicle)
	ImplementRaiseLowerTimeSetting.init(self, vehicle, 'implementLowerTime', 'COURSEPLAY_IMPLEMENT_LOWER_TIME', 'COURSEPLAY_IMPLEMENT_LOWER_TIME_TOOLTIP')
	self:set(ImplementRaiseLowerTimeSetting.LATE)
end

--- Return to first point after finishing fieldwork
---@class ReturnToFirstPointSetting : BooleanSetting
ReturnToFirstPointSetting = CpObject(BooleanSetting)
function ReturnToFirstPointSetting:init(vehicle)
	BooleanSetting.init(self, 'returnToFirstPoint', 'COURSEPLAY_RETURN_TO_FIRST_POINT',
		'COURSEPLAY_RETURN_TO_FIRST_POINT', vehicle)
end

--- Load courses at startup?
---@class LoadCoursesAtStartupSetting : BooleanSetting
LoadCoursesAtStartupSetting = CpObject(BooleanSetting)
function LoadCoursesAtStartupSetting:init()
	BooleanSetting.init(self, 'loadCoursesAtStartup', 'COURSEPLAY_LOAD_COURSES_AT_STARTUP',
		'COURSEPLAY_LOAD_COURSES_AT_STARTUP_TOOLTIP', nil)
end

--- Use AI Turns?
---@class UseAITurnsSetting : BooleanSetting
UseAITurnsSetting = CpObject(BooleanSetting)
function UseAITurnsSetting:init(vehicle)
	BooleanSetting.init(self, 'useAITurns', 'COURSEPLAY_USE_AI_TURNS',
		'COURSEPLAY_USE_AI_TURNS_TOOLTIP', vehicle)
end

--- Use pathfinding during turns?
---@class UsePathfindingInTurnsSetting : BooleanSetting
UsePathfindingInTurnsSetting = CpObject(BooleanSetting)
function UsePathfindingInTurnsSetting:init(vehicle)
	BooleanSetting.init(self, 'usePathfindingInTurns', 'COURSEPLAY_USE_PATHFINDING_IN_TURNS',
		'COURSEPLAY_USE_PATHFINDING_IN_TURNS_TOOLTIP', vehicle)
end

--- Allow driving reverse for pathfinding during turns?
---@class AllowReverseForPathfindingInTurnsSetting : BooleanSetting
AllowReverseForPathfindingInTurnsSetting = CpObject(BooleanSetting)
function AllowReverseForPathfindingInTurnsSetting:init(vehicle)
	BooleanSetting.init(self, 'allowReverseForPathfindingInTurns', 'COURSEPLAY_ALLOW_REVERSE_FOR_PATHFINDING_IN_TURNS',
			'COURSEPLAY_ALLOW_REVERSE_FOR_PATHFINDING_IN_TURNS_TOOLTIP', vehicle)
end

---@class AutoFieldScanSetting : BooleanSetting
AutoFieldScanSetting = CpObject(BooleanSetting)
function AutoFieldScanSetting:init()
	BooleanSetting.init(self, 'autoFieldScan', 'COURSEPLAY_AUTO_FIELD_SCAN',
		'COURSEPLAY_YES_NO_FIELDSCAN', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---@class ClickToSwitchSetting : BooleanSetting
ClickToSwitchSetting = CpObject(BooleanSetting)
function ClickToSwitchSetting:init()
	BooleanSetting.init(self, 'clickToSwitch', 'COURSEPLAY_CLICK_TO_SWITCH',
				'COURSEPLAY_YES_NO_CLICK_TO_SWITCH', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(false)
end

---@class EarnWagesSetting : BooleanSetting
EarnWagesSetting = CpObject(BooleanSetting)
function EarnWagesSetting:init()
	BooleanSetting.init(self, 'earnWages', 'COURSEPLAY_EARN_WAGES',
		'COURSEPLAY_YES_NO_WAGES', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(false)
end

---@class HourlyWages : SettingList
WorkerWages = CpObject(SettingList)
function WorkerWages:init()
	SettingList.init(self, 'workerWages', 'COURSEPLAY_WORKER_WAGES', 'COURSEPLAY_WORKER_WAGES_TOOLTIP', nil,
			{ 50, 100, 250, 500, 1000},
			{'50%', '100%', '250%', '500%', '1000%'}
		)
	self:set(100)
end

---@class SelfUnloadSetting : BooleanSetting
SelfUnloadSetting = CpObject(BooleanSetting)
function SelfUnloadSetting:init(vehicle)
	BooleanSetting.init(self, 'selfUnload', 'COURSEPLAY_SELF_UNLOAD', 'COURSEPLAY_SELF_UNLOAD_TOOLTIP', vehicle)
end

---@class SymmetricLaneChangeSetting : BooleanSetting
SymmetricLaneChangeSetting = CpObject(BooleanSetting)
function SymmetricLaneChangeSetting:init(vehicle)
	BooleanSetting.init(self, 'symmetricLaneChange', 'COURSEPLAY_SYMMETRIC_LANE_CHANGE', 'COURSEPLAY_SYMMETRIC_LANE_CHANGE', vehicle)
end

--- Container for settings
--- @class SettingsContainer
SettingsContainer = CpObject()

--- Add a setting which then can be addressed by its name like container['settingName'] or container.settingName
function SettingsContainer:addSetting(settingClass, ...)
	local s = settingClass(...)
	s.syncValue = true -- Only sync values that are part of a SettingsContainer
	self[s.name] = s
end

function SettingsContainer:saveToXML(xml, parentKey)
	for _, setting in pairs(self) do
		setting:saveToXml(xml, parentKey)
	end
end

function SettingsContainer:loadFromXML(xml, parentKey)
	for _, setting in pairs(self) do
		setting:loadFromXml(xml, parentKey)
	end
end

-- do not remove this comment
-- vim: set noexpandtab:
