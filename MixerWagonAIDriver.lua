---@class MixerWagonAIDriver : AIDriver

MixerWagonAIDriver = CpObject(AIDriver)

MixerWagonAIDriver.WORKING_TOOL_POSITIONS = {}
MixerWagonAIDriver.WORKING_TOOL_POSITIONS.LOADING = 1
MixerWagonAIDriver.WORKING_TOOL_POSITIONS.TRANSPORT = 2

MixerWagonAIDriver.myStates = {
	CHECK_SILO = {},
	DRIVE_INTO_SILO = {},
	DRIVE_OUT_OF_SILO = {},
	DRIVE_UNLOADING_COURSE = {checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true},
	BUNKER_SILO_IS_EMPTY = {},
	NO_VALID_SILO_FOUND = {},
	WORK_FINISHED = {}
}

function MixerWagonAIDriver:init(vehicle)
	AIDriver.init(self,vehicle)
	self:initStates(MixerWagonAIDriver.myStates)
	self.shovelSpec = self.vehicle.spec_shovel
	self.mixerWagonSpec = self.vehicle.spec_mixerWagon
	self.siloState = self.states.DRIVE_UNLOADING_COURSE
	self.debugChannel = 10
	self.siloSpeed = 5
end

function MixerWagonAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setMixerWagonAIDriverContent(self.vehicle)
end

function MixerWagonAIDriver:start(startingPoint)
	self:resetSiloData()
	self.bunkerSiloManager = nil
	self:validateWaitPoints()
	if startingPoint:is(StartingPointSetting.START_AT_FIRST_POINT) then
		self:changeState(self.states.CHECK_SILO)
	else 
		self:changeState(self.states.DRIVE_UNLOADING_COURSE)
	end
	AIDriver.start(self,startingPoint)
end

---Set the fill start point and the fill end point
function MixerWagonAIDriver:validateWaitPoints()
	self.fillStartPoint = nil
	self.fillEndPoint = nil
	local numWaitPoints = 0
	for i,wp in pairs(self.vehicle.Waypoints) do
		if wp.wait then
			numWaitPoints = numWaitPoints + 1
		end

		if numWaitPoints == 1 and self.fillStartPoint == nil then
			self.fillStartPoint = i
		end
		if numWaitPoints == 2 and self.fillEndPoint == nil then
			self.fillEndPoint = i
		end
	end
end

function MixerWagonAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course 
	return false
end

---If the end of a unload course is reached switch to state: CHECK_SILO
function MixerWagonAIDriver:onEndCourse()
	AIDriver.onEndCourse(self)
	if self.siloState == self.states.DRIVE_UNLOADING_COURSE then
		self:resetSiloData()
		self:changeState(self.states.CHECK_SILO)
	end
end

function MixerWagonAIDriver:drive(dt)
	if not self:areWaitPointsValid() or not self:areWorkingToolPositionsValid() then 
		self:hold()
	end
	if self.siloState == self.states.CHECK_SILO then 
		self:hold()
		if not self:getIsEmpty() then 
			self:debug("finished unloading")
			self:changeState(self.states.WORK_FINISHED)
		end
		if self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.LOADING) then
			self:checkSilo()
		end
	elseif self.siloState == self.states.DRIVE_INTO_SILO then 
		self:driveIntoSilo(dt)
	elseif self.siloState == self.states.DRIVE_OUT_OF_SILO then 
		if self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.TRANSPORT) then
			self:driveOutOfSilo(dt)
		end
	elseif self.siloState == self.states.DRIVE_UNLOADING_COURSE then 

	elseif self.siloState == self.states.BUNKER_SILO_IS_EMPTY then 
		self:hold()
		self:setInfoText('FARM_SILO_IS_EMPTY')
	elseif self.siloState == self.states.NO_VALID_SILO_FOUND then 
		self:hold()
		courseplay:setInfoText(self.vehicle, courseplay:loc('COURSEPLAY_MODE10_NOSILO'))
	elseif self.siloState == self.states.WORK_FINISHED then 
		self:hold()
		self:setInfoText('WORK_END')
	end
	self:updateTriggerHandlerStates()
	self:drawMap()
	AIDriver.drive(self,dt)
