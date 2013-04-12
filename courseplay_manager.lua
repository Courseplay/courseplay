courseplay_manager = {};
local courseplay_manager_mt = Class(courseplay_manager);

function courseplay_manager:loadMap(name)
	if g_currentMission.courseplay_courses == nil then
		--courseplay:debug("courseplay courses was nil and initialized", 2);
		g_currentMission.courseplay_courses = {};

		courseplay_coursesUnsort = {}
		if g_server ~= nil and table.getn(g_currentMission.courseplay_courses) == 0 then
			g_currentMission.courseplay_courses = courseplay_manager:load_courses()
			courseplay:debug("debugging g_currentMission.courseplay_coures", 4)
			courseplay:debug(table.show(g_currentMission.courseplay_courses), 4)
		end
	end
end

function courseplay_manager:deleteMap()
	g_currentMission.courseplay_courses = nil
end


function courseplay_manager:draw()
end

function courseplay_manager:update()
	--courseplay:debug(table.getn(g_currentMission.courseplay_courses), 4);
end

function courseplay_manager:keyEvent()
end

function courseplay_manager:load_courses()
	courseplay:debug('loading courses by courseplay manager', 3)
	local finish_all = false
	local path = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex .. "/"


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

				--course generation
				local generated = Utils.getNoNil(getXMLBool(File, key .. "#generated"), false);
				local turn = Utils.getNoNil(getXMLString(File, key .. "#turn"), "false");
				local turnStart = Utils.getNoNil(getXMLInt(File, key .. "#turnstart"), 0);
				local turnEnd = Utils.getNoNil(getXMLInt(File, key .. "#turnend"), 0);
				local ridgeMarker = Utils.getNoNil(getXMLInt(File, key .. "#ridgemarker"), 0);

				crossing = crossing == 1 or s == 1;
				wait = wait == 1;
				rev = rev == 1;

				if speed == 0 then
					speed = nil
				end

				--generated not needed, since true or false are loaded from file
				if turn == "false" then
					turn = nil;
				end;
				turnStart = turnStart == 1;
				turnEnd = turnEnd == 1;
				--ridgeMarker not needed, since 0, 1 or 2 is loaded from file

				tempCourse[s] = { 
					cx = x, 
					cz = z, 
					angle = dangle, 
					rev = rev, 
					wait = wait, 
					crossing = crossing, 
					speed = speed,
					generated = generated,
					turn = turn,
					turnStart = turnStart,
					turnEnd = turnEnd,
					ridgeMarker = ridgeMarker
				};
				s = s + 1;
			else
				local course = { name = name, id = id, waypoints = tempCourse }
				table.insert(courseplay_coursesUnsort, course)
				i = i + 1
				finish_wp = true
				break
			end
			until finish_wp == true
		until finish_all == true

	g_currentMission.courseplay_courses = {}

	for i = 1, table.getn(courseplay_coursesUnsort) do
		local name = courseplay_coursesUnsort[i].name
		table.insert(g_currentMission.courseplay_courses, name)
	end

	table.sort(g_currentMission.courseplay_courses)

	for i = 1, table.getn(g_currentMission.courseplay_courses) do
		for k, v in pairs(courseplay_coursesUnsort) do
			if g_currentMission.courseplay_courses[i] == courseplay_coursesUnsort[k].name then
				local waypoints = courseplay_coursesUnsort[k].waypoints
				local name = g_currentMission.courseplay_courses[i]
				local id = courseplay_coursesUnsort[k].id
				local course = { name = name, id = id, waypoints = waypoints }
				g_currentMission.courseplay_courses[i] = course
				break
			end
		end
	end
	-- search highest ID
	local maxID = 0
	for i = 1, table.getn(g_currentMission.courseplay_courses) do
		if g_currentMission.courseplay_courses[i].id ~= nil then
			if g_currentMission.courseplay_courses[i].id > maxID then
				maxID = g_currentMission.courseplay_courses[i].id
			end
		end
	end

	courseplay:debug(table.show(courseplay_courses), 4);

	courseplay_coursesUnsort = nil
	return g_currentMission.courseplay_courses
end


function courseplay_manager:mouseEvent(posX, posY, isDown, isUp, button)
end



stream_debug_counter = 0

addModEventListener(courseplay_manager);

--
-- based on PlayerJoinFix
--
-- SFM-Modding
-- @author  Manuel Leithner
-- @date:		01/08/11
-- @version:	v1.0
-- @history:	v1.0 - initial implementation 1.1 adaption to courseplay
--

