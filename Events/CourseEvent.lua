CourseEvent = {};
local CourseEvent_mt = Class(CourseEvent, Event);

InitEventClass(CourseEvent, "CourseEvent");

function CourseEvent:emptyNew()
	local self = Event:new(CourseEvent_mt);
	self.className = "CourseEvent";
	return self;
end

function CourseEvent:new(vehicle, course)
	self.vehicle = vehicle;
	self.course = course
	return self;
end

function CourseEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"readStream course event")
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	if streamReadBool(streamId) then
		self.course = Course.createFromStream(streamId, connection)
	else
		self.course = nil
	end
	self:run(connection);
end

function CourseEvent:writeStream(streamId, connection)
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"writeStream course event")
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	if self.course then
		-- loading a course in a vehicle
		streamWriteBool(streamId, true)
		course:writeStream()
	else
		-- unloading all courses from a vehicle
		streamWriteBool(streamId, false)
	end
end

-- Process the received event
function CourseEvent:run(connection)
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"run course event")
	if self.course then
		g_courseManager:loadCourseInVehicle(self.vehicle, self.course)
	else
		g_courseManager:unloadCourseFromVehicle(self.vehicle)
	end
	if not connection:getIsServer() then
		-- event was received from a client, so we, the server broadcast it to all other clients now
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"broadcast course event feedback")
		g_server:broadcastEvent(CourseEvent:new(self.vehicle,self.course), nil, connection, self.vehicle);
	end;
end

function CourseEvent.sendEvent(vehicle,course)
	if course then
		if g_server ~= nil then
			courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"broadcast course event")
			g_server:broadcastEvent(CourseEvent:new(vehicle,course), nil, nil, vehicle);
		else
			courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"send course event")
			g_client:getServerConnection():sendEvent(CourseEvent:new(vehicle,course));
		end;
	else 
		courseplay.infoVehicle(vehicle, 'CourseEvent Error: course = nil or #course<1!!!')
	end
end