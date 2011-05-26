SpecializationUtil.registerSpecialization("courseplay", "courseplay", g_modsDirectory.."/aacourseplay/courseplay.lua")

-- adding courseplay to default vehicles and vehicles that are loaded after courseplay in multiplayer
-- thanks to donner!
for k,v in pairs(VehicleTypeUtil.vehicleTypes) do  
  if v~=nil then
    for a=1, table.maxn(v.specializations) do
      local s = v.specializations[a];
      if s ~= nil then
        if s == SpecializationUtil.getSpecialization("steerable") then          
          if not SpecializationUtil.hasSpecialization(courseplay, v.specializations) then
          	print("adding courseplay to:"..tostring(v.name));
            table.insert(v.specializations, SpecializationUtil.getSpecialization("courseplay"));
          end
        end;
      end;
    end;
  end;
end;