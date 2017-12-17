function CpManager:setUpDebugChannels()
	print('## Courseplay: setting up debug channels');

	-- DEVELOPERS DEFAULT ACTIVE CHANNELS - ONLY WORKS FOR DEVELOPERS.
	local defaultActive = {};
	if CpManager.isDeveloper then
		-- Enable specified debugmode by default for Satis Only!
		if getMD5(g_gameSettings:getValue("nickname")) == "9a9f028043394ff9de1cf6c905b515c1" then
			--defaultActive[12] = true;
			--defaultActive[14] = true;
		end;
		if getMD5(g_gameSettings:getValue("nickname")) == "b74ad095badc54d4334039f2f73f240e" then
			defaultActive[6] = true;
			defaultActive[12] = true;
			defaultActive[14] = true;
		end;
		if getMD5(g_gameSettings:getValue("nickname")) == "3e701b6620453edcd4c170543e72788b" then
			defaultActive[12] = true;
			defaultActive[14] = true;
			defaultActive[4] = true;
			defaultActive[7] = true;
			defaultActive[9] = true;
			defaultActive[6] = true;
		end;
	end;

	-- DEBUG CHANNELS
	courseplay.numAvailableDebugChannels = 24;
	courseplay.numDebugChannels = 23;
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
		 [4] = 'Debug: Combines/mode2, register and unload combines';
		 [5] = 'Debug: Multiplayer';
		 [6] = 'Debug: implements (updateWorkTools etc.)';
		 [7] = 'Debug: course generation';
		 [8] = 'Debug: course management';
		 [9] = 'Debug: path finding';
		[10] = 'Debug: mode9: shovel loading/unloading';
		[11] = 'Debug: Combine self-unloading and heaps';
		[12] = 'Debug: all other debugs (uncategorized)';
		[13] = 'Debug: reverse driving';
		[14] = 'Debug: driving specific';
		[15] = 'Debug: mode3: overloader';
		[16] = 'Debug: recording courses';
		[17] = 'Debug: mode4/6: seeding/fieldWork';
		[18] = 'Debug: hud action';
		[19] = 'Debug: special triggers';
		[20] = 'Debug: WeightStation';
		[21] = 'Debug: Speed setting';
		[22] = 'Debug: temp MP';
		[23] = 'Debug: mode8: liquid product transport';
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
	if channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == true then
		local timestamp = getDate( "%H:%M:%S")
    	local seconds = courseplay.clock / 1000
		print('[dbg' .. tostring(channel) .. ' lp' .. g_updateLoopIndex .. ' ' .. timestamp .. '] ' .. str);
	end;
end;

-- convenience debug function to show the vehicle name and expects string.format() arguments, 
-- courseplay.debugVehicle( 14, vehicle, "fill level is %.1f, mode = %d", fillLevel, mode )
function courseplay.debugVehicle( channel, vehicle, ... )
	if channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == true then
		local seconds = courseplay.clock / 1000
		local timestamp = getDate( "%H:%M:%S")
		local vehicleName = vehicle and nameNum( vehicle ) or "Unknown vehicle"		
		print( string.format( '[dbg%d lp%d %s] %s: ', 
			tostring( channel ), g_updateLoopIndex, timestamp,vehicleName ) .. string.format( ... ))
	end
end

-- add a debug marker to the log file when Left Alt-D is pressed. This is to mark 
-- issues in the log file so developers can find relevant log entries easier.
function courseplay.logDebugMarker()
	local timestamp = getDate( "%H:%M:%S")
	print( string.format( '[dbg lp%d %s] Debug Marker %s', g_updateLoopIndex, timestamp, 
		g_careerScreen.savegames[g_careerScreen.selectedIndex].mapId ))
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
	if channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == false then
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
			local info = debug.getinfo(o, 'S')
			-- info.name is nil because o is not a calling level
			if info.what == 'C' then
				return ('"%s, C function"'):format(so);
			else
				-- the information is defined in a script
				return ('"%s, defined in %s (lines %d-%d)"'):format(so, info.source, info.linedefined, info.lastlinedefined);
			end
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
