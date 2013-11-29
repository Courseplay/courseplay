courseplay_manager = {};
local courseplay_manager_mt = Class(courseplay_manager);

function courseplay_manager:loadMap(name)
	if g_currentMission.cp_courses == nil then
		--courseplay:debug("cp courses was nil and initialized", 8);
		g_currentMission.cp_courses = {};
		g_currentMission.cp_folders = {};
		g_currentMission.cp_sorted = {item={}, info={}};

		if g_server ~= nil and next(g_currentMission.cp_courses) == nil then
			courseplay_manager:load_courses()
			courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		end
	end;

	--GlobalInfoText buttons
	self.buttons = {
		globalInfoText = {};
		registerButton = courseplay_manager.registerButton;
	};
	self.playerOnFootMouseEnabled = false;
	self.wasPlayerFrozen = false;

	if g_server ~= nil then
		courseplay.fields:loadAllCustomFields();
	end;
end;

function courseplay_manager:registerButton(section, fn, prm, img, x, y, w, h)
	local overlay = Overlay:new(img, Utils.getFilename("img/" .. img, courseplay.path), x, y, w, h);
	local button = { 
		section = section, 
		overlay = overlay, 
		overlays = { overlay }, 
		function_to_call = fn, 
		parameter = prm, 
		x_init = x,
		x = x,
		x2 = (x + w),
		y_init = y,
		y = y,
		y2 = (y + h),
		color = courseplay.hud.colors.white,
		canBeClicked = fn ~= nil,
		show = true,
		isClicked = false,
		isActive = false,
		isDisabled = false,
		isHovered = false,
		isHidden = false
	};
	--print(string.format("courseplay_manager:registerButton(%q, %q, %s, %q, %.3f, %.3f, %.3f, %.3f)", section, fn, prm, img, x, y, w, h));
	table.insert(courseplay_manager.buttons[tostring(section)], button);
	--return #(courseplay_manager.buttons[tostring(section)]);
end;

function courseplay_manager:deleteMap()
	g_currentMission.cp_courses = nil
	g_currentMission.cp_folders = nil
	g_currentMission.cp_sorted = nil

	for i,vehicle in pairs(g_currentMission.steerables) do
		if vehicle.cp ~= nil then
			if vehicle.cp.globalInfoTextOverlay ~= nil then
				vehicle.cp.globalInfoTextOverlay:delete();
			end;
			if vehicle.cp.buttons ~= nil then
				courseplay.button.deleteButtonOverlays(vehicle);
			end;
		end;
	end;

	for i,button in pairs(self.buttons.globalInfoText) do
		if button.overlays ~= nil then
			for j,overlay in pairs(button.overlays) do
				if overlay.overlayId ~= nil and overlay.delete ~= nil then
					overlay:delete();
				end;
			end;
		end;
	end;

	for section,signDatas in pairs(courseplay.signs.buffer) do
		for k,signData in pairs(signDatas) do
			courseplay.utils.signs.deleteSign(signData.sign);
		end;
		courseplay.signs.buffer[section] = {};
	end;

	courseplay.fields.allFieldsScanned = false;
	courseplay.fields.ingameDataSetUp = false;
end

function courseplay_manager:draw()
	courseplay.globalInfoText.hasContent = false;
	if not courseplay.globalInfoText.hideWhenPdaActive or (courseplay.globalInfoText.hideWhenPdaActive and not g_currentMission.missionPDA.showPDA) then
		if #(courseplay.globalInfoText.content) > 0 then
			courseplay.globalInfoText.hasContent = true;
			for i,data in pairs(courseplay.globalInfoText.content) do
				local bg = data.vehicle.cp.globalInfoTextOverlay;
				local bgColor = courseplay.globalInfoText.levelColors[tostring(data.level)];
				bgColor[4] = 0.85;
				bg:setColor(unpack(bgColor));

				local posY = courseplay.globalInfoText.posY + ((i - 1) * courseplay.globalInfoText.lineHeight);
				bg:setPosition(bg.x, posY);
				bg:setDimension(getTextWidth(courseplay.globalInfoText.fontSize, data.text) + courseplay.globalInfoText.backgroundPadding * 2.5, bg.height);

				local button = self.buttons.globalInfoText[i];
				if button ~= nil then
					button.canBeClicked = true;
					button.isDisabled = data.vehicle.isBroken or data.vehicle.isControlled;
					--courseplay.button.setOffset(button, 0, posY - courseplay.globalInfoText.posY);
					button.parameter = data.vehicle;
					if g_currentMission.controlledVehicle == data.vehicle then
						courseplay:setButtonColor(button, courseplay.hud.colors.activeGreen);
						button.canBeClicked = false;
					elseif button.isDisabled then
						courseplay:setButtonColor(button, courseplay.hud.colors.whiteDisabled);
					elseif button.isHovered then
						courseplay:setButtonColor(button, courseplay.hud.colors.hover);
					elseif button.isClicked then
						courseplay:setButtonColor(button, courseplay.hud.colors.activeRed);
					else
						courseplay:setButtonColor(button, button.color);
					end;
					button.overlay:render();
				end;


				bg:render();
				courseplay:setFontSettings("white", false);
				renderText(courseplay.globalInfoText.posX, posY, courseplay.globalInfoText.fontSize, data.text);

				--reset for next runthrough
				data.vehicle.cp.currentGlobalInfoTextLevel = nil;
			end;

			--empty the tables for next runthrough
			courseplay.globalInfoText.content = {};
			courseplay.globalInfoText.vehicleHasText = {};
		end;
	end;

	courseplay.lightsNeeded = g_currentMission.environment.needsLights or (g_currentMission.environment.lastRainScale > 0.1 and g_currentMission.environment.timeSinceLastRain < 30);
