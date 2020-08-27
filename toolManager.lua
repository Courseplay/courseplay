local abs, cos, sin, min, max, deg = math.abs, math.cos, math.sin, math.min, math.max, math.deg;
local _;
-- ##### MANAGING TOOLS ##### --
function courseplay:attachImplement(implement) 
	-- Update Vehicle
	if implement.className ~= 'RailroadVehicle' then
		if implement ~= nil then
			local attacherVehicle = implement:getAttacherVehicle()
			if attacherVehicle.spec_aiVehicle then 
				attacherVehicle.cp.tooIsDirty = true; 
			end;
			
			if attacherVehicle.getAttacherVehicle then
				local firstAttacherVehicle =  attacherVehicle:getAttacherVehicle()
				if firstAttacherVehicle~= nil and firstAttacherVehicle.spec_aiVehicle then
					firstAttacherVehicle.cp.tooIsDirty = true; 
				end;				
			end
		end
		courseplay:setAttachedCombine(self);
	end
end;

AttacherJoints.attachImplement = Utils.appendedFunction(AttacherJoints.attachImplement, courseplay.attachImplement);

function courseplay:onPostDetachImplement(implementIndex)
	--- Update Vehicle
	self.cp.tooIsDirty = true;
	local sAI= self:getAttachedImplements()
	if sAI[implementIndex].object == self.cp.attachedCombine then
		self.cp.attachedCombine = nil;
	end
end;

function courseplay:resetTools(vehicle)
	vehicle.cp.workTools = {}
	-- are there any tippers?
	vehicle.cp.hasAugerWagon = false;
	vehicle.cp.hasSugarCaneAugerWagon = false;
	vehicle.cp.hasSugarCaneTrailer = false
	vehicle.cp.hasFertilizerSowingMachine = nil;
	vehicle.cp.workToolAttached = courseplay:updateWorkTools(vehicle, vehicle);
	if not vehicle.cp.workToolAttached then
		courseplay:setCpMode(vehicle, courseplay.MODE_TRANSPORT)
	end
	-- Ryan prints fillTypeManager table. Nice cause it prints out all the fillTypes print_r(g_fillTypeManager)
	-- Reset fill type.
	--[[
	if #vehicle.cp.workTools > 0 and vehicle.cp.workTools[1].cp.hasSpecializationFillable and vehicle.cp.workTools[1].allowFillFromAir and vehicle.cp.workTools[1].allowTipDischarge then
		if vehicle.cp.siloSelectedFillType ==  FillType.UNKNOWN or (vehicle.cp.siloSelectedFillType ~=  FillType.UNKNOWN and not vehicle.cp.workTools[1]:allowFillType(vehicle.cp.siloSelectedFillType)) then
			vehicle.cp.siloSelectedFillType = vehicle.cp.workTools[1]:getFirstEnabledFillType();
			print("toolManager(41): setting siloSelectedFillType to "..tostring(vehicle.cp.siloSelectedFillType))
		end;
	else
		vehicle.cp.siloSelectedFillType =  FillType.UNKNOWN;
		print("toolManager(45): setting siloSelectedFillType to "..tostring(vehicle.cp.siloSelectedFillType))
	end;]]
	

	courseplay.hud:setReloadPageOrder(vehicle, -1, true);
	
	courseplay:calculateWorkWidth(vehicle, true);
	
	vehicle.cp.currentTrailerToFill = nil;
	vehicle.cp.trailerFillDistance = nil;
	vehicle.cp.tooIsDirty = false;
end;

function courseplay:getAvailableFillTypes(object, fillUnitIndex)
	-- We really should be using getFillUnitSupportedFillTypes(fillUnitIndex) TODO Make a loop to go through it. 
	if fillUnitIndex == nil then
		local fillTypes = {}
		if object.spec_fillUnit then
			for fillUnitIndex, fillUnit in ipairs(object:getFillUnits()) do
				for fillType, enabled in pairs(object:getFillUnitSupportedFillTypes(fillUnitIndex)) do
					if fillType ~= g_fillTypeManager.UNKNOWN and enabled then
						fillTypes[fillType] = enabled;
					end;
				end;
			end;
		end;
		return fillTypes
	end
	return object:getFillUnitSupportedFillTypes(fillUnitIndex)
	-- Old Stuff incase the above method doesn't work like old
	--[[ if fillUnitIndex == nil then
		local fillTypes = {}
		if object.fillUnits then
			for _, fillUnit in pairs(object.fillUnits) do
				for fillType, enabled in pairs(fillUnit.fillTypes) do
					if fillType ~= FillType.UNKNOWN and enabled then
						fillTypes[fillType] = enabled;
					end;
				end;
			end;
		end;
	end; ]]
end;

--TODO Tommi Remove if not used anymore
function courseplay:getAllAvailableFillTypes(vehicle)
	local fillTypes = {};
	if #vehicle.cp.workTools > 0 then
	    for _, workTool in pairs(vehicle.cp.workTools) do
			local toolFillTypes = courseplay:getAvailableFillTypes(workTool);
			for fillType, enabled in pairs(toolFillTypes) do
				if fillType ~= FillType.UNKNOWN and enabled then
					fillTypes[fillType] = enabled;
				end;
			end
		end;
	end;
	return fillTypes;
end;



function courseplay:getEasyFillTypeList(vehicle)
	local easyFillTypeList = {};
	local fillUnitHasMoreFillTypes = false
	local filltypes ={}
	local tempList = {}
	if #vehicle.cp.workTools > 0 then
		for _, workTool in pairs(vehicle.cp.workTools) do
			if workTool.spec_fillUnit then
				local fillUnits = workTool:getFillUnits()
				for i=1,#fillUnits do
					fillUnitHasMoreFillTypes, filltypes = courseplay:getFillUnitHasMoreFillTypes(workTool,i)
					if fillUnitHasMoreFillTypes then
						for index,fillType in pairs(filltypes) do
							if not tempList[fillType] then
								tempList[fillType] = true;
							end	
						end
					end
				end
			end
		end
	end

	for FillType,_ in pairs (tempList) do
		table.insert(easyFillTypeList,FillType)
	end

	return easyFillTypeList;
end;

function courseplay:getFillUnitHasMoreFillTypes(workTool, index)
	local unitsFillTypes = workTool:getFillUnitSupportedFillTypes(index)
	local counter = 0
	local fillTypesList = {}
	for fillType,enabled in pairs(unitsFillTypes) do
		counter = counter+1;
		table.insert(fillTypesList, fillType)
	end
	if counter > 1 then
		return true,fillTypesList;
	else
		return false
	end
end

function courseplay:isAttachedCombine(workTool)
	return (workTool.typeName~= nil and (workTool.typeName == 'attachableCombine' or workTool.typeName == 'attachableCombine_mouseControlled')) 
			or (not workTool.cp.hasSpecializationDrivable and workTool.hasPipe and not workTool.cp.isAugerWagon and not workTool.cp.isLiquidManureOverloader)
			or courseplay:isSpecialChopper(workTool)
			or workTool.cp.isAttachedCombine
