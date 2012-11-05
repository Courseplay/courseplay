function courseplay:find_combines(self)
	-- reseting reachable combines
	local found_combines = {}
	-- go through all vehicles and find filter all combines
	local all_vehicles = g_currentMission.vehicles
	for k, vehicle in pairs(all_vehicles) do
		-- combines should have this trigger

		-- trying to identify combines
		if courseplay:is_a_combine(vehicle) then
			table.insert(found_combines, vehicle)
		end
	end

	return found_combines
end


function courseplay:is_a_combine(vehicle)
	if vehicle.grainTankCapacity ~= nil then
		return true
	else
		return false
	end
end

function courseplay:combine_allows_tractor(self, combine)
	local num_allowed_courseplayers = 1
	if combine.courseplayers == nil then
		combine.courseplayers = {}
	end

	if combine.grainTankCapacity == 0 then
		num_allowed_courseplayers = 2
	else
		if self.realistic_driving then
			if combine.wants_courseplayer == true then
				return true
			end
			-- force unload when combine is full
			if combine.grainTankFillLevel == combine.grainTankCapacity then
				return true
			end
			-- is the pipe on the correct side?
			if combine.turnStage == 1 or combine.turnStage == 2 then
				return false
			end
			local left_fruit, right_fruit = courseplay:side_to_drive(self, combine, -10)
			if left_fruit > right_fruit then
				return false
			end
		end
	end

	if table.getn(combine.courseplayers) >= num_allowed_courseplayers then
		return false
	end

	if table.getn(combine.courseplayers) == 1 and not combine.courseplayers[1].allow_following then
		return false
	end

	return true
end

-- find combines on the same field (texture)
function courseplay:update_combines(self)

	self.reachable_combines = {}

	if not self.search_combine and self.saved_combine then
		table.insert(self.reachable_combines, self.saved_combine)
		return
	end

	courseplay:debug(string.format("combines total: %d ", table.getn(self.reachable_combines)), 4)

	local x, y, z = getWorldTranslation(self.aiTractorDirectionNode)
	local hx, hy, hz = localToWorld(self.aiTractorDirectionNode, -2, 0, 0)
	local lx, ly, lz = nil, nil, nil
	local terrain = g_currentMission.terrainDetailId

	local found_combines = courseplay:find_combines(self)

	courseplay:debug(string.format("combines found: %d ", table.getn(found_combines)), 4)
	-- go throuh found
	for k, combine in pairs(found_combines) do
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
		if area2 * 0.999 <= area1 and courseplay:combine_allows_tractor(self, combine) then
			table.insert(self.reachable_combines, combine)
		end
	end

	courseplay:debug(string.format("combines reachable: %d ", table.getn(self.reachable_combines)), 4)
end


function courseplay:register_at_combine(self, combine)
	courseplay:debug("registering at combine", 4)
	courseplay:debug(table.show(combine), 4)

	local num_allowed_courseplayers = 1
	self.calculated_course = false
	if combine.courseplayers == nil then
		combine.courseplayers = {}
	end

	if combine.grainTankCapacity == 0 then
		num_allowed_courseplayers = 2
	else
		if self.realistic_driving then
			if combine.wants_courseplayer == true or combine.grainTankFillLevel == combine.grainTankCapacity then

			else
				-- force unload when combine is full
				-- is the pipe on the correct side?
				if combine.turnStage == 1 or combine.turnStage == 2 then
					return false
				end
				local left_fruit, right_fruit = courseplay:side_to_drive(self, combine, -10)
				if left_fruit > right_fruit then
					return false
				end
			end
		end
	end

	if table.getn(combine.courseplayers) == num_allowed_courseplayers then
		return false
	end

	if table.getn(combine.courseplayers) == 1 and not combine.courseplayers[1].allow_following then
		return false
	end

	-- you got a courseplayer, so stop yellin....
	if combine.wants_courseplayer ~= nil and combine.wants_courseplayer == true then
		combine.wants_courseplayer = false
	end

	table.insert(combine.courseplayers, self)
	self.courseplay_position = table.getn(combine.courseplayers)
	self.active_combine = combine

	if math.floor(self.combine_offset) == 0 then

		local leftMarker = nil
		local currentCutter = nil

		for cutter, implement in pairs(combine.attachedCutters) do
			if cutter.aiLeftMarker ~= nil then
				if leftMarker == nil then
					leftMarker = cutter.aiLeftMarker;
					currentCutter = cutter
					local x, y, z = getWorldTranslation(currentCutter.rootNode)
					xt, yt, zt = worldToLocal(leftMarker, x, y, z)

					self.combine_offset = xt + 2.5;
				end;
			end;
		end;

		if combine.typeName == "selfPropelledPotatoHarvester" then
			local x, y, z = getWorldTranslation(combine.rootNode)
			xt, yt, zt = worldToLocal(combine.pipeRaycastNode, x, y, z)
			self.combine_offset = xt * -1
		end

		courseplay:debug("manually setting combine_offset:", 4)
		courseplay:debug(self.combine_offset, 4)
	end

	return true
end





function courseplay:unregister_at_combine(self, combine)
	if self.active_combine == nil or combine == nil then
		return true
	end
	self.calculated_course = false
	--courseplay:remove_from_combines_ignore_list(self, combine)
	table.remove(combine.courseplayers, self.courseplay_position)

	-- updating positions of tractors
	for k, tractor in pairs(combine.courseplayers) do
		tractor.courseplay_position = k
	end

	self.allow_follwing = false
	self.courseplay_position = nil
	self.active_combine = nil
	self.ai_state = 1

	-- if self.trafficCollisionIgnoreList[combine.rootNode] == true then
	--   self.trafficCollisionIgnoreList[combine.rootNode] = nil
	-- end

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