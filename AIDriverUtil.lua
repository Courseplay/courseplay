--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

---@class AIDriverUtil
AIDriverUtil = {}

-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
AIDriverUtil.PIPE_STATE_MOVING = 0
AIDriverUtil.PIPE_STATE_CLOSED = 1
AIDriverUtil.PIPE_STATE_OPEN = 2

function AIDriverUtil.isReverseDriving(vehicle)
	if not vehicle then
		printCallstack()
		return false
	end
	return vehicle.spec_reverseDriving and vehicle.spec_reverseDriving.isReverseDriving
end

function AIDriverUtil.getDirectionNode(vehicle)
	-- our reference node we are tracking/controlling, by default it is the vehicle's root/direction node
	if AIDriverUtil.isReverseDriving(vehicle) then
		-- reverse driving tractor, use the CP calculated reverse driving direction node pointing in the
		-- direction the driver seat is facing
		return vehicle.cp.reverseDrivingDirectionNode
	else
		return vehicle.cp.directionNode or vehicle.rootNode
	end
end

--- If we are towing an implement, move to a bigger radius in tight turns
--- making sure that the towed implement's trajectory remains closer to the
--- course.
---@param course Course
function AIDriverUtil.calculateTightTurnOffset(vehicle, course, previousOffset, useCalculatedRadius)
	local tightTurnOffset

	local function smoothOffset(offset)
		return (offset + 3 * (previousOffset or 0 )) / 4
	end

	-- first of all, does the current waypoint have radius data?
	local r
	if useCalculatedRadius then
		r = course:getCalculatedRadiusAtIx(course:getCurrentWaypointIx())
	else
		r = course:getRadiusAtIx(course:getCurrentWaypointIx())
	end

	if not r then
		return smoothOffset(0)
	end

	-- limit the radius we are trying to follow to the vehicle's turn radius.
	-- TODO: there's some potential here as the towed implement can move on a radius less than the vehicle's
	-- turn radius so this limit may be too pessimistic
	r = math.max(r, vehicle.cp.turnDiameter / 2)

	local towBarLength = AIDriverUtil.getTowBarLength(vehicle)

	-- Is this really a tight turn? It is when the tow bar is longer than radius / 3, otherwise
	-- we ignore it.
	if towBarLength < r / 3 then
		return smoothOffset(0)
	end

	-- Ok, looks like a tight turn, so we need to move a bit left or right of the course
	-- to keep the tool on the course. Use a little less than the calculated, this is purely empirical and should probably
	-- be reviewed why the calculated one seems to overshoot.
	local offset = 0.75 * AIDriverUtil.getOffsetForTowBarLength(r, towBarLength)
	if offset ~= offset then
		-- check for nan
		return smoothOffset(0)
	end
	-- figure out left or right now?
	local nextAngle = course:getWaypointAngleDeg(course:getCurrentWaypointIx() + 1)
	local currentAngle = course:getWaypointAngleDeg(course:getCurrentWaypointIx())
	if not nextAngle or not currentAngle then
		return smoothOffset(0)
	end

	if getDeltaAngle(math.rad(nextAngle), math.rad(currentAngle)) > 0 then offset = -offset end

	-- smooth the offset a bit to avoid sudden changes
	tightTurnOffset = smoothOffset(offset)
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER, vehicle,
		'Tight turn, r = %.1f, tow bar = %.1f m, currentAngle = %.0f, nextAngle = %.0f, offset = %.1f, smoothOffset = %.1f',
		r, towBarLength, currentAngle, nextAngle, offset, tightTurnOffset )
	-- remember the last value for smoothing
	return tightTurnOffset
end

function AIDriverUtil.getTowBarLength(vehicle)
	-- is there a wheeled implement behind the tractor and is it on a pivot?
	local workTool = courseplay:getFirstReversingWheeledWorkTool(vehicle)
	if not workTool or not workTool.cp.realTurningNode then
		return 0
	end
	-- get the distance between the tractor and the towed implement's turn node
	-- (not quite accurate when the angle between the tractor and the tool is high)
	local tractorX, _, tractorZ = getWorldTranslation(AIDriverUtil.getDirectionNode(vehicle))
	local toolX, _, toolZ = getWorldTranslation( workTool.cp.realTurningNode )
	local towBarLength = courseplay:distance( tractorX, tractorZ, toolX, toolZ )
	return towBarLength
