--COURSEPLAY
SpecializationUtil.registerSpecialization('courseplay', 'courseplay', g_currentModDirectory .. 'courseplay.lua');

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
	--Default specializations -- not needed as they're set in setNameVariable()
	--Custom (mod) specializations
	self.cp.hasSpecializationAugerWagon 		   = courseplay:hasSpecialization(self, 'AugerWagon');
	self.cp.hasSpecializationOverloader 		   = courseplay:hasSpecialization(self, 'overloader');
	self.cp.hasSpecializationHaweSUW 			   = courseplay:hasSpecialization(self, 'Hawe_SUW');
	self.cp.hasSpecializationAgrolinerTUW20 	   = courseplay:hasSpecialization(self, 'AgrolinerTUW20');
	self.cp.hasSpecializationOvercharge 		   = courseplay:hasSpecialization(self, 'Overcharge');
	self.cp.hasSpecializationBigBear 			   = courseplay:hasSpecialization(self, 'bigBear');
	self.cp.hasSpecializationSowingMachineWithTank = courseplay:hasSpecialization(self, 'SowingMachineWithTank');
	self.cp.hasSpecializationDrivingLine 		   = courseplay:hasSpecialization(self, 'DrivingLine');
	self.cp.hasSpecializationHoseRef 			   = courseplay:hasSpecialization(self, 'HoseRef');

	courseplay:setNameVariable(self);

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

	--ADD ATTACHABLES TO GLOBAL REFERENCE LIST
	if courseplay.thirdParty.EifokLiquidManure == nil then courseplay.thirdParty.EifokLiquidManure = {}; end;
	if courseplay.thirdParty.EifokLiquidManure.dockingStations == nil then courseplay.thirdParty.EifokLiquidManure.dockingStations = {}; end;
	if courseplay.thirdParty.EifokLiquidManure.hoseRefVehicles == nil then courseplay.thirdParty.EifokLiquidManure.hoseRefVehicles = {}; end;

	--Zunhammer Docking Station (zunhammerDocking.i3d / ManureDocking.lua) [Eifok Team]
	if Utils.endsWith(self.typeName, 'zhAndock') and self.cp.xmlFileName == 'zunhammerDocking.xml' then
		self.cp.isEifokZunhammerDockingStation = true;
		courseplay.thirdParty.EifokLiquidManure.dockingStations[self.rootNode] = self;

	--HoseRef [Eifok Team]
	elseif self.cp.hasSpecializationHoseRef then
		self.cp.hasHoseRef = true;
		courseplay.thirdParty.EifokLiquidManure.hoseRefVehicles[self.rootNode] = self;
	end;
end;
Attachable.load = Utils.appendedFunction(Attachable.load, courseplay.attachableLoad);

function courseplay:attachableDelete()
	if self.cp ~= nil then
		if self.cp.isEifokZunhammerDockingStation then
			courseplay.thirdParty.EifokLiquidManure.dockingStations[self.rootNode] = nil;
		elseif self.cp.hasSpecializationHoseRef then
			courseplay.thirdParty.EifokLiquidManure.hoseRefVehicles[self.rootNode] = nil;
		end;
	end;
end;
Attachable.delete = Utils.prependedFunction(Attachable.delete, courseplay.attachableDelete);

function courseplay:vehicleLoad(xmlFile)
	if self.cp == nil then self.cp = {}; end;

	-- XML FILE NAME VARIABLE
	if self.cp.xmlFileName == nil then
		local xmlFileName = Utils.splitString('/', self.configFileName);
		self.cp.xmlFileName = xmlFileName[#xmlFileName];
	end;

	--[[
	if self.cp.typeNameSingle == nil then
		local typeNameSingle = Utils.splitString('.', self.typeName);
		self.cp.typeNameSingle = typeNameSingle[#typeNameSingle];
	end;
	]]

	--Zunhammer Hose (zunhammerHose.i3d / Hose.lua) [Eifok Team]
	if self.cp.xmlFileName == 'zunhammerHose.xml' or Utils.endsWith(self.typeName, 'zhHose') then
		if courseplay.thirdParty.EifokLiquidManure == nil then courseplay.thirdParty.EifokLiquidManure = {}; end;
		if courseplay.thirdParty.EifokLiquidManure.hoses == nil then courseplay.thirdParty.EifokLiquidManure.hoses = {}; end;

		self.cp.isEifokZunhammerHose = true;
		table.insert(courseplay.thirdParty.EifokLiquidManure.hoses, self);
		--courseplay.thirdParty.EifokLiquidManure.hoses[self.msh] = self;
	end;
end;
Vehicle.load = Utils.appendedFunction(Vehicle.load, courseplay.vehicleLoad);

function courseplay:vehicleDelete()
	if self.cp ~= nil and self.cp.isEifokZunhammerHose then
		for i,hose in pairs(courseplay.thirdParty.EifokLiquidManure.hoses) do
			if hose.msh == self.msh then
				table.remove(courseplay.thirdParty.EifokLiquidManure.hoses, i);
				break;
			end;
		end;
		--courseplay.thirdParty.EifokLiquidManure.hoses[self.msh] = nil;
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

