local abs, cos, sin, min, max, deg = math.abs, math.cos, math.sin, math.min, math.max, math.deg;
-- ##### MANAGING TOOLS ##### --

function courseplay:attachImplement(implement)
	--- Update Vehicle
	local workTool = implement.object;
	if workTool.attacherVehicle.cp.hasSpecializationSteerable then
		workTool.attacherVehicle.cp.toolsDirty = true;
	end;

	courseplay:setAttachedCombine(self);
end;
function courseplay:detachImplement(implementIndex)
	--- Update Vehicle
	self.cp.toolsDirty = true;
end;

local origVehicleDetachImplement = Vehicle.detachImplement;
Vehicle.detachImplement = function(self, implementIndex, noEventSend)
	-- don't allow detaching while CP is active
	local tractor = self:getRootAttacherVehicle();
	if tractor and tractor.hasCourseplaySpec and tractor.cp.isDriving and not noEventSend then -- if noEventSend == true, detachImplement has been called from Vehicle:delete() -> no need to abort
		print('Courseplay warning: you need to stop Courseplay before detaching implements!');
		return;
	end;

	origVehicleDetachImplement(self, implementIndex, noEventSend);

	-- update attachCombineIndex and minHudPage
	if self.hasCourseplaySpec and not noEventSend then -- if noEventSend == true, detachImplement has been called from Vehicle:delete() -> no need to set attachedCombine anymore
		courseplay:setAttachedCombine(self);
	end;
end;


function courseplay:reset_tools(vehicle)
	vehicle.cp.workTools = {}
	-- are there any tippers?
	vehicle.cp.workToolAttached = courseplay:updateWorkTools(vehicle, vehicle);

	-- Reset fill type.
	if #vehicle.cp.workTools > 0 and vehicle.cp.workTools[1].cp.hasSpecializationFillable and vehicle.cp.workTools[1].allowFillFromAir and vehicle.cp.workTools[1].allowTipDischarge then
		if vehicle.cp.multiSiloSelectedFillType == Fillable.FILLTYPE_UNKNOWN or (vehicle.cp.multiSiloSelectedFillType ~= Fillable.FILLTYPE_UNKNOWN and not vehicle.cp.workTools[1].fillTypes[vehicle.cp.multiSiloSelectedFillType]) then
			vehicle.cp.multiSiloSelectedFillType = vehicle.cp.workTools[1]:getFirstEnabledFillType();
		end;
	else
		vehicle.cp.multiSiloSelectedFillType = Fillable.FILLTYPE_UNKNOWN;
	end;
	if vehicle.cp.hud.currentPage == 1 then
		courseplay.hud:setReloadPageOrder(vehicle, 1, true);
	end;

	vehicle.cp.currentTrailerToFill = nil;
	vehicle.cp.trailerFillDistance = nil;
	vehicle.cp.toolsDirty = false;
end;

function courseplay:getNextFillableFillType(vehicle)
	local workTool = vehicle.cp.workTools[1];
	if vehicle.cp.multiSiloSelectedFillType == Fillable.FILLTYPE_UNKNOWN or vehicle.cp.multiSiloSelectedFillType == Fillable.NUM_FILLTYPES then
		return workTool:getFirstEnabledFillType();
	end;

	local nextFillType, enabled = next(workTool.fillTypes, vehicle.cp.multiSiloSelectedFillType);
	if nextFillType and enabled then
		return nextFillType;
	end;

	return workTool:getFirstEnabledFillType();
end;

function courseplay:isAttachedCombine(workTool)
	return (workTool.typeName~= nil and (workTool.typeName == 'attachableCombine' or workTool.typeName == 'attachableCombine_mouseControlled')) or (not workTool.cp.hasSpecializationSteerable and workTool.hasPipe and not workTool.cp.isAugerWagon and not workTool.cp.isLiquidManureOverloader) or courseplay:isSpecialChopper(workTool)
