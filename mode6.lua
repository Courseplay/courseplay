function courseplay:handle_mode6(self, allowedToDrive, workArea, workSpeed, fill_level, last_recordnumber, lx , lz )
	local workTool --= self.tippers[1] -- to do, quick, dirty and unsafe
	local active_tipper = nil

	--[[
	if self.attachedCutters ~= nil then
		for cutter, implement in pairs(self.attachedCutters) do
			AICombine.addCutterTrigger(self, cutter);
		end;
	end;
	--]]

	workArea = (self.recordnumber > self.startWork) and (self.recordnumber < self.stopWork)

	if workArea then
		workSpeed = true
	end
	if (self.recordnumber == self.stopWork or last_recordnumber == self.stopWork )and self.abortWork == nil and not self.loaded then
		allowedToDrive = false
		self.global_info_text = courseplay:get_locale(self, "CPWorkEnd") --'hat Arbeit beendet.'
	end
	
	--calculate total fillLevel for UBT (in case of multiple trailers)
	local hasUBT = false;
	local fillLevelUBT = 0;
	for i=1, table.getn(self.tippers) do
		if courseplay:isUBT(self.tippers[i]) then
			hasUBT = true;
			fillLevelUBT = fillLevelUBT + (self.tippers[i].fillLevel * 100 / self.tippers[i].fillLevelMax);
		end;
	end;
	if hasUBT then 
		fill_level = fillLevelUBT;
	end;
	--END UBT fillLevel


	for i=1, table.getn(self.tippers) do
		workTool = self.tippers[i];
		-- implements, no combine or chopper
		if workTool ~= nil and self.grainTankCapacity == nil then

			-- stop while folding
			if courseplay:isFoldable(workTool) then
				if courseplay:isFolding(workTool) and self.turnStage == 0 then 
					allowedToDrive = false;
					courseplay:debug(workTool.name .. ": isFolding -> allowedToDrive == false", 3);
				end;
				courseplay:debug(string.format("%s: unfold: turnOnFoldDirection=%s, foldMoveDirection=%s", workTool.name, tostring(workTool.turnOnFoldDirection), tostring(workTool.foldMoveDirection)), 3);
			end;

			-- balers
			if courseplay:is_baler(workTool) then
				if self.recordnumber >= self.startWork + 1 and self.recordnumber < self.stopWork then
					-- automatic opening for balers
					if workTool.balerUnloadingState ~= nil then
						if fill_level == 100 and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then

							allowedToDrive = false
							workTool:setIsTurnedOn(false, false);
							if table.getn(workTool.bales) > 0 then
								workTool:setIsUnloadingBale(true, false)
							end
						elseif workTool.balerUnloadingState ~= Baler.UNLOADING_CLOSED then
							allowedToDrive = false
							if workTool.balerUnloadingState == Baler.UNLOADING_OPEN then
								workTool:setIsUnloadingBale(false)
							end
						elseif fill_level >= 0 and not workTool.isTurnedOn and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
							workTool:setIsTurnedOn(true, false);
						end
					end
				end
				
				if last_recordnumber == self.stopWork -1  and workTool.isTurnedOn and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
					workTool:setIsTurnedOn(false, false);
				end
			-- baleloader, copied original code parts				
			elseif courseplay:is_baleLoader(workTool) or courseplay:isUBT(workTool) then
				if not courseplay:isUBT(workTool) then
					if workArea then
						-- automatic stop for baleloader
						if workTool.grabberIsMoving or workTool:getIsAnimationPlaying("rotatePlatform") then
							allowedToDrive = false
						end
						if not workTool.isInWorkPosition and fill_level ~= 100 then
							--g_client:getServerConnection():sendEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_BUTTON_WORK_TRANSPORT));
							workTool.grabberIsMoving = true
							workTool.isInWorkPosition = true
							BaleLoader.moveToWorkPosition(workTool)
						end
					end

					if (fill_level == 100 and self.maxnumber ~= self.stopWork or self.recordnumber == self.stopWork) and workTool.isInWorkPosition and not workTool:getIsAnimationPlaying("rotatePlatform") then
						workTool.grabberIsMoving = true
						workTool.isInWorkPosition = false
						-- move to transport position
						BaleLoader.moveToTransportPosition(workTool)
					end

					if fill_level == 100 and self.maxnumber == self.stopWork then
						allowedToDrive = false
						self.global_info_text = courseplay:get_locale(self, "CPReadyUnloadBale") --'bereit zum entladen'
					end

					-- automatic unload
					if self.Waypoints[last_recordnumber].wait and (self.wait or fill_level == 0) then
						if not courseplay:isUBT(workTool) then
							if workTool.emptyState ~= BaleLoader.EMPTY_NONE then
								if workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_DROP then
									-- BaleLoader.CHANGE_DROP_BALES
									g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_DROP_BALES), true, nil, workTool)
								elseif workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_SINK then
									-- BaleLoader.CHANGE_SINK
									g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_SINK), true, nil, workTool)
								elseif workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_REDO then
									-- BaleLoader.CHANGE_EMPTY_REDO
									g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_EMPTY_REDO), true, nil, workTool);
								end
							else
								--BaleLoader.CHANGE_EMPTY_START
								if BaleLoader.getAllowsStartUnloading(workTool) then
									g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_EMPTY_START), true, nil, workTool)
								end
							end
						end;
					end;				
				
				elseif courseplay:isUBT(workTool) then
					if not workTool.fillLevelMax == workTool.numAttachers[workTool.typeOnTrailer] then
						workTool.fillLevelMax = workTool.numAttachers[workTool.typeOnTrailer];
					end;
					if workTool.capacity == nil or (workTool.capacity ~= nil and workTool.capacity ~= workTool.fillLevelMax) then
						workTool.capacity = workTool.fillLevelMax;
					end;
					
					if workArea then
						if (workTool.fillLevel == workTool.fillLevelMax or (workTool.capacity ~= nil and workTool.fillLevel == workTool.capacity) or fill_level == 100) then
							if self.maxnumber == self.stopWork then
								if workTool.loadingIsActive then
									workTool.loadingIsActive = false;
								end;

								allowedToDrive = false;
								self.global_info_text = "UBT "..courseplay:get_locale(self, "CPReadyUnloadBale"); --'UBT bereit zum entladen'
							end;
							--print("UBT is full (" .. tostring(workTool.fillLevel) .. "/" .. tostring(workTool.fillLevelMax) .. ")"); -- WORKS
						else
							if not workTool.loadingIsActive then
								--print("UBT activating loadingIsActive"); -- WORKS
								workTool.loadingIsActive = true;
							end;
						end;
						
						if not workTool.autoLoad then
							--print("UBT activating autoLoad"); -- WORKS
							workTool.autoLoad = true;
						end;
					else
						if workTool.loadingIsActive then
							workTool.loadingIsActive = false;
						end;

						-- automatic unload
						if self.Waypoints[last_recordnumber].wait and (self.wait or fill_level == 0 or workTool.fillLevel == 0) then
							--call unload function
							for i=1, workTool.numAttachers[workTool.typeOnTrailer] do
								if workTool.attacher[workTool.typeOnTrailer][i].attachedObject ~= nil then

									--ORIG: if workTool.ulRef[workTool.ulMode][1] == g_i18n:getText("UNLOAD_TRAILER") then
									if workTool.ulRef[workTool.ulMode][3] == 0 then --verrrrry dirty: unload on trailer
										local x,y,z = getWorldTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
										local rx,ry,rz = getWorldRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
										local root = getRootNode();
										setRigidBodyType(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,"Dynamic");
										setTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,x,y,z);
										setRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,rx,ry,rz);
										link(root,workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
										workTool.attacher[workTool.typeOnTrailer][i].attachedObject = nil;
										workTool.fillLevel = workTool.fillLevel - 1;
									else
										local x,y,z = getWorldTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
										local rx,ry,rz = getWorldRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
										local nx,ny,nz = getWorldTranslation(workTool.attacherLevel[workTool.typeOnTrailer]);
										local tx,ty,tz = getWorldTranslation(workTool.ulRef[workTool.ulMode][3]);
										local x = x + (tx - nx);
										local y = y + (ty - ny);
										local z = z + (tz - nz);
										local tH = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z);
										local relHeight = ny - tH;
										local root = getRootNode();
										setRigidBodyType(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,"Dynamic");
										setTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,x,(y - relHeight),z);
										setRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,rx,ry,rz);
										link(root,workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
										workTool.attacher[workTool.typeOnTrailer][i].attachedObject = nil;
										workTool.fillLevel = workTool.fillLevel - 1;
									end;
								end;
							end;
						end;				
					
					end;
				end;
			--END baleloader	


			-- other worktools, tippers, e.g. forage wagon	
			else
				if workArea and fill_level ~= 100 and ((self.abortWork == nil) or (self.abortWork ~= nil and last_recordnumber == self.abortWork) or (self.runOnceStartCourse)) and self.turnStage == 0  then
					if allowedToDrive then
						--unfold
						local recordnumber = math.min(self.recordnumber+2 ,self.maxnumber)
						local forecast = Utils.getNoNil(self.Waypoints[recordnumber].ridgeMarker,0)
						local marker = Utils.getNoNil(self.Waypoints[self.recordnumber].ridgeMarker,0)
						local waypoint = math.max(marker,forecast)
						if courseplay:isFoldable(workTool) and not courseplay:isFolding(workTool) then
							if not SpecializationUtil.hasSpecialization(Plough, workTool.specializations) then
								workTool:setFoldDirection(-1);
								self.runOnceStartCourse = false; 
							elseif waypoint == 2 and self.runOnceStartCourse then --wegpunkte finden und richtung setzen...
								workTool:setFoldDirection(-1);
								if workTool:getIsPloughRotationAllowed() then
									AITractor.aiRotateLeft(self);
									self.runOnceStartCourse = false;
								end
							elseif self.runOnceStartCourse then
								workTool:setFoldDirection(-1);
								self.runOnceStartCourse = false; 
							end
						end;

						if not courseplay:isFolding(workTool) then
							--lower
							if workTool.needsLowering and workTool.aiNeedsLowering then
								self:setAIImplementsMoveDown(true);
							end;
						
							--turn on
							if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn then
								workTool:setIsTurnedOn(true, false);
							end;
							if workTool.setIsPickupDown ~= nil then
								if self.pickup.isDown == nil or (self.pickup.isDown ~= nil and not self.pickup.isDown) then
									workTool:setIsPickupDown(true, false);
								end;
							end;
						end;
					end
				elseif not workArea or self.abortWork ~= nil or self.loaded or last_recordnumber == self.stopWork then
					workSpeed = false
					
					if not courseplay:isFolding(workTool) then
						--turn off
						if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn then
							workTool:setIsTurnedOn(false, false);
						end;
						if workTool.setIsPickupDown ~= nil then
							if self.pickup.isDown == nil or (self.pickup.isDown ~= nil and self.pickup.isDown) then
								workTool:setIsPickupDown(false, false);
							end;
						end;

						--raise
						if workTool.needsLowering and workTool.aiNeedsLowering and self.turnStage == 0 then
							self:setAIImplementsMoveDown(false);
						end;
					end;

					--fold
					if courseplay:isFoldable(workTool) then
						workTool:setFoldDirection(1);
						--workTool:setFoldDirection(-workTool.turnOnFoldDirection);
					end;
				end;

				-- done tipping
				local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()

				if tipper_fill_level ~= nil and tipper_capacity ~= nil then
					if self.unloading_tipper ~= nil and self.unloading_tipper.fillLevel == 0 then
						self.unloading_tipper = nil

						if tipper_fill_level == 0 then
							self.unloaded = true
							self.max_speed_level = 3
							self.currentTipTrigger = nil
						end
					end

					-- damn, i missed the trigger!
					if self.currentTipTrigger ~= nil then
						local trigger_id = self.currentTipTrigger.triggerId

						if self.currentTipTrigger.specialTriggerId ~= nil then
							trigger_id = self.currentTipTrigger.specialTriggerId
						end

						local trigger_x, trigger_y, trigger_z = getWorldTranslation(trigger_id)
						local ctx, cty, ctz = getWorldTranslation(self.rootNode);
						local distance_to_trigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z)
						if distance_to_trigger > 60 then
							self.currentTipTrigger = nil
						end
					end

					-- tipper is not empty and tractor reaches TipTrigger
					if tipper_fill_level > 0 and self.currentTipTrigger ~= nil and self.recordnumber > 3 then
						self.max_speed_level = 1
						allowedToDrive, active_tipper = courseplay:unload_tippers(self)
						self.info_text = courseplay:get_locale(self, "CPTriggerReached") -- "Abladestelle erreicht"		
					end
				end;
			end; --END other tools

			-- Begin Work   or goto abortWork
			if last_recordnumber == self.startWork and fill_level ~= 100 then
				if self.abortWork ~= nil then
					if self.abortWork < 5 then
						self.abortWork = 6
					end
					self.recordnumber = self.abortWork 
					if self.recordnumber < 2 then
						self.recordnumber = 2
					end
				end
			end
			-- last point reached restart
			if self.abortWork ~= nil then
				if (last_recordnumber == self.abortWork ) and fill_level ~= 100 then
					self.recordnumber = self.abortWork + 2  -- drive to waypoint after next waypoint
					self.abortWork = nil
				end
			end
			-- safe last point
			if (fill_level == 100 or self.loaded) and workArea and self.abortWork == nil and self.maxnumber ~= self.stopWork then
				self.abortWork = last_recordnumber - 10
				self.recordnumber = self.stopWork - 4
				if self.recordnumber < 1 then
					self.recordnumber = 1
				end
				--	courseplay:debug(string.format("Abort: %d StopWork: %d",self.abortWork,self.stopWork), 2)
			end;
			
		else  --COMBINES
		
			--TODO: move combine out of for loop, it never has more than one workTool
			if SpecializationUtil.hasSpecialization(Combine, self.specializations) or SpecializationUtil.hasSpecialization(combine, self.specializations) or self.grainTankCapacity == 0 then --TODO: create isCombine(bla) call
				if workArea and not self.isAIThreshing then
					local pipeState = self:getCombineTrailerInRangePipeState();
					if self.grainTankCapacity == 0 then
						if courseplay:isFoldable(workTool) then
							workTool:setFoldDirection(-1);
						end;
						self:setIsThreshing(true, true);
						if pipeState > 0 then
							self:setPipeState(pipeState);
						else
							self:setPipeState(2);
						end;
						if self.lastCuttersFruitType == 9 and not self.pipeParticleSystems[9].isEmitting and self.turnStage == 0 then
							self.waitingForTrailerToUnload = true
						end
						if self.waitingForTrailerToUnload then
							allowedToDrive = false;
							if self.pipeParticleSystems[9].isEmitting or pipeState > 0 then
								self.waitingForTrailerToUnload = false
							end
						end
					else
						if self.grainTankFillLevel < self.grainTankCapacity and not self.waitingForDischarge and not self.isThreshing then
							self:setIsThreshing(true, true);
						end
						if self.grainTankFillLevel >= self.grainTankCapacity or self.waitingForDischarge then
							self.waitingForDischarge = true
							allowedToDrive = false;
							self:setIsThreshing(false, true);
						end
						if self.isCheckedIn == nil and self.grainTankFillLevel < self.grainTankCapacity then
							self.waitingForDischarge = false
							self.waitingForTrailerToUnload = false
						end
						if self.grainTankFillLevel >= self.grainTankCapacity*0.8  or pipeState > 0 then
							self:setPipeState(2)
						elseif  pipeState == 0 then 
							self:setPipeState(1)
						end
						if self.waitingForTrailerToUnload then
							allowedToDrive = false;
						end
					end
				elseif self.recordnumber == self.stopWork then
					self:setIsThreshing(false, true);
					allowedToDrive = false;
				end
				local dx,_,dz = localDirectionToWorld(self.aiTreshingDirectionNode, 0, 0, 1);
				local length = Utils.vector2Length(dx,dz);
				if self.turnStage == 0 then
					self.aiThreshingDirectionX = dx/length;
					self.aiThreshingDirectionZ = dz/length;
				else
					self.aiThreshingDirectionX = -(dx/length);
					self.aiThreshingDirectionZ = -(dz/length);
				end				
			end;
		end
	end; --END for i in self.tippers
	
	return allowedToDrive, workArea, workSpeed, active_tipper
end