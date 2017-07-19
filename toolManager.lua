local abs, cos, sin, min, max, deg = math.abs, math.cos, math.sin, math.min, math.max, math.deg;
local _;
-- ##### MANAGING TOOLS ##### --

function courseplay:attachImplement(implement)
	--- Update Vehicle
	local workTool = implement.object;
	if workTool.attacherVehicle.cp.hasSpecializationSteerable then
		workTool.attacherVehicle.cp.tooIsDirty = true;
	end;
	courseplay:setAttachedCombine(self);
end;

AIVehicle.onAttachImplement = Utils.appendedFunction(AIVehicle.onAttachImplement, courseplay.attachImplement);


function courseplay:detachImplement(implementIndex)
	--- Update Vehicle
	self.cp.tooIsDirty = true;
	if self.attachedImplements[implementIndex].object == self.cp.attachedCombine then
		self.cp.attachedCombine = nil;
		courseplay:setMinHudPage(self);
	end
end;
AIVehicle.onDetachImplement = Utils.appendedFunction(AIVehicle.onDetachImplement, courseplay.detachImplement);


function courseplay:resetTools(vehicle)
	vehicle.cp.workTools = {}
	-- are there any tippers?
	vehicle.cp.hasAugerWagon = false;
	vehicle.cp.workToolAttached = courseplay:updateWorkTools(vehicle, vehicle);

	-- Reset fill type.
	if #vehicle.cp.workTools > 0 and vehicle.cp.workTools[1].cp.hasSpecializationFillable and vehicle.cp.workTools[1].allowFillFromAir and vehicle.cp.workTools[1].allowTipDischarge then
		if vehicle.cp.siloSelectedFillType == FillUtil.FILLTYPE_UNKNOWN or (vehicle.cp.siloSelectedFillType ~= FillUtil.FILLTYPE_UNKNOWN and not vehicle.cp.workTools[1]:allowFillType(vehicle.cp.siloSelectedFillType)) then
			vehicle.cp.siloSelectedFillType = vehicle.cp.workTools[1]:getFirstEnabledFillType();
		end;
	else
		vehicle.cp.siloSelectedFillType = FillUtil.FILLTYPE_UNKNOWN;
	end;
	if vehicle.cp.hud.currentPage == 1 then
		courseplay.hud:setReloadPageOrder(vehicle, 1, true);
	end;

	vehicle.cp.easyFillTypeList = courseplay:getEasyFillTypeList(courseplay:getAllAvalibleFillTypes(vehicle));
	vehicle.cp.siloSelectedEasyFillType = 0;
	courseplay:changeSiloFillType(vehicle, 1, vehicle.cp.siloSelectedFillType);

	courseplay:calculateWorkWidth(vehicle, true);

	vehicle.cp.currentTrailerToFill = nil;
	vehicle.cp.trailerFillDistance = nil;
	vehicle.cp.tooIsDirty = false;
end;

function courseplay:changeSiloFillType(vehicle, modifyer, currentSelectedFilltype)
	local eftl = vehicle.cp.easyFillTypeList;
	local newVal = 1;
	if currentSelectedFilltype and currentSelectedFilltype ~= FillUtil.FILLTYPE_UNKNOWN then
		for index, fillType in ipairs(eftl) do
			if currentSelectedFilltype == fillType then
				newVal = index;
			end;
		end;
	else
		newVal = vehicle.cp.siloSelectedEasyFillType + modifyer
		if newVal < 1 then
			newVal = #eftl;
		elseif newVal > #eftl then
			newVal = 1;
		end
	end;
	if vehicle.cp.siloSelectedFillType ~= eftl[newVal] then
 		--Mode 1 Run Counter Reset
 		vehicle.cp.runCounter = 0;
 		courseplay:changeRunCounter(vehicle, false)
 	end
	vehicle.cp.siloSelectedEasyFillType = newVal;
	vehicle.cp.siloSelectedFillType = eftl[newVal];
end;

function courseplay:getAvalibleFillTypes(object, fillUnitIndex)
	if fillUnitIndex == nil then
		local fillTypes = {}
		if object.fillUnits then
			for _, fillUnit in pairs(object.fillUnits) do
				for fillType, enabled in pairs(fillUnit.fillTypes) do
					if fillType ~= FillUtil.FILLTYPE_UNKNOWN and enabled then
						fillTypes[fillType] = enabled;
					end;
				end;
			end;
		end;
		return fillTypes;
	end;
    return object.fillUnits[fillUnitIndex].fillTypes;
end;

function courseplay:getAllAvalibleFillTypes(vehicle)
	local fillTypes = {};
	if #vehicle.cp.workTools > 0 then
	    for _, workTool in pairs(vehicle.cp.workTools) do
		    local toolFillTypes = courseplay:getAvalibleFillTypes(workTool);
			for fillType, enabled in pairs(toolFillTypes) do
				if fillType ~= FillUtil.FILLTYPE_UNKNOWN and enabled then
					fillTypes[fillType] = enabled;
				end;
			end
		end;
	end;
	return fillTypes;
end;

function courseplay:getEasyFillTypeList(fillTypes)
	local easyFillTypeList = {};
	for fillType, _ in pairs(fillTypes) do
		table.insert(easyFillTypeList, fillType);
	end;
	return easyFillTypeList;
end;

function courseplay:isAttachedCombine(workTool)
	return (workTool.typeName~= nil and (workTool.typeName == 'attachableCombine' or workTool.typeName == 'attachableCombine_mouseControlled')) or (not workTool.cp.hasSpecializationSteerable and workTool.hasPipe and not workTool.cp.isAugerWagon and not workTool.cp.isLiquidManureOverloader) or courseplay:isSpecialChopper(workTool)
