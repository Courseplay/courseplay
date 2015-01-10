--[[
@name:    inputCourseNameDialogue
@desc:    Dialogue settings for the Courseplay course saving form
@author:  Jakob Tischler
@version: 1.5
@date:    31 Oct 2014
--]]

local modDir = g_currentModDirectory;

inputCourseNameDialogue = {}
local inputCourseNameDialogue_mt = Class(inputCourseNameDialogue)
inputCourseNameDialogue.types = { "course", "folder", "filter" };

function inputCourseNameDialogue:new()
	local instance = {};
	instance = setmetatable(instance, inputCourseNameDialogue_mt);
	return instance;
end; --END new()

local elementOverlayExists = function(element)
	return element.overlay ~= nil and element.overlay.overlay ~= nil and element.overlay.overlay ~= 0;
end;

function inputCourseNameDialogue:setImageOverlay(element, filePath, type)
	-- print(('\t\tsetImageOverlay(): element=%q, filePath=%q, type=%q'):format(tostring(element), tostring(filePath), tostring(type)));

	if type == nil then
		if elementOverlayExists(element) then
			delete(element.overlay.overlay);
		end;

		element.overlay.overlay = createImageOverlay(filePath);
		element.overlay.filePath = filePath;
	else
		type = type:sub(2);
		if element.courseplayTypes == nil then
			element.courseplayTypes = {};
		end;
		if element.courseplayTypes[type] == nil then
			element.courseplayTypes[type] = {};
		end;

		element.courseplayTypes[type].overlayId = createImageOverlay(filePath);
		element.courseplayTypes[type].filePath = filePath;
		if type == 'course' then -- set the default overlay - ONLY DO THIS ONCE (for the course)
			if elementOverlayExists(element) then
				delete(element.overlay.overlay);
			end;
			element.overlay.overlay = element.courseplayTypes[type].overlayId;
			element.overlay.filePath = element.courseplayTypes[type].filePath;
		end;

		-- print(tableShow(element, 'element "' .. filePath .. '"'));
	end;
end;
function inputCourseNameDialogue.setModImages(element, xmlFile, key)
	element.modImgDir = modDir .. (getXMLString(xmlFile, key .. "#MOD_imageDir") or "");
	local fileNames = getXMLString(xmlFile, key .. '#MOD_imageFilename');

	if fileNames ~= nil then
		local split = Utils.splitString(",", fileNames);
		if #split == 1 then
			inputCourseNameDialogue:setImageOverlay(element, element.modImgDir .. fileNames);
		elseif #split == #inputCourseNameDialogue.types then
			for _,data in pairs(split) do
				local kv = Utils.splitString(":", data);
				local type, filePath = unpack(kv);
				local realFilePath = filePath;
				if not Utils.startsWith(filePath, "$") then
					realFilePath = element.modImgDir .. filePath;
				end;

				inputCourseNameDialogue:setImageOverlay(element, realFilePath, type);
			end;
		else
			--ERROR
		end;
	end;
end; --END setModImages()
BitmapElement.loadFromXML =    Utils.appendedFunction(BitmapElement.loadFromXML,    inputCourseNameDialogue.setModImages);
-- TextInputElement.loadFromXML = Utils.appendedFunction(TextInputElement.loadFromXML, inputCourseNameDialogue.setModImages);
ButtonElement.loadFromXML =    Utils.appendedFunction(ButtonElement.loadFromXML,    inputCourseNameDialogue.setModImages);

function inputCourseNameDialogue:onCreateTitleText(element)
	self.titleTextElement = element;
end; --END onCreateTitleText()

function inputCourseNameDialogue:onCreateSaveButton(element)
	self.saveButtonElement = element;
end; --END onCreateSaveButton()

function inputCourseNameDialogue:onCreateCancelButton(element)
	self.cancelButtonElement = element;
end; --END onCreateCancelButton()

function inputCourseNameDialogue:onCreateTextInput(element)
	self.textInputElement = element;
end; --END onCreateTextInput()

