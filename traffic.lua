--[[ next Version of Collision detection system:
	The approach is to keep all nodes in trigger table, who are really in trigger and to remove them, only if they actually leave
]]

local abs, max, min, pow, sin ,huge = math.abs, math.max, math.min, math.pow, math.sin, math.huge;


function courseplay:cpOnTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	-- prevent double or tripple runs for one event
	if self.cp.lastCheckedTrigger == triggerId 
	and self.cp.lastCheckedotherId == otherId
	and self.cp.lastCheckedonEnter == onEnter
	and self.cp.lastCheckedonLeave == onLeave then
		return
	end
	
	self.cp.lastCheckedTrigger = triggerId
	self.cp.lastCheckedotherId = otherId
	self.cp.lastCheckedonEnter = onEnter
	self.cp.lastCheckedonLeave = onLeave
	
	local changedTables = false  --used to just call update if something changed
	
	local debugMessage = "onEnter"
	if onLeave then 
		debugMessage = "onLeave"
	end
	
	--which trigger is it ? 
	local triggerNumber = self.cp.trafficCollisionTriggerToTriggerIndex[triggerId];
	courseplay:debug(string.format("%s:%s Trigger%d: triggered collision with %d (%s)", nameNum(self),debugMessage,triggerNumber,otherId,tostring(getName(otherId))), 3);
		
	if onEnter then
		if not self.cp.collidingObjects[triggerNumber][otherId] then
			self.cp.collidingObjects[triggerNumber][otherId] = true
			changedTables = true
			courseplay:debug(string.format("%s:%s-> added self.cp.collidingObjects[%d][%d]", nameNum(self),debugMessage,triggerNumber,otherId), 3);
		end
		if not self.cp.collidingObjects.all[otherId] then
			self.cp.collidingObjects.all[otherId] = true
			changedTables = true
		end
	elseif onLeave then
		if self.cp.collidingObjects[triggerNumber][otherId] then
			self.cp.collidingObjects[triggerNumber][otherId] = nil
			changedTables = true
			courseplay:debug(string.format("%s:%s-> self.cp.collidingObjects[%d][%d] = nil", nameNum(self),debugMessage,triggerNumber,otherId), 3);
		end
		
		--is this ID in one of the other triggers?
		local isInOtherTrigger = false 
		for i=1,4 do
			if i ~= triggerNumber and self.cp.collidingObjects[i][otherId] then
				isInOtherTrigger = true
			end
		end
		
		if self.cp.collidingObjects.all[otherId] and not isInOtherTrigger then
			self.cp.collidingObjects.all[otherId] = nil
			changedTables = true
			courseplay:debug(string.format("%s:%s-> self.cp.collidingObjects.all[%d]= nil", nameNum(self),debugMessage,otherId), 3);
		end
	end
	
	if changedTables then
		if courseplay.debugChannels[3] then
			for triggerNumber =1,4 do
				print(string.format("     self.cp.collidingObjects[%d]:",triggerNumber))
				for otherID,_ in pairs (self.cp.collidingObjects[triggerNumber]) do
					print(string.format("       [%d]",otherID))
				end
				print("______________")
			end
		end
		courseplay:updateCollisionVehicle(self)
	end
end

function courseplay:removeInvalidID(self,otherId)
	courseplay:debug(string.format("   deleting %d from triggers because the object is not valid",otherId), 3);
	if self.cp.collidingObjects.all[otherId] then
		self.cp.collidingObjects.all[otherId] = nil
	end
	for triggerNumber =1,4 do
		if self.cp.collidingObjects[triggerNumber][otherId] then 
			self.cp.collidingObjects[triggerNumber][otherId] = nil;
		end
	end
end

