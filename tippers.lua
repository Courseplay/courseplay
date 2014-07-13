-- ##### MANAGING TOOLS ##### --

function courseplay:attachImplement(implement)
	--local impl = implement.object;
end;
function courseplay:detachImplement(implementIndex)
	self.cp.toolsDirty = true;
end;

function courseplay:reset_tools(vehicle)
	vehicle.tippers = {}
	-- are there any tippers?
	vehicle.cp.tipperAttached = courseplay:updateWorkTools(vehicle, vehicle);
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
		and not workTool.cp.isCaseIHMagnum340Titanium 
		and not workTool.cp.isCaseIHPuma160Titanium 
		and not workTool.cp.isFendt828VarioFruktor 
		then
			hasWorkTool = true;
			vehicle.tippers[#vehicle.tippers + 1] = workTool;
			courseplay:setMarkers(vehicle, workTool);
			vehicle.cp.noStopOnTurn = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool);
			vehicle.cp.noStopOnEdge = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool);
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

function courseplay:getReverseProperties(vehicle, workTool)
	courseplay:debug(('getReverseProperties(%q, %q)'):format(nameNum(vehicle), nameNum(workTool)), 13);

	-- Make sure they are reset so they wont conflict when changing worktools
	workTool.cp.frontNode		= nil;
	workTool.cp.isPivot			= nil;

	if workTool == vehicle then
		courseplay:debug('\tworkTool is vehicle (steerable) -> return', 13);
		return;
	end;
	if vehicle.cp.hasSpecializationShovel then
		courseplay:debug('\tvehicle has "Shovel" spec -> return', 13);
		return;
	end;
	if workTool.cp.hasSpecializationShovel then
		courseplay:debug('\tworkTool has "Shovel" spec -> return', 13);
		return;
	end;
	if not courseplay:isReverseAbleWheeledWorkTool(workTool) then
		courseplay:debug('\tworkTool doesn\'t need reverse properties -> return', 13);
		return;
	end;

	--------------------------------------------------

	if not workTool.cp.distances then
		workTool.cp.distances = courseplay:getDistances(workTool);
	end;

	workTool.cp.realTurningNode = courseplay:getRealTurningNode(workTool);

	workTool.cp.realUnloadOrFillNode = courseplay:getRealUnloadOrFillNode(workTool);

	if workTool.attacherVehicle == vehicle or workTool.attacherVehicle.cp.isAttacherModule then
		workTool.cp.frontNode = courseplay:getRealTrailerFrontNode(workTool);
	else
		workTool.cp.frontNode = courseplay:getRealDollyFrontNode(workTool.attacherVehicle);
		if workTool.cp.frontNode then
			courseplay:debug(string.format('\tworkTool %q has dolly', nameNum(workTool)), 13);
		else
			courseplay:debug(string.format('\tworkTool %q has invalid dolly -> return', nameNum(workTool)), 13);
			return;
		end;
	end;

	workTool.cp.nodeDistance = courseplay:getRealTrailerDistanceToPivot(workTool);
	courseplay:debug("\ttz: "..tostring(workTool.cp.nodeDistance).."  workTool.cp.realTurningNode: "..tostring(workTool.cp.realTurningNode), 13);

	if workTool.cp.realTurningNode == workTool.cp.frontNode then
		workTool.cp.isPivot = false;
	else
		workTool.cp.isPivot = true;
	end;

	if workTool.cp.realTurningNode == workTool.cp.frontNode then
		courseplay:debug('\tworkTool.cp.realTurningNode == workTool.cp.frontNode', 13);
	end;

	courseplay:debug(('\t--> isPivot=%s, frontNode=%s'):format(tostring(workTool.cp.isPivot), tostring(workTool.cp.frontNode)), 13);
end;

