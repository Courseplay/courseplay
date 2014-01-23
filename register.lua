--COURSEPLAY
SpecializationUtil.registerSpecialization("courseplay", "courseplay", g_currentModDirectory .. "courseplay.lua")

function courseplay:register()
	local numInstallationsVehicles = 0;
	for k,vehicleType in pairs(VehicleTypeUtil.vehicleTypes) do
		if vehicleType ~= nil then
			for a=1, table.maxn(vehicleType.specializations) do
				local spec = vehicleType.specializations[a];
				if spec ~= nil and spec == SpecializationUtil.getSpecialization("steerable") then
					if not SpecializationUtil.hasSpecialization(courseplay, vehicleType.specializations) then
						--courseplay:debug("adding courseplay to:"..tostring(vehicleType.name), 3);
						table.insert(vehicleType.specializations, SpecializationUtil.getSpecialization("courseplay"));
						numInstallationsVehicles = numInstallationsVehicles + 1;
					end
				end;
			end;
		end;
	end;

	print(string.format("### Courseplay: installed into %d vehicles", numInstallationsVehicles));
end

function courseplay:setLocales()
	courseplay.locales = {};
	local i=0;
	while true do
		local key = string.format("modDesc.l10n.text(%d)", i);
		if not hasXMLProperty(courseplay.modDescFile, key) then 
			break;
		end;
		local textName = getXMLString(courseplay.modDescFile, key .. "#name");
		if textName ~= nil and textName ~= "" then
			if not g_i18n:hasText(textName) then
				g_i18n:setText(textName, textName);
			end;
			courseplay.locales[textName] = g_i18n:getText(textName);
			--print(string.format("courseplay.locales[%s] (#%d) = %s", textName, i, courseplay.locales[textName]));
			i = i + 1;
		else
			break;
		end;
	end;
	delete(courseplay.modDescFile);
	
	--print("\t### Courseplay: setLocales() finished");
end;

function courseplay:attachableLoad(xmlFile)
	if self.cp == nil then self.cp = {}; end;

	--SEARCH AND SET ATTACHABLE'S self.name IF NOT EXISTING
	if self.name == nil then
		local nameSearch = { "vehicle.name." .. g_languageShort, "vehicle.name.en", "vehicle.name", "vehicle#type" };
		for i,xmlPath in pairs(nameSearch) do
			self.name = getXMLString(xmlFile, xmlPath);
			if self.name ~= nil then 
				--print(self.name .. ": self.name was nil, got new name from " .. xmlPath .. " in XML");
				break; 
			end;
		end;
		if self.name == nil then 
			self.name = g_i18n:getText("UNKNOWN");
			--print(tostring(self.configFileName) .. ": self.name was nil, new name is " .. self.name);
		end;
	end;

	--SET SPECIALIZATION VARIABLE
	--Default specializations -- not needed as they're set in setNameVariable()
	--Custom (mod) specializations
	self.cp.hasSpecializationAugerWagon = courseplay:hasSpecialization(self, "AugerWagon");
	self.cp.hasSpecializationOverloader = courseplay:hasSpecialization(self, "overloader");
	self.cp.hasSpecializationHaweSUW = courseplay:hasSpecialization(self, "Hawe_SUW");
	self.cp.hasSpecializationAgrolinerTUW20 = courseplay:hasSpecialization(self, "AgrolinerTUW20");
	self.cp.hasSpecializationOvercharge = courseplay:hasSpecialization(self, "Overcharge");
	self.cp.hasSpecializationBigBear = courseplay:hasSpecialization(self, "bigBear");
	self.cp.hasSpecializationSowingMachineWithTank = courseplay:hasSpecialization(self, "SowingMachineWithTank");
	self.cp.hasSpecializationDrivingLine = courseplay:hasSpecialization(self, "DrivingLine");
	self.cp.hasSpecializationHoseRef = courseplay:hasSpecialization(self, "HoseRef");

	courseplay:setNameVariable(self);


	--ADD ATTACHABLES TO GLOBAL REFERENCE LIST
	if courseplay.thirdParty.EifokLiquidManure == nil then courseplay.thirdParty.EifokLiquidManure = {}; end;
	if courseplay.thirdParty.EifokLiquidManure.dockingStations == nil then courseplay.thirdParty.EifokLiquidManure.dockingStations = {}; end;
	if courseplay.thirdParty.EifokLiquidManure.hoseRefVehicles == nil then courseplay.thirdParty.EifokLiquidManure.hoseRefVehicles = {}; end;

	--Zunhammer Docking Station (zunhammerDocking.i3d / ManureDocking.lua) [Eifok Team]
	if Utils.endsWith(self.typeName, "zhAndock") and Utils.endsWith(self.configFileName, "zunhammerDocking.xml") then
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

	--Zunhammer Hose (zunhammerHose.i3d / Hose.lua) [Eifok Team]
	if Utils.endsWith(self.typeName, "zhHose") or Utils.endsWith(self.configFileName, "zunhammerHose.xml") then
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
	-- print(string.format('%s foldableLoad(): foldingParts#startMoveDirection=%s', nameNum(self), tostring(startMoveDir)));
	if startMoveDir == nil then
		local singleDir;
		local i = 0;
		while true do -- go through single foldingPart entries
			local key = string.format('vehicle.foldingParts.foldingPart(%d)', i);
			if not hasXMLProperty(xmlFile, key) then break; end;
			local dir = getXMLInt(xmlFile, key .. '#startMoveDirection');
			-- print(string.format('\tfoldingPart(%d)#startMoveDirection=%s', i, tostring(dir)));
			if dir then
				if singleDir == nil then --first foldingPart -> set singleDir
					-- print(string.format('\t\tsingleDir==nil -> set as %s', tostring(dir)));
					singleDir = dir;
				elseif dir ~= singleDir then -- two or more foldingParts have non-matching startMoveDirections --> not valid
					-- print(string.format('\t\tdir (%d) ~= singleDir (%d) -> invalid, set nil, break', dir, singleDir));
					singleDir = nil;
					break;
				elseif dir == singleDir then -- two or more foldingParts have non-matching startMoveDirections --> not valid
					-- print(string.format('\t\tdir (%d) == singleDir (%d) -> valid, continue', dir, singleDir));
				end;
			end;
			i = i + 1;
		end;
		if singleDir then -- startMoveDirection found in single foldingPart
			-- print(string.format('\tstartMoveDir=nil, singleDir=%s -> set startMoveDir as singleDir', tostring(singleDir)));
			startMoveDir = singleDir;
		end;
	end;

	self.cp.foldingPartsStartMoveDirection = Utils.getNoNil(startMoveDir, 0);
	-- print(string.format('%s foldableLoad(): foldingPartsStartMoveDirection=%s', nameNum(self), tostring(self.cp.foldingPartsStartMoveDirection)));
end;
Foldable.load = Utils.appendedFunction(Foldable.load, courseplay.foldableLoad);

courseplay:setLocales();
courseplay:register();

