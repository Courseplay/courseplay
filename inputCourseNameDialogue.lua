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
	--[[
	print("\\___MOD_imageFilename from xml = " .. tostring(MOD_imageFilename));
	print("\\___MOD_imageFocusedFilename from xml = " .. tostring(MOD_imageFocusedFilename));
	print("\\___MOD_imagePressedFilename from xml = " .. tostring(MOD_imagePressedFilename));
	print("\\___MOD_imageDisabledFilename from xml = " .. tostring(MOD_imageDisabledFilename));
	--]]

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
	self.titleTextElement.textCP = string.sub(element.text, 5);
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
	
	if self.titleTextElement.textCP ~= nil and courseplay.locales[self.titleTextElement.textCP] ~= nil then
		self.titleTextElement.text = courseplay.locales[self.titleTextElement.textCP];
		self.titleTextElement.textCP = nil;
	end;
	
	
	self:validateCourseName();

	FocusManager:setFocus(self.textInputElement);
	InputBinding.hasEvent(InputBinding.MENU_ACCEPT, true); --set focus
	
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
	if self.textInputElement ~= nil then
		--print("self.textInputElement.text= "..tostring(self.textInputElement.text).."  courseplay.vehicleToSaveCourseIn.current_course_name= "..tostring(courseplay.vehicleToSaveCourseIn.current_course_name));
		courseplay.vehicleToSaveCourseIn.current_course_name = self.textInputElement.text;
		CourseplayEvent.sendEvent(courseplay.vehicleToSaveCourseIn, "self.current_course_name", self.textInputElement.text)
		courseplay.vehicleToSaveCourseIn.cp.doNotOnSaveClick = true
	else
		--print("self.textInputElement.text= "..tostring(self.textInputElement).."  courseplay.vehicleToSaveCourseIn.current_course_name= "..tostring(courseplay.vehicleToSaveCourseIn.current_course_name));
	end
	if g_currentMission.courseplay_courses == nil then
		g_currentMission.courseplay_courses = {};
	end
	local numExistingCourses = table.getn(g_currentMission.courseplay_courses);
	local maxId = 0;
	if numExistingCourses > 0 then
		for i=1, numExistingCourses do
			local curCourseId = g_currentMission.courseplay_courses[i].id;
			if curCourseId ~= nil and curCourseId > maxId then
				maxId = curCourseId;
			end;
		end;
	end;
	courseplay.vehicleToSaveCourseIn.courseID = maxId + 1;
	courseplay.vehicleToSaveCourseIn.numCourses = 1;

	local course = { name = courseplay.vehicleToSaveCourseIn.current_course_name, id = courseplay.vehicleToSaveCourseIn.courseID, waypoints = courseplay.vehicleToSaveCourseIn.Waypoints };
	table.insert(g_currentMission.courseplay_courses, course);

	courseplay:save_courses(courseplay.vehicleToSaveCourseIn);
	
	if self.textInputElement ~= nil then
		CourseplayEvent.sendEvent(courseplay.vehicleToSaveCourseIn, "self.cp.onSaveClick",true)
		self:onCancelClick();
	end
end; --END onStartClick()

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
