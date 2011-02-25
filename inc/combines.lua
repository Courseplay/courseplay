

-- find combines on the same field (texture)
function courseplay:update_combines(self)
  print("updating combines")
  
  -- reseting reachable combines
  self.reachable_combines = {}
  
  local found_combines = {}
  -- go through all vehicles and find filter all combines
  local all_vehicles = g_currentMission.vehicles      
  for k,vehicle in pairs(all_vehicles) do
  	-- combines should have this trigger
  	-- trying to identify combines
  	if vehicle.onCutterTrafficCollisionTrigger ~= nil then
      table.insert(found_combines, vehicle)
  	end     
  end
  
  print(string.format("combines total: %d ", table.getn(found_combines) ))
  
  local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
  local hx, hy, hz = localToWorld(self.aiTractorDirectionNode, -2, 0, 0)
  local lx, ly, lz = nil, nil, nil
  local terrain = g_currentMission.terrainDetailId	
    
  -- go throuh found
  for k,combine in pairs(found_combines) do
  	 lx, ly, lz = getWorldTranslation(combine.rootNode)
  	 local dlx, dly, dlz = worldToLocal(self.aiTractorDirectionNode, lx, y, lz)
  	 local dnx = dlz * -1
  	 local dnz = dlx
  	 local angle = math.atan(dnz / dnx)
  	 dnx = math.cos(angle) * -2
  	 dnz = math.sin(angle) * -2
  	 hx, hy, hz = localToWorld(self.aiTractorDirectionNode, dnx, 0, dnz)
  	 local area1, area2 = Utils.getDensity(terrain, 2, x, z, lx, lz, hx, hz)
  	 area1 = area1 + Utils.getDensity(terrain, 0, x, z, lx, lz, hx, hz)
  	 area1 = area1 + Utils.getDensity(terrain, 1, x, z, lx, lz, hx, hz)
  	 if area2 * 0.999 <= area1 then
  	 	table.insert(self.reachable_combines, combine)
  	 end
  end
  
  print(string.format("combines reachable: %d ", table.getn(self.reachable_combines) ))
end