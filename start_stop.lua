-- starts driving the course
function courseplay:start(self)    
	
	if table.getn(self.Waypoints) < 1 then
	  return
	end
	
	self.numCollidingVehicles = 0;
	self.numToolsCollidingVehicles = {};
	self.drive  = false
	self.record = false
	
	if self.recordnumber < 1 then
	  self.recordnumber = 1
	end
	
	-- add do working players if not already added
	if self.working_course_player_num == nil then
		self.working_course_player_num = courseplay:add_working_player(self)
	end	
	
	courseplay:reset_tools(self)
	-- show arrow
	self.dcheck = true
	-- current position
	local ctx,cty,ctz = getWorldTranslation(self.rootNode);
	-- positoin of next waypoint
	local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
	-- distance
	dist = courseplay:distance(ctx ,ctz ,cx ,cz)	
	
	--if dist < 15 then
		-- hire a helper
		self:hire()
		-- ok i am near the waypoint, let's go
		self.checkSpeedLimit = false
		self.drive  = true
		if self.aiTrafficCollisionTrigger ~= nil then
		   addTrigger(self.aiTrafficCollisionTrigger, "onTrafficCollisionTrigger", self);
		end
		self.orgRpm = {} 
		self.orgRpm[1] = self.motor.maxRpm[1] 
		self.orgRpm[2] = self.motor.maxRpm[2] 
		self.orgRpm[3] = self.motor.maxRpm[3] 
		self.record = false
		self.dcheck = false
	--end
end

-- stops driving the course
function courseplay:stop(self)
	self:dismiss()
	self.motor.maxRpm[1] = self.orgRpm[1] 
	self.motor.maxRpm[2] = self.orgRpm[2] 
	self.motor.maxRpm[3] = self.orgRpm[3] 
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
	
	-- reseting variables
	self.unloaded = false
	self.checkSpeedLimit = true
	self.currentTipTrigger = nil
	self.drive  = false	
	self.play = true
	self.dcheck = false
	self.motor:setSpeedLevel(0, false);
	self.motor.maxRpmOverride = nil;
	
	AIVehicleUtil.driveInDirection(self, 0, 30, 0, 0, 28, false, moveForwards, 0, 1)	

end