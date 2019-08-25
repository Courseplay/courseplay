
---@class SchwarmManager
SchwarmManager = CpObject()

function SchwarmManager:getInputBindingsFromXML()
	local xmlFile = self:getSchwarmManagerXML()
	SchwarmManager.inputBindings = {}
	if xmlFile ~= nil then
		local index = 0;
		while true do
			local key = ('InputBindings.Inputs.Input(%d)'):format(index);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;
			local functionToCall =  getXMLString(xmlFile, key .. '#functionToCall');
			local assignment =  getXMLString(xmlFile, key .. '#assignment');
			SchwarmManager.inputBindings[functionToCall] = Input[assignment]
			index = index+1;
		end
		print("## Courseplay:SchwarmManager:Inputs loaded from xml:")
		for index, value in pairs(SchwarmManager.inputBindings) do
			print(string.format("  %s: %s",index,tostring(Input.keyIdToIdName[value])))
		end
	end
end

function SchwarmManager:getSchwarmManagerXML()
	local SManXml;
	self.gameFolderPath = getUserProfileAppPath()
	self.inputBindingsSchwarmManagerXMLFilePath = self.gameFolderPath .. '/InputBindings_SchwarmManager.xml';
	local filePath = self.inputBindingsSchwarmManagerXMLFilePath;
	if filePath ~= nil then
		if fileExists(filePath) then
			SManXml = loadXMLFile("InputBindings_SchwarmManagerXml", filePath)
		else
			print("## Courseplay:SchwarmManager:Error: no InputBindings_SchwarmManager.xml found")
		end
	else
		--this is a problem...
		-- File stays nil
	end
	return SManXml
end

function SchwarmManager:init(vehicle)
	self:getInputBindingsFromXML()
	self.activeDrivers = {}
	self.driversToStart = {}
	self.driversToStop = {}
	self.driversToPause ={}
	self.vehicleIdToStart = 1
	self.startAll = false
	self.stopAll = false
	self.pausedAll = false
	self.debugActive = true
end

g_schwarmManager = SchwarmManager()

function SchwarmManager:onInputEvent(unicode, symbol, modifier, isDown)
	if Input.keyPressedState[SchwarmManager.inputBindings.modifier] then
		if isDown then
			self:debug(string.format("courseplay:onKeyEvent %s: unicode(%s), sym(%s), modifier(%s), isDown(%s)",tostring(Input.keyIdToIdName[symbol]),tostring(unicode),tostring(symbol),tostring(modifier),tostring(isDown)))
			if symbol == SchwarmManager.inputBindings.startAll then
				self.debug(("call self:setStartAll()"))
				self:setStartAll()
			elseif symbol == SchwarmManager.inputBindings.stopAll then
				self.debug(("call self:setStopAll()"))
				self:setStopAll()
			elseif symbol == SchwarmManager.inputBindings.togglePausedAll then
				self.debug(("call self:togglePausedAll()"))
				self:togglePausedAll()
			elseif Input.keyPressedState[SchwarmManager.inputBindings.startSingle] then
				local number = self:getNumberFromSymbol(symbol)
				if number  ~= nil  then
					self.debug((string.format("call self:startSingle(%d)",number)))
					self:startSingle(number)
				end
			elseif Input.keyPressedState[SchwarmManager.inputBindings.stopSingle] then
				local number = self:getNumberFromSymbol(symbol)
				if number  ~= nil  then
					self.debug((string.format("call self:stopSingle(%d)",number)))
					self:stopSingle(number)
				end
			elseif Input.keyPressedState[SchwarmManager.inputBindings.togglePausedSingle] then
				local number = self:getNumberFromSymbol(symbol)
				if number  ~= nil  then
					self.debug((string.format("call self:togglePausedSingle(%d)",number)))
					self:togglePausedSingle(number)
				end
			elseif Input.keyPressedState[SchwarmManager.inputBindings.jumpTo] then
				local number = self:getNumberFromSymbol(symbol)
				if number  ~= nil  then
					self.debug((string.format("call self:jumpToVehicle(%d)",number)))
					self:jumpToVehicle(number)
				end
			elseif Input.keyPressedState[SchwarmManager.inputBindings.toggleDebugMode] then
				self.debug(("call self:toggleDebugMode()"))
				self:toggleDebugMode()
			end

		end
	end
end

function SchwarmManager:onUpdate()
	self:enableFlightMode()

	if self:getIsStartAllSet() then
		self:updateStartingAll()
	end
	if self:getIsStopAllSet() then
		self:updateStoppingAll()
	end
	if self:getIsPausedAll() then
		self:updatePausingAll()
	end
	if self:getIsStopSingleSet() then
		self:updateStoppingSingle()
	end
	if self:getIsPausedSingleSet() then
		self:updatePausingSingle()
	end
end

--starting all
function SchwarmManager:setStartAll()
	if #self.activeDrivers ~=0 then
		self:resetStartAll()
		return
	end
	self.startAll = true
	self.vehicleIdToStart = 1
	self.driversToStart = self:getDriversToStart()
end

function SchwarmManager:resetStartAll()
	self.startAll = false
end

function SchwarmManager:getIsStartAllSet()
	return self.startAll
end

function SchwarmManager:updateStartingAll()
	local vehicle = self.driversToStart[self.vehicleIdToStart]
	if vehicle.cp.driver then
		if self.vehicleIdToStart > 1 then
			--TODO check whether the vehicle is ok for start (course loaded, driver set up ....)
			--TODO only start the schwarm group with the set groupId
			local lastVehicle = self.driversToStart[self.vehicleIdToStart -1]
			if lastVehicle.cp.driver:isOnField() or courseplay:distanceToObject(vehicle, lastVehicle) > vehicle.cp.convoy.minDistance  then
				if #self.driversToStart == self.vehicleIdToStart then
					self:resetStartAll()
				end
				self:setStartOrder(vehicle)
			end
		else
			self:setStartOrder(vehicle)
		end
	end
