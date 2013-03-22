function courseplay:isEven(n)
   return tonumber(n) % 2 == 0;
end;

function courseplay:isOdd(n)
   return tonumber(n) % 2 == 1;
end;

--Table concatenation: http://stackoverflow.com/a/1413919
-- return a new array containing the concatenation of all of its parameters. Scaler parameters are included in place, and array parameters have their values shallow-copied to the final array. Note that userdata and function values are treated as scalar.
function tableConcat(...) 
    local t = {}
    for n = 1,select("#",...) do
        local arg = select(n,...)
        if type(arg)=="table" then
            for _,v in ipairs(arg) do
                t[#t+1] = v
            end
        else
            t[#t+1] = arg
        end
    end
    return t
end


--stringToMath [Jakob Tischler, 22 Mar 2013]
function courseplay:stringToMath(str)
	local result = str;
	
	if string.find(str, "+") then
		local strAr = Utils.splitString("+", str);
		if table.getn(strAr) == 2 then
			result = tonumber(strAr[1]) + tonumber(strAr[2]);
			return result;
		end;
	elseif string.find(str, "-") and string.find(str, "-") > 1 then --Note: >1 so that it doesn't match simple negative numbers (e.g. "-2");
		local strAr = Utils.splitString("-", str);
		if table.getn(strAr) == 2 then
			result = tonumber(strAr[1]) - tonumber(strAr[2]);
			return result;
		end;
	elseif string.find(str, "*") then
		local strAr = Utils.splitString("*", str);
		if table.getn(strAr) == 2 then
			result = tonumber(strAr[1]) * tonumber(strAr[2]);
			return result;
		end;
	elseif string.find(str, "/") then
		local strAr = Utils.splitString("/", str);
		if table.getn(strAr) == 2 then
			result = tonumber(strAr[1]) / tonumber(strAr[2]);
			return result;
		end;
	end;
	
	return tonumber(result);
end;


function courseplay:isFolding(workTool) --TODO: use getIsAnimationPlaying(animationName)
	if SpecializationUtil.hasSpecialization(Foldable, workTool.specializations) or SpecializationUtil.hasSpecialization(foldable, workTool.specializations) then
		for k, foldingPart in pairs(workTool.foldingParts) do
			local charSet = foldingPart.animCharSet;
			local animTime = nil
			if charSet ~= 0 then
				animTime = getAnimTrackTime(charSet, 0);
			else
				animTime = workTool:getRealAnimationTime(foldingPart.animationName);
			end;

			if animTime ~= nil then
				if workTool.foldMoveDirection > 0 then
					if animTime < foldingPart.animDuration then
						return true;
					end
				elseif workTool.foldMoveDirection < 0 then
					if animTime > 0 then
						return true;
					end
				end
			end
		end;
		return false;
	else
		return false;
	end;
end;

function tableShow(t, name, indent)
	local cart -- a container
	local autoref -- for self references

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

	local function addtocart(value, name, indent, saved, field)
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
end;
