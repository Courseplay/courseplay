--[[ DEBUG LEVELS
	0 = nothing
	1 = important, not detailled
	2 = mildly important
	3 = important
	4 = everything, most detailled
]]
local currectDebugLevel = 4

function courseplay:debug(string, level)
	if level ~= nil then
		level = 0
		if level <= currentDebugLevel then
			print(string)
		end
	end
end

-- debugging data dumper
-- just for development and debugging
function table.show(t, name, indent)
	if currentDebugLevel > 3 then
		return
	end
	
	local cart     -- a container
	local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
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

   local function addtocart (value, name, indent, saved, field)
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
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end

function eval(str)
   return assert(loadstring(str))()
end

stream_debug_counter = 0

function streamDebugWriteFloat32(streamId, value)  
  value = Utils.getNoNil(value, 0.0)
  stream_debug_counter = stream_debug_counter +1
--courseplay:debug("++++++++++++++++", 4) 
--courseplay:debug(stream_debug_counter, 4)
--courseplay:debug("float: ", 4)
--courseplay:debug(value, 4)
--courseplay:debug("-----------------", 4) 
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
	
	stream_debug_counter = stream_debug_counter +1
	--courseplay:debug("++++++++++++++++", 4) 
    --courseplay:debug(stream_debug_counter, 4)
	--courseplay:debug("Bool: ", 4)
    --courseplay:debug(value, 4)
	--courseplay:debug("-----------------", 4) 
	streamWriteBool(streamId, value)
end

function streamDebugWriteInt32(streamId, value)
value = Utils.getNoNil(value, 0)
stream_debug_counter = stream_debug_counter +1
--courseplay:debug("++++++++++++++++", 4) 
--courseplay:debug(stream_debug_counter, 4)
--courseplay:debug("Int32: ", 4)
--courseplay:debug(value, 4)
--courseplay:debug("-----------------", 4) 
  streamWriteInt32(streamId, value)
end

function streamDebugWriteString(streamId, value)
value = Utils.getNoNil(value, "")
stream_debug_counter = stream_debug_counter +1
--courseplay:debug("++++++++++++++++", 4) 
--courseplay:debug(stream_debug_counter, 4)
--courseplay:debug("String: ", 4)
--courseplay:debug(value, 4)
--courseplay:debug("-----------------", 4) 
  streamWriteString(streamId, value)
end


function streamDebugReadFloat32(streamId)
stream_debug_counter = stream_debug_counter +1
--courseplay:debug("++++++++++++++++", 4) 
--courseplay:debug(stream_debug_counter, 4)
  local value = streamReadFloat32(streamId)
--courseplay:debug("Float32: ", 4)
--courseplay:debug(value, 4)
--courseplay:debug("-----------------", 4) 
  return value
end


function streamDebugReadInt32(streamId)
stream_debug_counter = stream_debug_counter +1
--courseplay:debug("++++++++++++++++", 4) 
--courseplay:debug(stream_debug_counter, 4)
local value = streamReadInt32(streamId)
--courseplay:debug("Int32: ", 4)
--courseplay:debug(value, 4)
--courseplay:debug("-----------------", 4) 
return value
end

function streamDebugReadBool(streamId)
stream_debug_counter = stream_debug_counter +1
--courseplay:debug("++++++++++++++++", 4) 
--courseplay:debug(stream_debug_counter, 4)
local value = streamReadBool(streamId, 4)
--courseplay:debug("Bool: ", 4)
--courseplay:debug(value, 4)
--courseplay:debug("-----------------", 4) 
return value
end

function streamDebugReadString(streamId)
stream_debug_counter = stream_debug_counter +1
--courseplay:debug("++++++++++++++++", 4) 
--courseplay:debug(stream_debug_counter, 4)
local value = streamReadString(streamId)
--courseplay:debug("String: ", 4)
--courseplay:debug(value, 4)
--courseplay:debug("-----------------", 4)
return value
end
