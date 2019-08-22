
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
end

g_schwarmManager = SchwarmManager()

function SchwarmManager:onInputEvent(unicode, sym, modifier, isDown)
--	print(string.format("courseplay:onKeyEvent %s: unicode(%s), sym(%s), modifier(%s), isDown(%s)",tostring(Input.keyIdToIdName[sym]),tostring(unicode),tostring(sym),tostring(modifier),tostring(isDown)))
	if Input.keyIdToIdName[sym] == SchwarmManager.inputBindings.startAll then
		self:setStartAll()
	elseif Input.keyIdToIdName[sym] == SchwarmManager.inputBindings.stopAll then
		self:stopAll()
	end

end

function SchwarmManager:setStartAll()
	self.startAll = true
	self.vehicleIdToStart = 1
	for _, vehicle in pairs(g_currentMission.enterables) do
		--TODO only start the schwarm group with the set groupId
		if vehicle.cp.schwarmId ~= nil and vehicle.cp.schwarmId ~= 0 then
			self.driversToStart[vehicle.cp.schwarmId] = vehicle
		end
	end
end
function SchwarmManager:resetStartAll()
	self.startAll = false
end

function SchwarmManager:getIsStartAllSet()
	return self.startAll
end

function SchwarmManager: stopAll()
	for i=1,#self.activeDrivers do
		local vehicle = self.activeDrivers[i]
		courseplay:stop(vehicle)
	end

end

function SchwarmManager:onUpdate()
	if self:getIsStartAllSet() then
		self:updateStartingAll()
	end
end

function SchwarmManager:updateStartingAll()
	local vehicle = self.driversToStart[self.vehicleIdToStart]
	if vehicle.cp.driver and vehicle.cp.schwarmId == self.vehicleIdToStart then
		if self.vehicleIdToStart > 1 then
			--TODO check whether the vehicle is ok for start (course loaded, driver set up ....)
			--TODO only start the schwarm group with the set groupId

			local driver = self.activeDrivers[self.vehicleIdToStart -1].cp.driver
			if driver:isOnField() then
				print(string.format("%d is working, start %d",self.vehicleIdToStart -1,self.vehicleIdToStart))
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