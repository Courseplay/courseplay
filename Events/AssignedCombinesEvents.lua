--Events that should handle communication
--between combine and unloader that need sync

AssignedCombinesEvents = {};
local AssignedCombinesEvents_mt = Class(AssignedCombinesEvents, Event);
InitEventClass(AssignedCombinesEvents, "AssignedCombinesEvents");

function AssignedCombinesEvents:emptyNew()
	local self = Event:new(AssignedCombinesEvents_mt);
	self.className = "AssignedCombinesEvents";
	return self;
end

function AssignedCombinesEvents:new(vehicle,combine)
	self.vehicle = vehicle
	self.combine = combine
	return self
end

function AssignedCombinesEvents:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"AssignedCombinesEvents: readStream ")
	self.vehicle = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	self.combine = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
	self:run(connection);
end

function AssignedCombinesEvents:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"AssignedCombinesEvents: writeStream ")
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.combine))
end

function AssignedCombinesEvents:run(connection) -- wir fuehren das empfangene event aus
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"AssignedCombinesEvents: run ")
	if self.combine then
		self.vehicle.cp.driver.assignedCombinesSetting:toggleAssignedCombineFromNetwork(self.combine)
	end
	if not connection:getIsServer() then
		g_server:broadcastEvent(AssignedCombinesEvents:new(self.vehicle, self.combine), nil, connection, self.vehicle);
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"AssignedCombinesEvents: broadcastEvent to all clients ")
	end;
end

function AssignedCombinesEvents.sendEvent(vehicle,combine)
	if g_server ~= nil then
		g_server:broadcastEvent(AssignedCombinesEvents:new(vehicle,combine), nil, nil, vehicle);
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"AssignedCombinesEvents: broadcast course event ")
	else 
		g_client:getServerConnection():sendEvent(AssignedCombinesEvents:new(vehicle,combine));
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"AssignedCombinesEvents: sendEvent course event to clients ")
	end
end