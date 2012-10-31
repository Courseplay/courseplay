

function courseplay:debug(string)
  --print(string)
end

-- debugging data dumper
-- just for development and debugging
function table.show(t, name, indent)
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
--print("++++++++++++++++") 
--print(stream_debug_counter)
--print("float: ")
--print(value)
--print("-----------------") 
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
	--print("++++++++++++++++") 
    --print(stream_debug_counter)
	--print("Bool: ")
    --print(value)
	--print("-----------------") 
	streamWriteBool(streamId, value)
end

function streamDebugWriteInt32(streamId, value)
value = Utils.getNoNil(value, 0)
stream_debug_counter = stream_debug_counter +1
--print("++++++++++++++++") 
--print(stream_debug_counter)
--print("Int32: ")
--print(value)
--print("-----------------") 
  streamWriteInt32(streamId, value)
end

function streamDebugWriteString(streamId, value)
value = Utils.getNoNil(value, "")
stream_debug_counter = stream_debug_counter +1
--print("++++++++++++++++") 
--print(stream_debug_counter)
--print("String: ")
--print(value)
--print("-----------------") 
  streamWriteString(streamId, value)
end


function streamDebugReadFloat32(streamId)
stream_debug_counter = stream_debug_counter +1
--print("++++++++++++++++") 
--print(stream_debug_counter)
  local value = streamReadFloat32(streamId)
--print("Float32: ")
--print(value)
--print("-----------------") 
  return value
end


function streamDebugReadInt32(streamId)
stream_debug_counter = stream_debug_counter +1
--print("++++++++++++++++") 
--print(stream_debug_counter)
local value = streamReadInt32(streamId)
--print("Int32: ")
--print(value)
--print("-----------------") 
return value
end

function streamDebugReadBool(streamId)
stream_debug_counter = stream_debug_counter +1
--print("++++++++++++++++") 
--print(stream_debug_counter)
local value = streamReadBool(streamId)
--print("Bool: ")
--print(value)
--print("-----------------") 
return value
end

function streamDebugReadString(streamId)
stream_debug_counter = stream_debug_counter +1
--print("++++++++++++++++") 
--print(stream_debug_counter)
local value = streamReadString(streamId)
--print("String: ")
--print(value)
--print("-----------------") 
return value
end
