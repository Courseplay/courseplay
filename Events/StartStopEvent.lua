--the same event as giants AIVehicleSetStartedEvent, but customized for cp

AIVehicleSetStartedEventCP = {}
local AIVehicleSetStartedEventCP_mt = Class(AIVehicleSetStartedEventCP, Event);

InitEventClass(AIVehicleSetStartedEventCP, "AIVehicleSetStartedEventCP");

function AIVehicleSetStartedEventCP:emptyNew()
    local self = Event:new(AIVehicleSetStartedEventCP_mt)
    return self
end

function AIVehicleSetStartedEventCP:new(object, reason, isStarted, helper, startedFarmId)
    local self = AIVehicleSetStartedEventCP:emptyNew()
    self.object = object
    self.isStarted = isStarted
    self.reason = reason
    self.startedFarmId = startedFarmId
    if helper ~= nil then
        self.helperIndex = helper.index
    end
    return self
end

function AIVehicleSetStartedEventCP:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.isStarted = streamReadBool(streamId)
    if not self.isStarted then
        self.reason = streamReadUIntN(streamId, AIVehicle.NUM_BITS_REASONS)
    else
        self.helperIndex = streamReadUInt8(streamId)
    end
    self.startedFarmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self:run(connection)
end

function AIVehicleSetStartedEventCP:run(connection)
    if self.isStarted then
        courseplay.onStartCpAIDriver(self.object,self.helperIndex, true, self.startedFarmId)
    else
        courseplay.onStopCpAIDriver(self.object,self.reason, true)
    end
    if not connection:getIsServer() then
        for _, v in pairs(g_server.clientConnections) do
            if v ~= connection and not v:getIsLocal() then
                v:sendEvent(AIVehicleSetStartedEventCP:new(self.object, self.reason, self.isStarted, g_helperManager:getHelperByIndex(self.helperIndex), self.startedFarmId))
            end
        end
    end
end

function AIVehicleSetStartedEventCP:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.isStarted)
    if not self.isStarted then
        streamWriteUIntN(streamId, self.reason, AIVehicle.NUM_BITS_REASONS)
    else
        streamWriteUInt8(streamId, self.helperIndex)
    end
    streamWriteUIntN(streamId, self.startedFarmId, FarmManager.FARM_ID_SEND_NUM_BITS)
end