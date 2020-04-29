--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2020 Thomas Gärtner, Peter Vaiko

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
The CombineUnloadManager dispatches idle unloaders to unload combines.

The combine-unloader association is a many to many association, a combine
can have any number of unloaders, an unloader can have any number of
combines associated with it.

Association is driven by the unloader's HUD where the user selects one or
multiple combines.

When an unloader is done with unloading a combine and has free capacity,
or just returned from the unload course, it asks the CombineUnloadManager
for a combine to unload.

Based on the current situation the CombineUnloadManager may assign a combine
to the unloader but also may just tell it there's nothing to unload
at the moment.


]]--

---@class CombineUnloadmanager
CombineUnloadManager = CpObject()

CombineUnloadManager.debugChannel = 4

-- Constructor
function CombineUnloadManager:init()
	self.combines = {}
	self.unloadersOnFields ={}
	if g_currentMission then
		-- this isn't needed as combines will be added when they are registered
		-- but we want to be able to reload this file on the fly when developing/troubleshooting
		for _, vehicle in pairs(g_currentMission.vehicles) do
			if courseplay:isCombine(vehicle) or courseplay:isChopper(vehicle) then
				self:addCombineToList(vehicle)
			end
		end
	end
end

function CombineUnloadManager:debug(...)
	courseplay.debugFormat(self.debugChannel, 'CombineUnloadManager: ' .. string.format( ... ))
end

function CombineUnloadManager:addCombineToList(combine)
	if combine:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end
	-- we only handle combines with CP AIDriver
	if not combine.cp.driver or not combine.cp.driver:is_a(CombineAIDriver) then
		self:debug('%s has no combine AI driver, adding it now', combine.name)
		combine.cp.driver = CombineAIDriver(combine)
	end
	self:debug('added %s to list', tostring(combine.name))
	self.combines[combine]= {
		isChopper = courseplay:isChopper(combine);
		isCombine = courseplay:isCombine(combine) and not courseplay:isChopper(combine);
		isDriving = false;
		isOnFieldNumber = 0;
		fillLevel = 0;
		fillLevelPct = 0;
		capacity = combine:getFillUnitCapacity(1);
		leftOkToDrive = false;
		rightOKToDrive = false;
		pipeOffset = 0;
		fillLitersPerSecond = 0;
		lastCheckedFillLevel = 0;
		lastCheckedTime = 0;
		unloaders = {};
		secondsTill80Percent = 999
	}
end

function CombineUnloadManager:printStatus()
	for combine,attributes in pairs (self.combines) do
		self:debug('%s unloaders:', nameNum(combine))
		for _, unloader in ipairs(attributes.unloaders) do
			self:debug('  %s', nameNum(unloader))
		end
	end
end

function CombineUnloadManager:removeCombineFromList(combine)
	if self.combines[combine] then
		print(string.format("CombineUnloadmanager: removed %s from list",tostring(combine.name)))
		self.combines[combine] = nil
	end
end

function CombineUnloadManager:getUnloaderIndex(unloader, combine)
	for i=1, #self.combines[combine].unloaders do
		if self.combines[combine].unloaders[i] == unloader then
			return i
		end
	end
end

function CombineUnloadManager:releaseUnloaderFromCombine(unloader,combine)
	if self.combines[combine] then
		local ix = self:getUnloaderIndex(unloader, combine)
		if ix then
			table.remove(self.combines[combine].unloaders, ix)
		end
	end
end

function CombineUnloadManager:addUnloaderToCombine(unloader,combine)
	if not self:getUnloaderIndex(unloader, combine) then
		table.insert(self.combines[combine].unloaders, unloader)
		self:debug('assigned %s to combine %s', nameNum(unloader), nameNum(combine))
	else
		self:debug('%s is already assigned to combine %s', nameNum(unloader), nameNum(combine))
	end
end

