Fieldwork Course Generator
==========================

This tool is a preview of an extended course generator and
may at some point be integrated into Courseplay 
(https://github.com/Courseplay/courseplay).

It is a standalone tool, that is, currently you won't be 
able to use it from the game directly. Instead, it'll load
a saved field or a fieldwork course previously generated in
Courseplay, then you make some adjustments and save the
customized course.

Note that if you load fieldwork courses the course must have
a headland track as the tool uses the outermost headland track 
to find the field boundary.

You can then load this customized course in the game just
as a Courseplay generated course.

What this preview does:

- generates tracks in any direction
- finds the optimum angle, that is the direction the parallel
  tracks must run in order to have the minimum number of turns.
- makes a best effort to find an angle for non-convex fields 
  which results in continuous tracks
- start the headland tracks at any location.
- link the headland tracks with the parallel track (remember, 
  the parallel tracks start location changes with the angle)
- generate course starting in the center and finishing with
  the headland for sowing and any fieldwork other than 
  harvesting
- interleaved parallel tracks (sorry, don't know the exact term) 
  where you work every second (or 3rd, 4th...) track to prevent Y turns.
- non-convex fields: can generate path for non-convex fields. 
  This is an experimental feature.
  If there is no convex solution for a field or the non-convex
  solution results in significantly less tracks it'll choose the
  non-convex solution.
  A non-convex solution will always have the middle of the field
  divided in two or more blocks which will be worked one by one.
  Once a block is finished, the course will lead to the next block
  on the innermost headland path. This is not optimal but will 
  cover the entire field and the course will always remain within
  the field.
  In general, the algorithm will try to create the minimum amount
  of blocks and avoids creating blocks with just a few tracks.

Upcoming features:

- integration with Courseplay so courses can be generated 
  in game 
- optimized headland track generation to prevent skipping
  fruit at corners.

Installation
============

The package is for Windows and contains everything needed
to run, including a lua interpreter and the LOVE graphical
framework. 

This is the Windows version, I don't have access to Mac 
computers. If you are willing to install lua and LOVE, 
you can run the scripts on a Mac too. 

Just unzip the latest release from https://github.com/pvajko/course-generator/releases
to any folder you like. The release has all the required
tools bundled.

Alternatively, if you have lua and LOVE (love2d.org) installed
and the executables in the PATH you can clone or unzip the
source from git.

Usage
=====

1. Find your game folder. On Windows, this will most likely
   be under My Documents\My Games\FarmingSimulator2017

2. Under that, there is a CoursePlay_Courses folder with
   a subfolder for each installed map. This is where
   the Courseplay courses are stored for each map.
   Note the full path to these folders.

3. MAKE A BACKUP OF YOUR CoursePlay_Courses FOLDER! This is
   a beta version, there may be bugs in there I don't want 
   you to lose your saved courses!

4. Now switch to the folder where you unzipped the course
   generator and type:
   lua.exe startCourseGenerator.lua <full path to course folder>
   for example, on my computer this would be:

   lua53.exe startCourseGenerator.lua "c:\Users\Peter\Documents\My Games\FarmingSimulator2017\CoursePlay_Courses\FS17_coldboroughParkFarm.SampleModMap"
   
   for the Coldborough Farm map. Make sure there is _no_ \ at the very
   end of the folder name just before the ".

5. Alternatively, you can load a previously saved field with:

   lua53.exe startCourseGenerator.lua <full path to a savegame>

   (Courseplay saves the fields into the savegame folder)
   for example, on Savegame 8 on my computer would be:

   lua53.exe startCourseGenerator.lua "c:\Users\Peter\Documents\My Games\FarmingSimulator2017\savegame8

6. You should now see a list which contains either the 
   the saved courses of the map (if you started it with a map folder)
   or the saved fields of the savegame.
   
   Has limited support for course folders: when a new course is created
   from an existing one it'll be in the same folder as the original.
   If created from a field, it'll be in the root folder.

7. Select a fieldwork course or a field by typing in the number of the course 
   and pressing enter. The course generator will use this course
   or field to generate the course.
   If you selected a course, the course generator will use the 
   outermost headland pass of the course without alterations and 
   build everything based on that.
   Remember, the course must have a headland track! 
   Selecting non-fieldwork courses or fieldwork courses with no
   headland tracks will result in errors.

   If you selected a field, the course generator uses the field
   boundary to generate the headland tracks.

8. Next, you have to select the course where you want to save
   the generated course. Or, you can create a new course and
   type in the name.
   
9. After you confirm the creation/overwrite of the course, 
   the course generator window appears showing the outline of the
   field. 

10. Set the width and number of passes using the w/W and p/P keys.

11. Next, you'll have to define where to start the headland track.
    Use the right mouse button to place a marker where your want to 
    start it, just outside the field boundary. 

12. The course is now generated. Green is the headland, blueish   
    are the tracks in the center of the field and the red line is 
    the path between the two.
    The green dot is where the course starts, the red is where it ends.

13. If you want you can reverse the course so it starts in the middle
    and ends with the headland passes. This is great for sowing and 
    other, non harvesting fieldwork.

14. You can experiment with the various settings (you may need to 
    press g to regenerate the course).

15. If you like what you see, press s to save the course.

16. If you are in a game, you'll have to quit it and restart to be 
    able to see the new course, otherwise it won't show up.

17. Load the new course and test.

Thanks for giving it a try. If you have any problems, report it on
github https://github.com/pvajko/course-generator/issues or 
at courseplay@vajko.name.

Peter

