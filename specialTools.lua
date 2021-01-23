function courseplay:setNameVariable(workTool)
	if workTool.cp == nil then
		workTool.cp = {};
	end;

	courseplay:updateFillLevelsAndCapacities(workTool)

	-- TODO: is this even needed? Why not use the workTool.spec_* directly? Do we really need our own table?
	-- Only default specs!
	for i,spec in pairs(workTool.specializations) do
		if spec == Combine 			   then workTool.cp.hasSpecializationCombine 			 = true;
		elseif spec == Cutter 			   then workTool.cp.hasSpecializationCutter 			 = true;
		elseif spec == Drivable 		   then workTool.cp.hasSpecializationDrivable 			 = true;
		elseif spec == FillUnit 		   then workTool.cp.hasSpecializationFillUnit 			 = true;
		elseif spec == FillVolume 		   then workTool.cp.hasSpecializationFillVolume			 = true;
		elseif spec == MixerWagon 		   then workTool.cp.hasSpecializationMixerWagon 		 = true;
		elseif spec == Shovel 			   then workTool.cp.hasSpecializationShovel 			 = true;
		elseif spec == Leveler 		   	   then workTool.cp.hasSpecializationLeveler 			 = true;
		elseif spec == Overloading 		   then workTool.cp.hasSpecializationOverloader			 = true;
		elseif spec == Trailer	 		   then workTool.cp.hasSpecializationTrailer			 = true;
		elseif spec == BunkerSiloCompacter then workTool.cp.hasSpecializationBunkerSiloCompacter = true;		
		end;
	end;

    if workTool.cp.hasSpecializationFillUnit and workTool.cp.hasSpecializationFillVolume then
		workTool.cp.hasSpecializationFillable = true;
	end;

	--------------------------------------------------------------
	-- ###########################################################
	--------------------------------------------------------------

	-- SPECIALIZATIONS BASED
	-- [1] AUGER WAGONS
	if workTool.typeName == 'augerWagon' then
		workTool.cp.isAugerWagon = true;
	elseif workTool.cp.hasSpecializationOverloader and not workTool.cp.hasSpecializationCutter then
		workTool.cp.isAugerWagon = true;
	elseif workTool.animationParts ~= nil and workTool.animationParts[2] ~= nil and workTool.toggleUnloadingState ~= nil and workTool.setUnloadingState ~= nil then
		workTool.cp.isAugerWagon = true;
	end;
end;
