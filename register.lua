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

courseplay:setLocales();
courseplay:register();
