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

	-- TODO: is this even needed? Why not use the workTool.spec_* directly? Do we really need our own table?
	-- Only default specs!
	for i,spec in pairs(workTool.specializations) do
		if     spec == AnimatedVehicle 	   then workTool.cp.hasSpecializationAnimatedVehicle 	 = true;
		elseif spec == BaleLoader 		   then workTool.cp.hasSpecializationBaleLoader 		 = true;
		elseif spec == Pickup	 		   then workTool.cp.hasSpecializationPickup		 		 = true;
		elseif spec == Baler 			   then workTool.cp.hasSpecializationBaler 				 = true;
		elseif spec == Combine 			   then workTool.cp.hasSpecializationCombine 			 = true;
		elseif spec == Cover 			   then workTool.cp.hasSpecializationCover				 = true;
		elseif spec == Crawler 			   then workTool.cp.hasSpecializationCrawler			 = true;
		elseif spec == Cultivator 		   then workTool.cp.hasSpecializationCultivator 		 = true;
		elseif spec == Cutter 			   then workTool.cp.hasSpecializationCutter 			 = true;
		elseif spec == Cylindered 		   then workTool.cp.hasSpecializationCylindered 		 = true;
		elseif spec == Drivable 		   then workTool.cp.hasSpecializationDrivable 			 = true;
		elseif spec == FillUnit 		   then workTool.cp.hasSpecializationFillUnit 			 = true;
		elseif spec == FillVolume 		   then workTool.cp.hasSpecializationFillVolume			 = true;
		elseif spec == Foldable 		   then workTool.cp.hasSpecializationFoldable 			 = true;
		elseif spec == FruitPreparer 	   then workTool.cp.hasSpecializationFruitPreparer 		 = true;
		elseif spec == FuelTrailer		   then workTool.cp.hasSpecializationFuelTrailer		 = true;
		elseif spec == MixerWagon 		   then workTool.cp.hasSpecializationMixerWagon 		 = true;
		elseif spec == Mower 			   then workTool.cp.hasSpecializationMower 				 = true;
		elseif spec == Plow 			   then workTool.cp.hasSpecializationPlow 			 = true;
		elseif spec == ReverseDriving	   then workTool.cp.hasSpecializationReverseDriving		 = true;
		elseif spec == Shovel 			   then workTool.cp.hasSpecializationShovel 			 = true;
		elseif spec == SowingMachine 	   then workTool.cp.hasSpecializationSowingMachine 		 = true;
		elseif spec == Sprayer 			   then workTool.cp.hasSpecializationSprayer 			 = true;
		elseif spec == Tedder 			   then workTool.cp.hasSpecializationTedder 			 = true;
		elseif spec == WaterTrailer		   then workTool.cp.hasSpecializationWaterTrailer		 = true;
		elseif spec == Weeder 		   	   then workTool.cp.hasSpecializationWeeder 			 = true;
		elseif spec == Windrower 		   then workTool.cp.hasSpecializationWindrower 			 = true;
		elseif spec == Leveler 		   	   then workTool.cp.hasSpecializationLeveler 			 = true;
		elseif spec == Overloading 		   then workTool.cp.hasSpecializationOverloader			 = true;
		elseif spec == Trailer	 		   then workTool.cp.hasSpecializationTrailer			 = true;
		elseif spec == BunkerSiloCompacter then workTool.cp.hasSpecializationBunkerSiloCompacter = true;		
		end;
	end;

    if workTool.cp.hasSpecializationFillUnit and workTool.cp.hasSpecializationFillVolume then
		workTool.cp.hasSpecializationFillable = true;
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
	if workTool.typeName == 'augerWagon' or string.match( workTool.typeName, "FS17_kotteUniversalPack.kotteUniversal") then
		if workTool:getFillUnitAllowsFillType(1,g_fillTypeManager.nameToIndex.LIQUIDMANURE) then
			workTool.cp.isLiquidManureOverloader = true;
		else
			workTool.cp.isAugerWagon = true;
		end
		if workTool.cp.xmlFileName == 'horschTitan34UW.xml' then
			workTool.cp.isHorschTitan34UW = true;
		end;
	elseif workTool.cp.hasSpecializationOverloader and not workTool.cp.hasSpecializationCutter then
		workTool.cp.isAugerWagon = true;
		workTool.cp.hasSpecializationOverloaderV2 = workTool.overloaderVersion ~= nil and workTool.overloaderVersion >= 2;
	elseif workTool.animationParts ~= nil and workTool.animationParts[2] ~= nil and workTool.toggleUnloadingState ~= nil and workTool.setUnloadingState ~= nil then
		workTool.cp.isAugerWagon = true;
		workTool.cp.isTaarupShuttle = true;
	end;

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
	-- workTool.cp.useCrabSteeringMode:				(Crab Steering Index)	Used to overwrite the default crab steering mode when cp is driving
	-- workTool.cp.haveInvertedToolNode:			(Boolean)				Set to true if the tool have it's rootnode pointing in the wrong direction
	-- workTool.cp.directionNodeZOffset:			(Distance in meters)	If set, then the Direction Node will be offset by the value set. (Only useable for enterables)
	-- workTool.cp.widthWillCollideOnTurn:			(Boolean)				If set, then the vehicle will reverse(if possible) further back, before turning to make room for the width of the tool
	-- workTool.cp.notToBeReversed:					(Boolean)				Tools that should not be reversed with.
	-- workTool.cp.overwriteTurnRadius:         	(Radius in meters)		Overwrite the default turn radius calculation and uses the value specified.
	--																		Note: Tractors turn radius also takes into account, so if the tractors turn radius is higher than the tool, then it will use that one instead.
	-- workTool.cp.implementWheelAlwaysOnGround:	(Boolean)				Implements that have the topReferenceNode set, but still have the wheels on the ground all the time.
	-- workTool.cp.realTurnNodeOffsetZ:				(Distance in meters)	If real turning node is not calculated corectly, we can add an manual offset z to it.
	--																		Positive value, moves it forward, Negative value moves it backwards.
	-- workTool.cp.isTraileredChopper				(Boolean)				Allows Foragehavesters that are towed to be propely recoginzed by CP
	-- workTool.cp.baleRowWidth						(Distance in meters)	Sets the width of the droped bales to allow for next row placement
	-- TODO: Add description for all the special varialbes that is usable here.
	-- ###########################################################

	-- ###########################################################
	-- MODS
	-- ###########################################################
	-- [1] MOD COMBINES

	-- ###########################################################

	-- [2] MOD TRACTORS

	-- ##########################################################

	-- [3] MOD TRAILERS
	

	-- ###########################################################

	-- [4] MOD MANURE / LIQUID MANURE

	-- ###########################################################

	-- [5] MOD MOWERS


	-- ###########################################################

	-- [6] MOD BALING
	if workTool.cp.xmlFileName == 'KroneUltimaCF155XC.xml' then
		workTool.cp.isKroneUltimaCF155XC = true
		if not workTool.cp.ultimaSpec then
			for index,name in pairs (workTool.specializationNames) do
				if name == "FS17_KroneUltimaCF155XC.Ultima" then
					workTool.cp.ultimaSpec = workTool.specializations[index]
					break
				end
			end
		end
	
	elseif workTool.cp.xmlFileName == 'kuhnFBP3135.xml' then
		workTool.cp.iskuhnFBP3135 = true
		
	-- ###########################################################

	-- [7] MOD OTHER TOOLS
	elseif workTool.cp.xmlFileName == 'kuhnTF1500.xml' then
		workTool.cp.isKuhnTF1500 = true;
		workTool.cp.specialWorkWidth = 0;
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

	elseif workTool.cp.xmlFileName == 'terraDosT4_40.xml' then
		workTool.cp.isHolmerTerraDosT4_40 = true;
		workTool.cp.use = 1;
		workTool.cp.isHarvesterSteerable = true;
	elseif workTool.cp.xmlFileName == 'tiger6.xml' then
		workTool.cp.isRopaTiger6 = true;
		workTool.cp.isHarvesterSteerable = true;
		workTool.cp.useCrabSteeringMode = 1;
		
		
	elseif workTool.cp.xmlFileName == 'holmerHR9.xml' then
		workTool.cp.isHolmerHR9 = true;

	elseif workTool.cp.xmlFileName ==  'terraFelis2.xml' then
		workTool.cp.isHolmerTerraFelis2 = true;
		workTool.cp.isSugarBeetLoader = true

	elseif workTool.cp.xmlFileName ==  'maus5.xml' then
		workTool.cp.isRopaMaus5 = true;
		workTool.cp.isSugarBeetLoader = true

	elseif workTool.cp.xmlFileName ==  'ropaNawaRoMaus.xml' then
		workTool.cp.isRopaNawaRoMaus = true;
		workTool.cp.isSugarBeetLoader = true
		
	elseif workTool.cp.xmlFileName ==  'CaseIHA8800MR.xml' then
		workTool.cp.isCaseIHA8800MR = true;
		workTool.cp.isHarvesterSteerable = true;
		
	-- Harvesters (attachable) [Giants]
	elseif workTool.cp.xmlFileName == 'rootster604.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeRootster604 = true;
		workTool.cp.specialWorkWidth = 2.9
	
	elseif workTool.cp.xmlFileName == 'keiler2.xml' then
		workTool.cp.isRopaKeiler2 = true;
		workTool.cp.isHarvesterAttachable = true;

	elseif workTool.cp.xmlFileName == 'SE260.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeSE260 = true;
		workTool.cp.specialWorkWidth = 1.6
		
	elseif workTool.cp.xmlFileName == 'mex5.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isPoettingerMex5 = true;
		workTool.cp.fixedChopperOffset = 5.5
	
	-- SWT7 [Giants DLC]
	elseif workTool.cp.xmlFileName == 'SWT7.xml' then
		workTool.cp.isTraileredChopper = true;
		workTool.cp.overwriteTurnRadius = 9;
		workTool.cp.isSWT7 = true;
		

	-- ###########################################################
	-- [2] STEERABLE VEHICLES
	-- Valtra T Series [Giants]
	elseif workTool.cp.xmlFileName == 'valtraTSeries.xml' then
		workTool.cp.overwriteTurnRadius = 4.5;

	-- New Holland SP.400F (Sprayer) [Giants]
	elseif workTool.cp.xmlFileName == 'SP400F.xml' then
		workTool.cp.isSP400F = true;
		workTool.cp.directionNodeZOffset = 2.15;
		workTool.cp.widthWillCollideOnTurn = true;

	--Big Bud 747 [Giants Big Bud DLC]
	elseif workTool.cp.xmlFileName == 'bigBud747.xml' then
		workTool.cp.overwriteTurnRadius = 9;

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

	-- Einboeck Aerostar-Rotation 1200 [Giants]
	elseif workTool.cp.xmlFileName == 'einboeckRotation1200.xml' then
		workTool.cp.widthWillCollideOnTurn = true;

	-- ###########################################################
	-- [5] BALING
	-- Ursus T127 (Bale Loader) [Giants]
	elseif workTool.cp.xmlFileName == 'ursusT127.xml' then
		workTool.cp.isUrsusT127 = true;
		workTool.cp.baleRowWidth = 1.5

	-- Kuhn SW4014 (Bale Wrapper) [Giants Kuhn DLC]
	elseif workTool.cp.xmlFileName == 'kuhnSW4014.xml' then
		workTool.cp.isKuhnSW4014 = true;

	-- Arcusin FSX 63.72 (Bale Loader) [Giants]
	elseif workTool.cp.xmlFileName == 'arcusinFSX6372.xml' then
		workTool.cp.isArcusinFSX6372 = true;
		workTool.cp.baleRowWidth = 3
		
	--Krone Premos5000 [strawHarvestAddon]
	elseif 	workTool.cp.xmlFileName == 'premos5000.xml' then
		workTool.cp.isKronePremos5000 = true;	
		workTool.cp.isAttachedCombine = true;

	elseif 	workTool.cp.xmlFileName == 'comprimaV180XC.xml' then
		workTool.cp.isKroneComprimaV180XC = true;
		workTool.cp.isStrawHarvestAddonBaler = true;
	
	elseif 	workTool.cp.xmlFileName == 'bigPack1290HDPII.xml' then
		workTool.cp.isKroneBigPack1290HDPII = true;
		workTool.cp.isStrawHarvestAddonBaler = true;	
		
	-- ###########################################################
	-- [6] OTHER TOOLS
	-- WHEEL LOADERS [Giants]
	-- JCB 435S [Giants]
	elseif workTool.cp.xmlFileName == 'jcb435s.xml' then
		workTool.cp.directionNodeZOffset = -0.705;

	-- CULTIVATORS [Giants]
	-- Horsch Tiger 10 LT [Giants]
	elseif workTool.cp.xmlFileName == 'horschTiger10LT.xml' then
		workTool.cp.realTurnNodeOffsetZ = -2.231;
		workTool.cp.overwriteTurnRadius = 6;

	-- Kuhn HR4004 [Giants Kuhn DLC]
	elseif workTool.cp.xmlFileName == 'kuhnHR4004.xml' then
		workTool.cp.isKuhnHR4004 = true;

	-- Kuhn DC401 [Giants Kuhn DLC]
	elseif workTool.cp.xmlFileName == 'kuhnDC401.xml' then
		workTool.cp.isKuhnDC401 = true;

	-- Flexi Coil ST 820 [Giants Big Bud DLC]
	elseif workTool.cp.xmlFileName == 'flexicoilST820.xml' then
		workTool.cp.isFlexicoilST820 = true;
		workTool.cp.overwriteTurnRadius = 7;

	--Cultiplow Platinum 8m [Giants Big Bud DLC]
	elseif workTool.cp.xmlFileName == 'agrisemCultiplowPlatinum8m.xml' then
		workTool.cp.isAgrisemCultiplowPlatinum8m = true;
		workTool.cp.overwriteTurnRadius = 7;
		
	--Bednar SM 180000 [Giants Big Bud DLC]
	elseif workTool.cp.xmlFileName == 'BednarSM18000.xml' then
		workTool.cp.isBednarSM18000 = true

	-- PLOWS [Giants]
		-- Agromasz POH 5 [Giants]
	elseif workTool.cp.xmlFileName == 'agromaszPOH5.xml' then
		workTool.cp.isAgromaszPOH5 = true;

	-- Salford 4204 [Giants]
	elseif workTool.cp.xmlFileName == 'salford4204.xml' then
		workTool.cp.isSalford4204 = true;
		workTool.cp.overwriteTurnRadius = 3;

	-- Salford 8312 [Giants]
	elseif workTool.cp.xmlFileName == 'salford8312.xml' then
		workTool.cp.isSalford8312 = true;
		workTool.cp.notToBeReversed = true;
		workTool.cp.overwriteTurnRadius = 9;

	-- Lemken Titan 18 [Giants]
	elseif workTool.cp.xmlFileName == 'titan11.xml' then
		workTool.cp.isLemkenTitan18 = true;
		workTool.cp.implementWheelAlwaysOnGround = true;
		workTool.cp.overwriteTurnRadius = 4.5;

	-- Gregoire Besson SPSL 9 [Giants]
	elseif workTool.cp.xmlFileName == 'SPSL9.xml' then
		workTool.cp.isGregoireBessonSPSL9 = true;
		workTool.cp.implementWheelAlwaysOnGround = true;
		workTool.cp.overwriteTurnRadius = 10;
		workTool.cp.specialWorkWidth = 10.5

	-- Kuhn Discolander XM52 [Giants Kuhn DLC]
	elseif workTool.cp.xmlFileName == 'kuhnDiscolanderXM.xml' then
		workTool.cp.isKuhnDiscolanderXM52 = true;

	-- SEEDERS [Giants]

	--Seed Kawk 980 Air Cart [Giants Big Bud DLC]
	elseif workTool.cp.xmlFileName == 'seedHawk980AirCart.xml' then
		workTool.cp.isSeedHawk980AirCart = true;

	--Hatzenbichler TH1400 [Giants Big Bud DLC]
	elseif workTool.cp.xmlFileName == 'th1400.xml' then
		workTool.cp.isHatzenbichlerTH1400 = true;

	--Htzenbichler Terminator 18 [Giants Big Bud DLC]
	elseif workTool.cp.xmlFileName == 'terminator18.xml' then
		workTool.cp.isHatzenbichlerTerminator18 = true;

	--Seed Hawk XL Toolbar 84ft [Giants Big Bud DLC] new .xml xlAirDrill84.xml
	elseif	 workTool.cp.xmlFileName == 'seedHawkXLAirDrill84.xml' then
		workTool.cp.isSeedHawkXLAirDrill84 = true;
		workTool.cp.overwriteTurnRadius = 10;

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
		if workTool:getFillUnitAllowsFillType(1,g_fillTypeManager.nameToIndex.LIQUIDMANURE) then
			workTool.cp.isLiquidManureSprayer = true;
		elseif workTool:getFillUnitAllowsFillType(1,g_fillTypeManager.nameToIndex.MANURE) then    
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

	for i, spec in ipairs(g_vehicleTypeManager.vehicleTypes[vehicle.typeName].specializations) do
		if specToSpecClassName[spec] ~= nil then
			local varName = specToSpecClassName[spec]:gsub('^%l', string.upper):gsub('_', ''); -- first char uppercase, remove underscores
			vehicle.cp['hasSpecialization' .. varName] = true;
		end;
	end;
