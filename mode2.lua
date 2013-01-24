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
-- 81 alle trailer voll, schlepper wendet von maschine weg
-- 9 wenden
-- 10 seite wechseln

function courseplay:handle_mode2(self, dt)
	local curFile = "mode2.lua"
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
		self.allow_following = false
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
		if self.combine_offset > 0 then
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
			--courseplay:unregister_at_combine(self, self.active_combine)  
			if self.ai_state ~= 5 then
				if self.combine_offset > 0 then
					self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, self.turn_radius, 0, self.turn_radius)
				else
					self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, -self.turn_radius, 0, self.turn_radius)
				end
				self.ai_state = 5
				self.next_ai_state = 81
			end
		end
	end


	if self.active_combine ~= nil then
		if self.courseplay_position == 1 then
			-- is there a trailer to fill, or at least a waypoint to go to?
			if self.currentTrailerToFill or self.ai_state == 5 then
				if self.ai_state == 6 then
					-- drive behind combine: self.ai_state = 2
					-- drive next to combine:
					self.ai_state = 3
				end
				courseplay:unload_combine(self, dt)
			end
		else
			-- follow tractor in front of me
			tractor = self.active_combine.courseplayers[self.courseplay_position - 1]
			--	courseplay:follow_tractor(self, dt, tractor)
			self.ai_state = 6
			courseplay:unload_combine(self, dt)
		end
	elseif self.ai_mode == 5 and self.next_ai_state == 81 then
		courseplay:unload_combine(self, dt)
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
			courseplay:set_timeout(self, 5000)
		end

		--is any of the reachable combines full?
		if self.reachable_combines ~= nil then
			if table.getn(self.reachable_combines) > 0 then
				-- choose the combine that needs me the most
				if self.best_combine ~= nil then
					courseplay:debug(tostring(self.id)..": request check in: "..tostring(self.combineID), 1)
					if courseplay:register_at_combine(self, self.best_combine) then
						local leftFruit, rightFruit = courseplay:side_to_drive(self, self.best_combine, -10) --changed by THOMAS
						self.ai_state = 2
					end
				else
					self.info_text = courseplay:get_locale(self, "CPwaitFillLevel") --TODO: g_i18n
				end


				local highest_fill_level = 0;
				local num_courseplayers = 0;
				local distance = 0;

				self.best_combine = nil;
				self.combineID = 0;
				self.distanceToCombine = 99999999999;

				-- chose the combine who needs me the most
				for k, combine in pairs(self.reachable_combines) do
					if (combine.grainTankFillLevel >= (combine.grainTankCapacity * self.required_fill_level_for_follow / 100)) or combine.grainTankCapacity == 0 or combine.wants_courseplayer then
						if combine.grainTankCapacity == 0 then
							if combine.courseplayers == nil then
								self.best_combine = combine
							elseif table.getn(combine.courseplayers) <= num_courseplayers or self.best_combine == nil then
								num_courseplayers = table.getn(combine.courseplayers)
								if table.getn(combine.courseplayers) > 0 then
									if combine.courseplayers[1].allow_following then
										self.best_combine = combine
									end
								else
									self.best_combine = combine
								end
							end 

						elseif combine.grainTankFillLevel >= highest_fill_level and combine.isCheckedIn == nil then
							highest_fill_level = combine.grainTankFillLevel
							self.best_combine = combine
							local cx, cy, cz = getWorldTranslation(combine.rootNode)
							local sx, sy, sz = getWorldTranslation(self.rootNode)
							distance = courseplay:distance(sx, sz, cx, cz)
							self.distanceToCombine = distance
							self.combineID = combine.id
						end
					end
				end

				if self.combineID ~= 0 then
					courseplay:debug(tostring(self.id).." : call combine: "..tostring(self.combineID), 1)
				end

			else
				--self.info_text = "Kein Drescher in Reichweite"
				self.info_text = courseplay:get_locale(self, "CPnoCombineInReach")
			end
		end
	end
	return allowedToDrive
