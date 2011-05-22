-- saving // loading coures


-- enables input for course name
function courseplay:input_course_name(self)
 if table.getn(self.Waypoints) > 0 then
   self.user_input = ""
   self.user_input_active = true
   self.steeringEnabled = false     -- test
   self.save_name = true
   self.user_input_message = courseplay:get_locale(self, "CPCourseName")
 end
end

function courseplay:reload_courses(self, use_real_id)
  for k,v in pairs(self.loaded_courses) do
 
      courseplay:load_course(self, v, use_real_id)
  end
end

function courseplay:add_course(self, id, use_real_id)
  courseplay:load_course(self, id, use_real_id, true)  
end


function courseplay:load_course(self, id, use_real_id, add_course_at_end)
	-- global array for courses, no refreshing needed any more	

  if id ~= nil and id ~= "" then
    if not use_real_id then      
      id = self.selected_course_number + id
      
    end
    id = id * 1
    
    if courseplay_courses == nil then
      if self.courseplay_courses ~= nil then
        courseplay_courses = self.courseplay_courses
      else
        print("courseplay_courses is empty")
        return    
      end
    end
    
  	local course = courseplay_courses[id]
  	if course == nil then
  	  print("no course found")
  	  return
  	end
  	if not use_real_id then
  	  table.insert(self.loaded_courses, id)
  	end
  --	courseplay:reset_course(self)
  	if table.getn(self.Waypoints) == 0 then
    	self.Waypoints = course.waypoints
    	self.current_course_name = course.name
	else -- Add new course to old course
		local course1_waypoints = self.Waypoints
		local course2_waypoints = course.waypoints
		local lastWP = table.getn(self.Waypoints)
		local wp_found = false
		local new_wp = 1
		-- go through all waypoints and try to find a waypoint of the next course near a crossing
		
		if add_course_at_end ~= true then
			for number, course1_wp in pairs(course1_waypoints) do
			  if course1_wp.crossing  == true then
			  	for number_2, course2_wp in pairs(course2_waypoints) do
			  	  if course2_wp.crossing == true then  
			        if courseplay:distance(course1_wp.cx, course1_wp.cz, course2_wp.cx, course2_wp.cz) < 30 then
			           if number > 3 and number ~= number_2 and not wp_found and course1_waypoints[number].merged == nil then
			             lastWP = number
			             new_wp = number_2
			             wp_found = true
			             print(number)
			             print(number_2)
			           end
			        end
			      end
			    end
			  end
			end
		end
		
		course1_waypoints[lastWP].merged = true
		
		self.Waypoints = {}
		
		for i=1, lastWP do
		  table.insert(self.Waypoints, course1_waypoints[i])
		end
		
  		local lastNewWP = table.getn(course.waypoints)
  		for i=new_wp, lastNewWP do
  			table.insert(self.Waypoints, course.waypoints[i])
  		end
  		self.Waypoints[lastWP+1].merged = true
  		self.current_course_name = self.locales.CPCourseAdded
  	end
	self.play = true
	self.recordnumber = 1
	self.maxnumber = table.getn(self.Waypoints)
	-- this adds the signs to the course
	for k,wp in pairs(self.Waypoints) do
  		if k <= 3 or wp.wait == true  or wp.crossing == true then
	  		if k == 1 then
	  		  courseplay:addsign(self, wp.cx, wp.angle, wp.cz, self.start_sign, true)
	  		elseif wp.crossing then
	  		  courseplay:addsign(self, wp.cx, wp.angle, wp.cz, self.cross_sign, true)
	  		elseif wp.wait then
	  		  courseplay:addsign(self, wp.cx, wp.angle, wp.cz, self.wait_sign)	  		
	  		else
	  		  courseplay:addsign(self, wp.cx, wp.angle, wp.cz)
	  		end	  		
  	  	end
  	  	if k == self.maxnumber then
  	  	  courseplay:addsign(self, wp.cx, wp.angle, wp.cz, self.stop_sign)
  	  	end
  	  	if wp.wait then
		self.waitPoints = self.waitPoints + 1
		end
		if wp.crossing then
		self.crossPoints = self.crossPoints + 1
		end
    end
  end
end

