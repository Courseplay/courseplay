--[[
@name:    inputCourseNameDialogue
@desc:    Dialogue settings for the Courseplay course saving form
@author:  Jakob Tischler
@version: 1.0
@date:    14 Jun 2013
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
	
	FocusManager:setFocus(self.textInputElement);
	
	self:validateCourseName();
	
	--print(inputCourseNameDialogue:tableShow(self, "inputCourseNameDialogue", nil, "\t"));
end; --END onOpen()

function inputCourseNameDialogue:onClose(element)
	InputBinding.setShowMouseCursor(false);
	g_currentMission.isPlayerFrozen = false;
end; --END onClose()

function inputCourseNameDialogue:onIsUnicodeAllowed(unicode)
	--print("inputCourseNameDialogue:onIsUnicodeAllowed()");
	--print("self.allowedCharacters["..tostring(unicode) .."]=" .. tostring(self.allowedCharacters[unicode] == true));

	--[[
	--save [RETURN/ENTER]
	if unicode == 13 then
		if self:validateCourseName() then
			self:onSaveClick();
			return false;
		end;
	--cancel [ESCAPE]
	elseif unicode == 27 then
		self:onCancelClick();
		return false;
	end;
	]]
	
	return self.textInputElement.allowedCharacters[unicode] == true;
end; --END onIsUnicodeAllowed()

function inputCourseNameDialogue:onSaveClick()
	--print("inputCourseNameDialogue:onSaveClick()");
	--print("self.textInputElement.text="..tostring(self.textInputElement.text));
	
	courseplay.vehicleToSaveCourseIn.current_course_name = self.textInputElement.text;
	local maxId = 0;
	local numExistingCourses = table.getn(g_currentMission.courseplay_courses);
	if g_currentMission.courseplay_courses ~= nil and numExistingCourses > 0 then
		for i=1, numExistingCourses do
			local curCourseId = g_currentMission.courseplay_courses[i].id;
			if curCourseId ~= nil and g_currentMission.courseplay_courses[i].id > maxId then
				maxId = g_currentMission.courseplay_courses[i].id;
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

function inputCourseNameDialogue:onEscPressed()
	self:onCancelClick(self);
end; --END onEscPressed()

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
	--print("inputCourseNameDialogue:update()");
end; --END update()

function inputCourseNameDialogue:tableShow(t, name, channel, indent)
	--important performance backup: the channel is checked first before proceeding with the compilation of the table
	if channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == false then
		return;
	end;


	local cart -- a container
	local autoref -- for self references

	--[[ counts the number of elements in a table
local function tablecount(t)
   local n = 0
   for _, _ in pairs(t) do n = n+1 end
   return n
end
]]
	-- (RiciLake) returns true if the table is empty
	local function isemptytable(t) return next(t) == nil end

	local function basicSerialize(o)
		local so = tostring(o)
		if type(o) == "function" then
			local info = debug.getinfo(o, "S")
			-- info.name is nil because o is not a calling level
			if info.what == "C" then
				return string.format("%q", so .. ", C function")
			else
				-- the information is defined through lines
				return string.format("%q", so .. ", defined in (" ..
						info.linedefined .. "-" .. info.lastlinedefined ..
						")" .. info.source)
			end
		elseif type(o) == "number" then
			return so
		else
			return string.format("%q", so)
		end
	end

	local function addtocart(value, name, indent, saved, field)
		indent = indent or ""
		saved = saved or {}
		field = field or name

		cart = cart .. indent .. field

		if type(value) ~= "table" then
			cart = cart .. " = " .. basicSerialize(value) .. ";\n"
		else
			if saved[value] then
				cart = cart .. " = {}; -- " .. saved[value]
						.. " (self reference)\n"
				autoref = autoref .. name .. " = " .. saved[value] .. ";\n"
			else
				saved[value] = name
				--if tablecount(value) == 0 then
				if isemptytable(value) then
					cart = cart .. " = {};\n"
				else
					cart = cart .. " = {\n"
					for k, v in pairs(value) do
						k = basicSerialize(k)
						local fname = string.format("%s[%s]", name, k)
						field = string.format("[%s]", k)
						-- three spaces between levels
						addtocart(v, fname, indent .. "   ", saved, field)
					end
					cart = cart .. indent .. "};\n"
				end
			end
		end
	end

	name = name or "__unnamed__"
	if type(t) ~= "table" then
		return name .. " = " .. basicSerialize(t)
	end
	cart, autoref = "", ""
	addtocart(t, name, indent)
	return cart .. autoref
end;
