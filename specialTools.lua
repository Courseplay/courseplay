function courseplay:setNameVariable(workTool)
	--print("	base: CPloading: "..tostring(workTool.name))
	if workTool.cp == nil then
		workTool.cp = {};
	end;
	--replace cyclic Utils scanning
	workTool.cp.hasSpecializationSteerable = (SpecializationUtil.hasSpecialization(Steerable, workTool.specializations) or SpecializationUtil.hasSpecialization(steerable, workTool.specializations))
	workTool.cp.hasSpecializationCombine = SpecializationUtil.hasSpecialization(Combine, workTool.specializations)
	workTool.cp.hasSpecializationAICombine = SpecializationUtil.hasSpecialization(AICombine, workTool.specializations)
	workTool.cp.hasSpecializationAITractor = SpecializationUtil.hasSpecialization(AITractor, workTool.specializations)
	workTool.cp.hasSpecializationSprayer = SpecializationUtil.hasSpecialization(Sprayer, workTool.specializations) or SpecializationUtil.hasSpecialization(sprayer, workTool.specializations)
	workTool.cp.hasSpecializationFoldable = SpecializationUtil.hasSpecialization(Foldable, workTool.specializations) or SpecializationUtil.hasSpecialization(foldable, workTool.specializations)
	workTool.cp.hasSpecializationMower = SpecializationUtil.hasSpecialization(Mower, workTool.specializations)
	workTool.cp.hasSpecializationMixerWagon = SpecializationUtil.hasSpecialization(MixerWagon, workTool.specializations)
	workTool.cp.hasSpecializationCylindered = SpecializationUtil.hasSpecialization(Cylindered, workTool.specializations)
	workTool.cp.hasSpecializationAnimatedVehicle =  SpecializationUtil.hasSpecialization(AnimatedVehicle, workTool.specializations)
	workTool.cp.hasSpecializationShovel = SpecializationUtil.hasSpecialization(Shovel, workTool.specializations)
	workTool.cp.hasSpecializationBunkerSiloCompacter = SpecializationUtil.hasSpecialization(BunkerSiloCompacter, workTool.specializations)
	workTool.cp.hasSpecializationTedder = SpecializationUtil.hasSpecialization(Tedder, workTool.specializations) 
	workTool.cp.hasSpecializationWindrower = SpecializationUtil.hasSpecialization(Windrower, workTool.specializations) 
	workTool.cp.hasSpecializationCultivator = SpecializationUtil.hasSpecialization(Cultivator, workTool.specializations)
	workTool.cp.hasSpecializationFruitPreparer = SpecializationUtil.hasSpecialization(FruitPreparer, workTool.specializations) or SpecializationUtil.hasSpecialization(fruitPreparer, workTool.specializations)
	--[[ Debugs:
	if workTool.cp.hasSpecializationFruitPreparer then print("		FruitPreparer")end
	if workTool.cp.hasSpecializationTedder then print("		Tedder")end
	if workTool.cp.hasSpecializationWindrower then print("		Windrower")end
	if workTool.cp.hasSpecializationCultivator then print("		Cultivator")end
	if workTool.cp.hasSpecializationBunkerSiloCompacter then print("		BunkerSiloCompacter")end
	if workTool.cp.hasSpecializationShovel then print("		Shovel")end
	if workTool.cp.hasSpecializationAnimatedVehicle then print("		AnimatedVehicle")end
	if workTool.cp.hasSpecializationCylindered then print("		Cylindered")end
	if workTool.cp.hasSpecializationMixerWagon then print("		MixerWagon")end
	if workTool.cp.hasSpecializationMower then print("		Mower")end
	if workTool.cp.hasSpecializationFoldable then print("		Foldable")end
	if workTool.cp.hasSpecializationSprayer then print("		Sprayer")end
	if workTool.cp.hasSpecializationAITractor then print("		AITractor")end
	if workTool.cp.hasSpecializationAICombine then print("		AICombine")end
	if workTool.cp.hasSpecializationCombine then print("		Combine")end
	if workTool.cp.hasSpecializationSteerable then print("		Steerable")end
	]]
	--Mchale998 bale wrapper [Bergwout]
	if Utils.endsWith(workTool.configFileName, "Mchale998.xml") then
		workTool.cp.isMchale998 = true

	--Rolmasz S061 "Pomorzanin" [Maciusboss1 & Burner]
	elseif Utils.endsWith(workTool.configFileName, "S061.xml") and workTool.setTramlinesOn ~= nil and workTool.leftMarkerRope ~= nil and workTool.leftMarkerSpeedRotatingParts ~= nil then
		workTool.cp.isRolmaszS061 = true;

	--Universal Bale Trailer (UBT)
	elseif workTool.numAttacherParts ~= nil and workTool.autoLoad ~= nil and workTool.loadingIsActive ~= nil and workTool.unloadLeft ~= nil and workTool.unloadRight ~= nil and workTool.unloadBack ~= nil and workTool.typeOnTrailer ~= nil and workTool.fillLevelMax ~= nil then
		workTool.cp.isUBT = true;

	--Guellepack v2 [Bayerbua]
	elseif workTool.fillerArmInRange ~= nil  then
		workTool.cp.isFeldbinder = true
	elseif Utils.endsWith(workTool.configFileName, "KotteGARANTProfiVQ32000.xml") and workTool.fillerArmNode ~= nil then
		workTool.cp.isKotteGARANTProfiVQ32000 = true

	--Urf-Specialisation
	elseif workTool.sprayFillLevel ~= nil and workTool.sprayCapacity ~= nil then
		workTool.cp.hasUrfSpec = true

	--Silage shields
	elseif Utils.endsWith(workTool.configFileName, "holaras.xml") then
		workTool.cp.isSilageShield = true
	elseif Utils.endsWith(workTool.configFileName, "Stegemann.xml") then
		workTool.cp.isSilageShield = true

	--Abbey Sprayer Pack [FS-UK Modteam]
	elseif Utils.endsWith(workTool.configFileName, "Abbey_AP900.xml") then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbeyAP900 = true;
	elseif Utils.endsWith(workTool.configFileName, "Abbey_3000R.xml") then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbey3000R = true;
	elseif Utils.endsWith(workTool.configFileName, "Abbey_2000R.xml") then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbey2000R = true;
	elseif Utils.endsWith(workTool.configFileName, "Abbey_3000_Nurse.xml") then
		workTool.cp.isAbbeySprayerPack = true;
		workTool.cp.isAbbey3000Nurse = true;

	--JF-Stoll 1060 [NI Modding]
	elseif Utils.endsWith(workTool.configFileName, "JF_1060.xml") then
		workTool.cp.isJF1060 = true;

	--Kverneland Mower Pack [NI Modding]
	elseif Utils.endsWith(workTool.configFileName, "Kverneland_4028.xml") then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKverneland4028 = true;
	elseif Utils.endsWith(workTool.configFileName, "Kverneland_4028_AS.xml") then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKverneland4028AS = true;
	elseif Utils.endsWith(workTool.configFileName, "Kverneland_KD240.xml") then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKvernelandKD240 = true;
	elseif Utils.endsWith(workTool.configFileName, "Kverneland_KD240F.xml") then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKvernelandKD240F = true;
	elseif Utils.endsWith(workTool.configFileName, "Taarup_3532F.xml") then
		workTool.cp.isKvernelandMowerPack = true;
		workTool.cp.isKverneland3532F = true;

	--Taarup Mower Pack [NI Modding]
	elseif Utils.endsWith(workTool.configFileName, "Taarup_5090.xml") then
		workTool.cp.isTaarupMowerPack = true;
		workTool.cp.isTaarup5090 = true;

	--Poettinger Alpha/X8 Mower Pack [Eifok Team]
	elseif Utils.endsWith(workTool.configFileName, "PoettingerAlpha.xml") then
		workTool.cp.isPoettingerAlphaX8MowerPack = true;
		workTool.cp.isPoettingerAlpha = true;
	elseif Utils.endsWith(workTool.configFileName, "PoettingerX8.xml") then
		workTool.cp.isPoettingerAlphaX8MowerPack = true;
		workTool.cp.isPoettingerX8 = true;

	--Claas Quadrant 1200 [Eifok Team]
	elseif Utils.endsWith(workTool.configFileName, "Claas_Quadrant_1200.xml") then
		workTool.cp.isClaasQuadrant1200 = true;

	--Claas Liner 4000 [LS-Landtechnik & Fuqsbow-Team]
	elseif Utils.endsWith(workTool.configFileName, "liner4000.xml") then
		workTool.cp.isClaasLiner4000 = true;

	--Ursus Z586 bale wrapper [Giants]
	elseif Utils.endsWith(workTool.configFileName, "ursusZ586.xml") then
		workTool.cp.isUrsusZ586 = true;

	--Tebbe HS180 [Stefan Maurus]
	elseif Utils.endsWith(workTool.configFileName, "TebbeHS180.xml") then
		workTool.cp.isTebbeHS180 = true;

	--Fuchs liquid manure trailer [Stefan Maurus]
	elseif Utils.endsWith(workTool.configFileName, "FuchsGuellefass.xml") and workTool.isFuchsFass then
		workTool.cp.isFuchsLiquidManure = true;

	--Claas Conspeed [SFM]
	elseif Utils.endsWith(workTool.configFileName, "claasConspeed.xml") then
		workTool.cp.isClaasConspeedSFM = true;

	--Poettinger Mex 6 [Giants]
	elseif Utils.endsWith(workTool.configFileName, "poettingerMex6.xml") then
		workTool.cp.isPoettingerMex6 = true;

	--Sugarbeet Loaders [burner]
	elseif Utils.endsWith(workTool.configFileName, "RopaEuroMaus.xml") then
		workTool.cp.isRopaEuroMaus = true;
	elseif Utils.endsWith(workTool.configFileName, "HolmerTerraFelis.xml") then
		workTool.cp.isHolmerTerraFelis = true;
	elseif Utils.endsWith(workTool.configFileName, "RopaNawaRoMaus.xml") then
		workTool.cp.isRopaNawaRoMaus = true;
	
	--Harvesters (steerable)
	elseif Utils.endsWith(workTool.configFileName, "RopaEuroTiger_V8_3_XL.xml") then
		workTool.cp.isRopaEuroTiger = true;

	--Harvesters (steerable) [Giants]
	elseif Utils.endsWith(workTool.configFileName, "grimmeMaxtron620.xml") then
		workTool.cp.isHarvesterSteerable = true;
		workTool.cp.isGrimmeMaxtron620 = true;
	elseif Utils.endsWith(workTool.configFileName, "grimmeTectron415.xml") then
		workTool.cp.isHarvesterSteerable = true;
		workTool.cp.isGrimmeTectron415 = true;

	--Harvesters (attachable) [Giants]
	elseif Utils.endsWith(workTool.configFileName, "grimmeRootster604.xml") then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeRootster604 = true;
	elseif Utils.endsWith(workTool.configFileName, "grimmeSE75-55.xml") then
		workTool.cp.isHarvesterAttachable = true;
		workTool.cp.isGrimmeSE7555 = true;

	--Combines [Giants]
	elseif Utils.endsWith(workTool.configFileName, "fahrM66.xml") then
		workTool.cp.isFahrM66 = true;

	--Others
	elseif Utils.endsWith(workTool.configFileName, "KirovetsK700A.xml") then
		workTool.cp.isKirovetsK700A = true;
	end;
