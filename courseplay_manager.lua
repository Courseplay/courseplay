
courseplay_manager = {};
local courseplay_manager_mt = Class(courseplay_manager);

function courseplay_manager:loadMap(name)
  if g_currentMission.courseplay_courses == nil then
    -- print("courseplay courses was nil and initialized");
    g_currentMission.courseplay_courses = {};
  
	  courseplay_coursesUnsort = {}
	  if g_server ~= nil and table.getn(g_currentMission.courseplay_courses) == 0 then
		g_currentMission.courseplay_courses = courseplay_manager:load_courses();
		---- print(table.show(g_currentMission.courseplay_courses));
	  end
  end
end


function courseplay_manager:draw()

end
function courseplay_manager:update()
 
end

function courseplay_manager:keyEvent()
end

function courseplay_manager:load_courses()
    -- print('loaded courses by manager')
	local finish_all = false
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
		local id = getXMLInt(File, baseName .. "#id")
		if id == nil then
			id = 0
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
			local speed = Utils.getVectorFromString(getXMLString(File, key .. "#speed"))
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
			
			if speed == 0 then
			  speed = nil
			end
			
			tempCourse[s] = {cx = x, cz = z, angle = dangle, rev= rev, wait = wait, crossing = crossing, speed = speed}
			s = s + 1
		  else
		    local course = {name= name,id= id, waypoints=tempCourse}
        	table.insert(courseplay_coursesUnsort, course)
			i = i + 1
			finish_wp = true
			break
		  end
		until finish_wp == true
	until finish_all == true

	g_currentMission.courseplay_courses = {}
	
	for i=1, table.getn(courseplay_coursesUnsort) do
		local name = courseplay_coursesUnsort[i].name
		table.insert(g_currentMission.courseplay_courses, name)
   	end
   	
  	table.sort (g_currentMission.courseplay_courses)
  	
  	for i=1, table.getn(g_currentMission.courseplay_courses) do
  	    for k, v in pairs (courseplay_coursesUnsort) do
			if g_currentMission.courseplay_courses[i] == courseplay_coursesUnsort[k].name then
				local waypoints = courseplay_coursesUnsort[k].waypoints
				local name =  g_currentMission.courseplay_courses[i]
				local id = courseplay_coursesUnsort[k].id
				local course = {name= name, id = id, waypoints=waypoints}
	            g_currentMission.courseplay_courses[i] = course
	            break
			end
		end
    end
	-- search highest ID
	local maxID = 0
    for i=1, table.getn(g_currentMission.courseplay_courses) do
		if g_currentMission.courseplay_courses[i].id ~= nil then
			if g_currentMission.courseplay_courses[i].id > maxID then
            	maxID = g_currentMission.courseplay_courses[i].id
       	 	end
		end
    end
	
    
    courseplay_coursesUnsort = nil
    return g_currentMission.courseplay_courses
end

function courseplay_manager:writeStream(streamId, connection)
  -- print("manager transfering courses");
  --transfer courses
    local course_count = table.getn(g_currentMission.courseplay_courses)
    
    streamDebugWriteInt32(streamId, course_count)
    for i=1, course_count do       
      streamDebugWriteString(streamId, g_currentMission.courseplay_courses[i].name)
      streamDebugWriteInt32(streamId, g_currentMission.courseplay_courses[i].id)
      streamDebugWriteInt32(streamId, table.getn(g_currentMission.courseplay_courses[i].waypoints))
      for w=1, table.getn(g_currentMission.courseplay_courses[i].waypoints) do
        streamDebugWriteFloat32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].cx)
        streamDebugWriteFloat32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].cz)
        streamDebugWriteFloat32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].angle)
        streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].wait)
        streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].rev)
        streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].crossing)
        streamDebugWriteInt32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].speed)         
      end
    end
end;

