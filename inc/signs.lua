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

-- Load Lines for Hud
function courseplay:HudPage(self)
	local Page = self.showHudInfoBase
 	local i = 0
 --local c = 1
	 setTextBold(false)
	for c=1, 2, 1 do
		for v,name in pairs(self.hudpage[Page][c]) do
			if c == 1 then
				local yspace = 0.383 - (i * 0.021)
				renderText(0.763, yspace, 0.021, name);
	        elseif c == 2 then
				local yspace = 0.383 - (i * 0.021)
				renderText(0.87, yspace, 0.021, name);
			end
			i = i + 1
		end
		i = 0
	end
end