--[[

AUTHOR
Russ Beuker, Dec 2019

COURSEPLAY EDITOR
This was developed as a way to quickly make adjustments to recorded or saved courses.  All editing is done in-game and on-screen by using hotkeys and the mouse.  You can drag waypoints to new positions, insert and delete waypoints, change waypoint type and speed.

CAVEATS
1) This has not been tested on multiplayer.
2) This has not been tested with autodrive.
3) Backup your courses before trying this for the first time.
4) Works with courseplay .00344 and .00350 Dev (didn't try other versions)

DEV NOTES
This file is intended to be included with CoursePlay.  See the bottom of this file for instructions on what to modify in other files.  Most of this will be handled in a merge, but the instructions contain explanations on why we are making the changes.

A SUGGESTION ON LEARNING HOW TO USE THE EDITOR
Let's record a simple course and make a simple change, then drive it and save it.
1) Start a new game where you have some cash and buy a pickup.
2) In the pickup, record a simple course and save it.
3) Set the HUD mode to 'Transfer' and start driving the course from the first waypoint.  Observe.
4) Stop driving and stay in the vehicle.
5) Enable the editor (LEFT CTRL E by default)
6) Move the mouse to the base of one of the waypoint handles. A small sphere will appear at the top of the handle to let you know that you have 'selected' it.  You don't need to click on a waypoint to select it. Just hold your mouse over it instead.  
7) Click and hold the left mouse button while moving the mouse to drag the waypoint.  Release the mouse button to stop dragging the waypoint.
8) Let's test your edit by manually driving the pickup to point at the start of the course, and start driving again.  The truck will follow the edited course.
10) Save the course by using the HUD disk icon and give it a name (since this is the first time we are saving this course).
11) Clear the course ('x' button on the HUD)
12) Load the course again and you'll see the changes in the course.  Make some more changes, and use the save hotkey (LEFT CTRL F6, see F1 for commands) to save this course.  All course handle balls will appear while it is saving, then the editor will toggle off.
13) That's pretty well all there is to it.

USE CASES

1) You just recorded a course, but one or more waypoints are not exactly where you want them.  Solution: Open the editor and drag the waypoints to the desired position.
2) Your recorded course has areas where the speed is too high (or low).  This can happen when a heavily loaded vehicle can't stop in time to load/unload or make a corner.  Solution: Use the hotkeys to adjust the speed of individual waypoints.
3) You recorded a course and forgot to put in a wait/unload/turn/reverse/crossing waypoint.  Solution: Use the hotkeys to insert a waypoint and change its type.
4) Your course has a waypoint that you want to remove.  Solution: Use the hotkeys to delete those waypoints.
5) You like part of your generated course, but want to remove part of it and insert a recorded course.  This might happen in the center of an irregularly shaped field where the up/down paths might not be optimal and for that part of the field, you could do better by driving manually.  Solution: Use the hotkeys to do a 'delete to end' to remove the bad part of the course and then save.  Then record your own course for this strangely shaped area and save it under a different name.  Then clear the courses, load in the original with the deleted points and then append the recorded course and then drag the waypoints to make a nice transition to your recorded course.  Save the combined courses as one course under a new name.  Now you have a good course.  This is great for telling ex. your harvester to go and clean up all those little patches in the turns that it missed earlier.
6) You added a new building to your farm and now your old course is too close to the building, or your course now runs through the building and/or obscures some waypoints.  Solution: Drag the waypoints as needed.  If the building has covered up the waypoints, use the Delete Next Waypoint hotkey to get rid of the hidden waypoints and then build a new path around the building.  This is actually the use case that inspired me to create this editor - I added new buildings and all my carefully laid out courses were invalid.

NOTES
1) You can change the editor key hotkeys like you change the normal game hotkeys.  The courseplay editor hotkeys are at the bottom of the list.
2) You can bring up the in-game control help panel (defaults to F1) to see available editor commands.  These commands, in addition to left clicking the mouse, are the only commands used for the editor.
3) The editor can't create courses from scratch.  It can only edit existing recorded or saved courses.
4) You can undo drags, inserts and single waypoint deletes.  Changing waypoint speed or type, or deleting waypoints to the end or start cannot be undone.  Deleting waypoints to the end or start clears the previous undo history.
5) Dragging is done by selecting a waypoint and then left-clicking and hold while moving the mouse.  Release the mouse button to stop dragging.
6) 'selected' means that the mouse cursor is over an editing handle base (there's a sphere at the bottom of the handle).  Selected waypoints handles will brighten and a white sphere will appear at the top of the handle.  You don't need to click for it to be selected.  Just hovering over it is enough for it to be 'selected'.
7) You can only select one waypoint at a time. There is no multiselect.
8) You must edit while in a vehicle that has a loaded or recorded course.  The editor will be disabled while driving the course or recording.
9) You don't need to save the edited course before driving it.
10) There is a hotkey (LEFT CTRL F6 by default) for saving, which will overwrite the course file.  
11) When you leave a vehicle, or cycle to another vehicle, your unsaved editing changes will be lost.  You will not be prompted to save your changes.  So be sure to save your edits if needed before leaving the vehicle or changing to another vehicle.
12) Changing waypoint types will allow you to change it to inappropriate types, such as putting a TURNEND before a TURNSTART.  This may cause unpredicatable driving, so be sure to use those types properly.
13) IMPORTANT: You can also use the normal save function (disk icon on HUD) to save the edited course, but you'll have to provide a course name.  Think of it as a 'Save as...' button.
14) To understand the courseplay HUD recording 'Turn' button, think of it as a 'Travel' button instead where when you start the 'turn' it it stops working and moves at higher speed to the end, where it starts working again at its normal speed.  Instead of the vehicle following waypoints, courseplay will try to dynamically navigate from the turn start to the turn end position.
15) When you record a course, each waypoint is generated at the center of the vehicle and the speed of the vehicle is recorded.  When you drive the course, there is no guarantee that the center of your vehicle will pass over each waypoint at the recorded speed.  Rather, courseplay and the Giants engine will dynamically calculate the path taken, given vehicle weight, speed, traffic and available space to come up with the actual course travelled.  So this is why you may need to edit your course.
16) Generated courses automatically set the speed to zero, which means that it will determine it's own calculated speed.  If you use the editor to set one of those zero speeds to anything but zero, that speed will be used instead of a calculated speed.  Set it back to zero to use a calculated speed.
17) For a manual course, the speed is never calculated, so enter (or record) whatever speed you like.  The vehicle will try to attain that speed.
18) You can't change the waypoint lane in the editor.  If you insert a waypoint, it will duplicate the selected waypoint lane if it has one.
19) You can delete from the selected waypoint to the end of the course (see F1 for command), or delete from the selected waypoint to the beginning of the course (see F1 for command).
20) You can remove an inner section of the course (let's say the middle third of the course) by: first saving the whole course as A, then deleting the first third and save that as A1, then reload A and delete the last third and save that as A3.  Then load A1 and then load and append course A3.  Then save it as B.  Course B now has the middle third missing and you can edit that as desired.
21) Be sure to keep your course end away from your course beginning or else your vehicle may start to circle aimlessly.  Having the start and end too close together confuses courseplay, so keep it at least, say 5 pickup lengths away.  
22) The editing handle vertical lines can have different colors: orange for normal, wait or unload.  Pinkish for reverse.  Blue for crossing.  Green for turn start.  Red for turn end.
24) It is possible to have a waypoing at the exact same position as another waypoint, and this may happen while creating a crossing waypoint.

TEST SCRIPT
1) Record a course consisting of all waypoint types (wait, unload, crossing, turn start, turn end and reverse).
2) Drive the course (Use a pickup in transfer mode)
3) Enable the editor and drag one waypoint to a new position.
4) Drag another waypoint to a new position.
5) Delete a waypoint.
6) Insert a waypoint.
7) Delete a next waypoint.
8) Undo all changes.  It should return to as you left it in step 2.
9) Select a waypoint and increase the speed by 1.
10) Select a waypoint and decrease the speed by 1.
11) Try changing waypoint types.
12) Delete waypoints to the end.
13) Delete waypoints to the beginning.
14) Save as filename 'test'.
15) Drag another waypoint.
16) Save and overwrite (CTRL-F6)
17) Clear course.
18) Load course 'test'.
19) Course should be as you left it in step 15.
20) Drive the course.
21) Enable the editor and make sure the waypoint info panel is working.
22) Make sure the default hotkeys are shown in F1.
23) Try to change a hotkey mapping.
24) After editing course 'test' and saving it, save the game and then reload the game and see if the course still works.
25) Make sure editor handles are visible in daylight and darkness.
26) Load a large course and make sure framerate is ok.
27) Launch game with Autodrive. You should not be able to edit an autodrive course.

]]

courseEditor = {}
courseEditor.enabled = false  -- whether to allow show editing handles and allow dragging
-- raw mouse info from courseplay:onMouseEvent
courseEditor.guiMouseX = 0   
courseEditor.guiMouseY = 0
courseEditor.guiMouseLastX = 0
courseEditor.guiMouseLastY = 0
courseEditor.guiMouseisDown = false
courseEditor.guiMouseisUp = false
courseEditor.guiMouseButton = 0
-- mouse state 
courseEditor.isPressed = {primary = false, secondary = false}  -- state of the mouse buttons
courseEditor.rayCastHitWorldPos = {x = 0, y = 0, z = 0}  -- the world coordinates of the ground on which the cursor is pointed at
-- waypoints
courseEditor.maxWpDistVisible = 150  -- only draw waypoint handles within this distance from the camera, essential for large courses
courseEditor.guiWpHitMaxRadius = 0.6  -- mouse must be at least this close to the bottom sphere of the handle to select it
courseEditor.guiWpHitMaxRadiusWhileDragging = 10 -- use this larger radius to fix dragging lag
courseEditor.guiWpSelected = 0  -- the currently selected waypoint, zero means no waypoint is selected.  Selected means 'hovering over'
courseEditor.guiWpSelectedSpeed = 0
-- editing
courseEditor.queueUndo = false -- whether we need to do an undo
courseEditor.queueSave = false -- whether we need to save the course data it's already-existing courseStoragexxx.xml file
courseEditor.isSaving = false -- whether we are currently saving (for showing the saving animation)
courseEditor.queueIncreaseSpeed = false
courseEditor.queueDecreaseSpeed = false
courseEditor.queueDelete = false
courseEditor.queueDeleteNext = false
courseEditor.queueDeleteToEnd = false
courseEditor.queueDeleteToStart = false
courseEditor.queueInsert = false
courseEditor.queueCycleType = false
courseEditor.waypointTypes = {'normal', 'wait', 'unload', 'crossing', 'turnStart', 'turnEnd', 'reverse'}
courseEditor.waypointTypeIndex = 0
-- waypoint editor handles
courseEditor.pointScale = {x=7, y=7, z=7}  -- scaling for the top and bottom handle spheres
-- dragging
courseEditor.isDragging = false -- whether dragging is occurring
courseEditor.historyAdded = false -- whether we have added the pre-drag position of this waypoint to the history
courseEditor.dragIgnoreDist = 0.0 --0.0025  -- you have to drag it this far before it actually starts to drag, like a deadzone
courseEditor.dragOrigin = {x = 0, y = 0} -- mouse coords where dragging started with left mouse button
courseEditor.history = {} -- when dragging starts, the waypoint's pre-drag coordinates are added to the history table. 
-- wp info panel
courseEditor.overlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds') 

-- determine if the current course is an autodrive course
function courseEditor:isAutoDriveCourse(vehicle)
  local cID = nil
  if g_currentMission.cp_courses ~= nil then
    for _, course in pairs(g_currentMission.cp_courses) do
      if course.name == vehicle.cp.currentCourseName then
        cID = course.id
        break
      end
    end
  end
  return  (cID ~= nil and cID > 9999)
end

-- enable/disable editor via hotkey
function courseEditor:setEnabled(value, vehicle)
  if value then
    if not vehicle.cp.isRecording and not self:isAutoDriveCourse(vehicle) and #vehicle.Waypoints > 0 then
      self.enabled = value
      vehicle.cp.settings.showVisualWaypoints:set(ShowVisualWaypointsSetting.ALL)
	  self:addInputHelp()
    end
  else
    self.enabled = value
    vehicle.cp.visualWaypointsAl = false
    self:clearInputHelp()
    self:reset()
  end
end

-- add entries to the input help panel (via F1 keypress, usually)
function courseEditor:addInputHelp()
  g_currentMission.hud.inputHelp:clearCustomEntries()
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_TOGGLE', '', "Toggle course editor", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_UNDO', '', "Undo last course change", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_SAVE', '', "Save course changes", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_SPEED_DECREASE', '', "Decrease waypoint speed", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_SPEED_INCREASE', '', "Increase waypoint speed", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_DELETE_WAYPOINT', '', "Delete waypoint", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_DELETE_NEXT_WAYPOINT', '', "Delete next waypoint", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_DELETE_TO_START', '',"Delete wayoints to start", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_DELETE_TO_END', '', "Delete waypoints to end", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_INSERT_WAYPOINT', '', "Insert waypoint", false)
  g_currentMission.hud.inputHelp:addCustomEntry('COURSEPLAY_EDITOR_CYCLE_WAYPOINT_TYPE', '', "Change waypoint type", false)
end

-- remove our custom input help panel entries
function courseEditor:clearInputHelp()
  g_currentMission.hud.inputHelp:clearCustomEntries()
end

-- call reset when entering a vehicle or after saving a course via hotkey
function courseEditor:reset()
  self.enabled = false
  self.queueSave = false
  self.isSaving = false
  self.queueDeleteToStart = false
  self.queueDeleteToEnd = false
  self.queueDelete = false
  self.queueDeleteNext = false
  self.queueCycleType = false
  self.queueInsert = false
  self.isPressed = {primary = false, secondary = false}
  self.rayCastHitWorldPos = {x = 0, y = 0, z = 0} 
  self.guiWpSelected = 0 
  self.guiWpSelectedSpeed = 0
  self.isDragging = false 
  self.dragOrigin = {x = 0, y=0}
  self.queueUndo = false
  self.historyAdded = false
  self.waypointTypeIndex = 0
  self:clearHistory()
  self:clearInputHelp()
end

-- clears the undo history
function courseEditor:clearHistory()
  for k in pairs (self.history) do
    self.history [k] = nil
  end
end

-- performs an undo.  
function courseEditor:undo()
  if self.enabled and not self.queueSave and not self.isSaving then
    self.queueUndo = true 
  end
end

-- save the course (overwrites the current course file)
function courseEditor:save()
  if self.enabled and not self.queueSave and not self.isSaving then
    self.queueSave = true
  end
end

-- increase the speed of the selected waypoint
function courseEditor:increaseSpeed()
  if self.enabled and self.guiWpSelectedSpeed < 100 then
    self.queueIncreaseSpeed = true 
  end
end

-- decreases the speed of the selected waypoint
function courseEditor:decreaseSpeed()
  if self.enabled and self.guiWpSelectedSpeed > 0 then
    self.queueDecreaseSpeed = true 
  end
end

-- deletes the selected waypoint
function courseEditor:delete()
  if self.enabled then
    self.queueDelete = true 
  end
end

-- deletes the next waypaint after the selected waypoint
-- useful if you can't see the waypoint you want to delete
function courseEditor:deleteNext()
  if self.enabled then
    self.queueDeleteNext = true 
  end
end

-- deletes all waypoints from the selected waypoint to the end
function courseEditor:deleteToEnd()
  if self.enabled then
    self.queueDeleteToEnd = true 
  end
end

-- deletes all waypoints from the selected waypoint to the start
function courseEditor:deleteToStart()
  if self.enabled then
    self.queueDeleteToStart = true 
  end
end

-- inserts a waypoint immediately after the selected waypoint
function courseEditor:insert()
  -- need to avoid inserting inbetween Turn waypoints
  if self.enabled then
    self.queueInsert = true 
  end  
end

-- changes the waypoint type of the selected waypoint
function courseEditor:cycleType()
  if self.enabled then
    self.queueCycleType = true 
  end    
end

-- calculate the current mouse state so we can know if we are dragging
function courseEditor:updateMouseState(vehicle, posX, posY, isDown, isUp, mouseButton)
  if not self.enabled then return end  
  if vehicle.cp.isRecording then return end
  if vehicle.cp.isDriving then return end
  self.guiMouseX = posX
  self.guiMouseY = posY
  self.guiMouseisDown = isDown
  self.guiMouseisUp = isUp
  self.guiMouseButton = mouseButton  
  --which buttons are pressed?
  if self.guiMouseButton == courseplay.inputBindings.mouse.primaryButtonId and self.guiMouseisDown then
    self.isPressed.primary = true
    self.dragOrigin.x = self.guiMouseX
    self.dragOrigin.y = self.guiMouseY
  end
  if self.guiMouseButton == courseplay.inputBindings.mouse.primaryButtonId and self.guiMouseisUp then
    self.isPressed.primary = false
  end
  -- reset history flag?
  if self.historyAdded and self.isDragging and not self.isPressed.primary then
    self.historyAdded = false
  end
end  

