--
-- Courseplay v0.46
-- Specialization for Courseplay
--
-- @author  Lautschreier / Hummel
-- @version:	v0.5.15.02.11
-- @history:	14.02.01 added courseMode
--		15.02.01 refactoring and collisiontrigger
--
courseplay = {};

function courseplay.prerequisitesPresent(specializations)
    return true;
end

function courseplay:load(xmlFile)
	self.recordnumber = 1
	self.tmr = 1
	self.Waypoints = {}
	self.play = false
	self.back = false 
	self.wait = false
	self.circle = false
	
	self.ArrowPath = Utils.getFilename("Speci/arrow.png", self.baseDirectory);
	self.ArrowOverlay = Overlay:new("Arrow", self.ArrowPath, 0.4, 0.08, 0.250, 0.250);
	self.ArrowOverlay:render()
	local baseDirectory = getAppBasePath()
	local i3dNode = Utils.loadSharedI3DFile("data/maps/models/objects/beerKeg/beerKeg.i3d", baseDirectory)
	local itemNode = getChildAt(i3dNode, 0)
	link(getRootNode(), itemNode)
	setRigidBodyType(itemNode, "NoRigidBody")
	setTranslation(itemNode, 0, 0, 0)
	setVisibility(itemNode, false)
	delete(i3dNode)
	self.sign = itemNode
	
	-- traffic collision	
	self.onTrafficCollisionTrigger = courseplay.onTrafficCollisionTrigger;
	self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	self.trafficCollisionIgnoreList = {};
	for k,v in pairs(self.components) do
	  self.trafficCollisionIgnoreList[v.node] = true;
	end;
	self.numCollidingVehicles = 0;
end	
	
	
function courseplay:draw()
	if not self.drive then
		if not self.record then
		
			-- switch course mode
			if self.circle then
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayRound"), InputBinding.CourseMode);			      
			else
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayReturn"), InputBinding.CourseMode);			      
			end
				
			if InputBinding.hasEvent(InputBinding.CourseMode) then 
				if self.circle then
					self.circle = false			      
				else
					self.circle = true
				end
			end
				
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStart"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				self.record = true
				self.drive  = false
				-- show arrow to start if in circle mode
				if self.circle then
					self.dcheck = true
				end
				self.recordnumber = 1
				self.tmr = 101
			end
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStop"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				self.record = false
				self.drive  = false	
				self.dcheck = false
				self.play = true
				self.maxnumber = self.recordnumber - 1
	    self.back = false
			end
		end	
	end  
	
	if self.play then
		if not self.drive then 
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStart"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				self.drive  = false
				self.record = false		
				
				
				self.deactivateOnLeave = false
				self.stopMotorOnLeave = false
				if self.back then
					self.recordnumber = self.maxnumber - 2
					self.dcheck = true
					local ctx,cty,ctz = getWorldTranslation(self.rootNode);
					local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
					dist = courseplay:distance(ctx ,ctz ,cx ,cz)
					
					if dist < 15 then
						self.drive  = true
						 if self.aiTrafficCollisionTrigger ~= nil then
						   addTrigger(self.aiTrafficCollisionTrigger, "onTrafficCollisionTrigger", self);
						 end
						self.record = false
						self.dcheck = false
					end	
				else
					self.recordnumber = 1
					self.dcheck = true
					local ctx,cty,ctz = getWorldTranslation(self.rootNode);
					local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
					dist = courseplay:distance(ctx ,ctz ,cx ,cz)
					
					if dist < 15 then
						self.drive  = true
						if self.aiTrafficCollisionTrigger ~= nil then
						  addTrigger(self.aiTrafficCollisionTrigger, "onTrafficCollisionTrigger", self);
						end
						self.record = false
						self.dcheck = false
					end	
				end	
			end	
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStop"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				self.record = false
				 if self.aiTrafficCollisionTrigger ~= nil then
				   removeTrigger(self.aiTrafficCollisionTrigger);
				 end
				self.drive  = false	
				self.play = true
				self.motor:setSpeedLevel(0, false);
				self.motor.maxRpmOverride = nil;
				WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode)
				self.recordnumber = 1
				self.deactivateOnLeave = true
				self.stopMotorOnLeave = true
			end
		end		
		
	end
	
	
	
	if self.dcheck then
	  if self.recordnumber > 20 then
	    courseplay:dcheck(self);
	  end
	end
end	
		
		
function courseplay:update()
	if self.record then 
	  courseplay:record(self);
	end	
	
	if self.drive then
	  courseplay:checkcollision(self);
	  courseplay:drive(self);
	end	
	
end		


