-- saving // loading courses

-- enables input for course name
function courseplay:showSaveCourseForm(self, saveWhat)
	saveWhat = saveWhat or 'course'
	
	if saveWhat == 'course' then
		if table.getn(self.Waypoints) > 0 then
			courseplay.vehicleToSaveCourseIn = self;
			if self.cp.imWriting then
				self.cp.saveWhat = 'course'
				g_gui:showGui("inputCourseNameDialogue");
				self.cp.imWriting = false
			end
		end;
		
	elseif saveWhat == 'folder' then
		courseplay.vehicleToSaveCourseIn = self;
		if self.cp.imWriting then
			self.cp.saveWhat = 'folder'
			g_gui:showGui("inputCourseNameDialogue");
			self.cp.imWriting = false
		end
	
	elseif saveWhat == 'filter' then
		if self.cp.hud.filter == '' then
			courseplay.vehicleToSaveCourseIn = self;
			if self.cp.imWriting then
				self.cp.saveWhat = 'filter';
				g_gui:showGui("inputCourseNameDialogue");
				self.cp.imWriting = false;
			end;
		else
			self.cp.hud.filter = '';
			local button = self.cp.buttons["2"][self.cp.hud.filterButtonIndex];
			courseplay.button.setOverlay(button, 1);
			courseplay.settings.setReloadCourseItems(self);
		end;
	end
end;

function courseplay:reload_courses(self, use_real_id)
	local courses = self.cp.loadedCourses
	self.cp.loadedCourses = {}
	for k, v in pairs(courses) do
		courseplay:load_course(self, v, use_real_id)
	end
end

function courseplay:reinit_courses(self)
	if g_currentMission.cp_courses == nil then
		courseplay:debug("cp_courses is empty", 8)
		if g_server ~= nil then
			courseplay_manager:load_courses();
		end
		return
	end
end

function courseplay:add_sorted_course(vehicle, index)
	local id = vehicle.cp.hud.courses[index].id
	courseplay:load_course(vehicle, id, true, true)	
end

function courseplay:load_sorted_course(vehicle, index)
	if type(vehicle.cp.hud.courses[index]) ~= nil then
		local id = vehicle.cp.hud.courses[index].id
		courseplay:load_course(vehicle, id, true)
	end	
end

