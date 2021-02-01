--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

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

---@class GrainTransportAIDriver : AIDriver
GrainTransportAIDriver = CpObject(AIDriver)

GrainTransportAIDriver.myStates = {
	NEEDS_LOADING = {},
	NEEDS_UNLOADING = {}
}

--- Constructor
function GrainTransportAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'GrainTransportAIDriver:init()')
	AIDriver.init(self, vehicle)
	self:initStates(GrainTransportAIDriver.myStates)
	self.mode = courseplay.MODE_GRAIN_TRANSPORT
	self.totalFillCapacity = 0
	self:changeLoadingAtStartState(self.states.NEEDS_LOADING)
end

function GrainTransportAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setGrainTransportAIDriverContent(self.vehicle)
end

function GrainTransportAIDriver:start(startingPoint)
	self.vehicle:setCruiseControlMaxSpeed(self.vehicle:getSpeedLimit() or math.huge)
	AIDriver.start(self, startingPoint)
	self.vehicle.cp.settings.stopAtEnd:set(false)
end

function GrainTransportAIDriver:onStart()
	AIDriver.onStart(self)
	self:setupTotalCapacity()
	--get all exactFillRootNodes sorted from the front of the very front vehicle/implement to the last
	self:setupExactFillRootNodes()
	self:changeLoadingAtStartState(self.states.NEEDS_LOADING)
end

function GrainTransportAIDriver:enrichWaypoints()
	AIDriver.enrichWaypoints(self)
	--create WaypointNode for manual loading at the start waitPoint
	self.firstWaypointNode = WaypointNode('firstWaypoint')
	self.firstWaypointNode:setToWaypoint(self.course, 1, true)
end

function GrainTransportAIDriver:resetEnrichedWaypoints()
	--delete WaypointNode for manual loading at the start waitPoint
	if self.firstWaypointNode then
		self.firstWaypointNode:destroy()
	end
end

function GrainTransportAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course for grain transport mode
	return false
end


--TODO: consolidate this with AIDriver:drive() 
function GrainTransportAIDriver:drive(dt)
	-- make sure we apply the unload offset when needed
	self:updateOffset()
	-- update current waypoint/goal point
--	self.ppc:update()

	-- RESET TRIGGER RAYCASTS from drive.lua.
	-- TODO: Not sure how raycast can be called twice if everything is coded cleanly.
	self.vehicle.cp.hasRunRaycastThisLoop['tipTrigger'] = false
	self.vehicle.cp.hasRunRaycastThisLoop['specialTrigger'] = false

	courseplay:updateFillLevelsAndCapacities(self.vehicle)

	-- should we give up control so some other code can drive?
	local giveUpControl = false
	-- should we keep driving?

	local allowedToDrive = true
	if self:getSiloSelectedFillTypeSetting():isEmpty() then 
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_MANUAL_LOADING")
		--checking FillLevels, while loading at StartPoint 
		self:updateFillOrDischargeNodes()
		self:disableFillTypeLoading()
	else 

		if self:isNearFillPoint() then
			self:enableFillTypeLoading()
		else 
			self:disableFillTypeLoading()
		end
	end
		-- TODO: are these checks really necessary?
	if self.vehicle.cp.totalFillLevel ~= nil
		and self.vehicle.cp.tipRefOffset ~= nil
		and self.vehicle.cp.workToolAttached then

		self:searchForTipTriggers()
		allowedToDrive, giveUpControl = self:onUnLoadCourse(allowedToDrive, dt)
	else
		self:debug('Safety check failed')
	end

	-- TODO: clean up the self.allowedToDrives above and use a local copy
	if not allowedToDrive then
		self:hold()
	end
	
	if giveUpControl then
		self.ppc:update()
	--	not sure might need this one for heaps on ground or backwards into bunker silo ?
	--	self.triggerHandler:disableFillTypeUnloading()
		-- unload_tippers does the driving
		return
	else
		-- we drive the course as usual
		AIDriver.drive(self,dt)
	end
end

---Enables loading and disables unloading
function GrainTransportAIDriver:enableFillTypeLoading()
	self.triggerHandler:enableFillTypeLoading()
	self.triggerHandler:disableFillTypeLoading()
	self.triggerHandler:disableFillTypeUnloading()
end

---Enables unloading and disables loading
function GrainTransportAIDriver:disableFillTypeLoading()
	self.triggerHandler:enableFillTypeUnloading()
	self.triggerHandler:enableFillTypeUnloadingBunkerSilo()
	self.triggerHandler:disableFillTypeLoading()
end

---Is fillLevel reached to continue, loading at start
---@param float totalFillLevel of all trailers/ relevant fillUnits
---@return boolean is driveOnAtFillLevel reached ?
function GrainTransportAIDriver:isFillLevelReached(totalFillLevel)
	if totalFillLevel/self.totalFillCapacity*100 >= self:getMaxFillLevel() then 
		return true
	else 
		return false
	end
end

function GrainTransportAIDriver:getMaxFillLevel()
	return self.vehicle.cp.settings.driveOnAtFillLevel:get() or 99
end

function GrainTransportAIDriver:updateLights()
	self.vehicle:setBeaconLightsVisibility(false)
end

function GrainTransportAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeGrainTransportDriver
end

function GrainTransportAIDriver:getSeparateFillTypeLoadingSetting()
	return self.vehicle.cp.settings.separateFillTypeLoading
end

