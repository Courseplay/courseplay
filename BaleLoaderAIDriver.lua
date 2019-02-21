--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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

---@class BaleLoaderAIDriver : UnloadableFieldworkAIDriver
BaleLoaderAIDriver = CpObject(UnloadableFieldworkAIDriver)

BaleLoaderAIDriver.myStates = {
	APPROACHING_UNLOAD_POINT = {},
	UNLOADING = {}
}

--- Make sure the the bale loader behaves like a proper AIImplement and reacts on AIImplementStart/End
--- events so there's no special handling is needed elswhere.
function BaleLoaderAIDriver.register()

	AIImplement.getCanImplementBeUsedForAI = Utils.overwrittenFunction(AIImplement.getCanImplementBeUsedForAI,
		function(self, superFunc)
			if SpecializationUtil.hasSpecialization(BaleLoader, self.specializations) then
				return true
			elseif superFunc ~= nil then
				return superFunc(self)
			end
		end)

	BaleLoader.onAIImplementStart = Utils.overwrittenFunction(BaleLoader.onAIImplementStart,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			self:doStateChange(BaleLoader.CHANGE_MOVE_TO_WORK);
		end)

	BaleLoader.onAIImplementEnd = Utils.overwrittenFunction(BaleLoader.onAIImplementEnd,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			self:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT);
		end)

	local baleLoaderRegisterEventListeners = function(vehicleType)
		print('## Courseplay: Registering event listeners for bale loader')
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStart", BaleLoader)
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", BaleLoader)
	end

	print('## Courseplay: Appending event listener for bale loaders')
	BaleLoader.registerEventListeners = Utils.appendedFunction(BaleLoader.registerEventListeners, baleLoaderRegisterEventListeners)


	-- Make sure the Giants helper can't be hired for implements which have no Giants AI functionality
	AIVehicle.getCanStartAIVehicle = Utils.overwrittenFunction(AIVehicle.getCanStartAIVehicle,
		function(self, superFunc)
			-- Only the courseplay helper can handle bale loaders.
			if BaleLoaderAIDriver.hasBaleLoaderAttached(self) then
				return false
			end
			if superFunc ~= nil then
				return superFunc(self)
			end
		end)
end

function BaleLoaderAIDriver.hasBaleLoaderAttached(vehicle)
	local aiImplements = vehicle:getAttachedAIImplements()
	for _, implement in ipairs(aiImplements) do
		if SpecializationUtil.hasSpecialization(BaleLoader, implement.object.specializations) then
			return true
		end
	end
end

function BaleLoaderAIDriver:init(vehicle)
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self.baleLoader = self:getBaleLoader()
	self:initStates(BaleLoaderAIDriver.myStates)
	self:debug('Initialized, bale loader: %s', self.baleLoader:getName())
end

-- find my bale loader object
function BaleLoaderAIDriver:getBaleLoader()
	local aiImplements = self.vehicle:getAttachedAIImplements()
	for _, implement in ipairs(aiImplements) do
		if SpecializationUtil.hasSpecialization(BaleLoader, implement.object.specializations) then
			return implement.object
		end
	end
end

---@return boolean true if unload took over the driving
function BaleLoaderAIDriver:driveUnloadOrRefill(dt)
	self:updateOffset()
	self:updateFillType()

	-- by default, drive street/recorded speed.
	self:setSpeed(self:getRecordedSpeed())

	if not self.ppc:isReversing() then
		-- 'cause reverse does the raycasting for us
		self:searchForTipTriggers()
	end

	if self:hasTipTrigger() then
		if self:haveBales() and self.unloadRefillState == nil then
			self.unloadRefillState = self.states.APPROACHING_UNLOAD_POINT
			self:debug('Approaching unload point.')
		elseif self:haveBales() and self.unloadRefillState == self.states.APPROACHING_UNLOAD_POINT then
			local _, _, dz = localToLocal(self.baleLoader.cp.realUnloadOrFillNode, self.vehicle.cp.currentTipTrigger.triggerId, 0, 0, 0)
			self:debugSparse('distance to unload point: %.1f', dz)
			if math.abs(dz) < 1 then
				self:debug('Unload point reached.')
				self.unloadRefillState = self.states.UNLOADING
				self.lastEmptyState = nil
			end
		elseif self.unloadRefillState == self.states.UNLOADING then
			self:setSpeed(0)
			-- don't do this in every update loop, sending events does not make sense so often
			if g_updateLoopIndex % 100 == 0 then
				self:debug('Unloading, emptyState=%d, last=%s.', self.baleLoader.spec_baleLoader.emptyState, self.lastEmptyState)
				-- EMPTY_NONE is the base position (loaded or unloaded)
				if self:haveBales() or self.baleLoader.spec_baleLoader.emptyState ~= BaleLoader.EMPTY_NONE then
					-- this is like keep pressing the 'Unload' button. Not nice, should probably check the current state
					-- of the bale loader, but it is so simple like this and works ...
					self:debug('Press unload button, emptyState: %d...', self.baleLoader.spec_baleLoader.emptyState)
					g_client:getServerConnection():sendEvent(BaleLoaderStateEvent:new(self.baleLoader, BaleLoader.CHANGE_BUTTON_EMPTY))
					self.lastEmptyState = self.baleLoader.spec_baleLoader.emptyState
				else
					self:debug('Bales unloaded, continue course.')
					self.unloadRefillState = nil
					self.ppc:initialize(self.course:getNextFwdWaypointIx(self.ppc:getCurrentWaypointIx()));
				end
			end
		end
	end
	return false
end

function BaleLoaderAIDriver:haveBales()
	return self.baleLoader:getFillUnitFillLevel(self.baleLoader.spec_baleLoader.fillUnitIndex) > 0
end

function BaleLoaderAIDriver:updateFillType()
	if not self.fillType then
		self.fillType = self:getFillType()
	end
	-- This is an ugly hack here here to overwrite the legacy CP code's fillType as it is not
	-- able to handle the bale loaders. TODO: needs a more professional approach
	self.baleLoader.cp.fillType = self.fillType
	self:debugSparse('Bale filltype %s', self.fillType)
end

-- Getting fill type for bale loaders is not straightforward as the bales have the actual fill type,
-- the fill type what the trigger has, like STRAW, so just go through our bales and pick the first
-- fill type we find.
function BaleLoaderAIDriver:getFillType()
	local spec = self.baleLoader.spec_baleLoader
	for _, balePlace in pairs(spec.balePlaces) do
		if balePlace.bales then
			for _, baleServerId in pairs(balePlace.bales) do
				local bale = NetworkUtil.getObject(baleServerId)
				if bale ~= nil then
					return bale:getFillType()
				end
			end
		end
	end
end