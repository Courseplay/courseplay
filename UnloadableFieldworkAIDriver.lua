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
Fieldwork AI Driver for harvesting vehicles which need to unload material to continue

Also known as mode 6.

]]

---@class UnloadableFieldworkAIDriver : FieldworkAIDriver
UnloadableFieldworkAIDriver = CpObject(FieldworkAIDriver)
-- at which fill level we need to unload. We want to have a little buffer there
-- as we won't raise our implements until we stopped and during that time we keep
-- harvesting
UnloadableFieldworkAIDriver.normalFillLevelFullPercentage = 99.5
UnloadableFieldworkAIDriver.fillLevelFullPercentage = UnloadableFieldworkAIDriver.normalFillLevelFullPercentage
-- at which fill level we consider ourselves unloaded
UnloadableFieldworkAIDriver.fillLevelEmptyPercentage = 0.1

function UnloadableFieldworkAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'UnloadableFieldworkAIDriver:init()') 
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(UnloadableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_FIELDWORK
	self.stopImplementsWhileUnloadOrRefillOnField = false
end

function UnloadableFieldworkAIDriver:setHudContent()
	FieldworkAIDriver.setHudContent(self)
	courseplay.hud:setUnloadableFieldworkAIDriverContent(self.vehicle)
end

function UnloadableFieldworkAIDriver.create(vehicle)
	if AIDriverUtil.hasAIImplementWithSpecialization(vehicle, BaleLoader) then
		return BaleLoaderAIDriver(vehicle)
	elseif AIDriverUtil.hasAIImplementWithSpecialization(vehicle, BaleWrapper) then
		-- Bale wrapper is derived from baler so must check it first to make sure that we instantiate a
		-- BaleWrapperAIDriver if we have both the baler and the balewrapper specialization
		return BaleWrapperAIDriver(vehicle)
	elseif AIDriverUtil.hasAIImplementWithSpecialization(vehicle, Baler) then
		return BalerAIDriver(vehicle)
	elseif SpecializationUtil.hasSpecialization(Combine, vehicle.specializations) or
		AIDriverUtil.hasAIImplementWithSpecialization(vehicle, Combine) then
		return CombineAIDriver(vehicle)
	elseif SpecializationUtil.hasSpecialization(Plow, vehicle.specializations) or
		AIDriverUtil.hasAIImplementWithSpecialization(vehicle, Plow) then
		return PlowAIDriver(vehicle)
	else
		return UnloadableFieldworkAIDriver(vehicle)
	end
end

-- Bale loaders / wrappers have no AI markers
function UnloadableFieldworkAIDriver.getAIMarkersFromGrabberNode(object, spec)
	-- use the grabber node for all markers if exists
	if spec.baleGrabber and spec.baleGrabber.grabNode then
		return spec.baleGrabber.grabNode, spec.baleGrabber.grabNode, spec.baleGrabber.grabNode
	else
		return object.rootNode, object.rootNode, object.rootNode
	end
end

function UnloadableFieldworkAIDriver:drive(dt)
	-- only reason we need this is to update the totalFillLevel for reverse.lua so it will
	-- do a raycast for tip triggers (side effects, side effects all over the place, killing me...)
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	-- the rest is the same as the parent class
	FieldworkAIDriver.drive(self, dt)
end

--- Full during fieldwork
function UnloadableFieldworkAIDriver:changeToFieldworkUnloadOrRefill()
	self:debug('change to fieldwork unload')
	if not self.heldForUnloadRefill and not self:shouldStopForUnloading() then
		self:setInfoText(self:getFillLevelInfoText())
	end
	FieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
end

---@return boolean true if unload took over the driving
function UnloadableFieldworkAIDriver:driveUnloadOrRefill(dt)
	self:updateOffset()
	local allowedToDrive = true
	local isNearUnloadPoint, unloadPointIx = self.course:hasUnloadPointWithinDistance(self.ppc:getCurrentWaypointIx(),20)
	-- by default, drive street/recorded speed.
	self:setSpeed(self:getRecordedSpeed())
	if not self.ppc:isReversing() then
		-- 'cause reverse does the raycasting for us
		self:searchForTipTriggers()
	end
	local takeOverSteering = FieldworkAIDriver.driveUnloadOrRefill(self)
	if self.vehicle.cp.totalFillLevel > 0 then
		if self:hasTipTrigger() then
			-- unload at tip trigger
			self:setSpeed(self.vehicle.cp.speeds.approach)
			allowedToDrive, takeOverSteering = self:dischargeAtTipTrigger(dt)
			courseplay:setInfoText(self.vehicle,"COURSEPLAY_TIPTRIGGER_REACHED");
			self:setSpeed(self.vehicle.cp.speeds.turn)
		end
	end
	
	-- tractor reaches unloadPoint
	if isNearUnloadPoint then
		self:setSpeed(self.vehicle.cp.speeds.approach)
		courseplay:setInfoText(self.vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
		allowedToDrive, takeOverSteering = self:dischargeAtUnloadPoint(dt,unloadPointIx)
	end
	
	if not allowedToDrive then
		self:setSpeed(0)
	end
		
	-- done tipping?
	if self:hasTipTrigger() and self.vehicle.cp.totalFillLevel <= 10 then
		courseplay:resetTipTrigger(self.vehicle, true);
	end
		
	return takeOverSteering
end

--- Interface for AutoDrive
---@return boolean true when the tool is waiting to be unloaded
function UnloadableFieldworkAIDriver:isWaitingForUnload()
	return self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL
end


--- Check if need to unload anything
-- TODO: can this be refactored using FieldworkAIDriver.allFillLevelsOk()?
function UnloadableFieldworkAIDriver:allFillLevelsOk()
	if not self.vehicle.cp.workTools then return false end
	local allOk = true
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		allOk = self:fillLevelsOk(workTool) and allOk
	end
	return allOk
end

--- Check fill levels in all tools and stop when one of them isn't ok
function UnloadableFieldworkAIDriver:fillLevelsOk(workTool)
	if workTool.getFillUnits then
		for index, fillUnit in pairs(workTool:getFillUnits()) do
			-- let's see if we can get by this abstraction for all kinds of tools
			local ok = self:isLevelOk(workTool, index, fillUnit)
			if not ok then
				return false
			end
		end
	end
	-- all fill levels ok
	return true
end

-- is the fill level ok to continue? With unloadable tools we need to stop working when the tool is full
-- with fruit
function UnloadableFieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	local pc = 100 * workTool:getFillUnitFillLevelPercentage(index)
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnit.fillType)
	if self:shouldStopForUnloading(pc) then
		self:debugSparse('Stop for unloading: %s: %.2f', fillTypeName, pc )
		return false
	end
	if self:isValidFillType(fillUnit.fillType) and pc > self.fillLevelFullPercentage then
		self:debugSparse('Full: %s: %.2f', fillTypeName, pc )
		return false
	end
	self:debugSparse('Fill levels: %s: %.2f', fillTypeName, pc )
	return true
end

function UnloadableFieldworkAIDriver:shouldStopForUnloading(pc)
	return false
end


--- Get the first valid (non-fuel) fill type
function UnloadableFieldworkAIDriver:getFillType()
	if not self.vehicle.cp.workTools then return end
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		if workTool.getFillUnits then
			for _, fillUnit in pairs(workTool:getFillUnits()) do
				if self:isValidFillType(fillUnit.fillType) then
					return fillUnit.fillType
				end
			end
		end
	end
	return nil
end

function UnloadableFieldworkAIDriver:isValidFillType(fillType)
	return fillType ~= FillType.DIESEL and fillType ~= FillType.DEF	and fillType ~= FillType.AIR
end

function UnloadableFieldworkAIDriver:atUnloadWaypoint()
	return self.course:isUnloadAt(self.ppc:getCurrentWaypointIx())
end

--- Update the unload offset from the current settings and apply it when needed
function UnloadableFieldworkAIDriver:updateOffset()
	local currentWaypointIx = self.ppc:getCurrentWaypointIx()

	if self.course:hasUnloadPointAround(currentWaypointIx, 6, 3) then
		-- around unload points
		self.ppc:setOffset(self.vehicle.cp.loadUnloadOffsetX, self.vehicle.cp.loadUnloadOffsetZ)
	else
		self.ppc:setOffset(0, 0)
	end
end

function UnloadableFieldworkAIDriver:getFillLevelInfoText()
	return 'NEEDS_UNLOADING'
end

function UnloadableFieldworkAIDriver:setLightsMask(vehicle)
	local x,y,z = getWorldTranslation(vehicle.rootNode);
	if not courseplay:isField(x, z) and self.state == self.states.ON_UNLOAD_OR_REFILL_COURSE then
		vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_STREET)
	else
		vehicle:setLightsTypesMask(courseplay.lights.HEADLIGHT_FULL)
	end
end
