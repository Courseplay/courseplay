--Events that should handle communication
--between combine and unloader that need sync

UnloaderEvents = {};
UnloaderEvents.TYPE_ADD_TO_COMBINE = 0
UnloaderEvents.TYPE_REMOVE_FROM_COMBINE = 1
UnloaderEvents.TYPE_REGISTER_COMBINE = 2
UnloaderEvents.TYPE_DEREGISTER_COMBINE = 3
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
	if self.eventType == self.TYPE_REMOVE_FROM_COMBINE then
		g_combineUnloadManager:releaseUnloaderFromCombine(self.unloader,self.combine,true)
		self.unloader.cp.driver.combineToUnload = nil
		self:refreshHUD()
	elseif self.eventType == self.TYPE_ADD_TO_COMBINE then
		g_combineUnloadManager:addUnloaderToCombine(self.unloader,self.combine,true)
		self:refreshHUD()
	elseif self.eventType == self.TYPE_REGISTER_COMBINE then
		self.combine.cp.driver:registerUnloader(self.unloader,true)
		self.unloader.cp.driver.combineToUnload = self.combine
		self:refreshHUD()
	elseif self.eventType == self.TYPE_DEREGISTER_COMBINE then
		self.combine.cp.driver:deregisterUnloader(self.unloader,true)
		self:refreshHUD()
	end
	if not connection:getIsServer() then
		g_server:broadcastEvent(UnloaderEvents:new(self.unloader, self.combine, self.eventType), nil, connection, self.combine);
	end;
end

function UnloaderEvents:sendReleaseUnloaderEvent(unloader,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(unloader,combine,self.TYPE_REMOVE_FROM_COMBINE))
    end
end

function UnloaderEvents:sendAddUnloaderToCombine(unloader,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(unloader,combine,self.TYPE_ADD_TO_COMBINE))
    end
end

function UnloaderEvents:sendRegisterUnloaderEvent(unloader,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(unloader,combine,self.TYPE_REGISTER_COMBINE), nil,nil,combine)
    else
		g_client:getServerConnection():sendEvent(UnloaderEvents:new(unloader,combine,self.TYPE_REGISTER_COMBINE));
	end;
end

function UnloaderEvents:sendDeregisterUnloaderEvent(unloader,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(unloader,combine,self.TYPE_DEREGISTER_COMBINE), nil,nil,combine)
    else
		g_client:getServerConnection():sendEvent(UnloaderEvents:new(unloader,combine,self.TYPE_DEREGISTER_COMBINE));
	end;
end

function UnloaderEvents:refreshHUD()
	self.unloader.cp.driver:refreshHUD()
	self.combine.cp.driver:refreshHUD()
end