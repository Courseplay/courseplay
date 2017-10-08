--COURSEPLAY
SpecializationUtil.registerSpecialization('courseplay', 'courseplay', g_currentModDirectory .. 'courseplay.lua');
if courseplay.houstonWeGotAProblem then
	return;
end;

local drivableSpec = SpecializationUtil.getSpecialization('drivable');
local courseplaySpec = SpecializationUtil.getSpecialization('courseplay');
local numInstallationsVehicles = 0;

function courseplay:register(secondTime)
	if secondTime then
		print('## Courseplay: register later loaded mods');
	end
	for typeName,vehicleType in pairs(VehicleTypeUtil.vehicleTypes) do
		if vehicleType and not SpecializationUtil.hasSpecialization(courseplay, vehicleType.specializations) then 
			for i,spec in pairs(vehicleType.specializations) do
				if spec and spec == drivableSpec then
					if courseplay.isDevVersion then
						print(('  adding Courseplay to %q'):format(tostring(vehicleType.name)));
					end
					table.insert(vehicleType.specializations, courseplaySpec);
					vehicleType.hasCourseplaySpec = true;
					vehicleType.hasDrivableSpec = true;
					numInstallationsVehicles = numInstallationsVehicles + 1;
					break;
				end;
			end;
		end;
	end;
end;

AIVehicle.startAIVehicle = Utils.overwrittenFunction(AIVehicle.startAIVehicle,courseplay.startAIVehicle)

function courseplay:attachablePostLoad(xmlFile)
	if self.cp == nil then self.cp = {}; end;

	if self.cp.xmlFileName == nil then
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;
	
	--SET SPECIALIZATION VARIABLE
	courseplay:setNameVariable(self);
	courseplay:setCustomSpecVariables(self);

	if courseplay.liquidManureOverloaders == nil then
		courseplay.liquidManureOverloaders ={}
	end
	if self.cp.isLiquidManureOverloader then
		courseplay.liquidManureOverloaders[self.rootNode] = self
	end
	

	--SEARCH AND SET OBJECT'S self.name IF NOT EXISTING
	if self.name == nil then
		self.name = courseplay:getObjectName(self, xmlFile);
	end;
end;
Attachable.postLoad = Utils.appendedFunction(Attachable.postLoad, courseplay.attachablePostLoad);

function courseplay:attachableDelete()
	if self.cp ~= nil then
		if self.cp.isLiquidManureOverloader then
			courseplay.liquidManureOverloaders[self.rootNode] = nil
		end
	end;
end;
Attachable.delete = Utils.prependedFunction(Attachable.delete, courseplay.attachableDelete);

function courseplay.vehiclePostLoadFinished(self)
	if self.cp == nil then self.cp = {}; end;

	-- XML FILE NAME VARIABLE
	if self.cp.xmlFileName == nil then
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;

	-- make sure every vehicle has the CP API functions
	self.getIsCourseplayDriving = courseplay.getIsCourseplayDriving;
	self.setIsCourseplayDriving = courseplay.setIsCourseplayDriving;
	self.setCpVar = courseplay.setCpVar;
	
	courseplay:setNameVariable(self);
	
	-- combines table
	if courseplay.combines == nil then
		courseplay.combines = {};
	end;
	if self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader or courseplay:isAttachedCombine(self) then
		courseplay.combines[self.rootNode] = self;
	end;
end;
Vehicle.loadFinished = Utils.appendedFunction(Vehicle.loadFinished, courseplay.vehiclePostLoadFinished);
-- NOTE: using loadFinished() instead of load() so any other mod that overwrites Vehicle.load() doesn't interfere


function courseplay:prePreDelete(self)
	if self.cp ~= nil then
		courseplay:deleteMapHotspot(self);
	end
end;
FSBaseMission.removeVehicle = Utils.prependedFunction(FSBaseMission.removeVehicle, courseplay.prePreDelete);


function courseplay:vehicleDelete()
	if self.cp ~= nil then
		-- Remove created nodes
		if self.cp.notesToDelete and #self.cp.notesToDelete > 0 then
			for _, nodeId in ipairs(self.cp.notesToDelete) do
				if nodeId and nodeId ~= 0 then
					delete(nodeId);
				end;
			end;
			self.cp.notesToDelete = nil;
		end;

		if courseplay.combines[self.rootNode] then
			courseplay.combines[self.rootNode] = nil;
		end;
	end;
