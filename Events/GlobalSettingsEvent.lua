
GlobalSettingsEvent = {};
local GlobalSettingsEvent_mt = Class(GlobalSettingsEvent, Event);
InitEventClass(GlobalSettingsEvent, "GlobalSettingsEvent");
function GlobalSettingsEvent:emptyNew()
	local self = Event:new(GlobalSettingsEvent_mt);
	self.className = "GlobalSettingsEvent";
	return self;
end

function GlobalSettingsEvent:new(parentName, name, value)
	courseplay:debug(string.format("GlobalSettingsEvent:new %s, %s, %s)", tostring(parentName),tostring(name), tostring(value)), 5)
	self.parentName = parentName
	self.name = name
	self.value = value;
	return self;
end

function GlobalSettingsEvent:writeStream(streamId, connection)
	courseplay:debug("SettingsListEvent:writeStream()",5)
	courseplay:debug(('parentName:%s, name:%s, value:%s'):format(tostring(self.parentName), tostring(self.name), tostring(self.value)), 5);

	streamWriteString(streamId, self.parentName)
	streamWriteString(streamId, self.name)
	streamWriteInt32(streamId, self.value)
end

function GlobalSettingsEvent:readStream(streamId, connection)
	self.parentName = streamReadString(streamId)
	self.name = streamReadString(streamId)
	self.value = streamReadInt32(streamId)

	courseplay:debug("GlobalSettingsEvent:readStream()",5)
	courseplay:debug(('parentName:%s, name:%s, value:%s'):format(tostring(self.parentName), tostring(self.name), tostring(self.value)), 5);
	
	self:run(connection)
end

function GlobalSettingsEvent:run(connection)
	courseplay:debug("GlobalSettingsEvent:run()",5)
	courseplay:debug(('parentName:%s, name:%s, value:%s'):format(tostring(self.parentName), tostring(self.name), tostring(self.value)), 5);
	courseplay[self.parentName][self.name]:setFromNetwork(self.value)

	if not connection:getIsServer() then
		courseplay:debug("broadcast GlobalSettingsEvent",5)
		g_server:broadcastEvent(GlobalSettingsEvent:new(self.parentName, self.name, self.value), nil, connection);
	end;
end

function GlobalSettingsEvent.sendEvent(parentName, name, value)
	if g_server == nil then
		courseplay:debug("send GlobalSettingsEvent", 5)
		courseplay:debug(('parentName:%s, name:%s, value:%s'):format(tostring(parentName), tostring(name), tostring(value)), 5);
		g_client:getServerConnection():sendEvent(GlobalSettingsEvent:new(parentName, name, value))
	else 
		courseplay:debug("broadcast GlobalSettingsEvent", 5)
		courseplay:debug(('parentName:%s, name:%s, value:%s'):format(tostring(parentName), tostring(name), tostring(value)), 5);
		g_server:broadcastEvent(GlobalSettingsEvent:new(parentName, name, value))
	end
end