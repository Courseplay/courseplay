local curFile = 'course_management.lua';
local ceil = math.ceil;

-- saving // loading courses
function courseplay.courses:setup()
	-- LOAD COURSES AND FOLDERS FROM XML
	if g_currentMission.cp_courses == nil then
		-- courseplay:debug("cp_courses was nil and initialized", 8);
		g_currentMission.cp_courses = {};
		g_currentMission.cp_courseManager = {};
		g_currentMission.cp_folders = {};
		g_currentMission.cp_sorted = { item={}, info={} };

		if g_server ~= nil and next(g_currentMission.cp_courses) == nil then
			self:loadCoursesAndFoldersFromXml();
			-- courseplay:debug(tableShow(g_currentMission.cp_courses, "g_cM cp_courses", 8), 8);
		end;
	end;
end;


-- enables input for course/folder/filter name
function courseplay:showSaveCourseForm(vehicle, saveWhat) -- fn is in courseplay because it's vehicle based
	--print(string.format("courseplay:showSaveCourseForm(vehicle(%s), saveWhat(%s))",tostring(vehicle),tostring(saveWhat)))
	--print(string.format("vehicle.cp.imWriting(%s)",tostring(vehicle.cp.imWriting)))
	saveWhat = saveWhat or 'course'
	
	if saveWhat == 'course' then
		if vehicle.cp.numWaypoints > 0 then
			courseplay.vehicleToSaveCourseIn = vehicle;
			if vehicle.cp.imWriting then
				vehicle.cp.saveWhat = 'course'
				g_gui:showGui("inputCourseNameDialogue");
				vehicle.cp.imWriting = false
			end
		end;
		
	elseif saveWhat == 'folder' then
		courseplay.vehicleToSaveCourseIn = vehicle;
		if vehicle.cp.imWriting then
			vehicle.cp.saveWhat = 'folder'
			g_gui:showGui("inputCourseNameDialogue");
			vehicle.cp.imWriting = false
		end
	
	elseif saveWhat == 'filter' then
		if vehicle.cp.hud.filter == '' then
			courseplay.vehicleToSaveCourseIn = vehicle;
			if vehicle.cp.imWriting then
				vehicle.cp.saveWhat = 'filter';
				g_gui:showGui("inputCourseNameDialogue");
				vehicle.cp.imWriting = false;
			end;
		else
			vehicle.cp.hud.filter = '';
			vehicle.cp.hud.filterButton:setSpriteSectionUVs('search');
			vehicle.cp.hud.filterButton:setToolTip(courseplay:loc('COURSEPLAY_SEARCH_FOR_COURSES_AND_FOLDERS'));
			courseplay.settings.setReloadCourseItems(vehicle);
		end;
	end
end;

function courseplay:reloadCourses(vehicle, useRealId) -- fn is in courseplay because it's vehicle based
	courseplay:debug(('%s: reloadCourses(..., %s)'):format(nameNum(vehicle), tostring(useRealId)), 8);
	local courses = vehicle.cp.loadedCourses;
	vehicle.cp.loadedCourses = {};
	for k, v in pairs(courses) do
		courseplay:loadCourse(vehicle, v, useRealId);
	end;
end;

function courseplay.courses:reinitializeCourses()
	if g_currentMission.cp_courses == nil then
		courseplay:debug("cp_courses is empty", 8)
		if g_server ~= nil then
			self:loadCoursesAndFoldersFromXml();
		end
		return
	end
end

function courseplay:addSortedCourse(vehicle, index) -- fn is in courseplay because it's vehicle based
	local id = vehicle.cp.hud.courses[index].id
	courseplay:loadCourse(vehicle, id, true, true)
end

function courseplay:loadSortedCourse(vehicle, index) -- fn is in courseplay because it's vehicle based
	if type(vehicle.cp.hud.courses[index]) ~= nil then
		local id = vehicle.cp.hud.courses[index].id
		courseplay:loadCourse(vehicle, id, true)
	end	
end

