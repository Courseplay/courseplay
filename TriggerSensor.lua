
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
	y = self:renderText(y,0.4,"Has bale trigger: %s",tostring(self.baleTrigger ~= nil))
end
	
function TriggerSensor:renderText(y,xOffset,text,...)
	renderText(xOffset and 0.3+xOffset or 0.3,y,0.02,string.format(text,...))
	return y-0.02
end

function TriggerSensor:onUpdate(dt)
	self:updateTriggers()
end

--- Removes the physical passed triggers, except bunker silos.
function TriggerSensor:updateTriggers()
	for trigger,data in pairs(self.triggers) do 
		if self:hasTriggerPassed(data.distanceUntilFound) then 
			self.triggers[trigger] = nil
			self.numTriggers = math.max(self.numTriggers-1,0) 
			self:debug("Removed trigger(%s)",tostring(getName(data.triggerID)))
			if trigger == self.baleTrigger then 
				self.baleTrigger = nil
			end
		end
	end
end

--- Calculates if the trigger is completely passed with a small margin. 
---@param distanceUntilFound number
---@return boolean triggerPassed 
function TriggerSensor:hasTriggerPassed(distanceUntilFound)
	return (distanceUntilFound + self.TRIGGER_RAYCAST_DISTANCE + self.totalVehicleLength) < self.driver:getDistanceMovedSinceStart() 
end

--- Adds a new found trigger.
---@param trigger table 
---@param triggerID number
---@param isBaleTrigger boolean used to save this trigger in an additional variable for direct access.
function TriggerSensor:addTrigger(trigger,triggerID,isBaleTrigger) 
	self.triggers[trigger] = {
		triggerID = triggerID,
		distanceUntilFound = self.driver:getDistanceMovedSinceStart()
	}
	self:debug("Added trigger(%s)",tostring(getName(triggerID)))
	self.numTriggers = self.numTriggers + 1
	if isBaleTrigger then 
		self.baleTrigger = trigger
	end
end

function TriggerSensor:isNearTriggers()
	return self.numTriggers>0
end

function TriggerSensor:getCurrentBaleUnloadingTrigger()
	return self.baleTrigger
end

function TriggerSensor:hasCurrentBaleUnloadingTrigger()
	return self.baleTrigger ~= nil
end

--- Loading/ filling trigger callback
---@param transformId number 
---@param x number 
---@param y number 
---@param z number 
---@param distance number
function TriggerSensor:raycastCallback(transformId, x, y, z, distance)
	if CpManager.confirmedNoneSpecialTriggers[transformId] then
		return true;
	end;
	local objectName = tostring(getName(transformId));
	if self:debugEnabled() then
		cpDebug:drawPoint(x, y, z, 1, 1, 0);
	end;


	--- Handle loading, filling and normal unloading triggers.
	local loadingTriggers = Triggers.getLoadingTriggers()
	local fillingTriggers = Triggers.getFillTriggers()
	local unloadingTriggers = Triggers.getUnloadingTriggers()
	local baleUnloadingTriggers = Triggers.getBaleUnloadTriggers()
	local trigger = loadingTriggers[transformId] or fillingTriggers[transformId] or unloadingTriggers[transformId] or baleUnloadingTriggers[transformId]
	if trigger then 
		if not self.triggers[trigger] then
			local isBaleTrigger = baleUnloadingTriggers[transformId]
			self:addTrigger(trigger, transformId,isBaleTrigger)
			return false
		end
		--- Trigger was already found ignore it. 
		return false
	end

	--- Handle bunker silos 
	local bunkerSilos = Triggers.getBunkerSilos()
	trigger = bunkerSilos[transformId]
	if trigger then 
		if trigger.state ~= BunkerSilo.STATE_FILL then 
			--- Bunker silo state not correct to accept unloading into.
			return false
		end
		local trailerFillTypes = AIDriverUtil.getAllFillTypes(self.vehicle)
		if trailerFillTypes[trigger.inputFillType] or trigger.inputFillType == FillType.UNKNOWN then 
			--- Bunker silo accepts current loaded fill type.
			
			--- Legancy code needed for unloading at bunker silos.
			--- TODO: Rework this code.
			self.vehicle.cp.currentTipTrigger = trigger;
			self.vehicle.cp.currentTipTrigger.cpActualLength = courseplay:nodeToNodeDistance(self.driver:getDirectionNode(), transformId)*2

		end
		return false
	end
			
	CpManager.confirmedNoneSpecialTriggers[transformId] = true
	CpManager.confirmedNoneSpecialTriggersCounter = CpManager.confirmedNoneSpecialTriggersCounter + 1
	self:debug("added %d (%s) to trigger blacklist -> total = %d",transformId,objectName, CpManager.confirmedNoneSpecialTriggersCounter)
	return true
end

--- Raycast to find triggers in front of the driver direction.
---@param isHammerHeadRaycastAllowed boolean used to detect small loading triggers, as their hit box can be relative small.
function TriggerSensor:raycastTriggers(isHammerHeadRaycastAllowed)
	local raycastDistance = self.TRIGGER_RAYCAST_DISTANCE
	local dx,dz = self.driver.course:getDirectionToWPInDistance(self.driver.ppc:getCurrentWaypointIx(),self.vehicle,raycastDistance)
	local x,y,z,nx,ny,nz = courseplay:getTipTriggerRaycastDirection(self.vehicle,dx,dz,raycastDistance)	

	self:raycast(x,y,z, nx,ny,nz, "raycastCallback", raycastDistance)

	if isHammerHeadRaycastAllowed then
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
		self:raycast(dx2, y+2, dz2, nx, ny, nz,"raycastCallback", 4)
	end
end

--- Custom Raycast function with debug.
---@param x number 
---@param y number 
---@param z number 
---@param nx number 
---@param ny number 
---@param nz number 
---@param callback string trigger sensor callback function.
---@param raycastDistance number
function TriggerSensor:raycast(x,y,z, nx,ny,nz, callback, raycastDistance)
	if self:debugEnabled() then
		cpDebug:drawLine(x,y,z, 1,0,0, x+(nx*raycastDistance),y+(ny*raycastDistance),z+(nz*raycastDistance))
	end
	raycastAll(x,y,z, nx,ny,nz, callback, raycastDistance, self)
end