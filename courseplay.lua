--
-- Courseplay v0.95
-- Specialization for Courseplay
--
-- @author  Lautschreier / Hummel / Wolverin0815
-- @version:	v0.9.14.03.11
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
--      24.02.11 refactoring & standalone Mod (hummel)
--      25.02.11 following combine (hummel)
--      26.02.11 unloading combine (hummel)
--      27.02.11 turning  (hummel)
--      01.03.11 supporting BGA (hummel)
--      07.03.11 optimizing speed (hummel)
--      08.03.11 optimized turning
--      09.03.11 multiple courseplayers on a single field
--      11.03.11 added manual start (Wolverin0815)
--      13.03.11 localization (Wolverin0815)
--      14.03.11 mode2 optimizations (hummel)
courseplay = {};

courseplay_path = g_modsDirectory.."/aacourseplay/"

-- working tractors saved in this
working_course_players = {};


-- starting & stopping of courseplay
source(courseplay_path.."inc/start_stop.lua")

-- course recording & resetting
source(courseplay_path.."inc/recording.lua")



-- drive Modes
source(courseplay_path.."inc/mode1.lua")
source(courseplay_path.."inc/mode2.lua")

-- course recording & resetting
source(courseplay_path.."inc/drive.lua")

-- Mouse/Key Managment
source(courseplay_path.."inc/input.lua")

-- Infotext
source(courseplay_path.."inc/global.lua")

-- Distance Check
source(courseplay_path.."inc/distance.lua")

-- Visual Waypoints
source(courseplay_path.."inc/signs.lua")

-- Loading/Saving Courses
source(courseplay_path.."inc/course_management.lua")

-- loading/unloading tippers
source(courseplay_path.."inc/tippers.lua")

-- triggers
source(courseplay_path.."inc/triggers.lua")

-- triggers
source(courseplay_path.."inc/combines.lua")

source(courseplay_path.."inc/debug.lua")

source(courseplay_path.."inc/button.lua")