function CombineUnloadManager:giveMeACombineToUnload(unloader)
	--first try to find a chopper
	local chopper = self:getChopperWithLeastUnloaders(unloader)
	if chopper ~= nil and chopper.cp.driver:getFieldworkCourse() then
		local unloaderNumber = self:getNumUnloaders(chopper)
		if unloaderNumber == 0 then
			self:addUnloaderToCombine(unloader,chopper)
			return chopper
		elseif unloaderNumber < 2 then
			local prevTractor = self:getUnloaderByNumber(unloaderNumber, chopper)
			if prevTractor == unloader then
				-- awesome, we are on the list already.
				return chopper
			end
			if prevTractor.cp.driver:getFillLevelPercent() > unloader.cp.driver:getFillLevelThreshold() then
				self:addUnloaderToCombine(unloader,chopper)
				return chopper
			end
		end
	end
	--then try to find a combine
	local combine = self:getCombineWithMostFillLevel(unloader)
	self:debug('Combine with most fill level is %s', combine and combine:getName() or 'N/A')
	local unloaderToAssign
	if combine ~= nil and combine.cp.driver:getFieldworkCourse() then
		if combine.cp.wantsCourseplayer then
			self:addUnloaderToCombine(unloader,combine)
			combine.cp.wantsCourseplayer = false
			return combine
		end
		if combine.cp.driverPriorityUseFillLevel then
			unloaderToAssign = self:getFullestUnloader(combine)
			self:debug('Priority fill level, best unloader %s', unloaderToAssign and nameNum(unloaderToAssign) or 'N/A')
		else
			unloaderToAssign = self:getClosestUnloader(combine)
			self:debug('Priority closest, best unloader %s', unloaderToAssign and nameNum(unloaderToAssign) or 'N/A')
		end
		if unloaderToAssign == unloader then
			if combine.cp.driver:willWaitForUnloadToFinish() then
				self:debug("%s: fill level %.1f, waiting for unload", nameNum(combine), combine.cp.driver:getFillLevelPercentage())
				self:addUnloaderToCombine(unloader,combine)
				return combine
			else
				return nil, combine
			end
		end
	end
end

function CombineUnloadManager:getChopperWithLeastUnloaders(unloader)
	--print("FieldManager:getChopperWithLeastUnloaders")
	--first try to Find a chopper
	local chopperToReturn
	local amountUnloaders = math.huge
	for chopper,_ in pairs(unloader.cp.assignedCombines) do
		local data = self.combines[chopper]
		if data.isChopper then
			if amountUnloaders > #data.unloaders or #data.unloaders == 0 then
				chopperToReturn = chopper
				amountUnloaders = #data.unloaders
			end
		end
	end
	return chopperToReturn
end

function CombineUnloadManager:getCombineWithMostFillLevel(unloader)
	local mostFillLevel = 0
	local combineToReturn
	for combine,_ in pairs(unloader.cp.assignedCombines) do
		local data = self.combines[combine]
		-- if there is no unloader assigned or this unloader is already assigned as the first
		if data.isCombine and (self:getNumUnloaders(combine) == 0 or self:getUnloaderIndex(unloader, combine) == 1) then
			if combine.cp.wantsCourseplayer then
				return combine
			end
			local fillLevelPct = combine.cp.driver:getFillLevelPercentage()
			if mostFillLevel < fillLevelPct then
				mostFillLevel = fillLevelPct
				combineToReturn = combine
			end
		end
	end
	return combineToReturn
end

function CombineUnloadManager:getClosestUnloader(combine)
	local closestDistance = math.huge
	local unloaderToReturn
	for unloader,_ in pairs(combine.cp.assignedUnloaders) do
		local distance = courseplay:distanceToObject(unloader, combine)
		if distance < closestDistance then
			closestDistance = distance
			unloaderToReturn = unloader
		end
	end
	return unloaderToReturn
end

function CombineUnloadManager:getClosestCombine(unloader)
	local closestDistance = math.huge
	local combineToReturn
	for combine, _ in pairs(self.combines) do
		local distance = courseplay:distanceToObject(unloader, combine)
		if distance < closestDistance then
			closestDistance = distance
			combineToReturn = combine
		end
	end
	return combineToReturn
end

function CombineUnloadManager:getFullestUnloader(combine)
	local higestFillLevel = 0
	local unloaderToReturn
	for unloader,_ in pairs(combine.cp.assignedUnloaders) do
		local fillLevelPct = unloader.cp.driver:getFillLevelPercent()
		if higestFillLevel < fillLevelPct and not self:getHasCombine(unloader) then
			higestFillLevel = fillLevelPct
			unloaderToReturn = unloader
		end
	end
	return unloaderToReturn
end


function CombineUnloadManager:onUpdate(dt)
	self:updateCombinesAttributes()
end

