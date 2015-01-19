local abs, min = math.abs, math.min;

function courseplay:newturn(self, dt)
	--[[ TURN STAGES:
	0:	Raise implements
	1:	Create Turn maneuver (Creating waypoints to follow)
	2:	Drive Turn maneuver
	3:	Lower implement and continue on next lane
	]]

	local allowedToDrive = true;
	local moveForwards = true;
	local refSpeed = self.cp.speeds.turn
	local directionForce = 1;
	local lx, lz = 0, 1;
	local turnOutTimer = 1500;
	local turnTimer = 1500;

	local frontMarker = Utils.getNoNil(self.cp.aiFrontMarker, -3);
	local backMarker = Utils.getNoNil(self.cp.backMarkerOffset,0);
	if self.cp.noStopOnEdge then
		turnOutTimer = 0;
	end;

	local vehicleX, vehicleY, vehicleZ = getWorldTranslation(self.cp.DirectionNode);

	local newTarget = self.cp.turnTargets[self.cp.curTurnIndex];

	-- Debug prints
	if courseplay.debugChannels[14] then
		if #self.cp.turnTargets > 0 then
			-- Draw debug points for waypoints.
			for k, v in ipairs(self.cp.turnTargets) do
				local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, v.posX, 1, v.posZ);
				drawDebugPoint(v.posX, posY + 3, v.posZ, 0, 1, 1, 1);
			end;
		end;
	end;

	-- TURN STAGES 1 - 4
	if self.cp.turnStage > 0 then

		-- TURN STAGES 1 - Create Turn maneuver (Creating waypoints to follow)
		if self.cp.turnStage == 1 then
			courseplay:clearTurnTargets(self); -- Make sure we have cleaned it from any previus usage.
			self.cp.curTurnIndex = 1; -- Reset the current target index to the first one.

			-- Get the turn radius either by the automatic or user provided turn circle.
			local turnRadius = self.cp.turnDiameter / 2;

			-- Get the new turn target with offset
			local cx,cz = self.Waypoints[self.cp.waypointIndex+1].cx, self.Waypoints[self.cp.waypointIndex+1].cz;
			if (self.cp.laneOffset ~= nil and self.cp.laneOffset ~= 0) or (self.cp.toolOffsetX ~= nil and self.cp.toolOffsetX ~= 0) then
				courseplay:debug(string.format("%s:(Turn) turnWithOffset = true", nameNum(self)), 14);
				cx,cz = courseplay:turnWithOffset(self)
			end;
			local targetDeltaX, _, targetDeltaZ = worldToLocal(self.cp.DirectionNode, cx, vehicleY, cz);
			courseplay:debug(string.format("%s:(Turn) targetDeltaX=%.2f, targetDeltaZ=%.2f", nameNum(self), targetDeltaX, targetDeltaZ), 14);

			-- Get the turn direction
			local direction = 1;
			if targetDeltaX < 0 then
				direction = -1;
			end;

			-- Find the zOffset based on tractors current position from the start turn wp
			local _, _, z = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.waypointIndex].cx, vehicleY, self.Waypoints[self.cp.waypointIndex].cz);
			local zOffset = abs(z) + 1;
			-- If the front marker is in front of us and it's bigger than the normal offset, use that instead.
			if frontMarker > abs(z) then
				zOffset = frontMarker + 1;
			end;


			-- No need for Ohm or reverse turn
			if abs(targetDeltaX) > self.cp.turnDiameter then
				local posX, posZ;
				local index = 1;
				-- WP 1
				posX, _, posZ = localToWorld(self.cp.DirectionNode, 0, 0, 1);
				courseplay:addTurnTarget(self, posX, posZ);

				-- WP 2
				-- Target is less that 45° on the side of us
				if (targetDeltaZ + zOffset) > abs(targetDeltaX) then
					posX, _, posZ = localToWorld(self.cp.DirectionNode, targetDeltaX - (turnRadius * 2 * direction), 0, targetDeltaZ + zOffset);

				-- Target is 45° or more on the side of us
				else
					posX, _, posZ = localToWorld(self.cp.DirectionNode, turnRadius * direction, 0, turnRadius + 1);
				end;
				courseplay:addTurnTarget(self, posX, posZ);

				-- WP 3
				posX, _, posZ = localToWorld(self.cp.DirectionNode, targetDeltaX - (turnRadius * direction), 0, targetDeltaZ + turnRadius + zOffset);
				courseplay:addTurnTarget(self, posX, posZ);

				-- WP 4
				posX, _, posZ = localToWorld(self.cp.DirectionNode, targetDeltaX, 0, targetDeltaZ + zOffset);
				courseplay:addTurnTarget(self, posX, posZ);

				-- WP 5
				posX, _, posZ = localToWorld(self.cp.DirectionNode, targetDeltaX, 0, targetDeltaZ - (self.cp.totalLength + self.cp.totalLengthOffset + 5));
				courseplay:addTurnTarget(self, posX, posZ, true);

				courseplay:debug(string.format("%s:(Turn) Normal turn with %d waypoints", nameNum(self), #self.cp.turnTargets), 14);

			-- Ohm or reverse turn
			else
				-- TODO: (Claus) make Ohm and Reverse turn maneuver.
			end;

			self.cp.turnStage = 2;

		-- TURN STAGES 2 - Drive Turn maneuver
		elseif self.cp.turnStage == 2 then
			if newTarget then
				if newTarget.stage3 then
					self.cp.turnStage = 3;
					return;
				end;

				-- Change turn waypoint
				local dist = courseplay:distance(newTarget.posX, newTarget.posZ, vehicleX, vehicleZ);
				if dist < 1.5 then
					self.cp.curTurnIndex = min(self.cp.curTurnIndex + 1, #self.cp.turnTargets);
				end;
			else
				self.cp.turnStage = 1; -- Somehow we don't have any waypoints, so try recollect them.
				return;
			end;

		-- TURN STAGES 3 - Lower implement and continue on next lane
		else
			local _, _, deltaZ = worldToLocal(self.cp.DirectionNode,self.Waypoints[self.cp.waypointIndex+1].cx, vehicleY, self.Waypoints[self.cp.waypointIndex+1].cz)

			-- Lower implement and continue on next lane
			if deltaZ < frontMarker then
				courseplay:lowerImplements(self, true, true);

				self.cp.turnStage = 0;
				self.cp.isTurning = nil;
				self.cp.waitForTurnTime = self.timer + turnOutTimer;

				courseplay:setWaypointIndex(self, courseplay:getNextFwdPoint(self));
				courseplay:clearTurnTargets(self);

				return;
			end;
		end;


	-- TURN STAGES 0
	else
		if self.isStrawEnabled then
			self.cp.savedNoStopOnTurn = self.cp.noStopOnTurn
			self.cp.noStopOnTurn = false;
			turnTimer = self.strawToggleTime or 5;
		elseif self.cp.savedNoStopOnTurn ~= nil then
			self.cp.noStopOnTurn = self.cp.savedNoStopOnTurn;
			self.cp.savedNoStopOnTurn = nil;
		end;

		local offset = Utils.getNoNil(self.cp.totalOffsetX, 0);
		local x,y,z = localToWorld(self.cp.DirectionNode, offset, 0, backMarker);
		local dist = courseplay:distance(self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz, x, z);
		if backMarker <= 0 then
			if  dist < 0.5 then
				if not self.cp.noStopOnTurn then
					self.cp.waitForTurnTime = self.timer + turnTimer;
				end;
				courseplay:lowerImplements(self, false, false);
				--updateWheels = false;
				self.cp.turnStage = 1;
			end;
		else
			if dist < 0.5 and self.cp.turnStage ~= -1 then
				self.cp.turnStage = -1;
				courseplay:lowerImplements(self, false, false);
			end;
			if dist > backMarker and self.cp.turnStage == -1 then
				if not self.cp.noStopOnTurn then
					self.cp.waitForTurnTime = self.timer + turnTimer;
				end;
				--updateWheels = false;
				self.cp.turnStage = 1;
			end;
		end;
	end;

	-- allowedToDrive false -> SLOW DOWN TO STOP
	if not allowedToDrive then
		-- reset slipping timers
		courseplay:resetSlippingTimers(self)
		if courseplay.debugChannels[21] then
			renderText(0.5,0.85-(0.03*self.cp.coursePlayerNum),0.02,string.format("%s: self.lastSpeedReal: %.8f km/h ",nameNum(self),self.lastSpeedReal*3600))
		end
		self.cp.TrafficBrake = false;
		self.cp.isTrafficBraking = false;

		local moveForwards = true;
		if self.cp.curSpeed > 1 then
			allowedToDrive = true;
			moveForwards = self.movingDirection == 1;
			directionForce = -1;
		end;
		self.cp.speedDebugLine = ("turn("..tostring(debug.getinfo(1).currentline-1).."): allowedToDrive false ")
	else
		self.cp.speedDebugLine = ("turn("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		courseplay:setSpeed(self, refSpeed )
	end;

	--Set the driving direction
	if newTarget then
		lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, newTarget.posX, vehicleY, newTarget.posZ);
	end;
	if courseplay.debugChannels[12] and newTarget then
		local posY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newTarget.posX, 1, newTarget.posZ);
		drawDebugPoint(newTarget.posX, posY + 3, newTarget.posZ, 1, 1, 0, 1);
	end;

	-- Traffic break if something is in front of us
	if self.cp.TrafficBrake then
		moveForwards = self.movingDirection == -1;
		--lx = 0
		--lz = 1
	end

	-- Vehicles with inverted driving direction.
	if self.invertedDrivingDirection then
		lx = -lx
	end

	--self,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
	AIVehicleUtil.driveInDirection(self, dt, (self.cp.steeringAngle - 5), directionForce, 0.5, 20, allowedToDrive, moveForwards, lx, lz, refSpeed, 1);
	courseplay:setTrafficCollision(self, lx, lz, true);
end;

function courseplay:addTurnTarget(vehicle, posX, posZ, stage3)
	local target = {};
	target.posX 	= posX;
	target.posZ 	= posZ;
	target.stage3	= stage3;
	table.insert(vehicle.cp.turnTargets, target);
end

function courseplay:clearTurnTargets(vehicle)
	vehicle.cp.turnTargets = {};
end

function courseplay:turn(self, dt) --!!!
	--[[ TURN STAGES:
	0:	raise implements
	1:	start forward turn
	2:	
	3:	reversing
	4:	
	5:	
	6:	
	]]

	if self.cp.hasSprayer then
		courseplay:newturn(self, dt);
		return;
	end;

	local newTargetX, newTargetY, newTargetZ;
	local moveForwards = true;
	local updateWheels = true;
	local turnOutTimer = 1500
	local turnTimer = 1500
	--local frontMarker = Utils.getNoNil(self.cp.backMarkerOffset, -3)
	--local backMarker = Utils.getNoNil(self.cp.aiFrontMarker,0)
	local frontMarker = Utils.getNoNil(self.cp.aiFrontMarker, -3)
	local backMarker = Utils.getNoNil(self.cp.backMarkerOffset,0)
	if self.cp.noStopOnEdge then
		turnOutTimer = 0
	end
	if not self.cp.checkMarkers then
		self.cp.checkMarkers = true
		for _,workTool in pairs(self.cp.workTools) do
			courseplay:setMarkers(self, workTool)
		end
	end
	
	self.cp.turnTimer = self.cp.turnTimer - dt;

	-- TURN STAGES 1 - 6
	if self.cp.turnTimer < 0 or self.cp.turnStage > 0 then

		-- TURN STAGES 2 - 6
		if self.cp.turnStage > 1 then
			local x,y,z = getWorldTranslation(self.cp.DirectionNode);
			local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
			local myDirX, myDirY, myDirZ = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);

			newTargetX = self.aiTractorTargetX;
			newTargetY = y;
			newTargetZ = self.aiTractorTargetZ;

			-- TURN STAGE 2
			if self.cp.turnStage == 2 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if self.cp.isTurning == "left" then
					AITractor.aiRotateLeft(self);
				else
					AITractor.aiRotateRight(self);
				end
				if myDirX*dirX + myDirZ*dirZ > 0.2 or self.turnStageTimer < 0 then
					if self.cp.aiTurnNoBackward or
					(courseplay:distance(newTargetX, newTargetZ, self.Waypoints[self.cp.waypointIndex-1].cx, self.Waypoints[self.cp.waypointIndex-1].cz) > self.cp.turnDiameter * 1.2) then
						self.cp.turnStage = 4;
					else
						self.cp.turnStage = 3;
						moveForwards = false;
					end;
					if self.turnStageTimer < 0 then
						self.aiTractorTargetBeforeSaveX = self.aiTractorTargetX;
						self.aiTractorTargetBeforeSaveZ = self.aiTractorTargetZ;
						newTargetX = self.aiTractorTargetBeforeTurnX;
						newTargetZ = self.aiTractorTargetBeforeTurnZ;
						moveForwards = false;
						self.cp.turnStage = 6;
						self.turnStageTimer = Utils.getNoNil(self.turnStage6Timeout,3000)
					else
						self.turnStageTimer = Utils.getNoNil(self.turnStage3Timeout,20000)
					end;
				end;

			-- TURN STAGE 3
			elseif self.cp.turnStage == 3 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if myDirX*dirX + myDirZ*dirZ > 0.95 or self.turnStageTimer < 0 then
					self.cp.turnStage = 4;
				else
					moveForwards = false;
				end;

			-- TURN STAGE 4
			elseif self.cp.turnStage == 4 then
				local dx, dz = x-newTargetX, z-newTargetZ;
				local dot = dx*dirX + dz*dirZ;
				if self.cp.noStopOnEdge then
					courseplay:lowerImplements(self, true, false)
				end
				if -dot < Utils.getNoNil(self.turnEndDistance, 4) then
					if self.turnTargetMoveBack ~= nil and self.aiToolExtraTargetMoveBack ~= nil then
						newTargetX = self.aiTractorTargetX + dirX*(self.turnTargetMoveBack + self.aiToolExtraTargetMoveBack);
						newTargetY = y;
						newTargetZ = self.aiTractorTargetZ + dirZ*(self.turnTargetMoveBack + self.aiToolExtraTargetMoveBack);
					else
						newTargetX = self.aiTractorTargetX
						newTargetY = y;
						newTargetZ = self.aiTractorTargetZ
					end
					self.cp.turnStage = 5;
				end;

			-- TURN STAGE 5
			elseif self.cp.turnStage == 5 then
				local backX, backY, backZ = localToWorld(self.cp.DirectionNode,0,0,frontMarker);
				local dx, dz = backX-newTargetX, backZ-newTargetZ;
				local dot = dx*dirX + dz*dirZ;
				local moveback = 0
				if self.turnEndBackDistance ~= nil and self.aiToolExtraTargetMoveBack ~= nil then
					moveback = self.turnEndBackDistance+self.aiToolExtraTargetMoveBack
				else
					moveback = 10
				end
				if -dot < moveback  then
					self.cp.turnStage = 0;
					local _,_,z1 = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.waypointIndex+1].cx, backY, self.Waypoints[self.cp.waypointIndex+1].cz);
					local _,_,z2 = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.waypointIndex+2].cx, backY, self.Waypoints[self.cp.waypointIndex+2].cz);
					local _,_,z3 = worldToLocal(self.cp.DirectionNode, self.Waypoints[self.cp.waypointIndex+3].cx, backY, self.Waypoints[self.cp.waypointIndex+3].cz);
					if self.cp.isCombine then
						if z2 > 6 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 2);
						elseif z3 > 6 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 3);
						else
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 4);
						end
					else
						if z1 > 0 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 1);
						elseif z2 > 0 then
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 2);
						else
							courseplay:setWaypointIndex(self, self.cp.waypointIndex + 3);
						end
					end;
					courseplay:lowerImplements(self, true, true)
					self.cp.turnTimer = 8000
					self.cp.isTurning = nil 
					self.cp.waitForTurnTime = self.timer + turnOutTimer;
				end;

			-- TURN STAGE 6
			elseif self.cp.turnStage == 6 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if self.turnStageTimer < 0 then
					self.turnStageTimer = Utils.getNoNil(self.turnStage2Timeout,20000)
					self.cp.turnStage = 2;

					newTargetX = self.aiTractorTargetBeforeSaveX;
					newTargetZ = self.aiTractorTargetBeforeSaveZ;
				else
					local x,y,z = getWorldTranslation(self.cp.DirectionNode);
					local dirX, dirZ = -self.aiTractorDirectionX, -self.aiTractorDirectionZ;
					-- just drive along direction
					local targetX, targetZ = self.aiTractorTargetX, self.aiTractorTargetZ;
					local dx, dz = x-targetX, z-targetZ;
					local dot = dx*dirX + dz*dirZ;

					local projTargetX = targetX +dirX*dot;
					local projTargetZ = targetZ +dirZ*dot;
					local aheadDistance = Utils.getNoNil(self.aiTractorLookAheadDistance,10)
					newTargetX = projTargetX-dirX*aheadDistance;
					newTargetZ = projTargetZ-dirZ*aheadDistance;
					moveForwards = false;
				end;
			end;
			if courseplay.debugChannels[12] then
				drawDebugPoint(newTargetX, y+3, newTargetZ, 1, 1, 0, 1);
			end;

		-- TURN STAGE 1
		elseif self.cp.turnStage == 1 then
			-- turn
			local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
			if self.cp.isTurning == "right" then
				self.aiTractorTurnLeft = false;
			else
				self.aiTractorTurnLeft = true;
			end;
			local cx,cz = self.Waypoints[self.cp.waypointIndex+1].cx, self.Waypoints[self.cp.waypointIndex+1].cz;
			if (self.cp.laneOffset ~= nil and self.cp.laneOffset ~= 0) or (self.cp.toolOffsetX ~= nil and self.cp.toolOffsetX ~= 0) then
				cx,cz = courseplay:turnWithOffset(self)
			end;
			newTargetX = cx
			newTargetY = y;
			newTargetZ = cz
			
			self.aiTractorTargetBeforeTurnX = self.aiTractorTargetX;
			self.aiTractorTargetBeforeTurnZ = self.aiTractorTargetZ;

			self.aiTractorDirectionX = -dirX;
			self.aiTractorDirectionZ = -dirZ;
			self.cp.turnStage = 2;
			self.turnStageTimer = Utils.getNoNil(self.turnStage2Timeout,20000)

		-- TURN STAGE ??? --TODO (Jakob): what's the situation here? turnStage not > 1 and not > 0 ? When do we get to this point?
		else
			self.cp.turnStage = 1;
			if self.cp.noStopOnTurn == false then
				self.waitForTurnTime = self.timer + turnTimer;
			end
			courseplay:lowerImplements(self, false, true)
			updateWheels = false;
		end;

	-- TURN STAGE 0
	else
		if self.isStrawEnabled then 
			self.cp.savedNoStopOnTurn = self.cp.noStopOnTurn
			self.cp.noStopOnTurn = false
			turnTimer = self.strawToggleTime or 5;
		elseif self.cp.savedNoStopOnTurn ~= nil then
			self.cp.noStopOnTurn = self.cp.savedNoStopOnTurn
			self.cp.savedNoStopOnTurn = nil
		end
		
		local offset = Utils.getNoNil(self.cp.totalOffsetX, 0)
		local x,y,z = localToWorld(self.cp.DirectionNode, offset, 0, backMarker)
		local dist = courseplay:distance(self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz, x, z)
		if backMarker <= 0 then
			if  dist < 0.5 then
				if not self.cp.noStopOnTurn then
					self.cp.waitForTurnTime = self.timer + turnTimer
				end
				courseplay:lowerImplements(self, false, false)
				updateWheels = false;
				self.cp.turnStage = 1;
			end
		else
			if dist < 0.5 and self.cp.turnStage ~= -1 then
				self.cp.turnStage = -1
				courseplay:lowerImplements(self, false, false)
			end
			if dist > backMarker and self.cp.turnStage == -1 then
				if self.cp.noStopOnTurn == false then
					self.cp.waitForTurnTime = self.timer + turnTimer
				end
				updateWheels = false;
				self.cp.turnStage = 1;
			end
		end
		x,y,z = localToWorld(self.cp.DirectionNode, 0, 0, 1)
		self.aiTractorTargetX, self.aiTractorTargetZ = x,z
		
		x,y,z = getWorldTranslation(self.cp.DirectionNode);
		local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
		local targetX, targetZ = self.aiTractorTargetX, self.aiTractorTargetZ;
		local dx, dz = x-targetX, z-targetZ;
		local dot = dx*dirX + dz*dirZ;

		local projTargetX = targetX +dirX*dot;
		local projTargetZ = targetZ +dirZ*dot;
		
		
		newTargetX = projTargetX+self.aiTractorDirectionX
		newTargetY = y;
		newTargetZ = projTargetZ+self.aiTractorDirectionZ
	end;

	if updateWheels then
		local allowedToDrive = true
		local refSpeed = self.cp.speeds.turn
		self.cp.speedDebugLine = ("turn("..tostring(debug.getinfo(1).currentline-1).."): refSpeed = "..tostring(refSpeed))
		courseplay:setSpeed(self, refSpeed )
		
		local lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, newTargetX, newTargetY, newTargetZ);
		if self.cp.turnStage == 3 and math.abs(lx) < 0.1 then
			self.cp.turnStage = 4;
			moveForwards = true;
		end;
		if self.cp.TrafficBrake then
			moveForwards = self.movingDirection == -1;
			lx = 0
			lz = 1
		end
		if self.invertedDrivingDirection then
			lx = -lx
		end
		AIVehicleUtil.driveInDirection(self, dt, 25, 1, 0.5, 20, true, moveForwards, lx, lz, refSpeed, 1);
		courseplay:setTrafficCollision(self, lx, lz, true)
	end;
	
	if newTargetX ~= nil and newTargetZ ~= nil then
		self.aiTractorTargetX = newTargetX;
		self.aiTractorTargetZ = newTargetZ;
	end;