function courseplay:isInvertedTrailerNode(workTool, node)
	-- Use node if set else use the workTool.rootNode
	node = node or workTool.rootNode;

	-- Check if the node is in front of the attacher node
	local xTipper,yTipper,zTipper = getWorldTranslation(node);
	local attacherNode = workTool.attacherJoint.node;
	local rxTemp, ryTemp, rzTemp = getRotation(attacherNode);
	setRotation(attacherNode, 0, 0, 0);
	local _,_,direction = worldToLocal(attacherNode, xTipper,yTipper,zTipper);
	setRotation(attacherNode, rxTemp, ryTemp, rzTemp);
	local isInFront = direction >= 0;

	-- Check if it's reversed based on if it's in front of the attacher node or not
	local x,y,z = getWorldTranslation(attacherNode);
	local _,_,tz = worldToLocal(node, x,y,z);
	return isInFront and (tz > 0) or (tz < 0);
end;

local allowedJointType = {};
function courseplay:isReverseAbleWheeledWorkTool(workTool)
	if #allowedJointType == 0 then
		local jointTypeList = {"implement", "trailer", "trailerLow", "semitrailer"};
		for _,jointType in ipairs(jointTypeList) do
			local index = Vehicle.jointTypeNameToInt[jointType];
			if index then
				table.insert(allowedJointType, index, true);
			end;
		end;
	end;

	if allowedJointType[workTool.attacherJoint.jointType] and workTool.wheels and #workTool.wheels > 0 then
		-- Attempt to find the pivot node.
		local node, _ = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
		if node then
			-- Trailers
			if (workTool.attacherJoint.jointType ~= Vehicle.jointTypeNameToInt["implement"])
			-- Implements with pivot and wheels that do not lift the wheels from the ground.
			or (node ~= workTool.rootNode and workTool.attacherJoint.jointType == Vehicle.jointTypeNameToInt["implement"] and not workTool.attacherJoint.topReferenceNode)
			then
				return true;
			end;
		end;
	end;

	return false;
end;

function courseplay:getRealTrailerDistanceToPivot(workTool)
	-- Attempt to find the pivot node.
	local node, backTrack = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
	if node then
		local x,y,z;
		if node == workTool.rootNode then
			x,y,z = getWorldTranslation(workTool.attacherJoint.node);
		else
			x,y,z = getWorldTranslation(node);
		end;
		local _,_,tz = worldToLocal(courseplay:getRealTurningNode(workTool), x,y,z);
		return tz;
	else
		return 3;
	end;
end;

--- courseplay:findJointNodeConnectingToNode(workTool, fromNode, toNode)
--	Returns: (node, backtrack)
--		node will return either:		1. The jointNode that connects to the toNode,
--										2. The toNode if no jointNode is found but the fromNode is inside the same component as the toNode
--										3. nil in case none of the above fails.
--		backTrack will return either:	1. A table of all the jointNodes found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
function courseplay:findJointNodeConnectingToNode(workTool, fromNode, toNode)
	if fromNode == toNode then return toNode; end;

	-- Attempt to find the jointNode by backtracking the compomentJoints.
	for index, component in ipairs(workTool.components) do
		if component.node == fromNode then
			for _, joint in ipairs(workTool.componentJoints) do
				if joint.componentIndices[2] == index then
					if workTool.components[joint.componentIndices[1]].node == toNode then
						return joint.jointNode, {joint.jointNode};
					else
						local node, backTrack = courseplay:findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[1]].node, toNode);
						if backTrack then table.insert(backTrack, 1, joint.jointNode); end;
					    return node, backTrack;
					end;
				end;
			end;
		end;
	end;

	-- Last attempt to find the jointNode by getting parent of parent untill hit or the there is no more parents.
	local node = fromNode;
	while node ~= 0 and node ~= nil do
		if node == toNode then
			return toNode, nil;
		else
			node = getParent(node);
		end;
	end;

	-- If anything else fails, return nil
	return nil, nil;
end;

function courseplay:createNewLinkedNode(object, nodeName, linkToNode)
	if not object.cp.notesToDelete then object.cp.notesToDelete = {}; end;

	local node = createTransformGroup(nodeName);
	link(linkToNode, node);
	table.insert(object.cp.notesToDelete, node);

	return node;
end;

