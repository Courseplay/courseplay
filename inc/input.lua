
function courseplay:mouseEvent(posX, posY, isDown, isUp, button)
end		


-- deals with keyEvents
function courseplay:keyEvent(unicode, sym, modifier, isDown)
  if isDown and sym == Input.KEY_s and bitAND(modifier, Input.MOD_CTRL) > 0 then
	courseplay:input_course_name(self)
  end
  
  
  if isDown and sym == Input.KEY_o and bitAND(modifier, Input.MOD_CTRL) > 0 then
	courseplay:select_course(self)
  end
  
  -- user input fu
  if isDown and self.user_input_active then
	if 31 < unicode and unicode < 127 then 
		if self.user_input:len() <= 20 then
			self.user_input = self.user_input .. string.char(unicode)
		end
	end
	
	-- backspace
	if sym == 8 then
		if  self.user_input:len() >= 1 then
			 self.user_input =  self.user_input:sub(1, self.user_input:len() - 1)
		end
	end
	
	-- enter
	if sym == 13 then
		courseplay:handle_user_input(self)
	end
  end
  
  if isDown and self.course_selection_active then
	-- enter
	if sym == 13 then
		self.select_course = true
		courseplay:handle_user_input(self)
	end
	
	if sym == 273 then
	  if self.selected_course_number > 1 then
		self.selected_course_number = self.selected_course_number - 1
	  end
	end
	
	if sym == 274 then
	  if self.selected_course_number < 10 then
		self.selected_course_number = self.selected_course_number + 1
	  end
	end
  end
end;	



--  does something with the user input
function courseplay:handle_user_input(self)
	-- name for current_course
	if self.save_name then
	   courseplay:load_courses(self)
	   self.user_input_active = false
	   self.current_course_name = self.user_input
	   self.user_input = ""	   
	   self.user_input_message = nil
	   self.courses[self.current_course_name] = self.Waypoints
	   courseplay:save_courses(self)
	end
	
	if self.select_course then
		self.course_selection_active = false
		if self.current_course_name ~= nil then
		  courseplay:reset_course(self)
		  self.Waypoints = self.courses[self.current_course_name]
		  self.play = true
		  self.recordnumber = 1
		  self.maxnumber = table.getn(self.Waypoints)
		  
		  -- this adds the signs to the course
		  for k,wp in pairs(self.Waypoints) do
			  if k < 3 or wp.wait == true then
			  	courseplay:addsign(self, wp.cx, 0, wp.cz)
			  end
		  end
		end
	end
end

-- renders input form
function courseplay:user_input(self)
	renderText(0.4, 0.9,0.02, self.user_input_message .. self.user_input);
end