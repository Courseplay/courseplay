-- records waypoints for course
function courseplay:record(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.rootNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	if vehicle.recordnumber < 2 then
		vehicle.rotatedTime = 0

	else
		local prevPoint = vehicle.Waypoints[vehicle.recordnumber - 1];
		local prevCx, prevCz, prevAngle = prevPoint.cx, prevPoint.cz, prevPoint.angle;
		local dist = courseplay:distance(cx, cz, prevCx, prevCz);

		if vehicle.recordnumber <= 3 then
			vehicle.cp.recordingTimer = dist > 10 and 101 or 1;

		else
			local angleDiff = math.abs(newAngle - prevAngle);

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

	if vehicle.cp.recordingTimer > 100 then
		courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, false, vehicle.cp.drivingDirReverse, vehicle.recordnumber == 1, vehicle.lastSpeedReal);
		local signType = vehicle.recordnumber == 1 and "start" or nil;
		courseplay:addSign(vehicle, cx, cz, newAngle, signType);
		vehicle.cp.recordingTimer = 1;
		vehicle.recordnumber = vehicle.recordnumber + 1;
	end;
end;

function courseplay:set_next_target(vehicle, x, z)
	local next_x, next_y, next_z = localToWorld(vehicle.rootNode, x, 0, z)
	local next_wp = { x = next_x, y = next_y, z = next_z }
	table.insert(vehicle.next_targets, next_wp)
end

function courseplay:set_waitpoint(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.rootNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, true, vehicle.cp.drivingDirReverse, false, 0);
	vehicle.cp.recordingTimer = 1
	vehicle.recordnumber = vehicle.recordnumber + 1;
	vehicle.cp.numWaitPoints = vehicle.cp.numWaitPoints + 1;
	courseplay:addSign(vehicle, cx, cz, newAngle, "wait");
end


function courseplay:set_crossing(vehicle, stop)
	local cx, cy, cz = getWorldTranslation(vehicle.rootNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, false, vehicle.cp.drivingDirReverse, true, vehicle.lastSpeedReal);
	vehicle.cp.recordingTimer = 1
	vehicle.recordnumber = vehicle.recordnumber + 1
	vehicle.cp.numCrossingPoints = vehicle.cp.numCrossingPoints + 1
	if stop ~= nil then
		courseplay:addSign(vehicle, cx, cz, newAngle, "stop");
	else
		courseplay:addSign(vehicle, cx, cz, newAngle, "cross");
		courseplay:addSign(vehicle, cx, cz, newAngle, "normal");
	end
end

-- set Waypoint before change direction
function courseplay:change_DriveDirection(vehicle)
	local cx, cy, cz = getWorldTranslation(vehicle.rootNode);
	local newAngle = courseplay:currentVehAngle(vehicle);
	courseplay:setNewWaypointFromRecording(vehicle, cx, cz, newAngle, false, vehicle.cp.drivingDirReverse, false, 0);
	vehicle.cp.drivingDirReverse = not vehicle.cp.drivingDirReverse
	vehicle.cp.recordingTimer = 1
	vehicle.recordnumber = vehicle.recordnumber + 1
	courseplay:addSign(vehicle, cx, cz, newAngle);
end

function courseplay:setNewWaypointFromRecording(vehicle, cx, cz, angle, wait, rev, crossing, speed)
	vehicle.Waypoints[vehicle.recordnumber] = { cx = cx, cz = cz, angle = angle, wait = wait, rev = rev, crossing = crossing, speed = speed };
	courseplay:debug(string.format('%s: recording: set new waypoint (#%d): cx,cz=%.1f,%.1f, angle=%.1f, wait=%s, rev=%s, crossing=%s, speed=%.5f', nameNum(vehicle), vehicle.recordnumber, cx, cz, angle, tostring(wait), tostring(rev), tostring(crossing), speed), 12);
end;

