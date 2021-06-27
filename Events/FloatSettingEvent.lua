FloatSettingEvent = {};
FloatSettingEvent.TYPE_SETTING = 0
FloatSettingEvent.TYPE_GLOBAL = 1
FloatSettingEvent.TYPE_COURSEGENERATOR = 2
local FloatSettingEvent_mt = Class(FloatSettingEvent, Event);

InitEventClass(FloatSettingEvent, "FloatSettingEvent");

function FloatSettingEvent:emptyNew()
	local self = Event:new(FloatSettingEvent_mt);
	self.className = "FloatSettingEvent";
	return self;
end

function FloatSettingEvent:new(vehicle,parentName, name, value)
	courseplay:debug(string.format("FloatSettingEvent:new(%s, %s, %s, %s)",nameNum(vehicle), tostring(name),tostring(parentName), tostring(value)), courseplay.DBG_MULTIPLAYER)
	self.vehicle = nil
	self.vehicle = vehicle;
	self.parentName = parentName
	self.name = name
	self.value = value;
	return self;
end

function FloatSettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if streamReadBool(streamId) then
		courseplay:debug("vehicle specific Setting",courseplay.DBG_MULTIPLAYER)
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		courseplay:debug("global Setting",courseplay.DBG_MULTIPLAYER)
		self.vehicle = nil
	end
	self.parentName = streamReadString(streamId)
	self.name = streamReadString(streamId)
	self.value = streamReadFloat32(streamId)

	courseplay:debug("FloatSettingEvent:readStream()",courseplay.DBG_MULTIPLAYER)
	courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(nameNum(self.vehicle),tostring(self.parentName), tostring(self.name), tostring(self.value)), courseplay.DBG_MULTIPLAYER);

	self:run(connection);
end

function FloatSettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("FloatSettingEvent:writeStream()",courseplay.DBG_MULTIPLAYER)
	courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(nameNum(self.vehicle),tostring(self.parentName), tostring(self.name), tostring(self.value)), courseplay.DBG_MULTIPLAYER);
	if self.vehicle ~= nil then
		courseplay:debug("vehicle specific Setting",courseplay.DBG_MULTIPLAYER)
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		courseplay:debug("global Setting",courseplay.DBG_MULTIPLAYER)
		streamWriteBool(streamId, false)
	end
	streamWriteString(streamId, self.parentName)
	streamWriteString(streamId, self.name)
	streamWriteFloat32(streamId, self.value)
end

function FloatSettingEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("FloatSettingEvent:run()",courseplay.DBG_MULTIPLAYER)
	courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(nameNum(self.vehicle),tostring(self.parentName), tostring(self.name), tostring(self.value)), courseplay.DBG_MULTIPLAYER);

	if self.vehicle then 
		courseplay:debug("vehicle specific Setting",courseplay.DBG_MULTIPLAYER)
		self.vehicle.cp[self.parentName][self.name]:setFromNetwork(self.value)
	else
		courseplay:debug("global Setting",courseplay.DBG_MULTIPLAYER)
		courseplay[self.parentName][self.name]:setFromNetwork(self.value)
	end
	if not connection:getIsServer() then
		courseplay:debug("broadcast FloatSettingEvent",courseplay.DBG_MULTIPLAYER)
		g_server:broadcastEvent(FloatSettingEvent:new(self.vehicle,self.parentName, self.name, self.value), nil, connection, self.vehicle);
	end;
end

function FloatSettingEvent.sendEvent(vehicle,parentName, name, value)
	if g_server ~= nil then
		courseplay:debug("broadcast FloatSettingEvent", courseplay.DBG_MULTIPLAYER)
		courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(nameNum(vehicle), tostring(parentName), tostring(name), tostring(value)), courseplay.DBG_MULTIPLAYER);
		g_server:broadcastEvent(FloatSettingEvent:new(vehicle,parentName, name, value), nil, nil, vehicle);
	else
		courseplay:debug("send FloatSettingEvent", courseplay.DBG_MULTIPLAYER)
		courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(nameNum(vehicle), tostring(parentName),tostring(name), tostring(value)), courseplay.DBG_MULTIPLAYER);
		g_client:getServerConnection():sendEvent(FloatSettingEvent:new(vehicle,parentName, name, value));
	end;
end

