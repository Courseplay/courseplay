function CpManager:setUpDebugChannels()
	print('## Courseplay: setting up debug channels');

	-- DEVELOPERS DEFAULT ACTIVE CHANNELS - ONLY WORKS FOR DEVELOPERS.
	local defaultActive = {};
	if CpManager.isDeveloper then
		-- Enable specified debugmode by default for Satis Only!
		if getMD5(g_gameSettings:getValue("nickname")) == "9a9f028043394ff9de1cf6c905b515c1" then
			defaultActive[6] = true;
			defaultActive[12] = true;
			defaultActive[13] = true;
			defaultActive[14] = true;
		end;
		if getMD5(g_gameSettings:getValue("nickname")) == "b74ad095badc54d4334039f2f73f240e" then
			defaultActive[6] = true;
			defaultActive[13] = true;
		end;
		if getMD5(g_gameSettings:getValue("nickname")) == "3e701b6620453edcd4c170543e72788b" then
			defaultActive[11] = true;
			defaultActive[12] = true;
			defaultActive[13] = true;
			defaultActive[14] = true;
			defaultActive[6] = true;
			defaultActive[7] = true;
			defaultActive[8] = true;
			defaultActive[9] = true;
			defaultActive[4] = true;
			defaultActive[3] = true;
		end;
	end;

	-- DEBUG CHANNELS
	courseplay.numAvailableDebugChannels = 24;
	courseplay.numDebugChannels = 24;
	courseplay.numDebugChannelButtonsPerLine = 12;
	courseplay.numDebugChannelSections = math.ceil(courseplay.numAvailableDebugChannels / courseplay.numDebugChannelButtonsPerLine);
	courseplay.debugChannelSection = 1;
	courseplay.debugChannelSectionStart = 1;
	courseplay.debugChannelSectionEnd = courseplay.numDebugChannelButtonsPerLine;
	courseplay.debugChannels = {};
	for channel=1, courseplay.numAvailableDebugChannels do
		courseplay.debugChannels[channel] = defaultActive[channel] or false;
	end;

	-- Debug channels legend:
	courseplay.debugChannelsDesc = {
		[1] = 'Debug: Raycast (drive + tipTriggers)';
		[2] = 'Debug: Load and unload tippers';
		[3] = 'Debug: Traffic collision';
		[4] = 'Debug: Mode 2/3, combi/overloader';
		[5] = 'Debug: Multiplayer';
		[6] = 'Debug: implements (updateWorkTools etc.)';
		[7] = 'Debug: course generation';
		[8] = 'Debug: course management';
		[9] = 'Debug: path finding';
		[10] = 'Debug: mode9: shovel loading/unloading';
		[11] = 'Debug: AIDriver management';
		[12] = 'Debug: all other debugs (uncategorized)';
		[13] = 'Debug: reverse driving';
		[14] = 'Debug: driving specific';
		[15] = 'Debug: not used';
		[16] = 'Debug: recording courses';
		[17] = 'Debug: mode4/6: seeding/fieldWork';
		[18] = 'Debug: hud action';
		[19] = 'Debug: special triggers';
		[20] = 'Debug: WeightStation';
		[21] = 'Debug: Speed setting';
		[22] = 'Debug: temp MP';
		[23] = 'Debug: mode8: liquid product transport';
		[24] = 'Debug: activate cyclic prints'; --this is to prevent spamming the log if not nessesary (e.g. raycasts)
	};

	courseplay.debugButtonPosData = {};
	local dbgW = courseplay.hud:pxToNormal(22, 'x');
	local dbgH = courseplay.hud:pxToNormal(22, 'y');
	local dbgMarginX = dbgW * 0.075;
	local dbgMaxX = courseplay.hud.contentMaxX - (2 * (courseplay.hud.buttonSize.small.w + courseplay.hud.buttonSize.small.margin));
	local dbgMinX = dbgMaxX - (courseplay.numDebugChannelButtonsPerLine * dbgW) - ((courseplay.numDebugChannelButtonsPerLine - 1) * dbgMarginX);
	local dbgBtnPosY = courseplay.hud.linesPosY[8] - courseplay.hud:pxToNormal(5, 'y');
	for i = 1, courseplay.numDebugChannelButtonsPerLine do
		local data = {};
		data.width  = dbgW;
		data.height = dbgH;
		data.posX = dbgMinX + ((i - 1) * (dbgW + dbgMarginX));
		data.posY = dbgBtnPosY;
		data.textPosX = data.posX + (dbgW * 0.5);
		data.textPosY = courseplay.hud.linesPosY[8];

		courseplay.debugButtonPosData[i] = data;
	end;