end;
function courseplay:isAttachedMixer(workTool)
	return workTool.typeName == "mixerWagon" or (not workTool.cp.hasSpecializationDrivable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isAttacherModule(workTool)
	if workTool.spec_attacherJoints.attacherJoint then
		local workToolsWheels = workTool:getWheels();
		return (workTool.spec_attacherJoints.attacherJoint.jointType == AttacherJoints.JOINTTYPE_SEMITRAILER and (not workToolsWheels or (workToolsWheels and #workToolsWheels == 0))) or workTool.cp.isAttacherModule == true;
	end;
	return false;
end;
function courseplay:isBaleLoader(workTool) -- is the tool a bale loader?
	return workTool.cp.hasSpecializationBaleLoader or (workTool.balesToLoad ~= nil and workTool.baleGrabber ~=nil and workTool.grabberIsMoving~= nil);
end;
function courseplay:isBaler(workTool) -- is the tool a baler?
	return workTool.cp.hasSpecializationBaler or workTool.balerUnloadingState ~= nil or courseplay:isSpecialBaler(workTool);
end;
function courseplay:isCombine(workTool)
	return workTool.cp.hasSpecializationCombine and workTool.startThreshing ~= nil and workTool.cp.capacity ~= nil  and workTool.cp.capacity > 0;
end;
function courseplay:isChopper(workTool)
	return workTool.cp.hasSpecializationCombine and workTool.startThreshing ~= nil and workTool:getFillUnitCapacity(workTool.spec_combine.fillUnitIndex) > 10000000 or courseplay:isSpecialChopper(workTool);
end;
function courseplay:isFoldable(workTool) --is the tool foldable?
	return workTool.cp.hasSpecializationFoldable and  workTool.spec_foldable.foldingParts ~= nil and #workTool.spec_foldable.foldingParts > 0;
end;
function courseplay:isFrontloader(workTool)
    return Utils.getNoNil(workTool.typeName == "attachableFrontloader", false);
end;
function courseplay:isHarvesterSteerable(workTool)
	return Utils.getNoNil(workTool.typeName == "selfPropelledPotatoHarvester" or workTool.cp.isHarvesterSteerable, false);
end;
function courseplay:isHarvesterAttachable(workTool)
	return Utils.getNoNil(workTool.cp.isHarvesterAttachable, false);
end;
function courseplay:isHookLift(workTool)
	if workTool.spec_attacherJoints.attacherJoint then
		return workTool.spec_attacherJoints.attacherJoint.jointType == AttacherJoints.JOINTTYPE_HOOKLIFT;
	end;
	return false;
end
function courseplay:isMixer(workTool)
	return workTool.typeName == "selfPropelledMixerWagon" or (workTool.cp.hasSpecializationDrivable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isMower(workTool)
	return workTool.cp.hasSpecializationMower or courseplay:isSpecialMower(workTool);
end;
function courseplay:isRoundbaler(workTool) -- is the tool a roundbaler?
	return courseplay:isBaler(workTool) and workTool.spec_baler ~= nil and (workTool.spec_baler.baleCloseAnimationName ~= nil and workTool.spec_baler.baleUnloadAnimationName ~= nil or courseplay:isSpecialRoundBaler(workTool));
end;
function courseplay:isSowingMachine(workTool) -- is the tool a sowing machine?
	return workTool.cp.hasSpecializationSowingMachine or courseplay:isSpecialSowingMachine(workTool);
end;
function courseplay:isSpecialChopper(workTool)
	return workTool.typeName == "woodCrusherTrailer" or workTool.cp.isPoettingerMex5 or workTool.cp.isTraileredChopper
end
function courseplay:isSprayer(workTool) -- is the tool a sprayer/spreader?
	return workTool.cp.hasSpecializationSprayer or courseplay:isSpecialSprayer(workTool)
end;
function courseplay:isWheelloader(workTool)
	return workTool.typeName:match("wheelLoader");
end;
function courseplay:hasShovel(workTool)
	if workTool.cp.hasSpecializationShovel then
		return true
	end
end
function courseplay:hasLeveler(workTool) 
	if workTool.cp.hasSpecializationLeveler then	
		return true
	end
end

function courseplay:hasBunkerSiloCompacter(workTool)
	if workTool.cp.hasSpecializationBunkerSiloCompacter then	
		return true
	end
end
function courseplay:isTrailer(workTool)
	return workTool.typeName:match("trailer");
end;

-- UPDATE WORKTOOL DATA
function courseplay:updateWorkTools(vehicle, workTool, isImplement)
	if not isImplement then
		cpPrintLine(6, 3);
		courseplay:debug(('%s: updateWorkTools(%s, %q, isImplement=false) (mode=%d)'):format(nameNum(vehicle),tostring(vehicle.name), nameNum(workTool), vehicle.cp.mode), 6);
	else
		cpPrintLine(6);
		courseplay:debug(('%s: updateWorkTools(%s, %q, isImplement=true)'):format(nameNum(vehicle),tostring(vehicle.name), nameNum(workTool)), 6);
	end;

	-- Reset distances if in debug mode 6.
	if courseplay.debugChannels[6] ~= nil and courseplay.debugChannels[6] == true then
		workTool.cp.distances = nil;
	end;

	courseplay:setNameVariable(workTool);
	courseplay:setOwnFillLevelsAndCapacities(workTool,vehicle.cp.mode)
	local hasWorkTool = false;
	local hasWaterTrailer = false
	-- MODE 1 + 2: GRAIN TRANSPORT / COMBI MODE
	if vehicle.cp.mode == 1 or vehicle.cp.mode == 2 then
		if SpecializationUtil.hasSpecialization(Dischargeable, workTool.specializations) and (SpecializationUtil.hasSpecialization(Trailer, workTool.specializations) or SpecializationUtil.hasSpecialization(FillTriggerVehicle, workTool.specializations)) and workTool.cp.capacity and workTool.cp.capacity > 0.1 and not  SpecializationUtil.hasSpecialization(Pipe, workTool.specializations) then
			if vehicle.cp.mode == 2 and SpecializationUtil.hasSpecialization(Trailer, workTool.specializations) or vehicle.cp.mode == 1 then 
				hasWorkTool = true;
				vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			end
		end; 
	-- MODE 3: AUGERWAGON
	elseif vehicle.cp.mode == 3 then
		if workTool.cp.isAugerWagon then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end

	-- MODE 4: FERTILIZER AND SEEDING
	elseif vehicle.cp.mode == 4 then
		local isSprayer, isSowingMachine = courseplay:isSprayer(workTool), courseplay:isSowingMachine(workTool);
		if isSprayer or isSowingMachine or workTool.cp.isTreePlanter or workTool.cp.isKuhnDC401 or workTool.cp.isKuhnHR4004 then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			courseplay:setMarkers(vehicle, workTool)
			vehicle.cp.hasMachinetoFill = true;
			vehicle.cp.noStopOnEdge = isSprayer and not (isSowingMachine or workTool.cp.isTreePlanter);
			vehicle.cp.noStopOnTurn = isSprayer and not (isSowingMachine or workTool.cp.isTreePlanter);
			if isSprayer then
				vehicle.cp.hasSprayer = true;
			end;
			if isSowingMachine then
				vehicle.cp.hasSowingMachine = true;
			end;
		end;

	-- MODE 5: TRANSFER
	elseif vehicle.cp.mode == 5 then
		-- For reversing purpose
		if isImplement then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end;
		-- DO NOTHING

	-- MODE 6: FIELDWORK
	elseif vehicle.cp.mode == 6 then
		if (courseplay:isBaler(workTool) 
		or courseplay:isBaleLoader(workTool) 
		or courseplay:isSpecialBaleLoader(workTool) 
		or workTool.cp.hasSpecializationCultivator
		or courseplay:isCombine(workTool)
		or workTool.cp.hasSpecializationFruitPreparer 
		or workTool.cp.hasSpecializationPlow
		or workTool.cp.hasSpecializationTedder
		or workTool.cp.hasSpecializationWindrower
		or workTool.cp.hasSpecializationCutter
		or workTool.cp.hasSpecializationWeeder
		or workTool.spec_dischargeable
		or courseplay:isMower(workTool)
		or courseplay:isAttachedCombine(workTool) 
		or courseplay:isFoldable(workTool))
		and not courseplay:isSprayer(workTool)
		and not (courseplay:isSowingMachine(workTool) and not workTool.cp.hasSpecializationWeeder)
		then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			courseplay:setMarkers(vehicle, workTool);
			vehicle.cp.noStopOnTurn = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or workTool.cp.hasSpecializationCutter;
			vehicle.cp.noStopOnEdge = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or workTool.cp.hasSpecializationCutter;
			if workTool.cp.hasSpecializationPlow then
				vehicle.cp.hasPlow = true;
				if workTool.spec_plow.rotationPart.turnAnimation ~= nil then
					vehicle.cp.rotateablePlow = workTool;
				end;
			end;
			if courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) then
				vehicle.cp.hasBaleLoader = true;
				if vehicle.cp.lastValidTipDistance == nil then
					vehicle.cp.lastValidTipDistance = 0
				end;
			end;
			if courseplay:isHarvesterAttachable(workTool) then
				vehicle.cp.hasHarvesterAttachable = true;
			end;
			if courseplay:isSpecialChopper(workTool) then
				vehicle.cp.hasSpecialChopper = true;
			end;
		end;

	-- MODE 8: Field Supply
	elseif vehicle.cp.mode == 8 then
		if SpecializationUtil.hasSpecialization(FillTriggerVehicle, workTool.specializations) or SpecializationUtil.hasSpecialization(Pipe, workTool.specializations) and SpecializationUtil.hasSpecialization(Trailer, workTool.specializations) then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end;

	-- MODE 9: FILL AND EMPTY SHOVEL
	elseif vehicle.cp.mode == 9 then
		if not isImplement and (courseplay:isWheelloader(workTool) or workTool.typeName == 'frontloader' or courseplay:isMixer(workTool)) then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			workTool.cp.shovelState = 1;

		elseif isImplement and (courseplay:isFrontloader(workTool) or workTool.cp.hasSpecializationShovel) then 
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			workTool.spec_attachable.attacherVehicle.cp.shovelState = 1
		end;
	-- MODE 10:Leveler
	elseif vehicle.cp.mode == 10 then
		if isImplement and (workTool.cp.hasSpecializationLeveler or workTool.cp.hasSpecializationBunkerSiloCompacter) then 
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end;
	end;
	
	--belongs to mode4 but should be considered even if the mode is not set correctely
	if workTool.spec_sprayer ~= nil and workTool.spec_sowingMachine ~= nil then
				vehicle.cp.hasFertilizerSowingMachine = true;
	end
	
	--belongs to mode3 but should be considered even if the mode is not set correctely
	if workTool.cp.isAugerWagon then
		vehicle.cp.hasAugerWagon = true;
		if workTool.cp.isSugarCaneAugerWagon then
			vehicle.cp.hasSugarCaneAugerWagon = true
		end
	end;
	if workTool.cp.isSugarCaneTrailer then
		vehicle.cp.hasSugarCaneTrailer = true
	end
	
	vehicle.cp.hasWaterTrailer = hasWaterTrailer
	
	if hasWorkTool then
		courseplay:debug(('%s: workTool %q added to workTools (index %d)'):format(nameNum(vehicle), nameNum(workTool), #vehicle.cp.workTools), 6);
	end;

	--------------------------------------------------

	if not isImplement or hasWorkTool or workTool.cp.isNonTippersHandledWorkTool then
		-- SPECIAL SETTINGS
		courseplay:askForSpecialSettings(vehicle, workTool);

		--FOLDING PARTS: isFolded/isUnfolded states
		courseplay:setFoldedStates(workTool);
	end;

	-- REVERSE PROPERTIES
	courseplay:getReverseProperties(vehicle, workTool);

	-- aiTurnNoBackward
	if isImplement and hasWorkTool then
		if not vehicle.cp.aiTurnNoBackward and workTool.cp.notToBeReversed then
			vehicle.cp.aiTurnNoBackward = true;
			courseplay:debug(('%s: workTool.cp.notToBeReversed == true --> vehicle.cp.aiTurnNoBackward = true'):format(nameNum(workTool)), 6);
		end;
	end;

	-- TRAFFIC COLLISION IGNORE LIST
	courseplay:debug(('%s: adding %q (%q) to cpTrafficCollisionIgnoreList'):format(nameNum(vehicle), nameNum(workTool), tostring(workTool.cp.xmlFileName)), 3);
	vehicle.cpTrafficCollisionIgnoreList[workTool.rootNode] = true;
	-- TRAFFIC COLLISION IGNORE LIST (components)
	if workTool.components ~= nil then
		courseplay:debug(('%s: adding %q (%q) components to cpTrafficCollisionIgnoreList'):format(nameNum(vehicle), nameNum(workTool), tostring(workTool.cp.xmlFileName)), 3);
		for i,component in pairs(workTool.components) do
			vehicle.cpTrafficCollisionIgnoreList[component.node] = true;
		end;
	end;

	-- CHECK ATTACHED IMPLEMENTS
	for k,impl in pairs(workTool:getAttachedImplements()) do
		local implIsWorkTool = courseplay:updateWorkTools(vehicle, impl.object, true);
		if implIsWorkTool then
			hasWorkTool = true;
		end;
	end;

	-- STEERABLE (vehicle)
	if not isImplement then
		vehicle.cp.numWorkTools = #vehicle.cp.workTools;

		-- list debug
		if courseplay.debugChannels[3] then
			cpPrintLine(6);
			courseplay:debug(('%s cpTrafficCollisionIgnoreList'):format(nameNum(vehicle)), 3);
			for a,b in pairs(vehicle.cpTrafficCollisionIgnoreList) do
        if g_currentMission.nodeToObject[ a ] then
          local name = g_currentMission.nodeToObject[a].name;
          courseplay:debug(('\\___ [%s] = %s (%q)'):format(tostring(a), tostring(name), tostring(getName(a))), 3);
        end
			end;
		end;

		-- TURN DIAMETER
		if g_server ~= nil then
			courseplay:setAutoTurnDiameter(vehicle, hasWorkTool);
		end

		-- TIP REFERENCE POINTS
		courseplay:setTipRefOffset(vehicle);

		-- TIPPER COVERS
		vehicle.cp.tipperHasCover = false;
		vehicle.cp.tippersWithCovers = {};
		if hasWorkTool then
			courseplay:setTipperCoverData(vehicle);
		end;


		-- FINAL WORKTOOLS TABLE DEBUG
		if courseplay.debugChannels[6] then
			cpPrintLine(6);
			if vehicle.cp.numWorkTools > 0 then
				courseplay:debug(('%s: workTools:'):format(nameNum(vehicle)), 6);
				for i=1, vehicle.cp.numWorkTools do
					courseplay:debug(('\\___ [%d] = %s'):format(i, nameNum(vehicle.cp.workTools[i])), 6);
				end;
			else
				courseplay:debug(('%s: no workTools set'):format(nameNum(vehicle)), 6);
			end;
		end;
	end;

	--------------------------------------------------

	if not isImplement then
		cpPrintLine(6, 3);
	end;

	return hasWorkTool;
end;

function courseplay:setTipRefOffset(vehicle)
	vehicle.cp.tipRefOffset = 0;
	for i=1, vehicle.cp.numWorkTools do
		vehicle.cp.workTools[i].cp.rearTipRefPoint = nil;
		if vehicle.cp.hasMachinetoFill then
			vehicle.cp.tipRefOffset = 1.5;
		elseif vehicle.cp.workTools[i].rootNode ~= nil and vehicle.cp.workTools[i].tipReferencePoints ~= nil then
			if  #(vehicle.cp.workTools[i].tipReferencePoints) > 1 then
				for n=1 ,#(vehicle.cp.workTools[i].tipReferencePoints) do
					local tipperX, tipperY, tipperZ = getWorldTranslation(vehicle.cp.workTools[i].tipReferencePoints[n].node);
					local tipRefPointX, tipRefPointY, tipRefPointZ = worldToLocal(vehicle.cp.workTools[i].rootNode, tipperX, tipperY, tipperZ);
					courseplay:debug(string.format("point%s : tipRefPointX (%s), tipRefPointY (%s), tipRefPointZ(%s)",tostring(n),tostring(tipRefPointX),tostring(tipRefPointY),tostring( tipRefPointZ)),13)
					tipRefPointX = abs(tipRefPointX);
					if tipRefPointX > vehicle.cp.tipRefOffset then  
						if tipRefPointX > 0.1 then
							vehicle.cp.tipRefOffset = tipRefPointX;
						else
							vehicle.cp.tipRefOffset = 0
						end;
					end

					-- Find the rear tipRefpoint in case we are BGA tipping.
					if tipRefPointX < 0.1 and tipRefPointZ < 0 then
						if not vehicle.cp.workTools[i].cp.rearTipRefPoint or vehicle.cp.workTools[i].tipReferencePoints[n].width > vehicle.cp.workTools[i].tipReferencePoints[vehicle.cp.workTools[i].cp.rearTipRefPoint].width then
							vehicle.cp.workTools[i].cp.rearTipRefPoint = n;
							courseplay:debug(string.format("%s: Found rear TipRefPoint: %d - tipRefPointZ = %f", nameNum(vehicle), n, tipRefPointZ), 13);
						end;
					end;
				end;
			else
				vehicle.cp.workTools[i].cp.rearTipRefPoint = 1
				vehicle.cp.tipRefOffset = 0;
			end;
		end;
	end;
end;

--- Create two markers (offset distances from the root/direction node of the vehicle):
-- frontMarker: distance of the outermost work area limit from the root/direction node.
-- backMarker: distance of the innermost work area limit from the root/direction node.
function courseplay:setMarkers(vehicle, object)

	if object.cp.attachedCuttersVar ~= nil and not object.cp.hasSpecializationFruitPreparer and not courseplay:isAttachedCombine(object) then
		courseplay.debugVehicle(6, vehicle, 'setMarkers(): %s is a combine -> not setting work areas', tostring(object.name))
		return;
	end

	if object.cp.noWorkArea then
		courseplay.debugVehicle(6, vehicle, 'setMarkers(): %s is special tool configured for no work areas', tostring(object.name))
		return;
	end;

	local realDirectionNode		= AIDriverUtil.getDirectionNode(vehicle)
	local aLittleBitMore 		= 1;
	local pivotJointNode 		= courseplay:getPivotJointNode(object);
	object.cp.backMarkerOffset 	= nil;
	object.cp.aiFrontMarker 	= nil;

	-- Get and set vehicle distances if not set
	local vehicleDistances = vehicle.cp.distances or courseplay:getDistances(vehicle);
	-- Get and set object distances if not set
	local objectDistances = object.cp.distances or courseplay:getDistances(object);

	-- get the behindest and the frontest  points :-) ( as offset to root node)
	 

	local activeInputAttacherJoint = object.getActiveInputAttacherJoint and object:getActiveInputAttacherJoint()
	if not activeInputAttacherJoint then
		courseplay.debugVehicle(6, vehicle, 'setMarkers(): no attacher joints')
		return
	end

	if not courseplay:hasWorkAreas(object) then
		if courseplay:isWheeledWorkTool(object) and activeInputAttacherJoint.jointType and vehicleDistances.turningNodeToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType] then 
			-- Calculate the offset based on the distances
			local ztt = vehicleDistances.turningNodeToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType] * -1;

			local backMarkerCorrection = Utils.getNoNil(object.cp.backMarkerOffsetCorrection, 0);
			if vehicle.cp.backMarkerOffset == nil or (abs(backMarkerCorrection) > 0 and  ztt + backMarkerCorrection > vehicle.cp.backMarkerOffset) then
				vehicle.cp.backMarkerOffset = abs(backMarkerCorrection) > 0 and ztt + backMarkerCorrection or 0;
			end

			local frontMarkerCorrection = Utils.getNoNil(object.cp.frontMarkerOffsetCorrection, 0);
			if vehicle.cp.aiFrontMarker == nil or (abs(frontMarkerCorrection) > 0 and  ztt + frontMarkerCorrection < vehicle.cp.aiFrontMarker) then
				vehicle.cp.aiFrontMarker = abs(frontMarkerCorrection) > 0 and ztt + frontMarkerCorrection or -3;
			end

			courseplay.debugVehicle(6, vehicle, '(%s) setMarkers(), no work area: cp.backMarkerOffset = %s, cp.aiFrontMarker = %s',
				nameNum(object), tostring(vehicle.cp.backMarkerOffset), tostring(vehicle.cp.aiFrontMarker))
		else
			--- Set front and back marker to default values, so we don't check again.
			if vehicle.cp.backMarkerOffset == nil then
				vehicle.cp.backMarkerOffset = 0;
			end
			if vehicle.cp.aiFrontMarker == nil then
				vehicle.cp.aiFrontMarker = -3;
			end
			courseplay:debug(('%s: setMarkers(): %s has no workAreas -> return '):format(nameNum(vehicle), tostring(object.name)), 6);
		end;
		return;
	end

	local backMarkerAreaType, frontMarkerAreaType
	-- TODO: figure out what other types to avoid, the FS17 types ending with DROP do not seem to exist anymore
	local avoidType = {
		[WorkAreaType.RIDGEMARKER] = true
	}
	for k, area in courseplay:workAreaIterator(object) do
		if not avoidType[area.type] then
			for j,node in pairs(area) do
				if j == "start" or j == "height" or j == "width" then
					local x, y, z;
					local ztt = 0;
					local type;

					if pivotJointNode and activeInputAttacherJoint.jointType and vehicleDistances.turningNodeToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType] then 
						type = "Pivot Trailer";
						-- TODO: use localToLocal instead of a getWorldTranslation and a worldToLocal
						x, y, z = getWorldTranslation(pivotJointNode);

						-- Get the marker offset from the pivot node.
						_, _, ztt = worldToLocal(node, x, y, z);

						-- Calculate the offset based on the distances
						 ztt = ((vehicleDistances.turningNodeToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType] + objectDistances.attacherJointToPivot) * -1) - ztt; 

					 elseif courseplay:isWheeledWorkTool(object) and activeInputAttacherJoint.jointType and vehicleDistances.turningNodeToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType] then 
						type = "Trailer";
						x, y, z = getWorldTranslation(activeInputAttacherJoint.node) 

						-- Get the marker offset from the pivot node.
						_, _, ztt = worldToLocal(node, x, y, z);

						-- Calculate the offset based on the distances
						ztt = (vehicleDistances.turningNodeToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType] * -1) - ztt; 

					else
						type = "Vehicle";
						x, y, z = getWorldTranslation(node);
						_, _, ztt = worldToLocal(realDirectionNode, x, y, z);
					end;

					courseplay.debugVehicle(6, vehicle, '%s %s (%s) %s: ztt = %.2f',
						object:getName(), type, g_workAreaTypeManager.workAreaTypes[area.type].name, tostring(j), ztt)
					if object.cp.backMarkerOffset == nil or ztt + Utils.getNoNil(object.cp.backMarkerOffsetCorection, 0) > object.cp.backMarkerOffset then
						object.cp.backMarkerOffset = ztt + Utils.getNoNil(object.cp.backMarkerOffsetCorection, 0);
						backMarkerAreaType = area.type
					end
					if object.cp.aiFrontMarker == nil or ztt + Utils.getNoNil(object.cp.frontMarkerOffsetCorection, 0) < object.cp.aiFrontMarker then
						object.cp.aiFrontMarker = ztt + Utils.getNoNil(object.cp.frontMarkerOffsetCorection, 0);
						frontMarkerAreaType = area.type
					end
				end
			end
		else
			courseplay.debugVehicle(6, vehicle, "Avoiding workArea Type %s", g_workAreaTypeManager.workAreaTypes[area.type].name)
		end;
	end

	if vehicle.cp.backMarkerOffset == nil or object.cp.backMarkerOffset < (vehicle.cp.backMarkerOffset + aLittleBitMore) then
		vehicle.cp.backMarkerOffset = object.cp.backMarkerOffset - aLittleBitMore;
	end

	if vehicle.cp.aiFrontMarker == nil or object.cp.aiFrontMarker > (vehicle.cp.aiFrontMarker - aLittleBitMore) then
		vehicle.cp.aiFrontMarker = object.cp.aiFrontMarker + aLittleBitMore * 0.75;
	end

	-- Sprayers have a rectangular work area but the spray is at an angle so the front of the area is not covered.
	-- Also, some sprayers have multiple work areas depending on the configuration and fill type which can also
	-- move the front or back markers.
	-- This leads to little unsprayed rectangles at the row ends as the turn code turns off the sprayer when the back
	-- marker (which is actually in the front when the implement is attached to the back of the vehicle) reaches the
	-- field edge.
	-- So, if both the front and back markers are from sprayer work areas, move the back marker to where the front
	-- marker is which will result turning off the sprayer later.
	if frontMarkerAreaType and backMarkerAreaType and
		frontMarkerAreaType == WorkAreaType.SPRAYER and
		backMarkerAreaType == WorkAreaType.SPRAYER then
		courseplay.debugVehicle(6, vehicle, "Forcing backmarker to frontmarker for sprayer")
		vehicle.cp.backMarkerOffset = vehicle.cp.aiFrontMarker
	end

	courseplay.debugVehicle(6, vehicle, '(%s), setMarkers(): cp.backMarkerOffset = %s, cp.aiFrontMarker = %s',
		nameNum(object), tostring(vehicle.cp.backMarkerOffset), tostring(vehicle.cp.aiFrontMarker))
