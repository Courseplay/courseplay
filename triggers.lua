-- triggers

-- traffic collision
function courseplay:onTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if otherId == self.rootNode then
      return
    end
    if onEnter or onLeave then
        if otherId == Player.rootNode then
            if onEnter then
                self.numCollidingVehicles = self.numCollidingVehicles+1;
            elseif onLeave then
                self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);		
            end;
        else          
            local vehicle = g_currentMission.nodeToVehicle[otherId];
            if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil then
                if onEnter then
                    self.numCollidingVehicles = self.numCollidingVehicles+1;
                elseif onLeave then
                    self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);		
                end;
            end;
        end;
    end;
end;

-- tip trigger
function courseplay:findTipTriggerCallback(transformId, x, y, z, distance)
  for k,trigger in pairs(g_currentMission.onCreateLoadedObjects) do
	if trigger.className == "SiloTrigger" or trigger.className == "TipTrigger" or trigger.className =="MapBGASilo" or trigger.className =="MapBGASiloGrass" or trigger.className =="MapBGASiloChaff" then
	    -- transformId
	    if trigger.triggerId ~= nil and trigger.triggerId == transformId then
		  self.currentTipTrigger = trigger		
		elseif trigger.triggerIds ~= nil and transformId ~= nil and table.contains(trigger.triggerIds, transformId) then
		  self.currentTipTrigger = trigger		
		elseif trigger.specialTriggerId ~= nil and trigger.specialTriggerId == transformId then
		  -- support map bga by headshot xxl 
		  self.currentTipTrigger = trigger
		  --self.currentTipTrigger.triggerId = trigger.specialTriggerId
		end		
	end
  end 
end


function table.contains(table, element)
for _, value in pairs(table) do
if value == element then
return true
end
end
return false
end