end

---Enables triggerHandler loading/unloading while on unload course
function MixerWagonAIDriver:updateTriggerHandlerStates()
	if self.siloState == self.states.DRIVE_UNLOADING_COURSE then 
		self.triggerHandler:enableFillTypeLoading()
		self.triggerHandler:enableFillTypeUnloading()
	else 
		self.triggerHandler:disableFillTypeLoading()
		self.triggerHandler:disableFillTypeUnloading()
	end
end

function MixerWagonAIDriver:checkSilo()
	--if bunkerSiloManager is nil, then search for a silo/heap
	if self.bunkerSiloManager == nil then
		local silo = self:getTargetBunkerSilo()
		--silo/heap was found 
		if silo then 
			self.bunkerSiloManager =  BunkerSiloManager(self.vehicle, silo, self:getWorkWidth(),self.shovelSpec.shovelNodes[1],BunkerSiloManager.MODE.SHOVEL)
		else 
			self:debug("no silo was found")
		--	courseplay:setInfoText(self.vehicle, courseplay:loc('COURSEPLAY_MODE10_NOSILO'))
			self:changeState(self.states.NO_VALID_SILO_FOUND)
		end
	end
	---if bunkerSiloManager and siloMap are valid then search for best target
	if self.bunkerSiloManager and self.bunkerSiloManager:isSiloMapValid() then
		self.bestTarget, self.firstLine = self.bunkerSiloManager:getBestTargetFillUnitFillUp()
		--best target was found => STATE_GOINTO_SILO
		if self.bestTarget then 
			---Create and start drive into silo course
			self:createDriveIntoSiloCourse()
			self:startCourse(self.tempDriveIntoSiloCourse, 1)
			self:changeState(self.states.DRIVE_INTO_SILO)
			self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
			self.vehicle:requestActionEventUpdate()
			self:hold()
		else 
			self.bunkerSiloManager = nil
			self:resetBGASiloTables()
			self:debug("could not find best target")
			self:changeState(self.states.NO_VALID_SILO_FOUND)
		end
	else
		self.bunkerSiloManager = nil
		self:resetBGASiloTables()
		self:debug("silo map setup is not valid")
		self:changeState(self.states.BUNKER_SILO_IS_EMPTY)
	end
end

---Drive into the silo until max fillLevel is reached
function MixerWagonAIDriver:driveIntoSilo(dt)
	if self:getIsFull() then 
		---Create and start drive out of silo course
		self:createDriveOutOfSiloCourse()
		local ix = self.tempDriveIntoSiloCourse:getNextRevWaypointIxFromVehiclePosition(1, self.vehicle.rootNode, 5)
		self:startCourse(self.tempDriveOutOfSiloCourse, ix,self.mainCourse)
		self:changeState(self.states.DRIVE_OUT_OF_SILO)
		self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
		self.vehicle:requestActionEventUpdate()
		self:hold()
	end
	if not self:isAllowedToMove() then 
		self:hold()
	end
end

function MixerWagonAIDriver:driveOutOfSilo(dt)
	
end

---Start the next unload course form the tempDriveBackCourse correctly
function MixerWagonAIDriver:continueOnNextCourse(nextCourse, nextWpIx)
	local ix = nextCourse:getNextRevWaypointIxFromVehiclePosition(1, self.vehicle.rootNode, 5)
	self:changeState(self.states.DRIVE_UNLOADING_COURSE)
	AIDriver.continueOnNextCourse(self,nextCourse, ix)
end

