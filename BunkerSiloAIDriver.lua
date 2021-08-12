--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Courseplay Dev team

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

--[[
The BunkerSiloAIDriver handles the interaction with a bunker silo for all drivers except unloader.
The driver creates temporary courses into/ out of the silo and handles all the basic interaction with the silo.
	
	- It's possible to have the driver drive forwards or backwards into the silo, which depends on:
	  BunkerSiloAIDriver:isDriveDirectionReverse(), if this return true the drive direction into the silo is reverse.
	
	- It's also possible to have the driver abort the silo tasked after it has driven out of the silo with:
	  BunkerSiloAIDriver:getCanContinueDrivingSiloCourse() == false.
	
	- Sub classes/drivers can implement their on logic in:
		- BunkerSiloAIDriver:driveIntoSilo(dt)
		- BunkerSiloAIDriver:driveOutOfSilo(dt)
		- BunkerSiloAIDriver:driveNormalCourse(dt)
	  and also in for one time setups: 
		- BunkerSiloAIDriver:beforeDriveIntoSilo()
		- BunkerSiloAIDriver:beforeDriveOutOfSilo()
		- BunkerSiloAIDriver:beforeMainCourse()  	
	  with these functions it also possible to directly force a driving state:
	  	- BunkerSiloAIDriver:setupDriveIntoSiloCourse(forcedStartIx)
		- BunkerSiloAIDriver:setupDriveOutOfSiloCourse()
		- BunkerSiloAIDriver:setupMainCourse()  
	
	- The finding of the silo and the setup of the bunker silo manager gets handled in BunkerSiloAIDriver:checkSilo(),
	  where it's possible to change multiple sub functions for different functionalities:
		- BunkerSiloAIDriver:getTargetNode() : sets the reference node for the silo, to decide if the end is reached.
		- BunkerSiloAIDriver:getWorkWidth() : work width for the bunker silo manager columns width
		- BunkerSiloAIDriver:getIsHeapSearchAllowed() : are heaps allowed ?
		- BunkerSiloAIDriver:getIsEmptySiloAllowed() : if this is false, then the driver stops when the silo is empty.
		- BunkerSiloAIDriver:getTargetBunkerSiloMode() : legancy setup options for the bunker silo manager.
	
	- The speed while driving into/out of the silo is this function:
	  BunkerSiloAIDriver:getBunkerSiloSpeed()
]]

---@class BunkerSiloAIDriver : AIDriver
BunkerSiloAIDriver = CpObject(AIDriver)