function courseplay:load_course(self, id, useRealId, addCourseAtEnd)
	-- global array for courses, no refreshing needed any more
	courseplay:reinit_courses(self);

	if addCourseAtEnd == nil then addCourseAtEnd = false; end;

	courseplay:debug(string.format('%s: load_course(..., id=%s, useRealId=%s, addCourseAtEnd=%s)', nameNum(self), tostring(id), tostring(useRealId), tostring(addCourseAtEnd)), 8);
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
			table.insert(self.cp.loadedCourses, id * -1)
		else
			table.insert(self.cp.loadedCourses, id)
		end

		--	courseplay:reset_course(self)
		if #self.Waypoints == 0 then
			self.cp.numCourses = 1;
			self.Waypoints = course.waypoints
			self.cp.numWaypoints = #self.Waypoints;
			self.cp.currentCourseName = course.name
			courseplay:debug(string.format("course_management %d: %s: no course was loaded -> new course = course -> currentCourseName=%q, numCourses=%s", debug.getinfo(1).currentline, nameNum(self), tostring(self.cp.currentCourseName), tostring(self.cp.numCourses)), 8);

		else -- add new course to old course
			if self.cp.currentCourseName == nil then --recorded but not saved course
				self.cp.numCourses = 1;
			end;
			courseplay:debug(string.format("course_management %d: %s: currentCourseName=%q, numCourses=%s -> add new course %q", debug.getinfo(1).currentline, nameNum(self), tostring(self.cp.currentCourseName), tostring(self.cp.numCourses), tostring(course.name)), 8);


			local course1, course2 = self.Waypoints, course.waypoints;
			local numCourse1, numCourse2 = #course1, #course2;
			local course1wp, course2wp = numCourse1, 1;

			--find crossing points, merge at first pair where dist < 50
			local firstMatchFound, closestMatchFound = false, false;
			local useFirstMatch = false; --true: first match <50m is used to merge / false: match with closest distance <50m is used to merge;
			if not addCourseAtEnd then
				--find crossing points
				local crossingPoints = { [1] = {}, [2] = {} };
				for i=self.cp.lastMergedWP + 1, numCourse1 do
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

									self.cp.lastMergedWP = wpNum1;
									course1[course1wp].merged = true;
									course2[course2wp].merged = true;

									firstMatchFound = true;
									courseplay:debug(string.format('\tuseFirstMatch=true -> 2 valid crossing points found: (1)=#%d, (2)=#%d, dist=%.1f -> lastMergedWP=%d, set "merged" for both to "true", break', course1wp, course2wp, dist, self.cp.lastMergedWP), 8);
								else
									if dist < smallestDist then
										smallestDist = dist;

										--remove previous 'merged' vars
										course1[course1wp].merged = nil;
										course2[course2wp].merged = nil;

										course1wp = wpNum1;
										course2wp = wpNum2;

										self.cp.lastMergedWP = wpNum1;
										course1[course1wp].merged = true;
										course2[course2wp].merged = true;

										closestMatchFound = true;
										courseplay:debug(string.format('\tuseFirstMatch=false -> 2 valid crossing points found: (1)=#%d, (2)=#%d, dist=%.1f -> lastMergedWP=%d, set "merged" for both to "true", continue', course1wp, course2wp, dist, self.cp.lastMergedWP), 8);
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
					courseplay:debug(string.format('%s: merge points found: course 1: #%d, course 2: #%d', nameNum(self), course1wp, course2wp), 8);
				else
					courseplay:debug(string.format('%s: no points where the courses could be merged have been found -> add 2nd course at end', nameNum(self)), 8);
				end;
			end;

			self.Waypoints = {};
			for i=1, course1wp do
				table.insert(self.Waypoints, course1[i]);
			end;
			for i=course2wp, numCourse2 do
				table.insert(self.Waypoints, course2[i]);
			end;

			self.cp.numWaypoints = #self.Waypoints;
			self.cp.numCourses = self.cp.numCourses + 1;
			self.cp.currentCourseName = string.format("%d %s", self.cp.numCourses, courseplay:loc('CPCourseAdded'));
			courseplay:debug(string.format('%s: adding course done -> numWaypoints=%d, numCourses=%s, currentCourseName=%q', nameNum(self), self.cp.numWaypoints, self.cp.numCourses, self.cp.currentCourseName), 8);
		end;

		self.cp.canDrive = true;

		self.recordnumber = 1;  -- Waypoint number
		courseplay:updateWaypointSigns(self, "current");

		self.cp.hasGeneratedCourse = false;
		courseplay:validateCourseGenerationData(self);

		courseplay:validateCanSwitchMode(self);
	end
end

function courseplay.courses.sort(courses_to_sort, folders_to_sort, parent_id, level, make_copies)
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
		temp_sorted, temp_last_child = courseplay.courses.sort(courses_to_sort, folders_to_sort, folders[i].id, level+1, false)
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

function courseplay:reset_merged(self)
	for _,course in pairs(g_currentMission.cp_courses) do
		for num, wp in pairs(course.waypoints) do
			wp.merged = nil
		end
	end
end

function courseplay:delete_sorted_item(vehicle, index)
	local id = vehicle.cp.hud.courses[index].id
	local type = vehicle.cp.hud.courses[index].type
	
	if type == 'course' then
		g_currentMission.cp_courses[id] = nil
		
	elseif type == 'folder' then
		-- check for children: delete only if folder has no children
		if g_currentMission.cp_sorted.info['f'..id].lastChild == 0 then
			g_currentMission.cp_folders[id] = nil
		end
	else
		--Error?!
	end
	
	g_currentMission.cp_sorted = courseplay.courses.sort()
	courseplay.courses.save_all()
	courseplay.settings.setReloadCourseItems()
	courseplay:updateWaypointSigns(vehicle);
end

function courseplay.courses.save_parent(type, id)
	if id ~= nil and id > 0 then
		local File = courseplay.courses.openOrCreateXML()
		local i = 0
		local node=''
		local value
		
		if type == 'course' then
			i = courseplay.utils.findXMLNodeByAttr(File, 'XML.courses.course', 'id', id, 'Int')
			if i >= 0 then
				node = string.format('XML.courses.course(%d)',i)
				value = g_currentMission.cp_courses[id].parent
			end
		elseif type == 'folder' then
			i = courseplay.utils.findXMLNodeByAttr(File, 'XML.folders.folder', 'id', id, 'Int')
			if i >= 0 then
				node = string.format('XML.folders.folder(%d)',i)
				value = g_currentMission.cp_folders[id].parent
			end
		end
		
		if node ~= '' then
			setXMLInt(File, node .. '#parent', value)
			saveXMLFile(File)
		end
		delete(File)
	end
