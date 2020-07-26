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
    CombineUnloadAIDriver.init(self, vehicle)
    self:initStates(OverloaderAIDriver.myStates)
    self:debug('OverloaderAIDriver:init()')
    self.mode = courseplay.MODE_OVERLOADER
    self.unloadCourseState = self.states.ENROUTE
    self:findPipeAndTrailer()
end

function OverloaderAIDriver:findPipeAndTrailer()
    local implementWithPipe = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Pipe)
    if implementWithPipe then
        self.pipe = implementWithPipe.spec_pipe
        self:debug('Overloader found its pipe')
    else
        self:debug('Overloader has no implement with pipe')
    end
    self.trailer = AIDriverUtil.getImplementWithSpecialization(self.vehicle, Trailer)
end

function OverloaderAIDriver:start(startingPoint)
    --- Looks like the implements are not attached at onLoad() when the game loads so we end up
    --- with no pipe after game start. So make another attempt to find it when missing
    --- TODO: this should be fixed properly, just like the other hack in start_stop.lua for the bale loader
    if not self.pipe or not self.trailer then self:findPipeAndTrailer() end
    self.unloadCourseState = self.states.ENROUTE
    CombineUnloadAIDriver.start(self, startingPoint)
end

function OverloaderAIDriver:isTrailerUnderPipe()
    if not self.pipe then return end
    for trailer, value in pairs(self.pipe.objectsInTriggers) do
        if value > 0 then
            return true
        end
    end
    return false
end

function OverloaderAIDriver:driveUnloadCourse(dt)
    if self.unloadCourseState == self.states.ENROUTE then
    elseif self.unloadCourseState == self.states.WAITING_FOR_TRAILER then
        self:setSpeed(0)
        if self:isTrailerUnderPipe() then
            self:debug('Trailer is here, opening pipe')
            if self.pipe then self.pipe:setPipeState(AIDriverUtil.PIPE_STATE_OPEN) end
            self.unloadCourseState = self.states.WAITING_FOR_OVERLOAD_TO_START
        end
    elseif self.unloadCourseState == self.states.WAITING_FOR_OVERLOAD_TO_START then
        self:setSpeed(0)
        if self.pipe:getDischargeState() == Dischargeable.DISCHARGE_STATE_OBJECT then
            self:debug('Overloading started')
            self.unloadCourseState = self.states.OVERLOADING
        end
    elseif self.unloadCourseState == self.states.OVERLOADING then
        self:setSpeed(0)
        if self.pipe:getDischargeState() == Dischargeable.DISCHARGE_STATE_OFF then
            self:debug('Overloading finished, closing pipe')
            if self.pipe then self.pipe:setPipeState(AIDriverUtil.PIPE_STATE_CLOSED) end
            self.unloadCourseState = self.states.ENROUTE
        end
    end
    AIDriver.drive(self, dt)
end

function OverloaderAIDriver:onWaypointPassed(ix)
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
            if fillUnit.fillLevel > 0 then
                return false
            end
        end
    end
    return true
end