function courseplay:handleMode3(vehicle, allowedToDrive, dt)
	courseplay:debug(string.format("handleMode3(vehicle, allowedToDrive=%s, dt)",tostring(allowedToDrive)), 15);
	local workTool = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill] or vehicle.cp.workTools[1]; -- Why is currentTrailerToFill here it should be nil TODO test to see
	local backPointsUnfoldPipe = 8; --[[workTool.cp.backPointsUnfoldPipe or 8;]] --NOTE: backPointsUnfoldPipe must not be 0! 
	local forwardPointsFoldPipe = workTool.cp.forwardPointsFoldPipe or 2;
	local fillLevelPct = workTool.cp.fillLevelPercent

	if workTool.cp.isSugarCaneAugerWagon then 

		if vehicle.cp.wait and (vehicle.cp.previousWaypointIndex == vehicle.cp.waitPoints[1] or vehicle.cp.waypointIndex == vehicle.cp.waitPoints[1]) then 
			-- Set Mode 3 Unloading So drive knows we still need to do things. Set currentTrailerToFill to ensure that we are at nil
			vehicle.cp.isMode3Unloading = true
			vehicle.cp.currentTrailerToFill = nil
			courseplay:cancelWait(vehicle);
			vehicle.cp.isUnloaded = false -- Cancelwait sets this to true. We still need it to be false. Backwards way of doing it but this allows the conuntie button to be used. 
		end

		if vehicle.cp.isMode3Unloading == true then
			return courseplay:handleSugarCaneTrailer(vehicle, allowedToDrive, dt)
		end	

	elseif workTool.cp.isAugerWagon and not workTool.cp.isSugarCaneAugerWagon then
		workTool.cp.isUnloading = workTool.cp.fillLevel < workTool.cp.lastFillLevel;
		if vehicle.cp.wait and vehicle.cp.previousWaypointIndex >= math.max(vehicle.cp.waitPoints[1] - backPointsUnfoldPipe, 2) and vehicle.cp.previousWaypointIndex < vehicle.cp.waitPoints[1] and not workTool.cp.isUnloading then
			courseplay:handleAugerWagon(vehicle, workTool, true, false, "unfold",dt); --unfold=true, unload=false
		end;

		if vehicle.cp.wait and vehicle.cp.previousWaypointIndex == vehicle.cp.waitPoints[1] then
			CpManager:setGlobalInfoText(vehicle, 'OVERLOADING_POINT');

			local driveOn = false
			if fillLevelPct > 0 then
				courseplay:handleAugerWagon(vehicle, workTool, true, true, "unload",dt); --unfold=true, unload=true
			end;
			
			if vehicle.cp.prevFillLevelPct ~= nil then
				if fillLevelPct > 0 and workTool.cp.isUnloading then
					courseplay:setCustomTimer(vehicle, "fillLevelChange", 10);
				elseif fillLevelPct == vehicle.cp.prevFillLevelPct and fillLevelPct < vehicle.cp.followAtFillLevel and courseplay:timerIsThrough(vehicle, "fillLevelChange", false) then
					driveOn = true; -- drive on if fillLevelPct doesn't change for 10 seconds and fill level is < required_fillLevelPct_for_follow
					courseplay:debug('        no fillLevel change for 10 seconds -> driveOn', 15);
				end;
			end;

			vehicle.cp.prevFillLevelPct = fillLevelPct;
			
			if (fillLevelPct == 0 or driveOn) and not workTool.cp.isUnloading then
				courseplay:handleAugerWagon(vehicle, workTool, true, false, "stopUnload",dt); --unfold=true, unload=false
				courseplay:cancelWait(vehicle);
			end;
		end;

		if courseplay.debugChannels[15] then
			courseplay:checkAndPrintChange(vehicle, vehicle.cp.waitPoints[1], "firstWaitPoint");
			courseplay:checkAndPrintChange(vehicle, vehicle.cp.numWaypoints, "numWaypoints");
			courseplay:checkAndPrintChange(vehicle, backPointsUnfoldPipe, "backPointsUnfoldPipe");
			courseplay:checkAndPrintChange(vehicle, forwardPointsFoldPipe, "forwardPointsFoldPipe");

			courseplay:checkAndPrintChange(vehicle, vehicle.cp.previousWaypointIndex, "previousWaypointIndex");
			courseplay:checkAndPrintChange(vehicle, vehicle.cp.isUnloaded, "isUnloaded");
			courseplay:checkAndPrintChange(vehicle, vehicle.cp.wait, "wait");
			print("-------------------------");
		end;

		if vehicle.cp.previousWaypointIndex < math.max(vehicle.cp.waitPoints[1] - backPointsUnfoldPipe, 2) then -- is before unfold pipe point
			courseplay:handleAugerWagon(vehicle, workTool, false, false, "foldBefore",dt); --unfold=false, unload=false
		elseif (not vehicle.cp.wait or vehicle.cp.isUnloaded) and vehicle.cp.previousWaypointIndex >= math.min(vehicle.cp.waitPoints[1] + forwardPointsFoldPipe, vehicle.cp.numWaypoints - 1) then -- is past fold pipe point
			courseplay:handleAugerWagon(vehicle, workTool, false, false, "foldAfter",dt); --unfold=false, unload=false
			courseplay:resetCustomTimer(vehicle, "fillLevelChange", true)
			vehicle.cp.prevFillLevelPct = nil;
		elseif workTool.cp.isUnloading and not vehicle.cp.wait then
			courseplay:handleAugerWagon(vehicle, workTool, true, false, "forceStopUnload",dt); --unfold=true, unload=false
		end;
	end;

	workTool.cp.lastFillLevel = workTool.cp.fillLevel;

