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


---@class CompactingAIDriver : BunkerSiloAIDriver
CompactingAIDriver = CpObject(BunkerSiloAIDriver)

CompactingAIDriver.myStates = {
	WAITING_FOR_UNLOADERS = {},
	NOTHING = {}
}

function CompactingAIDriver:init(vehicle)
	BunkerSiloAIDriver.init(self,vehicle)
	self:initStates(CompactingAIDriver.myStates)
	self.debugChannel = 10
	self.compactingState = self.states.NOTHING 
	self.mode = courseplay.MODE_BUNKERSILO_COMPACTER
end

function CompactingAIDriver:onDraw()
	AIDriver.onDraw(self)
	--- TODO: this needs improvements, as currently vehicle.Waypoints is needed.
	if self.vehicle.Waypoints and self.vehicle.cp.canDrive then 
		local searchRadiusSetting = self.settings.levelCompactSearchRadius
		searchRadiusSetting:update()
		if searchRadiusSetting:isShowRadiusActive() then 
			local lastIx = #self.vehicle.Waypoints
			local wps = self.vehicle.Waypoints
			local x,y,z = wps[lastIx].cx,wps[lastIx].cy,wps[lastIx].cz
			local r = searchRadiusSetting:get()
			cpDebug:drawCircle(x, y+3, z,r,math.ceil(r/2), 1, 1, 1)
		end	
	end
end

function CompactingAIDriver:setHudContent()
	BunkerSiloAIDriver.setHudContent(self)
	courseplay.hud:setLevelCompactAIDriverContent(self.vehicle)
end

function CompactingAIDriver:start(startingPoint)
	--- Clean up old waypoint node.
	self.relevantWaypointNode = nil
	BunkerSiloAIDriver.start(self,startingPoint)
end

function CompactingAIDriver:drive(dt)

	--- Gets the search radius.
	local normalRadius = self.settings.levelCompactSearchRadius:get()
	--- Enlarge the searchRadius for waiting at waitpoint to avoid traffic problems
	local searchRadius = self:isWaitingForUnloaders() and normalRadius + 10 or normalRadius
	--- Searches for unloaders and restart/hold them in place.
	if self:foundUnloaderInRadius(searchRadius,not self:isWaitingForUnloaders()) then 
		self.hasFoundUnloaders = true
	else 
		self.hasFoundUnloaders = false
	end
	--- If the wait point is reached, wait until the unloader has finished.
	if self:isWaitingForUnloaders() then 
		self:hold()
		if not self.hasFoundUnloaders then
			self.compactingState = self.states.NOTHING
			self:clearInfoText('WAITING_FOR_UNLOADERS')
		else 
			self:setInfoText('WAITING_FOR_UNLOADERS')
		end
	end

	BunkerSiloAIDriver.drive(self,dt)
end

---search for unloaders nearby
---@param r number radius to search from the last main course waypoint 
---@param setWaiting boolean if true then set the cp driver to wait else reset waiting if needed
---@return true if valid unloader is nearby
function CompactingAIDriver:foundUnloaderInRadius(r,setWaiting)
	if not g_currentMission then
		return
	end

	if self.relevantWaypointNode == nil then 
		self.relevantWaypointNode = WaypointNode('relevantWaypointNode')
		self.relevantWaypointNode:setToWaypoint(self.course,self.course:getNumberOfWaypoints() , true)
	end
	if self:isSiloDebugActive() then
		local x,y,z = getTranslation(self.relevantWaypointNode.node)
		DebugUtil.drawDebugCircle(x,y+2,z, r, math.ceil(r/2))
	end
	local onlyStopFilledDrivers = self.settings.levelCompactSiloTyp:get()
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if vehicle ~= self.vehicle then
			local d = calcDistanceFrom(self.relevantWaypointNode.node, vehicle.rootNode)
			if d < r then
				local autodriveSpec = vehicle.spec_autodrive 
				if courseplay:isAIDriverActive(vehicle) and vehicle.cp.driver.triggerHandler:isAllowedToUnloadAtBunkerSilo() then
					--CombineUnloadAIDriver,GrainTransportAIDriver,UnloadableFieldworkAIDriver
					local isOkayToStop = true
					if onlyStopFilledDrivers then 
						if vehicle.cp.totalFillLevel < 0.02 then 
							isOkayToStop = false
						end
					end
					
					if setWaiting and isOkayToStop then 
						vehicle.cp.driver:hold()
						vehicle.cp.driver:setInfoText("WAITING_FOR_LEVELCOMPACTAIDRIVER")
						vehicle.cp.driver:disableTrafficConflictDetection()
					else 
						vehicle.cp.driver:clearInfoText("WAITING_FOR_LEVELCOMPACTAIDRIVER")
						vehicle.cp.driver:enableTrafficConflictDetection()
					end
					self:debugSparse("found cp driver : %s",nameNum(vehicle))
					return isOkayToStop
				elseif autodriveSpec and autodriveSpec.HoldDriving and vehicle.ad.stateModule and vehicle.ad.stateModule:isActive() then 
					--autodrive
					if setWaiting then
						autodriveSpec:HoldDriving(vehicle)
					end
					self:debugSparse("found autodrive driver : %s",nameNum(vehicle))
					return true
				elseif vehicle.getIsEntered and (vehicle:getIsEntered() or vehicle:getIsControlled()) and (AIDriverUtil.hasImplementWithSpecialization(vehicle, Trailer) or vehicle.spec_trailer) then 
					--Player controlled vehicle
					if self.settings.levelCompactSearchOnlyAutomatedDriver:is(false) then
						--Player controlled vehicle is allowed to lookup
						self:debugSparse("found player driven vehicle : %s",nameNum(vehicle))
						return true
					end
				end
			end
		end
	end
end

function CompactingAIDriver:beforeDriveIntoSilo()
	self:lowerImplements()
	BunkerSiloAIDriver.beforeDriveIntoSilo(self)
end

function CompactingAIDriver:beforeDriveOutOfSilo()
	self:raiseImplements()
	BunkerSiloAIDriver.beforeDriveOutOfSilo(self)
end

--- Has the driver reached the wait point and is waiting for the unloader?
function CompactingAIDriver:isWaitingForUnloaders()
	return self.compactingState == self.states.WAITING_FOR_UNLOADERS
end 

--- If an unloader was found, continue with the main course.
function CompactingAIDriver:getCanContinueDrivingSiloCourse()
	return not self.hasFoundUnloaders
end

function CompactingAIDriver:onWaypointPassed(ix)
	if self.course:isWaitAt(ix) then
		self.compactingState = self.states.WAITING_FOR_UNLOADERS
	end
	BunkerSiloAIDriver.onWaypointPassed(self, ix)
end

--- Override this function, as the stopping at wait point gets handled separately.
function CompactingAIDriver:isStoppingAtWaitPointAllowed()
	return false
end

function CompactingAIDriver:lowerImplements()
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	self.vehicle:requestActionEventUpdate()
	for _, implement in pairs(self.vehicle:getAttachedImplements()) do
		if implement.object.aiImplementStartLine then
			implement.object:aiImplementStartLine()
		end
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)
end

function CompactingAIDriver:raiseImplements()
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
	self.vehicle:requestActionEventUpdate()
	for _, implement in pairs(self.vehicle:getAttachedImplements()) do
		if implement.object.aiImplementEndLine then
			implement.object:aiImplementEndLine()
		end
	end
	self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
end