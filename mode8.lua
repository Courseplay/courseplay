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
						--print("trailer unloadtrigger id : "..tostring(trailer.unloadTrigger.triggerId))
					end	
				end
			--ManureLager
			elseif workTool.setIsReFilling ~= nil and workTool.ReFillTrigger ~= nil and workTool.fillLevel > 0 and not workTool.isReFilling then
				workTool:setIsReFilling(true);
				vehicle.cp.lastMode8UnloadTriggerId = workTool.ReFillTrigger.manureTrigger
				--print("manure unloadtrigger id : "..tostring(workTool.ReFillTrigger.manureTrigger))
			end;
		end;
	end;
end;
