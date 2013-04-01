function courseplay:turn(self, dt) --!!!
	local newTargetX, newTargetY, newTargetZ;
	local moveForwards = true;
	local updateWheels = true;
	local turnOutTimer = 1500
	if self.cp.noStopOnEdge then 
		turnOutTimer = 0
	end
	self.cp.turnTimer = self.cp.turnTimer - dt;

	if self.cp.turnTimer < 0 or self.cp.turnStage > 0 then
		if self.cp.turnStage > 1 then
			local x,y,z = getWorldTranslation(self.rootNode);
			local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
			local myDirX, myDirY, myDirZ = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);

			newTargetX = self.aiTractorTargetX;
			newTargetY = y;
			newTargetZ = self.aiTractorTargetZ;
			if self.cp.turnStage == 2 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if self.cp.isTurning == "left" then
					AITractor.aiRotateLeft(self);
				else
					AITractor.aiRotateRight(self);
				end
				if myDirX*dirX + myDirZ*dirZ > 0.2 or self.turnStageTimer < 0 then
					if self.cp.aiTurnNoBackward or
					(courseplay:distance(newTargetX, newTargetZ, self.Waypoints[self.recordnumber-1].cx, self.Waypoints[self.recordnumber-1].cz) > self.turn_radius *1.2) then
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
			elseif self.cp.turnStage == 3 then
				self.turnStageTimer = self.turnStageTimer - dt;
				if myDirX*dirX + myDirZ*dirZ > 0.95 or self.turnStageTimer < 0 then
					self.cp.turnStage = 4;
				else
					moveForwards = false;
				end;
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
			elseif self.cp.turnStage == 5 then
				local frontNode
				if self.cp.aiFrontMarker ~= nil then
					frontNode = self.cp.aiFrontMarker
				else
					frontNode = self.rootNode
				end
				local backX, backY, backZ = getWorldTranslation(frontNode);
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
					self.recordnumber = self.recordnumber +1
					courseplay:lowerImplements(self, true, true)
					self.cp.turnTimer = 8000
					self.cp.isTurning = nil 
					self.cp.waitForTurnTime = self.time + turnOutTimer; 
				end;
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
			if CPDebugLevel > 0 then drawDebugPoint(newTargetX, y+3, newTargetZ, 1, 1, 0, 1) end			
		elseif self.cp.turnStage == 1 then
			-- turn
			local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
			if self.cp.isTurning == "right" then
				self.aiTractorTurnLeft = false;
			else
				self.aiTractorTurnLeft = true;
			end
			if self.WpOffsetX ~= nil and self.WpOffsetZ ~= nil and (self.WpOffsetX ~= 0 or self.WpOffsetZ ~= 0 ) then
				cx,cz = courseplay:turnWithOffset(self)
			else
				cx = self.Waypoints[self.recordnumber].cx		
				cz = self.Waypoints[self.recordnumber].cz
			end
			newTargetX = cx
			newTargetY = y;
			newTargetZ = cz
			
			self.aiTractorTargetBeforeTurnX = self.aiTractorTargetX;
			self.aiTractorTargetBeforeTurnZ = self.aiTractorTargetZ;

			self.aiTractorDirectionX = -dirX;
			self.aiTractorDirectionZ = -dirZ;
			self.cp.turnStage = 2;
			self.turnStageTimer = Utils.getNoNil(self.turnStage2Timeout,20000)
		else
			self.cp.turnStage = 1;
			self.waitForTurnTime = self.time + 1500;
			courseplay:lowerImplements(self, false, true)
			updateWheels = false;
		end;
	else
		local offset = Utils.getNoNil(self.WpOffsetX ,0)
		local x,y,z = localToWorld(self.rootNode, offset, 0, -(Utils.getNoNil(self.cp.backMarkerOffset, 0)))
		local dist = courseplay:distance(self.Waypoints[self.recordnumber-1].cx, self.Waypoints[self.recordnumber-1].cz, x, z)
		if self.grainTankCapacity ~= nil then
			self.cp.noStopOnEdge = true
		end

		if  dist < 0.5 or  Utils.getNoNil(self.cp.backMarkerOffset, 0) < 0 then
			self.cp.waitForTurnTime = self.timer + 1500
			courseplay:lowerImplements(self, false, true)
			updateWheels = false;
			self.cp.turnStage = 1;
		end
		
		x,y,z = localToWorld(self.cp.DirectionNode, 0, 0, 1)
		self.aiTractorTargetX, self.aiTractorTargetZ = x,z
		local dirX, dirZ = self.aiTractorDirectionX, self.aiTractorDirectionZ;
		
		x,y,z = getWorldTranslation(self.rootNode);
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
		local lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, newTargetX, newTargetY, newTargetZ);
		if self.cp.turnStage == 3 and math.abs(lx) < 0.1 then
			self.cp.turnStage = 4;
			moveForwards = true;
		end;

		AIVehicleUtil.driveInDirection(self, dt, 25, 0.5, 0.5, 20, true, moveForwards, lx, lz, speedLevel, 0.9);
		
		local maxlx = 0.7071067; --math.sin(maxAngle);
		local colDirX = lx;
		local colDirZ = lz;

		if colDirX > maxlx then
			colDirX = maxlx;
			colDirZ = 0.7071067; --math.cos(maxAngle);
		elseif colDirX < -maxlx then
			colDirX = -maxlx;
			colDirZ = 0.7071067; --math.cos(maxAngle);
		end;

		for triggerId,_ in pairs(self.numCollidingVehicles) do
			AIVehicleUtil.setCollisionDirection(self.cp.DirectionNode, triggerId, colDirX, colDirZ);
		end;
	end;
	
	if newTargetX ~= nil and newTargetZ ~= nil then
		self.aiTractorTargetX = newTargetX;
		self.aiTractorTargetZ = newTargetZ;
	end;
	
end

function courseplay:lowerImplements(self, direction, workToolonOff)
	--direction true= lower,  false = raise , workToolonOff true = switch on worktool,  false = switch off worktool
	local state  = 1
	if direction then
		state  = -1
	end	
	if  self.setAIImplementsMoveDown ~= nil then
		self:setAIImplementsMoveDown(direction)
	elseif self.setFoldState ~= nil then
		self:setFoldState(state, true)
	end		
	if workToolonOff then 
		for _,workTool in pairs(self.tippers) do
			if workTool.setIsTurnedOn ~= nil and not courseplay:isFolding(workTool) then
				workTool:setIsTurnedOn(direction, false);
			end
		end
	end
end
function courseplay:turnWithOffset(self)
	local curPoint = self.Waypoints[self.recordnumber]
	local cx = curPoint.cx;
	local cz = curPoint.cz;
	local offsetX = self.WpOffsetX
	if curPoint.turnEnd and curPoint.laneDir ~= nil then
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