-- starts course recording -- just setting variables
function courseplay:start_record(vehicle)
	--    courseplay:reset_course(vehicle)
	vehicle.record = true
	vehicle.drive = false
	vehicle.cp.loadedCourses = {}
	vehicle.recordnumber = 1
	vehicle.cp.numWaitPoints = 0
	vehicle.cp.numCrossingPoints = 0
	vehicle.cp.recordingTimer = 101
	vehicle.cp.drivingDirReverse = false
	courseplay:updateWaypointSigns(vehicle, "current");
end

-- stops course recording -- just setting variables
function courseplay:stop_record(vehicle)
	courseplay:set_crossing(vehicle, true)
	vehicle.record = false
	vehicle.record_pause = false
	vehicle.drive = false
	vehicle.dcheck = false
	vehicle.cp.canDrive = true
	vehicle.maxnumber = vehicle.recordnumber - 1
	vehicle.recordnumber = 1
	vehicle.numCourses = 1;
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);
	courseplay:updateWaypointSigns(vehicle);
end

-- interrupts course recording -- just setting variables
function courseplay:interrupt_record(vehicle)
	if vehicle.recordnumber > 3 then
		vehicle.record_pause = true
		vehicle.record = false
		vehicle.dcheck = true

		--change last sign to "stop"
		local oldSignIndex = #vehicle.cp.signs.current;
		local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
		courseplay.utils.signs.changeSignType(vehicle, oldSignIndex, oldSignType, "stop");
	end
end

-- continues course recording -- just setting variables
function courseplay:continue_record(vehicle)
	vehicle.record_pause = false
	vehicle.record = true
	vehicle.dcheck = false

	--change last sign back to "normal"
	local oldSignIndex = #vehicle.cp.signs.current;
	local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
	courseplay.utils.signs.changeSignType(vehicle, oldSignIndex, oldSignType, "normal");
end;

-- delete last waypoint
function courseplay:delete_waypoint(vehicle)
	if vehicle.recordnumber > 3 then
		vehicle.recordnumber = vehicle.recordnumber - 1;
		vehicle.cp.recordingTimer = 1;

		--delete last sign
		local lastSignIndex = #vehicle.cp.signs.current;
		courseplay.utils.signs.moveToBuffer(vehicle, lastSignIndex, vehicle.cp.signs.current[lastSignIndex])

		--change new last sign to "stop"
		local oldSignIndex = lastSignIndex - 1;
		local oldSignType = vehicle.cp.signs.current[oldSignIndex].type;
		courseplay.utils.signs.changeSignType(vehicle, oldSignIndex, oldSignType, "stop");

		vehicle.Waypoints[vehicle.recordnumber] = nil
	end;
end;

-- resets current course -- just setting variables
function courseplay:reset_course(vehicle)
	courseplay:reset_merged(vehicle)
	vehicle.recordnumber = 1
	vehicle.target_x, vehicle.target_y, vehicle.target_z = nil, nil, nil
	if vehicle.cp.activeCombine ~= nil then
		courseplay:unregister_at_combine(vehicle, vehicle.cp.activeCombine)
	end
	vehicle.next_targets = {}
	vehicle.cp.loadedCourses = {}
	vehicle.cp.currentCourseName = nil
	--vehicle.cp.mode = 1
	vehicle.cp.modeState = 1
	vehicle.cp.recordingTimer = 1
	vehicle.Waypoints = {}
	vehicle.cp.canDrive = false
	vehicle.cp.abortWork = nil
	vehicle.createCourse = false
	vehicle.startlastload = 1
	vehicle.numCourses = 0;
	vehicle.cp.numWaitPoints = 0;
	vehicle.cp.waitPoints = {};

	vehicle.cp.hasGeneratedCourse = false;
	courseplay:validateCourseGenerationData(vehicle);
	courseplay:validateCanSwitchMode(vehicle);

	courseplay:updateWaypointSigns(vehicle, "current");
end

function courseplay:currentVehAngle(vehicle)
	local x, y, z = localDirectionToWorld(vehicle.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x, z);
	local dX, dZ = x/length, z/length;
	return math.deg(math.atan2(dX, dZ))
end;
