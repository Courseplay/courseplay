--
-- Courseplay v0.5
-- Specialization for Courseplay
--
-- @author  Lautschreier / Hummel
-- @version:	v0.5.18.02.11
-- @testing:    bullgore80
-- @history:	
--      02.01.11/06.02.11 course recording and driving (Lautschreier)
--      14.02.11 added courseMode (Hummel)
--		15.02.11 refactoring and collisiontrigger (Hummel)
--		16.02.11 signs are disapearing, tipper support (Hummel)
--      17.02.11 info text and global saving of "course_players" (Hummel)
--      18.02.11 more than one tipper recognized by tractor // name of tractor in global info message
courseplay = {};

-- working tractors saved in this
working_course_players = {};

function courseplay.prerequisitesPresent(specializations)
    return true;
end

function courseplay:load(xmlFile)
	self.recordnumber = 1
	self.tmr = 1
	self.Waypoints = {}
	self.courses = {}
	self.play = false
	self.back = false 
	self.wait = false
	self.working_course_player_num = nil
	
	-- info text on tractor
	self.info_text = nil
	
	-- global info text - also displayed when not in vehicle
	self.global_info_text = nil
	
	-- course modes: 1 circle route - 2 returning route
	self.course_mode = 1
	
	-- ai mode: 1 abfahrer
	self.ai_mode = 1
	
	self.ArrowPath = Utils.getFilename("Specializations/arrow.png", self.baseDirectory);
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
	
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	
	
	self.numCollidingVehicles = 0;
	self.numToolsCollidingVehicles = {};
	
	self.tippers = {}
	self.tipper_attached = false	
	self.currentTrailerToFill = nil
	
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
	
	courseplay:infotext(self);
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


-- starts driving the course
function courseplay:start(self)    
	-- add do working players if not already added
	if self.working_course_player_num == nil then
		self.working_course_player_num = courseplay:add_working_player(self)
	end	
	
	self.tippers = {}
	-- are there any tippers?	
	self.tipper_attached, self.tippers = courseplay:update_tools(self, self.tippers)
		
	if self.tipper_attached then
		-- tool triggers for tippers
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

function courseplay:add_working_player(self)
   table.insert(working_course_players, self)
   return table.getn(working_course_players)
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


-- starts course recording
function courseplay:start_record(self)
    courseplay:reset_course(self)
	
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

		

-- drives recored course
function courseplay:drive(self)
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  self.dist = courseplay:distance(cx ,cz ,ctx ,ctz)
  local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
  local allowedToDrive = true;
  local in_traffic = false;
    
  local tx, ty, tz = getWorldTranslation(self.aiTrafficCollisionTrigger)
  local nx, ny, nz = localDirectionToWorld(self.aiTractorDirectionNode, 0, 0, 1)
  
  raycastAll(tx, ty, tz, nx, ny, nz, "findTipTriggerCallback", 10, self)
  
  if self.currentTipTrigger ~= nil then
	self.info_text = "near trigger"
  end
  
  -- abfahrer-mode
  if self.ai_mode == 1 and self.tipper_attached then
  
	-- tippers are not full
	-- TODO wegpunkt berücksichtigen
    if tipper_fill_level < tipper_capacity then
		allowedToDrive = false;
		self.info_text = string.format("Wird beladen: %d von %d ",tipper_fill_level,tipper_capacity )
	end
	
	-- tipper is not empty and tractor reaches TipTrigger
	if tipper_fill_level > 0 and self.currentTipTrigger ~= nil then
		allowedToDrive = false;
		self.info_text = "Tip Trigger erreicht"
	end
	
  end
  
  if self.numCollidingVehicles > 0 then
    allowedToDrive = false;
    in_traffic = true;
  end

   for k,v in pairs(self.numToolsCollidingVehicles) do
		if v > 0 then
			allowedToDrive = false;
			in_traffic = true;			
			break;
		end;
    end;
    
  if in_traffic then
    self.global_info_text = 'Abfahrer steckt im Verkehr fest'
  end

  
  if not allowedToDrive then
     local lx, lz = 0, 1; 
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
  self.info_text = string.format("entfernung: %d ",dist )  
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


function courseplay:infotext(self)
	if self.isEntered then
		if self.info_text ~= nil then
		  renderText(0.4, 0.001,0.02, self.info_text);
		end
	end
	
	if self.global_info_text ~= nil then
	  local yspace = self.working_course_player_num * 0.022
	  local show_name = ""
	  if self.name ~= nil then
	    show_name = self.name
	  end
	  renderText(0.4, yspace ,0.02, show_name .. " " .. self.global_info_text);
	end
	self.info_text = nil
	self.global_info_text = nil
end

function courseplay:distance(x1 ,z1 ,x2 ,z2)
	xd = (x1 - x2) * (x1 - x2)
	zd = (z1 -z2) * (z1 - z2)
	dist = math.sqrt(math.abs(xd + zd) )
	return dist
end

-- update implements
function courseplay:update_tools(tractor_or_implement, tippers)    
  local tipper_attached = false
  -- go through all implements
  for k,implement in pairs(tractor_or_implement.attachedImplements) do
    local object = implement.object
    if object.allowTipDischarge then
      tipper_attached = true
      table.insert(tippers, object)
    end    
	-- are there more tippers attached to the current implement?
    if table.getn(object.attachedImplements) ~= 0 then
	  
      local c, f = courseplay:update_tools(object, tippers)
      if c and f then
        tippers = f
      end
    end
  end
  if tipper_attached then
    return true, tippers
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
  print("i am in onTipTrigger")
  print(transformId)
  
  local trigger = g_currentMission.tipTriggers
  local count = table.getn(trigger)
  print(count)
  for i = 1, count do
    print(trigger[i].triggerId)
    if trigger[i].triggerId == transformId then
	  print("hab den trigger gefunden")
      self.currentTipTrigger = trigger[i]
    end
  end
end

-- saving // loading coures

-- saves coures to xml-file
function courseplay:save_courses(self)
  -- TODO gameIndex finden
  local path = getUserProfileAppPath() .. "savegame" .. gameIndex .. "/"
  local File = io.open(path .. "courseplay.xml", "w")
  local tab = "   "
  if File ~= nil then
    File:write("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\" ?>\n<XML>\n<courses>\n")
    for name,x in pairs(self.courses) do
      File:write(tab .. "<course name=\"" .. name .. "\">\n")
      for i = 1, table.getn(x) do
        local v = x[i]
        File:write(tab .. tab .. "<waypoint" .. i .. " pos=\"" .. v.cx .. " " .. v.cz .. "\" angle=\"" .. v.angle .. "\" />\n")
      end
      File:write(tab .. "</course>\n")
    end
    File:write("</courses>\n")
    
    File:write("\n</XML>\n")
    File:close()
  end
end


function courseplay:load_courses(self)
  
end


-- debugging data dumper
function table.show(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return string.format("%q", so .. ", C function")
         else 
            -- the information is defined through lines
            return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
         end
      elseif type(o) == "number" then
         return so
      else
         return string.format("%q", so)
      end
   end

   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] 
                        .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end