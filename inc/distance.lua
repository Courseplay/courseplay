
-- distance between two coordinates
function courseplay:distance(x1 ,z1 ,x2 ,z2)
	xd = (x1 - x2) * (x1 - x2)
	zd = (z1 -z2) * (z1 - z2)
	dist = math.sqrt(math.abs(xd + zd) )
	return dist
end

-- displays arrow and distance to start point
function courseplay:dcheck(self)
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  if self.back then 
      number = self.maxnumber - 2
  else
      number = 1
  end	
  
  local arrowUV = {}
  local lx, ly, lz = worldToLocal(self.rootNode, self.Waypoints[number].cx, 0, self.Waypoints[number].cz)
  local arrowRotation = Utils.getYRotationFromDirection(lx, lz)
  
  arrowUV[1] = -0.5 * math.cos(-arrowRotation) + 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[2] = -0.5 * math.sin(-arrowRotation) - 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[3] = -0.5 * math.cos(-arrowRotation) - 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[4] = -0.5 * math.sin(-arrowRotation) + 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[5] = 0.5 * math.cos(-arrowRotation) + 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[6] = 0.5 * math.sin(-arrowRotation) - 0.5 * math.cos(-arrowRotation) + 0.5
  arrowUV[7] = 0.5 * math.cos(-arrowRotation) - 0.5 * math.sin(-arrowRotation) + 0.5
  arrowUV[8] = 0.5 * math.sin(-arrowRotation) + 0.5 * math.cos(-arrowRotation) + 0.5
  
  setOverlayUVs(self.ArrowOverlay.overlayId, arrowUV[1], arrowUV[2], arrowUV[3], arrowUV[4], arrowUV[5], arrowUV[6], arrowUV[7], arrowUV[8])
  self.ArrowOverlay:render()
  local ctx,cty,ctz = getWorldTranslation(self.rootNode);
  if self.record then
    return
  end
  local cx ,cz = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
  dist = courseplay:distance(ctx ,ctz ,cx ,cz)
  self.info_text = string.format("entfernung: %d ",dist )  
end;