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

	-- [1] MOD COMBINES
	-- John Deere S690i [Big Boss Modding]
	if workTool.cp.xmlFileName == 'JohnDeereS690i.xml' or workTool.cp.xmlFileName == 'JohnDeereS690i_TT.xml' then
		workTool.cp.isJohnDeereS690iBBM = true;

	-- John Deere S680 [Big Boss Modding]
	elseif workTool.cp.xmlFileName == 'JohnDeereS680dw.xml' or workTool.cp.xmlFileName == 'JohnDeereS680tt.xml' then
		workTool.cp.isJohnDeereS680BBM = true;

	-- John Deere S670 [Big Boss Modding]
	elseif workTool.cp.xmlFileName == 'JohnDeereS670bw.xml' then
		workTool.cp.isJohnDeereS670BBM = true;

	-- John Deere S650 [Big Boss Modding]
	elseif workTool.cp.xmlFileName == 'JohnDeereS650NW.xml' then
		workTool.cp.isJohnDeereS650BBM = true;

	-- Ropa EuroTiger [Burner]
	elseif workTool.cp.xmlFileName == 'RopaEuroTiger_V8_3_XL.xml' then
		workTool.cp.isRopaEuroTiger = true;

	-- JF-Stoll 1060 [NI Modding]
	elseif workTool.cp.xmlFileName == 'JF_1060.xml' then
		workTool.cp.isJF1060 = true;

	-- Poettinger Mex OK [Vertex Dezign]
	elseif workTool.cp.xmlFileName == 'poettingerMexOK.xml' then
		workTool.cp.isPoettingerMexOK = true;

	-- Claas Conspeed cutter [SFM]
	elseif workTool.cp.xmlFileName == 'claasConspeed.xml' then
		workTool.cp.isClaasConspeedSFM = true;

	-- ###########################################################

	-- [2] MOD TRACTORS
	--Fendt 828 Vario [surrealcrash, fruktor]
	elseif Utils.endsWith(workTool.typeName, 'Vario') and (workTool.cp.xmlFileName == '828Vario.xml' or workTool.cp.xmlFileName == '828VarioEX.xml') then
		workTool.cp.isFendt828VarioFruktor = true;

	-- Kirovets K700A [SFM]
	elseif workTool.cp.xmlFileName == 'KirovetsK700A.xml' then
		workTool.cp.isKirovetsK700A = true;

	-- ###########################################################

	-- [3] MOD TRAILERS
	-- Claas Quantum 3800K [Vertex Design]
	elseif workTool.psGrassactive ~= nil and workTool.psStrawactive ~= nil and workTool.cp.xmlFileName == 'claas_quantum_3800k.xml' then
		workTool.cp.isClaasQuantum3800K = true;
		workTool.cp.isPushWagon = true;

	-- AugerWagons
	elseif workTool.cp.hasSpecializationAugerWagon then
		workTool.cp.isAugerWagon = true;
		if workTool.cp.xmlFileName == 'horschTitan34UW.xml' then
			workTool.cp.isHorschTitan34UWTitaniumAddon = true;
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

	-- [4] MOD MANURE / LIQUID MANURE
	-- HoseRef liquid manure trailers [Eifok Team] (CP implementation v2)
	elseif workTool.cp.hasSpecializationHoseRef then
		workTool.cp.hasHoseRef = true;
		workTool.cp.isHoseRefTransporter = workTool.hasPump;
		workTool.cp.isHoseRefSprayer = workTool.hasPump and workTool.cp.hasSpecializationSprayer and workTool.allowsSpraying;
		workTool.cp.hasEifokZunhammerAttachable = false;

	-- Eifok liquid manure attachable pack [Eifok Team]
	elseif workTool.moescha ~= nil and workTool.cp.xmlFileName == 'moescha.xml' then
		workTool.cp.isEifokZunhammerMoescha = true;
		workTool.cp.isEifokZunhammerAttachable = true;
		workTool.cp.isNonTippersHandledWorkTool = true;
	elseif workTool.cp.xmlFileName == 'vogelsang.xml' then
		workTool.cp.isEifokZunhammerVogelsang = true;
		workTool.cp.isEifokZunhammerAttachable = true;
		workTool.cp.isNonTippersHandledWorkTool = true;
	elseif workTool.vibro ~= nil and workTool.cp.xmlFileName == 'zunhammerVibro.xml' then
		workTool.cp.isEifokZunhammerVibro = true;
		workTool.cp.isEifokZunhammerAttachable = true;
		workTool.cp.isNonTippersHandledWorkTool = true;

	-- Guellepack v2 [Bayerbua]
	elseif workTool.fillerArmInRange ~= nil  then
		workTool.cp.isFeldbinder = true
	elseif workTool.cp.xmlFileName == 'KotteGARANTProfiVQ32000.xml' and workTool.fillerArmNode ~= nil then
		workTool.cp.isKotteGARANTProfiVQ32000 = true

	-- Abbey Sprayer Pack [FS-UK Modteam]
	elseif workTool.cp.xmlFileName == 'Abbey_AP900.xml' then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbeyAP900 = true;
	elseif workTool.cp.xmlFileName == 'Abbey_3000R.xml' then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbey3000R = true;
	elseif workTool.cp.xmlFileName == 'Abbey_2000R.xml' then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbey2000R = true;
	elseif workTool.cp.xmlFileName == 'Abbey_3000_Nurse.xml' then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbey3000Nurse = true;

	--Tebbe HS180 [Stefan Maurus]
	elseif workTool.cp.xmlFileName == 'TebbeHS180.xml' or workTool.cp.hasSpecializationTebbeHS180 then
		workTool.cp.isTebbeHS180 = true;

	--Fuchs liquid manure trailer [Stefan Maurus]
	elseif workTool.cp.xmlFileName == 'FuchsGuellefass.xml' and workTool.isFuchsFass then
		workTool.cp.isFuchsLiquidManure = true;

	-- ###########################################################

	-- [5] MOD MOWERS
	-- Poettinger Eurocat 315H [MoreRealistic]
	elseif workTool.typeName == 'moreRealistic.mower_animated' and workTool.cp.xmlFileName == 'poettingerEurocat315H.xml' then
		workTool.cp.isMRpoettingerEurocat315H = true;

	-- Kverneland Mower Pack [NI Modding]
	elseif workTool.cp.xmlFileName == 'Kverneland_4028.xml' then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKverneland4028 = true;
	elseif workTool.cp.xmlFileName == 'Kverneland_4028_AS.xml' then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKverneland4028AS = true;
	elseif workTool.cp.xmlFileName == 'Kverneland_KD240.xml' then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKvernelandKD240 = true;
	elseif workTool.cp.xmlFileName == 'Kverneland_KD240F.xml' then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKvernelandKD240F = true;
	elseif workTool.cp.xmlFileName == 'Taarup_3532F.xml' then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKverneland3532F = true;

	-- Taarup Mower Pack [NI Modding]
	elseif workTool.cp.xmlFileName == 'Taarup_5090.xml' then
		workTool.cp.isTaarupMowerPack = true;
		workTool.cp.isTaarup5090 = true;

	-- Poettinger Alpha/X8 Mower Pack [Eifok Team]
	elseif workTool.cp.xmlFileName == 'PoettingerAlpha.xml' then
		workTool.cp.isPoettingerAlphaX8MowerPack = true;
		workTool.cp.isPoettingerAlpha = true;
	elseif workTool.cp.xmlFileName == 'PoettingerX8.xml' then
		workTool.cp.isPoettingerAlphaX8MowerPack = true;
		workTool.cp.isPoettingerX8 = true;

		-- ###########################################################

	-- [6] MOD BALING
	-- John Deere 864 Premium [BJR]
	elseif workTool.cp.xmlFileName == 'JohnDeere864Premium.xml' then
		workTool.cp.isJohnDeere864Premium = true;

	-- McHale998 bale wrapper [Bergwout]
	elseif workTool.cp.xmlFileName == 'Mchale998.xml' then
		workTool.cp.isMchale998 = true

	-- Universal Bale Trailer (UBT)
	elseif workTool.numAttacherParts ~= nil and workTool.autoLoad ~= nil and workTool.loadingIsActive ~= nil and workTool.unloadLeft ~= nil and workTool.unloadRight ~= nil and workTool.unloadBack ~= nil and workTool.typeOnTrailer ~= nil and workTool.fillLevelMax ~= nil then
		workTool.cp.isUBT = true;
		workTool.cp.isBrantnerDPW18000 = workTool.cp.xmlFileName == 'dpw18000.xml';
		workTool.cp.isMoellerUbtBaleLoader = workTool.cp.xmlFileName == 'AA47ballen.xml';

	-- Claas Quadrant 1200 [Eifok Team]
	elseif workTool.cp.xmlFileName == 'Claas_Quadrant_1200.xml' then
		workTool.cp.isClaasQuadrant1200 = true;

	-- ###########################################################

	-- [7] MOD OTHER TOOLS
	-- Rolmasz S061 'Pomorzanin' [Maciusboss1 & Burner]
	elseif workTool.cp.xmlFileName == 'S061.xml' and workTool.setTramlinesOn ~= nil and workTool.leftMarkerRope ~= nil and workTool.leftMarkerSpeedRotatingParts ~= nil then
		workTool.cp.isRolmaszS061 = true;

	-- Krone Swadro 900 [NI-Modding]
	elseif workTool.rowerFoldingParts and workTool.cp.xmlFileName == 'KroneSwadro900.xml' then
		workTool.cp.isKroneSwadro900 = true;

	-- Claas Liner 4000 [LS-Landtechnik & Fuqsbow-Team]
	elseif workTool.cp.xmlFileName == 'liner4000.xml' then
		workTool.cp.isClaasLiner4000 = true;

	-- Urf-Specialisation
	elseif workTool.sprayFillLevel ~= nil and workTool.sprayCapacity ~= nil then
		workTool.cp.hasUrfSpec = true

	-- Silage shields
	elseif workTool.cp.xmlFileName == 'holaras.xml' then
		workTool.cp.isSilageShield = true
	elseif workTool.cp.xmlFileName == 'Stegemann.xml' then
		workTool.cp.isSilageShield = true

	--Sugarbeet Loaders [burner]
	elseif workTool.cp.xmlFileName == 'RopaEuroMaus.xml' then
		workTool.cp.isRopaEuroMaus = true;
	elseif workTool.cp.xmlFileName == 'HolmerTerraFelis.xml' then
		workTool.cp.isHolmerTerraFelis = true;
	elseif workTool.cp.xmlFileName == 'RopaNawaRoMaus.xml' then
		workTool.cp.isRopaNawaRoMaus = true;


	-- ###########################################################
	-- ###########################################################
	-- ###########################################################


	-- GIANTS DEFAULT / DLC
	-- [1] COMBINES
	-- Combines [Giants]
	elseif workTool.cp.xmlFileName == 'fahrM66.xml' or workTool.cp.xmlFileName == 'fahrM66EX.xml' then
		workTool.cp.isFahrM66 = true;
		if not courseplay.trafficCollisionIgnoreList[workTool.components[2].node] then
			courseplay.trafficCollisionIgnoreList[workTool.components[2].node] = true; -- adding the Fahr M66 pipeCol to the ignore list if not set
		end;
	elseif workTool.cp.xmlFileName == 'caseIH7130.xml' then
		workTool.cp.isCaseIH7130 = true;
	elseif workTool.cp.xmlFileName == 'caseIH9230.xml' then
		workTool.cp.isCaseIH9230 = true;
	elseif workTool.cp.xmlFileName == 'caseIH9230Crawler.xml' then
		workTool.cp.isCaseIH9230Crawler = true;
	elseif workTool.cp.xmlFileName == 'deutz5465H.xml' then
		workTool.cp.isDeutz5465H = true;

	-- Poettinger Mex 6 [Giants]
	elseif workTool.cp.xmlFileName == 'poettingerMex6.xml' then
		workTool.cp.isPoettingerMex6 = true;

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
	elseif workTool.cp.xmlFileName == 'grimmeSE75-55.xml' then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeSE7555 = true;

	-- Cutters [Giants Titanium DLC]
	elseif workTool.cp.xmlFileName == 'caseIH3162Cutter.xml' then
		workTool.cp.isCaseIH3162Cutter = true;

	-- ###########################################################

	-- [2] TRACTORS
	-- Weidemann 4270 CX100T
	elseif workTool.cp.xmlFileName == 'weidemann4270CX100T.xml' then
		workTool.cp.isWeidemann4270CX100T = true

	-- Case IH Magnum 340 [Giants Titanium]
	elseif workTool.cp.xmlFileName == 'caseIHMagnum340.xml' or workTool.cp.xmlFileName == 'caseIHMagnum340TwinWheel.xml' then
		workTool.cp.isCaseIHMagnum340Titanium = true;

	-- Case IH Puma 160 [Giants Titanium]
	elseif workTool.cp.xmlFileName == 'caseIHPuma160.xml' then
		workTool.cp.isCaseIHPuma160Titanium = true;

	-- ###########################################################

	-- [3] TRAILERS
	-- Bergmann HTW 65 [Giants]
	elseif workTool.cp.xmlFileName == 'bergmannHTW65.xml' then
		workTool.cp.isBergmannHTW65 = true;
		workTool.cp.isPushWagon = true;

	-- Kroeger Agroliner SRB 35 [Giants]
	elseif workTool.cp.xmlFileName == 'SRB35.xml' then
		workTool.cp.isSRB35 = true;
		workTool.cp.isPushWagon = true;

	-- ###########################################################

	-- [4] BALING
	-- Ursus T127 bale loader [Giants Ursus DLC]
	elseif workTool.cp.xmlFileName == 'ursusT127.xml' then
		workTool.cp.isUrsusT127 = true;

	-- Ursus Z586 bale wrapper [Giants Ursus DLC]
	elseif workTool.cp.xmlFileName == 'ursusZ586.xml' then
		workTool.cp.isUrsusZ586 = true;

	-- ###########################################################

	-- [5] OTHER TOOLS
	-- Fahr KH 4S Tedder [Farming Classics - Free DLC]
	elseif workTool.cp.xmlFileName == 'fahrKH4S.xml' then
		workTool.cp.isFahrKH4S = true;

	-- Kuhn FA 367 Mower [Farming Classics - Free DLC]
	elseif workTool.cp.xmlFileName == 'kuhnFA367.xml' then
		workTool.cp.isKuhnFA367 = true;

	-- Seeders [Giants Väderstad DLC]
	elseif workTool.cp.xmlFileName == 'vaderstadRapidA600S.xml' then
		workTool.cp.isVaderstadRapidA600S = true;

	-- Fertilizer [Giants Marshall DLC]
	elseif workTool.cp.xmlFileName == 'marshallMS105.xml' then
		workTool.cp.isMarshallMS105 = true;

	-- Lindner Unitrac [Giant Lindner DLC]
	elseif workTool.cp.xmlFileName == 'lindnerUnitrac92.xml' then
		workTool.cp.isLindnerUnitrac92 = true;
		workTool.cp.mode9TrafficIgnoreVehicle = true;
		workTool.cp.tipperOffset = 1.0;
	elseif workTool.cp.xmlFileName == 'lindnerTransporterModule.xml' then
		workTool.cp.isLindnerTransporterModule = true;
		workTool.cp.isAttacherModule = true;
	elseif workTool.cp.xmlFileName == 'lindnerTankModule.xml' then
		workTool.cp.isLindnerTankModule = true;
	elseif workTool.cp.xmlFileName == 'lindnerSpreaderModule.xml' then
		workTool.cp.isLindnerSpreaderModule = true;
	elseif workTool.cp.xmlFileName == 'lindnerForageModule.xml' then
		workTool.cp.isLindnerForageModule = true;
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
		['AugerWagon'] 			  = { useVehicleCustomEnvironment = true },
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
	return workTool.cp.hasSpecializationSowingMachineWithTank;