end;

--------------------------------------------------

-- GENERAL DEBUG
function courseplay:debug(str, channel)
	if courseplay.debugChannels and channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == true then
		local timestamp = getDate( ":%S")
		print(timestamp .. ' [dbg' .. tostring(channel) .. ' lp' .. g_updateLoopIndex .. '] ' .. str);
	end;
end;

-- convenience debug function that expects string.format() arguments,
-- courseplay.debugVehicle( 14, "fill level is %.1f, mode = %d", fillLevel, mode )
---@param channel number
function courseplay.debugFormat(channel, ...)
	if courseplay.debugChannels and channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == true then
		local updateLoopIndex = g_updateLoopIndex and g_updateLoopIndex or 0
		local timestamp = getDate( ":%S")
		print(string.format('%s [dbg%d lp%d] %s', timestamp, channel, updateLoopIndex, string.format( ... )))
	end
end

-- convenience debug function to show the vehicle name and expects string.format() arguments, 
-- courseplay.debugVehicle( 14, vehicle, "fill level is %.1f, mode = %d", fillLevel, mode )
---@param channel number
function courseplay.debugVehicle(channel, vehicle, ...)
	if courseplay.debugChannels and channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == true then
		local vehicleName = vehicle and nameNum(vehicle) or "Unknown vehicle"
		local updateLoopIndex = g_updateLoopIndex and g_updateLoopIndex or 0
		local timestamp = getDate( ":%S")
		print(string.format('%s [dbg%d lp%d] %s: %s', timestamp, channel, updateLoopIndex, vehicleName, string.format( ... )))
	end
end

function courseplay.info(...)
	local updateLoopIndex = g_updateLoopIndex and g_updateLoopIndex or 0
	local timestamp = getDate( ":%S")
	print(string.format('%s [info lp%d] %s', timestamp, updateLoopIndex, string.format( ... )))
end

function courseplay.infoVehicle(vehicle, ...)
	local vehicleName = vehicle and nameNum(vehicle) or "Unknown vehicle"
	local updateLoopIndex = g_updateLoopIndex and g_updateLoopIndex or 0
	local timestamp = getDate( ":%S")
	print(string.format('%s [info lp%d] %s: %s', timestamp, updateLoopIndex, vehicleName, string.format( ... )))
end


local lines = {
	('-'):rep(50),
	('_'):rep(50),
	('#'):rep(50)
};
function cpPrintLine(debugChannel, line)
	if debugChannel == nil or courseplay.debugChannels[debugChannel] then
		line = line or 1;
		print(lines[line]);
	end;
end;

