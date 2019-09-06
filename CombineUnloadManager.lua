
---@class CombineUnloadmanager
CombineUnloadManager = CpObject()

-- Constructor
function CombineUnloadManager:init()
	print("CombineUnloadManager:init()")
	self.combines = {}
end

g_combineUnloadManager = CombineUnloadManager()


function CombineUnloadManager:addCombineToList(combine)
	print(string.format("CombineUnloadmanager: added %s to list",tostring(combine.name)))
	self.combines[combine]= {}

end

function CombineUnloadManager:removeCombineFromList(combine)
	print(string.format("CombineUnloadmanager: removed %s from list",tostring(combine.name)))
	self.combines[combine] = nil
end

function CombineUnloadManager:giveMeACombineToUnload()
	local combineToUnload
	for combine,data in pairs (self.combines) do
		combineToUnload = combine
	end
	return combineToUnload
end

function CombineUnloadManager:onUpdateTick()
	self:updateCombinesAttributes()


end

function CombineUnloadManager:updateCombinesAttributes()
	--update attributes
	for combine,attributes in pairs (self.combines) do
		attributes.isChopper =  combine:getFillUnitCapacity(combine.spec_combine.fillUnitIndex) > 10000000
		attributes.isCombine =  courseplay:isCombine(combine) and not attributes.isChopper
		attributes.isDriving = combine:getIsCourseplayDriving()
		attributes.isOnFieldNumber = self:getFieldNumber(combine)
		if attributes.sideOffsetToUnload == nil then
			self:updateOnFieldSituation(combine)
		end
		for name,value in pairs (attributes) do
			--print(string.format("%s: %s",tostring(name),tostring(value)))
		end
	end
end

function CombineUnloadManager:updateOnFieldSituation(combine)
	local attributes = self.combines[combine]
	attributes.sideOffsetToUnload, attributes.canBeUnloadedBeside = self:getOnFieldSituation(combine)
	for name,value in pairs (attributes) do
		print(string.format("%s: %s",tostring(name),tostring(value)))
	end
end


function CombineUnloadManager:getIsChopper(chopper)
	return self.combines[chopper].isChopper
end
function CombineUnloadManager:getUnloadSideOffset(combine)
	return self.combines[combine].sideOffsetToUnload
end
function CombineUnloadManager:getCanBeUnloadedBeside(combine)
	return self.combines[combine].canBeUnloadedBeside
end



function CombineUnloadManager:getFieldNumber(vehicle)
	local positionX,_,positionZ = getWorldTranslation(vehicle.cp.DirectionNode or vehicle.rootNode);
	return courseplay.fields:getFieldNumForPosition( positionX, positionZ )
end

function CombineUnloadManager:getPipeOffset(combine)
	if self:getIsChopper(combine) then
		return (combine.cp.workWidth/2)+2.5
	end
end

function CombineUnloadManager:getOnFieldSituation(combine)
	local offset = self:getPipeOffset(combine)
	local canGoBesideCombine = true

	local tractor = combine;
	if courseplay:isAttachedCombine(combine) then
		tractor = combine:getAttacherVehicle();
	end;

	-- get world directions

	local node = combine.cp.DirectionNode or combine.rootNode;
	local straightDirX,_,straightDirZ = localDirectionToWorld(node, 0, 0, 1);
	local leftDirX,_,leftDirZ = localDirectionToWorld(node, 1, 0, 0);
	local rightDirX,_,rightDirZ = localDirectionToWorld(node, -1, 0, 0);
	--set measurements of the box to check
	local boxWidth = 3;
	local boxLength =6;
	--to get the box centered divide the measurements by 2
	local boxWidthCenter = boxWidth/2
	local boxLengthCenter = boxLength/2

	--get the coords of the 3 left box points
	local x, y, z = localToWorld(tractor.cp.DirectionNode, 0, 0, -boxLengthCenter);
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



	local leftFruit, totalArealeft = FieldUtil.getFruitArea(lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
	local rightFruit, totalArearight = FieldUtil.getFruitArea(rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
	local leftField = courseplay:isField(lStartX,lStartZ)
	local rightField = courseplay:isField(rStartX,rStartZ)

	print(string.format("fruit:%s; leftFruit:%s; totalLeft:%s, leftField:%s, rightFruit:%s, totalRight:%s; rightField:%s",
	tostring(fruitType),tostring(leftFruit),tostring(totalArealeft),tostring(leftField),tostring(rightFruit),tostring(totalArearight),tostring(rightField)))

	if leftFruit > rightFruit then
		offset = -offset
	end

	if (not leftField or leftFruit > totalArealeft/10) and (not rightField or rightFruit > totalArearight/10) then
		canGoBesideCombine = false
		offset = 0
	end

	print("canGoBesideCombine:"..tostring(canGoBesideCombine))
	return offset,canGoBesideCombine
end