end;

function courseplay_manager:mouseEvent(posX, posY, isDown, isUp, button)
	local area = courseplay_manager.buttons.globalInfoTextClickArea;
	if area == nil then
		return;
	end;
	local mouseKey = button;
	local mouseIsInHudArea = posX > area.x1 and posX < area.x2 and posY > area.y1 and posY < area.y2;

	--LEFT CLICK
	if isDown and mouseKey == Input[courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION.keyName] and mouseIsInHudArea then
		if courseplay.globalInfoText.hasContent then
			for i,button in pairs(self.buttons.globalInfoText) do
				if button.show and courseplay:mouseIsInButtonArea(posX, posY, button) then
					local sourceVehicle = g_currentMission.controlledVehicle or button.parameter;
					--print(string.format("handleMouseClickForButton(%q, button)", nameNum(sourceVehicle)));
					courseplay:handleMouseClickForButton(sourceVehicle, button);
					break;
				end;
			end;
		end;

	--RIGHT CLICK
	elseif isDown and mouseKey == Input[courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.keyName] and g_currentMission.controlledVehicle == nil then
		if courseplay.globalInfoText.hasContent and not self.playerOnFootMouseEnabled then
			self.playerOnFootMouseEnabled = true;
			self.wasPlayerFrozen = g_currentMission.isPlayerFrozen;
			g_currentMission.isPlayerFrozen = true;
		elseif self.playerOnFootMouseEnabled then
			self.playerOnFootMouseEnabled = false;
			if not self.wasPlayerFrozen then
				g_currentMission.isPlayerFrozen = false;
			end;
		end;
		--print(string.format("right mouse click: playerOnFootMouseEnabled=%s, wasPlayerFrozen=%s, isPlayerFrozen=%s", tostring(self.playerOnFootMouseEnabled), tostring(self.wasPlayerFrozen), tostring(g_currentMission.isPlayerFrozen)));
		InputBinding.setShowMouseCursor(self.playerOnFootMouseEnabled);

	--HOVER
	elseif not isDown then
		for _,button in pairs(self.buttons.globalInfoText) do
			button.isClicked = false;
			if button.show and not button.isHidden then
				button.isHovered = false;
				if courseplay:mouseIsInButtonArea(posX, posY, button) then
					button.isClicked = false;
					button.isHovered = true;
				end;
			end;
		end;
	end;
end;

function courseplay_manager:update(dt)
	--courseplay:debug(table.getn(g_currentMission.courseplay_courses), 8);

	if g_currentMission.controlledVehicle == nil then
		if self.playerOnFootMouseEnabled then
			g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:get_locale(self, "COURSEPLAY_MOUSEARROW_HIDE"));
		elseif courseplay.globalInfoText.hasContent then
			g_currentMission:addExtraPrintText(courseplay.inputBindings.mouse.COURSEPLAY_MOUSEACTION_SECONDARY.displayName .. ": " .. courseplay:get_locale(self, "COURSEPLAY_MOUSEARROW_SHOW"));
		end;
	end;

	--SETUP INGAME FIELD DATA
	if not courseplay.fields.ingameDataSetUp then
		courseplay.fields:setUpFieldsIngameData();
	end;

	--SCAN ALL FIELD EDGES
	if not courseplay.fields.allFieldsScanned then
		courseplay.fields:setAllFieldEdges();
	end;
end;

function courseplay_manager:updateTick(dt)
end;

function courseplay_manager:keyEvent()
end

