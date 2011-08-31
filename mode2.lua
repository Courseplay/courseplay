-- AI-states
-- 0 Default, wenn nicht in Mode2 aktiv
-- 1 warte am startpunkt auf arbeit
-- 2 fahre hinter drescher
-- 3 fahre zur pipe / abtanken
-- 4 fahre ans heck des dreschers
-- 5 wegpunkte abfahren
-- 7 warte auf die Pipe 
-- 6 fahre hinter traktor
-- 8 alle trailer voll
-- 9 wenden
-- 10 seite wechseln

function courseplay:handle_mode2(self, dt)
	local allowedToDrive = false

	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  
	if tipper_fill_level == nil then
		tipper_fill_level = 0
	end
	if tipper_capacity == nil then
		tipper_capacity = 0
	end

	local fill_level = 0
	if tipper_capacity ~= 0 then
		fill_level = tipper_fill_level * 100 / tipper_capacity
	end

	if fill_level > self.required_fill_level_for_follow then
		self.allow_following = true
	else
		self.allow_following  = false
	end  

	if self.ai_state == 0 then   
		self.ai_state = 1
	end


	if self.ai_state == 1 and self.active_combine ~= nil then
		courseplay:unregister_at_combine(self, self.active_combine)
	end

	-- trailer full
	if self.ai_state == 8 then
		self.recordnumber = 2
		courseplay:unregister_at_combine(self, self.active_combine)   
		self.ai_state = 0
		self.loaded = true
		return false
	end
  
  -- support multiple tippers  
	if self.currentTrailerToFill == nil then
    	self.currentTrailerToFill = 1
  	end
  
	local current_tipper = self.tippers[self.currentTrailerToFill]
  
	if current_tipper == nil then
		self.tools_dirty = true
	   	return false
	end
  
  
  -- switch side
	if self.active_combine ~= nil and (self.ai_state == 10 or self.active_combine.turnAP ~= nil and self.active_combine.turnAP == true) then
    	if self.chopper_offset > 0 then
  			self.target_x, self.target_y, self.target_z = localToWorld(self.active_combine.rootNode, 25, 0, 0)
  		else
  			self.target_x, self.target_y, self.target_z = localToWorld(self.active_combine.rootNode, -25, 0, 0)
  		end
  		self.ai_state = 5
    	self.next_ai_state = 2
  	end
  
	if (current_tipper.fillLevel == current_tipper.capacity) or self.loaded or (fill_level >= self.required_fill_level_for_drive_on and self.ai_state == 1) then
    	if table.getn(self.tippers) > self.currentTrailerToFill then
      		self.currentTrailerToFill = self.currentTrailerToFill + 1
    	else
      		self.currentTrailerToFill = nil
      		if self.ai_state ~= 5 then
        	    if courseplay:calculate_course_to(self, self.Waypoints[2].cx, self.Waypoints[2].cz) then
        		  self.next_ai_state = 8				
				else -- fallback if no course could be calculated
				  self.ai_state = 8
				end
        		
        		-- set waypoint 40 meters in front of combine
        		--if self.active_combine ~= nil and courseplay:distance_to_object(self, self.active_combine) < 10 then
        		--self.target_x, self.target_y, self.target_z = localToWorld(self.active_combine.rootNode, self.chopper_offset*2, 0, 25)   -- 40
        	    --else
        	    --self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, self.chopper_offset*2, 0, 25)    -- 40
        	    --end
        	    --self.ai_state = 5
      		end
    	end
  	end
  

	if self.active_combine ~= nil then
  		if self.courseplay_position == 1 then
  	  	-- is there a trailer to fill, or at least a waypoint to go to?
  	  		if self.currentTrailerToFill or self.ai_state == 5 then
				if self.ai_state == 6 then
				    self.ai_state = 2
				end
				courseplay:unload_combine(self, dt)
  	  		end
  		else
		  	-- follow tractor in front of me
		  	tractor = self.active_combine.courseplayers[self.courseplay_position-1]
		  --	courseplay:follow_tractor(self, dt, tractor)
		  	self.ai_state = 6
		  	courseplay:unload_combine(self, dt)
    	end
  	else -- NO active combine
    -- STOP!!
    	if g_server ~= nil then
      		AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0, 0, 28, false, moveForwards, 0, 1)
    	end
    
  		if self.loaded then
  	  		self.recordnumber = 2
  	  		self.ai_state = 1
  	  	return false
  		end
  
    -- are there any combines out there that need my help?
		if self.timeout < self.timer then
		courseplay:update_combines(self)
	  	courseplay:set_timeout(self, 200)
		end

		--is any of the reachable combines full?
		if self.reachable_combines ~= nil then
			if table.getn(self.reachable_combines) > 0 then
				local best_combine = nil
			  	local highest_fill_level = 0
			  	local num_courseplayers = 0

			  	-- chose the combine who needs me the most
			  	for k,combine in pairs(self.reachable_combines) do
			    	if (combine.grainTankFillLevel > (combine.grainTankCapacity*self.required_fill_level_for_follow/100)) or combine.grainTankCapacity == 0 or combine.wants_courseplayer then
			      		if combine.grainTankCapacity == 0 then
			        		if combine.courseplayers == nil then
			          			best_combine = combine
			        		elseif table.getn(combine.courseplayers) <= num_courseplayers or best_combine == nil then
			          			num_courseplayers = table.getn(combine.courseplayers)
			          			if table.getn(combine.courseplayers) > 0 then
			            			if combine.courseplayers[1].allow_following then
			              				best_combine = combine
			            			end
			          			else
			            			best_combine = combine
			          			end
			        		end


						else
				        	if combine.grainTankFillLevel >= highest_fill_level then
				          		highest_fill_level = combine.grainTankFillLevel
				          		best_combine = combine
				        	end
			      		end
			    	end
				end

				if best_combine ~= nil then
					if courseplay:register_at_combine(self, best_combine) then
			  			self.ai_state = 2
			  		end
			  	else
			    	self.info_text = "Warte bis Fuellstand erreicht ist"-- courseplay:get_locale(self, "CPCombineTurning") -- "Drescher wendet. "
				end

			else
				self.info_text = "Kein Drescher in Reichweite" -- courseplay:get_locale(self, "CPCombineTurning") -- "Drescher wendet. "

			end  	
		end
  	end
    return allowedToDrive
