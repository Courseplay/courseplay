--- This event is used to synchronize Setting changes on run time.
---  Every setting event requires:
---  - a container name (parentName)
---  - a setting name
---  - an event index for the setting
---  - the value
---
SettingEvent = {}
local SettingEvent_mt = Class(SettingEvent, Event)

InitEventClass(SettingEvent, "SettingEvent")

function SettingEvent:emptyNew()
	local self = Event:new(SettingEvent_mt)
	self.className = "SettingEvent"
	return self
end

--- Creates a new Event
---@param vehicle table 
---@param setting Setting 
---@param eventData table 
---@param value any 
function SettingEvent:new(vehicle,setting,eventData,value)
	self.vehicle = vehicle
	self.value = value
	self.parentName,self.name,self.eventIx,self.writeFunc = self.decodeEventData(setting,eventData)
	self.debug("SettingEvent:new()")
	return self
end

--- Reads the serialized data on the receiving end of the event.
function SettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	
	self.parentName = streamReadString(streamId)
	self.name = streamReadString(streamId)
	self.eventIx = streamReadUInt8(streamId)
	self.debug("Parent name: %s, Setting name: %s, eventIx: %d",self.parentName, self.name,self.eventIx)
	self.vehicle = nil
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
		self.debugVehicle(self.vehicle,"Vehicle setting")
		self.setting,self.eventData = self.encodeEventData(self.vehicle,self.parentName,self.name,self.eventIx)
	else
		self.debug("Global setting")
		self.setting,self.eventData = self.encodeEventData(nil,self.parentName,self.name,self.eventIx)
	end

	if self.eventData.readFunc then 
		self.value = self.eventData.readFunc(streamId)
	end

	self.debug("SettingEvent:readStream()")
	self.debug("Parent name: %s, Setting name: %s, value: %s, eventIx: %d",self.parentName, self.name, tostring(self.value),self.eventIx)

	self:run(connection);
end

--- Writes the serialized data from the sender.
function SettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	self.debug("SettingEvent:writeStream()")
	streamWriteString(streamId, self.parentName)
	streamWriteString(streamId, self.name)
	streamWriteUInt8(streamId,self.eventIx)
	self.debug("Parent name: %s, Setting name: %s, value: %s, eventIx: %d",self.parentName, self.name, tostring(self.value),self.eventIx)
	if self.vehicle ~= nil then
		self.debugVehicle(self.vehicle,"Vehicle setting")
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		self.debug("Global setting")
		streamWriteBool(streamId, false)
	end
	if self.writeFunc then 
		self.writeFunc(streamId, self.value)
	end
end

--- Runs the event on the receiving end of the event.
function SettingEvent:run(connection) -- wir fuehren das empfangene event aus
	self.debug("SettingEvent:run()")
	self.eventData.eventFunc(self.setting,self.value,true)
	
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		self.debug("Send SettingEvent to clients")
		g_server:broadcastEvent(SettingEvent:new(self.vehicle,self.setting,self.eventData,self.value), nil, connection, self.vehicle)
	end
end

---  Sends an Event either:
---  - from the server to all clients or
---  - from the client to the server
---@param vehicle table 
---@param setting Setting 
---@param eventData table an event registers on the setting
---@param value any
function SettingEvent.sendEvent(vehicle,setting,eventData,value)
	if g_server ~= nil then
		SettingEvent.debug("Send SettingEvent to clients")
		SettingEvent.debug("Setting name: %s",setting:getName())
		g_server:broadcastEvent(SettingEvent:new(vehicle,setting,eventData,value), nil, nil, vehicle)
	else
		SettingEvent.debug("Send SettingEvent to server")
		SettingEvent.debug("Setting name: %s",setting:getName())
		g_client:getServerConnection():sendEvent(SettingEvent:new(vehicle,setting,eventData,value))
	end;
end

function SettingEvent.debug(...)
	courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,...)
end

function SettingEvent.debugVehicle(vehicle,...)
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,...)
end

--- Gets all relevant values from the setting event to send the event.
---@param setting Setting
---@param eventData table
function SettingEvent.decodeEventData(setting,eventData)
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
function SettingEvent.encodeEventData(vehicle,parentName,settingName,eventIx)
	local setting
	if vehicle ~= nil then 
		setting = vehicle.cp[parentName][settingName]
	else 
		setting = courseplay[parentName][settingName]
	end
	return setting,setting:getEvent(eventIx)
end
