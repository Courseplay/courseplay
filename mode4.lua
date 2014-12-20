function courseplay:handle_mode4(self, allowedToDrive, workSpeed, fillLevelPct, refSpeed)
	local workTool;
	local forceSpeedLimit = refSpeed
	local fieldArea = (self.recordnumber > self.cp.startWork) and (self.recordnumber < self.cp.stopWork)
	local workArea = (self.recordnumber > self.cp.startWork) and (self.recordnumber < self.cp.finishWork)
	local isFinishingWork = false
	local hasFinishedWork = false
	if self.recordnumber == self.cp.finishWork and self.cp.abortWork == nil then
		local _,y,_ = getWorldTranslation(self.cp.DirectionNode)
		local _,_,z = worldToLocal(self.cp.DirectionNode,self.Waypoints[self.cp.finishWork].cx,y,self.Waypoints[self.cp.finishWork].cz)
		z = -z
		local frontMarker = Utils.getNoNil(self.cp.aiFrontMarker,-3)
		if frontMarker + z < 0 then
			workArea = true
			isFinishingWork = true
		elseif self.cp.finishWork ~= self.cp.stopWork then
			courseplay:setRecordNumber(self, math.min(self.cp.finishWork + 1, self.maxnumber));
		end;
	end;
	
	--go with field speed	
	if fieldArea or self.recordnumber == self.cp.startWork then
		workSpeed = 1;
	end
	
	-- Begin Work
	if self.cp.lastRecordnumber == self.cp.startWork and fillLevelPct ~= 0 then
		if self.cp.abortWork ~= nil then
			if self.cp.abortWork < 5 then
				self.cp.abortWork = 6
			end
			courseplay:setRecordNumber(self, self.cp.abortWork);
			if self.Waypoints[self.recordnumber].turn ~= nil or self.Waypoints[self.recordnumber+1].turn ~= nil  then
				courseplay:setRecordNumber(self, self.recordnumber - 2);
			end
		end
	end
	-- last point reached restart
	if self.cp.abortWork ~= nil then
		if self.cp.lastRecordnumber == self.cp.abortWork and fillLevelPct ~= 0 then
			courseplay:setRecordNumber(self, self.cp.abortWork + 2);
		end
		if self.cp.lastRecordnumber == self.cp.abortWork + 8 then
			self.cp.abortWork = nil
		end
	end
	-- save last point
	if (fillLevelPct == 0 or self.cp.urfStop) and workArea then
		self.cp.urfStop = false
		if self.cp.hasUnloadingRefillingCourse and self.cp.abortWork == nil then
			self.cp.abortWork = self.recordnumber -10
			-- invert lane offset if abortWork is before previous turn point (symmetric lane change)
			if self.cp.symmetricLaneChange and self.cp.laneOffset ~= 0 then
				for i=self.cp.abortWork,self.cp.lastRecordnumber do
					local wp = self.Waypoints[i];
					if wp.turn ~= nil then
						courseplay:debug(string.format('%s: abortWork set (%d), abortWork + %d: turn=%s -> change lane offset back to abortWork\'s lane', nameNum(self), self.cp.abortWork, i-1, tostring(wp.turn)), 12);
						courseplay:changeLaneOffset(self, nil, self.cp.laneOffset * -1);
						self.cp.switchLaneOffset = true;
						break;
					end;
				end;
			end;
			courseplay:setRecordNumber(self, self.cp.stopWork - 4);
			--courseplay:debug(string.format("Abort: %d StopWork: %d",self.cp.abortWork,self.cp.stopWork), 12)
		elseif not self.cp.hasUnloadingRefillingCourse then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'NEEDS_REFILLING');
		end;
	end
	--
	if (self.recordnumber == self.cp.stopWork or self.cp.lastRecordnumber == self.cp.stopWork) and self.cp.abortWork == nil and not isFinishingWork and self.cp.wait then
		allowedToDrive = false;
		CpManager:setGlobalInfoText(self, 'WORK_END');
		hasFinishedWork = true;
		if self.cp.hasUnloadingRefillingCourse and self.recordnumber == self.cp.stopWork then --make sure that lastRecordnumber is stopWork, so the 'waiting points' algorithm in drive() works
			courseplay:setRecordNumber(self, self.cp.stopWork + 1);
		end;
	end;
	
	local firstPoint = self.cp.lastRecordnumber == 1;
	local prevPoint = self.Waypoints[self.cp.lastRecordnumber];
	local nextPoint = self.Waypoints[self.recordnumber];
	
	local ridgeMarker = prevPoint.ridgeMarker;
	local turnStart = prevPoint.turnStart;
	local turnEnd = prevPoint.turnEnd;
	for i=1, #(self.cp.workTools) do
		workTool = self.cp.workTools[i];
		local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool);
		local needsLowering = false
		
		if workTool.attacherJoint ~= nil then
			needsLowering = workTool.attacherJoint.needsLowering
		end
		
		--speedlimits
		local speedLimitActive = false
		if workTool.doCheckSpeedLimit and workTool:doCheckSpeedLimit() then
			forceSpeedLimit = math.min(forceSpeedLimit, workTool.speedLimit)
			speedLimitActive = true
		end

		
		-- stop while folding
		if courseplay:isFoldable(workTool) then
			if isFolding and self.cp.turnStage == 0 then
				allowedToDrive = false;
				--courseplay:debug(tostring(workTool.name) .. ": isFolding -> allowedToDrive == false", 12);
			end;
			--courseplay:debug(string.format("%s: unfold: turnOnFoldDirection=%s, foldMoveDirection=%s", workTool.name, tostring(workTool.turnOnFoldDirection), tostring(workTool.foldMoveDirection)), 12);
		end;

		if workArea and fillLevelPct ~= 0 and (self.cp.abortWork == nil or self.cp.runOnceStartCourse) and self.cp.turnStage == 0 and not self.cp.inTraffic then
			self.cp.runOnceStartCourse = false;
			--turn On                     courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker)
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,true,true,true,allowedToDrive,nil,nil, ridgeMarker)
			if allowedToDrive then
				if not specialTool then
					--unfold
					if courseplay:isFoldable(workTool) and workTool:getIsFoldAllowed() and not isFolding and not isUnfolded then -- and ((self.cp.abortWork ~= nil and self.recordnumber == self.cp.abortWork - 2) or (self.cp.abortWork == nil and self.recordnumber == 2)) then
						courseplay:debug(string.format('%s: unfold order (foldDir %d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
						workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
					end;
					
					if not isFolding and isUnfolded then
						--set or stow ridge markers
						if courseplay:isSowingMachine(workTool) and self.cp.ridgeMarkersAutomatic then
							if ridgeMarker ~= nil then
								if workTool.cp.haveInversedRidgeMarkerState then
									if ridgeMarker == 1 then
										ridgeMarker = 2;
									elseif ridgeMarker == 2 then
										ridgeMarker = 1;
									end;
									-- Skip 0 state, since that is the closed state.
								end;

								if workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= ridgeMarker then
									workTool:setRidgeMarkerState(ridgeMarker);
								end;
							elseif workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
								workTool:setRidgeMarkerState(0);
							end;
						end;

						--lower/raise
						if needsLowering and workTool.aiNeedsLowering then
							--courseplay:debug(string.format("WP%d: isLowered() = %s, hasGroundContact = %s", self.recordnumber, tostring(workTool:isLowered()), tostring(workTool.hasGroundContact)),12);
							if not workTool:isLowered() then
								courseplay:debug(string.format('%s: lower order', nameNum(workTool)), 17);
								self:setAIImplementsMoveDown(true);
								courseplay:setCustomTimer(self, "lowerTimeOut" , 5 )
							elseif not speedLimitActive and not courseplay:timerIsThrough(self, "lowerTimeOut") then 
								allowedToDrive = false;
								courseplay:debug(string.format('%s: wait for lowering', nameNum(workTool)), 17);
							end;
						end;
						--turn on
						if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn then
							courseplay:setMarkers(self, workTool);
							if courseplay:isSowingMachine(workTool) then
								--do manually instead of :setIsTurnedOn so that workTool.turnOnAnimation and workTool.playAnimation aren't called
								workTool.isTurnedOn = true;
								--[[if workTool.airBlowerSoundEnabled ~= nil then
									workTool.airBlowerSoundEnabled = true;
								end;]]
							else
								workTool:setIsTurnedOn(true, false);
							end;
							courseplay:debug(string.format('%s: turn on order', nameNum(workTool)), 17);
						end;
					end; --END if not isFolding
				end

				--DRIVINGLINE SPEC
				if workTool.cp.hasSpecializationDrivingLine and not workTool.manualDrivingLine then
					local curLaneReal = self.Waypoints[self.recordnumber].laneNum;
					if curLaneReal then
						local intendedDrivingLane = ((curLaneReal-1) % workTool.nSMdrives) + 1;
						if workTool.currentDrive ~= intendedDrivingLane then
							courseplay:debug(string.format('%s: currentDrive=%d, curLaneReal=%d -> intendedDrivingLane=%d -> set', nameNum(workTool), workTool.currentDrive, curLaneReal, intendedDrivingLane), 17);
							workTool.currentDrive = intendedDrivingLane;
						end;
					end;
				end;
			end;

		--TRAFFIC: TURN OFF
		elseif workArea and self.cp.abortWork == nil and self.cp.inTraffic then
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self, workTool, true, true, false, allowedToDrive, nil, nil, ridgeMarker);
			if not specialTool then
				if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn then
					workTool:setIsTurnedOn(false, false);
				end;
				courseplay:debug(string.format('%s: [TRAFFIC] turn off order', nameNum(workTool)), 17);
			end;

		--TURN OFF AND FOLD
		elseif self.cp.turnStage == 0 then
			--turn off
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,nil, ridgeMarker)
			if not specialTool then
				if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn then
					workTool:setIsTurnedOn(false, false);
					courseplay:debug(string.format('%s: turn off order', nameNum(workTool)), 17);
				end;

				--raise
				if not isFolding and isUnfolded then
					if needsLowering and workTool.aiNeedsLowering and workTool:isLowered() then
						self:setAIImplementsMoveDown(false);
						courseplay:debug(string.format('%s: raise order', nameNum(workTool)), 17);
					end;
				end;

				--retract ridgemarker
				if workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
					workTool:setRidgeMarkerState(0);
				end;
				
				--fold
				if courseplay:isFoldable(workTool) and not isFolding and not isFolded then
					courseplay:debug(string.format('%s: fold order (foldDir=%d)', nameNum(workTool), -workTool.cp.realUnfoldDirection), 17);
					workTool:setFoldDirection(-workTool.cp.realUnfoldDirection);
				end;
			end
		end

		--[[if not allowedToDrive then
			workTool:setIsTurnedOn(false, false)
		end]] --?? why am i here ??
	end; --END for i in self.cp.workTools
	if hasFinishedWork then
		isFinishingWork = true
	end
	return allowedToDrive, workArea, workSpeed,isFinishingWork,forceSpeedLimit
end;
