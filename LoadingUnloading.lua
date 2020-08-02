--Loading/Unloading handling with direct giants function 
--and not with local CP Triggers/ no more cp.worktool using!!

--for now only support for FieldSupplyAIDriver and FillableFieldworkAIDriver!

--used to check if fillTrigger is allowed and start/stop driver



--LoadTrigger callback used to open correct cover for loading 
function courseplay:loadTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	--legancy code!!!
	courseplay:SiloTrigger_TriggerCallback(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:isAIDriverActive(rootVehicle) then
		if rootVehicle.cp.driver:isLoadingTriggerCallbackEnabled() then
			courseplay:handleLoadTriggerCallback(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId,rootVehicle,fillableObject)
		end
	end
end
LoadTrigger.loadTriggerCallback = Utils.appendedFunction(LoadTrigger.loadTriggerCallback,courseplay.loadTriggerCallback)

function courseplay:handleLoadTriggerCallback(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId,rootVehicle,fillableObject)
	rootVehicle.cp.driver:countTriggerUp(otherId)
	rootVehicle.cp.driver:setInTriggerRange()
	if onEnter then 
		courseplay.debugFormat(2, 'LoadTrigger onEnter')
		if fillableObject.getFillUnitIndexFromNode ~= nil then
			local fillLevels, capacity
			if self.source.getAllFillLevels then
				fillLevels, capacity = self.source:getAllFillLevels(g_currentMission:getFarmId())
			elseif self.source.getAllProvidedFillLevels then
				fillLevels, capacity = self.source:getAllProvidedFillLevels(g_currentMission:getFarmId(), self.managerId)
			end
			if fillLevels then
				local foundFillUnitIndex = fillableObject:getFillUnitIndexFromNode(otherId)
				for fillTypeIndex, fillLevel in pairs(fillLevels) do
					if fillableObject:getFillUnitSupportsFillType(foundFillUnitIndex, fillTypeIndex) then
						if fillableObject:getFillUnitAllowsFillType(foundFillUnitIndex, fillTypeIndex) and fillableObject.spec_cover then
							SpecializationUtil.raiseEvent(fillableObject, "onAddedFillUnitTrigger",fillTypeIndex,foundFillUnitIndex,1)
							courseplay.debugFormat(2, 'open Cover for loading')
						end
					end
				end
			end
		end
	end
	if onLeave then 
		rootVehicle.cp.driver:countTriggerDown(otherId)
		spec = fillableObject.spec_fillUnit
		if spec then
			SpecializationUtil.raiseEvent(fillableObject, "onRemovedFillUnitTrigger",#spec.fillTrigger.triggers)
		end
		courseplay.debugFormat(2,"LoadTrigger onLeave")
	end
end

--FillTrigger callback used to set approach speed for Cp driver
function courseplay:fillTriggerCallback(superFunc, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:isAIDriverActive(rootVehicle) then
		if not rootVehicle.cp.driver:isLoadingTriggerCallbackEnabled() then
			return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
		end		
		if onEnter then
			courseplay.debugFormat(2, 'fillTrigger onEnter')
		end
		if onLeave then
			rootVehicle.cp.driver:countTriggerDown(otherActorId)
			courseplay.debugFormat(2, 'fillTrigger onLeave')
		else
			rootVehicle.cp.driver:countTriggerUp(otherActorId)
			rootVehicle.cp.driver:setInTriggerRange()
		end
	end
	return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end
FillTrigger.fillTriggerCallback = Utils.overwrittenFunction(FillTrigger.fillTriggerCallback, courseplay.fillTriggerCallback)

--check if the vehicle is controlled by courseplay
function courseplay:isAIDriverActive(rootVehicle) 
	if rootVehicle and rootVehicle.cp and rootVehicle.cp.driver and rootVehicle:getIsCourseplayDriving() and rootVehicle.cp.driver:isActive() then
		return true
	end
end




