--[[
@name: 		CourseplayFields
@author:	Jakob Tischler
@version:	0.3.1
@date:		06 Jul 2013

INFO
----------------------------
TG "courseplayFields" --- userAttribute "onCreate" [script callback] ==> "ZZZ_courseplay.onCreateCourseplayFields" (<Attribute name="onCreate" type="scriptCallback" value="ZZZ_courseplay.onCreateCourseplayFields" />)
\__	TG "f1" --- userAttribute "fieldNum" [integer] ==> "1" (<Attribute name="fieldNum" type="integer" value="1" />)
	\__	TG "fieldCorner"
	\__	TG "fieldCorner"
	\__	TG "fieldCorner"
	\__	TG "fieldCorner"
	\__	...
\__	TG "f26" --- userAttribute "fieldNum" [integer] ==> "26" (<Attribute name="fieldNum" type="integer" value="26" />)
	\__	TG "fieldCorner"
	\__	TG "fieldCorner"
	\__	TG "fieldCorner"
	\__	...
]]


--Init
CourseplayFields = {};
CourseplayFields.modName = g_currentModName;
CourseplayFields.modDir = g_currentModDirectory;
CourseplayFields.version = "0.3.1";
CourseplayFields.author = "Jakob Tischler";
local CourseplayFields_mt = Class(CourseplayFields, Object);

function onCreateCourseplayFields(self, id)
	print("### CourseplayFields v" .. CourseplayFields.version .. " by " .. CourseplayFields.author .. " initialized");
	local object = CourseplayFields:new(g_server ~= nil, g_client ~= nil);
	if object:load(id) then
		g_currentMission:addOnCreateLoadedObject(object);
		object:register(true);
	else
		object:delete();
	end;
end; --END onCreate()

function CourseplayFields:new(isServer, isClient, customMt)
	local mt = Utils.getNoNil(customMt, CourseplayFields_mt);
	local self = Object:new(isServer, isClient, mt);
	self.CourseplayFieldsDirtyFlag = self:getNextDirtyFlag();
	self.className = "CourseplayFields";
	return self;
end; --END new()

function CourseplayFields:load(id)
	--self.nodeId = id;

	self.numberOfFields = getNumOfChildren(id);
	self.highestFieldNumber = 0;
	self.fieldDefs = {};
	self.pointDistance = 5;

	for i=1,self.numberOfFields do
		local curFieldDef = getChildAt(id, i-1);
		local fieldDef = {};
		fieldDef.rootNode = curFieldDef;
		
		local fieldNum = getName(fieldDef.rootNode);
		fieldNum = string.sub(fieldNum, 2);
		fieldDef.fieldNumber = tonumber(Utils.getNoNil(getUserAttribute(curFieldDef, "fieldNum"), tonumber(fieldNum)));
		--print("### 79 CourseplayFields: current field's number = " .. tostring(fieldDef.fieldNumber));

		fieldDef.cornerPointsDefault = {};
		fieldDef.numberOfCornerPoints = getNumOfChildren(curFieldDef);
		for c=1,fieldDef.numberOfCornerPoints do
			local curCornerPoint = getChildAt(curFieldDef, c-1);
			local pointDef = {
				pointIdx = c;
			};
			pointDef.cx, _, pointDef.cz = getWorldTranslation(curCornerPoint)
			table.insert(fieldDef.cornerPointsDefault, pointDef);
		end;

		fieldDef.edgePointsCalculated = CourseplayFields:getFieldEdge(fieldDef.cornerPointsDefault, self.pointDistance);
		local numCalculatedPoints = table.getn(fieldDef.edgePointsCalculated) - fieldDef.numberOfCornerPoints;

		self.fieldDefs[fieldDef.fieldNumber] = fieldDef;
		if fieldDef.fieldNumber > self.highestFieldNumber then
			self.highestFieldNumber = fieldDef.fieldNumber;
		end;
		print(string.format("\\__ calculated field edge path for field %d (added %d to default %d points)", fieldDef.fieldNumber, numCalculatedPoints, fieldDef.numberOfCornerPoints));
	end;

	CourseplayFields.fieldDefs = self.fieldDefs;
	CourseplayFields.numberOfFields = self.numberOfFields;
	CourseplayFields.highestFieldNumber = self.highestFieldNumber;

	if courseplay ~= nil then
		courseplay.fields = CourseplayFields;
	else
		print("Error: CourseplayFields loaded outside of Courseplay environment.");
	end;

	--print(self:tableShow(CourseplayFields.fieldDefs, "### CourseplayFields.fieldDefs"));

	return true;
