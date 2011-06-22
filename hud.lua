-- Load Lines for Hud
function courseplay:HudPage(self)
  local Page = self.showHudInfoBase
  local i = 0
  --local c = 1
  setTextBold(false)
  for c=1, 2, 1 do
    for v,name in pairs(self.hudpage[Page][c]) do
      if c == 1 then
        local yspace = self.hudInfoBasePosY + 0.200 - ((v-1) * 0.021)
        renderText(self.hudInfoBasePosX + 0.005, yspace, 0.019, name);
      elseif c == 2 then
       local yspace = self.hudInfoBasePosY + 0.200 - ((v-1) * 0.021)
       renderText(self.hudInfoBasePosX + 0.122, yspace, 0.017, name);
      end
     i = i + 1
    end
    i = 0
  end
end

function courseplay:loadHud(self)
	self.hudpage[0][1] = {}
	self.hudpage[0][2] = {}
	self.hudpage[0][3] = {}
	self.hudpage[0][4] = {}
    self.hudpage[1][1] = {}
    self.hudpage[1][2] = {}
				
    if self.show_hud then
      self.hudInfoBaseOverlay:render();
	  if self.showHudInfoBase == 0 then
	    -- no courseplayer!
	    if self.courseplayers == nil or table.getn(self.courseplayers) == 0 then
	      if self.wants_courseplayer then
	        self.hudpage[0][1][1]= courseplay:get_locale(self, "CoursePlayCalledPlayer")
	      else
	        self.hudpage[0][1][1]= courseplay:get_locale(self, "CoursePlayCallPlayer")
	      end
	    else
	      self.hudpage[0][1][1]= courseplay:get_locale(self, "CoursePlayPlayer")
	      local tractor = self.courseplayers[1] 
	      self.hudpage[0][2][1] = tractor.name
	      
	      if tractor.forced_to_stop then
	    	self.hudpage[0][1][2]= courseplay:get_locale(self, "CoursePlayPlayerStart")	          
	      else
	        self.hudpage[0][1][2]= courseplay:get_locale(self, "CoursePlayPlayerStop")
	      end   
          self.hudpage[0][1][3]= courseplay:get_locale(self, "CoursePlayPlayerSendHome")
          if self.grainTankCapacity == 0 then
             local tractor = self.courseplayers[1]
             if tractor ~= nil then
            	self.hudpage[0][1][4]= courseplay:get_locale(self, "CoursePlayPlayerSwitchSide")
	            if tractor.forced_side == "left" then
	              self.hudpage[0][2][4]= courseplay:get_locale(self, "CoursePlayPlayerSideLeft")
	            elseif tractor.forced_side == "right" then
	             self.hudpage[0][2][4]= courseplay:get_locale(self, "CoursePlayPlayerSideRight")
	            else
	      		  self.hudpage[0][2][4]= courseplay:get_locale(self, "CoursePlayPlayerSideNone")
	      		end
            end
          end
	    end
	  elseif self.showHudInfoBase == 1 then
        if self.play then
			if not self.drive then
			    self.hudpage[1][1][3]= courseplay:get_locale(self, "CourseReset")
				
	            self.hudpage[1][1][1]= courseplay:get_locale(self, "CoursePlayStart")
				
			else
				local last_recordnumber = nil
				
			    if self.recordnumber > 1 then
			      last_recordnumber = self.recordnumber - 1    
			    else
			      last_recordnumber = 1
			    end
			    
				if (self.Waypoints[last_recordnumber].wait and self.wait) or (self.StopEnd and (self.recordnumber == self.maxnumber or self.currentTipTrigger ~= nil)) then
	   				self.hudpage[1][1][2]= courseplay:get_locale(self, "CourseWaitpointStart")
	   				
				end

				self.hudpage[1][1][1]= courseplay:get_locale(self, "CoursePlayStop")
			

				if not self.loaded and self.ai_mode ~= 5 then
					self.hudpage[1][1][3]= courseplay:get_locale(self, "NoWaitforfill")				
				end
				
				if not self.StopEnd then
					self.hudpage[1][1][4]= courseplay:get_locale(self, "CoursePlayStopEnd")
				end

				if InputBinding.hasEvent(InputBinding.AHInput3) then
					self.loaded = true
	   			end
			end
		end
		if not self.drive then
			if (not self.record and not self.record_pause) and (table.getn(self.Waypoints) == 0)  then
				self.hudpage[1][1][1]= courseplay:get_locale(self, "PointRecordStart")
				
			elseif (not self.record and not self.record_pause) and (table.getn(self.Waypoints) ~= 0) then	
			    self.hudpage[1][1][2]= courseplay:get_locale(self, "ModusSet")
				
	
			else
				self.hudpage[1][1][1]= courseplay:get_locale(self, "PointRecordStop")
				
				if not self.record_pause then	
					if self.recordnumber > 1 then
						self.hudpage[1][1][2]= courseplay:get_locale(self, "CourseWaitpointSet")
						
						self.hudpage[1][1][3]= courseplay:get_locale(self, "PointRecordInterrupt")
				
						self.hudpage[1][1][4]= courseplay:get_locale(self, "CourseCrossingSet")

						if not self.direction and self.movingDirection == -1 then
							courseplay:set_direction(self)
						end
						
						if self.direction and self.movingDirection == 1 then
							courseplay:set_direction(self)
						end
					end
				else
					if self.recordnumber > 4 then
						self.hudpage[1][1][2]= courseplay:get_locale(self, "PointRecordDelete")
				
					end
					
					self.hudpage[1][1][3]= courseplay:get_locale(self, "PointRecordContinue")
				
				end
				
			end
		end

	
	  elseif self.showHudInfoBase == 2 then
		local number_of_courses = 0
		if courseplay_courses ~= nil then
			for k,course in pairs(courseplay_courses) do 
			  number_of_courses = number_of_courses + 1
			end
		end
		local start_course_num = self.selected_course_number
		local end_course_num = start_course_num + 4
		
		if end_course_num >= number_of_courses then
		  end_course_num = number_of_courses-1
		end
		
		for i = 0, 10, 1 do
		  self.hudpage[2][1][i] = nil
		end
		
		
		local row =1
		for i = start_course_num, end_course_num, 1 do
		  for _,button in pairs(self.buttons) do
		    if button.page == -2 and button.row == row then
		      button.overlay:render()
		    end
		  end		  
		  local course_name = courseplay_courses[i+1].name
		  
		  if course_name == nil or course_name == "" then
		    course_name = "-"
		  end
		  
		  self.hudpage[2][1][row] = course_name
		  row = row +1 
		end
		
	  elseif self.showHudInfoBase == 3 then
		self.hudpage[3][1][1]= courseplay:get_locale(self, "CPCombineOffset") --"seitl. Abstand:"
	    self.hudpage[3][1][2]= courseplay:get_locale(self, "CPRequiredFillLevel") --"Start bei%:"
		self.hudpage[3][1][3]= courseplay:get_locale(self, "CPTurnRadius") --"Wenderadius:"
		self.hudpage[3][1][4]= courseplay:get_locale(self, "CPPipeOffset") --"Pipe Abstand:"
		self.hudpage[3][1][5]= courseplay:get_locale(self, "NoWaitforfillAt") --"abfahren bei%:"
		
		if self.ai_state ~= nil then
			self.hudpage[3][2][1]= string.format("%.1f", self.combine_offset)
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
		
		if self.tipper_offset ~= nil then
		  self.hudpage[3][2][4]= string.format("%.1f", self.tipper_offset)
		else
		  self.hudpage[3][2][4]= "---"
		end	
		
		if self.required_fill_level_for_drive_on ~= nil then
			self.hudpage[3][2][5]= string.format("%.1f", self.required_fill_level_for_drive_on)
		else
			self.hudpage[3][2][5]= "---"
		end
	  
	  elseif self.showHudInfoBase == 4 then
	    
	    self.hudpage[4][1][1]= courseplay:get_locale(self, "CPSelectCombine") -- "Drescher wählen:"
	    self.hudpage[4][1][2]= courseplay:get_locale(self, "CPCombineSearch") -- "Dreschersuche:"
	    self.hudpage[4][1][3]= courseplay:get_locale(self, "CPActual") -- "Aktuell:"
	    --self.hudpage[4][1][4]= courseplay:get_locale(self, "CPMaxHireables") -- "Aktuell:"
	  	--self.hudpage[4][2][4] = string.format("%d", g_currentMission.maxNumHirables)
	  
	    if self.active_combine ~= nil then
	      self.hudpage[4][2][3] = self.active_combine.name
	    else
	      self.hudpage[4][2][3] = courseplay:get_locale(self, "CPNone") -- "keiner"
	    end
	  
	    if self.saved_combine ~= nil then
	      local combine_name = self.saved_combine.name
	      if combine_name == nil then
	        combine_name = "Combine"
	      end
	      self.hudpage[4][2][1] = combine_name .. " (" .. string.format("%d", courseplay:distance_to_object(self, self.saved_combine)).."m)"
	    else
	      self.hudpage[4][2][1] = courseplay:get_locale(self, "CPNone") -- "keiner"
	    end
	  
	    if self.search_combine then
	      self.hudpage[4][2][2]= courseplay:get_locale(self, "CPFindAuto") -- "automatisch finden"
	    else
	      self.hudpage[4][2][2]= courseplay:get_locale(self, "CPFindManual") -- "manuell zuweisen"
	    end
	    
	    

	  elseif self.showHudInfoBase == 5 then
	    self.hudpage[5][1][1]= courseplay:get_locale(self, "CPTurnSpeed") -- "Wendemanöver:"
	    self.hudpage[5][1][2]= courseplay:get_locale(self, "CPFieldSpeed") -- "Auf dem Feld:"
	    self.hudpage[5][1][3]= courseplay:get_locale(self, "CPMaxSpeed") -- "Auf Straße:"
	    
	    self.hudpage[5][2][1]= string.format("%d", self.turn_speed*3600) .. " km/h"
	    self.hudpage[5][2][2]= string.format("%d", self.field_speed*3600) .. " km/h"
	    self.hudpage[5][2][3]= string.format("%d", self.max_speed*3600) .. " km/h"

	  
	  elseif self.showHudInfoBase == 6 then
	    self.hudpage[6][1][1]= courseplay:get_locale(self, "CPWpOffsetX") -- X-Offset
	    self.hudpage[6][1][2]= courseplay:get_locale(self, "CPWpOffsetZ") -- Z-Offset:


     	if self.WpOffsetX ~= nil then
		  self.hudpage[6][2][1]= string.format("%.1f", self.WpOffsetX) .. "m"
		else
		  self.hudpage[6][2][1]= "---"
		end
		
		if self.WpOffsetZ ~= nil then
		  self.hudpage[6][2][2]= string.format("%.1f", self.WpOffsetZ) .. "m"
		else
		  self.hudpage[6][2][2]= "---"
		end

	  end
	  
	  

	end-- end if show_hud
