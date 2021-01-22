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
		--end
		courseplay:setAIDriver(vehicle, modeNum)
	end;
end;

function courseplay:setAIDriver(vehicle, mode)
	if vehicle.cp.driver then
		vehicle.cp.driver:delete()
	end
	local status,driver,err
	if mode == courseplay.MODE_TRANSPORT then
		---@type AIDriver
		status,driver,err,errDriverName = xpcall(AIDriver, function(err) printCallstack(); return self,err,"AIDriver" end, vehicle)
	--local status, err = xpcall(self.cp.driver.update, function(err) printCallstack(); return err end, self.cp.driver, dt)
	elseif mode == courseplay.MODE_GRAIN_TRANSPORT then
		status,driver,err,errDriverName = xpcall(GrainTransportAIDriver, function(err) printCallstack(); return self,err,"GrainTransportAIDriver" end, vehicle)
	elseif mode == courseplay.MODE_COMBI then
		status,driver,err,errDriverName = xpcall(CombineUnloadAIDriver, function(err) printCallstack(); return self,err,"CombineUnloadAIDriver" end, vehicle)
	elseif mode == courseplay.MODE_OVERLOADER then
		status,driver,err,errDriverName = xpcall(OverloaderAIDriver, function(err) printCallstack(); return self,err,"OverloaderAIDriver" end, vehicle)
	elseif mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY then
		status,driver,err,errDriverName = xpcall(ShovelModeAIDriver.create, function(err) printCallstack(); return self,err,"ShovelModeAIDriver" end, vehicle)
	elseif mode == courseplay.MODE_SEED_FERTILIZE then
		status,driver,err,errDriverName = xpcall(FillableFieldworkAIDriver, function(err) printCallstack(); return self,err,"FillableFieldworkAIDriver" end, vehicle)
	elseif mode == courseplay.MODE_FIELDWORK then
		status,driver,err,errDriverName = xpcall(UnloadableFieldworkAIDriver.create, function(err) printCallstack(); return self,err,"UnloadableFieldworkAIDriver" end, vehicle)
	elseif mode == courseplay.MODE_BUNKERSILO_COMPACTER then
		status,driver,err,errDriverName = xpcall(LevelCompactAIDriver, function(err) printCallstack(); return self,err,"LevelCompactAIDriver" end, vehicle)
	elseif mode == courseplay.MODE_FIELD_SUPPLY then
		status,driver,err,errDriverName = xpcall(FieldSupplyAIDriver, function(err) printCallstack(); return self,err,"FieldSupplyAIDriver" end, vehicle)
	end
	vehicle.cp.driver = driver
	if not status then
		courseplay.infoVehicle(vehicle, "Exception, can't init %s, %s", errDriverName,tostring(err))
	end
end

function courseplay:setDriveNow(vehicle)
	vehicle.cp.driver:setDriveNow()
end

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
	local tractor = g_combineUnloadManager:getUnloaderByNumber(1, combine)
	if tractor then	
		tractor.cp.settings.forcedToStop:toggle()
	end
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
	if cancelStopAtEnd then
		vehicle.cp.settings.stopAtEnd:set(false)
	end;
end;

function courseplay:setDriveUnloadNow(vehicle, bool)
	if vehicle then
		vehicle.cp.settings.driveUnloadNow:set(bool)
		courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);		
	end
end

function courseplay:sendCourseplayerHome(combine)
	courseplay:setDriveUnloadNow(g_combineUnloadManager:getUnloaderByNumber(1, combine), true);
end



function courseplay:switchCourseplayerSide(combine)
	if courseplay:isChopper(combine) then
		local tractor = combine.courseplayers[1];
		if tractor == nil then
			return;
		end;

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

function courseplay:changeToolOffsetX(vehicle, changeBy)
	vehicle.cp.settings.toolOffsetX:changeBy(changeBy * 0.1)
	vehicle.cp.totalOffsetX = vehicle.cp.settings.toolOffsetX:get();
	-- show new setting for a few seconds on the screen
	courseplay:setCustomTimer(vehicle, 'showWorkWidth', 2);
end

function courseplay:setAutoToolOffsetX(vehicle)
	vehicle.cp.settings.toolOffsetX:setToConfiguredValue(vehicle)
end

function courseplay:changeToolOffsetZ(vehicle, changeBy, force, noDraw)
	vehicle.cp.settings.toolOffsetZ:changeBy(changeBy * 0.1)
	-- show new setting for a few seconds on the screen
	courseplay:setCustomTimer(vehicle, 'showWorkWidth', 2);
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

--legancy Code in toolManager still using it!
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

function courseplay:toggleAlignmentWaypoint( vehicle )
	vehicle.cp.alignment.enabled = not vehicle.cp.alignment.enabled
end

--Do we want to use this one again ?
function courseplay:toggleSearchCombineMode(vehicle)
	vehicle.cp.searchCombineAutomatically = not vehicle.cp.searchCombineAutomatically;
	if not vehicle.cp.searchCombineAutomatically then
		vehicle.cp.settings.searchCombineOnField:set(0)
	end;
end;

function courseplay:selectAssignedCombine(vehicle, changeBy)
	vehicle.cp.settings.selectedCombineToUnload:refresh()
	if changeBy > 0 then
		vehicle.cp.settings.selectedCombineToUnload:setNext()
	else
		vehicle.cp.settings.selectedCombineToUnload:setPrevious()
	end
	courseplay:removeActiveCombineFromTractor(vehicle)
	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
end;

function courseplay:removeActiveCombineFromTractor(vehicle)
	if vehicle.cp.driver and vehicle.cp.driver.onUserUnassignedActiveCombine then
		vehicle.cp.driver:onUserUnassignedActiveCombine()
	end
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


--still used in CourseGeneratorScreen.lua ??
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
	vehicle.cp.oldCourseGeneratorSettings.islandBypassMode = vehicle.cp.oldCourseGeneratorSettings.islandBypassMode + 1
	if vehicle.cp.oldCourseGeneratorSettings.islandBypassMode > Island.BYPASS_MODE_MAX then
		vehicle.cp.oldCourseGeneratorSettings.islandBypassMode = Island.BYPASS_MODE_MIN
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
		return;
	end;
	while courseplay.fields.fieldData[newFieldNum] == nil do
		if newFieldNum == 0 then
			vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;
			return;
		end;
		newFieldNum = MathUtil.clamp(newFieldNum + changeDir, 0, courseplay.fields.numAvailableFields);
	end;

	vehicle.cp.fieldEdge.selectedField.fieldNum = newFieldNum;

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

function courseplay:setSlippingStage(vehicle, stage)
	if vehicle.cp.slippingStage ~= stage then
		courseplay:debug(('%s: setSlippingStage(..., %d)'):format(nameNum(vehicle), stage), 14);
		vehicle.cp.slippingStage = stage;
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

function Setting:getName()
	return self.name
end

function Setting:getToolTip()
	return courseplay:loc(self.toolTip)
end

-- function only called from network to set synced setting
function Setting:setFromNetwork(value)
	self:set(value,true)
	self:onChange()
end


function Setting:printSetting()
	print(self:getName()..": "..tostring(self:get()))
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

-- For settings where the valid values depend on other conditions, re-evaluate the validity of the
-- current setting (when for example changed the mode of the vehicle, is the current setting still valid for the new mode)
function Setting:validateCurrentValue()
	-- override
end

function Setting:setParent(name)
	self.parentName = name
end

--- Should this setting be disabled on the GUI?
function Setting:isDisabled()
	return false
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
		self:set(value,true)
	end
end

function FloatSetting:saveToXml(xml, parentKey)
	setXMLFloat(xml, self:getKey(parentKey), self:get())
end

function FloatSetting:onWriteStream(stream)
	streamDebugWriteFloat32(stream, self:get())
end

function FloatSetting:onReadStream(stream)
	local value = streamDebugReadFloat32(stream)
	if value then 
		self:setFromNetwork(value)
	end
end


---@class IntSetting
IntSetting = CpObject(Setting)
--- @param name string name of this settings, will be used as an identifier in containers and XML
--- @param label string text ID in translations used as a label for this setting on the GUI
--- @param toolTip string text ID in translations used as a tooltip for this setting on the GUI
--- @param vehicle table vehicle, needed for vehicle specific settings for multiplayer syncs
--- @param MIN int min allowed value
--- @param MAX int max allowed value
function IntSetting:init(name, label, toolTip, vehicle,MIN,MAX)
	Setting.init(self, name, label, toolTip, vehicle)
	self.MAX = MAX
	self.MIN = MIN
end

function IntSetting:loadFromXml(xml, parentKey)
	local value = getXMLInt(xml, self:getKey(parentKey))
	if value then
		self:set(value,true)
	end
end

function IntSetting:saveToXml(xml, parentKey)
	setXMLInt(xml, self:getKey(parentKey), self:get())
end

function IntSetting:onWriteStream(stream)
	streamDebugWriteInt32(stream, self:get())
end

function IntSetting:onReadStream(stream)
	local value = streamDebugReadInt32(stream)
	if value then 
		self:setFromNetwork(value)
	end
end

function IntSetting:changeByX(x)
	self:set(self:get()+x)
end

function IntSetting:set(value,noEventSend)
	local minOk = self.MIN and value>=self.MIN or self.MIN == nil
	local maxOk = self.MAX and value<=self.MAX or self.MAX == nil
	if minOk and maxOk and value then 
		self.value = value
		if noEventSend == nil or noEventSend == false then
			if self.syncValue then
				self:sendEvent(value)
			end
		end
		self:onChange()
	end
end

function IntSetting:sendEvent(value)
	SettingsListEvent.sendEvent(self.vehicle,self.parentName, self.name, value)
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

---@param seconds number if value changed within seconds than it should be considered invalid
---@return nil if value changed in the last seconds seconds, otherwise the current value
function SettingList:getIfNotChangedFor(seconds)
	if self:getSecondsSinceLastChange() > seconds then
		return self:get()
	else
		return nil
	end
end

-- Is the current value same as the param?
function SettingList:is(value)
	return self.values[self.current] == value
end

-- Get the current text key (for the logs, for example)
function SettingList:__tostring()
	return self.texts[self.current]
end

-- Get the current text
function SettingList:getText()
	return courseplay:loc(self.texts[self.current])
end

--- Set the next value
function SettingList:setNext()
	local new = self:checkAndSetValidValue(self.current + 1)
	self:setToIx(new)
end

--- Set the previous value
function SettingList:setPrevious()
	local new = self:checkAndSetValidValue(self.current - 1)
	self:setToIx(new)
end

function SettingList:changeByX(x)
	local ix = 1
	if x<0 then
		ix = -1
	end
	local new = self:checkAndSetValidValue(self.current + ix)
	self:setToIx(new)
end

-- TODO: consolidate this with setNext()
function SettingList:next()
	self:setNext()
end

-- private function to set to the value at ix
function SettingList:setToIx(ix,noEventSend)
	if ix ~= self.current then
		self.previous = self.current
		self.current = ix
		self:onChange()
		self.lastChangeTimeMilliseconds = g_time
		if noEventSend == nil or noEventSend == false then
			if self.syncValue then
				self:sendEvent()
			end
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
function SettingList:set(value,noEventSend)
	local new
	-- find the value requested
	for i = 1, #self.values do
		if self.values[i] == value then
			new = self:checkAndSetValidValue(i)
			self:setToIx(new,noEventSend)
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
	-- remember the value loaded from XML for those settings which aren't up to date when loading,
	-- for example the field numbers
	self.valueFromXml = getXMLInt(xml, self:getKey(parentKey))
	if self.valueFromXml then
		self:set(self.valueFromXml,true)
	end
end

function SettingList:saveToXml(xml, parentKey)
	setXMLInt(xml, self:getKey(parentKey), Utils.getNoNil(self:get(),0))
end

---@return number seconds since last change
function SettingList:getSecondsSinceLastChange()
	return self:getMilliSecondsSinceLastChange() / 1000
end

---@return number milliseconds since last change
function SettingList:getMilliSecondsSinceLastChange()
	return (g_time - self.lastChangeTimeMilliseconds)
end

function SettingList:validateCurrentValue()
	local new = self:checkAndSetValidValue(self.current)
	self:setToIx(new,true)
end

function SettingList:getDebugString()
	local result = string.format('%s:\n', self.name)
	for i = 1, #self.values do
		result = result .. string.format('\t%s%2d: %s\n', i == self.current and '*' or ' ', i, tostring(self.values[i]))
	end
	return result
end

function SettingList:onWriteStream(stream)
	streamDebugWriteInt32(stream, self:getNetworkCurrentValue())
end

function SettingList:onReadStream(stream)
	local value = streamDebugReadInt32(stream)
	if value ~= nil then 
		self:setFromNetwork(value)
	else 
		print(self:getName()..": Error")
	end
end

function SettingList:getNetworkCurrentValue()
	return self.current
end

function SettingList:sendEvent()
	if self.vehicle then 
		SettingsListEvent.sendEvent(self.vehicle,self.parentName, self.name, self.current)
	else 
		GlobalSettingsEvent.sendEvent(self.parentName, self.name, self.current)
	end
end

---WIP
---Generic LinkedList setting and Interface for LinkedList.lua
---@class LinkedList : Setting
LinkedListSetting = CpObject(Setting)
function LinkedListSetting:init(name, label, toolTip, vehicle)
	Setting.init(self, name, label, toolTip, vehicle)
	self.List = LinkedList({value=nil,text="Dummy"})
end

function LinkedListSetting:moveUpByIndex(index)
	self.List:swapUpX(index)
end

function LinkedListSetting:moveDownByIndex(index)
	self.List:swapDownX(index)
end

function LinkedListSetting:addLast(data)
	self.List:addLast(data)
end

function LinkedListSetting:deleteByIndex(index)
	self.List:removeX(index)
end

function LinkedListSetting:getText(index)
	data = self:getDataByIndex(index)
	if data and data.text then 
		return data.text
	else
		return ""
	end
end

function LinkedListSetting:getDataByIndex(index)
	local element = self.List:getElementByIndex(index)
	if element and element.data then 
		return element.data
	end
end

function LinkedListSetting:getSize()
	return self.List:getSize()
end

function LinkedListSetting:getData()
	return self.List:getData()
end

function LinkedListSetting:getDataXtoY(x,y)	
	return self.List:getDataXtoY(x,y)
end

function LinkedListSetting:isEmpty()	
	return self:getSize()<=0
end

function LinkedListSetting:onWriteStream(stream)
	--override code
end

