local curFile = 'start_stop.lua';

-- starts driving the course
function courseplay:start(self)
	self.currentHelper = HelperUtil.getRandomHelper()

	self.isHired = true;
	self.isHirableBlocked = true;

	self.cp.savedLightsMask  =  self.aiLightsTypesMask;
	self.aiLightsTypesMask = nil; 
	self.cp.forceIsActiveBackup = self.forceIsActive;
	self.forceIsActive = true;
	self.cp.stopMotorOnLeaveBackup = self.stopMotorOnLeave;
	self.stopMotorOnLeave = false;
	self.steeringEnabled = false;
	self.disableCharacterOnLeave = false;

	if self.vehicleCharacter ~= nil and not g_currentMission.missionDynamicInfo.isMultiplayer then --disabled for MP for further investigation (Nil errors in ingame(draw))
		self.vehicleCharacter:delete();
		self.vehicleCharacter:loadCharacter(self.currentHelper.xmlFilename, getUserRandomizedMpColor(self.currentHelper.name))
		if self.isEntered then
			self.vehicleCharacter:setCharacterVisibility(false)
		end
	end
    -- Start the reset character timer.
	courseplay:setCustomTimer(self, "resetCharacter", 300);

		
	if courseplay.isClient then
		return
	end
	self.cp.numWayPoints = #self.Waypoints;
	--self:setCpVar('numWaypoints', #self.Waypoints,courseplay.isClient);
	if self.cp.numWaypoints < 1 then
		return
	end
	courseplay:setEngineState(self, true);
	self.cp.saveFuel = false
	
	--print(tableShow(self.attachedImplements[1],"self.attachedImplements",nil,nil,4)) 
	--local id = self.attachedImplements[1].object.unloadTrigger.triggerId
	--courseplay:findInTables(g_currentMission ,"g_currentMission", id)

	if self.cp.orgRpm == nil then
		self.cp.orgRpm = {}
		self.cp.orgRpm[1] = self.motor.maxRpm
		self.cp.orgRpm[2] = self.motor.maxRpm
		self.cp.orgRpm[3] = self.motor.maxRpm
	end
	
	self.cpTrafficCollisionIgnoreList = {}
	self.CPnumCollidingVehicles = 0;
	self.cp.collidingVehicleId = nil
	
	courseplay:debug(string.format("%s: Start/Stop: deleting \"self.cp.collidingVehicleId\"", nameNum(self)), 3);
	--self.numToolsCollidingVehicles = {};
	self:setIsCourseplayDriving(false);
	courseplay:setIsRecording(self, false);
	courseplay:setRecordingIsPaused(self, false);
	self.cp.calculatedCourseToCombine = false

	self.cp.backMarkerOffset = nil
	self.cp.aiFrontMarker = nil
	courseplay:resetTools(self)	
	
	if self.attachedCutters ~= nil then
		for cutter, implement in pairs(self.attachedCutters) do
			--remove cutter atTrafficCollisionTrigger in case of having changed or removed it while not in CP
			if self.cp.trafficCollisionTriggers[0] ~= nil then
				removeTrigger(self.cp.trafficCollisionTriggers[0])
				self.cp.trafficCollisionTriggerToTriggerIndex[self.cp.trafficCollisionTriggers[0]] = nil
			end	
			--set cutter aiTrafficCollisionTrigger to cp.aiTrafficCollisionTrigger's list
			if cutter.aiTrafficCollisionTrigger ~= nil then
				if cutter.cpTrafficCollisionTrigger == nil then
					cutter.cpTrafficCollisionTrigger = clone(cutter.aiTrafficCollisionTrigger, true);
					self.cp.trafficCollisionTriggers[0] = cutter.cpTrafficCollisionTrigger
				else
					self.cp.trafficCollisionTriggers[0] = cutter.cpTrafficCollisionTrigger
				end
				addTrigger(self.cp.trafficCollisionTriggers[0], 'cpOnTrafficCollisionTrigger', self);
				self.cp.trafficCollisionTriggerToTriggerIndex[self.cp.trafficCollisionTriggers[0]] = 0
				self.cp.collidingObjects[0] = {};
				courseplay:debug(string.format("%s: Start/Stop: cutter.aiTrafficCollisionTrigger present -> adding %s to self.cp.trafficCollisionTriggers[0]",nameNum(self),tostring(self.cp.trafficCollisionTriggers[0])),3)
				--self.cp.numCollidingObjects[0] = 0;
			else
				courseplay:debug(string.format('## Courseplay: %s: aiTrafficCollisionTrigger in cutter missing. Traffic collision prevention will not work!', nameNum(self)),3);
			end
		end
	end
	
	-- adapt collis height to vehicles height , its a runonce
	if self.cp.ColliHeightSet == nil and self.cp.numTrafficCollisionTriggers > 0 then
		local height = 0;
		local step = (self.sizeLength/2)+1 ;
		local stepBehind, stepFront = step, step;
		if self.attachedImplements ~= nil then
			for index, implement in pairs(self.attachedImplements) do
				local tool = implement.object
				local x,y,z = getWorldTranslation(tool.rootNode);
			    local _,_,nz =  worldToLocal(self.cp.DirectionNode, x, y, z);
				if nz > 0 then
					stepFront = stepFront + (tool.sizeLength)+2				
				else
					stepBehind = stepBehind + (tool.sizeLength)+2	
				end
			end
		end
		
		local distance = self.sizeLength;
		local nx, ny, nz = localDirectionToWorld(self.rootNode, 0, -1, 0);	
		self.cp.HeightsFound = 0;
		self.cp.HeightsFoundColli = 0;			
		for i=-stepBehind,stepFront,0.5 do				
			local x,y,z = localToWorld(self.rootNode, 0, distance, i);
			raycastAll(x, y, z, nx, ny, nz, "findVehicleHeights", distance, self);
			--print("drive raycast "..tostring(i).." end");
			--drawDebugLine(x, y, z, 1, 0, 0, x+(nx*distance), y+(ny*distance), z+(nz*distance), 1, 0, 0);
		end
		local difference = self.cp.HeightsFound - self.cp.HeightsFoundColli;
		local trigger = self.cp.trafficCollisionTriggers[1];
		local Tx,Ty,Tz = getTranslation(trigger,self.rootNode);
		setTranslation(trigger, Tx,Ty+difference,Tz);
		self.cp.ColliHeightSet = true;
	end
	
	--calculate workwidth for combines in mode7
	if self.cp.mode == 7 then
		courseplay:calculateWorkWidth(self)
	end
	-- set default modeState if not in mode 2 or 3
	if self.cp.mode ~= 2 and self.cp.mode ~= 3 then
		courseplay:setModeState(self, 0);
	end;

	if self.cp.waypointIndex < 1 then
		courseplay:setWaypointIndex(self, 1);
	end

	-- add do working players if not already added
	if self.cp.coursePlayerNum == nil then
		self.cp.coursePlayerNum = CpManager:addToTotalCoursePlayers(self)
	end;
	--add to activeCoursePlayers
	CpManager:addToActiveCoursePlayers(self);

	self.cp.turnTimer = 8000
	
	-- show arrow
	self:setCpVar('distanceCheck',true,courseplay.isClient);
	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.cp.DirectionNode);
	-- position of next waypoint
	local cx, cz = self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz
	-- distance (in any direction)
	local dist = courseplay:distance(ctx, ctz, cx, cz)

	local setLaneNumber = false;
	local isFrontAttached = false;
	local isReversePossible = true;
	local tailerCount = 0;
	for k,workTool in pairs(self.cp.workTools) do    --TODO temporary solution (better would be Tool:getIsAnimationPlaying(animationName))
		if courseplay:isFolding(workTool) then
			if  self.aiLower ~= nil then
				workTool:aiLower(true)
			elseif self.setFoldState ~= nil then
				self:setFoldState(-1, true)
			end
		end;
		--DrivingLine spec: set lane numbers
		if self.cp.mode == 4 and not setLaneNumber and workTool.cp.hasSpecializationDrivingLine and not workTool.manualDrivingLine then
			setLaneNumber = true;
		end;
		if self.cp.mode == 10 then
			local x,y,z = getWorldTranslation(workTool.rootNode)  
			local _,_,tz = worldToLocal(self.cp.DirectionNode,x,y,z)
			if tz > 0 then
				isFrontAttached = true
			end
		end
		if workTool.cp.hasSpecializationTrailer then
			tailerCount = tailerCount + 1
			if tailerCount > 1 then
				isReversePossible = false
			end
		end
		
		if workTool.sprayer ~= nil and self.cp.hasFertilizerSowingMachine then
			if workTool.cp.orignalAllowsSpraying == nil then
				workTool.cp.orignalAllowsSpraying = workTool.allowsSpraying
			end
			workTool.allowsSpraying = self.cp.fertilizerOption
		end	
		
		
	end;
	self.cp.isReversePossible = isReversePossible
	self.cp.mode10.levelerIsFrontAttached = isFrontAttached
	
	if self.cp.mode == 10 then 
		if self.cp.mode10.OrigCompactScale == nil then
			self.cp.mode10.OrigCompactScale = self.bunkerSiloCompactingScale
			self.bunkerSiloCompactingScale = self.bunkerSiloCompactingScale*5
		end
	end
		
		
	local mapIconPath = Utils.getFilename('img/mapWaypoint.png', courseplay.path);
	local mapIconHeight = 2 / 1080;
	local mapIconWidth = mapIconHeight / g_screenAspectRatio;

	local numWaitPoints = 0
	local numUnloadPoints = 0
	local numCrossingPoints = 0
	self.cp.waitPoints = {};
	self.cp.unloadPoints = {};
	self.cp.shovelFillStartPoint = nil
	self.cp.shovelFillEndPoint = nil
	self.cp.shovelEmptyPoint = nil
	self.cp.mode9SavedLastFillLevel = 0;
	self.cp.workDistance = 0
	self.cp.mediumWpDistance = 0
	self.cp.mode10.alphaList = {}
	local nearestpoint = dist
	local nearestWpIx = 0
	local curLaneNumber = 1;
	local hasReversing = false;
	local lookForNearestWaypoint = self.cp.startAtPoint == courseplay.START_AT_NEAREST_POINT and (self.cp.modeState == 0 or self.cp.modeState == 99); --or self.cp.modeState == 1

	local lookForNextWaypoint = self.cp.startAtPoint == courseplay.START_AT_NEXT_POINT and (self.cp.modeState == 0 or self.cp.modeState == 99); 
	local nx, _, nz = localDirectionToWorld( self.cp.DirectionNode, 0, 0, 1 )
	local myDirection = math.atan2( nx, nz ) 
	-- one of the remaining waypoints of the course, closest in front of us
	local nextWaypointIx = 1
	local foundNextWaypoint = false
	local distNextWaypoint = math.huge
	-- any waypoint of the course, closest in front of us
	local nearestWaypointInSameDirectionIx = 1
	local foundNearestWaypointInSameDirection = false
	local distNearestWaypointInSameDirection = math.huge


	for i,wp in pairs(self.Waypoints) do
		local cx, cz = wp.cx, wp.cz;

		-- find nearest waypoint regardless of its rotation and direction from us
		if lookForNearestWaypoint or lookForNextWaypoint then
			dist = courseplay:distance(ctx, ctz, cx, cz)
			if dist <= nearestpoint then
				nearestpoint = dist
				nearestWpIx = i
			end;
		end;

		-- find next waypoint 
		if lookForNextWaypoint then
			local _, _, dz = worldToLocal( self.cp.DirectionNode, cx, 0, cz )
			local deltaAngle = math.huge	
			if wp.angle ~= nil then 
				deltaAngle = math.abs( getDeltaAngle( math.rad( wp.angle ), myDirection ))
			end
			-- we don't want to deal with anything closer than 5 m to avoid circling
			-- also, we want the waypoint which points into the direction we are currently heading to
			if dist < 30 and dz > 5 and deltaAngle < math.rad( 45 ) then
				if dist < distNearestWaypointInSameDirection then
					nearestWaypointInSameDirectionIx = i
					distNearestWaypointInSameDirection = dist
					foundNearestWaypointInSameDirection = true
					courseplay:debug(string.format('%s: found waypoint %d anywhere, distance = %.1f, deltaAngle = %.1f', nameNum(self), i, dist, math.deg( deltaAngle )), 12);
				end
				if dist < distNextWaypoint and i >= self.cp.waypointIndex and i <= self.cp.waypointIndex + 10 then
					foundNextWaypoint = true
					distNextWaypoint = dist
					nextWaypointIx = i
					courseplay:debug(string.format('%s: found waypoint %d next, distance = %.1f, deltaAngle = %.1f', nameNum(self), i, dist, math.deg( deltaAngle )), 12);
				end
			end
		end

		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
			self.cp.waitPoints[numWaitPoints] = i;
		end;
		if wp.unload then
			numUnloadPoints = numUnloadPoints + 1;
			self.cp.unloadPoints[numUnloadPoints] = i;
		end;
		if wp.crossing then
			numCrossingPoints = numCrossingPoints + 1;
			self.cp.crossingPoints[numCrossingPoints] = i;
		end;

		-- has reversing part
		if self.cp.mode ~= 9 and wp.rev then
			hasReversing = true;
		end;

		-- specific Workzone
		if self.cp.mode == 4 or self.cp.mode == 6 then
			if numWaitPoints == 1 and (self.cp.startWork == nil or self.cp.startWork == 0) then
				self.cp.startWork = i
			end
			if numWaitPoints > 1 and (self.cp.stopWork == nil or self.cp.stopWork == 0) then
				self.cp.stopWork = i
			end
			if self.cp.startWork and not self.cp.stopWork then
				if i > 1 then
					local dist = courseplay:distance(cx, cz, self.Waypoints[i-1].cx, self.Waypoints[i-1].cz)
					self.cp.workDistance = self.cp.workDistance + dist
					self.cp.mediumWpDistance = self.cp.workDistance/i
				end
			end
			if numUnloadPoints == 1 and (self.cp.heapStart == nil or self.cp.heapStart == 0) then
				self.cp.heapStart = i
				self.cp.makeHeaps = false
			end
			if numUnloadPoints > 1 and (self.cp.heapStop == nil or self.cp.heapStop == 0) then
				self.cp.heapStop = i
				self.cp.makeHeaps = true
			end
		elseif self.cp.mode == 7  then--combineUnloadMode
			if numUnloadPoints == 1 and (self.cp.heapStart == nil or self.cp.heapStart == 0) then
				self.cp.heapStart = i
				self.cp.makeHeaps = false
			end
			if numUnloadPoints > 1 and (self.cp.heapStop == nil or self.cp.heapStop == 0) then
				self.cp.heapStop = i
				self.cp.makeHeaps = true
			end
		--unloading point for transporter
		elseif self.cp.mode == 8 then
			--

		--work points for shovel
		elseif self.cp.mode == 9 then
			if numWaitPoints == 1 and self.cp.shovelFillStartPoint == nil then
				self.cp.shovelFillStartPoint = i;
			end;
			if numWaitPoints == 2 and self.cp.shovelFillEndPoint == nil then
				self.cp.shovelFillEndPoint = i;
			end;
			if numWaitPoints == 3 and self.cp.shovelEmptyPoint == nil then
				self.cp.shovelEmptyPoint = i;
			end;
		end;

		-- laneNumber (for seeders)
		if setLaneNumber and wp.generated ~= nil and wp.generated == true then
			if wp.turnEnd ~= nil and wp.turnEnd == true then
				curLaneNumber = curLaneNumber + 1;
				courseplay:debug(string.format('%s: waypoint %d: turnEnd=true -> new curLaneNumber=%d', nameNum(self), i, curLaneNumber), 12);
			end;
			wp.laneNum = curLaneNumber;
		end;
	end; -- END for wp in self.Waypoints
	
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
	courseplay:debug(string.format("%s: numWaitPoints=%d, waitPoints[1]=%s, numCrossingPoints=%d", nameNum(self), self.cp.numWaitPoints, tostring(self.cp.waitPoints[1]), numCrossingPoints), 12);

	-- set waitTime to 0 if necessary
	if not courseplay:getCanHaveWaitTime(self) and self.cp.waitTime > 0 then
		courseplay:changeWaitTime(self, -self.cp.waitTime);
	end;

	if self.cp.numUnloadPoints > 0 and self.cp.lastValidTipDistance == nil then
		for _,courseplayer in pairs(CpManager.totalCoursePlayers) do
			if self ~= courseplayer then
				for index,value in pairs(self.cp.unloadPoints) do
					--print(string.format("self: %s: %s",tostring(index),tostring(value)))
					local selfPoint = self.Waypoints[value]
					--print(tostring(selfPoint))
					if courseplayer.cp.numUnloadPoints > 0 and courseplayer.cp.lastValidTipDistance ~= nil then 
						for index,value in pairs(courseplayer.cp.unloadPoints) do
							--print(string.format("courseplayer: %s: %s",tostring(index),tostring(value)))
							local point = courseplayer.Waypoints[value]
							--print(tostring(point))
							if selfPoint == point then
								self.cp.lastValidTipDistance = courseplayer.cp.lastValidTipDistance;
								break
							end
						end
					end
				end
			end
		end
	end


  if lookForNextWaypoint then
		if foundNextWaypoint then 
			courseplay:debug(string.format('%s: found next waypoint: %d', nameNum(self), nextWaypointIx ), 12);
			courseplay:safeSetWaypointIndex( self, nextWaypointIx )     
		elseif foundNearestWaypointInSameDirection then
			courseplay:debug(string.format('%s: no next waypoint found, using the closest one in the same direction: %d', nameNum(self), nearestWaypointInSameDirectionIx), 12);
			courseplay:safeSetWaypointIndex( self, nearestWaypointInSameDirectionIx )     
		else
			courseplay:debug(string.format('%s: no next waypoint found, none found in the same direction, falling back to the nearest: %d', 
			                               nameNum(self), nearestWpIx ), 12);
			courseplay:safeSetWaypointIndex( self, nearestWpIx )     
    end
  end
	
	if lookForNearestWaypoint then
		courseplay:safeSetWaypointIndex( self, nearestWpIx )     
	end --END if modeState == 0

	if self.cp.waypointIndex > 2 and self.cp.mode ~= 4 and self.cp.mode ~= 6 and self.cp.mode ~= 8 then
		courseplay:setIsLoaded(self, true);
	elseif self.cp.mode == 4 or self.cp.mode == 6 then
		courseplay:setIsLoaded(self, false);
		self.cp.hasUnloadingRefillingCourse = self.cp.numWaypoints > self.cp.stopWork + 7;
		self.cp.hasTransferCourse = self.cp.startWork > 5
		if  self.Waypoints[self.cp.stopWork].cx == self.Waypoints[self.cp.startWork].cx 
		and self.Waypoints[self.cp.stopWork].cz == self.Waypoints[self.cp.startWork].cz then -- TODO: VERY unsafe, there could be LUA float problems (e.g. 7 + 8 = 15.000000001)
			self.cp.finishWork = self.cp.stopWork-5
		else
			self.cp.finishWork = self.cp.stopWork
		end

		-- NOTE: if we want to start the course but catch one of the last 5 points ("returnToStartPoint"), make sure we get wp 2
		if self.cp.startAtPoint == courseplay.START_AT_NEAREST_POINT and self.cp.finishWork ~= self.cp.stopWork and self.cp.waypointIndex > self.cp.finishWork and self.cp.waypointIndex <= self.cp.stopWork then
			courseplay:setWaypointIndex(self, 2);
		end
		courseplay:debug(string.format("%s: numWaypoints=%d, stopWork=%d, finishWork=%d, hasUnloadingRefillingCourse=%s,hasTransferCourse=%s, waypointIndex=%d", nameNum(self), self.cp.numWaypoints, self.cp.stopWork, self.cp.finishWork, tostring(self.cp.hasUnloadingRefillingCourse),tostring(self.cp.hasTransferCourse), self.cp.waypointIndex), 12);
	elseif self.cp.mode == 8 then
		courseplay:setIsLoaded(self, false);
	end

	if self.cp.mode == 9 then
		courseplay:setWaypointIndex(self, 1);
		self.cp.shovelState = 1;
		for i,_ in pairs(self.attachedImplements) do
			local object = self.attachedImplements[i].object
			if object.ignoreVehicleDirectionOnLoad ~= nil then
				object.ignoreVehicleDirectionOnLoad = true
			end	
			if object.attachedImplements ~= nil then
				for k,_ in pairs(object.attachedImplements) do
					if object.attachedImplements[k].object.ignoreVehicleDirectionOnLoad ~= nil then
						object.attachedImplements[k].object.ignoreVehicleDirectionOnLoad = true
					end
				end
			end				
		end
	elseif self.cp.startAtPoint == courseplay.START_AT_FIRST_POINT then
		if self.cp.mode == 2 or self.cp.mode == 3 then
			courseplay:setWaypointIndex(self, 3);
			courseplay:setIsLoaded(self, true);
		else
			courseplay:setWaypointIndex(self, 1);
			local distToFirst = courseplay:distanceToPoint( self, self.Waypoints[ 1 ].cx, 0, self.Waypoints[ 1 ].cz )
			if distToFirst > self.cp.turnDiameter then
				courseplay:startAlignmentCourse( self, self.Waypoints[ 1 ])
			end
		end
	end;

	courseplay:updateAllTriggers();

	self.cp.cruiseControlSpeedBackup = self.cruiseControl.speed;

	if self.cp.hasDriveControl then
		local changed = false;
		if self.cp.driveControl.hasFourWD then
			self.cp.driveControl.fourWDBackup = self.driveControl.fourWDandDifferentials.fourWheel;
			if self.cp.driveControl.alwaysUseFourWD and not self.driveControl.fourWDandDifferentials.fourWheel then
				self.driveControl.fourWDandDifferentials.fourWheel = true;
				changed = true;
			end;
		end;
		if self.cp.driveControl.hasHandbrake then
			if self.driveControl.handBrake.isActive == true then
				self.driveControl.handBrake.isActive = false;
				changed = true;
			end;
		end;
		if self.cp.driveControl.hasShuttleMode and self.driveControl.shuttle.isActive then
			if self.driveControl.shuttle.direction < 1.0 then
				self.driveControl.shuttle.direction = 1.0;
				changed = true;
			end;
		end;

		if changed and driveControlInputEvent ~= nil then
			driveControlInputEvent.sendEvent(self);
		end;
	end;
	
	--check Crab Steering mode and set it to default
	if self.crabSteering and (self.crabSteering.state ~= self.crabSteering.aiSteeringModeIndex or self.cp.useCrabSteeringMode ~= nil) then
		local crabSteeringMode = self.cp.useCrabSteeringMode or self.crabSteering.aiSteeringModeIndex;
		self:setCrabSteering(crabSteeringMode);
	end

	-- ok i am near the waypoint, let's go
	self.cp.savedCheckSpeedLimit = self.checkSpeedLimit;
	self.checkSpeedLimit = false
	self.cp.runOnceStartCourse = true;
	self:setIsCourseplayDriving(true);
	courseplay:setIsRecording(self, false);
	self:setCpVar('distanceCheck',false,courseplay.isClient);

	self.cp.totalLength, self.cp.totalLengthOffset = courseplay:getTotalLengthOnWheels(self);

	courseplay:validateCanSwitchMode(self);

	-- deactivate load/add/delete course buttons
	courseplay.buttons:setActiveEnabled(self, 'page2');

	-- add ingameMap icon
	if CpManager.ingameMapIconActive then
		courseplay:createMapHotspot(self);
	end;

	-- Disable crop destruction if 4Real Module 01 - Crop Destruction mod is installed
	if self.cropDestruction then
		courseplay:disableCropDestruction(self);
	end;

	--More Realistlitic Mod. Temp fix until we can fix the breaking problem. 
	if self.mrUseMrTransmission and self.mrUseMrTransmission == true then
		self.mrUseMrTransmission = false;
		self.cp.changedMRMod = true;
	end

	--print("startStop "..debug.getinfo(1).currentline)
