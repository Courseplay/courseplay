--
-- Courseplay v0.9
-- Specialization for Courseplay
--
-- @author  Lautschreier / Hummel
-- @version:	v0.9.24.02.11
-- @testing:    bullgore80
-- @history:	
--      02.01.11/06.02.11 course recording and driving (Lautschreier)
--      14.02.11 added courseMode (Hummel)
--		15.02.11 refactoring and collisiontrigger (Hummel)
--		16.02.11 signs are disapearing, tipper support (Hummel)
--      17.02.11 info text and global saving of "course_players" (Hummel)
--      18.02.11 more than one tipper recognized by tractor // name of tractor in global info message
-- 		19.02.11 trailer unloads on trigger, kegel gefixt // (Hummel/Lautschreier)
--      19.02.11 changed loading/unloading logic, changed sound, added hire() dismiss()  (hummel)
--      19.02.11 auf/ablade logik erweitert - ablade trigger vergrößrt  (hummel)
--      20.02.11 laden/speichern von kursen (hummel)
--      21.02.11 wartepunkte hinzugefügt (hummel)
--      24.02.111 standalone Mod (hummel)

courseplay = {};

-- working tractors saved in this
working_course_players = {};

-- load / draw / update methods
source(g_modsDirectory.."/aacourseplay/inc/base.lua")

-- starting & stopping of courseplay
source(g_modsDirectory.."/aacourseplay/inc/start_stop.lua")

-- course recording & resetting
source(g_modsDirectory.."/aacourseplay/inc/recording.lua")

-- course recording & resetting
source(g_modsDirectory.."/aacourseplay/inc/drive.lua")

-- drive Modes
source(g_modsDirectory.."/aacourseplay/modes/mode1.lua")

-- Mouse/Key Managment
source(g_modsDirectory.."/aacourseplay/inc/input.lua")

-- Infotext
source(g_modsDirectory.."/aacourseplay/inc/global.lua")

-- Distance Check
source(g_modsDirectory.."/aacourseplay/inc/distance.lua")

-- Visual Waypoints
source(g_modsDirectory.."/aacourseplay/inc/signs.lua")

-- Loading/Saving Courses
source(g_modsDirectory.."/aacourseplay/inc/course_management.lua")

-- loading/unloading tippers
source(g_modsDirectory.."/aacourseplay/inc/tippers.lua")

-- triggers
source(g_modsDirectory.."/aacourseplay/inc/triggers.lua")