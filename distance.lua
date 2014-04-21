-- distance between two coordinates
function courseplay:distance(x1, z1, x2, z2)
	if x1 == nil or x2 == nil or z1 == nil or z2 == nil then
		return 1000;
	end;

	return Utils.vector2Length(x2 - x1, z2 - z1);
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
	vehicle.cp.infoText = string.format("%s: %.1fm", courseplay:loc("COURSEPLAY_DISTANCE"), courseplay:distance(ctx, ctz, cx, cz));
end;


function courseplay:distanceToObject(vehicle, object)
	local x, y, z = getWorldTranslation(vehicle.rootNode)
	local ox, oy, oz = worldToLocal(object.rootNode, x, y, z)

	return Utils.vector2Length(ox, oz)
end


function courseplay:distanceToPoint(vehicle, x, y, z)
	local ox, oy, oz = worldToLocal(vehicle.cp.DirectionNode, x, y, z)
	return Utils.vector2Length(ox, oz)
end