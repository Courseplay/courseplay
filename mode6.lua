
function courseplay:handle_mode6(self, allowedToDrive, workArea, workSpeed, fill_level, last_recordnumber)
	local workTool = self.tippers[1] -- to do, quick, dirty and unsafe
	local active_tipper  = nil
if self.attachedCutters ~= nil then
	for cutter,implement in pairs(self.attachedCutters) do
                   AICombine.addCutterTrigger(self, cutter);
               end;
			   end
	workArea = (self.recordnumber > self.startWork) and (self.recordnumber < self.stopWork)
	
	if workArea then
		workSpeed = true
	end
	if self.recordnumber >= self.stopWork and self.abortWork == nil and not self.loaded then
		allowedToDrive = false
		self.global_info_text = courseplay:get_locale(self, "CPWorkEnd") --'hat Arbeit beendet.'
	end
	
	
	-- worktool defined above
	if workTool ~= nil then
		-- balers
		if courseplay:is_baler(workTool) then
			if self.recordnumber >= self.startWork then
				-- automatic opening for balers
				if workTool.balerUnloadingState ~= nil then
					if fill_level == 100 and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then

						allowedToDrive = false
						workTool:setIsTurnedOn(false, false);					
						if table.getn(workTool.bales) > 0 then
							workTool:setIsUnloadingBale(true,false)
						end
					elseif workTool.balerUnloadingState ~= Baler.UNLOADING_CLOSED then
						allowedToDrive = false
						if workTool.balerUnloadingState == Baler.UNLOADING_OPEN then
								workTool:setIsUnloadingBale(false)
						end
					elseif fill_level == 0 and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
						workTool:setIsTurnedOn(true, false);
					end
				end
			end
		else
			-- baleloader, copied original code parts				
			if SpecializationUtil.hasSpecialization(BaleLoader, workTool.specializations) then
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
				end
								
			else
			
				-- other worktools, tippers, e.g. forage wagon	
				-- start/stop worktool
				if workArea and fill_level ~= 100 and (self.abortWork == nil and last_recordnumber == self.startWork or self.abortWork ~= nil and last_recordnumber == self.abortWork - 2) then
					--workSpeed = true
					if allowedToDrive then
						if workTool.setIsTurnedOn ~= nil then
							workTool:setIsTurnedOn(true,false)
							if workTool.setIsPickupDown ~= nil then
								workTool:setIsPickupDown(true, false)
							end
						elseif workTool.isTurnedOn ~= nil and workTool.pickupDown ~= nil then
							-- Krone ZX - planet-ls.de
							workTool.isTurnedOn = true
							workTool.pickupDown = true
							workTool:updateSendEvent()
						end
					end
				elseif not workArea or fill_level == 100 or self.abortWork ~= nil or last_recordnumber == self.stopWork then
					workSpeed = false
					if workTool.setIsTurnedOn ~= nil then
						workTool:setIsTurnedOn(false, false)	
						if workTool.setIsPickupDown ~= nil then
							workTool:setIsPickupDown(false, false)
						end		
					elseif workTool.isTurnedOn ~= nil and workTool.pickupDown ~= nil then
						-- Krone ZX - planet-ls.de
						workTool.isTurnedOn = false
						workTool.pickupDown = false
						workTool:updateSendEvent()
					end
				end
				-- done tipping
				local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
				if self.unloading_tipper ~= nil and self.unloading_tipper.fillLevel == 0 then			
					if self.unloading_tipper.tipState ~=  Trailer.TIPSTATE_CLOSED then	
					  print("toggle tip state")
					  self.unloading_tipper:toggleTipState(self.currentTipTrigger,1)		  
					end       
					
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
					local ctx,cty,ctz = getWorldTranslation(self.rootNode);
					local distance_to_trigger = courseplay:distance(ctx ,ctz ,trigger_x ,trigger_z)		
					if distance_to_trigger > 60 then
						self.currentTipTrigger = nil
					end
				end

				-- tipper is not empty and tractor reaches TipTrigger
				if tipper_fill_level > 0 and self.currentTipTrigger ~= nil and self.recordnumber > 3  then		
					self.max_speed_level = 1
					allowedToDrive, active_tipper = courseplay:unload_tippers(self)
					self.info_text = courseplay:get_locale(self, "CPTriggerReached") -- "Abladestelle erreicht"		
				end
				-- Beginn Work
	if last_recordnumber == self.startWork and fill_level ~= 100 then
		if self.abortWork ~= nil then
			self.recordnumber = self.abortWork - 4
			if self.recordnumber < 1 then
				self.recordnumber = 1
			end
		end
	end
	-- last point reached restart
	if self.abortWork ~= nil then
		if (last_recordnumber == self.abortWork - 4) and fill_level ~= 100 then
			self.recordnumber = self.abortWork - 2 -- drive to waypoint after next waypoint
			self.abortWork = nil					
		end
	end
	-- safe last point
	if (fill_level == 100 or self.loaded) and workArea and self.abortWork == nil and self.maxnumber ~= self.stopWork then
		self.abortWork = self.recordnumber
		self.recordnumber = self.stopWork - 4
		if self.recordnumber < 1 then
			self.recordnumber = 1
		end
	--	print(string.format("Abort: %d StopWork: %d",self.abortWork,self.stopWork))
	end
			end		
		end
	else
		if SpecializationUtil.hasSpecialization(Combine, self.specializations) then
			if self.grainTankCapacity == 0 and ((self.pipeParticleActivated and not self.isPipeUnloading) or not self.pipeStateIsUnloading[self.currentPipeState]) then
				-- there is some fruit to unload, but there is no trailer. Stop and wait for a trailer
				self.waitingForTrailerToUnload = true;
			end;
			if self.waitingForTrailerToUnload then
				if self.lastValidOutputFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
					local trailer = self:findTrailerToUnload(self.lastValidOutputFruitType);
					if trailer ~= nil then
					-- there is a trailer to unload. Continue working
						self.waitingForTrailerToUnload = false;
					end;
				else
					-- we did not cut anything yet. We shouldn't have ended in this state. Just continue working
					self.waitingForTrailerToUnload = false;
				end;
			end;

			if (self.grainTankFillLevel >= self.grainTankCapacity and self.grainTankCapacity > 0) or self.waitingForTrailerToUnload or self.waitingForDischarge  then
				allowedToDrive = false;
			end;
		end;
	end
	return allowedToDrive, workArea, workSpeed, active_tipper
end