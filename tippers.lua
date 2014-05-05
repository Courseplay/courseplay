function courseplay:attachImplement(implement)
	--local impl = implement.object;
end;
function courseplay:detachImplement(implementIndex)
	self.cp.toolsDirty = true;
end;

function courseplay:reset_tools(vehicle)
	vehicle.tippers = {}
	-- are there any tippers?
	vehicle.cp.tipperAttached = courseplay:update_tools(vehicle, vehicle)
	vehicle.cp.currentTrailerToFill = nil
	vehicle.cp.lastTrailerToFillDistance = nil
	vehicle.cp.toolsDirty = false;
end

function courseplay:isCombine(workTool)
	return (workTool.cp.hasSpecializationCombine or workTool.cp.hasSpecializationAICombine) and workTool.grainTankCapacity ~= nil and workTool.grainTankCapacity > 0;
end;
function courseplay:isChopper(workTool)
	return (workTool.cp.hasSpecializationCombine or workTool.cp.hasSpecializationAICombine) and workTool.grainTankCapacity ~= nil and workTool.grainTankCapacity == 0 or courseplay:isSpecialChopper(workTool);
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
function courseplay:is_baleLoader(workTool) -- is the tool a bale loader?
	return workTool.cp.hasSpecializationBaleLoader or (workTool.balesToLoad ~= nil and workTool.baleGrabber ~=nil and workTool.grabberIsMoving~= nil);
end;
function courseplay:isSprayer(workTool) -- is the tool a sprayer/spreader?
	return workTool.cp.hasSpecializationSprayer or courseplay:isSpecialSprayer(workTool)
end;
function courseplay:is_sowingMachine(workTool) -- is the tool a sowing machine?
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
	return (workTool.typeName~= nil and workTool.typeName == "attachableCombine") or (not workTool.cp.hasSpecializationSteerable and  workTool.grainTankCapacity ~= nil) or courseplay:isSpecialChopper(workTool)
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
	return workTool.typeName:match("forageWagon") or workTool.cp.xmlFileName == 'bergmannHTW65.xml' or workTool.cp.isPushWagon;
end;

