WorkWidthSettingEvent = {};
local WorkWidthSettingEvent_mt = Class(WorkWidthSettingEvent, Event);

InitEventClass(WorkWidthSettingEvent, "WorkWidthSettingEvent");

function WorkWidthSettingEvent:emptyNew()
	local self = Event:new(WorkWidthSettingEvent_mt);
	self.className = "WorkWidthSettingEvent";
	return self;
end

---@param value number (float)
function WorkWidthSettingEvent:new(vehicle, parentName, name, value)
	courseplay:debugFormat(courseplay.DBG_MULTIPLAYER,
		"WorkWidthSettingEvent:new(%s, %s, %s, %.1f)",nameNum(vehicle), name, parentName, value)
	self.vehicle = vehicle
	self.parentName = parentName
	self.name = name
	self.value = value
	return self
end

-- deserialize received event
function WorkWidthSettingEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	self.parentName = streamReadString(streamId)
	self.name = streamReadString(streamId)
	self.value = streamReadFloat32(streamId)

	courseplay:debugFormat(courseplay.DBG_MULTIPLAYER, "WorkWidthSettingEvent:readStream(%s, %s, %s, %.1f)",
		nameNum(self.vehicle), self.name, self.parentName, self.value)

	self:run(connection)
end

-- serialize event
function WorkWidthSettingEvent:writeStream(streamId, connection)
	courseplay:debugFormat(courseplay.DBG_MULTIPLAYER,
		"WorkWidthSettingEvent:writeStream(%s, %s, %s, %.1f)",nameNum(self.vehicle), self.name, self.parentName, self.value)
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	streamWriteString(streamId, self.parentName)
	streamWriteString(streamId, self.name)
	streamWriteFloat32(streamId, self.value)
end

-- process received event
function WorkWidthSettingEvent:run(connection)
	courseplay:debugFormat(courseplay.DBG_MULTIPLAYER,
		"WorkWidthSettingEvent:run(%s, %s, %s, %.1f)",nameNum(self.vehicle), self.name, self.parentName, self.value)
	self.vehicle.cp[self.parentName][self.name]:setFromNetwork(self.value)

	if not connection:getIsServer() then
		courseplay:debugFormat(courseplay.DBG_MULTIPLAYER, ' -> Broadcasting received event')
		g_server:broadcastEvent(self, nil, connection, self.vehicle);
	end;
end

function WorkWidthSettingEvent.sendEvent(vehicle, parentName, name, value)
	if g_server ~= nil then
		courseplay:debugFormat(courseplay.DBG_MULTIPLAYER,
			"WorkWidthSettingEvent:sendEvent broadcast to clients (%s, %s, %s, %.1f)",nameNum(vehicle), name, parentName, value)

		g_server:broadcastEvent(WorkWidthSettingEvent:new(vehicle,parentName, name, value), nil, nil, vehicle);
	else
		courseplay:debugFormat(courseplay.DBG_MULTIPLAYER,
			"WorkWidthSettingEvent:sendEvent send to server (%s, %s, %s, %.1f)",nameNum(vehicle), name, parentName, value)

		g_client:getServerConnection():sendEvent(WorkWidthSettingEvent:new(vehicle,parentName, name, value));
	end;
end

