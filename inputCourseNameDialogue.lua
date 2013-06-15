--[[
@name:    inputCourseNameDialogue
@desc:    Dialogue settings for the Courseplay course saving form
@author:  Jakob Tischler
@version: 1.1
@date:    15 Jun 2013
--]]

inputCourseNameDialogue = {}
local inputCourseNameDialogue_mt = Class(inputCourseNameDialogue)

function inputCourseNameDialogue:new()
	local instance = {};
	instance = setmetatable(instance, inputCourseNameDialogue_mt);
	return instance;
end; --END new()

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
	--print("self.textInputElement.text="..tostring(self.textInputElement.text));
	
	courseplay.vehicleToSaveCourseIn.current_course_name = self.textInputElement.text;
	local maxId = 0;
	if g_currentMission.courseplay_courses ~= nil then
		local numExistingCourses = table.getn(g_currentMission.courseplay_courses);
		if numExistingCourses > 0 then
			for i=1, numExistingCourses do
				local curCourseId = g_currentMission.courseplay_courses[i].id;
				if curCourseId ~= nil and curCourseId > maxId then
					maxId = curCourseId;
				end;
			end;
		end;
	end;
	courseplay.vehicleToSaveCourseIn.courseID = maxId + 1;

	courseplay.vehicleToSaveCourseIn.numCourses = 1;
	local course = { name = courseplay.vehicleToSaveCourseIn.current_course_name, id = courseplay.vehicleToSaveCourseIn.courseID, waypoints = courseplay.vehicleToSaveCourseIn.Waypoints };

	if g_currentMission.courseplay_courses == nil then
		g_currentMission.courseplay_courses = {};
	end
	table.insert(g_currentMission.courseplay_courses, course);

	courseplay:save_courses(courseplay.vehicleToSaveCourseIn);
	
	self:onCancelClick();
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
