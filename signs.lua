-- adds a visual waypoint to the map
function courseplay:addsign(self, x, y, z, forced_sign, always_visible)  
    local height = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)
    local root = nil
    if forced_sign ~= nil then
      root = forced_sign
    else
      root = self.sign
    end        
    
    local sign = clone(root, true)

    setTranslation(sign, x, height + 5, z)
    setVisibility(sign, true) 
    local sign_data = {sign = sign, always_visible = always_visible}
    table.insert(self.signs, sign_data)
	return(sign)
end

-- should the signs be visible?
function courseplay:sign_visibility(self, visibilty, force_remove)
  for k,v in pairs(self.signs) do   
      local vis = visibilty
      if v.always_visible then
        vis = true
      end      
      if force_remove then
        vis = false
      end
      setVisibility(v.sign, vis)
  end
end