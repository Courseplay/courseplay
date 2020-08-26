local curFile = 'recording.lua';
local abs, atan2, ceil, deg, floor, rad = math.abs, math.atan2, math.ceil, math.deg, math.floor, math.rad;

-- records waypoints for course
function courseplay:record(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.directionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	if vehicle.cp.lastValidTipDistance ~= nil then
		vehicle.cp.lastValidTipDistance = nil
	end
	
	if vehicle.cp.waypointIndex < 2 then
		vehicle.rotatedTime = 0

	elseif not vehicle.cp.isRecordingTurnManeuver then
		local prevPoint = vehicle.Waypoints[vehicle.cp.waypointIndex - 1];
		local prevCx, prevCz, prevAngle = prevPoint.cx, prevPoint.cz, prevPoint.angle;
		local dist = courseplay:distance(cx, cz, prevCx, prevCz);

		local angleDiff = abs(newAngle - prevAngle);

		if vehicle.cp.drivingDirReverse == true then
			if dist > 2 and (angleDiff > 1.5 or dist > 10) then
				vehicle.cp.recordingTimer = 101;
			end;
		else
			-- record more waypoints during turns
			if dist > 10 or ( angleDiff > 5 and dist > 1.5 ) then
				vehicle.cp.recordingTimer = 101;
			end
		end;
	end;
	vehicle.cp.curSpeed = ceil(vehicle.lastSpeedReal*3600)
	if vehicle.cp.recordingTimer > 100 then
		local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
		local crossing = courseplay:trueOrNil(vehicle.cp.waypointIndex == 1);
		courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, nil,nil, rev, crossing, vehicle.cp.curSpeed);
		local signType = vehicle.cp.waypointIndex == 1 and "start" or nil;
		courseplay.signs:addSign(vehicle, signType, cx, cz, nil, newAngle, nil, nil, 'regular');
		vehicle.cp.recordingTimer = 1;
		courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
	end;
end;

function courseplay:set_waitpoint(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.directionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait = true;
	local unload;
	local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
	local crossing;
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait,unload, rev, crossing, 0);
	vehicle.cp.recordingTimer = 1;
	courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
	vehicle.cp.numWaitPoints = vehicle.cp.numWaitPoints + 1;
	courseplay.signs:addSign(vehicle, 'wait', cx, cz, nil, newAngle, nil, nil, 'regular');
end

function courseplay:set_unloadPoint(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.directionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait;
	local unload = true;
	local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
	local crossing;
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait,unload , rev, crossing, 0);
	vehicle.cp.recordingTimer = 1;
	courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
	courseplay.signs:addSign(vehicle, 'unload', cx, cz, nil, newAngle, nil, nil, 'regular');

end

function courseplay:set_crossing(vehicle, stop)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.directionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait;
	local unload;
	local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
	local crossing = true;
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait,unload, rev, crossing, vehicle.cp.curSpeed);
	vehicle.cp.recordingTimer = 1;
	courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
	vehicle.cp.numCrossingPoints = vehicle.cp.numCrossingPoints + 1
	if stop ~= nil then
		courseplay.signs:addSign(vehicle, 'stop', cx, cz, nil, newAngle, nil, nil, 'regular');
	else
		courseplay.signs:addSign(vehicle, 'cross', cx, cz, nil, newAngle);
		courseplay.signs:addSign(vehicle, 'normal', cx, cz, nil, newAngle, nil, nil, 'regular');
	end
end

-- starts course recording -- just setting variables
function courseplay:start_record(vehicle)
	--    courseplay:clearCurrentLoadedCourse(vehicle)
	courseplay:setIsRecording(vehicle, true);
	courseplay:setRecordingIsPaused(vehicle, false);
	--probably not needed as courseplay:stop called it already!!
--	vehicle:setIsCourseplayDriving(false);
	vehicle.cp.loadedCourses = {}
	courseplay:setWaypointIndex(vehicle, 1,true);
	vehicle.cp.numWaitPoints = 0;
	vehicle.cp.numCrossingPoints = 0;
	vehicle.cp.recordingTimer = 101;
	vehicle.cp.drivingDirReverse = false;

	courseplay.signs:updateWaypointSigns(vehicle, "current");
	courseplay:validateCanSwitchMode(vehicle);
	--courseplay.buttons:setActiveEnabled(vehicle, 'recording');
end

-- stops course recording -- just setting variables
function courseplay:stop_record(vehicle)
	courseplay:set_crossing(vehicle, true);
	courseplay:setIsRecording(vehicle, false);
	courseplay:setRecordingIsPaused(vehicle, false);
	--probably not needed as courseplay:stop called it already!!
--	vehicle:setIsCourseplayDriving(false);
	vehicle:setCpVar('distanceCheck',false,courseplay.isClient);
	vehicle:setCpVar('canDrive',true,courseplay.isClient);
	vehicle.cp.numWaypoints = vehicle.cp.waypointIndex - 1;
	courseplay:setWaypointIndex(vehicle, 1,true);
	vehicle.cp.numCourses = 1;

	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);
	courseplay.signs:updateWaypointSigns(vehicle);
	--courseplay.buttons:setActiveEnabled(vehicle, 'recording');

	-- SETUP 2D COURSE DRAW DATA
	vehicle.cp.course2dUpdateDrawData = true;
	
	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true)