end;

------------------------------------------------------------------------------------------

function courseplay:isSpecialSprayer(workTool)
	return workTool.cp.isAbbeySprayerPack;
end;

function courseplay:isSpecialChopper(workTool)
	if workTool.cp.isJF1060 then
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
	return workTool.cp.isClaasQuadrant1200;
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
	
	--[[if fileNames ~= nil and table.getn(fileNames) > 0 then
		for i=1, table.getn(fileNames) do
			if Utils.endsWith(workTool.configFileName, fileNames[i] .. ".xml") then
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

	--Mchale998 bale wrapper
	if workTool.cp.isMchale998 then
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
		end;

		if not workTool.autoLoad then
			workTool.autoLoad = true;
		end;
		if workTool.loadingIsActive ~= turnOn then
			workTool.loadingIsActive = turnOn;
		end;

		if unload then
			for i=1, workTool.numAttachers[workTool.typeOnTrailer] do
				if workTool.attacher[workTool.typeOnTrailer][i].attachedObject ~= nil then

					--ORIG: if workTool.ulRef[workTool.ulMode][1] == g_i18n:getText("UNLOAD_TRAILER") then
					if workTool.ulRef[workTool.ulMode][3] == 0 then --verrrrry dirty: unload on trailer
						local x,y,z = getWorldTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
						local rx,ry,rz = getWorldRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
						local root = getRootNode();
						setRigidBodyType(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,"Dynamic");
						setTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,x,y,z);
						setRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,rx,ry,rz);
						link(root,workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
						workTool.attacher[workTool.typeOnTrailer][i].attachedObject = nil;
						workTool.fillLevel = workTool.fillLevel - 1;
					else
						local x,y,z = getWorldTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
						local rx,ry,rz = getWorldRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
						local nx,ny,nz = getWorldTranslation(workTool.attacherLevel[workTool.typeOnTrailer]);
						local tx,ty,tz = getWorldTranslation(workTool.ulRef[workTool.ulMode][3]);
						local x = x + (tx - nx);
						local y = y + (ty - ny);
						local z = z + (tz - nz);
						local tH = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z);
						local relHeight = ny - tH;
						local root = getRootNode();
						setRigidBodyType(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,"Dynamic");
						setTranslation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,x,(y - relHeight),z);
						setRotation(workTool.attacher[workTool.typeOnTrailer][i].attachedObject,rx,ry,rz);
						link(root,workTool.attacher[workTool.typeOnTrailer][i].attachedObject);
						workTool.attacher[workTool.typeOnTrailer][i].attachedObject = nil;
						workTool.fillLevel = workTool.fillLevel - 1;
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
					self.WpOffsetX = 3
				elseif ridgeMarker == 2 then
					workTool.HGdirection = -1;
					self.WpOffsetX = -3
				end
			end
		end

		return false, allowedToDrive

	--Urf-specialisation
	elseif workTool.cp.hasUrfSpec then
		if workTool.sprayFillLevel == 0 and workTool.isFertilizing > 1 then
			self.cp.urfStop = true
		end
		return false, allowedToDrive

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

	--Claas Quadrant 1200
	elseif workTool.cp.isClaasQuadrant1200 then
		if unfold ~= nil and turnOn ~= nil and lower ~= nil then
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

			--speed regulation
			if workTool.isBlocked then 
				allowedToDrive = false
			end
			workTool.blockMaxTime = 10000
			if workTool.actLoad2 == 1 then
				if workTool.blockTimer > workTool.blockMaxTime *0.8 then
					self.cp.maxFieldSpeed = 7/3600
					allowedToDrive = false
				end
			end
			if workTool.actLoad_IntSend < 0.8 and not workTool.isBlocked and workTool.actLoad_IntSend ~= 0 then
				self.cp.maxFieldSpeed = self.cp.maxFieldSpeed + 0.02/3600
			end
			if workTool.actLoad_IntSend == 0 and self.cp.maxFieldSpeed == 0 then
				self.cp.maxFieldSpeed = 4/3600
			end
			if workTool.actLoad_IntSend > 0.9 and self.cp.maxFieldSpeed > 1/3600 then
				self.cp.maxFieldSpeed = self.cp.maxFieldSpeed - 0.05/3600
			end
			--speed regulation END

		end
		
		return true ,allowedToDrive

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
		if targetTrailer == nil then
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



	--Tebbe HS180 (Maurus)
	elseif workTool.cp.isTebbeHS180 then
		local flap = 0
		if workTool.setDoorHigh ~= nil and workTool.doorhigh ~= nil then
			if turnOn then 
				flap = 3
			end
			workTool:setDoorHigh(flap);
		end
		if workTool.setFlapOpen ~= nil and workTool.flapopen then
			workTool:setFlapOpen(turnOn)
		end
		return false, allowedToDrive


	--Fuchsfass
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
function courseplay:askForSpecialSettings(self,object)
	
	if self.cp.isKirovetsK700A then
		self.cp.DirectionNode = self.rootNode
		self.cp.isKasi = 2.5
	elseif self.cp.isRopaEuroTiger then
		self:setSteeringMode(5)
		self.cp.offset = 5.2
		self.cp.noStopOnTurn = true
		self.cp.noStopOnEdge = true
	end;
	
	if object.cp.isMchale998 then
		self.cp.aiTurnNoBackward = true
		self.cp.noStopOnEdge = true
		self.cp.noStopOnTurn = true
		self.WpOffsetX = -2.4
		object.cp.inversedFoldDirection = true

	elseif object.cp.isKotteGARANTProfiVQ32000 then
		object.cp.feldbinders = {}
		for i=1, table.getn(g_currentMission.attachables) do
			if g_currentMission.attachables[i].fillerArmInRange ~= nil then
				table.insert(object.cp.feldbinders,i)
			end
		end
		object.cp.crabSteerMode = object.crabSteerMode
		object.cp.tankerId = 0
	elseif object.cp.isGrimmeSE7555 then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -2.1
		print("Grimme SE 75-55 workwidth: 1 m");
	elseif object.cp.isGrimmeRootster604 then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -0.9
		print("Grimme Rootster 604 workwidth: 2.8 m");
	elseif object.cp.isPoettingerMex6 then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -2.5
		print("Pöttinger Mex 6 workwidth: 2.0 m");
	elseif object.cp.isAbbeyAP900 then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -4.1
		print("Abbey AP900 workwidth: 5.8 m");
	elseif object.cp.isJF1060 then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -2.5
	elseif object.cp.isClaasConspeedSFM then
		object.cp.inversedFoldDirection = true;
	elseif object.cp.isUrsusZ586 then
		self.cp.aiTurnNoBackward = true
		self.cp.noStopOnEdge = true
		self.cp.noStopOnTurn = true
		self.WpOffsetX = -2.5
	elseif object.cp.isSilageShield then
		self.cp.hasShield = true
	end

