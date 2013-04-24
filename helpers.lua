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

function courseplay:handleSpecialTools(workTool,unfold,lower,turnOnOff,allowedToDrive,spare2,spare3)
	
	--gueldnerG40Frontloader free DLC classics
	if workTool.animatedFrontloader ~= nil then
		workTool:releaseShovel(unfold);
	

	-- Claas liner 4000
	elseif Utils.endsWith(workTool.configFileName, "liner4000.xml") then
		local isReadyToWork = workTool.rowerFoldingParts[1].isDown;
		local manualReset = false
		if workTool.cp.unfoldOrderIsGiven == nil then
			workTool.cp.unfoldOrderIsGiven = false
			workTool.cp.foldOrderIsGiven = false
		end
		if unfold == false and isReadyToWork then
			workTool.cp.foldOrderIsGiven = true
		end
		--lower
		if workTool.foldAnimTime > 0.99 then
			if isReadyToWork then
				for k, part in pairs(workTool.rowerFoldingParts) do
					workTool:setIsArmDown(k, lower);
				end;
				if workTool.cp.unfoldOrderIsGiven or workTool.cp.foldOrderIsGiven then
					--turn OnOff
					workTool:setIsTurnedOn(turnOnOff);
					workTool.cp.unfoldOrderIsGiven = false
				end
			end
		else
			allowedToDrive = false
		end
		--unfold			
		if (unfold and workTool.isTransport) or (workTool.cp.foldOrderIsGiven and isReadyToWork)  then
			workTool:setTransport(not unfold)
			if workTool.isReadyToTransport or workTool.cp.foldOrderIsGiven then
				if workTool.foldMoveDirection > 0.1 or (workTool.foldMoveDirection == 0 and workTool.foldAnimTime > 0.5) then
					workTool:setFoldDirection(-1)	
				else
					workTool:setFoldDirection(1)
				end;
				workTool.cp.foldOrderIsGiven = false
			end;
			workTool.cp.unfoldOrderIsGiven = true
			
		end
		if workTool.foldAnimTime == 0 then
			allowedToDrive = true
		end
		return true, allowedToDrive



	--Tebbe HS180 (Maurus)
	elseif Utils.endsWith(workTool.configFileName, "TebbeHS180.xml") then
		local flap = 0
		if workTool.setDoorHigh ~= nil and workTool.doorhigh ~= nil then
			if turnOnOff then 
				flap = 3
			end
			workTool:setDoorHigh(flap);
		end
		if workTool.setFlapOpen ~= nil and workTool.flapopen then
			workTool:setFlapOpen(turnOnOff)
		end
		return false, allowedToDrive



	--Poettinger Alpha
	elseif workTool.alpMot ~= nil and workTool.setTurnedOn ~= nil and workTool.setLiftUp ~= nil and workTool.setTransport ~= nil then
		--fold/unfold
		workTool:setTransport(not unfold);
		if workTool.alpMot.isTransport ~= nil then
			if (unfold and workTool.alpMot.isTransport) or (not unfold and not workTool.alpMot.isTransport) then
				allowedToDrive = false;
			end;
		end;
		
		--lower/raise
		workTool:setLiftUp(not lower);
		if workTool.alpMot.isLiftUp ~= nil and workTool.alpMot.isLiftDown ~= nil then
			if (lower and workTool.alpMot.isLiftUp) or (not lower and workTool.alpMot.isLiftDown) then
				allowedToDrive = false;
			end;
		end;

		--turn on/off
		workTool:setTurnedOn(turnOnOff);
		
		return true, allowedToDrive;



	--Poettinger X8
	elseif workTool.x8 ~= nil and workTool.x8.mowers ~= nil and workTool.setTurnedOn ~= nil and workTool.setLiftUp ~= nil and workTool.setTransport ~= nil and workTool.setSelection ~= nil then
		workTool:setSelection(3);
		
		local isFolded = workTool.x8.mowers[1].isTransport and workTool.x8.mowers[2].isTransport;
		local isRaised = workTool.x8.mowers[1].isLiftUp and workTool.x8.mowers[2].isLiftUp;
		
		--fold/unfold
		workTool:setTransport(not unfold);
		if (unfold and isFolded) or (not unfold and not isFolded) then
			allowedToDrive = false;
		end;
		
		--lower/raise
		workTool:setLiftUp(not lower);
		if (lower and isRaised) or (not lower and not isRaised) then
			allowedToDrive = false;
		end;

		--turn on/off
		workTool:setTurnedOn(turnOnOff);
		
		return true, allowedToDrive;
	end;



	return false, allowedToDrive;
end

function courseplay:round(num, decimals)
	if decimals and decimals > 0 then
		local mult = 10^decimals;
		return math.floor(num * mult + 0.5) / mult;
	end;
	return math.floor(num + 0.5);
end;