end;
Vehicle.delete = Utils.prependedFunction(Vehicle.delete, courseplay.vehicleDelete);

function courseplay:foldableLoad(savegame)
	if self.cp == nil then self.cp = {}; end;

	--FOLDING PARTS STARTMOVEDIRECTION
	local startMoveDir = getXMLInt(self.xmlFile, 'vehicle.foldingParts#startMoveDirection');
	if startMoveDir == nil then
 		local singleDir;
		local i = 0;
		while true do -- go through single foldingPart entries
			local key = string.format('vehicle.foldingParts.foldingPart(%d)', i);
			if not hasXMLProperty(self.xmlFile, key) then break; end;
			local dir = getXMLInt(self.xmlFile, key .. '#startMoveDirection');
			if dir then
				if singleDir == nil then --first foldingPart -> set singleDir
					singleDir = dir;
				elseif dir ~= singleDir then -- two or more foldingParts have non-matching startMoveDirections --> not valid
					singleDir = nil;
					break;
				elseif dir == singleDir then -- --> valid
				end;
			end;
			i = i + 1;
		end;
		if singleDir then -- startMoveDirection found in single foldingPart
			startMoveDir = singleDir;
		end;
	end;

	self.cp.foldingPartsStartMoveDirection = Utils.getNoNil(startMoveDir, 0);
end;
Foldable.load = Utils.appendedFunction(Foldable.load, courseplay.foldableLoad);

courseplay.locales = courseplay.utils.table.copy(g_i18n.texts, true);
courseplay:register();
print(string.format('### Courseplay: installed into %d vehicles', numInstallationsVehicles));

-- TODO: Remove the AIVehicleUtil.driveToPoint overwrite when the new patch goes out to fix it. (Temp fix from Giants: Emil)
local originalDriveToPoint = AIVehicleUtil.driveToPoint;
AIVehicleUtil.driveToPoint = function(self, dt, acceleration, allowedToDrive, moveForwards, tX, tZ, maxSpeed, doNotSteer)

	if self.firstTimeRun then

		if allowedToDrive then

			local tX_2 = tX * 0.5;
			local tZ_2 = tZ * 0.5;

			local d1X, d1Z = tZ_2, -tX_2;
			if tX > 0 then
				d1X, d1Z = -tZ_2, tX_2;
			end

			local hit,_,f2 = Utils.getLineLineIntersection2D(tX_2,tZ_2, d1X,d1Z, 0,0, tX, 0);

			if doNotSteer == nil or not doNotSteer then
				local rotTime = 0;
				local radius = 0;
				if hit and math.abs(f2) < 100000 then
					radius = tX * f2;
					rotTime = self.wheelSteeringDuration * ( math.atan(1/radius) / math.atan(1/self.maxTurningRadius) );
				end

				local targetRotTime = 0;
				if rotTime >= 0 then
					targetRotTime = math.min(rotTime, self.maxRotTime)
				else
					targetRotTime = math.max(rotTime, self.minRotTime)
				end

				if targetRotTime > self.rotatedTime then
					self.rotatedTime = math.min(self.rotatedTime + dt*self.aiSteeringSpeed, targetRotTime);
				else
					self.rotatedTime = math.max(self.rotatedTime - dt*self.aiSteeringSpeed, targetRotTime);
				end

				-- adjust maxSpeed
				local steerDiff = targetRotTime - self.rotatedTime;
				local fac = math.abs(steerDiff) / math.max(self.maxRotTime, -self.minRotTime);
				maxSpeed = maxSpeed * math.max( 0.01, 1.0 - fac);
			end;
		end

		self.motor:setSpeedLimit(maxSpeed);
		if self.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
			self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
		end

		if not allowedToDrive then
			acceleration = 0;
		end
		if not moveForwards then
			acceleration = -acceleration;
		end

		if not g_currentMission.missionInfo.stopAndGoBraking then
			if acceleration ~= self.nextMovingDirection then
				if not self.hasStopped then
					if math.abs(self.lastSpeedAcceleration) < 0.0001 and math.abs(self.lastSpeedReal) < 0.0001 and math.abs(self.lastMovedDistance) < 0.001 then
						acceleration = 0;
					end
				end
			end
		end

		WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal, acceleration, not allowedToDrive, self.requiredDriveMode);

	end

end