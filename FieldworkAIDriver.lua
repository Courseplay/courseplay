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
Fieldwork AI Driver

Can follow a fieldworking course, perform turn maneuvers, turn on/off and raise/lower implements,
add adjustment course if needed.
]]

FieldworkAIDriver = CpObject(AIDriver)

-- Our class implementation does not call the constructor of base classes
-- through multiple level of inheritances therefore we must explicitly call
-- the base class ctr.
function FieldworkAIDriver:init(vehicle)
	AIDriver.init(self, vehicle)
	-- waiting for tools to turn on, unfold and lower
	self.waitingForTools = true
end

--- Start the oourse and turn on all implements when needed
function FieldworkAIDriver:start(ix)
	AIDriver.start(self, ix)
	self.vehicle.cp.stopAtEnd = true
	self.waitingForTools = true
	if not self.alignmentCourse then
		-- if there's no alignment course, start work immediately
		-- TODO: should probably better start it when the initialized waypoint (ix) is reached
		-- as we may start the vehicle outside of the field?
		self:startWork()
	end
end

function FieldworkAIDriver:drive(dt)
	AIDriver.drive(self, dt)
	self:checkWorkTools()
end

function FieldworkAIDriver:stop(msgReference)
	self:stopWork()
	AIDriver.stop(self, msgReference)
end

function FieldworkAIDriver:onEndAlignmentCourse()
	self:startWork()
end

function FieldworkAIDriver:onEndCourse()
	self:stop('END_POINT')
end

function FieldworkAIDriver:getSpeed()
	local speed = 10
	if self.alignmentCourse then
		-- use the courseplay speed limit for fields
		speed = self.vehicle.cp.speeds.field
	else
		-- use the speed limit supplied by Giants for fieldwork
		local speedLimit = self.vehicle:getSpeedLimit() or math.huge
		speed = math.min(self.vehicle.cp.speeds.field, speedLimit)
	end
	-- as long as other CP components mess with the cruise control we need to reset this, for example after
	-- a turn
	self.vehicle:setCruiseControlMaxSpeed(speed)
	if self.course == self.mainCourse and self.waitingForTools then
		-- don't go anywhere until everything is ready to work
		speed = 0
	end
	return speed
end

--- Start the actual work. Lower and turn on implements
function FieldworkAIDriver:startWork()
	self:debug('Starting work: turn on and lower implements.')
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	courseplay:lowerImplements(self.vehicle)
end

--- Stop working. Raise and stop implements
function FieldworkAIDriver:stopWork()
	self:debug('Ending work: turn off and raise implements.')
	courseplay:raiseImplements(self.vehicle)
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
end

--- Check all worktools to see if we are ready to go or need to stop
function FieldworkAIDriver:checkWorkTools()
	if not self.vehicle.cp.workTools then return end
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		self:isReady(workTool)
		self:checkFillLevels(workTool)
	end
end

--- Check fill levels in all tools and stop when one of them isn't
-- ok (empty or full, depending on the derived class)
function FieldworkAIDriver:checkFillLevels(workTool)
	-- really no need to do this on every update()x
	if g_updateLoopIndex % 100 ~= 0 then return end
	if workTool.getFillUnits then
		for index, fillUnit in pairs(workTool:getFillUnits()) do
			-- let's see if we can get by this abstraction for all kinds of tools
			local ok, msgReference = self:isLevelOk(workTool, index, fillUnit)
			if not ok then
				self:stop(msgReference)
				return
			end
		end
	end
end

--- Check if worktool is ready for work
function FieldworkAIDriver:isReady(workTool)
	local _, _, isUnfolded = courseplay:isFolding(workTool)
	-- TODO: make these a generic helper?
	local isTurnedOn = true
	if workTool.spec_turnOnVehicle then
		isTurnedOn = workTool:getAIRequiresTurnOn() and workTool:getIsTurnedOn()
	end

	local isLowered = self:getCanAIImplementContinueWork(workTool)

	courseplay.debugVehicle(12, workTool, 'lowered=%s turnedon=%s unfolded=%s', isLowered, isTurnedOn, isUnfolded)

	if isLowered and isTurnedOn and isUnfolded then
		self.waitingForTools = false
	else
		self.waitingForTools = true
	end
end

-- is the fill level ok to continue?
function FieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	-- implement specifics in the derived classes
	return true
end

function FieldworkAIDriver:debug(...)
	courseplay.debugVehicle(17, self.vehicle, ...)
end

-- Giants question: this is copied from Attachable but when calling it with spec_attachable, it blows up with
-- dataS/scripts/vehicles/specializations/Attachable.lua(1026) : attempt to index local 'jointDesc' (a nil value)
function FieldworkAIDriver:getCanAIImplementContinueWork(workTool)
	local spec = workTool.spec_attachable
	if not workTool:getAINeedsLowering() or not spec then return true end
	local isReady = true
	if spec.lowerAnimation ~= nil then
		local time = workTool:getAnimationTime(spec.lowerAnimation)
		isReady = time == 1 or time == 0
	end
	local jointDesc = spec.attacherVehicle:getAttacherJointDescFromObject(workTool)
	if jointDesc.allowsLowering and workTool:getAINeedsLowering() then
		if jointDesc.moveDown then
			isReady = (jointDesc.moveAlpha == jointDesc.lowerAlpha or jointDesc.moveAlpha == jointDesc.upperAlpha) and isReady
		end
	end
	return isReady
end