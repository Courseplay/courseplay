function courseplay:handle_mode4(vehicle, allowedToDrive, workSpeed, refSpeed)
	local workTool;
	local forceSpeedLimit = refSpeed
	local fieldArea = (vehicle.cp.waypointIndex > vehicle.cp.startWork) and (vehicle.cp.waypointIndex < vehicle.cp.stopWork)
	local workArea = (vehicle.cp.waypointIndex > vehicle.cp.startWork) and (vehicle.cp.waypointIndex < vehicle.cp.finishWork)
	local isFinishingWork = false
	local hasFinishedWork = false
	local seederFillLevelPct = vehicle.cp.totalSeederFillLevelPercent   or 100;
	local sprayerFillLevelPct = vehicle.cp.totalSprayerFillLevelPercent or 100;
	if vehicle.cp.hasFertilizerSowingMachine and not vehicle.cp.fertilizerOption then
		sprayerFillLevelPct = 100
	end
	local refillMessage = ""
	--TODO Tommi remove this variabes and do it via fillUnitsFillTypes
	if seederFillLevelPct == 0 and sprayerFillLevelPct == 0 then
		refillMessage = g_i18n:getText("fillType_seeds")..", "..g_i18n:getText("fillType_fertilizer");
	elseif sprayerFillLevelPct == 0 then
		refillMessage = g_i18n:getText("fillType_fertilizer")
	else
		refillMessage = g_i18n:getText("fillType_seeds")
	end
	
	
	--print(string.format("seederFillLevelPct:%s; sprayerFillLevelPct:%s",tostring(seederFillLevelPct),tostring(sprayerFillLevelPct)))
	if vehicle.cp.waypointIndex == vehicle.cp.finishWork and vehicle.cp.abortWork == nil and not vehicle.cp.hasFinishedWork then
		local _,y,_ = getWorldTranslation(vehicle.cp.DirectionNode)
		local _,_,z = worldToLocal(vehicle.cp.DirectionNode,vehicle.Waypoints[vehicle.cp.finishWork].cx,y,vehicle.Waypoints[vehicle.cp.finishWork].cz)
		if not vehicle.isReverseDriving then
			z = -z
		end
		local frontMarker = Utils.getNoNil(vehicle.cp.aiFrontMarker,-3)
		if frontMarker + z -2 < 0 then
			workArea = true
			isFinishingWork = true
		elseif vehicle.cp.finishWork ~= vehicle.cp.stopWork then
			courseplay:setWaypointIndex(vehicle, math.min(vehicle.cp.finishWork + 1, vehicle.cp.numWaypoints));
		end;
	end;
	if vehicle.cp.hasTransferCourse and vehicle.cp.abortWork ~= nil and vehicle.cp.waypointIndex == 1 then
		courseplay:setWaypointIndex(vehicle,vehicle.cp.startWork+1);
	end
	--go with field speed	
	if fieldArea or vehicle.cp.waypointIndex == vehicle.cp.startWork or vehicle.cp.waypointIndex == vehicle.cp.stopWork +1 then
		workSpeed = 1;
	end
	
	-- Begin Work
	if vehicle.cp.previousWaypointIndex == vehicle.cp.startWork then
		if seederFillLevelPct ~= 0 and sprayerFillLevelPct ~= 0 then
												-- vv it's to prevent nil failure when abortWork is saved but the field course is not been loaded after loadMap
			if vehicle.cp.abortWork ~= nil and vehicle.cp.abortWork <= vehicle.cp.numWaypoints then  
				if vehicle.cp.abortWork < 5 then
					vehicle.cp.abortWork = 6
				end
				courseplay:setWaypointIndex(vehicle, vehicle.cp.abortWork);
				if vehicle.Waypoints[vehicle.cp.waypointIndex].turnStart or vehicle.Waypoints[vehicle.cp.waypointIndex+1].turnStart then
					courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex - 2);
					--- Invert lane offset if abortWork is before previous turn point (symmetric lane change)
					if vehicle.cp.symmetricLaneChange and vehicle.cp.laneOffset ~= 0 and not vehicle.cp.switchLaneOffset then
						courseplay:debug(string.format('%s: abortWork + %d: turnStart=%s -> change lane offset back to abortWork\'s lane', nameNum(vehicle), i-1, tostring(vehicle.Waypoints[vehicle.cp.waypointIndex].turnStart and true or false)), 12);
						courseplay:changeLaneOffset(vehicle, nil, vehicle.cp.laneOffset * -1);
						vehicle.cp.switchLaneOffset = true;
					end;
				end
				if vehicle.cp.realisticDriving then
					local tx, tz = vehicle.Waypoints[vehicle.cp.waypointIndex-2].cx,vehicle.Waypoints[vehicle.cp.waypointIndex-2].cz
					courseplay.debugVehicle( 9, vehicle, "mode4 66")
					if vehicle.cp.isNavigatingPathfinding == false and courseplay:calculateAstarPathToCoords( vehicle, nil, tx, tz, vehicle.cp.turnDiameter*2, true) then
						courseplay:setCurrentTargetFromList(vehicle, 1);
						courseplay.debugVehicle( 9, vehicle, "mode4 69")
						vehicle.cp.isNavigatingPathfinding = true;
					elseif not courseplay:onAlignmentCourse( vehicle ) then
						courseplay:startAlignmentCourse( vehicle, vehicle.Waypoints[vehicle.cp.waypointIndex-2], true)
					end
				end
				vehicle.cp.ppc:initialize()
			end
		elseif vehicle.cp.hasUnloadingRefillingCourse and vehicle.cp.abortWork ~= nil then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(vehicle, 'NEEDS_REFILLING',nil,refillMessage);		
		end
	end
	-- last point reached restart
	if vehicle.cp.abortWork ~= nil then
		if vehicle.cp.previousWaypointIndex == vehicle.cp.abortWork and seederFillLevelPct ~= 0 and sprayerFillLevelPct ~= 0 then
			courseplay:setWaypointIndex(vehicle, vehicle.cp.abortWork + 2);
			vehicle.cp.ppc:initialize()
		end
		local offset = 9;
		if vehicle.cp.hasSowingMachine then
			offset = 8;
		end;
		if vehicle.cp.realisticDriving then 
			offset = 0;
			if vehicle.cp.hasSowingMachine then
				offset = 1;
			end;
		end;
		if vehicle.cp.previousWaypointIndex < vehicle.cp.stopWork and vehicle.cp.previousWaypointIndex > vehicle.cp.abortWork + offset + vehicle.cp.abortWorkExtraMoveBack then

			vehicle.cp.abortWork = nil;
		end
	end
	-- save last point
	if (seederFillLevelPct == 0 or sprayerFillLevelPct == 0) and workArea then
		if vehicle.cp.hasUnloadingRefillingCourse and vehicle.cp.abortWork == nil then
			courseplay:setAbortWorkWaypoint(vehicle);
		elseif not vehicle.cp.hasUnloadingRefillingCourse then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(vehicle, 'NEEDS_REFILLING',nil,refillMessage);
		end;
	end
	--
	if (vehicle.cp.waypointIndex == vehicle.cp.stopWork or vehicle.cp.previousWaypointIndex == vehicle.cp.stopWork) and vehicle.cp.abortWork == nil and not isFinishingWork and vehicle.cp.wait then
		allowedToDrive = false;
		CpManager:setGlobalInfoText(vehicle, 'WORK_END');
		hasFinishedWork = true;
		if vehicle.cp.hasUnloadingRefillingCourse and vehicle.cp.waypointIndex == vehicle.cp.stopWork then --make sure that previousWaypointIndex is stopWork, so the 'waiting points' algorithm in drive() works
			courseplay:setWaypointIndex(vehicle, vehicle.cp.stopWork + 1);
			vehicle.cp.ppc:initialize()
		end;
	end;
	
	local firstPoint = vehicle.cp.previousWaypointIndex == 1;
	local prevPoint = vehicle.Waypoints[vehicle.cp.previousWaypointIndex];
	local nextPoint = vehicle.Waypoints[vehicle.cp.waypointIndex];
	
	local ridgeMarker = prevPoint.ridgeMarker;
	local specialTool; -- define it, so it will not be an global value anymore
	
	for i=1, #(vehicle.cp.workTools) do
		workTool = vehicle.cp.workTools[i];
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
			if isFolding and vehicle.cp.turnStage == 0 then
				allowedToDrive = false;
				--courseplay:debug(tostring(workTool.name) .. ": isFolding -> allowedToDrive == false", 12);
			end;
			--courseplay:debug(string.format("%s: unfold: turnOnFoldDirection=%s, foldMoveDirection=%s", workTool.name, tostring(workTool.turnOnFoldDirection), tostring(workTool.foldMoveDirection)), 12);
		end;
		if workArea and seederFillLevelPct ~= 0 and sprayerFillLevelPct ~= 0 and (vehicle.cp.abortWork == nil or vehicle.cp.runOnceStartCourse) and vehicle.cp.turnStage == 0 and not vehicle.cp.inTraffic then
			vehicle.cp.runOnceStartCourse = false;
			--turn On                     courseplay:handleSpecialTools(vehicle,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker)
			specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,true,true,true,allowedToDrive,nil,nil, ridgeMarker)
			local hasSetUnfoldOrderThisLoop = false
			if allowedToDrive then
				if not specialTool then
					vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
					--[[ --unfold																									-- Why has this been comments out? Mode6 uses a similar line 
					if courseplay:isFoldable(workTool) and workTool:getIsFoldAllowed() and not isFolding and not isUnfolded then -- and ((vehicle.cp.abortWork ~= nil and vehicle.cp.waypointIndex == vehicle.cp.abortWork - 2) or (vehicle.cp.abortWork == nil and vehicle.cp.waypointIndex == 2)) then
						courseplay:debug(string.format('%s: unfold order (foldDir %d)', nameNum(workTool), workTool.cp.realUnfoldDirection), 17);
						workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
						hasSetUnfoldOrderThisLoop = true
					end;
					if hasSetUnfoldOrderThisLoop then
						isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool);
					end
															--vv  used for foldables, which are not folding before start Strautmann manure spreader 
					if not isFolding and (isUnfolded or hasSetUnfoldOrderThisLoop) then 
						courseplay:manageImplements(vehicle, true, true, true)
						
						--set or stow ridge markers
						if (courseplay:isSowingMachine(workTool) or workTool.cp.isKuhnHR4004) and vehicle.cp.ridgeMarkersAutomatic then
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
							end;
						elseif workTool.ridgeMarkers and #workTool.ridgeMarkers > 0 and workTool.setRidgeMarkerState ~= nil and workTool.ridgeMarkerState ~= 0 then
							workTool:setRidgeMarkerState(0);
						end;

						--lower/raise
						if (needsLowering or workTool.aiNeedsLowering) and not courseplay:onAlignmentCourse( vehicle ) then
							--courseplay:debug(string.format("WP%d: isLowered() = %s, hasGroundContact = %s", vehicle.cp.waypointIndex, tostring(workTool:isLowered()), tostring(workTool.hasGroundContact)),12);
							if not workTool:getIsLowered() then
								courseplay:debug(string.format('%s: lower order', nameNum(workTool)), 17);
								workTool:setLowered(true);
								courseplay:setCustomTimer(vehicle, "lowerTimeOut" , 5 )
							elseif not speedLimitActive and not courseplay:timerIsThrough(vehicle, "lowerTimeOut") then 
								allowedToDrive = false;
								courseplay:debug(string.format('%s: wait for lowering', nameNum(workTool)), 17);
							end;
						end;
						--turn on
						if workTool.setIsTurnedOn ~= nil and not workTool.spec_turnOnVehicle.isTurnedOn then
							courseplay:setMarkers(vehicle, workTool);
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
					end; --END if not isFolding ]]
				end
				
				--Sprayer Addon Support
				if workTool.sectionControlActive then
					if workTool:getCurrentMode() ~= 4 then
						workTool:changeMode(4, true);
					end
					if workTool:getIsUnfolded() and workTool.getIsTurnedOn ~= nil and workTool:getIsTurnedOn() and #workTool.sections > 0 then
						for index, section in pairs(workTool.sections) do
							if workTool:checkIfAreaSprayed(index) == section.activated then
								workTool:toggleSection(index, section.activated);
							end;
						end;
					end;
				end;
				
				--DRIVINGLINE SPEC
				if workTool.cp.hasSpecializationDrivingLine and not workTool.manualDrivingLine then
					local curLaneReal = vehicle.Waypoints[vehicle.cp.waypointIndex].laneNum;
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
		elseif workArea and vehicle.cp.abortWork == nil and vehicle.cp.inTraffic then
			specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle, workTool, true, true, false, allowedToDrive, nil, nil, ridgeMarker);
			if not specialTool then
				if workTool.setIsTurnedOn ~= nil and workTool.spec_turnOnVehicle.isTurnedOn then
					workTool:setIsTurnedOn(false, false);
				end;
				courseplay:debug(string.format('%s: [TRAFFIC] turn off order', nameNum(workTool)), 17);
			end;

		--TURN OFF AND FOLD
		elseif vehicle.cp.turnStage == 0 then
			--turn off
			specialTool, allowedToDrive = courseplay:handleSpecialTools(vehicle,workTool,false,false,false,allowedToDrive,nil,nil, ridgeMarker)
			if not specialTool then
				vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
				--[[ if workTool.setIsTurnedOn ~= nil and workTool.spec_turnOnVehicle.isTurnedOn then
					workTool:setIsTurnedOn(false, false);
					courseplay:debug(string.format('%s: turn off order', nameNum(workTool)), 17);
				end; 

				--raise
				if not isFolding and isUnfolded then
					courseplay:manageImplements(vehicle, false, false, false)
					-if (needsLowering or workTool.aiNeedsLowering) and workTool:isLowered() then
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
				end; ]]
			end
		end

		--[[if not allowedToDrive then
			workTool:setIsTurnedOn(false, false)
		end]] --?? why am i here ??
	end; --END for i in vehicle.cp.workTools
	if hasFinishedWork then
		isFinishingWork = true
		vehicle.cp.hasFinishedWork = true
	end
	return allowedToDrive, workArea, workSpeed,isFinishingWork,forceSpeedLimit
end;
