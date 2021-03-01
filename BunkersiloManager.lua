---@class BunkerSiloManager
BunkerSiloManager = CpObject()

BunkerSiloManager.debugChannel = courseplay.DBG_MODE_10

BunkerSiloManager.MODE = {}
BunkerSiloManager.MODE.COMPACTING = 0 --LevelCompactAIDriver compacting without shield
BunkerSiloManager.MODE.SHIELD = 1 --LevelCompactAIDriver leveling/filUup with shield
BunkerSiloManager.MODE.SHOVEL = 2 --ShovelModeAIDriver 
BunkerSiloManager.MODE.UNLOADING = 3 --unloading in bunker with GrainTransport-,UnloadableFieldwork-,CombineUnloadAIDriver


--for reference look up : "https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=26&class=244"
--mostly : "BunkerSilo:load(id, xmlFile, key)"
--[[
	example bunker with only one entrance side

				-----------------	<-- heightNode (hx,_,hz)
				| X X X X X X X |  				   ---
				| X X X X X X X | 					|
				| X X X X X X X | 					|
				| X X X X X X X | 					|
				| X X X X X X X | 					|	 bunkerLength 
				| X X X X X X X | 					|
				| X X X X X X X | 					|
				| X X X X X X X | 					|
				| X X X X X X X | 					|
				| X X X X X X X |  				   ---
widthNode -->	|				|	<-- startNode (sx,_,sz)
(wx,_,wz)	
				|---------------|
				   bunkerWidth
		
		X = unitArea = unitWidth*unitHeigth


]]--

---@param vehicle vehicle
---@param Silo BunkerSilo or simulated HeapSilo
---@param float work width of the relevant tool
---@param node targetNode is either the front/back node of the implement used to check if the bestTarget was passed
---@param int driver mode (shovel,unloading,shield,compacting)
---@param boolean is the silo a heap ?
function BunkerSiloManager:init(vehicle, silo, workWidth, targetNode,driverMode, isHeap)
	self.silo = silo
	self.vehicle = vehicle
	self.targetNode = targetNode
	self.isHeap = isHeap
	self.driverMode = driverMode
	self.siloMap = self:createBunkerSiloMap(workWidth)
end

---Gets the driver mode 
---@return int driver mode (shovel,unloading,shield,compacting) 
function BunkerSiloManager:getDriverMode()
	return self.driverMode
end

function BunkerSiloManager:getSiloMap()
	return self.siloMap
end

---Get silo part by line and column index
---@param int line index
---@param int column index
---@return table silo part
function BunkerSiloManager:getSiloPart(line,column)
	return self.siloMap[line][column]
end

---Get silo part drive positions by line and column index,
---which have an driving offset near the bunker walls
---@param int line index
---@param int column index
---@return float cx/cz drive position 
function BunkerSiloManager:getSiloPartPosition(line,column)
	local siloPart = self:getSiloPart(line,column)
	return siloPart.cx,siloPart.cz
end

---Get silo part center positions by line and column index
---@param int line index
---@param int column index
---@return float bx/bz center position of part
function BunkerSiloManager:getSiloPartCenterPosition(line,column)
	local siloPart = self:getSiloPart(line,column)
	return siloPart.bx,siloPart.bz
end

---Get silo part start/width/height positions by line and column index
---@param int line index
---@param int column index
---@return float sx/sz start position of part
---@return float wx/wz width position of part
---@return float hx/hz height position of part
function BunkerSiloManager:getSiloPartStartWidthHeightPositions(line,column)
	local siloPart = self:getSiloPart(line,column)
	return siloPart.sx,siloPart.sz,siloPart.wx,siloPart.wz,siloPart.hx,siloPart.hz
end

---Gets silo part fillLevel
---@param int line index
---@param int column index
---@return float silo part fillLevel
function BunkerSiloManager:getSiloPartFillLevel(line,column)
	local fillLevel = 0
	local fillType = self:getSiloPartFillType(line,column)
	if fillType and fillType ~= 0 then 
		local sx,sz,wx,wz,hx,hz = self:getSiloPartStartWidthHeightPositions(line,column)
		fillLevel = DensityMapHeightUtil.getFillLevelAtArea(fillType,sx,sz,wx,wz,hx,hz)
	end
	return fillLevel
end

---Gets silo line total fillLevel
---@param int line index
---@return float silo line fillLevel
function BunkerSiloManager:getSiloPartLineFillLevel(line)
	local totalFillLevel = 0
	local numColumns = self:getNumberOfColumns()
	for column=1,numColumns do 
		totalFillLevel = totalFillLevel + self:getSiloPartFillLevel(line,column)
	end
	return totalFillLevel
