SiloSelectedFillTypeEvent = {};
SiloSelectedFillTypeEvent.TYPE_ADD_ELEMENT = 0
SiloSelectedFillTypeEvent.TYPE_DELETE_X = 1
SiloSelectedFillTypeEvent.TYPE_MOVE_UP_X = 2
SiloSelectedFillTypeEvent.TYPE_MOVE_DOWN_X = 3
SiloSelectedFillTypeEvent.TYPE_CHANGE_MAX_FILLLEVEL = 4
SiloSelectedFillTypeEvent.TYPE_CHANGE_RUNCOUNTER = 5
SiloSelectedFillTypeEvent.TYPE_CLEANUP_OLD_CODE = 6
local SiloSelectedFillTypeEvent_mt = Class(SiloSelectedFillTypeEvent, Event);

InitEventClass(SiloSelectedFillTypeEvent, "SiloSelectedFillTypeEvent");

function SiloSelectedFillTypeEvent:emptyNew()
	local self = Event:new(SiloSelectedFillTypeEvent_mt)
	self.className = "SiloSelectedFillTypeEvent"
	return self
end

function SiloSelectedFillTypeEvent:new(vehicle,settingType,parentName, name, index, value)
	courseplay:debug(string.format("courseplay:SiloSelectedFillTypeEvent:new(%s, %s)", tostring(name), tostring(value)), 5)
	self.vehicle = vehicle
	self.settingType = settingType
	self.messageNumber = Utils.getNoNil(self.messageNumber, 0) + 1
	self.name = name
	self.index = index
	self.value = value
	return self
end

function SiloSelectedFillTypeEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		self.vehicle = nil
	end
	self.settingType = streamReadIntN(streamId,3)
	local messageNumber = streamReadFloat32(streamId)
	self.name = streamReadString(streamId)
	if streamReadBool(streamId) then
		self.index = streamReadIntN(streamId,3)
	end
	if streamReadBool(streamId) then
		self.value = streamReadIntN(streamId,5)
	end
	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(self.vehicle).."/"..tostring(messageNumber).."  self.name: "..tostring(self.name).."  self.value: "..tostring(self.value),5)

	self:run(connection)
end

function SiloSelectedFillTypeEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(self.vehicle).."/"..tostring(self.messageNumber).."  self.name: "..tostring(self.name).."  value: "..tostring(self.value),5)

	if self.vehicle ~= nil then
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		streamWriteBool(streamId, false)
	end
	streamWriteIntN(streamId,self.settingType,3)
	streamWriteFloat32(streamId, self.messageNumber)
	streamWriteString(streamId, self.name)
	if self.index then
		streamWriteBool(streamId, true)
		streamWriteIntN(streamId, self.index,3)
	else
		streamWriteBool(streamId, false)
	end
	if self.value then
		streamWriteBool(streamId, true)
		streamWriteIntN(streamId, self.value,5)
	else
		streamWriteBool(streamId, false)
	end
end

function SiloSelectedFillTypeEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, name=%s, value=%s'):format(tostring(self.vehicle), tostring(self.name), tostring(self.value)), 5);

	if self.settingType == SiloSelectedFillTypeEvent.TYPE_ADD_ELEMENT then 
		self.vehicle.cp.settings[self.name]:onFillTypeSelection(self.value,true)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_DELETE_X then
		self.vehicle.cp.settings[self.name]:deleteByIndex(self.index,true)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_MOVE_UP_X then
		self.vehicle.cp.settings[self.name]:moveUpByIndex(self.index,true)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_MOVE_DOWN_X then
		self.vehicle.cp.settings[self.name]:moveDownByIndex(self.index,true)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_CHANGE_RUNCOUNTER then
		self.vehicle.cp.settings[self.name]:setRunCounterFromNetwork(self.index,self.value)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_CHANGE_MAX_FILLLEVEL then
		self.vehicle.cp.settings[self.name]:setMaxFillLevelFromNetwork(self.index,self.value)
	elseif self.settingType == SiloSelectedFillTypeEvent.CLEANUP_OLD_FILLTYPES then
		self.vehicle.cp.settings[self.name]:cleanUpOldFillTypes(true)
	end
	if not connection:getIsServer() then
		courseplay:debug("broadcast settings event feedback",5)
		g_server:broadcastEvent(SiloSelectedFillTypeEvent:new(self.vehicle, self.name, self.index, self.value), nil, connection, self.vehicle)
	end
end

function SiloSelectedFillTypeEvent.sendEvent(vehicle, settingType, name, index, value)
	if g_server ~= nil then
		courseplay:debug("broadcast settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_server:broadcastEvent(SiloSelectedFillTypeEvent:new(vehicle,settingType, name, index, value), nil, nil, self)
	else
		courseplay:debug("send settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_client:getServerConnection():sendEvent(SiloSelectedFillTypeEvent:new(vehicle,settingType, name, index, value))
	end;
end