function courseplay_manager:load_courses()
	--print("courseplay_manager:load_courses()");
	courseplay:debug('loading courses by courseplay manager', 8);

	local finish_all = false;
	local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
	if savegame ~= nil then
		local filePath = savegame.savegameDirectory .. "/courseplay.xml";

		if fileExists(filePath) then
			local cpFile = loadXMLFile("courseFile", filePath);
			g_currentMission.cp_courses = nil -- make sure it's empty (especially in case of a reload)
			g_currentMission.cp_courses = {}
			local courses_by_id = g_currentMission.cp_courses
			local courses_without_id = {}
			local i = 0
			
			local tempCourse
			repeat

				--current course
				local currentCourse = string.format("XML.courses.course(%d)", i)
				if not hasXMLProperty(cpFile, currentCourse) then
					finish_all = true;
					break;
				end;

				--course name
				local courseName = getXMLString(cpFile, currentCourse .. "#name");
				if courseName == nil then
					courseName = string.format('NO_NAME%d',i)
				end;
				local courseNameClean = courseplay:normalizeUTF8(courseName);

				--course ID
				local id = getXMLInt(cpFile, currentCourse .. "#id")
				if id == nil then
					id = 0;
				end;
				
				--course parent
				local parent = getXMLInt(cpFile, currentCourse .. "#parent")
				if parent == nil then
					parent = 0
				end

				--course waypoints
				tempCourse = {};
				local wpNum = 1;
				local key = currentCourse .. ".waypoint" .. wpNum;
				local finish_wp = not hasXMLProperty(cpFile, key);
				
				while not finish_wp do
					local x, z = Utils.getVectorFromString(getXMLString(cpFile, key .. "#pos"));
					if x ~= nil then
						if z == nil then
							finish_wp = true;
							break;
						end;
						local dangle =   Utils.getVectorFromString(getXMLString(cpFile, key .. "#angle"));
						local wait =     Utils.getVectorFromString(getXMLString(cpFile, key .. "#wait"));
						local speed =    Utils.getVectorFromString(getXMLString(cpFile, key .. "#speed"));
						local rev =      Utils.getVectorFromString(getXMLString(cpFile, key .. "#rev"));
						local crossing = Utils.getVectorFromString(getXMLString(cpFile, key .. "#crossing"));

						--course generation
						local generated =   Utils.getNoNil(getXMLBool(cpFile, key .. "#generated"), false);
						local dir =         getXMLString(cpFile, key .. "#dir");
						local turn =        Utils.getNoNil(getXMLString(cpFile, key .. "#turn"), "false");
						local turnStart =   Utils.getNoNil(getXMLInt(cpFile, key .. "#turnstart"), 0);
						local turnEnd =     Utils.getNoNil(getXMLInt(cpFile, key .. "#turnend"), 0);
						local ridgeMarker = Utils.getNoNil(getXMLInt(cpFile, key .. "#ridgemarker"), 0);

						crossing = crossing == 1 or wpNum == 1;
						wait = wait == 1;
						rev = rev == 1;

						if speed == 0 then
							speed = nil
						end

						--generated not needed, since true or false are loaded from file
						if turn == "false" then
							turn = nil;
						end;
						turnStart = turnStart == 1;
						turnEnd = turnEnd == 1;
						--ridgeMarker not needed, since 0, 1 or 2 is loaded from file

						tempCourse[wpNum] = { 
							cx = x, 
							cz = z, 
							angle = dangle, 
							rev = rev, 
							wait = wait, 
							crossing = crossing, 
							speed = speed,
							generated = generated,
							laneDir = dir,
							turn = turn,
							turnStart = turnStart,
							turnEnd = turnEnd,
							ridgeMarker = ridgeMarker
						};
						
						-- prepare next waypoint
						wpNum = wpNum + 1;
						key = currentCourse .. ".waypoint" .. wpNum;
						finish_wp = not hasXMLProperty(cpFile, key);
					else
						finish_wp = true;
						break;
					end;
				end -- while finish_wp == false;
				
				local course = { id = id, uid = 'c' .. id , type = 'course', name = courseName, nameClean = courseNameClean, waypoints = tempCourse, parent = parent }
				if id ~= 0 then
					courses_by_id[id] = course
				else
					table.insert(courses_without_id, course)
				end
				
				tempCourse = nil;
				i = i + 1;
				
			until finish_all == true;
			
			local j = 0
			local currentFolder, FolderName, id, parent, folder
			finish_all = false
			g_currentMission.cp_folders = nil
			g_currentMission.cp_folders = {}
			local folders_by_id = g_currentMission.cp_folders
			local folders_without_id = {}
			repeat
				-- current folder
				currentFolder = string.format("XML.folders.folder(%d)", j)
				if not hasXMLProperty(cpFile, currentFolder) then
					finish_all = true;
					break;
				end;
				
				-- folder name
				FolderName = getXMLString(cpFile, currentFolder .. "#name")
				if FolderName == nil then
					FolderName = string.format('NO_NAME%d',j)
				end
				local folderNameClean = courseplay:normalizeUTF8(FolderName);
				
				-- folder id
				id = getXMLInt(cpFile, currentFolder .. "#id")
				if id == nil then
					id = 0
				end
				
				-- folder parent
				parent = getXMLInt(cpFile, currentFolder .. "#parent")
				if parent == nil then
					parent = 0
				end
				
				-- "save" current folder
				folder = { id = id, uid = 'f' .. id ,type = 'folder', name = FolderName, nameClean = folderNameClean, parent = parent }
				if id ~= 0 then
					folders_by_id[id] = folder
				else
					table.insert(folders_without_id, folder)
				end
				j = j + 1
			until finish_all == true
			
			local save = false
			if #courses_without_id > 0 then
				-- give a new ID and save
				local maxID = courseplay.courses.getMaxCourseID()
				for i = 1, #courses_without_id do
					maxID = maxID + 1
					courses_without_id[i].id = maxID
					courses_without_id[i].uid = 'c' .. maxID
					courses_by_id[maxID] = courses_without_id[i]
				end
				save = true
			end
			if #folders_without_id > 0 then
				-- give a new ID and save
				local maxID = courseplay.courses.getMaxFolderID()
				for i = #folders_without_id, 1, -1 do
					maxID = maxID + 1
					folders_without_id[i].id = maxID
					folders_without_id[i].uid = 'f' .. maxID
					folders_by_id[maxID] = table.remove(folders_without_id)
				end
				save = true
			end		
			if save then
				-- this will overwrite the courseplay file and therefore delete the courses without ids and add them again with ids as they are now stored in g_currentMission with an id
				courseplay.courses.save_all()
			end
			
			g_currentMission.cp_sorted = courseplay.courses.sort(courses_by_id, folders_by_id, 0, 0)
						
			delete(cpFile);
		else
			--print("\t \"courseplay.xml\" missing from \"savegame" .. g_careerScreen.selectedIndex .. "\" folder");
		end; --END if fileExists
		
		courseplay:debug(tableShow(g_currentMission.cp_sorted.item, "cp_sorted.item", 8), 8);

		return g_currentMission.cp_courses;
	else
		print("Error: [Courseplay] current savegame could not be found.");
	end; --END if savegame ~= nil

	return nil;
