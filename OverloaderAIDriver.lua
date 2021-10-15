--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2020 Peter Vaiko

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
]]--

---@class OverloaderAIDriver : CombineUnloadAIDriver
OverloaderAIDriver = CpObject(CombineUnloadAIDriver)

OverloaderAIDriver.myStates = {
    ENROUTE = {},
    WAITING_FOR_TRAILER = {},
    WAITING_FOR_OVERLOAD_TO_START = {},
    OVERLOADING = {},
}

OverloaderAIDriver.MIN_SPEED_UNLOAD_COURSE = 10
OverloaderAIDriver.FILL_LEVEL_THRESHOLD = 0.99 -- 99%

function OverloaderAIDriver:init(vehicle)
    --there seems to be a bug, where "vehicle" is not always set once start is pressed
	CombineUnloadAIDriver.init(self, vehicle)
    self:initStates(OverloaderAIDriver.myStates)
    self.mode = courseplay.MODE_OVERLOADER
	self.debugChannel = courseplay.DBG_MODE_3
    self:debug('OverloaderAIDriver:init()')
	self.unloadCourseState = self.states.ENROUTE
    self.nearOverloadPoint = false
end

function OverloaderAIDriver:postInit()
    ---Refresh the Hud content here,as otherwise the moveable pipe is not 
    ---detected the first time after loading a savegame. 
    self:setHudContent()
    CombineUnloadAIDriver.postInit(self)
end

function OverloaderAIDriver:setupTrailerData()
    
    --- Checks if there is a auger wagon object.
    --- Gets the pipe object.
    local implementWithPipe = AIDriverUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Pipe)
    if implementWithPipe then
        --- Pipe was found.
        self.pipeSpec = implementWithPipe.spec_pipe
        self.trailer = implementWithPipe
		self:debug('Overloader found an auger wagon.')
        return
    else
        self:debug('Overloader has no implement with pipe.')
    end

    --- Checks if there is a sugar cane trailer attached.
    --- Gets the shovel object, as a sugar cane trailer uses the shovel spec to unload.
    local implementWithShovel = AIDriverUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Shovel)
    if implementWithShovel then
        --- Sugar cane trailer was found.
        self.shovelSpec = implementWithShovel.spec_shovel
        self.trailer = implementWithShovel
		self:debug('Overloader found a sugar cane trailer.')
        return
    else
        self:debug('Overloader has no sugar cane trailer.')
    end
    --- Gets the trailer object for different over loaders. Still WIP.
    self.trailer = AIDriverUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Trailer)

    --- TODO: Implement special trailers, like the annaburger fieldLinerHTS31.
end

function OverloaderAIDriver:setHudContent()
    self:setupTrailerData()
	CombineUnloadAIDriver.setHudContent(self)
	courseplay.hud:setOverloaderAIDriverContent(self.vehicle,self)
end

function OverloaderAIDriver:start(startingPoint)
    self.unloadCourseState = self.states.ENROUTE
    if self.shovelSpec then
        --- Remember the old giants setup.
        --- This disables unloading to ground, while the driver is driving.
        self.oldCanDischargeToGroundFunction = self.trailer.getCanDischargeToGround
        self.trailer.getCanDischargeToGround = function () return false end
    end 

    CombineUnloadAIDriver.start(self, startingPoint)
end

function OverloaderAIDriver:dismiss()
    --- Resets the old giants setup.
    if self.shovelSpec then
        self.trailer.getCanDischargeToGround = self.oldCanDischargeToGroundFunction
        self.oldCanDischargeToGroundFunction = nil
    end
    CombineUnloadAIDriver.dismiss(self)
end

--- Are there any trailer under the pipe ?
---@param shouldTrailerBeStandingStill boolean
function OverloaderAIDriver:isTrailerUnderPipe(shouldTrailerBeStandingStill)
    return AIDriverUtil.isTrailerUnderPipe(self.pipeSpec,shouldTrailerBeStandingStill)
end

