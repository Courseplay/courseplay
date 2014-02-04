function courseplay:attachImplement(implement)
	--local impl = implement.object;
end;
function courseplay:detachImplement(implementIndex)
	self.cp.toolsDirty = true;
end;

function courseplay:reset_tools(self)
	self.tippers = {}
	-- are there any tippers?
	self.cp.tipperAttached = courseplay:update_tools(self, self)
	self.cp.currentTrailerToFill = nil
	self.cp.lastTrailerToFillDistance = nil
	self.cp.toolsDirty = false;
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
	return workTool.typeName == "wheelLoader" or (workTool.cp.hasSpecializationSteerable and workTool.cp.hasSpecializationShovel and workTool.cp.hasSpecializationBunkerSiloCompacter);
end;

-- update implements to find attached tippers
function courseplay:update_tools(self, tractor_or_implement)
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
		if self.cp.mode == 1 or self.cp.mode == 2 then
			-- if object.cp.hasSpecializationTrailer then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.cp.mode == 3 then -- Overlader
			if object.cp.hasSpecializationTrailer then --to do
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.cp.mode == 4 then -- Fertilizer
			if courseplay:isSprayer(object) or courseplay:is_sowingMachine(object) then
				tipper_attached = true
				table.insert(self.tippers, object)
				courseplay:setMarkers(self, object)
				self.cp.noStopOnEdge = courseplay:isSprayer(object);
				self.cp.noStopOnTurn = courseplay:isSprayer(object);
				if courseplay:is_sowingMachine(object) then
					self.cp.hasSowingMachine = true;
				end;
			end
		elseif self.cp.mode == 6 then -- Baler, foragewagon, baleloader
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
			then
				tipper_attached = true;
				table.insert(self.tippers, object);
				courseplay:setMarkers(self, object);
				self.cp.noStopOnTurn = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object) or courseplay:isMower(object);
				self.cp.noStopOnEdge = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object);
				if object.cp.hasSpecializationPlough then 
					self.cp.hasPlough = true;
				end;
			end
		elseif self.cp.mode == 8 then -- Liquid manure transfer
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(self.tippers, object)
			-- end
		elseif self.cp.mode == 9 then --Fill and empty shovel
			if courseplay:isWheelloader(tractor_or_implement) 
			or tractor_or_implement.typeName == "frontloader" 
			or courseplay:isMixer(tractor_or_implement) then
				tipper_attached = true;
				table.insert(self.tippers, object);
				object.cp.shovelState = 1
			end;
		end
	end

	--FOLDING PARTS: isFolded/isUnfolded states
	courseplay:setFoldedStates(tractor_or_implement);


	if not self.cp.hasUBT then
		self.cp.hasUBT = false;
	end;
	-- go through all implements
	self.cp.aiBackMarker = nil

	for k, implement in pairs(tractor_or_implement.attachedImplements) do
		local object = implement.object

		courseplay:setNameVariable(object);

		--FRONT or BACK?
		local implX,implY,implZ = getWorldTranslation(object.rootNode);
		local _,_,tractorToImplZ = worldToLocal(self.rootNode, implX,implY,implZ);
		object.cp.positionAtTractor = Utils.sign(tractorToImplZ);
		courseplay:debug(string.format("%s: tractorToImplZ=%.4f, positionAtTractor=%d", nameNum(object), tractorToImplZ, object.cp.positionAtTractor), 6);

		--ADD TO self.tippers
		if self.cp.mode == 1 or self.cp.mode == 2 then
			--	if object.cp.hasSpecializationTrailer then
			if object.allowTipDischarge then
				tipper_attached = true
				table.insert(self.tippers, object)
				courseplay:getReverseProperties(self, object)
			end
			
		elseif self.cp.mode == 3 then -- Overlader
			if object.cp.hasSpecializationTrailer and object.cp.isAugerWagon then --to do 
				tipper_attached = true
				table.insert(self.tippers, object)
			end
		elseif self.cp.mode == 4 then -- Fertilizer and Seeding
			if courseplay:isSprayer(object) or courseplay:is_sowingMachine(object) then
				tipper_attached = true
				table.insert(self.tippers, object)
				courseplay:setMarkers(self, object)
				self.cp.noStopOnEdge = courseplay:isSprayer(object);
				self.cp.noStopOnTurn = courseplay:isSprayer(object);
				self.cp.hasMachinetoFill = true
				if courseplay:is_sowingMachine(object) then
					self.cp.hasSowingMachine = true;
				end;
			end
		elseif self.cp.mode == 5 then -- Transfer
			if object.setPlane ~= nil then --open/close cover
				tipper_attached = true;
				table.insert(self.tippers, object);
			end;
		elseif self.cp.mode == 6 then -- Baler, foragewagon, baleloader
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
				table.insert(self.tippers, object)
				courseplay:setMarkers(self, object)
				self.cp.noStopOnTurn = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object);
				self.cp.noStopOnEdge = courseplay:isBaler(object) or courseplay:is_baleLoader(object) or courseplay:isSpecialBaleLoader(object);
				if object.cp.hasSpecializationPlough then 
					self.cp.hasPlough = true;
				end;
			end;
			if courseplay:is_baleLoader(object) then
				self.cp.hasBaleLoader = true;
				courseplay:getReverseProperties(self, object)
			end;
			if object.allowTipDischarge then
				courseplay:getReverseProperties(self, object)
			end
		elseif self.cp.mode == 8 then --Liquid manure transfer
			--if SpecializationUtil.hasSpecialization(RefillTrigger, object.specializations) then
			tipper_attached = true
			table.insert(self.tippers, object)
			--		end
		elseif self.cp.mode == 9 then --Fill and empty shovel
			if courseplay:isFrontloader(object) or object.cp.hasSpecializationShovel then 
				tipper_attached = true;
				table.insert(self.tippers, object);
				object.attacherVehicle.cp.shovelState = 1
			end
		end;

		if object.aiLeftMarker ~= nil and object.aiForceTurnNoBackward == true then 
			self.cp.aiTurnNoBackward = true
			courseplay:debug(string.format("%s: object.aiLeftMarker ~= nil and object.aiForceTurnNoBackward == true --> self.cp.aiTurnNoBackward = true", nameNum(object)), 6);
		elseif object.aiLeftMarker == nil and table.getn(object.wheels) > 0 and object.cp.positionAtTractor <= 0 then
			self.cp.aiTurnNoBackward = true
			courseplay:debug(string.format("%s: object.aiLeftMarker == nil and table.getn(object.wheels) > 0 and object.cp.positionAtTractor <= 0 --> self.cp.aiTurnNoBackward = true", nameNum(object)), 6);
		end

		courseplay:askForSpecialSettings(self,object)

		--FOLDING PARTS: isFolded/isUnfolded states
		courseplay:setFoldedStates(object);

		-- are there more tippers attached to the current implement?
		local other_tipper_attached
		if table.getn(object.attachedImplements) ~= 0 then
			other_tipper_attached = courseplay:update_tools(self, object)
		end
		if other_tipper_attached == true then
			tipper_attached = true
		end
		
		courseplay:debug(string.format("%s: courseplay:update_tools()", nameNum(self)), 6);

		courseplay:debug(nameNum(self) .. ": adding " .. tostring(object.name) .. " to cpTrafficCollisionIgnoreList", 3)
		self.cpTrafficCollisionIgnoreList[object.rootNode] = true;
	end; --END for implement in attachedImplements
	
	for k,v in pairs(self.components) do
		self.cpTrafficCollisionIgnoreList[v.node] = true;
	end;


	--MINHUDPAGE for attached combines
	self.cp.attachedCombineIdx = nil;
	if not (self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader) then
		for i=1,table.getn(self.tippers) do
			if courseplay:isAttachedCombine(self.tippers[i]) then
				self.cp.attachedCombineIdx = i;
				break;
			end;
		end;
	end;
	if self.cp.attachedCombineIdx ~= nil then
		--courseplay:debug(string.format("setMinHudPage(self, self.tippers[%d])", self.cp.attachedCombineIdx), 12);
		courseplay:setMinHudPage(self, self.tippers[self.cp.attachedCombineIdx]);
	end;

	--CUTTERS
	if self.attachedCutters ~= nil and table.getn(self.attachedImplements) ~= 0 then
		if self.numAttachedCutters ~= nil and self.numAttachedCutters > 0 then
			for cutter, implement in pairs(self.attachedCutters) do
				local object = implement.object
				if object ~= nil and object.cp == nil then
					object.cp = {};
				end;

				if self.cp.mode == 6 then
					tipper_attached = true;
					table.insert(self.tippers, object);
					courseplay:setMarkers(self, object)
					self.cpTrafficCollisionIgnoreList[object.rootNode] = true;
					for k,v in pairs(object.components) do
						self.cpTrafficCollisionIgnoreList[v.node] = true;
					end;
				end;
			end;
		end;
	end;
	
	if courseplay.debugChannels[3] then
		courseplay:debug(string.format("%s cpTrafficCollisionIgnoreList", nameNum(self)), 3);
		for a,b in pairs(self.cpTrafficCollisionIgnoreList) do
			local name = g_currentMission.nodeToVehicle[a].name
			courseplay:debug(string.format("\\___ %s = %s", tostring(a), tostring(name)), 3);
		end;
	end

	courseplay:getAutoTurnradius(self, tipper_attached);
	
	--tipreferencepoints 
	self.cp.tipRefOffset = nil;
	for i=1, #(self.tippers) do
		if tipper_attached and self.tippers[i].rootNode ~= nil and self.tippers[i].tipReferencePoints ~= nil then
			local tipperX, tipperY, tipperZ = getWorldTranslation(self.tippers[i].rootNode);
			if tipper_attached and table.getn(self.tippers[i].tipReferencePoints) > 1 then
				for n=1 ,table.getn(self.tippers[i].tipReferencePoints) do
					local tipRefPointX, tipRefPointY, tipRefPointZ = worldToLocal(self.tippers[i].tipReferencePoints[n].node, tipperX, tipperY, tipperZ);
					tipRefPointX = math.abs(tipRefPointX);
					if tipRefPointX > 0.1 then
						self.cp.tipRefOffset = tipRefPointX;
						break;
					else
						self.cp.tipRefOffset = 0
					end;
				end;
			else 
				self.cp.tipRefOffset = 0;
			end;
		elseif self.cp.hasMachinetoFill then
			self.cp.tipRefOffset = 1.5
		end;
		if self.cp.tipRefOffset ~= nil then
			break
		end		
	end

	--tippers with covers
	self.cp.tipperHasCover = false;
	self.cp.tippersWithCovers = nil;
	self.cp.tippersWithCovers = {};
	if tipper_attached then
		for i=1, #(self.tippers) do
			local t = self.tippers[i];
			local coverItems = {};
			local isHKD302, isMUK, isSRB35 = false, false, false;
			
			if t.configFileName ~= nil then
				isHKD302 = t.configFileName == "data/vehicles/trailers/kroeger/HKD302.xml";
				isMUK = t.configFileName == "data/vehicles/trailers/kroeger/MUK303.xml" or t.configFileName == "data/vehicles/trailers/kroeger/MUK402.xml";
				isSRB35 = t.configFileName == "data/vehicles/trailers/kroeger/SRB35.xml";
			end;

			if isHKD302 or isMUK or isSRB35 then
				if isHKD302 then
					local c = getChild(t.rootNode, "bodyLeft");
					
					if c ~= nil and c ~= 0 then
						c = getChild(c, "bodyRight");
					end;
					if c ~= nil and c ~= 0 then
						c = getChild(c, "body");
					end;
					if c ~= nil and c ~= 0 then
						c = getChild(c, "plasticPlane");
					end;
					
					if c ~= nil and c ~= 0 then
						self.cp.tipperHasCover = true;
						table.insert(coverItems, c);
					end;
				elseif isMUK then
					local c = getChild(t.rootNode, "tank");
					
					if c ~= nil and c ~= 0 then
						c1 = getChild(c, "planeFlapLeft");
						c2 = getChild(c, "planeFlapRight");
					end;
					if c1 ~= nil and c1 ~= 0 and c2 ~= nil and c2 ~= 0  then
						self.cp.tipperHasCover = true;
						
						table.insert(coverItems, c1);
						table.insert(coverItems, c2);
					end;
				elseif isSRB35 then
					local c = getChild(t.rootNode, "plasticPlane");
					if c ~= nil and c ~= 0 then
						self.cp.tipperHasCover = true;
						
						table.insert(coverItems, c);
					end;
				end;
				
				if self.cp.tipperHasCover and #(coverItems) > 0 then
					courseplay:debug(string.format("Implement %q has a cover (coverItems ~= nil)", tostring(t.name)), 6);
					local data = {
						coverType = "defaultGiants",
						tipperIndex = i,
						coverItems = coverItems
					};
					table.insert(self.cp.tippersWithCovers, data);
				end;

			elseif t.setPlane ~= nil and type(t.setPlane) == "function" and t.currentPlaneId == nil and t.currentPlaneSetId == nil then
				--NOTE: setPlane is both in SMK and in chaffCover.lua -> check for currentPlaneId, currentPlaneSetId (chaffCover) nil
				
				courseplay:debug(string.format("Implement %q has a cover (setPlane ~= nil)", tostring(t.name)), 6);
				self.cp.tipperHasCover = true;
				local data = {
					coverType = "setPlane",
					tipperIndex = i,
					showCoverWhenTipping = Utils.endsWith(t.configFileName, 'SMK34.xml')
				};
				table.insert(self.cp.tippersWithCovers, data);
			
			elseif t.planeOpen ~= nil and t.animationParts[3] ~= nil and t.animationParts[3].offSet ~= nil and t.animationParts[3].animDuration ~= nil then
				courseplay:debug(string.format("Implement %q has a cover (planeOpen ~= nil)", tostring(t.name)), 6);
				self.cp.tipperHasCover = true;
				local data = {
					coverType = "planeOpen",
					tipperIndex = i
				};
				table.insert(self.cp.tippersWithCovers, data);
			
			elseif t.setCoverState ~= nil and type(t.setCoverState) == "function" and t.cover ~= nil and t.cover.opened ~= nil and t.cover.closed ~= nil and t.cover.state ~= nil then
				courseplay:debug(string.format("Implement %q has a cover (setCoverState ~= nil)", tostring(t.name)), 6);
				self.cp.tipperHasCover = true;
				local data = {
					coverType = "setCoverState",
					tipperIndex = i
				};
				table.insert(self.cp.tippersWithCovers, data);

			elseif t.setSheet ~= nil and t.sheet ~= nil and t.sheet.isActive ~= nil then
				courseplay:debug(string.format("Implement %q has a cover (setSheet ~= nil)", tostring(t.name)), 6);
				self.cp.tipperHasCover = true;
				local data = {
					coverType = "setSheet",
					tipperIndex = i
				};
				table.insert(self.cp.tippersWithCovers, data);

			end;
		end;
	end;
	--courseplay:debug(tableShow(self.cp.tippersWithCovers, tostring(self.name) .. ": self.cp.tippersWithCovers", 6), 6);
	--END tippers with covers


	if tipper_attached then
		return true
	end
	return nil
