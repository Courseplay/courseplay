
function courseplay:isSpecialSprayer(workTool)
	return	Utils.endsWith(workTool.configFileName, "Abbey_AP900.xml") 
		or Utils.endsWith(workTool.configFileName, "Abbey_3000R.xml") 
		or Utils.endsWith(workTool.configFileName, "Abbey_2000R.xml")
		or Utils.endsWith(workTool.configFileName, "Abbey_3000_Nurse.xml")
end;

function courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
	--Abbey 3000 NurseTanker
	if Utils.endsWith(workTool.configFileName, "Abbey_3000_Nurse.xml") then
		if workTool.PTOId then
			workTool:setPTO(false)
		end
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
					fillable.attacherVehicle.cp.stopForLoading = true
					if fillable.fillLevel >= fillable.capacity  or workTool.fillLevel <= 5 then
						workTool:setIsTurnedOn(false)
						fillable.attacherVehicle.cp.stopForLoading = false
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
	elseif Utils.endsWith(workTool.configFileName, "Abbey_3000R.xml") or Utils.endsWith(workTool.configFileName, "Abbey_2000R.xml") then
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
			local spray = lower and turnOn
			if workTool.setIsTurnedOn ~= nil and not workTool.isTurnedOn then
				workTool:setIsTurnedOn(spray, false);
			end
			if workTool.setIsTurnedOn ~= nil and workTool.isTurnedOn and not spray then
				workTool:setIsTurnedOn(spray, false);
			end
		end

		return true, allowedToDrive

	--Abbey AP900  workwith 5.8m offset-4,1m
	elseif Utils.endsWith(workTool.configFileName, "Abbey_AP900.xml")	then
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
	elseif Utils.endsWith(workTool.configFileName, "liner4000.xml") then
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
	elseif Utils.endsWith(workTool.configFileName, "TebbeHS180.xml") then
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
	elseif workTool.isFuchsFass and workTool.setdeckelAnimationisPlaying ~= nil then
		if cover ~= nil then
			workTool:setdeckelAnimationisPlaying(cover);
		end
		return false, allowedToDrive

	--Poettinger Alpha
	elseif workTool.alpMot ~= nil and workTool.setTurnedOn ~= nil and workTool.setLiftUp ~= nil and workTool.setTransport ~= nil then
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
	elseif workTool.x8 ~= nil and workTool.x8.mowers ~= nil and workTool.setTurnedOn ~= nil and workTool.setLiftUp ~= nil and workTool.setTransport ~= nil and workTool.setSelection ~= nil then
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
	
	if Utils.endsWith(object.configFileName, "grimmeSE75-55.xml") then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -2.1
		print("Grimme SE 75-55 workwidth: 0.7 m");
	elseif Utils.endsWith(object.configFileName, "grimmeRootster604.xml") then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -0.9
		print("Grimme Rootster 604 workwidth: 2.8 m");
	elseif Utils.endsWith(object.configFileName, "poettingerMex6.xml") then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -2.5
		print("Pöttinger Mex 6 workwidth: 2.0 m");
	elseif Utils.endsWith(object.configFileName, "Abbey_AP900.xml") then
		self.cp.aiTurnNoBackward = true
		self.WpOffsetX = -4.1
		print("Abbey AP900 workwidth: 5.8 m");
	end

end

function courseplay:isSpecialCombine(workTool, specialType, fileNames)
	if specialType ~= nil then
		if specialType == "sugarBeetLoader" then
			if Utils.endsWith(workTool.configFileName, "RopaEuroMaus.xml") or Utils.endsWith(workTool.configFileName, "HolmerTerraFelis.xml") then
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
	
	if fileNames ~= nil and table.getn(fileNames) > 0 then
		local returnTrueFalse = false;
		for i=1, table.getn(fileNames) do
			if Utils.endsWith(workTool.configFileName, fileNames[i] .. ".xml") then
				returnTrueFalse = true;
				break;
			end;
		end;
		return returnTrueFalse;
	end;
	
	return Utils.endsWith(workTool.configFileName, "JF_1060.xml") or courseplay:isSpecialCombine(workTool, "sugarBeetLoader");
end;