end

---Gets silo column total fillLevel
---@param int column index
---@return float silo column fillLevel
function BunkerSiloManager:getSiloPartColumnFillLevel(column)
	local totalFillLevel = 0
	local numLines = self:getNumberOfLines()
	for line=1,numLines do 
		totalFillLevel = totalFillLevel + self:getSiloPartFillLevel(line,column)
	end
	return totalFillLevel
end

---Gets silo column with the most fillLevel
---@param int optional line index
---@return int silo column with most fillLevel
function BunkerSiloManager:getSiloPartColumnWithMostFillLevel(line)
	local lastFillLevel = 0
	local lastColumn = 1
	local numColumns = self:getNumberOfColumns()
	for column=1,numColumns do 
		local fillLevel = 0 
		if line then 
			fillLevel = self:getSiloPartFillLevel(line,column)
		else 
			fillLevel = self:getSiloPartColumnFillLevel(column)
		end
		if fillLevel > lastFillLevel then 
			lastFillLevel = fillLevel
			lastColumn = column
		end
	end
	return lastColumn
end

---Gets silo column with the least fillLevel
---@param int optional line index
---@return int silo column with least fillLevel
function BunkerSiloManager:getSiloPartColumnWithLeastFillLevel(line)
	local lastFillLevel = math.huge
	local lastColumn = 1
	local numColumns = self:getNumberOfColumns()
	for column=1,numColumns do 
		local fillLevel = 0 
		if line then 
			fillLevel = self:getSiloPartFillLevel(line,column)
		else 
			fillLevel = self:getSiloPartColumnFillLevel(column)
		end
		if fillLevel < lastFillLevel then 
			lastFillLevel = fillLevel
			lastColumn = column
		end
	end
	return lastColumn
end

---Gets silo line with the most fillLevel
---@param int optional column index
---@return int silo line with most fillLevel
function BunkerSiloManager:getSiloPartLineWithMostFillLevel(column)
	local lastFillLevel = 0
	local lastLine = 1
	local numLines = self:getNumberOfLines()
	for line=1,numLines do 
		local fillLevel = 0 
		if line then 
			fillLevel = self:getSiloPartFillLevel(line,column)
		else 
			fillLevel = self:getSiloPartLineFillLevel(line)
		end
		if fillLevel > lastFillLevel then 
			lastFillLevel = fillLevel
			lastLine = line
		end
	end
	return lastLine
end

---Gets silo line with the least fillLevel
---@param int optional column index
---@return int silo line with least fillLevel
function BunkerSiloManager:getSiloPartLineWithLeastFillLevel(column)
	local lastFillLevel = math.huge
	local lastLine = 1
	local numLines = self:getNumberOfLines()
	for line=1,numLines do 
		local fillLevel = 0 
		if line then 
			fillLevel = self:getSiloPartFillLevel(line,column)
		else 
			fillLevel = self:getSiloPartLineFillLevel(line)
		end
		if fillLevel < lastFillLevel then 
			lastFillLevel = fillLevel
			lastLine = line
		end
	end
	return lastLine
end


---Gets the first silo part line, which has a fillLevel >0
---@return int first silo line which has a fillLevel >0
function BunkerSiloManager:getFirstSiloPartLineWithFillLevel()
	local numLines = self:getNumberOfLines()
	for line=1,numLines do 
		local fillLevel = self:getSiloPartLineFillLevel(line)
		if fillLevel > 0 then 
			return line
		end
	end
	return 1
end

---Gets the first silo part line with fillLevel > 0  for a column
---@param int column index
---@return int first silo line with fillLevel > 0  for a column
function BunkerSiloManager:getFirstSiloPartLineWithFillLevelForColumn(column)
	local numLines = self:getNumberOfLines()
	for line=1,numLines do 
		local fillLevel = self:getSiloPartFillLevel(line,column)
		if fillLevel > 0 then 
			return line
		end
	end
	return 1
end

---Gets the first silo part column with fillLevel > 0  for a line
---@param int line index
---@return int first silo column with fillLevel > 0 for a line
function BunkerSiloManager:getFirstSiloPartColumnWithFillLevelForLine(line)
	local numColumns = self:getNumberOfColumns()
	for column=1,numColumns do 
		local fillLevel = self:getSiloPartFillLevel(line,column)
		if fillLevel > 0 then 
			return column
		end
	end
	return 1