-- update implements to find attached tippers
function courseplay:update_tools(vehicle, tractor_or_implement)
	courseplay:setNameVariable(tractor_or_implement);

	--steerable (tractor, combine etc.)
	local tipper_attached = false
	if tractor_or_implement.cp.hasSpecializationAITractor 
	or tractor_or_implement.cp.isHarvesterSteerable 
	or courseplay:isBigM(tractor_or_implement) 
	or courseplay:isMixer(tractor_or_implement)
	or courseplay:isWheelloader(tractor_or_implement)
	or tractor_or_implement.typeName == "frontloader" then
		local object = tractor_or_implement
		if vehicle.cp.mode == 1 or vehicle.cp.mode == 2 then
			-- if object.cp.hasSpecializationTrailer then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(vehicle.tippers, object)
			end
		elseif vehicle.cp.mode == 3 then -- Overlader
			if object.cp.hasSpecializationTrailer then --to do
				tipper_attached = true
				table.insert(vehicle.tippers, object)
			end
		elseif vehicle.cp.mode == 4 then -- Fertilizer
			if courseplay:isSprayer(object) or courseplay:is_sowingMachine(object) then
				tipper_attached = true
				table.insert(vehicle.tippers, object)
				courseplay:setMarkers(vehicle, object)
				vehicle.cp.noStopOnEdge = courseplay:isSprayer(object);
				vehicle.cp.noStopOnTurn = courseplay:isSprayer(object);
				if courseplay:is_sowingMachine(object) then
					vehicle.cp.hasSowingMachine = true;
				end;
			end
		elseif vehicle.cp.mode == 6 then -- Baler, foragewagon, baleloader
			if (courseplay:isBaler(object) 
			or courseplay:is_baleLoader(object) 
			or courseplay:isSpecialBaleLoader(object) 
			or object.cp.hasSpecializationTedder
			or object.cp.hasSpecializationWindrower
			or object.cp.hasSpecializationCultivator
			or object.cp.hasSpecializationPlough
			or object.cp.hasSpecializationFruitPreparer
			or object.allowTipDischarge 
			or courseplay:isFoldable(object)) 
			and not object.cp.isCaseIHMagnum340Titanium 
			and not object.cp.isCaseIHPuma160Titanium 
			and not object.cp.isFendt828VarioFruktor 
			then
				tipper_attached = true;
				table.insert(vehicle.tippers, object);
				courseplay:setMarkers(vehicle, object);
				vehicle.cp.noStopOnTurn = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object) or courseplay:isMower(object);
				vehicle.cp.noStopOnEdge = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object);
				if object.cp.hasSpecializationPlough then 
					vehicle.cp.hasPlough = true;
				end;
			end
		elseif vehicle.cp.mode == 8 then -- Liquid manure transfer
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(vehicle.tippers, object)
			-- end
		elseif vehicle.cp.mode == 9 then --Fill and empty shovel
			if courseplay:isWheelloader(tractor_or_implement) 
			or tractor_or_implement.typeName == "frontloader" 
			or courseplay:isMixer(tractor_or_implement) then
				tipper_attached = true;
				table.insert(vehicle.tippers, object);
				object.cp.shovelState = 1
			end;
		end
	end

	--FOLDING PARTS: isFolded/isUnfolded states
	courseplay:setFoldedStates(tractor_or_implement);


	if not vehicle.cp.hasUBT then
		vehicle.cp.hasUBT = false;
	end;
	-- go through all implements
	vehicle.cp.aiBackMarker = nil

	for k, implement in pairs(tractor_or_implement.attachedImplements) do
		local object = implement.object

		courseplay:setNameVariable(object);

		--FRONT or BACK?
		local implX,implY,implZ = getWorldTranslation(object.rootNode);
		local _,_,tractorToImplZ = worldToLocal(vehicle.rootNode, implX,implY,implZ);
		object.cp.positionAtTractor = Utils.sign(tractorToImplZ);
		courseplay:debug(string.format("%s: tractorToImplZ=%.4f, positionAtTractor=%d", nameNum(object), tractorToImplZ, object.cp.positionAtTractor), 6);

		--ADD TO vehicle.tippers
		if vehicle.cp.mode == 1 or vehicle.cp.mode == 2 then
			--	if object.cp.hasSpecializationTrailer then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(vehicle.tippers, object)
				courseplay:getReverseProperties(vehicle, object)
			end
			
		elseif vehicle.cp.mode == 3 then -- Overlader
			if object.cp.hasSpecializationTrailer and object.cp.isAugerWagon then --to do 
				tipper_attached = true
				table.insert(vehicle.tippers, object)
			end
		elseif vehicle.cp.mode == 4 then -- Fertilizer and Seeding
			if courseplay:isSprayer(object) or courseplay:is_sowingMachine(object) then
				tipper_attached = true
				table.insert(vehicle.tippers, object)
				courseplay:setMarkers(vehicle, object)
				vehicle.cp.noStopOnEdge = courseplay:isSprayer(object);
				vehicle.cp.noStopOnTurn = courseplay:isSprayer(object);
				vehicle.cp.hasMachinetoFill = true
				if courseplay:is_sowingMachine(object) then
					vehicle.cp.hasSowingMachine = true;
				end;
				if object.hasWheels then
					courseplay:getReverseProperties(vehicle, object);
				end;
			end
		elseif vehicle.cp.mode == 5 then -- Transfer
			if object.setPlane ~= nil then --open/close cover
				tipper_attached = true;
				table.insert(vehicle.tippers, object);
			end;
		elseif vehicle.cp.mode == 6 then -- Baler, foragewagon, baleloader
			if courseplay:isBaler(object) 
			or courseplay:is_baleLoader(object) 
			or courseplay:isSpecialBaleLoader(object) 
			or object.cp.hasSpecializationTedder
			or object.cp.hasSpecializationWindrower
			or object.cp.hasSpecializationCultivator
			or object.cp.hasSpecializationPlough
			or object.cp.hasSpecializationFruitPreparer 
			or object.allowTipDischarge 
			or courseplay:isMower(object)
			or courseplay:isAttachedCombine(object) 
			or courseplay:isFoldable(object) then
				tipper_attached = true
				table.insert(vehicle.tippers, object)
				courseplay:setMarkers(vehicle, object)
				vehicle.cp.noStopOnTurn = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object);
				vehicle.cp.noStopOnEdge = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object);
				if object.cp.hasSpecializationPlough then 
					vehicle.cp.hasPlough = true;
				end;
			end;
			if courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object) then
				vehicle.cp.hasBaleLoader = true;
				courseplay:getReverseProperties(vehicle, object)
			elseif object.allowTipDischarge then
				courseplay:getReverseProperties(vehicle, object)
			end
		elseif vehicle.cp.mode == 8 then --Liquid manure transfer
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(vehicle.tippers, object)
			--		end
		elseif vehicle.cp.mode == 9 then --Fill and empty shovel
			if courseplay:isFrontloader(object) or object.cp.hasSpecializationShovel then 
				tipper_attached = true;
				table.insert(vehicle.tippers, object);
				object.attacherVehicle.cp.shovelState = 1
			end
		end;

		if object.aiLeftMarker ~= nil and object.aiForceTurnNoBackward == true then 
			vehicle.cp.aiTurnNoBackward = true
			courseplay:debug(string.format("%s: object.aiLeftMarker ~= nil and object.aiForceTurnNoBackward == true --> vehicle.cp.aiTurnNoBackward = true", nameNum(object)), 6);
		elseif object.aiLeftMarker == nil and #(object.wheels) > 0 and object.cp.positionAtTractor <= 0 then
			vehicle.cp.aiTurnNoBackward = true
			courseplay:debug(string.format("%s: object.aiLeftMarker == nil and #(object.wheels) > 0 and object.cp.positionAtTractor <= 0 --> vehicle.cp.aiTurnNoBackward = true", nameNum(object)), 6);
		end

		courseplay:askForSpecialSettings(vehicle,object)

		--FOLDING PARTS: isFolded/isUnfolded states
		courseplay:setFoldedStates(object);

		-- are there more tippers attached to the current implement?
		local other_tipper_attached
		if #(object.attachedImplements) ~= 0 then
			other_tipper_attached = courseplay:update_tools(vehicle, object)
		end
		if other_tipper_attached == true then
			tipper_attached = true
		end
		
		courseplay:debug(string.format("%s: courseplay:update_tools()", nameNum(vehicle)), 6);

		courseplay:debug(('%s: adding %q (%q) to cpTrafficCollisionIgnoreList'):format(nameNum(vehicle), tostring(object.name), tostring(object.cp.xmlFileName)), 3);
		vehicle.cpTrafficCollisionIgnoreList[object.rootNode] = true;
	end; --END for implement in attachedImplements
	
	for k,v in pairs(vehicle.components) do
		vehicle.cpTrafficCollisionIgnoreList[v.node] = true;
	end;


	--MINHUDPAGE for attached combines
	vehicle.cp.attachedCombineIdx = nil;
	if not (vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader) then
		for i=1,#(vehicle.tippers) do
			if courseplay:isAttachedCombine(vehicle.tippers[i]) then
				vehicle.cp.attachedCombineIdx = i;
				break;
			end;
		end;
	end;
	if vehicle.cp.attachedCombineIdx ~= nil then
		--courseplay:debug(string.format("setMinHudPage(vehicle, vehicle.tippers[%d])", vehicle.cp.attachedCombineIdx), 18);
		courseplay:setMinHudPage(vehicle, vehicle.tippers[vehicle.cp.attachedCombineIdx]);
	end;

	--CUTTERS
	if vehicle.attachedCutters ~= nil and #(vehicle.attachedImplements) ~= 0 then
		if vehicle.numAttachedCutters ~= nil and vehicle.numAttachedCutters > 0 then
			for cutter, implement in pairs(vehicle.attachedCutters) do
				local object = implement.object
				if object ~= nil and object.cp == nil then
					object.cp = {};
				end;

				if vehicle.cp.mode == 6 then
					tipper_attached = true;
					table.insert(vehicle.tippers, object);
					courseplay:setMarkers(vehicle, object)
					vehicle.cpTrafficCollisionIgnoreList[object.rootNode] = true;
					for k,v in pairs(object.components) do
						vehicle.cpTrafficCollisionIgnoreList[v.node] = true;
					end;
				end;
			end;
		end;
	end;
	
	if courseplay.debugChannels[3] then
		courseplay:debug(string.format("%s cpTrafficCollisionIgnoreList", nameNum(vehicle)), 3);
		for a,b in pairs(vehicle.cpTrafficCollisionIgnoreList) do
			local name = g_currentMission.nodeToVehicle[a].name
			courseplay:debug(string.format("\\___ %s = %s", tostring(a), tostring(name)), 3);
		end;
	end

	courseplay:getAutoTurnradius(vehicle, tipper_attached);
	
	--tipreferencepoints 
	vehicle.cp.tipRefOffset = nil;
	for i=1, #(vehicle.tippers) do
		if tipper_attached and vehicle.tippers[i].rootNode ~= nil and vehicle.tippers[i].tipReferencePoints ~= nil then
			local tipperX, tipperY, tipperZ = getWorldTranslation(vehicle.tippers[i].rootNode);
			if tipper_attached and #(vehicle.tippers[i].tipReferencePoints) > 1 then
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
			vehicle.cp.tipRefOffset = 1.5
		end;
		if vehicle.cp.tipRefOffset ~= nil then
			break
		end		
	end

	--tippers with covers
	vehicle.cp.tipperHasCover = false;
	vehicle.cp.tippersWithCovers = {};
	if tipper_attached then
		courseplay:setTipperCoverData(vehicle);
	end;
	--END tippers with covers


	if tipper_attached then
		return true;
	end;
	return nil;