function tableShow(t, name, channel, indent, maxDepth)
	-- important performance backup: the channel is checked first before proceeding with the compilation of the table
	if channel ~= nil then --Tommi and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == false then
		return;
	end;


	local cart; -- a container
	local autoref; -- for self references
	maxDepth = maxDepth or 50;
	local depth = 0;

	-- (RiciLake) returns true if the table is empty
	local function isemptytable(t)
		return next(t) == nil;
	end;

	local function basicSerialize(o)
		local so = tostring(o);
		local oType = type(o);
		if oType == 'function' then
			return ("function...")
			--[[local info = debug.getinfo(o, 'S')
			-- info.name is nil because o is not a calling level
			if info.what == 'C' then
				return ('"%s, C function"'):format(so);
			else
				-- the information is defined in a script
				return ('"%s, defined in %s (lines %d-%d)"'):format(so, info.source, info.linedefined, info.lastlinedefined);
			end]]
		elseif oType == 'number' then
			return so;
		elseif oType == 'boolean' then
			return ('%s'):format(so);
		else
			return ('%q'):format(so);
		end;
	end;

	local function addToCart(value, name, indent, saved, field, curDepth)
		indent = indent or ''
		saved = saved or {}
		field = field or name
		-- cart = cart .. indent .. field
		cart = indent .. field
		-- print(('addToCart(value=%q, name=%q, indent, saved, field=%q, curDepth=%d)'):format(tostring(value), tostring(name), tostring(field), tostring(curDepth)));

		if type(value) ~= 'table' then
			cart = cart .. ' = ' .. basicSerialize(value) .. ';';
			print(cart);
		else
			if saved[value] then
				cart = cart .. ' = {}; -- ' .. saved[value] .. ' (self reference)';
				print(cart);
				autoref = autoref .. name .. ' = ' .. saved[value] .. ';\n';
			else
				saved[value] = name;
				if isemptytable(value) then
					cart = cart .. ' = {};';
					print(cart);
				else
					if curDepth <= maxDepth then
						cart = cart .. ' = {';
						print(cart);
						for k, v in pairs(value) do
							k = basicSerialize(k);
							local fname = string.format('%s[%s]', name, k);
							field = string.format('[%s]', k);
							-- three spaces between levels
							addToCart(v, fname, indent .. '\t', saved, field, curDepth + 1);
						end;
						cart = indent .. '};';
						print(cart);
					else
						cart = cart .. ' = { ... };';
						print(cart);
					end;
				end;
			end;
		end;
	end;

	name = name or '__unnamed__';
	if type(t) ~= 'table' then
		return name .. ' = ' .. basicSerialize(t);
	end;
	cart, autoref = '', '';
	addToCart(t, name, indent, nil, nil, depth + 1)
	-- return cart .. autoref
	print(autoref);
	return ('-- %s %s -END- %s --'):format(('#'):rep(40), name, ('#'):rep(40));
end;

function eval(str)
	return assert(loadstring(str))()
end

--------------------------------------------------

-- MULTIPLAYER DEBUG
courseplay.streamDebugCounter = 0;

courseplay.streamWriteFunctions = {
	Bool   = streamWriteBool;
	Float  = streamWriteFloat32;
	Int    = streamWriteInt32;
	String = streamWriteString;
};
courseplay.streamReadFunctions = {
	Bool   = streamReadBool;
	Float  = streamReadFloat32;
	Int    = streamReadInt32;
	String = streamReadString;
};
function courseplay.streamDebugWrite(streamId, varType, value, name)
	courseplay.streamDebugCounter = courseplay.streamDebugCounter + 1;
	stream_debug_counter = stream_debug_counter + 1
	if varType == 'Bool' then
		value = Utils.getNoNil(value, false);
		if value == 1 then
			value = true;
		elseif value == 0 then
			value = false;
		end;
		courseplay:debug(('%d: writing %s (bool): %s'):format(stream_debug_counter,name or "XX", tostring(value)), 5);
	elseif varType == 'Float' then
		value = value or 0.0;
		courseplay:debug(('%d: writing %s (float): %f'):format(stream_debug_counter,name or "XX", value), 5);
	elseif varType == 'Int' then
		value = value or 0.0;
		courseplay:debug(('%d: writing %s (int): %d'):format(stream_debug_counter,name or "XX", value), 5);
	elseif varType == 'String' then
		value = value or 'nil';
		courseplay:debug(('%d: writing %s  (string): %q'):format(stream_debug_counter,name or "XX", value), 5);
	end;

	courseplay.streamWriteFunctions[varType](streamId, value);
end;

function courseplay.streamDebugRead(streamId, varType)
	courseplay.streamDebugCounter = courseplay.streamDebugCounter + 1;
	stream_debug_counter = stream_debug_counter + 1
	local value = courseplay.streamReadFunctions[varType](streamId);
	if varType == 'Bool' then
		courseplay:debug(('%d: reading bool: %s'):format(stream_debug_counter, tostring(value)), 5);
	elseif varType == 'Float' then
		courseplay:debug(('%d: reading float: %s'):format(stream_debug_counter, tostring(value)), 5);
	elseif varType == 'Int' then
		courseplay:debug(('%d: reading int: %s'):format(stream_debug_counter, tostring(value)), 5);
	elseif varType == 'String' then
		courseplay:debug(('%d: reading string: %s'):format(stream_debug_counter, tostring(value)), 5);
	end;

	return value;
end;

stream_debug_counter = 0;
function streamDebugWriteFloat32(streamId, value)
	value = Utils.getNoNil(value, 0.0)
	stream_debug_counter = stream_debug_counter + 1
	courseplay:debug(string.format("%d: writing float: %f",stream_debug_counter, value ),5)
	streamWriteFloat32(streamId, value)
