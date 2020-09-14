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

--- Constructor
function GrainTransportAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'GrainTransportAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_GRAIN_TRANSPORT
	self.totalFillCapacity = 0
	-- just for backwards compatibility
end

function GrainTransportAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setGrainTransportAIDriverContent(self.vehicle)
end

function GrainTransportAIDriver:start(startingPoint)
	self.readyToLoadManualAtStart = false
	self.vehicle:setCruiseControlMaxSpeed(self.vehicle:getSpeedLimit() or math.huge)
	AIDriver.start(self, startingPoint)
	self:setDriveUnloadNow(false);
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
		if self.readyToLoadManualAtStart then 
			self:setInfoText('REACHED_OVERLOADING_POINT')
			self:checkFillUnits()
			self:hold()
		else
			self:clearInfoText('REACHED_OVERLOADING_POINT')
		end	
	end

	if self:isNearFillPoint() then
		if not self:getSiloSelectedFillTypeSetting():isEmpty() then
			self.triggerHandler:enableFillTypeLoading()
		else 
			self.triggerHandler:disableFillTypeLoading()
		end
		self.triggerHandler:disableFillTypeUnloading()
	else 
		self.triggerHandler:enableFillTypeUnloading()
		self.triggerHandler:disableFillTypeLoading()
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
		-- unload_tippers does the driving
		return
	else
		-- we drive the course as usual
		AIDriver.drive(self,dt)
	end
end

function GrainTransportAIDriver:onWaypointPassed(ix)
	--firstWaypoint/ start, check if we are in a LoadTrigger or FillTrigger else loading at StartPoint
	if ix == 1 then 
		if self:getSiloSelectedFillTypeSetting():isEmpty() and not self.driveNow then 
			local totalFillUnitsData = {}
			self.totalFillCapacity = 0
			local totalFillLevel = 0
			self:getFillUnitInfo(self.vehicle,totalFillUnitsData)
			for object, objectData in pairs(totalFillUnitsData) do 
				for fillUnitIndex, fillUnitData in pairs(objectData) do 
					self.totalFillCapacity = self.totalFillCapacity + fillUnitData.capacity
					totalFillLevel = totalFillLevel + fillUnitData.fillLevel
				end
			end
			if not self:isFillLevelReached(totalFillLevel) then 
				self.readyToLoadManualAtStart = true
				for object, objectData in pairs(totalFillUnitsData) do 
					for fillUnitIndex, fillUnitData in pairs(objectData) do 
						SpecializationUtil.raiseEvent(object, "onAddedFillUnitTrigger",fillUnitData.fillType,fillUnitIndex,1)
					end
				end
			end
		end
	elseif ix>1 then 
		self.driveNow=false
	end
	AIDriver.onWaypointPassed(self,ix)
end

function GrainTransportAIDriver:isFillLevelReached(totalFillLevel)
	if totalFillLevel/self.totalFillCapacity*100 >= self:getMaxFillLevel() then 
		return true
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

function GrainTransportAIDriver:getSeperateFillTypeLoadingSetting()
	return self.vehicle.cp.settings.seperateFillTypeLoading
end

--manuel loading at StartPoint
function GrainTransportAIDriver:checkFillUnits()
	local maxNeeded = self.vehicle.cp.settings.driveOnAtFillLevel:get()
	local totalFillUnitsData = {}
	local totalFillLevel = 0
	self:getFillUnitInfo(self.vehicle,totalFillUnitsData)
	for object, objectData in pairs(totalFillUnitsData) do 
		for fillUnitIndex, fillUnitData in pairs(objectData) do 
			totalFillLevel = totalFillLevel + fillUnitData.fillLevel
		end
	end
	if self:isFillLevelReached(totalFillLevel) then 
		self.readyToLoadManualAtStart = false
		local totalFillUnitsData = {}
		self:getFillUnitInfo(self.vehicle,totalFillUnitsData)
		for object, objectData in pairs(totalFillUnitsData) do 
			SpecializationUtil.raiseEvent(object, "onRemovedFillUnitTrigger",0)
		end
	end
end

function GrainTransportAIDriver:getFillUnitInfo(object,totalFillUnitsData)
	local spec = object.spec_fillUnit
	if spec and object.spec_trailer then 
		totalFillUnitsData[object] = {}
		for fillUnitIndex,fillUnit in pairs(object:getFillUnits()) do 
			totalFillUnitsData[object][fillUnitIndex] = {}
			local capacity = object:getFillUnitCapacity(fillUnitIndex)
			local fillLevel = object:getFillUnitFillLevel(fillUnitIndex)
			local fillType = object:getFillUnitFillType(fillUnitIndex)
			totalFillUnitsData[object][fillUnitIndex].capacity = capacity
			totalFillUnitsData[object][fillUnitIndex].fillLevel = fillLevel
			totalFillUnitsData[object][fillUnitIndex].fillType = fillType
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getFillUnitInfo(impl.object,totalFillUnitsData)
	end
end

function GrainTransportAIDriver:setDriveNow()
	self.driveNow = true
	AIDriver.setDriveNow(self)
end

function GrainTransportAIDriver:getCanShowDriveOnButton() 
	return self.readyToLoadManualAtStart or AIDriver.getCanShowDriveOnButton(self)
end