local modName = g_currentModName;
local Server_sendObjects_old = Server.sendObjects;

function Server:sendObjects(connection, x, y, z, viewDistanceCoeff)
	connection:sendEvent(CourseplayJoinFixEvent:new());

	Server_sendObjects_old(self, connection, x, y, z, viewDistanceCoeff);
end


CourseplayJoinFixEvent = {};
CourseplayJoinFixEvent_mt = Class(CourseplayJoinFixEvent, Event);

InitEventClass(CourseplayJoinFixEvent, "CourseplayJoinFixEvent");

function CourseplayJoinFixEvent:emptyNew()
	local self = Event:new(CourseplayJoinFixEvent_mt);
	self.className = modName .. ".CourseplayJoinFixEvent";
	return self;
end

function CourseplayJoinFixEvent:new()
	local self = CourseplayJoinFixEvent:emptyNew()
	return self;
end

function CourseplayJoinFixEvent:writeStream(streamId, connection)


	if not connection:getIsServer() then
		--courseplay:debug("manager transfering courses", 4);
		--transfer courses
		local course_count = table.getn(g_currentMission.courseplay_courses)

		streamDebugWriteInt32(streamId, course_count)
		for i = 1, course_count do
			streamDebugWriteString(streamId, g_currentMission.courseplay_courses[i].name)
			streamDebugWriteInt32(streamId, g_currentMission.courseplay_courses[i].id)
			streamDebugWriteInt32(streamId, table.getn(g_currentMission.courseplay_courses[i].waypoints))
			for w = 1, table.getn(g_currentMission.courseplay_courses[i].waypoints) do
				streamDebugWriteFloat32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].cx)
				streamDebugWriteFloat32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].cz)
				streamDebugWriteFloat32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].angle)
				streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].wait)
				streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].rev)
				streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].crossing)
				streamDebugWriteInt32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].speed)

				streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].generated)
				streamDebugWriteString(streamId, g_currentMission.courseplay_courses[i].waypoints[w].turn)
				streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].turnStart)
				streamDebugWriteBool(streamId, g_currentMission.courseplay_courses[i].waypoints[w].turnEnd)
				streamDebugWriteInt32(streamId, g_currentMission.courseplay_courses[i].waypoints[w].ridgeMarker)
			end
		end
	end;
end

function CourseplayJoinFixEvent:readStream(streamId, connection)
	if connection:getIsServer() then
		--courseplay:debug("manager receiving courses", 4);
		-- course count
		local course_count = streamDebugReadInt32(streamId)
		--courseplay:debug("manager reading stream", 4);
		--courseplay:debug(course_count, 4);
		g_currentMission.courseplay_courses = {}
		for i = 1, course_count do
			--courseplay:debug("got course", 4);
			local course_name = streamDebugReadString(streamId)
			local course_id = streamDebugReadInt32(streamId)
			local wp_count = streamDebugReadInt32(streamId)
			local waypoints = {}
			for w = 1, wp_count do
				--courseplay:debug("got waypoint", 4);
				local cx = streamDebugReadFloat32(streamId)
				local cz = streamDebugReadFloat32(streamId)
				local angle = streamDebugReadFloat32(streamId)
				local wait = streamDebugReadBool(streamId)
				local rev = streamDebugReadBool(streamId)
				local crossing = streamDebugReadBool(streamId)
				local speeed = streamDebugReadInt32(streamId)

				local generated = streamDebugReadBool(streamId)
				local turn = streamDebugReadString(streamId)
				local turnStart = streamDebugReadBool(streamId)
				local turnEnd = streamDebugReadBool(streamId)
				local ridgeMarker = streamDebugReadInt32(streamId)
				
				local wp = {
					cx = cx, 
					cz = cz, 
					angle = angle, 
					wait = wait, 
					rev = rev, 
					crossing = crossing, 
					speed = speed,
					generated = generated,
					turn = turn,
					turnStart = turnStart,
					turnEnd = turnEnd,
					ridgeMarker = ridgeMarker 
				};
				table.insert(waypoints, wp)
			end
			local course = { name = course_name, waypoints = waypoints, id = course_id }
			table.insert(g_currentMission.courseplay_courses, course)
		end
	end;
end

function CourseplayJoinFixEvent:run(connection)
	--courseplay:debug("CourseplayJoinFixEvent Run function should never be called", 4);
end

;
