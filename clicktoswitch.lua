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
        courseplay.debugVehicle(courseplay.DBG_TRIGGERS,vehicle,"create a clickToSwitch raycast")
        raycastClosest(hx, hy, hz, px, py, pz, "vehicleClickToSwitchRaycastCallback", 1000, self, 371)
    end
end

-- this is called when the ray hits something
function clickToSwitch:vehicleClickToSwitchRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId ~= nil then
    local objectType = getRigidBodyType(hitObjectId)
        local object = g_currentMission:getNodeObject(hitObjectId)    
        if object ~= nil then
            -- check if the object is a implement or trailer then get the rootVehicle 
            local rootVehicle = object.getRootVehicle and object:getRootVehicle()
            local enterableSpec = object.spec_enterable or rootVehicle and rootVehicle.spec_enterable
            local targetObject = object.spec_enterable and object or rootVehicle 
            if enterableSpec then 
                -- this is a valid vehicle, so enter it
                g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(targetObject, g_currentMission.missionInfo.playerStyle, g_currentMission.player.farmId));
                g_currentMission.isPlayerFrozen = false;
                courseplay.debugFormat(courseplay.DBG_TRIGGERS,"clickToSwitch raycastCallBack: attempt to enter vehicle: %s ",nameNum(targetObject))
                return false
            end                
        end
    end
    return true
end
