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



---@class MixerWagonAIDriver : BunkerSiloAIDriver
MixerWagonAIDriver = CpObject(BunkerSiloAIDriver)


MixerWagonAIDriver.WORKING_TOOL_POSITIONS = {}
MixerWagonAIDriver.WORKING_TOOL_POSITIONS.LOADING = 1
MixerWagonAIDriver.WORKING_TOOL_POSITIONS.TRANSPORT = 2

function MixerWagonAIDriver:start(startingPoint)
	self.mixerWagon = AIDriverUtil.getImplementWithSpecialization(self.vehicle,MixerWagon) or self.vehicle
	self.shovel = AIDriverUtil.getImplementWithSpecialization(self.vehicle,Shovel) or self.vehicle
	BunkerSiloAIDriver.start(self,startingPoint)
end

function MixerWagonAIDriver:setHudContent()
	BunkerSiloAIDriver.setHudContent(self)
	courseplay.hud:setMixerWagonAIDriverContent(self.vehicle)
end

function MixerWagonAIDriver:beforeDriveIntoSilo()
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	self.vehicle:requestActionEventUpdate()
	self.triggerHandler:disableFillTypeLoading()
	self.triggerHandler:disableFillTypeUnloading()
	BunkerSiloAIDriver.beforeDriveIntoSilo(self)
end

function MixerWagonAIDriver:beforeDriveOutOfSilo()
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
	self.vehicle:requestActionEventUpdate()
	BunkerSiloAIDriver.beforeDriveOutOfSilo(self)
end

function MixerWagonAIDriver:beforeMainCourse()
	self.triggerHandler:enableFillTypeLoading()
	self.triggerHandler:enableFillTypeUnloading()
	BunkerSiloAIDriver.beforeMainCourse(self)
end

function MixerWagonAIDriver:drive(dt)
	if not self:areWorkingToolPositionsValid() then 
		self:hold()
	end
	BunkerSiloAIDriver.drive(self,dt)
end

function MixerWagonAIDriver:driveIntoSilo(dt)
	if not self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.LOADING) then 
		--- Waiting until the working position is reached.
		self:hold()
	end
	---
	if self:getIsFillLevelFromSiloReached() then 
		self:setupDriveOutOfSiloCourse()
	end
	if not self:isAllowedToMove() then 
		self:hold()
	end

	BunkerSiloAIDriver.driveIntoSilo(self,dt)
end

function MixerWagonAIDriver:driveOutOfSilo(dt)
	self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.TRANSPORT)
end 

function MixerWagonAIDriver:driveNormalCourse(dt)
	self:isWorkingToolPositionReached(dt,self.WORKING_TOOL_POSITIONS.TRANSPORT)
end

function MixerWagonAIDriver:getTargetNode()
	return self.shovel.spec_shovel.shovelNodes[1].node
end
function MixerWagonAIDriver:isDriveDirectionReverse()
	return false
end

function MixerWagonAIDriver:isEmptySiloAllowed()
	return false
end

---Is max fillLevel for the silo fillType reached ?
---@return boolean is fill level reached?
function MixerWagonAIDriver:getIsFillLevelFromSiloReached()
	local fillType = self.bunkerSiloManager:getFillType() or FillType.UNKNOWN
	local fillLevel = AIDriverUtil.getMixerWagonFillLevelForFillTypes(self.mixerWagon,fillType) or 0
	local maxFillLevel = self:getMaxFillLevelFromSilo(fillType)
	self:siloDebugSparse("FillLevel: %.2f,maxFillLevel: %.2f, fillType: %s",fillLevel,maxFillLevel,g_fillTypeManager:getFillTypeNameByIndex(fillType))
	return fillLevel and maxFillLevel and fillLevel >= maxFillLevel
end

---Gets max fillLevel of a fillType
---@param float fillTypeIndex
---@return float max fillLevel of a fillType 
function MixerWagonAIDriver:getMaxFillLevelFromSilo(fillType)
	if self:getSiloSelectedFillTypeSetting():isEmpty() then
		--- If the silo selected fill type list is empty, fill the driver completely
		return self:getCapacity()*0.98
	else 
		local fillTypeData = self:getSiloSelectedFillTypeSetting():getData()
		for _,data in ipairs(fillTypeData) do 
			if data.fillType == fillType then
				return (self:getCapacity()*data.maxFillLevel/100)*0.98
			end
		end
		return self:getCapacity()*0.98
	end
end


---Gets total capacity 
---@return float capacity
function MixerWagonAIDriver:getCapacity()
	return self.mixerWagon:getFillUnitCapacity(1)
end

---Is completely empty ?
function MixerWagonAIDriver:getIsEmpty()
	return self.mixerWagon:getFillUnitFillLevel(1)/self:getCapacity() <= 0.01
end

---Is all cleared in front ?
---@return boolean is allowed to move
function MixerWagonAIDriver:isAllowedToMove()
	if self.shovel.spec_shovel.loadingFillType == FillType.UNKNOWN then
		return true
	end
	return false
end

---Gets the silo selected fillType setting
---@return setting SiloSelectedFillTypeMixerWagonAIDriverSetting
function MixerWagonAIDriver:getSiloSelectedFillTypeSetting()
	return self.settings.siloSelectedFillTypeMixerWagonAIDriver
end

--- If max silo fillLevel is reached, then continue with the main course.
function MixerWagonAIDriver:getCanContinueDrivingSiloCourse()
	return not self:getIsFillLevelFromSiloReached()
end

--- Let the driver reverse a bit to have more room for driving into the silo.
function MixerWagonAIDriver:isStartDistanceToSiloNeeded()
	return true
end

function MixerWagonAIDriver:getWorkingToolPositionsSetting()
	return self.settings.mixerWagonToolPositions
end

function MixerWagonAIDriver:getBestTarget()
	return self.bunkerSiloManager:getBestTargetFillUnitFillUp()
end

function MixerWagonAIDriver:onWaypointPassed(ix)
	if self:isDrivingNormalCourse() then 
		if self.course:switchingToReverseAt(ix) then 
			--- Search for a bunker silos after the first silo.
			self:setupSiloCourse()
		end
	end
	BunkerSiloAIDriver.onWaypointPassed(self,ix)
end

function MixerWagonAIDriver:onEndCourse()
	if self:isDrivingNormalCourse() then 
		if not self:getIsEmpty() then 
			--- The mixer wagon was not completely emptied, so stop work.
			self:changeSiloState(self.states.WORK_FINISHED)
			return
		end
	end
	BunkerSiloAIDriver.onEndCourse(self)
end