end

function AIDriverUtil.getOffsetForTowBarLength(r, towBarLength)
	local rTractor = math.sqrt( r * r + towBarLength * towBarLength ) -- the radius the tractor should be on
	return rTractor - r
end

-- Find the node to use by the PPC when driving in reverse
function AIDriverUtil.getReverserNode(vehicle)
	local reverserNode, debugText
	-- if there's a reverser node on the tool, use that
	local reverserDirectionNode = AIVehicleUtil.getAIToolReverserDirectionNode(vehicle)
	local reversingWheeledWorkTool = courseplay:getFirstReversingWheeledWorkTool(vehicle)
	if reverserDirectionNode then
		reverserNode = reverserDirectionNode
		debugText = 'implement reverse (Giants)'
	elseif reversingWheeledWorkTool and reversingWheeledWorkTool.cp.realTurningNode then
		reverserNode = reversingWheeledWorkTool.cp.realTurningNode
		debugText = 'implement reverse (Courseplay)'
	elseif vehicle.spec_articulatedAxis ~= nil then
		-- articulated axis vehicles have a special reverser node
		-- and yes, Giants has a typo in there...
		if vehicle.spec_articulatedAxis.aiRevereserNode ~= nil then
			reverserNode = vehicle.spec_articulatedAxis.aiRevereserNode
			debugText = 'vehicle articulated axis reverese'
		elseif vehicle.spec_articulatedAxis.aiReverserNode ~= nil then
			reverserNode = vehicle.spec_articulatedAxis.aiReverserNode
			debugText = 'vehicle articulated axis reverse'
		end
	else
		-- otherwise see if the vehicle has a reverser node
		if vehicle.getAIVehicleReverserNode then
			reverserDirectionNode = vehicle:getAIVehicleReverserNode()
			if reverserDirectionNode then
				reverserNode = reverserDirectionNode
				debugText = 'vehicle reverse'
			end
		end
	end
	return reverserNode, debugText
end

-- Get the turning radius of the vehicle and its implements (copied from AIDriveStrategyStraight.updateTurnData())
function AIDriverUtil.getTurningRadius(vehicle)
	courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, 'Finding turn radius:')

	local radius = vehicle.maxTurningRadius or 6
	courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  turnRadius set to %.1f', radius)

	if g_vehicleConfigurations:get(vehicle, 'turnRadius') then
		radius = g_vehicleConfigurations:get(vehicle, 'turnRadius')
		courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  turnRadius set from configfile to %.1f', radius)
	end
	if vehicle.cp.turnDiameterAutoMode == false and vehicle.cp.turnDiameter ~= nil then
		radius = vehicle.cp.turnDiameter / 2
		courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  turnRadius manually set to %.1f', radius)
	end

	if vehicle:getAIMinTurningRadius() ~= nil then
		courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  AIMinTurningRadius by Giants is %.1f', vehicle:getAIMinTurningRadius())
		radius = math.max(radius, vehicle:getAIMinTurningRadius())
	end

	local maxToolRadius = 0

	for _, implement in pairs(vehicle:getAttachedImplements()) do
		local turnRadius = 0
		if g_vehicleConfigurations:get(implement.object, 'turnRadius') then
			turnRadius = g_vehicleConfigurations:get(implement.object, 'turnRadius')
			courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  %s: using the configured turn radius %.1f',
				implement.object:getName(), turnRadius)
		elseif SpecializationUtil.hasSpecialization(AIImplement, implement.object.specializations) then
			-- only call this for AIImplements, others may throw an error as the Giants code assumes AIImplement
			turnRadius = AIVehicleUtil.getMaxToolRadius(implement)
			if turnRadius > 0 then
				courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  %s: using the Giants turn radius %.1f',
					implement.object:getName(), turnRadius)
			end
		end
		if turnRadius == 0 then
			turnRadius = courseplay:getToolTurnRadius(implement.object)
			courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  %s: no Giants turn radius, we calculated %.1f',
				implement.object:getName(), turnRadius)
		end
		maxToolRadius = math.max(maxToolRadius, turnRadius)
		courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '  %s: max tool radius now is %.1f', implement.object:getName(), maxToolRadius)
	end
	radius = math.max(radius, maxToolRadius)
	courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, 'getTurningRadius: %.1f m', radius)
	return radius
