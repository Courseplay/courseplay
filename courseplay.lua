--
-- Courseplay v0.5
-- Specialization for Courseplay
--
-- @author  Lautschreier / Hummel
-- @version:	v0.5.15.02.11
-- @testing:    bullgore80
-- @history:	14.02.01 added courseMode
--		15.02.01 refactoring and collisiontrigger
--		16.02.01 signs are dispearing, tipper support
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
	
	-- course modes: 1 circle route - 2 returning route
	self.course_mode = 1
	
	-- ai mods: 1 abfahrer
	self.ai_mode = 1
	
	self.ArrowPath = Utils.getFilename("spezializations/arrow.png", self.baseDirectory);
	self.ArrowOverlay = Overlay:new("Arrow", self.ArrowPath, 0.4, 0.08, 0.250, 0.250);
	self.ArrowOverlay:render()
	
	-- kegel der route	
	local baseDirectory = getAppBasePath()
	local i3dNode = Utils.loadSharedI3DFile("data/maps/models/objects/beerKeg/beerKeg.i3d", baseDirectory)
	local itemNode = getChildAt(i3dNode, 0)
	link(getRootNode(), itemNode)
	setRigidBodyType(itemNode, "NoRigidBody")
	setTranslation(itemNode, 0, 0, 0)
	setVisibility(itemNode, false)
	delete(i3dNode)
	self.sign = itemNode
	self.signs = {}
	
	-- traffic collision	
	self.onTrafficCollisionTrigger = courseplay.onTrafficCollisionTrigger;
	self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	self.onToolTrafficCollisionTrigger = courseplay.onToolTrafficCollisionTrigger;
	
	self.trafficCollisionIgnoreList = {};
	for k,v in pairs(self.components) do
	  self.trafficCollisionIgnoreList[v.node] = true;
	end;
	self.numCollidingVehicles = 0;
    self.numToolsCollidingVehicles = {};
	
	
	self.tipper_attached = false
	
	self.currentTrailerToFill = 1
	
	-- name search
	local aNameSearch = {"vehicle.name." .. g_languageShort, "vehicle.name.en", "vehicle.name", "vehicle#type"};
	
	if Steerable.load ~= nil then
		local orgSteerableLoad = Steerable.load
		
		Steerable.load = function(self,xmlFile)
			orgSteerableLoad(self,xmlFile)
			
			for nIndex,sXMLPath in pairs(aNameSearch) do 
				self.name = getXMLString(xmlFile, sXMLPath);
				if self.name ~= nil then break; end;
			end;
			if self.name == nil then self.name = g_i18n:getText("UNKNOWN") end;
		end;
	end;
	
end	
	
	
function courseplay:draw()
	if not self.drive then
		if not self.record then		
			-- switch course mode
			if self.course_mode == 1 then
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayRound"), InputBinding.CourseMode);			      
			else
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayReturn"), InputBinding.CourseMode);			      
			end
				
			if InputBinding.hasEvent(InputBinding.CourseMode) then 
				if self.course_mode == 1 then
					self.course_mode = 0
				else
					self.course_mode = 1
				end
			end
				
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStart"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				courseplay:start_record(self)
			end
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStop"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				courseplay:stop_record(self)
			end
		end	
	end  
	
	if self.play then
		if not self.drive then 
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStart"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				courseplay:start(self)
			end	
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStop"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				courseplay:stop(self)
			end
		end				
	end
	
	if self.dcheck and table.getn(self.Waypoints) > 1 then
		courseplay:dcheck(self);	  
	end
end	

		
function courseplay:update()
	if self.isEntered then
		courseplay:sign_visibility(self, true)
	else
		courseplay:sign_visibility(self, false)
	end


	if self.record then 
	  courseplay:record(self);
	end	
	
	if self.drive then
	  courseplay:drive(self);
	end	
	
end		


-- starts course recording
function courseplay:start_record(self)
    courseplay:reset_course(self)
	courseplay:init_implements(self)
	self.record = true
	self.drive  = false
	-- show arrow to start if in circle mode
	if self.course_mode == 1 then
		self.dcheck = true
	end
	self.recordnumber = 1
	self.tmr = 101
end		

-- stops course recording
function courseplay:stop_record(self)
	self.record = false
	self.drive  = false	
	self.dcheck = false
	self.play = true
	self.maxnumber = self.recordnumber - 1
	self.back = false
end		

-- resets actual course
function courseplay:reset_course(self)	
	self.recordnumber = 1
	self.tmr = 1
	self.Waypoints = {}
	courseplay:sign_visibility(self, false)
	self.signs = {}
	self.play = false
	self.back = false 
	self.wait = false
	self.course_mode = 1
