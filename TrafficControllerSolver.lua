
TrafficControllerSolver = CpObject()

function TrafficControllerSolver:init(vehicleID)
	self.vehicle = g_currentMission.nodeToObject[vehicleID]
	print(nameNum(self.vehicle)..": TrafficControllerSolver:init()")
	self.otherVehicleId = g_trafficController:getBlockingVehicleId(vehicleID)
	self.otherVehicle = g_currentMission.nodeToObject[self.otherVehicleId]
	self.safetyDistance = 5 --minimal side distance between two vehicles rootNodes
end
function TrafficControllerSolver:solveCollision()
	--print("TrafficControllerSolver:solveCollision()")
	--print(string.format("%s blocks %s",nameNum(self.otherVehicle),nameNum(self.vehicle)))
	local driver = self.vehicle.cp.driver
	local course = driver.course

	if self.otherVehicle:getIsCourseplayDriving() then
		if not g_trafficController:getHasSolver(self.otherVehicleId) then
		--the other one didnt recognise me
			if self:vehicleIsMoving(self.otherVehicle) then
				if self:courseHitsOtherVehicle(course,self.vehicle.cp.driver.ppc:getCurrentWaypointIx())then
					--does it have the same direction ??
					-- find a way to overtake or to prevent collision
					if g_updateLoopIndex % 500 == 0 then
						print(string.format("TrafficControllerSolver: %s has traffic, situation known (cp, moving and course hits vehicle) but no solution provided yet",nameNum(self.vehicle)))
					end
				else
					--do nothing and wait till it moved out of the way
				end
			else
				print("call modifyCourseArroundObstacle")
				--its driven but not moving so go arround it
				self:modifyCourseArroundObstacle()
			end
		else
			-- let the two solvers talk to each other
			if g_updateLoopIndex % 500 == 0 then
				print(string.format("TrafficControllerSolver: %s has traffic, situation known (cp, two solvers) but no solution provided yet",nameNum(self.vehicle)))
			end
		end

	else
		if self:vehicleIsMoving(self.otherVehicle) then
			--the other one is manually driven, so wait and do nothing
		else
			--its not driving and not moving, so find a way arround it
			self:modifyCourseArroundObstacle()
		end
	end
end

function TrafficControllerSolver:courseHitsOtherVehicle(course,ix)
	return self:getFirstCollidingPointFromCourse(course,ix) ~= nil
end

function TrafficControllerSolver:vehicleIsMoving(vehicle)
	return vehicle.lastSpeedReal*3600 > 0.1
end

function TrafficControllerSolver:modifyCourseArroundObstacle()
	local driver = self.vehicle.cp.driver
	local course = driver.course
	local firstCollidingPoint = self:getFirstCollidingPointFromCourse(course,driver.ppc:getCurrentWaypointIx())
	if firstCollidingPoint then
		local pointsToModify = self:getAllCollidingPointsFromCourse(course,firstCollidingPoint)
		--print(string.format("found %d points",#pointsToModify))
		for i=1,#pointsToModify do
			local pointData = pointsToModify[i]
			local waypoint = course.waypoints[pointData.ix]
			local newOffset = 0
			--print("pointData.ix: "..tostring(pointData.ix).."  pointData.dx: "..tostring(pointData.dx).."  waypoint.x: "..tostring(waypoint.x).."  waypoint.z: "..tostring(waypoint.z))
			if pointData.dx > 0 then
				newOffset = pointData.dx - self.safetyDistance-(self.otherVehicle.cp.workWidth/2)
			else
				newOffset = pointData.dx + self.safetyDistance+(self.otherVehicle.cp.workWidth/2)
			end
			local courseOffsetX = course:getOffset()
			local newX,newY,newZ = course:waypointLocalToWorld(pointData.ix, newOffset+courseOffsetX, 0, 0)
			waypoint.x = newX
			waypoint.z = newZ
			--print("pointData.ix: "..tostring(pointData.ix).."  pointData.dx: "..tostring(pointData.dx).."  newX: "..tostring(newX).."  newZ: "..tostring(newZ))
		end
	end
end

function TrafficControllerSolver:getFirstCollidingPointFromCourse(course,ix)
	for i= ix,course:getNumberOfWaypoints() do
		if self:checkWayPointHittingVehicle(course,i) then
			return i
		end
	end
end

function TrafficControllerSolver:getAllCollidingPointsFromCourse(course,ix)
	local waypoints = {}
	for i= ix,course:getNumberOfWaypoints() do
		local hit,diffX,diffY,diffZ = self:checkWayPointHittingVehicle(course,i)
		if hit then
			local point = {
							ix = i;
							dx = diffX;
							dy = diffY;
							dz = diffZ;
			}
			table.insert(waypoints,point)
		else
			break
		end
	end
	return waypoints
end

function TrafficControllerSolver:checkWayPointHittingVehicle(course,ix)
	local x,y,z = getWorldTranslation(self.otherVehicleId)
	local length = self.otherVehicle.cp.totalLength or courseplay:getTotalLengthOnWheels(self.otherVehicle)

	local dx,dy,dz = course:worldToWaypointLocal(ix, x, y, z)
	return  math.abs(dz)< self.vehicle.cp.turnDiameter+self.safetyDistance+length and math.abs(dx) < self.safetyDistance+(self.otherVehicle.cp.workWidth/2), dx, dy, dz
end