--[[
@name:    inputCourseNameDialogue
@desc:    Dialogue settings for the Courseplay course saving form
@author:  Jakob Tischler
@version: 1.2
@date:    15 Jun 2013
--]]

local modDir = g_currentModDirectory;

inputCourseNameDialogue = {}
local inputCourseNameDialogue_mt = Class(inputCourseNameDialogue)

function inputCourseNameDialogue:new()
	local instance = {};
	instance = setmetatable(instance, inputCourseNameDialogue_mt);
	return instance;
end; --END new()

function inputCourseNameDialogue.setModImages(element, xmlFile, key)
	local name = Utils.getNoNil(getXMLString(xmlFile, key .. "#name", "[no name]"));
	--print("inputCourseNameDialogue.setModImages() for element " .. tostring(key) .. " (\"" .. name .. "\")");
	--print(string.format("inputCourseNameDialogue.setModImages() for element %s (\"%s\")", tostring(key), name));

	local MOD_imageFilename =         getXMLString(xmlFile, key .. "#MOD_imageFilename");
	local MOD_imageFocusedFilename =  getXMLString(xmlFile, key .. "#MOD_imageFocusedFilename");
	local MOD_imagePressedFilename =  getXMLString(xmlFile, key .. "#MOD_imagePressedFilename");
	local MOD_imageDisabledFilename = getXMLString(xmlFile, key .. "#MOD_imageDisabledFilename");

	if MOD_imageFilename ~= nil then
		element:setImageFilename(modDir .. MOD_imageFilename, element);
	end;
	if MOD_imageFocusedFilename ~= nil then
		element:setImageFocusedFilename(modDir .. MOD_imageFocusedFilename, element);
	end;
	if MOD_imagePressedFilename ~= nil then
		element:setImagePressedFilename(modDir .. MOD_imagePressedFilename, element);
	end;
	if MOD_imageDisabledFilename ~= nil then
		element:setImageDisabledFilename(modDir .. MOD_imageDisabledFilename, element);
	end;

	--[[
	print("\\___new imageFilename = " .. tostring(element.imageFilename));
	print("\\___new imageFocusedFilename = " .. tostring(element.imageFocusedFilename));
	print("\\___new imagePressedFilename = " .. tostring(element.imagePressedFilename));
	print("\\___new imageDisabledFilename = " .. tostring(element.imageDisabledFilename));
	--]]
end; --END setModImages()
BitmapElement.loadFromXML =    Utils.appendedFunction(BitmapElement.loadFromXML,    inputCourseNameDialogue.setModImages);
TextInputElement.loadFromXML = Utils.appendedFunction(TextInputElement.loadFromXML, inputCourseNameDialogue.setModImages);
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

	--src: ASCII Table - Decimal (Base 10) Values @ http://www.parse-o-matic.com/parse/pskb/ASCII-Chart.htm
	local allowedCharacterSpans = {
		{ 32,  32 },
		{ 40,  41 },
		{ 43,  43 },
		{ 45,  57 },
		{ 65,  90 },
		{ 97, 122 }
	};
	self.textInputElement.allowedCharacters = {};

	for _,span in pairs(allowedCharacterSpans) do
		for i=span[1],span[2] do
			self.textInputElement.allowedCharacters[i] = true;
		end;
	end;
end; --END onCreateTextInput()

function inputCourseNameDialogue:onOpen(element)
	g_currentMission.isPlayerFrozen = true;
	InputBinding.setShowMouseCursor(true);

	if self.titleTextElement.courseText == nil or self.titleTextElement.folderText == nil or self.titleTextElement.filterText == nil then
		local cpTitleParts = Utils.splitString(",", self.titleTextElement.text);
		local courseTitle = string.sub(cpTitleParts[1], 5);
		local folderTitle = string.sub(cpTitleParts[2], 5);
		local filterTitle = string.sub(cpTitleParts[3], 5);
		self.titleTextElement.courseText =  courseplay.locales[courseTitle] or "Course name:";
		self.titleTextElement.folderText =  courseplay.locales[folderTitle] or "Folder name:";
		self.titleTextElement.filterText =  courseplay.locales[filterTitle] or "Filter courses:";
	end;

	self.titleTextElement.text = self.titleTextElement[courseplay.vehicleToSaveCourseIn.cp.saveWhat .. "Text"];

	self:validateCourseName();

	--TODO: automatically setting focus doesn't work
	FocusManager:setFocus(self.textInputElement);
	self.textInputElement.mouseDown = false;
	self.textInputElement.state = TextInputElement.STATE_PRESSED;
	self.textInputElement:setForcePressed(true);
	--InputBinding.hasEvent(InputBinding.MENU_ACCEPT, true); --set focus

	--print(inputCourseNameDialogue:tableShow(element, "element"));
end; --END onOpen()

function inputCourseNameDialogue:onClose(element)
	InputBinding.setShowMouseCursor(false);
	g_currentMission.isPlayerFrozen = false;
end; --END onClose()

function inputCourseNameDialogue:onIsUnicodeAllowed(unicode)
	return self.textInputElement.allowedCharacters[unicode] == true;
end; --END onIsUnicodeAllowed()