end;

function courseplay:setMarkers(vehicle, object)
	object.cp.backMarkerOffset = nil
	object.cp.aiFrontMarker = nil
	-- get the behindest and the frontest  points :-) ( as offset to root node)
	local area = object.cuttingAreas
	if courseplay:isBigM(object) then
		area = object.mowerCutAreas
	elseif object.typeName == "defoliator_animated" then
		area = object.fruitPreparerAreas
	end

	local tableLength = #(area)
	if tableLength == 0 then
		return
	end
	for k = 1, tableLength do
		for j,node in pairs(area[k]) do
			if j == "start" or j == "height" or j == "width" then 
				local x, y, z = getWorldTranslation(node)
				local _, _, ztt = worldToLocal(vehicle.rootNode, x, y, z)
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

	if vehicle.cp.aiFrontMarker < -7 then
		vehicle.aiToolExtraTargetMoveBack = math.abs(vehicle.cp.aiFrontMarker)
	end
	courseplay:debug(nameNum(vehicle) .. " vehicle.turnEndBackDistance: "..tostring(vehicle.turnEndBackDistance).."  vehicle.aiToolExtraTargetMoveBack: "..tostring(vehicle.aiToolExtraTargetMoveBack),6);
	courseplay:debug(nameNum(vehicle) .. " setMarkers(): vehicle.cp.backMarkerOffset: "..tostring(vehicle.cp.backMarkerOffset).."  vehicle.cp.aiFrontMarker: "..tostring(vehicle.cp.aiFrontMarker), 6);
