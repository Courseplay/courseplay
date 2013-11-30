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
function courseplay:dcheck(vehicle)
	local number = vehicle.record_pause and vehicle.recordnumber - 1 or 1;

	local ctx, cty, ctz = getWorldTranslation(vehicle.rootNode);
	local cx, cz = vehicle.Waypoints[number].cx, vehicle.Waypoints[number].cz;
	local lx, ly, lz = worldToLocal(vehicle.rootNode, cx, 0, cz);
	local arrowRotation = Utils.getYRotationFromDirection(lx, lz);

	local cosAR, sinAR = math.cos(-arrowRotation), math.sin(-arrowRotation);
	local arrowUV = {
		[1] = -0.5 * cosAR + 0.5 * sinAR + 0.5;
		[2] = -0.5 * sinAR - 0.5 * cosAR + 0.5;
		[3] = -0.5 * cosAR - 0.5 * sinAR + 0.5;
		[4] = -0.5 * sinAR + 0.5 * cosAR + 0.5;
		[5] =  0.5 * cosAR + 0.5 * sinAR + 0.5;
		[6] =  0.5 * sinAR - 0.5 * cosAR + 0.5;
		[7] =  0.5 * cosAR - 0.5 * sinAR + 0.5;
		[8] =  0.5 * sinAR + 0.5 * cosAR + 0.5;
	};

	setOverlayUVs(vehicle.cp.directionArrowOverlay.overlayId, arrowUV[1], arrowUV[2], arrowUV[3], arrowUV[4], arrowUV[5], arrowUV[6], arrowUV[7], arrowUV[8]);
	vehicle.cp.directionArrowOverlay:render();

	vehicle.cp.infoText = string.format("%s: %.1fm", courseplay:get_locale(vehicle, "CPDistance"), courseplay:distance(ctx, ctz, cx, cz));
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