end	

-- starts driving the course
function courseplay:start(self)    
	self.tippers = {}
	self.tipper_attached, self.tippers = courseplay:update_tools(self, self.tippers)
	
	if self.tipper_attached then
		for k,object in pairs(self.tippers) do
		  AITractor.addToolTrigger(self, object)
		end
	end
	
    self.numCollidingVehicles = 0;
    self.numToolsCollidingVehicles = {};
	self.drive  = false
	self.record = false		
	self.wait   = false
	self.deactivateOnLeave = false
	self.stopMotorOnLeave = false
	if self.back then
		self.recordnumber = self.maxnumber - 2
	else
		self.recordnumber = 1
	end
		
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

-- stops driving the course
function courseplay:stop(self)
	self.record = false
	-- removing collision trigger
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end
	
	-- removing tippers
	if self.tipper_attached then
		for key,tipper in pairs(self.tippers) do
		  AITractor.removeToolTrigger(self, tipper)
		  tipper:aiTurnOff()
		end
	end
	
	self.drive  = false	
	self.play = true
	self.dcheck = false
	self.motor:setSpeedLevel(0, false);
	self.motor.maxRpmOverride = nil;
	WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode)
	self.recordnumber = 1
	self.deactivateOnLeave = true
	self.stopMotorOnLeave = true
end
		

-- drives recored course
function courseplay:drive(self)
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  self.dist = courseplay:distance(cx ,cz ,ctx ,ctz)
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  local allowedToDrive = true;
  
  -- abfahrer-mode tippers are not full
  if self.ai_mode == 1 and self.tipper_attached and tipper_fill_level < tipper_capacity then
	allowedToDrive = false;
  end
  
  
  if self.numCollidingVehicles > 0 then
    allowedToDrive = false;
  end

   for k,v in pairs(self.numToolsCollidingVehicles) do
		if v > 0 then
			allowedToDrive = false;
			break;
		end;
    end;

  
  if not allowedToDrive then
     local lx, lz = 0, 1; 
     AIVehicleUtil.driveInDirection(self, 1, 30, 0, 0, 28, false, moveForwards, lx, lz)
	 -- TODO renderText(0.4, 0.001,0.02, self.name .. ' steckt im Verkehr fest');
	 renderText(0.4, 0.001,0.02, 'Abfahrer steckt im Verkehr fest');
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
			  if self.course_mode == 1 then
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
				  self.wait = true
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
  if self.record then
    return
  end
  local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  dist = courseplay:distance(ctx ,ctz ,cx ,cz)
  renderText(0.4, 0.001,0.02,string.format("entfernung: %d ",dist ));
end;


function courseplay:delete()
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end
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

-- update implements
-- TODO support more tippers
function courseplay:update_tools(self)  
  local tipper_attached = false
  local tips = {}
  -- go through all implements
  for k,implement in pairs(self.attachedImplements) do
    local object = implement.object
    if object.allowTipDischarge then
      tipper_attached = true
      table.insert(tips, object)
    end    
  end
  if tipper_attached then
    return true, tips
  end
  return nil
end

function courseplay:addsign(self, x, y, z)  
    local height = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)
    local root = self.sign
    local sign = clone(root, true)
    setTranslation(sign, x, height + 1 + self.recordnumber, z)
    setVisibility(sign, true)
    table.insert(self.signs, sign)
	return(sign)
end

function courseplay:sign_visibility(self, visibilty)
  for k,v in pairs(self.signs) do    
      setVisibility(v, visibilty)	
  end
end

function courseplay:init_implements(self)
	for k,tool in pairs(self.attachedImplements) do
		if tool.aiTrafficCollisionTrigger ~= nil then
           addTrigger(tool.aiTrafficCollisionTrigger, "onToolTrafficCollisionTrigger", self);
		end
	end
end

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

function courseplay:onToolTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
      if onEnter or onLeave then	      
          if otherId == g_currentMission.player.rootNode then
              if onEnter then
                  self.numToolsCollidingVehicles[triggerId] = self.numToolsCollidingVehicles[triggerId]+1;
              elseif onLeave then
                  self.numToolsCollidingVehicles[triggerId] = math.max(self.numToolsCollidingVehicles[triggerId]-1, 0);
				  end;
          else
              local vehicle = g_currentMission.nodeToVehicle[otherId];
              if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil then
                  if onEnter then
                      self.numToolsCollidingVehicles[triggerId] = self.numToolsCollidingVehicles[triggerId]+1;
                  elseif onLeave then
                      self.numToolsCollidingVehicles[triggerId] = math.max(self.numToolsCollidingVehicles[triggerId]-1, 0);
                  end;
              end;
          end;
      end;
end;