function CombineUnloadManager:updateCombinesAttributes()
	--update attributes
	local number =1
	for combine,attributes in pairs (self.combines) do
		attributes.isDriving = combine:getIsCourseplayDriving()
		local fieldNum = self:getFieldNumberByCurrentPosition(combine)
		attributes.isOnFieldNumber = fieldNum
		attributes.leftOkToDrive, attributes.rightOKToDrive = self:getOnFieldSituation(combine)
		attributes.pipeOffset = self:getPipeOffset(combine)
		attributes.fillLevelPct = self:getCombinesFillLevelPercent(combine)
		attributes.fillLevel = self:getCombinesFillLevel(combine)
		attributes.secondsTill80Percent = self:getSecondsTill80Percent(combine) and self:getSecondsTill80Percent(combine) or attributes.secondsTill80Percent
		self:updateFillSpeed(combine,attributes)
		if attributes.measuredBackDistance == nil then
			self:raycastBack(combine)
		end
		if courseplay.debugChannels[self.debugChannel] then
			renderText(0.1,0.175+(0.02*number) ,0.015,
					string.format("%s: leftOK: %s; rightOK:%s numUnloaders:%d readyToUnload: %s",
							nameNum(combine), tostring(attributes.leftOkToDrive), tostring(attributes.rightOKToDrive),
							#attributes.unloaders, tostring(combine.cp.driver:isReadyToUnload())))
		end
		number = number + 1
	end
end

function CombineUnloadManager:updateFillSpeed(combine,data)
	if data.isCombine then
		if g_updateLoopIndex % 500 == 0 then
			local timeDiff = combine.timer - data.lastCheckedTime
			data.lastCheckedTime = combine.timer
			local fillDiff = data.fillLevel - data.lastCheckedFillLevel
			data.lastCheckedFillLevel = data.fillLevel
			data.fillLitersPerSecond =  fillDiff/timeDiff*1000 or 0
		end
	else
		data.fillLitersPerSecond = 0
	end
end

function CombineUnloadManager:getSecondsTillFull(combine)
	local data = self.combines[combine]
	local fillDiff = data.capacity -data.fillLevel
	local time = fillDiff/ data.fillLitersPerSecond
	return time >0 and time or 999
end

function CombineUnloadManager:getSecondsTill80Percent(combine)
	local data = self.combines[combine]
	local fillDiff = data.capacity*0.8 -data.fillLevel
	local time = fillDiff/ data.fillLitersPerSecond
	return data.fillLitersPerSecond > 0 and time or nil
end

function CombineUnloadManager:getIsChopper(chopper)
	return self.combines[chopper].isChopper
end
function CombineUnloadManager:getIsCombine(combine)
	return self.combines[combine].isCombine
end

function CombineUnloadManager:getCombinesPipeOffset(combine)
	return self.combines[combine].pipeOffset
end
function CombineUnloadManager:getPossibleSidesToDrive(combine)
	return self.combines[combine].leftOkToDrive, self.combines[combine].rightOKToDrive;
end

function CombineUnloadManager:getFieldNumberByCurrentPosition(vehicle)
	local positionX,_,positionZ = getWorldTranslation(vehicle.cp.directionNode or vehicle.rootNode);
	return courseplay.fields:getFieldNumForPosition( positionX, positionZ )
end

function CombineUnloadManager:getNumUnloaders(combine)
	return self.combines[combine] and #self.combines[combine].unloaders
end

function CombineUnloadManager:getUnloadersNumber(unloader, combine)
	local number = 0
	for i=1,#self.combines[combine].unloaders do
		if self.combines[combine].unloaders[i] == unloader then
			number = i
			break
		end
	end
	return number
end

function CombineUnloadManager:getUnloaderByNumber(number, combine)
	return self.combines[combine] and self.combines[combine].unloaders[number]
end

function CombineUnloadManager:getHasUnloaders(combine)
	return self:getNumUnloaders(combine) > 0
end

function CombineUnloadManager:getHasCombine(unloader)
	local isAssigned = false
	for combine,data in pairs(self.combines) do
		for i = 1, #self.combines[combine].unloaders do
			local unloaderToCheck = self.combines[combine].unloaders[i]
			if unloader == unloaderToCheck then
				isAssigned = true
			end
		end
	end
	return isAssigned
end

function CombineUnloadManager:getPipeOffset(combine)
	if self:getIsChopper(combine) then
		return (combine.cp.workWidth/2)+ 3
	elseif self:getIsCombine(combine) then
		if not combine.getCurrentDischargeNode then
			-- TODO: cotton harvesters for example don't have one...
			return 0
		end
		local dischargeNode = combine:getCurrentDischargeNode().node
		local dnX,dnY,dnZ = getWorldTranslation(dischargeNode)
		local baseNode = self:getPipesBaseNode(combine)
		local tX,tY,tZ = getWorldTranslation(baseNode)
		local pipeOffsetX = worldToLocal(combine.cp.directionNode,tX,tY,tZ)
		local distance = courseplay:distance(dnX,dnZ, tX,tZ)
		--print(string.format(" pipeOffsetX:%s; distance:%s = %s  measured:%s",tostring(pipeOffsetX),tostring(distance),tostring(distance+pipeOffsetX),tostring(measured)))
		if pipeOffsetX > 0 then
			return pipeOffsetX + distance
		elseif pipeOffsetX < 0 then
			return pipeOffsetX - distance
		end
	end
	return 0
end

function CombineUnloadManager:getPipesBaseNode(combine)
	if self:getIsChopper(combine) then
		for i=1,#combine.spec_pipe.nodes do
			local node = combine.spec_pipe.nodes[i]
			if node.autoAimYRotation then
				return node.node
			end
		end
	elseif self:getIsCombine(combine) then
		if not combine.getCurrentDischargeNode then
			-- TODO: cotton harvesters for example don't have one...
			return combine.rootNode
		end

		--TODO find a cleaner way to figure out the getPipesBaseNode
		local dischargeNode = combine:getCurrentDischargeNode().node
		local lastParent = dischargeNode
		while true do
			--print(string.format("   %s: %s",tostring(lastParent),tostring(getName(lastParent))))
			if getName(lastParent) == 'pipe' then
				return lastParent
			end

			lastParent = getParent(lastParent)
		end
	end
end

function CombineUnloadManager:getCombinesFillLevelPercent(combine)
	if not combine.getCurrentDischargeNode then
		-- TODO: cotton harvesters for example don't have one...
		return 0
	end
	local dischargeNode = combine:getCurrentDischargeNode()
	return combine:getFillUnitFillLevelPercentage(dischargeNode.fillUnitIndex)*100
end

function CombineUnloadManager:getCombinesFillLevel(combine)
	if not combine.getCurrentDischargeNode then
		-- TODO: cotton harvesters for example don't have one...
		return 0
	end
	local dischargeNode = combine:getCurrentDischargeNode()
	return combine:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
end


function CombineUnloadManager:getCombinesMeasuredBackDistance(combine)
	return self.combines[combine].measuredBackDistance
end

function CombineUnloadManager:getOnFieldSituation(combine)
	local offset = self:getPipeOffset(combine)

	-- glad we were able to re-use this super confusing notation, jeez, tractor is the combine now or what are we
	-- trying to do here? Handle a towed or tractor attached harvester? And if so, what does it matter if we
	-- check the tractor's sides or the towed/attached harvester's side for fruit?
	local tractor = combine;
	if courseplay:isAttachedCombine(combine) then
		tractor = combine:getAttacherVehicle();
	end;

	-- get world directions

	local node = combine.cp.directionNode or combine.rootNode;
	local straightDirX,_,straightDirZ = localDirectionToWorld(node, 0, 0, 1);
	local leftDirX,_,leftDirZ = localDirectionToWorld(node, 1, 0, 0);
	local rightDirX,_,rightDirZ = localDirectionToWorld(node, -1, 0, 0);
	--set measurements of the box to check
	local boxWidth = 3;
	local boxLength = 6 + combine.cp.workWidth/2;
	--to get the box centered divide the measurements by 2
	local boxWidthCenter = boxWidth/2
	local boxLengthCenter = boxLength/2

	--get the coords of the 3 left box points
	local x, y, z = localToWorld(tractor.cp.directionNode, 0, 0, 0)-- -boxLengthCenter+);
	local lStartX = x + (leftDirX * (math.abs(offset)-boxWidthCenter))
	local lStartZ = z + (leftDirZ * (math.abs(offset)-boxWidthCenter))
	local lWidthX = lStartX + (leftDirX*boxWidth);
	local lWidthZ = lStartZ + (leftDirZ*boxWidth);
	local lHeightX = lStartX + (straightDirX*boxLength);
	local lHeightZ = lStartZ + (straightDirZ*boxLength);

	--get the coords of the 3 right box points
	local rStartX = x + (rightDirX * (math.abs(offset)-boxWidthCenter))
	local rStartZ = z + (rightDirZ * (math.abs(offset)-boxWidthCenter))
	local rWidthX = rStartX + (rightDirX*boxWidth);
	local rWidthZ = rStartZ + (rightDirZ*boxWidth);
	local rHeightX = rStartX + (straightDirX*boxLength);
	local rHeightZ = rStartZ + (straightDirZ*boxLength);

	--fruitType
	local fruitType = combine.spec_combine.lastValidInputFruitType
	local hasFruit = false
	if fruitType == nil or fruitType == 0 then
		hasFruit,fruitType = courseplay:areaHasFruit(x, z, nil, math.abs(offset), math.abs(offset))
	end
	local minHarvestable, maxHarvestable = 1,1
	if fruitType ~= 0  and fruitType ~= nil then
		maxHarvestable = g_fruitTypeManager.fruitTypes[fruitType].numGrowthStates
	end

	--cpDebug:drawLine(lStartX,y+1,lStartZ, 100, 0, 0, lWidthX,y+1,lWidthZ)
	--cpDebug:drawLine(lWidthX,y+1,lWidthZ, 100, 0, 0, lHeightX,y+1,lHeightZ)
	--cpDebug:drawLine(lHeightX,y+1,lHeightZ, 100, 0, 0, lStartX,y+1,lStartZ)

	--cpDebug:drawLine(rStartX,y+1,rStartZ, 0, 100, 0, rWidthX,y+1,rWidthZ)
	--cpDebug:drawLine(rWidthX,y+1,rWidthZ, 0, 100, 0, rHeightX,y+1,rHeightZ)
	--cpDebug:drawLine(rHeightX,y+1,rHeightZ, 0, 100, 0, rStartX,y+1,rStartZ)



	local leftFruit, totalAreaLeft = FieldUtil.getFruitArea(lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
	local rightFruit, totalAreaRight = FieldUtil.getFruitArea(rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
	local leftField = courseplay:isField(lWidthX,lWidthZ,0.1,0.1)
	local rightField = courseplay:isField(rWidthX,rWidthZ,0.1,0.1)

	--print(string.format("fruit:%s; leftFruit:%s; totalLeft:%s, leftField:%s, rightFruit:%s, totalRight:%s; rightField:%s",
	--tostring(fruitType),tostring(leftFruit),tostring(totalArealeft),tostring(leftField),tostring(rightFruit),tostring(totalArearight),tostring(rightField)))

	local leftOK = leftField and leftFruit < totalAreaLeft*0.05
	local rightOK = rightField and rightFruit < totalAreaRight*0.05
	return leftOK,rightOK
end

function CombineUnloadManager:raycastBack(chopper)
	local nx, ny, nz = localDirectionToWorld(chopper.cp.directionNode, 0, 0, 1)
	local x, y, z = localToWorld(chopper.cp.directionNode, 0, 1.5, -10)
	cpDebug:drawLine(x, y, z, 0, 100, 0, x+(nx*10), y+(ny*10), z+(nz*10))
	raycastAll(x, y, z, nx, ny, nz, 'raycastBackCallback', 10, self)
end

-- I believe this tries to figure out how far the back of a combine is from its direction node.
-- TODO: just use vehicle.sizeLength instead?
function CombineUnloadManager:raycastBackCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex)
	if hitObjectId ~= 0 then
		--print("hitObject: "..tostring(hitObjectId).."; distance: "..tostring(distance))
		cpDebug:drawPoint(x, y, z, 1, 1 , 1);
		local object = g_currentMission:getNodeObject(hitObjectId)
		if object and self.combines[object] and self.combines[object].measuredBackDistance == nil then
			self.combines[object].measuredBackDistance = 10 - distance
			print(string.format("%s: measuredBackDistance(%s) = 10 - distance(%s)",tostring(object.name),tostring(self.combines[object].measuredBackDistance),tostring(distance)))
		else
			return true
		end
	end
end

g_combineUnloadManager = CombineUnloadManager()