end

---Gets silo part fillType
---@param int line index
---@param int column index
---@return int silo part fillType index
function BunkerSiloManager:getSiloPartFillType(line,column)
	local sx,sz,wx,wz,hx,hz = self:getSiloPartStartWidthHeightPositions(line,column)
	local wy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, 1, wz);
	local hy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, hx, 1, hz)
	return DensityMapHeightUtil.getFillTypeAtLine(wx, wy, wz, hx, hy, hz, 5)
end

---Get silo part area
---@param int line index
---@param int column index
---@return float silo part area
function BunkerSiloManager:getSiloPartArea(line,column)
	local siloPart = self:getSiloPart(line,column)
	return siloPart.area
end

---Get silo part line area
---@param int line index
---@return float silo part line area
function BunkerSiloManager:getSiloPartLineArea(line)
	local area = 0
	local numColumns = self:getNumberOfColumns()
	for column = 1, numColumns do 
		area = area + self:getSiloPartArea(line,column)
	end
	return area
end

---Get silo part column area
---@param int column index
---@return float silo part column area
function BunkerSiloManager:getSiloPartColumnArea(column)
	local area = 0
	local numLines = self:getNumberOfLines()
	for line = 1, numLines do 
		area = area + self:getSiloPartArea(line,column)
	end
	return area
end

---Get number of columns
---@return int number of columns
function BunkerSiloManager:getNumberOfColumns()
	return #self.siloMap[1]
end

---Get number of lines
---@return int number of lines
function BunkerSiloManager:getNumberOfLines()
	return #self.siloMap
end

---Get number of lines and columns
---@return int number of lines
---@return int number of columns
function BunkerSiloManager:getNumberOfLinesAndColumns()
	return self:getNumberOfLines(),self:getNumberOfColumns()
end

function BunkerSiloManager:getSilo()
	return self.silo
end

function BunkerSiloManager:isHeapSiloMap()
	return self.isHeap
end

