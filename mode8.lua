function courseplay:handle_mode8(vehicle)
	for i,workTool in pairs(vehicle.cp.workTools) do
		--                                            courseplay:handleSpecialTools(vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload)
		local isSpecialTool, allowedToDrive, lx, lz = courseplay:handleSpecialTools(vehicle, workTool, nil,    nil,   nil,    nil,            nil,   true  );
		if not isSpecialTool then
			if workTool.trailerInTrigger ~= nil and workTool.fillLevel > 0 and not workTool.fill then
				workTool.fill = true;

			--ManureLager
			elseif workTool.setIsReFilling ~= nil and workTool.ReFillTrigger ~= nil and workTool.fillLevel > 0 and not workTool.isReFilling then
				workTool:setIsReFilling(true);
			end;
		end;
	end;
end;
