function courseplay:find_combines(self)
  -- reseting reachable combines
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
  
  return found_combines
end


-- find combines on the same field (texture)
function courseplay:update_combines(self)
  
  self.reachable_combines = {}
  
  if not self.search_combine and self.saved_combine then
  	table.insert(self.reachable_combines, self.saved_combine)
    return
  end
  
  --print(string.format("combines total: %d ", table.getn(found_combines) ))
  
  local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
  local hx, hy, hz = localToWorld(self.aiTractorDirectionNode, -2, 0, 0)
  local lx, ly, lz = nil, nil, nil
  local terrain = g_currentMission.terrainDetailId	
  
  local found_combines = courseplay:find_combines(self)
    
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
  
  --print(string.format("combines reachable: %d ", table.getn(self.reachable_combines) ))
end


function courseplay:register_at_combine(self, combine)
  local num_allowed_courseplayers = 1
  
  if combine.courseplayers == nil then
    combine.courseplayers = {}
  end
  
  if combine.grainTankCapacity == 0 then
     num_allowed_courseplayers = 2
  end
  
  if table.getn(combine.courseplayers) == num_allowed_courseplayers then
    return false
  end
    
  table.insert(combine.courseplayers, self)
  self.courseplay_position = table.getn(combine.courseplayers)
  self.active_combine = combine  	     
  return true
end


function courseplay:unregister_at_combine(self, combine)
  if self.active_combine == nil or combine == nil then
    return true
  end
  
  courseplay:remove_from_combines_ignore_list(self, combine)
  table.remove(combine.courseplayers, self.courseplay_position)
  
  -- updating positions of tractors
  for k,tractor in pairs(combine.courseplayers) do
    tractor.courseplay_position = k
  end
  
  self.allow_follwing = false
  self.courseplay_position = nil
  self.active_combine = nil  
  self.ai_state = 1
  return true
end


function courseplay:add_to_combines_ignore_list(self, combine)
  if combine.trafficCollisionIgnoreList[self.rootNode] == nil then
    combine.trafficCollisionIgnoreList[self.rootNode] = true
  end
end


function courseplay:remove_from_combines_ignore_list(self, combine)
  if combine == nil then
    return
  end
  if combine.trafficCollisionIgnoreList[self.rootNode] == true then
    combine.trafficCollisionIgnoreList[self.rootNode] = nil
  end
end