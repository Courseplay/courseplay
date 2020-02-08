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
	UNLOADING = {},
	MOVE_FORWARD_AFTER_UNLOADING = {}
}

--- Make sure the the bale loader behaves like a proper AIImplement and reacts on AIImplementStart/End
--- events so there's no special handling is needed elswhere.
function BaleLoaderAIDriver.register()

	BaleLoader.onAIImplementStart = Utils.overwrittenFunction(BaleLoader.onAIImplementStart,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			self:doStateChange(BaleLoader.CHANGE_MOVE_TO_WORK);
		end)

	BaleLoader.onAIImplementEnd = Utils.overwrittenFunction(BaleLoader.onAIImplementEnd,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			local spec = self.spec_baleLoader
			if not spec.grabberIsMoving and spec.grabberMoveState == nil and spec.isInWorkPosition then
				self:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT);
			end
		end)

	local baleLoaderRegisterEventListeners = function(vehicleType)
		print('## Courseplay: Registering event listeners for bale loader')
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStart", BaleLoader)
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", BaleLoader)
	end

	print('## Courseplay: Appending event listener for bale loaders')
	BaleLoader.registerEventListeners = Utils.appendedFunction(BaleLoader.registerEventListeners, baleLoaderRegisterEventListeners)

end


function BaleLoaderAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'BaleLoaderAIDriver:init()')
	UnloadableFieldworkAIDriver.init(self, vehicle)
	self.baleLoader = FieldworkAIDriver.getImplementWithSpecialization(vehicle, BaleLoader)

	-- Bale loaders have no AI markers (as they are not AIImplements according to Giants) so add a function here
	-- to get the markers
	self.baleLoader.getAIMarkers = function(self)
		return UnloadableFieldworkAIDriver.getAIMarkersFromGrabberNode(self, self.spec_baleLoader)
	end

	self:initStates(BaleLoaderAIDriver.myStates)
	self.manualUnloadNode = WaypointNode(self.vehicle:getName() .. 'unloadNode')
	self:debug('Initialized, bale loader: %s', self.baleLoader:getName())
end

