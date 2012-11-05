-- records waypoints for course
function courseplay:record(self)
	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ))
	local fwd = self.direction
	if self.recordnumber < 2 then
		self.rotatedTime = 0
	end
	if self.recordnumber > 2 then
		local oldcx ,oldcz ,oldangle= self.Waypoints[self.recordnumber - 1].cx,self.Waypoints[self.recordnumber - 1].cz,self.Waypoints[self.recordnumber - 1].angle
		anglediff = math.abs(newangle - oldangle)
		self.dist = courseplay:distance(cx ,cz ,oldcx ,oldcz)
		if self.direction then
		 	if self.dist > 2 and (anglediff > 1.5 or dist > 10)  then
				self.tmr = 101
			end
		else
			if self.dist > 5 and (anglediff > 5 or dist > 10) then
				self.tmr = 101
			end
		end
	end 
	if self.recordnumber == 2 then
		local oldcx ,oldcz = self.Waypoints[1].cx,self.Waypoints[1].cz
		self.dist = courseplay:distance(cx ,cz ,oldcx ,oldcz)
		if self.dist > 10 then
			self.tmr = 101
		else
		   self.tmr = 1
		end
	end	
	if self.recordnumber == 3 then
		local oldcx ,oldcz = self.Waypoints[2].cx,self.Waypoints[2].cz
		self.dist = courseplay:distance(cx ,cz ,oldcx ,oldcz)
		if self.dist > 20 then  --20-
			self.tmr = 101
		else
			self.tmr = 1
		end
	end
	local set_crossing = false
	if self.recordnumber == 1 then
		set_crossing = true
	end
	if self.tmr > 100 then 
		self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = false, rev = self.direction, crossing = set_crossing, speed = self.lastSpeedReal}
		if self.recordnumber < 4 or self.waypointMode == 3 then
		    if self.recordnumber == 1 then
		    	courseplay:addsign(self, cx, newangle,cz, self.start_sign)
		    else
		    	courseplay:addsign(self, cx, newangle,cz)
		    end			
		end
		self.tmr = 1
		self.recordnumber = self.recordnumber + 1
	end
end;

function courseplay:set_next_target(self, x, z)
  local next_x, next_y, next_z = localToWorld(self.rootNode, x, 0, z)
	local next_wp = {x = next_x, y=next_y, z=next_z}
	table.insert(self.next_targets, next_wp) 
end

function courseplay:set_waitpoint(self)
	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ)) 
	self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = true, rev = self.direction, crossing = false, speed = 0}
	self.tmr = 1
	self.recordnumber = self.recordnumber + 1
	self.waitPoints = self.waitPoints + 1
	courseplay:addsign(self, cx, cy,cz, self.wait_sign)  
end


function courseplay:set_crossing(self, stop)
	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ)) 
	self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = false, rev = self.direction, crossing = true, speed = nil}
	self.tmr = 1
	self.recordnumber = self.recordnumber + 1
	self.crossPoints = self.crossPoints + 1
	if stop ~= nil then
		courseplay:addsign(self, cx, cy,cz,self.stop_sign)
	else
		courseplay:addsign(self, cx, cy,cz,self.cross_sign,true)
	end
end

-- set Waypoint before change direction
function courseplay:set_direction(self)
	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ))
	local fwd = nil
  	self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = false, rev = self.direction, crossing = false, speed = nil}
	self.direction = not self.direction
  	self.tmr = 1
  	self.recordnumber = self.recordnumber + 1
  	courseplay:addsign(self, cx, cy,cz)
end

-- starts course recording -- just setting variables
function courseplay:start_record(self)
--    courseplay:reset_course(self)
	self.record = true
	self.drive  = false
    self.loaded_courses = {}
	self.recordnumber = 1
	self.waitPoints = 0
	self.crossPoints = 0
	self.tmr = 101
	self.direction = false
end		

-- stops course recording -- just setting variables
function courseplay:stop_record(self)
	courseplay:set_crossing(self, true)
	self.record = false
	self.record_pause = false
	self.drive  = false	
	self.dcheck = false
	self.play = true
	self.maxnumber = self.recordnumber - 1
	self.recordnumber = 1
	self.back = false
end		

-- interrupts course recording -- just setting variables
function courseplay:interrupt_record(self)
	if self.recordnumber > 3 then
		self.record_pause = true
		self.record = false
        courseplay:sign_visibility(self, false)
		self.dcheck = true
		-- Show last 2 waypoints, in order to find position for continue
		local cx ,cz = self.Waypoints[self.recordnumber - 1].cx, self.Waypoints[self.recordnumber - 1].cz
		courseplay:addsign(self, cx, 0, cz)
		cx ,cz = self.Waypoints[self.recordnumber - 2].cx, self.Waypoints[self.recordnumber - 2].cz
		courseplay:addsign(self, cx, 0, cz)
	end	
end