function courseplay:getRealTurningNode(workTool)
	if not workTool.cp.turningNode then
		local node = courseplay:createNewLinkedNode(workTool, "realTurningNode", workTool.rootNode);

		local Distance = 0;
		local invert = courseplay:isInvertedTrailerNode(workTool) and -1 or 1;
		local steeringAxleScale = 0;

		-- Get the distance from root node to the whells turning point.
		if workTool.wheels and #workTool.wheels > 0 then
			local _,yTrailer,_ = getWorldTranslation(workTool.rootNode);
			local minDis, maxDis = 0, 0;
			local minDisRot, maxDisRot = 0, 0;
			local haveStraitWheels, haveRotatingWheels = false, false;
			local steeringAxleScaleMin, steeringAxleScaleMax = 0, 0;

			-- Sort wheels in turning wheels and strait wheels and find the min and max distance for each set.
			for i = 1, #workTool.wheels do
				if workTool.wheels[i].node == workTool.rootNode and workTool.wheels[i].lateralStiffness > 0 then
					local x,_,z = getWorldTranslation(workTool.wheels[i].driveNode);
					local _,_,dis = worldToLocal(workTool.rootNode, x, yTrailer, z);
					-- TODO: (Claus) Update to check if steering axle update backwards
					dis = dis * invert;
					if workTool.wheels[i].steeringAxleScale == 0 then
						if haveStraitWheels then
							if dis < minDis then minDis = dis; end;
							if dis > maxDis then maxDis = dis; end;
						else
							minDis = dis;
							maxDis = dis;
							haveStraitWheels = true;
						end;
					else
						if workTool.wheels[i].steeringAxleScale < 0 and workTool.wheels[i].steeringAxleScale < steeringAxleScaleMin then
							steeringAxleScaleMin = workTool.wheels[i].steeringAxleScale;
						elseif workTool.wheels[i].steeringAxleScale > 0 and workTool.wheels[i].steeringAxleScale > steeringAxleScaleMax then
							steeringAxleScaleMax = workTool.wheels[i].steeringAxleScale;
						end;
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
					Distance = (minDis + maxDis) * 0.5;
				end;

			-- Calculate turning wheel median distance if there are no strait wheels.
			elseif haveRotatingWheels then
				steeringAxleScale = steeringAxleScaleMin + steeringAxleScaleMax;
				if minDisRot == maxDisRot then
					Distance = minDisRot;
				else
					Distance = (minDisRot + maxDisRot) * 0.5;
				end;
			end;
		end;

		if Distance ~= 0 then
			setTranslation(node, 0, 0, Distance);
		end;
		if courseplay:isInvertedTrailerNode(workTool, node) then
			setRotation(node, 0, math.rad(180), 0);
		end;

		if not haveStraitWheels and workTool.steeringAxleUpdateBackwards and steeringAxleScale < 0 then
			local tempNode, _ = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
			if tempNode then
				local x, y, z;
				if tempNode == workTool.rootNode then
					x, y, z = getWorldTranslation(workTool.attacherJoint.node);
				else
					x, y, z = getWorldTranslation(tempNode);
				end;
				local _,_,dis = worldToLocal(node, x, y, z);
				local offset = (dis * math.abs(steeringAxleScale)) + Distance;
				setTranslation(node, 0, 0, offset);
				workTool.cp.steeringAxleUpdateBackwards = true;
			end;
		end;

		workTool.cp.turningNode = node;
	end;

	return workTool.cp.turningNode;
end;

