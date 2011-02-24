-- triggers

-- traffic collision
function courseplay:onTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
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
  for k,trigger in pairs(g_currentMission.tipTriggers) do
	if trigger.triggerId == transformId then
		self.currentTipTrigger = trigger		
	end
  end
end