-- continues course recording -- just setting variables
function courseplay:continue_record(self)
	self.record_pause = false
	self.record = true
	self.dcheck = false
	courseplay:sign_visibility(self, false)
    courseplay:RefreshSigns(self)
end	

-- delete last waypoint
function courseplay:delete_waypoint(self)
	if self.recordnumber > 3 then
		self.recordnumber = self.recordnumber - 1
		self.tmr = 1
        courseplay:RefreshSigns(self)
		self.Waypoints[self.recordnumber] = nil
		-- Show last 2 waypoints, in order to find position for continue
		local cx ,cz = self.Waypoints[self.recordnumber - 1].cx, self.Waypoints[self.recordnumber - 1].cz
		courseplay:addsign(self, cx, 0, cz)
		cx ,cz = self.Waypoints[self.recordnumber - 2].cx, self.Waypoints[self.recordnumber - 2].cz
		courseplay:addsign(self, cx, 0, cz)
	end	
end

-- resets actual course -- just setting variables
function courseplay:reset_course(self)	
	courseplay:reset_merged(self)
	self.recordnumber = 1
	self.target_x, self.target_y, self.target_z = nil, nil, nil
	if self.active_combine ~= nil then
	  courseplay:unregister_at_combine(self, self.active_combine)
	end
	self.next_targets = {}
	self.loaded_courses = {}
	self.current_course_name = nil
--self.ai_mode = 1
	self.ai_state = 1
	self.tmr = 1
	self.Waypoints = {}
	self.loaded_courses = {}
	courseplay:RefreshSigns(self)
	self.play = false
	self.back = false
	self.abortWork = nil
	self.createCourse = false
	self.startlastload  = 1
	
end	

function courseplay:set_FieldPoint(self)
  courseplay:createCourse(self, self.Waypoints) 
end

