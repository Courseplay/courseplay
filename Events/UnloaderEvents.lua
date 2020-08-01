--Events that should handle communication
--between combine and unloader that need sync

UnloaderEvents = {};
UnloaderEvents.TYPE_ADD_TO_COMBINE = 0
UnloaderEvents.TYPE_REMOVE_FROM_COMBINE = 1
UnloaderEvents.TYPE_RELEASE_UNLOADER = 2
UnloaderEvents.TYPE_ADD_UNLOADER_TO_COMBINE = 3
local UnloaderEvents_mt = Class(UnloaderEvents, Event);

InitEventClass(UnloaderEvents, "UnloaderEvents");

function UnloaderEvents:emptyNew()
	local self = Event:new(UnloaderEvents_mt);
	self.className = "UnloaderEvents";
	return self;
end

function UnloaderEvents:new(unloader,combine, eventType)
	self.unloader = unloader
	self.combine = combine
	self.eventType = eventType
	return self
end

function UnloaderEvents:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.unloader = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	self.combine = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	self.eventType = streamReadUIntN(streamId, 2)
	
	self:run(connection);
end

function UnloaderEvents:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.unloader))
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.combine))
    streamWriteUIntN(streamId, self.eventType, 2)
end

function UnloaderEvents:run(connection) -- wir fuehren das empfangene event aus
	if g_server == nil then
		if self.eventType == self.TYPE_RELEASE_UNLOADER then
			g_combineUnloadManager:releaseUnloaderFromCombine(self.unloader,self.combine,true)
		elseif self.eventType == self.TYPE_ADD_UNLOADER_TO_COMBINE then
			g_combineUnloadManager:addUnloaderToCombine(self.unloader,self.combine,true)
		end
	end
end

function UnloaderEvents:sendRelaseUnloaderEvent(unloader,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(unloader,combine,self.TYPE_RELEASE_UNLOADER), nil,nil,vehicle)
    end
end

function UnloaderEvents:sendAddUnloaderToCombine(unloader,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(unloader,combine,self.TYPE_ADD_UNLOADER_TO_COMBINE), nil,nil,vehicle)
    end
end