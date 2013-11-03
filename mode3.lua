function courseplay:handleMode3(vehicle, fill_level, allowedToDrive, dt)
	courseplay:debug(string.format("handleMode3(vehicle, fill_level=%s, allowedToDrive=%s, dt)", tostring(fill_level), tostring(allowedToDrive)), 15);
	local workTool = vehicle.tippers[vehicle.currentTrailerToFill] or vehicle.tippers[1];
	local backPointsUnfoldPipe = 8; --[[workTool.cp.backPointsUnfoldPipe or 8;]] --NOTE: backPointsUnfoldPipe must not be 0! 
	local forwardPointsFoldPipe = workTool.cp.forwardPointsFoldPipe or 2;
	workTool.cp.isUnloading = workTool.fillLevel < workTool.cp.lastFillLevel;

	if workTool.cp.isAugerWagon then
		if vehicle.wait and vehicle.cp.last_recordnumber >= math.max(vehicle.cp.waitPoints[1] - backPointsUnfoldPipe, 2) and vehicle.cp.last_recordnumber < vehicle.cp.waitPoints[1] and not workTool.cp.isUnloading then
			courseplay:handleAugerWagon(vehicle, workTool, true, false, "unfold"); --unfold=true, unload=false
		end;

		if vehicle.wait and vehicle.cp.last_recordnumber == vehicle.cp.waitPoints[1] then
			courseplay:setGlobalInfoText(vehicle, courseplay:get_locale(vehicle, "CPReachedOverloadPoint"));
			
			local driveOn = false
			if fill_level > 0 then
				courseplay:handleAugerWagon(vehicle, workTool, true, true, "unload"); --unfold=true, unload=true
			end;
			if vehicle.last_fill_level ~= nil then
				if fill_level > 0 and workTool.cp.isUnloading then
					courseplay:setCustomTimer(vehicle, "fillLevelChange", 7);
				elseif fill_level == vehicle.last_fill_level and fill_level < vehicle.required_fill_level_for_follow and courseplay:timerIsThrough(vehicle, "fillLevelChange", false) then
					driveOn = true; -- drive on if fill_level doesn't change for 7 seconds and fill level is < required_fill_level_for_follow
				end;
			end;

			vehicle.last_fill_level = fill_level;

			if (fill_level == 0 or driveOn) and not workTool.cp.isUnloading then
				courseplay:handleAugerWagon(vehicle, workTool, true, false, "stopUnload"); --unfold=true, unload=false
				vehicle.wait = false;
				vehicle.last_fill_level = nil;
				vehicle.unloaded = true;
			end;
		end;

		if (not vehicle.wait or vehicle.unloaded) and vehicle.cp.last_recordnumber >= math.min(vehicle.cp.waitPoints[1] + forwardPointsFoldPipe, vehicle.maxnumber - 1) then
			courseplay:handleAugerWagon(vehicle, workTool, false, false, "fold"); --unfold=false, unload=false
		end;
	end;

	workTool.cp.lastFillLevel = workTool.fillLevel;
end;



function courseplay:handleAugerWagon(vehicle, workTool, unfold, unload, orderName)
	courseplay:debug(string.format("\thandleAugerWagon(vehicle, %s, unfold=%s, unload=%s, orderName=%s)", nameNum(workTool), tostring(unfold), tostring(unload), tostring(orderName)), 15);

	--Taarup Shuttle
	if workTool.cp.isTaarupShuttle then
		if unfold and workTool.animationParts[1].clipStartTime then
			workTool:setAnimationTime(1, workTool.animationParts[1].animDuration, false);
		elseif not unfold and workTool.animationParts[1].clipEndTime then
			workTool:setAnimationTime(1, workTool.animationParts[1].offSet, false);
		end;

		if (unload and workTool.unloadingState ~= 1) or (not unload and workTool.unloadingState ~= 0) then
			workTool:setUnloadingState(unload);
		end;

	--Overcharge / AgrolinerTUW20 / Hawe SUW 5000
	elseif workTool.cp.hasSpecializationOvercharge or workTool.cp.hasSpecializationAgrolinerTUW20 or workTool.cp.isHaweSUW5000 then
		if unfold and not workTool.pipe.out then
			workTool:setAnimationTime(1, workTool.animationParts[1].animDuration, false);
		elseif not unfold and workTool.pipe.out then
			workTool:setAnimationTime(1, workTool.animationParts[1].offSet, false);
		end;

		if unload and not workTool.isUnloading and workTool.trailerFoundId ~= 0 then
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

	--Brent Avalanche
	elseif workTool.cp.isBrentAvalanche then
		-- n/a in FS13

	--Overloader spec
	elseif workTool.cp.hasSpecializationOverloaderV2 then
		if (unfold and workTool.cpAI ~= "out") or (not unfold and workTool.cpAI ~= "in") then
			if unfold then
				workTool.cpAI = "out";
			else
				workTool.cpAI = "in";
			end;

			if workTool.pipeLight ~= nil and g_currentMission.environment.needsLights or (g_currentMission.environment.lastRainScale > 0.1 and g_currentMission.environment.timeSinceLastRain < 30) then
				setVisibility(workTool.pipeLight, unfold);
			end;
		end;
		local hasTrailer = workTool.trailerToOverload ~= nil;
		local trailerIsFull = hasTrailer and workTool.trailerToOverload.fillLevel and workTool.trailerToOverload.capacity and workTool.trailerToOverload.fillLevel >= workTool.trailerToOverload.capacity;

		if (unload and hasTrailer and not trailerIsFull and not workTool.isCharging) or (not unload and workTool.isCharging) then
			workTool.isCharging = unload;
		end;

	--AugerWagon spec
	elseif workTool.cp.hasSpecializationAugerWagon and workTool.foldAnimTime ~= nil and workTool.turnOnFoldDirection ~= nil then
		local pipeIsFolding = workTool.foldAnimTime > workTool.cp.lastFoldAnimTime;
		local pipeIsUnfolding = workTool.foldAnimTime < workTool.cp.lastFoldAnimTime;
		local pipeIsFolded = workTool.foldAnimTime == 1;
		local pipeIsUnfolded = workTool.foldAnimTime == 0;
		courseplay:debug(string.format("\t\t%s: foldAnimTime=%s, lastFoldAnimTime=%s", nameNum(workTool), tostring(workTool.foldAnimTime), tostring(workTool.cp.lastFoldAnimTime)), 15);
		courseplay:debug(string.format("\t\t%s: pipeIsFolding=%s, pipeIsUnfolding=%s, pipeIsFolded=%s, pipeIsUnfolded=%s", nameNum(workTool), tostring(pipeIsFolding), tostring(pipeIsUnfolding), tostring(pipeIsFolded), tostring(pipeIsUnfolded)), 15);
		if unfold and not pipeIsUnfolded and not pipeIsUnfolding then
			workTool:setFoldDirection(workTool.turnOnFoldDirection); -- -1
			courseplay:debug(string.format("\t\t\t%s: setFoldDirection(%s) (unfold)", nameNum(workTool), tostring(workTool.turnOnFoldDirection)), 15);
		elseif not unfold and not pipeIsFolded and not pipeIsFolding then
			workTool:setFoldDirection(workTool.turnOnFoldDirection * -1); -- 1
			courseplay:debug(string.format("\t\t\t%s: setFoldDirection(%s) (fold)", nameNum(workTool), tostring(workTool.turnOnFoldDirection * -1)), 15);
		end;
		workTool.cp.lastFoldAnimTime = workTool.foldAnimTime;
	end;
end;