end

function courseplay:unload_combine(self, dt)
	local curFile = "mode2.lua"
	local allowedToDrive = true
	local combine = self.active_combine
	local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
	local currentX, currentY, currentZ = nil, nil, nil

	--local sl = nil --kann die weg??
	local mode = self.ai_state
	local combine_fill_level, combine_turning = nil, false
	local refSpeed = nil
	local handleTurn = false
	local cornChopper = false
	local isHarvester = false
	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	local tipper_percentage = tipper_fill_level / tipper_capacity * 100
	local xt, yt, zt = nil, nil, nil
	local dod = nil

	-- Calculate Trailer Offset

	if self.currentTrailerToFill ~= nil then
		xt, yt, zt = worldToLocal(self.tippers[self.currentTrailerToFill].fillRootNode, x, y, z)
	else
		courseplay:debug("this should never happen - no currentTrailerToFillSet", 4)
		xt, yt, zt = worldToLocal(self.tippers[1].rootNode, x, y, z)
	end

	-- support for tippers like hw80
	if zt < 0 then
		zt = zt * -1
	end

	local trailer_offset = zt + self.tipper_offset


	if self.sl == nil then
		self.sl = 3
	end


	-- is combine turning ?
	if combine ~= nil and (combine.turnStage == 1 or combine.turnStage == 2 or combine.turnStage == 5) then
		self.info_text = courseplay:get_locale(self, "CPCombineTurning") -- "Drescher wendet. "
		combine_turning = true
	end

	if combine.grainTankCapacity > 0 then
		combine_fill_level = combine.grainTankFillLevel * 100 / combine.grainTankCapacity
	else -- combine is a chopper / has no tank
		combine_fill_level = 51
		cornChopper = true
	end

	
	if mode == 2 or mode == 3 or mode == 4 then
		if combine == nil then
			self.info_text = "this should never happen" --TODO: change text to something less dramatic
			allowedToDrive = false
		end
	end



	local offset_to_chopper = self.combine_offset
	if combine.turnStage ~= 0 then
		offset_to_chopper = self.combine_offset * 1.6 --1,3
	end


	local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)
	local distance = Utils.vector2Length(x1, z1)
	if (combine.grainTankFillLevel == combine.grainTankCapacity) and combine.movingDirection == 0 then
		combine.isFullAndStopped = true;
		--courseplay:debug(string.format("%s(%i): %s @ %s: grain tank full, no side switch (combine.isFullAndStopped=%s)", curFile, debug.getinfo(1).currentline, self.name, combine.name, tostring(combine.isFullAndStopped)), 3)
	end

	if mode == 2 then -- Drive to Combine or Cornchopper

		self.sl = 3
		refSpeed = self.field_speed
		--courseplay:remove_from_combines_ignore_list(self, combine)
		self.info_text = courseplay:get_locale(self, "CPDriveBehinCombine") -- ""

		local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)

		if z1 > -10 then -- tractor in front of combine      --0
			-- left side of combine
			local cx_left, cy_left, cz_left = localToWorld(combine.rootNode, 20, 0, -20) --20,0, -30        (war 20,0,-25
			-- righ side of combine
			local cx_right, cy_right, cz_right = localToWorld(combine.rootNode, -20, 0, -20) -- -20,0,-30            -20,0,-25
			local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(self.aiTractorDirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)

			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end

		else
			-- tractor behind combine
			currentX, currentY, currentZ = localToWorld(combine.rootNode, 0, 0, -25)
		end

		--if not self.calculated_course then
		--		if courseplay:calculate_course_to(self, currentX, currentZ) then
		--			mode = 5
		--			self.shortest_dist = nil
		--			-- ai_state when waypoint is reached
		--			self.next_ai_state = 2
		--		end

		--	end

		local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, currentX, currentY, currentZ)
		dod = Utils.vector2Length(lx, lz)

		-- near point
		if dod < 3 then -- change to mode 4 == drive behind combine or cornChopper

			if cornChopper then -- decide on which side to drive based on ai-combine
				local leftFruit, rightFruit = courseplay:side_to_drive(self, combine, 10);
				if combine.forced_side == nil then
					if leftFruit > rightFruit then
						if self.combine_offset > 0 then
							self.combine_offset = math.abs(self.combine_offset) * -1;
							self.sideToDrive = "right"
						end
					elseif leftFruit == rightFruit then
						if self.combine_offset < 0 then
							self.combine_offset = math.abs(self.combine_offset) * -1;
							self.sideToDrive = "left"
						end
					end
				elseif combine.forced_side == "right" then
					self.sideToDrive = "right";
					self.combine_offset = math.abs(self.combine_offset) * -1;
				else
					self.sideToDrive = "left";
					self.combine_offset = math.abs(self.combine_offset);
				end

			end
			mode = 4
		end

		-- end mode 2
	elseif mode == 4 then -- Drive to rear Combine or Cornchopper

		self.info_text = courseplay:get_locale(self, "CPDriveToCombine") -- "Fahre zum Drescher"
		--courseplay:add_to_combines_ignore_list(self, combine)
		refSpeed = self.field_speed

		local tX, tY, tZ = nil, nil, nil

		if cornChopper then
			tX, tY, tZ = localToWorld(combine.rootNode, self.combine_offset * 0.8, 0, -5) -- offste *0.6     !????????????
		else			
			tX, tY, tZ = localToWorld(combine.rootNode, self.combine_offset, 0, -5)
		end

		if combine.attachedImplements ~= nil then
			for k, i in pairs(combine.attachedImplements) do
				local implement = i.object;
				if implement.haeckseldolly == true then
					tX, tY, tZ = localToWorld(implement.rootNode, self.combine_offset, 0, trailer_offset)
				end
			end
		end

		currentX, currentZ = tX, tZ

		local lx, ly, lz = nil, nil, nil

		lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, tX, y, tZ)

		if currentX ~= nil and currentZ ~= nil then
			local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, currentX, y, currentZ)
			dod = Utils.vector2Length(lx, lz)
		else
			dod = Utils.vector2Length(lx, lz)
		end


		if dod < 2 then -- dod < 2
			allowedToDrive = false
			mode = 3 -- change to mode 3 == drive to unload pipe
		end

		if dod > 50 then
			mode = 2
		end

	elseif mode == 3 then --drive to unload pipe

		self.info_text = courseplay:get_locale(self, "CPDriveNextCombine") -- "Fahre neben Drescher"
		--courseplay:add_to_combines_ignore_list(self, combine)
		refSpeed = self.field_speed

		if self.next_targets ~= nil then
			self.next_targets = {}
		end

		if combine_fill_level == 0 then --combine empty set waypoint 30 meters behind combine

			if self.combine_offset > 0 then
				self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, 10, 0, -10) --10, 0, -5)
			else
				self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, -10 , 0, -10) --10, 0, -5)
			end

			local leftFruit, rightFruit = courseplay:side_to_drive(self, combine, -10)
			local tempFruit
			
			if not combine.isFullAndStopped and combine.movingDirection == 0 then
				--Fruit side switch at end of field line
				tempFruit = leftFruit;
				leftFruit = rightFruit;
				rightFruit = tempFruit;
			end;
			combine.isFullAndStopped = false;


			if leftFruit > rightFruit then
				local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -10)

				local next_wp = { x = next_x, y = next_y, z = next_z }
				table.insert(self.next_targets, next_wp)

				local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -30)

				local next_wp = { x = next_x, y = next_y, z = next_z }
				table.insert(self.next_targets, next_wp)

				mode = 5 -- turn around and then wait for next start
			else
				local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -10)
				local next_wp = { x = next_x, y = next_y, z = next_z }
				table.insert(self.next_targets, next_wp)

				local next_x, next_y, next_z = localToWorld(combine.rootNode, 0, 0, -40)
				local next_wp = { x = next_x, y = next_y, z = next_z }
				table.insert(self.next_targets, next_wp)
				mode = 5
			end
				
		  


			if tipper_percentage >= self.required_fill_level_for_drive_on then
				self.loaded = true
			else
				self.next_ai_state = 1
			end
		end


		local current_offset = self.combine_offset
		local current_offset_positive = math.abs(self.combine_offset)
		
		--TODO: move all that shit over to combines.lua, or better yet base.lua, so it doesn't have to be calculated constantly
		--TODO: always use combineToPrnX, no matter what?
		local prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		local cwX, cwY, cwZ = getWorldTranslation(combine.rootNode)
		local prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		local combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.rootNode, prnwX, prnwY, prnwZ)
		--NOTE by Jakob: after a shitload of testing and failing, it seems combineToPrnX is what we're looking for (instead of prnToCombineX). Always results in correct x-distance from combine.rn to prn.
		--TODO: support for Grimme SE75-55
		

		
		if not cornChopper and self.auto_combine_offset then
			courseplay:debug(string.format("%s(%i): %s: cwX=%f, cwZ=%f, prnwX=%f, prnwZ=%f, combineToPrnX=%f, combineToPrnZ=%f", curFile, debug.getinfo(1).currentline, combine.name, cwX, cwZ, prnwX, prnwZ, combineToPrnX, combineToPrnZ), 2)
		end

		--combine // combine_offset is in auto mode
		if not cornChopper and self.auto_combine_offset and combine.currentPipeState == 2 then
			if getParent(combine.pipeRaycastNode) == combine.rootNode then -- pipeRaycastNode is direct child of combine.root
				--safety distance so the trailer doesn't crash into the pipe (sidearm)
				local additionalSafetyDistance = 0
				if combine.name == "Grimme Maxtron 620" then
					additionalSafetyDistance = 0.9 --0.8
				elseif combine.name == "Grimme Tectron 415" then
					additionalSafetyDistance = -0.5
				end

				current_offset = prnX + additionalSafetyDistance
				courseplay:debug(string.format("%s(%i): %s @ %s: root > pipeRaycastNode // current_offset = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, current_offset), 2)
			elseif getParent(getParent(combine.pipeRaycastNode)) == combine.rootNode then --pipeRaycastNode is direct child of pipe is direct child of combine.root
				local pipeX, pipeY, pipeZ = getTranslation(getParent(combine.pipeRaycastNode))
				current_offset = pipeX - prnZ
				
				if prnZ == 0 or combine.name == "Grimme Rootster 604" then
					current_offset = pipeX - prnY
				end
				courseplay:debug(string.format("%s(%i): %s @ %s: root > pipe > pipeRaycastNode // current_offset = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, current_offset), 2)
			elseif combine.pipeRaycastNode ~= nil then --BACKUP pipeRaycastNode isn't direct child of pipe
				current_offset = combineToPrnX + 0.5
				courseplay:debug(string.format("%s(%i): %s @ %s: combineToPrnX // current_offset = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, current_offset), 2)
			elseif combine.lmX ~= nil then --user leftMarker
				current_offset = combine.lmX + 2.5;
			else --if all else fails
				current_offset = 8;
			end

		--combine // combine_offset is in manual mode
		elseif not cornChopper and not self.auto_combine_offset then
			courseplay:debug(string.format("%s(%i): %s @ %s: combineToPrnX = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, combineToPrnX), 2)
			if combineToPrnX > 0 then
				current_offset = current_offset_positive
			elseif combineToPrnX < 0 then -- pipe on right side
				current_offset = current_offset_positive * -1
				courseplay:debug(string.format("%s(%i): %s @ %s: pipe on right side / current_offset = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, current_offset), 2)
			end
		
		--chopper // combine_offset is in auto mode
		elseif cornChopper and self.auto_combine_offset then
			if combine.lmX ~= nil then
				current_offset = combine.lmX + 2.5
				--courseplay:debug(string.format("%s(%i): %s @ %s: using leftMarker, current_offset = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, current_offset), 2)
			else
				current_offset = 8
				courseplay:debug(string.format("%s(%i): %s @ %s: using default current_offset = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, current_offset), 2)
			end

			if self.sideToDrive == nil then
				local left_fruit, right_fruit = courseplay:side_to_drive(self, combine, -10);
				if left_fruit < right_fruit then
					self.sideToDrive = "left";
				elseif right_fruit < left_fruit then
					self.sideToDrive = "right";
				end
				courseplay:debug(string.format("%s(%i): %s @ %s: sideToDrive first runthrough=%s => current_offset=%f", curFile, debug.getinfo(1).currentline, self.name, combine.name, tostring(self.sideToDrive), current_offset), 2)
			end;
				
			if self.sideToDrive	~= nil then
				if self.sideToDrive == "left" then
					current_offset = math.abs(current_offset);
				elseif self.sideToDrive == "right" then
					current_offset = math.abs(current_offset) * -1;
				end
			end;
		end
		
		--cornChopper forced side offset
		if cornChopper and combine.forced_side ~= nil then
			if combine.forced_side == "left" then
				current_offset = math.abs(current_offset);
			elseif combine.forced_side == "right" then
				current_offset = math.abs(current_offset) * -1;
			end
			courseplay:debug(string.format("%s(%i): %s @ %s: forced_side=%s => current_offset=%f", curFile, debug.getinfo(1).currentline, self.name, combine.name, combine.forced_side, current_offset), 2)
		end

		--refresh for display in HUD and other calculations
		self.combine_offset = current_offset;
		
		

		currentX, currentY, currentZ = localToWorld(combine.rootNode, current_offset, 0, trailer_offset + 5)

		local ttX, ttY, ttZ = localToWorld(combine.rootNode, current_offset, 0, trailer_offset)

		if combine.attachedImplements ~= nil then
			for k, i in pairs(combine.attachedImplements) do
				local implement = i.object;
				if implement.haeckseldolly == true then
					ttX, ttY, ttZ = localToWorld(implement.rootNode, current_offset, 0, trailer_offset)
				end
			end
		end

		local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, ttX, y, ttZ)
		dod = Utils.vector2Length(lx, lz)
		if dod > 40 then
			mode = 2
		end

		-- combine is not moving and trailer is under pipe
		if not cornChopper and ((combine.movingDirection == 0 and lz <= 0.5) or lz < -0.1 * trailer_offset) then
			self.info_text = courseplay:get_locale(self, "CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
			allowedToDrive = false
		elseif cornChopper then
			if combine.movingDirection == 0 and (lz == -1 or dod == -1) then
				allowedToDrive = false
				self.info_text = courseplay:get_locale(self, "CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
			end
			if lz < -2 then
				allowedToDrive = false
				self.info_text = courseplay:get_locale(self, "CPCombineWantsMeToStop")
				--mode = 2
			end
		end

		-- refspeed depends on the distance to the combine
		local combine_speed = combine.lastSpeed

		if lz > 5 then
			refSpeed = self.field_speed
		elseif lz < -3 then
			refSpeed = combine_speed / 2
		elseif combine.sentPipeIsUnloading ~= true then  --!!!
			refSpeed = combine_speed + (1/3600) 
		else
			refSpeed = combine_speed
		end
		courseplay:debug(print("combine.sentPipeIsUnloading: "..tostring(combine.sentPipeIsUnloading).." refSpeed:  "..tostring(refSpeed*3600).." combine_speed:  "..tostring(combine_speed*3600)),3)  
		self.sl = 2

		if (combine.turnStage ~= 0 and lz < 20) or self.timer < self.drive_slow_timer then
			refSpeed = 1 / 3600
			self.sl = 1
			if self.ESLimiter == nil then
				self.motor.maxRpm[self.sl] = 200
			end --!!!
			if combine.turnStage ~= 0 then
				self.drive_slow_timer = self.timer + 2000
			end
		else
			self.sl = 2
		end

		if combine.movingDirection == 0 then
			refSpeed = self.field_speed * 1.5
			if mode == 3 and dod < 20 and cornChopper then
				refSpeed = 1 / 3600 
			end
		end
		---------------------------------------------------------------------
	end -- end mode 3 or 4

	if combine_turning and not cornChopper and combine_fill_level > 0 then
		combine.waitForTurnTime = combine.time + 100
	end

	if combine_turning and distance < 20 then
		if tipper_percentage >= self.required_fill_level_for_drive_on then
			self.loaded = true
		elseif mode == 3 or mode == 4 then
			if cornChopper then
				self.leftFruit, self.rightFruit = courseplay:side_to_drive(self, combine, -10)

				--new chopper turn maneuver by Thomas Gärtner  --!!!
				if self.leftFruit < self.rightFruit then -- chopper will turn left

					if self.combine_offset > 0 then -- I'm left of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm left", curFile, debug.getinfo(1).currentline, self.name, combine.name), 2);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, 0, 0, self.turn_radius);
						courseplay:set_next_target(self, -50 ,  self.turn_radius);
	
					else --i'm right of choppper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm right", curFile, debug.getinfo(1).currentline, self.name, combine.name), 2);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, -50, 0, 0);
					end
					
				else -- chopper will turn right
					if self.combine_offset < 0 then -- I'm right of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm right", curFile, debug.getinfo(1).currentline, self.name, combine.name), 2);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, 0, 0, self.turn_radius);
						courseplay:set_next_target(self, 50,     self.turn_radius);
					else -- I'm left of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm left", curFile, debug.getinfo(1).currentline, self.name, combine.name), 2);
						self.target_x, self.target_y, self.target_z = localToWorld(self.rootNode, 50, 0, 0);
					end
				end
				if combine.forced_side == nil then
					if self.sideToDrive == "right" then
						self.sideToDrive = "left"
					elseif self.sideToDrive == "left" then
						self.sideToDrive = "right"
					end
				else
					self.sideToDrive = combine.forced_side
				end
				if self.sideToDrive == "right" then
					self.combine_offset = math.abs(self.combine_offset) * -1;
				elseif self.sideToDrive == "left" then
					self.combine_offset = math.abs(self.combine_offset);
				end
					

				mode = 5
				self.shortest_dist = nil
				self.next_ai_state = 7
			end
		elseif mode ~= 5 and mode ~= 9 and not self.realistic_driving then
			-- just wait until combine has turned
			allowedToDrive = false
			self.info_text = courseplay:get_locale(self, "CPCombineWantsMeToStop")
		end
	end


	if mode == 7 then
		if combine.movingDirection == 0 then
			mode = 3
		else
			self.info_text = courseplay:get_locale(self, "CPWaitUntilCombineTurned") --  ""
		end
	end


	-- wende man?ver
	if mode == 9 and self.target_x ~= nil and self.target_z ~= nil then
		--courseplay:remove_from_combines_ignore_list(self, combine)
		self.info_text = string.format(courseplay:get_locale(self, "CPTurningTo"), self.target_x, self.target_z)
		allowedToDrive = false
		local mx, mz = self.target_x, self.target_z
		local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, mx, y, mz)
		self.sl = 1
		refSpeed = self.field_speed --self.turn_speed

		if lz > 0 and math.abs(lx) < lz * 0.5 then -- lz * 0.5    --2
			if self.next_ai_state == 4 and not combine_turning then
				self.target_x = nil
				self.target_z = nil
				mode = self.next_ai_state
				self.next_ai_state = 0
			end

			if self.next_ai_state == 1 or self.next_ai_state == 2 then
				-- is there another waypoint to go to?
				if table.getn(self.next_targets) > 0 then
					mode = 5
					self.shortest_dist = nil
					self.target_x = self.next_targets[1].x
					self.target_y = self.next_targets[1].y
					self.target_z = self.next_targets[1].z
					table.remove(self.next_targets, 1)
				else
					mode = self.next_ai_state
					self.next_ai_state = 0
				end
			end
		else
			currentX, currentY, currentZ = localToWorld(self.aiTractorDirectionNode, self.turn_factor, 0, 5)
			allowedToDrive = true
		end
	end



	-- drive to given waypoint
	if mode == 5 and self.target_x ~= nil and self.target_z ~= nil then
		if combine ~= nil then
			--courseplay:remove_from_combines_ignore_list(self, combine)
		end
		self.info_text = string.format(courseplay:get_locale(self, "CPDriveToWP"), self.target_x, self.target_z)
		currentX = self.target_x
		currentY = self.target_y
		currentZ = self.target_z
		self.sl = 2
		refSpeed = self.field_speed

		distance_to_wp = courseplay:distance_to_point(self, currentX, y, currentZ)

		if table.getn(self.next_targets) == 0 then
			if distance_to_wp < 10 then
				refSpeed = self.turn_speed -- 3/3600
				self.sl = 1
			end
		end

		-- avoid circling
		local distToChange = 1
		if self.shortest_dist == nil or self.shortest_dist > distance_to_wp then
			self.shortest_dist = distance_to_wp
		end

		if distance_to_wp > self.shortest_dist and distance_to_wp < 3 then
			distToChange = distance_to_wp + 1
		end

		if distance_to_wp < distToChange then
			if self.next_ai_state == 81 then
				if self.active_combine ~= nil then
					courseplay:unregister_at_combine(self, self.active_combine)
				end
			end

			self.shortest_dist = nil
			if table.getn(self.next_targets) > 0 then
				--	  	mode = 5
				self.target_x = self.next_targets[1].x
				self.target_y = self.next_targets[1].y
				self.target_z = self.next_targets[1].z

				table.remove(self.next_targets, 1)
			else
				allowedToDrive = false
				if self.next_ai_state ~= 2 then
					self.calculated_course = false
				end
				if self.next_ai_state == 7 then

					mode = 7

					--self.target_x, self.target_y, self.target_z = localToWorld(combine.rootNode, self.chopper_offset*0.7, 0, -9) -- -2          --??? *0,5 -10

				elseif self.next_ai_state == 4 and combine_turning then
					self.info_text = courseplay:get_locale(self, "CPWaitUntilCombineTurned") --  ""
				elseif self.next_ai_state == 81 then -- tipper turning from combine

					self.recordnumber = 2
					courseplay:unregister_at_combine(self, self.active_combine)
					self.ai_state = 0
					self.loaded = true

				elseif self.next_ai_state == 1 then
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
		self.info_text = courseplay:get_locale(self, "CPFollowTractor") -- "Fahre hinter Traktor"
		--use the current tractor's sideToDrive as own
		if tractor.sideToDrive ~= nil then
			courseplay:debug(string.format("setting current tractor's sideToDrive (%s) as my own", tractor.sideToDrive));
			self.sideToDrive = tractor.sideToDrive;
		end;

		-- drive behind tractor
		local x1, y1, z1 = worldToLocal(tractor.rootNode, x, y, z)
		local distance = Utils.vector2Length(x1, z1)



		if z1 > 0 then
			-- tractor in front of tractor
			-- left side of tractor
			local cx_left, cy_left, cz_left = localToWorld(tractor.rootNode, 30, 0, -10)
			-- righ side of tractor
			local cx_right, cy_right, cz_right = localToWorld(tractor.rootNode, -30, 0, -10)
			local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(self.aiTractorDirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)
			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end
		else
			-- tractor behind tractor
			--TODO: ORIG: z = -40
			currentX, currentY, currentZ = localToWorld(tractor.rootNode, 0, 0, -30)
		end

		local lx, ly, lz = worldToLocal(self.aiTractorDirectionNode, currentX, currentY, currentZ)
		dod = Utils.vector2Length(lx, lz)

		if dod < 2 or tractor.ai_state ~= 3 then
			allowedToDrive = false
		end

		if distance > 50 then
			refSpeed = self.max_speed
		else
			refSpeed = tractor.lastSpeedReal --10/3600 -- tractor.lastSpeedReal
		end


		--     courseplay:debug(string.format("distance: %d  dod: %d",distance,dod ), 3)
	end


	self.ai_state = mode

	if currentX == nil or currentZ == nil then
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
		courseplay:setSpeed(self, refSpeed, self.sl)
	end



	if g_server ~= nil then
		local target_x, target_z = nil, nil
		if currentX ~= nil and currentZ ~= nil then
			target_x, target_z = AIVehicleUtil.getDriveDirection(self.aiTractorDirectionNode, currentX, y, currentZ)
		else
			allowedToDrive = false
		end

		if not allowedToDrive then
			target_x, target_z = 0, 1
			self.motor:setSpeedLevel(0, false);
			--	AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0, 0, 28, false, moveForwards, lx, lz)
		end


		courseplay:set_traffc_collision(self, target_x, target_z)

		AIVehicleUtil.driveInDirection(self, dt, self.steering_angle, 0.5, 0.5, 8, allowedToDrive, true, target_x, target_z, self.sl, 0.4)

		-- new
	end
end

function courseplay:calculate_course_to(self, target_x, target_z)
	local curFile = "mode2.lua"

	self.calculated_course = true
	-- check if there is fruit between me and the target, return false if not to avoid the calculating
	local node = nil
	if self.aiTractorDirectionNode ~= nil then
		node = self.aiTractorDirectionNode
	else
		node = self.aiTreshingDirectionNode
	end
	local x, y, z = getWorldTranslation(node)
	local hx, hy, hz = localToWorld(node, -2, 0, 0)
	local lx, ly, lz = nil, nil, nil
	local dlx, dly, dlz = worldToLocal(node, target_x, y, target_z)
	local dnx = dlz * -1
	local dnz = dlx
	local angle = math.atan(dnz / dnx)
	dnx = math.cos(angle) * -2
	dnz = math.sin(angle) * -2
	hx, hy, hz = localToWorld(node, dnx, 0, dnz)
	local density = 0
	for i = 1, FruitUtil.NUM_FRUITTYPES do
		if i ~= FruitUtil.FRUITTYPE_GRASS then
			density = density + Utils.getFruitArea(i, x, z, target_x, target_z, hx, hz);
		end
	end
	if density == 0 then
		return false
	end
	if not self.realistic_driving then
		return false
	end
	if self.active_combine ~= nil then
		local fruit_type = self.active_combine.lastValidInputFruitType
	elseif self.tipper_attached then
		local fruit_type = self.tippers[1].getCurrentFruitType
	else
		local fruit_type = nil
	end
	--courseplay:debug(string.format("position x: %d z %d", x, z ), 4)
	local wp_counter = 0
	local wps = CalcMoves(z, x, target_z, target_x, fruit_type)
	--courseplay:debug(table.show(wps), 4)
	if wps ~= nil then
		self.next_targets = {}
		for _, wp in pairs(wps) do
			wp_counter = wp_counter + 1
			local next_wp = { x = wp.y, y = 0, z = wp.x }
			table.insert(self.next_targets, next_wp)
			wp_counter = 0
		end
		self.target_x = self.next_targets[1].x
		self.target_y = self.next_targets[1].y
		self.target_z = self.next_targets[1].z
		self.no_speed_limit = true
		table.remove(self.next_targets, 1)
		self.ai_state = 5
	else
		return false
	end
	return true
end