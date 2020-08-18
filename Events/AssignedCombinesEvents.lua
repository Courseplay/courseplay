--Events that should handle communication
--between combine and unloader that need sync

RequestAssignedCombinesPostSyncEvent = {};
local RequestAssignedCombinesPostSyncEvent_mt = Class(RequestAssignedCombinesPostSyncEvent, Event);
InitEventClass(RequestAssignedCombinesPostSyncEvent, "RequestAssignedCombinesPostSyncEvent");

function RequestAssignedCombinesPostSyncEvent:emptyNew()
	local self = Event:new(RequestAssignedCombinesPostSyncEvent_mt);
	self.className = "RequestAssignedCombinesPostSyncEvent";
	return self;
end

function RequestAssignedCombinesPostSyncEvent:new(vehicle)
	self.vehicle = vehicle
	return self
end

function RequestAssignedCombinesPostSyncEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	
	self:run(connection);
end

function RequestAssignedCombinesPostSyncEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
end

function RequestAssignedCombinesPostSyncEvent:run(connection) -- wir fuehren das empfangene event aus
	if g_server ~= nil then
		self.vehicle.cp.driver.assignedCombinesSetting:sendPostSyncEvent(connection)
	end
end

function RequestAssignedCombinesPostSyncEvent:sendEvent(vehicle)
	if g_server == nil then
		g_client:getServerConnection():sendEvent(RequestAssignedCombinesPostSyncEvent:new(vehicle))
	end
end

AssignedCombinesPostSyncEvent = {};
local AssignedCombinesPostSyncEvent_mt = Class(AssignedCombinesPostSyncEvent, Event);
InitEventClass(AssignedCombinesPostSyncEvent, "AssignedCombinesPostSyncEvent");

function AssignedCombinesPostSyncEvent:emptyNew()
	local self = Event:new(AssignedCombinesPostSyncEvent_mt);
	self.className = "AssignedCombinesPostSyncEvent";
	return self;
end

function AssignedCombinesPostSyncEvent:new(vehicle,data,offsetHead)
	self.vehicle = vehicle
	self.data = data
	self.offsetHead = offsetHead
	return self
end

function AssignedCombinesPostSyncEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	self.offsetHead = streamReadUIntN(streamId,5)
	local assignedCombines = {}
	while streamReadBool(streamId) do 
		local combine = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
		assignedCombines[combine] = true
	end
	self:run(connection,assignedCombines);
end

function AssignedCombinesPostSyncEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
	streamWriteUIntN(streamId,self.offsetHead,5)
	for combine,bool in pairs(self.data) do 
		if bool then 
			streamWriteBool(streamId, true)
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(combine))
		end
	end
	streamWriteBool(streamId, false)
	
end

function AssignedCombinesPostSyncEvent:run(connection,assignedCombines) -- wir fuehren das empfangene event aus
	if g_server == nil then
		self.vehicle.cp.driver.assignedCombinesSetting:setNetworkValues(assignedCombines,self.offsetHead)
	end
end

function AssignedCombinesPostSyncEvent:sendEvent(vehicle,data,offsetHead)
	if g_server ~= nil then
		g_server:broadcastEvent(AssignedCombinesPostSyncEvent:new(vehicle,data,offsetHead), nil, nil, vehicle);
	end
end

AssignedCombinesEvents = {};
local AssignedCombinesEvents_mt = Class(AssignedCombinesEvents, Event);
InitEventClass(AssignedCombinesEvents, "AssignedCombinesEvents");

function AssignedCombinesEvents:emptyNew()
	local self = Event:new(AssignedCombinesEvents_mt);
	self.className = "AssignedCombinesEvents";
	return self;
end

function AssignedCombinesEvents:new(vehicle,eventTyp,index)
	self.vehicle = vehicle
	self.index = index
	self.eventTyp = eventTyp
	return self
end

function AssignedCombinesEvents:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	self.index = streamReadUIntN(streamId,5)
	self.eventTyp = streamReadUIntN(streamId,2)
	self:run(connection);
end

function AssignedCombinesEvents:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
	streamWriteUIntN(streamId,self.index,5)
	streamWriteUIntN(streamId,self.eventTyp,2)
end

function AssignedCombinesEvents:run(connection) -- wir fuehren das empfangene event aus
	if self.eventTyp == self.vehicle.cp.driver.assignedCombinesSetting.NetworkTypes.TOGGLE then
		self.vehicle.cp.driver.assignedCombinesSetting:toggleAssignedCombine(self.index,true)
	elseif self.eventTyp == self.vehicle.cp.driver.assignedCombinesSetting.NetworkTypes.CHANGE_OFFSET then
		self.vehicle.cp.driver.assignedCombinesSetting:changeListOffset(self.index,true)
	end
	if not connection:getIsServer() then
		g_server:broadcastEvent(AssignedCombinesEvents:new(self.vehicle, self.eventTyp, self.index), nil, connection, self.vehicle);
	end;
end

function AssignedCombinesEvents:sendEvent(vehicle,eventTyp,index)
	if g_server ~= nil then
		g_server:broadcastEvent(AssignedCombinesEvents:new(vehicle,eventTyp,index), nil, nil, vehicle);
	else 
		g_client:getServerConnection():sendEvent(AssignedCombinesEvents:new(vehicle,eventTyp,index));
	end
end