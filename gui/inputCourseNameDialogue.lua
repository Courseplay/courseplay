--[[
@name:    inputCourseNameDialogue
@desc:    Dialogue settings for the Courseplay course saving form
@author:  Jakob Tischler
@version: 1.5
@date:    31 Oct 2014
--]]

inputCourseNameDialogue = {};
inputCourseNameDialogue.firstTimeRun = true;
local inputCourseNameDialogue_mt = Class(inputCourseNameDialogue, ScreenElement)

inputCourseNameDialogue.MODE_COURSE = 1
inputCourseNameDialogue.MODE_FOLDER = 2
inputCourseNameDialogue.MODE_FILTER = 3
inputCourseNameDialogue.modeTexts = {
	'COURSEPLAY_COURSE_NAME',
	'COURSEPLAY_FOLDER_NAME',
	'COURSEPLAY_FILTER_COURSES'
}

inputCourseNameDialogue.CONTROLS = {
	titleTextElement = 'titleTextElement',
	textInputElement = 'textInputElement',
	buttonSave = 'buttonSave'
}

function inputCourseNameDialogue:new(target, custom_mt)
	if custom_mt == nil then
		custom_mt = inputCourseNameDialogue_mt
	end
	local self = ScreenElement:new(target, custom_mt)
	self:registerControls(inputCourseNameDialogue.CONTROLS)
	-- needed for onClickBack to work.
	self.returnScreenName = "";
	self.mode = self.MODE_COURSE
	return self
end; --END new()

function inputCourseNameDialogue:debug(...)
	courseplay.debugVehicle(courseplay.DBG_COURSES, self.vehicle, 'courseNameDialog: ' .. string.format(...))
end

---@param index number selected entry in the HUD, to pass on to the course manager
function inputCourseNameDialogue:setCourseMode(vehicle, index)
	self.vehicle = vehicle
	self:debug('saving course to folder at index %s', tostring(index))
	self.mode = self.MODE_COURSE
	self.index = index
end

---@param index number selected entry in the HUD, to pass on to the course manager
function inputCourseNameDialogue:setFolderMode(vehicle, index)
	self.vehicle = vehicle
	self:debug('creating folder in folder at index %s', tostring(index))
	self.mode = self.MODE_FOLDER
	self.index = index
end

function inputCourseNameDialogue:setFilterMode()
	self.mode = self.MODE_FILTER
end

function inputCourseNameDialogue:onOpen(element)
	g_currentMission.isPlayerFrozen = true;
	g_inputBinding:setShowMouseCursor(true);

	self.titleTextElement.text = courseplay:loc(self.modeTexts[self.mode])

	self:validateCourseName();

	FocusManager:setFocus(self.textInputElement)
	self.textInputElement.blockTime = 0
	self.textInputElement:onFocusActivate()
end; --END onOpen()

function inputCourseNameDialogue:onClose(element)
	g_inputBinding:setShowMouseCursor(false);
	g_currentMission.isPlayerFrozen = false;
end; --END onClose()

function inputCourseNameDialogue:onIsUnicodeAllowed(unicode)
	return courseplay.allowedCharacters[unicode] == true;
end; --END onIsUnicodeAllowed()

function inputCourseNameDialogue:onSaveClick()
	if self.mode == self.MODE_COURSE then
		if self.textInputElement ~= nil then
			g_courseManager:saveCourseFromVehicle(self.index, self.vehicle, self.textInputElement.text)
		end

	elseif self.mode == self.MODE_FOLDER then
		g_courseManager:createDirectory(self.index, self.textInputElement.text)

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
		-- TODO: WTF is this? Why are we calling cancel after we save?
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

	-- call the stock back handling
	self:onClickBack()
end;

function inputCourseNameDialogue:onTextChanged()
	self:validateCourseName();
end

function inputCourseNameDialogue:onEnterPressed()
	if self:validateCourseName() then
		self:onSaveClick();
	end;
end

function inputCourseNameDialogue:onEscPressed()
	self:onCancelClick()
end

function inputCourseNameDialogue:validateCourseName()
	local disabled = self.textInputElement.text == nil or self.textInputElement.text:len() < 1
	self.buttonSave:setDisabled(disabled)
	return not disabled;
end

g_inputCourseNameDialogue = inputCourseNameDialogue:new();
g_gui:loadGui(courseplay.path .. 'gui/inputCourseNameDialogue.xml', 'inputCourseNameDialogue', g_inputCourseNameDialogue);
FocusManager:setGui("MPLoadingScreen")