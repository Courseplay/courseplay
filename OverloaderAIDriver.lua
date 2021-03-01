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

function OverloaderAIDriver:findPipeAndTrailer()
    local implementWithPipe = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Pipe)
    if implementWithPipe then
        self.pipe = implementWithPipe.spec_pipe
		self.objectWithPipe = implementWithPipe
        self.moveablePipe = implementWithPipe.spec_cylindered
		self:debug('Overloader found its pipe')
		if self.moveablePipe then
			self:debug('Overloader found moveable pipe')
		end
    else
        self:debug('Overloader has no implement with pipe')
    end
    self.trailer = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Trailer)
end

function OverloaderAIDriver:setHudContent()
	CombineUnloadAIDriver.setHudContent(self)
	self:findPipeAndTrailer()
	courseplay.hud:setOverloaderAIDriverContent(self.vehicle,self.moveablePipe)
end

function OverloaderAIDriver:start(startingPoint)
    --- Looks like the implements are not attached at onLoad() when the game loads so we end up
    --- with no pipe after game start. So make another attempt to find it when missing
    --- TODO: this should be fixed properly, just like the other hack in start_stop.lua for the bale loader
    if not self.pipe or not self.trailer then self:findPipeAndTrailer() end
    self.unloadCourseState = self.states.ENROUTE
    CombineUnloadAIDriver.start(self, startingPoint)
end

function OverloaderAIDriver:isTrailerUnderPipe(shouldTrailerBeStandingStill)
    if not self.pipe then return end
    for trailer, value in pairs(self.pipe.objectsInTriggers) do
        if value > 0 then
            if shouldTrailerBeStandingStill then 
				local rootVehicle = trailer:getRootVehicle()
				if rootVehicle then 
					if rootVehicle:getLastSpeed(true) <1 then 
						return true
					else 
						return false
					end
				end
			end
			return true
        end
    end
    return false
end

function OverloaderAIDriver:driveUnloadCourse(dt)
    if self.unloadCourseState == self.states.ENROUTE then
    elseif self.unloadCourseState == self.states.WAITING_FOR_TRAILER then
        self:hold()
        if self:isTrailerUnderPipe(true) then
            self:debug('Trailer is here, opening pipe')
            if self.pipe then self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_OPEN) end
            self.unloadCourseState = self.states.WAITING_FOR_OVERLOAD_TO_START
        end
    elseif self.unloadCourseState == self.states.WAITING_FOR_OVERLOAD_TO_START then
        self:setSpeed(0)

		--can discharge and not pipe is moving 
		if self.pipe.currentState == self.pipe.targetState then
            self:debug('Overloading started')
            if self:isAugerPipeToolPositionsOkay(dt) then 
				self.unloadCourseState = self.states.OVERLOADING
			end
		end
    elseif self.unloadCourseState == self.states.OVERLOADING then
        self:setSpeed(0)
        if self.pipe:getDischargeState() == Dischargeable.DISCHARGE_STATE_OFF then
            if self:isMoveOnFillLevelReached() then 
                self:debug('Overloading finished, closing pipe')
                if self.pipe then self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED) end
                self.unloadCourseState = self.states.ENROUTE
			elseif not self:isTrailerUnderPipe() then
                self:debug('No Trailer here, closing pipe for now')
                if self.pipe then self.objectWithPipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED) end
                self.unloadCourseState = self.states.WAITING_FOR_TRAILER
			end
		end
    end
    AIDriver.drive(self, dt)
end

--if we have augerPipeToolPositions, then wait until we have set them
function OverloaderAIDriver:isAugerPipeToolPositionsOkay(dt)
	local augerPipeToolPositionsSetting = self.vehicle.cp.settings.augerPipeToolPositions
	if self.moveablePipe and augerPipeToolPositionsSetting:hasValidToolPositions() and not augerPipeToolPositionsSetting:updatePositions(dt,1) then 
		return false
	end
	return true
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
    self.nearOverloadPoint = self.course:hasWaitPointWithinDistance(ix, 30)
    CombineUnloadAIDriver.onWaypointChange(self, ix)
end

function OverloaderAIDriver:onWaypointPassed(ix)
    -- just in case...
    self.nearOverloadPoint = self.course:hasWaitPointWithinDistance(ix, 30)
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