end

function streamDebugWriteBool(streamId, value)
	value = Utils.getNoNil(value, false)
	if value == 1 then
		value = true
	elseif value == 0 then
		value = false
	end

	stream_debug_counter = stream_debug_counter + 1
	courseplay:debug(string.format("%d: writing bool: %s",stream_debug_counter, tostring(value) ),5)
	streamWriteBool(streamId, value)
end

function streamDebugWriteInt32(streamId, value)
	value = Utils.getNoNil(value, 0)
	stream_debug_counter = stream_debug_counter + 1
	courseplay:debug(string.format("%d: writing int: %d",stream_debug_counter, value ),5)
	streamWriteInt32(streamId, value)
end

function streamDebugWriteString(streamId, value)
	value = Utils.getNoNil(value, "")
	stream_debug_counter = stream_debug_counter + 1
	courseplay:debug(string.format("%d: writing string: %s",stream_debug_counter, value ),5)
	streamWriteString(streamId, value)
end


function streamDebugReadFloat32(streamId)
	stream_debug_counter = stream_debug_counter + 1
	local value = streamReadFloat32(streamId)
	courseplay:debug(string.format("%d: reading float: %f",stream_debug_counter, value ),5)
	return value
end


function streamDebugReadInt32(streamId)
	stream_debug_counter = stream_debug_counter + 1
	local value = streamReadInt32(streamId)
	courseplay:debug(string.format("%d: reading int: %d",stream_debug_counter, value ),5)
	return value
end

function streamDebugReadBool(streamId)
	stream_debug_counter = stream_debug_counter + 1
	local value = streamReadBool(streamId)
	courseplay:debug(string.format("%d: reading bool: %s",stream_debug_counter, tostring(value)),5)
	return value
end

function streamDebugReadString(streamId)
	stream_debug_counter = stream_debug_counter + 1
	local value = streamReadString(streamId)
	courseplay:debug(string.format("%d: reading string: %s",stream_debug_counter, value ),5)
	return value
end


--e.g. courseplay:findInTables(g_currentMission ,"g_currentMission", otherId)
function courseplay:findInTables(tableToSearchIn , tableToSearchString, valueToSearch)

	if courseplay.lastSearchedValue == nil then
		courseplay.lastSearchedValue = "empty"
	end
	if courseplay.lastSearchedValue == valueToSearch then --prevent loops in searching
		return
	else
		print("courseplay:findInTables -> searching "..type(valueToSearch).." "..tostring(valueToSearch).." in "..tableToSearchString)
		--courseplay.lastSearchedValue = valueToSearch
	end

	if type(tableToSearchIn) == "table" then
		--Level 0
		for index, value in pairs(tableToSearchIn) do
			if courseplay:findInMatchingValues(index,value,valueToSearch)  then
				print(string.format("courseplay:findInTables -> %s.%s = %s",tableToSearchString,tostring(index),tostring(value)))
			elseif type(value) == "table" then
				local table1 = tableToSearchIn[index]
				for index1, value1 in pairs(table1) do
					if courseplay:findInMatchingValues(index1,value1,valueToSearch) then
						print(string.format("courseplay:findInTables -> %s.%s.%s = %s",tableToSearchString,tostring(index),tostring(index1),tostring(value1)))
					elseif type(value1) == "table" then
						local table2 = table1[index1]
						for index2, value2 in pairs(table2) do
							if courseplay:findInMatchingValues(index2,value2,valueToSearch) then
								print(string.format("courseplay:findInTables -> %s.%s.%s.%s = %s",tableToSearchString,tostring(index),tostring(index1),tostring(index2),tostring(value2)))
							elseif type(value2) == "table" then
								local table3 = table2[index2]
								for index3, value3 in pairs(table3) do
									if courseplay:findInMatchingValues(index3,value3 ,valueToSearch) then
										print(string.format("courseplay:findInTables -> %s.%s.%s.%s.%s = %s",tableToSearchString,tostring(index),tostring(index1),tostring(index2),tostring(index3),tostring(value3)))
									elseif type(value3) == "table" then
										local table4 = table3[index3]
										for index4, value4 in pairs(table3) do
											if courseplay:findInMatchingValues(index4,value4,valueToSearch) then
												print(string.format("courseplay:findInTables -> %s.%s.%s.%s.%s.%s = %s",tableToSearchString,tostring(index),tostring(index1),tostring(index2),tostring(index3),tostring(index4),tostring(value4)))
											elseif type(value4) == "table" then
												local table5 = table4[index4]
												for index5, value5 in pairs(table4) do
													if courseplay:findInMatchingValues(index5,value5,valueToSearch) then
														print(string.format("courseplay:findInTables -> %s.%s.%s.%s.%s.%s.%s = %s",tableToSearchString,tostring(index),tostring(index1),tostring(index2),tostring(index3),tostring(index4),tostring(index5),tostring(value5)))
													elseif type(value4) == "table" then
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	else
		print("courseplay:findInTables -> "..tableToSearchString.." is not a table")
		return
	end
	print("courseplay:findInTables -> searching finished")