---creating the relevant siloMap
---@param float work width of the relevant tool
function BunkerSiloManager:createBunkerSiloMap(width)

	local bunkerSiloArea = self.silo.bunkerSiloArea

	--only for Heaps as this createBunkerSiloMap() also applies to it ..
	local sx,sz = bunkerSiloArea.sx,bunkerSiloArea.sz; --start BunkerNode
	local wx,wz = bunkerSiloArea.wx,bunkerSiloArea.wz; --width BunkerNode "x cordinate"
	local hx,hz = bunkerSiloArea.hx,bunkerSiloArea.hz; --height/"depth" BunkerNode "z cordinate"
	local bunkerWidth = courseplay:distance(sx,sz, wx, wz) 
	local bunkerLength = courseplay:distance(sx,sz, hx, hz)
	local sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 1, sz);
	
	-- check the distance from our vehicle either we are comming from the front or back of the silo
	local startDistance = courseplay:distanceToPoint(self.vehicle, sx, sy, sz)
	local endDistance = courseplay:distanceToPoint(self.vehicle, hx, sy, hz)
	
	--correct data for bunkerSilos
	--shorten the BunkerArea by 1.0 , as the silo size from Giants tends to be bigger the the actual fillArea 
	if bunkerSiloArea.start then
		sx, _, sz = localToWorld(bunkerSiloArea.start,-0.5,0,0) --start BunkerNode
		wx, _, wz = localToWorld(bunkerSiloArea.width,0.5,0,0) --width BunkerNode "x cordinate"
		hx, _, hz = localToWorld(bunkerSiloArea.height,-0.5,0,1) --height/"depth" BunkerNode "z cordinate"
		bunkerWidth = calcDistanceFrom(bunkerSiloArea.start,bunkerSiloArea.width)-1
		bunkerLength = calcDistanceFrom(bunkerSiloArea.start,bunkerSiloArea.height)-1
	end

		
	local widthDirX,widthDirY,widthDirZ,widthDistance = courseplay:getWorldDirection(sx,sy,sz, wx,sy,wz);
	local heightDirX,heightDirY,heightDirZ,heightDistance = courseplay:getWorldDirection(sx,sy,sz, hx,sy,hz);

	local widthCount = 0
	self:debug('Bunker width %.1f, working width %.1f (passed in)', bunkerWidth, width)
	widthCount =math.ceil(bunkerWidth/width)

	if self:getDriverMode() == self.MODE.SHIELD and courseplay:isEven(widthCount) then 
		widthCount = widthCount+1
	end

	local heightCount = math.ceil(bunkerLength/ width)
	local unitWidth = bunkerWidth/widthCount
	local unitHeigth = bunkerLength/heightCount
	
	--width/height in 2D(x and z separated) of silo

	local heightLengthX = (hx-sx)/heightCount
	local heightLengthZ = (hz-sz)/heightCount
	local widthLengthX = (wx-sx)/widthCount
	local widthLengthZ = (wz-sz)/widthCount
	local getOffTheWall = 1;

	local lastValidfillType = 0
	local map = {}
	for heightIndex = 1,heightCount do
		map[heightIndex]={}
		for widthIndex = 1,widthCount do
			local newWx = sx + widthLengthX
			local newWz = sz + widthLengthZ
			local newHx = sx + heightLengthX
			local newHz = sz + heightLengthZ
			
			--herrain height at start of small part
			local wY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newWx, 1, newWz);
			--herrain height at end of small part
			local hY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newHx, 1, newHz);
			--fillType in between 
			local fillType = DensityMapHeightUtil.getFillTypeAtLine(newWx, wY, newWz, newHx, hY, newHz, 5)
			if lastValidfillType ~= fillType and fillType ~= 0 then
				lastValidfillType = fillType
			end
			--fillLevel in small part
			local newFillLevel = DensityMapHeightUtil.getFillLevelAtArea(fillType, sx, sz, newWx, newWz, newHx, newHz )
			--center probably of small part ??
			local bx = sx + (widthLengthX/2) + (heightLengthX/2)
			local bz = sz + (widthLengthZ/2) + (heightLengthZ/2)
			local offset = 0

			if self:isHeapSiloMap() then
				offset = unitWidth/2
			else
				if widthIndex == 1 then
					offset = getOffTheWall + (width / 2)
				elseif widthIndex == widthCount then
					offset = unitWidth- (getOffTheWall + (width / 2))
				else
					offset = unitWidth / 2
				end
			end
			-- something with direction ??
			local cx,cz = sx +(widthDirX*offset)+(heightLengthX/2),sz +(widthDirZ*offset)+ (heightLengthZ/2)
			if self:getDriverMode() == self.MODE.SHOVEL and heightIndex == heightCount then
				cx,cz = sx +(widthDirX*offset)+(heightLengthX),sz +(widthDirZ*offset)+ (heightLengthZ)
			end
			local unitArea = unitWidth*unitHeigth

			map[heightIndex][widthIndex] ={
				sx = sx;	-- start?
				sz = sz;
				y = wY;
				wx = newWx; -- width?
				wz = newWz;
				hx = newHx; -- height?
				hz = newHz;
				cx = cx;     -- center
				cz = cz;
				bx = bx;
				bz = bz;
				area = unitArea;
				fillLevel = newFillLevel;
				fillType = fillType;
				bunkerLength = bunkerLength;
				bunkerWidth = bunkerWidth;
			}

			sx = map[heightIndex][widthIndex].wx
			sz = map[heightIndex][widthIndex].wz
		end
		sx = map[heightIndex][1].hx
		sz = map[heightIndex][1].hz
	end
	if lastValidfillType > 0 then
		self:debug('Bunker silo filled with %s(%i) will be divided in %d lines and %d column',g_fillTypeManager.indexToName[lastValidfillType], lastValidfillType, heightCount, widthCount)
	else
		courseplay.infoVehicle(self.vehicle,'Empty bunker silo will be divided in %d lines and %d columns',heightCount,widthCount)
	end
	--invert table as we are coming from the back into the silo
	if endDistance < startDistance then
		self:debug('Bunker silo will be approached from the back, so inverted the silo map')
		local newMap = {}
		local lineCounter = #map
		for lineIndex=1,lineCounter do
			local newLineIndex = lineCounter+1-lineIndex;
			--print(string.format("put line%s into line%s",tostring(lineIndex),tostring(newLineIndex)))
			newMap[newLineIndex]={}
			local columnCount = #map[lineIndex]
			for columnIndex =1, columnCount do
				--print(string.format("  put column%s into column%s",tostring(columnIndex),tostring(columnCount+1-columnIndex)))
				newMap[newLineIndex][columnCount+1-columnIndex] = map[lineIndex][columnIndex]
			end
		end
		map = newMap
	end
	return map
end

---Check if the bunker silo map setup valid ?
---@return boolean isSiloEmpty ?
function BunkerSiloManager:isSiloMapValid()
	return self.siloMap and not self:isSiloEmpty() or false
end

