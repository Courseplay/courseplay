---class FileSystemEntity
FileSystemEntity = CpObject()

function FileSystemEntity:init(fullPath, parent, name)
	self.fullPath = fullPath
	self.parent = parent
	self.name = name or string.match(fullPath, '.*\\(.+)')
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
--- Represents a file system directory
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
	delete(self.entries[name]:getFullPath())
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


FileSystemEntityView = CpObject()
function FileSystemEntityView:init(entity, level)
	self.name = entity:getName()
	self.level = level or 0
	self.entity = entity
	self.indent = ''
	-- indent only from level 2. level 0 is never shown, as it is the root directory, level 1
	-- has no indent.
	for i = 2, self.level do
		self.indent = self.indent .. '  '
	end
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

function FileSystemEntityView:showMoveButton()
	return false
end

function FileSystemEntityView:showLoadButton()
	return false
end

function FileSystemEntityView:showAddButton()
	return false
end

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


---@class CourseManager
CourseManager = CpObject()

function CourseManager:init(courseDirFullPath)
	self.courseDirFullPath = courseDirFullPath
	self.courseDir = Directory(courseDirFullPath)
	self.courseDirView = DirectoryView(self.courseDir)
	self.currentEntry = 1
	-- normal (non-fieldwork) courses, will create entry when the course is loaded into the vehicle
	self.courses = {}
	-- fieldwork courses, will create entry when the course is loaded into the vehicle
	self.fieldworkCourses = {}
end

-- wrapper to create a global instance.
function CourseManager.create()
	return CourseManager(("%s%s/%s"):format(getUserProfileAppPath(),"modsSettings/Courseplay",
		g_currentMission.missionInfo.mapId))
end

function CourseManager:refresh()
	self.courseDir:refresh()
	self.courseDirView:refresh()
end

function CourseManager:getEntries()
	return self.courseDirView:getEntries()
end

function CourseManager:setCurrentEntry(num)
	self.currentEntry = math.max(math.min(num, #self.courseDirView:getEntries()), 1)
end

function CourseManager:getCurrentEntry()
	return self.currentEntry
end

-- Unfold (expand) a folder
function CourseManager:unfold(index)
	self:getCurrentEntry()
	local dir = self.courseDirView:getEntries()[self:getCurrentEntry() - 1 + index]
	dir:unfold()
	self:debug('%s unfolded', dir:getName())
end

-- Fold (hide contents) a folder
function CourseManager:fold(index)
	local dir = self.courseDirView:getEntries()[self:getCurrentEntry() - 1 + index]
	dir:fold()
	self:debug('%s folded', dir:getName())
end

function CourseManager:loadCourse(vehicle, index)
	self:getCurrentEntry()
	local file = self.courseDirView:getEntries()[self:getCurrentEntry() - 1 + index]
	local course = Course.createFromFile(vehicle, file)
	if course:isFieldworkCourse() then
		self.fieldworkCourses[vehicle] = course
		courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, 'loaded fieldwork course %s', file:getName())
	else
		self.courses[vehicle] = course
		courseplay.debugVehicle(courseplay.DBG_COURSES, vehicle, 'loaded course %s', file:getName())
	end
	-- TODO: get rid of this global variable
	vehicle:setCpVar('canDrive', true, courseplay.isClient);
end

function CourseManager:getCourse(vehicle)
	return self.courses[vehicle]
end

function CourseManager:getFieldworkCourse(vehicle)
	return self.fieldworkCourses[vehicle]
end

function CourseManager:hasCourse(vehicle)
	-- a vehicle has a course assigned if either a normal or a fieldwork course (or both) is assigned
	return self.courses[vehicle] or self.fieldworkCourses[vehicle]
end

function CourseManager:getCourseName(vehicle)
	local name = ''
	if self.fieldworkCourses[vehicle] then
		name = self.fieldworkCourses[vehicle]:getName()
		if self.courses[vehicle] then
			-- if there is a fieldwork course and an unload/refill course, show both
			name = name .. ' + ' .. self.courses[vehicle]:getName()
		end
	else
		name = self.courses[vehicle]:getName()
	end
	return name
end

function CourseManager:migrateOldCourses(folders, courses)
	local levels = {}
	for _, folder in pairs(folders) do
		if not levels[folder.level] then
			levels[folder.level] = {}
		end
		table.insert(levels[folder.level], folder)
	end
	local foldersById = {}
	foldersById[0] = self.courseDir
	for level = 0, #levels do
		for _, folder in ipairs(levels[level]) do
			foldersById[folder.id] = foldersById[folder.parent]:createDirectory(folder.name)
		end
	end

	for _, course in pairs(courses) do
		if not course.virtual then
			self:debug('Loading course %s...', course.name)
			courseplay.courses:loadCourseFromFile(course)
			self:debug('Migrating course %s to %s', course.name, foldersById[course.parent]:getFullPath())
			courseplay.courses:writeCourseFile(foldersById[course.parent]:getFullPath() .. '/' .. course.name, course)
		end
	end
end

function CourseManager:debug(...)
	courseplay.debugFormat(courseplay.DBG_COURSES, string.format(...))
end

function CourseManager:dump()
	for v, c in pairs(self.courses) do
		courseplay.debugVehicle(courseplay.DBG_COURSES, v, 'course: %s', c:getName())
	end
	for v, c in pairs(self.fieldworkCourses) do
		courseplay.debugVehicle(courseplay.DBG_COURSES, v, 'fieldwork course: %s', c:getName())
	end
	return 'courses dumped.'
end

-- Recreate if already exists. This is only for development to recreate the global instance if this
-- file is reloaded while the game is running
if g_courseManager then
	g_courseManager = CourseManager.create()
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
		local loadButton = buttonsByRow[row]['loadSortedCourse']
		local addButton = buttonsByRow[row]['addSortedCourse']
		local deleteButton = buttonsByRow[row]['deleteSortedItem']
		local moveButton = buttonsByRow[row]['linkParent']
		if entryId <= #entries then
			unfoldButton:setShow(entries[entryId]:showUnfoldButton())
			foldButton:setShow(entries[entryId]:showFoldButton())
			loadButton:setShow(entries[entryId]:showLoadButton())
			addButton:setShow(entries[entryId]:showAddButton())
			deleteButton:setShow(entries[entryId]:showDeleteButton())
			moveButton:setShow(entries[entryId]:showMoveButton())
		else
			foldButton:setShow(false)
			unfoldButton:setShow(false)
			loadButton:setShow(false)
			addButton:setShow(false)
			deleteButton:setShow(false)
			moveButton:setShow(false)
		end
		row = row + 1
		entryId = entryId + 1
	end
end


function courseplay:unfold(vehicle, index)
	g_courseManager:unfold(index)
	courseplay.hud:setReloadPageOrder(vehicle, courseplay.hud.PAGE_MANAGE_COURSES, true);
end

function courseplay:fold(vehicle, index)
	g_courseManager:fold(index)
	courseplay.hud:setReloadPageOrder(vehicle, courseplay.hud.PAGE_MANAGE_COURSES, true);
end

