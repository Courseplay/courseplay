local curFile = 'recording.lua';
local abs, atan2, ceil, deg, rad = math.abs, math.atan2, math.ceil, math.deg, math.rad;

-- records waypoints for course
function courseplay:record(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.DirectionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	if vehicle.recordnumber < 2 then
		vehicle.rotatedTime = 0

	elseif not vehicle.cp.isRecordingTurnManeuver then
		local prevPoint = vehicle.Waypoints[vehicle.recordnumber - 1];
		local prevCx, prevCz, prevAngle = prevPoint.cx, prevPoint.cz, prevPoint.angle;
		local dist = courseplay:distance(cx, cz, prevCx, prevCz);

		if vehicle.recordnumber <= 3 then
			vehicle.cp.recordingTimer = dist > (vehicle.recordnumber == 3 and 20 or 10) and 101 or 1;

		else
			local angleDiff = abs(newAngle - prevAngle);

			if vehicle.cp.drivingDirReverse == true then
				if dist > 2 and (angleDiff > 1.5 or dist > 10) then
					vehicle.cp.recordingTimer = 101;
				end;
			else
				if dist > 5 and (angleDiff > 5 or dist > 10) then
					vehicle.cp.recordingTimer = 101;
				end;
			end;
		end;
	end;
	vehicle.cp.curSpeed = ceil(vehicle.lastSpeedReal*3600)

	if vehicle.cp.recordingTimer > 100 then
		local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
		local crossing = courseplay:trueOrNil(vehicle.recordnumber == 1);
		courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, nil, rev, crossing, vehicle.cp.curSpeed);
		local signType = vehicle.recordnumber == 1 and "start" or nil;
		courseplay.signs:addSign(vehicle, signType, cx, cz, nil, newAngle);
		vehicle.cp.recordingTimer = 1;
		courseplay:setRecordNumber(vehicle, vehicle.recordnumber + 1);
	end;
end;

function courseplay:set_waitpoint(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.DirectionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait = true;
	local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
	local crossing = nil;
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait, rev, crossing, 0);
	vehicle.cp.recordingTimer = 1
	courseplay:setRecordNumber(vehicle, vehicle.recordnumber + 1);
	vehicle.cp.numWaitPoints = vehicle.cp.numWaitPoints + 1;
	courseplay.signs:addSign(vehicle, 'wait', cx, cz, nil, newAngle);
end


function courseplay:set_crossing(vehicle, stop)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.DirectionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait = nil;
	local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
	local crossing = true;
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait, rev, crossing, vehicle.cp.curSpeed);
	vehicle.cp.recordingTimer = 1
	courseplay:setRecordNumber(vehicle, vehicle.recordnumber + 1);
	vehicle.cp.numCrossingPoints = vehicle.cp.numCrossingPoints + 1
	if stop ~= nil then
		courseplay.signs:addSign(vehicle, 'stop', cx, cz, nil, newAngle);
	else
		courseplay.signs:addSign(vehicle, 'cross', cx, cz, nil, newAngle);
		courseplay.signs:addSign(vehicle, 'normal', cx, cz, nil, newAngle);
	end
end

-- starts course recording -- just setting variables
function courseplay:start_record(vehicle)
	--    courseplay:clearCurrentLoadedCourse(vehicle)
	courseplay:setIsRecording(vehicle, true);
	courseplay:setRecordingIsPaused(vehicle, false);
	vehicle:setIsCourseplayDriving(false);
	vehicle.cp.loadedCourses = {}
	courseplay:setRecordNumber(vehicle, 1);
	vehicle.cp.HUDrecordnumber = 1;
	vehicle.cp.numWaitPoints = 0;
	vehicle.cp.numCrossingPoints = 0;
	vehicle.cp.recordingTimer = 101;
	vehicle.cp.drivingDirReverse = false;

	courseplay.utils:hasVarChanged(vehicle, 'HUDrecordnumber');
	courseplay.signs:updateWaypointSigns(vehicle, "current");
	courseplay:validateCanSwitchMode(vehicle);
	courseplay:buttonsActiveEnabled(vehicle, 'recording');
end

-- stops course recording -- just setting variables
function courseplay:stop_record(vehicle)
	courseplay:set_crossing(vehicle, true);
	courseplay:setIsRecording(vehicle, false);
	courseplay:setRecordingIsPaused(vehicle, false);
	vehicle:setIsCourseplayDriving(false);
	vehicle.cp.distanceCheck = false;
	vehicle.cp.canDrive = true;
	vehicle.maxnumber = vehicle.recordnumber - 1;
	courseplay:setRecordNumber(vehicle, 1);
	vehicle.cp.numCourses = 1;

	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);
	courseplay.signs:updateWaypointSigns(vehicle);
	courseplay:buttonsActiveEnabled(vehicle, 'recording');
end

