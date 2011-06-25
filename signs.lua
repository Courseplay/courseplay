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
	if forced_sign == nil then
    	setTranslation(sign, x, height + 5, z)
    elseif forced_sign == self.cross_sign then
	    setTranslation(sign, x, height + 4, z)
	else
	    setTranslation(sign, x, height + 3, z)
	end

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
        	if self.waypointMode == 1 then
				if self.record then
					vis = true
				else
				    vis = false
				end
				
			elseif self.waypointMode == 2 or self.waypointMode == 4 then
			    vis = true
            elseif self.waypointMode == 3 then
			    vis = false
			end
      	end

		if force_remove then
        	vis = false
      	end
		setVisibility(v.sign, vis)
  	end

end


-- add Crosspoints to the signs
function courseplay:RefreshGlobalSigns(self)
	
	if self.signs ~= nil then
    	courseplay:sign_visibility(self,false,true)
    	self.signs = {}
    end
	if courseplay_courses ~= nil then  -- ??? MP Ready ???
		for i=1, table.getn(courseplay_courses) do
	        for k,v in pairs(courseplay_courses[i].waypoints) do
	            local wp = courseplay_courses[i].waypoints[k]
  				if wp.crossing == true then
					local x = wp.cx
	               	local y = wp.angle
	               	local z = wp.cz
				    courseplay:addsign(self, x, y, z, self.cross_sign, true)
				end

	      	end
		end
	--	print("Refresh Global Signs")
    end
    
end


function courseplay:RefreshSigns(self)
	self.waitPoints = 0
	self.crossPoints = 0
  	courseplay:RefreshGlobalSigns(self)
	self.maxnumber = table.getn(self.Waypoints)
	for k,wp in pairs(self.Waypoints) do
        if k <= 3 or self.waypointMode >= 3 or wp.wait == true then
			if k == 1 then
		  		courseplay:addsign(self, wp.cx, wp.angle, wp.cz,self.start_sign)
		  	elseif wp.wait then
		  		courseplay:addsign(self, wp.cx, wp.angle, wp.cz,self.wait_sign)
            elseif k == self.maxnumber then
		     	courseplay:addsign(self, wp.cx, wp.angle, wp.cz, self.stop_sign)
		  	else
		  		courseplay:addsign(self, wp.cx, wp.angle, wp.cz)
		  	end
        end

 	  	if wp.wait then
		  self.waitPoints = self.waitPoints + 1
		end
		if wp.crossing then
		  self.crossPoints = self.crossPoints + 1
		end
    end

end