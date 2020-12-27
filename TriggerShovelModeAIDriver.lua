
--[[
handles "mode9": Fill and empty shovel at normal loading trigger, not at bunkersilo
--------------------------------------
0)  Course setup:
	a) Start in front of silo
	b) drive forwards to bunker or unloading position for trailer, set waiting point #1 and unload
	c) drive backwards, turn, drive forwards until before start

1)  drive course until trigger is found, let triggerHandler handle the loading : STATE_TRANSPORT
2)  if triggerHandler is finished drive until waiting point is reached : STATE_TRANSPORT
3)  do a raycast and wait until we find a unloading trigger or trailer : STATE_WAIT_FOR_TARGET
4)  drive to the trigger and unload there : STATE_START_UNLOAD, STATE_WAIT_FOR_UNLOADREADY, STATE_GO_BACK_FROM_EMPTYPOINT
5) 	if unloading is finished drive the course until 1) is active : STATE_TRANSPORT

NOTE: although lx and lz are passed in as parameters, they are never used.
]]


TriggerShovelModeAIDriver = CpObject(ShovelModeAIDriver)

TriggerShovelModeAIDriver.MAX_SPEED_IN_LOADING_TRIGGER = 5

function TriggerShovelModeAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setTriggerHandlerShovelModeAIDriverContent(self.vehicle)
end

function TriggerShovelModeAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course for TriggerShovelModeAIDriver
	return false
end

function TriggerShovelModeAIDriver:start(startingPoint)	
	--no shovel was found so return
	self:findShovel(self.vehicle)
	if not self.shovel then 
		self:error("Error: shovel not found!!")
		courseplay:stop(self.vehicle)
		return
	end
	self:setShovelState(self.states.STATE_TRANSPORT, 'setup');
	self:validateWaitpoints()
	AIDriver.start(self,startingPoint)
	self.vehicle.cp.settings.stopAtEnd:set(false)
	self:disableCollisionDetection()
end

-- get the needed waitPoint
function TriggerShovelModeAIDriver:validateWaitpoints()
	local numWaitPoints = 0
	for i,wp in pairs(self.vehicle.Waypoints) do
		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
		end;
		if numWaitPoints == 1 and self.shovelEmptyPoint == nil then
			self.shovelEmptyPoint = i;
		end;
	end
end

function TriggerShovelModeAIDriver:drive(dt)
	-- are shovel positions okay and we have one waitpoint ?
	local notAllowedToDrive = false
	if not self:checkShovelPositionsValid() or not self:checkWaypointsValid() then
		self:setSpeed(0)
	end
	if self:getSiloSelectedFillTypeSetting():isEmpty() then 
		-- no filltype selected => wait until we have one
		self:setSpeed(0)
		self:setInfoText('NO_SELECTED_FILLTYPE')
	else 
		self:clearInfoText('NO_SELECTED_FILLTYPE')
	end
	-- drive the course normally and let triggerHandler do all the loading stuff
	if self.shovelState == self.states.STATE_TRANSPORT then 
		self.triggerHandler:enableFillTypeLoading()
		-- near trigger reduce the speed so we don't miss the trigger
		if self.triggerHandler:isInTrigger() then
			self:setSpeed(self.MAX_SPEED_IN_LOADING_TRIGGER)
		else 
			-- we are close to the unload waitpoint and are behind the loading trigger
			if self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, self.shovelEmptyPoint) < 15 and self:iAmBeforeEmptyPoint() and self:iAmBehindFillPoint() then
				self:setShovelState(self.states.STATE_WAIT_FOR_TARGET)
			end
		end
		--backup for starting somewhere in between
		if not self:setShovelToPositionFinshed(3,dt) then
			self:hold()
		end
	-- close to the unload waitpoint, so set pre unload shovel position and do a raycast for unload triggers, trailers
	elseif self.shovelState == self.states.STATE_WAIT_FOR_TARGET then
		self:driveWaitForTarget(dt)
		self.triggerHandler:disableFillTypeLoading()
	-- drive to the unload trigger/ trailer
	elseif self.shovelState == self.states.STATE_START_UNLOAD then
		notAllowedToDrive =	self:driveStartUnload(dt)
	-- handle unloading
	elseif self.shovelState == self.states.STATE_WAIT_FOR_UNLOADREADY then
		self:driveWaitForUnloadReady(dt)
	-- reverse back to the course
	elseif self.shovelState == self.states.STATE_GO_BACK_FROM_EMPTYPOINT then
		self:driveGoBackFromEmptyPoint(dt)
	end
	if not notAllowedToDrive then
		AIDriver.drive(self,dt)
	end
end

function TriggerShovelModeAIDriver:onDraw()
	if self:isDebugActive() and self.shovel then 
		local y = 0.5
		y = self:renderText(y,"state: "..tostring(self.shovelState.name),0.4)
		y = self:renderText(y,"isShovelFull: "..tostring(self:getIsShovelFull() == true),0.4)
		y = self:renderText(y,"isShovelEmpty: "..tostring(self:getIsShovelEmpty() == true),0.4)
		y = self:renderText(y,"iAmBehindFillPoint: "..tostring(self:iAmBehindFillPoint() == true),0.4)
		y = self:renderText(y,"iAmBeforeEmptyPoint: "..tostring(self:iAmBeforeEmptyPoint() == true),0.4)
	end
	AIDriver.onDraw(self)
end

function TriggerShovelModeAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeShovelModeDriver
end

-- the same as AIDriver:onWaypointPassed without the wait msg
function TriggerShovelModeAIDriver:onWaypointPassed(ix)
	if self.course:isWaitAt(ix+1) then
		
	elseif ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	end
end


-- disable ShovelModeAIDriver override
function TriggerShovelModeAIDriver:onWaypointChange(ix)
	AIDriver.onWaypointChange(self,ix)
end

--check for a needed waitpoint
function TriggerShovelModeAIDriver:checkWaypointsValid()
	if self.shovelEmptyPoint == nil then
		courseplay:setInfoText(self.vehicle, 'COURSEPLAY_NO_VALID_COURSE');
		return false;
	end;
	return true
end

function TriggerShovelModeAIDriver:iAmBehindFillPoint()
	return self.ppc and self.ppc:getCurrentWaypointIx() > 5
end

function TriggerShovelModeAIDriver:iAmBeforeEmptyPoint()
	return self.ppc and self.ppc:getCurrentWaypointIx() < self.shovelEmptyPoint
end

-- disable ShovelModeAIDriver override
function TriggerShovelModeAIDriver:getSpeed()
	if self:getCanGoWithStreetSpeed() then
		return AIDriver.getSpeed(self)
	else
		return self.refSpeed
	end
end
--slow speed to make sure small trigger,like the potato sorter gets hit correctly
function TriggerShovelModeAIDriver:getDriveStartUnloadRefSpeed()
	return 3
end