end;

function courseplay:setFoldedStates(object)
	if courseplay:isFoldable(object) and object.spec_foldable.turnOnFoldDirection then
		cpPrintLine(17);
		courseplay:debug(nameNum(object) .. ': setFoldedStates()', 17);

		object.cp.realUnfoldDirection = object.spec_foldable.turnOnFoldDirection;
		if object.cp.foldingPartsStartMoveDirection and object.cp.foldingPartsStartMoveDirection ~= 0 and object.cp.foldingPartsStartMoveDirection ~= object.spec_foldable.turnOnFoldDirection then
			object.cp.realUnfoldDirection = object.spec_foldable.turnOnFoldDirection * object.cp.foldingPartsStartMoveDirection;
		end;

		if object.cp.realUnfoldDirectionIsReversed then
			object.cp.realUnfoldDirection = -object.cp.realUnfoldDirection;
		end;

		courseplay:debug(string.format('startAnimTime=%s, turnOnFoldDirection=%s, foldingPartsStartMoveDirection=%s --> realUnfoldDirection=%s', tostring(object.startAnimTime), tostring(object.turnOnFoldDirection), tostring(object.cp.foldingPartsStartMoveDirection), tostring(object.cp.realUnfoldDirection)), 17);

		for i,foldingPart in pairs(object.spec_foldable.foldingParts) do
			foldingPart.isFoldedAnimTime = 0;
			foldingPart.isFoldedAnimTimeNormal = 0;
			foldingPart.isUnfoldedAnimTime = foldingPart.animDuration;
			foldingPart.isUnfoldedAnimTimeNormal = 1;

			if object.cp.realUnfoldDirection < 0 then
				foldingPart.isFoldedAnimTime = foldingPart.animDuration;
				foldingPart.isFoldedAnimTimeNormal = 1;
				foldingPart.isUnfoldedAnimTime = 0;
				foldingPart.isUnfoldedAnimTimeNormal = 0;
			end;
			courseplay:debug(string.format('\tfoldingPart %d: isFoldedAnimTime=%s (normal: %d), isUnfoldedAnimTime=%s (normal: %d)', i, tostring(foldingPart.isFoldedAnimTime), foldingPart.isFoldedAnimTimeNormal, tostring(foldingPart.isUnfoldedAnimTime), foldingPart.isUnfoldedAnimTimeNormal), 17);
		end;
		cpPrintLine(17);
	end;
end;

function courseplay:setTipperCoverData(vehicle)
	for i=1, vehicle.cp.numWorkTools do
		local workTool = vehicle.cp.workTools[i];

		-- Default Giants trailers
		if workTool.cp.hasSpecializationCover and not workTool.cp.isStrawBlower and workTool.spec_cover.hasCovers then
			courseplay:debug(string.format('Implement %q has a cover (hasSpecializationCover == true)', tostring(workTool.name)), 6);
			local data = {
				coverType = 'defaultGiants',
				tipperIndex = i,
			};
			table.insert(vehicle.cp.tippersWithCovers, data);
			vehicle.cp.tipperHasCover = true;

		-- TODO: Delete old mod code if sure not needed anymore.
		-- Example: for mods trailer that don't use the default cover specialization. Look at openCloseCover() to see how this is used!
		else--if workTool.cp.isCoverVehicle then
			--courseplay:debug(string.format('Implement %q has a cover (isCoverVehicle == true)', tostring(workTool.name)), 6);
			--vehicle.cp.tipperHasCover = true;
			--local coverItems = someCreatedCoverList;
			--local data = {
			--	coverType = 'CoverVehicle',
			--	tipperIndex = i,
			--	coverItems = coverItems,
			--	showCoverWhenTipping = true
			--};
			--table.insert(vehicle.cp.tippersWithCovers, data);
		end;
	end;
end;

function courseplay:setAutoTurnDiameter(vehicle, hasWorkTool)
	cpPrintLine(6, 3);
	local turnRadius, turnRadiusAuto = 10, 10;

	vehicle.cp.turnDiameterAuto = vehicle.cp.vehicleTurnRadius * 2;
	courseplay:debug(('%s: Set turnDiameterAuto to %.2fm (2 x vehicleTurnRadius)'):format(nameNum(vehicle), vehicle.cp.turnDiameterAuto), 6);

	-- Check if we have worktools and if we are in a valid mode
	if hasWorkTool and (vehicle.cp.mode == 2 or vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6) then
		courseplay:debug(('%s: getHighestToolTurnDiameter(%s)'):format(nameNum(vehicle), vehicle.name), 6);

		local toolTurnDiameter = AIDriverUtil.getTurningRadius(vehicle) * 2

		-- If the toolTurnDiameter is bigger than the turnDiameterAuto, then set turnDiameterAuto to toolTurnDiameter
		if toolTurnDiameter > vehicle.cp.turnDiameterAuto then
			courseplay:debug(('%s: toolTurnDiameter(%.2fm) > turnDiameterAuto(%.2fm), turnDiameterAuto set to %.2fm'):format(nameNum(vehicle), toolTurnDiameter, vehicle.cp.turnDiameterAuto, toolTurnDiameter), 6);
			vehicle.cp.turnDiameterAuto = toolTurnDiameter;
		end;
	end;


	if vehicle.cp.turnDiameterAutoMode then
		vehicle.cp.turnDiameter = vehicle.cp.turnDiameterAuto;
		courseplay:debug(('%s: turnDiameterAutoMode is active: turnDiameter set to %.2fm'):format(nameNum(vehicle), vehicle.cp.turnDiameterAuto), 6);
	end;
	cpPrintLine(6, 1);
end;

--##################################################