function courseplay:clear_course(self, id)
  if id ~= nil then
    id = self.selected_course_number + id
    local course = courseplay_courses[id]
    if course == nil then
      return
    end
    table.remove(courseplay_courses, id)
    courseplay:save_courses(self)
  end
end

-- saves coures to xml-file
function courseplay:save_courses(self)
  local path = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex .. "/"
  local File = io.open(path .. "courseplay.xml", "w")
  local tab = "   "
  if File ~= nil then
    File:write("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\" ?>\n<XML>\n<courses>\n")
    for _,course in pairs(courseplay_courses) do
      if course ~= nil then
	      local name = course.name
	      local x = course.waypoints
	      File:write(tab .. "<course name=\"" .. name .. "\">\n")
	      for i = 1, table.getn(x) do
	        local v = x[i]
			local wait = 0
			local crossing = 0
			local rev = 0
			
			if v.crossing then
			  crossing = "1"
			else
			  crossing = "0"
			end
			
			if v.wait then
			  wait = "1"
			else
			  wait = "0"
			end
			if v.rev then
			  rev = "1"
			else
			  rev = "0"
			end
	        File:write(tab .. tab .. "<waypoint" .. i .. " pos=\"" .. v.cx .. " " .. v.cz .. "\" angle=\"" .. v.angle .. "\" rev=\"" .. rev .. "\" wait=\"" .. wait .. "\" crossing=\"" .. crossing .. "\" />\n")
	      end
	      File:write(tab .. "</course>\n")
      end
    end
    File:write("</courses>\n")
    
    
    File:write("\n</XML>\n")
    File:close()
  end
end


function courseplay:load_courses()
    print('loaded courses')
	local finish_all = false
	courseplay_coursesUnsort = {}
	local path = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex .. "/"
    local existDir = io.open (path .. "courseplay.xml", "a")
	if existDir == nil then
	 return
	end

	local File = io.open(path .. "courseplay.xml", "a")
	File:close()
	File = loadXMLFile("courseFile", path .. "courseplay.xml")
	local i = 0
	repeat
		
		local baseName = string.format("XML.courses.course(%d)", i)
		local name = getXMLString(File, baseName .. "#name")
		if name == nil then
			finish_all = true
			break
		end
		local tempCourse = {}
	  
		local s = 1
		
		local finish_wp = false
		repeat
		  local key = baseName .. ".waypoint" .. s
		  local x, z = Utils.getVectorFromString(getXMLString(File, key .. "#pos"))
		  if x ~= nil then
			if z == nil then
			  finish_wp = true
			  break
			end
			local dangle = Utils.getVectorFromString(getXMLString(File, key .. "#angle"))
			local wait = Utils.getVectorFromString(getXMLString(File, key .. "#wait"))
			local rev = Utils.getVectorFromString(getXMLString(File, key .. "#rev"))
			local crossing = Utils.getVectorFromString(getXMLString(File, key .. "#crossing"))
			
			if crossing == 1 or s == 1 then
			  crossing = true
		    else
		      crossing = false
		    end
		    
			if wait == 1 then
			  wait = true
			else
			  wait = false
			end
			if rev == 1 then
			  rev = true
			else
			  rev = false
			end
			tempCourse[s] = {cx = x, cz = z, angle = dangle, rev= rev, wait = wait, crossing = crossing}
			s = s + 1
		  else
		    local course = {name= name, waypoints=tempCourse}
        	table.insert(courseplay_coursesUnsort, course)
			i = i + 1
			finish_wp = true
			break
		  end
		until finish_wp == true
	until finish_all == true

	courseplay_courses = {}
	
	for i=1, table.getn(courseplay_coursesUnsort) do
		local name = courseplay_coursesUnsort[i].name
		table.insert(courseplay_courses, name)
   	end
   	
  	table.sort (courseplay_courses)
  	
  	for i=1, table.getn(courseplay_courses) do
  	    for k, v in pairs (courseplay_coursesUnsort) do
			if courseplay_courses[i] == courseplay_coursesUnsort[k].name then
				local waypoints = courseplay_coursesUnsort[k].waypoints
				local name =  courseplay_courses[i]
				local course = {name= name, waypoints=waypoints}
	            courseplay_courses[i] = course
	            break
			end
		end
    end
    
    courseplay_coursesUnsort = nil
    return courseplay_courses
end


