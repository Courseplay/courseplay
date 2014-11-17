function courseplay:setNameVariable(workTool)
	if workTool.cp == nil then
		workTool.cp = {};
	end;

	if workTool.cp.hasSpecializationPathVehicle or workTool.cp.hasSpecializationTrafficVehicle then
		return;
	end;

	-- local specList = { 'AICombine', 'AITractor', 'AnimatedVehicle', 'BaleLoader', 'Baler', 'BunkerSiloCompacter', 'Combine', 'Cultivator', 'Cutter', 'Cylindered', 'Fillable', 'Foldable', 'FruitPreparer', 'MixerWagon', 'Mower', 'PathVehicle', 'Plough', 'Shovel', 'SowingMachine', 'Sprayer', 'Steerable', 'Tedder', 'TrafficVehicle', 'Trailer', 'Windrower' };

	-- Only default specs!
	for i,spec in pairs(workTool.specializations) do
		if     spec == AICombine 		   then workTool.cp.hasSpecializationAICombine 			 = true;
		elseif spec == AITractor 		   then workTool.cp.hasSpecializationAITractor 			 = true;
		elseif spec == AnimatedVehicle 	   then workTool.cp.hasSpecializationAnimatedVehicle 	 = true;
		elseif spec == ArticulatedAxis 	   then workTool.cp.hasSpecializationArticulatedAxis 	 = true;
		elseif spec == BaleLoader 		   then workTool.cp.hasSpecializationBaleLoader 		 = true;
		elseif spec == Baler 			   then workTool.cp.hasSpecializationBaler 				 = true;
		elseif spec == BunkerSiloCompacter then workTool.cp.hasSpecializationBunkerSiloCompacter = true;
		elseif spec == Combine 			   then workTool.cp.hasSpecializationCombine 			 = true;
		elseif spec == Cultivator 		   then workTool.cp.hasSpecializationCultivator 		 = true;
		elseif spec == Cutter 			   then workTool.cp.hasSpecializationCutter 			 = true;
		elseif spec == Cylindered 		   then workTool.cp.hasSpecializationCylindered 		 = true;
		elseif spec == Fillable 		   then workTool.cp.hasSpecializationFillable 			 = true;
		elseif spec == Foldable 		   then workTool.cp.hasSpecializationFoldable 			 = true;
		elseif spec == FruitPreparer 	   then workTool.cp.hasSpecializationFruitPreparer 		 = true;
		elseif spec == MixerWagon 		   then workTool.cp.hasSpecializationMixerWagon 		 = true;
		elseif spec == Mower 			   then workTool.cp.hasSpecializationMower 				 = true;
		elseif spec == PathVehicle 		   then workTool.cp.hasSpecializationPathVehicle 		 = true;
		elseif spec == Plough 			   then workTool.cp.hasSpecializationPlough 			 = true;
		elseif spec == Shovel 			   then workTool.cp.hasSpecializationShovel 			 = true;
		elseif spec == SowingMachine 	   then workTool.cp.hasSpecializationSowingMachine 		 = true;
		elseif spec == Sprayer 			   then workTool.cp.hasSpecializationSprayer 			 = true;
		elseif spec == Steerable 		   then workTool.cp.hasSpecializationSteerable 			 = true;
		elseif spec == Tedder 			   then workTool.cp.hasSpecializationTedder 			 = true;
		elseif spec == TrafficVehicle 	   then workTool.cp.hasSpecializationTrafficVehicle 	 = true;
		elseif spec == Trailer 			   then workTool.cp.hasSpecializationTrailer 			 = true;
		elseif spec == Windrower 		   then workTool.cp.hasSpecializationWindrower 			 = true;
		end;

		--[[
		-- alternate possible query:
		for i,specClassName in pairs(specList) do
			if spec == _G[specClassName] then 
				workTool.cp['hasSpecialization' .. specClassName] = true;
			end;
		end;
		]]
	end;

	if workTool.cp.hasSpecializationFillable then
		workTool.cp.closestTipDistance = math.huge;
	end;

	--[[ DEBUG
	print(nameNum(workTool) .. ': default specs list');
	for i,specClassName in pairs(specList) do
		local var = 'hasSpecialization' .. specClassName;
		if workTool.cp[var] then
			print(('\t[%s] %s=true'):format(specClassName, var));
		end;
	end;
	--]]



	--------------------------------------------------------------
	-- ###########################################################
	--------------------------------------------------------------

	-- SPECIALIZATIONS BASED
	-- [1] AUGER WAGONS
	if workTool.typeName == 'augerWagon' then
		workTool.cp.isAugerWagon = true;
		if workTool.cp.xmlFileName == 'horschTitan34UW.xml' then
			workTool.cp.isHorschTitan34UW = true;
			workTool.cp.foldPipeAtWaitPoint = true;
		end;
	elseif workTool.cp.hasSpecializationOverloader then
		workTool.cp.isAugerWagon = true;
		workTool.cp.hasSpecializationOverloaderV2 = workTool.overloaderVersion ~= nil and workTool.overloaderVersion >= 2;
	elseif workTool.cp.hasSpecializationAgrolinerTUW20 then
		workTool.cp.isAugerWagon = true;
		if workTool.cp.xmlFileName == 'AgrolinerTUW20.xml' then
			workTool.cp.isAgrolinerTUW20 = true;
			workTool.cp.foldPipeAtWaitPoint = true;
		end;
	elseif workTool.cp.hasSpecializationOvercharge then
		workTool.cp.isAugerWagon = true;
		if workTool.cp.xmlFileName == 'AgrolinerTUW20.xml' then
			workTool.cp.isAgrolinerTUW20 = true;
			workTool.cp.foldPipeAtWaitPoint = true;
		elseif workTool.cp.xmlFileName == 'HaweULW2600T.xml' then
			workTool.cp.isHaweULW2600T = true;
			workTool.cp.foldPipeAtWaitPoint = true;
		elseif workTool.cp.xmlFileName == 'HaweULW3000T.xml' then
			workTool.cp.isHaweULW3000T = true;
			workTool.cp.foldPipeAtWaitPoint = true;
		end;
	elseif workTool.cp.hasSpecializationHaweSUW then
		workTool.cp.isAugerWagon = true;
		if workTool.cp.xmlFileName == 'Hawe_SUW_4000.xml' then
			workTool.cp.isHaweSUW4000 = true;
		elseif workTool.cp.xmlFileName == 'Hawe_SUW_5000.xml' then
			workTool.cp.isHaweSUW5000 = true;
		end;
	elseif workTool.cp.hasSpecializationBigBear then
		workTool.cp.isAugerWagon = true;
		workTool.cp.isRopaBigBear = true;
		workTool.cp.foldPipeAtWaitPoint = true;
		workTool.cp.hasSpecializationBigBearV2 = workTool.setUnloading ~= nil and workTool.setWorkMode~= nil and workTool.setActiveWorkMode ~= nil;
	elseif workTool.animationParts ~= nil and workTool.animationParts[2] ~= nil and workTool.toggleUnloadingState ~= nil and workTool.setUnloadingState ~= nil then
		workTool.cp.isAugerWagon = true;
		workTool.cp.isTaarupShuttle = true;


	-- ###########################################################
	-- ###########################################################
	-- ###########################################################

	-- MODS
	-- [1] MOD COMBINES


	-- ###########################################################

	-- [2] MOD TRACTORS


	-- ###########################################################

	-- [3] MOD TRAILERS


	-- ###########################################################

	-- [4] MOD MANURE / LIQUID MANURE


	-- ###########################################################

	-- [5] MOD MOWERS


	-- ###########################################################

	-- [6] MOD BALING


	-- ###########################################################

	-- [7] MOD OTHER TOOLS



	-- ###########################################################
	-- ###########################################################
	-- ###########################################################


	-- GIANTS DEFAULT / DLC
	-- [1] COMBINES / CUTTERS
	-- Combines [Giants]
	elseif workTool.cp.xmlFileName == 'caseIH7130.xml' then
		workTool.cp.isCaseIH7130 = true;
	elseif workTool.cp.xmlFileName == 'caseIH9230Crawler.xml' then
		workTool.cp.isCaseIH9230Crawler = true;
	elseif workTool.cp.xmlFileName == 'newHollandTC590.xml' then
		workTool.cp.isNewHollandTC590 = true;
	elseif workTool.cp.xmlFileName == 'newHollandCR1090.xml' then
		workTool.cp.isNewHollandCR1090 = true;
	elseif workTool.cp.xmlFileName == 'sampoRosenlewC6.xml' then
		workTool.cp.isSampoRosenlewC6 = true;

	-- Harvesters (steerable) [Giants]
	elseif workTool.cp.xmlFileName == 'grimmeMaxtron620.xml' then
		workTool.cp.isHarvesterSteerable = true;
		workTool.cp.isGrimmeMaxtron620 = true;
	elseif workTool.cp.xmlFileName == 'grimmeTectron415.xml' then
		workTool.cp.isHarvesterSteerable = true;
		workTool.cp.isGrimmeTectron415 = true;

	-- Harvesters (attachable) [Giants]
	elseif workTool.cp.xmlFileName == 'grimmeRootster604.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeRootster604 = true;

	-- Cutters [Giants]
	elseif workTool.cp.xmlFileName == 'caseIH3162Cutter.xml' then
		workTool.cp.isCaseIH3162Cutter = true;

	-- ###########################################################

	-- [2] TRACTORS
	-- Case IH Puma 160 [Giants]
	elseif workTool.cp.xmlFileName == 'caseIHPuma160.xml' then
		workTool.cp.isCaseIHPuma160 = true;

	-- ###########################################################

	-- [3] TRAILERS
	-- Bergmann HTW 65 [Giants]
	elseif workTool.cp.xmlFileName == 'bergmannHTW65.xml' then
		workTool.cp.isBergmannHTW65 = true;
		workTool.cp.isPushWagon = true;


	-- ###########################################################

	-- [4] BALING
	-- Ursus T127 bale loader [Giants]
	elseif workTool.cp.xmlFileName == 'ursusT127.xml' then
		workTool.cp.isUrsusT127 = true;

	-- Ursus Z586 bale wrapper [Giants]
	elseif workTool.cp.xmlFileName == 'ursusZ586.xml' then
		workTool.cp.isUrsusZ586 = true;

	-- ###########################################################

	-- [5] OTHER TOOLS
	-- Seeders [Giants]
	elseif workTool.cp.xmlFileName == 'vaderstadRapidA600S.xml' then
		workTool.cp.isVaderstadRapidA600S = true;
	end;
