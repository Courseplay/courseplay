-- distance between two coordinates
function courseplay:distance(x1, z1, x2, z2)
	if x1 == nil or x2 == nil or z1 == nil or z2 == nil then
		return 1000;
	end;

	local xd = math.pow(x1 - x2, 2);
	local zd = math.pow(z1 - z2, 2);
	return math.sqrt(math.abs(xd + zd));
end

-- displays arrow and distance to previous point
function courseplay:distanceCheck(vehicle)
	local number = vehicle.cp.recordingIsPaused and vehicle.recordnumber - 1 or 1;

	local cx, cz = vehicle.Waypoints[number].cx, vehicle.Waypoints[number].cz;
	local lx, ly, lz = worldToLocal(vehicle.rootNode, cx, 0, cz);
	local arrowRotation = Utils.getYRotationFromDirection(lx, lz);
	vehicle.cp.directionArrowOverlay:setRotation(arrowRotation, vehicle.cp.directionArrowOverlay.width/2, vehicle.cp.directionArrowOverlay.height/2);
	vehicle.cp.directionArrowOverlay:render();

	local ctx, cty, ctz = getWorldTranslation(vehicle.rootNode);
	vehicle.cp.infoText = string.format("%s: %.1fm", courseplay:loc("CPDistance"), courseplay:distance(ctx, ctz, cx, cz));
end;


function courseplay:distance_to_object(self, object)
	local x, y, z = getWorldTranslation(self.rootNode)
	local ox, oy, oz = worldToLocal(object.rootNode, x, y, z)

	return Utils.vector2Length(ox, oz)
end


function courseplay:distance_to_point(self, x, y, z)
	local ox, oy, oz = worldToLocal(self.cp.DirectionNode, x, y, z)
	return Utils.vector2Length(ox, oz)
end