end


--remove courseplayers from combine before it is reset and/or sold
function courseplay_manager:removeCourseplayersFromCombine(vehicle, callDelete)
	if vehicle.courseplayers ~= nil then
		local combine = vehicle;
		courseplay:debug(nameNum(combine) .. ": courseplay_manager:removeCourseplayersFromCombine(vehicle, callDelete)", 4);

		if table.getn(combine.courseplayers) > 0 then
			courseplay:debug(nameNum(combine) .. " has " .. table.getn(combine.courseplayers) .. " courseplayers -> unregistering all", 4);
			for i,tractor in pairs(combine.courseplayers) do
				courseplay:unregister_at_combine(tractor, combine);
				
				if tractor.cp.savedCombine ~= nil and tractor.cp.savedCombine == combine then
					tractor.cp.savedCombine = nil;
				end;
				tractor.cp.reachableCombines = nil;
			end;
			courseplay:debug(nameNum(combine) .. " has " .. table.getn(combine.courseplayers) .. " courseplayers", 4);
		end;
	end;
end;
BaseMission.removeVehicle = Utils.prependedFunction(BaseMission.removeVehicle, courseplay_manager.removeCourseplayersFromCombine);




stream_debug_counter = 0

addModEventListener(courseplay_manager);

--
-- based on PlayerJoinFix
--
-- SFM-Modding
-- @author:  Manuel Leithner
-- @date:    01/08/11
-- @version: v1.1
-- @history: v1.0 - initial implementation
--           v1.1 - adaption to courseplay
--

local modName = g_currentModName;
local Server_sendObjects_old = Server.sendObjects;

function Server:sendObjects(connection, x, y, z, viewDistanceCoeff)
	connection:sendEvent(CourseplayJoinFixEvent:new());

	Server_sendObjects_old(self, connection, x, y, z, viewDistanceCoeff);
end


CourseplayJoinFixEvent = {};
CourseplayJoinFixEvent_mt = Class(CourseplayJoinFixEvent, Event);

