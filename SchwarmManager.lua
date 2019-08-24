
---@class SchwarmManager
SchwarmManager = CpObject()

function SchwarmManager:getInputBindingsFromXML()
	--print("SchwarmManager:getInputBindingsFromXML()")
	SchwarmManager.inputBindings = {}
	SchwarmManager.inputBindings.startAll = "KEY_o"
	SchwarmManager.inputBindings.stopAll = "KEY_k"
end

function SchwarmManager:init(vehicle)
	self:getInputBindingsFromXML()
	self.activeDrivers = {}
	self.driversToStart = {}
	self.startAll = false
	self.stopAll = false
end

g_schwarmManager = SchwarmManager()

function SchwarmManager:onInputEvent(unicode, sym, modifier, isDown)
--	print(string.format("courseplay:onKeyEvent %s: unicode(%s), sym(%s), modifier(%s), isDown(%s)",tostring(Input.keyIdToIdName[sym]),tostring(unicode),tostring(sym),tostring(modifier),tostring(isDown)))
	if isDown then
		if Input.keyIdToIdName[sym] == SchwarmManager.inputBindings.startAll then
			self:setStartAll()
		elseif Input.keyIdToIdName[sym] == SchwarmManager.inputBindings.stopAll then
			self:setStopAll()
		end
	end
end

function SchwarmManager:onUpdate()
	if self:getIsStartAllSet() then
		self:updateStartingAll()
	end
	if self:getIsStopAllSet() then
		self:updateStoppingAll()
	end
end

--starting all
function SchwarmManager:setStartAll()
	self.startAll = true
	self.vehicleIdToStart = 1
	self.driversToStart = {}
	for _, vehicle in pairs(g_currentMission.enterables) do
		--TODO only start the schwarm group with the set groupId
		if vehicle.cp.schwarmId ~= nil and vehicle.cp.schwarmId ~= 0 then
			self.driversToStart[vehicle.cp.schwarmId] = vehicle
		end
	end
	for index , vehicle in pairs(self.driversToStart) do
		print("index: "..tostring(index).."startID: "..vehicle.cp.schwarmId)
	end
end
function SchwarmManager:resetStartAll()
	self.startAll = false
end

function SchwarmManager:getIsStartAllSet()
	return self.startAll
end

function SchwarmManager:updateStartingAll()
	local vehicle = self.driversToStart[self.vehicleIdToStart]
	if vehicle.cp.driver and vehicle.cp.schwarmId == self.vehicleIdToStart then
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


--stopping all
function SchwarmManager:setStopAll()
	self.stopAll = true
end

function SchwarmManager:resetStopAll()
	self.stopAll = false
end

function SchwarmManager:getIsStopAllSet()
	return self.stopAll
end

function SchwarmManager: updateStoppingAll()
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