function inputCourseNameDialogue:onSaveClick()
	--print("inputCourseNameDialogue:onSaveClick()");
	local vehicle = courseplay.vehicleToSaveCourseIn

	if vehicle.cp.saveWhat == 'course' then
		if self.textInputElement ~= nil then
			--print("self.textInputElement.text= "..tostring(self.textInputElement.text).."  courseplay.vehicleToSaveCourseIn.current_course_name= "..tostring(courseplay.vehicleToSaveCourseIn.current_course_name));
			vehicle.current_course_name = self.textInputElement.text;
			CourseplayEvent.sendEvent(vehicle, "self.current_course_name", self.textInputElement.text)
			vehicle.cp.doNotOnSaveClick = true
		else
			--print("self.textInputElement.text= "..tostring(self.textInputElement).."  courseplay.vehicleToSaveCourseIn.current_course_name= "..tostring(courseplay.vehicleToSaveCourseIn.current_course_name));
		end

		local maxID = courseplay.courses.getMaxCourseID() -- horoman: made maxID local, should not make a difference as it is used nowhere (at least Eclipse file search doesn't find it in any of the courseplay files)
		if maxID == nil then
			g_currentMission.cp_courses = {};
			maxID = 0
		end

		vehicle.courseID = maxID + 1;
		vehicle.numCourses = 1;

		local course = { id = vehicle.courseID, uid = 'c'..vehicle.courseID, type = 'course', name = vehicle.current_course_name,  waypoints = vehicle.Waypoints, parent = 0}
		g_currentMission.cp_courses[vehicle.courseID] = course
		g_currentMission.cp_sorted = courseplay.courses.sort()

		courseplay.courses.save_course(vehicle.courseID)
		courseplay.settings.setReloadCourseItems()
		courseplay:updateWaypointSigns(vehicle);
		
	elseif vehicle.cp.saveWhat == 'folder' then
		local maxID = courseplay.courses.getMaxFolderID()
		if maxID == nil then
			g_currentMission.cp_folders = {}
			maxID = 0
		end
		local folderID = maxID+1
		folder = { id = folderID, uid = 'f'..folderID, type = 'folder', name = self.textInputElement.text, parent = 0 }

		g_currentMission.cp_folders[folderID] = folder
		g_currentMission.cp_sorted = courseplay.courses.sort(g_currentMission.cp_courses, g_currentMission.cp_folders, 0, 0)

		courseplay.courses.save_folder(folderID)
		courseplay.settings.add_folder(folderID)
		courseplay.settings.setReloadCourseItems()
		courseplay:updateWaypointSigns(vehicle);
		
	elseif vehicle.cp.saveWhat == 'filter' then
		vehicle.cp.hud.filter = self.textInputElement.text;
		local button = vehicle.cp.buttons["2"][vehicle.cp.hud.filterButtonIndex];
		courseplay.button.setOverlay(button, 2);
		courseplay.settings.setReloadCourseItems(vehicle);
	end

	if self.textInputElement ~= nil then
		CourseplayEvent.sendEvent(courseplay.vehicleToSaveCourseIn, "self.cp.onSaveClick",true)
		self:onCancelClick();
	end
end; --END onSaveClick()

function inputCourseNameDialogue:onCancelClick()
	self.textInputElement.text = "";
	self.textInputElement.visibleTextPart1 = "";
	self.textInputElement.cursorPosition = 1;
	self.textInputElement.cursorBlinkTime = 0;

	g_gui:showGui("");
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
	if InputBinding.hasEvent(InputBinding.MENU_ACCEPT, true) then
		InputBinding.hasEvent(InputBinding.MENU_ACCEPT, true);
		self:onEnterPressed();
	elseif InputBinding.hasEvent(InputBinding.MENU, true) or InputBinding.hasEvent(InputBinding.MENU_CANCEL, true) then
		InputBinding.hasEvent(InputBinding.MENU_CANCEL, true);
		InputBinding.hasEvent(InputBinding.MENU, true);
		self:onCancelClick();
	end;
end; --END update()

function TextInputElement:setImageFilename(filename, element)
	if element.overlays[TextInputElement.STATE_NORMAL] ~= nil then
		delete(element.overlays[TextInputElement.STATE_NORMAL]);
	end;
	element.imageFilename = filename;
	if element.imageFilename ~= nil then
		local overlay = createImageOverlay(element.imageFilename)
		element.overlays[TextInputElement.STATE_NORMAL] = overlay;
	end;
end;
function TextInputElement:setImageFocusedFilename(filename, element)
	if element.overlays[TextInputElement.STATE_FOCUSED] ~= nil then
		delete(element.overlays[TextInputElement.STATE_FOCUSED]);
	end;
	element.imageFocusedFilename = filename;
	if element.imageFocusedFilename ~= nil then
		local overlay = createImageOverlay(element.imageFocusedFilename)
		element.overlays[TextInputElement.STATE_FOCUSED] = overlay;
	end;
end;
function TextInputElement:setImagePressedFilename(filename, element)
	if element.overlays[TextInputElement.STATE_PRESSED] ~= nil then
		delete(element.overlays[TextInputElement.STATE_PRESSED]);
	end;
	element.imagePressedFilename = filename;
	if element.imagePressedFilename ~= nil then
		local overlay = createImageOverlay(element.imagePressedFilename)
		element.overlays[TextInputElement.STATE_PRESSED] = overlay;
	end;
end;