function inputCourseNameDialogue:onOpen(element)
	g_currentMission.isPlayerFrozen = true;
	InputBinding.setShowMouseCursor(true);

	local saveWhat = courseplay.vehicleToSaveCourseIn.cp.saveWhat;

	--SET SAVE BUTTON IMAGE
	self.saveButtonElement.overlay.overlay = self.saveButtonElement.courseplayTypes[saveWhat].overlayId;
	self.saveButtonElement.overlay.filePath = self.saveButtonElement.courseplayTypes[saveWhat].filePath;

	--SET TITLE TEXT
	if self.titleTextElement.courseText == nil or self.titleTextElement.folderText == nil or self.titleTextElement.filterText == nil then
		local cpTitleParts = Utils.splitString(",", self.titleTextElement.text);
		local courseTitle = string.sub(cpTitleParts[1], 5);
		local folderTitle = string.sub(cpTitleParts[2], 5);
		local filterTitle = string.sub(cpTitleParts[3], 5);
		self.titleTextElement.courseText =  courseplay.locales[courseTitle] or "Course name:";
		self.titleTextElement.folderText =  courseplay.locales[folderTitle] or "Folder name:";
		self.titleTextElement.filterText =  courseplay.locales[filterTitle] or "Filter courses:";
	end;
	self.titleTextElement.text = self.titleTextElement[saveWhat .. "Text"];

	self:validateCourseName();

	--SET FOCUS
	FocusManager:setFocus(self.textInputElement);
	self.textInputElement.mouseDown = false;
	self.textInputElement.state = TextInputElement.STATE_PRESSED;
	self.textInputElement:setForcePressed(true);
end; --END onOpen()

function inputCourseNameDialogue:onClose(element)
	InputBinding.setShowMouseCursor(false);
	g_currentMission.isPlayerFrozen = false;
end; --END onClose()

function inputCourseNameDialogue:onIsUnicodeAllowed(unicode)
	return courseplay.allowedCharacters[unicode] == true;
end; --END onIsUnicodeAllowed()

