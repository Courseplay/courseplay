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
	self:addNewCombines()
end

function CombineUnloadManager:addNewCombines()
	if g_currentMission then
		-- this isn't needed as combines will be added when an CombineAIDriver is created for them
		-- but we want to be able to reload this file on the fly when developing/troubleshooting
		for _, vehicle in pairs(g_currentMission.vehicles) do
			if vehicle.cp.driver and vehicle.cp.driver:is_a(CombineAIDriver) and not self.combines[vehicle] then
				self:addCombineToList(vehicle, vehicle.cp.driver)
			end
		end
	end
end

function CombineUnloadManager:debug(...)
	courseplay.debugFormat(self.debugChannel, 'CombineUnloadManager: ' .. string.format( ... ))
end

function CombineUnloadManager:debugSparse(...)
	if g_updateLoopIndex % 110 == 0 then
		self:debug(...)
	end
end

function CombineUnloadManager:addCombineToList(vehicle, driver)
	if vehicle:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end
	-- the object with the combine specialization, this is the same as the vehicle for choppers and combines
	-- but will point to the implement if it is a towed/mounted harvester
	local combineObject = driver:getCombine()
	-- overloaders also use the CombineAIDriver, but they don't have a combine object
	if not combineObject then return end
	self:debug('added %s to list (combine object %s)', vehicle.name, combineObject.name)
	self.combines[vehicle]= {
		driver = driver,
		combineObject = combineObject,
		isChopper = courseplay:isChopper(combineObject),
		isCombine = (courseplay:isCombine(combineObject) or combineObject.isPremos) and not courseplay:isChopper(combineObject),
		isOnFieldNumber = 0;
		fillLevel = 0;
		fillLevelPct = 0;
		capacity = combineObject:getFillUnitCapacity(1);
		leftOkToDrive = false;
		rightOKToDrive = false;
		pipeOffset = 0;
		fillLitersPerSecond = 0;
		lastCheckedFillLevel = 0;
		lastCheckedTime = 0;
		unloaders = {};
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
		self:debug("removed %s from list", tostring(combine.name))
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

function CombineUnloadManager:releaseUnloaderFromCombine(unloader, combine, noEventSend)
	if self.combines[combine] then
		local ix = self:getUnloaderIndex(unloader, combine)
		if ix then
			self:debug('Released unloader %s from %s', nameNum(unloader), nameNum(combine))
			table.remove(self.combines[combine].unloaders, ix)
			if not noEventSend then 
				UnloaderEvents:sendRelaseUnloaderEvent(unloader,combine)
			end
		end
	end
end

function CombineUnloadManager:addUnloaderToCombine(unloader,combine,noEventSend)
	if not self:getUnloaderIndex(unloader, combine) then
		table.insert(self.combines[combine].unloaders, unloader)
		self:debug('assigned %s to combine %s as #%d', nameNum(unloader), nameNum(combine), #self.combines[combine].unloaders)
		if not noEventSend then
			UnloaderEvents:sendAddUnloaderToCombine(unloader,combine)
		end
	else
		self:debug('%s is already assigned to combine %s as	 #%d', nameNum(unloader), nameNum(combine), #self.combines[combine].unloaders)
	end
end

function CombineUnloadManager:giveMeACombineToUnload(unloader)
	--first try to find a chopper
	local chopper = self:getChopperWithLeastUnloaders(unloader)
	if chopper ~= nil and chopper.cp.driver:getFieldworkCourse() then
		local nUnloaders = self:getNumUnloaders(chopper)
		if nUnloaders == 0 then
			-- chopper has no unloader yet
			self:addUnloaderToCombine(unloader, chopper)
			return chopper
		else
			local num = self:getUnloadersNumber(unloader, chopper)
			if num then
				-- awesome, we are on the list already.
				self:debug('%s already assigned to %s as #%d', nameNum(unloader), nameNum(chopper), num)
				return chopper
			end
			if nUnloaders == 1 then
				local otherUnloader = self:getUnloaderByNumber(nUnloaders, chopper)
				-- when unloading choppers, the 'start at fill level' settings for the second unloader is the fill
				-- level of the currently active unloader must reach before we start driving to the chopper
				if otherUnloader.cp.driver:getFillLevelPercent() > unloader.cp.driver:getFillLevelThreshold() then
					-- other unloader has already reached the fill level needed
					self:addUnloaderToCombine(unloader, chopper)
					return chopper
				else
					self:debug('Other unloader %s fill level not reached, not assigning %s as second unloader to %s',
							nameNum(otherUnloader), nameNum(unloader), nameNum(chopper))
				end
			else
				-- we only allow 2 unloaders for a chopper, one actively unloading and a second one ready to take
				-- over.
				self:debug('%s has already 2 unloaders, not adding %s', nameNum(chopper), nameNum(unloader))
			end
		end
	end
	--then try to find a combine
	local combine = self:getCombineWithMostFillLevel(unloader)
	self:debug('Combine with most fill level is %s', combine and combine:getName() or 'N/A')
	local bestUnloader
	if combine ~= nil and combine.cp.driver:getFieldworkCourse() then
		if combine.cp.settings.combineWantsCourseplayer:is(true) then
			self:addUnloaderToCombine(unloader,combine)
			combine.cp.settings.combineWantsCourseplayer:set(false)
			return combine
		end
		local unloaders = self:getUnloaders(combine)
		if combine.cp.settings.driverPriorityUseFillLevel:is(true) then
			bestUnloader = self:getFullestUnloader(combine, unloaders)
			self:debug('Priority fill level, best unloader %s', bestUnloader and nameNum(bestUnloader) or 'N/A')
		else
			bestUnloader = self:getClosestUnloader(combine, unloaders)
			self:debug('Priority closest, best unloader %s', bestUnloader and nameNum(bestUnloader) or 'N/A')
		end
		if bestUnloader == unloader then
      if self:getCombinesFillLevelPercent(combine) > unloader.cp.driver:getFillLevelThreshold() or	combine.cp.driver:willWaitForUnloadToFinish() then
				self:debug("%s: fill level %.1f, waiting for unload", nameNum(combine), self:getCombinesFillLevelPercent(combine))
				self:addUnloaderToCombine(unloader, combine)
				return combine
			else
				return nil, combine
			end
		end
	end
end

function CombineUnloadManager:getChopperWithLeastUnloaders(unloader)
	local chopperToReturn
	local amountUnloaders = math.huge
	for chopper,_ in pairs(unloader.cp.driver:getAssignedCombines()) do
		local data = self.combines[chopper]
		if data and data.isChopper then
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
	for combine,_ in pairs(unloader.cp.driver:getAssignedCombines()) do
		local data = self.combines[combine]
		-- if there is no unloader assigned or this unloader is already assigned as the first
		if data and data.isCombine and (self:getNumUnloaders(combine) == 0 or self:getUnloaderIndex(unloader, combine) == 1) then
			if combine.cp.settings.combineWantsCourseplayer:is(true) then
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

function CombineUnloadManager:getUnloaders(combine)
	local unloaders = {}
	if g_currentMission then
		for _, vehicle in pairs(g_currentMission.vehicles) do
			if vehicle.cp.driver and vehicle.cp.driver:is_a(CombineUnloadAIDriver) then
				-- TODO: refactor and move assignedCombines into the CombineUnloadAIDriver
				local assignedCombines = vehicle.cp.driver:getAssignedCombines()
				if assignedCombines[combine] then
					table.insert(unloaders, vehicle)
				end
			end
		end
	end
	return unloaders
end


function CombineUnloadManager:getClosestUnloader(combine, unloaders)
	local closestDistance = math.huge
	local unloaderToReturn
	for _, unloader in pairs(unloaders) do
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

function CombineUnloadManager:getFullestUnloader(combine, unloaders)
	local highestFillLevel = - math.huge
	local unloaderToReturn
	for _, unloader in pairs(unloaders) do
		local fillLevelPct = unloader.cp.driver:getFillLevelPercent()
		if highestFillLevel < fillLevelPct and not self:isAssignedToOtherCombine(unloader, combine) then
			highestFillLevel = fillLevelPct
			unloaderToReturn = unloader
		end
	end
	return unloaderToReturn
end


function CombineUnloadManager:onUpdate(dt)
	self:addNewCombines()
	self:removeInactiveCombines()
	self:updateCombinesAttributes()
end

--- Remove everyone from the list who does not have a CombineAIDriver (for instance because the mode was changed)
function CombineUnloadManager:removeInactiveCombines()
	local vehiclesToRemove = {}
	for vehicle, _ in pairs (self.combines) do
		if not vehicle.cp.driver or not vehicle.cp.driver:is_a(CombineAIDriver) then
			table.insert(vehiclesToRemove, vehicle)
		end
	end
	for _, vehicle in ipairs(vehiclesToRemove) do
		self:removeCombineFromList(vehicle)
	end
end

function CombineUnloadManager:updateCombinesAttributes()
	--update attributes
	local number =1
	for combine,attributes in pairs (self.combines) do
		attributes.isOnFieldNumber = self:getFieldNumberByCurrentPosition(combine)
		attributes.leftOkToDrive, attributes.rightOKToDrive = self:getOnFieldSituation(combine)
		attributes.pipeOffset = self:getPipeOffset(combine)
		attributes.fillLevelPct = self:getCombinesFillLevelPercent(combine)
		attributes.fillLevel = self:getCombinesFillLevel(combine)
		self:updateFillSpeed(combine,attributes)
		if courseplay.debugChannels[self.debugChannel] then
			renderText(0.1,0.175+(0.02*number) ,0.015,
					string.format("%s: leftOK: %s; rightOK:%s numUnloaders:%d",
							nameNum(combine), tostring(attributes.leftOkToDrive), tostring(attributes.rightOKToDrive),
							#attributes.unloaders))
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
	local x, _, z = getWorldTranslation(vehicle.rootNode);
	return PathfinderUtil.getFieldIdAtWorldPosition(x, z)
end

function CombineUnloadManager:getFieldNumber(vehicle)
	if self.combines[vehicle] then
		return self.combines[vehicle].isOnFieldNumber
	else
		return 0
	end
end

function CombineUnloadManager:getNumUnloaders(combine)
	return self.combines[combine] and #self.combines[combine].unloaders or 0
end

function CombineUnloadManager:getUnloadersNumber(unloader, combine)
	for i = 1, #self.combines[combine].unloaders do
		if self.combines[combine].unloaders[i] == unloader then
			return i
		end
	end
end

function CombineUnloadManager:getUnloaderByNumber(number, combine)
	return self.combines[combine] and self.combines[combine].unloaders[number]
end

function CombineUnloadManager:getHasUnloaders(combine)
	return self:getNumUnloaders(combine) > 0
end

--- Is this unloader assigned to a combine other than thisCombine
function CombineUnloadManager:isAssignedToOtherCombine(unloader, thisCombine)
	for combine, _ in pairs(self.combines) do
		for i = 1, #self.combines[combine].unloaders do
			local unloaderToCheck = self.combines[combine].unloaders[i]
			if unloader == unloaderToCheck and combine ~= thisCombine then
				return true
			end
		end
	end
	return false
end

function CombineUnloadManager:getPipeOffset(combine)
	if self:getIsChopper(combine) then
		return (combine.cp.workWidth / 2) + 3
	elseif self:getIsCombine(combine) then
		local pipeOffsetX, _ = combine.cp.driver:getPipeOffset()
		return pipeOffsetX
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
		while entityExists(lastParent) do
			if getName(lastParent) == 'pipe' then
				return lastParent
			end

			lastParent = getParent(lastParent)
		end
	end
	-- if nothing found, use the root node
	return combine.rootNode
end

function CombineUnloadManager:getCombinesFillLevelPercent(combine)
  local combine = combine.cp.driver:getCombine()
    
  if combine then
      if not combine.getCurrentDischargeNode then
          -- TODO: cotton harvesters for example don't have one...
          return 0
      end
      local dischargeNode = combine:getCurrentDischargeNode()
      return combine:getFillUnitFillLevelPercentage(dischargeNode.fillUnitIndex)*100
  else 
      return 0
  end
end

function CombineUnloadManager:getCombinesFillLevel(combine)
  local combine = combine.cp.driver:getCombine()

  if combine then
      if not combine.getCurrentDischargeNode then
          -- TODO: cotton harvesters for example don't have one...
          return 0
      end
      local dischargeNode = combine:getCurrentDischargeNode()
      return combine:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
  else 
      return 0
  end
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
	local fruitType = combine.cp.driver.combine.lastValidInputFruitType
	local hasFruit = false
	if fruitType == nil or fruitType == 0 then
		hasFruit,fruitType = courseplay:areaHasFruit(x, z, nil, math.abs(offset), math.abs(offset))
	end
	local noFruitOnLeft, noFruitOnRight = true, true
	if fruitType ~= 0  and fruitType ~= nil then
		local minHarvestable, maxHarvestable = 1, 1
		maxHarvestable = g_fruitTypeManager.fruitTypes[fruitType].numGrowthStates

	--cpDebug:drawLine(lStartX,y+1,lStartZ, 100, 0, 0, lWidthX,y+1,lWidthZ)
	--cpDebug:drawLine(lWidthX,y+1,lWidthZ, 100, 0, 0, lHeightX,y+1,lHeightZ)
	--cpDebug:drawLine(lHeightX,y+1,lHeightZ, 100, 0, 0, lStartX,y+1,lStartZ)

	--cpDebug:drawLine(rStartX,y+1,rStartZ, 0, 100, 0, rWidthX,y+1,rWidthZ)
	--cpDebug:drawLine(rWidthX,y+1,rWidthZ, 0, 100, 0, rHeightX,y+1,rHeightZ)
	--cpDebug:drawLine(rHeightX,y+1,rHeightZ, 0, 100, 0, rStartX,y+1,rStartZ)

		local leftFruit, totalAreaLeft = FieldUtil.getFruitArea(lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
		noFruitOnLeft = leftFruit < totalAreaLeft * 0.05
		local rightFruit, totalAreaRight = FieldUtil.getFruitArea(rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
		noFruitOnRight = rightFruit < totalAreaRight * 0.05
	end

	local leftField = courseplay:isField(lWidthX, lWidthZ,0.1,0.1)
	local rightField = courseplay:isField(rWidthX, rWidthZ,0.1,0.1)
	-- TODO: for now, it isn't ok to drive off the field when following a chopper.
	if not self:getIsChopper(combine) then
		leftField, rightField = true, true
	end
	local leftOK = leftField and noFruitOnLeft
	local rightOK = rightField and noFruitOnRight
	return leftOK, rightOK
end

function CombineUnloadManager:getPossibleCombines(vehicle)
	local possibleCombines = {}
	for combine,data in pairs (g_combineUnloadManager.combines) do
		local selectedField = vehicle.cp.settings.searchCombineOnField:get()
		if data.isOnFieldNumber == selectedField or data.isOnFieldNumber == 0 or selectedField ==0 then
			table.insert(possibleCombines, combine)
		end
	end
	return possibleCombines
end

g_combineUnloadManager = CombineUnloadManager()