end

---@return boolean true if there are any implements attached to the back of the vehicle
function AIDriverUtil.hasImplementsOnTheBack(vehicle)
	for _, implement in pairs(vehicle:getAttachedImplements()) do
		if implement.object ~= nil then
			local _, _, dz = localToLocal(implement.object.rootNode, vehicle.rootNode, 0, 0, 0)
			if dz < 0 then
				return true
			end
		end
	end
	return false
end

function AIDriverUtil.getAllAttachedImplements(object, implements)
	if not implements then implements = {} end
	for _, implement in ipairs(object:getAttachedImplements()) do
		table.insert(implements, implement)
		AIDriverUtil.getAllAttachedImplements(implement.object, implements)
	end
	return implements
end

---@return table, number frontmost object and the distance between the front of that object and the root node of the vehicle
--- when > 0 in front of the vehicle
function AIDriverUtil.getFirstAttachedImplement(vehicle)
	-- by default, it is the vehicle's front
	local maxDistance = vehicle.sizeLength / 2 + vehicle.lengthOffset
	local firstImplement = vehicle
	for _, implement in pairs(AIDriverUtil.getAllAttachedImplements(vehicle)) do
		if implement.object ~= nil then
			-- the distance from the vehicle's root node to the front of the implement
			local _, _, d = localToLocal(implement.object.rootNode, vehicle.rootNode, 0, 0,
				implement.object.sizeLength / 2 + implement.object.lengthOffset)
			courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '%s front distance %d', implement.object:getName(), d)
			if d > maxDistance then
				maxDistance = d
				firstImplement = implement.object
			end
		end
	end
	return firstImplement, maxDistance
end

---@return table, number rearmost object and the distance between the back of that object and the root node of the object
function AIDriverUtil.getLastAttachedImplement(vehicle)
	-- by default, it is the vehicle's back
	local minDistance = vehicle.sizeLength / 2 - vehicle.lengthOffset
	-- lengthOffset > 0 if the root node is towards the back of the vehicle, < 0 if it is towards the front
	local lastImplement = vehicle
	for _, implement in pairs(AIDriverUtil.getAllAttachedImplements(vehicle)) do
		if implement.object ~= nil then
			-- the distance from the vehicle's root node to the back of the implement
			local _, _, d = localToLocal(implement.object.rootNode, vehicle.rootNode, 0, 0,
				- implement.object.sizeLength / 2 + implement.object.lengthOffset)
			courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, vehicle, '%s back distance %d', implement.object:getName(), d)
			if d < minDistance then
				minDistance = d
				lastImplement = implement.object
			end
		end
	end
	return lastImplement, minDistance
end

function AIDriverUtil.isAllFolded(object)
	if SpecializationUtil.hasSpecialization(Foldable, object.specializations) then
		if object:getIsUnfolded() then
			-- object is unfolded, so all can't be folded
			return false
		end
	end
	for _, implement in pairs(object:getAttachedImplements()) do
		if not AIDriverUtil.isAllFolded(implement.object) then
			-- at least on implement is not completely folded so all can't be folded
			return false
		end
	end
	-- nothing is unfolded
	return true
end

function AIDriverUtil.hasAIImplementWithSpecialization(vehicle, specialization)
	return AIDriverUtil.getAIImplementWithSpecialization(vehicle, specialization) ~= nil
end