end
function courseplay:findInMatchingValues(index, value1, value2)
	local type1 = type(value1)
	local type2 = type(value2)
	--print("checking "..type1..tostring(value1).."vs "..type2.." "..tostring(value2))
	if type1 == type2 and value1 == value2 then
		return true
	end
	if type2 == "string" then
		if tostring(index) == value2 then
			return true
		end
	end
	return false
end

--- Ugly hack until we figure out why there's no global debug available in FS19
debug = {}
function debug.traceback()
	return 'debug.traceback() not implemented'
end

function debug.getinfo()
	local result = {}
	result.name = 'debug.getinfo() not implemented'
	result.currentline = 0
	return result
end

-- TODO: there could be a drawTemporaryLine in cpDebug that already has a buffer for all draw data, there's no need to
-- create a separate one
function courseplay:showTemporaryMarkers(vehicle)
	if not courseplay.debugChannels[14] then return end
	if vehicle.cp.showMarkers then
		if vehicle.cp.showMarkers.timer < vehicle.timer then
			-- time is up, remove markers
			vehicle.cp.showMarkers = nil
		else
			cpDebug:drawLine(vehicle.cp.showMarkers.x1, vehicle.cp.showMarkers.y + 1, vehicle.cp.showMarkers.z1, 0.5, 0, 0.5,
				vehicle.cp.showMarkers.x2, vehicle.cp.showMarkers.y + 1, vehicle.cp.showMarkers.z2);
		end
	end
end

--- start showing a temporary marker line
function courseplay:addTemporaryMarker(vehicle, node)
	vehicle.cp.showMarkers = {}
	vehicle.cp.showMarkers.timer = vehicle.timer + 25000
	vehicle.cp.showMarkers.x1, _, vehicle.cp.showMarkers.z1 = localToWorld(node, -1, 0, 0)
	vehicle.cp.showMarkers.x2, _, vehicle.cp.showMarkers.z2 = localToWorld(node, 1, 0, 0)
	vehicle.cp.showMarkers.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, vehicle.cp.showMarkers.x1, 0, vehicle.cp.showMarkers.z1 );
end

function courseplay:showAIMarkers(vehicle)

end

--------------------------------------------------
--- Courseplay Debug Class
--------------------------------------------------
cpDebug = {};
local cpDebug_mt = Class(cpDebug);
addModEventListener(cpDebug);
local modDirectory = g_currentModDirectory;

local colorDelta = 1/255; -- Used to convert RGB color code into 0-1 float color code

--- Define debug draw types
local drawTypes = {
	Point = "Sphere", -- Reference to img/debug/Sphere.i3d
	Line  = "Line"    -- Reference to img/debug/Line.i3d
}

