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

function StartStopWorkEvent:readStream(streamId, connection) 
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.eventType = streamReadUIntN(streamId, 1)
	self:run(connection);
end

function StartStopWorkEvent:writeStream(streamId, connection)  
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
    streamWriteUIntN(streamId, self.eventType, 1)
end

function StartStopWorkEvent:run(connection) 
	if self.eventType == self.TYPE_START then
        self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
		self.vehicle:requestActionEventUpdate()
    elseif self.eventType == self.TYPE_STOP then
		self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
		self.vehicle:requestActionEventUpdate()
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