---Create a straight forwards course to best target
function MixerWagonAIDriver:createDriveIntoSiloCourse()
	local targetColumn = self.bestTarget.column
	local numLines = self.bunkerSiloManager:getNumberOfLines()
	local x,z = self.bunkerSiloManager:getSiloPartPosition(1,targetColumn)
	local dx,dz = self.bunkerSiloManager:getSiloPartPosition(numLines,targetColumn)
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
	self.tempDriveIntoSiloCourse = self:getStraightForwardCourseFromPositionToAnotherPosition(x,z,dx,dz,0)
end

---Create a straight backwards course out of the silo
function MixerWagonAIDriver:createDriveOutOfSiloCourse()
	local targetColumn = self.bestTarget.column
	local x,z = self.bunkerSiloManager:getSiloPartPosition(1,targetColumn)
	local dx,_,dz = worldToLocal(self.vehicle.rootNode,x,0,z)
	self.tempDriveOutOfSiloCourse = self:getStraightReverseCourse(math.abs(dz)+5)
end

---Gets a forward course between two positions
---@param float x/z
---@param float dx/dz
---@param float zOffset
---@return Course forward course between two positions 
function MixerWagonAIDriver:getStraightForwardCourseFromPositionToAnotherPosition(x,z,dx,dz,zOffset)
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
	local referenceNode = createTransformGroup("tempCourse")
	setTranslation(referenceNode,x,y,z)
	local dist = courseplay:distance(x, z, dx, dz)
	local nx, nz = MathUtil.vector2Normalize(dx - x, dz - z)
	local dirY = 0
	-- check for NaN
	if nx == nx or nz == nz then
		dirY = MathUtil.getYRotationFromDirection(nx, nz)
	end
	setRotation(referenceNode,0,dirY,0)
	local zOffset = zOffset and zOffset or 0
	local course = Course.createFromNode(self.vehicle, referenceNode, 0, 0, dist+zOffset, 5, false)
	delete(referenceNode)
	return course
end


function MixerWagonAIDriver:changeState(newState)
	if self.siloState ~= newState then
		self.siloState = newState
		self:debug("change siloState => "..newState.name)
	end
end

---Are fill start point and fill end point set correctly ?
---@return boolean fill start point and fill end point set correctly 
function MixerWagonAIDriver:areWaitPointsValid()
	if self.fillStartPoint == nil or self.fillEndPoint == nil then
		courseplay:setInfoText(self.vehicle, 'COURSEPLAY_NO_VALID_COURSE')
		return false
	end
	return true
end

---Are all working tool positions set correctly ?
---@return boolean working tool positions set correctly
function MixerWagonAIDriver:areWorkingToolPositionsValid()
	local validToolPositions = self.vehicle.cp.settings.mixerWagonToolPositions:hasValidToolPositions()
	if not validToolPositions then 
		courseplay:setInfoText(self.vehicle, 'COURSEPLAY_SHOVEL_POSITIONS_MISSING')
	end
	return validToolPositions
end

---Is working tool positions reached ?
---@return boolean working tool positions reached
function MixerWagonAIDriver:isWorkingToolPositionReached(dt,positionIx)
	return self.vehicle.cp.settings.mixerWagonToolPositions:updatePositions(dt,positionIx)
end

---Is max fillLevel reached ?
---@return boolean is full ?
function MixerWagonAIDriver:getIsFull()
	local fillType = self.bunkerSiloManager:getFillType()
	return self:getFillTypeFillLevel(fillType) >= self:getMaxFillLevelFromSilo(fillType)
end

---Gets max fillLevel of a fillType
---@param float fillTypeIndex
---@return float max fillLevel of a fillType 
function MixerWagonAIDriver:getMaxFillLevelFromSilo(fillType)
	if self:getSiloSelectedFillTypeSetting():isEmpty() then
		return self:getCapacity()*0.98
	else 
		local fillTypeData = self:getSiloSelectedFillTypeSetting():getData()
		for _,data in ipairs(fillTypeData) do 
			if data.fillType == fillType then
				return self:getCapacity()*data.maxFillLevel/100
			end
		end
		return self:getCapacity()*0.98
	end