end; --END load()

function CourseplayFields:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)
	courseplay.fields = nil;
	self.fieldDefs = nil;
	
end; --END delete()

function CourseplayFields:readStream(streamId, connection)
	CourseplayFields:superClass().readStream(self, streamId, connection)
	if connection:getIsServer() then
		--
	end;
end; --END readStream()

function CourseplayFields:writeStream(streamId, connection)
	CourseplayFields:superClass().readStream(self, streamId, connection)
	if not connection:getIsServer() then
		--
	end;
end; --END writeStream()

function CourseplayFields:readUpdateStream(streamId, timestamp, connection)
	CourseplayFields:superClass().readUpdateStream(self, streamId, timestamp, connection)
	if connection:getIsServer() then
		--
	end
end; --END readUpdateStream()

function CourseplayFields:writeUpdateStream(streamId, connection, dirtyMask)
	CourseplayFields:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		--
	end
end; --END writeUpdateStream()


-- ======================================================================================


function CourseplayFields:getFieldEdge(defaultPoints, pointDistance)
	local extra = 90;
	local pointsAr = {};
	local numDefaultPoints = table.getn(defaultPoints);

	for idx,curPoint in pairs(defaultPoints) do
		local nextPoint = defaultPoints[idx+1];
		if idx == numDefaultPoints then
			nextPoint = defaultPoints[1];
		end;

		table.insert(pointsAr, curPoint);

		local pointsNeeded = math.floor(CourseplayFields:distance(curPoint, nextPoint) / pointDistance);
		if pointsNeeded > 0 then
			--@source: http://math.stackexchange.com/questions/143932/calculate-point-given-x-y-angle-and-distance
			local angle = CourseplayFields:calcAngle(curPoint, nextPoint);
			for i=1,pointsNeeded do
				local newPoint = {
					cx = curPoint.cx + ((pointDistance * i) * math.cos(angle)),
					cz = curPoint.cz + ((pointDistance * i) * math.sin(angle))
				};
				--print(string.format("\\_ newPoint %d: x=%.2f,z=%.2f", i, newPoint.x, newPoint.z));
				table.insert(pointsAr, newPoint);
			end;
		end;
	end;

	return pointsAr;
end; --END getFieldEdge()

function CourseplayFields:distance(point1, point2)
	local xs = math.pow(point2.cx - point1.cx, 2);
	local zs = math.pow(point2.cz - point1.cz, 2);

	return math.sqrt(xs + zs);
end; --END distance()

function CourseplayFields:calcAngle( point1, point2)
	return math.atan2(point2.cz-point1.cz, point2.cx-point1.cx);
end; --END calcAngle()

function CourseplayFields:loadFromAttributesAndNodes(xmlFile, key)
	return true;
end; --END loadFromAttributesAndNodes()

function CourseplayFields:getSaveAttributesAndNodes(nodeIdent)
	--return attributes, nodes
end; --END getSaveAttributesAndNodes()

function CourseplayFields:mouseEvent(posX, posY, isDown, isUp, button)
end;

function CourseplayFields:keyEvent(unicode, sym, modifier, isDown)
end;

function CourseplayFields:update(dt)
end; --END update()

function CourseplayFields:updateTick(dt)	
	if self.isServer then
	end
end; --END updateTick()

function CourseplayFields:draw()
end; --END draw()

function CourseplayFields:getShowInfo()
	if (g_currentMission.controlPlayer and self.playerInRange) then
		return true;
	end;
	return false;
end; --END getShowInfo()

function CourseplayFields:tableShow(t, name, indent)
	local cart -- a container
	local autoref -- for bsh references

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
						.. " (bsh reference)\n"
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
						--addtocart(v, fname, indent .. "   ", saved, field)
						addtocart(v, fname, indent .. "\t", saved, field)
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