InitEventClass(CourseplayJoinFixEvent, "CourseplayJoinFixEvent");

function CourseplayJoinFixEvent:emptyNew()
	local self = Event:new(CourseplayJoinFixEvent_mt);
	self.className = modName .. ".CourseplayJoinFixEvent";
	return self;
end

function CourseplayJoinFixEvent:new()
	local self = CourseplayJoinFixEvent:emptyNew()
	return self;
end

function CourseplayJoinFixEvent:writeStream(streamId, connection)


	if not connection:getIsServer() then
		--courseplay:debug("manager transfering courses", 8);
		--transfer courses
		local course_count = 0
		for k, v in pairs(g_currentMission.cp_courses) do
			course_count = course_count + 1
		end
		streamDebugWriteInt32(streamId, course_count)
		courseplay:debug(string.format("writing %d courses ", course_count ),5)
		for id, course in pairs(g_currentMission.cp_courses) do
			streamDebugWriteString(streamId, course.name)
			streamDebugWriteInt32(streamId, course.id)
			streamDebugWriteInt32(streamId, table.getn(course.waypoints))
			for w = 1, table.getn(course.waypoints) do
				streamDebugWriteFloat32(streamId, course.waypoints[w].cx)
				streamDebugWriteFloat32(streamId, course.waypoints[w].cz)
				streamDebugWriteFloat32(streamId, course.waypoints[w].angle)
				streamDebugWriteBool(streamId, course.waypoints[w].wait)
				streamDebugWriteBool(streamId, course.waypoints[w].rev)
				streamDebugWriteBool(streamId, course.waypoints[w].crossing)
				streamDebugWriteInt32(streamId, course.waypoints[w].speed)

				streamDebugWriteBool(streamId, course.waypoints[w].generated)
				streamDebugWriteString(streamId, (course.waypoints[w].laneDir or ""))
				streamDebugWriteString(streamId, course.waypoints[w].turn)
				streamDebugWriteBool(streamId, course.waypoints[w].turnStart)
				streamDebugWriteBool(streamId, course.waypoints[w].turnEnd)
				streamDebugWriteInt32(streamId, course.waypoints[w].ridgeMarker)
			end
		end
		courseplay:debug("writing courses end",5)
	end;
end

function CourseplayJoinFixEvent:readStream(streamId, connection)
	courseplay:debug("CourseplayJoinFixEvent:readStream",5)
	if connection:getIsServer() then
		courseplay:debug("connection:getIsServer()",5)
		--courseplay:debug("manager receiving courses", 8);
		-- course count
		local course_count = streamDebugReadInt32(streamId)
		courseplay:debug(string.format("reading %d couses ", course_count ),5)
		--courseplay:debug("manager reading stream", 8);
		--courseplay:debug(course_count, 8);
		g_currentMission.cp_courses = {}
		for i = 1, course_count do
			--courseplay:debug("got course", 8);
			local course_name = streamDebugReadString(streamId)
			local course_id = streamDebugReadInt32(streamId)
			local wp_count = streamDebugReadInt32(streamId)
			local waypoints = {}
			for w = 1, wp_count do
				--courseplay:debug("got waypoint", 8);
				local cx = streamDebugReadFloat32(streamId)
				local cz = streamDebugReadFloat32(streamId)
				local angle = streamDebugReadFloat32(streamId)
				local wait = streamDebugReadBool(streamId)
				local rev = streamDebugReadBool(streamId)
				local crossing = streamDebugReadBool(streamId)
				local speeed = streamDebugReadInt32(streamId)

				local generated = streamDebugReadBool(streamId)
				local dir = streamDebugReadString(streamId)
				local turn = streamDebugReadString(streamId)
				local turnStart = streamDebugReadBool(streamId)
				local turnEnd = streamDebugReadBool(streamId)
				local ridgeMarker = streamDebugReadInt32(streamId)
				
				local wp = {
					cx = cx, 
					cz = cz, 
					angle = angle, 
					wait = wait, 
					rev = rev, 
					crossing = crossing, 
					speed = speed,
					generated = generated,
					laneDir = dir,
					turn = turn,
					turnStart = turnStart,
					turnEnd = turnEnd,
					ridgeMarker = ridgeMarker 
				};
				table.insert(waypoints, wp)
			end
			local course = { name = course_name, waypoints = waypoints, id = course_id }
			g_currentMission.cp_courses[course_id] = course
		end
		courseplay:debug("reading end",5)
	end;
end

function CourseplayJoinFixEvent:run(connection)
	--courseplay:debug("CourseplayJoinFixEvent Run function should never be called", 8);
end;