end;

function courseplay:setFoldedStates(object)
	if courseplay:isFoldable(object) and object.turnOnFoldDirection then
		if courseplay.debugChannels[17] then print(string.rep('-', 50)); end;
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
		if courseplay.debugChannels[17] then print(string.rep('-', 50)); end;
	end;
end;

function courseplay:setTipperCoverData(vehicle)
	for i=1, #(vehicle.tippers) do
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

-- loads all tippers
function courseplay:load_tippers(vehicle)
	local allowedToDrive = false;
	local cx, cz = vehicle.Waypoints[2].cx, vehicle.Waypoints[2].cz;

	if vehicle.cp.currentTrailerToFill == nil then
		vehicle.cp.currentTrailerToFill = 1;
	end
	local currentTrailer = vehicle.tippers[vehicle.cp.currentTrailerToFill];

	-- SUPER SILO TRIGGER
	if currentTrailer.currentSuperSiloTrigger ~= nil then
		local sst = currentTrailer.currentSuperSiloTrigger;
		local triggerFillType;
		if sst.fillTypes and sst.currentFillType and sst.fillTypes[sst.currentFillType] then
			triggerFillType = sst.fillTypes[sst.currentFillType].fillType;
		end;
		if triggerFillType and currentTrailer:allowFillType(triggerFillType, true) then
			if not currentTrailer.currentSuperSiloTrigger.isFilling then
				currentTrailer.currentSuperSiloTrigger:setIsFilling(true);
			end;
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
		vehicle.cp.isLoaded = true;
		vehicle.cp.lastTrailerToFillDistance = nil;
		vehicle.cp.currentTrailerToFill = nil;
		return true;
	end;

	if vehicle.cp.lastTrailerToFillDistance == nil then
		-- drive on if current tipper is full
		if currentTrailer.fillLevel == currentTrailer.capacity then
			if #(vehicle.tippers) > vehicle.cp.currentTrailerToFill then
				local trailerX, _, trailerZ = getWorldTranslation(currentTrailer.fillRootNode);
				vehicle.cp.lastTrailerToFillDistance = courseplay:distance(cx, cz, trailerX, trailerZ);
				vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
			else
				vehicle.cp.currentTrailerToFill = nil;
				vehicle.cp.lastTrailerToFillDistance = nil;
			end;
			allowedToDrive = true;
		end;

	else
		local trailerX, _, trailerZ = getWorldTranslation(currentTrailer.fillRootNode);
		local distance = courseplay:distance(cx, cz, trailerX, trailerZ);

		if distance > vehicle.cp.lastTrailerToFillDistance and vehicle.cp.lastTrailerToFillDistance ~= nil then
			allowedToDrive = true;
		else
			allowedToDrive = false;
			if currentTrailer.fillLevel == currentTrailer.capacity then
				if #(vehicle.tippers) > vehicle.cp.currentTrailerToFill then
					vehicle.cp.lastTrailerToFillDistance = courseplay:distance(cx, cz, trailerX, trailerZ);
					vehicle.cp.currentTrailerToFill = vehicle.cp.currentTrailerToFill + 1;
				else
					vehicle.cp.currentTrailerToFill = nil;
					vehicle.cp.lastTrailerToFillDistance = nil;
				end;
			end;
		end;
	end;

	-- normal mode if all tippers are empty
	return allowedToDrive;
end

