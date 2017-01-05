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
		elseif spec == Leveler 		   		then workTool.cp.hasSpecializationLeveler 			 = true;
		elseif spec == Overloading 		   then workTool.cp.hasSpecializationOverloader			 = true;	
		end;
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

	--- SPECIAL VARIABLES THAT CAN BE USED:
	--
	-- workTool.cp.steeringAngleCorrection:			(Angle in degrees)		Overwrite the default steering angle if set. NOTE: steeringAngleMultiplier will have no effect if this is set.
	-- workTool.cp.steeringAngleMultiplier:			(Number)				Used if vehicle needs to turn faster or slower.
	--																		2 	= turns 2 times slower.																	
	--																		0.5 = turns 2 times faster.
	-- workTool.cp.componentNumAsDirectionNode:		(Component Index)		Used to set another component as the Direction Node. Starts from index 1 as the first component.
	-- workTool.cp.haveInvertedToolNode:			(Boolean)				Set to true if the tool have it's rootnode pointing in the wrong direction
	-- workTool.cp.directionNodeZOffset:			(Distance in meters)	If set, then the Direction Node will be offset by the value set. (Only useable for steerables)
	-- workTool.cp.widthWillCollideOnTurn:			(Boolean)				If set, then the vehicle will reverse(if possible) further back, before turning to make room for the width of the tool
	-- workTool.cp.notToBeReversed:					(Boolean)				Tools that should not be reversed with.
	-- workTool.cp.overwriteTurnRadius:         	(Radius in meters)		Overwrite the default turn radius calculation and uses the value specified.
	--																		Note: Tractors turn radius also takes into account, so if the tractors turn radius is higher than the tool, then it will use that one instead.
	-- workTool.cp.implementWheelAlwaysOnGround:	(Boolean)				Implements that have the topReferenceNode set, but still have the wheels on the ground all the time.
	-- workTool.cp.realTurnNodeOffsetZ:				(Distance in meters)	If real turning node is not calculated corectly, we can add an manual offset z to it.
	--																		Positive value, moves it forward, Negative value moves it backwards.
	-- TODO: Add description for all the special varialbes that is usable here.
	-- ###########################################################

	-- ###########################################################
	-- MODS
	-- ###########################################################
	-- [1] MOD COMBINES

	-- ###########################################################

	-- [2] MOD TRACTORS

	elseif workTool.cp.xmlFileName ==  'KirovetsK700A.xml' then
		workTool.cp.isKirovetsK700A = true;
		--workTool.cp.steeringAngleCorrection = 10;
		--workTool.cp.directionNodeZOffset = 1.644;
		--workTool.cp.componentNumAsDirectionNode = 2;

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
	-- END OF MODS
	-- ###########################################################


	-- ###########################################################
	-- GIANTS DEFAULT / DLC / MOD
	-- ###########################################################
	-- [1] COMBINES / CUTTERS
	-- Combines / Harvesters [Giants]
	elseif workTool.cp.xmlFileName == 'grimmeTectron415.xml' then
		workTool.cp.isGrimmeTectron415 = true;
		workTool.cp.isHarvesterSteerable = true;

	elseif workTool.cp.xmlFileName == 'holmerTerraDosT4_40.xml' then
		workTool.cp.isHolmerTerraDosT4_40 = true;
		workTool.cp.isHarvesterSteerable = true;
		workTool.cp.pipeSide = 1;
		workTool.cp.ridgeMarkerIndex = 6;
		
	elseif workTool.cp.xmlFileName == 'holmerHR9.xml' then
		

	elseif workTool.cp.xmlFileName ==  'holmerTerraFelis2.xml' then
		workTool.cp.isHolmerTerraFelis2 = true;
		workTool.cp.isSugarBeetLoader = true

	-- Harvesters (attachable) [Giants]
	elseif workTool.cp.xmlFileName == 'grimmeRootster604.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeRootster604 = true;
		workTool.cp.notToBeReversed = true;
	
	elseif workTool.cp.xmlFileName == 'grimmeSE260.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeSE260 = true;
		workTool.cp.notToBeReversed = true;
		
	elseif workTool.cp.xmlFileName == 'poettingerMex5.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isPoettingerMex5 = true;
		

	-- ###########################################################
	-- [2] STEERABLE VEHICLES
	-- Terra Variant 600 eco [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'holmerTerraVariant.xml' then
		workTool.cp.isHolmerTerraVariant = true;
		workTool.cp.ridgeMarkerIndex = 1 ;

	-- New Holland SP.400F (Sprayer) [Giants]
	elseif workTool.cp.xmlFileName == 'SP400F.xml' then
		workTool.cp.isSP400F = true;
		workTool.cp.directionNodeZOffset = 2.15;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12
		workTool.cp.widthWillCollideOnTurn = true;

	-- Trucks [Giants]
	elseif workTool.cp.xmlFileName == 'americanTruckDualAxle.xml' then
		workTool.cp.directionNodeZOffset = 3.471;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12
	elseif workTool.cp.xmlFileName == 'americanTruckOneAxle.xml' then
		workTool.cp.directionNodeZOffset = 2.317;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12
	elseif workTool.cp.xmlFileName == 'tatraPhoenix.xml' then
		workTool.cp.directionNodeZOffset = 1.525;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12
	elseif workTool.cp.xmlFileName == 'manTGS18480.xml' then
		workTool.cp.directionNodeZOffset = 1.959;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12

	-- ###########################################################
	-- [3] TRAILERS


	-- ###########################################################
	-- [4] FERTILIZER EQUIPMENT
	-- Zunhammer TV [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'zunhammerTV.xml' then
		workTool.cp.isLiquidManureOverloader = true;
	
	-- Zunhammer Vibro [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'zunhammerVibro.xml' then
		workTool.cp.isZunhammerVibro = true;

	-- Bergmann TSW A 19 TV [Giants Mod: Holmer Pack]
	elseif workTool.cp.xmlFileName == 'bergmannTSWA19.xml' then
		workTool.cp.mode9TrafficIgnoreVehicle = true
		if workTool.attacherVehicle ~= nil then
			workTool.attacherVehicle.cp.mode9TrafficIgnoreVehicle = true
	end

	-- Joskin Modulo 2 [Giants]
	elseif workTool.cp.xmlFileName == 'joskinModulo.xml' then
		workTool.cp.widthWillCollideOnTurn = true;

	-- Veenhuis Premium Integral II [Giants]
	elseif workTool.cp.xmlFileName == 'premiumIntegral30000.xml' then
		workTool.cp.widthWillCollideOnTurn = true;

	-- Amazone UF 1201 [Giants]
	elseif workTool.cp.xmlFileName == 'amazoneUF1201.xml' then
		workTool.cp.widthWillCollideOnTurn = true;

	-- Caruelle Nicolas Stilla 460 [Giants]
	elseif workTool.cp.xmlFileName == 'caruelleNicolasStilla460.xml' then
		workTool.cp.widthWillCollideOnTurn = true;

	-- ###########################################################
	-- [5] BALING
	-- Ursus T127 (Bale Loader) [Giants]
	elseif workTool.cp.xmlFileName == 'ursusT127.xml' then
		workTool.cp.isUrsusT127 = true;

	-- Ursus Z586 (Bale Wrapper) [Giants]
	elseif workTool.cp.xmlFileName == 'ursusZ586.xml' then
		workTool.cp.isUrsusZ586 = true;
		workTool.cp.notToBeReversed = true;

	-- Arcusin FSX 63.72 (Bale Loader) [Giants]
	elseif workTool.cp.xmlFileName == 'arcusinFSX6372.xml' then
		workTool.cp.isArcusinFSX6372 = true;

	-- ###########################################################
	-- [6] OTHER TOOLS
	-- WHEEL LOADERS [Giants]
	-- JCB 435S [Giants]
	elseif workTool.cp.xmlFileName == 'jcb435s.xml' then
		workTool.cp.directionNodeZOffset = -0.705;
		workTool.cp.showDirectionNode = true; -- Only for debug mode 12

	-- CULTIVATORS [Giants]
	-- Horsch Tiger 10 LT [Giants]
	elseif workTool.cp.xmlFileName == 'horschTiger10LT.xml' then
		workTool.cp.realTurnNodeOffsetZ = -2.231;
		workTool.cp.overwriteTurnRadius = 6;

	-- PLOUGHS [Giants]
	-- Amazone Cayron 200 [Giants]
	elseif workTool.cp.xmlFileName == 'amazoneCayron200.xml' then
		workTool.cp.isAmazoneCayron200 = true;

	-- Kuhn Vari-Master 153 [Giants]
	elseif workTool.cp.xmlFileName == 'kuhnVariMaster153.xml' then
		workTool.cp.isKuhnVariMaster153 = true;

	-- Salford 4204 [Giants]
	elseif workTool.cp.xmlFileName == 'salford4204.xml' then
		workTool.cp.isSalford4204 = true;
		workTool.cp.overwriteTurnRadius = 3;

	-- Salford 8312 [Giants]
	elseif workTool.cp.xmlFileName == 'salford8312.xml' then
		workTool.cp.isSalford8312 = true;
		workTool.cp.notToBeReversed = true;

	-- Lemken Titan 11 [Giants]
	elseif workTool.cp.xmlFileName == 'lemkenTitan11.xml' then
		workTool.cp.isLemkenTitan11 = true;
		workTool.cp.implementWheelAlwaysOnGround = true;
		workTool.cp.notToBeReversed = true;
		workTool.cp.overwriteTurnRadius = 4.5;

	-- SEEDERS [Giants]

	end;
	-- ###########################################################
	-- END OF GIANTS DEFAULT / DLC / MOD
	-- ###########################################################

	-- ###########################################################
	-- VEHICLE TYPES
	-- Hooklift trailers [Giants]
	if workTool.typeName == 'hookLiftTrailer' then
		workTool.cp.isHookLiftTrailer = true;

	-- Wood harvesters [Giants]
	elseif workTool.typeName == 'woodHarvester' then
		workTool.cp.isWoodHarvester = true;

	-- Wood chipper [Giants]
	elseif workTool.typeName == 'woodCrusherTrailer' or workTool.typeName == 'woodCrusherTrailerDrivable' then
		workTool.cp.isWoodChipper = true;

	-- Tree Planter [Giants]
	elseif workTool.typeName == 'treePlanter' then
		workTool.cp.isTreePlanter = true;

	-- Wood forwarders [Giants]
	elseif workTool.typeName == 'forwarder' then
		workTool.cp.isWoodForwarder = true;

	-- Straw blowers [Giants]
	elseif workTool.typeName == 'strawBlower' then
		workTool.cp.isStrawBlower = true;
		workTool.cp.specialUnloadDistance = 0;

	-- Fuel trailers [Giants]
	elseif workTool.typeName == 'fuelTrailer' or workTool.cp.hasSpecializationFuelTrailer then
		workTool.cp.isFuelTrailer = true;

	-- Water trailers [Giants]
	elseif workTool.typeName == 'waterTrailer' or workTool.cp.hasSpecializationWaterTrailer then
		workTool.cp.isWaterTrailer = true;
	end;

	-- ###########################################################
	-- SPRAYER SETUP
	-- ###########################################################
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
	local forcedStop = not unfold and not lower and not turnOn and not allowedToDrive and not cover and not unload and not ridgeMarker and forceSpeedLimit ==0;
	local implementsDown = lower and turnOn
	if workTool.PTOId then
		workTool:setPTO(false)
	end;

	if workTool.cp.isSP400F then
		if self.isHired then
			if unfold then
				--- Move the wheel base outwards while working.
				if not workTool:getIsAnimationPlaying("moveWheelBase") and workTool:getAnimationTime("moveWheelBase") < 1 then
					workTool:playAnimation("moveWheelBase", 0.4, workTool:getAnimationTime("moveWheelBase"));
				elseif workTool:getIsAnimationPlaying("moveWheelBase") and workTool.animations["moveWheelBase"].currentSpeed < 0 then
					workTool:setAnimationSpeed("moveWheelBase", 0.4);
				end;
			elseif self.isHired then
				--- Move the wheel base inwards when not working.
				if not workTool:getIsAnimationPlaying("moveWheelBase") and workTool:getAnimationTime("moveWheelBase") > 0 then
					workTool:playAnimation("moveWheelBase", -0.4, workTool:getAnimationTime("moveWheelBase"));
				elseif workTool:getIsAnimationPlaying("moveWheelBase") and workTool.animations["moveWheelBase"].currentSpeed > 0 then
					workTool:setAnimationSpeed("moveWheelBase", -0.4);
				end;
			end;
		end;
		return false ,allowedToDrive,forceSpeedLimit;
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
	end;

	return false, allowedToDrive,forceSpeedLimit;
end

function courseplay:askForSpecialSettings(self, object)
	--- SPECIAL VARIABLES THAT CAN BE USED:
	--
	-- automaticToolOffsetX:					(Distance in meters)	Used to automatically set the tool horizontal offset. Negagive value = left, Positive value = right.
	-- object.cp.backMarkerOffsetCorection:		(Distance in meters)	If the implement stops to early or to late, you can specify then it needs to raise and/or turn off the work tool
	--																	Positive value, moves it forward, Negative value moves it backwards.
	-- object.cp.frontMarkerOffsetCorection:	(Distance in meters)	If the implement starts to early or to late, you can specify then it needs to lower and/or turn on the work tool
	--																	Positive value, moves it forward, Negative value moves it backwards.
	-- object.cp.haveInversedRidgeMarkerState:	(Boolean)				If the ridmarker is using the wrong side in auto mode, set this value to true
	-- object.cp.realUnfoldDirectionIsReversed:	(Boolean)				If the tool unfolds when driving roads and folds when working fields, then set this one to true to reverse the folding order.
	-- object.cp.specialUnloadDistance:			(Distance in meters)	Able to set the distance to the waiting point when it needs to unload. Used by bale loaders. Distance from trailer's turning point to the rear unloading point.
	-- self.cp.noStopOnEdge:                    (Boolean)               Set this to true if it dont need to stop the work tool while turning.
	--																	Some work tool types automatically set this to true.
	-- self.cp.noStopOnTurn:					(Boolean)				Set this to true if the work tool don't need to stop for 1½ sec before turning.
	--																	Some work tool types automatically set this to true.
	-- self.cp.backMarkerOffset:				(Distance in meters)	If the implement stops to early or to late, you can specify then it needs to raise/lower or turn on/off the work tool
	-- TODO: Add description for all the special varialbes that is usable here.

	courseplay:debug(('%s: askForSpecialSettings(..., %q)'):format(nameNum(self), nameNum(object)), 6);

	local automaticToolOffsetX;

	-- OBJECTS
	if object.cp.isSP400F then
		object.cp.backMarkerOffsetCorection = 0.5;
		object.cp.frontMarkerOffsetCorection = -0.25;

	elseif object.cp.isUrsusT127 then
		object.cp.specialUnloadDistance = -1.8;
		automaticToolOffsetX = -2.4; -- ToolOffsetX is 0.2 meters to the left

	elseif object.cp.isArcusinFSX6372 then
		object.cp.specialUnloadDistance = -3.8;
		automaticToolOffsetX = -2.4; -- ToolOffsetX is 0.2 meters to the left

	elseif object.cp.isAmazoneCayron200 then
		automaticToolOffsetX = 0.8; -- ToolOffsetX is 0.8 meters to the right

	elseif object.cp.isKuhnVariMaster153 then
		automaticToolOffsetX = 0.1; -- ToolOffsetX is 0.1 meters to the right

	elseif object.cp.isSalford4204 then
		automaticToolOffsetX = -0.2; -- ToolOffsetX is 0.2 meters to the left

	elseif object.cp.isSalford8312 then
		automaticToolOffsetX = 0.5; -- ToolOffsetX is 0.5 meters to the right

	elseif object.cp.isLemkenTitan11 then
		automaticToolOffsetX = 0.8; -- ToolOffsetX is 0.8 meters to the right

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
		automaticToolOffsetX = -1.8

	elseif object.cp.isUrsusZ586 then
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

	if automaticToolOffsetX ~= nil and self.cp.tempToolOffsetX == nil then
		self.cp.tempToolOffsetX = self.cp.toolOffsetX;
		courseplay:changeToolOffsetX(self, nil, automaticToolOffsetX, true);
	end;

	-- Debug Prints
	if self.cp.backMarkerOffset and type(self.cp.backMarkerOffset) == "number" then
		courseplay:debug(("%s backMarkerOffset set to %.1fm"):format(self.name, self.cp.backMarkerOffset),6);
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
	if specialWorkWidth and type(workTool.cp.specialWorkWidth) == "number" then
		courseplay:debug(("%s workwidth: %.1fm"):format(workTool.name, specialWorkWidth),7);
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