end

function courseplay:setMarkers(self, object)
	object.cp.backMarkerOffset = nil
	object.cp.aiFrontMarker = nil
	-- get the behindest and the frontest  points :-) ( as offset to root node)
	local area = object.cuttingAreas
	if courseplay:isBigM(object) then
		area = object.mowerCutAreas
	elseif object.typeName == "defoliator_animated" then
		area = object.fruitPreparerAreas
	end

	local tableLength = table.getn(area)
	if tableLength == 0 then
		return
	end
	for k = 1, tableLength do
		for j,node in pairs(area[k]) do
			if j == "start" or j == "height" or j == "width" then 
				local x, y, z = getWorldTranslation(node)
				_, _, ztt = worldToLocal(self.rootNode, x, y, z)
				if object.cp.backMarkerOffset == nil or ztt > object.cp.backMarkerOffset then
					object.cp.backMarkerOffset = ztt
				end
				if object.cp.aiFrontMarker == nil  or ztt < object.cp.aiFrontMarker then
					object.cp.aiFrontMarker = ztt
				end
			end
		end
	end

	if self.cp.backMarkerOffset == nil or object.cp.backMarkerOffset < self.cp.backMarkerOffset then
		self.cp.backMarkerOffset = object.cp.backMarkerOffset
	end

	if object.isFuchsFass then
		local x,y,z = 0,0,0;
		local valveOffsetFromRootNode = 0;
		local caOffsetFromValve = -1.5; --4.5;

		if object.distributerIsAttached then
			x,y,z = getWorldTranslation(object.attachedImplements[1].object.rootNode);
		else
			x,y,z = getWorldTranslation(object.rootNode);
			valveOffsetFromRootNode = 3.5;
		end;

		local _, _, distToFuchs = worldToLocal(self.rootNode, x, y, z);
		self.cp.backMarkerOffset = distToFuchs + valveOffsetFromRootNode + caOffsetFromValve;
		object.cp.aiFrontMarker = self.cp.backMarkerOffset - 2.5;
		self.cp.aiFrontMarker = object.cp.aiFrontMarker;
	end;

	if self.cp.aiFrontMarker == nil or object.cp.aiFrontMarker > self.cp.aiFrontMarker then
		self.cp.aiFrontMarker = object.cp.aiFrontMarker
	end

	if self.cp.aiFrontMarker < -7 then
		self.aiToolExtraTargetMoveBack = math.abs(self.cp.aiFrontMarker)
	end
	courseplay:debug(nameNum(self) .. " self.turnEndBackDistance: "..tostring(self.turnEndBackDistance).."  self.aiToolExtraTargetMoveBack: "..tostring(self.aiToolExtraTargetMoveBack),6); 
	courseplay:debug(nameNum(self) .. " setMarkers(): self.cp.backMarkerOffset: "..tostring(self.cp.backMarkerOffset).."  self.cp.aiFrontMarker: "..tostring(self.cp.aiFrontMarker), 6);
