--
--	automatic overcharging for trailers with courseplay-attachervehicles
--	
-- Brent Avelanche, Hilken, Agroliner TUW & Co., HAWE SUW 5000, Kverneland Taarup Shuttle & Co.
-- Bastian82

AutoOvercharge = {};

function AutoOvercharge.prerequisitesPresent(specializations)
    return true;
end;

function AutoOvercharge:load(xmlFile)
	self.wasfolded = true;
	self.wasclosed = false;
end;

function AutoOvercharge:delete()
	
end;

function AutoOvercharge:readStream(streamId, connection)
	
end;

function AutoOvercharge:writeStream(streamId, connection)
	
end;

function AutoOvercharge:mouseEvent(posX, posY, isDown, isUp, button)
end;

function AutoOvercharge:keyEvent(unicode, sym, modifier, isDown)
end;

function AutoOvercharge:update(dt)

	if self.attacherVehicle ~= nil and (self.attacherVehicle.isHired or self.attacherVehicle.drive) then
	if self.attacherVehicle.ai_mode ~= nil and self.attacherVehicle.ai_mode == 3 then
		-- Brent Avelanche
		if self.lowerRmp ~= nil and self.attacherVehicle.movingDirection == 0 then
			if not self.turnOn and self.inRangeDraw and self.Go.trsp and self.CheckDone.trsp then
				self.turnOn = true;
			end;
		end;
		
		if self.animationParts ~= nil then		
			-- Automatischer Überlademodus Taarup Shuttle
			if self.toggleUnloadingState ~= nil then
				if self:getIsActive() then
							
					if self.allowunload and self.activeUnloading == false then
						self:setUnloadingState(true);
					end;
							
					if self.attacherVehicle.ai_state == 0 and self.attacherVehicle.movingDirection == 0 and self.allowunload == false and self.unloadingState == 1 then
						self:setAnimationTime(2, self.animationParts[2].animDuration, false);
					end;
					
					if self.attacherVehicle.ai_state == 0 and self.attacherVehicle.movingDirection == 0 and self.unloadingState == 0 then
						self:setAnimationTime(1, self.animationParts[1].animDuration, false);
						self.open = true;
					end;
					
					if (self.filllevel == 0 or self.attacherVehicle.ai_state > 0) and self.unloadingState == 1 then
						self:setAnimationTime(1, self.animationParts[1].offSet, false);
						self:setUnloadingState(false);
					end;
				end;
			end;

			
			
			-- Hilken & Agroliner TUW & HAWE SUW 5000
			if self.toggleUnloadingState == nil and self.setUnloadingState ~= nil then
				if self:getIsActive() then
				-- HAWE SUW 5000
					if self.isDrumActivated ~= nil then	
						if self.pipe ~= nil and self.attacherVehicle.ai_state == 0 and self.attacherVehicle.movingDirection == 0 then
							if not self.pipe.out then
								self:setAnimationTime(1, self.animationParts[1].animDuration, false);
							end;
						end;
						if (self.filllevel == 0 or self.attacherVehicle.ai_state > 0) then
							if self.pipe ~= nil and self.pipe.out then
								self:setAnimationTime(1, self.animationParts[1].offSet, false);
							end;
						end;
						self.isDrumActivated = self.isUnloading;
					else
						-- Agroliner, Hilken with optional folding of the pipe
						if self.pipe ~= nil and self.attacherVehicle.ai_state == 0 and self.attacherVehicle.movingDirection == 0 then
							if not self.pipe.out then
								if self.planeOpen == nil then
									-- Hilken
									self:setAnimationTime(1, self.animationParts[self.pipe.animOpenIdx].animDuration, false);
								else 
									-- Agroliner
									self:setAnimationTime(1, self.animationParts[1].animDuration, false);
								end;
							end;
						end;
						-- Agroliner Plane close
						if (self.attacherVehicle.ai_state == 0 or self.loaded) and self.planeOpen ~= nil and self.planeOpen and self.wasclosed then
							self:setAnimationTime(3, self.animationParts[3].offSet, false);
						end;
						
						if (self.filllevel == 0 or self.attacherVehicle.ai_state > 0) then
							if self.pipe ~= nil and self.pipe.out and self.wasfolded then
								if self.planeOpen == nil then
									-- Hilken
									self:setAnimationTime(1, self.animationParts[self.pipe.animOpenIdx].offSet, false);
								else 
									-- Agroliner
									self:setAnimationTime(1, self.animationParts[1].offSet, false);
								end;
							end;
							-- Agroliner Plane open
							if self.planeOpen ~= nil and not self.planeOpen then
								self:setAnimationTime(3, self.animationParts[3].animDuration, false);
							end;
						end;
					end;
					
				end;
			end;
			
			
		end;

		
		-- save pipe and plane status before courseplay start
		if self.toggleUnloadingState == nil and self.setUnloadingState ~= nil and self.pipe ~= nil and self.attacherVehicle ~= nil and not self.attacherVehicle.drive then
			self.wasfolded = not self.pipe.out;
			if self.planeOpen ~= nil then
				self.wasclosed = not self.planeOpen;
			end;
		end;

	end;
	end;
