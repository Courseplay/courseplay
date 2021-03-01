CoursePlayNetworkHelper = {};

CourseplayEvent = {};
local CourseplayEvent_mt = Class(CourseplayEvent, Event);

InitEventClass(CourseplayEvent, "CourseplayEvent");

function CourseplayEvent:emptyNew()
	local self = Event:new(CourseplayEvent_mt);
	self.className = "CourseplayEvent";
	return self;
end

function CourseplayEvent:new(vehicle, func, value, page)
	courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"courseplay:CourseplayEvent:new( %s, %s, %s)",tostring(func), tostring(value), tostring(page))
	self.vehicle = vehicle;
	self.messageNumber = Utils.getNoNil(self.messageNumber,0) +1
	self.func = func
	self.value = value;
	self.type = type(value)
	self.page = page

	if self.type == "table" then
		if self.func == "setVehicleWaypoints" then
			self.type = "waypointList"
		end
	end

	return self;
end

function CourseplayEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	--local id = streamReadInt32(streamId);
	self.vehicle = NetworkUtil.readNodeObject(streamId);
	local messageNumber = streamReadFloat32(streamId);
	self.func = streamReadString(streamId);
	self.page = streamReadInt32(streamId);
	if self.page == 999 then
		self.page = "global"
	elseif self.page == 998 then
		self.page = true
	elseif self.page == 997 then
		self.page = false
	elseif self.page == 996 then
		self.page = nil
	end
	self.type = streamReadString(streamId);
	if self.type == "boolean" then
		self.value = streamReadBool(streamId);
	elseif self.type == "string" then
		self.value = streamReadString(streamId);
	elseif self.type == "nil" then
		self.value = streamReadString(streamId);
	elseif self.type == "waypointList" then
		local wp_count = streamReadInt32(streamId)
		self.value = {}
		for w = 1, wp_count do
			table.insert(self.value, CoursePlayNetworkHelper:readWaypoint(streamId))
		end
	else 
		self.value = streamReadFloat32(streamId);
	end
	courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"	readStream:")
	courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"	messageNumber: %s, functionCall: %s, value: %s, page: %s, type: %s ",tostring(messageNumber), tostring(self.func), tostring(self.value),tostring(self.page), tostring(self.type))

	self:run(connection);
end

function CourseplayEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"	writeStream:")
	courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"	messageNumber: %s, functionCall: %s, value: %s, page: %s, type: %s ",tostring(messageNumber), tostring(self.func), tostring(self.value),tostring(self.page), tostring(self.type))
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
	streamWriteFloat32(streamId, self.messageNumber);
	streamWriteString(streamId, self.func);
	if self.page == "global" then
		self.page = 999
	elseif self.page == true then
		self.page = 998
	elseif self.page == false then
		self.page = 997
	elseif self.page == nil then
		self.page = 996
	end
	streamWriteInt32(streamId, self.page);
	streamWriteString(streamId, self.type);
	if self.type == "boolean" then
		streamWriteBool(streamId, self.value);
	elseif self.type == "string" then
		streamWriteString(streamId, self.value);
	elseif self.type == "nil" then
		streamWriteString(streamId, "nil");
	elseif self.type == "waypointList" then
		streamWriteInt32(streamId, #(self.value))
		for w = 1, #(self.value) do
			CoursePlayNetworkHelper:writeWaypoint(streamId, self.value[w])
		end
	else
		streamWriteFloat32(streamId, self.value);
	end
end

function CourseplayEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"\t\t\trun")
	courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,'\t\t\t\function=%s, value=%s', tostring(self.func), tostring(self.value));
	self.vehicle:setCourseplayFunc(self.func, self.value, true, self.page);
	if not connection:getIsServer() then
		courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"broadcast event feedback")
		g_server:broadcastEvent(CourseplayEvent:new(self.vehicle, self.func, self.value, self.page), nil, connection, self.object);
	end;
end

function CourseplayEvent.sendEvent(vehicle, func, value, noEventSend, page) -- hilfsfunktion, die Events anst��te (wirde von setRotateDirection in der Spezi aufgerufen) 
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"broadcast event")
			courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,'function=%s, value=%s, page=%s', tostring(func), tostring(value), tostring(page));
			g_server:broadcastEvent(CourseplayEvent:new(vehicle, func, value, page), nil, nil, vehicle);
		else
			courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"send event")
			courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,'function=%s, value=%s, page=%s', tostring(func), tostring(value), tostring(page));
			g_client:getServerConnection():sendEvent(CourseplayEvent:new(vehicle, func, value, page));
		end;
	end;
