
function courseplay:mouseEvent(posX, posY, isDown, isUp, button) 
  if isDown and self.show_hud and self.isEntered then
    --print(string.format("posX: %f posY: %f",posX,posY))
    
    for _,button in pairs(self.buttons) do
      if button.page == self.showHudInfoBase or button.page == nil then
        
        if posX > button.x and posX < button.x2 and posY > button.y and posY < button.y2 then
          local func = button.function_to_call
          
          -- TODO überhaupt nicht DRY das geht bestimmt irgendwie schöner
          if func == "switch_hud_page" then
            courseplay:switch_hud_page(self, button.parameter)
          end
          
          
          if func == "row1" or func == "row2" or func == "row3" then
            if self.showHudInfoBase == 1 then
	            if self.play then
	              if not self.drive then
	                if func == "row3" then
	                  courseplay:reset_course(self)
	                end
	                
	                if func == "row1" then
	                  courseplay:start(self)
	                end 
	              else -- not drving          
	                if self.Waypoints[self.recordnumber].wait and self.wait and func == "row2" then
	                  self.wait = false
	                end
	                
	                if func == "row1" then
	                  courseplay:stop(self)
	                end
	                
	                if not self.loaded and func == "row3" then
	                  self.loaded = true
	                end 
	              end -- end not driving
	            end -- not playing
	            
	            if not self.drive  then
	              if not self.record and (table.getn(self.Waypoints) == 0) then
	                if func == "row1" then
	                  courseplay:start_record(self)
	                end
	                
	                if func == "row2" then
	                  courseplay:select_course(self)
	                end
	              elseif not self.record and (table.getn(self.Waypoints) ~= 0) then
	              	if func == "row2" then
	              	  courseplay:change_ai_state(self, 1)
	              	end
	              else
	                if func == "row1" then
	                  courseplay:stop_record(self)
	                end
	                
	                if func == "row2" then
	                  courseplay:set_waitpoint(self)
	                end
	              end
            	end
            end
            
            if self.showHudInfoBase == 2 then
              if func == "row2" then
                courseplay:select_course(self)
              end
              
              if func == "row3" then
                -- TODO delete coming soon
              end
              
              if func == "row1" and not self.record and (table.getn(self.Waypoints) ~= 0) then
                courseplay:input_course_name(self)
              end              
            end
            
          end
          
        end
      end
    end
  end
end		


-- deals with keyEvents
function courseplay:keyEvent(unicode, sym, modifier, isDown)
 
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
			  if k <= 3 or wp.wait == true then
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