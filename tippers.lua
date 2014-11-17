-- ##### MANAGING TOOLS ##### --

function courseplay:attachImplement(implement)
	--- Update Vehicle
	local workTool = implement.object;
	if workTool.attacherVehicle.cp.hasSpecializationSteerable then
		workTool.attacherVehicle.cp.toolsDirty = true;
	end;
end;
function courseplay:detachImplement(implementIndex)
	--- Update Vehicle
	self.cp.toolsDirty = true;
end;

function courseplay:reset_tools(vehicle)
	vehicle.tippers = {}
	-- are there any tippers?
	vehicle.cp.tipperAttached = courseplay:updateWorkTools(vehicle, vehicle);

	-- Reset fill type.
	if #vehicle.tippers > 0 and vehicle.tippers[1].cp.hasSpecializationFillable and vehicle.tippers[1].allowFillFromAir and vehicle.tippers[1].allowTipDischarge then
		if vehicle.cp.multiSiloSelectedFillType == Fillable.FILLTYPE_UNKNOWN or (vehicle.cp.multiSiloSelectedFillType ~= Fillable.FILLTYPE_UNKNOWN and not vehicle.tippers[1].fillTypes[vehicle.cp.multiSiloSelectedFillType]) then
			vehicle.cp.multiSiloSelectedFillType = vehicle.tippers[1]:getFirstEnabledFillType();
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
	local workTool = vehicle.tippers[1];
	if vehicle.cp.multiSiloSelectedFillType == Fillable.FILLTYPE_UNKNOWN or vehicle.cp.multiSiloSelectedFillType == Fillable.NUM_FILLTYPES then
		return workTool:getFirstEnabledFillType();
	end;

	for fillType, enabled in pairs(workTool.fillTypes) do
		if fillType > vehicle.cp.multiSiloSelectedFillType and enabled then
			return fillType;
		end;
	end;

	return workTool:getFirstEnabledFillType();
end;

function courseplay:isCombine(workTool)
	return (workTool.cp.hasSpecializationCombine or workTool.cp.hasSpecializationAICombine) and workTool.attachedCutters ~= nil and workTool.capacity > 0;
end;
function courseplay:isChopper(workTool)
	return (workTool.cp.hasSpecializationCombine or workTool.cp.hasSpecializationAICombine) and workTool.attachedCutters ~= nil and workTool.capacity == 0 or courseplay:isSpecialChopper(workTool);
end;
function courseplay:isHarvesterSteerable(workTool)
	return workTool.typeName == "selfPropelledPotatoHarvester" or workTool.cp.isGrimmeMaxtron620 or workTool.cp.isGrimmeTectron415;
end;
function courseplay:isBaler(workTool) -- is the tool a baler?
	return workTool.cp.hasSpecializationBaler or workTool.balerUnloadingState ~= nil or courseplay:isSpecialBaler(workTool);
end;
function courseplay:isRoundbaler(workTool) -- is the tool a roundbaler?
	return courseplay:isBaler(workTool) and (workTool.baleCloseAnimationName ~= nil and workTool.baleUnloadAnimationName ~= nil or courseplay:isSpecialRoundBaler(workTool));
end;
function courseplay:isBaleLoader(workTool) -- is the tool a bale loader?
	return workTool.cp.hasSpecializationBaleLoader or (workTool.balesToLoad ~= nil and workTool.baleGrabber ~=nil and workTool.grabberIsMoving~= nil);
end;
function courseplay:isSprayer(workTool) -- is the tool a sprayer/spreader?
	return workTool.cp.hasSpecializationSprayer or courseplay:isSpecialSprayer(workTool)
end;
function courseplay:isSowingMachine(workTool) -- is the tool a sowing machine?
	return workTool.cp.hasSpecializationSowingMachine or courseplay:isSpecialSowingMachine(workTool);
end;
function courseplay:isFoldable(workTool) --is the tool foldable?
	return workTool.cp.hasSpecializationFoldable or workTool.foldingParts ~= nil;
end;
function courseplay:isMower(workTool)
	return workTool.cp.hasSpecializationMower or courseplay:isSpecialMower(workTool);
end;
function courseplay:isBigM(workTool)
	return workTool.cp.hasSpecializationSteerable and courseplay:isMower(workTool);
end;
function courseplay:isAttachedCombine(workTool)
	return (workTool.typeName~= nil and workTool.typeName == "attachableCombine") or (not workTool.cp.hasSpecializationSteerable and  workTool.hasPipe) or courseplay:isSpecialChopper(workTool)