end

function courseplay:checkForChangeAndBroadcast(self, stringName, variable , variableMemory)
	if variable ~= variableMemory then
		courseplay:debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"checkForChangeAndBroadcast")
		CourseplayEvent.sendEvent(self, stringName, variable)
		variableMemory = variable
	end
	return variableMemory

end



---------------------------------



--
-- based on PlayerJoinFix
--
-- SFM-Modding
-- @author:  Manuel Leithner
-- @date:    01/08/11
-- @version: v1.1
-- @history: v1.0 - initial implementation
--           v1.1 - adaption to courseplay
--

local modName = g_currentModName;
local Server_sendObjects_old = Server.sendObjects;

function Server:sendObjects(connection, x, y, z, viewDistanceCoeff)
	connection:sendEvent(CourseplayJoinFixEvent:new());
	courseplay:debug("server send objects",courseplay.DBG_MULTIPLAYER)

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
		courseplay.globalSettings:onWriteStream(streamId)
		
		--transfer courses
		local course_count = 0
		for _,_ in pairs(g_currentMission.cp_courses) do
			course_count = course_count + 1
		end
		print(string.format("\t### CourseplayMultiplayer: writing %d courses ", course_count ))
		streamDebugWriteInt32(streamId, course_count)
		for id, course in pairs(g_currentMission.cp_courses) do
			streamDebugWriteString(streamId, course.name)
			streamDebugWriteString(streamId, course.uid)
			streamDebugWriteString(streamId, course.type)
			streamDebugWriteInt32(streamId, course.id)
			streamDebugWriteInt32(streamId, course.parent)
			streamDebugWriteInt32(streamId, course.multiTools)
			if course.waypoints then
				streamDebugWriteInt32(streamId, #(course.waypoints))
				for w = 1, #(course.waypoints) do
					CourseEvent:writeWaypoint(streamId, course.waypoints[w])
				end
			else
				streamDebugWriteInt32(streamId, -1)
			end
		end
				
		local folderCount = 0
		for _,_ in pairs(g_currentMission.cp_folders) do
			folderCount = folderCount + 1
		end
		streamDebugWriteInt32(streamId, folderCount)
		print(string.format("\t### CourseplayMultiplayer: writing %d folders ", folderCount ))
		for id, folder in pairs(g_currentMission.cp_folders) do
			streamDebugWriteString(streamId, folder.name)
			streamDebugWriteString(streamId, folder.uid)
			streamDebugWriteString(streamId, folder.type)
			streamDebugWriteInt32(streamId, folder.id)
			streamDebugWriteInt32(streamId, folder.parent)
			streamDebugWriteBool(streamId, folder.virtual)
			streamDebugWriteBool(streamId, folder.autodrive)
		end
				
		local fieldsCount = 0
		for _, field in pairs(courseplay.fields.fieldData) do
			if field.isCustom then
				fieldsCount = fieldsCount+1
			end
		end
		streamDebugWriteInt32(streamId, fieldsCount)
		print(string.format("\t### CourseplayMultiplayer: writing %d custom fields ", fieldsCount))
		for id, course in pairs(courseplay.fields.fieldData) do
			if course.isCustom then
				streamDebugWriteString(streamId, course.name)
				streamDebugWriteInt32(streamId, course.numPoints)
				streamDebugWriteBool(streamId, course.isCustom)
				streamDebugWriteInt32(streamId, course.fieldNum)
				streamDebugWriteInt32(streamId, course.dimensions.minX)
				streamDebugWriteInt32(streamId, course.dimensions.maxX)
				streamDebugWriteInt32(streamId, course.dimensions.minZ)
				streamDebugWriteInt32(streamId, course.dimensions.maxZ)
				streamDebugWriteInt32(streamId, #(course.points))
				for p = 1, #(course.points) do
					streamDebugWriteFloat32(streamId, course.points[p].cx)
					streamDebugWriteFloat32(streamId, course.points[p].cy)
					streamDebugWriteFloat32(streamId, course.points[p].cz)
				end
			end
		end
	end;
end

function CourseplayJoinFixEvent:readStream(streamId, connection)
	if connection:getIsServer() then
		courseplay.globalSettings:onReadStream(streamId)

		local course_count = streamDebugReadInt32(streamId)
		print(string.format("\t### CourseplayMultiplayer: reading %d couses ", course_count ))
		g_currentMission.cp_courses = {}
		for i = 1, course_count do
			--courseplay:debug("got course", courseplay.DBG_COURSES);
			local course_name = streamDebugReadString(streamId)
			local courseUid = streamDebugReadString(streamId)
			local courseType = streamDebugReadString(streamId)
			local course_id = streamDebugReadInt32(streamId)
			local courseParent = streamDebugReadInt32(streamId)
			local courseMultiTools = streamDebugReadInt32(streamId)
			local wp_count = streamDebugReadInt32(streamId)
			local waypoints = {}
			if wp_count >= 0 then
				for w = 1, wp_count do
					--courseplay:debug("got waypoint", courseplay.DBG_COURSES);
					table.insert(waypoints, CourseEvent:readWaypoint(streamId))
				end
			else
				waypoints = nil
			end
			local course = { id = course_id, uid = courseUid, type = courseType, name = course_name, nameClean = courseplay:normalizeUTF8(course_name), waypoints = waypoints, parent = courseParent, multiTools = courseMultiTools  }
			g_currentMission.cp_courses[course_id] = course
			g_currentMission.cp_sorted = courseplay.courses:sort()
		end
		
		local folderCount = streamDebugReadInt32(streamId)
		print(string.format("\t### CourseplayMultiplayer: reading %d folders ", folderCount ))
		g_currentMission.cp_folders = {}
		for i = 1, folderCount do
			local folderName = streamDebugReadString(streamId)
			local folderUid = streamDebugReadString(streamId)
			local folderType = streamDebugReadString(streamId)
			local folderId = streamDebugReadInt32(streamId)
			local folderParent = streamDebugReadInt32(streamId)
			local folderVirtual = streamDebugReadBool(streamId)
			local folderAutoDrive = streamDebugReadBool(streamId)
			local folder = { id = folderId, uid = folderUid, type = folderType, name = folderName, nameClean = courseplay:normalizeUTF8(folderName), parent = folderParent, virtual = folderVirtual, autodrive = folderAutoDrive }
			g_currentMission.cp_folders[folderId] = folder
			g_currentMission.cp_sorted = courseplay.courses:sort(g_currentMission.cp_courses, g_currentMission.cp_folders, 0, 0)
		end
		
		local fieldsCount = streamDebugReadInt32(streamId)		
		print(string.format("\t### CourseplayMultiplayer: reading %d custom fields ", fieldsCount))
		courseplay.fields.fieldData = {}
		for i = 1, fieldsCount do
			local name = streamDebugReadString(streamId)
			local numPoints = streamDebugReadInt32(streamId)
			local isCustom = streamDebugReadBool(streamId)
			local fieldNum = streamDebugReadInt32(streamId)
			local minX = streamDebugReadInt32(streamId)
			local maxX = streamDebugReadInt32(streamId)
			local minZ = streamDebugReadInt32(streamId)
			local maxZ = streamDebugReadInt32(streamId)
			local ammountPoints = streamDebugReadInt32(streamId)
			local waypoints = {}
			for w = 1, ammountPoints do 
				local cx = streamDebugReadFloat32(streamId)
				local cy = streamDebugReadFloat32(streamId)
				local cz = streamDebugReadFloat32(streamId)
				local wp = { cx = cx, cy = cy, cz = cz}
				table.insert(waypoints, wp)
			end
			local field = { name = name, numPoints = numPoints, isCustom = isCustom, fieldNum = fieldNum, points = waypoints, dimensions = {minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ}}
			courseplay.fields.fieldData[fieldNum] = field
		end
		print("\t### CourseplayMultiplayer: courses/folders reading end")
	end;
end

function CourseplayJoinFixEvent:run(connection)
	--courseplay:debug("CourseplayJoinFixEvent Run function should never be called", courseplay.DBG_COURSES);
end;

---------------------------------