end;
function courseplay:isAttachedMixer(workTool)
	return workTool.typeName == "mixerWagon" or (not workTool.cp.hasSpecializationSteerable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isAttacherModule(workTool)
	if workTool.attacherJoint then
		return (workTool.attacherJoint.jointType == AttacherJoints.JOINTTYPE_SEMITRAILER and (not workTool.wheels or (workTool.wheels and #workTool.wheels == 0))) or workTool.cp.isAttacherModule == true;
	end;
	return false;
end;
function courseplay:isBaleLoader(workTool) -- is the tool a bale loader?
	return workTool.cp.hasSpecializationBaleLoader or (workTool.balesToLoad ~= nil and workTool.baleGrabber ~=nil and workTool.grabberIsMoving~= nil);
end;
function courseplay:isBaler(workTool) -- is the tool a baler?
	return workTool.cp.hasSpecializationBaler or workTool.balerUnloadingState ~= nil or courseplay:isSpecialBaler(workTool);
end;
function courseplay:isBigM(workTool)
	return workTool.cp.hasSpecializationSteerable and courseplay:isMower(workTool);
end;
function courseplay:isCombine(workTool)
	return workTool.cp.hasSpecializationCombine and workTool.attachedCutters ~= nil and workTool.cp.capacity ~= nil  and workTool.cp.capacity > 0;
end;
function courseplay:isChopper(workTool)
	return workTool.cp.hasSpecializationCombine and workTool.attachedCutters ~= nil and workTool.cp.capacity == 0 or courseplay:isSpecialChopper(workTool);
end;
function courseplay:isFoldable(workTool) --is the tool foldable?
	return workTool.cp.hasSpecializationFoldable and  workTool.foldingParts ~= nil and #workTool.foldingParts > 0;
end;
function courseplay:isFrontloader(workTool)
	return workTool.cp.hasSpecializationCylindered and workTool.cp.hasSpecializationAnimatedVehicle and not workTool.cp.hasSpecializationShovel;
end;
function courseplay:isHarvesterSteerable(workTool)
	return Utils.getNoNil(workTool.typeName == "selfPropelledPotatoHarvester" or workTool.cp.isHarvesterSteerable, false);
end;
function courseplay:isHarvesterAttachable(workTool)
	return Utils.getNoNil(workTool.cp.isHarvesterAttachable, false);
end;
function courseplay:isHookLift(workTool)
	if workTool.attacherJoint then
		return workTool.attacherJoint.jointType == AttacherJoints.JOINTTYPE_HOOKLIFT;
	end;
	return false;
end
function courseplay:isMixer(workTool)
	return workTool.typeName == "selfPropelledMixerWagon" or (workTool.cp.hasSpecializationSteerable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isMower(workTool)
	return workTool.cp.hasSpecializationMower or courseplay:isSpecialMower(workTool);
end;
function courseplay:isRoundbaler(workTool) -- is the tool a roundbaler?
	return courseplay:isBaler(workTool) and workTool.baler ~= nil and (workTool.baler.baleCloseAnimationName ~= nil and workTool.baler.baleUnloadAnimationName ~= nil or courseplay:isSpecialRoundBaler(workTool));
end;
function courseplay:isSowingMachine(workTool) -- is the tool a sowing machine?
	return workTool.cp.hasSpecializationSowingMachine or courseplay:isSpecialSowingMachine(workTool);
end;
function courseplay:isSpecialChopper(workTool)
	return workTool.typeName == "woodCrusherTrailer" or workTool.cp.isPoettingerMex5
end
function courseplay:isSprayer(workTool) -- is the tool a sprayer/spreader?
	return workTool.cp.hasSpecializationSprayer or courseplay:isSpecialSprayer(workTool)
end;
function courseplay:isWheelloader(workTool)
	return workTool.typeName:match("wheelLoader");
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
		if workTool.allowTipDischarge and workTool.cp.capacity and workTool.cp.capacity > 0.1 then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			if workTool.cp.isAugerWagon then
				vehicle.cp.hasAugerWagon = true;
			end;
		end;

	-- MODE 3: AUGERWAGON
	elseif vehicle.cp.mode == 3 then
		if workTool.cp.isAugerWagon then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			vehicle.cp.hasAugerWagon = true;
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
		or workTool.cp.hasSpecializationCutter
		or workTool.cp.hasSpecializationFruitPreparer 
		or workTool.cp.hasSpecializationPlough
		or workTool.cp.hasSpecializationTedder
		or workTool.cp.hasSpecializationWindrower
		or workTool.allowTipDischarge 
		or courseplay:isMower(workTool)
		or courseplay:isAttachedCombine(workTool) 
		or courseplay:isFoldable(workTool))
		and not courseplay:isSprayer(workTool)
		and not courseplay:isSowingMachine(workTool)
		then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			courseplay:setMarkers(vehicle, workTool);
			vehicle.cp.noStopOnTurn = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or vehicle.attachedCutters ~= nil;
			vehicle.cp.noStopOnEdge = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or vehicle.attachedCutters ~= nil;
			if workTool.cp.hasSpecializationPlough then 
				vehicle.cp.hasPlough = true;
				if workTool.rotationPart.turnAnimation ~= nil then
					vehicle.cp.hasRotateablePlough = true;
				end;
			end;
			if courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) then
				vehicle.cp.hasBaleLoader = true;
			end;
			if courseplay:isHarvesterAttachable(workTool) then
				vehicle.cp.hasHarvesterAttachable = true;
			end;
			if courseplay:isSpecialChopper(workTool) then
				vehicle.cp.hasSpecialChopper = true;
			end;
		end;

	-- MODE 7: COMBINE SELF UNLOADING
	elseif vehicle.cp.mode == 7 then
		-- DO NOTHING

	-- MODE 8: LIQUID MANURE TRANSFER
	elseif vehicle.cp.mode == 8 then
		if workTool.cp.hasSpecializationFillable and ((workTool.overloading ~= nil or workTool.setIsReFilling ~= nil) or workTool.cp.isFuelTrailer or workTool.cp.isWaterTrailer) then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			vehicle.cp.hasMachinetoFill = true;
			workTool.cp.waterReceiverTrigger = nil; -- water trailer: make sure it has no saved unloading water trigger
		end;
		hasWaterTrailer = workTool.cp.isWaterTrailer
	-- MODE 9: FILL AND EMPTY SHOVEL
	elseif vehicle.cp.mode == 9 then
		if not isImplement and (courseplay:isWheelloader(workTool) or workTool.typeName == 'frontloader' or courseplay:isMixer(workTool)) then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			workTool.cp.shovelState = 1;

		elseif isImplement and (courseplay:isFrontloader(workTool) or workTool.cp.hasSpecializationShovel) then 
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			workTool.attacherVehicle.cp.shovelState = 1
		end;
	-- MODE 10:Leveler
	elseif vehicle.cp.mode == 10 then
		if isImplement and workTool.cp.hasSpecializationLeveler then 
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end;
	end;

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
	if not isImplement or workTool.cp.hasSpecializationCutter then
		courseplay:debug(('%s: adding %q (%q) components to cpTrafficCollisionIgnoreList'):format(nameNum(vehicle), nameNum(workTool), tostring(workTool.cp.xmlFileName)), 3);
		for i,component in pairs(workTool.components) do
			vehicle.cpTrafficCollisionIgnoreList[component.node] = true;
		end;
	end;

	-- CHECK ATTACHED IMPLEMENTS
	for k,impl in pairs(workTool.attachedImplements) do
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
        if g_currentMission.nodeToVehicle[ a ] then
          local name = g_currentMission.nodeToVehicle[a].name;
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

function courseplay:setMarkers(vehicle, object)
	local realDirectionNode		= vehicle.isReverseDriving and vehicle.cp.reverseDrivingDirectionNode or vehicle.cp.DirectionNode;
	local aLittleBitMore 		= 1;
	local pivotJointNode 		= courseplay:getPivotJointNode(object);
	object.cp.backMarkerOffset 	= nil;
	object.cp.aiFrontMarker 	= nil;

	-- Get and set vehicle distances if not set
	local vehicleDistances = vehicle.cp.distances or courseplay:getDistances(vehicle);
	-- Get and set object distances if not set
	local objectDistances = object.cp.distances or courseplay:getDistances(object);

	-- get the behindest and the frontest  points :-) ( as offset to root node)
	local area = object.workAreas
	if object.attachedCutters ~= nil and not object.cp.hasSpecializationFruitPreparer and not courseplay:isAttachedCombine(object) then
		courseplay:debug(('%s: setMarkers(): %s is a combine -> return '):format(nameNum(vehicle), tostring(object.name)), 6);
		return;
	end
	
	if not area or object.cp.noWorkArea then
		courseplay:debug(('%s: setMarkers(): %s has no workAreas -> return '):format(nameNum(vehicle), tostring(object.name)), 6);
		return;
	end;

	local tableLength = #(area)
	if tableLength == 0 then
		if courseplay:isWheeledWorkTool(object) and object.attacherJoint.jointType and vehicleDistances.turningNodeToRearTrailerAttacherJoints[object.attacherJoint.jointType] then
			-- Calculate the offset based on the distances
			local ztt = vehicleDistances.turningNodeToRearTrailerAttacherJoints[object.attacherJoint.jointType] * -1;

			local backMarkerCorrection = Utils.getNoNil(object.cp.backMarkerOffsetCorection, 0);
			if vehicle.cp.backMarkerOffset == nil or (abs(backMarkerCorrection) > 0 and  ztt + backMarkerCorrection > vehicle.cp.backMarkerOffset) then
				vehicle.cp.backMarkerOffset = abs(backMarkerCorrection) > 0 and ztt + backMarkerCorrection or 0;
			end

			local frontMarkerCorrection = Utils.getNoNil(object.cp.frontMarkerOffsetCorection, 0);
			if vehicle.cp.aiFrontMarker == nil or (abs(frontMarkerCorrection) > 0 and  ztt + frontMarkerCorrection < vehicle.cp.aiFrontMarker) then
				vehicle.cp.aiFrontMarker = abs(frontMarkerCorrection) > 0 and ztt + frontMarkerCorrection or -3;
			end

			courseplay:debug(('%s: setMarkers(): cp.backMarkerOffset = %s, cp.aiFrontMarker = %s'):format(nameNum(vehicle), tostring(vehicle.cp.backMarkerOffset), tostring(vehicle.cp.aiFrontMarker)), 6);
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

	local avoidType = {
		[WorkArea.AREATYPE_RIDGEMARKER] = true;
		[WorkArea.AREATYPE_MOWERDROP] = true;
		[WorkArea.AREATYPE_WINDROWERDROP] = true;
		[WorkArea.AREATYPE_TEDDERDROP] = true;
	}
	for k = 1, tableLength do
		if not avoidType[area[k].type] then
			for j,node in pairs(area[k]) do
				if j == "start" or j == "height" or j == "width" then
					local x, y, z;
					local ztt = 0;
					local type;

					if pivotJointNode and object.attacherJoint.jointType and vehicleDistances.turningNodeToRearTrailerAttacherJoints[object.attacherJoint.jointType] then
						type = "Pivot Trailer";
						x, y, z = getWorldTranslation(pivotJointNode);

						-- Get the marker offset from the pivot node.
						_, _, ztt = worldToLocal(node, x, y, z);

						-- Calculate the offset based on the distances
						ztt = ((vehicleDistances.turningNodeToRearTrailerAttacherJoints[object.attacherJoint.jointType] + objectDistances.attacherJointToPivot) * -1) - ztt;

					elseif courseplay:isWheeledWorkTool(object) and object.attacherJoint.jointType and vehicleDistances.turningNodeToRearTrailerAttacherJoints[object.attacherJoint.jointType] then
						type = "Trailer";
						x, y, z = getWorldTranslation(object.attacherJoint.node)

						-- Get the marker offset from the pivot node.
						_, _, ztt = worldToLocal(node, x, y, z);

						-- Calculate the offset based on the distances
						ztt = (vehicleDistances.turningNodeToRearTrailerAttacherJoints[object.attacherJoint.jointType] * -1) - ztt;

					else
						type = "Vehicle";
						x, y, z = getWorldTranslation(node);
						_, _, ztt = worldToLocal(realDirectionNode, x, y, z);
					end;

					courseplay:debug(('%s: %s %s Point(%s) %s: ztt = %s'):format(nameNum(vehicle), tostring(object.name), type, tostring(k), tostring(j), tostring(ztt)), 6);
					if object.cp.backMarkerOffset == nil or ztt + Utils.getNoNil(object.cp.backMarkerOffsetCorection, 0) > object.cp.backMarkerOffset then
						object.cp.backMarkerOffset = ztt + Utils.getNoNil(object.cp.backMarkerOffsetCorection, 0);
					end
					if object.cp.aiFrontMarker == nil or ztt + Utils.getNoNil(object.cp.frontMarkerOffsetCorection, 0) < object.cp.aiFrontMarker then
						object.cp.aiFrontMarker = ztt + Utils.getNoNil(object.cp.frontMarkerOffsetCorection, 0);
					end
				end
			end
		else
			courseplay:debug(("%s: Avoiding workArea Type %s"):format(nameNum(vehicle), WorkArea.areaTypeIntToName[area[k].type]), 6);
		end;
	end

	if vehicle.cp.backMarkerOffset == nil or object.cp.backMarkerOffset < (vehicle.cp.backMarkerOffset + aLittleBitMore) then
		vehicle.cp.backMarkerOffset = object.cp.backMarkerOffset - aLittleBitMore;
	end

	if vehicle.cp.aiFrontMarker == nil or object.cp.aiFrontMarker > (vehicle.cp.aiFrontMarker - aLittleBitMore) then
		vehicle.cp.aiFrontMarker = object.cp.aiFrontMarker + aLittleBitMore * 0.75;
	end

	courseplay:debug(('%s: setMarkers(): cp.backMarkerOffset = %s, cp.aiFrontMarker = %s'):format(nameNum(vehicle), tostring(vehicle.cp.backMarkerOffset), tostring(vehicle.cp.aiFrontMarker)), 6);
end;

function courseplay:setFoldedStates(object)
	if courseplay:isFoldable(object) and object.turnOnFoldDirection then
		cpPrintLine(17);
		courseplay:debug(nameNum(object) .. ': setFoldedStates()', 17);

		object.cp.realUnfoldDirection = object.turnOnFoldDirection;
		if object.cp.foldingPartsStartMoveDirection and object.cp.foldingPartsStartMoveDirection ~= 0 and object.cp.foldingPartsStartMoveDirection ~= object.turnOnFoldDirection then
			object.cp.realUnfoldDirection = object.turnOnFoldDirection * object.cp.foldingPartsStartMoveDirection;
		end;

		if object.cp.realUnfoldDirectionIsReversed then
			object.cp.realUnfoldDirection = -object.cp.realUnfoldDirection;
		end;

		courseplay:debug(string.format('startAnimTime=%s, turnOnFoldDirection=%s, foldingPartsStartMoveDirection=%s --> realUnfoldDirection=%s', tostring(object.startAnimTime), tostring(object.turnOnFoldDirection), tostring(object.cp.foldingPartsStartMoveDirection), tostring(object.cp.realUnfoldDirection)), 17);

		for i,foldingPart in pairs(object.foldingParts) do
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
		if workTool.cp.hasSpecializationCover and not workTool.cp.isStrawBlower then
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

		local toolTurnDiameter = courseplay:getHighestToolTurnDiameter(vehicle);

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

	local driveOn = vehicle.cp.isLoaded;

	if not currentTrailer.cp.realUnloadOrFillNode and not driveOn then
		currentTrailer.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(currentTrailer);
		if not currentTrailer.cp.realUnloadOrFillNode then
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
				vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
			else
				driveOn = true;
			end;
		end;
	end;

	if vehicle.cp.tipperLoadMode == 0 and not driveOn then
		if vehicle.cp.waypointIndex == 2 and currentTrailer.cp.currentSiloTrigger == nil then
			--- We must be on an loading point at a field so we stop under wp1 and wait for trailer to be filled up
			vehicle.cp.tipperLoadMode = 2;
		elseif currentTrailer.cp.currentSiloTrigger then
			--- We have an silo trigger, so we go load at silo trigger mode
			vehicle.cp.tipperLoadMode = 1;
		else
			--- We were not able to determ what mode to set, so we move further forward until one is set.
			return allowedToDrive;
		end;
	end;

	local unloadDistance = 1000;
	local trailerX,_,trailerZ = getWorldTranslation(currentTrailer.cp.realUnloadOrFillNode);

	if not driveOn then
		if vehicle.cp.tipperLoadMode == 1 then
			local directionNode = vehicle.aiVehicleDirectionNode or vehicle.cp.DirectionNode;
			local _,vehicleY,_ = getWorldTranslation(directionNode);

			local _,_,z = worldToLocal(directionNode, trailerX, vehicleY, trailerZ);
			vehicle.cp.trailerFillDistance = z + 0.5;

			if currentTrailer.cp.currentSiloTrigger ~= nil then
				local triggerX,_,triggerZ = getWorldTranslation(currentTrailer.cp.currentSiloTrigger.rootNode);
				_,_,unloadDistance = worldToLocal(directionNode, triggerX, vehicleY, triggerZ);
			end;
		elseif vehicle.cp.tipperLoadMode == 2 then
			local cx, cz = vehicle.Waypoints[2].cx, vehicle.Waypoints[2].cz;
			if not vehicle.cp.trailerFillDistance then
				vehicle.cp.trailerFillDistance = courseplay:distance(cx, cz, trailerX, trailerZ) + 0.5;
			end;
			unloadDistance = courseplay:distance(cx, cz, trailerX, trailerZ);
		end;

	end;

	-- SiloTrigger (Giants)
	if vehicle.cp.tipperLoadMode == 1 and currentTrailer.cp.currentSiloTrigger ~= nil and not driveOn then
        local acceptedFillType = false;
		local siloTrigger = currentTrailer.cp.currentSiloTrigger;

		for _, fillType in pairs(siloTrigger.fillTypes) do
			if fillType == vehicle.cp.siloSelectedFillType then
				acceptedFillType = true;
				break;
			end;
		end;

		if acceptedFillType then
			local siloIsEmpty = siloTrigger:getFillLevel(vehicle.cp.siloSelectedFillType) <= 1;

			if not siloTrigger.isFilling and not siloIsEmpty and currentTrailer:allowFillType(vehicle.cp.siloSelectedFillType, false) and unloadDistance < vehicle.cp.trailerFillDistance then
				siloTrigger:startFill(vehicle.cp.siloSelectedFillType);
				courseplay:setCustomTimer(vehicle, 'siloEmptyMessageDelay', 1);
				courseplay:debug(('%s: SiloTrigger: selectedFillType = %s, isFilling = %s'):format(nameNum(vehicle), tostring(FillUtil.fillTypeIntToName[siloTrigger.selectedFillType]), tostring(siloTrigger.isFilling)), 2);
			elseif siloTrigger.isFilling then
				courseplay:setCustomTimer(vehicle, 'siloEmptyMessageDelay', 1);
			elseif siloIsEmpty and vehicle.cp.totalFillLevelPercent < vehicle.cp.driveOnAtFillLevel and courseplay:timerIsThrough(vehicle, 'siloEmptyMessageDelay') then
				CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
			end;
		else
			CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_NO_FILLTYPE');
		end;
	end;

	-- drive on when required fill level is reached
	if not driveOn and (courseplay:timerIsThrough(vehicle, 'fillLevelChange') or vehicle.cp.prevFillLevelPct == nil) then
		if vehicle.cp.prevFillLevelPct ~= nil and vehicle.cp.totalFillLevelPercent == vehicle.cp.prevFillLevelPct and vehicle.cp.totalFillLevelPercent > vehicle.cp.driveOnAtFillLevel then
			driveOn = true;
		end;
		vehicle.cp.prevFillLevelPct = vehicle.cp.totalFillLevelPercent;
		courseplay:setCustomTimer(vehicle, 'fillLevelChange', 7);
	end;

	if vehicle.cp.totalFillLevelPercent == 100 or driveOn then
		vehicle.cp.prevFillLevelPct = nil;
		courseplay:setIsLoaded(vehicle, true);
		vehicle.cp.trailerFillDistance = nil;
		vehicle.cp.currentTrailerToFill = nil;
		vehicle.cp.tipperLoadMode = 0;
		courseplay:changeRunCounter(vehicle, true)
		return allowedToDrive;
	end;

	if currentTrailer.cp.realUnloadOrFillNode and vehicle.cp.trailerFillDistance then
		if currentTrailer:getFreeCapacity(vehicle.cp.siloSelectedFillType) == 0
		or currentTrailer.cp.currentSiloTrigger ~= nil and not (currentTrailer:getFreeCapacity(vehicle.cp.siloSelectedFillType) > 0 and #currentTrailer:getFillUnitsWithFillType(vehicle.cp.siloSelectedFillType) > 0) then
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
				vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
			else
				vehicle.cp.prevFillLevelPct = nil;
				courseplay:setIsLoaded(vehicle, true);
				vehicle.cp.trailerFillDistance = nil;
				vehicle.cp.currentTrailerToFill = nil;
				vehicle.cp.tipperLoadMode = 0;
			end;
		else
			if unloadDistance < vehicle.cp.trailerFillDistance then
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
	if ctt.getTipDistanceFromTrailer == nil then
		courseplay:debug(nameNum(vehicle) .. ": getTipDistanceFromTrailer function doesn't exist for currentTipTrigger - unloading function aborted", 2);
		return allowedToDrive;
	end

	-- If we are less than 15 waypoints from the end point, don't reset the stopAtEndMode1 (We might be at the same silo as we are filling from)
	if vehicle.cp.waypointIndex + 20 < vehicle.cp.numWaypoints then
		vehicle.cp.stopAtEndMode1 = false;
	end;

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
			elseif tipper.tipReferencePoints ~= nil then
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
	end;


	local isBGA = ctt.bunkerSilo ~= nil  and vehicle.cp.handleAsOneSilo ~= true;
	local bgaIsFull = isBGA and (ctt.fillLevel >= ctt.capacity);
	if isBGA then
		vehicle.cp.isBGATipping = true;
	end;

	for k, tipper in pairs(vehicle.cp.workTools) do
		if tipper.tipReferencePoints ~= nil then
			local allowedToDriveBackup = allowedToDrive;
			local fillType = tipper.cp.fillType;
			local distanceToTrigger, bestTipReferencePoint = 0,1;
			if isBGA then
				if tipper.cp.rearTipRefPoint and tipper.cp.rearTipRefPoint ~= bestTipReferencePoint then
					bestTipReferencePoint = tipper.cp.rearTipRefPoint;
				end;
				distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper,bestTipReferencePoint);
			else
				distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper);
			end
			tipper.preferedTipReferencePointIndex = bestTipReferencePoint
			local trailerInTipRange = false
			if not isBGA then
				trailerInTipRange =  g_currentMission:getIsTrailerInTipRange(tipper, ctt, bestTipReferencePoint);
				courseplay:debug(('%s: distanceToTrigger=%s, bestTipReferencePoint=%s -> trailerInTipRange=%s'):format(nameNum(vehicle), tostring(distanceToTrigger), tostring(bestTipReferencePoint), tostring(trailerInTipRange)), 2);
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

			
				local x,y,z = getWorldTranslation(tipper.tipReferencePoints[bestTipReferencePoint].node)
				local tx,ty,tz = x,y,z+0.50
				local x1,z1 = ctt.bunkerSiloArea.sx,ctt.bunkerSiloArea.sz
				local x2,z2 = ctt.bunkerSiloArea.wx,ctt.bunkerSiloArea.wz
				local x3,z3 = ctt.bunkerSiloArea.hx,ctt.bunkerSiloArea.hz
				trailerInTipRange = Utils.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z)
				local sx, sy, sz = worldToLocal(ctt.triggerStartId, x, y, z);
				local ex, ey, ez = worldToLocal(ctt.triggerEndId, x, y, z);
				local startDistance = Utils.vector2Length(sx, sz);
				local endDistance = Utils.vector2Length(ex, ez);
				courseplay:debug(('%s: startDistance=%s, endDistance=%s -> trailerInTipRange=%s'):format(nameNum(vehicle), tostring(startDistance), tostring(endDistance), tostring(trailerInTipRange)), 2);
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
					end

				-------------------------------
				--- Normal BGA unload
				-------------------------------
				else
					if trailerInTipRange then
						goForTipping = true
					end

					-- Get the animation
					local animation = tipper.tipAnimations[bestTipReferencePoint];
					local totalLength = abs(endDistance - startDistance)*0.9;
					local fillDelta = vehicle.cp.totalFillLevel / vehicle.cp.totalCapacity;
					local totalTipDuration = ((animation.dischargeEndTime - animation.dischargeStartTime) / animation.animationOpenSpeedScale) * fillDelta / 1000;
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
						courseplay:debug(string.format("%s: BGA totalLength=%.2f,  totalTipDuration%.2f,  refSpeed=%.2f", nameNum(vehicle), totalLength, totalTipDuration, refSpeed), 2);
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

						courseplay:debug(string.format('%s: unloadDistance = %.2f tipper.cp.trailerFillDistance = %.4s', nameNum(vehicle), unloadDistance, tostring(tipper.cp.prevTrailerDistance)), 2);
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
						courseplay:debug(nameNum(vehicle) .. ": goForTipping = true [BGA trigger accepts fruit (" .. tostring(fillType) .. ")]", 2);
					else
						courseplay:debug(nameNum(vehicle) .. ": goForTipping = true [trigger accepts fruit (" .. tostring(fillType) .. ")]", 2);
					end;

					if tipper.tipState == Trailer.TIPSTATE_CLOSED or tipper.tipState == Trailer.TIPSTATE_CLOSING then
						local isNearestPoint = false
						if distanceToTrigger > tipper.cp.closestTipDistance then
							isNearestPoint = true
							courseplay:debug(nameNum(vehicle) .. ": isNearestPoint = true ", 2);
						else
							tipper.cp.closestTipDistance = distanceToTrigger
						end
						if distanceToTrigger == 0 or isBGA or isNearestPoint then
							if isBGA then
								--tip to ground or existing heap
								tipper:toggleTipState(nil, bestTipReferencePoint);
							elseif ctt.animalHusbandry then
								if ctt.animalHusbandry:getHasSpaceForTipping(tipper.cp.fillType) then
									tipper:toggleTipState(ctt, bestTipReferencePoint);
								end
							else	
								tipper:toggleTipState(ctt, bestTipReferencePoint);
							end
							courseplay:debug(nameNum(vehicle)..": toggleTipState: "..tostring(bestTipReferencePoint).."  /unloadingTipper= "..tostring(tipper.name), 2);
						end
					else
						tipper.cp.isTipping = true;
						courseplay:debug(nameNum(vehicle)..": set isTipping", 2);
						allowedToDrive = false;
					end;
				else
					if tipper.tipState ~= Trailer.TIPSTATE_CLOSING and tipper.tipState ~= Trailer.TIPSTATE_CLOSED then
						tipper.cp.closestTipDistance = math.huge
						allowedToDrive = false;
					end;

					takeOverSteering = courseplay:manageCompleteTipping(vehicle,tipper,dt)
					
					if isBGA and ((not vehicle.Waypoints[vehicle.cp.waypointIndex].rev and not vehicle.cp.isReverseBGATipping) or unloadWhileReversing) then
						allowedToDrive = allowedToDriveBackup;
					end;
				end;
			elseif not ctt.acceptedFillTypes[fillType] then
				if isBGA then
					courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [BGA trigger does not accept fruit (" .. tostring(fillType) .. ")]", 2);
				else
					courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [trigger does not accept fruit (" .. tostring(fillType) .. ")]", 2);
				end;
			elseif isBGA and not bgaIsFull and not trailerInTipRange and not goForTipping then
				courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [BGA: trailerInTipRange == false]", 2);
			elseif isBGA and bgaIsFull and not goForTipping then
				courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [BGA: fillLevel > capacity]", 2);
			elseif isBGA and not goForTipping then
				courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [BGA]", 2);
			elseif not isBGA and not trailerInTipRange and not goForTipping then
				courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [trailerInTipRange == false]", 2);
			elseif not isBGA and not goForTipping then
				courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [fillLevel > capacity]", 2);
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
	if vehicle.cp.tipperFillLevel == 0 then
		vehicle.cp.isUnloaded = true;
	end
	vehicle.cp.currentTipTrigger = nil;
	vehicle.cp.handleAsOneSilo = nil; -- Used for BGA tipping
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
	end;
