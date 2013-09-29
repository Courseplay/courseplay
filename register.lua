--COURSEPLAY FIELDS
local cpfPath = g_currentModDirectory .. "CourseplayFields.lua";
if fileExists(cpfPath) then
	source(cpfPath);
else
	print("Error: " .. cpfPath .. " could not be loaded!");
end;


--COURSEPLAY
SpecializationUtil.registerSpecialization("courseplay", "courseplay", g_currentModDirectory .. "courseplay.lua")
SpecializationUtil.registerSpecialization("autoovercharge", "AutoOvercharge", g_currentModDirectory .. "AutoOvercharge.lua")
SpecializationUtil.registerSpecialization("perard", "perard", g_currentModDirectory .. "AutoOvercharge.lua")

-- adding courseplay to default vehicles and vehicles that are loaded after courseplay in multiplayer
-- thanks to donner!

function courseplay:register()
	local numInstallationsVehicles = 0;
	local numInstallationsOverchargers = 0;
	for k, v in pairs(VehicleTypeUtil.vehicleTypes) do
		if v ~= nil then
			if v.name == "perard.perard" then
				--courseplay:debug("renew perard interbenne 25", 2);
				for l, w in pairs(v.specializations) do
					v.specializations[l] = nil
				end;

				if not SpecializationUtil.hasSpecialization(Fillable, v.specializations) then
					table.insert(v.specializations, SpecializationUtil.getSpecialization("fillable"));
				end;
				if not SpecializationUtil.hasSpecialization(Attachable, v.specializations) then
					table.insert(v.specializations, SpecializationUtil.getSpecialization("attachable"));
				end;
				if not SpecializationUtil.hasSpecialization(Trailer, v.specializations) then
					table.insert(v.specializations, SpecializationUtil.getSpecialization("trailer"));
				end;
				if not SpecializationUtil.hasSpecialization(perard, v.specializations) then
					table.insert(v.specializations, SpecializationUtil.getSpecialization("perard"));
				end;
			else
				for a = 1, table.maxn(v.specializations) do
					local s = v.specializations[a];
					if s ~= nil then
						if s == SpecializationUtil.getSpecialization("steerable") then
							if not SpecializationUtil.hasSpecialization(courseplay, v.specializations) then
								--courseplay:debug("adding courseplay to:"..tostring(v.name), 3);
								table.insert(v.specializations, SpecializationUtil.getSpecialization("courseplay"));
								numInstallationsVehicles = numInstallationsVehicles + 1;
							end
						end;
						if s == SpecializationUtil.getSpecialization("fillable") then
							--if not SpecializationUtil.hasSpecialization(autoovercharge, v.specializations) then
							if not SpecializationUtil.hasSpecialization(AutoOvercharge, v.specializations) then
								--courseplay:debug("adding autoovercharge to:"..tostring(v.name), 3);
								table.insert(v.specializations, SpecializationUtil.getSpecialization("autoovercharge"));
								numInstallationsOverchargers = numInstallationsOverchargers + 1;
							end
						end
					end;
				end;
			end;
		end;
	end;

	print(string.format("\t### Courseplay: installed into %d vehicles and %d fillables", numInstallationsVehicles, numInstallationsOverchargers));
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

--SEARCH AND SET ATTACHABLE'S self.name IF NOT EXISTING
function courseplay:setAttachablesName(xmlFile)
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
	--print("	regst: CPloading: "..tostring(self.name))
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
	]]
end;
Attachable.load = Utils.appendedFunction(Attachable.load, courseplay.setAttachablesName);

courseplay:setLocales();
courseplay:register();