end

function courseplay:unload_combine(self, dt)
	local allowedToDrive = true
	local combine = self.active_combine
	local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
	local cx, cy, cz = nil, nil, nil

	local sl = nil
	local mode = self.ai_state
	local combine_fill_level, combine_turning = nil, nil
	local refSpeed = nil
	local handleTurn = false
	local cornChopper = false
	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	local tipper_percentage = tipper_fill_level/tipper_capacity * 100
	local xt, yt, zt = nil, nil, nil
    local dod = nil

	-- Calculate Trailer Offset
	if self.currentTrailerToFill ~= nil then
		xt, yt, zt = worldToLocal(self.tippers[self.currentTrailerToFill].rootNode, x, y, z)
	else
		xt, yt, zt = worldToLocal(self.tippers[1].rootNode, x, y, z)
	end
	-- support for tippers like hw80
	if zt < 0 then
		zt = zt *-1
	end

	local trailer_offset = zt + self.tipper_offset
	if self.currentTrailerToFill ~= nil then
		trailer_offset = zt + self.tipper_offset*self.currentTrailerToFill
	end


	if self.sl == nil then
		self.sl = 3
	end


	-- is combine turning ?
	if combine ~= nil and (combine.turnStage == 1 or combine.turnStage == 2) then
		self.info_text = courseplay:get_locale(self, "CPCombineTurning") -- "Drescher wendet. "
		combine_turning = true
	end

	if mode == 2 or mode == 3 or mode == 4 then
 		if combine == nil then
		  self.info_text = "this should never happen"
		  allowedToDrive = false
		end
	end

	if combine.grainTankCapacity > 0 then
	  combine_fill_level = combine.grainTankFillLevel * 100 / combine.grainTankCapacity
	else -- combine is a chopper / has no tank
	  combine_fill_level = 51
	  cornChopper = true
	end

    local offset_to_chopper = self.chopper_offset
	if combine.turnStage ~= 0 then
	    offset_to_chopper = self.chopper_offset * 1.6 --1,3
	end


	local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)
	local distance = Utils.vector2Length(x1, z1)

	if mode == 2 then  -- Drive to Combine or Cornchopper

		self.sl = 3
		refSpeed = self.field_speed
	  	courseplay:remove_from_combines_ignore_list(self, combine)
	  	self.info_text =courseplay:get_locale(self, "CPDriveBehinCombine") -- ""

		local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)  

		if z1 > -10 then  -- tractor in front of combine      --0
			-- left side of combine
			local cx_left, cy_left, cz_left = localToWorld(combine.rootNode, 10, 0, -20)           --20,0, -30        (war 20,0,-25
			-- righ side of combine
			local cx_right, cy_right, cz_right = localToWorld(combine.rootNode, -10, 0, -20)       -- -20,0,-30            -20,0,-25
			local lx, ly, lz =	worldToLocal(self.aiTractorDirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(self.aiTractorDirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)
			if disL < disR then
		  		cx, cy, cz = cx_left, cy_left, cz_left
	    	else
		  		cx, cy, cz = cx_right, cy_right, cz_right
	    	end
	--	elseif z1 > -10 and z1 < 5 and x1 > self.combine_offset and x1 < (self.combine_offset * 1.5) then
	--	 	mode = 3
	--	 	return
		else
		    -- tractor behind combine
		    cx, cy, cz = localToWorld(combine.rootNode, 0, 0, -30)
	  	end
		
		if not self.calculated_course then
			if courseplay:calculate_course_to(self, cx, cz) then
				mode = 5
				-- ai_state when waypoint is reached
				self.next_ai_state = 2			
			end
			
		 end
       		
        local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx, cy, cz) 
     	dod = Utils.vector2Length(lx, lz)
	    --print(string.format("Dod: %d lx: %d lz: %d x1: %d z1: %d", dod,lx,lz,x1,z1 ))
	  -- near point
		if dod < 3 then  -- change to mode 4 == drive behind combine or cornChopper


			if cornChopper then -- decide on which side to drive based on ai-combine
	      		local leftFruit, rightFruit =  courseplay:side_to_drive(self, combine, 20)
	      		local last_offset = self.chopper_offset
				self.chopper_offset = self.combine_offset
                if leftFruit > rightFruit then
	      			self.chopper_offset = self.combine_offset * -1
	      		elseif leftFruit == rightFruit then
	        		self.chopper_offset = last_offset * -1
	      		end
	    	end
        	mode = 4
	  	end
	 -- end mode 2



	elseif mode == 4 then -- Drive to rear Combine or Cornchopper

		self.info_text =courseplay:get_locale(self, "CPDriveToCombine") -- "Fahre zum Drescher"
	    courseplay:add_to_combines_ignore_list(self, combine)
	    refSpeed = self.field_speed



	    local tX, tY, tZ = nil, nil, nil

		if cornChopper then
	      tX, tY, tZ = localToWorld(combine.rootNode, self.chopper_offset *0.7, 0, -10) -- offste *0.6     !????????????
	    else
	    	if self.chopper_offset < 0 then
				self.chopper_offset = self.chopper_offset * -1
			end
	      	tX, tY, tZ = localToWorld(combine.rootNode, self.chopper_offset, 0, -10)
	    end
	    cx, cz = tX, tZ


        local ttX, ttY, ttZ = nil, nil, nil
	  	local lx, ly, lz = nil, nil, nil
        ttX, ttY, ttZ = localToWorld(combine.rootNode, offset_to_chopper, 0, trailer_offset/2)
	  	lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, ttX, y, ttZ)

	  	if cx ~= nil and cz ~= nil then
	    	local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx, y, cz)
	    	dod = Utils.vector2Length(lx, lz)
	  	else
	    	dod = Utils.vector2Length(lx, lz)
	  	end


		if dod < 2 then     -- dod < 2
	    	allowedToDrive = false
	    	mode = 3   -- change to mode 3 == drive to unload pipe
	  	end

	    if dod > 60 then      --??
	    	mode = 2
	  	end







	elseif mode == 3 then --drive to unload pipe

		self.info_text =courseplay:get_locale(self, "CPDriveNextCombine") -- "Fahre neben Drescher"
		courseplay:add_to_combines_ignore_list(self, combine)
        refSpeed = self.field_speed

        if self.next_targets ~= nil then
	        self.next_targets = {}
	    end

	  	if combine_fill_level == 0 then --combine empty set waypoint 30 meters behind combine
	    	self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, 10, 0, -5)
            courseplay:addsign(self,self.target_x, 10,self.target_y)
	    	if tipper_percentage >= self.required_fill_level_for_drive_on then
	      		self.loaded = true
	    	else

				-- turn left
			    self.turn_factor = 5 --??
			    -- insert waypoint behind combine
		    	local leftFruit, rightFruit =  courseplay:side_to_drive(self, combine, 20)
		        local next_x, next_y, next_z = localToWorld(combine.rootNode, 5, 0, -5)
				if leftFruit > rightFruit then
					next_x, next_y, next_z = localToWorld(combine.rootNode, -5, 0, -5)
				end
				local next_wp = {x = next_x, y=next_y, z=next_z}
				courseplay:addsign(self,next_x, 10,next_z)
				table.insert(self.next_targets, next_wp)
				-- insert another point behind combine
		       	next_x, next_y, next_z = localToWorld(combine.rootNode, 5, 0, -30)
		       	if leftFruit > rightFruit then
					next_x, next_y, next_z = localToWorld(combine.rootNode, -5, 0, -30)
				end
		        local next_wp = {x = next_x, y=next_y, z=next_z}
		        courseplay:addsign(self,next_x, 10,next_z)
				table.insert(self.next_targets, next_wp)
				mode = 9 -- turn around and then wait for next start
			    self.next_ai_state = 1



	    	end
		end


		if not cornChopper and self.chopper_offset < 0 then
			self.chopper_offset = self.chopper_offset * -1
		end



        cx, cy, cz = localToWorld(combine.rootNode, self.chopper_offset, 0, trailer_offset)      	  
        

        local ttX, ttY, ttZ = localToWorld(combine.rootNode, offset_to_chopper, 0, trailer_offset/2)
	  	local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, ttX, y, ttZ)
        dod = Utils.vector2Length(lx, lz)
        if dod > 60 then
        	mode = 2
      	end

      
		-- combine is not moving and trailer is under pipe
		if not cornChopper and ((combine.movingDirection == 0 and lz <= 0.5) or lz < -0.4 * trailer_offset) then
			self.info_text =courseplay:get_locale(self, "CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
			allowedToDrive = false

		elseif cornChopper then
			if combine.movingDirection == 0 and (lz == -1 or dod == -1) then
				allowedToDrive = false 
				self.info_text =courseplay:get_locale(self, "CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
		    end
		    if lz < -5 or dod < -5 then
		    	mode = 2
		    end

		end
	--	local speed  = combine.lastSpeed*3600
     --   print(string.format("MovingDirection: %d lz: %d dod: %d lx: %d ", combine.movingDirection, lz, dod,lx ))

	  -- refspeed depends on the distance to the combine
	  	local combine_speed = combine.lastSpeed



		if combine_speed ~= nil then
			refSpeed = combine_speed + (combine_speed * lz * 3 / 10)
			if refSpeed > self.field_speed then
			  refSpeed = self.field_speed
			end
		else
			refSpeed = self.field_speed
		end

		self.sl = 2

		if (combine.turnStage ~= 0 and lz < 20) or self.timer < self.drive_slow_timer then
			refSpeed = 1/3600
			self.motor.maxRpm[self.sl] = 200
			if combine.turnStage ~= 0 then
				self.drive_slow_timer = self.timer + 100
			end
		end

		if combine.movingDirection == 0 then
			refSpeed = self.field_speed * 1.5
			if mode == 3 and dod < 10 then
			--print("near wating combine")
				refSpeed = 1/3600
			end
		end
															  ---------------------------------------------------------------------
	end	 -- end mode 3 or 4

    
	if combine_turning and distance < 30 then
		if tipper_percentage >= self.required_fill_level_for_drive_on then
	    	self.loaded = true
	  	elseif mode == 3 or mode == 4 then
			if cornChopper then
				self.leftFruit, self.rightFruit =  courseplay:side_to_drive(self, combine, -20)

	      		if self.chopper_offset > 0 then     --turn Left
					self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, self.turn_radius, 0, self.turn_radius*-1)
			        self.turn_factor = -5

	                local next_x, next_y, next_z = localToWorld(self.rootNode, 0, 0, self.turn_radius*-1)
		      		local next_wp = {x = next_x, y=next_y, z=next_z}
		      		table.insert(self.next_targets, next_wp)

			        local next_x, next_y, next_z = localToWorld(self.rootNode, self.turn_radius, 0, self.turn_radius*-0,4)
		      		local next_wp = {x = next_x, y=next_y, z=next_z}
		      		table.insert(self.next_targets, next_wp)

		      		local next_x, next_y, next_z = localToWorld(self.rootNode,-1.5, 0, 5 )
		      		local next_wp = {x = next_x, y=next_y, z=next_z}
		      		table.insert(self.next_targets, next_wp)


			    else -- turn right
			        self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, self.turn_radius*-1, 0, self.turn_radius*-1)
			        self.turn_factor = 5

	                local next_x, next_y, next_z = localToWorld(self.rootNode, 0, 0, self.turn_radius*-1)
		      		local next_wp = {x = next_x, y=next_y, z=next_z}
		      		table.insert(self.next_targets, next_wp)

			        local next_x, next_y, next_z = localToWorld(self.rootNode, self.turn_radius*-1, 0, self.turn_radius*-0.4)
		      		local next_wp = {x = next_x, y=next_y, z=next_z}
		      		table.insert(self.next_targets, next_wp)

		      		local next_x, next_y, next_z = localToWorld(self.rootNode, 1.5, 0, 5)
		      		local next_wp = {x = next_x, y=next_y, z=next_z}
		      		table.insert(self.next_targets, next_wp)
				end	


				mode = 5
			    self.next_ai_state = 7

			else -- combine

	      		self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, 10, 0, -10)
		      	self.turn_factor = 5  -- turn left

		      	-- insert waypoint behind combine
		      	local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -10)
		      	local next_wp = {x = next_x, y=next_y, z=next_z}
		      	table.insert(self.next_targets, next_wp)

		     	 -- insert another point behind combine
		     	local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -30)
		     	local next_wp = {x = next_x, y=next_y, z=next_z}

		     	table.insert(self.next_targets, next_wp)
		      	mode = 5
		      	self.next_ai_state = 2
			end
		elseif mode ~=5 and mode ~= 9 then
			-- just wait until combine has turned
			allowedToDrive = false
			self.info_text =courseplay:get_locale(self, "CPCombineWantsMeToStop")
		end
	end