-- unloads all tippers
function courseplay:unload_tippers(vehicle, allowedToDrive)
	local ctt = vehicle.cp.currentTipTrigger;
	if ctt.getTipDistanceFromTrailer == nil then
		courseplay:debug(nameNum(vehicle) .. ": getTipDistanceFromTrailer function doesn't exist for currentTipTrigger - unloading function aborted", 2);
		return allowedToDrive;
	end;

	local isBGA = ctt.bunkerSilo ~= nil and ctt.bunkerSilo.movingPlanes ~= nil;
	local bgaIsFull = isBGA and (ctt.bunkerSilo.fillLevel >= ctt.bunkerSilo.capacity);

	for k, tipper in pairs(vehicle.tippers) do
		if tipper.tipReferencePoints ~= nil then
			local allowedToDriveBackup = allowedToDrive;
			local fruitType = tipper.currentFillType
			--local positionInSilo = -1;
			local distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper);
			local trailerInTipRange = g_currentMission:getIsTrailerInTipRange(tipper, ctt, bestTipReferencePoint);
			courseplay:debug(nameNum(vehicle)..": distanceToTrigger: "..tostring(distanceToTrigger).."  /bestTipReferencePoint: "..tostring(bestTipReferencePoint).." /trailerInTipRange: "..tostring(trailerInTipRange), 2);
			local goForTipping = false;
			local unloadWhileReversing = false; -- Used by Reverse BGA Tipping
			local isRePositioning = false; -- Used by Reverse BGA Tipping

			--BGA TRIGGER
			if isBGA and not bgaIsFull then
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
						vehicle.cp.BGASectionInverted = false;
						vehicle.cp.isChangingDirection = false;
						vehicle.cp.lastDistance = math.huge;

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
							goForTipping = trailerInTipRange and nearestDistance < 2.5;
							unloadWhileReversing = true;
						elseif isInUnloadSection and tipper.tipState ~= Trailer.TIPSTATE_CLOSING and tipper.tipState ~= Trailer.TIPSTATE_CLOSED then
							tipper:toggleTipState();
							courseplay:debug(string.format("%s: Ramp(%d) fill level is at max. Waiting with unloading.]", nameNum(vehicle), nearestBGASection), 13);
						end;
					end;

					-- Get the silo section distance from bestTipReferencePoint
					local wx, wy, wz = getWorldTranslation(ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].nodeId);
					nearestDistance = Utils.vector2Length(wx - x, wz - z);

					-- If we drive too far, then change direction and try to replace again.
					if not isLastSiloSection and nearestDistance > 1 --[[and nearestDistance > vehicle.cp.lastDistance and nearestBGASection ~= vehicle.cp.BGASelectedSection]] then
						if nearestDistance < vehicle.cp.lastDistance then
							-- prevent it from changing direction all the time.
							if vehicle.cp.isChangingDirection then
								vehicle.cp.isChangingDirection = false;
								courseplay:debug(string.format("%s: Changed direction to %s to try reposition again.]", nameNum(vehicle), vehicle.Waypoints[vehicle.recordnumber].rev and "reverse" or "forward"), 13);
							end;
							isRePositioning = true;
						elseif nearestDistance > vehicle.cp.lastDistance and not vehicle.cp.isChangingDirection then
							local _,_,tz = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, wx,wy,wz);
							if tipper.cp.inversedRearTipNode then tz = tz * -1 end;

							if tz > 0 and vehicle.Waypoints[vehicle.recordnumber].rev then
								-- Change direction to forward
								vehicle.cp.isReverseBGATipping = true;
								vehicle.cp.isChangingDirection = true;
								vehicle.recordnumber = courseplay:getNextFwdPoint(vehicle);
							elseif tz < 0 and not vehicle.Waypoints[vehicle.recordnumber].rev then
								-- Change direction to reverse
								local found = false;
								for i = vehicle.recordnumber, 1, -1 do
									if vehicle.Waypoints[i].rev then
										vehicle.recordnumber = i;
										found = true;
									end;
								end;

								if found then
									vehicle.cp.isReverseBGATipping = false;
									vehicle.cp.isChangingDirection = true;
								end;
							end;
						end;
					elseif vehicle.cp.isChangingDirection then
						vehicle.cp.isChangingDirection = false;
					end;

					-- Make sure we drive to the middle of the next silo section before stopping again.
					if (vehicle.cp.isReverseBGATipping and vehicle.cp.lastDistance >= nearestDistance) or isRePositioning then
						--courseplay:debug(string.format("%s: Moving to the middle of silo section %d - current distance: %.3fm]", nameNum(vehicle), vehicle.cp.BGASelectedSection, nearestDistance), 13);

					-- Unload if inside the selected section
					elseif trailerInTipRange and nearestBGASection == vehicle.cp.BGASelectedSection then
						goForTipping = trailerInTipRange and nearestDistance < 2.5;
					end;

					-- Update last distance
					vehicle.cp.lastDistance = nearestDistance;

					-- Goto the next silo section if this one is filled and not last silo section.
					if not isLastSiloSection and ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel >= medianSiloCapacity then
						-- Make sure we run this script even that we are not in an reverse waypoint anymore.
						vehicle.cp.isReverseBGATipping = true;

						-- Make sure we reset the lastDistance in case we move silo section more than once in an unload
						vehicle.cp.lastDistance = math.huge;

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
						vehicle.recordnumber = courseplay:getNextFwdPoint(vehicle);

						courseplay:debug(string.format("%s: New BGA silo section: %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 13);
					elseif isLastSiloSection and goForTipping then
						-- Make sure we run this script even that we are not in an reverse waypoint anymore.
						vehicle.cp.isReverseBGATipping = true;

						-- Make sure that we don't reverse into the silo after it's full
						vehicle.recordnumber = courseplay:getNextFwdPoint(vehicle);
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
						meterPrSeconds = (vehicle.cp.speeds.unload * 3600) * 1000 / 60 / 60;
					end;

					-- Find what BGA silo section to unload in if not found
					if not vehicle.cp.BGASelectedSection then
						vehicle.cp.bunkerSiloSectionFillLevel = math.min((ctt.bunkerSilo.fillLevel + (vehicle.cp.tipperFillLevel * 0.9))/silos, medianSiloCapacity);
						courseplay:debug(string.format("%s: Max allowed fill level pr. section = %.2f", nameNum(vehicle), vehicle.cp.bunkerSiloSectionFillLevel), 12);
						vehicle.cp.BGASectionInverted = false;

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

						courseplay:debug(string.format("%s: BGA selected silo section: %d - Is inverted order: %s", nameNum(vehicle), vehicle.cp.BGASelectedSection, tostring(vehicle.cp.BGASectionInverted)), 12);

					end;

					local isLastSiloSection = (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == 1) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == silos);

					-- Get a vector distance, to make a more precise distance check.
					local xmp, _, zmp = getWorldTranslation(ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].nodeId);
					local _, _, vectorDistance = worldToLocal(tipper.tipReferencePoints[bestTipReferencePoint].node, xmp, y, zmp);
					if vehicle.cp.BGASectionInverted then
						vectorDistance = -vectorDistance;
					end;

					if not isLastSiloSection and ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel >= vehicle.cp.bunkerSiloSectionFillLevel then
						if tipper.tipState ~= Trailer.TIPSTATE_CLOSING and tipper.tipState ~= Trailer.TIPSTATE_CLOSED then
							tipper:toggleTipState();
							courseplay:debug(string.format("%s: SiloSection(%d) fill level is at max allowed fill level. Stopping unloading and move to next.", nameNum(vehicle), vehicle.cp.BGASelectedSection), 12);
							if courseplay:isPushWagon(tipper) then tipper:disableCurrentTipAnimation(tipper.tipAnimations[bestTipReferencePoint].animationDuration); end;
							vehicle.cp.isChangingPosition = true;
						end;
						if vehicle.cp.BGASectionInverted then
							vehicle.cp.BGASelectedSection = math.max(vehicle.cp.BGASelectedSection - 1, 1);
						else
							vehicle.cp.BGASelectedSection = math.min(vehicle.cp.BGASelectedSection + 1, silos);
						end;
						courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 12);
					end;

					local isFirseSiloSection = (vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == silos) or (not vehicle.cp.BGASectionInverted and vehicle.cp.BGASelectedSection == 1);

					-- Open hatch before time
					if isFirseSiloSection and courseplay:isPushWagon(tipper) then
						local openDistance = meterPrSeconds * (animation.animationDuration / animation.animationOpenSpeedScale / 1000);
						local isOpen = tipper:getCurrentTipAnimationTime() >= animation.animationDuration;
						if vectorDistance <= (2 + openDistance) and not isOpen then
							tipper:enableTipAnimation(bestTipReferencePoint, 1);
						end;
					end;

					local canUnload = false;
					-- We can unload if we are in the right distance to the first silo
					if isFirseSiloSection then
						if vectorDistance < 2 then
							canUnload = ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel;
						end;

						-- Slow down to real unload speed
						if not stopAndGo and vectorDistance < 3 and not vehicle.cp.backupUnloadSpeed then
							-- Calculate the unloading speed.
							local refSpeed = meterPrSeconds * 60 * 60 / 1000 * 0.80;
							vehicle.cp.backupUnloadSpeed = vehicle.cp.speeds.unload * 3600;
							courseplay:changeUnloadSpeed(vehicle, nil, refSpeed);
							courseplay:debug(string.format("%s: BGA totalLength=%.2f,  totalTipDuration%.2f,  refSpeed=%.2f", nameNum(vehicle), totalLength, totalTipDuration, refSpeed), 12);
						end;

						if vehicle.cp.BGASelectedSection ~= nearestBGASection and not vehicle.cp.isChangingPosition then
							vehicle.cp.BGASelectedSection = nearestBGASection;
							courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 12);
						end;
					elseif vehicle.cp.BGASelectedSection == nearestBGASection then
						canUnload = ctt.bunkerSilo.movingPlanes[vehicle.cp.BGASelectedSection].fillLevel < vehicle.cp.bunkerSiloSectionFillLevel or isLastSiloSection;
						if vehicle.cp.isChangingPosition then vehicle.cp.isChangingPosition = nil end;
					elseif vehicle.cp.BGASelectedSection ~= nearestBGASection and not vehicle.cp.isChangingPosition then
						vehicle.cp.BGASelectedSection = nearestBGASection;
						courseplay:debug(string.format("%s: Change to siloSection = %d", nameNum(vehicle), vehicle.cp.BGASelectedSection), 12);
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
				vehicle.cp.currentTipTrigger = nil;
				vehicle.cp.isReverseBGATipping = nil;
				vehicle.cp.BGASelectedSection = nil;

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

					if isBGA and ((not vehicle.Waypoints[vehicle.recordnumber].rev and not vehicle.cp.isReverseBGATipping) or unloadWhileReversing or isRePositioning) then
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

