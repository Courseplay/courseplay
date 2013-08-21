function courseplay:setNameVariable(workTool)
	if workTool.cp == nil then
		workTool.cp = {};
	end;

	--Urf-Specialisation
	if workTool.sprayFillLevel ~= nil and workTool.sprayCapacity ~= nil then
		workTool.cp.hasUrfSpec = true

	-- Holaras Silage shield
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
end


function courseplay:isSpecialCombine(workTool, specialType, fileNames)
	if specialType ~= nil then
		if specialType == "sugarBeetLoader" then
			if (workTool.cp.isRopaEuroMaus or workTool.cp.isHolmerTerraFelis) and workTool.unloadingTrigger ~= nil and workTool.unloadingTrigger.node ~= nil then
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


function courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
	local implementsDown = lower and turnOn
	if workTool.PTOId then
		workTool:setPTO(false)
	end


	--RopaEuroTiger
	if self.cp.isRopaEuroTiger then
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
	end

	--Urf-specialisation
	if workTool.cp.hasUrfSpec then
		if workTool.sprayFillLevel == 0 then
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

	if object.cp.isGrimmeSE7555 then
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

