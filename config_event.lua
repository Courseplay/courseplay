ConfigEvent = {};
ConfigEvent_mt = Class(ConfigEvent, Event);

InitEventClass(ConfigEvent, "ConfigEvent");

function ConfigEvent:emptyNew()  -- hoier wir ein leeres Event objekt erzeugt
    local self = Event:new(ConfigEvent_mt );
    self.className="ConfigEvent";
    return self;
end;

function ConfigEvent:new(vehicle, cx, cz, angle, wait, rev, crossing) -- Der konsturktor des Events (erzeugt eben ein neues Event). Wir wollen das vehicle (aufrufer) und die neue richtung speichern bzw. übertragen
    self.vehicle = vehicle;
    self.cx = cx;
	self.cz = cz;
	self.angle = angle;
	self.wait = wait;
	self.rev = rev;
	self.crossing = crossing;
    return self;
end;

function ConfigEvent:readStream(streamId, connection)  -- wird aufgerufen wenn mich ein Event erreicht
    local id = streamReadInt32(streamId); -- hier lesen wir die übertragene ID des vehicles aus
	self.vehicle = networkGetObject(id);
    self.cx = streamReadFloat32(streamId);
	self.cz = streamReadFloat32(streamId);
	self.angle = streamReadFloat32(streamId);
	self.wait = streamReadBool(streamId);
	self.rev = streamReadBool(streamId);
	self.crossing = streamReadBool(streamId);	
    self:run(connection);  -- das event wurde komplett empfangen und kann nun "ausgeführt" werden
end;

function ConfigEvent:writeStream(streamId, connection)   -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream übereinstimmen (z.B. hier: erst die Vehicle-Id und dann die rotation senden, und bei Readstream dann eben erst die vehicleId lesen und dann die rotation)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));	-- wir übertragen das Vehicle in form seiner ID
    streamWriteFloat32(streamId, self.cx );   
	streamWriteFloat32(streamId, self.cz );   
	streamWriteFloat32(streamId, self.angle );   
	streamWriteBool(streamId, self.wait );   
	streamWriteBool(streamId, self.rev );   
	streamWriteBool(streamId, self.crossing );   
end;

function ConfigEvent:run(connection)  -- wir führen das empfangene event aus
    self.vehicle:setConfig(self.vehicle, self.cx, self.cz, self.angle, self.wait, self.rev, self.crossing, true); -- wir rufen die funktion setConfig auf, damit auch hier bei uns die drehrichtung geändert wird. Das true ist hier wichtig, dann wir haben ein event erhalten, d.h. wir brauchen es nicht mehr versenden, weil es alle anderen mitpsieler schon erreicht hat! Das true also hier nie vergessen!!!!!!
	if not connection:getIsServer() then  -- wenn der Empfänger des Events der Server ist, dann soll er das Event an alle anderen Clients schicken
		g_server:broadcastEvent(ConfigEvent:new(self.vehicle, self.cx, self.cz, self.angle, self.wait, self.rev, self.crossing), nil, connection, self.object);
	end;
end;

function ConfigEvent.sendEvent(vehicle, cx, cz, angle, wait, rev, crossing, noEventSend)  -- hilfsfunktion, die Events anstößte (wirde von setRotateDirection in der Spezi aufgerufen)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then   -- wenn wir der Server sind dann schicken wir das event an alle clients
			g_server:broadcastEvent(ConfigEvent:new(vehicle, cx, cz, angle, wait, rev, crossing), nil, nil, vehicle);
		else -- wenn wir ein Client sind dann schicken wir das event zum server
			g_client:getServerConnection():sendEvent(ConfigEvent:new(vehicle, cx, cz, angle, wait, rev, crossing));
		end;
	end;
end;