BunkerSiloAIDriver.myStates = {
	DRIVING_NORMAL_COURSE = {checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	DRIVING_NORMAL_COURSE_TO_SILO = {checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	DRIVING_INTO_SILO = {},
	DRIVING_OUT_OF_SILO ={},
	CHECK_SILO = {},
	SILO_IS_EMPTY = {}
}

--- Creates BunkerSiloAIDriver
---@param vehicle table
function BunkerSiloAIDriver.create(vehicle)
	if AIDriverUtil.hasImplementWithSpecialization(vehicle, Leveler) then 
		return ShieldAIDriver(vehicle)
	end
	return CompactingAIDriver(vehicle)
end

function BunkerSiloAIDriver:init(vehicle)
	AIDriver.init(self,vehicle)
	self:initStates(BunkerSiloAIDriver.myStates)
	self.siloState = self.states.DRIVING_NORMAL_COURSE
	self.siloDebugChannel = courseplay.DBG_MODE_10
	self.siloDebugTicks = 100
	self.transitionCourseOffset = 10
end

function BunkerSiloAIDriver:start(startingPoint)
	--- On start reset old variables
	self.bunkerSiloManager = nil 
	self:deleteBestTarget()
	self:changeSiloState(self.states.DRIVING_NORMAL_COURSE)
	AIDriver.start(self,startingPoint)
end

function BunkerSiloAIDriver:drive(dt)
	self:drawSiloMap()
	if self:isDrivingNormalCourse() then 
		self:driveNormalCourse(dt)
	elseif self:isDrivingIntoSilo() then
		self:driveIntoSilo(dt)
	elseif self:isDrivingOutOfSilo() then
		self:driveOutOfSilo(dt)
	elseif self:isCheckingSilo() then
		---If setup of the course was successful, then start.
		self:setupSiloCourse()
	elseif self:isWorkFinished() then
	--	self:hold()
		self:setInfoText('WORK_END')
	elseif self:isSiloEmpty() then
		self:hold()
		self:setInfoText('WORK_END')
	end


	AIDriver.drive(self,dt)
end

function BunkerSiloAIDriver:isDrivingIntoSilo()
	return self.siloState == self.states.DRIVING_INTO_SILO
end

function BunkerSiloAIDriver:isDrivingOutOfSilo()
	return self.siloState == self.states.DRIVING_OUT_OF_SILO
end

function BunkerSiloAIDriver:isCheckingSilo()
	return self.siloState == self.states.CHECK_SILO
end

function BunkerSiloAIDriver:isDrivingNormalCourse()
	return self.siloState == self.states.DRIVING_NORMAL_COURSE
end

function BunkerSiloAIDriver:isWorkFinished()
	return self.siloState == self.states.FINISHED
end

function BunkerSiloAIDriver:isSiloEmpty()
	return self.siloState == self.states.SILO_IS_EMPTY
end

function BunkerSiloAIDriver:isDrivingTransitionCourse()
	return self.siloState == self.states.DRIVING_NORMAL_COURSE_TO_SILO
end

function BunkerSiloAIDriver:driveNormalCourse(dt)
--- override
end

function BunkerSiloAIDriver:driveIntoSilo(dt)
	self:updateBestTarget()
	if self:isStuck() or self:isNearEnd() then 
		self:setupDriveOutOfSiloCourse()
	end
end

function BunkerSiloAIDriver:updateBestTarget()
	self.bunkerSiloManager:updateTarget(self.bestTarget)
end

function BunkerSiloAIDriver:driveOutOfSilo(dt)
	--- override
end
function BunkerSiloAIDriver:checkSilo()
	if self.bunkerSiloManager == nil then
		--- Search for a silo or heap, if allowed.
		local silo,isHeap = BunkerSiloManagerUtil.getTargetBunkerSiloAtWaypoint(self.vehicle,self.course,1,self:isHeapSearchAllowed())
		if silo then 
			self:debug("silo was found")
			--- Creates a bunker silo manager.
			self.bunkerSiloManager = BunkerSiloManager(self.vehicle,silo,self:getWorkWidth(),self:getTargetNode(),self:getTargetBunkerSiloMode(),isHeap)
			--- If empty silos are not allowed, then check if it is empty and got to state SILO_IS_EMPTY.
			if self.bunkerSiloManager and self.bunkerSiloManager:isSiloMapValid() or self:isEmptySiloAllowed() then
				return true
			else
				self.bunkerSiloManager = nil
				self:debug("silo map setup is not valid")
				self:changeSiloState(self.states.SILO_IS_EMPTY)
			end
		else 
			courseplay:setInfoText(self.vehicle, courseplay:loc('COURSEPLAY_MODE10_NOSILO'));
		end
	--- Reevaluate the silo if empty silos are not allowed.
	elseif self.bunkerSiloManager:isSiloMapValid() or self:isEmptySiloAllowed() then
		return true
	else 
		self.bunkerSiloManager = nil
		self:debug("silo map setup is not valid")
		self:changeSiloState(self.states.FINISHED)
	end
end

--- Can the silo be empty or not ?
function BunkerSiloAIDriver:isEmptySiloAllowed()
	return true
end

function BunkerSiloAIDriver:getTargetBunkerSiloMode()
	return BunkerSiloManager.MODE.COMPACTING
end

--- Returns the reference node for the progress detection.
function BunkerSiloAIDriver:getTargetNode()
	return self:getBackMarkerNode(self.vehicle)
end

function BunkerSiloAIDriver:isHeapSearchAllowed()
	return false
end

function BunkerSiloAIDriver:getWorkWidth()
	return self.vehicle.cp.workWidth
end

--- If true then the drive into silo course is reverse and 
--- the drive out of silo course is forwards.
function BunkerSiloAIDriver:isDriveDirectionReverse()
	return true
end

--- Does the driver needs some space
--- before driving into the silo for the first time ?
---@param bestTarget table first target for driving into the silo.
function BunkerSiloAIDriver:isStartDistanceToSiloNeeded(bestTarget)
	return false
end


--- Create a straight course into the silo.
---@param targetColumn number silo map column to create the straight course.
---@return course generated course 
---@return firstWpIx first waypoint of the course relative to the vehicle position.
function BunkerSiloAIDriver:getDriveIntoSiloCourse(targetColumn)
	local driveDirection = self:isDriveDirectionReverse()
	local numLines = self.bunkerSiloManager:getNumberOfLines()
	local x,z = self.bunkerSiloManager:getSiloPartPosition(1,targetColumn)
	local dx,dz = self.bunkerSiloManager:getSiloPartPosition(numLines - 1,targetColumn)		--stop a little bit shy of the end to prevent pushing chaff out of open-end bunker
	local startOffset = -5
	local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 0, startOffset, 0, 5, driveDirection)
	local firstWpIx
	if driveDirection then
		firstWpIx = course:getNextRevWaypointIxFromVehiclePosition(1, self:getDirectionNode(), 5)
	else 
		firstWpIx = course:getNextFwdWaypointIxFromVehiclePosition(1, self:getDirectionNode(), 5)
	end
	return course, firstWpIx
end

--- Create a straight course out of the silo.
---@param targetColumn number silo map column to create the straight course.
---@return course generated course 
---@return firstWpIx first waypoint of the course relative to the vehicle position.
function BunkerSiloAIDriver:getDriveOutOfSiloCourse(targetColumn,lengthOffset)
	local driveDirection = self:isDriveDirectionReverse()
	local numLines = self.bunkerSiloManager:getNumberOfLines()
	local x,z = self.bunkerSiloManager:getSiloPartPosition(numLines,targetColumn)
	local dx,dz = self.bunkerSiloManager:getSiloPartPosition(1,targetColumn)
	lengthOffset = lengthOffset or 0
	local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 0, 5, 10 + lengthOffset, 5, not driveDirection)
	local firstWpIx
	if driveDirection then
		firstWpIx = course:getNextFwdWaypointIxFromVehiclePosition(1, self:getDirectionNode(), 5)
	else 
		firstWpIx = course:getNextRevWaypointIxFromVehiclePosition(1, self:getDirectionNode(), 5)
	end
	return course, firstWpIx