--- setup debug items
function cpDebug:setup()
	--- Get the main rootNode
	local globalRootNode = getRootNode();

	--- Preset variables
	self.activeDrawData			= {};	-- Holds the active visible drawItems
	self.drawBuffer 			= {};   -- Holds drawItems for later use
	self.drawBufferMax 			= 50;	-- Max size of the buffer for each draw type
	self.drawPrototypes 		= {};	-- Holds a object prototype of each draw type
	self.itemsToDraw	 		= {};	-- Holds a list of items to draw in the next draw update
	self.nextUpdateLoopIndex 	= 0;	-- This is when last update was done
	self.oldDrawData		= {};   -- Holds the left over drawItems that needs to be put in the buffer.

	--- Setup drawTypes as prototypes to be cloned from when needed
	for drawType, i3dFile in pairs(drawTypes) do
		self.activeDrawData[drawType]	= {};	-- Define the draw type in the activeDrawData table
		self.drawBuffer[drawType]		= {};	-- Define the draw type in the drawBuffer table
		self.oldDrawData[drawType]	= {};	-- Define the draw type in the oldDrawData table

		-- Load the i3d file for the draw type and set it's default settings.
		local i3dNode =  g_i3DManager:loadSharedI3DFile( 'img/debug/' .. i3dFile .. '.i3d' , modDirectory);
		local itemNode = getChildAt(i3dNode, 0);
		link(globalRootNode, itemNode);
		setRigidBodyType(itemNode, 'NoRigidBody');
		setTranslation(itemNode, 0, 0, 0);
		setVisibility(itemNode, false);
		delete(i3dNode);

		-- Store the draw type node as a prototype for later use
		self.drawPrototypes[drawType] = itemNode;
	end;
end;

--- setup debug items on map load
function cpDebug:loadMap(name)
	self:setup();
end

--- Cleanup on exit map
function cpDebug:deleteMap()
	--- Delete activeDrawData itemNodes
	if self.activeDrawData then
		for drawType,drawDatas in pairs(self.activeDrawData) do
			for _,drawData in pairs(drawDatas) do
				self:deleteDrawItem(drawData.itemNode);
			end;
			self.drawBuffer[drawType] = {};
		end;
	end
	--- Delete drawBuffer itemNodes
	if self.drawBuffer then
		for drawType,drawDatas in pairs(self.drawBuffer) do
			for _,drawData in pairs(drawDatas) do
				self:deleteDrawItem(drawData.itemNode);
			end;
			self.drawBuffer[drawType] = {};
		end;
	end
	--- Deleting oldDrawData itemNodes is not needed since it's set and reset on each draw

	--- Delete draw prototypes itemNodes
	if self.drawPrototypes then
		for _,itemNode in pairs(self.drawPrototypes) do
			self:deleteDrawItem(itemNode);
		end;
	end
end;

function cpDebug:update(dt) end; -- TODO: might not be used at all, so we can delete it when sure