function LinkedListSetting:onReadStream(stream)
	--override code
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

function BooleanSetting:changeByX(x)
	self:toggle()
end


function BooleanSetting:loadFromXml(xml, parentKey)
	local value = getXMLBool(xml, self:getKey(parentKey))
	if value ~= nil then
		self:set(value,true)
	end
end

function BooleanSetting:saveToXml(xml, parentKey)
	setXMLBool(xml, self:getKey(parentKey), self:get())
end

--- Generic Percentage setting from 1% to 100%
---@class PercentageSettingList : SettingList
PercentageSettingList = CpObject(SettingList)
function PercentageSettingList:init(name, label, toolTip, vehicle)
	local values = {}
	local texts = {}
	for i=1,100 do 
		values[i] = i
		texts[i] = i.."%"
	end
	SettingList.init(self, name, label, toolTip, vehicle,values, texts)
end

function PercentageSettingList:checkAndSetValidValue(new)
	if new <= #self.values and new > 0 then
		return new
	else
		return self.current
	end
end

--- Generic Speed setting from x to y 
---@class SpeedSetting : SettingList
SpeedSetting = CpObject(SettingList)
function SpeedSetting:init(name, label, toolTip, vehicle,startValue,stopValue)
	local values = {}
	local texts = {}
	for i=1,stopValue-startValue do 
		local x = startValue+i-1
		values[i] = x
		texts[i] = ('%i %s'):format(x, courseplay:getSpeedMeasuringUnit());
	end
	SettingList.init(self, name, label, toolTip, vehicle,values, texts)
end

-- Generic IntSetting with power of x (for example 0.1) 
---@class IntSettingScientific 
IntSettingScientific = CpObject(IntSetting)
--- @param name string name of this settings, will be used as an identifier in containers and XML
--- @param label string text ID in translations used as a label for this setting on the GUI
--- @param toolTip string text ID in translations used as a tooltip for this setting on the GUI
--- @param vehicle table vehicle, needed for vehicle specific settings for multiplayer syncs
--- @param MIN int min allowed value
--- @param MAX int max allowed value
--- @param POWER float changes int value by const POWER 
function IntSettingScientific:init(name, label, toolTip, vehicle,MIN,MAX,POWER)
	IntSetting.init(self, name, label, toolTip, vehicle,MIN,MAX)
	self.MAX = MAX
	self.MIN = MIN
	self.POWER = POWER
end

function IntSettingScientific:getText()
	return tostring(self:getFixedValue())
end

-- get the fixed value with self.POWER
function IntSettingScientific:getFixedValue()
	return self:get()*self.POWER
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

function AutoDriveModeSetting:next()
	courseplay.debugVehicle(12, vehicle, 'AutoDrive mode: %d', vehicle.cp.settings.autoDriveMode:get())
	SettingList.next(self)
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
		if self.valueFromXml then
			self:set(self.valueFromXml)
			self.valueFromXml = nil
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
StartingPointSetting.START_WITH_UNLOAD      = 5 -- start with unloading the combine (only for CombineUnloadAIDriver)

function StartingPointSetting:init(vehicle)
	SettingList.init(self, 'startingPoint', 'COURSEPLAY_START_AT_POINT', 'COURSEPLAY_START_AT_POINT', vehicle,
			{
		        StartingPointSetting.START_AT_NEAREST_POINT,
				StartingPointSetting.START_AT_FIRST_POINT  ,
				StartingPointSetting.START_AT_CURRENT_POINT,
				StartingPointSetting.START_AT_NEXT_POINT,
				StartingPointSetting.START_WITH_UNLOAD
			},
			{
				"COURSEPLAY_NEAREST_POINT",
				"COURSEPLAY_FIRST_POINT"  ,
				"COURSEPLAY_CURRENT_POINT",
				"COURSEPLAY_NEXT_POINT",
				"COURSEPLAY_UNLOAD"
			})
end

function StartingPointSetting:checkAndSetValidValue(new)
	-- enable unload only for CombineUnloadAIDriver/Overloader
	if self.vehicle.cp.driver and
			self.vehicle.cp.mode ~= courseplay.MODE_COMBI and
			self.vehicle.cp.mode ~= courseplay.MODE_OVERLOADER and
			self.values[new] == StartingPointSetting.START_WITH_UNLOAD then
		return 1
	else
		return SettingList.checkAndSetValidValue(self, new)
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

function CenterModeSetting:init(vehicle)
	SettingList.init(self, 'centerMode', 'COURSEPLAY_CENTER_MODE', '', vehicle,
		{
			courseGenerator.CENTER_MODE_UP_DOWN,
			courseGenerator.CENTER_MODE_CIRCULAR,
			courseGenerator.CENTER_MODE_SPIRAL,
			courseGenerator.CENTER_MODE_LANDS
		},
		{
			'COURSEPLAY_CENTER_MODE_UP_DOWN',
			'COURSEPLAY_CENTER_MODE_CIRCULAR',
			'COURSEPLAY_CENTER_MODE_SPIRAL',
			'COURSEPLAY_CENTER_MODE_LANDS'
		})
end

--- Number of rows per land in Lands center mode
---@class NumberOfRowsPerLand
NumberOfRowsPerLandSetting = CpObject(SettingList)

function NumberOfRowsPerLandSetting:init(vehicle)
	SettingList.init(self, 'numberOfRowsPerLand', 'COURSEPLAY_NUMBER_OF_ROWS_PER_LAND',
			'COURSEPLAY_NUMBER_OF_ROWS_PER_LAND_TOOLTIP', vehicle,
			{4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24},
			{4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24})
	self:set(6)
end

--- Percentage of Overlap for Headland
---@class HeadlandOverlapPercent
HeadlandOverlapPercent = CpObject(SettingList)

function HeadlandOverlapPercent:init(vehicle)
	local values, texts = {}, {}
	for i = 0, 20 do
		table.insert(values, i)
		table.insert(texts, string.format('%d %%', i))
	end
	SettingList.init(self, 'headlandOverlapPercent', 'COURSEPLAY_HEADLAND_OVERLAP_PERCENT',
			'COURSEPLAY_HEADLAND_OVERLAP_PERCENT_TOOLTIP', vehicle,
			values, texts)
	-- reasonable default used for years
	self:set(7)
end

---@class ShowSeedCalculatorSetting : BooleanSetting
ShowSeedCalculatorSetting = CpObject(BooleanSetting)
function ShowSeedCalculatorSetting:init(vehicle)
	BooleanSetting.init(self, 'showSeedCalculator', 'COURSEPLAY_SEEDUSAGECALCULATOR','COURSEPLAY_SEEDUSAGECALCULATOR', vehicle)
	self:set(false)
end

--- Course generator settings (read from the XML, may be added to the UI later when needed):
---
--- Minimum radius in meters where a lane change on the headland is allowed. This is to ensure that
--- we only change lanes on relatively straight sections of the headland (not around corners)
---@class HeadlandLaneChangeMinRadius
HeadlandLaneChangeMinRadius = CpObject(IntSetting)

function HeadlandLaneChangeMinRadius:init()
	IntSetting.init(self, 'headlandLaneChangeMinRadius', 'HeadlandLaneChangeMinRadius',
			'Minimum radius where a lane change on the headland is allowed')
	self:set(20)
end

--- No lane change allowed on the headland if there is a corner ahead within this distance in meters
---@class HeadlandLaneChangeMinDistanceToCorner
HeadlandLaneChangeMinDistanceToCorner = CpObject(IntSetting)
function HeadlandLaneChangeMinDistanceToCorner:init()
	IntSetting.init(self, 'headlandLaneChangeMinDistanceToCorner', 'HeadlandLaneChangeMinDistanceToCorner',
			'Minimum distance to a corner for a lane change on the headland')
	self:set(20)
end

--- No lane change allowed on the headland if there is a corner behind within this distance in meters
---@class HeadlandLaneChangeMinDistanceFromCorner
HeadlandLaneChangeMinDistanceFromCorner = CpObject(IntSetting)
function HeadlandLaneChangeMinDistanceFromCorner:init()
	IntSetting.init(self, 'headlandLaneChangeMinDistanceFromCorner', 'HeadlandLaneChangeMinDistanceFromCorner',
			'Minimum distance from a corner for a lane change on the headland')
	self:set(10)
end

--- Pathfinder parameters settings (read from the XML, may be added to the UI later when needed):
---

--- The hybrid A* algorithm's default delta angle at the goal is 6 degrees, meaning the goal node must
--- be within this angle for the goal to be considered as reached. This may lead to very long or completely
--- unsuccessful path finding if the goal is close to an obstacle for example.
--- We'll therefore start relaxing this criteria so bigger angle differences are acceptable as the pathfinder
--- number of unsuccessful iterations grow.
---
--- This is a factor at which we increase the goal angle difference, a value of 0 won't change it.
---@class DeltaAngleRelaxfactor
DeltaAngleRelaxFactor = CpObject(FloatSetting)
function DeltaAngleRelaxFactor:init()
	IntSetting.init(self, 'deltaAngleRelaxFactor', 'DeltaAngleRelaxFactor',
			'Factor to decrease pathfinder accuracy with unsuccessful iterations')
	self:set(10)
end

--- Maximum value of the delta angle at the goal in radians, see above.
---@class MaxDeltaAngleAtGoal
MaxDeltaAngleAtGoal = CpObject(FloatSetting)
function MaxDeltaAngleAtGoal:init()
	IntSetting.init(self, 'maxDeltaAngleAtGoal', 'MaxDeltaAngleAtGoal',
			'Maximum angle difference allowed at goal')
	self:set(math.pi / 4)
end

--toggleHeadlandDirection
--toggleHeadlandOrder

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

---@class FoldImplementAtEndSetting : BooleanSetting
FoldImplementAtEndSetting = CpObject(BooleanSetting)
function FoldImplementAtEndSetting:init(vehicle)
	BooleanSetting.init(self, 'foldImplementAtEnd', 'COURSEPLAY_SHOULD_FOLD_IMPLEMENT',
		'COURSEPLAY_SHOULD_FOLD_IMPLEMENT_TOOLTIP', vehicle)
	self:set(true)
end

--- Return to first point after finishing fieldwork
---@class ReturnToFirstPointSetting : SettingList
ReturnToFirstPointSetting = CpObject(SettingList)
ReturnToFirstPointSetting.DEACTIVED = 0
ReturnToFirstPointSetting.RETURN_TO_START = 1
ReturnToFirstPointSetting.RELEASE_DRIVER = 2
ReturnToFirstPointSetting.RETURN_TO_START_AND_RELEASE_DRIVER = 3
function ReturnToFirstPointSetting:init(vehicle)
	SettingList.init(self, 'returnToFirstPoint', 'COURSEPLAY_RETURN_TO_FIRST_POINT',
		'COURSEPLAY_RETURN_TO_FIRST_POINT', vehicle,
		{
			self.DEACTIVED,
			self.RETURN_TO_START,
			self.RELEASE_DRIVER,
			self.RETURN_TO_START_AND_RELEASE_DRIVER	
			},
		{
			"COURSEPLAY_DEACTIVATED",
			"COURSEPLAY_ACTIVATED",
			"COURSEPLAY_RETURN_TO_FIRST_POINT_RELEASE_DRIVER",
			"COURSEPLAY_RETURN_TO_FIRST_POINT_RETURN_TO_START_AND_RELEASE_DRIVER"
		})
end

function ReturnToFirstPointSetting:isReturnToStartActive()
	return self:get() == self.RETURN_TO_START or self:get() == self.RETURN_TO_START_AND_RELEASE_DRIVER
end

function ReturnToFirstPointSetting:isReleaseDriverActive()
	return self:get() == self.RELEASE_DRIVER or self:get() == self.RETURN_TO_START_AND_RELEASE_DRIVER
end

--- Generic offset setting with increment/decrement
---@class OffsetSetting : FloatSetting
OffsetSetting = CpObject(FloatSetting)
function OffsetSetting:init(name, label, toolTip, vehicle, value)
	FloatSetting.init(self, name, label, toolTip, vehicle, value)
end

-- increment/decrement offset
function OffsetSetting:changeBy(changeBy)
	self.value = courseplay:round(self.value, 1) + changeBy
	if abs(self.value) < 0.1 then
		self.value = 0
	end
end

---@class ToolOffsetXSetting : OffsetSetting
ToolOffsetXSetting = CpObject(OffsetSetting)
function ToolOffsetXSetting:init(vehicle)
	OffsetSetting.init(self, 'toolOffsetX', 'COURSEPLAY_TOOL_OFFSET_X', 'COURSEPLAY_TOOL_OFFSET_X', vehicle, 0)
end

--- Set to the configured value if exists, 0 otherwise
function ToolOffsetXSetting:setToConfiguredValue()
	-- set the auto tool offset if exists or 0
	self:set(g_vehicleConfigurations:getRecursively(self.vehicle, self.name) or 0)
end