-- ##### LOADING TOOLS ##### --
function courseplay:load_tippers(vehicle, allowedToDrive)
	--- vehicle.cp.tipperLoadMode == num
	-- 0 = No loading mode is set. Will continue driving forward until mode 1 or 2 is set
	-- 1 = Load at silo trigger. Will continue  driving forward until the trailer is centered underneath the silo trigger, then stop and fill up
	-- 2 = Stop at underneath wp 1 for field loading

	if vehicle.cp.currentTrailerToFill == nil then
		vehicle.cp.currentTrailerToFill = 1;
	end

	local currentTrailer = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill];

	local driveOn = vehicle.cp.settings.driveUnloadNow:get();
	if not currentTrailer.cp.realUnloadOrFillNode then
		currentTrailer.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(currentTrailer);
		if not currentTrailer.cp.realUnloadOrFillNode or not currentTrailer.spec_trailer then
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
				vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
			else
				driveOn = true;
			end;
		end;
	end;
	
	currentTrailer = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill];
	
	if (vehicle.cp.tipperLoadMode == 0 or vehicle.cp.tipperLoadMode == 3) and not driveOn then
		--if vehicle.cp.ppc:haveJustPassedWaypoint(1) and currentTrailer.cp.currentSiloTrigger == nil then  --vehicle.cp.ppc:haveJustPassedWaypoint(1) doesn't work here
		if vehicle.cp.driver.course:havePhysicallyPassedWaypoint(vehicle.cp.directionNode, 1) and currentTrailer.cp.currentSiloTrigger == nil then
		--- We must be on an loading point at a field so we stop under wp1 and wait for trailer to be filled up
			vehicle.cp.tipperLoadMode = 2;
		elseif currentTrailer.cp.currentSiloTrigger then
			--- We have an silo trigger, so we go load at silo trigger mode
			vehicle.cp.tipperLoadMode = 1;
		else
			
			--- we know, we are in the filling range so tell the rest of the program.
			vehicle.cp.tipperLoadMode = 3;
			return allowedToDrive;
		end;
	end;

	local unloadDistance = 1000;
	local backUpDistance = 1000;
	local trailerX,_,trailerZ = getWorldTranslation(currentTrailer.cp.realUnloadOrFillNode);
	
	if not driveOn then
		if vehicle.cp.tipperLoadMode == 1 then
			local directionNode = vehicle.aiVehicleDirectionNode or vehicle.cp.directionNode;
			local _,vehicleY,_ = getWorldTranslation(directionNode);

			local _,_,z = worldToLocal(directionNode, trailerX, vehicleY, trailerZ);
			vehicle.cp.trailerFillDistance = z + 0.5;

			if currentTrailer.cp.currentSiloTrigger ~= nil then
				local triggerX,_,triggerZ = getWorldTranslation(currentTrailer.cp.currentSiloTrigger.rootNode);
				_,_,unloadDistance = worldToLocal(directionNode, triggerX, vehicleY, triggerZ);
				courseplay:debug(string.format('%s: Silo Trigger unloadDistance = %.2f vehicle.cp.trailerFillDistance = %.4s', nameNum(vehicle), unloadDistance, tostring(vehicle.cp.trailerFillDistance)), 2);
				
				--to be used when the waypoints are too close to get the realUnloadOrFillNode under the fillTrigger
				--we are in fillTrigger anyway, so thats just optics
				backUpDistance = vehicle.cp.driver.course:getDistanceBetweenVehicleAndWaypoint(vehicle, 1)
			end;
		elseif vehicle.cp.tipperLoadMode == 2 then
			vehicle.cp.trailerFillDistance = 1;
		end;
	end;

	if vehicle.cp.tipperLoadMode == 1 and currentTrailer.cp.currentSiloTrigger ~= nil and not driveOn then
        local acceptedFillType = false;
		local siloTrigger = currentTrailer.cp.currentSiloTrigger;
		local fillTypeData = vehicle.cp.settings.siloSelectedFillTypeGrainTransportDriver:getData()
		if not siloTrigger.isLoading then
			vehicle.cp.siloSelectedFillType = FillType.UNKNOWN
			--should be a function in the rework !!
			if fillTypeData then 
				for _,data in ipairs(fillTypeData) do 
					if data.runCounter >0 then 
						if courseplay:fillTypesMatch(vehicle, siloTrigger, currentTrailer) then	
							local breakLoop = false
							local fillLevels, capacity
							if siloTrigger.source and  siloTrigger.source.getAllFillLevels then 
								fillLevels, capacity = siloTrigger.source:getAllFillLevels(g_currentMission:getFarmId())
							elseif siloTrigger.source and siloTrigger.source.getAllProvidedFillLevels then
								--siloTrigger.extraParameter instead of siloTrigger.managerId
								fillLevels, capacity = siloTrigger.source:getAllProvidedFillLevels(g_currentMission:getFarmId(), siloTrigger.managerId)
							else
								courseplay:debug('fillLevels not found !!', 2);
								breakLoop=true
								break
							end						
							for fillTypeIndex, fillLevel in pairs(fillLevels) do
								if fillTypeIndex == data.fillType then 
									if fillLevel > 0 then 
										vehicle.cp.siloSelectedFillType = data.fillType
										breakLoop=true
										break
									else
							
									end
								end
							end
							if breakLoop then 
								break
							end
						else
						
						end
					end		
				end
			end
		end
		if courseplay:fillTypesMatch(vehicle, siloTrigger, currentTrailer) then	
			local siloIsEmpty = false --siloTrigger:getFillLevel(vehicle.cp.siloSelectedFillType) <= 1;
			if not siloTrigger.isLoading and not siloIsEmpty and (unloadDistance < vehicle.cp.trailerFillDistance or backUpDistance < 1 ) then
				if siloTrigger:getIsActivatable(currentTrailer) then
					courseplay:setFillOnTrigger(vehicle,currentTrailer,true,siloTrigger)
				end 
				
				--siloTrigger:startFill(vehicle.cp.siloSelectedFillType);
				courseplay:setCustomTimer(vehicle, 'siloEmptyMessageDelay', 1);
				courseplay:debug(('%s: SiloTrigger: selectedFillType = %s, isLoading = %s'):format(nameNum(vehicle), tostring(g_fillTypeManager.indexToName[siloTrigger.selectedFillType]), tostring(siloTrigger.isLoading)), 2);
			elseif siloTrigger.isLoading then
				courseplay:setCustomTimer(vehicle, 'siloEmptyMessageDelay', 1);
			elseif siloIsEmpty and vehicle.cp.totalFillLevelPercent < vehicle.cp.settings.refillUntilPct:get() and courseplay:timerIsThrough(vehicle, 'siloEmptyMessageDelay') then
				CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
			end;
		else
			CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_NO_FILLTYPE');
		end;
	end;

	-- drive on when required fill level is reached
	-- in case of waiting to be loaded e.g. by shovel 
	if not driveOn and (courseplay:timerIsThrough(vehicle, 'fillLevelChange') or vehicle.cp.prevFillLevelPct == nil) then
		if vehicle.cp.prevFillLevelPct ~= nil and vehicle.cp.totalFillLevelPercent == vehicle.cp.prevFillLevelPct and vehicle.cp.totalFillLevelPercent > vehicle.cp.settings.refillUntilPct:get() then
			driveOn = true;
		end;
		vehicle.cp.prevFillLevelPct = vehicle.cp.totalFillLevelPercent;
		courseplay:setCustomTimer(vehicle, 'fillLevelChange', 7);
	end;
	
	--if established on a fill trigger go on immediately when level is reached
	if currentTrailer.cp.currentSiloTrigger ~= nil and (vehicle.cp.totalFillLevelPercent > vehicle.cp.settings.refillUntilPct:get() or vehicle.cp.settings.driveUnloadNow:is(true)) then
		courseplay:setFillOnTrigger(vehicle,currentTrailer,false,currentTrailer.cp.currentSiloTrigger)
		driveOn = true;
	end;	

	if vehicle.cp.totalFillLevelPercent == 100 or driveOn then
		vehicle.cp.prevFillLevelPct = nil;
		courseplay:setDriveUnloadNow(vehicle, true);
		vehicle.cp.trailerFillDistance = nil;
		vehicle.cp.currentTrailerToFill = nil;
		vehicle.cp.tipperLoadMode = 0;
		return allowedToDrive;
	end;

	if currentTrailer.cp.realUnloadOrFillNode and vehicle.cp.trailerFillDistance then
		if courseplay:getFreeCapacity(currentTrailer,vehicle.cp.siloSelectedFillType) == 0 then
		--or currentTrailer.cp.currentSiloTrigger ~= nil and not (courseplay:getFreeCapacity(currentTrailer,vehicle.cp.siloSelectedFillType) > 0 and #currentTrailer:getFillUnitsWithFillType(vehicle.cp.siloSelectedFillType) > 0) then
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
				vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
			else
				vehicle.cp.prevFillLevelPct = nil;
				courseplay:setDriveUnloadNow(vehicle, true);
				vehicle.cp.trailerFillDistance = nil;
				vehicle.cp.currentTrailerToFill = nil;
				vehicle.cp.tipperLoadMode = 0;
			end;
		else
			courseplay:debug(string.format('%s: Stop the tipper unloadDistance = %.4s vehicle.cp.trailerFillDistance = %.4s waypointindex = %s', nameNum(vehicle), tostring(unloadDistance), tostring(vehicle.cp.trailerFillDistance), tostring(vehicle.cp.waypointIndex)), 2);
			if unloadDistance < vehicle.cp.trailerFillDistance or vehicle.cp.tipperLoadMode == 2 or backUpDistance < 1 then
				allowedToDrive = false;
			end;
		end;
	end;

	-- normal mode if all tippers are empty
	return allowedToDrive;
end


-- ##################################################


-- ##### UNLOADING TOOLS ##### --
function courseplay:unload_tippers(vehicle, allowedToDrive,dt)
	local ctt = vehicle.cp.currentTipTrigger;
	local takeOverSteering = false
	--[[if ctt.getTipDistanceFromTrailer == nil then
		courseplay:debug(nameNum(vehicle) .. ": getTipDistanceFromTrailer function doesn't exist for currentTipTrigger - unloading function aborted", 2);
		return allowedToDrive;
	end]]

	-- If we are less than 15 waypoints from the end point, don't reset the stopAtEndMode1 (We might be at the same silo as we are filling from)
	if vehicle.cp.waypointIndex + 20 < vehicle.cp.numWaypoints then
		vehicle.cp.stopAtEndMode1 = false;
	end;

	--[[
	-- If the tipTrigger is full, then drive on to see if there is
	local freeCapacity = 0;
	if ctt.bunkerSilo then
		freeCapacity = ctt.capacity - ctt.fillLevel;
	else
		for _, tipper in pairs(vehicle.cp.workTools) do
			if ctt.animalHusbandry then
				if ctt.animalHusbandry:getHasSpaceForTipping(tipper.cp.fillType) then
					freeCapacity = 100
				end
			elseif tipper.spec_dischargeable ~= nil then
				freeCapacity = freeCapacity + courseplay:getTipTriggerFreeCapacity(ctt, tipper.cp.fillType);
				if tipper.cp.isTipping then
					vehicle.cp.isTipping = true;
				end;
			end;
		end;
	end
	
	if freeCapacity == 0 then
		if vehicle.cp.isTipping then
			if not courseplay.SiloIsFullMessageTimeOn then
				courseplay:setCustomTimer(vehicle, 'SiloIsFullMessage', 5);
				courseplay.SiloIsFullMessageTimeOn = true;
			end;

			if courseplay:timerIsThrough(vehicle, 'SiloIsFullMessage') then
				courseplay:resetTipTrigger(vehicle)
				courseplay:resetCustomTimer(vehicle, 'SiloIsFullMessage', true);
				courseplay.SiloIsFullMessageTimeOn = nil;
				vehicle.cp.isTipping = false;
				if vehicle.cp.mode == 1 then
					vehicle.cp.stopAtEndMode1 = true;
				end			
			end;
			CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_FULL')
		else
			courseplay:resetTipTrigger(vehicle)
			courseplay:resetCustomTimer(vehicle, 'SiloIsFullMessage', true);
			courseplay.SiloIsFullMessageTimeOn = nil;
			if vehicle.cp.mode == 1 then
				vehicle.cp.stopAtEndMode1 = true;
			end
		end;

		return allowedToDrive;
	end;]]
	

	local isBGA = ctt.bunkerSilo ~= nil;
	local bgaIsFull = isBGA and (ctt.fillLevel >= ctt.capacity);
	if isBGA then
		vehicle.cp.isBGATipping = true;
	end;

	for k, tipper in pairs(vehicle.cp.workTools) do
		if tipper.spec_dischargeable ~= nil then
			local allowedToDriveBackup = allowedToDrive;
			local fillType = tipper.cp.fillType;

			local currentDischargeNode = tipper:getCurrentDischargeNode()
			local distanceToTrigger, bestTipReferencePoint = 0, currentDischargeNode;
			
			
			--find the best TipPoint
			if not tipper:getCanDischargeToObject(currentDischargeNode) then
				for i=1,#tipper.spec_dischargeable.dischargeNodes do
					if tipper:getCanDischargeToObject(tipper.spec_dischargeable.dischargeNodes[i])then
						tipper:setCurrentDischargeNodeIndex(tipper.spec_dischargeable.dischargeNodes[i]);
						currentDischargeNode = tipper:getCurrentDischargeNode()
						break
					end
				end
			end
			
			
			
			
			
			--[[if isBGA then
				if tipper.cp.rearTipRefPoint and tipper.cp.rearTipRefPoint ~= bestTipReferencePoint then
					bestTipReferencePoint = tipper.cp.rearTipRefPoint;
				end;
				distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper,bestTipReferencePoint);
			else
				distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper);
			end]]
			
			
			if  isBGA then
				if tipper.cp.rearTipRefPoint and tipper.cp.rearTipRefPoint ~= bestTipReferencePoint then
					bestTipReferencePoint = tipper.cp.rearTipRefPoint;
				end;
			end
			distanceToTrigger = courseplay:nodeToNodeDistance(currentDischargeNode.node, ctt.triggerId)
			
			
			--tipper.preferedTipReferencePointIndex = bestTipReferencePoint
			local trailerInTipRange = false
			if not isBGA then
				trailerInTipRange =  tipper:getCanDischargeToObject(currentDischargeNode) --g_currentMission:getIsTrailerInTipRange(tipper, ctt, bestTipReferencePoint);
				courseplay:debug(('%s: distanceToTrigger=%s, bestTipReferencePoint=%s -> trailerInTipRange=%s'):format(nameNum(tipper), tostring(distanceToTrigger), tostring(bestTipReferencePoint), tostring(trailerInTipRange)), 2);
			end
			
			local goForTipping = false;
			local unloadWhileReversing = false; -- Used by Reverse BGA Tipping
			local isRePositioning = false; -- Used by Reverse BGA Tipping
			-- Moved to drive in attempt to fix loop bug
			-- if tipper.tipState == Trailer.TIPSTATE_CLOSED and vehicle.cp.keepOnTipping  then
			-- 	vehicle.cp.keepOnTipping = false
			-- 	print("reset vehicle.cp.keepOnTipping")
			-- end
			
			--BGA TRIGGER
			if isBGA and not bgaIsFull then

				local stopAndGo = false;

				-- Make sure we are using the rear TipReferencePoint as bestTipReferencePoint if possible.
				
				-- Check if bestTipReferencePoint it's inversed

				--[[if tipper.cp.inversedRearTipNode == nil then
					local vx,vy,vz = getWorldTranslation(vehicle.rootNode)
					local _,_,tz = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, vx,vy,vz);
					tipper.cp.inversedRearTipNode = tz < 0;
				end;
				]]
				-- Local values used in both normal and reverse direction
				local x,y,z = getWorldTranslation(currentDischargeNode.node)
				local tx,ty,tz = x,y,z+0.50
				local x1,z1 = ctt.bunkerSiloArea.sx,ctt.bunkerSiloArea.sz
				local x2,z2 = ctt.bunkerSiloArea.wx,ctt.bunkerSiloArea.wz
				local x3,z3 = ctt.bunkerSiloArea.hx,ctt.bunkerSiloArea.hz
				trailerInTipRange = MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z)
				local sx, sy, sz = worldToLocal(ctt.triggerStartId, x, y, z);
				local ex, ey, ez = worldToLocal(ctt.triggerEndId, x, y, z);
				local startDistance = MathUtil.vector2Length(sx, sz);
				local endDistance = MathUtil.vector2Length(ex, ez);
				courseplay:debug(('%s: startDistance=%s, endDistance=%s -> trailerInTipRange=%s'):format(nameNum(tipper), tostring(startDistance), tostring(endDistance), tostring(trailerInTipRange)), 2);
				--stop if we are not empty but near the end of the trigger
				if 	tipper.cp.isTipping and (endDistance <1 or startDistance <1) then
					allowedToDrive = false;
				end

				-------------------------------
				--- Reverse into BGA and unload
				-------------------------------
				if vehicle.Waypoints[vehicle.cp.waypointIndex].rev or vehicle.cp.isReverseBGATipping then
					if vehicle.cp.totalFillLevel > 0 then
						if trailerInTipRange and ((startDistance > 8 and endDistance > 8) or vehicle.cp.keepOnTipping) then
							goForTipping = true
							allowedToDrive = false
							if vehicle.cp.lastValidTipDistance and not vehicle.cp.keepOnTipping then
								vehicle.cp.keepOnTipping = true
								--print("set vehicle.cp.keepOnTipping")
							end
						end
					else
						courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle))
						vehicle.cp.ppc:initialize()
					end

				-------------------------------
				--- Normal BGA unload
				-------------------------------
				else
					if trailerInTipRange then
						goForTipping = true
					end
					--[[
					-- Get the animation
					local animation;
					if tipper.spec_animatedVehicle.animations['tipAnimationBack'] ~= nil then
						animation = tipper.spec_animatedVehicle.animations['tipAnimationBack'];
					elseif tipper.configFileName == 'data/vehicles/annaburger/fieldLinerHTS31/fieldLinerHTS31.xml' then		--Anim time for the Annaburger is just 2 seconds, way to low to unload it properly
						animation = {['duration'] = 16000, ['currentTime'] = 0}
					elseif tipper.spec_animatedVehicle.animations['tipAnimationBackDoor'] ~= nil then
						animation = tipper.spec_animatedVehicle.animations['tipAnimationBackDoor'];
					else
						animation = {["duration"] = 15000, ["currentTime"] = 0}								--Set some defaults, so in case a weird anim name was used, at least we are not throwing an error
					end
					]]
					
					local totalLength = abs(endDistance - startDistance)*0.9;
					--local fillDelta = vehicle.cp.totalFillLevel / vehicle.cp.totalCapacity;
					
					local dischargeNode = tipper:getCurrentDischargeNode()
					local totalTipDuration = ((tipper.cp.totalFillLevel / dischargeNode.emptySpeed )/ 1000)
					local meterPrSeconds = totalLength / totalTipDuration;
					
					if stopAndGo then
						meterPrSeconds = vehicle.cp.speeds.reverse * 1000;
					end;

					-- Slow down to real unload speed
					if not vehicle.cp.backupUnloadSpeed and not stopAndGo then --and vectorDistance < 6*meterPrSeconds then
						-- Calculate the unloading speed.
						local refSpeed = meterPrSeconds * 3.6; -- * 0.90;
						vehicle.cp.backupUnloadSpeed = vehicle.cp.speeds.reverse;
						courseplay:changeReverseSpeed(vehicle, nil, refSpeed, true);
						--courseplay:debug(string.format("%s: BGA totalLength=%.2f,  totalTipDuration%.2f,  refSpeed=%.2f", nameNum(tipper), totalLength, totalTipDuration, refSpeed), 2);
						courseplay:debug(string.format("%s in mode %s: entering BGASilo: \nemptySpeed: %sl/sek; fillLevel: %0.1fl\nSilo length: %sm/Total unload time: %ss *3.6 = unload speed: %.2fkmh", tostring(tipper.getName and tipper:getName() or 'no name'), tostring(vehicle.cp.mode), tostring(dischargeNode.emptySpeed*1000),tipper.cp.totalFillLevel,tostring(totalLength) ,tostring(totalTipDuration),refSpeed),14)
					--print(string.format("totalTipDuration: %s; totalLength: %s",tostring(totalTipDuration),tostring(totalLength)))
						--print(string.format("%s: BGA totalLength=%.2f,  totalTipDuration%.2f,  refSpeed=%.2f", nameNum(vehicle), totalLength, totalTipDuration, refSpeed));
					end;
				end;

			--BGA TIPTRIGGER BUT IS FULL AND WE ARE REVERSE TIPPING
			elseif isBGA and bgaIsFull and (vehicle.Waypoints[vehicle.cp.waypointIndex].rev or vehicle.cp.isReverseBGATipping) then
				-- Stop the vehicle, since we don't want to reverse into the BGA if it's full.
				allowedToDrive = false;
				-- Tell the user why we have stoped.
				CpManager:setGlobalInfoText(vehicle, 'BGA_IS_FULL');

			-- BGA TIPTRIGGER IS FULL
			elseif isBGA and bgaIsFull and not vehicle.Waypoints[vehicle.cp.waypointIndex].rev and not vehicle.cp.isReverseBGATipping then
				-- set trigger to nil
				courseplay:resetTipTrigger(vehicle);

			-- REGULAR TIPTRIGGER
			elseif not isBGA then
				if ctt.isAreaTrigger then
					trailerInTipRange = g_currentMission.trailerTipTriggers[tipper] ~= nil
					if not vehicle.Waypoints[vehicle.cp.waypointIndex].rev and not tipper.cp.isTipping then

						local trailerX,_,trailerZ = getWorldTranslation(tipper.tipReferencePoints[bestTipReferencePoint].node);
						local triggerX,_,triggerZ = getWorldTranslation(vehicle.cp.currentTipTrigger.rootNode);

						local unloadDistance = courseplay:distance(trailerX, trailerZ, triggerX, triggerZ) 

						courseplay:debug(string.format('%s: unloadDistance = %.2f tipper.cp.trailerFillDistance = %.4s', nameNum(tipper), unloadDistance, tostring(tipper.cp.prevTrailerDistance)), 2);
						goForTipping = trailerInTipRange and tipper.cp.prevTrailerDistance and tipper.cp.prevTrailerDistance < unloadDistance
						tipper.cp.prevTrailerDistance = unloadDistance 
						
					else
						goForTipping = trailerInTipRange
					end;
				else
					goForTipping = trailerInTipRange
				end
				

				--AlternativeTipping: don't unload if full
				if ctt.fillLevel ~= nil and ctt.capacity ~= nil and ctt.fillLevel >= ctt.capacity then
					goForTipping = false;
				end;
			end

			--UNLOAD
			--print("goForTipping = "..tostring(goForTipping))
			
			if ctt.acceptedFillTypes[fillType] and goForTipping == true then
				--print("ctt.acceptedFillTypes[fillType] and goForTipping == true; tipper.cp.isTipping= "..tostring(tipper.cp.isTipping))
				if not tipper.cp.isTipping then
					if isBGA then
						courseplay:debug(nameNum(tipper) .. ": goForTipping = true [BGA trigger accepts fruit (" .. tostring(fillType) .. ")]", 2);
					else
						courseplay:debug(nameNum(tipper) .. ": goForTipping = true [trigger accepts fruit (" .. tostring(fillType) .. ")]", 2);
					end;
					local tipState = tipper:getTipState()
					if tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING then
						local isNearestPoint = false
						if courseplay:round(distanceToTrigger, 1) > courseplay:round(tipper.cp.closestTipDistance, 1) then
							isNearestPoint = true
							courseplay:debug(nameNum(tipper) .. ": isNearestPoint = true ", 2);
						else
							tipper.cp.closestTipDistance = distanceToTrigger
						end
						if distanceToTrigger == 0 or isBGA or isNearestPoint then
							if isBGA then
								--tip to ground or existing heap
								tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
							elseif ctt.animalHusbandry then
								if ctt.animalHusbandry:getHasSpaceForTipping(tipper.cp.fillType) then
							--		tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
								end
							else	
							--	tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT) --tipper:toggleTipState(ctt, bestTipReferencePoint);
							end
							courseplay:debug(nameNum(tipper)..": setDischargeState: "..tostring(bestTipReferencePoint).."  /unloadingTipper= "..tostring(tipper:getName()), 2);
						end
					else
						tipper.cp.isTipping = true;
						courseplay:debug(nameNum(tipper)..": set isTipping", 2);
						allowedToDrive = false;
					end;
				else
					local tipState = tipper:getTipState()
					if tipState ~= Trailer.TIPSTATE_CLOSING and tipState ~= Trailer.TIPSTATE_CLOSED then
						tipper.cp.closestTipDistance = math.huge
						allowedToDrive = false;
					end;

					--Tommi takeOverSteering = courseplay:manageCompleteTipping(vehicle,tipper,dt)
					
					if isBGA and ((not vehicle.Waypoints[vehicle.cp.waypointIndex].rev and not vehicle.cp.isReverseBGATipping) or unloadWhileReversing) then
						allowedToDrive = allowedToDriveBackup;
					end;
				end;
			elseif not ctt.acceptedFillTypes[fillType] then
				if isBGA then
					courseplay:debug(nameNum(tipper) .. ": goForTipping = false [BGA trigger does not accept fruit (" .. tostring(fillType) .. ")]", 2);
				else
					courseplay:debug(nameNum(tipper) .. ": goForTipping = false [trigger does not accept fruit (" .. tostring(fillType) .. ")]", 2);
				end;
			elseif isBGA and not bgaIsFull and not trailerInTipRange and not goForTipping then
				courseplay:debug(nameNum(tipper) .. ": goForTipping = false [BGA: trailerInTipRange == false]", 2);
			elseif isBGA and bgaIsFull and not goForTipping then
				courseplay:debug(nameNum(tipper) .. ": goForTipping = false [BGA: fillLevel > capacity]", 2);
			elseif isBGA and not goForTipping then
				courseplay:debug(nameNum(tipper) .. ": goForTipping = false [BGA]", 2);
			elseif not isBGA and not trailerInTipRange and not goForTipping then
				courseplay:debug(nameNum(tipper) .. ": goForTipping = false [trailerInTipRange == false]", 2);
			elseif not isBGA and not goForTipping then
				courseplay:debug(nameNum(tipper) .. ": goForTipping = false [fillLevel > capacity]", 2);
			end;
		end;
	end;
	return allowedToDrive,takeOverSteering;
