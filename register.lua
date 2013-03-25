SpecializationUtil.registerSpecialization("courseplay", "courseplay", g_modsDirectory .. "/ZZZ_courseplay/courseplay.lua")
SpecializationUtil.registerSpecialization("autoovercharge", "AutoOvercharge", g_modsDirectory .. "/ZZZ_courseplay/AutoOvercharge.lua")
SpecializationUtil.registerSpecialization("perard", "perard", g_modsDirectory .. "/ZZZ_courseplay/AutoOvercharge.lua")


-- adding courseplay to default vehicles and vehicles that are loaded after courseplay in multiplayer
-- thanks to donner!

function register_courseplay()
	for k, v in pairs(VehicleTypeUtil.vehicleTypes) do
		if v ~= nil then
			if v.name == "perard.perard" then
				--courseplay:debug("renew perard interbenne 25", 2);
				for l, w in pairs(v.specializations) do
					v.specializations[l] = nil
				end
				table.insert(v.specializations, SpecializationUtil.getSpecialization("fillable"));
				table.insert(v.specializations, SpecializationUtil.getSpecialization("attachable"));
				table.insert(v.specializations, SpecializationUtil.getSpecialization("trailer"));
				table.insert(v.specializations, SpecializationUtil.getSpecialization("perard"));
			else
				for a = 1, table.maxn(v.specializations) do
					local s = v.specializations[a];
					if s ~= nil then
						if s == SpecializationUtil.getSpecialization("steerable") then
							if not SpecializationUtil.hasSpecialization(courseplay, v.specializations) then
								--courseplay:debug("adding courseplay to:"..tostring(v.name), 3);
								table.insert(v.specializations, SpecializationUtil.getSpecialization("courseplay"));
							end
						end;
						if s == SpecializationUtil.getSpecialization("fillable") then
							if not SpecializationUtil.hasSpecialization(autoovercharge, v.specializations) then
								--courseplay:debug("adding autoovercharge to:"..tostring(v.name), 3);
								table.insert(v.specializations, SpecializationUtil.getSpecialization("autoovercharge"));
							end
						end
					end;
				end;
			end;
		end;
	end;
end


-- dirty workaround for localization - don't try this at home!
-- get all l10n > text > #name attribues from modDesc.xml, insert them into courseplay.locales
function cp_setLocales()
	courseplay.locales = {};
	if not Utils.endsWith(courseplay_path, "/") then
		courseplay_path = courseplay_path .. "/";
	end;
	local cp_modDesc_file = loadXMLFile("cp_modDesc", courseplay_path .. "modDesc.xml");
	local b=0;
	while true do
		local attr = string.format("modDesc.l10n.text(%d)#name", b);
		local textName = getXMLString(cp_modDesc_file, attr);
		if textName ~= nil then
			if not g_i18n:hasText(textName) then
				g_i18n:setText(textName, textName);
			end;
			courseplay.locales[textName] = g_i18n:getText(textName);
			--print(string.format("courseplay.locales[%s] (#%d) = %s", textName, b, courseplay.locales[textName]));
			b = b + 1;
		else
			break;
		end;
	end;
end;

function cp_setLines()
	courseplay.hud = {
		infoBasePosX = 0.433;
		infoBasePosY = 0.002;
		infoBaseWidth = 0.512; --try: 512/1920
		infoBaseHeight = 0.512; --try: 512/1080
		linesPosY = {};
		linesBottomPosY = {};
		linesButtonPosY = {};
		numLines = 6;
		lineHeight = 0.021;
		hoverColor = {
			r =  32/255;
			g = 168/255;
			b = 219/255;
			a = 1;
		};
	};
	for l=1,courseplay.hud.numLines do
		if l == 1 then
			courseplay.hud.linesPosY[l] = courseplay.hud.infoBasePosY + 0.210;
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.infoBasePosY + 0.077;
		else
			courseplay.hud.linesPosY[l] = courseplay.hud.linesPosY[1] - ((l-1) * courseplay.hud.lineHeight);
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.linesBottomPosY[1] - ((l-1) * courseplay.hud.lineHeight);
		end;
		courseplay.hud.linesButtonPosY[l] = courseplay.hud.linesPosY[l] + 0.0020; --0.0045
	end;
	
end;

cp_setLines();
cp_setLocales();
register_courseplay();