function courseplay:getAutoTurnradius(vehicle, tipper_attached)
	local sinAlpha = 0       --Sinus vom Lenkwinkel
	local wheelbase = 0      --Radstand
	local track = 0		 --Spurweite
	local turnRadius = 0     --Wendekreis unbereinigt
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
	
	--if tipper_attached and vehicle.cp.mode == 2 then
	if tipper_attached and (vehicle.cp.mode == 2 or vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6) then --JT: I've added modes 3, 4 & 6 - needed?
		vehicle.cp.turnRadiusAuto = turnRadius;
		local n = #(vehicle.tippers);
		--print(string.format("vehicle.tippers[1].sizeLength = %s  turnRadius = %s", tostring(vehicle.tippers[1].sizeLength),tostring( turnRadius)))
		if n == 1 and vehicle.tippers[1].attacherVehicle ~= vehicle and (vehicle.tippers[1].sizeLength > turnRadius) then
			vehicle.cp.turnRadiusAuto = vehicle.tippers[1].sizeLength;
		end;
		if (n > 1) then
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

function courseplay:getReverseProperties(vehicle, tipper)
	courseplay:debug(('getReverseProperties(%q, %q)'):format(nameNum(vehicle), nameNum(tipper)), 13);

	-- We only need to set this once.
	if not tipper.cp.realTurningNode then
		-- Find the real trailer turning point
		tipper.cp.realTurningNode = courseplay:createRealTrailerTurningNode(vehicle, tipper);
	end;

	-- We only need to set this once.
	if tipper.cp.unloadOrFillNode == nil then
		-- We need to make sure we have all the info when creating the node.
		courseplay:askForSpecialSettings(vehicle,tipper);

		tipper.cp.unloadOrFillNode = courseplay:createUnloadOrFillNode(vehicle, tipper);
	end;

	if tipper.attacherVehicle == vehicle or (#vehicle.tippers > 0 and vehicle.tippers[1] ~= tipper and vehicle.tippers[1].cp.isAttacherModule)then
		tipper.cp.frontNode = getParent(tipper.attacherJoint.node);
	else
		tipper.cp.frontNode = getParent(tipper.attacherVehicle.attacherJoint.node);
		courseplay:debug(string.format('\ttipper %q has dolly', nameNum(tipper)), 13);
	end;
	if tipper.cp.hasSpecializationShovel or vehicle.cp.hasSpecializationShovel then
		courseplay:debug(string.format('\treturn because tipper %q is a shovel', nameNum(tipper)), 13);
		return;
	end;

	local xTipper,yTipper,zTipper = getWorldTranslation(tipper.cp.realTurningNode);

	tipper.cp.nodeDistance = courseplay:getRealTrailerDistanceToPivot(vehicle, tipper);
	courseplay:debug("\ttz: "..tostring(tipper.cp.nodeDistance).."  tipper.cp.realTurningNode: "..tostring(tipper.cp.realTurningNode), 13);

	tipper.cp.inversedNodes = courseplay:isInvertedTrailerNode(vehicle, tipper);

	local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(tipper.cp.frontNode, xTipper,yTipper,zTipper);
	courseplay:debug("\tlxFrontNode: "..tostring(lxFrontNode), 13);
	if math.abs(lxFrontNode) <= 0.001 or tipper.rootNode == tipper.cp.frontNode then
		tipper.cp.isPivot = false;
	else
		tipper.cp.isPivot = true;
	end;
	if tipper.rootNode == tipper.cp.frontNode then
		courseplay:debug('\ttipper.rootNode == tipper.cp.frontNode', 13);
	end;

	courseplay:debug(('\t--> inversedNodes=%s, isPivot=%s, frontNode=%s'):format(tostring(tipper.cp.inversedNodes), tostring(tipper.cp.isPivot), tostring(tipper.cp.frontNode)), 13);
end;

function courseplay:isInvertedTrailerNode(vehicle, tipper)
	local x,y,z = getWorldTranslation(vehicle.rootNode);
	local xTipper,yTipper,zTipper = getWorldTranslation(tipper.rootNode);
	local _,_,tz = worldToLocal(tipper.rootNode, x,y,z);
	return tz < 0;
end;

function courseplay:getRealTrailerDistanceToPivot(vehicle, tipper)
	-- In case it's not set.
	if not tipper.cp.realTurningNode then
		-- Find the real trailer turning point
		tipper.cp.realTurningNode = courseplay:createRealTrailerTurningNode(vehicle, tipper);
	end;

	local invert = courseplay:isInvertedTrailerNode(vehicle, tipper) and -1 or 1;

	if tipper.attacherJoint.rootNode == tipper.rootNode then
		local x,y,z = getWorldTranslation(tipper.attacherJoint.node);
		local _,_,tz = worldToLocal(tipper.cp.realTurningNode, x,y,z);
		return tz*invert;
	else
	    -- Attempt to find the pivot node.
		local node = courseplay:findJointNodeConnectingToNode(tipper, tipper.attacherJoint.rootNode, tipper.rootNode);

		if node then
			local x,y,z = getWorldTranslation(tipper.attacherJoint.node);
			local _,_,tz = worldToLocal(tipper.cp.realTurningNode, x,y,z);
			return tz*invert;
		else
		    return 3*invert;
		end;
	end;
end;

function courseplay:findJointNodeConnectingToNode(tipper, fromNode, toNode)
	-- Attempt to find the jointNode by backtracking the compomentJoints.
	for index, component in ipairs(tipper.components) do
		if component.node == fromNode then
			for _, joint in ipairs(tipper.componentJoints) do
				if joint.componentIndices[2] == index then
					if tipper.components[joint.componentIndices[1]].node == toNode then
						return joint.jointNode;
					else
					    return courseplay:findJointNodeConnectingToNode(tipper, tipper.components[joint.componentIndices[1]].node, toNode);
					end;
				end;
			end;
		end;
	end;

	-- Last attempt to find the jointNode by getting parent of parent (in dept of 3)
	if getParent(getParent(tipper.attacherJoint.rootNode)) == tipper.rootNode
	or getParent(getParent(getParent(tipper.attacherJoint.rootNode))) == tipper.rootNode
	or getParent(getParent(getParent(getParent(tipper.attacherJoint.rootNode)))) == tipper.rootNode
	then
		return tipper.attacherJoint.node;
	end;

	return nil;
end;

function courseplay:createRealTrailerTurningNode(vehicle, tipper)
	if #tipper.wheels > 0 then
		local _,yTrailer,_ = getWorldTranslation(tipper.rootNode);
		local minDis, maxDis = 0, 0;
		local minDisRot, maxDisRot = 0, 0;
		local haveStraitWheels, haveRotatingWheels = false, false;
		local Distance = 0;

		local invert = courseplay:isInvertedTrailerNode(vehicle, tipper) and -1 or 1;

		-- Sort wheels in turning wheels and strait wheels and find the min and max distance for each set.
		for i = 1, #tipper.wheels do
			if tipper.wheels[i].node == tipper.rootNode then
				local x,_,z = getWorldTranslation(tipper.wheels[i].driveNode);
				local _,_,dis = worldToLocal(tipper.rootNode, x, yTrailer, z);
				if tipper.wheels[i].steeringAxleScale == 0 then
					if haveStraitWheels then
						if dis < minDis then minDis = dis; end;
						if dis > maxDis then maxDis = dis; end;
					else
						minDis = dis;
						maxDis = dis;
						haveStraitWheels = true;
					end;
				else
					if haveRotatingWheels then
						if dis < minDisRot then minDisRot = dis; end;
						if dis > maxDisRot then maxDisRot = dis; end;
					else
						minDisRot = dis;
						maxDisRot = dis;
						haveRotatingWheels = true;
					end;
				end;
			end;
		end;

		-- Calculate strait wheel median distance
		if haveStraitWheels then
			if minDis == maxDis then
				Distance = minDis;
			else
			    local dif = minDis - maxDis;
				Distance = minDis + (dif/2);
			end;

		-- Calculate turning wheel median distance if there are no strait wheels.
		elseif haveRotatingWheels then
			if minDisRot == maxDisRot then
				Distance = minDisRot;
			else
				local dif = minDisRot - maxDisRot;
				Distance = minDisRot + (dif/2);
			end;
		end;

		-- If the distance is not 0 then create an transformGroup and place it at the right location and return the node of it.
		if Distance ~= 0 then
			local node = createTransformGroup("realTurningNode");
			link(tipper.rootNode, node);
			setTranslation(node, 0, 0, Distance * invert);
			return node;
		end;
	end;

	-- Return the tipper's rootNode if all the above fails.
	return tipper.rootNode;
end;

function courseplay:createUnloadOrFillNode(vehicle, tipper)
	-- Make sure the realTurningNode is set.
	if not tipper.cp.realTurningNode then
		-- Find the real trailer turning point
		tipper.cp.realTurningNode = courseplay:createRealTrailerTurningNode(vehicle, tipper);
	end;
	local invert = courseplay:isInvertedTrailerNode(vehicle, tipper) and -1 or 1;

	if courseplay:is_baleLoader(tipper) then
		local Distance = (tipper.cp.specialUnloadDistance or -5) * invert;
		local node = createTransformGroup("UnloadOrFillNode");
		link(tipper.cp.realTurningNode, node);
		setTranslation(node, 0, 0, Distance);
		return node;
	elseif courseplay:isSpecialBaleLoader(tipper) then
		if tipper.cp.specialUnloadDistance then
			local Distance = tipper.cp.specialUnloadDistance * invert;
			local node = createTransformGroup("UnloadOrFillNode");
			link(tipper.cp.realTurningNode, node);
			setTranslation(node, 0, 0, Distance);
			return node;
		else
			return clone(tipper.cp.realTurningNode, true);
		end;
	elseif tipper.cp.hasSpecializationFillable and tipper.allowFillFromAir then
		return tipper.exactFillRootNode;
	end;

	-- Return false, so this will only be runned once.
	return false;
end;