end;



function courseplay:handleAugerWagon(vehicle, workTool, unfold, unload, orderName,dt)
	courseplay:debug(string.format("\thandleAugerWagon(vehicle, %s, unfold=%s, unload=%s, orderName=%s)", nameNum(workTool), tostring(unfold), tostring(unload), tostring(orderName)), 15);
	local pipeOrderExists = unfold ~= nil;
	local unloadOrderExists = unload ~= nil;

	if workTool.cp.isSugarCaneAugerWagon then 
		local movingTools = workTool.spec_cylindered.movingTools
		local tipState = workTool:getDischargeState()

		--force the correct tipState 
		if unload then
			--start tipping
			if (tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING) then
				workTool:toggleTipState()
			end
		else
			--close tipper
			if tipState == Trailer.TIPSTATE_OPEN or tipState == Trailer.TIPSTATE_OPENING then
				workTool:toggleTipState()
			end
		end
		
		--execute tipping action
		if tipState == Trailer.TIPSTATE_OPENING then
			local targetPositions = { 	rot = { [1] = 0},
										trans = { [1] = movingTools[1].transMax }
									}
			if courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, nil, targetPositions, dt ,1) then
				local targetPositions = { 	rot = { [1] = movingTools[2].rotMin},
										trans = { [1] = 0 }
									}
				if courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, nil, targetPositions, dt ,2) then
					workTool.tipState = Trailer.TIPSTATE_OPEN
				end
			end
		elseif tipState == Trailer.TIPSTATE_CLOSING then
			local targetPositions = { 	rot = { [1] = movingTools[2].rotMax},
										trans = { [1] = 0 }
									}
			if courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, nil, targetPositions, dt ,2) then
				local targetPositions = { 	rot = { [1] = 0},
										trans = { [1] = movingTools[1].transMin }
									}
				if courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, nil, targetPositions, dt ,1) then
					workTool.tipState = Trailer.TIPSTATE_CLOSED
				end
			end
		end
	
	
	--Taarup Shuttle
	elseif workTool.cp.isTaarupShuttle then
		if pipeOrderExists then
			if unfold and workTool.animationParts[1].clipStartTime then
				workTool:setAnimationTime(1, workTool.animationParts[1].animDuration, false);
			elseif not unfold and workTool.animationParts[1].clipEndTime then
				workTool:setAnimationTime(1, workTool.animationParts[1].offSet, false);
			end;
		end;

		if unloadOrderExists then
			if (unload and workTool.unloadingState ~= 1) or (not unload and workTool.unloadingState ~= 0) then
				workTool:setUnloadingState(unload);
			end;
		end;

	--Overcharge / AgrolinerTUW20 / Hawe SUW
	elseif workTool.cp.hasSpecializationOvercharge or workTool.cp.hasSpecializationAgrolinerTUW20 or workTool.cp.hasSpecializationHaweSUW then
		if pipeOrderExists and workTool.pipe.out ~= nil then
			if unfold and not workTool.pipe.out then
				workTool:setAnimationTime(1, workTool.animationParts[1].animDuration, false);
				if workTool.cp.hasPipeLight and workTool.cp.pipeLight.a ~= CpManager.lightsNeeded then
					--Tommi workTool:setState("work:1", CpManager.lightsNeeded);
				end;
			elseif not unfold and workTool.pipe.out then
				workTool:setAnimationTime(1, workTool.animationParts[1].offSet, false);
				if workTool.cp.hasPipeLight and workTool.cp.pipeLight.a then
					workTool:setState("work:1", false);
				end;
			end;
		end;

		if unload and not workTool.isUnloading and (workTool.trailerFoundId ~= 0 or workTool.trailerFound ~= nil) then
			workTool:setUnloadingState(true);
			if workTool.isDrumActivated ~= nil then
				workTool.isDrumActivated = workTool.isUnloading;
			end;
		elseif not unload and workTool.isUnloading then
			workTool:setUnloadingState(false);
			if workTool.isDrumActivated ~= nil then
				workTool.isDrumActivated = workTool.isUnloading;
			end;
		end;

	--Ropa Big Bear / 'bigBear' spec
	elseif workTool.cp.hasSpecializationBigBear then
		if pipeOrderExists then
			if unfold and not workTool.activeWorkMode then
				if not workTool.workMode then
					courseplay:debug('\t\tunfold=true, activeWorkMode=false, workMode=false -> set workMode to true', 15);
					workTool.workMode = true;
					workTool.bigBearNeedEvent = true;
				else
					courseplay:debug('\t\tunfold=true, activeWorkMode=false, workMode=true -> set activeWorkMode to true', 15);
					workTool.activeWorkMode = true;
					workTool.bigBearNeedEvent = true;
				end;
			elseif not unfold then
				if workTool.activeWorkMode then
					courseplay:debug('\t\tunfold=false, activeWorkMode=true -> set activeWorkMode to false', 15);
					workTool.activeWorkMode = false;
					workTool.bigBearNeedEvent = true;
				end;
			end;
		end;

		if unload and workTool.allowOverload and not workTool.isUnloading and workTool.trailerRaycastFound then
			courseplay:debug('\t\tunload=true, allowOverload=true, isUnloading=false, trailerRaycastFound=true -> set isUnloading to true', 15);
			workTool.isUnloading = true;
			workTool.bigBearNeedEvent = true;
		elseif workTool.isUnloading and (not unload or not workTool.trailerRaycastFound or not workTool.allowOverload) then
			courseplay:debug(string.format('\t\tunload=%s, isUnloading=true, allowOverload=%s, trailerRaycastFound=%s -> set isUnloading to false', tostring(unload), tostring(workTool.allowOverload), tostring(workTool.trailerRaycastFound)), 15);
			workTool.isUnloading = false;
			workTool.bigBearNeedEvent = true;
		end;

	--Brent Avalanche
	elseif workTool.cp.isBrentAvalanche then
		-- n/a in FS13

	--Overloader spec
	elseif workTool.cp.hasSpecializationOverloaderV2 then
		if pipeOrderExists then
			if (unfold and workTool.cpAI ~= "out") or (not unfold and workTool.cpAI ~= "in") then
				local newPipeState = unfold and 'out' or 'in';
				courseplay:debug(string.format('\t\tunfold=%s, workTool.cpAI=%s -> set workTool.cpAI to %s', tostring(unfold), tostring(workTool.cpAI), newPipeState), 15);
				workTool.cpAI = newPipeState;

				if workTool.pipeLight ~= nil and getVisibility(workTool.pipeLight) ~= (unfold and CpManager.lightsNeeded) then
					if workTool.togglePipeLight then
						--Tommi workTool:togglePipeLight(unfold and CpManager.lightsNeeded);
					else
						--Tommi setVisibility(workTool.pipeLight, unfold and CpManager.lightsNeeded);
					end;
				end;
			end;
		end;

		local hasTrailer = workTool.trailerToOverload ~= nil;
		local trailerIsFull = hasTrailer and workTool.trailerToOverload.fillLevel and workTool.trailerToOverload.capacity and workTool.trailerToOverload.fillLevel >= workTool.trailerToOverload.capacity;
		if (unload and hasTrailer and not trailerIsFull and not workTool.isCharging) or (not unload and workTool.isCharging) then
			workTool.isCharging = unload;
			courseplay:debug(string.format('\t\tset workTool.isCharging to %s', tostring(unload)), 15);
		end;

	--AugerWagon spec
	elseif workTool.typeName == 'augerWagon' or workTool.cp.isAugerWagon then
		if pipeOrderExists then
			local pipeIsFolding = workTool.pipeCurrentState == 0;
			local pipeIsFolded = workTool.pipeCurrentState == 1 
			local pipeIsUnfolded = workTool.pipeCurrentState == 2;
			courseplay:debug(string.format("\t\tpipeIsFolding=%s, pipeIsFolded=%s, pipeIsUnfolded=%s", tostring(pipeIsFolding), tostring(pipeIsFolded), tostring(pipeIsUnfolded)), 15);
			if unfold and not pipeIsFolding and pipeIsFolded then
				workTool:setPipeState(2);
				courseplay:debug("\t\t\tsetPipeState(2) (unfold)", 15);
			elseif not unfold and not pipeIsFolding and pipeIsUnfolded then
				workTool:setPipeState(1);
				courseplay:debug("\t\t\tsetPipeState(1) (fold)", 15);
			end;
			if unfold and pipeIsUnfolded and vehicle.cp.pipePositions then
				courseplay:checkAndSetMovingToolsPosition(vehicle, workTool.movingTools, nil, vehicle.cp.pipePositions, dt , vehicle.cp.pipeIndex ) ;
			end
			
			workTool.cp.lastFoldAnimTime = workTool.foldAnimTime;
		end;
	end;
