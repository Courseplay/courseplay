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
---@class CombineUnloadAIDriver : AIDriver
CombineUnloadAIDriver = CpObject(AIDriver)

CombineUnloadAIDriver.myStates = {
	ONFIELD = {},
	ONSTREET = {},
	FIND_COMBINE ={},
	FINDPATH_TO_COMBINE={},
	DRIVE_TO_COMBINE = {},
	FINDPATH_TO_COURSE={},
	DRIVE_TO_UNLOADCOURSE ={},
	ALLIGN_TO_COMBINE = {}
}

--- Constructor
function CombineUnloadAIDriver:init(vehicle)
	courseplay.debugVehicle(11,vehicle,'CombineUnloadAIDriver:init()')
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_COMBI
	self:initStates(CombineUnloadAIDriver.myStates)
	self.combineUnloadState =self.states.ONSTREET
	self:setHudContent()
	self:setNewOnFieldState(self.states.FIND_COMBINE)
end

function CombineUnloadAIDriver:setHudContent()
	courseplay.hud:setCombineUnloadAIDriverContent(self.vehicle)
end

function CombineUnloadAIDriver:start(ix)
	AIDriver.start(self, ix)
end

function CombineUnloadAIDriver:drive(dt)
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	if self.combineUnloadState == self.states.ONSTREET then
		if not self:onUnLoadCourse(true, dt) then
			self:hold()
		end
		self:searchForTipTriggers()
		AIDriver.drive(self, dt)
	elseif self.combineUnloadState == self.states.ONFIELD then
		self:driveOnField(dt)
	end
end

function CombineUnloadAIDriver:driveOnField(dt)
	if self.onFieldState == self.states.FIND_COMBINE then
		self.combineToUnload = g_combineUnloadManager:giveMeACombineToUnload()
		if self.combineToUnload ~= nil then
			--print("combine set")
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
		else
			--print("no combine")
		end
		self:hold()

	elseif self.onFieldState == self.states.FINDPATH_TO_COMBINE then
		--get coords of the combine
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.rootNode)
		if self:driveToPointWithPathfinding(cx, cz) then
			self:setNewOnFieldState(self.states.DRIVE_TO_COMBINE)
			self.lastCombinesCoords = { x=cx;
										y=cy;
										z=cz;
			}
		end

	elseif self.onFieldState == self.states.DRIVE_TO_COMBINE then
		--check whether the combine moved meanwhile
		if courseplay:distanceToPoint(self.combineToUnload,self.lastCombinesCoords.x,self.lastCombinesCoords.y,self.lastCombinesCoords.z) > 30 then
			self:setNewOnFieldState(self.states.FINDPATH_TO_COMBINE)
		end

		--if we are in range , change to drive directly
		local cx,cy,cz = getWorldTranslation(self.combineToUnload.rootNode)
		if courseplay:distanceToPoint(self.vehicle,cx,cy,cz) < 50 then
			self:setNewOnFieldState(self.states.ALLIGN_TO_COMBINE)
		end

		-- maybe do obstacle avoiding
	elseif self.onFieldState == self.states.ALLIGN_TO_COMBINE then

		--TODO

	elseif self.onFieldState == self.states.FINDPATH_TO_COURSE then
		if self:startCourseWithPathfinding(self.mainCourse, 1) then
			self:setNewOnFieldState(self.states.DRIVE_TO_UNLOADCOURSE)
		end
	elseif self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
		--do nothing just drive
		-- maybe do obstacle avoiding
	end
	AIDriver.drive(self, dt)

end



function CombineUnloadAIDriver:onEndCourse()
	if self.combineUnloadState == self.states.ONFIELD then
		if self.onFieldState == self.states.DRIVE_TO_UNLOADCOURSE then
			self.combineUnloadState = self.states.ONSTREET
			self:setNewOnFieldState(self.states.FIND_COMBINE)
		end

	else
		self.combineUnloadState = self.states.ONFIELD
	end

end


function CombineUnloadAIDriver:setNewOnFieldState(newState)
	self.onFieldState = newState
end










function CombineUnloadAIDriver:onWhichFieldAmI(vehicle)
	local positionX,_,positionZ = getWorldTranslation(vehicle.cp.DirectionNode or vehicle.rootNode);
	return self:getFieldNumForPosition( positionX, positionZ )
end

function CombineUnloadAIDriver:getFieldNumForPosition( positionX, positionZ )
	local fieldNum = 0;
	for index, field in pairs(courseplay.fields.fieldData) do
		if positionX >= field.dimensions.math.minX and positionX <= field.dimensions.math.maxX and positionZ >= field.dimensions.math.minZ and positionZ <= field.dimensions.math.maxZ then
			local _, pointInPoly, _, _ = courseplay.fields:getPolygonData(field.points, positionX, positionZ, true, true, true);
			if pointInPoly then
				fieldNum = index
				break
			end
		end
	end
	return fieldNum
end
