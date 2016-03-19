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
	if self.cp.lastDistanceToTurnPoint == nil then
		self.cp.lastDistanceToTurnPoint = math.huge;
	end
	if not self.cp.checkMarkers then
		self.cp.checkMarkers = true
		for _,workTool in pairs(self.cp.workTools) do
			courseplay:setMarkers(self, workTool)
			courseplay:askForSpecialSettings(self, workTool)
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
			self.cp.lastDistanceToTurnPoint = math.huge;
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
		else              -- The situation is when a turn timeout appears...
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
		local targetX,targetZ = self.Waypoints[self.cp.waypointIndex].cx, self.Waypoints[self.cp.waypointIndex].cz;
		local x,y,z = localToWorld(self.cp.DirectionNode, offset, 0, backMarker)
		local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,targetX,0,targetZ)
		local dist = courseplay:distance3D(targetX,terrainHeight,targetZ, x,y,z)
		--local dist = courseplay:distance(targetX,targetZ,x,z)
		-- print(string.format("distance: %f; backmarker %f; y:%.3f vs Height:%.3f",dist,backMarker,y,terrainHeight))
		if backMarker <= 0 then
			if  dist < 0.5 or self.cp.lastDistanceToTurnPoint < dist then
				if not self.cp.noStopOnTurn then
					self.cp.waitForTurnTime = self.timer + turnTimer
				end
				courseplay:lowerImplements(self, false, false)
				updateWheels = false;
				self.cp.turnStage = 1;
			else
				self.cp.lastDistanceToTurnPoint = dist;
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
			for _,workTool in pairs(self.cp.workTools) do								 --vvTODO (Tom) why is this here vv?
				if workTool.setIsTurnedOn ~= nil and not courseplay:isFolding(workTool) and (true or workTool ~= self) and workTool.isTurnedOn ~= workToolonOff then
					workTool:setIsTurnedOn(workToolonOff, false);                          -- disabled for Pantera
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
