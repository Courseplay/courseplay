CourseplayEvent = {};
CourseplayEvent_mt = Class(CourseplayEvent, Event);

InitEventClass(CourseplayEvent, "CourseplayEvent");

function CourseplayEvent:emptyNew()
	local self = Event:new(CourseplayEvent_mt);
	self.className = "CourseplayEvent";
	return self;
end

function CourseplayEvent:new(vehicle, func, value)
	self.vehicle = vehicle;
	self.func = func
	self.value = value;
	return self;
end

function CourseplayEvent:readStream(streamId, connection)
	local id = streamReadInt32(streamId);
	self.vehicle = networkGetObject(id);
	self.func = streamReadString(streamId);
	self.value = streamReadFloat32(streamId);

	self:run(connection);
end

function CourseplayEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteString(streamId, self.func);
	streamWriteFloat32(streamId, self.value);
end

function CourseplayEvent:run(connection)
	self.vehicle:setCourseplayFunc(self.func, self.value, true);
	if not connection:getIsServer() then
		g_server:broadcastEvent(CourseplayEvent:new(self.vehicle, self.func, self.value), nil, connection, self.object);
	end;
end

function CourseplayEvent.sendEvent(vehicle, func, value, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(CourseplayEvent:new(vehicle, func, value), nil, nil, vehicle);
		else
			g_client:getServerConnection():sendEvent(CourseplayEvent:new(vehicle, func, value));
		end;
	end;
end