end;

function courseplay:isSpecialSprayer(workTool)
	return workTool.cp.isAbbeySprayerPack;
end;

function courseplay:isSpecialChopper(workTool)
	if workTool.cp.isJF1060 or workTool.cp.isPoettingerMex6 or workTool.cp.isPoettingerMexOK then
		if workTool.grainTankFillLevel == nil then
			workTool.grainTankFillLevel = 0;
		end;
		if workTool.grainTankCapacity == nil then
			workTool.grainTankCapacity = 0;
		end;
		if workTool.cp.isChopper == nil then
			workTool.cp.isChopper = true
		end
		return true;
	end
	return false
end

function courseplay:isSpecialMower(workTool)
	return workTool.cp.isPoettingerAlphaX8MowerPack or workTool.cp.isKvernelandMowerPack or workTool.cp.isTaarupMowerPack;
end

function courseplay:isSpecialBaler(workTool)
	return workTool.cp.isClaasQuadrant1200 or workTool.cp.isJohnDeere864Premium;
end;

function courseplay:isSpecialRoundBaler(workTool)
	return workTool.cp.isJohnDeere864Premium;
end;

function courseplay:isSpecialBaleLoader(workTool)
	return workTool.cp.isUBT;
end;

function courseplay:isSpecialCombine(workTool, specialType, fileNames)
	if specialType ~= nil then
		if specialType == "sugarBeetLoader" then
			if (workTool.cp.isRopaEuroMaus or workTool.cp.isHolmerTerraFelis or workTool.cp.isRopaNawaRoMaus) and workTool.unloadingTrigger ~= nil and workTool.unloadingTrigger.node ~= nil then
				if workTool.grainTankFillLevel == nil then
					workTool.grainTankFillLevel = 0;
				end;
				if workTool.grainTankCapacity == nil then
					workTool.grainTankCapacity = 0;
				end;
				return true;
			end;
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

	return workTool.cp.isJF1060;
end


function courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload,ridgeMarker)

	local implementsDown = lower and turnOn
	if workTool.PTOId then
		workTool:setPTO(false)
	end

	--Marshall MS 105 [Giant Marshell DLC Pack]
	if workTool.cp.isMarshallMS105 then
		if workTool.animation.state == 1 then -- Animation: state 1 is starting rotor spreader, state 2 is spreading.
			workTool.animation.runWeight = 1;
			workTool.animation.startWeight = 0;
			workTool.animation.endWeight = 0;
			setAnimTrackTime(workTool.animation.animCharSet, 0, 0);
			disableAnimTrack(workTool.animation.animCharSet, 0);
			setAnimTrackTime(workTool.animation.animCharSet, 1, 0);
			enableAnimTrack(workTool.animation.animCharSet, 1);
			workTool.animation.state = 2;
		end;

		--Lindner Unitrac: Tank Module [Giant Lindner DLC Pack]
	elseif workTool.cp.isLindnerTankModule and self.cp.mode == 4 and not self.cp.inTraffic then
		local isFolding, isFolded, isUnfolded = courseplay:isFolding(workTool);

		if courseplay:isFoldable(workTool) and not isFolding and not isUnfolded then
			workTool:setFoldDirection(workTool.cp.realUnfoldDirection);
		end;

		if workTool.setIsTurnedOn ~= nil and implementsDown ~= nil and implementsDown ~= workTool.isTurnedOn then
			workTool:setIsTurnedOn(implementsDown, false);
		end;

		return true, allowedToDrive;

	--Lindner Unitrac: Stöckl Spreader Module [Giant Lindner DLC Pack]
	elseif workTool.cp.isLindnerSpreaderModule and self.cp.mode == 4 and not self.cp.inTraffic then
		local angle = 0;
		if unfold then
			angle = -38;
		end;

		if workTool.movingTools[1].curRot[workTool.movingTools[1].rotationAxis] ~= math.rad(angle) then
			courseplay:rotateSingleTool(self, workTool, 1, angle);
		end;

		if workTool.setIsTurnedOn ~= nil and implementsDown ~= nil and implementsDown ~= workTool.isTurnedOn then
			workTool:setIsTurnedOn(implementsDown, false);
		end;

		return true, allowedToDrive;

	--Claas Quantum 3800K [Vertex Design]
	elseif workTool.cp.isClaasQuantum3800K then
		--correctly turn off the grass particle system, as it's not being done in the trailer's "Pickup" spec
		if turnOn ~= nil then
			if turnOn then
				if workTool.cp.hasDeactivatedGrassPS then
					workTool.cp.hasDeactivatedGrassPS = false;
				end;
			elseif not turnOn and not workTool.psGrassactive and not workTool.cp.hasDeactivatedGrassPS then
				for _, ps in pairs(workTool.grassParticleSystems) do
					Utils.setEmittingState(ps.particleSystem, false);
				end;
				workTool.cp.hasDeactivatedGrassPS = true;
			end;
		end;
		return false, allowedToDrive;

	--Zunhammer Liquid Manure Pack [Eifok Team]
	elseif workTool.cp.hasEifokZunhammerAttachable and self.cp.mode == 4 then
		local attachable = workTool.cp.eifokZunhammerAttachable;

		if attachable.cp.isEifokZunhammerMoescha then
			--no special handling needed

		elseif attachable.cp.isEifokZunhammerVogelsang then
			if not attachable.isTrans then --set to transport position
				allowedToDrive = false;
				if attachable.isPark then
					attachable:setParking(false);
				end;
			end;
			if unfold ~= nil and unfold ~= attachable.setUnfold then
				attachable:setFoldingDir(unfold);
			end;

			if allowedToDrive then
				allowedToDrive = attachable.isFold or attachable.isUnfold; --basic isFolding for Vogelsang
			end;
		elseif attachable.cp.isEifokZunhammerVibro then
			if unfold ~= nil and unfold ~= attachable.setUnfold then
				attachable:setFoldingDir(unfold);
			end;

			if implementsDown ~= nil and attachable:isLowered() ~= implementsDown and attachable.attacherVehicleJointIndex ~= nil then
				workTool:setJointMoveDown(attachable.attacherVehicleJointIndex, implementsDown, false);
			end;

			if allowedToDrive then
				allowedToDrive = attachable.isFold or attachable.isUnfold; --basic isFolding for Vibro
			end;
		end;

		return false, allowedToDrive;

	elseif workTool.cp.isHoseRefTransporter then
		-- print(string.format('handleSpecialTools(): isHoseRefTransporter, unload=%s -> %s handleSpecialSprayer(..., "push")', tostring(unload), unload and 'call' or 'don\'t call'));
		if unload then
			local fillLevel = workTool.fillLevel * 100 / workTool.capacity;
			if self.cp.tipperFillLevel ~= nil and self.cp.tipperCapacity ~= nil then
				fillLevel = self.cp.tipperFillLevel * 100 / self.cp.tipperCapacity;
			end;
			return courseplay:handleSpecialSprayer(self, workTool, fillLevel, nil, allowedToDrive, nil, nil, nil, "push");
		end;

	--Mchale998 bale wrapper
	elseif workTool.cp.isMchale998 then
		if workTool.baleWrapperState == 3 then
			allowedToDrive = false
		elseif workTool.baleWrapperState == 4 then
			workTool:doStateChange(8)
		end

		return false, allowedToDrive;

	--Rolmasz S061 "Pomorzanin"
	elseif workTool.cp.isRolmaszS061 then
		-- 1 = lower/raise, 2/3 = left/right arm, 4 = cover, 5/6 = left/right ridgeMarker (fold and extend), 7/8 = left/right ridgeMarker (up and down)
		local animParts = workTool.animationParts;

		local isLoweringRaising = courseplay:isAnimationPartPlaying(workTool, 1);
		local isRaised = animParts[1].clipEndTime == false;
		local isLowered = animParts[1].clipEndTime;
		local isFolded = animParts[2].clipStartTime and animParts[3].clipStartTime;
		local isUnfolded = animParts[2].clipEndTime and animParts[3].clipEndTime;
		--local isFolding = courseplay:isAnimationPartPlaying(workTool, { 2, 3, 5, 6, 7, 8 });
		local isFolding = courseplay:isAnimationPartPlaying(workTool, { 2, 3 });
		local isMovingRidgeMarkers = courseplay:isAnimationPartPlaying(workTool, { 5, 6, 7, 8 });
		local leftRidgeMarkerExtended = animParts[5].clipEndTime;
		local rightRidgeMarkerExtended = animParts[6].clipEndTime;

		if unfold then
			if isRaised and isFolded and not isMovingRidgeMarkers and not (leftRidgeMarkerExtended or rightRidgeMarkerExtended) then
				workTool:setAnimationTime(2, animParts[2].animDuration); --unfold left arm
				workTool:setAnimationTime(3, animParts[3].animDuration); --unfold right arm
			end;
		else
			if isRaised and isUnfolded and not isMovingRidgeMarkers then
				if not (leftRidgeMarkerExtended or rightRidgeMarkerExtended) then
					workTool:setAnimationTime(2, animParts[2].startPosition); --fold left arm
					workTool:setAnimationTime(3, animParts[3].startPosition); --fold right arm
				end;

				--stow ridgeMarkers
				for i=5,8 do
					if animParts[i].clipEndTime then
						workTool:setAnimationTime(i, animParts[i].startPosition);
					end;
				end;
			end;
		end;

		if self.cp.ridgeMarkersAutomatic and ridgeMarker and isUnfolded then
			if not leftRidgeMarkerExtended then
				workTool:setAnimationTime(5, animParts[5].animDuration);
			end;
			if not rightRidgeMarkerExtended then
				workTool:setAnimationTime(6, animParts[6].animDuration);
			end;

			--Note: for some reason, startPosition = down and animDuration = up
			if ridgeMarker == 0 then --none
				--raise ridgeMarkers
				if animParts[7].clipStartTime then
					workTool:setAnimationTime(7, animParts[7].animDuration);
					--print("raise left ridgeMarker (both)");
				end;
				if animParts[8].clipStartTime then
					workTool:setAnimationTime(8, animParts[8].animDuration);
					--print("raise right ridgeMarker (both)");
				end;
			elseif ridgeMarker == 1 then --left
				if animParts[8].clipStartTime then
					workTool:setAnimationTime(8, animParts[8].animDuration);
					--print("raise right ridgeMarker");
				end;
				if animParts[7].clipEndTime then
					workTool:setAnimationTime(7, animParts[7].startPosition);
					--print("lower left ridgeMarker");
				end;
			elseif ridgeMarker == 2 then --right
				if animParts[7].clipStartTime then
					workTool:setAnimationTime(7, animParts[7].animDuration);
					--print("raise left ridgeMarker");
				end;
				if animParts[8].clipEndTime then
					workTool:setAnimationTime(8, animParts[8].startPosition);
					--print("lower right ridgeMarker");
				end;
			end;
		end;

		if isFolding or isLoweringRaising then
			allowedToDrive = false;
		end;

		if lower then
			if isUnfolded and not isLowered and not isLoweringRaising then
				workTool:aiLower();
			end;
		else
			workTool:aiRaise();
		end;

		if turnOn then
			if isLowered and not workTool.isTurnedOn then
				workTool:aiTurnOn();
			end;
		else
			workTool:aiTurnOff();
		end;

		return false, allowedToDrive;

	--Universal Bale Trailer
	elseif workTool.cp.isUBT then
		if not workTool.fillLevelMax == workTool.numAttachers[workTool.typeOnTrailer] then
			workTool.fillLevelMax = workTool.numAttachers[workTool.typeOnTrailer];
		end;
		if workTool.capacity == nil or (workTool.capacity ~= nil and workTool.capacity ~= workTool.fillLevelMax) then
			workTool.capacity = workTool.fillLevelMax;
			workTool.realBaseCapacity = workTool.fillLevelMax;
		end;

		if not workTool.autoLoad then
			workTool.autoLoad = true;
		end;
		if workTool.loadingIsActive ~= turnOn then
			workTool.loadingIsActive = turnOn;
		end;

		if unload then
			local root = getRootNode();
			for i=1, workTool.numAttachers[workTool.typeOnTrailer] do
				local attacher = workTool.attacher[workTool.typeOnTrailer][i];
				if attacher.attachedObject ~= nil then

					--ORIG: if workTool.ulRef[workTool.ulMode][1] == g_i18n:getText("UNLOAD_TRAILER") then
					if workTool.ulRef[workTool.ulMode][3] == 0 then --verrrrry dirty: unload on trailer
						local x,y,z = getWorldTranslation(attacher.attachedObject);
						local rx,ry,rz = getWorldRotation(attacher.attachedObject);
						setRigidBodyType(attacher.attachedObject,"Dynamic");
						setTranslation(attacher.attachedObject,x,y,z);
						setRotation(attacher.attachedObject,rx,ry,rz);
						link(root,attacher.attachedObject);
						attacher.attachedObject = nil;
						workTool:setFillLevel(workTool.fillLevel - 1, Fillable.FILLTYPE_UNKNOWN, true);
					else
						local x,y,z = getWorldTranslation(attacher.attachedObject);
						local rx,ry,rz = getWorldRotation(attacher.attachedObject);
						local nx,ny,nz = getWorldTranslation(workTool.attacherLevel[workTool.typeOnTrailer]);
						local tx,ty,tz = getWorldTranslation(workTool.ulRef[workTool.ulMode][3]);
						local x = x + (tx - nx);
						local y = y + (ty - ny);
						local z = z + (tz - nz);
						local tH = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z);
						local relHeight = ny - tH;
						setRigidBodyType(attacher.attachedObject,"Dynamic");
						setTranslation(attacher.attachedObject,x,(y - relHeight),z);
						setRotation(attacher.attachedObject,rx,ry,rz);
						link(root,attacher.attachedObject);
						attacher.attachedObject = nil;
						workTool:setFillLevel(workTool.fillLevel - 1, Fillable.FILLTYPE_UNKNOWN, true);
					end;
				end;
			end;
		end;
		return true, allowedToDrive;

	--RopaEuroTiger
	elseif self.cp.isRopaEuroTiger then
		local fold = self:getToggledFoldDirection()
		if unfold then
			if  fold == -1 then
				self:setFoldState(fold, false);
			end
		else
			if  fold == 1 and self.grainTankFillLevel == 0 then
				self:setFoldState(fold, false);
			end
		end
		if self.foldAnimTime > 0 and self.foldAnimTime < 1 then
			return true, false
		end;
		if self.steeringMode ~= 5 and lower then
			self:setSteeringMode(5)
		end
		if not lower then
			self:setSteeringMode(4)
		end

		return false, allowedToDrive
	end;

	--KotteGARANTProfiVQ32000
	if workTool.cp.isKotteGARANTProfiVQ32000 then
		if workTool.cp.crabSteerMode ~= 0 then
			local ridgeMarker = self.Waypoints[self.recordnumber].ridgeMarker
			if not implementsDown then
				workTool.crabSteerMode = 0
			else
				workTool.crabSteerMode = workTool.cp.crabSteerMode
				if ridgeMarker == 1 then
					workTool.HGdirection = 1;
					courseplay:changeToolOffsetX(self, nil, 3, true);
				elseif ridgeMarker == 2 then
					workTool.HGdirection = -1;
					courseplay:changeToolOffsetX(self, nil, -3, true);
				end
			end
		end

		return false, allowedToDrive

	--Urf-specialisation
	elseif workTool.cp.hasUrfSpec and workTool.sprayFillLevel ~= nil and workTool.isFertilizing ~= nil then
		if workTool.sprayFillLevel == 0 and ((type(workTool.isFertilizing) == 'number' and workTool.isFertilizing > 1) or workTool.isFertilizing == true) then
			self.cp.urfStop = true;
		end;
		return false, allowedToDrive;

	--KvernelandMowerPack
	elseif workTool.cp.isKvernelandMowerPack then
		if workTool.cp.isKvernelandKD240 then
			if workTool.TransRot ~= nil and workTool.TransRot ~= down then
				workTool:setTransRot(not unfold);
			end
			if workTool.setArmOne ~= nil then
				workTool:setArmOne(implementsDown);
			end
		elseif workTool.cp.isKverneland4028AS or workTool.cp.isKverneland4028 then
			if workTool.TransRot ~= nil and workTool.TransRot ~= down then
				workTool:setTransRot(unfold);
			end
			if workTool.setSideSkirts ~= nil and workTool.isSideSkirtsOn ~= unfold then
				workTool:setSideSkirts(unfold);
			end
			if workTool.setWheelRot ~= nil and (workTool.isWheelRotOn == implementsDown) or (workTool.isWheelRotOn == nil and not implementsDown) then
				workTool:setWheelRot(not implementsDown );
			end
		else
			if workTool.TransRot ~= nil and workTool.TransRot ~= down then
				workTool:setTransRot(implementsDown);
			end
			if workTool.setSideSkirts ~= nil and workTool.isSideSkirtsOn ~= unfold then
				workTool:setSideSkirts(unfold);
			end
		end
		if workTool.isTurnedOn ~= turnOn then
			workTool:setIsTurnedOn(turnOn);
		end

		return true, allowedToDrive

	-- TaarupMowerPack
	elseif workTool.cp.isTaarupMowerPack then
		if workTool.isReadyToTransport then
			workTool:setTransport(not unfold)
		end
		if down ~= workTool.mowerFoldingParts[1].mainPart.isDown then
			for k, part in pairs(workTool.mowerFoldingParts) do
				workTool:setIsArmDown(k, implementsDown);
			end;
		end
		if workTool.isTurnedOn ~= turnOn then
			workTool:setIsTurnedOn(turnOn);
		end

		--custom isFolding for Kverneland mowers
		if workTool.mowerFoldingParts ~= nil then
			for partIdx, foldingPart in pairs(workTool.mowerFoldingParts) do
				local mainPart = foldingPart.mainPart;
				local axes, curRot = { "x", "y", "z" }, {};
				curRot.x, curRot.y, curRot.z = getRotation(mainPart.joint.jointNode);
				--print(string.format("part %d: minRot=%f,%f,%f, maxRot=%f,%f,%f, curRot=%f,%f,%f", partIdx, mainPart.minRot[1], mainPart.minRot[2], mainPart.minRot[3], mainPart.maxRot[1], mainPart.maxRot[2], mainPart.maxRot[3], curRot.x, curRot.y, curRot.z));
				for i,axis in pairs(axes) do
					if courseplay:isBetween(curRot[axis], mainPart.minRot[i], mainPart.maxRot[i], false) then
						--print(string.format("isFolding: curRot.%s is between mainPart.minRot[%d] and mainPart.maxRot[%d]", axis, i, i));
						allowedToDrive = false;
					end;
				end;
			end;
		end

		return true, allowedToDrive

	--Claas Quadrant 1200 / John Deere 864 Premium
	elseif workTool.cp.isClaasQuadrant1200 or workTool.cp.isJohnDeere864Premium then
		if unfold ~= nil and turnOn ~= nil and lower ~= nil then
			if workTool.cp.isClaasQuadrant1200 then
				if not unfold then
					workTool:emptyBaler(true);
					workTool:setPTO(true)
				end
				if workTool.sl.isOpen ~= unfold then
					workTool:openSlide(unfold);
				end
				if workTool.pu.bDown ~= implementsDown then
					workTool:releasePickUp(implementsDown)
				end
				if workTool.isTurnedOn ~= unfold then
					workTool.isTurnedOn = unfold
				end

			elseif workTool.cp.isJohnDeere864Premium then
				--EMPTY BALER
				if not unfold then
					if #(workTool.bales) == 0 and workTool.fillLevel > 200 and workTool.coverEdge.isLoaded and workTool.shouldNet == false and not workTool.isNetting then
						workTool:setShouldNet(true);
					elseif #(workTool.bales) > 0 then
						if workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then --unload bale
							workTool:setIsUnloadingBale(true);
						end;
					elseif workTool.fillLevel == 0 and workTool.balerUnloadingState == Baler.UNLOADING_OPEN then
						workTool:setIsUnloadingBale(false);
						if workTool.isTurnedOn then
							workTool:setIsTurnedOn(false, false);
						end;
					elseif workTool.fillLevel <= 200 and workTool.balerUnloadingState == Baler.UNLOADING_CLOSED and not workTool.isNetting then
						if workTool.isTurnedOn then
							workTool:setIsTurnedOn(false, false);
						end;
					end;
				end;

				if workTool.isPickupDown ~= implementsDown then
					workTool:setPickup(implementsDown)
				end;
				if not workTool.attachablePTO.attached then
					workTool:togglePTOAttach(true);
				end;
				if workTool.isSupportDown then
					workTool:toggleSupport(false);
				end;

				--SPARE NETS
				if not workTool.coverEdge.isLoaded then
					allowedToDrive = false;

					if workTool.balerUnloadingState == Baler.UNLOADING_CLOSED then
						if workTool.coverEdge.hasSpareNet then --set spare net to current net
							if not workTool.doors.rear.isOpen then
								courseplay.thirdParty.JD864PremiumOpenRearDoor(workTool, true);
							else
								workTool:setHasNet(true);
								courseplay.thirdParty.JD864PremiumOpenRearDoor(workTool, false, true);
							end;

						else --open doors for additional net supply
							if workTool.isTurnedOn then
								workTool:setIsTurnedOn(false);
							end;
							courseplay:setGlobalInfoText(self, 'BALER_NETS');
							if not workTool.doors.rear.isOpen then
								courseplay.thirdParty.JD864PremiumOpenRearDoor(workTool, true);
							elseif workTool.coverEdge.palletInRange ~= nil and workTool.coverEdge.palletInRange.rollsLeft > 0 then
								workTool:setHasSpareNet(true); --1st spare roll
								workTool.coverEdge.palletInRange:removeRoll(workTool.coverEdge.palletInRange.rollsLeft-1);
								workTool:setHasNet(true); --move spare to active
								if workTool.coverEdge.palletInRange.rollsLeft > 0 then
									workTool:setHasSpareNet(true); --2nd spare roll
									workTool.coverEdge.palletInRange:removeRoll(workTool.coverEdge.palletInRange.rollsLeft-1);
								end;
								courseplay.thirdParty.JD864PremiumOpenRearDoor(workTool, false, true);
							end;
							return true, allowedToDrive;
						end;
					end;
				end;
			end;

			--speed regulation
			if workTool.isBlocked then
				allowedToDrive = false;
				courseplay:setGlobalInfoText(self, 'PICKUP_JAMMED');
			end;
			workTool.blockMaxTime = 10000
			if workTool.actLoad2 == 1 then
				if workTool.blockTimer > workTool.blockMaxTime *0.8 then
					self.cp.maxFieldSpeed = self.cp.maxFieldSpeed * 0.7;
					allowedToDrive = false
				end
			end
			local actLoadSend;
			if workTool.actLoad_IntSend ~= nil then
				actLoadSend = workTool.actLoad_IntSend;
			elseif workTool.actLoad_Send ~= nil then
				actLoadSend = workTool.actLoad_Send;
			end;

			if actLoadSend ~= nil then
				if actLoadSend < 0.8 and not workTool.isBlocked and actLoadSend ~= 0 then
					self.cp.maxFieldSpeed = self.cp.maxFieldSpeed + 0.02/3600
				end
				if actLoadSend == 0 and self.cp.maxFieldSpeed == 0 then
					self.cp.maxFieldSpeed = 4/3600
				end
				if actLoadSend > 0.9 and self.cp.maxFieldSpeed > 1/3600 then
					self.cp.maxFieldSpeed = self.cp.maxFieldSpeed - 0.05/3600
				end
			end;
			--speed regulation END
		end;

		if workTool.cp.isClaasQuadrant1200 then
			return true, allowedToDrive;
		else
			if not unfold then
				return true, allowedToDrive;
			else
				return false, allowedToDrive;
			end;
		end;

	--Ursus Z586 BaleWrapper
	elseif workTool.cp.isUrsusZ586 then
		if workTool.baleWrapperState == 4 then
			workTool:doStateChange(5)
		end
		if workTool.baleWrapperState ~= 0 then 
			allowedToDrive = false
		end

		return false ,allowedToDrive

	--JF_FCT1060_ProTec
	elseif workTool.cp.isJF1060 then
		if unfold ~= nil and turnOn ~= nil and lower ~= nil then
			if unfold ~= workTool.isArmOneOn and not workTool.isTurnedOn then
				workTool:setArmOne(unfold);
			end
			if unfold ~= workTool.isTransRotOn and not workTool.isTurnedOn  then
				workTool:setTransRot(unfold);
			end
			if workTool.isTurnedOn then
				workTool:setPickup(lower);
			end
			if workTool.isTransRotOn and workTool.isArmOneOn then
				workTool:setIsTurnedOn(unfold);
			end
		end
		local targetTrailer = workTool:findAutoAimTrailerToUnload(workTool.currentFruitType);
		local trailer, trailerDistance = workTool:findTrailerToUnload(workTool.currentFruitType);
		if targetTrailer == nil or trailer == nil then
			allowedToDrive = false
		end

		return true ,allowedToDrive

	--Abbey 3000 NurseTanker
	elseif workTool.cp.isAbbey3000Nurse then
		local x,y,z = getRotation(workTool.boomArmY)
		local a,b,c = getRotation(workTool.boomArmX)
		if unload ~= nil then
			if unload then

				if y >= -1.56 then
					workTool.isEntered = true
					InputBinding.actions[InputBinding.BOOM_RIGHT].lastIsPressed = true 
				else
					workTool.isEntered = false
				end
				if workTool.isSpreaderInRange ~= nil then
					local fillable = workTool.isSpreaderInRange
					local fillableHasAttacherVehicle = fillable.attacherVehicle ~= nil;
					if fillableHasAttacherVehicle then
						fillable.attacherVehicle.cp.stopForLoading = true;
					end;
					if fillable.fillLevel >= fillable.capacity  or workTool.fillLevel <= 5 then
						workTool:setIsTurnedOn(false)
						if fillableHasAttacherVehicle then
							fillable.attacherVehicle.cp.stopForLoading = false
							fillable.attacherVehicle.wait = false
						end;
					elseif not workTool.isTurnedOn then
						workTool:setIsTurnedOn(true)
					end
				end
			else
				if y < -0.01 then
					workTool.isEntered = true
					InputBinding.actions[InputBinding.BOOM_LEFT].lastIsPressed = true
				elseif y > 0.01 then
					workTool.isEntered = true
					InputBinding.actions[InputBinding.BOOM_RIGHT].lastIsPressed = true
				elseif a < -0.00 then
					workTool.isEntered = true
					InputBinding.actions[InputBinding.BOOM_DOWN].lastIsPressed = true
				else
					workTool.isEntered = false
				end
			end
		end

		return true, allowedToDrive

	--Abbey 2000/3000R
	elseif workTool.cp.isAbbey3000R or workTool.cp.isAbbey2000R then
		if workTool.PTOId then
			workTool:setPTO(false)
		end
		if cover ~= nil then
			local Cover = -1
			if cover then
				Cover = 1
			end
			workTool:setFoldDirection(Cover);
		end

		if lower ~= nil and turnOn ~= nil then
			if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn then
				workTool:setIsTurnedOn(implementsDown, false);
			end
			if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn and not spray then
				workTool:setIsTurnedOn(implementsDown, false);
			end
		end

		return true, allowedToDrive

	--Abbey AP900  workwith 5.8m offset-4,1m
	elseif workTool.cp.isAbbeyAP900 then
		if workTool.PTOId then
			workTool:setPTO(false)
		end
		if unfold == true then
			if workTool.animationParts[1].currentPosition <= 3001 then
				workTool:setAnimationTime(1, workTool.animationParts[1].currentPosition+(workTool.animationParts[1].offSet*(3)));
			end
		else
			if workTool.animationParts[1].currentPosition > 0 then
				workTool:setAnimationTime(1, workTool.animationParts[1].currentPosition-(workTool.animationParts[1].offSet*(3)));
			end
		end

		return false, allowedToDrive

	--gueldnerG40Frontloader free DLC classics
	elseif workTool.animatedFrontloader ~= nil then
		workTool:releaseShovel(unfold);

	--Krone Swadro 900 [NI-Modding]
	elseif workTool.cp.isKroneSwadro900 then
		local rfp1,rfp2 = workTool.rowerFoldingParts[1], workTool.rowerFoldingParts[2];

		local _,_,z1 = getRotation(rfp1.mainPart.joint.jointNode);
		local _,_,z2 = getRotation(rfp2.mainPart.joint.jointNode);

		local isFolded1   = math.abs(z1/(rfp1.mainPart.minRot[3] + 0.00001)) < 0.01;
		local isFolded2   = math.abs(z2/(rfp2.mainPart.minRot[3] + 0.00001)) < 0.01;
		local isFolded    = isFolded1 and isFolded2;

		local isUnfolded1 = math.abs(z1/(rfp1.mainPart.maxRot[3] + 0.00001)) > 0.99;
		local isUnfolded2 = math.abs(z2/(rfp2.mainPart.maxRot[3] + 0.00001)) > 0.99;
		local isUnfolded  = isUnfolded1 and isUnfolded2;

		local isFolding = not isFolded and not isUnfolded;
		if isFolding then
			allowedToDrive = false;
		end;

		local isLowered = rfp1.mainPart.isDown and rfp2.mainPart.isDown;

		-- print(('%s: [unfold=%s, lower=%s, turnOn=%s]'):format(nameNum(workTool), tostring(unfold), tostring(lower), tostring(turnOn)));
		-- print(('\t\tisFolded1=%s, isFolded2=%s, isUnfolded1=%s, isUnfolded2=%s, isFolded=%s, isUnfolded=%s, isFolding=%s'):format(tostring(isFolded1), tostring(isFolded2), tostring(isUnfolded1), tostring(isUnfolded2), tostring(isFolded), tostring(isUnfolded), tostring(isFolding)));

		--fold/unfold
		if (workTool.isTransport == unfold) and not isLowered then
			workTool:setTransport(not unfold);
			allowedToDrive = false; --not really needed, as it's only called once
		end;

		if isUnfolded then
			--lower/raise
			for i,part in pairs(workTool.rowerFoldingParts) do
				if not workTool.isTransport and part.mainPart.isDown ~= lower then
					workTool:setIsArmDown(i, lower);
					allowedToDrive = false; --not really needed, as it's only called once
				end;
			end;

			--turn on/off
			if workTool.isTurnedOn ~= turnOn then
				workTool:setIsTurnedOn(turnOn);
			end;
		end;

		return true, allowedToDrive;

	-- Claas liner 4000
	elseif workTool.cp.isClaasLiner4000 then
		local isReadyToWork = workTool.rowerFoldingParts[1].isDown;
		local manualReset = false
		if workTool.cp.unfoldOrderIsGiven == nil then
			workTool.cp.unfoldOrderIsGiven = false
			workTool.cp.foldOrderIsGiven = false
		end
		if unfold == false and isReadyToWork then
			workTool.cp.foldOrderIsGiven = true
		end
		--lower
		if workTool.foldAnimTime > 0.99 then
			if isReadyToWork then
				for k, part in pairs(workTool.rowerFoldingParts) do
					workTool:setIsArmDown(k, lower);
				end;
				if workTool.cp.unfoldOrderIsGiven or workTool.cp.foldOrderIsGiven then
					--turn OnOff
					workTool:setIsTurnedOn(turnOn);
					workTool.cp.unfoldOrderIsGiven = false
				end
			end
		else
			allowedToDrive = false
		end
		--unfold
		if (unfold and workTool.isTransport) or (workTool.cp.foldOrderIsGiven and isReadyToWork)  then
			workTool:setTransport(not unfold)
			if workTool.isReadyToTransport or workTool.cp.foldOrderIsGiven then
				if workTool.foldMoveDirection > 0.1 or (workTool.foldMoveDirection == 0 and workTool.foldAnimTime > 0.5) then
					workTool:setFoldDirection(-1)
				else
					workTool:setFoldDirection(1)
				end;
				workTool.cp.foldOrderIsGiven = false
			end;
			workTool.cp.unfoldOrderIsGiven = true

		end
		if workTool.foldAnimTime == 0 then
			allowedToDrive = true
		end
		return true, allowedToDrive



	-- Tebbe HS180 script (Stefan Maurus)
	elseif workTool.cp.isTebbeHS180 then
		local flap = 0;
		if workTool.setDoorHigh ~= nil and workTool.doorhigh ~= nil then
			if turnOn then 
				flap = 3;
			end;
			workTool:setDoorHigh(flap);
		end
		if workTool.setFlapOpen ~= nil and workTool.flapopen then
			workTool:setFlapOpen(turnOn)
		end
		return false, allowedToDrive


	-- Fuchs liquid manure barrell (Stefan Maurus)
	elseif workTool.cp.isFuchsLiquidManure and workTool.setdeckelAnimationisPlaying ~= nil then
		if cover ~= nil then
			workTool:setdeckelAnimationisPlaying(cover);
		end
		return false, allowedToDrive

	--Poettinger Alpha
	elseif workTool.cp.isPoettingerAlpha and workTool.alpMot ~= nil and workTool.setTurnedOn ~= nil and workTool.setLiftUp ~= nil and workTool.setTransport ~= nil then
		--fold/unfold
		workTool:setTransport(not unfold);
		if workTool.alpMot.isTransport ~= nil then
			if (unfold and workTool.alpMot.isTransport) or (not unfold and not workTool.alpMot.isTransport) then
				allowedToDrive = false;
			end;
		end;

		--lower/raise
		workTool:setLiftUp(not lower);
		if workTool.alpMot.isLiftUp ~= nil and workTool.alpMot.isLiftDown ~= nil then
			if (lower and workTool.alpMot.isLiftUp) or (not lower and workTool.alpMot.isLiftDown) then
				allowedToDrive = false;
			end;
		end;

		--turn on/off
		workTool:setTurnedOn(turnOn);

		return true, allowedToDrive;



	--Poettinger X8
	elseif workTool.cp.isPoettingerX8 and workTool.x8 ~= nil and workTool.x8.mowers ~= nil and workTool.setTurnedOn ~= nil and workTool.setLiftUp ~= nil and workTool.setTransport ~= nil and workTool.setSelection ~= nil then
		workTool:setSelection(3);

		local isFolded = workTool.x8.mowers[1].isTransport and workTool.x8.mowers[2].isTransport;
		local isRaised = workTool.x8.mowers[1].isLiftUp and workTool.x8.mowers[2].isLiftUp;

		--fold/unfold
		workTool:setTransport(not unfold);
		if (unfold and isFolded) or (not unfold and not isFolded) then
			allowedToDrive = false;
		end;

		--lower/raise
		workTool:setLiftUp(not lower);
		if (lower and isRaised) or (not lower and not isRaised) then
			allowedToDrive = false;
		end;

		--turn on/off
		workTool:setTurnedOn(turnOn);

		return true, allowedToDrive;
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
	if (self.cp.isJohnDeereS690iBBM or self.cp.isJohnDeereS680BBM or self.cp.isJohnDeereS670BBM) and not self.isRealistic then
		if self.motor.maxTorques[1] > 0 then
			self.motor.maxTorques[1] = -self.motor.maxTorques[1];
		end;

	elseif self.cp.isWeidemann4270CX100T  then
		local frontPart_vis = getParent(self.movingTools[1].node)
		local frontPart = getParent(frontPart_vis)
		self.aiTrafficCollisionTrigger = getChild(frontPart, "trafficCollisionTrigger");

	elseif self.cp.isKirovetsK700A then
		self.cp.DirectionNode = self.components[2].node;
		self.cp.isKasi = 3.4; -- (Distance from rootNode to DirectionNode) Used to set the correct distance.

	elseif self.cp.isRopaEuroTiger then
		self:setSteeringMode(5)
		self.cp.offset = 5.2
		self.cp.noStopOnTurn = true
		self.cp.noStopOnEdge = true
	end;

	-- OBJECTS
	if object.cp.isBrantnerDPW18000 then
		object.cp.specialUnloadDistance = -2.3;

	elseif object.cp.isMoellerUbtBaleLoader then
		object.cp.specialUnloadDistance = -2.63;

	elseif object.cp.isVaderstadRapidA600S then
		object.cp.haveInversedRidgeMarkerState = true;

	elseif object.cp.isUrsusT127 then
		object.cp.specialUnloadDistance = -1.8;

	elseif object.cp.isMarshallMS105 then
		automaticToolOffsetX = -7.0;

	elseif object.cp.isLindnerTankModule then
		object.cp.realUnfoldDirectionIsReversed = true;
		self.cp.aiTurnNoBackward = true;
		self.cp.backMarkerOffset = -5;

	elseif object.cp.isLindnerSpreaderModule then
		automaticToolOffsetX = 4.7;
		self.cp.backMarkerOffset = -3.5;

	elseif object.cp.isLindnerForageModule then
		self.cp.aiTurnNoBackward = true;
		self.cp.noStopOnEdge = true;
		self.cp.noStopOnTurn = true;
		courseplay:changeToolOffsetZ(self, nil, -5);

	elseif object.cp.isKuhnFA367 then
		object.cp.realUnfoldDirectionIsReversed = true;
		automaticToolOffsetX = -2.1;

	elseif object.cp.isFahrKH4S then
		-- self.cp.aiTurnNoBackward = false; -- TODO: (Claus) Why is it not reversing when turning ? Need to fix this!
		object.cp.realUnfoldDirectionIsReversed = true;

	elseif object.cp.isMRpoettingerEurocat315H then
		object.cp.realUnfoldDirectionIsReversed = true;

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

	elseif object.cp.isHoseRefTransporter then
		courseplay:debug(('\tobject %q: isHoseRefTransporter=true'):format(nameNum(object)), 14);
		if object.cp.hoseRefs == nil then
			courseplay:debug('\tsetCustomHoseRefs()', 14);
			courseplay.thirdParty.EifokLiquidManure:setCustomHoseRefs(object);
		end;

		-- add attached hoses to traffic collision ignore list
		for side,ref in pairs(object.cp.hoseRefs.park) do
			if ref.isUsed and ref.hose ~= nil then
				courseplay:debug(('%s: %s: add hose %d [park %s] to traffic collision ignore list'):format(nameNum(self), nameNum(object), ref.hose.rootNode, side), 3);
				self.cpTrafficCollisionIgnoreList[ref.hose.rootNode] = true;
			end;
		end;

	elseif object.cp.isEifokZunhammerAttachable then
		courseplay:debug(('\tobject %q: isEifokZunhammerAttachable=true'):format(nameNum(object)), 14);
		for i,tipper in pairs(self.tippers) do
			if object.attacherVehicle == tipper then
				courseplay:debug(('\t\t%s: hasEifokZunhammerAttachable=true, eifokZunhammerAttachable=%q'):format(nameNum(tipper), nameNum(object)), 14);
				tipper.cp.hasEifokZunhammerAttachable = true;
				tipper.cp.eifokZunhammerAttachable = object;
				break;
			end;
		end;

	elseif object.cp.isMchale998 then
		self.cp.aiTurnNoBackward = true
		self.cp.noStopOnEdge = true
		self.cp.noStopOnTurn = true
		automaticToolOffsetX = -2.4

	elseif object.cp.isKotteGARANTProfiVQ32000 then
		object.cp.feldbinders = {}
		for i=1, #g_currentMission.attachables do
			if g_currentMission.attachables[i].fillerArmInRange ~= nil then
				table.insert(object.cp.feldbinders,i)
			end
		end
		object.cp.crabSteerMode = object.crabSteerMode
		object.cp.tankerId = 0
	elseif object.cp.isGrimmeSE7555 then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -2.1
		print("Grimme SE 75-55 workwidth: 1 m");
	elseif object.cp.isGrimmeRootster604 then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -0.9
		print("Grimme Rootster 604 workwidth: 2.8 m");
	elseif object.cp.isPoettingerMex6 then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -2.5
		print("Pöttinger Mex 6 workwidth: 2.0 m");
	elseif object.cp.isPoettingerMexOK then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -1.7;
		print("Pöttinger Mex OK workwidth: 0.5 m");
	elseif object.cp.isAbbeyAP900 then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -4.1
		print("Abbey AP900 workwidth: 5.8 m");
	elseif object.cp.isJF1060 then
		self.cp.aiTurnNoBackward = true
		automaticToolOffsetX = -2.5
	elseif object.cp.isUrsusZ586 then
		self.cp.aiTurnNoBackward = true
		self.cp.noStopOnEdge = true
		self.cp.noStopOnTurn = true
		automaticToolOffsetX = -2.5;
	elseif object.cp.isSilageShield then
		self.cp.hasShield = true
	end

	if automaticToolOffsetX ~= nil then
		self.cp.tempToolOffsetX = self.cp.toolOffsetX;
		courseplay:changeToolOffsetX(self, nil, automaticToolOffsetX, true);
	end;
