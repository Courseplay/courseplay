function courseplay:debug(str, channel)
	if channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == true then
		print("[dbg" .. tostring(channel) .. "] " .. str);
	end;
end;

function tableShow(t, name, channel, indent, maxDepth)
	--important performance backup: the channel is checked first before proceeding with the compilation of the table
	if channel ~= nil and courseplay.debugChannels[channel] ~= nil and courseplay.debugChannels[channel] == false then
		return;
	end;


	local cart -- a container
	local autoref -- for self references
	maxDepth = maxDepth or 50;
	local depth = 0;

	--[[ counts the number of elements in a table
local function tablecount(t)
   local n = 0
   for _, _ in pairs(t) do n = n+1 end
   return n
end
]]
	-- (RiciLake) returns true if the table is empty
	local function isemptytable(t) return next(t) == nil end

	local function basicSerialize(o)
		local so = tostring(o)
		if type(o) == "function" then
			local info = debug.getinfo(o, "S")
			-- info.name is nil because o is not a calling level
			if info.what == "C" then
				return string.format("%q", so .. ", C function")
			else
				-- the information is defined through lines
				return string.format("%q", so .. ", defined in (" ..
						info.linedefined .. "-" .. info.lastlinedefined ..
						")" .. info.source)
			end
		elseif type(o) == "number" then
			return so
		else
			return string.format("%q", so)
		end
	end

	local function addtocart(value, name, indent, saved, field, curDepth)
		indent = indent or ""
		saved = saved or {}
		field = field or name
		cart = cart .. indent .. field

		if type(value) ~= "table" then
			cart = cart .. " = " .. basicSerialize(value) .. ";\n"
		else
			if saved[value] then
				cart = cart .. " = {}; -- " .. saved[value]
						.. " (self reference)\n"
				autoref = autoref .. name .. " = " .. saved[value] .. ";\n"
			else
				saved[value] = name
				--if tablecount(value) == 0 then
				if isemptytable(value) then
					cart = cart .. " = {};\n"
				else
					if curDepth <= maxDepth then
						cart = cart .. " = {\n"
						for k, v in pairs(value) do
							k = basicSerialize(k)
							local fname = string.format("%s[%s]", name, k)
							field = string.format("[%s]", k)
							-- three spaces between levels
							addtocart(v, fname, indent .. "\t", saved, field, curDepth + 1);
						end
						cart = cart .. indent .. "};\n"
					else
						cart = cart .. " = { ... };\n";
					end;
				end
			end
		end;
	end

	name = name or "__unnamed__"
	if type(t) ~= "table" then
		return name .. " = " .. basicSerialize(t)
	end
	cart, autoref = "", ""
	addtocart(t, name, indent, nil, nil, depth + 1)
	return cart .. autoref
end;

function eval(str)
	return assert(loadstring(str))()
end

stream_debug_counter = 0

function streamDebugWriteFloat32(streamId, value)
	value = Utils.getNoNil(value, 0.0)
	stream_debug_counter = stream_debug_counter + 1
	--[[courseplay:debug("++++++++++++++++", 55)
	courseplay:debug(stream_debug_counter, 55)
	courseplay:debug("float: " .. value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: writing float: %f",stream_debug_counter, value ),5)
	streamWriteFloat32(streamId, value)
end

function streamDebugWriteBool(streamId, value)
	value = Utils.getNoNil(value, false)
	if value == 1 then
		value = true
	end

	if value == 0 then
		value = false
	end

	stream_debug_counter = stream_debug_counter + 1
	--[[courseplay:debug("++++++++++++++++", 5)
	courseplay:debug(stream_debug_counter, 5)
	courseplay:debug("Bool: ", 5)
	courseplay:debug(value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: writing bool: %s",stream_debug_counter, tostring(value) ),5)	
	streamWriteBool(streamId, value)
end

function streamDebugWriteInt32(streamId, value)
	value = Utils.getNoNil(value, 0)
	stream_debug_counter = stream_debug_counter + 1
	--[[courseplay:debug("++++++++++++++++", 5)
	courseplay:debug(stream_debug_counter, 5)
	courseplay:debug("Int32: ", 5)
	courseplay:debug(value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: writing int: %d",stream_debug_counter, value ),5)
	streamWriteInt32(streamId, value)
end

function streamDebugWriteString(streamId, value)
	value = Utils.getNoNil(value, "")
	stream_debug_counter = stream_debug_counter + 1
	--[[courseplay:debug("++++++++++++++++", 5)
	courseplay:debug(stream_debug_counter, 5)
	courseplay:debug("String: ", 5)
	courseplay:debug(value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: writing string: %s",stream_debug_counter, value ),5)
	streamWriteString(streamId, value)
end


function streamDebugReadFloat32(streamId)
	stream_debug_counter = stream_debug_counter + 1
	--courseplay:debug("++++++++++++++++", 5)
	--courseplay:debug(stream_debug_counter, 5)
	local value = streamReadFloat32(streamId)
	--[[courseplay:debug("Float32: ", 5)
	courseplay:debug(value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: reading float: %f",stream_debug_counter, value ),5)
	return value
end


function streamDebugReadInt32(streamId)
	stream_debug_counter = stream_debug_counter + 1
	--courseplay:debug("++++++++++++++++", 5)
	--courseplay:debug(stream_debug_counter, 5)
	local value = streamReadInt32(streamId)
	--[[courseplay:debug("Int32: ", 5)
	courseplay:debug(value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: reading int: %d",stream_debug_counter, value ),5)
	return value
end

function streamDebugReadBool(streamId)
	stream_debug_counter = stream_debug_counter + 1
	--courseplay:debug("++++++++++++++++", 5)
	--courseplay:debug(stream_debug_counter, 5)
	local value = streamReadBool(streamId)
	--[[courseplay:debug("Bool: ", 5)
	courseplay:debug(value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: reading bool: %s",stream_debug_counter, tostring(value)),5)
	return value
end

function streamDebugReadString(streamId)
	stream_debug_counter = stream_debug_counter + 1
	--courseplay:debug("++++++++++++++++", 5)
	--courseplay:debug(stream_debug_counter, 5)
	local value = streamReadString(streamId)
	--[[courseplay:debug("String: ", 5)
	courseplay:debug(value, 5)
	courseplay:debug("-----------------", 5)]]
	courseplay:debug(string.format("%d: reading string: %s",stream_debug_counter, value ),5)
	return value
end