function courseplay:updateCollisionVehicle(vehicle)
	courseplay:debug(string.format("%s:updateCollisionVehicle:", nameNum(vehicle)), 3);	
	
	--check all triggers and see, what we have
	local currentCollisionVehicleId = nil
	local distanceToCollisionVehicle = huge
		
	for otherId,_ in pairs (vehicle.cp.collidingObjects.all) do
		--ignore objects on list
		if entityExists(otherId) then
			local parent = getParent(otherId);
			courseplay:debug(string.format("%s:  checking CollisionIgnoreList for %d", nameNum(vehicle),otherId), 3);
			if CpManager.trafficCollisionIgnoreList[otherId] then
				courseplay:debug(string.format("  is on global list ->ignore"), 3);
			elseif CpManager.trafficCollisionIgnoreList[parent] then
				courseplay:debug(string.format("  parent is on global list ->ignore"), 3);
			elseif vehicle.cpTrafficCollisionIgnoreList[otherId] then
				courseplay:debug(string.format("  is on local list ->ignore"), 3);	
			elseif vehicle.cpTrafficCollisionIgnoreList[parent] then
				courseplay:debug(string.format("  parent is on local list ->ignore"), 3);	
			else
				courseplay:debug(string.format("  is not on CollisionIgnoreList"), 3);
				local collisionVehicle = g_currentMission.nodeToVehicle[otherId];
				if (collisionVehicle ~= nil and collisionVehicle.isTrafficLightStopper) --we already had it and marked it
				or getName(otherId) == "AITrafficStopCanBeMoved"  -- Traffic Light System by Blacky_BPG (WasselMap)
				or (collisionVehicle ~= nil and collisionVehicle.rootNode == nil) then
					--is it a traffic light ?
					local _,translationY,_ = getTranslation(otherId);
					if collisionVehicle == nil then
						local trafficLight = {}
						trafficLight.isTrafficLightStopper = true;
						trafficLight.name = TrafficLightStopper;
						trafficLight.lastSpeedReal = 0;
						g_currentMission.nodeToVehicle[otherId] = trafficLight;
					elseif not collisionVehicle.isTrafficLightStopper then
						collisionVehicle.isTrafficLightStopper = true;
					end				
					
					if translationY < -1 then
						OtherIdisCloser = false
						courseplay:debug("   trafficLight: transY = "..tostring(translationY)..", so it's green or Off-> go on",3)
					else
						courseplay:debug("   trafficLight: transY = "..tostring(translationY)..", so it's red-> set as collision vehicle",3)
						for triggerNumber = 1,4 do
							if vehicle.cp.collidingObjects[triggerNumber][otherId] then
								local trafficLightDistance = triggerNumber*5;
								if distanceToCollisionVehicle > trafficLightDistance then
									courseplay:debug(string.format("   %d is closer (%.2f m)",otherId,trafficLightDistance), 3);
									distanceToCollisionVehicle = trafficLightDistance
									currentCollisionVehicleId = otherId;
									break;
								end
							end				
						end				
					end			
				elseif collisionVehicle ~= nil then
					-- is this a normal vehicle?
					local distance = courseplay:distanceToObject(vehicle, collisionVehicle)
					if distanceToCollisionVehicle > distance then
						courseplay:debug(string.format("   %d is closer (%.2f m)",otherId,distance), 3);
						distanceToCollisionVehicle = distance;
						currentCollisionVehicleId = otherId;
					end
				else
					-- is this a traffic vehicle?
					local cm = getCollisionMask(otherId);
					if collisionVehicle == nil and bitAND(cm, 2097152) ~= 0 and not string.match(getName(otherId),'Trigger') and not string.match(getName(otherId),'trigger') then -- if bit21 is part of the collisionMask then set new vehicle in GCM.NTV
						courseplay:debug(string.format("   g_currentMission.nodeToVehicle[%s] == nil -> setting %s as aPath vehicle",otherId,tostring(getName(otherId))), 3);
						local pathVehicle = {}
						pathVehicle.rootNode = otherId
						pathVehicle.isCpPathvehicle = true
						pathVehicle.name = "PathVehicle"
						pathVehicle.sizeLength = 7
						pathVehicle.sizeWidth = 3
						g_currentMission.nodeToVehicle[otherId] = pathVehicle
						local distance = courseplay:distanceToObject(vehicle, pathVehicle)
						if distanceToCollisionVehicle > distance then
							courseplay:debug(string.format("   %d is closer (%.2f m)",otherId,distance), 3);
							distanceToCollisionVehicle = distance
							currentCollisionVehicleId = otherId;
						end
					end;
				
				end
			end
		else
			courseplay:removeInvalidID(vehicle,otherId);
		end
	end
	if currentCollisionVehicleId ~= nil then	
	 courseplay:debug(string.format("    setting vehicle.cp.collidingVehicleId to %d (%s)",currentCollisionVehicleId,tostring(getName(currentCollisionVehicleId))), 3);	
	end
	vehicle.cp.collidingVehicleId = currentCollisionVehicleId

end