--	if self.waitTimer and self.timer < self.waitTimer then
--		courseplay:remove_from_combines_ignore_list(self, combine)
--		allowedToDrive = false
--	else
	  -- wende man?ver
		if mode == 9 and self.target_x ~= nil and self.target_z ~= nil then
			courseplay:remove_from_combines_ignore_list(self, combine)
			self.info_text = string.format(courseplay:get_locale(self, "CPTurningTo"), self.target_x, self.target_z )
			allowedToDrive = false
			local mx, mz = self.target_x, self.target_z
			local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, mx, y, mz)
			self.sl = 1
			refSpeed = self.field_speed --self.turn_speed
		--	print(string.format("lz: %d lx: %d  ", lz, lx))     --print
			if lz > 0 and math.abs(lx) < lz * 0.5 then -- lz * 0.5    --2
				if self.next_ai_state == 4 and not combine_turning then
					self.target_x = nil
					self.target_z = nil
					mode = self.next_ai_state
					self.next_ai_state = 0
				end

				if self.next_ai_state == 1 or self.next_ai_state == 2 then
				-- is there another waypoint to go to?
					if table.getn(self.next_targets)> 0 then
						mode = 5
					  	self.target_x =  self.next_targets[1].x
					  	self.target_y =  self.next_targets[1].y
					  	self.target_z =  self.next_targets[1].z
					  	table.remove(self.next_targets, 1)
					else
		  				mode = self.next_ai_state
		  				self.next_ai_state = 0
					end
				end
			else
				cx, cy, cz = localToWorld(self.aiTractorDirectionNode, self.turn_factor, 0, 5)
				allowedToDrive = true
			end
		end



	  -- drive to given waypoint
		if mode == 5 and self.target_x ~= nil and self.target_z ~= nil then
			courseplay:remove_from_combines_ignore_list(self, combine)
		    self.info_text = string.format(courseplay:get_locale(self, "CPDriveToWP"), self.target_x, self.target_z )
		  	cx = self.target_x
		  	cy = self.target_y
		  	cz = self.target_z

		  	self.sl = 2
		  	refSpeed = self.field_speed

		  	distance_to_wp = courseplay:distance_to_point(self, cx, y, cz)
			
			if table.getn(self.next_targets) == 0 then
	  			if distance_to_wp < 10 then
	  	  			refSpeed = self.turn_speed -- 3/3600
	  	  			self.sl = 1
	  			end
			end
			
			-- avoid circling
			local distToChange = 2
			if self.shortest_dist == nil or self.shortest_dist > distance_to_wp then
			  self.shortest_dist = distance_to_wp
			end  	
			
			if self.dist > self.shortest_dist and distance_to_wp < 15 then
			  distToChange = distance_to_wp + 1
			end
			
		  	if distance_to_wp < distToChange then
				self.shortest_dist = nil
		  	 	if table.getn(self.next_targets)> 0 then
			  --	  	mode = 5
			  	    self.target_x =  self.next_targets[1].x
			  	    self.target_y =  self.next_targets[1].y
			  	    self.target_z =  self.next_targets[1].z

			  	    table.remove(self.next_targets, 1)
		  	  	else
		  	  		allowedToDrive = false
		  	  		if self.next_ai_state ~= 2 then
		  	  		  self.calculated_course = false
		  	  		end
			  	  	if self.next_ai_state == 7 and combine_turning == nil then
			  	  		self.chopper_offset = self.combine_offset

			  	  	-- only for corn choppers
						if cornChopper then
				  			local last_offset = self.chopper_offset
				  	      	if self.leftFruit > self.rightFruit then
				  	    		self.chopper_offset = self.combine_offset * -1
				  	      	elseif self.leftFruit == self.rightFruit then
				  	        	self.chopper_offset = last_offset * -1
				  	      	end

				  	    	if combine.movingDirection == 0 then
								self.info_text ="Warte bis Pipe ausgerichtet"
	  							allowedToDrive = false
	  						elseif combine.movingDirection > 0 then
	  							self.next_ai_state = 3
	  						end
				  	    end

				  		self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, self.chopper_offset, 0, 3) -- -2          --??? *0,5 -10

					elseif (self.next_ai_state == 7 or self.next_ai_state == 4 )and combine_turning then
			  	    	self.info_text =courseplay:get_locale(self, "CPWaitUntilCombineTurned") --  ""

			  	  	elseif self.next_ai_state == 1  then
			  	    --	self.sl = 1
			  	    --	refSpeed = self.turn_speed
			  	    	mode = self.next_ai_state
			  	    	self.next_ai_state = 0
                    
			  	  	else
			  	    	mode = self.next_ai_state
			  	    	self.next_ai_state = 0
			  	  	end
			  	end
			end
	  	end

	  	if mode == 6 then --Follow Tractor
	  --      tractor = self.active_combine.courseplayers[self.courseplay_position-1]
	        self.info_text =courseplay:get_locale(self, "CPFollowTractor") -- "Fahre hinter Traktor"

        --	refSpeed = 10/3600 -- tractor.lastSpeedReal
        --	local mode = self.follow_mode        ???
        --    print(string.format("refSpeed: %d ",refSpeed*3600 ))
 			 -- drive behind tractor
    		local x1, y1, z1 = worldToLocal(tractor.rootNode, x, y, z)
    		local distance = Utils.vector2Length(x1, z1)
    
    
    
		    if z1 > 0 then
		    	-- tractor in front of tractor
		      	-- left side of tractor
				local cx_left, cy_left, cz_left = localToWorld(tractor.rootNode, 30, 0, -10)
			     -- righ side of tractor
			    local cx_right, cy_right, cz_right = localToWorld(tractor.rootNode, -30, 0, -10)
			    local lx, ly, lz =	worldToLocal(self.aiTractorDirectionNode, cx_left, y, cz_left)
			      -- distance to left position
			    local disL = Utils.vector2Length(lx, lz)
			    local rx, ry, rz = worldToLocal(self.aiTractorDirectionNode, cx_right, y, cz_right)
			      -- distance to right position
			    local disR = Utils.vector2Length(rx, rz)
			    if disL < disR then
			        cx, cy, cz = cx_left, cy_left, cz_left
			    else
			        cx, cy, cz = cx_right, cy_right, cz_right
			    end
			else
			     -- tractor behind tractor
			     cx, cy, cz = localToWorld(tractor.rootNode, 0, 0, -50)
			end

    		local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx, cy, cz)
    		dod = Utils.vector2Length(lx, lz)

    		if dod < 2 or tractor.ai_state ~= 3 then
      			allowedToDrive = false
    		end
  
    		if distance > 100 then
      			refSpeed = self.max_speed
      		else
      			refSpeed = tractor.lastSpeedReal --10/3600 -- tractor.lastSpeedReal
    		end  
  
  			
       --     print(string.format("distance: %d  dod: %d",distance,dod ))
  
	  	end

