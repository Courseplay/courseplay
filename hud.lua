-- Load Lines for Hud
function courseplay:HudPage(self)
local Page = self.showHudInfoBase
local i = 0
--local c = 1
setTextBold(false)
for c=1, 2, 1 do
for v,name in pairs(self.hudpage[Page][c]) do
if c == 1 then
local yspace = 0.383 - (i * 0.021)
renderText(0.763, yspace, 0.021, name);
elseif c == 2 then
local yspace = 0.383 - (i * 0.021)
renderText(0.87, yspace, 0.021, name);
end
i = i + 1
end
i = 0
end
end