end

function SchwarmManager:setStartOrder(vehicle)
	courseplay:start(vehicle)
	table.insert(self.activeDrivers,vehicle)
	self.vehicleIdToStart = self.vehicleIdToStart +1
end

function SchwarmManager:getDriversToStart()
	local indexList = {}
	local rawDriversToStart ={}
	local driversToStartOutput = {}
	for _, vehicle in pairs(g_currentMission.enterables) do
		--TODO only start the schwarm group with the set groupId
		if vehicle.cp.schwarmId ~= nil and vehicle.cp.schwarmId ~= 0 then
			rawDriversToStart[vehicle.cp.schwarmId] = vehicle
			table.insert(indexList,vehicle.cp.schwarmId)
		end
	end
	table.sort(indexList)
	for i=1,#indexList do
		table.insert(driversToStartOutput,rawDriversToStart[indexList[i]])
	end
	return driversToStartOutput
end

--stopping all
function SchwarmManager:setStopAll()
	self.stopAll = true
	self.driversToStart = {}
end

function SchwarmManager:resetStopAll()
	self.stopAll = false
end

function SchwarmManager:getIsStopAllSet()
	return self.stopAll
end

function SchwarmManager:updateStoppingAll()
	for i,vehicle in pairs (self.activeDrivers) do
		local driver = vehicle.cp.driver
		driver:hold()
		if driver:isStopped() then
			--print("stopping: "..tostring(i))
			self:setStopOrder(vehicle)
		end
	end
	if #self.activeDrivers == 0 then
		--print("stopping finished")
		self:resetStopAll()
	end
end

function SchwarmManager:setStopOrder(vehicle)
	courseplay:stop(vehicle)
	table.remove(self.activeDrivers,self:getIndexfromVehicle(vehicle))
end

--pausing all
function SchwarmManager:togglePausedAll()
	self.pausedAll = not self.pausedAll
end

function SchwarmManager:getIsPausedAll()
	return self.pausedAll
end

function SchwarmManager:updatePausingAll()
	for _,vehicle in pairs (self.activeDrivers) do
		local driver = vehicle.cp.driver
		driver:hold()
	end
end

function SchwarmManager:startSingle(idToStart)
	self.driversToStart = self:getDriversToStart()
	local vehicle = self:getVehicleFromId(self.driversToStart,idToStart)
	if vehicle ~= nil and self:isNotActive(vehicle) then
		self:setStartOrder(vehicle)
	end
end

function SchwarmManager:stopSingle(idToStop)
	local vehicle = self:getVehicleFromId(self.activeDrivers,idToStop)
	if vehicle ~= nil and not self:isNotActive(vehicle) then
		self.driversToStop[idToStop] = vehicle
	end
end
function SchwarmManager:getIsStopSingleSet()
	for _,_ in pairs (self.driversToStop) do
		return true
	end
	return false
end

function SchwarmManager:updateStoppingSingle()
	for index,vehicle in pairs (self.driversToStop)do
		local driver = vehicle.cp.driver
		driver:hold()
		if driver:isStopped() then
			--print("stopping: "..tostring(i))
			self:setStopOrder(vehicle)
			self.driversToStop[index]= nil
		end
	end
end

function SchwarmManager:togglePausedSingle(idToPause)
	local vehicle = self:getVehicleFromId(self.activeDrivers,idToPause)
	if self.driversToPause[idToPause] then
		self.driversToPause[idToPause] = nil
	else
		self.driversToPause[idToPause] = vehicle
	end
end

function SchwarmManager:getIsPausedSingleSet()
	for _,_ in pairs (self.driversToPause) do
		return true
	end
	return false
end

function SchwarmManager:updatePausingSingle()
	for _,vehicle in pairs (self.driversToPause) do
		local driver = vehicle.cp.driver
		driver:hold()
	end
end

--activate the drone flight mode in update because init() is too early
function SchwarmManager:enableFlightMode()
	--activate the flight mode
	if not g_flightAndNoHUDKeysEnabled then
		g_currentMission.player:consoleCommandToggleFlightAndNoHUDMode()
		print("## Courseplay:SchwarmManager: flight mode enabled")
	end
end

function SchwarmManager:jumpToVehicle(idToJumpTo)
local targetVehicle = self:getVehicleFromId(g_currentMission.enterables,idToJumpTo)
	if targetVehicle ~= nil then
		courseplay:goToVehicle(nil, targetVehicle)
	end
end

--Debug
function SchwarmManager:toggleDebugMode()
	self.debugActive = not self.debugActive
end

function SchwarmManager:debug(text)
	if self.debugActive then
		print(text)
	end
end

-- helpers
function SchwarmManager:getNumberFromSymbol(symbol)
local number = tonumber(string.sub(Input.keyIdToIdName[symbol], 8))
	return number
end

function SchwarmManager:getVehicleFromId(driversList, idToStart)
	for i=1,#driversList do
		local vehicle = driversList[i]
		if vehicle.cp.schwarmId == idToStart then
			return vehicle
		end
	end
end

function SchwarmManager:getIndexfromVehicle(vehicle)
	for i=1,#self.activeDrivers do
		if self.activeDrivers[i] == vehicle then
			return i
		end
	end

end
function SchwarmManager:isNotActive(vehicle)
	for i=1,#self.activeDrivers do
		if self.activeDrivers[i] == vehicle then
			return false
		end
	end
	return true
end