function OverloaderAIDriver:driveUnloadCourse(dt)
    if self.pipeSpec then 
        self:driveUnloadCourseWithAugerWagon(dt)
    elseif self.shovelSpec then 
        self:driveUnloadCourseWithSugarCaneTrailer(dt)
    end
    AIDriver.drive(self, dt)
end

function OverloaderAIDriver:driveUnloadCourseWithAugerWagon(dt)
    if self.unloadCourseState == self.states.ENROUTE then
    elseif self.unloadCourseState == self.states.WAITING_FOR_TRAILER then
        self:holdWithFuelSave()
        --- Is there any valid still standing target under the pipe ?
        if self:isTrailerUnderPipe(true) then
            self:debug('Trailer is here, opening pipe.')
            self.trailer:setPipeState(AIDriverUtil.PIPE_STATE_OPEN)
            self.unloadCourseState = self.states.WAITING_FOR_OVERLOAD_TO_START
             --- If the driver was in fuel save make sure it gets started again for overloading.
            self:startEngineIfNeeded()
        end
    elseif self.unloadCourseState == self.states.WAITING_FOR_OVERLOAD_TO_START then
        self:hold()
		--- Pipe isn't moving, so start overloading.
		if self.pipeSpec.currentState == self.pipeSpec.targetState then
            self:debug('Overloading started')
            --- Waiting for an optional tool position to start. 
            if self:isWorkingToolPositionReached(dt,1) then 
				self.unloadCourseState = self.states.OVERLOADING
			end
		end
    elseif self.unloadCourseState == self.states.OVERLOADING then
        self:hold()
        --- Finished overloading.
        if not self.trailer:getCanDischargeToObject(self.trailer:getCurrentDischargeNode()) then
            --- If the driver is unloaded enough, continue.
            if self:isMoveOnFillLevelReached() then 
                self:debug('Overloading finished, closing pipe')
                self.trailer:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
                self.unloadCourseState = self.states.ENROUTE
            --- Closing the pipe and wait for another unload target, only after the last target has left.
			elseif not self:isTrailerUnderPipe() then
                self:debug('No Trailer here, closing pipe for now')
                self.trailer:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED)
                self.unloadCourseState = self.states.WAITING_FOR_TRAILER
			end
		end
    end
end

function OverloaderAIDriver:driveUnloadCourseWithSugarCaneTrailer(dt)
    --- To handle sugarcane trailers all tool positions have to be set.
    if not self:areWorkingToolPositionsValid() then 
        self:holdWithFuelSave()
    end
    if self.unloadCourseState == self.states.ENROUTE then
        if not self:isWorkingToolPositionReached(dt,SugarCaneTrailerToolPositionsSetting.TRANSPORT_POSITION) then 
            self:hold()
        end
    elseif self.unloadCourseState == self.states.WAITING_FOR_TRAILER then
        self:holdWithFuelSave()
        --- If the driver is unloaded enough, continue.
        if self:isMoveOnFillLevelReached() then 
            self.unloadCourseState = self.states.ENROUTE
            return
        end
        
        self:isWorkingToolPositionReached(dt,SugarCaneTrailerToolPositionsSetting.TRANSPORT_POSITION) 
        --- Needs raycast to check for trailers to the side.

    elseif self.unloadCourseState == self.states.OVERLOADING then
        self:hold()
         --- If the driver is unloaded enough, continue.
        if self:isMoveOnFillLevelReached() then 
            self.unloadCourseState = self.states.ENROUTE
            return
        end

        local dischargeNode = self.trailer:getCurrentDischargeNode()
        local dischargeObject = dischargeNode.dischargeObject
        local fillUnitIndex = dischargeNode.dischargeFillUnitIndex
        if dischargeObject then 
            local fillLevelPercentage = dischargeObject:getFillUnitFillLevelPercentage(fillUnitIndex)
            --- This disables unloading, when the target is filled >= 99 %.
            if fillLevelPercentage > self.FILL_LEVEL_THRESHOLD then 
                self.unloadCourseState = self.states.WAITING_FOR_TRAILER
            end
        end

        if self:isWorkingToolPositionReached(dt,SugarCaneTrailerToolPositionsSetting.UNLOADING_POSITION) then 
            --- When the unloading position is reached, but the trailer is gone, then go back to transport position.
            if not dischargeObject then 
                self.unloadCourseState = self.states.WAITING_FOR_TRAILER
            end
        end
    end
