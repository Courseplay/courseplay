--[[COURSEPLAY FIELDS
local cpfPath = g_currentModDirectory .. "CourseplayFields.lua";
if fileExists(cpfPath) then
	source(cpfPath);
else
	print("Error: " .. cpfPath .. " could not be loaded!");
end;
]]


--COURSEPLAY
SpecializationUtil.registerSpecialization("courseplay", "courseplay", g_currentModDirectory .. "courseplay.lua")

-- adding courseplay to default vehicles and vehicles that are loaded after courseplay in multiplayer
-- thanks to donner!

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

	print(string.format("\t### Courseplay: installed into %d vehicles", numInstallationsVehicles));
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

	if self.cp == nil then
		self.cp = {}
	end
	--SET SPECIALIZATION VARIABLE
	--Default specializations
	self.cp.hasSpecializationTrailer = SpecializationUtil.hasSpecialization(Trailer, self.specializations)
	self.cp.hasSpecializationBaler = SpecializationUtil.hasSpecialization(Baler, self.specializations)
	self.cp.hasSpecializationBaleLoader = SpecializationUtil.hasSpecialization(baleLoader, self.specializations) or SpecializationUtil.hasSpecialization(BaleLoader, self.specializations)
	self.cp.hasSpecializationPlough = SpecializationUtil.hasSpecialization(Plough, self.specializations)
	self.cp.hasSpecializationSowingMachine =(SpecializationUtil.hasSpecialization(sowingMachine, self.specializations) or SpecializationUtil.hasSpecialization(SowingMachine, self.specializations))
	self.cp.hasSpecializationCombine = SpecializationUtil.hasSpecialization(Combine, self.specializations)
	self.cp.hasSpecializationSprayer = SpecializationUtil.hasSpecialization(Sprayer, self.specializations) or SpecializationUtil.hasSpecialization(sprayer, self.specializations)
	self.cp.hasSpecializationFoldable = SpecializationUtil.hasSpecialization(Foldable, self.specializations) or SpecializationUtil.hasSpecialization(foldable, self.specializations)
	self.cp.hasSpecializationMower = SpecializationUtil.hasSpecialization(Mower, self.specializations)
	self.cp.hasSpecializationMixerWagon = SpecializationUtil.hasSpecialization(MixerWagon, self.specializations)
	self.cp.hasSpecializationCylindered = SpecializationUtil.hasSpecialization(Cylindered, self.specializations)
	self.cp.hasSpecializationAnimatedVehicle =  SpecializationUtil.hasSpecialization(AnimatedVehicle, self.specializations)
	self.cp.hasSpecializationShovel = SpecializationUtil.hasSpecialization(Shovel, self.specializations)
	self.cp.hasSpecializationTedder = SpecializationUtil.hasSpecialization(Tedder, self.specializations) 
	self.cp.hasSpecializationWindrower = SpecializationUtil.hasSpecialization(Windrower, self.specializations) 
	self.cp.hasSpecializationCultivator = SpecializationUtil.hasSpecialization(Cultivator, self.specializations)
	self.cp.hasSpecializationFruitPreparer = SpecializationUtil.hasSpecialization(FruitPreparer, self.specializations) or SpecializationUtil.hasSpecialization(fruitPreparer, self.specializations)

	--Custom (mod) specializations
	self.cp.hasSpecializationAugerWagon = courseplay:hasSpecialization(self, "AugerWagon");
	self.cp.hasSpecializationOverloader = courseplay:hasSpecialization(self, "overloader");
	self.cp.hasSpecializationHaweSUW = courseplay:hasSpecialization(self, "Hawe_SUW");
	self.cp.hasSpecializationOverloader = courseplay:hasSpecialization(self, "overloader");
	self.cp.hasSpecializationAgrolinerTUW20 = courseplay:hasSpecialization(self, "AgrolinerTUW20");
	self.cp.hasSpecializationOvercharge = courseplay:hasSpecialization(self, "Overcharge");
	self.cp.hasSpecializationSowingMachineWithTank = courseplay:hasSpecialization(self, "SowingMachineWithTank");

	--[[ Debugs:
	if self.cp.hasSpecializationFruitPreparer then print("		FruitPreparer")end
	if self.cp.hasSpecializationTedder then print("		Tedder")end
	if self.cp.hasSpecializationWindrower then print("		Windrower")end
	if self.cp.hasSpecializationCultivator then print("		Cultivator")end
	if self.cp.hasSpecializationShovel then print("		Shovel")end
	if self.cp.hasSpecializationAnimatedVehicle then print("		AnimatedVehicle")end
	if self.cp.hasSpecializationCylindered then print("		Cylindered")end
	if self.cp.hasSpecializationMixerWagon then print("		MixerWagon")end
	if self.cp.hasSpecializationMower then print("		Mower")end
	if self.cp.hasSpecializationFoldable then print("		Foldable")end
	if self.cp.hasSpecializationSprayer then print("		Sprayer")end
	if self.cp.hasSpecializationCombine then print("		Combine")end
	if self.cp.hasSpecializationSowingMachine then print("		SowingMachine") end
	if self.cp.hasSpecializationTrailer then print("		Trailer")end
	if self.cp.hasSpecializationBaler then print("		Baler") end
	if self.cp.hasSpecializationBaleLoader then print("		BaleLoader") end
	if self.cp.hasSpecializationPlough then print("		Plough") end
	if self.cp.hasSpecializationAugerWagon then print("\t\tload(): AugerWagon"); end;
	if self.cp.hasSpecializationOverloader then print("\t\tload(): overloader"); end;
	if self.cp.hasSpecializationAgrolinerTUW20 then print("\t\tload(): AgrolinerTUW20"); end;
	if self.cp.hasSpecializationOvercharge then print("\t\tload(): Overcharge"); end;
	--]]


	--ADD ATTACHABLES TO GLOBAL REFERENCE LIST
	--Zunhammer Docking Station (zunhammerDocking.i3d / ManureDocking.lua) [Eifok Team]
	if Utils.endsWith(self.typeName, "zhAndock") and Utils.endsWith(self.configFileName, "zunhammerDocking.xml") then
		if courseplay.thirdParty.EifokLiquidManure == nil then courseplay.thirdParty.EifokLiquidManure = {}; end;
		if courseplay.thirdParty.EifokLiquidManure.dockingStations == nil then courseplay.thirdParty.EifokLiquidManure.dockingStations = {}; end;

		self.cp.isEifokZunhammerDockingStation = true;
		courseplay.thirdParty.EifokLiquidManure.dockingStations[self.rootNode] = self;

	--Kotte Containers (KotteContainer.i3d) [Eifok Team]
	elseif Utils.endsWith(self.typeName, "kotte") and Utils.endsWith(self.configFileName, "kotte.xml") then
		if courseplay.thirdParty.EifokLiquidManure == nil then courseplay.thirdParty.EifokLiquidManure = {}; end;
		if courseplay.thirdParty.EifokLiquidManure.KotteContainers == nil then courseplay.thirdParty.EifokLiquidManure.KotteContainers = {}; end;

		self.cp.isEifokKotteContainer = true;
		courseplay.thirdParty.EifokLiquidManure.KotteContainers[self.rootNode] = self;

	--Kotte Zubringer (KotteZubringer.i3d) [Eifok Team]
	elseif Utils.endsWith(self.typeName, "zubringer") and Utils.endsWith(self.configFileName, "zubringer.xml") then
		if courseplay.thirdParty.EifokLiquidManure == nil then courseplay.thirdParty.EifokLiquidManure = {}; end;
		if courseplay.thirdParty.EifokLiquidManure.KotteZubringers == nil then courseplay.thirdParty.EifokLiquidManure.KotteZubringers = {}; end;

		courseplay.thirdParty.EifokLiquidManure.KotteZubringers[self.rootNode] = self;
	end;
end;
Attachable.load = Utils.appendedFunction(Attachable.load, courseplay.attachableLoad);

function courseplay:attachableDelete()
	if self.cp ~= nil then
		if self.cp.isEifokZunhammerDockingStation then
			courseplay.thirdParty.EifokLiquidManure.dockingStations[self.rootNode] = nil;
		elseif self.cp.isEifokKotteZubringer then
			courseplay.thirdParty.EifokLiquidManure.KotteContainers[self.rootNode] = nil;
		elseif self.cp.isEifokKotteContainer then
			courseplay.thirdParty.EifokLiquidManure.KotteZubringers[self.rootNode] = nil;
		end;
	end;
end;
Attachable.delete = Utils.prependedFunction(Attachable.delete, courseplay.attachableDelete);

function courseplay:vehicleLoad(xmlFile)
	--Zunhammer Hose (zunhammerHose.i3d / Hose.lua) [Eifok Team]
	if Utils.endsWith(self.typeName, "zhHose") or Utils.endsWith(self.configFileName, "zunhammerHose.xml") then
		if self.cp == nil then self.cp = {}; end;
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

courseplay:setLocales();
courseplay:register();