end;

function courseplay:setRecordingPause(vehicle)
	if vehicle.cp.waypointIndex > 3 then
		courseplay:setIsRecording(vehicle, not vehicle.cp.isRecording);
		courseplay:setRecordingIsPaused(vehicle, not vehicle.cp.recordingIsPaused);
		if vehicle.cp.recordingIsPaused then
			vehicle.cp.hud.recordingPauseButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_PAUSE_RESUME'));
		else
			vehicle.cp.hud.recordingPauseButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_PAUSE'));
		end;

		vehicle:setCpVar('distanceCheck',vehicle.cp.recordingIsPaused,courseplay.isClient);

		local oldSignIndex = #vehicle.cp.signs.current;
		local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
		local newSignType = vehicle.cp.recordingIsPaused and 'stop' or 'normal'; --change last sign to "stop"/"normal"
		courseplay.signs:changeSignType(vehicle, oldSignIndex, oldSignType, newSignType);

		courseplay:validateCanSwitchMode(vehicle);
		--courseplay.buttons:setActiveEnabled(vehicle, 'recording');
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

	local cx, cy, cz = getWorldTranslation(vehicle.cp.directionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait,unload, rev, crossing;
	if vehicle.cp.isRecordingTurnManeuver then
		courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait,unload, rev, crossing, vehicle.cp.curSpeed, true, nil);
	else
		local preTurnStartPoint = vehicle.Waypoints[vehicle.cp.waypointIndex - 2];
		local turnStartPoint = vehicle.Waypoints[vehicle.cp.waypointIndex - 1];

		local vx1,vz1 = turnStartPoint.cx - preTurnStartPoint.cx, turnStartPoint.cz - preTurnStartPoint.cz;
		local vx2,vz2 = cx - turnStartPoint.cx, cz - turnStartPoint.cz;
		local vx3,vz3 = cx - preTurnStartPoint.cx, cz - preTurnStartPoint.cz;
		local vl1,vl2,vl3 = MathUtil.vector2Length(vx1,vz1), MathUtil.vector2Length(vx2,vz2), MathUtil.vector2Length(vx3,vz3);
		local dir1X, dir1Z = vx1/vl1, vz1/vl1;
		local dir2X, dir2Z = vx2/vl2, vz2/vl2;

		--local relativeDirX = (dir1Z * dir2X) - (dir1X * dir2Z); --usually: z: upwards positive, downwards negative
		local relativeDirX =  (dir1X * dir2Z) - (dir1Z * dir2X); --GIANTS: z: downwards positive, upwards negative --> inverse calcuation

		local minUpVerticalHypotenuse = MathUtil.vector2Length(vl1, vl2);
		local turnVerticalDirStr = 'level';
		if vl3 > minUpVerticalHypotenuse then
			turnVerticalDirStr = 'up';
		else
			turnVerticalDirStr = 'down';
		end;

		if courseplay.debugChannels[16] then
			local printStr = '';
			printStr = printStr .. string.format('\tvx1,vz1=%.2f,%.2f\n', vx1,vz1);
			printStr = printStr .. string.format('\tvx2,vz2=%.2f,%.2f\n', vx2,vz2);
			printStr = printStr .. string.format('\tvl1,vl2=%.2f,%.2f\n', vl1,vl2);
			printStr = printStr .. string.format('\tdir1X,dir1Z=%.3f,%.3f\n', dir1X,dir1Z);
			printStr = printStr .. string.format('\tdir2X,dir2Z=%.3f,%.3f\n', dir2X,dir2Z);
			printStr = printStr .. string.format('\trelativeDirX=%.3f -> turnVerticalDirStr=%q', relativeDirX, turnVerticalDirStr);
			print(printStr);
		end;

		courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait,unload, rev, crossing, vehicle.cp.curSpeed, nil, true);
	end;

	vehicle.cp.recordingTimer = 1;
	courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
	local diamondColor = vehicle.cp.isRecordingTurnManeuver and 'turnStart' or 'turnEnd';
	courseplay.signs:addSign(vehicle, 'normal', cx, cz, nil, newAngle, nil, nil, diamondColor);
	--courseplay.buttons:setActiveEnabled(vehicle, 'recording');
end;

-- set Waypoint before change direction
function courseplay:change_DriveDirection(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.directionNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	local wait,unload, crossing;
	local rev = courseplay:trueOrNil(vehicle.cp.drivingDirReverse);
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, wait,unload, rev, crossing, 0);
	vehicle.cp.drivingDirReverse = not vehicle.cp.drivingDirReverse
	if vehicle.cp.drivingDirReverse then
		vehicle.cp.hud.recordingDriveDirectionButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_REVERSE_STOP'));
	else
		vehicle.cp.hud.recordingDriveDirectionButton:setToolTip(courseplay:loc('COURSEPLAY_RECORDING_REVERSE_START'));
	end;
	vehicle.cp.recordingTimer = 1;
	courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
	courseplay.signs:addSign(vehicle, 'normal', cx, cz, nil, newAngle, nil, nil, 'regular');
	--courseplay.buttons:setActiveEnabled(vehicle, 'recording');