end

function courseplay:getSpecialWorkWidth(implement)
	if implement.cp then
		if implement.cp.isLindnerTankModule then
			return 6.0;
		end;
	end;

	return nil;
end;

function courseplay:handleSpecialSprayer(self, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, pumpDir)
	local vehicle = self;
	pumpDir = pumpDir or "pull";
	driveOn = driveOn or 100;
	local isDone = (pumpDir == "pull" and fillLevelPct >= driveOn) or (pumpDir == "push" and fillLevelPct == 0);

	--Marshall MS 105 [Giant Marshell DLC Pack]
	if activeTool.cp.isMarshallMS105 and vehicle.cp.mode == 4 then
		if vehicle.cp.numWaitPoints == 3 then
			local refillPoint = vehicle.cp.waitPoints[3];
			local openHatch = vehicle.recordnumber > refillPoint - 1 and vehicle.recordnumber <= refillPoint + 4;
			courseplay:rotateSingleTool(self, activeTool, 1, openHatch, dt);
		end;

	--Lindner Unitrac: Stöckl Spreader Module [Giant Lindner DLC Pack]
	elseif activeTool.cp.isLindnerSpreaderModule and vehicle.cp.mode == 4 then
		if vehicle.cp.numWaitPoints == 3 then
			local refillPoint = vehicle.cp.waitPoints[3];
			local isInRefillArea = vehicle.recordnumber > refillPoint - 3 and vehicle.recordnumber <= refillPoint;
			if isInRefillArea and not activeTool:getIsAnimationPlaying('planeMover') and activeTool:getRealAnimationTime('planeMover') ~= 0 then
				activeTool:resetMover();
				courseplay:debug(string.format('%s: Resetting planeMover', nameNum(activeTool)), 6);
			end;
		end;

	--HoseRef system: sprayer [Eifok Team]
	elseif activeTool.cp.isHoseRefSprayer and vehicle.cp.mode == 4 then
			-- courseplay:debug(string.format('\t%s handleSpecialSprayer() start [isHoseRefSprayer] - pumpDir=%s, allowedToDrive=%s, searchMapHoseRefStation[pumpDir]=%s, targetRefillObject[pumpDir]=%s, isDone=%s', nameNum(activeTool), tostring(pumpDir), tostring(allowedToDrive), tostring(vehicle.cp.EifokLiquidManure.searchMapHoseRefStation[pumpDir]), tostring(vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil), tostring(isDone)), 14);
		if vehicle.cp.EifokLiquidManure.searchMapHoseRefStation[pumpDir] and vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil and not isDone then
			courseplay.thirdParty.EifokLiquidManure:findRefillObject(vehicle, activeTool, 'MapHoseRefStation', pumpDir); --find MapHoseRefStations
		end;
		if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] ~= nil and vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir].type == 'MapHoseRefStation' then
			allowedToDrive = courseplay.thirdParty.EifokLiquidManure:refillViaHose(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, pumpDir);
		end;

		if vehicle.cp.waitPoints[3] ~= nil and (vehicle.recordnumber == vehicle.cp.waitPoints[3] or vehicle.cp.lastRecordnumber == vehicle.cp.waitPoints[3]) and vehicle.wait then
			if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil and courseplay:timerIsThrough(vehicle, 'findRefillObject') and not isDone then
				courseplay.thirdParty.EifokLiquidManure:findRefillObject(vehicle, activeTool, 'HoseRefVehicles', pumpDir); --find HoseRef vehicles (transporters and containers)
				if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil then
					courseplay:setCustomTimer(vehicle, 'findRefillObject', 6);
				end;
			end;
			if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] ~= nil then
				if vehicle.cp.timers.findRefillObject ~= 0 then --reset timer
					vehicle.cp.timers.findRefillObject = 0;
				end;
				allowedToDrive = courseplay.thirdParty.EifokLiquidManure:refillViaHose(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, pumpDir);
			end;

		elseif pumpDir == 'pull' and vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil then
			allowedToDrive = courseplay.thirdParty.EifokLiquidManure:refillAtLiquidManureTrigger(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt);
		end;

		--courseplay:debug(string.format('\t%s handleSpecialSprayer() end [isHoseRefSprayer] - allowedToDrive==%s', nameNum(activeTool), tostring(allowedToDrive)), 14);
		return true, allowedToDrive, lx, lz;

	--HoseRef system: transporter [Eifok Team]
	elseif activeTool.cp.isHoseRefTransporter then
		-- courseplay:debug(string.format('\t%s handleSpecialSprayer() start [isHoseRefTransporter] - pumpDir=%s, allowedToDrive=%s, searchMapHoseRefStation[pumpDir]=%s, targetRefillObject[pumpDir]=%s, isDone=%s', nameNum(activeTool), tostring(pumpDir), tostring(allowedToDrive), tostring(vehicle.cp.EifokLiquidManure.searchMapHoseRefStation[pumpDir]), tostring(vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil), tostring(isDone)), 14);
		if vehicle.cp.EifokLiquidManure.searchMapHoseRefStation[pumpDir] and vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil and not isDone then
			courseplay.thirdParty.EifokLiquidManure:findRefillObject(vehicle, activeTool, 'MapHoseRefStation', pumpDir);
		end;
		if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] ~= nil and vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir].type == 'MapHoseRefStation' then
			allowedToDrive = courseplay.thirdParty.EifokLiquidManure:refillViaHose(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, pumpDir);
		end;

		if (vehicle.Waypoints[vehicle.recordnumber].wait or vehicle.Waypoints[vehicle.cp.lastRecordnumber].wait) and vehicle.wait and pumpDir == 'push' then
			if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil and courseplay:timerIsThrough(vehicle, 'findRefillObject') and not (activeTool.fill or activeTool.isReFilling) and not isDone then
				courseplay.thirdParty.EifokLiquidManure:findRefillObject(vehicle, activeTool, 'HoseRefVehicles', pumpDir); --find HoseRef vehicles (transporters and containers)
				if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil then
					courseplay:setCustomTimer(vehicle, 'findRefillObject', 6); --set timer
				end;
			end;
			if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] ~= nil then
				if vehicle.cp.timers.findRefillObject ~= 0 then --reset timer
					vehicle.cp.timers.findRefillObject = 0;
				end;
				allowedToDrive = courseplay.thirdParty.EifokLiquidManure:refillViaHose(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, pumpDir);
			else
				return false, allowedToDrive, lx, lz; --regular liquidManure / ManureLager trigger, handle as usual [PUSH]
			end;

		elseif pumpDir == 'pull' and vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] == nil then
			if not (vehicle.recordnumber >= vehicle.cp.waitPoints[1] - 4 and vehicle.recordnumber <= vehicle.cp.waitPoints[1] + 3) then
				allowedToDrive = courseplay.thirdParty.EifokLiquidManure:refillAtLiquidManureTrigger(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt);
				--return false, allowedToDrive, lx, lz; ----regular liquidManure / ManureLager trigger, handle as usual [pull]
			end;
		end;

		return true, allowedToDrive, lx, lz;

	--Kotte Garant Profi VQ 32000 [Güllepack v2 / bayerbua]
	elseif activeTool.cp.isKotteGARANTProfiVQ32000 and #activeTool.cp.feldbinders > 0 then
		local hasFeldbinderOrStation = false;
		for _,v in pairs(activeTool.cp.feldbinders) do
			local tanker = g_currentMission.attachables[v]
			local moveDone = false
			if tanker.manschetteDrawLine and (activeTool.cp.tankerId == 0 or activeTool.cp.tankerId == v) then
				if tanker.fillerArm.vehicle == activeTool then
					hasFeldbinderOrStation = true;
					activeTool.cp.tankerId = v
					local tx,ty,tz = getWorldTranslation(tanker.manschetteNode1);
					local fdx, _, _ = worldToLocal(activeTool.rootNode,tx,ty,tz);
					if fdx < 0 then -- is the tanker on the valid side ?
						local vx, vy, vz = getWorldTranslation(tanker.fillerArm.fillerArmNode);
						local fx, fy, fz = worldToLocal(tanker.manschetteNode1,vx,vy,vz);
						local offsetX = 3.1  --will be read out of the Feldbinder in future
						local tx,ty,tz = localToWorld(tanker.manschetteNode1,offsetX,0,fz+10)
						drawDebugPoint(tx,ty+3,tz, 1, 0 , 1, 1);
						lx, lz = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode,tx,ty,tz);
						fz = -fz
						if fz > 15 then
							if self.lastSpeedReal > 20/3600 then
								if allowedToDrive then
									allowedToDrive = courseplay:brakeToStop(self)
								end;
							else
								self.cp.maxFieldSpeed = 10/3600
							end
						elseif fz > 0.1 then
							self.cp.maxFieldSpeed = 5/3600
						else   -- fill up
							allowedToDrive = false
							if fillLevelPct < driveOn then
								if not activeTool.manschetteInRange then
									local done = courseplay:moveSingleTool(self,activeTool, 9, 0,0,1.2180819906372, dt)
									if done then
										if not activeTool.cp.moveArmBackward then
											activeTool.cp.moveArmBackward = courseplay:moveSingleTool(self,activeTool, 11, math.rad(10),0,0, dt) and courseplay:moveSingleTool(self,activeTool, 12, -math.rad(10),0,0, dt)
										else
											local movedone = courseplay:moveSingleTool(self,activeTool, 11, -math.rad(10),0,0, dt) and courseplay:moveSingleTool(self,activeTool, 12, math.rad(10),0,0, dt)
											if movedone then
												activeTool.cp.moveArmBackward = false
											end
										end
									end
								end
							end
							if activeTool.fillerArmReadyToOverload then
								activeTool.fillerArmOverloadActive = true
							end
						end
					end
					if fillLevelPct >= driveOn then
						moveDone = courseplay:moveSingleTool(self,activeTool, 9, 0,0,0, dt)
						courseplay:moveSingleTool(self,activeTool, 11, 0,0,0, dt)
						courseplay:moveSingleTool(self,activeTool, 12, 0,0,0, dt)
						if moveDone then
							activeTool.cp.moveArmBackward = false
							self.cp.maxFieldSpeed = 0
							allowedToDrive = true
						end
					end
					break;
				end
			elseif activeTool.cp.tankerId == v then
				activeTool.cp.tankerId = 0
			end
		end
		return hasFeldbinderOrStation, allowedToDrive,lx,lz;
	end



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