function courseplay:createCourse(self, poly)
	courseplay:reset_course(self)
	n = table.getn(poly)
	minZ = poly[1].cz
	maxZ = poly[1].cz
	minX = poly[1].cx
	maxX = poly[1].cx
	for i = 2, n do
		local p = poly[i]
		if p.cx < minX then minX = p.cx end
		if p.cx > maxX then maxX = p.cx end
		if p.cz < minZ then minZ = p.cz end
		if p.cz > maxZ then maxZ = p.cz end
	end
	ab = {}
	cd = {}
	ab[1] = {x = minX ,z = minZ ,ka = "0"}
	ab[2] = {x = minX ,z = maxZ ,ka = "0"}
	ab[3] = {x = maxX ,z = minZ ,ka = "0"}
	ab[4] = {x = maxX ,z = maxZ ,ka = "0"}
	for i = 1, 4 do
		if (i+1) == 5 then
			 j = 1;
		else
			 j = i+1;
		end
		local dist = courseplay:distance(ab[i].x ,ab[i].z ,poly[1].cx ,poly[1].cz)
		cd[i] = {x = ab[i].x ,z = ab[i].z ,ka = dist}	
	end
	table.sort(cd, function(a,b) return a.ka < b.ka end)
	local duangel = 0
	for i = 1, 5 do
		duangel = duangel + poly[i].angle
	end
	duangel = duangel / 5
	local function bubbleSort(cd)
		local hasChanged
		local itemCount=4
		repeat
		itemCount=itemCount - 1
		hasChanged = false
		for i = 2, itemCount do
			j = i+1;
			local aTanA = math.atan2(cd[i].x - cd[1].x ,cd[i].z - cd[1].z);
			local aTanB = math.atan2(cd[j].x - cd[1].x ,cd[j].z - cd[1].z);
			if (duangel > 180 and duangel < 270) or (duangel > 0 and duangel < 90) then
				if (aTanA < aTanB) then
					cd[i].x, cd[j].x = cd[j].x, cd[i].x
					cd[i].z, cd[j].z = cd[j].z, cd[i].z
					hasChanged = true
				end
			else
				if (aTanB < aTanA) then
					cd[i].x, cd[j].x = cd[j].x, cd[i].x
					cd[i].z, cd[j].z = cd[j].z, cd[i].z
					hasChanged = true
				end
			end			
		end
		until hasChanged == false
	end
	bubbleSort(cd)

	local cax = cd[1].x
  	local caz = cd[1].z
  	local cbx = cd[2].x
  	local cbz = cd[2].z
    local ccx = cd[3].x
  	local ccz = cd[3].z
  	local cdx = cd[4].x
  	local cdz = cd[4].z
	courseplay:reset_course(self)
	local vadx = cax - cdx 
	local vadz = caz - cdz 
    local vdax = cdx - cax 
	local vdaz = cdz - caz 
	local vbcx = cbx - ccx 
	local vbcz = cbz - ccz 
	local vcbx = ccx - cbx 
	local vcbz = ccz - cbz 
	local vabx = cax - cbx 
	local vabz = caz - cbz 
	local vbax = cbx - cax 
	local vbaz = cbz - caz 
    local vlad = Utils.vector2Length(vdax, vdaz)
    local vlbc = Utils.vector2Length(vcbx, vcbz)
    local workWidht = self.toolWorkWidht;
	local distWayPoint = 3
	local wx, wz = cax, caz
	local i, ib = 1,1
	local fieldEndVad,fieldEndVbc,fieldEnd = false, false, false
	while fieldEnd == false do
		local reachedVad = (workWidht*(ib+1)-(workWidht/2))/vlad
        local reachedVbc = (workWidht*(ib+1)-(workWidht/2))/vlbc
		if  math.mod(ib,2) == 0 then
			if reachedVbc  < 1 then
				if ib == 1 then
					wxe = cax + (workWidht/2)*ib/vlad*vdax
		   			wze = caz + (workWidht/2)*ib/vlad*vdaz
		            wx = cbx + (workWidht/2)*ib/vlbc*vcbx
		   			wz = cbz + (workWidht/2)*ib/vlbc*vcbz
		
				else
					wxe = cax + (workWidht*ib-(workWidht/2))/vlad*vdax
		   			wze = caz + (workWidht*ib-(workWidht/2))/vlad*vdaz
		   			wx = cbx + (workWidht*ib-(workWidht/2))/vlbc*vcbx
		   			wz = cbz + (workWidht*ib-(workWidht/2))/vlbc*vcbz
		       	end
			else 
	 	  		wxe = cdx + (workWidht/2)/vlad*vadx
	    		wze = cdz + (workWidht/2)/vlad*vadz
	    		wx = ccx + (workWidht/2)/vlbc*vbcx
		  		wz = ccz + (workWidht/2)/vlbc*vbcz
				fieldEndVbc = true
            end
		else
            if reachedVad  < 1 then
				if ib == 1 then
					wx = cax + (workWidht/2)*ib/vlad*vdax
		   			wz = caz + (workWidht/2)*ib/vlad*vdaz
		   			wxe = cbx + (workWidht/2)*ib/vlbc*vcbx
		   			wze = cbz + (workWidht/2)*ib/vlbc*vcbz
				else
					wx = cax + (workWidht*ib-(workWidht/2))/vlad*vdax
		   			wz = caz + (workWidht*ib-(workWidht/2))/vlad*vdaz
		   			wxe = cbx + (workWidht*ib-(workWidht/2))/vlbc*vcbx
		   			wze = cbz + (workWidht*ib-(workWidht/2))/vlbc*vcbz
                end 
			else
	  	  		wx = cdx + (workWidht/2)/vlad*vadx
	    		wz = cdz + (workWidht/2)/vlad*vadz
	    		wxe = ccx + (workWidht/2)/vlbc*vbcx
		  		wze = ccz + (workWidht/2)/vlbc*vbcz
				fieldEndVad = true
            end
		end
		self.Waypoints[i] = {cx = wx ,cz = wz ,angle = 0, wait = false, rev = false, crossing = false}
		local vsex = wx - wxe
		local vsez = wz - wze
		local vesx = wxe - wx
		local vesz = wze - wz
		local vlse = Utils.vector2Length(vsex,vsez)
		local vlab = Utils.vector2Length(vabx, vabz)
        local ig = 1
		local fielEndLength = false
		while fielEndLength == false do -- gerade setzen
				local reachedEndlength = (distWayPoint*(ig+1)/vlse)
                if reachedEndlength  < 1 then
					wxl = wx + (distWayPoint*ig/vlse)*vesx
					wzl = wz + (distWayPoint*ig/vlse)*vesz
				else
				   	wxl = wxe
				   	wzl = wze
				   	fielEndLength = true
				end
				local kamu = courseplay:pointInPolygon(poly ,wxl ,wzl) 
				if kamu == true then
					self.Waypoints[i] = {cx = wxl ,cz = wzl ,angle = 0, wait = false, rev = false, crossing = false}
					i = i + 1
				end
				ig = ig+1
					
        end
        ib = ib+1
        fieldEnd = fieldEndVad or fieldEndVbc -- to do for not square Fields
   end

	self.maxnumber  = table.getn(self.Waypoints)
    self.recordnumber = 1
    self.createCourse = false
    self.play = true
    self.Waypoints[1].wait = true
    self.Waypoints[self.maxnumber].wait = true
    courseplay:RefreshSigns(self)
end

function courseplay:pointInPolygon(vertices, x, z)
	local intersectionCount = 0
	local x0 = vertices[#vertices].cx - x;
	local z0 = vertices[#vertices].cz - z;
	for i=1,#vertices do
		local x1 = vertices[i].cx - x;
		local z1 = vertices[i].cz - z;
		if z0 > 0 and z1 <= 0 and x1 * z0 > z1 * x0 then
			intersectionCount = intersectionCount + 1
		end
		if z1 > 0 and z0 <= 0 and x0 * z1 > z0 * x1 then
			intersectionCount = intersectionCount + 1
		end
		x0 = x1
		z0 = z1	
	end
	return (intersectionCount % 2) == 1
end