end

function courseplay:addCpNilTempFillLevelFunction()
	local cpNilTempFillLevel = function(self, state)
		if state ~= self.state and state == BunkerSilo.STATE_CLOSED then
			self.cpTempFillLevel = nil;
		end;
	end;
	BunkerSilo.setState = Utils.prependedFunction(BunkerSilo.setState, cpNilTempFillLevel);
end;

function courseplay:getTipTriggerFreeCapacity(trigger, fillType)
	--Tommi TODO get it to the new Trigger version
	local freeCapacity = 0;
	if trigger.tipTriggerTargets ~= nil then
		for _, storage in pairs(trigger.tipTriggerTargets) do
			freeCapacity = freeCapacity + storage:getFreeCapacity(fillType)
		end;
	else
		return math.huge;
	end
	return freeCapacity;
end;

function courseplay:resetTipTrigger(vehicle, changeToForward)
	if vehicle.cp.currentTipTrigger ~= nil then
		if vehicle.cp.tipperFillLevel == 0 then
			vehicle.cp.isUnloaded = true;
		end
		vehicle.cp.currentTipTrigger = nil;
		vehicle.cp.isReverseBGATipping = nil; -- Used for reverse BGA tipping
		vehicle.cp.isBGATipping = false;

		for k, tipper in pairs(vehicle.cp.workTools) do
			tipper.cp.BGASelectedSection = nil; -- Used for reverse BGA tipping
			tipper.cp.isTipping = false;
			tipper.cp.prevTrailerDistance = 100.00;
		end;
		vehicle.cp.inversedRearTipNode = nil; -- Used for reverse BGA tipping
		if vehicle.cp.backupUnloadSpeed then
			courseplay:changeReverseSpeed(vehicle, nil, vehicle.cp.backupUnloadSpeed, true);
			vehicle.cp.backupUnloadSpeed = nil;
		end;
		if changeToForward and vehicle.Waypoints[vehicle.cp.waypointIndex].rev then
			courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
			vehicle.cp.ppc:initialize()
		end;
	end
end;

-- this does not change lx/lz (direction), only allowedToDrive
function courseplay:refillWorkTools(vehicle, driveOnAtPercent, allowedToDrive, lx, lz)
	--if the trigger is not used by me, reset it after 10s
	if courseplay:timerIsThrough(vehicle, "triggerFailBackup", false) then
		  courseplay:resetFillTrigger(vehicle)
	end
	for _,workTool in ipairs(vehicle.cp.workTools) do
		local isFilling = false
		if (vehicle.cp.fillTrigger) and (workTool.cp.capacity ~= nil) and (workTool.cp.capacity > 0) then
			local trigger = courseplay.triggers.fillTriggers[vehicle.cp.fillTrigger]
			if trigger ~= nil and courseplay:fillTypesMatch(vehicle, trigger, workTool) then
				courseplay:setInfoText(vehicle, string.format("COURSEPLAY_LOADING_AMOUNT;%d;%d",courseplay.utils:roundToLowerInterval(vehicle.cp.totalFillLevel, 100),vehicle.cp.totalCapacity));
				courseplay:openCloseCover(vehicle, not courseplay.SHOW_COVERS,trigger)
				allowedToDrive, isFilling = courseplay:fillOnTrigger(vehicle, workTool,vehicle.cp.fillTrigger)
			else
				courseplay.debugVehicle(19,vehicle,'fillTypes dont match -> reset fillTrigger')
				courseplay:resetFillTrigger(vehicle)
			end
			
			--check whether vehicle.cp.refillUntilPct is set 
			if driveOnAtPercent < 100 and isFilling then
				local triggerFilltype = trigger:getCurrentFillType()
				local fillUnits = workTool:getFillUnits()
				if trigger.sourceObject then
					triggerFilltype = workTool.spec_fillUnit.fillTrigger.triggers[1].sourceObject:getFillUnitFillType(1)
				end
				
				--if the concerned fillUnits fillLevel is reached, stop filling
				for i=1,#fillUnits do
					--print(string.format("fillUnit[%i]: triggerFilltype(%s) == workTool:getFillUnitFillType(i)(%s) and workTool:getFillUnitFillLevelPercentage(i)*100(%.1f) > driveOnAtPercent(%i)"
					--	,i,tostring(triggerFilltype),tostring(workTool:getFillUnitFillType(i)),workTool:getFillUnitFillLevelPercentage(i)*100,driveOnAtPercent))
					if triggerFilltype == workTool:getFillUnitFillType(i)
					and workTool:getFillUnitFillLevelPercentage(i)*100 > driveOnAtPercent then
						courseplay.debugVehicle(19,vehicle,'set fillLevel percentage reached -> stop filling and reset fillTrigger')
						courseplay:setFillOnTrigger(vehicle,workTool,false,trigger)
						courseplay:resetFillTrigger(vehicle)
					end				
				end
			end
		end
	end;
	return allowedToDrive, lx, lz;
end;		
		
function courseplay:fillOnTrigger(vehicle, objectToFill,triggerId)
	local allowedToDrive = true
	local trigger = courseplay.triggers.fillTriggers[triggerId]
	if trigger.onActivateObject then
		--loadTriggers:placeables,silos
		--when I'm in the trigger, activate it
		if trigger:getIsActivatable(objectToFill) and not vehicle.isFuelFilling then
			courseplay.debugVehicle(19,vehicle,'start filling')
			courseplay:setFillOnTrigger(vehicle,objectToFill,true,trigger)
			allowedToDrive = false;
			vehicle.isFuelFilling = true
		end
		if vehicle.isFuelFilling then 
			allowedToDrive = false;
			if not trigger.isLoading then
				courseplay.debugVehicle(19,vehicle,'fillTrigger stopped filling -> reset fillTrigger')
				vehicle.isFuelFilling = nil
				courseplay:resetFillTrigger(vehicle)
			end
		end
	elseif trigger.sourceObject ~= nil then
		--fillTriggers(Pallets,Vehicles)
		local counter = 0
		-- toggle through my fillTriggers trigger list and check, whether a trigger is valid to fill 
		-- then start filling
		for triggerIndex, fillTrigger in ipairs(objectToFill.spec_fillUnit.fillTrigger.triggers) do
			counter = counter+1
			if fillTrigger:getIsActivatable(objectToFill) and not vehicle.isFuelFilling then 
				local triggerFilltype = trigger:getCurrentFillType()
				local fillUnits = objectToFill:getFillUnits()
				for i=1,#fillUnits do
					if objectToFill:getFillUnitFillLevelPercentage(i)*100 < vehicle.cp.settings.refillUntilPct:get() and courseplay:fillTypesMatch(vehicle, fillTrigger, objectToFill,i) then
						courseplay.debugVehicle(19,vehicle,'start filling')
						courseplay:setFillOnTrigger(vehicle,objectToFill,true,trigger,triggerIndex)
						allowedToDrive = false;
						vehicle.isFuelFilling = true
						break;
					end
				end
			end
		end
		--when the trigger is filling, stop and wait
		if vehicle.isFuelFilling then
			allowedToDrive = false;
			--if the trigger stops loading, reset vehicle.isFuelFilling
			if not objectToFill.spec_fillUnit.fillTrigger.isFilling then 
				courseplay.debugVehicle(19,vehicle,'fillTrigger stopped filling -> reset fillTrigger')
				courseplay:resetFillTrigger(vehicle)
				vehicle.isFuelFilling = nil
				courseplay:setCustomTimer(vehicle, "resetFillTrigger", 5)
			end
		--maybe there are more pallets nearby, so wait for 5s and move further
		--if you get a new pallet, start loading there, otherwise kill the trigger
		elseif courseplay:timerIsThrough(vehicle, "resetFillTrigger", false) then
			if #objectToFill.spec_fillUnit.fillTrigger.triggers == 0 then
				courseplay.debugVehicle(19,vehicle,'timer "resetFillTrigger" is up -> reset fillTrigger')
				courseplay:resetFillTrigger(vehicle)
				courseplay:resetCustomTimer(vehicle, "resetFillTrigger", true)
			end
		
		end	
	end
	
	
	return allowedToDrive, vehicle.isFuelFilling ;
end
	
function courseplay:resetFillTrigger(vehicle)
	--print("resetFillTrigger: triggers: "..tostring(#vehicle.cp.fillTriggers))
	if vehicle.cp.fillTrigger then
		--if we have more than one trigger found, take the next one
		if #vehicle.cp.fillTriggers >1 then
			table.remove(vehicle.cp.fillTriggers,1)
			vehicle.cp.fillTrigger = vehicle.cp.fillTriggers[1];
			courseplay.debugVehicle(19,vehicle,'resetFillTrigger: there are more triggers, take then next one (%d)', vehicle.cp.fillTrigger)
		--if it was the last one, reset vehicle.cp.fillTrigger
		else
			table.remove(vehicle.cp.fillTriggers,1)
			vehicle.cp.fillTrigger = nil
			courseplay.debugVehicle(19,vehicle,'resetFillTrigger: no triggers left, reset vehicle.cp.fillTrigger')
		end
		--setting the next fwd waypoint for reverse filling. should not cause problems in fwd filling. if it does, find an other way 
		local driver = vehicle.cp.driver
		driver.ppc:initialize(driver.course:getNextFwdWaypointIxFromVehiclePosition(driver.ppc:getCurrentWaypointIx(),vehicle.cp.directionNode,driver.ppc:getLookaheadDistance()));
	elseif vehicle.cp.fuelFillTrigger then
		vehicle.cp.fuelFillTrigger = nil
	end
	courseplay:openCloseCover(vehicle, courseplay.SHOW_COVERS)
end	

function courseplay:setFillOnTrigger(vehicle,workTool,fillOrder,trigger,triggerIndex)
	courseplay:resetCustomTimer(vehicle, "triggerFailBackup", true)
	courseplay.activateTriggerForVehicle = vehicle.cp.driver.activateTriggerForVehicle
	if fillOrder then
		--start filling
		if trigger.onActivateObject then
			if trigger.autoStart then
				courseplay:activateTriggerForVehicle(trigger, vehicle);
			elseif not trigger.isLoading then
				--force Diesel when I'm in fuelFillTrigger or the selected fillType in fillTrigger and start the autoload
				trigger.autoStart = true
				courseplay:activateTriggerForVehicle(trigger, vehicle);
				trigger.selectedFillType = (vehicle.cp.fuelFillTrigger and FillType.DIESEL) or (vehicle.cp.siloSelectedFillType ~= FillType.UNKNOWN and vehicle.cp.siloSelectedFillType) or courseplay:getOnlyPossibleFillType(vehicle,workTool,trigger) 
				g_effectManager:setFillType(trigger.effects, trigger.selectedFillType)
				trigger.autoStart = false
				courseplay.hud:setReloadPageOrder(vehicle, vehicle.cp.hud.currentPage, true);
			end
		elseif trigger.sourceObject ~= nil then
			--move the wanted trigger to the top of the table, setFillUnitIsFilling takes allways the trigger[1] 
			local fillTrigger = workTool.spec_fillUnit.fillTrigger.triggers[triggerIndex]
			if triggerIndex >1 then
				table.remove(workTool.spec_fillUnit.fillTrigger.triggers, triggerIndex)
				table.insert(workTool.spec_fillUnit.fillTrigger.triggers, 1, fillTrigger)
			end
			
			workTool:setFillUnitIsFilling(true)
		end
	else
		--stop filling
		if trigger.onActivateObject then 
			if trigger.isLoading then
				courseplay:activateTriggerForVehicle(trigger, vehicle);
			end
		elseif trigger.sourceObject then
			workTool:setFillUnitIsFilling(false)							
		end
		courseplay:openCloseCover(vehicle, courseplay.SHOW_COVERS)
	end
end	

function courseplay:getOnlyPossibleFillType(vehicle,workTool,fillTrigger)
	local fillUnits = workTool:getFillUnits()
	for i=1,#fillUnits do	
		local unitsFillTypes = workTool:getFillUnitSupportedFillTypes(i)
		local counter = 0
		local lastCheckedFillType = 1
		for fillType,v in pairs (unitsFillTypes) do
			counter = counter+1
			lastCheckedFillType = fillType
		end
		if counter == 1 and courseplay:getLoadTriggerProvidedFillTypeValid(fillTrigger, lastCheckedFillType) then
			return lastCheckedFillType
		end
	end
end
		
function courseplay:handleUnloading(vehicle,revUnload,dt,reverseCourseUnloadpoint)
	local tipRefpoint = 0
	local stopForTipping = false
	local takeOverSteering = false
	local message = ""
	--print("reverseCourseUnloadpoint: "..tostring(reverseCourseUnloadpoint).."  revUnload: "..tostring(revUnload))

	if (vehicle.cp.isCombine or vehicle.cp.isHarvesterSteerable or vehicle.cp.hasHarvesterAttachable) and vehicle.cp.totalFillLevelPercent > 0 then
		for i=1, #(vehicle.cp.workTools) do
			local workTool = vehicle.cp.workTools[i];
			local combine = vehicle
			if courseplay:isAttachedCombine(workTool) and workTool.cp.hasSpecializationCutter then
				combine = workTool
			end
			if courseplay:isCombine(combine) then			
				if vehicle.cp.previousWaypointIndex == vehicle.cp.unloadPoints[1] then
					local _,y,_ = getWorldTranslation(combine.pipeRaycastNode);
					local _,_,z = worldToLocal(combine.pipeRaycastNode, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cx, y, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cz);
					if z <= 0 then
						stopForTipping = true;
						if combine.pipeCurrentState ~= 2 then
							combine:setPipeState(2);
						end;
						if combine:getCanTipToGround() then
							if not combine.dischargeToGround then
								combine:setDischargeToGround(true);
							end
						end;
						if vehicle.getFirstEnabledFillType and vehicle.pipeParticleSystems and vehicle.cp.totalFillLevelPercent > 0 then
							local filltype = vehicle:getFirstEnabledFillType();
							if filltype ~= FillType.UNKNOWN and vehicle.pipeParticleSystems[filltype] then
								local stopTime = vehicle.pipeParticleSystems[filltype][1].stopTime;
								if stopTime then
									courseplay:setCustomTimer(vehicle, "waitUntilPipeIsEmpty", stopTime);
								end;
							end;
						end;
					end;
				end;
			end;
		end;
	elseif not (vehicle.cp.isCombine or vehicle.cp.isHarvesterSteerable or vehicle.cp.hasHarvesterAttachable) then
		
		for index, tipper in pairs (vehicle.cp.workTools) do
			local goForTipping = false
			if 	tipper.overloading ~= nil then
				tipRefpoint = tipper.pipeRaycastNode
				local _,y,_ = getWorldTranslation(tipper.pipeRaycastNode);
				local _,_,z = worldToLocal(tipper.pipeRaycastNode, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cx, y, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cz);
				if z <= 0 and tipper.cp.fillLevel ~= 0 then
					stopForTipping = true
					goForTipping = true
				end
				if goForTipping and vehicle.getFirstEnabledFillType and vehicle.pipeParticleSystems and vehicle.cp.totalFillLevelPercent > 0 then
					local filltype = vehicle:getFirstEnabledFillType();
					if filltype ~= FillType.UNKNOWN and vehicle.pipeParticleSystems[filltype] then
						local stopTime = vehicle.pipeParticleSystems[filltype][1].stopTime;
						if stopTime then
							courseplay:setCustomTimer(vehicle, "waitUntilPipeIsEmpty", stopTime);
						end;
					end;
				end;
				if goForTipping and not tipper.overloading.isActive then
					if tipper:getCanTipToGround() then
						if not self.dischargeToGround then
							tipper:setDischargeToGround(true)
						end
					else
						tipper:setOverloadingActive(true)
					end
				end
			else
				local x,y,z = 0,0,0
				if revUnload then
					tipRefpoint = tipper.cp.rearTipRefPoint
					if reverseCourseUnloadpoint ~= nil and reverseCourseUnloadpoint > 0 then
						_,y,_ = getWorldTranslation(tipper.cp.realUnloadOrFillNode or tipRefpoint or tipper.rootNode);
						_,_,z = worldToLocal(tipper.cp.realUnloadOrFillNode or tipRefpoint or tipper.rootNode, vehicle.Waypoints[reverseCourseUnloadpoint].cx, y, vehicle.Waypoints[reverseCourseUnloadpoint].cz);
						if not vehicle.cp.lastValidTipDistanceChecked and tipper:getTipState() == Trailer.TIPSTATE_CLOSED then
							courseplay:debug(nameNum(vehicle) .. ": call courseplay:checkValidTipDistance" , 2);
							local trueDistanceToHeap = courseplay:checkValidTipDistance(vehicle,tipper,reverseCourseUnloadpoint)
							if vehicle.cp.lastValidTipDistance == nil or trueDistanceToHeap < vehicle.cp.lastValidTipDistance then
								vehicle.cp.lastValidTipDistance = trueDistanceToHeap;
								courseplay:debug(nameNum(vehicle) .. ": heap found, distance changed",2)
								if vehicle.cp.hud.currentPage == 3 then
									courseplay.hud:setReloadPageOrder(vehicle, 3, true);
								end;
							end
							
						end
						
						
						if vehicle.cp.lastValidTipDistance ~= nil and (z > vehicle.cp.lastValidTipDistance or tipper:getTipState() ~= Trailer.TIPSTATE_CLOSED) and tipper.cp.fillLevel ~= 0 then
							stopForTipping = true
							goForTipping = true
							vehicle.cp.lastValidTipDistanceChecked = nil
						end
						message = "script"					
					else
						_,y,_ = getWorldTranslation(tipper.cp.realUnloadOrFillNode or tipRefpoint or tipper.rootNode);
						_,_,z = worldToLocal(tipper.cp.realUnloadOrFillNode or tipRefpoint, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cx, y, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cz);
						goForTipping = true
						message = "point"
					end
				else
					tipRefpoint = tipper.preferedTipReferencePointIndex
					_,y,_ = getWorldTranslation(tipper.cp.realUnloadOrFillNode or tipRefpoint or tipper.rootNode);
					_,_,z = worldToLocal(tipper.cp.realUnloadOrFillNode or tipRefpoint or tipper.rootNode, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cx, y, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cz);
					if z <= 0 and tipper.cp.fillLevel ~= 0 then
						stopForTipping = true
						goForTipping = true
					end					
				end
				
				--print(string.format("tipper.couldNotDropTimer: %s; goForTipping: %s",tostring(tipper.couldNotDropTimer),tostring(goForTipping)))
				
				if (tipper:getTipState() == Trailer.TIPSTATE_CLOSED or tipper:getTipState() == Trailer.TIPSTATE_CLOSING) and goForTipping then
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
					--print("toggeltipstate by "..message)
				end
				
				takeOverSteering = courseplay:manageCompleteTipping(vehicle,tipper,dt,z)
				
				--finsh and go for next round
				if (tipper:getTipState() == Trailer.TIPSTATE_OPEN or tipper:getTipState() == Trailer.TIPSTATE_OPENING) and tipper.cp.fillLevel == 0 then
					tipper:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
					vehicle.cp.takeOverSteering = false
					if revUnload then
						courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
						vehicle.cp.ppc:initialize()
					end				
				end			
				
			end
		end
	end
	if vehicle.cp.totalFillLevel == 0 and courseplay:timerIsThrough(vehicle, "waitUntilPipeIsEmpty") then
		courseplay:resetCustomTimer(vehicle, "waitUntilPipeIsEmpty", true);
		courseplay:setVehicleWait(vehicle, false);
		if vehicle.cp.isCombine and vehicle.pipeCurrentState ~= 0 then
			vehicle:setPipeState(0);
		end;
	end
	return stopForTipping,takeOverSteering
end

function courseplay:checkValidTipDistance(vehicle,tipper,reverseCourseUnloadpoint)
	local trueDistanceToHeap = 0
	local startX,startY,startZ = getWorldTranslation(tipper.cp.realUnloadOrFillNode or tipRefpoint or tipper.rootNode);
	local p2x,p2y,p2z = vehicle.Waypoints[reverseCourseUnloadpoint].cx, 0, vehicle.Waypoints[reverseCourseUnloadpoint].cz
	p2y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,p2x,0,p2z)
	local basicDistance = -courseplay:distance3D(startX,startY,startZ,p2x,p2y,p2z)
	local searchWidth = 3
	for i=0,basicDistance,-0.5 do
		local tempHeightX,tempHeightY,tempHeightZ = localToWorld(tipper.cp.realUnloadOrFillNode,0,0,i) --local tx1, ty1, tz1 = localToWorld(directionNode,3,1,self.cp.aiFrontMarker)
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(startX,startY,startZ,tempHeightX,tempHeightY,tempHeightZ, searchWidth)
		if fillType == tipper.cp.fillType then
			trueDistanceToHeap = basicDistance-i;
			break;
		end
	end
	
	vehicle.cp.lastValidTipDistanceChecked =true
	return trueDistanceToHeap;
end


function courseplay:handleHeapUnloading(vehicle)
	--Todo right now it starts when tractor is under unload point. Be nice if pipe was under
	local stopForUnload = false;
	--For Mode 7 Has workTools is empty
	if #(vehicle.cp.workTools) == 0 then
		vehicle.cp.workTools[1] = vehicle
	end;
	for i=1, #(vehicle.cp.workTools) do
		local workTool = vehicle.cp.workTools[i];
		local combine = vehicle
		if workTool and courseplay:isAttachedCombine(workTool) then
			combine = workTool
		end
		if courseplay:isCombine(combine) then
			if vehicle.cp.makeHeaps then
				if (vehicle.cp.waypointIndex + 1) == vehicle.cp.heapStart and combine.pipeCurrentState ~= 2 then
					combine:setPipeState(2);
				end
				if vehicle.cp.previousWaypointIndex == vehicle.cp.heapStart then
					if combine.cp.fillLevel > 0 then
						if combine:getCanTipToGround() then
							if not combine.dischargeToGround then
								combine:setDischargeToGround(true);
								vehicle.cp.speeds.discharge = courseplay:getDischargeSpeed(vehicle, combine);
								courseplay:setVehicleWait(vehicle, false);
							end;
						else
							stopForUnload = true;
							-- TODO show message "not able to discharge"
						end;
					end;
				end;
				if vehicle.cp.previousWaypointIndex > vehicle.cp.heapStart and vehicle.cp.previousWaypointIndex < vehicle.cp.heapStop then
					-- Set Timer if unloading pipe takes time before empty.
					if vehicle.getFirstEnabledFillType and vehicle.pipeParticleSystems and vehicle.cp.totalFillLevelPercent > 0 then
						local filltype = vehicle:getFirstEnabledFillType();
						if filltype ~= FillType.UNKNOWN and vehicle.pipeParticleSystems[filltype] then
							local stopTime = vehicle.pipeParticleSystems[filltype][1].stopTime;
							if stopTime then
								courseplay:setCustomTimer(vehicle, "waitUntilPipeIsEmpty", stopTime);
							end;
						end;
					end;
				end;
				if vehicle.cp.previousWaypointIndex == vehicle.cp.heapStop then
					if combine.cp.fillLevel > 0 then
						stopForUnload = true;
						-- Set Timer if unloading pipe takes time before empty.
						if vehicle.getFirstEnabledFillType and vehicle.pipeParticleSystems and vehicle.cp.totalFillLevelPercent > 0 then
							local filltype = vehicle:getFirstEnabledFillType();
							if filltype ~= FillType.UNKNOWN and vehicle.pipeParticleSystems[filltype] then
								local stopTime = vehicle.pipeParticleSystems[filltype][1].stopTime;
								if stopTime then
									courseplay:setCustomTimer(vehicle, "waitUntilPipeIsEmpty", stopTime);
								end;
							end;
						end;
					elseif courseplay:timerIsThrough(vehicle, "waitUntilPipeIsEmpty") then
						courseplay:resetCustomTimer(vehicle, "waitUntilPipeIsEmpty", true);
						courseplay:setVehicleWait(vehicle, false);
					elseif combine.pipeCurrentState ~= 0 then
						combine:setPipeState(0);
					end;
				end;		
			end;
		end;
	end;
	return stopForUnload;
end;

function courseplay:getDischargeSpeed(vehicle, combine)
	courseplay:debug(nameNum(vehicle) .. ":getDischargeSpeed()", 11);
	local refSpeed = 0

	local sx,sz = vehicle.Waypoints[vehicle.cp.heapStart].cx, vehicle.Waypoints[vehicle.cp.heapStart].cz;
	local ex,ez = vehicle.Waypoints[vehicle.cp.heapStop].cx, vehicle.Waypoints[vehicle.cp.heapStop].cz;
	local length = courseplay:distance(sx,sz, ex,ez)*.8  --just to be sure, that we will get all in...
	courseplay:debug(nameNum(vehicle) .. ":  TipRange length: "..tostring(length), 11);

	-- 1.25s Seems to be the correct vaule for discharge speed of all combines tested
	-- added overloading delay has that varies from combine to combine
	local completeTipDuration = (combine.cp.fillLevel/combine.overloading.capacity) * 1.25 + (combine.overloading.delay.time/1000)
	courseplay:debug(nameNum(vehicle) .. ":  complete tip duration: "..tostring(completeTipDuration), 11);

	local meterPrSeconds = length / completeTipDuration;
	refSpeed =  meterPrSeconds * 3.6
	courseplay:debug(nameNum(vehicle) .. ":  refSpeed: "..tostring(refSpeed), 11);

	return refSpeed
end

function courseplay:manageCompleteTipping(vehicle,tipper,dt,zSent)
	local node = tipper.cp.realUnloadOrFillNode or tipper.rootNode;
	local _,y,_ = getWorldTranslation(node);
	local z 
	if zSent ~= nil then
		z = zSent
	else	
		_,_,z = worldToLocal(node, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cx, y, vehicle.Waypoints[vehicle.cp.previousWaypointIndex].cz);
	end
	local isTipping = tipper.spec_dischargeable.currentRaycastDischargeNode.isEffectActive
	if tipper:getTipState() == Trailer.TIPSTATE_OPEN and not isTipping then
		vehicle.cp.takeOverSteering = true
		if vehicle.cp.settings.saveFuelOption:is(true) then
			courseplay:setCustomTimer(vehicle,'fuelSaveTimer',30)
		end
		
	end		
	
	
	if g_updateLoopIndex % 100 == 0 and (tipper:getTipState() == Trailer.TIPSTATE_OPEN or tipper:getTipState() == Trailer.TIPSTATE_OPENING) and isTipping and vehicle.cp.takeOverSteering then
		vehicle.cp.takeOverSteering = false	
		vehicle.cp.lastValidTipDistance = z or 0
		--print("reset takeOverSteering z= "..tostring(z).." Zsent: "..tostring(zSent))
		
		--refresh HUD
		if vehicle.cp.hud.currentPage == 3 then
			courseplay.hud:setReloadPageOrder(vehicle, 3, true);
		end;
		
	end
	
	if vehicle.cp.takeOverSteering then
		local fwdWayoint = courseplay:getNextFwdPoint(vehicle)
		local x,z = vehicle.Waypoints[fwdWayoint].cx, vehicle.Waypoints[fwdWayoint].cz;
		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
		local lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.directionNode, x, y, z);
		AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, 1, 0.5, 10, true, true, lx, lz, 5, 1)
	end
	return vehicle.cp.takeOverSteering
