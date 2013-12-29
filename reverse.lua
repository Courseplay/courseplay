function courseplay:goReverse(self,lx,lz)

		local fwd = false
		local inverse = 1
		local tipper = self.tippers[1]
		local debugActive = courseplay.debugChannels[13]
		local isNotValid = table.getn(self.tippers) == 0 or tipper.cp.inversedNodes == nil or tipper.cp.isPivot == nil or tipper.cp.frontNode == nil or self.cp.mode == 9 
		if isNotValid then
			return -lx,-lz,fwd
		end
		
		if tipper.cp.inversedNodes then
			inverse = -1
		end
		if self.cp.lastReverseRecordnumber == nil then
			self.cp.lastReverseRecordnumber = self.recordnumber -1
		end
		local nodeDistance = math.max(tipper.cp.nodeDistance,6)
		local node = tipper.rootNode
		local isPivot = tipper.cp.isPivot
		local xTipper,yTipper,zTipper = getWorldTranslation(node)
		if debugActive then drawDebugPoint(xTipper, yTipper+3, zTipper, 1, 0 , 0, 1) end;
		local xTractor,yTractor,zTractor = getWorldTranslation(self.rootNode)
		local frontNode = tipper.cp.frontNode
		local xFrontNode,yFrontNode,zFrontNode = getWorldTranslation(frontNode)
		local tipperFillLevel, tipperCapacity = self:getAttachedTrailersFillLevelAndCapacity();
		local tcx,tcy,tcz =0,0,0
		local index = self.recordnumber +1
		if debugActive then 
			drawDebugPoint(xFrontNode,yFrontNode+3,zFrontNode, 1, 0 , 0, 1)
			if not self.cp.checkReverseValdityPrinted then
				local checkValdity = false
				for i=index, self.maxnumber do
					if self.Waypoints[i].rev then 
						tcx = self.Waypoints[i].cx
						tcz = self.Waypoints[i].cz
						local _,_,z = worldToLocal(node, tcx,yTipper,tcz)
						if z*inverse < 0 then
							checkValdity = true
							break
						end
					else
						break
					end		
				end
				if not checkValdity then
					print(nameNum(self) ..": reverse course is not valid")
				end
				self.cp.checkReverseValdityPrinted = true
			end
		end;
		for i= index, self.maxnumber do
			if self.Waypoints[i].rev then
				tcx = self.Waypoints[i].cx
				tcz = self.Waypoints[i].cz
			else
				tcx , tcy, tcz = localToWorld(node,0,0,-10*inverse)
			end
			local distance = courseplay:distance(xTipper,zTipper, tcx ,tcz)	
			if distance > nodeDistance then
					local _,_,z = worldToLocal(node, tcx,yTipper,tcz)
					if z*inverse < 0 then
						self.recordnumber = i -1
						break
					end
			end
		end
		srX,srZ = self.Waypoints[self.recordnumber].cx,self.Waypoints[self.recordnumber].cz
		local _,_,tsrZ = worldToLocal(self.rootNode,srX,yTipper,srZ)
		if tsrZ > 0 then
			self.cp.checkReverseValdityPrinted = false
			self.recordnumber = self.recordnumber +1 
		end 

		if debugActive then drawDebugPoint(tcx, yTipper+3, tcz, 1, 1 , 1, 1)end;
		local lxTipper, lzTipper = AIVehicleUtil.getDriveDirection(node, tcx, yTipper, tcz);
		courseplay:showDirection(node,lxTipper, lzTipper)
		local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(frontNode, xTipper,yTipper,zTipper);
		
		if tipper.cp.inversedNodes then 	-- some tippers have the rootNode backwards, crazy isn't it?
			lxTipper, lzTipper = -lxTipper, -lzTipper 
			lxFrontNode, lzFrontNode = -lxFrontNode, -lzFrontNode
		end
		if math.abs(lxFrontNode) > 0.001 and not tipper.cp.isPivot and tipper.rootNode ~= tipper.cp.frontNode then --backup
 			tipper.cp.isPivot = true
			courseplay:debug(nameNum(self) .. " backup tipper.cp.isPivot set: "..tostring(lxFrontNode),13)
		end
		local lxTractor, lzTractor = 0,0
		local limitTractor = 0.068
		local limitFront = 0.065
		local limitTipper = 0.03

		if isPivot then
			courseplay:showDirection(frontNode,lxFrontNode, lzFrontNode)
			lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(self.rootNode, xFrontNode,yFrontNode,zFrontNode);
			courseplay:showDirection(self.rootNode,lxTractor, lzTractor)
			
			lz = (-lzTractor) - (-lzFrontNode) 
			lx = (-lxTractor) - (-lxFrontNode) 
			
			if ((lxTipper > limitTipper and lxFrontNode < lxTipper) or (lxTipper < -limitTipper and lxFrontNode > lxTipper)) and math.abs(lxFrontNode) < limitFront and math.abs(lxTractor) < limitTractor then

					lz = (-lzFrontNode) - (-lzTipper)
					lx = (-lxFrontNode) - (-lxTipper)
					
					lz = (-lzTractor) - lz
					lx = (-lxTractor) - lx
					courseplay.Revprinted = false
					if (lxTipper > 0 and lxFrontNode > 0 and lxTractor > 0) or (lxTipper < 0 and lxFrontNode < 0 and lxTractor < 0) then
						lz = -lz
						lx = -lx
					end
			else
				if not courseplay.Revprinted then
					if math.abs(lxFrontNode) > limitFront then
						courseplay:debug(nameNum(self) .. " out with front: "..tostring(lxFrontNode),13)
					end
					if math.abs(lxTractor) > limitTractor then
						courseplay:debug(nameNum(self) .. " out with tractor: "..tostring(lxTractor),13)
					end
					if math.abs(lxTipper) < limitTipper then
						courseplay:debug(nameNum(self) .. " out with tipper: "..tostring(lxTipper),13)
					end
					courseplay.Revprinted = true
				end
			end
		else
			lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(self.rootNode, xTipper,yTipper,zTipper);
			courseplay:showDirection(self.rootNode,lxTractor, lzTractor)
			
			lz = (-lzTractor) - (-lzTipper) 
			lx = (-lxTractor) - (-lxTipper) 
		
			if math.abs(lx) < 0.05 then
				lx = 0
				lz = 1
			end
			--print("lx: "..tostring(lx).."	lxTractor: "..tostring(lxTractor).."	lxTipper: "..tostring(lxTipper))
		end
		if (math.abs(lxFrontNode) > 0.4 or math.abs(lxTractor) > 0.4)  and isPivot then
			fwd = true
			--lx = -lx
			self.recordnumber = self.cp.lastReverseRecordnumber
		end
		local nx, ny, nz = localDirectionToWorld(node, lxTipper, 0, lzTipper)
		courseplay:debug(nameNum(self) .. ": call backward raycast", 1);
		local num = raycastAll(xTipper,yTipper+1,zTipper, nx, ny, nz, "findTipTriggerCallback", 10, self)
		if num > 0 then 
			courseplay:debug(string.format("%s: drive(%d): backward raycast end", nameNum(self), debug.getinfo(1).currentline), 1);
		end;
		if courseplay.debugChannels[1] then
			drawDebugLine(xTipper,yTipper+1,zTipper, 1, 1, 0, xTipper+(nx*10), yTipper+(ny*10), zTipper+(nz*10), 1, 1, 0);
		end;
		courseplay:showDirection(self.rootNode,lx,lz)
		if (self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 6) and self.cp.tipperFillLevel == 0 then
			for i = self.recordnumber, self.maxnumber do
				if  not self.Waypoints[i].rev then
					local _,_,lz = worldToLocal(self.cp.DirectionNode, self.Waypoints[i].cx , y , self.Waypoints[i].cz)
					if lz > 3 then
						self.recordnumber = i
						break
					end					
				end
			end
		end
		
		

		return lx,lz,fwd
end

function courseplay:showDirection(node,lx,lz)
	if courseplay.debugChannels[13] then
		local x,y,z = getWorldTranslation(node)
		ctx,_,ctz = localToWorld(node,lx*5,y,lz*5)
		drawDebugLine(x, y+5, z, 1, 0, 0, ctx, y+5, ctz, 1, 0, 0);
	end
end