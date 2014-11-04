--COURSEPLAY
SpecializationUtil.registerSpecialization('courseplay', 'courseplay', g_currentModDirectory .. 'courseplay.lua');
if courseplay.houstonWeGotAProblem then
	return;
end;

local steerableSpec = SpecializationUtil.getSpecialization('steerable');
local courseplaySpec = SpecializationUtil.getSpecialization('courseplay');
local numInstallationsVehicles = 0;

function courseplay:register()
	for typeName,vehicleType in pairs(VehicleTypeUtil.vehicleTypes) do
		if vehicleType then
			for i,spec in pairs(vehicleType.specializations) do
				if spec and spec == steerableSpec and not SpecializationUtil.hasSpecialization(courseplay, vehicleType.specializations) then
					-- print(('\tadding Courseplay to %q'):format(tostring(vehicleType.name)));
					table.insert(vehicleType.specializations, courseplaySpec);
					vehicleType.hasCourseplaySpec = true;
					vehicleType.hasSteerableSpec = true;
					numInstallationsVehicles = numInstallationsVehicles + 1;
					break;
				end;
			end;
		end;
	end;
end;

-- if there are any vehicles loaded *after* Courseplay, install the spec into them
local postRegister = function(typeName, className, filename, specializationNames, customEnvironment)
	local vehicleType = VehicleTypeUtil.vehicleTypes[typeName];
	if vehicleType and vehicleType.specializations and not vehicleType.hasCourseplaySpec and Utils.hasListElement(specializationNames, 'steerable') then
		table.insert(vehicleType.specializations, courseplaySpec);
		vehicleType.hasCourseplaySpec = true;
		vehicleType.hasSteerableSpec = true;
		numInstallationsVehicles = numInstallationsVehicles + 1;
	end;
end;
VehicleTypeUtil.registerVehicleType = Utils.appendedFunction(VehicleTypeUtil.registerVehicleType, postRegister);

function courseplay:attachableLoad(xmlFile)
	if self.cp == nil then self.cp = {}; end;

	--SET SPECIALIZATION VARIABLE
	courseplay:setNameVariable(self);
	courseplay:setCustomSpecVariables(self);


	--SEARCH AND SET OBJECT'S self.name IF NOT EXISTING
	if self.name == nil then
		self.name = courseplay:getObjectName(self, xmlFile);
	end;

	-- ATTACHABLE CHOPPER SPECIAL NODE
	if self.cp.isPoettingerMex6 or self.cp.isPoettingerMexOK then
		self.cp.fixedRootNode = createTransformGroup('courseplayFixedRootNode');
		link(self.rootNode, self.cp.fixedRootNode);
		setTranslation(self.cp.fixedRootNode, 0, 0, 0);
		setRotation(self.cp.fixedRootNode, 0, math.rad(180), 0);
	end;

end;
Attachable.load = Utils.appendedFunction(Attachable.load, courseplay.attachableLoad);

function courseplay:attachableDelete()
	if self.cp ~= nil then
	end;
end;
Attachable.delete = Utils.prependedFunction(Attachable.delete, courseplay.attachableDelete);

function courseplay.vehicleLoadFinished(self)
	if self.cp == nil then self.cp = {}; end;

	-- XML FILE NAME VARIABLE
	if self.cp.xmlFileName == nil then
		-- local xmlFileName = Utils.splitString('/', self.configFileName);
		-- self.cp.xmlFileName = xmlFileName[#xmlFileName];
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;

	--[[
	if self.cp.typeNameSingle == nil then
		self.cp.typeNameSingle = Utils.splitString('.', self.typeName);
		self.cp.typeNameSingle = self.cp.typeNameSingle[#self.cp.typeNameSingle];
	end;
	]]

end;
Vehicle.loadFinished = Utils.prependedFunction(Vehicle.loadFinished, courseplay.vehicleLoadFinished);
-- NOTE: using loadFinished() instead of load() so any other mod that overwrites Vehicle.load() doesn't interfere

function courseplay:vehicleDelete()
	if self.cp ~= nil then
		-- Remove created nodes
		if self.cp.notesToDelete and #self.cp.notesToDelete > 0 then
			for _, nodeId in ipairs(self.cp.notesToDelete) do
				if nodeId and nodeId ~= 0 then
					delete(nodeId);
				end;
			end;
		end;

	end;
end;
Vehicle.delete = Utils.prependedFunction(Vehicle.delete, courseplay.vehicleDelete);

function courseplay:foldableLoad(xmlFile)
	if self.cp == nil then self.cp = {}; end;

	--FOLDING PARTS STARTMOVEDIRECTION
	local startMoveDir = getXMLInt(xmlFile, 'vehicle.foldingParts#startMoveDirection');
	if startMoveDir == nil then
		local singleDir;
		local i = 0;
		while true do -- go through single foldingPart entries
			local key = string.format('vehicle.foldingParts.foldingPart(%d)', i);
			if not hasXMLProperty(xmlFile, key) then break; end;
			local dir = getXMLInt(xmlFile, key .. '#startMoveDirection');
			if dir then
				if singleDir == nil then --first foldingPart -> set singleDir
					singleDir = dir;
				elseif dir ~= singleDir then -- two or more foldingParts have non-matching startMoveDirections --> not valid
					singleDir = nil;
					break;
				elseif dir == singleDir then -- --> valid
				end;
			end;
			i = i + 1;
		end;
		if singleDir then -- startMoveDirection found in single foldingPart
			startMoveDir = singleDir;
		end;
	end;

	self.cp.foldingPartsStartMoveDirection = Utils.getNoNil(startMoveDir, 0);
end;
Foldable.load = Utils.appendedFunction(Foldable.load, courseplay.foldableLoad);

courseplay.locales = courseplay.utils.table.copy(g_i18n.texts, true);
courseplay:register();
print(string.format('### Courseplay: installed into %d vehicles', numInstallationsVehicles));

