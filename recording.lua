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
		 	if self.dist > 1 and (anglediff > 2 or dist > 5)  then
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
		if self.dist > 20 then
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
		self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = false, rev = self.direction, crossing = set_crossing}
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


function courseplay:set_waitpoint(self)
	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ)) 
  self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = true, rev = self.direction, crossing = false}
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
  self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = false, rev = self.direction, crossing = true}
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
  	self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = false, rev = self.direction, crossing = false}
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
	
end	


function courseplay:set_FieldPoint(self)
	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ)) 
  	self.Waypoints[self.recordnumber] = {cx = cx ,cz = cz ,angle = newangle, wait = true, rev = false, crossing = false}
  	self.tmr = 1
  	self.recordnumber = self.recordnumber + 1
  	self.createCourse = true
  	courseplay:addsign(self, cx, cy,cz, self.wait_sign)
end

function courseplay:createCourse(self)
--[[	local cx,cy,cz = getWorldTranslation(self.rootNode);
	local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
	local length = Utils.vector2Length(x,z);
	local dX = x/length
	local dZ = z/length
	local newangle = math.deg(math.atan2(dX,dZ))  ]]
  	local cax =  self.Waypoints[1].cx
  	local caz =  self.Waypoints[1].cz

  	local cbx =   self.Waypoints[2].cx
  	local cbz =   self.Waypoints[2].cz

    local ccx =  self.Waypoints[3].cx
  	local ccz =  self.Waypoints[3].cz

  	local cdx =   self.Waypoints[4].cx
  	local cdz =   self.Waypoints[4].cz

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
    local workWidht = self.toolWorkWidht
	local distWayPoint = 5
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
        i = i + 1
		
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
				
				self.Waypoints[i] = {cx = wxl ,cz = wzl ,angle = 0, wait = false, rev = false, crossing = false}
				
				i = i + 1
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