end;

function courseplay:setFoldedStates(object)
	if courseplay:isFoldable(object) and object.turnOnFoldDirection then
		if courseplay.debugChannels[17] then print(string.rep('-', 50)); end;
		courseplay:debug(nameNum(object) .. ': setFoldedStates()', 17);

		object.cp.realUnfoldDirection = object.turnOnFoldDirection;
		if object.cp.foldingPartsStartMoveDirection and object.cp.foldingPartsStartMoveDirection ~= 0 then
			object.cp.realUnfoldDirection = object.turnOnFoldDirection * object.cp.foldingPartsStartMoveDirection;
		end;
		if object.cp.isMRpoettingerEurocat315H then --TODO: somehow move to specialTools
			object.cp.realUnfoldDirection = -1;
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

-- loads all tippers
function courseplay:load_tippers(self)
	local allowedToDrive = false
	local cx, cz = self.Waypoints[2].cx, self.Waypoints[2].cz
	local tipper_fill_level, tipper_capacity = self:getAttachedTrailersFillLevelAndCapacity()
	if tipper_fill_level == nil then tipper_fill_level = 0 end
	if tipper_capacity == nil then tipper_capacity = 0 end
	local fill_level = 0
	if tipper_capacity ~= 0 then
		fill_level = tipper_fill_level * 100 / tipper_capacity
	end

	if self.cp.currentTrailerToFill == nil then
		self.cp.currentTrailerToFill = 1
	end

	-- drive on when required fill level is reached
	local drive_on = false
	if self.cp.timeOut < self.timer or self.cp.prevFillLevel == nil then
		if self.cp.prevFillLevel ~= nil and fill_level == self.cp.prevFillLevel and fill_level > self.cp.driveOnAtFillLevel then
			drive_on = true
		end
		self.cp.prevFillLevel = fill_level
		courseplay:set_timeout(self, 7000)
	end

	if fill_level == 100 or drive_on then
		self.cp.prevFillLevel = nil
		self.cp.isLoaded = true
		self.cp.lastTrailerToFillDistance = nil
		self.cp.currentTrailerToFill = nil
		return true
	end

	if self.cp.lastTrailerToFillDistance == nil then

		local current_tipper = self.tippers[self.cp.currentTrailerToFill]

		-- drive on if current tipper is full
		if current_tipper.fillLevel == current_tipper.capacity then
			if table.getn(self.tippers) > self.cp.currentTrailerToFill then
				local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.cp.currentTrailerToFill].rootNode)

				self.cp.lastTrailerToFillDistance = courseplay:distance(cx, cz, tipper_x, tipper_z)

				self.cp.currentTrailerToFill = self.cp.currentTrailerToFill + 1
			else
				self.cp.currentTrailerToFill = nil
				self.cp.lastTrailerToFillDistance = nil
			end
			allowedToDrive = true
		end

	else
		local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.cp.currentTrailerToFill].rootNode)

		local distance = courseplay:distance(cx, cz, tipper_x, tipper_z)

		if distance > self.cp.lastTrailerToFillDistance and self.cp.lastTrailerToFillDistance ~= nil then
			allowedToDrive = true
		else
			allowedToDrive = false
			local current_tipper = self.tippers[self.cp.currentTrailerToFill]
			if current_tipper.fillLevel == current_tipper.capacity then
				if table.getn(self.tippers) > self.cp.currentTrailerToFill then
					local tipper_x, tipper_y, tipper_z = getWorldTranslation(self.tippers[self.cp.currentTrailerToFill].rootNode)
					self.cp.lastTrailerToFillDistance = courseplay:distance(cx, cz, tipper_x, tipper_z)
					self.cp.currentTrailerToFill = self.cp.currentTrailerToFill + 1
				else
					self.cp.currentTrailerToFill = nil
					self.cp.lastTrailerToFillDistance = nil
				end
			end
		end
	end

	-- normal mode if all tippers are empty
	return allowedToDrive