-------------------------
-- EIFOK LIQUID MANURE --
-------------------------
function courseplay.thirdParty.EifokLiquidManure:findRefillObject(vehicle, activeTool, where, pumpDir)
	-- self = courseplay.thirdParty.EifokLiquidManure
	-- where: 'MapHoseRefStation' / 'HoseRefVehicles'
	-- pumpDir: 'push' / 'pull'

	local startPoint, endPoint = 1, vehicle.maxnumber;
	if vehicle.cp.mode == 4 then
		if where == 'MapHoseRefStation' then
			startPoint, endPoint = vehicle.cp.stopWork, vehicle.maxnumber;
		else
			startPoint, endPoint = vehicle.recordnumber - 5, vehicle.recordnumber;
		end;
	elseif vehicle.cp.mode == 8 then
		if where == 'MapHoseRefStation' then
			startPoint, endPoint = 1, vehicle.maxnumber;
		else
			startPoint, endPoint = vehicle.recordnumber - 5, vehicle.recordnumber;
		end;
	end;

	courseplay:debug(string.format('%s: findRefillObject(%s) (%s) START', nameNum(activeTool), where, pumpDir), 14);
	local maxDistance = 5.2;
	local targetObject, targetObjectType, closestWaypoint, closestDistance, side, targetConnSide = nil, nil, nil, math.huge, nil, nil;

	local mapHoseRefStationsExist = MapHoseRefStation ~= nil and MapHoseRefStation.MapHoseRefStation ~= nil and #MapHoseRefStation.MapHoseRefStation.stations > 0;

	--MapHoseRefStations
	if where == 'MapHoseRefStation' then
		if mapHoseRefStationsExist then
			local targetRefillObject = vehicle.cp.EifokLiquidManure.targetRefillObject;

			for i,station in pairs(MapHoseRefStation.MapHoseRefStation.stations) do
				local skipStation = (pumpDir == 'push' and targetRefillObject.pull ~= nil and targetRefillObject.pull.object == station) or (pumpDir == 'pull' and targetRefillObject.push ~= nil and targetRefillObject.push.object == station); --don't refill from the same station/vehicle you've already filled
				if station.worldTranslation == nil then
					local srX,srY,srZ = getWorldTranslation(station.ref1);
					station.worldTranslation = { x=srX; y=srY; z=srZ; };
				end;
				if skipStation then --TODO (Jakob): don't break here, instead use "if not skipStation then"
					break;
				end;
				local srX,srY,srZ = station.worldTranslation.x,station.worldTranslation.y,station.worldTranslation.z;
				for n=startPoint, endPoint do
					local wp = vehicle.Waypoints[n];
					local dist = Utils.vector2Length(wp.cx-srX, wp.cz-srZ);
					local inWaitingPointArea = courseplay:waypointsHaveAttr(vehicle, n, -2, 3, 'wait', true, false);
					local skipWP = (pumpDir == 'pull' and inWaitingPointArea) or (pumpDir == 'push' and not inWaitingPointArea); 
					-- courseplay:debug(string.format('\twaypoint %d - skipWP=%s, dist=%.3f/maxDist=%.1f, closestDist=%.3f', n, tostring(skipWP), dist, maxDistance, closestDistance), 14);
					if not skipWP and dist < maxDistance and dist < closestDistance then
						closestWaypoint = n;
						closestDistance = dist;
						targetObject = station;
						targetObjectType = 'MapHoseRefStation';

						--set side relative to course/vehicle --TODO: use directions
						local angleToRefNormal = courseplay.utils.normalizeAngle(math.deg(Utils.getYRotationFromDirection(srX - wp.cx, srZ - wp.cz)));
						local wpAngleNormal = courseplay.utils.normalizeAngle(wp.angle);
						local angleDiffNormal = courseplay.utils.normalizeAngle(wpAngleNormal - angleToRefNormal);
						if angleDiffNormal > 180 then
							side = 'left';
						else
							side = 'right';
						end;
						courseplay:debug(string.format('\t\t[MAPHOSEREFSTATION] set waypoint %d - dist=%.3f/maxDist=%.1f, closestDist=%.3f, wpAngleNormal=%.3f, angleToRefNormal=%.3f, angleDiffNormal=%.3f, side=%s', n, dist, maxDistance, closestDistance, wpAngleNormal, angleToRefNormal, angleDiffNormal, side), 14);
						break;
					end;
				end; --END for waypoints
				if targetObject ~= nil then
					break;
				end;
			end; --END for MapHoseRefStations
		end; --END mapHoseRefStationsExist
		if targetObject == nil then
			vehicle.cp.EifokLiquidManure.searchMapHoseRefStation[pumpDir] = false;
		end;

	-- Transporters & containers
	elseif where == 'HoseRefVehicles' then
		local vehiclesExist = table.maxn(self.hoseRefVehicles) > 0;

		if targetObject == nil and vehiclesExist then
			for vehRootNode,hoseRefVehicle in pairs(self.hoseRefVehicles) do
				if hoseRefVehicle ~= nil and hoseRefVehicle ~= activeTool then
					if hoseRefVehicle.cp.hoseRefs == nil then --first time: set cp.hoseRefs
						self:setCustomHoseRefs(hoseRefVehicle)
					end;

					local attVeh = hoseRefVehicle:getRootAttacherVehicle();
					local hoseRefVehicleValid = attVeh == nil or (not attVeh.drive or (attVeh.Waypoints[attVeh.cp.lastRecordnumber].wait and attVeh.wait));

					if hoseRefVehicleValid then
						for connSide,connRef in pairs(activeTool.cp.hoseRefs.conn) do --my conns
							local x,y,z = getWorldTranslation(connRef.node);
							for targetConnectSide,targetConnectRef in pairs(hoseRefVehicle.cp.hoseRefs.conn) do --hoseRefVehicle's conns
								local crX,crY,crZ = getWorldTranslation(targetConnectRef.node);
								local dist = Utils.vector3Length(x-crX,y-crY,z-crZ);
								if dist < maxDistance and dist < closestDistance and ((pumpDir == 'pull' and hoseRefVehicle.fillLevel > 0) or (pumpDir == 'push' and hoseRefVehicle.fillLevel < hoseRefVehicle.capacity)) then
									closestWaypoint = nil;
									closestDistance = dist;
									targetObject = hoseRefVehicle;
									targetObjectType = 'HoseRefTransporter';
									side = connSide;
									targetConnSide = targetConnectSide;
									courseplay:debug(string.format('\t\t[HoseRefTransporter] set targetObject %q (rootNode=%s) - closestDist=%.3f, side=%s, targetConnSide=%s', nameNum(hoseRefVehicle), tostring(hoseRefVehicle.rootNode), closestDistance, side, targetConnSide), 14);
								end;
							end;
						end;
						if targetObject ~= nil then
							break;
						end;
					end; --END if hoseRefVehicleValid
				end; --END if hoseRefVehicle ~= nil
			end; --END for i,hoseRefVehicle in pairs(self.hoseRefVehicles) do
		end; --END if targetObject == nil and vehiclesExist then
	end; --END if where == 'MapHoseRefStation'/'HoseRefVehicles'

	if targetObject == nil then
		vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] = nil;
		courseplay:debug(string.format('%s: findRefillObject(%s) (%s) END - targetObject == nil', nameNum(activeTool), tostring(where), tostring(pumpDir)), 14);
	else
		vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] = {
			object = targetObject;
			type = targetObjectType;
			closestWaypoint = closestWaypoint;
			side = side;
			targetConnSide = targetConnSide;
		};
		courseplay:debug(string.format('%s: findRefillObject(%s) (%s) END - targetObjectType=%s, closestWaypoint=%s, closestDistance=%.3f, side=%s, targetConnSide=%s', nameNum(activeTool), tostring(where), tostring(pumpDir), tostring(targetObjectType), tostring(closestWaypoint), closestDistance, tostring(side), tostring(targetConnSide)), 14);
	end;