function courseplay_manager:readStream(streamId, connection)
  -- print("manager receiving courses");
  -- course count
  local course_count = streamDebugReadInt32(streamId)
  -- print("manager reading stream");
  -- print(course_count);
  g_currentMission.courseplay_courses = {}
  for i=1, course_count do
    -- print("got course");
    local course_name = streamDebugReadString(streamId)
    local course_id = streamDebugReadInt32(streamId)
    local wp_count = streamDebugReadInt32(streamId)
  	local  waypoints = {}
  	for w=1, wp_count do    
	  -- print("got waypoint");
  	  local cx = streamDebugReadFloat32(streamId)
  	  local cz = streamDebugReadFloat32(streamId)
  	  local angle = streamDebugReadFloat32(streamId)
  	  local wait = streamDebugReadBool(streamId)
  	  local rev = streamDebugReadBool(streamId)
  	  local crossing = streamDebugReadBool(streamId)
  	  local speeed  = streamDebugReadInt32(streamId)
  	  local wp = {cx = cx, cz = cz, angle = angle , wait = wait, rev = rev, crossing = crossing, speed = speed}
  	  table.insert(waypoints, wp)
  	end
    local course = {name = course_name, waypoints= waypoints, id = course_id}
    table.insert(g_currentMission.courseplay_courses, course)
  end  
  -- print(table.show(courseplay_courses));
end;

function courseplay_manager:mouseEvent(posX, posY, isDown, isUp, button)
end;




stream_debug_counter = 0

function streamDebugWriteFloat32(streamId, value)  
  value = Utils.getNoNil(value, 0.0)
  stream_debug_counter = stream_debug_counter +1
-- print("++++++++++++++++") 
-- print(stream_debug_counter)
-- print("float: ")
-- print(value)
-- print("-----------------") 
  streamWriteFloat32(streamId, value)
end

function streamDebugWriteBool(streamId, value)
	value = Utils.getNoNil(value, false)
	if value == 1 then
	  value = true
	end
	
	if value == 0 then
	  value = false
	end
	
	stream_debug_counter = stream_debug_counter +1
	-- print("++++++++++++++++") 
    -- print(stream_debug_counter)
	-- print("Bool: ")
    -- print(value)
	-- print("-----------------") 
	streamWriteBool(streamId, value)
end

function streamDebugWriteInt32(streamId, value)
value = Utils.getNoNil(value, 0)
stream_debug_counter = stream_debug_counter +1
-- print("++++++++++++++++") 
-- print(stream_debug_counter)
-- print("Int32: ")
-- print(value)
-- print("-----------------") 
  streamWriteInt32(streamId, value)
end

function streamDebugWriteString(streamId, value)
value = Utils.getNoNil(value, "")
stream_debug_counter = stream_debug_counter +1
-- print("++++++++++++++++") 
-- print(stream_debug_counter)
-- print("String: ")
-- print(value)
-- print("-----------------") 
  streamWriteString(streamId, value)
end


function streamDebugReadFloat32(streamId)
stream_debug_counter = stream_debug_counter +1
-- print("++++++++++++++++") 
-- print(stream_debug_counter)
  local value = streamReadFloat32(streamId)
-- print("Float32: ")
-- print(value)
-- print("-----------------") 
  return value
end


function streamDebugReadInt32(streamId)
stream_debug_counter = stream_debug_counter +1
-- print("++++++++++++++++") 
-- print(stream_debug_counter)
local value = streamReadInt32(streamId)
-- print("Int32: ")
-- print(value)
-- print("-----------------") 
return value
end

function streamDebugReadBool(streamId)
stream_debug_counter = stream_debug_counter +1
-- print("++++++++++++++++") 
-- print(stream_debug_counter)
local value = streamReadBool(streamId)
-- print("Bool: ")
-- print(value)
-- print("-----------------") 
return value
end

function streamDebugReadString(streamId)
stream_debug_counter = stream_debug_counter +1
-- print("++++++++++++++++") 
-- print(stream_debug_counter)
local value = streamReadString(streamId)
-- print("String: ")
-- print(value)
-- print("-----------------") 
return value
end

addModEventListener(courseplay_manager);