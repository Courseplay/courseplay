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



---@class BunkerSiloLoaderAIDriver : BunkerSiloAIDriver
BunkerSiloLoaderAIDriver = CpObject(BunkerSiloAIDriver)

function BunkerSiloLoaderAIDriver:init(vehicle)
	BunkerSiloAIDriver.init(self,vehicle)
	self.shovel = AIDriverUtil.getImplementWithSpecialization(self.vehicle,Shovel) or self.vehicle
	self.shovelSpec = self.shovel.spec_shovel
	self.dischargeObject = AIDriverUtil.getImplementWithSpecialization(self.vehicle,Dischargeable) or self.vehicle
	self.dischargeSpec = self.dischargeObject.spec_dischargeable
	self.currentDischargeNode = self.dischargeObject:getCurrentDischargeNode()
	self.mode = courseplay.MODE_SHOVEL_FILL_AND_EMPTY
end

function BunkerSiloLoaderAIDriver:setHudContent()
	BunkerSiloAIDriver.setHudContent(self)
	courseplay.hud:setBunkerSiloLoaderAIDriverContent(self.vehicle)
end

function BunkerSiloLoaderAIDriver:start(startingPoint)
	self:changeSiloState(self.states.CHECK_SILO)

	--- Remember the old giants setup
	self.canStartDischargeAutomatically = self.currentDischargeNode.canStartDischargeAutomatically
	self.oldCanDischargeToGround = self.currentDischargeNode.canDischargeToGround
	self.currentDischargeNode.canStartDischargeAutomatically = true
	self.currentDischargeNode.canDischargeToGround = false
	BunkerSiloAIDriver.start(self,startingPoint)
end

function BunkerSiloLoaderAIDriver:stop(msg)
	--- Reset the old giants setup
	self.currentDischargeNode.canStartDischargeAutomatically = self.canStartDischargeAutomatically
	self.currentDischargeNode.canDischargeToGround = self.oldCanDischargeToGround
	self.canStartDischargeAutomatically = nil
	self.oldCanDischargeToGround = nil


	BunkerSiloAIDriver.stop(self,msg)
end

function BunkerSiloLoaderAIDriver:getTargetNode()
	return self.shovelSpec.shovelNodes[1].node
end
function BunkerSiloLoaderAIDriver:isDriveDirectionReverse()
	return false
end

function BunkerSiloAIDriver:isEmptySiloAllowed()
	return false
end

function BunkerSiloLoaderAIDriver:beforeDriveIntoSilo()
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	self.vehicle:aiImplementStartLine()
	self.vehicle:requestActionEventUpdate() 
	BunkerSiloAIDriver.beforeDriveIntoSilo(self)
end

function BunkerSiloLoaderAIDriver:beforeDriveOutOfSilo()
	self.vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
	self.vehicle:aiImplementEndLine()
	self.vehicle:requestActionEventUpdate()
	BunkerSiloAIDriver.beforeDriveOutOfSilo(self)
end

function BunkerSiloLoaderAIDriver:driveIntoSilo(dt)
	if not self:getIsMovingAllowed() then
		self:hold()
	end

	BunkerSiloAIDriver.driveIntoSilo(self,dt)
end

function BunkerSiloLoaderAIDriver:isHeapSearchAllowed()
	return true
end

--- Can the driver continue driving into the silo/heap ?
function BunkerSiloLoaderAIDriver:getIsMovingAllowed()
	local isUnloading = self.dischargeSpec.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF
	if not isUnloading then 
		self:setInfoText("WAITING_FOR_UNLOADERS")
	end
	return self.shovelSpec.loadingFillType == FillType.UNKNOWN and (isUnloading or self.shovel:getFillUnitFillLevel(1) < 0.02)
end

--- Let the driver reverse a bit to have more room for driving into the silo.
function BunkerSiloLoaderAIDriver:isStartDistanceToSiloNeeded()
	return true
end

--- Overwritten to disable this.
function BunkerSiloLoaderAIDriver:isStuck()

end

function BunkerSiloLoaderAIDriver:getBunkerSiloSpeed()
	return 2
end

function BunkerSiloLoaderAIDriver:getBestTarget()
	return 1
end