end;

function courseplay:refillWorkTools(vehicle, driveOn, allowedToDrive, lx, lz, dt)
	for _,workTool in ipairs(vehicle.cp.workTools) do
		if workTool.cp.fillLevel == nil or workTool.cp.capacity == nil then
			return allowedToDrive, lx, lz;
		end;
		local workToolSeederFillLevelPct = workTool.cp.seederFillLevelPercent;
		local workToolSprayerFillLevelPct = workTool.cp.sprayerFillLevelPercent;
		if workTool.cp.isLiquidManureOverloader then
			workToolSprayerFillLevelPct = workTool.cp.fillLevelPercent
		end
		local fillLevelPct = vehicle.cp.totalFillLevelPercent;

		local isSprayer = courseplay:isSprayer(workTool);

		if isSprayer then
			local isSpecialSprayer = false;
			isSpecialSprayer, allowedToDrive, lx, lz = courseplay:handleSpecialSprayer(vehicle, workTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, 'pull');
			if isSpecialSprayer then
				return allowedToDrive, lx, lz;
			end;
		end;

		-- Sprayer / liquid manure transporters
		if (isSprayer or workTool.cp.isLiquidManureOverloader) and not workTool:allowFillType(FillUtil.FILLTYPE_MANURE) then
			-- print(('\tworkTool %d (%q)'):format(i, nameNum(workTool)));
			local fillTrigger;
			if vehicle.cp.fillTrigger ~= nil then

				courseplay:debug(('%s: vehicle.cp.fillTrigger = %s'):format(nameNum(vehicle), tostring(vehicle.cp.fillTrigger)), 19);
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if trigger and (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger) then
					if courseplay:fillTypesMatch(trigger, workTool) then
						--print('\t\tslow down, it\'s a sprayerFillTrigger');
						courseplay:debug(('%s: trigger is SprayerFillTrigger -> set vehicle.cp.isInFilltrigger'):format(nameNum(vehicle)), 19);
						vehicle.cp.isInFilltrigger = true;
					else
						vehicle.cp.fillTrigger = nil
						courseplay:debug(('%s: fillTypes dont match -> reset vehicle.cp.fillTrigger'):format(nameNum(vehicle)), 19);
					end
				end;
			end;

			-- check for fillTrigger
			if workTool.fillTriggers then
				local trigger = workTool.fillTriggers[1];
				if trigger ~= nil and (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger) then
					fillTrigger = trigger;
					vehicle.cp.fillTrigger = nil;
					courseplay:debug(('%s: trigger is SprayerFillTrigger -> fillTrigger = trigger  +  reset vehicle.cp.fillTrigger'):format(nameNum(vehicle)), 19);
				end;
			end;

			-- check for UPK fillTrigger
			if fillTrigger == nil and workTool.upkTrigger then
				local trigger = workTool.upkTrigger[1];
				if trigger ~= nil and (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger) then
					fillTrigger = trigger;
					vehicle.cp.fillTrigger = nil;
				end;
			end;

			local fillTypesMatch = courseplay:fillTypesMatch(fillTrigger, workTool);
			local canRefill = workToolSprayerFillLevelPct < driveOn and fillTypesMatch and not vehicle.cp.isLoaded;
			courseplay:debug(('%s: canRefill:%s; fillTypesMatch:%s'):format(nameNum(vehicle),tostring(canRefill),tostring(fillTypesMatch)), 19);

			if canRefill and vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT then
				canRefill = not courseplay:waypointsHaveAttr(vehicle, vehicle.cp.waypointIndex, -2, 2, 'wait', true, false);

				if canRefill then
					if (workTool.isSpreaderInRange ~= nil and workTool.isSpreaderInRange.manureTriggerc ~= nil)
					-- regular fill triggers
					or (fillTrigger ~= nil and fillTrigger.triggerId ~= nil and vehicle.cp.lastMode8UnloadTriggerId ~= nil and fillTrigger.triggerId == vehicle.cp.lastMode8UnloadTriggerId)
					-- manureLager fill trigger
					or (fillTrigger ~= nil and fillTrigger.manureTrigger ~= nil and vehicle.cp.lastMode8UnloadTriggerId ~= nil and fillTrigger.manureTrigger == vehicle.cp.lastMode8UnloadTriggerId)
					then
						canRefill = false;
					end;
				end;
			end;
			-- print(('workToolFillLevelPct=%.1f, driveOn=%d, fillTrigger=%s, fillTypesMatch=%s, canRefill=%s'):format(workToolFillLevelPct, driveOn, tostring(fillTrigger), tostring(fillTypesMatch), tostring(canRefill)));

			if canRefill then
				allowedToDrive = false;
				-- 												 unfold, lower, turnOn, allowedToDrive, cover, unload)
				courseplay:handleSpecialTools(vehicle, workTool, nil,    nil,   nil,    allowedToDrive, false, false);

				

				if not workTool.isFilling then
					workTool:setIsFilling(true);
				end;
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.cp.sprayerFillLevel or workTool.cp.fillLevel, 100), workTool.cp.sprayerCapacity or workTool.cp.capacity));

			elseif vehicle.cp.isLoaded or workToolSprayerFillLevelPct >= driveOn and fillTrigger~= nil and (fillTrigger.isSprayerFillTrigger or fillTrigger.isLiquidManureFillTrigger) then
				if workTool.isFilling then
					workTool:setIsFilling(false);
				end;
				--												 unfold, lower, turnOn, allowedToDrive, cover, unload)
				courseplay:handleSpecialTools(vehicle, workTool, nil,    nil,   nil,    allowedToDrive, false, false);
				if not (vehicle.cp.fillTrigger and courseplay.triggers.all[vehicle.cp.fillTrigger].isWeightStation) then
					vehicle.cp.fillTrigger = nil;
					if workTool.cp.isLiquidManureOverloader then
						courseplay:changeRunCounter(vehicle, true)
					end
					courseplay:debug(('%s: vehicle.cp.isLoaded or workToolSprayerFillLevelPct >= driveOn -> set vehicle.cp.fillTrigger to nil'):format(nameNum(vehicle)), 19);
				end;
			else
				courseplay:debug(('%s: canRefill is false -> break'):format(nameNum(vehicle)), 19);
			end;
		end;

		-- SOWING MACHINE -- NOTE: no elseif, as a workTool might be both a sprayer and a seeder (URF)
		if courseplay:isSowingMachine(workTool) then
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if trigger.isSowingMachineFillTrigger then
					--print("slow down , its a SowingMachineFillTrigger")
					courseplay:debug('%s: trigger is SowingMachineFillTrigger -> set vehicle.cp.isInFilltrigger', 19);
					vehicle.cp.isInFilltrigger = true;
				end
			end
			if workToolSeederFillLevelPct < driveOn and workTool.fillTriggers[1] ~= nil and workTool.fillTriggers[1].isSowingMachineFillTrigger then
				--print(tableShow(workTool.fillTriggers,"workTool.fillTriggers"))
				if not workTool.isFilling then
					workTool:setIsFilling(true);
				end;
				allowedToDrive = false;
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.cp.seederFillLevel, 100), workTool.cp.seederCapacity));
			elseif workTool.fillTriggers[1] ~= nil and workTool.fillTriggers[1].isSowingMachineFillTrigger then
				if workTool.isFilling then
					workTool:setIsFilling(false);
				end;
				vehicle.cp.fillTrigger = nil;
				courseplay:debug('%s: vehicle.cp.isLoaded or workToolSeederFillLevelPct >= driveOn -> set vehicle.cp.fillTrigger to nil', 19);
			end;

		-- TREE PLANTER
		elseif workTool.cp.isTreePlanter then
			if workTool.nearestSaplingPallet ~= nil and workTool.mountedSaplingPallet == nil then
				local id = workTool.nearestSaplingPallet.id;
				-- print("load Pallet "..tostring(id));
				workTool:loadPallet(id);
			end;

		-- FUEL TRAILER
		elseif workTool.cp.isFuelTrailer then
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if trigger.isGasStationTrigger then
					vehicle.cp.isInFilltrigger = true;
				else
					vehicle.cp.fillTrigger = nil;
				end
			end
			if fillLevelPct < driveOn and workTool.fuelFillTriggers[1] ~= nil and workTool.fuelFillTriggers[1].isGasStationTrigger then
				if not workTool.isFuelFilling then
					workTool:setIsFuelFilling(true);
				end;
				allowedToDrive = false;
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.cp.fillLevel, 100), workTool.cp.capacity));
			elseif workTool.fuelFillTriggers[1] ~= nil then
				if workTool.isFuelFilling then
					workTool:setIsFuelFilling(false);
				end;
				vehicle.cp.fillTrigger = nil;
				courseplay:changeRunCounter(vehicle, true)
			end;

		-- WATER TRAILER
		elseif workTool.cp.isWaterTrailer then
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if trigger.isWaterTrailerFillTrigger then
					vehicle.cp.isInFilltrigger = true;
				else
					vehicle.cp.fillTrigger = nil;
				end
			end
			if fillLevelPct < driveOn and workTool.waterTrailerFillTriggers[1] ~= nil and workTool.waterTrailerFillTriggers[1].isWaterTrailerFillTrigger then
				if not workTool.isWaterTrailerFilling then
					workTool:setIsWaterTrailerFilling(true);
				end;
				allowedToDrive = false;
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.cp.fillLevel, 100), workTool.cp.capacity));
			elseif workTool.waterTrailerFillTriggers[1] ~= nil then
				if workTool.isWaterTrailerFilling then
					workTool:setIsWaterTrailerFilling(false);
				end;
				vehicle.cp.fillTrigger = nil;
				courseplay:changeRunCounter(vehicle, true)
			end;
		end;
	end;

	return allowedToDrive, lx, lz;
