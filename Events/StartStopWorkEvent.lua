StartStopWorkEvent = {};
StartStopWorkEvent.TYPE_START = 0
StartStopWorkEvent.TYPE_STOP = 1
local StartStopWorkEvent_mt = Class(StartStopWorkEvent, Event);

InitEventClass(StartStopWorkEvent, "StartStopWorkEvent");

function StartStopWorkEvent:emptyNew()
	local self = Event:new(StartStopWorkEvent_mt);
	self.className = "StartStopWorkEvent";
	return self;
end

function StartStopWorkEvent:new(vehicle, eventType)
	self.vehicle = vehicle
	self.eventType = eventType
	return self
end

function StartStopWorkEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.eventType = streamReadUIntN(streamId, 1)
	self:run(connection);
end

function StartStopWorkEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
	--NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
    streamWriteUIntN(streamId, self.eventType, 1)

end

function StartStopWorkEvent:run(connection) -- wir fuehren das empfangene event aus
	if self.eventType == self.TYPE_START then
        self.vehicle.cp.driver:startWork()
    elseif self.eventType == self.TYPE_STOP then
        self.vehicle.cp.driver:stopWork()		
    end
end

function StartStopWorkEvent:sendStartEvent(vehicle)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(StartStopWorkEvent:new(vehicle, self.TYPE_START), nil,nil,vehicle)
    end
end

function StartStopWorkEvent:sendStopEvent(vehicle)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(StartStopWorkEvent:new(vehicle, self.TYPE_STOP), nil,nil,vehicle)
    end
end