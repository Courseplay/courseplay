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
	courseplay:debug(string.format("courseplay:CourseplayEvent:new( %s, %s, %s)",tostring(func), tostring(value), tostring(page)), 5)
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
	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(self.vehicle).."/"..tostring(messageNumber).."  function: "..tostring(self.func).."  self.value: "..tostring(self.value).."  self.page: "..tostring(self.page).."  self.type: "..self.type, 5)

	self:run(connection);
end

function CourseplayEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(NetworkUtil.getObjectId(self.vehicle)).."/"..tostring(self.messageNumber).."  function: "..tostring(self.func).."  value: "..tostring(self.value).."  type: "..tostring(self.type).."  page: "..tostring(self.page), 5)
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
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, function=%s, value=%s'):format(tostring(self.vehicle), tostring(self.func), tostring(self.value)), 5);
	self.vehicle:setCourseplayFunc(self.func, self.value, true, self.page);
	if not connection:getIsServer() then
		courseplay:debug("broadcast event feedback",5)
		g_server:broadcastEvent(CourseplayEvent:new(self.vehicle, self.func, self.value, self.page), nil, connection, self.object);
	end;
end

function CourseplayEvent.sendEvent(vehicle, func, value, noEventSend, page) -- hilfsfunktion, die Events anst��te (wirde von setRotateDirection in der Spezi aufgerufen) 
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			courseplay:debug("broadcast event",5)
			courseplay:debug(('\tid=%s, function=%s, value=%s, page=%s'):format(tostring(vehicle), tostring(func), tostring(value), tostring(page)), 5);
			g_server:broadcastEvent(CourseplayEvent:new(vehicle, func, value, page), nil, nil, vehicle);
		else
			courseplay:debug("send event",5)
			courseplay:debug(('\tid=%s, function=%s, value=%s, page=%s'):format(tostring(vehicle), tostring(func), tostring(value), tostring(page)), 5);
			g_client:getServerConnection():sendEvent(CourseplayEvent:new(vehicle, func, value, page));
		end;
	end;
end

function courseplay:checkForChangeAndBroadcast(self, stringName, variable , variableMemory)
	if variable ~= variableMemory then
		courseplay:debug("checkForChangeAndBroadcast",5)
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
	courseplay:debug("server send objects",5)

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
		for name, setting in pairs(courseplay.globalSettings) do
			streamDebugWriteBool(streamId, true)
			streamDebugWriteString(streamId, name)
			streamDebugWriteInt32(streamId, setting.previous)
			streamDebugWriteInt32(streamId, setting.current)
		end
		streamDebugWriteBool(streamId, false)

		--courseplay:debug("manager transfering courses", 8);
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
					CoursePlayNetworkHelper:writeWaypoint(streamId, course.waypoints[w])
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
		while streamDebugReadBool(streamId) do
			local name = streamDebugReadString(streamId)
			local previous = streamDebugReadInt32(streamId)
			local value = streamDebugReadInt32(streamId)
			courseplay.globalSettings[name]:setFromNetwork(value)
			courseplay.globalSettings[name].previous = previous
		end

		local course_count = streamDebugReadInt32(streamId)
		print(string.format("\t### CourseplayMultiplayer: reading %d couses ", course_count ))
		g_currentMission.cp_courses = {}
		for i = 1, course_count do
			--courseplay:debug("got course", 8);
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
					--courseplay:debug("got waypoint", 8);
					table.insert(waypoints, CoursePlayNetworkHelper:readWaypoint(streamId))
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
	--courseplay:debug("CourseplayJoinFixEvent Run function should never be called", 8);
end;


---------------------------------



CourseplaySettingsSyncEvent = {};
local CourseplaySettingsSyncEvent_mt = Class(CourseplaySettingsSyncEvent, Event);

InitEventClass(CourseplaySettingsSyncEvent, "CourseplaySettingsSyncEvent");

function CourseplaySettingsSyncEvent:emptyNew()
	local self = Event:new(CourseplaySettingsSyncEvent_mt);
	self.className = "CourseplaySettingsSyncEvent";
	return self;
end

function CourseplaySettingsSyncEvent:new(vehicle, name, value)
	courseplay:debug(string.format("courseplay:CourseplaySettingsSyncEvent:new(%s, %s)", tostring(name), tostring(value)), 5)
	self.vehicle = vehicle;
	self.messageNumber = Utils.getNoNil(self.messageNumber, 0) + 1
	self.name = name
	self.value = value;
	return self;
end

function CourseplaySettingsSyncEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		self.vehicle = nil
	end
	local messageNumber = streamReadFloat32(streamId)
	self.name = streamReadString(streamId)
	self.value = streamReadInt32(streamId)

	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(self.vehicle).."/"..tostring(messageNumber).."  self.name: "..tostring(self.name).."  self.value: "..tostring(self.value),5)

	self:run(connection);
end

function CourseplaySettingsSyncEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(self.vehicle).."/"..tostring(self.messageNumber).."  self.name: "..tostring(self.name).."  value: "..tostring(self.value),5)

	if self.vehicle ~= nil then
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		streamWriteBool(streamId, false)
	end
	streamWriteFloat32(streamId, self.messageNumber)
	streamWriteString(streamId, self.name)
	streamWriteInt32(streamId, self.value)
end

function CourseplaySettingsSyncEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, name=%s, value=%s'):format(tostring(self.vehicle), tostring(self.name), tostring(self.value)), 5);

	if self.vehicle ~= nil then
		self.vehicle.cp.settings[self.name]:setFromNetwork(self.value)
	else
		courseplay.globalSettings[self.name]:setFromNetwork(self.value)
	end
	if not connection:getIsServer() then
		courseplay:debug("broadcast settings event feedback",5)
		g_server:broadcastEvent(CourseplaySettingsSyncEvent:new(self.vehicle, self.name, self.value), nil, connection, self.vehicle);
	end;
end

