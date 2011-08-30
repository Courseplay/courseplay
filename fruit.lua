-- inspired by fieldstatus of Alan R. (ls-uk.info: thebadtouch)
function courseplay:area_has_fruit(x,z)
  
  local numFruits = table.getn(g_currentMission.fruits);
  local getdenFunc = Utils.getDensity;
  local getfruitFunc = Utils.getFruitArea;
  local chnum=0;
  local density = 0
  local startX, startZ, endX, endZ, widthX, widthZ, heightX, heightZ;
  
  local widthX=0.5;
  local widthZ=0.5;
  
  --x = x - 2.5
  --z = z - 2.5
  
  for i = 1, FruitUtil.NUM_FRUITTYPES do
  	if i ~= FruitUtil.FRUITTYPE_GRASS then	    
  	  	  
  	  density = Utils.getFruitArea(i, x, z, x-widthX, z-widthZ, x+widthX, z+widthZ);
  	    	  	     	  	  
  	  if density > 0 then
  	  	print(string.format("checking x: %d z %d - density: %d", x, z, density ))
  	    return true
  	  end  	  	  
  	end
  end
  
  print(string.format(" x: %d z %d - is really cut!", x, z ))
  return false
end



function courseplay:check_for_fruit(self, distance)
  
  local x,y,z = localToWorld(self.aiTractorDirectionNode, 0, 0, distance) --getWorldTranslation(combine.aiTreshingDirectionNode);
   
  local length = Utils.vector2Length(x,z);
  local aiThreshingDirectionX = x/length;
  local aiThreshingDirectionZ = z/length; 
  
  local dirX, dirZ = aiThreshingDirectionX, aiThreshingDirectionZ;
  if dirX == nil or x == nil or dirZ == nil then
	  return 0, 0 
  end
  local sideX, sideZ = -dirZ, dirX;
	
  local threshWidth = 3     		
  
  local sideWatchDirOffset = -8
  local sideWatchDirSize = 3
  
  
  local lWidthX = x - sideX*0.5*threshWidth + dirX * sideWatchDirOffset;
  local lWidthZ = z - sideZ*0.5*threshWidth + dirZ * sideWatchDirOffset;
  local lStartX = lWidthX - sideX*0.7*threshWidth;
  local lStartZ = lWidthZ - sideZ*0.7*threshWidth;
  local lHeightX = lStartX + dirX*sideWatchDirSize;
  local lHeightZ = lStartZ + dirZ*sideWatchDirSize;
  
  local rWidthX = x + sideX*0.5*threshWidth + dirX * sideWatchDirOffset;
  local rWidthZ = z + sideZ*0.5*threshWidth + dirZ * sideWatchDirOffset;
  local rStartX = rWidthX + sideX*0.7*threshWidth;
  local rStartZ = rWidthZ + sideZ*0.7*threshWidth;
  local rHeightX = rStartX + dirX*sideWatchDirSize;
  local rHeightZ = rStartZ + dirZ*sideWatchDirSize;
  local leftFruit = 0
  local rightFruit = 0
   
   for i = 1, FruitUtil.NUM_FRUITTYPES do
     if i ~= FruitUtil.FRUITTYPE_GRASS then	   	 
	     leftFruit = leftFruit + Utils.getFruitArea(i, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ)
	   
	     rightFruit = rightFruit + Utils.getFruitArea(i, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ)
     end
   end
  
  return leftFruit, rightFruit;
end


function courseplay:side_to_drive(self, combine, distance)
  -- if there is a forced side to drive return this
  if self.forced_side ~= nil then
    if self.forced_side == "left" then
      return 0, 1000
    else
      return 1000, 0
    end
  end  
  
  -- with autopilot combine, choose search area side
  if combine.apCombinePresent ~= nil and combine.apCombinePresent then
	if combine.autoPilotEnabled then 							
		if combine.autoPilotAreaLeft.available and combine.autoPilotAreaLeft.active then
			return 0, 1000
		end
		if combine.autoPilotAreaRight.available and combine.autoPilotAreaRight.active then 
			return 1000, 0
		end
	end
  end
  
  local x,y,z = localToWorld(combine.aiTreshingDirectionNode, 0, 0, distance) --getWorldTranslation(combine.aiTreshingDirectionNode);
    
  local dirX, dirZ = combine.aiThreshingDirectionX, combine.aiThreshingDirectionZ;
  if dirX == nil or x == nil or dirZ == nil then
    return 0, 0 
  end
  local sideX, sideZ = -dirZ, dirX;
  
  local threshWidth = 20		  
  
  local lWidthX = x - sideX*0.5*threshWidth + dirX * combine.sideWatchDirOffset;
  local lWidthZ = z - sideZ*0.5*threshWidth + dirZ * combine.sideWatchDirOffset;
  local lStartX = lWidthX - sideX*0.7*threshWidth;
  local lStartZ = lWidthZ - sideZ*0.7*threshWidth;
  local lHeightX = lStartX + dirX*combine.sideWatchDirSize;
  local lHeightZ = lStartZ + dirZ*combine.sideWatchDirSize;
  
  local rWidthX = x + sideX*0.5*threshWidth + dirX * combine.sideWatchDirOffset;
  local rWidthZ = z + sideZ*0.5*threshWidth + dirZ * combine.sideWatchDirOffset;
  local rStartX = rWidthX + sideX*0.7*threshWidth;
  local rStartZ = rWidthZ + sideZ*0.7*threshWidth;
  local rHeightX = rStartX + dirX*self.sideWatchDirSize;
  local rHeightZ = rStartZ + dirZ*self.sideWatchDirSize;
  local leftFruit = 0
  local rightFruit = 0
  
  for i = 1, FruitUtil.NUM_FRUITTYPES do
    leftFruit = leftFruit + Utils.getFruitArea(i, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ)
  
    rightFruit = rightFruit + Utils.getFruitArea(i, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ)
  end
  
  --print(string.format("fruit:  left %f right %f",leftFruit,rightFruit ))
  
  return leftFruit,rightFruit
end