function ToolOffsetXSetting:getText()
	if self.value ~= 0 then
		return ('%.1f%s (%s)'):format(
				abs(self.value),
				courseplay:loc('COURSEPLAY_UNIT_METER'),
				courseplay:loc(self.value > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'))
	else
		return '---'
	end
end

---@class ToolOffsetZSetting : OffsetSetting
ToolOffsetZSetting = CpObject(OffsetSetting)
function ToolOffsetZSetting:init(vehicle)
	OffsetSetting.init(self, 'toolOffsetZ', 'COURSEPLAY_TOOL_OFFSET_Z', 'COURSEPLAY_TOOL_OFFSET_Z', vehicle, 0)
end

function ToolOffsetZSetting:getText()
	if self.value ~= 0 then
		return ('%.1f%s (%s)'):format(
				abs(self.value),
				courseplay:loc('COURSEPLAY_UNIT_METER'),
				courseplay:loc(self.value > 0 and 'COURSEPLAY_FRONT' or 'COURSEPLAY_BACK'))
	else
		return '---'
	end
end

--- Setting to select a field
---@class FieldNumberSetting : SettingList
FieldNumberSetting = CpObject(SettingList)
function FieldNumberSetting:init(vehicle)
	local values, texts = self:loadFields()
	SettingList.init(self, 'fieldNumbers', 'COURSEPLAY_FIELD', 'COURSEPLAY_FIELD',
		vehicle, values, texts)
end

function FieldNumberSetting:loadFields()
	local values = {}
	local texts = {}
	for fieldNumber, _ in pairs( courseplay.fields.fieldData ) do
		table.insert(values, fieldNumber)
		table.insert(texts, fieldNumber)
	end
	table.sort( values, function( a, b ) return a < b end )
	table.sort( texts, function( a, b ) return a < b end )
	return values, texts
end

--- Refresh current field numbers (as they may change when fields are bought/sold)
function FieldNumberSetting:refresh()
	self.values, self.texts = self:loadFields()
	-- if a value was loaded previously from XML and this is the first refresh after that, take over that
	-- value now. This is because at game load the fields are not known yet.
	if self.valueFromXml then
		self:set(self.valueFromXml)
		self.valueFromXml = nil
	end
	self.current = math.min(self.current, #self.values)
end

--- Search combine on field
---@class SearchCombineOnFieldSetting : FieldNumberSetting
SearchCombineOnFieldSetting = CpObject(FieldNumberSetting)
function SearchCombineOnFieldSetting:init(vehicle)
	FieldNumberSetting.init(self, vehicle)
	self.name = 'searchCombineOnField'
	self.label = 'COURSEPLAY_SEARCH_COMBINE_ON_FIELD'
	self.tooltip = 'COURSEPLAY_SEARCH_COMBINE_ON_FIELD'
	self.xmlKey = 'searchCombineOnField'
	self.xmlAttribute = '#fieldNumber'
	self:addNoneSelected()
end

function SearchCombineOnFieldSetting:addNoneSelected()
	-- add value/text for nothing selected
	table.insert(self.values, 1, 0)
	table.insert(self.texts, 1, '--')
end

function SearchCombineOnFieldSetting:refresh()
	local current = self.current
	FieldNumberSetting.refresh(self)
	self:addNoneSelected()
	self.current = math.min(current, #self.values)
end

function SearchCombineOnFieldSetting:changeByX(x)
	if courseplay.fields.numAvailableFields == 0 or not self.vehicle.cp.searchCombineAutomatically then
		self:set(0)
		return
	end
	return FieldNumberSetting.changeByX(self,x)
end

--- SelectedCombineToUnload on field
---@class SelectedCombineToUnloadSetting : SettingList
SelectedCombineToUnloadSetting = CpObject(SettingList)

function SelectedCombineToUnloadSetting:init()
	print("SelectedCombineToUnloadSetting:init()")
	self.name = 'selectedCombineToUnload'
	self.label = 'COURSEPLAY_SEARCH_COMBINE_ON_FIELD'
	self.tooltip = 'COURSEPLAY_SEARCH_COMBINE_ON_FIELD'
	self.xmlKey = 'selectedCombineToUnload'
	self.xmlAttribute = '#combineId'
	self.current = 0
	self:refresh()
end

function SelectedCombineToUnloadSetting:refresh()
	self.values = {}
	for combine,_ in pairs (g_combineUnloadManager.combines) do
		table.insert(self.values,combine)
	end
end

function SelectedCombineToUnloadSetting:checkAndSetValidValue(new)
	if new > #self.values then
		return 0
	elseif new < 0 then
		return #self.values
	else
		return new
	end
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

---@class PipeAlwaysUnfold : BooleanSetting
PipeAlwaysUnfoldSetting = CpObject(BooleanSetting)
function PipeAlwaysUnfoldSetting:init(vehicle)
	BooleanSetting.init(self, 'pipeAlwaysUnfold', 'COURSEPLAY_PIPE_ALWAYS_UNFOLD',
				'COURSEPLAY_YES_NO_PIPE_ALWAYS_UNFOLD', vehicle)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(false)
end

function PipeAlwaysUnfoldSetting:isDisabled()
	return self.vehicle.cp.driver and not self.vehicle.cp.driver:is_a(CombineAIDriver)
end


---@class SowingMachineFertilizerEnabled : BooleanSetting
SowingMachineFertilizerEnabled = CpObject(BooleanSetting)
function SowingMachineFertilizerEnabled:init(vehicle)
	BooleanSetting.init(self, 'sowingMachineFertilizerEnabled', 'COURSEPLAY_FERTILIZE_OPTION',
				'COURSEPLAY_YES_NO_FERTILIZE_OPTION', vehicle)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

function SowingMachineFertilizerEnabled:isDisabled()
	return self.vehicle.cp.driver and not AIDriverUtil.hasAIImplementWithSpecialization(self.vehicle, SowingMachine)
end

---@class StrawSwathSetting : SettingList
StrawSwathSetting = CpObject(SettingList)
StrawSwathSetting.OFF = 0
StrawSwathSetting.ON = 1
StrawSwathSetting.ONLY_CENTER = 2
function StrawSwathSetting:init(vehicle)
	SettingList.init(self, 'strawSwath', 'COURSEPLAY_STRAW_ON_HEADLAND','COURSEPLAY_YES_NO_STRAW_ON_HEADLAND', vehicle,
		{StrawSwathSetting.OFF,StrawSwathSetting.ON,StrawSwathSetting.ONLY_CENTER},
		{'COURSEPLAY_DEACTIVATED','COURSEPLAY_ACTIVATED','COURSEPLAY_STRAW_ON_ONLY_CENTER'})
	-- set default while we are transitioning from the the old setting to this new one
	self:set(1)
end

function StrawSwathSetting:isDisabled()
	return self.vehicle.cp.driver and not self.vehicle.cp.driver:is_a(CombineAIDriver)
end

---@class RidgeMarkersAutomatic : BooleanSetting
RidgeMarkersAutomatic = CpObject(BooleanSetting)
function RidgeMarkersAutomatic:init(vehicle)
	BooleanSetting.init(self, 'ridgeMarkersAutomatic', 'COURSEPLAY_RIDGEMARKERS',
			'COURSEPLAY_YES_NO_RIDGEMARKERS', vehicle)
	self:set(false)
end

function RidgeMarkersAutomatic:isDisabled()
	return self.vehicle.cp.driver and not AIDriverUtil.hasAIImplementWithSpecialization(self.vehicle, RidgeMarker)
end

---@class KeepCurrentSteering : BooleanSetting
KeepCurrentSteering = CpObject(BooleanSetting)
function KeepCurrentSteering:init(vehicle)
	BooleanSetting.init(self, 'keepCurrentSteering', 'COURSEPLAY_KEEP_CURRENT_STEERING',
			'COURSEPLAY_KEEP_CURRENT_STEERING_TOOLTIP ', vehicle)
	self:set(false)
end

---@class EnableVisualWaypointsTemporary : BooleanSetting
EnableVisualWaypointsTemporary = CpObject(BooleanSetting)
function EnableVisualWaypointsTemporary:init(vehicle)
	BooleanSetting.init(self, 'enableVisualWaypointsTemporary', 'COURSEPLAY_ENABLE_VISUAL_WAYPOINTS_TEMPORARY',
				'COURSEPLAY_ENABLE_VISUAL_WAYPOINTS_TEMPORARY_TOOLTIP', vehicle)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(false)
end

---@class EnableOpenHudWithMouseVehicle : BooleanSetting
EnableOpenHudWithMouseVehicle = CpObject(BooleanSetting)
function EnableOpenHudWithMouseVehicle:init(vehicle)
	BooleanSetting.init(self, 'enableOpenHudWithMouseVehicle', 'COURSEPLAY_ENABLE_OPEN_HUD_WITH_MOUSE_VEHICLE',
				'COURSEPLAY_YES_NO_ENABLE_OPEN_HUD_WITH_MOUSE_VEHICLE', vehicle)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---@class SelfUnloadSetting : BooleanSetting
SelfUnloadSetting = CpObject(BooleanSetting)
function SelfUnloadSetting:init(vehicle)
	BooleanSetting.init(self, 'selfUnload', 'COURSEPLAY_SELF_UNLOAD', 'COURSEPLAY_SELF_UNLOAD_TOOLTIP', vehicle)
end

function SelfUnloadSetting:isDisabled()
	return self.vehicle.cp.driver and not self.vehicle.cp.driver:is_a(CombineAIDriver)
end


---@class SymmetricLaneChangeSetting : BooleanSetting
SymmetricLaneChangeSetting = CpObject(BooleanSetting)
function SymmetricLaneChangeSetting:init(vehicle)
	BooleanSetting.init(self, 'symmetricLaneChange', 'COURSEPLAY_SYMMETRIC_LANE_CHANGE', 'COURSEPLAY_SYMMETRIC_LANE_CHANGE', vehicle)
end

---@class StopForUnloadSetting : BooleanSetting
StopForUnloadSetting = CpObject(BooleanSetting)
function StopForUnloadSetting:init(vehicle)
	BooleanSetting.init(self, 'stopForUnload', 'COURSEPLAY_STOP_DURING_UNLOADING', 'COURSEPLAY_STOP_DURING_UNLOADING', vehicle)
end

function StopForUnloadSetting:checkAndSetValidValue(new)
	if courseplay:isChopper(self.vehicle) then
		-- can't activate for choppers
		return 1
	end
	return BooleanSetting.checkAndSetValidValue(self, new)
end

---@class AllowUnloadOnFirstHeadlandSetting : BooleanSetting
AllowUnloadOnFirstHeadlandSetting = CpObject(BooleanSetting)
function AllowUnloadOnFirstHeadlandSetting:init(vehicle)
	BooleanSetting.init(self, 'allowUnloadOnFirstHeadland', 'COURSEPLAY_ALLOW_UNLOAD_ON_FIRST_HEADLAND',
			'COURSEPLAY_ALLOW_UNLOAD_ON_FIRST_HEADLAND_TOOLTIP', vehicle)
	self:set(true)
end

function AllowUnloadOnFirstHeadlandSetting:isDisabled()
	return self.vehicle.cp.driver and not self.vehicle.cp.driver:is_a(CombineAIDriver)
end

-----------------------------------------------------------------------

---@class StopAtEndSetting : BooleanSetting
StopAtEndSetting = CpObject(BooleanSetting)
function StopAtEndSetting:init(vehicle)
	BooleanSetting.init(self, 'stopAtEnd', 'COURSEPLAY_STOP_AT_LAST_POINT', 'COURSEPLAY_STOP_AT_LAST_POINT', vehicle)
	self:set(false)
end

---@class AutomaticCoverHandlingSetting : BooleanSetting
AutomaticCoverHandlingSetting = CpObject(BooleanSetting)
function AutomaticCoverHandlingSetting:init(vehicle)
	BooleanSetting.init(self, 'automaticCoverHandling', 'COURSEPLAY_COVER_HANDLING', 'COURSEPLAY_COVER_HANDLING', vehicle)
	self:set(true)
end

--no Function!!
---@class AutomaticUnloadingOnFieldSetting : BooleanSetting
AutomaticUnloadingOnFieldSetting = CpObject(BooleanSetting)
function AutomaticUnloadingOnFieldSetting:init(vehicle)
	BooleanSetting.init(self, 'automaticUnloadingOnField', 'COURSEPLAY_UNLOADING_ON_FIELD', 'COURSEPLAY_UNLOADING_ON_FIELD',vehicle, {'COURSEPLAY_MANUAL','COURSEPLAY_AUTOMATIC'})
	self:set(false)
end

---@class DriverPriorityUseFillLevelSetting : BooleanSetting
DriverPriorityUseFillLevelSetting = CpObject(BooleanSetting)
function DriverPriorityUseFillLevelSetting:init(vehicle)
	BooleanSetting.init(self, 'driverPriorityUseFillLevel', 'COURSEPLAY_UNLOADING_DRIVER_PRIORITY', 'COURSEPLAY_UNLOADING_DRIVER_PRIORITY', vehicle, {'COURSEPLAY_DISTANCE','COURSEPLAY_FILLEVEL'})
	self:set(false)
end

---@class UseRecordingSpeedSetting : BooleanSetting
UseRecordingSpeedSetting = CpObject(BooleanSetting)
function UseRecordingSpeedSetting:init(vehicle)
	BooleanSetting.init(self, 'useRecordingSpeed', 'COURSEPLAY_MAX_SPEED_MODE', 'COURSEPLAY_MAX_SPEED_MODE', vehicle, {'COURSEPLAY_MAX_SPEED_MODE_MAX','COURSEPLAY_MAX_SPEED_MODE_RECORDING'})
	self:set(true)
end

---@class WarningLightsModeSetting : SettingList
WarningLightsModeSetting = CpObject(SettingList)
WarningLightsModeSetting.WARNING_LIGHTS_NEVER = 0;
WarningLightsModeSetting.WARNING_LIGHTS_BEACON_ON_STREET = 1;
WarningLightsModeSetting.WARNING_LIGHTS_BEACON_HAZARD_ON_STREET = 2;
WarningLightsModeSetting.WARNING_LIGHTS_BEACON_ALWAYS = 3;

function WarningLightsModeSetting:init(vehicle)
	SettingList.init(self, 'warningLightsMode', 'COURSEPLAY_WARNING_LIGHTS', 'COURSEPLAY_WARNING_LIGHTS', vehicle,
		{ 
			WarningLightsModeSetting.WARNING_LIGHTS_NEVER,
			WarningLightsModeSetting.WARNING_LIGHTS_BEACON_ON_STREET,
			WarningLightsModeSetting.WARNING_LIGHTS_BEACON_HAZARD_ON_STREET,
			WarningLightsModeSetting.WARNING_LIGHTS_BEACON_ALWAYS
		},
		{ 	
			'COURSEPLAY_WARNING_LIGHTS_MODE_0',
			'COURSEPLAY_WARNING_LIGHTS_MODE_1',
			'COURSEPLAY_WARNING_LIGHTS_MODE_2',
			'COURSEPLAY_WARNING_LIGHTS_MODE_3'
		}
		)
	self:set(1)
end

---@class ShowMapHotspotSetting : SettingList
ShowMapHotspotSetting = CpObject(SettingList)
ShowMapHotspotSetting.DEACTIVED = 0;
ShowMapHotspotSetting.NAME_ONLY = 1;
ShowMapHotspotSetting.NAME_AND_COURSE = 2;

function ShowMapHotspotSetting:init(vehicle)
	SettingList.init(self, 'showMapHotspot', 'COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT', 'COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT', vehicle,
		{ 
			ShowMapHotspotSetting.DEACTIVED,
			ShowMapHotspotSetting.NAME_ONLY,
			ShowMapHotspotSetting.NAME_AND_COURSE
		},
		{ 	
			'COURSEPLAY_DEACTIVATED',
			'COURSEPLAY_NAME_ONLY',
			'COURSEPLAY_NAME_AND_COURSE'
		}
		)
	self:set(2)
	self.mapHotspot=nil
end

function ShowMapHotspotSetting:onChange()
	--TODO get the other components in here ??
	for _,vehicle in pairs(CpManager.activeCoursePlayers) do
		local showMapHotspot = vehicle.cp.settings.showMapHotspot
		if showMapHotspot and showMapHotspot:getMapHotspot() then
			showMapHotspot:getMapHotspot():setText('CP\n' .. showMapHotspot:getMapHotspotText(vehicle))
			courseplay.hud:setReloadPageOrder(vehicle, 7, true)
		end
	end
end

function ShowMapHotspotSetting:getMapHotspot()
	return self.mapHotspot
end

function ShowMapHotspotSetting:deleteMapHotspot()
	if self.mapHotspot then
		g_currentMission:removeMapHotspot(self.mapHotspot)
		self.mapHotspot:delete()
		self.mapHotspot = nil
	end
end

function ShowMapHotspotSetting:getMapHotspotText(vehicle)
	local text = '';
	if vehicle.cp.settings.showMapHotspot:is(ShowMapHotspotSetting.NAME_ONLY) then 
		text = nameNum(vehicle, true) .. '\n';
	elseif vehicle.cp.settings.showMapHotspot:is(ShowMapHotspotSetting.NAME_AND_COURSE) then
		text = nameNum(vehicle, true) .. '\n';
		text = text .. ('(%s)'):format(vehicle.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE'));
	end
	return text
end

function ShowMapHotspotSetting:createMapHotspot()
	if self.vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING then
		return
	end
	--[[
	local hotspotX, _, hotspotZ = getWorldTranslation(vehicle.rootNode);
	local _, textSize = getNormalizedScreenValues(0, 6);
	local _, textOffsetY = getNormalizedScreenValues(0, 9.5);
	local width, height = getNormalizedScreenValues(11,11);
]]	local helperName = self.vehicle.currentHelper and self.vehicle.currentHelper.name or ".."
	local hotspotX, _, hotspotZ = getWorldTranslation(self.vehicle.rootNode)
	local _, textSize = getNormalizedScreenValues(0, 9)
	local _, textOffsetY = getNormalizedScreenValues(0, 18)
	local width, height = getNormalizedScreenValues(24, 24)
	self.mapHotspot = MapHotspot:new("cpHelper", MapHotspot.CATEGORY_AI)
	self.mapHotspot:setSize(width, height)
	self.mapHotspot:setLinkedNode(self.vehicle.components[1].node)											-- objectId to what the hotspot is attached to
	self.mapHotspot:setText(string.format('CP(%s)\n%s', tostring(helperName),self:getMapHotspotText(self.vehicle)))
	self.mapHotspot:setImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER), {0.052, 0.1248, 0.672, 1})
	self.mapHotspot:setBackgroundImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER))
	self.mapHotspot:setIconScale(0.7)
	self.mapHotspot:setTextOptions(textSize, nil, textOffsetY, {1, 1, 1, 1}, Overlay.ALIGN_VERTICAL_MIDDLE)
	self.mapHotspot:setColor(Utils.getNoNil(courseplay.hud.ingameMapIconsUVs[self.vehicle.cp.mode], courseplay.hud.ingameMapIconsUVs[courseplay.MODE_GRAIN_TRANSPORT]))
	g_currentMission:addMapHotspot(self.mapHotspot)


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


function ShowMapHotspotSetting:onWriteStream(stream)
	SettingList.onWriteStream(self,stream)
	if self.mapHotspot~=nil then 
		streamWriteBool(stream,true)
		if self.vehicle.currentHelper and self.vehicle.currentHelper.index ~= nil then 
			streamWriteBool(stream,true)
			streamWriteUInt8(stream, self.vehicle.currentHelper.index)
		else 
			streamWriteBool(stream,false)
		end
	else 
		streamWriteBool(stream,false)
	end
end

function ShowMapHotspotSetting:onReadStream(stream)
	SettingList.onReadStream(self,stream)
	if streamReadBool(stream) then
		if streamReadBool(stream) then
			local helperIndex = streamReadUInt8(stream)
			self.vehicle.currentHelper = g_helperManager:getHelperByIndex(helperIndex)
		end
		--add to activeCoursePlayers
		CpManager:addToActiveCoursePlayers(self.vehicle)	
		-- add ingameMap icon
		self:createMapHotspot();
	end
end


---@class SaveFuelOptionSetting : BooleanSetting
SaveFuelOptionSetting = CpObject(BooleanSetting)
function SaveFuelOptionSetting:init(vehicle)
	BooleanSetting.init(self, 'saveFuelOption', 'COURSEPLAY_FUELSAVEOPTION', 'COURSEPLAY_FUELSAVEOPTION', vehicle)
	self:set(true)
end

---@class AlwaysSearchFuelSetting : BooleanSetting
AlwaysSearchFuelSetting = CpObject(BooleanSetting)
function AlwaysSearchFuelSetting:init(vehicle)
	BooleanSetting.init(self, 'allwaysSearchFuel', 'COURSEPLAY_FUEL_SEARCH_FOR', 'COURSEPLAY_FUEL_SEARCH_FOR', vehicle, {'COURSEPLAY_FUEL_BELOW_20PCT','COURSEPLAY_FUEL_ALWAYS'})
	self:set(false)
end
---@class RealisticDrivingSetting : BooleanSetting
RealisticDrivingSetting = CpObject(BooleanSetting)
function RealisticDrivingSetting:init(vehicle)
	BooleanSetting.init(self, 'useRealisticDriving', 'COURSEPLAY_PATHFINDING', 'COURSEPLAY_PATHFINDING', vehicle)
	self:set(true)
end

---@class DriveUnloadNowSetting : BooleanSetting
DriveUnloadNowSetting = CpObject(BooleanSetting)
function DriveUnloadNowSetting:init(vehicle)
	BooleanSetting.init(self, 'driveUnloadNow', 'COURSEPLAY_DRIVE_NOW', 'COURSEPLAY_DRIVE_NOW', vehicle)
	self:set(false)
end

---@class CombineWantsCourseplayerSetting : BooleanSetting
CombineWantsCourseplayerSetting = CpObject(BooleanSetting)
function CombineWantsCourseplayerSetting:init(vehicle)
	BooleanSetting.init(self, 'combineWantsCourseplayer', 'COURSEPLAY_DRIVER', 'COURSEPLAY_DRIVER', vehicle, {'COURSEPLAY_REQUEST_UNLOADING_DRIVER','COURSEPLAY_UNLOADING_DRIVER_REQUESTED'})
	self:set(false)
end

---@class KeepUnloadingUntilEndOfRow : BooleanSetting
KeepUnloadingUntilEndOfRow = CpObject(BooleanSetting)
function KeepUnloadingUntilEndOfRow:init(vehicle)
	BooleanSetting.init(self, 'keepUnloadingUntilEndOfRow', 'COURSEPLAY_KEEP_UNLOADING_UNTIL_END_OF_ROW',
			'COURSEPLAY_KEEP_UNLOADING_UNTIL_END_OF_ROW_TOOLTIP', vehicle)
	self:set(false)
end

function KeepUnloadingUntilEndOfRow:isDisabled()
	return self.vehicle.cp.driver and not self.vehicle.cp.driver:is_a(CombineUnloadAIDriver)
end

---@class SiloSelectedFillTypeSetting : LinkedListSetting
SiloSelectedFillTypeSetting = CpObject(LinkedListSetting)
SiloSelectedFillTypeSetting.NetworkTypes = {}
SiloSelectedFillTypeSetting.NetworkTypes.ADD_ELEMENT = 0
SiloSelectedFillTypeSetting.NetworkTypes.DELETE_X = 1
SiloSelectedFillTypeSetting.NetworkTypes.MOVE_UP_X = 2
SiloSelectedFillTypeSetting.NetworkTypes.MOVE_DOWN_X = 3
SiloSelectedFillTypeSetting.NetworkTypes.CHANGE_MAX_FILLLEVEL = 4
SiloSelectedFillTypeSetting.NetworkTypes.CHANGE_RUNCOUNTER = 5
SiloSelectedFillTypeSetting.NetworkTypes.CLEANUP_OLD_FILLTYPES = 6
SiloSelectedFillTypeSetting.NetworkTypes.CHANGE_MIN_FILLEVEL = 7
function SiloSelectedFillTypeSetting:init(vehicle, mode)
	LinkedListSetting.init(self, 'siloSelectedFillType'..mode, 'COURSEPLAY_ADD_FILLTYPE', 'COURSEPLAY_ADD_FILLTYPE', vehicle)
	self.mode = mode
	self.MAX_RUNS = 20
	self.MAX_PERCENT = 100
	self.MIN_PERCENT = 0
	self.runCounterActive = true
	self.MAX_FILLTYPES = 2
	self.disallowedFillTypes = nil
	self.xmlKey = 'siloSelectedFillType'..mode
	self.xmlAttributeSize = '#size'
	self.xmlAttributeRunCounter = '#runCounter'
	self.xmlAttributeFillType = '#fillType'
	self.xmlAttributeMaxFillLevel = '#maxFillLevel'	
	self.xmlAttributeMinFillLevel = '#minFillLevel'	
end

function SiloSelectedFillTypeSetting:getMaxFillTypes()
	return self.MAX_FILLTYPES
end

function SiloSelectedFillTypeSetting:addFilltype()
	if self:isFull() then 
		return
	end
	local supportedFillTypes = {}
	self:getSupportedFillTypes(self.vehicle,supportedFillTypes)
	self:checkSelectedFillTypes(supportedFillTypes)
	if supportedFillTypes then
		g_gui:showSiloDialog({title="Filltype Selection", fillLevels=supportedFillTypes, capacity=100, callback=self.onFillTypeSelection, target=self, hasInfiniteCapacity = true})
	end
end

function SiloSelectedFillTypeSetting:isFull()
	if self:getSize() >= self.MAX_FILLTYPES then 
		return true
	end
end

function SiloSelectedFillTypeSetting:sendEvent(NetworkType, index , value)
	SiloSelectedFillTypeEvent.sendEvent(self.vehicle,self.name,NetworkType, index, value)
end

function SiloSelectedFillTypeSetting:onFillTypeSelection(selectedFillType,noEventSend)
	if selectedFillType and selectedFillType ~= FillType.UNKNOWN then 
		self:addLast(self:fillTypeDataToAdd(selectedFillType))
		if not noEventSend then
			self:sendEvent(self.NetworkTypes.ADD_ELEMENT,nil,selectedFillType)
		end
	end
end  

function SiloSelectedFillTypeSetting:fillTypeDataToAdd(selectedfillType,counter,maxLevel,minLevel)
	local data = nil
	if self.runCounterActive then
		data = {
			fillType = selectedfillType,
			text = g_fillTypeManager:getFillTypeByIndex(selectedfillType).title,
			runCounter = counter or self.MAX_RUNS,
			maxFillLevel = maxLevel or self.MAX_PERCENT,
			minFillLevel = minLevel or self.MIN_PERCENT
		}	
	else
		data = {
			fillType = selectedfillType,
			text = g_fillTypeManager:getFillTypeByIndex(selectedfillType).title,
			maxFillLevel = maxLevel or self.MAX_PERCENT,
			minFillLevel = minLevel or self.MIN_PERCENT
		}	
	end
	return data
end

--deletes not supported fillTypes
function SiloSelectedFillTypeSetting:cleanUpOldFillTypes(noEventSend)
	local supportedFillTypes = {}
	self:getSupportedFillTypes(self.vehicle,supportedFillTypes)
	self:checkSelectedFillTypes(supportedFillTypes,true)
	if not noEventSend then
		self:sendEvent(self.NetworkTypes.CLEANUP_OLD_FILLTYPES)
	end
end

function SiloSelectedFillTypeSetting:validateCurrentValue()
	self:cleanUpOldFillTypes(true)
end


function SiloSelectedFillTypeSetting:checkSelectedFillTypes(supportedFillTypes,cleanUp)
	totalData = self:getData()
	for index,data in ipairs(totalData) do 
		if supportedFillTypes[data.fillType] then --already selected fillTypes disable multi select
			supportedFillTypes[data.fillType]=0
		elseif cleanUp then	--delete not supported fillTypes 
			self:deleteByIndex(index) 
			return self:checkSelectedFillTypes(supportedFillTypes,cleanUp)
		end
	end
end 

function SiloSelectedFillTypeSetting:getSupportedFillTypes(object,supportedFillTypes)  
	if object and object.spec_fillUnit and object.getFillUnits then
		if supportedFillTypes ~= nil then 
			for fillUnitIndex, fillUnit in pairs(object:getFillUnits()) do
				for fillType,bool in pairs(object:getFillUnitSupportedFillTypes(fillUnitIndex)) do 
					local found = false
					local specMotor = object.spec_motorized
					--disable motor consumer fillTypes as they get loaded seperatly 
					if specMotor then 
						local consumer = specMotor.consumersByFillType[fillType] 
						if consumer then 
							if consumer.fillUnitIndex == fillUnitIndex then 
								found = true
							end							
						end
					end
					--disabled FillTypes(AIR, sometimes DEF or DIESEL)
					if self.disallowedFillTypes then		
						for _,_fillType in pairs(self.disallowedFillTypes) do 
							if fillType == _fillType then
								found = true
							end
						end
					end	
					--all okay and fillType is new add it to spported
					if bool and not found then 
						if supportedFillTypes[fillType] == nil then
							supportedFillTypes[fillType]=100
						end
					end
				end		
			end
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getSupportedFillTypes(impl.object,supportedFillTypes)
	end
end

--check if at least one fillType in list and if runCounterActive then check sepreate counters
function SiloSelectedFillTypeSetting:isActive()  
	if self:getSize() == 0 then 
		return false
	end
	if not self.runCounterActive then 
		return true
	end	
	local data = self:getData()
	local runCounterCheck = false
	for _,data in ipairs(data) do 
		if data.runCounter > 0 then 
			runCounterCheck=true
		end
	end
	return runCounterCheck
end

function SiloSelectedFillTypeSetting:isRunCounterActive()
	return self.runCounterActive
end

function SiloSelectedFillTypeSetting:getTexts(index)
	local data = self:getDataByIndex(index)
	
	if data then
		local runCounterText = data.runCounter and data.runCounter.."/"..self.MAX_RUNS or ""
		local maxFillLevelText = data.maxFillLevel and data.maxFillLevel.."%" or ""
		local minFillLevelText = data.minFillLevel and data.minFillLevel.."%" or ""
		return runCounterText,maxFillLevelText,minFillLevelText
	else
		return "","",""
	end
end

function SiloSelectedFillTypeSetting:incrementRunCounter(index)
	local data = self:getDataByIndex(index)
	if data and data.runCounter then 
		if not (data.runCounter >= self.MAX_RUNS) then 
			data.runCounter = data.runCounter+1
			self:sendEvent(self.NetworkTypes.CHANGE_RUNCOUNTER,index,1)
		end
	end
end

function SiloSelectedFillTypeSetting:decrementRunCounterByFillType(lastFillTypes)
	local totalData = self:getData()
	for index,data in ipairs(totalData) do 
		for _,fillType in pairs(lastFillTypes) do
			if data.fillType == fillType then
				self:decrementRunCounter(index)		
			end
		end
	end
end

function SiloSelectedFillTypeSetting:getMaxFillLevelByFillType(fillType)
	local totalData = self:getData()
	for index,data in ipairs(totalData) do 
		if data.fillType == fillType then
			return data.maxFillLevel		
		end
	end
end

function SiloSelectedFillTypeSetting:decrementRunCounter(index)
	local data = self:getDataByIndex(index)
	if data and data.runCounter then 
		if not (data.runCounter <= 0) then 
			data.runCounter = data.runCounter-1
			self:sendEvent(self.NetworkTypes.CHANGE_RUNCOUNTER,index,-1)
		end
	end
end

function SiloSelectedFillTypeSetting:changeMaxFillLevel(index)
	local diff = nil
	if index < 0 then 
		diff=-1
		index = index*(-1)
	else
		diff = 1
	end
	local data = self:getDataByIndex(index)
	if data and data.maxFillLevel then 
		local newDiff = data.maxFillLevel+diff 
		if newDiff >0 and newDiff <=100 then
			data.maxFillLevel = newDiff
			self:sendEvent(self.NetworkTypes.CHANGE_MAX_FILLLEVEL,index,diff)
		end
	end	
end

function SiloSelectedFillTypeSetting:changeMinFillLevel(index)
	local diff = nil
	if index < 0 then 
		diff=-1
		index = index*(-1)
	else
		diff = 1
	end
	local data = self:getDataByIndex(index)
	if data and data.minFillLevel then 
		local newDiff = data.minFillLevel+diff 
		if newDiff >=0 and newDiff <=100 then
			data.minFillLevel = newDiff
			self:sendEvent(self.NetworkTypes.CHANGE_MIN_FILLEVEL,index,diff)
		end
	end	
end

function SiloSelectedFillTypeSetting:changeRunCounter(index)
	local diff = nil
	if index < 0 then 
		diff=-1
		index = index*(-1)
	else
		diff = 1
	end
	local data = self:getDataByIndex(index)
	if data and data.runCounter then 
		local newDiff = data.runCounter+diff 
		if newDiff >=0 and newDiff <=self.MAX_RUNS then
			data.runCounter = newDiff
			self:sendEvent(self.NetworkTypes.CHANGE_RUNCOUNTER,index,diff)
		end
	end	
end

function SiloSelectedFillTypeSetting:setRunCounterFromNetwork(index,value)
	local data = self:getDataByIndex(index)
	if data and data.runCounter then 
		local diff = data.runCounter+value
		if diff >= 0 and diff <=20 then 
			data.runCounter = diff
		end
	end
end

function SiloSelectedFillTypeSetting:setMaxFillLevelFromNetwork(index,value)
	local data = self:getDataByIndex(index)
	if data and data.maxFillLevel then 
		local diff = data.maxFillLevel+value
		if diff >= 1 and diff <=100 then 
			data.maxFillLevel = diff
		end
	end
end

function SiloSelectedFillTypeSetting:setMinFillLevelFromNetwork(index,value)
	local data = self:getDataByIndex(index)
	if data and data.minFillLevel then 
		local diff = data.minFillLevel+value
		if diff >= 0 and diff <=100 then 
			data.minFillLevel = diff
		end
	end
end


function SiloSelectedFillTypeSetting:moveUpByIndex(index,noEventSend)
	LinkedListSetting.moveUpByIndex(self,index)
	if not noEventSend then
		self:sendEvent(self.NetworkTypes.MOVE_UP_X,index)
	end
end

function SiloSelectedFillTypeSetting:moveDownByIndex(index,noEventSend)
	LinkedListSetting.moveDownByIndex(self,index)
	if not noEventSend then
		self:sendEvent(self.NetworkTypes.MOVE_DOWN_X,index)
	end
end

function SiloSelectedFillTypeSetting:deleteByIndex(index,noEventSend)
	LinkedListSetting.deleteByIndex(self,index)
	if not noEventSend then
		self:sendEvent(self.NetworkTypes.DELETE_X,index)
	end
end

function SiloSelectedFillTypeSetting:getKey(parentKey)
	return parentKey .. '.' .. self.xmlKey
end

function SiloSelectedFillTypeSetting:loadFromXml(xml, parentKey)
	local size = Utils.getNoNil(getXMLInt(xml, self:getKey(parentKey)..self.xmlAttributeSize),0)
	if size and size>0 then
		for key=1,size do 
			local elementKey = string.format("%s.element(%d)", self:getKey(parentKey), key-1)
			local selectedFillType = Utils.getNoNil(getXMLInt(xml, elementKey..self.xmlAttributeFillType), 0)
			local counter
			if self.runCounterActive then
				counter = Utils.getNoNil(getXMLInt(xml, elementKey..self.xmlAttributeRunCounter), self.MAX_RUNS)
			end
			local maxLevel = Utils.getNoNil(getXMLInt(xml, elementKey..self.xmlAttributeMaxFillLevel), 100)
			local minLevel = Utils.getNoNil(getXMLInt(xml, elementKey..self.xmlAttributeMinFillLevel), 1)
			if selectedFillType then 
				self:addLast(self:fillTypeDataToAdd(selectedFillType,counter,maxLevel,minLevel))
			end
		end
	end
end

function SiloSelectedFillTypeSetting:saveToXml(xml, parentKey)
	local size = self:getSize()
	setXMLInt(xml, self:getKey(parentKey)..self.xmlAttributeSize, Utils.getNoNil(size,0))
	if size > 0 then 
		for key,data in ipairs(self:getData()) do
			local elementKey = string.format("%s.element(%d)", self:getKey(parentKey), key-1)
			setXMLInt(xml, elementKey..self.xmlAttributeFillType, Utils.getNoNil(data.fillType,0))
			if self.runCounterActive then
				setXMLInt(xml, elementKey..self.xmlAttributeRunCounter, Utils.getNoNil(data.runCounter,self.MAX_RUNS))
			end
			setXMLInt(xml, elementKey..self.xmlAttributeMaxFillLevel, Utils.getNoNil(data.maxFillLevel,100))
			setXMLInt(xml, elementKey..self.xmlAttributeMinFillLevel, Utils.getNoNil(data.minFillLevel,1))
		end
	end
end

function SiloSelectedFillTypeSetting:onWriteStream(stream)
	local size = self:getSize() or 0
	streamDebugWriteInt32(stream, size)
	streamDebugWriteBool(stream,self.runCounterActive)
	if size > 0 then 
		for key,data in ipairs(self:getData()) do
			streamDebugWriteInt32(stream, data.fillType)
			if self.runCounterActive then
				streamDebugWriteInt32(stream, data.runCounter)
			end
			streamDebugWriteInt32(stream, data.maxFillLevel)
			streamDebugWriteInt32(stream, data.minFillLevel)
		end
	end
end

function SiloSelectedFillTypeSetting:onReadStream(stream)
	local size = streamDebugReadInt32(stream)
	self.runCounterActive = streamDebugReadBool(stream)
	if size and size>0 then
		for key=1,size do 
			local selectedFillType = streamDebugReadInt32(stream)
			local counter
			if self.runCounterActive then
				counter = streamDebugReadInt32(stream)
			end
			local maxLevel = streamDebugReadInt32(stream)
			local minLevel = streamDebugReadInt32(stream)
			if selectedFillType then 
				self:addLast(self:fillTypeDataToAdd(selectedFillType,counter,maxLevel,minLevel))
			end
		end
	end
end

---@class TurnOnFieldSetting : BooleanSetting
TurnOnFieldSetting = CpObject(BooleanSetting)
function TurnOnFieldSetting:init(vehicle)
	BooleanSetting.init(self, 'turnOnField','COURSEPLAY_TURN_ON_FIELD', 'COURSEPLAY_TURN_ON_FIELD', vehicle) 
	self:set(true)
end

---@class TurnStageSetting : BooleanSetting
TurnStageSetting = CpObject(BooleanSetting)
function TurnStageSetting:init(vehicle)
	BooleanSetting.init(self, 'turnStage','COURSEPLAY_TURN_MANEUVER', 'COURSEPLAY_TURN_MANEUVER', vehicle, {'COURSEPLAY_START','COURSEPLAY_FINISH'}) 
	self:set(false)
end

---@class RefillUntilPctSetting : PercentageSettingList
RefillUntilPctSetting = CpObject(PercentageSettingList)
function RefillUntilPctSetting:init(vehicle)
	PercentageSettingList.init(self, 'refillUntilPct', 'COURSEPLAY_REFILL_UNTIL_PCT', 'COURSEPLAY_REFILL_UNTIL_PCT', vehicle)
	self:set(100)
end

---@class DriveOnAtFillLevelSetting : PercentageSettingList
DriveOnAtFillLevelSetting = CpObject(PercentageSettingList)
function DriveOnAtFillLevelSetting:init(vehicle)
	PercentageSettingList.init(self, 'driveOnAtFillLevel', 'COURSEPLAY_DRIVE_ON_AT', 'COURSEPLAY_DRIVE_ON_AT', vehicle)
	self:set(90)
end

---@class FollowAtFillLevelSetting : PercentageSettingList
FollowAtFillLevelSetting = CpObject(PercentageSettingList)
function FollowAtFillLevelSetting:init(vehicle)
	PercentageSettingList.init(self, 'followAtFillLevel', 'COURSEPLAY_START_AT', 'COURSEPLAY_START_AT', vehicle)
	self:set(50)
end

---@class MoveOnAtFillLevelSetting : PercentageSettingList
MoveOnAtFillLevelSetting = CpObject(PercentageSettingList)
function MoveOnAtFillLevelSetting:init(vehicle)
	PercentageSettingList.init(self, 'moveOnAtFillLevel', 'COURSEPLAY_MOVE_ON_AT', 'COURSEPLAY_MOVE_ON_AT', vehicle)
	self:set(5)
end

--separate SiloSelectedFillTypeSettings to save their current state
--and disable runCounter for FillableFieldWorkDriver and FieldSupplyDriver

--TODO: figure out how to implement maxFillLevel for separate FillTypes in mode 1 
---@class GrainTransportDriver_SiloSelectedFillTypeSetting : SiloSelectedFillTypeSetting
GrainTransportDriver_SiloSelectedFillTypeSetting = CpObject(SiloSelectedFillTypeSetting)
function GrainTransportDriver_SiloSelectedFillTypeSetting:init(vehicle)
	SiloSelectedFillTypeSetting.init(self, vehicle, "GrainTransportDriver")
	self.MAX_FILLTYPES = 5
	self.disallowedFillTypes = {FillType.AIR}
end

---@class FillableFieldWorkDriver_SiloSelectedFillTypeSetting : SiloSelectedFillTypeSetting
FillableFieldWorkDriver_SiloSelectedFillTypeSetting = CpObject(SiloSelectedFillTypeSetting)
function FillableFieldWorkDriver_SiloSelectedFillTypeSetting:init(vehicle)
	SiloSelectedFillTypeSetting.init(self, vehicle, "FillableFieldWorkDriver")
	self.runCounterActive = false
	self.disallowedFillTypes = {FillType.DIESEL, FillType.DEF,FillType.AIR}
end

---@class FieldSupplyDriver_SiloSelectedFillTypeSetting : SiloSelectedFillTypeSetting
FieldSupplyDriver_SiloSelectedFillTypeSetting = CpObject(SiloSelectedFillTypeSetting)
function FieldSupplyDriver_SiloSelectedFillTypeSetting:init(vehicle)
	SiloSelectedFillTypeSetting.init(self, vehicle, "FieldSupplyDriver")
	self.runCounterActive = false
	self.disallowedFillTypes = {FillType.DEF,FillType.AIR}
end

---@class ShovelModeDriver_SiloSelectedFillTypeSetting : SiloSelectedFillTypeSetting
ShovelModeDriver_SiloSelectedFillTypeSetting = CpObject(SiloSelectedFillTypeSetting)
function ShovelModeDriver_SiloSelectedFillTypeSetting:init(vehicle)
	SiloSelectedFillTypeSetting.init(self, vehicle, "ShovelModeDriver")
	self.MAX_FILLTYPES = 1
	self.disallowedFillTypes = {FillType.DEF,FillType.AIR}
end

---@class ShovelModeAIDriverTriggerHandlerIsActive : BooleanSetting
ShovelModeAIDriverTriggerHandlerIsActive = CpObject(BooleanSetting)
function ShovelModeAIDriverTriggerHandlerIsActive:init(vehicle)
	BooleanSetting.init(self, 'shovelModeAIDriverTriggerHandlerIsActive','COURSEPLAY_SHOVEL_TRIGGERHANDLER_IS_ACTIVE', 'COURSEPLAY_SHOVEL_TRIGGERHANDLER_IS_ACTIVE', vehicle) 
	self:set(false)
end

function ShovelModeAIDriverTriggerHandlerIsActive:isDisabled()
	if self.vehicle.cp.mode ~= courseplay.MODE_SHOVEL_FILL_AND_EMPTY then 
		return true
	end
	return false
end

function ShovelModeAIDriverTriggerHandlerIsActive:onChange()
	if self.vehicle.cp.mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY then
		courseplay:setAIDriver(self.vehicle, courseplay.MODE_SHOVEL_FILL_AND_EMPTY)
	end	
	BooleanSetting.onChange(self)
end

---@class SeparateFillTypeLoadingSetting : SettingList
SeparateFillTypeLoadingSetting = CpObject(SettingList)
SeparateFillTypeLoadingSetting.DEACTIVED = 0
function SeparateFillTypeLoadingSetting:init(vehicle)
	SettingList.init(self, 'separateFillTypeLoading', 'COURSEPLAY_LOADING_SEPARATE_FILLTYPES', 'COURSEPLAY_LOADING_SEPARATE_FILLTYPES', vehicle,
		{ 
			SeparateFillTypeLoadingSetting.DEACTIVED,
			2,
			3
		},
		{ 	
			'COURSEPLAY_DEACTIVATED',
			'COURSEPLAY_LOADING_SEPARATE_FILLTYPES_TRAILERS',
			'COURSEPLAY_LOADING_SEPARATE_FILLTYPES_TRAILERS'
		}
		)
	self:set(1)
end

function SeparateFillTypeLoadingSetting:hasDiffFillTypes()
	return self.current>1
end

function SeparateFillTypeLoadingSetting:checkAndSetValidValue(new)
	local diff = new<1 and #self.values or new
	if diff > self:getSeparateFillUnits()  then 
		return 1
	else 
		return SettingList.checkAndSetValidValue(self, new)
	end
end

--gets separate FillUnits example Wilson == 2
function SeparateFillTypeLoadingSetting:getSeparateFillUnits()
	local TrailerInfo = {}
	TrailerInfo.fillUnits = 0
	self:getTrailerFillUnitCount(self.vehicle,TrailerInfo)
	return TrailerInfo.fillUnits
end

function SeparateFillTypeLoadingSetting:getTrailerFillUnitCount(object,TrailerInfo)
	if self:hasNeededSpec(object,Dischargeable) and self:hasNeededSpec(object,Trailer) and not self:hasNeededSpec(object,Pipe) then 
		if object.getFillUnits then 
			for _, fillUnit in pairs(object:getFillUnits()) do
				TrailerInfo.fillUnits = TrailerInfo.fillUnits + 1
			end
		end
	end
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getTrailerFillUnitCount(impl.object, TrailerInfo)
	end
end

function SeparateFillTypeLoadingSetting:hasNeededSpec(object,spec)
	if SpecializationUtil.hasSpecialization(spec, object.specializations) then
		return true
	end
end

function SeparateFillTypeLoadingSetting:getText()
	return self.current>1 and courseplay:loc(self.texts[self.current])..self:get() or SettingList.getText(self)
end

function SeparateFillTypeLoadingSetting:isActive()
	if self.vehicle.cp.driver:is_a(GrainTransportAIDriver) and not self.vehicle.cp.driver:getSiloSelectedFillTypeSetting():isEmpty() then 
		return true
	end
end

---@class ForcedToStopSetting : BooleanSetting
ForcedToStopSetting = CpObject(BooleanSetting)
function ForcedToStopSetting:init(vehicle)
	BooleanSetting.init(self, 'forcedToStop','--', '--', vehicle,{'COURSEPLAY_UNLOADING_DRIVER_STOP','COURSEPLAY_UNLOADING_DRIVER_START'}) 
	self:set(false)
end

---

---@class ReverseSpeedSetting : SpeedSetting
ReverseSpeedSetting = CpObject(SpeedSetting)
function ReverseSpeedSetting:init(vehicle)
	SpeedSetting.init(self, 'reverseSpeed','COURSEPLAY_SPEED_REVERSING', 'COURSEPLAY_SPEED_REVERSING', vehicle,3,(vehicle:getCruiseControlMaxSpeed() or 60)) 
	self:set(6)
end

function ReverseSpeedSetting:onChange()
	self.vehicle.cp.speeds.reverse = self:get()
end

---@class TurnSpeedSetting : SpeedSetting
TurnSpeedSetting = CpObject(SpeedSetting)
function TurnSpeedSetting:init(vehicle)
	SpeedSetting.init(self, 'turnSpeed','COURSEPLAY_SPEED_TURN', 'COURSEPLAY_SPEED_TURN', vehicle,3,(vehicle:getCruiseControlMaxSpeed() or 60)) 
	self:set(10)
end

function TurnSpeedSetting:onChange()
	self.vehicle.cp.speeds.turn = self:get()
end

---@class FieldSpeedSettting : SpeedSetting
FieldSpeedSettting = CpObject(SpeedSetting)
function FieldSpeedSettting:init(vehicle)
	SpeedSetting.init(self, 'fieldSpeed','COURSEPLAY_SPEED_FIELD', 'COURSEPLAY_SPEED_FIELD', vehicle,3,(vehicle:getCruiseControlMaxSpeed() or 60)) 
	self:set(24)
end

function FieldSpeedSettting:onChange()
	self.vehicle.cp.speeds.field = self:get()
end

---@class StreetSpeedSetting : SpeedSetting
StreetSpeedSetting = CpObject(SpeedSetting)
function StreetSpeedSetting:init(vehicle)
	SpeedSetting.init(self, 'streetSpeed','COURSEPLAY_SPEED_MAX', 'COURSEPLAY_SPEED_MAX', vehicle,3,(vehicle:getCruiseControlMaxSpeed() or 60)) 
	self:set(vehicle:getCruiseControlMaxSpeed() or 50)
end

function StreetSpeedSetting:getText()
	if self.vehicle.cp.settings.useRecordingSpeed:is(true) then 
		return courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_AUTOMATIC'):format(SpeedSetting.getText(self))
	else 
		return SpeedSetting.getText(self)
	end	
end

function StreetSpeedSetting:onChange()
	self.vehicle.cp.speeds.street = self:get()
end


---@class BunkerSpeedSetting : SpeedSetting
BunkerSpeedSetting = CpObject(SpeedSetting)
---@param vehicle table
---@param levelCompactModeSetting LevelCompactModeSetting
function BunkerSpeedSetting:init(vehicle, levelCompactModeSetting)
	self.levelCompactModeSetting = levelCompactModeSetting
	SpeedSetting.init(self, 'bunkerSpeed','COURSEPLAY_MODE10_MAX_BUNKERSPEED', 'COURSEPLAY_MODE10_MAX_BUNKERSPEED', vehicle,5,20)
	self:set(10)
	self.MAX_SPEED_LEVELING = 10
end

function BunkerSpeedSetting:checkAndSetValidValue(x)
	local new = SettingList.checkAndSetValidValue(self, x)
	if self.levelCompactModeSetting:hasLeveler() then
		if new > self.MAX_SPEED_LEVELING then 
			return 10
		end
	end 
	return new
end

function BunkerSpeedSetting:onChange()
	self.vehicle.cp.speeds.bunkerSpeed = self:get()
end

function BunkerSpeedSetting:getText()
	if self.isAutomaticActive() then 
		return courseplay:loc('COURSEPLAY_AUTOMATIC')
	else 
		return SpeedSetting.getText(self)
	end
end

function BunkerSpeedSetting:isAutomaticActive()
	return false
end

--[[
---@class CrawlSpeedSetting : SpeedSetting
CrawlSpeedSetting = CpObject(SpeedSetting)
function CrawlSpeedSetting:init(vehicle)
	SpeedSetting.init(self, 'crawlSpeed','COURSEPLAY_MODE10_MAX_BUNKERSPEED', 'COURSEPLAY_MODE10_MAX_BUNKERSPEED', vehicle,3,20) 
	
end

---@class DischargeSpeedSetting : SpeedSetting
DischargeSpeedSetting = CpObject(SpeedSetting)
function DischargeSpeedSetting:init(vehicle)
	SpeedSetting.init(self, 'dischargeSpeed','COURSEPLAY_MODE10_MAX_BUNKERSPEED', 'COURSEPLAY_MODE10_MAX_BUNKERSPEED', vehicle,3,20) 
	
end

---@class ApproachSpeedSetting : SpeedSetting
ApproachSpeedSetting = CpObject(SpeedSetting)
function ApproachSpeedSetting:init(vehicle)
	SpeedSetting.init(self, 'approachSpeed','COURSEPLAY_MODE10_MAX_BUNKERSPEED', 'COURSEPLAY_MODE10_MAX_BUNKERSPEED', vehicle,3,20) 
	
end
]]--

---@class AssignedCombinesSetting : Setting
AssignedCombinesSetting = CpObject(Setting)
AssignedCombinesSetting.NetworkTypes = {}
AssignedCombinesSetting.NetworkTypes.TOGGLE = 0
AssignedCombinesSetting.NetworkTypes.CHANGE_OFFSET = 1
function AssignedCombinesSetting:init(vehicle)
	Setting.init(self, 'assignedCombines','-', '-', vehicle) 
	self.MAX_COMBINES_FOR_PAGE = 5
	self.offsetHead = 0
	-- table has key (the combine's vehicle) with all combines assigned to this unloader in the HUD, value is true
	self.table = {}
	self.lastPossibleCombines = {}
end

function AssignedCombinesSetting:getPossibleCombines()
	return g_combineUnloadManager:getPossibleCombines(self.vehicle)
end

function AssignedCombinesSetting:onReadStream(streamId)
	while streamReadBool(streamId) do 
		if self.combineIDs == nil then
			self.combineIDs = {}
		end
		local combineId = NetworkUtil.readNodeObjectId(streamId)
		self.combineIDs[combineId] = true
	end
end

-- while onReadStream not every vehicle is created,
-- so assign them after every vehicle is init with the NetworkIds
function AssignedCombinesSetting:fixOnReadStream()
	if self.combineIDs and next(self.combineIDs) then 
		for combineId,isAssigned in pairs(self.combineIDs) do
			local combine = NetworkUtil.getObject(combineId)
			self.table[combine] = true
		end
		self.combineIDs = nil
	end
end

function AssignedCombinesSetting:onWriteStream(streamId)
	for combine,isAssigned in pairs(self.table) do 
		if isAssigned then 
			streamWriteBool(streamId, true)
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(combine))
		end
	end
	streamWriteBool(streamId, false)
end

--enables/disables connection between combine/tractor
function AssignedCombinesSetting:toggleAssignedCombine(index)
	local newIndex = index-2+self.offsetHead
	local possibleCombines = self:getPossibleCombines()
	local combine =	possibleCombines[newIndex]
	self:fixOnReadStream()
	if combine then 
		if self.table[combine] then 
			self.table[combine] = nil
		else
			self.table[combine] = true
		end
		AssignedCombinesEvents.sendEvent(self.vehicle,combine)
		self.vehicle.cp.driver:refreshHUD()
	end
end

function AssignedCombinesSetting:toggleAssignedCombineFromNetwork(combine)
	self:fixOnReadStream()
	if self.table[combine] then 
		self.table[combine] = nil
	else
		self.table[combine] = true
	end
	self.vehicle.cp.driver:refreshHUD()
end

function AssignedCombinesSetting:getTexts()
	self:fixOnReadStream()
	local x = 1+self.offsetHead
	local line = 1
	local texts = {}
	for i=x,self.MAX_COMBINES_FOR_PAGE+x do 
		local possibleCombines = self:getPossibleCombines()
		self:clearInactiveCombines(possibleCombines)
		if possibleCombines[i] then
			local combine = possibleCombines[i]
			local fieldNumber = g_combineUnloadManager:getFieldNumber(combine)
			local box = self.table[combine] and "[X]"or "[  ]"
			local text = string.format("%s %s (Field %d)",box, combine.name , fieldNumber)
			texts[line] = text
		else
			texts[line] = ""
		end
		line = line +1
	end
	return texts
end

--removes inactive combines connections 
function AssignedCombinesSetting:clearInactiveCombines(possibleCombines)
	local validCombines = {}
	for index, combine in pairs(possibleCombines) do 
		if self.table[combine] then 
			validCombines[combine] = true
		end
	end
	self.table = validCombines
	self.vehicle.cp.driver:refreshHUD()
end

function AssignedCombinesSetting:allowedToChangeListOffsetUp()
	local possibleCombines = self:getPossibleCombines()
	return #possibleCombines-self.offsetHead > self.MAX_COMBINES_FOR_PAGE 
end

function AssignedCombinesSetting:allowedToChangeListOffsetDown()
	return self.offsetHead >0
end

--move List up/down
function AssignedCombinesSetting:changeListOffset(x,noEventSend)	
	if x>0 and self:allowedToChangeListOffsetUp() then 
		self.offsetHead = self.offsetHead+1
	elseif x<0 and self:allowedToChangeListOffsetDown() then 
		self.offsetHead = self.offsetHead-1
	end
	self.vehicle.cp.driver:refreshHUD()
end

function AssignedCombinesSetting:getData()
	return self.table
end

function AssignedCombinesSetting:__tostring()
	local ret = 'assigned combines: '
	local list = ''
	for combine, _ in pairs(self.table) do
		list = list .. nameNum(combine) .. ', '
	end
	if list == '' then list = 'none' end
	return ret .. list
end

function AssignedCombinesSetting:selectClosest()
	local dMin = math.huge
	local closestCombine
	for _, combine in pairs(self:getPossibleCombines()) do
		local d = calcDistanceFrom(self.vehicle.rootNode, combine.rootNode)
		if d < dMin then
			dMin = d
			closestCombine = combine
		end
	end
	if closestCombine then
		self.table[closestCombine] = true
	end
	self.vehicle.cp.driver:refreshHUD()
end

---@class ShowVisualWaypointsSetting : SettingList
ShowVisualWaypointsSetting = CpObject(SettingList)
ShowVisualWaypointsSetting.DEACTIVED = 0
ShowVisualWaypointsSetting.START_STOP = 1
ShowVisualWaypointsSetting.ALL = 3
function ShowVisualWaypointsSetting:init(vehicle)
	SettingList.init(self, 'showVisualWaypoints', 'COURSEPLAY_WAYPOINT_MODE', 'COURSEPLAY_WAYPOINT_MODE', vehicle,
		{ 
			ShowVisualWaypointsSetting.DEACTIVED,
			ShowVisualWaypointsSetting.START_STOP,
			ShowVisualWaypointsSetting.ALL 
		}
		)
	self:set(1)
	self.syncValue = false
end

function ShowVisualWaypointsSetting:onChange()
	courseplay.signs:setSignsVisibility(self.vehicle)
end

---@class ShowVisualWaypointsCrossPointSetting : BooleanSetting
ShowVisualWaypointsCrossPointSetting = CpObject(BooleanSetting)
function ShowVisualWaypointsCrossPointSetting:init(vehicle)
	BooleanSetting.init(self, 'showVisualWaypointsCrossPoint','-', '-', vehicle) 
	self:set(false)
	self.syncValue = false
end
function ShowVisualWaypointsCrossPointSetting:onChange()
	courseplay.signs:setSignsVisibility(self.vehicle)
end

---@class ConvoyActiveSetting : BooleanSetting
ConvoyActiveSetting = CpObject(BooleanSetting)
function ConvoyActiveSetting:init(vehicle)
	BooleanSetting.init(self, 'convoyActive','COURSEPLAY_COMBINE_CONVOY', 'COURSEPLAY_COMBINE_CONVOY', vehicle) 
	self:set(false)
end

--not sure if this one would still be needed ??
---@class ConvoyMaxDistanceSetting : IntSetting
ConvoyMaxDistanceSetting = CpObject(IntSetting)
function ConvoyMaxDistanceSetting:init(vehicle)
	IntSetting.init(self, 'convoyMaxDistance','COURSEPLAY_CONVOY_MAX_DISTANCE', 'COURSEPLAY_CONVOY_MAX_DISTANCE', vehicle,40,3000) 
	self:set(300)
end

function ConvoyMaxDistanceSetting:getText()
	return string.format('%d%s', self:get(),courseplay:loc('COURSEPLAY_UNIT_METER'));
end

---@class ConvoyMinDistanceSetting : IntSetting
ConvoyMinDistanceSetting = CpObject(IntSetting)
function ConvoyMinDistanceSetting:init(vehicle)
	IntSetting.init(self, 'convoyMinDistance','COURSEPLAY_CONVOY_MIN_DISTANCE', 'COURSEPLAY_CONVOY_MIN_DISTANCE', vehicle,10,2000) 
	self:set(100)
end

function ConvoyMinDistanceSetting:getText()
	return string.format('%d%s', self:get(),courseplay:loc('COURSEPLAY_UNIT_METER'));
end

---@class OppositeTurnModeSetting : BooleanSetting
OppositeTurnModeSetting = CpObject(BooleanSetting)
function OppositeTurnModeSetting:init(vehicle)
	BooleanSetting.init(self, 'oppositeTurnMode','COURSEPLAY_OPPOSITE_TURN_DIRECTION', 'COURSEPLAY_OPPOSITE_TURN_DIRECTION', vehicle,{'COURSEPLAY_OPPOSITE_TURN_AT_END','COURSEPLAY_OPPOSITE_TURN_WHEN_POSSIBLE'}) 
	self:set(false)
end

---@class WorkingToolPositionsSetting : Setting
---@param totalPositionsAmount number of possible postions
---@param validSpecs allowed Specializations of objects that get saved, nil = every object
WorkingToolPositionsSetting = CpObject(Setting)
WorkingToolPositionsSetting.NetworkTypes = {}
WorkingToolPositionsSetting.NetworkTypes.SET_OR_CLEAR_POSITION = 0
WorkingToolPositionsSetting.NetworkTypes.PLAY_POSITION = 1
function WorkingToolPositionsSetting:init(name, label, toolTip, vehicle,totalPositionsAmount,validSpecs)
	Setting.init(self, name,label, toolTip, vehicle)
	self.texts = {}
	self.hasPosition = {}
	self.totalPositions = totalPositionsAmount or 4
	self.playTestPostion = nil
	self.validSpecs = validSpecs
	self.xmlAttribute = '#hasPositions'
	self.MAX_ROT_SPEED = 0.7
	self.MIN_ROT_SPEED = 0.1
	self.MAX_TRANS_SPEED = 0.7
	self.MIN_TRANS_SPEED = 0.2
end

function WorkingToolPositionsSetting:getTexts()
	local texts = {}
	for i=1,self.totalPositions do 
		local text = ""
		if self.hasPosition[i] then 
			text = "ok"
		end
		texts[i] = text
	end
	return texts
end

--save or delete tool position x
function WorkingToolPositionsSetting:setOrClearPostion(x,noEventSend) 
	if self.hasPosition[x] then 
		self.hasPosition[x] = nil
		if g_server then 
			self:clearPosition(self.vehicle,x)
		end
	else 
		self.hasPosition[x] = true
		if g_server then 
			self:savePosition(self.vehicle,x)
		end
	end
	if not noEventSend then
		WorkingToolPositionsEvents.sendEvent(self.vehicle,self.name,self.NetworkTypes.SET_OR_CLEAR_POSITION,x)
	end
	self.vehicle.cp.driver:refreshHUD()
end


--save tool postions for all valid objects recursive
function WorkingToolPositionsSetting:savePosition(object,posX)
	local spec = object.spec_cylindered
	if spec and self:isValidSpec(object) then 
		if spec.cpWorkingToolPos == nil then 
			spec.cpWorkingToolPos = {}
		end
		local objectPos = {}
		for toolIndex, tool in ipairs(spec.movingTools) do
			objectPos[toolIndex] = {}
			objectPos[toolIndex].curRot = tool.curRot[tool.rotationAxis]
			objectPos[toolIndex].curTrans = tool.curTrans[tool.translationAxis]
		end
		spec.cpWorkingToolPos[posX] = objectPos
		if spec.cpWorkingToolPosMax == nil then 
			spec.cpWorkingToolPosMax = self.totalPositions
		end
	end	
	for _,impl in pairs(object:getAttachedImplements()) do
		self:savePosition(impl.object,posX)
	end
end

function WorkingToolPositionsSetting:clearPosition(object,posX)
	local spec = object.spec_cylindered
	if spec and spec.cpWorkingToolPos then 
		if spec.cpWorkingToolPos[posX] then 
			spec.cpWorkingToolPos[posX] = nil
		end
	end	
	for _,impl in pairs(object:getAttachedImplements()) do
		self:clearPosition(impl.object,posX)
	end
end

-- play position manually
function WorkingToolPositionsSetting:playPosition(x)
	if g_server then
		if self.hasPosition[x] then
			self.playTestPostion = x
		end
	else 
		WorkingToolPositionsEvents.sendEvent(self.vehicle,self.name,self.NetworkTypes.PLAY_POSITION,x)
	end
end

--called every frame to update positions 
--also gets called in base.lua for player manual postitions
function WorkingToolPositionsSetting:updatePositions(dt,posX)
	callback = {}
	local nextPosX = self.hasPosition[posX] and posX or self.playTestPostion and self.hasPosition[self.playTestPostion] and self.playTestPostion
	if nextPosX == nil then 
		return
	end
	self:updateAndSetPosition(self.vehicle,dt,nextPosX,callback)
	if not callback.isDirty then
		self.playTestPostion = nil
	end
	return not callback.isDirty
end

--update tool postions for all valid objects recursive to position "pos"
function WorkingToolPositionsSetting:updateAndSetPosition(object,dt,posX,callback)
	local spec = object.spec_cylindered 
	if spec and spec.cpWorkingToolPos and spec.cpWorkingToolPos[posX] and self:isValidSpec(object) then 
		local isDirty
		for toolIndex, tool in ipairs(spec.movingTools) do
			if self.checkToolRotation(object,tool,toolIndex,posX,dt,self) then
				isDirty = true
			end
			if self.checkToolTranslation(object,tool,toolIndex,posX,dt,self) then
				isDirty = true
			end		
			if isDirty then 
				callback.isDirty = true
			end
		end
	end
	for _,impl in pairs(object:getAttachedImplements()) do
		self:updateAndSetPosition(impl.object, dt,posX,callback)
	end
end

--use tool.move as if we are a player using mouse/axis ..
function WorkingToolPositionsSetting.checkToolRotation(self,tool,toolIndex,posX,dt,setting)
	local spec = self.spec_cylindered
	if tool.rotSpeed == nil then
		return
	end
	
	local curRot = { getRotation(tool.node) }
	local newRot = curRot[tool.rotationAxis]
	-- speed for frontloader, shovel, etc achses
	cpDiff = spec.cpWorkingToolPos[posX][toolIndex].curRot - newRot
	local rotSpeed = math.min(math.max(setting.MIN_ROT_SPEED,math.abs(cpDiff*5)),setting.MAX_ROT_SPEED)--0.7
	if math.abs(cpDiff) > 0.003 then
		if cpDiff < 0 then
			rotSpeed=rotSpeed*(-1)
		end
	else 
		tool.move = 0
		return false
	end
	tool.move = rotSpeed
	if tool.move ~= tool.moveToSend then
		tool.moveToSend = tool.move
		self:raiseDirtyFlags(spec.cylinderedInputDirtyFlag)
	end
    return true
end

--use tool.move as if we are a player using mouse/axis ..
function WorkingToolPositionsSetting.checkToolTranslation(self,tool,toolIndex,posX,dt,setting)	
	local spec = self.spec_cylindered
	if tool.transSpeed == nil then
		return
	end
	
	local curTrans = { getTranslation(tool.node) }
	local newTrans = curTrans[tool.translationAxis]
	-- speed for telescope arm
	cpDiff = spec.cpWorkingToolPos[posX][toolIndex].curTrans - newTrans
	local transSpeed = math.min(math.max(setting.MIN_TRANS_SPEED,math.abs(cpDiff*5)),setting.MAX_TRANS_SPEED)--0.5
	if math.abs(cpDiff) > 0.003 then
		if cpDiff < 0 then
			transSpeed=transSpeed*(-1)
		end
	else 
		tool.move = 0
		return false
	end
	tool.move = transSpeed
	if tool.move ~= tool.moveToSend then
		tool.moveToSend = tool.move
		self:raiseDirtyFlags(spec.cylinderedInputDirtyFlag)
	end
    return true
end

function WorkingToolPositionsSetting:isValidSpec(object)
	if self.validSpecs == nil then 
		return true
	end	
	for _,spec in pairs(self.validSpecs) do
		if SpecializationUtil.hasSpecialization(spec, object.specializations)  then 
			return true
		end
	end	
end

function WorkingToolPositionsSetting:hasValidToolPositions()
	return #self.hasPosition == self.totalPositions
end

function WorkingToolPositionsSetting:getTotalPositions()
	return self.totalPositions
end

function WorkingToolPositionsSetting:onWriteStream(streamId)
	for i=1,self.totalPositions do 
		streamWriteBool(streamId,self.hasPosition[i]==true)
	end
end

function WorkingToolPositionsSetting:onReadStream(streamId)
	for i=1,self.totalPositions do 
		self.hasPosition[i] = streamReadBool(streamId)
	end
end

function WorkingToolPositionsSetting:loadFromXml(xml, parentKey)
	local value = getXMLBool(xml, self:getKey(parentKey))
	if value then
		for i=1,self.totalPositions do 
			self.hasPosition[i] = true
		end
	end
end

function WorkingToolPositionsSetting:saveToXml(xml, parentKey)
	setXMLBool(xml, self:getKey(parentKey), self:hasValidToolPositions())
end

function WorkingToolPositionsSetting:devSetMaxRotSpeed(x)
	if x ~= nil and type(x) == "number" then
		self.MAX_ROT_SPEED = x
	end
end

function WorkingToolPositionsSetting:devSetMinRotSpeed(x)
	if x ~= nil and type(x) == "number" then
		self.MIN_ROT_SPEED = x
	end
end

function WorkingToolPositionsSetting:devSetMaxTransSpeed(x)
	if x ~= nil and type(x) == "number" then
		self.MAX_TRANS_SPEED = x
	end
end

function WorkingToolPositionsSetting:devSetMinTransSpeed(x)
	if x ~= nil and type(x) == "number" then
		self.MIN_TRANS_SPEED = x
	end
end

function WorkingToolPositionsSetting:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_cylindered
	if spec.cpWorkingToolPos == nil or #spec.cpWorkingToolPos < spec.cpWorkingToolPosMax then 
		return 
	end
	for positionIndex, movingTools in ipairs(spec.cpWorkingToolPos) do 
		local positionKey = string.format("%s.cpWorkingToolPos(%d)", key, positionIndex)
		for toolIndex, objectPos in ipairs(movingTools) do
			local toolKey = string.format("%s.movingTool(%d)", positionKey, toolIndex)
			if objectPos.curRot then
				setXMLFloat(xmlFile, toolKey.."#rotation", objectPos.curRot)
			end
			if objectPos.curTrans then
				setXMLFloat(xmlFile, toolKey.."#translation", objectPos.curTrans)
			end
		end
	end
end
Cylindered.saveToXMLFile = Utils.appendedFunction(Cylindered.saveToXMLFile,WorkingToolPositionsSetting.saveToXMLFile)

function WorkingToolPositionsSetting:onLoad(savegame)
	local spec = self.spec_cylindered
	local posIndex = 1
	if savegame == nil then 
		return
	end
	while true do
		local baseKey = string.format("%s.cylindered.cpWorkingToolPos(%d)",savegame.key, posIndex)
		if not hasXMLProperty(savegame.xmlFile, baseKey) then
			break
		end
		if spec.cpWorkingToolPos == nil then 
			spec.cpWorkingToolPos = {}
		end
		if spec.cpWorkingToolPos[posIndex] == nil then 
			spec.cpWorkingToolPos[posIndex] = {}
		end
		local toolIndex=0
		while true do
			local toolKey = string.format("%s.movingTool(%d)", baseKey, toolIndex)
			if not hasXMLProperty(savegame.xmlFile, toolKey) then
				break
			end
			if spec.cpWorkingToolPos[posIndex][toolIndex] == nil then 
				spec.cpWorkingToolPos[posIndex][toolIndex] = {}
			end
			local newCurRot = getXMLFloat(savegame.xmlFile, toolKey.."#rotation")
			if newCurRot ~= nil then 
				spec.cpWorkingToolPos[posIndex][toolIndex].curRot = newCurRot
			end
			local newTrans = getXMLFloat(savegame.xmlFile, toolKey.."#translation")
			if newTrans ~= nil then
				spec.cpWorkingToolPos[posIndex][toolIndex].curTrans = newTrans
			end
			toolIndex = toolIndex + 1
		end
		posIndex = posIndex + 1
	end
	if spec.cpWorkingToolPos then
		spec.cpWorkingToolPosMax = posIndex-1
	end	
end
Cylindered.onLoad = Utils.appendedFunction(Cylindered.onLoad,WorkingToolPositionsSetting.onLoad)

---@class FrontloaderToolPositionsSetting : WorkingToolPositionsSetting
FrontloaderToolPositionsSetting = CpObject(WorkingToolPositionsSetting)
function FrontloaderToolPositionsSetting:init(vehicle)
	local label = "front"
	local toolTip = "front"
	WorkingToolPositionsSetting.init(self,"frontloaderToolPositions", label, toolTip, vehicle,4)
end

---@class AugerPipeToolPositionsSetting : WorkingToolPositionsSetting
AugerPipeToolPositionsSetting = CpObject(WorkingToolPositionsSetting)
function AugerPipeToolPositionsSetting:init(vehicle)
	local label = "pipe"
	local toolTip = "pipe"
	local validSpecs = {Pipe}
	WorkingToolPositionsSetting.init(self,"augerPipeToolPositions", label, toolTip, vehicle,1,validSpecs)
end

function AugerPipeToolPositionsSetting:getText()
	if self.hasPosition[1] then 
		return "ok"
	end
end

---@class ShovelStopAndGoSetting : BooleanSetting
ShovelStopAndGoSetting = CpObject(BooleanSetting)
function ShovelStopAndGoSetting:init(vehicle)
	BooleanSetting.init(self, 'shovelStopAndGo','COURSEPLAY_SHOVEL_STOP_AND_GO', 'COURSEPLAY_SHOVEL_STOP_AND_GO', vehicle) 
	self:set(true)
end

---@class LevelCompactModeSetting : SettingList
LevelCompactModeSetting = CpObject(SettingList)
LevelCompactModeSetting.COMPACTING = 1
LevelCompactModeSetting.LEVELING = 2
LevelCompactModeSetting.FILLING = 3
function LevelCompactModeSetting:init(vehicle)
	SettingList.init(self, 'levelCompactMode', 'COURSEPLAY_MODE10_MODE', 'COURSEPLAY_MODE10_MODE', vehicle,
		{ 
			LevelCompactModeSetting.COMPACTING,
			LevelCompactModeSetting.LEVELING,
			LevelCompactModeSetting.FILLING 
		},
		{
			'COURSEPLAY_MODE10_MODE_COMPACTING',
			'COURSEPLAY_MODE10_MODE_LEVELING',
			'COURSEPLAY_MODE10_MODE_BUILDUP'
		}
		)
end

---SettingList.checkAndSetValidValue(self, new)
function LevelCompactModeSetting:checkAndSetValidValue(x)
	local new = SettingList.checkAndSetValidValue(self, x)
	if self:hasLeveler() then
		if new == LevelCompactModeSetting.COMPACTING then 
			return LevelCompactModeSetting.LEVELING
		end
	else 
		if new > LevelCompactModeSetting.COMPACTING then 
			return LevelCompactModeSetting.COMPACTING
		end
	end
	return new
end

function LevelCompactModeSetting:hasLeveler()
	return AIDriverUtil.getImplementWithSpecialization(self.vehicle, Leveler) ~= nil
end

---@class LevelCompactSearchOnlyAutomatedDriverSetting : BooleanSetting
LevelCompactSearchOnlyAutomatedDriverSetting = CpObject(BooleanSetting)
function LevelCompactSearchOnlyAutomatedDriverSetting:init(vehicle)
	BooleanSetting.init(self, 'levelCompactSearchOnlyAutomatedDriver', 'COURSEPLAY_MODE10_SEARCH_MODE', 'COURSEPLAY_MODE10_SEARCH_MODE', vehicle,
		{'COURSEPLAY_MODE10_SEARCH_MODE_ALL','COURSEPLAY_MODE10_SEARCH_MODE_CP'})
	self:set(true)
end

---@class LevelCompactSearchRadiusSetting : IntSetting
LevelCompactSearchRadiusSetting = CpObject(IntSetting)
function LevelCompactSearchRadiusSetting:init(vehicle)
	IntSetting.init(self, 'levelCompactSearchRadius', 'COURSEPLAY_MODE10_SEARCHRADIUS', 'COURSEPLAY_MODE10_SEARCHRADIUS', vehicle,10,200)
	self:set(50)
end

function LevelCompactSearchRadiusSetting:getText()
	return ('%d%s'):format(self:get(), courseplay:loc('COURSEPLAY_UNIT_METER'))
end

---@class LevelCompactSiloTypSetting : BooleanSetting
LevelCompactSiloTypSetting = CpObject(BooleanSetting)
function LevelCompactSiloTypSetting:init(vehicle)
	local texts = {
		'COURSEPLAY_MODE10_REVERSE_UNLOADING',
		'COURSEPLAY_MODE10_DRIVINGTHROUGH'
	}
	BooleanSetting.init(self, 'levelCompactSiloTyp', 'COURSEPLAY_MODE10_SILO_LOADEDBY', 'COURSEPLAY_MODE10_SILO_LOADEDBY', vehicle,texts)
end

---@class LevelCompactShieldHeightSetting : SettingList
LevelCompactShieldHeightSetting = CpObject(SettingList)
LevelCompactShieldHeightSetting.Automatic = -1
function LevelCompactShieldHeightSetting:init(vehicle)
	local texts = {}
	local values = {}
	texts[1] = 'COURSEPLAY_AUTOMATIC'
	values[1] = -1
	for i=2,17 do
		local x = (i-2)*0.1
		values[i] = x
		texts[i] = x
	end
	SettingList.init(self, 'levelCompactShieldHeight', 'COURSEPLAY_MODE10_BLADE_HEIGHT', 'COURSEPLAY_MODE10_BLADE_HEIGHT', vehicle,values,texts)
	self:set(-1)
end

function LevelCompactShieldHeightSetting:isAutomaticActive()
	return self:get() == self.Automatic
end

function LevelCompactShieldHeightSetting:getText()
	if not self:isAutomaticActive() then
		return ('%.1f%s'):format(self:get(), courseplay:loc('COURSEPLAY_UNIT_METER'))
	else 
		return SettingList.getText(self)
	end
end

function LevelCompactShieldHeightSetting:changeByX(x)
	if not self:isDisabled() then 
		SettingList.changeByX(self,x) 
	end
end

function LevelCompactShieldHeightSetting:isDisabled()
	return self.vehicle.cp.settings.levelCompactMode:get() == LevelCompactModeSetting.COMPACTING
end

--[[
---@class SearchCombineAutomaticallySetting : BooleanSetting
SearchCombineAutomaticallySetting = CpObject(BooleanSetting)
function SearchCombineAutomaticallySetting:init(vehicle)
	BooleanSetting.init(self, 'searchCombineAutomatically','COURSEPLAY_COMBINE_SEARCH_MODE', 'COURSEPLAY_COMBINE_SEARCH_MODE', vehicle, {'COURSEPLAY_MANUAL_SEARCH','COURSEPLAY_AUTOMATIC_SEARCH'}) 
	self:set(false)
end

---@class ShowSelectedFieldEdgePathSetting : SettingList
ShowSelectedFieldEdgePathSetting = CpObject(SettingList)
function ShowSelectedFieldEdgePathSetting:init(vehicle)
	SettingList.init(self, 'showSelectedFieldEdgePath','COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER', 'COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER', vehicle) 
	self:set(false)
end


]]--

--- Container for settings
--- @class SettingsContainer
SettingsContainer = CpObject()

function SettingsContainer:init(name)
	self.name = name
end

--- Add a setting which then can be addressed by its name like container['settingName'] or container.settingName
function SettingsContainer:addSetting(settingClass, ...)
	local s = settingClass(...)
	s.syncValue = true -- Only sync values that are part of a SettingsContainer
	s:setParent(self.name)
	self[s.name] = s
end

function SettingsContainer:saveToXML(xml, parentKey)
	for _, setting in pairs(self) do
		if self.validateSetting(setting) then 
			setting:saveToXml(xml, parentKey)
		end
	end
end

function SettingsContainer:loadFromXML(xml, parentKey)
	for _, setting in pairs(self) do
		if self.validateSetting(setting) then 
			setting:loadFromXml(xml, parentKey)
		end
	end
end

function SettingsContainer:validateCurrentValues()
	for k, setting in pairs(self) do
		if self.validateSetting(setting) then 
			setting:validateCurrentValue()
		end
	end
end

--TODO: test if in pairs() or in ipairs() is needed, as ipairs would be safer as
--		I am not sure if the order is the same on Client and Server,
--		but doesn't seem to work at the moment

function SettingsContainer:onReadStream(stream)
	for k, setting in pairs(self) do
		if self.validateSetting(setting) then 
			setting:onReadStream(stream)
		end
	end
end

function SettingsContainer:onWriteStream(stream)
	for k, setting in pairs(self) do
		if self.validateSetting(setting) then 
			setting:onWriteStream(stream)
		end
	end
end

function SettingsContainer:validateSetting(setting)
	if setting == self.name then 
		return false
	end
	return true
end

function SettingsContainer.createGlobalSettings()
	container = SettingsContainer("globalSettings")
	container:addSetting(LoadCoursesAtStartupSetting)
	container:addSetting(AutoFieldScanSetting)
	container:addSetting(WorkerWagesSetting)
	container:addSetting(ClickToSwitchSetting)
	container:addSetting(ShowMiniHudSetting)
	container:addSetting(EnableOpenHudWithMouseGlobalSetting)
	container:addSetting(AutoRepairSetting)
	return container
end

function SettingsContainer.createGlobalCourseGeneratorSettings()
	local container = SettingsContainer('globalCourseGeneratorSettings')
	container:addSetting(HeadlandLaneChangeMinRadius)
	container:addSetting(HeadlandLaneChangeMinDistanceToCorner)
	container:addSetting(HeadlandLaneChangeMinDistanceFromCorner)
	return container
end

function SettingsContainer.createGlobalPathfinderSettings()
	local container = SettingsContainer('globalPathfinderSettings')
	container:addSetting(MaxDeltaAngleAtGoal)
	container:addSetting(DeltaAngleRelaxFactor)
	return container
end

function SettingsContainer.createVehicleSpecificSettings(vehicle)
	---@type SettingsContainer
	local container = SettingsContainer("settings")
	container:addSetting(SearchCombineOnFieldSetting, vehicle)
	container:addSetting(SelectedCombineToUnloadSetting)
	container:addSetting(ReturnToFirstPointSetting, vehicle)
	container:addSetting(UseAITurnsSetting, vehicle)
	container:addSetting(UsePathfindingInTurnsSetting, vehicle)
	container:addSetting(AllowReverseForPathfindingInTurnsSetting, vehicle)
	container:addSetting(ImplementRaiseTimeSetting, vehicle)
	container:addSetting(ImplementLowerTimeSetting, vehicle)
	container:addSetting(AutoDriveModeSetting, vehicle)
	container:addSetting(SelfUnloadSetting, vehicle)
	container:addSetting(StartingPointSetting, vehicle)
	container:addSetting(SymmetricLaneChangeSetting, vehicle)
	container:addSetting(PipeAlwaysUnfoldSetting, vehicle)
	container:addSetting(RidgeMarkersAutomatic, vehicle)
	container:addSetting(KeepCurrentSteering, vehicle)
	container:addSetting(StopForUnloadSetting, vehicle)
	container:addSetting(StrawSwathSetting, vehicle)
	container:addSetting(AllowUnloadOnFirstHeadlandSetting, vehicle)
	container:addSetting(SowingMachineFertilizerEnabled, vehicle)
	container:addSetting(EnableOpenHudWithMouseVehicle, vehicle)
	container:addSetting(EnableVisualWaypointsTemporary, vehicle)
	container:addSetting(StopAtEndSetting, vehicle)
	container:addSetting(AutomaticCoverHandlingSetting, vehicle)
	container:addSetting(AutomaticUnloadingOnFieldSetting, vehicle)
	container:addSetting(DriverPriorityUseFillLevelSetting, vehicle)
	container:addSetting(UseRecordingSpeedSetting, vehicle)
	container:addSetting(WarningLightsModeSetting, vehicle)
	container:addSetting(ShowMapHotspotSetting, vehicle)
	container:addSetting(SaveFuelOptionSetting, vehicle)
	container:addSetting(AlwaysSearchFuelSetting, vehicle)
	container:addSetting(RealisticDrivingSetting, vehicle)
	container:addSetting(DriveUnloadNowSetting, vehicle)
	container:addSetting(CombineWantsCourseplayerSetting, vehicle)
	container:addSetting(TurnOnFieldSetting, vehicle)
	container:addSetting(TurnStageSetting, vehicle)
	container:addSetting(GrainTransportDriver_SiloSelectedFillTypeSetting, vehicle)
	container:addSetting(FillableFieldWorkDriver_SiloSelectedFillTypeSetting, vehicle)
	container:addSetting(FieldSupplyDriver_SiloSelectedFillTypeSetting, vehicle)
	container:addSetting(ShovelModeDriver_SiloSelectedFillTypeSetting, vehicle)
	container:addSetting(ShovelModeAIDriverTriggerHandlerIsActive, vehicle)
	container:addSetting(DriveOnAtFillLevelSetting, vehicle)
	container:addSetting(MoveOnAtFillLevelSetting, vehicle)
	container:addSetting(RefillUntilPctSetting, vehicle)
	container:addSetting(FollowAtFillLevelSetting,vehicle)
	container:addSetting(ForcedToStopSetting,vehicle)
	container:addSetting(SeparateFillTypeLoadingSetting,vehicle)
	container:addSetting(ReverseSpeedSetting, vehicle)
	container:addSetting(TurnSpeedSetting, vehicle)
	container:addSetting(FieldSpeedSettting,vehicle)
	container:addSetting(StreetSpeedSetting,vehicle)
	container:addSetting(ShowVisualWaypointsSetting,vehicle)
	container:addSetting(ShowVisualWaypointsCrossPointSetting,vehicle)
	container:addSetting(OppositeTurnModeSetting,vehicle)
	container:addSetting(FoldImplementAtEndSetting, vehicle)
	container:addSetting(ConvoyActiveSetting,vehicle)
	container:addSetting(ConvoyMinDistanceSetting,vehicle)
	container:addSetting(ConvoyMaxDistanceSetting,vehicle) -- do we need this one ?
	container:addSetting(FrontloaderToolPositionsSetting,vehicle)
	container:addSetting(AugerPipeToolPositionsSetting,vehicle)
	container:addSetting(ShovelStopAndGoSetting,vehicle)
	container:addSetting(LevelCompactModeSetting,vehicle)
	container:addSetting(LevelCompactSearchOnlyAutomatedDriverSetting,vehicle)
	container:addSetting(LevelCompactSearchRadiusSetting,vehicle)
	container:addSetting(LevelCompactShieldHeightSetting,vehicle)
	container:addSetting(BunkerSpeedSetting,vehicle, container.levelCompactMode)
	container:addSetting(LevelCompactSiloTypSetting,vehicle)
	container:addSetting(ToolOffsetXSetting, vehicle)
	container:addSetting(ToolOffsetZSetting, vehicle)
	return container
end

function SettingsContainer.createCourseGeneratorSettings(vehicle)
	local container = SettingsContainer("courseGeneratorSettings")
	container:addSetting(NumberOfRowsPerLandSetting, vehicle)
	container:addSetting(CenterModeSetting, vehicle)
	container:addSetting(HeadlandOverlapPercent, vehicle)
	container:addSetting(ShowSeedCalculatorSetting, vehicle)
	return container
end


-- do not remove this comment
-- vim: set noexpandtab:
