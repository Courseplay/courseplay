--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[

The Course Manager is responsible for:
	- managing all saved courses, in particular:
		* maintaining a directory/file structure on the disk
		* saving courses to XML files
		* loading courses from files when the user selects them in the HUD
		* creating directories on the disk when the user creates a folder in the HUD
	- keeping track of courses assigned to a vehicle:
		* courses are assigned to a vehicle when the users selects them in the HUD
		* the Course Manager provides the assigned courses to the AIDriver on start
		* assignments are saved with the savegame and loaded on game start
	- synchronizing course assignments in multiplayer
		* courses are saved/loaded on the client only
		* the Course Manager on the server only holds the assignments and provides the courses to the AIDriver
		* whenever an assignment changes, all assigned courses of the vehicle are sent to
		  the server (as a CourseEvent), which then also broadcasts them to the other clients

]]--

--- An entity (file or directory) in the file system
---class FileSystemEntity
FileSystemEntity = CpObject()

---@param fullPath : string
---@param parent : FileSystemEntity
---@param name : string
function FileSystemEntity:init(fullPath, parent, name)
	self.fullPath = fullPath
	self.parent = parent
	self.name = name or string.match(fullPath, '.*[\\/](.+)')
end

function FileSystemEntity:isDirectory()
	return false
end

function FileSystemEntity:getName()
	return self.name
end

function FileSystemEntity:getFullPath()
	return self.fullPath
end

function FileSystemEntity:getParent()
	return self.parent
end

function FileSystemEntity.__eq(a, b)
	return a.fullPath == b.fullPath
end

function FileSystemEntity:__tostring()
	return 'Name: ' .. self.name .. ', Path: ' .. self.fullPath
end

---@class File : FileSystemEntity
File = CpObject(FileSystemEntity)

function File:__tostring()
	return 'File: ' .. FileSystemEntity.__tostring(self) .. '\n'
end

--- A directory on the file system. This can recursively be traversed to all subdirectories.
---@class Directory : FileSystemEntity
Directory = CpObject(FileSystemEntity)

function Directory:init(fullPath, parent, name)
	FileSystemEntity.init(self, fullPath, parent, name)
	self.entries = {}
	createFolder(self.fullPath)
	self:refresh()
end

function Directory:isDirectory()
	return true
end

--- Refresh from disk
function Directory:refresh()
	self.entriesToRemove = {}
	for key, _ in pairs(self.entries) do
		self.entriesToRemove[key] = true
	end
	getFiles(self.fullPath, 'fileCallback', self)
	for key, _ in pairs(self.entriesToRemove) do
		self.entries[key] = nil
	end
end

function Directory:fileCallback(name, isDirectory)
	if isDirectory then
		if self.entries[name] then
			self.entries[name]:refresh()
		else
			self.entries[name] = Directory(self.fullPath .. '\\' .. name, self)
		end
	elseif not self.entries[name] then
		self.entries[name] = File(self.fullPath .. '\\' .. name, self)
	end
	if self.entriesToRemove[name] then
		self.entriesToRemove[name] = nil
	end
end

function Directory:deleteFile(name)
	getfenv(0).deleteFile(self.entries[name]:getFullPath())
	self.entries[name] = nil
end

function Directory:createDirectory(name)
	if not self.entries[name] then
		self.entries[name] = Directory(self.fullPath .. '\\' .. name, self)
	end
	return self.entries[name]
end

function Directory:__tostring()
	local str = 'Directory: ' .. FileSystemEntity.__tostring(self) .. '\n'
	for _, entry in pairs(self.entries) do
		str = str .. tostring(entry)
	end
	return str
end

--- A view representing a file system entity (file or directory). The view knows how to display an entity on the UI.
---@class FileSystemEntityView
FileSystemEntityView = CpObject()
FileSystemEntityView.indentString = '  '

function FileSystemEntityView:init(entity, level)
	self.name = entity:getName()
	self.level = level or 0
	self.entity = entity
	self.indent = ''
	-- indent only from level 2. level 0 is never shown, as it is the root directory, level 1
	-- has no indent.
	for i = 2, self.level do
		self.indent = self.indent .. FileSystemEntityView.indentString
	end
end

function FileSystemEntityView:getEntity()
	return self.entity
end

function FileSystemEntityView:getName()
	return self.name
end

function FileSystemEntityView:getFullPath()
	return self.entity:getFullPath()
end

function FileSystemEntityView:getLevel()
	return self.level
end

function FileSystemEntityView:__tostring()
	return self.indent .. self.name .. '\n'
end

function FileSystemEntityView.__lt(a, b)
	return a.name < b.name
end

function FileSystemEntityView:isDirectory()
	return self.entity:isDirectory()
end

-- by default, no fold or unfold shown
function FileSystemEntityView:showUnfoldButton()
	return false
end
function FileSystemEntityView:showFoldButton()
	return false
end

-- for now, disable delete and move
function FileSystemEntityView:showDeleteButton()
	return false
end

function FileSystemEntityView:showSaveButton()
	return false
end

function FileSystemEntityView:showLoadButton()
	return false
end

function FileSystemEntityView:showAddButton()
	return false
end

--- View of a regular file (XML with a saved course
---@class FileView : FileSystemEntityView
FileView = CpObject(FileSystemEntityView)
function FileView:init(file, level)
	FileSystemEntityView.init(self, file, level)
end

function FileView:showLoadButton()
	return true
end

function FileView:showAddButton()
	return true
end

--- View of a directory of saved courses
---@class DirectoryView
DirectoryView = CpObject(FileSystemEntityView)

---@param directory Directory
function DirectoryView:init(directory, level, folded)
	FileSystemEntityView.init(self, directory, level)
	self.directory = directory
	self.folded = folded or false
	self:refresh()
end

function DirectoryView:refresh()
	self.directoryViews = {}
	self.fileViews = {}
	for _, entry in pairs(self.directory.entries) do
		if entry:isDirectory() then
			table.insert(self.directoryViews, DirectoryView(entry, self.level + 1, true))
		else
			table.insert(self.fileViews, FileView(entry, self.level + 1))
		end
	end
	table.sort(self.directoryViews)
	table.sort(self.fileViews)
end

function DirectoryView:fold()
	self.folded = true
end

function DirectoryView:unfold()
	self.folded = false
end

function DirectoryView:isFolded()
	return self.folded
end

function DirectoryView:__tostring()
	local str = ''
	if self.level > 0 then
		str = str .. self.indent .. self.name .. '\n'
	end
	if not self.folded then
		for _, dv in ipairs(self.directoryViews) do
			str = str .. tostring(dv)
		end
		for _, fv in ipairs(self.fileViews) do
			str = str .. tostring(fv)
		end
	end
	return str
end

function DirectoryView:collectEntries(t)
	if self.level > 0 then
		table.insert(t, self)
	end
	if not self.folded then
		for _, dv in ipairs(self.directoryViews) do
			dv:collectEntries(t)
		end
		for _, fv in ipairs(self.fileViews) do
			table.insert(t, fv)
		end
	end
end

--- Entries according to the current folded/unfolded state of the directories.
function DirectoryView:getEntries()
	self.entries = {}
	self:collectEntries(self.entries)
	return self.entries
end

function DirectoryView:showUnfoldButton()
	return self:isFolded()
end

function DirectoryView:showFoldButton()
	return not self:isFolded()
end

function DirectoryView:showSaveButton()
	return true
end

--- Represents an assignment: the courses assigned (loaded) to a vehicle
---@class CourseAssignment
CourseAssignment = CpObject()
function CourseAssignment:init(vehicle, course)
	self.vehicle = vehicle
	---@type Course[]
	self.courses = {}
	self:add(course)
end

function CourseAssignment:add(course)
	table.insert(self.courses, course)
end


--- The CourseManager is responsible for loading/saving all courses and maintaining the vehicle - course
--- assignments.
--- Course folders shown in the HUD correspond actual file system folders.
--- Courses shown in the HUD correspond actual files on the file system.
---@class CourseManager
CourseManager = CpObject()

function CourseManager:init()
	-- courses are stored in a folder per map, under modsSettings/Courseplay/Courses/<map name>/
	local baseDir = getUserProfileAppPath() .. "/modsSettings/Courseplay"
	-- create subfolders one by one, seems like createFolder() can't recursively create subfolders
	createFolder(baseDir)
	baseDir = baseDir .. "/Courses/"
	createFolder(baseDir)
	self.courseDirFullPath = baseDir .. g_currentMission.missionInfo.mapId
	self.courseDir = Directory(self.courseDirFullPath)
	self.courseDirView = DirectoryView(self.courseDir)
	self.currentEntry = 1
	-- one entry per vehicle, each entry can hold a list of courses:
	-- an entry is created once at least one course is loaded to the vehicle on the HUD
	---@type CourseAssignment[]
	self.assignments = {}
	-- representation of all waypoints loaded for a vehicle as needed by the legacy functions
	self.legacyWaypoints = {}
	self.savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.selectedIndex)
	-- file where we save the courses assigned to each vehicle
	self.savedAssignmentsXmlFilePath = self.savegameFolderPath .. '/courseplayCourseAssignments.xml'
	-- this is the list of courses loaded from a savegame and waiting for the vehicle to grab them (to which they were
	-- assigned when the game was saved) after the game is loaded
	self.savedAssignments = {}
end

--- Refresh everything from disk
function CourseManager:refresh()
	self.courseDir:refresh()
	self.courseDirView:refresh()
	self:setCurrentEntry(self:getCurrentEntry())
end

function CourseManager:getEntries()
	return self.courseDirView:getEntries()
end

--- The current entry is the one on the top of the HUD. Scrolling the HUD changes the current entry.
function CourseManager:setCurrentEntry(num)
	self.currentEntry = math.max(math.min(num, #self.courseDirView:getEntries()), 1)
end

function CourseManager:getCurrentEntry()
	return self.currentEntry
end

--- Return directory view displayed at index on the HUD
function CourseManager:getDirViewAtIndex(index)
	return self.courseDirView:getEntries()[self:getCurrentEntry() - 1 + index]
end

-- Unfold (expand) a folder
function CourseManager:unfold(index)
	local dir = self:getDirViewAtIndex(index)
	dir:unfold()
	self:debug('%s unfolded', dir:getName())
end

-- Fold (hide contents) a folder
function CourseManager:fold(index)
	local dir = self:getDirViewAtIndex(index)
	dir:fold()
	self:debug('%s folded', dir:getName())
end

function CourseManager:createDirectory(index, name)
	-- if index is given, it points to a directory in the HUD, so create the new directory under that,
	-- otherwise under the root
	local dir = index and self:getDirViewAtIndex(index):getEntity() or self.courseDir
	dir:createDirectory(name)
	self:refresh()
end

--- Take all the courses currently assigned to the vehicle and concatenate them into a single course
--- and then save this course to the directory at index in the HUD
function CourseManager:saveCourseFromVehicle(index, vehicle, name)
	local dir = index and self:getDirViewAtIndex(index):getEntity() or self.courseDir
	courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, 'saving course %s in folder %s', name, dir:getName())
	local courses = self:getAssignedCourses(vehicle)
	local course = courses[1]:copy()
	for i = 2, #courses do
		course:append(courses[i])
	end
	self:saveCourse(dir:getFullPath() .. '/' .. name, course)
	self:refresh()
end

function CourseManager:saveCourse(fullPath, course)
	local courseXml = createXMLFile("courseXml", fullPath, 'course');
	course:saveToXml(courseXml, 'course')
	saveXMLFile(courseXml);
	delete(courseXml);
	self:debug('Course %s saved.', course:getName())
end

function CourseManager:getAssignment(vehicle)
	for i, assignment in ipairs(self.assignments) do
		if assignment.vehicle == vehicle then
			return i, assignment
		end
	end
	return nil, nil
end

function CourseManager:getAssignedCourses(vehicle)
	local _, assignment = self:getAssignment(vehicle)
	return assignment and assignment.courses or {}
end

---@param vehicle : table
---@param course : Course
function CourseManager:assign(vehicle, course)
	local _, assignment = self:getAssignment(vehicle)
	if assignment then
		assignment:add(course)
	else
		table.insert(self.assignments, CourseAssignment(vehicle, course))
	end
end

--- Load the course shown in the HUD at index
function CourseManager:loadCourseSelectedInHud(vehicle, index)
	self:getCurrentEntry()
	local file = self.courseDirView:getEntries()[self:getCurrentEntry() - 1 + index]

	local courseXml = loadXMLFile("courseXml", file:getFullPath())
	local courseKey = "course";
	local course = Course.createFromXml(vehicle, courseXml, courseKey)
	course:setName(file:getName())
	delete(courseXml);
	self:assignCourseToVehicle(vehicle, course)
	CourseEvent.sendEvent(vehicle, self:getAssignedCourses(vehicle))
end

function CourseManager:assignCourseToVehicle(vehicle, course)
	course:setVehicle(vehicle)
	self:assign(vehicle, course)
	courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, 'course %s assigned', course:getName())
	self:updateLegacyCourseData(vehicle)
end

--- Unload all courses for this vehicle
function CourseManager:unloadAllCoursesFromVehicle(vehicle)
	local ix, assignment = self:getAssignment(vehicle)
	if ix then
		self.legacyWaypoints[assignment.vehicle] = {}
		table.remove(self.assignments, ix)
		courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, 'unloaded all courses')
	end
	self:updateLegacyCourseData(vehicle)
end

function CourseManager:loadGeneratedCourse(vehicle, course)
	-- for now, when loading a generated course, remove all other courses from the vehicle
	self:unloadAllCoursesFromVehicle(vehicle)
	self:assignCourseToVehicle(vehicle, course)
	CourseEvent.sendEvent(vehicle, self:getAssignedCourses(vehicle))
end

--- This is just the index of the vehicle's assigned course in the self.assignments array. Vehicles
--- write this in the savegame so on game load they can pick and load their assigned courses.
function CourseManager:getCourseAssignmentId(vehicle)
	local ix, _ = self:getAssignment(vehicle)
	return ix
end

--- When loading a savegame, assign a course to the vehicle again.
--- This is the course which was loaded to a vehicle at the time the game was saved.
function CourseManager:loadAssignedCourse(vehicle, assignmentId)
	if #self.savedAssignments == 0 then
		-- have not loaded them yet
		self:loadAssignments()
	end
	if self.savedAssignments[assignmentId] then
		self.savedAssignments[assignmentId].vehicle = vehicle
		for _, course in ipairs(self.savedAssignments[assignmentId].courses) do
			courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, 'loading assigned course %s from savegame', course:getName())
			g_courseManager:assignCourseToVehicle(vehicle, course)
		end
	end
	self:updateLegacyCourseData(vehicle)
end

--- Save the courses currently assigned to each vehicle. These are all saved in a single file under the
--- savegame folder (all currently loaded course for each vehicle)
function CourseManager:saveAssignedCourses()
	createFolder(self.savegameFolderPath)
	local savedAssignmentsXml = createXMLFile("savedAssignmentsXml", self.savedAssignmentsXmlFilePath, 'savedAssignments')
	-- this token will be saved with the vehicle in the savegame and can be used to find the courses
	-- for that vehicle when loading
	for assignmentId, assignment in ipairs(self.assignments) do
		-- XML index is 0 based, hence -1
		local key = string.format('savedAssignments.assignment(%d)', assignmentId - 1)
		setXMLInt(savedAssignmentsXml, key .. '#id', assignmentId)
		setXMLString(savedAssignmentsXml, key .. '#vehicle', nameNum(assignment.vehicle))
		for i, course in ipairs(assignment.courses) do
			local courseKey = string.format('%s.course(%d)', key, i - 1)
			courseplay.debugVehicle(courseplay.DBG_COURSES, assignment.vehicle, 'saving assigned course %s', course:getName())
			course:saveToXml(savedAssignmentsXml, courseKey)
		end
		assignmentId = assignmentId + 1
	end
	saveXMLFile(savedAssignmentsXml);
	delete(savedAssignmentsXml);
end

--- Reload the courses that were assigned to each vehicle at the time of the last savegame
function CourseManager:loadAssignments()
	createFolder(self.savegameFolderPath);
	local savedAssignmentsXml;
	if fileExists(self.savedAssignmentsXmlFilePath) then
		self.savedAssignments = {}
		savedAssignmentsXml = loadXMLFile('savedAssignmentsXml', self.savedAssignmentsXmlFilePath);
		local assignmentId = 0
		while true do
			local key = string.format('savedAssignments.assignment(%d)', assignmentId)
			if not hasXMLProperty(savedAssignmentsXml, key) then
				-- no more assignments left
				break
			end
			local dummyVehicle = {}
			local vehicleName = getXMLString(savedAssignmentsXml, key .. '#vehicle')
			self:debug('loading assigned courses for vehicle %s', vehicleName)
			local assignment = CourseAssignment(dummyVehicle, nil, nil)
			local courseNum = 0
			while true do
				local courseKey = string.format('%s.course(%d)', key, courseNum)
				if not hasXMLProperty(savedAssignmentsXml, courseKey) then
					-- no more courses left
					break
				end
				local course = Course.createFromXml(dummyVehicle, savedAssignmentsXml, courseKey)
				self:debug('loaded assigned course %s for %s', course:getName(), vehicleName)
				assignment:add(course)
				courseNum = courseNum + 1
			end
			if #assignment.courses > 0 then
				table.insert(self.savedAssignments, assignment)
			end
			assignmentId = assignmentId + 1
		end
	else
		self:debug('No assigned courses in savegame.')
	end
end

--- For backwards compatibility, create all waypoints of all loaded courses for this vehicle, as it
--- used to be stored in the terrible global Waypoints variable
function CourseManager:updateLegacyWaypoints(vehicle)
	local _, assignment = self:getAssignment(vehicle)
	if not assignment then return end
	self.legacyWaypoints[assignment.vehicle] = {}
	local n = 1
	for _, course in ipairs(assignment.courses) do
		for i = 1, course:getNumberOfWaypoints() do
			table.insert(self.legacyWaypoints[vehicle], Waypoint(course:getWaypoint(i), n))
			n = n +1
		end
	end
end

function CourseManager:getLegacyWaypoints(vehicle)
	return self.legacyWaypoints[vehicle]
end

--- Update all the legacy (as usual global) data structures related to a vehicle's loaded course
-- TODO: once someone has the time and motivation, refactor those legacy structures
function CourseManager:updateLegacyCourseData(vehicle)
	-- force reload of the 2D plot
	vehicle.cp.course2dDrawData = nil;
	vehicle.cp.course2dUpdateDrawData = true;
	self:updateLegacyWaypoints(vehicle);
	if g_client then
		courseplay.signs:updateWaypointSigns(vehicle);
	end
	-- TODO: get rid of this global variable
	vehicle:setCpVar('canDrive', self:hasCourse(vehicle), courseplay.isClient);
end

--- Get all courses assigned to the vehicle. These will be concatenated into a single course
--- in the order they were added to the vehicle in the HUD
function CourseManager:getCourse(vehicle, excludeFieldworkCourses)
	local _, assignment = self:getAssignment(vehicle)
	local course = assignment.courses[1]:copy(vehicle)
	for i = 2, #assignment.courses do
		if not excludeFieldworkCourses or (excludeFieldworkCourses and not course:isFieldworkCourse()) then
			course:append(assignment.courses[i])
		end
	end
	return course
end

function CourseManager:getFieldworkCourse(vehicle)
	local _, assignment = self:getAssignment(vehicle)
	for _, course in ipairs(assignment.courses) do
		if course:isFieldworkCourse() then
			return course
		end
	end
end

function CourseManager:hasCourse(vehicle)
	-- a vehicle has a course assigned if either a normal or a fieldwork course (or both) is assigned
	local ix, _ = self:getAssignment(vehicle)
	return ix ~= nil
end