end;
function courseplay:isAttachedMixer(workTool)
	return workTool.typeName == "mixerWagon" or (not workTool.cp.hasSpecializationSteerable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isMixer(workTool)
	return workTool.typeName == "selfPropelledMixerWagon" or (workTool.cp.hasSpecializationSteerable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isFrontloader(workTool)
	return workTool.cp.hasSpecializationCylindered  and workTool.cp.hasSpecializationAnimatedVehicle and not workTool.cp.hasSpecializationShovel;
end;
function courseplay:isWheelloader(workTool)
	return workTool.typeName:match("wheelLoader") or (workTool.cp.hasSpecializationSteerable and workTool.cp.hasSpecializationShovel and workTool.cp.hasSpecializationBunkerSiloCompacter);
end;
function courseplay:isPushWagon(workTool)
	return workTool.typeName:match("forageWagon") or workTool.cp.hasSpecializationSiloTrailer or workTool.cp.isPushWagon;
end;

-- UPDATE WORKTOOL DATA
function courseplay:updateWorkTools(vehicle, workTool, isImplement)
	if not isImplement then
		cpPrintLine(6, 3);
		courseplay:debug(('%s: updateWorkTools(vehicle, %q, isImplement=false) (mode=%d)'):format(nameNum(vehicle), nameNum(workTool), vehicle.cp.mode), 6);
	else
		cpPrintLine(6);
		courseplay:debug(('%s: updateWorkTools(vehicle, %q, isImplement=true)'):format(nameNum(vehicle), nameNum(workTool)), 6);
	end;

	courseplay:setNameVariable(workTool);

	local hasWorkTool = false;

	-- MODE 1 + 2: GRAIN TRANSPORT / COMBI MODE
	if vehicle.cp.mode == 1 or vehicle.cp.mode == 2 then
		if workTool.allowTipDischarge then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
		end;

	-- MODE 3: AUGERWAGON
	elseif vehicle.cp.mode == 3 then
		if workTool.cp.isAugerWagon then -- if workTool.cp.hasSpecializationTrailer then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
		end

	-- MODE 4: FERTILIZER AND SEEDING
	elseif vehicle.cp.mode == 4 then
		local isSprayer, isSowingMachine = courseplay:isSprayer(workTool), courseplay:isSowingMachine(workTool);
		if isSprayer or isSowingMachine then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
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
		if isImplement and courseplay.isDeveloper then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
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
		then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
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
		if workTool.cp.hasSpecializationFillable then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
		end;

	-- MODE 9: FILL AND EMPTY SHOVEL
	elseif vehicle.cp.mode == 9 then
		if not isImplement and (courseplay:isWheelloader(workTool) or workTool.typeName == 'frontloader' or courseplay:isMixer(workTool)) then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
			workTool.cp.shovelState = 1;

		elseif isImplement and (courseplay:isFrontloader(workTool) or workTool.cp.hasSpecializationShovel) then 
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
			workTool.attacherVehicle.cp.shovelState = 1
		end;
	end;

	if hasWorkTool then
		courseplay:debug(('%s: workTool %q added to tippers (index %d)'):format(nameNum(vehicle), nameNum(workTool), #vehicle.tippers), 6);
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
		local _,_,tractorToImplZ = worldToLocal(vehicle.rootNode, implX,implY,implZ);

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
		vehicle.cp.numWorkTools = #vehicle.tippers;

		-- list debug
		if courseplay.debugChannels[3] then
			cpPrintLine(6);
			courseplay:debug(('%s cpTrafficCollisionIgnoreList'):format(nameNum(vehicle)), 3);
			for a,b in pairs(vehicle.cpTrafficCollisionIgnoreList) do
				local name = g_currentMission.nodeToVehicle[a].name;
				courseplay:debug(('\\___ [%s] = %s (%q)'):format(tostring(a), tostring(name), tostring(getName(a))), 3);
			end;
		end;

		--MINHUDPAGE FOR ATTACHED COMBINES
		vehicle.cp.attachedCombineIdx = nil;
		if not (vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader) then
			for i=1, vehicle.cp.numWorkTools do
				if courseplay:isAttachedCombine(vehicle.tippers[i]) then
					vehicle.cp.attachedCombineIdx = i;
					break;
				end;
			end;
		end;
		if vehicle.cp.attachedCombineIdx ~= nil then
			--courseplay:debug(string.format('setMinHudPage(vehicle, vehicle.tippers[%d])', vehicle.cp.attachedCombineIdx), 18);
			courseplay:setMinHudPage(vehicle, vehicle.tippers[vehicle.cp.attachedCombineIdx]);
		end;

		-- TURN RADIUS
		courseplay:setAutoTurnradius(vehicle, hasWorkTool);

		-- TIP REFERENCE POINTS
		courseplay:setTipRefOffset(vehicle);

		-- TIPPER COVERS
		vehicle.cp.tipperHasCover = false;
		vehicle.cp.tippersWithCovers = {};
		if hasWorkTool then
			courseplay:setTipperCoverData(vehicle);
		end;


		-- FINAL TIPPERS TABLE DEBUG
		if courseplay.debugChannels[6] then
			cpPrintLine(6);
			if vehicle.cp.numWorkTools > 0 then
				courseplay:debug(('%s: tippers:'):format(nameNum(vehicle)), 6);
				for i=1, vehicle.cp.numWorkTools do
					courseplay:debug(('\\___ [%d] = %s'):format(i, nameNum(vehicle.tippers[i])), 6);
				end;
			else
				courseplay:debug(('%s: no tippers set'):format(nameNum(vehicle)), 6);
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
	for i=1, vehicle.cp.numWorkTools do
		if vehicle.tippers[i].rootNode ~= nil and vehicle.tippers[i].tipReferencePoints ~= nil then
			local tipperX, tipperY, tipperZ = getWorldTranslation(vehicle.tippers[i].rootNode);
			if  #(vehicle.tippers[i].tipReferencePoints) > 1 then
				vehicle.tippers[i].cp.rearTipRefPoint = nil;
				for n=1 ,#(vehicle.tippers[i].tipReferencePoints) do
					local tipRefPointX, tipRefPointY, tipRefPointZ = worldToLocal(vehicle.tippers[i].tipReferencePoints[n].node, tipperX, tipperY, tipperZ);
					tipRefPointX = math.abs(tipRefPointX);
					if (vehicle.cp.tipRefOffset == nil or vehicle.cp.tipRefOffset == 0) and tipRefPointX > 0.1 then
						vehicle.cp.tipRefOffset = tipRefPointX;
					else
						vehicle.cp.tipRefOffset = 0
					end;

					-- Find the rear tipRefpoint in case we are reverse BGA tipping.
					if tipRefPointX < 0.1 and tipRefPointZ > 0 then
						if not vehicle.tippers[i].cp.rearTipRefPoint or vehicle.tippers[i].tipReferencePoints[n].width > vehicle.tippers[i].tipReferencePoints[vehicle.tippers[i].cp.rearTipRefPoint].width then
							vehicle.tippers[i].cp.rearTipRefPoint = n;
							courseplay:debug(string.format("%s: Found rear TipRefPoint: %d - tipRefPointZ = %f", nameNum(vehicle), n, tipRefPointZ), 13);
						end;
					end;
				end;
			else 
				vehicle.cp.tipRefOffset = 0;
			end;
		elseif vehicle.cp.hasMachinetoFill then
			vehicle.cp.tipRefOffset = 1.5;
		end;
		if vehicle.cp.tipRefOffset ~= nil then
			break;
		end;
	end;
end;

function courseplay:setMarkers(vehicle, object,isImplement)
	object.cp.backMarkerOffset = nil
	object.cp.aiFrontMarker = nil
	-- get the behindest and the frontest  points :-) ( as offset to root node)
	local area = object.workAreas

	-- TODO: Old FS15 methode, should be removed when sure all is using the "workAreas"
	--[[if courseplay:isBigM(object) then
		area = object.mowerCutAreas
	elseif object.typeName == "defoliator_animated" then
		area = object.fruitPreparerAreas
	end]]

	if not area then
		return;
	end;

	local tableLength = #(area)
	if tableLength == 0 then
		return
	end
	for k = 1, tableLength do
		for j,node in pairs(area[k]) do
			if j == "start" or j == "height" or j == "width" then 
				local x, y, z = getWorldTranslation(node)
				local _, _, ztt = worldToLocal(vehicle.rootNode, x, y, z)
				courseplay:debug(('%s:%s Point %s: ztt = %s'):format(nameNum(vehicle), tostring(object.name), tostring(j), tostring(ztt)), 6);
				if object.cp.backMarkerOffset == nil or ztt > object.cp.backMarkerOffset then
					object.cp.backMarkerOffset = ztt
				end
				if object.cp.aiFrontMarker == nil  or ztt < object.cp.aiFrontMarker then
					object.cp.aiFrontMarker = ztt
				end
			end
		end
	end

	if vehicle.cp.backMarkerOffset == nil or object.cp.backMarkerOffset < vehicle.cp.backMarkerOffset then
		vehicle.cp.backMarkerOffset = object.cp.backMarkerOffset
	end

	if object.isFuchsFass then -- TODO (Jakob): move to askForSpecialSettings()
		local x,y,z = 0,0,0;
		local valveOffsetFromRootNode = 0;
		local caOffsetFromValve = -1.5; --4.5;

		if object.distributerIsAttached then
			x,y,z = getWorldTranslation(object.attachedImplements[1].object.rootNode);
		else
			x,y,z = getWorldTranslation(object.rootNode);
			valveOffsetFromRootNode = 3.5;
		end;

		local _, _, distToFuchs = worldToLocal(vehicle.rootNode, x, y, z);
		vehicle.cp.backMarkerOffset = distToFuchs + valveOffsetFromRootNode + caOffsetFromValve;
		object.cp.aiFrontMarker = vehicle.cp.backMarkerOffset - 2.5;
		vehicle.cp.aiFrontMarker = object.cp.aiFrontMarker;
	end;

	if vehicle.cp.aiFrontMarker == nil or object.cp.aiFrontMarker > vehicle.cp.aiFrontMarker then
		vehicle.cp.aiFrontMarker = object.cp.aiFrontMarker
	end
	if not isImplement then --FS15
		vehicle.cp.aiFrontMarker = 0
		vehicle.cp.backMarkerOffset = 0
	end

	if vehicle.cp.aiFrontMarker < -7 then
		vehicle.aiToolExtraTargetMoveBack = math.abs(vehicle.cp.aiFrontMarker)
	end

	courseplay:debug(('%s: setMarkers(): turnEndBackDistance=%s, aiToolExtraTargetMoveBack=%s'):format(nameNum(vehicle), tostring(vehicle.turnEndBackDistance), tostring(vehicle.aiToolExtraTargetMoveBack)), 6);
	courseplay:debug(('%s: setMarkers(): cp.backMarkerOffset=%s, cp.aiFrontMarker=%s'):format(nameNum(vehicle), tostring(vehicle.cp.backMarkerOffset), tostring(vehicle.cp.aiFrontMarker)), 6);
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
		local t = vehicle.tippers[i];
		local isHKD302, isMUK, isSRB35 = false, false, false;

		if t.configFileName ~= nil then
			isHKD302 = t.configFileName == 'data/vehicles/trailers/kroeger/HKD302.xml';
			isMUK = t.configFileName == 'data/vehicles/trailers/kroeger/MUK303.xml' or t.configFileName == 'data/vehicles/trailers/kroeger/MUK402.xml';
			isSRB35 = t.cp.isSRB35; -- t.configFileName == 'data/vehicles/trailers/kroeger/SRB35.xml';
		end;

		-- Default Giants trailers
		if isHKD302 or isMUK or isSRB35 then
			local coverItems = {};
			if isHKD302 then
				local c = getChild(t.rootNode, 'bodyLeft');
				if c ~= nil and c ~= 0 then
					c = getChild(c, 'bodyRight');
				end;
				if c ~= nil and c ~= 0 then
					c = getChild(c, 'body');
				end;
				if c ~= nil and c ~= 0 then
					c = getChild(c, 'plasticPlane');
				end;

				if c ~= nil and c ~= 0 then
					vehicle.cp.tipperHasCover = true;
					table.insert(coverItems, c);
				end;
			elseif isMUK then
				local c = getChild(t.rootNode, 'tank');
				local c1, c2;
				if c ~= nil and c ~= 0 then
					c1 = getChild(c, 'planeFlapLeft');
					c2 = getChild(c, 'planeFlapRight');
				end;

				if c1 ~= nil and c1 ~= 0 and c2 ~= nil and c2 ~= 0  then
					vehicle.cp.tipperHasCover = true;
					table.insert(coverItems, c1);
					table.insert(coverItems, c2);
				end;
			elseif isSRB35 then
				local c = getChild(t.rootNode, 'plasticPlane');
				if c ~= nil and c ~= 0 then
					vehicle.cp.tipperHasCover = true;
					table.insert(coverItems, c);
				end;
			end;

			if vehicle.cp.tipperHasCover and #(coverItems) > 0 then
				courseplay:debug(string.format('Implement %q has a cover (coverItems ~= nil)', tostring(t.name)), 6);
				local data = {
					coverType = 'defaultGiants',
					tipperIndex = i,
					coverItems = coverItems
				};
				table.insert(vehicle.cp.tippersWithCovers, data);
			end;

		-- setPlane (SMK-34 et al.)
		elseif t.setPlane ~= nil and type(t.setPlane) == 'function' and t.currentPlaneId == nil and t.currentPlaneSetId == nil then
			--NOTE: setPlane is both in SMK and in chaffCover.lua -> check for currentPlaneId, currentPlaneSetId (chaffCover) nil
			courseplay:debug(string.format('Implement %q has a cover (setPlane ~= nil)', tostring(t.name)), 6);
			vehicle.cp.tipperHasCover = true;
			local data = {
				coverType = 'setPlane',
				tipperIndex = i,
				showCoverWhenTipping = t.cp.xmlFileName == 'SMK34.xml'
			};
			table.insert(vehicle.cp.tippersWithCovers, data);

		-- planeOpen (TUW et al.)
		elseif t.planeOpen ~= nil and t.animationParts[3] ~= nil and t.animationParts[3].offSet ~= nil and t.animationParts[3].animDuration ~= nil then
			courseplay:debug(string.format('Implement %q has a cover (planeOpen ~= nil)', tostring(t.name)), 6);
			vehicle.cp.tipperHasCover = true;
			local data = {
				coverType = 'planeOpen',
				tipperIndex = i
			};
			table.insert(vehicle.cp.tippersWithCovers, data);

		-- setCoverState (Hobein 18t et al.)
		elseif t.setCoverState ~= nil and type(t.setCoverState) == 'function' and t.cover ~= nil and t.cover.opened ~= nil and t.cover.closed ~= nil and t.cover.state ~= nil then
			courseplay:debug(string.format('Implement %q has a cover (setCoverState ~= nil)', tostring(t.name)), 6);
			vehicle.cp.tipperHasCover = true;
			local data = {
				coverType = 'setCoverState',
				tipperIndex = i
			};
			table.insert(vehicle.cp.tippersWithCovers, data);

		-- setCoverState (Giants Marshall DLC)
		elseif t.setCoverState ~= nil and type(t.setCoverState) == 'function' and t.covers ~= nil and t.isCoverOpen ~= nil then
			courseplay:debug(string.format('Implement %q has a cover (setCoverState [Giants Marshall DLC] ~= nil)', tostring(t.name)), 6);
			vehicle.cp.tipperHasCover = true;
			local data = {
				coverType = 'setCoverStateGiants',
				tipperIndex = i
			};
			table.insert(vehicle.cp.tippersWithCovers, data);

		-- setSheet (Marston)
		elseif t.setSheet ~= nil and t.sheet ~= nil and t.sheet.isActive ~= nil then
			courseplay:debug(string.format('Implement %q has a cover (setSheet ~= nil)', tostring(t.name)), 6);
			vehicle.cp.tipperHasCover = true;
			local data = {
				coverType = 'setSheet',
				tipperIndex = i
			};
			table.insert(vehicle.cp.tippersWithCovers, data);
		end;
	end;
end;

function courseplay:setAutoTurnradius(vehicle, hasWorkTool)
	local sinAlpha = 0;		-- Sinus vom Lenkwinkel
	local wheelbase = 0;	-- Radstand
	local track = 0;		-- Spurweite
	local turnRadius = 0;	-- Wendekreis unbereinigt
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
		turnRadius = 2*wheelbase/sinAlpha+track
		vehicle.foundWheels = {}
	else
		turnRadius = vehicle.cp.turnRadius                  -- Kasi and Co are not supported. Nobody does hauling with a Kasi or Quadtrack !!!
	end;
	
	if hasWorkTool and (vehicle.cp.mode == 2 or vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6) then --TODO (Jakob): I've added modes 3, 4 & 6 - needed?
		vehicle.cp.turnRadiusAuto = turnRadius;
		--print(string.format("vehicle.tippers[1].sizeLength = %s  turnRadius = %s", tostring(vehicle.tippers[1].sizeLength),tostring( turnRadius)))
		if vehicle.cp.numWorkTools == 1 and vehicle.tippers[1].attacherVehicle ~= vehicle and (vehicle.tippers[1].sizeLength > turnRadius) then
			vehicle.cp.turnRadiusAuto = vehicle.tippers[1].sizeLength;
		end;
		if (vehicle.cp.numWorkTools > 1) then
			vehicle.cp.turnRadiusAuto = turnRadius * 1.5;
		end
	end;

	if vehicle.cp.turnRadiusAutoMode then
		vehicle.cp.turnRadius = vehicle.cp.turnRadiusAuto;
		if math.abs(vehicle.cp.turnRadius) > 50 then
			vehicle.cp.turnRadius = 15
		end
	end;
end

--##################################################


-- ##### LOADING TOOLS ##### --
function courseplay:load_tippers(vehicle, allowedToDrive)
	local cx, cz = vehicle.Waypoints[2].cx, vehicle.Waypoints[2].cz;

	if vehicle.cp.currentTrailerToFill == nil then
		vehicle.cp.currentTrailerToFill = 1;
	end
	local currentTrailer = vehicle.tippers[vehicle.cp.currentTrailerToFill];

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
				courseplay:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
			end;
		else
			courseplay:setGlobalInfoText(vehicle, 'FARM_SILO_DONT_HAVE_FILTYPE');
		end;
	end;

	-- drive on when required fill level is reached
	local driveOn = false;
	if vehicle.cp.timeOut < vehicle.timer or vehicle.cp.prevFillLevelPct == nil then
		if vehicle.cp.prevFillLevelPct ~= nil and vehicle.cp.tipperFillLevelPct == vehicle.cp.prevFillLevelPct and vehicle.cp.tipperFillLevelPct > vehicle.cp.driveOnAtFillLevel then
			driveOn = true;
		end;
		vehicle.cp.prevFillLevelPct = vehicle.cp.tipperFillLevelPct;
		courseplay:set_timeout(vehicle, 7000);
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
		courseplay:debug(nameNum(vehicle) .. ": getTipDistanceFromTrailer function doesn't exist for currentTipTrigger - unloading function aborted", 2);
		return allowedToDrive;
	end;

	local isBGA = ctt.bunkerSilo ~= nil and ctt.bunkerSilo.movingPlanes ~= nil and vehicle.cp.handleAsOneSilo ~= true;
	local bgaIsFull = isBGA and (ctt.bunkerSilo.fillLevel >= ctt.bunkerSilo.capacity);

	for k, tipper in pairs(vehicle.tippers) do
		if tipper.tipReferencePoints ~= nil then
			local allowedToDriveBackup = allowedToDrive;
			local fruitType = tipper.currentFillType
			local distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper);
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

				if vehicle.isRealistic then stopAndGo = true; end;

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
				if vehicle.Waypoints[vehicle.recordnumber].rev or vehicle.cp.isReverseBGATipping then
					-- Get the silo section fill level based on how many sections and total capacity.
					local medianSiloCapacity = ctt.bunkerSilo.capacity / silos * 0.92; -- we make it a bit smaler than it actually is, since it will still unload a bit to the silo next to it.

					-- Find what BGA silo section to unload in if not found
					if not vehicle.cp.BGASelectedSection then
						-- TODO: (Claus) Make sure that the route is long enough (#535)

						vehicle.cp.BGASectionInverted = false;

						-- Find out what end to start at.
						if startDistance > endDistance then
							vehicle.cp.BGASelectedSection = 1;
						else
							vehicle.cp.BGASelectedSection = silos;
							vehicle.cp.BGASectionInverted = true;
						end;

						-- Find which section to unload into.
						while (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection > 1) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection < silos) do
							if ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel < medianSiloCapacity then
								break;
							end;

							if vehicle.cp.BGASectionInverted then
								vehicle.cp.BGASelectedSection = vehicle.cp.BGASelectedSection - 1;
							else
								vehicle.cp.BGASelectedSection = vehicle.cp.BGASelectedSection + 1;
							end;
						end;

						courseplay:debug(string.format("%s: BGA selected silo section: %d - Is inverted order: %s", nameNum(vehicle), vehicle.cp.BGASelectedSection, tostring(vehicle.cp.BGASectionInverted)), 13);
					end;

					-- Check if last silo section.
					local isLastSiloSection = (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == 1) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == silos);

					-- Start unloading some silo section before main silo section to make a ramp for the trailer.
					if not isLastSiloSection and nearestBGASection ~= vehicle.cp.BGASelectedSection then
						local unloadNumOfSectionBefore = 6;
						local sectionMaxFillLevel = 0;
						local isInUnloadSection = false;

						-- INVERTED SILO DIRECTION
						if (vehicle.cp.BGASectionInverted and nearestBGASection >= vehicle.cp.BGASelectedSection - unloadNumOfSectionBefore) and nearestBGASection < vehicle.cp.BGASelectedSection then
							-- recalculate the num of section before, in case the num of section left is less.
							unloadNumOfSectionBefore = math.min(vehicle.cp.BGASelectedSection - 1,unloadNumOfSectionBefore);

							-- Calculate the current section max fill level.
							sectionMaxFillLevel = (unloadNumOfSectionBefore - math.max(vehicle.cp.BGASelectedSection - nearestBGASection, 0) + 1) * ((medianSiloCapacity * 0.5) / unloadNumOfSectionBefore);

							isInUnloadSection = true;

						-- NORMAL SILO DIRECTION
						elseif (not vehicle.cp.BGASectionInverted and nearestBGASection <= vehicle.cp.BGASelectedSection + unloadNumOfSectionBefore) and nearestBGASection > vehicle.cp.BGASelectedSection then
							-- recalculate the num of section before, in case the num of section left is less.
							unloadNumOfSectionBefore = math.min(silos - vehicle.cp.BGASelectedSection ,unloadNumOfSectionBefore)

							-- Calculate the current section max fill level.
							sectionMaxFillLevel = (unloadNumOfSectionBefore - math.max(nearestBGASection - vehicle.cp.BGASelectedSection, 0) + 1) * ((medianSiloCapacity * 0.5) / unloadNumOfSectionBefore);

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
							courseplay:debug(string.format("%s: Ramp(%d) fill level is at max. Waiting with unloading.]", nameNum(vehicle), nearestBGASection), 13);
						end;
					end;

					-- Get a vector distance, to make a more precise distance check.
					local xmp, _, zmp = getWorldTranslation(ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].nodeId);
					local _, _, vectorDistance = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, xmp, y, zmp);
					if tipper.cp.inversedRearTipNode then vectorDistance = vectorDistance * -1 end;

					-- If we drive too far, then change direction and try to replace again.
					if not isLastSiloSection and (vectorDistance > 1 or vectorDistance < -1) and nearestBGASection ~= vehicle.cp.BGASelectedSection then
						local isChangingDirection = false;

						if vectorDistance > 0 and vehicle.Waypoints[vehicle.recordnumber].rev then
							-- Change direction to forward
							vehicle.cp.isReverseBGATipping = true;
							isChangingDirection = true;
							courseplay:setRecordNumber(vehicle, courseplay:getNextFwdPoint(vehicle));
						elseif vectorDistance < 0 and not vehicle.Waypoints[vehicle.recordnumber].rev then
							-- Change direction to reverse
							local found = false;
							for i = vehicle.recordnumber, 1, -1 do
								if vehicle.Waypoints[i].rev then
									courseplay:setRecordNumber(vehicle, i);
									found = true;
								end;
							end;

							if found then
								vehicle.cp.isReverseBGATipping = false;
								isChangingDirection = true;
							end;
						end;

						if isChangingDirection then
							courseplay:debug(string.format("%s: Changed direction to %s to try reposition again.]", nameNum(vehicle), vehicle.Waypoints[vehicle.recordnumber].rev and "reverse" or "forward"), 13);
						end;
					end;


					-- Make sure we drive to the middle of the next silo section before stopping again.
					if vehicle.cp.isReverseBGATipping and vectorDistance > 0 then
						courseplay:debug(string.format("%s: Moving to the middle of silo section %d - current distance: %.3fm]", nameNum(vehicle), vehicle.cp.BGASelectedSection, vectorDistance), 13);

					-- Unload if inside the selected section
					elseif trailerInTipRange and nearestBGASection == vehicle.cp.BGASelectedSection then
						goForTipping = trailerInTipRange and vectorDistance > -2.5;
					end;

					-- Goto the next silo section if this one is filled and not last silo section.
					if not isLastSiloSection and ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel >= medianSiloCapacity then
						-- Make sure we run this script even that we are not in an reverse waypoint anymore.
						vehicle.cp.isReverseBGATipping = true;

						-- Find next section to unload into.
						while (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection > 1) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection < silos) do
							if ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel < medianSiloCapacity then
								break;
							end;

							if vehicle.cp.BGASectionInverted then
								vehicle.cp.BGASelectedSection = vehicle.cp.BGASelectedSection - 1;
							else
								vehicle.cp.BGASelectedSection = vehicle.cp.BGASelectedSection + 1;
							end;
						end;

						-- Find the first forward waypoint ahead of the vehicle so we can drive ahead to the next silo section.
						courseplay:setRecordNumber(vehicle, courseplay:getNextFwdPoint(vehicle));

						courseplay:debug(string.format("%s: New BGA silo section: %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 13);
					elseif isLastSiloSection and goForTipping then
						-- Make sure we run this script even that we are not in an reverse waypoint anymore.
						vehicle.cp.isReverseBGATipping = true;

						-- Make sure that we don't reverse into the silo after it's full
						courseplay:setRecordNumber(vehicle, courseplay:getNextFwdPoint(vehicle));
					end;

				-------------------------------
				--- Normal BGA unload
				-------------------------------
				else
					-- Get the silo section fill level based on how many sections and total capacity.
					local medianSiloCapacity = ctt.bunkerSilo.capacity / silos;

					-- Get the animation
					local animation = tipper.tipAnimations[bestTipReferencePoint];
					local totalLength = math.abs(endDistance - startDistance);
					local fillDelta = vehicle.cp.tipperFillLevel / vehicle.cp.tipperCapacity;
					local totalTipDuration = ((animation.dischargeEndTime - animation.dischargeStartTime) / animation.animationOpenSpeedScale) * fillDelta / 1000;
					local meterPrSeconds = totalLength / totalTipDuration;
					if stopAndGo then
						meterPrSeconds = vehicle.cp.speeds.unload * 1000;
					end;

					-- Find what BGA silo section to unload in if not found
					if not vehicle.cp.BGASelectedSection then
						local fillLevel = ctt.bunkerSilo.fillLevel;
						if ctt.bunkerSilo.cpTempFillLevel then fillLevel = ctt.bunkerSilo.cpTempFillLevel end;

						vehicle.cp.bunkerSiloSectionFillLevel = math.min((fillLevel + (vehicle.cp.tipperFillLevel * 0.9))/silos, medianSiloCapacity);
						courseplay:debug(string.format("%s: Max allowed fill level pr. section = %.2f", nameNum(vehicle), vehicle.cp.bunkerSiloSectionFillLevel), 2);
						vehicle.cp.BGASectionInverted = false;

						ctt.bunkerSilo.cpTempFillLevel = fillLevel + vehicle.cp.tipperFillLevel;
						courseplay:debug(string.format("%s: cpTempFillLevel = %.2f", nameNum(vehicle), ctt.bunkerSilo.cpTempFillLevel), 2);

						-- Find out what end to start at.
						if startDistance < endDistance then
							vehicle.cp.BGASelectedSection = 1;
						else
							vehicle.cp.BGASelectedSection = silos;
							vehicle.cp.BGASectionInverted = true;
						end;

						-- Find which section to unload into.
						while (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection < silos) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection > 1) do
							if ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel then
								break;
							end;

							if vehicle.cp.BGASectionInverted then
								vehicle.cp.BGASelectedSection = vehicle.cp.BGASelectedSection - 1;
							else
								vehicle.cp.BGASelectedSection = vehicle.cp.BGASelectedSection + 1;
							end;
						end;

						courseplay:debug(string.format("%s: BGA selected silo section: %d - Is inverted order: %s", nameNum(vehicle), vehicle.cp.BGASelectedSection, tostring(vehicle.cp.BGASectionInverted)), 2);

					end;

					if not vehicle.cp.bunkerSiloSectionFillLevel then
						courseplay:resetTipTrigger(vehicle);
						return allowedToDrive;
					end;

					local isLastSiloSection = (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == 1) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == silos);

					-- Get a vector distance, to make a more precise distance check.
					local xmp, _, zmp = getWorldTranslation(ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].nodeId);
					local _, _, vectorDistance = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, xmp, y, zmp);
					local isOpen = tipper:getCurrentTipAnimationTime() >= animation.animationDuration;

					if not isLastSiloSection and ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel >= vehicle.cp.bunkerSiloSectionFillLevel then
						if tipper.tipState ~= Trailer.TIPSTATE_CLOSING and tipper.tipState ~= Trailer.TIPSTATE_CLOSED then
							tipper:toggleTipState();
							courseplay:debug(string.format("%s: SiloSection(%d) fill level is at max allowed fill level. Stopping unloading and move to next.", nameNum(vehicle), vehicle.cp.BGASelectedSection), 2);
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
							vehicle.cp.BGASelectedSection = math.max(vehicle.cp.BGASelectedSection - 1, 1);
						else
							vehicle.cp.BGASelectedSection = math.min(vehicle.cp.BGASelectedSection + 1, silos);
						end;
						courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 2);
					end;

					local isFirseSiloSection = (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == silos) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == 1);

					-- Open hatch before time
					if courseplay:isPushWagon(tipper) then
						local openDistance = meterPrSeconds * (animation.animationDuration / animation.animationOpenSpeedScale / 1000);
						if vectorDistance <= (3 + openDistance) and not isOpen then
							tipper:enableTipAnimation(bestTipReferencePoint, 1);
						end;
					end;

					-- Slow down to real unload speed
					if not vehicle.cp.backupUnloadSpeed and not stopAndGo and vectorDistance < 6*meterPrSeconds then
						-- Calculate the unloading speed.
						local refSpeed = meterPrSeconds * 3.6 * 0.80;
						vehicle.cp.backupUnloadSpeed = vehicle.cp.speeds.unload * 3600;
						courseplay:changeUnloadSpeed(vehicle, nil, refSpeed, true);
						courseplay:debug(string.format("%s: BGA totalLength=%.2f,  totalTipDuration%.2f,  refSpeed=%.2f", nameNum(vehicle), totalLength, totalTipDuration, refSpeed), 2);
					end;

					local canUnload = false;
					-- We can unload if we are in the right distance to the first silo
					if isFirseSiloSection then
						if vectorDistance < 2 then
							canUnload = ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel;
						end;

						if vehicle.cp.BGASelectedSection ~= nearestBGASection and not vehicle.cp.isChangingPosition then
							vehicle.cp.BGASelectedSection = nearestBGASection;
							courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 2);
						end;
					elseif vehicle.cp.BGASelectedSection == nearestBGASection then
						canUnload = ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel or isLastSiloSection;
						if vehicle.cp.isChangingPosition then vehicle.cp.isChangingPosition = nil end;
					elseif vehicle.cp.BGASelectedSection ~= nearestBGASection and not vehicle.cp.isChangingPosition then
						vehicle.cp.BGASelectedSection = nearestBGASection;
						courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 2);
					end;

					goForTipping = trailerInTipRange and canUnload;

					--if goForTipping or isLastSiloSection then
					if isLastSiloSection or stopAndGo then
						if (not stopAndGo and vectorDistance < -2) or (stopAndGo and vehicle.cp.BGASelectedSection == nearestBGASection and goForTipping) then
							allowedToDriveBackup = false;
						end;
					end;
				end;

			--BGA TIPTRIGGER BUT IS FULL AND WE ARE REVERSE TIPPING
			elseif isBGA and bgaIsFull and (vehicle.Waypoints[vehicle.recordnumber].rev or vehicle.cp.isReverseBGATipping) then
				-- Stop the vehicle, since we don't want to reverse into the BGA if it's full.
				allowedToDrive = false;
				-- Tell the user why we have stoped.
				courseplay:setGlobalInfoText(vehicle, 'BGA_IS_FULL');

			-- BGA TIPTRIGGER IS FULL
			elseif isBGA and bgaIsFull and not vehicle.Waypoints[vehicle.recordnumber].rev and not vehicle.cp.isReverseBGATipping then
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
				if vehicle.cp.unloadingTipper == nil or vehicle.cp.unloadingTipper == tipper then -- make sure we only tip one trailer at the time
					if isBGA then
						courseplay:debug(nameNum(vehicle) .. ": goForTipping = true [BGA trigger accepts fruit (" .. tostring(fruitType) .. ")]", 2);
					else
						courseplay:debug(nameNum(vehicle) .. ": goForTipping = true [trigger accepts fruit (" .. tostring(fruitType) .. ")]", 2);
					end;

					if tipper.tipState == Trailer.TIPSTATE_CLOSED or tipper.tipState == Trailer.TIPSTATE_CLOSING then
						vehicle.toggledTipState = bestTipReferencePoint;
						local isNearestPoint = false
						if distanceToTrigger > tipper.cp.closestTipDistance then
							isNearestPoint = true
							courseplay:debug(nameNum(vehicle) .. ": isNearestPoint = true ", 2);
						else
							tipper.cp.closestTipDistance = distanceToTrigger
						end
						if distanceToTrigger == 0 or isBGA or isNearestPoint then
							tipper:toggleTipState(ctt,vehicle.toggledTipState);
							vehicle.cp.unloadingTipper = tipper
							courseplay:debug(nameNum(vehicle)..": toggleTipState: "..tostring(vehicle.toggledTipState).."  /unloadingTipper= "..tostring(vehicle.cp.unloadingTipper.name), 2);
							allowedToDrive = false;
						end
					elseif tipper.tipState ~= Trailer.TIPSTATE_CLOSING then
						tipper.cp.closestTipDistance = math.huge
						allowedToDrive = false;
					end;

					if isBGA and ((not vehicle.Waypoints[vehicle.recordnumber].rev and not vehicle.cp.isReverseBGATipping) or unloadWhileReversing) then
						allowedToDrive = allowedToDriveBackup;
					end;
				else
					tipper.cp.closestTipDistance = math.huge;
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
	vehicle.cp.BGASelectedSection = nil; -- Used for reverse BGA tipping
	vehicle.cp.inversedRearTipNode = nil; -- Used for reverse BGA tipping
	if vehicle.cp.backupUnloadSpeed then
		courseplay:changeUnloadSpeed(vehicle, nil, vehicle.cp.backupUnloadSpeed, true);
		vehicle.cp.backupUnloadSpeed = nil;
	end;
	if changeToForward and vehicle.Waypoints[vehicle.recordnumber].rev then
		courseplay:setRecordNumber(vehicle, courseplay:getNextFwdPoint(vehicle));
	end;
end;

