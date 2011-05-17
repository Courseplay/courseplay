CourseplayEvent = {};
CourseplayEvent_mt = Class(CourseplayEvent, Event);

InitEventClass(CourseplayEvent, "CourseplayEvent");

function CourseplayEvent:emptyNew()  -- hoier wir ein leeres Event objekt erzeugt
    local self = Event:new(CourseplayEvent_mt );
    self.className="CourseplayEvent";
    return self;
end;

function CourseplayEvent:new(vehicle, func, value) -- Der konsturktor des Events (erzeugt eben ein neues Event). Wir wollen das vehicle (aufrufer) und die neue richtung speichern bzw. �bertragen
    self.vehicle = vehicle;
    self.func = func
	self.value = value;
    return self;
end;

function CourseplayEvent:readStream(streamId, connection)  -- wird aufgerufen wenn mich ein Event erreicht
    local id = streamReadInt32(streamId); -- hier lesen wir die �bertragene ID des vehicles aus
	self.vehicle = networkGetObject(id);
    self.func = streamReadString(streamId);
	self.value = streamReadFloat32(streamId);	
    self:run(connection);  -- das event wurde komplett empfangen und kann nun "ausgef�hrt" werden
end;

function CourseplayEvent:writeStream(streamId, connection)   -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream �bereinstimmen (z.B. hier: erst die Vehicle-Id und dann die rotation senden, und bei Readstream dann eben erst die vehicleId lesen und dann die rotation)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));	-- wir �bertragen das Vehicle in form seiner ID
    streamWriteString(streamId, self.func );   
	streamWriteFloat32(streamId, self.value );   
end;

function CourseplayEvent:run(connection)  -- wir f�hren das empfangene event aus
    self.vehicle:setCourseplayFunc(self.func, self.value, true); -- wir rufen die funktion setConfig auf, damit auch hier bei uns die drehrichtung ge�ndert wird. Das true ist hier wichtig, dann wir haben ein event erhalten, d.h. wir brauchen es nicht mehr versenden, weil es alle anderen mitpsieler schon erreicht hat! Das true also hier nie vergessen!!!!!!
	if not connection:getIsServer() then  -- wenn der Empf�nger des Events der Server ist, dann soll er das Event an alle anderen Clients schicken
		g_server:broadcastEvent(CourseplayEvent:new(self.vehicle, self.func, self.value), nil, connection, self.object);
	end;
end;

function CourseplayEvent.sendEvent(vehicle, func, value, noEventSend)  -- hilfsfunktion, die Events anst��te (wirde von setRotateDirection in der Spezi aufgerufen)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then   -- wenn wir der Server sind dann schicken wir das event an alle clients
			g_server:broadcastEvent(CourseplayEvent:new(vehicle, func, value), nil, nil, vehicle);
		else -- wenn wir ein Client sind dann schicken wir das event zum server
			g_client:getServerConnection():sendEvent(CourseplayEvent:new(vehicle, func, value));
		end;
	end;
end;