--	end

	self.ai_state = mode

	if cx == nil or cz == nil then
		self.info_text = courseplay:get_locale(self, "CPWaitForWaypoint") -- "Warte bis ich neuen Wegpunkt habe"
		allowedToDrive = false
	end

	if self.forced_to_stop then
		self.info_text = courseplay:get_locale(self, "CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
		allowedToDrive = false
	end

	if self.showWaterWarning then
		allowedToDrive = false
		self.global_info_text = self.locales.CPWaterDrive
	end

    	-- check traffic and calculate speed
    if allowedToDrive then

		allowedToDrive = courseplay:check_traffic(self, true, allowedToDrive)
		if self.sl == nil then
			self.sl = 3
		end
		local maxRpm = self.motor.maxRpm[self.sl]
		local real_speed = self.lastSpeedReal

		if refSpeed == nil then
			refSpeed = real_speed
		end

		--print(string.format("sl: %d old RPM %d  real_speed: %d refSpeed: %d ", self.sl, maxRpm, real_speed*3600, refSpeed*3600 ))

		if real_speed < refSpeed then
			if real_speed * 2 < refSpeed then
				maxRpm = maxRpm + 100
			elseif real_speed * 1.5 < refSpeed then
				maxRpm = maxRpm + 50
			else
				maxRpm = maxRpm + 5
			end
		end

		if real_speed > refSpeed then
			if real_speed / 2 > refSpeed then
		  		maxRpm = maxRpm - 100
			elseif real_speed / 1.5 > refSpeed then
		  		maxRpm = maxRpm - 50
			else
		  		maxRpm = maxRpm - 5
			end
		end

		-- don't drive faster/slower than you can!
		if maxRpm > self.orgRpm[3] then
			maxRpm = self.orgRpm[3]
		else
			if maxRpm < self.motor.minRpm then
		   		maxRpm = self.motor.minRpm
		 	end
		end

		self.motor.maxRpm[self.sl] = maxRpm
	end



	if g_server ~= nil then
	    local target_x, target_z = nil,nil
		if cx ~= nil and cz ~= nil then
	    	target_x, target_z = AIVehicleUtil.getDriveDirection(self.aiTractorDirectionNode, cx, y, cz)
		else
			allowedToDrive = false
		end

	    if not allowedToDrive then
			target_x, target_z = 0, 1
	  		self.motor:setSpeedLevel(0, false);
	  	--	AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0, 0, 28, false, moveForwards, lx, lz)
		end

		AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0.5, 0.5, 8, allowedToDrive, true, target_x, target_z, self.sl, 0.4)
		courseplay:set_traffc_collision(self, target_x, target_z)
		 -- new
	end

end

function courseplay:calculate_course_to(self, target_x, target_z)
  local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
  self.calculated_course = true
  print(string.format("position x: %d z %d", x, z ))
  local wp_counter = 0
  local wps = CalcMoves(z, x, target_z, target_x)
  print(table.show(wps))
  
  if wps ~= nil then
	  self.next_targets = {}
	  for _,wp in pairs(wps) do
		  wp_counter = wp_counter + 1
		  
		  local next_wp = {x = wp.y, y=0, z=wp.x}
		  table.insert(self.next_targets, next_wp)
		  wp_counter = 0	
	  end
	  
	  self.target_x =  self.next_targets[1].x
	  self.target_y =  self.next_targets[1].y
	  self.target_z =  self.next_targets[1].z
	  self.no_speed_limit = true
	  table.remove(self.next_targets, 1)
	  self.ai_state = 5
  else
    return false
  end
  return true
end