-- drives recored course
function courseplay:drive(self)
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  self.dist = courseplay:distance(cx ,cz ,ctx ,ctz)
  
  local allowedToDrive = true;
  
  if self.numCollidingVehicles > 0 then
    allowedToDrive = false;
  end

  if not allowedToDrive then
     --local x,y,z = getWorldTranslation(self.aiTractorDirectionNode);
      local lx, lz = 0, 1; --AIVehicleUtil.getDriveDirection(self.aiTractorDirectionNode, self.aiTractorTargetX, y, self.aiTractorTargetZ);
     AIVehicleUtil.driveInDirection(self, 1, 30, 0, 0, 28, false, moveForwards, lx, lz)
     return;
   end;

  
  -- only stop if have to wait
  if self.wait then				
    self.drive  = false
    self.motor:setSpeedLevel(0, false);
    self.motor.maxRpmOverride = nil;
    WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode)
  end
  
  
  if self.dist > 5 then
	  if self.recordnumber > self.maxnumber - 4 or self.recordnumber < 4 then
		  self.sl = 2
	  else
		  self.sl = 3					
	  end	

	  local lx, lz = AIVehicleUtil.getDriveDirection(self.rootNode,cx,cty,cz);
	  
	  AIVehicleUtil.driveInDirection(self, 1,  25, 0.5, 0.5, 20, true, true, lx, lz ,self.sl, 0.9);
  else	
	  if not self.back then
				  
		  if self.recordnumber < self.maxnumber  then
			  self.recordnumber = self.recordnumber + 1
		  else			
			  -- dont stop if in circle mode
			  if self.circle then
			    self.back = false
			    self.recordnumber = 1
			    self.wait = false
			  else
			    self.back = true
			    self.wait = true
			  end
			  
			  
			  
			  self.record = false
			  self.play = true
				  
		  end	
	  else
		  if self.back then	
			  if self.recordnumber > 1  then
				  self.recordnumber = self.recordnumber - 1
			  else
				  self.record = false
				  self.drive  = false	
				  self.play = true
				  self.motor:setSpeedLevel(0, false);
				  self.motor.maxRpmOverride = nil;
				  WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode)
				  self.recordnumber = 1
				  self.back = false
				  
			  end	
		  end	
	  end
	  
  end
end;  
  
-- records waypoints for course
function courseplay:record(self)
  local cx,cy,cz = getWorldTranslation(self.rootNode);
  local x,y,z = localDirectionToWorld(self.rootNode, 0, 0, 1);
  local length = Utils.vector2Length(x,z);
  local dX = x/length
  local dZ = z/length
  local newangle = math.deg(math.atan2(dX,dZ))	
  
  
  if self.recordnumber < 4 then
	  self.rotatedTime = 0
  end	
  if self.recordnumber > 2 then
	  local oldcx ,oldcz ,oldangle= self.Waypoints[self.recordnumber - 1].cx,self.Waypoints[self.recordnumber - 1].cz,self.Waypoints[self.recordnumber - 1].angle
	  anglediff = math.abs(newangle - oldangle)
	  self.dist = courseplay:distance(cx ,cz ,oldcx ,oldcz)
	  if self.dist > 10 and (anglediff > 5 or dist > 40) then
		  self.tmr = 101
	  end
  end	
  if self.tmr > 100 then	
	  
	  self.Waypoints[self.recordnumber] = {cx = cx  ,cz = cz  ,angle = newangle}
	  if self.recordnumber < 3 then			
		  courseplay:addsign(self, cx, cy,cz)
	  end	
	  self.tmr = 1
	  self.recordnumber = self.recordnumber + 1
  end
  self.tmr = self.tmr + 1 
end;

-- checks collision trigger
function courseplay:checkcollision(self)
  if self.aiTrafficCollisionTrigger ~= nil then
    AIVehicleUtil.setCollisionDirection(self.aiTractorDirectionNode, self.aiTrafficCollisionTrigger, -0.7071067, 0.7071067);    
  end;	
end

-- displays arrow and distance to start point
function courseplay:dcheck(self)
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  if self.back then 
      number = self.maxnumber - 2
  else
      number = 1
  end	
  
  local arrowUV = {}
  local lx, ly, lz = worldToLocal(self.rootNode, self.Waypoints[number].cx, 0, self.Waypoints[number].cz)
  local arrowRotation = Utils.getYRotationFromDirection(lx, lz)
  
  arrowUV[1] = -0.5 * math.cos(-arrowRotation) + 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[2] = -0.5 * math.sin(-arrowRotation) - 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[3] = -0.5 * math.cos(-arrowRotation) - 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[4] = -0.5 * math.sin(-arrowRotation) + 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[5] = 0.5 * math.cos(-arrowRotation) + 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[6] = 0.5 * math.sin(-arrowRotation) - 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[7] = 0.5 * math.cos(-arrowRotation) - 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[8] = 0.5 * math.sin(-arrowRotation) + 0.5 * math.cos(-arrowRotation) + 0.5
  
  setOverlayUVs(self.ArrowOverlay.overlayId, arrowUV[1], arrowUV[2], arrowUV[3], arrowUV[4], arrowUV[5], arrowUV[6], arrowUV[7], arrowUV[8])
  self.ArrowOverlay:render()
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  dist = courseplay:distance(ctx ,ctz ,cx ,cz)
  renderText(0.4, 0.001,0.02,string.format("entfernung: %d ",dist ));
end;


function courseplay:delete()
end;	

function courseplay:mouseEvent(posX, posY, isDown, isUp, button)
end		

function courseplay:keyEvent(unicode, sym, modifier, isDown)
end;	

function courseplay:distance(x1 ,z1 ,x2 ,z2)
	
	xd = (x1 - x2) * (x1 - x2)
	zd = (z1 -z2) * (z1 - z2)
	dist = math.sqrt(math.abs(xd + zd) )
	return dist
end

function courseplay:addsign(self, x, y, z)
  
    local height = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)
    local root = self.sign
    local sign = clone(root, true)
    setTranslation(sign, x, height + 1 + self.recordnumber, z)
    setVisibility(sign, true)
    
end

function courseplay:onTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        if otherId == Player.rootNode then
            if onEnter then
                self.numCollidingVehicles = self.numCollidingVehicles+1;
		print("collision!!!");
            elseif onLeave then
                self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);
		print("collision removed");
            end;
        else
            local vehicle = g_currentMission.nodeToVehicle[otherId];
            if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil then
                if onEnter then
                    self.numCollidingVehicles = self.numCollidingVehicles+1;
		    print("collision!!!");
                elseif onLeave then
                    self.numCollidingVehicles = math.max(self.numCollidingVehicles-1, 0);
		    print("collision removed");
                end;
            end;
        end;
    end;
end;