end;

--[[TODO (Jakob): delete when new custom spec fn is made sure to always work correctly
function courseplay:setCustomSpecVariables(workTool)
	workTool.cp.hasSpecializationAgrolinerTUW20 	   = courseplay:hasSpecialization(workTool, 'AgrolinerTUW20');
	workTool.cp.hasSpecializationAugerWagon 		   = courseplay:hasSpecialization(workTool, 'AugerWagon');
	workTool.cp.hasSpecializationBigBear 			   = courseplay:hasSpecialization(workTool, 'bigBear');
	workTool.cp.hasSpecializationDrivingLine 		   = courseplay:hasSpecialization(workTool, 'DrivingLine');
	workTool.cp.hasSpecializationHaweSUW 			   = courseplay:hasSpecialization(workTool, 'Hawe_SUW');
	workTool.cp.hasSpecializationHoseRef 			   = courseplay:hasSpecialization(workTool, 'HoseRef');
	workTool.cp.hasSpecializationOvercharge 		   = courseplay:hasSpecialization(workTool, 'Overcharge');
	workTool.cp.hasSpecializationOverloader 		   = courseplay:hasSpecialization(workTool, 'overloader');
	workTool.cp.hasSpecializationSiloTrailer		   = courseplay:hasSpecialization(workTool, 'SiloTrailer');
	workTool.cp.hasSpecializationSowingMachineWithTank = courseplay:hasSpecialization(workTool, 'SowingMachineWithTank');
	workTool.cp.hasSpecializationTebbeHS180 		   = courseplay:hasSpecialization(workTool, 'TebbeHS180');
end;
]]