end

-- unloads all tippers
function courseplay:unload_tippers(self)
	local allowedToDrive = true;
	local ctt = self.cp.currentTipTrigger;
	if ctt.getTipDistanceFromTrailer == nil then
		courseplay:debug(nameNum(self) .. ": getTipDistanceFromTrailer function doesn't exist for currentTipTrigger - unloading function aborted", 2);
		return allowedToDrive;
	end;
	local tipperFillLevel, tipperCapacity = self:getAttachedTrailersFillLevelAndCapacity();
	local isBGA = ctt.bunkerSilo ~= nil;
	local bgaIsFull = isBGA and (ctt.bunkerSilo.fillLevel >= ctt.bunkerSilo.capacity);
	local bgaSectionPositions = {
		{ from =  0, to =   40 },
		{ from = 30, to =   70 },
		{ from = 60, to = 1000 }
	};

	for k, tipper in pairs(self.tippers) do
		if tipper.tipReferencePoints ~= nil then
			local fruitType = tipper.currentFillType
			local positionInSilo = -1;
			local distanceToTrigger, bestTipReferencePoint = ctt:getTipDistanceFromTrailer(tipper);
			local trailerInTipRange = g_currentMission:getIsTrailerInTipRange(tipper, ctt, bestTipReferencePoint);
			courseplay:debug(nameNum(self)..": distanceToTrigger: "..tostring(distanceToTrigger).."  /bestTipReferencePoint: "..tostring(bestTipReferencePoint).." /trailerInTipRange: "..tostring(trailerInTipRange), 2);
			local goForTipping = false;
			
			--BGA TRIGGER
			if isBGA and not bgaIsFull then
				if self.cp.unloadAtSiloStart then
					goForTipping = trailerInTipRange;
				else
					if self.runonce == nil then
						self.runonce = 0;
					end;

					local silos = table.getn(ctt.bunkerSilo.movingPlanes);
					local x, y, z = getWorldTranslation(tipper.tipReferencePoints[bestTipReferencePoint].node);
					local sx, sy, sz = worldToLocal(ctt.bunkerSilo.movingPlanes[1].nodeId, x, y, z);
					local ex, ey, ez = worldToLocal(ctt.bunkerSilo.movingPlanes[silos].nodeId, x, y, z);
					local startDistance =  Utils.vector2Length(sx, sz) 
					local endDistance = Utils.vector2Length(ex, ez)
					local dist = courseplay:distance(sx, sz, ex, ez) 
					positionInSilo = startDistance*100/dist
					if self.runonce == 0 then
						local bgaSections = {
							fillLevel = { 0, 0, 0 },
							capacity = { 0, 0, 0 }
						};

						for k=1,silos do
							local filling = ctt.bunkerSilo.movingPlanes[k].fillLevel;
							local capacity = ctt.bunkerSilo.movingPlanes[k].capacity;
							if k <= math.ceil(silos * 0.3) then
								bgaSections.fillLevel[1] = bgaSections.fillLevel[1] + filling;
								bgaSections.capacity[1] = bgaSections.capacity[1] + capacity;
							elseif k <= math.ceil(silos * 0.6) then
								bgaSections.fillLevel[2] = bgaSections.fillLevel[2] + filling
								bgaSections.capacity[2] = bgaSections.capacity[2] + capacity;
							elseif k <= silos then 
								bgaSections.fillLevel[3] = bgaSections.fillLevel[3] + filling
								bgaSections.capacity[3] = bgaSections.capacity[3] + capacity;
							end
						end;
						courseplay:debug(string.format("%s: BGA section 1: %d/%d, section 2: %d/%d, section 3: %d/%d", nameNum(self), bgaSections.fillLevel[1], bgaSections.capacity[1], bgaSections.fillLevel[2], bgaSections.capacity[2], bgaSections.fillLevel[3], bgaSections.capacity[3]), 2);

						if bgaSections.fillLevel[1] <= bgaSections.fillLevel[2] and bgaSections.fillLevel[1] < bgaSections.fillLevel[3] then
							self.cp.tipLocation = 1;
						elseif bgaSections.fillLevel[2] <= bgaSections.fillLevel[3] and bgaSections.fillLevel[2] < bgaSections.fillLevel[1] then
							self.cp.tipLocation = 2;
						elseif bgaSections.fillLevel[3] < bgaSections.fillLevel[1] and bgaSections.fillLevel[3] < bgaSections.fillLevel[2] then
							self.cp.tipLocation = 3;
						else
							self.cp.tipLocation = 1;
						end;

						courseplay:debug(string.format("%s: BGA tipLocation = %d", nameNum(self), self.cp.tipLocation), 2);
						self.runonce = 1;
					end

					goForTipping = trailerInTipRange and ((positionInSilo >= bgaSectionPositions[self.cp.tipLocation].from and positionInSilo <= bgaSectionPositions[self.cp.tipLocation].to) or dist == 0) ;

					--TODO after v3.40: if section == 1 is full, check 2 and 3 / if section == 2 is full, check 1 and 3 etc.
				end;

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
				if isBGA then
					courseplay:debug(nameNum(self) .. ": goForTipping = true [BGA trigger accepts fruit (" .. tostring(fruitType) .. ")]", 2);
				else
					courseplay:debug(nameNum(self) .. ": goForTipping = true [trigger accepts fruit (" .. tostring(fruitType) .. ")]", 2);
				end;

				if tipper.tipState == Trailer.TIPSTATE_CLOSED then
					self.toggledTipState = bestTipReferencePoint;
					local isNearestPoint = false
					if distanceToTrigger > self.cp.closestTipDistance then
						isNearestPoint = true
						courseplay:debug(nameNum(self) .. ": isNearestPoint = true ", 2);
					else
						self.cp.closestTipDistance = distanceToTrigger
					end
					if distanceToTrigger == 0 or isBGA or isNearestPoint then
						tipper:toggleTipState(ctt,self.toggledTipState);
						self.cp.unloadingTipper = tipper
						courseplay:debug(nameNum(self)..": toggleTipState: "..tostring(self.toggledTipState).."  /unloadingTipper= "..tostring(self.cp.unloadingTipper.name), 2);
					end					
				elseif tipper.tipState ~= Trailer.TIPSTATE_CLOSING then 
					self.cp.closestTipDistance = math.huge
					allowedToDrive = false;
				end;

				if isBGA then
					allowedToDrive = true;
				end;
			elseif not ctt.acceptedFillTypes[fruitType] then
				if isBGA then
					courseplay:debug(nameNum(self) .. ": goForTipping = false [BGA trigger does not accept fruit (" .. tostring(fruitType) .. ")]", 2);
				else
					courseplay:debug(nameNum(self) .. ": goForTipping = false [trigger does not accept fruit (" .. tostring(fruitType) .. ")]", 2);
				end;
			elseif isBGA and not bgaIsFull and not trailerInTipRange and not goForTipping then
				courseplay:debug(nameNum(self) .. ": goForTipping = false [BGA: trailerInTipRange == false]", 2);
			elseif isBGA and not bgaIsFull and trailerInTipRange and not goForTipping then
				courseplay:debug(string.format("%s: goForTipping = false [BGA: position %.1f is not in section %d's area]", nameNum(self), positionInSilo, self.cp.tipLocation), 2);
			elseif isBGA and bgaIsFull and not goForTipping then
				courseplay:debug(nameNum(self) .. ": goForTipping = false [BGA: fillLevel > capacity]", 2);
			elseif isBGA and not goForTipping then
				courseplay:debug(nameNum(self) .. ": goForTipping = false [BGA]", 2);
			elseif not isBGA and not trailerInTipRange and not goForTipping then
				courseplay:debug(nameNum(self) .. ": goForTipping = false [trailerInTipRange == false]", 2);
			elseif not isBGA and not goForTipping then
				courseplay:debug(nameNum(self) .. ": goForTipping = false [fillLevel > capacity]", 2);
			end;
		end
	end
	return allowedToDrive
