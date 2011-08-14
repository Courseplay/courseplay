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

  --C.Schoch
	--local trigger_objects = g_currentMission.onCreateLoadedObjects
	local trigger_objects = {};
	if  g_currentMission.onCreateLoadedObjects ~= nil then
    for k,trigger in pairs(g_currentMission.onCreateLoadedObjects) do
      table.insert(trigger_objects, trigger)
    end
  end
  --C.Schoch
	
  if  g_currentMission.tipAnywhereTriggers ~= nil then
    for k,trigger in pairs(g_currentMission.tipAnywhereTriggers) do
      table.insert(trigger_objects, trigger)
    end
  end
	
  -- C.Schoch
	if g_currentMission.tipTriggers ~= nil then
		for k,trigger in pairs(g_currentMission.tipTriggers) do
			if trigger.isExtendedTrigger then
				table.insert(trigger_objects, trigger);
			end;
    end
	end;
  -- C.Schoch
  
  for k,trigger in pairs(trigger_objects) do
	--print(trigger.className);
	if (trigger.className and (trigger.className == "SiloTrigger" or endswith(trigger.className, "TipTrigger") or startswith(trigger.className, "MapBGA")))  or trigger.isTipAnywhereTrigger then
	  -- transformId
	  if  not trigger.className then
	    -- little hack ;)
	    trigger.className = "TipAnyWhere"
	  end 
	  if trigger.triggerId ~= nil and trigger.triggerId == transformId then
		  self.currentTipTrigger = trigger
		elseif trigger.triggerIds ~= nil and transformId ~= nil and table.contains(trigger.triggerIds, transformId) then
		  self.currentTipTrigger = trigger	
		elseif trigger.specialTriggerId ~= nil and trigger.specialTriggerId == transformId then
		  -- support map bga by headshot xxl
		  if trigger.silage.fillLevel < trigger.silage.maxFillLevel then
		    self.currentTipTrigger = trigger
		  end
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

function startswith(sbig, slittle)
  if type(slittle) == "table" then
    for k,v in ipairs(slittle) do
      if string.sub(sbig, 1, string.len(v)) == v then 
        return true
      end
    end
    return false
  end
  return string.sub(sbig, 1, string.len(slittle)) == slittle
end

function endswith(sbig, slittle)
if type(slittle) == "table" then
for k,v in ipairs(slittle) do
if string.sub(sbig, string.len(sbig) - string.len(v) + 1) == v then 
return true
end
end
return false
end
return string.sub(sbig, string.len(sbig) - string.len(slittle) + 1) == slittle
end