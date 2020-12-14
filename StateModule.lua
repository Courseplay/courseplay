StateModule = CpObject()

function StateModule:init(debugClass,debugFunc, vehicle) 
	self.states = {}
	self.debugClass = debugClass
	self.debugFunc = debugFunc
	self.vehicle = vehicle
end

--- Aggregation of states from this and all descendant classes
function StateModule:initStates(states)
	for key, state in pairs(states) do
		self.states[key] = {name = tostring(key), properties = state}
	end
end

function StateModule:debug(lastState,newState)
	if self.vehicle then
		self.debugClass[self.debugFunc](self.debugClass,self.vehicle,"lastState: %s => newState: %s",lastState.name,newState.name)
	else
		self.debugClass[self.debugFunc](self.debugClass,"lastState: %s => newState: %s",lastState.name,newState.name)
	end
end

function StateModule:changeState(newStateName)
	local newState = self.states[newStateName]
	if self.state ~= newState then 
		self:debug(self.state,newState)
		self.state = newState
	end	
end

function StateModule:get()
	return self.state
end

function StateModule:getName()
	return self.state.name
end

function StateModule:is(state)
	return self.state == self.states[state]
end

function StateModule:onReadStream(streamId)
	local nameState = streamReadString(streamId)
	self.state = self.states[nameState]
end

function StateModule:onWriteStream(streamId)
	streamWriteString(streamId,self.state.name)
	self.lastStateSent = self.state
end

function StateModule:onWriteUpdateStream(streamId)
	if self.lastStateSent == nil or self.lastStateSent ~= self.state then
		streamWriteBool(streamId,true)
		streamWriteString(streamId,self.state.name)
		self.lastStateSent = self.state
	else
		streamWriteBool(streamId,false)
	end
end

function StateModule:onReadUpdateStream(streamId)
	if streamReadBool(streamId) then
		local nameState = streamReadString(streamId)
		self.state = self.states[nameState]
	end
end