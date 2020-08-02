--This is a copy from the Autodrive code "https://github.com/Stephan-S/FS19_AutoDrive" 
--all credits go to their Dev team

--Event from Client to Server once joind, gets called 
--after streamWrite/streamRead for each vehicle  
--TODO: make it also viable as an one time event only called once from CPManager
--		for sync Courses, globalSettings...

UserConnectedEvent = {}
UserConnectedEvent_mt = Class(UserConnectedEvent, Event)

InitEventClass(UserConnectedEvent, "UserConnectedEvent")

function UserConnectedEvent:emptyNew()
	local self = Event:new(UserConnectedEvent_mt)
	self.className = "UserConnectedEvent"
	return self
end

function UserConnectedEvent:new(vehicle)
	self.vehicle = vehicle
	return self
end

function UserConnectedEvent:writeStream(streamId, connection)
	if self.vehicle then 
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		streamWriteBool(streamId, false)
	end
end

function UserConnectedEvent:readStream(streamId, connection)
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	end
	self:run(connection)
end

function UserConnectedEvent:run(connection)
	if g_server ~= nil then
		connection:sendEvent(PostSyncEvent:new(self.vehicle))
	end
end

function UserConnectedEvent.sendEvent(vehicle)
	if g_server == nil then
		g_client:getServerConnection():sendEvent(UserConnectedEvent:new(vehicle))
	end
end