end

function courseplay:handleSpecialSprayer(self,activeTool, fill_level, driveOn, allowedToDrive,lx,lz)

	if activeTool.cp.isKotteGARANTProfiVQ32000 and #activeTool.cp.feldbinders > 0 then
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
								courseplay:brakeToStop(self)
							else
								self.cp.maxFieldSpeed = 10/3600
							end
						elseif fz > 0.1 then
							self.cp.maxFieldSpeed = 5/3600
						else   -- fill up
							allowedToDrive = false
							if fill_level < 100 then
								if not activeTool.manschetteInRange then
									local done = courseplay:moveSingleTool(self,activeTool, 9, 0,0,1.2180819906372)
									if done then
										if not activeTool.cp.moveArmBackward then
											activeTool.cp.moveArmBackward = courseplay:moveSingleTool(self,activeTool, 11, math.rad(10),0,0) and courseplay:moveSingleTool(self,activeTool, 12, -math.rad(10),0,0)
										else
											local movedone = courseplay:moveSingleTool(self,activeTool, 11, -math.rad(10),0,0) and courseplay:moveSingleTool(self,activeTool, 12, math.rad(10),0,0)
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
					if fill_level == 100 then
						moveDone = courseplay:moveSingleTool(self,activeTool, 9, 0,0,0)
						courseplay:moveSingleTool(self,activeTool, 11, 0,0,0)
						courseplay:moveSingleTool(self,activeTool, 12, 0,0,0)
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

function courseplay:moveSingleTool(self,activeTool, toolIndex,x,y,z)
	--local toolRot = activeTool.movingTools[9].curRot[3]
	local tool = activeTool.movingTools[toolIndex];
	local rotSpeed = 0.0033;
	local targetRot = {x,y,z}
	local done = true
	if tool.rotSpeed ~= nil then
		rotSpeed = tool.rotSpeed * 60;
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
				Cylindered.setDirty(self, tool);
				self:raiseDirtyFlags(self.cylinderedDirtyFlag);
				changed = true;
			end;
		end;
	end;
	return done

end