end

function courseplay:lowerImplements(self, moveDown, workToolonOff)
	--moveDown true= lower,  false = raise , workToolonOff true = switch on worktool,  false = switch off worktool
	if moveDown == nil then 
		moveDown = false; 
	end;

	local state  = 1;
	if moveDown then
		state  = -1;
    end;

    local specialTool;
	for _,workTool in pairs(self.cp.workTools) do
					--courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
		specialTool = courseplay:handleSpecialTools(self,workTool,true,moveDown,workToolonOff,nil,nil,nil);
		
		if not specialTool and workTool.setPickupState ~= nil then
			if workTool.isPickupLowered ~= nil and workTool.isPickupLowered ~= moveDown then
				workTool:setPickupState(moveDown, false);
			end;
		end;
	
	end;
	if not specialTool then
		if self.setAIImplementsMoveDown ~= nil then
			self:setAIImplementsMoveDown(moveDown,true);
		elseif self.setFoldState ~= nil then
			self:setFoldState(state, true);
		end;
		if self.cp.mode == 4 then
			for _,workTool in pairs(self.cp.workTools) do
				if workTool.setIsTurnedOn ~= nil and not courseplay:isFolding(workTool) and workTool ~= self and workTool.isTurnedOn ~= workToolonOff then
					workTool:setIsTurnedOn(workToolonOff, false);
				end;
			end;
		end;
	end;