end

function OverloaderAIDriver:updateTick()
    --- Only use the raycast with a sugar cane trailer.
    if self.shovelSpec then
         --- This creates a raycast to the sides of the trailer to check for unload targets.
        if self.unloadCourseState == self.states.WAITING_FOR_TRAILER then 
            self:raycastSugarCaneTrailerSides()
        end
    end
    CombineUnloadAIDriver.updateTick(self)
end

--- Searches for unloading target to the left side of the sugar cane trailer. 
--- TODO: Make the search direction and the raycast start point relative to the current discharge node.
function OverloaderAIDriver:raycastSugarCaneTrailerSides()
    local rootNode = self.trailer.rootNode
    local sideOffset = 2
    local heightOffset = 3
    local raycastLength = 5
    local ny = -1
    --- Raycast to the right side.
---    local x,y,z = localToWorld(rootNode,-sideOffset,heightOffset,0)
---    local nx,_,nz = localDirectionToWorld(rootNode,-1,0,0)
---    self:raycastSugarCaneTrailer(x,y,z,nx,ny,nz,raycastLength)
    --- Raycast to the left side.
    local x,y,z = localToWorld(rootNode,sideOffset,heightOffset,0)
    local nx,_,nz = localDirectionToWorld(rootNode,1,0,0)
    self:raycastSugarCaneTrailer(x,y,z,nx,ny,nz,raycastLength)
end

function OverloaderAIDriver:raycastSugarCaneTrailer(x,y,z,nx,ny,nz,distance)
    if courseplay.debugChannels[self.debugChannel] then
        cpDebug:drawLine(x,y,z,1,1,1,x+distance*nx,y+distance*ny,z+distance*nz)
    end
    raycastAll(x, y, z, nx, ny, nz, "raycastSugarCaneTrailerCallback", distance, self)
end

function OverloaderAIDriver:raycastSugarCaneTrailerCallback(hitActorId, x, y, z, distance, nx, ny, nz, subShapeIndex, hitShapeId)
    if self.unloadCourseState == self.states.OVERLOADING then 
        self:debug("Is already overloading.")
        return false
    end
    if hitActorId ~= nil then
        local object = g_currentMission:getNodeObject(hitActorId)
        if object and object.getRootVehicle then 
            local rootVehicle = object:getRootVehicle()
            if rootVehicle == self.vehicle then 
                return true
            end
            if rootVehicle then 
                --- Checks if the vehicle is stopped.
                if not AIDriverUtil.isStopped(rootVehicle) then
                    self:debug("Target %s is still moving.",nameNum(object))
                    return false
                end

                local fillUnitIndex = object:getFillUnitIndexFromNode(hitShapeId)

                --- Fill unit not found.
                if not fillUnitIndex then 
                    return true
                end

                local allowedToFillByShovel = object:getFillUnitSupportsToolType(fillUnitIndex, ToolType.DISCHARGEABLE)	
                local currentDischargeNode = self.trailer:getCurrentDischargeNode()
                local fillType = self.trailer:getDischargeFillType(currentDischargeNode)
                local validFillType = object:getFillUnitAllowsFillType(fillUnitIndex,fillType)
                if validFillType then 
                    local fillLevelPercentage = object:getFillUnitFillLevelPercentage(fillUnitIndex)
                    if fillLevelPercentage < self.FILL_LEVEL_THRESHOLD then 
                        --- If the driver was in fuel save make sure it gets started again for overloading.
                        self:startEngineIfNeeded()
                        self.unloadCourseState = self.states.OVERLOADING
                        self:debug("Starting to overload.")
                        return false
                    else 
                        self:debug("Target %s is already full.",nameNum(object))
                        return false
                    end
                else 
                    self:debug("Target %s doesn't support this fillType %s, fillUnitIndex : %d.",nameNum(object),g_fillTypeManager:getFillTypeNameByIndex(fillType),fillUnitIndex)
                    return true
                end
            end
        end
    end
    return true
