--Post sync is used for variables that need predefined variables in all vehicles 

PostSyncEvent = {}
PostSyncEvent_mt = Class(PostSyncEvent, Event)

InitEventClass(PostSyncEvent, "PostSyncEvent")

function PostSyncEvent:emptyNew()
	local self = Event:new(PostSyncEvent_mt)
	self.className = "PostSyncEvent"
	return self
end

function PostSyncEvent:new(vehicle)
	self.vehicle = vehicle
	return self
end

function PostSyncEvent:writeStream(streamId, connection)
	local vehicleID = NetworkUtil.getObjectId(self.vehicle)
	if vehicleID then 
		streamDebugWriteBool(streamId, true)
		streamWriteInt32(streamId, vehicleID)
		---assignedCombines
		if self.vehicle.cp.assignedCombines then 
			for combine,data in pairs(self.vehicle.cp.assignedCombines) do
				if data == true then 
					streamDebugWriteBool(streamId, true)
					NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(combine))
				end
			end
		end
		streamDebugWriteBool(streamId, false)
	else 
		streamDebugWriteBool(streamId, false)
	end
	
end

function PostSyncEvent:readStream(streamId, connection)
	if streamDebugReadBool(streamId) then 
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
		--assignedCombines
		while streamDebugReadBool(streamId) do 
			local combine = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
			if combine ~= nil then 
				self.vehicle.cp.assignedCombines[combine] = true
			else 
			
			end
		end
	end
	
	self:run(connection)
end

function PostSyncEvent:run(connection)
	if g_server == nil then
		
	end
end