function courseplay:setCustomSpecVariables(vehicle)
	local customSpecNames = {
		['AgrolinerTUW20'] 		  = { },
		--['AugerWagon'] 			  = { useVehicleCustomEnvironment = true },
		['bigBear'] 			  = { },
		['DrivingLine'] 		  = { },
		['Hawe_SUW'] 			  = { },
		['HoseRef'] 			  = { },
		['Overcharge'] 			  = { },
		['overloader'] 			  = { },
		['SiloTrailer'] 		  = { },
		['SowingMachineWithTank'] = { },
		['TebbeHS180'] 			  = { }
	};

	local specToSpecClassName = {};

	local vehicleCustomEnvironment = vehicle.customEnvironment;
	local mrDlcsCustomEnvironment;
	if vehicle.typeName:lower():find('morerealisticdlcs.') then
		mrDlcsCustomEnvironment = Utils.splitString('.', vehicle.typeName)[1];
	end;

	for specClassName, data in pairs(customSpecNames) do
		local fullSpecClassName = specClassName;
		-- MoreRealisticDLCs vehicle
		if mrDlcsCustomEnvironment then
			-- spec must be in vehicle CE
			if data.useVehicleCustomEnvironment then
				if vehicleCustomEnvironment then
					fullSpecClassName = ('%s.%s'):format(vehicleCustomEnvironment, specClassName);
				end;

			-- spec in MoreRealisticDLCs CE
			else
				fullSpecClassName = ('%s.%s'):format(mrDlcsCustomEnvironment, specClassName);
			end;

		-- vehicle CE
		elseif vehicleCustomEnvironment then
			fullSpecClassName = ('%s.%s'):format(vehicleCustomEnvironment, specClassName);
		end;

		local spec = getClassObject(fullSpecClassName);
		if spec then
			specToSpecClassName[spec] = specClassName;
		end;
	end;

	for i, spec in ipairs(VehicleTypeUtil.vehicleTypes[vehicle.typeName].specializations) do
		if specToSpecClassName[spec] ~= nil then
			local varName = specToSpecClassName[spec]:gsub('^%l', string.upper):gsub('_', ''); -- first char uppercase, remove underscores
			vehicle.cp['hasSpecialization' .. varName] = true;
		end;
	end;
end;


------------------------------------------------------------------------------------------

function courseplay:isSpecialSowingMachine(workTool)
	return false;
end;

function courseplay:isSpecialSprayer(workTool)
	return false;
end;

function courseplay:isSpecialChopper(workTool)
	return false
end

function courseplay:isSpecialMower(workTool)
	return false;
end

function courseplay:isSpecialBaler(workTool)
	return false;
end;

function courseplay:isSpecialRoundBaler(workTool)
	return false;
end;

function courseplay:isSpecialBaleLoader(workTool)
	return false;
end;

function courseplay:isSpecialCombine(workTool, specialType, fileNames)
	if specialType ~= nil then
		if specialType == "sugarBeetLoader" then
		end;
	end;

	--[[if fileNames ~= nil and #fileNames > 0 then
		for i=1, #fileNames do
			if workTool.cp.xmlFileName == fileNames[i] .. '.xml' then
				return true;
			end;
		end;
		return false;
	end;]]

	return false;
end


function courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker)

	local implementsDown = lower and turnOn
	if workTool.PTOId then
		workTool:setPTO(false)
	end;

	--Ursus Z586 BaleWrapper
	if workTool.cp.isUrsusZ586 then
		if workTool.baleWrapperState == 4 then
			workTool:doStateChange(5)
		end
		if workTool.baleWrapperState ~= 0 then 
			allowedToDrive = false
		end

		return false ,allowedToDrive

	end;



	return false, allowedToDrive;
end

function courseplay:askForSpecialSettings(self, object)
	-- SPECIAL VARIABLES TO USE:
	--[[
	-- automaticToolOffsetX:					(Distance in meters)	Used to automatically set the tool horizontal offset.
	-- object.cp.haveInversedRidgeMarkerState:	(Boolean)				If the ridmarker is using the wrong side in auto mode, set this value to true
	-- object.cp.realUnfoldDirectionIsReversed:	(Boolean)				If the tool unfolds when driving roads and folds when working fields, then set this one to true to reverse the folding order.
	-- object.cp.isPushWagon					(Boolean)				Set to true if the trailer is unloading by not lifting the trailer but pushing it out in the rear end. (Used in BGA tipping)
	-- object.cp.specialUnloadDistance:			(Distance in meters)	Able to set the distance to the waiting point when it needs to unload. Used by bale loaders. Distance from trailer's turning point to the rear unloading point.
	-- self.cp.aiTurnNoBackward:				(Boolean)				Set to true if the vehicle is not allowed to reverse with the implement/trailer during the turn maneuver.
	-- self.cp.noStopOnEdge:                    (Boolean)               Set this to true if it dont need to stop the work tool while turning.
	--																	Some work tool types automatically set this to true.
	-- self.cp.noStopOnTurn:					(Boolean)				Set this to true if the work tool don't need to stop for 1½ sec before turning.
	--																	Some work tool types automatically set this to true.
	-- self.cp.backMarkerOffset:				(Distance in meters)	If the implement stops to early or to late, you can specify then it needs to raise/lower or turn on/off the work tool
	-- TODO: (Claus / Jakob) Add description for all the special varialbes that is usable here.
	]]

	courseplay:debug(('%s: askForSpecialSettings(..., %q)'):format(nameNum(self), nameNum(object)), 6);

	local automaticToolOffsetX;

	-- STEERABLES


	-- OBJECTS
	if object.cp.isVaderstadRapidA600S then
		object.cp.haveInversedRidgeMarkerState = true;

	elseif object.cp.isUrsusT127 then
		object.cp.specialUnloadDistance = -1.8;

	elseif object.cp.isAugerWagon then
		if object.cp.foldPipeAtWaitPoint then
			--object.cp.backPointsUnfoldPipe = 1;
			object.cp.forwardPointsFoldPipe = 0;
			if object.foldAnimTime ~= nil then
				object.cp.lastFoldAnimTime = object.foldAnimTime;
			end;
		end;
		object.cp.lastFillLevel = object.fillLevel;

		if object.cp.isHaweSUW4000 or object.cp.isHaweSUW5000 or object.cp.isHaweULW2600T or object.cp.isHaweULW3000T then
			object.cp.hasPipeLight = object.B3 and object.B3.work and object.B3.work[1];
			if object.cp.hasPipeLight then
				object.cp.pipeLight = object.B3.work[1];
			end;
		elseif object.cp.hasSpecializationBigBear then
			if (self.cp.mode == 2 or self.cp.mode == 3) and not object.workMode then
				if object.cp.hasSpecializationBigBearV2 then
					object:setWorkMode(true);
				else
					object.workMode = true;
					object.cp.needsEvent = true;
				end;
			end;
		end;

	elseif object.cp.isGrimmeRootster604 then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -0.9
		print("Grimme Rootster 604 workwidth: 2.8 m");
	elseif object.cp.isUrsusZ586 then
		self.cp.aiTurnNoBackward = true
		self.cp.noStopOnEdge = true
		self.cp.noStopOnTurn = true
		automaticToolOffsetX = -2.5;
	end

	if automaticToolOffsetX ~= nil then
		self.cp.tempToolOffsetX = self.cp.toolOffsetX;
		courseplay:changeToolOffsetX(self, nil, automaticToolOffsetX, true);
	end;
end

function courseplay:getSpecialWorkWidth(workTool)
	--[[if workTool.cp then
		if workTool.cp.isLindnerTankModule then
			return 6.0;
		end;
	end;]]

	return nil;
end;

function courseplay:handleSpecialSprayer(self, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, pumpDir)
	return false, allowedToDrive,lx,lz;
end

