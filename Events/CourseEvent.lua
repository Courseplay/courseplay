CourseEvent = {};
local CourseEvent_mt = Class(CourseEvent, Event);

InitEventClass(CourseEvent, "CourseEvent");

function CourseEvent:emptyNew()
	local self = Event:new(CourseEvent_mt);
	self.className = "CourseEvent";
	return self;
end

function CourseEvent:new(vehicle,course)
	self.vehicle = vehicle;
	self.course = course
	return self;
end

function CourseEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	courseplay.debugVehicle(5,vehicle,"readStream course event")
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		self.vehicle = nil
	end
	local wp_count = streamReadInt32(streamId)
	self.course = {}
	for w = 1, wp_count do
		table.insert(self.course, CourseEvent:readWaypoint(streamId))
	end
	self:run(connection);
end

function CourseEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay.debugVehicle(5,vehicle,"writeStream course event")
	if self.vehicle ~= nil then
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		streamWriteBool(streamId, false)
	end
	streamWriteInt32(streamId, #(self.course))
	for w = 1, #(self.course) do
		CourseEvent:writeWaypoint(streamId, self.course[w])
	end
end

function CourseEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay.debugVehicle(5,vehicle,"run course event")
	if self.vehicle then 
		courseplay:setVehicleWaypoints(vehicle, self.course)
	end
	
end

function CourseEvent.sendEvent(vehicle,course)
	if course and #course > 0 then
		if g_server ~= nil then
			courseplay.debugVehicle(5,vehicle,"broadcast course event")
			g_server:broadcastEvent(CourseEvent:new(vehicle,course), nil, nil, vehicle);
		else
			courseplay.debugVehicle(5,vehicle,"send course event")
			g_client:getServerConnection():sendEvent(CourseEvent:new(vehicle,course));
		end;
	else 
		courseplay.infoVehicle(vehicle, 'CourseEvent Error: course = nil or #course<1!!!')
	end
end


function CourseEvent:writeWaypoint(streamId, waypoint)
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

function CourseEvent:readWaypoint(streamId)
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