---Check if a siloMap was created and it's not empty
---@return boolean isSiloEmpty ?
function BunkerSiloManager:isSiloEmpty()
	return self:getTotalFillLevel() <= 0 
end

---Gets the total fillLevel of the silo
---@return float totalFillLevel ?
function BunkerSiloManager:getTotalFillLevel()
	local totalFillLevel = 0
	local numLines,numColumns = self:getNumberOfLinesAndColumns()
	for line = 1, numLines do
		for column = 1, numColumns do
			totalFillLevel = totalFillLevel + self:getSiloPartFillLevel(line,column)
		end
	end
	self:debug("totalFillLevel: %.2f",totalFillLevel)
	return totalFillLevel
end


---Gets column with least fillLevel, without the column directly near the bunker walls
---@return int best column to fill
function BunkerSiloManager:getBestColumnToFill()
	local numLines,numColumns = self:getNumberOfLinesAndColumns()
	local leastFillLevel = math.huge
	local leastColumnIndex = 0
	for columnIndex=2,numColumns-1 do
		local fillLevel = self:getSiloPartColumnFillLevel(columnIndex)
		if fillLevel<leastFillLevel then
			leastFillLevel = fillLevel
			leastColumnIndex = columnIndex
		end
	end
	return leastColumnIndex
end

---set the waypoint cordinates for the correct column of the bunkerSiloMap
---@param course course of the driver
---@param int target column of the BunkerSiloMap
---@param int currentWaypointIx of the driver
---@return int return first waypointIndex to start offset course from
function BunkerSiloManager:setOffsetsPerWayPoint(course,bestColumn,ix)
	local numLines = self:getNumberOfLines()
	local points =	{}
	local foundFirst = 0
	for index=ix,course:getNumberOfWaypoints() do
		if BunkerSiloManagerUtil.getTargetBunkerSiloAtWaypoint(self.vehicle,course,index)~= nil then
			local closest,cx,cz = 0,0,0
			local leastDistance = math.huge
			for lineIndex=1,numLines do
				local x,z = self:getSiloPartPosition(lineIndex,bestColumn)
				local distance = course:getDistanceBetweenPointAndWaypoint(x,z, index)
				if leastDistance > distance then
					leastDistance = distance
					closest = lineIndex
					cx,cz = x,z
				end
			end
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
			course.waypoints[index].x = cx
			course.waypoints[index].z = cz
			--local offsetX,_,offsetZ = course:worldToWaypointLocal(index, cx, y, cz)
			points[index]= true
			--print(string.format("set %s new",tostring(index)))
			if foundFirst == 0 then
				foundFirst = index
			end
		elseif foundFirst ~= 0 then
			break
		end
	end

	return foundFirst
end

---Gets the closest bunker silo map line form a given column to a waypoint ix
---@param course course of the driver
---@param int waypoint ix to get the distance from
---@param int target column of the bunker silo map
---@return float dx,dy,dz closest silo map part position
function BunkerSiloManager:getClosestSiloPartPositionToWaypoint(course,ix,targetColumn)
	local closestLine,dx,dz = 0,0,0
	local leastDistance = math.huge
	for lineIndex=1,#self.siloMap do
		local x,z = self:getSiloPartPosition(lineIndex,targetColumn)
		local distance = course:getDistanceBetweenPointAndWaypoint(x,z, ix)
		if leastDistance > distance then
			leastDistance = distance
			closestLine = lineIndex
			dx,dz = x,z
		end
	end
	local dy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, dx, 1, dz);
	return dx,dy,dz
end


---have we reached the end ?
---@param siloMapPart bestTarget targeted part
---@return boolean end reached ?
function BunkerSiloManager:isAtEnd(bestTarget)
	local numLines = self:getNumberOfLines()
	if not self.siloMap or not bestTarget then 
		return false
	end
	local cx,cz = self:getSiloPartPosition(bestTarget.line,bestTarget.column)
	local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	local x,y,z = getWorldTranslation(self.targetNode)
	local distance2Target =  courseplay:distance(x,z, cx, cz) --distance from shovel to target
	if distance2Target < 1 then
		if bestTarget.line == numLines then
			return true
		end
	end
	return false
end

--- get the bestTarget, firstLine of the bestTarget work with
---@return bestTarget, firstLine of the bestTarget
function BunkerSiloManager:getBestTargetFillUnitFillUp()
	local line = self:getFirstSiloPartLineWithFillLevel()
	local column = self:getSiloPartColumnWithMostFillLevel(line)
	local bestTarget = {
		line = line,
		column = column
	}	
	return bestTarget, line