end

--- Setup all necessary conditions at the start of the course,
--- for example lowering the attached implement in compacting mode.
function BunkerSiloAIDriver:beforeDriveIntoSilo()
	--- override
	self:deleteLastBestTarget()
	self.bestTarget,self.firstLine = self:getBestTarget()
end

--- Gets the best target for driving into the silo.
--- Allways starts at the right side and then drives to the left/right side.
function BunkerSiloAIDriver:getBestTarget()
	if not self.lastDrivenColumn then 
		local column = math.floor(self.bunkerSiloManager:getNumberOfColumns()/2)
		self:siloDebug("Starting a new approach in the middle at column %d",column)
		self.lastDrivenColumnRight = true
		return {line=1,column=column},1
	else 
		local numColumns = self.bunkerSiloManager:getNumberOfColumns()
		local nextColumn
		if self.lastDrivenColumnRight then 
			nextColumn = self.lastDrivenColumn+1
			if nextColumn > numColumns then 
				nextColumn = math.floor(self.bunkerSiloManager:getNumberOfColumns()/2) 
				self.lastDrivenColumnRight = false
			end
		else
			nextColumn = self.lastDrivenColumn-1
			if nextColumn <= 0 then 
				nextColumn = math.floor(self.bunkerSiloManager:getNumberOfColumns()/2) 
				self.lastDrivenColumnRight = true
			end
		end
		
		self:siloDebug("Starting at column: %d, last column: %d",nextColumn,self.lastDrivenColumn)
		return {line=1,column=nextColumn},1
	end
end

--- Setup all necessary conditions at the start of the course,
--- for example raising the attached implement in compacting mode.
function BunkerSiloAIDriver:beforeDriveOutOfSilo()
	--- override
end

--- Delete the best target, so after the unloader has unloaded,
--- a new approach for the silo is created.
function BunkerSiloAIDriver:beforeMainCourse()
	self:deleteBestTarget()
end

--- Deletes the best target and forces a new approach.
function BunkerSiloAIDriver:deleteBestTarget()
	self.lastDrivenColumn = nil
	self.bestTarget = nil
	self.lastDrivenColumnRight = not self.lastDrivenColumnRight
end

