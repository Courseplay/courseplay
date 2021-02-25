--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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

A wrapper :) for the standard Bale object

--]]

---@class BaleToCollect
BaleToCollect = CpObject()

---@param baleObject : Bale
function BaleToCollect:init(baleObject)
	self.bale = baleObject
	local x, _, z = getWorldTranslation(self.bale.nodeId)
	-- this finds bales on merged fields too, but the bale must be on the field
	self.fieldId = courseplay.fields:getFieldNumForPosition(x, z)
	if self.fieldId == 0 then
		-- this does not find bales on merged fields, but finds them if they are on the
		-- field border too (just off the field)
		self.fieldId = PathfinderUtil.getFieldIdAtWorldPosition(x, z)
	end
end

--- Call this before attempting to construct a BaleToCollect to check the validity of the object
function BaleToCollect.isValidBale(object)
	-- nodeId is sometimes 0, causing issues for the BaleToCollect constructor
	return object:isa(Bale) and object.nodeId and entityExists(object.nodeId)
end

function BaleToCollect:getFieldId()
	return self.fieldId
end

function BaleToCollect:getId()
	return self.bale.id
end

function BaleToCollect:getPosition()
	return getWorldTranslation(self.bale.nodeId)
end

---@return number, number, number, number x, z, direction from node, distance from node
function BaleToCollect:getPositionInfoFromNode(node)
	local xb, _, zb = self:getPosition()
	local x, _, z = getWorldTranslation(node)
	local dx, dz = xb - x, zb - z
	local yRot = MathUtil.getYRotationFromDirection(dx, dz)
	return xb, zb, yRot, math.sqrt(dx * dx + dz * dz)
end

function BaleToCollect:getPositionAsState3D()
	local xb, _, zb = self:getPosition()
	local _, yRot, _ = getWorldRotation(self.bale.nodeId)
	return State3D(xb, -zb, courseGenerator.fromCpAngle(yRot))
end

--- Minimum distance from the bale's center (node) to avoid hitting the bale
--- when driving by in any direction
function BaleToCollect:getSafeDistance()
	-- round bales don't have length, just diameter
	local length = self.bale.baleDiameter and self.bale.baleDiameter or self.bale.baleLength
	-- no matter what kind of bale, the footprint is a rectangle, get the diagonal
	return math.sqrt(length * length + self.bale.baleWidth * self.bale.baleWidth) / 2
end