end;
function courseplay:isAttachedMixer(workTool)
	return workTool.typeName == "mixerWagon" or (not workTool.cp.hasSpecializationSteerable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isAttacherModule(workTool)
	if workTool.attacherJoint then
		return (workTool.attacherJoint.jointType == Vehicle.jointTypeNameToInt["semitrailer"] and (not workTool.wheels or (workTool.wheels and #workTool.wheels == 0))) or workTool.cp.isAttacherModule == true;
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
	return (workTool.cp.hasSpecializationCombine or workTool.cp.hasSpecializationAICombine) and workTool.attachedCutters ~= nil and workTool.capacity > 0;
end;
function courseplay:isChopper(workTool)
	return (workTool.cp.hasSpecializationCombine or workTool.cp.hasSpecializationAICombine) and workTool.attachedCutters ~= nil and workTool.capacity == 0 or courseplay:isSpecialChopper(workTool);
end;
function courseplay:isFoldable(workTool) --is the tool foldable?
	return workTool.cp.hasSpecializationFoldable or workTool.foldingParts ~= nil;
end;
function courseplay:isFrontloader(workTool)
	return workTool.cp.hasSpecializationCylindered  and workTool.cp.hasSpecializationAnimatedVehicle and not workTool.cp.hasSpecializationShovel;
end;
function courseplay:isHarvesterSteerable(workTool)
	return workTool.typeName == "selfPropelledPotatoHarvester" or workTool.cp.isGrimmeMaxtron620 or workTool.cp.isGrimmeTectron415;
end;
function courseplay:isHookLift(workTool)
	if workTool.attacherJoint then
		return workTool.attacherJoint.jointType == Vehicle.jointTypeNameToInt["hookLift"];
	end;
	return false;
end
function courseplay:isMixer(workTool)
	return workTool.typeName == "selfPropelledMixerWagon" or (workTool.cp.hasSpecializationSteerable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isMower(workTool)
	return workTool.cp.hasSpecializationMower or courseplay:isSpecialMower(workTool);
end;
function courseplay:isPushWagon(workTool)
	return workTool.typeName:match("forageWagon") or workTool.cp.hasSpecializationSiloTrailer or workTool.cp.isPushWagon;
end;
function courseplay:isRoundbaler(workTool) -- is the tool a roundbaler?
	return courseplay:isBaler(workTool) and (workTool.baleCloseAnimationName ~= nil and workTool.baleUnloadAnimationName ~= nil or courseplay:isSpecialRoundBaler(workTool));
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
function courseplay:isWheelloader(workTool)			--vv added for Kasi, check whether it could cause problems (Tom)
	return workTool.typeName:match("wheelLoader") or workTool.cp.isWheelLoader;
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

	courseplay:setNameVariable(workTool);

	local hasWorkTool = false;

	-- MODE 1 + 2: GRAIN TRANSPORT / COMBI MODE
	if vehicle.cp.mode == 1 or vehicle.cp.mode == 2 then
		if workTool.allowTipDischarge and workTool.capacity and workTool.capacity > 0.1 then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end;

	-- MODE 3: AUGERWAGON
	elseif vehicle.cp.mode == 3 then
		if workTool.cp.isAugerWagon then -- if workTool.cp.hasSpecializationTrailer then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end

	-- MODE 4: FERTILIZER AND SEEDING
	elseif vehicle.cp.mode == 4 then
		local isSprayer, isSowingMachine = courseplay:isSprayer(workTool), courseplay:isSowingMachine(workTool);
		if isSprayer or isSowingMachine or workTool.cp.isTreePlanter then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			courseplay:setMarkers(vehicle, workTool)
			vehicle.cp.hasMachinetoFill = true;
			vehicle.cp.noStopOnEdge = isSprayer;
			vehicle.cp.noStopOnTurn = isSprayer;
			if isSprayer then
				vehicle.cp.hasSprayer = true;
			end;
			if isSowingMachine then
				vehicle.cp.hasSowingMachine = true;
			end;
		end;

	-- MODE 5: TRANSFER
	elseif vehicle.cp.mode == 5 then
		-- For reverse testing and only for developers!!!!
		if isImplement and CpManager.isDeveloper then
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
		and not workTool.cp.isCaseIHPuma160
		and not courseplay:isSprayer(workTool)
		and not courseplay:isSowingMachine(workTool)
		then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			courseplay:setMarkers(vehicle, workTool,isImplement);
			vehicle.cp.noStopOnTurn = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or vehicle.attachedCutters ~= nil;
			vehicle.cp.noStopOnEdge = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or vehicle.attachedCutters ~= nil;
			if workTool.cp.hasSpecializationPlough then 
				vehicle.cp.hasPlough = true;
			end;
			if courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) then
				vehicle.cp.hasBaleLoader = true;
			end;
		end;

	-- MODE 7: COMBINE SELF UNLOADING
	elseif vehicle.cp.mode == 7 then
		-- DO NOTHING

	-- MODE 8: LIQUID MANURE TRANSFER
	elseif vehicle.cp.mode == 8 then
		if workTool.cp.hasSpecializationFillable and ((workTool.getOverloadingTrailerInRangePipeState ~= nil or workTool.setIsReFilling ~= nil) or workTool.cp.isFuelTrailer or workTool.cp.isWaterTrailer) then
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			vehicle.cp.hasMachinetoFill = true;
			workTool.cp.waterReceiverTrigger = nil; -- water trailer: make sure it has no saved unloading water trigger
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
			workTool.attacherVehicle.cp.shovelState = 1
		end;
	end;

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
		local implX,implY,implZ = getWorldTranslation(workTool.rootNode);
		local _,_,tractorToImplZ = worldToLocal(vehicle.cp.DirectionNode, implX,implY,implZ);

		vehicle.cp.aiBackMarker = nil; --TODO (Jakob): still needed?
		if not vehicle.cp.aiTurnNoBackward and workTool.aiLeftMarker ~= nil and workTool.aiForceTurnNoBackward == true then 
			vehicle.cp.aiTurnNoBackward = true;
			courseplay:debug(('%s: workTool.aiLeftMarker ~= nil and workTool.aiForceTurnNoBackward == true --> vehicle.cp.aiTurnNoBackward = true'):format(nameNum(workTool)), 6);
		elseif not vehicle.cp.aiTurnNoBackward and workTool.aiLeftMarker == nil and #(workTool.wheels) > 0 and tractorToImplZ <= 0 then
			vehicle.cp.aiTurnNoBackward = true;
			courseplay:debug(('%s: workTool.aiLeftMarker == nil and #(workTool.wheels) > 0 and tractorToImplZ (%.2f) <= 0 --> vehicle.cp.aiTurnNoBackward = true'):format(nameNum(workTool), tractorToImplZ), 6);
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
				local name = g_currentMission.nodeToVehicle[a].name;
				courseplay:debug(('\\___ [%s] = %s (%q)'):format(tostring(a), tostring(name), tostring(getName(a))), 3);
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
	vehicle.cp.tipRefOffset = nil;
	local foundTipRefOffset = false;
	for i=1, vehicle.cp.numWorkTools do
		if vehicle.cp.hasMachinetoFill then
			vehicle.cp.tipRefOffset = 1.5;
		elseif vehicle.cp.workTools[i].rootNode ~= nil and vehicle.cp.workTools[i].tipReferencePoints ~= nil then
			local tipperX, tipperY, tipperZ = getWorldTranslation(vehicle.cp.workTools[i].rootNode);
			if  #(vehicle.cp.workTools[i].tipReferencePoints) > 1 then
				vehicle.cp.workTools[i].cp.rearTipRefPoint = nil;
				for n=1 ,#(vehicle.cp.workTools[i].tipReferencePoints) do
					local tipRefPointX, tipRefPointY, tipRefPointZ = worldToLocal(vehicle.cp.workTools[i].tipReferencePoints[n].node, tipperX, tipperY, tipperZ);
					tipRefPointX = abs(tipRefPointX);
					if not foundTipRefOffset then
						if (vehicle.cp.tipRefOffset == nil or vehicle.cp.tipRefOffset == 0) and tipRefPointX > 0.1 then
							vehicle.cp.tipRefOffset = tipRefPointX;
							foundTipRefOffset = true;
						else
							vehicle.cp.tipRefOffset = 0
						end;
					end;

					-- Find the rear tipRefpoint in case we are BGA tipping.
					if tipRefPointX < 0.1 and tipRefPointZ > 0 then
						if not vehicle.cp.workTools[i].cp.rearTipRefPoint or vehicle.cp.workTools[i].tipReferencePoints[n].width > vehicle.cp.workTools[i].tipReferencePoints[vehicle.cp.workTools[i].cp.rearTipRefPoint].width then
							vehicle.cp.workTools[i].cp.rearTipRefPoint = n;
							courseplay:debug(string.format("%s: Found rear TipRefPoint: %d - tipRefPointZ = %f", nameNum(vehicle), n, tipRefPointZ), 13);
						end;
					end;
				end;
			else
				vehicle.cp.tipRefOffset = 0;
			end;
		end;
	end;
end;

function courseplay:setMarkers(vehicle, object,isImplement)
	local aLittleBitMore = 1;
	object.cp.backMarkerOffset = nil
	object.cp.aiFrontMarker = nil
	-- get the behindest and the frontest  points :-) ( as offset to root node)
	local area = object.workAreas
	if object.attachedCutters ~= nil and not object.cp.hasSpecializationFruitPreparer and not courseplay:isAttachedCombine(object) then
		courseplay:debug(('%s: setMarkers(): %s is a combine -> return '):format(nameNum(vehicle), tostring(object.name)), 6);
		return
	end
	
	if not area then
		courseplay:debug(('%%s: setMarkers(): %s has no workAreas -> return '):format(nameNum(vehicle), tostring(object.name)), 6);
		return;
	end;

	local tableLength = #(area)
	if tableLength == 0 then
		courseplay:debug(('%s: setMarkers(): %s has no workAreas -> return '):format(nameNum(vehicle), tostring(object.name)), 6);
		return
	end
	for k = 1, tableLength do
		for j,node in pairs(area[k]) do
			if j == "start" or j == "height" or j == "width" then 
				local x, y, z = getWorldTranslation(node)
				local _, _, ztt = worldToLocal(vehicle.cp.DirectionNode, x, y, z)
				courseplay:debug(('%s: %s Point %s: ztt = %s'):format(nameNum(vehicle), tostring(object.name), tostring(j), tostring(ztt)), 6);
				if object.cp.backMarkerOffset == nil or ztt > object.cp.backMarkerOffset then
					object.cp.backMarkerOffset = ztt
				end
				if object.cp.aiFrontMarker == nil  or ztt < object.cp.aiFrontMarker then
					object.cp.aiFrontMarker = ztt
				end
			end
		end
	end

	if vehicle.cp.backMarkerOffset == nil or object.cp.backMarkerOffset < (vehicle.cp.backMarkerOffset + aLittleBitMore) then
		vehicle.cp.backMarkerOffset = object.cp.backMarkerOffset - aLittleBitMore;
	end

	if vehicle.cp.aiFrontMarker == nil or object.cp.aiFrontMarker > (vehicle.cp.aiFrontMarker - aLittleBitMore) then
		vehicle.cp.aiFrontMarker = object.cp.aiFrontMarker + aLittleBitMore;
	end

	if vehicle.cp.aiFrontMarker < -7 then
		vehicle.aiToolExtraTargetMoveBack = abs(vehicle.cp.aiFrontMarker)
	end

	courseplay:debug(('%s: setMarkers(): turnEndBackDistance = %s, aiToolExtraTargetMoveBack = %s'):format(nameNum(vehicle), tostring(vehicle.turnEndBackDistance), tostring(vehicle.aiToolExtraTargetMoveBack)), 6);
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

function courseplay:setOldAutoTurnDiameter(vehicle, hasWorkTool)
	local sinAlpha = 0;		-- Sinus vom Lenkwinkel
	local wheelbase = 0;	-- Radstand
	local track = 0;		-- Spurweite
	local turnDiameter = 0;	-- Wendekreis unbereinigt
	local xerion = false
	if vehicle.foundWheels == nil then
		vehicle.foundWheels = {}
	end
	for i=1, #(vehicle.wheels) do
		local wheel =  vehicle.wheels[i]
		if wheel.rotMax ~= 0 then
			if vehicle.foundWheels[1] == nil then
				sinAlpha = wheel.rotMax
				vehicle.foundWheels[1] = wheel
			elseif vehicle.foundWheels[2] == nil then
				vehicle.foundWheels[2] = wheel
			elseif vehicle.foundWheels[4] == nil then
				vehicle.foundWheels[4] = wheel
			end
		elseif vehicle.foundWheels[3] == nil then
			vehicle.foundWheels[3] = wheel
		end
	
	end
	if vehicle.foundWheels[3] == nil then --Xerion and Co
		sinAlpha = sinAlpha *2
		xerion = true
	end
		
	if #(vehicle.foundWheels) == 3 or xerion then
		local wh1X, wh1Y, wh1Z = getWorldTranslation(vehicle.foundWheels[1].driveNode);
		local wh2X, wh2Y, wh2Z = getWorldTranslation(vehicle.foundWheels[2].driveNode);
		local wh3X, wh3Y, wh3Z = 0,0,0
		if xerion then
			wh3X, wh3Y, wh3Z = getWorldTranslation(vehicle.foundWheels[4].driveNode);
		else
			wh3X, wh3Y, wh3Z = getWorldTranslation(vehicle.foundWheels[3].driveNode);
		end	 
		track  = courseplay:distance(wh1X, wh1Z, wh2X, wh2Z)
		wheelbase = courseplay:distance(wh1X, wh1Z, wh3X, wh3Z)
		turnDiameter = 2*wheelbase/sinAlpha+track
		vehicle.foundWheels = {}
	else
		turnDiameter = vehicle.cp.turnDiameter                  -- Kasi and Co are not supported. Nobody does hauling with a Kasi or Quadtrack !!!
	end;
	
	if hasWorkTool and (vehicle.cp.mode == 2 or vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6) then --TODO (Jakob): I've added modes 3, 4 & 6 - needed?
		vehicle.cp.turnDiameterAuto = turnDiameter;
		--print(string.format("vehicle.cp.workTools[1].sizeLength = %s  turnDiameter = %s", tostring(vehicle.cp.workTools[1].sizeLength),tostring( turnDiameter)))
		if vehicle.cp.numWorkTools == 1 and vehicle.cp.workTools[1].attacherVehicle ~= vehicle and (vehicle.cp.workTools[1].sizeLength > turnDiameter) then
			vehicle.cp.turnDiameterAuto = vehicle.cp.workTools[1].sizeLength;
		end;
		if (vehicle.cp.numWorkTools > 1) then
			vehicle.cp.turnDiameterAuto = turnDiameter * 1.5;
		end
	end;

	if vehicle.cp.turnDiameterAutoMode then
		vehicle.cp.turnDiameter = vehicle.cp.turnDiameterAuto;
		if abs(vehicle.cp.turnDiameter) > 50 then
			vehicle.cp.turnDiameter = 15
		end
	end;
end

--##################################################


-- ##### LOADING TOOLS ##### --
function courseplay:load_tippers(vehicle, allowedToDrive)
	local cx, cz = vehicle.Waypoints[2].cx, vehicle.Waypoints[2].cz;
	local driveOn = false;

	if vehicle.cp.currentTrailerToFill == nil then
		vehicle.cp.currentTrailerToFill = 1;
	end
	local currentTrailer = vehicle.cp.workTools[vehicle.cp.currentTrailerToFill];
	if not currentTrailer.cp.realUnloadOrFillNode then
		currentTrailer.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(currentTrailer);
		if not currentTrailer.cp.realUnloadOrFillNode then
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
				vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
			else
				driveOn = true;
			end;
		end;
	end;

	if not vehicle.cp.trailerFillDistance then

		if not currentTrailer.cp.realUnloadOrFillNode then
			return allowedToDrive;
		end;

		local _,y,_ = getWorldTranslation(currentTrailer.cp.realUnloadOrFillNode);
		local _,_,z = worldToLocal(currentTrailer.cp.realUnloadOrFillNode, cx, y, cz);
		vehicle.cp.trailerFillDistance = z;
	end;

	-- MultiSiloTrigger (Giants)
	if currentTrailer.cp.currentMultiSiloTrigger ~= nil then
		local acceptedFillType = false;
		local mst = currentTrailer.cp.currentMultiSiloTrigger;

		for _, fillType in pairs(mst.fillTypes) do
			if fillType == vehicle.cp.multiSiloSelectedFillType then
				acceptedFillType = true;
				break;
			end;
		end;

		if acceptedFillType then
			local siloIsEmpty = g_currentMission.missionStats.farmSiloAmounts[vehicle.cp.multiSiloSelectedFillType] <= 1;

			if not mst.isFilling and not siloIsEmpty and (currentTrailer.currentFillType == Fillable.FILLTYPE_UNKNOWN or currentTrailer.currentFillType == vehicle.cp.multiSiloSelectedFillType) then
				mst:startFill(vehicle.cp.multiSiloSelectedFillType);
				courseplay:debug(('%s: MultiSiloTrigger: selectedFillType = %s, isFilling = %s'):format(nameNum(vehicle), tostring(Fillable.fillTypeIntToName[mst.selectedFillType]), tostring(mst.isFilling)), 2);
			elseif siloIsEmpty then
				CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
			end;
		else
			CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_NO_FILLTYPE');
		end;
	end;

	-- drive on when required fill level is reached
	if courseplay:timerIsThrough(vehicle, 'fillLevelChange') or vehicle.cp.prevFillLevelPct == nil then
		if vehicle.cp.prevFillLevelPct ~= nil and vehicle.cp.tipperFillLevelPct == vehicle.cp.prevFillLevelPct and vehicle.cp.tipperFillLevelPct > vehicle.cp.driveOnAtFillLevel then
			driveOn = true;
		end;
		vehicle.cp.prevFillLevelPct = vehicle.cp.tipperFillLevelPct;
		courseplay:setCustomTimer(vehicle, 'fillLevelChange', 7);
	end;

	if vehicle.cp.tipperFillLevelPct == 100 or driveOn then
		vehicle.cp.prevFillLevelPct = nil;
		courseplay:setIsLoaded(vehicle, true);
		vehicle.cp.trailerFillDistance = nil;
		vehicle.cp.currentTrailerToFill = nil;
		return allowedToDrive;
	end;

	if currentTrailer.cp.realUnloadOrFillNode and vehicle.cp.trailerFillDistance then
		if currentTrailer.fillLevel == currentTrailer.capacity
		or currentTrailer.cp.currentMultiSiloTrigger ~= nil and not (currentTrailer.currentFillType == Fillable.FILLTYPE_UNKNOWN or currentTrailer.currentFillType == vehicle.cp.multiSiloSelectedFillType) then
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
				vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
			else
				vehicle.cp.prevFillLevelPct = nil;
				courseplay:setIsLoaded(vehicle, true);
				vehicle.cp.trailerFillDistance = nil;
				vehicle.cp.currentTrailerToFill = nil;
			end;
		else
			local _,y,_ = getWorldTranslation(currentTrailer.cp.realUnloadOrFillNode);
			local _,_,vectorDistanceZ = worldToLocal(currentTrailer.cp.realUnloadOrFillNode, cx, y, cz);

			if vectorDistanceZ < vehicle.cp.trailerFillDistance then
				allowedToDrive = false;
			end;
		end;
	end;

	-- normal mode if all tippers are empty
	return allowedToDrive;
end


-- ##################################################


-- ##### UNLOADING TOOLS ##### --
function courseplay:unload_tippers(vehicle, allowedToDrive)
	local ctt = vehicle.cp.currentTipTrigger;
	if ctt.getTipDistanceFromTrailer == nil then
		if ctt.getTipInfoForTrailer == nil then
			courseplay:debug(nameNum(vehicle) .. ": getTipDistanceFromTrailer function doesn't exist for currentTipTrigger - unloading function aborted", 2);
			return allowedToDrive;
		else
			ctt.isHeapTipTrigger = true;
		end
	end;

	local isBGA = ctt.bunkerSilo ~= nil and ctt.bunkerSilo.movingPlanes ~= nil and vehicle.cp.handleAsOneSilo ~= true;
	local bgaIsFull = isBGA and (ctt.bunkerSilo.fillLevel >= ctt.bunkerSilo.capacity);
	if isBGA then
		vehicle.cp.isBGATipping = true;
	end;

	for k, tipper in pairs(vehicle.cp.workTools) do
		if tipper.tipReferencePoints ~= nil then
			local allowedToDriveBackup = allowedToDrive;
			local fruitType = tipper.currentFillType
			local distanceToTrigger, bestTipReferencePoint = 0,0
			if ctt.isHeapTipTrigger then
				_,distanceToTrigger,bestTipReferencePoint = ctt:getTipInfoForTrailer(tipper);
			else
				distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper);
			end
			local trailerInTipRange = g_currentMission:getIsTrailerInTipRange(tipper, ctt, bestTipReferencePoint);
			courseplay:debug(('%s: distanceToTrigger=%s, bestTipReferencePoint=%s -> trailerInTipRange=%s'):format(nameNum(vehicle), tostring(distanceToTrigger), tostring(bestTipReferencePoint), tostring(trailerInTipRange)), 2);
			local goForTipping = false;
			local unloadWhileReversing = false; -- Used by Reverse BGA Tipping
			local isRePositioning = false; -- Used by Reverse BGA Tipping

			--BGA TRIGGER
			if isBGA and not bgaIsFull then
				if vehicle.cp.handleAsOneSilo == nil then
				    local length = 0;
					for i = 1, #ctt.bunkerSilo.movingPlanes-1, 1 do
						local x, y, z = getWorldTranslation(ctt.bunkerSilo.movingPlanes[i].nodeId);
						local lx, _, lz = worldToLocal(ctt.bunkerSilo.movingPlanes[i+1].nodeId, x, y, z);
						length = length + Utils.vector2Length(lx, lz);
					end;
					length = length / #ctt.bunkerSilo.movingPlanes;

					if length < 0.5 then
						vehicle.cp.handleAsOneSilo = true;
					else
						vehicle.cp.handleAsOneSilo = false;
					end;

					courseplay:debug(('%s: Median Silo Section Distance = %s, handleAsOneSilo = %s'):format(nameNum(vehicle), tostring(courseplay:round(length, 1)), tostring(vehicle.cp.handleAsOneSilo)), 13);

					if vehicle.cp.handleAsOneSilo == true then return allowedToDrive; end;
				end

				local stopAndGo = false;

				-- Make sure we are using the rear TipReferencePoint as bestTipReferencePoint if possible.
				if tipper.cp.rearTipRefPoint and tipper.cp.rearTipRefPoint ~= bestTipReferencePoint then
					bestTipReferencePoint = tipper.cp.rearTipRefPoint;
					trailerInTipRange = g_currentMission:getIsTrailerInTipRange(tipper, ctt, bestTipReferencePoint);
				end;

				-- Check if bestTipReferencePoint it's inversed
				if tipper.cp.inversedRearTipNode == nil then
					local vx,vy,vz = getWorldTranslation(vehicle.rootNode)
					local _,_,tz = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, vx,vy,vz);
					tipper.cp.inversedRearTipNode = tz < 0;
				end;

				-- Local values used in both normal and reverse direction
				local silos = #ctt.bunkerSilo.movingPlanes;
				local x, y, z = getWorldTranslation(tipper.tipReferencePoints[bestTipReferencePoint].node);
				local sx, sy, sz = worldToLocal(ctt.bunkerSilo.movingPlanes[1].nodeId, x, y, z);
				local ex, ey, ez = worldToLocal(ctt.bunkerSilo.movingPlanes[silos].nodeId, x, y, z);
				local startDistance = Utils.vector2Length(sx, sz);
				local endDistance = Utils.vector2Length(ex, ez);

				-- Get nearest silo section number (Code snip taken from BunkerSilo:setFillDeltaAt)
				local nearestDistance = math.huge;
				local nearestBGASection = 1;
				for i, movingPlane in pairs(ctt.bunkerSilo.movingPlanes) do
					local wx, _, wz = getWorldTranslation(movingPlane.nodeId);
					local distance = Utils.vector2Length(wx - x, wz - z);
					if nearestDistance > distance then
						nearestBGASection = i;
						nearestDistance = distance;
					end;
				end;

				-------------------------------
				--- Reverse into BGA and unload
				-------------------------------
				if vehicle.Waypoints[vehicle.cp.waypointIndex].rev or vehicle.cp.isReverseBGATipping then
					-- Get the silo section fill level based on how many sections and total capacity.
					local medianSiloCapacity = ctt.bunkerSilo.capacity / silos * 0.92; -- we make it a bit smaler than it actually is, since it will still unload a bit to the silo next to it.

					-- Find what BGA silo section to unload in if not found
					if not tipper.cp.BGASelectedSection then
						vehicle.cp.BGASectionInverted = false;

						-- Find out what end to start at.
						if startDistance > endDistance then
							tipper.cp.BGASelectedSection = 1;
						else
							tipper.cp.BGASelectedSection = silos;
							vehicle.cp.BGASectionInverted = true;
						end;

						-- Find which section to unload into.
						while (vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection > 1) or (not vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection < silos) do
							if ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].fillLevel < medianSiloCapacity then
								break;
							end;

							if vehicle.cp.BGASectionInverted then
								tipper.cp.BGASelectedSection = tipper.cp.BGASelectedSection - 1;
							else
								tipper.cp.BGASelectedSection = tipper.cp.BGASelectedSection + 1;
							end;
						end;

						courseplay:debug(string.format("%s: BGA selected silo section: %d - Is inverted order: %s", nameNum(vehicle), tipper.cp.BGASelectedSection, tostring(vehicle.cp.BGASectionInverted)), 13);
					end;

					-- Check if last silo section.
					local isLastSiloSection = (vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection == 1) or (not vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection == silos);

					-- Start unloading some silo section before main silo section to make a ramp for the trailer.
					if not isLastSiloSection and nearestBGASection ~= tipper.cp.BGASelectedSection then
						local unloadNumOfSectionBefore = 6;
						local sectionMaxFillLevel = 0;
						local isInUnloadSection = false;

						-- INVERTED SILO DIRECTION
						if (vehicle.cp.BGASectionInverted and nearestBGASection >= tipper.cp.BGASelectedSection - unloadNumOfSectionBefore) and nearestBGASection < tipper.cp.BGASelectedSection then
							-- recalculate the num of section before, in case the num of section left is less.
							unloadNumOfSectionBefore = min(tipper.cp.BGASelectedSection - 1,unloadNumOfSectionBefore);

							-- Calculate the current section max fill level.
							sectionMaxFillLevel = (unloadNumOfSectionBefore - max(tipper.cp.BGASelectedSection - nearestBGASection, 0) + 1) * ((medianSiloCapacity * 0.5) / unloadNumOfSectionBefore);

							isInUnloadSection = true;

						-- NORMAL SILO DIRECTION
						elseif (not vehicle.cp.BGASectionInverted and nearestBGASection <= tipper.cp.BGASelectedSection + unloadNumOfSectionBefore) and nearestBGASection > tipper.cp.BGASelectedSection then
							-- recalculate the num of section before, in case the num of section left is less.
							unloadNumOfSectionBefore = min(silos - tipper.cp.BGASelectedSection ,unloadNumOfSectionBefore)

							-- Calculate the current section max fill level.
							sectionMaxFillLevel = (unloadNumOfSectionBefore - max(nearestBGASection - tipper.cp.BGASelectedSection, 0) + 1) * ((medianSiloCapacity * 0.5) / unloadNumOfSectionBefore);

							isInUnloadSection = true;
						end;

						if ctt.bunkerSilo.movingPlanes[nearestBGASection].fillLevel < sectionMaxFillLevel then
							-- Get a vector distance, to make a more precise distance check.
							local xmp, _, zmp = getWorldTranslation(ctt.bunkerSilo.movingPlanes[nearestBGASection].nodeId);
							local _, _, vectorDistance = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, xmp, y, zmp);

							goForTipping = trailerInTipRange and vectorDistance > -2.5;
							unloadWhileReversing = true;
						elseif isInUnloadSection and tipper.tipState ~= Trailer.TIPSTATE_CLOSING and tipper.tipState ~= Trailer.TIPSTATE_CLOSED then
							tipper:toggleTipState();
							tipper.cp.isTipping = false;
							courseplay:debug(string.format("%s: Ramp(%d) fill level is at max. Waiting with unloading.]", nameNum(vehicle), nearestBGASection), 13);
						end;
					end;

					-- Get a vector distance, to make a more precise distance check.
					local xmp, _, zmp = getWorldTranslation(ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].nodeId);
					local _, _, vectorDistance = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, xmp, y, zmp);
					if tipper.cp.inversedRearTipNode then vectorDistance = vectorDistance * -1 end;

					-- If we drive too far, then change direction and try to replace again.
					if not isLastSiloSection and (vectorDistance > 1 or vectorDistance < -1) and nearestBGASection ~= tipper.cp.BGASelectedSection then
						local isChangingDirection = false;

						if vectorDistance > 0 and vehicle.Waypoints[vehicle.cp.waypointIndex].rev then
							-- Change direction to forward
							vehicle.cp.isReverseBGATipping = true;
							isChangingDirection = true;
							courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
						elseif vectorDistance < 0 and not vehicle.Waypoints[vehicle.cp.waypointIndex].rev then
							-- Change direction to reverse
							local found = false;
							for i = vehicle.cp.waypointIndex, 1, -1 do
								if vehicle.Waypoints[i].rev then
									courseplay:setWaypointIndex(vehicle, i);
									found = true;
								end;
							end;

							if found then
								vehicle.cp.isReverseBGATipping = false;
								isChangingDirection = true;
							end;
						end;

						if isChangingDirection then
							courseplay:debug(string.format("%s: Changed direction to %s to try reposition again.]", nameNum(vehicle), vehicle.Waypoints[vehicle.cp.waypointIndex].rev and "reverse" or "forward"), 13);
						end;
					end;


					-- Make sure we drive to the middle of the next silo section before stopping again.
					if vehicle.cp.isReverseBGATipping and vectorDistance > 0 then
						courseplay:debug(string.format("%s: Moving to the middle of silo section %d - current distance: %.3fm]", nameNum(vehicle), tipper.cp.BGASelectedSection, vectorDistance), 13);

					-- Unload if inside the selected section
					elseif trailerInTipRange and nearestBGASection == tipper.cp.BGASelectedSection then
						goForTipping = trailerInTipRange and vectorDistance > -2.5;
					end;

					-- Goto the next silo section if this one is filled and not last silo section.
					if not isLastSiloSection and ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].fillLevel >= medianSiloCapacity then
						-- Make sure we run this script even that we are not in an reverse waypoint anymore.
						vehicle.cp.isReverseBGATipping = true;

						-- Find next section to unload into.
						while (vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection > 1) or (not vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection < silos) do
							if ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].fillLevel < medianSiloCapacity then
								break;
							end;

							if vehicle.cp.BGASectionInverted then
								tipper.cp.BGASelectedSection = tipper.cp.BGASelectedSection - 1;
							else
								tipper.cp.BGASelectedSection = tipper.cp.BGASelectedSection + 1;
							end;
						end;

						-- Find the first forward waypoint ahead of the vehicle so we can drive ahead to the next silo section.
						courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));

						courseplay:debug(string.format("%s: New BGA silo section: %d", nameNum(vehicle), tipper.cp.BGASelectedSection), 13);
					elseif isLastSiloSection and goForTipping then
						-- Make sure we run this script even that we are not in an reverse waypoint anymore.
						vehicle.cp.isReverseBGATipping = true;

						-- Make sure that we don't reverse into the silo after it's full
						courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
					end;

				-------------------------------
				--- Normal BGA unload
				-------------------------------
				else
					-- Get the silo section fill level based on how many sections and total capacity.
					local medianSiloCapacity = ctt.bunkerSilo.capacity / silos;

					-- Get the animation
					local animation = tipper.tipAnimations[bestTipReferencePoint];
					local totalLength = abs(endDistance - startDistance);
					local fillDelta = vehicle.cp.tipperFillLevel / vehicle.cp.tipperCapacity;
					local totalTipDuration = ((animation.dischargeEndTime - animation.dischargeStartTime) / animation.animationOpenSpeedScale) * fillDelta / 1000;
					local meterPrSeconds = totalLength / totalTipDuration;
					if stopAndGo then
						meterPrSeconds = vehicle.cp.speeds.reverse * 1000;
					end;

					-- Find what BGA silo section to unload in if not found
					if not tipper.cp.BGASelectedSection then
						local fillLevel = ctt.bunkerSilo.fillLevel;
						if ctt.bunkerSilo.cpTempFillLevel then fillLevel = ctt.bunkerSilo.cpTempFillLevel end;

						vehicle.cp.bunkerSiloSectionFillLevel = min((fillLevel + (vehicle.cp.tipperFillLevel * 0.9))/silos, medianSiloCapacity);
						courseplay:debug(string.format("%s: Max allowed fill level pr. section = %.2f", nameNum(vehicle), vehicle.cp.bunkerSiloSectionFillLevel), 2);
						vehicle.cp.BGASectionInverted = false;

						ctt.bunkerSilo.cpTempFillLevel = fillLevel + vehicle.cp.tipperFillLevel;
						courseplay:debug(string.format("%s: cpTempFillLevel = %.2f", nameNum(vehicle), ctt.bunkerSilo.cpTempFillLevel), 2);

						-- Find out what end to start at.
						if startDistance < endDistance then
							tipper.cp.BGASelectedSection = 1;
						else
							tipper.cp.BGASelectedSection = silos;
							vehicle.cp.BGASectionInverted = true;
						end;

						-- Find which section to unload into.
						while (vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection < silos) or (not vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection > 1) do
							if ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel then
								break;
							end;

							if vehicle.cp.BGASectionInverted then
								tipper.cp.BGASelectedSection = tipper.cp.BGASelectedSection - 1;
							else
								tipper.cp.BGASelectedSection = tipper.cp.BGASelectedSection + 1;
							end;
						end;

						courseplay:debug(string.format("%s: BGA selected silo section: %d - Is inverted order: %s", nameNum(vehicle), tipper.cp.BGASelectedSection, tostring(vehicle.cp.BGASectionInverted)), 2);

					end;

					if not vehicle.cp.bunkerSiloSectionFillLevel then
						courseplay:resetTipTrigger(vehicle);
						return allowedToDrive;
					end;

					local isLastSiloSection = (vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection == 1) or (not vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection == silos);

					-- Get a vector distance, to make a more precise distance check.
					local xmp, _, zmp = getWorldTranslation(ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].nodeId);
					local _, _, vectorDistance = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, xmp, y, zmp);
					local isOpen = tipper:getCurrentTipAnimationTime() >= animation.animationDuration;

					if not isLastSiloSection and ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].fillLevel >= vehicle.cp.bunkerSiloSectionFillLevel then
						if tipper.tipState ~= Trailer.TIPSTATE_CLOSING and tipper.tipState ~= Trailer.TIPSTATE_CLOSED then
							tipper:toggleTipState();
							tipper.cp.isTipping = false;
							courseplay:debug(string.format("%s: SiloSection(%d) fill level is at max allowed fill level. Stopping unloading and move to next.", nameNum(vehicle), tipper.cp.BGASelectedSection), 2);
							if courseplay:isPushWagon(tipper) then
								if isOpen then
									tipper:disableCurrentTipAnimation(tipper.tipAnimations[bestTipReferencePoint].animationDuration);
								else
									tipper:enableTipAnimation(bestTipReferencePoint, 1);
								end;
							end;
							vehicle.cp.isChangingPosition = true;
						end;
						if vehicle.cp.BGASectionInverted then
							tipper.cp.BGASelectedSection = max(tipper.cp.BGASelectedSection - 1, 1);
						else
							tipper.cp.BGASelectedSection = min(tipper.cp.BGASelectedSection + 1, silos);
						end;
						courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), tipper.cp.BGASelectedSection), 2);
					end;

					local isFirseSiloSection = (vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection == silos) or (not vehicle.cp.BGASectionInverted and tipper.cp.BGASelectedSection == 1);

					local startTipDistance = 1.5;
					-- Open hatch before time
					if courseplay:isPushWagon(tipper) then
						local openDistance = meterPrSeconds * (animation.animationDuration / animation.animationOpenSpeedScale / 1000);
						if vectorDistance <= (3 + openDistance) and not isOpen then
							tipper:enableTipAnimation(bestTipReferencePoint, 1);
						end;

					-- Find out when to start tipping based on speed
					else
						startTipDistance = meterPrSeconds * (animation.dischargeStartTime / animation.animationOpenSpeedScale / 1000);
					end;

					-- Slow down to real unload speed
					if not vehicle.cp.backupUnloadSpeed and not stopAndGo and vectorDistance < 6*meterPrSeconds then
						-- Calculate the unloading speed.
						local refSpeed = meterPrSeconds * 3.6; -- * 0.90;
						vehicle.cp.backupUnloadSpeed = vehicle.cp.speeds.reverse;
						courseplay:changeReverseSpeed(vehicle, nil, refSpeed, true);
						courseplay:debug(string.format("%s: BGA totalLength=%.2f,  totalTipDuration%.2f,  refSpeed=%.2f", nameNum(vehicle), totalLength, totalTipDuration, refSpeed), 2);
					end;

					local canUnload = false;
					-- We can unload if we are in the right distance to the first silo
					if isFirseSiloSection then
						if vectorDistance < startTipDistance then
							canUnload = ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel;
						end;

						if tipper.cp.BGASelectedSection ~= nearestBGASection and not vehicle.cp.isChangingPosition then
							tipper.cp.BGASelectedSection = nearestBGASection;
							courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), tipper.cp.BGASelectedSection), 2);
						end;
					elseif tipper.cp.BGASelectedSection == nearestBGASection then
						canUnload = ctt.bunkerSilo.movingPlanes[tipper.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel or isLastSiloSection;
						if vehicle.cp.isChangingPosition then vehicle.cp.isChangingPosition = nil end;
					elseif tipper.cp.BGASelectedSection ~= nearestBGASection and not vehicle.cp.isChangingPosition then
						tipper.cp.BGASelectedSection = nearestBGASection;
						courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), tipper.cp.BGASelectedSection), 2);
					end;

					goForTipping = trailerInTipRange and canUnload;

					--if goForTipping or isLastSiloSection then
					if isLastSiloSection or stopAndGo then
						if (not stopAndGo and vectorDistance < -2) or (stopAndGo and tipper.cp.BGASelectedSection == nearestBGASection and goForTipping) then
							allowedToDriveBackup = false;
						end;
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

			--REGULAR TIPTRIGGER
			elseif not isBGA then
				goForTipping = trailerInTipRange;

				--AlternativeTipping: don't unload if full
				if ctt.fillLevel ~= nil and ctt.capacity ~= nil and ctt.fillLevel >= ctt.capacity then
					goForTipping = false;
				end;
			end

			--UNLOAD
			if ctt.acceptedFillTypes[fruitType] and goForTipping == true then
				if not tipper.cp.isTipping then
					if isBGA then
						courseplay:debug(nameNum(vehicle) .. ": goForTipping = true [BGA trigger accepts fruit (" .. tostring(fruitType) .. ")]", 2);
					else
						courseplay:debug(nameNum(vehicle) .. ": goForTipping = true [trigger accepts fruit (" .. tostring(fruitType) .. ")]", 2);
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
							tipper:toggleTipState(ctt, bestTipReferencePoint);
							tipper.cp.isTipping = true;
							courseplay:debug(nameNum(vehicle)..": toggleTipState: "..tostring(bestTipReferencePoint).."  /unloadingTipper= "..tostring(tipper.name), 2);
							allowedToDrive = false;
						end
					end;
				else
					if tipper.tipState ~= Trailer.TIPSTATE_CLOSING then
						tipper.cp.closestTipDistance = math.huge
						allowedToDrive = false;
					end;

					if isBGA and ((not vehicle.Waypoints[vehicle.cp.waypointIndex].rev and not vehicle.cp.isReverseBGATipping) or unloadWhileReversing) then
						allowedToDrive = allowedToDriveBackup;
					end;
				end;
			elseif not ctt.acceptedFillTypes[fruitType] then
				if isBGA then
					courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [BGA trigger does not accept fruit (" .. tostring(fruitType) .. ")]", 2);
				else
					courseplay:debug(nameNum(vehicle) .. ": goForTipping = false [trigger does not accept fruit (" .. tostring(fruitType) .. ")]", 2);
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
	return allowedToDrive;
