-- starts driving the course
function courseplay:start(self)    
	
	self.numCollidingVehicles = 0;
	self.numToolsCollidingVehicles = {};
	self.drive  = false
	self.record = false
	
	if self.recordnumber == nil then
	  self.recordnumber = 1
	end
	
	-- add do working players if not already added
	if self.working_course_player_num == nil then
		self.working_course_player_num = courseplay:add_working_player(self)
	end	
	
	courseplay:reset_tools(self)
		
	if self.tipper_attached then
		-- tool (collision)triggers for tippers
		for k,object in pairs(self.tippers) do
		  AITractor.addToolTrigger(self, object)
		end
	end
	
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
		
		if self.recordnumber == nil then
			self.recordnumber = 1
		end
		-- ok i am near the waypoint, let's go
		self.checkSpeedLimit = false
		self.drive  = true
		if self.aiTrafficCollisionTrigger ~= nil then
		   addTrigger(self.aiTrafficCollisionTrigger, "onTrafficCollisionTrigger", self);
		end
		self.orgRpm = self.motor.maxRpm
		self.record = false
		self.dcheck = false
	--end
end

-- stops driving the course
function courseplay:stop(self)
	self:dismiss()
	self.motor.maxRpm = self.orgRpm
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
	WheelsUtil.updateWheelsPhysics(self, 0, 0, 0, false, self.requiredDriveMode)

end