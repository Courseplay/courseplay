
function courseplay:mouseEvent(posX, posY, isDown, isUp, button)
  if isDown and button == 3 and self.isEntered then
    if self.mouse_enabled then
      self.mouse_enabled = false
    else
      self.mouse_enabled = true	    
      if not self.show_hud then
        self.showHudInfoBase = 1
        self.show_hud = true
      end
    end
    InputBinding.setShowMouseCursor(self.mouse_enabled)
  end
  if isDown and button == 1 and self.show_hud and self.isEntered then
    --print(string.format("posX: %f posY: %f",posX,posY))
    
    for _,button in pairs(self.buttons) do
      if button.page == self.showHudInfoBase or button.page == nil or button.page == self.showHudInfoBase*-1  then
        
        if posX > button.x and posX < button.x2 and posY > button.y and posY < button.y2 then
          local func = button.function_to_call
          
          -- TODO überhaupt nicht DRY das geht bestimmt irgendwie schöner
          if func == "switch_hud_page" then
            courseplay:switch_hud_page(self, button.parameter)
          end
          
          if func == "change_combine_offset" then
            courseplay:change_combine_offset(self, button.parameter)
          end
          
          if func == "load_course" then
            courseplay:load_course(self, button.parameter)
          end
          
          if func == "save_course" then
            courseplay:input_course_name(self)
          end
          
          if func == "clear_course" then
            courseplay:clear_course(self, button.parameter)
          end
          
          if func == "change_turn_radius" then
            courseplay:change_turn_radius(self, button.parameter)
          end
          
          if func == "change_tipper_offset" then
            courseplay:change_tipper_offset(self, button.parameter)
          end
          
          if func == "change_required_fill_level" then
            courseplay:change_required_fill_level(self, button.parameter)
          end
          
          if func == "change_turn_speed" then
            courseplay:change_turn_speed(self, button.parameter)
          end
          
          if func == "change_num_ai_helpers" then
            courseplay:change_num_ai_helpers(self, button.parameter)
          end
          
          if func == "change_field_speed" then
            courseplay:change_field_speed(self, button.parameter)
          end
          
          if func == "change_max_speed" then
            courseplay:change_max_speed(self, button.parameter)
          end
          
          if func == "switch_search_combine" then
            courseplay:switch_search_combine(self)
          end
          
          if func == "change_selected_course" then
            courseplay:change_selected_course(self, button.parameter)
          end
          
          if func == "switch_combine" then
            courseplay:switch_combine(self, button.parameter)
          end
          
          if func == "close_hud" then
            self.mouse_enabled = false
            self.show_hud = false
            InputBinding.setShowMouseCursor(self.mouse_enabled)
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
	              	 local last_recordnumber = nil
  
	              	 if self.recordnumber > 1 then
	              	   last_recordnumber = self.recordnumber - 1    
	              	 else
  					   last_recordnumber = 1
  					 end
  					      
	                if last_recordnumber ~= nil and self.Waypoints[last_recordnumber].wait and self.wait and func == "row2" then
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
	              if (not self.record and not self.record_pause) and (table.getn(self.Waypoints) == 0) then
	                if func == "row1" then
	                  courseplay:start_record(self)
	                end
	                
	              elseif (not self.record and not self.record_pause) and (table.getn(self.Waypoints) ~= 0) then
	              	if func == "row2" then
	              	  courseplay:change_ai_state(self, 1)
	              	end
	              else
	                if func == "row1" then
	                  courseplay:stop_record(self)
	                end
	                
					if not self.record_pause then
					  if func == "row2" and self.recordnumber > 3 then
						courseplay:set_waitpoint(self)
					  end
					  if func == "row3" and self.recordnumber > 3 then
						courseplay:interrupt_record(self)
					  end
					else
					  if func == "row2" and self.recordnumber > 4 then
					    courseplay:delete_waypoint(self)
					  end
					  if func == "row3" then
						courseplay:continue_record(self)
					  end
					end
	              end	  
				  
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
  
end;	



--  does something with the user input
function courseplay:handle_user_input(self)
	-- name for current_course
	if self.save_name then
		courseplay:load_courses(self)
		self.user_input_active = false
		self.current_course_name = self.user_input
		course = {name =self.current_course_name, waypoints = self.Waypoints}
		table.insert(self.courses, course)
		self.user_input = ""	   
		self.user_input_message = nil
		self.steeringEnabled = true   --test
		courseplay:save_courses(self)
	end
end

-- renders input form
function courseplay:user_input(self)
	renderText(0.4, 0.9,0.02, self.user_input_message .. self.user_input);
end