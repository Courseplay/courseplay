local curFile = 'start_stop.lua';

-- starts driving the course only runs on the server!
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

	local mode = self.cp.settings.driverMode:get()

	-- modes 4/6 without start and stop point, set them at start and end, for only-on-field-courses
	if (mode == courseplay.MODE_SEED_FERTILIZE or mode == courseplay.MODE_FIELDWORK) then
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

	courseplay:updateAllTriggers();

	---Do we need to set distanceCheck==true at the beginning of courseplay:start() and set now set it to false 50 lines later ??
--	self.cp.distanceCheck = false

	self.cp.totalLength, self.cp.totalLengthOffset = courseplay:getTotalLengthOnWheels(self);

	courseplay:validateCanSwitchMode(self);

	-- and another ugly hack here as when settings.lua setAIDriver() is called the bale loader does not seem to be
	-- attached and I don't have the motivation do dig through the legacy code to find out why
	if mode == courseplay.MODE_FIELDWORK then
		self.cp.driver:delete()
		self.cp.driver = UnloadableFieldworkAIDriver.create(self)
	elseif mode == courseplay.MODE_BUNKERSILO_COMPACTER then 
		--- Not sure if this is needed, might have to check if the AIDriver gets reevaluated after an implement gets attached.
		self.cp.driver:delete()
		self.cp.driver = BunkerSiloAIDriver.create(self)
	end

	self.cp.driver:start(self.cp.settings.startingPoint)
end;

-- stops driving the course only runs on the server!
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


	if self.cp.directionNodeToTurnNodeLength ~= nil then
		self.cp.directionNodeToTurnNodeLength = nil
	end

		
	self.cp.settings.forcedToStop:set(false)
	
	---Is this one still used as cp.isTurning isn't getting set to true ??
	self.cp.isTurning = nil;
	courseplay:clearTurnTargets(self);
	self.cp.fillTrigger = nil;
	self.cp.hasMachineToFill = false;

	-- resetting variables
	courseplay:resetTipTrigger(self);

	if self.cp.checkReverseValdityPrinted then
		self.cp.checkReverseValdityPrinted = false

	end
	
	self.cp.curSpeed = 0;

	self.cp.startWork = nil
	self.cp.stopWork = nil
	courseplay:setSlippingStage(self, 0);
	courseplay:resetCustomTimer(self, 'slippingStage1');
	courseplay:resetCustomTimer(self, 'slippingStage2');

	
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
