-- saving // loading coures


-- enables input for course name
function courseplay:input_course_name(self)
 self.user_input = ""
 self.user_input_active = true
 self.save_name = true
 self.user_input_message = "Name des Kurses: "
end


function courseplay:display_course_selection(self)
  self.current_course_name = nil
  renderText(0.4, 0.9 ,0.02, "Kurs Laden:");
  
  local i = 0
  for name,wps in pairs(self.courses) do
    local addit = ""
	i = i + 1
	if self.selected_course_number == i then
	  addit = " <<<< "
	  self.current_course_name = name
	end
	local yspace = 0.9 - (i * 0.022)
	
	renderText(0.4, yspace ,0.02, name .. addit);
  end
  
end

function courseplay:select_course(self)
  if self.course_selection_active then
	self.course_selection_active = false
  else
	courseplay:load_courses(self)
	self.course_selection_active = true
  end
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
			self.courses[name] = tempCourse
			i = i + 1
			finish_wp = true
			break
		  end
		until finish_wp == true
	until finish_all == true
end