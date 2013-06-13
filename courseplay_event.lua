CourseplayEvent = {};
CourseplayEvent_mt = Class(CourseplayEvent, Event);

InitEventClass(CourseplayEvent, "CourseplayEvent");

function CourseplayEvent:emptyNew()
	courseplay:debug("recieve new event",5)
	local self = Event:new(CourseplayEvent_mt);
	self.className = "CourseplayEvent";
	return self;
end

function CourseplayEvent:new(vehicle, func, value)
	self.vehicle = vehicle;
	self.func = func
	self.value = value;
	self.type = type(value)
	return self;
end

function CourseplayEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	local id = streamReadInt32(streamId);
	self.vehicle = networkGetObject(id);
	self.func = streamReadString(streamId);
	self.type = streamReadString(streamId);
	if self.type == "boolean" then
		self.value = streamReadBool(streamId);
	elseif self.type == "nil" then
		self.value = nil
	else 
		self.value = streamReadFloat32(streamId);
	end
	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(networkGetObjectId(self.vehicle).."  function: "..tostring(self.func).."  self.value: "..tostring(self.value).."  self.type: "..tostring(self.type)),5)

	self:run(connection);
end

function CourseplayEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(networkGetObjectId(self.vehicle).."  function: "..tostring(self.func).."  value: "..tostring(self.value).."  type: "..tostring(self.type)),5)
	streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteString(streamId, self.func);
	streamWriteString(streamId, self.type);
	if self.type == "boolean" then
		streamWriteBool(streamId, self.value);
	else
		streamWriteFloat32(streamId, self.value);
	end
end

function CourseplayEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("			run",5)
	courseplay:debug("				id: "..tostring(networkGetObjectId(self.vehicle).."  function: "..tostring(self.func).."  value: "..tostring(self.value)),5)
	self.vehicle:setCourseplayFunc(self.func, self.value, true);
	if not connection:getIsServer() then
		courseplay:debug("broadcast event feedback",5)
		g_server:broadcastEvent(CourseplayEvent:new(self.vehicle, self.func, self.value), nil, connection, self.object);
	end;
end

function CourseplayEvent.sendEvent(vehicle, func, value, noEventSend) -- hilfsfunktion, die Events anst��te (wirde von setRotateDirection in der Spezi aufgerufen) 
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			courseplay:debug("broadcast event",5)
			courseplay:debug("	id: "..tostring(networkGetObjectId(vehicle).."  function: "..tostring(func).."  value: "..tostring(value)),5)
			g_server:broadcastEvent(CourseplayEvent:new(vehicle, func, value), nil, nil, vehicle);
		else
			courseplay:debug("send event",5)
			courseplay:debug("	id: "..tostring(networkGetObjectId(vehicle).."  function: "..tostring(func).."  value: "..tostring(value)),5)
			g_client:getServerConnection():sendEvent(CourseplayEvent:new(vehicle, func, value));
		end;
	end;
end

