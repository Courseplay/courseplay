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
	if courseplay:isFoldable(workTool) then
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

function courseplay:round(num, decimals)
	if decimals and decimals > 0 then
		local mult = 10^decimals;
		return math.floor(num * mult + 0.5) / mult;
	end;
	return math.floor(num + 0.5);
end;

function courseplay:nilOrBool(variable, bool)
	return variable == nil or (variable ~= nil and variable == bool);
end;

function table.contains(table, element) --TODO: always use Utils.hasListElement
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end;

function table.map(table, func)
	local newArray = {};
	for i,v in ipairs(table) do
		newArray[i] = func(v);
	end;
	return newArray;
end;

function startswith(sbig, slittle) --TODO: always use Utils.startsWith
	if type(slittle) == "table" then
		for k, v in ipairs(slittle) do
			if string.sub(sbig, 1, string.len(v)) == v then
				return true
			end
		end
		return false
	end
	return string.sub(sbig, 1, string.len(slittle)) == slittle
end

function endswith(sbig, slittle) --TODO: always use Utils.endsWith
	if type(slittle) == "table" then
		for k, v in ipairs(slittle) do
			if string.sub(sbig, string.len(sbig) - string.len(v) + 1) == v then
				return true
			end
		end
		return false
	end
	return string.sub(sbig, string.len(sbig) - string.len(slittle) + 1) == slittle
end

function nameNum(vehicle)
	return tostring(vehicle.name) .. " (#" .. tostring(vehicle.working_course_player_num) .. ")";
end;