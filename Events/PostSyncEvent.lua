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
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	---assignedCombines
	if self.vehicle.cp.assignedCombines then 
		print("assignedCombines found")
		for combine,data in pairs(self.vehicle.cp.assignedCombines) do
			if data == true then 
				print("write Combine: "..tostring(combine))
				streamDebugWriteBool(streamId, true)
				NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(combine))
			end
		end
	end
	streamDebugWriteBool(streamId, false)
end

function PostSyncEvent:readStream(streamId, connection)
	print("PostSyncEvent readStream")
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	--assignedCombines
	while streamDebugReadBool(streamId) do 
		print("assignedCombines found")
		local combine = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
		if combine ~= nil then 
			print("read Combine:"..tostring(combine))
			self.vehicle.cp.assignedCombines[combine] = true
			print("assignedCombine")
		else 
			print("combine is nil")
		end
	end
	
	self:run(connection)
end

function PostSyncEvent:run(connection)
	if g_server == nil then
		
	end
end