function CourseplaySettingsSyncEvent.sendEvent(vehicle, name, value)
	if g_server ~= nil then
		courseplay:debug("broadcast settings event", 5)
		courseplay:debug(('\tid=%s, name=%s, value=%s'):format(tostring(vehicle), tostring(name), tostring(value)), 5);
		g_server:broadcastEvent(CourseplaySettingsSyncEvent:new(vehicle, name, value), nil, nil, self);
	else
		courseplay:debug("send settings event", 5)
		courseplay:debug(('\tid=%s, name=%s, value=%s'):format(tostring(vehicle), tostring(name), tostring(value)), 5);
		g_client:getServerConnection():sendEvent(CourseplaySettingsSyncEvent:new(vehicle, name, value));
	end;
end

---------------------------------

function CoursePlayNetworkHelper:writeWaypoint(streamId, waypoint)
	streamDebugWriteFloat32(streamId, waypoint.cx)
	streamDebugWriteFloat32(streamId, waypoint.cz)
	streamDebugWriteFloat32(streamId, waypoint.angle)
	streamDebugWriteBool(streamId, waypoint.wait)
	streamDebugWriteBool(streamId, waypoint.rev)
	streamDebugWriteBool(streamId, waypoint.crossing)
	streamDebugWriteInt32(streamId, waypoint.speed)

	streamDebugWriteBool(streamId, waypoint.generated)
	
	streamDebugWriteBool(streamId, waypoint.turnStart)
	streamDebugWriteBool(streamId, waypoint.turnEnd)
	
	streamDebugWriteInt32(streamId, waypoint.ridgeMarker)
	
	streamDebugWriteInt32(streamId, waypoint.headlandHeightForTurn)

end;

function CoursePlayNetworkHelper:readWaypoint(streamId)
	local cx = streamDebugReadFloat32(streamId)
	local cz = streamDebugReadFloat32(streamId)
	local angle = streamDebugReadFloat32(streamId)
	local wait = streamDebugReadBool(streamId)
	local rev = streamDebugReadBool(streamId)
	local crossing = streamDebugReadBool(streamId)
	local speed = streamDebugReadInt32(streamId)

	local generated = streamDebugReadBool(streamId)
	--local dir = streamDebugReadString(streamId)
	local turnStart = streamDebugReadBool(streamId)
	local turnEnd = streamDebugReadBool(streamId)
	local ridgeMarker = streamDebugReadInt32(streamId)
	local headlandHeightForTurn = streamDebugReadInt32(streamId)

	local wp = {
		cx = cx, 
		cz = cz, 
		angle = angle, 
		wait = wait, 
		rev = rev, 
		crossing = crossing, 
		speed = speed,
		generated = generated,
		turnStart = turnStart,
		turnEnd = turnEnd,
		ridgeMarker = ridgeMarker,
		headlandHeightForTurn = headlandHeightForTurn
	};
	return wp;
end;

------------------------------

--This ia an huge desynchronized SyncTable that sends data from the Server to the Client
--A few of these variables should propably not be sync.



VariableSyncEvent = {};
local VariableSyncEvent_mt = Class(VariableSyncEvent, Event);

InitEventClass(VariableSyncEvent, "VariableSyncEvent");

function VariableSyncEvent:emptyNew()
	local self = Event:new(VariableSyncEvent_mt);
	self.className = "VariableSyncEvent";
	return self;
end

function VariableSyncEvent:new(vehicle, variableSyncTable)
	
	self.vehicle = vehicle
	self.variableSyncTable = variableSyncTable
	
	return self
end

function VariableSyncEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht	
	
	--[[
	variableTable =
		{
		[1] = { VariableType, VariableValue One, variable index }		   },
		[2] = { VariableType, VariableValue Two, variable index }
		...
		}
	]]--
	
	self.vehicle = NetworkUtil.readNodeObject(streamId);
	
	local variableSyncTable = {}	
	local indexQueue = 1
	while true do
		
		--VariableIndex
		local _variableIndex = streamReadInt16(streamId)
		
		if _variableIndex == 0 then 
			break
		end
	
		
		variableSyncTable[indexQueue]={}
		variableSyncTable[indexQueue][3] = _variableIndex
		
		--VariableType
		local variableType = streamReadIntN(streamId,2)
		variableSyncTable[indexQueue][1] = variableType
		
		if _variableIndex > 0 then 
			if variableType == 0 then
				local VariableValue = streamReadBool(streamId)
				variableSyncTable[indexQueue][2] = VariableValue
			--	print("Bool: "..tostring(VariableValue))
			elseif variableType == 1 then
				variableSyncTable[indexQueue][2] = streamReadInt32(streamId)
			elseif variableType == 2 then
				variableSyncTable[indexQueue][2] = streamReadFloat32(streamId)
			elseif variableType == 3 then
				variableSyncTable[indexQueue][2] = streamReadString(streamId)
			end			
		elseif _variableIndex < 0 then 
			variableSyncTable[indexQueue][2] = nil
		end
		if variableSyncTable[indexQueue][2] ~= nil then
		--	print("data 1: "..tostring(variableType).." data 2: "..tostring(variableSyncTable[indexQueue][2]).." data 3: ".._variableIndex.."type data[3]: "..type(_variableIndex))
				
		else 
		--	print("data 1: "..tostring(variableType).." data 2: "..tostring(variableSyncTable[indexQueue][2]).." data 3: ".._variableIndex.."type data[3]: "..type(_variableIndex))
		
		end
		
		
		indexQueue = indexQueue +1
    end


	
	--self:run(connection);
	VariableSyncEventHelper:getSyncVariables(self.vehicle, variableSyncTable)
end

function VariableSyncEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	

	--[[
	variableTable =
		{
		[1] = { VariableType, VariableValue One, variable index }		   },
		[2] = { VariableType, VariableValue Two, variable index }
		...
		}
	]]--

	--VariableSyncEventHelper:setSyncVariables(self.vehicle)
	
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
	
	for i, data in pairs(self.variableSyncTable) do
		
		
		--print("data 1: "..tostring(data[1]).." data 2: "..tostring(data[2]).." data 3: "..data[3].."type data[3]: "..type(data[3]))
		
		local VariableIndex = data[3]
		
		--VariableIndex 
		streamWriteInt16(streamId, VariableIndex)
		
		local VariableType = data[1]
		
		--VariableType
		
		
		local VariableValue = data[2]
		
		--VariableValue
		if VariableValue == nil then 
		--	print("is nil: "..tostring(VariableValue))
		else
			if data[1] == 0 then --"Bool"
				streamWriteIntN(streamId, 0,2)
				streamWriteBool(streamId, VariableValue)
			--	print("Bool: "..tostring(VariableValue))
			elseif data[1] == 1 then --"Int32"
				streamWriteIntN(streamId, 1,2)	
				streamWriteInt32(streamId, VariableValue)
			elseif data[1] == 2 then --"Float32"
				streamWriteIntN(streamId, 2,2)
				streamWriteFloat32(streamId, VariableValue)
			elseif data[1] == 3 then --"String"
				streamWriteIntN(streamId, 3,2)
				streamWriteString(streamId, VariableValue)
			else
			
			end
		end
    end
	streamWriteInt32(streamId, 0)
	
end

function VariableSyncEvent:run(connection) -- wir fuehren das empfangene event aus
	
	--VariableSyncEventHelper:getSyncVariables(self.vehicle, self.variableSyncTable)
	
--[[	if not connection:getIsServer() then
		courseplay:debug("broadcast settings event feedback",5)
		g_server:broadcastEvent(VariableSyncEvent:new(self.vehicle, firstSync), nil, connection, self.vehicle);
	end;
]]--
end

function VariableSyncEvent.sendEvent(vehicle, variableSyncTable)
	if g_server ~= nil then
		
		g_server:broadcastEvent(VariableSyncEvent:new(vehicle, variableSyncTable), nil, nil, vehicle);
	else
		
		g_client:getServerConnection():sendEvent(VariableSyncEvent:new(vehicle, variableSyncTable));
	end;
end

VariableSyncEventHelper = {}



