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
inputCourseNameDialogue.types = { "course", "folder", "filter" };

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
	return self
end; --END new()


function inputCourseNameDialogue:onOpen(element)
	g_currentMission.isPlayerFrozen = true;
	g_inputBinding:setShowMouseCursor(true);

	local saveWhat = courseplay.vehicleToSaveCourseIn.cp.saveWhat
	if saveWhat == 'course' then
		self.titleTextElement.text = courseplay:loc('COURSEPLAY_COURSE_NAME')
	elseif saveWhat == 'folder' then
		self.titleTextElement.text = courseplay:loc('COURSEPLAY_FOLDER_NAME')
	elseif saveWhat == 'filter' then
		self.titleTextElement.text = courseplay:loc('COURSEPLAY_FILTER_COURSES')
	end

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
	local vehicle = courseplay.vehicleToSaveCourseIn
	if vehicle.cp.saveWhat == 'course' then
		if self.textInputElement ~= nil then
			CourseplayEvent.sendEvent(vehicle, "self.cp.saveWhat", vehicle.cp.saveWhat)
			vehicle:setCpVar('currentCourseName',self.textInputElement.text);
			vehicle.cp.doNotOnSaveClick = true
		end

		local maxID = courseplay.courses:getMaxCourseID()
		if maxID == nil then
			g_currentMission.cp_courses = {};
			maxID = 0
		end

		vehicle.cp.currentCourseId = maxID + 1;
		vehicle.cp.numCourses = 1;

		local course = { id = vehicle.cp.currentCourseId, uid = 'c'..vehicle.cp.currentCourseId, type = 'course', name = vehicle.cp.currentCourseName, nameClean = courseplay:normalizeUTF8(vehicle.cp.currentCourseName), waypoints = vehicle.Waypoints, parent = 0 }
		if vehicle.cp.courseWorkWidth then -- data for turn maneuver
			course.workWidth = vehicle.cp.courseWorkWidth;
		end;
		if vehicle.cp.courseNumHeadlandLanes then
			course.numHeadlandLanes = vehicle.cp.courseNumHeadlandLanes;
		end;
		if vehicle.cp.courseHeadlandDirectionCW ~= nil then
			course.headlandDirectionCW = vehicle.cp.courseHeadlandDirectionCW;
		end;
		if vehicle.cp.multiTools ~= 1 then
			course.multiTools = vehicle.cp.multiTools
		end;

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
		local folderID
		if not maxID or maxID == 0 then
			-- no folders yet
			g_currentMission.cp_folders = {}
			folderID = 1
		elseif g_currentMission.cp_folders[maxID].virtual then
			-- dirty trick: the last folder is virtual, make sure the virtual is always at the end of the folder list
			-- so there are no gaps in the real folder IDs
			-- so move up the virtual folder to the end
			courseplay.courses:moveFolder(maxID, maxID + 1)
			-- new folder goes where the virtual was before
			folderID = maxID
		else
			-- folders already exist, use the nextID
			folderID = maxID + 1
		end

		local folder = { id = folderID, uid = 'f'..folderID, type = 'folder', name = vehicle.cp.saveFolderName, nameClean = courseplay:normalizeUTF8(vehicle.cp.saveFolderName), parent = 0 }

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

	courseplay.vehicleToSaveCourseIn.cp.saveFolderName = nil
	courseplay.vehicleToSaveCourseIn = nil;
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
g_gui:loadGui(courseplay.path .. 'inputCourseNameDialogue.xml', 'inputCourseNameDialogue', g_inputCourseNameDialogue);
FocusManager:setGui("MPLoadingScreen")