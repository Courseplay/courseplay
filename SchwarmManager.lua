
---@class SchwarmManager
SchwarmManager = CpObject()

function SchwarmManager:getInputBindingsFromXML()
	--print("SchwarmManager:getInputBindingsFromXML()")
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
			SchwarmManager.inputBindings[functionToCall] = assignment
			index = index+1;
		end
		print("### Courseplay:SchwarmManager:Inputs loaded from xml:")
		courseplay:printMeThisTable(SchwarmManager.inputBindings,0,5,"### Courseplay:SchwarmManager.inputBindings")
	end
end

function SchwarmManager:getSchwarmManagerXML()
	-- returns the file if success, nil else
	local SManXml;
	self.savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.selectedIndex); -- This should work for both SP, MP and Dedicated Servers
	self.inputBindingsSchwarmManagerXMLFilePath = self.savegameFolderPath .. '/InputBindings_SchwarmManager.xml';
	local filePath = self.inputBindingsSchwarmManagerXMLFilePath;
	if filePath ~= nil then
		if fileExists(filePath) then
			SManXml = loadXMLFile("InputBindings_SchwarmManagerXml", filePath)
		else
			print("### Courseplay:SchwarmManager:Error: no InputBindings_SchwarmManager.xml found")
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
	self.startAll = false
	self.stopAll = false
	self.pausedAll = false
end

g_schwarmManager = SchwarmManager()

function SchwarmManager:onInputEvent(unicode, sym, modifier, isDown)
	--print(string.format("courseplay:onKeyEvent %s: unicode(%s), sym(%s), modifier(%s), isDown(%s)",tostring(Input.keyIdToIdName[sym]),tostring(unicode),tostring(sym),tostring(modifier),tostring(isDown)))
	if isDown then
		if Input.keyIdToIdName[sym] == SchwarmManager.inputBindings.startAll then
			self:setStartAll()
		elseif Input.keyIdToIdName[sym] == SchwarmManager.inputBindings.stopAll then
			self:setStopAll()
		elseif Input.keyIdToIdName[sym] == SchwarmManager.inputBindings.togglePausedAll then
			self:togglePausedAll()
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
	for _,vehicle in pairs (self.activeDrivers) do
		local driver = vehicle.cp.driver
		driver:hold()
		if driver:isStopped() then
			courseplay:stop(vehicle)
			table.remove(self.activeDrivers,i)
		end
	end
	if #self.activeDrivers == 0 then
		self:resetStopAll()
	end
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

function SchwarmManager:enableFlightMode()
	--activate the flight mode
	if not  g_currentMission.player.debugFlightMode then
		g_flightAndNoHUDKeysEnabled = true
		--g_currentMission.player.debugFlightCoolDown = 0
		--g_currentMission.player:onInputDebugFlyToggle()
		-- g_currentMission.player.debugFlightMode = true
	end
end
