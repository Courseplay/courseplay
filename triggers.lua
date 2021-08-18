--[[
	Global table to store all triggers types:

	They get stored by their unique trigger id.

 	- LoadTriggers are basically all placeable triggers to fill upon.

 	- FillTriggers are all vehicles with fill triggers spec.

 	- UnloadTriggers are basically all placeable triggers to unload at, except bunker silos.
 		They can be separated in normal unload trigger and bale unload triggers.

	- BunkerSilos 
]]--
Triggers = {}

Triggers.loadingTriggers = {}
Triggers.unloadingTriggers = {}
Triggers.baleUnloadingTriggers = {}
Triggers.fillTriggers = {}
Triggers.bunkerSilos = {}

function Triggers.getBunkerSilos()
	return Triggers.bunkerSilos
end

function Triggers.getLoadingTriggers()
	return Triggers.loadingTriggers
end

function Triggers.getFillTriggers()
	return Triggers.fillTriggers
end

function Triggers.getUnloadingTriggers()
	return Triggers.unloadingTriggers
end

function Triggers.getBaleUnloadTriggers()
	return Triggers.baleUnloadingTriggers
end


---Add all relevant triggers on create and remove them on delete.
function Triggers.addLoadingTrigger(trigger,superFunc,...)
	local returnValue = superFunc(trigger,...)

	if trigger.triggerNode then
		Triggers.loadingTriggers[trigger.triggerNode] = trigger
	end
	return returnValue
end
LoadTrigger.load = Utils.overwrittenFunction(LoadTrigger.load,Triggers.addLoadingTrigger)

function Triggers.addUnloadingTrigger(trigger,superFunc,...)
	local returnValue = superFunc(trigger,...)

	if trigger.exactFillRootNode then
		Triggers.unloadingTriggers[trigger.exactFillRootNode] = trigger
	end

	if trigger.baleTriggerNode then 
		Triggers.baleUnloadingTriggers[trigger.baleTriggerNode] = trigger
	end

	return returnValue
end
UnloadTrigger.load = Utils.overwrittenFunction(UnloadTrigger.load,Triggers.addUnloadingTrigger)

function Triggers.addFillTrigger(_,superFunc,triggerId, ...)
	local trigger = superFunc(_,triggerId, ...)
	if trigger.triggerId then
		Triggers.fillTriggers[triggerId] = trigger
	end 
	return trigger
end
FillTrigger.new = Utils.overwrittenFunction(FillTrigger.new,Triggers.addFillTrigger)

function Triggers.removeLoadingTrigger(trigger)
	if trigger.triggerNode then
		Triggers.loadingTriggers[trigger.triggerNode] = trigger
	end
end
LoadTrigger.delete = Utils.appendedFunction(LoadTrigger.delete,Triggers.removeLoadingTrigger)

function Triggers.removeUnloadingTrigger(trigger)
	if trigger.exactFillRootNode then 
		Triggers.unloadingTriggers[trigger.exactFillRootNode] = nil
	end

	if trigger.baleTriggerNode then 
		Triggers.baleUnloadingTriggers[trigger.baleTriggerNode] = nil
	end

end
UnloadTrigger.delete = Utils.prependedFunction(UnloadTrigger.delete,Triggers.removeUnloadingTrigger)

function Triggers.removeFillTrigger(trigger)
	if trigger.triggerId then
		Triggers.fillTriggers[trigger.triggerId] = nil
	end
end
FillTrigger.delete = Utils.prependedFunction(FillTrigger.delete,Triggers.removeFillTrigger)


function Triggers.addBunkerSilo(silo,superFunc,...)
	local returnValue = superFunc(silo,...)

	--- Not sure if this is needed, some old magic maybe ?
	silo.triggerId = silo.interactionTriggerNode
	silo.bunkerSilo = true
	silo.className = "BunkerSiloTipTrigger"
	silo.rootNode = silo.nodeId
	silo.triggerStartId = silo.bunkerSiloArea.start
	silo.triggerEndId = silo.bunkerSiloArea.height
	silo.triggerWidth = courseplay:nodeToNodeDistance(silo.bunkerSiloArea.start, silo.bunkerSiloArea.width)

	Triggers.bunkerSilos[silo.triggerId] = silo
	return returnValue

end
BunkerSilo.load = Utils.overwrittenFunction(BunkerSilo.load,Triggers.addBunkerSilo)

function Triggers.removeBunkerSilo(silo)
	local triggerNode = silo.interactionTriggerNode
	Triggers.bunkerSilos[triggerNode] = nil
end
BunkerSilo.delete = Utils.prependedFunction(BunkerSilo.delete,Triggers.removeBunkerSilo)

---Global Company

function Triggers.addLoadingTriggerGC(trigger,superFunc,...)
	local returnValue = Triggers.addLoadingTrigger(trigger,superFunc,...)

	TriggerHandler.onLoad_GC_LoadingTriggerFix(trigger,superFunc,...)

	return returnValue
end

-- do not remove this comment
-- vim: set noexpandtab: