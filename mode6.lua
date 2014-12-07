function courseplay:handle_mode6(self, allowedToDrive, workSpeed, fillLevelPct, lx , lz, refSpeed )
	local workTool;
	local activeTipper = nil
	local specialTool = false
	local forceSpeedLimit = refSpeed 
	--[[
	if self.attachedCutters ~= nil then
		for cutter, implement in pairs(self.attachedCutters) do
			AICombine.addCutterTrigger(self, cutter);
		end;
	end;
	--]]
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
			courseplay:setRecordNumber(self, math.min(self.cp.finishWork + 1,self.maxnumber));
		end;
	end;
	if fieldArea then
		workSpeed = 1;
	end
	if (self.recordnumber == self.cp.stopWork or self.cp.lastRecordnumber == self.cp.stopWork) and self.cp.abortWork == nil and not self.cp.isLoaded and not isFinishingWork and self.cp.wait then
		allowedToDrive = false
		CpManager:setGlobalInfoText(self, 'WORK_END');
		hasFinishedWork = true
	end

	-- Wait until we have fully started up Threshing
	if self.sampleThreshingStart and isSamplePlaying(self.sampleThreshingStart.sample) then
		-- Only allow us to drive if we are moving backwards.
		if not self.cp.isReverseBackToPoint then
			allowedToDrive = false;
		end;
		courseplay:setInfoText(self, string.format(courseplay:loc("COURSEPLAY_STARTING_UP_TOOL"), tostring(self.name)));
	end;

	local selfIsFolding, selfIsFolded, selfIsUnfolded = courseplay:isFolding(self);
	for i=1, #(self.cp.workTools) do
		workTool = self.cp.workTools[i];
		local tool = self
		if courseplay:isAttachedCombine(workTool) then
			tool = workTool
		end

		local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool);
		local needsLowering = false
		
		if workTool.attacherJoint ~= nil then
			needsLowering = workTool.attacherJoint.needsLowering
		end
		
		--speedlimits														--	TODO (Tom) workTool:doCheckSpeedLimit() is not working for harvesters			
		if (workTool.doCheckSpeedLimit and workTool:doCheckSpeedLimit()) or workTool.cp.isGrimmeMaxtron620 or workTool.cp.isGrimmeTectron415 then
			forceSpeedLimit = math.min(forceSpeedLimit, workTool.speedLimit)
		end
		
		-- stop while folding
		if (isFolding or selfIsFolding) and self.cp.turnStage == 0 then
			allowedToDrive = courseplay:brakeToStop(self);
			--courseplay:debug(tostring(workTool.name) .. ": isFolding -> allowedToDrive == false", 6);
		end;

		-- implements, no combine or chopper
		if workTool ~= nil and tool.attachedCutters == nil then
			-- balers
			if courseplay:isBaler(workTool) then
				if self.recordnumber >= self.cp.startWork + 1 and self.recordnumber < self.cp.stopWork and self.cp.turnStage == 0 then
																			--  self, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload, ridgeMarker)
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self, workTool, true,   true,  true,   allowedToDrive, nil,   nil);
					if not specialTool then
						-- automatic opening for balers
						if workTool.balerUnloadingState ~= nil then
							fillLevelPct = courseplay:round(fillLevelPct, 3);
							local capacity = courseplay:round(100 * (workTool.realBalerOverFillingRatio or 1), 3);

							if courseplay:isRoundbaler(workTool) and fillLevelPct > capacity * 0.9 and fillLevelPct < capacity and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
								if not workTool.isTurnedOn then
									workTool:setIsTurnedOn(true, false);
								end;
								workSpeed = 0.5;
							elseif fillLevelPct >= capacity and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
								allowedToDrive = false;
								if #(workTool.bales) > 0 then
									workTool:setIsUnloadingBale(true, false)
								end
							elseif workTool.balerUnloadingState ~= Baler.UNLOADING_CLOSED then
								allowedToDrive = false
								if workTool.balerUnloadingState == Baler.UNLOADING_OPEN then
									workTool:setIsUnloadingBale(false)
								end
							elseif fillLevelPct >= 0 and not workTool.isTurnedOn and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
								workTool:setIsTurnedOn(true, false);
							end
						end
						if workTool.setPickupState ~= nil then
							if workTool.isPickupLowered ~= nil and not workTool.isPickupLowered then
								workTool:setPickupState(true, false);
								courseplay:debug(string.format('%s: lower pickup order', nameNum(workTool)), 17);
							end;
						end;
					end
				end

				if self.cp.lastRecordnumber == self.cp.stopWork -1 and workTool.isTurnedOn then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,nil)
					if not specialTool and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
						workTool:setIsTurnedOn(false, false);
						if workTool.setPickupState ~= nil then
							if workTool.isPickupLowered ~= nil and workTool.isPickupLowered then
								workTool:setPickupState(false, false);
								courseplay:debug(string.format('%s: raise pickup order', nameNum(workTool)), 17);
							end;
						end;
					end
				end

			-- baleloader, copied original code parts
			elseif courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) then
				if workArea and fillLevelPct ~= 100 then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,true,true,true,allowedToDrive,nil,nil);
					if not specialTool then
						-- automatic stop for baleloader
						if workTool.grabberIsMoving then
							allowedToDrive = false;
						end;
						if not workTool.isInWorkPosition and fillLevelPct ~= 100 then
							workTool.grabberIsMoving = true
							workTool.isInWorkPosition = true
							BaleLoader.moveToWorkPosition(workTool)
							-- workTool:doStateChange(BaleLoader.CHANGE_MOVE_TO_WORK);
						end
					end;
				end

				if (fillLevelPct == 100 and self.cp.hasUnloadingRefillingCourse or self.recordnumber == self.cp.stopWork) and workTool.isInWorkPosition and not workTool:getIsAnimationPlaying('rotatePlatform') and not workTool:getIsAnimationPlaying('emptyRotate') then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,nil);
					if not specialTool then
						workTool.grabberIsMoving = true
						workTool.isInWorkPosition = false
						BaleLoader.moveToTransportPosition(workTool)
						-- workTool:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT);
					end;
				end

				if fillLevelPct == 100 and not self.cp.hasUnloadingRefillingCourse then
					if self.cp.automaticUnloadingOnField then
						self.cp.unloadOrder = true
						CpManager:setGlobalInfoText(self, 'UNLOADING_BALE');
					else
						specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,nil); --TODO: unclear
					end
				end;

				-- stop when unloading
				if workTool.activeAnimations and (workTool:getIsAnimationPlaying('rotatePlatform') --[[or workTool:getIsAnimationPlaying('emptyRotate')]]) then
					allowedToDrive = false;
				end;

				-- automatic unload
				if (not workArea and self.Waypoints[self.cp.lastRecordnumber].wait and (self.cp.wait or fillLevelPct == 0)) or self.cp.unloadOrder then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,true);
					if not specialTool then
						if workTool.emptyState ~= BaleLoader.EMPTY_NONE then
							if workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_DROP then
								-- BaleLoader.CHANGE_DROP_BALES
								g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_DROP_BALES), true, nil, workTool)
							elseif workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_SINK then
								-- BaleLoader.CHANGE_SINK
								g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_SINK), true, nil, workTool)

								-- Change the direction to forward if we were reversing.
								if self.Waypoints[self.recordnumber].rev then
									courseplay:setRecordNumber(self, courseplay:getNextFwdPoint(self));
								end;
							elseif workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_REDO then
								-- BaleLoader.CHANGE_EMPTY_REDO
								g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_EMPTY_REDO), true, nil, workTool);
							end
						else
							--BaleLoader.CHANGE_EMPTY_START
							if BaleLoader.getAllowsStartUnloading(workTool) then
								g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_EMPTY_START), true, nil, workTool)
							end
							self.cp.unloadOrder = false;
						end
					end;
				end;
			--END baleloader


			-- other worktools, tippers, e.g. forage wagon
			else
				if workArea and fillLevelPct ~= 100 and ((self.cp.abortWork == nil) or (self.cp.abortWork ~= nil and self.cp.lastRecordnumber == self.cp.abortWork) or (self.cp.runOnceStartCourse)) and self.cp.turnStage == 0  then
								--courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,true,true,true,allowedToDrive,nil,nil)
					if allowedToDrive then
						if not specialTool then
							--unfold
							local recordnumber = math.min(self.recordnumber + 2, self.maxnumber);
							local forecast = Utils.getNoNil(self.Waypoints[recordnumber].ridgeMarker,0)
							local marker = Utils.getNoNil(self.Waypoints[self.recordnumber].ridgeMarker,0)
							local waypoint = math.max(marker,forecast)
							if courseplay:isFoldable(workTool) and not isFolding and not isUnfolded then
								if not workTool.cp.hasSpecializationPlough then
									courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
									workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
									self.cp.runOnceStartCourse = false;
								elseif waypoint == 2 and self.cp.runOnceStartCourse then --wegpunkte finden und richtung setzen...
									courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
									workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
									if workTool:getIsPloughRotationAllowed() then
										AITractor.aiRotateLeft(self);
										self.cp.runOnceStartCourse = false;
									end
								elseif self.cp.runOnceStartCourse then
									courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
									workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
									self.cp.runOnceStartCourse = false;
								end
							end;


							if not isFolding and isUnfolded and not waitForSpecialTool then --TODO: where does "waitForSpecialTool" come from? what does it do?
								--lower
								if needsLowering and workTool.aiNeedsLowering then
									self:setAIImplementsMoveDown(true);
									courseplay:debug(string.format('%s: lower order', nameNum(workTool)), 17);
								end;

								--turn on
								if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn then
									workTool:setIsTurnedOn(true, false);
									courseplay:debug(string.format('%s: turn on order', nameNum(workTool)), 17);
									self.cp.runOnceStartCourse = false
									courseplay:setMarkers(self, workTool);
								end;

								if workTool.setPickupState ~= nil then
									if workTool.isPickupLowered ~= nil and not workTool.isPickupLowered then
										workTool:setPickupState(true, false);
										courseplay:debug(string.format('%s: lower pickup order', nameNum(workTool)), 17);
									end;
								end;
							end;
						end;
					end
				elseif not workArea or self.cp.abortWork ~= nil or self.cp.isLoaded or self.cp.lastRecordnumber == self.cp.stopWork then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil,nil)
					if not specialTool then
						if not isFolding then
							--turn off
							if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn then
								workTool:setIsTurnedOn(false, false);
								courseplay:debug(string.format('%s: turn off order', nameNum(workTool)), 17);
							end;
							if workTool.setPickupState ~= nil then
								if workTool.isPickupLowered ~= nil and workTool.isPickupLowered then
									workTool:setPickupState(false, false);
									courseplay:debug(string.format('%s: raise pickup order', nameNum(workTool)), 17);
								end;
							end;

							--raise
							if needsLowering and workTool.aiNeedsLowering and self.cp.turnStage == 0 then
								self:setAIImplementsMoveDown(false);
								courseplay:debug(string.format('%s: raise order', nameNum(workTool)), 17);
							end;
						end;

						--fold
						if courseplay:isFoldable(workTool) and not isFolding and not isFolded then
							courseplay:debug(string.format('%s: fold order (foldDir=%d)', nameNum(workTool), -workTool.cp.realUnfoldDirection), 17);
							workTool:setFoldDirection(-workTool.cp.realUnfoldDirection);
							--workTool:setFoldDirection(-workTool.turnOnFoldDirection);
						end;
					end;
				end;

				-- done tipping
				if self.cp.tipperFillLevel ~= nil and self.cp.tipperCapacity ~= nil then
					if self.cp.currentTipTrigger and self.cp.tipperFillLevel == 0 then
						courseplay:resetTipTrigger(self, true);
					end

					-- damn, i missed the trigger!
					if self.cp.currentTipTrigger ~= nil then
						local trigger = self.cp.currentTipTrigger
						local triggerId = trigger.triggerId
						if trigger.isPlaceableHeapTrigger then
							triggerId = trigger.rootNode;
						end;

						if trigger.specialTriggerId ~= nil then
							triggerId = trigger.specialTriggerId
						end
						local trigger_x, trigger_y, trigger_z = getWorldTranslation(triggerId);
						local ctx, cty, ctz = getWorldTranslation(self.cp.DirectionNode);

						-- Start reversion value is to check if we have started to reverse
						-- This is used in case we already registered a tipTrigger but changed the direction and might not be in that tipTrigger when unloading. (Bug Fix)
						local startReversing = self.Waypoints[self.recordnumber].rev and not self.Waypoints[self.cp.lastRecordnumber].rev;
						if startReversing then
							courseplay:debug(string.format("%s: Is starting to reverse. Tip trigger is reset.", nameNum(self)), 13);
						end;

						local extraLength = 5;
						if trigger.bunkerSilo ~= nil and trigger.bunkerSilo.movingPlanes ~= nil and self.cp.handleAsOneSilo ~= true then
							-- We are a bunkerSilo, so we need to add more extraLength to the totalLength.
							extraLength = 55;
						end;

						if courseplay:distance(ctx, ctz, trigger_x, trigger_z) > (self.cp.totalLength + extraLength) or startReversing then
							courseplay:resetTipTrigger(self);
						end
					end

					-- tipper is not empty and tractor reaches TipTrigger
					if self.cp.tipperFillLevel > 0 and self.cp.currentTipTrigger ~= nil and self.recordnumber > 3 then
						allowedToDrive, activeTipper = courseplay:unload_tippers(self, allowedToDrive);
						courseplay:setInfoText(self, courseplay:loc("COURSEPLAY_TIPTRIGGER_REACHED"));
					end
				end;
			end; --END other tools

			-- Begin work or go to abortWork
			if self.cp.lastRecordnumber == self.cp.startWork and fillLevelPct ~= 100 then
				if self.cp.abortWork ~= nil then
					if self.cp.abortWork < 5 then
						self.cp.abortWork = 6
					end
					courseplay:setRecordNumber(self, self.cp.abortWork);
					if self.recordnumber < 2 then
						courseplay:setRecordNumber(self, 2);
					end
					if self.Waypoints[self.recordnumber].turn ~= nil or self.Waypoints[self.recordnumber+1].turn ~= nil  then
						courseplay:setRecordNumber(self, self.recordnumber - 2);
					end
				end
			end
			-- last point reached restart
			if self.cp.abortWork ~= nil then
				if (self.cp.lastRecordnumber == self.cp.abortWork ) and fillLevelPct ~= 100 then
					courseplay:setRecordNumber(self, self.cp.abortWork + 2); -- drive to waypoint after next waypoint
					self.cp.abortWork = nil
				end
			end
			-- safe last point
			if (fillLevelPct == 100 or self.cp.isLoaded) and workArea and not courseplay:isBaler(workTool) then
				if self.cp.hasUnloadingRefillingCourse and self.cp.abortWork == nil then
					self.cp.abortWork = self.cp.lastRecordnumber - 10;
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
					if self.recordnumber < 1 then
						courseplay:setRecordNumber(self, 1);
					end
					--courseplay:debug(string.format("Abort: %d StopWork: %d",self.cp.abortWork,self.cp.stopWork), 12)
				elseif not self.cp.hasUnloadingRefillingCourse and not self.cp.automaticUnloadingOnField then
					allowedToDrive = false;
					CpManager:setGlobalInfoText(self, 'NEEDS_UNLOADING');
				elseif not self.cp.hasUnloadingRefillingCourse and self.cp.automaticUnloadingOnField then
					allowedToDrive = false;
				end;
			end;

		--COMBINES
		elseif workTool.cp.hasSpecializationCutter then

			--Start combine
			local isTurnedOn = tool:getIsTurnedOn();
			local pipeState = 0;
			if tool.getOverloadingTrailerInRangePipeState ~= nil then
				pipeState = tool:getOverloadingTrailerInRangePipeState();
			end;
			if workArea and not tool.isAIThreshing and self.cp.abortWork == nil and self.cp.turnStage == 0 then
				specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,true,true,true,allowedToDrive,nil,nil)
				if not specialTool then
					local weatherStop = not tool:getIsThreshingAllowed(true)

					-- Choppers
					if tool.capacity == 0 then
						if courseplay:isFoldable(workTool) and not isTurnedOn and not isFolding and not isUnfolded then
							courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
							workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
						end;
						if not isFolding and isUnfolded and not isTurnedOn then
							courseplay:debug(string.format('%s: Start Treshing', nameNum(tool)), 12);
							tool:setIsTurnedOn(true);
							if pipeState > 0 then
								tool:setPipeState(pipeState);
							else
								tool:setPipeState(2);
							end;
						end

						-- stop when there's no trailer to fill - courtesy of upsidedown
						local chopperWaitForTrailer = false;
						if tool.cp.isChopper and tool.lastValidFillType ~= FruitUtil.FRUITTYPE_UNKNOWN then
							local targetTrailer = tool:findAutoAimTrailerToUnload(tool.lastValidFillType);
							local trailer, trailerDistance = tool:findTrailerToUnload(tool.lastValidFillType);
							--print(string.format('targetTrailer=%s, trailer=%s', tostring(targetTrailer), tostring(trailer)));
							if targetTrailer == nil or trailer == nil then
								chopperWaitForTrailer = true;
								--print(string.format('\tat least one of them not found at pipeState %s -> chopperWaitForTrailer=true', tostring(pipeState)));
							end;
						end;

						if (pipeState == 0 and self.cp.turnStage == 0) or chopperWaitForTrailer then
							tool.cp.waitingForTrailerToUnload = true;
						end;

					-- Combines
					else
						local tankFillLevelPct = tool.fillLevel * 100 / tool.capacity;

						-- WorkTool Unfolding.
						if courseplay:isFoldable(workTool) and not isTurnedOn and not isFolding and not isUnfolded then
							courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
							workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
						end;

						-- Combine Unfolding
						if courseplay:isFoldable(tool) then
							if not selfIsFolding and not selfIsUnfolded then
								courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(tool), tool.cp.realUnfoldDirection), 17);
								tool:setFoldDirection(tool.cp.realUnfoldDirection);
							end;
						end;

						if not isFolding and isUnfolded and not selfIsFolding and selfIsUnfolded and tankFillLevelPct < 100 and not tool.waitingForDischarge and not isTurnedOn and not weatherStop then
							tool:setIsTurnedOn(true);
						end
						if tool.pipeIsUnloading and (tool.courseplayers == nil or tool.courseplayers[1] == nil) and tool.cp.stopWhenUnloading and tankFillLevelPct >= 1 then
							tool.stopForManualUnloader = true
						end
							
						if tankFillLevelPct >= 100 or tool.waitingForDischarge or (tool.cp.stopWhenUnloading and tool.pipeIsUnloading and tool.courseplayers and tool.courseplayers[1] ~= nil) or tool.stopForManualUnloader then
							tool.waitingForDischarge = true;
							allowedToDrive = courseplay:brakeToStop(self); -- allowedToDrive = false;
							if isTurnedOn then
								tool:setIsTurnedOn(false);
							end;
							if tankFillLevelPct < 80 and (not tool.cp.stopWhenUnloading or (tool.cp.stopWhenUnloading and (tool.courseplayers == nil or tool.courseplayers[1] == nil))) then
								courseplay:setReverseBackDistance(self, 2);
								tool.waitingForDischarge = false;
								if not weatherStop and not isTurnedOn then
									tool:setIsTurnedOn(true);
								end;
							end;
							if tool.stopForManualUnloader and tool.fillLevel == 0 then
								tool.stopForManualUnloader = false
							end
						end;

						if weatherStop then
							allowedToDrive = false;
							if isTurnedOn then
								tool:setIsTurnedOn(false);
							end;
							CpManager:setGlobalInfoText(self, 'WEATHER');
						end

					end

					-- Make sure we are lowered when working the field.
					if allowedToDrive and isTurnedOn and not workTool:isLowered() and not self.cp.isReverseBackToPoint then
						courseplay:lowerImplements(self, true, false);
					end;

					-- If we are moving a bit back, don't lower the tool before we move forward again.
					if isTurnedOn and workTool:isLowered() and self.cp.isReverseBackToPoint then
						courseplay:lowerImplements(self, false, false);
					end;
				end
			 --Stop combine
			elseif self.recordnumber == self.cp.stopWork or self.cp.abortWork ~= nil then
				local isEmpty = tool.fillLevel == 0
				if self.cp.abortWork == nil and self.cp.wait then
					allowedToDrive = false;
				end
				if isEmpty then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,false,false,false,allowedToDrive,nil)
				else
					specialTool, allowedToDrive = courseplay:handleSpecialTools(self,workTool,true,false,false,allowedToDrive,nil)
				end
				if not specialTool then
					tool:setIsTurnedOn(false);
					if courseplay:isFoldable(workTool) and isEmpty and not isFolding and not isFolded then
						courseplay:debug(string.format('%s: fold order (foldDir=%d)', nameNum(workTool), -workTool.cp.realUnfoldDirection), 17);
						workTool:setFoldDirection(-workTool.cp.realUnfoldDirection);
					end;
					if courseplay:isFoldable(tool) and isEmpty and not isFolding and not isFolded then
						courseplay:debug(string.format('%s: fold order (foldDir=%d)', nameNum(tool), -tool.cp.realUnfoldDirection), 17);
						tool:setFoldDirection(-tool.cp.realUnfoldDirection);
					end;
					tool:setPipeState(1)
				end
			end

			if tool.cp.isCombine and isTurnedOn and tool.fillLevel >= tool.capacity*0.8  or ((pipeState > 0 or courseplay:isAttachedCombine(workTool))and not courseplay:isSpecialChopper(workTool))then
				tool:setPipeState(2)
				if tool.setOverloadingActive  and tool.getIsPipeUnloadingAllowed then
					if tool:getIsPipeUnloadingAllowed() then
						tool:setOverloadingActive(true);
					end
				end
			elseif  pipeState == 0 and tool.cp.isCombine and tool.fillLevel < tool.capacity then
				tool:setPipeState(1)
			end
			if tool.cp.waitingForTrailerToUnload then
				local mayIDrive = false;
				if tool.cp.isCombine or courseplay:isAttachedCombine(workTool) then
					if tool.cp.isCheckedIn == nil or (pipeState == 0 and tool.fillLevel == 0) then
						tool.cp.waitingForTrailerToUnload = false
					end
				elseif tool.cp.isChopper then
					-- resume driving
					local ch, gr = Fillable.FILLTYPE_CHAFF, Fillable.FILLTYPE_GRASS_WINDROW;
					if (tool.pipeParticleSystems and ((tool.pipeParticleSystems[ch] and tool.pipeParticleSystems[ch].isEmitting) or (tool.pipeParticleSystems[gr] and tool.pipeParticleSystems[gr].isEmitting))) or pipeState > 0 then
						if tool.lastValidFillType ~= FruitUtil.FRUITTYPE_UNKNOWN then
							local targetTrailer = tool:findAutoAimTrailerToUnload(tool.lastValidFillType);
							local trailer, trailerDistance = tool:findTrailerToUnload(tool.lastValidFillType);
							if targetTrailer ~= nil and trailer ~= nil and targetTrailer == trailer then
								tool.cp.waitingForTrailerToUnload = false;
							end;
						else
							mayIDrive = allowedToDrive;
						end;
					end
				end
				allowedToDrive = mayIDrive;
			end

			local dx,_,dz = localDirectionToWorld(self.cp.DirectionNode, 0, 0, 1);
			local length = Utils.vector2Length(dx,dz);
			if self.cp.turnStage == 0 then
				self.aiThreshingDirectionX = dx/length;
				self.aiThreshingDirectionZ = dz/length;
			else
				self.aiThreshingDirectionX = -(dx/length);
				self.aiThreshingDirectionZ = -(dz/length);
			end
		end
	end; --END for i in self.cp.workTools

	if hasFinishedWork then
		isFinishingWork = true
	end
	return allowedToDrive, workArea, workSpeed, activeTipper ,isFinishingWork,forceSpeedLimit
end