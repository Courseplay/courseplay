function courseplay:change_ai_state(self, change_by)
  self.ai_mode = self.ai_mode + change_by

  if self.ai_mode == 5 or self.ai_mode == 0 then  
    self.ai_mode = 1    
  end
end

function courseplay:switch_hud_page(self, change_by)
  self.showHudInfoBase = self.showHudInfoBase + change_by
  if self.showHudInfoBase == 0 then  --edit for more sites
    self.showHudInfoBase = 1
   end

   if self.showHudInfoBase == 5 then  --edit for more sites
     self.showHudInfoBase = 4
   end
end


function courseplay:change_combine_offset(self, change_by)
  self.combine_offset = self.combine_offset + change_by
  
  if self.combine_offset < 0 then
    self.combine_offset = 0
  end
  
  if self.chopper_offset > 0 then
    self.chopper_offset = self.combine_offset
  else
    self.chopper_offset = self.combine_offset * -1
  end
  
end

function courseplay:change_tipper_offset(self, change_by)
  self.tipper_offset = self.tipper_offset + change_by

end



function courseplay:change_required_fill_level(self, change_by)
   self.required_fill_level_for_follow = self.required_fill_level_for_follow + change_by
  
  if self.required_fill_level_for_follow < 0 then
    self.required_fill_level_for_follow = 0
  end
  
  if self.required_fill_level_for_follow > 100 then
    self.required_fill_level_for_follow = 100
  end
end


function courseplay:change_turn_radius(self, change_by)
   self.turn_radius = self.turn_radius + change_by
   
   if self.turn_radius < 0 then
    self.turn_radius = 0
  end
end


