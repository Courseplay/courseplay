local abs, ceil, floor, huge, max, min, pi, sqrt = math.abs, math.ceil, math.floor, math.huge, math.max, math.min, math.pi, math.sqrt;

function courseplay:isEven(n)
   return tonumber(n) % 2 == 0;
end;

function courseplay:isOdd(n)
   return tonumber(n) % 2 == 1;
end;

--Table concatenation: http://stackoverflow.com/a/1413919
-- return a new array containing the concatenation of all of its parameters. Scaler parameters are included in place, and array parameters have their values shallow-copied to the final array. Note that userdata and function values are treated as scalar.
function tableConcat(...) 
	local t = {};
	for n = 1, select('#', ...) do
		local arg = select(n, ...);
		if type(arg) == 'table' then
			for _,v in ipairs(arg) do
				t[#t+1] = v;
			end;
		else
			t[#t+1] = arg;
		end;
	end;
	return t;
end;

function courseplay:round(num, decimals)
	if num == nil or type(num) ~= "number" then
		return nil;
	end;

	if decimals and decimals > 0 then
		local mult = 10^decimals;
		return math.floor(num * mult + 0.5) / mult;
	end;
	return math.floor(num + 0.5);
end;

function courseplay:nilOrBool(variable, bool)
	return variable == nil or (variable ~= nil and variable == bool);
end;

function nameNum(vehicle, hideNum)
	if vehicle == nil or not vehicle.getName then
		return 'nil';
	end;

	if vehicle.cp ~= nil and vehicle.cp.coursePlayerNum ~= nil then
		if hideNum then
			return tostring(vehicle:getName());
		end;
		return tostring(vehicle:getName()) .. ' (#' .. tostring(vehicle.cp.coursePlayerNum) .. ')';
	elseif vehicle.isHired then
		return tostring(vehicle:getName()) .. ' (helper)';
	end;
	return vehicle:getName()
end;

function courseplay:isBetween(n, num1, num2, include)
	if type(n) ~= "number" or type(num1) ~= "number" or type(num2) ~= "number" then
		return;
	end;
	if include then
		return (num1 > num2 and n <= num1 and n >= num2) or (num1 < num2 and n >= num1 and n <= num2);
	else
		return (num1 > num2 and n < num1 and n > num2) or (num1 < num2 and n > num1 and n < num2);
	end;
end;

function courseplay:setVarValueFromString(self, str, value)
	--print(string.format("courseplay:setVarValueFromString(self, %s, %s)",str,tostring(value)))
	local what = StringUtil.splitString(".", str);
	local whatDepth = #what;
	if whatDepth < 1 or whatDepth > 5 then
		return;
	end;

	local baseVar;
	if what[1] == "self" then 
		baseVar = self;
	elseif what[1] == "courseplay" then
		baseVar = courseplay;
	end;
	if baseVar ~= nil then
		local result;
		if whatDepth == 1 then --self
			baseVar = value;
			result = value;
		elseif whatDepth == 2 then --self.cp or self.var
			baseVar[what[2]] = value;
			result = value;
		elseif whatDepth == 3 then --self.cp.var
			if baseVar == self and what[2] == 'cp' then
				self:setCpVar(what[3], value,true,courseplay.isClient)
				result = value;
			else
				baseVar[what[2]][what[3]] = value;
				result = value;
			end
		elseif whatDepth == 4 then --self.cp.table.var
			baseVar[what[2]][what[3]][what[4]] = value;
			result = value;
		elseif whatDepth == 5 then --self.cp.table1.table2.var
			baseVar[what[2]][what[3]][what[4]][what[5]] = value;
			result = value;
		end;

		courseplay:debug("					" .. table.concat(what, ".") .." = " .. tostring(result),courseplay.DBG_MULTIPLAYER);
	end;

	what = nil;
end;
function courseplay:getVarValueFromString(self, str)
	local what = StringUtil.splitString(".", str);
	local whatDepth = #what;
	local whatObj;
	if what[1] == "self" then 
		whatObj = self;
	elseif what[1] == "courseplay" then
		whatObj = courseplay;
	end;

	if whatObj ~= nil then
		for i=2,whatDepth do
			local key = what[i];
			whatObj = whatObj[key];
			
			if i ~= whatDepth and type(whatObj) ~= "table" then
				print(('%s: error in string %q @ %s: traversal failed'):format(nameNum(self), str, key));
				whatObj = nil;
				break;
			end;
		end;
	end;

	--print(table.concat(what, ".") .."=" .. tostring(whatObj))
	return whatObj;
end;

function courseplay:boolToInt(bool)
	if bool and type(bool) == 'boolean' then
		return 1;
	end;
	return;
end;
function courseplay:intToBool(int)
	if int == nil or type(int) ~= "number" then
		return nil;
	end;
	return int == 1;
end;
function courseplay:trueOrNil(bool)
	if bool ~= nil and bool == true then
		return true;
	end;
	return nil;
end;

function courseplay:loopedTable(tab, idx, maxIdx)
	maxIdx = maxIdx or #tab;
	while idx > maxIdx do
		--idx = maxIdx - idx;
		idx = idx - maxIdx;
	end;
	while idx < 1 do
		idx = idx + maxIdx;
	end;

	return tab[idx];
end;

function courseplay:waypointsHaveAttr(vehicle, curRecordNumber, back, forward, attr, value, all)
	for i=curRecordNumber+back, curRecordNumber+forward do
		local wp = courseplay:loopedTable(vehicle.Waypoints, i);
		if wp[attr] ~= nil and wp[attr] == value then
			if not all then -- one waypoint has met condition, not all needed -> return true
				return true;
			end;
		elseif all then -- condition not met, but all waypoints should meet condition -> return false
			return false;
		end;
	end;

	if all then -- all waypoints have met condition (no return false in loop) -> return true
		return true;
	else -- none of the waypoints have met condition (no return true in loop) -> return false
		return false;
	end;
end;

function courseplay:varLoop(var, changeBy, maxVar, minVar)
	minVar = minVar or 1;
	var = var + changeBy;
	if var > maxVar then
		var = minVar;
	elseif var < minVar then
		var = maxVar;
	end;
	return var;
end;

-- by horoman
courseplay.utils.table = {}

function courseplay.utils.table.compare(t1,t2,field)
	local result = false
	local C1 = t1[field]
	local C2 = t2[field]
	
	if type(C1) == 'string' or type(C2) == 'string' then
		local c1 = string.lower(C1)
		local c2 = string.lower(C2)
		if c1 == c2 then
			result = C1 < C2
		else
			result = c1 < c2
		end
	else
		result = C1 < C2
	end

	return result
end

function courseplay.utils.table.compare_name(t1,t2)
	-- return courseplay.utils.table.compare(t1,t2,'name')
	return courseplay.utils.table.compare(t1, t2, 'nameClean');
end

function courseplay.utils.table.search_in_field(tab, field, term)
	local result = {}
	for k,v in pairs(tab) do
		if v[field] == term then
			table.insert(result, v)
		end
	end
	return result
end

function courseplay.utils.table.copy(tab, recursive)
-- note that if 'recursive' is not 'true', only tab is copied. if tab contains tables itself again, these tables are not copied but referenced again (the reference is copied).
	local result = {};
	for k,v in pairs(tab) do
		if recursive and type(v) == 'table' then
			result[k] = courseplay.utils.table.copy(v, recursive);
		else
			result[k] = v;
		end;
	end;
	return result;
end;

function courseplay.utils.table.append(t1,t2)
	for k,v in pairs(t2) do
		table.insert(t1,v)
	end
	return t1
end

function courseplay.utils.table.merge(t1, t2, overwrite)
	if overwrite == nil then
		overwrite = false
	end
	for k, v in pairs(t2) do
		if overwrite or t1[k] == nil then
			t1[k] = v		
		end
	end
	return t1
end

function courseplay.utils.table.move(t1, t2, t1_index, t2_index)
	t1_index = t1_index or (#t1);
	t2_index = t2_index or (#t2 + 1);
	if t1[t1_index] == nil then
		return false;
	end;

	t2[t2_index] = t1[t1_index];
	table.remove(t1, t1_index);
	return t2[t2_index] ~= nil;
end;

function table.map(t, func)
	local newArray = {};
	for i,v in pairs(t) do
		newArray[i] = func(v);
	end;
	return newArray;
end;

-- reverse order of elements in table in place
function table.reverse(t)
	local i, j = 1, #t

	while i < j do
		t[i], t[j] = t[j], t[i]

		i = i + 1
		j = j - 1
	end
end;

function table.getLast(t)
	if #t == 0 then
		if next(t) ~= nil then
			return table.maxn(t);
		end;
		return nil;
	end;
	return t[#t];
end;

function table.rotate(tbl, inc) --@gist: https://gist.github.com/JakobTischler/b4bb7a4d1c8cf8d2d85f
	if inc == nil or inc == 0 then
		return tbl;
	end;

	local t = tbl;
	local rot = math.abs(inc);

	if inc < 0 then
		for i=1,rot do
			local p = t[1];
			table.remove(t, 1);
			table.insert(t, p);
		end;
	else
		for i=1,rot do
			local n = #t;
			local p = t[n];
			table.remove(t, n);
			table.insert(t, 1, p);
		end;
	end;

	return t;
end;

function courseplay.utils.table.getMax(tab, field)
	local max;
	if tab ~= nil and field ~= nil then
		max = false
		for k, v in pairs(tab) do -- TODO (Jakob): use next(tab) instead of for loop
			if v[field] ~= nil then
				max = v[field]
				break
			end
		end
		for k, v in pairs(tab) do
			if v[field] ~= nil then
				if v[field] > max then
					max = v[field]
				end
			end
		end
	end
	return max
end;



courseplay.prmGetXMLFn = {
	Bool = getXMLBool,
	Float = getXMLFloat,
	Int = getXMLInt,
	String = getXMLString
};
courseplay.prmSetXMLFn = {
	Bool = setXMLBool,
	Float = setXMLFloat,
	Int = setXMLInt,
	String = setXMLString
};
function courseplay.utils.findXMLNodeByAttr(File, node, attr, value, valueType)
	-- returns the node number in case of success
	-- else it returns the negative value of the next unused node (if there are 6 nodes with the name defined by the node parameter and none matches the search, the function returns -7)
	valueType = valueType or 'Int'
	local i = -1
	local done = false
	local dummy

	if courseplay.prmGetXMLFn[valueType] ~= nil then
		-- this solution does not look very nice but has no unnecessary statements in the loops which should make them as fast as possible
		repeat
			i = i + 1;
			dummy = '';
			dummy = courseplay.prmGetXMLFn[valueType](File, string.format(node .. '(%d)' .. "#" .. attr, i));
			if dummy == value then
				done = true;
			elseif dummy == nil then -- the attribute seems not to exist. Does the node?
				if not hasXMLProperty(File, string.format(node .. '(%d)', i)) then -- if the node does not exist, we are at the end and done
					done = true;
				end;
			end;
		until done;
	else
		-- ERROR
	end;

	if dummy ~= nil then
		return i;
	else
		return -1 * i;
	end;
end;

function courseplay.utils.findFreeXMLNode(File, node)
	-- returns the node number in case of success
	local i = -1
	local done = false
	local exists
	
	repeat
		i = i+1
		exists = hasXMLProperty(File, string.format(node .. '(%d)', i))
		if not exists then
			done = true
		end
	until done
	
	return i
end

function courseplay.utils.setXML(File, node, attribute, value, valueType, match_attr, match_attr_value, match_attr_type)
	-- this function is not meant do be called in loops as it is rather slow: 
	-- it is searched for the node everytime the function is called.
	-- Use setMultipleXML instead.
	attribute = attribute or '';
	valueType = valueType or 'Int';
	match_attr = match_attr or '';
	match_attr_value = match_attr_value or '';
	match_attr_type = match_attr_type or 'Int';
	
	if attribute ~= '' then
		attribute = '#' .. attribute;
	end;

	if match_attr ~= '' and match_attr_value ~= '' then
		local i = courseplay.utils.findXMLNodeByAttr(File, node, match_attr, match_attr_value, match_attr_type);
		if i < 0 then i = -i end;
		courseplay.prmSetXMLFn[valueType](File, ('%s(%d)%s'):format(node, i, attribute), value);
	else
		courseplay.prmSetXMLFn[valueType](File, node .. attribute, value);
	end;
end;

function courseplay.utils.setMultipleXML(File, node, values, types)
-- function to save multiple attributes (and to the node itself) of one node
--
-- File: File got by loadXML(...)
-- node (string)
-- values has to be a table of the form:
-- {attribute1 = value1, attribute2 = value2, ...}
-- to write into the node directly set attribute = '_node_'
-- types is a table of the form:
-- {attribute1 = type1, attribute2 = type2, ...}; type1 is a string (e.g. 'Int')
-- attributes with no type in the types table will be skipped.
	for attribute, value in pairs(values) do
		local valueType = types[attribute]

		if valueType ~= nil then
			if attribute ~= '_node_' then
				attribute = '#' .. attribute
			else
				attribute = ''
			end

			if value ~= nil and courseplay.prmSetXMLFn[valueType] ~= nil then
				courseplay.prmSetXMLFn[valueType](File, node .. attribute, value);
			else
				-- Error?!
				print('could not save attribute: ' .. attribute)
			end
		end -- end if not skip then
	end -- end for k, v in pairs(values) do
end

function courseplay.utils.setMultipleXMLNodes(File, root_node, node_name , values, types, unique_nodes)
	-- values has to be a table of the form:
	-- {attribute1 = value1, attribute2 = value2, ...}
	-- types a table of the form:
	-- {attribute1 = type1, attribute2 = type2, ...}
	-- to write into the node directly set attribute = '_node_'

	if unique_nodes == nil then
		unique_nodes = true
	end
	
	local skip = false
	local j = 0
	local node = ''

	
	for k, v in pairs(values) do
		if unique_nodes then
			node = root_node .. '.' .. node_name .. k
		else
			node = string.format(root_node .. '.' .. node_name .. '(%d)', j)
			j = j+1
		end		
		courseplay.utils.setMultipleXML(File, node, v, types)
	end
end

---------------------------

function courseplay.utils.normalizeAngle(angle)
	local newAngle = angle;
	while newAngle >= 360 do
		newAngle = newAngle - 360;
	end;
	while newAngle < 0 do
		newAngle = newAngle + 360;
	end;
	return newAngle;
end;

function courseplay:setCustomTimer(vehicle, timerName, seconds)
	vehicle.cp.timers[timerName] = vehicle.timer + (seconds * 1000);
end;
function courseplay:timerIsThrough(vehicle, timerName, defaultToBool)
	local timer = vehicle.cp.timers[timerName];
	if timer == nil then
		return Utils.getNoNil(defaultToBool, true);
	end;
	return vehicle.timer > timer;
end;
function courseplay:getCustomTimerExists(vehicle, timerName)
	return vehicle.cp.timers[timerName] ~= nil;
end;
function courseplay:resetCustomTimer(vehicle, timerName, setToNil)
	if setToNil then
		vehicle.cp.timers[timerName] = nil;
	else
		vehicle.cp.timers[timerName] = 0.0;
	end;
end;

function courseplay:getDriveDirection(node, x, y, z)
	local lx, ly, lz = worldToLocal(node, x, y, z)
	local length = MathUtil.vector3Length(lx,ly,lz)
	if length > 0 then
		lx = lx / length
		lz = lz / length
		ly = ly /length
	end
	return lx,ly,lz
end

function courseplay:checkAndPrintChange(vehicle, variable, VariableNameString)
	if vehicle.cp.checkTable == nil then
		vehicle.cp.checkTable = {}
	end
	if variable == nil then
		variable = -32756
	end
	if variable ~= vehicle.cp.checkTable[VariableNameString] then
		print(string.format("%s: changed Variable: %s: %s",nameNum(vehicle),VariableNameString,tostring(variable)))
		vehicle.cp.checkTable[VariableNameString] = variable
	end
end;

function courseplay.utils:hasVarChanged(vehicle, variableName, direct) 
	if direct == nil then direct = false; end;
	if vehicle.cp.varMemory == nil then
		vehicle.cp.varMemory = {};
	end;

	local variable;
	if direct then
		variable = vehicle[variableName];
	else
		variable = vehicle.cp[variableName];
	end;
	local memory = vehicle.cp.varMemory[variableName];

	if (memory == nil and variable ~= nil) or (memory ~= nil and (variable == nil or variable ~= vehicle.cp.varMemory[variableName])) then
		courseplay:debug(string.format('%s: hasVarChanged(): changed variable %q - old=%q, new=%q', nameNum(vehicle), variableName, tostring(memory), tostring(variable)), courseplay.DBG_UNCATEGORIZED);
		vehicle.cp.varMemory[variableName] = variable;
		return true;
	end;
	return false;
end;

function courseplay.utils:getFnCallSource(level)
	level = (level or 1) + 1;
	return tostring(debug.getinfo(level, "n").name);
end;

function courseplay.utils:getFnCallPath(numPathSteps)
	numPathSteps = numPathSteps or 1;
	if numPathSteps > 1 then
		local ret = {};
		local fn, file, line;
		for level=numPathSteps + 2, 2, -1 do
			local debugData = debug.getinfo(level, 'nSl');
			if level <= numPathSteps + 1 then
				fn = debugData.name;
				if fn and file and line then
					ret[#ret + 1] = ('[%d] %s() (%s:%d)'):format(level - 1, fn, file, line);
				end;
			end;
			file = courseplay.utils:getFileNameFromPath(debugData.source);
			line = debugData.currentline;
			-- print(('level %d: fn=%q, file=%q, line=%d'):format(level, tostring(fn), tostring(file), line))
		end;
		return table.concat(ret, ' -> ');
	end;

	local debugData = debug.getinfo(2, 'nSl');
	local file = courseplay.utils:getFileNameFromPath(debugData.source);
	return ('%s() (%s:%d)'):format(debugData.name, file, debugData.currentline);
end;

function courseplay.utils:getFileNameFromPath(filePath)
	if not filePath then return 'N/A' end
	local fileName = filePath;

	local idx = filePath:match('^.*()/'); -- check for last forward slash
	if idx == nil then
		idx = filePath:match('^.*()\\'); -- check for last backward slash
	end;
	if idx then
		fileName = filePath:sub(idx + 1);
	end;

	return fileName;
end;

function courseplay:loc(key)
	return courseplay.locales[key] or key;
end;

function courseplay:getSpeedMeasuringUnit()
	return g_i18n:getSpeedMeasuringUnit()
end

function courseplay:getMeasuringUnit()
	return g_gameSettings.useMiles and g_i18n:getText('unit_miles') or g_i18n:getText('unit_km');
end

function courseplay.utils:crossProductQuery(a, b, c, useC)
	-- returns:
	--	-1	vector from A to right intersects BC (except at the bottom end point)
	--	 0	A is directly on BC
	--	 1	all else

	if useC == nil then useC = true; end;
	local x,z = useC and 'cx' or 'x', useC and 'cz' or 'z';

	if a[z] == b[z] and b[z] == c[z] then
		if (b[x] <= a[x] and a[x] <= c[x]) or (c[x] <= a[x] and a[x] <= b[x]) then
			return 0;
		else
			return 1;
		end;
	end;

	if b[z] > c[z] then
		local cNew = b;
		local bNew = c;
		b,c = bNew,cNew;
	end;

	if a[z] == b[z] and a[x] == b[x] then
		return 0;
	end;

	if a[z] <= b[z] or a[z] > c[z] then
		return 1;
	end;

	local delta = (b[x] - a[x]) * (c[z] - a[z]) - (b[z] - a[z]) * (c[x] - a[x]);

	-- possible to use MathUtil.sign(): return MathUtil.sign(delta) * -1;
	if delta > 0 then
		return -1;
	elseif delta < 0 then
		return 1;
	else
		return 0;
	end;
end;

function courseplay:getRelativePointDirection(pp, cp, np, useC)
	if pp == nil or cp == nil or np == nil then return nil; end;
	if useC == nil then useC = true; end;

	local dx1, dz1 = courseplay:getPointDirection(pp, cp, useC);
	local dx2, dz2 = courseplay:getPointDirection(cp, np, useC);

	local rot1 = MathUtil.getYRotationFromDirection(dx1, dz1);
	local rot2 = MathUtil.getYRotationFromDirection(dx2, dz2);

	local rotDelta = rot1 - rot2; --TODO: rot2 - rot1 ?
	
	return MathUtil.getDirectionFromYRotation(rotDelta);
end;

function courseplay:getObjectName(object, xmlFile)
	-- if object.name ~= nil the return object.name; end;
	
	if object.configFileName then
		local storeItem = g_storeManager:getItemByXMLFilename(object.configFileName);
		if storeItem and storeItem.name then
			return storeItem.name;
		end;
	end;

	if xmlFile ~= nil and xmlFile ~= 0 then
		local nameSearch = { 'vehicle.name.' .. g_languageShort, 'vehicle.name.en', 'vehicle.name', 'vehicle#type' };
		local name;
		for i,xmlKey in ipairs(nameSearch) do
			name = getXMLString(xmlFile, xmlKey);
			if name ~= nil then 
				return name;
			end;
		end;
	end;

	return courseplay:loc('UNKNOWN') .. '_' .. tostring(object.rootNode);
end;

function courseplay:getRealWorldRotation(node, direction)
	if not direction then direction = 1 end;
	local x,_,z = localDirectionToWorld(node, 0, 0, direction);
	return MathUtil.getYRotationFromDirection(x, z);
end;

function courseplay:getWorldDirection(fromX, fromY, fromZ, toX, toY, toZ)
	-- NOTE: if only 2D is needed, pass fromY and toY as 0
	local wdx, wdy, wdz = toX - fromX, toY - fromY, toZ - fromZ;
	local dist = MathUtil.vector3Length(wdx, wdy, wdz); -- length of vector
	if dist and dist > 0.01 then
		wdx, wdy, wdz = wdx/dist, wdy/dist, wdz/dist; -- if not too short: normalize
		return wdx, wdy, wdz, dist;
	end;
	return 0, 0, 0, 0;
end;

function courseplay.utils:setOverlayUVsSymmetric(overlay, col, line, numCols, numLines)
	if overlay.overlayId and overlay.currentUVs == nil or overlay.currentUVs ~= { col, line, numCols, numLines } then
		local bottomY = 1 - line / numLines;
		local topY = bottomY + 1 / numLines;
		local leftX = (col - 1) / numCols;
		local rightX = leftX + 1 / numCols;
		setOverlayUVs(overlay.overlayId, leftX,bottomY, leftX,topY, rightX,bottomY, rightX,topY);
		overlay.currentUVs = { col, line, numCols, numLines };
	end;
end;

function courseplay.utils:setOverlayUVsPx(overlay, UVs, textureSizeX, textureSizeY)
	if overlay.overlayId and overlay.currentUVs == nil or overlay.currentUVs ~= UVs then
		local leftX, bottomY, rightX, topY = unpack(UVs);

		local fromTop = false;
		if topY < bottomY then
			fromTop = true;
		end;
		local leftXNormal = leftX / textureSizeX;
		local rightXNormal = rightX / textureSizeX;
		local bottomYNormal = bottomY / textureSizeY;
		local topYNormal = topY / textureSizeY;
		if fromTop then
			bottomYNormal = 1 - bottomYNormal;
			topYNormal = 1 - topYNormal;
		end;
		setOverlayUVs(overlay.overlayId, leftXNormal,bottomYNormal, leftXNormal,topYNormal, rightXNormal,bottomYNormal, rightXNormal,topYNormal);
		overlay.currentUVs = UVs;
	end;
end;

function courseplay.utils:getUvs(UVs, textureSizeX, textureSizeY)
	local leftX, bottomY, rightX, topY = unpack(UVs);

	local fromTop = false;
	if topY < bottomY then
		fromTop = true;
	end;
	local leftXNormal = leftX / textureSizeX;
	local rightXNormal = rightX / textureSizeX;
	local bottomYNormal = bottomY / textureSizeY;
	local topYNormal = topY / textureSizeY;
	if fromTop then
		bottomYNormal = 1 - bottomYNormal;
		topYNormal = 1 - topYNormal;
	end
	return {leftXNormal,bottomYNormal, leftXNormal,topYNormal, rightXNormal,bottomYNormal, rightXNormal,topYNormal}
end

function courseplay.utils:roundToLowerInterval(num, idp)
	return floor(num / idp) * idp;
end;

function courseplay.utils:roundToUpperInterval(num, idp)
	return ceil(num / idp) * idp;
end;

function courseplay.utils:getColorFromPct(pct, colorMap, step)
	if colorMap[pct] then
		return unpack(colorMap[pct]);
	end;

	local lower = self:roundToLowerInterval(pct, step);
	local upper = self:roundToUpperInterval(pct, step);

	local alpha = (pct - lower) / step;
	return MathUtil.vector3ArrayLerp(colorMap[lower], colorMap[upper], alpha);
end;

-- 2D course
function courseplay.utils:getCourseDimensions(poly)
	local xMin, yMin = huge, huge;
	local xMax, yMax = -huge, -huge;
	for _,point in pairs(poly) do
		xMin = min(xMin, point.x or point.cx);
		yMin = min(yMin, point.z or point.cz);
		xMax = max(xMax, point.x or point.cx);
		yMax = max(yMax, point.z or point.cz);
	end;
	local span = max(xMax-xMin,yMax-yMin);

	return { xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax, span = span };
end;

function courseplay.utils:scalePlotField2D(x, y)
	local xRes = CpManager.course2dPlotField.x + x * CpManager.course2dPlotField.width;
	local yRes = CpManager.course2dPlotField.y + y * CpManager.course2dPlotField.height;
	return xRes, yRes
end;

function courseplay.utils:det(x1, y1, x2, y2)
	return x1 * y2 - y1 * x2;
end;

function courseplay.utils:removeCollinearPoints(poly, epsilon)
	local function pointsAreCollinear(p, q, r, eps)
		return abs(self:det(q.cx-p.cx, q.cz-p.cz,    r.cx-p.cx, r.cz-p.cz)) <= (eps or 1e-32)
	end

	local res = self.table.copy(poly);
	res[1].origIndex = 1;
	res[#poly].origIndex = #poly;
	for k=#poly-1,2,-1 do
		res[k].origIndex = k;
		if pointsAreCollinear(res[k+1], res[k], res[k-1], epsilon) then
			table.remove(res,k)
		end;
	end;

	return res;
end;

function courseplay.utils:worldCoordsTo2D(vehicle, worldX, worldZ)
	local x =     (worldX - vehicle.cp.course2dDimensions.xMin) / vehicle.cp.course2dDimensions.span;
	local y = 1 - (worldZ - vehicle.cp.course2dDimensions.yMin) / vehicle.cp.course2dDimensions.span;
	x, y = self:scalePlotField2D(x, y);
	-- x = courseplay.hud:getFullPx(x, 'x');
	-- y = courseplay.hud:getFullPx(y, 'y');

	return x, y;
end;

function courseplay.utils:update2dCourseBackgroundPos(vehicle, mouseX, mouseY)
	local dx = mouseX - CpManager.course2dDragDropMouseDown[1];
	local dy = mouseY - CpManager.course2dDragDropMouseDown[2];

	if vehicle.cp.course2dPdaMapOverlay then
		vehicle.cp.course2dPdaMapOverlay:setColor(1,0,0,0.6);
		vehicle.cp.course2dPdaMapOverlay:setPosition(vehicle.cp.course2dPdaMapOverlay.origPos[1] + dx, vehicle.cp.course2dPdaMapOverlay.origPos[2] + dy)
	else
		setOverlayColor(CpManager.course2dPolyOverlayId, 1,0,0,0.6);
		vehicle.cp.course2dBackground.x = vehicle.cp.course2dBackground.origPos[1] + dx;
		vehicle.cp.course2dBackground.y = vehicle.cp.course2dBackground.origPos[2] + dy;
	end;
end;

function courseplay.utils:move2dCoursePlotField(vehicle, mouseX, mouseY)
	-- reset background color
	if vehicle.cp.course2dPdaMapOverlay then
		vehicle.cp.course2dPdaMapOverlay:setColor(1, 1, 1, CpManager.course2dPdaMapOpacity);
	end;

	local dx = mouseX - CpManager.course2dDragDropMouseDown[1];
	local dy = mouseY - CpManager.course2dDragDropMouseDown[2];

	-- update plot position
	if dx ~= 0 or dy ~= 0 then
		local newX = MathUtil.clamp(CpManager.course2dPlotPosX + dx, 0 + CpManager.course2dPlotField.width  * 0.05, 1 - CpManager.course2dPlotField.width  * 1.05); -- 5% padding
		local newY = MathUtil.clamp(CpManager.course2dPlotPosY + dy, 0 + CpManager.course2dPlotField.height * 0.05, 1 - CpManager.course2dPlotField.height * 1.05); -- 5% padding
		-- print(('move2dCoursePlotField(): dx=%.3f, dy=%.3f -> newX=%.3f, newY=%.3f'):format(dx, dy, newX, newY));

		CpManager.course2dPlotPosX = newX;
		CpManager.course2dPlotPosY = newY;
		CpManager.course2dPlotField.x = CpManager.course2dPlotPosX;
		CpManager.course2dPlotField.y = CpManager.course2dPlotPosY;

		-- update 2D data for all vehicles
		for k,veh in pairs(g_currentMission.enterables) do
			if veh.hasCourseplaySpec then
				veh.cp.course2dUpdateDrawData = true;
			end;
		end;
	end;

	-- reset data
	CpManager.course2dDragDropMouseDown = nil;
end;

function courseplay:setupCourse2dData(vehicle)
	vehicle.cp.course2dDrawData = nil;
	if vehicle.cp.numWaypoints < 1 then return; end;

	vehicle.cp.course2dDimensions = courseplay.utils:getCourseDimensions(vehicle.Waypoints);
	local bBox = vehicle.cp.course2dDimensions;
	local pxSize = 2;  -- thickness of line in pixels
	local height = pxSize / g_screenHeight;

	local bgPadding = 0.05 * bBox.span;
	local bgX1, bgY1 = courseplay.utils:worldCoordsTo2D(vehicle, bBox.xMin - bgPadding, bBox.yMin - bgPadding);
	local bgX2, bgY2 = courseplay.utils:worldCoordsTo2D(vehicle, bBox.xMax + bgPadding, bBox.yMax + bgPadding);
	local bgW, bgH = bgX2 - bgX1, abs(bgY2 - bgY1);

	vehicle.cp.course2dBackground = {
		x = bgX1,
		y = bgY2, -- seems wrong, but is correct, as [3D] topZ < bottomZ, but [2D] topY > bottomY
		width = bgW,
		height = bgH,
		tractorVisAreaMinX = bgX1,
		tractorVisAreaMaxX = bgX2,
		tractorVisAreaMinY = bgY2,
		tractorVisAreaMaxY = bgY1
	};

	-- PDA MAP BG
	if vehicle.cp.course2dPdaMapOverlay then
		local leftX	  = bBox.xMin - bgPadding + g_currentMission.hud.ingameMap.worldCenterOffsetX;
		local bottomY = bBox.yMax + bgPadding + g_currentMission.hud.ingameMap.worldCenterOffsetZ;
		local rightX  = bBox.xMax + bgPadding + g_currentMission.hud.ingameMap.worldCenterOffsetX;
		local topY	  = bBox.yMin - bgPadding + g_currentMission.hud.ingameMap.worldCenterOffsetZ;
		courseplay.utils:setOverlayUVsPx(vehicle.cp.course2dPdaMapOverlay, { leftX, bottomY, rightX, topY }, g_currentMission.hud.ingameMap.worldSizeX, g_currentMission.hud.ingameMap.worldSizeZ);

		vehicle.cp.course2dPdaMapOverlay:setPosition(vehicle.cp.course2dBackground.x, vehicle.cp.course2dBackground.y);
		vehicle.cp.course2dPdaMapOverlay:setDimension(vehicle.cp.course2dBackground.width, vehicle.cp.course2dBackground.height);
	end;

	vehicle.cp.course2dDrawData = {};
	local epsilon = 2; -- orig: 0.001, also ok: 0.5
	local reducedWaypoints = courseplay.utils:removeCollinearPoints(vehicle.Waypoints, epsilon);
	local numReducedPoints = #reducedWaypoints;

	local np, startX, startY, endX, endY, dx, dz, dx2D, dy2D, width, rotation, r, g, b;
	for i,wp in ipairs(reducedWaypoints) do
		np = i < numReducedPoints and reducedWaypoints[i + 1] or reducedWaypoints[1];

		startX, startY = courseplay.utils:worldCoordsTo2D(vehicle, wp.cx, wp.cz);
		endX, endY	   = courseplay.utils:worldCoordsTo2D(vehicle, np.cx, np.cz);

		dx2D = endX - startX;
		dy2D = (endY - startY) / g_screenAspectRatio;
		width = MathUtil.vector2Length(dx2D, dy2D);

		dx = np.cx - wp.cx;
		dz = np.cz - wp.cz;
		rotation = MathUtil.getYRotationFromDirection(dx, dz) - pi * 0.5;

		r, g, b = courseplay.utils:getColorFromPct(100 * wp.origIndex / vehicle.cp.numWaypoints, CpManager.course2dColorTable, CpManager.course2dColorPctStep);

		vehicle.cp.course2dDrawData[i] = {
			x = startX;
			y = startY;
			width = width;
			height = height;
			rotation = rotation;
			color = { r, g, b, 1 };
		};
	end;

	vehicle.cp.course2dUpdateDrawData = false;
end;

function courseplay:drawCourse2D(vehicle, doLoop)
	-- dynamically update the data (when drag + drop happens)
	if vehicle.cp.course2dUpdateDrawData then
		-- print(('%s: course2dUpdateDrawData==true -> call setupCourse2dData()'):format(nameNum(vehicle)));
		courseplay:setupCourse2dData(vehicle);
	end;

	if not vehicle.cp.course2dDrawData then
		return;
	end;

	-- background
	local bg = vehicle.cp.course2dBackground;
	if vehicle.cp.course2dPdaMapOverlay then
		vehicle.cp.course2dPdaMapOverlay:render();
	else
		if not CpManager.course2dDragDropMouseDown then
			setOverlayColor(CpManager.course2dPolyOverlayId, 0,0,0,0.6);
		end;
		renderOverlay(CpManager.course2dPolyOverlayId, bg.x, bg.y, bg.width, bg.height);
	end;

	if CpManager.course2dDragDropMouseDown ~= nil then -- drag and drop mode -> only render background
		return;
	end;

	-- course
	local numPoints = #vehicle.cp.course2dDrawData;
	local r,g,b,a;
	for i,data in ipairs(vehicle.cp.course2dDrawData) do
		if not doLoop and i == numPoints then
			break;
		end;

		r,g,b,a = unpack(data.color);
		setOverlayColor(CpManager.course2dPolyOverlayId, r,g,b,a);

		setOverlayRotation(CpManager.course2dPolyOverlayId, data.rotation, 0, 0);

		renderOverlay(CpManager.course2dPolyOverlayId, data.x, data.y, data.width, data.height);
	end;
	setOverlayRotation(CpManager.course2dPolyOverlayId, 0, 0, 0); -- reset overlay rotation


	-- render vehicle position
	local ovl = CpManager.course2dTractorOverlay;
	local worldX,_,worldZ = getWorldTranslation(vehicle.rootNode);
	if worldX ~= vehicle.cp.course2dTranslationX or worldZ ~= vehicle.cp.course2dTranslationZ then
		vehicle.cp.course2dTranslationX = worldX;
		vehicle.cp.course2dTranslationZ = worldZ;
		vehicle.cp.course2dTranslationX2D, vehicle.cp.course2dTranslationZ2D = courseplay.utils:worldCoordsTo2D(vehicle, worldX, worldZ);
		ovl:setPosition(vehicle.cp.course2dTranslationX2D - ovl.width * 0.5, vehicle.cp.course2dTranslationZ2D - ovl.height * 0.5);
	end;

	local x, y = vehicle.cp.course2dTranslationX2D, vehicle.cp.course2dTranslationZ2D;
	if x < bg.tractorVisAreaMinX or x > bg.tractorVisAreaMaxX or y < bg.tractorVisAreaMinY or y > bg.tractorVisAreaMaxY then
		-- outside of background area -> abort
		return;
	end;

	local dx,_,dz = localDirectionToWorld(vehicle.cp.directionNode or vehicle.rootNode, 0, 0, 1);
	if dx ~= vehicle.cp.course2dDirectionX or dz ~= vehicle.cp.course2dDirectionZ then
		vehicle.cp.course2dDirectionX = dx;
		vehicle.cp.course2dDirectionZ = dz;
		local rotation = MathUtil.getYRotationFromDirection(dx, dz) - pi * 0.5;
		ovl:setRotation(rotation, ovl.width * 0.5, ovl.height * 0.5);
	end;

	ovl:render();
end;

function courseplay.utils:rgbToNormal(r, g, b, a)
	if a then
		return { r/255, g/255, b/255, a };
	end;

	return { r/255, g/255, b/255 };
end;

function courseplay:sekToTimeFormat(numSec)
	local nSeconds = numSec
	local nHours = math.floor(nSeconds/3600);
	local nMins = math.floor(nSeconds/60 - (nHours*60));
	local nSecs = math.floor(nSeconds - nHours*3600 - nMins *60);
	local timeTable = {}
	if nSeconds == 0 then
		timeTable = {
					nHours = 0;
					nMins = 0;
					nSecs = 0;
					}
			return timeTable
	end
	timeTable = {
					nHours = nHours;
					nMins = nMins;
					nSecs = nSecs;
					
					}
	return timeTable	
end


local excludeTables = {
	["attacherVehicle"] 		= true,
	["currentSelection"] 		= true,
	["selectionObject"] 		= true,
	["selectableObjects"] 		= true,
	["modifierTargetObject"] 	= true
}
function courseplay:printMeThisTable(t,level,maxlevel,upperPath)
	-- If alreadyPrinted is not defined, define it.
	if not courseplay.alreadyPrinted then courseplay.alreadyPrinted = {} end;

	local stepWidth = 4
	local spacer = math.max(1,level*stepWidth)
	local lowSpacer = math.max(1,spacer-stepWidth)
	local printSpace =""
	local printLowSpace = ""
	local nextLevel = level+1;
	for i=1,spacer do
		printSpace = printSpace.." ";
	end
	for i=1,lowSpacer do
		printLowSpace = printLowSpace.." ";
	end
	if level == 0 then
		print(upperPath..":")
		print("[")
	else
		print(printLowSpace.."[")
	end
	if courseplay.alreadyPrinted[t] then
		print(printSpace.."already printed")
	else
		for index,value in pairs(t)do
			local newPath = upperPath.."."..tostring(index)
			if type(value) =='table' and nextLevel<=maxlevel then
				if excludeTables[tostring(index)] then
					print(string.format("%s%s:(%s -> Table Excluded)",printSpace,tostring(newPath),tostring(value)));
				else
					print(string.format("%s%s:(%s)",printSpace,tostring(newPath),tostring(value)))
					courseplay:printMeThisTable(value,nextLevel,maxlevel,newPath)
				end;
			else
				print(printSpace..string.format("%s:%s",tostring(index),tostring(value)))
			end
		end
	end
	courseplay.alreadyPrinted[t] = true;
	if level == 0 then
		print("]")
	else
		print(printLowSpace.."]")
	end

	-- We are done printing, so clear the alreadyPrinted table.
	if level == 0 then
		courseplay.alreadyPrinted = {};
	end;
end



function courseplay:segmentsIntersection(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y) --@src: http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect#comment19248344_1968345
	local s1_x, s1_y, s2_x, s2_y;
	s1_x = A2x - A1x;
	s1_y = A2y - A1y;
	s2_x = B2x - B1x;
	s2_y = B2y - B1y;

	local s, t;
	s = (-s1_y * (A1x - B1x) + s1_x * (A1y - B1y)) / (-s2_x * s1_y + s1_x * s2_y);
	t = ( s2_x * (A1y - B1y) - s2_y * (A1x - B1x)) / (-s2_x * s1_y + s1_x * s2_y);

	if (s >= 0 and s <= 1 and t >= 0 and t <= 1) then
		--Collision detected
		local x = A1x + (t * s1_x);
		local z = A1y + (t * s1_y);
		return { x = x, z = z };
	end;

	--No collision
	return nil;
end;

function courseplay:getPointDirection(cp, np)
	-- TODO get rid of cx/cz
	local dx, dz = (np.x or np.cx) - (cp.x or cp.cx), (np.z or np.cz) - (cp.z or cp.cz)
	local vl = MathUtil.vector2Length(dx, dz);
	if vl and vl > 0.0001 then
		dx = dx / vl;
		dz = dz / vl;
	end;
	return dx, dz, vl;
end;

function courseplay:getClosestPolyPoint(poly, x, z)
	local closestDistance = math.huge;
	local closestPointIndex;

	for i=1, #(poly) do
		local cp = poly[i];
		local distanceToPoint = courseplay:distance(cp.cx, cp.cz, x, z);
		if distanceToPoint < closestDistance then
			closestDistance = distanceToPoint;
			closestPointIndex = i;
		end;
	end;

	return closestPointIndex;
end;

HelperUtil = {}

---Prints a table to an xml File recursively.
---Basically has the same function as DebugUtil.printTableRecursively() except for saving the prints to an xml file
---@param int/float/.. value is the last relevant value from parent table
---@param int depth is the current depth of the iteration
---@param int maxDepth represent the max iterations 
---@param xmlFile to save in
---@param string baseKey parent key 
function HelperUtil.printTableRecursivelyToXML(value, depth, maxDepth,xmlFile,baseKey)
	depth = depth or 0
	maxDepth = maxDepth or 3
	if depth > maxDepth then
		return
	end
	local key = string.format('%s.depth:%d',baseKey,depth)
	local k = 0
	for i,j in pairs(value) do
		local key = string.format('%s(%d)',key,k)
		local valueType = type(j) 
		setXMLString(xmlFile, key .. '#valueType', tostring(valueType))
		setXMLString(xmlFile, key .. '#index', tostring(i))
		setXMLString(xmlFile, key .. '#value', tostring(j))
		if valueType == "table" then
			HelperUtil.printTableRecursivelyToXML(j,depth+1, maxDepth,xmlFile,key)
		end
		k = k + 1
	end
end

---Prints a global variable to an xml File.
---@param int/float/.. global variable to print to xmlFile
---@param int maxDepth represent the max iterations 
function HelperUtil.printVariableToXML(variableName, maxDepth)
	local baseKey = 'CpDebugPrint'
	local xmlFile = createXMLFile("xmlFile", CpManager.cpDebugPrintXmlFilePath, baseKey);
	local xmlFileValid = xmlFile and xmlFile ~= 0 or false
	if not xmlFileValid then
		courseplay.error("Xml File not valid!")
		return 
	end
	setXMLString(xmlFile, baseKey .. '#maxDepth', tostring(maxDepth))
	local depth = maxDepth and math.max(1, tonumber(maxDepth)) or 1
	local value = CpManager:getVariable(variableName)
	local valueType = type(value)
	if value then
		local key = string.format('%s.depth:%d',baseKey,0)
		setXMLString(xmlFile, key .. '#valueType', tostring(valueType))
		setXMLString(xmlFile, key .. '#variableName', tostring(variableName))
		if valueType == 'table' then		
			HelperUtil.printTableRecursivelyToXML(value,1,depth,xmlFile,key)
			local mt = getmetatable(value)
			if mt and type(mt) == 'table' then
				HelperUtil.printTableRecursivelyToXML(mt,1,depth,xmlFile,key..'-metaTable')
			end
		else 
			setXMLString(xmlFile, key .. '#valueType', tostring(valueType))
			setXMLString(xmlFile, key .. '#value', tostring(value))
		end
	else 
		setXMLString(xmlFile, key .. '#value', tostring(value))
	end
	saveXMLFile(xmlFile)
	delete(xmlFile)
	courseplay.info("Finished printing to courseplayDebugPrint.xml")
end