function courseplay:getRealUnloadOrFillNode(workTool)
	if workTool.cp.unloadOrFillNode == nil then
		-- BALELOADERS
		if courseplay:isBaleLoader(workTool) or (courseplay:isSpecialBaleLoader(workTool) and workTool.cp.specialUnloadDistance) then
			-- Create the new node and link it to realTurningNode
			local node = courseplay:createNewLinkedNode(workTool, "UnloadOrFillNode", courseplay:getRealTurningNode(workTool));

			-- make sure we set the node distance position
			local Distance = workTool.cp.specialUnloadDistance or -5;
			setTranslation(node, 0, 0, Distance);

			workTool.cp.unloadOrFillNode = node;

		-- NORMAL FILLABLE TRAILERS WITH ALLOW TO BE FILLED FROM THE AIR
		elseif workTool.cp.hasSpecializationFillable and workTool.allowFillFromAir then
			-- Create the new node and link it to exactFillRootNode
			local node = courseplay:createNewLinkedNode(workTool, "UnloadOrFillNode", workTool.exactFillRootNode);

			-- Make sure ve set the height position to the same as the realTurningNode
			local x, y, z = getWorldTranslation(courseplay:getRealTurningNode(workTool));
			local _,Height,_ = worldToLocal(workTool.exactFillRootNode, x, y, z);
			setTranslation(node, 0, Height, 0);

			if courseplay:isInvertedTrailerNode(workTool, node) then
				setRotation(node, 0, math.rad(180), 0);
			end;

			workTool.cp.unloadOrFillNode = node;

		-- NONE OF THE ABOVE
		else
			workTool.cp.unloadOrFillNode = false;
		end;
	end;

	return workTool.cp.unloadOrFillNode;
end;

function courseplay:getRealTrailerFrontNode(workTool)
	if not workTool.cp.realFrontNode then
		local jointNode, backtrack = courseplay:findJointNodeConnectingToNode(workTool, workTool.attacherJoint.rootNode, workTool.rootNode);
		if jointNode and backtrack and workTool.attacherJoint.jointType ~= Vehicle.jointTypeNameToInt["implement"] then
			local rootNode;
			for _, joint in ipairs(workTool.componentJoints) do
				if joint.jointNode == jointNode then
					rootNode = workTool.components[joint.componentIndices[2]].node;
					break;
				end;
			end;

			if rootNode then
				local node = courseplay:createNewLinkedNode(workTool, "realFrontNode", rootNode);
				local x, y, z = getWorldTranslation(jointNode);
				local _,_,delta = worldToLocal(rootNode, x, y, z);

				setTranslation(node, 0, 0, delta);

				if courseplay:isInvertedTrailerNode(workTool, node) then
					setRotation(node, 0, math.rad(180), 0);
				end;

				workTool.cp.realFrontNode = node;
			end;
		else
			workTool.cp.realFrontNode = courseplay:getRealTurningNode(workTool);
		end;
	end;

	return workTool.cp.realFrontNode
end;

function courseplay:getRealDollyFrontNode(dolly)
	if dolly.cp.realDollyFrontNode == nil then
		local node, _ = courseplay:findJointNodeConnectingToNode(dolly, dolly.attacherJoint.rootNode, dolly.rootNode);
		if node then
			-- Trailers without pivote
			if (node == dolly.rootNode and dolly.attacherJoint.jointType ~= Vehicle.jointTypeNameToInt["implement"])
			-- Implements with pivot and wheels that do not lift the wheels from the ground.
			or (node ~= dolly.rootNode and dolly.attacherJoint.jointType == Vehicle.jointTypeNameToInt["implement"] and not dolly.attacherJoint.topReferenceNode) then
				dolly.cp.realDollyFrontNode = courseplay:getRealTurningNode(dolly);
			else
				dolly.cp.realDollyFrontNode = false;
			end;
		end;
	end;

	return dolly.cp.realDollyFrontNode
end;