end;

function courseplay:handleUnloading(vehicle,revUnload,dt,reverseCourseUnloadpoint)
	local tipRefpoint = 0
	local stopForTipping = false
	local takeOverSteering = false
	local message = ""
	--print("reverseCourseUnloadpoint: "..tostring(reverseCourseUnloadpoint).."  revUnload: "..tostring(revUnload))

	if (vehicle.cp.isCombine or vehicle.cp.isHarvesterSteerable or vehicle.cp.hasHarvesterAttachable) and vehicle.cp.totalFillLevelPercent > 0 then
		for i=1, #(vehicle.cp.workTools) do
			workTool = vehicle.cp.workTools[i];
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
							if filltype ~= FillUtil.FILLTYPE_UNKNOWN and vehicle.pipeParticleSystems[filltype] then
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
					if filltype ~= FillUtil.FILLTYPE_UNKNOWN and vehicle.pipeParticleSystems[filltype] then
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
						if vehicle.cp.lastValidTipDistance ~= nil and (z > vehicle.cp.lastValidTipDistance or tipper.tipState ~= Trailer.TIPSTATE_CLOSED) and tipper.cp.fillLevel ~= 0 then
							stopForTipping = true
							goForTipping = true
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
				
				if (tipper.tipState == Trailer.TIPSTATE_CLOSED or tipper.tipState == Trailer.TIPSTATE_CLOSING) and goForTipping then
					tipper:toggleTipState(nil, tipRefpoint);
					--print("toggeltipstate by "..message)
				end
				
				takeOverSteering = courseplay:manageCompleteTipping(vehicle,tipper,dt,z)
				
				--finsh and go for next round
				if (tipper.tipState == Trailer.TIPSTATE_OPEN or tipper.tipState == Trailer.TIPSTATE_OPENING) and tipper.cp.fillLevel == 0 then
					tipper:toggleTipState(nil, tipRefpoint);
					vehicle.cp.takeOverSteering = false
					if revUnload then
						courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
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

