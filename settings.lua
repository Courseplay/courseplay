function courseplay:change_ai_state(self, change_by)
	self.ai_mode = self.ai_mode + change_by

	if self.ai_mode == 9 or self.ai_mode == 0 then
		self.ai_mode = 1
	end
end

function courseplay:call_player(self)
	if self.wants_courseplayer then --edit for more sites
		self.wants_courseplayer = false
	else
		self.wants_courseplayer = true
	end
end

function courseplay:start_stop_player(self)
	local tractor = self.courseplayers[1]
	if tractor.forced_to_stop then --edit for more sites
		tractor.forced_to_stop = false
	else
		tractor.forced_to_stop = true
	end
end

function courseplay:send_player_home(self)
	local tractor = self.courseplayers[1]
	tractor.loaded = true
end

function courseplay:switch_player_side(self)
	if self.grainTankCapacity == 0 then
		local tractor = self.courseplayers[1]
		if tractor == nil then
			return
		end

		tractor.ai_state = 10

		if tractor.forced_side == nil then
			tractor.forced_side = "left"
		elseif tractor.forced_side == "left" then
			tractor.forced_side = "right"
		else
			tractor.forced_side = nil
		end
	end
end

function courseplay:switch_hud_page(self, change_by)
	self.showHudInfoBase = self.showHudInfoBase + change_by

	if self.showHudInfoBase < self.min_hud_page then --edit for more sites
		self.showHudInfoBase = 7
	end

	if self.showHudInfoBase == 8 then --edit for more sites
		self.showHudInfoBase = self.min_hud_page
	end
end


function courseplay:change_combine_offset(self, change_by)
	local previousOffset = self.combine_offset
	
	self.auto_combine_offset = false
	self.combine_offset = roundCustom(self.combine_offset, 1) + change_by
	if self.combine_offset > -0.1 and self.combine_offset < 0.1 then
		self.combine_offset = 0.0
		self.auto_combine_offset = true
	end
	
	courseplay:debug("manual combine_offset change: prev " .. previousOffset .. " // new " .. self.combine_offset .. " // auto = " .. tostring(self.auto_combine_offset), 2)
end

function courseplay:change_tipper_offset(self, change_by)
	self.tipper_offset = self.tipper_offset + change_by
end


function courseplay:changeCPWpOffsetX(self, change_by)
	self.WpOffsetX = self.WpOffsetX + change_by
end

function courseplay:changeCPWpOffsetZ(self, change_by)
	self.WpOffsetZ = self.WpOffsetZ + change_by
end

function courseplay:changeWorkWidth(self, change_by)
	self.toolWorkWidht = self.toolWorkWidht + change_by
	self.workWidthChanged = self.timer + 2000
	if self.toolWorkWidht < 1 then
		self.toolWorkWidht = 1
	end
end

function courseplay:change_WaypointMode(self, change_by)
	self.waypointMode = self.waypointMode + change_by
	if self.waypointMode == 6 then
		self.waypointMode = 1
	end
	courseplay:RefreshSigns(self)
end


function courseplay:change_required_fill_level_for_drive_on(self, change_by)
	self.required_fill_level_for_drive_on = self.required_fill_level_for_drive_on + change_by

	if self.required_fill_level_for_drive_on < 0 then
		self.required_fill_level_for_drive_on = 0
	end

	if self.required_fill_level_for_drive_on > 100 then
		self.required_fill_level_for_drive_on = 100
	end
end


function courseplay:change_required_fill_level(self, change_by)
	self.required_fill_level_for_follow = self.required_fill_level_for_follow + change_by

	if self.required_fill_level_for_follow < 0 then
		self.required_fill_level_for_follow = 0
	end

	if self.required_fill_level_for_follow > 100 then
		self.required_fill_level_for_follow = 100
	end
end


function courseplay:change_turn_radius(self, change_by)
	self.turn_radius = self.turn_radius + change_by

	if self.turn_radius < 0 then
		self.turn_radius = 0
	end
end


function courseplay:change_turn_speed(self, change_by)
	local speed = self.turn_speed * 3600

	speed = speed + change_by

	if speed < 1 then
		speed = 1
	end
	self.turn_speed = speed / 3600
end

function courseplay:change_wait_time(self, change_by)
	local speed = self.waitTime

	speed = speed + change_by

	if speed < 0 then
		speed = 0
	end
	self.waitTime = speed
end

function courseplay:change_field_speed(self, change_by)
	local speed = self.field_speed * 3600
	speed = speed + change_by
	if speed < 1 then
		speed = 1
	end
	self.field_speed = speed / 3600
end

function courseplay:change_max_speed(self, change_by)
	local speed = self.max_speed * 3600
	speed = speed + change_by
	if speed < 1 then
		speed = 1
	end
	self.max_speed = speed / 3600
end

function courseplay:change_RulMode(self, change_by)
	self.RulMode = self.RulMode + change_by
	if self.RulMode == 4 then
		self.RulMode = 1
	end
end

function courseplay:switch_mouse_right_key_enabled(self)
	self.mouse_right_key_enabled = not self.mouse_right_key_enabled
end

function courseplay:switch_search_combine(self)
	self.search_combine = not self.search_combine
end

function courseplay:switch_realistic_driving(self)
	self.realistic_driving = not self.realistic_driving
end


function courseplay:switch_use_speed(self)
	self.use_speed = not self.use_speed
end

function courseplay:switch_combine(self, change_by)
	local combines = courseplay:find_combines(self)

	local selected_combine_number = self.selected_combine_number + change_by

	if selected_combine_number < 0 then
		selected_combine_number = 0
	end

	if selected_combine_number > table.getn(combines) then
		selected_combine_number = table.getn(combines)
	end

	self.selected_combine_number = selected_combine_number

	if self.selected_combine_number == 0 then
		self.saved_combine = nil
	else
		self.saved_combine = combines[self.selected_combine_number]
	end
end


function courseplay:change_selected_course(self, change_by)

	local selected_course_number = self.selected_course_number
	selected_course_number = selected_course_number + change_by

	local number_of_courses = 0
	for k, trigger in pairs(g_currentMission.courseplay_courses) do
		number_of_courses = number_of_courses + 1
	end

	if selected_course_number >= number_of_courses - 4 then
		selected_course_number = number_of_courses - 5
	end

	if selected_course_number < 0 then
		selected_course_number = 0
	end

	self.selected_course_number = selected_course_number
end

function courseplay:change_num_ai_helpers(self, change_by)
	local num_helpers = g_currentMission.maxNumHirables
	num_helpers = num_helpers + change_by

	if num_helpers < 1 then
		num_helpers = 1
	end

	g_currentMission.maxNumHirables = num_helpers
end

function courseplay:change_DebugLevel(change_by)
	CPDebugLevel = CPDebugLevel + change_by
	if CPDebugLevel == 5 then
		CPDebugLevel = 0
	end
	--print('CPDebugLevel = '..CPDebugLevel)
end