function courseplay:loadCourse(vehicle, id, useRealId, addCourseAtEnd) -- fn is in courseplay because it's vehicle based
	-- global array for courses, no refreshing needed any more
	courseplay.courses:reinitializeCourses();
	
	if vehicle.cp.lastValidTipDistance ~= nil then
		vehicle.cp.lastValidTipDistance = nil
	end
	if addCourseAtEnd == nil then addCourseAtEnd = false; end;

	courseplay:debug(string.format('%s: loadCourse(..., id=%s, useRealId=%s, addCourseAtEnd=%s)', nameNum(vehicle), tostring(id), tostring(useRealId), tostring(addCourseAtEnd)), 8);
	if id ~= nil and id ~= "" then
		if not useRealId then
			return -- not supported any more
		end
		id = id * 1 -- equivalent to tonumber()

		-- negative values mean that addCourseAtEnd is true
		if id < 1 then
			id = id * -1
			addCourseAtEnd = true;
		end

		local course = g_currentMission.cp_courses[id]
		if course == nil then
			courseplay:debug(string.format('\tid %d -> course not found, return', id), 8);
			return
		end

		if addCourseAtEnd == true then
			table.insert(vehicle.cp.loadedCourses, id * -1)
		else
			table.insert(vehicle.cp.loadedCourses, id)
		end

		--	courseplay:clearCurrentLoadedCourse(vehicle)
		if #vehicle.Waypoints == 0 then
			vehicle.cp.numCourses = 1;
			vehicle.Waypoints = course.waypoints
			--vehicle:setCpVar('numWaypoints', #vehicle.Waypoints,courseplay.isClient);
			vehicle.cp.numWayPoints = #vehicle.Waypoints;
			vehicle:setCpVar('currentCourseName',course.name,courseplay.isClient)

			-- for turn maneuver
			vehicle.cp.courseWorkWidth = course.workWidth;
			vehicle.cp.courseNumHeadlandLanes = course.numHeadlandLanes;
			vehicle.cp.courseHeadlandDirectionCW = course.headlandDirectionCW;
			course.multiTools = course.multiTools or 1
			courseplay:changeMultiTools(vehicle, nil, course.multiTools)
			
			courseplay:debug(string.format("course_management %d: %s: no course was loaded -> new course = course -> currentCourseName=%q, numCourses=%s", debug.getinfo(1).currentline, nameNum(vehicle), tostring(vehicle.cp.currentCourseName), tostring(vehicle.cp.numCourses)), 8);

		else -- add new course to old course
			if vehicle.cp.currentCourseName == nil then --recorded but not saved course
				vehicle.cp.numCourses = 1;
			end;
			courseplay:debug(string.format("course_management %d: %s: currentCourseName=%q, numCourses=%s -> add new course %q", debug.getinfo(1).currentline, nameNum(vehicle), tostring(vehicle.cp.currentCourseName), tostring(vehicle.cp.numCourses), tostring(course.name)), 8);


			local course1, course2 = vehicle.Waypoints, course.waypoints;
			local numCourse1, numCourse2 = #course1, #course2;
			local course1wp, course2wp = numCourse1, 1;

			--find crossing points, merge at first pair where dist < 50
			local firstMatchFound, closestMatchFound = false, false;
			local useFirstMatch = false; --true: first match <50m is used to merge / false: match with closest distance <50m is used to merge;
			if not addCourseAtEnd then
				--find crossing points
				local crossingPoints = { [1] = {}, [2] = {} };
				for i=vehicle.cp.lastMergedWP + 1, numCourse1 do
					if i > 1 and course1[i].crossing == true and not course1[i].merged then
						courseplay:debug('course1 wp ' .. i .. ': add to crossingPoints[1]', 8);
						table.insert(crossingPoints[1], i);
					end;
				end;
				for i,wp in pairs(course2) do
					if i < numCourse2 and wp.crossing == true and not wp.merged then
						courseplay:debug('course2 wp ' .. i .. ': add to crossingPoints[2]', 8);
						table.insert(crossingPoints[2], i);
					end;
				end;
				courseplay:debug(string.format('course 1 has %d crossing points (excluding first point), course 2 has %d crossing points (excluding last point), useFirstMatch=%s', #crossingPoints[1], #crossingPoints[2], tostring(useFirstMatch)), 8);

				--find < 50m match
				local smallestDist = math.huge;
				if #crossingPoints[1] > 0 and #crossingPoints[2] > 0 then
					for _,wpNum1 in pairs(crossingPoints[1]) do
						local wp1 = course1[wpNum1];
						for _,wpNum2 in pairs(crossingPoints[2]) do
							local wp2 = course2[wpNum2];
							local dist = courseplay:distance(wp1.cx, wp1.cz, wp2.cx, wp2.cz);
							courseplay:debug(string.format('course1 wp %d, course2 wp %d, dist=%s', wpNum1, wpNum2, tostring(dist)), 8);
							if dist and dist ~= 0 and dist < 50 then
								if useFirstMatch then
									course1wp = wpNum1;
									course2wp = wpNum2;

									vehicle.cp.lastMergedWP = wpNum1;
									course1[course1wp].merged = true;
									course2[course2wp].merged = true;

									firstMatchFound = true;
									courseplay:debug(string.format('\tuseFirstMatch=true -> 2 valid crossing points found: (1)=#%d, (2)=#%d, dist=%.1f -> lastMergedWP=%d, set "merged" for both to "true", break', course1wp, course2wp, dist, vehicle.cp.lastMergedWP), 8);
								else
									if dist < smallestDist then
										smallestDist = dist;

										--remove previous 'merged' vars
										course1[course1wp].merged = nil;
										course2[course2wp].merged = nil;

										course1wp = wpNum1;
										course2wp = wpNum2;

										vehicle.cp.lastMergedWP = wpNum1;
										course1[course1wp].merged = true;
										course2[course2wp].merged = true;

										closestMatchFound = true;
										courseplay:debug(string.format('\tuseFirstMatch=false -> 2 valid crossing points found: (1)=#%d, (2)=#%d, dist=%.1f -> lastMergedWP=%d, set "merged" for both to "true", continue', course1wp, course2wp, dist, vehicle.cp.lastMergedWP), 8);
									end;
								end;
							end;
							if firstMatchFound then break; end;
						end;
						if firstMatchFound then break; end;
					end;
				end;
			end;

			if not addCourseAtEnd then
				if firstMatchFound or closestMatchFound then
					courseplay:debug(string.format('%s: merge points found: course 1: #%d, course 2: #%d', nameNum(vehicle), course1wp, course2wp), 8);
				else
					courseplay:debug(string.format('%s: no points where the courses could be merged have been found -> add 2nd course at end', nameNum(vehicle)), 8);
				end;
			end;

			vehicle.Waypoints = {};
			for i=1, course1wp do
				table.insert(vehicle.Waypoints, course1[i]);
			end;
			for i=course2wp, numCourse2 do
				table.insert(vehicle.Waypoints, course2[i]);
			end;
			vehicle.cp.numWayPoints = #vehicle.Waypoints;
			--vehicle:setCpVar('numWaypoints', #vehicle.Waypoints,courseplay.isClient);
			vehicle.cp.numCourses = vehicle.cp.numCourses + 1;
			vehicle:setCpVar('currentCourseName',string.format("%d %s", vehicle.cp.numCourses, courseplay:loc('COURSEPLAY_COMBINED_COURSES')),courseplay.isClient);

			-- for turn maneuver
			if not vehicle.cp.courseWorkWidth then
				vehicle.cp.courseWorkWidth = course.workWidth;
				--Place here to prevent it being reset back to one multi Tool on course addition when course isn't auto generated
				course.multiTools = course.multiTools or 1
				courseplay:changeMultiTools(vehicle, nil, course.multiTools)
			end;
			if not vehicle.cp.courseNumHeadlandLanes then
				vehicle.cp.courseNumHeadlandLanes = course.numHeadlandLanes;
			end;
			if vehicle.cp.courseHeadlandDirectionCW == nil then
				vehicle.cp.courseHeadlandDirectionCW = course.headlandDirectionCW;
			end;
			
			
			courseplay:debug(string.format('%s: adding course done -> numWaypoints=%d, numCourses=%s, currentCourseName=%q', nameNum(vehicle), vehicle.cp.numWaypoints, vehicle.cp.numCourses, vehicle.cp.currentCourseName), 8);
		end;

		
		vehicle:setCpVar('canDrive',true,courseplay.isClient);
		
		courseplay:setWaypointIndex(vehicle, 1);
		courseplay:setModeState(vehicle, 0);
		courseplay.signs:updateWaypointSigns(vehicle, "current");

		vehicle.cp.hasGeneratedCourse = false;
		courseplay:validateCourseGenerationData(vehicle);

		courseplay:validateCanSwitchMode(vehicle);

		-- SETUP 2D COURSE DRAW DATA
		vehicle.cp.course2dUpdateDrawData = true;
	end
end

function courseplay.courses:sort(courses_to_sort, folders_to_sort, parent_id, level, make_copies)
--Note: this function is recursive.
	courses_to_sort = courses_to_sort or g_currentMission.cp_courses
	folders_to_sort = folders_to_sort or g_currentMission.cp_folders
	parent_id = parent_id or 0
	level = level or 0	
	if make_copies == nil then
		make_copies = true
	end
	
	if make_copies then
		-- Tables are pointers. The sort function will delete entries in the tables. In order to preserve the original tables a copy is made in the first execution.
		-- note that only courses_to_sort and folders_to_sort are copied. if those contain tables themselves again, these tables are referenced again (the reference is copied).
		courses_to_sort = courseplay.utils.table.copy(courses_to_sort)
		folders_to_sort = courseplay.utils.table.copy(folders_to_sort)
	end
	
	local sorted = {}
	sorted.item = {}
	sorted.info = {}
	local last_child = 0
	
	-- search for folder children with this parent
	local folders = {}
	local temp_sorted, temp_sorted_items, temp_last_child
	folders = courseplay.utils.table.search_in_field(folders_to_sort, 'parent', parent_id)
	table.sort(folders, courseplay.utils.table.compare_name)
	
	-- search for course children with this parent
	local courses = {}
	courses = courseplay.utils.table.search_in_field(courses_to_sort, 'parent', parent_id)
	table.sort(courses, courseplay.utils.table.compare_name)
	
	-- handle the folders first
	-- first delete the found entries in the folders_to_sort
	--	this has to be done in a separate loop as folders_to_sort is used in the loop and should then not contain the already found folders anymore.
	for i = 1, #folders do
		folders_to_sort[folders[i].id] = nil
	end
	for i = 1, #folders do
		-- find child's children
		temp_sorted, temp_last_child = self:sort(courses_to_sort, folders_to_sort, folders[i].id, level+1, false)
		temp_sorted_items = temp_sorted.item
		
		folders[i].level = level
		folders[i].displayname = folders[i].name
		sorted.info[ folders[i].uid ] = {}
		if #courses ~= 0 or i ~= #folders then
			-- there are courses after the last folder or it's not the last folder
			sorted.info[ folders[i].uid ].next_neighbour = #temp_sorted_items + 1		-- relative index to next neighbour
		else
			-- it's the last folder and there are no courses afterwards
			sorted.info[folders[i].uid].next_neighbour = 0
		end
		sorted.info[folders[i].uid].lastChild = temp_last_child 						-- relative index to the last direct child
		sorted.info[folders[i].uid].parent_ridx = -(#sorted.item + 1)					-- relative index to the parent
		if i > 1 then
			sorted.info[folders[i].uid].leading_neighbour = -sorted.info[folders[i-1].uid].next_neighbour	-- relative index to the leading neighbour
		else
			sorted.info[folders[i].uid].leading_neighbour = 0
		end
		
		-- append folder
		table.insert(sorted.item, folders[i])
		-- append children
		sorted.item = courseplay.utils.table.append(sorted.item, temp_sorted_items)
		-- add children's info
		sorted.info = courseplay.utils.table.merge(sorted.info, temp_sorted.info)
	end
	
	-- now handle the found courses:
	for i = 1, #courses do
		-- first delete the course form courses_to_sort
		courses_to_sort[courses[i].id] = nil
		
		courses[i].level = level
		courses[i].displayname = courses[i].name
		sorted.info[ courses[i].uid ] = {}
		if i ~= #courses then
			-- it's not the last entry
			sorted.info[courses[i].uid].next_neighbour = 1
		else
			sorted.info[courses[i].uid].next_neighbour = 0
		end
		sorted.info[courses[i].uid].parent_ridx = -(#sorted.item + 1)
		if i ~= 1 then
			-- it's not the first course, so there is one before
			sorted.info[courses[i].uid].leading_neighbour = -1
		elseif #folders ~= 0 then
			-- it is the first course, but there are folders before
			sorted.info[courses[i].uid].leading_neighbour = -(#temp_sorted_items + 1)			
		else
			-- first course and no folders, so it is the very first one
			sorted.info[courses[i].uid].leading_neighbour = 0
		end
		table.insert(sorted.item, courses[i])
	end
	
	if #courses > 0 then
		last_child = #(sorted.item)		-- relative index to the last direct child
	elseif #folders > 0 then
		last_child = #(sorted.item) - #temp_sorted_items
	else
		last_child = 0
	end
	
	if level == 0 then
		-- all courses and folders should be handled now (we are done)
		local n = #sorted.item
		for i=1, n do
			sorted.info[ sorted.item[i].uid ].sorted_index = i
		end
		
		-- are we really done? -> add any corrupted folders and courses:	
		for k,v in pairs(folders_to_sort) do
			v.level = level
			v.displayname = v.name .. ' (corrupted)'
			table.insert(sorted.item, v)
		end
		for k,v in pairs(courses_to_sort) do
			v.level = level
			v.displayname = v.name .. ' (corrupted)'
			table.insert(sorted.item, v)
		end
		for i = n+1, #sorted.item do
			sorted.info[ sorted.item[i].uid ] = {sorted_index=i}
		end
		
	end
	
	return sorted, last_child
end

function courseplay.courses:resetMerged()
	for _,course in pairs(g_currentMission.cp_courses) do
		for num, wp in pairs(course.waypoints) do
			wp.merged = nil;
		end;
	end;
end;

function courseplay:deleteSortedItem(vehicle, index) -- fn is in courseplay because it's vehicle based
	local id = vehicle.cp.hud.courses[index].id
	local type = vehicle.cp.hud.courses[index].type
	
	if type == 'course' then
		local slotId = self.courses:getFreeSaveSlot(id);
		self.courses:removeFromManagerXml(type, slotId);
		g_currentMission.cp_courses[id] = nil
	elseif type == 'folder' then
		-- check for children: delete only if folder has no children
		if g_currentMission.cp_sorted.info['f'..id].lastChild == 0 then
			self.courses:removeFromManagerXml(type, id);
			g_currentMission.cp_folders[id] = nil
		end
	else
		--Error?!
	end
	
	g_currentMission.cp_sorted = courseplay.courses:sort()
	courseplay.settings.setReloadCourseItems()
	courseplay.signs:updateWaypointSigns(vehicle);
end

function courseplay.courses:saveFolderToXml(folder_id, cpCManXml, append)
-- saves a folder to the courseplay xml file
--
-- append (bool,integer): append can be a bool or an integer
--		if it's false, the function will check if the id exists in the file. if it exists, it will overwrite it otherwise it will append
--		if append is true, the function will search for the next free position and save there
--		if append is an integer, the function will save at this position (without checking if it is the end or what there was before)
	local deleteFile = false
	if append == nil then
		append = false  -- slow but secure
	end

	if cpCManXml == nil then
		cpCManXml = self:getCourseManagerXML()
		deleteFile = true
	end

	-- { id = id, type = 'folder', name = name, parent = parent }
	local types = { id = 'Int', name = 'String', parent = 'Int'}
	local i = 0

	-- find the node position and save the attributes
	if append ~= false then
		if append == true then
			i = courseplay.utils.findFreeXMLNode(cpCManXml,'courseManager.folders.folder')
		else
			i = append
		end
	else
		i = courseplay.utils.findXMLNodeByAttr(cpCManXml, 'courseManager.folders.folder', 'id', folder_id, 'Int')
		if i < 0 then i = -i end
	end
	courseplay.utils.setMultipleXML(cpCManXml, string.format('courseManager.folders.folder(%d)', i), g_currentMission.cp_folders[folder_id], types)

	saveXMLFile(cpCManXml)
	if deleteFile then
		delete(cpCManXml)
	end
end

function courseplay.courses:saveFoldersToXml(cpCManXml)
--	function to save all folders by once
	local deleteFile = false;

	if cpCManXml == nil then
		cpCManXml = self:getCourseManagerXML();
		deleteFile = true;
	end;

	local index = 0;
	for k,_ in pairs(g_currentMission.cp_folders) do
		self:saveFolderToXml(k, cpCManXml, index);
		index = index + 1;
	end;

	if deleteFile then
		delete(cpCManXml);
	end;
end

function courseplay.courses:getFreeSaveSlot(course_id)
	local freeSlot = 1;
	local isOwnSaveSlot = false;
	-- Check if there is any saved data already. If not, we returns 1 as the firstSlot
	if g_currentMission.cp_courseManager and #g_currentMission.cp_courseManager > 0 then
		local foundFreeSlot = false;

		-- Check if we already have an saved slot
		if course_id then
			for index, v in ipairs(g_currentMission.cp_courseManager) do
				if v.id == course_id then
					freeSlot = index;
					foundFreeSlot = true;
					isOwnSaveSlot = true;
				end;
			end;
		end;

		-- Check if there is an free slot we can use, in case we don't have one already.
		if not foundFreeSlot then
			for index, v in ipairs(g_currentMission.cp_courseManager) do
				if v.isUsed == false then
					freeSlot = index;
					foundFreeSlot = true;
				end;
			end;
		end;

		-- If there were no free slot found, return the end position
		if not foundFreeSlot then
			freeSlot = #g_currentMission.cp_courseManager + 1;
		end;
	end;

	return freeSlot, isOwnSaveSlot;
end

function courseplay.courses:saveCourseToXml(course_id, cpCManXml)
	-- save course to xml file
	if g_server == nil then
		return
	end
	
	local deleteFile = false
	if cpCManXml == nil then
		cpCManXml = self:getCourseManagerXML()
		deleteFile = true
	end

	local cp_course = g_currentMission.cp_courses[course_id];

	local freeSlot, isOwnSaveSlot = self:getFreeSaveSlot(course_id);
	-- We can use an unused slot
	if g_currentMission.cp_courseManager[freeSlot] then
		g_currentMission.cp_courseManager[freeSlot].isUsed = true;
		g_currentMission.cp_courseManager[freeSlot].id =	 cp_course.id;
		g_currentMission.cp_courseManager[freeSlot].name =	 cp_course.name;
		g_currentMission.cp_courseManager[freeSlot].parent = cp_course.parent;

	-- We are an new slot
	else
		local info = {
			index =	   freeSlot - 1;
			isUsed =   true;
			fileName = (CpManager.cpCourseStorageXmlFileTemplate):format(freeSlot);
			id =	   cp_course.id;
			name =	   cp_course.name;
			parent =   cp_course.parent;
		}
		table.insert(g_currentMission.cp_courseManager, info);
	end;
	self:updateCourseManagerSlotsXml(freeSlot, cpCManXml);


	-- Dont save course if we already have a saveSlot.
	if not isOwnSaveSlot then
		-- save waypoint: rev, wait, crossing, generated, turnstart, turnend are bools; speed may be nil!
		-- from xml: rev=int wait=int crossing=int generated=bool, turnstart=int turnend=int ridgemarker=int
		-- xml: pos="float float" angle=float rev=0/1 wait=0/1 crossing=0/1 speed=float generated="true/false" turnstart=0/1 turnend=0/1 ridgemarker=0/1/2
		local waypoints = {}
		-- setXMLFloat seems imprecise...
		local courseXmlFilePath = CpManager.cpCoursesFolderPath .. g_currentMission.cp_courseManager[freeSlot].fileName;
		local courseXml = createXMLFile("courseXml", courseXmlFilePath, 'course');
		if cp_course.workWidth then
			setXMLFloat(courseXml, "course#workWidth", cp_course.workWidth);
		end;
		if cp_course.numHeadlandLanes then
			setXMLInt(courseXml, "course#numHeadlandLanes", cp_course.numHeadlandLanes);
		end;
		if cp_course.headlandDirectionCW ~= nil then
			setXMLBool(courseXml, "course#headlandDirectionCW", cp_course.headlandDirectionCW);
		end;
		if cp_course.multiTools ~= nil then
			setXMLInt(courseXml, "course#multiTools", cp_course.multiTools);
		end;

		if courseXml and courseXml ~= 0 then
			local types = {
				pos='String',
				angle='String',
				rev='Int',
				wait='Int',
				unload='Int',
				crossing='Int',
				speed='String',
				generated='Bool',
				lane='Int',
				dir='String',
				turnstart='Int',
				turnend='Int',
				ridgemarker='Int',
        isconnectingtrack='Bool'};

			for k, v in pairs(cp_course.waypoints) do
				local waypoint = {
					-- Required Values
					pos =   ('%.2f %.2f'):format(v.cx, v.cz);
					angle = ('%.2f'):format(v.angle);
					speed = ('%d'):format(v.speed or 0);

					-- Optional Values
					rev =		   v.rev and courseplay:boolToInt(v.rev) or nil;
					wait =		   v.wait and courseplay:boolToInt(v.wait) or nil;
					unload =	   v.unload and courseplay:boolToInt(v.unload) or nil;
					crossing =	   v.crossing and courseplay:boolToInt(v.crossing) or nil;
					generated =	   v.generated and v.generated or nil;
					turnstart =    v.turnStart and courseplay:boolToInt(v.turnStart) or nil;
					turnend =	   v.turnEnd and courseplay:boolToInt(v.turnEnd) or nil;
					ridgemarker = (v.ridgeMarker and v.ridgeMarker ~= 0) and v.ridgeMarker or nil;
					lane =		  (v.lane and v.lane < 0) and v.lane or nil;
					isconnectingtrack =	v.isConnectingTrack and v.isConnectingTrack or nil;
				};

				waypoints[k] = waypoint;
			end

			courseplay.utils.setMultipleXMLNodes(courseXml, "course", 'waypoint', waypoints, types, true);

			saveXMLFile(courseXml);
		else
			print(("COURSEPLAY ERROR: Could not save course to file: %q"):format(courseXmlFilePath));
			g_currentMission.cp_courseManager[freeSlot].isUsed = false;
			self:updateCourseManagerSlotsXml(freeSlot, cpCManXml);
		end;
		delete(courseXml);
	end;

	saveXMLFile(cpCManXml)
	if deleteFile then
		delete(cpCManXml)
	end
end

function courseplay.courses:saveCoursesToXml(cpCManXml)
--	function to save or update all courses by once
	local deleteFile = false;

	if cpCManXml == nil then
		cpCManXml = self:getCourseManagerXML();
		deleteFile = true;
	end;

	for k,_ in pairs(g_currentMission.cp_courses) do
		self:saveCourseToXml(k, cpCManXml)
	end

	if deleteFile then
		delete(cpCManXml);
	end;
end

function courseplay.courses:saveAllToXml(cpCManXml)
	-- saves or update all the courses and folders
	if g_server == nil then
		return;
	end;

	local deleteFile = false;
	if cpCManXml == nil then
		cpCManXml = self:getCourseManagerXML();
		deleteFile = true;
	end;

	self:saveFoldersToXml(cpCManXml);
	self:saveCoursesToXml(cpCManXml);

	if deleteFile then
		delete(cpCManXml)
	end
end

function courseplay.courses:removeFromManagerXml(type, type_id, cpCManXml)
	local deleteFile = false;
	if cpCManXml == nil then
		cpCManXml = self:getCourseManagerXML();
		deleteFile = true;
	end;

	local key = "";

	if type == "course" and type_id and type_id > 0 and type_id <= #g_currentMission.cp_courseManager then
		key = ("courseManager.saveSlot.slot(%d)"):format(g_currentMission.cp_courseManager[type_id].index);
		-- Set isUsed to false, so it can be used again later.
		setXMLBool(cpCManXml, key .. '#isUsed', false);
		g_currentMission.cp_courseManager[type_id].isUsed = false;

		-- Remove values that's not needed anymore
		if hasXMLProperty(cpCManXml, key .. "#id") then removeXMLProperty(cpCManXml, key .. "#id"); end;
		if hasXMLProperty(cpCManXml, key .. "#name") then removeXMLProperty(cpCManXml, key .. "#name"); end;
		if hasXMLProperty(cpCManXml, key .. "#parent") then removeXMLProperty(cpCManXml, key .. "#parent"); end;
		g_currentMission.cp_courseManager[type_id].id = nil;
		g_currentMission.cp_courseManager[type_id].name = nil;
		g_currentMission.cp_courseManager[type_id].parent = nil;

		-- Clear the courseStorage file for unused data.
		local courseXmlFilePath = CpManager.cpCoursesFolderPath .. g_currentMission.cp_courseManager[type_id].fileName;
		if fileExists(courseXmlFilePath) then
			local courseXml = createXMLFile("courseXml", courseXmlFilePath, 'course');
			saveXMLFile(courseXml);
			delete(courseXml);
		end;

	elseif type == "folder" then
		key = "courseManager.folders.folder";
		local id = courseplay.utils.findXMLNodeByAttr(cpCManXml, key, 'id', type_id, 'Int')
		if id >= 0 then
			removeXMLProperty(cpCManXml, key .. ("(%d)"):format(id));
		end;
	end;

	if g_server~= nil then
		saveXMLFile(cpCManXml)
		if deleteFile then
			delete(cpCManXml)
		end
	end
end

function courseplay.courses:updateCourseManagerSlotsXml(slot, cpCManXml)
	local deleteFile = false;
	if cpCManXml == nil then
		cpCManXml = self:getCourseManagerXML();
		deleteFile = true;
	end;

	if g_currentMission.cp_courseManager[slot].isUsed then
		local types = {
			isUsed = 'Bool',
			fileName = 'String',
			id = 'Int',
			name = 'String',
			parent = 'Int'
		};
		courseplay.utils.setMultipleXML(cpCManXml, string.format('courseManager.saveSlot.slot(%d)', g_currentMission.cp_courseManager[slot].index), g_currentMission.cp_courseManager[slot], types)
	else
		self.removeFromManagerXml("course", slot, cpCManXml);
	end;

	saveXMLFile(cpCManXml)
	if deleteFile then
		delete(cpCManXml)
	end
end

function courseplay.courses:getCourseManagerXML()
-- returns the file if success, nil else
	local cpCManXml;
	local filePath = CpManager.cpCourseManagerXmlFilePath;
	if filePath ~= nil then
		if fileExists(filePath) then
			cpCManXml = loadXMLFile("courseManagerXml", filePath)
		else
			cpCManXml = createXMLFile("courseManagerXml", filePath, 'courseManager')
		end
	else
		--this is a problem...
		-- File stays nil
	end
	return cpCManXml
end

function courseplay.courses:getMaxCourseID()
	local maxID;
	if g_currentMission.cp_courses ~= nil then
		maxID = courseplay.utils.table.getMax(g_currentMission.cp_courses, 'id')
		if  maxID == false then
			maxID = 0
		end
	end
	return maxID
end

function courseplay.courses:getMaxFolderID()
	local maxID;
	if g_currentMission.cp_folders ~= nil then
		maxID = courseplay.utils.table.getMax(g_currentMission.cp_folders, 'id')
		if  maxID == false then
			maxID = 0
		end
	end
	return maxID
end

function courseplay:linkParent(vehicle, index)
	if type(vehicle.cp.hud.courses[index]) ~= nil then
		local id = vehicle.cp.hud.courses[index].id
		local type = vehicle.cp.hud.courses[index].type
				
		if vehicle.cp.hud.choose_parent ~= true then
			vehicle.cp.hud.selected_child = { type = type, id = id }
			
			-- show folders:
			vehicle.cp.hud.showFoldersOnly = true
			vehicle.cp.hud.showZeroLevelFolder = true
			courseplay.settings.toggleFilter(vehicle, false);
			if type == 'folder' then
				vehicle.cp.folder_settings[id].skipMe = true
			end
			courseplay.hud.setCourses(vehicle,1)
			
			vehicle.cp.hud.choose_parent = true
			
		else -- choose_parent is true
			-- prepare showing courses:		
			vehicle.cp.hud.showFoldersOnly = false
			vehicle.cp.hud.showZeroLevelFolder = false
			courseplay.settings.toggleFilter(vehicle, true);
			if vehicle.cp.hud.selected_child.type == 'folder' then
				vehicle.cp.folder_settings[vehicle.cp.hud.selected_child.id].skipMe = false
			end
			vehicle.cp.hud.choose_parent = false

			-- link if possible and show courses anyway
			if type == 'folder' then --parent must be a folder!
				if vehicle.cp.hud.selected_child.type == 'folder' then
					g_currentMission.cp_folders[vehicle.cp.hud.selected_child.id].parent = id
					courseplay.courses:saveFolderToXml(vehicle.cp.hud.selected_child.id)
				else
					g_currentMission.cp_courses[vehicle.cp.hud.selected_child.id].parent = id
					courseplay.courses:saveCourseToXml(vehicle.cp.hud.selected_child.id)
				end
				g_currentMission.cp_sorted = courseplay.courses:sort()
				courseplay.settings.setReloadCourseItems()
			else
				courseplay.hud.setCourses(vehicle,1)
			end
		end -- if choose parent
	else
		-- type(vehicle.cp.hud.courses[index]) == nil
		if vehicle.cp.hud.choose_parent then
			print('folder not available')
			-- maybe there are no folders?
			-- go back
			vehicle.cp.hud.showFoldersOnly = false
			vehicle.cp.hud.showZeroLevelFolder = false
			courseplay.settings.toggleFilter(vehicle, true);
			if vehicle.cp.hud.selected_child.type == 'folder' then
				vehicle.cp.folder_settings[vehicle.cp.hud.selected_child.id].skipMe = false
			end
			courseplay.hud.setCourses(vehicle,1)
			
			vehicle.cp.hud.choose_parent = false
		end
	end -- if type(vehicle.cp.hud.courses[index]) ~= nil
	--courseplay.buttons:setActiveEnabled(vehicle, "page2");
end

function courseplay.courses:getNextCourse(vehicle, index, rev)
-- returns the next entry to be showed in the hud from index onwards (assuming index is item that is shown!)
-- if rev is true it is searchd reversely, the next item before index is returned
-- returns 0 if no item is found

	if vehicle == nil or index == nil then
		return 0
	end
	
	rev = rev or false
	local sorted_item = vehicle.cp.sorted.item
	local sorted_info = vehicle.cp.sorted.info
	local num_courses = #sorted_item
		
	if not rev then
		-- search forwards
		-- show child or next neighbour
		local no_next_entry = false
		local search_neighbour = false
		
		if sorted_item[index].type == "folder" then
			if vehicle.cp.folder_settings[ sorted_item[index].id ].showChildren then
				-- this should be fine even if the folder doesn't have a child
				index = index + 1
				
				-- Exceptions:
				while vehicle.cp.hud.showFoldersOnly and index <= num_courses and sorted_item[index].type ~= 'folder' do
					index = index + 1
				end
				if index <= num_courses and sorted_item[index].type == 'folder' and vehicle.cp.folder_settings[ sorted_item[index].id ].skipMe then
					-- show next neighbour or next neighbour of parent if there is none
					search_neighbour = true
				end
			else
				-- children aren't shown, show next neighbour though (if there is one)
				search_neighbour = true
			end				
		else
			-- index is a course, the next item in the list can not be a child but either 1)another course on the same level 2)course or a folder on a lower level
			-- therefore if next item was hidden, the current item would be hidden as well. As the current item is shown, the next item is shown as well:
			index = index + 1
			while (vehicle.cp.hud.showFoldersOnly and index <= num_courses) and sorted_item[index].type ~= 'folder' do
				-- folders only: skip courses until end reached or folder found
				index = index + 1
			end
			if index <= num_courses and sorted_item[index].type == 'folder' and vehicle.cp.folder_settings[ sorted_item[index].id ].skipMe then
				-- show next neighbour or next neighbour of parent (if there is none)
				search_neighbour = true
			end
		end
		
		-- search for next neighbour
		while search_neighbour and (not no_next_entry) do
			search_neighbour = false
			
			-- show next neighbour (if there is one)
			while ((sorted_info[ sorted_item[index].uid ].next_neighbour == 0) and (not no_next_entry)) do
				if sorted_item[index].level > 0 then
					index = index + sorted_info[ sorted_item[index].uid ].parent_ridx
				else
					no_next_entry = true
				end
			end
			index = index + sorted_info[sorted_item[index].uid].next_neighbour
				
			-- Exceptions
			if vehicle.cp.hud.showFoldersOnly and sorted_item[index].type ~= 'folder' then
				-- index is a course, all next neighbours (if there are) will be courses -> get next neighbour of parent
				search_neighbour = true
				if sorted_item[index].parent ~= 0 then
					index = index + sorted_info[ sorted_item[index].uid ].parent_ridx
				else
					no_next_entry = true
				end
			elseif sorted_item[index].type == 'folder' and vehicle.cp.folder_settings[ sorted_item[index].id ].skipMe then
				-- show next neighbour or next neighbour of parent (if there is none)
				search_neighbour = true
			end
		end -- while search_neighbour
			
		if index > num_courses or no_next_entry then
			-- we are over the end -> there is no next item
			index = 0
		end
	else
		-- reverse search
		-- go up to the next neighbour and search for the last shown child
		local search_neighbour = true
		local search_child = true
		
		while search_neighbour do
			search_neighbour = false
			if sorted_info[ sorted_item[index].uid ].leading_neighbour ~= 0 then
				-- if index is showen, also it's neightbours are:
				index = index + sorted_info[sorted_item[index].uid].leading_neighbour
				
				while search_child do
					-- let's see if the leading neighbour has children to show
					if sorted_item[index].type == "folder" then
						if vehicle.cp.folder_settings[ sorted_item[index].id ].showChildren and (sorted_info[ sorted_item[index].uid ].lastChild ~= 0) then
							-- there are children to show. Let's do the testing again with the last child
							index = index + sorted_info[ sorted_item[index].uid ].lastChild
						else
							-- children aren't shown, show folder itself though
							search_child = false
							
							-- Exceptions:
							if vehicle.cp.folder_settings[ sorted_item[index].id ].skipMe then
								search_neighbour = true
							end
						end
					else
						-- index is a course - no children to show - show corse itself though
						search_child = false
						
						-- Exceptions
						if vehicle.cp.hud.showFoldersOnly then
							search_neighbour = true
						end	
					end
				end
				
			else
				-- there is no leading neighbour. show parent folder if there is one
				if sorted_info[ sorted_item[index].uid ].parent_ridx ~= 0 then
					-- for entries with level=0, this returns 0 (level=0 entries don't have parents)
					index = index + sorted_info[ sorted_item[index].uid ].parent_ridx
					
					-- Exceptions:
					if index ~= 0 and vehicle.cp.folder_settings[ sorted_item[index].id ].skipMe then
						-- search again
						search_neighbour = true
					end
				else
					index = 0
				end			
			end
		end -- while search_neighbour
	end -- end of reverse search
	
	return index
end -- end of function

function courseplay.courses:getMeOrBestFit(self, index)
-- if parent doesn't show its children: parent is returned
-- if it's a course and showFoldersOnly is on: parent is returned
-- if it's a skipped folder or an item of one: next neighbour is returned
-- if no fit is found: zero is returned
	local parent_id = 0
	local done = false
	local s_item = self.cp.sorted.item
	local s_info = self.cp.sorted.info
	local n_s_item = #s_item
	
	if n_s_item == 0 then
		done = true
		index = 0
	elseif index < 1 then
		index = 1
	elseif index > n_s_item then
		index = n_s_item
	end

	while not done do	
		if s_item[index].parent == 0 then
			-- course or folder does not have a parent -> show it
			done = true
			
			-- Exceptions:
			if self.cp.hud.showFoldersOnly and (not s_item[index].type == 'folder') then
				-- nothing to show!
				index = 0
			elseif s_item[index].type == 'folder' and self.cp.folder_settings[s_item[index].id].skipMe then
				if s_info[ s_item[index].uid ].next_neighbour ~= 0 then
					index = index + s_info[ s_item[index].uid ].next_neighbour
					done = false
				else
					-- nothing to show!
					index = 0
				end
			end
			
		else
			-- get parent id
			parent_id = s_item[index].parent
			
			-- does the parent of the parent of the parent show its children?
			local finished = false
			while not finished do
				
				if self.cp.folder_settings[parent_id].showChildren and (not self.cp.folder_settings[parent_id].skipMe) then
					-- parent shows children, but does parent have a parent itself?
					if g_currentMission.cp_folders[parent_id].parent ~= 0 then
						parent_id = g_currentMission.cp_folders[parent_id].parent
					else
						-- no parent anymore -> all of index's parent show it's children: we are done done!
						done = true
						finished = true
						
						-- Exceptions: 
						if self.cp.hud.showFoldersOnly and (not s_item[index].type == 'folder') then
						-- index is not a folder, but it's parent will be one (and it has a parent, otherwise code would not arrive here)
							index = index + s_info[ s_item[index].uid ].parent_ridx
							done = false
						elseif s_item[index].type == 'folder' and self.cp.folder_settings[s_item[index].id].skipMe then				
							-- folder is skipped
							local continue = true
							while continue do
								if s_info[ s_item[index].uid ].next_neighbour ~= 0 then
								-- if it has a neighbour, try to show this
									index = index + s_info[ s_item[index].uid ].next_neighbour
									continue = false
									done = false
								elseif s_item[index].parent ~= 0 then
								-- no neighbour but a parent: use parent in the next loop to see if the parent has a neighbour
									index = index + s_info[ s_item[index].uid ].parent_ridx
								else
								-- none of the parents has a neighbour! -> nothing to show
									index = 0
									continue = false
								end
							end
						end -- Exceptions
						
					end
				elseif self.cp.folder_settings[parent_id].skipMe then
				-- parent is skipped -> try to show neighbour of parent
					index = s_info['f'.. parent_id].sorted_index
					local continue = true
					while continue do
						if s_info[ s_item[index].uid ].next_neighbour ~= 0 then
						-- if it has a neighbour, try to show this
							index = index + s_info[ s_item[index].uid ].next_neighbour
							continue = false
							finished = true
						elseif s_item[index].parent ~= 0 then
						-- no neighbour but a parent: use parent in the next loop to see if the parent has a neighbour
							index = index + s_info[ s_item[index].uid ].parent_ridx
						else
						-- none of the parents has a neighbour! -> nothing to show
							index = 0
							continue = false
							finished = true
							done = true
						end
					end
				else
					-- parent doesn't show children (index is hidden) -> search next shown parent
					index = index + s_info[ s_item[index].uid ].parent_ridx		--index of parent
					finished = true
				end
			end -- while not finished
		end -- if has parent (end of else)
	end -- while not done
	return index
end

function courseplay.courses:reloadVehicleCourses(vehicle)
	if vehicle ~= nil then
		-- reload courses (sort)
		if vehicle.cp.hud.filter == '' then
			vehicle.cp.sorted = g_currentMission.cp_sorted
		else
			local parent
			local courses, folders = {}, {}
			local searchTermClean = courseplay:normalizeUTF8(vehicle.cp.hud.filter);
			courseplay:debug(string.format("%s: [filter] searchTermClean = %q", nameNum(vehicle), tostring(searchTermClean)), 8);

			-- filter courses
			for k, course in pairs(g_currentMission.cp_courses) do
				if string.match(course.nameClean, searchTermClean) ~= nil then
					courseplay:debug(string.format("\tmatch: course.nameClean=%q / searchTermClean = %q", tostring(course.nameClean), tostring(searchTermClean)), 8);
					courses[k] = course
					-- add parents
					parent = course.parent
					while parent ~= 0 and folders[parent] == nil do	-- if folder[parent] is not nil, the folder was already added and therefore also it's parents
						folders[parent] = g_currentMission.cp_folders[parent]
						parent = g_currentMission.cp_folders[parent].parent
					end
				end
			end

			-- sort
			-- sort(courses_to_sort, folders_to_sort, parent_id, level, make_copies)
			vehicle.cp.sorted = self:sort(courses, folders, 0, 0, false)
		end
		
		-- update folder settings here??
		
		-- update items for the hud
		courseplay.hud.reloadCourses(vehicle);
		
		vehicle.cp.reloadCourseItems = false
	end -- end vehicle ~= nil
end

function courseplay.courses:loadCoursesAndFoldersFromXml()
	print('## Courseplay: loading courses and folders from "courseManager.xml"');
	local cpCManXml = self:getCourseManagerXML();
	if cpCManXml and cpCManXml ~= 0 then
		local save = false;
		local courses_by_id = {};
		local folders_by_id = {};

		g_currentMission.cp_courseManager = nil;
		g_currentMission.cp_courseManager = {};

		local index = 0;
		while true do
			-- current course
			local key = ('courseManager.saveSlot.slot(%d)'):format(index);
			if not hasXMLProperty(cpCManXml, key) then
				break;
			end;

			local info = {
				index =	   index;
				isUsed =   getXMLBool(cpCManXml, key .. '#isUsed');
				fileName = getXMLString(cpCManXml, key .. '#fileName');
				id =	   getXMLInt(cpCManXml, key .. '#id');
				name =	   getXMLString(cpCManXml, key .. '#name');
				parent =   getXMLInt(cpCManXml, key .. '#parent');
			};
			table.insert(g_currentMission.cp_courseManager, info);

			index = index + 1;
		end;


		g_currentMission.cp_courses = nil -- make sure it's empty (especially in case of a reload)
		g_currentMission.cp_courses = {}
		courses_by_id = g_currentMission.cp_courses
		local courses_without_id = {}
		-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		-- LOAD COURSES
		local waypoints;
		for slotId, slot in ipairs(g_currentMission.cp_courseManager) do
			if slot.isUsed then
				local courseXmlFilePath = CpManager.cpCoursesFolderPath .. slot.fileName;
				local courseXml = loadXMLFile("courseXml", courseXmlFilePath)

				-- current course
				local courseKey = "course";

				-- course name
				local courseName = slot.name;
				if courseName == nil then
					courseName = ('NO_NAME%d'):format(slotId);
				end;
				local courseNameClean = courseplay:normalizeUTF8(courseName);

				-- course ID
				local id = slot.id or 0;

				-- course parent
				local parent = slot.parent or 0;

				-- course workWidth
				local workWidth = getXMLFloat(courseXml, courseKey .. "#workWidth");

				-- course numHeadlandLanes
				local numHeadlandLanes = getXMLInt(courseXml, courseKey .. "#numHeadlandLanes");

				-- course headlandDirectionCW
				local headlandDirectionCW = getXMLBool(courseXml, courseKey .. "#headlandDirectionCW");
				
				local multiTools = getXMLInt(courseXml, courseKey .. "#multiTools");

				--course waypoints
				waypoints = {};
				local wpNum = 1;
				while true do
					local key = courseKey .. '.waypoint' .. wpNum;
					if not hasXMLProperty(courseXml, key .. '#pos') then
						break;
					end;
					local x, z = Utils.getVectorFromString(getXMLString(courseXml, key .. '#pos'));
					if x == nil or z == nil then
						break;
					end;
					local angle 	  =  getXMLFloat(courseXml, key .. '#angle') or 0;
					local speed 	  = getXMLString(courseXml, key .. '#speed') or '0'; -- use string so we can get both ints and proper floats without LUA's rounding errors
					speed = tonumber(speed);
					if ceil(speed) ~= speed then -- is it an old savegame with old speeds ?
						speed = ceil(speed * 3600);
					end;
					-- NOTE: only pos, angle and speed can't be nil. All others can and should be nil if not "active", so that they're not saved to the xml
					local wait 		  =    getXMLInt(courseXml, key .. '#wait');
					local unload	  =    getXMLInt(courseXml, key .. '#unload');
					local rev 		  =    getXMLInt(courseXml, key .. '#rev');
					local crossing 	  =    getXMLInt(courseXml, key .. '#crossing');
					local generated   =   getXMLBool(courseXml, key .. '#generated');
					local lane		  =    getXMLInt(courseXml, key .. '#lane');
					local laneDir	  = getXMLString(courseXml, key .. '#dir');
					local turnStart	  =    getXMLInt(courseXml, key .. '#turnstart');
					local turnEnd 	  =    getXMLInt(courseXml, key .. '#turnend');
					local ridgeMarker =    getXMLInt(courseXml, key .. '#ridgemarker') or 0;
					local isConnectingTrack   =   getXMLBool(courseXml, key .. '#isconnectingtrack');
					crossing = crossing == 1 or wpNum == 1;
					wait = wait == 1;
					unload = unload == 1;
					rev = rev == 1;
					turnStart = turnStart == 1;
					turnEnd = turnEnd == 1;
					waypoints[wpNum] = {
						cx = x,
						cz = z,
						angle = angle,
						speed = speed,
						rev = rev,
						wait = wait,
						unload = unload,
						crossing = crossing,
						generated = generated,
						lane = lane,
						turnStart = turnStart,
						turnEnd = turnEnd,
						ridgeMarker = ridgeMarker,
            isConnectingTrack = isConnectingTrack
					};
					wpNum = wpNum + 1;
				end; -- END while true (waypoints)
				local course = {
					id =				  id,
					uid =				  'c' .. id ,
					type =				  'course',
					name =				  courseName,
					nameClean =			  courseNameClean,
					waypoints =			  waypoints,
					parent =			  parent,
					workWidth =			  workWidth,
					numHeadlandLanes =	  numHeadlandLanes,
					headlandDirectionCW = headlandDirectionCW,
					multiTools = 		  multiTools
				};
				if id ~= 0 then
					courses_by_id[id] = course;
				else
					table.insert(courses_without_id, course);
				end;
				waypoints = nil;

				delete(courseXml);
			end;
		end; -- END for loop

		if #courses_without_id > 0 then
			-- give a new ID and save
			local maxID = self:getMaxCourseID()
			for i = 1, #courses_without_id do
				maxID = maxID + 1
				courses_without_id[i].id = maxID
				courses_without_id[i].uid = 'c' .. maxID
				courses_by_id[maxID] = courses_without_id[i]
			end
			save = true
		end


		-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		-- LOAD FOLDERS
		local j = 0
		local currentFolder, FolderName, id, parent, folder
		local finish_all = false
		g_currentMission.cp_folders = nil
		g_currentMission.cp_folders = {}
		folders_by_id = g_currentMission.cp_folders
		local folders_without_id = {}
		repeat
			-- current folder
			currentFolder = string.format("courseManager.folders.folder(%d)", j)
			if not hasXMLProperty(cpCManXml, currentFolder) then
				finish_all = true;
				break;
			end;

			-- folder name
			FolderName = getXMLString(cpCManXml, currentFolder .. "#name")
			if FolderName == nil then
				FolderName = string.format('NO_NAME%d',j)
			end
			local folderNameClean = courseplay:normalizeUTF8(FolderName);

			-- folder id
			id = getXMLInt(cpCManXml, currentFolder .. "#id")
			if id == nil then
				id = 0
			end

			-- folder parent
			parent = getXMLInt(cpCManXml, currentFolder .. "#parent")
			if parent == nil then
				parent = 0
			end

			-- "save" current folder
			folder = { id = id, uid = 'f' .. id, type = 'folder', name = FolderName, nameClean = folderNameClean, parent = parent }
			if id ~= 0 then
				folders_by_id[id] = folder
			else
				table.insert(folders_without_id, folder)
			end
			j = j + 1
		until finish_all == true

		if #folders_without_id > 0 then
			-- give a new ID and save
			local maxID = self:getMaxFolderID()
			for i = #folders_without_id, 1, -1 do
				maxID = maxID + 1
				folders_without_id[i].id = maxID
				folders_without_id[i].uid = 'f' .. maxID
				folders_by_id[maxID] = table.remove(folders_without_id)
			end
			save = true
		end

		if CpManager.oldCPFileExists then
			save, courses_by_id, folders_by_id = CpManager:importOldCPFiles(save, courses_by_id, folders_by_id);
		end;

		if save then
			-- this will update courseManager file and therefore update the courses and folders without ids.
			self:saveAllToXml(cpCManXml);
		end
		delete(cpCManXml);

		g_currentMission.cp_sorted = self:sort(courses_by_id, folders_by_id, 0, 0)

		courseplay:debug(tableShow(g_currentMission.cp_sorted.item, "cp_sorted.item", 8), 8);

		return g_currentMission.cp_courses;
	elseif CpManager.cpCourseManagerXmlFilePath then
		print(("COURSEPLAY ERROR: unable to load or create -> %s"):format(CpManager.cpCourseManagerXmlFilePath));
	end; --END if savegame ~= nil

	return nil;
end;

--UTF-8: ALLOWED CHARACTERS and NORMALIZATION
--src: ASCII Table - Decimal (Base 10) Values @ http://www.parse-o-matic.com/parse/pskb/ASCII-Chart.htm
--src: http://en.wikipedia.org/wiki/List_of_Unicode_characters
function courseplay:getAllowedCharacters()
	local allowedSpan = { from = 32, to = 591 };
	local prohibitedUnicodes = { [34] = true, [39] = true, [94] = true, [96] = true, [215] = true, [247] = true };
	for unicode=127,190 do
		prohibitedUnicodes[unicode] = true;
	end;

	local result = {};
	for unicode=allowedSpan.from,allowedSpan.to do
		prohibitedUnicodes[unicode] = prohibitedUnicodes[unicode] or false;
		result[unicode] = not prohibitedUnicodes[unicode] and getCanRenderUnicode(unicode);
		if courseplay.debugChannels and courseplay.debugChannels[8] and getCanRenderUnicode(unicode) then
			print(string.format('allowedCharacters[%d]=%s (%q) (prohibited=%s, getCanRenderUnicode()=true)', unicode, tostring(result[unicode]), unicodeToUtf8(unicode), tostring(prohibitedUnicodes[unicode])));
		end;
	end;

	return result;
end;

function courseplay:getUtf8normalization()
	local result = {};

	local normalizationSpans = {
		a  = { {192,195}, 197, {224,227}, 229, {256,261} },
		ae = { 196, 198, 228, 230 },
		c  = { 199, 231, {262,269} },
		d  = { {270,273} },
		e  = { {200,203}, {232,235}, {274,283} },
		g  = { {284,291} },
		h  = { {292,295} },
		i  = { {204,207}, {236,239}, {296,307} },
		j  = { {308,309} },
		k  = { {310,312} },
		l  = { {313,322} },
		n  = { 209, 241, {323,331} },
		o  = { {210,213}, {242,245}, {332,337} },
		oe = { 214, 216, 246, 248, 338, 339 },
		r  = { {340,345} },
		s  = { {346,353}, 383 },
		ss = { 223 },
		t  = { {354,359} },
		u  = { {217,219}, {249,251}, {360,371} },
		ue = { 220, 252 },
		w  = { 372, 373 },
		y  = { 221, 253, 255, {374,376} },
		z  = { {377,382} }
	};

	--[[
	local test = { 197, 229, 216, 248, 198, 230 };
	for _,unicode in pairs(test) do
		print(string.format("%q: getCanRenderUnicode(%d)=%s", unicodeToUtf8(unicode), unicode, tostring(getCanRenderUnicode(unicode))));
	end;
	]]

	for normal,unicodes in pairs(normalizationSpans) do
		for _,data in pairs(unicodes) do
			if type(data) == "number" then
				local utf8 = unicodeToUtf8(data);
				result[utf8] = normal;
				if false and getCanRenderUnicode(data) then
					print(string.format("courseplay.utf8normalization[%q] = %q", utf8, normal));
				end;
			elseif type(data) == "table" then
				for unicode=data[1],data[2] do
					local utf8 = unicodeToUtf8(unicode);
					result[utf8] = normal;
					if false and getCanRenderUnicode(unicode) then
						print(string.format("courseplay.utf8normalization[%q] = %q", utf8, normal));
					end;
				end;
			end;
		end;
	end;

	return result;
end;

function courseplay:normalizeUTF8(str)
	local len = str:len();
	local utfLen = utf8Strlen(str);
	courseplay:debug(string.format("str %q: len=%d, utfLen=%d", str, len, utfLen), 8);

	if len ~= utfLen then --special char in str
		local result = "";
		for i=0,utfLen-1 do
			local char = utf8Substr(str,i,1);
			courseplay:debug(string.format("\tchar=%q, replaceChar=%q", char, tostring(courseplay.utf8normalization[char])), 8);

			local clean = courseplay.utf8normalization[char] or char:lower();
			result = result .. clean;
		end;
		courseplay:debug(string.format("normalizeUTF8(%q) --> clean=%q", str, result), 8);
		return result;
	end;

	return str:lower();
end;