end

-- delete last waypoint
function courseplay:delete_waypoint(vehicle)
	if vehicle.cp.waypointIndex > 3 then
		courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex - 1,true);
		vehicle.cp.recordingTimer = 1;

		--delete last sign
		local lastSignIndex = #vehicle.cp.signs.current;
		courseplay.signs:moveToBuffer(vehicle, lastSignIndex, vehicle.cp.signs.current[lastSignIndex])

		--change new last sign to "stop"
		local oldSignIndex = lastSignIndex - 1;
		local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
		courseplay.signs:changeSignType(vehicle, oldSignIndex, oldSignType, "stop");
		vehicle.Waypoints[vehicle.cp.waypointIndex] = nil
		vehicle.cp.numWaypoints = vehicle.cp.waypointIndex;
	end;
	--courseplay.buttons:setActiveEnabled(vehicle, 'recording');
end;

function courseplay:currentVehAngle(vehicle)
	local x, y, z = localDirectionToWorld(vehicle.cp.directionNode, 0, 0, 1);
	local length = MathUtil.vector2Length(x, z);
	local dx, dz = x/length, z/length;
	local angleRad = MathUtil.getYRotationFromDirection(dx, dz);
	local angleDeg = deg(angleRad);
	return angleDeg, angleRad;
end;

function courseplay:setIsRecording(vehicle, isRecording)
	if vehicle.cp.isRecording ~= isRecording then
		vehicle.cp.isRecording = isRecording
		--vehicle:setCpVar('isRecording',isRecording,courseplay.isClient);
	end;
end;

function courseplay:setRecordingIsPaused(vehicle, pause)
	if vehicle.cp.recordingIsPaused ~= pause then
		vehicle.cp.recordingIsPaused = pause;
	end;
end;

function courseplay:setNewWaypointFromRecording(vehicle, cx, cz, angle, wait,unload, rev, crossing, speed, turnStart, turnEnd)
	vehicle.Waypoints[vehicle.cp.waypointIndex] = { cx = cx, cz = cz, angle = angle, wait = wait,unload = unload, rev = rev, crossing = crossing, speed = speed, turnStart = turnStart, turnEnd = turnEnd };
	courseplay:debug(string.format('%s: recording: set new waypoint (#%d): cx,cz=%.1f,%.1f, angle=%.1f, wait=%s, rev=%s, crossing=%s, speed=%.5f, turnStart=%s, turnEnd=%s', nameNum(vehicle), vehicle.cp.waypointIndex, cx, cz, angle, tostring(wait), tostring(rev), tostring(crossing), speed, tostring(turnStart), tostring(turnEnd)), 16);
	vehicle.cp.numWayPoints = vehicle.cp.waypointIndex
	courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true)
end;

function courseplay:addSplitRecordingPoints(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.cp.directionNode);
	local prevPoint = vehicle.Waypoints[vehicle.cp.waypointIndex - 1];
	local prevCx, prevCz = prevPoint.cx, prevPoint.cz;
	local dist = courseplay:distance(cx, cz, prevCx, prevCz);
	local numPointsNeeded = ceil(dist / 5) - 1;
	local dx, dz = (cx - prevCx) / dist, (cz - prevCz) / dist;
	local angle = deg(MathUtil.getYRotationFromDirection(dx, dz));
	local speed = prevPoint.speed;
	courseplay:debug(('%s: addSplitRecordingPoints: dist=%.1f, numPointsNeeded=%d, angle=%.1f, speed=%.1f'):format(nameNum(vehicle), dist, numPointsNeeded, angle, speed), 16);

	-- change previous point sign from 'stop' to 'normal'
	local oldSignIndex = #vehicle.cp.signs.current;
	local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
	local newSignType = 'normal';
	courseplay.signs:changeSignType(vehicle, oldSignIndex, oldSignType, newSignType);


	if numPointsNeeded > 0 then
		local x, z;
		for i=1, numPointsNeeded do
			x = prevCx + (i * 5 * dx);
			z = prevCz + (i * 5 * dz);

			courseplay:setNewWaypointFromRecording(vehicle, x, z, angle, nil,nil, nil, nil,     speed);
			courseplay.signs:addSign(vehicle, nil, x, z, nil, angle, nil, nil, 'regular');
			courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
		end;
	end;

	-- add current position as last new point
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, angle, nil,nil, nil, nil,     speed);
	courseplay.signs:addSign(vehicle, 'stop', cx, cz, nil, angle);
	vehicle.cp.recordingTimer = 1;
	courseplay:setWaypointIndex(vehicle, vehicle.cp.waypointIndex + 1,true);
	--courseplay.buttons:setActiveEnabled(vehicle, 'recording');
end;
-- do not remove this comment
-- vim: set noexpandtab:
