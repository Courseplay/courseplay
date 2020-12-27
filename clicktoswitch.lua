--[[

AUTHOR
Russ Beuker, January 2020

CLICK TO SWITCH
This was developed as a way to quickly jump from your current vehicle to another vehicle by mouse clicking on the vehicle on-screen.
This can provide a quicker way of getting into a vehicle which you can see from your current position rather that cycling through your vehicles with a hotkey.
You'll need to enable this in the hud advanced settings page.

CAVEATS
1) This has not been tested on multiplayer.
2) Works with courseplay .00358Dev (didn't try other versions)

DEV NOTES
This file is intended to be included with CoursePlay.  See the bottom of this file for instructions on what to modify in other files.
Most of this will be handled in a merge, but the instructions contain explanations on why we are making the changes.

NOTES
1) The vehicle must be visible and within range (1000 meters, which is pretty well a pixel on the horizon) to be able to switch to it.
2) You must click on the power unit.  Ex. For a tractor with a trailer, you must click on the tractor.  Clicking on the trailer won't do anything.
3) The only input used is the 'Courseplay: mouse action' hotkey.  No other configuration or hotkeys are required.

TEST SCRIPT
1) Enter a vehicle and bring up the Courseplay HUD advanced settings page.  Turn off the Click to switch setting.
2) While in a vehicle, turn to face another vehicle that you have permission to enter.
3) Click on the other vehicle.  You should switch to that vehicle.
4) Now click on the original vehicle.  You should switch back to that vehicle.
5) Try clicking on other things (other vehicles, trailers, trees, ground etc).  Nothing should happen.
6) Save the game and quit.
7) Load the game and try clicking to switch. It should work.
8) Disable the Click to switch option.
9) Save the game and quit.
10) Load the game and try clicking to switch.  It should not work.

]]--

clickToSwitch = {}

-- let's find out if a vehicle is under the cursor by casting a ray in that direction
function clickToSwitch:updateMouseState(vehicle, posX, posY, isDown, isUp, mouseButton)
  local activeCam = getCamera()
  if activeCam ~= nil then
    local hx, hy, hz, px, py, pz = RaycastUtil.getCameraPickingRay(posX, posY, activeCam)
    raycastClosest(hx, hy, hz, px, py, pz, "vehicleClickToSwitchRaycastCallback", 1000, self, 371)
  end
end

-- this is called when the ray hits something
function clickToSwitch:vehicleClickToSwitchRaycastCallback(hitObjectId, x, y, z, distance)
  if hitObjectId ~= nil then
    local objectType = getRigidBodyType(hitObjectId)
    if objectType ~= "Kinematic" then
      local object = g_currentMission:getNodeObject(hitObjectId)    
      if object ~= nil then
        -- this is a valid vehicle, so enter it
        g_currentMission:requestToEnterVehicle(object);
      end
      return false
    end
  end
  return true
end

-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
-- CODE MERGING NOTES
-----------------------------------------------------------------------------------------
--[[

-- make the following change to input.lua (to 

function courseplay:onMouseEvent(posX, posY, isDown, isUp, mouseButton)
	--RIGHT CLICK
	-- Input binding debug
	local vehicle = g_currentMission.controlledVehicle		
	if not vehicle or not vehicle.hasCourseplaySpec then return end
  courseEditor:updateMouseState(vehicle, posX, posY, isDown, isUp, mouseButton)
  
	--print(string.format('courseplay:mouseEvent(posX(%s), posY(%s), isDown(%s), isUp(%s), mouseButton(%s))', tostring(posX), tostring(posY), tostring(isDown), tostring(isUp), tostring(mouseButton) ))
	--print(string.format("if isUp(%s) and mouseButton(%s) == courseplay.inputBindings.mouse.secondaryButtonId(%s) and Enterable.getIsEntered(self)(%s) then"
	--,tostring(isUp),tostring(mouseButton),tostring(courseplay.inputBindings.mouse.secondaryButtonId),tostring(Enterable.getIsEntered(self))))
	if isUp and mouseButton == courseplay.inputBindings.mouse.secondaryButtonId and vehicle:getIsEntered() then
		if vehicle.cp.hud.show then
			courseplay:setMouseCursor(vehicle, not vehicle.cp.mouseCursorActive);
		elseif not vehicle.cp.hud.show and vehicle.cp.hud.openWithMouse then
			courseplay:openCloseHud(vehicle, true)
		end;
	end;

	local hudGfx = courseplay.hud.visibleArea;
	local mouseIsInHudArea = vehicle.cp.mouseCursorActive and courseplay:mouseIsInArea(posX, posY, hudGfx.x1, hudGfx.x2, hudGfx.y1, vehicle.cp.suc.active and courseplay.hud.suc.visibleArea.y2 or hudGfx.y2);
	-- if not mouseIsInHudArea then return; end;

  -- should we switch vehicles? -- added for clickToSwitch
  if courseplay.globalSettings.clickToSwitch:is(true) and vehicle.cp.mouseCursorActive and vehicle.cp.hud.show and vehicle:getIsEntered() and not mouseIsInHudArea and   -- added for clickToSwitch
    mouseButton == courseplay.inputBindings.mouse.primaryButtonId then  -- added for clickToSwitch
    clickToSwitch:updateMouseState(vehicle, posX, posY, isDown, isUp, mouseButton)  -- added for clickToSwitch
  end  -- added for clickToSwitch
  
.
.

----------------------------

In settings.lua add the following just after the 'AutoFieldScanSetting' block (to define the global setting to turn this on or off)

---@class ClickToSwitchSetting : BooleanSetting
ClickToSwitchSetting = CpObject(BooleanSetting)
function ClickToSwitchSetting:init()
  BooleanSetting.init(self, 'clickToSwitch', 'COURSEPLAY_CLICK_TO_SWITCH',
				'COURSEPLAY_YES_NO_CLICK_TO_SWITCH', nil)
  -- set default while we are transitioning from the the old setting to this new one
  self:set(false)
end

----------------------------

In GlobalSettingsPage.xml add the following just after the 'workerWages' block (to define the on/off gui switch for this feature)
.
.
<GuiElement type="multiTextOption" profile="multiTextOptionSettings" onCreate="onCreateGlobalSettingsPage" name="clickToSwitch" toolTipElementId="ingameMenuHelpBoxText">
  <GuiElement type="button" profile="multiTextOptionSettingsLeft" />
  <GuiElement type="button" profile="multiTextOptionSettingsRight" />
  <GuiElement type="text" profile="multiTextOptionSettingsText" />
  <GuiElement type="text" profile="multiTextOptionSettingsTitle" />
  <GuiElement type="bitmap" profile="multiTextOptionSettingsBg" />
</GuiElement>
.
.
----------------------------

In translation_en.xml add
.
.
		<text name="COURSEPLAY_CLICK_TO_SWITCH"					   			text="Click to switch" />  -- add for clicktoswitch
		<text name="COURSEPLAY_YES_NO_CLICK_TO_SWITCH"					   	text="Click on a vehicle to switch to it" />  -- add for clicktoswitch
.
.

do this for the other translation languages too.

]]--