end

--- Check if there are valid tool positions set.
function OverloaderAIDriver:getWorkingToolPositionsSetting()
    local setting = self.pipeSpec and self.settings.pipeToolPositions or self.settings.sugarCaneTrailerToolPositions
    return setting:hasValidToolPositions() and setting
end

function OverloaderAIDriver:isProximitySwerveEnabled(vehicle)
	-- make sure we stay close to the trailer while overloading
	return CombineUnloadAIDriver.isProximitySwerveEnabled(self, vehicle) and not self.nearOverloadPoint
end

function OverloaderAIDriver:isProximitySpeedControlEnabled()
    return CombineUnloadAIDriver.isProximitySpeedControlEnabled(self) and not self.nearOverloadPoint
end

function OverloaderAIDriver:onWaypointChange(ix)
    -- this is called when the next wp changes, that is well before we get there
    -- save it in a variable to avoid the relatively expensive hasWaitPointWithinDistance to be called too often
    self.nearOverloadPoint,self.closestOverloadPointIx = self.course:hasWaitPointWithinDistance(ix, 30)
    CombineUnloadAIDriver.onWaypointChange(self, ix)
end

function OverloaderAIDriver:onWaypointPassed(ix)
    -- just in case...
    self.nearOverloadPoint, self.closestOverloadPointIx = self.course:hasWaitPointWithinDistance(ix, 30)
    if self.course:isWaitAt(ix) then
        if self:isTrailerEmpty() then
            self:debug('Wait point reached but my trailer is empty, continuing')
        else
            self:debug('Wait point reached, wait for trailer.')
            self.unloadCourseState = self.states.WAITING_FOR_TRAILER
        end
    else
        CombineUnloadAIDriver.onWaypointPassed(self, ix)
    end
end

function OverloaderAIDriver:getSpeed()
    
    local defaultSpeed = CombineUnloadAIDriver.getSpeed(self)  
    
    if self.unloadCourseState == self.states.ENROUTE and self.closestOverloadPointIx then
        local distToWaitPoint = self.course:getDistanceBetweenVehicleAndWaypoint(self.vehicle,self.closestOverloadPointIx)
        return MathUtil.clamp(distToWaitPoint, self.MIN_SPEED_UNLOAD_COURSE, defaultSpeed)
    else 
        return defaultSpeed    
    end
end

function OverloaderAIDriver:isTrailerEmpty()
    if self.trailer and self.trailer.getFillUnits then
        for _, fillUnit in pairs(self.trailer:getFillUnits()) do
            if fillUnit.fillLevel > 0.1 then
                return false
            end
        end
    end
    return true
end

function OverloaderAIDriver:isMoveOnFillLevelReached()
	if self.trailer and self.trailer.getFillUnits then
        for _, fillUnit in pairs(self.trailer:getFillUnits()) do
             return fillUnit.fillLevel/fillUnit.capacity*100 < self.vehicle.cp.settings.moveOnAtFillLevel:get() 
        end
    end
    return true
end

--override this as mode 3 unloading works separate without triggerHandler
function OverloaderAIDriver:enableFillTypeUnloading()
	
end

--- Is around the overload point?
function OverloaderAIDriver:isNearOverloadPoint()
	return self.nearOverloadPoint
end

--- Driver is waiting at the overloading point.
function OverloaderAIDriver:isWaitingAtOverloadingPoint()
    return self.unloadCourseState ~= self.states.ENROUTE
end

function OverloaderAIDriver:isStoppingAtWaitPointAllowed()
	return false
end

function OverloaderAIDriver:hasSugarCaneTrailerToolPositions()
    return false
end