end


--- Are we near the end ?
---@param siloMapPart bestTarget targeted part
---@return boolean are we close to the end ?
function BunkerSiloManager:isNearEnd(bestTarget)
	return bestTarget.line >= #self.siloMap-1
end

--- updating the current silo target part
---@param siloMapPart bestTarget targeted part
function BunkerSiloManager:updateTarget(bestTarget)
	local numLines = self:getNumberOfLines()
	local cx,cz = self:getSiloPartPosition(bestTarget.line,bestTarget.column)
	local cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
	local x,y,z = getWorldTranslation(self.targetNode)
	local distance2Target =  courseplay:distance(x,z, cx, cz) --distance from shovel to target
	if math.abs(distance2Target) < 1 then
		bestTarget.line = math.min(bestTarget.line + 1, numLines)
	end		
end

---drawing the routing of the driver 
---@param table bestTarget targeted part
---@param table for driving out of the silo
---@param float target shield height of mode 10 driver
function BunkerSiloManager:debugRouting(bestTarget,tempTarget,targetHeight)
	if self.siloMap ~= nil and bestTarget ~= nil then

		local sx,sz,wx,wz,hx,hz = self:getSiloPartStartWidthHeightPositions(bestTarget.line,bestTarget.column)
		local bx,bz = self:getSiloPartCenterPosition(bestTarget.line,bestTarget.column)
		local cx,cz = self:getSiloPartPosition(bestTarget.line,bestTarget.column)
		local whx,whz = hx +(wx-sx) ,hz +(wz-sz)
		local _,tractorHeight,_ = getWorldTranslation(self.vehicle.cp.directionNode)
		local y = tractorHeight + 1.5;

		cpDebug:drawLine(sx, y, sz, 1, 0, 0, wx, y, wz);
		cpDebug:drawLine(wx, y, wz, 1, 0, 0, whx, y, whz);
		cpDebug:drawLine(hx, y, hz, 1, 0, 0, sx, y, sz);
		cpDebug:drawLine(cx, y, cz, 1, 0, 1, bx, y, bz);
		cpDebug:drawPoint(cx, y, cz, 1, 1 , 1);

		local bunker = self.silo
		if bunker ~= nil then
			local sx,sz = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local wx,wz = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local hx,hz = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			cpDebug:drawLine(sx,y+2,sz, 0, 0, 1, wx,y+2,wz);
			--drawDebugLine(sx,y+2,sz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
			--drawDebugLine(wx,y+2,wz, 0, 0, 1, hx,y+2,hz, 0, 1, 0);
			cpDebug:drawLine(sx,y+2,sz, 0, 0, 1, hx,y+2,hz);
			cpDebug:drawLine(wx,y+2,wz, 0, 0, 1, hx,y+2,hz);
		end
		if tempTarget ~= nil then
			local tx,tz = tempTarget.cx,tempTarget.cz
			cpDebug:drawLine(tx, y, tz, 1, 0, 1, sx, y, sz);
			cpDebug:drawPoint(tx, y, tz, 1, 1 , 1);
		end
		if targetHeight then 
			local numLines = self:getNumberOfLines()
			local x,z = self:getSiloPartCenterPosition(1,bestTarget.column)
			local nx,nz = self:getSiloPartCenterPosition(numLines,bestTarget.column)
			local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x,1,z)
			local height = terrainHeight + targetHeight
			cpDebug:drawLine(x, height, z, 1, 1, 1, nx, height, nz);
		end
	end
end

---drawing the bunkerSiloMap 
function BunkerSiloManager:drawMap()
	function drawTile(f, r, g, b)
		cpDebug:drawLine(f.sx, f.y + 1, f.sz, r, g, b, f.wx, f.y + 1, f.wz)
		cpDebug:drawLine(f.wx, f.y + 1, f.wz, r, g, b, f.hx, f.y + 1, f.hz)
		cpDebug:drawLine(f.hx, f.y + 1, f.hz, r, g, b, f.sx, f.y + 1, f.sz);
		cpDebug:drawLine(f.cx, f.y + 1, f.cz, 1, 1, 1, f.bx, f.y + 1, f.bz);
	end

	if not self.siloMap then return end
	for _, line in pairs(self.siloMap) do
		for _, fillUnit in pairs(line) do
			drawTile(fillUnit, 1/1 - fillUnit.fillLevel, 1, 0)
		end
	end
	if not self.silo then return end
	if self.silo.bunkerSiloArea.start then 
		DebugUtil.drawDebugNode(self.silo.bunkerSiloArea.start, 'startBunkerNode')
		DebugUtil.drawDebugNode(self.silo.bunkerSiloArea.width, 'widthBunkerNode')
		DebugUtil.drawDebugNode(self.silo.bunkerSiloArea.height, 'heightBunkerNode')
	else --for heaps where we have no bunker nodes (start/width/height)
		cpDebug:drawPoint(self.silo.bunkerSiloArea.sx, 1, self.silo.bunkerSiloArea.sz, 1, 1, 1)
		cpDebug:drawPoint(self.silo.bunkerSiloArea.wx, 1, self.silo.bunkerSiloArea.wz, 1, 1, 1)
		cpDebug:drawPoint(self.silo.bunkerSiloArea.hx, 1, self.silo.bunkerSiloArea.hz, 1, 1, 1)
	end