end;

function AutoOvercharge:updateTick(dt)
	if self.attacherVehicle~= nil and self.attacherVehicle.ai_mode ~= nil and self.attacherVehicle.ai_mode == 3 then
	-- Hilken & Agroliner TUW & HAWE SUW 5000
	if self.toggleUnloadingState == nil and self.setUnloadingState ~= nil then

		if self:getIsActive() then
			if self.trailerFoundId ~= nil and self.trailerFoundId ~= 0 then
				courseplay:debug("AutoOvercharge trailer found!", 3);
				local trailer = g_currentMission.nodeToVehicle[self.trailerFoundId];
				if trailer ~= nil and trailer ~= self and 
					trailer.allowFillFromAir and trailer.capacity ~= trailer.fillLevel and
					(trailer:allowFillType(Fillable.fillTypeNameToInt["seeds"], true) or
					 trailer:allowFillType(self.currentFillType, true) )then
					-- Automatischer Überlademodus
					if self.isUnloading == false and self.attacherVehicle ~= nil and self.attacherVehicle.movingDirection == 0 and (self.attacherVehicle.isHired or self.attacherVehicle.drive) then
						self:setUnloadingState(true);
					end;
					--
					
				end;
			end;
		end;
	end;
	end;

end;

function AutoOvercharge:draw()	

end;

function AutoOvercharge:onAttach(attacherVehicle)

end;

function AutoOvercharge:onDetach()

end;

function AutoOvercharge:onLeave()
	
end;

function AutoOvercharge:onDeactivate()

end;

function AutoOvercharge:onDeactivateSounds()

end;



--Perard Innerbanne 25
--hz888

-- edited (optimized for courseplay) by Bastian82 - (find on planet-ls.de)

perard = {};

function perard.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Trailer, specializations);
end;

