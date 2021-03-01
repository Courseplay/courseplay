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

--[[
Fieldwork AI Driver for plows

]]

---@class PlowAIDriver : FieldworkAIDriver
PlowAIDriver = CpObject(FieldworkAIDriver)

PlowAIDriver.myStates = {
	ROTATING_PLOW = {},
	UNFOLDING_PLOW = {},
}

function PlowAIDriver:init(vehicle)
	courseplay.debugVehicle(courseplay.DBG_AI_DRIVER,vehicle,'PlowAIDriver:init()')
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(PlowAIDriver.myStates)
	self.mode = courseplay.MODE_FIELDWORK
	self.debugChannel = courseplay.DBG_MODE_6
	self.plow = AIDriverUtil.getAIImplementWithSpecialization(vehicle, Plow)
	self:setOffsetX()
	if self:hasRotatablePlow() then
		self:debug('has rotatable plow.')
	end
end

-- When starting work with a plow it first may need to be unfolded and then turned so it is facing to
-- the unworked side, and then can we start working
function PlowAIDriver:startWork()
	self:debug('Starting plow work')
	StartStopWorkEvent:sendStartEvent(self.vehicle)
	self:setOffsetX()
	self:startEngineIfNeeded()

	-- this will unfold the plow when necessary
	self.vehicle:raiseAIEvent("onAIStart", "onAIImplementStart")
	self.vehicle:requestActionEventUpdate()

	if self.plow.getIsUnfolded and self.plow:getIsUnfolded() then
		self:debug('Plow already unfolded, now rotating if needed')
		self:rotatePlow()
		self.fieldworkState = self.states.ROTATING_PLOW
	else
		self:debug('Unfolding plow')
		self.fieldworkState = self.states.UNFOLDING_PLOW
	end
end

function PlowAIDriver:driveFieldwork(dt)
	if self.fieldworkState == self.states.ROTATING_PLOW then
		self:setSpeed(0)
		if not self.plow.spec_plow:getIsAnimationPlaying(self.plow.spec_plow.rotationPart.turnAnimation) then
			self:debug('Plow rotation finished, ')
			self:setOffsetX()
			self:lowerImplements(self.vehicle)
			self.fieldworkState = self.states.WAITING_FOR_LOWER
		end
	elseif self.fieldworkState == self.states.UNFOLDING_PLOW then
		self:setSpeed(0)
		if self.plow.getIsUnfolded and self.plow:getIsUnfolded() then
			if self.plow:getIsPlowRotationAllowed() then
				self:debug('Plow unfolded, now rotating if needed')
				self:rotatePlow()
			end
			self.fieldworkState = self.states.ROTATING_PLOW
		end
	else
		return FieldworkAIDriver.driveFieldwork(self, dt)
	end
	return false
end

function PlowAIDriver:onWaypointPassed(ix)
	-- readjust the tool offset every now and then. This is necessary as the offset is calculated from the
	-- tractor's direction node which may need to result in incorrect values if the plow is not straight behind
	-- the tractor (which may be the case when starting). When passing waypoints we'll most likely be driving
	-- straight and thus calculating a proper tool offset
	if self.state == self.states.ON_FIELDWORK_COURSE and self.fieldworkState == self.states.WORKING then
		self:setOffsetX()
	end
	FieldworkAIDriver.onWaypointPassed(self, ix)
end

function PlowAIDriver:rotatePlow()
	self:debug('Starting work: check if plow needs to be turned.')
	local ridgeMarker = self.course:getRidgeMarkerState(self.ppc:getCurrentWaypointIx())
	local plowShouldBeOnTheLeft = ridgeMarker == courseplay.RIDGEMARKER_RIGHT
	self:debug('Ridge marker %d, plow should be on the left %s', ridgeMarker, tostring(plowShouldBeOnTheLeft))
	self.plow:setRotationMax(plowShouldBeOnTheLeft)
end

