-- saving // loading coures


-- enables input for course name
function courseplay:input_course_name(self)
 self.user_input = ""
 self.user_input_active = true
 self.save_name = true
 self.user_input_message = courseplay:get_locale(self, "CPCourseName")
end

function courseplay:load_course(self, id)

end

-- saves coures to xml-file
function courseplay:save_courses(self)
  local path = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex .. "/"
  local File = io.open(path .. "courseplay.xml", "w")
  local tab = "   "
  if File ~= nil then
    File:write("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\" ?>\n<XML>\n<courses>\n")
    for name,x in pairs(self.courses) do
      File:write(tab .. "<course name=\"" .. name .. "\">\n")
      for i = 1, table.getn(x) do
        local v = x[i]
		local wait = 0
		if v.wait then
		  wait = "1"
		else
		  wait = "0"
		end
        File:write(tab .. tab .. "<waypoint" .. i .. " pos=\"" .. v.cx .. " " .. v.cz .. "\" angle=\"" .. v.angle .. "\" wait=\"" .. wait .. "\" />\n")
      end
      File:write(tab .. "</course>\n")
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
			if wait == 1 then
			  wait = true
			else
			  wait = false
			end
			tempCourse[s] = {cx = x, cz = z, angle = dangle, wait = wait}
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