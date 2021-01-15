
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
--[[
Field Supply AI Driver to let fill tools with digestate or liquid manure on the field egde
Also known as mode 8
]]

---@class FieldSupplyAIDriver : GrainTransportAIDriver
FieldSupplyAIDriver = CpObject(GrainTransportAIDriver)

FieldSupplyAIDriver.myStates = {
	TO_BE_UNLOADED = {},
	UNLOAD_DONE = {}
}

--- Constructor
function FieldSupplyAIDriver:init(vehicle)
	GrainTransportAIDriver.init(self, vehicle)
	self:initStates(FieldSupplyAIDriver.myStates)
	self.unloadState = self.states.TO_BE_UNLOADED
end

function FieldSupplyAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setFieldSupplyAIDriverContent(self.vehicle)
end

function FieldSupplyAIDriver:start(startingPoint)
	AIDriver.start(self,startingPoint)
	self:setupTotalCapacity()
	self:setupDischargeRootNodes()
	self:findPipe()
	self.unloadState = self.states.TO_BE_UNLOADED
	self.vehicle.cp.settings.stopAtEnd:set(false)
end


function FieldSupplyAIDriver:enrichWaypoints()
	--create WaypointNodes for all waitPoints
	AIDriver.enrichWaypoints(self)
	self.course:enrichWaitPoints()
end

function FieldSupplyAIDriver:resetEnrichedWaypoints()
	--delete all WaypointNodes, which where created for waitPoints
	self.course:resetEnrichedWaitPoints()
end


function FieldSupplyAIDriver:isProximitySwerveEnabled()
	return AIDriver.isProximitySwerveEnabled(self) and not self:isNearWaitPointNode()
end

function FieldSupplyAIDriver:drive(dt)
	---course has no waitPoints, wrong course setup!
	if not self.course:hasWaitPointNodes() then
		self:setInfoText('COURSEPLAY_NO_VALID_COURSE')
		self:setSpeed(0)
	---no loading FillType selected!
	elseif self:getSiloSelectedFillTypeSetting():isEmpty() then 
		self:setInfoText('NO_SELECTED_FILLTYPE')
		self:setSpeed(0)
	else
		self:clearInfoText('COURSEPLAY_NO_VALID_COURSE')
		self:clearInfoText('NO_SELECTED_FILLTYPE')
		self:updateFillOrDischargeNodes()
		if courseplay.debugChannels[2] then
			CourseUtil.drawDebugWaitPointsNodes(self.course)
		end
		if self:isNearWaitPointNode() then
			self:openPipe()
			if self.unloadState == self.states.TO_BE_UNLOADED then 
				---near a waitPoint, so allow unloading and disallow loading 
				self.triggerHandler:enableFillTypeUnloading()
				self.triggerHandler:disableFillTypeLoading()
			else 
				self:clearInfoText('REACHED_REFILLING_POINT')
				self.triggerHandler:disableFillTypeLoading()
				self.triggerHandler:disableFillTypeUnloading()
			end
		else 
			self:closePipe()
			self.triggerHandler:enableFillTypeLoading()
			self.triggerHandler:disableFillTypeUnloading()
			self:clearInfoText('REACHED_REFILLING_POINT')
		end
	end
	if self:isPipeMoving() then 
		self:setSpeed(0)
	end

	AIDriver.drive(self,dt)
end

---check if we have an augerWagon with pipe attached
function FieldSupplyAIDriver:findPipe()
    local implementWithPipe = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Pipe)
    if implementWithPipe then
        self.pipe = implementWithPipe
    end
end

function FieldSupplyAIDriver:closePipe() 
	if self.pipe then
		if not self:isPipeMoving() and self.pipe.currentState ~= AIDriverUtil.PIPE_STATE_CLOSED then
			self.pipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
		end
	end
end

function FieldSupplyAIDriver:openPipe() 
	if self.pipe then
		if not self:isPipeMoving() and self.pipe.currentState ~= AIDriverUtil.PIPE_STATE_OPEN then
			self.pipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
		end
	end
end

function FieldSupplyAIDriver:isPipeMoving() 
	return self.pipe and self.pipe.currentState == AIDriverUtil.PIPE_STATE_MOVING or false
end

function FieldSupplyAIDriver:getSiloSelectedFillTypeSetting()
	return self.vehicle.cp.settings.siloSelectedFillTypeFieldSupplyDriver
end

function FieldSupplyAIDriver:getClosestTargetNodeAndDistance(relevantFillOrDischargeNodeData)
	return self.course:getClosestWaitPointNode(relevantFillOrDischargeNodeData.rootNode)
end

function FieldSupplyAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	--- Check if we are at the last waypoint and should we continue with first waypoint of the course
	-- or stop.
	if ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	elseif self.course:isWaitAt(ix) then
		local totalFillLevel = self:getTotalFillLevel()
		if not self:isFillLevelReached(totalFillLevel) then
			self.unloadState = self.states.TO_BE_UNLOADED
		end
	end
end

---implement/trailer is empty, so update the next Target node 
function FieldSupplyAIDriver:isRelevantFillOrDischargeNodeFillLevelReached(capacity,fillLevel)
	return fillLevel <= capacity*0.01
end

---isFillLevelReached to continue from wait point
---@param float totalFillLevel of all relevant fillUnits
---@return boolean allowed to continue driving
function FieldSupplyAIDriver:isFillLevelReached(totalFillLevel)
	local totalFillLevelPercentage = totalFillLevel/self.totalFillCapacity*100
	local minFillLevel = self.vehicle.cp.settings.moveOnAtFillLevel:get()
	self:debugSparse(string.format("totalFillLevelPercentage: %.1f <= minFillLevel: %.1f",totalFillLevelPercentage,minFillLevel))
	return totalFillLevelPercentage <= minFillLevel
end

function FieldSupplyAIDriver:isNearWaitPointNode()
	return self.nextClosestRelevantNodeDistance == math.huge or self.nextClosestRelevantNodeDistance<15
end

function FieldSupplyAIDriver:isAllowedToStopAtTargetNode(closestTargetNodeDistance)
	return AIDriver.isAllowedToStopAtTargetNode(self,closestTargetNodeDistance) and self.unloadState == self.states.TO_BE_UNLOADED
end

function FieldSupplyAIDriver:checkFillUnits()
	local totalFillLevel = self:getTotalFillLevel()

	if self:isFillLevelReached(totalFillLevel) and self.lastTotalFillLevel and self.lastTotalFillLevel == totalFillLevel then 
		self.unloadState = self.states.UNLOAD_DONE
		self:resetFillOrDischargeNodes()
		local totalFillUnitsData = {}
		self:getFillUnitInfo(self.vehicle,totalFillUnitsData)
		self:closeCovers(self.vehicle)
	end
	self.lastTotalFillLevel = totalFillLevel
end

function FieldSupplyAIDriver:continue()
	GrainTransportAIDriver.continue(self)
	self.unloadState = self.states.UNLOAD_DONE
end

function FieldSupplyAIDriver:setDriveNow()
	AIDriver.setDriveNow(self)
	self:resetFillOrDischargeNodes()
	self.unloadState = self.states.UNLOAD_DONE
end

function FieldSupplyAIDriver:getCanShowDriveOnButton() 
	return AIDriver.getCanShowDriveOnButton(self) or self.unloadState == self.states.TO_BE_UNLOADED
end