function VariableSyncEventHelper:setSyncVariables(vehicle,firstSync)
	
	vehicle.SyncTableBool[1]=vehicle.cp.isChopper
	vehicle.SyncTableBool[2]=vehicle.cp.distanceCheck
	vehicle.SyncTableBool[3]=vehicle.cp.hasShovelStatePositions[2]
	vehicle.SyncTableBool[4]=vehicle.cp.hasShovelStatePositions[3]
	vehicle.SyncTableBool[5]=vehicle.cp.hasShovelStatePositions[4]
	vehicle.SyncTableBool[6]=vehicle.cp.hasShovelStatePositions[5]
	vehicle.SyncTableBool[7]=vehicle.cp.shovelPositionFromKey
	vehicle.SyncTableBool[8]=vehicle.cp.canDrive
	vehicle.SyncTableBool[9]=vehicle.cp.isRecording 
	vehicle.SyncTableBool[10]=vehicle.cp.recordingIsPaused
	vehicle.SyncTableBool[11]=vehicle.cp.isRecordingTurnManeuver
	if vehicle.cp.driver.isWaiting ~=nil then
		vehicle.SyncTableBool[12]=vehicle.cp.driver:isWaiting()
	else 
		vehicle.SyncTableBool[12]=false
	end
	if vehicle.cp.driver.getCanShowDriveOnButton ~=nil then
		vehicle.SyncTableBool[13]=vehicle.cp.driver:getCanShowDriveOnButton()
	else 
		vehicle.SyncTableBool[13]=false
	end
	vehicle.SyncTableBool[14]=vehicle.cp.driverPriorityUseFillLevel
	vehicle.SyncTableBool[15]=vehicle.cp.hudDriver.active
	vehicle.SyncTableBool[16]=vehicle.cp.isDriving
	vehicle.SyncTableBool[17]=vehicle.cp.speeds.useRecordingSpeed
	vehicle.SyncTableBool[18]=vehicle.cp.runCounterActive
	vehicle.SyncTableBool[19]=vehicle.cp.allwaysSearchFuel
	vehicle.SyncTableBool[20]=vehicle.cp.stopAtEnd
	vehicle.SyncTableBool[21]=vehicle.cp.automaticCoverHandling
	vehicle.SyncTableBool[22]=vehicle.cp.saveFuelOptionActive
	vehicle.SyncTableBool[23]=vehicle.cp.realisticDriving
	vehicle.SyncTableBool[24]=vehicle.cp.turnDiameterAutoMode
	vehicle.SyncTableBool[25]=vehicle.cp.turnOnField
	vehicle.SyncTableBool[26]=vehicle.cp.alignment.enabled
	vehicle.SyncTableBool[27]=vehicle.cp.convoyActive
	vehicle.SyncTableBool[28]=vehicle.cp.driveUnloadNow
	vehicle.SyncTableBool[29]=vehicle.cp.wantsCourseplayer
	vehicle.SyncTableBool[30]=vehicle.cp.combineOffsetAutoMode
	vehicle.SyncTableBool[31]=vehicle.cp.searchCombineAutomatically
	vehicle.SyncTableBool[32]=vehicle.cp.oppositeTurnMode
	vehicle.SyncTableBool[33]=vehicle.cp.hasFertilizerSowingMachine
	vehicle.SyncTableBool[34]=vehicle.cp.fertilizerEnabled
	vehicle.SyncTableBool[35]=vehicle.cp.hasUnloadingRefillingCourse
	vehicle.SyncTableBool[36]=vehicle.cp.automaticUnloadingOnField
	vehicle.SyncTableBool[37]=vehicle.cp.hasPlow
	vehicle.SyncTableBool[37]=vehicle.cp.plowFieldEdge
	vehicle.SyncTableBool[38]=vehicle.cp.shovelStopAndGo
	vehicle.SyncTableBool[39]=vehicle.cp.mode10.automaticSpeed 
	vehicle.SyncTableBool[40]=vehicle.cp.mode10.leveling
	vehicle.SyncTableBool[41]=vehicle.cp.mode10.searchCourseplayersOnly
	vehicle.SyncTableBool[42]=vehicle.cp.mode10.automaticHeigth
	vehicle.SyncTableBool[43]=vehicle.cp.mode10.drivingThroughtLoading
	vehicle.SyncTableBool[44]=CpManager.ingameMapIconActive
	vehicle.SyncTableBool[45]=CpManager.ingameMapIconShowName
	vehicle.SyncTableBool[46]=CpManager.ingameMapIconShowCourse
	vehicle.SyncTableBool[47]=CpManager.ingameMapIconShowText
	vehicle.SyncTableBool[48]=CpManager.ingameMapIconShowTextLoaded 	
	vehicle.SyncTableBool[49]=vehicle.cp.visualWaypointsStartEnd
	vehicle.SyncTableBool[50]=vehicle.cp.visualWaypointsAll
	vehicle.SyncTableBool[51]=vehicle.cp.visualWaypointsCrossing
	vehicle.SyncTableBool[52]=vehicle.cp.fieldEdge.customField.isCreated 
	vehicle.SyncTableBool[53]=vehicle.cp.fieldEdge.customField.selectedFieldNumExists
	vehicle.SyncTableBool[54]=vehicle.cp.fieldEdge.customField.show
	vehicle.SyncTableBool[55]=vehicle.cp.hud.openWithMouse
	vehicle.SyncTableBool[56]=vehicle.cp.drivingDirReverse
	vehicle.SyncTableBool[57]=vehicle.cp.hasStartingCorner
	vehicle.SyncTableBool[58]=vehicle.cp.hasStartingDirection
	vehicle.SyncTableBool[59]=vehicle.cp.hasValidCourseGenerationData
	vehicle.SyncTableBool[60]=vehicle.cp.returnToFirstPoint
	vehicle.SyncTableBool[61]=vehicle.cp.ridgeMarkersAutomatic
	vehicle.SyncTableBool[62]=vehicle.cp.tipperHasCover
	vehicle.SyncTableBool[63]=vehicle.cp.hasSowingMachine
	vehicle.SyncTableBool[64]=vehicle.cp.generationPosition.hasSavedPosition
	vehicle.SyncTableBool[65]=vehicle.cp.hasBaleLoader
	

	vehicle.SyncTableInt[1]=vehicle.cp.manualWorkWidth
	vehicle.SyncTableInt[2]=vehicle.cp.multiTools
	vehicle.SyncTableInt[3]=vehicle.cp.laneNumber
	vehicle.SyncTableInt[4]=vehicle.cp.waitTime
	vehicle.SyncTableInt[5]=vehicle.cp.siloSelectedFillType
	vehicle.SyncTableInt[6]=vehicle.cp.maxRunNumber
	vehicle.SyncTableInt[7]=vehicle.cp.convoy.number
	vehicle.SyncTableInt[8]=vehicle.cp.convoy.members
	vehicle.SyncTableInt[9]=vehicle.cp.driveOnAtFillLevel
	vehicle.SyncTableInt[10]=vehicle.cp.turnStage
	vehicle.SyncTableInt[11]=vehicle.cp.headland.reverseManeuverType
	vehicle.SyncTableInt[12]=courseplay.fields.numAvailableFields
	vehicle.SyncTableInt[13]=vehicle.cp.mode10.searchRadius
	vehicle.SyncTableInt[14]=vehicle.cp.fieldEdge.customField.fieldNum
	vehicle.SyncTableInt[15]=vehicle.cp.fieldEdge.selectedField.fieldNum
	vehicle.SyncTableInt[16]=vehicle.cp.mode
	vehicle.SyncTableInt[17]=vehicle.cp.drawCourseMode
	vehicle.SyncTableInt[18]=vehicle.cp.hudDriver.runCounter
	vehicle.SyncTableInt[19]=vehicle.cp.globalInfoTextLevel
	vehicle.SyncTableInt[20]=vehicle.cp.headland.numLanes
	vehicle.SyncTableInt[21]=vehicle.cp.headland.turnType
	vehicle.SyncTableInt[22]=vehicle.cp.startAtPoint
	vehicle.SyncTableInt[23]=vehicle.cp.coursePlayerNum
	vehicle.SyncTableInt[24]=vehicle.cp.hud.currentPage
	vehicle.SyncTableInt[25]=vehicle.cp.searchCombineOnField
	vehicle.SyncTableInt[26]=vehicle.cp.warningLightsMode
	vehicle.SyncTableInt[27]=vehicle.cp.startingCorner
	vehicle.SyncTableInt[28]=vehicle.cp.startingDirection
	vehicle.SyncTableInt[29]=vehicle.cp.generationPosition.fieldNum
--	vehicle.SyncTableInt[30]=vehicle.cp.waypointIndex	
--	vehicle.SyncTableInt[31]=vehicle.cp.numWaypoints
--	vehicle.SyncTableInt[32]=vehicle.cp.numCrossingPoints
--	vehicle.SyncTableInt[33]=vehicle.cp.numWaitPoints
	
	
	
	
	

	vehicle.SyncTableFloat[1]=vehicle.cp.speeds.turn
	vehicle.SyncTableFloat[2]=vehicle.cp.speeds.field
	vehicle.SyncTableFloat[3]=vehicle.cp.speeds.reverse
	vehicle.SyncTableFloat[4]=vehicle.cp.speeds.street
	vehicle.SyncTableFloat[5]=vehicle.cp.speeds.bunkerSilo
	vehicle.SyncTableFloat[6]=vehicle.cp.loadUnloadOffsetX
	vehicle.SyncTableFloat[7]=vehicle.cp.loadUnloadOffsetZ
	vehicle.SyncTableFloat[8]=vehicle.cp.turnDiameterAuto
	vehicle.SyncTableFloat[9]=vehicle.cp.turnDiameter
	vehicle.SyncTableFloat[10]=vehicle.cp.workWidth
	vehicle.SyncTableFloat[11]=vehicle.cp.laneOffset
	vehicle.SyncTableFloat[12]=vehicle.cp.toolOffsetX
	vehicle.SyncTableFloat[13]=vehicle.cp.toolOffsetZ
	vehicle.SyncTableFloat[14]=vehicle.cp.convoy.minDistance
	vehicle.SyncTableFloat[15]=vehicle.cp.convoy.maxDistance
	vehicle.SyncTableFloat[16]=vehicle.cp.convoy.distance
	vehicle.SyncTableFloat[17]=vehicle.cp.combineOffset
	vehicle.SyncTableFloat[18]=vehicle.cp.tipperOffset
	vehicle.SyncTableFloat[19]=vehicle.cp.followAtFillLevel
	vehicle.SyncTableFloat[20]=vehicle.cp.refillUntilPct
	vehicle.SyncTableFloat[21]=vehicle.cp.mode10.shieldHeight
	vehicle.SyncTableFloat[22]=vehicle.cp.fieldEdge.customField.points
	vehicle.SyncTableFloat[23]=vehicle.cp.generationPosition.x
	vehicle.SyncTableFloat[24]=vehicle.cp.generationPosition.z
	--vehicle.SyncTableFloat[25]=vehicle.cp.timeRemaining

