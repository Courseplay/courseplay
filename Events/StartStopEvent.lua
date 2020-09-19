StartStopEvent = {};
StartStopEvent.TYPE_START = 0
StartStopEvent.TYPE_STOP = 1
local StartStopEvent_mt = Class(StartStopEvent, Event);

InitEventClass(StartStopEvent, "StartStopEvent");

function StartStopEvent:emptyNew()
	local self = Event:new(StartStopEvent_mt);
	self.className = "StartStopEvent";
	return self;
end

function StartStopEvent:new(vehicle, eventType)

	self.vehicle = vehicle
	self.eventType = eventType

	return self
end

function StartStopEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.eventType = streamReadUIntN(streamId, 1)

	self:run(connection);
end

function StartStopEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
	--NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
    streamWriteUIntN(streamId, self.eventType, 1)

end

function StartStopEvent:run(connection) -- wir fuehren das empfangene event aus

	if self.eventType == self.TYPE_START then
        SpecializationUtil.raiseEvent(self.vehicle, "onStartCpAIDriver")
    elseif self.eventType == self.TYPE_STOP then
        SpecializationUtil.raiseEvent(self.vehicle, "onStopCpAIDriver")
    end
	self.vehicle.cp.driver:refreshHUD()
end



function StartStopEvent:sendStartEvent(vehicle)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(StartStopEvent:new(vehicle, self.TYPE_START), true)
    end
end

function StartStopEvent:sendStopEvent(vehicle)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(StartStopEvent:new(vehicle, self.TYPE_STOP), true)
    end
end