function courseplay:handleHeapUnloading(vehicle)
	--Todo right now it starts when tractor is under unload point. Be nice if pipe was under
	local stopForUnload = false;
	--For Mode 7 Has workTools is empty
	if #(vehicle.cp.workTools) == 0 then
		vehicle.cp.workTools[1] = vehicle
	end;
	for i=1, #(vehicle.cp.workTools) do
		workTool = vehicle.cp.workTools[i];
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
						if filltype ~= FillUtil.FILLTYPE_UNKNOWN and vehicle.pipeParticleSystems[filltype] then
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
							if filltype ~= FillUtil.FILLTYPE_UNKNOWN and vehicle.pipeParticleSystems[filltype] then
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
	if (tipper.tipState == Trailer.TIPSTATE_OPEN or tipper.tipState == Trailer.TIPSTATE_OPENING) and tipper.couldNotDropTimer > 100 then
		if tipper.couldNotDropTimer > tipper.couldNotDropTimerThreshold *0.9 then
			tipper.couldNotDropTimer = 0
		end
		vehicle.cp.takeOverSteering = true
	end		
	
	if (tipper.tipState == Trailer.TIPSTATE_OPEN or tipper.tipState == Trailer.TIPSTATE_OPENING) and tipper.couldNotDropTimer < 100 and vehicle.cp.takeOverSteering then
		vehicle.cp.takeOverSteering = false	
		vehicle.cp.lastValidTipDistance = z or 0
		--print("reset takeOverSteering z= "..tostring(z).." Zsent: "..tostring(zSent))
	end
	
	if vehicle.cp.takeOverSteering then
		local fwdWayoint = courseplay:getNextFwdPoint(vehicle)
		local x,z = vehicle.Waypoints[fwdWayoint].cx, vehicle.Waypoints[fwdWayoint].cz;
		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
		local lx,lz = AIVehicleUtil.getDriveDirection(vehicle.cp.DirectionNode, x, y, z);
		AIVehicleUtil.driveInDirection(vehicle, dt, vehicle.cp.steeringAngle, 1, 0.5, 10, true, true, lx, lz, 5, 1)
	end
	return vehicle.cp.takeOverSteering
end
