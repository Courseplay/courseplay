
CommandEvents = {};
local CommandEvents_mt = Class(CommandEvents, Event);

InitEventClass(CommandEvents, "CommandEvents");

function CommandEvents:emptyNew()
	local self = Event:new(CommandEvents_mt);
	self.className = "CommandEvents";
	return self;
end

function CommandEvents:new(functionName,parameter)
	self.functionName = functionName
	self.parameter = parameter
	return self
end

function CommandEvents:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,"CommandEvents: readStream event ")
	self.functionName = streamReadString(streamId)	
	if streamReadBool(streamId) then
		self.parameter = streamReadInt32(streamId)
	end	
	self:run(connection)
end

function CommandEvents:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,"CommandEvents: writeStream event")
	streamWriteString(streamId,self.functionName)
	if self.parameter then 
		streamWriteBool(streamId,true)
		streamWriteInt32(streamId,self.parameter)
	else 
		streamWriteBool(streamId,false)
	end
end

function CommandEvents:run(connection) -- wir fuehren das empfangene event aus
	CpManager[self.functionName](CpManager,self.parameter)
	courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,"CommandEvents: run event")
end

function CommandEvents.sendEvent(functionName,parameter)
    if g_server == nil then
		g_client:getServerConnection():sendEvent(CommandEvents:new(functionName,parameter));
		courseplay.debugFormat(courseplay.DBG_MULTIPLAYER,"CommandEvents: send event to server")
    end
end