end;
function courseplay.thirdParty.EifokLiquidManure:refillViaHose(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, pumpDir)
	-- self = courseplay.thirdParty.EifokLiquidManure

	--courseplay:debug(string.format("\t%s refillViaHose() start - allowedToDrive==%s", nameNum(activeTool), tostring(allowedToDrive)), 14);
	if vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir] ~= nil then --object found
		local targetRefillObject = vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir];
		local object, type, closestWaypoint, side, targetConnSide = targetRefillObject.object, targetRefillObject.type, targetRefillObject.closestWaypoint, targetRefillObject.side, targetRefillObject.targetConnSide;

		local objectIsFull =  object.fillLevel ~= nil and object.capacity ~= nil and object.fillLevel >= object.capacity;
		local objectIsEmpty = object.fillLevel ~= nil and object.fillLevel == 0;
		local iAmFull =  fillLevelPct >= driveOn;
		local iAmEmpty = fillLevelPct == 0;

		local isDone = iAmFull or objectIsEmpty;
		if pumpDir == "push" then
			isDone = iAmEmpty or (objectIsFull and fillLevelPct < vehicle.cp.followAtFillLevel);
			--courseplay:debug(string.format("%s: isDone=%s, fillLevelPct=%.1f, objectIsFull=%s (%s/%s), followAtFillLevel=%d", nameNum(activeTool), tostring(isDone), fillLevelPct, tostring(objectIsFull), tostring(object.fillLevel), tostring(object.capacity), vehicle.cp.followAtFillLevel), 14);
		end;

		local proceedWithFilling = false;
		if type == "MapHoseRefStation" and closestWaypoint ~= nil then
			if vehicle.recordnumber >= closestWaypoint - 1 and vehicle.recordnumber <= closestWaypoint + 4 then
				--SLOW DOWN
				if not isDone then 
					if vehicle.lastSpeedReal > 15/3600 then
						if allowedToDrive then
							allowedToDrive = courseplay:brakeToStop(vehicle);
						end;
					elseif vehicle.lastSpeedReal > 5/3600 then
						vehicle.cp.maxFieldSpeed = 5/3600;
					end;
				end;

				if vehicle.recordnumber >= closestWaypoint then
					proceedWithFilling = true;
				end;

			elseif vehicle.recordnumber > closestWaypoint + 6 then
				proceedWithFilling = false;
			end;

		elseif type == "HoseRefTransporter" then
			proceedWithFilling = true;
		end; --END if type == "MapHoseRefStation"/"HoseRefTransporter"

		if proceedWithFilling then
			if vehicle.cp.EifokLiquidManure.sId1 == nil and vehicle.cp.EifokLiquidManure.sId2 == nil then
				vehicle.cp.EifokLiquidManure.sId1,vehicle.cp.EifokLiquidManure.sId2 = 1, 2; --NOTE: sId1 is always at activeTool, sId2 is always at object. Their values (1, 2) can switch, though.
			end;

			local vehicleConnectionRef = activeTool.cp.hoseRefs.conn[side];
			if vehicleConnectionRef == nil then
				vehicle.cp.infoText = string.format("no connection ref found on %s side", side);
				return true, false, lx, lz;
			end;

			--CHOOSE TRAILER'S SIDE REF
			local checkOrder = {
				right = { "right", "left" };
				left = { "left", "right" };
			};
			local correctSideRef = activeTool.cp.hoseRefs.park[checkOrder[side][1]];
			local otherSideRef =   activeTool.cp.hoseRefs.park[checkOrder[side][2]];
			if correctSideRef == nil and otherSideRef ~= nil then --only one park ref exists
				correctSideRef = otherSideRef;
			elseif correctSideRef ~= nil and otherSideRef == nil then
				otherSideRef = correctSideRef;
			end;

			--FIND HOSE TO USE
			self:findHoseToUse(vehicle, activeTool, object, correctSideRef, otherSideRef, checkOrder, side, pumpDir);

			if vehicle.cp.EifokLiquidManure.hoseToUse == nil then
				courseplay:setGlobalInfoText(vehicle, 'HOSE_MISSING');
				return false;

			--GO FOR GLORY
			else
				allowedToDrive = self:connectRefillDisconnect(vehicle, activeTool, allowedToDrive, vehicleConnectionRef, correctSideRef, driveOn, isDone, pumpDir);
			end;
		end; --END if proceedWithFilling
	end;

	--courseplay:debug(string.format("\t%s refillViaHose() end - allowedToDrive==%s", nameNum(activeTool), tostring(allowedToDrive)), 14);
	return allowedToDrive;
end;
function courseplay.thirdParty.EifokLiquidManure:findHoseToUse(vehicle, activeTool, object, correctSideRef, otherSideRef, checkOrder, side, pumpDir) --TODO: delete checkOrder, side from variables, as they're only needed for debug
	-- self = courseplay.thirdParty.EifokLiquidManure

	if vehicle.cp.EifokLiquidManure.hoseToUse == nil and vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir].type == "MapHoseRefStation" and object.isUsed then
		local sId1,sId2 = vehicle.cp.EifokLiquidManure.sId1,vehicle.cp.EifokLiquidManure.sId2;
		for i,hose in pairs(courseplay.thirdParty.EifokLiquidManure.hoses) do
			if (hose.ctors[sId1].isAttached and hose.ctors[sId1].station == object and not hose.ctors[sId2].isAttached) then
				vehicle.cp.EifokLiquidManure.hoseToUse = hose;
				vehicle.cp.EifokLiquidManure.sId1,vehicle.cp.EifokLiquidManure.sId2 = sId1, sId2;
				vehicle.cp.EifokLiquidManure.leaveHoseAtStation = true;
				courseplay:debug(string.format("\t%s: hose attached to station, set hose, sId1=%d, sId2=%d", nameNum(activeTool), vehicle.cp.EifokLiquidManure.sId1, vehicle.cp.EifokLiquidManure.sId2), 14);
				break;
			elseif (hose.ctors[sId2].isAttached and hose.ctors[sId2].station == object and not hose.ctors[sId1].isAttached) then
				vehicle.cp.EifokLiquidManure.hoseToUse = hose;
				vehicle.cp.EifokLiquidManure.sId1,vehicle.cp.EifokLiquidManure.sId2 = sId2, sId1;
				vehicle.cp.EifokLiquidManure.leaveHoseAtStation = true;
				courseplay:debug(string.format("\t%s: hose attached to station, set hose, sId1=%d, sId2=%d", nameNum(activeTool), vehicle.cp.EifokLiquidManure.sId1, vehicle.cp.EifokLiquidManure.sId2), 14);
				break;
			end;
		end;
	end;

	if vehicle.cp.EifokLiquidManure.hoseToUse == nil then
		if correctSideRef.isUsed and correctSideRef.hose ~= nil then
			vehicle.cp.EifokLiquidManure.hoseToUse = correctSideRef.hose;
			courseplay:debug(string.format("\t%s: [side %s] hoseToUse is hose at park.%s ref (correct side)", nameNum(activeTool), side, checkOrder[side][1]), 14);
		elseif otherSideRef.isUsed and otherSideRef.hose ~= nil then
			vehicle.cp.EifokLiquidManure.hoseToUse = otherSideRef.hose;
			courseplay:debug(string.format("\t%s: [side %s] hoseToUse is hose at park.%s ref (other side)", nameNum(activeTool), side, checkOrder[side][2]), 14);
		end;
	end;
end;
function courseplay.thirdParty.EifokLiquidManure:connectRefillDisconnect(vehicle, activeTool, allowedToDrive, vehicleConnectionRef, correctSideRef, driveOn, isDone, pumpDir)
	-- self = courseplay.thirdParty.EifokLiquidManure

	--courseplay:debug(string.format("\t%s connectRefillDisconnect() start - allowedToDrive==%s", nameNum(activeTool), tostring(allowedToDrive)), 14);
	local targetRefillObject = vehicle.cp.EifokLiquidManure.targetRefillObject[pumpDir];
	local object, type, closestWaypoint, side, targetConnSide = targetRefillObject.object, targetRefillObject.type, targetRefillObject.closestWaypoint, targetRefillObject.side, targetRefillObject.targetConnSide;

	local hose = vehicle.cp.EifokLiquidManure.hoseToUse;
	local sId1,sId2 = vehicle.cp.EifokLiquidManure.sId1,vehicle.cp.EifokLiquidManure.sId2;
	local hoseTargetType = "veh";
	local maxConnectionDistance = 3.9;
	if hose.hoseLength ~= nil then
		maxConnectionDistance = hose.hoseLength * 0.9;
	end;
	local vehConnX,vehConnY,vehConnZ = getWorldTranslation(vehicleConnectionRef.node);
	local distVehConnToOtherConn = 0;
	local tx,ty,tz;
	if type == "MapHoseRefStation" then
		tx,ty,tz = object.worldTranslation.x, object.worldTranslation.y, object.worldTranslation.z;
		hoseTargetType = "station";
	elseif type == "HoseRefTransporter" then
		tx,ty,tz = getWorldTranslation(object.cp.hoseRefs.conn[targetConnSide].node);
	end;
	distVehConnToOtherConn = Utils.vector3Length(vehConnX - tx, vehConnY - ty, vehConnZ - tz);

	if distVehConnToOtherConn <= maxConnectionDistance then
		local tmpAllowedToDrive = false;

		if not isDone then
			--DETACH HOSE FROM PARK
			if hose.ctors[sId1].isAttached and hose.ctors[sId1].veh == activeTool --[[and activeTool.hoseRef.refs[hose.ctors[sId1].refId].rt == "park"]] then --connected to vehicle (park)
				courseplay:debug(string.format("\t%s: distVehConnToOtherConn=%.3f/%.3f, allowedToDrive=false", nameNum(activeTool), distVehConnToOtherConn, maxConnectionDistance), 14);
				--courseplay:debug(string.format("\t\those.ctors[%d].isAttached=%s, hose.ctors[%d].isAttached=%s", sId1, tostring(hose.ctors[sId1].isAttached), sId2, tostring(hose.ctors[sId2].isAttached)), 14);
				hose:setRelease(hose.ctors[sId1].veh, sId1, hose.ctors[sId1].refId); --WORKS
				courseplay:debug(string.format("\t\those:setRelease(hose.ctors[%d].veh, %d, %d) [DETACH HOSE FROM PARK]", sId1, sId1, hose.ctors[sId1].refId), 14);
			end;

			--CONNECT HOSE TO OBJECT
			if not hose.ctors[sId1].isAttached and not hose.ctors[sId2].isAttached then --not connected to anything
				if type == "MapHoseRefStation" then
					hose:setAttachStation(object, sId1); --WORKS
					courseplay:debug(string.format("\t\those:setAttachStation(object, %d) [CONNECT HOSE TO STATION]", sId1), 14);
				else
					hose:setAttach(object, sId1, object.cp.hoseRefs.conn[targetConnSide].id);
					courseplay:debug(string.format("\t\those:setAttach(object, %d, %d) [CONNECT HOSE TO HOSEREFVEHICLE]", sId1, object.cp.hoseRefs.conn[targetConnSide].id), 14);
				end;
			end;
			
			--CONNECT HOSE TO ACTIVETOOL
			if hose.ctors[sId1][hoseTargetType] == object and not hose.ctors[sId2].isAttached then --connected to object
				hose:setAttach(activeTool, sId2, vehicleConnectionRef.id); --WORKS
				courseplay:debug(string.format("\t\those:setAttach(activeTool, %d, %d) [CONNECT HOSE TO ACTIVETOOL]", sId2, vehicleConnectionRef.id), 14);
			end;

			--START FILL
			if hose.ctors[sId1][hoseTargetType] == object and hose.ctors[sId2].veh == activeTool and not isDone then --connected to object and vehicle (conn)
				local pumpDirNum = 1;
				local objectIsReady = (object.fillLevel or 1) > 0;
				if pumpDir == "push" then
					pumpDirNum = -1;
					objectIsReady = (object.fillLevel or 0) < (object.capacity or 1);
				end;
				
				if objectIsReady and activeTool.pumpDir ~= pumpDirNum then
					courseplay:debug(string.format("\t\tobject.fillLevel=%s, object.capacity=%s, activeTool.pumpDir=%s -> activeTool:setPumpDir(%d) [START FILL]", tostring(object.fillLevel), tostring(object.capacity), tostring(activeTool.pumpDir), pumpDirNum), 14);
					activeTool:setPumpDir(pumpDirNum); --WORKS
				end;
			end;
		end; --END not isDone

		--STOP FILL
		if isDone then
			if courseplay.debugChannels[14] then
				local objectIsFull  = object.fillLevel ~= nil and object.capacity ~= nil and object.fillLevel >= object.capacity;
				local objectIsEmpty = object.fillLevel ~= nil and object.fillLevel == 0;
				local iAmFull  = 100 * activeTool.fillLevel/activeTool.capacity >= driveOn;
				local iAmEmpty = activeTool.fillLevel == 0;
				if pumpDir == "push" then
					courseplay:debug(string.format("\t%s isDone=true, iAmEmpty=%s, objectIsFull=%s -> call stopAndDisconnect()", nameNum(activeTool), tostring(iAmEmpty), tostring(objectIsFull)), 14);
				else
					courseplay:debug(string.format("\t%s isDone=true, iAmFull=%s, objectIsEmpty=%s -> call stopAndDisconnect()", nameNum(activeTool), tostring(iAmFull), tostring(objectIsEmpty)), 14);
				end;
			end;
			self:stopAndDisconnect(vehicle, activeTool, hoseTargetType, object, hose, correctSideRef);

			--ALLOW DRIVING
			if (vehicle.cp.EifokLiquidManure.leaveHoseAtStation and hose.ctors[sId1][hoseTargetType] == object and hose.ctors[sId2].veh == 0) or (not vehicle.cp.EifokLiquidManure.leaveHoseAtStation and hose.ctors[sId1].isAttached and hose.ctors[sId1].veh == activeTool) then --disconnected from connRef OR connected to vehicle (park)
				self:resetData(vehicle, pumpDir, pumpDir, false);
				tmpAllowedToDrive = true;
			end;
		end; --END isDone

		if not tmpAllowedToDrive then
			allowedToDrive = false;
			--courseplay:debug(string.format("\t%s tmpAllowedToDrive==false --> allowedToDrive=false", nameNum(activeTool)), 14);
		end;
	end; --END distVehConnToOtherConn <= maxConnectionDistance

	--courseplay:debug(string.format("\t%s connectRefillDisconnect() end - allowedToDrive==%s", nameNum(activeTool), tostring(allowedToDrive)), 14);
	return allowedToDrive;
