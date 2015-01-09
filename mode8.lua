function courseplay:handle_mode8(vehicle)
	
	for i,workTool in pairs(vehicle.cp.workTools) do
		--                                            courseplay:handleSpecialTools(vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload)
		local isSpecialTool, allowedToDrive, lx, lz = courseplay:handleSpecialTools(vehicle, workTool, nil,    nil,   nil,    nil,            nil,   true  );
		if not isSpecialTool then
			if workTool.getOverloadingTrailerInRangePipeState ~= nil and workTool:getOverloadingTrailerInRangePipeState() > 0 and workTool.fillLevel > 0 and not workTool.isOverloadingActive then
				for trailer,_ in pairs(workTool.overloadingTrailersInRange) do
					if trailer.unloadTrigger ~= nil then
						workTool:setOverloadingActive(true);
						vehicle.cp.lastMode8UnloadTriggerId = trailer.unloadTrigger.triggerId
						--print("mode8: trailer unloadtrigger id : "..tostring(trailer.unloadTrigger.triggerId))
					end	
				end
				
			-- ManureLager
			elseif workTool.setIsReFilling ~= nil and workTool.ReFillTrigger ~= nil and workTool.fillLevel > 0 and not workTool.isReFilling then
				workTool:setIsReFilling(true);
				vehicle.cp.lastMode8UnloadTriggerId = workTool.ReFillTrigger.manureTrigger
				--print("mode8: manure unloadtrigger id : "..tostring(workTool.ReFillTrigger.manureTrigger))
			
			--BGA extension V3.0
			elseif workTool.fillTriggers[1] and  workTool.fillTriggers[1].bga and workTool.fillTriggers[1].bga.fermenter_bioOK then
				if not workTool.isFilling and workTool.fillLevel > 1 then
					workTool:setIsFilling(true);
					vehicle.cp.lastMode8UnloadTriggerId = workTool.fillTriggers[1].triggerId
					--print("mode8: trigger id : "..tostring(workTool.fillTriggers[1].triggerId))
				end;
			end;
		end;
	end;
end;
