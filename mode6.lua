local max, min = math.max, math.min;

function courseplay:handle_mode6(vehicle, allowedToDrive, workSpeed, fillLevelPct, lx , lz, refSpeed )
	local workTool;
	local activeTipper = nil
	local specialTool = false
	local forceSpeedLimit = refSpeed 
	--[[
	if vehicle.attachedCutters ~= nil then
		for cutter, implement in pairs(vehicle.attachedCutters) do
			AICombine.addCutterTrigger(vehicle, cutter);
		end;
	end;
	--]]
	local fieldArea = (vehicle.cp.waypointIndex > vehicle.cp.startWork) and (vehicle.cp.waypointIndex < vehicle.cp.stopWork)
	local workArea = (vehicle.cp.waypointIndex > vehicle.cp.startWork) and (vehicle.cp.waypointIndex < vehicle.cp.finishWork)
	local isFinishingWork = false
	local hasFinishedWork = false
	if vehicle.cp.waypointIndex == vehicle.cp.finishWork and vehicle.cp.abortWork == nil then
		local _,y,_ = getWorldTranslation(vehicle.cp.DirectionNode)
		local _,_,z = worldToLocal(vehicle.cp.DirectionNode,vehicle.Waypoints[vehicle.cp.finishWork].cx,y,vehicle.Waypoints[vehicle.cp.finishWork].cz)
		z = -z
		local frontMarker = Utils.getNoNil(vehicle.cp.aiFrontMarker,-3)
		if frontMarker + z < 0 then
			workArea = true
			isFinishingWork = true
		elseif vehicle.cp.finishWork ~= vehicle.cp.stopWork then
			courseplay:setWaypointIndex(vehicle, min(vehicle.cp.finishWork + 1,vehicle.cp.numWaypoints));
		end;
	end;
	if vehicle.cp.hasTransferCourse and vehicle.cp.abortWork ~= nil and vehicle.cp.waypointIndex == 1 then
		courseplay:setWaypointIndex(vehicle,vehicle.cp.startWork+1);
	end
	if fieldArea or vehicle.cp.waypointIndex == vehicle.cp.startWork or vehicle.cp.waypointIndex == vehicle.cp.stopWork +1 then
		workSpeed = 1;
	end
	if (vehicle.cp.waypointIndex == vehicle.cp.stopWork or vehicle.cp.previousWaypointIndex == vehicle.cp.stopWork) and vehicle.cp.abortWork == nil and not vehicle.cp.isLoaded and not isFinishingWork and vehicle.cp.wait then
		allowedToDrive = false
		CpManager:setGlobalInfoText(vehicle, 'WORK_END');
		hasFinishedWork = true
	end

	-- Wait until we have fully started up Threshing
	if vehicle.sampleThreshingStart and isSamplePlaying(vehicle.sampleThreshingStart.sample) then
		-- Only allow us to drive if we are moving backwards.
		if not vehicle.cp.isReverseBackToPoint then
			allowedToDrive = false;
		end;
		courseplay:setInfoText(vehicle, string.format("COURSEPLAY_STARTING_UP_TOOL;%s",tostring(vehicle.name)));
	end;

	local vehicleIsFolding, vehicleIsFolded, vehicleIsUnfolded = courseplay:isFolding(vehicle);
	for i=1, #(vehicle.cp.workTools) do
		workTool = vehicle.cp.workTools[i];
		local tool = vehicle
		if courseplay:isAttachedCombine(workTool) then
			tool = workTool
			workTool.cp.turnStage = vehicle.cp.turnStage
		end
		local ridgeMarker = vehicle.Waypoints[vehicle.cp.waypointIndex].ridgeMarker
		local nextRidgeMarker = vehicle.Waypoints[min(vehicle.cp.waypointIndex+4,vehicle.cp.numWaypoints)].ridgeMarker
		
		if workTool.haeckseldolly then
			if (ridgeMarker == 2 or (nextRidgeMarker == 2 and vehicle.cp.turnStage>1)) and workTool.bunkerrechts ~= false then
				workTool.bunkerrechts = false
			elseif (ridgeMarker == 1 or (nextRidgeMarker == 1 and vehicle.cp.turnStage>1)) and workTool.bunkerrechts ~= true then
				workTool.bunkerrechts = true
			end
		end
		
		local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool);
		local needsLowering = false
		
		if workTool.attacherJoint ~= nil then
			needsLowering = workTool.attacherJoint.needsLowering
		end
		
		--speedlimits								--	TODO (Tom) workTool:doCheckSpeedLimit() is not working for harvesters			
		if workTool.doCheckSpeedLimit and (workTool:doCheckSpeedLimit() or workTool.isPreparerSpeedLimitActive) then
			forceSpeedLimit = min(forceSpeedLimit, workTool.speedLimit)
		end
		
		-- stop while folding
		if (isFolding or vehicleIsFolding) and vehicle.cp.turnStage == 0 then
			allowedToDrive = false;
			--courseplay:debug(tostring(workTool.name) .. ": isFolding -> allowedToDrive == false", 6);
		end;

		-- implements, no combine or chopper
		if workTool ~= nil and tool.attachedCutters == nil then
			-- balers
			if courseplay:isBaler(workTool) then
				if vehicle.cp.waypointIndex >= vehicle.cp.startWork + 1 and vehicle.cp.waypointIndex < vehicle.cp.stopWork and vehicle.cp.turnStage == 0 then
																			--  vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload, ridgeMarker,forceSpeedLimit)
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle, workTool, true,   true,  true,   allowedToDrive, nil,   nil);
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

				if vehicle.cp.previousWaypointIndex == vehicle.cp.stopWork -1 and workTool.isTurnedOn then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,false,false,false,allowedToDrive,nil,nil)
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
					specialTool, allowedToDrive, forceSpeedLimit = courseplay:handleSpecialTools(vehicle,workTool,true,true,true,allowedToDrive,nil,nil,nil,forceSpeedLimit);
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

				if (fillLevelPct == 100 and vehicle.cp.hasUnloadingRefillingCourse or vehicle.cp.waypointIndex == vehicle.cp.stopWork) and workTool.isInWorkPosition and not workTool:getIsAnimationPlaying('rotatePlatform') and not workTool:getIsAnimationPlaying('emptyRotate') then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,false,false,false,allowedToDrive,nil,nil);
					if not specialTool then
						workTool.grabberIsMoving = true
						workTool.isInWorkPosition = false
						BaleLoader.moveToTransportPosition(workTool)
						-- workTool:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT);
					end;
				end

				if fillLevelPct == 100 and not vehicle.cp.hasUnloadingRefillingCourse then
					if vehicle.cp.automaticUnloadingOnField then
						specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,false,false,false,allowedToDrive,nil,true); 
						if not specialTool then
							vehicle.cp.unloadOrder = true
						end
						CpManager:setGlobalInfoText(vehicle, 'UNLOADING_BALE');
					end
				end;

				-- stop when unloading
				if workTool.activeAnimations and (workTool:getIsAnimationPlaying('rotatePlatform') or workTool:getIsAnimationPlaying('emptyRotate')) then
					allowedToDrive = false;
				end;

				-- automatic unload
				if vehicle.cp.delayFolding and courseplay:timerIsThrough(vehicle, 'foldBaleLoader', false) then
					vehicle.cp.unloadOrder = true
					vehicle.cp.delayFolding = nil
				end
				
				if (not workArea and vehicle.Waypoints[vehicle.cp.previousWaypointIndex].wait and (vehicle.cp.wait or fillLevelPct == 0)) or vehicle.cp.unloadOrder then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,false,false,false,allowedToDrive,nil,true);
					if not specialTool then
						if workTool.emptyState ~= BaleLoader.EMPTY_NONE then
							if workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_DROP then
								-- (2) drop the bales
								-- print(('%s: set state BaleLoader.CHANGE_DROP_BALES'):format(nameNum(workTool)));
								g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_DROP_BALES), true, nil, workTool)
							elseif workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_SINK then
								-- (3) lower (fold) table
								if not courseplay:getCustomTimerExists(vehicle, 'foldBaleLoader') then
									-- print(('%s: foldBaleLoader timer not running -> set timer 2 seconds'):format(nameNum(workTool)));
									courseplay:setCustomTimer(vehicle, 'foldBaleLoader', 2);
									vehicle.cp.delayFolding = true;
								elseif courseplay:timerIsThrough(vehicle, 'foldBaleLoader', false) then
									-- print(('%s: timer through -> set state BaleLoader.CHANGE_SINK -> reset timer'):format(nameNum(workTool)));
									g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_SINK), true, nil, workTool);
									courseplay:resetCustomTimer(vehicle, 'foldBaleLoader', true);
								end;

								-- Change the direction to forward if we were reversing.
								if vehicle.Waypoints[vehicle.cp.waypointIndex].rev then
									-- print(('%s: set waypointIndex to next forward point'):format(nameNum(workTool)));
									courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
								end;
							elseif workTool.emptyState == BaleLoader.EMPTY_WAIT_TO_REDO then
								-- print(('%s: set state BaleLoader.CHANGE_EMPTY_REDO'):format(nameNum(workTool)));
								g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_EMPTY_REDO), true, nil, workTool);
							end;
						else
							-- (1) lift (unfold) table
							if BaleLoader.getAllowsStartUnloading(workTool) then
								-- print(('%s: set state BaleLoader.CHANGE_EMPTY_START'):format(nameNum(workTool)));
								g_server:broadcastEvent(BaleLoaderStateEvent:new(workTool, BaleLoader.CHANGE_EMPTY_START), true, nil, workTool);
							end;
							vehicle.cp.unloadOrder = false;
						end;
					end;
				end;
			--END baleloader


			-- other worktools, tippers, e.g. forage wagon
			else
				if workArea and fillLevelPct ~= 100 and ((vehicle.cp.abortWork == nil) or (vehicle.cp.abortWork ~= nil and vehicle.cp.previousWaypointIndex == vehicle.cp.abortWork) or (vehicle.cp.runOnceStartCourse)) and vehicle.cp.turnStage == 0  then
					--courseplay:handleSpecialTools(vehicle,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,true,true,true,allowedToDrive,nil,nil)
					if allowedToDrive then
						if not specialTool then
							--unfold
							local recordnumber = min(vehicle.cp.waypointIndex + 2, vehicle.cp.numWaypoints);
							local forecast = Utils.getNoNil(vehicle.Waypoints[recordnumber].ridgeMarker,0)
							local marker = Utils.getNoNil(vehicle.Waypoints[vehicle.cp.waypointIndex].ridgeMarker,0)
							local waypoint = max(marker,forecast)
							if courseplay:isFoldable(workTool) and not isFolding and not isUnfolded then
								if not workTool.cp.hasSpecializationPlough then
									courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
									workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
									vehicle.cp.runOnceStartCourse = false;
								elseif waypoint == 2 and vehicle.cp.runOnceStartCourse then --wegpunkte finden und richtung setzen...
									courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
									workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
									if workTool:getIsPloughRotationAllowed() then
										AITractor.aiRotateLeft(vehicle);
										vehicle.cp.runOnceStartCourse = false;
									end
								elseif vehicle.cp.runOnceStartCourse then
									courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
									workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
									vehicle.cp.runOnceStartCourse = false;
								end
							end;


							if not isFolding and isUnfolded and not waitForSpecialTool then --TODO: where does "waitForSpecialTool" come from? what does it do?
								--lower
								if needsLowering and workTool.aiNeedsLowering then
									vehicle:setAIImplementsMoveDown(true);
									courseplay:debug(string.format('%s: lower order', nameNum(workTool)), 17);
								end;

								--turn on
								if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn then
									workTool:setIsTurnedOn(true, false);
									courseplay:debug(string.format('%s: turn on order', nameNum(workTool)), 17);
									vehicle.cp.runOnceStartCourse = false
									courseplay:setMarkers(vehicle, workTool);
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
				elseif not workArea or vehicle.cp.abortWork ~= nil or vehicle.cp.isLoaded or vehicle.cp.previousWaypointIndex == vehicle.cp.stopWork then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,false,false,false,allowedToDrive,nil,nil)
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
							if needsLowering and workTool.aiNeedsLowering and vehicle.cp.turnStage == 0 then
								vehicle:setAIImplementsMoveDown(false);
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
				if vehicle.cp.tipperFillLevel ~= nil and vehicle.cp.tipperCapacity ~= nil then
					if vehicle.cp.currentTipTrigger and vehicle.cp.tipperFillLevel == 0 then
						courseplay:resetTipTrigger(vehicle, true);
					end

					-- damn, i missed the trigger!
					if vehicle.cp.currentTipTrigger ~= nil then
						local trigger = vehicle.cp.currentTipTrigger
						local triggerId = trigger.triggerId
						if trigger.isPlaceableHeapTrigger then
							triggerId = trigger.rootNode;
						end;

						if trigger.specialTriggerId ~= nil then
							triggerId = trigger.specialTriggerId
						end
						local trigger_x, trigger_y, trigger_z = getWorldTranslation(triggerId);
						local ctx, cty, ctz = getWorldTranslation(vehicle.cp.DirectionNode);

						-- Start reversion value is to check if we have started to reverse
						-- This is used in case we already registered a tipTrigger but changed the direction and might not be in that tipTrigger when unloading. (Bug Fix)
						local startReversing = vehicle.Waypoints[vehicle.cp.waypointIndex].rev and not vehicle.Waypoints[vehicle.cp.previousWaypointIndex].rev;
						if startReversing then
							courseplay:debug(string.format("%s: Is starting to reverse. Tip trigger is reset.", nameNum(vehicle)), 13);
						end;

						local distToTrigger = courseplay:distance(ctx, ctz, trigger_x, trigger_z);
						local isBGA = trigger.bunkerSilo ~= nil and trigger.bunkerSilo.movingPlanes ~= nil
						local triggerLength = Utils.getNoNil(vehicle.cp.currentTipTrigger.cpActualLength,20)
						local maxDist = isBGA and (vehicle.cp.totalLength + 55) or (vehicle.cp.totalLength + triggerLength); 
						if distToTrigger > maxDist or startReversing then --it's a backup, so we don't need to care about +/-10m
							courseplay:resetTipTrigger(vehicle);
							courseplay:debug(string.format("%s: distance to currentTipTrigger = %d (> %d or start reversing) --> currentTipTrigger = nil", nameNum(vehicle), distToTrigger, maxDist), 1);
						end
					end

					-- tipper is not empty and tractor reaches TipTrigger
					if vehicle.cp.tipperFillLevel > 0 and vehicle.cp.currentTipTrigger ~= nil and vehicle.cp.waypointIndex > 3 then
						allowedToDrive, activeTipper = courseplay:unload_tippers(vehicle, allowedToDrive);
						courseplay:setInfoText(vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
					end
				end;
			end; --END other tools

			-- Begin work or go to abortWork
			if vehicle.cp.previousWaypointIndex == vehicle.cp.startWork and fillLevelPct ~= 100 then
				if vehicle.cp.abortWork ~= nil then
					if vehicle.cp.abortWork < 5 then
						vehicle.cp.abortWork = 6
					end
					courseplay:setWaypointIndex(vehicle, vehicle.cp.abortWork);
					if vehicle.cp.waypointIndex < 2 then
						courseplay:setWaypointIndex(vehicle, 2);
					end
					if vehicle.Waypoints[vehicle.cp.waypointIndex].turn ~= nil or vehicle.Waypoints[vehicle.cp.waypointIndex+1].turn ~= nil  then
						courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex - 2);
					end
				end
			end
			-- last point reached restart
			if vehicle.cp.abortWork ~= nil then
				if (vehicle.cp.previousWaypointIndex == vehicle.cp.abortWork ) and fillLevelPct ~= 100 then
					courseplay:setWaypointIndex(vehicle, vehicle.cp.abortWork + 2); -- drive to waypoint after next waypoint
					vehicle.cp.abortWork = nil
				end
			end
			-- save last point
			if (fillLevelPct == 100 or vehicle.cp.isLoaded) and workArea and not courseplay:isBaler(workTool) then
				if vehicle.cp.hasUnloadingRefillingCourse and vehicle.cp.abortWork == nil then
					vehicle.cp.abortWork = vehicle.cp.previousWaypointIndex - 10;
					-- invert lane offset if abortWork is before previous turn point (symmetric lane change)
					if vehicle.cp.symmetricLaneChange and vehicle.cp.laneOffset ~= 0 then
						for i=vehicle.cp.abortWork,vehicle.cp.previousWaypointIndex do
							local wp = vehicle.Waypoints[i];
							if wp.turn ~= nil then
								courseplay:debug(string.format('%s: abortWork set (%d), abortWork + %d: turn=%s -> change lane offset back to abortWork\'s lane', nameNum(vehicle), vehicle.cp.abortWork, i-1, tostring(wp.turn)), 12);
								courseplay:changeLaneOffset(vehicle, nil, vehicle.cp.laneOffset * -1);
								vehicle.cp.switchLaneOffset = true;
								break;
							end;
						end;
					end;
					--courseplay:setWaypointIndex(vehicle, vehicle.cp.stopWork - 4);
					courseplay:setWaypointIndex(vehicle, vehicle.cp.stopWork + 1);
					if vehicle.cp.waypointIndex < 1 then
						courseplay:setWaypointIndex(vehicle, 1);
					end
					--courseplay:debug(string.format("Abort: %d StopWork: %d",vehicle.cp.abortWork,vehicle.cp.stopWork), 12)
				elseif not vehicle.cp.hasUnloadingRefillingCourse and not vehicle.cp.automaticUnloadingOnField then
					allowedToDrive = false;
					CpManager:setGlobalInfoText(vehicle, 'NEEDS_UNLOADING');
				elseif not vehicle.cp.hasUnloadingRefillingCourse and vehicle.cp.automaticUnloadingOnField then
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
			if workArea and not tool.isAIThreshing and vehicle.cp.abortWork == nil and vehicle.cp.turnStage == 0 then
											--courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker,forceSpeedLimit)
				specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,true,true,true,allowedToDrive,nil,nil,ridgeMarker)
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

						if (pipeState == 0 and vehicle.cp.turnStage == 0) or chopperWaitForTrailer then
							tool.cp.waitingForTrailerToUnload = true;
						end;

					-- Combines
					else
						local tankFillLevelPct = tool.fillLevel * 100 / tool.capacity;
						if not vehicle.cp.isReverseBackToPoint then
							-- WorkTool Unfolding.
							if courseplay:isFoldable(workTool) and not isTurnedOn and not isFolding and not isUnfolded then
								courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
								workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
							end;

							-- Combine Unfolding
							if courseplay:isFoldable(tool) then
								if not vehicleIsFolding and not vehicleIsUnfolded then
									courseplay:debug(string.format('%s: unfold order (foldDir=%d)', nameNum(tool), tool.cp.realUnfoldDirection), 17);
									tool:setFoldDirection(tool.cp.realUnfoldDirection);
								end;
							end;

							if not isFolding and isUnfolded and not vehicleIsFolding and vehicleIsUnfolded and tankFillLevelPct < 100 and not tool.waitingForDischarge and not isTurnedOn and not weatherStop then
								tool:setIsTurnedOn(true);
							end
						end
						if tool.pipeIsUnloading and (tool.courseplayers == nil or tool.courseplayers[1] == nil) and tool.cp.stopWhenUnloading and tankFillLevelPct >= 1 then
							tool.stopForManualUnloader = true
						end
							
						if tankFillLevelPct >= 100 
						or tool.waitingForDischarge 
						or (tool.cp.stopWhenUnloading and tool.pipeIsUnloading and tool.courseplayers and tool.courseplayers[1] ~= nil and tool.courseplayers[1].cp.modeState ~= 9) 
						or tool.stopForManualUnloader then
							tool.waitingForDischarge = true;
							allowedToDrive = false;
							if isTurnedOn then
								tool:setIsTurnedOn(false);
							end;
							if workTool:isLowered() then
									courseplay:lowerImplements(vehicle, false, false);
							end;
							if (tankFillLevelPct < 80 and not tool.cp.stopWhenUnloading) or (tool.cp.stopWhenUnloading and tool.fillLevel == 0) then
								courseplay:setReverseBackDistance(vehicle, 2);
								tool.waitingForDischarge = false;
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
							CpManager:setGlobalInfoText(vehicle, 'WEATHER');
						end

					end

					-- Make sure we are lowered when working the field.
					if allowedToDrive and isTurnedOn and not workTool:isLowered() and not vehicle.cp.isReverseBackToPoint then
						courseplay:lowerImplements(vehicle, true, false);
					end;
				
				end
			 --Stop combine
			elseif vehicle.cp.waypointIndex == vehicle.cp.stopWork or vehicle.cp.abortWork ~= nil then
				local isEmpty = tool.fillLevel == 0
				if vehicle.cp.abortWork == nil and vehicle.cp.wait then
					allowedToDrive = false;
				end
				if isEmpty then
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,false,false,false,allowedToDrive,nil)
				else
					specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,true,false,false,allowedToDrive,nil)
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
				end
				if tool.cp.isCombine and not tool.cp.wantsCourseplayer and tool.fillLevel > 0.1 and tool.courseplayers and #(tool.courseplayers) == 0 then
					tool.cp.wantsCourseplayer = true
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
				if tool.cp.isCombine or (courseplay:isAttachedCombine(workTool) and not courseplay:isSpecialChopper(workTool)) then
					if tool.cp.isCheckedIn == nil or (pipeState == 0 and tool.fillLevel == 0) then
						tool.cp.waitingForTrailerToUnload = false
					end
				elseif tool.cp.isChopper or courseplay:isSpecialChopper(workTool) then
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

			local dx,_,dz = localDirectionToWorld(vehicle.cp.DirectionNode, 0, 0, 1);
			local length = Utils.vector2Length(dx,dz);
			if vehicle.cp.turnStage == 0 then
				vehicle.aiThreshingDirectionX = dx/length;
				vehicle.aiThreshingDirectionZ = dz/length;
			else
				vehicle.aiThreshingDirectionX = -(dx/length);
				vehicle.aiThreshingDirectionZ = -(dz/length);
			end
		end
	end; --END for i in vehicle.cp.workTools

	if hasFinishedWork then
		isFinishingWork = true
	end
	return allowedToDrive, workArea, workSpeed, activeTipper ,isFinishingWork,forceSpeedLimit
end