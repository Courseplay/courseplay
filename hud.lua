-- Load Lines for Hud
function courseplay:HudPage(self)
  local Page = self.showHudInfoBase
  local i = 0
  --local c = 1
  setTextBold(false)
  for c=1, 2, 1 do
    for v,name in pairs(self.hudpage[Page][c]) do
      if c == 1 then
        local yspace = 0.383 - (i * 0.021)
        renderText(0.763, yspace, 0.021, name);
      elseif c == 2 then
       local yspace = 0.383 - (i * 0.021)
       renderText(0.87, yspace, 0.021, name);
      end
     i = i + 1
    end
    i = 0
  end
end


function courseplay:loadHud(self)
  self.hudpage[1][1] = {}
    self.hudpage[1][2] = {}
    if self.show_hud then
	  if self.showHudInfoBase <= 1 then
        if self.play then
			if not self.drive then
			    self.hudpage[1][1][4]= courseplay:get_locale(self, "CourseReset")
				self.hudpage[1][2][4]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput3)
				if InputBinding.hasEvent(InputBinding.AHInput3) then
					courseplay:reset_course(self)
				end
	            self.hudpage[1][1][1]= courseplay:get_locale(self, "CoursePlayStart")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:start(self)
				end

			else
				if self.Waypoints[self.recordnumber].wait and self.wait then
	   				self.hudpage[1][1][2]= courseplay:get_locale(self, "CourseWaitpointStart")
					self.hudpage[1][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
	   				if InputBinding.hasEvent(InputBinding.AHInput2) then
						self.wait = false
					end
				end

				self.hudpage[1][1][1]= courseplay:get_locale(self, "CoursePlayStop")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:stop(self)
				end

				if not self.loaded then
					self.hudpage[1][1][3]= courseplay:get_locale(self, "NoWaitforfill")
					self.hudpage[1][2][3]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput3)
				end

				if InputBinding.hasEvent(InputBinding.AHInput3) then
					self.loaded = true
	   			end
			end
		end
		if not self.drive  then
			if not self.record and (table.getn(self.Waypoints) == 0)  then
				self.hudpage[1][1][1]= courseplay:get_locale(self, "PointRecordStart")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:start_record(self)
				end
	
	            self.hudpage[1][1][2]= courseplay:get_locale(self, "CourseLoad")
				self.hudpage[1][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
	            if InputBinding.hasEvent(InputBinding.AHInput2) then
	   				 courseplay:select_course(self)
				end
	
					
			elseif not self.record and (table.getn(self.Waypoints) ~= 0) then	
			    self.hudpage[1][1][3]= courseplay:get_locale(self, "ModusSet")
	            self.hudpage[1][2][3]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)

				if InputBinding.hasEvent(InputBinding.AHInput2) then
				    courseplay:change_ai_state(self, 1)					
				end
	
			else
				self.hudpage[1][1][1]= courseplay:get_locale(self, "PointRecordStop")
				self.hudpage[1][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
				if InputBinding.hasEvent(InputBinding.AHInput1) then
					courseplay:stop_record(self)
				end
	
	            self.hudpage[1][1][2]= courseplay:get_locale(self, "CourseWaitpointSet")
				self.hudpage[1][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
				if InputBinding.hasEvent(InputBinding.AHInput2) then
					courseplay:set_waitpoint(self)
				end
			end
		end
	

	
	  elseif self.showHudInfoBase == 2 then
		self.hudpage[2][1][2]= courseplay:get_locale(self, "CourseLoad")
		self.hudpage[2][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
	        if InputBinding.hasEvent(InputBinding.AHInput2) then
	   			 courseplay:select_course(self)
			end	
			
		self.hudpage[2][1][3]= courseplay:get_locale(self, "CourseDel")
		self.hudpage[2][2][3]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput3)
        if InputBinding.hasEvent(InputBinding.AHInput3) then
		 -- comming soon
   		end
   			
		if not self.record and (table.getn(self.Waypoints) ~= 0) then
			self.hudpage[2][1][1]= courseplay:get_locale(self, "CourseSave")
			self.hudpage[2][2][1]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput1)
			
			if InputBinding.hasEvent(InputBinding.AHInput1) then
   				 courseplay:input_course_name(self)
   		 	end
   		end
	  elseif self.showHudInfoBase == 3 then
		self.hudpage[3][1][1]= "Abstand zum Drescher:"
	    self.hudpage[3][1][2]= "Start bei%:"
		self.hudpage[3][1][3]= "Wenderadius:"
		
		if self.ai_state ~= nil then
			self.hudpage[3][2][1]= string.format("%d", self.combine_offset)
		else
			self.hudpage[3][2][1]= "---"
		end
		if self.required_fill_level_for_follow ~= nil then
			self.hudpage[3][2][2]= string.format("%d", self.required_fill_level_for_follow)
		else
			self.hudpage[3][2][2]= "---"
		end

		if self.turn_radius ~= nil then
			self.hudpage[3][2][3]= string.format("%d", self.turn_radius)
		else
			self.hudpage[3][2][3]= "---"
		end	

	  end
	end-- end if show_hud
end


function courseplay:showHud(self)
  -- HUD
	if self.show_hud and self.isEntered then
	    
		self.hudInfoBaseOverlay:render();
		courseplay:render_buttons(self, self.showHudInfoBase)
		
    	if self.ai_mode == 1 then
			self.hudinfo[1]= courseplay:get_locale(self, "CourseMode1")
		elseif self.ai_mode == 2 then
		    self.hudinfo[1]= courseplay:get_locale(self, "CourseMode2")
        elseif self.ai_mode == 3 then
		    self.hudinfo[1]= courseplay:get_locale(self, "CourseMode3")
        elseif self.ai_mode == 4 then
		    self.hudinfo[1]= courseplay:get_locale(self, "CourseMode4")
        elseif self.ai_mode == 5 then
		    self.hudinfo[1]= courseplay:get_locale(self, "CourseMode5")
		else
		     self.hudinfo[1]= "---"
		end

    	if self.current_course_name ~= nil then
			self.hudinfo[2]= "Kurs: "..self.current_course_name
		else
			self.hudinfo[2]=  "Kurs: kein Kurs geladen"
		end
		
		if self.Waypoints[self.recordnumber ] ~= nil then
		    self.hudinfo[3]= "Wegpunkt: "..self.recordnumber .." / "..self.maxnumber
		else
			self.hudinfo[3]=  "Keine Wegpunkte geladen"
		end
		setTextBold(false)
		local i = 0
        for v,name in pairs(self.hudinfo) do
            local yspace = 0.292 - (i * 0.021)
        	renderText(0.763, yspace, 0.021, name);
            i = i + 1
		end


		setTextBold(true)
		if self.showHudInfoBase == 1 then
			renderText(0.825, 0.408, 0.021, string.format("Tastenbelegung"));
			courseplay:HudPage(self);
		elseif self.showHudInfoBase == 2 then
	        renderText(0.825, 0.408, 0.021, string.format("Kurs Optionen"));
	        courseplay:HudPage(self);
	    elseif self.showHudInfoBase == 3 then
	      	renderText(0.825, 0.408, 0.021, string.format("Einstellungen"));
			courseplay:HudPage(self);
		end
	elseif self.play then
	  -- hud not displayed - display start stop
	  if self.drive then
	    g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStop"), InputBinding.AHInput1);
	    if InputBinding.hasEvent(InputBinding.AHInput1) then
	      courseplay:stop(self)
	    end
	    
	    if self.Waypoints[self.recordnumber].wait and self.wait then
	      self.hudpage[1][1][2]= courseplay:get_locale(self, "CourseWaitpointStart")
	      self.hudpage[1][2][2]= InputBinding.getKeyNamesOfDigitalAction(InputBinding.AHInput2)
	      if InputBinding.hasEvent(InputBinding.AHInput2) then
	        self.wait = false
	      end
	    end
	    	  
	  else
	  	g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStart"), InputBinding.AHInput1);
	  	if InputBinding.hasEvent(InputBinding.AHInput1) then
	  	  courseplay:start(self)
	  	end
	  end
	end
end