end;

function courseplay:getPipesRotation(vehicle)
	vehicle.cp.pipeWorkToolIndex = nil
	vehicle.cp.pipeIndex = nil
	vehicle.cp.pipePositions = nil
	for i,implement in pairs(vehicle:getAttachedImplements()) do
		local workTool = implement.object;
		if workTool.spec_cylindered.movingTools and workTool.pipeCurrentState and workTool.pipeCurrentState == 2 then
			for index,tool in pairs(workTool.spec_cylindered.movingTools) do
				if tool.axis and tool.axis == "AXIS_PIPE" then
					vehicle.cp.pipeIndex =  index 				--index of movingTools
					vehicle.cp.pipeWorkToolIndex = i			--index of attachedImplements
				end
			end
		end
		if vehicle.cp.pipeIndex ~= nil then
			local rotation, translation = courseplay:getCurrentMovingToolsPosition(self, workTool.spec_cylindered.movingTools, nil, vehicle.cp.pipeIndex)
			vehicle.cp.pipePositions = {  
							rot = rotation ;
							trans = translation;
							}
			break;
		end
	end
end		

function courseplay:handleSugarCaneTrailer(vehicle, allowedToDrive, dt)
	
	-- Ensure we are starting with a trailer to fill
	if vehicle.cp.currentTrailerToFill == nil then
		vehicle.cp.currentTrailerToFill = 1
	end

	--Select the trailer to fill
	local currentTipper = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill]
	local tipState = currentTipper.tipState
	fillLevelPct = vehicle.cp.totalFillLevelPercent

	-- Reset found trailer and look for a new one
	if (tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING) and fillLevelPct > 0 then
		currentTipper.trailerFound = nil
		--the distance is 2.3m because if the trailer is further away, it will tip to the ground as well
		local x,y,z = localToWorld(currentTipper.shovelTipReferenceNode,0,-2.3,0); 
		raycastAll(x, y, z, 0, -1, 0, "findTrailerRaycastCallback", currentTipper.shovelTipRaycastDistance, currentTipper);
		if courseplay.debugChannels[15] then
			local nx, ny, nz = localDirectionToWorld(currentTipper.shovelTipReferenceNode, 0, 0, -1)
			local dist =  currentTipper.shovelTipRaycastDistance 
			drawDebugLine(x,y,z, 1, 0, 0, x+(nx*dist),y+(ny*dist),z+(nz*dist), 1, 0, 0);
		end
	end

	local tipperX,_,tipperZ = getWorldTranslation(currentTipper.rootNode);
	local targetWaypoint = vehicle.Waypoints[vehicle.cp.waitPoints[1]]
	local unloadDistance = courseplay:distance(tipperX, tipperZ, targetWaypoint.cx, targetWaypoint.cz)

	local atWaitPoint = unloadDistance < 1
	local trailerFound = currentTipper.trailerFound ~= nil									
	local trailerFull = currentTipper.trailerFound and currentTipper.trailerFound:getFillLevel() >= currentTipper.trailerFound:getCapacity()
	local driveOn = false

	courseplay.debugVehicle(15,vehicle,'trailerFound=%s trailerFull=%s, unloadDistance=%.2f',tostring(trailerFound),tostring(trailerFull),unloadDistance)

	-- Ensure we don't drive when the tipper is unfolded
	if tipState ~= Trailer.TIPSTATE_CLOSED then
		allowedToDrive = false
	end

	if vehicle.cp.isUnloaded == false then
		if  currentTipper.cp.fillLevelPercent == 0 then
			-- Current Tipper is empty check to see if there is another and if so move onto that one
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
				courseplay:handleAugerWagon(vehicle, currentTipper, false, false, "stopUnload",dt)
				-- Wait unitl the tipper is closed before moveing to the next trailer
				if tipState == Trailer.TIPSTATE_CLOSED then
					vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1
					currentTipper.cp.isSugarCaneUnloading = nil
					currentTipper.cp.prevFillLevelPct = nil
				end
			else
			--No more trailers are aviable driveOn
			driveOn = true;
			end
		-- Trailer we are unloading into is filled up. Stop until another trailer comes into range
		elseif currentTipper.cp.isSugarCaneUnloading == true and (not trailerFound or trailerFull) then
			courseplay:handleAugerWagon(vehicle, currentTipper, false, false, "stopUnload",dt)
			allowedToDrive = false
			if vehicle.cp.prevFillLevelPct ~= nil then
				if fillLevelPct > 0 and tipState == Trailer.TIPSTATE_CLOSING then
					courseplay:setCustomTimer(vehicle, "fillLevelChange", 10);
				elseif fillLevelPct == vehicle.cp.prevFillLevelPct and fillLevelPct < vehicle.cp.followAtFillLevel and courseplay:timerIsThrough(vehicle, "fillLevelChange", false) then
					driveOn = true-- drive on if fillLevelPct doesn't change for 10 seconds and fill level is < required_fillLevelPct_for_follow
					courseplay:debug('        no fillLevel change for 10 seconds -> driveOn', 15);
				end;
			end;

			vehicle.cp.prevFillLevelPct = fillLevelPct;
		-- We found a trailer to unload into STOP driving
		elseif atWaitPoint then
			allowedToDrive = false
			if trailerFound then
				courseplay:handleAugerWagon(vehicle, currentTipper, true, true, "unload",dt)
				currentTipper.cp.isSugarCaneUnloading = true
			end
		end;
	end
	if driveOn or vehicle.cp.isUnloaded == true then
		-- If the tipper is in unloading state close it
		if tipState ~= Trailer.TIPSTATE_CLOSED then
			courseplay:handleAugerWagon(vehicle, currentTipper, false, false, "stopUnload",dt)

		-- Everything is buttoned up drive on
		elseif tipState == Trailer.TIPSTATE_CLOSED then
			vehicle.cp.prevFillLevelPct = nil
			currentTipper.cp.isSugarCaneUnloading = nil
			vehicle.cp.isMode3Unloading = false
			vehicle.cp.currentTrailerToFill = nil
			vehicle.cp.isUnloaded = true
			currentTipper.trailerFound = nil
		end;
	end

	return allowedToDrive
end