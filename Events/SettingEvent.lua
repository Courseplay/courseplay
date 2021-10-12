--- This event is used to synchronize global setting changes on run time.
---  Every setting event requires:
---  - a container name (parentName)
---  - a setting name
---  - an event index for the setting
---  - the value
---
GlobalSettingEvent = {}
local GlobalSettingEvent_mt = Class(GlobalSettingEvent, Event)

InitEventClass(GlobalSettingEvent, "GlobalSettingEvent")

function GlobalSettingEvent:emptyNew()
	local self = Event:new(GlobalSettingEvent_mt)
	self.className = "GlobalSettingEvent"
	return self
end

--- Creates a new Event
---@param setting Setting 
---@param eventData table 
---@param value any 
function GlobalSettingEvent:new(setting,eventData,value)
	self.value = value
	self.parentName,self.name,self.eventIx,self.writeFunc = self.decodeEventData(setting,eventData)
	self.debug("GlobalSettingEvent:new()")
	return self
end

--- Reads the serialized data on the receiving end of the event.
function GlobalSettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	
	self.parentName = streamReadString(streamId)
	self.name = streamReadString(streamId)
	self.eventIx = streamReadUInt8(streamId)
	self.debug("Parent name: %s, Setting name: %s, eventIx: %d",self.parentName, self.name,self.eventIx)
	self.setting,self.eventData = self.encodeEventData(self.parentName,self.name,self.eventIx)
	if self.eventData.readFunc then 
		self.value = self.eventData.readFunc(streamId)
	end

	self.debug("GlobalSettingEvent:readStream()")
	self.debug("Parent name: %s, Setting name: %s, value: %s, eventIx: %d",self.parentName, self.name, tostring(self.value),self.eventIx)

	self:run(connection);
end

--- Writes the serialized data from the sender.
function GlobalSettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	self.debug("GlobalSettingEvent:writeStream()")
	streamWriteString(streamId, self.parentName)
	streamWriteString(streamId, self.name)
	streamWriteUInt8(streamId,self.eventIx)
	self.debug("Parent name: %s, Setting name: %s, value: %s, eventIx: %d",self.parentName, self.name, tostring(self.value),self.eventIx)
	if self.writeFunc then 
		self.writeFunc(streamId, self.value)
	end
end

--- Runs the event on the receiving end of the event.
function GlobalSettingEvent:run(connection) -- wir fuehren das empfangene event aus
	self.debug("GlobalSettingEvent:run()")
	self.eventData.eventFunc(self.setting,self.value)
	
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		self.debug("Send GlobalSettingEvent to clients")
		g_server:broadcastEvent(GlobalSettingEvent:new(self.setting,self.eventData,self.value), nil, connection)
	end
end

---  Sends an Event either:
---  - from the server to all clients or
---  - from the client to the server
---@param setting Setting 
---@param eventData table an event registers on the setting
---@param value any
function GlobalSettingEvent.sendEvent(setting,eventData,value)
	if g_server ~= nil then
		GlobalSettingEvent.debug("Send GlobalSettingEvent to clients")
		GlobalSettingEvent.debug("Setting name: %s",setting:getName())
		g_server:broadcastEvent(GlobalSettingEvent:new(setting,eventData,value))
	else
		GlobalSettingEvent.debug("Send GlobalSettingEvent to server")
		GlobalSettingEvent.debug("Setting name: %s",setting:getName())
		g_client:getServerConnection():sendEvent(GlobalSettingEvent:new(setting,eventData,value))
	end;
end

function GlobalSettingEvent.debug(...)
	courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,...)
end

--- Gets all relevant values from the setting event to send the event.
---@param setting Setting
---@param eventData table
function GlobalSettingEvent.decodeEventData(setting,eventData)
	local parentName = setting:getParentName()
	local settingName = setting:getName()
	local eventIx = eventData.ix
	local writeFunc = eventData.writeFunc
	return parentName,settingName,eventIx,writeFunc
end

--- Gets the setting and event back from all received values.
---@param parentName table Name of the setting container
---@param settingName string Name of the setting
---@param eventIx number Event number received
function GlobalSettingEvent.encodeEventData(parentName,settingName,eventIx)
	local setting = courseplay[parentName][settingName]
	return setting,setting:getEvent(eventIx)
end


--- This event is used to synchronize Setting changes on run time.
---  Every setting event requires:
---  - a container name (parentName)
---  - a setting name
---  - an event index for the setting
---  - the value
---
VehicleSettingEvent = {}
local VehicleSettingEvent_mt = Class(VehicleSettingEvent, Event)