-- calc the current courseid from course name
function courseEditor:getCurrentCourseID(vehicle)
  local cID = nil
  if g_currentMission.cp_courses ~= nil then
    for _, course in pairs(g_currentMission.cp_courses) do
      if not course.virtual and course.name == vehicle.cp.currentCourseName then
        cID = course.id
        break
      end
    end
  end 
  return cID
end
      
-- this is called when the raycast has detected the ground under the mouse cursor
-- this will tell us where on the ground we are pointing to
function courseEditor:groundRaycastCallback(hitObjectId, x, y, z, distance)
  if hitObjectId ~= nil then
      local objectType = getRigidBodyType(hitObjectId)
      if objectType ~= "Dynamic" and objectType ~= "Kinematic" then
          self.rayCastHitWorldPos.x = x
          self.rayCastHitWorldPos.y = y
          self.rayCastHitWorldPos.z = z
          return false
      end
  end
  return true
end

-- draw the handles and perform actions caused by hotkeys and mouse
function courseEditor:draw(vehicle)
	if not self.enabled then return end
	if vehicle ~= g_currentMission.controlledVehicle then return; end;
	if #vehicle.Waypoints == 0 then  -- check if we just unloaded the course
		self: reset()
		return
	end
	local height = 4.5;
	local isHit = false
	local dist = 0
	local guiAdjustedWpHitMaxRadius = self.guiWpHitMaxRadius
	local sx,sy,sz
	local abs = math.abs
	local selectedColor = {r=1.0, g=1.0, b=1.0} -- selected waypoint handle color
	local unselectedColor = {r=0.0, g=1.0, b=1.0} -- unselected waypoint handle color
	local savingColor = {r=1.0, g=1.0, b=1.0} -- waypoint handle color while saving
	self.guiWpSelectedSpeed = 0

	-------------------------------------------------------------------------------

	-- for adjusting brightness of handles when they are selected
	local function adjustBrightness(color, factor)  -- 0 to 0.99 decrease brightness, 1.01 to 2 increase brightness
		color.r = color.r * factor
		color.g= color.g * factor
		color.b = color.b * factor
		return color
	end

	-- calculate the waypoint type, which is useful to know when changing waypoint types
	local function calcWaypointTypeIdx(wpid)
		local tpidx = 1
		--  {'normal', 'wait', 'unload', 'crossing', 'turnStart', 'turnEnd', 'reverse'}
		if vehicle.Waypoints[wpid].wait then tpidx = 2
			elseif vehicle.Waypoints[wpid].unload then tpidx = 3
			elseif vehicle.Waypoints[wpid].crossing then tpidx = 4
			elseif vehicle.Waypoints[wpid].turnStart then tpidx = 5
			elseif vehicle.Waypoints[wpid].turnEnd then tpidx = 6
			elseif vehicle.Waypoints[wpid].rev then tpidx = 7
		end
		return tpidx
	end

	-------------------------------------------------------------------------------

	-- the visual representation of a waypoint that can be grabbed with the mouse
	-- the color of the vertical lines gives an indication of what type of waypoint it is
	local function drawHandle(wpMe, wpMeID, isSelected, isDragging, isSaving, signColor)
		local color
		local horizLinesColor
		local vertLinesColor
		-- calc color
		if isSaving then
			color = savingColor
			horizLinesColor = savingColor
			signColor = savingColor
			vertLinesColor = savingColor
		else
			if isSelected then
				color = selectedColor
				horizLinesColor = unselectedColor
				vertLinesColor = signColor
			else
				color = unselectedColor
				horizLinesColor = unselectedColor
				vertLinesColor = signColor
			end
		end
		local f
		if isSelected then f = 1.5 else f = 1.0 end
		signColor = adjustBrightness(vertLinesColor, f)
		-- vertical line
		cpDebug:drawLine(wpMe.cx, wpMe.cy, wpMe.cz, vertLinesColor.r, vertLinesColor.g, vertLinesColor.b, wpMe.cx, wpMe.cy + height, wpMe.cz)

		-- Horizontal lines
		-- Draw lower line connecting the waypoint to both the previous and next waypoint.
		--   We do this to avoid lines disappearing at the edge of the screen due to the use of the function 'project'
		--   which helps us not draw waypoint handles that we could not possibly see.
		--   Although we'll draw both the lines right on top of each other, this is worth it framerate-wise since we
		--   are showing far fewer lines than if we did not use project.
		local wpNext = vehicle.Waypoints[wpMeID + 1]
		if  wpNext ~= nil then
			if wpNext.cy == nil or wpNext.cy == 0 then
				wpNext.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wpNext.cx, 1, wpNext.cz)
			end
			cpDebug:drawLine(wpMe.cx, wpMe.cy + 0.20, wpMe.cz, horizLinesColor.r, horizLinesColor.g, horizLinesColor.b, wpNext.cx, wpNext.cy + 0.20, wpNext.cz)
		end
		-- horizontal ground line to previous handle
		local wpPrev = vehicle.Waypoints[wpMeID - 1]
		if wpPrev ~= nil then
			if wpPrev.cy == nil or wpPrev.cy == 0 then
				wpPrev.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wpPrev.cx, 1, wpPrev.cz)
			end
			cpDebug:drawLine(wpMe.cx, wpMe.cy + 0.20, wpMe.cz, horizLinesColor.r, horizLinesColor.g, horizLinesColor.b, wpPrev.cx, wpPrev.cy + 0.20, wpPrev.cz)
		end

		-- upper sphere
		if isSelected or isSaving then
			cpDebug:drawPoint(wpMe.cx, wpMe.cy + height, wpMe.cz, color.r, color.g, color.b)
		end

		-- lower sphere
		if not isDragging then
			cpDebug:drawPoint(wpMe.cx, wpMe.cy, wpMe.cz, color.r, color.g, color.b)
		end
	end

	-------------------------------------------------------------------------------
	-- are we saving?  Adjust handle colors and reset the editor after save is done
	if self.isSaving then
		if courseplay:timerIsThrough(vehicle, 'courseEditorSaving') then
			courseplay:resetCustomTimer(vehicle, "courseEditorSaving", true);
			local cID = self:getCurrentCourseID(vehicle)
			if cID ~= nil then
				self.isSaving = false

				-- save it
				courseEditor:doSaveCourseAction(vehicle, cID);

				self:reset()
			end
			self.isSaving = false
			return
		end
	end

	-------------------------------------------------------------------------------

	-- are we dragging?
	if self.isPressed.primary then
		self.historyReverted = false
		self.isDragging = (abs(self.dragOrigin.x - self.guiMouseX) > self.dragIgnoreDist) or (math.abs(self.dragOrigin.y - self.guiMouseY) >  self.dragIgnoreDist)
	else
		self.isDragging = false
		self.guiWpSelected = 0
	end

	-------------------------------------------------------------------------------

	-- find the world coords on the ground under the cursor
	local activeCam = getCamera()
	if activeCam ~= nil then
		-- where is the camera world position and what direction is it from the camera to the ground that the cursor is over?
		local hx, hy, hz, px, py, pz = RaycastUtil.getCameraPickingRay(self.guiMouseX, self.guiMouseY, activeCam)
		-- now raycast the camera position and direction to find exactly where on the ground that the cursor is over
		--raycastClosest(hx, hy, hz, px, py, pz, "groundRaycastCallback", self.maxWpDistVisible - 1, self, 63)    --63
		raycastClosest(hx, hy, hz, px, py, pz, "groundRaycastCallback", self.maxWpDistVisible - 1, self, 1)    --63
		-- iterate through all waypoints, but only allow editing of nearby visible waypoints to preserve framerate on large courses
		for i,wp in pairs(vehicle.Waypoints) do
			if wp.cy == nil or wp.cy == 0 then
				wp.cy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.cx, 1, wp.cz)
			end
			-- project the waypoint onto the screen
			sx,sy,sz = project(wp.cx, wp.cy, wp.cz)
			-- only consider visible waypoints
			if (sx ~= nil and sy ~= nil and sz ~= nil) and ((sx < 1 and sx > 0) and (sy < 1 and sy > 0)  and (sz < 1)) then
				-- also only consider nearby waypoints
				dist = courseplay:distance3D(hx, hy, hz, wp.cx, wp.cy, wp.cz)
				if dist < self.maxWpDistVisible then
					-- if we have already have a 'hit' waypoint, increase the maxradius to prevent dragging lag and fails
					if self.guiWpSelected == 0 then
						guiAdjustedWpHitMaxRadius = self.guiWpHitMaxRadius
					else
						guiAdjustedWpHitMaxRadius = self.guiWpHitMaxRadiusWhileDragging
					end
					-- calc the handle vertical line color
					local sign = g_i18n:getText('COURSEPLAY_EDITOR_NORMAL');
					local signColor = {r=1.0, g=0.212, b=0.0}  -- orange
					if wp.wait then
						sign = g_i18n:getText('COURSEPLAY_EDITOR_WAIT');
						signColor = {r=1.0, g=0.212, b=0.0}  -- orange
					elseif wp.unload then
						sign = g_i18n:getText('COURSEPLAY_EDITOR_UNLOAD');
						signColor = {r=1.0, g=0.212, b=0.0}  -- orange
					elseif wp.crossing then
						sign = g_i18n:getText('COURSEPLAY_EDITOR_CROSSING');
						signColor = {r=0.0, g=0.212, b=0.212}  -- blueish
					elseif wp.rev then
						sign = g_i18n:getText('COURSEPLAY_EDITOR_REVERSE');
						signColor = {r=0.44, g=0.00, b=0.41}  -- pinkish
					elseif wp.turnStart then
						sign = g_i18n:getText('COURSEPLAY_EDITOR_TURNSTART');
						signColor = {r=0.00, g=0.8, b=0.0} -- green
					elseif wp.turnEnd then
						sign = g_i18n:getText('COURSEPLAY_EDITOR_TURNEND');
						signColor = {r=0.8, g=0.0, b=0.00}  -- red
					end
					if i == 1 or i == #vehicle.Waypoints then
						signColor = {r=1.0, g=0.212, b=0.0} -- orange
					end
					-- Are we close enough to the waypoint with the cursor so that we should hover?
					-- If we hover, that is known as 'selecting'.
					isHit = (abs(self.rayCastHitWorldPos.x - wp.cx) < guiAdjustedWpHitMaxRadius) and
					        (abs(self.rayCastHitWorldPos.z - wp.cz) < guiAdjustedWpHitMaxRadius) and
					        ((self.guiWpSelected == 0) or (self.guiWpSelected == i)) and
					        not vehicle:getIsCourseplayDriving()
					if isHit then
						self.waypointTypeIndex = calcWaypointTypeIdx(i)
						-- is hotkey pressed to increase speed?
						if self.queueIncreaseSpeed then
							courseEditor:doIncreaseSpeedAction(vehicle, i);
							self.queueIncreaseSpeed = false
						end
						-- is hotkey pressed to decrease speed?
						if self.queueDecreaseSpeed then
							courseEditor:doDecreaseSpeedAction(vehicle, i);
							self.queueDecreaseSpeed = false
						end
						self.guiWpSelectedSpeed = wp.speed
						-- draw the waypointnumber:speed:sign info panel
						local saction = ''
						if wp.generated and wp.speed == 0 then
							saction = string.format("%d:auto:%s", i, sign)
						else
							local speed = wp.speed and string.format('%d', wp.speed) or '--'
							local speedUnit = utf8ToUpper(g_i18n:getSpeedMeasuringUnit())
							saction = string.format("%d:%s %s:%s", i, speed, speedUnit, sign)
						end
						if wp.lane then
							saction = saction .. string.format(' (%s: %d)', g_i18n:getText('COURSEPLAY_HEADLAND'), -wp.lane)
						end
						local theight = 0.025
						local overlayColor = {r = 0, g = 0, b = 0, a = 0.85}
						local overlayWidth = getTextWidth(theight, saction) + 0.015
						local overlayHeight = 0.045
						-- render text background
						setOverlayColor(self.overlayId, overlayColor.r, overlayColor.g, overlayColor.b, overlayColor.a )
						renderOverlay(self.overlayId, (0.5 - (overlayWidth) / 2), 0.99 - overlayHeight, overlayWidth, overlayHeight)
						-- render text
						setTextAlignment(1)
						setTextColor(1, 1, 1, 1)
						renderText(0.5, 0.958, theight, saction)
						-- dragging waypoint code goes here
						if self.isDragging then
							-- add the waypoint position to undo history only if we are just starting to drag
							if not self.historyAdded then
								table.insert(self.history, {action="dragto", wp = i, x = wp.cx, y = wp.cy, z = wp.cz})
								self.historyAdded = true
							end

							local wpInfo = {
								cx=self.rayCastHitWorldPos.x,
								cy=self.rayCastHitWorldPos.y,
								cz=self.rayCastHitWorldPos.z
							};
							-- move the signs
							courseEditor:doDragToAction(vehicle, i, wpInfo);

							-- update the 2D course plot
							vehicle.cp.course2dUpdateDrawData = true;
						end
						self.guiWpSelected = i  -- this is the selected waypoint
					end
					-- draw handles
					drawHandle(wp, i, (self.guiWpSelected == i), self.isDragging, self.isSaving, signColor)
				end
			end
		end
	end

	-------------------------------------------------------------------------------

	-- do we need to do an undo? (initiated by hotkey)
	if self.queueUndo then
		if #self.history ~= 0 then
			--if not self.historyAdded then
		    local action = self.history[#self.history].action
			local wpIndex = self.history[#self.history].wp
		    if action == 'dragto' then
				local wpInfo = {
					cx=self.history[#self.history].x,
					cy=self.history[#self.history].y,
					cz=self.history[#self.history].z
				};
				-- Undo dragto
				courseEditor:doUndoDragToAction(vehicle, wpIndex, wpInfo);
			elseif action == 'delete' then
				local wpInfo = {
					cx=self.history[#self.history].x,
					cy=self.history[#self.history].y,
					cz=self.history[#self.history].z,
					angle=self.history[#self.history].angle,
					speed=self.history[#self.history].speed
				};
				-- Undo delete
				courseEditor:doUndoDeleteAction(vehicle, wpIndex, wpInfo);
			elseif action == 'insert' then
				-- Undo insert
				courseEditor:doUndoInsertAction(vehicle,wpIndex);
		    end

			-- remove this from the history
			table.remove(self.history)

		    vehicle.cp.waypointIndex = 1
		    vehicle.cp.course2dUpdateDrawData = true;
			--end
		end
		self.historyAdded = false
		self.queueUndo = false
	end

	-------------------------------------------------------------------------------

	-- do we need to save? (initiated by hotkey, not the disk icon on hud)
	if self.queueSave and not self.isSaving then
		local cID = self:getCurrentCourseID(vehicle)
		if cID ~= nil then -- don't save an unsaved course
			-- the timer will give it a chance to paint the handles in the saving color
			-- before the actual potentially-lengthy saving begins
			courseplay:setCustomTimer(vehicle, 'courseEditorSaving', 0.2);
			self.isSaving = true
		end
		self.queueSave = false
	end

	-------------------------------------------------------------------------------

	-- do we need to delete a waypoint? (initiated by hotkey)
	if self.queueDelete then
		if self.guiWpSelected ~= 0 then
			-- don't delete if it's the start or end waypoint
			if self.guiWpSelected ~= 1 and self.guiWpSelected ~= #vehicle.Waypoints then
				 --add to history
				table.insert(self.history, {action="delete",
					wp = self.guiWpSelected,
					x = vehicle.Waypoints[self.guiWpSelected].cx,
					y = vehicle.Waypoints[self.guiWpSelected].cy,
					z = vehicle.Waypoints[self.guiWpSelected].cz,
					angle = vehicle.Waypoints[self.guiWpSelected].angle,
					speed = vehicle.Waypoints[self.guiWpSelected].speed,
					lane = vehicle.Waypoints[self.guiWpSelected].lane}
				)

				-- Delete Selected WP
				courseEditor:doDeleteSelectedAction(vehicle,self.guiWpSelected);
			end
		end
		self.queueDelete = false
		vehicle.cp.course2dUpdateDrawData = true;
	end

	  -------------------------------------------------------------------------------

	-- do we need to delete the next waypoint? (initiated by hotkey)
	if self.queueDeleteNext then
		if self.guiWpSelected ~= 0 then
			-- don't delete if it's the start or end waypoint
			if self.guiWpSelected + 1 ~= #vehicle.Waypoints then
				--add to history
				table.insert(self.history, {action="delete",
				    wp = self.guiWpSelected + 1,
				    x = vehicle.Waypoints[self.guiWpSelected + 1].cx,
				    y = vehicle.Waypoints[self.guiWpSelected + 1].cy,
				    z = vehicle.Waypoints[self.guiWpSelected + 1].cz,
				    angle = vehicle.Waypoints[self.guiWpSelected + 1].angle,
				    speed = vehicle.Waypoints[self.guiWpSelected + 1].speed,
				    lane = vehicle.Waypoints[self.guiWpSelected + 1].lane}
				)

				-- Delete Next
				courseEditor:doDeleteNextAction(vehicle,self.guiWpSelected);
			end
		end
		self.queueDeleteNext = false
		vehicle.cp.course2dUpdateDrawData = true;
	end

	-------------------------------------------------------------------------------

	-- do we need to delete to start? (initiated by hotkey)
	if self.queueDeleteToStart then
		if self.guiWpSelected ~= 0 then
			-- don't delete if it's the start or end waypoint
			if self.guiWpSelected ~= 1 and self.guiWpSelected ~= #vehicle.Waypoints then
				-- Delete from selected WP to Start
				courseEditor:doDeleteToStartAction(vehicle, self.guiWpSelected);

				-- clear the history because we don't store these potentially huge changes
				self:clearHistory();
			end
		end
		vehicle.cp.waypointIndex = 1
		self.queueDeleteToStart = false
		vehicle.cp.course2dUpdateDrawData = true;
	end

	-------------------------------------------------------------------------------

	-- do we need to delete to end? (initiated by hotkey)
	if self.queueDeleteToEnd then
		if self.guiWpSelected ~= 0 then
			-- don't delete if it's the start or end waypoint
			if self.guiWpSelected ~= 1 and self.guiWpSelected ~= #vehicle.Waypoints then
				-- Delete from selected WP to End
				courseEditor:doDeleteToEndAction(vehicle, self.guiWpSelected)

				-- Clear the history because we don't store these potentially huge changes
				self:clearHistory();
			end
		end
		vehicle.cp.waypointIndex = 1
		self.queueDeleteToEnd = false
		vehicle.cp.course2dUpdateDrawData = true;
	end

	-------------------------------------------------------------------------------

	-- do we need to inert a waypoint? (initiated by hotkey)
	if self.queueInsert then
		if self.guiWpSelected ~= 0 and self.guiWpSelected ~= #vehicle.Waypoints then
			local cp = {x=vehicle.Waypoints[self.guiWpSelected].cx, y=vehicle.Waypoints[self.guiWpSelected].cz}
			local np = {x=vehicle.Waypoints[self.guiWpSelected + 1].cx, y=vehicle.Waypoints[self.guiWpSelected + 1].cz}
			local midPNx, midPNz = getPointInTheMiddle(cp, np )
			local midPNy=getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, midPNx, 1, midPNz)
			-- add to history table
			table.insert(self.history, {action="insert",
			    wp = self.guiWpSelected + 1}
			)
			-- insert into the waypoint table
			courseEditor:doInsertAction(vehicle,self.guiWpSelected,midPNx,midPNy,midPNz);
		end
		vehicle.cp.waypointIndex = 1
		self.queueInsert = false
		vehicle.cp.course2dUpdateDrawData = true;
	end

	-------------------------------------------------------------------------------

	-- cycle through the waypoint types.  This is not added to undo history.
	-- cycling is not smart.  It will allow you to change to a type that is not appropriate
	if self.queueCycleType then
		if self.guiWpSelected ~= 0 then
			-- don't cycle if it's the start or end waypoint
			if self.guiWpSelected ~= 1 and self.guiWpSelected ~= #vehicle.Waypoints then
				if self.waypointTypeIndex + 1 > #self.waypointTypes then
					self.waypointTypeIndex = 1
				else
					self.waypointTypeIndex = self.waypointTypeIndex + 1
				end
				--  {'normal', 'wait', 'unload', 'crossing', 'turnStart', 'turnEnd', 'reverse'}
				local tp = self.waypointTypes[self.waypointTypeIndex] -- TODO: Is this needed ? it's not used anywhere inside this function

				-- Change the selected waypoint
				courseEditor:doChangeTypeAction(vehicle,self.guiWpSelected,self.waypointTypeIndex);
			end
		end
		vehicle.cp.waypointIndex = 1
		self.queueCycleType = false
	end
end

-- Action: Save the course (overwrites the current course file)
function courseEditor:doSaveCourseAction(vehicle, courseID, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"SaveCourse", courseID, noEventSend);

	--- Update speed
	courseplay.courses:saveCourseToXml(courseID, nil, true)
	courseplay.settings.setReloadCourseItems()
	courseplay.signs:updateWaypointSigns(vehicle)
	--save it again to guarantee the angles are recalculated -- TODO: Is this really needed to save it twice?
	courseplay.courses:saveCourseToXml(courseID, nil, true)
	courseplay.settings.setReloadCourseItems()
end

-- Action: Increase the speed of the selected waypoint
function courseEditor:doIncreaseSpeedAction(vehicle, guiWpSelected, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"IncreaseSpeed", guiWpSelected, noEventSend);

	--- Update speed
	vehicle.Waypoints[guiWpSelected].speed = vehicle.Waypoints[guiWpSelected].speed + 1
end

-- Action: Decreases the speed of the selected waypoint
function courseEditor:doDecreaseSpeedAction(vehicle, guiWpSelected, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"DecreaseSpeed", guiWpSelected, noEventSend);

	--- Update speed
	vehicle.Waypoints[guiWpSelected].speed = vehicle.Waypoints[guiWpSelected].speed - 1
end

-- Action: Update waypoint to where it's draged to
function courseEditor:doDragToAction(vehicle, guiWpSelected, wpInfo, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"DragTo", {wpSelected=guiWpSelected, wpInfo=wpInfo}, noEventSend);

	--- Update waypoints
	vehicle.Waypoints[guiWpSelected].cx = wpInfo.cx
	vehicle.Waypoints[guiWpSelected].cy = wpInfo.cy
	vehicle.Waypoints[guiWpSelected].cz = wpInfo.cz
	-- move the signs

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle, 'all', guiWpSelected - 1)
	courseplay.signs:updateWaypointSigns(vehicle, 'all', guiWpSelected)
end

-- Action: Undo dragto.
function courseEditor:doUndoDragToAction(vehicle, guiWpSelected, wpInfo, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"UndoDragTo", {wpSelected=guiWpSelected, wpInfo=wpInfo}, noEventSend);

	--- Undo dragto
	vehicle.Waypoints[guiWpSelected].cx = wpInfo.cx
	vehicle.Waypoints[guiWpSelected].cy = wpInfo.cy
	vehicle.Waypoints[guiWpSelected].cz = wpInfo.cz

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle, 'all', guiWpSelected - 1)
	courseplay.signs:updateWaypointSigns(vehicle, 'all', guiWpSelected)
end

-- Action: Undo delete wp.
function courseEditor:doUndoDeleteAction(vehicle, guiWpSelected, wpInfo, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"UndoDelete", {wpSelected=guiWpSelected, wpInfo=wpInfo}, noEventSend);

	--- Undo delete WP
	table.insert(vehicle.Waypoints,	guiWpSelected, wpInfo);

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle)
end

-- Action: Undo insert wp.
function courseEditor:doUndoInsertAction(vehicle, guiWpSelected, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"UndoInsert", guiWpSelected, noEventSend);

	--- Undo insert WP
	table.remove(vehicle.Waypoints, guiWpSelected);

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle);
end

-- Action: Deletes the selected waypoint
function courseEditor:doDeleteSelectedAction(vehicle,guiWpSelected, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"DeleteSelected", guiWpSelected, noEventSend);

	--- Delete selected WP
	table.remove(vehicle.Waypoints, guiWpSelected);

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle);

	--- Reset waypointIndex to start
	vehicle.cp.waypointIndex = 1
end

-- Action: Deletes the next waypaint after the selected waypoint
function courseEditor:doDeleteNextAction(vehicle,guiWpSelected, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"DeleteNext", guiWpSelected, noEventSend);

	--- Delete next WP from selected
	table.remove(vehicle.Waypoints, guiWpSelected + 1);

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle)

	--- Reset waypointIndex to start
	vehicle.cp.waypointIndex = 1
end

-- Action: Deletes all waypoints from the selected waypoint to the start
function courseEditor:doDeleteToStartAction(vehicle, guiWpSelected, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"DeleteToStart", guiWpSelected, noEventSend);

	--- Delete from selected WP to Start
	for _ = 1,guiWpSelected - 1 do
		table.remove(vehicle.Waypoints, 1)
	end
	vehicle.Waypoints[1].speed = 1
	vehicle.Waypoints[1].wait = false
	vehicle.Waypoints[1].unload = false
	vehicle.Waypoints[1].rev = false
	vehicle.Waypoints[1].crossing = true
	vehicle.Waypoints[1].turnstart = false
	vehicle.Waypoints[1].turnend = false

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle);
end

-- Action: Deletes all waypoints from the selected waypoint to the end
function courseEditor:doDeleteToEndAction(vehicle, guiWpSelected, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle,"DeleteToEnd", guiWpSelected, noEventSend);

	--- Delete from selected WP to End
	local num = #vehicle.Waypoints - guiWpSelected
	for _ = 1,num do
		table.remove(vehicle.Waypoints, guiWpSelected + 1)
	end
	vehicle.Waypoints[guiWpSelected].speed = 1
	vehicle.Waypoints[guiWpSelected].wait = false
	vehicle.Waypoints[guiWpSelected].unload = false
	vehicle.Waypoints[guiWpSelected].rev = false
	vehicle.Waypoints[guiWpSelected].crossing = true
	vehicle.Waypoints[guiWpSelected].turnstart = false
	vehicle.Waypoints[guiWpSelected].turnend = false

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle);
end

-- Action: Inserts the new waypoint
function courseEditor:doInsertAction(vehicle, guiWpSelected, midPNx, midPNy, midPNz, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle, "InsertNewWP", {wpSelected=guiWpSelected, midPNx=midPNx,	midPNy=midPNy, midPNz=midPNz}, noEventSend);

	--- Change the waypoint type
	table.insert(
		vehicle.Waypoints,
		guiWpSelected + 1,
		{
			cx=midPNx,
			cy=midPNy,
			cz=midPNz,
			angle=vehicle.Waypoints[guiWpSelected].angle,
			speed=vehicle.Waypoints[guiWpSelected].speed,
			lane=vehicle.Waypoints[guiWpSelected].lane
		}
	)

	--- Update signs
	courseplay.signs:updateWaypointSigns(vehicle);
end

-- Action: Update waypoint type of the selected waypoint
function courseEditor:doChangeTypeAction(vehicle, guiWpSelected, waypointTypeIndex, noEventSend)
	--- Send MP Event
	CourseEditorEvent.sendEvent(vehicle, "ChangeType", {wpSelected=guiWpSelected, typeIndex=waypointTypeIndex}, noEventSend);

	--- Change the waypoint type
	vehicle.Waypoints[guiWpSelected].wait = false
	vehicle.Waypoints[guiWpSelected].unload = false
	vehicle.Waypoints[guiWpSelected].rev = false
	vehicle.Waypoints[guiWpSelected].crossing = false
	vehicle.Waypoints[guiWpSelected].turnStart = false
	vehicle.Waypoints[guiWpSelected].turnEnd = false

	local section = "current";
	if waypointTypeIndex == 1 then
		-- nothing
	elseif waypointTypeIndex == 2 then
		vehicle.Waypoints[guiWpSelected].wait = true
		vehicle.Waypoints[guiWpSelected].speed = 0
	elseif waypointTypeIndex == 3 then
		vehicle.Waypoints[guiWpSelected].unload = true
	elseif waypointTypeIndex == 4 then
		vehicle.Waypoints[guiWpSelected].crossing = true
		section = "crossing";
	elseif waypointTypeIndex == 5 then
		vehicle.Waypoints[guiWpSelected].turnStart = true
	elseif waypointTypeIndex == 6 then
		vehicle.Waypoints[guiWpSelected].turnEnd = true
	elseif waypointTypeIndex == 7 then
		vehicle.Waypoints[guiWpSelected].rev = true
	end

	--- Update selected sign
	courseplay.signs:updateWaypointSigns(vehicle, section, guiWpSelected);
end