end;
function courseplay.thirdParty.EifokLiquidManure:stopAndDisconnect(vehicle, activeTool, hoseTargetType, object, hose, correctSideRef)
	-- self = courseplay.thirdParty.EifokLiquidManure

	local sId1,sId2 = vehicle.cp.EifokLiquidManure.sId1,vehicle.cp.EifokLiquidManure.sId2;

	if hose.ctors[sId1][hoseTargetType] == object and hose.ctors[sId2].veh == activeTool then 
		if activeTool.pumpDir ~= 0 then --still filling
			activeTool:setPumpDir(0); --WORKS
			courseplay:debug(string.format("\t\tactiveTool:setPumpDir(0) [STOP FILL]"), 14);
		end;

		--DETACH HOSE FROM ACTIVETOOL
		if activeTool.pumpDir == 0 then --filling stopped
			hose:setRelease(hose.ctors[sId2].veh, sId2, hose.ctors[sId2].refId); --WORKS
			courseplay:debug(string.format("\t\those:setRelease(hose.ctors[%d].veh, %d, hose.ctors[%d].refId) [DETACH HOSE FROM ACTIVETOOL (conn)]", sId2, sId2, sId2), 14);
		end;
	end;

	if not vehicle.cp.EifokLiquidManure.leaveHoseAtStation then
		--DETACH HOSE FROM OBJECT
		if hose.ctors[sId1][hoseTargetType] == object and hose.ctors[sId2].veh == 0 and not hose.ctors[sId2].isAttached then
			local refId = hose.ctors[sId1].refId;
			if hoseTargetType == "station" then
				refId = 0;
			end;
			hose:setRelease(hose.ctors[sId1][hoseTargetType], sId1, refId); --WORKS
			courseplay:debug(string.format("\t\those:setRelease(hose.ctors[%d].%s, %d, %d) [DETACH HOSE FROM OBJECT]", sId1, hoseTargetType, sId1, refId), 14);
		end;

		--ATTACH HOSE TO ACTIVETOOL (park)
		if not hose.ctors[sId1].isAttached and not hose.ctors[sId2].isAttached then --not connected to anything
			hose:setAttach(activeTool, sId1, correctSideRef.id); --WORKS
			courseplay:debug(string.format("\t\those:setAttach(activeTool, %d, %d) [ATTACH HOSE TO ACTIVETOOL (park)]", sId1, correctSideRef.id), 14);
		end;
	end;
	vehicle.cp.maxFieldSpeed = 0;
	vehicle.cp.fillTrigger = nil;
	courseplay:debug(string.format("\t\tset maxFieldSpeed to 0, fillTrigger set to nil", nameNum(activeTool)), 14);
end;


function courseplay.thirdParty.EifokLiquidManure:refillAtLiquidManureTrigger(vehicle, activeTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt)
	-- self = courseplay.thirdParty.EifokLiquidManure

	--in front on trigger
	if vehicle.cp.fillTrigger ~= nil then
		local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
		if courseplay:fillTypesMatch(trigger, activeTool) then 
			vehicle.cp.isInFilltrigger = true;
		end;
	end;

	--NOTE: fillArm center (when extended) is 2.26m left and 3.428m front of the rootNode, and 0.768m above ground --> docking station needs to be 2.816m left and 3.428m front of Zunhammer rootNode

	--in trigger
	--Default liquidManureFillTrigger
	local trigger = activeTool.lastSprayerFillTrigger or activeTool.sprayerFillTriggers[1];
	local fillTypesMatch = courseplay:fillTypesMatch(trigger, activeTool);
	if trigger ~= nil and trigger.vehiclesInRange ~= nil and trigger.vehiclesInRange[activeTool] and fillTypesMatch then
		if activeTool.cp.isHoseRefSprayer and activeTool.fillarm and activeTool.fillarm.anim then
			local fillArmAnim = activeTool.fillarm.anim;
			local fillArmIsClosed = fillArmAnim.curTime == 0;
			local fillArmIsOpen = activeTool.fillarm.bIsOpen;
			if fillLevelPct < driveOn then --stop, extend arm and fill
				allowedToDrive = false;
				if not fillArmIsOpen then --if arm is not fully extended
					local fillArmAnimNewTime = math.min(fillArmAnim.curTime + dt*fillArmAnim.speed, fillArmAnim.duration);
					activeTool:setFillarm(fillArmAnimNewTime);
				else
					activeTool:setIsSprayerFilling(true, false);
					vehicle.cp.infoText = string.format(courseplay:loc("COURSEPLAY_LOADING_AMOUNT"), vehicle.cp.tipperFillLevel, vehicle.cp.tipperCapacity);
				end;
			elseif fillLevelPct >= driveOn then
				activeTool:setIsSprayerFilling(false, false);
				vehicle.cp.fillTrigger = nil;
				if not fillArmIsClosed then
					allowedToDrive = false;
					local fillArmAnimNewTime = math.max(fillArmAnim.curTime - dt*fillArmAnim.speed, 0);
					activeTool:setFillarm(fillArmAnimNewTime);
				end;
			end;

		elseif activeTool.cp.isHoseRefTransporter then --Kotte Zubringer
			if fillLevelPct < driveOn then
				allowedToDrive = false;
				activeTool:setIsSprayerFilling(true, false);
				vehicle.cp.infoText = string.format(courseplay:loc("COURSEPLAY_LOADING_AMOUNT"), vehicle.cp.tipperFillLevel, vehicle.cp.tipperCapacity);
			elseif fillLevelPct >= driveOn then
				activeTool:setIsSprayerFilling(false, false);
				vehicle.cp.fillTrigger = nil;
			end;
		end;
	end;
	return allowedToDrive;
end;

function courseplay.thirdParty.EifokLiquidManure:setCustomHoseRefs(workTool)
	-- self = courseplay.thirdParty.EifokLiquidManure

	if workTool.hoseRef == nil or workTool.cp.hoseRefs ~= nil then return; end;

	workTool.cp.hoseRefs = {
		conn = {};
		park = {};
		dock = {};
	};
	for i,ref in pairs(workTool.hoseRef.refs) do
		local refX, refY, refZ = getWorldTranslation(ref.node);
		local rootNodeToRefX,_,_ = worldToLocal(workTool.rootNode, refX, refY, refZ);
		if rootNodeToRefX >= 0 and workTool.cp.hoseRefs[ref.rt].left == nil then
			workTool.cp.hoseRefs[ref.rt].left = ref;
		elseif rootNodeToRefX < 0 and workTool.cp.hoseRefs[ref.rt].right == nil then
			workTool.cp.hoseRefs[ref.rt].right = ref;
		end;
	end;
end;
function courseplay.thirdParty.EifokLiquidManure:resetData(vehicle, targetObjectDir, searchDir, hasZunhammer)
	-- self = courseplay.thirdParty.EifokLiquidManure

	vehicle.cp.EifokLiquidManure.hoseToUse = nil;
	vehicle.cp.EifokLiquidManure.sId1, vehicle.cp.EifokLiquidManure.sId2 = nil, nil;
	vehicle.cp.EifokLiquidManure.leaveHoseAtStation = false;

	if courseplay:nilOrBool(hasZunhammer, true) then
		vehicle.cp.hasEifokZunhammer18500PU = false;
	end;

	if targetObjectDir ~= nil and targetObjectDir ~= false then
		vehicle.cp.EifokLiquidManure.targetRefillObject[targetObjectDir] = nil;
	elseif targetObjectDir == nil then
		vehicle.cp.EifokLiquidManure.targetRefillObject.pull = nil;
		vehicle.cp.EifokLiquidManure.targetRefillObject.push = nil;
	end;

	if searchDir ~= nil and searchDir ~= false then
		vehicle.cp.EifokLiquidManure.searchMapHoseRefStation[searchDir] = true;
	elseif searchDir == nil then
		vehicle.cp.EifokLiquidManure.searchMapHoseRefStation.pull = true;
		vehicle.cp.EifokLiquidManure.searchMapHoseRefStation.push = true;
	end;
end;

function courseplay.thirdParty.JD864PremiumOpenRearDoor(workTool, open, forceState)
	local dir = open and 1 or -1;
	local targetAnimTime = open and 1 or 0;
	local curAnimTime = workTool:getAnimationTime(workTool.doors.rear.animation);
	local animIsPlaying = workTool:getIsAnimationPlaying(workTool.doors.rear.animation);

	if not animIsPlaying and curAnimTime ~= targetAnimTime and workTool.doors.rear.isOpen ~= open then
		workTool:playAnimation(workTool.doors.rear.animation, dir, nil);
	end;
	if curAnimTime == targetAnimTime or forceState then
		workTool.doors.rear.isOpen = open;
		workTool:raiseDirtyFlags(workTool.doors.rear.dirtyFlag);
	end;
end;
