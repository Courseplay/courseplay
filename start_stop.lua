local curFile = 'start_stop.lua';

-- starts driving the course only runs on the server
function courseplay:start(self)
	if g_server == nil then 
		return
	end
		
	if not CpManager.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] then			-- ???
		CpManager.trafficCollisionIgnoreList[g_currentMission.terrainRootNode] = true;
	end;

	self.cp.numWayPoints = #self.Waypoints;
	if self.cp.numWaypoints < 1 then
		return
	end
	--setEngineState needed or AIDriver handling this ??
	courseplay:setEngineState(self, true);
	self.cp.saveFuel = false

	courseplay.alreadyPrinted = {}

	self.cpTrafficCollisionIgnoreList = {}

	courseplay:resetTools(self)

	if self.cp.waypointIndex < 1 then
		courseplay:setWaypointIndex(self, 1);
	end

	-- show arrow
--	self.cp.distanceCheck = true
	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.cp.directionNode);

	-- TODO: temporary bandaid here for the case when the legacy waypointIndex isn't set correctly
	if self.cp.waypointIndex > #self.Waypoints then
		courseplay.infoVehicle(self, 'Waypoint index %d reset to %d', self.cp.waypointIndex, #self.Waypoints)
		self.cp.waypointIndex = #self.Waypoints
	end
	-- position of next waypoint
	local cx, cz = self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz
	-- distance (in any direction)
	local dist = courseplay:distance(ctx, ctz, cx, cz)

	local numWaitPoints = 0
	local numUnloadPoints = 0
	local numCrossingPoints = 0
	self.cp.waitPoints = {};
	self.cp.unloadPoints = {};

	-- modes 4/6 without start and stop point, set them at start and end, for only-on-field-courses
	if (self.cp.mode == 4 or self.cp.mode == 6) then
		if numWaitPoints == 0 or self.cp.startWork == nil then
			self.cp.startWork = 1;
		end;
		if numWaitPoints == 0 or self.cp.stopWork == nil then
			self.cp.stopWork = self.cp.numWaypoints;
		end;
	end;
	self.cp.numWaitPoints = numWaitPoints;
	self.cp.numUnloadPoints = numUnloadPoints;
	self.cp.numCrossingPoints = numCrossingPoints;
	courseplay:debug(string.format("%s: numWaitPoints=%d, waitPoints[1]=%s, numCrossingPoints=%d",
		nameNum(self), self.cp.numWaitPoints, tostring(self.cp.waitPoints[1]), numCrossingPoints), courseplay.DBG_COURSES);

	-- set waitTime to 0 if necessary
	if not courseplay:getCanHaveWaitTime(self) and self.cp.waitTime > 0 then
		courseplay:changeWaitTime(self, -self.cp.waitTime);
	end;

	if self.cp.waypointIndex > 2 and self.cp.mode ~= 4 and self.cp.mode ~= 6 and self.cp.mode ~= 8 then
		courseplay:setDriveUnloadNow(self, true);
	elseif self.cp.mode == 4 or self.cp.mode == 6 then
		courseplay:setDriveUnloadNow(self, false);
		self.cp.hasUnloadingRefillingCourse = self.cp.numWaypoints > self.cp.stopWork + 7;
		if  self.Waypoints[self.cp.stopWork].cx == self.Waypoints[self.cp.startWork].cx
		and self.Waypoints[self.cp.stopWork].cz == self.Waypoints[self.cp.startWork].cz then -- TODO: VERY unsafe, there could be LUA float problems (e.g. 7 + 8 = 15.000000001)
			self.cp.finishWork = self.cp.stopWork-5
		else
			self.cp.finishWork = self.cp.stopWork
		end

		-- NOTE: if we want to start the course but catch one of the last 5 points ("returnToStartPoint"), make sure we get wp 2
		if self.cp.settings.startingPoint:is(StartingPointSetting.START_AT_NEAREST_POINT) and self.cp.finishWork ~= self.cp.stopWork and self.cp.waypointIndex > self.cp.finishWork and self.cp.waypointIndex <= self.cp.stopWork then
			courseplay:setWaypointIndex(self, 2);
		end
	elseif self.cp.mode == 8 then
		courseplay:setDriveUnloadNow(self, false);
	end

	if self.cp.settings.startingPoint:is(StartingPointSetting.START_AT_FIRST_POINT) then
		if self.cp.mode == 2 or self.cp.mode == 3 then
			-- TODO: really? 3?
			courseplay:setWaypointIndex(self, 3);
			courseplay:setDriveUnloadNow(self, true);
		else
			courseplay:setWaypointIndex(self, 1);
		end
	end;

	courseplay:updateAllTriggers();

	self.cp.cruiseControlSpeedBackup = self:getCruiseControlSpeed();

	-- ok i am near the waypoint, let's go
	self.cp.savedCheckSpeedLimit = self.checkSpeedLimit;
	self.checkSpeedLimit = false
	---Do we need to set distanceCheck==true at the beginning of courseplay:start() and set now set it to false 50 lines later ??
--	self.cp.distanceCheck = false

	self.cp.totalLength, self.cp.totalLengthOffset = courseplay:getTotalLengthOnWheels(self);

	courseplay:validateCanSwitchMode(self);



	-- and another ugly hack here as when settings.lua setAIDriver() is called the bale loader does not seem to be
	-- attached and I don't have the motivation do dig through the legacy code to find out why
	if self.cp.mode == courseplay.MODE_FIELDWORK then
		self.cp.driver:delete()
		self.cp.driver = UnloadableFieldworkAIDriver.create(self)
	end
	---Make sure the clients and the server have the same farmId
	local farmIndex = self.spec_enterable.controllerFarmId or self:getOwnerFarmId()
	courseplay.onStartCpAIDriver(self,nil, false, farmIndex)
	self.cp.driver:start(self.cp.settings.startingPoint)
end;

-- stops driving the course only runs on the server
function courseplay:stop(self)
	if g_server == nil then 
		return
	end
	-- Stop AI Driver
	if self.cp.driver then
		self.cp.driver:dismiss()
	end
	
	--is this one still used ?? 
	if g_currentMission.missionInfo.automaticMotorStartEnabled and self.cp.saveFuel and not self.spec_motorized.isMotorStarted then
		courseplay:setEngineState(self, true);
		self.cp.saveFuel = false;
	end
	if courseplay:getCustomTimerExists(self,'fuelSaveTimer')  then
		--print("reset existing timer")
		courseplay:resetCustomTimer(self,'fuelSaveTimer',true)
	end

	if self.cp.directionNodeToTurnNodeLength ~= nil then
		self.cp.directionNodeToTurnNodeLength = nil
	end

	---This is not working correctly on the server!
	if self.cp.cruiseControlSpeedBackup then		
		self.spec_drivable.cruiseControl.speed = self.cp.cruiseControlSpeedBackup; -- NOTE JT: no need to use setter or event function - Drivable's update() checks for changes in the var and calls the event itself
		self.cp.cruiseControlSpeedBackup = nil;
	end; 

		
	self.spec_drivable.cruiseControl.minSpeed = 1
	self.cp.settings.forcedToStop:set(false)
	self.cp.waitingForTrailerToUnload = false
	
	---Is this one still used as cp.isTurning isn't getting set to true ??
	self.cp.isTurning = nil;
	courseplay:clearTurnTargets(self);
	self.cp.fillTrigger = nil;
	self.cp.hasMachineToFill = false;

	-- resetting variables
	self.checkSpeedLimit = self.cp.savedCheckSpeedLimit;
	courseplay:resetTipTrigger(self);

	if self.cp.checkReverseValdityPrinted then
		self.cp.checkReverseValdityPrinted = false

	end
	
	self.cp.curSpeed = 0;

	self.spec_motorized.motor.maxRpmOverride = nil;
	self.cp.startWork = nil
	self.cp.stopWork = nil
	self.cp.hasFinishedWork = nil
	self.cp.turnTimeRecorded = nil;	
	self.cp.hasUnloadingRefillingCourse = false;
	self.cp.prevFillLevelPct = nil;
	courseplay:setSlippingStage(self, 0);
	courseplay:resetCustomTimer(self, 'slippingStage1');
	courseplay:resetCustomTimer(self, 'slippingStage2');

	self.cp.hasBaleLoader = false;
	
	if self.cp.manualWorkWidth ~= nil then
		courseplay:changeWorkWidth(self, nil, self.cp.manualWorkWidth, true)
		if self.cp.hud.currentPage == courseplay.hud.PAGE_COURSE_GENERATION then
			courseplay.hud:setReloadPageOrder(self, self.cp.hud.currentPage, true);
		end
	end
	
	self.cp.totalLength, self.cp.totalLengthOffset = 0, 0;
	self.cp.numWorkTools = 0;
	
	--validation: can switch mode?
	courseplay:validateCanSwitchMode(self);
	courseplay.onStopCpAIDriver(self,AIVehicle.STOP_REASON_USER)
	-- reactivate load/add/delete course buttons
	--courseplay.buttons:setActiveEnabled(self, 'page2');
end

---TODO: move this to TrafficCollision.lua
function courseplay:findVehicleHeights(transformId, x, y, z, distance)
	local startHeight = math.max(self.sizeLength,5)
	local height = startHeight - distance
	local vehicle = false
	--print(string.format("found %s (%s)",tostring(getName(transformId)),tostring(transformId)))
	-- if self.cp.aiTrafficCollisionTrigger == transformId then
	if self.aiTrafficCollisionTrigger == transformId then	
		if self.cp.HeightsFoundColli < height then
			self.cp.HeightsFoundColli = height
		end
	elseif transformId == self.rootNode then
		vehicle = true
	elseif getParent(transformId) == self.rootNode and self.aiTrafficCollisionTrigger ~= transformId then
		vehicle = true
	elseif self.cpTrafficCollisionIgnoreList[transformId] or self.cpTrafficCollisionIgnoreList[getParent(transformId)] then
		vehicle = true
	end

	if vehicle and self.cp.HeightsFound < height then
		self.cp.HeightsFound = height
	end

	return true
end

function courseplay:safeSetWaypointIndex( vehicle, newIx )
	for i = newIx, newIx do
		-- don't set it too close to a turn start, 
		if vehicle.Waypoints[ i ] ~= nil and vehicle.Waypoints[ i ].turnStart then
			-- set it to after the turn
			newIx = i + 2
			break
		end	
	end

	if vehicle.cp.waypointIndex > vehicle.cp.numWaypoints then
		courseplay:setWaypointIndex(vehicle, 1);
	else
		courseplay:setWaypointIndex( vehicle, newIx );
	end
end

-- do not remove this comment
-- vim: set noexpandtab:
