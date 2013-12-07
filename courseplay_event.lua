CourseplayEvent = {};
CourseplayEvent_mt = Class(CourseplayEvent, Event);

InitEventClass(CourseplayEvent, "CourseplayEvent");

function CourseplayEvent:emptyNew()
	courseplay:debug("recieve new event",5)
	local self = Event:new(CourseplayEvent_mt);
	self.className = "CourseplayEvent";
	return self;
end

function CourseplayEvent:new(vehicle, func, value, page)
	self.vehicle = vehicle;
	self.messageNumber = Utils.getNoNil(self.messageNumber,0) +1
	self.func = func
	self.value = value;
	self.type = type(value)
	self.page = page
	return self;
end

function CourseplayEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	local id = streamReadInt32(streamId);
	self.vehicle = networkGetObject(id);
	local messageNumber = streamReadFloat32(streamId);
	self.func = streamReadString(streamId);
	self.page = streamReadInt32(streamId);
	if self.page == 999 then
		self.page = "global"
	elseif self.page == 998 then
		self.page = true
	elseif self.page == 997 then
		self.page = false
	end
	self.type = streamReadString(streamId);
	if self.type == "boolean" then
		self.value = streamReadBool(streamId);
	elseif self.type == "string" then
		self.value = streamReadString(streamId);
	elseif self.type == "nil" then
		self.value = streamReadString(streamId);
	else 
		self.value = streamReadFloat32(streamId);
	end
	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(networkGetObjectId(self.vehicle).."/"..tostring(messageNumber).."  function: "..tostring(self.func).."  self.value: "..tostring(self.value).."  self.page: "..tostring(self.page).."  self.type: "..self.type),5)

	self:run(connection);
end

function CourseplayEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(networkGetObjectId(self.vehicle).."/"..tostring(self.messageNumber).."  function: "..tostring(self.func).."  value: "..tostring(self.value).."  type: "..tostring(self.type).."  page: "..tostring(self.page)),5)
	streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteFloat32(streamId, self.messageNumber);
	streamWriteString(streamId, self.func);
	if self.page == "global" then
		self.page = 999
	elseif self.page == true then
		self.page = 998
	elseif self.page == false then
		self.page = 997
	end
	streamWriteInt32(streamId, self.page);
	streamWriteString(streamId, self.type);
	if self.type == "boolean" then
		streamWriteBool(streamId, self.value);
	elseif self.type == "string" then
		streamWriteString(streamId, self.value);
	elseif self.type == "nil" then
		streamWriteString(streamId, "nil");
	else
		streamWriteFloat32(streamId, self.value);
	end
end

function CourseplayEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("			run",5)
	courseplay:debug("				id: "..tostring(networkGetObjectId(self.vehicle).."  function: "..tostring(self.func).."  value: "..tostring(self.value)),5)
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
			courseplay:debug("	id: "..tostring(networkGetObjectId(vehicle).."  function: "..tostring(func).."  value: "..tostring(value).."  page: "..tostring(page)),5)
			g_server:broadcastEvent(CourseplayEvent:new(vehicle, func, value, page), nil, nil, vehicle);
		else
			courseplay:debug("send event",5)
			courseplay:debug("	id: "..tostring(networkGetObjectId(vehicle).."  function: "..tostring(func).."  value: "..tostring(value).."  page: "..tostring(page)),5)
			g_client:getServerConnection():sendEvent(CourseplayEvent:new(vehicle, func, value, page));
		end;
	end;
end

function courseplay:checkForChangeAndBroadcast(self, stringName, variable , variableMemory)
	if variable ~= variableMemory then
		CourseplayEvent.sendEvent(self, stringName, variable)
		variableMemory = variable
	end
	return variableMemory

end