end

function courseplay.courses.save_course(course_id, File, append)
-- save course to xml file
--
-- append (bool,integer): append can be a bool or an integer
--		if it's false, the function will check if the id exists in the file. if it exists, it will overwrite it otherwise it will append
--		if append is true, the function will search for the next free position and save there
--		if append is an integer, the function will save at this position (without checking if it is the end or what there was before)
	local deleteFile = false
	if append == nil then
		append = false  -- slow but secure
	end
	
	if File == nil then
		File = courseplay.courses.openOrCreateXML()
		deleteFile = true
	end
	
	-- { id = id, type = 'course', name = name, waypoints = tempCourse, parent = parent }
	local types = { id = 'Int', name = 'String', parent = 'Int'}
	local i = 0
	
	-- find the node position and save the attributes
	if append ~= false then
		if append == true then
			i = courseplay.utils.findFreeXMLNode(File,'XML.courses.course')
		else
			i = append
		end
	else
		i = courseplay.utils.findXMLNodeByAttr(File, 'XML.courses.course', 'id', course_id, 'Int')
		if i < 0 then i = -i end
	end
	courseplay.utils.setMultipleXML(File, string.format('XML.courses.course(%d)', i), g_currentMission.cp_courses[course_id], types)
	
	-- save waypoint: rev, wait, crossing, generated, turnstart, turnend are bools; turn is a string; turn, speed may be nil!
	-- from xml: rev=int wait=int crossing=int generated=bool, turn=string!!, turnstart=int turnend=int ridgemarker=int
	-- xml: pos="float float" angle=float rev=0/1 wait=0/1 crossing=0/1 speed=float generated="true/false" turn="true/false" turnstart=0/1 turnend=0/1 ridgemarker=0/1/2
	local waypoints = {}
	-- setXMLFloat seems imprecise...
	types = { pos='String', angle='String', rev='Int', wait='Int', crossing='Int', speed='String', generated='Bool', dir='String', turn='String', turnstart='Int', turnend='Int', ridgemarker='Int' };

	for k, v in pairs(g_currentMission.cp_courses[course_id].waypoints) do
		local waypoint = {} --create a new table on every call
		waypoint.pos = tostring(courseplay:round(v.cx, 4)) .. ' ' .. tostring(courseplay:round(v.cz, 4));
		waypoint.angle = tostring(courseplay:round(v.angle, 4));
		-- the following would not be necessary if bools would be saved as bools instead of converting them to integers...
		waypoint.rev = courseplay:boolToInt(v.rev);
		waypoint.wait = courseplay:boolToInt(v.wait);
		waypoint.crossing = courseplay:boolToInt(v.crossing);
		waypoint.speed = tostring(courseplay:round(v.speed or 0, 5));
		waypoint.generated = Utils.getNoNil(v.generated,false);
		waypoint.dir = v.laneDir or "";
		waypoint.turn = v.turn or "false";
		waypoint.turnstart = Utils.getNoNil(courseplay:boolToInt(v.turnStart),0);
		waypoint.turnend = Utils.getNoNil(courseplay:boolToInt(v.turnEnd),0);
		waypoint.ridgemarker = Utils.getNoNil(v.ridgeMarker,0);

		waypoints[k] = waypoint;
	end
	
	courseplay.utils.setMultipleXMLNodes(File, string.format('XML.courses.course(%d)', i), 'waypoint', waypoints, types, true)
	
	saveXMLFile(File)
	if deleteFile then
		delete(File)
	end
end

function courseplay.courses.save_folder(folder_id, File, append)
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
	
	if File == nil then
		File = courseplay.courses.openOrCreateXML()
		deleteFile = true
	end

	-- { id = id, type = 'folder', name = name, parent = parent }
	local types = { id = 'Int', name = 'String', parent = 'Int'}
	local i = 0
	
	-- find the node position and save the attributes
	if append ~= false then
		if append == true then
			i = courseplay.utils.findFreeXMLNode(File,'XML.folders.folder')
		else
			i = append
		end
	else
		i = courseplay.utils.findXMLNodeByAttr(File, 'XML.folders.folder', 'id', folder_id, 'Int')
		if i < 0 then i = -i end
	end
	courseplay.utils.setMultipleXML(File, string.format('XML.folders.folder(%d)', i), g_currentMission.cp_folders[folder_id], types)
	
	saveXMLFile(File)
	if deleteFile then
		delete(File)
	end