function courseplay:getTotalLengthOnWheels(vehicle)
	courseplay:debug(('%s: getTotalLengthOnWheels()'):format(nameNum(vehicle)), 6);
	local totalLength = 0;
	local directionNodeToFrontWheelOffset;

	if not vehicle.cp.distances then
		vehicle.cp.distances = courseplay:getDistances(vehicle);
	end;

	-- STEERABLES
	if vehicle.cp.hasSpecializationSteerable then
		directionNodeToFrontWheelOffset = vehicle.cp.distances.frontWheelToDirectionNodeOffset;

		local _, y, _ = getWorldTranslation(vehicle.rootNode);

		local hasRearAttach = false;
		local jointType = 0;

		for _, implement in ipairs(vehicle.attachedImplements) do
			local xi, _, zi = getWorldTranslation(implement.object.attacherJoint.node);
			local _,_,delta = worldToLocal(vehicle.rootNode, xi, y, zi);

			-- Check if it's rear attached
			if delta < 0 then
				hasRearAttach = true;
				local length, _ = courseplay:getTotalLengthOnWheels(implement.object);
				if length > 0 then
					jointType = implement.object.attacherJoint.jointType;
					totalLength = length;
				end;
			end;
		end;

		if hasRearAttach and totalLength > 0 and jointType > 0 then
			local length = vehicle.cp.distances.frontWheelToRearTrailerAttacherJoints[jointType];
			if length then
				totalLength = totalLength + length;
			else
				totalLength = 0;
				directionNodeToFrontWheelOffset = 0;
			end;
			courseplay:debug(('%s: hasRearAttach: totalLength=%.2f'):format(nameNum(vehicle), totalLength), 6);
		else
			totalLength = vehicle.cp.distances.frontWheelToRearWheel;
			courseplay:debug(('%s: Using frontWheelToRearWheel=%.2f'):format(nameNum(vehicle), totalLength), 6);
		end;

		cpPrintLine(6);
		courseplay:debug(('%s: totalLength=%.2f, totalLengthOffset=%.2f'):format(nameNum(vehicle), totalLength, directionNodeToFrontWheelOffset), 6);
		cpPrintLine(6);

	-- IMPLEMENTS OR TRAILERS
	else
	    local _, y, _ = getWorldTranslation(vehicle.attacherJoint.node);

		local hasRearAttach = false;
		local jointType = 0;

		for _, implement in ipairs(vehicle.attachedImplements) do
			local xi, _, zi = getWorldTranslation(implement.object.attacherJoint.node);
			local delta,_,_ = worldToLocal(vehicle.attacherJoint.node, xi, y, zi);

			-- Check if it's rear attached
			if delta > 0 then
				hasRearAttach = true;
				local length, _ = courseplay:getTotalLengthOnWheels(implement.object);
				if length > 0 then
					jointType = implement.object.attacherJoint.jointType;
					totalLength = length;
				end;
			end;
		end;

		if hasRearAttach and totalLength > 0 and jointType > 0 and vehicle.cp.distances.attacherJointToRearTrailerAttacherJoints then
			local length = vehicle.cp.distances.attacherJointToRearTrailerAttacherJoints[jointType];
			if length then
				totalLength = totalLength + length;
			else
				totalLength = 0;
			end;
			courseplay:debug(('%s: hasRearAttach: totalLength=%.2f'):format(nameNum(vehicle), totalLength), 6);
		elseif vehicle.cp.distances.attacherJointToRearWheel then
			totalLength = vehicle.cp.distances.attacherJointToRearWheel;
			courseplay:debug(('%s: Using attacherJointToRearWheel=%.2f'):format(nameNum(vehicle), totalLength), 6);
		else
			totalLength = 0;
			courseplay:debug(('%s: No length found, returning 0'):format(nameNum(vehicle)), 6);
		end;
	end;

	return totalLength, directionNodeToFrontWheelOffset;
end;

