---class FileSystemEntity
FileSystemEntity = CpObject()

function FileSystemEntity:init(fullPath, name)
	self.fullPath = fullPath
	self.name = name or string.match(fullPath, '.*\\(.+)')
end

function FileSystemEntity:isDirectory()
	return false
end

function FileSystemEntity:getFullPath()
	return self.fullPath
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

function Directory:init(fullPath, name)
	FileSystemEntity.init(self, fullPath, name)
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
	print(name, isDirectory)
	if isDirectory then
		if self.entries[name] then
			self.entries[name]:refresh()
		else
			self.entries[name] = Directory(self.fullPath .. '\\' .. name)
		end
	elseif not self.entries[name] then
		self.entries[name] = File(self.fullPath .. '\\' .. name)
	end
end

function Directory:mkdir(name)
	if not self.entries[name] then
		self.entries[name] = Directory(self.fullPath .. '\\' .. name)
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

---@class CourseManager
CourseManager = CpObject()

function CourseManager:init(courseFolder)
	self.courseFolder = courseFolder
	self.files = {}
	getFiles(courseFolder, 'fileCallback', self)
end

function CourseManager:fileCallback(name, isDirectory)
	table.insert(self.files, name)
	print(name, isDirectory)
	if isDirectory then
		getFiles(courseFolder, 'fileCallback', self)
	end
end

