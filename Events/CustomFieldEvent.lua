--- This event is used to synchronize custom field, 
--- either from the server to a newly joined player
--- or after a custom field was created to all user and server. 
---
CustomFieldEvent = {}
local CustomFieldEvent_mt = Class(CustomFieldEvent, Event)

InitEventClass(CustomFieldEvent, "CustomFieldEvent")

function CustomFieldEvent:emptyNew()
	local self = Event:new(CustomFieldEvent_mt)
	self.className = "CustomFieldEvent"
	return self
end

--- Creates a new Event
---@param field table 
function CustomFieldEvent:new(field)
	self.field = field
	self.debug("CustomFieldEvent:new()")
	return self
end

--- Reads the serialized data on the receiving end of the event.
function CustomFieldEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.field = CustomFieldEvent.readField(streamId)
	self.debug("CustomFieldEvent:readStream()")
	self.debug("Field name: %s, numPoints = %s ",tostring(self.field.name), tostring(self.field.numPoints))

	self:run(connection);
end

--- Writes the serialized data from the sender.
function CustomFieldEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	self.debug("CustomFieldEvent:writeStream()")
	self.debug("Field name: %s, numPoints = %s ",tostring(self.field.name), tostring(self.field.numPoints))
	CustomFieldEvent.writeField(self.field,streamId)
end

--- Runs the event on the receiving end of the event.
function CustomFieldEvent:run(connection) -- wir fuehren das empfangene event aus
	self.debug("CustomFieldEvent:run()")
	CpFieldUtil.saveFieldFromNetwork(self.field)
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		self.debug("Send CustomFieldEvent to clients")
		g_server:broadcastEvent(CustomFieldEvent:new(self.field), nil, connection)
	end
end

--- Sends an event to sync a custom created field.
function CustomFieldEvent.sendEvent(field)
	--- Only sync custom fields
	if field.isCustom then
		if g_server ~= nil then
			CustomFieldEvent.debug("Send CustomFieldEvent to clients")
			CustomFieldEvent.debug("Field name: %s",tostring(field.name))
			g_server:broadcastEvent(CustomFieldEvent:new(field))
		else
			CustomFieldEvent.debug("Send CustomFieldEvent to server")
			CustomFieldEvent.debug("Field name: %s",tostring(field.name))
			g_client:getServerConnection():sendEvent(CustomFieldEvent:new(field))
		end;
	end
end

function CustomFieldEvent.debug(...)
	courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,...)
end

--- Writes a single custom field.
function CustomFieldEvent.writeField(field,streamId)
	local numPoints = field.numPoints or #field.points
	streamDebugWriteString(streamId, field.name)
	streamDebugWriteInt32(streamId, numPoints)
	streamDebugWriteInt32(streamId, field.fieldNum)
	streamDebugWriteInt32(streamId, field.dimensions.minX)
	streamDebugWriteInt32(streamId, field.dimensions.maxX)
	streamDebugWriteInt32(streamId, field.dimensions.minZ)
	streamDebugWriteInt32(streamId, field.dimensions.maxZ)
	for p = 1, numPoints do
		streamDebugWriteFloat32(streamId, field.points[p].cx)
		streamDebugWriteFloat32(streamId, field.points[p].cy)
		streamDebugWriteFloat32(streamId, field.points[p].cz)
	end

end

--- Reads a single custom field.
function CustomFieldEvent.readField(streamId)
	local field = {
		dimensions = {},
		points = {},
		isCustom = true
	}
	field.name = streamDebugReadString(streamId)
	field.numPoints = streamDebugReadInt32(streamId)
	field.fieldNum = streamDebugReadInt32(streamId)
	field.dimensions.minX = streamDebugReadInt32(streamId)
	field.dimensions.maxX = streamDebugReadInt32(streamId)
	field.dimensions.minZ = streamDebugReadInt32(streamId)
	field.dimensions.maxZ = streamDebugReadInt32(streamId)
	for p = 1, field.numPoints do
		field.points[p] = {}
		field.points[p].cx = streamDebugReadFloat32(streamId)
		field.points[p].cy = streamDebugReadFloat32(streamId)
		field.points[p].cz = streamDebugReadFloat32(streamId)
	end
	return field
end