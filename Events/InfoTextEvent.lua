--for now only GlobalInfoText, should be cp.infoText too!!
InfoTextEvent = {}
local InfoTextEvent_mt = Class(InfoTextEvent, Event)

InitEventClass(InfoTextEvent, "InfoTextEvent")

function InfoTextEvent:emptyNew()
	local self = Event:new(InfoTextEvent_mt)
	self.className = "InfoTextEvent"
	return self
end

function InfoTextEvent:new(vehicle,refIdx,forceRemove)
	self.vehicle = vehicle
	self.refIdx = refIdx
	self.forceRemove = forceRemove
	return self
end

function InfoTextEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"readStream infoText event")
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		self.vehicle = nil
	end
	self.forceRemove = streamReadBool(streamId)
	self.refIdx = streamReadString(streamId)
	self:run(connection);
end

function InfoTextEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"writeStream infoText event")
	if self.vehicle ~= nil then
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		streamWriteBool(streamId, false)
	end
	streamWriteBool(streamId, self.forceRemove or false)
	streamWriteString(streamId, self.refIdx or "")
end

function InfoTextEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"run infoText event")
	if self.vehicle then 
		CpManager:setGlobalInfoText(self.vehicle, self.refIdx, self.forceRemove)
	end
	
end

function InfoTextEvent.sendEvent(vehicle,refIdx,forceRemove)
	if g_server ~= nil then
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"broadcast infoText event")
		g_server:broadcastEvent(InfoTextEvent:new(vehicle,refIdx,forceRemove), nil, nil, vehicle);
--	else
--		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"send infoText event")
--		g_client:getServerConnection():sendEvent(InfoTextEvent:new(vehicle,refIdx,forceRemove));
	end;
end
