function courseplay:setNameVariable(workTool)
	if workTool.cp == nil then
		workTool.cp = {};
	end;
	--[[local counter = 0;
	if workTool.fillUnits ~= nil then
		for index ,unit in pairs(workTool.fillUnits) do
			counter = counter +1
		end
	end
	print(string.format("%s: has %d fillUnits",tostring(workTool.name),counter))
	]]

	courseplay:updateFillLevelsAndCapacities(workTool)


	-- Only default specs!
	for i,spec in pairs(workTool.specializations) do
		if     spec == AnimatedVehicle 	   then workTool.cp.hasSpecializationAnimatedVehicle 	 = true;
		elseif spec == ArticulatedAxis 	   then workTool.cp.hasSpecializationArticulatedAxis 	 = true;
		elseif spec == BaleLoader 		   then workTool.cp.hasSpecializationBaleLoader 		 = true;
		elseif spec == Baler 			   then workTool.cp.hasSpecializationBaler 				 = true;
		elseif spec == Combine 			   then workTool.cp.hasSpecializationCombine 			 = true;
		elseif spec == Cover 			   then workTool.cp.hasSpecializationCover				 = true;
		elseif spec == Cultivator 		   then workTool.cp.hasSpecializationCultivator 		 = true;
		elseif spec == Cutter 			   then workTool.cp.hasSpecializationCutter 			 = true;
		elseif spec == Cylindered 		   then workTool.cp.hasSpecializationCylindered 		 = true;
		elseif spec == Fillable 		   then workTool.cp.hasSpecializationFillable 			 = true;
		elseif spec == Foldable 		   then workTool.cp.hasSpecializationFoldable 			 = true;
		elseif spec == FruitPreparer 	   then workTool.cp.hasSpecializationFruitPreparer 		 = true;
		elseif spec == FuelTrailer		   then workTool.cp.hasSpecializationFuelTrailer		 = true;
		elseif spec == MixerWagon 		   then workTool.cp.hasSpecializationMixerWagon 		 = true;
		elseif spec == Mower 			   then workTool.cp.hasSpecializationMower 				 = true;
		elseif spec == Plough 			   then workTool.cp.hasSpecializationPlough 			 = true;
		elseif spec == Shovel 			   then workTool.cp.hasSpecializationShovel 			 = true;
		elseif spec == SowingMachine 	   then workTool.cp.hasSpecializationSowingMachine 		 = true;
		elseif spec == Sprayer 			   then workTool.cp.hasSpecializationSprayer 			 = true;
		elseif spec == Steerable 		   then workTool.cp.hasSpecializationSteerable 			 = true;
		elseif spec == Tedder 			   then workTool.cp.hasSpecializationTedder 			 = true;
		elseif spec == WaterTrailer		   then workTool.cp.hasSpecializationWaterTrailer		 = true;
		elseif spec == Windrower 		   then workTool.cp.hasSpecializationWindrower 			 = true;
		end;
	end;

	if workTool.cp.hasSpecializationFillable then
		workTool.cp.closestTipDistance = math.huge;
	end;
	if workTool.typeName == 'hookLiftTrailer' then
		workTool.cp.isHookLiftTrailer = true;
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
		if workTool:allowFillType(FillUtil.FILLTYPE_LIQUIDMANURE) then
			workTool.cp.isLiquidManureOverloader = true;
		else
			workTool.cp.isAugerWagon = true;
		end
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
	-- GIANTS DEFAULT / DLC / MOD
	-- ###########################################################
	-- [1] COMBINES / CUTTERS
	-- Combines / Harvesters [Giants]
	elseif workTool.cp.xmlFileName == 'grimmeTectron415.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isGrimmeTectron415 = true;
		workTool.cp.isHarvesterSteerable = true;
		--workTool.cp.directionNodeZOffset = 2.3;

	elseif workTool.cp.xmlFileName == 'holmerTerraDosT4_40.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isHolmerTerraDosT4_40 = true;
		workTool.cp.isHarvesterSteerable = true;
		workTool.cp.isCrabSteeringPossible = true;
		workTool.cp.pipeSide = 1;
		workTool.cp.ridgeMarkerIndex = 6;
		
	elseif workTool.cp.xmlFileName == 'holmerHR9.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isHolmerHR9 = true;
		workTool.cp.isCrabSteeringPossible = true;

	elseif workTool.cp.xmlFileName ==  'holmerTerraFelis2.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isHolmerTerraFelis2 = true;
		workTool.cp.isSugarBeetLoader = true

	-- Harvesters (attachable) [Giants]
	elseif workTool.cp.xmlFileName == 'grimmeRootster604.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeRootster604 = true;
	
	elseif workTool.cp.xmlFileName == 'grimmeSE260.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeSE260 = true;
		
	elseif workTool.cp.xmlFileName == 'poettingerMex5.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isPoettingerMex5 = true;
		

	-- ###########################################################
	-- [2] TRACTORS
	-- Terra Variant 600 eco [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'holmerTerraVariant.xml' then -- Checked: Is Giants Mod Vehicle
		workTool.cp.isHolmerTerraVariant = true;
		workTool.cp.isCrabSteeringPossible = true;
		workTool.cp.ridgeMarkerIndex = 1 ;

	-- Wood harvesters [Giants]
	elseif workTool.typeName == 'woodHarvester' then -- Checked: Is Default Giants Vehicle Type
		workTool.cp.isWoodHarvester = true;
		
	-- Wood chipper [Giants]
	elseif workTool.typeName == 'woodCrusherTrailer' or workTool.typeName == 'woodCrusherTrailerDrivable' then -- Checked: Is Default Giants Vehicle Type
		workTool.cp.isWoodChipper = true;	

	-- Tree Planter [Giants]
	elseif workTool.typeName == 'treePlanter' then -- Checked: Is Default Giants Vehicle Type
		workTool.cp.isTreePlanter = true;
				
	-- Wood forwarders [Giants]
	elseif workTool.typeName == 'forwarder' then -- Checked: Is Default Giants Vehicle Type
		workTool.cp.isWoodForwarder = true;

	-- ###########################################################
	-- [3] TRAILERS
	-- Fliegl ASS 298 [Giants]
	elseif workTool.cp.xmlFileName == 'flieglASS2101.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isFlieglASS298 = true;
		workTool.cp.isPushWagon = true;

	-- Krampe Bandit 750 [Giants]
	elseif workTool.cp.xmlFileName == 'krampeBandit750.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isKrampeBandit750 = true;
		workTool.cp.isPushWagon = true;

	-- Krampe Bandit Sb 30 / 60 [Giants]
	elseif workTool.cp.xmlFileName == 'krampeSB3060.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isKrampeSB3060 = true;
		workTool.cp.isPushWagon = true;

	-- Kroeger Agroliner TAW 30 [Giants]
	elseif workTool.cp.xmlFileName == 'kroegerTAW30.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isKroegerTAW30 = true;
		workTool.cp.isPushWagon = true;

	-- Bergmann HT 50 [Giants Mod: ITRunner Pack]
	elseif workTool.cp.xmlFileName == 'containerChaff.xml' then -- Checked: Is Giants Mod Vehicle
		workTool.cp.isBergmannHT50 = true;
		workTool.cp.isPushWagon = true;


	-- ###########################################################
	-- [4] MANURE / LIQUID MANURE

	-- Zunhammer TV [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'zunhammerTV.xml' then -- Checked: Is Giants Mod Vehicle
		workTool.cp.isZunhammerTV = true;
		workTool.cp.isLiquidManureOverloader = true;
		workTool.cp.isCrabSteeringPossible = true;
		if workTool.attacherVehicle ~= nil then
			workTool.cp.isCrabSteeringPossible = true;
		end

	-- Zunhammer Vibro [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'zunhammerVibro.xml' then -- Checked: Is Giants Mod Vehicle
		workTool.cp.isZunhammerVibro = true;

	-- Bergmann TSW A 19 TV [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'bergmannTSWA19.xml' then -- Checked: Is Giants Mod Vehicle
		workTool.cp.ISBergmannTSWA19 = true
		workTool.cp.mode9TrafficIgnoreVehicle = true
		workTool.cp.isCrabSteeringPossible = true;
		if workTool.attacherVehicle ~= nil then
			workTool.attacherVehicle.cp.mode9TrafficIgnoreVehicle = true
			workTool.cp.isCrabSteeringPossible = true;
		end

	-- ###########################################################
	-- [5] BALING
	-- Ursus T127 bale loader [Giants]
	elseif workTool.cp.xmlFileName == 'ursusT127.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isUrsusT127 = true;

	-- Ursus Z586 bale wrapper [Giants]
	elseif workTool.cp.xmlFileName == 'ursusZ586.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isUrsusZ586 = true;

	-- ###########################################################
	-- [6] OTHER TOOLS
	-- Trucks [Giants]
	elseif workTool.cp.xmlFileName == 'americanTruckDualAxle.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isAmericanTruckDualAxle = true;
		workTool.cp.directionNodeZOffset = 2;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12

	elseif workTool.cp.xmlFileName == 'americanTruckOneAxle.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isAmericanTruckOneAxle = true;
		workTool.cp.directionNodeZOffset = 2;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12

	-- Wheel Loaders [Giants]
	-- JCB 435S [Giants]
	elseif workTool.cp.xmlFileName == 'jcb435s.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isJCB435S = true;
		workTool.cp.directionNodeZOffset = -0.705;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12

	-- Cultivators [Giants]
	elseif workTool.cp.xmlFileName == 'koeckerlingAllrounder.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isKoeckerlingAllrounder = true;

	-- Seeders [Giants]
	elseif workTool.cp.xmlFileName == 'vaderstadRapid600s.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isVaderstadRapid600s = true;

	elseif workTool.cp.xmlFileName == 'horschMaestro12SW.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isHorschMaestro12SW = true;

	elseif workTool.cp.xmlFileName == 'lemkenSolitair12.xml' then -- Checked: Is Default Giants Vehicle
		workTool.cp.isLemkenSolitair12 = true;

	-- Special tools [Giants]
	elseif workTool.typeName == 'strawBlower' then -- Checked: Is Default Giants Vehicle Type
		workTool.cp.isStrawBlower = true;
		workTool.cp.specialUnloadDistance = 0;

	elseif workTool.typeName == 'fuelTrailer' or workTool.cp.hasSpecializationFuelTrailer then -- Checked: Is Default Giants Vehicle Type
		workTool.cp.isFuelTrailer = true;

	elseif workTool.typeName == 'waterTrailer' or workTool.cp.hasSpecializationWaterTrailer then -- Checked: Is Default Giants Vehicle Type
		workTool.cp.isWaterTrailer = true;
	end;

	if courseplay:isSprayer(workTool) then
		if workTool:allowFillType(FillUtil.FILLTYPE_LIQUIDMANURE) then
			workTool.cp.isLiquidManureSprayer = true;
		elseif workTool:allowFillType(FillUtil.FILLTYPE_MANURE) then
			workTool.cp.isManureSprayer = true;
		end;
	end;
end;

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

	for specClassName, data in pairs(customSpecNames) do
		local fullSpecClassName = specClassName;
		if vehicle.customEnvironment then
			fullSpecClassName = ('%s.%s'):format(vehicle.customEnvironment, specClassName);
		end;

		--!!! local spec = getClassObject(fullSpecClassName);
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
	if workTool.cp.isSpecialBaleLoader or workTool.isSpecialBaleLoader then
		return true;
	end;
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

function courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker,forceSpeedLimit)
	local forcedStop = not unfold and not lower and not turnOn and not allowedToDriveacover and not unload and not ridgeMarker and forceSpeedLimit ==0;
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

		return false ,allowedToDrive,forceSpeedLimit;


	elseif workTool.cp.isCrabSteeringPossible or (workTool.attacherVehicle ~= nil and workTool.attacherVehicle.cp.isCrabSteeringPossible) then
		local tractor = workTool.attacherVehicle;
		if workTool.cp.isHolmerTerraDosT4_40 or workTool.cp.isHolmerTerraVariant then
			tractor = workTool;
		end
		if tractor.cp.hasCrabSteeringActive then
			local nextRidgeMarker = tractor.Waypoints[math.min(tractor.cp.waypointIndex+ tractor.cp.ridgeMarkerIndex ,tractor.cp.numWaypoints)].ridgeMarker
			local onField = nextRidgeMarker == ridgeMarker;
			local state = tractor.crabSteering.stateTarget;
			if implementsDown and onField then
				if ridgeMarker == 1 and state ~= 3 then
					tractor:setCrabSteering(3);
				elseif ridgeMarker ==2 and state ~= 2 then

				tractor:setCrabSteering(2);
				end
			elseif tractor.cp.isHolmerTerraDosT4_40 and state ~= 1 and not forcedStop then
				tractor:setCrabSteering(1);
			elseif tractor.cp.isHolmerTerraVariant and state ~= 0 and not forcedStop then
				tractor:setCrabSteering(0);
			end
		end
	end;

	return false, allowedToDrive,forceSpeedLimit;
end

function courseplay:askForSpecialSettings(self, object)
	-- SPECIAL VARIABLES TO USE:
	--[[
	-- automaticToolOffsetX:					(Distance in meters)	Used to automatically set the tool horizontal offset.
	-- object.cp.backMarkerOffsetCorection:		(Distance in meters)	If the implement stops to early or to late, you can specify then it needs to raise and/or turn off the work tool
	--																	Positive value, moves it forward, Negative value moves it backwards.
	-- object.cp.frontMarkerOffsetCorection:	(Distance in meters)	If the implement starts to early or to late, you can specify then it needs to lower and/or turn on the work tool
	--																	Positive value, moves it forward, Negative value moves it backwards.
	-- object.cp.widthWillCollideOnTurn			(Boolean)				If set, then the vehicle will reverse(if possible) further back, before turning to make room for the width of the tool
	-- object.cp.canBeReversed					(Boolean)				Tools that can be reversed even if the default Giants value: aiForceTurnNoBackward is set to true
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
	-- TODO: (Claus) Add description for all the special varialbes that is usable here.
	]]

	courseplay:debug(('%s: askForSpecialSettings(..., %q)'):format(nameNum(self), nameNum(object)), 6);

	local automaticToolOffsetX;

	-- OBJECTS
	if object.cp.isHorschMaestro12SW then
		object.cp.canBeReversed = true;

	elseif object.cp.isVaderstadRapid600s then
		object.cp.canBeReversed = true;

	elseif object.cp.isLemkenSolitair12 then
		object.cp.canBeReversed = true;

	elseif object.cp.isKoeckerlingAllrounder then
		object.cp.canBeReversed = true;

	elseif object.cp.isUrsusT127 then
		object.cp.specialUnloadDistance = -1.8;

	elseif object.cp.isAugerWagon then
		if object.cp.foldPipeAtWaitPoint then
			object.cp.forwardPointsFoldPipe = 0;
			if object.foldAnimTime ~= nil then
				object.cp.lastFoldAnimTime = object.foldAnimTime;
			end;
		end;
		object.cp.lastFillLevel = object.cp.fillLevel;

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

	elseif object.cp.isGrimmeSE260 then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -1.8

	elseif object.cp.isGrimmeRootster604 then
		self.cp.aiTurnNoBackward = true

	elseif object.cp.isUrsusZ586 then
		self.cp.aiTurnNoBackward = true
		self.cp.noStopOnEdge = true
		self.cp.noStopOnTurn = true
		automaticToolOffsetX = -2.5;

	elseif object.cp.isZunhammerVibro  then
		local tractor = object.attacherVehicle; 
		if tractor.cp.noStopOnEdge then
			tractor.cp.noStopOnEdge = false;
			tractor.cp.noStopOnTurn = false;
		end

	elseif self.cp.isHolmerTerraDosT4_40 then
		self.cp.noStopOnTurn = true;
		self.cp.noStopOnEdge = true;
		self.cp.backMarkerOffset = 4.5;
		self.isStrawEnabled = false;
	end;

	if self.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT then
		object.cp.lastFillLevel = object.cp.fillLevel;
	end;

	if automaticToolOffsetX ~= nil then
		self.cp.tempToolOffsetX = self.cp.toolOffsetX;
		courseplay:changeToolOffsetX(self, nil, automaticToolOffsetX, true);
	end;

	-- Debug Prints
	if self.cp.backMarkerOffset and type(self.cp.backMarkerOffset) == "number" then
		courseplay:debug(("%s backMarkerOffset set to %.1f"):format(self.name, self.cp.backMarkerOffset),6);
	end;
end

function courseplay:getSpecialWorkWidth(workTool)
	local specialWorkWidth;
	if workTool.cp then
		if workTool.cp.isGrimmeRootster604 then
			specialWorkWidth = 2.9;
		elseif workTool.cp.isGrimmeSE260 then
			specialWorkWidth = 1.6
		end
	end;

	-- Debug Prints
	if specialWorkWidth and type(self.cp.specialWorkWidth) == "number" then
		courseplay:debug(("%s workwidth: %.1fm"):format(self.name, specialWorkWidth),7);
	end;

	return specialWorkWidth;
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
		local newRot;
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