--- Attempt to set the tool offset automatically, assuming the attacher joint of the tool is in the middle (the axis
--- of the tractor). Then find the relative distance of the attacher node to the left/right AI markers:
--- a tool with no offset will have the same distance from left and right
--- a tool with offset will be closer to either left or right AI marker.
function PlowAIDriver:setOffsetX()
	local aiLeftMarker, aiRightMarker, aiBackMarker = self.plow.spec_plow:getAIMarkers()
	if aiLeftMarker and aiBackMarker and aiRightMarker then
		local attacherJoint = self.plow:getActiveInputAttacherJoint()
		local referenceNode = attacherJoint and attacherJoint.node or self:getDirectionNode()
		-- find out the left/right AI markers distance from the attacher joint (or, if does not exist, the
		-- vehicle's root node) to calculate the offset.
		self.plowReferenceNode = referenceNode
		local leftMarkerDistance, rightMarkerDistance = self:getOffsets(referenceNode, aiLeftMarker, aiRightMarker)
		-- some plows rotate the markers with the plow, so swap left and right when needed
		-- so find out if the left is really on the left of the vehicle's root node or not
		local leftDx, _, _ = localToLocal(aiLeftMarker, self:getDirectionNode(), 0, 0, 0)
		local rightDx, _, _ = localToLocal(aiRightMarker, self:getDirectionNode(), 0, 0, 0)
		if leftDx < rightDx then
			-- left is positive x, so looks like the plow is inverted, swap left/right then
			leftMarkerDistance, rightMarkerDistance = -rightMarkerDistance, -leftMarkerDistance
		end
		-- TODO: Fix this offset dependency and copy paste
		local newToolOffsetX = -(leftMarkerDistance + rightMarkerDistance) / 2
		-- set to the average of old and new to smooth a little bit to avoid oscillations
		self.vehicle.cp.settings.toolOffsetX:set((self.vehicle.cp.settings.toolOffsetX:get() + newToolOffsetX) / 2)
		self.vehicle.cp.totalOffsetX = self.vehicle.cp.settings.toolOffsetX:get()
		self:debug('%s: left = %.1f, right = %.1f, leftDx = %.1f, rightDx = %.1f, setting tool offsetX to %.2f (total offset %.2f)',
			nameNum(self.plow), leftMarkerDistance, rightMarkerDistance, leftDx, rightDx, self.vehicle.cp.settings.toolOffsetX:get(), self.vehicle.cp.totalOffsetX)
	end
end

-- If the left/right AI markers had a consistent orientation (rotation) we could use localToLocal to get the
-- referenceNode's distance in the marker's coordinate system. But that's not the case, so we'll use some vector
-- algebra to calculate how far left/right are the markers from the referenceNode.
function PlowAIDriver:getOffsets(referenceNode, aiLeftMarker, aiRightMarker)
	local refX, _, refZ = getWorldTranslation(referenceNode)
	local lx, _, lz = getWorldTranslation(aiLeftMarker)
	local rx, _, rz = getWorldTranslation(aiRightMarker)
	local leftOffset = -self:getScalarProjection(lx - refX, lz - refZ, lx - rx, lz - rz)
	local rightOffset = self:getScalarProjection(rx - refX, rz - refZ, rx - lx, rz - lz)
	return leftOffset, rightOffset
end

--- Get scalar projection of vector v onto vector u
function PlowAIDriver:getScalarProjection(vx, vz, ux, uz)
	local dotProduct = vx * ux + vz * uz
	local length = math.sqrt(ux * ux + uz * uz)
	return dotProduct / length
end

function PlowAIDriver:hasRotatablePlow()
	return self.plow.spec_plow.rotationPart.turnAnimation ~= nil
end

--- We expect this to be called before the turn starts, so after the turn
function PlowAIDriver:getTurnEndSideOffset()
	if self:hasRotatablePlow() then
		local toolOffsetX = self.vehicle.cp.settings.toolOffsetX:get()
		-- need the double tool offset as the turn end still has the current offset, after the rotation it'll be
		-- on the other side, (one toolOffsetX would put it to 0 only)
		return 2 * toolOffsetX
	else
		return 0
	end
end