function courseplay:getDistances(object)
	cpPrintLine(6);
	local distances = {};

	-- STEERABLES
	if object.cp.DirectionNode then
		-- Finde the front and rear distance from the direction node
		local front, rear = 0, 0;
		local haveRunnedOnce = false
		for _, wheel in ipairs(object.wheels) do
			local wdnrxTemp, wdnryTemp, wdnrzTemp = getRotation(wheel.driveNode);
			setRotation(wheel.driveNode, 0, 0, 0);
			local wreprxTemp, wrepryTemp, wreprzTemp = getRotation(wheel.repr);
			setRotation(wheel.repr, 0, 0, 0);
			local xw, yw, zw = getWorldTranslation(wheel.driveNode);
			local _,_,dis = worldToLocal(object.cp.DirectionNode, xw, yw, zw);
			setRotation(wheel.repr, wreprxTemp, wrepryTemp, wreprzTemp);
			setRotation(wheel.driveNode, wdnrxTemp, wdnryTemp, wdnrzTemp);
			if haveRunnedOnce then
				if dis < rear then rear = dis; end;
				if dis > front then front = dis; end;
			else
				rear = dis;
				front = dis;
				haveRunnedOnce = true;
			end;
		end;
		-- Set the wheel offset anddistance
		distances.frontWheelToDirectionNodeOffset = front * -1;
		distances.frontWheelToRearWheel = math.abs(front - rear);
		courseplay:debug(('%s: frontWheelToDirectionNodeOffset=%.2f, frontWheelToRearWheel=%.2f'):format(nameNum(object), distances.frontWheelToDirectionNodeOffset, distances.frontWheelToRearWheel), 6);

		-- Finde the attacherJoints distance from the direction node
		for _, attacherJoint in ipairs(object.attacherJoints) do
			local xj, yj, zj = getWorldTranslation(attacherJoint.jointTransform);
			local _,_,dis = worldToLocal(object.cp.DirectionNode, xj, yj, zj);
			if dis < front then
				if not distances.frontWheelToRearTrailerAttacherJoints then
					distances.frontWheelToRearTrailerAttacherJoints = {};
				end;
				distances.frontWheelToRearTrailerAttacherJoints[attacherJoint.jointType] = math.abs(front - dis);
				courseplay:debug(('%s: frontWheelToRearTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.frontWheelToRearTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;
		end

	-- IMPLEMENTS OR TRAILERS
	else
		local node = object.attacherJoint.node;
		if object.attacherJoint.rootNode ~= object.rootNode then
			local tempNode, backTrack = courseplay:findJointNodeConnectingToNode(object, object.attacherJoint.rootNode, object.rootNode);
			if tempNode and backTrack then
				node = tempNode;
				local tnx, tny, tnz = getWorldTranslation(tempNode);
				local xdis,ydis,dis = worldToLocal(object.attacherJoint.node, tnx, tny, tnz);
				local nodeLength = 0;
				for i = 1, #backTrack do
					local btx, bty, btz = getWorldTranslation(backTrack[i]);
					if i == 1 then
						tempNode = object.attacherJoint.node;
					else
						tempNode = backTrack[i-1];
					end;

					-- Save the rotations of the tempNode
					local tnrxTemp, tnryTemp, tnrzTemp = getRotation(tempNode);
					-- Reset all the rotation to 0 for tempNode, to be sure we get valid data.
					setRotation(tempNode, 0, 0, 0);
					-- Get the distance from tempNode to the current backTrack node
					local _,_,dis = worldToLocal(tempNode, btx, bty, btz);
					-- Restore the tempNode rotations.
					setRotation(tempNode, tnrxTemp, tnryTemp, tnrzTemp);
					courseplay:debug(('%s: backTrack[%d](node: %s) Length = %.2f'):format(nameNum(object), i, tostring(backTrack[i]), math.abs(dis)), 6);
					nodeLength = nodeLength + math.abs(dis);
				end;

				distances.attacherJointToPivot = nodeLength
				courseplay:debug(('%s: attacherJointToPivot=%.2f'):format(nameNum(object), distances.attacherJointToPivot), 6);
			end;
		end;

		local nx, ny, nz = getWorldTranslation(node);
		-- Find the distance from attacherJoint to rear wheel
		if object.wheels and #object.wheels > 0 then
			local length = 0;
			for _, wheel in ipairs(object.wheels) do
				local wdnrxTemp, wdnryTemp, wdnrzTemp = getRotation(wheel.driveNode);
				setRotation(wheel.driveNode, 0, 0, 0);
				local wreprxTemp, wrepryTemp, wreprzTemp = getRotation(wheel.repr);
				setRotation(wheel.repr, 0, 0, 0);
				local _,_,dis = worldToLocal(wheel.driveNode, nx, ny, nz);
				setRotation(wheel.repr, wreprxTemp, wrepryTemp, wreprzTemp);
				setRotation(wheel.driveNode, wdnrxTemp, wdnryTemp, wdnrzTemp);

				if math.abs(dis) > length then
					length = math.abs(dis);
				end;
			end;

			if distances.attacherJointToPivot then
				distances.pivotToRearWheel = length;
				distances.attacherJointToRearWheel = distances.attacherJointToPivot + length;
			else
				distances.attacherJointToRearWheel = length;
			end;

			courseplay:debug(('%s: attacherJointToRearWheel=%.2f'):format(nameNum(object), distances.attacherJointToRearWheel), 6);
		end;

		-- Finde the attacherJoints distance from the direction node
		for _, attacherJoint in ipairs(object.attacherJoints) do
			local jtfxTemp, jtfyTemp, jtfzTemp = getRotation(attacherJoint.jointTransform);
			setRotation(attacherJoint.jointTransform, 0, 0, 0);
			local _,_,dis = worldToLocal(attacherJoint.jointTransform, nx, ny, nz);

			setRotation(attacherJoint.jointTransform, jtfxTemp, jtfyTemp, jtfzTemp);
			if dis > 0 then
				if not distances.attacherJointToRearTrailerAttacherJoints then
					distances.attacherJointToRearTrailerAttacherJoints = {};
				end;

				if distances.attacherJointToPivot then
					if not distances.pivotToRearTrailerAttacherJoints then
						distances.pivotToRearTrailerAttacherJoints = {};
					end;
					distances.pivotToRearTrailerAttacherJoints[attacherJoint.jointType] = math.abs(dis);
					distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType] = distances.attacherJointToPivot + math.abs(dis);
				else
					distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType] = math.abs(dis);
				end;

				courseplay:debug(('%s: attacherJointToRearTrailerAttacherJoints[%d]=%.2f'):format(nameNum(object), attacherJoint.jointType, distances.attacherJointToRearTrailerAttacherJoints[attacherJoint.jointType]), 6);
			end;
		end;
	end;

	return distances;
