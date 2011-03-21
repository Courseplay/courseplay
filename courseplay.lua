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
--      16.03.11 HUD added (wolverin0815)
--      17.03.11 optimized turning (hummel)
--      18.03.11 distance and overload mode added (hummel)
courseplay = {};

courseplay_path = g_modsDirectory.."/aacourseplay/"

-- working tractors saved in this
working_course_players = {};


-- starting & stopping of courseplay
source(courseplay_path.."start_stop.lua")

-- course recording & resetting
source(courseplay_path.."recording.lua")



-- drive Modes
source(courseplay_path.."mode1.lua")
source(courseplay_path.."mode2.lua")

-- course recording & resetting
source(courseplay_path.."drive.lua")

-- Mouse/Key Managment
source(courseplay_path.."input.lua")

-- Infotext
source(courseplay_path.."global.lua")

-- Distance Check
source(courseplay_path.."distance.lua")

-- Visual Waypoints
source(courseplay_path.."signs.lua")

-- Loading/Saving Courses
source(courseplay_path.."course_management.lua")

-- loading/unloading tippers
source(courseplay_path.."tippers.lua")

-- triggers
source(courseplay_path.."triggers.lua")

-- triggers
source(courseplay_path.."combines.lua")

source(courseplay_path.."debug.lua")

source(courseplay_path.."button.lua")
source(courseplay_path.."hud.lua")
source(courseplay_path.."settings.lua")