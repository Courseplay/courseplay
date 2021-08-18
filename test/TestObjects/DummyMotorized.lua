--- This file is only for functional tests outside of the game.

require("CpObject")
---@class DummyMotorized
DummyMotorized = CpObject()

function DummyMotorized:init(vehicle)
	self:createConsumers(vehicle)
end

function DummyMotorized:createConsumers(vehicle)
	self.consumers = {}
    self.consumersByFillType = {}

	for ix,fillUnit in ipairs(vehicle:getFillUnits()) do  
		if fillUnit.isConsumer then 
			local consumer = {
				fillUnitIndex = ix,
				fillType = fillUnit.fillType
			}
			table.insert(self.consumers, consumer)
			self.consumersByFillType[consumer.fillType] = consumer
		end
	end
	
end
