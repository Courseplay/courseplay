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
	streamDebugWriteFloat32(streamId, self.messageNumber);
	streamDebugWriteString(streamId, self.func);
	if self.page == "global" then
		self.page = 999
	elseif self.page == true then
		self.page = 998
	elseif self.page == false then
		self.page = 997
	elseif self.page == nil then
		self.page = 996
	end
	streamDebugWriteInt32(streamId, self.page);
	streamDebugWriteString(streamId, self.type);
	if self.type == "boolean" then
		streamDebugWriteBool(streamId, self.value);
	elseif self.type == "string" then
		streamDebugWriteString(streamId, self.value);
	elseif self.type == "nil" then
		streamDebugWriteString(streamId, "nil");
	elseif self.type == "waypointList" then
		streamDebugWriteInt32(streamId, #(self.value))
		for w = 1, #(self.value) do
			CoursePlayNetworkHelper:writeWaypoint(streamId, self.value[w])
		end
	else
		streamDebugWriteFloat32(streamId, self.value);
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
CourseplayJoinFixEvent.mpDebugActive = false

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
			self:debugWrite(course.name,"course name")
			streamDebugWriteString(streamId, course.uid)
			self:debugWrite(course.uid,"course uid")
			streamDebugWriteString(streamId, course.type)
			self:debugWrite(course.type,"course type")
			streamDebugWriteInt32(streamId, course.id)
			self:debugWrite(course.id,"course id")
			streamDebugWriteInt32(streamId, course.parent)
			self:debugWrite(course.parent,"course parent")
			streamDebugWriteInt32(streamId, course.multiTools)
			self:debugWrite(course.multiTools,"course multiTools")
			if course.waypoints then
				streamDebugWriteInt32(streamId, #(course.waypoints))
				self:debugWrite(#(course.waypoints),"course numWaypoints")
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
			self:debugWrite(folder.name,"folder name")
			streamDebugWriteString(streamId, folder.uid)
			self:debugWrite(folder.uid,"folder uid")
			streamDebugWriteString(streamId, folder.type)
			self:debugWrite(folder.type,"folder type")
			streamDebugWriteInt32(streamId, folder.id)
			self:debugWrite(folder.id,"folder id")
			streamDebugWriteInt32(streamId, folder.parent)
			self:debugWrite(folder.parent,"folder parent")
			streamDebugWriteBool(streamId, folder.virtual)
			self:debugWrite(folder.virtual,"folder virtual")
			streamDebugWriteBool(streamId, folder.autodrive)
			self:debugWrite(folder.autodrive,"folder autodrive")
		end		
		local fieldsCount = 0
		for _, field in pairs(courseplay.fields.fieldData) do
			if field.isCustom then
				fieldsCount = fieldsCount+1
			end
		end
		streamDebugWriteInt32(streamId, fieldsCount)
		print(string.format("\t### CourseplayMultiplayer: writing %d custom fields ", fieldsCount))
		for id, field in pairs(courseplay.fields.fieldData) do
			if field.isCustom then
				CustomFieldEvent.writeField(field,streamId)
			end
		end
	end;
end

function CourseplayJoinFixEvent:readStream(streamId, connection)
	if connection:getIsServer() then
		courseplay.globalSettings:onReadStream(streamId)
		local course_count = streamReadInt32(streamId)
		print(string.format("\t### CourseplayMultiplayer: reading %d couses ", course_count ))
		g_currentMission.cp_courses = {}
		for i = 1, course_count do
			--courseplay:debug("got course", courseplay.DBG_COURSES);
			local course_name = streamReadString(streamId)
			self:debugRead(course_name,"course name")
			local courseUid = streamReadString(streamId)
			self:debugRead(courseUid,"course uid")
			local courseType = streamReadString(streamId)
			self:debugRead(courseType,"course type")
			local course_id = streamReadInt32(streamId)
			self:debugRead(course_id,"course id")
			local courseParent = streamReadInt32(streamId)
			self:debugRead(courseParent,"course parent")
			local courseMultiTools = streamReadInt32(streamId)
			self:debugRead(courseMultiTools,"course multi tools")
			local wp_count = streamReadInt32(streamId)
			self:debugRead(wp_count,"course waypoint amount")
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
		local folderCount = streamReadInt32(streamId)
		print(string.format("\t### CourseplayMultiplayer: reading %d folders ", folderCount ))
		g_currentMission.cp_folders = {}
		for i = 1, folderCount do
			local folderName = streamReadString(streamId)
			self:debugRead(folderName,"folder name")
			local folderUid = streamReadString(streamId)
			self:debugRead(folderUid,"folder uid")
			local folderType = streamReadString(streamId)
			self:debugRead(folderType,"folder type")
			local folderId = streamReadInt32(streamId)
			self:debugRead(folderId,"folder id")
			local folderParent = streamReadInt32(streamId)
			self:debugRead(folderParent,"folder parent")
			local folderVirtual = streamReadBool(streamId)
			self:debugRead(folderVirtual,"folder virtual")
			local folderAutoDrive = streamReadBool(streamId)
			self:debugRead(folderAutoDrive,"folder is auto drive")
			local folder = { id = folderId, uid = folderUid, type = folderType, name = folderName, nameClean = courseplay:normalizeUTF8(folderName), parent = folderParent, virtual = folderVirtual, autodrive = folderAutoDrive }
			g_currentMission.cp_folders[folderId] = folder
			g_currentMission.cp_sorted = courseplay.courses:sort(g_currentMission.cp_courses, g_currentMission.cp_folders, 0, 0)
		end
		local fieldsCount = streamReadInt32(streamId)		
		print(string.format("\t### CourseplayMultiplayer: reading %d custom fields ", fieldsCount))
		courseplay.fields.fieldData = {}
		for i = 1, fieldsCount do
			local field = CustomFieldEvent.readField(streamId)
			courseplay.fields.fieldData[field.fieldNum] = field
		end
		print("\t### CourseplayMultiplayer: courses/folders reading end")
	end;
end

function CourseplayJoinFixEvent:debug(str,...)
---	if courseplay.debugChannels[courseplay.DBG_MULTIPLAYER] then 
---		courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,...)
---	end
	if self.mpDebugActive then 
		print(string.format(str,...))
	end
end

function CourseplayJoinFixEvent:debugWrite(value,valueName)
	self:debug("Stream write, %s: %s ",valueName,tostring(value))
end

function CourseplayJoinFixEvent:debugRead(value,valueName)
	self:debug("Stream read, %s: %s ",valueName,tostring(value))
end
function CourseplayJoinFixEvent:run(connection)
	--courseplay:debug("CourseplayJoinFixEvent Run function should never be called", courseplay.DBG_COURSES);
end;

---------------------------------

