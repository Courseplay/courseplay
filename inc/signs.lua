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
function courseplay:load_Hud(self)
	self.hudpage[1] = {}
	table.insert(self.hudpage[1],g_i18n:getText("CoursePlayRound").."  " .. InputBinding.getKeyNamesOfDigitalAction(InputBinding.CourseMode))
	table.insert(self.hudpage[1],("self.ai_state").."  " .. self.ai_state )
	table.insert(self.hudpage[1],("Start bei %").."  " .. self.required_fill_level_for_follow )
	table.insert(self.hudpage[1],("Turn Radius").."  " .. self.turn_radius )
	table.insert(self.hudpage[1],("Chopper Offset").."  " .. self.combine_offset )
	table.insert(self.hudpage[1],("Chopper Offset").."  " .. self.combine_offset )


	self.hudpage[2] = {}
	table.insert(self.hudpage[2],("Chopper Offset").."  " .. self.combine_offset )
	table.insert(self.hudpage[2],("self.ai_state").."  " .. self.ai_state )
	table.insert(self.hudpage[2],("Start bei %").."  " .. self.required_fill_level_for_follow )
	table.insert(self.hudpage[2],("Turn Radius").."  " .. self.turn_radius )
	table.insert(self.hudpage[2],("Chopper Offset").."  " .. self.combine_offset )
	table.insert(self.hudpage[2],("Chopper Offset").."  " .. self.combine_offset )

	self.hudpage[3] = {}
	table.insert(self.hudpage[3],("Chopper Offset").."  " .. self.combine_offset )
	table.insert(self.hudpage[3],("self.ai_state").."  " .. self.ai_state )
	table.insert(self.hudpage[3],("Start bei %").."  " .. self.required_fill_level_for_follow )
	table.insert(self.hudpage[3],("Turn Radius").."  " .. self.turn_radius )
	table.insert(self.hudpage[3],("Chopper Offset").."  " .. self.combine_offset )
	table.insert(self.hudpage[3],("Chopper Offset").."  " .. self.combine_offset )
end

function courseplay:HudPage(self)
	local Page = self.showHudInfoBase
 	local i = 0
 	setTextBold(false)
	for v,name in pairs(self.hudpage[Page]) do
    	i = i + 1
		local yspace = 0.600 - (i * 0.025)
		renderText(0.768, yspace, 0.021, name);
	end
end