function perard:load(xmlFile)

    self.pipeParticles = {};
    local i = 0;
    while true do
	local key = string.format("vehicle.pipeParticles.pipeParticle(%d)", i);
        local t = getXMLString(xmlFile, key .. "#type");
        if t == nil then
        	break;
        end;
        local desc = FruitUtil.fruitTypes[t];
        if desc ~= nil then
	        local fillType = FruitUtil.fruitTypeToFillType[desc.index];
	        local currentPS = {};
                local particleNode = Utils.loadParticleSystem(xmlFile, currentPS, key, self.components, false, "particleSystems/wheatParticleSystem.i3d", self.baseDirectory);
	                self.pipeParticles[fillType] = currentPS;
	                if self.defaultpipeParticles == nil then
	                	self.defaultpipeParticles = currentPS;
	                end;
        end;
        i = i + 1;
    end;

    self.TrailerTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.TrailerTrigger#index"));
    self.onTrigger = perard.onTrigger;
    if self.TrailerTrigger ~= nil then
    	addTrigger(self.TrailerTrigger, "onTrigger", self);
    end;
    self.isTrailerInRange = false;
    self.kardan1 = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.kardan1#index"));
    self.kardan2 = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.kardan2#index"));
    self.grainUnloading = 15;

    local pipeNode = Utils.indexToObject(self.rootNode, getXMLString(xmlFile, "vehicle.pipe#index"));
    if pipeNode ~= nil then
        self.pipe = {};
        self.pipe.node = pipeNode;
        local x, y, z = Utils.getVectorFromString(getXMLString(xmlFile, "vehicle.pipe#minRot"));
        self.pipe.minRot = {};
        self.pipe.minRot[1] = Utils.degToRad(Utils.getNoNil(x, 0));
        self.pipe.minRot[2] = Utils.degToRad(Utils.getNoNil(y, 0));
        self.pipe.minRot[3] = Utils.degToRad(Utils.getNoNil(z, 0));

        x, y, z = Utils.getVectorFromString(getXMLString(xmlFile, "vehicle.pipe#maxRot"));
        self.pipe.maxRot = {};
        self.pipe.maxRot[1] = Utils.degToRad(Utils.getNoNil(x, 0));
        self.pipe.maxRot[2] = Utils.degToRad(Utils.getNoNil(y, 0));
        self.pipe.maxRot[3] = Utils.degToRad(Utils.getNoNil(z, 0));

        self.pipe.rotTime = Utils.getNoNil(getXMLString(xmlFile, "vehicle.pipe#rotTime"), 2)*1000;
        self.pipe.touchRotLimit = Utils.degToRad(Utils.getNoNil(getXMLString(xmlFile, "vehicle.pipe#touchRotLimit"), 10));
    end;

    local pipe1Node = Utils.indexToObject(self.rootNode, getXMLString(xmlFile, "vehicle.pipe1#index"));
    if pipe1Node ~= nil then
        self.pipe1 = {};
        self.pipe1.node = pipe1Node;
        local x, y, z = Utils.getVectorFromString(getXMLString(xmlFile, "vehicle.pipe1#minRot"));
        self.pipe1.minRot = {};
        self.pipe1.minRot[1] = Utils.degToRad(Utils.getNoNil(x, 0));
        self.pipe1.minRot[2] = Utils.degToRad(Utils.getNoNil(y, 0));
        self.pipe1.minRot[3] = Utils.degToRad(Utils.getNoNil(z, 0));

        x, y, z = Utils.getVectorFromString(getXMLString(xmlFile, "vehicle.pipe1#maxRot"));
        self.pipe1.maxRot = {};
        self.pipe1.maxRot[1] = Utils.degToRad(Utils.getNoNil(x, 0));
        self.pipe1.maxRot[2] = Utils.degToRad(Utils.getNoNil(y, 0));
        self.pipe1.maxRot[3] = Utils.degToRad(Utils.getNoNil(z, 0));

        self.pipe1.rotTime = Utils.getNoNil(getXMLString(xmlFile, "vehicle.pipe1#rotTime"), 2)*1000;
        self.pipe1.touchRotLimit = Utils.degToRad(Utils.getNoNil(getXMLString(xmlFile, "vehicle.pipe1#touchRotLimit"), 10));
    end;
	
	self.pipeMax = false;
	self.ont = false;

end;

function perard:delete()

    for _, particleSystem in pairs(self.pipeParticles) do
        Utils.deleteParticleSystem(particleSystem);
    end;

end;

function perard:readStream(streamId, connection)

end;

function perard:writeStream(streamId, connection)

end;

function perard:mouseEvent(posX, posY, isDown, isUp, button)
end;

function perard:keyEvent(unicode, sym, modifier, isDown)

end;