function inputCourseNameDialogue:onSaveClick()
	--print("inputCourseNameDialogue:onSaveClick()");
	local vehicle = courseplay.vehicleToSaveCourseIn
	if vehicle.cp.saveWhat == 'course' then
		if self.textInputElement ~= nil then
			--print("self.textInputElement.text= "..tostring(self.textInputElement.text).."  courseplay.vehicleToSaveCourseIn.cp.currentCourseName= "..tostring(courseplay.vehicleToSaveCourseIn.cp.currentCourseName));
			CourseplayEvent.sendEvent(vehicle, "self.cp.saveWhat", vehicle.cp.saveWhat)
			vehicle:setCpVar('currentCourseName',self.textInputElement.text);
			--CourseplayEvent.sendEvent(vehicle, "self.cp.currentCourseName", self.textInputElement.text)
			vehicle.cp.doNotOnSaveClick = true
		else
			--print("self.textInputElement= "..tostring(self.textInputElement).."  courseplay.vehicleToSaveCourseIn.cp.currentCourseName= "..tostring(courseplay.vehicleToSaveCourseIn.cp.currentCourseName));
		end

		local maxID = courseplay.courses:getMaxCourseID() -- horoman: made maxID local, should not make a difference as it is used nowhere (at least Eclipse file search doesn't find it in any of the courseplay files)
		if maxID == nil then
			g_currentMission.cp_courses = {};
			maxID = 0
		end

		vehicle.cp.currentCourseId = maxID + 1;
		vehicle.cp.numCourses = 1;

		local course = { id = vehicle.cp.currentCourseId, uid = 'c'..vehicle.cp.currentCourseId, type = 'course', name = vehicle.cp.currentCourseName, nameClean = courseplay:normalizeUTF8(vehicle.cp.currentCourseName), waypoints = vehicle.Waypoints, parent = 0 }
		g_currentMission.cp_courses[vehicle.cp.currentCourseId] = course
		--courseplay:dopairs(g_currentMission.cp_courses,1) replace it by tableshow
		
		g_currentMission.cp_sorted = courseplay.courses:sort()
		if not courseplay.isClient then
			courseplay.courses:saveCourseToXml(vehicle.cp.currentCourseId, nil, true)
		end
		courseplay.settings.setReloadCourseItems()
		courseplay.signs:updateWaypointSigns(vehicle);

	elseif vehicle.cp.saveWhat == 'folder' then
		if self.textInputElement ~= nil then
			vehicle.cp.saveFolderName = self.textInputElement.text
			CourseplayEvent.sendEvent(vehicle, "self.cp.saveWhat", vehicle.cp.saveWhat)
			CourseplayEvent.sendEvent(vehicle, "self.cp.saveFolderName", self.textInputElement.text)
		end
	
		local maxID = courseplay.courses:getMaxFolderID()
		if maxID == nil then
			g_currentMission.cp_folders = {}
			maxID = 0
		end
		local folderID = maxID+1
		folder = { id = folderID, uid = 'f'..folderID, type = 'folder', name = vehicle.cp.saveFolderName, nameClean = courseplay:normalizeUTF8(vehicle.cp.saveFolderName), parent = 0 }

		g_currentMission.cp_folders[folderID] = folder
		--courseplay:dopairs(g_currentMission.cp_folders,1)replace it by tableshow
		g_currentMission.cp_sorted = courseplay.courses:sort(g_currentMission.cp_courses, g_currentMission.cp_folders, 0, 0)
		if not courseplay.isClient then
			courseplay.courses:saveFolderToXml(folderID, nil, true)
		end
		courseplay.settings.add_folder(folderID)
		courseplay.settings.setReloadCourseItems()
		courseplay.signs:updateWaypointSigns(vehicle);

	elseif vehicle.cp.saveWhat == 'filter' then
		if self.textInputElement ~= nil then
			vehicle.cp.hud.filter = self.textInputElement.text;
			CourseplayEvent.sendEvent(vehicle, "self.cp.saveWhat", vehicle.cp.saveWhat)
			CourseplayEvent.sendEvent(vehicle, "self.cp.saveFolderName", self.textInputElement.text)
		end

		vehicle.cp.hud.filterButton:setSpriteSectionUVs('cancel');
		vehicle.cp.hud.filterButton:setToolTip(courseplay:loc('COURSEPLAY_DEACTIVATE_FILTER'));
		courseplay.settings.setReloadCourseItems(vehicle);
	end

	if self.textInputElement ~= nil then
		CourseplayEvent.sendEvent(courseplay.vehicleToSaveCourseIn, "self.cp.onSaveClick",true)
		self:onCancelClick();
	else
		vehicle.cp.saveFolderName = nil
	end
end; --END onSaveClick()

function inputCourseNameDialogue:onCancelClick()
	self.textInputElement.text = "";
	self.textInputElement.visibleTextPart1 = "";
	self.textInputElement.cursorPosition = 1;
	self.textInputElement.cursorBlinkTime = 0;

	g_gui:showGui("");
	courseplay.vehicleToSaveCourseIn.cp.saveFolderName = nil
	courseplay.vehicleToSaveCourseIn = nil;
	self:onClose();
end; --END onCancelClick()

function inputCourseNameDialogue:onTextChanged()
	self:validateCourseName();
end; --END onTextChanged()

function inputCourseNameDialogue:onEnterPressed()
	if self:validateCourseName() then
		self:onSaveClick();
	end;
end; --END onEnterPressed()

function inputCourseNameDialogue:validateCourseName()
	self.saveButtonElement.disabled = self.textInputElement.text == nil or self.textInputElement.text:len() < 1;
	--print("self.saveButtonElement.disabled="..tostring(self.saveButtonElement.disabled));
	return not self.saveButtonElement.disabled;
end; --END validateCourseName()

function inputCourseNameDialogue:setTextInputFocus(element)
end;

function inputCourseNameDialogue:setCallbacks(onCourseNameEntered, target)
	self.target = target;
end; --END setCallbacks()

function inputCourseNameDialogue:update(dt)
	if InputBinding.hasEvent(InputBinding.MENU_ACCEPT) or InputBinding.hasEvent(InputBinding.COURSEPLAY_MENU_ACCEPT_SECONDARY) then
		-- InputBinding.hasEvent(InputBinding.MENU_ACCEPT);
		self:onEnterPressed();
	elseif InputBinding.hasEvent(InputBinding.MENU, true) or InputBinding.hasEvent(InputBinding.MENU_CANCEL, true) then
		-- InputBinding.hasEvent(InputBinding.MENU_CANCEL);
		-- InputBinding.hasEvent(InputBinding.MENU);
		self:onCancelClick();
	end;
end; --END update()




g_inputCourseNameDialogue = inputCourseNameDialogue:new();
g_gui:loadGui(courseplay.path .. 'inputCourseNameDialogue.xml', 'inputCourseNameDialogue', g_inputCourseNameDialogue);