end

function courseplay:addCpNilTempFillLevelFunction()
	local cpNilTempFillLevel = function(self, state)
		if state ~= self.state and state == BunkerSilo.STATE_CLOSED then
			self.cpTempFillLevel = nil;
		end;
	end;
	BunkerSilo.setState = Utils.prependedFunction(BunkerSilo.setState, cpNilTempFillLevel);
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

function courseplay:refillWorkTools(vehicle, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt)
	for _,workTool in ipairs(vehicle.cp.workTools) do
		if workTool.fillLevel == nil or workTool.capacity == nil then
			return;
		end;
		local workToolFillLevelPct = workTool.fillLevel * 100 / workTool.capacity;

		local isSprayer = courseplay:isSprayer(workTool);

		if isSprayer then
			local isSpecialSprayer = false;
			isSpecialSprayer, allowedToDrive, lx, lz = courseplay:handleSpecialSprayer(vehicle, workTool, fillLevelPct, driveOn, allowedToDrive, lx, lz, dt, 'pull');
			if isSpecialSprayer then
				return allowedToDrive, lx, lz;
			end;
		end;

		-- Sprayer / liquid manure transporters
		if (isSprayer or workTool.cp.isLiquidManureOverloader) and not workTool.fillTypes[Fillable.FILLTYPE_MANURE] then
			-- print(('\tworkTool %d (%q)'):format(i, nameNum(workTool)));
			local fillTrigger;

			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger) and courseplay:fillTypesMatch(trigger, workTool) then 
					--print('\t\tslow down, it\'s a sprayerFillTrigger');
					vehicle.cp.isInFilltrigger = true;
				end;
			end;

			-- check for fillTrigger
			if workTool.fillTriggers then
				local trigger = workTool.fillTriggers[1];
				if trigger ~= nil and (trigger.isSprayerFillTrigger or trigger.isLiquidManureFillTrigger) then
					fillTrigger = trigger;
					vehicle.cp.fillTrigger = nil;
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
			local canRefill = workToolFillLevelPct < driveOn and fillTypesMatch;

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
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.fillLevel, 100), workTool.capacity));

			elseif vehicle.cp.isLoaded or workToolFillLevelPct >= driveOn then
				if workTool.isFilling then
					workTool:setIsFilling(false);
				end;
				--												 unfold, lower, turnOn, allowedToDrive, cover, unload)
				courseplay:handleSpecialTools(vehicle, workTool, nil,    nil,   nil,    allowedToDrive, false, false);
				vehicle.cp.fillTrigger = nil;
			end;
		end;

		-- SOWING MACHINE -- NOTE: no elseif, as a workTool might be both a sprayer and a seeder (URF)
		if courseplay:isSowingMachine(workTool) then
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if trigger.isSowingMachineFillTrigger then
					--print("slow down , its a SowingMachineFillTrigger")
					vehicle.cp.isInFilltrigger = true;
				end
			end
			if fillLevelPct < driveOn and workTool.fillTriggers[1] ~= nil and workTool.fillTriggers[1].isSowingMachineFillTrigger then
				--print(tableShow(workTool.fillTriggers,"workTool.fillTriggers"))
				if not workTool.isFilling then
					workTool:setIsFilling(true);
				end;
				allowedToDrive = false;
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.fillLevel, 100), workTool.capacity));
			elseif workTool.fillTriggers[1] ~= nil then
				if workTool.isFilling then
					workTool:setIsFilling(false);
				end;
				vehicle.cp.fillTrigger = nil;
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
				end
			end
			if fillLevelPct < driveOn and workTool.fuelFillTriggers[1] ~= nil and workTool.fuelFillTriggers[1].isGasStationTrigger then
				if not workTool.isFuelFilling then
					workTool:setIsFuelFilling(true);
				end;
				allowedToDrive = false;
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.fillLevel, 100), workTool.capacity));
			elseif workTool.fuelFillTriggers[1] ~= nil then
				if workTool.isFuelFilling then
					workTool:setIsFuelFilling(false);
				end;
				vehicle.cp.fillTrigger = nil;
			end;

		-- WATER TRAILER
		elseif workTool.cp.isWaterTrailer then
			if vehicle.cp.fillTrigger ~= nil then
				local trigger = courseplay.triggers.all[vehicle.cp.fillTrigger];
				if trigger.isWaterTrailerFillTrigger then
					vehicle.cp.isInFilltrigger = true;
				end
			end
			if fillLevelPct < driveOn and workTool.waterTrailerFillTriggers[1] ~= nil and workTool.waterTrailerFillTriggers[1].isWaterTrailerFillTrigger then
				if not workTool.isWaterTrailerFilling then
					workTool:setIsWaterTrailerFilling(true);
				end;
				allowedToDrive = false;
				courseplay:setInfoText(vehicle, ('COURSEPLAY_LOADING_AMOUNT;%d;%d'):format(courseplay.utils:roundToLowerInterval(workTool.fillLevel, 100), workTool.capacity));
			elseif workTool.waterTrailerFillTriggers[1] ~= nil then
				if workTool.isWaterTrailerFilling then
					workTool:setIsWaterTrailerFilling(false);
				end;
				vehicle.cp.fillTrigger = nil;
			end;
		end;
	end;

	return allowedToDrive, lx, lz;
end;

