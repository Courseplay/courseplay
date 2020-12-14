SiloSelectedFillTypeEvent = {};
local SiloSelectedFillTypeEvent_mt = Class(SiloSelectedFillTypeEvent, Event);

InitEventClass(SiloSelectedFillTypeEvent, "SiloSelectedFillTypeEvent");

function SiloSelectedFillTypeEvent:emptyNew()
	local self = Event:new(SiloSelectedFillTypeEvent_mt)
	self.className = "SiloSelectedFillTypeEvent"
	return self
end

function SiloSelectedFillTypeEvent:new(vehicle, name,settingType, index, value)
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
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	self.settingType = streamReadUIntN(streamId,3)
	local messageNumber = streamReadFloat32(streamId)
	self.name = streamReadString(streamId)
	if streamReadBool(streamId) then
		self.index = streamReadIntN(streamId,3)
	end
	if streamReadBool(streamId) then
		self.value = streamReadIntN(streamId,8)
	end
	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(self.vehicle).."/"..tostring(messageNumber).."  self.name: "..tostring(self.name).."  self.value: "..tostring(self.value),5)

	self:run(connection)
end

function SiloSelectedFillTypeEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(self.vehicle).."/"..tostring(self.messageNumber).."  self.name: "..tostring(self.name).."  value: "..tostring(self.value),5)
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	streamWriteUIntN(streamId,self.settingType,3)
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
		streamWriteIntN(streamId, self.value,8)
	else
		streamWriteBool(streamId, false)
	end
end

function SiloSelectedFillTypeEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, name=%s, value=%s'):format(tostring(self.vehicle), tostring(self.name), tostring(self.value)), 5);

	if self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.ADD_ELEMENT then 
		courseplay:debug("add Element!",5)
		self.vehicle.cp.settings[self.name]:onFillTypeSelection(self.value,true)
	elseif self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.DELETE_X then
		courseplay:debug("delete Element!",5)
		self.vehicle.cp.settings[self.name]:deleteByIndex(self.index,true)
	elseif self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.MOVE_UP_X then
		courseplay:debug("move UP Element!",5)
		self.vehicle.cp.settings[self.name]:moveUpByIndex(self.index,true)
	elseif self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.MOVE_DOWN_X then
		courseplay:debug("move Down Element!",5)
		self.vehicle.cp.settings[self.name]:moveDownByIndex(self.index,true)
	elseif self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.CHANGE_RUNCOUNTER then
		courseplay:debug("change Counter Element!",5)
		self.vehicle.cp.settings[self.name]:setRunCounterFromNetwork(self.index,self.value)
	elseif self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.CHANGE_MAX_FILLLEVEL then
		courseplay:debug("change Max Element!",5)
		self.vehicle.cp.settings[self.name]:setMaxFillLevelFromNetwork(self.index,self.value)
	elseif self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.CLEANUP_OLD_FILLTYPES  then
		courseplay:debug("cleanUP Element!",5)
		self.vehicle.cp.settings[self.name]:cleanUpOldFillTypes(true)
	elseif self.settingType == SiloSelectedFillTypeSetting.NetworkTypes.CHANGE_MIN_FILLEVEL then
		courseplay:debug("change Min Element!",5)
		self.vehicle.cp.settings[self.name]:setMinFillLevelFromNetwork(self.index,self.value)
	end
	self.vehicle.cp.driver:refreshHUD()
	if not connection:getIsServer() then
		courseplay:debug("broadcast settings event feedback",5)
		g_server:broadcastEvent(SiloSelectedFillTypeEvent:new(self.vehicle, self.name,self.settingType, self.index, self.value), nil, connection, self.vehicle)
	end
end

function SiloSelectedFillTypeEvent.sendEvent(vehicle, name,settingType, index, value)
	if g_server ~= nil then
		courseplay:debug("broadcast settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_server:broadcastEvent(SiloSelectedFillTypeEvent:new(vehicle, name,settingType, index, value), nil, nil, vehicle)
	else
		courseplay:debug("send settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_client:getServerConnection():sendEvent(SiloSelectedFillTypeEvent:new(vehicle, name,settingType, index, value))
	end;
end


