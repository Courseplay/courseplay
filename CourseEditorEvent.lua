CourseEditorEvent = {};
local CourseEditorEvent_mt = Class(CourseEditorEvent, Event);

InitEventClass(CourseEditorEvent, "CourseEditorEvent");

function CourseEditorEvent:emptyNew()
	local self = Event:new(CourseEditorEvent_mt);
	self.className = "CourseEditorEvent";
	return self;
end

function CourseEditorEvent:new(vehicle,action,values)
	self.vehicle = vehicle;
	self.action = action;
	self.values = values;
	return self;
end

function CourseEditorEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId);
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"readStream Course Editor")
	self.action = streamReadString(streamId);
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,'readStream Course Editor: Recieving %s event', tostring(self.action));

	if self.action == "DragTo"
	or self.action == "UndoDragTo"
	then
		self.values = {
			wpSelected = streamReadInt32(streamId),
			wpInfo = {
				cx    = streamReadFloat32(streamId),
				cy    = streamReadFloat32(streamId),
				cz    = streamReadFloat32(streamId)
			}
		};

	elseif self.action == "UndoDelete" then
		self.values = {
			wpSelected = streamReadInt32(streamId),
			wpInfo = {
				cx    = streamReadFloat32(streamId),
				cy    = streamReadFloat32(streamId),
				cz    = streamReadFloat32(streamId),
				angle = streamReadFloat32(streamId),
				speed = streamReadInt32(streamId)
			}
		};

	elseif self.action == "SaveCourse"
		or self.action == "IncreaseSpeed"
		or self.action == "DecreaseSpeed"
		or self.action == "UndoInsert"
		or self.action == "DeleteSelected"
		or self.action == "DeleteNext"
		or self.action == "DeleteToStart"
		or self.action == "DeleteToEnd"
	then
		self.values     = streamReadInt32(streamId);

	elseif self.action == "InsertNewWP" then
		self.values = {
			wpSelected = streamReadInt32(streamId),
			midPNx     = streamReadFloat32(streamId),
			midPNy     = streamReadFloat32(streamId),
			midPNz     = streamReadFloat32(streamId)
		};

	elseif self.action == "ChangeType" then
		self.values = {
			wpSelected = streamReadInt32(streamId),
			typeIndex  = streamReadInt8(streamId)
		};
	end

	self:run(connection);
end

function CourseEditorEvent:writeStream(streamId, connection)
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,'writeStream Course Editor: Sending %s event', tostring(self.action));
	NetworkUtil.writeNodeObject(streamId, self.vehicle);
	streamWriteString(streamId, self.action);

	if self.action == "DragTo"
	or self.action == "UndoDragTo"
	then
		streamWriteInt32(  streamId, self.values.wpSelected);
		streamWriteFloat32(streamId, self.values.wpInfo.cx);
		streamWriteFloat32(streamId, self.values.wpInfo.cy);
		streamWriteFloat32(streamId, self.values.wpInfo.cz);

	elseif self.action == "UndoDelete" then
		streamWriteInt32(  streamId, self.values.wpSelected);
		streamWriteFloat32(streamId, self.values.wpInfo.cx);
		streamWriteFloat32(streamId, self.values.wpInfo.cy);
		streamWriteFloat32(streamId, self.values.wpInfo.cz);
		streamWriteFloat32(streamId, self.values.wpInfo.angle);
		streamWriteInt32(  streamId, self.values.wpInfo.speed);

	elseif self.action == "SaveCourse"
		or self.action == "IncreaseSpeed"
		or self.action == "DecreaseSpeed"
		or self.action == "UndoInsert"
		or self.action == "DeleteSelected"
		or self.action == "DeleteNext"
		or self.action == "DeleteToStart"
		or self.action == "DeleteToEnd"
	then
		streamWriteInt32(streamId, self.values);

	elseif self.action == "InsertNewWP" then
		streamWriteInt32(  streamId, self.values.wpSelected);
		streamWriteFloat32(streamId, self.values.midPNx);
		streamWriteFloat32(streamId, self.values.midPNy);
		streamWriteFloat32(streamId, self.values.midPNz);

	elseif self.action == "ChangeType" then
		streamWriteInt32(streamId, self.values.wpSelected);
		streamWriteInt8( streamId, self.values.typeIndex)
	end


	end

function CourseEditorEvent:run(connection)
	courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"run Course Editor event")

	if self.action == "SaveCourse" then
		courseEditor:doSaveCourseAction(self.vehicle,self.values,true);
	elseif self.action == "IncreaseSpeed" then
		courseEditor:doIncreaseSpeedAction(self.vehicle,self.values,true);
	elseif self.action == "IncreaseSpeed" then
		courseEditor:doIncreaseSpeedAction(self.vehicle,self.values,true);
	elseif self.action == "DecreaseSpeed" then
		courseEditor:doDecreaseSpeedAction(self.vehicle,self.values,true);
	elseif self.action == "DragTo" then
		courseEditor:doDragToAction(self.vehicle, self.values.wpSelected, self.values.wpInfo, true);
	elseif self.action == "UndoDragTo" then
		courseEditor:doUndoDragToAction(self.vehicle, self.values.wpSelected, self.values.wpInfo, true);
	elseif self.action == "UndoDelete" then
		courseEditor:doUndoDeleteAction(self.vehicle, self.values.wpSelected, self.values.wpInfo, true);
	elseif self.action == "UndoInsert" then
		courseEditor:doUndoInsertAction(self.vehicle,self.values,true);
	elseif self.action == "DeleteSelected" then
		courseEditor:doDeleteSelectedAction(self.vehicle,self.values,true);
	elseif self.action == "DeleteNext" then
		courseEditor:doDeleteNextAction(self.vehicle,self.values,true);
	elseif self.action == "DeleteToStart" then
		courseEditor:doDeleteToStartAction(self.vehicle,self.values,true);
	elseif self.action == "DeleteToEnd" then
		courseEditor:doDeleteToEndAction(self.vehicle,self.values,true);
	elseif self.action == "InsertNewWP" then
		courseEditor:doInsertAction(self.vehicle,self.values.wpSelected,self.values.midPNx,self.values.midPNy,self.values.midPNz,true);
	elseif self.action == "ChangeType" then
		courseEditor:doChangeTypeAction(self.vehicle,self.values.wpSelected,self.values.typeIndex,true);
	end

	if not connection:getIsServer() then
		courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,self.vehicle,"broadcast Course Editor event feedback");
		g_server:broadcastEvent(CourseEditorEvent:new(self.vehicle,self.action,self.values), nil, connection, self.vehicle);
	end;
end

function CourseEditorEvent.sendEvent(vehicle,action,values,noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"broadcast Course Editor event");
			courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,'action=%s, values=%s', tostring(action), tostring(values));
			g_server:broadcastEvent(CourseEditorEvent:new(vehicle,action,values), nil, nil, vehicle);
		else
			courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,"send Course Editor event");
			courseplay.debugVehicle(courseplay.DBG_MULTIPLAYER,vehicle,'action=%s, values=%s', tostring(action), tostring(values));
			g_client:getServerConnection():sendEvent(CourseEditorEvent:new(vehicle,action,values));
		end;
	end
end