end;


-- ##################################################


-- ##### LOADING TOOLS ##### --
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
			elseif vehicle.cp.isLoaded then
				currentTrailer.currentSuperSiloTrigger:setIsFilling(false);
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
		courseplay:setIsLoaded(vehicle, true);
		vehicle.cp.lastTrailerToFillDistance = nil;
		vehicle.cp.currentTrailerToFill = nil;
		return true;
	end;

	if vehicle.cp.lastTrailerToFillDistance == nil then
		-- drive on if current tipper is full
		if currentTrailer.fillLevel == currentTrailer.capacity then
			if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
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
				if vehicle.cp.numWorkTools > vehicle.cp.currentTrailerToFill then
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


-- ##################################################


-- ##### UNLOADING TOOLS ##### --
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
			local distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper);
			local trailerInTipRange = g_currentMission:getIsTrailerInTipRange(tipper, ctt, bestTipReferencePoint);
			courseplay:debug(('%s: distanceToTrigger=%s, bestTipReferencePoint=%s -> trailerInTipRange=%s'):format(nameNum(vehicle), tostring(distanceToTrigger), tostring(bestTipReferencePoint), tostring(trailerInTipRange)), 2);
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
	vehicle.cp.isReverseBGATipping = nil; -- Used for reverse BGA tipping
	vehicle.cp.BGASelectedSection = nil; -- Used for reverse BGA tipping
	vehicle.cp.inversedRearTipNode = nil; -- Used for reverse BGA tipping
	if vehicle.cp.backupUnloadSpeed then
		courseplay:changeUnloadSpeed(vehicle, nil, vehicle.cp.backupUnloadSpeed, true);
		vehicle.cp.backupUnloadSpeed = nil;
	end;
	if changeToForward and vehicle.Waypoints[vehicle.recordnumber].rev then
		vehicle.recordnumber = courseplay:getNextFwdPoint(vehicle);
	end;
end;

