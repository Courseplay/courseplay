--
--	automatic overcharging for trailers with courseplay-attachervehicles
--	
-- Brent Avelanche, Hilken, Agroliner TUW & Co., Kverneland Taarup Shuttle & Co.
--

AutoOvercharge = {};

function AutoOvercharge.prerequisitesPresent(specializations)
    return true;
end;

function AutoOvercharge:load(xmlFile)

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

	-- Brent Avelanche
	if self.lowerRmp ~= nil and self.attacherVehicle then
		if ((self.attacherVehicle.isHired or self.attacherVehicle.drive) and not self.turnOn) and self.inRangeDraw and self.Go.trsp and self.CheckDone.trsp then
			self.turnOn = true;
		end;
	end;
	
	-- Automatischer Überlademodus Taarup Shuttle
	if self.toggleUnloadingState ~= nil then
		if self:getIsActive() and self.attacherVehicle ~= nil and (self.attacherVehicle.isHired or self.attacherVehicle.drive) then
					
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

end;

function AutoOvercharge:updateTick(dt)
		
	-- Hilken & Agroliner TUW
	if self.toggleUnloadingState == nil and self.setUnloadingState ~= nil then
		if self.varTip ~= nil then
			if self.varTip.enableOvercharge == false then 
				return;
			end;
		end;

		if self:getIsActive() then
			if self.trailerFoundId ~= nil and self.trailerFoundId ~= 0 then
				--print("trailer found!");
				local trailer = g_currentMission.nodeToVehicle[self.trailerFoundId];
				if trailer ~= nil and trailer ~= self and 
					trailer.allowFillFromAir and trailer.capacity ~= trailer.fillLevel and
					(trailer:allowFillType(Fillable.fillTypeNameToInt["seeds"], true) or
					 trailer:allowFillType(self.currentFillType, true) )then
					-- Automatischer Überlademodus
					if self.isUnloading == false and self.attacherVehicle ~= nil and (self.attacherVehicle.isHired or self.attacherVehicle.drive) then
						self:setUnloadingState(true);
					end;
					--
					
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