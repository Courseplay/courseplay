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
end

function GrainTransportAIDriver:setHudContent()
	AIDriver.setHudContent(self)
	courseplay.hud:setGrainTransportAIDriverContent(self.vehicle)
end

function GrainTransportAIDriver:start(startingPoint)
	self.readyToLoadManualAtStart = false
	self.nextClosestExactFillRootNode = nil
	self.vehicle:setCruiseControlMaxSpeed(self.vehicle:getSpeedLimit() or math.huge)
	AIDriver.start(self, startingPoint)
	self.vehicle.cp.settings.stopAtEnd:set(false)
	self.firstWaypointNode = WaypointNode('firstWaypoint')
	self.firstWaypointNode:setToWaypoint(self.course, 1, true)
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
			if self.nextClosestExactFillRootNode then 
				--drive until the closest exactFillRootNode/fillUnit is at the first Waypoint
				self:setSpeed(3)
				if self.nextClosestExactFillRootNodeDistance == nil then
					 self.nextClosestExactFillRootNodeDistance = math.huge
				end
				local d = calcDistanceFrom(self.firstWaypointNode.node, self.nextClosestExactFillRootNode)
				if d < self.nextClosestExactFillRootNodeDistance then 
					self.nextClosestExactFillRootNodeDistance = d
				else 
					self:hold()
				end
			else
				self:hold()
			end
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
		self.triggerHandler:enableFillTypeUnloadingBunkerSilo()
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
	--	not sure might need this one for heaps on ground or backwards into bunker silo ?
	--	self.triggerHandler:disableFillTypeUnloading()
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
				self:openCovers(self.vehicle)			
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
	local distance = math.huge
	local nextClosestExactFillRootNode
	self:getFillUnitInfo(self.vehicle,totalFillUnitsData)
	for object, objectData in pairs(totalFillUnitsData) do 
		for fillUnitIndex, fillUnitData in pairs(objectData) do 
			totalFillLevel = totalFillLevel + fillUnitData.fillLevel
			--get the closest exactFillRootNode/fillUnit 
			if fillUnitData.exactFillRootNode and fillUnitData.fillLevel/fillUnitData.capacity*100 < 99 then 
				local d = calcDistanceFrom(self.firstWaypointNode.node, fillUnitData.exactFillRootNode)
				if d < distance then
					distance = d
					nextClosestExactFillRootNode = fillUnitData.exactFillRootNode
				end
			end
		end
	end
	if nextClosestExactFillRootNode ~= self.nextClosestExactFillRootNode then 
		self.nextClosestExactFillRootNodeDistance = nil
		self.nextClosestExactFillRootNode = nextClosestExactFillRootNode
	end		
	if g_updateLoopIndex % 2 == 0 and self:isFillLevelReached(totalFillLevel) and self.lastTotalFillLevel and self.lastTotalFillLevel == totalFillLevel then 
		self.readyToLoadManualAtStart = false
		self.nextClosestExactFillRootNode = nil
		local totalFillUnitsData = {}
		self:getFillUnitInfo(self.vehicle,totalFillUnitsData)
		self:closeCovers(self.vehicle)
	end
	self.lastTotalFillLevel = totalFillLevel
end

function GrainTransportAIDriver:getFillUnitInfo(object,totalFillUnitsData)
	local spec = object.spec_fillUnit
	if spec and object.spec_trailer then 
		totalFillUnitsData[object] = {}
		for fillUnitIndex,fillUnit in pairs(object:getFillUnits()) do 
			local fillType = object:getFillUnitFillType(fillUnitIndex)
			if not self:isValidFuelType(object,fillType,fillUnitIndex) then 
				totalFillUnitsData[object][fillUnitIndex] = {}
				local capacity = object:getFillUnitCapacity(fillUnitIndex)
				local fillLevel = object:getFillUnitFillLevel(fillUnitIndex)
				totalFillUnitsData[object][fillUnitIndex].capacity = capacity
				totalFillUnitsData[object][fillUnitIndex].fillLevel = fillLevel
				totalFillUnitsData[object][fillUnitIndex].fillType = fillType
				totalFillUnitsData[object][fillUnitIndex].exactFillRootNode = object:getFillUnitExactFillRootNode(fillUnitIndex)
			end
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:getFillUnitInfo(impl.object,totalFillUnitsData)
	end
end

function GrainTransportAIDriver:continue()
	self.nextClosestExactFillRootNode = nil
	AIDriver.continue(self)
end

function GrainTransportAIDriver:setDriveNow()
	self.driveNow = true
	self.readyToLoadManualAtStart = false
	self.nextClosestExactFillRootNode = nil
	AIDriver.setDriveNow(self)
end

function GrainTransportAIDriver:getCanShowDriveOnButton() 
	return self.readyToLoadManualAtStart or AIDriver.getCanShowDriveOnButton(self)
end

function GrainTransportAIDriver:stop(stopMsg)
	if self.firstWaypointNode then
		self.firstWaypointNode:destroy()
	end
	self.nextClosestExactFillRootNode = nil
	AIDriver.stop(self,stopMsg)
end

function GrainTransportAIDriver:delete()
	if self.firstWaypointNode then
		self.firstWaypointNode:destroy()
	end
	AIDriver.delete(self)
end