---handle manual Loading at start point
function GrainTransportAIDriver:fillOrUnloadAtTargetPoint()
	local relevantFillOrDischargeNodeData = self.fillOrDischargeNodesData[self.currentClosestRelevantNodeIndex]
	self:openCover(relevantFillOrDischargeNodeData.object,relevantFillOrDischargeNodeData.fillUnitIndex)
	local fillLevel = relevantFillOrDischargeNodeData.object:getFillUnitFillLevel(relevantFillOrDischargeNodeData.fillUnitIndex)
	local capacity = relevantFillOrDischargeNodeData.object:getFillUnitCapacity(relevantFillOrDischargeNodeData.fillUnitIndex)
	--if targetFillRootNode is full, then use the next exactFillRootNode
	if self:isRelevantFillOrDischargeNodeFillLevelReached(capacity,fillLevel) then 
		self.currentClosestRelevantNodeIndex = MathUtil.clamp(self.currentClosestRelevantNodeIndex+1,1,#self.fillOrDischargeNodesData)
		self.nextClosestRelevantNodeDistance = math.huge
		self:closeCover(relevantFillOrDischargeNodeData.object,relevantFillOrDischargeNodeData.fillUnitIndex)
		return
	end
	self:checkFillUnits()
end

function GrainTransportAIDriver:getClosestTargetNodeAndDistance(relevantFillOrDischargeNodeData)
	return self.firstWaypointNode.node,calcDistanceFrom(relevantFillOrDischargeNodeData.rootNode,self.firstWaypointNode.node)
end

--manuel loading at StartPoint
function GrainTransportAIDriver:checkFillUnits()
	local totalFillLevel = self:getTotalFillLevel()

	if self:isFillLevelReached(totalFillLevel) and self.lastTotalFillLevel and self.lastTotalFillLevel == totalFillLevel then 
		self:changeLoadingAtStartState(self.states.NEEDS_UNLOADING)
		self:closeCovers(self.vehicle)
		self:resetFillOrDischargeNodes()
	else 
		self:changeLoadingAtStartState(self.states.NEEDS_LOADING)
	end
	self.lastTotalFillLevel = totalFillLevel
end

---Gets the total fillLevel of all relevant fillUnits
function GrainTransportAIDriver:getTotalFillLevel()
	local totalFillUnitsData = {}
	local totalFillLevel = 0
	self:getFillUnitInfo(self.vehicle,totalFillUnitsData)
	for object, objectData in pairs(totalFillUnitsData) do 
		for fillUnitIndex, fillUnitData in pairs(objectData) do 
			totalFillLevel = totalFillLevel + fillUnitData.fillLevel
		end
	end
	return totalFillLevel
end

---Gets all the relevant fillUnits data recursive
---@param object vehicle/implement/trailer 
---@param table of all relevant fillUnitsData sorted by object and fillUnitIndex
function GrainTransportAIDriver:getFillUnitInfo(object,totalFillUnitsData)
	if object.getFillUnits then 
		totalFillUnitsData[object] = {}
		for fillUnitIndex,fillUnit in pairs(object:getFillUnits()) do 
			local fillType = object:getFillUnitFillType(fillUnitIndex)
			if not AIDriverUtil.isValidFuelType(object,fillType,fillUnitIndex) then 
				totalFillUnitsData[object][fillUnitIndex] = {}
				local capacity = object:getFillUnitCapacity(fillUnitIndex)
				local fillLevel = object:getFillUnitFillLevel(fillUnitIndex)
				totalFillUnitsData[object][fillUnitIndex].capacity = capacity
				totalFillUnitsData[object][fillUnitIndex].fillLevel = fillLevel
				totalFillUnitsData[object][fillUnitIndex].fillType = fillType
			end
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getFillUnitInfo(impl.object,totalFillUnitsData)
	end
end

function GrainTransportAIDriver:continue()
	AIDriver.continue(self)
	self:changeLoadingAtStartState(self.states.NEEDS_UNLOADING)
	self:resetFillOrDischargeNodes()
end

function GrainTransportAIDriver:setDriveNow()
	self:changeLoadingAtStartState(self.states.NEEDS_UNLOADING)
	AIDriver.setDriveNow(self)
	self:resetFillOrDischargeNodes()
end

function GrainTransportAIDriver:getCanShowDriveOnButton() 
	return self.loadingAtStartState == self.states.NEEDS_LOADING or AIDriver.getCanShowDriveOnButton(self)
end

---Gets the total capacity of all relevant fillUnits
function GrainTransportAIDriver:setupTotalCapacity()
	local tempCapacityTable = {}
	AIDriverUtil.getTotalFillCapacity(self.vehicle,tempCapacityTable)
	self.totalFillCapacity = tempCapacityTable.capacity or 0
end

function GrainTransportAIDriver:isRelevantFillOrDischargeNodeFillLevelReached(capacity,fillLevel)
	return capacity-fillLevel < 0.02
end

function GrainTransportAIDriver:isAllowedToStopAtTargetNode(closestTargetNodeDistance)
	return AIDriver.isAllowedToStopAtTargetNode(self,closestTargetNodeDistance) and self.loadingAtStartState == self.states.NEEDS_LOADING
end

function GrainTransportAIDriver:changeLoadingAtStartState(state)
	if state ~= self.loadingAtStartState then
		self.loadingAtStartState = state
		self:debug("loadingAtStartState => "..tostring(state.name))
	end
end

function GrainTransportAIDriver:onFirstWaypoint() 
	AIDriver.onFirstWaypoint(self)
	self:changeLoadingAtStartState(self.states.NEEDS_LOADING)
end