--- Deletes the best target, but saves the last driven column.
function BunkerSiloAIDriver:deleteLastBestTarget()
	self.lastBestTarget = self.bestTarget
	self.lastDrivenColumn = self.bestTarget and self.bestTarget.column
	self.bestTarget = nil
end

--- Sets up silo course.
function BunkerSiloAIDriver:setupSiloCourse()
	if self:checkSilo() then
		if not self:getCanContinueDrivingSiloCourse() then 
			self:setupMainCourse()
		elseif self:isStartDistanceToSiloNeeded(self:getBestTarget()) then 
			self:setupTransitionCourse()
		else 
			self:setupDriveIntoSiloCourse(1)
		end
	end
	self:hold()
end

--- Sets up the drive into silo course.
---@param forcedStartIx number forces the driver to start at this waypoint
function BunkerSiloAIDriver:setupDriveIntoSiloCourse(forcedStartIx)
	self:beforeDriveIntoSilo()
	local course,ix = self:getDriveIntoSiloCourse(self.bestTarget.column)
	self:siloDebug("Starting drive into silo course at: %d",forcedStartIx or ix)
	self:startCourse(course,forcedStartIx or ix)
	self:changeSiloState(self.states.DRIVING_INTO_SILO)
end

--- Sets up the drive out of silo course.
function BunkerSiloAIDriver:setupDriveOutOfSiloCourse()
	self:beforeDriveOutOfSilo()
	--- Finds the closest column relative to the driver position.
	local closestColumn = self.bunkerSiloManager:getClosestColumnToNode(self:getDirectionNode(),1)
	local course,ix = self:getDriveOutOfSiloCourse(closestColumn)
	self:siloDebug("Starting drive out of silo course at: %d",ix)
	self:startCourse(course,course:getNumberOfWaypoints())
	self:changeSiloState(self.states.DRIVING_OUT_OF_SILO)
end

--- Sets up the main course, when an unloader approaches.
function BunkerSiloAIDriver:setupMainCourse()
	self:beforeMainCourse()
	local nextIx
	if self:isDriveDirectionReverse() then
		nextIx = self.mainCourse:getNextFwdWaypointIxFromVehiclePosition(1, self:getDirectionNode(), 1)
	else 
		nextIx = self.mainCourse:getNextRevWaypointIxFromVehiclePosition(1, self:getDirectionNode(), 1)
	end
	self:siloDebug("Starting main course at: %d",nextIx)
	self:startCourse(self.mainCourse,nextIx)
	self:changeSiloState(self.states.DRIVING_NORMAL_COURSE)	
end

--- Setups a transition course from the normal course to the first drive into silo course,
--- this should give the driver more room to manoeuver.
function BunkerSiloAIDriver:setupTransitionCourse()
	local fistWpIx = 1
	local course
	local closestColumn,closestDistance = self.bunkerSiloManager:getClosestColumnToNode(self:getDirectionNode(),1)
	if self:isDriveDirectionReverse() then
		course = self:getStraightForwardCourse(5)
	else 
		local dist = self.transitionCourseOffset - closestDistance
		self:siloDebug("Setup transition course = dist: %.2f",dist)
		if dist>0 then
			local closestColumn = self.bunkerSiloManager:getClosestColumnToNode(self:getDirectionNode(),1)
			course = self:getDriveOutOfSiloCourse(closestColumn,5)

			fistWpIx = course:getNextRevWaypointIxFromVehiclePosition(1, self:getDirectionNode(), 2)
		else 
			self:setupDriveIntoSiloCourse(1)
			return 
		end
	end
	self:siloDebug("Starting transition course from main course to silo at: %d",fistWpIx)
	self:startCourse(course,fistWpIx)
	self:changeSiloState(self.states.DRIVING_NORMAL_COURSE_TO_SILO)
end


function BunkerSiloAIDriver:onEndCourse()
	if not self:isDrivingNormalCourse() then 
		--- The driver is ready to drive into the silo.
		if self:isDrivingTransitionCourse() then 
			self:setupDriveIntoSiloCourse()
			return
		end
		if self:isDrivingIntoSilo() then
			---Driver is at the end of the silo.
			self:setupDriveOutOfSiloCourse()
		else
			if not self:getCanContinueDrivingSiloCourse() then 
				--- Driver isn't allowed to continue driving into the silo,
				--- so continue with the main course.
				self:setupMainCourse()
			else 
				---Driver has returned out of the silo.
				self:setupDriveIntoSiloCourse()
			end
		end
	else 
		---Driver has reached the silo after driving the normal course.
		self:changeSiloState(self.states.CHECK_SILO)
	end