end

function courseplay:sugarCaneTrailerToggleTipstate()
	--print(nameNum(self)..": courseplay:sugarCaneTrailerToggleTipstate() called by: "..courseplay.utils:getFnCallPath(2))
	if self.tipState < Trailer.TIPSTATE_OPEN then
		self.tipState = Trailer.TIPSTATE_OPENING
	else
		self.tipState = Trailer.TIPSTATE_CLOSING
	end
end

function courseplay:updateSugarCaneTrailerTipping(vehicle,dt)
	for _,tipper in pairs(vehicle.cp.workTools) do
		if tipper.cp.isSugarCaneTrailer then
			local movingTools = tipper.movingTools
			if tipper:getTipState() == Trailer.TIPSTATE_OPENING then
				local targetPositions = { 	rot = { [1] = movingTools[1].rotMin},
											trans = { [1] = 0 }
										}
				if courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, nil, targetPositions, dt ,1) then
					tipper.tipState = Trailer.TIPSTATE_OPEN
				end
			elseif tipper:getTipState() == Trailer.TIPSTATE_CLOSING then
				local targetPositions = { 	rot = { [1] = movingTools[1].rotMax},
											trans = { [1] = 0 }
										}
				if courseplay:checkAndSetMovingToolsPosition(vehicle, movingTools, nil, targetPositions, dt ,1) then
					tipper.tipState = Trailer.TIPSTATE_CLOSED
				end
			end
			if tipper:getTipState() == Trailer.TIPSTATE_OPEN and tipper:getFillLevel() == 0 then
				tipper.tipState = Trailer.TIPSTATE_CLOSING
			end
		end
	end	
end

--- Iterator for all work areas of an object
function courseplay:workAreaIterator(object)
	local i = 0
	return function()
		i = i + 1
		local wa = object and object.getWorkAreaByIndex and object:getWorkAreaByIndex(i)
		if wa then return i, wa end
	end
end

function courseplay:hasWorkAreas(object) 
	return object and object.getWorkAreaByIndex and object:getWorkAreaByIndex(1)
end

--- Get the working width of thing. Will return the maximum of the working width of thing and
-- all of its implements
function courseplay:getWorkWidth(thing, logPrefix)
	logPrefix = logPrefix and logPrefix .. '  ' or ''
	courseplay.debugFormat(6,'%s%s: getting working width...', logPrefix, nameNum(thing))
	-- our own width
	local width = courseplay:getAIMarkerWidth(thing, logPrefix)
	if not width then
		width = courseplay:getWorkAreaWidth(thing, logPrefix)
	end
	local implements = thing:getAttachedImplements()
	if implements then
		-- get width of all implements
		for _, implement in ipairs(implements) do
			local specialWorkWidth = courseplay:getSpecialWorkWidth(implement.object);
			if specialWorkWidth and type(specialWorkWidth) == "number" then
				width = math.max( width, specialWorkWidth);
			else
				width = math.max( width, courseplay:getWorkWidth(implement.object, logPrefix))
			end;
		end
	end
	courseplay.debugFormat(6, '%s%s: working width is %.1f', logPrefix, nameNum(thing), width)
	return width
end

function courseplay:getWorkAreaWidth(object, logPrefix)
	logPrefix = logPrefix or ''
	-- TODO: check if there's a better way to find out if the implement has a work area
	local width = 0
	for i, wa in courseplay:workAreaIterator(object) do
		-- work areas are defined by three nodes: start, width and height. These nodes
		-- define a rectangular work area which you can make visible with the
		-- gsVehicleDebugAttributes console command and then pressing F5
		local x, _, _ = localToLocal(wa.width, wa.start, 0, 0, 0)
		width = math.max(width, math.abs(x))
		local _, _, z = localToLocal(wa.height, wa.start, 0, 0, 0)
		courseplay.debugFormat(6, '%s%s: work area %d is %s, %.1f by %.1f m',
			logPrefix, nameNum(object), i, g_workAreaTypeManager.workAreaTypes[wa.type].name, math.abs(x), math.abs(z))
	end
	if width == 0 then
		courseplay.debugFormat(6, '%s%s: has NO work area', logPrefix, nameNum(object))
	end
	return width
end

function courseplay:getAIMarkerWidth(object, logPrefix)
	logPrefix = logPrefix or ''
	if object.getAIMarkers then
		local aiLeftMarker, aiRightMarker = object:getAIMarkers()
		if aiLeftMarker and aiRightMarker then
			local left, _, _ = localToLocal(aiLeftMarker, object.cp.directionNode or object.rootNode, 0, 0, 0);
			local right, _, _ = localToLocal(aiRightMarker, object.cp.directionNode or object.rootNode, 0, 0, 0);
			local width, _, _ = localToLocal(aiLeftMarker, aiRightMarker, 0, 0, 0)
			courseplay.debugFormat( 6, '%s%s aiMarkers: left=%.2f, right=%.2f (width %.2f)', logPrefix, nameNum(object), left, right, width)

			if left < right then
				left, right = right, left -- yes, lua can do this!
				courseplay.debugFormat(6, '%s%s left < right -> switch -> left=%.2f, right=%.2f', logPrefix, nameNum(object), left, right)
			end
			return left - right;
		end
	end
end

function courseplay:getIsToolCombiValidForCpMode(vehicle,cpModeToCheck)
	--5 is always valid
	if cpModeToCheck == 5 then 
		return true;
	end
	local modeValid = false
	if vehicle.cp.workToolAttached then
		for _, workTool in pairs(vehicle.cp.workTools) do
			if courseplay:getIsToolValidForCpMode(workTool,cpModeToCheck) then
				modeValid = true
			end
		end
	end
	if not modeValid then
		modeValid = courseplay:getIsToolValidForCpMode(vehicle,cpModeToCheck)
	end
	return modeValid
end

--- Is this mode valid for the tool?
--- @param workTool table tool to check
--- @param cpModeToCheck number is worktool valid for this mode?
function courseplay:getIsToolValidForCpMode(workTool, cpModeToCheck)
	local modeValid = false
	--Made Mode1 and Mode2 separate check to have a cleaner check for Liquid Trailer.
	if cpModeToCheck == courseplay.MODE_GRAIN_TRANSPORT and (SpecializationUtil.hasSpecialization(Dischargeable ,workTool.specializations) and SpecializationUtil.hasSpecialization(Trailer, workTool.specializations) and not SpecializationUtil.hasSpecialization(Pipe, workTool.specializations) and workTool.cp.capacity and workTool.cp.capacity > 0.1 or SpecializationUtil.hasSpecialization(FillTriggerVehicle, workTool.specializations)) then
		modeValid = true;
	elseif cpModeToCheck == courseplay.MODE_COMBI and SpecializationUtil.hasSpecialization(Dischargeable ,workTool.specializations) and SpecializationUtil.hasSpecialization(Trailer, workTool.specializations) and not SpecializationUtil.hasSpecialization(Pipe, workTool.specializations) and workTool.cp.capacity and workTool.cp.capacity > 0.1 and not SpecializationUtil.hasSpecialization(FillTriggerVehicle, workTool.specializations) then
		modeValid = true;
	elseif cpModeToCheck == courseplay.MODE_OVERLOADER and SpecializationUtil.hasSpecialization(Trailer, workTool.specializations) and SpecializationUtil.hasSpecialization(Pipe, workTool.specializations) then
		modeValid = true
	elseif cpModeToCheck == courseplay.MODE_SEED_FERTILIZE then
		local isSprayer, isSowingMachine = courseplay:isSprayer(workTool), courseplay:isSowingMachine(workTool);
		if isSprayer or isSowingMachine or workTool.cp.isTreePlanter or workTool.cp.isKuhnDC401 or workTool.cp.isKuhnHR4004 then
			modeValid = true;
		end
	elseif cpModeToCheck == courseplay.MODE_FIELDWORK then
		if (courseplay:isBaler(workTool)
			or courseplay:isBaleLoader(workTool)
			or courseplay:isSpecialBaleLoader(workTool)
			or workTool.cp.hasSpecializationPickup
			or workTool.cp.hasSpecializationCultivator
			or courseplay:isCombine(workTool)
			or workTool.cp.hasSpecializationFruitPreparer
			or workTool.cp.hasSpecializationPlow		
			or workTool.cp.hasSpecializationTedder
			or workTool.cp.hasSpecializationWindrower
			or workTool.cp.hasSpecializationWeeder
			or workTool.cp.hasSpecializationCutter
			--or workTool.spec_dischargeable
			or courseplay:isMower(workTool)
			or courseplay:isAttachedCombine(workTool)
			or courseplay:isFoldable(workTool))
			and not courseplay:isSprayer(workTool)
			and not (courseplay:isSowingMachine(workTool) and not workTool.cp.hasSpecializationWeeder)
		then
			modeValid = true;
		end
	elseif cpModeToCheck == 8 and (SpecializationUtil.hasSpecialization(FillTriggerVehicle, workTool.specializations) or SpecializationUtil.hasSpecialization(Pipe, workTool.specializations) and SpecializationUtil.hasSpecialization(Trailer, workTool.specializations)) then

		modeValid = true;

	elseif cpModeToCheck == courseplay.MODE_SHOVEL_FILL_AND_EMPTY and courseplay:hasShovel(workTool) then
		modeValid = true;
	
	elseif cpModeToCheck == courseplay.MODE_BUNKERSILO_COMPACTER and (courseplay:hasLeveler(workTool) or courseplay:hasBunkerSiloCompacter(workTool)) then
		modeValid = true;

	end
	return modeValid ;
end

function courseplay:updateFillLevelsAndCapacities(vehicle)
	courseplay:setOwnFillLevelsAndCapacities(vehicle,vehicle.cp.mode)
	vehicle.cp.totalFillLevel = vehicle.cp.fillLevel;
	vehicle.cp.totalCapacity = vehicle.cp.capacity;
	vehicle.cp.totalSeederFillLevel = vehicle.cp.seederFillLevel
	vehicle.cp.totalSeederCapacity = vehicle.cp.seederCapacity
	vehicle.cp.totalSprayerFillLevel = vehicle.cp.sprayerFillLevel
	vehicle.cp.totalSprayerCapacity = vehicle.cp.sprayerCapacity
	if vehicle.cp.totalSprayerFillLevel ~= nil and vehicle.cp.sprayerCapacity ~= nil then
		vehicle.cp.totalSprayerFillLevelPercent = (vehicle.cp.totalSprayerFillLevel*100)/vehicle.cp.totalSprayerCapacity
	end
	if vehicle.cp.fillLevel ~= nil and vehicle.cp.capacity ~= nil then
		vehicle.cp.totalFillLevelPercent = (vehicle.cp.fillLevel*100)/vehicle.cp.capacity;
	end
	--print(string.format("vehicle itself(%s): vehicle.cp.totalFillLevel:(%s)",tostring(vehicle:getName()),tostring(vehicle.cp.totalFillLevel)))
	--print(string.format("vehicle itself(%s): vehicle.cp.totalCapacity:(%s)",tostring(vehicle:getName()),tostring(vehicle.cp.totalCapacity)))
	if vehicle.cp.workTools ~= nil then
		for _,tool in pairs(vehicle.cp.workTools) do
			local hasMoreFillUnits = courseplay:setOwnFillLevelsAndCapacities(tool,vehicle.cp.mode)
			if hasMoreFillUnits and tool ~= vehicle then
				vehicle.cp.totalFillLevel = (vehicle.cp.totalFillLevel or 0) + tool.cp.fillLevel
				vehicle.cp.totalCapacity = (vehicle.cp.totalCapacity or 0 ) + tool.cp.capacity
				vehicle.cp.totalFillLevelPercent = (vehicle.cp.totalFillLevel*100)/vehicle.cp.totalCapacity;
				--print(string.format("%s: adding %s to vehicle.cp.totalFillLevel = %s",tostring(tool:getName()),tostring(tool.cp.fillLevel), tostring(vehicle.cp.totalFillLevel)))
				--print(string.format("%s: adding %s to vehicle.cp.totalCapacity = %s",tostring(tool:getName()),tostring(tool.cp.capacity), tostring(vehicle.cp.totalCapacity)))
				if tool.spec_sowingMachine ~= nil or tool.cp.isTreePlanter then
					vehicle.cp.totalSeederFillLevel = (vehicle.cp.totalSeederFillLevel or 0) + tool.cp.seederFillLevel
					vehicle.cp.totalSeederCapacity = (vehicle.cp.totalSeederCapacity or 0) + tool.cp.seederCapacity
					vehicle.cp.totalSeederFillLevelPercent = (vehicle.cp.totalSeederFillLevel*100)/vehicle.cp.totalSeederCapacity
					--print(string.format("%s:  vehicle.cp.totalSeederFillLevel:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSeederFillLevel)))
					--print(string.format("%s:  vehicle.cp.totalSeederCapacity:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSeederCapacity)))
				end
				if tool.spec_sprayer ~= nil then
					vehicle.cp.totalSprayerFillLevel = (vehicle.cp.totalSprayerFillLevel or 0) + tool.cp.sprayerFillLevel
					vehicle.cp.totalSprayerCapacity = (vehicle.cp.totalSprayerCapacity or 0) + tool.cp.sprayerCapacity
					vehicle.cp.totalSprayerFillLevelPercent = (vehicle.cp.totalSprayerFillLevel*100)/vehicle.cp.totalSprayerCapacity
					--print(string.format("%s:  vehicle.cp.totalSprayerFillLevel:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSprayerFillLevel)))
					--print(string.format("%s:  vehicle.cp.totalSprayerCapacity:%s",tostring(vehicle:getName()),tostring(vehicle.cp.totalSprayerCapacity)))
				end
			end
		end
	end
	--print(string.format("End of function: vehicle.cp.totalFillLevel:(%s)",tostring(vehicle.cp.totalFillLevel)))
end

function courseplay:setOwnFillLevelsAndCapacities(workTool,mode)
	local fillLevel, capacity = 0,0
	local fillLevelPercent = 0;
	local fillType = 0;
	if workTool.getFillUnits == nil then
		return false
	end
	local fillUnits = workTool:getFillUnits()
	for index,fillUnit in pairs(fillUnits) do
		if mode == 10 and workTool.cp.hasSpecializationLeveler then
			if not workTool.cp.originalCapacities then
				workTool.cp.originalCapacities = {}
				workTool.cp.originalCapacities[index]= fillUnit.capacity
			end
		end
		-- TODO: why not fillUnit.fillType == FillType.DIESEL? answer: because you may have diesel in your trailer
		if workTool.getConsumerFillUnitIndex and (index == workTool:getConsumerFillUnitIndex(FillType.DIESEL)
				or index == workTool:getConsumerFillUnitIndex(FillType.DEF)
				or index == workTool:getConsumerFillUnitIndex(FillType.AIR))
				or fillUnit.capacity > 999999 then
		else

			fillLevel = fillLevel + fillUnit.fillLevel
			capacity = capacity + fillUnit.capacity
			if fillLevel ~= nil and capacity ~= nil then
				fillLevelPercent = (fillLevel*100)/capacity;
			else
				fillLevelPercent = nil
			end
			fillType = fillUnit.lastValidFillType
			if workTool.cp.isTreePlanter  then
				local hired = true
				if workTool.mountedSaplingPallet == nil then
					workTool.cp.seederFillLevel = 0
					hired = false;
				else
					workTool.cp.seederFillLevel = fillUnit.fillLevel
				end;
				if workTool.attacherVehicle ~= nil and workTool.attacherVehicle.isHired ~= hired and workTool.attacherVehicle.cp.isDriving then
					workTool.attacherVehicle.isHired = hired;
				end
				workTool.cp.seederCapacity = fillUnit.capacity
				workTool.cp.seederFillLevelPercent = (fillUnit.fillLevel*100)/fillUnit.capacity;
			end
			if workTool.spec_sowingMachine ~= nil and index == workTool.spec_sowingMachine.fillUnitIndex then
				workTool.cp.seederFillLevel = fillUnit.fillLevel
				--print(string.format("%s: adding %s to workTool.cp.seederFillLevel",tostring(workTool:getName()),tostring(fillUnit.fillLevel)))
				workTool.cp.seederCapacity = fillUnit.capacity
				--print(string.format("%s: adding %s to workTool.cp.seederCapacity",tostring(workTool:getName()),tostring(fillUnit.capacity)))
				if g_currentMission.missionInfo.helperBuySeeds then
					workTool.cp.seederFillLevel = 100
					workTool.cp.seederCapacity = 100
				end
				workTool.cp.seederFillLevelPercent = (fillUnit.fillLevel*100)/fillUnit.capacity;
			end
			if workTool.spec_sprayer ~= nil and index == workTool.spec_sprayer.fillUnitIndex then
				workTool.cp.sprayerFillLevel = fillUnit.fillLevel
				--print(string.format("%s: adding %s to workTool.cp.sprayerFillLevel",tostring(workTool:getName()),tostring(fillUnit.fillLevel)))
				workTool.cp.sprayerCapacity = fillUnit.capacity
				--print(string.format("%s: adding %s to workTool.cp.sprayerCapacity",tostring(workTool:getName()),tostring(fillUnit.capacity)))

				if courseplay:isSprayer(workTool) then
					if (workTool.cp.isLiquidManureSprayer and g_currentMission.missionInfo.helperSlurrySource == 2)
							or (workTool.cp.isManureSprayer and g_currentMission.missionInfo.helperManureSource == 2)
							or (g_currentMission.missionInfo.helperBuyFertilizer and not workTool.cp.isLiquidManureSprayer and not workTool.cp.isManureSprayer)
					then
						workTool.cp.sprayerFillLevel = 100
						workTool.cp.sprayerCapacity = 100
					end
				end
				workTool.cp.sprayerFillLevelPercent = (fillUnit.fillLevel*100)/fillUnit.capacity;
			end
		end
	end

	workTool.cp.fillLevel = fillLevel
	workTool.cp.capacity = capacity
	workTool.cp.fillLevelPercent = fillLevelPercent
	workTool.cp.fillType = fillType
	--print(string.format("%s: adding %s to workTool.cp.fillLevel",tostring(workTool:getName()),tostring(workTool.cp.fillLevel)))
	--print(string.format("%s: adding %s to workTool.cp.capacity",tostring(workTool:getName()),tostring(workTool.cp.capacity)))
	return true
end

function courseplay:checkFuel(vehicle, lx, lz,allowedToDrive)
	if vehicle.getConsumerFillUnitIndex ~= nil then
		local isFilling = false
		local dieselIndex = vehicle:getConsumerFillUnitIndex(FillType.DIESEL)
		local currentFuelPercentage = vehicle:getFillUnitFillLevelPercentage(dieselIndex) * 100;
		local searchForFuel = not vehicle.isFuelFilling and (vehicle.cp.settings.allwaysSearchFuel:is(true) and currentFuelPercentage < 99 or currentFuelPercentage < 20);
		if searchForFuel and not vehicle.cp.fuelFillTrigger then
			local nx, ny, nz = localDirectionToWorld(vehicle.cp.directionNode, lx, 0, lz);
			local tx, ty, tz = getWorldTranslation(vehicle.cp.directionNode)
			courseplay:doTriggerRaycasts(vehicle, 'fuelTrigger', 'fwd', true, tx, ty, tz, nx, ny, nz);
		end

		if vehicle.cp.fuelFillTrigger then
			local trigger = courseplay.triggers.fillTriggers[vehicle.cp.fuelFillTrigger]
			if trigger ~= nil and courseplay:fillTypesMatch(vehicle, trigger, vehicle, dieselIndex) then
				allowedToDrive,isFilling = courseplay:fillOnTrigger(vehicle,vehicle,vehicle.cp.fuelFillTrigger)
			else
				vehicle.cp.fuelFillTrigger = nil
			end
		end
		if currentFuelPercentage < 5 then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(vehicle, 'FUEL_MUST');
		elseif currentFuelPercentage < 20 and not vehicle.isFuelFilling then
			CpManager:setGlobalInfoText(vehicle, 'FUEL_SHOULD');
		elseif isFilling and currentFuelPercentage < 99.99 then
			allowedToDrive = false;
			CpManager:setGlobalInfoText(vehicle, 'FUEL_IS');
		end;
	end
	return allowedToDrive;
end

function courseplay:openCloseCover(vehicle, showCover, fillTrigger)
	if vehicle.cp.settings.automaticCoverHandling:is(false)then
		return
	end

	for i,twc in pairs(vehicle.cp.tippersWithCovers) do
		local tIdx, coverType, showCoverWhenTipping, coverItems = twc.tipperIndex, twc.coverType, twc.showCoverWhenTipping, twc.coverItems;
		local tipper = vehicle.cp.workTools[tIdx];
		local numCovers = #tipper.spec_cover.covers
		-- default Giants trailers
		if coverType == 'defaultGiants' then
			--open cover
			if not showCover then
				--we have more covers, open the one related to the fillUnit
				if numCovers > 1 and (courseplay:isSprayer(tipper) or courseplay:isSowingMachine(tipper)) and fillTrigger then
					local fillUnits = tipper:getFillUnits()
					for i=1,#fillUnits do
						if courseplay:fillTypesMatch(vehicle, fillTrigger, tipper, i) then
							local cover = tipper:getCoverByFillUnitIndex(i)
							if tipper.spec_cover.state ~= cover.index then
								tipper:setCoverState(cover.index ,true);
							end
						end
					end
				else
					--we have just one, easy going
					local newState = 1
					if tipper.spec_cover.state ~= newState and tipper:getIsNextCoverStateAllowed(newState) then
						tipper:setCoverState(newState,true);
					end
				end
			else --showCover
				local newState = 0
				if tipper.spec_cover.state ~= newState then
					if tipper:getIsNextCoverStateAllowed(newState) then
						tipper:setCoverState(newState,true);
					else
						for i=tipper.spec_cover.state,numCovers do
							if tipper:getIsNextCoverStateAllowed(i+1)then
								tipper:setCoverState(i+1,true);
							end
							if tipper:getIsNextCoverStateAllowed(newState) then
								tipper:setCoverState(newState,true);
								break
							end
						end
					end;
				end
			end



			-- Example: for mods trailer that don't use the default cover specialization
		else--if coverType == 'CoverVehicle' then
			--for _,ci in pairs(coverItems) do
			--	if getVisibility(ci) ~= showCover then
			--		setVisibility(ci, showCover);
			--	end;
			--end;
			--if showCoverWhenTipping and isAtTipTrigger and not showCover then
			--
			--else
			--	tipper:setPlane(not showCover);
			--end;
		end;
	end; --END for i,tipperWithCover in vehicle.cp.tippersWithCovers
end;