end;


------------------------------------------------------------------------------------------

function courseplay:isSpecialBaler(workTool)
	if workTool.cp.isKroneUltimaCF155XC then
		return true;
	end
	return false;
end;

function courseplay:isSpecialCombine(workTool, specialType, fileNames)
	if specialType ~= nil then
		if specialType == "sugarBeetLoader" then
		end;
	end;

	if workTool.cp.isKronePremos5000 then
		return true;
	end
	return false;
end

-- TODO: this screams for refactoring. Those self.cp.is<some special tool> are completely wrong. We should set the
-- attributes (like offset, noStopOnEdge etc,) which needs to be set for that specific tool and that's it, no need for this
-- tool specific variable. (Or better yet, the whole special tool config should be read from an XML file)
function courseplay:askForSpecialSettings(self, object)
	--- SPECIAL VARIABLES THAT CAN BE USED:
	--
	-- object.cp.specialUnloadDistance:			(Distance in meters)	Able to set the distance to the waiting point when it needs to unload. Used by bale loaders. Distance from trailer's turning point to the rear unloading point.

	courseplay:debug(('%s: askForSpecialSettings(..., %q)'):format(nameNum(self), nameNum(object)), 6);

	if object.cp.isUrsusT127 then
		object.cp.specialUnloadDistance = -1.8;

	elseif object.cp.isArcusinFSX6372 then
		object.cp.specialUnloadDistance = -3.8;

	elseif object.cp.isAugerWagon then
		object.cp.lastFillLevel = object.cp.fillLevel;

	end;

end

function courseplay:getSpecialWorkWidth(workTool)
	local specialWorkWidth;
	if workTool.cp then
		specialWorkWidth = workTool.cp.specialWorkWidth;
	end;

	-- Debug Prints
	if specialWorkWidth and type(workTool.cp.specialWorkWidth) == "number" then
		courseplay:debug(("%s workwidth: %.1fm"):format(workTool.name, specialWorkWidth),7);
	end;

	return specialWorkWidth;
end;