end

--- Is the driver allowed to continue driving the silo course ?
function BunkerSiloAIDriver:getCanContinueDrivingSiloCourse()
	return true
end


---Never use alignment course.
function BunkerSiloAIDriver:isAlignmentCourseNeeded(course,ix)
	return false
end

--- Is the Driver at the end of the silo?
function BunkerSiloAIDriver:isNearEnd()
	local referenceNode = self:getTargetNode()
	--- We us the last line of the silo map as reference.
	--- TODO: This should be improved once the silo map is adjusted to be more precise.
	local line,column = self.bunkerSiloManager:getNumberOfLines(),self.bestTarget.column
	local x,z = self.bunkerSiloManager:getSiloPartStartWidthHeightPositions(line,column)
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z);
	local _,_,dz = worldToLocal(referenceNode,x,y,z)
	return math.abs(dz)<0.1
end

function BunkerSiloAIDriver:changeSiloState(newState)
	if self.siloState ~= newState then
		self.siloState = newState
		self:siloDebug("New siloState => %s",newState.name)
	end
end

function BunkerSiloAIDriver:siloDebug(...)
	courseplay.debugVehicle(self.siloDebugChannel, self.vehicle,...)
end

function BunkerSiloAIDriver:siloDebugSparse(...)
	if g_updateLoopIndex %  self.siloDebugTicks ==0 then self:siloDebug(...) end
end

function BunkerSiloAIDriver:drawSiloMap()
	if self:isSiloDebugActive() and self.bunkerSiloManager then 
		self.bunkerSiloManager:drawMap()
	end
end

function BunkerSiloAIDriver:isSiloDebugActive()
	return courseplay.debugChannels[self.siloDebugChannel]
end

function BunkerSiloAIDriver:isTrafficConflictDetectionEnabled()
	return AIDriver.isTrafficConflictDetectionEnabled(self) and self.siloState and self.siloState.properties.checkForTrafficConflict
end

function BunkerSiloAIDriver:isProximitySwerveEnabled()
	return AIDriver.isProximitySwerveEnabled(self) and self.siloState and self.siloState.properties.enableProximitySwerve
end

function BunkerSiloAIDriver:isProximitySpeedControlEnabled()
	return AIDriver.isProximitySpeedControlEnabled(self) and self.siloState and self.siloState.properties.enableProximitySpeedControl
end

function BunkerSiloAIDriver:getSpeed()
	if self:isDrivingIntoSilo() or self:isDrivingOutOfSilo() then 
		return self:getBunkerSiloSpeed()
	else 
		return AIDriver.getSpeed(self)
	end
end

function BunkerSiloAIDriver:getBunkerSiloSpeed()
	return self.settings.bunkerSpeed:get()
end

function BunkerSiloAIDriver:isStuck()
	if self:doesNotMove() then
		if self.vehicle.cp.timers.slipping == nil or self.vehicle.cp.timers.slipping == 0 then
			courseplay:setCustomTimer(self.vehicle, 'slipping', 3);
			--courseplay:debug(('%s: setCustomTimer(..., "slippingStage", courseplay.DBG_TRAFFIC)'):format(nameNum(self.vehicle)), courseplay.DBG_MODE_10);
		elseif courseplay:timerIsThrough(self.vehicle, 'slipping') then
			--courseplay:debug(('%s: timerIsThrough(..., "slippingStage") -> return isStuck(), reset timer'):format(nameNum(self.vehicle)), courseplay.DBG_MODE_10);
			courseplay:resetCustomTimer(self.vehicle, 'slipping');
			self:debug("dropout isStuck")
			return true
		end;
	else
		courseplay:resetCustomTimer(self.vehicle, 'slipping');
	end
end

function BunkerSiloAIDriver:doesNotMove()
	-- giants supplied last speed is in mm/s;
	-- does not move if we are less than 1km/h
	return AIDriverUtil.isStopped(self.vehicle) and self.bestTarget.line > self.firstLine+1
end

function BunkerSiloAIDriver:setLightsMask(vehicle)
	vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_FULL)
end