function courseplay:setRecordingPause(vehicle)
	if vehicle.recordnumber > 3 then
		courseplay:setIsRecording(vehicle, not vehicle.cp.isRecording);
		courseplay:setRecordingIsPaused(vehicle, not vehicle.cp.recordingIsPaused);
		if vehicle.cp.recordingIsPaused then
			vehicle.cp.hud.recordingPauseButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_PAUSE_RESUME'));
		else
			vehicle.cp.hud.recordingPauseButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_PAUSE'));
		end;

		vehicle.cp.distanceCheck = vehicle.cp.recordingIsPaused;

		local oldSignIndex = #vehicle.cp.signs.current;
		local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
		local newSignType = vehicle.cp.recordingIsPaused and 'stop' or 'normal'; --change last sign to "stop"/"normal"
		courseplay.signs:changeSignType(vehicle, oldSignIndex, oldSignType, newSignType);

		courseplay:validateCanSwitchMode(vehicle);
		courseplay:buttonsActiveEnabled(vehicle, 'recording');
	end;
end;

function courseplay:setRecordingTurnManeuver(vehicle)
	vehicle.cp.isRecordingTurnManeuver = not vehicle.cp.isRecordingTurnManeuver;
	if vehicle.cp.isRecordingTurnManeuver then
		vehicle.cp.hud.recordingTurnManeuverButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_TURN_END'));
	else
		vehicle.cp.hud.recordingTurnManeuverButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_TURN_START'));
	end;
	courseplay:debug(string.format('%s: set "isRecordingTurnManeuver" to %s', nameNum(vehicle), tostring(vehicle.cp.isRecordingTurnManeuver)), 16);

	local cx, cy, cz = getWorldTranslation(vehicle.cp.DirectionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait, rev, crossing = nil, nil, nil;
	if vehicle.cp.isRecordingTurnManeuver then
		courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait, rev, crossing, vehicle.cp.curSpeed, "noDirection", true, nil);
	else
		local preTurnStartPoint = vehicle.Waypoints[vehicle.recordnumber - 2];
		local turnStartPoint = vehicle.Waypoints[vehicle.recordnumber - 1];

		local vx1,vz1 = turnStartPoint.cx - preTurnStartPoint.cx, turnStartPoint.cz - preTurnStartPoint.cz;
		local vx2,vz2 = cx - turnStartPoint.cx, cz - turnStartPoint.cz;
		local vx3,vz3 = cx - preTurnStartPoint.cx, cz - preTurnStartPoint.cz;
		local vl1,vl2,vl3 = Utils.vector2Length(vx1,vz1), Utils.vector2Length(vx2,vz2), Utils.vector2Length(vx3,vz3);
		local dir1X, dir1Z = vx1/vl1, vz1/vl1;
		local dir2X, dir2Z = vx2/vl2, vz2/vl2;

		--local relativeDirX = (dir1Z * dir2X) - (dir1X * dir2Z); --usually: z: upwards positive, downwards negative
		local relativeDirX =  (dir1X * dir2Z) - (dir1Z * dir2X); --GIANTS: z: downwards positive, upwards negative --> inverse calcuation
		local turnDirStr = 'noDirection';
		if relativeDirX > 0 then
			turnDirStr = 'right';
		elseif relativeDirX < 0 then
			turnDirStr = 'left';
		end;

		local minUpVerticalHypotenuse = Utils.vector2Length(vl1, vl2);
		local turnVerticalDirStr = 'level';
		if vl3 > minUpVerticalHypotenuse then
			turnVerticalDirStr = 'up';
		else
			turnVerticalDirStr = 'down';
		end;

		vehicle.Waypoints[vehicle.recordnumber - 1].turn = turnDirStr; --set turnStart point's turn direction
		if courseplay.debugChannels[16] then
			local printStr = '';
			printStr = printStr .. string.format('\tvx1,vz1=%.2f,%.2f\n', vx1,vz1);
			printStr = printStr .. string.format('\tvx2,vz2=%.2f,%.2f\n', vx2,vz2);
			printStr = printStr .. string.format('\tvl1,vl2=%.2f,%.2f\n', vl1,vl2);
			printStr = printStr .. string.format('\tdir1X,dir1Z=%.3f,%.3f\n', dir1X,dir1Z);
			printStr = printStr .. string.format('\tdir2X,dir2Z=%.3f,%.3f\n', dir2X,dir2Z);
			printStr = printStr .. string.format('\trelativeDirX=%.3f -> turnDirStr=%q, turnVerticalDirStr=%q', relativeDirX, turnDirStr, turnVerticalDirStr);
			print(printStr);
		end;

		courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait, rev, crossing, vehicle.cp.curSpeed, nil, nil, true);
	end;

	vehicle.cp.recordingTimer = 1
	courseplay:setRecordNumber(vehicle, vehicle.recordnumber + 1);
	courseplay.signs:addSign(vehicle, 'normal', cx, cz, nil, newAngle);
	courseplay:buttonsActiveEnabled(vehicle, 'recording');
end;