function BaleLoaderAIDriver:setHudContent()
	UnloadableFieldworkAIDriver.setHudContent(self)
	courseplay.hud:setBaleLoaderAIDriverContent(self.vehicle)
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
	-- use the relevant node, not the current one to determine we are around the unload point as the current changes
	-- when we change direction
	local nearUnloadPoint, unloadPointIx = self.course:hasUnloadPointWithinDistance(self.ppc:getRelevantWaypointIx(), 25)
	if self:hasTipTrigger() or nearUnloadPoint then
		self:setSpeed(self.vehicle.cp.speeds.approach)
		self:raycast()
		if self:haveBales() and self.unloadRefillState == nil then
			self.unloadRefillState = self.states.APPROACHING_UNLOAD_POINT
			self.tooCloseToOtherBales = false
			self:debug('Approaching unload point.')
		elseif self:haveBales() and self.unloadRefillState == self.states.APPROACHING_UNLOAD_POINT then
			local unloadNode = self:getUnloadNode(nearUnloadPoint, unloadPointIx)
			local _, _, dz = localToLocal(unloadNode, self.baleLoader.cp.realUnloadOrFillNode, 0, 0, 0)
			self:debugSparse('distance to unload point: %.1f', dz)
			if math.abs(dz) < 1 or self.tooCloseToOtherBales then
				self:debug('Unload point reached.')
				self.unloadRefillState = self.states.UNLOADING
			end
		elseif self.unloadRefillState == self.states.MOVE_FORWARD_AFTER_UNLOADING then
			self:setSpeed(self.vehicle.cp.speeds.approach)
			local unloadNode = self:getUnloadNode(nearUnloadPoint, unloadPointIx)
			local _, _, dz = localToLocal(unloadNode, self.baleLoader.cp.realUnloadOrFillNode, 0, 0, 0)
			if math.abs(dz) > 3 then
				self:debug('Moved away from unload point')
				-- transition to the next stage (out of EMPTY_WAIT_TO_SINK)
				g_client:getServerConnection():sendEvent(BaleLoaderStateEvent:new(self.baleLoader, BaleLoader.CHANGE_BUTTON_EMPTY))
				-- continue pressing the button until we folded everything back
				self.unloadRefillState = self.states.UNLOADING
			end
		elseif self.unloadRefillState == self.states.UNLOADING then
			self:setSpeed(0)
			-- don't do this in every update loop, sending events does not make sense so often
			if g_updateLoopIndex % 100 == 0 then
				self:debug('Unloading, emptyState=%d.', self.baleLoader.spec_baleLoader.emptyState)
				if self.baleLoader.spec_baleLoader.emptyState == BaleLoader.EMPTY_WAIT_TO_SINK then
					self:debug('Bales unloaded, moving forward a bit, emptyState: %d...', self.baleLoader.spec_baleLoader.emptyState)
					self.unloadRefillState = self.states.MOVE_FORWARD_AFTER_UNLOADING
					-- make sure we are driving forward now
					self.ppc:initialize(self.course:getNextFwdWaypointIx(self.ppc:getCurrentWaypointIx()));
				-- EMPTY_NONE is the base position (loaded or unloaded)
				elseif self:haveBales() or self.baleLoader.spec_baleLoader.emptyState ~= BaleLoader.EMPTY_NONE then
					-- this is like keep pressing the 'Unload' button. Not nice, should probably check the current state
					-- of the bale loader, but it is so simple like this and works ...
					self:debug('Press unload button, emptyState: %d...', self.baleLoader.spec_baleLoader.emptyState)
					g_client:getServerConnection():sendEvent(BaleLoaderStateEvent:new(self.baleLoader, BaleLoader.CHANGE_BUTTON_EMPTY))
				else
					self:debug('Bales unloaded, continue course.')
					courseplay:resetTipTrigger(self.vehicle)
					self.unloadRefillState = nil
					self.ppc:initialize(self.course:getNextFwdWaypointIx(self.ppc:getCurrentWaypointIx()));
				end
			end
		end
	else
		-- for some bale loaders the onAIImplementEnd() does not work seemingly because the grabber is still busy
		-- with the last bale when switching to the unload course. Make sure here that it is moved to transport
		-- position on the unload course
		local spec = self.baleLoader.spec_baleLoader
		if not spec.grabberIsMoving and spec.grabberMoveState == nil and spec.isInWorkPosition then
			self:debug('Move grabber to transport position')
			self.baleLoader:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT);
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

--- Unload node is either an unload waypoint or an unload trigger
function BaleLoaderAIDriver:getUnloadNode(isUnloadpoint, unloadPointIx)
	if isUnloadpoint then
		self:debugSparse('manual unload point at ix = %d', unloadPointIx)
		self.manualUnloadNode:setToWaypoint(self.course, unloadPointIx)
		return self.manualUnloadNode.node
	else
		return self.vehicle.cp.currentTipTrigger.triggerId
	end
end

--- Raycast back to stop when there's already a stack of bales at the unload point.
function BaleLoaderAIDriver:raycast()
	if not self.baleLoader.cp.realUnloadOrFillNode then return end
	local nx, ny, nz = localDirectionToWorld(self.baleLoader.cp.realUnloadOrFillNode, 0, 0, -1)
	local x, y, z = localToWorld(self.baleLoader.cp.realUnloadOrFillNode, 0, 0, 0)
	raycastClosest(x, y, z, nx, ny, nz, 'raycastCallback', 5, self)
end

function BaleLoaderAIDriver:raycastCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and object:isa(Bale) then
			if distance < 2 then
				self.tooCloseToOtherBales = true
				self:debugSparse('Bale found at d=%.1f', distance)
			else
				self.tooCloseToOtherBales = false
			end
		end
	end
end