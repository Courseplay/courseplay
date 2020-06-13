UnloaderEvents = {};
UnloaderEvents.TYPE_ADD_TO_COMBINE = 0
UnloaderEvents.TYPE_REMOVE_FROM_COMBINE = 1
UnloaderEvents.TYPE_RELEASE_UNLOADER = 2

local UnloaderEvents_mt = Class(UnloaderEvents, Event);

InitEventClass(UnloaderEvents, "UnloaderEvents");

function UnloaderEvents:emptyNew()
	local self = Event:new(UnloaderEvents_mt);
	self.className = "UnloaderEvents";
	return self;
end

function UnloaderEvents:new(vehicle,combine, eventType)
	self.vehicle = vehicle
	self.combine = combine
	self.eventType = eventType
	return self
end

function UnloaderEvents:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.combine = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	self.eventType = streamReadUIntN(streamId, 2)
	
	self:run(connection);
end

function UnloaderEvents:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.combine))
    streamWriteUIntN(streamId, self.eventType, 2)
end

function UnloaderEvents:run(connection) -- wir fuehren das empfangene event aus
	if g_server == nil then
		if self.eventType == self.TYPE_ADD_TO_COMBINE then	
			self.vehicle.cp.driver:setCombineToUnloadClient(self.combine)
			self.combine.cp.driver:registerUnloader(self.vehicle)
		elseif self.eventType == self.TYPE_REMOVE_FROM_COMBINE then
			if self.vehicle.cp.driver.combineToUnload ~= nil then
				self.combine.cp.driver:deregisterUnloader(self.vehicle)
			end
		elseif self.eventType == self.TYPE_RELEASE_UNLOADER then
			self.vehicle.cp.driver:releaseUnloader()
		end
	end
end

function UnloaderEvents:sendAddToCombineEvent(vehicle,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(vehicle,combine,self.TYPE_ADD_TO_COMBINE), nil,nil,vehicle)
    end
end

function UnloaderEvents:sendRemoveFromCombineEvent(vehicle,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(vehicle,combine,self.TYPE_REMOVE_FROM_COMBINE), nil,nil,vehicle)
    end
end

function UnloaderEvents:sendRelaseUnloaderEvent(vehicle,combine)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(UnloaderEvents:new(vehicle,combine,self.TYPE_RELEASE_UNLOADER), nil,nil,vehicle)
    end
end