end


function courseplay:showHud(self)
  -- HUD
	if self.show_hud and self.isEntered then
	    
		
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
        elseif self.ai_mode == 6 then
		    self.hudinfo[1]= courseplay:get_locale(self, "CourseMode6")
		else
		    self.hudinfo[1]= "---"
		end

    	if self.current_course_name ~= nil then
			self.hudinfo[2]= courseplay:get_locale(self, "CPCourse").. " " .. self.current_course_name
		else
			self.hudinfo[2]=  courseplay:get_locale(self, "CPNoCourseLoaded") -- "Kurs: kein Kurs geladen"
		end
		
		if self.Waypoints[self.recordnumber ] ~= nil then
		    self.hudinfo[3]= courseplay:get_locale(self, "CPWaypoint") ..self.recordnumber .."/"..self.maxnumber .."    ".. self.locales.WaitPoints.. self.waitPoints.."    "..self.locales.CrossPoints.. self.crossPoints
		elseif self.record or self.record_pause then
			 self.hudinfo[3]= courseplay:get_locale(self, "CPWaypoint") ..self.recordnumber .."    ".. self.locales.WaitPoints .. self.waitPoints  .."    ".. self.locales.CrossPoints .. self.crossPoints
		else  
			self.hudinfo[3]=  courseplay:get_locale(self, "CPNoWaypoint") -- "Keine Wegpunkte geladen"
		end
		setTextBold(false)
		local i = 0
        for v,name in pairs(self.hudinfo) do
            local yspace = self.hudInfoBasePosY + 0.077 - (i * 0.021)
        	renderText(self.hudInfoBasePosX + 0.003, yspace, 0.017, name);
            i = i + 1
		end


		setTextBold(true)
		local hud_headline = nil
		
		if self.showHudInfoBase == 0 then
		  hud_headline= courseplay:get_locale(self, "CPCombineMangament") -- "Kurse verwalten"
		elseif self.showHudInfoBase == 1 then
		  hud_headline= courseplay:get_locale(self, "CPSteering") -- "Abfahrhelfer Steuerung"
		elseif self.showHudInfoBase == 2 then
	      hud_headline= courseplay:get_locale(self, "CPManageCourses") -- "Kurse verwalten"
	    elseif self.showHudInfoBase == 3 then
	      hud_headline= courseplay:get_locale(self, "CPCombiSettings") -- "Einstellungen Combi Modus"
		elseif self.showHudInfoBase == 4 then
		  hud_headline= courseplay:get_locale(self, "CPManageCombines") -- "Drescher verwalten";
		elseif self.showHudInfoBase == 5 then
		  hud_headline= courseplay:get_locale(self, "CPSpeedLimit") -- "Geschwindigkeiten"
		elseif self.showHudInfoBase == 6 then
		  hud_headline= courseplay:get_locale(self, "CPSettings") -- "Allgemein"
		end
		
	    renderText(self.hudInfoBasePosX + 0.060, self.hudInfoBasePosY + 0.240, 0.021, hud_headline);
	    courseplay:HudPage(self);


	end
	
	if self.play then
	  -- hud not displayed - display start stop
	  if self.drive then
	    g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStop"), InputBinding.AHInput1);
	    if InputBinding.hasEvent(InputBinding.AHInput1) then
	      self:setCourseplayFunc("stop", nil)    
	    end
	    
	     local last_recordnumber = nil
  
	     if self.recordnumber > 1 then
	       last_recordnumber = self.recordnumber - 1    
         else
           last_recordnumber = 1
         end
	    
	    if self.Waypoints[last_recordnumber].wait and self.wait then
	      g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CourseWaitpointStart"), InputBinding.AHInput2);
	      if InputBinding.hasEvent(InputBinding.AHInput2) then
	        self:setCourseplayFunc("drive_on", nil)    
	      end
	    end
	    	  
	  else
	  	g_currentMission:addHelpButtonText(courseplay:get_locale(self, "CoursePlayStart"), InputBinding.AHInput1);
	  	if InputBinding.hasEvent(InputBinding.AHInput1) then
	  	  self:setCourseplayFunc("start", nil)    
	  	end
	  end
	end
end