end

function courseplay:getAutoTurnradius(self, tipper_attached)
	local sinAlpha = 0       --Sinus vom Lenkwinkel
	local wheelbase = 0      --Radstand
	local track = 0		 --Spurweite
	local turnRadius = 0     --Wendekreis unbereinigt
	local xerion = false
	if self.foundWheels == nil then
		self.foundWheels = {}
	end
	for i=1, table.getn(self.wheels) do
		local wheel =  self.wheels[i]
		if wheel.rotMax ~= 0 then
			if self.foundWheels[1] == nil then
				sinAlpha = wheel.rotMax
				self.foundWheels[1] = wheel
			elseif self.foundWheels[2] == nil then
				self.foundWheels[2] = wheel
			elseif self.foundWheels[4] == nil then
				self.foundWheels[4] = wheel
			end
		elseif self.foundWheels[3] == nil then
			self.foundWheels[3] = wheel
		end
	
	end
	if self.foundWheels[3] == nil then --Xerion and Co
		sinAlpha = sinAlpha *2
		xerion = true
	end
		
	if table.getn(self.foundWheels) == 3 or xerion then
		local wh1X, wh1Y, wh1Z = getWorldTranslation(self.foundWheels[1].driveNode);
		local wh2X, wh2Y, wh2Z = getWorldTranslation(self.foundWheels[2].driveNode);	
		local wh3X, wh3Y, wh3Z = 0,0,0
		if xerion then
			wh3X, wh3Y, wh3Z = getWorldTranslation(self.foundWheels[4].driveNode);
		else
			wh3X, wh3Y, wh3Z = getWorldTranslation(self.foundWheels[3].driveNode);
		end	 
		track  = courseplay:distance(wh1X, wh1Z, wh2X, wh2Z)
		wheelbase = courseplay:distance(wh1X, wh1Z, wh3X, wh3Z)
		turnRadius = 2*wheelbase/sinAlpha+track
		self.foundWheels = {}	
	else
		turnRadius = self.cp.turnRadius                  -- Kasi and Co are not supported. Nobody does hauling with a Kasi or Quadtrack !!! 
	end;
	
	--if tipper_attached and self.cp.mode == 2 then
	if tipper_attached and (self.cp.mode == 2 or self.cp.mode == 3 or self.cp.mode == 4 or self.cp.mode == 6) then --JT: I've added modes 3, 4 & 6 - needed?
		self.cp.turnRadiusAuto = turnRadius;
		local n = #(self.tippers);
		--print(string.format("self.tippers[1].sizeLength = %s  turnRadius = %s", tostring(self.tippers[1].sizeLength),tostring( turnRadius)))
		if n == 1 and self.tippers[1].attacherVehicle ~= self and (self.tippers[1].sizeLength > turnRadius) then
			self.cp.turnRadiusAuto = self.tippers[1].sizeLength;
		end;
		if (n > 1) then
			self.cp.turnRadiusAuto = turnRadius * 1.5;
		end
	end;

	if self.cp.turnRadiusAutoMode then
		self.cp.turnRadius = self.cp.turnRadiusAuto;
		if math.abs(self.cp.turnRadius) > 50 then
			self.cp.turnRadius = 15
		end
	end;
