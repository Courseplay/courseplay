-- adds a visual waypoint to the map
function courseplay:addsign(self, x, y, z)  
    local height = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)
    local root = self.sign
    local sign = clone(root, true)
    setTranslation(sign, x, height + 1, z)
    setVisibility(sign, true)
    table.insert(self.signs, sign)
	return(sign)
end

-- should the signs be visible?
function courseplay:sign_visibility(self, visibilty)
  for k,v in pairs(self.signs) do    
      setVisibility(v, visibilty)	
  end
end