end;

function courseplay:turnWithOffset(self)
	--SYMMETRIC LANE CHANGE
	if self.cp.symmetricLaneChange then
		if self.cp.switchLaneOffset then
			courseplay:changeLaneOffset(self, nil, self.cp.laneOffset * -1);
			self.cp.switchLaneOffset = false;
			courseplay:debug(string.format("%s: cp.turnStage == 1, switchLaneOffset=true -> new laneOffset=%.1f, new totalOffset=%.1f, set switchLaneOffset to false", nameNum(self), self.cp.laneOffset, self.cp.totalOffsetX), 12);
		end;
	end;
	--TOOL OFFSET TOGGLE
	if self.cp.hasPlough then
		if self.cp.switchToolOffset then
			courseplay:changeToolOffsetX(self, nil, self.cp.toolOffsetX * -1, true);
			self.cp.switchToolOffset = false;
			courseplay:debug(string.format("%s: cp.turnStage == 1, switchToolOffset=true -> new toolOffset=%.1f, new totalOffset=%.1f, set switchToolOffset to false", nameNum(self), self.cp.toolOffsetX, self.cp.totalOffsetX), 12);
		end;
	end;

	local curPoint = self.Waypoints[self.cp.waypointIndex+1]
	local cx, cz = curPoint.cx, curPoint.cz;
	local offsetX = self.cp.totalOffsetX
	if curPoint.turnEnd and curPoint.laneDir ~= nil then --TODO (Jakob): use point's direction to next point to get the proper offset
		local dir = curPoint.laneDir;
		local turnDir = curPoint.turn;
		
		if dir == "E" then
			cz = curPoint.cz + offsetX;
		elseif dir == "W" then
			cz = curPoint.cz - offsetX;
		elseif dir == "N" then
			cx = curPoint.cx + offsetX;
		elseif dir == "S" then
			cx = curPoint.cx - offsetX;
		end;
	end;
	return cx,cz
end
