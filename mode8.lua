-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode8(self)
	if self.tippers ~= nil then
		for i = 1, table.getn(self.tippers) do
			workTool = self.tippers[i]
			if workTool ~= nil then
				--courseplay:handleSpecialTools(self,workTool,unfold,lower,turnOn,allowedToDrive,cover,unload)
				courseplay:handleSpecialTools(self,workTool,nil,nil,nil,nil,nil,true)
				if workTool.trailerInTrigger ~= nil and workTool.fillLevel > 0 and not workTool.fill then
			
					workTool.fill = true;
				
				--ManureLager
				elseif workTool.setIsReFilling ~= nil and workTool.ReFillTrigger ~= nil and workTool.fillLevel > 0 and not workTool.isReFilling then
					workTool:setIsReFilling(true);
				end;
			end
		end
	end
end
