function courseplay:handle_mode4(self, allowedToDrive, workSpeed, refSpeed)
	local workTool;
	local forceSpeedLimit = refSpeed
	local fieldArea = (self.cp.waypointIndex > self.cp.startWork) and (self.cp.waypointIndex < self.cp.stopWork)
	local workArea = (self.cp.waypointIndex > self.cp.startWork) and (self.cp.waypointIndex < self.cp.finishWork)
	local isFinishingWork = false
	local hasFinishedWork = false
	local seederFillLevelPct = self.cp.totalSeederFillLevelPercent   or 100;
	local sprayerFillLevelPct = self.cp.totalSprayerFillLevelPercent or 100;
	
	--print(string.format("seederFillLevelPct:%s; sprayerFillLevelPct:%s",tostring(seederFillLevelPct),tostring(sprayerFillLevelPct)))
	if self.cp.waypointIndex == self.cp.finishWork and self.cp.abortWork == nil then
		local _,y,_ = getWorldTranslation(self.cp.DirectionNode)
		local _,_,z = worldToLocal(self.cp.DirectionNode,self.Waypoints[self.cp.finishWork].cx,y,self.Waypoints[self.cp.finishWork].cz)
		z = -z
		local frontMarker = Utils.getNoNil(self.cp.aiFrontMarker,-3)
		if frontMarker + z -2 < 0 then
			workArea = true
			isFinishingWork = true
		elseif self.cp.finishWork ~= self.cp.stopWork then
			courseplay:setWaypointIndex(self, math.min(self.cp.finishWork + 1, self.cp.numWaypoints));
		end;
	end;
	if self.cp.hasTransferCourse and self.cp.abortWork ~= nil and self.cp.waypointIndex == 1 then
		courseplay:setWaypointIndex(self,self.cp.startWork+1);
	end
	--go with field speed	
	if fieldArea or self.cp.waypointIndex == self.cp.startWork or self.cp.waypointIndex == self.cp.stopWork +1 then
		workSpeed = 1;
	end
	
	-- Begin Work
	if self.cp.previousWaypointIndex == self.cp.startWork then
		if seederFillLevelPct ~= 0 and sprayerFillLevelPct ~= 0 then
			if self.cp.abortWork ~= nil then
				if self.cp.abortWork < 5 then
					self.cp.abortWork = 6
				end
				courseplay:setWaypointIndex(self, self.cp.abortWork);
				if self.Waypoints[self.cp.waypointIndex].turnStart or self.Waypoints[self.cp.waypointIndex+1].turnStart then
					courseplay:setWaypointIndex(self, self.cp.waypointIndex - 2);
				end
			end
		elseif self.cp.hasUnloadingRefillingCourse and self.cp.abortWork ~= nil then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'NEEDS_REFILLING');		
		end
	end
	-- last point reached restart
	if self.cp.abortWork ~= nil then
		if self.cp.previousWaypointIndex == self.cp.abortWork and seederFillLevelPct ~= 0 and sprayerFillLevelPct ~= 0 then
			courseplay:setWaypointIndex(self, self.cp.abortWork + 2);
		end
		if self.cp.previousWaypointIndex < self.cp.stopWork and self.cp.previousWaypointIndex > self.cp.abortWork + 9 + self.cp.abortWorkExtraMoveBack then
			self.cp.abortWork = nil;
		end
	end
	-- save last point
	if (seederFillLevelPct == 0 or sprayerFillLevelPct == 0 or self.cp.urfStop) and workArea then
		self.cp.urfStop = false
		if self.cp.hasUnloadingRefillingCourse and self.cp.abortWork == nil then
			courseplay:setAbortWorkWaypoint(self);
		elseif not self.cp.hasUnloadingRefillingCourse then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(self, 'NEEDS_REFILLING');
		end;
	end
	--
	if (self.cp.waypointIndex == self.cp.stopWork or self.cp.previousWaypointIndex == self.cp.stopWork) and self.cp.abortWork == nil and not isFinishingWork and self.cp.wait then
		allowedToDrive = false;
		CpManager:setGlobalInfoText(self, 'WORK_END');
		hasFinishedWork = true;
		if self.cp.hasUnloadingRefillingCourse and self.cp.waypointIndex == self.cp.stopWork then --make sure that previousWaypointIndex is stopWork, so the 'waiting points' algorithm in drive() works
			courseplay:setWaypointIndex(self, self.cp.stopWork + 1);
		end;
	end;
	
	local firstPoint = self.cp.previousWaypointIndex == 1;
	local prevPoint = self.Waypoints[self.cp.previousWaypointIndex];
	local nextPoint = self.Waypoints[self.cp.waypointIndex];
	
	local ridgeMarker = prevPoint.ridgeMarker;
	local turnStart = prevPoint.turnStart;
	local turnEnd = prevPoint.turnEnd;
	local specialTool; -- define it, so it will not be an global value anymore
	for i=1, #(self.cp.workTools) do
		workTool = self.cp.workTools[i];
		local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool);
		local needsLowering = false

		if workTool.attacherJoint ~= nil then
			needsLowering = workTool.attacherJoint.needsLowering
		end
		
		--speedlimits
		local speedLimitActive = false
		
		forceSpeedLimit, speedLimitActive = courseplay:getSpeedWithLimiter(workTool, forceSpeedLimit);

		-- stop while folding
		if courseplay:isFoldable(workTool) then
			if isFolding and self.cp.turnStage == 0 then
				allowedToDrive = false;
				--courseplay:debug(tostring(workTool.name) .. ": isFolding -> allowedToDrive == false", 12);
			end;
			--courseplay:debug(string.format("%s: unfold: turnOnFoldDirection=%s, foldMoveDirection=%s", workTool.name, tostring(workTool.turnOnFoldDirection), tostring(workTool.foldMoveDirection)), 12);
		end;
		if workArea and seederFillLevelPct ~= 0 and sprayerFillLevelPct ~= 0 and (self.cp.abortWork == nil or self.cp.runOnceStartCourse) and self.cp.turnStage == 0 and not self.cp.inTraffic then
			self.cp.runOnceStartCourse = false;
			--turn On                     courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker)
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,true,true,true,allowedToDrive,nil,nil, ridgeMarker)
			local hasSetUnfoldOrderThisLoop = false
			if allowedToDrive then
				if not specialTool then
					--unfold
					if courseplay:isFoldable(workTool) and workTool:getIsFoldAllowed() and not isFolding and not isUnfolded then -- and ((self.cp.abortWork ~= nil and self.cp.waypointIndex == self.cp.abortWork - 2) or (self.cp.abortWork == nil and self.cp.waypointIndex == 2)) then
						courseplay:debug(string.format('%s: unfold order (foldDir %d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
						workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
						hasSetUnfoldOrderThisLoop = true
					end;
					if hasSetUnfoldOrderThisLoop then
						isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool);
					end
															--vv  used for foldables, which are not folding before start Strautmann manure spreader 
					if not isFolding and (isUnfolded or hasSetUnfoldOrderThisLoop) then 
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

								if workTool.ridgeMarkers and #workTool.ridgeMarkers > 0 and workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= ridgeMarker then
									workTool:setRidgeMarkerState(ridgeMarker);
								end;
							elseif workTool.ridgeMarkers and #workTool.ridgeMarkers > 0 and workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
								workTool:setRidgeMarkerState(0);
							end;
						end;

						--lower/raise
						if (needsLowering or workTool.aiNeedsLowering) then
							--courseplay:debug(string.format("WP%d: isLowered() = %s, hasGroundContact = %s", self.cp.waypointIndex, tostring(workTool:isLowered()), tostring(workTool.hasGroundContact)),12);
							if not workTool:isLowered() then
								courseplay:debug(string.format('%s: lower order', nameNum(workTool)), 17);
								workTool:aiLower();
								courseplay:setCustomTimer(self, "lowerTimeOut" , 5 )
							elseif not speedLimitActive and not courseplay:timerIsThrough(self, "lowerTimeOut") then 
								allowedToDrive = false;
								courseplay:debug(string.format('%s: wait for lowering', nameNum(workTool)), 17);
							end;
						end;
						--turn on
						if workTool.setIsTurnedOn ~= nil and not workTool.turnOnVehicle.isTurnedOn then
							courseplay:setMarkers(self, workTool);
							if courseplay:isSowingMachine(workTool) then
								workTool:setIsTurnedOn(true,false);
							else
								if workTool.lastTurnedOn then
									workTool.lastTurnedOn = false
								end
								workTool:setIsTurnedOn(true,false);
							end;
							courseplay:debug(string.format('%s: turn on order', nameNum(workTool)), 17);
						end;
					end; --END if not isFolding
				end

				--DRIVINGLINE SPEC
				if workTool.cp.hasSpecializationDrivingLine and not workTool.manualDrivingLine then
					local curLaneReal = self.Waypoints[self.cp.waypointIndex].laneNum;
					if curLaneReal then
						local intendedDrivingLane = ((curLaneReal-1) % workTool.nSMdrives) + 1;
						if workTool.currentLane ~= intendedDrivingLane then
							courseplay:debug(string.format('%s: currentLane=%d, curLaneReal=%d -> intendedDrivingLane=%d -> set', nameNum(workTool), workTool.currentLane, curLaneReal, intendedDrivingLane), 17);
							workTool.currentLane = intendedDrivingLane;
						end;
					end;
				end;
			end;

		--TRAFFIC: TURN OFF
		elseif workArea and self.cp.abortWork == nil and self.cp.inTraffic then
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self, workTool, true, true, false, allowedToDrive, nil, nil, ridgeMarker);
			if not specialTool then
				if workTool.setIsTurnedOn ~= nil and workTool.turnOnVehicle.isTurnedOn then
					workTool:setIsTurnedOn(false, false);
				end;
				courseplay:debug(string.format('%s: [TRAFFIC] turn off order', nameNum(workTool)), 17);
			end;

		--TURN OFF AND FOLD
		elseif self.cp.turnStage == 0 then
			--turn off
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,nil, ridgeMarker)
			if not specialTool then
				if workTool.setIsTurnedOn ~= nil and workTool.turnOnVehicle.isTurnedOn then
					workTool:setIsTurnedOn(false, false);
					courseplay:debug(string.format('%s: turn off order', nameNum(workTool)), 17);
				end;

				--raise
				if not isFolding and isUnfolded then
					if (needsLowering or workTool.aiNeedsLowering) and workTool:isLowered() then
						workTool:aiRaise();
						courseplay:debug(string.format('%s: raise order', nameNum(workTool)), 17);
					end;
				end;

				--retract ridgemarker
				if workTool.ridgeMarkers and #workTool.ridgeMarkers > 0 and workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
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
