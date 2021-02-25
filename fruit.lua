-- inspired by fieldstatus of Alan R. (ls-uk.info: thebadtouch)
function courseplay:areaHasFruit(x, z, fruitType, widthX, widthZ)
	widthX = widthX or 0.5;
	widthZ = widthZ or 0.5;
	if not courseplay:isField(x, z, widthX, widthZ) then
		return false, nil, 0, 0;
	end;

	local density = 0;
	local totalArea = 0
	local maxDensity = 0;
	local maxFruitType = 0
	if fruitType ~= nil and fruitType ~= FruitType.UNKNOWN then
		local minHarvestable, maxHarvestable = 1, fruitType.numGrowthStates
	
		density, totalArea = FieldUtil.getFruitArea(x, z, x - widthX, z - widthZ, x + widthX, z + widthZ, {}, {}, fruitType, minHarvestable , maxHarvestable, 0, 0, 0,false);
		if density > 0 then
			--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), courseplay.DBG_TRAFFIC)
			return true, fruitType, density, totalArea
		end;
	else
		for i = 1, #g_fruitTypeManager.fruitTypes do
			if i ~= g_fruitTypeManager.nameToIndex['GRASS'] and i ~= g_fruitTypeManager.nameToIndex['DRYGRASS'] then 
				local fruitType = g_fruitTypeManager.fruitTypes[i]
				local minHarvestable, maxHarvestable = 1, fruitType.numGrowthStates
				--function FieldUtil.getFruitArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, terrainDetailRequiredValueRanges, terrainDetailProhibitValueRanges, requiredFruitType, requiredMinGrowthState, requiredMaxGrowthState, prohibitedFruitType, prohibitedMinGrowthState, prohibitedMaxGrowthState, useWindrowed
				density,totalArea = FieldUtil.getFruitArea(x, z, x - widthX, z - widthZ, x + widthX, z + widthZ, {}, {}, i, minHarvestable , maxHarvestable, 0, 0, 0,false);
				if density > maxDensity then
					maxDensity = density
					maxFruitType = i
				end
			end;
		end;
		if maxDensity > 0 then
			--courseplay:debug(string.format("checking x: %d z %d - density: %d", x, z, density ), courseplay.DBG_TRAFFIC)
			--print("areaHasFruit: return "..tostring(maxFruitType))
			return true, maxFruitType, maxDensity, totalArea
		end;
	end;

	--courseplay:debug(string.format(" x: %d z %d - is really cut!", x, z ), courseplay.DBG_TRAFFIC)
	return false, nil, 0, 0;
end;

function courseplay:initailzeFieldMod()
    --print("courseplay:initailzeFieldMod()")
	self.fieldMod = {}
    self.fieldMod.modifier = DensityMapModifier:new(g_currentMission.terrainDetailId, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels)
    self.fieldMod.filter = DensityMapFilter:new(self.fieldMod.modifier)
end

function courseplay:isField(x, z, widthX, widthZ)
    --print(string.format("running courseplay:isField(%s, %s, %s, %s)",tostring(x),tostring(z),tostring(widthX),tostring(widthZ)))
	widthX = widthX or 0.5
    widthZ = widthZ or 0.5
	local startWorldX, startWorldZ   = x, z
	local widthWorldX, widthWorldZ   = x - widthX, z - widthZ
	local heightWorldX, heightWorldZ = x + widthX, z + widthZ
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, startWorldX, 1, startWorldZ)

	--cpDebug:drawLine(startWorldX,y+1,startWorldZ, 0, 100, 0, widthWorldX,y+1,widthWorldZ)
	--cpDebug:drawLine(widthWorldX,y+1,widthWorldZ, 0, 100, 0, heightWorldX,y+1,heightWorldZ)
	--cpDebug:drawLine(heightWorldX,y+1,heightWorldZ, 0, 100, 0, startWorldX,y+1,startWorldZ)

    self.fieldMod.modifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, "ppp")
    self.fieldMod.filter:setValueCompareParams("greater", 0)

    local _, area, totalArea = self.fieldMod.modifier:executeGet( self.fieldMod.filter)
	local isField = area > 0
	return isField, area, totalArea
end