--	vehicle.SyncTableString[1]=vehicle.cp.currentCourseName
--	vehicle.SyncTableString[2]=vehicle.cp.gitAdditionalText
--	vehicle.SyncTableString[3]=vehicle.cp.infoText
	
	--[[
	variableTable =
		{
		[1] = { VariableType, VariableValue One, variable index }		   },
		[2] = { VariableType, VariableValue Two, variable index }
		...
		}
	]]--
	if firstSync then 
		return
	end
	
	
	local variableSyncTable = {}
	local indexSyncTable = 1
	
	for i=1, #(vehicle.SyncTableBool) do
		if not vehicle.SyncTableBool[i] == vehicle.oldSyncTableBool[i] then 
			variableSyncTable[indexSyncTable]={}
			variableSyncTable[indexSyncTable][1] = 0--"Bool"
			if vehicle.SyncTableBool[i] == nil then
				variableSyncTable[indexSyncTable][2] = nil
				variableSyncTable[indexSyncTable][3] = i*(-1)
				vehicle.oldSyncTableBool[i]=nil
			else
				variableSyncTable[indexSyncTable][2] = vehicle.SyncTableBool[i]
				variableSyncTable[indexSyncTable][3] = i
				vehicle.oldSyncTableBool[i]=vehicle.SyncTableBool[i]
			end
			indexSyncTable = indexSyncTable +1 
		end
	end		
	for i=1, #(vehicle.SyncTableInt) do
		if not vehicle.SyncTableInt[i] == vehicle.oldSyncTableInt[i] then 
			variableSyncTable[indexSyncTable][1] = 1--"Int32"
			variableSyncTable[indexSyncTable]={}
			if vehicle.SyncTableInt[i] == nil then
				variableSyncTable[indexSyncTable][2] = nil
				variableSyncTable[indexSyncTable][3] = i*(-1)
				vehicle.oldSyncTableInt[i]=nil
			else
				variableSyncTable[indexSyncTable][2] = vehicle.SyncTableInt[i]
				variableSyncTable[indexSyncTable][3] = i
				vehicle.oldSyncTableInt[i]=vehicle.SyncTableInt[i]
			end
			indexSyncTable = indexSyncTable +1 
		end
	end	
	for i=1, #(vehicle.SyncTableFloat) do
		if not vehicle.SyncTableFloat[i] == vehicle.oldSyncTableFloat[i] then 
			variableSyncTable[indexSyncTable][1] = 2--"Float32"
			variableSyncTable[indexSyncTable]={}
			if vehicle.SyncTableFloat[i] == nil then
				variableSyncTable[indexSyncTable][2] = nil
				variableSyncTable[indexSyncTable][3] = i*(-1)
				vehicle.oldSyncTableFloat[i]=nil
			else
				variableSyncTable[indexSyncTable][2] = vehicle.SyncTableFloat[i]
				variableSyncTable[indexSyncTable][3] = i
				vehicle.oldSyncTableFloat[i]=vehicle.SyncTableFloat[i]
			end
			indexSyncTable = indexSyncTable +1 
		end
	end	
	for i=1, #(vehicle.SyncTableString) do
		if not vehicle.SyncTableString[i] == vehicle.oldSyncTableString[i] then 
			variableSyncTable[indexSyncTable][1] = 3--"String"
			variableSyncTable[indexSyncTable]={}
			if vehicle.SyncTableString[i] == nil then
				variableSyncTable[indexSyncTable][2] = nil
				variableSyncTable[indexSyncTable][3] = i*(-1)
				vehicle.oldSyncTableString[i]=vehicle.SyncTableString[i]
			else
				variableSyncTable[indexSyncTable][2] = vehicle.SyncTableString[i]
				variableSyncTable[indexSyncTable][3] = i
				vehicle.oldSyncTableString[i]=vehicle.SyncTableString[i] 
			end
			indexSyncTable = indexSyncTable +1 
		end
	end	
	if indexSyncTable >1 then
		VariableSyncEvent.sendEvent(vehicle,variableSyncTable)
	end
end

function VariableSyncEventHelper:getSyncVariables(vehicle, variableSyncTable,firstSync)
	if not firstSync then
		for i, data in pairs(variableSyncTable) do
		
			local variableIndex = data[3]
			
			if data[1] == 0 then --"Bool"
				if data[2] ~= nil then
					vehicle.SyncTableBool[variableIndex] = data[2]
					vehicle.oldSyncTableBool[variableIndex] = data[2]
				else
					vehicle.SyncTableBool[variableIndex] = nil
					vehicle.oldSyncTableBool[variableIndex] = nil
				end

			elseif data[1] == 1 then --"Int32"
				if data[2] ~= nil then
					vehicle.SyncTableInt[variableIndex] = data[2]
					vehicle.oldSyncTableInt[variableIndex] = data[2]
				else
					vehicle.SyncTableInt[variableIndex] = nil
					vehicle.oldSyncTableInt[variableIndex] = nil
				end
			elseif data[1] == 2 then --"Float32"
				if data[2] ~= nil then
					vehicle.SyncTableFloat[variableIndex] = data[2]
					vehicle.oldSyncTableFloat[variableIndex] = data[2]
				else
					vehicle.SyncTableFloat[variableIndex] = nil
					vehicle.oldSyncTableFloat[variableIndex] = nil
				end
			elseif data[1] == 3 then --"String"
				if data[2] ~= nil then
					vehicle.SyncTableString[variableIndex] = data[2]
					vehicle.oldSyncTableString[variableIndex] = data[2]
				else
					vehicle.SyncTableString[variableIndex] = nil
					vehicle.oldSyncTableString[variableIndex] = nil
				end
			end	
		end
	end
	vehicle.cp.isChopper = vehicle.SyncTableBool[1]
	vehicle.cp.distanceCheck = vehicle.SyncTableBool[2]
	vehicle.cp.hasShovelStatePositions[2] = vehicle.SyncTableBool[3]
	vehicle.cp.hasShovelStatePositions[3] = vehicle.SyncTableBool[4]
	vehicle.cp.hasShovelStatePositions[4] = vehicle.SyncTableBool[5]
	vehicle.cp.hasShovelStatePositions[5] = vehicle.SyncTableBool[6]
	vehicle.cp.shovelPositionFromKey = vehicle.SyncTableBool[7]
	vehicle.cp.canDrive = vehicle.SyncTableBool[8]
	vehicle.cp.isRecording = vehicle.SyncTableBool[9]
	vehicle.cp.recordingIsPaused = vehicle.SyncTableBool[10]
	vehicle.cp.isRecordingTurnManeuver = vehicle.SyncTableBool[11]
	vehicle.cp.hudDriver.isWaiting = vehicle.SyncTableBool[12]
	vehicle.cp.hudDriver.showDriveOnButton = vehicle.SyncTableBool[13]
	vehicle.cp.driverPriorityUseFillLevel = vehicle.SyncTableBool[14]
	vehicle.cp.hudDriver.active = vehicle.SyncTableBool[15]
	vehicle.cp.isDriving = vehicle.SyncTableBool[16]
	vehicle.cp.speeds.useRecordingSpeed = vehicle.SyncTableBool[17]
	vehicle.cp.runCounterActive = vehicle.SyncTableBool[18]
	vehicle.cp.allwaysSearchFuel = vehicle.SyncTableBool[19]
	vehicle.cp.stopAtEnd = vehicle.SyncTableBool[20]
	vehicle.cp.automaticCoverHandling = vehicle.SyncTableBool[21]
	vehicle.cp.saveFuelOptionActive = vehicle.SyncTableBool[22]
	vehicle.cp.realisticDriving = vehicle.SyncTableBool[23]
	vehicle.cp.turnDiameterAutoMode = vehicle.SyncTableBool[24]
	vehicle.cp.turnOnField = vehicle.SyncTableBool[25]
	vehicle.cp.alignment.enabled = vehicle.SyncTableBool[26]
	vehicle.cp.convoyActive = vehicle.SyncTableBool[27]
	vehicle.cp.driveUnloadNow = vehicle.SyncTableBool[28]
	vehicle.cp.wantsCourseplayer = vehicle.SyncTableBool[29]
	vehicle.cp.combineOffsetAutoMode = vehicle.SyncTableBool[30]
	vehicle.cp.searchCombineAutomatically = vehicle.SyncTableBool[31]
	vehicle.cp.oppositeTurnMode = vehicle.SyncTableBool[32]
	vehicle.cp.hasFertilizerSowingMachine = vehicle.SyncTableBool[33]
	vehicle.cp.fertilizerEnabled = vehicle.SyncTableBool[34]
	vehicle.cp.hasUnloadingRefillingCourse = vehicle.SyncTableBool[35]
	vehicle.cp.automaticUnloadingOnField = vehicle.SyncTableBool[36]
	vehicle.cp.hasPlow = vehicle.SyncTableBool[37]
	vehicle.cp.plowFieldEdge = vehicle.SyncTableBool[37]
	vehicle.cp.shovelStopAndGo = vehicle.SyncTableBool[38]
	vehicle.cp.mode10.automaticSpeed = vehicle.SyncTableBool[39]
	vehicle.cp.mode10.leveling = vehicle.SyncTableBool[40]
	vehicle.cp.mode10.searchCourseplayersOnly = vehicle.SyncTableBool[41]
	vehicle.cp.mode10.automaticHeigth = vehicle.SyncTableBool[42]
	vehicle.cp.mode10.drivingThroughtLoading = vehicle.SyncTableBool[43]
	CpManager.ingameMapIconActive = vehicle.SyncTableBool[44]
	CpManager.ingameMapIconShowName = vehicle.SyncTableBool[45]
	CpManager.ingameMapIconShowCourse = vehicle.SyncTableBool[46]
	CpManager.ingameMapIconShowText = vehicle.SyncTableBool[47]
	CpManager.ingameMapIconShowTextLoaded = vehicle.SyncTableBool[48] 	
	vehicle.cp.visualWaypointsStartEnd = vehicle.SyncTableBool[49]
	vehicle.cp.visualWaypointsAll = vehicle.SyncTableBool[50]
	vehicle.cp.visualWaypointsCrossing = vehicle.SyncTableBool[51]
	vehicle.cp.fieldEdge.customField.isCreated = vehicle.SyncTableBool[52]
	vehicle.cp.fieldEdge.customField.selectedFieldNumExists = vehicle.SyncTableBool[53]
	vehicle.cp.fieldEdge.customField.show = vehicle.SyncTableBool[54]
	vehicle.cp.hud.openWithMouse = vehicle.SyncTableBool[55]
	vehicle.cp.drivingDirReverse = vehicle.SyncTableBool[56]
	vehicle.cp.hasStartingCorner = vehicle.SyncTableBool[57]
	vehicle.cp.hasStartingDirection = vehicle.SyncTableBool[58]
	vehicle.cp.hasValidCourseGenerationData = vehicle.SyncTableBool[59]
	vehicle.cp.returnToFirstPoint = vehicle.SyncTableBool[60]
	vehicle.cp.ridgeMarkersAutomatic = vehicle.SyncTableBool[61]
	vehicle.cp.tipperHasCover = vehicle.SyncTableBool[62]
	vehicle.cp.hasSowingMachine = vehicle.SyncTableBool[63]
	vehicle.cp.generationPosition.hasSavedPositio = vehicle.SyncTableBool[64]
	vehicle.cp.hasBaleLoader = vehicle.SyncTableBool[65]


	vehicle.cp.manualWorkWidth = vehicle.SyncTableInt[1]
	vehicle.cp.multiTools = vehicle.SyncTableInt[2]
	vehicle.cp.laneNumber = vehicle.SyncTableInt[3]
	vehicle.cp.waitTime = vehicle.SyncTableInt[4]
	vehicle.cp.siloSelectedFillType = vehicle.SyncTableInt[5]
	vehicle.cp.maxRunNumber = vehicle.SyncTableInt[6]
	vehicle.cp.convoy.number = vehicle.SyncTableInt[7]
	vehicle.cp.convoy.members = vehicle.SyncTableInt[8]
	vehicle.cp.driveOnAtFillLevel = vehicle.SyncTableInt[9]
	vehicle.cp.turnStage = vehicle.SyncTableInt[10]
	vehicle.cp.headland.reverseManeuverType = vehicle.SyncTableInt[11]
	courseplay.fields.numAvailableFields = vehicle.SyncTableInt[12]
	vehicle.cp.mode10.searchRadius = vehicle.SyncTableInt[13]
	vehicle.cp.fieldEdge.customField.fieldNum = vehicle.SyncTableInt[14]
	vehicle.cp.fieldEdge.selectedField.fieldNum = vehicle.SyncTableInt[15]
	vehicle.cp.mode = vehicle.SyncTableInt[16]
	vehicle.cp.drawCourseMode = vehicle.SyncTableInt[17]
	vehicle.cp.hudDriver.runCounter = vehicle.SyncTableInt[18]
	vehicle.cp.globalInfoTextLevel = vehicle.SyncTableInt[19]
	vehicle.cp.headland.numLanes = vehicle.SyncTableInt[20]
	vehicle.cp.headland.turnType = vehicle.SyncTableInt[21]
	vehicle.cp.startAtPoint = vehicle.SyncTableInt[22]
	vehicle.cp.coursePlayerNum = vehicle.SyncTableInt[23]
	vehicle.cp.hud.currentPage = vehicle.SyncTableInt[24]
	vehicle.cp.searchCombineOnField = vehicle.SyncTableInt[25]
	vehicle.cp.warningLightsMode = vehicle.SyncTableInt[26]
	vehicle.cp.startingCorner = vehicle.SyncTableInt[27]
	vehicle.cp.startingDirection = vehicle.SyncTableInt[28]
	vehicle.cp.generationPosition.fieldNum = vehicle.SyncTableInt[29]
--	vehicle.cp.waypointIndex = vehicle.SyncTableInt[30]
--	vehicle.cp.numWaypoints = vehicle.SyncTableInt[31]
--	vehicle.cp.numCrossingPoints = vehicle.SyncTableInt[32]
--	vehicle.cp.numWaitPoints = vehicle.SyncTableInt[33]

	vehicle.cp.speeds.turn = vehicle.SyncTableFloat[1]
	vehicle.cp.speeds.field = vehicle.SyncTableFloat[2]
	vehicle.cp.speeds.reverse = vehicle.SyncTableFloat[3]
	vehicle.cp.speeds.street = vehicle.SyncTableFloat[4]
	vehicle.cp.speeds.bunkerSilo = vehicle.SyncTableFloat[5]
	vehicle.cp.loadUnloadOffsetX = vehicle.SyncTableFloat[6]
	vehicle.cp.loadUnloadOffsetZ = vehicle.SyncTableFloat[7]
	vehicle.cp.turnDiameterAuto = vehicle.SyncTableFloat[8]
	vehicle.cp.turnDiameter = vehicle.SyncTableFloat[9]
	vehicle.cp.workWidth = vehicle.SyncTableFloat[10]
	vehicle.cp.laneOffset = vehicle.SyncTableFloat[11]
	vehicle.cp.toolOffsetX = vehicle.SyncTableFloat[12]
	vehicle.cp.toolOffsetZ = vehicle.SyncTableFloat[13]
	vehicle.cp.convoy.minDistance = vehicle.SyncTableFloat[14]
	vehicle.cp.convoy.maxDistance = vehicle.SyncTableFloat[15]
	vehicle.cp.convoy.distance = vehicle.SyncTableFloat[16]
	vehicle.cp.combineOffset = vehicle.SyncTableFloat[17]
	vehicle.cp.tipperOffset = vehicle.SyncTableFloat[18]
	vehicle.cp.followAtFillLevel = vehicle.SyncTableFloat[19]
	vehicle.cp.refillUntilPct = vehicle.SyncTableFloat[20]
	vehicle.cp.mode10.shieldHeight = vehicle.SyncTableFloat[21]
	vehicle.cp.fieldEdge.customField.points = vehicle.SyncTableFloat[22]
	vehicle.cp.generationPosition.x = vehicle.SyncTableFloat[23]
	vehicle.cp.generationPosition.z = vehicle.SyncTableFloat[24]
	--vehicle.cp.timeRemaining = vehicle.SyncTableFloat[25]

--	vehicle.cp.currentCourseName = vehicle.SyncTableString[1]
--	vehicle.cp.gitAdditionalText = vehicle.SyncTableString[2]
--	vehicle.cp.infoText = vehicle.SyncTableString[3]


	
end


--This Event is used to give the Server the ability to send Hud Commands to everyone,
--without the Client having access to The AIDriver Code