function courseplay:moveSingleTool(vehicle, activeTool, toolIndex, x,y,z, dt)
	--local toolRot = activeTool.movingTools[9].curRot[3]
	local tool = activeTool.movingTools[toolIndex];
	local rotSpeed = 0.0033;
	local targetRot = {x,y,z}
	local done = true;
	local changed = false;
	if dt == nil then dt = g_physicsDt; end;
	if tool.rotSpeed ~= nil then
		rotSpeed = tool.rotSpeed * dt;
	end;
	for i=1, 3 do
		local oldRot = tool.curRot[i];
		local target = targetRot[i]
		local newRot = nil;
		if target ~= oldRot then
			done = false
		end
		local dir = targetRot[i] - oldRot;
		dir = math.abs(dir)/dir;

		if tool.node ~= nil and tool.rotMin ~= nil and tool.rotMax ~= nil and dir ~= nil and dir ~= 0 then
			newRot = Utils.clamp(oldRot + (rotSpeed * dir), tool.rotMin, tool.rotMax);
			if (dir == 1 and newRot > targetRot[i]) or (dir == -1 and newRot < targetRot[i]) then
				newRot = targetRot[i];
			end;
			if newRot ~= oldRot and newRot >= tool.rotMin and newRot <= tool.rotMax then
				tool.curRot[i] = newRot;
				setRotation(tool.node, unpack(tool.curRot));
				changed = true;
			end;
		end;
	end;

	if changed then
		Cylindered.setDirty(vehicle, tool);
		vehicle:raiseDirtyFlags(vehicle.cylinderedDirtyFlag);
	end;

	return done

end

--- rotateSingleTool Usage
--- @param vehicle 		[Object] 			The vehicle it self.
--- @param activeTool 	[Object] 			The working tool or vehicle it self.
--- @param toolIndex 	[Number] 			The moving tool index from the activeTool.movingTools
--- @param rotatePos 	[Boolean or Number]	If boolean, then it will rotate to max or min position based on true or false.
---											If Number, then rotate to that position in degree.
--- @param dt			[Number or Nil]		The time in ms since last update. If nil, then it use the global dt from the game.
function courseplay:rotateSingleTool(vehicle, activeTool, toolIndex, rotatePos, dt)
	if vehicle == nil or activeTool == nil or toolIndex == nil or rotatePos == nil then
		return;
	end;

	dt = dt or g_physicsDt;

	local mt = activeTool.movingTools[toolIndex];
	local changed = false;

	local curRot = mt.curRot[mt.rotationAxis];
	local targetRot = mt.invertAxis and mt.rotMax or mt.rotMin;

	if type(rotatePos) == 'boolean' then
		if rotatePos then
			targetRot = mt.invertAxis and mt.rotMin or mt.rotMax;
		end;
	elseif type(rotatePos) == 'number' then
		targetRot = Utils.clamp(math.rad(rotatePos), mt.rotMin, mt.rotMax);
	else
		-- Unsupported rotatePos format, so we returns.
		return;
	end;

	if courseplay:round(curRot, 4) ~= courseplay:round(targetRot, 4) then
		local newRot;

		local rotDir = Utils.sign(targetRot - curRot);

		if mt.node and mt.rotMin and mt.rotMax and rotDir ~= 0 then
			local rotChange = mt.rotSpeed ~= nil and (mt.rotSpeed * dt) or (0.2/dt);
			newRot = Utils.clamp(curRot + (rotChange * rotDir), mt.rotMin, mt.rotMax);
			if (rotDir == 1 and newRot > targetRot) or (rotDir == -1 and newRot < targetRot) then
				newRot = targetRot;
			end;
			if newRot ~= curRot and newRot >= mt.rotMin and newRot <= mt.rotMax then
				mt.curRot[mt.rotationAxis] = newRot;
				setRotation(mt.node, unpack(mt.curRot));
				changed = true;
			end;
		end;
	end;

	if changed then
		Cylindered.setDirty(vehicle, mt);
		vehicle:raiseDirtyFlags(vehicle.cylinderedDirtyFlag);
	end;
end;
