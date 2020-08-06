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
	courseplay:debug(string.format("courseplay:SettingsListEvent:new(%s, %s)", tostring(name), tostring(value)), 5)
	self.vehicle = vehicle;
	self.parentName = parentName
	self.messageNumber = Utils.getNoNil(self.messageNumber, 0) + 1
	self.name = name
	self.value = value;
	return self;
end

function SettingsListEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		self.vehicle = nil
	end
	self.parentName = streamReadString(streamId)
	local messageNumber = streamReadFloat32(streamId)
	self.name = streamReadString(streamId)
	self.value = streamReadInt32(streamId)

	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(self.vehicle).."/"..tostring(messageNumber).."  self.name: "..tostring(self.name).."  self.value: "..tostring(self.value),5)

	self:run(connection);
end

function SettingsListEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(self.vehicle).."/"..tostring(self.messageNumber).."  self.name: "..tostring(self.name).."  value: "..tostring(self.value),5)

	if self.vehicle ~= nil then
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		streamWriteBool(streamId, false)
	end
	streamWriteString(streamId, self.parentName)
	streamWriteFloat32(streamId, self.messageNumber)
	streamWriteString(streamId, self.name)
	streamWriteInt32(streamId, self.value)
end

function SettingsListEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, name=%s, value=%s'):format(tostring(self.vehicle), tostring(self.name), tostring(self.value)), 5);

	if self.vehicle then 
		self.vehicle.cp[self.parentName][self.name]:setFromNetwork(self.value)
	else
		courseplay[self.parentName][self.name]:setFromNetwork(self.value)
	end
	if not connection:getIsServer() then
		courseplay:debug("broadcast settings event feedback",5)
		g_server:broadcastEvent(SettingsListEvent:new(self.vehicle, self.name, self.value), nil, connection, self.vehicle);
	end;
end

function SettingsListEvent.sendEvent(vehicle,parentName, name, value)
	if g_server ~= nil then
		courseplay:debug("broadcast settings event", 5)
		courseplay:debug(('\tid=%s, name=%s, value=%s'):format(tostring(vehicle), tostring(name), tostring(value)), 5);
		g_server:broadcastEvent(SettingsListEvent:new(vehicle,parentName, name, value), nil, nil, self);
	else
		courseplay:debug("send settings event", 5)
		courseplay:debug(('\tid=%s, name=%s, value=%s'):format(tostring(vehicle), tostring(name), tostring(value)), 5);
		g_client:getServerConnection():sendEvent(SettingsListEvent:new(vehicle,parentName, name, value));
	end;
end