end

---Vehicle debug function
function BunkerSiloManager:debug(...)
	courseplay.debugVehicle(self.debugChannel, self.vehicle, ...)
end

BunkerSiloManagerUtil = {}
BunkerSiloManagerUtil.debugChannel = 10

---Vehicle debug function
---@param vehicle
function BunkerSiloManagerUtil.debug(vehicle,...)
	courseplay.debugVehicle(BunkerSiloManagerUtil.debugChannel, vehicle, ...)
end

---Checks for bunkerSilos between two points
---@param vehicle vehicle of the driver
---@param int x,z fist point
---@param int tx,tz second point
---return BunkerSilo  
function BunkerSiloManagerUtil.getBunkerSilo(vehicle,x,z,tx,tz)
	if g_currentMission.bunkerSilos ~= nil then
		for _, bunker in pairs(g_currentMission.bunkerSilos) do
			local x1,z1 = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local x2,z2 = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local x3,z3 = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			if MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z) then
				BunkerSiloManagerUtil.debug(vehicle,"Silo was found: %s",nameNum(bunker))
				return bunker
			end
		end
	end
end

---Checks for heaps between two points
---@param vehicle vehicle of the driver
---@param int x,z first point
---@param int nx,nz second point
---return targetSilo a simulated bunkerSilo version of the heap
function BunkerSiloManagerUtil.getHeapCoords(vehicle,x,z,nx,nz)
	local p1x,p1z,p2x,p2z,p1y,p2y = x,z,nx,nz,0,0
	p1y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p1x, 1, p1z);
	p2y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p2x, 1, p2z);
	local heapFillType = DensityMapHeightUtil.getFillTypeAtLine(p1x, p1y, p1z, p2x, p2y, p2z, 5)
	if heapFillType == nil or heapFillType == FillType.UNKNOWN then 
		return 
	end
	
	--create temp node 
	local point = createTransformGroup("cpTempHeapFindingPoint");
	link(g_currentMission.terrainRootNode, point);

	-- Rotate it in the right direction
	local dx,_,dz, distance = courseplay:getWorldDirection(p1x,p1y,p1z,p2x,p2y,p2z);
	
	setTranslation(point,p1x,p1y,p1z);
	local yRot = MathUtil.getYRotationFromDirection(dx, dz);
	setRotation(point, 0, yRot, 0);

	-- move the line to find out the size of the heap
	
	--find maxX 
	local stepSize = 0.1
	local searchWidth = 0.1
	local maxX = 0
	local tempStartX, tempStartZ,tempHeightX,tempHeightZ = 0,0,0,0;
	for i=stepSize,250,stepSize do
		tempStartX,tempStartY,tempStartZ = localToWorld(point,i,0,0)
		tempHeightX,tempHeightY,tempHeightZ= localToWorld(point,i,0,distance*2)
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
		--print(string.format("fillType:%s distance: %.1f",tostring(fillType),i))	
		if fillType ~= heapFillType then
			maxX = i-stepSize
			BunkerSiloManagerUtil.debug(vehicle,"maxX = %.2f",maxX)
			break
		end
	end
	
	--find minX 
	local minX = 0
	local tempStartX, tempStartZ,tempHeightX,tempHeightZ = 0,0,0,0;
	for i=stepSize,250,stepSize do
		tempStartX,tempStartY,tempStartZ = localToWorld(point,-i,0,0)
		tempHeightX,tempHeightY,tempHeightZ= localToWorld(point,-i,0,distance*2)
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX,tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
		--print(string.format("fillType:%s distance: %.1f",tostring(fillType),i))	
		if fillType ~= heapFillType then
			minX = i-stepSize
			BunkerSiloManagerUtil.debug(vehicle,"minX = %.2f",minX)
			break
		end
	end
	
	--find minZ and maxZ
	local foundHeap = false
	local minZ, maxZ = 0,0
	for i=0,250,stepSize do
		tempStartX,tempStartY,tempStartZ = localToWorld(point,maxX,0,i)
		tempHeightX,tempHeightY,tempHeightZ= localToWorld(point,-minX,0,i)
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
		if not foundHeap then
			if fillType == heapFillType then
				foundHeap = true
				minZ = i-stepSize
				BunkerSiloManagerUtil.debug(vehicle,"minZ = %.2f",minZ)
			end
		else
			if fillType ~= heapFillType then
				maxZ = i-stepSize+1
				BunkerSiloManagerUtil.debug(vehicle,"maxZ = %.2f",maxZ)
				break
			end
		end	
	end
	
	--set found values into bunker table and return it
	local bunker = {}
	bunker.bunkerSiloArea = {}
	bunker.bunkerSiloArea.sx,_,bunker.bunkerSiloArea.sz = localToWorld(point,maxX,0,minZ);
	bunker.bunkerSiloArea.wx,_,bunker.bunkerSiloArea.wz = localToWorld(point,-minX,0,minZ)
	bunker.bunkerSiloArea.hx,_,bunker.bunkerSiloArea.hz = localToWorld(point,maxX,0,maxZ)
	local sx,sz = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
	local wx,wz = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
	local hx,hz = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz

	local fillLevel = DensityMapHeightUtil.getFillLevelAtArea(heapFillType, sx, sz, wx, wz, hx, hz)
	BunkerSiloManagerUtil.debug(vehicle,"Heap found with %s(%d) and fillLevel: %.2f",g_fillTypeManager:getFillTypeByIndex(heapFillType).title,heapFillType,fillLevel)

	-- Clean up the temporary node.
	unlink(point);
	delete(point);

	return bunker