function courseplay:checkTraffic(vehicle, displayWarnings, allowedToDrive)
	local ahead = false
	local inQueue = false
	local collisionVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId]
	if collisionVehicle ~= nil and not (vehicle.cp.mode == 9 and (collisionVehicle.allowFillFromAir or (collisionVehicle.cp and collisionVehicle.cp.mode9TrafficIgnoreVehicle))) then
		local vx, vy, vz = getWorldTranslation(vehicle.cp.collidingVehicleId);
		local tx, _, tz = worldToLocal(vehicle.cp.trafficCollisionTriggers[1], vx, vy, vz);
		local x, y, z = getWorldTranslation(vehicle.cp.DirectionNode);
		local halfLength =  (collisionVehicle.sizeLength or 5) * 0.5;
		local x1,z1 = AIVehicleUtil.getDriveDirection(vehicle.cp.collidingVehicleId, x, y, z);
		if z1 > -0.9 then -- tractor in front of vehicle face2face or beside < 4 o'clock
			ahead = true
		end;
		local _,transY,_ = getTranslation(vehicle.cp.collidingVehicleId);
		if (transY < -1 and collisionVehicle.rootNode == nil) or abs(tx) > 5 and collisionVehicle.rootNode ~= nil and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then
			courseplay:debug(('%s: checkTraffic:\tcall deleteCollisionVehicle(), transY: %s, tx: %s, vehicle.cp.collidingObjects.all[Id]: %s'):format(nameNum(vehicle),tostring(transY),tostring(tx),tostring(vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId])), 3);
			courseplay:deleteCollisionVehicle(vehicle);
			return allowedToDrive;
		end;

		if collisionVehicle.lastSpeedReal == nil or collisionVehicle.lastSpeedReal*3600 < 5 or ahead then
			-- courseplay:debug(('%s: checkTraffic:\tcall distance=%.2f'):format(nameNum(vehicle), tz-halfLength), 3);
			if tz <= halfLength + 4 then --TODO: abs(tz) ?
				allowedToDrive = false;
				vehicle.cp.inTraffic = true;
				courseplay:debug(('%s: checkTraffic:\tstop'):format(nameNum(vehicle)), 3);
			elseif vehicle.cp.curSpeed > 10 then
				-- courseplay:debug(('%s: checkTraffic:\tbrake'):format(nameNum(vehicle)), 3);
				allowedToDrive = false;
			else
				-- courseplay:debug(('%s: checkTraffic:\tdo nothing - go, but set "vehicle.cp.isTrafficBraking"'):format(nameNum(vehicle)), 3);
				vehicle.cp.isTrafficBraking = true;
			end;
		end;
		local attacher
		if collisionVehicle.getRootAttacherVehicle then
			attacher = collisionVehicle:getRootAttacherVehicle()
			inQueue = vehicle.cp.mode == 1 and vehicle.cp.waypointIndex == 1 and attacher.cp ~= nil and attacher.cp.isDriving and attacher.cp.mode == 1 and attacher.cp.waypointIndex == 2 
		end	
		if collisionVehicle.isTrafficLightStopper then
			inQueue = true
		end
	end;

	if displayWarnings and vehicle.cp.inTraffic and not inQueue then
		CpManager:setGlobalInfoText(vehicle, 'TRAFFIC');
	end;
	return allowedToDrive;
end


function courseplay:regulateTrafficSpeed(vehicle,refSpeed,allowedToDrive)
	if vehicle.cp.isTrafficBraking then
		return refSpeed
	end
	if vehicle.cp.collidingVehicleId ~= nil then
		local collisionVehicle = g_currentMission.nodeToVehicle[vehicle.cp.collidingVehicleId];
		local vehicleBehind = false
		if collisionVehicle == nil then
			--courseplay:debug(nameNum(vehicle)..": regulateTrafficSpeed:	setting vehicle.cp.collidingVehicleId nil",3)
			--courseplay:deleteCollisionVehicle(vehicle)
			return refSpeed
		else
			local name = getName(vehicle.cp.collidingVehicleId)
			courseplay:debug(nameNum(vehicle)..": regulateTrafficSpeed:	 "..tostring(name),3)
		end
		local x, y, z = getWorldTranslation(vehicle.cp.collidingVehicleId)
		local x1, y1, z1 = worldToLocal(vehicle.cp.DirectionNode, x, y, z)
		if z1 < 0 or abs(x1) > 5 and not vehicle.cp.collidingObjects.all[vehicle.cp.collidingVehicleId] then -- vehicle behind tractor
			vehicleBehind = true
		end
		local distance = 0
		if collisionVehicle.rootNode ~= nil then
			distance = courseplay:distanceToObject(vehicle, collisionVehicle)
		end
		if collisionVehicle.rootNode == nil or collisionVehicle.lastSpeedReal == nil or (distance > 40) or vehicleBehind then
			courseplay:debug(string.format("%s: v.rootNode= %s,v.lastSpeedReal= %s, distance: %f, vehicleBehind= %s",nameNum(vehicle),tostring(collisionVehicle.rootNode),tostring(collisionVehicle.lastSpeedReal),distance,tostring(vehicleBehind)),3)
			courseplay:deleteCollisionVehicle(vehicle)
		else
			if allowedToDrive and not (vehicle.cp.mode == 9 and (collisionVehicle.allowFillFromAir or collisionVehicle.cp.mode9TrafficIgnoreVehicle)) then
				if vehicle.cp.curSpeed - (collisionVehicle.lastSpeedReal*3600) > 15 or z1 < 3 then
					vehicle.cp.TrafficBrake = true
				else
					return min(collisionVehicle.lastSpeedReal*3600,refSpeed)
				end
			end
		end
	end
	
	return refSpeed
end


function courseplay:deleteCollisionVehicle(vehicle)
	if vehicle.cp.collidingVehicleId ~= nil  then
		vehicle.cp.collidingVehicleId = nil;
		courseplay:updateCollisionVehicle(vehicle)
	end
end