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

function courseplay:load_course(self, id)
  if id ~= nil then
    id = self.selected_course_number + id
  	local course = self.courses[id]
  	if course == nil then
  	  return
  	end
  	courseplay:reset_course(self)
  	self.Waypoints = course.waypoints
	self.play = true
	self.recordnumber = 1
	self.maxnumber = table.getn(self.Waypoints)
  	self.current_course_name = course.name
	-- this adds the signs to the course
	for k,wp in pairs(self.Waypoints) do
  	  if k <= 3 or wp.wait == true then
  		courseplay:addsign(self, wp.cx, 0, wp.cz)
  	  end
    end
  end
end

function courseplay:clear_course(self, id)
  if id ~= nil then
    id = self.selected_course_number + id
    local course = self.courses[id]
    if course == nil then
      return
    end
    table.remove(self.courses, id)
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
    for _,course in pairs(self.courses) do
      if course ~= nil then
	      local name = course.name
	      local x = course.waypoints
	      File:write(tab .. "<course name=\"" .. name .. "\">\n")
	      for i = 1, table.getn(x) do
	        local v = x[i]
			local wait = 0
			local rev = 0
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
	        File:write(tab .. tab .. "<waypoint" .. i .. " pos=\"" .. v.cx .. " " .. v.cz .. "\" angle=\"" .. v.angle .. "\" rev=\"" .. rev .. "\" wait=\"" .. wait .. "\" />\n")
	      end
	      File:write(tab .. "</course>\n")
      end
    end
    File:write("</courses>\n")
    
    
    File:write("\n</XML>\n")
    File:close()
  end
end


function courseplay:load_courses(self)
	local finish_all = false
	self.courses = {}
	local path = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex .. "/"
    local existDir = io.open (path .. "courseplay.xml")
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
			tempCourse[s] = {cx = x, cz = z, angle = dangle, rev= rev, wait = wait}
			s = s + 1
		  else
		    local course = {name= name, waypoints=tempCourse}
		    table.insert(self.courses, course)
			i = i + 1
			finish_wp = true
			break
		  end
		until finish_wp == true
	until finish_all == true
end