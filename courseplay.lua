--
-- Courseplay v3.40 RC
-- Specialization for Courseplay
--
-- @author  Lautschreier / Hummel / Wolverin0815 / Bastian82 / skydancer / Jakob Tischler / Thomas Gärtner
-- @version:	v3.40 RC (09 May 2013)

courseplay = {
	path = g_currentModDirectory;
	debugLevel = 0;
	--version = "";
};
if courseplay.path ~= nil then
	if not Utils.endsWith(courseplay.path, "/") then
		courseplay.path = courseplay.path .. "/";
	end;
end;

-- working tractors saved in this
working_course_players = {};

function initialize_courseplay()
	source(courseplay.path .. "helpers.lua")
	source(courseplay.path .. "turn.lua")
	source(courseplay.path .. "specialTools.lua")

	-- starting & stopping of courseplay
	source(courseplay.path .. "start_stop.lua")

	-- course recording & resetting
	source(courseplay.path .. "recording.lua")
	source(courseplay.path .. "generateCourse.lua")

	-- drive Modes
	source(courseplay.path .. "mode1.lua")
	source(courseplay.path .. "mode2.lua")
	source(courseplay.path .. "mode4.lua")
	source(courseplay.path .. "mode6.lua")
	source(courseplay.path .. "mode9.lua")

	-- course driving
	source(courseplay.path .. "drive.lua")

	-- Mouse/Key Managment
	source(courseplay.path .. "input.lua")

	-- Infotext
	source(courseplay.path .. "global.lua")

	-- Distance Check
	source(courseplay.path .. "distance.lua")

	-- Visual Waypoints
	source(courseplay.path .. "signs.lua")

	-- Loading/Saving Courses
	source(courseplay.path .. "course_management.lua")

	-- loading/unloading tippers
	source(courseplay.path .. "tippers.lua")

	-- triggers
	source(courseplay.path .. "triggers.lua")

	-- triggers
	source(courseplay.path .. "combines.lua")

	source(courseplay.path .. "debug.lua")

	source(courseplay.path .. "button.lua")
	source(courseplay.path .. "hud.lua")
	source(courseplay.path .. "settings.lua")
	source(courseplay.path .. "courseplay_event.lua")
	source(courseplay.path .. "astar.lua")
	source(courseplay.path .. "fruit.lua")
end;

initialize_courseplay();
