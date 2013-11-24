function courseplay:handle_mode4(self, allowedToDrive, workArea, workSpeed, fill_level)
	local workTool; -- = self.tippers[1] -- to do, quick, dirty and unsafe

	workArea = (self.recordnumber > self.startWork) and (self.recordnumber < self.stopWork)

	-- Begin Work
	if self.cp.last_recordnumber == self.startWork and fill_level ~= 0 then
		if self.abortWork ~= nil then
			if self.abortWork < 5 then
				self.abortWork = 6
			end
			self.recordnumber = self.abortWork
			if self.Waypoints[self.recordnumber].turn ~= nil or self.Waypoints[self.recordnumber+1].turn ~= nil  then
				self.recordnumber = self.recordnumber -2
			end
		end
	end
	-- last point reached restart
	if self.abortWork ~= nil then
		if self.cp.last_recordnumber == self.abortWork and fill_level ~= 0 then
			self.recordnumber = self.abortWork +2
		end
		if self.cp.last_recordnumber == self.abortWork + 8 then
			self.abortWork = nil
		end
	end
	-- safe last point
	if (fill_level == 0 or self.cp.urfStop) and workArea then
		self.cp.urfStop = false
		if self.cp.hasUnloadingRefillingCourse and self.abortWork == nil then
			self.abortWork = self.recordnumber -10
			self.recordnumber = self.stopWork - 4
			--courseplay:debug(string.format("Abort: %d StopWork: %d",self.abortWork,self.stopWork), 12)
		elseif not self.cp.hasUnloadingRefillingCourse then
			allowedToDrive = false;
			courseplay:setGlobalInfoText(self, ": " .. courseplay:get_locale(self, "CPworkToolNeedsToBeRefilled"), -1);
		end;
	end
	--
	if ((self.recordnumber == self.stopWork and not self.cp.hasUnloadingRefillingCourse) or self.cp.last_recordnumber == self.stopWork) and self.abortWork == nil then
		allowedToDrive = courseplay:brakeToStop(self)
		courseplay:setGlobalInfoText(self, courseplay:get_locale(self, "CPWorkEnd"), 1);
	end
	
	
	local returnToStartPoint = false;
	if  self.Waypoints[self.stopWork].cx == self.Waypoints[self.startWork].cx 
	and self.Waypoints[self.stopWork].cz == self.Waypoints[self.startWork].cz 
	and self.recordnumber > self.stopWork - 5
	and self.recordnumber <= self.stopWork then
		returnToStartPoint = true;
	end;
	
	local firstPoint = self.cp.last_recordnumber == 1;
	local prevPoint = self.Waypoints[self.cp.last_recordnumber];
	local nextPoint = self.Waypoints[self.recordnumber];
	
	local ridgeMarker = prevPoint.ridgeMarker;
	local turnStart = prevPoint.turnStart;
	local turnEnd = prevPoint.turnEnd;

	for i=1, table.getn(self.tippers) do
		workTool = self.tippers[i];

		-- stop while folding
		if courseplay:isFoldable(workTool) then
			if courseplay:isFolding(workTool) and self.cp.turnStage == 0 then
				allowedToDrive = false;
				--courseplay:debug(tostring(workTool.name) .. ": isFolding -> allowedToDrive == false", 12);
			end;
			--courseplay:debug(string.format("%s: unfold: turnOnFoldDirection=%s, foldMoveDirection=%s", workTool.name, tostring(workTool.turnOnFoldDirection), tostring(workTool.foldMoveDirection)), 12);
		end;

		if workArea and fill_level ~= 0 and (self.abortWork == nil or self.runOnceStartCourse) and self.cp.turnStage == 0 and not returnToStartPoint and not self.cp.inTraffic then
			self.runOnceStartCourse = false;
			workSpeed = 1;
			--turn On                     courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker)
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,true,true,true,allowedToDrive,nil,nil, ridgeMarker)
			if allowedToDrive then
				if not specialTool then
					--unfold
					if courseplay:isFoldable(workTool) and workTool:getIsFoldAllowed() then -- and ((self.abortWork ~= nil and self.recordnumber == self.abortWork - 2) or (self.abortWork == nil and self.recordnumber == 2)) then
						if courseplay:is_sowingMachine(workTool) then
							workTool:setFoldDirection(-1);
						
						elseif workTool.turnOnFoldDirection ~= nil and workTool.turnOnFoldDirection ~= 0 then
							workTool:setFoldDirection(workTool.turnOnFoldDirection);
						
						--Backup
						else
							workTool:setFoldDirection(1); --> doesn't work for Kotte VTL (liquidManure)
						end;
					end;
					
					if not courseplay:isFolding(workTool) then
						--set or stow ridge markers
						if courseplay:is_sowingMachine(workTool) and self.cp.ridgeMarkersAutomatic then
							if ridgeMarker ~= nil then
								if workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= ridgeMarker then
									workTool:setRidgeMarkerState(ridgeMarker);
								end;
							elseif workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
								workTool:setRidgeMarkerState(0);
							end;
						end;

						--lower/raise
						if workTool.needsLowering and workTool.aiNeedsLowering then
							--courseplay:debug(string.format("WP%d: isLowered() = %s, hasGroundContact = %s", self.recordnumber, tostring(workTool:isLowered()), tostring(workTool.hasGroundContact)),12);
							if not workTool:isLowered() then
								self:setAIImplementsMoveDown(true);
							end;
						end;

						--turn on
						if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn then
							courseplay:setMarkers(self, workTool);
							if courseplay:is_sowingMachine(workTool) then
								--do manually instead of :setIsTurnedOn so that workTool.turnOnAnimation and workTool.playAnimation aren't called
								workTool.isTurnedOn = true;
								--[[if workTool.airBlowerSoundEnabled ~= nil then
									workTool.airBlowerSoundEnabled = true;
								end;]]
							else
								workTool:setIsTurnedOn(true, false);
							end;
						end;
					end; --END if not isFolding
				end
			end;
		elseif self.cp.turnStage == 0 then
			workSpeed = 0;
			--turn off
			specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,nil, ridgeMarker)
			if not specialTool then
				if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn then
					workTool:setIsTurnedOn(false, false);
				end;

				--raise
				if not courseplay:isFolding(workTool) then
					if workTool.needsLowering and workTool.aiNeedsLowering and workTool:isLowered() then
						self:setAIImplementsMoveDown(false);
					end;
				end;

				--retract ridgemarker
				if workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
					workTool:setRidgeMarkerState(0);
				end;
				
				--fold
				if courseplay:isFoldable(workTool) then
					if courseplay:is_sowingMachine(workTool) then
						workTool:setFoldDirection(1);

					elseif workTool.turnOnFoldDirection ~= nil and workTool.turnOnFoldDirection ~= 0 then
						workTool:setFoldDirection(-workTool.turnOnFoldDirection);
						
					--Backup
					else
						workTool:setFoldDirection(-1); --> doesn't work for Kotte VTL (liquidManure)
					end;
				end;
			end
		end

		--[[if not allowedToDrive then
			workTool:setIsTurnedOn(false, false)
		end]] --?? why am i here ??
	end; --END for i in self.tippers

	return allowedToDrive, workArea, workSpeed
end;