--- Draw debug items if there is any to show
function cpDebug:draw()
	if g_currentMission.paused then
		return;
	end;

	--- Clean active drawData
	for drawType,_ in pairs(drawTypes) do
		if #self.activeDrawData[drawType] > 0 then
			self.oldDrawData[drawType] = self.activeDrawData[drawType];
			self.activeDrawData[drawType] = {};
		end
	end

	--- Draw requested items
	for _, drawInfo in ipairs(self.itemsToDraw) do
		-- Get draw data from draw info
		local drawData = self:getDrawData(drawInfo);

		-- Continue if we have drawData
		if drawData then
			if drawData.drawType == "Point" then
				-- Update position and color of point
				self:updatePointDrawData(drawData);
			elseif drawData.drawType == "Line" then
				-- Update position, direction, length and color of line
				self:updateLineDrawData(drawData);
			end;

			-- Store the drawData so we can access them later
			table.insert(self.activeDrawData[drawData.drawType], drawData);
		end
	end
	--- Clear items to draw so it's ready for next update
	self.itemsToDraw = {};

	--- Cleanup leftover drawData
	self:storeInBuffer();

	--- set next loop to run so we don't double draw
	self.nextUpdateLoopIndex = g_updateLoopIndex + 1;

	--for drawType,_ in pairs(drawTypes) do
	--	print("numDrawBuffer[\""..drawType.."\"] = " .. tostring(#self.drawBuffer[drawType]));
	--end

end;

--- Get draw data based on info
-- @param	drawInfo	(table)	Contains info to generate drawData
-- @return	nil if drawType do not excist in prototypes
-- @return	active drawData table
function cpDebug:getDrawData(drawInfo)
	--- Make sure the draw type excist and if not then return nothing.
	if not self.drawPrototypes[drawInfo.drawType] then
		return;
	end

	local drawData = {};

	--- Pull drawData from an excisting active drawdata if there is one to use
	if #self.oldDrawData[drawInfo.drawType] > 0 then
		-- Pull drawData from active list. No need to set visibility here since they are already visible!
		drawData = table.remove(self.oldDrawData[drawInfo.drawType]);

		--- Pull drawData from drawBuffer if there is one to use
	elseif #self.drawBuffer[drawInfo.drawType] > 0 then
		-- Pull buffer drawData
		drawData = table.remove(self.drawBuffer[drawInfo.drawType]);
		-- Show the object
		setVisibility(drawData.itemNode, true);

		--- Create a new itemNode from the prototype if none of the above was valid
	else
		-- Clone prototype to get new object
		drawData.itemNode = clone(self.drawPrototypes[drawInfo.drawType], true);
		-- Set the draw type
		drawData.drawType = drawInfo.drawType;
		-- Show the object
		setVisibility(drawData.itemNode, true);
	end

	--- Define new color
	drawData.r = drawInfo.r;
	drawData.g = drawInfo.g;
	drawData.b = drawInfo.b;

	--- Set new position based on drawType
	if drawInfo.drawType == "Point" then
		-- Set draw data for a point
		drawData.posX		= drawInfo.posX
		drawData.posY		= drawInfo.posY
		drawData.posZ		= drawInfo.posZ
	elseif drawInfo.drawType == "Line" then
		-- Set draw data for a line
		drawData.posX1		= drawInfo.posX1
		drawData.posY1		= drawInfo.posY1
		drawData.posZ1		= drawInfo.posZ1
		drawData.posX2		= drawInfo.posX2
		drawData.posY2		= drawInfo.posY2
		drawData.posZ2		= drawInfo.posZ2
	end

	return drawData;
end

--- Update color of object
function cpDebug:updateObjectColor(drawData)
	setShaderParameter(drawData.itemNode, 'shapeColor', drawData.r, drawData.g, drawData.b, 1, false);
end

--- Update position and color of point
function cpDebug:updatePointDrawData(drawData)
	--- Update point position
	setTranslation(drawData.itemNode, drawData.posX, drawData.posY, drawData.posZ);
  --- Update scale
  if courseEditor.enabled then 
    setScale(drawData.itemNode, courseEditor.pointScale.x, courseEditor.pointScale.y, courseEditor.pointScale.z) 
  else
    setScale(drawData.itemNode, 2, 2, 2) 
  end
  --- Update point color
	self:updateObjectColor(drawData);
end

--- Update position, direction, length and color of line
function cpDebug:updateLineDrawData(drawData)
	--- Update line start position
	setTranslation(drawData.itemNode, drawData.posX1, drawData.posY1, drawData.posZ1);

	--- Get the direction to the end point
	local dirX, _, dirZ, distToNextPoint = courseplay:getWorldDirection(drawData.posX1, drawData.posY1, drawData.posZ1, drawData.posX2, drawData.posY2, drawData.posZ2);
	--- Get Y rotation
	local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ);
	--- Get X rotation
	local dy = drawData.posY2 - drawData.posY1;
	local dist2D = MathUtil.vector2Length(drawData.posX2 - drawData.posX1, drawData.posZ2 - drawData.posZ1);
	local rotX = -MathUtil.getYRotationFromDirection(dy, dist2D);

	--- Set the direction of the line
	setRotation(drawData.itemNode, rotX, rotY, 0);
	--- Set the length if the line
	setScale(drawData.itemNode, 1, 1, distToNextPoint);

	--- Update line color
	self:updateObjectColor(drawData);
end

--- Draw a line from point a to b with 0-1 float color
-- @param	posXa	(float)	From point x (world location)
-- @param	posYa	(float)	From point y (world location)
-- @param	posZa	(float)	From point z (world location)
-- @param	r		(float)	Line color Red
-- @param	g		(float)	Line color Green
-- @param	b		(float)	Line color Blue
-- @param	posXb	(float)	To point x (world location)
-- @param	posYb	(float)	To point y (world location)
-- @param	posZb	(float)	To point z (world location)
function cpDebug:drawLine(posXa, posYa, posZa, r, g, b, posXb, posYb, posZb)
	self:addDrawItem("Line", posXa, posYa, posZa, r, g, b, posXb, posYb, posZb);
end

--- Draw a line from point a to b with 0-255 RGB color code
-- @param	posXa	(float)		From point x (world location)
-- @param	posYa	(float)		From point y (world location)
-- @param	posZa	(float)		From point z (world location)
-- @param	r		(RGB color)	Line color Red
-- @param	g		(RGB color)	Line color Green
-- @param	b		(RGB color)	Line color Blue
-- @param	posXb	(float)		To point x (world location)
-- @param	posYb	(float)		To point y (world location)
-- @param	posZb	(float)		To point z (world location)
function cpDebug:drawLineRGB(posXa, posYa, posZa, r, g, b, posXb, posYb, posZb)
	self:addDrawItem("Line", posXa, posYa, posZa, colorDelta*r, colorDelta*g, colorDelta*b, posXb, posYb, posZb);
end

--- Draw a point with 0-1 float color
-- @param	posX	(float)	From point x (world location)
-- @param	posY	(float)	From point y (world location)
-- @param	posZ	(float)	From point z (world location)
-- @param	r		(float)	Point color Red
-- @param	g		(float)	Point color Green
-- @param	b		(float)	Point color Blue
function cpDebug:drawPoint(posX, posY, posZ, r, g, b)
	self:addDrawItem("Point", posX, posY, posZ, r, g, b);
end

--- Draw a point with 0-255 RGB color code
-- @param	posX	(float)		From point x (world location)
-- @param	posY	(float)		From point y (world location)
-- @param	posZ	(float)		From point z (world location)
-- @param	r		(RGB color)	Point color Red
-- @param	g		(RGB color)	Point color Green
-- @param	b		(RGB color)	Point color Blue
function cpDebug:drawPointRGB(posX, posY, posZ, r, g, b)
	self:addDrawItem("Point", posX, posY, posZ, colorDelta*r, colorDelta*g, colorDelta*b);
end

--- Add draw item to the next draw update
-- @param	drawType	(string)	From point x (world location)
-- @param	posX1		(float)		From point x (world location)
-- @param	posY1		(float)		From point y (world location)
-- @param	posZ1		(float)		From point z (world location)
-- @param	r			(float)		Object color Red
-- @param	g			(float)		Object color Green
-- @param	b			(float)		Object color Blue
-- @param	posX2		(float)		To point x (world location)
-- @param	posY2		(float)		To point y (world location)
-- @param	posZ2		(float)		To point z (world location)
function cpDebug:addDrawItem(drawType, posX1, posY1, posZ1, r, g, b, posX2, posY2, posZ2)
	--- If we are in a new update loop and we haven't drawn the previous once, clear the previous draws since we don't want to double draw
	if self.nextUpdateLoopIndex < g_updateLoopIndex then
		self.nextUpdateLoopIndex = g_updateLoopIndex;
		self.itemsToDraw = {};
	end

	local drawInfo = {};

	if drawType == "Point" then
		-- Set draw data for a point
		drawInfo.posX		= posX1
		drawInfo.posY		= posY1
		drawInfo.posZ		= posZ1
	elseif drawType == "Line" then
		-- Set draw data for a line
		drawInfo.posX1		= posX1
		drawInfo.posY1		= posY1
		drawInfo.posZ1		= posZ1
		drawInfo.posX2		= posX2
		drawInfo.posY2		= posY2
		drawInfo.posZ2		= posZ2
	else
		-- Skip adding an items if they are not defined
		return
	end

	drawInfo.drawType	= drawType
	drawInfo.r			= r
	drawInfo.g			= g
	drawInfo.b			= b

	--- Add drawData to itemsToDraw table to be drawn in the next draw update
	table.insert(self.itemsToDraw, drawInfo);
end

--- Store leftover draw data table into the buffer for later use
function cpDebug:storeInBuffer()
	--- Store leftovers in the buffer by drawType
	for drawType, drawDatas in pairs(self.oldDrawData) do
		for _, drawData in ipairs(drawDatas) do
			if #self.drawBuffer[drawType] < self.drawBufferMax then
				-- Hide the object
				setVisibility(drawData.itemNode, false);

				-- Store leftover items in the buffer
				table.insert(self.drawBuffer[drawType], drawData);
			else
				-- Delete leftover items since the buffer is full
				self:deleteDrawItem(drawData.itemNode);
			end
		end

		-- Clean the oldDrawData table of the drawType
		self.oldDrawData[drawType] = {};
	end
end;

--- Delete draw item
function cpDebug:deleteDrawItem(itemNode)
	setVisibility(itemNode, false);
	unlink(itemNode);
	delete(itemNode);
end