-- set Waypoint before change direction
function courseplay:change_DriveDirection(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.DirectionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait, crossing = nil, nil;
	local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait, rev, crossing, 0);
	vehicle.cp.drivingDirReverse = not vehicle.cp.drivingDirReverse
	if vehicle.cp.drivingDirReverse then
		vehicle.cp.hud.recordingDriveDirectionButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_REVERSE_STOP'));
	else
		vehicle.cp.hud.recordingDriveDirectionButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_REVERSE_START'));
	end;
	vehicle.cp.recordingTimer = 1
	courseplay:setRecordNumber(vehicle, vehicle.recordnumber + 1);
	courseplay.signs:addSign(vehicle, 'normal', cx, cz, nil, newAngle);
	courseplay:buttonsActiveEnabled(vehicle, 'recording');
end

-- delete last waypoint
function courseplay:delete_waypoint(vehicle)
	if vehicle.recordnumber > 3 then
		courseplay:setRecordNumber(vehicle, vehicle.recordnumber - 1);
		vehicle.cp.recordingTimer = 1;

		--delete last sign
		local lastSignIndex = #vehicle.cp.signs.current;
		courseplay.signs:moveToBuffer(vehicle, lastSignIndex, vehicle.cp.signs.current[lastSignIndex])

		--change new last sign to "stop"
		local oldSignIndex = lastSignIndex - 1;
		local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
		courseplay.signs:changeSignType(vehicle, oldSignIndex, oldSignType, "stop");

		vehicle.Waypoints[vehicle.recordnumber] = nil
	end;
	courseplay:buttonsActiveEnabled(vehicle, 'recording');
end;

-- clears current course -- just setting variables
function courseplay:clearCurrentLoadedCourse(vehicle)
	courseplay.courses:resetMerged();
	courseplay:setRecordNumber(vehicle, 1);
	vehicle.cp.curTarget.x, vehicle.cp.curTarget.y, vehicle.cp.curTarget.z = nil, nil, nil;
	vehicle.cp.nextTargets = {};
	if vehicle.cp.activeCombine ~= nil then
		courseplay:unregisterFromCombine(vehicle, vehicle.cp.activeCombine)
	end
	vehicle.cp.loadedCourses = {}
	vehicle.cp.currentCourseName = nil
	courseplay:setModeState(vehicle, 1);
	-- print(('%s [%s(%d)]: clearCurrentLoadedCourse() -> set modeState to 1'):format(nameNum(vehicle), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
	if vehicle.cp.mode == 2 or vehicle.cp.mode == 3 then
		courseplay:setModeState(vehicle, 0);
		-- print(('%s [%s(%d)]: clearCurrentLoadedCourse(): mode=%d -> set modeState to 0'):format(nameNum(vehicle), curFile, debug.getinfo(1).currentline, vehicle.cp.mode)); -- DEBUG140301
	end;
	vehicle.cp.recordingTimer = 1
	vehicle.Waypoints = {}
	vehicle.cp.canDrive = false
	vehicle.cp.abortWork = nil
	courseplay:resetTipTrigger(vehicle);
	vehicle.cp.lastMergedWP = 1;
	vehicle.cp.numCourses = 0;
	vehicle.cp.numWaypoints = 0;
	vehicle.cp.numWaitPoints = 0;
	vehicle.cp.waitPoints = {};

	vehicle.cp.hasGeneratedCourse = false;
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);

	courseplay.signs:updateWaypointSigns(vehicle, "current");
end

function courseplay:currentVehAngle(vehicle)
	local x, y, z = localDirectionToWorld(vehicle.cp.DirectionNode, 0, 0, 1);
	local length = Utils.vector2Length(x, z);
	local dx, dz = x/length, z/length;
	local angleRad = Utils.getYRotationFromDirection(dx, dz);
	local angleDeg = deg(angleRad);
	return angleDeg, angleRad;
end;

function courseplay:setIsRecording(vehicle, isRecording)
	if vehicle.cp.isRecording ~= isRecording then
		vehicle.cp.isRecording = isRecording;
	end;
end;

function courseplay:setRecordingIsPaused(vehicle, pause)
	if vehicle.cp.recordingIsPaused ~= pause then
		vehicle.cp.recordingIsPaused = pause;
	end;
end;

function courseplay:setNewWaypointFromRecording(vehicle, cx, cz, angle, wait, rev, crossing, speed, turn, turnStart, turnEnd)
	vehicle.Waypoints[vehicle.recordnumber] = { cx = cx, cz = cz, angle = angle, wait = wait, rev = rev, crossing = crossing, speed = speed, turn = turn, turnStart = turnStart, turnEnd = turnEnd };
	courseplay:debug(string.format('%s: recording: set new waypoint (#%d): cx,cz=%.1f,%.1f, angle=%.1f, wait=%s, rev=%s, crossing=%s, speed=%.5f, turn=%s, turnStart=%s, turnEnd=%s', nameNum(vehicle), vehicle.recordnumber, cx, cz, angle, tostring(wait), tostring(rev), tostring(crossing), speed, tostring(turn), tostring(turnStart), tostring(turnEnd)), 16);
end;

