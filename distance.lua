-- distance between two coordinates
function courseplay:distance(x1, z1, x2, z2)
	if x1 == nil or x2 == nil or z1 == nil or z2 == nil then
		return 1000;
	end;

	return MathUtil.vector2Length(x2 - x1, z2 - z1);
end

function courseplay:distance3D(x1,y1,z1,x2,y2,z2)
	return MathUtil.vector3Length(x2 - x1, y2 - y1, z2 - z1);
end

-- displays arrow and distance to previous point
function courseplay:distanceCheck(vehicle)
	local number = vehicle.cp.recordingIsPaused and vehicle.cp.waypointIndex - 1 or 1;

	local cx, cz = vehicle.Waypoints[number].cx, vehicle.Waypoints[number].cz;
	local lx, ly, lz = worldToLocal(vehicle.cp.directionNode, cx, 0, cz);
	local arrowRotation = MathUtil.getYRotationFromDirection(lx, lz);
	vehicle.cp.directionArrowOverlay:setRotation(arrowRotation, vehicle.cp.directionArrowOverlay.width/2, vehicle.cp.directionArrowOverlay.height/2);
	vehicle.cp.directionArrowOverlay:render();

	local ctx, cty, ctz = getWorldTranslation(vehicle.cp.directionNode);
	courseplay:setInfoText(vehicle, ('COURSEPLAY_DISTANCE;%d'):format(courseplay:distance(ctx, ctz, cx, cz)));
end;

function courseplay:distanceToObject(vehicle, object)
	local node1 = vehicle.cp.directionNode or vehicle.rootNode
	local node2 = object.rootNode or object.nodeId
	return calcDistanceFrom(node1, node2)
end

function courseplay:distanceToPoint(vehicle, x, y, z)
	local ox, oy, oz = worldToLocal(vehicle.cp.directionNode, x, y, z);
	return MathUtil.vector2Length(ox, oz);
end;

function courseplay:nodeToNodeDistance(node1, node2)
	local x1,y1,z1 = getWorldTranslation(node1);
	local x2,y2,z2 = getWorldTranslation(node2);
	return MathUtil.vector3Length(x2 - x1, y2 - y1, z2 - z1);
end;