end

function courseplay:getReverseProperties(self, tipper)
	if tipper.attacherVehicle == self then
		tipper.cp.frontNode = getParent(tipper.attacherJoint.node)
	else
		tipper.cp.frontNode = getParent(tipper.attacherVehicle.attacherJoint.node)
		courseplay:debug(string.format('%s: tipper %q has dolly', nameNum(self), nameNum(tipper)), 13);
	end
	if tipper.cp.hasSpecializationShovel or self.cp.hasSpecializationShovel then
		courseplay:debug(string.format('%s: return because tipper %q is a shovel', nameNum(self), nameNum(tipper)), 13);
		return
	end
	local x,y,z = getWorldTranslation(self.rootNode)
	local_,_,tz = worldToLocal(tipper.rootNode, x,y,z)
	tipper.cp.nodeDistance = math.abs(tz)
							courseplay:debug(nameNum(self) .. " tz: "..tostring(tz).."  tipper.rootNode: "..tostring(tipper.rootNode),13)
	if tz > 0 then
		tipper.cp.inversedNodes = false
	else
		tipper.cp.inversedNodes = true
	end
	local xTipper,yTipper,zTipper = getWorldTranslation(tipper.rootNode)
	local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(tipper.cp.frontNode, xTipper,yTipper,zTipper);
	courseplay:debug(nameNum(self) .. " lxFrontNode: "..tostring(lxFrontNode),13)
	if math.abs(lxFrontNode) <= 0.001 or tipper.rootNode == tipper.cp.frontNode then
		tipper.cp.isPivot = false
	else
		tipper.cp.isPivot = true
	end
	if tipper.rootNode == tipper.cp.frontNode then
		courseplay:debug(nameNum(self) .. "tipper.rootNode == tipper.cp.frontNode",13)
	end

	courseplay:debug(nameNum(self) .. " tipper.cp.inversedNodes: "..tostring(tipper.cp.inversedNodes).."  tipper.cp.isPivot: "..tostring(tipper.cp.isPivot).."  tipper.cp.frontNode: "..tostring(tipper.cp.frontNode),13)
end