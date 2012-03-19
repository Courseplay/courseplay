-- handles "mode1" : waiting at start until tippers full - driving course and unloading on trigger
function courseplay:handle_mode8(self)
	if self.tippers ~= nil then
		for i=1, table.getn(self.tippers) do
		workTool = self.tippers[i]
			if workTool ~= nil then
				if workTool.trailerInTrigger ~= nil and workTool.fillLevel > 0 and not workTool.fill then	
					workTool.fill = true;
				end
			end
		end
	end
end  