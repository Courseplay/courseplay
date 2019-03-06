function courseplay:stopAIVehicle(superFunc, reason, noEventSend)
	courseplay.debugVehicle(12, self,'stopAIVehicle reason = %s, courseplay driving = %s', tostring(reason), tostring(courseplay:getIsCourseplayDriving()))
	if superFunc ~= nil and not courseplay:getIsCourseplayDriving() then
		superFunc(self, reason, noEventSend)
	else
		courseplay.debugVehicle(12, self,'Not calling AIVehicle.stopAIVehicle as courseplay is driving')
	end
end
AIVehicle.stopAIVehicle = Utils.overwrittenFunction(AIVehicle.stopAIVehicle, courseplay.stopAIVehicle)