end

---Is empty ? 
---@return boolean is empty ?
function MixerWagonAIDriver:getIsEmpty()
	return self:getFillLevel() <= self:getCapacity()*0.01
end

---Gets fillLevel of a fillType
---@param float fillTypeIndex
---@return float fillLevel of a fillType 
function MixerWagonAIDriver:getFillTypeFillLevel(fillType)
	for _, data in pairs(self.mixerWagonSpec.mixerWagonFillTypes) do
		if data.fillTypes[fillType] then 
			return data.fillLevel
		end
	end
	return 0
end

---Gets total fillLevel 
---@return float fillLevel
function MixerWagonAIDriver:getFillLevel()
	return self.vehicle:getFillUnitFillLevel(1)
end

---Gets total capacity 
---@return float capacity
function MixerWagonAIDriver:getCapacity()
	return self.vehicle:getFillUnitCapacity(1)
end

---Is all cleared in front ?
---@return boolean is allowed to move
function MixerWagonAIDriver:isAllowedToMove()
	if self.shovelSpec.loadingFillType == FillType.UNKNOWN then
		return true
	end
	return false
end

---Gets a bunker silo
---@return table bunkerSiloManager
function MixerWagonAIDriver:getTargetBunkerSilo()
	return BunkerSiloManagerUtil.getTargetBunkerSiloBetweenWaypoints(self.vehicle,self.course,self.fillStartPoint,self.fillEndPoint)
end

---Gets the silo selected fillType 
---@return setting SiloSelectedFillTypeMixerWagonAIDriverSetting
function MixerWagonAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeMixerWagonAIDriver
end

---The same as AIDriver:onWaypointPassed() without the wait msg
function MixerWagonAIDriver:onWaypointPassed(ix)
	if self.course:isWaitAt(ix+1) then
		
	elseif ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	end
end

----Only use normal speed while driving the unloading course
function MixerWagonAIDriver:getSpeed()
	if self:getCanGoWithStreetSpeed() then
		return AIDriver.getSpeed(self)
	else
		return self.siloSpeed
	end
end

---Only use normal speed while driving the unloading course
function MixerWagonAIDriver:getCanGoWithStreetSpeed()
	return self.siloState == self.states.DRIVE_UNLOADING_COURSE
end

---Get work width
function MixerWagonAIDriver:getWorkWidth()
	return 3
end

---Reset all silo data
function MixerWagonAIDriver:resetSiloData()
	self.tempDriveIntoSiloCourse = nil
	self.tempDriveOutOfSiloCourse = nil
	self.bestTarget = nil
	self.firstLine = nil
end

function MixerWagonAIDriver:debugRouting()
	if self:isDebugActive() and self.bunkerSiloManager then
		self.bunkerSiloManager:debugRouting(self.bestTarget)
	end
end

function MixerWagonAIDriver:drawMap()
	if self:isDebugActive() and self.bunkerSiloManager then
		self.bunkerSiloManager:drawMap()
	end
end

function MixerWagonAIDriver:isDebugActive()
	return courseplay.debugChannels[self.debugChannel]
end

---Only allow traffic conflict while driving the unloading course
function MixerWagonAIDriver:isTrafficConflictDetectionEnabled()
	return AIDriver.isTrafficConflictDetectionEnabled(self) and self.siloState.properties.checkForTrafficConflict
end

---Only allow proximity swerve while driving the unloading course
function MixerWagonAIDriver:isProximitySwerveEnabled()
	return AIDriver.isProximitySwerveEnabled(self) and self.siloState.properties.enableProximitySwerve
end

---Only allow proximity speed control while driving the unloading course
function MixerWagonAIDriver:isProximitySpeedControlEnabled()
	return AIDriver.isProximitySpeedControlEnabled(self) and self.siloState.properties.enableProximitySpeedControl
end

---Always do a loop course
function MixerWagonAIDriver:shouldStopAtEndOfCourse()
	return false
end