end

---Checks if there is a bunker silo in between two waypoints,
---if a bunker was found the return it
---@param vehicle vehicle of the driver
---@param table course of the driver
---@param int first waypoint ix
---@param int last waypoint ix
---@param boolean looking for heaps allowed ?
---@return table bunker silo or simulated heap silo
---@return boolean was a heap found ?
function BunkerSiloManagerUtil.getTargetBunkerSiloBetweenWaypoints(vehicle,course,firstWpIx,lastWpIx,checkForHeapsActive)
	local x,_,z = course:getWaypointPosition(firstWpIx)
	local nx,_,nz = course:getWaypointPosition(lastWpIx)

	local silo = BunkerSiloManagerUtil.getBunkerSilo(vehicle,x,z,nx,nz)
	if silo then 
		return silo
	end
	--it's not a bunkersSilo, try to find a heap if it is allowed
	if checkForHeapsActive then
		return BunkerSiloManagerUtil.getHeapCoords(vehicle,x,z,nx,nz),true
	end
end

---Checks if the waypoint is in a bunker silo, 
---if a bunker was found the return it
---@param vehicle vehicle of the driver
---@param table course of the driver
---@param int waypoint ix to look for a silo
---@return table bunker silo 
function BunkerSiloManagerUtil.getTargetBunkerSiloAtWaypoint(vehicle,course,wpIx)
	local x,_,z = course:getWaypointPosition(wpIx)
	local nx,nz = x,z + 0.50
	return BunkerSiloManagerUtil.getBunkerSilo(vehicle,x,z,nx,nz)
end

---Gets the first waypoint in the silo and the last waypoint
---@param vehicle vehicle of the driver
---@param course course of the driver
---@param int first waypoint to start checking from
---@return int first waypointIx in silo
---@return int last waypointIx in silo
function BunkerSiloManagerUtil.getFirstAndLastWaypointIxInSilo(vehicle,course,startIx)
	local firstIx, lastIx
	for ix=startIx,course:getNumberOfWaypoints() do 
		local x,_,z = course:getWaypointPosition(ix)
		local nextIx = math.min(ix,course:getNumberOfWaypoints())
		local nx,_,nz = course:getWaypointPosition(nextIx)
		if BunkerSiloManagerUtil.getBunkerSilo(vehicle,x,z,nx,nz) then 
			if not firstIx then 
				firstIx = ix
			end
			lastIx = ix
		elseif foundFirst then 
			break
		end
	end
	return firstIx,lastIx
end
