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
			local rootVehicle = attacherVehicle:getRootVehicle()
			if rootVehicle then 
				if rootVehicle.cp.settings then 
					rootVehicle.cp.settings:validateCurrentValues()
				end
				if rootVehicle.cp.driver then 
					rootVehicle.cp.driver:refreshHUD()
				end
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
	local rootVehicle = self:getRootVehicle()
	if rootVehicle then 
		if rootVehicle.cp.settings then 
			rootVehicle.cp.settings:validateCurrentValues()
		end
		if rootVehicle.cp.driver then 
			rootVehicle.cp.driver:refreshHUD()
		end
	end
end;

function courseplay:resetTools(vehicle)
	vehicle.cp.workTools = {}
	-- are there any tippers?
	vehicle.cp.hasAugerWagon = false;

	vehicle.cp.workToolAttached = courseplay:updateWorkTools(vehicle, vehicle);
	if not vehicle.cp.workToolAttached and not vehicle.cp.mode == courseplay.MODE_BUNKERSILO_COMPACTER then
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
	

	vehicle.cp.tooIsDirty = false;
end;

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

	local isAllowedOkay,isDisallowedOkay = CpManager.validModeSetupHandler:isModeValid(vehicle.cp.mode,workTool)
	if isAllowedOkay and isDisallowedOkay then
		if vehicle.cp.mode == 5 then 
			-- For reversing purpose ?? still needed ?
			if isImplement then
				hasWorkTool = true;
				vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			end
		else
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end
	end
	

	-- MODE 4: FERTILIZER AND SEEDING
	if vehicle.cp.mode == 4 then
		if isAllowedOkay and isDisallowedOkay then
			courseplay:setMarkers(vehicle, workTool)
			vehicle.cp.hasMachinetoFill = true;
			vehicle.cp.noStopOnEdge = isSprayer and not (isSowingMachine or workTool.cp.isTreePlanter);
			vehicle.cp.noStopOnTurn = isSprayer and not (isSowingMachine or workTool.cp.isTreePlanter);
		end;
	-- MODE 6: FIELDWORK
	elseif vehicle.cp.mode == 6 then
		if isAllowedOkay and isDisallowedOkay then
			courseplay:setMarkers(vehicle, workTool);
			vehicle.cp.noStopOnTurn = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or workTool.cp.hasSpecializationCutter;
			vehicle.cp.noStopOnEdge = courseplay:isBaler(workTool) or courseplay:isBaleLoader(workTool) or courseplay:isSpecialBaleLoader(workTool) or workTool.cp.hasSpecializationCutter;
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
	end	
	--belongs to mode3 but should be considered even if the mode is not set correctely
	if workTool.cp.isAugerWagon then
		vehicle.cp.hasAugerWagon = true;
	end;

	
	vehicle.cp.hasWaterTrailer = hasWaterTrailer
	
	if hasWorkTool then
		courseplay:debug(('%s: workTool %q added to workTools (index %d)'):format(nameNum(vehicle), nameNum(workTool), #vehicle.cp.workTools), 6);
	end;

	--------------------------------------------------

	if not isImplement or hasWorkTool or workTool.cp.isNonTippersHandledWorkTool then
		-- SPECIAL SETTINGS ?? is this one needed any more ? 
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

function courseplay:addCpNilTempFillLevelFunction()
	local cpNilTempFillLevel = function(self, state)
		if state ~= self.state and state == BunkerSilo.STATE_CLOSED then
			self.cpTempFillLevel = nil;
		end;
	end;
	BunkerSilo.setState = Utils.prependedFunction(BunkerSilo.setState, cpNilTempFillLevel);
end;

function courseplay:resetTipTrigger(vehicle, changeToForward)
	if vehicle.cp.currentTipTrigger ~= nil then
		vehicle.cp.currentTipTrigger = nil;
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

--this one enable the buttons and allowes the user to change the mode
function courseplay:getIsToolCombiValidForCpMode(vehicle,cpModeToCheck)
	--5 is always valid
	if cpModeToCheck == 5 then 
		return true;
	end
	if cpModeToCheck == 7 then 
		return false;
	end
	local callback = {}
	callback.isDisallowedOkay = true
	courseplay:getIsToolValidForCpMode(vehicle,cpModeToCheck,callback)
	return callback.isAllowedOkay and callback.isDisallowedOkay
end

function courseplay:getIsToolValidForCpMode(object, mode, callback)
	isAllowedOkay,isDisallowedOkay = CpManager.validModeSetupHandler:isModeValid(mode,object)
	callback.isAllowedOkay = callback.isAllowedOkay or isAllowedOkay
	callback.isDisallowedOkay = callback.isDisallowedOkay and isDisallowedOkay
	for _,impl in pairs(object:getAttachedImplements()) do
		courseplay:getIsToolValidForCpMode(impl.object, mode, callback)
	end
end

function courseplay:updateFillLevelsAndCapacities(vehicle)
	courseplay:setOwnFillLevelsAndCapacities(vehicle,vehicle.cp.mode)
	vehicle.cp.totalFillLevel = vehicle.cp.fillLevel;
	vehicle.cp.totalCapacity = vehicle.cp.capacity;
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