function CourseManager:getCourseName(vehicle)
	local name = ''
	local _, assignment = self:getAssignment(vehicle)
	name = assignment.courses[1]:getName()
	if #assignment.courses > 1 then
		-- more than one course loaded
		name = string.format('%s + %d', name, #assignment.courses - 1)
	end
	return name
end

function CourseManager:migrateOldCourses(folders, courses)
	local foldersById = {}
	foldersById[0] = self.courseDir

	local levels = {}
	local nLevels = 0
	for _, folder in pairs(folders) do
		if not levels[folder.level] then
			levels[folder.level] = {}
		end
		self:debug('Reading folder %s (level %d)', folder.name, folder.level)
		table.insert(levels[folder.level], folder)
		nLevels = nLevels + 1  -- ipairs won't work on levels as it is 0 indexed
	end
	if nLevels > 0 then
		for level = 0, #levels do
			for _, folder in ipairs(levels[level]) do
				foldersById[folder.id] = foldersById[folder.parent]:createDirectory(folder.name)
			end
		end
	end

	for _, course in pairs(courses) do
		if not course.virtual then
			self:debug('Loading course %s...', course.name)
			local courseXml = loadXMLFile("courseXml", course.xmlFilePath)
			local courseKey = "course";
			local dummyVehicle = {}
			local newCourse = Course.createFromXml(dummyVehicle, courseXml, courseKey)
			newCourse:setName(course.name)
			self:debug('Migrating course %s to %s', course.name, foldersById[course.parent]:getFullPath())
			self:saveCourse(foldersById[course.parent]:getFullPath() .. '/' .. course.name, newCourse)
		end
	end
	self:refresh()
end

function CourseManager:debug(...)
	courseplay.debugFormat(courseplay.DBG_COURSES, string.format(...))
end

function CourseManager:dump()
	for _, assignment in ipairs(self.assignments) do
		for _, course in ipairs(assignment.courses) do
			courseplay.debugVehicle(courseplay.DBG_COURSES, assignment.vehicle, 'course: %s', course:getName())
		end
	end
	return 'courses dumped.'
end

-- Recreate if already exists. This is only for development to recreate the global instance if this
-- file is reloaded while the game is running
if g_courseManager then
	local old_courseManager = g_courseManager
	g_courseManager = CourseManager()
	-- preserve the existing vehicle/course assignments
	g_courseManager.assignments = old_courseManager.assignments
	g_courseManager.legacyWaypoints = old_courseManager.legacyWaypoints
end

-- Relocated to this file so it can be reloaded while the game is running (hud.lua is not reloadable)
function courseplay.hud:updateCourseList(vehicle, page)
	local hudPage = vehicle.cp.hud.content.pages[page]
	local entries = g_courseManager and g_courseManager:getEntries() or {}
	local entryId = g_courseManager and g_courseManager:getCurrentEntry() or 1
	local row = 1
	while row <= self.numLines and entryId <= #entries do
		hudPage[row][1].text = entries[entryId]:getName();
		hudPage[row][1].indention = entries[entryId]:getLevel() * self.indent;
		row = row + 1
		entryId = entryId + 1
	end
	for l = row, self.numLines do
		hudPage[l][1].text = nil;
	end
end

function courseplay.hud:updateCourseButtonsVisibility(vehicle)
	local buttonsByRow = {}
	for _, button in pairs(vehicle.cp.buttons[courseplay.hud.COURSE_MANAGEMENT_BUTTONS]) do
		if button.row and button.functionToCall then
			if buttonsByRow[button.row] == nil then
				buttonsByRow[button.row] = {}
			end
			buttonsByRow[button.row][button.functionToCall] = button
		end
	end
	local entries = g_courseManager and g_courseManager:getEntries() or {}
	local entryId = g_courseManager and g_courseManager:getCurrentEntry() or 1
	local row = 1
	while row <= self.numLines do
		local unfoldButton = buttonsByRow[row]['unfold']
		local foldButton = buttonsByRow[row]['fold']
		local loadButton = buttonsByRow[row]['loadCourse']
		local addButton = buttonsByRow[row]['addSortedCourse']
		local deleteButton = buttonsByRow[row]['deleteSortedItem']
		local saveButton = buttonsByRow[row]['saveCourseToFolder']
		if entryId <= #entries then
			unfoldButton:setShow(entries[entryId]:showUnfoldButton())
			foldButton:setShow(entries[entryId]:showFoldButton())
			loadButton:setShow(entries[entryId]:showLoadButton())
			addButton:setShow(entries[entryId]:showAddButton())
			deleteButton:setShow(entries[entryId]:showDeleteButton())
			saveButton:setShow(entries[entryId]:showSaveButton())
		else
			foldButton:setShow(false)
			unfoldButton:setShow(false)
			loadButton:setShow(false)
			addButton:setShow(false)
			deleteButton:setShow(false)
			saveButton:setShow(false)
		end
		row = row + 1
		entryId = entryId + 1
	end
end

--- All course management related HUD callbacks
function courseplay:unfold(vehicle, index)
	g_courseManager:unfold(index)
	courseplay.hud:setReloadPageOrder(vehicle, courseplay.hud.PAGE_MANAGE_COURSES, true);
end

function courseplay:fold(vehicle, index)
	g_courseManager:fold(index)
	courseplay.hud:setReloadPageOrder(vehicle, courseplay.hud.PAGE_MANAGE_COURSES, true);
end

function courseplay:clearCurrentLoadedCourse(vehicle)
	g_courseManager:unloadAllCoursesFromVehicle(vehicle)
	-- empty course list means we removed all courses
	CourseEvent.sendEvent(vehicle, {})
end

function courseplay:loadCourse(vehicle, index)
	if type(vehicle.cp.hud.courses[index]) ~= nil then
		g_courseManager:loadCourseSelectedInHud(vehicle, index)
	end
end

function courseplay:saveCourseToFolder(vehicle, index)
	courseplay:lockContext(false)
	g_inputCourseNameDialogue:setCourseMode(vehicle, index)
	g_gui:showGui("inputCourseNameDialogue")
end

function courseplay:createFolder(vehicle)
	courseplay:lockContext(false)
	g_inputCourseNameDialogue:setFolderMode(vehicle)
	g_gui:showGui("inputCourseNameDialogue")
end

function courseplay:createSubFolder(vehicle, index)
	courseplay:lockContext(false)
	g_inputCourseNameDialogue:setFolderMode(vehicle, index)
	g_gui:showGui("inputCourseNameDialogue")
end

function courseplay:reloadCoursesFromDisk(vehicle)
	g_courseManager:refresh()
end