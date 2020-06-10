FoldUnfoldImplementEvent = {};
FoldUnfoldImplementEvent.TYPE_FOLD = 0
FoldUnfoldImplementEvent.TYPE_UNFOLD = 1
local FoldUnfoldImplementEvent_mt = Class(FoldUnfoldImplementEvent, Event);

InitEventClass(FoldUnfoldImplementEvent, "FoldUnfoldImplementEvent");

function FoldUnfoldImplementEvent:emptyNew()
	local self = Event:new(FoldUnfoldImplementEvent_mt);
	self.className = "FoldUnfoldImplementEvent";
	return self;
end

function FoldUnfoldImplementEvent:new(vehicle, eventType)
	self.vehicle = vehicle
	self.eventType = eventType
	return self
end

function FoldUnfoldImplementEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.eventType = streamReadUIntN(streamId, 1)
	self:run(connection);
end

function FoldUnfoldImplementEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
	--NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
    streamWriteUIntN(streamId, self.eventType, 1)

end

function FoldUnfoldImplementEvent:run(connection) -- wir fuehren das empfangene event aus
	if self.eventType == self.TYPE_FOLD then
        self.vehicle.cp.driver:foldImplements()
    elseif self.eventType == self.TYPE_UNFOLD then
        self.vehicle.cp.driver:unfoldImplements()		
    end
end

function FoldUnfoldImplementEvent:sendFoldEvent(vehicle)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(FoldUnfoldImplementEvent:new(vehicle, self.TYPE_FOLD), nil,nil,vehicle)
    end
end

function FoldUnfoldImplementEvent:sendUnfoldEvent(vehicle)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(FoldUnfoldImplementEvent:new(vehicle, self.TYPE_UNFOLD), nil,nil,vehicle)
    end
end