InitEventClass(VehicleSettingEvent, "VehicleSettingEvent")

function VehicleSettingEvent:emptyNew()
	local self = Event:new(VehicleSettingEvent_mt)
	self.className = "VehicleSettingEvent"
	return self
end

--- Creates a new Event
---@param vehicle table 
---@param setting Setting 
---@param eventData table 
---@param value any 
function VehicleSettingEvent:new(vehicle,setting,eventData,value)
	self.vehicle = vehicle
	self.value = value
	self.parentName,self.name,self.eventIx,self.writeFunc = self.decodeEventData(setting,eventData)
	self.debug(self.vehicle,"VehicleSettingEvent:new()")
	return self
end

--- Reads the serialized data on the receiving end of the event.
function VehicleSettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	self.parentName = streamReadString(streamId)
	self.name = streamReadString(streamId)
	self.eventIx = streamReadUInt8(streamId)
	self.debug(self.vehicle,"Parent name: %s, Setting name: %s, eventIx: %d",self.parentName, self.name,self.eventIx)
	self.setting,self.eventData = self.encodeEventData(self.vehicle,self.parentName,self.name,self.eventIx)

	if self.eventData.readFunc then 
		self.value = self.eventData.readFunc(streamId)
	end

	self.debug(self.vehicle,"VehicleSettingEvent:readStream()")
	self.debug(self.vehicle,"Parent name: %s, Setting name: %s, value: %s, eventIx: %d",self.parentName, self.name, tostring(self.value),self.eventIx)

	self:run(connection);
end

--- Writes the serialized data from the sender.
function VehicleSettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	self.debug(self.vehicle,"VehicleSettingEvent:writeStream()")
	streamWriteString(streamId, self.parentName)
	streamWriteString(streamId, self.name)
	streamWriteUInt8(streamId,self.eventIx)
	self.debug(self.vehicle,"Parent name: %s, Setting name: %s, value: %s, eventIx: %d",self.parentName, self.name, tostring(self.value),self.eventIx)
	if self.writeFunc then 
		self.writeFunc(streamId, self.value)
	end
end

--- Runs the event on the receiving end of the event.
function VehicleSettingEvent:run(connection) -- wir fuehren das empfangene event aus
	self.debug(self.vehicle,"VehicleSettingEvent:run()")
	self.eventData.eventFunc(self.setting,self.value)
	
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		self.debug(self.vehicle,"Send VehicleSettingEvent to clients")
		g_server:broadcastEvent(VehicleSettingEvent:new(self.vehicle,self.setting,self.eventData,self.value), nil, connection, self.vehicle)
	end
end

---  Sends an Event either:
---  - from the server to all clients or
---  - from the client to the server
---@param vehicle table 
---@param setting Setting 
---@param eventData table an event registers on the setting
---@param value any
function VehicleSettingEvent.sendEvent(vehicle,setting,eventData,value)
	if g_server ~= nil then
		VehicleSettingEvent.debug(vehicle,"Send VehicleSettingEvent to clients")
		VehicleSettingEvent.debug(vehicle,"Setting name: %s",setting:getName())
		g_server:broadcastEvent(VehicleSettingEvent:new(vehicle,setting,eventData,value), nil, nil, vehicle)
	else
		VehicleSettingEvent.debug(vehicle,"Send VehicleSettingEvent to server")
		VehicleSettingEvent.debug(vehicle,"Setting name: %s",setting:getName())
		g_client:getServerConnection():sendEvent(VehicleSettingEvent:new(vehicle,setting,eventData,value))
	end;
end
function VehicleSettingEvent.debug(vehicle,...)
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,...)
end

--- Gets all relevant values from the setting event to send the event.
---@param setting Setting
---@param eventData table
function VehicleSettingEvent.decodeEventData(setting,eventData)
	local parentName = setting:getParentName()
	local settingName = setting:getName()
	local eventIx = eventData.ix
	local writeFunc = eventData.writeFunc
	return parentName,settingName,eventIx,writeFunc
end

--- Gets the setting and event back from all received values.
---@param vehicle table
---@param parentName table Name of the setting container
---@param settingName string Name of the setting
---@param eventIx number Event number received
function VehicleSettingEvent.encodeEventData(vehicle,parentName,settingName,eventIx)
	local setting = vehicle.cp[parentName][settingName]
	return setting,setting:getEvent(eventIx)
end
