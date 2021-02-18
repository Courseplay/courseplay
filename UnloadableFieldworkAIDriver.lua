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
	self.refillUntilPct = vehicle.cp.settings.refillUntilPct
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
    elseif FS19_addon_strawHarvest and AIDriverUtil.hasAIImplementWithSpecialization(vehicle, FS19_addon_strawHarvest.StrawHarvestPelletizer) then
        return CombineAIDriver(vehicle)
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
	self.triggerHandler:disableFillTypeUnloading()
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
	self.triggerHandler:enableFillTypeUnloading()
	self.triggerHandler:enableFillTypeUnloadingBunkerSilo()
		
	-- TODO: refactor that whole unload process, it was just copied from the legacy CP code
	self:searchForTipTriggers()
	local allowedToDrive, giveUpControl = self:onUnLoadCourse(true, dt)
	if not allowedToDrive then
		self:hold()
	end	
	if giveUpControl then 
		return true
	end
	FieldworkAIDriver.driveUnloadOrRefill(self,dt)
	return false
end

--- Interface for AutoDrive
---@return boolean true when the tool is waiting to be unloaded
function UnloadableFieldworkAIDriver:isWaitingForUnload()
	return self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldworkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL
end

function UnloadableFieldworkAIDriver:areFillLevelsOk(fillLevelInfo)	
	for fillType, info in pairs(fillLevelInfo) do
		if self:isValidFillType(fillType) then 
			local percentage =  info.fillLevel/info.capacity*100 
			if info.fillLevel >= info.capacity or percentage > self.refillUntilPct:get() or percentage> self.fillLevelFullPercentage  then
				self:debugSparse('Full or refillUntilPct reached: %.2f', percentage)
				return false
			end
			if self:shouldStopForUnloading(percentage) then
				self:debugSparse('Stop for unloading: %.2f', percentage)
				return false
			end
		end
	end
	return true
end

function UnloadableFieldworkAIDriver:shouldStopForUnloading(pc)
	return false
end

function UnloadableFieldworkAIDriver:isValidFillType(fillType)
	return not self:isValidFuelType(self.vehicle,fillType) and fillType ~= FillType.DEF	and fillType ~= FillType.AIR 
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

function UnloadableFieldworkAIDriver:setDriveNow()
	if self.state == self.states.ON_FIELDWORK_COURSE then
		self:stopAndChangeToUnload()
	else
		AIDriver.setDriveNow(self)
	end
end