function perard:update(dt)
		
	if self:getIsActiveForInput() then
		if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA) then
			self.pipeMax = not self.pipeMax;
		end;

		if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA2) and self.trailerFound ~= nil and self.pipeMax then
			self.ont = not self.ont;
		end;
	end;
	
	if self:getIsActive() and self.attacherVehicle ~= nil and self.attacherVehicle.drive then
		-- Pipe
		if self.attacherVehicle.ai_state == 0 and self.attacherVehicle.movingDirection == 0 and self.pipeMax == false then
			self.pipeMax = true	
		end;	
		if self.filllevel == 0 or self.attacherVehicle.ai_state > 0 and self.pipeMax == true then
			self.pipeMax = false	
		end;
	end;
	
	--self.trailerFound = 0;
	
    if self:getIsActive() then
		local trailer = g_currentMission.nodeToVehicle[self.trailerFound];
		if self.trailerFound ~= nil and self.pipeMax then
			if self.attacherVehicle ~= nil and self.attacherVehicle.drive then 
				self.ont = true 
			end;
			if self.ont then
				local deltaLevel = self.grainUnloading;
				if trailer ~= nil and trailer ~= self and 
				trailer.capacity ~= trailer.fillLevel and
				(trailer:allowFillType(Fillable.fillTypeNameToInt["seeds"], true) or
				trailer:allowFillType(self.currentFillType, true)) then
					deltaLevel = math.min(deltaLevel, trailer.capacity - trailer.fillLevel);
					if trailer.fillLevel >= trailer.capacity then
						self.ont = false;
					end;
					if self.fillLevel <= 0.0 then
						Utils.setEmittingState(self.pipeParticles[self.currentFillType], false);
					else
						Utils.setEmittingState(self.pipeParticles[self.currentFillType], true);
							end;
				else
					deltaLevel = 0;
					self.ont = false;
					Utils.setEmittingState(self.pipeParticles[self.currentFillType], false);
				end;
						if self.fillLevel <= 0.0 then
							deltaLevel = deltaLevel+self.fillLevel;
							self.fillLevel = 0.0;
					self.ont = false;
						end;
					self:setFillLevel(self.fillLevel-deltaLevel, self.currentFillType);
				if trailer ~= nil then
					trailer:setFillLevel(trailer.fillLevel+deltaLevel, self.currentFillType);
				end;
			else
				Utils.setEmittingState(self.pipeParticles[self.currentFillType], false);
			end;
			if self.ont and self.kardan1 ~= nil then
				rotate(self.kardan1, 0, 0,dt*0.02);
			end;
			if self.ont and self.kardan2 ~= nil then
				rotate(self.kardan2, 0, 0,dt*-0.02);
			end;
		else
			Utils.setEmittingState(self.pipeParticles[self.currentFillType], false);

		end;
		if self.pipe ~= nil then
			local x, y, z = getRotation(self.pipe.node);
			local rot = {x,y,z};
			local newRot = Utils.getMovedLimitedValues(rot, self.pipe.maxRot, self.pipe.minRot, 3, self.pipe.rotTime, dt, not self.pipeMax);
			setRotation(self.pipe.node, unpack(newRot));
		end;
		if self.pipe1 ~= nil then
			local x, y, z = getRotation(self.pipe1.node);
			local rot = {x,y,z};
			local newRot = Utils.getMovedLimitedValues(rot, self.pipe1.maxRot, self.pipe1.minRot, 3, self.pipe1.rotTime, dt, not self.pipeMax);
			setRotation(self.pipe1.node, unpack(newRot));
		end;

    end;

end;

function perard:draw()

    if self.pipeMax then
    	if self.trailerFound ~= nil then
			if self.ont then
					g_currentMission:addHelpButtonText("Ueberladen ausschalten", InputBinding.IMPLEMENT_EXTRA2);
			else
				if self.fillLevel > 0.0 then
					g_currentMission:addHelpButtonText("Ueberladen einschalten", InputBinding.IMPLEMENT_EXTRA2);
				end;
			end;
    	end;
	g_currentMission:addHelpButtonText("Schnecke einklappen", InputBinding.IMPLEMENT_EXTRA);
    else
	g_currentMission:addHelpButtonText("Schnecke ausklappen", InputBinding.IMPLEMENT_EXTRA);
    end;

end;

function perard:onTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)

    if self:getIsActive() then
    	if onStay or onEnter then
        	self.isTrailerInRange = true;
		self.trailerFound = otherId;
	elseif onLeave then
                self.isTrailerInRange = false;
		self.trailerFound = nil;
        end;
    end;

end;