function AIDriverUtil.hasImplementWithSpecialization(vehicle, specialization)
	return AIDriverUtil.getImplementWithSpecialization(vehicle, specialization) ~= nil
end

function AIDriverUtil.getAIImplementWithSpecialization(vehicle, specialization)
	local aiImplements = vehicle:getAttachedAIImplements()
	return AIDriverUtil.getImplementWithSpecializationFromList(specialization, aiImplements)
end

function AIDriverUtil.getImplementWithSpecialization(vehicle, specialization)
	local implements = vehicle:getAttachedImplements()
	return AIDriverUtil.getImplementWithSpecializationFromList(specialization, implements)
end

function AIDriverUtil.getImplementWithSpecializationFromList(specialization, implements)
	for _, implement in ipairs(implements) do
		if SpecializationUtil.hasSpecialization(specialization, implement.object.specializations) then
			return implement.object
		end
	end
end

--- Is this a real wheel the implement is actually rolling on (and turning around) or just some auxiliary support
--- wheel? We need to know about the real wheels when finding the turn radius/distance between attacher joint and
--- wheels.
function AIDriverUtil.isRealWheel(wheel)
	return wheel.hasTireTracks and wheel.maxLatStiffnessLoad > 0.5
end

function AIDriverUtil.isBehindOtherVehicle(vehicle, otherVehicle)
	local _, _, dz = localToLocal(AIDriverUtil.getDirectionNode(vehicle), AIDriverUtil.getDirectionNode(otherVehicle), 0, 0, 0)
	return dz < 0
end

function AIDriverUtil.isStopped(vehicle)
	-- giants supplied last speed is in mm/s
	return math.abs(vehicle.lastSpeedReal) < 0.0001
end

function AIDriverUtil.isReversing(vehicle)
	return vehicle.movingDirection == -1 and vehicle.lastSpeedReal * 3600 > 0.1
end

--- Get the current normalized steering angle:
---@return number between -1 and +1, -1 full right steering, +1 full left steering
function AIDriverUtil.getCurrentNormalizedSteeringAngle(vehicle)
	if vehicle.rotatedTime >= 0 then
		return vehicle.rotatedTime / vehicle.maxRotTime
	elseif vehicle.rotatedTime < 0 then
		return -vehicle.rotatedTime / vehicle.minRotTime
	end
end

function AIDriverUtil.getAllFillLevels(object, fillLevelInfo, driver)
	-- get own fill levels
	if object.getFillUnits then
		for _, fillUnit in pairs(object:getFillUnits()) do
			local fillType = AIDriverUtil.getFillTypeFromFillUnit(fillUnit)
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
			if driver then
				driver:debugSparse('%s: Fill levels: %s: %.1f/%.1f', object:getName(), fillTypeName, fillUnit.fillLevel, fillUnit.capacity)
			end
			if not fillLevelInfo[fillType] then fillLevelInfo[fillType] = {fillLevel=0, capacity=0} end
			fillLevelInfo[fillType].fillLevel = fillLevelInfo[fillType].fillLevel + fillUnit.fillLevel
			fillLevelInfo[fillType].capacity = fillLevelInfo[fillType].capacity + fillUnit.capacity
			--used to check treePlanter fillLevel
			local treePlanterSpec = object.spec_treePlanter
			if treePlanterSpec then
				fillLevelInfo[fillType].treePlanterSpec = object.spec_treePlanter
			end
		end
	end
	-- collect fill levels from all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		AIDriverUtil.getAllFillLevels(impl.object, fillLevelInfo, driver)
	end
end

function AIDriverUtil.getFillTypeFromFillUnit(fillUnit)
	local fillType = fillUnit.lastValidFillType or fillUnit.fillType
	-- TODO: do we need to check more supported fill types? This will probably cover 99.9% of the cases
	if fillType == FillType.UNKNOWN then
		-- just get the first valid supported fill type
		for ft, valid in pairs(fillUnit.supportedFillTypes) do
			if valid then return ft end
		end
	else
		return fillType
	end
end