HudContentEvent = {};
local HudContentEvent_mt = Class(HudContentEvent, Event);

InitEventClass(HudContentEvent, "HudContentEvent");

function HudContentEvent:emptyNew()
	local self = Event:new(HudContentEvent_mt);
	self.className = "HudContentEvent";
	return self;
end

function HudContentEvent:new(vehicle, setContent)

	self.vehicle = vehicle
	self.setContent = setContent
	return self
end

function HudContentEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	
	self.setContent = streamReadInt8(streamId)
	
	self:run(connection);
end

function HudContentEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	
	streamWriteInt8(streamId, self.setContent)
	
end

function HudContentEvent:run(connection) -- wir fuehren das empfangene event aus
	
	if self.setContent == 0 then
		courseplay.hud:setAIDriverContent(self.vehicle)
	elseif self.setContent == 1 then
		courseplay.hud:setGrainTransportAIDriverContent(self.vehicle)
	elseif self.setContent == 2 then
		courseplay.hud:setFieldWorkAIDriverContent(self.vehicle)
	elseif self.setContent == 3 then
		courseplay.hud:setUnloadableFieldworkAIDriverContent(self.vehicle)
	elseif self.setContent == 4 then
		courseplay.hud:setCombineAIDriverContent(self.vehicle)
	elseif self.setContent == 5 then
		courseplay.hud:setCombineUnloadAIDriverContent(self.vehicle)
	elseif self.setContent == 6 then
		courseplay.hud:setFieldSupplyAIDriverContent(self.vehicle)
	elseif self.setContent == 7 then
		courseplay.hud:setShovelModeAIDriverContent(self.vehicle)
	elseif self.setContent == 8 then
		courseplay.hud:setLevelCompactAIDriverContent(self.vehicle)
	elseif self.setContent == 9 then
		courseplay.hud:setBaleLoaderAIDriverContent(self.vehicle)
	elseif self.setContent == 10 then
		courseplay.hud:setFillableFieldworkAIDriverContent(self.vehicle)
	elseif self.setContent == 11 then
		courseplay.hud:setReloadPageOrder(self.vehicle, self.vehicle.cp.hud.currentPage, true)
	elseif self.setContent == 12 then
	--	courseplay.hud:setReloadPageOrder(self.vehicle, 1 , true);
	end
	
end

function HudContentEvent.sendEvent(vehicle, setContent)
	if g_server ~= nil then
		
		g_server:broadcastEvent(HudContentEvent:new(vehicle, setContent), nil, nil, vehicle);
	else
		
	--	g_client:getServerConnection():sendEvent(HudContentEvent:new(vehicle, setContent));
	end;
end

--Not Used/Working for now 

WaypointSyncEvent = {};
local WaypointSyncEvent_mt = Class(WaypointSyncEvent, Event);

InitEventClass(WaypointSyncEvent, "WaypointSyncEvent");

function WaypointSyncEvent:emptyNew()
	local self = Event:new(WaypointSyncEvent_mt);
	self.className = "WaypointSyncEvent";
	return self;
end

function WaypointSyncEvent:new(vehicle)

	self.vehicle = vehicle
		
	
	return self
end

function WaypointSyncEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	
	local wp_count = streamDebugReadInt32(streamId)
	if wp_count >= 0 then
		for w = 1, wp_count do
			--courseplay:debug("got waypoint", 8);
			local wpoint = CoursePlayNetworkHelper:readWaypoint(streamId)
			self.vehicle.Waypoints = {}
			self.vehicle.oldWaypoints = {}
			table.insert(self.vehicle.Waypoints, wpoint)
			table.insert(self.vehicle.oldWaypoints, wpoint)
		end
	else
		
	end
	
	self:run(connection);
end

function WaypointSyncEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	
	if  #(self.vehicle.waypoints) >0 and self.vehicle.waypoints~=nil then
		streamDebugWriteInt32(streamId, #(self.vehicle.waypoints))
		for w = 1, #(self.vehicle.waypoints) do
			CoursePlayNetworkHelper:writeWaypoint(streamId, self.vehicle.waypoints[w])
			self.vehicle.oldWaypoints = {}
			table.insert(self.vehicle.oldWaypoints, self.vehicle.waypoints[w])
		end
	else
		streamDebugWriteInt32(streamId, -1)
	end
	
	
end

function WaypointSyncEvent:run(connection) -- wir fuehren das empfangene event aus
	
	
	
end

function WaypointSyncEvent.sendEvent(vehicle)
	if g_server ~= nil then
		
		g_server:broadcastEvent(WaypointSyncEvent:new(vehicle), nil, nil, vehicle);
	else
		
		g_client:getServerConnection():sendEvent(WaypointSyncEvent:new(vehicle));
	end;
end

--WIP

ReloadVehicleCoursesEvent = {};
local ReloadVehicleCoursesEvent_mt = Class(ReloadVehicleCoursesEvent, Event);

InitEventClass(ReloadVehicleCoursesEvent, "ReloadVehicleCoursesEvent");

function ReloadVehicleCoursesEvent:emptyNew()
	local self = Event:new(ReloadVehicleCoursesEvent_mt);
	self.className = "ReloadVehicleCoursesEvent";
	return self;
end

function ReloadVehicleCoursesEvent:new(vehicle)

	self.vehicle = vehicle
		
	return self
end

function ReloadVehicleCoursesEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	
	
	
	self:run(connection);
end

function ReloadVehicleCoursesEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	
	
	
end

function ReloadVehicleCoursesEvent:run(connection) -- wir fuehren das empfangene event aus
	
	courseplay.courses:reloadVehicleCourses(self.vehicle)
	
end

function ReloadVehicleCoursesEvent.sendEvent(vehicle)
	if g_server ~= nil then
		
		g_server:broadcastEvent(ReloadVehicleCoursesEvent:new(vehicle), nil, nil, vehicle);
	else
		
		g_client:getServerConnection():sendEvent(ReloadVehicleCoursesEvent:new(vehicle));
	end;
end