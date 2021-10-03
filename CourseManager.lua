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
	getFiles(self.fullPath, 'fileCallback', self)
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

FileView = CpObject(FileSystemEntityView)
function FileView:init(file, level)
	FileSystemEntityView.init(self, file, level)
end

---@class DirectoryView
DirectoryView = CpObject(FileSystemEntityView)

---@param directory Directory
function DirectoryView:init(directory, level, folded)
	FileSystemEntityView.init(self, directory, level)
	self.directory = directory
	self.folded = folded or false
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


---@class CourseManager
CourseManager = CpObject()

function CourseManager:init(courseDirFullPath)
	self.courseDirFullPath = courseDirFullPath
	self.courseDir = Directory(courseDirFullPath)
	self.courseDirView = DirectoryView(self.courseDir)
	self.currentEntry = 1
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

function courseplay.hud:updateCourseList(vehicle, page)
	local hudPage = vehicle.cp.hud.content.pages[page]
	local entries = g_courseManager and g_courseManager:getEntries() or {}
	local entryId = g_courseManager and g_courseManager:getCurrentEntry() or 1
	local line = 1
	while line <= self.numLines and entryId <= #entries do
		hudPage[line][1].text = entries[entryId]:getName();
		if entries[line]:isDirectory() then
			hudPage[line][1].indention = (entries[line]:getLevel() + 1) * self.indent;
		else
			hudPage[line][1].indention = entries[line]:getLevel() * self.indent;
		end
		line = line + 1
		entryId = entryId + 1
	end
	for l = line, self.numLines do
		hudPage[l][1].text = nil;
	end
end