end

function courseplay.courses.save_folders(File, append)
--	function to save all folders by once
--	append (bool): whether to append to the file (true) or check if the id exists (false)
	local deleteFile = false
	if append == nil then
		append = false
	end
	
	if File == nil then
		File = courseplay.courses.openOrCreateXML()
		deleteFile = true
	end
	
	if append then
		append = courseplay.utils.findFreeXMLNode(File,'XML.folders.folder')
	end
	
	for k,_ in pairs(g_currentMission.cp_folders) do
		courseplay.courses.save_folder(k, File, append)
		if append ~= false then
			append = append + 1
		end
	end
	if deleteFile then
		delete(File)
	end
end

function courseplay.courses.save_courses(File, append)
--	function to save all courses by once
--	append (bool): whether to append to the file (true) or check if the id exists (false)
	local deleteFile = false
	if append == nil then
		append = false
	end
	
	if File == nil then
		File = courseplay.courses.openOrCreateXML()
		deleteFile = true
	end
	
	if append then
		append = courseplay.utils.findFreeXMLNode(File,'XML.courses.course')
	end
	
	for k,_ in pairs(g_currentMission.cp_courses) do
		courseplay.courses.save_course(k, File, append) -- append is either false or an integer here
		if append ~= false then
			append = append + 1
		end
	end
	
	if deleteFile then
		delete(File)
	end
end