end;

function courseplay:getCanUseCpMode(vehicle)
	-- check engine running state
	if not courseplay:getIsEngineReady(vehicle) then
		return false;
	end;

	local mode = vehicle.cp.mode;

	if (mode == 7 and not vehicle.cp.isCombine and not vehicle.cp.isChopper and not vehicle.cp.isHarvesterSteerable)
	or ((mode == 1 or mode == 2 or mode == 3 or mode == 4 or mode == 8 or mode == 9) and (vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable))
	or ((mode ~= 5) and (vehicle.cp.isWoodHarvester or vehicle.cp.isWoodForwarder)) then
		courseplay:setInfoText(vehicle, 'COURSEPLAY_MODE_NOT_SUPPORTED_FOR_VEHICLETYPE');
		return false;
	end;


	if mode ~= 5 and mode ~= 7 and not vehicle.cp.workToolAttached then
		if mode == 4 or mode == 6 then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TOOL');
		elseif mode == 9 then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_SHOVEL_NOT_FOUND');
		elseif mode == 10 then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_MODE10_NOBLADE');
		else
			courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TRAILER');
		end;
		return false;
	end;
	
	if mode == 10 and vehicle.cp.mode10.levelerIsFrontAttached then
		courseplay:setInfoText(vehicle, 'COURSEPLAY_MODE10_NOFRONTBLADE');
		return false;
	end

	local minWait, maxWait, minUnload, maxUnload;

	if (mode == 1 and vehicle.cp.hasAugerWagon) or mode == 3 or mode == 8 or mode == 10 then
		minWait, maxWait = 1, 1;
		if  vehicle.cp.hasWaterTrailer then
			maxWait = 10
		end
		if vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, string.format("COURSEPLAY_WAITING_POINTS_TOO_FEW;%d",minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
			return false;
		end;
		if mode == 3 then
			maxUnload = 0
			if vehicle.cp.workTools[1] == nil or vehicle.cp.workTools[1].cp == nil or not vehicle.cp.workTools[1].cp.isAugerWagon then
				courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TRAILER');
				return false;
			elseif vehicle.cp.numUnloadPoints > maxUnload then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_MANY;%d',maxUnload));
			return false; 
			end;
		elseif mode == 8 then
			if vehicle.cp.workTools[1] == nil then
				courseplay:setInfoText(vehicle, 'COURSEPLAY_WRONG_TRAILER');
				return false;
			end;
		end;
	elseif mode == 7 then
		minWait, maxWait = 1, 1;
		if vehicle.cp.numUnloadPoints == 0 and vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, string.format("COURSEPLAY_WAITING_POINTS_TOO_FEW;%d",minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
			return false;
		end;
		minUnload, maxUnload = 2, 2;
		if vehicle.cp.numWaitPoints == 0 and vehicle.cp.numUnloadPoints < minUnload then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_FEW;%d',minUnload));
			return false;
		elseif vehicle.cp.numUnloadPoints > maxUnload then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_MANY;%d',maxUnload));
			return false;
		end;
	elseif mode == 4 or mode == 6 then
		if vehicle.cp.startWork == nil or vehicle.cp.stopWork == nil then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_NO_WORK_AREA');
			return false;
		end;
		if mode == 6 then
			maxUnload = 0;
			if vehicle.cp.hasBaleLoader then
				minWait, maxWait = 2, 3;
				if vehicle.cp.numWaitPoints < minWait then
					courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_FEW;%d',minWait));
					return false;
				elseif vehicle.cp.numWaitPoints > maxWait then
					courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
					return false;
				end;																									--TODO: Remove when tippers are supported with 2 unload points
			elseif (vehicle.cp.isCombine or vehicle.cp.isHarvesterSteerable or vehicle.cp.hasHarvesterAttachable) and not vehicle.cp.hasSpecialChopper then
				maxUnload = 2;
			else
				maxUnload = 1;
			end;
			if vehicle.cp.numUnloadPoints > maxUnload then
				courseplay:setInfoText(vehicle, string.format('COURSEPLAY_UNLOADING_POINTS_TOO_MANY;%d',maxUnload));
				return false;
			end;
		end;

	elseif mode == 9 then
		minWait, maxWait = 3, 3;
		if vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_FEW;%d',minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, string.format('COURSEPLAY_WAITING_POINTS_TOO_MANY;%d',maxWait));
			return false;
		elseif vehicle.cp.shovelStatePositions == nil or vehicle.cp.shovelStatePositions[2] == nil or vehicle.cp.shovelStatePositions[3] == nil or vehicle.cp.shovelStatePositions[4] == nil or vehicle.cp.shovelStatePositions[5] == nil then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_SHOVEL_POSITIONS_MISSING');
			return false;
		elseif vehicle.cp.shovelFillStartPoint == nil or vehicle.cp.shovelFillEndPoint == nil or vehicle.cp.shovelEmptyPoint == nil then
			courseplay:setInfoText(vehicle, 'COURSEPLAY_NO_VALID_COURSE');
			return false;
		end;
	end;

	return true;
end;

-- stops driving the course
function courseplay:stop(self)
	self.isHired = false;
	self.isHirableBlocked = false;
	
	self.aiLightsTypesMask = self.cp.savedLightsMask;
	self.forceIsActive = self.cp.forceIsActiveBackup;
	self.stopMotorOnLeave = self.cp.stopMotorOnLeaveBackup;
	self.steeringEnabled = true;
	self.disableCharacterOnLeave = true;

	if g_currentMission.missionInfo.automaticMotorStartEnabled and self.cp.saveFuel and not self.isMotorStarted then
		courseplay:setEngineState(self, true);
		self.cp.saveFuel = false;		
	end
	if courseplay:getCustomTimerExists(self,'fuelSaveTimer')  then 
		--print("reset existing timer")
		courseplay:resetCustomTimer(self,'fuelSaveTimer',true)
	end
	
	if self.cp.runReset == true then
 		self.cp.runCounter = 0;
 		self.cp.runReset = false;
 		courseplay:changeRunCounter(self, false)
 	end;

	-- Reset the reset character timer.
	courseplay:resetCustomTimer(self, "resetCharacter", true);

	if self.vehicleCharacter ~= nil then
		self.vehicleCharacter:delete();
	end

	courseplay:endAlignmentCourse( self )

	if self.isEntered or self.isControlled then
		if self.vehicleCharacter ~= nil then
			----------------------------------
			--- Fix Missing playerIndex and playerColorIndex that some times happens for unknow reasons
			local playerIndex = Utils.getNoNil(self.playerIndex, g_currentMission.missionInfo.playerIndex);
			local playerColorIndex = Utils.getNoNil(self.playerColorIndex, g_currentMission.missionInfo.playerColorIndex);
			--- End Fix
			----------------------------------

			self.vehicleCharacter:loadCharacter(PlayerUtil.playerIndexToDesc[playerIndex].xmlFilename, playerColorIndex)
			self.vehicleCharacter:setCharacterVisibility(not self.isEntered)
		end
	end;
	self.currentHelper = nil

	--stop special tools
	for _, tool in pairs (self.cp.workTools) do
		--  vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload, ridgeMarker,forceSpeedLimit)
		courseplay:handleSpecialTools(self, tool, false,   false,  false,   false, false, nil,nil,0);
		if tool.cp.originalCapacities then
			for index,fillUnit in pairs(tool.fillUnits) do
				fillUnit.capacity =  tool.cp.originalCapacities[index]
			end
			tool.cp.originalCapacities = nil
		end
		if tool.cp.orignalAllowsSpraying ~= nil then
			tool.allowsSpraying = tool.cp.orignalAllowsSpraying
			tool.cp.orignalAllowsSpraying = nil
		end
	end

	self.cp.lastInfoText = nil

	if courseplay.isClient then
		return
	end
	
	--mode10 restore original compactingScales
	if self.cp.mode10.OrigCompactScale ~= nil then
		self.bunkerSiloCompactingScale = self.cp.mode10.OrigCompactScale 
		self.cp.mode10.OrigCompactScale = nil
	end
	
	
	-- Enable crop destruction if 4Real Module 01 - Crop Destruction mod is installed
	if self.cropDestruction then
		courseplay:enableCropDestruction(self);
	end;

	--More Realistlitic Mod. Temp fix until we can fix the breaking problem. 
	if self.mrUseMrTransmission ~= nil and self.cp.changedMRMod == true then
		self.mrUseMrTransmission = true;
		self.cp.changedMRMod = false;
	end;

	if self.cp.hasDriveControl then
		local changed = false;
		if self.cp.driveControl.hasFourWD and self.driveControl.fourWDandDifferentials.fourWheel ~= self.cp.driveControl.fourWDBackup then
			self.driveControl.fourWDandDifferentials.fourWheel = self.cp.driveControl.fourWDBackup;
			self.driveControl.fourWDandDifferentials.diffLockFront = false;
			self.driveControl.fourWDandDifferentials.diffLockBack = false;
			changed = true;
		end;

		if changed and driveControlInputEvent ~= nil then
			driveControlInputEvent.sendEvent(self);
		end;
	end;

	if self.cp.cruiseControlSpeedBackup then
		self.cruiseControl.speed = self.cp.cruiseControlSpeedBackup; -- NOTE JT: no need to use setter or event function - Drivable's update() checks for changes in the var and calls the event itself
		self.cp.cruiseControlSpeedBackup = nil;
	end;

	if self.cp.takeOverSteering then
		self.cp.takeOverSteering = false
	end
	
	courseplay:releaseCombineStop(self)
	self.cp.BunkerSiloMap = nil
	self.cp.mode9TargetSilo = nil
	self.cp.mode10.lowestAlpha = 99
	
	
	self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
	self.cruiseControl.minSpeed = 1
	self.cp.forcedToStop = false
	self.cp.waitingForTrailerToUnload = false
	courseplay:setIsRecording(self, false);
	courseplay:setRecordingIsPaused(self, false);
	if self.cp.modeState > 4 then
		courseplay:setModeState(self, 1);
	end
	self.cp.isTurning = nil;
	courseplay:clearTurnTargets(self);
	self.cp.backMarkerOffset = nil
	self.cp.aiFrontMarker = nil
	self.cp.aiTurnNoBackward = false
	self.cp.noStopOnEdge = false
	self.cp.fillTrigger = nil;
	self.cp.tipperLoadMode = 0;
	self.cp.hasMachineToFill = false;
	self.cp.unloadOrder = false
	self.cp.isUnloadingStopped = false
	self.cp.foundColli = {}
	self.cp.inTraffic = false
	self.cp.bypassWaypointsSet = false
	-- deactivate beacon and hazard lights
	if self.beaconLightsActive then
		self:setBeaconLightsVisibility(false);
	end;
	if self.turnLightState and self.turnLightState ~= Lights.TURNLIGHT_OFF then
		self:setTurnLightState(Lights.TURNLIGHT_OFF);
	end;

	--open all covers
	if self.cp.workToolAttached and self.cp.tipperHasCover and self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 5 or self.cp.mode == 6 then
		courseplay:openCloseCover(self,60,false,false,true);
	end;

	-- resetting variables
	self.cp.ColliHeightSet = nil
	self.cp.tempCollis = {}
	self.checkSpeedLimit = self.cp.savedCheckSpeedLimit;
	courseplay:resetTipTrigger(self);
	self:setIsCourseplayDriving(false);
	self:setCpVar('canDrive',true,courseplay.isClient)
	self:setCpVar('distanceCheck',false,courseplay.isClient);
	self.cp.mode7GoBackBeforeUnloading = false
	if self.cp.checkReverseValdityPrinted then
		self.cp.checkReverseValdityPrinted = false

	end
	self.cp.lastMode8UnloadTriggerId = nil

	self.cp.curSpeed = 0;

	self.motor.maxRpmOverride = nil;
	self.cp.heapStart = nil
	self.cp.heapStop = nil
	self.cp.startWork = nil
	self.cp.stopWork = nil
	self.cp.hasFinishedWork = nil
	self.cp.turnTimeRecorded = nil;	
	self.cp.hasUnloadingRefillingCourse = false;
	self.cp.hasTransferCourse = false
	courseplay:setStopAtEnd(self, false);
	self.cp.stopAtEndMode1 = false;
	self.cp.isTipping = false;
	self.cp.isUnloaded = false;
	self.cp.prevFillLevelPct = nil;
	self.cp.isInRepairTrigger = nil;
	self.cp.curMapWeightStation = nil;
	courseplay:setSlippingStage(self, 0);
	courseplay:resetCustomTimer(self, 'slippingStage1');
	courseplay:resetCustomTimer(self, 'slippingStage2');

	courseplay:resetCustomTimer(self, 'foldBaleLoader', true);

	self.cp.hasBaleLoader = false;
	self.cp.hasPlough = false;
	self.cp.hasRotateablePlough = false;
	self.cp.hasSowingMachine = false;
	self.cp.hasSprayer = false;
	if self.cp.tempToolOffsetX ~= nil then
		courseplay:changeToolOffsetX(self, nil, self.cp.tempToolOffsetX, true);
		self.cp.tempToolOffsetX = nil
	end;
	if self.cp.manualWorkWidth ~= nil then
		courseplay:changeWorkWidth(self, nil, self.cp.manualWorkWidth, true)
		if self.cp.hud.currentPage == courseplay.hud.PAGE_COURSE_GENERATION then
			courseplay.hud:setReloadPageOrder(self, self.cp.hud.currentPage, true);
		end
	end
	
	self.cp.totalLength, self.cp.totalLengthOffset = 0, 0;
	self.cp.numWorkTools = 0;

	self.cp.movingToolsPrimary, self.cp.movingToolsSecondary = nil, nil;
	self.cp.attachedFrontLoader = nil

	courseplay:deleteFixedWorldPosition(self);

	--remove any local and global info texts
	if g_server ~= nil then
		courseplay:setInfoText(self, nil);

		for refIdx,_ in pairs(CpManager.globalInfoText.msgReference) do
			if self.cp.activeGlobalInfoTexts[refIdx] ~= nil then
				CpManager:setGlobalInfoText(self, refIdx, true);
			end;
		end;
	end

	-- remove ingame map hotspot
	if CpManager.ingameMapIconActive then
		courseplay:deleteMapHotspot(self);
	end;

	--remove from activeCoursePlayers
	CpManager:removeFromActiveCoursePlayers(self);

	--validation: can switch mode?
	courseplay:validateCanSwitchMode(self);

	-- reactivate load/add/delete course buttons
	courseplay.buttons:setActiveEnabled(self, 'page2');
end


function courseplay:findVehicleHeights(transformId, x, y, z, distance)
	local height = self.sizeLength - distance
	local vehicle = false
	--print(string.format("found %s (%s)",tostring(getName(transformId)),tostring(transformId)))
	if self.cp.trafficCollisionTriggerToTriggerIndex[transformId] ~= nil then
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

function courseplay:checkSaveFuel(vehicle,allowedToDrive)
	if (not vehicle.cp.saveFuelOptionActive) 
	or (vehicle.cp.mode == courseplay.MODE_COMBI and vehicle.cp.activeCombine ~= nil)
	or (vehicle.cp.mode == courseplay.MODE_FIELDWORK and ((vehicle.courseplayers ~= nil and #vehicle.courseplayers > 0) or vehicle.cp.convoyActive))
	or ((vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT or vehicle.cp.mode == courseplay.MODE_OVERLOADER) and vehicle.Waypoints[vehicle.cp.previousWaypointIndex].wait)
	then
		if vehicle.cp.saveFuel then
			vehicle.cp.saveFuel = false
		end
		courseplay:resetCustomTimer(vehicle,'fuelSaveTimer',true)
		return
	end
	
	if allowedToDrive then
		if courseplay:getCustomTimerExists(vehicle,'fuelSaveTimer')  then 
			--print("reset existing timer")
			courseplay:resetCustomTimer(vehicle,'fuelSaveTimer',true)
		end
		if vehicle.cp.saveFuel then
			--print("reset saveFuel")
			vehicle.cp.saveFuel = false
		end	
	else
		-- set fuel save timer
		if not vehicle.cp.saveFuel then
			if courseplay:timerIsThrough(vehicle,'fuelSaveTimer',false) then
				--print(" timer is throught and not nil")
				--print("set saveFuel")
				vehicle.cp.saveFuel = true
			elseif courseplay:timerIsThrough(vehicle,'fuelSaveTimer') then
				--print(" set timer ")
				courseplay:setCustomTimer(vehicle,'fuelSaveTimer',30)
			end
		end
	end
end

function courseplay:safeSetWaypointIndex( vehicle, newIx )
	for i = newIx, newIx + 3 do
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
