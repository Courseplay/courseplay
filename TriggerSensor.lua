
---@class TriggerSensor
TriggerSensor = CpObject()
TriggerSensor.TRIGGER_RAYCAST_DISTANCE = 10

---@param driver AIDriver
---@param vehicle table
function TriggerSensor:init(driver,vehicle)
	self.driver = driver 
	self.vehicle = vehicle
	self.totalVehicleLength = AIDriverUtil.getVehicleAndImplementsTotalLength(self.vehicle)
	self.triggers = {}
	self.numTriggers = 0
	self.debugChannel = courseplay.DBG_TRIGGERS
end

function TriggerSensor:debug(...)
	courseplay.debugVehicle(self.debugChannel,self.vehicle,...)
end

function TriggerSensor:debugEnabled()
	return courseplay.debugChannels[self.debugChannel]
end

function TriggerSensor:onDraw()
	if not self:debugEnabled() then 
		return
	end
	local i = 0
	local y = 0.5
	for trigger,data in pairs(self.triggers) do 
		y = self:renderText(y,0.4,"%d: Trigger(%s), dist: %.2f",i,tostring(getName(data.triggerID)),data.distanceUntilFound)
		i = i+1
	end
	y = self:renderText(y,0.4,"Current triggers: %d",self.numTriggers)
	y = self:renderText(y,0.4,"Total vehicle length: %.2f",self.totalVehicleLength)
	y = self:renderText(y,0.4,"Distance Traveled: %.2f",self.driver:getDistanceMovedSinceStart() or 0)
end
	
function TriggerSensor:renderText(y,xOffset,text,...)
	renderText(xOffset and 0.3+xOffset or 0.3,y,0.02,string.format(text,...))
	return y-0.02
end

function TriggerSensor:onUpdate(dt)
	self:updateTriggers()
end

function TriggerSensor:updateTriggers()
	for trigger,data in pairs(self.triggers) do 
		if self:hasTriggerPassed(data.distanceUntilFound) then 
			self.triggers[trigger] = nil
			self.numTriggers = math.max(self.numTriggers-1,0) 
			self:debug("Removed trigger(%s)",tostring(getName(data.triggerID)))
		end
	end
end

function TriggerSensor:hasTriggerPassed(distanceUntilFound)
	return (distanceUntilFound + self.TRIGGER_RAYCAST_DISTANCE + self.totalVehicleLength) < self.driver:getDistanceMovedSinceStart() 
end

---@param trigger table 
---@param triggerID number
function TriggerSensor:addTrigger(trigger,triggerID) 
	self.triggers[trigger] = {
		triggerID = triggerID,
		distanceUntilFound = self.driver:getDistanceMovedSinceStart()
	}
	self:debug("Added trigger(%s)",tostring(getName(triggerID)))
	self.numTriggers = self.numTriggers + 1
end

function TriggerSensor:isNearTriggers()
	return self.numTriggers>0
end


--- Loading/ filling trigger callback
---@param transformId number 
---@param x number 
---@param y number 
---@param z number 
---@param distance number
function TriggerSensor:loadingFillingTriggerCallback(transformId, x, y, z, distance)
	if CpManager.confirmedNoneSpecialTriggers[transformId] then
		return true;
	end;
	local objectName = tostring(getName(transformId));
	if self:debugEnabled() then
		cpDebug:drawPoint(x, y, z, 1, 1, 0);
	end;

	local loadingTriggers = Triggers.getLoadingTriggers()
	local fillingTriggers = Triggers.getFillTriggers()
	local trigger = loadingTriggers[transformId] or fillingTriggers[transformId]
	if trigger and not self.triggers[trigger] then
		self:addTrigger(trigger, transformId)
		return false
	end
			
	CpManager.confirmedNoneSpecialTriggers[transformId] = true
	CpManager.confirmedNoneSpecialTriggersCounter = CpManager.confirmedNoneSpecialTriggersCounter + 1
	self:debug("added %d (%s) to trigger blacklist -> total = %d",transformId,objectName, CpManager.confirmedNoneSpecialTriggersCounter)
	return true
end

function TriggerSensor:raycastLoadingFillingTriggers()
	local raycastDistance = self.TRIGGER_RAYCAST_DISTANCE
	local dx,dz = self.driver.course:getDirectionToWPInDistance(self.driver.ppc:getCurrentWaypointIx(),self.vehicle,raycastDistance)
	local x,y,z,nx,ny,nz = courseplay:getTipTriggerRaycastDirection(self.vehicle,dx,dz,raycastDistance)	

	self:raycast(x,y,z, nx,ny,nz, "loadingFillingTriggerCallback", raycastDistance)

	local directionNode = self.driver:getDirectionNode()
	local ny = 0

	-- raycast start point in front of vehicle
	local x1,_,z1 = localToWorld(directionNode,2,0,0)
	local x2,_,z2 = localToWorld(directionNode,-2,0,0)

	local dx1,dz1 = x1+nx*raycastDistance,z1+nz*raycastDistance
	local dx2,dz2 = x2+nx*raycastDistance,z2+nz*raycastDistance

	local nx1,nz1 = MathUtil.vector2Normalize(dx2 - x1, dz2 - z1)
	local nx2,nz2 = MathUtil.vector2Normalize(dx1 - x2, dz1 - z2)

	--create a hammerhead raycast to get small triggers
	nx, ny, nz = localDirectionToWorld(directionNode, 1, 0, 0)
	self:raycast(dx2, y+2, dz2, nx, ny, nz,"loadingFillingTriggerCallback", 4)
end

---@param x number 
---@param y number 
---@param z number 
---@param nx number 
---@param ny number 
---@param nz number 
---@param callback function
---@param raycastDistance number
function TriggerSensor:raycast(x,y,z, nx,ny,nz, callback, raycastDistance)
	if self:debugEnabled() then
		cpDebug:drawLine(x,y,z, 1,0,0, x+(nx*raycastDistance),y+(ny*raycastDistance),z+(nz*raycastDistance))
	end
	raycastAll(x,y,z, nx,ny,nz, callback, raycastDistance, self)
end