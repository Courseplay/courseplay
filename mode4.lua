function courseplay:handle_mode4(self, allowedToDrive, workArea, workSpeed, fill_level, last_recordnumber)
	local workTool; -- = self.tippers[1] -- to do, quick, dirty and unsafe

	workArea = (self.recordnumber > self.startWork) and (self.recordnumber < self.stopWork)

	-- Begin Work
	if last_recordnumber == self.startWork and fill_level ~= 0 then
		if self.abortWork ~= nil then
			if self.abortWork < 5 then
				self.abortWork = 6
			end
			self.recordnumber = self.abortWork
		end
	end
	-- last point reached restart
	if self.abortWork ~= nil then
		if last_recordnumber == self.abortWork and fill_level ~= 0 then
			self.recordnumber = self.abortWork +2
			self.abortWork = nil
		end
	end
	-- safe last point
	if fill_level == 0 and workArea and self.abortWork == nil then
		self.abortWork = self.recordnumber -10
		self.recordnumber = self.stopWork - 4
		--	courseplay:debug(string.format("Abort: %d StopWork: %d",self.abortWork,self.stopWork), 2)
	end
	
	local returnToStartPoint = false;
	if  self.Waypoints[self.stopWork].cx == self.Waypoints[self.startWork].cx 
	and self.Waypoints[self.stopWork].cz == self.Waypoints[self.startWork].cz 
	and self.recordnumber > self.stopWork - 5
	and self.recordnumber <= self.stopWork then
		returnToStartPoint = true;
	end;
	
	local firstPoint = last_recordnumber == 1;
	local prevPoint = self.Waypoints[last_recordnumber];
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
				courseplay:debug(workTool.name .. ": isFolding -> allowedToDrive == false", 3);
			end;
			--courseplay:debug(string.format("%s: unfold: turnOnFoldDirection=%s, foldMoveDirection=%s", workTool.name, tostring(workTool.turnOnFoldDirection), tostring(workTool.foldMoveDirection)), 3);
		end;

		if workArea and fill_level ~= 0 and (self.abortWork == nil or self.runOnceStartCourse) and self.cp.turnStage == 0 then
			self.runOnceStartCourse = false;
			workSpeed = 1;
			if allowedToDrive then
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
							if workTool.ridgeMarkerState ~= ridgeMarker then
								workTool:setRidgeMarkerState(ridgeMarker);
							end;
						elseif workTool.ridgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
							workTool:setRidgeMarkerState(0);
						end;
					end;

					--lower/raise
					if workTool.needsLowering and workTool.aiNeedsLowering then
						--courseplay:debug(string.format("WP%d: isLowered() = %s, hasGroundContact = %s", self.recordnumber, tostring(workTool:isLowered()), tostring(workTool.hasGroundContact)),3);
						--TODO: still needed here? already implemented in turn maneuver
						if turnEnd ~= nil and turnStart ~= nil then
							if not workTool:isLowered() and turnEnd == false and turnStart == false then
								self:setAIImplementsMoveDown(true);
							end;
						elseif not workTool:isLowered() then
							self:setAIImplementsMoveDown(true);
						end;
					end;

					--turn on
					if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn and not returnToStartPoint then
						if courseplay:is_sowingMachine(workTool) then
							--do manually instead of :setIsTurnedOn so that workTool.turnOnAnimation and workTool.playAnimation aren't called
							workTool.isTurnedOn = true;
							--[[if workTool.airBlowerSoundEnabled ~= nil then
								workTool.airBlowerSoundEnabled = true;
							end;]]
						else
							--Tebbe HS180 (Maurus)
							if workTool.setDoorHigh ~= nil and workTool.doorhigh ~= nil then
								workTool:setDoorHigh(3); --TODO: make configurable
							end;
							if workTool.setFlapOpen ~= nil and workTool.flapopen then
								workTool:setFlapOpen(false)
							end;
						
							workTool:setIsTurnedOn(true, false);
						end;
					elseif returnToStartPoint and workTool.isTurnedOn then
						if courseplay:is_sowingMachine(workTool) then
							workTool.isTurnedOn = false;
						elseif workTool.setIsTurnedOn ~= nil then
							workTool:setIsTurnedOn(false, false);
						end;
					end;
				end; --END if not isFolding
			end;
		elseif self.cp.turnStage == 0 then
			workSpeed = 0;
			--turn off
			if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn then
				if courseplay:is_sowingMachine(workTool) then
					--do manually instead of :setIsTurnedOn so that workTool.turnOnAnimation and workTool.playAnimation aren't called
					workTool.isTurnedOn = false;
					--[[if workTool.airBlowerSoundEnabled ~= nil then
						workTool.airBlowerSoundEnabled = false;
					end;]]
				else
					workTool:setIsTurnedOn(false, false);

					--Tebbe HS180 (Maurus)
					if workTool.setDoorHigh ~= nil and workTool.doorhigh ~= nil then
						workTool:setDoorHigh(0);
					end;
					if workTool.setFlapOpen ~= nil and workTool.flapopen then
						workTool:setFlapOpen(false)
					end;
				end;
			end;

			--raise
			if not courseplay:isFolding(workTool) then
				if workTool.needsLowering and workTool.aiNeedsLowering and workTool:isLowered() then
					self:setAIImplementsMoveDown(false);
				end;
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

		if not allowedToDrive then
			workTool:setIsTurnedOn(false, false)
		end
	end; --END for i in self.tippers

	return allowedToDrive, workArea, workSpeed
end;