function courseplay.courses.delete_save_all(self)
-- saves courses to xml-file
-- opening the file with io.open will delete its content...
	if g_server ~= nil then
		local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
		if savegame ~= nil and g_currentMission.cp_courses ~= nil then
			local file = io.open(savegame.savegameDirectory .. "/courseplay.xml", "w");
			if file ~= nil then
				file:write('<?xml version="1.0" encoding="utf-8" standalone="no" ?>\n<XML>\n');
				file:write(string.format('\t<courseplayHud posX="%.3f" posY="%.3f" />\n', courseplay.hud.infoBasePosX, courseplay.hud.infoBasePosY));
				file:write(string.format('\t<courseplayGlobalInfoText posX="%.3f" posY="%.3f" />\n', courseplay.globalInfoText.posX, courseplay.globalInfoText.posY));
				file:write(string.format('\t<courseplayFields automaticScan=%q onlyScanOwnedFields=%q debugScannedFields=%q debugCustomLoadedFields=%q scanStep="%d" />\n', tostring(courseplay.fields.automaticScan), tostring(courseplay.fields.onlyScanOwnedFields), tostring(courseplay.fields.debugScannedFields), tostring(courseplay.fields.debugCustomLoadedFields), courseplay.fields.scanStep));

				file:write('\t<folders>\n')
				for i,folder in pairs(g_currentMission.cp_folders) do
					file:write('\t\t<folder name="' .. folder.name .. '" id="' .. folder.id .. '" parent="' .. folder.parent ..'" />\n');
				end
				file:write('\t</folders>\n')
				
				file:write('\t<courses>\n')
				for i,course in pairs(g_currentMission.cp_courses) do
					file:write('\t\t<course name="' .. course.name .. '" id="' .. course.id .. '" numWaypoints="' .. #(course.waypoints) .. '" parent="' .. course.parent ..'">\n');
					for wpNum,wp in ipairs(course.waypoints) do
						local wpContent = '\t\t\t<waypoint' .. wpNum .. ' ';
						wpContent = wpContent .. 'pos="' .. tostring(Utils.getNoNil(courseplay:round(wp.cx, 4), 0)) .. ' ' .. tostring(Utils.getNoNil(courseplay:round(wp.cz, 4), 0)) .. '" ';
						wpContent = wpContent .. 'angle="' .. tostring(Utils.getNoNil(courseplay:round(wp.angle, 2), 0)) .. '" ';
						wpContent = wpContent .. 'wait="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.wait), 0)) .. '" ';
						wpContent = wpContent .. 'crossing="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.crossing), 0)) .. '" ';
						wpContent = wpContent .. 'rev="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.rev), 0)) .. '" ';
						wpContent = wpContent .. 'speed="' .. tostring(courseplay:round(Utils.getNoNil(wp.speed, 0), 5)) .. '" ';
						if wp.laneDir then
							wpContent = wpContent .. 'dir="' .. tostring(wp.laneDir) .. '" '; --no getNoNil as we want it to be nil if it doesn't exist during loading
						end;
						wpContent = wpContent .. 'turn="' .. tostring(Utils.getNoNil(wp.turn, false)) .. '" ';
						wpContent = wpContent .. 'turnstart="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.turnStart), 0)) .. '" ';
						wpContent = wpContent .. 'turnend="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.turnEnd), 0)) .. '" ';
						wpContent = wpContent .. 'ridgemarker="' .. tostring(Utils.getNoNil(wp.ridgeMarker, 0)) .. '" ';
						wpContent = wpContent .. 'generated="' .. tostring(Utils.getNoNil(wp.generated, false)) .. '" ';
						wpContent = wpContent .. '/>\n';

						file:write(wpContent);
					end;
					file:write('\t\t</course>\n');
				end;
				file:write('\t</courses>\n</XML>');
				file:close();
			else
				print("Error: Courseplay courses could not be saved to " .. tostring(savegame.savegameDirectory) .. "/courseplay.xml"); 
			end;
		end;
	end;
end;

function courseplay.courses.save_all(recreateXML)
-- saves all the courses and folders
-- recreateXML (bool): 	if nil or true the xml file will be overwritten. While saving each course/folder it is saved without 
--							checking if the id already exists in the file (it should not as the file was deleted and therefore empty).  This is faster than
--						if false, the xml file will only be created if it doesn't exist. If there exists already a course/folder with the specific id in the xml, it will be overwritten
	if recreateXML == nil then
		recreateXML = true
	end
	
	if recreateXML then
	-- new version (better performance):
		courseplay.courses.delete_save_all()
	else
	-- old version:
		local f = courseplay.courses.openOrCreateXML(recreateXML)
		saveXMLFile(f)
		
		courseplay.courses.save_folders(f, recreateXML)			 -- append and don't check for id if recreateXML is true
		courseplay.courses.save_courses(f, recreateXML)
		delete(f)
	end
end

function courseplay.courses.openOrCreateXML(forceCreation)
-- returns the file if success, nil else
	forceCreation = forceCreation or false
	
	local File = nil
	local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
	
	if savegame ~= nil then
		local filePath = savegame.savegameDirectory .. "/courseplay.xml"
		if fileExists(filePath) and (not forceCreation) then
			File = loadXMLFile("courseFile", filePath)
		else
			File = createXMLFile("courseFile", filePath, 'XML')
		end
	else
		--this is a problem...
		-- File stays nil
	end	
	return File
end

function courseplay.courses.getMaxCourseID()
	local maxID = nil
	if g_currentMission.cp_courses ~= nil then
		maxID = courseplay.utils.table.getMax(g_currentMission.cp_courses, 'id')
		if  maxID == false then
			maxID = 0
		end
	end	
	return maxID
end

function courseplay.courses.getMaxFolderID()
	local maxID = nil
	if g_currentMission.cp_folders ~= nil then
		maxID = courseplay.utils.table.getMax(g_currentMission.cp_folders, 'id')
		if  maxID == false then
			maxID = 0
		end
	end
	return maxID
end

function courseplay:link_parent(vehicle, index)	
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
			if	type == 'folder' then --parent must be a folder!
				if vehicle.cp.hud.selected_child.type == 'folder' then
					g_currentMission.cp_folders[vehicle.cp.hud.selected_child.id].parent = id
					courseplay.courses.save_folder(vehicle.cp.hud.selected_child.id)
				else
					g_currentMission.cp_courses[vehicle.cp.hud.selected_child.id].parent = id
					courseplay.courses.save_course(vehicle.cp.hud.selected_child.id)
				end
				g_currentMission.cp_sorted = courseplay.courses.sort()
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
	--courseplay:buttonsActiveEnabled(vehicle, "page2");
end

function courseplay.courses.getNextCourse(vehicle, index, rev)
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

function courseplay.courses.getMeOrBestFit(self, index)
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

function courseplay.courses.reload(vehicle)
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
			vehicle.cp.sorted = courseplay.courses.sort(courses, folders, 0, 0, false)
		end
		
		-- update folder settings here??
		
		-- update items for the hud
		courseplay.hud.reloadCourses(vehicle);
		
		vehicle.cp.reloadCourseItems = false
	end -- end vehicle ~= nil
end
