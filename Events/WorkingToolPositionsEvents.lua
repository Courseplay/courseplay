WorkingToolPositionsEvents = {};
local WorkingToolPositionsEvents_mt = Class(WorkingToolPositionsEvents, Event);

InitEventClass(WorkingToolPositionsEvents, "WorkingToolPositionsEvents");

function WorkingToolPositionsEvents:emptyNew()
	local self = Event:new(WorkingToolPositionsEvents_mt);
	self.className = "WorkingToolPositionsEvents";
	return self;
end

function WorkingToolPositionsEvents:new(vehicle,setting,eventType,position)
	self.vehicle = vehicle;
	self.setting = setting
	self.eventType = eventType
	self.position  = position
	return self;
end

function WorkingToolPositionsEvents:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"readStream WorkingToolPositionsEvent")
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	self.setting = streamReadString(streamId)
	self.eventType = streamReadIntN(streamId,1)
	self.position = streamReadUIntN(streamId,3)
	self:run(connection);
end

function WorkingToolPositionsEvents:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"writeStream WorkingToolPositionsEvent")
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	streamWriteString(streamId,self.setting)
	streamWriteIntN(streamId,self.eventType,1)
	streamWriteUIntN(streamId,self.position,3)
end

function WorkingToolPositionsEvents:run(connection) -- wir fuehren das empfangene event aus
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"run WorkingToolPositionsEvent")
	if self.eventType == WorkingToolPositionsSetting.NetworkTypes.SET_OR_CLEAR_POSITION then 
		self.vehicle.cp.settings[self.setting]:setOrClearPostion(self.position,true)
	else
		if not connection:getIsServer() then
			self.vehicle.cp.settings[self.setting]:playPosition(self.position)
		end
	end
	if not connection:getIsServer() then
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"broadcast WorkingToolPositionsEvent")
		g_server:broadcastEvent(WorkingToolPositionsEvents:new(self.vehicle,self.setting,self.eventType,self.position), nil, connection, self.vehicle);
	end;
end

function WorkingToolPositionsEvents.sendEvent(vehicle,setting,eventType,position)
	if g_server ~= nil then
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"broadcast WorkingToolPositionsEvent")
		g_server:broadcastEvent(WorkingToolPositionsEvents:new(vehicle,setting,eventType,position), nil, nil, vehicle);
	else
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"send WorkingToolPositionsEvent")
		g_client:getServerConnection():sendEvent(WorkingToolPositionsEvents:new(vehicle,setting,eventType,position));
	end;
end
