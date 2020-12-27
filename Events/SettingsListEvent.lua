SettingsListEvent = {};
SettingsListEvent.TYPE_SETTING = 0
SettingsListEvent.TYPE_GLOBAL = 1
SettingsListEvent.TYPE_COURSEGENERATOR = 2
local SettingsListEvent_mt = Class(SettingsListEvent, Event);

InitEventClass(SettingsListEvent, "SettingsListEvent");

function SettingsListEvent:emptyNew()
	local self = Event:new(SettingsListEvent_mt);
	self.className = "SettingsListEvent";
	return self;
end

function SettingsListEvent:new(vehicle,parentName, name, value)
	courseplay:debug(string.format("SettingsListEvent:new(%s, %s, %s, %s)",tostring(vehicle), tostring(name),tostring(parentName), tostring(value)), 5)
	self.vehicle = nil
	self.vehicle = vehicle;
	self.parentName = parentName
	self.name = name
	self.value = value;
	return self;
end

function SettingsListEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if streamReadBool(streamId) then
		courseplay:debug("vehicle specific Setting",5)
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		courseplay:debug("global Setting",5)
		self.vehicle = nil
	end
	self.parentName = streamReadString(streamId)
	self.name = streamReadString(streamId)
	self.value = streamReadInt32(streamId)

	courseplay:debug("SettingsListEvent:readStream()",5)
	courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(tostring(self.vehicle),tostring(self.parentName), tostring(self.name), tostring(self.value)), 5);

	self:run(connection);
end

function SettingsListEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("SettingsListEvent:writeStream()",5)
	courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(tostring(self.vehicle),tostring(self.parentName), tostring(self.name), tostring(self.value)), 5);
	if self.vehicle ~= nil then
		courseplay:debug("vehicle specific Setting",5)
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		courseplay:debug("global Setting",5)
		streamWriteBool(streamId, false)
	end
	streamWriteString(streamId, self.parentName)
	streamWriteString(streamId, self.name)
	streamWriteInt32(streamId, self.value)
end

function SettingsListEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("SettingsListEvent:run()",5)
	courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(tostring(self.vehicle),tostring(self.parentName), tostring(self.name), tostring(self.value)), 5);

	if self.vehicle then 
		courseplay:debug("vehicle specific Setting",5)
		self.vehicle.cp[self.parentName][self.name]:setFromNetwork(self.value)
	else
		courseplay:debug("global Setting",5)
		courseplay[self.parentName][self.name]:setFromNetwork(self.value)
	end
	if not connection:getIsServer() then
		courseplay:debug("broadcast SettingsListEvent",5)
		g_server:broadcastEvent(SettingsListEvent:new(self.vehicle,self.parentName, self.name, self.value), nil, connection, self.vehicle);
	end;
end

function SettingsListEvent.sendEvent(vehicle,parentName, name, value)
	if g_server ~= nil then
		courseplay:debug("broadcast SettingsListEvent", 5)
		courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(tostring(vehicle), tostring(parentName), tostring(name), tostring(value)), 5);
		g_server:broadcastEvent(SettingsListEvent:new(vehicle,parentName, name, value), nil, nil, vehicle);
	else
		courseplay:debug("send SettingsListEvent", 5)
		courseplay:debug(('vehicle:%s, parentName:%s, name:%s, value:%s'):format(tostring(vehicle), tostring(parentName),tostring(name), tostring(value)), 5);
		g_client:getServerConnection():sendEvent(SettingsListEvent:new(vehicle,parentName, name, value));
	end;
end

